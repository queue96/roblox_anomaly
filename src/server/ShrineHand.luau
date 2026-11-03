--!nonstrict
-- ShrineHand.luau (ModuleScript ฝั่ง Server, require จาก CoreLoop)
-- มือผีที่ศาลพระภูมิ: ถวายขนมแล้วสักพัก มือเหี่ยวๆ (มีแค่มือ ไม่มีตัว) ยื่นออกมาจากช่องประตูในตัวศาล
-- คว้าชิ้นขนมแล้วดึงกลับเข้าไปในศาล ใบตองวางอยู่ต่อจนหมดเวลาคุ้มครอง
--
-- จุดในศาล: ถ้าโมเดลศาลมี Attachment "HandHole" (ช่องที่มือออก, แกน -Z ของ attachment = ทิศออกนอกศาล)
--   และ "OfferingSpot" (ที่วางขนม) ใน SpiritHouseOnStilts จะใช้จุดนั้น (ศาลรุ่นใหม่ SpiritHouseOnStilts_v2)
--   ไม่มี = คำนวณจากศาลเดิม: หน้าศาล = ทิศจากกลางศาลไปกระถางธูป (Incense2) ช่องประตูอยู่หลังกระถางธูป
-- โมเดลมือ: ServerStorage.ImportedProps.GhostHand (นำเข้าจาก assets/models/GhostHand.fbx) ถ้ามี
--   ไม่มี = ประกอบมือจากชิ้นส่วนง่ายๆ (แขนผอม ข้อนิ้วยาว เล็บดำ)
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShrineHand = {}

local SKIN = Color3.fromRGB(122, 128, 106) -- เทาอมเขียวซีด
local SKIN_DARK = Color3.fromRGB(78, 82, 66)
local NAIL = Color3.fromRGB(42, 36, 28)
local HAND_LENGTH = 1.9 -- studs (แขนท่อนล่าง + มือ) ให้พอดีช่องประตูศาลที่กว้างราว 1 stud

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- ทรงกระบอกตามแนวจาก a ไป b
local function bone(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3): Part
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	return part(parent, name, Vector3.new(len, thick, thick), cf, color, Enum.PartType.Cylinder)
end

-- มือประกอบจากชิ้นส่วน: จุดอ้างอิง (PrimaryPart "Wrist") = ปลายแขนด้านใน, มือชี้ไปทาง -Z
local function buildFallbackHand(): Model
	local m = Instance.new("Model")
	m.Name = "GhostHand"
	local origin = part(m, "Wrist", Vector3.new(0.1, 0.1, 0.1), CFrame.new(), SKIN)
	origin.Transparency = 1
	m.PrimaryPart = origin
	-- แขนท่อนล่างผอม ปลายด้านในเป็นผ้าขาดดำ
	bone(m, "Sleeve", Vector3.new(0, 0, 0.1), Vector3.new(0, 0, -0.35), 0.32, Color3.fromRGB(28, 26, 24))
	bone(m, "Forearm", Vector3.new(0, 0, -0.2), Vector3.new(0, 0.02, -1.05), 0.2, SKIN_DARK)
	part(m, "WristBone", Vector3.new(0.2, 0.17, 0.17), CFrame.new(0, 0.03, -1.05), SKIN, Enum.PartType.Ball)
	-- ฝ่ามือแบนผอม
	part(m, "Palm", Vector3.new(0.3, 0.08, 0.36), CFrame.new(0, 0.02, -1.26) * CFrame.Angles(math.rad(-8), 0, 0), SKIN)
	-- นิ้วยาวผอม 3 ข้อ งอลงเหมือนกำลังจะคว้า + เล็บยาวดำ
	local fingers = { { x = -0.12, len = 0.26 }, { x = -0.04, len = 0.31 }, { x = 0.04, len = 0.3 }, { x = 0.12, len = 0.24 } }
	for i, f in ipairs(fingers) do
		local p0 = Vector3.new(f.x, 0.02, -1.43)
		local p1 = p0 + Vector3.new(f.x * 0.25, -0.03, -f.len)
		local p2 = p1 + Vector3.new(f.x * 0.15, -0.12, -f.len * 0.75)
		local p3 = p2 + Vector3.new(0, -0.12, -f.len * 0.45)
		bone(m, "Finger" .. i .. "a", p0, p1, 0.055, SKIN)
		bone(m, "Finger" .. i .. "b", p1, p2, 0.048, SKIN)
		bone(m, "Finger" .. i .. "c", p2, p3, 0.04, SKIN)
		part(m, "Knuckle" .. i, Vector3.new(0.07, 0.07, 0.07), CFrame.new(p1), SKIN_DARK, Enum.PartType.Ball)
		bone(m, "Nail" .. i, p3, p3 + (p3 - p2).Unit * 0.09, 0.035, NAIL)
	end
	-- นิ้วโป้งชี้เข้าหาฝ่ามือ
	local t0 = Vector3.new(-0.16, 0.0, -1.18)
	local t1 = t0 + Vector3.new(-0.08, -0.06, -0.18)
	local t2 = t1 + Vector3.new(0.05, -0.08, -0.14)
	bone(m, "Thumb_a", t0, t1, 0.06, SKIN)
	bone(m, "Thumb_b", t1, t2, 0.05, SKIN)
	bone(m, "Thumb_nail", t2, t2 + (t2 - t1).Unit * 0.08, 0.035, NAIL)
	return m
end

local function buildHand(): Model
	local imported = ServerStorage:FindFirstChild("ImportedProps") and ServerStorage.ImportedProps:FindFirstChild("GhostHand")
	if imported and imported:IsA("Model") then
		local m = imported:Clone()
		m.Name = "GhostHand"
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		-- โมเดลนำเข้าใช้ขนาดจริงจาก Blender (ฝ่ามือใหญ่ตามที่ปั้น ไม่ย่อ)
		-- จุดหมุน = ปลายแขนด้านใน (กระดูก Forearm) หันไปทางกระดูก Hand (-Z = ทิศมือ) คำนวณจากกระดูกเอง
		-- (3D Importer ใส่ PivotOffset เอียง 90° มา ตั้งใน Studio แล้วก็ยังกลับมา)
		local fa, hb = m:FindFirstChild("Forearm", true), m:FindFirstChild("Hand", true)
		if fa and hb and fa:IsA("Bone") and hb:IsA("Bone") then
			local want = CFrame.lookAt(fa.WorldPosition, hb.WorldPosition)
			if m.PrimaryPart then -- (ตั้ง WorldPivot ของ Model ที่มี PrimaryPart แล้วไม่มีผล: ต้องตั้ง PivotOffset ของชิ้นเอง)
				m.PrimaryPart.PivotOffset = m.PrimaryPart.CFrame:ToObjectSpace(want)
			else
				m.WorldPivot = want
			end
		end
		return m
	end
	return buildFallbackHand()
end

-- จุดช่องประตู (มือออก) และที่วางขนม ในโลก
function ShrineHand.Spots(spirit: Instance, body: BasePart): (CFrame, Vector3)
	local hole = body:FindFirstChild("HandHole", true)
	local spot = body:FindFirstChild("OfferingSpot", true)
	if hole and hole:IsA("Attachment") and spot and spot:IsA("Attachment") then
		return hole.WorldCFrame, spot.WorldPosition
	end
	local inc = spirit:FindFirstChild("Incense2") :: BasePart?
	local c = body.Position
	local front = if inc then Vector3.new(inc.Position.X - c.X, 0, inc.Position.Z - c.Z) else body.CFrame.LookVector
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(1, 0, 0)
	local right = front:Cross(Vector3.yAxis)
	local incY = if inc then inc.Position.Y else c.Y + 1.7
	local incPos = if inc then inc.Position else c + front * 1.3
	-- ช่องประตู: ในตัวศาลหลังกระถางธูป เยื้องข้างนิดไม่ให้มือทะลุกระถาง / ที่วางขนม: บนพื้นระเบียงหน้ากระถางธูป
	-- (collision ของศาลเดิมมีรู ข้างกระถางธูปยิง ray ลงแล้วทะลุถึงพื้นดิน)
	local holePos = Vector3.new(c.X, incY + 0.45, c.Z) + front * 0.35 + right * 0.32
	local spotPos = Vector3.new(incPos.X, incY, incPos.Z) + front * 0.7 + right * 0.35
	return CFrame.lookAt(holePos, holePos + front), spotPos
end

-- ย้ายโมเดลไปตาม CFrame ที่ tween ได้ (โมเดลไม่มี property ให้ tween ตรงๆ)
local function tweenPivot(m: Model, from: CFrame, to: CFrame, time: number, style: Enum.EasingStyle?)
	local v = Instance.new("CFrameValue")
	v.Value = from
	local conn = v.Changed:Connect(function(cf)
		if m.Parent then
			m:PivotTo(cf)
		end
	end)
	local t = TweenService:Create(v, TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = to })
	t:Play()
	t.Completed:Wait()
	conn:Disconnect()
	v:Destroy()
end

local function fade(m: Model, to: number, time: number)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Wrist" then
			local base = d:GetAttribute("BaseT")
			if base == nil then
				base = d.Transparency
				d:SetAttribute("BaseT", base)
			end
			TweenService:Create(d, TweenInfo.new(time), { Transparency = if to >= 1 then 1 else base }):Play()
		end
	end
	task.wait(time)
end

-- ชิ้นขนมที่ถวาย (ชื่อขึ้นต้น "Sweet": มือผีหยิบเฉพาะขนม ใบตองวางอยู่ต่อ)
local function sweetsOf(offering: Model): { BasePart }
	local list = {}
	for _, d in ipairs(offering:GetDescendants()) do
		if d:IsA("BasePart") and (string.sub(d.Name, 1, 5) == "Sweet" or d.Name == "KhanFill" or d.Name == "KhanSweets") then
			table.insert(list, d)
		end
	end
	return list
end

local running: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- ---------------------------------------------------------------- นิ้วมือผี (โมเดลนำเข้ามีกระดูก GhostHandRig)
-- ท่ากำขนม: องศางอต่อข้อ (ข้อโคน, ข้อกลาง, ข้อปลาย) ตอนกำ / ตอนแบเตรียมคว้า — ตรงกับ action "Grab" ใน Blender
-- (tools/blender/spirit_house_v2.py GRAB) แต่ไม่อัปโหลด Animation: หมุนกระดูกเองด้วย Bone.CFrame (replicate ไปทุกเครื่อง
-- ต่างจาก Bone.Transform ที่ตั้งจาก server แล้วผู้เล่นไม่เห็น)
local GRAB = {
	Index = { { 24, 28, 18 }, { -14, -16, -10 } },
	Middle = { { 26, 30, 20 }, { -14, -18, -12 } },
	Ring = { { 27, 30, 20 }, { -12, -16, -10 } },
	Pinky = { { 28, 30, 18 }, { -10, -14, -10 } },
	Thumb = { { 22, 26, 18 }, { -16, -10, -8 } },
}
type Finger = { bones: { Bone }, rest: { CFrame }, axis: CFrame, closed: { number }, open: { number } }

-- หาแกนงอของแต่ละนิ้ว: 3D Importer วางแกนกระดูกต่างจาก Blender ได้ -> ลองหมุนข้อโคนทั้ง 4 ทิศ
-- ทิศที่ปลายนิ้วเข้าใกล้กลางฝ่ามือมากสุด = งอเข้า (กำ)
local function fingerRig(hand: Model): ({ Finger }, Vector3?)
	local function b(name: string): Bone?
		local x = hand:FindFirstChild(name, true)
		return if x and x:IsA("Bone") then x else nil
	end
	local h, mid = b("Hand"), b("Middle1")
	if not (h and mid) then
		return {}, nil
	end
	local palm = (h.WorldPosition + mid.WorldPosition) / 2
	local list: { Finger } = {}
	for name, ang in pairs(GRAB) do
		local bones = { b(name .. "1"), b(name .. "2"), b(name .. "3") }
		if bones[1] and bones[2] and bones[3] then
			local rest = { bones[1].CFrame, bones[2].CFrame, bones[3].CFrame }
			local tip0 = bones[3].WorldPosition
			local best, bestD = CFrame.Angles(1, 0, 0), math.huge
			for _, ax in ipairs({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis }) do
				local r = CFrame.fromAxisAngle(ax, math.rad(25))
				bones[1].CFrame = rest[1] * r
				local d = (bones[3].WorldPosition - palm).Magnitude
				if d < bestD then
					bestD, best = d, CFrame.fromAxisAngle(ax, 1)
				end
				bones[1].CFrame = rest[1]
			end
			if bestD < (tip0 - palm).Magnitude then
				table.insert(list, { bones = bones :: any, rest = rest, axis = best, closed = ang[1], open = ang[2] })
			end
		end
	end
	return list, palm
end

-- k: 0 = ท่าปกติ, 1 = กำ, -1 = แบสุด
local function setGrip(fingers: { Finger }, k: number)
	for _, f in ipairs(fingers) do
		local ang = if k >= 0 then f.closed else f.open
		local w = math.abs(k)
		local axis, _ = f.axis:ToAxisAngle()
		for i = 1, 3 do
			f.bones[i].CFrame = f.rest[i] * CFrame.fromAxisAngle(axis, math.rad(ang[i] * w))
		end
	end
end

-- กลางอุ้งมือ: ครึ่งทางระหว่างข้อโคนนิ้ว (สันมือ) กับปลายนิ้ว 4 นิ้ว — ท่ากำแล้วจุดนี้อยู่ในกำมือพอดี
-- (ใช้ทั้งเล็งตอนคว้าและเป็นที่ติดขนมตอนดึงกลับ)
local function cupPoint(fingers: { Finger }): Vector3
	local knuckles, tips, n = Vector3.zero, Vector3.zero, 0
	for _, f in ipairs(fingers) do
		if f.bones[1].Name:sub(1, 5) ~= "Thumb" then
			local b2, b3 = f.bones[2].WorldPosition, f.bones[3].WorldPosition
			knuckles += f.bones[1].WorldPosition
			tips += b3 + (b3 - b2) * 0.55
			n += 1
		end
	end
	if n == 0 then
		return fingers[1].bones[3].WorldPosition
	end
	return (knuckles + tips) / (2 * n)
end

-- ค่อยๆ เปลี่ยนท่ามือจาก a ไป b ใน t วินาที (ไม่รอ)
local function gripTween(fingers: { Finger }, a: number, b: number, t: number)
	if #fingers == 0 then
		return
	end
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local u = math.clamp((os.clock() - t0) / t, 0, 1)
			u = u * u * (3 - 2 * u)
			setGrip(fingers, a + (b - a) * u)
			if u >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- เรียกหลังวางขนมถวาย: รอสักพักแล้วมือผีออกมาหยิบขนมเข้าไปในศาล (ของถวายถูกลบก่อน = ยกเลิก)
-- sound: เรียกตอนมือเริ่มยื่นออกมา คืน Sound ที่เล่นอยู่ได้ (ถ้ามือหยิบจบก่อนเสียงจบ = ค่อยๆ เฟดเสียงลงแล้วหยุด)
function ShrineHand.Take(offering: Model, spirit: Instance, body: BasePart, delaySeconds: number?, sound: ((BasePart) -> Sound?)?)
	if running[offering] then
		return
	end
	running[offering] = true
	task.spawn(function()
		task.wait(delaySeconds or (6 + math.random() * 6))
		if not offering.Parent then
			return
		end
		local sweets = sweetsOf(offering)
		if #sweets == 0 then
			return
		end
		local holeCF = ShrineHand.Spots(spirit, body)
		local hand = buildHand()
		local length = hand:GetExtentsSize().Magnitude
		local fingers, palm = fingerRig(hand)
		-- ขนม: จุดกลางของกองขนม -> มือต้องไปจบตรงนั้น (ปลายนิ้วเลยไปนิด)
		local sum = Vector3.zero
		for _, s in ipairs(sweets) do
			sum += s.Position
		end
		local target = sum / #sweets
		-- จากปลายแขนด้านใน (pivot) ถึงกลางฝ่ามือ: มือนำเข้าวัดจากกระดูกจริง / มือประกอบเอง = สัดส่วนเดิม
		local reach = if palm then (palm - hand:GetPivot().Position).Magnitude else HAND_LENGTH * 0.72
		-- ซ่อนอยู่ในศาล (ทั้งมือหลังช่องประตู) -> ยื่นออกมาเหนือขนม -> จิกลงคว้า -> ดึงกลับ
		local dirOut = Vector3.new(target.X - holeCF.Position.X, 0, target.Z - holeCF.Position.Z)
		dirOut = if dirOut.Magnitude > 0.01 then dirOut.Unit else holeCF.LookVector
		-- แขนเอียงลงจากช่องประตูหาขนม (ไม่ยื่นแบนราบไปกับแท่น)
		local PITCH = math.rad(24)
		local dirDown = (dirOut * math.cos(PITCH) - Vector3.yAxis * math.sin(PITCH)).Unit
		local hidden = CFrame.lookAt(holeCF.Position - dirDown * (length + 0.2), holeCF.Position)
		local aboveTarget = target + Vector3.new(0, 0.35, 0)
		local outWrist = aboveTarget - dirDown * reach
		local out = CFrame.lookAt(outWrist, aboveTarget)
		local grab = out + Vector3.new(0, -0.27, 0) -- จิกลงไปที่กองขนม
		-- ไม่ให้นิ้ว/ฝ่ามือจมพื้นแท่นศาล: ลองวางมือในท่านั้นจริง (แบ / กำ) วัดจุดต่ำสุดของปลายนิ้วกับฝ่ามือ
		-- แล้วยกขึ้นจนพ้นพื้นใต้ขนม (มือนำเข้ามีขนาดจริง นิ้วยาวห้อยต่ำกว่าข้อมือมาก)
		if #fingers > 0 then
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { body }
			local hit = Workspace:Raycast(target + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), rp)
			local floorY = if hit then hit.Position.Y else target.Y - 0.15
			local function lowest(cf: CFrame, k: number): number
				hand:PivotTo(cf)
				setGrip(fingers, k)
				local y = math.huge
				for _, f in ipairs(fingers) do
					local b2, b3 = f.bones[2].WorldPosition, f.bones[3].WorldPosition
					local tip = b3 + (b3 - b2) * 0.9 -- ข้อสุดท้ายยาวราวข้อกลาง (+ เล็บ)
					y = math.min(y, b2.Y, b3.Y, tip.Y - 0.06)
				end
				return y
			end
			-- แนวแขนต้องลอดกลางช่องประตูศาลเสมอ (เดิมยกมือขึ้น/เลื่อนมือตามขนมแบบขนานกัน -> แนวแขนไม่ผ่านกลางประตู
			-- แขนชนกรอบประตูด้านบน): หาจุดเล็ง A แล้ววางมือบนเส้นตรง ช่องประตู -> A (pivot อยู่บนเส้นเดียวกันหลังประตู)
			-- ปรับ A ซ้ำจนกลางอุ้งมือ (ท่ากำ) อยู่ที่จุดที่ต้องการ
			local hole = holeCF.Position
			local function poseThrough(a: Vector3): CFrame
				local d = (a - hole).Unit
				return CFrame.lookAt(a - d * reach, a)
			end
			local function aimCup(cup: Vector3): CFrame
				local a = cup + Vector3.new(0, 0.2, 0)
				local cf = poseThrough(a)
				for _ = 1, 4 do
					hand:PivotTo(cf)
					setGrip(fingers, 1)
					a += cup - cupPoint(fingers)
					cf = poseThrough(a)
				end
				return cf
			end
			-- ท่าคว้า: กลางอุ้งมือที่กำแล้วอยู่ที่ขนมพอดี (ยกขึ้นถ้านิ้วจะจมพื้นแท่น)
			grab = aimCup(target)
			local liftGrab = math.max(0, floorY + 0.01 - lowest(grab, 1))
			if liftGrab > 0 then
				grab = aimCup(target + Vector3.new(0, liftGrab, 0))
			end
			-- ท่ายื่นรอคว้า: อยู่เหนือจุดคว้า 0.3 บนแนวที่ลอดประตูเหมือนกัน (จิกลงมาหาขนม) นิ้วแบไม่จมพื้น
			out = aimCup(target + Vector3.new(0, 0.3 + liftGrab, 0))
			local liftOut = math.max(0, floorY + 0.08 - lowest(out, -1))
			if liftOut > 0 then
				out = aimCup(target + Vector3.new(0, 0.3 + liftGrab + liftOut, 0))
			end
			-- ซ่อนในศาล: ถอยตามแนวเดียวกับท่ายื่น (ดึงเข้า-ออกลอดกลางประตู)
			local aOut = out.Position + out.LookVector * reach
			hidden = out - out.LookVector * ((aOut - hole).Magnitude + length + 0.2 - reach)
			setGrip(fingers, 0)
		end
		hand:PivotTo(hidden)
		for _, d in ipairs(hand:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "Wrist" then
				d:SetAttribute("BaseT", d.Transparency)
				d.Transparency = 1
			end
		end
		hand.Parent = spirit
		local snd: Sound? = nil
		if sound then
			local ok, s = pcall(sound, body)
			snd = if ok and typeof(s) == "Instance" and s:IsA("Sound") then s else nil
		end
		local function fadeSound()
			local s = snd
			snd = nil
			if s and s.Parent then
				if s.IsPlaying then
					local tw = TweenService:Create(s, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Volume = 0 })
					tw:Play()
					tw.Completed:Wait()
				end
				s:Destroy()
			end
		end
		task.spawn(fade, hand, 0, 0.5)
		gripTween(fingers, 0, -1, 1.4) -- ยื่นออกมาพร้อมแบนิ้วเตรียมคว้า
		tweenPivot(hand, hidden, out, 1.5, Enum.EasingStyle.Quad)
		if not offering.Parent then
			hand:Destroy()
			task.spawn(fadeSound)
			return
		end
		task.wait(0.35)
		tweenPivot(hand, out, grab, 0.25, Enum.EasingStyle.Quad)
		gripTween(fingers, -1, 1, 0.22) -- กำรอบชิ้นขนม (ค้างไว้จนดึงกลับเข้าศาล)
		task.wait(0.12)
		-- คว้าขนม: ขนมขยับตามมือ
		--   มือมีกระดูก: ขนมติดอยู่กลางอุ้งมือที่กำ (เดิมผูกกับข้อมือตอนนิ้วยังกำไม่สุด -> ขนมห้อยใต้นิ้วตอนดึงกลับ)
		local function tipsNow(): Vector3
			return cupPoint(fingers)
		end
		local rel = {}
		local handCF = hand:GetPivot()
		local center = Vector3.zero
		for _, s in ipairs(sweets) do
			if s.Parent then
				rel[s] = handCF:ToObjectSpace(s.CFrame)
				center += s.Position / #sweets
			end
		end
		local start: { [BasePart]: CFrame } = {}
		for s in pairs(rel) do
			start[s] = s.CFrame
		end
		local grabT0 = os.clock()
		local follow = RunService.Heartbeat:Connect(function()
			local cf = hand:GetPivot()
			local snap = if #fingers > 0 then tipsNow() else nil
			-- ช่วงแรก 0.25 วิ ขนมค่อยๆ เลื่อนจากที่วางเข้าอุ้งมือ (ไม่กระโดดเข้ามือในเฟรมเดียว)
			local u = math.clamp((os.clock() - grabT0) / 0.25, 0, 1)
			u = u * u * (3 - 2 * u)
			for s, r in pairs(rel) do
				if s.Parent then
					local c = cf * r
					if snap then -- อยู่กลางอุ้งมือที่กำ (คงระยะของแต่ละชิ้นจากกลางกองขนม)
						c = c.Rotation + snap + (c.Position - (cf * handCF:ToObjectSpace(CFrame.new(center))).Position)
					end
					s.CFrame = start[s]:Lerp(c, u)
				end
			end
		end)
		task.wait(0.3)
		tweenPivot(hand, grab, out, 0.3, Enum.EasingStyle.Quad)
		-- ดึงกลับเข้าศาล: จางหายช่วงท้าย (ปลายแขนด้านในยาวเลยผนังหลังศาล ไม่ให้เห็นโผล่ด้านหลัง)
		task.delay(0.45, function()
			fade(hand, 1, 0.4)
			for s in pairs(rel) do
				if s.Parent then
					TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				end
			end
		end)
		tweenPivot(hand, out, hidden, 0.9, Enum.EasingStyle.Quad)
		follow:Disconnect()
		for s in pairs(rel) do
			s:Destroy()
		end
		task.wait(0.1)
		hand:Destroy()
		running[offering] = nil
		task.spawn(fadeSound) -- หยิบจบแล้วแต่เสียงยังไม่จบ: ค่อยๆ เบาลง
	end)
end

return ShrineHand
