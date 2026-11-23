--!strict
-- PassStallBuilder.luau — Lobby: สร้างแผงขาย Game Pass (โต๊ะ ป้าย ของ 4 ชิ้น ปุ่มซื้อ) ใช้ทั้งตอนเล่น (lobby/server/PassShop)
--   และในโหมด edit (DevCommand) ให้ผู้พัฒนาเห็นและลากย้ายได้ (ผู้ใช้ 2026-11-23)
--   Model "PassStall" ใน Workspace มีชิ้นล่องหน StallBase (PrimaryPart) = ตำแหน่ง/ทิศของแผง
--   ลากย้ายทั้ง Model ใน Studio แล้ว Save: ตอนเล่นสร้างแผงใหม่ทับที่ตำแหน่งนั้นเสมอ (ข้อความตามภาษา + ปุ่มซื้อ)
--   ไม่มี StallBase = วางหน้ารถเข็นขายของคันหลัก (ShopCart_Main) เหมือนเดิม
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any

local Builder = {}

local function ui(key: string): any
	return LanguageModule.UI[key]
end


local function bil(label: TextLabel, key: string)
	local e = ui(key)
	Bilingual.Text(label, e.th, e.en, { id = e.id, pt = e.pt, es = e.es })
end

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, key: string, color: Color3, font: Font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.86)
	t.Position = UDim2.fromScale(0.04, 0.07)
	t.FontFace = font
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = parent
	bil(t, key)
end

local function board(name: string, size: Vector3, cf: CFrame, key: string, parent: Instance, bgColor: Color3, textColor: Color3, stroke: Color3)
	local b = part({ Name = name, Size = size, CFrame = cf, Color = bgColor, Material = Enum.Material.Wood }, parent)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 90
	sg.LightInfluence = 0.3
	sg.Brightness = 1.3
	sg.Parent = b
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = bgColor
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local st = Instance.new("UIStroke")
	st.Color = stroke
	st.Thickness = 5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = bg
	label(bg, key, textColor, Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold))
	return b
end

local WOOD = Color3.fromRGB(92, 64, 42)
local CLOTH = Color3.fromRGB(150, 24, 30)
local GOLD = Color3.fromRGB(214, 170, 60)
local TOP_Y = 3.1

-- ---------------------------------------------------------------- ป้ายราคา (ผู้ใช้ 2026-11-23: ทำให้ดูดีขึ้น)
-- ป้ายไม้แขวนหน้าผ้าคลุมโต๊ะ (ไม่บังของบนโต๊ะ) · ข้อความ ...Sign แยกเป็น ชื่อ / คำอธิบาย / "ได้ตลอดไป" / ราคา
--   ...Sign ทุกภาษา = "ชื่อ\nคำอธิบาย\nได้ตลอดไป · ⏣ราคา"
local LANGS = { "th", "en", "id", "pt", "es" }
local function signParts(key: string): { [string]: { [string]: string } }
	local e = ui(key)
	local out = { name = {}, desc = {}, forever = {}, price = {} }
	for _, lang in ipairs(LANGS) do
		local s = e[lang] or e.en
		local lines = string.split(s, "\n")
		local foot = lines[3] or ""
		local cut = string.find(foot, " · ", 1, true)
		out.name[lang] = lines[1] or s
		out.desc[lang] = lines[2] or ""
		out.forever[lang] = if cut then string.sub(foot, 1, cut - 1) else ""
		out.price[lang] = if cut then string.sub(foot, cut + #" · ") else foot
	end
	return out
end

local function bilRaw(t: TextLabel, v: { [string]: string })
	Bilingual.Text(t, v.th, v.en, { id = v.id, pt = v.pt, es = v.es })
end

local function cardText(parent: Instance, v: { [string]: string }, pos: UDim2, size: UDim2, color: Color3, weight: Enum.FontWeight, maxSize: number, xAlign: Enum.TextXAlignment?)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", weight)
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextXAlignment = xAlign or Enum.TextXAlignment.Center
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = t
	t.Parent = parent
	bilRaw(t, v)
	return t
end

local function corner(parent: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = parent
end

local function priceCard(cf: CFrame, key: string, parent: Instance)
	local W, H = 2.85, 1.45
	local card = part({ Name = "PriceCard", Size = Vector3.new(W, H, 0.08), CFrame = cf, Color = Color3.fromRGB(60, 36, 22), Material = Enum.Material.Wood }, parent)
	-- หมุดทองสองตัวที่มุมบน (ห้อยกับขอบโต๊ะ)
	for _, x in ipairs({ -W / 2 + 0.25, W / 2 - 0.25 }) do
		part({ Name = "Pin", Shape = Enum.PartType.Ball, Size = Vector3.new(0.13, 0.13, 0.13), CFrame = cf * CFrame.new(x, H / 2 - 0.12, -0.06), Color = GOLD, Material = Enum.Material.Metal }, parent)
	end
	local v = signParts(key)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 140
	sg.LightInfluence = 0.15
	sg.Brightness = 1.15
	sg.Parent = card
	-- กรอบไม้เข้ม + กระดาษครีมด้านใน
	local paper = Instance.new("Frame")
	paper.Size = UDim2.new(1, -14, 1, -14)
	paper.Position = UDim2.fromOffset(7, 7)
	paper.BackgroundColor3 = Color3.fromRGB(248, 238, 214)
	paper.BorderSizePixel = 0
	paper.Parent = sg
	corner(paper, 10)
	local st = Instance.new("UIStroke")
	st.Color = GOLD
	st.Thickness = 3
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = paper
	-- แถบชื่อสีแดงด้านบน
	local head = Instance.new("Frame")
	head.Size = UDim2.new(1, 0, 0.34, 0)
	head.BackgroundColor3 = Color3.fromRGB(132, 22, 28)
	head.BorderSizePixel = 0
	head.Parent = paper
	corner(head, 10)
	local fill = Instance.new("Frame") -- ปิดมุมโค้งด้านล่างของแถบ ให้ต่อกับกระดาษตรงๆ
	fill.Size = UDim2.new(1, 0, 0, 12)
	fill.Position = UDim2.new(0, 0, 1, -12)
	fill.BackgroundColor3 = head.BackgroundColor3
	fill.BorderSizePixel = 0
	fill.Parent = head
	cardText(head, v.name, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.8), Color3.fromRGB(255, 226, 150), Enum.FontWeight.Heavy, 64)
	-- คำอธิบาย
	cardText(paper, v.desc, UDim2.fromScale(0.05, 0.36), UDim2.fromScale(0.9, 0.34), Color3.fromRGB(74, 44, 30), Enum.FontWeight.SemiBold, 40)
	-- เส้นประคั่น
	local line = Instance.new("Frame")
	line.Size = UDim2.new(0.88, 0, 0, 2)
	line.Position = UDim2.fromScale(0.06, 0.71)
	line.BackgroundColor3 = Color3.fromRGB(205, 180, 130)
	line.BorderSizePixel = 0
	line.Parent = paper
	-- "ได้ตลอดไป" ซ้าย · ราคาในเม็ดทองขวา
	cardText(paper, v.forever, UDim2.fromScale(0.06, 0.75), UDim2.fromScale(0.5, 0.2), Color3.fromRGB(120, 92, 64), Enum.FontWeight.SemiBold, 32, Enum.TextXAlignment.Left)
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(0.34, 0.21)
	pill.Position = UDim2.fromScale(0.6, 0.745)
	pill.BackgroundColor3 = Color3.fromRGB(236, 188, 70)
	pill.BorderSizePixel = 0
	pill.Parent = paper
	corner(pill, 30)
	local ps = Instance.new("UIStroke")
	ps.Color = Color3.fromRGB(150, 100, 26)
	ps.Thickness = 2
	ps.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ps.Parent = pill
	cardText(pill, v.price, UDim2.fromScale(0.08, 0.08), UDim2.fromScale(0.84, 0.84), Color3.fromRGB(60, 32, 12), Enum.FontWeight.Heavy, 46)
	return card
end

-- ---------------------------------------------------------------- ของบนโต๊ะ
-- โมเดล Blender (tools/blender/pass_stall_items.py, ผู้ใช้ 2026-11-23): แม่แบบ ServerStorage.PassStallItems ใน Lobby
--   (Import 3D จาก assets/models/PassStallItems/upload/PassStallItems.fbx) · texture ชิ้นละ 256 px โหลดเบา
--   ขนาด/กึ่งกลาง (studs, Roblox) จาก log BBOX ของสคริปต์ เทียบ origin = พื้นใต้กึ่งกลางของ · ตั้ง Size เองทุกชิ้น
--   ไม่มีแม่แบบ = ใช้ของที่ประกอบจาก Part แบบเดิม
local MESH_ITEMS: { [string]: { size: Vector3, center: Vector3 } } = {
	PassGhostBook = { size = Vector3.new(1.466, 0.380, 1.227), center = Vector3.new(0.050, 0.190, -0.067) },
	PassSandals = { size = Vector3.new(1.367, 0.268, 1.144), center = Vector3.new(0, 0.134, 0) },
	PassPrayerBeads = { size = Vector3.new(1.889, 0.424, 1.557), center = Vector3.new(0, 0.212, 0) },
}
local INCENSE_CUP = Vector3.new(-0.56, 0.30, 0.40) -- ปากถ้วยธูปบนเบาะ (เทียบ origin ของ PassPrayerBeads)

local function meshItem(name: string, at: CFrame, scale: number, parent: Instance): boolean
	local ok, ss = pcall(function()
		return game:GetService("ServerStorage")
	end)
	local tpl = ok and ss and ss:FindFirstChild("PassStallItems")
	local src = tpl and tpl:FindFirstChild(name, true)
	local info = MESH_ITEMS[name]
	if not (src and src:IsA("BasePart") and info) then
		return false
	end
	local p = src:Clone()
	for _, ch in ipairs(p:GetChildren()) do
		if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") then
			ch:Destroy()
		end
	end
	p.Name = name
	p.Size = info.size * scale
	p.CFrame = at * CFrame.new(info.center * scale)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Parent = parent
	return true
end

local function elephantFlashlight(cf: CFrame, parent: Instance)
	-- โมเดลจริงจาก Blender (แม่แบบ ServerStorage.ElephantFlashlight ใน Lobby) ตั้งบนโต๊ะ เลนส์หันหาลูกค้า เอียงนิดให้เห็นด้านข้าง ไม่เปิดไฟ
	local SCALE = 1.5
	local shown = IDS.PlaceElephant(cf * CFrame.new(0, IDS.ELEPHANT_HALF_HEIGHT * SCALE, 0.1) * CFrame.Angles(0, math.rad(28), 0), SCALE, parent)
	if shown then
		for name, p in pairs(shown) do
			p.Anchored = true
			if name == "ElephantSidePanel" then
				p.Material = Enum.Material.SmoothPlastic
				p.Color = Color3.fromRGB(150, 152, 158)
			end
		end
		return
	end
	-- ไม่มีแม่แบบ: ไฟฉายประกอบจาก Part แบบเดิม
	local RED = Color3.fromRGB(168, 28, 24)
	local axis = cf * CFrame.new(0, 0.36, 0)
	part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 0.5, 0.5), CFrame = axis * CFrame.new(-0.2, 0, 0), Color = RED, Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.53, 0.53), CFrame = axis * CFrame.new(0.25, 0, 0), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.65, 0.65), CFrame = axis * CFrame.new(0.66, 0, 0), Color = RED, Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "Head", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.85, 0.85), CFrame = axis * CFrame.new(0.95, 0, 0), Color = Color3.fromRGB(190, 190, 185), Material = Enum.Material.Metal }, parent)
	local lens = part({ Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.72, 0.72), CFrame = axis * CFrame.new(1.16, 0, 0), Color = Color3.fromRGB(255, 236, 170), Material = Enum.Material.Neon }, parent)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Right
	beam.Brightness = 1.5
	beam.Range = 10
	beam.Angle = 40
	beam.Color = Color3.fromRGB(255, 240, 200)
	beam.Parent = lens
end

local function incenseStick(base: CFrame, parent: Instance)
	local stick = part({ Name = "Incense", Size = Vector3.new(0.05, 0.9, 0.05), CFrame = base * CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(6)), Color = Color3.fromRGB(170, 60, 40), Material = Enum.Material.Wood }, parent)
	local tip = part({ Name = "IncenseTip", Size = Vector3.new(0.07, 0.07, 0.07), CFrame = stick.CFrame * CFrame.new(0, 0.46, 0), Color = Color3.fromRGB(255, 90, 30), Material = Enum.Material.Neon }, parent)
	local smoke = Instance.new("Smoke")
	smoke.Size = 0.2
	smoke.RiseVelocity = 1.2
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(220, 220, 220)
	smoke.Parent = tip
end

local function prayerBeads(cf: CFrame, parent: Instance)
	local at = cf * CFrame.Angles(0, math.rad(-6), 0)
	if meshItem("PassPrayerBeads", at, 1, parent) then
		incenseStick(at * CFrame.new(INCENSE_CUP), parent)
		return
	end
	part({ Name = "Cushion", Size = Vector3.new(1.7, 0.22, 1.4), CFrame = cf * CFrame.new(0, 0.11, 0), Color = Color3.fromRGB(170, 30, 36), Material = Enum.Material.Fabric }, parent)
	local center = cf * CFrame.new(0, 0.3, 0)
	local n = 22
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		part({ Name = "Bead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.17, 0.17, 0.17), CFrame = center * CFrame.new(math.cos(a) * 0.55, 0, math.sin(a) * 0.45), Color = Color3.fromRGB(110, 62, 30), Material = Enum.Material.Wood }, parent)
	end
	part({ Name = "GuruBead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), CFrame = center * CFrame.new(0, 0, -0.5), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "Tassel", Size = Vector3.new(0.12, 0.05, 0.4), CFrame = center * CFrame.new(0, -0.02, -0.75), Color = GOLD, Material = Enum.Material.Fabric }, parent)
	-- ธูปเล็กๆ ปักข้าง ให้รู้ว่าเกี่ยวกับการสวด
	local stick = part({ Name = "Incense", Size = Vector3.new(0.05, 0.9, 0.05), CFrame = cf * CFrame.new(0.65, 0.65, 0.45), Color = Color3.fromRGB(170, 60, 40), Material = Enum.Material.Wood }, parent)
	local tip = part({ Name = "IncenseTip", Size = Vector3.new(0.07, 0.07, 0.07), CFrame = stick.CFrame * CFrame.new(0, 0.46, 0), Color = Color3.fromRGB(255, 90, 30), Material = Enum.Material.Neon }, parent)
	local smoke = Instance.new("Smoke")
	smoke.Size = 0.2
	smoke.RiseVelocity = 1.2
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(220, 220, 220)
	smoke.Parent = tip
end

local function sandals(cf: CFrame, parent: Instance)
	if meshItem("PassSandals", cf * CFrame.Angles(0, math.rad(8), 0), 1.15, parent) then
		return
	end
	-- สีน้ำตาลไม้ + สายแดง + ปีกทองเล็กๆ ข้างสาย (ไม่ใช้ขาว-น้ำเงินแบบรองเท้าแตะยี่ห้อดัง)
	local SOLE = Color3.fromRGB(120, 78, 44)
	local STRAP = Color3.fromRGB(176, 34, 30)
	local WING = Color3.fromRGB(232, 196, 90)
	for i, side in ipairs({ -0.38, 0.38 }) do
		local s = cf * CFrame.new(side, 0, 0) * CFrame.Angles(0, math.rad(if i == 1 then 8 else -8), 0)
		part({ Name = "Sole", Size = Vector3.new(0.55, 0.14, 1.35), CFrame = s * CFrame.new(0, 0.07, 0), Color = SOLE, Material = Enum.Material.Rubber }, parent)
		part({ Name = "Bottom", Size = Vector3.new(0.56, 0.06, 1.36), CFrame = s * CFrame.new(0, 0.02, 0), Color = Color3.fromRGB(70, 44, 24), Material = Enum.Material.Rubber }, parent)
		local post = s * CFrame.new(0, 0.14, -0.38)
		part({ Name = "ToePost", Size = Vector3.new(0.06, 0.12, 0.06), CFrame = post * CFrame.new(0, 0.06, 0), Color = STRAP, Material = Enum.Material.Rubber }, parent)
		for _, dir in ipairs({ -1, 1 }) do
			local mid = post * CFrame.new(dir * 0.14, 0.1, 0.22)
			part({ Name = "Strap", Size = Vector3.new(0.07, 0.07, 0.55), CFrame = mid * CFrame.Angles(math.rad(-12), math.rad(dir * 28), 0), Color = STRAP, Material = Enum.Material.Rubber }, parent)
		end
		-- ปีกเล็กๆ กางออกข้างสายทั้งสองฝั่ง (3 ขนต่อข้าง)
		for _, dir in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local w = s * CFrame.new(dir * (0.36 + k * 0.05), 0.24 + k * 0.05, 0.05 + k * 0.1) * CFrame.Angles(math.rad(-20 - k * 12), 0, math.rad(dir * (35 + k * 10)))
				part({ Name = "Feather", Size = Vector3.new(0.05, 0.36 - k * 0.07, 0.14), CFrame = w, Color = WING, Material = Enum.Material.Metal }, parent)
			end
		end
	end
end

-- สมุดหมอผี: สมุดปกหนังดำมุมทอง วางบนผ้ายันต์แดง มีเทียนเล่มเล็ก
local function ghostBook(cf: CFrame, parent: Instance)
	if meshItem("PassGhostBook", cf * CFrame.new(-0.05, 0, 0) * CFrame.Angles(0, math.rad(-14), 0), 1.1, parent) then
		return
	end
	part({ Name = "Cloth", Size = Vector3.new(1.9, 0.04, 1.5), CFrame = cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, math.rad(6), 0), Color = Color3.fromRGB(160, 28, 26), Material = Enum.Material.Fabric }, parent)
	local book = cf * CFrame.new(-0.1, 0, 0) * CFrame.Angles(0, math.rad(-12), 0)
	part({ Name = "Pages", Size = Vector3.new(1.15, 0.24, 1.5), CFrame = book * CFrame.new(0, 0.16, 0), Color = Color3.fromRGB(214, 196, 150), Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "CoverBottom", Size = Vector3.new(1.25, 0.05, 1.6), CFrame = book * CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(26, 20, 18), Material = Enum.Material.Leather }, parent)
	part({ Name = "CoverTop", Size = Vector3.new(1.25, 0.05, 1.6), CFrame = book * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(26, 20, 18), Material = Enum.Material.Leather }, parent)
	part({ Name = "Spine", Size = Vector3.new(0.08, 0.3, 1.6), CFrame = book * CFrame.new(-0.62, 0.17, 0), Color = Color3.fromRGB(20, 16, 14), Material = Enum.Material.Leather }, parent)
	for _, z in ipairs({ -0.7, 0.7 }) do
		part({ Name = "Corner", Size = Vector3.new(0.22, 0.06, 0.16), CFrame = book * CFrame.new(0.52, 0.32, z), Color = GOLD, Material = Enum.Material.Metal }, parent)
	end
	-- ยันต์บนปก (วงทอง + จุดแดงเรือง)
	part({ Name = "Seal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 0.62, 0.62), CFrame = book * CFrame.new(0.05, 0.33, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "SealCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.035, 0.3, 0.3), CFrame = book * CFrame.new(0.05, 0.335, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 30, 24), Material = Enum.Material.Neon }, parent)
	local candle = part({ Name = "Candle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.16, 0.16), CFrame = cf * CFrame.new(0.72, 0.27, 0.48) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(236, 228, 208), Material = Enum.Material.SmoothPlastic }, parent)
	local flame = part({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.09, 0.14, 0.09), CFrame = candle.CFrame * CFrame.new(0.3, 0, 0), Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Neon }, parent)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 150, 70)
	l.Brightness = 0.8
	l.Range = 5
	l.Parent = flame
end

type Item = { attr: string, passId: number, sign: string, name: string, buy: string?, build: (CFrame, Instance) -> () }
local ITEMS: { Item } = {
	{ attr = "ElephantLight", passId = IDS.ElephantPassId, sign = "ElephantSign", name = "ElephantName", build = elephantFlashlight },
	{ attr = "FastPrayer", passId = IDS.FastPrayPassId, sign = "FastPraySign", name = "FastPrayName", build = prayerBeads },
	{ attr = "WingSandals", passId = IDS.SandalsPassId, sign = "SandalsSign", name = "SandalsName", build = sandals },
	{ attr = "GhostBook", passId = IDS.GhostBookPassId, sign = "GhostBookSign", name = "GhostBookName", buy = "BuyGhostBook", build = ghostBook },
}
Builder.ITEMS = ITEMS

-- สร้าง (หรือสร้างใหม่) ทั้งแผง คืน { ปุ่มซื้อ -> ของ }
function Builder.Build(): { [ProximityPrompt]: Item }
	-- ---------------------------------------------------------------- ที่ตั้ง: หน้ารถเข็นขายของคันหลัก หันไปทางลานวัด
	local lobby = workspace:WaitForChild("TempleLobby", 30)
	local cart = lobby and lobby:WaitForChild("ShopCart_Main", 10) :: Model?
	local base: CFrame
	if cart then
		local pv = cart:GetPivot()
		-- หน้ารถเข็น (ฝั่งป้าย) = -LookVector ของ pivot
		local front = -pv.LookVector
		local at = Vector3.new(pv.X, 0.1, pv.Z) + front * 5.5
		base = CFrame.lookAt(at, at + front)
	else
		base = CFrame.lookAt(Vector3.new(14, 0.1, 78.5), Vector3.new(14, 0.1, 78.5) + Vector3.new(-0.707, 0, -0.707))
	end
	local folder = workspace:FindFirstChild("PassStall")
	if folder and not folder:IsA("Model") then
		folder:Destroy() -- Folder รุ่นเก่า (สร้างตอนเล่น)
		folder = nil
	end
	if not folder then
		folder = Instance.new("Model")
		folder.Name = "PassStall"
		folder.Parent = workspace
	end
	local stall = folder :: Model
	local anchorBase = stall:FindFirstChild("StallBase")
	if anchorBase and anchorBase:IsA("BasePart") then
		base = anchorBase.CFrame -- ผู้พัฒนาลากย้ายแผงไว้: ใช้ตำแหน่งนั้น
	else
		local b = Instance.new("Part")
		b.Name = "StallBase"
		b.Size = Vector3.new(13.4, 0.2, 2.8)
		b.CFrame = base
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Transparency = 1
		b.Parent = stall
		anchorBase = b
	end
	for _, c in ipairs(stall:GetChildren()) do
		if c ~= anchorBase then
			c:Destroy()
		end
	end
	stall.PrimaryPart = anchorBase :: BasePart

	part({ Name = "TableTop", Size = Vector3.new(13.4, 0.3, 2.8), CFrame = base * CFrame.new(0, TOP_Y - 0.15, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = true }, stall)
	part({ Name = "TableCloth", Size = Vector3.new(13.5, 1.6, 0.06), CFrame = base * CFrame.new(0, TOP_Y - 0.9, -1.42), Color = CLOTH, Material = Enum.Material.Fabric }, stall)
	part({ Name = "ClothTrim", Size = Vector3.new(13.5, 0.14, 0.08), CFrame = base * CFrame.new(0, TOP_Y - 0.12, -1.43), Color = GOLD, Material = Enum.Material.Metal }, stall)
	for _, x in ipairs({ -6.4, 6.4 }) do
		for _, z in ipairs({ -1.2, 1.2 }) do
			part({ Name = "Leg", Size = Vector3.new(0.3, TOP_Y - 0.3, 0.3), CFrame = base * CFrame.new(x, (TOP_Y - 0.3) / 2, z), Color = WOOD, Material = Enum.Material.Wood, CanCollide = true }, stall)
		end
	end
	-- ป้ายหัวแผงด้านหลัง
	part({ Name = "PostL", Size = Vector3.new(0.25, 4.2, 0.25), CFrame = base * CFrame.new(-6.4, TOP_Y + 2.1, 1.25), Color = WOOD, Material = Enum.Material.Wood }, stall)
	part({ Name = "PostR", Size = Vector3.new(0.25, 4.2, 0.25), CFrame = base * CFrame.new(6.4, TOP_Y + 2.1, 1.25), Color = WOOD, Material = Enum.Material.Wood }, stall)
	board("TitleBoard", Vector3.new(12.6, 1.3, 0.12), base * CFrame.new(0, TOP_Y + 3.6, 1.25), "PassStallTitle", stall, Color3.fromRGB(40, 22, 14), Color3.fromRGB(245, 214, 120), GOLD)
	local lamp = part({ Name = "StallLamp", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = base * CFrame.new(0, TOP_Y + 4.5, 0.6), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon }, stall)
	do
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 210, 150)
		l.Brightness = 1.6
		l.Range = 14
		l.Shadows = false
		l.Parent = lamp
	end

	local prompts: { [ProximityPrompt]: Item } = {}
	for i, item in ipairs(ITEMS) do
		local x = (i - (#ITEMS + 1) / 2) * 3.25
		local spot = base * CFrame.new(x, TOP_Y, 0.15)
		local m = Instance.new("Model")
		m.Name = "Pass_" .. item.attr
		m.Parent = stall
		item.build(spot, m)
		-- ป้ายราคาแขวนหน้าผ้าคลุมโต๊ะ ใต้ของชิ้นนั้น (เอียงหน้าขึ้นนิดให้อ่านจากระดับสายตา)
		priceCard(base * CFrame.new(x, TOP_Y - 0.78, -1.62) * CFrame.Angles(math.rad(10), 0, 0), item.sign, m)
		-- จุดติดปุ่มกด (มองไม่เห็น)
		local anchor = part({ Name = "PromptAnchor", Size = Vector3.new(2.4, 1.2, 1.6), CFrame = spot * CFrame.new(0, 0.6, 0), Transparency = 1, CanQuery = false }, m)
		local pr = Instance.new("ProximityPrompt")
		pr.Name = "BuyPassPrompt"
		pr.HoldDuration = 0
		pr.MaxActivationDistance = 8
		pr.RequiresLineOfSight = false
		pr:SetAttribute("PassAttr", item.attr)
		pr.Parent = anchor
		local buy, nm = ui(item.buy or "BuyElephant"), ui(item.name)
		Bilingual.Prompt(pr, buy.th, buy.en, nm.th, nm.en, {
			id = { buy.id, nm.id },
			pt = { buy.pt, nm.pt },
			es = { buy.es, nm.es },
		})
		prompts[pr] = item
	end
	return prompts
end

return Builder
