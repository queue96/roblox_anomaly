-- AnomalyManager.luau (ModuleScript ฝั่ง Server)
-- Phase 4: รวมสิ่งผิดปกติ (Anomaly) ทั้งหมดของเกม "ปั๊มหลอดท้ายทุ่ง"
--   แต่ละผีมี apply(vehicle) = ทำให้รถ/ฉากผิดปกติ  และ reset() = คืนฉากให้ปกติ (ถ้าแตะของในฉาก)
--   CoreLoop สุ่มชื่อผีจาก AnomalyManager.Keys แล้วเรียก Apply(key, vehicle)
--   พอรถขี่ออกไปแล้ว CoreLoop เรียก ResetAnomalies() คืนวิทยุ หุ่นไล่กา ผีตานี น้ำมัน ให้กลับเป็นปกติ
-- ชื่อผี = คีย์บทพูดใน LanguageModule.Dialogues ด้วย

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local AnomalyManager = {}

-- ---------------------------------------------------------------- เสียง (Creator Store ฟรี)
local SOUNDS = {
	RadioMusic = "rbxassetid://108772936146894", -- The Old Radio (เพลงวิทยุเก่าๆ)
	MonkChant = "rbxassetid://1845929179", -- Chanting Monk A (สวดศพ)
	RadioStatic = "rbxassetid://9117159106", -- Old Radio Click/Tuning/Buzz
	DogHowl = "rbxassetid://748228812", -- Dog Howling
}

-- ---------------------------------------------------------------- ของในฉาก
local interactive = Workspace:WaitForChild("InteractiveProps")
local anomalyProps = Workspace:WaitForChild("AnomalyProps")
local radio = interactive:FindFirstChild("Radio")
local gasPump = interactive:FindFirstChild("GasPump")
local fuelLiquid = gasPump and gasPump:FindFirstChild("FuelLiquid") :: BasePart?
local scarecrow = anomalyProps:FindFirstChild("Scarecrow") :: Model?
local tani = anomalyProps:FindFirstChild("PhiTaniGhost") :: Model?

-- ค่าเดิมสำหรับ reset
local fuelColor = fuelLiquid and fuelLiquid.Color
local fuelMaterial = fuelLiquid and fuelLiquid.Material
local fuelSA = fuelLiquid and fuelLiquid:FindFirstChildOfClass("SurfaceAppearance") :: any
local fuelSAColor = fuelSA and fuelSA.Color
local scarecrowPivot = scarecrow and scarecrow:GetPivot()
local TANI_HIDDEN = 1
local TANI_SHOWN = 0.1

-- ---------------------------------------------------------------- helpers
local function showPart(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		local t = d:GetAttribute("ShowTransparency")
		if t ~= nil and (d:IsA("BasePart") or d:IsA("Decal")) then
			(d :: any).Transparency = t
		end
	end
end

local function setTransparency(root: Instance, t: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).Transparency = t
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

local function driverOf(v: Model): Model?
	return v:FindFirstChild("DriverNPC") :: Model?
end

-- วิทยุ: Sound อยู่ในชิ้นที่ใหญ่ที่สุดของโมเดลวิทยุ (เสียง 3D ได้ยินเฉพาะแถวร้าน)
local radioPart: BasePart? = nil
if radio then
	local best = 0
	for _, d in ipairs(radio:GetDescendants()) do
		if d:IsA("BasePart") then
			local s = d.Size.X * d.Size.Y * d.Size.Z
			if s > best then
				best = s
				radioPart = d
			end
		end
	end
end

local function radioSound(name: string, id: string, volume: number, looped: boolean): Sound?
	if not radioPart then
		return nil
	end
	local s = radioPart:FindFirstChild(name) :: Sound?
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.Parent = radioPart
	end
	local snd = s :: Sound
	snd.SoundId = id
	snd.Volume = volume
	snd.Looped = looped
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 8
	snd.RollOffMaxDistance = 60
	return snd
end
local radioMusic = radioSound("RadioMusic", SOUNDS.RadioMusic, 0.35, true)
local radioChant = radioSound("MonkChant", SOUNDS.MonkChant, 0.6, true)
local radioStatic = radioSound("RadioStatic", SOUNDS.RadioStatic, 0.5, false)
if radioChant then
	local eq = Instance.new("EqualizerSoundEffect") -- เสียงแตกๆ เหมือนคลื่นวิทยุเพี้ยน
	eq.LowGain = -12
	eq.MidGain = 4
	eq.HighGain = -6
	eq.Parent = radioChant
end

local function radioNormal()
	if radioChant then
		radioChant:Stop()
	end
	if radioMusic and not radioMusic.IsPlaying then
		radioMusic:Play()
	end
end

-- ---------------------------------------------------------------- รายชื่อผี
-- apply(v) รับรถที่ Clone แล้ว (ยังไม่ขี่เข้ามา)  reset() คืนของในฉาก (ไม่ต้องคืนรถ เพราะรถถูก Destroy)
type Anomaly = { apply: (Model) -> (), reset: (() -> ())? }

AnomalyManager.Anomalies = {
	-- 1. ผีไม่มีหัวซ้อนท้าย
	Anomaly_Headless = {
		apply = function(v)
			local g = v:FindFirstChild("GhostPassenger")
			if g then
				showPart(g)
			end
		end,
	},
	-- 2. ป้ายทะเบียน 4444 ป่าช้า
	Anomaly_Cemetery = {
		apply = function(v)
			local plate = v:FindFirstChild("LicensePlate")
			if plate then
				(plate :: any).NormalPlate.Enabled = false;
				(plate :: any).GhostPlate.Enabled = true
			end
		end,
	},
	-- 3. ผมผีพันล้อ
	Anomaly_WheelHair = {
		apply = function(v)
			local h = v:FindFirstChild("WheelHairAnomaly")
			if h then
				showPart(h)
			end
		end,
	},
	-- 4. คนขับหันหัวกลับหลัง 180°
	Anomaly_NeckTwist = {
		apply = function(v)
			local d = driverOf(v)
			local head = d and d:FindFirstChild("Head") :: BasePart?
			if not head then
				return
			end
			local c = head.CFrame
			local rot = c * CFrame.Angles(0, math.pi, 0)
			local parts = { head }
			for _, x in ipairs(head:GetDescendants()) do
				if x:IsA("BasePart") then
					table.insert(parts, x)
				end
			end
			for _, p in ipairs(parts) do
				p.CFrame = rot * c:ToObjectSpace(p.CFrame)
			end
		end,
	},
	-- 5. คนขับยิ้มกว้างถึงหู ตาโปน
	Anomaly_CreepySmile = {
		apply = function(v)
			local d = driverOf(v)
			local head = d and d:FindFirstChild("Head")
			if not head then
				return
			end
			local face = head:FindFirstChild("FaceNormal")
			if face then
				(face :: Decal).Transparency = 1
			end
			local creepy = head:FindFirstChild("CreepyFace")
			if creepy then
				showPart(creepy)
			end
		end,
	},
	-- 6. กระสือ: คนขับไม่มีขา มีไส้ห้อยเรืองแสงแทน
	Anomaly_Krasue = {
		apply = function(v)
			local d = driverOf(v)
			if not d then
				return
			end
			local legs = d:FindFirstChild("Legs")
			if legs then
				setTransparency(legs, 1)
			end
			local torso = d:FindFirstChild("Torso") :: BasePart?
			if not torso then
				return
			end
			local base = torso.CFrame * CFrame.new(0, -torso.Size.Y / 2, 0)
			for i = 1, 5 do
				local len = 1.2 + math.random() * 1.4
				local p = Instance.new("Part")
				p.Name = "KrasueEntrail"
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new(len, 0.22, 0.22)
				p.Material = Enum.Material.Neon
				p.Color = if i % 2 == 0 then Color3.fromRGB(150, 20, 30) else Color3.fromRGB(110, 140, 40)
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				local off = Vector3.new((i - 3) * 0.18, -len / 2, (math.random() - 0.5) * 0.4)
				p.CFrame = base * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90 + math.random(-15, 15)))
				p.Parent = d
			end
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 60, 40)
			glow.Range = 6
			glow.Brightness = 1.2
			glow.Parent = torso
		end,
	},
	-- 7. วิทยุในร้านเปลี่ยนจากเพลงเป็นเสียงพระสวดศพ
	Anomaly_MonkRadio = {
		apply = function(_v)
			if radioStatic then
				radioStatic:Play()
			end
			task.delay(0.8, function()
				if radioMusic then
					radioMusic:Stop()
				end
				if radioChant then
					radioChant:Play()
				end
			end)
		end,
		reset = radioNormal,
	},
	-- 8. ผีตานียืนอยู่หลังกอกล้วย (ปกติมองไม่เห็น)
	Anomaly_Tani = {
		apply = function(_v)
			if tani then
				for _, d in ipairs(tani:GetDescendants()) do
					if d:IsA("BasePart") then
						TweenService:Create(d, TweenInfo.new(4), { Transparency = TANI_SHOWN }):Play()
					end
				end
			end
		end,
		reset = function()
			if tani then
				setTransparency(tani, TANI_HIDDEN)
			end
		end,
	},
	-- 9. หุ่นไล่กาย้ายมายืนใกล้ร้าน หันหน้ามาทางผู้เล่น ตาแดงเรืองขึ้น
	Anomaly_Scarecrow = {
		apply = function(_v)
			if not (scarecrow and scarecrowPivot and gasPump) then
				return
			end
			local from = scarecrowPivot.Position
			local pump = (gasPump :: Model):GetPivot().Position
			local p = from:Lerp(pump, 0.55)
			p = Vector3.new(p.X, groundAt(p) + (from.Y - groundAt(from)), p.Z)
			-- pivot เดิมของหุ่นไล่กาหน้า = LookVector (หันเข้าร้าน)
			scarecrow:PivotTo(CFrame.lookAt(p, Vector3.new(pump.X, p.Y, pump.Z)))
			for _, d in ipairs(scarecrow:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Eye") then
					d.Color = Color3.fromRGB(255, 20, 20)
				end
			end
		end,
		reset = function()
			if scarecrow and scarecrowPivot then
				scarecrow:PivotTo(scarecrowPivot)
				for _, d in ipairs(scarecrow:GetDescendants()) do
					if d:IsA("BasePart") and string.find(d.Name, "Eye") then
						d.Color = d:GetAttribute("BaseColor") or d.Color
					end
				end
			end
		end,
	},
	-- 10. น้ำมันในหลอดแก้วกลายเป็นเลือด
	Anomaly_BloodFuel = {
		apply = function(_v)
			if fuelLiquid then
				local blood = Color3.fromRGB(110, 8, 12)
				TweenService:Create(fuelLiquid, TweenInfo.new(2.5), { Color = blood }):Play()
				fuelLiquid.Material = Enum.Material.Glass
				-- น้ำมันเป็น MeshPart ที่มี SurfaceAppearance (เท็กซ์เจอร์ส้ม) ต้องย้อมที่ SurfaceAppearance.Color ด้วย
				if fuelSA then
					TweenService:Create(fuelSA, TweenInfo.new(2.5), { Color = Color3.fromRGB(150, 10, 14) }):Play()
				end
			end
		end,
		reset = function()
			if fuelLiquid and fuelColor and fuelMaterial then
				fuelLiquid.Color = fuelColor
				fuelLiquid.Material = fuelMaterial
			end
			if fuelSA and fuelSAColor then
				fuelSA.Color = fuelSAColor
			end
		end,
	},
} :: { [string]: Anomaly }

-- จำสีตาหุ่นไล่กาไว้ก่อน (ใช้ตอน reset)
if scarecrow then
	for _, d in ipairs(scarecrow:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "Eye") then
			d:SetAttribute("BaseColor", d.Color)
		end
	end
end

AnomalyManager.Keys = {}
for k in pairs(AnomalyManager.Anomalies) do
	table.insert(AnomalyManager.Keys, k)
end
table.sort(AnomalyManager.Keys)

function AnomalyManager.Random(): string
	return AnomalyManager.Keys[math.random(#AnomalyManager.Keys)]
end

-- ผีที่แตะของในฉาก (มี reset) เช่น วิทยุ หุ่นไล่กา ต้อง Apply ตอนรถถึงตู้ปั๊ม ไม่ใช่ตอนต่อคิว
-- (ไม่งั้นลูกค้าคันหน้าที่ปกติจะโดนเข้าใจผิดว่าเป็นผี)
function AnomalyManager.IsWorld(key: string): boolean
	local a = AnomalyManager.Anomalies[key]
	return a ~= nil and a.reset ~= nil
end

function AnomalyManager.Apply(key: string, vehicle: Model): boolean
	local a = AnomalyManager.Anomalies[key]
	if not a then
		warn("[AnomalyManager] ไม่รู้จักผี " .. tostring(key))
		return false
	end
	a.apply(vehicle)
	return true
end

-- คืนของในฉากทุกอย่างให้ปกติ (เรียกตอนรถขี่ออกไป / ตอนเริ่มเกม)
function AnomalyManager.ResetAnomalies()
	for _, a in pairs(AnomalyManager.Anomalies) do
		if a.reset then
			a.reset()
		end
	end
end

-- ---------------------------------------------------------------- บรรยากาศทุ่ง: หมาหอนไกลๆ แบบสุ่ม
local ambienceStarted = false
function AnomalyManager.StartAmbience()
	if ambienceStarted then
		return
	end
	ambienceStarted = true
	local spots = {
		Vector3.new(-90, 4, 70),
		Vector3.new(80, 4, -70),
		Vector3.new(60, 4, 90),
		Vector3.new(-80, 4, -60),
	}
	local emitter = Instance.new("Part")
	emitter.Name = "DogHowlEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.Parent = Workspace
	local howl = Instance.new("Sound")
	howl.Name = "DogHowl"
	howl.SoundId = SOUNDS.DogHowl
	howl.Volume = 0.7
	howl.RollOffMode = Enum.RollOffMode.Linear
	howl.RollOffMinDistance = 40
	howl.RollOffMaxDistance = 260
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 2.5
	reverb.WetLevel = -4
	reverb.Parent = howl
	howl.Parent = emitter
	task.spawn(function()
		while true do
			task.wait(math.random(25, 60))
			emitter.Position = spots[math.random(#spots)]
			howl.PlaybackSpeed = 0.9 + math.random() * 0.2
			howl:Play()
		end
	end)
end

function AnomalyManager.Init()
	AnomalyManager.ResetAnomalies()
	radioNormal()
	AnomalyManager.StartAmbience()
end

return AnomalyManager
