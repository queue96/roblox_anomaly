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

-- ตัวละคร (ชื่อแม่แบบใน ServerStorage.HumanTemplates) opts.char เลือกได้ ไม่ใส่ = human_base
--   human_base ชาย / human_female หญิง / human_child เด็ก / human_elder_male ตา / human_elder_female ยาย
local DEFAULT_CHAR = "human_base"

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

-- ชุด / ทรงผมของแต่ละตัวละคร (ไม่รวมชุดผี ghost_* และชุดกุมารทอง) sin = ซิ่นยาว เดินด้วย walk_skirt
local OUTFITS_BY: { [string]: { any } } = {
	human_base = OUTFITS,
	human_female = {
		{ name = "blouse_sin", weight = 3, skirt = true },
		{ name = "indigo_scarf", weight = 2, skirt = true },
		{ name = "sabai", weight = 1, skirt = true },
		{ name = "chest_wrap", weight = 1 },
		{ name = "wan_girl", weight = 1, teen = true },
		{ name = "wan_band_tee", weight = 1, teen = true },
		{ name = "wan_crop", weight = 1, teen = true },
		{ name = "wan_plaid", weight = 1, teen = true },
	},
	human_child = { { name = "mohom_child", weight = 1 } },
	human_elder_male = {
		{ name = "mohom", weight = 3 },
		{ name = "farmer", weight = 2 },
		{ name = "sarong", weight = 2, skirt = true },
	},
	human_elder_female = {
		{ name = "blouse_sin", weight = 3, skirt = true },
		{ name = "indigo_scarf", weight = 2, skirt = true },
		{ name = "sabai", weight = 1, skirt = true },
	},
}
local HAIRS_BY: { [string]: { string } } = {
	human_base = HAIRS,
	human_female = { "bob", "ponytail_bow" },
	human_child = { "child_short", "ko", "pia", "klae" },
	human_elder_male = { "bald_grey", "long_white_beard" },
	human_elder_female = { "bun_grey", "curly_grey" },
}

-- ความเร็วเดินที่ท่า walk ตั้งใจไว้ (studs/วินาที) ใช้ปรับความเร็วท่าให้เท้าไม่ไถลพื้น
local WALK_CLIP_SPEED = 4.3
-- ความเร็วตามธรรมชาติของแต่ละท่า (studs/วินาที ที่ความเร็วท่า 1 เท้าไม่ไถล) วัดจากระยะก้าวจริงของเท้าใน Studio
-- 2026-11-05 (ปรับเทียบให้ human_base walk = 4.3) · walk_base = ท่าเดินของ human_base เล่นบนตัวละครนี้
-- เดิมทุกตัวคิดเป็น 4.3 หมด: คนแก่/ผ้าซิ่นที่ก้าวสั้นมากเดินที่ 7 studs/วินาที -> ท่าเร่งจนสุด (1.8) แล้วเท้ายังไถล ดูเดินซอยเท้าไม่ชัด
local NATURAL: { [string]: { [string]: number } } = {
	human_base = { walk = 4.3, walk_base = 4.3, walk_skirt = 1.9, run = 14, run_skirt = 5.8 },
	human_female = { walk = 3.9, walk_base = 4.0, walk_skirt = 1.7, run = 13, run_skirt = 5.3 },
	human_child = { walk = 3.1, walk_base = 2.4, walk_skirt = 1.45, run = 10.5, run_skirt = 4.25 },
	human_elder_male = { walk = 2.0, walk_base = 4.05, walk_skirt = 0.9, run = 7.7, run_skirt = 3.1 },
	human_elder_female = { walk = 1.7, walk_base = 3.75, walk_skirt = 0.75, run = 6.4, run_skirt = 2.6 },
}
-- เลือกท่าแรกที่ต้องเร่งไม่เกินนี้ (เร่งมากกว่านี้ดูซอยเท้าถี่ผิดธรรมชาติ)
local MAX_CLIP_RATE = 1.9
local GAITS_SKIRT = { "walk_skirt", "run_skirt" } -- ผ้านุ่งยาว: ห้ามก้าวยาว (ขาทะลุผ้า) เร็วขึ้น = ก้าวสั้นถี่แบบรีบ
local GAITS = { "walk", "walk_base", "run" }

type Rig = {
	animators: { Animator },
	tracks: { [Animator]: { [string]: AnimationTrack } },
	current: string?,
	overlays: { [string]: boolean }, -- ท่าซ้อนที่เล่นทับท่าเดิน/ยืน (ถือร่ม หิ้วแกลลอน พนมมือ)
	skirt: boolean,
	dance: string?,
	char: string, -- ตัวละคร (ชุดท่าของตัวนี้ ท่าที่ไม่มีใช้ของ human_base)
	seated: string?, -- นั่งขับรถอยู่: ท่าขับนี้ตลอด (คำสั่งเดิน/ยืน/เต้นไม่มีผล)
}
local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any

local function template(char: string?): Model?
	local f = ServerStorage:FindFirstChild("HumanTemplates")
	return f and (f:FindFirstChild(char or DEFAULT_CHAR) or f:FindFirstChild(DEFAULT_CHAR)) :: Model?
end

function HumanNPC.Available(char: string?): boolean
	local f = ServerStorage:FindFirstChild("HumanTemplates")
	return f ~= nil and f:FindFirstChild(char or DEFAULT_CHAR) ~= nil
end

-- Skin_<n> -> ชุดที่ปิดผิวชิ้นนั้น (สร้างจาก build_anims.py ตอน export)
local function skinParts(char: string): { [string]: { string } }
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("HumanSkinParts")
	if not mod then
		return {}
	end
	return (require(mod :: ModuleScript) :: any)[char] or {}
end

-- ท่าของตัวละครนี้ ท่าที่ตัวนี้ไม่มี (ขับรถ ถือร่ม หิ้วแกลลอน พนมมือ ฯลฯ) ใช้ของ human_base (กระดูกชื่อเดียวกัน)
local function animIds(char: string?): { [string]: string }
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("HumanAnimIds")
	if not mod then
		return {}
	end
	local all = require(mod :: ModuleScript) :: any
	local base = all[DEFAULT_CHAR] or {}
	local own = char and all[char]
	if not own or char == DEFAULT_CHAR then
		return setmetatable({ walk_base = base.walk }, { __index = base }) :: any
	end
	local t = table.clone(own)
	t.walk_base = base.walk -- ท่าเดินก้าวยาวชัดของ human_base (ยืมใช้ตอนต้องเดินเร็วกว่าท่าของตัวเองไหว)
	return setmetatable(t, { __index = base }) :: any
end

local function pickOutfit(opts: { [string]: any }, char: string): { [string]: any }
	local outfits = OUTFITS_BY[char] or OUTFITS
	if opts.outfit then
		for _, o in ipairs(outfits) do
			if o.name == opts.outfit then
				return o
			end
		end
	end
	local pool, total = {}, 0
	for _, o in ipairs(outfits) do
		-- กางร่ม / ถือแกลลอน / งานแห่: ไม่ใส่หมวกกันน็อก, วัยรุ่น: เฉพาะชุดสายแว้น
		local ok = (opts.teen == nil or (o.teen == true) == opts.teen) and not (o.helmet and (opts.umbrella or opts.noHelmet))
		if ok then
			table.insert(pool, o)
			total += o.weight
		end
	end
	-- ตัวละครที่ไม่มีชุดตามเงื่อนไข (เช่น เด็กไม่มีชุดสายแว้น): สุ่มจากทุกชุดของตัวนั้น
	if #pool == 0 then
		for _, o in ipairs(outfits) do
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
-- ไม่มีใครใส่หมวกกันน็อก (ผู้ใช้ 2026-11-05: เห็นหน้า/หัวลูกค้าชัดๆ จับผิดผีได้) ชุดที่มากับหมวก = ถอดหมวกแล้วใส่ผมแทน
local function isHelmet(n: string): boolean
	return string.sub(n, -7) == "_helmet" or string.sub(n, -6) == "_visor"
end

function HumanNPC.Dress(d: Model, opts: { [string]: any }): { [string]: any }
	if opts.noHat then
		-- ไม่ใส่หมวกทุกชนิด (คนขับรถยนต์): ไม่เอาชุดที่มากับหมวกกันน็อก และถอดงอบออก
		opts = table.clone(opts)
		opts.noHelmet = true
	end
	local char = opts.char or DEFAULT_CHAR
	local outfit = pickOutfit(opts, char)
	local hairs = HAIRS_BY[char] or HAIRS
	local hair = if opts.hair and table.find(hairs, opts.hair) then opts.hair else hairs[math.random(#hairs)]
	local skin = skinParts(char)
	for _, c in ipairs(d:GetChildren()) do
		if c:IsA("MeshPart") and c.Name ~= "Body" and c.Name ~= "BodyHead" then
			local n = c.Name
			local keep
			if string.sub(n, 1, 5) == "Skin_" then
				keep = not table.find(skin[n] or {}, outfit.name)
			elseif string.sub(n, 1, 6) == "Cloth_" or string.sub(n, 1, 5) == "Hair_" then
				keep = n == "Cloth_" .. outfit.name or string.sub(n, 1, #outfit.name + 7) == "Cloth_" .. outfit.name .. "_" or (hair ~= nil and n == "Hair_" .. hair)
				if keep and ((opts.noHat and isHat(n)) or isHelmet(n)) then
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
	d:SetAttribute("Char", char)
	d:SetAttribute("Outfit", outfit.name)
	d:SetAttribute("Hair", hair or "")
	return outfit
end

-- opts: outfit (ชื่อชุด), hair, teen (true = ชุดสายแว้นเท่านั้น / false = ไม่เอาชุดสายแว้น), umbrella, noHelmet,
--       dance (ชื่อท่าเต้นตอนแกว่ง เช่น "ramwong", "wan_bounce")
function HumanNPC.Build(opts: { [string]: any }): Model
	if not HumanNPC.Available(opts.char) then
		opts = table.clone(opts)
		opts.char = DEFAULT_CHAR
	end
	local char = opts.char or DEFAULT_CHAR
	local tpl = template(char) :: Model
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
		char = char,
	}
	-- ท่าอารมณ์ / หน้าตา / กะพริบตา (shared/HumanEmotes, client/HumanEmotesRunner)
	-- เฉพาะ human_base: ชุดภาพหน้า (HumanFaceSets) ทำบนผิวของ human_base ใส่ตัวอื่นแล้วหน้าเพี้ยน
	if char == DEFAULT_CHAR then
		game:GetService("CollectionService"):AddTag(m, "HumanEmote")
	end
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

-- ---------------------------------------------------------------- นั่งให้มือถึงแฮนด์ (ผู้ใช้ 2026-11-08: บางตัวแอ่น / มือไม่จับมอไซ)
-- วัดใน Studio (DevCommand): แฮนด์มอไซค์/ตุ๊กตุ๊กอยู่หน้าสะโพก ~2.6 studs แต่แขนยาวแค่ 1.7-1.9
--   -> ต้องเอื้อม 131-151% ของแขน IK ดึงแขนเหยียดตึงแล้วก็ยังไม่ถึง (ป้าแช่มแขนสั้นสุดห่างสุด)
--   ท่าของตัวเอง (build_anims ของแต่ละตัว) ต่างจากท่าที่ยืม human_base แค่ ~0.1 stud ไม่ใช่สาเหตุ
-- แก้: โน้มทั้งตัวไปหน้ารอบข้อสะโพก + เลื่อนไปหน้านิด จนหัวไหล่ห่างแฮนด์ไม่เกิน REACH ของความยาวแขน
--   (ขาไม่เพี้ยน: IK เท้าดึงเท้ากลับไปที่พักเท้าเอง)
-- หัวไหล่ซ้าย (กระดูก upper_arm.L) ตอนเล่นท่าขับ ในกรอบสะโพก (+X ขวา, +Y ขึ้น, -Z หน้า) วัดใน Studio 2026-11-08
local SHOULDER_POSED: { [string]: { [string]: Vector3 } } = {
	human_base = { ride_moto = Vector3.new(-0.62, 1.79, -0.28), drive_tuktuk = Vector3.new(-0.62, 1.82, -0.09), drive_car = Vector3.new(-0.62, 1.82, -0.06) },
	human_elder_male = { ride_moto = Vector3.new(-0.55, 1.53, -0.48), drive_tuktuk = Vector3.new(-0.55, 1.61, -0.27), drive_car = Vector3.new(-0.55, 1.60, -0.30) },
	human_elder_female = { ride_moto = Vector3.new(-0.47, 1.48, -0.31), drive_tuktuk = Vector3.new(-0.47, 1.52, -0.12), drive_car = Vector3.new(-0.47, 1.52, -0.14) },
}
local REACH = 0.97 -- ระยะหัวไหล่-แฮนด์ ไม่เกินเท่านี้ของแขน (ขี่มอไซค์แขนเกือบเหยียด งอนิดเดียว)
local MAX_LEAN = 24 -- องศา โน้มเพิ่มได้สูงสุด (เลื่อนไปหน้าก่อน โน้มแต่พอดี: ลุง ~12° หนุ่ม ~17° ป้าแช่มแขนสั้นสุด ~24°)
local MAX_SHIFT = 0.3 -- studs เลื่อนไปหน้าได้สูงสุด (มากกว่านี้ต้นขาจมตัวรถ)
local armLen: { [string]: number } = {}
local function armLength(char: string): number?
	if armLen[char] then
		return armLen[char]
	end
	local tpl = template(char)
	local a, f, h = tpl and bone(tpl, "upper_arm.L"), tpl and bone(tpl, "forearm.L"), tpl and bone(tpl, "hand.L")
	if not (a and f and h) then
		return nil
	end
	local n = (f.WorldPosition - a.WorldPosition).Magnitude + (h.WorldPosition - f.WorldPosition).Magnitude
	armLen[char] = n
	return n
end
-- คืนสะโพกใหม่ (โน้ม + เลื่อน) ที่ทำให้มือทั้งสองข้างถึงแฮนด์ ถ้าถึงอยู่แล้วคืนค่าเดิม
function HumanNPC.FitReach(char: string, clip: string, hip: CFrame, targets: { [string]: IKTarget }): (CFrame, number, number)
	local sh = SHOULDER_POSED[char] and SHOULDER_POSED[char][clip]
	local arm = armLength(char)
	if not (sh and arm) then
		return hip, 0, 0
	end
	local pairsList = {}
	for key, sx in pairs({ handL = 1, handR = -1 }) do
		local t = targets[key]
		if t then
			table.insert(pairsList, { Vector3.new(sh.X * sx, sh.Y, sh.Z), hip:PointToObjectSpace(t.pos) })
		end
	end
	if #pairsList == 0 then
		return hip, 0, 0
	end
	local best, bestCost, fallback, fallbackWorst = nil, math.huge, nil, math.huge
	for si = 0, math.floor(MAX_SHIFT / 0.05 + 0.5) do
		for th = 0, MAX_LEAN do
			local x = CFrame.new(0, 0, -si * 0.05) * CFrame.Angles(-math.rad(th), 0, 0)
			local worst = 0
			for _, pr in ipairs(pairsList) do
				worst = math.max(worst, (x:PointToWorldSpace(pr[1]) - pr[2]).Magnitude / arm)
			end
			local cost = si * 0.05 * 0.25 + math.rad(th) -- เลื่อนถูกกว่าโน้ม (โน้มมากดูหลังค่อม)
			if worst <= REACH and cost < bestCost then
				best, bestCost = { si * 0.05, th }, cost
			end
			if worst < fallbackWorst then
				fallback, fallbackWorst = { si * 0.05, th }, worst
			end
		end
	end
	local pick = best or fallback :: { number }
	return hip * CFrame.new(0, 0, -pick[1]) * CFrame.Angles(-math.rad(pick[2]), 0, 0), pick[1], pick[2]
end

function HumanNPC.SeatIn(vehicle: Model, hip: CFrame, clip: string, opts: { [string]: any }?, targets: { [string]: IKTarget }?): Model?
	local ch = (opts or {} :: any).char
	if not (template(ch) and animIds(ch)[clip]) then
		return nil
	end
	local o = table.clone(opts or {})
	o.noHelmet = if o.noHelmet == nil then false else o.noHelmet
	local w = HumanNPC.Build(o)
	local d = w:FindFirstChild("DriverNPC") :: Model
	local hb = bone(d, "hips")
	local hipRel = if hb then d:GetPivot():PointToObjectSpace(hb.WorldPosition) else Vector3.new(0, 3.1, 0)
	if targets then
		local fitted, shift, lean = HumanNPC.FitReach((rigs[w] and rigs[w].char) or DEFAULT_CHAR, clip, hip, targets)
		hip = fitted
		d:SetAttribute("SeatShift", shift) -- (ดูค่าใน Studio ตอนทดสอบ)
		d:SetAttribute("SeatLean", lean)
	end
	d:SetAttribute("SeatClip", clip) -- client/RiderMotion: มอไซค์ 2 ล้อ = เอาเท้าลงตอนจอด
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
		local ids = animIds(rig.char)
		local id = ids[clip]
		if not id or not animator:IsDescendantOf(workspace) then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local tr = animator:LoadAnimation(a)
		tr.Looped = true
		t[clip] = tr
		-- โหลดท่ายืน/เดินไว้ล่วงหน้าตั้งแต่ครั้งแรก: ท่าที่ยังโหลดไม่เสร็จเล่นไม่ออก ตัวจะกลับเป็นท่า A แวบหนึ่ง
		for _, c in ipairs({ "idle", "walk", "walk_skirt", "walk_base", "run_skirt" }) do
			if t[c] == nil and ids[c] then
				local pa = Instance.new("Animation")
				pa.AnimationId = ids[c]
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

-- เดินเร็วสุดที่ท่ายังดูเป็นธรรมชาติ (เท้าไม่ไถล) ของตัวนี้ (nil = ไม่จำกัด / ไม่ใช่คนแบบมีกระดูก)
--   คนแก่ใส่ผ้านุ่ง: ก้าวสั้นมาก สั่งเดิน 7 studs/วินาทีจะซอยเท้าถี่จนดูไม่ออกว่าเดิน -> Pedestrian.WalkTo เดินช้าลงเอง
function HumanNPC.PaceLimit(m: Model): number?
	local rig = rigs[m]
	if not rig or rig.seated then
		return nil
	end
	local nat = NATURAL[rig.char] or NATURAL.human_base
	local list = if rig.skirt then GAITS_SKIRT else GAITS
	local best = 0
	for _, c in ipairs(list) do
		best = math.max(best, nat[c] or 0)
	end
	return if best > 0 then best * 1.7 else nil
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
		local spd = speed or WALK_CLIP_SPEED
		local nat = NATURAL[rig.char] or NATURAL.human_base
		local list = if rig.skirt then GAITS_SKIRT else GAITS
		local clip, rate = list[#list], 1
		for _, c in ipairs(list) do
			local r = spd / (nat[c] or WALK_CLIP_SPEED)
			if r <= MAX_CLIP_RATE then
				clip, rate = c, r
				break
			end
			clip, rate = c, r
		end
		-- เปลี่ยนท่าบ่อยๆ ตอนความเร็วก้ำกึ่งดูกระตุก: ท่าเดิมยังใช้ได้ (ไม่เร่งเกิน 2.2) ใช้ต่อ
		local cur = rig.current
		if cur and cur ~= clip and table.find(list, cur) then
			local r = spd / (nat[cur] or WALK_CLIP_SPEED)
			if r >= 0.6 and r <= 2.2 then
				clip, rate = cur, r
			end
		end
		HumanNPC.Play(m, clip, math.clamp(rate, 0.5, 2.2))
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

-- ร่างผีของชาวบ้านแต่ละแบบ (แม่แบบใน ServerStorage.GhostTemplates กระดูก 52 ท่อนชุดเดียวกับ HumanTemplates)
-- ท่าของชาวบ้าน (เดิน ยืน ขับรถ) จึงเล่นบนร่างผีได้ตรงกันทุกท่อน
local GHOST_BODY: { [string]: { string } } = {
	human_base = { "ghost_funeral_man", "ghost_shroud" },
	human_female = { "ghost_funeral_woman", "ghost_mirror", "ghost_tani" },
	human_elder_male = { "ghost_funeral_elder_man" },
	human_elder_female = { "ghost_funeral_elder_woman" },
	human_child = { "ghost_child" },
}

local function ghostBody(char: string, d: Model): Model?
	local f = ServerStorage:FindFirstChild("GhostTemplates")
	local names = GHOST_BODY[char] or GHOST_BODY[DEFAULT_CHAR]
	local pool = {}
	for _, n in ipairs(names) do
		if f and f:FindFirstChild(n) then
			table.insert(pool, n)
		end
	end
	if #pool == 0 then
		return nil
	end
	local g = ((f :: Instance):FindFirstChild(pool[math.random(#pool)]) :: Model):Clone()
	local gRoot = g:FindFirstChild("RootPart") :: BasePart?
	local dRoot = d:FindFirstChild("RootPart") :: BasePart?
	if not (gRoot and dRoot) then
		g:Destroy()
		return nil
	end
	-- วางให้กระดูกรากทับกระดูกรากของตัวจริงพอดี (ท่าเดียวกัน = ทับกันทั้งตัว)
	g:PivotTo(dRoot.CFrame * gRoot.CFrame:ToObjectSpace(g:GetPivot()))
	for _, x in ipairs(g:GetDescendants()) do
		if x:IsA("BasePart") then
			x.Anchored = true
			x.CanCollide = false
			x.CanTouch = false
			x.CanQuery = false
		end
	end
	-- มือ/เท้าจับแฮนด์ / พวงมาลัย / ที่พักเท้าเหมือนตัวจริง: IK ชุดเดียวกัน ชี้ไปที่กระดูกของร่างผี
	local dac = d:FindFirstChildOfClass("AnimationController")
	local gac = g:FindFirstChildOfClass("AnimationController")
	if dac and gac then
		for _, ik in ipairs(dac:GetChildren()) do
			if ik:IsA("IKControl") and ik.ChainRoot and ik.EndEffector then
				local root, tip = bone(g, ik.ChainRoot.Name), bone(g, ik.EndEffector.Name)
				if root and tip then
					local c = ik:Clone()
					c.ChainRoot = root
					c.EndEffector = tip
					c.Parent = gac
				end
			end
		end
	end
	return g
end

-- ร่างผีซ้อน (เห็นเฉพาะตอนพนมมือ) เล่นท่าเดียวกับตัวจริง
--   kind = "ghost" (ร่างผีจริง) | "twist" (ร่างผี + หัวหันกลับ 180°) | "pale" (สำเนาตัวจริง ผิวซีดเขียว)
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
	-- ร่างผีจริง (ghost / twist): ผีจากแม่แบบผีที่กระดูกชุดเดียวกับชาวบ้าน (ServerStorage.GhostTemplates) ซ้อนทับตัวจริง
	-- ไม่มีแม่แบบผี = ใช้สำเนาตัวจริงแบบเดิม (twist = หัวหันกลับ, pale = ผิวซีด)
	local double = if kind == "ghost" or kind == "twist" then ghostBody(rig.char, d) else nil
	if double then
		-- พนมมือแล้วต้องรู้ทันทีว่าเป็นผี (ผู้ใช้ 2026-11-06: ร่างผีชุดขาวดูเหมือนคนธรรมดา สวดนานก็ไม่รู้ว่าผี)
		-- ผิวซีดเขียวแบบศพ ตัวโปร่งจางๆ แสงเย็นเรืองรอบตัว (ไม่มีขอบแดงเรือง: ผู้ใช้เอาออกแล้ว 2026-11-05)
		for _, c in ipairs(double:GetChildren()) do
			if c:IsA("MeshPart") then
				-- หัวหันกลับ (twist): ทึบทั้งตัว ไม่งั้นผมยาวด้านหลังกับหน้าที่หันกลับมองทะลุซ้อนกันดูเละ (ผู้ใช้ 2026-11-07)
				c.Transparency = if kind == "twist" then 0 else 0.22
				if string.sub(c.Name, 1, 4) == "Body" or string.sub(c.Name, 1, 5) == "Skin_" then
					local sa = c:FindFirstChildOfClass("SurfaceAppearance")
					if sa then
						pcall(function()
							(sa :: any).Color = Color3.fromRGB(150, 172, 160)
						end)
					else
						c.Color = Color3.fromRGB(150, 172, 160)
					end
				end
			end
		end
		local gRoot = double:FindFirstChild("RootPart") :: BasePart?
		if gRoot then
			local a = Instance.new("Attachment")
			a.Position = gRoot.CFrame:PointToObjectSpace(d:GetPivot().Position + Vector3.new(0, 3.2, 0))
			a.Parent = gRoot
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(170, 215, 200)
			l.Range = 9
			l.Brightness = 0.8
			l.Shadows = false
			l.Parent = a
		end
	end
	if not double then
		-- ต้อง Clone ทั้งโมเดลในครั้งเดียว: ประกอบใหม่จากชิ้นที่ Clone ทีละชิ้น ผิวจะไม่ผูกกับกระดูกของร่างใหม่ (ค้างท่า A-pose)
		double = d:Clone()
		for _, c in ipairs((double :: Model):GetChildren()) do
			if c.Name == "Head" or c.Name == "Torso" or c.Name == "GhostDouble" then
				c:Destroy()
			end
		end
	end
	assert(double)
	double.Name = "GhostDouble"
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
	if ac and not animator then
		animator = Instance.new("Animator")
		animator.Parent = ac
	end
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
