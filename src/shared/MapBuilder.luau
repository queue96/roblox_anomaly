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

return MapBuilder
