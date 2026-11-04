-- AnomalyManager.luau (ModuleScript ฝั่ง Server)
-- Phase 4: รวมสิ่งผิดปกติ (Anomaly) ทั้งหมดของเกม "ปั๊มหลอดท้ายทุ่ง"
--   แต่ละผีมี apply(vehicle) = ทำให้รถ/ฉากผิดปกติ  และ reset() = คืนฉากให้ปกติ (ถ้าแตะของในฉาก)
--   CoreLoop สุ่มชื่อผีจาก AnomalyManager.Keys แล้วเรียก Apply(key, vehicle)
--   พอรถขี่ออกไปแล้ว CoreLoop เรียก ResetAnomalies() คืนวิทยุ หุ่นไล่กา ผีตานี น้ำมัน ให้กลับเป็นปกติ
-- ชื่อผี = คีย์บทพูดใน LanguageModule.Dialogues ด้วย
-- ระบบพนมมือ (เพิ่มเมื่อ 2026-10-28): ของผีทุกชิ้นติด tag "GhostOnly" (เห็นเฉพาะคนที่กำลังพนมมือ)
--   ส่วนของปกติที่ผีมาแทนที่ติด tag "NormalOnly" (หายไปตอนพนมมือ) — Client (PrayerController) สลับให้เฉพาะเครื่องตัวเอง
--   Server เก็บสถานะ "ไม่ได้พนมมือ" ไว้เสมอ: ของผีล่องหน ของปกติแสดงตามเดิม

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))

local AnomalyManager = {}

-- ---------------------------------------------------------------- เสียง (Creator Store ฟรี)
local SOUNDS = {
	RadioMusic = "rbxassetid://101156490081905", -- radio_song
	MonkChant = "rbxassetid://118042869785522", -- เสียงสวดมนต์นะโม ตัสสะ ที่นำเข้าใหม่
	RadioStatic = "rbxassetid://9117159106", -- Old Radio Click/Tuning/Buzz
	DogHowl = "rbxassetid://93714483057730", -- หมาหอน (ไฟล์ที่เจ้าของเกมอัปโหลด)
}

-- ---------------------------------------------------------------- ของในฉาก
local interactive = Workspace:WaitForChild("InteractiveProps")
local anomalyProps = Workspace:WaitForChild("AnomalyProps")
local radio = interactive:FindFirstChild("Radio")
local gasPump = (interactive:FindFirstChild("FuelPumps") or interactive):FindFirstChild("GasPump")
local fuelLiquid = gasPump and gasPump:FindFirstChild("FuelLiquid") :: BasePart?
local scarecrow = anomalyProps:FindFirstChild("Scarecrow") :: Model?
local tani = anomalyProps:FindFirstChild("PhiTaniGhost") :: Model?
-- rigged Tani (ServerStorage.GhostTemplates.ghost_tani) replaces the part ghost: feet on the ground where it stood,
-- facing the shop like the old one (its front was -Z of the torso)
if tani and GhostNPC.Has("ghost_tani") then
	local old = tani
	local p = old:GetPivot()
	local hit = Workspace:Raycast(p.Position + Vector3.new(0, 10, 0), Vector3.new(0, -40, 0), (function()
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Include
		rp.FilterDescendantsInstances = { Workspace.Terrain }
		return rp
	end)())
	local y = if hit then hit.Position.Y else p.Position.Y - 2.25
	-- face the spot where customers stop (tani_peek points at the driver); the old part ghost's pivot faced away
	local wps = Workspace:FindFirstChild("VehicleWaypoints")
	local stop = wps and wps:FindFirstChild("StopPoint") :: BasePart?
	local feet = Vector3.new(p.Position.X, y, p.Position.Z)
	local face = if stop then CFrame.lookAt(feet, Vector3.new(stop.Position.X, y, stop.Position.Z)) else CFrame.new(feet) * p.Rotation
	local m = GhostNPC.Spawn("ghost_tani", face, "tani_peek")
	if m then
		m.Name = "PhiTaniGhostModel"
		m.Parent = anomalyProps
		for _, d in ipairs(old:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanQuery = false
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
		tani = m
	end
end

-- ค่าเดิมสำหรับ reset
local fuelColor = fuelLiquid and fuelLiquid.Color
local fuelMaterial = fuelLiquid and fuelLiquid.Material
local fuelSA = fuelLiquid and fuelLiquid:FindFirstChildOfClass("SurfaceAppearance") :: any
local fuelSAColor = fuelSA and fuelSA.Color
local scarecrowPivot = scarecrow and scarecrow:GetPivot()
local TANI_HIDDEN = 1
local TANI_SHOWN = 0.1

-- ---------------------------------------------------------------- helpers
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

-- ---------------------------------------------------------------- ม่านตาทิพย์ (เห็นเฉพาะตอนพนมมือ)
-- attribute ที่ Client ใช้: VeilProp (ชื่อ property) / VeilShow (ค่าตอนมองเห็น) / VeilHide (ค่าตอนซ่อน) / VeilFade (วินาที)
local GHOST_TAG = "GhostOnly"
local NORMAL_TAG = "NormalOnly"

local function veilProp(d: Instance): string?
	if d:IsA("BasePart") or d:IsA("Decal") then
		return "Transparency"
	elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
		return "Enabled"
	elseif d:IsA("Sound") then
		return "Volume"
	end
	return nil
end

local function veil(d: Instance, tag: string, prop: string, shown: any, hidden: any, fade: number?)
	d:SetAttribute("VeilProp", prop)
	d:SetAttribute("VeilShow", shown)
	d:SetAttribute("VeilHide", hidden)
	d:SetAttribute("VeilFade", fade);
	(d :: any)[prop] = if tag == GHOST_TAG then hidden else shown
	CollectionService:AddTag(d, tag)
end

local function selfAndDescendants(root: Instance): { Instance }
	local list = root:GetDescendants()
	table.insert(list, 1, root)
	return list
end

-- ของผี: เห็นเฉพาะตอนพนมมือ
--   showT = ความโปร่งตอนเห็น (ไม่ใส่ = ใช้ค่าปัจจุบัน ข้ามชิ้นที่ล่องหนอยู่แล้ว)
--   useShowAttr = ใช้ attribute ShowTransparency ของชิ้นส่วนผีที่ซ่อนไว้ในแม่แบบรถ (เฉพาะชิ้นที่มี)
local function ghostOnly(root: Instance, showT: number?, useShowAttr: boolean?, fade: number?)
	for _, d in ipairs(selfAndDescendants(root)) do
		local prop = veilProp(d)
		if prop == "Transparency" then
			local cur = (d :: any).Transparency
			local s = if useShowAttr then d:GetAttribute("ShowTransparency") elseif showT then showT elseif cur < 1 then cur else nil
			if s ~= nil then
				veil(d, GHOST_TAG, prop, s, 1, fade)
			end
		elseif prop == "Enabled" and not useShowAttr then
			if (d :: any).Enabled then
				veil(d, GHOST_TAG, prop, true, false, fade)
			end
		elseif prop == "Volume" then
			veil(d, GHOST_TAG, prop, (d :: any).Volume, 0, fade)
		end
	end
end

-- ของปกติ: หายไปตอนพนมมือ (เห็นของจริงที่ผีบังไว้)
local function normalOnly(root: Instance)
	for _, d in ipairs(selfAndDescendants(root)) do
		local prop = veilProp(d)
		if prop == "Transparency" then
			if (d :: any).Transparency < 1 then
				veil(d, NORMAL_TAG, prop, (d :: any).Transparency, 1)
			end
		elseif prop == "Enabled" then
			if (d :: any).Enabled then
				veil(d, NORMAL_TAG, prop, true, false)
			end
		elseif prop == "Volume" then
			veil(d, NORMAL_TAG, prop, (d :: any).Volume, 0)
		end
	end
end

-- เอา tag ออก (Client คืนค่าเอง: GhostOnly -> VeilHide, NormalOnly -> VeilShow)
local function unveil(root: Instance?)
	if not root then
		return
	end
	for _, d in ipairs(selfAndDescendants(root)) do
		CollectionService:RemoveTag(d, GHOST_TAG)
		CollectionService:RemoveTag(d, NORMAL_TAG)
	end
end

-- Clone ของในฉากเป็น "ร่างผี" แยกชิ้น (ไม่แตะ CFrame ของจริง เพราะ Client ทับ CFrame ของ Server ไม่ได้)
local function apparition(src: Instance, name: string): Instance
	local c = src:Clone()
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	c.Name = name
	return c
end

local function driverOf(v: Model): Model?
	return v:FindFirstChild("DriverNPC") :: Model?
end

-- ชาวบ้านแบบใหม่ (HumanNPC, skinned mesh): ผีที่แก้หัว/หน้าใช้ร่างผีซ้อนแทนการแก้ชิ้นส่วน
--   ร่างผีเห็นตอนพนมมือ ตัวจริงหายไป
local function humanGhost(v: Model, kind: string): boolean
	local d = driverOf(v)
	if not (d and d:GetAttribute("Human")) then
		return false
	end
	local double, real = HumanNPC.MakeDouble(v, kind)
	if double then
		ghostOnly(double)
		for _, p in ipairs(real) do
			normalOnly(p)
		end
	end
	return true
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
	-- ได้ยินไกลขึ้น (เดิม 5/35: เดินห่างร้านนิดเดียวก็เงียบ) แต่เบาลง (RADIO_GAIN)
	snd.RollOffMinDistance = 8
	snd.RollOffMaxDistance = 70
	return snd
end
-- ความดังรวมของวิทยุ: ลด 30% (ทุกเสียงจากวิทยุ ทั้งค่าเริ่มต้นนี้และความดังของแต่ละสถานี SoundBank.RadioStations)
local RADIO_GAIN = 0.7
local RADIO_VOLUME = { music = 0.35 * RADIO_GAIN, chant = 0.52 * RADIO_GAIN, static = 0.38 * RADIO_GAIN }
local radioMusic = radioSound("RadioMusic", SOUNDS.RadioMusic, RADIO_VOLUME.music, true)
local radioChant = radioSound("MonkChant", SOUNDS.MonkChant, RADIO_VOLUME.chant, true)
local radioStatic = radioSound("RadioStatic", SOUNDS.RadioStatic, RADIO_VOLUME.static, false)
-- (เอาเสียงผีร้องโอเปร่าที่สุ่มดังจากวิทยุ pumpt_ghostsingging 127709670953007 ออกแล้ว ผู้ใช้สั่ง 2026-11-03)
if radioMusic then
	local eq = Instance.new("EqualizerSoundEffect") -- ตัดเสียงเบสออกให้เหมือนลำโพงวิทยุสังกะสีแตกๆ
	eq.LowGain = -20
	eq.MidGain = 8
	eq.HighGain = -10
	eq.Parent = radioMusic
	local dist = Instance.new("DistortionSoundEffect") -- เพิ่มความซ่าเหมือนคลื่นแทรกต่างจังหวัด
	dist.Level = 0.25
	dist.Parent = radioMusic
end
if radioChant then
	local eq = Instance.new("EqualizerSoundEffect") -- เสียงแตกๆ เหมือนคลื่นวิทยุเพี้ยน แต่ไม่แสบหู
	eq.LowGain = -20
	eq.MidGain = 8
	eq.HighGain = -10
	eq.Parent = radioChant
	local dist = Instance.new("DistortionSoundEffect")
	dist.Level = 0.25
	dist.Parent = radioChant
end
if radioStatic then
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -10
	eq.MidGain = 0
	eq.HighGain = -20 -- ตัดเสียงซ่าแหลมๆ ออกให้ฟังสบายหู
	eq.Parent = radioStatic
end

-- ระบบเปิด/ปิดและสลับสถานีวิทยุลูกทุ่ง 5 คลื่น (เริ่มเกมมาปิดวิทยุให้เงียบ ถ้าผู้เล่นอยากฟังค่อยเดินไปกดเปิดเอง)
local currentStationIdx = 0
local radioUserOn = false
local tunePrompt: ProximityPrompt? = nil

local function updateRadioPromptText()
	if tunePrompt then
		-- ข้อความจริงแต่ละภาษา: HUDController แปลตาม attribute "RadioOn"
		tunePrompt.ActionText = if radioUserOn then "Turn Off Radio" else "Turn On Radio"
		tunePrompt:SetAttribute("RadioOn", radioUserOn)
	end
end

local function turnOffRadio()
	radioUserOn = false
	if radioStatic then
		radioStatic.TimePosition = 0
		radioStatic:Play()
		task.delay(0.2, function()
			if radioStatic then
				radioStatic:Stop()
			end
		end)
	end
	if radioMusic and radioMusic.IsPlaying then
		radioMusic:Stop()
	end
	updateRadioPromptText()
end

local function tuneLukThungStation(idx: number?)
	if not radioMusic then
		return
	end
	radioUserOn = true
	if radioChant and radioChant.IsPlaying then
		radioChant:Stop()
	end
	local stations = SoundBank.RadioStations
	if #stations == 0 then
		return
	end
	currentStationIdx = idx or ((currentStationIdx % #stations) + 1)
	local st = stations[currentStationIdx]
	if radioStatic then
		radioStatic.TimePosition = 0
		radioStatic:Play()
		task.delay(0.45, function()
			if radioStatic then
				radioStatic:Stop()
			end
		end)
	end
	local resolvedId = SoundBank.ResolveId(st :: any)
	radioMusic.SoundId = resolvedId
	radioMusic.Volume = st.volume * RADIO_GAIN
	radioMusic.PlaybackSpeed = st.speed or 1
	SoundBank.ApplyWarmEffects(radioMusic, st)
	if not radioMusic.IsPlaying then
		radioMusic:Play()
	end
	updateRadioPromptText()
end

function AnomalyManager.SetGhostPresent(_isGhost: boolean)
	-- (สถานะผีส่งผ่าน Remotes:SetAttribute("IsAnomaly") ให้ฝั่ง Client ใช้ปรับเสียงสวดมนต์ของตัวผู้เล่นเอง)
end

-- ให้ผู้เล่นเดินไปกดเปิด/ปิดวิทยุในเพิงเองได้ (เริ่มเกมมาปิดเงียบไว้ก่อน)
if radioPart then
	tunePrompt = radioPart:FindFirstChild("TuneRadioPrompt") :: ProximityPrompt?
	if not tunePrompt then
		tunePrompt = Instance.new("ProximityPrompt")
		tunePrompt.Name = "TuneRadioPrompt"
		tunePrompt.ObjectText = "Radio"
		tunePrompt.KeyboardKeyCode = Enum.KeyCode.E
		tunePrompt.HoldDuration = 0.2
		tunePrompt.MaxActivationDistance = 8
		tunePrompt.RequiresLineOfSight = false
		tunePrompt.Parent = radioPart
	end
	-- ทุกปุ่มในเกมใช้ E (ปุ่มที่บันทึกค้างในไฟล์ place อาจยังเป็น R)
	(tunePrompt :: ProximityPrompt).KeyboardKeyCode = Enum.KeyCode.E
	updateRadioPromptText()
	tunePrompt.Triggered:Connect(function()
		if radioUserOn then
			turnOffRadio()
		else
			tuneLukThungStation()
		end
	end)
end

local function radioNormal()
	if radioChant then
		radioChant:Stop()
		unveil(radioChant)
	end
	if radioStatic then
		unveil(radioStatic)
	end
	if radioMusic then
		unveil(radioMusic)
		if radioUserOn then
			if currentStationIdx == 0 then
				tuneLukThungStation(1)
			elseif not radioMusic.IsPlaying then
				radioMusic:Play()
			end
		else
			radioMusic:Stop()
		end
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
			-- rigged ghost (ServerStorage.GhostTemplates.ghost_headless) sits where the old part ghost sat
			local torso = g and g:FindFirstChild("Torso") :: BasePart?
			if torso and GhostNPC.Has("ghost_headless") then
				local hip = CFrame.new(torso.CFrame:PointToWorldSpace(Vector3.new(0, -1.05, 0))) * v:GetPivot().Rotation
				local m = GhostNPC.SpawnSeated("ghost_headless", hip, "pillion_hug")
				if m then
					m.Name = "GhostPassengerModel"
					m.Parent = v
					ghostOnly(m)
					return
				end
			end
			if g then
				ghostOnly(g, nil, true)
			end
		end,
	},
	-- 2. ป้ายทะเบียน 4444 ป่าช้า
	Anomaly_Cemetery = {
		apply = function(v)
			local plate = v:FindFirstChild("LicensePlate")
			if plate then
				normalOnly((plate :: any).NormalPlate)
				veil((plate :: any).GhostPlate, GHOST_TAG, "Enabled", true, false)
			end
		end,
	},
	-- 3. ผมผีพันล้อ
	Anomaly_WheelHair = {
		apply = function(v)
			local h = v:FindFirstChild("WheelHairAnomaly")
			if h then
				ghostOnly(h, nil, true)
			end
		end,
	},
	-- 4. คนขับหันหัวกลับหลัง 180°
	Anomaly_NeckTwist = {
		apply = function(v)
			if humanGhost(v, "twist") then
				return
			end
			local d = driverOf(v)
			local head = d and d:FindFirstChild("Head") :: BasePart?
			if not head then
				return
			end
			-- หัวที่หันกลับเป็นชิ้น Clone แยก (เห็นตอนพนมมือ) หัวจริงหายไปแทน
			local twisted = apparition(head, "TwistedHead") :: BasePart
			local c = head.CFrame
			local rot = c * CFrame.Angles(0, math.pi, 0)
			local parts = { twisted }
			for _, x in ipairs(twisted:GetDescendants()) do
				if x:IsA("BasePart") then
					table.insert(parts, x)
				end
			end
			for _, p in ipairs(parts) do
				p.CFrame = rot * c:ToObjectSpace(p.CFrame)
			end
			twisted.Parent = d
			ghostOnly(twisted)
			normalOnly(head)
		end,
	},
	-- 5. คนขับยิ้มกว้างถึงหู ตาโปน
	Anomaly_CreepySmile = {
		apply = function(v)
			if humanGhost(v, "pale") then
				return
			end
			local d = driverOf(v)
			local head = d and d:FindFirstChild("Head")
			if not head then
				return
			end
			local face = head:FindFirstChild("FaceNormal")
			if face then
				normalOnly(face)
			end
			local creepy = head:FindFirstChild("CreepyFace")
			if creepy then
				ghostOnly(creepy, nil, true)
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
				normalOnly(legs)
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
				ghostOnly(p)
			end
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 60, 40)
			glow.Range = 6
			glow.Brightness = 1.2
			glow.Parent = torso
			ghostOnly(glow)
		end,
	},
	-- 8. คนขับใส่หน้ากากผีตาโขน (ร่างผี ghost_ta_khon นั่งทับคนขับ เห็นตอนพนมมือ คนขับจริงหายไป)
	Anomaly_TaKhon = {
		apply = function(v)
			local d = driverOf(v)
			if not (d and GhostNPC.Has("ghost_ta_khon")) then
				return
			end
			local hipPos: Vector3? = nil
			for _, x in ipairs(d:GetDescendants()) do
				if x:IsA("Bone") and x.Name == "hips" then
					hipPos = x.WorldPosition
					break
				end
			end
			local torso = d:FindFirstChild("Torso") :: BasePart?
			if not hipPos and torso then
				hipPos = (torso.CFrame * CFrame.new(0, -torso.Size.Y / 2, 0)).Position
			end
			if not hipPos then
				return
			end
			local m = GhostNPC.SpawnSeated("ghost_ta_khon", CFrame.new(hipPos) * v:GetPivot().Rotation, "mask_tilt")
			if m then
				m.Name = "GhostRiderModel"
				m.Parent = v
				ghostOnly(m)
				normalOnly(d)
			end
		end,
	},
	-- 11. ผีผู้หญิงนั่งซ้อนท้าย ค่อยๆ หันหน้าไปมองกระจกมองข้าง (ghost_mirror ที่เบาะหลังแบบผีหัวขาด)
	Anomaly_MirrorGhost = {
		apply = function(v)
			local g = v:FindFirstChild("GhostPassenger")
			local torso = g and g:FindFirstChild("Torso") :: BasePart?
			if not (torso and GhostNPC.Has("ghost_mirror")) then
				return
			end
			local hip = CFrame.new(torso.CFrame:PointToWorldSpace(Vector3.new(0, -1.05, 0))) * v:GetPivot().Rotation
			local m = GhostNPC.SpawnSeated("ghost_mirror", hip, "pillion_look")
			if m then
				m.Name = "GhostPassengerModel"
				m.Parent = v
				ghostOnly(m)
			end
		end,
	},
	-- ผีไม่แปลงร่าง เดินมาซื้อทั้งร่างผี (CoreLoop สร้างตัวด้วย AnomalyManager.BuildWalkIn ไม่ต้องแก้อะไรเพิ่ม)
	Anomaly_GhostWalkIn = {
		apply = function(_v) end,
	},
	-- 7. วิทยุในร้านเปลี่ยนจากเพลงเป็นเสียงพระสวดศพ (ใช้เสียงพระสวดวัดของวิทยุ ไม่เอาเสียงพูดของผู้เล่นมาปน)
	Anomaly_MonkRadio = {
		-- คนไม่ได้พนมมือยังได้ยินเพลงวิทยุตามปกติ คนพนมมือได้ยินเสียงสวดศพแทน
		apply = function(_v)
			if radioStatic then
				veil(radioStatic, GHOST_TAG, "Volume", RADIO_VOLUME.static, 0)
				radioStatic:Play()
			end
			if radioMusic and radioUserOn then
				veil(radioMusic, NORMAL_TAG, "Volume", RADIO_VOLUME.music, 0)
			end
			task.delay(0.8, function()
				if radioChant then
					radioChant.SoundId = SOUNDS.MonkChant
					radioChant.PlaybackSpeed = 1
					veil(radioChant, GHOST_TAG, "Volume", RADIO_VOLUME.chant, 0)
					radioChant:Play()
				end
			end)
		end,
		reset = radioNormal,
	},
	-- (ผีตานีหลังกอกล้วย / หุ่นไล่กาย้ายมาใกล้ร้าน ย้ายไปเป็น "ผีฉาก" ด้านล่าง: ไม่นับเป็นผีของลูกค้า 2026-11-03)
	-- 10. น้ำมันในหลอดแก้วกลายเป็นเลือด
	Anomaly_BloodFuel = {
		apply = function(_v)
			-- เลือดเป็นชิ้น Clone ทับน้ำมันจริง (CoreLoop เลื่อนระดับตามน้ำมันจริงด้วย) เห็นเฉพาะตอนพนมมือ
			if fuelLiquid and gasPump and not gasPump:FindFirstChild("BloodFuel") then
				local blood = apparition(fuelLiquid, "BloodFuel") :: BasePart
				blood.Color = Color3.fromRGB(110, 8, 12)
				blood.Material = Enum.Material.Glass
				blood.CanCollide = false
				blood.CanQuery = false
				-- น้ำมันเป็น MeshPart ที่มี SurfaceAppearance (เท็กซ์เจอร์ส้ม) ต้องย้อมที่ SurfaceAppearance.Color ด้วย
				local sa = blood:FindFirstChildOfClass("SurfaceAppearance") :: any
				if sa then
					sa.Color = Color3.fromRGB(150, 10, 14)
				end
				blood.Parent = gasPump
				ghostOnly(blood, nil, nil, 2.5)
				normalOnly(fuelLiquid)
			end
		end,
		reset = function()
			local blood = gasPump and gasPump:FindFirstChild("BloodFuel")
			if blood then
				blood:Destroy()
			end
			unveil(fuelLiquid)
			if fuelLiquid and fuelColor and fuelMaterial then
				fuelLiquid.Color = fuelColor
				fuelLiquid.Material = fuelMaterial
			end
			if fuelSA and fuelSAColor then
				fuelSA.Color = fuelSAColor
			end
		end,
	},
	-- 11. (ฝนตก) คนเดินมาท่ามกลางฝนหนักโดยไม่กางร่ม ตัวแห้งสนิท
	Anomaly_NoUmbrella = {
		apply = function(v)
			-- คนไม่ได้พนมมือยังเห็นร่ม คนพนมมือเห็นว่าเดินตากฝนมาโดยไม่มีร่ม
			local u = v:FindFirstChild("Umbrella")
			if u then
				normalOnly(u)
			end
		end,
	},
} :: { [string]: Anomaly }

-- ---------------------------------------------------------------- ผีฉาก (ไม่เกี่ยวกับลูกค้า / งานในร้าน)
-- โผล่นานๆ ครั้ง (CoreLoop.sceneryLoop) ให้เห็นเฉยๆ ทุกคนเห็นได้โดยไม่ต้องพนมมือ ปกติซ่อนไว้ ไม่ค้างในฉาก
--   Tani      ผีตานียืนหลังกอกล้วย (AnomalyProps.PhiTaniGhost)
--   Scarecrow หุ่นไล่กาย้ายมายืนใกล้ร้าน หันมาทางร้าน ตาแดง (ร่างแยก ScarecrowApparition ตัวจริงกลางทุ่งอยู่ที่เดิม)
--   Shadow    เงาดำตาแดงยืนหลังต้นไทร (AnomalyProps.BanyanShadowAnomaly)
-- โมเดลที่โผล่ติด tag "SceneryGhost" + attribute SceneryKind / ShowId: client/SceneryGhostWatch เล่นเสียงตอนเห็น
-- และมองค้างนานเกิน = ผีพุ่งใส่หน้าคนที่มองคนเดียว
local SCENERY_TAG = "SceneryGhost"
local banyanShadow = anomalyProps:FindFirstChild("BanyanShadowAnomaly") :: Model?
local SHADOW_SHOWN = 0.35
local sceneryShown: { [string]: Instance } = {}
local showCount = 0

local function fadeParts(root: Instance, t: number, time: number)
	for _, d in ipairs(selfAndDescendants(root)) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then -- RootPart of a rigged ghost stays invisible
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = t }):Play()
			else
				d.Transparency = t
			end
			d.CanQuery = t < 1
		end
	end
end

-- ซ่อนผีฉากทั้งหมดตอนเริ่ม (เดิมโมเดลค้างโผล่อยู่ในฉาก)
local function hideAllScenery()
	if tani then
		unveil(tani)
		fadeParts(tani, 1, 0)
	end
	if banyanShadow then
		unveil(banyanShadow)
		fadeParts(banyanShadow, 1, 0)
	end
	local ghost = anomalyProps:FindFirstChild("ScarecrowApparition")
	if ghost then
		ghost:Destroy()
	end
	for _, m in pairs(sceneryShown) do
		CollectionService:RemoveTag(m, SCENERY_TAG)
	end
	table.clear(sceneryShown)
end

AnomalyManager.SceneryKinds = {
	"Tani",
	"Scarecrow",
	"Shadow",
}

function AnomalyManager.ShowScenery(kind: string): Instance?
	if sceneryShown[kind] then
		return sceneryShown[kind]
	end
	local m: Instance? = nil
	if kind == "Tani" and tani then
		unveil(tani)
		fadeParts(tani, TANI_SHOWN, 3)
		m = tani
	elseif kind == "Shadow" and banyanShadow then
		unveil(banyanShadow)
		fadeParts(banyanShadow, SHADOW_SHOWN, 3)
		m = banyanShadow
	elseif kind == "Scarecrow" and scarecrow and scarecrowPivot and gasPump then
		local from = scarecrowPivot.Position
		local pump = (gasPump :: Model):GetPivot().Position
		local p = from:Lerp(pump, 0.55)
		p = Vector3.new(p.X, groundAt(p) + (from.Y - groundAt(from)), p.Z)
		local ghost = apparition(scarecrow, "ScarecrowApparition") :: Model
		-- หน้าของหุ่นไล่กาอยู่ฝั่ง -LookVector ของ pivot จึงหมุนกลับ 180° ให้หน้ามองร้าน
		ghost:PivotTo(CFrame.lookAt(p, Vector3.new(pump.X, p.Y, pump.Z)) * CFrame.Angles(0, math.pi, 0))
		for _, d in ipairs(ghost:GetDescendants()) do
			if d:IsA("BasePart") and string.find(d.Name, "Eye") then
				d.Color = Color3.fromRGB(255, 20, 20)
			end
		end
		fadeParts(ghost, 1, 0)
		ghost.Parent = anomalyProps
		for _, d in ipairs(selfAndDescendants(ghost)) do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(2), { Transparency = 0 }):Play()
				d.CanQuery = true
			end
		end
		m = ghost
	end
	if m then
		showCount += 1
		m:SetAttribute("SceneryKind", kind)
		m:SetAttribute("ShowId", showCount)
		CollectionService:AddTag(m, SCENERY_TAG)
		sceneryShown[kind] = m
	end
	return m
end

function AnomalyManager.HideScenery(kind: string)
	local m = sceneryShown[kind]
	sceneryShown[kind] = nil
	if not m then
		return
	end
	CollectionService:RemoveTag(m, SCENERY_TAG)
	if m.Name == "ScarecrowApparition" then
		fadeParts(m, 1, 1.5)
		task.delay(1.6, function()
			m:Destroy()
		end)
	else
		fadeParts(m, 1, 1.5)
	end
end

-- ผีที่ใช้ได้เฉพาะกับรถ (ต้องมีคนซ้อน / ป้ายทะเบียน / ล้อ) หรือเฉพาะคนเดินตอนฝนตก
local VEHICLE_ONLY = {
	Anomaly_Headless = true,
	Anomaly_Cemetery = true,
	Anomaly_WheelHair = true,
	Anomaly_TaKhon = true,
	Anomaly_MirrorGhost = true,
}
local WALKER_RAIN_ONLY = { Anomaly_NoUmbrella = true }
-- ชาวบ้านแบบใหม่เป็นผิวชิ้นเดียว ซ่อนแค่ขาไม่ได้ -> กระสือเกิดกับคนขับรถเท่านั้น
local NOT_HUMAN_WALKER = { Anomaly_Krasue = true }

-- ลูกค้าแบบไหนที่ผีตัวนี้เกิดได้ (ใช้ตอน admin เรียกผีเฉพาะตัว): "vehicle" | "walker"
function AnomalyManager.KindFor(key: string): string
	if WALKER_RAIN_ONLY[key] or key == "Anomaly_GhostWalkIn" then
		return "walker"
	end
	return "vehicle"
end

-- ผีตัวนี้ต้องฝนตก (คนเดินมาไม่กางร่ม)
function AnomalyManager.NeedsRain(key: string): boolean
	return WALKER_RAIN_ONLY[key] == true
end

-- สุ่มผีที่เข้ากับลูกค้าแบบนี้ (kind = "vehicle" | "walker")
function AnomalyManager.RandomFor(kind: string, raining: boolean): string
	local pool = {}
	for _, k in ipairs(AnomalyManager.Keys) do
		local ok = true
		if VEHICLE_ONLY[k] and kind ~= "vehicle" then
			ok = false
		end
		if WALKER_RAIN_ONLY[k] and not (kind == "walker" and raining) then
			ok = false
		end
		if NOT_HUMAN_WALKER[k] and kind == "walker" and HumanNPC.Available() then
			ok = false
		end
		-- ผีเดินมาทั้งร่าง: CoreLoop สุ่มแยกเอง (WalkInChance)
		if k == "Anomaly_GhostWalkIn" then
			ok = false
		end
		if ok then
			table.insert(pool, k)
		end
	end
	return pool[math.random(#pool)]
end

-- ผีที่เดินมาซื้อทั้งร่าง (ไม่แปลงร่าง): ท่าเดิน / ท่ายืนของแต่ละตัว
local WALK_IN = {
	{ name = "Pop", walk = "TwitchWalk", idle = "LickLips" },
	{ name = "ghost_child", walk = "ghost_glide", idle = "ghost_idle" },
	{ name = "ghost_shroud", walk = "shroud_glide", idle = "shroud_idle" },
	{ name = "ghost_funeral_woman", walk = "ghost_glide", idle = "ghost_glide" },
	{ name = "ghost_kuman_thong", walk = "run", idle = "kuman_giggle" },
	{ name = "ghost_tani", walk = "ghost_idle", idle = "ghost_idle" },
}

function AnomalyManager.BuildWalkIn(): Model?
	local list = {}
	for _, w in ipairs(WALK_IN) do
		if GhostNPC.Has(w.name) then
			table.insert(list, w)
		end
	end
	if #list == 0 then
		return nil
	end
	local w = list[math.random(#list)]
	local m = GhostNPC.Spawn(w.name, CFrame.new(), w.walk)
	if not m then
		return nil
	end
	m:SetAttribute("WalkClip", w.walk)
	m:SetAttribute("IdleClip", w.idle)
	m:SetAttribute("FocusBone", "head")
	-- ชิ้นล่องหนตรงหัว (กล่องคำพูดลอยเหนือหัว / CoreLoop.getHead หาชื่อ "Head")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == "head" then
			local h = Instance.new("Part")
			h.Name = "Head"
			h.Size = Vector3.new(0.8, 0.8, 0.8)
			h.Transparency = 1
			h.Anchored = true
			h.CanCollide = false
			h.CanQuery = false
			h.CanTouch = false
			h.CFrame = d.WorldCFrame
			h.Parent = m
			break
		end
	end
	return m
end

-- เดิน / หยุด (เฉพาะผีที่เดินมาทั้งร่าง: ตัวอื่นไม่ทำอะไร)
function AnomalyManager.WalkInMoving(m: Model, moving: boolean)
	local clip = m:GetAttribute(if moving then "WalkClip" else "IdleClip")
	if type(clip) == "string" then
		GhostNPC.Play(m, clip)
	end
end

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

-- คืนของในฉากเฉพาะผีตัวเดียว (ผีที่สวดเรียกมาเอง หมดเวลาแล้ว)
function AnomalyManager.Reset(key: string)
	local a = AnomalyManager.Anomalies[key]
	if a and a.reset then
		a.reset()
	end
end

-- คืนของในฉากทุกอย่างให้ปกติ (เรียกตอนรถขี่ออกไป / ตอนเริ่มเกม)
function AnomalyManager.ResetAnomalies()
	for _, a in pairs(AnomalyManager.Anomalies) do
		if a.reset then
			a.reset()
		end
	end
end

-- ---------------------------------------------------------------- บรรยากาศทุ่ง: ระบบเสียงธรรมชาติสุ่มรอบแมพ (Field Recordings จาก ProSoundEffects)
-- เสียงเล่นฝั่ง Server (ทุกคนได้ยินเหมือนกัน เป็นเสียง 3D จากจุดนั้นจริงๆ)
local AMBIENT = {
	-- 1. เสียงหมาหอนแว่วมาจากหลังเขา (ไฟล์ที่เจ้าของเกมอัปโหลด) เล่นจากต้นคลิปจนจบ ความเร็วเดิม
	--    ดังจากหลังแนวเขารอบทุ่ง (HILL_SPOTS) ได้ยินไกลกว่าเสียงอื่น (minDist/maxDist) ตัดเสียงแหลมให้อู้อี้เหมือนลอดเขามา
	--    (ก่อนหน้า: 748228812 หอนยาวรำคาญ -> ProSoundEffects coyote 9113956884 / 9113952977)
	{ name = "DogHowl", id = "rbxassetid://93714483057730", weight = 3, volume = 0.42, hill = true, minDist = 90, maxDist = 480, highGain = -14, speed = 1, fromStart = true },
	-- (เอาเสียงหลอนแนวธี่หยด EerieFx 116827997071173 ออกแล้ว ผู้ใช้สั่ง 2026-11-03)
	-- 2. ลมหนาวพัดวูบผ่านยอดไม้/ใบกล้วยเสียดสีกัน (Leaves Rustle Wind Blowing Through Trees 1 & 2)
	{ name = "WindLeaves1", id = "rbxassetid://9116258071", weight = 3, volume = 0.65, near = true, segment = 5.5, fade = true },
	{ name = "WindLeaves2", id = "rbxassetid://9116258282", weight = 2, volume = 0.60, near = true, segment = 5.0, fade = true },
	-- 3. ลมทุ่งพัดกรรโชกเอื่อยๆ (Ambient Wind)
	{ name = "WindGust", id = "rbxassetid://5799870105", weight = 2, volume = 0.55, segment = 6.0, fade = true },
	-- 4. เสียงกบ/เขียดร้องแว่วจากคันนาไกลๆ (Jungle Frogs)
	{ name = "NightFrogs", id = "rbxassetid://9112807844", weight = 2, volume = 0.45, segment = 5.0, fade = true },
	-- 5. เสียงกิ่งไม้ใหญ่แถวต้นไทร/หลังร้านลั่นตามแรงลม (Wood Creaking)
	{ name = "TreeBranchCreak", id = "rbxassetid://9125407169", weight = 2, volume = 0.50, near = true },
	-- 6. เสียงโครงไม้และแผ่นสังกะสีเพิงร้านขยับเบาๆ ตอนลมตี (Wood & Metal Creaking)
	{ name = "ShackTinWoodCreak", id = "rbxassetid://9126282474", weight = 2, volume = 0.42, near = true, segment = 3.2, fade = true },
	-- 7. เสียงนกกลางคืนกระพือปีกบินผ่านยอดไม้ไปเงียบๆ (Bird Wings Flap Flutter)
	{ name = "NightBirdWings", id = "rbxassetid://9114787449", weight = 1, volume = 0.48, near = true, segment = 2.5, fade = true },
}
local THUNDER_ID = "rbxassetid://9120016037"
local AMBIENT_SCALE = 0.65 -- ความดังรวมของเสียงสุ่มรอบทุ่ง
local FAR_SPOTS = {
	Vector3.new(-90, 4, 70),
	Vector3.new(80, 4, -70),
	Vector3.new(60, 4, 90),
	Vector3.new(-80, 4, -60),
	Vector3.new(30, 4, -90), -- กลางทุ่งหลังหุ่นไล่กา
	Vector3.new(-40, 4, 40), -- แถวต้นไทร
}
-- หลังแนวเขา: เขารอบทุ่งสูง ~25 studs ที่ระยะ 160-200 จากร้าน (ทิศตามถนน ตะวันออก/ตก เป็นที่ราบ ไม่ใช้)
local HILL_SPOTS = {
	Vector3.new(0, 4, 260),
	Vector3.new(130, 4, 225),
	Vector3.new(225, 4, 130),
	Vector3.new(225, 4, -130),
	Vector3.new(130, 4, -225),
	Vector3.new(0, 4, -260),
	Vector3.new(-130, 4, -225),
	Vector3.new(-225, 4, -130),
	Vector3.new(-225, 4, 130),
	Vector3.new(-130, 4, 225),
}
local NEAR_SPOTS = {
	Vector3.new(14, 4, 20), -- หลังร้าน
	Vector3.new(-14, 4, 18),
	Vector3.new(20, 4, -2), -- ข้างร้าน
	Vector3.new(-20, 4, 4),
}

local ambienceStarted = false
function AnomalyManager.StartAmbience()
	if ambienceStarted then
		return
	end
	ambienceStarted = true
	local emitter = Instance.new("Part")
	emitter.Name = "AmbienceEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.Parent = Workspace
	local sounds: { [string]: Sound } = {}
	for _, a in ipairs(AMBIENT) do
		local snd = Instance.new("Sound")
		snd.Name = a.name
		snd.SoundId = a.id
		snd.Volume = a.volume * AMBIENT_SCALE
		snd.PlaybackSpeed = 1.0
		snd.RollOffMode = Enum.RollOffMode.Linear
		snd.RollOffMinDistance = a.minDist or (if a.near then 12 else 65)
		snd.RollOffMaxDistance = a.maxDist or (if a.near then 80 else 300)
		local warmEq = Instance.new("EqualizerSoundEffect")
		warmEq.Name = "WarmAmbientEQ"
		warmEq.LowGain = 1
		warmEq.MidGain = 0
		warmEq.HighGain = a.highGain or -8 -- ตัดย่านแหลมเบาๆ ไม่ให้เสียงยืดหรืออู้อี้
		warmEq.Parent = snd
		snd.Parent = emitter
		sounds[a.name] = snd
	end
	-- ฟ้าร้อง (เฉพาะตอนฝนตก) เสียงทั่วทั้งแมพ + Client ทำฟ้าแลบจาก Attribute ThunderAt
	local thunder = Instance.new("Sound")
	thunder.Name = "Thunder"
	thunder.SoundId = THUNDER_ID
	thunder.Volume = 0.42
	local thunderEq = Instance.new("EqualizerSoundEffect")
	thunderEq.LowGain = 3
	thunderEq.MidGain = 0
	thunderEq.HighGain = -10 -- ฟ้าร้องทุ้มลึก ไม่แสบหู
	thunderEq.Parent = thunder
	thunder.Parent = game:GetService("SoundService")
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

	local total = 0
	for _, a in ipairs(AMBIENT) do
		total += a.weight
	end
	local function pickAmbient()
		local r = math.random() * total
		for _, a in ipairs(AMBIENT) do
			r -= a.weight
			if r <= 0 then
				return a
			end
		end
		return AMBIENT[1]
	end

	-- เล่นเสียงหนึ่งจากจุดสุ่ม: segment = เล่นไม่เกินกี่วินาที (สุ่มช่วงกลางคลิป เว้นแต่ fromStart), fade = ค่อยๆ เข้า/ออก
	local function playAmbient(a)
		local snd = sounds[a.name]
		local list = if a.hill then HILL_SPOTS elseif a.near then NEAR_SPOTS else FAR_SPOTS
		emitter.Position = list[math.random(#list)]
		local targetVol = a.volume * AMBIENT_SCALE
		snd.PlaybackSpeed = (a.speed or 0.99) - 0.05 + math.random() * 0.10
		if a.segment and not a.fromStart and snd.TimeLength > a.segment + 1 then
			snd.TimePosition = math.random() * (snd.TimeLength - a.segment)
		else
			snd.TimePosition = 0
		end
		if a.fade then
			snd.Volume = 0
			snd:Play()
			TweenService:Create(snd, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Volume = targetVol }):Play()
		else
			snd.Volume = targetVol
			snd:Play()
		end
		if a.segment then
			local seg = a.segment
			if a.fade and seg > 1.5 then
				task.delay(seg - 1.2, function()
					TweenService:Create(snd, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
				end)
			end
			task.delay(seg, function()
				snd:Stop()
			end)
		end
	end

	task.spawn(function()
		-- ตอนเริ่มเกม: หน่วง 25 วินาทีแล้วเปิดด้วยเสียงหมาหอนแว่วจากหลังเขา
		-- (คัทซีนเปิด/จบคืน: เงียบ ไม่สุ่มเสียง — ReplicatedStorage.CutsceneRunning จาก Cutscene.luau)
		local function inCutscene(): boolean
			return game:GetService("ReplicatedStorage"):GetAttribute("CutsceneRunning") == true
		end
		game:GetService("ReplicatedStorage"):GetAttributeChangedSignal("CutsceneRunning"):Connect(function()
			if inCutscene() then
				for _, s in pairs(sounds) do
					s:Stop()
				end
				thunder:Stop()
			end
		end)
		task.delay(25, function()
			if not inCutscene() then
				playAmbient(AMBIENT[1])
			end
		end)
		-- สุ่มเสียงธรรมชาติรอบทุ่งทุกๆ 45 วินาที
		while true do
			task.wait(45)
			if not inCutscene() then
				playAmbient(pickAmbient())
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(math.random(18, 40))
			if remotes:GetAttribute("Weather") == "Rain" and not game:GetService("ReplicatedStorage"):GetAttribute("CutsceneRunning") then
				remotes:SetAttribute("ThunderAt", os.clock()) -- Client: ฟ้าแลบก่อน
				task.wait(0.4 + math.random() * 0.8) -- แล้วเสียงตามมา
				thunder.PlaybackSpeed = 1.0
				thunder:Play()
			end
		end
	end)
	-- สุ่มหมุนเปลี่ยนคลื่นวิทยุลูกทุ่งเหงาๆ อัตโนมัติทุกๆ 70 - 130 วินาที (เฉพาะตอนที่ผู้เล่นเปิดวิทยุไว้ และไม่ได้เป็นเสียงสวดศพ)
	task.spawn(function()
		while true do
			task.wait(math.random(70, 130))
			if radioUserOn and radioChant and not radioChant.IsPlaying then
				tuneLukThungStation()
			end
		end
	end)
end

function AnomalyManager.Init()
	AnomalyManager.ResetAnomalies()
	hideAllScenery()
	radioNormal()
	AnomalyManager.StartAmbience()
end

return AnomalyManager
