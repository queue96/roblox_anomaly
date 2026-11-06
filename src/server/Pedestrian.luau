-- Pedestrian.luau (ModuleScript ฝั่ง Server)
-- ลูกค้าเดินเท้า (เดินมาซื้อน้ำมันใส่แกลลอน / มาหลบฝน) + ร่ม
--   ใช้ชิ้นส่วนจากคนขับในรถแม่แบบ (DriverNPC: หัว หน้าปกติ/หน้าหลอน ลำตัว แขน ขา) จัดท่าใหม่เป็นท่ายืน
--   โครงสร้างยังชื่อ DriverNPC เหมือนเดิม ผีที่แก้คนขับ (หันหัว 180 / ยิ้มหลอน / กระสือ) จึงใช้กับคนเดินได้เลย
--   หน้า = -Z ของ pivot, pivot อยู่ที่พื้นใต้เท้า, ทุกชิ้น Anchored ขยับด้วย PivotTo (เหมือนรถ)

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Pedestrian = {}
local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))
local JerryCan = require(script.Parent:WaitForChild("JerryCan"))

local templates = ServerStorage:WaitForChild("VehicleTemplates")

local UMBRELLA_COLORS = {
	Color3.fromRGB(140, 28, 30),
	Color3.fromRGB(32, 48, 86),
	Color3.fromRGB(42, 78, 50),
	Color3.fromRGB(96, 62, 112),
	Color3.fromRGB(70, 66, 60),
}
local SHIRT_COLORS = {
	Color3.fromRGB(60, 70, 90),
	Color3.fromRGB(110, 60, 40),
	Color3.fromRGB(80, 90, 60),
	Color3.fromRGB(140, 130, 110),
	Color3.fromRGB(45, 45, 50),
}

local DEG = math.rad
local VERTICAL = CFrame.Angles(DEG(90), 0, 0) -- ชิ้นแขนขายาวตามแกน Z -> หมุนให้ตั้งลง

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = parent
	return p
end

-- ---------------------------------------------------------------- ร่ม
-- โมเดลร่มจาก Blender (tools/blender/umbrella.py -> assets/models/Umbrella.fbx) นำเข้าแล้วเป็นโมเดล "Umbrella"
--   ใช้แม่แบบใน ServerStorage.ImportedProps.Umbrella (หรือ Workspace.Umbrella ถ้ายังไม่ได้ย้าย)
--   pivot = จุดมือจับ, แกน +Y = ทิศขึ้นของร่ม, ผ้าร่ม Umbrella_Canopy สีเทาอ่อน ย้อมสีด้วย SurfaceAppearance.Color
--   ไม่เจอแม่แบบ -> ใช้ร่มทำจาก Part แบบเดิม
local UMBRELLA_SCALE = 0.8 -- โมเดลกว้าง 6 studs ย่อให้พอดีคน (~4.8)
local function umbrellaTemplate(): Model?
	local imported = ServerStorage:FindFirstChild("ImportedProps")
	local t = (imported and imported:FindFirstChild("Umbrella")) or Workspace:FindFirstChild("Umbrella")
	return if t and t:IsA("Model") then t else nil
end

-- canopy = ตำแหน่งกลางร่ม, grip = ตำแหน่งมือที่จับ (CFrame ในโลก)
-- exact = ด้ามชี้ตรงไปทาง canopy เลย (ด้ามลอดรูกำมือพอดี) / ไม่ใส่ = ปรับให้ตั้งเกือบตรง
function Pedestrian.AddUmbrella(model: Model, canopy: Vector3, grip: Vector3, color: Color3?, exact: boolean?): Model
	local tmpl = umbrellaTemplate()
	if tmpl then
		local u = tmpl:Clone()
		u.Name = "Umbrella"
		for _, d in ipairs(u:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
		u:ScaleTo(UMBRELLA_SCALE)
		-- ด้ามชี้ไปทางผ้าร่ม แต่ให้ตั้งเกือบตรง (ร่มเอียงนิดเดียว ดูเป็นธรรมชาติ)
		local up = if exact then (canopy - grip).Unit else ((canopy - grip).Unit + Vector3.new(0, 2, 0)).Unit
		u:PivotTo(CFrame.lookAt(grip, grip + up) * CFrame.Angles(DEG(-90), 0, 0))
		local c = color or UMBRELLA_COLORS[math.random(#UMBRELLA_COLORS)]
		local fabric = u:FindFirstChild("Umbrella_Canopy", true)
		if fabric and fabric:IsA("BasePart") then
			fabric.Color = c
			local sa = fabric:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				(sa :: any).Color = c
			end
		end
		u.Parent = model
		return u
	end
	local u = Instance.new("Model")
	u.Name = "Umbrella"
	local c = color or UMBRELLA_COLORS[math.random(#UMBRELLA_COLORS)]
	local tilt = CFrame.new(canopy) -- ผ้าร่มขนานพื้น (ด้ามเอียงเข้าหามือได้)
	local len = (canopy - grip).Magnitude
	part(u, "Pole", Vector3.new(0.12, 0.12, len), CFrame.lookAt((canopy + grip) / 2, canopy), Color3.fromRGB(60, 50, 40), Enum.Material.Wood)
	part(u, "Handle", Vector3.new(0.22, 0.22, 0.5), CFrame.lookAt(grip, canopy), Color3.fromRGB(40, 30, 24), Enum.Material.Wood)
	-- ผ้าร่มซ้อน 3 ชั้น (มองไกลๆ เป็นทรงโดม)
	local rings = { { 4.6, 0 }, { 3.3, 0.28 }, { 1.9, 0.52 } }
	for i, r in ipairs(rings) do
		part(u, "Canopy" .. i, Vector3.new(0.14, r[1], r[1]), tilt * CFrame.new(0, r[2], 0) * CFrame.Angles(0, 0, DEG(90)), c, Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	part(u, "Tip", Vector3.new(0.25, 0.25, 0.25), tilt * CFrame.new(0, 0.85, 0), Color3.fromRGB(30, 26, 22), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	u.Parent = model
	return u
end

-- คนขับรถกางร่ม (ร่มลอยเหนือหัว ด้ามลงมาที่ไหล่ขวา)
function Pedestrian.AddRiderUmbrella(vehicle: Model): Model?
	local d = vehicle:FindFirstChild("DriverNPC")
	local head = d and d:FindFirstChild("Head") :: BasePart?
	local torso = d and d:FindFirstChild("Torso") :: BasePart?
	if not (head and torso) then
		return nil
	end
	local piv = vehicle:GetPivot()
	local canopy = head.Position + Vector3.new(0, 2.6, 0) + piv.LookVector * -0.3
	local grip = torso.Position + piv.RightVector * 0.9 + Vector3.new(0, 0.4, 0)
	return Pedestrian.AddUmbrella(vehicle, canopy, grip)
end

-- ---------------------------------------------------------------- คนเดิน
type Anim = { root: BasePart, swing: { { part: BasePart, rel: CFrame, hinge: CFrame, sign: number, amount: number } }, phase: number }
local anims: { [Model]: Anim } = setmetatable({}, { __mode = "k" }) :: any

-- ชาวบ้านแบบใหม่ (HumanNPC: ตัวละครจาก Blender สุ่มชุด/ผม มีท่าเดิน/ยืน/เต้น) ถ้ามีแม่แบบใน ServerStorage.HumanTemplates
--   ไม่มีแม่แบบ -> ใช้คนแบบกล่องเดิมด้านล่าง
-- มือในท่าถือของ (carry_gallon มือซ้าย, hold_umbrella มือขวา) เทียบ pivot ที่พื้นใต้เท้า (+X = ขวาของตัว, -Z = หน้า)
-- ค่าจาก build_anims.py (ตำแหน่งกระดูกมือในท่านั้น)
local HUMAN_LEFT_HAND = Vector3.new(-1.41, 2.97, -0.25)
-- มือขวา = จุดกลางด้ามร่มในกำมือ และแนวด้าม (ท่า hold_umbrella มือ grip_umbrella: แบมือ วางด้ามบนฝ่ามือ แล้วงอนิ้วจนแตะด้าม)
-- วัดใน Studio ด้วย shared/HeadTurn.grip -> ด้ามร่มต้องวางตรงจุดนี้ ตามแนวนี้พอดี นิ้วจึงกำรอบด้าม ไม่ทะลุ
-- (เดิมใช้ตำแหน่งกระดูกมือ = ข้อมือ ด้ามร่มจึงแทงทะลุมือ) เปลี่ยนท่า/มือใน build_anims.py แล้วต้องวัดใหม่
local HUMAN_RIGHT_HAND = Vector3.new(1.19, 3.99, -1.5)
local HUMAN_UMBRELLA_UP = Vector3.new(-0.159, 0.984, -0.083)
-- แกลลอนน้ำมัน (โมเดลเดียวกับในร้าน server/JerryCan) ใน Model ชื่อ "Gallon" กลางคานหูหิ้วอยู่ที่ hand (เทียบ pivot)
local function addGallon(m: Model, hand: Vector3): Model
	local g = Instance.new("Model")
	g.Name = "Gallon"
	JerryCan.Build(g, CFrame.new(hand - JerryCan.GRIP))
	-- client/HeldItems ล็อกหูหิ้วเข้ากำมือซ้ายจริงทุกเฟรม (ตำแหน่งมือข้างบนวัดจาก human_base: ผู้หญิง/เด็ก/คนแก่ มือไม่อยู่ตรงนั้น)
	CollectionService:AddTag(g, "NpcGallon")
	g.Parent = m
	return g
end

local function buildHuman(opts: { [string]: any }): Model
	local m = HumanNPC.Build(opts)
	if opts.gallon then
		-- แกลลอนเปล่า (มาซื้อน้ำมัน) แบบเดียวกับในร้าน: หูหิ้วอยู่ในกำมือซ้าย ฝาหันไปข้างหน้า
		addGallon(m, HUMAN_LEFT_HAND)
	end
	if opts.umbrella then
		local h = HUMAN_RIGHT_HAND
		Pedestrian.AddUmbrella(m, h + HUMAN_UMBRELLA_UP * 3.2, h, opts.umbrellaColor, true) -- ด้ามลอดกำมือ หลังคาร่มเหนือหัว
	end
	-- แขนที่ถือของไม่แกว่งตามท่าเดิน (ท่าซ้อน): ของจึงอยู่ในมือตลอด
	if opts.gallon then
		HumanNPC.Hold(m, "carry_gallon", true)
	end
	if opts.umbrella then
		HumanNPC.Hold(m, "hold_umbrella", true)
	end
	return m
end

-- opts: umbrella (ร่ม), gallon (แกลลอนน้ำมันมือซ้าย), shirt/pants (สีเสื้อ/กางเกง คนแบบกล่อง), umbrellaColor,
--       teen (ชาวบ้านแบบใหม่: ชุดสายแว้น), dance (ท่าเต้นตอนแกว่งตามขบวน เช่น "ramwong", "wan_bounce")
function Pedestrian.Build(opts: { umbrella: boolean?, gallon: boolean?, shirt: Color3?, pants: Color3?, umbrellaColor: Color3?, teen: boolean?, dance: string?, noHelmet: boolean?, char: string?, outfit: string? }): Model
	if HumanNPC.Available() then
		return buildHuman(opts :: any)
	end
	local bike = templates:WaitForChild("CustomerBike") :: Model
	local src = (bike:WaitForChild("DriverNPC") :: Model):Clone()
	local m = Instance.new("Model")
	m.Name = "Walker"
	local root = part(m, "Root", Vector3.new(1, 0.2, 1), CFrame.new(), Color3.new(), nil)
	root.Transparency = 1
	m.PrimaryPart = root
	src.Parent = m

	local shirt = opts.shirt or SHIRT_COLORS[math.random(#SHIRT_COLORS)]
	local function place(path: { string }, cf: CFrame, size: Vector3?)
		local node: Instance? = src
		for _, n in ipairs(path) do
			node = node and node:FindFirstChild(n)
		end
		local p = node :: BasePart?
		if not p then
			return nil
		end
		-- ชิ้นลูก (เช่น หน้าหลอนในหัว) ขยับตามหัว
		local children = {}
		for _, d in ipairs(p:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(children, { d, p.CFrame:ToObjectSpace(d.CFrame) })
			end
		end
		p.CFrame = cf
		if size then
			p.Size = size
		end
		for _, ch in ipairs(children) do
			ch[1].CFrame = cf * ch[2]
		end
		return p
	end

	-- ขา (สะโพกสูง 3.3)
	for _, side in ipairs({ { "Left", -0.5 }, { "Right", 0.5 } }) do
		local s, x = side[1], side[2]
		place({ "Legs", s .. "Thigh" }, CFrame.new(x, 2.6, 0) * VERTICAL, Vector3.new(0.8, 0.8, 1.4))
		place({ "Legs", s .. "Shin" }, CFrame.new(x, 1.1, 0) * VERTICAL, Vector3.new(0.7, 0.7, 1.6))
		place({ "Legs", s .. "Foot" }, CFrame.new(x, 0.15, -0.15))
	end
	local torso = place({ "Torso" }, CFrame.new(0, 4.3, 0))
	if torso then
		torso.Color = shirt
	end
	place({ "Sash" }, CFrame.new(0, 3.45, 0))
	place({ "Head" }, CFrame.new(0, 5.85, 0))
	-- แขนซ้าย: ห้อยลง (ถือแกลลอน)
	place({ "LeftArm", "Upper" }, CFrame.new(-1.3, 4.5, 0) * VERTICAL)
	place({ "LeftArm", "Lower" }, CFrame.new(-1.3, 2.85, 0) * VERTICAL)
	place({ "LeftArm", "Hand" }, CFrame.new(-1.3, 1.85, 0))
	local leftUpper = src:FindFirstChild("LeftArm") and src.LeftArm:FindFirstChild("Upper")
	if leftUpper then
		leftUpper.Color = shirt
	end
	-- แขนขวา: ถือร่ม (งอศอกยื่นไปข้างหน้า) หรือห้อยลง
	local grip = Vector3.new(1.3, 4.0, -1.6)
	place({ "RightArm", "Upper" }, CFrame.new(1.3, 4.5, 0) * VERTICAL)
	if opts.umbrella then
		place({ "RightArm", "Lower" }, CFrame.new(1.3, 3.85, -0.85) * CFrame.Angles(DEG(-8), 0, 0))
		place({ "RightArm", "Hand" }, CFrame.new(grip))
	else
		place({ "RightArm", "Lower" }, CFrame.new(1.3, 2.85, 0) * VERTICAL)
		place({ "RightArm", "Hand" }, CFrame.new(1.3, 1.85, 0))
	end
	local rightUpper = src:FindFirstChild("RightArm") and src.RightArm:FindFirstChild("Upper")
	if rightUpper then
		rightUpper.Color = shirt
	end

	-- แกลลอนน้ำมัน (server/JerryCan) หูหิ้วอยู่ที่มือซ้าย
	if opts.gallon then
		addGallon(m, Vector3.new(-1.3, 1.85, 0))
	end
	if opts.umbrella then
		Pedestrian.AddUmbrella(m, Vector3.new(0.15, 7.7, -0.45), grip, opts.umbrellaColor)
	end

	-- ชิ้นที่แกว่งตอนเดิน (ขา 2 ข้าง + แขนซ้ายกับแกลลอน)
	local swing = {}
	local function addSwing(p: Instance?, hinge: CFrame, sign: number, amount: number)
		if p and p:IsA("BasePart") then
			table.insert(swing, { part = p, rel = p.CFrame, hinge = hinge, sign = sign, amount = amount })
		end
	end
	for _, side in ipairs({ { "Left", -0.5, 1 }, { "Right", 0.5, -1 } }) do
		local legs = src:FindFirstChild("Legs")
		for _, n in ipairs({ "Thigh", "Shin", "Foot" }) do
			addSwing(legs and legs:FindFirstChild(side[1] .. n), CFrame.new(side[2], 3.3, 0), side[3], 1)
		end
	end
	local leftArm = src:FindFirstChild("LeftArm")
	if leftArm then
		for _, n in ipairs({ "Upper", "Lower", "Hand" }) do
			addSwing(leftArm:FindFirstChild(n), CFrame.new(-1.3, 5.25, 0), -1, 0.35)
		end
	end
	local gallon = m:FindFirstChild("Gallon")
	if gallon then
		for _, d in ipairs(gallon:GetChildren()) do
			addSwing(d, CFrame.new(-1.3, 5.25, 0), -1, 0.35)
		end
	end
	if opts.pants then
		local legs = src:FindFirstChild("Legs")
		if legs then
			for _, d in ipairs(legs:GetChildren()) do
				if d:IsA("BasePart") and not string.find(d.Name, "Foot") then
					d.Color = opts.pants
				end
			end
		end
	end
	anims[m] = { root = root, swing = swing, phase = 0 }
	return m
end

-- ท่าเดิน: a = มุมแกว่ง (เรเดียน) 0 = ยืนตรง
local function pose(m: Model, a: number)
	local an = anims[m]
	if not an then
		return
	end
	local base = an.root.CFrame
	for _, s in ipairs(an.swing) do
		if s.part.Parent then
			local ang = a * s.sign * s.amount
			s.part.CFrame = base * s.hinge * CFrame.Angles(ang, 0, 0) * s.hinge:Inverse() * s.rel
		end
	end
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(p: Vector3): number
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 40, p.Z), Vector3.new(0, -80, 0), groundParams)
	return if hit then hit.Position.Y else p.Y
end

-- พื้นจริง (รวมพื้นร้าน) ไม่นับตัวเอง/ผู้เล่น/รถ
function Pedestrian.FloorAt(p: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	-- เริ่มยิงจากสูงกว่าเท้านิดเดียว (ไม่งั้นชนชายคา/หลังคา)
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 3, p.Z), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else groundAt(p)
end

-- เดินไปจุดหมาย (เดินบนพื้นดิน หรือ floor = true ใช้พื้นจริงรวมพื้นร้าน)
function Pedestrian.WalkTo(m: Model, target: Vector3, speed: number?, floor: boolean?, ignore: { Instance }?)
	local an = anims[m]
	local spd = speed or 7
	local cap = HumanNPC.PaceLimit(m) -- คนแก่ใส่ผ้านุ่งเดินช้ากว่านี้ (ท่าเดินไม่ซอยเท้า/ไถล)
	if cap then
		spd = math.min(spd, cap)
	end
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent then
			done = true
			conn:Disconnect()
			return
		end
		local pos = m:GetPivot().Position
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local dist = flat.Magnitude
		if dist < 0.2 then
			done = true
			conn:Disconnect()
			pose(m, 0)
			HumanNPC.SetMoving(m, false)
			return
		end
		HumanNPC.SetMoving(m, true, spd)
		local step = math.min(dist, spd * dt)
		local dir = flat.Unit
		local nxt = pos + dir * step
		local y = if floor then Pedestrian.FloorAt(nxt, ignore or { m }) else groundAt(nxt)
		if an then
			an.phase += step * 0.9
		end
		local phase = if an then an.phase else 0
		local bob = if HumanNPC.Is(m) then 0 else math.abs(math.sin(phase)) * 0.12 -- ชาวบ้านแบบใหม่: ท่าเดินยวบเอง
		m:PivotTo(CFrame.lookAt(Vector3.new(nxt.X, y + bob, nxt.Z), Vector3.new(nxt.X, y + bob, nxt.Z) + dir))
		pose(m, math.sin(phase) * 0.5)
	end)
	while not done do
		task.wait()
	end
end

-- ท่าแกว่งขา/แขน (ใช้ตอนเต้น หรือเดินตามรถที่ขยับด้วย PivotTo เอง)
function Pedestrian.Pose(m: Model, a: number)
	pose(m, a)
	HumanNPC.Pose(m, a)
end

-- หันหน้าไปทางจุดหนึ่ง (ยืนอยู่กับที่)
function Pedestrian.Face(m: Model, at: Vector3)
	local p = m:GetPivot().Position
	local flat = Vector3.new(at.X - p.X, 0, at.Z - p.Z)
	if flat.Magnitude > 0.01 then
		m:PivotTo(CFrame.lookAt(p, p + flat.Unit))
	end
	pose(m, 0)
	HumanNPC.SetMoving(m, false)
end

-- ค่อยๆ จางหาย (ผี) แล้วลบทิ้ง
function Pedestrian.FadeAway(m: Model, seconds: number)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 1 then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		elseif d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds + 0.1, function()
		m:Destroy()
	end)
end

return Pedestrian
