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
Lighting.EnvironmentSpecularScale = 0.5
Lighting.ShadowSoftness = 0.15

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmo then
	atmo = Instance.new("Atmosphere")
	atmo.Name = "RuralAtmosphere"
	atmo.Parent = Lighting
end
-- หมอกปกติหนาพอกลบภูเขา/ขอบแมพ (เดิม 0.42 / Offset 0.15 ยังเห็นภูเขาลางๆ) แต่ยังเห็นแนวไม้ขอบทุ่ง
local FOG_DENSITY = { min = 0.54, max = 0.62 }
atmo.Density = (FOG_DENSITY.min + FOG_DENSITY.max) / 2
atmo.Offset = 0.08
atmo.Color = Color3.fromRGB(18, 22, 28)
atmo.Decay = Color3.fromRGB(10, 12, 15)
atmo.Glare = 0.25
atmo.Haze = 1.65

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

-- Post-Processing ให้ภาพฟุ้งนุ่มและมีมิติระยะชัดลึก (เหมือนแมพ Horror ดังๆ)
local bloom = (Lighting:FindFirstChild("NightBloom") :: BloomEffect?) or Instance.new("BloomEffect")
bloom.Name = "NightBloom"
bloom.Enabled = true
bloom.Intensity = 0.45
bloom.Size = 32
bloom.Threshold = 0.92
bloom.Parent = Lighting

local dof = (Lighting:FindFirstChild("NightDepthOfField") :: DepthOfFieldEffect?) or Instance.new("DepthOfFieldEffect")
dof.Name = "NightDepthOfField"
-- Performance (2026-11-07): ระยะชัดลึกหนักบนการ์ดจอเล็ก เปิดเฉพาะตอนตาทิพย์เปิด (updatePrayerOptics) ไม่เปิดค้างทั้งเกม
dof.Enabled = false
dof.FocusDistance = 20
dof.InFocusRadius = 40
dof.NearIntensity = 0.1
dof.FarIntensity = 0.15
dof.Parent = Lighting

local softBlur = (Lighting:FindFirstChild("SoftFilmBlur") :: BlurEffect?) or Instance.new("BlurEffect")
softBlur.Name = "SoftFilmBlur"
softBlur.Size = 0 -- ภาพคมเป็นค่าเริ่มต้น เบลอเฉพาะตอนเปิดตาทิพย์
softBlur.Enabled = false -- เบลอ Size 0 ยังกินแรงเรนเดอร์ทั้งจอ: เปิดเฉพาะตอน Size > 0 (ตามด้านล่าง)
softBlur:GetPropertyChangedSignal("Size"):Connect(function()
	softBlur.Enabled = softBlur.Size > 0.01
end)
softBlur.Parent = Lighting
-- Bloom เดิมในไฟล์ place (ชื่อ "Bloom" Intensity 0) ไม่ได้ทำให้ภาพต่างแต่ยังเป็นอีกหนึ่งรอบเรนเดอร์ ปิดไว้ (เหลือ NightBloom ตัวเดียว)
local legacyBloom = Lighting:FindFirstChild("Bloom")
if legacyBloom and legacyBloom:IsA("BloomEffect") and legacyBloom.Intensity <= 0.001 then
	legacyBloom.Enabled = false
end

-- Dynamic Focus + เอฟเฟกต์ฟุ้งพิเศษตอนพนมมือเปิดตาทิพย์ (PrayerSight)
local focusParams = RaycastParams.new()
focusParams.FilterType = Enum.RaycastFilterType.Exclude
focusParams.IgnoreWater = true

local currentFocus = 20
-- 1.2 ขอบจอมืดสลัว (Screen Vignette) + บีบขอบจอเข้มขึ้นตอนเปิดตาทิพย์
local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "AmbienceVignette"
vignetteGui.IgnoreGuiInset = true
vignetteGui.ScreenInsets = Enum.ScreenInsets.None -- เต็มจอจริงถึงขอบ (มือถือมีติ่ง/ขอบโค้ง: ค่าเริ่มต้นถูกบีบไว้ใน safe area เหลือแถบเกินขอบ)
vignetteGui.ResetOnSpawn = false
-- อยู่ใต้ UI ทุกชิ้น: DisplayOrder เท่ากับ PumpHUD (0) แล้วสร้างทีหลัง = ขอบมืดทับ UI ที่มุมจอทั้งหมด (เงิน ปุ่มคีย์ ไฟฉาย ตั้งค่า จางหมด)
vignetteGui.DisplayOrder = -1
vignetteGui.Parent = localPlayer:WaitForChild("PlayerGui")

local function createVignetteEdge(name: string, pos: UDim2, anchor: Vector2, size: UDim2, rotation: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = Color3.fromRGB(3, 5, 8)
	f.BackgroundTransparency = 0.36
	f.BorderSizePixel = 0
	f.Active = false
	f.Interactable = false
	f.Parent = vignetteGui

	local grad = Instance.new("UIGradient")
	grad.Rotation = rotation
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = f
	return f
end

local vigTop = createVignetteEdge("TopEdge", UDim2.fromScale(0, 0), Vector2.new(0, 0), UDim2.fromScale(1, 0.24), 90)
local vigBottom = createVignetteEdge("BottomEdge", UDim2.fromScale(0, 1), Vector2.new(0, 1), UDim2.fromScale(1, 0.24), 270)
local vigLeft = createVignetteEdge("LeftEdge", UDim2.fromScale(0, 0), Vector2.new(0, 0), UDim2.fromScale(0.20, 1), 0)
local vigRight = createVignetteEdge("RightEdge", UDim2.fromScale(1, 0), Vector2.new(1, 0), UDim2.fromScale(0.20, 1), 180)

-- 1.3 แมลงเม่าบินตอมหลอดไฟนีออนเสาไม้ & ไฟในเพิงสังกะสี (NightMoths)
local function attachNightMoths(bulbPart: BasePart, rate: number)
	if bulbPart:FindFirstChild("NightMoths") then
		return
	end
	local moths = Instance.new("ParticleEmitter")
	moths.Name = "NightMoths"
	moths.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	moths.Shape = Enum.ParticleEmitterShape.Sphere
	moths.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	moths.Rate = rate
	moths.Lifetime = NumberRange.new(2.2, 3.8)
	moths.Speed = NumberRange.new(0.9, 1.9)
	moths.SpreadAngle = Vector2.new(180, 180)
	moths.Acceleration = Vector3.new(0, 0.55, 0) -- บินร่อนเข้าหาไอร้อนของหลอดไฟด้านบน
	moths.Drag = 1.6 -- เกาะกลุ่มบินวนรอบๆ หลอดไฟ ไม่พุ่งหนีไปไกล
	moths.Rotation = NumberRange.new(0, 360)
	moths.RotSpeed = NumberRange.new(-180, 180)
	moths.Color = ColorSequence.new(Color3.fromRGB(245, 225, 175))
	moths.LightEmission = 0.55
	moths.LightInfluence = 0.45
	moths.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.13),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	moths.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.8, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	moths.Parent = bulbPart

	-- ปิดแมลงเม่าอัตโนมัติถ้าหลอดไฟดับ (เช่น สับคัตเอาต์ หรือไฟดับ)
	local light = bulbPart:FindFirstChildOfClass("PointLight") or bulbPart:FindFirstChildOfClass("SpotLight")
	if light then
		moths.Enabled = light.Enabled
		light:GetPropertyChangedSignal("Enabled"):Connect(function()
			moths.Enabled = light.Enabled
		end)
	end
end

task.spawn(function()
	local mapEnv = Workspace:WaitForChild("MapEnvironment", 15)
	if not mapEnv then
		return
	end
	local dirtRoad = mapEnv:WaitForChild("DirtRoad", 10)
	local neonPoleBulb = dirtRoad and dirtRoad:WaitForChild("NeonLightPart", 10)
	if neonPoleBulb and neonPoleBulb:IsA("BasePart") then
		attachNightMoths(neonPoleBulb, 6)
	end
	local shack = mapEnv:WaitForChild("ShackStructure", 10)
	-- หลังสลับเป็นโมเดล Import หลอดในเพิงชื่อ ShackLight_Neon (เดิม ShackLightBulb)
	local shackBulb = shack and (shack:FindFirstChild("ShackLight_Neon", true) or shack:FindFirstChild("ShackLightBulb"))
	if shackBulb and shackBulb:IsA("BasePart") then
		attachNightMoths(shackBulb, 4)
	end
	-- หลอดไส้ห้อยสายไฟ (MapBuilder.AddNightPracticalLights)
	local hanging = shack and shack:FindFirstChild("HangingBulb")
	local hangingBulb = hanging and hanging:FindFirstChild("Bulb")
	if hangingBulb and hangingBulb:IsA("BasePart") then
		attachNightMoths(hangingBulb, 5)
	end
end)

-- 1.4 เส้นควันธูปลอยจากศาลพระภูมิ + ควันพุ่งตอนธูปดับ (IncenseSmoke & ExtinguishPuff)
local function setupIncenseStickFX(tip: BasePart)
	-- ลบ ParticleEmitter รุ่นเก่าที่ไม่ได้ตั้ง Texture ควัน
	for _, c in ipairs(tip:GetChildren()) do
		if c:IsA("ParticleEmitter") then
			c:Destroy()
		end
	end

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "IncenseSmoke"
	smoke.Texture = ASSETS.MistTexture
	smoke.Rate = 9
	smoke.Lifetime = NumberRange.new(2.2, 3.4)
	smoke.Speed = NumberRange.new(0.22, 0.42)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = Vector3.new(0.28, 1.35, 0.12) -- ลอยขึ้นฟ้าพร้อมเอียงตามลมทุ่งเบาๆ
	smoke.Drag = 0.65
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-25, 25)
	smoke.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 212, 195)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 152, 165)),
	})
	smoke.Brightness = 0.75
	smoke.LightInfluence = 0.35
	smoke.LightEmission = 0.08
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.06),
		NumberSequenceKeypoint.new(0.4, 0.22),
		NumberSequenceKeypoint.new(1, 0.56),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.22, 0.42),
		NumberSequenceKeypoint.new(0.75, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Enabled = (tip.Material == Enum.Material.Neon)
	smoke.Parent = tip

	-- ควันดำพุ่งวูบตอนธูปดับ (เมื่อเผลอเติมน้ำมันให้ผี)
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "ExtinguishPuff"
	puff.Texture = ASSETS.MistTexture
	puff.Enabled = false
	puff.Lifetime = NumberRange.new(1.0, 1.8)
	puff.Speed = NumberRange.new(0.8, 1.8)
	puff.SpreadAngle = Vector2.new(35, 35)
	puff.Acceleration = Vector3.new(0.35, 1.8, 0.15)
	puff.Drag = 1.2
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-45, 45)
	puff.Color = ColorSequence.new(Color3.fromRGB(85, 80, 78))
	puff.Brightness = 0.5
	puff.LightInfluence = 0.4
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0.85),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Parent = tip

	-- แสงไฟแดงเรื่อๆ ที่ปลายธูปแต่ละดอก (พอดับทีละดอก ศาลจะมืดลงทีละขั้น)
	local emberLight = tip:FindFirstChild("IncenseEmberLight") :: PointLight?
	if not emberLight then
		emberLight = Instance.new("PointLight")
		emberLight.Name = "IncenseEmberLight"
		emberLight.Color = Color3.fromRGB(255, 85, 35)
		emberLight.Brightness = 0.45
		emberLight.Range = 4.5
		emberLight.Shadows = false
		emberLight.Parent = tip
	end
	emberLight.Enabled = (tip.Material == Enum.Material.Neon)

	local wasLit = (tip.Material == Enum.Material.Neon)
	tip:GetPropertyChangedSignal("Material"):Connect(function()
		local isLit = (tip.Material == Enum.Material.Neon)
		smoke.Enabled = isLit
		emberLight.Enabled = isLit
		if wasLit and not isLit then
			puff:Emit(16)
		end
		wasLit = isLit
	end)
end

task.spawn(function()
	local spiritHouse = Workspace:WaitForChild("SpiritHouse", 15)
	if not spiritHouse then
		return
	end
	for i = 1, 3 do
		local tip = (spiritHouse:WaitForChild("Incense" .. i .. "_Neon", 8) or spiritHouse:FindFirstChild("Incense" .. i)) :: BasePart?
		if tip and tip:IsA("BasePart") then
			setupIncenseStickFX(tip)
		end
	end
end)

local praySightfxActive = false
local prayerSightEffect = Lighting:WaitForChild("PrayerSight", 10) :: ColorCorrectionEffect?

local function updatePrayerOptics(active: boolean)
	if praySightfxActive == active then
		return
	end
	praySightfxActive = active
	TweenService:Create(bloom, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
		Intensity = if active then 0.65 else 0.45,
		Size = if active then 38 else 32,
	}):Play()
	-- ตาทิพย์ต้องเห็นชัดพอจับผิดผีได้: เบลอนิดเดียว ระยะไกลไม่เบลอเพิ่ม
	TweenService:Create(softBlur, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
		Size = if active then 1.4 else 0,
	}):Play()
	-- ระยะชัดลึกเปิดเฉพาะตอนตาทิพย์เปิด (Performance 2026-11-07)
	dof.Enabled = active
	-- ขอบจอ (Vignette) บีบเข้ามาเบาๆ แต่จางกว่าปกติ ไม่ให้ภาพมืดลงตอนเพ่งดูผี
	local edgeTrans = if active then 0.5 else 0.36
	local vSize = if active then UDim2.fromScale(1, 0.33) else UDim2.fromScale(1, 0.24)
	local hSize = if active then UDim2.fromScale(0.27, 1) else UDim2.fromScale(0.20, 1)
	local info = TweenInfo.new(0.6, Enum.EasingStyle.Sine)
	TweenService:Create(vigTop, info, { BackgroundTransparency = edgeTrans, Size = vSize }):Play()
	TweenService:Create(vigBottom, info, { BackgroundTransparency = edgeTrans, Size = vSize }):Play()
	TweenService:Create(vigLeft, info, { BackgroundTransparency = edgeTrans, Size = hSize }):Play()
	TweenService:Create(vigRight, info, { BackgroundTransparency = edgeTrans, Size = hSize }):Play()end

-- PrayerController เปิด Enabled ค้างไว้หลังสวดครั้งแรก จึงฟัง attribute "Open" แทน (เดิม blur / vignette ค้างหลังเลิกสวด)
if prayerSightEffect then
	prayerSightEffect:GetAttributeChangedSignal("Open"):Connect(function()
		updatePrayerOptics(prayerSightEffect:GetAttribute("Open") == true)
	end)
end

task.spawn(function()
	while true do
		task.wait(0.1)
		local cam = Workspace.CurrentCamera
		if cam and dof.Enabled then -- ไม่เปิดระยะชัดลึก = ไม่ต้องยิง ray หาโฟกัส
			local filter = {}
			if localPlayer.Character then
				table.insert(filter, localPlayer.Character)
			end
			local mistPart = cam:FindFirstChild("GroundMistEmitter")
			if mistPart then
				table.insert(filter, mistPart)
			end
			focusParams.FilterDescendantsInstances = filter

			local hit = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 60, focusParams)
			local targetDist = if hit then math.clamp(hit.Distance, 8, 38) else 22
			currentFocus = currentFocus + (targetDist - currentFocus) * 0.25
			dof.FocusDistance = currentFocus
		end
	end
end)

-- หมอกค่อยๆ หนาขึ้นบางลงเหมือนมีหมอกก้อนลอยผ่าน
-- ตอนสวด ภาพสว่างขึ้น (PrayerController ดัน ExposureCompensation) จนเห็นภูเขาขอบแมพ/นอกแมพ -> หมอกหนาขึ้นกลบระยะไกลไว้
-- Offset 0 ดึงหมอกเข้ามาใกล้ (ราวแนวต้นกล้วยขอบแมพ) แทนที่จะเริ่มหนาไกลๆ
local PRAY_FOG = { Density = 0.85, Haze = 2.6, Offset = 0 }
local NORMAL_HAZE = atmo.Haze
local NORMAL_OFFSET = atmo.Offset
local driftTween: Tween? = nil
local function isPraying(): boolean
	return localPlayer:GetAttribute("Praying") == true
end
localPlayer:GetAttributeChangedSignal("Praying"):Connect(function()
	if driftTween then
		driftTween:Cancel()
	end
	local praying = isPraying()
	TweenService:Create(atmo, TweenInfo.new(if praying then 1.2 else 2, Enum.EasingStyle.Sine), {
		Density = if praying then PRAY_FOG.Density else (FOG_DENSITY.min + FOG_DENSITY.max) / 2,
		Haze = if praying then PRAY_FOG.Haze else NORMAL_HAZE,
		Offset = if praying then PRAY_FOG.Offset else NORMAL_OFFSET,
	}):Play()
end)
task.spawn(function()
	while true do
		-- คัทซีน (CutsceneController) ตั้งหมอกเย็น/เช้าเอง: ไม่ลอยทับ
		if isPraying() or Lighting:GetAttribute("Cutscene") or Lighting:GetAttribute("Dawn") then
			task.wait(1)
			continue
		end
		local target = FOG_DENSITY.min + math.random() * (FOG_DENSITY.max - FOG_DENSITY.min)
		driftTween = TweenService:Create(atmo, TweenInfo.new(math.random(10, 18), Enum.EasingStyle.Sine), {
			Density = target,
		})
		local tween = driftTween :: Tween
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
-- Performance (2026-11-07): เดิม 7/วิ ก้อน 14-26 studs (~100 ก้อนซ้อนกันบนจอ การ์ดจอวาดซ้ำหลายชั้น) -> 4/วิ ก้อน 12-22
mist.Rate = 4
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
	NumberSequenceKeypoint.new(0, 12),
	NumberSequenceKeypoint.new(1, 22),
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
-- มือถือดังขึ้นเท่ากับกลุ่มเสียงอื่น (Shared.DeviceInfo.VolumeBoost) อุปกรณ์อื่น = 1 เท่าเดิม
local deviceModule = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("DeviceInfo", 5)
local DeviceInfo = if deviceModule then require(deviceModule) :: any else { VolumeBoost = function() return 1 end }
ambienceGroup.Volume = DeviceInfo.VolumeBoost()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		ambienceGroup.Volume = DeviceInfo.VolumeBoost()
	end)
end
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

-- ลางผีใหญ่ (server: remotes.BigOmen / BigEvent): จิ้งหรีดเงียบกริบค้างไว้จนผีใหญ่ไป ห้ามเสียงอื่นเร่งกลับ
local omenHeld = false
local function fadeCrickets(scale, duration)
	if omenHeld and scale > 0.05 then
		return
	end
	for _, c in ipairs(crickets) do
		TweenService:Create(c.sound, TweenInfo.new(duration, Enum.EasingStyle.Sine), {
			Volume = c.volume * scale,
		}):Play()
	end
end

task.spawn(function()
	while true do
		-- (45-110 -> 90-180 ผู้ใช้ 2026-11-08: เงียบกริบเป็นลางก่อนผีใหญ่ด้วย เงียบเองบ่อยไปลางจะไม่มีความหมาย)
		task.wait(math.random(90, 180))
		if ReplicatedStorage:GetAttribute("CutsceneRunning") or omenHeld then
			continue -- คัทซีน / ลางผีใหญ่อยู่แล้ว: ไม่เล่นจังหวะจิ้งหรีดเงียบกริบ
		end
		fadeCrickets(0.05, 2.5) -- เงียบลงเร็วๆ เหมือนมีอะไรเดินผ่าน
		task.wait(math.random(5, 10))
		fadeCrickets(1, 8)
	end
end)

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local function update()
		local on = remotes:GetAttribute("BigOmen") == true or remotes:GetAttribute("BigEvent") ~= nil
		if on == omenHeld then
			return
		end
		if on then
			fadeCrickets(0.02, 3) -- เงียบลงช้าๆ จนเหลือแต่ลม (ก่อนผีใหญ่มา BigOmenTime วิ)
			omenHeld = true
		else
			omenHeld = false
			task.delay(6, function()
				if not omenHeld then
					fadeCrickets(1, 10) -- ผีใหญ่ไปแล้ว: ค่อยๆ ร้องกลับมา
				end
			end)
		end
	end
	remotes:GetAttributeChangedSignal("BigOmen"):Connect(update)
	remotes:GetAttributeChangedSignal("BigEvent"):Connect(update)
	update()
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
	local targetVol = snd.Volume * 0.3 -- เสียงกระซิบ/หายใจที่สุ่มมาเบาเหลือ 30% (เดิมดังเกินไป)
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
	end
	task.delay(5.5, function()
		fadeCrickets(1, 4.0)
	end)
end

SoundService:GetAttributeChangedSignal("DebugHaunt"):Connect(function()
	local cmd = SoundService:GetAttribute("DebugHaunt")
	if type(cmd) == "string" and cmd ~= "" then
		triggerRandomHaunt(cmd) -- "breath" | "dirt" | "shop" | "tree"
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
	local walkBobTime = 0
	local breathTime = 0

	local bobConn: RBXScriptConnection
	bobConn = RunService.RenderStepped:Connect(function(dt)
		if not char.Parent or not root.Parent or hum.Health <= 0 then
			bobConn:Disconnect()
			return
		end
		local horizVel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local isMoving = horizVel > 1.2 and hum.FloorMaterial ~= Enum.Material.Air and not root.Anchored
		local isPraying = (localPlayer:GetAttribute("Praying") == true)

		local targetOffset: Vector3
		if isPraying then
			-- ตอนยืนพนมมือสวดมนต์: นิ่งสงบ มีแค่จังหวะหายใจลึกๆ เบาๆ
			breathTime += dt * 2.1
			targetOffset = Vector3.new(0, math.sin(breathTime) * 0.032, 0)
		elseif isMoving then
			-- ตอนก้าวเดิน: โคลงซ้าย-ขวาและยวบขึ้น-ลงนุ่มๆ ตามจังหวะก้าวเท้า (WalkSpeed = 10)
			local speedFactor = math.clamp(horizVel / 10, 0.35, 1.2)
			walkBobTime += dt * (6.2 * speedFactor)
			local bobX = math.cos(walkBobTime) * 0.055 * speedFactor
			local bobY = math.abs(math.sin(walkBobTime)) * -0.075 * speedFactor
			targetOffset = Vector3.new(bobX, bobY, 0)
		else
			-- ตอนยืนนิ่งปกติ: จังหวะหายใจขึ้น-ลงช้าๆ
			breathTime += dt * 1.6
			local swayX = math.sin(breathTime * 0.5) * 0.012
			local swayY = math.sin(breathTime) * 0.024
			targetOffset = Vector3.new(swayX, swayY, 0)
		end

		-- ตัวผู้เล่นชาวบ้าน: กล้องอยู่ระดับตา (Humanoid attribute EyeOffset จาก VillagerAnimate)
		local eye = hum:GetAttribute("EyeOffset")
		if typeof(eye) == "Vector3" then
			targetOffset += eye
		end
		hum.CameraOffset = hum.CameraOffset:Lerp(targetOffset, math.clamp(dt * 10, 0, 1))
	end)

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
