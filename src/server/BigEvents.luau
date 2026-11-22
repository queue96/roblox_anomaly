--!strict
-- BigEvents.luau (ModuleScript ฝั่ง Server)
-- ผีใหญ่บุกประชิด (GDD ข้อ 3 Tier 3 / ข้อ 27-30): ทุกตัวรับมือแบบเดียวกัน = ปิดแผงร้าน + ดับไฟ (ผู้ใช้ 2026-11-21:
-- ตัดนั่งยอง / ยืนนิ่ง / ปิดไฟฉายออก กติกาเหล่านั้นยังอยู่ในโค้ด เปิดได้ที่ rules ของแต่ละตัว)
--   Krasue  แสงไฟผีกระสือลอยจากเถียงนา มาบินวนรอบเพิง 2 รอบ (คนในร้านเห็นแสงลอดช่องเพิง) แล้วลอยกลับ ร้องเพลงวนตลอด
--   Pret    เปรตตัวสูงเท่าต้นตาลเดินผ่านถนนหน้าร้าน
--   Funeral ขบวนคนชุดขาวลอยผ่านถนนหน้าร้าน (ไม่อยู่ในการสุ่ม)
--   Pop     ปอบเดินกระตุกมาเคาะแผงหน้าร้าน (ไม่อยู่ในการสุ่ม)
-- ลำดับ: Warn (ผีเดินเข้ามา ข้อความบอกวิธีรับมือ) -> Danger (ผีถึงหน้าร้าน ตรวจกติกาทุก 0.25 วินาที) -> Leave (ผีออกไป)
--   ทำผิดครั้งแรก = จบช่วง Danger ทันที ผีเล่นท่าโกรธ คืนรายชื่อคนที่โดน (CoreLoop ตัดธูป + ผีหลอก)
-- ไฟ = server/Power (สะพานไฟ CutoutSwitch) · นั่งยอง = player attribute "Crouching" (Remotes.Crouch จาก client/Animate)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))
local Power = require(script.Parent:WaitForChild("Power"))
local GhostFloat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostFloat")) :: any

local BigEvents = {}

BigEvents.Config = {
	Warn = 15, -- วินาที: ผีเดินเข้ามา ให้เวลาวิ่งไปสับสะพานไฟ / ปิดแผง / นั่งยอง
	Danger = 8, -- วินาที: ผีอยู่หน้าร้าน ตรวจกติกา
	Leave = 9, -- วินาที: ผีออกไป
	Grace = 0.6, -- ช่วงแรกของ Danger ยังไม่ตรวจ (คนที่กำลังจะนั่งลงพอดี)
	StillSpeed = 1.5, -- เร็วกว่านี้ (studs/วินาที) = ขยับ
}
-- ตัด Funeral (ขบวนแห่ศพ) ออกจากการสุ่มแล้ว (2026-11-16) · ตัด Pop (ปอบเคาะแผง) ออก (ผู้ใช้ 2026-11-21) เรียกได้จากแผง admin
BigEvents.Kinds = { "Krasue", "Pret" }

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CrouchRemote = remotes:FindFirstChild("Crouch") or Instance.new("RemoteEvent")
CrouchRemote.Name = "Crouch"
CrouchRemote.Parent = remotes
CrouchRemote.OnServerEvent:Connect(function(p: Player, on: any)
	p:SetAttribute("Crouching", on == true)
end)
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		p:SetAttribute("Crouching", false)
	end)
end)

-- ---------------------------------------------------------------- ผังเดิน
-- pts = ตำแหน่ง (x, z) ตอนเริ่ม / จบ Warn / จบ Danger / จบ Leave (เดินเป็นเส้นตรงในแต่ละช่วง)
-- lift = ยกจากพื้นในแต่ละจุด · clips = ท่าช่วง Warn / Danger / Leave · angry = ท่าตอนจับได้ว่ามีคนทำผิด
-- face = ทิศที่หันตอนอยู่กับที่ (ไม่ใส่ = หันหาหน้าร้าน)
type Ghost = {
	name: string,
	pts: { { number } },
	lift: { number }?,
	clips: { string },
	angry: string?,
	face: Vector3?,
	float: boolean?, -- ลอย (shared/GhostFloat): ส่าย ขึ้นลง เอียงตัว พุ่งเป็นพักๆ เร็วตามความดุของรอบ
	mirrorOf: number?, -- คนแบกคานขวา: ท่าสะท้อนซ้าย-ขวาของผีลำดับนี้ (client/MirrorPose) ยืนตามโลง ไม่เดินตาม pts
	-- เส้นทางบินของตัวเองทั้ง 3 ช่วง (กระสือ, ผู้ใช้ 2026-11-22) แทน pts:
	--   Warn   บินโค้งเข้ามาจากนอกแมพ far0 สูง hFar ลดระดับลงถึงจุดเข้า (มุม a0 บนวงรีรอบเพิง)
	--   Danger วนรอบเพิงจากมุม a0 ถึง a1 แบบไม่เป็นวงกลมเป๊ะ: เร็ว-ช้า ห่าง-ใกล้ผนัง ขึ้น-ลง (noise, ปลายทั้งสองข้างตรงวงรี)
	--   Leave  ออกจากมุม a1 บินโค้งเร่งออกไปนอกแมพ far1 ไต่ระดับขึ้น
	-- หันหน้าไปตามทางบินเสมอ · lift = สูงจากพื้นด้านหลัง/ข้าง, liftFront = สูงด้านหน้า (ข้ามตู้ปั๊ม)
	orbit: {
		cx: number,
		cz: number,
		rx: number,
		rz: number,
		a0: number,
		a1: number,
		dur: number,
		hx: number,
		hz: number,
		clear: number,
		lift: number,
		liftFront: number,
		far0: Vector2,
		far1: Vector2,
		hFar: number,
		bend0: number,
		bend1: number,
		seed: number,
	}?,
}
type Plan = {
	ghosts: { Ghost },
	rules: { lights: boolean, crouch: boolean, still: boolean, shutter: boolean, flashlight: boolean },
	voice: string?,
	laugh: string?,
	song: string?, -- SoundBank preset วนตลอดตั้งแต่โผล่จนจางหาย (แทน voice/laugh)
	focus: string?,
	glow: Color3?,
	glowRange: number?,
	warn: number?, -- วินาทีช่วง Warn ของตัวนี้ (ไม่ใส่ = Config.Warn)
	danger: number?, -- วินาทีช่วง Danger ของตัวนี้ (ไม่ใส่ = Config.Danger)
	leave: number?, -- วินาทีช่วง Leave ของตัวนี้ (ไม่ใส่ = Config.Leave)
	coffin: boolean?, -- แบกโลง (ServerStorage.GhostProps.Coffin) ด้วยกำปั้นขวาของผีตัวแรก
	knock: boolean?, -- เสียงเคาะแผงสังกะสีเป็นจังหวะตลอดช่วง Danger (ปอบเคาะแผง: เดิมเงียบ มีแค่ท่า 2026-11-08)
}

-- ขบวนแห่ศพ: แบกโลง 2 คาน คานละ 2 คน (หน้า/หลัง ห่างกัน COFFIN_GAP) ศพห่อผ้าลอยตามหลัง
--   คานซ้าย = ชาย 2 คน ท่า coffin_walk (บ่าขวา) / คานขวา = หญิง 2 คน ท่าเดียวกันสะท้อนเป็นบ่าซ้าย (client/MirrorPose)
--   โลง: origin = กลางคานซ้าย ตัวโลงอยู่ทาง +X (ขวาคนแบก) คานขวาห่าง POLE_SPAN
local COFFIN_GAP = 7 -- ระยะคนแบกหน้า-หลัง (โลงยาว 10.5)
local POLE_SPAN = 3.14 -- ระยะคานซ้าย-ขวา (โลงกว้าง 3.36 กึ่งกลางที่ +1.57)
local function procession(): { Ghost }
	local list: { Ghost } = {}
	local rows = {
		{ "ghost_funeral_man", 0, "coffin_walk" },
		{ "ghost_funeral_elder_man", -COFFIN_GAP, "coffin_walk" },
		{ "ghost_shroud", -COFFIN_GAP - 5, "shroud_glide" },
	}
	for _, r in ipairs(rows) do
		local n, dx, clip = r[1] :: string, r[2] :: number, r[3] :: string
		table.insert(list, {
			name = n,
			pts = { { -78 + dx, -14 }, { -14 + dx, -14 }, { 20 + dx, -14 }, { 58 + dx, -14 } },
			lift = if n == "ghost_shroud" then { 0.5, 0.5, 0.5, 0.5 } else nil,
			float = n == "ghost_shroud" or nil,
			clips = { clip, clip, clip },
		})
	end
	-- คานขวา: สะท้อนคนแบกหน้า (1) และหลัง (2)
	for i, n in ipairs({ "ghost_funeral_woman", "ghost_funeral_elder_woman" }) do
		table.insert(list, { name = n, pts = list[i].pts, clips = {}, mirrorOf = i })
	end
	return list
end

local function plans(): { [string]: Plan }
	-- แผงหน้าร้าน: ปอบยืนห่างแผง 1.94 studs (ระยะหมัดในท่า KnockShutter)
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	local knockX = if door then door.Position.X + 6 else 6
	local knockZ = if door then door.Position.Z - door.Size.Z / 2 - 1.94 else 6
	-- กระสือ: วงรีรอบเพิงห่างผนัง ORBIT_GAP studs (เพิง 35.4 x 24 กลางที่ (0, 17.5) วัด 2026-11-21)
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	local scx, scz, ssx, ssz = 0, 17.5, 35.4, 24
	if shack then
		local cf, sz = shack:GetBoundingBox()
		scx, scz, ssx, ssz = cf.X, cf.Z, sz.X, sz.Z
	end
	local ORBIT_GAP = 7
	local KRASUE_TIME = { warn = 24, danger = 40, leave = 22 } -- ผู้ใช้ 2026-11-22: อยู่นานขึ้น (เดิม 15 / 26 / 9)
	local ORBIT_LAPS = 2.15 -- รอบโดยประมาณในช่วง Danger (เฉลี่ย ~7.5 studs/วิ) จบอีกฟากแล้วบินออก
	local FAR = 260 -- เริ่ม/จบห่างกลางเพิง (นอกแมพ: กำแพงล่องหนอยู่ราว ±48)
	local hut = Vector2.new(-33, -58) -- เถียงนาร้างกลางทุ่ง: บินเข้ามาผ่านเหนือเถียงนา
	local rx, rz = ssx / 2 + ORBIT_GAP, ssz / 2 + ORBIT_GAP
	local a0 = math.atan2((hut.Y - scz) / rz, (hut.X - scx) / rx) -- จุดบนวงที่หันไปทางเถียงนา
	local a1 = a0 + ORBIT_LAPS * 2 * math.pi
	local c = Vector2.new(scx, scz)
	local out1 = Vector2.new(rx * math.cos(a1), rz * math.sin(a1)).Unit
	local seed = math.random() * 100
	local orbit = {
		cx = scx,
		cz = scz,
		rx = rx,
		rz = rz,
		a0 = a0,
		a1 = a1,
		dur = KRASUE_TIME.danger,
		hx = ssx / 2, -- ครึ่งกว้าง/ลึกของเพิง (กันวงรีตัดมุม)
		hz = ssz / 2,
		clear = 4, -- ห่างผนังอย่างน้อย (studs)
		lift = 7,
		liftFront = 12.5, -- ด้านหน้ามีตู้ปั๊มสูง 8: ไส้ห้อยต่ำกว่าหัว ~2.5 (ตู้อยู่ที่ front ~0.8)
		far0 = c + (hut - c).Unit * FAR,
		far1 = c + out1 * FAR,
		hFar = 26,
		bend0 = (if math.random() < 0.5 then -1 else 1) * (25 + math.random() * 25), -- ทางโค้งออกข้าง (studs)
		bend1 = (if math.random() < 0.5 then -1 else 1) * (25 + math.random() * 25),
		seed = seed,
	}
	local SHUT_DARK = { lights = true, crouch = false, still = false, shutter = true, flashlight = false }
	return {
		Krasue = {
			ghosts = {
				{
					name = "Krasue",
					pts = { { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 } }, -- ไม่ใช้: บินตาม orbit ทั้ง 3 ช่วง
					clips = { "Float", "Float", "Float" },
					angry = "Lunge",
					float = true,
					orbit = orbit,
				},
			},
			rules = SHUT_DARK,
			song = "Ghost_Krasue_Song", -- ร้องเพลงวนจนบินพ้นแมพ (เดิม voice แม่นาค + หัวเราะปอบ)
			focus = "Head",
			glow = Color3.fromRGB(255, 110, 40),
			glowRange = 20, -- แสงส่องลอดช่องเพิงเข้าไปถึงคนที่หลบในร้าน
			warn = KRASUE_TIME.warn,
			danger = KRASUE_TIME.danger,
			leave = KRASUE_TIME.leave,
		},
		Pret = {
			ghosts = {
				{ name = "Pret", pts = { { -86, -17 }, { -18, -17 }, { 18, -17 }, { 58, -17 } }, clips = { "TallSlowWalk", "TallSlowWalk", "TallSlowWalk" }, angry = "Shriek" },
			},
			rules = SHUT_DARK,
			voice = "Ghost_Pret",
			laugh = "Ghost_Pret_Laugh",
		},
		Funeral = {
			ghosts = procession(),
			rules = SHUT_DARK,
			voice = "Ghost_Showtime",
			coffin = true,
		},
		Pop = {
			ghosts = {
				{
					name = "Pop",
					pts = { { 26, -22 }, { knockX, knockZ }, { knockX, knockZ }, { 32, -32 } },
					clips = { "TwitchWalk", "KnockShutter", "TwitchWalk" },
					angry = "PossessedSnap",
					face = Vector3.new(0, 0, 1),
				},
			},
			rules = SHUT_DARK,
			voice = "Ghost_Pop",
			laugh = "Ghost_Pop_Laugh",
			knock = true,
		},
	}
end

-- ---------------------------------------------------------------- ช่วยเหลือ
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

local function fade(root: Instance, t: number, time: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = t }):Play()
			else
				d.Transparency = t
			end
		end
	end
end

local function shopFront(): Vector3
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	return if door then door.Position else Vector3.new(0, 0, 8)
end

local function shutterClosed(): boolean
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not door then
		return true
	end
	local openY = door:GetAttribute("OpenY") or 15.5
	local closedY = door:GetAttribute("ClosedY") or 6.0
	return door.Position.Y < (openY + closedY) / 2
end

-- ผู้เล่นที่ต้องรับมือ: ยังมีชีวิต ไม่ได้ถูกยึดตัว (ตาย / คัทซีน)
local function activePlayers(): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root and hum.Health > 0 and not root.Anchored then
			table.insert(out, p)
		end
	end
	return out
end

local function flashlightOn(p: Player): boolean
	local c = p.Character
	if not c then
		return false
	end
	for _, t in ipairs(c:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("On") == true then
			return true
		end
	end
	return false
end

-- คนนี้ทำผิดอะไร (nil = ไม่ผิด)
local function playerFault(p: Player, rules: any): string?
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if rules.crouch and p:GetAttribute("Crouching") ~= true then
		return "Crouch"
	end
	if rules.still then
		local v = root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > BigEvents.Config.StillSpeed then
			return "Move"
		end
	end
	if rules.flashlight and flashlightOn(p) then
		return "Flashlight"
	end
	return nil
end

-- ---------------------------------------------------------------- เดินตามผัง
type Live = { m: Model, g: Ghost, seed: number, t0: number }

-- ทางบินของ orbit (กระสือ) ณ ช่วง phase ที่ระยะ a (0..1): คืน (x, z, สูงจากพื้น)
local function onEllipse(o: any, ang: number, k: number): (number, number)
	return o.cx + o.rx * k * math.cos(ang), o.cz + o.rz * k * math.sin(ang)
end
-- k ต่ำสุดที่จุดบนวงรีมุม ang ยังพ้นกรอบเพิง + clear (วงรีตัดมุมสี่เหลี่ยม)
local function minK(o: any, ang: number): number
	local c, s = math.abs(math.cos(ang)), math.abs(math.sin(ang))
	local kx = if c > 1e-3 then (o.hx + o.clear) / (o.rx * c) else math.huge
	local kz = if s > 1e-3 then (o.hz + o.clear) / (o.rz * s) else math.huge
	return math.min(kx, kz)
end
local function liftAt(o: any, ang: number): number
	return o.lift + (o.liftFront - o.lift) * math.max(0, -math.sin(ang)) -- ด้านหน้า (z น้อย) = สูงขึ้นข้ามตู้ปั๊ม
end
local function orbitAt(o: any, phase: number, a: number): (number, number, number)
	if phase == 2 then
		-- วนรอบเพิงแบบมีชีวิต: มุมเดินหน้าเฉลี่ยคงที่ + ส่ายเร็ว-ช้า, ระยะห่างผนังยืด-หด, ขึ้น-ลง
		-- env = 0 ที่ต้น/ปลายช่วง: เริ่มและจบตรงวงรีพอดี ต่อกับทางเข้า/ทางออกไม่สะดุด
		local t = a * o.dur
		local env = math.sin(math.pi * a)
		local sd = o.seed
		local ang = o.a0 + (o.a1 - o.a0) * a + env * (0.8 * math.noise(t * 0.09, sd, 1.1) + 0.2 * math.sin(t * 0.29 + sd))
		local k = math.clamp(1 + env * (0.36 * math.noise(t * 0.13, sd, 3.3) + 0.06 * math.sin(t * 0.47 + sd)), 0.84, 1.3)
		-- วงรีตัดมุมเพิง (เพิงเป็นสี่เหลี่ยม): ดันออกให้พ้นกรอบเพิง + clear เสมอ (ต้น/ปลายช่วงใช้ k = max(1, minK) ตรงกับทางเข้า/ออก)
		k = math.max(k, minK(o, ang))
		local x, z = onEllipse(o, ang, k)
		local front = math.max(0, -math.sin(ang))
		local h = liftAt(o, ang) + env * (5 * math.max(-0.25, math.noise(t * 0.19, sd, 7.7)) + 1.0 * math.sin(t * 0.8 + sd * 2))
		-- ด้านหน้าห้ามต่ำกว่า liftFront (ตู้ปั๊มสูง 8 ไส้ห้อยใต้หัว ~2.5) ด้านหลังลงต่ำได้ถึง lift - 1.5
		h = math.max(h, (o.lift - 1.5) + (o.liftFront - o.lift + 1.5) * front)
		return x, z, h
	end
	local p0: Vector2, p1: Vector2, h0: number, h1: number, bend: number, u: number
	if phase == 1 then
		local ex, ez = onEllipse(o, o.a0, math.max(1, minK(o, o.a0)))
		p0, p1, h0, h1, bend = o.far0, Vector2.new(ex, ez), o.hFar, liftAt(o, o.a0), o.bend0
		u = a * a * (3 - 2 * a) -- ลดระดับนุ่มๆ
	else
		local ex, ez = onEllipse(o, o.a1, math.max(1, minK(o, o.a1)))
		p0, p1, h0, h1, bend = Vector2.new(ex, ez), o.far1, liftAt(o, o.a1), o.hFar + 6, o.bend1
		u = a ^ 1.6 -- ไต่ระดับเร็วขึ้นเรื่อยๆ ตอนบินจากไป
	end
	local d = p1 - p0
	local side = if d.Magnitude > 0.01 then Vector2.new(-d.Y, d.X).Unit else Vector2.zero
	local p = p0 + d * a + side * (math.sin(math.pi * a) * bend)
	return p.X, p.Y, h0 + (h1 - h0) * u
end

local function placeAt(e: Live, phase: number, a: number)
	local o = e.g.orbit
	if o then
		-- หันหน้าไปทางที่บินจริง (ผู้ใช้ 2026-11-21: ไม่หันมองคนในร้าน)
		local x, z, h = orbitAt(o, phase, a)
		local da = 0.004
		local xa, za
		if a + da <= 1 then
			xa, za = orbitAt(o, phase, a + da)
		else
			local xb, zb = orbitAt(o, phase, a - da)
			xa, za = 2 * x - xb, 2 * z - zb
		end
		local feet = Vector3.new(x, groundAt(x, z) + h, z)
		local look = Vector3.new(xa - x, 0, za - z)
		if look.Magnitude < 1e-3 then
			local lv = e.m:GetPivot().LookVector
			look = Vector3.new(lv.X, 0, lv.Z)
		end
		look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
		if e.g.float then
			local off, rot = GhostFloat.Offset(e.seed, os.clock() - e.t0, look)
			feet += off
			e.m:PivotTo(CFrame.lookAt(feet, feet + look) * rot)
		else
			e.m:PivotTo(CFrame.lookAt(feet, feet + look))
		end
		return
	end
	local p0, p1 = e.g.pts[phase], e.g.pts[phase + 1]
	local x = p0[1] + (p1[1] - p0[1]) * a
	local z = p0[2] + (p1[2] - p0[2]) * a
	local lift = 0
	if e.g.lift then
		lift = e.g.lift[phase] + (e.g.lift[phase + 1] - e.g.lift[phase]) * a
	end
	local feet = Vector3.new(x, groundAt(x, z) + lift, z)
	local dir = Vector3.new(p1[1] - p0[1], 0, p1[2] - p0[2])
	local look: Vector3
	if dir.Magnitude > 0.5 then
		look = dir.Unit
	elseif e.g.face then
		look = e.g.face
	else
		local f = shopFront()
		look = Vector3.new(f.X - x, 0, f.Z - z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, 1)
	end
	if e.g.float then
		-- ลอย: ส่ายซ้ายขวา ขึ้นลง เอียงตัวตามทางส่าย (ไม่ลอยเป็นเส้นตรงนิ่งๆ)
		local off, rot = GhostFloat.Offset(e.seed, os.clock() - e.t0, look)
		feet += off
		e.m:PivotTo(CFrame.lookAt(feet, feet + look) * rot)
		return
	end
	e.m:PivotTo(CFrame.lookAt(feet, feet + look))
end

-- ---------------------------------------------------------------- รัน
-- ctx.notice(key, seconds, players?) ข้อความล่างจอ · คืน { ok, faults = { [Player] = เหตุผล }, team = เหตุผลรวม?, group }
function BigEvents.Run(kind: string, ctx: { notice: (string, number, { Player }?) -> () }): { [string]: any }
	local plan = plans()[kind]
	if not plan then
		return { ok = true, faults = {} }
	end
	local cfg = BigEvents.Config
	local group = Instance.new("Model")
	group.Name = "BigEvent_" .. kind
	group:SetAttribute("FocusBone", plan.focus or "head")
	local live: { Live } = {}
	for _, g in ipairs(plan.ghosts) do
		local m = GhostNPC.Spawn(g.name, CFrame.new(), g.clips[1] or nil)
		if m then
			m.Parent = group
			local e = { m = m, g = g, seed = math.random() * 100, t0 = os.clock() }
			placeAt(e, 1, 0)
			table.insert(live, e)
		end
	end
	if #live == 0 then
		group:Destroy()
		return { ok = true, faults = {} }
	end
	-- คนแบกคานขวา: client/MirrorPose สะท้อนท่าของคนแบกคานซ้ายให้ทุกเฟรม (ตัวนี้ไม่มีท่าของตัวเอง)
	for _, e in ipairs(live) do
		local src = e.g.mirrorOf and live[e.g.mirrorOf]
		if src then
			local ov = Instance.new("ObjectValue")
			ov.Name = "MirrorSource"
			ov.Value = src.m
			ov.Parent = e.m
			-- Animator ที่ไม่มีท่าเล่นก็ยังรีเซ็ตกระดูกทุกเฟรม (ทับท่าสะท้อน): เอาออก
			for _, ac in ipairs(e.m:GetDescendants()) do
				if ac:IsA("AnimationController") or ac:IsA("Animator") then
					ac:Destroy()
				end
			end
			game:GetService("CollectionService"):AddTag(e.m, "MirrorPose")
		end
	end
	local root = live[1].m:FindFirstChild("RootPart") :: BasePart?
	-- โลง: origin = กลางคานขวา (กำปั้นขวาคนแบก) หน้าโลง = หน้าคนแบก วางตามมือขวาของคนแบกหน้าทุกเฟรม (โยกตามก้าว)
	local coffin: Model? = nil
	local hand: Bone? = nil
	local props = game:GetService("ServerStorage"):FindFirstChild("GhostProps")
	local ct = plan.coffin and props and props:FindFirstChild("Coffin") :: Model?
	if ct then
		coffin = ct:Clone()
		-- moved by script every frame: no physics, no pushing players (a push would count as a "Move" fault)
		for _, d in ipairs((coffin :: Model):GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end
		;(coffin :: Model).Parent = group
		-- โลงขยับตามมือคนแบกทุกเฟรม: เครื่องผู้เล่นเกลี่ยให้ลื่นพร้อมผี (shared/NetSmooth)
		require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetSmooth")).Track(coffin)
		for _, d in ipairs(live[1].m:GetDescendants()) do
			if d:IsA("Bone") and d.Name == "hand.R" then
				hand = d
				break
			end
		end
	end
	local function carry()
		if coffin and hand then
			local rot = live[1].m:GetPivot().Rotation
			-- มือคนแบกหน้าจับที่ปลายคานหน้า: กลางคานอยู่หลังมือครึ่งระยะคนแบก
			local cp = CFrame.new(hand.TransformedWorldCFrame.Position) * rot * CFrame.new(0, 0, COFFIN_GAP / 2)
			coffin:PivotTo(cp)
			-- คนแบกคานขวา: ตำแหน่งสะท้อนของคนแบกคานซ้ายข้ามแนวกลางโลง
			for _, e in ipairs(live) do
				local src = e.g.mirrorOf and live[e.g.mirrorOf]
				if src then
					local rel = cp:PointToObjectSpace(src.m:GetPivot().Position)
					e.m:PivotTo(cp * CFrame.new(POLE_SPAN - rel.X, rel.Y, rel.Z))
				end
			end
		end
	end
	carry()
	if plan.glow and root then
		local l = Instance.new("PointLight")
		l.Color = plan.glow
		l.Range = plan.glowRange or 14
		l.Brightness = 2
		l.Parent = root
	end
	fade(group, 1, 0)
	group.Parent = Workspace:FindFirstChild("AnomalyProps") or Workspace
	fade(group, 0, 2.5)
	local song: Sound? = nil
	if root and plan.song then
		song = SoundBank.CreateSound(plan.song, root, 140)
		if song then
			local target = song.Volume
			song.Volume = 0
			song:Play()
			TweenService:Create(song, TweenInfo.new(2.5), { Volume = target }):Play()
		end
	end
	local function fadeSong(t: number)
		if song then
			TweenService:Create(song, TweenInfo.new(t), { Volume = 0 }):Play()
		end
	end
	if root and plan.voice then
		SoundBank.PlayOneShot(plan.voice, root, 160, 6)
	end
	-- ระยะเวลาแต่ละช่วง (กระสืออยู่นานกว่าตัวอื่น)
	local warnT = plan.warn or cfg.Warn
	local dangerT = plan.danger or cfg.Danger
	local leaveT = plan.leave or cfg.Leave
	ctx.notice("Big_" .. kind .. "_Warn", warnT)

	-- ขยับตามผังทุกเฟรม (phase 1 = Warn, 2 = Danger, 3 = Leave)
	local durations = { warnT, dangerT, leaveT }
	local phase = 1
	local phaseStart = os.clock()
	local frozen = false
	local conn = RunService.Heartbeat:Connect(function()
		if frozen then
			return
		end
		local el = os.clock() - phaseStart
		local a = math.clamp(el / durations[phase], 0, 1)
		local fury = GhostFloat.Fury()
		for _, e in ipairs(live) do
			-- right-pole bearers follow the coffin (carry); with no coffin they walk their own path like the others
			if e.m.Parent and not (e.g.mirrorOf and coffin and hand) then
				-- ผีลอยเดี่ยว (กระสือ): ลอยเร็วตามความดุ พุ่งเป็นพักๆ ถึงก่อนแล้ววนส่ายรอ (ขบวนศพเดินพร้อมโลง ไม่เร่ง)
				-- บินตาม orbit (กระสือ): ไม่พุ่งไปรอที่ปลายทาง ความเร็วต่อเนื่องกันทุกช่วง (ความเร็วแปรผันอยู่ใน orbitAt แล้ว)
				--   Warn = เกือบคงที่ ส่ายเร็ว-ช้านิดๆ · Leave = เริ่มเท่าความเร็ววน แล้วเร่งออกไป
				if e.g.orbit then
					local o = e.g.orbit :: any
					local u = a
					if phase == 1 then
						u = math.clamp(a + 0.05 * math.noise(el * 0.35, o.seed, 4.4) * math.sin(math.pi * a), 0, 1)
					elseif phase == 3 then
						u = 0.5 * a + 0.5 * a * a
					end
					placeAt(e, phase, u)
				else
					placeAt(e, phase, if e.g.float and not coffin then GhostFloat.Progress(e.seed, el, durations[phase], fury) else a)
				end
				if e.g.mirrorOf then
					e.m:PivotTo(e.m:GetPivot() * CFrame.new(POLE_SPAN, 0, 0)) -- beside its partner, not inside it
				end
			end
		end
		carry()
	end)
	local function setPhase(n: number)
		-- จบช่วงเดิมให้ตรงจุดพอดี แล้วเริ่มช่วงใหม่
		for _, e in ipairs(live) do
			if not (e.g.mirrorOf and coffin and hand) then
				placeAt(e, phase, 1)
				if e.g.mirrorOf then
					e.m:PivotTo(e.m:GetPivot() * CFrame.new(POLE_SPAN, 0, 0))
				end
			end
		end
		carry()
		phase = n
		phaseStart = os.clock()
		for _, e in ipairs(live) do
			-- ท่าเดิม = เล่นต่อ ไม่เริ่มท่าใหม่ (ไม่สะดุดกลางก้าว)
			if e.g.clips[n] and e.g.clips[n] ~= e.g.clips[n - 1] then
				GhostNPC.Play(e.m, e.g.clips[n])
			end
		end
	end

	task.wait(warnT)
	setPhase(2)
	ctx.notice("Big_Danger", dangerT)
	if root and plan.laugh then
		SoundBank.PlayOneShot(plan.laugh, root, 160, 5)
	end
	if plan.knock then
		-- ปอบยืนเคาะแผงตลอดช่วง Danger: เสียงดังที่ตัวแผง (ได้ยินชัดจากในร้าน)
		task.spawn(function()
			local props = Workspace:FindFirstChild("InteractiveProps")
			local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
			if not door then
				return
			end
			task.wait(0.4)
			while phase == 2 and not frozen and group.Parent do
				SoundBank.PlayOneShot("ShutterKnock", door, 90, 3)
				task.wait(0.9 + math.random() * 0.8)
			end
		end)
	end

	-- ตรวจกติกา: ผิดครั้งแรก = จบ (ผิดทั้งทีม: ไฟ / แผง -> ทุกคนโดน)
	local faults: { [Player]: string } = {}
	local team: string? = nil
	local t0 = os.clock()
	while os.clock() - t0 < dangerT do
		task.wait(0.25)
		if os.clock() - t0 < cfg.Grace then
			continue
		end
		if plan.rules.lights and Power.LightsOn() then
			team = "Lights"
		elseif plan.rules.shutter and not shutterClosed() then
			team = "Shutter"
		end
		if team then
			for _, p in ipairs(activePlayers()) do
				faults[p] = team
			end
			break
		end
		for _, p in ipairs(activePlayers()) do
			local f = playerFault(p, plan.rules)
			if f then
				faults[p] = f
			end
		end
		if next(faults) then
			break
		end
	end
	local ok = next(faults) == nil and team == nil

	if not ok then
		-- จับได้: ผีหยุดเดิน เล่นท่าโกรธ แล้วจางหายหลังผีหลอก
		frozen = true
		for _, e in ipairs(live) do
			if e.g.angry then
				GhostNPC.Play(e.m, e.g.angry)
			end
		end
		task.delay(4, function()
			conn:Disconnect()
			fade(group, 1, 1.5)
			fadeSong(1.5)
			task.delay(1.6, function()
				group:Destroy()
			end)
		end)
	else
		-- รอด: ผีเดินต่อจนพ้นไป
		task.wait(math.max(0, dangerT - (os.clock() - t0)))
		setPhase(3)
		-- ไม่ขึ้นข้อความ "มันผ่านไปแล้ว" (Big_Pass) แล้ว (ผู้ใช้ 2026-11-22): ผู้เล่นดู/ฟังเอาเองว่าผีไปหรือยัง
		-- รอจนผีบินพ้นไปจริงก่อนคืนค่า (ผู้ใช้ 2026-11-22: ผียังไม่ทันไป ลูกค้าก็มาแล้ว)
		--   CoreLoop ถือ Big.running ไว้จนฟังก์ชันนี้คืน = ไม่ปล่อยลูกค้าระหว่างผีกำลังจากไป
		task.wait(leaveT)
		fade(group, 1, 1.5)
		fadeSong(1.5)
		task.wait(1.6)
		conn:Disconnect()
		group:Destroy()
	end
	return { ok = ok, faults = faults, team = team, group = group }
end

return BigEvents
