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
local RunService = game:GetService("RunService")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local GhostFloat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostFloat")) :: any
local Bilingual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilingual")) -- ป้ายทะเบียนผีตามภาษาของแต่ละคน
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) -- ชื่อลูกค้าบนป้ายมรณะ
local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))

local AnomalyManager = {}

-- ชื่อเดือนย่อบนป้ายมรณะ (Anomaly_Cemetery)
local TH_MONTHS = { "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.", "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค." }
local EN_MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }

-- ---------------------------------------------------------------- เสียง (Creator Store ฟรี)
local SOUNDS = {
	RadioMusic = "rbxassetid://101156490081905", -- radio_song
	MonkChant = "rbxassetid://118042869785522", -- เสียงสวดมนต์นะโม ตัสสะ ที่นำเข้าใหม่ (ไม่ใช้ในวิทยุแล้ว)
	-- funeral_music_2 (เจ้าของเกมอัปโหลด 2026-11-08) ยาว 94.8 วิ: วิทยุผีเล่นเพลงงานศพแทนเสียงสวด
	-- (ไฟล์แรก funeral_music 109680101637101 ยาวแค่ 30 วิ วนซ้ำเร็วเกิน)
	FuneralMusic = "rbxassetid://92787263614050",
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
-- chant = เพลงงานศพของผีวิทยุ: ดังเองโดยไม่ต้องเปิดวิทยุ เบากว่าเสียงสวดเดิม (0.52 -> 0.32; ลอง 1.8 แล้วดังไป ผู้ใช้ 2026-11-08)
local RADIO_VOLUME = { music = 0.35 * RADIO_GAIN, chant = 0.32 * RADIO_GAIN, static = 0.38 * RADIO_GAIN }
local radioMusic = radioSound("RadioMusic", SOUNDS.RadioMusic, RADIO_VOLUME.music, true)
-- (ชื่อ Sound ยังเป็น "MonkChant" ให้ SettingsController จัดเข้ากลุ่มเพลง แต่เล่นเพลงงานศพแล้ว)
local radioChant = radioSound("MonkChant", SOUNDS.FuneralMusic, RADIO_VOLUME.chant, true)
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
	-- อู้อี้หนักๆ เหมือนดังลอดมาจากที่ไกล/ข้างฝา (ผู้ใช้ 2026-11-08): ตัดเสียงแหลมเกือบหมด เหลือทุ้มกับกลางตุ้บๆ
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -4
	eq.MidGain = -2
	eq.HighGain = -40
	eq.Parent = radioChant
	local dist = Instance.new("DistortionSoundEffect")
	dist.Level = 0.18
	dist.Parent = radioChant
	-- ระยะได้ยินเท่าเสียงวิทยุอื่น (radioSound 8-70 studs) ไม่ดังเต็มทั่วลานปั๊ม
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
local radioOmenOn = false -- ลางผีใหญ่กำลังเล่นทางวิทยุ (ดูด้านล่าง): ห้ามเพลงลูกทุ่งดังทับ
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
	if radioOmenOn then
		-- ลางผีใหญ่อยู่: จำไว้ว่าเปิด แล้วเพลงค่อยดังหลังลางจบ
		updateRadioPromptText()
		return
	end
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

-- วิทยุผี (เดิมเสียงสวดแว่วแป๊บเดียว ผู้ใช้ 2026-11-05)
-- (2026-11-07/08 ผู้ใช้สั่ง: เปลี่ยนเสียงสวดเป็นเพลงงานศพ SOUNDS.FuneralMusic เปิดค้างตลอดตอนผีอยู่ ไม่ขาดๆ หายๆ
--  เสียงอู้อี้แบบลำโพงวิทยุ: EQ + Distortion ที่ใส่ไว้กับ radioChant ด้านบน)
local chantToken = 0

local function radioNormal()
	chantToken += 1
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

-- ลางผีใหญ่ทางวิทยุ (ผู้ใช้ 2026-11-22): จิ้งหรีดเงียบ (Remotes "BigOmen") -> วิทยุในเพิงซ่าขึ้นมาเอง
--   แล้วกลายเป็นเสียงสวดนะโมแว่วๆ ช้าๆ อู้อี้ (เปิดเองแม้ผู้เล่นปิดวิทยุไว้ ทุกคนได้ยิน ไม่ใช่ veil แบบผีวิทยุ)
--   ผีใหญ่มาถึง (Remotes "BigEvent") หรือลางยกเลิก = ซ่าแว่บแล้วเงียบ เพลงเดิมกลับมาถ้าผู้เล่นเปิดวิทยุไว้
--   ใช้ Sound แยก OmenChant / OmenStatic: ไม่ยุ่งกับ radioChant ของผีวิทยุ (Anomaly_MonkRadio)
do
	local omenChant = radioSound("OmenChant", SOUNDS.MonkChant, 0, true)
	local omenStatic = radioSound("OmenStatic", SOUNDS.RadioStatic, 0, true)
	local CHANT_VOL = RADIO_VOLUME.chant * 1.1
	local STATIC_VOL = RADIO_VOLUME.static * 1.2
	if omenChant then
		omenChant.PlaybackSpeed = 0.86 -- ช้าลง เสียงต่ำ หลอนกว่าเสียงสวดตอนพนมมือ
		local eq = Instance.new("EqualizerSoundEffect") -- ลำโพงวิทยุเก่า: ตัดทุ้มกับแหลม
		eq.LowGain = -14
		eq.MidGain = 4
		eq.HighGain = -24
		eq.Parent = omenChant
		local dist = Instance.new("DistortionSoundEffect")
		dist.Level = 0.3
		dist.Parent = omenChant
		local echo = Instance.new("EchoSoundEffect") -- แว่วเหมือนดังมาจากที่ไกล
		echo.Delay = 0.35
		echo.Feedback = 0.25
		echo.WetLevel = -8
		echo.Parent = omenChant
	end
	if omenStatic then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -10
		eq.MidGain = 0
		eq.HighGain = -20
		eq.Parent = omenStatic
	end
	local token = 0
	local pausedMusic = false
	local function fadeTo(s: Sound?, vol: number, t: number)
		if s then
			game:GetService("TweenService"):Create(s, TweenInfo.new(t), { Volume = vol }):Play()
		end
	end
	local function start()
		if radioOmenOn or not (omenChant and omenStatic) then
			return
		end
		radioOmenOn = true
		token += 1
		local my = token
		pausedMusic = false
		if radioMusic and radioMusic.IsPlaying then
			radioMusic:Pause()
			pausedMusic = true
		end
		-- ซ่าดังขึ้นมาเอง 1.6 วิ แล้วจางลงเหลือเสียงฟู่ใต้เสียงสวดที่ค่อยๆ ดังขึ้น
		omenStatic.Volume = STATIC_VOL
		omenStatic.TimePosition = 0
		omenStatic:Play()
		task.delay(1.6, function()
			if token ~= my then
				return
			end
			fadeTo(omenStatic, STATIC_VOL * 0.18, 2.5)
			omenChant.Volume = 0
			local len = omenChant.TimeLength
			omenChant.TimePosition = if len > 0 then math.random() * len * 0.6 else 0
			omenChant:Play()
			fadeTo(omenChant, CHANT_VOL, 3.5)
		end)
	end
	local function stop()
		if not radioOmenOn then
			return
		end
		token += 1
		local my = token
		-- ซ่าแว่บ แล้วเงียบ
		if omenStatic then
			omenStatic.Volume = STATIC_VOL
		end
		fadeTo(omenChant, 0, 0.5)
		task.delay(0.6, function()
			if token ~= my then
				return
			end
			if omenChant then
				omenChant:Stop()
			end
			if omenStatic then
				omenStatic:Stop()
			end
			radioOmenOn = false
			if radioUserOn and radioMusic then
				if pausedMusic then
					radioMusic:Resume()
				elseif currentStationIdx == 0 then
					tuneLukThungStation(1)
				elseif not radioMusic.IsPlaying then
					radioMusic:Play()
				end
			end
			pausedMusic = false
		end)
	end
	local remotesF = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
	local function update()
		local omen = remotesF:GetAttribute("BigOmen") == true
		local event = remotesF:GetAttribute("BigEvent") ~= nil
		if omen and not event then
			start()
		else
			stop()
		end
	end
	remotesF:GetAttributeChangedSignal("BigOmen"):Connect(update)
	remotesF:GetAttributeChangedSignal("BigEvent"):Connect(update)
end

-- ---------------------------------------------------------------- รายชื่อผี
-- apply(v) รับรถที่ Clone แล้ว (ยังไม่ขี่เข้ามา)  reset() คืนของในฉาก (ไม่ต้องคืนรถ เพราะรถถูก Destroy)
type Anomaly = { apply: (Model) -> (), reset: (() -> ())? }

-- ผีซ้อนท้าย (หัวขาด / มองกระจก): ใต้ Torso ผีเก่า 1.05 = แค่ 0.05 เหนือเบาะ แต่ก้นร่าง v2 อยู่ต่ำกว่ากระดูก hips ~0.45
-- -> ยกขึ้นให้ก้นวางบนเบาะพอดี (วัดใน Studio 2026-11-13: CustomerBike / Saleng เบาะ Chassis; ผู้ใช้: ก้นจมเบาะ)
local PILLION_LIFT = 0.42

-- ผีขี่แทนคนขับ (ตาโขน): มือ/เท้าจับแฮนด์ วางเท้าบนที่พักเท้า ด้วย IK ชุดเดียวกับคนขับที่ซ่อนไว้
-- (Target/Pole เป็น Attachment ใน DriverNPC.IKTargets ซึ่งยังอยู่ ขยับไปกับรถ) ผู้ใช้ 2026-11-13: มือไม่กำแฮนด์
local function copyRiderIK(driver: Model, ghost: Model)
	local dac = driver:FindFirstChildOfClass("AnimationController")
	local gac = ghost:FindFirstChildOfClass("AnimationController")
	if not dac then
		return
	end
	if not gac then
		gac = Instance.new("AnimationController")
		gac.Parent = ghost
	end
	-- IKControl ทำงานผ่าน Animator (ท่า mocap ไม่สร้าง Animator ให้ ต้องมีเอง)
	if not (gac :: Instance):FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = gac
	end
	local bones: { [string]: Bone } = {}
	for _, b in ipairs(ghost:GetDescendants()) do
		if b:IsA("Bone") then
			bones[b.Name] = b
		end
	end
	for _, ik in ipairs(dac:GetChildren()) do
		if ik:IsA("IKControl") and ik.ChainRoot and ik.EndEffector then
			local root, tip = bones[ik.ChainRoot.Name], bones[ik.EndEffector.Name]
			if root and tip then
				local c = ik:Clone()
				c.ChainRoot = root
				c.EndEffector = tip
				c.Parent = gac
			end
		end
	end
end

AnomalyManager.Anomalies = {
	-- 1. ผีไม่มีหัวซ้อนท้าย
	Anomaly_Headless = {
		apply = function(v)
			local g = v:FindFirstChild("GhostPassenger")
			-- rigged ghost (ServerStorage.GhostTemplates.ghost_headless) sits where the old part ghost sat
			local torso = g and g:FindFirstChild("Torso") :: BasePart?
			if torso and GhostNPC.Has("ghost_headless") then
				local hip = CFrame.new(torso.CFrame:PointToWorldSpace(Vector3.new(0, -1.05 + PILLION_LIFT, 0))) * v:GetPivot().Rotation
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
		-- ป้ายมรณะของลูกค้า (ผู้ใช้ 2026-11-16: "4444 ตาย" บอกตรงเกิน ไม่หลอน): คนขับเป็นคนปกติ พนมมือแล้วป้ายทะเบียนกลายเป็น
		-- ป้ายชื่อหน้าศพ ขาวตัวหนังสือดำ เขียนชื่อคนที่กำลังคุยกับเราอยู่ (ชื่อเดียวกับในซับ) + "มรณะ <วันนี้>" ตามภาษาของแต่ละคน
		-- ชื่อ: CoreLoop.spawnCustomer ตั้ง attribute CustomerNameKey ไว้ที่รถก่อน Apply (ไม่มี = "ไม่ทราบชื่อ")
		apply = function(v)
			local plate = v:FindFirstChild("LicensePlate")
			if plate then
				-- ป้ายในแม่แบบรถ (ไฟล์ place) ยังเป็นป้ายแดงเรือง "4444 / ป่าช้า CEMETERY" + แถบเลือดหยด: แต่งทับตอนใช้จริง
				local ghostGui = plate:FindFirstChild("GhostPlate")
				local frame = ghostGui and ghostGui:FindFirstChildOfClass("Frame")
				if ghostGui and ghostGui:IsA("SurfaceGui") and frame then
					local nameKey = v:GetAttribute("CustomerNameKey")
					local names = (LanguageModule :: any).Names
					local entry = if type(nameKey) == "string" then names[nameKey] else nil
					local nameTH = if entry then entry.th else "ไม่ทราบชื่อ"
					local nameEN = if entry then entry.en else "Name unknown"
					-- ภาษาอื่น: ชื่อ + คำว่า "มรณะ" ตามคำแปลใน LanguageModule (ยังไม่แปล = อังกฤษ)
					local nameMore, diedMore = {}, {}
					for _, l in ipairs(LanguageModule.Langs) do
						if l ~= "th" and l ~= "en" then
							nameMore[l] = if entry then LanguageModule.Pick(entry, l) else LanguageModule.GetUI("TombNoName", l)
							diedMore[l] = LanguageModule.GetUI("TombDied", l)
						end
					end
					-- วันนี้ตามเวลาไทย (UTC+7) ปี พ.ศ.
					local d = os.date("!*t", os.time() + 7 * 3600)
					local dateTH = string.format("%d %s %d", d.day, TH_MONTHS[d.month], d.year + 543)
					local dateEN = string.format("%d %s %d", d.day, EN_MONTHS[d.month], d.year)
					ghostGui.Brightness = 1 -- เดิม 2 (ตัวหนังสือแดงเรือง): ป้ายกระดาษขาวไม่ต้องเรือง แค่อ่านออกในที่มืด
					frame.BackgroundColor3 = Color3.fromRGB(226, 222, 208)
					local ink = Color3.fromRGB(18, 16, 16)
					for _, t in ipairs(frame:GetChildren()) do
						if t:IsA("TextLabel") then
							t.TextColor3 = ink
							if t.Position.Y.Scale > 0.3 then
								t.Font = Enum.Font.SourceSans
								local more = {}
								for l, w in pairs(diedMore) do
									more[l] = w .. " " .. dateEN
								end
								Bilingual.Text(t, "มรณะ " .. dateTH, "DIED " .. dateEN, more)
							else
								t.Font = Enum.Font.SourceSansBold
								Bilingual.Text(t, nameTH, nameEN, nameMore)
							end
						elseif t:IsA("Frame") then
							t.Visible = false -- แถบเลือดหยดของป้ายเดิม
						end
					end
					-- ขอบดำแบบป้ายไว้ทุกข์
					if not frame:FindFirstChild("MourningBorder") then
						local stroke = Instance.new("UIStroke")
						stroke.Name = "MourningBorder"
						stroke.Color = ink
						stroke.Thickness = 5
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Parent = frame
					end
				end
				normalOnly((plate :: any).NormalPlate)
				veil((plate :: any).GhostPlate, GHOST_TAG, "Enabled", true, false)
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
				copyRiderIK(d, m)
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
			local hip = CFrame.new(torso.CFrame:PointToWorldSpace(Vector3.new(0, -1.05 + PILLION_LIFT, 0))) * v:GetPivot().Rotation
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
		-- เพลงงานศพเปิดค้างวนตลอด (Looped) จนผีไป: ลูกค้าผีออกจากร้าน / ผีที่สวดเรียกหมดเวลา -> reset = radioNormal (ผู้ใช้ 2026-11-08)
		apply = function(_v)
			chantToken += 1
			local my = chantToken
			if radioStatic then
				veil(radioStatic, GHOST_TAG, "Volume", RADIO_VOLUME.static, 0)
				radioStatic:Play()
			end
			if radioMusic and radioUserOn then
				veil(radioMusic, NORMAL_TAG, "Volume", RADIO_VOLUME.music, 0)
			end
			task.delay(0.8, function()
				if chantToken ~= my or not radioChant then
					return
				end
				radioChant.SoundId = SOUNDS.FuneralMusic
				radioChant.PlaybackSpeed = 1
				veil(radioChant, GHOST_TAG, "Volume", RADIO_VOLUME.chant, 0)
				radioChant:SetAttribute("VeilFade", nil)
				radioChant:Play()
				-- เริ่มจากจุดสุ่มในเพลง (ช่วงแรก 75%) เจอผีนี้หลายรอบก็ได้ยินคนละท่อน ไม่เริ่มแบบเดิมทุกครั้ง
				local len = radioChant.TimeLength
				radioChant.TimePosition = if len > 0 then math.random() * len * 0.75 else 0
			end)
		end,
		reset = radioNormal,
	},
	-- (ผีตานีหลังกอกล้วย / หุ่นไล่กาย้ายมาใกล้ร้าน ย้ายไปเป็น "ผีฉาก" ด้านล่าง: ไม่นับเป็นผีของลูกค้า 2026-11-03)
	-- 10. น้ำมันในหลอดแก้วกลายเป็นเลือด
	Anomaly_BloodFuel = {
		-- หลอดน้ำมันทั้ง 2 ตู้ (เบนซิน + ดีเซล) ค่อยๆ กลายเป็นสีเลือดเมื่อตาทิพย์เปิด (BLOOD_FADE วินาที ผู้ใช้ 2026-11-07)
		-- ตัวลูกค้าไม่แปลงร่างผี (เอาออกจาก CUSTOMER_GHOST_FORM แล้ว)
		apply = function(_v)
			-- เลือดเป็นชิ้น Clone ทับน้ำมันจริง (CoreLoop เลื่อนระดับตามน้ำมันจริงด้วย) เห็นเฉพาะตอนพนมมือ
			local group = interactive:FindFirstChild("FuelPumps") or interactive
			for _, pumpName in ipairs({ "GasPump", "DieselPump" }) do
				local pump = group:FindFirstChild(pumpName)
				local liquid = pump and pump:FindFirstChild("FuelLiquid") :: BasePart?
				if pump and liquid and not pump:FindFirstChild("BloodFuel") then
					-- ค่อยๆ แดง: สลับเป็นชิ้นเลือดทันที (หน้าตาเหมือนน้ำมันเดิมเป๊ะ วัสดุเดิม) แล้ว Client ไล่สีไปแดงใน BLOOD_TINT วิ
					-- (เดิมเฟดความโปร่งข้ามกัน 2 ชิ้น 3 วิ -> ช่วงกลางทั้งคู่โปร่งจนหลอดดูว่างเปล่า ผู้ใช้ 2026-11-08)
					local BLOOD_TINT = 3
					local blood = apparition(liquid, "BloodFuel") :: BasePart
					local red = Color3.fromRGB(110, 8, 12)
					blood:SetAttribute("VeilTintFrom", liquid.Color)
					blood:SetAttribute("VeilTintTo", red)
					blood:SetAttribute("VeilTintTime", BLOOD_TINT)
					blood.Color = red
					blood.CanCollide = false
					blood.CanQuery = false
					-- น้ำมันเป็น MeshPart ที่มี SurfaceAppearance (เท็กซ์เจอร์ส้ม/เขียว) ต้องย้อมที่ SurfaceAppearance.Color ด้วย
					local sa = blood:FindFirstChildOfClass("SurfaceAppearance") :: any
					if sa then
						local saRed = Color3.fromRGB(150, 10, 14)
						blood:SetAttribute("VeilTintSAFrom", sa.Color)
						blood:SetAttribute("VeilTintSATo", saRed)
						sa.Color = saRed
					end
					blood.Parent = pump
					ghostOnly(blood, nil, nil, 0)
					normalOnly(liquid)
					liquid:SetAttribute("VeilFade", 0)
				end
			end
		end,
		reset = function()
			local group = interactive:FindFirstChild("FuelPumps") or interactive
			for _, pumpName in ipairs({ "GasPump", "DieselPump" }) do
				local pump = group:FindFirstChild(pumpName)
				local blood = pump and pump:FindFirstChild("BloodFuel")
				if blood then
					blood:Destroy()
				end
				local liquid = pump and pump:FindFirstChild("FuelLiquid")
				if liquid and liquid ~= fuelLiquid then
					unveil(liquid)
				end
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
	-- 11. ศพไฟคลอกมาซื้อน้ำมัน: มองปกติเห็นชาวบ้าน พอพนมมือเห็นร่างจริงเป็นศพไหม้เกรียมมีควันดำคุกรุ่น
	Anomaly_BurnedCorpse = {
		apply = function(v)
			if humanGhost(v, "burned") then
				return
			end
			local d = driverOf(v)
			if not d then
				return
			end
			local charred = apparition(d, "BurnedCorpseDouble") :: Model
			for _, p in ipairs(charred:GetDescendants()) do
				if p:IsA("BasePart") then
					p.Color = Color3.fromRGB(45, 22, 18)
					p.Material = Enum.Material.Slate
				end
			end
			charred.Parent = v
			ghostOnly(charred)
			normalOnly(d)
		end,
	},
	-- 12. ผีเด็กขี่คอ: มองปกติเห็นลูกค้ามาคนเดียว พอพนมมือเห็นผีเด็ก (ghost_child) นั่งขี่คอเกาะหัวลูกค้าจ้องลงมา
	Anomaly_ShoulderChild = {
		apply = function(v)
			local d = driverOf(v)
			if not (d and GhostNPC.Has("ghost_child")) then
				return
			end
			-- ถอดหมวกงอบ (Hat_ngob) ออกเพื่อไม่ให้ปีกงอบกว้างๆ ตัดทะลุคอ/ลำตัวของผีเด็กที่นั่งขี่คอ (ทรงผมจริง Hair_* ยังอยู่ครบ)
			for _, ch in ipairs(d:GetChildren()) do
				if ch:IsA("BasePart") and (string.sub(ch.Name, 1, 4) == "Hat_" or string.find(string.lower(ch.Name), "ngob")) then
					ch:Destroy()
				end
			end
			local neckPos: Vector3? = nil
			local headPos: Vector3? = nil
			for _, x in ipairs(d:GetDescendants()) do
				if x:IsA("Bone") then
					if x.Name == "neck" then
						neckPos = x.WorldPosition
					elseif x.Name == "head" then
						headPos = x.WorldPosition
					end
				end
			end
			local headPart = d:FindFirstChild("Head") :: BasePart?
			local basePos = neckPos or headPos or (headPart and headPart.Position)
			if not basePos then
				return
			end
			local rot = v:GetPivot().Rotation
			-- ผิวไหล่บน (BodyUpper top) อยู่สูงกว่ากระดูก neck +0.30 และหลังหัว (BodyHead back) อยู่ที่ +0.35
			--   วางสะโพกที่ (0, +0.32, +0.34) เทียบ neck เพื่อให้ต้นขาพาดบนบ่าพอดี ตัวไม่จมเข้าหัว และมือวางบนกระหม่อมหัวลูกค้า
			local seatClip = d:GetAttribute("SeatClip")
			local off = if seatClip == "ride_moto" then Vector3.new(0, 0.22, 0.08) else Vector3.new(0, 0.32, 0.34)
			local hip = (CFrame.new(basePos) * rot) * CFrame.new(off)
			local m = GhostNPC.SpawnSeated("ghost_child", hip, "shoulder_ride")
			if m then
				m.Name = "GhostPassengerModel"
				m:SetAttribute("FocusBone", "head")
				m:SetAttribute("ShoulderRider", true)
				m.Parent = v
				ghostOnly(m)
			end
		end,
	},
	-- 13. ศพห่อผ้าท้ายกระบะ (ผู้ใช้ 2026-11-16): มองปกติท้ายกระบะว่าง พอพนมมือเห็นศพห่อผ้าขาวมัดตราสัง (ghost_shroud) ยืนอยู่ในคอกท้ายกระบะ
	--   หัวหันตามคนที่มอง (client/GhostAnimRunner.lookAtCamera) · คนขับเป็นคนปกติ ต้องเดินอ้อมไปดูท้ายรถเอง · เกิดกับกระบะเท่านั้น (PICKUP_ONLY)
	Anomaly_ShroudPickup = {
		apply = function(v)
			if not GhostNPC.Has("ghost_shroud") then
				return
			end
			-- พื้นกระบะของ ThaiPickupOld (PickupVersion 2) สูง 3.7 เหนือ pivot ยาว z 1.8..10 (หน้ารถ = -Z) วัดใน Studio 2026-11-16
			-- ยืนกลางกระบะค่อนไปท้าย หันหน้าออกท้ายรถ (หัวหันซ้ายขวาได้ 80° จึงมองตามได้ทั้งสองข้างรถ)
			local cf = v:GetPivot() * CFrame.new(0, 3.7, 6.4) * CFrame.Angles(0, math.pi, 0)
			local m = GhostNPC.Spawn("ghost_shroud", cf, "shroud_idle")
			if m then
				m.Name = "GhostPassengerModel"
				m:SetAttribute("FocusBone", "head")
				m:SetAttribute("LookAtCamera", true)
				m.Parent = v
				ghostOnly(m)
			end
		end,
	},
	-- 14. ผีเท้ากลับหลัง (ผู้ใช้ 2026-11-16): มองปกติเป็นชาวบ้านเดินมา พอพนมมือเห็นเท้าสองข้างบิดชี้ไปข้างหลัง (ร่างซ้อน HumanNPC.MakeDouble "backfeet")
	--   ที่เหลือเหมือนคนเดิมทุกอย่าง ต้องก้มมองเท้า · เกิดกับคนเดิน/คนเข็นจักรยานเท่านั้น (WALKER_ONLY: คนบนรถมองไม่เห็นเท้า)
	Anomaly_BackFeet = {
		apply = function(v)
			humanGhost(v, "backfeet")
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
				d.Color = Color3.fromRGB(26, 22, 20)
				d.Material = Enum.Material.SmoothPlastic
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

-- ผีที่ใช้ได้เฉพาะกับรถ (ต้องมีคนซ้อน / ป้ายทะเบียน / ล้อ)
local VEHICLE_ONLY = {
	Anomaly_Headless = true,
	Anomaly_Cemetery = true,
	Anomaly_TaKhon = true,
	Anomaly_MirrorGhost = true,
}
-- ผีเด็กขี่คอ: ไม่สุ่มกับรถยนต์มีหลังคา (หัวเด็กจะทะลุหลังคาเก๋ง/กระบะ) ใช้กับมอไซค์และคนเดินเท้า/จักรยาน
local NOT_CAR = { Anomaly_ShoulderChild = true }

-- ลูกค้าแบบไหนที่ผีตัวนี้เกิดได้ (ใช้ตอน admin เรียกผีเฉพาะตัว): "vehicle" | "walker"
function AnomalyManager.KindFor(key: string): string
	if key == "Anomaly_GhostWalkIn" then
		return "walker"
	end
	return "vehicle"
end

-- ศพห่อผ้าท้ายกระบะ: ต้องมีกระบะท้ายเปิด (ThaiPickupOld) เท่านั้น
local PICKUP_ONLY = { Anomaly_ShroudPickup = true }
-- ผีเท้ากลับหลัง: เท้าต้องมองเห็น = คนเดินเท้า / คนเข็นจักรยาน
local WALKER_ONLY = { Anomaly_BackFeet = true }

-- ผีตัวนี้เกิดกับลูกค้าแบบนี้ได้ไหม
--   kind = "vehicle" มอไซค์/ซาเล้ง | "walker" คนเดิน/เข็นจักรยาน | "car" เก๋ง/ตุ๊กตุ๊ก | "pickup" กระบะ (นับเป็นรถยนต์ด้วย)
-- ใช้ทั้งตอนสุ่มผีในเกมจริง (RandomFor) และตอน admin เรียกผีเฉพาะตัว (CoreLoop.devSpawn "ghost")
function AnomalyManager.Fits(key: string, kind: string): boolean
	if PICKUP_ONLY[key] and kind ~= "pickup" then
		return false
	end
	if WALKER_ONLY[key] and kind ~= "walker" then
		return false
	end
	if VEHICLE_ONLY[key] and kind ~= "vehicle" then
		return false
	end
	if NOT_CAR[key] and (kind == "car" or kind == "pickup") then
		return false
	end
	return true
end

-- สุ่มผีที่เข้ากับลูกค้าแบบนี้ (kind = "vehicle" | "walker" | "car" | "pickup")
-- (ผู้ใช้ 2026-11-16: 1 คืนไม่อยากให้เจอผีลูกค้าซ้ำ) เดิมสุ่มแบบไม่จำ: คืนที่มีผี 4 ตัวซ้ำกันราวครึ่งหนึ่ง และผีที่มากับลูกค้าได้ทุกแบบ
-- (คอหัก วิทยุสวดศพ น้ำมันเลือด ศพไฟคลอก) ออกรวมกัน 2 ใน 3 ส่วนผีเฉพาะทางแทบไม่ออก
--   1) usedTonight: ผีที่ออกไปแล้วในคืนนี้ไม่ออกซ้ำ จนกว่าผีที่เข้ากับลูกค้าแบบนั้นจะออกครบทุกตัว (แล้วเริ่มรอบใหม่) · ล้างตอนเริ่มคืน (NewNight)
--   2) น้ำหนัก: ผีเฉพาะทางได้น้ำหนักมากกว่าเมื่อลูกค้าแบบของมันมา (กระบะมา = ส่วนใหญ่เป็นศพห่อผ้าท้ายกระบะ) ผีทั่วไป = 1
local usedTonight: { [string]: boolean } = {}
local function weightOf(key: string): number
	if PICKUP_ONLY[key] then
		return 4
	elseif WALKER_ONLY[key] or VEHICLE_ONLY[key] then
		return 2
	elseif NOT_CAR[key] then
		return 1.5
	end
	return 1
end

-- เริ่มคืนใหม่: ลืมว่าผีตัวไหนออกไปแล้ว (CoreLoop.resetGame)
function AnomalyManager.NewNight()
	table.clear(usedTonight)
end

-- ผีตัวนี้ออกไปแล้วในคืนนี้ (สุ่มได้ / admin บังคับ / สวดเรียกมา)
function AnomalyManager.MarkUsed(key: string)
	usedTonight[key] = true
end

function AnomalyManager.RandomFor(kind: string, _raining: boolean?): string
	local pool, fresh = {}, {}
	for _, k in ipairs(AnomalyManager.Keys) do
		-- ผีเดินมาทั้งร่าง: CoreLoop สุ่มแยกเอง (WalkInChance)
		if k ~= "Anomaly_GhostWalkIn" and AnomalyManager.Fits(k, kind) then
			table.insert(pool, k)
			if not usedTonight[k] then
				table.insert(fresh, k)
			end
		end
	end
	if #fresh == 0 then
		-- ผีที่เข้ากับลูกค้าแบบนี้ออกครบแล้ว: เริ่มรอบใหม่เฉพาะกลุ่มนี้
		for _, k in ipairs(pool) do
			usedTonight[k] = nil
		end
		fresh = pool
	end
	local total = 0
	for _, k in ipairs(fresh) do
		total += weightOf(k)
	end
	local r = math.random() * total
	local chosen = fresh[#fresh]
	for _, k in ipairs(fresh) do
		r -= weightOf(k)
		if r <= 0 then
			chosen = k
			break
		end
	end
	usedTonight[chosen] = true
	return chosen
end

-- ผีที่เดินมาซื้อทั้งร่าง (ไม่แปลงร่าง): ท่าเดิน / ท่ายืนของแต่ละตัว
--   float = ลอยมา (ลอยสูงจากพื้นกี่ studs): ไม่เดินตรงดิ่ง ลอยโค้งอ้อมมา ส่ายซ้ายขวา ขึ้นลง (AnomalyManager.FloatTo)
local WALK_IN = {
	{ name = "Pop", walk = "TwitchWalk", idle = "LickLips" },
	{ name = "ghost_child", walk = "ghost_glide", idle = "ghost_idle", float = 0.3 },
	{ name = "ghost_shroud", walk = "shroud_glide", idle = "shroud_idle", float = 0.5 },
	{ name = "ghost_funeral_woman", walk = "ghost_glide", idle = "ghost_glide", float = 0.4 },
	{ name = "ghost_kuman_thong", walk = "kuman_run", idle = "kuman_giggle" },
	-- ตานี: เดิมเดินด้วยท่ายืน (ghost_idle) ตัวไถลมาเฉยๆ ดูแปลก (ผู้ใช้ 2026-11-13) -> ลอยร่อนมาแบบผีหญิงงานศพ ยืนท่าแอบมอง
	{ name = "ghost_tani", walk = "ghost_glide", idle = "tani_peek", float = 0.35 },
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
	if w.float then
		m:SetAttribute("FloatLift", w.float)
	end
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

-- ผีลอยที่เดินมาซื้อทั้งร่าง (FloatLift): ลอยไปจุดหมายแบบผี แทน Pedestrian.WalkTo ที่เดินเส้นตรง
-- (ผู้ใช้ 2026-11-06) ไม่ตรงดิ่งมาที่ร้าน: ลอยเป็นเส้นโค้งอ้อมออกห่างตัวร้าน + ส่ายซ้ายขวา ขึ้นลง เอียงตัว พุ่งเป็นพักๆ (shared/GhostFloat)
-- คืน false = ตัวนี้ไม่ใช่ผีลอย (ให้ผู้เรียกใช้ Pedestrian.WalkTo ตามเดิม) · ถึงที่แล้ววางตัวลอยนิ่งที่จุดหมายพอดี
function AnomalyManager.FloatTo(m: Model, target: Vector3, speed: number): boolean
	local lift = m:GetAttribute("FloatLift")
	if type(lift) ~= "number" then
		return false
	end
	-- ลอยด้วย Server ทุกเฟรม: เครื่องผู้เล่นเกลี่ยให้ลื่น (shared/NetSmooth)
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetSmooth")).Track(m)
	local p0 = m:GetPivot().Position
	local a = Vector3.new(p0.X, 0, p0.Z)
	local b = Vector3.new(target.X, 0, target.Z)
	local dist = (b - a).Magnitude
	if dist < 0.3 then
		return true
	end
	local fwd = (b - a).Unit
	local perp = Vector3.new(-fwd.Z, 0, fwd.X)
	-- โค้งออกด้านที่ห่างจากตัวร้าน (อ้อมร้าน ไม่พุ่งตรงเข้าหา) ระยะสั้นโค้งน้อย ระยะไกลโค้งกว้าง
	local mid = (a + b) / 2
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	local sc = if shack then shack:GetPivot().Position else Vector3.new(0, 0, 8)
	local away = Vector3.new(mid.X - sc.X, 0, mid.Z - sc.Z)
	local sign = if math.abs(away:Dot(perp)) < 0.5 then (if math.random() < 0.5 then -1 else 1) elseif away:Dot(perp) > 0 then 1 else -1
	local ctrl = mid + perp * sign * math.clamp(dist * 0.45, 1.5, 18)
	local function at(s: number): Vector3
		local u = 1 - s
		return a * (u * u) + ctrl * (2 * u * s) + b * (s * s)
	end
	local len = 0
	local prev = a
	for i = 1, 16 do
		local p = at(i / 16)
		len += (p - prev).Magnitude
		prev = p
	end
	local fury = GhostFloat.Fury()
	local spd = speed * (0.85 + fury * 0.55)
	local seed = math.random() * 100
	local t0 = os.clock()
	local s = 0
	local function place(k: number, w: number)
		local p = at(k)
		local ahead = at(math.min(1, k + 0.02)) - p
		local look = if ahead.Magnitude > 0.01 then ahead.Unit else fwd
		local off, rot = GhostFloat.Offset(seed, os.clock() - t0, look, fury)
		-- ส่ายเต็มที่กลางทาง ค่อยๆ หยุดส่ายตอนใกล้ถึง (หยุดตรงจุดคิว/ตู้พอดี)
		local ground = groundAt(p)
		local y = ground + lift * math.min(1, (os.clock() - t0) / 0.6)
		local pos = Vector3.new(p.X, y, p.Z) + off * w
		-- ลอยลงต่ำสุดได้แค่เฉียดพื้น (เท้าไม่จมดิน) ส่วนที่เกินดันกลับขึ้นไปลอยสูงแทน
		if pos.Y < ground + 0.05 then
			pos = Vector3.new(pos.X, ground + 0.05 + (ground + 0.05 - pos.Y) * 0.5, pos.Z)
		end
		m:PivotTo(CFrame.lookAt(pos, pos + look) * CFrame.new():Lerp(rot, w))
	end
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent then
			done = true
			conn:Disconnect()
			return
		end
		s = math.min(1, s + spd * GhostFloat.Surge(seed, os.clock() - t0, fury) * dt / math.max(len, 0.1))
		place(s, math.clamp(math.min(s, 1 - s) * 6, 0, 1))
		if s >= 1 then
			done = true
			conn:Disconnect()
		end
	end)
	while not done do
		task.wait()
	end
	return true
end

-- เดิน / หยุด (เฉพาะผีที่เดินมาทั้งร่าง: ตัวอื่นไม่ทำอะไร)
function AnomalyManager.WalkInMoving(m: Model, moving: boolean)
	local clip = m:GetAttribute(if moving then "WalkClip" else "IdleClip")
	if type(clip) == "string" then
		GhostNPC.Play(m, clip)
	end
end

-- ตัดตาเรืองแสงของหุ่นไล่กาออกทั้งหมด (ผู้ใช้ 2026-11-18: ตาเป็นสีดำด้านปกติ ไม่เรืองแสง)
if scarecrow then
	for _, d in ipairs(scarecrow:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "Eye") then
			d.Color = Color3.fromRGB(26, 22, 20)
			d.Material = Enum.Material.SmoothPlastic
			d:SetAttribute("BaseColor", d.Color)
		elseif d:IsA("Light") then
			d.Enabled = false
		end
	end
end

-- ตัดออกจากการสุ่ม (ยังเรียกทดสอบผ่าน ForceAnomaly ได้):
--   Anomaly_GhostWalkIn: ผีเดินมาซื้อทั้งร่าง เห็นได้โดยไม่ต้องพนมมือ ไม่ได้ทดสอบอะไร ผู้ใช้สั่งตัด 2026-11-16
--     (CoreLoop.CONFIG.WalkInChance = 0 · ForceAnomaly "Anomaly_GhostWalkIn" ยังสร้างร่างผีเดินมาได้)
--   Anomaly_NoUmbrella: ตัดระบบฝนตกออกแล้ว 2026-11-16
local RETIRED = { Anomaly_GhostWalkIn = true, Anomaly_NoUmbrella = true }

AnomalyManager.Keys = {}
for k in pairs(AnomalyManager.Anomalies) do
	if not RETIRED[k] then
		table.insert(AnomalyManager.Keys, k)
	end
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

-- ผีที่ตัวลูกค้าเองไม่แปลงร่าง (ผิดปกติที่ป้าย/ล้อ/น้ำมัน/วิทยุ/ร่ม): ลูกค้าคือผี พนมมือแล้วต้องเห็นร่างผีของตัวลูกค้าด้วย
-- และตอนหลอกใช้ร่างผีนี้ ไม่ใช่ร่างคน (ผู้ใช้ 2026-11-06) ผีที่มีร่างของตัวเองอยู่แล้ว (กระสือ ตาโขน หันหัว ยิ้ม) ไม่ต้องใส่
-- ผีซ้อนท้าย (หัวขาด / มองกระจก): ตัวผีคือคนซ้อน คนขับเป็นคนปกติ
-- (ป้ายป่าช้า / วิทยุสวดศพ: เอาออกแล้ว คนขับเป็นคนปกติ จับผิดจากป้าย/วิทยุอย่างเดียว ผู้ใช้ 2026-11-07)
local CUSTOMER_GHOST_FORM: { [string]: boolean } = {}

function AnomalyManager.Apply(key: string, vehicle: Model): boolean
	local a = AnomalyManager.Anomalies[key]
	if not a then
		warn("[AnomalyManager] ไม่รู้จักผี " .. tostring(key))
		return false
	end
	usedTonight[key] = true -- รวมผีที่ admin บังคับและผีที่สวดเรียกมา: คืนนี้ไม่สุ่มซ้ำ
	a.apply(vehicle)
	if vehicle and CUSTOMER_GHOST_FORM[key] then
		local d = driverOf(vehicle)
		if d and not d:FindFirstChild("GhostDouble") then
			humanGhost(vehicle, "ghost")
		end
	end
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
	--    (weight 3 -> 1 ผู้ใช้ 2026-11-08: หมาหอนเป็นลางก่อนผีใหญ่มา AnomalyManager.Omen สุ่มเองบ่อยไปลางจะไม่มีความหมาย)
	{ name = "DogHowl", id = "rbxassetid://93714483057730", weight = 1, volume = 0.42, hill = true, minDist = 90, maxDist = 480, highGain = -14, speed = 1, fromStart = true },
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
	-- (ตัดฟ้าร้องและระบบฝนตกออกแล้ว 2026-11-16)
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

	-- ลางก่อนผีใหญ่มา (CoreLoop.Big.run): หมาหอนแว่วจากหลังเขา (เสียงเดียวกับที่สุ่ม แต่ตั้งใจเล่นตรงจังหวะ)
	AnomalyManager.Omen = function()
		playAmbient(AMBIENT[1])
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
	-- สุ่มหมุนเปลี่ยนคลื่นวิทยุลูกทุ่งเหงาๆ อัตโนมัติทุกๆ 70 - 130 วินาที (เฉพาะตอนที่ผู้เล่นเปิดวิทยุไว้ และไม่ได้เป็นเสียงสวดศพ)
	task.spawn(function()
		while true do
			task.wait(math.random(70, 130))
			if radioUserOn and not radioOmenOn and radioChant and not radioChant.IsPlaying then
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
