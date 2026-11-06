--!strict
-- SceneryGhosts.client.luau
-- ผีฉาก (ไม่ใช่ลูกค้า) โผล่ให้เห็นเป็นช่วงๆ — เกิดบนเครื่องนี้เครื่องเดียว: แต่ละคนเห็นคนละตัว คนละเวลา
--   คืนหนึ่งสุ่มชนิดผีไว้ไม่กี่แบบ (KindsPerNight) โผล่ทีละตัว ไม่บ่อย (MaxPerNight / Every)
--   ผีอยู่ที่ของมัน (ดงกล้วย / ต้นไทร / ทุ่ง) ขยับออกมาให้เห็นนิดเดียว + เรืองแสงจางๆ ไม่เดินมาหน้าร้านเอง
--   ผู้เล่นหันไปเห็น = ผีเดินเข้าหาคนนั้น (ผู้ใช้ 2026-11-04) เดินไล่ทัน / หนีนานเกิน HuntMax / ปิดแผงระหว่างถูกไล่ = ผีหลอก
--     ใครอยู่นอกร้าน (หรือคนที่ถูกไล่ถึงตัวตอนแผงเปิด) ล้ม + ตาปรือ จนผีปั่นป่วนเสร็จ (server: CoreLoop.Rampage / GhostLinger)
--   ผีเดินผ่าน (path: เปรต กระหัง) ยังใช้แบบเดิม: มองค้างนาน = พุ่งใส่หน้า (client/SceneryGhostWatch ใช้ tag "SceneryGhost")
--   หุ่นไล่กา: พอหันไปเห็น ไถลถอยหลังหายไปในทุ่ง (ไม่พุ่งใส่หน้า)
-- ไฟดับ (เครื่องปั่นไฟ) + พนมมือจนตาทิพย์เปิด: เห็นศพห่อผ้าขาวยืนเต็มทุ่ง -> ลงสมุด 1 อีเวนต์ต่อคืน (Remotes.OutageSwarm)
-- แม่แบบผี: ReplicatedStorage.GhostModels (server/GhostNPC สำเนามาจาก ServerStorage.GhostTemplates)
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local models = ReplicatedStorage:WaitForChild("GhostModels", 60)
local animIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostAnimIds")) :: any
local GhostStretch = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostStretch")) :: any
local GhostFloat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostFloat")) :: any
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank")) :: any
if not models then
	return
end

local CONFIG = {
	FirstAfter = { 120, 240 }, -- หลังเปิดร้าน (วินาที) ผีตัวแรก
	Every = { 330, 540 }, -- ห่างกันเท่านี้ (เดิม 240-420 ผีมาถี่เกิน ผู้ใช้ 2026-11-05)
	MaxPerNight = 3, -- คืนละไม่เกิน
	KindsPerNight = 4, -- สุ่มชนิดผีไว้คืนละเท่านี้แบบ (ไม่ออกครบทุกตัว)
	Stay = { 30, 45 }, -- โผล่ค้างกี่วินาที (ถ้าไม่มีใครหันไปเห็น ก็จางหายไปเอง)
	SeeTime = 0.7, -- อยู่ในสายตาต่อเนื่องกี่วินาทีถึงนับว่าเห็น
	SeeDist = 110, -- ไกลกว่านี้ไม่นับว่าเห็น
	SeeCenter = 0.45, -- ห่างกลางจอไม่เกินสัดส่วนนี้ (ของครึ่งจอ)
	HuntSpeed = 7.5, -- เดินไล่ (studs/วินาที) ผู้เล่นเดิน 10 จึงเดินหนีได้
	HuntReach = 5, -- ถึงตัวในระยะนี้ = ผีหลอก
	HuntMax = 14, -- ไล่นานสุดกี่วินาที แล้วหลอกเลย (เดินหนีไม่พ้น ถ้ายังอยู่นอกร้าน)
	WatchTime = 5, -- ร้านยังเปิด: ผีที่ถูกเห็นยืนมองนานเท่านี้แล้วจางหาย (ไม่เดินมาหา)
	WatchTransparency = 0.55, -- ตอนยืนมองจางลงเหลือเท่านี้ (เห็นลางๆ)
	GlowColor = Color3.fromRGB(185, 205, 255),
	SwarmCount = 14, -- ศพห่อผ้าตอนไฟดับ
	SwarmRadius = { 24, 72 },
}

-- from -> to = ขยับออกมาจากที่ซ่อนให้เห็นง่ายขึ้น แต่ยังอยู่ในที่ของมัน (ดงกล้วย x 19..33 z 9..48 / ต้นไทร ราว -32, 22 / ทุ่งฝั่งตรงข้ามถนน)
-- path = เดินผ่านไปเรื่อยๆ (speed studs/วินาที) · moveClip = ท่าตอนเคลื่อน / clip = ท่าตอนหยุด · then = ท่าหลังหยุดสักพัก
type Kind = {
	model: string,
	from: { number },
	to: { number },
	clip: string,
	moveClip: string?,
	lift: number?,
	speed: number?,
	path: boolean?,
	huntSpeed: number?,
	glow: Color3?,
	focus: string?,
	after: { any }?,
	front: { { number } }?, -- จุดหน้าร้านที่สุ่มไปโผล่แทนที่ประจำ (เดินออกมาจากด้านหลังจุดนั้น 3 studs)
	frontChance: number?,
	-- ยืดแขน (shared/GhostStretch): at = กี่วินาทีหลังหยุด แขนยาว factor เท่า ค้าง hold วิ แล้วหดกลับ (วนซ้ำทุก every วิ)
	reach: { side: string, factor: number, at: number, hold: number, every: number }?,
	longLegs: number?, -- ขายาวกี่เท่า (ค่อยๆ ยืดหลังโผล่ แล้วเดินขาโย่งไปมา / เดินไล่ด้วยขายาว)
	hop: { height: number, rate: number }?, -- กระโดดดึ๋งๆ ตอนเคลื่อน (สูง studs, ครั้งต่อวินาที)
	float: boolean?, -- ลอย (shared/GhostFloat): ส่ายซ้ายขวา ขึ้นลง เอียงตัว พุ่งเป็นพักๆ เร็วขึ้นตามความดุของรอบ
}
local KINDS: { [string]: Kind } = {
	Tani = { model = "ghost_tani", from = { 28, 7 }, to = { 27.4, 2.1 }, clip = "tani_peek", moveClip = "ghost_idle", speed = 0.8 },
	-- นางรำ: ครึ่งหนึ่งโผล่ที่ต้นไทร อีกครึ่งมารำหน้าร้าน (ฝั่งตรงข้ามถนน / ข้างลาน) ผู้ใช้ 2026-11-05
	Dancer = {
		model = "ghost_dancer",
		from = { -33, 17 },
		to = { -30, 13 },
		clip = "dancer_dance",
		speed = 0.7,
		front = { { -16, -20 }, { -4, -21 }, { 8, -20 }, { 12, -2 } },
		frontChance = 0.5,
	},
	-- แม่นาก: ยื่นมือแล้วแขนยืดยาวออกมาหยิบของ (ตำนานยื่นมือเก็บมะนาว)
	MaeNak = {
		model = "ghost_mae_nak",
		from = { -46, -26 },
		to = { -42, -24 },
		clip = "nak_cradle",
		speed = 1.2,
		after = { 4, "nak_reach" },
		reach = { side = "R", factor = 4.5, at = 4.8, hold = 2.5, every = 9 },
	},
	-- กุมารทอง: กระโดดดึ๋งๆ เข้ามา
	Kuman = { model = "ghost_kuman_thong", from = { -38, 17 }, to = { -35, 12 }, clip = "kuman_giggle", moveClip = "run", speed = 3, huntSpeed = 9, hop = { height = 2.6, rate = 1.7 } },
	-- ผีเด็ก: ขายืดสูงโย่ง เดินไปมา/เดินไล่ด้วยขายาว
	Child = { model = "ghost_child", from = { 30, -32 }, to = { 27, -29 }, clip = "ghost_idle", moveClip = "ghost_glide", speed = 1.6, longLegs = 2.4 },
	Shroud = { model = "ghost_shroud", from = { -27, -50 }, to = { -25, -44 }, clip = "shroud_idle", moveClip = "shroud_glide", lift = 0.5, speed = 1.6, float = true },
	Krasue = { model = "Krasue", from = { -38, -50 }, to = { -34, -44 }, clip = "Float", lift = 5.5, speed = 2.2, huntSpeed = 9, glow = Color3.fromRGB(255, 110, 40), focus = "Head", float = true },
	Pop = { model = "Pop", from = { 32, -26 }, to = { 29, -23 }, clip = "LickLips", moveClip = "TwitchWalk", speed = 2 },
	Pret = { model = "Pret", from = { -80, -62 }, to = { 85, -62 }, clip = "TallSlowWalk", speed = 14, path = true }, -- 5x size (GhostAnimIds.SCALE): stride 5x longer too
	Krahang = { model = "Krahang", from = { 90, -30 }, to = { -95, -30 }, clip = "FlapFly", lift = 16, speed = 11, path = true, float = true },
	Scarecrow = { model = "", from = { 0, 0 }, to = { 0, 0 }, clip = "" },
	Shadow = { model = "", from = { 0, 0 }, to = { 0, 0 }, clip = "" },
}
local KIND_LIST = { "Tani", "Dancer", "MaeNak", "Kuman", "Child", "Shroud", "Krasue", "Pop", "Pret", "Krahang", "Scarecrow", "Shadow" }

local function rand(r: { number }): number
	return r[1] + math.random() * (r[2] - r[1])
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

local function shopFront(): Vector3
	local wps = Workspace:FindFirstChild("VehicleWaypoints")
	local stop = wps and wps:FindFirstChild("StopPoint") :: BasePart?
	return if stop then stop.Position else Vector3.new(-4, 2, -7)
end

local function fade(root: Instance, t: number, time: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" and d.Name ~= "FocusMarker" then
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = t }):Play()
			else
				d.Transparency = t
			end
		end
	end
end

-- ---------------------------------------------------------------- ผีมีกระดูก (ท่าเล่นบนเครื่องนี้เอง)
local function animator(m: Model): Animator
	local ac = m:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
	ac.Parent = m
	local an = ac:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	an.Parent = ac
	return an :: Animator
end

local function play(m: Model, clip: string)
	local set = animIds[m.Name]
	local id = set and set[clip]
	if not id then
		return
	end
	local an = animator(m)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local tr = an:LoadAnimation(a)
	tr.Looped = not (animIds.ONCE and animIds.ONCE[clip])
	tr:Play(0.3)
	for _, other in ipairs(an:GetPlayingAnimationTracks()) do
		if other ~= tr then
			other:Stop(0.3)
		end
	end
end

local function spawnRigged(name: string): Model?
	local t = models:FindFirstChild(name) :: Model?
	if not t then
		return nil
	end
	local m = t:Clone()
	local sc = animIds.SCALE and animIds.SCALE[name]
	if sc and sc ~= 1 then
		m:ScaleTo(sc)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	return m
end

-- แสงเรืองจางๆ ตรงอก (ที่มืดก็ยังเห็นเงาผี)
local function addGlow(m: Model, color: Color3)
	local root = m:FindFirstChild("RootPart") :: BasePart?
	if not root then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 3.5, -1)
	a.Parent = root
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 11
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = a
end

-- ---------------------------------------------------------------- โผล่ / หาย
local folder = Instance.new("Folder")
folder.Name = "LocalSceneryGhosts"
folder.Parent = Workspace
local showId = 0
local current: { kind: string, m: Model, conn: RBXScriptConnection?, hunting: boolean? }? = nil

local function hide(fadeTime: number?)
	local c = current
	current = nil
	if not c then
		return
	end
	if c.conn then
		c.conn:Disconnect()
	end
	CollectionService:RemoveTag(c.m, "SceneryGhost")
	local t = fadeTime or 1.5
	fade(c.m, 1, t)
	task.delay(t + 0.1, function()
		c.m:Destroy()
	end)
end

-- หุ่นไล่กา: ยืนครึ่งทางระหว่างที่เดิมกับตู้ปั๊ม ตาแดง พอหันไปเห็น = ไถลถอยหลังหายไปในทุ่ง
local function showScarecrow(): Model?
	local ap = Workspace:FindFirstChild("AnomalyProps")
	local src = ap and ap:FindFirstChild("Scarecrow") :: Model?
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			if string.find(d.Name, "Eye") then
				d.Color = Color3.fromRGB(255, 20, 20)
				d.Material = Enum.Material.Neon
			end
		end
	end
	local from = src:GetPivot().Position
	local front = shopFront()
	local p = from:Lerp(front, 0.2)
	p = Vector3.new(p.X, groundAt(p.X, p.Z) + (from.Y - groundAt(from.X, from.Z)), p.Z)
	-- หน้าหุ่นอยู่ฝั่ง -LookVector ของ pivot: หมุนกลับ 180° ให้หน้ามองร้าน
	m:PivotTo(CFrame.lookAt(p, Vector3.new(front.X, p.Y, front.Z)) * CFrame.Angles(0, math.pi, 0))
	m.Name = "ScarecrowLocal"
	fade(m, 1, 0)
	m.Parent = folder
	fade(m, 0, 2)
	local away = Vector3.new(from.X - p.X, 0, from.Z - p.Z).Unit
	local seenFor = 0
	local fleeing = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if fleeing or not m.Parent then
			return
		end
		local cam = Workspace.CurrentCamera
		local cf, size = m:GetBoundingBox()
		local head = cf.Position + Vector3.new(0, size.Y * 0.3, 0)
		local sp, on = cam:WorldToViewportPoint(head)
		local vs = cam.ViewportSize
		local off = Vector2.new((sp.X - vs.X / 2) / (vs.X / 2), (sp.Y - vs.Y / 2) / (vs.Y / 2)).Magnitude
		if on and sp.Z > 0 and sp.Z < 110 and off < 0.45 then
			seenFor += dt
		else
			seenFor = 0
		end
		if seenFor > 0.7 then
			fleeing = true
			conn:Disconnect()
			-- ไถลถอยหลังเร็วๆ จมลงดินนิดๆ แล้วจางหาย
			local start = m:GetPivot()
			local cv = Instance.new("CFrameValue")
			cv.Value = start
			cv.Changed:Connect(function(v)
				if m.Parent then
					m:PivotTo(v)
				end
			end)
			TweenService:Create(cv, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = start + away * 22 + Vector3.new(0, -2.5, 0) }):Play()
			fade(m, 1, 1.4)
			task.delay(1.5, function()
				cv:Destroy()
				if current and current.m == m then
					current = nil
				end
				m:Destroy()
			end)
		end
	end)
	current = { kind = "Scarecrow", m = m, conn = conn }
	return m
end

local function showShadow(): Model?
	local ap = Workspace:FindFirstChild("AnomalyProps")
	local src = ap and ap:FindFirstChild("BanyanShadowAnomaly") :: Model?
	if not src then
		return nil
	end
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanQuery = false
		end
	end
	m.Name = "ShadowLocal"
	m.Parent = folder
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(3), { Transparency = if string.find(d.Name, "Eye") then 0 else 0.35 }):Play()
		end
	end
	current = { kind = "Shadow", m = m }
	return m
end

local function shutterClosed(): boolean
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not door then
		return false
	end
	local openY = door:GetAttribute("OpenY") or 15.5
	local closedY = door:GetAttribute("ClosedY") or 6.0
	return door.Position.Y < (openY + closedY) / 2
end

-- ผู้เล่นอยู่ในร้านไหม (เหมือน CoreLoop.insideShop ฝั่ง server: ในกรอบเพิง และหลังแนวแผงสังกะสี)
local function insideShop(pos: Vector3): boolean
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not (shack and door) then
		return false
	end
	local cf, size = shack:GetBoundingBox()
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) < size.X / 2 - 0.4 and pos.Z > door.Position.Z + 0.3 and lp.Z < size.Z / 2
end

-- ตำแหน่งนี้อยู่ในตัวเพิงร้าน (กรอบกว้างกว่าผนัง 2 studs: ตัวผีไม่โผล่ผ่านผนัง/หลังคาเข้าไปในร้าน)
local function inShackBox(pos: Vector3): boolean
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	if not shack then
		return false
	end
	local cf, size = shack:GetBoundingBox()
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) < size.X / 2 + 2 and math.abs(lp.Z) < size.Z / 2 + 2
end

-- ผีมาหาได้เฉพาะคนที่ถูกขังอยู่นอกร้าน (แผงปิดแล้ว) ร้านยังเปิดอยู่ = ผีแค่ยืนมองลางๆ แล้วจางหาย (ผู้ใช้ 2026-11-05)
local function lockedOut(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and shutterClosed() and not insideShop(root.Position)
end

-- ผีอยู่ในสายตาผู้เล่นตอนนี้ไหม (อยู่ค่อนไปทางกลางจอ ไม่ไกลเกิน ไม่มีของทึบบัง)
local seeParams = RaycastParams.new()
seeParams.FilterType = Enum.RaycastFilterType.Exclude
local function inSight(p: Vector3): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local sp, on = cam:WorldToViewportPoint(p)
	if not on or sp.Z <= 0 or sp.Z > CONFIG.SeeDist then
		return false
	end
	local vs = cam.ViewportSize
	if Vector2.new((sp.X - vs.X / 2) / (vs.X / 2), (sp.Y - vs.Y / 2) / (vs.Y / 2)).Magnitude > CONFIG.SeeCenter then
		return false
	end
	local camPos = cam.CFrame.Position
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _ = 1, 6 do
		seeParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(camPos, p - camPos, seeParams)
		if not hit then
			return true
		end
		-- ใบไม้ / ของโปร่ง / ไม่มีตัวตน ไม่นับว่าบัง
		if hit.Instance.Transparency > 0.5 or not hit.Instance.CanCollide then
			table.insert(ignore, hit.Instance)
		else
			return false
		end
	end
	return true
end

-- ผีไล่ถึงแล้ว: ให้ server ตัดสินว่าใครโดน (คนนอกร้าน ล้มจนผีปั่นป่วนเสร็จ) แล้วตอบกลับว่าเครื่องนี้โดนหลอกไหม
local hitRemote: RemoteEvent? = nil
task.spawn(function()
	local r = remotes:WaitForChild("SceneryGhostHit") :: RemoteEvent
	hitRemote = r
	r.OnClientEvent:Connect(function(scared: boolean)
		local c = current
		if not c then
			return
		end
		if scared and _G.LocalJumpscare then
			_G.LocalJumpscare("Scenery_" .. c.kind, c.m)
		end
		task.delay(if scared then 0.3 else 0, function()
			if current == c then
				hide(1)
			end
		end)
	end)
end)
local function strike(kind: string)
	local r = hitRemote
	if not r then
		hide(1)
		return
	end
	r:FireServer(kind)
	local c = current
	task.delay(3, function() -- server ไม่ตอบ: จางหายเอง
		if c and current == c then
			hide(1)
		end
	end)
end

local function showRigged(kind: string, def: Kind): Model?
	local m = spawnRigged(def.model)
	if not m then
		return nil
	end
	local lift = def.lift or 0
	local from = Vector3.new(def.from[1], 0, def.from[2])
	local to = Vector3.new(def.to[1], 0, def.to[2])
	if def.front and #def.front > 0 and math.random() < (def.frontChance or 0.5) then
		local spot = def.front[math.random(#def.front)]
		to = Vector3.new(spot[1], 0, spot[2])
		local f = shopFront()
		local away = Vector3.new(to.X - f.X, 0, to.Z - f.Z)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, -1)
		from = to + away * 3
	end
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local total = dir.Magnitude
	local unit = if total > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	-- ทางเข้ามา (ผู้ใช้ 2026-11-06): ไม่ตรงดิ่ง โค้งออกข้างหนึ่งแล้ววกเข้า (ผีบินผ่านฉากแบบ path ยังเป็นเส้นตรง)
	local arcSide = if math.random() < 0.5 then -1 else 1
	local arcCtrl = (from + to) / 2 + Vector3.new(-unit.Z, 0, unit.X) * arcSide * math.clamp(total * 0.5, 0, 10)
	local function along(k: number): (Vector3, Vector3)
		if def.path then
			return from + unit * (total * k), unit
		end
		local u = 1 - k
		local p = from * (u * u) + arcCtrl * (2 * u * k) + to * (k * k)
		local tan = (arcCtrl - from) * (2 * u) + (to - arcCtrl) * (2 * k)
		tan = Vector3.new(tan.X, 0, tan.Z)
		return p, if tan.Magnitude > 0.01 then tan.Unit else unit
	end
	-- dirNow = ทิศที่หันตอนเคลื่อน / nil = หยุดอยู่ หันหาหน้าร้าน
	local hopUntil = 0 -- กระโดดอยู่ (hop): ถึงเวลานี้
	local floatSeed, floatT0 = math.random() * 100, os.clock()
	local function extraY(): number
		local y = GhostStretch.LegLift(m)
		if def.hop and os.clock() < hopUntil then
			y += math.abs(math.sin(os.clock() * math.pi * def.hop.rate)) * def.hop.height
		end
		return y
	end
	local function place(pos: Vector3, dirNow: Vector3?)
		local feet = Vector3.new(pos.X, groundAt(pos.X, pos.Z) + lift + extraY(), pos.Z)
		local look: Vector3
		if dirNow then
			look = dirNow
		elseif def.path then
			look = unit
		else
			local f = shopFront()
			look = Vector3.new(f.X - feet.X, 0, f.Z - feet.Z)
			look = if look.Magnitude > 0.01 then look.Unit else unit
		end
		if def.float then
			-- ลอย: ส่ายซ้ายขวา ขึ้นลง เอียงตัวตามทางส่าย ตลอดเวลา (ไม่ลอยนิ่งเป็นเส้นตรง)
			local off, rot = GhostFloat.Offset(floatSeed, os.clock() - floatT0, look)
			feet += off
			m:PivotTo(CFrame.lookAt(feet, feet + look) * rot)
			return
		end
		m:PivotTo(CFrame.lookAt(feet, feet + look))
	end
	place(from, unit)
	addGlow(m, def.glow or CONFIG.GlowColor)
	m:SetAttribute("FocusBone", def.focus or "head")
	fade(m, 1, 0)
	m.Parent = folder
	fade(m, 0, 2)
	play(m, def.moveClip or def.clip)
	-- ผีลอย: เร็วขึ้นตามความดุของรอบ (shared/GhostFloat)
	local floatMult = if def.float then GhostFloat.SpeedMult() else 1
	local speed = (def.speed or 1) * floatMult
	local huntSpeed = (def.huntSpeed or CONFIG.HuntSpeed) * (if def.float then 0.75 + floatMult * 0.25 else 1)
	local focusName = def.focus or "head"
	local focusBone: Bone? = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == focusName then
			focusBone = d
			break
		end
	end
	if not def.path then
		m:SetAttribute("NoStare", true) -- ผีตัวนี้เดินมาหาเมื่อถูกเห็น ไม่ใช้จ้องค้างแล้วพุ่งใส่หน้า
	end
	local t0 = os.clock()
	local arrived = false
	local pos = from
	local seenFor = 0
	local hunting = false
	local struck = false
	local huntStart = 0
	local watching = false
	local watchUntil = 0
	local function faceMe()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			if d.Magnitude > 0.1 then
				place(pos, d.Unit)
			end
		end
	end
	local function startHunt()
		hunting = true
		watching = false
		huntStart = os.clock()
		fade(m, 0, 0.6)
		if current and current.m == m then
			current.hunting = true
		end
		play(m, def.moveClip or def.clip)
		-- ผีลอยมาหา: หัวเราะคิกคักล้อเลียนก่อนโฉบเข้ามา
		local root = m:FindFirstChild("RootPart")
		local set = SoundBank.GhostSounds[kind]
		if def.float and root and set then
			SoundBank.PlayOneShot(set.laugh, root, 70, 4)
		end
	end
	-- ผีลอยไล่แบบล้อหลอก (ผู้ใช้ 2026-11-06): โฉบเข้า-ถอยออกเป็นจังหวะ ส่ายวนข้าง พุ่งเป็นพักๆ
	-- ใกล้ถึงตัว (ใน TeaseClose studs) ถอยวนรอบหนึ่งแล้วพุ่งเข้าใส่เต็มแรง
	local function teaseStep(gap: Vector3, dt: number): Vector3
		local t = os.clock() - huntStart
		local dir = gap.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local dist = gap.Magnitude
		local surge = GhostFloat.Surge(floatSeed, t)
		local fwd: number
		if dist < CONFIG.HuntReach + 4 and t > 2.5 then
			fwd = 2.2 -- เล่นพอแล้ว: พุ่งใส่
		else
			-- โฉบเข้า 2 จังหวะ ถอย 1 จังหวะ (ถอยสั้นกว่าเข้า: ยังเข้าใกล้ขึ้นเรื่อยๆ)
			local beat = math.sin(t * 2.1 + floatSeed)
			fwd = if beat > -0.45 then 1.25 * surge else -0.7
		end
		-- วนอ้อมเข้ามาทางข้างเดียว (ยิ่งไกลยิ่งวนกว้าง) + ส่ายไปมา: ไม่พุ่งตรงเข้าหาเป็นเส้นตรง
		local orbit = arcSide * 1.1 * math.clamp((dist - CONFIG.HuntReach) / 14, 0, 1) + math.cos(t * 1.4 + floatSeed) * 0.6
		return (dir * fwd + side * orbit) * huntSpeed * dt
	end
	-- ผีเดินไล่ (ไม่ลอย): เดินโค้งอ้อมเข้ามาเหมือนกัน ไม่ตรงดิ่ง
	local function walkStep(gap: Vector3, dt: number): Vector3
		local dir = gap.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local curl = arcSide * 0.75 * math.clamp((gap.Magnitude - CONFIG.HuntReach) / 14, 0, 1)
		return (dir + side * curl).Unit * huntSpeed * dt
	end
	local conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent or struck then
			return
		end
		-- ร้านยังเปิด: ยืนนิ่งหันมามองคนที่เห็น จางๆ แล้วหายไป (แผงปิดลงระหว่างนั้นและคนนี้อยู่นอกร้าน = เริ่มมาหา)
		if watching then
			if lockedOut() then
				startHunt()
				return
			end
			faceMe()
			if os.clock() >= watchUntil then
				hide(2.5)
			end
			return
		end
		if hunting then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not (hum and root) or hum.Health <= 0 or Lighting:GetAttribute("Cutscene") == true then
				hide(1)
				return
			end
			-- แผงเปิดขึ้น / หนีเข้าร้านได้แล้ว = เลิกไล่ กลับไปยืนมองแล้วจางหาย
			if not lockedOut() then
				hunting = false
				watching = true
				watchUntil = os.clock() + CONFIG.WatchTime
				fade(m, CONFIG.WatchTransparency, 1)
				if current and current.m == m then
					current.hunting = false
				end
				play(m, def.clip)
				return
			end
			local gap = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			if gap.Magnitude <= CONFIG.HuntReach or os.clock() - huntStart >= CONFIG.HuntMax then
				struck = true
				strike(kind)
				return
			end
			if def.float then
				-- ส่าย/วนล้อหลอกแล้วห้ามทะลุเข้าตัวร้าน: ก้าวที่จะเข้าไปในกรอบเพิง = ไม่ขยับ
				local nextPos = pos + teaseStep(gap, dt)
				if inShackBox(pos) or not inShackBox(nextPos) then
					pos = nextPos
				end
			else
				local nextPos = pos + walkStep(gap, dt)
				if inShackBox(pos) or not inShackBox(nextPos) then
					pos = nextPos
				else
					pos += gap.Unit * huntSpeed * dt -- โค้งแล้วจะชนร้าน: ตรงเข้าหาแทน
				end
			end
			hopUntil = os.clock() + 0.1
			place(pos, gap.Unit)
			return
		end
		-- หันไปเห็น = เริ่มเดินเข้าหา
		if not def.path then
			local p = if focusBone then focusBone.WorldPosition else m:GetPivot().Position + Vector3.new(0, 4, 0)
			seenFor = if inSight(p) then seenFor + dt else 0
			if seenFor >= CONFIG.SeeTime then
				if lockedOut() then
					startHunt()
				else
					watching = true
					watchUntil = os.clock() + CONFIG.WatchTime
					fade(m, CONFIG.WatchTransparency, 1)
					play(m, def.clip)
				end
				return
			end
		end
		if arrived then
			if def.float then
				place(pos) -- ลอยอยู่กับที่ก็ยังส่าย/ขึ้นลง
			end
			return
		end
		local s = (os.clock() - t0) * speed
		if s >= total then
			arrived = true
			pos = to
			place(to)
			if def.moveClip then
				play(m, def.clip)
			end
			if def.after then
				task.delay(def.after[1], function()
					if m.Parent and not hunting then
						play(m, def.after[2])
					end
				end)
			end
			if def.path then
				hide(1)
			end
			return
		end
		local tan: Vector3
		pos, tan = along(s / total)
		hopUntil = os.clock() + 0.1
		place(pos, tan)
	end)
	-- ขาโย่ง: ค่อยๆ ยืดหลังโผล่มาได้แป๊บ (ยกตัวตามความยาวขาที่เพิ่ม: เรียก place ซ้ำทุกเฟรมระหว่างยืด)
	if def.longLegs then
		task.delay(2.2, function()
			if not m.Parent then
				return
			end
			GhostStretch.Set(m, "leg", nil, def.longLegs, 2.5)
			local t1 = os.clock()
			while m.Parent and os.clock() - t1 < 2.7 do
				if arrived and not hunting and not watching then
					place(pos)
				end
				RunService.Heartbeat:Wait()
			end
		end)
		-- ยืนอยู่ขายาว: เดินโย่งไปมาช้าๆ แถวที่ของมัน
		task.spawn(function()
			local dirSign = 1
			while m.Parent do
				task.wait(3.5)
				if m.Parent and arrived and not hunting and not watching then
					play(m, def.moveClip or def.clip)
					local t1 = os.clock()
					local side = Vector3.new(-unit.Z, 0, unit.X) * dirSign
					while m.Parent and arrived and not hunting and not watching and os.clock() - t1 < 2.5 do
						local dt = RunService.Heartbeat:Wait()
						pos += side * 1.4 * dt
						place(pos, side)
					end
					dirSign = -dirSign
					if m.Parent and not hunting then
						play(m, def.clip)
					end
				end
			end
		end)
	end
	-- ยืดแขนหยิบของ: หลังหยุดสักพัก แขนยาวออกไป ค้าง แล้วหดกลับ (วนซ้ำ)
	if def.reach then
		local r = def.reach
		task.spawn(function()
			while m.Parent and not arrived do
				task.wait(0.2)
			end
			task.wait(r.at)
			while m.Parent do
				if not hunting then
					GhostStretch.Set(m, "arm", r.side, r.factor, 1.3)
					task.wait(1.3 + r.hold)
					if not m.Parent then
						break
					end
					GhostStretch.Set(m, "arm", r.side, 1, 0.9)
				end
				task.wait(r.every)
				if m.Parent and not hunting then
					play(m, "nak_reach")
				end
				task.wait(0.8)
			end
		end)
	end
	current = { kind = kind, m = m, conn = conn }
	return m
end

local function show(kind: string)
	if current then
		hide(0.5)
	end
	local def = KINDS[kind]
	if not def then
		return
	end
	local m: Model?
	if kind == "Scarecrow" then
		m = showScarecrow()
	elseif kind == "Shadow" then
		m = showShadow()
	else
		m = showRigged(kind, def)
	end
	if not m then
		return
	end
	-- หุ่นไล่กาหนีเองตอนโดนมอง: ไม่ต้องให้พุ่งใส่หน้า
	if kind ~= "Scarecrow" then
		showId += 1
		m:SetAttribute("SceneryKind", kind)
		m:SetAttribute("ShowId", showId)
		CollectionService:AddTag(m, "SceneryGhost")
	end
	local mine = m
	task.delay(rand(CONFIG.Stay), function()
		if current and current.m == mine and not current.hunting then
			hide()
		end
	end)
end

-- admin (client/AdminPanel): เรียกผีฉากบนเครื่องตัวเอง ผ่าน attribute "SceneryTest" ของผู้เล่น ("ชนิด:เลขสุ่ม" / "hide:..")
player:GetAttributeChangedSignal("SceneryTest"):Connect(function()
	local v = player:GetAttribute("SceneryTest")
	local kind = if type(v) == "string" then string.match(v, "^(%w+)") else nil
	if kind == "hide" then
		hide(0.5)
	elseif kind then
		show(kind)
	end
end)

-- ---------------------------------------------------------------- ตารางเวลาของเครื่องนี้
local function canShow(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return remotes:GetAttribute("ShopOpen") == true
		and remotes:GetAttribute("BigEvent") == nil
		and Lighting:GetAttribute("Cutscene") ~= true
		and Lighting:GetAttribute("Dawn") ~= true
		and hum ~= nil
		and hum.Health > 0
end

task.spawn(function()
	while true do
		-- รอเปิดร้าน = เริ่มคืนใหม่ของเครื่องนี้: สุ่มชนิดผีที่จะเจอคืนนี้
		while remotes:GetAttribute("ShopOpen") ~= true do
			task.wait(1)
		end
		local pool = table.clone(KIND_LIST)
		local tonight = {}
		for _ = 1, math.min(CONFIG.KindsPerNight, #pool) do
			table.insert(tonight, table.remove(pool, math.random(#pool)))
		end
		local shown = 0
		local nextAt = os.clock() + rand(CONFIG.FirstAfter)
		while remotes:GetAttribute("ShopOpen") == true do
			task.wait(1)
			if current and (remotes:GetAttribute("BigEvent") ~= nil or Lighting:GetAttribute("Dawn") == true) then
				hide(1) -- ผีใหญ่มา / ฟ้าสางจบคืน: ผีฉากหลบไปก่อน
			end
			if shown < CONFIG.MaxPerNight and os.clock() >= nextAt and not current and canShow() then
				show(tonight[math.random(#tonight)])
				shown += 1
				nextAt = os.clock() + rand(CONFIG.Every)
			end
		end
		hide(0.5)
	end
end)

-- ---------------------------------------------------------------- ไฟดับ + ตาทิพย์: ศพห่อผ้าขาวเต็มทุ่ง
local swarm: { Model } = {}
local swarmReported = false
local function sightOpen(): boolean
	local grade = Lighting:FindFirstChild("PrayerSight")
	return player:GetAttribute("Praying") == true and grade ~= nil and grade:GetAttribute("Open") == true
end

local function clearSwarm()
	for _, m in ipairs(swarm) do
		fade(m, 1, 1.2)
		task.delay(1.3, function()
			m:Destroy()
		end)
	end
	table.clear(swarm)
end

local function buildSwarm()
	local center = Vector3.new(0, 0, 6)
	for i = 1, CONFIG.SwarmCount do
		local m = spawnRigged("ghost_shroud")
		if not m then
			return
		end
		local a = (i / CONFIG.SwarmCount) * math.pi * 2 + math.random() * 0.4
		local r = rand(CONFIG.SwarmRadius)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local feet = Vector3.new(x, groundAt(x, z) + 0.4, z)
		m:PivotTo(CFrame.lookAt(feet, Vector3.new(center.X, feet.Y, center.Z)))
		fade(m, 1, 0)
		m.Parent = folder
		fade(m, 0.15, 2.5)
		play(m, "shroud_idle")
		table.insert(swarm, m)
	end
end

local lastShop = false
RunService.Heartbeat:Connect(function()
	local shop = remotes:GetAttribute("ShopOpen") == true
	if shop and not lastShop then
		swarmReported = false -- คืนใหม่
	end
	lastShop = shop
	local want = ReplicatedStorage:GetAttribute("PowerOn") == false and sightOpen() and Lighting:GetAttribute("Cutscene") ~= true
	if want and #swarm == 0 then
		buildSwarm()
		if not swarmReported then
			swarmReported = true
			local r = remotes:FindFirstChild("OutageSwarm") :: RemoteEvent?
			if r then
				r:FireServer()
			end
		end
	elseif not want and #swarm > 0 then
		clearSwarm()
	end
end)
