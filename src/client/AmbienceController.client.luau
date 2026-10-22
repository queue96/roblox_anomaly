-- AmbienceController.client.luau
-- บรรยากาศกลางคืนฝั่ง Client: เสียงจิ้งหรีดเหงาๆ + หมอกหนาวๆ ลอยเรี่ยพื้น
-- (ทำฝั่ง Client เพราะเสียง/หมอกเป็นของเฉพาะผู้เล่นแต่ละคน และไม่ไปแตะ MapBuilder/GameManager)

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
-- 1. หมอกหนาว: Atmosphere สีเทาฟ้าซีด + โทนภาพเย็นๆ หม่นๆ
---------------------------------------------------------------------
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmo then
	atmo = Instance.new("Atmosphere")
	atmo.Name = "RuralAtmosphere"
	atmo.Parent = Lighting
end
atmo.Density = 0.52
atmo.Offset = 0.3
atmo.Color = Color3.fromRGB(100, 114, 128)
atmo.Decay = Color3.fromRGB(40, 52, 66)
atmo.Glare = 0
atmo.Haze = 2.6

local grade = Lighting:FindFirstChild("ColdNightGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "ColdNightGrade"
grade.TintColor = Color3.fromRGB(205, 220, 240)
grade.Saturation = -0.35
grade.Contrast = 0.08
grade.Brightness = -0.02
grade.Parent = Lighting

-- หมอกค่อยๆ หนาขึ้นบางลงเหมือนมีหมอกก้อนลอยผ่าน
task.spawn(function()
	while true do
		local target = 0.44 + math.random() * 0.14
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
mist.Color = ColorSequence.new(Color3.fromRGB(120, 135, 150))
mist.Brightness = 0.6 -- คืนนี้มืดมาก ถ้าให้แสงฉากคุมทั้งหมดหมอกจะมองไม่เห็น
mist.LightInfluence = 0.25
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

-- เสียงจิ้งหรีดรอบตัว (2D) เบาๆ
local cricketBed = makeLoop("CricketBed", ASSETS.CricketBed, 0.35, 0.94, SoundService)
local eerieAir = makeLoop("EerieAir", ASSETS.EerieAir, 0.07, 0.8, SoundService)

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

local groveCrickets = makePositional("GroveCrickets", ASSETS.CricketFar, Vector3.new(30, 3, 30), 0.5, 1.06)
local fieldCrickets = makePositional("FieldCrickets", ASSETS.CricketBed, Vector3.new(-20, 3, -55), 0.4, 0.88)
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

print("🦗 [Client] Ambience: จิ้งหรีดเหงาๆ + หมอกหนาว พร้อมแล้ว")
