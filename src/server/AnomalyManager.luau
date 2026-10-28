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
local RADIO_VOLUME = { music = 0.35, chant = 0.52, static = 0.38 }
local radioMusic = radioSound("RadioMusic", SOUNDS.RadioMusic, RADIO_VOLUME.music, true)
local radioChant = radioSound("MonkChant", SOUNDS.MonkChant, RADIO_VOLUME.chant, true)
local radioStatic = radioSound("RadioStatic", SOUNDS.RadioStatic, RADIO_VOLUME.static, false)
if radioChant then
	local eq = Instance.new("EqualizerSoundEffect") -- เสียงแตกๆ เหมือนคลื่นวิทยุเพี้ยน แต่ไม่แสบหู
	eq.LowGain = -12
	eq.MidGain = 3
	eq.HighGain = -18
	eq.Parent = radioChant
end
if radioStatic then
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -10
	eq.MidGain = 0
	eq.HighGain = -20 -- ตัดเสียงซ่าแหลมๆ ออกให้ฟังสบายหู
	eq.Parent = radioStatic
end

-- ระบบสลับสถานีวิทยุลูกทุ่งเหงาๆ หลอนๆ 5 คลื่น (สำหรับวิทยุในร้านเท่านั้น)
local currentStationIdx = 0

local function tuneLukThungStation(idx: number?)
	if not radioMusic then
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
	radioMusic.Volume = st.volume
	radioMusic.PlaybackSpeed = st.speed or 1
	SoundBank.ApplyWarmEffects(radioMusic, st)
	if not radioMusic.IsPlaying then
		radioMusic:Play()
	end
end

function AnomalyManager.SetGhostPresent(_isGhost: boolean)
	-- (สถานะผีส่งผ่าน Remotes:SetAttribute("IsAnomaly") ให้ฝั่ง Client ใช้ปรับเสียงสวดมนต์ของตัวผู้เล่นเอง)
end

-- ให้ผู้เล่นเดินไปกดเปลี่ยนคลื่นเพลงลูกทุ่งที่ตัววิทยุในเพิงได้
if radioPart then
	local tunePrompt = radioPart:FindFirstChild("TuneRadioPrompt") :: ProximityPrompt?
	if not tunePrompt then
		tunePrompt = Instance.new("ProximityPrompt")
		tunePrompt.Name = "TuneRadioPrompt"
		tunePrompt.ActionText = "หมุนคลื่นวิทยุลูกทุ่ง / Tune Radio"
		tunePrompt.ObjectText = "วิทยุทรานซิสเตอร์"
		tunePrompt.KeyboardKeyCode = Enum.KeyCode.R
		tunePrompt.HoldDuration = 0.2
		tunePrompt.MaxActivationDistance = 8
		tunePrompt.RequiresLineOfSight = false
		tunePrompt.Parent = radioPart
	end
	tunePrompt.Triggered:Connect(function()
		tuneLukThungStation()
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
	end
	if radioMusic then
		if currentStationIdx == 0 then
			tuneLukThungStation(1)
		elseif not radioMusic.IsPlaying then
			radioMusic:Play()
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
	-- 7. วิทยุในร้านเปลี่ยนจากเพลงเป็นเสียงพระสวดศพ (ใช้เสียงพระสวดวัดของวิทยุ ไม่เอาเสียงพูดของผู้เล่นมาปน)
	Anomaly_MonkRadio = {
		-- คนไม่ได้พนมมือยังได้ยินเพลงวิทยุตามปกติ คนพนมมือได้ยินเสียงสวดศพแทน
		apply = function(_v)
			if radioStatic then
				veil(radioStatic, GHOST_TAG, "Volume", RADIO_VOLUME.static, 0)
				radioStatic:Play()
			end
			if radioMusic then
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
	-- 8. ผีตานียืนอยู่หลังกอกล้วย (ปกติมองไม่เห็น)
	Anomaly_Tani = {
		apply = function(_v)
			if tani then
				for _, d in ipairs(tani:GetDescendants()) do
					if d:IsA("BasePart") then
						veil(d, GHOST_TAG, "Transparency", TANI_SHOWN, TANI_HIDDEN, 3) -- ค่อยๆ ปรากฏ
					end
				end
			end
		end,
		reset = function()
			if tani then
				unveil(tani)
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
			if anomalyProps:FindFirstChild("ScarecrowApparition") then
				return
			end
			local from = scarecrowPivot.Position
			local pump = (gasPump :: Model):GetPivot().Position
			local p = from:Lerp(pump, 0.55)
			p = Vector3.new(p.X, groundAt(p) + (from.Y - groundAt(from)), p.Z)
			-- ร่างผีของหุ่นไล่กา (Clone) ยืนใกล้ร้าน ส่วนตัวจริงกลางทุ่งหายไปตอนพนมมือ
			local ghost = apparition(scarecrow, "ScarecrowApparition") :: Model
			-- หน้าของหุ่นไล่กาอยู่ฝั่ง -LookVector ของ pivot (ลูกตาอยู่ฝั่งนั้น) จึงหมุนกลับ 180° ให้หน้ามองร้าน
			ghost:PivotTo(CFrame.lookAt(p, Vector3.new(pump.X, p.Y, pump.Z)) * CFrame.Angles(0, math.pi, 0))
			for _, d in ipairs(ghost:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Eye") then
					d.Color = Color3.fromRGB(255, 20, 20)
				end
			end
			ghost.Parent = anomalyProps
			ghostOnly(ghost)
			normalOnly(scarecrow)
		end,
		reset = function()
			local ghost = anomalyProps:FindFirstChild("ScarecrowApparition")
			if ghost then
				ghost:Destroy()
			end
			if scarecrow and scarecrowPivot then
				unveil(scarecrow)
				scarecrow:PivotTo(scarecrowPivot)
			end
		end,
	},
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

-- ผีที่ใช้ได้เฉพาะกับรถ (ต้องมีคนซ้อน / ป้ายทะเบียน / ล้อ) หรือเฉพาะคนเดินตอนฝนตก
local VEHICLE_ONLY = { Anomaly_Headless = true, Anomaly_Cemetery = true, Anomaly_WheelHair = true }
local WALKER_RAIN_ONLY = { Anomaly_NoUmbrella = true }

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
		if ok then
			table.insert(pool, k)
		end
	end
	return pool[math.random(#pool)]
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

-- ---------------------------------------------------------------- บรรยากาศทุ่ง: เสียงหลอนแบบสุ่มรอบๆ แมพ
-- เสียงเล่นฝั่ง Server (ทุกคนได้ยินเหมือนกัน เป็นเสียง 3D จากจุดนั้นจริงๆ) ทุก 14-32 วิ สุ่ม 1 เสียงตามน้ำหนัก
--   segment = เล่นแค่ช่วงหนึ่งของไฟล์ยาว (เริ่มสุ่มตำแหน่ง แล้วหยุดเมื่อครบเวลา)
--   near = ดังใกล้ร้าน (เช่น เสียงฝีเท้า เสียงกระซิบ) ไม่ใช่ไกลกลางทุ่ง
local AMBIENT = {
	{ name = "DogHowl", id = "rbxassetid://748228812", weight = 4, volume = 0.7 },
	{ name = "Owl", id = "rbxassetid://9117181875", weight = 3, volume = 0.6 },
	{ name = "Crows", id = "rbxassetid://190872950", weight = 2, volume = 0.5, segment = 6 },
	{ name = "Crying", id = "rbxassetid://75664285683608", weight = 2, volume = 0.45 },
	{ name = "Laugh", id = "rbxassetid://91272160888434", weight = 1, volume = 0.4 },
	{ name = "Bells", id = "rbxassetid://119445319966378", weight = 1, volume = 0.35 },
	{ name = "Whisper", id = "rbxassetid://2643071410", weight = 2, volume = 0.5, segment = 5, near = true },
	{ name = "Footsteps", id = "rbxassetid://135952279207329", weight = 2, volume = 0.6, segment = 3, near = true },
	{ name = "Eerie", id = "rbxassetid://9112775624", weight = 1, volume = 0.6, segment = 10 },
}
local THUNDER_ID = "rbxassetid://9120016037"
local AMBIENT_SCALE = 0.45 -- เสียงพื้นหลังเบาลง ให้ผีหลอกเด่นกว่า
local FAR_SPOTS = {
	Vector3.new(-90, 4, 70),
	Vector3.new(80, 4, -70),
	Vector3.new(60, 4, 90),
	Vector3.new(-80, 4, -60),
	Vector3.new(30, 4, -90), -- กลางทุ่งหลังหุ่นไล่กา
	Vector3.new(-40, 4, 40), -- แถวต้นไทร
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
		snd.RollOffMinDistance = if a.near then 10 else 40
		snd.RollOffMaxDistance = if a.near then 70 else 260
		local warmEq = Instance.new("EqualizerSoundEffect")
		warmEq.Name = "WarmAmbientEQ"
		warmEq.LowGain = 1
		warmEq.MidGain = 0
		warmEq.HighGain = -8 -- ตัดย่านแหลมเบาๆ ไม่ให้เสียงยืดหรืออู้อี้
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

	task.spawn(function()
		while true do
			task.wait(math.random(14, 32))
			local a = pickAmbient()
			local snd = sounds[a.name]
			local list = if a.near then NEAR_SPOTS else FAR_SPOTS
			emitter.Position = list[math.random(#list)]
			snd.PlaybackSpeed = 1.0
			if a.segment and snd.TimeLength > a.segment + 1 then
				snd.TimePosition = math.random() * (snd.TimeLength - a.segment)
			else
				snd.TimePosition = 0
			end
			snd:Play()
			if a.segment then
				local seg = a.segment
				task.delay(seg, function()
					snd:Stop()
				end)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(math.random(18, 40))
			if remotes:GetAttribute("Weather") == "Rain" then
				remotes:SetAttribute("ThunderAt", os.clock()) -- Client: ฟ้าแลบก่อน
				task.wait(0.4 + math.random() * 0.8) -- แล้วเสียงตามมา
				thunder.PlaybackSpeed = 1.0
				thunder:Play()
			end
		end
	end)
	-- สุ่มหมุนเปลี่ยนคลื่นวิทยุลูกทุ่งเหงาๆ อัตโนมัติทุกๆ 70 - 130 วินาที (เฉพาะตอนที่ไม่ได้เป็นเสียงสวดศพ)
	task.spawn(function()
		while true do
			task.wait(math.random(70, 130))
			if radioChant and not radioChant.IsPlaying then
				tuneLukThungStation()
			end
		end
	end)
end

function AnomalyManager.Init()
	AnomalyManager.ResetAnomalies()
	radioNormal()
	AnomalyManager.StartAmbience()
end

return AnomalyManager
