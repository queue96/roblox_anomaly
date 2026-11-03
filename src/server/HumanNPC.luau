--!strict
-- HumanNPC.luau (ModuleScript ฝั่ง Server)
-- ชาวบ้านแบบใหม่: ตัวละคร skinned mesh จาก Blender (assets/models/human_base -> roblox/human_base/human_base.fbx)
--   แม่แบบ = ServerStorage.HumanTemplates.human_base (นำเข้าด้วย Import 3D: Scale 0.01, Rig Custom, Anchored)
--   ในแม่แบบมีผมทุกทรงและชุดทุกชุด ตอนสร้างจะสุ่ม 1 ชุด + 1 ทรงผม แล้วลบชิ้นที่ไม่ได้ใช้ทิ้ง
--   ผิวถูกตัดเป็น Body (ไม่มีชุดไหนปิด) + Skin_<n> (ผิวใต้ชุด): ลบ Skin_ ที่ชุดที่ใส่ปิดอยู่ (ReplicatedStorage.Shared.HumanSkinParts)
--   เสื้อผ้าจึงแนบตัวได้บาง ๆ โดยผิวไม่โผล่ทะลุเวลาขยับ
--   ท่าทาง = AnimationController.Animator + ID ใน ReplicatedStorage.Shared.HumanAnimIds
--
-- โครงสร้างที่คืนให้ Pedestrian (ให้โค้ดเดิมที่หา DriverNPC / Head / Torso ใช้ต่อได้):
--   Walker (Model, PrimaryPart = Root ที่พื้นใต้เท้า หน้า = -Z)
--     DriverNPC (ตัวละคร, attribute Human = true, Outfit, Hair)
--       Head / Torso  ชิ้นล่องหน วางที่หัว/อก (ตำแหน่งกล่องคำพูด, กล้อง jumpscare)
--       GhostDouble   (มีเมื่อโดนผีบางแบบ) ร่างผีซ้อน เห็นเฉพาะตอนพนมมือ เล่นท่าพร้อมตัวจริง
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HumanNPC = {}

local TEMPLATE_NAME = "human_base"

-- ชุดของผู้ชาย (ชื่อตรงกับ Cloth_<ชุด>* ในแม่แบบ) weight = โอกาสสุ่ม
--   skirt = ผ้านุ่งยาว (ต้องเดินด้วย walk_skirt), helmet = หมวกกันน็อก (ไม่ใส่ผม)
local OUTFITS = {
	{ name = "mohom", weight = 3 },
	{ name = "farmer", weight = 2 },
	{ name = "sarong", weight = 2, skirt = true },
	{ name = "red_shirt", weight = 2 },
	{ name = "wan_baggy", weight = 1, teen = true },
	{ name = "wan_flannel", weight = 1, teen = true },
	{ name = "wan_denim", weight = 1, teen = true, helmet = true },
	{ name = "wan_camo", weight = 1, teen = true, helmet = true },
}
local HAIRS = { "student", "rong_song_sung", "side_part" }

-- ความเร็วเดินที่ท่า walk ตั้งใจไว้ (studs/วินาที) ใช้ปรับความเร็วท่าให้เท้าไม่ไถลพื้น
local WALK_CLIP_SPEED = 4.3

type Rig = {
	animators: { Animator },
	tracks: { [Animator]: { [string]: AnimationTrack } },
	current: string?,
	overlays: { [string]: boolean }, -- ท่าซ้อนที่เล่นทับท่าเดิน/ยืน (ถือร่ม หิ้วแกลลอน พนมมือ)
	skirt: boolean,
	dance: string?,
	seated: string?, -- นั่งขับรถอยู่: ท่าขับนี้ตลอด (คำสั่งเดิน/ยืน/เต้นไม่มีผล)
}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function template(): Model?
	local f = ServerStorage:FindFirstChild("HumanTemplates")
	return f and f:FindFirstChild(TEMPLATE_NAME) :: Model?
end

function HumanNPC.Available(): boolean
	return template() ~= nil
end

-- Skin_<n> -> ชุดที่ปิดผิวชิ้นนั้น (สร้างจาก build_anims.py ตอน export)
local function skinParts(): { [string]: { string } }
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("HumanSkinParts")
	if not mod then
		return {}
	end
	return (require(mod :: ModuleScript) :: any)[TEMPLATE_NAME] or {}
end

local function animIds(): { [string]: string }
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("HumanAnimIds")
	if not mod then
		return {}
	end
	return (require(mod :: ModuleScript) :: any)[TEMPLATE_NAME] or {}
end

local function pickOutfit(opts: { [string]: any }): { [string]: any }
	if opts.outfit then
		for _, o in ipairs(OUTFITS) do
			if o.name == opts.outfit then
				return o
			end
		end
	end
	local pool, total = {}, 0
	for _, o in ipairs(OUTFITS) do
		-- กางร่ม / ถือแกลลอน / งานแห่: ไม่ใส่หมวกกันน็อก, วัยรุ่น: เฉพาะชุดสายแว้น
		local ok = (opts.teen == nil or (o.teen == true) == opts.teen) and not (o.helmet and (opts.umbrella or opts.noHelmet))
		if ok then
			table.insert(pool, o)
			total += o.weight
		end
	end
	local r = math.random() * total
	for _, o in ipairs(pool) do
		r -= o.weight
		if r <= 0 then
			return o
		end
	end
	return pool[#pool]
end

local function bone(model: Instance, name: string): Bone?
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then
			return d
		end
	end
	return nil
end

local function marker(parent: Instance, name: string, size: Vector3, pos: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- แต่งตัว: สุ่มชุด + ทรงผมแล้วลบชิ้นที่ไม่ได้ใช้ (ชุดอื่น ผมอื่น ผิวที่ชุดนี้ปิด) ใช้ทั้ง NPC และตัวผู้เล่น
-- คืนข้อมูลชุดที่ได้ ({ name, skirt, helmet, teen })
-- ชิ้นที่เป็นหมวก (ชื่อลงท้าย): ngob = งอบ, helmet / visor = หมวกกันน็อก
local HAT_SUFFIX = { "_ngob", "_helmet", "_visor" }
local function isHat(n: string): boolean
	for _, s in ipairs(HAT_SUFFIX) do
		if string.sub(n, -#s) == s then
			return true
		end
	end
	return false
end

function HumanNPC.Dress(d: Model, opts: { [string]: any }): { [string]: any }
	if opts.noHat then
		-- ไม่ใส่หมวกทุกชนิด (คนขับรถยนต์): ไม่เอาชุดที่มากับหมวกกันน็อก และถอดงอบออก
		opts = table.clone(opts)
		opts.noHelmet = true
	end
	local outfit = pickOutfit(opts)
	local hair = if outfit.helmet then nil else (opts.hair or HAIRS[math.random(#HAIRS)])
	local skin = skinParts()
	for _, c in ipairs(d:GetChildren()) do
		if c:IsA("MeshPart") and c.Name ~= "Body" and c.Name ~= "BodyHead" then
			local n = c.Name
			local keep
			if string.sub(n, 1, 5) == "Skin_" then
				keep = not table.find(skin[n] or {}, outfit.name)
			elseif string.sub(n, 1, 6) == "Cloth_" or string.sub(n, 1, 5) == "Hair_" then
				keep = n == "Cloth_" .. outfit.name or string.sub(n, 1, #outfit.name + 7) == "Cloth_" .. outfit.name .. "_" or (hair ~= nil and n == "Hair_" .. hair)
				if keep and opts.noHat and isHat(n) then
					keep = false
				end
			else
				keep = true
			end
			if not keep then
				c:Destroy()
			end
		end
	end
	d:SetAttribute("Human", true)
	d:SetAttribute("Outfit", outfit.name)
	d:SetAttribute("Hair", hair or "")
	return outfit
end

-- opts: outfit (ชื่อชุด), hair, teen (true = ชุดสายแว้นเท่านั้น / false = ไม่เอาชุดสายแว้น), umbrella, noHelmet,
--       dance (ชื่อท่าเต้นตอนแกว่ง เช่น "ramwong", "wan_bounce")
function HumanNPC.Build(opts: { [string]: any }): Model
	local tpl = template() :: Model
	local m = Instance.new("Model")
	m.Name = "Walker"
	local root = marker(m, "Root", Vector3.new(1, 0.2, 1), Vector3.zero)
	m.PrimaryPart = root

	local d = tpl:Clone()
	d.Name = "DriverNPC"
	d:PivotTo(CFrame.new())
	local outfit = HumanNPC.Dress(d, opts)

	-- หัว / อก: ชิ้นล่องหนให้โค้ดเดิมใช้หาตำแหน่ง
	local hb = bone(d, "head")
	local cb = bone(d, "chest")
	marker(d, "Head", Vector3.new(1, 1.1, 1), (if hb then hb.WorldPosition else Vector3.new(0, 5.5, 0)) + Vector3.new(0, 0.55, 0))
	marker(d, "Torso", Vector3.new(1.6, 1.6, 0.9), if cb then cb.WorldPosition + Vector3.new(0, 0.3, 0) else Vector3.new(0, 4.4, 0))
	d.Parent = m

	local ac = d:FindFirstChildOfClass("AnimationController")
	local animator = ac and ac:FindFirstChildOfClass("Animator")
	rigs[m] = {
		animators = if animator then { animator } else {},
		tracks = {},
		current = nil,
		overlays = {},
		skirt = outfit.skirt == true,
		dance = opts.dance,
	}
	-- ท่าอารมณ์ / หน้าตา / กะพริบตา (shared/HumanEmotes, client/HumanEmotesRunner)
	game:GetService("CollectionService"):AddTag(m, "HumanEmote")
	return m
end

-- ให้ชาวบ้านนั่งขับรถ: สร้างตัว วางสะโพก (กระดูก hips) ที่ hip แล้วย้าย DriverNPC เข้าไปในรถ
-- (โค้ดผีหา vehicle.DriverNPC ได้เหมือนเดิม) ท่า = clip ("drive_car" / "ride_moto" / "drive_tuktuk" / "ride_bicycle")
-- เล่นท่าเองเมื่อรถเข้า Workspace คืน nil ถ้าไม่มีแม่แบบหรือท่านี้ยังไม่ได้ publish
-- IK: ดึงมือ/เท้าของคนขับไปที่จุดบนรถ (แฮนด์ / พวงมาลัย / ที่พักเท้า) ทับท่าขับที่เล่นอยู่
--   จุดเป้าเป็น Attachment ในชิ้นล่องหน "IKTargets" ใน DriverNPC (ขยับไปกับรถเอง)
--   pole = ทิศที่ศอก/เข่าหันไป (ศอกออกข้างลง, เข่าขึ้นหน้า)
type IKTarget = { pos: Vector3, pole: Vector3 }
local function addIK(d: Model, targets: { [string]: IKTarget })
	local ac = d:FindFirstChildOfClass("AnimationController")
	if not ac then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "IKTargets"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CFrame = d:GetPivot()
	holder.Parent = d
	local chains = {
		handL = { "upper_arm.L", "hand.L" },
		handR = { "upper_arm.R", "hand.R" },
		footL = { "thigh.L", "foot.L" },
		footR = { "thigh.R", "foot.R" },
	}
	for key, t in pairs(targets) do
		local ch = chains[key]
		local root, tip = ch and bone(d, ch[1]), ch and bone(d, ch[2])
		if root and tip then
			-- ใส่ Parent ก่อนตั้ง WorldPosition (Attachment ที่ยังไม่มี parent จะเก็บเป็นค่าเทียบศูนย์โลก)
			local a = Instance.new("Attachment")
			a.Name = key
			a.Parent = holder
			a.WorldPosition = t.pos
			local pole = Instance.new("Attachment")
			pole.Name = key .. "Pole"
			pole.Parent = holder
			pole.WorldPosition = t.pole
			local ik = Instance.new("IKControl")
			ik.Name = "IK_" .. key
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = root
			ik.EndEffector = tip
			ik.Target = a
			ik.Pole = pole
			ik.Weight = 1
			ik.Parent = ac
		end
	end
end

function HumanNPC.SeatIn(vehicle: Model, hip: CFrame, clip: string, opts: { [string]: any }?, targets: { [string]: IKTarget }?): Model?
	if not (template() and animIds()[clip]) then
		return nil
	end
	local o = table.clone(opts or {})
	o.noHelmet = if o.noHelmet == nil then false else o.noHelmet
	local w = HumanNPC.Build(o)
	local d = w:FindFirstChild("DriverNPC") :: Model
	local hb = bone(d, "hips")
	local hipRel = if hb then d:GetPivot():PointToObjectSpace(hb.WorldPosition) else Vector3.new(0, 3.1, 0)
	d:PivotTo(hip * CFrame.new(-hipRel))
	if targets then
		addIK(d, targets)
	end
	local old = vehicle:FindFirstChild("DriverNPC")
	if old then
		old:Destroy()
	end
	d.Parent = vehicle
	rigs[vehicle] = rigs[w]
	rigs[w] = nil
	rigs[vehicle].seated = clip
	w:Destroy()
	task.spawn(function()
		local t0 = os.clock()
		-- รถยังไม่ถูกวางลงฉากตอนสร้าง: รอจนตัวคนขับอยู่ใน Workspace (ถูกลบไปก่อน = เลิกรอ)
		while d.Parent and not d:IsDescendantOf(workspace) and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		if d:IsDescendantOf(workspace) then
			HumanNPC.Play(vehicle, clip)
		end
	end)
	return d
end

function HumanNPC.Is(m: Instance): boolean
	return rigs[m :: Model] ~= nil
end

local function track(rig: Rig, animator: Animator, clip: string): AnimationTrack?
	local t = rig.tracks[animator]
	if not t then
		t = {}
		rig.tracks[animator] = t
	end
	if t[clip] == nil then
		local id = animIds()[clip]
		if not id or not animator:IsDescendantOf(workspace) then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local tr = animator:LoadAnimation(a)
		tr.Looped = true
		t[clip] = tr
		-- โหลดท่ายืน/เดินไว้ล่วงหน้าตั้งแต่ครั้งแรก: ท่าที่ยังโหลดไม่เสร็จเล่นไม่ออก ตัวจะกลับเป็นท่า A แวบหนึ่ง
		for _, c in ipairs({ "idle", "walk", "walk_skirt" }) do
			if t[c] == nil and animIds()[c] then
				local pa = Instance.new("Animation")
				pa.AnimationId = animIds()[c]
				local ptr = animator:LoadAnimation(pa)
				ptr.Looped = true
				t[c] = ptr
			end
		end
	end
	return t[clip]
end

-- เริ่มท่า tr แล้วค่อยหยุดท่าอื่น (ไม่รวมท่าซ้อน เช่น ถือร่ม) ถ้า tr ยังโหลดไม่เสร็จ ให้ท่าเดิมเล่นต่อจนกว่าจะพร้อม
local function swapTo(rig: Rig, an: Animator, clip: string, tr: AnimationTrack, speed: number?)
	local function go()
		if rig.current ~= clip then
			return -- ระหว่างรอโหลด มีคำสั่งท่าอื่นมาแทนแล้ว
		end
		tr:Play(0.25, 1, speed or 1)
		for name, other in pairs(rig.tracks[an]) do
			if name ~= clip and not rig.overlays[name] and other.IsPlaying then
				other:Stop(0.25)
			end
		end
	end
	if tr.Length > 0 then
		go()
	else
		task.spawn(function()
			local t0 = os.clock()
			while tr.Length == 0 and os.clock() - t0 < 5 do
				task.wait(0.05)
			end
			go()
		end)
	end
end

-- เล่นท่า (ทั้งตัวจริงและร่างผีซ้อน) speed = ความเร็วท่า
function HumanNPC.Play(m: Model, clip: string, speed: number?)
	local rig = rigs[m]
	if not rig then
		return
	end
	if rig.current == clip then
		if speed then
			for _, an in ipairs(rig.animators) do
				local tr = track(rig, an, clip)
				if tr then
					tr:AdjustSpeed(speed)
				end
			end
		end
		return
	end
	local played = false
	local prev = rig.current
	rig.current = clip
	for _, an in ipairs(rig.animators) do
		local tr = track(rig, an, clip)
		if tr then
			swapTo(rig, an, clip, tr, speed)
			played = true
			-- ท่าซ้อนที่สั่งไว้ตอนยังไม่อยู่ใน Workspace (เช่น ถือร่มตั้งแต่สร้าง) เริ่มตรงนี้
			for ov in pairs(rig.overlays) do
				local otr = track(rig, an, ov)
				if otr and not otr.IsPlaying then
					otr.Priority = Enum.AnimationPriority.Action
					otr:Play(0.25)
				end
			end
		end
	end
	-- ยังไม่อยู่ใน Workspace (โหลดท่าไม่ได้) = ยังไม่นับว่าเล่น ครั้งหน้าจะลองใหม่
	if not played then
		rig.current = prev
	end
end

-- ท่าซ้อน (ขยับแค่แขน/ตัวบน เล่นทับท่าเดิน/ยืน): "hold_umbrella" มือขวา, "carry_gallon" มือซ้าย,
-- "hold_flashlight" มือซ้าย, "pray" สองมือ  on = false เลิกถือ
-- เรียกก่อนเอาเข้า Workspace ได้: จะเริ่มเล่นพร้อมท่าแรก
function HumanNPC.Hold(m: Model, clip: string, on: boolean)
	local rig = rigs[m]
	if not rig then
		return
	end
	if clip == "pray" and on then
		-- พนมมือ: มือต้องว่าง เลิกถือทุกอย่างก่อน
		for other in pairs(rig.overlays) do
			if other ~= "pray" then
				HumanNPC.Hold(m, other, false)
			end
		end
	end
	rig.overlays[clip] = on or nil
	for _, an in ipairs(rig.animators) do
		local tr = track(rig, an, clip)
		if tr then
			tr.Priority = Enum.AnimationPriority.Action
			if on and not tr.IsPlaying then
				tr:Play(0.25)
			elseif not on and tr.IsPlaying then
				tr:Stop(0.25)
			end
		end
	end
end

-- เดิน / ยืน (speed = studs ต่อวินาทีที่ตัวเลื่อนจริง)
function HumanNPC.SetMoving(m: Model, moving: boolean, speed: number?)
	local rig = rigs[m]
	if not rig then
		return
	end
	if rig.seated then
		HumanNPC.Play(m, rig.seated)
		return
	end
	if moving then
		local clip = if rig.skirt then "walk_skirt" else "walk"
		HumanNPC.Play(m, clip, math.clamp((speed or WALK_CLIP_SPEED) / WALK_CLIP_SPEED, 0.6, 1.8))
	else
		HumanNPC.Play(m, "idle")
	end
end

-- แกว่ง/เต้นตามขบวน (Pedestrian.Pose): a ~= 0 = กำลังขยับ
function HumanNPC.Pose(m: Model, a: number)
	local rig = rigs[m]
	if not rig then
		return
	end
	if rig.seated then
		HumanNPC.Play(m, rig.seated)
		return
	end
	if a ~= 0 and rig.dance then
		HumanNPC.Play(m, rig.dance)
	else
		HumanNPC.SetMoving(m, a ~= 0)
	end
end

-- ร่างผีซ้อน (เห็นเฉพาะตอนพนมมือ): สำเนาตัวละครใน DriverNPC เล่นท่าเดียวกัน
--   kind = "twist" (หัวหันกลับ 180°) | "pale" (ผิวซีดเขียว)
--   คืนค่า (ร่างผี, รายชื่อชิ้นของตัวจริงที่ต้องซ่อนตอนพนมมือ)
function HumanNPC.MakeDouble(m: Model, kind: string): (Model?, { Instance })
	local rig = rigs[m]
	local d = m:FindFirstChild("DriverNPC") :: Model?
	if not (rig and d) then
		return nil, {}
	end
	local real: { Instance } = {}
	for _, c in ipairs(d:GetChildren()) do
		if c:IsA("MeshPart") then
			table.insert(real, c)
		end
	end
	-- ต้อง Clone ทั้งโมเดลในครั้งเดียว: ประกอบใหม่จากชิ้นที่ Clone ทีละชิ้น ผิวจะไม่ผูกกับกระดูกของร่างใหม่ (ค้างท่า A-pose)
	local double = d:Clone()
	double.Name = "GhostDouble"
	for _, c in ipairs(double:GetChildren()) do
		if c.Name == "Head" or c.Name == "Torso" or c.Name == "GhostDouble" then
			c:Destroy()
		end
	end
	local pivot = d:GetPivot()
	if kind == "twist" then
		-- หมุนกระดูกหัวรอบแกนตั้งของตัว (แกนกระดูกของ Roblox ไม่ตรงกับ Blender จึงหมุนรอบแกนโลก)
		local hb = bone(double, "head")
		if hb then
			local axis = hb.WorldCFrame:VectorToObjectSpace(pivot.UpVector)
			hb.CFrame = hb.CFrame * CFrame.fromAxisAngle(axis, math.pi)
		end
	elseif kind == "pale" then
		for _, c in ipairs(double:GetChildren()) do
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
	double.Parent = d
	local ac = double:FindFirstChildOfClass("AnimationController")
	local animator = ac and ac:FindFirstChildOfClass("Animator")
	if animator then
		table.insert(rig.animators, animator)
		-- เริ่มท่าเดียวกับตัวจริง
		local cur = rig.current
		rig.current = nil
		if cur then
			HumanNPC.Play(m, cur)
		end
	end
	return double, real
end

return HumanNPC
