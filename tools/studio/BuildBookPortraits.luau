-- BuildBookPortraits.luau — ModuleScript (Rojo: ServerStorage.BuildBookPortraits ของ place เกม) รันใน Studio Edit mode
-- สร้าง ServerStorage.BookPortraits: ฉากนิ่ง 1 ฉากต่อ 1 หน้าในสมุดผี (ชื่อ = key ใน LanguageModule.BookOrder)
--   ผี/คน: โคลนจากแม่แบบแล้ว "อบท่า" จาก KeyframeSequence (Bone.CFrame = rest * pose ของ keyframe ที่เลือก)
--          แขนที่ยังกางแนวนอน (ท่าบางชุดขยับแขนนิดเดียว) ถูกปล่อยลงข้างตัว ไม่ให้เห็นท่า T
--   ผีที่มากับของ: จัดฉากแบบในเกม (ซ้อนท้ายมอไซค์ / นั่งแทนคนขับ / แบกโลง ฯลฯ) ตำแหน่งตามสูตรใน
--          AnomalyManager / CoreLoop.humanizeDriver / BigEvents
--   ทุกชิ้น Anchored ไม่มีสคริปต์/เสียง/Humanoid, WorldPivot = กลางกล่อง หันตามทิศฉาก, attribute "BookYaw" = มุมกล้อง
-- เสร็จแล้ว: copy โฟลเดอร์ ServerStorage.BookPortraits ไปวางที่ ReplicatedStorage ของ place Lobby

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")

local GHOSTS = SS.GhostTemplates
local HUMANS = SS.HumanTemplates
local BIKE = SS.VehicleTemplates.CustomerBike

-- ลำดับเดียวกับ LanguageModule.BookOrder
local ORDER = {
	"Anomaly_Headless", "Anomaly_Cemetery", "Anomaly_WheelHair", "Anomaly_NeckTwist", "Anomaly_CreepySmile",
	"Anomaly_Krasue", "Anomaly_TaKhon", "Anomaly_MirrorGhost", "Anomaly_GhostWalkIn", "Outage_Shrouds",
	"Big_Krasue", "Big_Pret", "Big_Funeral", "Big_Pop", "Anomaly_MonkRadio", "Anomaly_BloodFuel", "Anomaly_NoUmbrella",
}

-- ---------------------------------------------------------------- ท่า
local function clipOf(kind: string, model: string, clip: string): KeyframeSequence?
	local root = if kind == "Human" then SS:FindFirstChild("HumanAnims") else SS:FindFirstChild("GhostAnims")
	local folder = root and root:FindFirstChild(model)
	local k = folder and (folder:FindFirstChild(clip) or folder:FindFirstChild(model .. "_" .. clip))
	return if k and k:IsA("KeyframeSequence") then k else nil
end

local function bone(m: Instance, name: string): Bone?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then
			return d
		end
	end
	return nil
end

-- แขนกางเกือบแนวนอน -> หมุนลงให้ทำมุม ~68° ใต้แนวนอน (ข้างลำตัว)
local function relaxArms(m: Model, facing: CFrame)
	for _, side in ipairs({ "L", "R" }) do
		local upper = bone(m, "upper_arm." .. side)
		local fore = bone(m, "forearm." .. side)
		if upper and fore then
			local dir = fore.WorldPosition - upper.WorldPosition
			if dir.Magnitude > 0.05 then
				local up = facing.UpVector
				local drop = -dir.Unit:Dot(up) -- sin(มุมใต้แนวนอน)
				if drop < 0.45 then
					local flat = dir - up * dir:Dot(up)
					local out = if flat.Magnitude > 0.01 then flat.Unit else facing.RightVector
					local target = (out * math.cos(math.rad(68)) - up * math.sin(math.rad(68))).Unit
					local r = CFrame.fromRotationBetweenVectors(dir.Unit, target)
					local w = upper.WorldCFrame
					upper.WorldCFrame = CFrame.new(w.Position) * r * w.Rotation
				end
			end
		end
	end
end

local function bakePose(m: Model, kfs: KeyframeSequence?, frac: number)
	if not kfs then
		return
	end
	local list = kfs:GetKeyframes()
	table.sort(list, function(a, b)
		return (a :: Keyframe).Time < (b :: Keyframe).Time
	end)
	local kf = list[math.clamp(math.floor(#list * frac) + 1, 1, #list)] :: Keyframe
	local poses = {}
	for _, p in ipairs(kf:GetDescendants()) do
		if p:IsA("Pose") and p.Weight > 0 then
			poses[p.Name] = p.CFrame
		end
	end
	for _, b in ipairs(m:GetDescendants()) do
		if b:IsA("Bone") and poses[b.Name] then
			b.CFrame = b.CFrame * poses[b.Name]
		end
	end
end

-- ---------------------------------------------------------------- ตัวละคร
-- แม่แบบคนมีทุกชุด/ทรงผมซ้อนกัน: กฎเดียวกับ HumanNPC (เก็บ Cloth_<ชุด>* + Hair_<ผม>, ลบ Skin_ ที่ชุดปิด)
local skinMap = (function()
	local ok, t = pcall(function()
		return require(RS.Shared.HumanSkinParts:Clone())
	end)
	return if ok then t else {}
end)()
local function dress(m: Model, template: string, outfit: string, hair: string)
	local covers = skinMap[template] or {}
	for _, c in ipairs(m:GetChildren()) do
		local n = c.Name
		local drop = false
		if string.sub(n, 1, 5) == "Skin_" then
			drop = covers[n] ~= nil and table.find(covers[n], outfit) ~= nil
		elseif string.sub(n, 1, 6) == "Cloth_" then
			drop = not (n == "Cloth_" .. outfit or string.sub(n, 1, #outfit + 7) == "Cloth_" .. outfit .. "_")
		elseif string.sub(n, 1, 5) == "Hair_" then
			drop = n ~= "Hair_" .. hair
		end
		if drop then
			c:Destroy()
		end
	end
end

-- ผิวซีดเขียวแบบร่างผีซ้อน "pale" (HumanNPC.MakeDouble)
local function pale(m: Model)
	for _, c in ipairs(m:GetChildren()) do
		if string.sub(c.Name, 1, 4) == "Body" or string.sub(c.Name, 1, 5) == "Skin_" then
			local sa = c:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				pcall(function()
					(sa :: any).Color = Color3.fromRGB(176, 196, 184)
				end)
			end
		end
	end
end

-- ตัวละครพร้อมท่า: spec = { ghost = "Pop" } หรือ { human = "human_base", outfit, hair }, clip, frac
local function figure(spec: { [string]: any }): (Model, Vector3)
	local m: Model
	local kfs: KeyframeSequence?
	if spec.ghost then
		m = GHOSTS[spec.ghost]:Clone()
		kfs = clipOf("Ghost", spec.ghost, spec.clip)
	else
		m = HUMANS[spec.human]:Clone()
		dress(m, spec.human, spec.outfit, spec.hair)
		kfs = clipOf("Human", spec.human, spec.clip)
	end
	-- ระยะสะโพกจาก pivot (ท่าพัก) แบบ GhostNPC.hipsOffset ใช้วางนั่ง
	local hb = bone(m, "hips")
	local hipOff = if hb then m:GetPivot():PointToObjectSpace(hb.WorldPosition) else Vector3.new(0, 3.1, 0)
	bakePose(m, kfs, spec.frac or 0.3)
	if spec.twist then
		local h = bone(m, "head")
		if h then
			local w = h.WorldCFrame
			h.WorldCFrame = CFrame.new(w.Position) * CFrame.fromAxisAngle(m:GetPivot().UpVector, math.pi) * w.Rotation
		end
	end
	if spec.pale then
		pale(m)
	end
	if not spec.keepArms then
		relaxArms(m, m:GetPivot())
	end
	return m, hipOff
end

-- ---------------------------------------------------------------- มอไซค์ลูกค้า
local function bike(withHair: boolean?): (Model, CFrame, CFrame, CFrame)
	local b = BIKE:Clone()
	local piv = b:GetPivot()
	local rot = piv.Rotation
	local drv = b:FindFirstChild("DriverNPC")
	local pas = b:FindFirstChild("GhostPassenger")
	local dt = drv and drv:FindFirstChild("Torso") :: BasePart?
	local pt = pas and pas:FindFirstChild("Torso") :: BasePart?
	local dh = drv and drv:FindFirstChild("Head") :: BasePart?
	-- สะโพกคนขับ: ขอบล่าง Torso คนขับเดิม + ปรับแบบ CoreLoop.humanizeDriver (ride_moto)
	local driverHip = if dt then CFrame.new((dt.CFrame * CFrame.new(0, -dt.Size.Y / 2, 0)).Position) * rot * CFrame.new(0, 0.12, 0.15) else piv
	-- สะโพกคนซ้อน: แบบ Anomaly_Headless / Anomaly_MirrorGhost
	local pillionHip = if pt then CFrame.new(pt.CFrame:PointToWorldSpace(Vector3.new(0, -1.05, 0))) * rot else piv
	local headAt = if dh then CFrame.new(dh.Position) * rot else piv
	for _, n in ipairs({ "DriverNPC", "GhostPassenger" }) do
		local x = b:FindFirstChild(n)
		if x then
			x:Destroy()
		end
	end
	local hair = b:FindFirstChild("WheelHairAnomaly")
	if hair and not withHair then
		hair:Destroy()
	elseif hair then
		for _, d in ipairs(hair:GetDescendants()) do
			-- แม่แบบซ่อนผมไว้ ค่าตอนโชว์อยู่ใน attribute ShowTransparency (AnomalyManager.ghostOnly)
			local show = d:GetAttribute("ShowTransparency")
			if d:IsA("BasePart") and type(show) == "number" then
				d.Transparency = show
			end
		end
	end
	return b, driverHip, pillionHip, headAt
end

-- วางให้สะโพกอยู่ที่ hip (แบบ GhostNPC.SpawnSeated)
local function rider(b: Model, hip: CFrame, spec: { [string]: any })
	local m, off = figure(spec)
	m:PivotTo(hip * CFrame.new(-off))
	m.Parent = b
end

local DRIVER = { human = "human_base", outfit = "wan_flannel", hair = "student", clip = "ride_moto", frac = 0.3, keepArms = true }
local function with(extra: { [string]: any }): { [string]: any }
	local t = table.clone(DRIVER)
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end

-- ---------------------------------------------------------------- ฉากแต่ละหน้า: คืน (โมเดล, ทิศฉาก, มุมกล้อง)
local SCENES: { [string]: () -> (Model, CFrame, number) } = {
	Anomaly_Headless = function()
		local b, dHip, pHip = bike()
		rider(b, dHip, DRIVER)
		rider(b, pHip, { ghost = "ghost_headless", clip = "pillion_hug", frac = 0.3, keepArms = true })
		return b, b:GetPivot(), -72 -- มุมข้าง: คนขับไม่บังคนซ้อน
	end,
	Anomaly_Cemetery = function()
		local b, dHip = bike()
		rider(b, dHip, with({ outfit = "farmer", hair = "rong_song_sung" }))
		return b, b:GetPivot(), 160
	end,
	Anomaly_WheelHair = function()
		local b, dHip = bike(true)
		rider(b, dHip, with({ outfit = "wan_baggy", hair = "student" }))
		return b, b:GetPivot(), 70
	end,
	Anomaly_NeckTwist = function()
		local b, dHip = bike()
		rider(b, dHip, with({ outfit = "red_shirt", hair = "side_part", twist = true }))
		return b, b:GetPivot(), -30
	end,
	Anomaly_CreepySmile = function()
		local b, dHip = bike()
		rider(b, dHip, with({ outfit = "mohom", hair = "rong_song_sung", pale = true }))
		return b, b:GetPivot(), -25
	end,
	Anomaly_Krasue = function()
		-- กระสือลอยแทนที่หัวคนขับ (AnomalyManager.Anomaly_Krasue)
		local b, _, _, headAt = bike()
		local m = figure({ ghost = "Krasue", clip = "Float", frac = 0.3 })
		m:PivotTo(headAt * CFrame.new(0, 0.3, 0))
		m.Parent = b
		return b, b:GetPivot(), -30
	end,
	Anomaly_TaKhon = function()
		local b, dHip = bike()
		rider(b, dHip, { ghost = "ghost_ta_khon", clip = "mask_tilt", frac = 0.5, keepArms = true })
		return b, b:GetPivot(), -30
	end,
	Anomaly_MirrorGhost = function()
		local b, dHip, pHip = bike()
		rider(b, dHip, with({ outfit = "wan_denim", hair = "side_part" }))
		rider(b, pHip, { ghost = "ghost_mirror", clip = "pillion_look", frac = 0.6, keepArms = true })
		return b, b:GetPivot(), -72
	end,
	Anomaly_GhostWalkIn = function()
		local m = figure({ ghost = "ghost_child", clip = "ghost_idle", frac = 0.3 })
		return m, m:GetPivot(), 15
	end,
	Outage_Shrouds = function()
		-- ศพห่อผ้ายืนเรียงในทุ่ง 3 ร่าง ลึกเข้าไปเรื่อยๆ
		local g = Instance.new("Model")
		local rot = GHOSTS.ghost_shroud:GetPivot().Rotation
		for i, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(-5, 0, 5), Vector3.new(5, 0, 9) }) do
			local m = figure({ ghost = "ghost_shroud", clip = "shroud_idle", frac = 0.2 + i * 0.15 })
			m:PivotTo(rot * CFrame.new(off))
			m.Parent = g
		end
		return g, rot, 10
	end,
	Big_Krasue = function()
		local m = figure({ ghost = "Krasue", clip = "Sniff", frac = 0.5 })
		return m, m:GetPivot(), 20
	end,
	Big_Pret = function()
		local m = figure({ ghost = "Pret", clip = "Idle", frac = 0.3 })
		return m, m:GetPivot(), 15
	end,
	Big_Funeral = function()
		-- คนแบกหน้า-หลัง (คานซ้าย) + โลงห้อยจากกำปั้นขวาคนหน้า (BigEvents.carry)
		local GAP = 7
		local g = Instance.new("Model")
		local front = figure({ ghost = "ghost_funeral_man", clip = "coffin_walk", frac = 0.3, keepArms = true })
		local rot = front:GetPivot().Rotation
		front:PivotTo(rot)
		front.Parent = g
		local back = figure({ ghost = "ghost_funeral_elder_man", clip = "coffin_walk", frac = 0.3, keepArms = true })
		back:PivotTo(rot * CFrame.new(0, 0, GAP))
		back.Parent = g
		local props = SS:FindFirstChild("GhostProps")
		local hand = bone(front, "hand.R")
		if props and props:FindFirstChild("Coffin") and hand then
			local c = props.Coffin:Clone()
			c:PivotTo(CFrame.new(hand.WorldPosition + Vector3.new(0, 0.1, 0)) * rot * CFrame.new(0, 0, GAP / 2))
			c.Parent = g
		end
		return g, rot, -55
	end,
	Big_Pop = function()
		-- เมชปอบไม่ขยับตามกระดูกใน ViewportFrame (แขนกางท่า T เสมอ): ใช้ภาพครึ่งตัวเน้นหน้า แขนหลุดกรอบ
		local m = figure({ ghost = "Pop", clip = "PossessedSnap", frac = 0.5 })
		m:SetAttribute("BookFocusY", 0.84)
		m:SetAttribute("BookFit", 0.34)
		return m, m:GetPivot(), 12
	end,
	Anomaly_MonkRadio = function()
		local m = SS.ToolboxRadioTemplates.RadioTemplate_1:Clone()
		return m, m:GetPivot(), 90
	end,
	Anomaly_BloodFuel = function()
		local m = workspace.MapEnvironment.ShackDressing.FuelBottleRack:Clone()
		return m, m:GetPivot(), 0
	end,
	Anomaly_NoUmbrella = function()
		local m = figure({ human = "human_elder_male", outfit = "farmer", hair = "long_white_beard", clip = "idle", frac = 0.3 })
		return m, m:GetPivot(), 0
	end,
}

local function finish(model: Model, facing: CFrame, yaw: number)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("AnimationController")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local rot = facing.Rotation
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position) * rot
	model:PivotTo(rot)
	model:SetAttribute("BookYaw", yaw)
end

-- ใช้งาน: require(game.ServerStorage.BuildBookPortraits:Clone())()  (Clone กัน require แคชผลรอบก่อน)
return function(): string
	local old = SS:FindFirstChild("BookPortraits")
	if old then
		old:Destroy()
	end
	local out = Instance.new("Folder")
	out.Name = "BookPortraits"
	local report = {}
	for _, key in ipairs(ORDER) do
		local ok, m, facing, yaw = pcall(SCENES[key])
		if ok and m then
			m.Name = key
			finish(m, facing, yaw)
			m.Parent = out
			table.insert(report, key .. ": ok")
		else
			table.insert(report, key .. ": " .. tostring(m))
		end
	end
	out.Parent = SS
	return table.concat(report, "\n")
end
