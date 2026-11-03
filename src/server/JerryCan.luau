--!strict
-- JerryCan.luau (ModuleScript ฝั่ง Server)
--   JerryCan.Build(parent, cf) -> Handle   ใส่แกลลอนลงใน parent ที่ cf (คืนชิ้นตัวถัง "Handle")
--   JerryCan.SetFull(container, full)      มีน้ำมัน = เห็นเปลือกน้ำมันชมพูแดง / เปล่า = ซ่อน
--   JerryCan.GRIP                          จุดที่มือกำ (กลางคานหูหิ้ว) เทียบจุดอ้างอิง
local ServerStorage = game:GetService("ServerStorage")

local JerryCan = {}
JerryCan.GRIP = Vector3.new(0, 0.79, 0.15)

local function propPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- แกลลอนน้ำมันพลาสติกขาวขุ่น จุดอ้างอิง = กลางตัวถัง (ใช้ร่วม: แกลลอนในร้าน/ในมือผู้เล่น server/CoreLoop + ลูกค้าเดินเท้า server/Pedestrian)
--   ตัวถังมุมมน ไหล่ลาดหน้า-หลังลงไปจรดขอบตัวถัง ฝาเกลียวขาวที่ไหล่หน้า หูหิ้วห่วงกลมเล็กบนไหล่หลัง
--   (กลางคานหูหิ้วอยู่ที่ (0, 0.79, 0.15) = จุดที่มือกำ) ขีดบอกปริมาตรด้านข้าง
--   ตัวถังรวมเป็นชิ้นเดียวด้วย CSG (ไม่มีรอยต่อระหว่างชิ้น): ไหล่ถูกตัด (Intersect) ให้พอดีมุมโค้ง ไม่ยื่นเป็นชายคา
--     Handle   = ตัวถังทั้งใบ + ไหล่ + หูหิ้ว (ภาพคราบต่อกันทั้งใบ)
--     CanFuel  = เปลือกบางชมพูแดงโปร่งแสงครอบตัวถังใต้ระดับน้ำมัน (~2/3) attribute CanFuelShell:
--                มีน้ำมัน = เห็นสีน้ำมันทะลุพลาสติก, เปล่า = มองไม่เห็น (setCanFull) น้ำมันไม่เต็มถึงบน
--   CSG ทำครั้งเดียวตอนสร้างแกลลอนแรก แล้ว Clone ต้นแบบ (ถ้า CSG ใช้ไม่ได้ ใช้ชิ้นส่วนแยกแทน)
--   ของเก่าใช้มานาน: พลาสติกขุ่นออกเหลือง + ภาพคราบ (Texture CAN_GRIME) ดินเกาะก้น คราบน้ำมันเก่าไหลจากฝา
--   ฝุ่นจับบนไหล่
--   ทรงเดียวกับ assets/models/JerryCan.fbx (tools/blender/jerry_can.py)
local CAN_WHITE = Color3.fromRGB(226, 220, 198)
local CAN_FULL = Color3.fromRGB(228, 112, 98)
-- ภาพคราบ (tools/studio/jerry_can_grime.py -> assets/models/jerry_can_grime/, ID ใน ids.json) แก้ภาพ = อัปโหลดทับ ID เดิม
local CAN_GRIME = {
	side = "rbxassetid://104313735955210",
	front = "rbxassetid://94519920328005",
	top = "rbxassetid://123228168339406",
}
local canTemplate: Model? = nil
local function buildCanTemplate(): Model
	local m = Instance.new("Model")
	m.Name = "_CanTemplate"
	m.Parent = ServerStorage -- CSG ต้องมีชิ้นอยู่ใน DataModel ระหว่างสร้าง
	local W, H, D = 0.6, 0.85, 0.9 -- กว้าง สูงตัวถัง ยาวหน้า-หลัง (หน้า = -Z ฝั่งฝา)
	local top, sh, r = H / 2, 0.2, 0.12 -- ไหล่สูง 0.2 เหนือตัวถัง, รัศมีมุม
	local FUEL = 0.66 -- ระดับน้ำมัน (สัดส่วนความสูงตัวถัง)
	local yFuel = -H / 2 + H * FUEL
	local up = CFrame.Angles(0, 0, math.rad(90))
	local function piece(name: string, size: Vector3, at: CFrame, shape: Enum.PartType?): Part
		return propPart(m, name, size, at, CAN_WHITE, nil, shape)
	end
	-- ทรงตัวถังมุมมน (กล่องไขว้ 2 + ทรงกระบอก 4 มุม) ระหว่าง y0..y1
	local function rounded(name: string, y0: number, y1: number, grow: number?): { BasePart }
		local h, cy = y1 - y0, (y0 + y1) / 2
		local g = grow or 0 -- ขยายออกรอบด้าน (เปลือกน้ำมัน)
		local w, d, rr = W + 2 * g, D + 2 * g, r + g
		local list: { BasePart } = {
			piece(name, Vector3.new(w, h, d - 2 * rr), CFrame.new(0, cy, 0)),
			piece(name, Vector3.new(w - 2 * rr, h, d), CFrame.new(0, cy, 0)),
		}
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(list, piece(name, Vector3.new(h, 2 * rr, 2 * rr), CFrame.new(sx * (w / 2 - rr), cy, sz * (d / 2 - rr)) * up, Enum.PartType.Cylinder))
			end
		end
		return list
	end
	-- ไหล่: แผ่นกลาง + ลิ่มลาดหน้า/หลังกว้างเต็มลงไปจรดขอบ (ตัดมุมทีหลัง)
	local sz0 = 0.13
	local shoulder: { BasePart } = { piece("CanShoulder", Vector3.new(W, sh, 2 * sz0), CFrame.new(0, top + sh / 2, 0)) }
	for _, zs in ipairs({ -1, 1 }) do
		local w = Instance.new("WedgePart")
		w.Name = "CanShoulder"
		w.Size = Vector3.new(W, sh, D / 2 - sz0)
		w.CFrame = CFrame.new(0, top + sh / 2, zs * (sz0 + w.Size.Z / 2)) * CFrame.Angles(0, if zs < 0 then 0 else math.pi, 0)
		w.Color = CAN_WHITE
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CastShadow = false
		w.Parent = m
		table.insert(shoulder, w)
	end
	local upper = rounded("Handle", -H / 2, top) -- ตัวถังทั้งใบ + ไหล่ + หูหิ้ว = ชิ้นเดียว (ภาพคราบต่อกันทั้งใบ)
	local fuel = rounded("CanFuel", -H / 2 - 0.004, yFuel, 0.006)
	-- หูหิ้วห่วงกลมชิ้นเดียวกับไหล่ (มือกำได้พอดี): เสากลมหน้า-หลังหยั่งลงในไหล่ + คานกลม + ลูกกลมที่หัวมุมให้โค้งต่อกัน
	local gy, gz, gr, gs = 0.79, 0.15, 0.035, 0.11 -- กลางคาน (จุดที่มือกำ), รัศมีเนื้อหูหิ้ว, ครึ่งช่วงเสา
	local postBot = top + 0.08
	for _, dz in ipairs({ -gs, gs }) do
		table.insert(upper, piece("Handle", Vector3.new(gy - postBot, 2 * gr, 2 * gr), CFrame.new(0, (gy + postBot) / 2, gz + dz) * up, Enum.PartType.Cylinder))
		table.insert(upper, piece("Handle", Vector3.one * 2 * gr, CFrame.new(0, gy, gz + dz), Enum.PartType.Ball))
	end
	table.insert(upper, piece("Handle", Vector3.new(2 * gs, 2 * gr, 2 * gr), CFrame.new(0, gy, gz) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder))
	local ok, err = pcall(function()
		local function union(list: { BasePart }, name: string): BasePart
			local rest = table.move(list, 2, #list, 1, {})
			local u = list[1]:UnionAsync(rest)
			for _, p in ipairs(list) do
				p:Destroy()
			end
			u.Name = name
			u.UsePartColor = true
			u.Color = CAN_WHITE
			u.Material = Enum.Material.SmoothPlastic
			pcall(function() -- เงามุมโค้งนุ่ม + กรอบชนแบบกล่อง (ตั้งได้เฉพาะตอนแก้ใน Studio — ตอนเล่นจริงข้าม)
				u.SmoothingAngle = 35
				u.CollisionFidelity = Enum.CollisionFidelity.Box
			end)
			u.Anchored = true
			u.CanCollide = false
			u.CastShadow = false
			u.Parent = m
			return u
		end
		-- ตัดไหล่ให้อยู่ในแนวมุมโค้งของตัวถัง (แท่งมุมมนสูงคลุมไหล่)
		local cut = union(rounded("Cut", top - 0.01, top + sh + 0.01), "Cut")
		local sh1 = union(shoulder, "Shoulder")
		local clipped = sh1:IntersectAsync({ cut })
		sh1:Destroy()
		cut:Destroy()
		clipped.Parent = m
		table.insert(upper, clipped)
		union(upper, "Handle")
		union(fuel, "CanFuel")
	end)
	if not ok then
		warn("[CoreLoop] แกลลอน: CSG ใช้ไม่ได้ ใช้ชิ้นส่วนแยกแทน", err)
	end
	-- เปลือกน้ำมัน: ชมพูแดงโปร่งแสงบางๆ ครอบตัวถังส่วนล่าง (เห็นคราบผ่าน) แกลลอนเปล่า = มองไม่เห็น (setCanFull)
	for _, d in ipairs(m:GetChildren()) do
		if d.Name == "CanFuel" and d:IsA("BasePart") then
			d.Color = CAN_FULL
			d.Transparency = 1
			d:SetAttribute("CanFuelShell", true)
		end
	end
	-- ภาพคราบ: ข้าง = ภาพเดียวตั้งแต่บนไหล่ถึงก้น, หน้า = คราบน้ำมันไหลจากฝาลงด้านลาดถึงก้น, บน = ฝุ่น
	-- ภาพคราบด้านข้างมีแถบหมองที่ขอบบนภาพ: ยืดภาพให้สูงกว่าตัวแกลลอน แล้วชิดขอบล่างภาพกับก้น
	-- แถบนั้นจะเลยพ้นบนไหล่ไป (ไม่เป็นชั้นเข้ม-สะอาด-ดิน) ส่วนบนไหล่/ด้านลาดใช้ภาพฝุ่นแบบจางลงให้กลืนกับด้านข้าง
	local SIDE_V, FRONT_V = 1.3, 1.2 -- ความสูงภาพ 1 แผ่น (studs) ตัวแกลลอนสูง H + sh = 1.05
	local function tex(part: Instance, face: Enum.NormalId, id: string, tileU: number, tileV: number, offU: number, offV: number, fade: number?)
		local t = Instance.new("Texture")
		t.Name = "CanGrime"
		t.Texture = id
		t.Face = face
		t.StudsPerTileU = tileU
		t.StudsPerTileV = tileV
		t.OffsetStudsU = offU
		t.OffsetStudsV = offV
		t.Transparency = fade or 0
		t.Parent = part
	end
	for _, d in ipairs(m:GetChildren()) do
		if d:IsA("BasePart") and d.Name ~= "CanFuel" then
			-- ชิดขอบล่างภาพกับก้นแกลลอน: v(y) = tile - (y + H/2)
			-- ชิ้น CSG (UnionOperation) นับภาพจากจุดกลางชิ้น ชิ้นธรรมดานับจากขอบบน/ขอบซ้ายของหน้า
			local csg = d:IsA("UnionOperation")
			local ref = if csg then d.Position.Y else d.Position.Y + d.Size.Y / 2
			local function v(tile: number): number
				return tile - (ref + H / 2)
			end
			local uSide, uFront = if csg then D / 2 else 0, if csg then W / 2 else 0
			tex(d, Enum.NormalId.Left, CAN_GRIME.side, D, SIDE_V, uSide, v(SIDE_V))
			tex(d, Enum.NormalId.Right, CAN_GRIME.side, D, SIDE_V, uSide, v(SIDE_V))
			tex(d, Enum.NormalId.Front, CAN_GRIME.front, W, FRONT_V, uFront, v(FRONT_V))
			tex(d, Enum.NormalId.Back, CAN_GRIME.side, W, SIDE_V, uFront, v(SIDE_V))
			tex(d, Enum.NormalId.Top, CAN_GRIME.top, W, D, uFront, if csg then D / 2 else 0, 0.45)
		end
	end
	-- ฝาเกลียวขาวที่ไหล่หน้า
	local capZ = -0.08
	piece("CanNeck", Vector3.new(0.06, 0.11, 0.11), CFrame.new(0, top + sh + 0.02, capZ) * up, Enum.PartType.Cylinder)
	piece("CanCap", Vector3.new(0.09, 0.15, 0.15), CFrame.new(0, top + sh + 0.08, capZ) * up, Enum.PartType.Cylinder)
	-- ขีดบอกปริมาตรด้านข้าง (+X)
	for i = 0, 3 do
		propPart(m, "CanMark" .. i, Vector3.new(0.01, 0.015, 0.12), CFrame.new(W / 2 + 0.005, -0.25 + i * 0.16, -0.2), Color3.fromRGB(160, 150, 138))
	end
	-- คราบน้ำมันรอบคอฝา + หูหิ้วมือจับจนหมอง
	local ring = propPart(m, "CanOilRing", Vector3.new(0.012, 0.2, 0.2), CFrame.new(0, top + sh + 0.002, capZ) * up, Color3.fromRGB(112, 66, 34), nil, Enum.PartType.Cylinder)
	ring.Transparency = 0.45
	local gg = propPart(m, "CanGripGrime", Vector3.new(0.15, 2 * gr + 0.006, 2 * gr + 0.006), CFrame.new(0, gy, gz) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(96, 78, 56), nil, Enum.PartType.Cylinder)
	gg.Transparency = 0.5
	m.Parent = nil
	return m
end

-- โมเดลนำเข้า ServerStorage.ImportedProps.JerryCan (assets/models/JerryCan.fbx: JerryCan + JerryCanFuel, pivot = กลางคานหูหิ้ว)
-- ถ้ามี ใช้แทนแกลลอนประกอบจากชิ้นส่วน (คราบวาดอยู่ใน texture แล้ว) ชิ้นตัวถังเปลี่ยนชื่อเป็น "Handle" ให้ Tool ใช้ได้
local function importedTemplate(): Model?
	local store = ServerStorage:FindFirstChild("ImportedProps")
	local m = store and store:FindFirstChild("JerryCan")
	return if m and m:IsA("Model") and m:FindFirstChild("JerryCan", true) then m else nil
end

local function buildImported(tmpl: Model, parent: Instance, cf: CFrame): Part
	local grip = cf * CFrame.new(JerryCan.GRIP) -- cf = กลางตัวถัง (เหมือนแกลลอนประกอบ) -> จุดกำ = pivot ของโมเดลนำเข้า
	local piv = tmpl:GetPivot()
	local body: Part? = nil
	for _, d in ipairs(tmpl:GetDescendants()) do
		if d:IsA("BasePart") then
			local c = d:Clone()
			for _, ch in ipairs(c:GetChildren()) do
				if ch:IsA("BasePart") then
					ch:Destroy()
				end
			end
			c.CFrame = grip * piv:ToObjectSpace(d.CFrame)
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = false
			if d.Name == "JerryCanFuel" then
				c.Name = "CanFuel"
				c.Color = CAN_FULL
				c.Material = Enum.Material.SmoothPlastic
				c.TextureID = ""
				c.Transparency = 1
				c:SetAttribute("CanFuelShell", true)
			else
				c.Name = "Handle"
				body = c :: any
			end
			c.Parent = parent
		end
	end
	return body :: Part
end

function JerryCan.Build(parent: Instance, cf: CFrame): Part
	local tmpl = importedTemplate()
	if tmpl then
		return buildImported(tmpl, parent, cf)
	end
	if not canTemplate then
		canTemplate = buildCanTemplate()
	end
	local body: Part? = nil
	for _, d in ipairs((canTemplate :: Model):GetChildren()) do
		local c = d:Clone()
		if c:IsA("BasePart") then
			c.CFrame = cf * d.CFrame
		end
		c.Parent = parent
		if c.Name == "Handle" then
			body = c :: any
		end
	end
	return body :: Part
end

-- color = สีน้ำมันในแกลลอน (ไม่ใส่ = ชมพูแดงเบนซิน, ดีเซลส่งสีเขียวมา)
function JerryCan.SetFull(container: Instance, full: boolean, color: Color3?)
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("CanFuelShell") then
			d.Transparency = if full then 0.45 else 1
			d.Color = color or CAN_FULL
		end
	end
end

return JerryCan
