-- MapBuilder.luau
-- สร้างและตกแต่งฉาก 3D แบบละเอียด (Detailed Procedural Map) ของ "ปั๊มหลอด & เพิงปะยางท้ายทุ่ง"
-- รันได้ทั้งตอนกด Play (F5) หรือรันใน Command Bar: require(game.ReplicatedStorage.Shared.MapBuilder).Build()

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local StarterPack = game:GetService("StarterPack")

local MapBuilder = {}

-- ป้ายชื่อลอยขนาดกะทัดรัด (สามารถตั้ง SHOW_LABELS = false ได้ถ้าต้องการปิดป้ายทั้งหมด)
MapBuilder.SHOW_LABELS = true

local function addLabel(parent: Instance, titleText: string, color: Color3?)
	local existing = parent:FindFirstChild("ZoneLabel")
	if existing then
		existing:Destroy()
	end
	if not MapBuilder.SHOW_LABELS then
		return
	end

	local bg = Instance.new("BillboardGui")
	bg.Name = "ZoneLabel"
	bg.Size = UDim2.new(0, 185, 0, 38)
	bg.StudsOffset = Vector3.new(0, 3.2, 0)
	bg.AlwaysOnTop = false
	bg.MaxDistance = 65
	bg.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 0.35
	lbl.BackgroundColor3 = Color3.fromRGB(10, 15, 13)
	lbl.BorderSizePixel = 0
	lbl.TextColor3 = color or Color3.fromRGB(255, 195, 75)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextWrapped = true
	lbl.Text = titleText
	lbl.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = lbl
end

local function createPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ฟังก์ชันสร้างต้นกล้วยตานีแบบละเอียด (ลำต้น + ใบแผ่ 6 แฉก + เครือกล้วย & ปลีกล้วยสีแดงเข้ม)
local function buildDetailedBananaTree(parent: Instance, basePos: Vector3, scale: number, index: number): Model
	local tree = Instance.new("Model")
	tree.Name = "BananaTree_" .. index
	tree.Parent = parent

	local height = 9.5 * scale
	local trunk = createPart(
		"Trunk",
		Vector3.new(1.3 * scale, height, 1.3 * scale),
		CFrame.new(basePos + Vector3.new(0, height / 2, 0)),
		Color3.fromRGB(58, 102, 44),
		Enum.Material.Grass,
		tree
	)
	tree.PrimaryPart = trunk

	-- ใบกล้วย 6 แฉกโค้งออกรอบทิศ
	local topPos = basePos + Vector3.new(0, height - 0.4, 0)
	for a = 1, 6 do
		local angle = math.rad((a * 60) + (index * 17))
		local leafCF = CFrame.new(topPos) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(-22), 0, 0) * CFrame.new(0, 0, -3.2 * scale)
		createPart(
			"BananaLeaf_" .. a,
			Vector3.new(1.8 * scale, 0.15, 5.8 * scale),
			leafCF,
			Color3.fromRGB(44, 92, 34),
			Enum.Material.Grass,
			tree
		)
	end

	-- ปลีกล้วยสีแดงคล้ำห้อยลงมา
	createPart(
		"BananaBlossom",
		Vector3.new(0.65 * scale, 1.4 * scale, 0.65 * scale),
		CFrame.new(topPos + Vector3.new(0.9 * scale, -1.2 * scale, 0)),
		Color3.fromRGB(115, 28, 38),
		Enum.Material.SmoothPlastic,
		tree
	)

	return tree
end

-- วัดขนาด Bounding Box ของ Model หรือ BasePart
local function getItemSize(item: Instance): Vector3
	if item:IsA("Model") then
		local _, s = item:GetBoundingBox()
		return s
	elseif item:IsA("BasePart") then
		return item.Size
	end
	return Vector3.new(2, 2, 2)
end

-- วัดความสูงดั้งเดิมของโมเดล
local function getTemplateHeight(item: Instance): number
	return getItemSize(item).Y
end

-- ฟังก์ชันตรวจสอบคุณลักษณะของโมเดล (สี, รูปทรง, พื้นผิว, ลำดับที่โหลด) เพื่อแยก ศาลพระภูมิ / วิทยุ / หุ่นไล่กา / ต้นข้าว(กอหญ้า) / ต้นกล้วย ออกจากกันอย่างแม่นยำ 100%
local function classifyToolboxItem(item: Instance, templateIndex: number?): (string, number)
	-- ล้างชื่อ Template ที่ระบบเคยตั้งไว้ในรอบก่อนๆ ออกก่อน เพื่อไม่ให้คำว่า BananaTemplate หรือ GrassTemplate ไปกวนการจำแนกประเภท!
	local cleanRootName = string.lower(item.Name)
	cleanRootName = string.gsub(cleanRootName, "^bananatemplate_%d+$", "")
	cleanRootName = string.gsub(cleanRootName, "^grasstemplate_%d+$", "")
	cleanRootName = string.gsub(cleanRootName, "^scarecrowtemplate_%d+$", "")
	cleanRootName = string.gsub(cleanRootName, "^radiotemplate_%d+$", "")
	local nameBlob = cleanRootName

	local greenParts = 0
	local vividGreenParts = 0
	local brownParts = 0
	local redParts = 0
	local yellowParts = 0
	local transparentParts = 0
	local decalOrTexCount = 0
	local meshCount = 0
	local wedgeOrSphereCount = 0
	local hasFlatDecalPlane = false
	local hasHumanoidOrClothes = false
	local totalParts = 0

	local function inspectPart(p: BasePart)
		totalParts += 1
		local c = p.Color
		if p.Transparency > 0.05 then
			transparentParts += 1
		end
		if c.G > c.R + 0.05 and c.G > c.B + 0.03 then
			greenParts += 1
			if p.Transparency == 0 and c.G > 0.45 and c.G > c.R + 0.08 then
				vividGreenParts += 1
			end
		elseif c.R > 0.65 and c.G < 0.35 and c.B < 0.35 then
			redParts += 1
		elseif c.R > 0.65 and c.G > 0.50 and c.B < 0.40 then
			yellowParts += 1
		elseif c.R > c.G + 0.02 and c.G > c.B + 0.01 and c.R < 0.72 then
			brownParts += 1
		end
		if p:IsA("MeshPart") then
			meshCount += 1
			if p.TextureID ~= "" then
				decalOrTexCount += 1
			end
		elseif p:IsA("WedgePart") or p:IsA("CornerWedgePart") or (p:IsA("Part") and p.Shape ~= Enum.PartType.Block) then
			wedgeOrSphereCount += 1
		end
		if p.Transparency > 0.02 and (p:FindFirstChildWhichIsA("Decal") or p:FindFirstChildWhichIsA("Texture")) then
			hasFlatDecalPlane = true
		end
	end

	if item:IsA("BasePart") then
		inspectPart(item)
	end
	for _, desc in ipairs(item:GetDescendants()) do
		nameBlob = nameBlob .. " " .. string.lower(desc.Name)
		if desc:IsA("BasePart") then
			inspectPart(desc)
		elseif desc:IsA("Decal") or desc:IsA("Texture") or desc:IsA("SurfaceAppearance") then
			decalOrTexCount += 1
		elseif desc:IsA("SpecialMesh") or desc:IsA("FileMesh") or desc:IsA("BlockMesh") or desc:IsA("CylinderMesh") then
			meshCount += 1
			if desc:IsA("FileMesh") and desc.TextureId ~= "" then
				decalOrTexCount += 1
			end
		elseif desc:IsA("Humanoid") or desc:IsA("Shirt") or desc:IsA("Pants") or desc:IsA("CharacterMesh") or desc:IsA("Accessory") then
			hasHumanoidOrClothes = true
		end
	end

	local itemSize = getItemSize(item)
	local maxHoriz = math.max(itemSize.X, itemSize.Z, 0.01)
	local minHoriz = math.min(itemSize.X, itemSize.Z)
	local horizAspectRatio = minHoriz / maxHoriz -- หุ่นไล่กากางแขนจะมีทรงแบน (ค่า < 0.68) ส่วนต้นไม้/กอหญ้าจะมีทรงกลม (ค่า > 0.75)

	-- 1. ศาลพระภูมิจาก Toolbox (มีชิ้นส่วนสีเหลืองสด + หลังคาสีแดงสด หรือมีชื่อเกี่ยวกับศาล)
	if
		string.find(nameBlob, "ศาล")
		or string.find(nameBlob, "spirit")
		or string.find(nameBlob, "shrine")
		or (redParts >= 2 and yellowParts >= 2)
	then
		return "spirit_house", 0
	end

	-- 2. วิทยุทรานซิสเตอร์ (กล่องเตี้ยแบน หรือไม่มีชิ้นส่วนสีเขียวและเตี้ยกว่า 2.5 Studs)
	if
		string.find(nameBlob, "radio")
		or string.find(nameBlob, "วิทยุ")
		or string.find(nameBlob, "transistor")
		or string.find(nameBlob, "speaker")
		or (greenParts == 0 and itemSize.Y < 2.5)
		or (itemSize.Y < 1.6 and maxHoriz < 4.5)
	then
		return "radio", 0
	end

	-- 3. หุ่นไล่กา (Scarecrow) จาก Toolbox:
	-- หุ่นไล่กากางแขนจะมีทรงแบนหน้า-หลัง (horizAspectRatio < 0.65) ในขณะที่ต้นกล้วยใบจะแผ่กลมรอบทิศ (horizAspectRatio > 0.72)
	local isTreeName = string.find(nameBlob, "banana")
		or string.find(nameBlob, "palm")
		or string.find(nameBlob, "crown")
		or string.find(nameBlob, "tree")
		or string.find(nameBlob, "trunk")
		or string.find(nameBlob, "กล้วย")

	if
		not isTreeName
		and horizAspectRatio < 0.65
		and (
			string.find(nameBlob, "scarecrow")
			or string.find(nameBlob, "หุ่น")
			or string.find(nameBlob, "straw")
			or string.find(nameBlob, "dummy")
			or hasHumanoidOrClothes
			or (greenParts < totalParts * 0.35 and itemSize.Y >= 2.5 and maxHoriz < 10)
		)
	then
		return "scarecrow", 0
	end

	-- 4. กรองแปลงหญ้าขนาดใหญ่ที่เป็นหนามสีน้ำตาลยักษ์ / แผ่นหญ้าสี่เหลี่ยมจัตุรัสสีเขียวสะท้อนแสง / แท่งเสาเลโก้ ออกไปเก็บในกรุสำรอง!
	local isDefinitelyBananaTree = isTreeName or yellowParts > 0 or (brownParts > 0 and greenParts >= brownParts and totalParts <= 30)
	if
		not isDefinitelyBananaTree
		and (
			totalParts > 35
			or (maxHoriz > 7.5 and itemSize.Y < maxHoriz * 0.95)
			or (brownParts > greenParts and totalParts > 10)
			or (totalParts > 15 and brownParts == 0 and yellowParts == 0 and decalOrTexCount == 0 and meshCount == 0 and wedgeOrSphereCount == 0)
		)
	then
		return "blocky_grass_unused", 0
	end

	-- 5. คำนวณคะแนนความเป็น "กอหญ้าพุ่มเดี่ยว (Tall Grass)" เทียบกับ "ต้นกล้วย (Banana Tree)"
	local grassScore = 0
	if hasFlatDecalPlane then
		grassScore += 140
	end
	if transparentParts > 0 then
		grassScore += 80
	end
	if decalOrTexCount > 0 then
		grassScore += 60
	end
	if
		string.find(nameBlob, "grass")
		or string.find(nameBlob, "weed")
		or string.find(nameBlob, "bush")
		or string.find(nameBlob, "plant")
		or string.find(nameBlob, "หญ้า")
	then
		grassScore += 100
	end
	if vividGreenParts == 0 and brownParts == 0 and yellowParts == 0 then
		grassScore += 55
	end
	if totalParts <= 3 and brownParts == 0 and yellowParts == 0 then
		grassScore += 45
	end
	if isTreeName then
		grassScore -= 140
	end
	if yellowParts > 0 then
		grassScore -= 160
	end
	if brownParts > 0 and vividGreenParts > 0 then
		grassScore -= 110
	end
	if vividGreenParts >= 4 and decalOrTexCount == 0 and transparentParts == 0 then
		grassScore -= 55
	end
	-- กอหญ้าดั้งเดิมจะมีขนาดเล็กกว่าต้นกล้วย
	grassScore -= (maxHoriz * 3.0 + itemSize.Y * 1.5)

	if grassScore > 0 then
		return "grass", grassScore
	end
	return "banana", grassScore
end

-- คัดแยกและจัดเก็บโมเดลที่ผู้เล่นโหลดมาจาก Toolbox (ดึงต้นกล้วยทั้งหมด 6 ต้นกลับไปปลูกข้างปั๊ม และใช้กอหญ้าพุ่มฟูในทุ่งนา!)
local function harvestAllToolboxAssets()
	local ServerStorage = game:GetService("ServerStorage")
	local Players = game:GetService("Players")

	local function getFolder(name: string): Folder
		local f = ServerStorage:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = ServerStorage
		end
		return f :: Folder
	end

	local bananaFolder = getFolder("ToolboxBananaTemplates")
	local grassFolder = getFolder("ToolboxGrassTemplates")
	local radioFolder = getFolder("ToolboxRadioTemplates")
	local scarecrowFolder = getFolder("ToolboxScarecrowTemplates")
	local archiveFolder = getFolder("ArchivedToolboxSpiritHouse")

	-- รวบรวมโมเดลทั้งหมดจากทั้งใน ServerStorage และที่เพิ่งลากวางใน Workspace มาจัดหมวดหมู่พร้อมกันทีเดียว
	local allCandidates = {}
	for _, folder in ipairs({ bananaFolder, grassFolder, scarecrowFolder, archiveFolder }) do
		for _, item in ipairs(folder:GetChildren()) do
			table.insert(allCandidates, item)
		end
	end

	local reservedNames = {
		Camera = true,
		Terrain = true,
		Baseplate = true,
		MapEnvironment = true,
		InteractiveProps = true,
		SpiritHouse = true,
		AnomalyProps = true,
		VehicleWaypoints = true,
		CustomDecorations = true,
	}

	for _, child in ipairs(Workspace:GetChildren()) do
		if not reservedNames[child.Name] and (child:IsA("Model") or child:IsA("BasePart")) then
			if not Players:GetPlayerFromCharacter(child) then
				for _, desc in ipairs(child:GetDescendants()) do
					if desc:IsA("LuaSourceContainer") then
						desc:Destroy()
					elseif desc:IsA("BasePart") then
						desc.Anchored = true
					end
				end
				if child:IsA("BasePart") then
					child.Anchored = true
				end
				table.insert(allCandidates, child)
			end
		end
	end

	local plantCandidates = {}

	for _, item in ipairs(allCandidates) do
		local kind, grassScore = classifyToolboxItem(item)

		if kind == "spirit_house" or kind == "blocky_grass_unused" then
			item.Parent = archiveFolder
		elseif kind == "scarecrow" then
			for _, desc in ipairs(item:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.CanCollide = true
				end
			end
			item.Name = "ScarecrowTemplate_" .. (#scarecrowFolder:GetChildren() + 1)
			item.Parent = scarecrowFolder
		elseif kind == "radio" then
			item.Name = "RadioTemplate_" .. (#radioFolder:GetChildren() + 1)
			item.Parent = radioFolder
		else
			table.insert(plantCandidates, { item = item, score = grassScore })
		end
	end

	-- เรียงลำดับพืชทั้งหมดตามคะแนนความเป็น "กอหญ้า (Tall Grass)" จากมากไปน้อย:
	-- ให้ตัวที่มีคะแนนเป็นกอหญ้าสูงสุด (1-2 แบบแรก) ไปอยู่ในคลังกอหญ้าทุ่งนา และให้ต้นกล้วยทั้ง 6 ต้นอยู่ในคลังดงกล้วยข้างปั๊ม!
	table.sort(plantCandidates, function(a, b)
		return a.score > b.score
	end)

	local targetGrassCount = 0
	if #plantCandidates >= 2 then
		targetGrassCount = math.clamp(#plantCandidates - 6, 1, 2)
		if #plantCandidates >= 8 then
			targetGrassCount = 2
		elseif plantCandidates[2] and plantCandidates[2].score > 0 then
			targetGrassCount = 2
		end
	elseif #plantCandidates == 1 then
		targetGrassCount = 1
	end

	for idx, entry in ipairs(plantCandidates) do
		local item = entry.item
		if idx <= targetGrassCount then
			for _, desc in ipairs(item:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.CanCollide = false
				end
			end
			if item:IsA("BasePart") then
				item.CanCollide = false
			end
			item.Name = "GrassTemplate_" .. idx
			item.Parent = grassFolder
		else
			for _, desc in ipairs(item:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.CanCollide = true
				end
			end
			item.Name = "BananaTemplate_" .. (idx - targetGrassCount)
			item.Parent = bananaFolder
		end
	end

	print(
		string.format(
			"✅ [MapBuilder] คัดแยกโมเดลสำเร็จ: ต้นกล้วยข้างปั๊ม %d ต้น | กอหญ้าทุ่งนา %d แบบ | หุ่นไล่กา %d ตัว",
			#bananaFolder:GetChildren(),
			#grassFolder:GetChildren(),
			#scarecrowFolder:GetChildren()
		)
	)

	return bananaFolder:GetChildren(), grassFolder:GetChildren(), radioFolder:GetChildren(), scarecrowFolder:GetChildren()
end

local function harvestToolboxBananaTrees(): { Instance }
	local bananas, _, _, _ = harvestAllToolboxAssets()
	return bananas
end

-- วางโมเดลจากแม่แบบ Toolbox ลงบนพิกัดพื้นดิน โดยปรับความสูงเป็น targetHeight (และจำกัดความกว้างสำหรับแปลงหญ้าขนาดใหญ่)
local function placeToolboxTreeAt(template: Instance, parent: Instance, groundPos: Vector3, index: number, targetHeight: number, prefixName: string?): Instance
	local clone = template:Clone()
	local prefix = prefixName or "BananaTree_"
	clone.Name = prefix .. index
	clone.Parent = parent

	local isGrass = (prefix == "RiceGrass_" or prefix == "RoadsideGrass_")
	local randomYaw = math.rad((index * 83) % 360)

	if clone:IsA("Model") then
		local _, origSize = clone:GetBoundingBox()
		if origSize.Y > 0.1 then
			local ratioY = targetHeight / origSize.Y
			local ratio = ratioY
			if isGrass then
				local maxAllowedWidth = (prefix == "RoadsideGrass_") and 3.4 or 5.2
				local maxHoriz = math.max(origSize.X, origSize.Z, 0.1)
				local ratioXZ = maxAllowedWidth / maxHoriz
				ratio = math.min(ratioY, ratioXZ)
			end
			clone:ScaleTo(clone:GetScale() * ratio)
		end

		local bboxCF, bboxSize = clone:GetBoundingBox()
		local pivotCF = clone:GetPivot()
		local bottomY = bboxCF.Position.Y - (bboxSize.Y / 2)
		local pivotOffsetFromBottom = pivotCF.Position.Y - bottomY

		local targetPos = Vector3.new(groundPos.X, groundPos.Y + pivotOffsetFromBottom, groundPos.Z)
		clone:PivotTo(CFrame.new(targetPos) * CFrame.Angles(0, randomYaw, 0))
	elseif clone:IsA("BasePart") then
		if clone.Size.Y > 0.1 then
			local ratioY = targetHeight / clone.Size.Y
			local ratio = ratioY
			if isGrass then
				local maxAllowedWidth = (prefix == "RoadsideGrass_") and 3.4 or 5.2
				local maxHoriz = math.max(clone.Size.X, clone.Size.Z, 0.1)
				local ratioXZ = maxAllowedWidth / maxHoriz
				ratio = math.min(ratioY, ratioXZ)
			end
			clone.Size = clone.Size * ratio
		end
		local targetPos = Vector3.new(groundPos.X, groundPos.Y + (clone.Size.Y / 2), groundPos.Z)
		clone.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, randomYaw, 0)
	end

	return clone
end

-- สร้างไฟฉายกบ (Flashlight Tool) แจกให้ผู้เล่นทุกคน
function MapBuilder.CreateFlashlightTool()
	if StarterPack:FindFirstChild("FrogFlashlight") then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = "FrogFlashlight"
	tool.ToolTip = "🔦 ไฟฉายกบส่องผี (Frog Flashlight)"
	tool.RequiresHandle = true

	local handle = createPart(
		"Handle",
		Vector3.new(0.55, 0.55, 1.35),
		CFrame.new(0, 0, 0),
		Color3.fromRGB(45, 95, 55),
		Enum.Material.SmoothPlastic,
		tool
	)
	handle.Anchored = false

	local lens = createPart(
		"YellowRim",
		Vector3.new(0.65, 0.65, 0.2),
		CFrame.new(0, 0, -0.65),
		Color3.fromRGB(240, 190, 40),
		Enum.Material.Neon,
		tool
	)
	lens.Anchored = false
	lens.CanCollide = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = lens
	weld.Parent = handle

	local spotLight = Instance.new("SpotLight")
	spotLight.Name = "BeamLight"
	spotLight.Face = Enum.NormalId.Front
	spotLight.Brightness = 4.0
	spotLight.Range = 58
	spotLight.Angle = 54
	spotLight.Color = Color3.fromRGB(255, 244, 195)
	spotLight.Shadows = true
	spotLight.Enabled = true
	spotLight.Parent = handle

	tool.Parent = StarterPack
end

function MapBuilder.Build()
	-- สร้างหรือปรับแต่งพื้นดินหลักขนาดใหญ่ (500x500 Studs) ด้วยวัสดุหญ้าธรรมชาติเข้ม (LeafyGrass) แทนสีเทาเรียบๆ
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Size = Vector3.new(500, 4, 500)
		baseplate.Position = Vector3.new(0, -2, 0)
		baseplate.Color = Color3.fromRGB(45, 58, 36)
		baseplate.Material = Enum.Material.LeafyGrass
		baseplate.Anchored = true
	else
		local newBase = Instance.new("Part")
		newBase.Name = "Baseplate"
		newBase.Size = Vector3.new(500, 4, 500)
		newBase.Position = Vector3.new(0, -2, 0)
		newBase.Color = Color3.fromRGB(45, 58, 36)
		newBase.Material = Enum.Material.LeafyGrass
		newBase.Anchored = true
		newBase.TopSurface = Enum.SurfaceType.Smooth
		newBase.BottomSurface = Enum.SurfaceType.Smooth
		newBase.Parent = Workspace
	end

	local function getOrCreateFolder(folderName: string): Folder
		local f = Workspace:FindFirstChild(folderName)
		if not f then
			f = Instance.new("Folder")
			f.Name = folderName
			f.Parent = Workspace
		end
		f:ClearAllChildren()
		return f :: Folder
	end

	-- กวาดและแยกประเภทโมเดลใหม่ที่วางไว้ใน Workspace (ต้นข้าว/กอหญ้าหลายแบบ, วิทยุ, หุ่นไล่กา, ศาลพระภูมิ, ต้นกล้วย)
	local _, grassTemplates, radioTemplates, scarecrowTemplates = harvestAllToolboxAssets()

	local mapEnv = getOrCreateFolder("MapEnvironment")
	local interactive = getOrCreateFolder("InteractiveProps")
	local spiritHouse = getOrCreateFolder("SpiritHouse")
	local anomalyProps = getOrCreateFolder("AnomalyProps")
	local waypoints = getOrCreateFolder("VehicleWaypoints")

	-- โฟลเดอร์สำหรับให้ผู้เล่นวางโมเดลตกแต่งเพิ่มเติมเอง (จะไม่ถูกลบเด็ดขาดแม้สั่ง Build ใหม่)
	if not Workspace:FindFirstChild("CustomDecorations") then
		local customFolder = Instance.new("Folder")
		customFolder.Name = "CustomDecorations"
		customFolder.Parent = Workspace
	end

	-- แยกแสงตอน Dev (สว่างเห็นชัด 100%) กับตอนกด Play เข้าเกม (มืดหลอนเที่ยงคืน)
	local RunService = game:GetService("RunService")
	if RunService:IsRunning() then
		MapBuilder.SetNightLighting()
	else
		MapBuilder.SetDayDevLighting()
	end

	-- =====================================================
	-- 0. สร้างพื้นภูมิประเทศขรุขระแบบธรรมชาติด้วย Roblox Voxel Terrain (คันนานูน + แอ่งนาบุ๋มลงไปเหมือนรอบแรกเป๊ะ + ถนนเรียบ)
	-- =====================================================
	local terrain = Workspace.Terrain
	if terrain then
		terrain:Clear()
		pcall(function()
			terrain.Decoration = true -- เปิดหญ้าพลิ้วไหวอัตโนมัติบนพื้นดิน
		end)

		-- ปูพื้นหญ้าและดินโคลนธรรมชาติคลุมทับ Baseplate รอบนอกทั้งหมด ไม่ให้เป็นแผ่นสีเทาเรียบๆ
		terrain:FillBlock(CFrame.new(0, -2.2, 0), Vector3.new(360, 4.2, 360), Enum.Material.LeafyGrass)
		-- ปูพื้นโคลนถนนและลานหน้าร้าน
		terrain:FillBlock(CFrame.new(0, -1.6, -12), Vector3.new(170, 3.3, 26), Enum.Material.Mud)
		terrain:FillBlock(CFrame.new(0, -1.6, 12), Vector3.new(54, 3.3, 32), Enum.Material.Ground)
		-- ขุดแอ่งน้ำทุ่งนาฝั่งตรงข้ามให้บุ๋มลึกลงไป แล้วปูพื้นโคลนใต้น้ำ (เหมือนในรูปที่ต้องการเป๊ะ!)
		terrain:FillBlock(CFrame.new(0, -1.2, -50), Vector3.new(162, 3.0, 54), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(0, -2.8, -50), Vector3.new(164, 2.8, 56), Enum.Material.Mud)

		-- สร้างเนินดินขรุขระตามคันนา ไหล่ทาง และโคนดงกล้วยด้วยก้อน Voxel Ball สุ่มขนาด
		for mx = -75, 75, 9 do
			local seed = math.abs(mx * 17)
			local r1 = 3.2 + (seed % 25) * 0.1
			-- ไหล่ทางฝั่งติดทุ่งนา (คันนาหน้าสุดขรุขระเป็นคลื่น มีรอยบุ๋มลงไปในนา)
			terrain:FillBall(Vector3.new(mx, -1.4 + (seed % 5) * 0.12, -24.5 + ((seed % 3) - 1) * 0.7), r1, Enum.Material.Grass)
			-- ไหล่ทางฝั่งหน้าร้านและริมถนนลูกรัง
			if math.abs(mx) > 22 then
				terrain:FillBall(Vector3.new(mx, -1.3 + (seed % 4) * 0.15, 2 + (seed % 4)), r1 + 0.8, Enum.Material.LeafyGrass)
			end
		end

		-- คันนากลางและคันนาขวาแบบขรุขระธรรมชาติ (มีรอยบุ๋มแบ่งแปลงนาเหมือนรูปต้นแบบ)
		for mz = -26, -74, -6 do
			local s2 = math.abs(mz * 23)
			terrain:FillBall(Vector3.new(-10 + ((s2 % 3) - 1) * 0.5, -1.5, mz), 3.0 + (s2 % 10) * 0.08, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(25 + ((s2 % 3) - 1) * 0.5, -1.5, mz), 3.0 + (s2 % 10) * 0.08, Enum.Material.Grass)
		end

		-- เนินดินโคนดงกล้วยตานีและหลังเพิงสังกะสี
		for _, moundPos in ipairs({
			Vector3.new(24, -1.0, 14),
			Vector3.new(28, -0.8, 24),
			Vector3.new(22, -1.1, 34),
			Vector3.new(10, -1.2, 34),
			Vector3.new(-6, -1.2, 35),
			Vector3.new(32, -0.9, 36),
			Vector3.new(-22, -1.2, 10),
		}) do
			terrain:FillBall(moundPos, 5.5, Enum.Material.LeafyGrass)
		end
	end

	-- =====================================================
	-- 1. โซนถนนดินลูกรัง (ระบายสีลงบนพื้น Terrain โดยตรง ไม่ใช้แผ่น Part แข็งๆ) & เสาไฟไม้ (DirtRoad)
	-- =====================================================
	local dirtRoadModel = Instance.new("Model")
	dirtRoadModel.Name = "DirtRoad"
	dirtRoadModel.Parent = mapEnv

	-- แอ่งน้ำโคลนสะท้อนแสงไฟนีออนหน้าร้าน (Rain Puddles)
	for idx, pPos in ipairs({
		{ pos = Vector3.new(-11, 0.79, -6.5), s = Vector3.new(0.06, 4.6, 3.4) },
		{ pos = Vector3.new(5, 0.79, -10.5), s = Vector3.new(0.06, 5.2, 3.6) },
		{ pos = Vector3.new(-3, 0.77, 1.5), s = Vector3.new(0.06, 3.6, 3.0) },
	}) do
		local puddle = createPart(
			"MudPuddle_" .. idx,
			pPos.s,
			CFrame.new(pPos.pos) * CFrame.Angles(0, math.rad(idx * 35), math.rad(90)),
			Color3.fromRGB(38, 28, 22),
			Enum.Material.Glass,
			dirtRoadModel,
			Enum.PartType.Cylinder
		)
		puddle.Reflectance = 0.35
		puddle.Transparency = 0.15
		puddle.CanCollide = false
	end

	-- ก้อนหินธรรมชาติริมทางและรอบหลักกิโล
	for idx, rPos in ipairs({
		Vector3.new(-23.2, 0.45, -2.0),
		Vector3.new(-21.0, 0.38, -2.4),
		Vector3.new(-14.2, 0.42, -1.2),
		Vector3.new(16.8, 0.45, 5.2),
		Vector3.new(-17.5, 0.45, 11.5),
		Vector3.new(12.5, 0.42, -22.5),
		Vector3.new(-11.2, 0.45, -23.0),
	}) do
		createPart(
			"NaturalRock_" .. idx,
			Vector3.new(1.1 + (idx % 3) * 0.35, 0.6 + (idx % 2) * 0.25, 0.9 + (idx % 3) * 0.3),
			CFrame.new(rPos) * CFrame.Angles(math.rad(idx * 17), math.rad(idx * 53), math.rad(idx * 11)),
			Color3.fromRGB(88, 82, 74),
			Enum.Material.Slate,
			dirtRoadModel
		)
	end

	-- หลักกิโลเมตรเก่าๆ ริมทาง
	local kmPost = createPart("KilometerMilestone", Vector3.new(1.4, 3.2, 1.4), CFrame.new(-22, 1.6, -1.5), Color3.fromRGB(215, 210, 198), Enum.Material.Concrete, dirtRoadModel)
	createPart("KilometerTop", Vector3.new(1.4, 0.8, 1.4), CFrame.new(-22, 3.6, -1.5), Color3.fromRGB(185, 45, 45), Enum.Material.Concrete, dirtRoadModel)
	addLabel(kmPost, "🛣️ หลักกิโลเมตรที่ 4 (ถนนดินลูกรัง)", Color3.fromRGB(230, 185, 130))

	-- เสาไฟไม้หน้าร้าน + โคมไฟนีออนกะพริบ
	createPart("WoodenPole", Vector3.new(1.1, 17, 1.1), CFrame.new(-15, 8.5, -0.5), Color3.fromRGB(72, 50, 34), Enum.Material.Wood, dirtRoadModel)
	createPart("PoleArm", Vector3.new(0.4, 0.4, 3.5), CFrame.new(-15, 16, -2.0), Color3.fromRGB(60, 60, 65), Enum.Material.CorrodedMetal, dirtRoadModel)
	local neonTube = createPart(
		"NeonLightPart",
		Vector3.new(4.2, 0.35, 0.55),
		CFrame.new(-15, 15.65, -2.8),
		Color3.fromRGB(255, 240, 200),
		Enum.Material.Neon,
		dirtRoadModel
	)
	local poleLight = Instance.new("PointLight")
	poleLight.Name = "FlickerLight"
	poleLight.Brightness = 2.0
	poleLight.Range = 38
	poleLight.Color = Color3.fromRGB(255, 220, 155)
	poleLight.Shadows = true
	poleLight.Parent = neonTube

	-- =====================================================
	-- 2. โซนทุ่งนามืด, คันนา, น้ำในนา & เถียงนาร้าง (RiceField)
	-- =====================================================
	local riceFieldModel = Instance.new("Model")
	riceFieldModel.Name = "RiceField"
	riceFieldModel.Parent = mapEnv

	-- พื้นน้ำในนาสะท้อนแสงจันทร์สลัวๆ
	local paddyWater = createPart(
		"PaddyWater",
		Vector3.new(160, 0.4, 52),
		CFrame.new(0, 0.2, -50),
		Color3.fromRGB(22, 36, 28),
		Enum.Material.Glass,
		riceFieldModel
	)
	paddyWater.Reflectance = 0.15

	-- กอข้าวในทุ่งนา + หญ้ารกตามคันนาและริมถนนลูกรัง (ใช้โมเดล Tall Grass จาก Toolbox ถ้ามี!)
	local grassIdx = 0
	for rx = -52, 52, 7.5 do
		for rz = -29, -65, -6.5 do
			grassIdx += 1
			local gx = rx + ((grassIdx * 37) % 3) - 1
			local gz = rz + ((grassIdx * 53) % 3) - 1
			if #grassTemplates > 0 then
				local chosenGrass = grassTemplates[((grassIdx - 1) % #grassTemplates) + 1]
				local targetH = 2.6 + ((grassIdx * 19) % 16) * 0.1 -- สูงไล่ระดับ 2.6 - 4.1 Studs
				placeToolboxTreeAt(chosenGrass, riceFieldModel, Vector3.new(gx, 0.25, gz), grassIdx, targetH, "RiceGrass_")
			else
				-- สำรองกรณีไม่มีโมเดลหญ้า: สร้างกอข้าวใบเรียว 3 มิติ (ห้ามสร้างเป็นก้อนสี่เหลี่ยมทื่อๆ เด็ดขาด!)
				for b = 1, 4 do
					local bAngle = math.rad((b * 45) + ((grassIdx * 29) % 30))
					local bTilt = math.rad(12 + (b * 4))
					local blade = createPart(
						"RiceBlade_" .. b,
						Vector3.new(0.18, 2.6 + (b % 2) * 0.4, 0.45),
						CFrame.new(gx, 1.3, gz) * CFrame.Angles(0, bAngle, 0) * CFrame.Angles(bTilt, 0, 0),
						Color3.fromRGB(48, 76, 36),
						Enum.Material.Grass,
						riceFieldModel
					)
					blade.CanCollide = false
				end
			end
		end
	end

	-- ปลูกกอหญ้า Tall Grass ริมถนนลูกรัง, ข้างหลักกิโล, โคนเสาไฟ และรอบฐานศาลพระภูมิ
	if #grassTemplates > 0 then
		local roadsideCoords = {
			-- รอบหลักกิโลเมตรที่ 4 และโคนเสาไฟไม้หน้าร้าน
			{ pos = Vector3.new(-22.8, 0.3, -2.2), h = 3.2 },
			{ pos = Vector3.new(-21.2, 0.3, -0.8), h = 2.5 },
			{ pos = Vector3.new(-23.5, 0.3, -1.0), h = 2.8 },
			{ pos = Vector3.new(-15.8, 0.3, -1.2), h = 3.0 },
			{ pos = Vector3.new(-14.3, 0.3, 0.2), h = 2.4 },
			-- ริมคันนาติดถนนฝั่งตรงข้าม
			{ pos = Vector3.new(-38, 0.5, -24.2), h = 3.6 },
			{ pos = Vector3.new(-26, 0.5, -24.5), h = 3.1 },
			{ pos = Vector3.new(-12, 0.5, -24.0), h = 3.8 },
			{ pos = Vector3.new(-9.5, 0.5, -24.8), h = 2.9 },
			{ pos = Vector3.new(4, 0.5, -24.3), h = 3.4 },
			{ pos = Vector3.new(16, 0.5, -24.2), h = 3.0 },
			{ pos = Vector3.new(25.5, 0.5, -24.5), h = 3.7 },
			{ pos = Vector3.new(38, 0.5, -24.2), h = 3.3 },
			-- รอบฐานศาลพระภูมิและข้างซ้ายเพิง
			{ pos = Vector3.new(-24.2, 0.3, 8.8), h = 2.8 },
			{ pos = Vector3.new(-23.8, 0.3, 11.6), h = 3.3 },
			{ pos = Vector3.new(-19.8, 0.3, 11.2), h = 2.5 },
			{ pos = Vector3.new(-16.5, 0.3, 8.2), h = 2.9 },
			{ pos = Vector3.new(-16.8, 0.3, 15.0), h = 3.4 },
			-- ข้างขวาเพิงและทางเดินไปห้องน้ำสังกะสี
			{ pos = Vector3.new(16.5, 0.3, 7.5), h = 2.7 },
			{ pos = Vector3.new(17.2, 0.3, 13.5), h = 3.2 },
			{ pos = Vector3.new(22.5, 0.3, 31.5), h = 3.1 },
			{ pos = Vector3.new(25.8, 0.3, 34.2), h = 2.8 },
		}
		for idx, gData in ipairs(roadsideCoords) do
			local chosenGrass = grassTemplates[((idx - 1) % #grassTemplates) + 1]
			placeToolboxTreeAt(chosenGrass, dirtRoadModel, gData.pos, idx, gData.h, "RoadsideGrass_")
		end
	end

	-- เถียงนาร้างไม้ไผ่ยกพื้นสูงไกลๆ (จุดเกิดแสงไฟผีกระสือ Tier 3)
	local hutModel = Instance.new("Model")
	hutModel.Name = "DistantRiceHut"
	hutModel.Parent = riceFieldModel
	local hutFloor = createPart("HutFloor", Vector3.new(10, 0.5, 8), CFrame.new(-28, 3.5, -58), Color3.fromRGB(68, 50, 34), Enum.Material.WoodPlanks, hutModel)
	for _, offset in ipairs({ Vector3.new(-4.2, -1.75, -3.2), Vector3.new(4.2, -1.75, -3.2), Vector3.new(-4.2, -1.75, 3.2), Vector3.new(4.2, -1.75, 3.2) }) do
		createPart("HutPillar", Vector3.new(0.6, 7.5, 0.6), CFrame.new(hutFloor.Position + offset + Vector3.new(0, 2, 0)), Color3.fromRGB(58, 42, 28), Enum.Material.Wood, hutModel)
	end
	createPart("HutRoof", Vector3.new(11.5, 0.4, 9.5), CFrame.new(-28, 7.8, -58) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(95, 82, 68), Enum.Material.CorrodedMetal, hutModel)
	addLabel(hutFloor, "🛖 เถียงนาร้างกลางทุ่ง (จุดผีกระสือ)", Color3.fromRGB(255, 145, 90))

	-- =====================================================
	-- 3. โซนเพิงสังกะสีไม้ไผ่แบบละเอียด (ShackStructure)
	-- =====================================================
	local shackModel = Instance.new("Model")
	shackModel.Name = "ShackStructure"
	shackModel.Parent = mapEnv

	-- พื้นไม้กระดานเพิงร้าน
	createPart("ShackFloor", Vector3.new(32, 0.8, 20), CFrame.new(0, 0.4, 18), Color3.fromRGB(82, 60, 40), Enum.Material.WoodPlanks, shackModel)

	-- จุดเกิดผู้เล่น 1-4 คนในเพิง
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "ShackSpawn"
	spawnLoc.Size = Vector3.new(6, 0.6, 6)
	spawnLoc.Position = Vector3.new(0, 0.85, 21)
	spawnLoc.Anchored = true
	spawnLoc.Transparency = 1
	spawnLoc.CanCollide = false
	spawnLoc.Parent = shackModel

	-- เสาไม้ค้ำเพิง 6 ต้น
	local pillarCoords = {
		Vector3.new(-15.2, 6, 8.5),
		Vector3.new(15.2, 6, 8.5),
		Vector3.new(-15.2, 5.5, 18),
		Vector3.new(15.2, 5.5, 18),
		Vector3.new(-15.2, 5, 27.5),
		Vector3.new(15.2, 5, 27.5),
	}
	for idx, pPos in ipairs(pillarCoords) do
		createPart("WoodenPillar_" .. idx, Vector3.new(1.1, 11.5, 1.1), CFrame.new(pPos), Color3.fromRGB(65, 45, 30), Enum.Material.Wood, shackModel)
	end

	-- ฝาผนังไม้ตีเว้นร่อง (ให้มองเห็นเงาหลอนๆ ด้านนอกได้รำไร)
	for h = 2, 9, 1.6 do
		createPart("BackPlank", Vector3.new(31.5, 1.2, 0.4), CFrame.new(0, h, 27.6), Color3.fromRGB(88, 65, 45), Enum.Material.WoodPlanks, shackModel)
		createPart("LeftPlank", Vector3.new(0.4, 1.2, 19.5), CFrame.new(-15.5, h, 18), Color3.fromRGB(88, 65, 45), Enum.Material.WoodPlanks, shackModel)
		createPart("RightPlank", Vector3.new(0.4, 1.2, 19.5), CFrame.new(15.5, h, 18), Color3.fromRGB(88, 65, 45), Enum.Material.WoodPlanks, shackModel)
	end

	-- หลังคาสังกะสีลูกฟูกเก่า (วางซ้อนแผ่นเหลื่อมกันและลาดเอียงไปด้านหลัง)
	for s = -15, 15, 5 do
		local rustShade = math.random(-12, 12)
		createPart(
			"CorrugatedTinSheet",
			Vector3.new(5.4, 0.35, 24),
			CFrame.new(s, 11.6, 17.5) * CFrame.Angles(math.rad(-6), 0, math.rad(math.random(-1, 1))),
			Color3.fromRGB(115 + rustShade, 98 + rustShade, 86 + rustShade),
			Enum.Material.CorrodedMetal,
			shackModel
		)
	end

	-- ป้ายร้านวินเทจ 2 ภาษา (TH / EN)
	local signPart = createPart(
		"ShopSign",
		Vector3.new(22, 2.8, 0.5),
		CFrame.new(0, 12.8, 6.2),
		Color3.fromRGB(48, 30, 20),
		Enum.Material.WoodPlanks,
		shackModel
	)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.Parent = signPart
	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.TextColor3 = Color3.fromRGB(255, 205, 70)
	signText.Font = Enum.Font.GothamBold
	signText.TextScaled = true
	signText.Text = "⛽ ปั๊มหลอดท้ายทุ่ง - RURAL GAS & TIRE"
	signText.Parent = signGui

	-- โต๊ะไม้เก่ามีขาโต๊ะ 4 ขา + แคร่ไม้ไผ่นั่งพักในเพิง
	createPart("CounterTop", Vector3.new(14, 0.5, 3.6), CFrame.new(0, 3.55, 13), Color3.fromRGB(78, 54, 34), Enum.Material.WoodPlanks, shackModel)
	for _, legOff in ipairs({ Vector3.new(-6.4, 1.9, 11.5), Vector3.new(6.4, 1.9, 11.5), Vector3.new(-6.4, 1.9, 14.5), Vector3.new(6.4, 1.9, 14.5) }) do
		createPart("TableLeg", Vector3.new(0.6, 3.1, 0.6), CFrame.new(legOff), Color3.fromRGB(62, 42, 26), Enum.Material.Wood, shackModel)
	end
	-- ล้อยางอะไหล่วางซ้อนกันมุมร้าน
	for ty = 1, 3 do
		createPart(
			"SpareTire_" .. ty,
			Vector3.new(1.0, 2.8, 2.8),
			CFrame.new(-12.5, 0.8 + ((ty - 1) * 1.05), 11) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(30, 32, 32),
			Enum.Material.Rubber,
			shackModel,
			Enum.PartType.Cylinder
		)
	end

	-- ไฟนีออนในเพิงร้าน
	local shackBulb = createPart("ShackLightBulb", Vector3.new(3.5, 0.3, 0.5), CFrame.new(0, 10.9, 17), Color3.fromRGB(255, 235, 185), Enum.Material.Neon, shackModel)
	local shackPointLight = Instance.new("PointLight")
	shackPointLight.Name = "InteriorLight"
	shackPointLight.Brightness = 1.6
	shackPointLight.Range = 30
	shackPointLight.Color = Color3.fromRGB(255, 215, 145)
	shackPointLight.Shadows = true
	shackPointLight.Parent = shackBulb

	-- =====================================================
	-- 4. โซนดงกล้วยตานีทึบๆ รอบร้าน (BananaGrove - ใช้โมเดลจาก Toolbox ถ้ามี!)
	-- =====================================================
	MapBuilder.PlantBananaTrees()

	-- =====================================================
	-- 5. โซนอุปกรณ์ทำงานหลักแบบละเอียด (InteractiveProps)
	-- =====================================================
	-- 5.1 ตู้ปั๊มน้ำมันหลอดแก้วโบราณ (GasPump)
	local gasPumpModel = Instance.new("Model")
	gasPumpModel.Name = "GasPump"
	gasPumpModel.Parent = interactive

	createPart("ConcretePad", Vector3.new(3.8, 0.5, 3.8), CFrame.new(-6, 0.5, 2.5), Color3.fromRGB(140, 138, 132), Enum.Material.Concrete, gasPumpModel)
	local pumpBase = createPart(
		"PumpBase",
		Vector3.new(4.2, 2.2, 2.2),
		CFrame.new(-6, 2.8, 2.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(175, 48, 38),
		Enum.Material.CorrodedMetal,
		gasPumpModel,
		Enum.PartType.Cylinder
	)
	local glassTube = createPart(
		"GlassCylinder",
		Vector3.new(2.8, 1.65, 1.65),
		CFrame.new(-6, 6.3, 2.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(220, 235, 240),
		Enum.Material.Glass,
		gasPumpModel,
		Enum.PartType.Cylinder
	)
	glassTube.Transparency = 0.55
	-- น้ำมันสีส้มสดข้างในหลอดแก้ว
	createPart(
		"OrangeFuelLiquid",
		Vector3.new(2.1, 1.45, 1.45),
		CFrame.new(-6, 5.95, 2.5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 140, 25),
		Enum.Material.Neon,
		gasPumpModel,
		Enum.PartType.Cylinder
	)
	-- ฝาครอบบนหลอดแก้ว & มือหมุนด้านข้าง
	createPart("PumpCap", Vector3.new(0.5, 1.9, 1.9), CFrame.new(-6, 7.8, 2.5) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(165, 45, 35), Enum.Material.CorrodedMetal, gasPumpModel, Enum.PartType.Cylinder)
	createPart("HandCrank", Vector3.new(0.3, 1.4, 0.3), CFrame.new(-4.7, 3.2, 2.5) * CFrame.Angles(math.rad(35), 0, 0), Color3.fromRGB(40, 40, 42), Enum.Material.Metal, gasPumpModel)
	gasPumpModel.PrimaryPart = pumpBase
	addLabel(glassTube, "⛽ GasPump (ปั๊มน้ำมันหลอดแก้ว)", Color3.fromRGB(255, 175, 50))

	local pumpPrompt = Instance.new("ProximityPrompt")
	pumpPrompt.Name = "PumpFuelPrompt"
	pumpPrompt.ObjectText = "ปั๊มหลอดแก้ว / Fuel Pump"
	pumpPrompt.ActionText = "หมุนปั๊มเติมน้ำมัน (+100฿)"
	pumpPrompt.HoldDuration = 2.5
	pumpPrompt.MaxActivationDistance = 10
	pumpPrompt.Parent = pumpBase

	-- 5.2 ถังปั๊มลมปะยางทรงกระบอกพร้อมล้อ (AirCompressor)
	local airCompModel = Instance.new("Model")
	airCompModel.Name = "AirCompressor"
	airCompModel.Parent = interactive
	local airTank = createPart(
		"CompressorTank",
		Vector3.new(4.2, 2.1, 2.1),
		CFrame.new(7, 1.8, 2.5),
		Color3.fromRGB(185, 72, 35),
		Enum.Material.CorrodedMetal,
		airCompModel,
		Enum.PartType.Cylinder
	)
	createPart("MotorTop", Vector3.new(1.5, 1.1, 1.2), CFrame.new(6.5, 3.2, 2.5), Color3.fromRGB(50, 52, 55), Enum.Material.Metal, airCompModel)
	createPart("WheelL", Vector3.new(0.4, 1.3, 1.3), CFrame.new(5.5, 0.9, 3.6) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, airCompModel, Enum.PartType.Cylinder)
	createPart("WheelR", Vector3.new(0.4, 1.3, 1.3), CFrame.new(5.5, 0.9, 1.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(28, 28, 30), Enum.Material.Rubber, airCompModel, Enum.PartType.Cylinder)
	airCompModel.PrimaryPart = airTank
	addLabel(airTank, "🔧 AirCompressor (ถังปั๊มลมปะยาง)", Color3.fromRGB(255, 175, 50))

	-- 5.3 แผ่นสังกะสีปิดหน้าร้าน (ShutterDoor) & เชือกดึง (RejectRope)
	local shutterDoor = createPart(
		"ShutterDoor",
		Vector3.new(30, 9.5, 0.4),
		CFrame.new(0, 15.5, 8.2),
		Color3.fromRGB(125, 115, 108),
		Enum.Material.CorrodedMetal,
		interactive
	)
	shutterDoor:SetAttribute("OpenY", 15.5)
	shutterDoor:SetAttribute("ClosedY", 6.0)

	local rejectRope = createPart(
		"RejectRope",
		Vector3.new(0.6, 3.8, 0.6),
		CFrame.new(-5.5, 5.4, 12.2),
		Color3.fromRGB(220, 55, 55),
		Enum.Material.Fabric,
		interactive
	)
	addLabel(rejectRope, "🚧 RejectRope (ดึงแผงสังกะสีปิดร้าน!)", Color3.fromRGB(255, 80, 95))

	local rejectPrompt = Instance.new("ProximityPrompt")
	rejectPrompt.Name = "RejectCustomerPrompt"
	rejectPrompt.ObjectText = "แผงสังกะสีหน้าร้าน / Shop Shutter"
	rejectPrompt.ActionText = "ดึงแผงปิดร้าน! (ปฏิเสธผี)"
	rejectPrompt.HoldDuration = 0.5
	rejectPrompt.MaxActivationDistance = 10
	rejectPrompt.Parent = rejectRope

	-- 5.4 วิทยุทรานซิสเตอร์บนโต๊ะไม้ (Radio - ใช้โมเดลจาก Toolbox ถ้ามี!) & กระป๋องคุกกี้แดงใส่เงิน (MoneyTin)
	if #radioTemplates > 0 then
		local radioClone = radioTemplates[1]:Clone()
		radioClone.Name = "Radio"
		radioClone.Parent = interactive

		if radioClone:IsA("Model") then
			local _, origS = radioClone:GetBoundingBox()
			local maxHoriz = math.max(origS.X, origS.Z, 0.1)
			local scaleRatio = 2.2 / maxHoriz
			radioClone:ScaleTo(radioClone:GetScale() * scaleRatio)

			local bboxCF, bboxSize = radioClone:GetBoundingBox()
			local pivotCF = radioClone:GetPivot()
			local bottomY = bboxCF.Position.Y - (bboxSize.Y / 2)
			local offsetFromBottom = pivotCF.Position.Y - bottomY
			radioClone:PivotTo(CFrame.new(4, 3.82 + offsetFromBottom, 13))

			local anyPart = radioClone.PrimaryPart or radioClone:FindFirstChildWhichIsA("BasePart", true)
			if anyPart then
				addLabel(anyPart, "📻 Radio (วิทยุทรานซิสเตอร์)", Color3.fromRGB(140, 220, 255))
			end
		elseif radioClone:IsA("BasePart") then
			local maxHoriz = math.max(radioClone.Size.X, radioClone.Size.Z, 0.1)
			local scaleRatio = 2.2 / maxHoriz
			radioClone.Size = radioClone.Size * scaleRatio
			radioClone.CFrame = CFrame.new(4, 3.82 + (radioClone.Size.Y / 2), 13)
			addLabel(radioClone, "📻 Radio (วิทยุทรานซิสเตอร์)", Color3.fromRGB(140, 220, 255))
		end
	else
		local radioPart = createPart("Radio", Vector3.new(2.1, 1.3, 0.9), CFrame.new(4, 4.45, 13), Color3.fromRGB(42, 44, 48), Enum.Material.Metal, interactive)
		createPart("RadioAntenna", Vector3.new(0.12, 2.2, 0.12), CFrame.new(4.8, 5.6, 13) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(190, 195, 200), Enum.Material.Metal, interactive)
		addLabel(radioPart, "📻 Radio (วิทยุทรานซิสเตอร์)", Color3.fromRGB(140, 220, 255))
	end

	local moneyTin = createPart(
		"MoneyTin",
		Vector3.new(1.0, 1.8, 1.8),
		CFrame.new(-1.5, 4.3, 13) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(205, 40, 50),
		Enum.Material.Metal,
		interactive,
		Enum.PartType.Cylinder
	)
	addLabel(moneyTin, "💰 MoneyTin (กระป๋องคุกกี้ใส่เงิน 500฿)", Color3.fromRGB(235, 255, 100))

	-- 5.5 สวิตช์คัตเอาต์ไฟในเพิง (CutoutSwitch - Prop Hook #3)
	local cutout = createPart("CutoutSwitch", Vector3.new(0.5, 1.8, 1.2), CFrame.new(-14.6, 5.5, 18), Color3.fromRGB(210, 140, 45), Enum.Material.Metal, interactive)
	addLabel(cutout, "⚡ CutoutSwitch (คัตเอาต์สับดับไฟ)", Color3.fromRGB(255, 220, 90))

	-- 5.6 เครื่องปั่นไฟหลังดงกล้วย (Generator)
	local genModel = Instance.new("Model")
	genModel.Name = "Generator"
	genModel.Parent = interactive
	local genPart = createPart("GeneratorBody", Vector3.new(3.8, 2.8, 2.6), CFrame.new(20, 1.8, 30), Color3.fromRGB(145, 48, 42), Enum.Material.CorrodedMetal, genModel)
	createPart("ExhaustPipe", Vector3.new(0.5, 1.8, 0.5), CFrame.new(21.2, 3.6, 30), Color3.fromRGB(45, 45, 48), Enum.Material.CorrodedMetal, genModel)
	genModel.PrimaryPart = genPart
	addLabel(genPart, "⚡ Generator (เครื่องปั่นไฟหลังดงกล้วย)", Color3.fromRGB(255, 180, 70))

	-- =====================================================
	-- 6. ศาลพระภูมิไม้สักเก่าท้ายทุ่ง (ปั้นใหม่ละเอียดขลังๆ เข้ากับธีมหลอนชนบทไทย + ธูป 3 ดอก)
	-- =====================================================
	local sx, sz = -22, 10
	-- 6.1 ฐานปูนเก่าตะไคร่จับ 2 ชั้น
	createPart("ShrineBaseStep1", Vector3.new(4.6, 0.5, 4.6), CFrame.new(sx, 0.25, sz), Color3.fromRGB(82, 86, 78), Enum.Material.Slate, spiritHouse)
	createPart("ShrineBaseStep2", Vector3.new(3.2, 0.6, 3.2), CFrame.new(sx, 0.8, sz), Color3.fromRGB(68, 75, 64), Enum.Material.Concrete, spiritHouse)

	-- 6.2 เสาไม้สักแกะสลัก + ผ้าสามสีผูกเสาศาล (แดง / เหลืองหม่น / เขียว)
	createPart("ShrinePillar", Vector3.new(1.15, 4.2, 1.15), CFrame.new(sx, 3.1, sz), Color3.fromRGB(75, 50, 34), Enum.Material.Wood, spiritHouse)
	createPart("PillarTrimBottom", Vector3.new(1.55, 0.45, 1.55), CFrame.new(sx, 1.3, sz), Color3.fromRGB(92, 64, 42), Enum.Material.Wood, spiritHouse)
	createPart("PillarTrimTop", Vector3.new(1.75, 0.5, 1.75), CFrame.new(sx, 4.95, sz), Color3.fromRGB(92, 64, 42), Enum.Material.Wood, spiritHouse)
	createPart("ClothBandRed", Vector3.new(1.26, 0.32, 1.26), CFrame.new(sx, 3.45, sz), Color3.fromRGB(165, 38, 38), Enum.Material.Fabric, spiritHouse)
	createPart("ClothBandGold", Vector3.new(1.26, 0.32, 1.26), CFrame.new(sx, 3.10, sz), Color3.fromRGB(185, 145, 45), Enum.Material.Fabric, spiritHouse)
	createPart("ClothBandGreen", Vector3.new(1.26, 0.32, 1.26), CFrame.new(sx, 2.75, sz), Color3.fromRGB(42, 115, 62), Enum.Material.Fabric, spiritHouse)

	-- 6.3 ถานชาลา (ลานวางเครื่องเซ่น) + ลูกกรงระเบียงไม้รอบศาล
	createPart("ShrinePlatform", Vector3.new(5.6, 0.4, 5.2), CFrame.new(sx, 5.35, sz), Color3.fromRGB(88, 58, 38), Enum.Material.WoodPlanks, spiritHouse)
	createPart("ShrineSubPlatform", Vector3.new(4.8, 0.3, 4.4), CFrame.new(sx, 5.05, sz), Color3.fromRGB(68, 45, 30), Enum.Material.Wood, spiritHouse)
	-- ขอบระเบียงซ้าย-ขวา-หลัง
	createPart("RailLeft", Vector3.new(0.25, 0.65, 5.0), CFrame.new(sx - 2.65, 5.85, sz), Color3.fromRGB(115, 82, 45), Enum.Material.Wood, spiritHouse)
	createPart("RailRight", Vector3.new(0.25, 0.65, 5.0), CFrame.new(sx + 2.65, 5.85, sz), Color3.fromRGB(115, 82, 45), Enum.Material.Wood, spiritHouse)
	createPart("RailBack", Vector3.new(5.5, 0.65, 0.25), CFrame.new(sx, 5.85, sz + 2.45), Color3.fromRGB(115, 82, 45), Enum.Material.Wood, spiritHouse)
	-- เสาหัวเม็ดมุมระเบียง 4 มุม
	for _, rPos in ipairs({
		Vector3.new(sx - 2.65, 6.0, sz - 2.45),
		Vector3.new(sx + 2.65, 6.0, sz - 2.45),
		Vector3.new(sx - 2.65, 6.0, sz + 2.45),
		Vector3.new(sx + 2.65, 6.0, sz + 2.45),
	}) do
		createPart("CornerPost", Vector3.new(0.38, 1.0, 0.38), CFrame.new(rPos), Color3.fromRGB(145, 108, 48), Enum.Material.Wood, spiritHouse)
	end

	-- 6.4 ตัวเรือนศาลไม้สักสีเลือดหมูเก่า + ซุ้มประตูหน้าศาล
	createPart("ShrineSanctuaryBase", Vector3.new(3.6, 0.35, 3.0), CFrame.new(sx, 5.7, sz + 0.65), Color3.fromRGB(110, 42, 36), Enum.Material.Wood, spiritHouse)
	local shrineHouse = createPart("ShrineTop", Vector3.new(3.2, 2.7, 2.5), CFrame.new(sx, 7.15, sz + 0.7), Color3.fromRGB(108, 36, 34), Enum.Material.WoodPlanks, spiritHouse)
	-- โพรงประตูมืดด้านหน้าเรือนศาล + กรอบซุ้มประตูสีทองโบราณหมองๆ
	createPart("ShrineDoorway", Vector3.new(1.5, 2.0, 0.15), CFrame.new(sx, 6.9, sz - 0.52), Color3.fromRGB(22, 16, 14), Enum.Material.SmoothPlastic, spiritHouse)
	createPart("DoorFrameL", Vector3.new(0.22, 2.2, 0.25), CFrame.new(sx - 0.85, 6.95, sz - 0.52), Color3.fromRGB(155, 118, 48), Enum.Material.Wood, spiritHouse)
	createPart("DoorFrameR", Vector3.new(0.22, 2.2, 0.25), CFrame.new(sx + 0.85, 6.95, sz - 0.52), Color3.fromRGB(155, 118, 48), Enum.Material.Wood, spiritHouse)
	createPart("DoorFrameArch", Vector3.new(2.0, 0.3, 0.3), CFrame.new(sx, 8.1, sz - 0.52), Color3.fromRGB(155, 118, 48), Enum.Material.Wood, spiritHouse)

	-- 6.5 หลังคาจั่วไทยซ้อน 2 ชั้น + ช่อฟ้าใบระกา (โทนไม้เก่าตัดทองโบราณขลังๆ ไม่ฉูดฉาด)
	createPart("ShrineRoofLowerL", Vector3.new(2.7, 0.3, 3.6), CFrame.new(sx - 1.15, 8.85, sz + 0.65) * CFrame.Angles(0, 0, math.rad(36)), Color3.fromRGB(85, 32, 28), Enum.Material.Wood, spiritHouse)
	createPart("ShrineRoofLowerR", Vector3.new(2.7, 0.3, 3.6), CFrame.new(sx + 1.15, 8.85, sz + 0.65) * CFrame.Angles(0, 0, math.rad(-36)), Color3.fromRGB(85, 32, 28), Enum.Material.Wood, spiritHouse)
	createPart("ShrineRoofUpperL", Vector3.new(2.1, 0.28, 3.0), CFrame.new(sx - 0.8, 9.6, sz + 0.65) * CFrame.Angles(0, 0, math.rad(42)), Color3.fromRGB(145, 108, 45), Enum.Material.Wood, spiritHouse)
	createPart("ShrineRoofUpperR", Vector3.new(2.1, 0.28, 3.0), CFrame.new(sx + 0.8, 9.6, sz + 0.65) * CFrame.Angles(0, 0, math.rad(-42)), Color3.fromRGB(145, 108, 45), Enum.Material.Wood, spiritHouse)
	createPart("RoofRidge", Vector3.new(0.3, 0.35, 3.4), CFrame.new(sx, 10.25, sz + 0.65), Color3.fromRGB(165, 125, 52), Enum.Material.Wood, spiritHouse)
	-- ช่อฟ้าปลายแหลมหน้าจั่ว
	createPart("ChofahFront", Vector3.new(0.22, 1.1, 0.22), CFrame.new(sx, 10.7, sz - 1.0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(175, 135, 55), Enum.Material.Wood, spiritHouse)
	createPart("ChofahBack", Vector3.new(0.22, 0.9, 0.22), CFrame.new(sx, 10.6, sz + 2.3) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(175, 135, 55), Enum.Material.Wood, spiritHouse)

	-- 6.6 หุ่นตายายด้านในศาล + ขวดน้ำแดงปักหลอด + พวงมาลัยดาวเรือง + เทียนคู่ไฟสลัว
	createPart("GrandpaDollBody", Vector3.new(0.42, 0.65, 0.35), CFrame.new(sx - 0.32, 6.2, sz - 0.25), Color3.fromRGB(165, 135, 85), Enum.Material.SmoothPlastic, spiritHouse)
	createPart("GrandpaDollHead", Vector3.new(0.32, 0.32, 0.32), CFrame.new(sx - 0.32, 6.7, sz - 0.25), Color3.fromRGB(210, 185, 155), Enum.Material.SmoothPlastic, spiritHouse, Enum.PartType.Ball)
	createPart("GrandmaDollBody", Vector3.new(0.42, 0.62, 0.35), CFrame.new(sx + 0.32, 6.2, sz - 0.25), Color3.fromRGB(145, 65, 85), Enum.Material.SmoothPlastic, spiritHouse)
	createPart("GrandmaDollHead", Vector3.new(0.32, 0.32, 0.32), CFrame.new(sx + 0.32, 6.68, sz - 0.25), Color3.fromRGB(210, 185, 155), Enum.Material.SmoothPlastic, spiritHouse, Enum.PartType.Ball)

	-- ขวดน้ำแดงพร้อมหลอดสีเขียว
	local redBottle = createPart("RedSodaOffering", Vector3.new(0.95, 0.42, 0.42), CFrame.new(sx - 1.65, 6.0, sz - 1.35) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(210, 28, 38), Enum.Material.Glass, spiritHouse, Enum.PartType.Cylinder)
	redBottle.Transparency = 0.2
	createPart("SodaStraw", Vector3.new(0.08, 0.65, 0.08), CFrame.new(sx - 1.60, 6.55, sz - 1.35) * CFrame.Angles(0, 0, math.rad(-15)), Color3.fromRGB(85, 225, 110), Enum.Material.SmoothPlastic, spiritHouse)

	-- พวงมาลัยดาวเรืองวางหน้าศาล
	createPart("MarigoldGarland", Vector3.new(0.75, 0.22, 0.75), CFrame.new(sx + 1.65, 5.66, sz - 1.35), Color3.fromRGB(235, 175, 30), Enum.Material.Fabric, spiritHouse)
	-- แสงเทียนสลัวๆ หน้าศาลพระภูมิ
	local candleFlame = createPart("ShrineCandleFlame", Vector3.new(0.16, 0.28, 0.16), CFrame.new(sx - 1.1, 6.1, sz - 0.9), Color3.fromRGB(255, 185, 75), Enum.Material.Neon, spiritHouse, Enum.PartType.Ball)
	local shrineLight = Instance.new("PointLight")
	shrineLight.Name = "ShrineEerieGlow"
	shrineLight.Brightness = 1.1
	shrineLight.Range = 14
	shrineLight.Color = Color3.fromRGB(255, 160, 75)
	shrineLight.Shadows = true
	shrineLight.Parent = candleFlame

	-- 6.7 กระถางธูปทองเหลือง + ธูป 3 ดอก (ระบบชีวิตของทีม 3 ดอก)
	createPart("IncensePot", Vector3.new(0.65, 0.9, 0.9), CFrame.new(sx, 5.85, sz - 1.55) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(165, 130, 55), Enum.Material.Metal, spiritHouse, Enum.PartType.Cylinder)
	addLabel(shrineHouse, "⛩️ SpiritHouse (ศาลพระภูมิไม้เก่า - ธูป 3 ดอก)", Color3.fromRGB(255, 110, 120))

	for i = 1, 3 do
		local incX = sx - 0.5 + ((i - 1) * 0.5)
		local inc = createPart(
			"Incense" .. i,
			Vector3.new(0.16, 1.25, 0.16),
			CFrame.new(incX, 6.55, sz - 1.55),
			Color3.fromRGB(255, 65, 55),
			Enum.Material.Neon,
			spiritHouse
		)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "IncenseSmoke"
		smoke.Rate = 6
		smoke.Lifetime = NumberRange.new(1.5, 2.5)
		smoke.Speed = NumberRange.new(1, 2)
		smoke.Size = NumberSequence.new(0.18, 0.55)
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Parent = inc
	end

	-- =====================================================
	-- 7. โมเดลจุดเกิด Anomaly แบบมีรูปร่าง (AnomalyProps - 5 Prop Hooks)
	-- =====================================================
	-- 7.1 หุ่นไล่กากลางทุ่งนา (ใช้โมเดลหุ่นไล่กาจาก Toolbox ถ้ามี!)
	if #scarecrowTemplates > 0 then
		local scClone = scarecrowTemplates[1]:Clone()
		scClone.Name = "Scarecrow"
		scClone.Parent = anomalyProps

		if scClone:IsA("Model") then
			local _, origS = scClone:GetBoundingBox()
			if origS.Y > 0.1 then
				local ratio = 7.4 / origS.Y
				scClone:ScaleTo(scClone:GetScale() * ratio)
			end
			local bboxCF, bboxSize = scClone:GetBoundingBox()
			local pivotCF = scClone:GetPivot()
			local bottomY = bboxCF.Position.Y - (bboxSize.Y / 2)
			local offsetFromBottom = pivotCF.Position.Y - bottomY
			scClone:PivotTo(CFrame.new(8, 0.25 + offsetFromBottom, -38))

			local anyPart = scClone.PrimaryPart or scClone:FindFirstChildWhichIsA("BasePart", true)
			if anyPart then
				addLabel(anyPart, "👻 Scarecrow (หุ่นไล่กากลางนา)", Color3.fromRGB(255, 150, 100))
			end
		elseif scClone:IsA("BasePart") then
			if scClone.Size.Y > 0.1 then
				local ratio = 7.4 / scClone.Size.Y
				scClone.Size = scClone.Size * ratio
			end
			scClone.CFrame = CFrame.new(8, 0.25 + (scClone.Size.Y / 2), -38)
			addLabel(scClone, "👻 Scarecrow (หุ่นไล่กากลางนา)", Color3.fromRGB(255, 150, 100))
		end
	else
		local scarecrowModel = Instance.new("Model")
		scarecrowModel.Name = "Scarecrow"
		scarecrowModel.Parent = anomalyProps
		local scPole = createPart("ScarecrowPole", Vector3.new(0.5, 7.2, 0.5), CFrame.new(8, 3.6, -38), Color3.fromRGB(95, 72, 45), Enum.Material.Wood, scarecrowModel)
		createPart("ScarecrowArms", Vector3.new(5.5, 0.4, 0.4), CFrame.new(8, 5.4, -38), Color3.fromRGB(95, 72, 45), Enum.Material.Wood, scarecrowModel)
		local scTorso = createPart("ScarecrowShirt", Vector3.new(2.0, 2.8, 1.0), CFrame.new(8, 4.8, -38), Color3.fromRGB(125, 55, 48), Enum.Material.Fabric, scarecrowModel)
		createPart("ScarecrowHead", Vector3.new(1.3, 1.3, 1.3), CFrame.new(8, 6.8, -38), Color3.fromRGB(185, 160, 110), Enum.Material.Fabric, scarecrowModel, Enum.PartType.Ball)
		createPart("StrawHat", Vector3.new(2.8, 0.4, 2.8), CFrame.new(8, 7.45, -38), Color3.fromRGB(170, 140, 75), Enum.Material.Grass, scarecrowModel)
		scarecrowModel.PrimaryPart = scTorso
		addLabel(scTorso, "👻 Scarecrow (หุ่นไล่กากลางนา)", Color3.fromRGB(255, 150, 100))
	end

	-- 7.2 ผีตานีชุดไทยสีเขียวซ่อนหลังดงกล้วย (PhiTaniGhost)
	local taniModel = Instance.new("Model")
	taniModel.Name = "PhiTaniGhost"
	taniModel.Parent = anomalyProps
	local taniTorso = createPart("TaniDress", Vector3.new(1.8, 4.5, 1.1), CFrame.new(20.5, 2.8, 13.5), Color3.fromRGB(52, 165, 85), Enum.Material.Fabric, taniModel)
	local taniHead = createPart("TaniHead", Vector3.new(1.2, 1.3, 1.2), CFrame.new(20.5, 5.7, 13.5), Color3.fromRGB(210, 225, 215), Enum.Material.SmoothPlastic, taniModel)
	local taniHair = createPart("TaniLongHair", Vector3.new(1.35, 3.2, 0.6), CFrame.new(20.5, 4.8, 13.9), Color3.fromRGB(15, 18, 16), Enum.Material.SmoothPlastic, taniModel)
	taniTorso.Transparency = 0.75
	taniHead.Transparency = 0.75
	taniHair.Transparency = 0.75
	taniModel.PrimaryPart = taniTorso
	addLabel(taniTorso, "👻 PhiTaniGhost (ผีตานีหลังดงกล้วย)", Color3.fromRGB(110, 255, 150))

	-- Prop Hook #1: กระจกเงาบานเก่าพร้อมกรอบไม้ในเพิง
	createPart("MirrorFrame", Vector3.new(0.4, 4.4, 3.2), CFrame.new(14.8, 6.5, 18), Color3.fromRGB(68, 46, 30), Enum.Material.Wood, anomalyProps)
	local oldMirror = createPart("OldMirror", Vector3.new(0.25, 3.8, 2.6), CFrame.new(14.65, 6.5, 18), Color3.fromRGB(170, 210, 220), Enum.Material.Glass, anomalyProps)
	oldMirror.Reflectance = 0.65
	addLabel(oldMirror, "🪞 OldMirror (กระจกเงาข้างฝา - Hook #1)", Color3.fromRGB(170, 230, 255))

	-- Prop Hook #2: รูปตาเจ้าของอู่ & ปฏิทินรายวัน
	local ownerPhoto = createPart("OwnerPhoto", Vector3.new(2.8, 3.4, 0.3), CFrame.new(-6, 7, 27.1), Color3.fromRGB(185, 180, 170), Enum.Material.SmoothPlastic, anomalyProps)
	createPart("WallCalendar", Vector3.new(2.0, 2.6, 0.25), CFrame.new(-2, 6.8, 27.1), Color3.fromRGB(220, 65, 55), Enum.Material.SmoothPlastic, anomalyProps)
	addLabel(ownerPhoto, "🖼️ OwnerPhoto & ปฏิทิน (Hook #2)", Color3.fromRGB(220, 220, 220))

	-- Prop Hook #4: ถังแช่น้ำแข็งสีน้ำเงินพร้อมฝาปิดมุมเพิง
	local iceBoxModel = Instance.new("Model")
	iceBoxModel.Name = "IceBox"
	iceBoxModel.Parent = anomalyProps
	local iceBoxPart = createPart("IceBoxBody", Vector3.new(4.2, 3.0, 2.8), CFrame.new(11, 2.2, 24), Color3.fromRGB(42, 110, 190), Enum.Material.SmoothPlastic, iceBoxModel)
	createPart("IceBoxLid", Vector3.new(4.4, 0.4, 3.0), CFrame.new(11, 3.9, 24), Color3.fromRGB(235, 240, 245), Enum.Material.SmoothPlastic, iceBoxModel)
	iceBoxModel.PrimaryPart = iceBoxPart
	addLabel(iceBoxPart, "🧊 IceBox (ถังแช่น้ำแข็ง - Hook #4)", Color3.fromRGB(130, 200, 255))

	-- Prop Hook #5: ห้องน้ำสังกะสีท้ายดงกล้วย + โอ่งมังกรใส่น้ำ
	local outhouseModel = Instance.new("Model")
	outhouseModel.Name = "TinOuthouse"
	outhouseModel.Parent = anomalyProps
	local outhousePart = createPart("OuthouseBody", Vector3.new(5.2, 8.2, 5.2), CFrame.new(28, 4.4, 38), Color3.fromRGB(102, 92, 84), Enum.Material.CorrodedMetal, outhouseModel)
	createPart("OuthouseDoor", Vector3.new(2.8, 6.8, 0.3), CFrame.new(28, 3.8, 35.3) * CFrame.Angles(0, math.rad(15), 0), Color3.fromRGB(85, 72, 62), Enum.Material.CorrodedMetal, outhouseModel)
	-- โอ่งมังกรหน้าห้องน้ำ
	createPart("DragonWaterJar", Vector3.new(2.8, 2.6, 2.6), CFrame.new(24.2, 1.6, 35.5), Color3.fromRGB(125, 65, 38), Enum.Material.Slate, outhouseModel, Enum.PartType.Ball)
	outhouseModel.PrimaryPart = outhousePart
	addLabel(outhousePart, "🚪 TinOuthouse & โอ่งน้ำ (Hook #5)", Color3.fromRGB(210, 185, 160))

	-- =====================================================
	-- 8. จุดรถวิ่ง 3 จุดบนถนนดิน (VehicleWaypoints)
	-- =====================================================
	local wpSpawn = createPart("SpawnPoint", Vector3.new(3.5, 0.6, 3.5), CFrame.new(-65, 0.8, -8), Color3.fromRGB(80, 255, 120), Enum.Material.Neon, waypoints)
	wpSpawn.Transparency = 0.65
	wpSpawn.CanCollide = false

	local wpStop = createPart("StopPoint", Vector3.new(3.5, 0.6, 3.5), CFrame.new(-2, 0.8, -5), Color3.fromRGB(255, 215, 60), Enum.Material.Neon, waypoints)
	wpStop.Transparency = 0.65
	wpStop.CanCollide = false
	addLabel(wpStop, "🟡 StopPoint (จุดรถจอดเติมน้ำมัน)", Color3.fromRGB(255, 225, 80))

	local wpExit = createPart("ExitPoint", Vector3.new(3.5, 0.6, 3.5), CFrame.new(65, 0.8, -8), Color3.fromRGB(255, 80, 90), Enum.Material.Neon, waypoints)
	wpExit.Transparency = 0.65
	wpExit.CanCollide = false

	MapBuilder.CreateFlashlightTool()

	-- ถ้าอยู่ในโหมด Edit (ตอนปั้นแมพ) ให้เลื่อนกล้องมาที่หน้าเพิงปั๊มหลอดอัตโนมัติ จะได้ไม่ต้องหมุนหากลางอากาศ
	local RunService = game:GetService("RunService")
	if not RunService:IsRunning() and Workspace.CurrentCamera then
		Workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-8, 18, -24), Vector3.new(0, 5, 12))
	end

	print("✨ [MapBuilder] ตกแต่งฉาก 3D แบบละเอียดเสร็จสมบูรณ์! (โหมด Dev สว่าง / ตอนกด Play จะมืดอัตโนมัติ)")
end

-- ฟังก์ชันปรับแสงสว่างสำหรับตอนปั้นแมพ/วางโมเดล (Edit Mode)
function MapBuilder.SetDayDevLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.0
	Lighting.Ambient = Color3.fromRGB(120, 125, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 135)
	Lighting.GlobalShadows = true
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = 0.1
	end
end

-- ฟังก์ชันปรับแสงมืดหลอนตอนเที่ยงคืน (ทำงานอัตโนมัติเฉพาะตอนกด Play เข้าเกม)
function MapBuilder.SetNightLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.3
	Lighting.Ambient = Color3.fromRGB(15, 22, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(15, 22, 20)
	Lighting.GlobalShadows = true
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		atmo = Instance.new("Atmosphere")
		atmo.Name = "RuralAtmosphere"
		atmo.Parent = Lighting
	end
	atmo.Density = 0.42
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(20, 28, 25)
	atmo.Decay = Color3.fromRGB(12, 18, 15)
	atmo.Haze = 2.2
end

-- ฟังก์ชันดึงต้นกล้วยจาก Toolbox (ทั้งต้นใหญ่และต้นเล็กที่โหลดเพิ่ม) ไปปลูกแบบผสมไล่ระดับ "กอกล้วยธรรมชาติ" รอบร้าน!
function MapBuilder.PlantBananaTrees()
	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		mapEnv = Instance.new("Folder")
		mapEnv.Name = "MapEnvironment"
		mapEnv.Parent = Workspace
	end

	local oldGrove = mapEnv:FindFirstChild("BananaGrove")
	if oldGrove then
		oldGrove:Destroy()
	end

	local bananaModel = Instance.new("Model")
	bananaModel.Name = "BananaGrove"
	bananaModel.Parent = mapEnv

	local templates = harvestToolboxBananaTrees()

	-- พิกัดปลูกดงกล้วยตานีแบบผสม 26 ต้น (จัดเป็นกอกล้วย: มีต้นแม่สูงใหญ่ด้านหลัง/กลางกอ + ต้นกลาง + ต้นเล็ก/หน่อกล้วยแซมข้างโคนต้นใหญ่)
	local bananaCoords = {
		-- กอที่ 1: ข้างขวาเพิงใกล้ถนน (ต้นกลาง + ต้นเล็กแซมด้านหน้า ไม่บังสายตาเกินไป)
		{ pos = Vector3.new(20, 0, 9), tier = "medium", height = 9.5, scale = 1.0 },
		{ pos = Vector3.new(18.2, 0, 7.8), tier = "small", height = 6.2, scale = 0.7 },
		{ pos = Vector3.new(25, 0, 12), tier = "large", height = 12.2, scale = 1.15 },
		{ pos = Vector3.new(23.3, 0, 13.2), tier = "small", height = 6.8, scale = 0.75 },

		-- กอที่ 2: ข้างเครื่องปั่นไฟ (ต้นแม่ใบแผ่สวย + ต้นกลาง + หน่อกล้วยเล็ก)
		{ pos = Vector3.new(19, 0, 17), tier = "medium", height = 9.2, scale = 0.95 },
		{ pos = Vector3.new(26, 0, 19), tier = "large", height = 13.0, scale = 1.2 },
		{ pos = Vector3.new(24.4, 0, 17.8), tier = "small", height = 6.5, scale = 0.7 },
		{ pos = Vector3.new(22, 0, 25), tier = "medium", height = 10.0, scale = 1.05 },
		{ pos = Vector3.new(20.5, 0, 23.8), tier = "small", height = 6.0, scale = 0.68 },
		{ pos = Vector3.new(30, 0, 26), tier = "large", height = 12.5, scale = 1.15 },

		-- กอที่ 3: แนวหลังเพิงสังกะสี (ไล่ระดับสูง-กลาง-เล็ก)
		{ pos = Vector3.new(16, 0, 31), tier = "medium", height = 9.5, scale = 1.0 },
		{ pos = Vector3.new(14.5, 0, 29.8), tier = "small", height = 6.4, scale = 0.72 },
		{ pos = Vector3.new(10, 0, 33), tier = "large", height = 12.4, scale = 1.15 },
		{ pos = Vector3.new(3, 0, 34), tier = "medium", height = 8.8, scale = 0.9 },
		{ pos = Vector3.new(-5, 0, 34), tier = "large", height = 11.8, scale = 1.1 },
		{ pos = Vector3.new(-6.6, 0, 32.5), tier = "small", height = 6.3, scale = 0.7 },
		{ pos = Vector3.new(-13, 0, 33), tier = "medium", height = 9.4, scale = 1.0 },

		-- กอที่ 4: ดงกล้วยทึบด้านหลังและรอบห้องน้ำสังกะสี (ต้นแม่สูงใหญ่เป็นฉากหลัง + ต้นเล็กแซมริมทางเดิน)
		{ pos = Vector3.new(33, 0, 15), tier = "large", height = 13.5, scale = 1.25 },
		{ pos = Vector3.new(35, 0, 23), tier = "medium", height = 10.2, scale = 1.05 },
		{ pos = Vector3.new(24, 0, 35), tier = "large", height = 12.6, scale = 1.15 },
		{ pos = Vector3.new(22.3, 0, 33.8), tier = "small", height = 7.0, scale = 0.75 },
		{ pos = Vector3.new(33, 0, 33), tier = "large", height = 12.0, scale = 1.1 },
		{ pos = Vector3.new(19, 0, 39), tier = "medium", height = 9.6, scale = 1.0 },
		{ pos = Vector3.new(17.5, 0, 37.6), tier = "small", height = 6.0, scale = 0.68 },
		{ pos = Vector3.new(34, 0, 41), tier = "large", height = 13.2, scale = 1.2 },
		{ pos = Vector3.new(25, 0, 44), tier = "medium", height = 10.0, scale = 1.05 },
	}

	if #templates > 0 then
		-- เรียงลำดับโมเดลจากความสูงดั้งเดิม (น้อย -> มาก) เพื่อแยกโมเดลต้นเล็กกับโมเดลต้นใหญ่
		local sorted = table.clone(templates)
		table.sort(sorted, function(a, b)
			return getTemplateHeight(a) < getTemplateHeight(b)
		end)

		local smallPool = {}
		local largePool = {}
		local splitIndex = math.max(1, math.floor(#sorted / 2))

		for idx, t in ipairs(sorted) do
			if idx <= splitIndex then
				table.insert(smallPool, t)
			end
			if idx > splitIndex or #sorted == 1 then
				table.insert(largePool, t)
			end
		end

		for i, bData in ipairs(bananaCoords) do
			local chosenTemplate
			if bData.tier == "small" then
				chosenTemplate = smallPool[((i - 1) % #smallPool) + 1]
			elseif bData.tier == "large" then
				chosenTemplate = largePool[((i - 1) % #largePool) + 1]
			else
				chosenTemplate = sorted[((i - 1) % #sorted) + 1]
			end

			placeToolboxTreeAt(chosenTemplate, bananaModel, bData.pos, i, bData.height)
		end
		print("🍌 [MapBuilder] ปลูกดงกล้วยตานีแบบผสม (ต้นแม่ + ต้นกลาง + ต้นเล็กแซมโคน) จากโมเดลทั้ง " .. #templates .. " แบบ รวม 26 ต้นเรียบร้อย!")
	else
		for i, bData in ipairs(bananaCoords) do
			local tree = buildDetailedBananaTree(bananaModel, bData.pos, bData.scale, i)
			if i == 1 and tree.PrimaryPart then
				addLabel(tree.PrimaryPart, "🍌 ดงกล้วยตานี (BananaGrove)", Color3.fromRGB(110, 235, 120))
			end
		end
	end

	MapBuilder.PaintTerrainRoad()
	MapBuilder.AddSacredBanyanZone()
	MapBuilder.AddSideRiceFields()
	MapBuilder.ReplaceHillsWithInvisibleWalls()
	MapBuilder.BuildCompactPerimeter()
end

-- =====================================================
-- ฟังก์ชันพิเศษ: เพิ่มโซนด้านขวา "ต้นไทรใหญ่พันผ้าสามสี + ม้าหินอ่อนเก่า + ตุ๊กตานางรำ/ม้าลายแตกๆ + Anomaly เงาคนหลังต้นไม้"
-- โดยอ้างอิงจากตำแหน่งปัจจุบันของศาลพระภูมิที่คุณวางไว้ และไม่แตะต้องของเดิมชิ้นอื่นเลย!
-- =====================================================
function MapBuilder.AddSacredBanyanZone()
	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		mapEnv = Instance.new("Folder")
		mapEnv.Name = "MapEnvironment"
		mapEnv.Parent = Workspace
	end

	local anomalyFolder = Workspace:FindFirstChild("AnomalyProps")
	if not anomalyFolder then
		anomalyFolder = Instance.new("Folder")
		anomalyFolder.Name = "AnomalyProps"
		anomalyFolder.Parent = Workspace
	end

	-- ลบเฉพาะโซนต้นไทรเดิม (ถ้าเคยรันคำสั่งนี้แล้ว) เพื่อไม่ให้สร้างซ้ำทับกัน
	local oldZone = mapEnv:FindFirstChild("SacredBanyanZone")
	if oldZone then
		oldZone:Destroy()
	end
	local oldShadow = anomalyFolder:FindFirstChild("BanyanShadowAnomaly")
	if oldShadow then
		oldShadow:Destroy()
	end

	-- อ่านตำแหน่งปัจจุบันของศาลพระภูมิที่คุณจัดวางไว้ในฉาก
	local sx, groundY, sz = -22, 0.5, 12
	local spiritHouse = Workspace:FindFirstChild("SpiritHouse")
	if spiritHouse and spiritHouse:IsA("Model") then
		local cf, s = spiritHouse:GetBoundingBox()
		sx = cf.Position.X
		sz = cf.Position.Z
		groundY = math.max(0.2, cf.Position.Y - (s.Y * 0.5))
	end

	local banyanZone = Instance.new("Model")
	banyanZone.Name = "SacredBanyanZone"
	banyanZone.Parent = mapEnv

	-- พิกัดศูนย์กลางต้นไทรใหญ่ (อยู่เยื้องด้านหลังและทางขวาของศาลพระภูมิ)
	local tx = sx - 10.5
	local tz = sz + 10.5
	local ty = groundY

	-- =====================================================
	-- 1. ต้นไทรโบราณแผ่กิ่งก้านและรากอากาศ + ผ้าแพรสามสี (SacredBanyanTree)
	-- =====================================================
	local treeModel = Instance.new("Model")
	treeModel.Name = "SacredBanyanTree"
	treeModel.Parent = banyanZone

	-- ลำต้นหลักขนาดใหญ่และผิวเปลือกไม้ขรุขระ
	local mainTrunk = createPart(
		"BanyanMainTrunk",
		Vector3.new(4.6, 14.5, 4.6),
		CFrame.new(tx, ty + 7.0, tz) * CFrame.Angles(math.rad(-3), math.rad(15), math.rad(4)),
		Color3.fromRGB(58, 43, 31),
		Enum.Material.Wood,
		treeModel
	)
	treeModel.PrimaryPart = mainTrunk
	addLabel(mainTrunk, "🌳 ต้นไทรใหญ่พันผ้าสามสี (Anomaly: ผ้าสีเลือด / เงาคนแอบ)", Color3.fromRGB(255, 195, 95))

	-- ลำต้นรองที่บิดพันกันให้ดูเป็นต้นไทรอายุร้อยปี
	for idx, tOff in ipairs({
		{ off = Vector3.new(1.6, 5.8, -1.1), s = Vector3.new(2.4, 12.0, 2.4), ang = Vector3.new(5, 25, -6) },
		{ off = Vector3.new(-1.7, 6.0, 0.9), s = Vector3.new(2.6, 12.5, 2.5), ang = Vector3.new(-4, -20, 7) },
		{ off = Vector3.new(0.4, 6.2, 1.8), s = Vector3.new(2.2, 12.0, 2.2), ang = Vector3.new(-7, 10, -3) },
	}) do
		createPart(
			"TwistedTrunk_" .. idx,
			tOff.s,
			CFrame.new(tx + tOff.off.X, ty + tOff.off.Y, tz + tOff.off.Z)
				* CFrame.Angles(math.rad(tOff.ang.X), math.rad(tOff.ang.Y), math.rad(tOff.ang.Z)),
			Color3.fromRGB(52, 38, 27),
			Enum.Material.Wood,
			treeModel
		)
	end

	-- พูพอนและรากไทรแผ่ยึดพื้นดิน 8 ทิศ
	for r = 1, 8 do
		local ang = math.rad((r - 1) * 45 + 12)
		local rDist = 3.2 + (r % 2) * 0.8
		local rx = tx + math.cos(ang) * rDist
		local rz = tz + math.sin(ang) * rDist
		createPart(
			"ButtressRoot_" .. r,
			Vector3.new(1.3, 4.8, 2.6),
			CFrame.new(Vector3.new(rx, ty + 1.4, rz), Vector3.new(tx, ty + 3.2, tz)) * CFrame.Angles(math.rad(-28), 0, 0),
			Color3.fromRGB(54, 40, 28),
			Enum.Material.Wood,
			treeModel
		)
	end

	-- กิ่งก้านใหญ่แผ่คลุมหลังศาลพระภูมิและม้าหินอ่อน
	local branches = {
		{ pos = Vector3.new(4.5, 13.5, -4.2), size = Vector3.new(2.0, 11.5, 2.0), rot = Vector3.new(42, -35, -38) }, -- แผ่คลุมเหนือศาลพระภูมิ
		{ pos = Vector3.new(-5.2, 13.2, -3.5), size = Vector3.new(2.1, 12.0, 2.1), rot = Vector3.new(38, 40, 44) }, -- แผ่คลุมเหนือม้าหินอ่อน
		{ pos = Vector3.new(3.8, 14.2, 4.0), size = Vector3.new(1.9, 10.5, 1.9), rot = Vector3.new(-36, 25, -32) },
		{ pos = Vector3.new(-4.5, 14.0, 4.2), size = Vector3.new(2.0, 11.0, 2.0), rot = Vector3.new(-40, -30, 36) },
		{ pos = Vector3.new(0, 15.2, -5.0), size = Vector3.new(1.8, 10.0, 1.8), rot = Vector3.new(48, 0, 0) },
	}
	for idx, b in ipairs(branches) do
		createPart(
			"BanyanBranch_" .. idx,
			b.size,
			CFrame.new(tx + b.pos.X, ty + b.pos.Y, tz + b.pos.Z)
				* CFrame.Angles(math.rad(b.rot.X), math.rad(b.rot.Y), math.rad(b.rot.Z)),
			Color3.fromRGB(56, 42, 30),
			Enum.Material.Wood,
			treeModel
		)
	end

	-- รากอากาศต้นไทร (Aerial Roots) ห้อยระย้าลงมาจากกิ่งไม้ สร้างบรรยากาศหลอนขลังๆ
	for a = 1, 14 do
		local aAng = math.rad(a * 25.7)
		local aRad = 4.2 + (a % 4) * 1.6
		local ax = tx + math.cos(aAng) * aRad
		local az = tz + math.sin(aAng) * aRad
		local aLen = 5.5 + (a % 3) * 1.8
		local aerialRoot = createPart(
			"AerialRoot_" .. a,
			Vector3.new(0.22, aLen, 0.22),
			CFrame.new(ax, ty + 13.5 - (aLen * 0.5), az) * CFrame.Angles(math.rad((a % 3) - 1) * 3, 0, math.rad(((a + 1) % 3) - 1) * 3),
			Color3.fromRGB(68, 52, 36),
			Enum.Material.Wood,
			treeModel
		)
		aerialRoot.CanCollide = false
	end

	-- พุ่มใบไทรหนาทึบ 9 ก้อนซ้อนกัน แผ่ร่มเงามืดครึ้มด้านขวาของฉาก
	local canopyClusters = {
		{ off = Vector3.new(0, 18.5, 0), s = Vector3.new(16, 10, 16), col = Color3.fromRGB(34, 52, 28) },
		{ off = Vector3.new(6.5, 16.2, -5.5), s = Vector3.new(14, 8.5, 14), col = Color3.fromRGB(38, 58, 32) }, -- คลุมเหนือศาลพระภูมิ
		{ off = Vector3.new(-7.0, 15.8, -4.5), s = Vector3.new(14.5, 8.5, 14), col = Color3.fromRGB(32, 48, 26) }, -- คลุมเหนือม้าหินอ่อน
		{ off = Vector3.new(5.5, 16.5, 5.5), s = Vector3.new(13, 8, 13), col = Color3.fromRGB(36, 54, 30) },
		{ off = Vector3.new(-6.0, 16.5, 5.5), s = Vector3.new(13.5, 8.5, 13.5), col = Color3.fromRGB(30, 46, 25) },
		{ off = Vector3.new(0, 15.5, -7.5), s = Vector3.new(12, 7.5, 11), col = Color3.fromRGB(40, 60, 34) },
		{ off = Vector3.new(0, 21.5, 0), s = Vector3.new(13, 7.5, 13), col = Color3.fromRGB(42, 62, 35) },
	}
	for idx, c in ipairs(canopyClusters) do
		local foliage = createPart(
			"BanyanCanopy_" .. idx,
			c.s,
			CFrame.new(tx + c.off.X, ty + c.off.Y, tz + c.off.Z) * CFrame.Angles(0, math.rad(idx * 37), 0),
			c.col,
			Enum.Material.Grass,
			treeModel,
			Enum.PartType.Ball
		)
		foliage.CanCollide = false
	end

	-- =====================================================
	-- 2. ผ้าแพรสามสีพันรอบลำต้นไทร + พวงมาลัย (ThaiRibbons - Anomaly เปลี่ยนเป็นสีแดงเลือดได้)
	-- =====================================================
	local ribbonModel = Instance.new("Model")
	ribbonModel.Name = "SacredThaiRibbons"
	ribbonModel.Parent = treeModel

	local ribbonData = {
		{ name = "RibbonRed", yOff = 4.9, col = Color3.fromRGB(205, 32, 32), tilt = 4 },
		{ name = "RibbonYellow", yOff = 4.2, col = Color3.fromRGB(235, 185, 35), tilt = -3 },
		{ name = "RibbonGreen", yOff = 3.5, col = Color3.fromRGB(42, 165, 72), tilt = 2 },
	}
	for _, rInfo in ipairs(ribbonData) do
		local rib = createPart(
			rInfo.name,
			Vector3.new(5.55, 0.58, 5.55),
			CFrame.new(tx, ty + rInfo.yOff, tz) * CFrame.Angles(math.rad(rInfo.tilt), math.rad(15), 0),
			rInfo.col,
			Enum.Material.Fabric,
			ribbonModel
		)
		rib:SetAttribute("NormalColor", rInfo.col)
		rib:SetAttribute("AnomalyBloodColor", Color3.fromRGB(135, 8, 8))
	end

	-- ชายผ้าสามสีผูกปมทิ้งชายลงมาด้านหน้าลำต้น
	local tailRed = createPart(
		"RibbonTailRed",
		Vector3.new(0.55, 2.6, 0.25),
		CFrame.new(tx + 0.8, ty + 2.9, tz - 2.75) * CFrame.Angles(math.rad(-8), 0, math.rad(6)),
		Color3.fromRGB(205, 32, 32),
		Enum.Material.Fabric,
		ribbonModel
	)
	tailRed:SetAttribute("NormalColor", Color3.fromRGB(205, 32, 32))
	local tailYellow = createPart(
		"RibbonTailYellow",
		Vector3.new(0.55, 2.4, 0.25),
		CFrame.new(tx + 0.25, ty + 2.8, tz - 2.78) * CFrame.Angles(math.rad(-6), 0, math.rad(-5)),
		Color3.fromRGB(235, 185, 35),
		Enum.Material.Fabric,
		ribbonModel
	)
	tailYellow:SetAttribute("NormalColor", Color3.fromRGB(235, 185, 35))

	-- พวงมาลัยดาวเรืองคล้องหน้าผ้าสามสี
	createPart(
		"TreeGarland",
		Vector3.new(0.9, 1.2, 0.35),
		CFrame.new(tx + 0.5, ty + 4.3, tz - 2.85),
		Color3.fromRGB(240, 175, 25),
		Enum.Material.Fabric,
		ribbonModel
	)

	-- =====================================================
	-- 3. ตุ๊กตาม้าลายแตกๆ & ตุ๊กตานางรำเก่าทิ้งไว้โคนต้นไทร (BrokenOfferings)
	-- =====================================================
	local offeringsModel = Instance.new("Model")
	offeringsModel.Name = "BrokenOfferings"
	offeringsModel.Parent = banyanZone

	-- 3.1 ตุ๊กตาม้าลายแก้บนเก่าๆ (ตัวที่ 1 ยืนเอียงขาหัก + ตัวที่ 2 ล้มตะแคงอยู่ข้างรากไทร)
	local zx, zz = tx + 2.8, tz - 3.6
	local zebra1 = Instance.new("Model")
	zebra1.Name = "BrokenZebraStatue"
	zebra1.Parent = offeringsModel
	local zBody = createPart(
		"ZebraBody",
		Vector3.new(0.85, 0.75, 1.65),
		CFrame.new(zx, ty + 0.95, zz) * CFrame.Angles(math.rad(8), math.rad(-25), math.rad(-14)),
		Color3.fromRGB(225, 222, 215),
		Enum.Material.Concrete,
		zebra1
	)
	-- ลายแถบสีดำบนตัวม้าลาย
	for s = -2, 2 do
		createPart(
			"ZebraStripe_" .. s,
			Vector3.new(0.88, 0.77, 0.14),
			zBody.CFrame * CFrame.new(0, 0, s * 0.28),
			Color3.fromRGB(28, 28, 30),
			Enum.Material.Concrete,
			zebra1
		)
	end
	createPart(
		"ZebraNeck",
		Vector3.new(0.55, 0.95, 0.55),
		zBody.CFrame * CFrame.new(0, 0.55, -0.65) * CFrame.Angles(math.rad(25), 0, 0),
		Color3.fromRGB(225, 222, 215),
		Enum.Material.Concrete,
		zebra1
	)
	-- หัวม้าลายที่หักตกอยู่ข้างๆ โคนต้น
	createPart(
		"BrokenZebraHead",
		Vector3.new(0.5, 0.45, 0.85),
		CFrame.new(zx + 0.65, ty + 0.25, zz - 0.85) * CFrame.Angles(math.rad(15), math.rad(40), math.rad(75)),
		Color3.fromRGB(215, 212, 205),
		Enum.Material.Concrete,
		zebra1
	)
	for _, legOff in ipairs({ Vector3.new(-0.28, -0.55, -0.55), Vector3.new(0.28, -0.55, -0.55), Vector3.new(-0.28, -0.55, 0.55) }) do
		createPart("ZebraLeg", Vector3.new(0.22, 0.75, 0.22), zBody.CFrame * CFrame.new(legOff), Color3.fromRGB(220, 218, 210), Enum.Material.Concrete, zebra1)
	end

	-- 3.2 ตุ๊กตานางรำชุดไทยเก่าชฎาเอียงวางทิ้งไว้โคนรากไทร
	local dx, dz = tx + 1.2, tz - 4.1
	local dancerModel = Instance.new("Model")
	dancerModel.Name = "OldNangRamDoll"
	dancerModel.Parent = offeringsModel
	createPart("DancerBase", Vector3.new(0.75, 0.2, 0.75), CFrame.new(dx, ty + 0.12, dz), Color3.fromRGB(110, 35, 30), Enum.Material.Concrete, dancerModel)
	createPart("DancerSkirt", Vector3.new(0.55, 0.85, 0.45), CFrame.new(dx, ty + 0.62, dz) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(175, 130, 42), Enum.Material.Fabric, dancerModel)
	createPart("DancerTorso", Vector3.new(0.48, 0.65, 0.35), CFrame.new(dx, ty + 1.32, dz) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(185, 48, 42), Enum.Material.Fabric, dancerModel)
	createPart("DancerHead", Vector3.new(0.42, 0.42, 0.42), CFrame.new(dx, ty + 1.82, dz), Color3.fromRGB(228, 215, 195), Enum.Material.SmoothPlastic, dancerModel, Enum.PartType.Ball)
	-- ชฎาทองเหลืองเก่าๆ บนหัวนางรำ
	createPart("DancerCrown", Vector3.new(0.28, 0.55, 0.28), CFrame.new(dx, ty + 2.22, dz) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(195, 155, 45), Enum.Material.Metal, dancerModel)

	-- =====================================================
	-- 4. ชุดโต๊ะม้าหินอ่อนเก่าขึ้นตะไคร่น้ำใต้ร่มไทร (OldMarbleBenchSet)
	-- =====================================================
	local benchModel = Instance.new("Model")
	benchModel.Name = "OldMarbleBenchSet"
	benchModel.Parent = banyanZone

	local bx, bz = sx - 14.5, sz - 0.5
	-- ขาตั้งและแผ่นโต๊ะม้าหินอ่อนกลม
	createPart("MarbleTablePedestal", Vector3.new(1.8, 2.2, 1.8), CFrame.new(bx, ty + 1.1, bz), Color3.fromRGB(128, 132, 124), Enum.Material.Concrete, benchModel)
	local tableTop = createPart(
		"MarbleTableTop",
		Vector3.new(0.45, 4.4, 4.4),
		CFrame.new(bx, ty + 2.3, bz) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(148, 152, 142),
		Enum.Material.Concrete,
		benchModel,
		Enum.PartType.Cylinder
	)
	addLabel(tableTop, "🪑 ม้าหินอ่อนเก่าใต้ต้นไทร", Color3.fromRGB(190, 215, 185))

	-- เก้าอี้ม้าหินอ่อนโค้ง 3 ตัวรอบโต๊ะ (ตัวหนึ่งเอียงทรุดลงในดิน)
	for idx, sData in ipairs({
		{ off = Vector3.new(-3.4, 0, 0), rotY = 90, tilt = 0 },
		{ off = Vector3.new(3.4, 0, 0), rotY = -90, tilt = 6 },
		{ off = Vector3.new(0, 0, 3.4), rotY = 0, tilt = -4 },
	}) do
		local scf = CFrame.new(bx + sData.off.X, ty + 0.75, bz + sData.off.Z)
			* CFrame.Angles(math.rad(sData.tilt), math.rad(sData.rotY), 0)
		createPart("MarbleStoolLeg1_" .. idx, Vector3.new(0.45, 1.3, 1.1), scf * CFrame.new(-0.9, -0.1, 0), Color3.fromRGB(120, 125, 116), Enum.Material.Concrete, benchModel)
		createPart("MarbleStoolLeg2_" .. idx, Vector3.new(0.45, 1.3, 1.1), scf * CFrame.new(0.9, -0.1, 0), Color3.fromRGB(120, 125, 116), Enum.Material.Concrete, benchModel)
		createPart("MarbleStoolSeat_" .. idx, Vector3.new(2.8, 0.32, 1.35), scf * CFrame.new(0, 0.6, 0), Color3.fromRGB(145, 150, 140), Enum.Material.Concrete, benchModel)
	end

	-- =====================================================
	-- 5. Anomaly เงาคนยืนแอบชะโงกหน้าหลังต้นไทรใหญ่ (BanyanShadowAnomaly)
	-- =====================================================
	local shadowModel = Instance.new("Model")
	shadowModel.Name = "BanyanShadowAnomaly"
	shadowModel.Parent = anomalyFolder

	local shX, shZ = tx - 2.3, tz - 0.8
	local shadowTorso = createPart(
		"ShadowTorso",
		Vector3.new(1.8, 5.2, 0.9),
		CFrame.new(shX, ty + 2.8, shZ) * CFrame.Angles(0, math.rad(15), math.rad(14)),
		Color3.fromRGB(8, 8, 10),
		Enum.Material.SmoothPlastic,
		shadowModel
	)
	local shadowHead = createPart(
		"ShadowHead",
		Vector3.new(1.35, 1.45, 1.35),
		CFrame.new(shX - 0.55, ty + 5.8, shZ - 0.2) * CFrame.Angles(0, math.rad(15), math.rad(22)),
		Color3.fromRGB(8, 8, 10),
		Enum.Material.SmoothPlastic,
		shadowModel,
		Enum.PartType.Ball
	)
	-- ดวงตาสีขาวซีดเรืองแสงจางๆ ของเงาปริศนาที่แอบมองมาจากหลังต้นไทร
	local eyeL = createPart("ShadowEyeL", Vector3.new(0.16, 0.12, 0.12), shadowHead.CFrame * CFrame.new(-0.24, 0.1, -0.62), Color3.fromRGB(235, 240, 220), Enum.Material.Neon, shadowModel, Enum.PartType.Ball)
	local eyeR = createPart("ShadowEyeR", Vector3.new(0.16, 0.12, 0.12), shadowHead.CFrame * CFrame.new(0.24, 0.1, -0.62), Color3.fromRGB(235, 240, 220), Enum.Material.Neon, shadowModel, Enum.PartType.Ball)

	-- ซ่อนเงาไว้ในสถานะปกติ (จะโผล่ออกมาเฉพาะตอนเกิด Anomaly เงาคนหลังต้นไทร!)
	for _, p in ipairs({ shadowTorso, shadowHead, eyeL, eyeR }) do
		p.CanCollide = false
		p.Transparency = 0.35 -- ให้เห็นเป็นเงาตะคุ่มๆ ในโหมดจัดฉาก (เวลาเริ่มเกมจริงสามารถสั่งซ่อน/เปิดได้)
	end
	shadowModel.PrimaryPart = shadowHead
	addLabel(shadowHead, "👤 BanyanShadowAnomaly (เงาคนแอบหลังต้นไทร)", Color3.fromRGB(215, 110, 255))

	print("🌳 [MapBuilder] สร้างโซนด้านขวา: ต้นไทรใหญ่พันผ้าสามสี + ม้าหินอ่อนเก่า + ตุ๊กตาม้าลาย/นางรำ + เงาคนหลังต้นไม้ เรียบร้อย!")
end

-- =====================================================
-- ฟังก์ชันพิเศษ: เปลี่ยนเฉพาะ "ถนน" ให้เป็นพื้น Terrain ระบายสีธรรมชาติ (โดยไม่แตะต้องหรือรีเซ็ตของที่คุณลากจัดวางไว้แล้ว!)
-- =====================================================
function MapBuilder.PaintTerrainRoad()
	local terrain = Workspace.Terrain
	if not terrain then
		return
	end

	-- 1. ลบเฉพาะแผ่น Part ถนนแข็งๆ และแท่งคันนาเหลี่ยมๆ ที่โผล่เกะกะออก (ห้ามลบเสาไฟ, หลักกิโล, ศาลพระภูมิ, เพิงร้าน หรือต้นไม้เด็ดขาด!)
	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if mapEnv then
		local partsToRemove = {
			RoadSurface = true,
			WheelTrack1 = true,
			WheelTrack2 = true,
			ShopDirtYard = true,
			RiceBund_Front = true,
			RiceBund_Mid = true,
			RiceBund_Right = true,
		}
		for _, desc in ipairs(mapEnv:GetDescendants()) do
			if desc:IsA("BasePart") then
				local n = desc.Name
				if
					partsToRemove[n]
					or string.find(n, "^RoadShoulder")
					or string.find(n, "^RoughMudPatch")
					or string.find(n, "^BundMound_")
					or string.find(n, "^EarthMound_")
				then
					desc:Destroy()
				end
			end
		end
	end

	-- 2. ตั้งค่าโทนสีดินดำชื้น (Ground) และโคลนดำหลังฝนตก (Mud) ให้มืดขรึม สบายตา ไม่สว่างแสบตา!
	pcall(function()
		terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(52, 46, 40)) -- สีดินดำปนหินคลุกมืดๆ สบายตา
		terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(36, 32, 28)) -- สีโคลนดำชื้นตรงร่องกลางถนนและก้นนา
		terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(55, 68, 42)) -- ดรอปสีพื้นหญ้าให้เข้มรับกับดินดำ
		terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(52, 66, 40))
	end)

	-- 3. ใช้ ReplaceMaterial ระบายสี (Paint) ลงบนพื้น Terrain โดยไม่เปลี่ยนความสูงของพื้น!
	local function paintRegion(center: Vector3, size: Vector3, targetMat: Enum.Material)
		local half = size * 0.5
		local region = Region3.new(center - half, center + half):ExpandToGrid(4)
		for _, srcMat in ipairs({ Enum.Material.LeafyGrass, Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Mud }) do
			if srcMat ~= targetMat then
				pcall(function()
					terrain:ReplaceMaterial(region, 4, srcMat, targetMat)
				end)
			end
		end
	end

	-- ระบายสีพื้นถนนหลักเป็นดินลูกรัง (Ground) ยาวตลอดแนว
	paintRegion(Vector3.new(0, 0, -12), Vector3.new(350, 8, 16), Enum.Material.Ground)
	-- ระบายสีร่องล้อรถตรงกลางถนนเป็นดินโคลนเข้ม (Mud) ผสมให้มีมิติ
	paintRegion(Vector3.new(0, 0, -12), Vector3.new(350, 8, 6), Enum.Material.Mud)
	-- ระบายสีลานดินหน้าเพิงร้านเป็นดินลูกรัง (Ground) เชื่อมกับถนน
	paintRegion(Vector3.new(0, 0, 4), Vector3.new(36, 8, 16), Enum.Material.Ground)

	print("🛣️ [MapBuilder] เปลี่ยนถนนเป็นพื้น Terrain ระบายสีธรรมชาติเรียบร้อย (ของที่คุณจัดวางไว้ยังอยู่ครบ 100% ไม่หาย!)")
end

-- =====================================================
-- ฟังก์ชันพิเศษ: สร้างทุ่งนาขนาบข้างซ้าย-ขวาของเพิงร้าน (ขุดแอ่งนาบุ๋ม + คันนานูนธรรมชาติ + น้ำในนา + กอข้าว Tall Grass)
-- โดยเว้นระยะให้พ้นดงกล้วยฝั่งซ้ายและพ้นต้นไทร/ม้าหินอ่อนฝั่งขวาอัตโนมัติ ไม่แตะต้องของเดิมเลย!
-- =====================================================
function MapBuilder.AddSideRiceFields()
	local terrain = Workspace.Terrain
	local ServerStorage = game:GetService("ServerStorage")

	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		mapEnv = Instance.new("Folder")
		mapEnv.Name = "MapEnvironment"
		mapEnv.Parent = Workspace
	end

	-- ลบเฉพาะทุ่งนาซ้าย-ขวาเดิม (ถ้าเคยรันคำสั่งนี้แล้ว) เพื่อไม่ให้ซ้อนทับกัน
	for _, oldName in ipairs({ "SideRiceFields", "LeftRiceField", "RightRiceField" }) do
		local oldObj = mapEnv:FindFirstChild(oldName)
		if oldObj then
			oldObj:Destroy()
		end
	end

	local leftFieldModel = Instance.new("Model")
	leftFieldModel.Name = "LeftRiceField"
	leftFieldModel.Parent = mapEnv

	local rightFieldModel = Instance.new("Model")
	rightFieldModel.Name = "RightRiceField"
	rightFieldModel.Parent = mapEnv

	-- คำนวณขอบเขตดงกล้วย (ฝั่งซ้ายของจอ = +X) และโซนต้นไทร/ศาลพระภูมิ (ฝั่งขวาของจอ = -X) อัตโนมัติเพื่อไม่ให้กินพื้นที่ของเดิม
	local leftInnerEdgeX = 39 -- ขอบนอกของดงกล้วยฝั่งซ้าย
	local bananaGrove = mapEnv:FindFirstChild("BananaGrove")
	if bananaGrove and bananaGrove:IsA("Model") then
		local cf, s = bananaGrove:GetBoundingBox()
		leftInnerEdgeX = math.max(38, math.ceil(cf.Position.X + s.X * 0.5 + 3.5))
	end

	local rightInnerEdgeX = -42 -- ขอบนอกของต้นไทรและม้าหินอ่อนฝั่งขวา
	local banyanZone = mapEnv:FindFirstChild("SacredBanyanZone")
	if banyanZone and banyanZone:IsA("Model") then
		local cf, s = banyanZone:GetBoundingBox()
		rightInnerEdgeX = math.min(-40, math.floor(cf.Position.X - s.X * 0.5 - 2.5))
	end

	local zFront = 5
	local zBack = 53
	local centerZ = (zFront + zBack) * 0.5
	local depthZ = zBack - zFront

	local leftOuterEdgeX = 96
	local rightOuterEdgeX = -96

	local centerXL = (leftInnerEdgeX + leftOuterEdgeX) * 0.5
	local widthL = leftOuterEdgeX - leftInnerEdgeX

	local centerXR = (rightOuterEdgeX + rightInnerEdgeX) * 0.5
	local widthR = rightInnerEdgeX - rightOuterEdgeX

	-- 1. ขุดแอ่งนาบุ๋มลึกลงไป + ปูพื้นโคลนใต้น้ำ + ปั้นคันนานูนๆ ด้วย Voxel Terrain เหมือนทุ่งนาฝั่งตรงข้ามเป๊ะ!
	if terrain then
		-- แอ่งนาฝั่งซ้ายของจอ (+X ถัดจากดงกล้วย)
		terrain:FillBlock(CFrame.new(centerXL, -1.2, centerZ), Vector3.new(widthL, 3.0, depthZ), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(centerXL, -2.8, centerZ), Vector3.new(widthL + 2, 2.8, depthZ + 2), Enum.Material.Mud)

		-- แอ่งนาฝั่งขวาของจอ (-X ถัดจากต้นไทรและศาลพระภูมิ)
		terrain:FillBlock(CFrame.new(centerXR, -1.2, centerZ), Vector3.new(widthR, 3.0, depthZ), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(centerXR, -2.8, centerZ), Vector3.new(widthR + 2, 2.8, depthZ + 2), Enum.Material.Mud)

		-- คันนากั้นริมถนน (Z = 2.5) ทั้งฝั่งซ้ายและฝั่งขวา
		for mx = leftInnerEdgeX - 2, leftOuterEdgeX + 2, 8 do
			local seed = math.abs(mx * 17)
			local r = 3.1 + (seed % 20) * 0.08
			terrain:FillBall(Vector3.new(mx, -1.4 + (seed % 4) * 0.12, 2.5 + ((seed % 3) - 1) * 0.5), r, Enum.Material.Grass)
		end
		for mx = rightOuterEdgeX - 2, rightInnerEdgeX + 2, 8 do
			local seed = math.abs(mx * 19)
			local r = 3.1 + (seed % 20) * 0.08
			terrain:FillBall(Vector3.new(mx, -1.4 + (seed % 4) * 0.12, 2.5 + ((seed % 3) - 1) * 0.5), r, Enum.Material.Grass)
		end

		-- คันนาแนวลึก (กั้นขอบดงกล้วย, แบ่งครึ่งแปลงนาซ้าย, กั้นขอบต้นไทร, แบ่งครึ่งแปลงนาขวา)
		local midXL = math.floor((leftInnerEdgeX + leftOuterEdgeX) * 0.5)
		local midXR = math.floor((rightOuterEdgeX + rightInnerEdgeX) * 0.5)
		for mz = zFront - 1, zBack + 1, 6 do
			local s2 = math.abs(mz * 23)
			local r = 3.0 + (s2 % 10) * 0.08
			-- คันนาฝั่งซ้าย (+X)
			terrain:FillBall(Vector3.new(leftInnerEdgeX - 1.5 + ((s2 % 3) - 1) * 0.4, -1.4, mz), r, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(midXL + ((s2 % 3) - 1) * 0.4, -1.5, mz), r, Enum.Material.Grass)
			-- คันนาฝั่งขวา (-X)
			terrain:FillBall(Vector3.new(rightInnerEdgeX + 1.5 + ((s2 % 3) - 1) * 0.4, -1.4, mz), r, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(midXR + ((s2 % 3) - 1) * 0.4, -1.5, mz), r, Enum.Material.Grass)
		end
	end

	-- 2. แผ่นผิวน้ำในนาสะท้อนแสงจันทร์ (แยก Model ฝั่งซ้ายกับฝั่งขวาเป็นคนละก้อนกัน!)
	local waterLeft = createPart(
		"PaddyWater_Left",
		Vector3.new(widthL, 0.4, depthZ),
		CFrame.new(centerXL, 0.2, centerZ),
		Color3.fromRGB(22, 36, 28),
		Enum.Material.Glass,
		leftFieldModel
	)
	waterLeft.Reflectance = 0.15
	leftFieldModel.PrimaryPart = waterLeft

	local waterRight = createPart(
		"PaddyWater_Right",
		Vector3.new(widthR, 0.4, depthZ),
		CFrame.new(centerXR, 0.2, centerZ),
		Color3.fromRGB(22, 36, 28),
		Enum.Material.Glass,
		rightFieldModel
	)
	waterRight.Reflectance = 0.15
	rightFieldModel.PrimaryPart = waterRight

	-- 3. ปลูกกอข้าว (Tall Grass จากคลัง ToolboxGrassTemplates) เรียงแยกเข้า LeftRiceField และ RightRiceField
	local grassTemplates = {}
	local grassFolder = ServerStorage:FindFirstChild("ToolboxGrassTemplates")
	if grassFolder then
		grassTemplates = grassFolder:GetChildren()
	end
	if #grassTemplates == 0 then
		local _, g, _, _ = harvestAllToolboxAssets()
		grassTemplates = g
	end

	local midXL = math.floor((leftInnerEdgeX + leftOuterEdgeX) * 0.5)
	local midXR = math.floor((rightOuterEdgeX + rightInnerEdgeX) * 0.5)
	local grassIdx = 0

	-- ปลูกกอข้าวฝั่งซ้าย (+X) เข้าไปใน LeftRiceField
	for rx = leftInnerEdgeX + 4.5, leftOuterEdgeX - 4.5, 7.5 do
		if math.abs(rx - midXL) > 3.2 then -- เว้นแนวสันคันนากลาง
			for rz = zFront + 3.5, zBack - 3.5, 6.5 do
				grassIdx += 1
				local gx = rx + ((grassIdx * 37) % 3) - 1
				local gz = rz + ((grassIdx * 53) % 3) - 1
				if #grassTemplates > 0 then
					local chosenGrass = grassTemplates[((grassIdx - 1) % #grassTemplates) + 1]
					local targetH = 2.6 + ((grassIdx * 19) % 16) * 0.1
					placeToolboxTreeAt(chosenGrass, leftFieldModel, Vector3.new(gx, 0.25, gz), grassIdx, targetH, "RiceGrass_")
				end
			end
		end
	end

	-- ปลูกกอข้าวฝั่งขวา (-X) เข้าไปใน RightRiceField
	for rx = rightOuterEdgeX + 4.5, rightInnerEdgeX - 4.5, 7.5 do
		if math.abs(rx - midXR) > 3.2 then -- เว้นแนวสันคันนากลาง
			for rz = zFront + 3.5, zBack - 3.5, 6.5 do
				grassIdx += 1
				local gx = rx + ((grassIdx * 41) % 3) - 1
				local gz = rz + ((grassIdx * 59) % 3) - 1
				if #grassTemplates > 0 then
					local chosenGrass = grassTemplates[((grassIdx - 1) % #grassTemplates) + 1]
					local targetH = 2.6 + ((grassIdx * 23) % 16) * 0.1
					placeToolboxTreeAt(chosenGrass, rightFieldModel, Vector3.new(gx, 0.25, gz), grassIdx, targetH, "RiceGrass_")
				end
			end
		end
	end

	print("🌾 [MapBuilder] สร้างทุ่งนาแยก 2 ก้อนอิสระ (LeftRiceField & RightRiceField) เรียบร้อยแล้ว!")
end

-- ฟังก์ชันย่อย: แยกก้อน SideRiceFields เดิมในฉากออกเป็น LeftRiceField และ RightRiceField ทันทีโดยไม่ขยับตำแหน่งเดิม!
function MapBuilder.SplitSideRiceFields()
	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		return
	end
	local combined = mapEnv:FindFirstChild("SideRiceFields")
	if not combined then
		print("✅ [MapBuilder] ทุ่งนาซ้าย-ขวาแยกเป็น LeftRiceField และ RightRiceField อยู่แล้ว!")
		return
	end

	local leftModel = mapEnv:FindFirstChild("LeftRiceField") or Instance.new("Model")
	leftModel.Name = "LeftRiceField"
	leftModel.Parent = mapEnv

	local rightModel = mapEnv:FindFirstChild("RightRiceField") or Instance.new("Model")
	rightModel.Name = "RightRiceField"
	rightModel.Parent = mapEnv

	for _, child in ipairs(combined:GetChildren()) do
		local posX = 0
		if child:IsA("Model") then
			local cf, _ = child:GetBoundingBox()
			posX = cf.Position.X
		elseif child:IsA("BasePart") then
			posX = child.Position.X
		end

		if posX >= 0 then
			child.Parent = leftModel
			if child.Name == "PaddyWater_Left" and child:IsA("BasePart") then
				leftModel.PrimaryPart = child
			end
		else
			child.Parent = rightModel
			if child.Name == "PaddyWater_Right" and child:IsA("BasePart") then
				rightModel.PrimaryPart = child
			end
		end
	end

	combined:Destroy()
	print("✂️ [MapBuilder] แยกทุ่งนาซ้าย (LeftRiceField) และทุ่งนาขวา (RightRiceField) เป็นอ๊อฟเจกคนละก้อนเรียบร้อย!")
end

-- =====================================================
-- ฟังก์ชันพิเศษ: ลบก้อนภูเขาทรงกลมรอบขอบแมพออกทั้งหมด แล้วสร้าง "กำแพงล่องหน (Invisible Walls)" กั้นขอบแมพแทน!
-- (ไม่แตะต้องเพิงร้าน, ศาลพระภูมิ, ต้นไทร, ดงกล้วย หรือของที่คุณจัดวางไว้เลย!)
-- =====================================================
function MapBuilder.ReplaceHillsWithInvisibleWalls()
	local terrain = Workspace.Terrain
	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		mapEnv = Instance.new("Folder")
		mapEnv.Name = "MapEnvironment"
		mapEnv.Parent = Workspace
	end

	-- 1. ลบก้อนภูเขาทรงกลม (FillBall) รอบขอบแมพออกทั้งหมดด้วย Air
	if terrain then
		for angle = 0, 340, 20 do
			local rad = math.rad(angle)
			local dist = 115 + ((angle * 13) % 25)
			local hx = math.cos(rad) * dist
			local hz = math.sin(rad) * dist
			local r = 22 + (angle % 11)
			terrain:FillBall(Vector3.new(hx, 2 + (angle % 7), hz), r + 2.5, Enum.Material.Air)
		end

		-- ปูพื้นหญ้าแนวราบที่ระดับพื้นเดิม (Y = -2.2, สูง 4.2) คืนเฉพาะจุดที่ก้อนภูเขาเคยคว้านลงไปกินพื้นดินรอบนอก
		for angle = 0, 340, 20 do
			local rad = math.rad(angle)
			local dist = 115 + ((angle * 13) % 25)
			local hx = math.cos(rad) * dist
			local hz = math.sin(rad) * dist
			local r = 24 + (angle % 11)
			terrain:FillBlock(CFrame.new(hx, -2.2, hz), Vector3.new(r * 2, 4.2, r * 2), Enum.Material.LeafyGrass)
		end

		-- เคลียร์ส่วนที่อาจล้ำเข้ามาในแอ่งทุ่งนาหน้าสุด (Z = -50) ให้เรียบเหมือนเดิม
		terrain:FillBlock(CFrame.new(0, -1.2, -50), Vector3.new(162, 3.0, 54), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(0, -2.8, -50), Vector3.new(164, 2.8, 56), Enum.Material.Mud)
		for mx = -75, 75, 9 do
			local seed = math.abs(mx * 17)
			local r1 = 3.2 + (seed % 25) * 0.1
			terrain:FillBall(Vector3.new(mx, -1.4 + (seed % 5) * 0.12, -24.5 + ((seed % 3) - 1) * 0.7), r1, Enum.Material.Grass)
		end
		for mz = -26, -74, -6 do
			local s2 = math.abs(mz * 23)
			terrain:FillBall(Vector3.new(-10 + ((s2 % 3) - 1) * 0.5, -1.5, mz), 3.0 + (s2 % 10) * 0.08, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(25 + ((s2 % 3) - 1) * 0.5, -1.5, mz), 3.0 + (s2 % 10) * 0.08, Enum.Material.Grass)
		end
	end

	-- 2. ซ่อมขอบทุ่งนาซ้าย-ขวา (ที่เคยโดนก้อนภูเขาทับมุมอยู่นิดนึง) และทาสีถนนให้เนียนเหมือนเดิม
	MapBuilder.AddSideRiceFields()
	MapBuilder.PaintTerrainRoad()

	-- 3. สร้างกำแพงล่องหน (InvisibleWalls) 4 ด้านล้อมกรอบพื้นที่เล่นทั้งหมด
	local oldWalls = mapEnv:FindFirstChild("InvisibleWalls")
	if oldWalls then
		oldWalls:Destroy()
	end

	local wallsModel = Instance.new("Model")
	wallsModel.Name = "InvisibleWalls"
	wallsModel.Parent = mapEnv

	local wallConfigs = {
		{ name = "InvisibleWall_Front", size = Vector3.new(208, 40, 2), pos = Vector3.new(0, 20, -79) }, -- ขอบนอกทุ่งนาฝั่งตรงข้าม
		{ name = "InvisibleWall_Back", size = Vector3.new(208, 40, 2), pos = Vector3.new(0, 20, 58) }, -- ขอบหลังร้านและหลังทุ่งนาซ้าย-ขวา
		{ name = "InvisibleWall_Left", size = Vector3.new(2, 40, 140), pos = Vector3.new(103, 20, -10.5) }, -- ขอบซ้ายสุดของแมพ
		{ name = "InvisibleWall_Right", size = Vector3.new(2, 40, 140), pos = Vector3.new(-103, 20, -10.5) }, -- ขอบขวาสุดของแมพ
	}

	for _, w in ipairs(wallConfigs) do
		local wall = createPart(w.name, w.size, CFrame.new(w.pos), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, wallsModel)
		wall.Transparency = 1 -- ล่องหน 100%
		wall.CanCollide = true -- กั้นไม่ให้ผู้เล่นเดินตกขอบแมพ
		wall.CastShadow = false
	end

	print("🛡️ [MapBuilder] ลบก้อนภูเขากลมๆ รอบแมพออกทั้งหมด และตั้งกำแพงล่องหน (InvisibleWalls) 4 ด้านเรียบร้อยแล้ว!")
end

-- =====================================================
-- ฟังก์ชันพิเศษ (ทางเลือกที่ 3):
-- 1. สร้างทุ่งนาด้านหลังร้าน (BackRiceField) เชื่อมกับทุ่งนาซ้าย-ขวา ให้ล้อมโคกดินตรงกลางครบ 4 ด้าน
-- 2. ตัดพื้นดิน Terrain และ Baseplate ส่วนเกินนอกขอบแมพทิ้งทั้งหมด ไม่ให้เหลือสนามหญ้าโล่งๆ
-- 3. ปลูกแนวต้นกล้วย/ต้นไม้ชายทุ่ง (OuterTreeLine) ล้อมกรอบริมคันนานอกสุด + ตั้งกำแพงล่องหน
-- (ไม่แตะต้องหรือรีเซ็ตของที่คุณจัดวางไว้ตรงกลางเลยแม้แต่ชิ้นเดียว!)
-- =====================================================
function MapBuilder.BuildCompactPerimeter()
	local terrain = Workspace.Terrain
	local ServerStorage = game:GetService("ServerStorage")

	local mapEnv = Workspace:FindFirstChild("MapEnvironment")
	if not mapEnv then
		mapEnv = Instance.new("Folder")
		mapEnv.Name = "MapEnvironment"
		mapEnv.Parent = Workspace
	end

	-- แยกทุ่งนาซ้าย-ขวาเป็น LeftRiceField / RightRiceField อัตโนมัติถ้ายังไม่ได้แยก
	MapBuilder.SplitSideRiceFields()

	-- ลบเฉพาะ BackRiceField และ OuterTreeLine เดิม (ถ้าเคยรันคำสั่งนี้แล้ว)
	for _, oldName in ipairs({ "BackRiceField", "OuterTreeLine" }) do
		local oldObj = mapEnv:FindFirstChild(oldName)
		if oldObj then
			oldObj:Destroy()
		end
	end

	-- -----------------------------------------------------
	-- 1. สร้างทุ่งนาด้านหลังร้าน (BackRiceField) เชื่อมต่อกับทุ่งนาซ้าย-ขวา
	-- -----------------------------------------------------
	local backFieldModel = Instance.new("Model")
	backFieldModel.Name = "BackRiceField"
	backFieldModel.Parent = mapEnv

	local zBackStart = 55
	local zBackEnd = 86
	local centerBackZ = (zBackStart + zBackEnd) * 0.5 -- 70.5
	local depthBackZ = zBackEnd - zBackStart -- 31
	local widthBackX = 192 -- X = -96 .. +96

	if terrain then
		-- ขุดแอ่งนาด้านหลังร้านให้บุ๋มลึกลงไป + ปูพื้นโคลนใต้น้ำ
		terrain:FillBlock(CFrame.new(0, -1.2, centerBackZ), Vector3.new(widthBackX, 3.0, depthBackZ), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(0, -2.8, centerBackZ), Vector3.new(widthBackX + 2, 2.8, depthBackZ + 2), Enum.Material.Mud)

		-- คันนากั้นระหว่างหลังเพิงร้าน/ดงกล้วย/ต้นไทร กับทุ่งนาด้านหลัง (Z = 54) และคันนาขอบหลังสุด (Z = 87.5)
		for mx = -98, 98, 8 do
			local seed = math.abs(mx * 17)
			local r = 3.1 + (seed % 18) * 0.08
			terrain:FillBall(Vector3.new(mx, -1.4 + (seed % 4) * 0.12, 54.0 + ((seed % 3) - 1) * 0.4), r, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(mx, -1.3 + (seed % 4) * 0.12, 87.5 + ((seed % 3) - 1) * 0.4), r + 0.4, Enum.Material.Grass)
		end

		-- คันนาแบ่งแปลงนาด้านหลังออกเป็น 3 แปลง (X = -38 และ X = +38 เชื่อมกับแนวคันนาซ้าย-ขวาพอดี) + ขอบซ้ายขวาสุด (X = ±97.5)
		for mz = zBackStart - 1, zBackEnd + 1, 6 do
			local s2 = math.abs(mz * 23)
			local r = 3.0 + (s2 % 10) * 0.08
			terrain:FillBall(Vector3.new(-38 + ((s2 % 3) - 1) * 0.4, -1.5, mz), r, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(38 + ((s2 % 3) - 1) * 0.4, -1.5, mz), r, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(-97.5, -1.3, mz), r + 0.4, Enum.Material.Grass)
			terrain:FillBall(Vector3.new(97.5, -1.3, mz), r + 0.4, Enum.Material.Grass)
		end

		-- คันนาขอบนอกสุดของทุ่งนาซ้าย-ขวา (X = ±97.5) และขอบหน้าสุดของทุ่งนาฝั่งตรงข้าม (Z = -77.5)
		for mz = -76, 54, 7 do
			if math.abs(mz - -12) > 11 then -- เว้นช่องถนนซ้าย-ขวา
				local s3 = math.abs(mz * 19)
				terrain:FillBall(Vector3.new(-97.5, -1.3, mz), 3.4 + (s3 % 3) * 0.3, Enum.Material.Grass)
				terrain:FillBall(Vector3.new(97.5, -1.3, mz), 3.4 + (s3 % 3) * 0.3, Enum.Material.Grass)
			end
		end
		for mx = -96, 96, 8 do
			local s4 = math.abs(mx * 29)
			terrain:FillBall(Vector3.new(mx, -1.3, -77.5), 3.4 + (s4 % 3) * 0.3, Enum.Material.Grass)
		end
	end

	-- แผ่นน้ำในทุ่งนาด้านหลังร้าน (PaddyWater_Back)
	local waterBack = createPart(
		"PaddyWater_Back",
		Vector3.new(widthBackX, 0.4, depthBackZ),
		CFrame.new(0, 0.2, centerBackZ),
		Color3.fromRGB(22, 36, 28),
		Enum.Material.Glass,
		backFieldModel
	)
	waterBack.Reflectance = 0.15
	backFieldModel.PrimaryPart = waterBack

	-- โหลดแม่แบบกอหญ้าและต้นกล้วยจาก ServerStorage
	local grassTemplates = {}
	local grassFolder = ServerStorage:FindFirstChild("ToolboxGrassTemplates")
	if grassFolder then
		grassTemplates = grassFolder:GetChildren()
	end
	local bananaTemplates = {}
	local bananaFolder = ServerStorage:FindFirstChild("ToolboxBananaTemplates")
	if bananaFolder then
		bananaTemplates = bananaFolder:GetChildren()
	end
	if #grassTemplates == 0 or #bananaTemplates == 0 then
		local b, g, _, _ = harvestAllToolboxAssets()
		if #grassTemplates == 0 then
			grassTemplates = g
		end
		if #bananaTemplates == 0 then
			bananaTemplates = b
		end
	end

	-- ปลูกกอข้าวในทุ่งนาด้านหลังร้าน (BackRiceField)
	local grassIdx = 0
	for rx = -91, 91, 7.5 do
		if math.abs(rx - -38) > 3.2 and math.abs(rx - 38) > 3.2 then
			for rz = zBackStart + 3.5, zBackEnd - 3.5, 6.5 do
				grassIdx += 1
				local gx = rx + ((grassIdx * 37) % 3) - 1
				local gz = rz + ((grassIdx * 53) % 3) - 1
				if #grassTemplates > 0 then
					local chosenGrass = grassTemplates[((grassIdx - 1) % #grassTemplates) + 1]
					local targetH = 2.6 + ((grassIdx * 19) % 16) * 0.1
					placeToolboxTreeAt(chosenGrass, backFieldModel, Vector3.new(gx, 0.25, gz), grassIdx, targetH, "RiceGrass_")
				end
			end
		end
	end

	-- -----------------------------------------------------
	-- 2. ปิดจุดตกโลก (Horizon Ground) + ขยายขอบดินรับหลังแนวต้นไม้เพื่อไม่ให้มองเห็นอวกาศ/ดาวด้านล่างเด็ดขาด!
	-- -----------------------------------------------------
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		-- ขยายแผ่นพื้นมืดระดับเส้นขอบฟ้า (2048x2048) มารับต่อจากขอบ Terrain ที่ระดับความสูงเดียวกันเป๊ะ เพื่อปิดช่องมองเห็นดาวใต้โลก 100%
		baseplate.Size = Vector3.new(2048, 4, 2048)
		baseplate.Position = Vector3.new(0, -2.15, 0)
		baseplate.Color = Color3.fromRGB(32, 42, 25)
		baseplate.Material = Enum.Material.LeafyGrass
	end

	if terrain then
		-- เติมพื้นหญ้า Voxel Terrain รองรับหลังแนวต้นไม้ชายทุ่งออกไปอีกชั้น (X = -140..+140, Z = -115..+125) ไม่ให้เป็นหน้าผาตัดชันตรงแนวต้นไม้
		terrain:FillBlock(CFrame.new(0, -2.2, 106), Vector3.new(280, 4.2, 38), Enum.Material.LeafyGrass)
		terrain:FillBlock(CFrame.new(0, -2.2, -96), Vector3.new(280, 4.2, 38), Enum.Material.LeafyGrass)
		terrain:FillBlock(CFrame.new(118, -2.2, 5), Vector3.new(44, 4.2, 240), Enum.Material.LeafyGrass)
		terrain:FillBlock(CFrame.new(-118, -2.2, 5), Vector3.new(44, 4.2, 240), Enum.Material.LeafyGrass)
	end

	-- ระบายสีถนนช่วงที่อยู่ในกรอบและต่อแนวถนนออกไปด้านซ้าย-ขวาให้กลืนเข้ากับความมืด
	MapBuilder.PaintTerrainRoad()

	-- -----------------------------------------------------
	-- 3. ปลูกแนวต้นกล้วย + พุ่มไม้ทึบชายทุ่ง 2 ชั้น (OuterTreeLine) บังสายตาหลังกำแพงล่องหน
	-- -----------------------------------------------------
	local outerTreesModel = Instance.new("Model")
	outerTreesModel.Name = "OuterTreeLine"
	outerTreesModel.Parent = mapEnv

	-- แผ่นถนนดินดำต่อออกไปนอกเขตกำแพงล่องหนซ้าย-ขวา เพื่อไม่ให้มองไปตามถนนแล้วเห็นขอบถนนขาด
	createPart(
		"RoadHorizonExt_Left",
		Vector3.new(220, 0.3, 16),
		CFrame.new(205, 0.0, -12),
		Color3.fromRGB(38, 34, 30),
		Enum.Material.Ground,
		outerTreesModel
	)
	createPart(
		"RoadHorizonExt_Right",
		Vector3.new(220, 0.3, 16),
		CFrame.new(-205, 0.0, -12),
		Color3.fromRGB(38, 34, 30),
		Enum.Material.Ground,
		outerTreesModel
	)

	local borderCoords = {}
	-- แนวชายทุ่งด้านหลังสุด 2 ชั้นสลับฟันปลา (Z = 89..98)
	for bx = -102, 102, 9 do
		local seed = math.abs(bx * 31)
		table.insert(borderCoords, {
			pos = Vector3.new(bx + ((seed % 5) - 2), 0.5, 89.5 + (seed % 3)),
			h = 10.0 + (seed % 6),
		})
		table.insert(borderCoords, {
			pos = Vector3.new(bx + 4.5, 0.5, 95.5 + ((seed + 2) % 3)),
			h = 12.0 + ((seed + 3) % 6),
		})
	end
	-- แนวชายทุ่งด้านหน้าสุดหลังเถียงนา 2 ชั้นสลับฟันปลา (Z = -79..-88)
	for fx = -102, 102, 10 do
		local seed = math.abs(fx * 29)
		table.insert(borderCoords, {
			pos = Vector3.new(fx + ((seed % 5) - 2), 0.5, -79.5 - (seed % 3)),
			h = 9.5 + (seed % 6),
		})
		table.insert(borderCoords, {
			pos = Vector3.new(fx + 5.0, 0.5, -85.5 - ((seed + 2) % 3)),
			h = 11.5 + ((seed + 3) % 6),
		})
	end
	-- แนวชายทุ่งด้านซ้ายสุด (X = 99..107) และขวาสุด (X = -99..-107) 2 ชั้น ยกเว้นช่องถนน (Z = -24..0)
	for sz = -78, 88, 9 do
		if sz < -24 or sz > 1 then
			local seed = math.abs(sz * 37)
			table.insert(borderCoords, {
				pos = Vector3.new(99.0 + (seed % 2), 0.5, sz + ((seed % 3) - 1)),
				h = 10.0 + (seed % 6),
			})
			table.insert(borderCoords, {
				pos = Vector3.new(105.5 + (seed % 3), 0.5, sz + 4.5),
				h = 12.5 + ((seed + 2) % 6),
			})
			table.insert(borderCoords, {
				pos = Vector3.new(-99.0 - (seed % 2), 0.5, sz + (((seed + 1) % 3) - 1)),
				h = 10.0 + ((seed + 3) % 6),
			})
			table.insert(borderCoords, {
				pos = Vector3.new(-105.5 - (seed % 3), 0.5, sz + 4.5),
				h = 12.5 + ((seed + 4) % 6),
			})
		end
	end

	for idx, bData in ipairs(borderCoords) do
		if #bananaTemplates > 0 then
			local chosen = bananaTemplates[((idx - 1) % #bananaTemplates) + 1]
			placeToolboxTreeAt(chosen, outerTreesModel, bData.pos, idx, bData.h, "BorderTree_")
		else
			buildDetailedBananaTree(outerTreesModel, bData.pos, bData.h / 10, idx)
		end
		-- พุ่มไม้เตี้ยทึบสีเขียวคล้ำที่โคนแนวต้นไม้ ช่วยบังแสงไฟฉายไม่ให้ทะลุออกไปข้างหลัง
		local bush = createPart(
			"BorderBush_" .. idx,
			Vector3.new(7.5 + (idx % 3) * 1.5, 4.2 + (idx % 2) * 1.2, 7.5 + (idx % 3) * 1.5),
			CFrame.new(bData.pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(idx * 41), 0),
			Color3.fromRGB(26, 38, 22),
			Enum.Material.LeafyGrass,
			outerTreesModel,
			Enum.PartType.Ball
		)
		bush.CanCollide = false

		if #grassTemplates > 0 and idx % 2 == 0 then
			local gChosen = grassTemplates[((idx - 1) % #grassTemplates) + 1]
			placeToolboxTreeAt(gChosen, outerTreesModel, bData.pos + Vector3.new(1.5, -0.2, -1.2), idx, 3.4, "BorderGrass_")
		end
	end

	-- -----------------------------------------------------
	-- 4. ขยับกำแพงล่องหน (InvisibleWalls) เข้ามาอยู่ด้านในคันนา (ห่างจากขอบต้นไม้ 12 Studs)
	--    เพื่อไม่ให้ผู้เล่นเดินเอาหน้าไปชิดขอบต้นไม้หรือชะโงกกล้องออกไปนอกแมพได้!
	-- -----------------------------------------------------
	local oldWalls = mapEnv:FindFirstChild("InvisibleWalls")
	if oldWalls then
		oldWalls:Destroy()
	end

	local wallsModel = Instance.new("Model")
	wallsModel.Name = "InvisibleWalls"
	wallsModel.Parent = mapEnv

	for _, w in ipairs({
		{ name = "InvisibleWall_Front", size = Vector3.new(186, 40, 2), pos = Vector3.new(0, 20, -70) },
		{ name = "InvisibleWall_Back", size = Vector3.new(186, 40, 2), pos = Vector3.new(0, 20, 81) },
		{ name = "InvisibleWall_Left", size = Vector3.new(2, 40, 154), pos = Vector3.new(89, 20, 5.5) },
		{ name = "InvisibleWall_Right", size = Vector3.new(2, 40, 154), pos = Vector3.new(-89, 20, 5.5) },
	}) do
		local wall = createPart(w.name, w.size, CFrame.new(w.pos), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, wallsModel)
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CastShadow = false
	end

	print("🌾🌲 [MapBuilder] ปิดจุดตกโลก + ซ้อนพุ่มไม้ทึบชายทุ่ง 2 ชั้น + ดึงกำแพงล่องหนเข้ามาด้านใน เรียบร้อย!")
end

-- หาโมเดลที่นำเข้าจาก Blender (assets/models/*.fbx) ใน Workspace.NewModels หรือ ServerStorage.ImportedProps
local function findImportedModel(name: string): Model?
	for _, folder in ipairs({ Workspace:FindFirstChild("NewModels"), game:GetService("ServerStorage"):FindFirstChild("ImportedProps") }) do
		local m = folder and folder:FindFirstChild(name)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- ย้าย placeholder เดิมไปเก็บใน ServerStorage.ArchivedPlaceholders (ไม่ลบทิ้ง) แล้ววางโมเดลใหม่แทน
local function archivePlaceholder(old: Instance)
	local ss = game:GetService("ServerStorage")
	local archive = ss:FindFirstChild("ArchivedPlaceholders") or Instance.new("Folder")
	archive.Name = "ArchivedPlaceholders"
	archive.Parent = ss
	old.Parent = archive
end

-- สลับตู้ปั๊มหลอด placeholder (InteractiveProps.GasPump) เป็นโมเดล GasPump.fbx
-- ตั้งฐานตู้ไว้ตรงฐานเดิม หันหน้าป้ายไปทาง StopPoint และย้าย PumpFuelPrompt / ZoneLabel ไปใส่ตู้ใหม่
function MapBuilder.SwapGasPumpModel()
	local interactive = Workspace:FindFirstChild("InteractiveProps")
	local old = interactive and interactive:FindFirstChild("GasPump")
	local new = findImportedModel("GasPump")
	if not old or not new then
		warn("[MapBuilder] SwapGasPumpModel: ไม่พบ InteractiveProps.GasPump หรือโมเดลที่นำเข้า (NewModels/ImportedProps.GasPump)")
		return
	end
	if old:GetAttribute("ImportedProp") then
		warn("[MapBuilder] SwapGasPumpModel: ตู้ปั๊มเป็นโมเดลใหม่อยู่แล้ว")
		return
	end

	local pad = old:FindFirstChild("ConcretePad") :: BasePart?
	local basePos = if pad then pad.Position - Vector3.new(0, pad.Size.Y / 2, 0) else old:GetPivot().Position
	local stop = Workspace:FindFirstChild("StopPoint", true)
	local facing = if stop then (stop:GetPivot().Position - basePos) * Vector3.new(1, 0, 1) else Vector3.new(0, 0, -1)
	if facing.Magnitude < 0.01 then
		facing = Vector3.new(0, 0, -1)
	end
	-- ด้านหน้าของโมเดลจาก Blender คือแกน -Z ซึ่ง CFrame.lookAt ชี้ไปทางเป้าหมายพอดี
	new:PivotTo(CFrame.lookAt(basePos, basePos + facing.Unit))

	local body = new:FindFirstChild("GasPump") :: BasePart?
	local glass = new:FindFirstChild("GlassTube") :: BasePart?
	local prompt = old:FindFirstChild("PumpFuelPrompt", true)
	if prompt and body then
		prompt.Parent = body
	end
	local label = old:FindFirstChild("ZoneLabel", true)
	if label and glass then
		label.Parent = glass
	end
	if glass then
		glass.Material = Enum.Material.Glass
		glass.Color = Color3.fromRGB(205, 225, 215)
		glass.Transparency = 0.55
		glass.CastShadow = false
	end
	for _, d in ipairs(new:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = d == body
		end
	end
	if body then
		new.PrimaryPart = body
	end

	archivePlaceholder(old)
	new.Name = "GasPump"
	new:SetAttribute("ImportedProp", true)
	new.Parent = interactive
	print("⛽ [MapBuilder] สลับตู้ปั๊มหลอดเป็นโมเดลใหม่แล้ว (ของเดิมเก็บไว้ที่ ServerStorage.ArchivedPlaceholders)")
end

-- ===================================================================================
-- สลับ placeholder ทั้งฉากเป็นโมเดลจาก Blender (assets/models/*.fbx)
-- โมเดลต้นแบบ: Workspace.NewModels.<ชื่อไฟล์> (จะถูกย้ายไปเก็บที่ ServerStorage.ImportedProps แล้ว Clone มาวาง)
-- ของเดิมทุกชิ้นย้ายไป ServerStorage.ArchivedPlaceholders (ไม่ลบ) รันซ้ำได้ ระบบจะข้ามถ้าเคยสลับแล้ว
-- ชื่อที่สคริปต์ใช้อยู่คงไว้: InteractiveProps.ShutterDoor / RejectRope(+RejectCustomerPrompt), DirtRoad.NeonLightPart(+FlickerLight)
-- ===================================================================================
local IMPORTED_TEMPLATES = {
	"AirCompressor", "TireStack", "ShackSigns", "ShackPorchKit", "CorrugatedPanels", "ShackLight", "FuelDrum",
	"ToolsOnGround", "TvAntennaAndPoles", "SpiritHouseOnStilts", "ShackInteriorProps", "Generator", "TinOuthouse",
	"SacredBanyanProps", "RoadsideProps", "ShackShelf", "ShackSeats", "WelcomeSign", "WoodPlankWalls",
	"HangingCoils", "PowerLines", "SacredBanyanTree", "WoodenPolePlain",
}

local function moveTemplatesToStorage(): Folder
	local ss = game:GetService("ServerStorage")
	local store = ss:FindFirstChild("ImportedProps") or Instance.new("Folder")
	store.Name = "ImportedProps"
	store.Parent = ss
	local newModels = Workspace:FindFirstChild("NewModels")
	for _, name in ipairs(IMPORTED_TEMPLATES) do
		local m = newModels and newModels:FindFirstChild(name)
		if m and not store:FindFirstChild(name) then
			m.Parent = store
		end
	end
	-- importer สร้าง SurfaceAppearance ว่าง (ไม่มี ColorMap) ซ้อนให้ชิ้นที่มี material หน้าป้าย (SignFace ฯลฯ)
	-- ทำให้ป้ายขึ้นเป็นสีพื้นเรียบและย้อมสีไม่ได้: ลบอันที่ว่างทิ้ง เหลืออันที่มี texture
	for _, p in ipairs(store:GetDescendants()) do
		if p:IsA("MeshPart") then
			local sas = {}
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("SurfaceAppearance") then
					table.insert(sas, c)
				end
			end
			if #sas > 1 then
				for _, sa in ipairs(sas) do
					if sa.ColorMap == "" then
						sa:Destroy()
					end
				end
			end
		end
	end
	return store :: Folder
end

local function archiveFolder(sub: string): Folder
	local ss = game:GetService("ServerStorage")
	local root = ss:FindFirstChild("ArchivedPlaceholders") or Instance.new("Folder")
	root.Name = "ArchivedPlaceholders"
	root.Parent = ss
	local f = root:FindFirstChild(sub) or Instance.new("Folder")
	f.Name = sub
	f.Parent = root
	return f :: Folder
end

local function boundsOf(list: { Instance }): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	local function addPart(p: BasePart)
		local cf, s = p.CFrame, p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local w = cf:PointToWorldSpace(Vector3.new(sx * s.X, sy * s.Y, sz * s.Z))
					mn = mn:Min(w)
					mx = mx:Max(w)
				end
			end
		end
	end
	for _, inst in ipairs(list) do
		if inst:IsA("BasePart") then
			addPart(inst)
		end
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				addPart(d)
			end
		end
	end
	return mn, mx
end

local function bottomCenter(list: { Instance }): Vector3
	local mn, mx = boundsOf(list)
	return Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
end

local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local hit = Workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -260, 0), params)
	return if hit then hit.Position.Y else 2
end

-- Clone ชิ้นส่วนจากต้นแบบมาวาง
-- anchor: "bottom" = กึ่งกลางฐาน, "origin" = จุด origin จาก Blender (pivot ของไฟล์),
--         "backBottom" = ฐานด้านหลัง (ติดผนัง), "backTop" = บนสุดด้านหลัง (ของแขวน), "topStart" = ปลายสายไฟด้านต้น
local function placeGroup(store: Folder, file: string, names: { string }, target: Vector3, yawDeg: number, anchor: string, parent: Instance): { [string]: BasePart }
	local tplModel = store:FindFirstChild(file) :: Model
	assert(tplModel, "ไม่พบต้นแบบ " .. file)
	local parts = {}
	for _, n in ipairs(names) do
		local p = tplModel:FindFirstChild(n)
		assert(p and p:IsA("BasePart"), "ไม่พบชิ้น " .. file .. "." .. n)
		table.insert(parts, p)
	end
	local mn, mx = boundsOf(parts)
	local a: Vector3
	if anchor == "origin" then
		a = tplModel:GetPivot().Position
	elseif anchor == "backBottom" then
		a = Vector3.new((mn.X + mx.X) / 2, mn.Y, mx.Z)
	elseif anchor == "backTop" then
		a = Vector3.new((mn.X + mx.X) / 2, mx.Y, mx.Z)
	elseif anchor == "topStart" then
		a = Vector3.new((mn.X + mx.X) / 2, mx.Y, mn.Z)
	else
		a = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	end
	local base = CFrame.new(target) * CFrame.Angles(0, math.rad(yawDeg), 0)
	local out = {}
	for _, p in ipairs(parts) do
		local c = p:Clone()
		c.CFrame = base * (CFrame.new(-a) * p.CFrame)
		c.Anchored = true
		c.Parent = parent
		out[p.Name] = c
	end
	return out
end

local function moveChildren(from: Instance?, className: string, to: Instance?)
	if not from or not to then
		return
	end
	for _, d in ipairs(from:GetDescendants()) do
		if d:IsA(className) then
			d.Parent = to
		end
	end
end

local function moveLabel(from: Instance?, to: BasePart?)
	if not from or not to then
		return
	end
	local label = if from:IsA("BillboardGui") then from else from:FindFirstChild("ZoneLabel", true)
	if label and label:IsA("BillboardGui") then
		label.Adornee = nil
		label.Parent = to
	end
end

local function makeNeon(p: BasePart?, color: Color3)
	if not p then
		return
	end
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		sa:Destroy() -- SurfaceAppearance จะบังสี Neon (เป็นของที่นำเข้ามาเอง ไม่ใช่ของเดิมในฉาก)
	end
	p.Material = Enum.Material.Neon
	p.Color = color
	p.CastShadow = false
end

local function newModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("ImportedProp", true)
	m.Parent = parent
	return m
end

local function setCollide(container: Instance, bigOnly: boolean)
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("ImportedProp") ~= false then
			local s = d.Size
			d.CanCollide = (not bigOnly) or math.max(s.X, s.Y, s.Z) > 3.2
		end
	end
end

function MapBuilder.SwapImportedProps()
	if Workspace:GetAttribute("ImportedPropsSwapped") then
		warn("[MapBuilder] SwapImportedProps: เคยสลับไปแล้ว (ลบ attribute ImportedPropsSwapped ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = moveTemplatesToStorage()
	local env = Workspace:FindFirstChild("MapEnvironment")
	local interactive = Workspace:FindFirstChild("InteractiveProps")
	local anomaly = Workspace:FindFirstChild("AnomalyProps")
	assert(env and interactive and anomaly, "ไม่พบ MapEnvironment / InteractiveProps / AnomalyProps")

	-- ---------------------------------------------------------------- เพิง (ShackStructure)
	local shack = env:FindFirstChild("ShackStructure") :: Model
	local floor = shack:FindFirstChild("ShackFloor") :: BasePart
	local floorBottom = floor.Position.Y - floor.Size.Y / 2
	local floorTop = floorBottom + 0.8
	local pillars = {}
	local counterParts, tireParts, roofSheets = {}, {}, {}
	local shopSign = shack:FindFirstChild("ShopSign") :: BasePart
	local bulb = shack:FindFirstChild("ShackLightBulb") :: BasePart
	for _, c in ipairs(shack:GetChildren()) do
		if c.Name:match("^WoodenPillar") then
			table.insert(pillars, c)
		elseif c.Name == "CounterTop" or c.Name == "TableLeg" then
			table.insert(counterParts, c)
		elseif c.Name:match("^SpareTire") then
			table.insert(tireParts, c)
		elseif c.Name == "CorrugatedTinSheet" then
			table.insert(roofSheets, c)
		end
	end
	local signBottom = bottomCenter({ shopSign })
	local counterBase = bottomCenter(counterParts)
	local tireBase = bottomCenter(tireParts)
	local bulbTop = bulb.Position + Vector3.new(0, bulb.Size.Y / 2, 0)

	local oldShack = archiveFolder("ShackStructure")
	for _, c in ipairs(shack:GetChildren()) do
		if not c:IsA("SpawnLocation") then
			c.Parent = oldShack
		end
	end
	local newShack = newModel("ImportedShack", shack)

	placeGroup(store, "ShackPorchKit", { "PorchDeck" }, Vector3.new(floor.Position.X, floorBottom, floor.Position.Z), 0, "bottom", newShack)
	for _, p in ipairs(pillars) do
		local b = bottomCenter({ p })
		placeGroup(store, "ShackPorchKit", { "WoodenPillar" }, Vector3.new(b.X, floorTop, b.Z), 0, "bottom", newShack)
	end
	-- ผนัง: หลัง 5 แผ่น, ข้างละ 4 แผ่น สลับสังกะสี/ไม้ (คานไม้ของแผ่นไม้หันเข้าในเพิง)
	local W = { tin = { "CorrugatedPanels", "TinWallPanel" }, bent = { "CorrugatedPanels", "TinWallPanel_Bent" }, torn = { "CorrugatedPanels", "TinWallPanel_Torn" },
		wood = { "WoodPlankWalls", "WoodPlankWallPanel" }, broken = { "WoodPlankWalls", "WoodPlankWallPanel_Broken" } }
	local walls = {
		{ "wood", Vector3.new(-12, floorTop, 28.35), 180 }, { "tin", Vector3.new(-6, floorTop, 28.35), 180 }, { "torn", Vector3.new(0, floorTop, 28.35), 180 },
		{ "broken", Vector3.new(6, floorTop, 28.35), 180 }, { "bent", Vector3.new(12, floorTop, 28.35), 180 },
		{ "tin", Vector3.new(-16.3, floorTop, 10.5), 90 }, { "wood", Vector3.new(-16.3, floorTop, 15.5), 90 }, { "bent", Vector3.new(-16.3, floorTop, 20.5), 90 }, { "tin", Vector3.new(-16.3, floorTop, 25.5), 90 },
		{ "torn", Vector3.new(16.3, floorTop, 10.5), -90 }, { "tin", Vector3.new(16.3, floorTop, 15.5), -90 }, { "wood", Vector3.new(16.3, floorTop, 20.5), -90 }, { "tin", Vector3.new(16.3, floorTop, 25.5), -90 },
	}
	for _, w in ipairs(walls) do
		local spec = W[w[1]]
		placeGroup(store, spec[1], { spec[2] }, w[2], w[3], "bottom", newShack)
	end
	for i, sheet in ipairs(roofSheets) do
		local b = bottomCenter({ sheet })
		placeGroup(store, "CorrugatedPanels", { "TinRoofPanel" }, b, if i % 2 == 0 then 180 else 0, "bottom", newShack)
	end
	local sign = placeGroup(store, "ShackSigns", { "MainSignBoard" }, signBottom, 0, "bottom", newShack)
	moveChildren(oldShack:FindFirstChild("ShopSign"), "SurfaceGui", sign.MainSignBoard)
	-- ให้ตัวหนังสือป้ายร้านมืดตามแสงฉาก (ไม่เรืองแสงเองตอนกลางคืน)
	for _, g in ipairs(sign.MainSignBoard:GetChildren()) do
		if g:IsA("SurfaceGui") then
			g.LightInfluence = 1
		end
	end
	local counter = placeGroup(store, "ShackInteriorProps", { "CounterTable" }, counterBase, 0, "bottom", newShack)
	local counterTop = counter.CounterTable.Position.Y + counter.CounterTable.Size.Y / 2
	placeGroup(store, "TireStack", { "TireStack_4" }, Vector3.new(tireBase.X, floorTop, tireBase.Z), 0, "bottom", newShack)
	local light = placeGroup(store, "ShackLight", { "ShackLight", "ShackLight_Neon" }, Vector3.new(bulbTop.X, bulbTop.Y + 0.35, bulbTop.Z), 0, "backTop", newShack)
	-- หลอดนีออนในเพิงเป็นหลอดเสีย ไม่ติด (ให้แสงหน้าร้านมาจากโคมเสาไฟไม้อย่างเดียว เพื่อให้มืดหลอน)
	local tube = light.ShackLight_Neon
	makeNeon(tube, Color3.fromRGB(120, 135, 120))
	tube.Material = Enum.Material.Glass
	tube.Transparency = 0.35
	moveChildren(oldShack:FindFirstChild("ShackLightBulb"), "Light", tube)
	for _, l in ipairs(tube:GetChildren()) do
		if l:IsA("Light") then
			l.Enabled = false
		end
	end
	-- ของเพิ่มตาม concept (ไม่มี placeholder)
	placeGroup(store, "ShackShelf", { "ShackShelf" }, Vector3.new(-11, floorTop, 28.1), 0, "backBottom", newShack)
	placeGroup(store, "ShackInteriorProps", { "SodaCrate" }, Vector3.new(6.5, floorTop, 26.2), 15, "bottom", newShack)
	placeGroup(store, "ShackInteriorProps", { "CompendiumBook" }, Vector3.new(-3.5, counterTop, 13.2), -20, "bottom", newShack)
	-- โต๊ะใหม่สูงกว่าเดิม: ยกวิทยุเดิมที่วางบนโต๊ะขึ้นให้ไม่จมโต๊ะ
	local radio = interactive:FindFirstChild("Radio")
	if radio and (radio:IsA("Model") or radio:IsA("BasePart")) then
		local mn = boundsOf({ radio })
		if mn.Y < counterTop then
			radio:PivotTo(radio:GetPivot() + Vector3.new(0, counterTop - mn.Y + 0.02, 0))
		end
	end
	placeGroup(store, "ShackSeats", { "WoodenBench" }, Vector3.new(-9, floorTop, 10.6), 0, "bottom", newShack)
	placeGroup(store, "ShackSeats", { "WoodenStool" }, Vector3.new(9.5, floorTop, 10.2), 0, "bottom", newShack)
	placeGroup(store, "WelcomeSign", { "WelcomeSign" }, Vector3.new(16.5, 6.2, 16), -90, "backBottom", newShack)
	placeGroup(store, "TvAntennaAndPoles", { "TvAntenna" }, Vector3.new(-9, 13.3, 24), 0, "bottom", newShack)
	placeGroup(store, "HangingCoils", { "HangingHoseCoil" }, Vector3.new(15, 9.6, 7.45), 0, "backTop", newShack)
	placeGroup(store, "HangingCoils", { "HangingTire" }, Vector3.new(-15, 9.3, 7.45), 0, "backTop", newShack)
	setCollide(newShack, true)

	-- ---------------------------------------------------------------- ของใน InteractiveProps (คงชื่อ Part เดิมให้สคริปต์)
	local function swapPart(folder: Instance, name: string, file: string, names: { string }, target: Vector3, yaw: number, anchor: string, keepAttrs: boolean?)
		local old = folder:FindFirstChild(name)
		if not old or old:GetAttribute("ImportedProp") then
			return nil
		end
		local placed = placeGroup(store, file, names, target, yaw, anchor, folder)
		local main = placed[names[1]]
		for _, d in ipairs(old:GetChildren()) do
			if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Parent = main
			end
		end
		if keepAttrs then
			for k, v in pairs(old:GetAttributes()) do
				main:SetAttribute(k, v)
			end
		end
		for i = 2, #names do
			placed[names[i]].Parent = main
		end
		archivePlaceholder(old)
		main.Name = name
		main:SetAttribute("ImportedProp", true)
		return placed
	end

	local shutterOld = interactive:FindFirstChild("ShutterDoor") :: BasePart
	if shutterOld and not shutterOld:GetAttribute("ImportedProp") then
		local oldPos, oldSize = shutterOld.Position, shutterOld.Size
		local placed = swapPart(interactive, "ShutterDoor", "CorrugatedPanels", { "ShutterDoor" }, Vector3.zero, 0, "bottom", true)
		local door = placed and placed.ShutterDoor
		if door then
			door.Size = Vector3.new(oldSize.X, oldSize.Y, door.Size.Z)
			door.Position = oldPos
			door.CanCollide = true
		end
	end
	local rope = interactive:FindFirstChild("RejectRope") :: BasePart
	if rope then
		swapPart(interactive, "RejectRope", "CorrugatedPanels", { "RejectRope" }, bottomCenter({ rope }), 0, "bottom")
	end
	local cut = interactive:FindFirstChild("CutoutSwitch") :: BasePart
	if cut then
		local b = bottomCenter({ cut })
		swapPart(interactive, "CutoutSwitch", "ShackInteriorProps", { "CutoutSwitch", "CutoutSwitch_Lever" }, Vector3.new(-14.45, b.Y, b.Z), -90, "backBottom")
	end
	if interactive:FindFirstChild("MoneyTin") then
		local b = bottomCenter({ interactive.MoneyTin })
		swapPart(interactive, "MoneyTin", "ShackInteriorProps", { "MoneyTin", "MoneyTin_Lid" }, Vector3.new(b.X, counterTop, b.Z), 0, "bottom")
	end

	-- ---------------------------------------------------------------- AnomalyProps
	if anomaly:FindFirstChild("OldMirror") then
		local b = bottomCenter({ anomaly.OldMirror })
		swapPart(anomaly, "OldMirror", "ShackInteriorProps", { "OldMirror", "OldMirror_Glass" }, Vector3.new(14.45, b.Y, b.Z), 90, "backBottom")
		local glass = anomaly.OldMirror:FindFirstChild("OldMirror_Glass") :: BasePart
		if glass then
			glass.Material = Enum.Material.Glass
			glass.Reflectance = 0.5
			glass.Transparency = 0.05
		end
	end
	if anomaly:FindFirstChild("OwnerPhoto") then
		local b = bottomCenter({ anomaly.OwnerPhoto })
		swapPart(anomaly, "OwnerPhoto", "ShackInteriorProps", { "OwnerPhoto", "OwnerPhoto_Image" }, Vector3.new(b.X - 0.8, b.Y + 0.6, 28.1), 0, "backBottom")
		local cal = placeGroup(store, "ShackInteriorProps", { "WallCalendar", "WallCalendar_Page" }, Vector3.new(b.X + 1.2, b.Y + 0.2, 28.1), 0, "backBottom", anomaly.OwnerPhoto)
		cal.WallCalendar_Page.Parent = cal.WallCalendar
	end
	local function swapModel(folder: Instance, name: string, file: string, names: { string }, yaw: number, anchor: string, newName: string?)
		local old = folder:FindFirstChild(name)
		if not old or old:GetAttribute("ImportedProp") then
			return nil
		end
		local base = bottomCenter({ old })
		local m = newModel(newName or name, folder)
		local placed = placeGroup(store, file, names, base, yaw, anchor, m)
		m.PrimaryPart = placed[names[1]]
		moveLabel(old, placed[names[1]])
		for _, d in ipairs(old:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				d.Parent = placed[names[1]]
			end
		end
		archivePlaceholder(old)
		setCollide(m, true)
		return placed, m
	end
	swapModel(anomaly, "IceBox", "ShackInteriorProps", { "IceBox", "IceBox_Lid" }, 0, "bottom")
	swapModel(anomaly, "TinOuthouse", "TinOuthouse", { "TinOuthouse", "TinOuthouse_Door", "TinOuthouse_Latch", "DragonJar", "WaterDipper" }, 0, "origin")
	swapModel(Workspace, " Generator", "Generator", { "Generator", "PullStartHandle", "Generator_Neon" }, 0, "origin", "Generator")
	local gen = Workspace:FindFirstChild("Generator")
	if gen and gen:GetAttribute("ImportedProp") then
		makeNeon(gen:FindFirstChild("Generator_Neon") :: BasePart, Color3.fromRGB(255, 60, 40))
	end
	for _, c in ipairs(Workspace:GetChildren()) do
		if c.Name == "AirCompressor" and not c:GetAttribute("ImportedProp") then
			local placed = swapModel(Workspace, "AirCompressor", "AirCompressor", { "AirCompressor", "PressureGauge_Needle", "ReliefValve" }, 0, "bottom")
			break
		end
	end

	-- ---------------------------------------------------------------- ถนน: เสาไฟไม้ + หลักกิโล
	local road = env:FindFirstChild("DirtRoad")
	local pole = road and road:FindFirstChild("WoodenPole") :: BasePart
	if pole and not pole:GetAttribute("ImportedProp") then
		local b = bottomCenter({ pole })
		local oldNeon = road:FindFirstChild("NeonLightPart")
		local placed = placeGroup(store, "TvAntennaAndPoles", { "WoodenPole", "WoodenPole_Neon" }, b, 0, "bottom", road)
		archivePlaceholder(pole)
		local arm = road:FindFirstChild("PoleArm")
		if arm then
			archivePlaceholder(arm)
		end
		local neon = placed.WoodenPole_Neon
		if oldNeon then
			moveChildren(oldNeon, "Light", neon)
			archivePlaceholder(oldNeon)
		end
		makeNeon(neon, Color3.fromRGB(255, 240, 200))
		neon.Name = "NeonLightPart"
		placed.WoodenPole:SetAttribute("ImportedProp", true)
	end
	local km = road and road:FindFirstChild("KilometerMilestone") :: BasePart
	if km and not km:GetAttribute("ImportedProp") then
		local b = bottomCenter({ km }) + Vector3.new(0, 0.45, 0) -- placeholder เดิมจมดิน 0.6: ยกให้เห็นฐานปูน
		local placed = placeGroup(store, "RoadsideProps", { "KilometerMilestone" }, b, 0, "bottom", road)
		moveLabel(km, placed.KilometerMilestone)
		archivePlaceholder(km)
		local top = road:FindFirstChild("KilometerTop")
		if top then
			archivePlaceholder(top)
		end
		placed.KilometerMilestone:SetAttribute("ImportedProp", true)
	end

	-- ---------------------------------------------------------------- ศาลพระภูมิ (คงชื่อ Incense1-3 ไว้ในโฟลเดอร์ SpiritHouse)
	local spirit = Workspace:FindFirstChild("SpiritHouse")
	if spirit and not spirit:GetAttribute("ImportedProp") then
		local base = bottomCenter(spirit:GetChildren())
		local center = (spirit:FindFirstChild("ShrinePillar") :: BasePart)
		local target = if center then Vector3.new(center.Position.X, base.Y, center.Position.Z) else base
		local oldSpirit = archiveFolder("SpiritHouse")
		local smoke = {}
		for i = 1, 3 do
			smoke[i] = spirit:FindFirstChild("Incense" .. i)
		end
		local glow = spirit:FindFirstChild("ShrineCandleFlame")
		local label = spirit:FindFirstChild("ShrineTop")
		local placed = placeGroup(store, "SpiritHouseOnStilts", { "SpiritHouseOnStilts", "Incense1", "Incense2", "Incense3", "Incense1_Neon", "Incense2_Neon", "Incense3_Neon" }, target, -45, "origin", spirit)
		moveLabel(label, placed.SpiritHouseOnStilts)
		for i = 1, 3 do
			local tip = placed["Incense" .. i .. "_Neon"]
			moveChildren(smoke[i], "ParticleEmitter", tip)
			makeNeon(tip, Color3.fromRGB(255, 90, 30))
		end
		moveChildren(glow, "Light", placed.Incense2_Neon)
		for _, p in pairs(placed) do
			p:SetAttribute("ImportedProp", true)
		end
		-- ชิ้นเดิมทั้งหมด (รวม Incense1-3 อันเก่า) ย้ายไปเก็บ เหลือแต่ชิ้นใหม่ที่ชื่อเดิม
		for _, c in ipairs(spirit:GetChildren()) do
			if not c:GetAttribute("ImportedProp") then
				c.Parent = oldSpirit
			end
		end
		spirit:SetAttribute("ImportedProp", true)
	end

	-- ---------------------------------------------------------------- ต้นไทร (ขนาดจริง) + ของเซ่น + ม้านั่งหินอ่อน
	local zone = env:FindFirstChild("SacredBanyanZone")
	if zone then
		local oldTree = zone:FindFirstChild("SacredBanyanTree")
		if oldTree and not oldTree:GetAttribute("ImportedProp") then
			local trunk = oldTree:FindFirstChild("BanyanMainTrunk") :: BasePart
			local b = bottomCenter({ oldTree })
			local target = if trunk then Vector3.new(trunk.Position.X, b.Y, trunk.Position.Z) else b
			local m = newModel("SacredBanyanTree", zone)
			local placed = placeGroup(store, "SacredBanyanTree", { "BanyanTrunk", "BanyanRoots", "BanyanLimbs", "BanyanTwigs", "BanyanAerialRoots", "SacredThaiRibbons" }, target, 0, "origin", m)
			m.PrimaryPart = placed.BanyanTrunk
			moveLabel(oldTree, placed.BanyanTrunk)
			archivePlaceholder(oldTree)
			for _, n in ipairs({ "BanyanTwigs", "BanyanAerialRoots", "BanyanLimbs", "SacredThaiRibbons" }) do
				placed[n].CanCollide = false
			end
		end
		swapModel(zone, "BrokenOfferings", "SacredBanyanProps", { "BrokenOfferings" }, 0, "bottom")
		swapModel(zone, "OldMarbleBenchSet", "SacredBanyanProps", { "OldMarbleBenchSet" }, 0, "bottom")
	end

	-- ---------------------------------------------------------------- เถียงนากลางทุ่ง
	local rice = env:FindFirstChild("RiceField")
	if rice then
		swapModel(rice, "DistantRiceHut", "RoadsideProps", { "DistantRiceHut" }, 0, "bottom")
	end

	-- ---------------------------------------------------------------- ของรอบร้านตาม concept (ไม่มี placeholder)
	local yard = newModel("ImportedYardProps", env)
	local function onGround(x: number, z: number): Vector3
		return Vector3.new(x, groundY(x, z), z)
	end
	placeGroup(store, "FuelDrum", { "FuelDrum" }, onGround(19.2, 11.5), 0, "bottom", yard)
	placeGroup(store, "FuelDrum", { "FuelDrum_Red" }, onGround(20.9, 14.2), 30, "bottom", yard)
	placeGroup(store, "TireStack", { "TireLeaning" }, onGround(11.8, 2.2), 15, "bottom", yard)
	placeGroup(store, "TireStack", { "TireWithRim" }, onGround(-9.8, 0.6), 0, "bottom", yard)
	placeGroup(store, "ToolsOnGround", { "Wrench" }, onGround(-2.8, -0.2), 20, "bottom", yard)
	placeGroup(store, "ToolsOnGround", { "TireIron" }, onGround(1.2, -0.8), -25, "bottom", yard)
	placeGroup(store, "ToolsOnGround", { "TireLever" }, onGround(3.6, 1.0), 40, "bottom", yard)
	placeGroup(store, "ToolsOnGround", { "PatchKitTin" }, onGround(5.2, 2.6), 0, "bottom", yard)
	placeGroup(store, "ToolsOnGround", { "BucketWater" }, onGround(9.2, 5.0), 0, "bottom", yard)
	-- เสาไฟฟ้าคอนกรีต 2 ต้นริมทุ่ง + สายไฟ 40 studs ระหว่างเสา (คานเสาขวางแนวสาย)
	local p1, p2 = onGround(45, -32), onGround(85, -32)
	-- ให้โคนเสาสองต้นอยู่ระดับเดียวกัน (ต้นที่พื้นสูงกว่าจมดินลงไป) สายไฟจะได้พาดตรงลูกถ้วยทั้งสองฝั่ง
	local poleY = math.min(p1.Y, p2.Y)
	p1, p2 = Vector3.new(p1.X, poleY, p1.Z), Vector3.new(p2.X, poleY, p2.Z)
	placeGroup(store, "TvAntennaAndPoles", { "ConcretePole" }, p1, 90, "bottom", yard)
	placeGroup(store, "TvAntennaAndPoles", { "ConcretePole" }, p2, 90, "bottom", yard)
	placeGroup(store, "PowerLines", { "PowerLine_40" }, Vector3.new(p1.X, p1.Y + 29.2, p1.Z), 90, "topStart", yard)
	setCollide(yard, true)

	Workspace:SetAttribute("ImportedPropsSwapped", true)
	MapBuilder.TintShackHaunted()
	MapBuilder.MuteBrightProps()
	MapBuilder.AddRoadPowerPoles()
	print("🏚️ [MapBuilder] สลับ placeholder เป็นโมเดลจาก Blender ครบแล้ว (ของเดิมอยู่ใน ServerStorage.ArchivedPlaceholders, ต้นแบบอยู่ใน ServerStorage.ImportedProps)")
end

-- ===================================================================================
-- เสาไฟไม้เรียงตามถนนตั้งแต่ทางเข้า (VehicleWaypoints.SpawnPoint) ถึงทางออก (ExitPoint) พร้อมสายไฟ 4 เส้นพาดต่อกันทุกต้น
-- รวมเสาต้นที่มีหลอด (DirtRoad.WoodenPole + NeonLightPart) ด้วย: หมุนเสาทุกต้นให้คานลูกถ้วยขวางถนน
-- เสาต้นอื่นไม่มีหลอด (ฝาโคมเปล่า) และปิดแสงที่ไม่ได้มาจากหลอดไฟ (แสงเรืองที่ศาลพระภูมิ)
-- ===================================================================================
local POLE_YAW = -90 -- คานขวางถนน (ถนนวิ่งตามแกน X) และโคมของเสาที่มีหลอดหันเข้าหาร้าน
local INSULATOR_X = { -2.2, -1.0, 1.0, 2.2 } -- ตำแหน่งลูกถ้วยบนคาน (studs จากแกนเสา)
local INSULATOR_Y = 21.6 -- ความสูงยอดลูกถ้วยจากโคนเสา

-- ตำแหน่งโคนแกนเสาในพิกัดของ MeshPart (โมเดลจาก Blender: โคมยื่นไปทาง -Z, แกนเสาอยู่ห่างขอบ +Z ราว 0.45)
local function poleAxisLocal(pole: BasePart): Vector3
	return Vector3.new(0, -pole.Size.Y / 2, pole.Size.Z / 2 - 0.45)
end

local function insulatorWorld(pole: BasePart, i: number): Vector3
	local a = poleAxisLocal(pole)
	return pole.CFrame:PointToWorldSpace(Vector3.new(INSULATOR_X[i], a.Y + INSULATOR_Y, a.Z))
end

local function wireSegment(a: Vector3, b: Vector3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "Wire"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new((b - a).Magnitude + 0.04, 0.09, 0.09)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(18, 18, 18)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
end

local function sagWire(a: Vector3, b: Vector3, parent: Instance)
	local n = 10
	local sag = 0.03 * (b - a).Magnitude
	local prev = a
	for k = 1, n do
		local t = k / n
		local pt = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		wireSegment(prev, pt, parent)
		prev = pt
	end
end

function MapBuilder.AddRoadPowerPoles()
	if Workspace:GetAttribute("RoadPowerPolesAdded") then
		warn("[MapBuilder] AddRoadPowerPoles: เคยเพิ่มไปแล้ว (ลบ attribute RoadPowerPolesAdded ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local env = Workspace:FindFirstChild("MapEnvironment")
	local road = env and env:FindFirstChild("DirtRoad")
	local litPole = road and road:FindFirstChild("WoodenPole") :: BasePart
	local tplModel = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	tplModel = tplModel and tplModel:FindFirstChild("TvAntennaAndPoles")
	local tplPole = tplModel and tplModel:FindFirstChild("WoodenPole") :: BasePart
	local wp = Workspace:FindFirstChild("VehicleWaypoints")
	assert(litPole and tplPole and wp, "ไม่พบ DirtRoad.WoodenPole / ImportedProps.TvAntennaAndPoles.WoodenPole / VehicleWaypoints")

	-- แนวเสาอยู่ฝั่งตรงข้ามร้าน (ร้านใช้ไฟจากเครื่องปั่นไฟ ไม่มีสายเข้าร้าน)
	-- ถนนวิ่งตามแกน X: กลางถนน = ค่า Z เฉลี่ยของจุดเข้า/ออก, ร้านอยู่ฝั่ง +Z จึงวางเสาที่ฝั่ง -Z ห่างกลางถนน 9 studs (ไหล่ทางหญ้า)
	local spawnPt, exitPt = wp:FindFirstChild("SpawnPoint"), wp:FindFirstChild("ExitPoint")
	local roadZ = if spawnPt and exitPt then (spawnPt.Position.Z + exitPt.Position.Z) / 2 else -11.5
	local shack = env:FindFirstChild("ShackStructure")
	local shopSide = if shack and shack:GetPivot().Position.Z < roadZ then -1 else 1
	local lineZ = roadZ - shopSide * 9
	local xs = { -112, -75, -45, -15, 15, 45, 75, 105, 126 }
	if spawnPt and exitPt then
		xs[1] = math.floor(spawnPt.Position.X)
		xs[#xs] = math.ceil(exitPt.Position.X)
	end

	-- เสาชุดเก่า (ถ้ามี) ย้ายไปเก็บ ไม่ลบ
	local oldLine = env:FindFirstChild("RoadPowerPoles")
	if oldLine then
		archivePlaceholder(oldLine)
	end
	local folder = Instance.new("Model")
	folder.Name = "RoadPowerPoles"
	folder.Parent = env

	-- เสาไม้เก่าสีหลอน: ไม้ดำคล้ำ และเอียงคนละนิดแบบเสาผุ
	local rng = Random.new(1313)
	local tplRot = tplPole.CFrame - tplPole.Position
	local function hauntedWood(p: BasePart)
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa.Color = Color3.fromRGB(78, 72, 66)
		end
	end

	-- เสาฝั่งตรงข้ามร้าน: ไม่มีหลอดและไม่มีโคม (ใช้ WoodenPolePlain.fbx ถ้านำเข้าแล้ว ไม่งั้นใช้เสาแบบมีฝาโคม)
	local store = moveTemplatesToStorage()
	local plainModel = store:FindFirstChild("WoodenPolePlain")
	local plainPole = plainModel and plainModel:FindFirstChild("WoodenPolePlain") :: BasePart?
	local farTpl = plainPole or tplPole
	local farRot = farTpl.CFrame - farTpl.Position
	local poles = {}
	for _, x in ipairs(xs) do
		local c = farTpl:Clone()
		c.Name = "WoodenPole"
		local base = Vector3.new(x, groundY(x, lineZ) - 0.4, lineZ)
		local lean = CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(-3, 3)))
		c.CFrame = CFrame.new(base) * lean * CFrame.Angles(0, math.rad(POLE_YAW), 0) * CFrame.new(-poleAxisLocal(farTpl)) * farRot
		c.Anchored = true
		c:SetAttribute("ImportedProp", true)
		hauntedWood(c)
		c.Parent = folder
		table.insert(poles, c)
	end

	-- เสาหน้าร้านที่มีหลอด (+NeonLightPart/FlickerLight): อยู่ที่เดิมหน้าร้าน ตั้งตรง โคมหันออกถนน (คานขนานถนน)
	local archived = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
	local oldPolePart = archived and archived:FindFirstChild("WoodenPole") :: BasePart?
	local litBaseXZ = if oldPolePart then Vector3.new(oldPolePart.Position.X, 0, oldPolePart.Position.Z) else Vector3.new(-15, 0, -0.5)
	local litAxis = Vector3.new(litBaseXZ.X, groundY(litBaseXZ.X, litBaseXZ.Z) - 0.4, litBaseXZ.Z + tplPole.Size.Z / 2 - 0.45)
	local litCF = CFrame.new(litAxis) * CFrame.new(-poleAxisLocal(tplPole)) * tplRot
	local delta = litCF * litPole.CFrame:Inverse()
	litPole.CFrame = litCF
	local bulb = road:FindFirstChild("NeonLightPart") :: BasePart
	if bulb then
		bulb.CFrame = delta * bulb.CFrame
	end
	hauntedWood(litPole)

	-- 3) สายไฟ 4 เส้นพาดต่อกันทุกต้น (รวมเสาที่มีหลอด)
	local wires = Instance.new("Model")
	wires.Name = "Wires"
	wires.Parent = folder
	for i = 1, #poles - 1 do
		for k = 1, #INSULATOR_X do
			sagWire(insulatorWorld(poles[i], k), insulatorWorld(poles[i + 1], k), wires)
		end
	end
	-- โคมเสาหน้าร้านใช้ไฟจากเครื่องปั่นไฟของร้าน: สายเส้นเดียวจากหัวเสาเพิงต้นที่ใกล้ที่สุด มาเข้าเสาที่ระดับโคม
	-- (ไม่ต่อกับแนวสายไฟฝั่งตรงข้าม)
	local shackModel = env:FindFirstChild("ShackStructure")
	local importedShack = shackModel and shackModel:FindFirstChild("ImportedShack")
	local nearPillar, best = nil, math.huge
	if importedShack then
		for _, p in ipairs(importedShack:GetChildren()) do
			if p.Name == "WoodenPillar" and p:IsA("BasePart") then
				local d = (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(litPole.Position.X, 0, litPole.Position.Z)).Magnitude
				if d < best then
					nearPillar, best = p, d
				end
			end
		end
	end
	if nearPillar then
		local from = nearPillar.Position + Vector3.new(0, nearPillar.Size.Y / 2 - 0.4, 0)
		local axisLocal = poleAxisLocal(litPole)
		local to = litPole.CFrame:PointToWorldSpace(Vector3.new(0, axisLocal.Y + 16.2, axisLocal.Z + 0.35))
		sagWire(from, to, wires)
	end

	-- 4) แหล่งแสงนอกจากไฟฉายให้มีแค่หลอดไฟ: ปิดแสงเรืองที่ศาลพระภูมิ (ปลายธูปยังเป็นถ่านแดงแต่ไม่ส่องแสง)
	local spirit = Workspace:FindFirstChild("SpiritHouse")
	if spirit then
		for _, l in ipairs(spirit:GetDescendants()) do
			if l:IsA("Light") then
				l.Enabled = false
			end
		end
	end

	Workspace:SetAttribute("RoadPowerPolesAdded", true)
	print("🔌 [MapBuilder] วางเสาไฟไม้ " .. #poles .. " ต้นตามถนนพร้อมสายไฟแล้ว")
end

-- วางแนวเสาไฟใหม่ (เสาชุดเก่าย้ายไป ArchivedPlaceholders)
function MapBuilder.RebuildRoadPowerPoles()
	Workspace:SetAttribute("RoadPowerPolesAdded", nil)
	MapBuilder.AddRoadPowerPoles()
end

-- ย้ายเงาคนแอบ (AnomalyProps.BanyanShadowAnomaly) ออกจากลำต้นไทรใหม่ ไปยืนหลบชิดลำต้นฝั่งที่มองไม่เห็นจากถนน/ร้าน
-- หาผิวลำต้นด้วย raycast จากด้านนอกเข้าหาแกนต้น แล้ววางเงาห่างผิว 0.6 stud หันหน้าเข้าหาลำต้น (ท่าแอบ)
function MapBuilder.HideBanyanShadowBehindTree()
	local anomaly = Workspace:FindFirstChild("AnomalyProps")
	local shadow = anomaly and anomaly:FindFirstChild("BanyanShadowAnomaly")
	local zone = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("SacredBanyanZone")
	local tree = zone and zone:FindFirstChild("SacredBanyanTree")
	if not shadow or not tree then
		warn("[MapBuilder] HideBanyanShadowBehindTree: ไม่พบ BanyanShadowAnomaly หรือ SacredBanyanTree")
		return
	end
	local trunk = tree:FindFirstChild("BanyanTrunk") :: BasePart
	-- แกนลำต้นที่โคน = pivot ของต้นไทร (ตำแหน่งลำต้นในฉาก - ในต้นแบบ) ; ไม่ใช้ trunk.Position เพราะเป็นกึ่งกลางกล่องที่รวมกิ่งเอียง
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	local tplTree = store and store:FindFirstChild("SacredBanyanTree")
	local center = if tplTree then trunk.Position - tplTree.BanyanTrunk.Position + tplTree:GetPivot().Position else trunk.Position
	-- ถนนอยู่ฝั่ง -Z และร้านอยู่ฝั่ง +X ของต้นไทร: หลบไปทาง +Z ค่อนไป -X
	local dir = Vector3.new(-0.45, 0, 1).Unit
	local _, size = shadow:GetBoundingBox()
	-- รัศมีลำต้นช่วงอกราว 4.8 studs: วางเงาห่างแกน 6.5 studs ให้พ้นผิวลำต้นแต่ยังชิดพอให้ดูเหมือนแอบ
	local spot = Vector3.new(center.X, 0, center.Z) + dir * 6.5
	local floorY = groundY(spot.X, spot.Z)
	local pos = Vector3.new(spot.X, floorY + size.Y / 2, spot.Z)
	local look = Vector3.new(center.X, pos.Y, center.Z)
	local target = CFrame.lookAt(pos, look)
	-- ย้ายทั้งโมเดลตาม bounding box (ไม่แตะโครงสร้างภายใน)
	local bboxCF = shadow:GetBoundingBox()
	shadow:PivotTo(target * bboxCF:ToObjectSpace(shadow:GetPivot()))
	print("👤 [MapBuilder] ย้ายเงาคนแอบไปหลบหลังต้นไทรแล้ว")
end

-- ===================================================================================
-- ชุดโมเดลไทยบ้านรอบ 2 (MarbleTableSet, KilometerPost, DragonJar, Scarecrow, SquatToilet, HandLights)
-- ย้ายต้นแบบจาก Workspace / NewModels ไป ServerStorage.ImportedProps แล้ววางแทนของเดิม (ของเดิมเก็บใน ArchivedPlaceholders)
-- ===================================================================================
local THAI_PROPS = { "MarbleTableSet", "KilometerPost", "DragonJar", "Scarecrow", "SquatToilet", "HandLights" }

function MapBuilder.SwapThaiProps()
	if Workspace:GetAttribute("ThaiPropsSwapped") then
		warn("[MapBuilder] SwapThaiProps: เคยสลับไปแล้ว (ลบ attribute ThaiPropsSwapped ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = moveTemplatesToStorage()
	for _, name in ipairs(THAI_PROPS) do
		if not store:FindFirstChild(name) then
			local m = Workspace:FindFirstChild(name)
			if not (m and m:IsA("Model")) then
				local nm = Workspace:FindFirstChild("NewModels")
				m = nm and nm:FindFirstChild(name)
			end
			-- ต้นแบบที่นำเข้ามาต้องมีชิ้นตามชื่อไฟล์ (กันหยิบ Scarecrow ของเพื่อนใน AnomalyProps ผิดตัว)
			assert(m and m:IsA("Model") and m.Parent ~= Workspace:FindFirstChild("AnomalyProps"), "ไม่พบโมเดลที่นำเข้า " .. name)
			m.Parent = store
		end
	end
	local env = Workspace.MapEnvironment
	local anomaly = Workspace.AnomalyProps

	-- 1) โต๊ะ + ม้านั่งหินขัด แทน OldMarbleBenchSet ใต้ต้นไทร (ป้ายชื่อย้ายตาม)
	local zone = env:FindFirstChild("SacredBanyanZone")
	local oldBench = zone and zone:FindFirstChild("OldMarbleBenchSet")
	if oldBench then
		local base = bottomCenter({ oldBench })
		local m = newModel("OldMarbleBenchSet", zone)
		local placed = placeGroup(store, "MarbleTableSet", { "MarbleTable", "MarbleBench1", "MarbleBench2", "MarbleBench3", "MarbleBench4" }, base, 0, "bottom", m)
		m.PrimaryPart = placed.MarbleTable
		moveLabel(oldBench, placed.MarbleTable)
		archivePlaceholder(oldBench)
	end

	-- 2) หลักกิโล แทน DirtRoad.KilometerMilestone (คงชื่อเดิม, หน้าตัวเลขหันออกถนน)
	local road = env:FindFirstChild("DirtRoad")
	local km = road and road:FindFirstChild("KilometerMilestone")
	if km then
		local b = bottomCenter({ km })
		local base = Vector3.new(b.X, groundY(b.X, b.Z) - 0.05, b.Z)
		local placed = placeGroup(store, "KilometerPost", { "KilometerPost" }, base, 0, "bottom", road)
		moveLabel(km, placed.KilometerPost)
		archivePlaceholder(km)
		placed.KilometerPost.Name = "KilometerMilestone"
		placed.KilometerPost:SetAttribute("ImportedProp", true)
	end

	-- 3) โอ่งหน้าห้องน้ำ แทน TinOuthouse.DragonJar (ยกขันขึ้นให้ลอยบนน้ำในโอ่งใหม่)
	local outhouse = anomaly:FindFirstChild("TinOuthouse")
	local oldJar = outhouse and outhouse:FindFirstChild("DragonJar")
	if oldJar then
		local base = bottomCenter({ oldJar })
		local placed = placeGroup(store, "DragonJar", { "DragonJar", "DragonJar_Water" }, base, 0, "bottom", outhouse)
		archivePlaceholder(oldJar)
		local dipper = outhouse:FindFirstChild("WaterDipper") :: BasePart
		if dipper then
			local water = placed.DragonJar_Water
			local dmn = boundsOf({ dipper })
			dipper.CFrame = dipper.CFrame + Vector3.new(0, water.Position.Y + 0.01 - dmn.Y, 0)
		end
	end

	-- 4) ส้วมนั่งยองในห้องน้ำสังกะสี (ไม่มี placeholder): กลางห้อง ด้านหน้าส้วมหันไปทางประตู
	local body = outhouse and outhouse:FindFirstChild("TinOuthouse") :: BasePart
	local door = outhouse and outhouse:FindFirstChild("TinOuthouse_Door") :: BasePart
	if body and door then
		local bmn, bmx = boundsOf({ body })
		local doorZ = door.Position.Z
		local floorTop = bmn.Y + 0.25 -- พื้นยกในห้องสูง 0.25 stud จากโคนโมเดล
		local center = Vector3.new((bmn.X + bmx.X) / 2, floorTop - 0.39, doorZ + 2.15) -- แผ่นปูนส้วมเสมอพื้นห้อง
		local placed = placeGroup(store, "SquatToilet", { "SquatToilet", "SquatToilet_Water" }, center, 0, "bottom", outhouse)
		placed.SquatToilet:SetAttribute("ImportedProp", true)
	end

	-- 5) หุ่นไล่กากลางนา แทน ScareCrow mesh ของเดิม (คง Model "Scarecrow" + Part ที่มีป้ายชื่อ/ParticleEmitter ไว้)
	local crowModel = anomaly:FindFirstChild("Scarecrow")
	local oldMesh = crowModel and crowModel:FindFirstChild("ScareCrow")
	if oldMesh then
		local b = bottomCenter({ oldMesh })
		local base = Vector3.new(b.X, groundY(b.X, b.Z) - 0.6, b.Z) -- เสาปักลงดิน 0.6
		local placed = placeGroup(store, "Scarecrow", { "Scarecrow", "Scarecrow_EyeL_Neon", "Scarecrow_EyeR_Neon" }, base, 180, "bottom", crowModel)
		for _, n in ipairs({ "Scarecrow_EyeL_Neon", "Scarecrow_EyeR_Neon" }) do
			makeNeon(placed[n], Color3.fromRGB(255, 40, 30))
			placed[n].CanCollide = false
		end
		crowModel.PrimaryPart = placed.Scarecrow
		archivePlaceholder(oldMesh)
	end

	-- 6) ตะเกียงพายุบนโต๊ะร้าน (ยังไม่จุด: เปลวไฟซ่อนไว้ ใช้ทำ event ได้โดยตั้ง Transparency = 0)
	local shack = env.ShackStructure:FindFirstChild("ImportedShack")
	local counter = shack and shack:FindFirstChild("CounterTable") :: BasePart
	if counter then
		local _, cmx = boundsOf({ counter })
		local placed = placeGroup(store, "HandLights", { "StormLantern", "StormLantern_Glass", "StormLantern_Neon" }, Vector3.new(-5.6, cmx.Y + 0.01, 13.6), 20, "bottom", shack)
		local glass = placed.StormLantern_Glass
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.5
		glass.CanCollide = false
		local flame = placed.StormLantern_Neon
		makeNeon(flame, Color3.fromRGB(255, 150, 60))
		flame.Transparency = 1
		flame.CanCollide = false
	end

	-- 7) ไฟฉายของผู้เล่น (StarterPack.FrogFlashlight): ใส่โมเดลไฟฉายเชื่อมกับ Handle เดิม ซ่อนชิ้นเดิม (สคริปต์/SpotLight คงเดิม)
	local tool = game:GetService("StarterPack"):FindFirstChild("FrogFlashlight")
	local handle = tool and tool:FindFirstChild("Handle") :: BasePart
	local tplLights = store:FindFirstChild("HandLights")
	if handle and tplLights and not handle:FindFirstChild("FlashlightModel") then
		local body = tplLights.Flashlight:Clone()
		local lens = tplLights.Flashlight_Neon:Clone()
		local k = handle.Size.Z / body.Size.Z
		local lensOffset = lens.Position - body.Position
		body.Size *= k
		lens.Size *= k
		-- โมเดลส่องไป +Z แต่ Tool ส่องไป -Z: หมุน 180 องศารอบแกนตั้ง
		local rot = CFrame.Angles(0, math.pi, 0)
		body.CFrame = handle.CFrame * rot * (body.CFrame - body.Position)
		lens.CFrame = handle.CFrame * rot * CFrame.new(lensOffset * k) * (lens.CFrame - lens.Position)
		makeNeon(lens, Color3.fromRGB(255, 240, 200))
		for _, p in ipairs({ body, lens }) do
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			p.Parent = handle
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
		body.Name = "FlashlightModel"
		lens.Name = "FlashlightLens"
		handle.Transparency = 1
		local rim = tool:FindFirstChild("YellowRim")
		if rim and rim:IsA("BasePart") then
			rim.Transparency = 1
		end
	end

	Workspace:SetAttribute("ThaiPropsSwapped", true)
	print("🏮 [MapBuilder] วางโมเดลไทยบ้านรอบ 2 ครบแล้ว")
end

-- ===================================================================================
-- ชุดพืชไทย: แทนของเดิมที่วางอยู่ (ต้นกล้วยใน BananaGrove, กอข้าวในนา, กอหญ้าริมถนน) ตำแหน่งเดิม ขนาดตามของเดิม
-- ของเดิมเก็บใน ServerStorage.ArchivedPlaceholders (ไม่ลบ)
-- ===================================================================================
local THAI_PLANTS = { "BananaClump", "BananaBunch", "BananaBlossom", "ThaiGrasses", "MangoTree" }
-- ยอดต้นกล้วยต้นสูงสุดในกอ (studs, แกน Roblox เทียบ pivot ที่โคนกอ) สำหรับห้อยเครือกล้วย
local BANANA_TOP = Vector3.new(-0.2, 9.4, 0.38)
-- ปลายก้านเครือกล้วย (เทียบ pivot ของเครือ) สำหรับห้อยหัวปลี
local BUNCH_END = Vector3.new(-0.9, -4.55, 0)

function MapBuilder.SwapThaiPlants()
	if Workspace:GetAttribute("ThaiPlantsSwapped") then
		warn("[MapBuilder] SwapThaiPlants: เคยสลับไปแล้ว (ลบ attribute ThaiPlantsSwapped ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = moveTemplatesToStorage()
	for _, name in ipairs(THAI_PLANTS) do
		if not store:FindFirstChild(name) then
			local m = Workspace:FindFirstChild(name)
			local nm = Workspace:FindFirstChild("NewModels")
			m = m or (nm and nm:FindFirstChild(name))
			assert(m and m:IsA("Model"), "ไม่พบโมเดลที่นำเข้า " .. name)
			m.Parent = store
		end
	end
	local env = Workspace.MapEnvironment
	local rng = Random.new(2026)

	local function placeScaled(file: string, names: { string }, base: Vector3, yaw: number, scale: number, parent: Instance, name: string): Model
		local m = Instance.new("Model")
		m.Name = name
		m:SetAttribute("ImportedProp", true)
		local placed = placeGroup(store, file, names, base, yaw, "origin", m)
		m.PrimaryPart = placed[names[1]]
		m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
		m.Parent = parent
		return m
	end

	-- 1) ต้นกล้วย: กอใหม่แทนทุกต้นเดิม ขนาดตามความสูงเดิม, ห้อยเครือ + หัวปลีทุก ๆ 3 กอ
	local grove = env:FindFirstChild("BananaGrove")
	if grove then
		local i = 0
		for _, old in ipairs(grove:GetChildren()) do
			if old:IsA("Model") and not old:GetAttribute("ImportedProp") then
				i += 1
				local _, s = old:GetBoundingBox()
				local b = bottomCenter({ old })
				local base = Vector3.new(b.X, groundY(b.X, b.Z) - 0.1, b.Z)
				local yaw = rng:NextNumber(0, 360)
				local m = placeScaled("BananaClump", { "BananaClump", "BananaClump_B", "BananaClump_Base" }, base, yaw, 1, grove, old.Name)
				if i % 3 == 1 then
					local rot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
					local top = rot:PointToWorldSpace(BANANA_TOP)
					local byaw = yaw + rng:NextNumber(0, 360)
					placeGroup(store, "BananaBunch", { "BananaBunch" }, top, byaw, "origin", m)
					local tip = (CFrame.new(top) * CFrame.Angles(0, math.rad(byaw), 0)):PointToWorldSpace(BUNCH_END)
					placeGroup(store, "BananaBlossom", { "BananaBlossom" }, tip, byaw, "origin", m)
				end
				m:ScaleTo(math.clamp(s.Y / 13.6, 0.6, 1.1))
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = d.Name == "BananaClump_Base"
						d.CastShadow = d.Name ~= "BananaClump_Base"
					end
				end
				archivePlaceholder(old)
			end
		end
	end

	-- 2) กอข้าว: แถวต้นข้าวเพิ่งดำ (3 กอ) แทนทุกกอเดิมในนา หันแนวแถวไปทางเดียวกันทั้งแปลง
	local fields = { env:FindFirstChild("RiceField"), env:FindFirstChild("BackRiceField") }
	local nm = Workspace:FindFirstChild("NewModels")
	-- แปลงข้างมีทั้งใน MapEnvironment และ NewModels (คนละตำแหน่ง) ทำทั้งคู่
	for _, n in ipairs({ "LeftRiceField", "RightRiceField" }) do
		for _, root in ipairs({ env, nm }) do
			local f = root and root:FindFirstChild(n)
			if f then
				table.insert(fields, f)
			end
		end
	end
	for _, field in ipairs(fields) do
		for _, old in ipairs(field:GetChildren()) do
			if old:IsA("Model") and old.Name:match("^RiceGrass") and not old:GetAttribute("ImportedProp") then
				local b = bottomCenter({ old })
				local m = placeScaled("ThaiGrasses", { "RicePaddyPatch" }, Vector3.new(b.X, b.Y + 0.15, b.Z), 0, 1, field, old.Name)
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CastShadow = false
					end
				end
				archivePlaceholder(old)
			end
		end
	end

	-- 3) กอหญ้าริมถนน: กอหญ้าดอกฟูแทนทุกกอเดิม ขนาดตามความสูงเดิม
	local road = env:FindFirstChild("DirtRoad")
	if road then
		for _, old in ipairs(road:GetChildren()) do
			if old:IsA("Model") and old.Name:match("^RoadsideGrass") and not old:GetAttribute("ImportedProp") then
				local _, s = old:GetBoundingBox()
				local b = bottomCenter({ old })
				local m = placeScaled("ThaiGrasses", { "WildGrassClump" }, Vector3.new(b.X, groundY(b.X, b.Z), b.Z), rng:NextNumber(0, 360), 1, road, old.Name)
				m:ScaleTo(math.clamp(s.Y / 4.6, 0.55, 1.0))
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
					end
				end
				archivePlaceholder(old)
			end
		end
	end

	-- 4) นาข้าวรอบนอก (BackRiceField ที่ราก Workspace 6 แปลง)
	for _, f in ipairs(Workspace:GetChildren()) do
		if f:IsA("Model") and f.Name == "BackRiceField" then
			for _, old in ipairs(f:GetChildren()) do
				if old:IsA("Model") and old.Name:match("^RiceGrass") and not old:GetAttribute("ImportedProp") then
					local b = bottomCenter({ old })
					local m = placeScaled("ThaiGrasses", { "RicePaddyPatch" }, Vector3.new(b.X, b.Y + 0.15, b.Z), 0, 1, f, old.Name)
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then
							d.CanCollide = false
							d.CastShadow = false
						end
					end
					archivePlaceholder(old)
				end
			end
		end
	end

	-- 5) กอหญ้าแนวขอบแมพ (OuterTreeLine.BorderGrass): สลับกอหญ้าดอกฟูกับกอตะไคร้ ขนาดตามของเดิม
	local otl = env:FindFirstChild("OuterTreeLine")
	if otl then
		local k = 0
		for _, old in ipairs(otl:GetChildren()) do
			if old:IsA("Model") and old.Name:match("^BorderGrass") and not old:GetAttribute("ImportedProp") then
				k += 1
				local _, s = old:GetBoundingBox()
				local b = bottomCenter({ old })
				local kind = if k % 3 == 0 then "LemongrassClump" else "WildGrassClump"
				local m = placeScaled("ThaiGrasses", { kind }, Vector3.new(b.X, groundY(b.X, b.Z), b.Z), rng:NextNumber(0, 360), 1, otl, old.Name)
				m:ScaleTo(math.clamp(s.Y / (if kind == "LemongrassClump" then 4.8 else 4.6), 0.55, 1.0))
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
					end
				end
				archivePlaceholder(old)
			end
		end
	end

	-- 6) ต้นไม้แนวขอบแมพ (OuterTreeLine.BorderTree): ทุก 6 ต้น แทนมะม่วง 1 ต้น (ใบแบบเบา) และกอกล้วย 1 กอ ที่เหลือคงเดิม
	if otl then
		local k = 0
		for _, old in ipairs(otl:GetChildren()) do
			if old:IsA("Model") and old.Name:match("^BorderTree") and not old:GetAttribute("ImportedProp") then
				k += 1
				local b = bottomCenter({ old })
				local base = Vector3.new(b.X, groundY(b.X, b.Z) - 0.2, b.Z)
				if k % 6 == 1 then
					local m = placeScaled("MangoTree", { "MangoTrunk", "MangoTwigs" }, base, rng:NextNumber(0, 360), 1, otl, old.Name)
					m.MangoTwigs.CanCollide = false
					MapBuilder.AddMangoLeaves(m, true)
					archivePlaceholder(old)
				elseif k % 6 == 4 then
					local m = placeScaled("BananaClump", { "BananaClump", "BananaClump_B", "BananaClump_Base" }, base, rng:NextNumber(0, 360), 1, otl, old.Name)
					m:ScaleTo(0.85)
					for _, d in ipairs(m:GetDescendants()) do
						if d:IsA("BasePart") then
							d.CanCollide = false
						end
					end
					archivePlaceholder(old)
				end
			end
		end
	end

	Workspace:SetAttribute("ThaiPlantsSwapped", true)
	MapBuilder.TagWindPlants()
	print("🍌 [MapBuilder] แทนต้นกล้วย กอข้าว และกอหญ้าเดิมด้วยโมเดลพืชไทยแล้ว")
end

-- กอตะไคร้/กอหญ้าตามคันนา: หาคันนาจากจุดที่พื้นสูงกว่าผิวน้ำในแต่ละแปลง แล้ววางกอห่างกันอย่างน้อย 5 studs
function MapBuilder.AddBundClumps()
	if Workspace:GetAttribute("BundClumpsAdded") then
		warn("[MapBuilder] AddBundClumps: เคยเพิ่มไปแล้ว (ลบ attribute BundClumpsAdded ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	assert(store and store:FindFirstChild("ThaiGrasses"), "ไม่พบ ImportedProps.ThaiGrasses")
	local env = Workspace.MapEnvironment
	local waters = {}
	-- เฉพาะนา 4 แปลงในเขตเล่น (นารอบนอกไกล ไม่ต้องใส่ เพื่อประหยัดเครื่อง)
	for _, d in ipairs(env:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:match("^PaddyWater") then
			table.insert(waters, d)
		end
	end
	local include = { Workspace.Terrain }
	for _, w in ipairs(waters) do
		table.insert(include, w)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local rng = Random.new(77)
	local placed: { Vector3 } = {}
	local folder = Instance.new("Model")
	folder.Name = "BundClumps"
	folder.Parent = env
	local count = 0
	for _, w in ipairs(waters) do
		local top = w.Position.Y + w.Size.Y / 2
		local hx, hz = w.Size.X / 2 + 2, w.Size.Z / 2 + 2
		for x = -hx, hx, 2.5 do
			for z = -hz, hz, 2.5 do
				local p = w.CFrame:PointToWorldSpace(Vector3.new(x + rng:NextNumber(-0.8, 0.8), 0, z + rng:NextNumber(-0.8, 0.8)))
				local hit = Workspace:Raycast(Vector3.new(p.X, top + 30, p.Z), Vector3.new(0, -60, 0), params)
				if hit and hit.Instance == Workspace.Terrain and hit.Position.Y > top + 0.15 and hit.Position.Y < top + 3 then
					local ok = true
					for _, q in ipairs(placed) do
						if (Vector3.new(q.X, 0, q.Z) - Vector3.new(hit.Position.X, 0, hit.Position.Z)).Magnitude < 8 then
							ok = false
							break
						end
					end
					if ok and rng:NextNumber() < 0.6 then
						table.insert(placed, hit.Position)
						count += 1
						local kind = if count % 3 == 0 then "WildGrassClump" else "LemongrassClump"
						local m = Instance.new("Model")
						m.Name = "Bund" .. kind .. "_" .. count
						m:SetAttribute("ImportedProp", true)
						local base = hit.Position - Vector3.new(0, 0.1, 0)
						local yaw = rng:NextNumber(0, 360)
						local pl = placeGroup(store, "ThaiGrasses", { kind }, base, yaw, "origin", m)
						m.PrimaryPart = pl[kind]
						m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
						m.Parent = folder
						m:ScaleTo(rng:NextNumber(0.55, 0.8))
						for _, d in ipairs(m:GetDescendants()) do
							if d:IsA("BasePart") then
								d.CanCollide = false
							end
						end
					end
				end
			end
		end
	end
	Workspace:SetAttribute("BundClumpsAdded", true)
	MapBuilder.TagWindPlants()
	print("🌾 [MapBuilder] วางกอตะไคร้/หญ้าตามคันนา " .. count .. " กอ")
end

-- ต้นข้าวเต็มแปลง: ปูแผ่น RiceTile (16 กอ 6.4 x 6.4 studs) ทุกช่องที่เป็นผิวน้ำในนา 4 แปลงเขตเล่น
-- แถวข้าว 3 กอ (RicePaddyPatch) ที่วางไว้ก่อนในแปลงเหล่านี้ถูกเอาออก (เป็นของที่นำเข้าเอง ไม่ใช่ของเดิม)
function MapBuilder.FillRicePaddies()
	if Workspace:GetAttribute("RicePaddiesFilled") then
		warn("[MapBuilder] FillRicePaddies: เคยทำแล้ว (ลบ attribute RicePaddiesFilled ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = moveTemplatesToStorage()
	if not store:FindFirstChild("RiceTile") then
		local m = Workspace:FindFirstChild("RiceTile") or (Workspace:FindFirstChild("NewModels") and Workspace.NewModels:FindFirstChild("RiceTile"))
		assert(m and m:IsA("Model"), "ไม่พบโมเดลที่นำเข้า RiceTile")
		m.Parent = store
	end
	local tpl = store.RiceTile.RiceTile :: BasePart
	local env = Workspace.MapEnvironment
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local total = 0
	for _, field in ipairs(env:GetChildren()) do
		local water = nil
		for _, c in ipairs(field:GetChildren()) do
			if c:IsA("BasePart") and c.Name:match("^PaddyWater") then
				water = c
			end
		end
		if water then
			for _, c in ipairs(field:GetChildren()) do
				if c:IsA("Model") and c.Name:match("^RiceGrass") and c:GetAttribute("ImportedProp") then
					c:Destroy()
				end
			end
			params.FilterDescendantsInstances = { Workspace.Terrain, water }
			local top = water.Position.Y + water.Size.Y / 2
			local tiles = Instance.new("Model")
			tiles.Name = "RiceTiles"
			tiles.Parent = field
			local hx, hz = water.Size.X / 2, water.Size.Z / 2
			for x = -hx + 3.2, hx - 3.2, 6.4 do
				for z = -hz + 3.2, hz - 3.2, 6.4 do
					local ok = true
					for _, o in ipairs({ Vector3.zero, Vector3.new(2.4, 0, 2.4), Vector3.new(-2.4, 0, 2.4), Vector3.new(2.4, 0, -2.4), Vector3.new(-2.4, 0, -2.4) }) do
						local p = water.CFrame:PointToWorldSpace(Vector3.new(x, 0, z) + o)
						local hit = Workspace:Raycast(Vector3.new(p.X, top + 20, p.Z), Vector3.new(0, -40, 0), params)
						if not hit or hit.Instance ~= water then
							ok = false
							break
						end
					end
					if ok then
						local c = tpl:Clone()
						local p = water.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
						-- จุด origin ของแผ่น (ระดับ 0 ใน Blender) วางที่ผิวน้ำ โคนกออยู่ใต้น้ำ 0.2 stud
						local offset = tpl.Position - store.RiceTile:GetPivot().Position
						c.CFrame = (tpl.CFrame - tpl.CFrame.Position) + Vector3.new(p.X, top, p.Z) + offset
						c.Anchored = true
						c.CanCollide = false
						c.CastShadow = false
						c:SetAttribute("ImportedProp", true)
						c.Parent = tiles
						total += 1
					end
				end
			end
		end
	end
	Workspace:SetAttribute("RicePaddiesFilled", true)
	print("🌾 [MapBuilder] ปูต้นข้าวเต็มแปลง " .. total .. " แผ่น")
end

-- ต้นไม้บนภูเขาด้านข้าง: ต้นมะม่วงแบบใบเบา (far) บนเนินภูเขานอกเขตเล่น ห่างกันอย่างน้อย 20 studs
function MapBuilder.AddMountainTrees(maxTrees: number?)
	if Workspace:GetAttribute("MountainTreesAdded") then
		warn("[MapBuilder] AddMountainTrees: เคยเพิ่มไปแล้ว (ลบ attribute MountainTreesAdded ที่ Workspace ถ้าต้องการรันใหม่)")
		return
	end
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	assert(store and store:FindFirstChild("MangoTree"), "ไม่พบ ImportedProps.MangoTree")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local rng = Random.new(4242)
	local folder = Instance.new("Model")
	folder.Name = "MountainTrees"
	folder.Parent = Workspace.MapEnvironment
	local placed: { Vector3 } = {}
	local cands = {}
	for x = -320, 320, 16 do
		for z = -280, 280, 16 do
			if math.abs(x) > 100 or math.abs(z) > 90 then
				local px, pz = x + rng:NextNumber(-6, 6), z + rng:NextNumber(-6, 6)
				local hit = Workspace:Raycast(Vector3.new(px, 400, pz), Vector3.new(0, -500, 0), params)
				if hit and hit.Position.Y > 8 and hit.Material ~= Enum.Material.Water then
					table.insert(cands, hit.Position)
				end
			end
		end
	end
	-- สุ่มลำดับ แล้ววางเรียงจากจุดที่ใกล้เขตเล่นก่อน (มองเห็นจากในเกม)
	table.sort(cands, function(a, b)
		return math.max(math.abs(a.X) - 100, math.abs(a.Z) - 90) < math.max(math.abs(b.X) - 100, math.abs(b.Z) - 90)
	end)
	local limit = maxTrees or 45
	for _, p in ipairs(cands) do
		if #placed >= limit then
			break
		end
		local ok = true
		for _, q in ipairs(placed) do
			if (q - p).Magnitude < 20 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(placed, p)
			local m = Instance.new("Model")
			m.Name = "MountainMango_" .. #placed
			m:SetAttribute("ImportedProp", true)
			local base = p - Vector3.new(0, 0.6, 0)
			local yaw = rng:NextNumber(0, 360)
			local pl = placeGroup(store, "MangoTree", { "MangoTrunk", "MangoTwigs" }, base, yaw, "origin", m)
			m.PrimaryPart = pl.MangoTrunk
			m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
			pl.MangoTwigs.CanCollide = false
			m.Parent = folder
			MapBuilder.AddMangoLeaves(m, true, true)
		end
	end
	Workspace:SetAttribute("MountainTreesAdded", true)
	print("⛰️ [MapBuilder] ปลูกต้นไม้บนภูเขาด้านข้าง " .. #placed .. " ต้น")
end

-- ติด tag ให้ GrassWind.client แกว่งตามลม (รันซ้ำได้ ต้องรันใหม่หลังสร้างใบไม้/ต้นข้าวใหม่):
--   "WindSway"    = ทั้งต้นเอนจากโคน: กอหญ้า/ตะไคร้, แผ่นต้นข้าว RiceTile, ต้นกล้วย, ต้นไม้ชายทุ่ง BorderTree
--                   attribute: SwayAmp (แรงเอน), SwaySpeed (ความเร็ว), SwayPush = false (ไม่เอนหลบเวลาคนเดินชน)
--   "LeafFlutter" = ลำต้นนิ่ง ใบไหวทีละใบ: BanyanLeaves (ต้นไทร), MangoLeaves (ต้นมะม่วงบนภูเขา)
function MapBuilder.TagWindPlants()
	local CollectionService = game:GetService("CollectionService")
	local function sway(inst: Instance, amp: number, speed: number?, push: boolean?)
		CollectionService:AddTag(inst, "WindSway")
		inst:SetAttribute("SwayAmp", amp)
		inst:SetAttribute("SwaySpeed", speed)
		inst:SetAttribute("SwayPush", push)
	end
	local grass, rice, trees, leaves = 0, 0, 0, 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("ImportedProp") and (d:FindFirstChild("WildGrassClump") or d:FindFirstChild("LemongrassClump")) then
			sway(d, if d:FindFirstChild("LemongrassClump") then 0.7 else 1)
			grass += 1
		elseif d:IsA("BasePart") and d.Name == "RiceTile" and d.Parent and d.Parent.Name == "RiceTiles" then
			-- แผ่นข้าวกว้าง 6 studs เอนมากไม่ได้ (ขอบแผ่นจะลอยพ้นน้ำ) และไม่ให้เอนหลบคนทั้งแผ่น
			sway(d, 0.5, 1.15, false)
			rice += 1
		elseif d:IsA("Model") and d.Name:match("^BananaTree") then
			sway(d, 0.45, 0.75)
			trees += 1
		elseif d:IsA("Model") and d.Name:match("^BorderTree") then
			if d:FindFirstChild("MangoLeaves") then
				-- ต้นมะม่วงชายทุ่งมีใบ ~110 แผ่น: ให้แค่ใบไหว (LeafFlutter) ถ้าเอนทั้งต้นด้วยจะหนักเครื่องและขยับซ้อนกัน
				CollectionService:RemoveTag(d, "WindSway")
			else
				sway(d, 0.3, 0.6, false)
				trees += 1
			end
		elseif d:IsA("Model") and (d.Name == "BanyanLeaves" or d.Name == "MangoLeaves") then
			CollectionService:AddTag(d, "LeafFlutter")
			leaves += 1
		end
	end
	print(string.format("🌬️ [MapBuilder] ติด tag ลม: กอหญ้า %d กอ, ต้นข้าว %d แผ่น, ต้นกล้วย/ต้นไม้ชายทุ่ง %d ต้น, พุ่มใบไม้ %d พุ่ม", grass, rice, trees, leaves))
end

-- ===================================================================================
-- Phase 2: รถลูกค้าแม่แบบ (ServerStorage.VehicleTemplates) ตาม phases.html
-- ใช้โมเดล CustomerBike / Saleng ที่นำเข้าจาก Blender (Workspace.NewModels) แล้วเพิ่ม:
--   Chassis (PrimaryPart, แกนกลางสำหรับ PivotTo), Headlight (+SpotLight), LicensePlate (SurfaceGui ปกติ/ผี),
--   WheelHairAnomaly (เส้นผม+ผ้าห่อศพพันล้อ ซ่อนไว้), DriverNPC (คนขับ), GhostPassenger (ผีไร้หัวซ้อนท้าย ซ่อนไว้)
-- แกนของรถ: หน้ารถ = -Z, pivot ของรถอยู่ที่พื้นใต้กึ่งกลางรถ หน่วย studs
-- ชิ้นที่ซ่อนไว้ทุกชิ้นมี attribute "ShowTransparency" = ค่าความโปร่งใสตอนแสดง ให้โค้ด Phase 4 ใช้คืนค่า
-- ===================================================================================
local SKIN = Color3.fromRGB(176, 128, 92)
local GHOST_SKIN = Color3.fromRGB(196, 196, 178)

local function vPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
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
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ส่วนตัวที่เป็นแท่งระหว่างสองจุด (แขน ขา)
local function limb(parent: Instance, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material?): Part
	local len = (b - a).Magnitude
	return vPart(parent, name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material)
end

local function hideForAnomaly(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d:SetAttribute("ShowTransparency", d.Transparency)
			d.Transparency = 1
		end
	end
	if root:IsA("BasePart") then
		root:SetAttribute("ShowTransparency", root.Transparency)
		root.Transparency = 1
	end
end

-- คนขับ: ชาวบ้านเสื้อม่อฮ่อม กางเกงขาก๊วย ผ้าขาวม้าคาดเอว นั่งบิดรถ มือจับแฮนด์ เท้าวางที่พักเท้า
-- hip = จุดก้นบนเบาะ, grip = ตำแหน่งปลายแฮนด์ (x ซ้าย/ขวา), foot = ที่พักเท้า (ทั้งหมดเป็นพิกัดในเฟรมของรถ)
local function buildDriver(vehicleCF: CFrame, hip: Vector3, gripL: Vector3, gripR: Vector3, footL: Vector3, footR: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "DriverNPC"
	local function at(v: Vector3): Vector3
		return vehicleCF:PointToWorldSpace(v)
	end
	local lean = CFrame.Angles(math.rad(-12), 0, 0) -- ตัวเอนไปข้างหน้าเล็กน้อย
	local torsoCF = vehicleCF * CFrame.new(hip + Vector3.new(0, 1.15, -0.05)) * lean
	local torso = vPart(m, "Torso", Vector3.new(1.9, 2.0, 1.0), torsoCF, Color3.fromRGB(28, 34, 58), Enum.Material.Fabric)
	-- ผ้าขาวม้าคาดเอว
	vPart(m, "Sash", Vector3.new(2.0, 0.35, 1.1), torsoCF * CFrame.new(0, -0.8, 0), Color3.fromRGB(150, 40, 40), Enum.Material.Fabric)
	-- หัว (ทรง R6) + หน้าปกติ + หน้ายิ้มหลอน (ซ่อน)
	local head = vPart(m, "Head", Vector3.new(1.9, 0.95, 0.95), torsoCF * CFrame.new(0, 1.5, 0), SKIN)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "FaceNormal"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	-- หน้ายิ้มฉีกถึงใบหู (ตาโปนขาว + ปากดำแดงกว้าง) ซ่อนไว้ใช้กับ anomaly
	local creepy = Instance.new("Model")
	creepy.Name = "CreepyFace"
	creepy.Parent = head
	local hf = head.CFrame
	for _, s in ipairs({ -1, 1 }) do
		vPart(creepy, "Eye", Vector3.new(0.28, 0.28, 0.28), hf * CFrame.new(s * 0.27, 0.15, -0.55), Color3.fromRGB(240, 240, 230), Enum.Material.Neon, Enum.PartType.Ball)
		vPart(creepy, "Pupil", Vector3.new(0.1, 0.1, 0.1), hf * CFrame.new(s * 0.27, 0.15, -0.68), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	vPart(creepy, "Smile", Vector3.new(1.3, 0.12, 0.06), hf * CFrame.new(0, -0.25, -0.6), Color3.fromRGB(40, 0, 0))
	for _, s in ipairs({ -1, 1 }) do
		vPart(creepy, "SmileCorner", Vector3.new(0.5, 0.1, 0.06), hf * CFrame.new(s * 0.78, -0.08, -0.48) * CFrame.Angles(0, s * math.rad(-35), s * math.rad(25)), Color3.fromRGB(40, 0, 0))
	end
	vPart(creepy, "Teeth", Vector3.new(1.1, 0.06, 0.05), hf * CFrame.new(0, -0.2, -0.62), Color3.fromRGB(220, 210, 180))
	hideForAnomaly(creepy)
	-- แขน: ไหล่ -> ศอก -> มือจับแฮนด์
	for _, side in ipairs({ { -1, gripL, "LeftArm" }, { 1, gripR, "RightArm" } }) do
		local s, grip, name = side[1], side[2], side[3]
		local shoulder = torsoCF:PointToWorldSpace(Vector3.new(s * 1.1, 0.75, 0))
		local hand = at(grip)
		local elbow = (shoulder + hand) / 2 + vehicleCF:VectorToWorldSpace(Vector3.new(s * 0.35, -0.35, 0))
		local arm = Instance.new("Model")
		arm.Name = name
		arm.Parent = m
		limb(arm, "Upper", shoulder, elbow, 0.75, Color3.fromRGB(28, 34, 58), Enum.Material.Fabric)
		limb(arm, "Lower", elbow, hand, 0.6, SKIN)
		vPart(arm, "Hand", Vector3.new(0.45, 0.45, 0.45), CFrame.new(hand), SKIN, nil, Enum.PartType.Ball)
	end
	-- ขา (Model "Legs" เพื่อซ่อนทั้งท่อนล่างได้ในคำสั่งเดียว): สะโพก -> เข่า -> เท้าบนที่พักเท้า
	local legs = Instance.new("Model")
	legs.Name = "Legs"
	legs.Parent = m
	for _, side in ipairs({ { -1, footL, "Left" }, { 1, footR, "Right" } }) do
		local s, foot, name = side[1], side[2], side[3]
		local hp = at(hip + Vector3.new(s * 0.5, 0.15, 0))
		local knee = at(Vector3.new(s * 0.75, hip.Y + 0.35, foot.Z - 0.15))
		local ft = at(foot + Vector3.new(0, 0.25, 0))
		limb(legs, name .. "Thigh", hp, knee, 0.85, Color3.fromRGB(20, 20, 24), Enum.Material.Fabric)
		limb(legs, name .. "Shin", knee, ft, 0.7, Color3.fromRGB(20, 20, 24), Enum.Material.Fabric)
		vPart(legs, name .. "Foot", Vector3.new(0.5, 0.3, 0.9), vehicleCF * CFrame.new(foot + Vector3.new(0, 0.15, -0.15)), Color3.fromRGB(70, 50, 35))
	end
	return m
end

-- ผีไร้หัวซ้อนท้าย: หญิงชุดไทย (สไบครีม ผ้าซิ่นแดงขอบทอง) นั่งกอดเอวคนขับ คอขาดเปื้อนเลือด (ซ่อนไว้ตั้งแต่เริ่ม)
local function buildGhostPassenger(vehicleCF: CFrame, hip: Vector3, driverWaist: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "GhostPassenger"
	local function at(v: Vector3): Vector3
		return vehicleCF:PointToWorldSpace(v)
	end
	local torsoCF = vehicleCF * CFrame.new(hip + Vector3.new(0, 1.05, 0)) * CFrame.Angles(math.rad(-10), 0, 0)
	vPart(m, "Torso", Vector3.new(1.6, 1.8, 0.85), torsoCF, GHOST_SKIN)
	-- สไบพาดเฉียง
	vPart(m, "Sabai", Vector3.new(1.7, 0.7, 0.95), torsoCF * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(214, 196, 150), Enum.Material.Fabric)
	vPart(m, "Belt", Vector3.new(1.7, 0.22, 0.95), torsoCF * CFrame.new(0, -0.8, 0), Color3.fromRGB(176, 140, 60), Enum.Material.Metal)
	-- คอขาด
	vPart(m, "NeckStump", Vector3.new(0.25, 0.55, 0.55), torsoCF * CFrame.new(0, 1.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 10, 12), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	vPart(m, "BloodDrip", Vector3.new(0.12, 0.6, 0.06), torsoCF * CFrame.new(0.2, 0.65, -0.44), Color3.fromRGB(110, 10, 12))
	-- แขนอ้อมกอดเอวคนขับ
	for _, s in ipairs({ -1, 1 }) do
		local shoulder = torsoCF:PointToWorldSpace(Vector3.new(s * 0.95, 0.65, 0))
		local hand = at(driverWaist + Vector3.new(s * 0.55, 0, -0.4))
		local elbow = at(driverWaist + Vector3.new(s * 1.25, 0.05, 0.45))
		limb(m, "Arm", shoulder, elbow, 0.5, GHOST_SKIN)
		limb(m, "Forearm", elbow, hand, 0.42, GHOST_SKIN)
	end
	-- ผ้าซิ่นคลุมตักถึงข้อเท้า นั่งคร่อม
	for _, s in ipairs({ -1, 1 }) do
		local hp = at(hip + Vector3.new(s * 0.45, 0.2, 0))
		local knee = at(Vector3.new(s * 0.7, hip.Y + 0.1, hip.Z - 0.55))
		local ft = at(Vector3.new(s * 0.68, 1.0, hip.Z - 0.65))
		limb(m, "SkirtThigh", hp, knee, 0.7, Color3.fromRGB(96, 18, 22), Enum.Material.Fabric)
		limb(m, "SkirtShin", knee, ft, 0.62, Color3.fromRGB(96, 18, 22), Enum.Material.Fabric)
		vPart(m, "SkirtHem", Vector3.new(0.68, 0.1, 0.68), CFrame.new(ft + Vector3.new(0, 0.05, 0)), Color3.fromRGB(176, 140, 60), Enum.Material.Fabric)
	end
	hideForAnomaly(m)
	return m
end

-- เส้นผมยาวดำ + ผ้าขาวห่อศพพันซี่ล้อหลัง (ซ่อนไว้)
local function buildWheelHair(vehicleCF: CFrame, hub: Vector3, radius: number): Model
	local m = Instance.new("Model")
	m.Name = "WheelHairAnomaly"
	local rng = Random.new(10)
	for k = 1, 14 do
		local a0 = rng:NextNumber(0, math.pi * 2)
		local prev = nil
		for j = 0, 5 do
			local a = a0 + j * 0.45
			local r = radius * rng:NextNumber(0.45, 1.0)
			local x = rng:NextNumber(-0.18, 0.18)
			local p = vehicleCF:PointToWorldSpace(hub + Vector3.new(x, r * math.sin(a), r * math.cos(a)))
			if prev then
				limb(m, "Hair", prev, p, 0.05, Color3.fromRGB(8, 8, 8))
			end
			prev = p
		end
		-- ปอยผมห้อยลงพื้น
		limb(m, "HairTail", prev, prev + Vector3.new(0, -rng:NextNumber(0.3, 0.9), 0), 0.05, Color3.fromRGB(8, 8, 8))
	end
	for k = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p0 = vehicleCF:PointToWorldSpace(hub + Vector3.new(0, 0.5 * math.sin(a), 0.5 * math.cos(a)))
		local p1 = vehicleCF:PointToWorldSpace(hub + Vector3.new(0.1, 0.95 * math.sin(a + 0.8), 0.95 * math.cos(a + 0.8)))
		local cloth = limb(m, "ShroudCloth", p0, p1, 0.22, Color3.fromRGB(226, 222, 206), Enum.Material.Fabric)
		cloth.Size = Vector3.new(cloth.Size.X, 0.06, cloth.Size.Z)
	end
	hideForAnomaly(m)
	return m
end

-- ป้ายทะเบียน: SurfaceGui ปกติ (พื้นขาวตัวดำ) + ป้ายผี (พื้นดำเปื้อนเลือด ตัวแดงเรืองแสง) ซ่อนไว้
local function buildPlate(vehicleCF: CFrame, center: Vector3): Part
	local plate = vPart(Instance.new("Folder"), "LicensePlate", Vector3.new(0.92, 0.5, 0.03), vehicleCF * CFrame.new(center) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(235, 235, 230))
	local function gui(name: string, bg: Color3, fg: Color3, top: string, bottom: string, glow: boolean, enabled: boolean)
		local g = Instance.new("SurfaceGui")
		g.Name = name
		g.Face = Enum.NormalId.Back -- ท้ายรถ (+Z)
		g.CanvasSize = Vector2.new(184, 100)
		g.LightInfluence = if glow then 0 else 1
		g.Brightness = if glow then 2 else 1
		g.Enabled = enabled
		g.Parent = plate
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = bg
		f.BorderSizePixel = 0
		f.Parent = g
		for i, txt in ipairs({ top, bottom }) do
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, -8, if i == 1 then 0.6 else 0.4, 0)
			t.Position = UDim2.new(0, 4, if i == 1 then 0 else 0.6, 0)
			t.Text = txt
			t.TextColor3 = fg
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.Parent = f
		end
		return g
	end
	gui("NormalPlate", Color3.fromRGB(240, 240, 235), Color3.fromRGB(20, 20, 20), "1กข 4512", "ราชบุรี RATCHABURI", false, true)
	local ghost = gui("GhostPlate", Color3.fromRGB(14, 6, 6), Color3.fromRGB(255, 30, 30), "4444", "ป่าช้า CEMETERY", true, false)
	-- คราบเลือดบนป้ายผี
	for k = 1, 3 do
		local d = Instance.new("Frame")
		d.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
		d.BorderSizePixel = 0
		d.Size = UDim2.new(0, 10 + k * 6, 0, 30 + k * 12)
		d.Position = UDim2.new(0.15 + k * 0.25, 0, 0, 0)
		d.ZIndex = 0
		d.Parent = ghost:FindFirstChildOfClass("Frame")
	end
	return plate
end

function MapBuilder.BuildVehicleTemplates()
	local ss = game:GetService("ServerStorage")
	local folder = ss:FindFirstChild("VehicleTemplates") or Instance.new("Folder")
	folder.Name = "VehicleTemplates"
	folder.Parent = ss
	local nm = Workspace:FindFirstChild("NewModels")
	-- พิกัดอ้างอิงจาก Blender (assets/models: CustomerBike.fbx / Saleng.fbx) แปลงเป็นแกน Roblox: X=-bx, Y=bz, Z=by
	local HIP = Vector3.new(0, 2.78, 0.95)
	local HIP2 = Vector3.new(0, 2.78, 2.25)
	local GRIP_L, GRIP_R = Vector3.new(1.05, 3.6, -1.3), Vector3.new(-1.05, 3.6, -1.3)
	local FOOT_L, FOOT_R = Vector3.new(0.82, 0.85, -0.05), Vector3.new(-0.82, 0.85, -0.05)
	for _, name in ipairs({ "CustomerBike", "Saleng" }) do
		local src = (nm and nm:FindFirstChild(name)) or folder:FindFirstChild(name)
		if src and not src:GetAttribute("TemplateReady") then
			local m = src :: Model
			local base = m:GetPivot() -- pivot = จุดกำเนิดจาก Blender (พื้นใต้กึ่งกลางรถ)
			local baseCF = CFrame.new(base.Position) * (base - base.Position)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			-- แกนกลางรถ
			local chassis = vPart(m, "Chassis", Vector3.new(1.2, 1.6, 5.2), baseCF * CFrame.new(0, 1.8, 0.1), Color3.fromRGB(255, 0, 255))
			chassis.Transparency = 1
			chassis.CanCollide = true
			chassis.CanQuery = true
			chassis.PivotOffset = CFrame.new(0, -1.8, -0.1) -- pivot ของรถ = พื้นใต้รถ
			m.PrimaryPart = chassis
			-- ไฟหน้า (+SpotLight ส่องไปข้างหน้ากดลงพื้นเล็กน้อย)
			local hl = m:FindFirstChild("Headlight_Neon")
			if hl and hl:IsA("BasePart") then
				hl.Name = "Headlight"
				hl.Material = Enum.Material.Neon
				hl.Color = Color3.fromRGB(255, 236, 190)
				local sa = hl:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					sa:Destroy()
				end
				local att = Instance.new("Attachment")
				att.Name = "BeamAttachment"
				att.Parent = hl
				att.WorldCFrame = CFrame.lookAt(hl.Position, hl.Position + baseCF:VectorToWorldSpace(Vector3.new(0, -0.25, -1)))
				local spot = Instance.new("SpotLight")
				spot.Name = "HeadlightBeam"
				spot.Face = Enum.NormalId.Front
				spot.Angle = 50
				spot.Range = 40
				spot.Brightness = 3
				spot.Color = Color3.fromRGB(255, 232, 180)
				spot.Parent = att
			end
			local tl = m:FindFirstChild("Taillight_Neon")
			if tl and tl:IsA("BasePart") then
				tl.Name = "Taillight"
				tl.Material = Enum.Material.Neon
				tl.Color = Color3.fromRGB(200, 20, 20)
				local sa = tl:FindFirstChildOfClass("SurfaceAppearance")
				if sa then
					sa:Destroy()
				end
			end
			-- ป้ายทะเบียน: ชิ้น mesh เดิมเปลี่ยนชื่อเป็นกรอบป้าย แล้ววางป้ายที่มี SurfaceGui ทับด้านหลัง
			local plateMesh = m:FindFirstChild("LicensePlate")
			if plateMesh then
				plateMesh.Name = "LicensePlateFrame"
			end
			local plate = buildPlate(baseCF, Vector3.new(0, 1.62, 3.36))
			plate.Parent = m
			buildWheelHair(baseCF, Vector3.new(0, 1.03, 2.1), 0.8).Parent = m
			buildDriver(baseCF, HIP, GRIP_L, GRIP_R, FOOT_L, FOOT_R).Parent = m
			buildGhostPassenger(baseCF, HIP2, HIP + Vector3.new(0, 0.9, 0)).Parent = m
			m.Parent = folder
			m:SetAttribute("TemplateReady", true)
		end
	end
	print("🛵 [MapBuilder] เตรียมรถแม่แบบใน ServerStorage.VehicleTemplates แล้ว")
end

-- สร้างคนขับ/ผีซ้อนท้ายของรถแม่แบบใหม่ (หลังแก้สัดส่วน) โดยไม่แตะชิ้นอื่นของรถ
function MapBuilder.RebuildVehicleRiders()
	local folder = game:GetService("ServerStorage"):FindFirstChild("VehicleTemplates")
	if not folder then
		return
	end
	local HIP = Vector3.new(0, 2.78, 0.95)
	local HIP2 = Vector3.new(0, 2.78, 2.25)
	for _, m in ipairs(folder:GetChildren()) do
		if m:IsA("Model") and m:FindFirstChild("Chassis") then
			local baseCF = m:GetPivot()
			for _, n in ipairs({ "DriverNPC", "GhostPassenger" }) do
				local old = m:FindFirstChild(n)
				if old then
					old:Destroy()
				end
			end
			buildDriver(baseCF, HIP, Vector3.new(1.05, 3.6, -1.3), Vector3.new(-1.05, 3.6, -1.3), Vector3.new(0.82, 0.85, -0.05), Vector3.new(-0.82, 0.85, -0.05)).Parent = m
			buildGhostPassenger(baseCF, HIP2, HIP + Vector3.new(0, 0.9, 0)).Parent = m
		end
	end
end

-- จัดมุมปะยาง: ถังปั๊มลมอยู่หน้าสุดใกล้ถนน (เด่นสุด เผื่อ event กับเครื่อง) กองยางเก่าอยู่ด้านหลังและข้างๆ
-- ชื่อ AirCompressor / PressureGauge_Needle / ReliefValve คงเดิม
function MapBuilder.GroupCompressorTires()
	local env = Workspace:FindFirstChild("MapEnvironment")
	local yard = env and env:FindFirstChild("ImportedYardProps")
	local comp = Workspace:FindFirstChild("AirCompressor")
	if not yard or not comp then
		warn("[MapBuilder] GroupCompressorTires: ไม่พบ ImportedYardProps หรือ AirCompressor")
		return
	end
	-- วางให้ก้นวัตถุแตะพื้นที่ (x, z) และหมุนรอบแกนตั้งตาม yaw (องศา) ทับของเดิม
	local function setOnGround(inst: Instance, x: number, z: number, yaw: number, tilt: CFrame?)
		local list = { inst }
		local pivot = (inst :: any):GetPivot()
		local rotOnly = CFrame.Angles(0, math.rad(yaw), 0) * (tilt or CFrame.identity) * (pivot - pivot.Position)
		local placed = CFrame.new(Vector3.new(x, 0, z)) * rotOnly
		;(inst :: any):PivotTo(placed)
		local mn = boundsOf(list)
		local dy = groundY(x, z) - mn.Y
		;(inst :: any):PivotTo(placed + Vector3.new(0, dy, 0))
		return pivot
	end
	-- ถังปั๊มลม: หน้าสุด แกนยาวขนานถนน
	setOnGround(comp, 8, 1.6, 0)
	-- กองยาง 4 เส้น (ย้ายจากระเบียงมาไว้หลังถังลม)
	local shack = env:FindFirstChild("ShackStructure")
	local stack = shack and shack:FindFirstChild("ImportedShack") and shack.ImportedShack:FindFirstChild("TireStack_4")
	if stack then
		stack.Parent = yard
		setOnGround(stack, 11.6, 4.8, 15)
	end
	local leaning = yard:FindFirstChild("TireLeaning")
	if leaning then
		setOnGround(leaning, 13.6, 3.2, 70)
	end
	local rim = yard:FindFirstChild("TireWithRim")
	if rim then
		setOnGround(rim, 4.6, 4.8, 30)
	end
	-- ยางเส้นเปล่าอีกเส้นนอนพิงกองยาง
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	local tpl = store and store:FindFirstChild("TireStack") and store.TireStack:FindFirstChild("TireLeaning")
	if tpl and not yard:FindFirstChild("TireLoose") then
		local loose = tpl:Clone()
		loose.Name = "TireLoose"
		loose.Anchored = true
		loose.Parent = yard
		setOnGround(loose, 9.2, 5.8, 0, CFrame.Angles(math.rad(-75), 0, 0))
	end
	-- ของปะยางวางหน้าถังลม
	local bucket = yard:FindFirstChild("BucketWater")
	if bucket then
		setOnGround(bucket, 4.8, 1.2, 0)
	end
	local kit = yard:FindFirstChild("PatchKitTin")
	if kit then
		setOnGround(kit, 5.6, -0.4, 20)
	end
	print("🛞 [MapBuilder] จัดมุมถังปั๊มลม + กองยางแล้ว")
end

-- หรี่ของที่สีสว่างเกินจนดูเหมือนมีแสง: น้ำมันในตู้ปั๊ม และหลักกิโล (ย้อมสี texture ให้หม่น)
function MapBuilder.MuteBrightProps()
	local targets = {
		{ Workspace:FindFirstChild("InteractiveProps") and Workspace.InteractiveProps:FindFirstChild("GasPump"), "FuelLiquid", Color3.fromRGB(150, 118, 90) },
		{ Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("DirtRoad"), "KilometerMilestone", Color3.fromRGB(120, 116, 106) },
	}
	for _, t in ipairs(targets) do
		local part = t[1] and t[1]:FindFirstChild(t[2])
		local sa = part and part:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa.Color = t[3]
		end
	end
	-- เถียงนากลางทุ่ง: ผิวด้าน ไม่สะท้อน และหม่นลง
	local rice = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("RiceField")
	local hut = rice and rice:FindFirstChild("DistantRiceHut")
	if hut then
		for _, d in ipairs(hut:GetDescendants()) do
			if d:IsA("SurfaceAppearance") then
				d.MetalnessMap = ""
				d.RoughnessMap = ""
				d.Color = Color3.fromRGB(105, 100, 88)
			elseif d:IsA("BasePart") then
				d.Reflectance = 0
			end
		end
	end
end

-- ย้อมสีกระท่อมให้หลอน: สังกะสี/ไม้ เทาอมเขียวหม่นแบบขึ้นตะไคร่ ป้ายร้านเข้มกว่าอีกระดับ (รวม ShutterDoor)
local SHACK_TINT = Color3.fromRGB(92, 96, 84)
local SHACK_SIGN_TINT = Color3.fromRGB(70, 70, 62)
function MapBuilder.TintShackHaunted()
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure")
	local imported = shack and shack:FindFirstChild("ImportedShack")
	local targets = { imported, Workspace:FindFirstChild("InteractiveProps") and Workspace.InteractiveProps:FindFirstChild("ShutterDoor") }
	for _, t in ipairs(targets) do
		if t then
			for _, d in ipairs(t:GetDescendants()) do
				if d:IsA("SurfaceAppearance") then
					d.Color = if d.Parent and d.Parent.Name == "MainSignBoard" then SHACK_SIGN_TINT else SHACK_TINT
				end
			end
		end
	end
end

-- ===================================================================================
-- ใบต้นไทร: แผ่นใบไขว้ (leaf card) 4 แผ่นต่อกลุ่ม ติดภาพกลุ่มใบไทรพื้นหลังโปร่งใส ตามจุดจาก assets/models/SacredBanyanTree_LeafAnchors.json
-- (x, y, z, radius) เป็น studs เทียบกับ pivot ของต้นไทร (โคนลำต้น) ตามแกน Roblox
-- ===================================================================================
local BANYAN_LEAF_IMAGE = "rbxassetid://71802157290225" -- SacredBanyanTree_LeafCard.png
local BANYAN_LEAF_TINT = Color3.fromRGB(150, 165, 140) -- หม่นลงให้เข้ากับฉากกลางคืน
local BANYAN_LEAF_ANCHORS = {
	{ -1.95, 33.26, 0.0, 3.39 },
	{ 2.42, 33.02, 2.21, 3.1 },
	{ -0.36, 32.57, -4.08, 3.36 },
	{ -2.92, 33.02, 3.81, 3.11 },
	{ 5.02, 33.05, -0.89, 3.57 },
	{ -5.04, 32.51, -3.2, 2.88 },
	{ 1.61, 33.26, 5.98, 3.5 },
	{ 3.01, 32.46, -5.8, 3.4 },
	{ -7.04, 32.67, 2.57, 2.68 },
	{ 7.42, 32.45, 3.06, 2.79 },
	{ -3.42, 31.78, -7.32, 3.11 },
	{ -2.62, 32.72, 8.35, 3.51 },
	{ 7.89, 32.31, -4.57, 2.95 },
	{ -9.62, 31.54, -2.12, 2.68 },
	{ 6.12, 32.44, 8.71, 2.61 },
	{ 1.32, 31.3, -10.19, 3.57 },
	{ -8.22, 31.98, 6.93, 3.42 },
	{ 10.68, 32.27, 0.44, 3.17 },
	{ -7.66, 31.59, -7.62, 2.97 },
	{ 0.56, 30.9, 12.02, 3.38 },
	{ 7.71, 31.39, -9.23, 3.54 },
	{ -11.9, 32.19, 1.6, 2.9 },
	{ 10.4, 31.62, 7.23, 3.34 },
	{ -2.94, 31.52, -13.09, 2.72 },
	{ -6.7, 31.06, 11.69, 3.29 },
	{ 11.97, 31.93, -3.82, 2.74 },
	{ -12.68, 30.79, -5.86, 3.18 },
	{ 5.39, 30.01, 12.87, 3.36 },
	{ 5.02, 30.03, -13.95, 3.36 },
	{ -12.38, 30.14, 6.5, 2.79 },
	{ 14.47, 30.05, 3.81, 2.68 },
	{ -8.12, 30.57, -12.64, 3.38 },
	{ -2.6, 30.38, 15.09, 2.68 },
	{ 11.24, 30.0, -8.7, 3.14 },
	{ -14.27, 30.24, -1.18, 2.98 },
	{ 10.3, 30.32, 11.14, 3.35 },
	{ -0.07, 29.89, -15.64, 3.17 },
	{ -10.24, 30.01, 11.28, 2.74 },
	{ 15.07, 30.12, -1.4, 3.38 },
	{ -13.44, 29.16, -10.2, 3.4 },
	{ 3.01, 29.42, 16.57, 3.3 },
	{ 9.31, 27.86, -14.8, 2.81 },
	{ -16.71, 28.68, 4.58, 2.66 },
	{ 15.04, 29.38, 7.72, 3.08 },
	{ -5.8, 28.33, -15.66, 2.9 },
	{ -6.82, 27.04, 16.73, 3.55 },
	{ -17.08, 25.47, 0.68, 2.71 },
	{ -14.28, 24.53, 8.65, 2.42 },
	{ -9.91, 24.65, 14.75, 2.76 },
	{ -0.77, 24.47, 15.99, 2.6 },
	{ 9.49, 24.87, 13.12, 2.84 },
	{ 13.61, 24.46, 7.87, 2.53 },
	{ 17.64, 24.07, -1.36, 2.7 },
	{ 15.22, 24.33, -7.72, 2.6 },
	{ 9.77, 24.72, -14.77, 2.85 },
	{ -1.09, 24.86, -16.72, 2.76 },
	{ -6.81, 24.77, -15.26, 2.69 },
	{ -12.77, 24.58, -8.87, 2.5 }
}

local function leafCard(cf: CFrame, size: Vector3, horizontal: boolean, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "LeafCard"
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for _, face in ipairs(if horizontal then { Enum.NormalId.Top, Enum.NormalId.Bottom } else { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local d = Instance.new("Decal")
		d.Texture = BANYAN_LEAF_IMAGE
		d.Face = face
		d.Color3 = BANYAN_LEAF_TINT
		d.Parent = p
	end
	p.Parent = parent
end

function MapBuilder.AddBanyanLeaves()
	local zone = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("SacredBanyanZone")
	local tree = zone and zone:FindFirstChild("SacredBanyanTree")
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	local tplTree = store and store:FindFirstChild("SacredBanyanTree")
	if not tree or not tplTree then
		warn("[MapBuilder] AddBanyanLeaves: ไม่พบ SacredBanyanTree ในฉาก หรือต้นแบบใน ServerStorage.ImportedProps")
		return
	end
	if tree:FindFirstChild("BanyanLeaves") then
		warn("[MapBuilder] AddBanyanLeaves: มีใบอยู่แล้ว (ลบ SacredBanyanTree.BanyanLeaves ถ้าต้องการสร้างใหม่)")
		return
	end
	-- pivot ของต้นไทรในฉาก = ตำแหน่งลำต้นในฉาก - ตำแหน่งลำต้นในต้นแบบ (ต้นแบบมี pivot ที่จุด 0,0,0)
	local origin = tree.BanyanTrunk.Position - tplTree.BanyanTrunk.Position + tplTree:GetPivot().Position
	local leaves = Instance.new("Model")
	leaves.Name = "BanyanLeaves"
	leaves.Parent = tree
	local rng = Random.new(77)
	local function clump(c: Vector3, r: number)
		local yaw0 = rng:NextNumber(0, 180)
		for k = 0, 2 do
			local cf = CFrame.new(c) * CFrame.Angles(0, math.rad(yaw0 + k * 60), 0) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, 0)
			leafCard(cf, Vector3.new(2.3 * r, 1.6 * r, 0.05), false, leaves)
		end
		local top = CFrame.new(c + Vector3.new(0, r * 0.25, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-10, 10)))
		leafCard(top, Vector3.new(2.2 * r, 0.05, 2.2 * r), true, leaves)
	end
	local count = 0
	for _, a in ipairs(BANYAN_LEAF_ANCHORS) do
		local c = origin + Vector3.new(a[1], a[2], a[3])
		local r = a[4]
		clump(c, r)
		count += 1
		-- พุ่มย่อย 2 พุ่มรอบจุดหลัก เยื้องออกด้านข้างและห้อยต่ำลงมา ให้ทรงพุ่มหนาและแผ่กว้างขึ้น
		local outward = Vector3.new(a[1], 0, a[3])
		outward = if outward.Magnitude > 0.1 then outward.Unit else Vector3.new(1, 0, 0)
		for _ = 1, 2 do
			local side = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * r * 0.9
			local off = outward * r * rng:NextNumber(0.3, 1.1) + side + Vector3.new(0, -r * rng:NextNumber(0.3, 0.9), 0)
			clump(c + off, r * rng:NextNumber(0.65, 0.85))
			count += 1
		end
	end
	print("🌳 [MapBuilder] เพิ่มใบต้นไทร " .. count .. " พุ่มแล้ว")
end

-- สร้างใบต้นไทรใหม่ (ลบชุดใบที่สร้างไว้ก่อน ซึ่งเป็นของที่ฟังก์ชันนี้สร้างเอง)
function MapBuilder.RebuildBanyanLeaves()
	local zone = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("SacredBanyanZone")
	local tree = zone and zone:FindFirstChild("SacredBanyanTree")
	local old = tree and tree:FindFirstChild("BanyanLeaves")
	if old then
		old:Destroy()
	end
	MapBuilder.AddBanyanLeaves()
end

-- ===================================================================================
-- ใบมะม่วง: แผ่นใบไขว้ ตามจุดใน assets/models/MangoTree_LeafAnchors.json (studs เทียบ pivot ที่โคนต้น)
-- ใช้: MapBuilder.AddMangoLeaves(<Model ต้นมะม่วงที่วางในฉาก>)
-- ===================================================================================
local MANGO_LEAF_IMAGE = "rbxassetid://126910157062464" -- MangoTree_LeafCard.png
local MANGO_LEAF_TINT = Color3.fromRGB(150, 170, 140)
local MANGO_LEAF_ANCHORS = {
	{ -0.99, 20.22, 0.0, 2.85 },
	{ 1.18, 21.22, 1.08, 2.64 },
	{ -0.19, 20.12, -2.12, 2.85 },
	{ -1.57, 20.19, 2.05, 3.15 },
	{ 2.85, 20.75, -0.5, 2.49 },
	{ -2.57, 20.17, -1.64, 2.8 },
	{ 0.9, 21.15, 3.36, 2.92 },
	{ 1.6, 20.2, -3.08, 3.13 },
	{ -3.35, 20.4, 1.22, 2.49 },
	{ 4.06, 21.06, 1.67, 2.52 },
	{ -1.94, 20.21, -4.14, 2.41 },
	{ -1.34, 19.86, 4.27, 2.55 },
	{ 4.22, 20.7, -2.45, 2.8 },
	{ -4.68, 21.15, -1.03, 2.75 },
	{ 2.92, 20.04, 4.15, 2.89 },
	{ 0.64, 20.11, -4.9, 2.66 },
	{ -4.39, 20.73, 3.7, 3.1 },
	{ 5.17, 20.11, 0.21, 2.72 },
	{ -4.02, 19.7, -4.0, 3.12 },
	{ 0.25, 19.45, 5.38, 2.99 },
	{ 3.6, 19.7, -4.31, 3.13 },
	{ -5.97, 19.2, 0.8, 2.55 },
	{ 5.13, 20.25, 3.57, 3.14 },
	{ -1.37, 20.24, -6.08, 3.3 },
	{ -3.22, 19.74, 5.62, 3.03 },
	{ 6.05, 19.18, -1.93, 3.02 },
	{ -6.19, 18.97, -2.86, 3.19 },
	{ 2.51, 18.83, 6.0, 2.87 },
	{ 2.51, 18.86, -6.97, 3.27 },
	{ -6.65, 19.58, 3.5, 2.53 },
	{ 6.97, 19.73, 1.84, 2.61 },
	{ -4.06, 19.12, -6.31, 2.76 },
	{ -1.34, 19.52, 7.77, 2.8 },
	{ 6.01, 18.86, -4.66, 3.18 },
	{ -7.88, 19.77, -0.65, 2.94 },
	{ 5.24, 19.13, 5.67, 2.91 },
	{ -0.04, 18.5, -7.65, 2.73 },
	{ -5.34, 18.76, 5.89, 2.45 },
	{ 7.96, 17.92, -0.74, 2.51 },
	{ -6.52, 18.19, -4.95, 2.83 },
	{ 1.54, 17.75, 8.47, 3.16 },
	{ 4.5, 18.77, -7.15, 2.41 },
	{ -8.67, 18.71, 2.38, 2.82 },
	{ 7.31, 18.22, 3.75, 2.81 },
	{ -2.88, 18.45, -7.78, 2.48 },
	{ -3.29, 18.66, 8.09, 3.08 },
	{ 8.31, 18.4, -3.94, 2.7 },
	{ -8.66, 17.4, -2.67, 2.71 },
	{ 4.86, 18.25, 8.3, 2.51 },
	{ 2.05, 17.59, -9.54, 2.44 },
	{ -7.31, 18.22, 5.19, 2.48 },
	{ 9.26, 16.87, 1.16, 2.47 },
	{ -6.08, 18.03, -7.15, 2.54 },
	{ -0.38, 16.98, 10.4, 2.58 },
	{ 6.81, 18.17, -6.91, 2.83 },
	{ -9.35, 17.74, 0.48, 2.53 },
	{ 8.14, 16.36, 6.73, 2.98 },
	{ -1.33, 18.31, -9.52, 2.62 },
	{ -5.76, 17.8, 8.36, 2.57 },
	{ 10.67, 16.16, -2.45, 2.57 },
	{ -9.43, 16.35, -5.35, 2.9 },
	{ 3.22, 16.54, 9.93, 2.44 },
	{ 4.49, 16.33, -9.83, 3.17 },
	{ -10.47, 15.19, 4.44, 3.17 },
	{ 10.78, 15.42, 3.82, 2.66 },
	{ -5.37, 14.13, -10.11, 2.59 },
	{ -2.58, 16.05, 9.98, 2.47 },
	{ 8.68, 17.25, -5.64, 2.65 },
	{ -10.75, 16.52, -1.8, 2.58 },
	{ 7.35, 13.12, 9.4, 2.82 },
	{ -11.74, 13.3, -0.48, 2.59 },
	{ -10.67, 12.94, 3.53, 2.93 },
	{ -8.29, 13.5, 7.15, 2.69 },
	{ -3.48, 13.42, 11.21, 2.26 },
	{ 0.93, 12.98, 10.76, 2.45 },
	{ 2.99, 12.75, 9.78, 2.4 },
	{ 7.53, 12.83, 6.72, 2.67 },
	{ 10.13, 12.51, 5.1, 2.57 },
	{ 9.92, 13.35, 0.67, 2.63 },
	{ 9.68, 12.98, -3.98, 2.27 },
	{ 8.31, 13.39, -6.87, 2.41 },
	{ 4.12, 13.01, -10.0, 2.38 },
	{ -0.12, 13.07, -10.5, 2.83 },
	{ -4.56, 13.51, -10.4, 2.68 },
	{ -7.62, 13.16, -8.62, 2.86 },
	{ -9.85, 13.26, -5.09, 2.87 }
}

function MapBuilder.AddMangoLeaves(tree: Model, light: boolean?, far: boolean?)
	if not tree or tree:FindFirstChild("MangoLeaves") then
		return
	end
	local store = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	local tpl = store and store:FindFirstChild("MangoTree")
	local trunk = tree:FindFirstChild("MangoTrunk") :: BasePart
	local origin = if tpl and trunk then trunk.Position - tpl.MangoTrunk.Position + tpl:GetPivot().Position else tree:GetPivot().Position
	local leaves = Instance.new("Model")
	leaves.Name = "MangoLeaves"
	leaves.Parent = tree
	local rng = Random.new(88)
	local function card(cf: CFrame, size: Vector3, horizontal: boolean)
		local p = Instance.new("Part")
		p.Name = "LeafCard"
		p.Size = size
		p.CFrame = cf
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		for _, face in ipairs(if horizontal then { Enum.NormalId.Top, Enum.NormalId.Bottom } else { Enum.NormalId.Front, Enum.NormalId.Back }) do
			local d = Instance.new("Decal")
			d.Texture = MANGO_LEAF_IMAGE
			d.Face = face
			d.Color3 = MANGO_LEAF_TINT
			d.Parent = p
		end
		p.Parent = leaves
	end
	for idx, a in ipairs(MANGO_LEAF_ANCHORS) do
		if far and idx % 3 ~= 0 then
			continue
		end
		local c = origin + Vector3.new(a[1], a[2], a[3])
		local r = a[4] * (if far then 1.7 else 1)
		for n = 1, if light then 1 else 2 do
			local cc = if n == 1 then c else c + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.8, 0), rng:NextNumber(-1, 1)) * r * 0.7
			local rr = if n == 1 then r else r * 0.8
			local yaw0 = rng:NextNumber(0, 180)
			for k = 0, 2 do
				card(CFrame.new(cc) * CFrame.Angles(0, math.rad(yaw0 + k * 60), 0) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, 0), Vector3.new(2.3 * rr, 1.7 * rr, 0.05), false)
			end
			card(CFrame.new(cc + Vector3.new(0, rr * 0.3, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), math.rad(rng:NextNumber(0, 360)), 0), Vector3.new(2.3 * rr, 0.05, 2.3 * rr), true)
		end
	end
end

-- ===================================================================================
-- วัดไทยชนบทครบชุด (สำหรับฉาก Lobby) — โมเดลจาก tools/blender/thai_temple.py
-- นำเข้า FBX 8 ไฟล์ (TempleGate, TempleFence, BoneStupa, Meru, Ubosot, Kuti, Sala, BuddhaTrio) ด้วย 3D Importer
-- แล้วรัน: require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildTempleLobby()
-- ต้นแบบถูกย้ายไป ServerStorage.ImportedProps.ThaiTemple, วัดวางที่ Workspace.TempleLobby (ไม่แตะแมพเดิม)
-- mesh ทุกชิ้นปิด collision แล้วใช้กล่องชนล่องหน (Colliders) แทน เพื่อให้เดินผ่านประตู/ขึ้นบันไดได้จริง
-- ตาราง TEMPLE_UNITS สร้างจาก tools/blender/temple_units_to_luau.py (อย่าแก้มือ ให้รันสคริปต์ใหม่)
-- ===================================================================================
local TEMPLE_UNITS = {
	TempleGate = {
		file = "TempleGate",
		parts = { "TempleGate", "TempleGate_Buddha" },
		bmin = Vector3.new(-12.86, 0, -3.73),
		bmax = Vector3.new(12.86, 34.32, 3.73),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ -8.25, 8.55, 0, 3.2, 17.1, 3.2 }, { 8.25, 8.55, 0, 3.2, 17.1, 3.2 },
		},
	},
	TempleNameSign = {
		file = "TempleGate",
		parts = { "TempleNameSign", "TempleNameSign_Plaque" },
		bmin = Vector3.new(-7.95, 0, -0.85),
		bmax = Vector3.new(7.95, 7.6, 0.85),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 2.5, 0, 15, 5, 1.6 },
		},
	},
	FenceSegment = {
		file = "TempleFence",
		parts = { "FenceSegment" },
		bmin = Vector3.new(0.75, 0, -0.95),
		bmax = Vector3.new(12.95, 7.3, 0.95),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 6, 2.2, 0, 10.4, 4.4, 1.2 }, { 12, 2.7, 0, 1.7, 5.4, 1.7 },
		},
	},
	FenceSegment_Half = {
		file = "TempleFence",
		parts = { "FenceSegment_Half" },
		bmin = Vector3.new(0.75, 0, -0.95),
		bmax = Vector3.new(6.95, 7.3, 0.95),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 3, 2.2, 0, 4.4, 4.4, 1.2 }, { 6, 2.7, 0, 1.7, 5.4, 1.7 },
		},
	},
	FencePost = {
		file = "TempleFence",
		parts = { "FencePost" },
		bmin = Vector3.new(-0.95, 0, -0.95),
		bmax = Vector3.new(0.95, 7.3, 0.95),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 2.7, 0, 1.7, 5.4, 1.7 },
		},
	},
	BoneStupa_A = {
		file = "BoneStupa",
		parts = { "BoneStupa_A" },
		bmin = Vector3.new(-2.34, 0, -2.34),
		bmax = Vector3.new(2.34, 13.8, 2.34),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 3, 0, 4.6, 6, 4.6 },
		},
	},
	BoneStupa_B = {
		file = "BoneStupa",
		parts = { "BoneStupa_B" },
		bmin = Vector3.new(-2.04, 0, -2.04),
		bmax = Vector3.new(2.04, 10, 2.04),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 2.5, 0, 4, 5, 4 },
		},
	},
	BoneStupa_C = {
		file = "BoneStupa",
		parts = { "BoneStupa_C" },
		bmin = Vector3.new(-1.7, 0, -1.7),
		bmax = Vector3.new(1.7, 9.94, 1.7),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 2.15, 0, 3.32, 4.3, 3.32 },
		},
	},
	Meru = {
		file = "Meru",
		parts = { "Meru_Base", "Meru_Hall", "Meru_Roof", "Meru_Chimney" },
		bmin = Vector3.new(-14.84, 0, -14.14),
		bmax = Vector3.new(14.84, 56.35, 18.52),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 2.59, 0, 25.99, 5.17, 21.39 }, { 0, 2.26, 10.93, 9.2, 4.53, 1.15 }, { 0, 1.94, 12.07, 9.2, 3.88, 1.15 },
			{ 0, 1.62, 13.22, 9.2, 3.23, 1.15 }, { 0, 1.29, 14.38, 9.2, 2.59, 1.15 }, { 0, 0.97, 15.52, 9.2, 1.94, 1.15 },
			{ 0, 0.65, 16.67, 9.2, 1.29, 1.15 }, { 0, 0.32, 17.82, 9.2, 0.65, 1.15 }, { -11.04, 11.5, 8.74, 1.27, 12.65, 1.27 },
			{ -11.04, 11.5, -8.74, 1.27, 12.65, 1.27 }, { -5.29, 11.5, 8.74, 1.26, 12.65, 1.27 }, { -5.29, 11.5, -8.74, 1.26, 12.65, 1.27 },
			{ 5.29, 11.5, 8.74, 1.26, 12.65, 1.27 }, { 5.29, 11.5, -8.74, 1.26, 12.65, 1.27 }, { 11.04, 11.5, 8.74, 1.27, 12.65, 1.27 },
			{ 11.04, 11.5, -8.74, 1.27, 12.65, 1.27 }, { -11.04, 6.5, 0, 0.92, 2.64, 17.48 }, { 11.04, 6.5, 0, 0.92, 2.64, 17.48 },
			{ 0, 8.86, -3.1, 8.74, 7.36, 9.2 }, { 0, 19.84, -7.59, 5.29, 29.32, 5.29 },
		},
	},
	Ubosot = {
		file = "Ubosot",
		parts = { "Ubosot_Base", "Ubosot_Walls", "Ubosot_Columns", "Ubosot_Roof", "Ubosot_KaewWall" },
		bmin = Vector3.new(-24.7, 0, -31.85),
		bmax = Vector3.new(24.7, 34.91, 41.34),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 1.43, 2.93, 32.5, 2.86, 51.35 }, { 0, 1.07, 29.15, 10.4, 2.15, 1.11 }, { 0, 0.72, 30.26, 10.4, 1.43, 1.1 },
			{ 0, 0.36, 31.36, 10.4, 0.72, 1.11 }, { -7.54, 10.66, 16.25, 5.72, 15.6, 1.3 }, { 7.54, 10.66, 16.25, 5.72, 15.6, 1.3 },
			{ 0, 16.38, 16.25, 9.36, 4.16, 1.3 }, { 0, 10.66, -18.85, 20.8, 15.6, 1.3 }, { -9.75, 10.66, -1.3, 1.3, 15.6, 33.8 },
			{ 9.75, 10.66, -1.3, 1.3, 15.6, 33.8 }, { -10.4, 9.88, 25.74, 1.56, 14.04, 1.56 }, { -5.98, 9.88, 25.74, 1.56, 14.04, 1.56 },
			{ 5.98, 9.88, 25.74, 1.56, 14.04, 1.56 }, { 10.4, 9.88, 25.74, 1.56, 14.04, 1.56 }, { -13.78, 9.1, 13, 1.3, 12.48, 1.3 },
			{ -13.78, 9.1, 3.25, 1.3, 12.48, 1.3 }, { -13.78, 9.1, -6.5, 1.3, 12.48, 1.3 }, { -13.78, 9.1, -16.25, 1.3, 12.48, 1.3 },
			{ 13.78, 9.1, 13, 1.3, 12.48, 1.3 }, { 13.78, 9.1, 3.25, 1.3, 12.48, 1.3 }, { 13.78, 9.1, -6.5, 1.3, 12.48, 1.3 },
			{ 13.78, 9.1, -16.25, 1.3, 12.48, 1.3 }, { -13, 1.69, 35.75, 15.34, 3.38, 1.04 }, { 13, 1.69, 35.75, 15.34, 3.38, 1.04 },
			{ 0, 1.69, -27.3, 41.34, 3.38, 1.04 }, { -20.15, 1.69, 4.22, 1.04, 3.38, 64.09 }, { 20.15, 1.69, 4.22, 1.04, 3.38, 64.09 },
		},
	},
	Kuti = {
		file = "Kuti",
		parts = { "Kuti_Stilts", "Kuti_House", "Kuti_Roof" },
		bmin = Vector3.new(-14.74, -0.31, -10.57),
		bmax = Vector3.new(14.74, 35.06, 31.76),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ -11.4, 11.1, 12.6, 1.35, 22.2, 1.35 }, { -11.4, 4.5, 4.5, 1.35, 9, 1.35 }, { -11.4, 4.5, -2.25, 1.35, 9, 1.35 },
			{ -11.4, 4.5, -8.7, 1.35, 9, 1.35 }, { -3.75, 4.5, 12.6, 1.35, 9, 1.35 }, { -3.75, 4.5, 4.5, 1.35, 9, 1.35 },
			{ -3.75, 4.5, -2.25, 1.35, 9, 1.35 }, { -3.75, 4.5, -8.7, 1.35, 9, 1.35 }, { 3.75, 4.5, 12.6, 1.35, 9, 1.35 },
			{ 3.75, 4.5, 4.5, 1.35, 9, 1.35 }, { 3.75, 4.5, -2.25, 1.35, 9, 1.35 }, { 3.75, 4.5, -8.7, 1.35, 9, 1.35 },
			{ 11.4, 11.1, 12.6, 1.35, 22.2, 1.35 }, { 11.4, 4.5, 4.5, 1.35, 9, 1.35 }, { 11.4, 4.5, -2.25, 1.35, 9, 1.35 },
			{ 11.4, 4.5, -8.7, 1.35, 9, 1.35 }, { 0, 9.6, 1.95, 24.9, 1.2, 23.1 }, { 7.35, 5.1, 14.25, 7.8, 10.2, 1.5 },
			{ 7.35, 4.67, 15.75, 7.8, 9.35, 1.5 }, { 7.35, 4.25, 17.25, 7.8, 8.5, 1.5 }, { 7.35, 3.82, 18.75, 7.8, 7.65, 1.5 },
			{ 7.35, 3.4, 20.25, 7.8, 6.8, 1.5 }, { 7.35, 2.98, 21.75, 7.8, 5.95, 1.5 }, { 7.35, 2.55, 23.25, 7.8, 5.1, 1.5 },
			{ 7.35, 2.12, 24.75, 7.8, 4.25, 1.5 }, { 7.35, 1.7, 26.25, 7.8, 3.4, 1.5 }, { 7.35, 1.28, 27.75, 7.8, 2.55, 1.5 },
			{ 7.35, 0.85, 29.25, 7.8, 1.7, 1.5 }, { 7.35, 0.42, 30.75, 7.8, 0.85, 1.5 }, { -8.03, 16.2, 4.5, 7.95, 12, 0.6 },
			{ 8.03, 16.2, 4.5, 7.95, 12, 0.6 }, { 0, 21.45, 4.5, 8.1, 1.5, 0.6 }, { 0, 16.2, -8.7, 24, 12, 0.6 },
			{ -11.7, 16.2, -2.1, 0.6, 12, 12.6 }, { 11.7, 16.2, -2.1, 0.6, 12, 12.6 }, { -4.5, 12.3, 13.27, 15.3, 4.2, 0.45 },
			{ -12, 12.3, 9.08, 0.45, 4.2, 8.55 }, { 12, 12.3, 9.08, 0.45, 4.2, 8.55 },
		},
	},
	Sala = {
		file = "Sala",
		parts = { "Sala_Base", "Sala_Columns", "Sala_Roof" },
		bmin = Vector3.new(-24.86, 0, -18.12),
		bmax = Vector3.new(24.86, 27.2, 19.32),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 0.92, 0, 46, 1.84, 34.5 }, { 0, 0.61, 17.77, 16.1, 1.23, 1.04 }, { 0, 0.31, 18.8, 16.1, 0.61, 1.04 },
			{ 0, 2.42, -10.81, 20.7, 1.15, 7.36 }, { -20.7, 8.62, 14.95, 1.73, 13.57, 1.72 }, { -20.7, 8.62, -14.95, 1.73, 13.57, 1.72 },
			{ -10.35, 8.62, 14.95, 1.72, 13.57, 1.72 }, { -10.35, 8.62, -14.95, 1.72, 13.57, 1.72 }, { 0, 8.62, 14.95, 1.72, 13.57, 1.72 },
			{ 0, 8.62, -14.95, 1.72, 13.57, 1.72 }, { 10.35, 8.62, 14.95, 1.72, 13.57, 1.72 }, { 10.35, 8.62, -14.95, 1.72, 13.57, 1.72 },
			{ 20.7, 8.62, 14.95, 1.73, 13.57, 1.72 }, { 20.7, 8.62, -14.95, 1.73, 13.57, 1.72 }, { -20.7, 8.62, 4.94, 1.73, 13.57, 1.72 },
			{ -20.7, 8.62, -4.94, 1.73, 13.57, 1.72 }, { 20.7, 8.62, 4.94, 1.73, 13.57, 1.72 }, { 20.7, 8.62, -4.94, 1.73, 13.57, 1.72 },
			{ -13.8, 9.83, 5.17, 1.73, 15.98, 1.72 }, { -13.8, 9.83, -5.17, 1.73, 15.98, 1.72 }, { 13.8, 9.83, 5.17, 1.73, 15.98, 1.72 },
			{ 13.8, 9.83, -5.17, 1.73, 15.98, 1.72 },
		},
	},
	BuddhaTrio = {
		file = "BuddhaTrio",
		parts = { "BuddhaTrio_Base", "BuddhaTrio_Plaques", "Buddha_Center", "Buddha_Left", "Buddha_Right" },
		bmin = Vector3.new(-6.4, 0, -2.1),
		bmax = Vector3.new(6.4, 8.23, 2.12),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 1.55, 0, 12.8, 3.1, 4.2 },
		},
	},
	DonationBoard = {
		file = "DonationBoard",
		parts = { "DonationBoard", "DonationBoard_Board", "DonationBoard_Face" },
		bmin = Vector3.new(-15.6, 0, -1),
		bmax = Vector3.new(15.6, 26.3, 1),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ -13.6, 13.15, 0, 2, 26.3, 2 }, { 13.6, 13.15, 0, 2, 26.3, 2 },
		},
	},
	DonationBox = {
		file = "DonationBox",
		parts = { "DonationBox_Stand", "DonationBox", "DonationBox_Door", "DonationBox_Glass" },
		bmin = Vector3.new(-1.7, 0, -1.4),
		bmax = Vector3.new(1.7, 7.78, 1.4),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 1.68, 0, 3.4, 3.35, 2.8 }, { 0, 5.55, 0, 3, 4.4, 2.4 },
		},
	},
	ShopCart = {
		file = "ShopCart",
		parts = { "ShopCart", "ShopCart_Goods", "ShopCart_Canopy", "ShopCart_Sign" },
		bmin = Vector3.new(-7.5, 0, -3.3),
		bmax = Vector3.new(8.1, 13.2, 3.9),
		-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z
		cols = {
			{ 0, 4.9, 0, 12.6, 9.8, 5.2 },
		},
	},
}

local TEMPLE_FILES = { "TempleGate", "TempleFence", "BoneStupa", "Meru", "Ubosot", "Kuti", "Sala", "BuddhaTrio", "DonationBoard", "DonationBox", "ShopCart" }
local TEMPLE_GOLD_TEXT = Color3.fromRGB(214, 172, 92)

local function templeStore(): Folder
	local ss = game:GetService("ServerStorage")
	local root = ss:FindFirstChild("ImportedProps") or Instance.new("Folder")
	root.Name = "ImportedProps"
	root.Parent = ss
	local store = root:FindFirstChild("ThaiTemple") or Instance.new("Folder")
	store.Name = "ThaiTemple"
	store.Parent = root
	for _, name in ipairs(TEMPLE_FILES) do
		if not store:FindFirstChild(name) then
			for _, where in ipairs({ Workspace, Workspace:FindFirstChild("NewModels") }) do
				local m = where and where:FindFirstChild(name)
				if m and m:IsA("Model") then
					m.Parent = store
					break
				end
			end
		end
	end
	-- importer ใส่ SurfaceAppearance ว่างซ้อน: ลบอันที่ไม่มี ColorMap (เหมือน moveTemplatesToStorage)
	for _, p in ipairs(store:GetDescendants()) do
		if p:IsA("MeshPart") then
			local sas = {}
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("SurfaceAppearance") then
					table.insert(sas, c)
				end
			end
			if #sas > 1 then
				for _, sa in ipairs(sas) do
					if sa.ColorMap == "" then
						sa:Destroy()
					end
				end
			end
		end
	end
	return store :: Folder
end

-- กรอบ (min, max) ของชิ้นส่วนหลังแปลงด้วย rel[p] (CFrame ของแต่ละชิ้นในกรอบอ้างอิงใหม่)
local function boundsOfRel(parts: { BasePart }, rel: { [BasePart]: CFrame }): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in ipairs(parts) do
		local h = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local w = rel[p] * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
					mn = mn:Min(w)
					mx = mx:Max(w)
				end
			end
		end
	end
	return mn, mx
end

-- ทิศที่ 3D Importer หมุนโมเดลมา (เช่นตั้ง World Forward ต่างจากตอน export) ทุกไฟล์ในชุดวัดนำเข้าด้วยค่าเดียวกัน
-- จึงวัดจากโบสถ์ (กรอบไม่สมมาตรหน้า-หลัง) ครั้งเดียว: ลองหมุน 0/90/180/270° หาอันที่กรอบตรงกับตอนปั้นที่สุด
-- ต้องนำเข้าแบบ "Set Pivot to Scene Origin" (pivot ของโมเดล = จุดกำเนิดของฉากใน Blender)
local templeImportFix: CFrame? = nil
local function getTempleImportFix(store: Folder): CFrame
	if templeImportFix then
		return templeImportFix
	end
	local u = TEMPLE_UNITS.Ubosot
	local tpl = store:FindFirstChild(u.file)
	if not tpl then
		return CFrame.identity
	end
	local parts, rel = {}, {}
	local pv = tpl:GetPivot()
	for _, n in ipairs(u.parts) do
		local p = tpl:FindFirstChild(n, true)
		if p and p:IsA("BasePart") then
			table.insert(parts, p)
			rel[p] = pv:ToObjectSpace(p.CFrame)
		end
	end
	local mn, mx = boundsOfRel(parts, rel)
	local s = (mx - mn).Magnitude / (u.bmax - u.bmin).Magnitude
	local best, bestScore = 0, math.huge
	for _, deg in ipairs({ 0, 90, 180, 270 }) do
		local r = CFrame.Angles(0, math.rad(deg), 0)
		local a, b = r * (u.bmin * s), r * (u.bmax * s)
		local score = (mn - a:Min(b)).Magnitude + (mx - a:Max(b)).Magnitude
		if score < bestScore then
			best, bestScore = deg, score
		end
	end
	if bestScore > 2 * s then
		warn(("[MapBuilder] วัดทิศโมเดลวัดไม่ได้ (คลาด %.1f studs) ใช้ทิศเดิม — นำเข้าแบบ Set Pivot to Scene Origin หรือยัง?"):format(bestScore))
		best = 0
	end
	print(("🧭 [MapBuilder] โมเดลวัดถูกหมุนตอนนำเข้า %d° (คลาด %.2f studs) หมุนกลับให้อัตโนมัติ"):format(best, bestScore))
	templeImportFix = CFrame.Angles(0, -math.rad(best), 0)
	return templeImportFix :: CFrame
end

-- วาง prop 1 ชุด: cf = ตำแหน่ง/ทิศของฐานกลาง prop (หน้า prop หันไป +Z ของ cf), scale = ขยาย (ค่าเริ่มต้น 1)
local function placeTempleUnit(store: Folder, unitName: string, cf: CFrame, parent: Instance, scale: number?): Model
	local u = TEMPLE_UNITS[unitName]
	local tpl = store:FindFirstChild(u.file)
	assert(tpl, "ไม่พบโมเดลนำเข้า " .. u.file .. " (นำเข้า " .. u.file .. ".fbx ก่อน)")
	local fix = getTempleImportFix(store)
	local pv = tpl:GetPivot()
	local parts, rel = {}, {}
	for _, n in ipairs(u.parts) do
		local p = tpl:FindFirstChild(n, true)
		assert(p and p:IsA("BasePart"), "ไม่พบชิ้น " .. u.file .. "." .. n)
		table.insert(parts, p)
		-- ตำแหน่งเทียบ pivot ของไฟล์ แล้วหมุนกลับทิศที่ Importer หมุนมา
		rel[p] = fix * pv:ToObjectSpace(p.CFrame)
	end
	local mn, mx = boundsOfRel(parts, rel)
	-- ตรวจหน่วยตอนนำเข้า: ถ้าขนาดไม่ตรงกับตอนปั้น ให้ย่อ/ขยายกลับ
	local s = (mx - mn).Magnitude / (u.bmax - u.bmin).Magnitude
	local offset = mn - u.bmin * s
	local m = Instance.new("Model")
	m.Name = unitName
	m:SetAttribute("ImportedProp", true)
	for _, p in ipairs(parts) do
		local c = p:Clone()
		c.CFrame = cf * (CFrame.new(-offset) * rel[p])
		c.Anchored = true
		c.CanCollide = false
		c.CanTouch = false
		c.Parent = m
	end
	m.WorldPivot = cf
	local k = scale or 1
	if math.abs(k / s - 1) > 0.002 then
		m:ScaleTo(k / s)
	end
	local cols = Instance.new("Folder")
	cols.Name = "Colliders"
	cols.Parent = m
	for _, c in ipairs(u.cols) do
		local p = Instance.new("Part")
		p.Name = "Collider"
		p.Size = Vector3.new(c[4], c[5], c[6]) * k
		p.CFrame = cf * CFrame.new(Vector3.new(c[1], c[2], c[3]) * k)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = true
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = cols
	end
	m.Parent = parent
	return m
end

local function templeLight(parent: Instance, name: string, pos: Vector3, color: Color3, brightness: number, range: number)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = pos
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = true
	l.Parent = p
	p.Parent = parent
end

-- ข้อความบนแผ่นป้ายที่หันไป +Z (NormalId.Back) — slots = { { ข้อความ, ตำแหน่ง X (0..1), ความกว้าง (0..1) } }
local function templeLabels(part: BasePart?, slots: { { any } }, textSize: number?)
	if not part then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TempleText"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = part
	for _, s in ipairs(slots) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(s[2], 0.5)
		t.Size = UDim2.fromScale(s[3], 0.8)
		t.Text = s[1]
		t.TextColor3 = TEMPLE_GOLD_TEXT
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.Parent = gui
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = textSize or 60
		c.Parent = t
	end
end

-- origin = จุดกลางลานวัดบนพื้น (ค่าเริ่มต้น 0,0,600 ห่างจากแมพหลัก) · ประตูวัดหันไป +Z
-- rebuild = true: ย้ายชุดเดิมไปเก็บ ServerStorage.ArchivedPlaceholders.TempleLobby แล้วสร้างใหม่
-- spread = ขยายพื้นที่วัด (ค่าเริ่มต้น 2) รั้ว/พื้น/ลานกลางคูณตามนี้ แต่ขนาดอาคารเท่าเดิม (ควร ≥ 2 ไม่งั้นอาคารชิดกัน)
function MapBuilder.BuildTempleLobby(origin: Vector3?, rebuild: boolean?, spread: number?)
	local old = Workspace:FindFirstChild("TempleLobby")
	if old then
		if not rebuild then
			warn("[MapBuilder] BuildTempleLobby: มี Workspace.TempleLobby แล้ว (ส่ง rebuild = true เพื่อสร้างใหม่)")
			return
		end
		old.Name = "TempleLobby_Old"
		old.Parent = archiveFolder("TempleLobby")
	end
	local store = templeStore()
	for _, name in ipairs(TEMPLE_FILES) do
		assert(store:FindFirstChild(name), "ยังไม่ได้นำเข้า " .. name .. ".fbx")
	end
	local O = origin or Vector3.new(0, 0, 600)
	local G = O + Vector3.new(0, 0.1, 0)
	local K = spread or 2
	local function at(x: number, z: number, yaw: number?, y: number?): CFrame
		return CFrame.new(G + Vector3.new(x, y or 0, z)) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	end
	local lobby = Instance.new("Model")
	lobby.Name = "TempleLobby"
	lobby.WorldPivot = CFrame.new(G)

	-- พื้นลานวัด + ทางเดินปูนจากประตูถึงบันไดโบสถ์
	local ground = Instance.new("Part")
	ground.Name = "TempleGround"
	ground.Size = Vector3.new(200 * K, 1, 176 * K)
	ground.CFrame = CFrame.new(G + Vector3.new(0, -0.5, -2 * K))
	ground.Material = Enum.Material.Ground
	ground.Color = Color3.fromRGB(66, 58, 48)
	ground.Anchored = true
	ground.Parent = lobby
	-- ประตูวัด (FRONT) / รั้วหลัง (BACK) / รั้วข้าง (±X) ขยายตาม spread
	-- โบสถ์ชิดด้านหลัง (UBZ) เพื่อเปิดลานโล่งกลางวัดไว้ให้ผู้เล่นรวมตัว ศาลา (ซ้าย) / กุฏิ (ขวา) อยู่ริมรั้ว
	local FRONT, BACK, X = 62 * K, -70 * K, 81 * K
	local UBZ = BACK + 45
	local plazaBack, plazaFront = UBZ + 46, FRONT - 14
	local plazaZ = (plazaBack + plazaFront) / 2
	local plazaW = 2 * X - 130
	local plaza = Instance.new("Part")
	plaza.Name = "TemplePlaza"
	plaza.Size = Vector3.new(plazaW, 0.2, plazaFront - plazaBack)
	plaza.CFrame = CFrame.new(G + Vector3.new(0, 0.1, plazaZ))
	plaza.Material = Enum.Material.Concrete
	plaza.Color = Color3.fromRGB(104, 100, 92)
	plaza.Anchored = true
	plaza.Parent = lobby
	-- ทางเดินจากบันไดโบสถ์ถึงหน้าประตู (ตัดกลางลาน)
	local pathFrom, pathTo = UBZ + 32, FRONT + 6
	local path = Instance.new("Part")
	path.Name = "TemplePath"
	path.Size = Vector3.new(10, 0.2, pathTo - pathFrom)
	path.CFrame = CFrame.new(G + Vector3.new(0, 0.15, (pathFrom + pathTo) / 2))
	path.Material = Enum.Material.Concrete
	path.Color = Color3.fromRGB(112, 110, 102)
	path.Anchored = true
	path.Parent = lobby

	-- จุดเกิดผู้เล่น: กลางลาน (ล่องหน ไม่ชน)
	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Size = Vector3.new(8, 1, 8)
	lobbySpawn.CFrame = CFrame.new(G + Vector3.new(14, 0.4, plazaZ))
	lobbySpawn.Anchored = true
	lobbySpawn.Transparency = 1
	lobbySpawn.CanCollide = false
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Parent = lobby

	-- ประตูวัด + ป้ายชื่อวัด
	placeTempleUnit(store, "TempleGate", at(0, FRONT), lobby)
	local sign = placeTempleUnit(store, "TempleNameSign", at(24, FRONT + 5), lobby)
	templeLabels(sign:FindFirstChild("TempleNameSign_Plaque") :: BasePart, { { "วัดท้ายทุ่ง", 0.25, 0.42 }, { "WAT THAI THUNG", 0.75, 0.42 } })

	-- รั้ววัด: ช่วงละ 12 studs มีเสาหัวลูกแก้วที่ปลาย เดินวนจากหน้าขวา → ขวา → หลัง → ซ้าย → หน้าซ้าย
	local fence = Instance.new("Model")
	fence.Name = "TempleFence"
	fence.Parent = lobby
	local function run(x: number, z: number, yaw: number, length: number)
		local cf = at(x, z, yaw)
		local d = 0
		while length - d >= 12 do
			placeTempleUnit(store, "FenceSegment", cf * CFrame.new(d, 0, 0), fence)
			d += 12
		end
		if length - d >= 6 then
			placeTempleUnit(store, "FenceSegment_Half", cf * CFrame.new(d, 0, 0), fence)
		end
	end
	run(9, FRONT, 0, X - 9)
	run(X, FRONT, 90, FRONT - BACK)
	run(X, BACK, 180, 2 * X)
	run(-X, BACK, -90, FRONT - BACK)
	run(-X, FRONT, 0, X - 9)

	-- โบสถ์ท้ายลาน หันหน้าเข้าหาประตู + พระ 3 องค์บนฐานชุกชี
	placeTempleUnit(store, "Ubosot", at(0, UBZ), lobby)
	local trio = placeTempleUnit(store, "BuddhaTrio", at(0, UBZ - 15.6, 0, 2.86), lobby, 1.2)
	trio.Name = "BuddhaTrio_Ubosot"
	local NAMES = { { "พระแก่นจันทร์", 0.115, 0.22 }, { "พระประธาน", 0.5, 0.22 }, { "พระเกษร", 0.885, 0.22 } }
	templeLabels(trio:FindFirstChild("BuddhaTrio_Plaques") :: BasePart, NAMES, 40)
	templeLight(lobby, "UbosotCandleLight", G + Vector3.new(0, 9, UBZ - 8), Color3.fromRGB(255, 160, 80), 1.1, 24)
	-- ไฟสาดหน้าโบสถ์สีขาวอมฟ้า ให้เห็นหน้าบันลอยขึ้นมาจากความมืดเมื่อมองจากลาน
	templeLight(lobby, "UbosotFacadeLight", G + Vector3.new(0, 6, UBZ + 52), Color3.fromRGB(190, 210, 255), 1, 48)

	-- ศาลาการเปรียญ (ฝั่งซ้าย หันหน้าเข้าลาน) + พระ 3 องค์อีกชุด
	local SALA = at(-X + 28, plazaZ, 90)
	placeTempleUnit(store, "Sala", SALA, lobby)
	local trio2 = placeTempleUnit(store, "BuddhaTrio", SALA * CFrame.new(0, 2.99, -10.81), lobby, 1.4)
	trio2.Name = "BuddhaTrio_Sala"
	templeLabels(trio2:FindFirstChild("BuddhaTrio_Plaques") :: BasePart, NAMES, 40)
	templeLight(lobby, "SalaLight", (SALA * CFrame.new(0, 11, -3.5)).Position, Color3.fromRGB(200, 215, 255), 0.5, 26)

	-- กุฏิ 2 หลัง (ฝั่งขวา หันหน้าเข้าลาน) ย่อ 2/3 = ขนาดจริง (ไฟล์ปั้นไว้ใหญ่ 1.5 เท่า) ประตู ~5.4 × 7 studs
	local KUTI = 1 / 1.5
	placeTempleUnit(store, "Kuti", at(X - 12, plazaZ + 25, -90), lobby, KUTI)
	placeTempleUnit(store, "Kuti", at(X - 12, plazaZ - 25, -90), lobby, KUTI).Name = "Kuti_2"
	templeLight(lobby, "KutiLamp", G + Vector3.new(X - 14, 11, plazaZ + 25), Color3.fromRGB(255, 176, 96), 0.5, 16)

	-- เมรุ (มุมหลังซ้าย) + แสงแดงจางๆ ที่ประตูเตาเผา
	local MERU = at(-X + 25, BACK + 25)
	placeTempleUnit(store, "Meru", MERU, lobby)
	templeLight(lobby, "MeruFurnaceGlow", (MERU * CFrame.new(0, 7.5, 2.6)).Position, Color3.fromRGB(255, 70, 40), 0.5, 9)
	templeLight(lobby, "GateLamp", G + Vector3.new(0, 15, FRONT - 3), Color3.fromRGB(190, 210, 255), 0.6, 24)

	-- ป้ายบริจาค (หน้าป้ายเปล่า DonationBoard_Face ไว้ใส่ SurfaceGui ทำ dashboard ผู้บริจาค) หันเข้าลาน
	placeTempleUnit(store, "DonationBoard", at(-24, FRONT - 12, 180), lobby)
	-- ตู้บริจาค (จุดกดโดเนท) ข้างทางเข้ากำแพงแก้วโบสถ์ หันเข้าหาทางเดิน
	local box = placeTempleUnit(store, "DonationBox", at(-8.5, UBZ + 40, 90), lobby)
	local glass = box:FindFirstChild("DonationBox_Glass") :: BasePart
	if glass then
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.55
	end
	-- รถเข็นขายทุกอย่าง (ร้านค้า) ฝั่งขวาของทางเดิน หันเข้าหาทางเดิน
	local cart = placeTempleUnit(store, "ShopCart", at(22, FRONT - 18, -90), lobby)
	templeLabels(cart:FindFirstChild("ShopCart_Sign") :: BasePart, { { "ขายทุกอย่าง · All Goods", 0.5, 0.95 } }, 50)
	templeLight(lobby, "ShopCartLamp", G + Vector3.new(21, 10.5, FRONT - 18), Color3.fromRGB(255, 214, 150), 0.7, 14)

	-- ธาตุเก็บกระดูก 2 กลุ่ม (บางองค์เอียงนิดๆ ให้ดูเก่า)
	local stupas = Instance.new("Model")
	stupas.Name = "BoneStupas"
	stupas.Parent = lobby
	local rng = Random.new(907)
	local KINDS = { "BoneStupa_A", "BoneStupa_B", "BoneStupa_C" }
	local spots = {}
	for r = 0, 2 do
		for c = 0, 3 do
			table.insert(spots, { -31 - c * 6.5 - (r % 2) * 2, BACK + 8 + r * 7 })
		end
	end
	for r = 0, 1 do
		for c = 0, 3 do
			table.insert(spots, { 31 + c * 6.5, BACK + 7 + r * 7 })
		end
	end
	for i, sp in ipairs(spots) do
		local kind = KINDS[(i * 7 + rng:NextInteger(0, 2)) % 3 + 1]
		local cf = at(sp[1] + rng:NextNumber(-0.8, 0.8), sp[2] + rng:NextNumber(-0.8, 0.8), rng:NextInteger(-1, 1) * 4)
		if rng:NextNumber() < 0.25 then
			cf *= CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), 0, math.rad(rng:NextNumber(-3, 3)))
		end
		placeTempleUnit(store, kind, cf, stupas).Name = kind .. "_" .. i
	end

	-- ต้นมะม่วงในวัด (ใบไหวด้วย tag LeafFlutter จาก TagWindPlants ห้ามติด WindSway)
	local mangoStore = game:GetService("ServerStorage"):FindFirstChild("ImportedProps")
	if mangoStore and mangoStore:FindFirstChild("MangoTree") then
		-- ปลูกรอบขอบลาน (ไม่ขวางกลางลาน) มุมหลังขวาเป็นต้นไทร (ดูช่วงบรรยากาศหลอนด้านล่าง)
		local ex = plazaW / 2 + 8
		for i, p in ipairs({ { -ex, plazaFront - 10, 30 }, { ex, plazaFront - 10, 140 }, { -ex, plazaBack + 10, 250 }, { ex, plazaBack + 10, 80 } }) do
			local m = Instance.new("Model")
			m.Name = "TempleMango_" .. i
			m:SetAttribute("ImportedProp", true)
			local base = G + Vector3.new(p[1], -0.4, p[2])
			local pl = placeGroup(mangoStore :: Folder, "MangoTree", { "MangoTrunk", "MangoTwigs" }, base, p[3], "origin", m)
			m.PrimaryPart = pl.MangoTrunk
			m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(p[3]), 0)
			pl.MangoTwigs.CanCollide = false
			m.Parent = lobby
			MapBuilder.AddMangoLeaves(m)
		end
	else
		warn("[MapBuilder] BuildTempleLobby: ไม่พบ ImportedProps.MangoTree ข้ามการปลูกต้นไม้")
	end

	-- ---------------------------------------------------------------- บรรยากาศหลอน
	-- งานสวดอภิธรรมในศาลา, ต้นไทรพันผ้าสามสี + ศาลพระภูมิ, ดงกล้วยตานีมุมหน้า, ธงขาวหน้าเมรุ,
	-- เสาไฟไม้หลอดสลัวรอบลาน (tag FlickerLamp ให้ LobbyClient กะพริบ), หญ้ารกริมรั้ว และเงาคนยืนใต้ต้นไทร (tag Apparition)
	local CollectionService = game:GetService("CollectionService")
	local props = mangoStore :: Folder?
	local spooky = Instance.new("Model")
	spooky.Name = "SpookyDecor"
	spooky.Parent = lobby
	local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent or spooky
		return p
	end
	local function lamp(p: BasePart, color: Color3, brightness: number, range: number, flicker: boolean)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Brightness = brightness
		l.Range = range
		l.Shadows = true
		l.Parent = p
		if flicker then
			CollectionService:AddTag(p, "FlickerLamp")
		end
	end
	local GOLD = Color3.fromRGB(214, 172, 92)
	local CANDLE = Color3.fromRGB(255, 150, 70)

	-- งานศพในศาลา: โลงขาวขอบทองบนแท่น, รูปผู้ตายกรอบดำ, เทียนสองข้าง, พวงหรีดเรียงหน้าศาลา
	local funeral = Instance.new("Model")
	funeral.Name = "SalaFuneral"
	funeral.Parent = spooky
	local FLOOR = 2.99
	block("CoffinStand", Vector3.new(8.4, 1.6, 3.2), SALA * CFrame.new(0, FLOOR + 0.8, 1.5), Color3.fromRGB(92, 28, 24), Enum.Material.Wood, funeral)
	block("Coffin", Vector3.new(7.4, 2.2, 2.6), SALA * CFrame.new(0, FLOOR + 2.7, 1.5), Color3.fromRGB(236, 232, 222), Enum.Material.SmoothPlastic, funeral)
	block("CoffinTrim", Vector3.new(7.6, 0.25, 2.8), SALA * CFrame.new(0, FLOOR + 3.85, 1.5), GOLD, Enum.Material.Metal, funeral)
	block("PortraitFrame", Vector3.new(2.4, 3, 0.2), SALA * CFrame.new(0, FLOOR + 6.1, 3.1) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(15, 15, 15), Enum.Material.Wood, funeral)
	block("PortraitPhoto", Vector3.new(1.9, 2.4, 0.22), SALA * CFrame.new(0, FLOOR + 6.1, 3.12) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(150, 146, 140), Enum.Material.SmoothPlastic, funeral)
	block("PortraitEasel", Vector3.new(0.2, 4.4, 0.2), SALA * CFrame.new(0, FLOOR + 4.4, 3.4), Color3.fromRGB(40, 30, 24), Enum.Material.Wood, funeral)
	for _, sx in ipairs({ -4.6, 4.6 }) do
		block("CandleStand", Vector3.new(0.5, 3.6, 0.5), SALA * CFrame.new(sx, FLOOR + 1.8, 3), GOLD, Enum.Material.Metal, funeral)
		local candle = block("Candle", Vector3.new(0.35, 1.2, 0.35), SALA * CFrame.new(sx, FLOOR + 4.2, 3), Color3.fromRGB(240, 236, 220), Enum.Material.SmoothPlastic, funeral)
		local flame = block("CandleFlame", Vector3.new(0.18, 0.4, 0.18), SALA * CFrame.new(sx, FLOOR + 5, 3), CANDLE, Enum.Material.Neon, funeral)
		flame.CastShadow = false
		flame.CanCollide = false
		lamp(flame, CANDLE, 1.2, 14, true)
		candle.CanCollide = false
	end
	local wreathColors = { Color3.fromRGB(235, 232, 225), Color3.fromRGB(230, 200, 80), Color3.fromRGB(150, 110, 170), Color3.fromRGB(235, 232, 225) }
	for i = 0, 6 do
		local x = -18 + i * 6
		local base = SALA * CFrame.new(x, 0, 21.5)
		block("WreathLegL", Vector3.new(0.15, 6, 0.15), base * CFrame.new(-1, 3, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(60, 44, 30), Enum.Material.Wood, funeral)
		block("WreathLegR", Vector3.new(0.15, 6, 0.15), base * CFrame.new(1, 3, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(60, 44, 30), Enum.Material.Wood, funeral)
		local disc = block("Wreath", Vector3.new(0.5, 4.2, 4.2), base * CFrame.new(0, 5.2, 0) * CFrame.Angles(0, math.rad(90), 0), wreathColors[i % #wreathColors + 1], Enum.Material.Fabric, funeral)
		disc.Shape = Enum.PartType.Cylinder
		block("WreathRibbon", Vector3.new(1.4, 2.6, 0.08), base * CFrame.new(0, 2.6, 0.3), Color3.fromRGB(245, 245, 245), Enum.Material.Fabric, funeral)
	end

	-- ธงขาว (ธงกระดาษงานศพ) ปักหน้าเมรุ
	for i, sx in ipairs({ -12, -4, 4, 12 }) do
		local base = MERU * CFrame.new(sx, 0, 24 + (i % 2) * 3)
		block("FuneralFlagPole", Vector3.new(0.3, 16, 0.3), base * CFrame.new(0, 8, 0), Color3.fromRGB(120, 104, 70), Enum.Material.Wood)
		local flag = block("FuneralFlag", Vector3.new(1.4, 7, 0.06), base * CFrame.new(0.85, 12, 0) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(240, 238, 230), Enum.Material.Fabric)
		flag.CanCollide = false
	end

	if props then
		-- ต้นไทรใหญ่พันผ้าสามสี (ไม่มีใบ เหลือแต่กิ่ง/รากอากาศ) + ศาลพระภูมิ + ของเซ่นแตกๆ มุมหลังขวา
		local banyanBase = G + Vector3.new(X - 42, 0, BACK + 42)
		if props:FindFirstChild("SacredBanyanTree") then
			local m = Instance.new("Model")
			m.Name = "LobbyBanyanTree"
			m:SetAttribute("ImportedProp", true)
			local pl = placeGroup(props, "SacredBanyanTree", { "BanyanTrunk", "BanyanRoots", "BanyanLimbs", "BanyanTwigs", "BanyanAerialRoots", "SacredThaiRibbons" }, banyanBase, 200, "origin", m)
			for _, n in ipairs({ "BanyanTwigs", "BanyanAerialRoots", "BanyanLimbs", "SacredThaiRibbons" }) do
				pl[n].CanCollide = false
			end
			m.PrimaryPart = pl.BanyanTrunk
			m.Parent = spooky
		end
		if props:FindFirstChild("SpiritHouseOnStilts") then
			local pl = placeGroup(props, "SpiritHouseOnStilts", { "SpiritHouseOnStilts", "Incense1", "Incense2", "Incense3", "Incense1_Neon", "Incense2_Neon", "Incense3_Neon" }, banyanBase + Vector3.new(-26, 0, 18), 135, "bottom", spooky)
			for k = 1, 3 do
				makeNeon(pl["Incense" .. k .. "_Neon"], Color3.fromRGB(255, 90, 30))
			end
			lamp(pl.Incense2_Neon, Color3.fromRGB(255, 110, 50), 0.8, 10, true)
		end
		if props:FindFirstChild("SacredBanyanProps") then
			placeGroup(props, "SacredBanyanProps", { "BrokenOfferings" }, banyanBase + Vector3.new(-14, 0, 12), 160, "bottom", spooky)
			placeGroup(props, "SacredBanyanProps", { "OldMarbleBenchSet" }, banyanBase + Vector3.new(-30, 0, -6), 20, "bottom", spooky)
		end

		-- ดงกล้วยตานีมุมหน้าซ้าย/ขวา (ชื่อขึ้นต้น BananaTree ให้ TagWindPlants ติด tag ลม)
		if props:FindFirstChild("BananaClump") then
			local rngB = Random.new(4040)
			local n = 0
			for _, side in ipairs({ -1, 1 }) do
				for k = 0, 5 do
					n += 1
					local bx = side * (X - 12 - (k % 3) * 11 + rngB:NextNumber(-2, 2))
					local bz = FRONT - 12 - math.floor(k / 3) * 12 + rngB:NextNumber(-2, 2)
					local base = G + Vector3.new(bx, -0.2, bz)
					local yaw = rngB:NextNumber(0, 360)
					local m = Instance.new("Model")
					m.Name = "BananaTree_Lobby_" .. n
					m:SetAttribute("ImportedProp", true)
					local pl = placeGroup(props, "BananaClump", { "BananaClump", "BananaClump_B", "BananaClump_Base" }, base, yaw, "origin", m)
					m.PrimaryPart = pl.BananaClump
					m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
					m.Parent = spooky
				end
			end
		end

		-- เสาไฟไม้ 4 แถว × 3 (ริมลาน 2 แถว + กลางลาน 2 แถว) หลอดสลัวบางดวงกะพริบ
		-- ทุกเสาโยงสายไฟหย่อนๆ ถึงกัน: ตามแถวหน้า-หลัง และขวางลานทั้ง 3 แนว
		if props:FindFirstChild("TvAntennaAndPoles") then
			local half = (plazaFront - plazaBack) / 2
			local cols = { -(plazaW / 2 + 3), -plazaW / 6, plazaW / 6, plazaW / 2 + 3 }
			local rows = { plazaZ - half + 8, plazaZ, plazaZ + half - 8 }
			local tops: { { Vector3 } } = {}
			local n = 0
			for ci, cx in ipairs(cols) do
				tops[ci] = {}
				for ri, rz in ipairs(rows) do
					n += 1
					local m = Instance.new("Model")
					m.Name = "PlazaPole_" .. n
					m.Parent = spooky
					local pl = placeGroup(props, "TvAntennaAndPoles", { "WoodenPole", "WoodenPole_Neon" }, G + Vector3.new(cx, 0, rz), if cx < 0 then 90 else -90, "bottom", m)
					makeNeon(pl.WoodenPole_Neon, Color3.fromRGB(255, 226, 170))
					lamp(pl.WoodenPole_Neon, Color3.fromRGB(255, 214, 160), 1.3, 46, n % 3 == 1)
					local pole = pl.WoodenPole
					tops[ci][ri] = Vector3.new(G.X + cx, pole.Position.Y + pole.Size.Y / 2 - 0.8, G.Z + rz)
				end
			end
			local wires = Instance.new("Model")
			wires.Name = "PowerWires"
			wires.Parent = spooky
			-- สายไฟ 2 เส้นต่อช่วง หย่อนลงกลางช่วง 5% ของระยะ (แบ่งเป็นท่อนสั้นๆ ตามเส้นโค้ง)
			local function wire(a: Vector3, b: Vector3)
				local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
				local side = if flat.Magnitude > 0 then flat.Unit:Cross(Vector3.yAxis) * 0.7 else Vector3.zero
				local sag = (b - a).Magnitude * 0.05
				for _, off in ipairs({ side, -side }) do
					local SEG = 8
					local prev = a + off
					for k = 1, SEG do
						local t = k / SEG
						local p = a:Lerp(b, t) + off - Vector3.new(0, sag * 4 * t * (1 - t), 0)
						local len = (p - prev).Magnitude
						local w = Instance.new("Part")
						w.Name = "Wire"
						w.Shape = Enum.PartType.Cylinder
						w.Size = Vector3.new(len + 0.05, 0.12, 0.12)
						w.CFrame = CFrame.lookAt((prev + p) / 2, p) * CFrame.Angles(0, math.rad(90), 0)
						w.Color = Color3.fromRGB(22, 20, 18)
						w.Material = Enum.Material.SmoothPlastic
						w.Anchored = true
						w.CanCollide = false
						w.CanQuery = false
						w.CanTouch = false
						w.CastShadow = false
						w.Parent = wires
						prev = p
					end
				end
			end
			for ci = 1, #cols do
				for ri = 1, #rows - 1 do
					wire(tops[ci][ri], tops[ci][ri + 1])
				end
			end
			for ri = 1, #rows do
				for ci = 1, #cols - 1 do
					wire(tops[ci][ri], tops[ci + 1][ri])
				end
			end
		end

		-- โอ่งมังกรหน้ากุฏิ
		if props:FindFirstChild("DragonJar") then
			for _, dz in ipairs({ 25, -25 }) do
				placeGroup(props, "DragonJar", { "DragonJar", "DragonJar_Water" }, G + Vector3.new(X - 40, 0, plazaZ + dz + 9), 0, "bottom", spooky)
			end
		end

		-- หญ้ารกริมรั้ว (ไม่ขึ้นในลาน/ทางเดิน/ใต้อาคาร)
		if props:FindFirstChild("ThaiGrasses") then
			local keepOut = {
				{ -plazaW / 2 - 4, plazaW / 2 + 4, plazaBack - 4, plazaFront + 4 }, -- ลาน
				{ -8, 8, UBZ, FRONT + 8 }, -- ทางเดิน
				{ -30, 30, UBZ - 36, UBZ + 46 }, -- โบสถ์
				{ -X, -X + 52, plazaZ - 30, plazaZ + 30 }, -- ศาลา + พวงหรีด
				{ X - 44, X, plazaZ - 40, plazaZ + 40 }, -- กุฏิ
				{ -X, -X + 44, BACK, BACK + 70 }, -- เมรุ + ธง
				{ -60, 60, BACK, BACK + 30 }, -- ธาตุ
				{ X - 80, X, BACK, BACK + 80 }, -- ต้นไทร
				{ -X, X, FRONT - 32, FRONT }, -- ดงกล้วย / ประตู
			}
			local rngG = Random.new(5151)
			local count = 0
			for _ = 1, 400 do
				if count >= 70 then
					break
				end
				local gx, gz = rngG:NextNumber(-X + 3, X - 3), rngG:NextNumber(BACK + 3, FRONT - 3)
				local ok = true
				for _, r in ipairs(keepOut) do
					if gx > r[1] and gx < r[2] and gz > r[3] and gz < r[4] then
						ok = false
						break
					end
				end
				if ok then
					count += 1
					local kind = if count % 3 == 0 then "LemongrassClump" else "WildGrassClump"
					local base = G + Vector3.new(gx, -0.1, gz)
					local yaw = rngG:NextNumber(0, 360)
					local m = Instance.new("Model")
					m.Name = "LobbyGrass_" .. count
					m:SetAttribute("ImportedProp", true)
					local pl = placeGroup(props, "ThaiGrasses", { kind }, base, yaw, "origin", m)
					m.PrimaryPart = pl[kind]
					m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
					m.Parent = spooky
					m:ScaleTo(rngG:NextNumber(0.6, 0.95))
				end
			end
		end
	end

	-- ป่ารอบวัด 2 แนวนอกรั้ว (มะม่วงใบบาง + กอกล้วย) เว้นทางหน้าประตู + กำแพงล่องหนตามแนวรั้ว (ปิดประตูด้วย)
	-- หมอก (LobbyServer) กลืนป่าแนวนอกจนมองไม่เห็นขอบพื้น
	ground.Size = Vector3.new(2 * X + 170, 1, (FRONT - BACK) + 170)
	ground.CFrame = CFrame.new(G + Vector3.new(0, -0.5, (FRONT + BACK) / 2))
	if props and props:FindFirstChild("MangoTree") and props:FindFirstChild("BananaClump") then
		local forest = Instance.new("Model")
		forest.Name = "Forest"
		forest.Parent = lobby
		local rngF = Random.new(31337)
		local n = 0
		for _, d in ipairs({ 16, 40 }) do
			local x0, x1, z0, z1 = -X - d, X + d, BACK - d, FRONT + d
			local edges = { { x0, z0, x1, z0 }, { x1, z0, x1, z1 }, { x1, z1, x0, z1 }, { x0, z1, x0, z0 } }
			for _, e in ipairs(edges) do
				local len = Vector3.new(e[3] - e[1], 0, e[4] - e[2]).Magnitude
				local steps = math.floor(len / 22)
				for s = 0, steps - 1 do
					local t = (s + rngF:NextNumber(0.2, 0.8)) / steps
					local fx = e[1] + (e[3] - e[1]) * t + rngF:NextNumber(-5, 5)
					local fz = e[2] + (e[4] - e[2]) * t + rngF:NextNumber(-5, 5)
					if not (math.abs(fx) < 22 and fz > FRONT) then
						n += 1
						local base = G + Vector3.new(fx, -0.3, fz)
						local yaw = rngF:NextNumber(0, 360)
						local m = Instance.new("Model")
						m:SetAttribute("ImportedProp", true)
						if rngF:NextNumber() < 0.55 then
							m.Name = "ForestMango_" .. n
							local pl = placeGroup(props, "MangoTree", { "MangoTrunk", "MangoTwigs" }, base, yaw, "origin", m)
							pl.MangoTwigs.CanCollide = false
							m.PrimaryPart = pl.MangoTrunk
							m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
							m.Parent = forest
							m:ScaleTo(rngF:NextNumber(0.85, 1.3))
							MapBuilder.AddMangoLeaves(m, true, true)
						else
							m.Name = "BananaTree_Forest_" .. n
							local pl = placeGroup(props, "BananaClump", { "BananaClump", "BananaClump_B", "BananaClump_Base" }, base, yaw, "origin", m)
							m.PrimaryPart = pl.BananaClump
							m.WorldPivot = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)
							m.Parent = forest
							m:ScaleTo(rngF:NextNumber(0.9, 1.25))
						end
					end
				end
			end
		end
	end
	local walls = Instance.new("Folder")
	walls.Name = "InvisibleWalls"
	walls.Parent = lobby
	local WALL_H = 80
	for _, w in ipairs({
		{ Vector3.new(2 * X + 4, WALL_H, 2), Vector3.new(0, WALL_H / 2, FRONT + 1.5) },
		{ Vector3.new(2 * X + 4, WALL_H, 2), Vector3.new(0, WALL_H / 2, BACK - 1.5) },
		{ Vector3.new(2, WALL_H, FRONT - BACK + 4), Vector3.new(X + 1.5, WALL_H / 2, (FRONT + BACK) / 2) },
		{ Vector3.new(2, WALL_H, FRONT - BACK + 4), Vector3.new(-X - 1.5, WALL_H / 2, (FRONT + BACK) / 2) },
	}) do
		local wall = block("InvisibleWall", w[1], CFrame.new(G + w[2]), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, walls)
		wall.Transparency = 1
		wall.CastShadow = false
		wall.CanQuery = false
	end

	-- โซนสร้างห้อง: วงไฟนีออนแดง 6 วง (รัศมี 10) เรียง 2 แถวซ้าย-ขวาของลาน แถวละ 3 วงจากหน้าลานไปหลังลาน
	-- พื้นในวงเป็นพื้นลานเดิม; RoomPad_n เป็นแผ่นล่องหน (tag RoomPad + attribute PadIndex) ให้ LobbyServer ใช้หาว่าใครยืนวงไหน
	local pads = Instance.new("Folder")
	pads.Name = "RoomPads"
	pads.Parent = lobby
	local PAD_R = 10
	local padCol = plazaW / 3
	local padRows = { plazaFront - 24, plazaFront - 80, plazaFront - 136 }
	local idx = 0
	for _, side in ipairs({ -1, 1 }) do
		for _, pz in ipairs(padRows) do
			idx += 1
			local c = G + Vector3.new(side * padCol, 0, pz)
			local ring = Instance.new("Model")
			ring.Name = "RoomPadRing_" .. idx
			ring.Parent = pads
			local SEG = 36
			for k = 0, SEG - 1 do
				local a = (k + 0.5) / SEG * math.pi * 2
				local seg = block("RingSeg", Vector3.new(0.5, 0.12, 2 * math.pi * PAD_R / SEG + 0.08), CFrame.new(c + Vector3.new(math.cos(a) * PAD_R, 0.27, math.sin(a) * PAD_R)) * CFrame.Angles(0, -a, 0), Color3.fromRGB(255, 50, 36), Enum.Material.Neon, ring)
				seg.CanCollide = false
				seg.CanQuery = false
				seg.CastShadow = false
			end
			local pad = block("RoomPad_" .. idx, Vector3.new(0.4, PAD_R * 2, PAD_R * 2), CFrame.new(c + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, pads)
			pad.Shape = Enum.PartType.Cylinder
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanQuery = false
			pad.CastShadow = false
			pad:SetAttribute("PadIndex", idx)
			CollectionService:AddTag(pad, "RoomPad")
			-- เสาตะเกียงริมวงด้านนอกลาน
			local pc = c + Vector3.new(side * (PAD_R + 1.5), 0, 0)
			local post = block("RoomPadPost", Vector3.new(0.5, 7, 0.5), CFrame.new(pc + Vector3.new(0, 3.5, 0)), Color3.fromRGB(70, 52, 36), Enum.Material.Wood, pads)
			post.CanCollide = false
			local lantern = block("RoomPadLantern", Vector3.new(0.8, 1, 0.8), CFrame.new(pc + Vector3.new(0, 7.4, 0)), Color3.fromRGB(255, 120, 70), Enum.Material.Neon, pads)
			lantern.CastShadow = false
			lamp(lantern, Color3.fromRGB(255, 90, 60), 1, 20, idx % 2 == 0)
		end
	end

	-- เงาคนผมยาวชุดขาวยืนนิ่งใต้ต้นไทร (LobbyClient ทำให้จางหายเมื่อผู้เล่นเดินเข้าใกล้)
	local ghost = Instance.new("Model")
	ghost.Name = "LobbyApparition"
	local gbase = G + Vector3.new(X - 58, 0, BACK + 58)
	local gcf = CFrame.lookAt(gbase, Vector3.new(G.X, gbase.Y, plazaZ + G.Z))
	local dress = block("Dress", Vector3.new(1.8, 4.6, 1), gcf * CFrame.new(0, 2.3, 0), Color3.fromRGB(226, 226, 220), Enum.Material.Fabric, ghost)
	local head = block("Head", Vector3.new(1.1, 1.2, 1.1), gcf * CFrame.new(0, 5.2, 0), Color3.fromRGB(20, 18, 18), Enum.Material.Fabric, ghost)
	block("Hair", Vector3.new(1.3, 2.6, 0.5), gcf * CFrame.new(0, 4.3, -0.45), Color3.fromRGB(14, 12, 12), Enum.Material.Fabric, ghost)
	for _, p in ipairs(ghost:GetChildren()) do
		local bp = p :: BasePart
		bp.CanCollide = false
		bp.CanQuery = false
		bp.CastShadow = false
		bp.Transparency = 0.15
	end
	ghost.PrimaryPart = dress
	head.Shape = Enum.PartType.Ball
	CollectionService:AddTag(ghost, "Apparition")
	ghost.Parent = spooky

	lobby.Parent = Workspace
	MapBuilder.TagWindPlants()
	print("🛕 [MapBuilder] สร้างวัด Workspace.TempleLobby ที่ " .. tostring(O) .. " (spread " .. K .. ")")
	return lobby
end

-- ===================================================================================
-- 🚗 รถและจักรยานสไตล์ไทย 8 คัน (tools/blender/thai_vehicles.py → assets/models/Thai*.fbx)
-- แม่แบบอยู่ ServerStorage.VehicleTemplates (anchored, pivot = พื้นใต้กึ่งกลางรถ, หน้ารถ -Z เหมือน CustomerBike)
-- ข้อมูลที่นั่ง/ล้อ/ไฟ/กล่องชนมาจาก Shared.ThaiVehicleRigs (สร้างจาก vehicle_rig_to_luau.py)
-- mesh ทุกชิ้น CanCollide = false ชนเฉพาะกล่องล่องหนใน "Colliders" + ลูกบอลลื่น "Skid" ที่ล้อ
-- ถ้ายังไม่ได้นำเข้า FBX จะใช้ชิ้น Part แทน (Body.Proxy) และสลับเป็น mesh เองเมื่อรันซ้ำหลังนำเข้า
-- ===================================================================================
local THAI_VEHICLES = {
	{ name = "ThaiPickupOld", kind = "Car", maxSpeed = 42, turn = 1.3 },
	{ name = "ThaiSedanSoluna", kind = "Car", maxSpeed = 50, turn = 1.4 },
	{ name = "ThaiBicycleRed", kind = "Bicycle", maxSpeed = 20, turn = 2.0 },
	{ name = "ThaiBicycleBlue", kind = "Bicycle", maxSpeed = 20, turn = 2.0 },
	{ name = "ThaiTukTuk", kind = "TukTuk", maxSpeed = 34, turn = 1.8 },
	{ name = "ThaiRacingMoto", kind = "Motorcycle", maxSpeed = 48, turn = 1.9 },
	{ name = "ThaiSoundTruck", kind = "Car", maxSpeed = 38, turn = 1.2 },
	{ name = "ThaiParadeTruck", kind = "Truck", maxSpeed = 32, turn = 0.9 },
}
MapBuilder.THAI_VEHICLES = THAI_VEHICLES

local VEHICLE_MATERIAL: { [string]: Enum.Material } = {
	pk_paint = Enum.Material.CorrodedMetal,
	pk_paint_top = Enum.Material.CorrodedMetal,
	rust = Enum.Material.CorrodedMetal,
	cage_rust = Enum.Material.CorrodedMetal,
	rim_rust = Enum.Material.CorrodedMetal,
	glass = Enum.Material.Glass,
	chrome = Enum.Material.Metal,
	steel = Enum.Material.Metal,
	horn = Enum.Material.Metal,
	mt_gold = Enum.Material.Metal,
	mt_purple = Enum.Material.Metal,
	tt_roof = Enum.Material.Fabric,
	seat_cloth = Enum.Material.Fabric,
	speaker_box = Enum.Material.Fabric,
	seat_vinyl = Enum.Material.Leather,
	saddle = Enum.Material.Leather,
	tt_seat = Enum.Material.Leather,
	floor_tread = Enum.Material.DiamondPlate,
	basket = Enum.Material.DiamondPlate,
	led = Enum.Material.Neon,
}

local function thaiRigs(): { [string]: any }
	-- :Clone() กัน Studio แคชโมดูลเก่า (เหมือนกฎ Command Bar)
	return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ThaiVehicleRigs"):Clone()) :: any
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function vehPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ป้ายทะเบียนไทย / ป้ายไฟ ด้วย SurfaceGui (ใช้ได้ทั้งตอนมี mesh และตอนใช้ proxy)
local function vehicleSign(parent: Instance, name: string, d: any, lines: { string }, bg: Color3, fg: Color3, glow: boolean): Part
	local p = vehPart(parent, name, v3(d.s), CFrame.new(v3(d.c)), bg)
	local g = Instance.new("SurfaceGui")
	g.Face = if d.front == 1 then Enum.NormalId.Front else Enum.NormalId.Back
	g.CanvasSize = Vector2.new(math.floor(200 * d.s[1] / d.s[2]), 200)
	g.LightInfluence = if glow then 0 else 1
	g.Brightness = if glow then 1.6 else 1
	g.Parent = p
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = bg
	f.BorderSizePixel = 6
	f.BorderColor3 = Color3.fromRGB(20, 20, 20)
	f.BorderMode = Enum.BorderMode.Inset
	f.Parent = g
	for i, txt in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		local h = if #lines == 1 then 1 else (if i == 1 then 0.62 else 0.38)
		t.Size = UDim2.new(1, -16, h, -8)
		t.Position = UDim2.new(0, 8, if i == 1 then 0 else 0.62, 4)
		t.Text = txt
		t.TextColor3 = fg
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.Parent = f
	end
	return p
end

-- วาง MeshPart จากโมเดลที่นำเข้า (3D Importer) ให้ตรงเฟรมรถ: หาทิศหน้ารถจากล้อหน้า-ล้อหลัง และขนาดจากระยะล้อ
local function adoptImportedMeshes(name: string, rig: any, body: Instance, frame: CFrame): { [string]: MeshPart }?
	local ss = game:GetService("ServerStorage")
	local stored = ss:FindFirstChild("ImportedProps") and ss.ImportedProps:FindFirstChild("ThaiVehicles")
	local fresh = Workspace:FindFirstChild(name)
	local src = (if fresh and fresh:IsA("Model") and not fresh:HasTag("PlayerVehicle") then fresh else nil)
		or findImportedModel(name)
		or (stored and stored:FindFirstChild(name) :: Model?)
	if not src then
		return nil
	end
	if src.Parent == Workspace then
		-- เก็บต้นฉบับที่นำเข้าไว้ ServerStorage.ImportedProps.ThaiVehicles (ไม่ลบ) ใช้สร้างแม่แบบใหม่ได้ภายหลัง
		local ip = ss:FindFirstChild("ImportedProps") or Instance.new("Folder")
		ip.Name = "ImportedProps"
		ip.Parent = ss
		local tv = ip:FindFirstChild("ThaiVehicles") or Instance.new("Folder")
		tv.Name = "ThaiVehicles"
		tv.Parent = ip
		local old = tv:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		src.Parent = tv
	end
	local meshes: { [string]: MeshPart } = {}
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("MeshPart") then
			meshes[(d.Name:gsub("%.%d+$", ""))] = d
		end
	end
	local wf, wr = rig.wheels[1], rig.wheels[#rig.wheels]
	local mf, mr = meshes[wf.n], meshes[wr.n]
	if not (mf and mr and meshes[name]) then
		warn("⚠️ [MapBuilder] " .. name .. ": โมเดลที่นำเข้าไม่มีชิ้น " .. wf.n .. "/" .. wr.n .. "/" .. name .. " ใช้ proxy แทน")
		return nil
	end
	local eF, eR = v3(rig.bbox[wf.n].c), v3(rig.bbox[wr.n].c)
	local dA = (mr.Position - mf.Position) * Vector3.new(1, 0, 1)
	local dE = (eR - eF) * Vector3.new(1, 0, 1)
	local k = dA.Magnitude / math.max(dE.Magnitude, 1e-3) -- ขนาดที่นำเข้าเทียบกับ studs ที่ปั้น
	local yaw = math.atan2(-dA.Z, dA.X) - math.atan2(-dE.Z, dE.X)
	local rot = CFrame.Angles(0, yaw, 0)
	local srcFrame = CFrame.new(mf.Position - rot:VectorToWorldSpace(eF * k)) * rot -- เฟรมรถ ณ จุดที่นำเข้า
	local out: { [string]: MeshPart } = {}
	for n, mesh in pairs(meshes) do
		local c = mesh:Clone()
		for _, ch in ipairs(c:GetChildren()) do
			if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") then
				ch:Destroy()
			end
		end
		local rel = srcFrame:ToObjectSpace(mesh.CFrame)
		if math.abs(k - 1) > 0.02 then
			c.Size = c.Size / k
			rel = CFrame.new(rel.Position / k) * (rel - rel.Position)
		end
		c.CFrame = frame * rel
		c.Anchored = true
		c.CanCollide = false
		c.CanTouch = false
		c.CanQuery = false
		c.Massless = true
		c.Name = n
		if n:find("_Glass$") then
			c.Transparency = 0.55
			c.CastShadow = false
		elseif n:find("_Neon$") then
			-- วงไฟลำโพง <ชื่อรถ>_LED<i>_Neon: สีที่ i ของ rig.led_colors
			local sa = c:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa:Destroy()
			end
			local ci = tonumber(n:match("_LED(%d+)_Neon$"))
			local lc = rig.led_colors and ci and rig.led_colors[ci]
			c.Material = Enum.Material.Neon
			c.Color = if lc then Color3.fromRGB(lc[1], lc[2], lc[3]) else Color3.fromRGB(255, 60, 200)
			c:SetAttribute("LedIndex", ci or 1)
			c:AddTag("VehicleLED")
		end
		c.Parent = body
		out[n] = c
	end
	return out
end



local function buildThaiVehicle(spec: any, rig: any): Model
	local frame = CFrame.new() -- สร้างที่จุดกำเนิดโลก แล้ว PivotTo ทีหลัง
	local m = Instance.new("Model")
	m.Name = spec.name
	m:SetAttribute("VehicleKind", spec.kind)
	m:SetAttribute("MaxSpeed", spec.maxSpeed)
	m:SetAttribute("TurnRate", spec.turn)
	m:SetAttribute("PlayerDrivable", true)
	m:SetAttribute("LightsOn", true)
	m:SetAttribute("TemplateReady", true)

	-- แกนกลางรถ (PrimaryPart) อยู่ที่ระดับดุมล้อ, pivot ของรถ = พื้นใต้กึ่งกลางรถ
	local hubY = rig.wheels[1].c[2]
	local chassis = vehPart(m, "Chassis", Vector3.new(1, 1, 1), frame * CFrame.new(0, hubY, 0), Color3.fromRGB(255, 0, 255))
	chassis.Transparency = 1
	chassis.Massless = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(4, 0, 0, 100, 1)
	m.PrimaryPart = chassis
	chassis.PivotOffset = CFrame.new(0, -hubY, 0)

	local body = Instance.new("Model")
	body.Name = "Body"
	body.Parent = m
	local meshes = adoptImportedMeshes(spec.name, rig, body, frame)
	m:SetAttribute("UsesImportedMesh", meshes ~= nil)
	if not meshes then
		local proxy = Instance.new("Model")
		proxy.Name = "Proxy"
		proxy.Parent = body
		for _, d in ipairs(rig.proxy) do
			if d.k == "horn" then
				-- แถวลำโพงฮอร์น: กระบอกเงินเรียงกัน ปากบานหันไปหน้ารถ
				local hs = v3(d.s)
				local hc = frame * CFrame.new(v3(d.c))
				for i = 1, 8 do
					local x = -hs.X / 2 + hs.X * (i - 0.5) / 8
					vehPart(proxy, "Horn", Vector3.new(hs.Z, 0.5, 0.5), hc * CFrame.new(x, -0.1, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(176, 178, 182), Enum.Material.Metal, Enum.PartType.Cylinder)
					vehPart(proxy, "HornBell", Vector3.new(0.15, 0.85, 0.85), hc * CFrame.new(x, -0.1, -hs.Z / 2) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(196, 198, 202), Enum.Material.Metal, Enum.PartType.Cylinder)
				end
				continue
			end
			local pc = rig.pal[d.k]
			local color = Color3.fromRGB(pc[1], pc[2], pc[3])
			local mat = VEHICLE_MATERIAL[d.k] or (if pc[4] >= 0.8 then Enum.Material.Metal else Enum.Material.SmoothPlastic)
			local size, cf = v3(d.s), frame * CFrame.new(v3(d.c))
			if d.rx then
				-- แผ่น/แท่งเฉียงตามเส้นทแยงของกล่อง (กระจกหน้า ฝากระโปรงเปิด ท่อเฟรมจักรยาน)
				local len = math.sqrt(size.Y ^ 2 + size.Z ^ 2)
				local ang = math.atan2(size.Y, size.Z) * (if d.rx > 0 then -1 else 1)
				cf = cf * CFrame.Angles(ang, 0, 0)
				size = Vector3.new(size.X, d.th, len)
			end
			local p = vehPart(proxy, "Proxy_" .. d.k, size, cf, color, mat)
			if d.k == "glass" then
				p.Transparency = 0.55
				p.CastShadow = false
			end
			if d.n == 1 then
				p.Color = Color3.fromRGB(255, 60, 200)
				p:AddTag("VehicleLED")
			end
		end
		-- ลำโพง: หน้าลำโพงกลมสีดำ + จานไฟนีออนด้านหลังที่โตกว่าเล็กน้อย (เห็นเป็นวงไฟรอบลำโพง)
		for _, sp in ipairs(rig.speakers or {}) do
			local rot = if sp.ax == "x" then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
			local cf = frame * CFrame.new(v3(sp.c)) * rot
			local lc = rig.led_colors[sp.ci + 1]
			local ring = vehPart(proxy, "SpeakerLED", Vector3.new(0.08, sp.d - 0.02, sp.d - 0.02), cf, Color3.fromRGB(lc[1], lc[2], lc[3]), Enum.Material.Neon, Enum.PartType.Cylinder)
			ring:SetAttribute("LedIndex", sp.ci + 1)
			ring:AddTag("VehicleLED")
			local outward = frame:VectorToWorldSpace(if sp.ax == "x" then Vector3.new(math.sign(sp.c[1]), 0, 0) else Vector3.new(0, 0, math.sign(sp.c[3])))
			vehPart(proxy, "SpeakerCone", Vector3.new(0.1, sp.d * 0.8, sp.d * 0.8), cf + outward * 0.06, Color3.fromRGB(40, 40, 44), Enum.Material.Fabric, Enum.PartType.Cylinder)
			vehPart(proxy, "SpeakerCap", Vector3.new(0.14, sp.d * 0.22, sp.d * 0.22), cf + outward * 0.09, Color3.fromRGB(120, 120, 128), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		for _, lb in ipairs(rig.ledbars or {}) do
			local lc = rig.led_colors[lb.ci + 1]
			local p = vehPart(proxy, "LedBar", v3(lb.s), frame * CFrame.new(v3(lb.c)), Color3.fromRGB(lc[1], lc[2], lc[3]), Enum.Material.Neon)
			p:SetAttribute("LedIndex", lb.ci + 1)
			p:AddTag("VehicleLED")
		end
	end
	-- ไฟสีส่องจากตู้ลำโพงลงพื้นรอบรถ (สีเปลี่ยนตามวงไฟ)
	if rig.led_colors then
		local glowAt = { Vector3.new(4.2, 6, 4.8), Vector3.new(-4.2, 6, 4.8), Vector3.new(0, 7, 8.6) }
		for i, pos in ipairs(glowAt) do
			local lc = rig.led_colors[i]
			local g = vehPart(body, "SpeakerGlow" .. i, Vector3.new(0.2, 0.2, 0.2), frame * CFrame.new(pos), Color3.new(0, 0, 0))
			g.Transparency = 1
			local pl = Instance.new("PointLight")
			pl.Color = Color3.fromRGB(lc[1], lc[2], lc[3])
			pl.Range = 14
			pl.Brightness = 1.6
			pl.Parent = g
			g:SetAttribute("LedIndex", i)
			g:AddTag("VehicleLED")
		end
	end

	-- ล้อ (mesh ที่นำเข้า หรือทรงกระบอกแทน) ต่อกับ Chassis ด้วย Motor6D ให้สคริปต์ขับหมุนล้อ/เลี้ยวได้
	local wheels = Instance.new("Model")
	wheels.Name = "Wheels"
	wheels.Parent = m
	for _, w in ipairs(rig.wheels) do
		local cf = frame * CFrame.new(v3(w.c))
		local wp: BasePart
		if meshes and meshes[w.n] then
			wp = meshes[w.n]
			wp.Parent = wheels
		else
			wp = vehPart(wheels, w.n, Vector3.new(w.w, w.r * 2, w.r * 2), cf, Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, Enum.PartType.Cylinder)
			local rimColor = if spec.name == "ThaiPickupOld" then Color3.fromRGB(122, 82, 52) elseif spec.name == "ThaiSoundTruck" then Color3.fromRGB(25, 25, 28) elseif spec.name == "ThaiRacingMoto" then Color3.fromRGB(214, 166, 60) else Color3.fromRGB(180, 182, 188)
			local rim = vehPart(wp, "Rim", Vector3.new(w.w + 0.06, w.r * 1.3, w.r * 1.3), cf, rimColor, Enum.Material.Metal, Enum.PartType.Cylinder)
			local wc = Instance.new("WeldConstraint")
			wc.Part0, wc.Part1 = wp, rim
			wc.Parent = rim
		end
		local motor = Instance.new("Motor6D")
		motor.Name = "Axle"
		motor.Part0 = chassis
		motor.Part1 = wp
		motor.C0 = chassis.CFrame:ToObjectSpace(cf)
		motor.C1 = wp.CFrame:ToObjectSpace(cf)
		motor:SetAttribute("Steer", w.st == 1)
		motor:SetAttribute("Radius", w.r)
		motor:SetAttribute("BaseC0", motor.C0)
		motor.Parent = wp
	end

	-- กล่องชนล่องหน + ลูกบอลลื่นที่ล้อ (แตะพื้นแทนล้อ ไม่ติดขอบหลุม)
	local cols = Instance.new("Model")
	cols.Name = "Colliders"
	cols.Parent = m
	for i, c in ipairs(rig.cols) do
		local p = vehPart(cols, "Collider" .. i, v3(c.s), frame * CFrame.new(v3(c.c)), Color3.new(1, 0, 0))
		p.Transparency = 1
		p.CanCollide = true
		p.CanQuery = true
		p.Massless = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.4, c.f or 0.3, 0, if c.f then 1 else 0.5, 1)
	end
	for i, s in ipairs(rig.skids) do
		local p = vehPart(cols, "Skid" .. i, Vector3.one * (s.r * 2), frame * CFrame.new(v3(s.c)), Color3.new(0, 1, 0), nil, Enum.PartType.Ball)
		p.Transparency = 1
		p.CanCollide = true
		p.Massless = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0, 0, 100, 1)
	end

	-- ที่นั่ง (VehicleSeat = คนขับ, Seat = ผู้โดยสาร) ล่องหน ไม่กันทาง
	for _, s in ipairs(rig.seats) do
		local seat = Instance.new(s.t) :: BasePart
		seat.Name = s.n
		seat.Size = v3(s.s)
		seat.CFrame = frame * CFrame.new(v3(s.c))
		seat.Transparency = 1
		seat.Anchored = true
		seat.CanCollide = false
		seat.CanQuery = true
		seat.Massless = true
		if seat:IsA("VehicleSeat") then
			seat.MaxSpeed = 0
			seat.Torque = 0
			seat.HeadsUpDisplay = false
		end
		seat.Parent = m
	end

	-- ไฟหน้า (SpotLight) / ไฟท้าย เป็น Part Neon แปะทับเลนส์ของ mesh
	local lights = Instance.new("Model")
	lights.Name = "Lights"
	lights.Parent = m
	local small = spec.kind == "Bicycle"
	for i, l in ipairs(rig.lights) do
		local head = l.t == "head"
		local size = v3(l.s)
		local cf = frame * CFrame.new(v3(l.c))
		local p
		if l.rd == 1 then -- โคมกลม: ทรงกระบอกแกนตามความยาวรถ
			p = vehPart(lights, if head then "Headlight" .. i else "Taillight" .. i, Vector3.new(size.Z, size.X, size.Y), cf * CFrame.Angles(0, math.rad(90), 0),
				if head then Color3.fromRGB(255, 238, 200) else Color3.fromRGB(200, 20, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
		else
			p = vehPart(lights, if head then "Headlight" .. i else "Taillight" .. i, size, cf,
				if head then Color3.fromRGB(255, 238, 200) else Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
		end
		p.CastShadow = false
		if head then
			local att = Instance.new("Attachment")
			att.Name = "BeamAttachment"
			att.Parent = p
			att.WorldCFrame = CFrame.lookAt(p.Position, p.Position + frame:VectorToWorldSpace(Vector3.new(0, -0.12, -1)))
			local spot = Instance.new("SpotLight")
			spot.Name = "HeadlightBeam"
			spot.Face = Enum.NormalId.Front
			spot.Angle = if small then 45 else 60
			spot.Range = if small then 26 else 48
			spot.Brightness = if small then 2 else 3.5
			spot.Color = Color3.fromRGB(255, 232, 180)
			spot.Shadows = not small
			spot.Parent = att
		else
			local glow = Instance.new("PointLight")
			glow.Name = "TailGlow"
			glow.Color = Color3.fromRGB(255, 30, 20)
			glow.Range = 5
			glow.Brightness = 0.8
			glow.Parent = p
		end
	end
	for i, pl in ipairs(rig.plates) do
		vehicleSign(m, "LicensePlate" .. i, pl, { pl.t, pl.p }, Color3.fromRGB(240, 240, 232), Color3.fromRGB(20, 20, 20), false)
	end
	for i, sg in ipairs(rig.signs) do
		local taxi = sg.t == "TAXI"
		vehicleSign(m, "RoofSign" .. i, sg, { sg.t },
			if taxi then Color3.fromRGB(240, 200, 40) else Color3.fromRGB(14, 14, 18),
			if taxi then Color3.fromRGB(160, 20, 20) else Color3.fromRGB(80, 230, 255), true)
	end
	if rig.led_colors then
		local list = {}
		for _, c in ipairs(rig.led_colors) do
			table.insert(list, string.format("%d,%d,%d", c[1], c[2], c[3]))
		end
		m:SetAttribute("LedColors", table.concat(list, ";"))
	end

	-- เชื่อมทุกชิ้นเข้ากับ Chassis (ยกเว้นล้อที่ใช้ Motor6D) ให้ขยับทั้งคันได้เมื่อปลด Anchored
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= chassis and d.Parent ~= wheels and not d:IsDescendantOf(wheels) then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = chassis
			wc.Part1 = d
			wc.Parent = d
		end
	end
	return m
end

-- สร้าง/สร้างใหม่แม่แบบรถไทยทั้ง 8 คันใน ServerStorage.VehicleTemplates (ไม่แตะ CustomerBike / Saleng)
-- แม่แบบเดิมชื่อเดียวกันย้ายไป ServerStorage.ArchivedPlaceholders.ThaiVehicles (เก็บไว้รุ่นเดียว)
-- รันซ้ำได้: require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildThaiVehicleTemplates()
function MapBuilder.BuildThaiVehicleTemplates(only: { string }?)
	local ss = game:GetService("ServerStorage")
	local folder = ss:FindFirstChild("VehicleTemplates") or Instance.new("Folder")
	folder.Name = "VehicleTemplates"
	folder.Parent = ss
	local archive = ss:FindFirstChild("ArchivedPlaceholders") or Instance.new("Folder")
	archive.Name = "ArchivedPlaceholders"
	archive.Parent = ss
	local arch = archive:FindFirstChild("ThaiVehicles") or Instance.new("Folder")
	arch.Name = "ThaiVehicles"
	arch.Parent = archive
	local rigs = thaiRigs()
	local built = {}
	for _, spec in ipairs(THAI_VEHICLES) do
		if only and not table.find(only, spec.name) then
			continue
		end
		local rig = rigs[spec.name]
		if not rig then
			warn("⚠️ [MapBuilder] ไม่มีข้อมูล rig ของ " .. spec.name)
			continue
		end
		local old = folder:FindFirstChild(spec.name)
		if old then
			local prev = arch:FindFirstChild(spec.name)
			if prev then
				prev:Destroy()
			end
			old.Parent = arch
		end
		local m = buildThaiVehicle(spec, rig)
		m.Parent = folder
		table.insert(built, spec.name .. (if m:GetAttribute("UsesImportedMesh") then " (mesh)" else " (proxy)"))
		task.wait()
	end
	print("🚗 [MapBuilder] แม่แบบรถไทยใน ServerStorage.VehicleTemplates: " .. table.concat(built, ", "))
end

-- วางรถที่ผู้เล่นขึ้นขับได้ 1 คัน (ปลด Anchored + tag "PlayerVehicle" ให้ ThaiVehicleDrive.server ควบคุม)
function MapBuilder.SpawnThaiVehicle(name: string, cf: CFrame, parent: Instance?): Model?
	local folder = game:GetService("ServerStorage"):FindFirstChild("VehicleTemplates")
	local t = folder and folder:FindFirstChild(name)
	if not t then
		warn("⚠️ [MapBuilder] ไม่พบแม่แบบ " .. name .. " (รัน BuildThaiVehicleTemplates() ก่อน)")
		return nil
	end
	local m = t:Clone() :: Model
	m:PivotTo(cf)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	m:AddTag("PlayerVehicle")
	m.Parent = parent or Workspace
	return m
end

-- จอดรถทั้ง 8 คันเรียงกันไว้ทดสอบ/ถ่ายภาพ ใน Workspace.ThaiVehicleShowcase (เรียงตามแกน +X จาก origin หน้ารถหัน -Z)
function MapBuilder.ParkThaiVehicles(origin: Vector3?, spacing: number?): Folder
	local o = origin or Vector3.new(-40, 0, -30)
	local f = Workspace:FindFirstChild("ThaiVehicleShowcase") or Instance.new("Folder")
	f.Name = "ThaiVehicleShowcase"
	f:ClearAllChildren()
	f.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local templates = game:GetService("ServerStorage"):FindFirstChild("VehicleTemplates")
	local x = o.X
	for _, spec in ipairs(THAI_VEHICLES) do
		-- วางสูงกว่าพื้นจุดที่สูงที่สุดใต้ตัวรถ (กันกล่องชนจมดินแล้วรถดีดเอียงตอนเกิด)
		local t = templates and templates:FindFirstChild(spec.name)
		local ext = if t then (t :: Model):GetExtentsSize() else Vector3.new(4, 4, 8)
		local y = -math.huge
		for _, dx in ipairs({ -0.5, 0, 0.5 }) do
			for _, dz in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
				local hit = Workspace:Raycast(Vector3.new(x + dx * ext.X, o.Y + 60, o.Z + dz * ext.Z), Vector3.new(0, -200, 0), params)
				if hit then
					y = math.max(y, hit.Position.Y)
				end
			end
		end
		y = if y == -math.huge then o.Y else y
		MapBuilder.SpawnThaiVehicle(spec.name, CFrame.new(x, y + 0.3, o.Z), f)
		x += spacing or math.max(ext.X + 3, 9)
	end
	return f
end

return MapBuilder
