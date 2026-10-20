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
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = Color3.fromRGB(28, 24, 19)
		baseplate.Material = Enum.Material.Ground
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

	local mapEnv = getOrCreateFolder("MapEnvironment")
	local interactive = getOrCreateFolder("InteractiveProps")
	local spiritHouse = getOrCreateFolder("SpiritHouse")
	local anomalyProps = getOrCreateFolder("AnomalyProps")
	local waypoints = getOrCreateFolder("VehicleWaypoints")

	-- ตั้งค่า Lighting ตอนเที่ยงคืนชนบท
	Lighting.ClockTime = 0
	Lighting.Brightness = 0.3
	Lighting.Ambient = Color3.fromRGB(15, 22, 20)
	Lighting.OutdoorAmbient = Color3.fromRGB(15, 22, 20)
	Lighting.GlobalShadows = true

	-- =====================================================
	-- 1. โซนถนนดินลูกรัง, ร่องล้อ, หลักกิโล & เสาไฟไม้ (DirtRoad)
	-- =====================================================
	local dirtRoadModel = Instance.new("Model")
	dirtRoadModel.Name = "DirtRoad"
	dirtRoadModel.Parent = mapEnv

	local roadPart = createPart(
		"RoadSurface",
		Vector3.new(160, 0.6, 22),
		CFrame.new(0, 0.3, -12),
		Color3.fromRGB(92, 54, 34),
		Enum.Material.Mud,
		dirtRoadModel
	)
	-- ร่องรอยล้อรถบนถนนดิน
	createPart("WheelTrack1", Vector3.new(160, 0.65, 2.2), CFrame.new(0, 0.32, -8), Color3.fromRGB(72, 42, 26), Enum.Material.Ground, dirtRoadModel)
	createPart("WheelTrack2", Vector3.new(160, 0.65, 2.2), CFrame.new(0, 0.32, -14), Color3.fromRGB(72, 42, 26), Enum.Material.Ground, dirtRoadModel)

	-- ลานดินอัดแน่นหน้าเพิงร้าน
	createPart("ShopDirtYard", Vector3.new(44, 0.55, 22), CFrame.new(0, 0.28, 6), Color3.fromRGB(82, 52, 34), Enum.Material.Ground, dirtRoadModel)

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

	-- คันนาดินกั้นแปลงนา
	createPart("RiceBund_Front", Vector3.new(160, 0.9, 3.0), CFrame.new(0, 0.45, -24.5), Color3.fromRGB(52, 62, 36), Enum.Material.Grass, riceFieldModel)
	createPart("RiceBund_Mid", Vector3.new(3.2, 0.9, 52), CFrame.new(-10, 0.45, -50), Color3.fromRGB(52, 62, 36), Enum.Material.Grass, riceFieldModel)
	createPart("RiceBund_Right", Vector3.new(3.2, 0.9, 52), CFrame.new(25, 0.45, -50), Color3.fromRGB(52, 62, 36), Enum.Material.Grass, riceFieldModel)

	-- กอข้าวในทุ่งนา
	for rx = -45, 45, 9 do
		for rz = -32, -62, -8 do
			createPart(
				"RiceClump",
				Vector3.new(1.8, 2.2, 1.8),
				CFrame.new(rx + math.random(-2, 2), 1.2, rz + math.random(-2, 2)) * CFrame.Angles(0, math.rad(math.random(0, 180)), 0),
				Color3.fromRGB(38, 72, 32),
				Enum.Material.Grass,
				riceFieldModel
			)
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
	-- 4. โซนดงกล้วยตานีทึบๆ รอบร้าน (BananaGrove - 14 ต้น)
	-- =====================================================
	local bananaModel = Instance.new("Model")
	bananaModel.Name = "BananaGrove"
	bananaModel.Parent = mapEnv

	local bananaCoords = {
		{ pos = Vector3.new(21, 0, 10), scale = 1.0 },
		{ pos = Vector3.new(25, 0, 14), scale = 1.15 },
		{ pos = Vector3.new(20, 0, 19), scale = 0.95 },
		{ pos = Vector3.new(27, 0, 21), scale = 1.2 },
		{ pos = Vector3.new(22, 0, 27), scale = 1.05 },
		{ pos = Vector3.new(29, 0, 29), scale = 1.1 },
		{ pos = Vector3.new(17, 0, 32), scale = 1.0 },
		{ pos = Vector3.new(11, 0, 34), scale = 1.15 },
		{ pos = Vector3.new(4, 0, 35), scale = 0.9 },
		{ pos = Vector3.new(-4, 0, 35), scale = 1.1 },
		{ pos = Vector3.new(-12, 0, 34), scale = 1.0 },
		{ pos = Vector3.new(33, 0, 18), scale = 1.25 },
		{ pos = Vector3.new(34, 0, 26), scale = 1.05 },
		{ pos = Vector3.new(24, 0, 36), scale = 1.15 },
	}
	for i, bData in ipairs(bananaCoords) do
		local tree = buildDetailedBananaTree(bananaModel, bData.pos, bData.scale, i)
		if i == 1 and tree.PrimaryPart then
			addLabel(tree.PrimaryPart, "🍌 ดงกล้วยตานี (BananaGrove)", Color3.fromRGB(110, 235, 120))
		end
	end

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

	-- 5.4 วิทยุทรานซิสเตอร์พร้อมเสาอากาศ (Radio) & กระป๋องคุกกี้แดงใส่เงิน (MoneyTin)
	local radioPart = createPart("Radio", Vector3.new(2.1, 1.3, 0.9), CFrame.new(4, 4.45, 13), Color3.fromRGB(42, 44, 48), Enum.Material.Metal, interactive)
	createPart("RadioAntenna", Vector3.new(0.12, 2.2, 0.12), CFrame.new(4.8, 5.6, 13) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(190, 195, 200), Enum.Material.Metal, interactive)
	addLabel(radioPart, "📻 Radio (วิทยุทรานซิสเตอร์)", Color3.fromRGB(140, 220, 255))

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
	-- 6. ศาลพระภูมิไม้เก่า + หลังคาจั่ว + ธูป 3 ดอก (SpiritHouse)
	-- =====================================================
	createPart("ShrinePillar", Vector3.new(1.1, 4.6, 1.1), CFrame.new(-22, 2.3, 10), Color3.fromRGB(92, 64, 42), Enum.Material.Wood, spiritHouse)
	createPart("ShrinePlatform", Vector3.new(5.2, 0.4, 4.6), CFrame.new(-22, 4.7, 10), Color3.fromRGB(115, 78, 48), Enum.Material.WoodPlanks, spiritHouse)
	local shrineHouse = createPart("ShrineTop", Vector3.new(3.2, 2.8, 2.8), CFrame.new(-22, 6.2, 10.4), Color3.fromRGB(140, 45, 42), Enum.Material.WoodPlanks, spiritHouse)
	-- หลังคาจั่วศาลพระภูมิ
	createPart("ShrineRoofL", Vector3.new(2.6, 0.35, 3.6), CFrame.new(-23.0, 8.1, 10.4) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(165, 125, 45), Enum.Material.Wood, spiritHouse)
	createPart("ShrineRoofR", Vector3.new(2.6, 0.35, 3.6), CFrame.new(-21.0, 8.1, 10.4) * CFrame.Angles(0, 0, math.rad(-35)), Color3.fromRGB(165, 125, 45), Enum.Material.Wood, spiritHouse)
	addLabel(shrineHouse, "⛩️ SpiritHouse (ศาลพระภูมิ - ธูป 3 ดอก)", Color3.fromRGB(255, 110, 120))

	for i = 1, 3 do
		local inc = createPart(
			"Incense" .. i,
			Vector3.new(0.2, 1.3, 0.2),
			CFrame.new(-23.2 + (i * 0.6), 5.5, 8.5),
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
	-- 7.1 หุ่นไล่กากลางทุ่งนา (ใส่หมวกงอบ + กางแขนไม้ไผ่)
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

	print("✨ [MapBuilder] ตกแต่งฉาก 3D แบบละเอียด (เพิงไม้ไผ่สังกะสี, ดงกล้วย 14 ต้น, ทุ่งนาคันนา, ตู้ปั๊มหลอดแก้ว) เสร็จสมบูรณ์!")
end

return MapBuilder
