-- AmbienceController.client.luau
-- บรรยากาศกลางคืนฝั่ง Client: เสียงจิ้งหรีดเหงาๆ + หมอกหนาวๆ ลอยเรี่ยพื้น
-- (ทำฝั่ง Client เพราะเสียง/หมอกเป็นของเฉพาะผู้เล่นแต่ละคน และไม่ไปแตะ MapBuilder/GameManager)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))

-- รอให้ Server สั่ง SetNightLighting() เสร็จก่อน ไม่งั้นค่าหมอกของเราจะโดนค่ากลางคืนจาก Server ทับ
if not game:IsLoaded() then
	game.Loaded:Wait()
end
while Lighting.ClockTime > 1 and Lighting.ClockTime < 23 do
	Lighting:GetPropertyChangedSignal("ClockTime"):Wait()
end
task.wait(1)

local ASSETS = {
	CricketBed = "rbxassetid://9112764023", -- Crickets Canyon 2 (ProSoundEffects) จิ้งหรีดร้องต่อเนื่อง
	CricketFar = "rbxassetid://9112764040", -- Crickets Canyon 1 (ProSoundEffects) จิ้งหรีดอีกฝูงไกลๆ
	EerieAir = "rbxassetid://9114244841", -- Electric Forest Airy (ProSoundEffects) ลมหวิวๆ เบาๆ ใต้เสียงจิ้งหรีด
	MistTexture = "rbxasset://textures/particles/smoke_main.dds",
}

---------------------------------------------------------------------
-- 1. หมอกหนาว: Atmosphere มืดขรึมยามวิกาล + โทนสีหนังผีไทยยุค 90s
---------------------------------------------------------------------
Lighting.EnvironmentDiffuseScale = 0.2
Lighting.EnvironmentSpecularScale = 0.25

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmo then
	atmo = Instance.new("Atmosphere")
	atmo.Name = "RuralAtmosphere"
	atmo.Parent = Lighting
end
atmo.Density = 0.42
atmo.Offset = 0.15
atmo.Color = Color3.fromRGB(18, 22, 28)
atmo.Decay = Color3.fromRGB(10, 12, 15)
atmo.Glare = 0.1
atmo.Haze = 1.5

local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then
	sky = Instance.new("Sky")
	sky.Name = "NightSky"
	sky.Parent = Lighting
end
sky.StarCount = 0
sky.CelestialBodiesShown = true

local grade = Lighting:FindFirstChild("ColdNightGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "ColdNightGrade"
grade.TintColor = Color3.fromRGB(235, 245, 235)
grade.Saturation = -0.25
grade.Contrast = 0.20
grade.Brightness = 0
grade.Parent = Lighting

-- หมอกค่อยๆ หนาขึ้นบางลงเหมือนมีหมอกก้อนลอยผ่าน
task.spawn(function()
	while true do
		local target = 0.38 + math.random() * 0.08
		local tween = TweenService:Create(atmo, TweenInfo.new(math.random(10, 18), Enum.EasingStyle.Sine), {
			Density = target,
		})
		tween:Play()
		tween.Completed:Wait()
	end
end)

---------------------------------------------------------------------
-- 2. หมอกเรี่ยพื้น: ParticleEmitter ในกล่องบางๆ ที่ตามกล้องผู้เล่นไป
---------------------------------------------------------------------
local GROUND_Y = 2.5

local mistBox = Instance.new("Part")
mistBox.Name = "GroundMistEmitter"
mistBox.Anchored = true
mistBox.CanCollide = false
mistBox.CanQuery = false
mistBox.CanTouch = false
mistBox.CastShadow = false
mistBox.Transparency = 1
mistBox.Size = Vector3.new(120, 1, 120)

local mist = Instance.new("ParticleEmitter")
mist.Name = "GroundMist"
mist.Texture = ASSETS.MistTexture
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Rate = 7
mist.Lifetime = NumberRange.new(12, 18)
mist.Speed = NumberRange.new(0.3, 1)
mist.SpreadAngle = Vector2.new(180, 5)
mist.Acceleration = Vector3.new(0.4, 0, 0.15) -- ลมพัดเอื่อยๆ
mist.Rotation = NumberRange.new(0, 360)
mist.RotSpeed = NumberRange.new(-4, 4)
mist.Color = ColorSequence.new(Color3.fromRGB(70, 82, 92))
mist.Brightness = 0.35 -- คืนนี้มืดมาก ลดความสว่างหมอกเรี่ยพื้นไม่ให้ขาวฟุ้งแสบตา
mist.LightInfluence = 0.45
mist.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 14),
	NumberSequenceKeypoint.new(1, 26),
})
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.3, 0.8),
	NumberSequenceKeypoint.new(0.7, 0.83),
	NumberSequenceKeypoint.new(1, 1),
})
mist.Parent = mistBox
mistBox.Parent = Workspace.CurrentCamera
mist:Emit(60) -- ให้มีหมอกพร้อมตั้งแต่วินาทีแรก ไม่ต้องรอค่อยๆ ลอยมา

RunService.RenderStepped:Connect(function()
	local camPos = Workspace.CurrentCamera.CFrame.Position
	mistBox.CFrame = CFrame.new(camPos.X, GROUND_Y, camPos.Z)
end)

---------------------------------------------------------------------
-- 3. เสียงจิ้งหรีดเหงาๆ
---------------------------------------------------------------------
local ambienceGroup = SoundService:FindFirstChild("Ambience") or Instance.new("SoundGroup")
ambienceGroup.Name = "Ambience"
ambienceGroup.Volume = 1
ambienceGroup.Parent = SoundService

-- ตัดเสียงทุ้ม (รถไกลๆ ในไฟล์ต้นฉบับ) ออก + reverb กว้างๆ ให้ทุ่งดูโล่งและเหงา
local eq = Instance.new("EqualizerSoundEffect")
eq.LowGain = -30
eq.MidGain = -4
eq.HighGain = 0
eq.Parent = ambienceGroup

local reverb = Instance.new("ReverbSoundEffect")
reverb.DecayTime = 3.5
reverb.Density = 0.6
reverb.Diffusion = 0.8
reverb.DryLevel = -2
reverb.WetLevel = -14
reverb.Parent = ambienceGroup

local function makeLoop(name, soundId, volume, speed, parent)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = soundId
	s.Looped = true
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.SoundGroup = ambienceGroup
	s.Parent = parent
	s:Play()
	return s
end

-- เสียงจิ้งหรีดรอบตัว (2D) เบาๆ (PlaybackSpeed = 1.0 เพื่อไม่ให้เสียงยืด)
local cricketBed = makeLoop("CricketBed", ASSETS.CricketBed, 0.35, 1.0, SoundService)
local eerieAir = makeLoop("EerieAir", ASSETS.EerieAir, 0.07, 1.0, SoundService)

-- จิ้งหรีดอีกฝูงในดงกล้วย/ทุ่งหลังร้าน (3D) เดินเข้าใกล้แล้วดังขึ้น
local function makePositional(name, soundId, position, volume, speed)
	local att = Instance.new("Attachment")
	att.Name = name .. "Emitter"
	att.WorldPosition = position
	att.Parent = Workspace.Terrain
	local s = makeLoop(name, soundId, volume, speed, att)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 140
	return s
end

local groveCrickets = makePositional("GroveCrickets", ASSETS.CricketFar, Vector3.new(30, 3, 30), 0.5, 1.0)
local fieldCrickets = makePositional("FieldCrickets", ASSETS.CricketBed, Vector3.new(-20, 3, -55), 0.4, 1.0)
fieldCrickets.TimePosition = 18 -- เลื่อนจุดเริ่ม ไม่ให้ร้องพร้อมกับ CricketBed

-- ความเหงา: บางช่วงจิ้งหรีดเงียบกริบไปพักหนึ่ง เหลือแต่ลมหวิว แล้วค่อยๆ ร้องกลับมา
local crickets = {
	{ sound = cricketBed, volume = cricketBed.Volume },
	{ sound = groveCrickets, volume = groveCrickets.Volume },
	{ sound = fieldCrickets, volume = fieldCrickets.Volume },
}

local function fadeCrickets(scale, duration)
	for _, c in ipairs(crickets) do
		TweenService:Create(c.sound, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
			Volume = c.volume * scale,
		}):Play()
	end
end

task.spawn(function()
	while true do
		task.wait(math.random(45, 110))
		fadeCrickets(0.05, 2.5) -- เงียบลงเร็วๆ เหมือนมีอะไรเดินผ่าน
		task.wait(math.random(5, 10))
		fadeCrickets(1, 8)
	end
end)

---------------------------------------------------------------------
-- 4. เสียงหลอกผู้เล่นแบบ 3D เฉพาะตัว (Personal Haunt / Prank Audio)
--    ไม่แสบหู (Warm Low-Pass EQ จาก SoundBank):
--    - เสียงหายใจรดต้นคอ (ข้างซ้าย / ข้างขวา / ข้างหลังคอ)
--    - เสียงเดินย่ำดินลูกรังวนรอบๆ ร้าน
--    - เสียงเดินไปมาบนพื้นไม้ในร้าน & เสียงเดินบนหลังคาสังกะสีเหนือหัว
--    - เสียงปีนขึ้นต้นไม้ / ตะกายเปลือกไม้ที่ดงกล้วยและต้นไทรใหญ่
---------------------------------------------------------------------
local hauntFolder = Instance.new("Folder")
hauntFolder.Name = "PersonalHauntEmitters"
hauntFolder.Parent = Workspace.CurrentCamera

local function makeMovingEmitter(name: string, startPos: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.Position = startPos
	p.Parent = hauntFolder
	return p
end

-- 4.1 เสียงหายใจใกล้ๆ คอ (เกาะติดหลังบ่าซ้าย/ขวาของผู้เล่น เหมือนมีคนมายืนซ้อนหลังชิดคอ)
local function playNeckBreath(side: string?)
	local char = localPlayer.Character
	local head = (char and char:FindFirstChild("Head") :: BasePart?) or Workspace.CurrentCamera
	if not head then
		return
	end
	local chosen = side or ({ "Left", "Right", "Behind" })[math.random(1, 3)]
	local presetName = if chosen == "Left"
		then "BreathNeckLeft"
		elseif chosen == "Right" then "BreathNeckRight"
		else "BreathBehindSlow"
	local offset = if chosen == "Left"
		then Vector3.new(-1.1, -0.15, 1.05) -- ชิดซอกคอซ้ายด้านหลัง
		elseif chosen == "Right" then Vector3.new(1.1, -0.15, 1.05) -- ชิดซอกคอขวาด้านหลัง
		else Vector3.new(0, -0.1, 1.25) -- ชิดท้ายทอยด้านหลัง

	local emitter = makeMovingEmitter("NeckBreathEmitter", head.Position)
	local snd = SoundBank.CreateSound(presetName, emitter, 18)
	if not snd then
		emitter:Destroy()
		return
	end
	snd.RollOffMinDistance = 1.5
	snd.RollOffMaxDistance = 12
	local targetVol = snd.Volume
	snd.Volume = 0
	if snd.TimeLength > 5 then
		snd.TimePosition = math.random() * math.max(0, snd.TimeLength - 4.5)
	end
	snd:Play()
	TweenService:Create(snd, TweenInfo.new(0.6, Enum.EasingStyle.Sine), { Volume = targetVol }):Play()

	local dur = 3.6
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local h = (localPlayer.Character and localPlayer.Character:FindFirstChild("Head") :: BasePart?) or Workspace.CurrentCamera
		if h then
			emitter.CFrame = h.CFrame * CFrame.new(offset)
		end
	end)
	-- เสียงผู้เล่นสะดุ้ง/เสียงสั่นกลัวเบาๆ ตามเพศตัวละครเมื่อโดนหายใจรดต้นคอ
	task.delay(1.8, function()
		local g = SoundBank.DetectPlayerGender(localPlayer)
		SoundBank.PlayReaction(if math.random() < 0.5 then "Tremble" else "Startle", g)
	end)
	task.delay(dur - 0.8, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
		end
	end)
	task.delay(dur, function()
		conn:Disconnect()
		emitter:Destroy()
	end)
end

local function getShopCenter(): Vector3
	local inter = Workspace:FindFirstChild("InteractiveProps")
	local shutter = inter and inter:FindFirstChild("ShutterDoor") :: BasePart?
	local rad = inter and inter:FindFirstChild("Radio")
	if shutter then
		return shutter.Position + Vector3.new(0, -2, 4)
	elseif rad and rad:IsA("Model") then
		return rad:GetPivot().Position
	end
	return Vector3.new(0, 3.2, 11)
end

-- 4.2 เสียงเดินย่ำดินลูกรังวนรอบร้าน (ค่อยๆ เคลื่อนตัวเป็นวงโค้งรอบร้านในความมืด)
local function playDirtStepsAroundShop(hurry: boolean?)
	local presetName = if hurry then "WalkDirtHurry" else "WalkDirtCircle"
	local dur = if hurry then 3.5 else 6.0
	local center = getShopCenter()
	local radius = if hurry then 19 else 24
	local startAngle = math.random() * math.pi * 2
	local dir = if math.random() < 0.5 then 1 else -1
	local arc = if hurry then math.rad(55) else math.rad(115)

	local emitter = makeMovingEmitter("DirtWalkEmitter", center + Vector3.new(math.cos(startAngle) * radius, 0, math.sin(startAngle) * radius))
	local snd = SoundBank.CreateSound(presetName, emitter, 85)
	if not snd then
		emitter:Destroy()
		return
	end
	snd.RollOffMinDistance = 10
	snd.RollOffMaxDistance = 80
	snd:Play()

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local ang = startAngle + dir * arc * u
		local r = if hurry then radius * (1 - 0.35 * u) else radius
		emitter.Position = center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
	end)
	task.delay(dur - 0.6, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.6), { Volume = 0 }):Play()
		end
	end)
	task.delay(dur, function()
		conn:Disconnect()
		emitter:Destroy()
	end)
end

-- 4.3 เสียงเดินไปมาในร้าน (พื้นไม้กระดาน/แคร่ลั่น หรือเดินบนหลังคาสังกะสีเหนือหัวเพิงร้านจริงๆ)
local function playShopInteriorOrRoofWalk(onRoof: boolean?)
	local presetName = if onRoof then "RoofTinSteps" else (if math.random() < 0.6 then "WalkShopWood1" else "WalkShopWood2")
	local dur = 4.6
	local shopC = getShopCenter()
	local y = if onRoof then (shopC.Y + 9.5) else shopC.Y
	local offset = if math.random() < 0.5 then -5.5 else 5.5
	local fromX = shopC.X + offset
	local toX = shopC.X - offset
	local z = shopC.Z + (math.random() - 0.5) * 2.5

	local emitter = makeMovingEmitter("ShopWalkEmitter", Vector3.new(fromX, y, z))
	local snd = SoundBank.CreateSound(presetName, emitter, 65)
	if not snd then
		emitter:Destroy()
		return
	end
	snd.RollOffMinDistance = 8
	snd.RollOffMaxDistance = 60
	snd:Play()

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		local x = fromX + (toX - fromX) * u
		emitter.Position = Vector3.new(x, y, z)
	end)
	task.delay(dur - 0.6, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.6), { Volume = 0 }):Play()
		end
	end)
	task.delay(dur, function()
		conn:Disconnect()
		emitter:Destroy()
	end)
end

-- 4.4 เสียงปีนขึ้นต้นไม้ (ไต่ขึ้นจากโคนต้นไทรใหญ่ หรือดงกล้วยตานี ขึ้นไปบนยอดไม้)
local TREE_SPOTS = {
	Vector3.new(-35, 3, 35), -- โซนต้นไทรใหญ่พันผ้าสามสี
	Vector3.new(28, 3, 26),  -- ดงกล้วยตานีข้างร้าน
	Vector3.new(-18, 3, 24), -- ต้นไม้ใหญ่หลังศาลพระภูมิ
}
local function playTreeClimb()
	local basePos = TREE_SPOTS[math.random(#TREE_SPOTS)]
	local presetName = if math.random() < 0.5 then "ClimbTree1" else "ClimbTree2"
	local dur = 4.8
	local emitter = makeMovingEmitter("TreeClimbEmitter", basePos)
	local snd = SoundBank.CreateSound(presetName, emitter, 90)
	if not snd then
		emitter:Destroy()
		return
	end
	snd.RollOffMinDistance = 12
	snd.RollOffMaxDistance = 85
	snd:Play()

	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local u = math.clamp((os.clock() - t0) / dur, 0, 1)
		-- เสียงไต่สูงขึ้นไปบนกิ่งไม้ (Y +2 -> Y +16 studs)
		emitter.Position = basePos + Vector3.new(math.sin(u * 6) * 0.8, u * 14, math.cos(u * 6) * 0.8)
	end)
	task.delay(dur - 0.7, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.7), { Volume = 0 }):Play()
		end
	end)
	task.delay(dur, function()
		conn:Disconnect()
		emitter:Destroy()
	end)
end

-- ลูปสุ่มหลอกผู้เล่นทุกๆ 22 - 48 วินาที (และรับคำสั่งทดสอบจาก Attribute DebugHaunt บน SoundService)
local function triggerRandomHaunt(forcedKind: string?)
	local kind = forcedKind
	if not kind then
		local r = math.random()
		if r < 0.28 then
			kind = "breath"
		elseif r < 0.56 then
			kind = "dirt"
		elseif r < 0.80 then
			kind = "shop"
		else
			kind = "tree"
		end
	end

	-- หรี่เสียงจิ้งหรีดลงนิดหนึ่งตอนมีเสียงหลอก เพื่อให้ได้ยินเสียงย่อง/เสียงหายใจชัดๆ แบบขนลุก
	fadeCrickets(0.25, 1.2)
	if kind == "breath" then
		playNeckBreath()
	elseif kind == "dirt" then
		playDirtStepsAroundShop(math.random() < 0.35)
	elseif kind == "shop" then
		playShopInteriorOrRoofWalk(math.random() < 0.4)
	elseif kind == "tree" then
		playTreeClimb()
	elseif kind == "cold" then
		SoundBank.PlayReaction("Cold", SoundBank.DetectPlayerGender(localPlayer))
	elseif kind == "fear" then
		SoundBank.PlayReaction("Fear", SoundBank.DetectPlayerGender(localPlayer))
	elseif kind == "startle" then
		SoundBank.PlayReaction("Startle", SoundBank.DetectPlayerGender(localPlayer))
	elseif kind == "question" then
		SoundBank.PlayReaction("Question", SoundBank.DetectPlayerGender(localPlayer))
	end
	task.delay(5.5, function()
		fadeCrickets(1, 4.0)
	end)
end

SoundService:GetAttributeChangedSignal("DebugHaunt"):Connect(function()
	local cmd = SoundService:GetAttribute("DebugHaunt")
	if type(cmd) == "string" and cmd ~= "" then
		triggerRandomHaunt(cmd) -- "breath" | "dirt" | "shop" | "tree" | "cold" | "fear" | "startle" | "question"
		SoundService:SetAttribute("DebugHaunt", "")
	end
end)

-- ปิดการสุ่มเสียงหลอกผู้เล่นอัตโนมัติ (หายใจรดต้นคอ / เดินรอบร้าน / เดินบนหลังคา / ปีนต้นไม้ / หนาวสั่น)
-- ให้เหลือเฉพาะเสียงหมาหอนจากฝั่ง Server (AnomalyManager) ตามที่ผู้พัฒนากำหนด

---------------------------------------------------------------------
-- 5. เสียงฝีเท้าตัวละครผู้เล่นตามพื้นผิวจริง (Rural Horror Footsteps)
--    แทนที่เสียงเดินพลาสติกเดิมของ Roblox ด้วยเสียงย่ำพื้นไม้เก่าลั่นเอี๊ยดในเพิง / เสียงย่ำดินลูกรัง / เสียงย่ำโคลนชื้นตอนฝนตก
---------------------------------------------------------------------
local sfxGroup = SoundService:FindFirstChild("SFX") :: SoundGroup?
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")

local function setupCharacterFootsteps(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not (root and hum) then
		return
	end

	-- ปิดเสียงฝีเท้าพลาสติกเดิมของ Roblox (Running)
	local function muteDefaultRunning(child: Instance)
		if child:IsA("Sound") and child.Name == "Running" then
			child.Volume = 0
			child:GetPropertyChangedSignal("Volume"):Connect(function()
				if child.Volume > 0 then
					child.Volume = 0
				end
			end)
		end
	end
	for _, c in ipairs(root:GetChildren()) do
		muteDefaultRunning(c)
	end
	root.ChildAdded:Connect(muteDefaultRunning)

	local oldStep = root:FindFirstChild("HorrorFootsteps")
	if oldStep then
		oldStep:Destroy()
	end

	local stepSound = Instance.new("Sound")
	stepSound.Name = "HorrorFootsteps"
	stepSound.SoundId = "rbxassetid://135952279207329"
	stepSound.Looped = true
	stepSound.Volume = 0
	stepSound.PlaybackSpeed = 0.98
	stepSound.RollOffMode = Enum.RollOffMode.InverseTapered
	stepSound.RollOffMinDistance = 4
	stepSound.RollOffMaxDistance = 32
	if sfxGroup then
		stepSound.SoundGroup = sfxGroup
	end

	-- ใช้ EQ บางๆ ตัดปลายแหลมเล็กน้อย ไม่ใส่ PitchShift/Reverb หนักๆ ที่ทำให้เสียงเท้าหลอนแปลกๆ หรือก้องอู้อี้
	local stepEQ = Instance.new("EqualizerSoundEffect")
	stepEQ.LowGain = 1
	stepEQ.MidGain = 0
	stepEQ.HighGain = -8
	stepEQ.Parent = stepSound

	stepSound.Parent = root
	stepSound:Play()

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { char }

	local currentSurface = ""

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not char.Parent or not root.Parent or hum.Health <= 0 then
			conn:Disconnect()
			return
		end

		local horizVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local isMovingOnGround = horizVel > 1.2 and hum.FloorMaterial ~= Enum.Material.Air and not root.Anchored

		if not isMovingOnGround then
			stepSound.Volume = math.max(0, stepSound.Volume - dt * 5.0)
			return
		end

		-- ตรวจจับพื้นผิวใต้เท้า
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -5.5, 0), rayParams)
		local mat = if hit then hit.Material else hum.FloorMaterial
		local hitInst = hit and hit.Instance
		local hitName = if hitInst then hitInst.Name else ""

		local isWood = mat == Enum.Material.WoodPlanks
			or mat == Enum.Material.Wood
			or hitName == "PorchDeck"
			or hitName == "ShackFloor"
			or (hitInst and hitInst:FindFirstAncestor("ShackStructure") ~= nil)

		local isRaining = (remotesFolder and remotesFolder:GetAttribute("Weather") == "Rain")
		local isMudOrWater = mat == Enum.Material.Mud
			or hitName:find("Puddle") ~= nil
			or hitName:find("PaddyWater") ~= nil
			or (isRaining and not isWood)

		local surfaceKind = if isWood then "wood" elseif isMudOrWater then "mud" else "dirt"
		if surfaceKind ~= currentSurface then
			currentSurface = surfaceKind
			if surfaceKind == "wood" then
				stepEQ.LowGain = 2
				stepEQ.MidGain = -1
				stepEQ.HighGain = -10
			elseif surfaceKind == "mud" then
				stepEQ.LowGain = 2
				stepEQ.MidGain = 0
				stepEQ.HighGain = -9
			else
				stepEQ.LowGain = 1
				stepEQ.MidGain = 0
				stepEQ.HighGain = -7
			end
		end

		local speedRatio = math.clamp(horizVel / 10, 0.85, 1.15)
		local basePlayback = if surfaceKind == "wood" then 0.95 elseif surfaceKind == "mud" then 0.96 else 1.0
		stepSound.PlaybackSpeed = basePlayback * speedRatio

		-- ลดความดังเสียงฝีเท้าลงให้เบาและเป็นธรรมชาติ (เดิม 0.46-0.54 ดังกลบเสียงบรรยากาศ)
		local targetVol = if surfaceKind == "wood" then 0.16 elseif surfaceKind == "mud" then 0.20 else 0.18
		stepSound.Volume = math.min(targetVol, stepSound.Volume + dt * 2.5)
	end)
end

if localPlayer.Character then
	task.spawn(setupCharacterFootsteps, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(setupCharacterFootsteps)

print("🦗 [Client] Ambience: จิ้งหรีดเหงาๆ + หมอกหนาว + เสียงหลอก 3D + เสียงฝีเท้าสยองขวัญตามพื้นผิว พร้อมแล้ว")
