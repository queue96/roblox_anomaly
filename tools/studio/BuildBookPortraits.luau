-- BuildBookPortraits.luau — ModuleScript (Rojo: ServerStorage.BuildBookPortraits ของ place เกม) รันใน Studio Edit mode
-- สร้าง ServerStorage.BookPortraits: ฉากนิ่ง 1 ฉากต่อ 1 หน้าในสมุดผี (ชื่อ = key ใน LanguageModule.BookOrder)
--   v2 (2026-11-24): ใช้โมเดลปัจจุบันของเกม (ชาวบ้าน v2 / ผี v2-v3 / รถ v2) จัดฉากตามสูตรเดียวกับ AnomalyManager / CoreLoop.humanizeDriver
--   ท่า: GhostClipData (mocap ผี), HumanAnimsMocap / HumanAnims, GhostAnims -> อบลง Bone.CFrame · มือ/เท้าถึงแฮนด์ด้วย IK 2 ท่อน
--   ทุกชิ้น Anchored ไม่มีสคริปต์/เสียง/ไฟ, WorldPivot = กลางกล่อง หันตามทิศฉาก
--   attribute "BookYaw" = มุมกล้อง (0 = หน้า, 180 = หลัง), "BookFocusY" / "BookFit" = ภาพระยะใกล้ (ดู shared/BookPortrait)
-- 🚨 ห้ามมีเลือด/อวัยวะในรูป: กระสือตัดภาพแค่หัวกับผม, ศพไฟคลอกเป็นสีถ่านดำล้วน, น้ำมันเลือดใช้สีเดียวกับในเกม
-- เสร็จแล้วต้องเอาไปไว้ที่ ReplicatedStorage.BookPortraits ของ place Lobby

local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local GHOSTS = SS.GhostTemplates
local HUMANS = SS.HumanTemplates
local VEH = SS.VehicleTemplates
local CLIPS = require(RS.Shared.GhostClipData:Clone()) :: any

-- โมดูลจริงของเกม (ชุด/ผม/ผิว/โน้มให้มือถึงแฮนด์) โหลดจากสำเนา ไม่แคชผลรอบก่อน
local HumanNPC = (function(): any
	local c = SSS.Server.HumanNPC:Clone()
	c.Parent = SSS.Server
	local ok, r = pcall(require, c)
	c:Destroy()
	assert(ok, r)
	return r
end)()

local TEMPLATE_OF = { human_base = "villager_male", human_female = "villager_female", human_elder_male = "villager_male", human_elder_female = "villager_female" }
local ANIM_OF = { human_elder_male = "human_base", human_elder_female = "human_female" }

-- ---------------------------------------------------------------- ท่า
local function bone(m: Instance, name: string): Bone?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then
			return d
		end
	end
	return nil
end

local function bakeKfs(m: Model, kfs: KeyframeSequence?, frac: number): boolean
	if not kfs then
		return false
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
	return true
end

-- ท่า mocap ของผี (ค่าเดียวกับที่ client/GhostAnimRunner ใส่ Bone.Transform)
local function bakeMocap(m: Model, name: string, frac: number): boolean
	local c = CLIPS[name]
	if not c then
		return false
	end
	local root, hips = m:FindFirstChild("RootPart") :: BasePart?, bone(m, "hips")
	local scale = 1
	if root and hips then
		local dy = math.abs(hips.WorldPosition.Y - root.Position.Y)
		if dy > 0.2 then
			scale = math.clamp(dy / 2.95, 0.4, 2.5)
		end
	end
	local i = math.clamp(math.floor(#c.times * frac) + 1, 1, #c.times)
	for _, b in ipairs(m:GetDescendants()) do
		local keys = b:IsA("Bone") and c.tracks[b.Name]
		if keys then
			local k = keys[math.min(i, #keys)]
			local cf = CFrame.new(k[1], k[2], k[3], k[4], k[5], k[6], k[7])
			b.CFrame = b.CFrame * ((cf - cf.Position) + cf.Position * scale)
		end
	end
	return true
end

local function humanKfs(char: string, clip: string): KeyframeSequence?
	local c = ANIM_OF[char] or char
	for _, f in ipairs({ "HumanAnimsMocap", "HumanAnims" }) do
		local root = SS:FindFirstChild(f)
		for _, who in ipairs({ c, "human_base" }) do
			local folder = root and root:FindFirstChild(who)
			local k = folder and (folder:FindFirstChild(clip) or folder:FindFirstChild(who .. "_" .. clip))
			if k and k:IsA("KeyframeSequence") then
				return k
			end
		end
	end
	return nil
end

local function ghostKfs(name: string, clip: string): KeyframeSequence?
	local root = SS:FindFirstChild("GhostAnims")
	local folder = root and root:FindFirstChild(name)
	local k = folder and (folder:FindFirstChild(clip) or folder:FindFirstChild(name .. "_" .. clip))
	return if k and k:IsA("KeyframeSequence") then k else nil
end

-- IK 2 ท่อน: ปลาย (tip) ไปที่ pos ข้อกลางหันไปทาง pole
local CHAINS = {
	handL = { "upper_arm.L", "forearm.L", "hand.L" },
	handR = { "upper_arm.R", "forearm.R", "hand.R" },
	footL = { "thigh.L", "shin.L", "foot.L" },
	footR = { "thigh.R", "shin.R", "foot.R" },
}
local function aim(b: Bone, from: Vector3, to: Vector3)
	if from.Magnitude < 1e-4 or to.Magnitude < 1e-4 then
		return
	end
	local r = CFrame.fromRotationBetweenVectors(from.Unit, to.Unit)
	local w = b.WorldCFrame
	b.WorldCFrame = CFrame.new(w.Position) * r * w.Rotation
end
local function solveIK(m: Model, targets: { [string]: any })
	for key, t in pairs(targets) do
		local ch = CHAINS[key]
		local a, b, c = bone(m, ch[1]), bone(m, ch[2]), bone(m, ch[3])
		if a and b and c then
			local tipRot = c.WorldCFrame.Rotation
			local p0 = a.WorldPosition
			local l1 = (b.WorldPosition - p0).Magnitude
			local l2 = (c.WorldPosition - b.WorldPosition).Magnitude
			local to = t.pos - p0
			local d = math.clamp(to.Magnitude, math.abs(l1 - l2) + 0.01, l1 + l2 - 0.01)
			local dir = to.Unit
			local pole = (t.pole - p0)
			pole = pole - dir * pole:Dot(dir)
			pole = if pole.Magnitude > 1e-3 then pole.Unit else Vector3.yAxis
			local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
			local mid = p0 + dir * (l1 * cosA) + pole * (l1 * math.sqrt(1 - cosA * cosA))
			aim(a, b.WorldPosition - p0, mid - p0)
			aim(b, c.WorldPosition - b.WorldPosition, (p0 + dir * d) - b.WorldPosition)
			if string.sub(key, 1, 4) == "foot" then
				local w = c.WorldCFrame
				c.WorldCFrame = CFrame.new(w.Position) * tipRot
			end
		end
	end
end

-- ---------------------------------------------------------------- ตัวละคร
local SKIN = Color3.fromRGB(209, 179, 153)
local function hipsOffset(m: Model): Vector3
	local hb = bone(m, "hips")
	return if hb then m:GetPivot():PointToObjectSpace(hb.WorldPosition) else Vector3.new(0, 3.1, 0)
end

-- ชาวบ้าน: spec = { char, outfit, hair, clip, frac }
local function human(spec: { [string]: any }): (Model, Vector3)
	local m = HUMANS[TEMPLATE_OF[spec.char]]:Clone()
	HumanNPC.Dress(m, { char = spec.char, outfit = spec.outfit, hair = spec.hair, skinTint = SKIN, noHat = spec.noHat })
	local off = hipsOffset(m)
	bakeKfs(m, humanKfs(spec.char, spec.clip), spec.frac or 0.3)
	return m, off
end

-- ผี: ท่า mocap ก่อน ไม่มีค่อยใช้ KeyframeSequence
local function ghost(name: string, clip: string?, frac: number?): (Model, Vector3)
	local m = GHOSTS[name]:Clone()
	local off = hipsOffset(m)
	if clip and not bakeMocap(m, clip, frac or 0.3) then
		if not bakeKfs(m, ghostKfs(name, clip), frac or 0.3) then
			warn("BookPortraits: no clip " .. name .. "/" .. clip)
		end
	end
	return m, off
end

-- ---------------------------------------------------------------- มอไซค์ลูกค้า (สูตร CoreLoop.humanizeDriver)
type Bike = { m: Model, hip: CFrame, pillion: CFrame, targets: { [string]: any }, piv: CFrame }
local function bike(): Bike
	local b = VEH.CustomerBike:Clone()
	local piv = b:GetPivot()
	local rot = piv.Rotation
	local drv = b:FindFirstChild("DriverNPC") :: Model
	local torso = drv:FindFirstChild("Torso") :: BasePart
	local hip = CFrame.new((torso.CFrame * CFrame.new(0, -torso.Size.Y / 2, 0)).Position) * rot * CFrame.new(0, 0.12, 0.15)
	local hipX = piv:PointToObjectSpace(hip.Position).X
	local targets = {}
	for _, p in ipairs(drv:GetDescendants()) do
		if p:IsA("BasePart") and (p.Name == "Hand" or p.Name == "LeftFoot" or p.Name == "RightFoot") then
			local lp = piv:PointToObjectSpace(p.Position)
			local side = if lp.X > hipX then 1 else -1
			if p.Name == "Hand" then
				targets[if side > 0 then "handR" else "handL"] = { pos = piv:PointToWorldSpace(lp), pole = piv:PointToWorldSpace(lp + Vector3.new(1.2 * side, -1.2, 1)) }
			else
				local fp = Vector3.new(hipX + side * math.max(0.6, math.abs(lp.X - hipX) * 0.8), lp.Y + 0.1, lp.Z + 0.45)
				targets[if side > 0 then "footR" else "footL"] = { pos = piv:PointToWorldSpace(fp), pole = piv:PointToWorldSpace(fp + Vector3.new(side * 1.6, 1.4, -0.8)) }
			end
		end
	end
	local pas = b:FindFirstChild("GhostPassenger")
	local pt = pas and pas:FindFirstChild("Torso") :: BasePart?
	local pillion = if pt then CFrame.new(pt.CFrame:PointToWorldSpace(Vector3.new(0, -1.05 + 0.42, 0))) * rot else hip * CFrame.new(0, 0.2, 1.2)
	for _, n in ipairs({ "DriverNPC", "GhostPassenger", "WheelHairAnomaly" }) do
		local x = b:FindFirstChild(n)
		if x then
			x:Destroy()
		end
	end
	return { m = b, hip = hip, pillion = pillion, targets = targets, piv = piv }
end

-- คนขับ: คืนตัวละคร (แต่งต่อได้ เช่น บิดคอ)
local function driver(b: Bike, spec: { [string]: any }): Model
	local s = table.clone(spec)
	s.clip = "ride_moto"
	local m, off = human(s)
	local hip = HumanNPC.FitReach(spec.char, "ride_moto", b.hip, b.targets)
	m:PivotTo(hip * CFrame.new(-off))
	solveIK(m, b.targets)
	m.Parent = b.m
	return m
end
local function pillion(b: Bike, name: string, clip: string, frac: number)
	local m, off = ghost(name, clip, frac)
	m:PivotTo(b.pillion * CFrame.new(-off))
	m.Parent = b.m
end

local MAN = { char = "human_base", outfit = "wan_flannel", hair = "student" }

local function tintSkin(m: Model, color: Color3)
	for _, c in ipairs(m:GetChildren()) do
		if c:IsA("MeshPart") and (string.sub(c.Name, 1, 4) == "Body" or string.sub(c.Name, 1, 5) == "Lower") then
			local sa = c:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				pcall(function()
					(sa :: any).Color = color
				end)
			end
		end
	end
end

local function slab(parent: Instance, cf: CFrame, size: Vector3, color: Color3)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
end

-- ---------------------------------------------------------------- ฉากแต่ละหน้า: คืน (โมเดล, ทิศฉาก, มุมกล้อง, focusY?, fit?)
local SCENES: { [string]: () -> ...any } = {
	Anomaly_Headless = function()
		local b = bike()
		driver(b, MAN)
		pillion(b, "ghost_headless", "pillion_hug", 0.3)
		return b.m, b.piv, -72
	end,
	Anomaly_Cemetery = function()
		local b = bike()
		driver(b, { char = "human_elder_male", outfit = "mohom", hair = "bald_grey" })
		-- ViewportFrame ไม่วาด SurfaceGui: ทำป้ายหน้าศพเป็นชิ้น (ขาวขอบดำ + แถบตัวหนังสือ)
		local plate = b.m:FindFirstChild("LicensePlate") :: any
		if plate then
			local part: BasePart? = if plate:IsA("BasePart") then plate else plate:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local c = part.Position
				local face = CFrame.lookAt(c, c - b.piv.LookVector) -- หน้าป้ายหันไปท้ายรถ
				local w, h = math.max(part.Size.X, part.Size.Z), part.Size.Y
				w, h = math.max(w, 1), math.max(h, 0.6)
				local ink = Color3.fromRGB(18, 16, 16)
				local base = face * CFrame.new(0, 0, -(math.min(part.Size.X, part.Size.Z) / 2 + 0.03))
				slab(b.m, base, Vector3.new(w + 0.12, h + 0.12, 0.02), ink)
				slab(b.m, base * CFrame.new(0, 0, -0.015), Vector3.new(w, h, 0.02), Color3.fromRGB(226, 222, 208))
				slab(b.m, base * CFrame.new(0, h * 0.2, -0.03), Vector3.new(w * 0.72, h * 0.16, 0.02), ink)
				slab(b.m, base * CFrame.new(0, -h * 0.1, -0.03), Vector3.new(w * 0.5, h * 0.09, 0.02), ink)
				slab(b.m, base * CFrame.new(0, -h * 0.29, -0.03), Vector3.new(w * 0.6, h * 0.09, 0.02), ink)
			end
		end
		return b.m, b.piv, 165
	end,
	Anomaly_NeckTwist = function()
		local b = bike()
		local d = driver(b, { char = "human_base", outfit = "red_shirt", hair = "side_part" })
		-- HumanNPC.MakeDouble "twist"
		local nb, hb = bone(d, "neck"), bone(d, "head")
		local rNeck = CFrame.Angles(0, math.rad(75), 0) * CFrame.Angles(math.rad(8), 0, math.rad(20))
		local rTotal = CFrame.Angles(0, math.pi, 0) * CFrame.Angles(math.rad(16), 0, math.rad(38))
		if nb then
			nb.CFrame = nb.CFrame * rNeck
		end
		if hb then
			hb.CFrame = hb.CFrame * (if nb then rNeck:Inverse() * rTotal else rTotal)
		end
		tintSkin(d, Color3.fromRGB(165, 180, 168))
		return b.m, b.piv, 160, 0.72, 0.62
	end,
	Anomaly_TaKhon = function()
		local b = bike()
		local m, off = ghost("ghost_ta_khon", "mask_tilt", 0.5)
		local hip = HumanNPC.FitReach("human_base", "ride_moto", b.hip, b.targets)
		m:PivotTo(hip * CFrame.new(-off))
		solveIK(m, b.targets)
		m.Parent = b.m
		return b.m, b.piv, -30
	end,
	Anomaly_MirrorGhost = function()
		local b = bike()
		driver(b, { char = "human_base", outfit = "wan_denim", hair = "side_part" })
		pillion(b, "ghost_mirror", "pillion_look", 0.6)
		return b.m, b.piv, -72
	end,
	Outage_Shrouds = function()
		-- ศพห่อผ้ายืนเรียงในทุ่ง 3 ร่าง ลึกเข้าไปเรื่อยๆ
		local g = Instance.new("Model")
		local rot = GHOSTS.ghost_shroud:GetPivot().Rotation
		for i, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(-2.1, 0, 3), Vector3.new(2.1, 0, 5) }) do
			local m = ghost("ghost_shroud", "shroud_idle", 0.15 + i * 0.2)
			m:PivotTo(rot * CFrame.new(off))
			m.Parent = g
		end
		return g, rot, 8, 0.5, 1.05
	end,
	Big_Krasue = function()
		-- เห็นแค่หัวกับผม (ห้ามเห็นเครื่องใน ดู GEMINI.md หัวข้อ 0)
		local m = ghost("Krasue", "Float", 0.4)
		return m, m:GetPivot(), 18, 0.82, 0.42
	end,
	Big_Pret = function()
		local m = ghost("Pret", "TallSlowWalk", 0.25)
		return m, m:GetPivot(), 18, 0.5, 1.02
	end,
	Anomaly_MonkRadio = function()
		-- วิทยุที่วางในร้านจริง (RadioV2) หันหน้าปัดเข้ากล้อง
		local src = workspace.InteractiveProps.Radio :: Model
		local m = Instance.new("Model")
		for _, c in ipairs(src:GetChildren()) do
			if c:IsA("BasePart") then
				c:Clone().Parent = m
			end
		end
		local body = m:FindFirstChild("Radio") :: BasePart
		local dial = m:FindFirstChild("RadioDial") :: BasePart
		local out = dial.Position - body.Position
		local axis = body.CFrame.LookVector
		local face = if out:Dot(axis) >= 0 then axis else -axis
		face = Vector3.new(face.X, 0, face.Z).Unit
		return m, CFrame.lookAt(Vector3.zero, face), 18
	end,
	Anomaly_BloodFuel = function()
		local ip = workspace.InteractiveProps
		local src = (ip:FindFirstChild("FuelPumps") or ip):FindFirstChild("GasPump") :: Model
		local m = src:Clone()
		local liquid = m:FindFirstChild("FuelLiquid") :: any
		if liquid then
			liquid.Transparency = 0
			liquid.Color = Color3.fromRGB(110, 8, 12)
			local sa = liquid:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa.Color = Color3.fromRGB(150, 10, 14) -- AnomalyManager.Anomaly_BloodFuel
			end
		end
		return m, m:GetPivot(), 0
	end,
	Anomaly_BurnedCorpse = function()
		local m = ghost("ghost_burned", nil)
		bakeKfs(m, humanKfs("human_base", "idle"), 0.3)
		-- สีถ่านดำล้วน (ไม่ใช้พื้นผิวรอยไหม้แดงของในเกม รูปในสมุดเห็นใกล้)
		for _, c in ipairs(m:GetDescendants()) do
			if c:IsA("MeshPart") then
				local sa = c:FindFirstChildOfClass("SurfaceAppearance") :: any
				if sa then
					sa.Color = Color3.fromRGB(58, 50, 46)
				end
				c.Color = Color3.fromRGB(58, 50, 46)
			end
		end
		return m, m:GetPivot(), 18
	end,
	Anomaly_ShoulderChild = function()
		local g = Instance.new("Model")
		local host = human({ char = "human_base", outfit = "mohom", hair = "side_part", clip = "idle", frac = 0.3 })
		local rot = host:GetPivot().Rotation
		host:PivotTo(rot)
		host.Parent = g
		local neck = bone(host, "neck")
		local m = GHOSTS.ghost_child:Clone()
		local off = hipsOffset(m)
		local R = math.rad
		-- client/GhostAnimRunner.poseShoulderRide
		local pose = {
			["hips"] = CFrame.Angles(R(-2), 0, 0), ["spine"] = CFrame.Angles(R(-4), 0, 0), ["chest"] = CFrame.Angles(R(-4), 0, 0),
			["neck"] = CFrame.Angles(R(14), 0, 0), ["head"] = CFrame.Angles(R(14), 0, R(4)),
			["thigh.L"] = CFrame.Angles(R(-82), R(14), R(-24)), ["thigh.R"] = CFrame.Angles(R(-82), R(-14), R(24)),
			["shin.L"] = CFrame.Angles(R(72), 0, R(8)), ["shin.R"] = CFrame.Angles(R(72), 0, R(-8)),
			["foot.L"] = CFrame.Angles(R(-10), 0, 0), ["foot.R"] = CFrame.Angles(R(-10), 0, 0),
			["upper_arm.L"] = CFrame.Angles(R(-40), R(20), R(60)), ["upper_arm.R"] = CFrame.Angles(R(-40), R(-20), R(-60)),
			["forearm.L"] = CFrame.Angles(R(55), R(35), R(92)), ["forearm.R"] = CFrame.Angles(R(55), R(-35), R(-92)),
			["hand.L"] = CFrame.Angles(R(22), 0, 0), ["hand.R"] = CFrame.Angles(R(22), 0, 0),
		}
		for _, b in ipairs(m:GetDescendants()) do
			if b:IsA("Bone") and pose[b.Name] then
				b.CFrame = b.CFrame * pose[b.Name]
			end
		end
		if neck then
			m:PivotTo(CFrame.new(neck.WorldPosition) * rot * CFrame.new(0, 0.32, 0.34) * CFrame.new(-off))
		end
		m.Parent = g
		return g, rot, 20
	end,
	Anomaly_ShroudPickup = function()
		local v = VEH.ThaiPickupOld:Clone()
		for _, n in ipairs({ "DriverNPC", "GhostPassenger" }) do
			local x = v:FindFirstChild(n)
			if x then
				x:Destroy()
			end
		end
		local m = ghost("ghost_shroud", "shroud_idle", 0.3)
		m:PivotTo(v:GetPivot() * CFrame.new(0, 3.7, 6.4) * CFrame.Angles(0, math.pi, 0))
		m.Parent = v
		return v, v:GetPivot(), 168, 0.5, 2
	end,
	Anomaly_BackFeet = function()
		local m = human({ char = "human_base", outfit = "farmer", hair = "rong_song_sung", clip = "idle", frac = 0.3, noHat = true })
		for _, n in ipairs({ "foot.L", "foot.R" }) do
			local fb = bone(m, n)
			if fb then
				fb.CFrame = fb.CFrame * CFrame.fromAxisAngle(fb.WorldCFrame:VectorToObjectSpace(Vector3.yAxis), math.pi)
			end
		end
		return m, m:GetPivot(), 35, 0.36, 0.72
	end,
}

local function finish(model: Model, facing: CFrame, yaw: number, focusY: number?, fit: number?)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("LayerCollector")
			or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") or d:IsA("ValueBase") or d:IsA("Folder") or d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Constraint")
			or (d:IsA("Attachment") and not d:IsA("Bone")) then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			-- ชิ้นล่องหน (ตัวชน ที่นั่ง จุดอ้างอิง) ไม่ต้องติดไปด้วย ยกเว้นรากกระดูก
			if d.Transparency >= 0.99 and not d:FindFirstChildWhichIsA("Bone", true) then
				d:Destroy()
			end
		end
	end
	local function clean(x: Instance)
		for k in pairs(x:GetAttributes()) do
			pcall(function()
				x:SetAttribute(k, nil)
			end)
		end
		for _, t in ipairs(x:GetTags()) do
			x:RemoveTag(t)
		end
	end
	clean(model)
	for _, d in ipairs(model:GetDescendants()) do
		clean(d)
	end
	local rot = facing.Rotation
	model.WorldPivot = CFrame.new(model:GetBoundingBox().Position) * rot
	model:PivotTo(rot)
	model:SetAttribute("BookYaw", yaw)
	model:SetAttribute("BookFocusY", focusY)
	model:SetAttribute("BookFit", fit)
end

-- ใช้งาน: require(game.ServerStorage.BuildBookPortraits:Clone())()  (Clone กัน require แคชผลรอบก่อน)
return function(): string
	local order = (require(RS.Shared.LanguageModule:Clone()) :: any).BookOrder
	local out = Instance.new("Folder")
	out.Name = "BookPortraits"
	local report = {}
	for _, key in ipairs(order) do
		local scene = SCENES[key]
		if not scene then
			table.insert(report, key .. ": NO SCENE")
			continue
		end
		local ok, m, facing, yaw, focusY, fit = pcall(scene)
		if ok and m then
			m.Name = key
			local ok2, err = pcall(finish, m, facing, yaw, focusY, fit)
			m.Parent = out
			table.insert(report, key .. (if ok2 then ": ok" else ": finish " .. tostring(err)))
		else
			table.insert(report, key .. ": " .. tostring(m))
		end
	end
	local old = SS:FindFirstChild("BookPortraits")
	if old then
		old:Destroy()
	end
	out.Parent = SS
	return table.concat(report, "\n")
end
