--!strict
-- RobuxShop.server.luau — ร้านค้า Robux ในแมพปั๊ม (ผู้ใช้ 2026-11-23)
--   1) ไฟฉายตราช้าง (Game Pass 49): วางบนเคาน์เตอร์ / เจ้าของ = player attribute ElephantLight · กดหยิบมาใช้ = ElephantInUse
--      Flashlight.server: ถ่านไม่ลด + ไฟบนตัวไฟฉายแรงขึ้น · HUDController: ลำแสงของตัวเองไกลขึ้น สว่างขึ้น
--   2) ป้ายผี (Product 19): แปะผนังซ้ายในร้าน ซื้อแล้วกระสือโผล่หลอกทุกคนในห้อง ยกเว้นคนซื้อ
--   3) ต่อธูป (Product 19): ปุ่ม R ที่กระถางธูปศาลพระภูมิ ขึ้นเฉพาะตอนมีดอกดับ (CoreLoop.AddIncense)
--      ซื้อตอนธูปครบพอดี (คนอื่นจุดไปก่อน) = เก็บไว้ จุดให้ทันทีที่มีดอกดับ
-- รหัสสินค้า: shared/RobuxShop.luau
-- admin (ไม่หัก Robux): ServerStorage.RobuxShopTest:Fire(player, "elephant" | "prank" | "incense")

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notice = remotes:WaitForChild("Notice") :: RemoteEvent
local TriggerJumpscare = remotes:WaitForChild("TriggerJumpscare") :: RemoteEvent

local PROMPT_RANGE = 9

-- ---------------------------------------------------------------- ตัวช่วย
local function notice(player: Player, key: string, vars: { [string]: any }?)
	Notice:FireClient(player, key, 5, vars)
end

-- ข้อความบนป้ายทุกภาษาจาก LanguageModule.UI (BilingualText ฝั่ง client เลือกภาษาให้)
local function bil(label: TextLabel, key: string)
	local e = LanguageModule.UI[key]
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

local function makePrompt(name: string, parent: Instance, range: number?): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name
	pr.HoldDuration = 0
	pr.MaxActivationDistance = range or PROMPT_RANGE
	pr.RequiresLineOfSight = false
	pr.AutoLocalize = false
	pr:SetAttribute("NeedsFacing", true)
	pr:SetAttribute("Range", range or PROMPT_RANGE)
	pr.Parent = parent
	return pr
end

local folder = workspace:FindFirstChild("RobuxShop") or Instance.new("Folder")
folder.Name = "RobuxShop"
folder:ClearAllChildren()
folder.Parent = workspace

-- ของที่วางไว้ในไฟล์ place (ผู้ใช้ 2026-11-23: อยากเห็นและลากย้ายเองในโหมด edit): Workspace.RobuxShopProps
--   ElephantFlashlightDisplay (Model: ElephantFlashlight / ElephantLens / ElephantSidePanel) + GhostPoster (Part)
--   มี = ใช้ตำแหน่งที่วางไว้ (ลากย้ายใน Studio แล้ว Save ได้เลย) · ไม่มี = สร้างที่ตำแหน่งตั้งต้นด้านล่าง
local placed = workspace:FindFirstChild("RobuxShopProps")

-- ---------------------------------------------------------------- 1) ไฟฉายตราช้าง: วางบนเคาน์เตอร์ข้างตะเกียง (ผู้ใช้ 2026-11-23)
--   ไม่เปิดไฟ ไม่มีป้าย · ไม่มี Pass: กดแล้วซื้อ · มี Pass: ทุกคนเริ่มด้วยไฟฉายกบ กดที่นี่เพื่อหยิบไฟฉายตราช้างมาใช้ (กดอีกครั้ง = กลับไปใช้ไฟฉายกบ)
--   ใช้อยู่ = player attribute ElephantInUse (server/Flashlight: หน้าตา + ถ่านไม่หมด + ไฟแรง · client/HUDController: ลำแสงไกล)
--   ข้อความปุ่มต่างกันแต่ละคน: client/RobuxShop ตั้งเอง
local COUNTER_AT = CFrame.new(6.2, 5.84, 14.3) * CFrame.Angles(0, math.rad(-90), 0) -- ขอบเคาน์เตอร์ด้านในร้าน (หลังตะเกียง) หัวไฟชี้ +X
local elephantModel = Instance.new("Model")
elephantModel.Name = "ElephantFlashlightDisplay"
elephantModel.Parent = folder
local promptHost: BasePart
local placedDisplay = placed and placed:FindFirstChild("ElephantFlashlightDisplay")
local placedMain = placedDisplay and placedDisplay:FindFirstChild("ElephantFlashlight", true)
if placedMain and placedMain:IsA("BasePart") then
	-- วางไว้ในแมพแล้ว: ใช้ตัวนั้น (ไม่เปิดไฟ)
	elephantModel:Destroy()
	elephantModel = placedDisplay :: Model
	for _, d in ipairs(elephantModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			if d.Name == "ElephantLens" then
				d.Material = Enum.Material.Glass
				d.Transparency = 0.35
			elseif d.Name == "ElephantSidePanel" then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.fromRGB(150, 152, 158)
			end
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	promptHost = placedMain
else
	local showParts = IDS.PlaceElephant(COUNTER_AT * CFrame.new(0, IDS.ELEPHANT_HALF_HEIGHT, 0), 1, elephantModel)
	if showParts and showParts.ElephantFlashlight then
		for _, sp in pairs(showParts) do
			sp.Anchored = true
		end
		local panel = showParts.ElephantSidePanel
		if panel then
			panel.Material = Enum.Material.SmoothPlastic
			panel.Color = Color3.fromRGB(150, 152, 158)
		end
		promptHost = showParts.ElephantFlashlight
	else
		-- ยังไม่ได้ Import โมเดล (ServerStorage.ElephantFlashlight): จุดกดล่องหนไว้ก่อน
		promptHost = part({ Name = "ElephantSpot", Size = Vector3.new(1, 1, 1), CFrame = COUNTER_AT * CFrame.new(0, 0.5, 0), Transparency = 1 }, elephantModel)
	end
end
-- ระยะกดสั้น (ผู้ใช้ 2026-11-23: ปุ่มร้าน Robux ขึ้นจากไกลเกินไป บังปุ่มงานบนเคาน์เตอร์)
local elephantPrompt = makePrompt("BuyElephantPrompt", promptHost, 4.5)

-- ---------------------------------------------------------------- 2) ป้ายผี: ผนังสังกะสีฝั่งตะวันตกในร้าน (ข้างประตูไม้) หันเข้าร้าน (+X)
local POSTER_POS = Vector3.new(-16.25, 8.0, 21.0)
local placedPoster = placed and placed:FindFirstChild("GhostPoster")
local poster: BasePart = if placedPoster and placedPoster:IsA("BasePart")
	then placedPoster
	else part({ Name = "GhostPoster", Size = Vector3.new(2.7, 3.6, 0.05), CFrame = CFrame.lookAt(POSTER_POS, POSTER_POS + Vector3.xAxis), Color = Color3.fromRGB(20, 12, 12), Material = Enum.Material.SmoothPlastic }, folder)
-- รูปกระดาษขาดมีขอบโปร่งใส: ตัวแผ่นต้องล่องหน ไม่งั้นเห็นสี่เหลี่ยมทึบหลังรอยขาด (SurfaceGui ยังแสดงบนแผ่นล่องหนได้)
poster.Transparency = if IDS.PosterImage ~= "" then 1 else 0
poster.Anchored = true
poster.CanCollide = false
for _, old in ipairs(poster:GetChildren()) do
	if old:IsA("SurfaceGui") or old:IsA("ProximityPrompt") then
		old:Destroy() -- รูปตัวอย่างที่วางไว้ในโหมด edit: สร้างใหม่ให้มีข้อความตามภาษา
	end
end
do
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 110
	sg.LightInfluence = 1 -- แสงปกติของฉาก: มืดก็มืดตาม ส่องไฟฉายถึงเห็น (ผู้ใช้ 2026-11-24 เดิม 0.25 เรืองในความมืด)
	sg.Brightness = 1
	sg.Parent = poster
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(14, 6, 6)
	-- รูปกระดาษเก่า (tools/blender/ghost_poster_aged.py) เต็มป้าย ขอบขาดโปร่งใส: พื้นหลังไม่ต้องทึบ (ยังไม่มีรูป = พื้นดำเดิม)
	bg.BackgroundTransparency = if IDS.PosterImage ~= "" then 1 else 0
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local img = Instance.new("ImageLabel")
	img.Name = "Ghost"
	img.BackgroundTransparency = 1
	img.Position = if IDS.PosterImage ~= "" then UDim2.fromScale(0, 0) else UDim2.fromScale(0.04, 0.12)
	img.Size = if IDS.PosterImage ~= "" then UDim2.fromScale(1, 1) else UDim2.fromScale(0.92, 0.7)
	img.ScaleType = Enum.ScaleType.Crop
	img.Image = IDS.PosterImage
	img.Parent = bg
	if IDS.PosterImage == "" then
		-- ยังไม่ได้อัปโหลดรูป (assets/models/GhostPoster/upload/GhostPoster.png): ใช้หน้าผีตัวอักษรไปก่อน
		local face = Instance.new("TextLabel")
		face.BackgroundTransparency = 1
		face.Size = UDim2.fromScale(1, 1)
		face.Text = "👻"
		face.TextScaled = true
		face.Parent = img
	end
	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromScale(0.04, 0.015)
	top.Size = UDim2.fromScale(0.92, 0.1)
	top.FontFace = Font.fromEnum(Enum.Font.Creepster)
	top.TextColor3 = Color3.fromRGB(235, 40, 30)
	top.TextStrokeColor3 = Color3.fromRGB(20, 6, 4)
	top.TextStrokeTransparency = 0.3
	top.ZIndex = 3
	top.TextScaled = true
	top.Parent = bg
	bil(top, "PosterTop")
	local bottom = Instance.new("TextLabel")
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromScale(0.04, 0.84)
	bottom.Size = UDim2.fromScale(0.92, 0.14)
	bottom.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	bottom.TextColor3 = Color3.fromRGB(236, 228, 208)
	bottom.TextStrokeColor3 = Color3.fromRGB(20, 6, 4)
	bottom.TextStrokeTransparency = 0.3
	bottom.ZIndex = 3
	bottom.TextScaled = true
	bottom.TextWrapped = true
	bottom.Parent = bg
	bil(bottom, "PosterBottom")
	-- กระดาษเทปมุมบน ให้ดูเป็นป้ายแปะ (เฉพาะป้ายแบบไม่มีรูป: รูปกระดาษขาดมีขอบของตัวเองแล้ว)
	for _, x in ipairs(if IDS.PosterImage ~= "" then {} else { -1.15, 1.15 }) do
		part({ Name = "Tape", Size = Vector3.new(0.5, 0.18, 0.06), CFrame = poster.CFrame * CFrame.new(x, 1.72, -0.02) * CFrame.Angles(0, 0, math.rad(x > 0 and -30 or 30)), Color = Color3.fromRGB(220, 210, 170), Material = Enum.Material.SmoothPlastic, Transparency = 0.15 }, folder)
	end
end
local prankPrompt = makePrompt("BuyPrankPrompt", poster, 5)

-- ---------------------------------------------------------------- 3) ต่อธูป: ปุ่ม R ที่กระถางธูป
local spirit = workspace:WaitForChild("SpiritHouse", 30)
local pot = spirit and spirit:WaitForChild("IncensePot", 10) :: BasePart?
local MAX_INCENSE = 0
if spirit then
	for _, c in ipairs(spirit:GetChildren()) do
		if string.match(c.Name, "^Incense%d+_Neon$") then
			MAX_INCENSE += 1
		end
	end
end
if MAX_INCENSE == 0 then
	MAX_INCENSE = 3
end
local incensePrompt: ProximityPrompt? = nil
if pot then
	local pr = makePrompt("BuyIncensePrompt", pot, 6)
	-- ปุ่มถวายขนมใช้ E ที่ศาลเดียวกัน: แยกเป็น R และขึ้นพร้อมกันได้
	pr.KeyboardKeyCode = Enum.KeyCode.R
	pr.GamepadKeyCode = Enum.KeyCode.ButtonX
	pr.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	pr.UIOffset = Vector2.new(0, 70)
	pr:SetAttribute("OwnKey", true) -- client/PromptFacing: ไม่แย่งที่กับปุ่ม E ถวายขนม
	incensePrompt = pr
end

local function incenseNow(): number
	return tonumber(remotes:GetAttribute("Incense")) or MAX_INCENSE
end
local function canRelight(): boolean
	local n = incenseNow()
	return n > 0 and n < MAX_INCENSE and remotes:GetAttribute("GameOver") ~= true
end
local function refreshIncensePrompt()
	if incensePrompt then
		incensePrompt.Enabled = canRelight()
	end
end
remotes:GetAttributeChangedSignal("Incense"):Connect(refreshIncensePrompt)
remotes:GetAttributeChangedSignal("GameOver"):Connect(refreshIncensePrompt)
refreshIncensePrompt()

-- ---------------------------------------------------------------- ผลของสินค้า
local function giveElephant(player: Player)
	if player:GetAttribute("ElephantLight") ~= true then
		player:SetAttribute("ElephantLight", true)
	end
end

local function doPrank(buyer: Player)
	local models = ReplicatedStorage:FindFirstChild("GhostModels")
	local ghost = models and models:FindFirstChild("Krasue")
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= buyer then
			TriggerJumpscare:FireClient(p, "Prank_Poster", ghost)
			task.delay(2.8, function()
				if p.Parent then
					notice(p, "Shop_PrankBy", { name = buyer.DisplayName })
				end
			end)
		end
	end
	notice(buyer, "Shop_PrankDone")
	print("[RobuxShop] ป้ายผี: " .. buyer.Name .. " หลอกทุกคน")
end

local pendingIncense = 0
local function relightOne(buyer: Player?): boolean
	if not canRelight() then
		return false
	end
	local CoreLoop = require(script.Parent:WaitForChild("CoreLoop")) :: any
	if not CoreLoop.AddIncense(1) then
		return false
	end
	if buyer then
		for _, p in ipairs(Players:GetPlayers()) do
			notice(p, "Shop_IncenseBy", { name = buyer.DisplayName })
		end
	end
	return true
end
local function doIncense(buyer: Player)
	if not relightOne(buyer) then
		pendingIncense += 1
		notice(buyer, "Shop_IncenseQueued")
	end
	print("[RobuxShop] ต่อธูป: " .. buyer.Name .. " (ค้างจุด " .. pendingIncense .. ")")
end
-- ซื้อไว้ตอนธูปครบ: ดอกไหนดับก็จุดคืนทันที
remotes:GetAttributeChangedSignal("Incense"):Connect(function()
	if pendingIncense > 0 and canRelight() then
		task.defer(function()
			if pendingIncense > 0 and relightOne(nil) then
				pendingIncense -= 1
			end
		end)
	end
end)

-- ---------------------------------------------------------------- Game Pass
-- ทุก Game Pass (shared/RobuxShop.PASSES) ซื้อที่ Lobby หรือที่นี่ก็ได้: เข้าแมพมาแล้วเช็กให้ทุกอัน
local GOT_NOTICE = { ElephantLight = "Shop_ElephantGot", FastPrayer = "Shop_FastPrayGot", WingSandals = "Shop_SandalsGot", GhostBook = "Shop_GhostBookGot", BigRoom = "Shop_BigRoomGot" }
local function checkPasses(player: Player)
	for _, pass in ipairs(IDS.PASSES) do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				player:SetAttribute(pass.attr, true)
			end
		end
	end
end
Players.PlayerAdded:Connect(checkPasses)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(checkPasses, p)
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, pass in ipairs(IDS.PASSES) do
		if pass.id == passId then
			player:SetAttribute(pass.attr, true)
			notice(player, GOT_NOTICE[pass.attr])
			if pass.attr == "ElephantLight" then
				player:SetAttribute("ElephantInUse", true) -- เพิ่งซื้อที่เคาน์เตอร์: ใช้เลย
			end
		end
	end
end)
-- รองเท้าแตะติดปีก: ได้/เอาคืนระหว่างเดินอยู่ = ปรับความเร็วทันที (ไม่แตะตอนโดนชะลอ/หยุดเดินอยู่)
local function onSandals(player: Player)
	player:GetAttributeChangedSignal("WingSandals"):Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local base = game:GetService("StarterPlayer").CharacterWalkSpeed
		local normal = math.abs(hum.WalkSpeed - base) < 0.01 or math.abs(hum.WalkSpeed - base * IDS.SANDALS_SPEED) < 0.01
		if normal then
			hum.WalkSpeed = IDS.WalkSpeed(player)
		end
	end)
end
Players.PlayerAdded:Connect(onSandals)
for _, p in ipairs(Players:GetPlayers()) do
	onSandals(p)
end

-- ---------------------------------------------------------------- Developer Products
local granted: { [string]: boolean } = {}
MarketplaceService.ProcessReceipt = function(info: any): Enum.ProductPurchaseDecision
	if granted[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if info.ProductId == IDS.PrankProductId and IDS.PrankProductId ~= 0 then
		doPrank(player)
	elseif info.ProductId == IDS.IncenseProductId and IDS.IncenseProductId ~= 0 then
		doIncense(player)
	else
		warn("[RobuxShop] ไม่รู้จักสินค้า " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	granted[info.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ---------------------------------------------------------------- ปุ่มซื้อ
local function othersInRoom(player: Player): boolean
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			return true
		end
	end
	return false
end

elephantPrompt.Triggered:Connect(function(player: Player)
	if player:GetAttribute("ElephantLight") == true then
		-- มี Pass: หยิบมาใช้ / วางคืน (กลับไปใช้ไฟฉายกบ)
		local use = player:GetAttribute("ElephantInUse") ~= true
		player:SetAttribute("ElephantInUse", use)
		notice(player, if use then "Shop_ElephantPicked" else "Shop_ElephantReturned")
		return
	end
	if IDS.ElephantPassId == 0 then
		warn("[RobuxShop] ยังไม่ได้ใส่ ElephantPassId ใน shared/RobuxShop")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, IDS.ElephantPassId)
end)
prankPrompt.Triggered:Connect(function(player: Player)
	if not othersInRoom(player) then
		notice(player, "Shop_PrankAlone")
		return
	end
	if IDS.PrankProductId == 0 then
		warn("[RobuxShop] ยังไม่ได้ใส่ PrankProductId ใน shared/RobuxShop")
		return
	end
	MarketplaceService:PromptProductPurchase(player, IDS.PrankProductId)
end)
if incensePrompt then
	incensePrompt.Triggered:Connect(function(player: Player)
		if not canRelight() then
			return
		end
		if IDS.IncenseProductId == 0 then
			warn("[RobuxShop] ยังไม่ได้ใส่ IncenseProductId ใน shared/RobuxShop")
			return
		end
		MarketplaceService:PromptProductPurchase(player, IDS.IncenseProductId)
	end)
end

-- ---------------------------------------------------------------- ทดสอบจากแผง admin (ไม่หัก Robux)
local test = ServerStorage:FindFirstChild("RobuxShopTest") :: BindableEvent?
if not test then
	local ev = Instance.new("BindableEvent")
	ev.Name = "RobuxShopTest"
	ev.Parent = ServerStorage
	test = ev
end
(test :: BindableEvent).Event:Connect(function(player: Player, what: string)
	if what == "elephant" then
		local own = player:GetAttribute("ElephantLight") ~= true
		player:SetAttribute("ElephantLight", own)
		if not own then
			player:SetAttribute("ElephantInUse", false)
		end
	elseif what == "fastpray" then
		player:SetAttribute("FastPrayer", player:GetAttribute("FastPrayer") ~= true)
	elseif what == "ghostbook" then
		player:SetAttribute("GhostBook", player:GetAttribute("GhostBook") ~= true)
	elseif what == "sandals" then
		player:SetAttribute("WingSandals", player:GetAttribute("WingSandals") ~= true)
	elseif what == "prank" then
		doPrank(player)
	elseif what == "prankself" then
		-- เล่นคนเดียวใน Studio: ให้คนกดโดนเองจะได้เห็นผีที่โผล่
		local models = ReplicatedStorage:FindFirstChild("GhostModels")
		TriggerJumpscare:FireClient(player, "Prank_Poster", models and models:FindFirstChild("Krasue"))
	elseif what == "incense" then
		doIncense(player)
	end
end)
