--!strict
-- Power.luau (ModuleScript ฝั่ง Server)
-- ไฟร้านดับ -> ต้องเดินไปสตาร์ทเครื่องปั่นไฟ (Workspace.Generator หลังดงกล้วย) ไฟถึงกลับมา
--   สตาร์ท = มินิเกม: กดปุ่มที่เครื่องแล้วยืนอยู่ใกล้ๆ วงจังหวะเด้งขึ้นมาทีละรอบ ต้องกด (Space / แตะ) ตอนเข็มอยู่ในช่อง
--     ส่วนแดง = บูสต์ (แถบขึ้นเยอะ GainGreat) / ช่องขาว = ขึ้นนิดเดียว (GainGood) / แถบเต็ม = เครื่องติด
--     ระหว่างรอวงรอบถัดไป แถบค่อยๆ ขึ้นเองทีละนิด (GainPerSecond ต่อคนที่ยืนซ่อม)
--     พลาด (นอกช่อง หรือไม่กด) = โดนไฟช็อต: กระเด็นออกจากเครื่อง ชาไปครู่หนึ่ง มินิเกมปิด
--       ต้องเดินกลับไปกดปุ่มที่เครื่องใหม่ (ความคืบหน้าที่ทำไว้ยังอยู่) กดซ้ำได้หลังพ้น ShockCooldown
--   (หน้าจอมินิเกม: client/GeneratorMinigame.client.luau)  ช่วยกันซ่อมได้หลายคน ความคืบหน้ารวมกัน
-- สถานะไฟ: ReplicatedStorage attribute "PowerOn" (client ใช้ปิดแมลงเม่า / เสียง ฯลฯ ได้)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))

local Power = {}

Power.Config = {
	GainGreat = 0.35, -- โดนส่วนแดง: แถบขึ้นเท่านี้ (3 ครั้งเครื่องติด)
	GainGood = 0.07, -- โดนช่องขาว: ขึ้นนิดเดียว
	GainPerSecond = 0.012, -- ยืนซ่อมอยู่เฉยๆ: แถบขึ้นเองวินาทีละเท่านี้ (ต่อคน; คนเดียวไม่กดเลย ~80 วินาที)
	ShockStun = 1.4, -- โดนไฟช็อต: เดินไม่ได้กี่วินาที
	ShockCooldown = 2.5, -- โดนไฟช็อตแล้ว กดปุ่มที่เครื่องใหม่ได้หลังจากนี้ (วินาที)
	Range = 8, -- ต้องยืนห่างเครื่องไม่เกินนี้ (studs) ระหว่างซ่อม
	CutEvery = { 420, 660 }, -- ไฟดับเองหลังไฟติดมาแล้วนานเท่านี้ (วินาที, สุ่ม) ตอนร้านเปิด (เดิม 240-480 ถี่เกิน ผู้ใช้ 2026-11-05)
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local GenRemote = remotes:FindFirstChild("Generator") or Instance.new("RemoteEvent")
GenRemote.Name = "Generator"
GenRemote.Parent = remotes

local powerOn = true
local progress = 0
local sessions: { [Player]: boolean } = {}
local shockedUntil: { [Player]: number } = {}
local saved: { { inst: Instance, prop: string, value: any } } = {}
local runSound: Sound? = nil
local prompt: ProximityPrompt? = nil

ReplicatedStorage:SetAttribute("PowerOn", true)

local function generator(): Model?
	return Workspace:FindFirstChild("Generator") :: Model?
end

local function genPart(): BasePart?
	local g = generator()
	if not g then
		return nil
	end
	return (g:FindFirstChild("Generator") or g:FindFirstChild("GeneratorBody") or g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
end

-- ไฟของร้าน: หลอดนีออนเสาหน้าร้าน หลอดในเพิง หลอดไส้ห้อย ตะเกียง (ไฟดับ = มืดสนิท ต้องใช้ไฟฉาย)
local LIGHT_PARTS = { NeonLightPart = true, ShackLight_Neon = true, ShackLightBulb = true, Bulb = true, StormLantern_Neon = true }
-- ไฟดับ: ฟ้าแทบไม่ให้แสงเลย (PrayerController ยังปรับ ExposureCompensation ตอนพนมมือ "ตาทิพย์" เห็นในความมืดได้
-- แต่ผีจะมาหามากขึ้น: CoreLoop.prayerSummonLoop)
local DARK = { Ambient = Color3.fromRGB(0, 0, 0), OutdoorAmbient = Color3.fromRGB(3, 3, 5), Brightness = 0 }
local function shopLights(): { BasePart }
	local out = {}
	local env = Workspace:FindFirstChild("MapEnvironment")
	if env then
		for _, d in ipairs(env:GetDescendants()) do
			if d:IsA("BasePart") and LIGHT_PARTS[d.Name] then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function setNeon(on: boolean)
	local g = generator()
	local n = g and g:FindFirstChild("Generator_Neon") :: BasePart?
	if n then
		n.Color = if on then Color3.fromRGB(80, 255, 110) else Color3.fromRGB(255, 60, 40)
	end
end

function Power.IsOn(): boolean
	return powerOn
end

-- สะพานไฟในเพิง (InteractiveProps.CutoutSwitch): สับลง = ไฟร้านดับทั้งหมด สับขึ้น = ไฟกลับมา (ถ้าเครื่องปั่นไฟเดินอยู่)
--   ไม่เกี่ยวกับไฟดับ (เครื่องปั่นไฟ): ใช้หลบผีใหญ่ (server/BigEvents) ReplicatedStorage attribute "BreakerOn"
local breakerOn = true
local dark = false
ReplicatedStorage:SetAttribute("BreakerOn", true)

-- ไฟร้านติดอยู่จริง (เครื่องปั่นไฟเดิน + สะพานไฟสับขึ้น)
function Power.LightsOn(): boolean
	return powerOn and breakerOn
end

-- มืด: เก็บค่าเดิมของ Lighting และหลอดไฟไว้ แล้วดับ / สว่าง: คืนค่าที่เก็บไว้
local function setDark(on: boolean)
	if on == dark then
		return
	end
	dark = on
	if not on then
		for _, s in ipairs(saved) do
			local inst: any = s.inst
			if inst.Parent then
				inst[s.prop] = s.value
			end
		end
		table.clear(saved)
		return
	end
	table.clear(saved)
	local L: any = Lighting
	for prop, v in pairs(DARK) do
		table.insert(saved, { inst = Lighting, prop = prop, value = L[prop] })
		L[prop] = v
	end
	for _, part in ipairs(shopLights()) do
		table.insert(saved, { inst = part, prop = "Material", value = part.Material })
		table.insert(saved, { inst = part, prop = "Color", value = part.Color })
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(60, 58, 50)
		for _, l in ipairs(part:GetDescendants()) do
			if l:IsA("Light") then
				table.insert(saved, { inst = l, prop = "Enabled", value = l.Enabled })
				l.Enabled = false
			end
		end
	end
end

-- silent = ไม่มีเสียงคัตเอาต์ตัด (ตอนเริ่มคืน: ไฟดับรอสตาร์ทเครื่องอยู่แล้ว ไม่ให้ได้ยินเสียงกระแทกตอนโหลดเข้าเกม)
function Power.Cut(silent: boolean?)
	if not powerOn then
		return
	end
	powerOn = false
	progress = 0
	ReplicatedStorage:SetAttribute("PowerOn", false)
	setDark(true)
	if runSound then
		runSound:Stop()
	end
	setNeon(false)
	local gp = genPart()
	if gp and not silent then
		SoundBank.PlayAtPosition("PowerOffClunk", gp.Position, 120, 2)
	end
	local lp = shopLights()[1]
	if lp and not silent then
		SoundBank.PlayAtPosition("PowerOffClunk", lp.Position, 120, 2)
	end
	if prompt then
		prompt.Enabled = true
	end
	print("⚡ ไฟร้านดับ! ต้องไปสตาร์ทเครื่องปั่นไฟ")
end

-- เสียงเครื่องปั่นไฟเดิน: เปิดตั้งแต่เริ่มเกม (ไฟติดอยู่ = เครื่องเดินอยู่) และตอนสตาร์ทติดหลังไฟดับ
-- (เดิมสร้างเสียงตอนสตาร์ทติดเท่านั้น: เริ่มเกมมาเครื่องเงียบ จนกว่าไฟจะดับแล้วซ่อมครั้งแรก)
local function startRunSound()
	local gp = genPart()
	if not gp then
		return
	end
	if not runSound then
		runSound = SoundBank.CreateSound("GeneratorRun", gp, 70)
	end
	if runSound and not runSound.IsPlaying then
		runSound:Play()
	end
end

function Power.Restore()
	if powerOn then
		return
	end
	powerOn = true
	ReplicatedStorage:SetAttribute("PowerOn", true)
	setDark(not breakerOn)
	setNeon(true)
	startRunSound()
	if prompt then
		prompt.Enabled = false
	end
	for p in pairs(sessions) do
		GenRemote:FireClient(p, "done")
	end
	table.clear(sessions)
	print("⚡ เครื่องปั่นไฟติดแล้ว ไฟกลับมา")
end

local function stopSession(p: Player)
	if sessions[p] then
		sessions[p] = nil
		GenRemote:FireClient(p, "close")
	end
end

-- กดพลาด = ไฟช็อต: เสียงไฟแตก + เครื่องสะดุด ประกายไฟที่เครื่อง ปิดมินิเกมของคนนั้น ชาเดินไม่ได้ครู่หนึ่ง
-- (กระเด็นถอยหลัง + จอแวบ/สั่น ทำฝั่ง client: ตัวผู้เล่นเป็นของเครื่องเขา เซิร์ฟเวอร์ผลักตัวไม่ได้)
local function sparks(gp: BasePart)
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, gp.Size.Y / 2, 0)
	a.Parent = gp
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), Color3.fromRGB(120, 170, 255))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.18, 0)
	e.Lifetime = NumberRange.new(0.15, 0.4)
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = a
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(170, 210, 255)
	l.Brightness = 6
	l.Range = 14
	l.Parent = a
	e:Emit(40)
	task.delay(0.15, function()
		l.Enabled = false
	end)
	task.delay(1, function()
		a:Destroy()
	end)
end

local function shock(p: Player, gp: BasePart?)
	if gp then
		SoundBank.PlayAtPosition("GeneratorShock", gp.Position, 120, 2)
		SoundBank.PlayAtPosition("GeneratorBackfire", gp.Position, 140, 2)
		sparks(gp)
	end
	sessions[p] = nil
	shockedUntil[p] = os.clock() + Power.Config.ShockCooldown
	GenRemote:FireClient(p, "shock", if gp then gp.Position else nil)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed > 0 then
		local speed = hum.WalkSpeed
		hum.WalkSpeed = 0
		task.delay(Power.Config.ShockStun, function()
			-- ระหว่างนั้นถูกอย่างอื่นตั้งค่าใหม่ (ล้ม ฯลฯ) = ไม่ทับ
			if hum.Parent and hum.WalkSpeed == 0 then
				hum.WalkSpeed = speed
			end
		end)
	end
end

local function near(p: Player): boolean
	local gp = genPart()
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return gp ~= nil and root ~= nil and (root.Position - gp.Position).Magnitude <= Power.Config.Range + gp.Size.Magnitude / 2
end

GenRemote.OnServerEvent:Connect(function(p: Player, what: any)
	if not sessions[p] or powerOn then
		return
	end
	local gp = genPart()
	if what == "great" or what == "good" then
		local gain = if what == "great" then Power.Config.GainGreat else Power.Config.GainGood
		progress = math.min(1, progress + gain + 1e-6)
		for q in pairs(sessions) do
			GenRemote:FireClient(q, "progress", progress)
		end
		if progress >= 1 then
			Power.Restore()
		end
	elseif what == "miss" then
		shock(p, gp)
	elseif what == "leave" then
		stopSession(p)
	end
end)

local breakerPrompt: ProximityPrompt? = nil
local leverRest: CFrame? = nil
local function breakerParts(): (BasePart?, BasePart?)
	local props = Workspace:FindFirstChild("InteractiveProps")
	local sw = props and props:FindFirstChild("CutoutSwitch") :: BasePart?
	return sw, sw and sw:FindFirstChild("CutoutSwitch_Lever") :: BasePart?
end

function Power.BreakerOn(): boolean
	return breakerOn
end

function Power.SetBreaker(on: boolean, silent: boolean?)
	if on == breakerOn then
		return
	end
	breakerOn = on
	ReplicatedStorage:SetAttribute("BreakerOn", on)
	setDark(not (powerOn and breakerOn))
	local sw, lever = breakerParts()
	if lever and leverRest then
		-- คันโยกพับลงเมื่อสับลง
		lever.CFrame = if on then leverRest else leverRest * CFrame.Angles(math.rad(-70), 0, 0)
	end
	if sw and not silent then
		SoundBank.PlayAtPosition("PowerOffClunk", sw.Position, 90, 2)
	end
	if breakerPrompt then
		breakerPrompt:SetAttribute("LightsOff", not on)
	end
end

function Power.Start(active: () -> boolean)
	local sw, lever = breakerParts()
	if lever then
		leverRest = lever.CFrame
	end
	if sw then
		local bp = Instance.new("ProximityPrompt")
		bp.Name = "BreakerPrompt"
		bp.ActionText = "Lights Off"
		bp.ObjectText = "Breaker Switch"
		bp.KeyboardKeyCode = Enum.KeyCode.E
		bp.HoldDuration = 0.15
		bp.MaxActivationDistance = 8
		bp.RequiresLineOfSight = false
		bp.Parent = sw
		breakerPrompt = bp
		bp.Triggered:Connect(function()
			Power.SetBreaker(not breakerOn)
		end)
	else
		warn("[Power] ไม่เจอ InteractiveProps.CutoutSwitch")
	end
	local gp = genPart()
	if powerOn then
		startRunSound() -- เริ่มเกมไฟติดอยู่: ได้ยินเครื่องเดินตั้งแต่แรก
	end
	if gp then
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "StartGeneratorPrompt"
		pr.ActionText = "Start Generator"
		pr.ObjectText = "Generator"
		pr.HoldDuration = 0.3
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr:SetAttribute("NeedsFacing", true)
		pr:SetAttribute("Range", 9)
		pr.Enabled = false
		pr.Parent = gp
		prompt = pr
		pr.Triggered:Connect(function(p: Player)
			if powerOn or sessions[p] or os.clock() < (shockedUntil[p] or 0) then
				return
			end
			sessions[p] = true
			SoundBank.PlayAtPosition("GeneratorPull", gp.Position, 80, 2)
			GenRemote:FireClient(p, "open", progress)
		end)
	else
		warn("[Power] ไม่เจอ Workspace.Generator")
	end
	-- เดินออกห่างเครื่อง = เลิกซ่อม (ความคืบหน้าที่ทำไว้ยังอยู่)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if powerOn then
			return
		end
		acc += dt
		if acc < 0.25 then
			return
		end
		local step = acc
		acc = 0
		local working = 0
		for p in pairs(sessions) do
			if not (p.Parent and near(p)) then
				stopSession(p)
			else
				working += 1
			end
		end
		-- ยืนซ่อมอยู่ (ระหว่างรอวงจังหวะรอบถัดไป): แถบค่อยๆ ขึ้นเองทีละนิด คนช่วยกันหลายคนขึ้นเร็วขึ้น
		if working > 0 then
			progress = math.min(1, progress + Power.Config.GainPerSecond * working * step)
			for q in pairs(sessions) do
				GenRemote:FireClient(q, "progress", progress)
			end
			if progress >= 1 then
				Power.Restore()
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
		shockedUntil[p] = nil
	end)
	-- ไฟดับเองเป็นระยะตอนร้านเปิด: เริ่มนับเมื่อไฟติดและร้านเปิดเท่านั้น ระหว่างนับถ้าไฟดับหรือร้านปิด ให้นับใหม่
	-- (เดิมนับตั้งแต่เปิด server และไม่รีเซ็ต ไฟเลยดับซ้ำได้ทันทีหลังเพิ่งซ่อมเสร็จ)
	task.spawn(function()
		while true do
			while not (powerOn and active()) do
				task.wait(1)
			end
			local c = Power.Config.CutEvery
			local duration = math.random(c[1], c[2])
			local t0 = os.clock()
			while os.clock() - t0 < duration and powerOn and active() do
				task.wait(1)
			end
			if powerOn and active() then
				Power.Cut()
			end
		end
	end)
end

return Power
