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

type Rig = { animators: { Animator }, tracks: { [Animator]: { [string]: AnimationTrack } }, current: string?, skirt: boolean, dance: string? }
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
	local outfit = pickOutfit(opts)
	local hair = if outfit.helmet then nil else (opts.hair or HAIRS[math.random(#HAIRS)])
	local skin = skinParts()
	for _, c in ipairs(d:GetChildren()) do
		if c:IsA("MeshPart") and c.Name ~= "Body" then
			local n = c.Name
			local keep
			if string.sub(n, 1, 5) == "Skin_" then
				keep = not table.find(skin[n] or {}, outfit.name)
			else
				keep = n == "Cloth_" .. outfit.name or string.sub(n, 1, #outfit.name + 7) == "Cloth_" .. outfit.name .. "_" or (hair ~= nil and n == "Hair_" .. hair)
			end
			if not keep then
				c:Destroy()
			end
		end
	end
	d:SetAttribute("Human", true)
	d:SetAttribute("Outfit", outfit.name)
	d:SetAttribute("Hair", hair or "")

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
		skirt = outfit.skirt == true,
		dance = opts.dance,
	}
	return m
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
	end
	return t[clip]
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
	for _, an in ipairs(rig.animators) do
		local tr = track(rig, an, clip)
		if tr then
			for name, other in pairs(rig.tracks[an]) do
				if name ~= clip and other.IsPlaying then
					other:Stop(0.25)
				end
			end
			tr:Play(0.25, 1, speed or 1)
			played = true
		end
	end
	-- ยังไม่อยู่ใน Workspace (โหลดท่าไม่ได้) = ยังไม่นับว่าเล่น ครั้งหน้าจะลองใหม่
	if played then
		rig.current = clip
	end
end

-- เดิน / ยืน (speed = studs ต่อวินาทีที่ตัวเลื่อนจริง)
function HumanNPC.SetMoving(m: Model, moving: boolean, speed: number?)
	local rig = rigs[m]
	if not rig then
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
			if c.Name == "Body" or string.sub(c.Name, 1, 5) == "Skin_" then
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
