-- CoreLoop.luau (ModuleScript ฝั่ง Server)
-- Phase 3: ลูปหลักของเกม "ปั๊มหลอดท้ายทุ่ง"
--   รถลูกค้า (Clone จาก ServerStorage.VehicleTemplates) ขี่จาก SpawnPoint มาจอดที่ StopPoint
--   -> ล็อกปุ่ม 3 วินาทีให้ผู้เล่นส่องไฟฉายดูก่อน
--   -> ผู้เล่นเลือก "เติมน้ำมัน" (กดค้าง 3 วิ ที่ตู้ปั๊ม) หรือ "ดึงแผงปิดร้าน" (กดค้าง 0.5 วิ ที่เชือก)
--   -> ตรวจคำตอบจาก currentVehicleIsAnomaly: ถูกได้เงิน / เติมให้ผีธูปดับ 1 ดอก + หักเงิน
--   -> รถขี่ออกไปทาง ExitPoint แล้วเสกคันต่อไป  ครบ 500฿ = ชนะ  ธูปดับครบ 3 ดอก = แพ้
-- Phase 4: ชนิดผีทั้งหมดอยู่ใน AnomalyManager.luau (Apply ตอนเสกรถ, ResetAnomalies ตอนรถขี่ออกไป)
-- พนมมือ (Prayer.luau, 2026-10-28): ผีเห็นได้เฉพาะคนที่พนมมือ / ลูกค้าทักคนที่พนมมือ / สวดตอนร้านว่างอาจเรียกผีมาเอง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CoreLoop = {}
local backToLobby: (Player) -> ()

-- ---------------------------------------------------------------- ค่าปรับเกม
local CONFIG = {
	TargetMoney = 1500, -- (เดิม 500 จบเร็วเกิน ~5 นาที) ตอนนี้ ~15-20 นาทีต่อคืน
	Prices = { 80, 100, 120 }, -- ราคาที่ผู้เล่นตอบได้ (เงินที่ได้ = ราคาที่ตอบ) [น้ำมันหลอด]
	NormalPrice = 100, -- ไม่มีใครตอบ = ราคานี้
	-- บริการแต่ละแบบ: ตู้ไหน / ราคาให้เลือก / คำถามราคา (เติมผิดตู้ ลูกค้าท้วง)
	Services = {
		petrol = { choice = "fuel", prices = { 80, 100, 120 }, normal = 100, ask = "AskPrice" },
		diesel = { choice = "diesel", prices = { 250, 300, 350 }, normal = 300, ask = "AskPriceDiesel" },
		air = { choice = "air", prices = { 10, 20, 30 }, normal = 20, ask = "AskPriceAir" },
	},
	MaxWrongService = 2, -- เติมผิดตู้เกินนี้ ลูกค้าเลิกรอ
	-- สัดส่วนลูกค้าที่ขับมา (คนเดินแยกอีกทีด้วย WalkerChance)
	CustomerMix = {
		{ kind = "vehicle", weight = 5 }, -- มอไซค์ / ซาเล้ง (น้ำมันหลอด)
		{ kind = "car", weight = 2 }, -- กระบะ / เก๋ง (ดีเซลที่ตู้ 2)
		{ kind = "tuktuk", weight = 1.5 }, -- ตุ๊กตุ๊ก (น้ำมันหลอด)
		{ kind = "bicycle", weight = 1.5 }, -- จักรยานยางแบน เข็นมาเติมลม
	},
	DieselPumpOffset = 26, -- ตู้ดีเซลอยู่ห่างตู้ 1 ไปทางขาออกเท่านี้ (ถ้าไม่ได้วางเองใน InteractiveProps.DieselPump)
	AirStopOffset = 12, -- จุดจอดเติมลม (หน้าถังลม)
	ExpensiveRefuseChance = 0.5, -- ตอบแพง (120) ลูกค้าปกติมีโอกาสไม่เอา
	ReplyTime = 8, -- วินาทีที่เปิดให้ตอบราคา
	RejectGhostReward = 50, -- ดึงแผงปิดร้านใส่ผีได้ถูกต้อง
	GhostFuelPenalty = 100, -- เผลอเติมน้ำมันให้ผี (หักเงิน + ธูปดับ 1 ดอก)
	StartIncense = 3,
	AnomalyChance = 0.4,
	InspectLock = 4, -- วินาทีที่ล็อกปุ่มหลังรถจอด (ให้ส่องไฟฉายดู / พนมมือดู)
	DecisionTime = 35, -- ถ้าไม่มีใครตัดสินใจ ลูกค้าจะขับออกไปเอง (เผื่อเวลาพนมมือเช็กผี)
	DriveSpeed = 24, -- studs / วินาที
	GreetReplyTime = 5, -- วินาทีที่เปิดให้ทักทายตอบ
	-- จังหวะลูกค้าเป็น "ระลอก": มา 1-3 คัน -> พอร้านว่าง (ไม่มีรถเหลือ) พักตาม rest วินาที ให้ผู้เล่นเดินเล่น/สำรวจ
	-- แล้วค่อยสุ่มระลอกถัดไป (น้ำหนัก = โอกาส)
	Pacing = {
		{ kind = "single", weight = 4, count = 1, rest = { 20, 35 } }, -- มาคันเดียว พักสั้นๆ
		{ kind = "quiet", weight = 2, count = 1, rest = { 45, 70 } }, -- มาคันเดียว แล้วเงียบไปนาน
		{ kind = "pair", weight = 2, count = 2, spacing = { 1.5, 3 }, rest = { 30, 45 } }, -- มาพร้อมกัน 2 คัน
		{ kind = "rush", weight = 1, count = 3, spacing = { 3, 6 }, rest = { 40, 60 } }, -- มาต่อๆ กัน 3 คัน
	},
	FirstWaveDelay = { 10, 16 }, -- หลังเปิดร้าน
	-- ฝนตก: ลูกค้ามาน้อยลง บางคนแค่แวะหลบฝน (ไม่ซื้อ) แล้วชวนคุย
	RainPacing = {
		{ kind = "shelter", weight = 3, count = 1, rest = { 25, 40 } },
		{ kind = "single", weight = 3, count = 1, rest = { 35, 50 } },
		{ kind = "quiet", weight = 2, count = 1, rest = { 50, 75 } },
	},
	WalkerChance = 0.25, -- ลูกค้าเดินมาถือแกลลอน (ปกติ)
	WalkerChanceRain = 0.5, -- (ฝนตก) เดินกางร่มมา
	WalkSpeed = 7,
	WalkerStartDistance = 55, -- คนเดินโผล่มาห่างตู้ปั๊มเท่านี้ (ตามถนน)
	RiderUmbrellaChance = 0.8, -- ฝนตก คนขับรถกางร่ม
	MaxShelter = 2, -- คนหลบฝนพร้อมกันได้สูงสุด
	ShelterGhostChance = 0.3, -- คนหลบฝนเป็นผี (ฝนหยุดแล้วจางหายไป)
	ShelterTalkEvery = { 16, 26 }, -- คนหลบฝนชวนคุยทุกๆ (เฉพาะตอนไม่มีลูกค้า)
	ShelterSpots = { Vector3.new(9, 0, 10.5), Vector3.new(12.5, 0, 10.8) }, -- ใต้ชายคาหน้าร้าน (y หาเอง)
	-- ขาจร (ไม่ได้มาใช้บริการ) โผล่ช่วงร้านว่างระหว่างระลอก: เด็กแว้น / รถซิ่งเปิดเพลง / รถแห่งานบวช
	RoadEventChance = 0.45, -- โอกาสต่อช่วงพัก
	RoadEvents = {
		{ kind = "racer", weight = 3, rain = true },
		{ kind = "party", weight = 2, rain = false },
		{ kind = "parade", weight = 1, rain = false },
	},
	MaxQueue = 3, -- ที่ตู้ปั๊ม 1 + รอคิว 2
	QueueSpacing = 9, -- ระยะห่างคันที่รอคิว (studs)
	-- รอนานแล้วไม่พอใจ
	ImpatientAfter = { 22, 32 }, -- วินาทีหลังเปิดปุ่ม (รวมช่วงถามราคา): บ่นครั้งที่ 1, 2
	QueueAnnoyedAfter = 14, -- รอคิวนานเกินนี้ มาถึงก็บ่นเลย
	SlowPenaltyRatio = 0.2, -- เติมช้า (บ่นไปแล้ว) ลูกค้าจ่ายน้อยลง 20% (น้ำมันหลอด 100 -> 80, ดีเซล 300 -> 240, ลม 20 -> 16)
	-- ไล่ผีไปแล้วยังวิ่งตามไป: ผีหันมาหลอก ล้มตึงลงพื้น
	GhostLeaveSpeed = 8, -- ผีที่โดนไล่ขี่ออกช้าๆ (ตามทันได้)
	ChaseRadius = 9, -- เข้าใกล้ผีที่กำลังออกไปเท่านี้ = โดน
	ChaseMinFromShop = 10, -- ต้องออกมาห่างตู้ปั๊มเท่านี้ (ยืนในร้านเฉยๆ ไม่โดน)
	KnockdownTime = 4, -- นอนกองกับพื้นกี่วินาที
	RestartDelay = 20, -- ชนะแล้วรอเท่านี้ก่อนเริ่มคืนใหม่ (ให้เวลากดปุ่ม "กลับ Lobby")
	LobbyPlaceId = 70980777393906, -- ออกจากเกม = Teleport กลับวัด (Lobby, Start Place)
	-- พนมมือ
	PrayReactRadius = 30, -- ลูกค้าเห็นคนพนมมือในระยะนี้ แล้วทัก
	PrayReactMax = 2, -- ลูกค้า 1 คนทักเรื่องพนมมือได้สูงสุดกี่ครั้ง
	PrayReactAfter = 1.2, -- พนมมือนานเท่านี้ลูกค้าถึงจะสังเกต
	PrayGhostLineChance = 0.6, -- ผีตอบแบบผี (ที่เหลือแกล้งทำตัวเป็นคนปกติ)
	PraySummonAfter = 3, -- สวดตอนร้านว่างนานเท่านี้ ถึงจะสุ่มเรียกผี (1 ครั้งต่อการพนมมือ 1 รอบ)
	PraySummonChance = 0.35,
	PraySummonCooldown = 60, -- เรียกผีได้ครั้งเดียวในช่วงนี้ (ทั้งร้าน)
	PraySummonDuration = { 15, 22 }, -- ผีที่สวดเรียกมาอยู่นานเท่านี้
	PraySummonGhostNext = 0.5, -- โอกาสที่ลูกค้าคนถัดไป "ตามมา" เป็นผีแน่นอน
	PraySummonKeys = { "Anomaly_Tani", "Anomaly_Scarecrow", "Anomaly_MonkRadio" },
}

-- ---------------------------------------------------------------- ฉากและของในฉาก
local interactive = Workspace:WaitForChild("InteractiveProps")
local gasPump = interactive:WaitForChild("GasPump") :: Model
local pumpBody = gasPump:WaitForChild("GasPump") :: BasePart
local fuelLiquid = gasPump:FindFirstChild("FuelLiquid") :: BasePart?
local shutterDoor = interactive:WaitForChild("ShutterDoor") :: BasePart
local rejectRope = interactive:WaitForChild("RejectRope") :: BasePart
local spirit = Workspace:WaitForChild("SpiritHouse")
local waypoints = Workspace:WaitForChild("VehicleWaypoints")
local spawnPoint = waypoints:WaitForChild("SpawnPoint") :: BasePart
local stopPoint = waypoints:WaitForChild("StopPoint") :: BasePart
local exitPoint = waypoints:WaitForChild("ExitPoint") :: BasePart
local templates = ServerStorage:WaitForChild("VehicleTemplates")

-- ---------------------------------------------------------------- Remotes
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(name: string): RemoteEvent
	local r = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r :: RemoteEvent
end
local UpdateHUD = remote("UpdateHUD") -- (money, target, incense, maxIncense)
local TriggerJumpscare = remote("TriggerJumpscare") -- (anomalyKey)
local CustomerSpeech = remote("CustomerSpeech") -- (dialogueKey, headPart) / (nil) = ปิดคำพูด
local GameState = remote("GameState") -- ("Waiting" | "Playing" | "Win" | "Lose")
local DialogueReply = remote("DialogueReply") -- S->C ("open", options, seconds) / ("close", byName, amount)  C->S (amount)
local DeathChoice = remote("DeathChoice") -- C->S ("restart" | "quit")  S->C ("restart", byName) = มีคนกดเริ่มใหม่แล้ว

-- แพ้ (ธูปดับหมด): ผู้เล่นทุกคนล้มนอนตาย จอแดง รอให้มีคนกด "เริ่มใหม่" (ใครกดก่อนนับทั้งร้าน)
-- ล้มหงายลงพื้น (ทำฝั่ง Server ทุกคนเห็นเหมือนกัน) ยึดตัวไว้ เดินไม่ได้ จนกว่าจะเกิดใหม่
local Prayer = require(script.Parent:WaitForChild("Prayer"))
local function collapse(player: Player)
	Prayer.Stop(player) -- ล้มแล้วเลิกพนมมือ
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.AutoRotate = false
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	local groundY = if hit then hit.Position.Y else root.Position.Y - 3
	local look = root.CFrame.LookVector
	local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(look.X, 0, look.Z))
	local lying = CFrame.new(root.Position.X, groundY + 0.6, root.Position.Z) * yaw * CFrame.Angles(math.rad(85), 0, 0)
	root.Anchored = true
	TweenService:Create(root, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = lying }):Play()
end

-- ล้มตึงชั่วคราว แล้วลุกขึ้นมาเล่นต่อ (ตามผีไป)
local function knockDown(player: Player, seconds: number)
	collapse(player)
	task.delay(seconds, function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum) or not root.Anchored then
			return
		end
		local p = root.Position
		local look = Vector3.yAxis:Cross(root.CFrame.RightVector) -- ทิศหน้าเดิม (แกนขวาไม่เปลี่ยนตอนล้มหงาย)
		root.CFrame = CFrame.lookAt(p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0) + Vector3.new(look.X, 0, look.Z))
		root.Anchored = false
		local sp = game:GetService("StarterPlayer")
		hum.WalkSpeed = sp.CharacterWalkSpeed
		hum.JumpPower = sp.CharacterJumpPower
		hum.JumpHeight = sp.CharacterJumpHeight
		hum.AutoRotate = true
	end)
end
-- ออกจากเกม: Teleport กลับ Lobby (ใน Studio Teleport ไม่ได้ / Teleport พลาด -> Kick พร้อมข้อความลาแทน)
local leaving: { [Player]: boolean } = {}
local function kickGoodbye(player: Player)
	local th = player:GetAttribute("Lang") == "th"
	player:Kick(if th then "ขอบคุณที่มาเฝ้าปั๊มหลอดท้ายทุ่ง... แล้วพบกันใหม่คืนหน้า" else "Thanks for minding the roadside pump... see you next night.")
end
function backToLobby(player: Player)
	if leaving[player] then
		return
	end
	leaving[player] = true
	if RunService:IsStudio() then
		print("🏯 [" .. player.Name .. "] กลับ Lobby (Studio Teleport ไม่ได้ -> Kick แทน)")
		kickGoodbye(player)
		return
	end
	print("🏯 [" .. player.Name .. "] กลับ Lobby")
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(CONFIG.LobbyPlaceId, { player })
	end)
	if not ok then
		warn("[CoreLoop] Teleport กลับ Lobby ไม่ได้:", err)
		leaving[player] = nil
		kickGoodbye(player)
	end
end
TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
	if leaving[player] then
		warn("[CoreLoop] Teleport กลับ Lobby ล้มเหลว:", result, msg)
		leaving[player] = nil
		kickGoodbye(player)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	leaving[p] = nil
end)

local losePending = false
local restartBy: string? = nil
DeathChoice.OnServerEvent:Connect(function(player, choice: any)
	if choice == "restart" and losePending and not restartBy then
		restartBy = player.DisplayName
		DeathChoice:FireAllClients("restart", player.DisplayName)
		print("🔁 [" .. player.Name .. "] เลือกเริ่มใหม่")
	elseif choice == "quit" then
		backToLobby(player)
	end
end)

-- ---------------------------------------------------------------- ปุ่มกด (ProximityPrompt)
local function setupPrompt(name: string, parent: Instance, hold: number, action: string, object: string): ProximityPrompt
	local p = parent:FindFirstChild(name, true) :: ProximityPrompt?
	if not (p and p:IsA("ProximityPrompt")) then
		p = Instance.new("ProximityPrompt")
		p.Name = name
		p.Parent = parent
	end
	local prompt = p :: ProximityPrompt
	prompt.HoldDuration = hold
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.AutoLocalize = false
	prompt.Enabled = false
	return prompt
end
-- ทิศถนน (จากจุดเกิดรถ -> ขาออก)
local ROAD_DIR = Vector3.new(stopPoint.Position.X - spawnPoint.Position.X, 0, stopPoint.Position.Z - spawnPoint.Position.Z).Unit

-- ตู้ 2: ดีเซล (น้ำมันสีเขียว) สำหรับรถยนต์ — ใช้ InteractiveProps.DieselPump ถ้าวางไว้เอง ไม่งั้น Clone ตู้ 1 ไปวางถัดไป
local dieselPump = interactive:FindFirstChild("DieselPump") :: Model?
if not dieselPump then
	local c = gasPump:Clone()
	c.Name = "DieselPump"
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local piv = gasPump:GetPivot()
	c:PivotTo(piv + ROAD_DIR * CONFIG.DieselPumpOffset)
	c.Parent = interactive
	dieselPump = c
end
local dieselBody = (dieselPump :: Model):FindFirstChild("GasPump") :: BasePart
local dieselLiquid = (dieselPump :: Model):FindFirstChild("FuelLiquid") :: BasePart?
if dieselLiquid then
	dieselLiquid.Color = Color3.fromRGB(70, 150, 60)
	local sa = dieselLiquid:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		(sa :: any).Color = Color3.fromRGB(110, 210, 90)
	end
end
-- ถังลม (เติมลมยาง)
local airCompressor = Workspace:FindFirstChild("AirCompressor") or interactive:FindFirstChild("AirCompressor")
local airBody: BasePart? = nil
if airCompressor then
	local best = 0
	for _, d in ipairs(airCompressor:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.Magnitude > best then
			best = d.Size.Magnitude
			airBody = d
		end
	end
end
local airHiss = Instance.new("Sound")
airHiss.Name = "AirHiss"
airHiss.SoundId = "rbxassetid://9116496074"
airHiss.Volume = 0.8
airHiss.RollOffMaxDistance = 60
airHiss.Parent = airBody or pumpBody

local pumpPrompt = setupPrompt("PumpFuelPrompt", pumpBody, 3, "Fill Up", "Gas Pump")
local dieselPrompt = setupPrompt("DieselFuelPrompt", dieselBody, 3, "Fill Diesel", "Diesel Pump")
local airPrompt = setupPrompt("AirPumpPrompt", airBody or pumpBody, 2, "Pump Air", "Air Compressor") -- ข้อความจริงตามภาษาผู้เล่นตั้งฝั่ง Client (HUDController)
local rejectPrompt = setupPrompt("RejectCustomerPrompt", rejectRope, 0.5, "Close Shop!", "Shutter Rope")
local openPrompt = setupPrompt("OpenShopPrompt", rejectRope, 1, "Open Shop", "Shutter Rope") -- ก่อนเริ่มคืน

-- ---------------------------------------------------------------- สถานะเกม
local money = 0
local incense = CONFIG.StartIncense
local gameOver = false
local currentVehicle: Model? = nil
local currentVehicleIsAnomaly = false
local currentAnomaly: string? = nil
local decision: string? = nil -- "fuel" | "reject" | nil
local decisionMade = Instance.new("BindableEvent")

local function publishState()
	remotes:SetAttribute("Money", money)
	remotes:SetAttribute("Incense", incense)
	remotes:SetAttribute("IsAnomaly", currentVehicleIsAnomaly)
	remotes:SetAttribute("Anomaly", currentAnomaly or "")
	remotes:SetAttribute("GameOver", gameOver)
end

local function broadcastHUD(player: Player?)
	if player then
		UpdateHUD:FireClient(player, money, CONFIG.TargetMoney, incense, CONFIG.StartIncense)
	else
		UpdateHUD:FireAllClients(money, CONFIG.TargetMoney, incense, CONFIG.StartIncense)
	end
	publishState()
	local tin = interactive:FindFirstChild("MoneyTin")
	if tin then
		tin:SetAttribute("Money", money)
	end
end
Players.PlayerAdded:Connect(function(p)
	task.wait(2)
	broadcastHUD(p)
end)

-- ธูป: ดอกที่ i ติดอยู่ถ้า i <= incense
local function refreshIncense()
	for i = 1, CONFIG.StartIncense do
		local lit = i <= incense
		local tip = spirit:FindFirstChild("Incense" .. i .. "_Neon") :: BasePart?
		if tip then
			tip.Material = if lit then Enum.Material.Neon else Enum.Material.Slate
			tip.Color = if lit then Color3.fromRGB(255, 90, 30) else Color3.fromRGB(40, 36, 34)
			for _, e in ipairs(tip:GetDescendants()) do
				if e:IsA("ParticleEmitter") then
					e.Enabled = lit
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- ผี (Phase 4: อยู่ใน AnomalyManager.luau)
local AnomalyManager = require(script.Parent:WaitForChild("AnomalyManager"))
local Pedestrian = require(script.Parent:WaitForChild("Pedestrian"))
local Weather = require(script.Parent:WaitForChild("Weather"))
local AnomalyBook = require(script.Parent:WaitForChild("AnomalyBook"))
local LeaderboardStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardStats"))
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local function pick(list: { any }): any
	return list[math.random(#list)]
end

-- ลูกค้าประจำ (ชื่อ / คำทัก / คำสั่งน้ำมัน) ผีจะปลอมเป็นหนึ่งในนี้
local CHARACTERS = {
	{ name = "Name_Sommai", greet = "Greet_Uncle", order = "Normal_Uncle", voice = "M" },
	{ name = "Name_Chaem", greet = "Greet_Aunt", order = "Normal_Aunt", voice = "F" },
	{ name = "Name_Ton", greet = "Greet_Student", order = "Normal_Student", voice = "M" },
	{ name = "Name_Boonmee", greet = "Greet_Farmer", order = "Normal_Farmer", voice = "M" },
}
-- ประโยคผีที่ใช้คำแทนตัวเฉพาะเพศ ต้องให้ลูกค้าเพศเดียวกันพูด (ไม่อยู่ในตาราง = ใครพูดก็ได้)
local ANOMALY_VOICE: { [string]: string } = {
	Anomaly_Krasue = "F", -- "ป้า"
	Anomaly_Cemetery = "F", -- "จ้ะ"
	Anomaly_Headless = "M", -- "ผม"
	Anomaly_NeckTwist = "M",
	Anomaly_MonkRadio = "M",
	Anomaly_Scarecrow = "M",
}
-- คนแวะหลบฝน (ชื่อไม่ซ้ำกับลูกค้าประจำ จะได้ไม่สับสนตอนคุยกัน)
local SHELTER_CHARACTERS = {
	{ name = "Name_Prik", voice = "F" },
	{ name = "Name_Daeng", voice = "M" },
	{ name = "Name_Noi", voice = "F" },
}
local namesInUse: () -> { [string]: boolean }
local function pickCharacter(voice: string?, list: { any }?)
	local src = list or CHARACTERS
	local used = if namesInUse then namesInUse() else {}
	local pool, fallback = {}, {}
	for _, c in ipairs(src) do
		if voice == nil or c.voice == voice then
			table.insert(fallback, c)
			if not used[c.name] then
				table.insert(pool, c)
			end
		end
	end
	if #pool > 0 then
		return pick(pool)
	end
	return pick(if #fallback > 0 then fallback else src)
end

-- ---------------------------------------------------------------- การขี่รถ
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }

local function groundAt(p: Vector3): number
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 40, p.Z), Vector3.new(0, -80, 0), groundParams)
	return if hit then hit.Position.Y else p.Y
end

local function wheelsOf(v: Model): { BasePart }
	local list = {}
	for _, n in ipairs({ "FrontWheel", "RearWheel", "SidecarWheel" }) do
		local w = v:FindFirstChild(n)
		if w and w:IsA("BasePart") then
			table.insert(list, w)
		end
	end
	return list
end

-- เลื่อนรถไปยังจุดหมาย (หน้ารถ = -Z ของ pivot) ล้อหมุน รถเกาะพื้นดิน ชะลอตอนใกล้ถึงถ้า brake = true
local function driveTo(v: Model, target: Vector3, brake: boolean, speedOverride: number?)
	local wheels = wheelsOf(v)
	local done = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if not v.Parent then
			done = true
			conn:Disconnect()
			return
		end
		local pos = v:GetPivot().Position
		local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
		local dist = flat.Magnitude
		local speed = speedOverride or CONFIG.DriveSpeed
		if brake then
			speed = math.max(3, math.min(speed, dist * 1.6))
		end
		local step = math.min(dist, speed * dt)
		if dist < 0.15 then
			done = true
			conn:Disconnect()
			return
		end
		local dir = flat.Unit
		local nextPos = pos + dir * step
		nextPos = Vector3.new(nextPos.X, groundAt(nextPos), nextPos.Z)
		v:PivotTo(CFrame.lookAt(nextPos, nextPos + dir))
		-- ล้อหมุนรอบแกนขวางของรถ
		local right = v:GetPivot().RightVector
		local angle = -step / 1.03
		for _, w in ipairs(wheels) do
			local c = w.Position
			w.CFrame = CFrame.new(c) * CFrame.fromAxisAngle(right, angle) * (w.CFrame - c)
		end
	end)
	while not done do
		task.wait()
	end
end

-- ---------------------------------------------------------------- ฉากประกอบ (แผงสังกะสี, น้ำมันในหลอดแก้ว)
local shutterOpenY = shutterDoor.Position.Y
local shutterDrop = (shutterDoor:GetAttribute("OpenY") or 15.5) - (shutterDoor:GetAttribute("ClosedY") or 6)

local function closeShutter()
	SoundBank.PlayOneShot("ShutterCloseSlam", shutterDoor, 75, 2.0)
	local p = shutterDoor.Position
	local t = TweenService:Create(shutterDoor, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = Vector3.new(p.X, shutterOpenY - shutterDrop, p.Z),
	})
	t:Play()
	t.Completed:Wait()
end

local function openShutter()
	SoundBank.PlayOneShot("ShutterOpenPull", shutterDoor, 65, 1.5)
	local p = shutterDoor.Position
	local t = TweenService:Create(shutterDoor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = Vector3.new(p.X, shutterOpenY, p.Z),
	})
	t:Play()
	t.Completed:Wait()
end

local fuelFull = fuelLiquid and fuelLiquid.Size
local fuelBottom = fuelLiquid and (fuelLiquid.Position.Y - fuelLiquid.Size.Y / 2)
local function setFuelLevel(frac: number, time: number)
	if not (fuelLiquid and fuelFull and fuelBottom) then
		return
	end
	local h = math.max(0.05, fuelFull.Y * frac)
	local p = fuelLiquid.Position
	local goal = {
		Size = Vector3.new(fuelFull.X, h, fuelFull.Z),
		Position = Vector3.new(p.X, fuelBottom + h / 2, p.Z),
	}
	local t = TweenService:Create(fuelLiquid, TweenInfo.new(time, Enum.EasingStyle.Sine), goal)
	t:Play()
	-- น้ำมันเลือด (ผี Anomaly_BloodFuel เห็นเฉพาะตอนพนมมือ) ลดระดับตามน้ำมันจริง
	local blood = gasPump:FindFirstChild("BloodFuel")
	if blood and blood:IsA("BasePart") then
		TweenService:Create(blood, TweenInfo.new(time, Enum.EasingStyle.Sine), goal):Play()
	end
	return t
end

-- น้ำมันในหลอดตู้ดีเซล (เหมือน setFuelLevel แต่ตู้ 2)
local dieselFull = dieselLiquid and dieselLiquid.Size
local dieselBottom = dieselLiquid and (dieselLiquid.Position.Y - dieselLiquid.Size.Y / 2)
local function setDieselLevel(frac: number, time: number)
	if not (dieselLiquid and dieselFull and dieselBottom) then
		return nil
	end
	local h = math.max(0.05, dieselFull.Y * frac)
	local p = dieselLiquid.Position
	local t = TweenService:Create(dieselLiquid, TweenInfo.new(time, Enum.EasingStyle.Sine), {
		Size = Vector3.new(dieselFull.X, h, dieselFull.Z),
		Position = Vector3.new(p.X, dieselBottom + h / 2, p.Z),
	})
	t:Play()
	return t
end

-- ---------------------------------------------------------------- การตัดสินใจของผู้เล่น
-- ใช้ได้ทั้งจาก ProximityPrompt และจากการทดสอบ (require(ServerScriptService.Server.CoreLoop).Decide("fuel"))
-- ปุ่มบริการทั้งหมดเปิด/ปิดพร้อมกัน (เลือกผิดตู้ได้ ลูกค้าจะท้วง)
local servicePromptsOpen = false
local function setServicePrompts(on: boolean)
	servicePromptsOpen = on
	pumpPrompt.Enabled = on
	dieselPrompt.Enabled = on
	airPrompt.Enabled = on
	rejectPrompt.Enabled = on
end

local DECIDE_TEXT = { fuel = "⛽ เติมน้ำมันหลอด", diesel = "🛢️ เติมดีเซล", air = "🛞 เติมลม", reject = "🚧 ดึงแผงปิดร้าน!" }
function CoreLoop.Decide(choice: string, who: string?): boolean
	if decision or not currentVehicle or gameOver or not servicePromptsOpen then
		return false
	end
	decision = choice
	setServicePrompts(false)
	print("[" .. (who or "?") .. "] " .. (DECIDE_TEXT[choice] or choice))
	decisionMade:Fire()
	return true
end

pumpPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("fuel", player.Name)
end)
dieselPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("diesel", player.Name)
end)
airPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("air", player.Name)
end)

rejectPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("reject", player.Name)
end)

-- ทดสอบจาก Command Bar / เครื่องมือ: ServerStorage.DevDecision:Fire("fuel" | "reject")
-- (require โมดูลนี้จาก Command Bar จะได้สำเนาใหม่คนละตัวกับที่เกมใช้ จึงต้องสั่งผ่าน BindableEvent)
local devDecision = ServerStorage:FindFirstChild("DevDecision") or Instance.new("BindableEvent")
devDecision.Name = "DevDecision"
devDecision.Parent = ServerStorage
local chooseReply: (string, string, string?) -> boolean
local devSpawn: (string) -> ()
local devRoadEvent: (string) -> ()
local shopOpened = false
devDecision.Event:Connect(function(choice: string)
	-- "fuel" | "reject" | "reply:100" | "open"
	local amount = string.match(choice, "^reply:(%w+)$") -- reply:100 / reply:hello / reply:both
	if amount then
		chooseReply(amount, "DevDecision")
	elseif choice == "open" then
		shopOpened = true
	elseif choice == "spawn" then
		devSpawn("vehicle") -- เสกลูกค้าเพิ่ม 1 คันทันที (ทดสอบคิว)
	elseif choice == "walker" or choice == "car" or choice == "tuktuk" or choice == "bicycle" then
		devSpawn(choice) -- ลูกค้าแต่ละแบบ
	elseif choice == "racer" or choice == "party" or choice == "parade" then
		devRoadEvent(choice) -- ขาจรบนถนน
	elseif choice == "shelter" then
		devSpawn("shelter") -- คนมาหลบฝน
	elseif string.sub(choice, 1, 5) == "book:" then
		AnomalyBook.Survived(string.sub(choice, 6)) -- ทดสอบปลดล็อกสมุด
	elseif choice == "bookreset" then
		AnomalyBook.Reset()
	elseif choice == "rain" or choice == "clear" then
		Weather.Set(choice == "rain")
	elseif choice == "incense1" then
		incense = 1 -- ทดสอบ: เหลือธูปดอกสุดท้าย
		refreshIncense()
		broadcastHUD()
	elseif choice == "lose" then
		incense = 0 -- ทดสอบฉากตาย: คันถัดไปจบเกม (หรือทันทีถ้าไม่มีลูกค้า)
		refreshIncense()
		broadcastHUD()
	elseif choice == "restart" then
		if losePending and not restartBy then
			restartBy = "DevDecision"
			DeathChoice:FireAllClients("restart", "DevDecision")
		end
	else
		CoreLoop.Decide(choice, "DevDecision")
	end
end)
-- ทดสอบผีเฉพาะตัว: ServerStorage.DevDecision:SetAttribute("ForceAnomaly", "Anomaly_Krasue") -> ลูกค้าคันถัดไปเป็นผีนี้
-- ("Normal" = บังคับลูกค้าปกติ)

-- สถานะสำหรับทดสอบ
function CoreLoop.State()
	return {
		money = money,
		incense = incense,
		gameOver = gameOver,
		hasCustomer = currentVehicle ~= nil,
		isAnomaly = currentVehicleIsAnomaly,
		anomaly = currentAnomaly,
		promptsOpen = servicePromptsOpen,
	}
end

local function waitDecision(timeout: number): string?
	if decision then
		return decision
	end
	local fired = false
	local conn = decisionMade.Event:Connect(function()
		fired = true
	end)
	local t0 = os.clock()
	while not fired and os.clock() - t0 < timeout and not gameOver do
		task.wait(0.1)
	end
	conn:Disconnect()
	return decision
end

-- ---------------------------------------------------------------- บทสนทนา
-- speaker = { name = "Name_Sommai" } (ลูกค้า แปลชื่อฝั่ง Client) หรือ { player = "DisplayName" } (ผู้เล่นที่ตอบ)
local currentHead: BasePart? = nil
local speechBusyUntil = 0 -- ลูกค้ากำลังพูดถึงเมื่อไหร่ (คำทักเรื่องพนมมือรอให้พูดจบก่อน)
local function getHead(m: Instance?): BasePart?
	if not m then
		return nil
	end
	local drv = m:FindFirstChild("DriverNPC")
	local h = (drv and drv:FindFirstChild("Head")) or m:FindFirstChild("Head", true)
	if h and h:IsA("BasePart") then
		return h
	end
	if m:IsA("Model") and m.PrimaryPart then
		return m.PrimaryPart
	end
	return m:FindFirstChildWhichIsA("BasePart", true)
end
local function say(key: string, speaker: { [string]: any }, vars: { [string]: any }?, hold: number?, headOverride: BasePart?)
	CustomerSpeech:FireAllClients(key, headOverride or currentHead, speaker, vars)
	speechBusyUntil = os.clock() + (hold or 2.4)
	if hold then
		task.wait(hold)
	end
end

-- ตัวเลือกตอบ: ทุกคนเห็นเหมือนกัน ใครตอบก่อนนับเป็นคำตอบของทั้งร้าน
-- options = { { id = "100", key = "Reply_100" }, ... }  Client ส่ง id กลับมา
local replyOpen = false
local replyOptions: { { id: string, key: string } } = {}
local replyId: string? = nil
local replyBy: string? = nil
local replyGender: string = "M"
function chooseReply(id: string, who: string, gender: string?): boolean
	if not replyOpen then
		return false
	end
	for _, o in ipairs(replyOptions) do
		if o.id == id then
			replyOpen = false
			replyId = id
			replyBy = who
			replyGender = gender or "M"
			DialogueReply:FireAllClients("close", who, id)
			return true
		end
	end
	return false
end
DialogueReply.OnServerEvent:Connect(function(player, id: any)
	if type(id) == "string" or type(id) == "number" then
		chooseReply(tostring(id), player.DisplayName, SoundBank.DetectPlayerGender(player))
	end
end)

local function askReply(options: { { id: string, key: string } }, seconds: number): string?
	replyId, replyBy = nil, nil
	replyOptions = options
	replyOpen = true
	DialogueReply:FireAllClients("open", options, seconds)
	local t0 = os.clock()
	while replyOpen and os.clock() - t0 < seconds and not decision and not gameOver do
		task.wait(0.1)
	end
	if replyOpen then
		replyOpen = false
		DialogueReply:FireAllClients("close", nil, nil)
	end
	return replyId
end

local PRICE_OPTIONS = {}
for _, p in ipairs(CONFIG.Prices) do
	table.insert(PRICE_OPTIONS, { id = tostring(p), key = "Reply_" .. p })
end
local GREET_OPTIONS = {
	{ id = "hello", key = "Reply_Hello" },
	{ id = "both", key = "Reply_GreetBoth" },
}

-- ---------------------------------------------------------------- ลูกค้า + คิว
type Customer = {
	v: Model,
	kind: string, -- "vehicle" | "walker" | "car" | "tuktuk" | "bicycle"
	order: string, -- คีย์ประโยคสั่งน้ำมัน
	service: string, -- "petrol" | "diesel" | "air"
	length: number, -- ความยาวตัวรถ (เว้นระยะคิว)
	ghost: boolean,
	anomaly: string?,
	deferredWorld: string?, -- ผีที่แตะฉาก ใส่ตอนถึงตู้ปั๊ม
	who: any,
	useAnomalyLine: boolean,
	spawnedAt: number,
	queuedSince: number?, -- เริ่มรอคิว (มาถึงช่องรอแล้วแต่ยังไม่ถึงตู้)
	atPump: boolean,
	serving: boolean,
}
local queue: { Customer } = {}
local forceGhostNext = false -- สวดตอนร้านว่างแล้วเรียกของมา: ลูกค้าคนถัดไปเป็นผี

local function pickTemplate(): Model
	local bike = templates:FindFirstChild("CustomerBike") :: Model
	local saleng = templates:FindFirstChild("Saleng") :: Model?
	if saleng and math.random() < 0.3 then
		return saleng
	end
	return bike
end

-- ช่องจอด: 1 = StopPoint (ตู้ปั๊ม), 2..n = ถอยหลังไปทางที่รถมา
local function slotPos(i: number): Vector3
	local stop = stopPoint.Position
	local back = Vector3.new(spawnPoint.Position.X - stop.X, 0, spawnPoint.Position.Z - stop.Z).Unit
	-- เว้นตามความยาวรถแต่ละคัน (รถยนต์ยาวกว่ามอไซค์มาก)
	local dist = 0
	for j = 2, i do
		local a = queue[j - 1]
		local b = queue[j]
		local la = if a then a.length else CONFIG.QueueSpacing
		local lb = if b then b.length else CONFIG.QueueSpacing
		dist += math.max(CONFIG.QueueSpacing, (la + lb) / 2 + 2)
	end
	local p = stop + back * dist
	return Vector3.new(p.X, groundAt(p), p.Z)
end

-- จุดที่คันหน้าสุดไปจอดรับบริการ: น้ำมันหลอด = StopPoint, ดีเซล = หน้าตู้ 2, เติมลม = หน้าถังลม
local function serviceTarget(service: string): Vector3
	local stop = stopPoint.Position
	local p = stop
	if service == "diesel" then
		p = stop + ROAD_DIR * CONFIG.DieselPumpOffset
	elseif service == "air" then
		p = stop + ROAD_DIR * CONFIG.AirStopOffset
	end
	return Vector3.new(p.X, groundAt(p), p.Z)
end

-- คนเดินมาซื้อน้ำมันใส่แกลลอน: บอกว่าจะเอาไปเติมอะไร
local WALKER_ORDERS = { "Walker_Order_1", "Walker_Order_2", "Walker_Order_3", "Walker_Order_4" }
local WALKER_ORDERS_RAIN = { "Walker_Order_Rain_1", "Walker_Order_Rain_2" }

local function backDir(): Vector3
	local stop = stopPoint.Position
	return Vector3.new(spawnPoint.Position.X - stop.X, 0, spawnPoint.Position.Z - stop.Z).Unit
end

-- ---------------------------------------------------------------- รถไทย (แม่แบบจาก MapBuilder.BuildThaiVehicleTemplates)
local CAR_TEMPLATES = { "ThaiPickupOld", "ThaiSedanSoluna" }
local BICYCLE_TEMPLATES = { "ThaiBicycleRed", "ThaiBicycleBlue" }
local CAR_ORDERS = { "Car_Order_1", "Car_Order_2", "Car_Order_3" }
local TUKTUK_ORDERS = { "TukTuk_Order_1", "TukTuk_Order_2" }
local BICYCLE_ORDERS = { "Bicycle_Order_1", "Bicycle_Order_2" }

-- เตรียมรถไทยให้เป็นรถลูกค้า: ยึดทุกชิ้น (ขยับด้วย PivotTo เหมือนรถเดิม) ปิดเบาะไม่ให้ผู้เล่นนั่ง เปิดไฟหน้า
local function prepThaiVehicle(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			(d :: any).Disabled = true
		end
		if d:IsA("Constraint") or d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then
			d:Destroy()
		end
	end
	local lights = m:FindFirstChild("Lights")
	if lights then
		for _, d in ipairs(lights:GetDescendants()) do
			if d:IsA("Light") then
				d.Enabled = true
			elseif d:IsA("BasePart") then
				d.Material = Enum.Material.Neon
			end
		end
	end
end

-- คนขับนั่งเบาะคนขับ: ใช้คนขับจากมอไซค์แม่แบบ (ท่านั่ง) วางสะโพกลงบนเบาะ
local function seatDriver(m: Model): Model?
	local seat = m:FindFirstChild("DriverSeat") :: BasePart?
	local bike = templates:FindFirstChild("CustomerBike") :: Model?
	local src = bike and bike:FindFirstChild("DriverNPC") :: Model?
	if not (seat and bike and src) then
		return nil
	end
	local drv = src:Clone()
	local bikePiv = bike:GetPivot()
	local hipLocal = CFrame.new(0, 2.95, 0.38) -- สะโพกคนขับเทียบ pivot มอไซค์
	local rot = m:GetPivot() - m:GetPivot().Position
	local seatTop = CFrame.new(seat.Position + Vector3.new(0, seat.Size.Y / 2, 0)) * rot
	for _, d in ipairs(drv:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame = seatTop * hipLocal:Inverse() * bikePiv:ToObjectSpace(d.CFrame)
		end
	end
	drv.Parent = m
	return drv
end

local function templateOrNil(name: string): Model?
	local t = templates:FindFirstChild(name)
	return if t and t:IsA("Model") then t else nil
end

-- สุ่มชนิดลูกค้าที่ขับมา (ถ้าแม่แบบรถไทยไม่มี ใช้มอไซค์แทน)
local function pickKind(): string
	local total = 0
	for _, k in ipairs(CONFIG.CustomerMix) do
		total += k.weight
	end
	local r = math.random() * total
	local kind = "vehicle"
	for _, k in ipairs(CONFIG.CustomerMix) do
		r -= k.weight
		if r <= 0 then
			kind = k.kind
			break
		end
	end
	if kind == "car" and not templateOrNil(CAR_TEMPLATES[1]) then
		return "vehicle"
	elseif kind == "tuktuk" and not templateOrNil("ThaiTukTuk") then
		return "vehicle"
	elseif kind == "bicycle" and not templateOrNil(BICYCLE_TEMPLATES[1]) then
		return "vehicle"
	end
	return kind
end

local function spawnCustomer(kind: string?)
	local raining = Weather.IsRaining()
	if not kind then
		kind = if math.random() < (if raining then CONFIG.WalkerChanceRain else CONFIG.WalkerChance) then "walker" else pickKind()
	end
	local k = kind :: string
	local walking = k == "walker" or k == "bicycle"
	local forced = devDecision:GetAttribute("ForceAnomaly")
	devDecision:SetAttribute("ForceAnomaly", nil)
	local ghost
	if forced == "Normal" then
		ghost = false
	elseif type(forced) == "string" and AnomalyManager.Anomalies[forced] then
		ghost = true
	else
		forced = nil
		ghost = forceGhostNext or math.random() < CONFIG.AnomalyChance
	end
	forceGhostNext = false

	local v: Model
	local service = "petrol"
	if k == "walker" then
		v = Pedestrian.Build({ umbrella = raining, gallon = true })
	elseif k == "bicycle" then
		-- จักรยานยางแบน: คนเดินเข็นจักรยานมาด้วย (จักรยานอยู่ข้างขวา)
		v = Pedestrian.Build({ umbrella = raining, gallon = false })
		local bt = templateOrNil(pick(BICYCLE_TEMPLATES)) :: Model
		local bike = bt:Clone()
		prepThaiVehicle(bike)
		bike:PivotTo(v:GetPivot() * CFrame.new(2.1, 0, -0.4))
		bike.Name = "PushedBicycle"
		bike.Parent = v
		service = "air"
	elseif k == "car" or k == "tuktuk" then
		local tname = if k == "car" then pick(CAR_TEMPLATES) else "ThaiTukTuk"
		v = (templateOrNil(tname) :: Model):Clone()
		prepThaiVehicle(v)
		seatDriver(v)
		service = if k == "car" then "diesel" else "petrol"
	else
		v = pickTemplate():Clone()
		if raining and math.random() < CONFIG.RiderUmbrellaChance then
			Pedestrian.AddRiderUmbrella(v)
		end
	end
	local length = if walking then (if k == "bicycle" then 6 else 4) else (v :: Model):GetExtentsSize().Z

	local anomaly: string? = nil
	local deferred: string? = nil
	if ghost then
		local anomalyKind = if k == "vehicle" then "vehicle" elseif walking then "walker" else "car"
		anomaly = if forced then forced else AnomalyManager.RandomFor(anomalyKind, raining)
		if AnomalyManager.IsWorld(anomaly :: string) then
			deferred = anomaly
		else
			AnomalyManager.Apply(anomaly :: string, v)
		end
	end
	local useAnomalyLine = ghost and math.random() < 0.6
	local who = pickCharacter(if useAnomalyLine then ANOMALY_VOICE[anomaly :: string] else nil)
	local order = who.order
	if k == "walker" then
		order = pick(if raining then WALKER_ORDERS_RAIN else WALKER_ORDERS)
	elseif k == "car" then
		order = pick(CAR_ORDERS)
	elseif k == "tuktuk" then
		order = pick(TUKTUK_ORDERS)
	elseif k == "bicycle" then
		order = pick(BICYCLE_ORDERS)
	end
	local c: Customer = {
		v = v,
		kind = k,
		order = order,
		service = service,
		length = length,
		ghost = ghost,
		anomaly = anomaly,
		deferredWorld = deferred,
		who = who,
		useAnomalyLine = useAnomalyLine,
		spawnedAt = os.clock(),
		queuedSince = nil,
		atPump = false,
		serving = false,
	}
	v:SetAttribute("IsAnomaly", ghost)
	v:SetAttribute("AnomalyKey", anomaly or "")
	v:SetAttribute("Kind", k)
	local start = if walking then stopPoint.Position + backDir() * CONFIG.WalkerStartDistance else spawnPoint.Position
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, Vector3.new(stopPoint.Position.X, start.Y, stopPoint.Position.Z)))
	v.Name = "Customer"
	v.Parent = Workspace
	-- เสียงเครื่องยนต์รถลูกค้าเดินเบาทุ้มๆ ไม่แสบหู (เล่นเฉพาะเมื่ออัปโหลดไฟล์ .wav เข้า UploadedSounds แล้ว ไม่ใช้เสียงเบิ้ลตัดสำรอง)
	if not walking then
		local engPart = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
		local engPresetName = if k == "car" then "DieselIdle" else "MotoIdle"
		local engPreset = SoundBank.Presets[engPresetName]
		if engPart and engPreset then
			local _, isCustom = SoundBank.ResolveId(engPreset)
			if isCustom then
				local engSnd = SoundBank.CreateSound(engPresetName, engPart, 70)
				if engSnd then
					engSnd:Play()
				end
			end
		end
	end
	table.insert(queue, c)
	print("🛵 ลูกค้ามา [" .. k .. "/" .. service .. "] (" .. (if ghost then "ผี " .. tostring(anomaly) else "ปกติ") .. ") คิว " .. #queue)

	-- ไปช่องของตัวเอง แล้วเลื่อนขึ้นเรื่อยๆ จนถึงจุดรับบริการ (คันหน้าสุด: ตู้ 1 / ตู้ดีเซล / ถังลม)
	task.spawn(function()
		while v.Parent and not c.serving and not gameOver do
			local idx = table.find(queue, c)
			if not idx then
				return
			end
			local target = if idx == 1 then serviceTarget(service) else slotPos(idx)
			local flat = Vector3.new(target.X - v:GetPivot().Position.X, 0, target.Z - v:GetPivot().Position.Z)
			if flat.Magnitude > 0.5 then
				if walking then
					Pedestrian.WalkTo(v, target, CONFIG.WalkSpeed)
					Pedestrian.Face(v, if service == "air" and airBody then airBody.Position else pumpBody.Position)
				else
					driveTo(v, target, true)
				end
			else
				if idx == 1 then
					c.atPump = true
				elseif not c.queuedSince then
					c.queuedSince = os.clock()
				end
				task.wait(0.2)
			end
		end
	end)
end

-- ---------------------------------------------------------------- คนแวะหลบฝน (ไม่ซื้อ ไม่ต้องตัดสินใจ แค่ชวนคุย)
type Shelter = { v: Model, who: any, ghost: boolean, spot: number, arrived: boolean, leaving: boolean }
local shelters: { Shelter } = {}
local customerTalking = false -- ลูกค้าที่ตู้กำลังคุยอยู่ (คนหลบฝนรอจังหวะ)

local SHELTER_TALK = { "ShelterTalk_1", "ShelterTalk_2", "ShelterTalk_3", "ShelterTalk_4", "ShelterTalk_5" }
local SHELTER_GHOST_TALK = { "ShelterGhostTalk_1", "ShelterGhostTalk_2", "ShelterGhostTalk_3" }

local function freeSpot(): number?
	for i = 1, #CONFIG.ShelterSpots do
		local used = false
		for _, sh in ipairs(shelters) do
			if sh.spot == i then
				used = true
			end
		end
		if not used then
			return i
		end
	end
	return nil
end

local shelterSpeaking = false -- กันคนหลบฝน 2 คนพูดทับกัน
local function shelterSay(sh: Shelter, key: string, hold: number)
	if customerTalking or replyOpen or shelterSpeaking then
		return false
	end
	shelterSpeaking = true
	CustomerSpeech:FireAllClients(key, getHead(sh.v), { name = sh.who.name, voice = sh.who.voice, ghost = sh.ghost }, nil)
	task.wait(hold)
	if not customerTalking and not replyOpen then
		CustomerSpeech:FireAllClients(nil)
	end
	shelterSpeaking = false
	return true
end

-- ชื่อที่อยู่ในร้านตอนนี้ (ลูกค้าในคิว + คนหลบฝน) ไม่สุ่มซ้ำ
function namesInUse()
	local used = {}
	for _, c in ipairs(queue) do
		used[c.who.name] = true
	end
	for _, sh in ipairs(shelters) do
		used[sh.who.name] = true
	end
	return used
end

local function spawnShelter()
	local spot = freeSpot()
	if not spot then
		return
	end
	local ghost = math.random() < CONFIG.ShelterGhostChance
	local v = Pedestrian.Build({ umbrella = true, gallon = false })
	local sh: Shelter = { v = v, who = pickCharacter(nil, SHELTER_CHARACTERS), ghost = ghost, spot = spot, arrived = false, leaving = false }
	local start = stopPoint.Position + backDir() * (CONFIG.WalkerStartDistance - 10)
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, Vector3.new(stopPoint.Position.X, start.Y, stopPoint.Position.Z)))
	v.Name = "ShelterVisitor"
	v:SetAttribute("IsAnomaly", ghost)
	v.Parent = Workspace
	table.insert(shelters, sh)
	print("☔ คนแวะหลบฝน (" .. (if ghost then "ผี" else "คน") .. ")")

	task.spawn(function()
		local spotXZ = CONFIG.ShelterSpots[spot]
		local ignore = { v, shutterDoor }
		-- เดินมาตามถนน -> เลี้ยวเข้าใต้ชายคา
		local roadPoint = Vector3.new(spotXZ.X, 0, stopPoint.Position.Z)
		Pedestrian.WalkTo(v, roadPoint, CONFIG.WalkSpeed)
		if not v.Parent then
			return
		end
		Pedestrian.WalkTo(v, Vector3.new(spotXZ.X, 0, spotXZ.Z), CONFIG.WalkSpeed * 0.8, true, ignore)
		Pedestrian.Face(v, Vector3.new(spotXZ.X, 0, spotXZ.Z - 10)) -- หันออกไปทางถนน
		sh.arrived = true
		-- ขอหลบฝน (รอจังหวะที่ไม่มีลูกค้าคุยอยู่)
		local t0 = os.clock()
		while v.Parent and (customerTalking or replyOpen) and os.clock() - t0 < 20 do
			task.wait(0.5)
		end
		for _ = 1, 20 do
			if not v.Parent or shelterSay(sh, if ghost then "ShelterGhost_Ask" else "Shelter_Ask", 3.5) then
				break
			end
			task.wait(1)
		end
		-- ชวนคุยเป็นระยะจนฝนหยุด
		local nextTalk = os.clock() + CONFIG.ShelterTalkEvery[1] + math.random() * (CONFIG.ShelterTalkEvery[2] - CONFIG.ShelterTalkEvery[1])
		while v.Parent and Weather.IsRaining() and not gameOver do
			if os.clock() > nextTalk then
				if shelterSay(sh, pick(if ghost then SHELTER_GHOST_TALK else SHELTER_TALK), 4) then
					nextTalk = os.clock() + CONFIG.ShelterTalkEvery[1] + math.random() * (CONFIG.ShelterTalkEvery[2] - CONFIG.ShelterTalkEvery[1])
				else
					nextTalk = os.clock() + 3
				end
			end
			task.wait(0.5)
		end
		if not v.Parent or gameOver then
			return
		end
		-- ฝนหยุด: ลาแล้วกลับ (ผีจางหายไปเฉยๆ)
		sh.leaving = true
		task.wait(2 + math.random() * 3)
		local t1 = os.clock()
		while (customerTalking or replyOpen) and os.clock() - t1 < 15 do
			task.wait(0.5)
		end
		for _ = 1, 40 do -- รอจังหวะที่ไม่มีใครคุย (สูงสุด ~40 วิ)
			if shelterSay(sh, if ghost then "ShelterGhost_Leave" else "Shelter_Leave", 3.2) then
				break
			end
			task.wait(1)
		end
		local idx = table.find(shelters, sh)
		if idx then
			table.remove(shelters, idx)
		end
		if ghost then
			Pedestrian.FadeAway(v, 2.5)
		else
			Pedestrian.WalkTo(v, roadPoint, CONFIG.WalkSpeed * 0.8, true, ignore)
			local away = stopPoint.Position - backDir() * 60
			Pedestrian.WalkTo(v, away, CONFIG.WalkSpeed)
			v:Destroy()
		end
	end)
end

-- ---------------------------------------------------------------- ขาจรบนถนน (ไม่ได้มาใช้บริการ แค่ผ่าน/แวะทัก/ก่อกวน)
local roadEventRunning = false
local RACER_REV = "rbxassetid://74974322876141" -- เบิ้ลตัด
local RACER_PASS = "rbxassetid://92289716313018"
local PARTY_MUSIC = "rbxassetid://9040293936" -- เพลงแดนซ์
local PARADE_CROWD = "rbxassetid://9112779173" -- โห่ฮิ้ว แตรขบวนแห่
local PARADE_DRUMS = "rbxassetid://9043078311" -- กลองเดินขบวน

local function eventSound(parent: Instance, presetOrId: string, volume: number, looped: boolean, range: number, music: boolean): Sound
	local preset = SoundBank.Presets[presetOrId]
	if preset then
		local snd = SoundBank.CreateSound(presetOrId, parent, range) :: Sound
		snd.Name = if music then "EventMusic" else "EventSound"
		snd.Looped = looped
		snd.RollOffMode = Enum.RollOffMode.Linear
		snd.RollOffMinDistance = 15
		snd.RollOffMaxDistance = range
		snd:SetAttribute("SoundCategory", if music then "Music" else "SFX")
		snd:Play()
		return snd
	end
	local snd = Instance.new("Sound")
	snd.Name = if music then "EventMusic" else "EventSound"
	snd.SoundId = presetOrId
	snd.Volume = volume
	snd.Looped = looped
	snd.RollOffMode = Enum.RollOffMode.Linear
	snd.RollOffMinDistance = 15
	snd.RollOffMaxDistance = range
	snd:SetAttribute("SoundCategory", if music then "Music" else "SFX")
	SoundBank.ApplyWarmEffects(snd, { low = 5, mid = 2, high = -18 })
	snd.Parent = parent
	snd:Play()
	return snd
end

local function roadVehicle(name: string): Model?
	local t = templateOrNil(name)
	if not t then
		return nil
	end
	local v = t:Clone()
	prepThaiVehicle(v)
	seatDriver(v)
	v.Name = "RoadEvent"
	local start = spawnPoint.Position
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, start + ROAD_DIR))
	v.Parent = Workspace
	return v
end

local function roadSay(key: string, nameKey: string, hold: number, srcModel: Instance?)
	if customerTalking or replyOpen then
		return
	end
	CustomerSpeech:FireAllClients(key, getHead(srcModel), { name = nameKey }, nil)
	task.wait(hold)
	if not customerTalking and not replyOpen then
		CustomerSpeech:FireAllClients(nil)
	end
end

-- คนเดิน/เต้นตามรถ: ทุกเฟรมวางตามรถ + ท่าเต้น (โยก ส่าย) ถ้ารถวิ่งก็แกว่งขาเดิน
local function followVehicle(v: Model, people: { { m: Model, offset: CFrame, dance: boolean } }): () -> ()
	local alive = true
	local t0 = os.clock()
	local lastPos = v:GetPivot().Position
	local conn = RunService.Heartbeat:Connect(function()
		if not v.Parent then
			return
		end
		local t = os.clock() - t0
		local piv = v:GetPivot()
		local moving = (piv.Position - lastPos).Magnitude > 0.01
		lastPos = piv.Position
		for i, pp in ipairs(people) do
			if pp.m.Parent then
				local ph = t * 6 + i * 1.3
				local bob = if pp.dance then math.abs(math.sin(ph)) * 0.5 else 0
				local sway = if pp.dance then math.sin(ph * 0.5) * 0.35 else 0
				local cf = piv * pp.offset
				local y = groundAt(cf.Position)
				pp.m:PivotTo(CFrame.new(cf.Position.X, y + bob, cf.Position.Z) * (cf - cf.Position) * CFrame.Angles(0, sway, 0))
				Pedestrian.Pose(pp.m, if moving or pp.dance then math.sin(ph) * 0.5 else 0)
			end
		end
	end)
	return function()
		alive = false
		conn:Disconnect()
		for _, pp in ipairs(people) do
			if pp.m.Parent then
				pp.m:Destroy()
			end
		end
	end
end

local function exitPos(): Vector3
	local e = exitPoint.Position
	return Vector3.new(e.X, e.Y, e.Z)
end

-- 1) เด็กแว้น: มอไซค์ซิ่ง 1-2 คัน บิดเสียงดัง ยกล้อหน้าร้าน ตะโกนแซว แล้วซิ่งออกไป
local function eventRacers()
	local count = math.random(1, 2)
	for i = 1, count do
		task.spawn(function()
			task.wait((i - 1) * 1.2)
			local v = roadVehicle("ThaiRacingMoto")
			if not v then
				return
			end
			local root = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
			eventSound(root :: Instance, "RacerMotoRevCut", 0.48, true, 160, false)
			local stop = stopPoint.Position
			local wheelieAt = stop - ROAD_DIR * 14 + Vector3.new(0, 0, 2.5 * (i - 1))
			driveTo(v, wheelieAt, false, 40)
			-- ยกล้อ: เงยหน้ารถ 25° วิ่งผ่านหน้าร้าน ~30 studs
			local from = v:GetPivot()
			local t0 = os.clock()
			local dur = 1.4
			while os.clock() - t0 < dur and v.Parent do
				local k = (os.clock() - t0) / dur
				local pos = from.Position + ROAD_DIR * (30 * k)
				local lift = math.sin(math.min(k * 1.4, 1) * math.pi / 2) * math.rad(25) * (if k > 0.85 then (1 - k) / 0.15 else 1)
				local y = groundAt(pos)
				local at = Vector3.new(pos.X, y + lift * 1.6, pos.Z)
				v:PivotTo(CFrame.lookAt(at, at + ROAD_DIR) * CFrame.Angles(lift, 0, 0)) -- หน้ารถเงยขึ้น lift เรเดียน
				task.wait()
			end
			if i == 1 then
				task.spawn(roadSay, pick({ "Racer_Shout_1", "Racer_Shout_2" }), "Name_Racer", 2.6, v)
			end
			eventSound(root :: Instance, "RacerWheeliePass", 0.52, false, 200, false)
			driveTo(v, exitPos(), false, 46)
			v:Destroy()
		end)
	end
	task.wait(9 + count * 1.2)
end

-- 2) รถซิ่งเปิดเพลงแดนซ์: จอดหน้าร้าน เปิดเพลงดัง สาวโคโยตี้ยืนข้างรถ (ไม่ได้เต้นบนรถ) วัยรุ่นเต้นตามรถ แล้วพากันไปต่อ
local function eventParty()
	local v = roadVehicle("ThaiSoundTruck")
	if not v then
		return
	end
	local len = v:GetExtentsSize().Z
	local root = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
	local partyTrack = if math.random() < 0.5 then "DanceMusic1_SaiYor" else "DanceMusic2_MorlamEDM"
	local music = eventSound(root :: Instance, partyTrack, 0.50, true, 170, true)
	local people = {}
	-- สาวโคโยตี้ ยืนข้างรถฝั่งร้าน (ยืนเฉยๆ ไม่เต้น)
	local coyote = Pedestrian.Build({ shirt = Color3.fromRGB(220, 60, 140), pants = Color3.fromRGB(30, 30, 35) })
	coyote.Name = "Coyote"
	coyote.Parent = Workspace
	table.insert(people, { m = coyote, offset = CFrame.new(5.5, 0, -len * 0.15) * CFrame.Angles(0, math.rad(-90), 0), dance = false })
	-- วัยรุ่น 4 คนเต้นอยู่ท้ายรถ
	local teenColors = { Color3.fromRGB(40, 90, 160), Color3.fromRGB(200, 170, 40), Color3.fromRGB(30, 30, 30), Color3.fromRGB(160, 40, 40) }
	for i = 1, 4 do
		local tm = Pedestrian.Build({ shirt = teenColors[i] })
		tm.Name = "Teen"
		tm.Parent = Workspace
		local col = if i % 2 == 0 then 2.2 else -2.2
		local row = math.floor((i - 1) / 2)
		table.insert(people, { m = tm, offset = CFrame.new(col, 0, len / 2 + 3 + row * 3.2), dance = true })
	end
	local stopFollow = followVehicle(v, people)
	local stopAt = stopPoint.Position + ROAD_DIR * 4 + Vector3.new(0, 0, -2)
	driveTo(v, stopAt, true, 14)
	roadSay("Party_Line", "Name_PartyDriver", 3, v)
	roadSay("Teen_Line", "Name_Teen", 2.6, people[2] and people[2].m or v)
	roadSay("Coyote_Line", "Name_Coyote", 3, coyote)
	task.wait(6)
	driveTo(v, exitPos(), false, 12)
	music:Stop()
	stopFollow()
	v:Destroy()
end

-- 3) รถแห่งานบวช: ขบวนช้าๆ คนเดินตามเต้นรำ นาคชุดขาวกางร่มทอง เสียงกลอง+โห่ฮิ้ว ชวนไปงาน แล้วแห่ผ่านไป
local function eventParade()
	local v = roadVehicle("ThaiParadeTruck")
	if not v then
		return
	end
	local len = v:GetExtentsSize().Z
	local root = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
	local crowd = eventSound(root :: Instance, PARADE_CROWD, 1.2, true, 180, false)
	local paradeTrack = if math.random() < 0.5 then "ParadeMusic1_RotHae" else "ParadeMusic2_KlongYao"
	local drums = eventSound(root :: Instance, paradeTrack, 0.48, true, 180, true)
	local people = {}
	-- นาค (ชุดขาว ร่มทอง) เดินหน้าขบวนท้ายรถ
	local naga = Pedestrian.Build({ umbrella = true, shirt = Color3.fromRGB(235, 232, 225), pants = Color3.fromRGB(235, 232, 225), umbrellaColor = Color3.fromRGB(210, 170, 50) })
	naga.Name = "Ordinand"
	naga.Parent = Workspace
	table.insert(people, { m = naga, offset = CFrame.new(0, 0, len / 2 + 3), dance = false })
	local colors = { Color3.fromRGB(230, 120, 40), Color3.fromRGB(60, 130, 200), Color3.fromRGB(200, 60, 90), Color3.fromRGB(240, 200, 60), Color3.fromRGB(120, 60, 160) }
	for i = 1, 10 do
		local m = Pedestrian.Build({ shirt = colors[(i - 1) % #colors + 1] })
		m.Name = "ParadeDancer"
		m.Parent = Workspace
		local col = if i % 2 == 0 then 2.4 else -2.4
		local row = math.floor((i - 1) / 2)
		table.insert(people, { m = m, offset = CFrame.new(col + (math.random() - 0.5), 0, len / 2 + 6.5 + row * 3.4), dance = true })
	end
	local stopFollow = followVehicle(v, people)
	-- แห่ผ่านหน้าร้านช้าๆ ชวนไปงาน
	local mid = stopPoint.Position + ROAD_DIR * 10
	driveTo(v, mid, false, 6)
	roadSay("Parade_Invite", "Name_ParadeHost", 3.4, v)
	roadSay("Parade_Cheer", "Name_ParadeCrowd", 2.4, naga)
	driveTo(v, exitPos(), false, 6)
	crowd:Stop()
	drums:Stop()
	stopFollow()
	v:Destroy()
end

local function runRoadEvent(kind: string?)
	if roadEventRunning then
		return
	end
	local raining = Weather.IsRaining()
	if not kind then
		local pool, total = {}, 0
		for _, e in ipairs(CONFIG.RoadEvents) do
			if e.rain or not raining then
				table.insert(pool, e)
				total += e.weight
			end
		end
		local r = math.random() * total
		for _, e in ipairs(pool) do
			r -= e.weight
			if r <= 0 then
				kind = e.kind
				break
			end
		end
	end
	roadEventRunning = true
	print("🎉 ขาจรบนถนน: " .. tostring(kind))
	local ok, err = pcall(function()
		if kind == "racer" then
			eventRacers()
		elseif kind == "party" then
			eventParty()
		elseif kind == "parade" then
			eventParade()
		end
	end)
	if not ok then
		warn("[CoreLoop] road event error:", err)
	end
	roadEventRunning = false
end

local function anyShelter(): Shelter?
	for _, sh in ipairs(shelters) do
		if sh.arrived and not sh.leaving then
			return sh
		end
	end
	return nil
end

function devRoadEvent(kind: string)
	task.spawn(runRoadEvent, kind)
end

function devSpawn(kind: string)
	if gameOver then
		return
	end
	if kind == "shelter" then
		spawnShelter()
	elseif #queue < CONFIG.MaxQueue then
		spawnCustomer(kind)
	end
end

-- เลือกจังหวะครั้งถัดไป
local function pickPacing()
	local list = if Weather.IsRaining() then CONFIG.RainPacing else CONFIG.Pacing
	local total = 0
	for _, p in ipairs(list) do
		total += p.weight
	end
	local r = math.random() * total
	for _, p in ipairs(list) do
		r -= p.weight
		if r <= 0 then
			return p
		end
	end
	return list[1]
end

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- ปล่อยลูกค้าเข้ามาตามจังหวะ (หยุดเมื่อคิวเต็ม)
local function waitWhile(cond: () -> boolean, seconds: number?)
	local t0 = os.clock()
	while cond() and not gameOver and (not seconds or os.clock() - t0 < seconds) do
		task.wait(0.5)
	end
end

local function spawnerLoop()
	waitWhile(function()
		return true
	end, rand(CONFIG.FirstWaveDelay))
	while not gameOver do
		local pace = pickPacing()
		if pace.kind == "shelter" then
			if #shelters < CONFIG.MaxShelter and Weather.IsRaining() then
				spawnShelter()
			else
				spawnCustomer()
			end
		end
		for i = 1, (if pace.kind == "shelter" then 0 else pace.count) do
			while #queue >= CONFIG.MaxQueue and not gameOver do
				task.wait(0.5)
			end
			if gameOver then
				return
			end
			spawnCustomer()
			if i < pace.count then
				task.wait(rand(pace.spacing))
			end
		end
		-- รอจนร้านว่างจริงๆ (คันสุดท้ายของระลอกออกไปแล้ว) แล้วค่อยนับเวลาพัก
		waitWhile(function()
			return #queue > 0
		end)
		local rest = rand(pace.rest)
		print(string.format("☕ ร้านว่าง พัก %.0f วิ (ระลอกถัดไป)", rest))
		if math.random() < CONFIG.RoadEventChance then
			task.delay(math.min(4, rest * 0.3), runRoadEvent)
		end
		waitWhile(function()
			return true
		end, rest)
		-- ขาจรยังอยู่บนถนน รอให้ผ่านไปก่อนค่อยปล่อยลูกค้าระลอกใหม่
		waitWhile(function()
			return roadEventRunning
		end, 60)
	end
end

-- ---------------------------------------------------------------- บริการลูกค้า 1 คัน (คันที่ถึงตู้ปั๊ม)
local function waitDecisionImpatient(c: Customer, speaker, annoyed: number, promptsAt: number): (string?, number)
	-- คืน (คำตอบ, ระดับความไม่พอใจ 0..2)
	if decision then
		return decision, annoyed
	end
	local t0 = os.clock()
	while not decision and not gameOver and os.clock() - t0 < CONFIG.DecisionTime do
		local waited = os.clock() - promptsAt -- นับจากตอนปุ่มเปิด (รวมช่วงถามราคา)
		if annoyed < 1 and waited > CONFIG.ImpatientAfter[1] then
			annoyed = 1
			say(if c.ghost then "Ghost_Wait" else pick({ "Impatient_1", "Impatient_2" }), speaker)
		elseif annoyed < 2 and waited > CONFIG.ImpatientAfter[2] then
			annoyed = 2
			say(if c.ghost then "Ghost_Wait2" else "Impatient_3", speaker)
		end
		task.wait(0.1)
	end
	return decision, annoyed
end

-- ---------------------------------------------------------------- ลูกค้าทักคนที่พนมมือ
local PRAY_ASK = { "Pray_Ask_1", "Pray_Ask_2", "Pray_Ask_3", "Pray_Ask_4" }
local PRAY_GHOST = { "Pray_Ghost_1", "Pray_Ghost_2", "Pray_Ghost_3" }
local PRAY_REPLY = { "Pray_Reply_1", "Pray_Reply_2", "Pray_Reply_3", "Pray_Reply_4" }
local PRAY_AFTER = { "Pray_After_1", "Pray_After_2" }
local PRAY_GHOST_AFTER = { "Pray_GhostAfter_1", "Pray_GhostAfter_2" }

-- ทำงานตลอดที่ลูกค้าคนนี้อยู่ที่ตู้ (หยุดเมื่อ alive() = false)
local function watchPrayers(c: Customer, speaker: { [string]: string }, alive: () -> boolean)
	local reacted = 0
	local seen: { [Player]: number } = {} -- พนมมือรอบไหนที่ทักไปแล้ว (เวลาเริ่มพนมมือ)
	while alive() and reacted < CONFIG.PrayReactMax and not gameOver do
		task.wait(0.3)
		-- ทักได้แม้ตัวเลือกตอบราคาเปิดอยู่ (ตัวเลือกแสดงแยกจากกล่องคำพูด) แค่รอให้ประโยคก่อนหน้าจบ
		if os.clock() < speechBusyUntil or decision then
			continue
		end
		for _, p in ipairs(Prayer.PrayingNear(c.v:GetPivot().Position, CONFIG.PrayReactRadius)) do
			local started = Prayer.StartedAt(p)
			local dur = Prayer.Duration(p)
			if started and dur and dur >= CONFIG.PrayReactAfter and seen[p] ~= started then
				seen[p] = started
				reacted += 1
				local ghostLine = c.ghost and math.random() < CONFIG.PrayGhostLineChance
				print("🙏 ลูกค้าเห็น [" .. p.Name .. "] พนมมือ" .. (if ghostLine then " (ผีไม่ชอบ)" else ""))
				say(pick(if ghostLine then PRAY_GHOST else PRAY_ASK), speaker, nil, 2.8)
				if not alive() then
					break
				end
				say(pick(PRAY_REPLY), { player = p.DisplayName, userId = p.UserId, gender = SoundBank.DetectPlayerGender(p) }, nil, 2.4)
				if not alive() then
					break
				end
				say(pick(if ghostLine then PRAY_GHOST_AFTER else PRAY_AFTER), speaker, nil, 2.6)
				break
			end
		end
	end
end

local function serveCustomer(c: Customer)
	local v = c.v
	c.serving = true
	currentVehicle = v
	currentVehicleIsAnomaly = c.ghost
	currentAnomaly = c.anomaly
	decision = nil
	if c.deferredWorld then
		AnomalyManager.Apply(c.deferredWorld, v)
	end
	AnomalyManager.SetGhostPresent(c.ghost)
	publishState()

	local ghost = c.ghost
	local who = c.who
	local speaker = { name = who.name, voice = who.voice, ghost = ghost }
	local arrivedAt = os.clock()
	customerTalking = true
	currentHead = getHead(v)
	local annoyed = 0
	local present = true -- ลูกค้ายังคุยอยู่ที่ตู้ (ทักคนพนมมือได้)
	task.spawn(watchPrayers, c, speaker, function()
		return present and v.Parent ~= nil
	end)

	-- ทัก (ถ้ารอคิวนานจะบ่นก่อน)
	if c.queuedSince and os.clock() - c.queuedSince > CONFIG.QueueAnnoyedAfter and not ghost then
		annoyed = 1
		say("Greet_Waited", speaker, nil, 2.6)
	else
		say(who.greet, speaker)
	end
	-- ผู้เล่นทักตอบ (ทักคนเดียว / ทักทั้งสองคน)
	local greet = askReply(GREET_OPTIONS, CONFIG.GreetReplyTime)
	if greet then
		say(if greet == "both" then "PlayerGreetBoth" else "PlayerHello", { player = replyBy :: string, gender = replyGender }, nil, 1.6)
		if greet == "both" then
			local passenger = v:FindFirstChild("GhostPassenger")
			local hasPassenger = c.anomaly == "Anomaly_Headless" and passenger ~= nil
			if hasPassenger then
				-- คนขับไม่รู้ตัวว่ามีอะไรซ้อนท้าย
				say("Alone_Ghost", speaker, nil, 2.6)
				say("Passenger_Whisper", { ghost = "???" }, nil, 2.4)
			elseif ghost then
				say("Alone_Creepy", speaker, nil, 2.6)
			else
				say("Alone_Normal", speaker, nil, 2.6)
			end
		end
	end

	-- ฝนตก: บ่นเรื่องฝนนิดหน่อย (ผีไม่รู้สึกถึงฝน)
	local raining = Weather.IsRaining()
	if raining and math.random() < 0.5 then
		say(if ghost then "Ghost_RainTalk" else pick({ "RainTalk_1", "RainTalk_2", "RainTalk_3" }), speaker, nil, 2.6)
	end
	-- คนหลบฝนใต้ชายคาทักลูกค้า (เป็นเบาะแสได้: ผีไม่เปียกฝน / ลูกค้ามองไม่เห็นคนหลบฝนที่เป็นผี)
	local sh = anyShelter()
	if sh and math.random() < 0.7 then
		local shSpeaker = { name = sh.who.name, voice = sh.who.voice, ghost = sh.ghost }
		if sh.ghost and not ghost then
			say("ShelterGhost_ToCustomer", shSpeaker, nil, 2.8, getHead(sh.v))
			say("Chat_WhoTalking", speaker, nil, 2.8)
		elseif ghost and raining then
			say("Shelter_NoticeDry", shSpeaker, nil, 3, getHead(sh.v))
			say("Ghost_DryReply", speaker, nil, 2.6)
		else
			say(pick({ "Shelter_ToCustomer_1", "Shelter_ToCustomer_2" }), shSpeaker, nil, 2.6, getHead(sh.v))
			say(if ghost then "Ghost_ShortReply" else pick({ "Chat_Reply_1", "Chat_Reply_2" }), speaker, nil, 2.4)
		end
	end

	local order = if c.useAnomalyLine then c.anomaly :: string else c.order
	say(order, speaker, nil, 3.2)
	-- คิวคันหลังแซวให้รีบ
	local nextInLine = queue[2]
	if nextInLine and nextInLine.queuedSince and os.clock() - nextInLine.queuedSince > 6 and math.random() < 0.4 then
		say(if nextInLine.ghost then "Queue_ChimeGhost" else "Queue_Chime", { name = nextInLine.who.name, voice = nextInLine.who.voice, ghost = nextInLine.ghost }, nil, 2.4, getHead(nextInLine.v))
	end
	-- ล็อกปุ่มอย่างน้อย InspectLock วิหลังรถจอด (ให้ส่องไฟฉายดู)
	task.wait(math.max(0, CONFIG.InspectLock - (os.clock() - arrivedAt)))
	if not gameOver then
		setServicePrompts(true)
	end
	local promptsAt = os.clock()

	-- ถามราคา (ตามบริการ: น้ำมันหลอด / ดีเซล / เติมลม)
	local svc = CONFIG.Services[c.service] or CONFIG.Services.petrol
	local price = svc.normal
	local leaveEarly = false
	if not decision and not gameOver then
		say(svc.ask, speaker)
		local options = {}
		for _, amount in ipairs(svc.prices) do
			table.insert(options, { id = tostring(amount), key = "Reply_" .. amount })
		end
		local answered = askReply(options, CONFIG.ReplyTime)
		if answered then
			price = tonumber(answered) :: number
			say("PlayerQuote", { player = replyBy :: string, gender = replyGender }, { amount = price }, 1.6)
			if ghost then
				say("Ghost_Price", speaker, nil, 2.4)
			elseif price < svc.normal then
				say("Price_Cheap", speaker, { amount = price }, 2.4)
			elseif price == svc.normal then
				say("Price_Normal", speaker, { amount = price }, 2.4)
			elseif math.random() < CONFIG.ExpensiveRefuseChance and not decision then
				say("Price_ExpensiveNo", speaker, { amount = price }, 2.6)
				leaveEarly = true
			else
				say("Price_ExpensiveOk", speaker, { amount = price }, 2.4)
			end
		elseif not decision then
			say(if ghost then "Ghost_Price" else "Price_Silent", speaker, { amount = price }, 2.4)
		end
	end

	local choice: string? = nil
	if leaveEarly then
		setServicePrompts(false)
		print("💸 ตั้งราคาแพงไป ลูกค้าไม่เติม")
	else
		choice, annoyed = waitDecisionImpatient(c, speaker, annoyed, promptsAt)
		setServicePrompts(false)
		-- เติมผิดตู้ (ลูกค้าปกติท้วง แล้วรอให้ทำใหม่) ผีไม่สนว่าตู้ไหน เติมอะไรให้ก็คือเติมให้ผี
		local wrong = 0
		while not ghost and choice and choice ~= "reject" and choice ~= svc.choice and not gameOver do
			wrong += 1
			annoyed = math.max(annoyed, 1)
			local wrongKey = if c.service == "diesel" then "Wrong_NeedDiesel" elseif c.service == "air" then "Wrong_NeedAir" elseif choice == "air" then "Wrong_NeedFuel" else "Wrong_NeedPetrol"
			say(wrongKey, speaker, nil, 2.8)
			print("❌ เติมผิดตู้ (" .. choice .. ") ลูกค้าต้องการ " .. c.service)
			if wrong >= CONFIG.MaxWrongService then
				say("Wrong_GiveUp", speaker, nil, 2.6)
				choice = nil
				leaveEarly = true
				break
			end
			decision = nil
			setServicePrompts(true)
			choice, annoyed = waitDecisionImpatient(c, speaker, annoyed, promptsAt)
			setServicePrompts(false)
		end
		-- ผี: ตู้ไหนก็นับเป็นเติมให้ผี
		if ghost and (choice == "diesel" or choice == "air") then
			choice = "fuel"
		end
		-- ลูกค้าปกติที่เติมถูกตู้ -> ใช้เส้นทาง "fuel" เดิม (แอนิเมชันตามบริการ)
		if not ghost and choice == svc.choice then
			choice = "fuel"
		end
	end

	-- ตรวจคำตอบ
	if choice == "fuel" then
		if c.service == "air" and not ghost then
			airHiss:Play()
			task.wait(2)
			airHiss:Stop()
		else
			local targetBody = if c.service == "diesel" and not ghost then dieselBody else pumpBody
			SoundBank.PlayOneShot("PumpCrankLoop", targetBody, 55, 2.0)
			SoundBank.PlayOneShot("FuelGlugLoop", targetBody, 50, 2.0)
			local fillTween = if c.service == "diesel" and not ghost then setDieselLevel(0.2, 2) else setFuelLevel(0.15, 2)
			if fillTween then
				fillTween.Completed:Wait()
			end
		end
		if ghost then
			-- เติมให้ผี: ธูปดับ 1 ดอก + หักเงิน + ผีหลอก
			say("Ghost_Pay", speaker, { amount = price }, 1.5)
			incense -= 1
			money = math.max(0, money - CONFIG.GhostFuelPenalty)
			refreshIncense()
			local spiritPart = spirit:FindFirstChildWhichIsA("BasePart", true)
			if spiritPart then
				SoundBank.PlayOneShot("IncenseExtinguish", spiritPart, 85, 3.0)
			end
			TriggerJumpscare:FireAllClients(c.anomaly, v)
			print("👻 เติมน้ำมันให้ผี! ธูปเหลือ " .. incense)
			if incense <= 0 then
				-- ธูปดอกสุดท้ายดับ: ตายทันทีหลังผีหลอก ไม่ต้องรอลูกค้าพูด/ขี่ออก
				broadcastHUD()
				present = false
				task.wait(1.1)
				CustomerSpeech:FireAllClients(nil)
				currentHead = nil
				customerTalking = false
				currentVehicle = nil
				return
			end
		elseif annoyed > 0 then
			local paid = math.max(1, price - math.floor(price * CONFIG.SlowPenaltyRatio + 0.5))
			money += paid
			local tin = interactive:FindFirstChild("MoneyTin")
			SoundBank.PlayOneShot("CoinTinDrop2", (tin and tin:FindFirstChildWhichIsA("BasePart", true)) or pumpBody, 55, 1.5)
			say("Pay_Slow", speaker, { amount = paid })
			print("😒 เติมช้า ลูกค้าจ่ายแค่ " .. paid .. "฿ รวม " .. money)
		else
			money += price
			local tin = interactive:FindFirstChild("MoneyTin")
			SoundBank.PlayOneShot("CoinTinDrop1", (tin and tin:FindFirstChildWhichIsA("BasePart", true)) or pumpBody, 55, 1.5)
			say(pick({ "Pay_1", "Pay_2", "Pay_3" }), speaker, { amount = price })
			print("💰 ลูกค้าปกติ +" .. price .. "฿ รวม " .. money)
		end
		broadcastHUD()
		setFuelLevel(1, 3)
		setDieselLevel(1, 3)
	elseif choice == "reject" then
		closeShutter()
		if ghost then
			money += CONFIG.RejectGhostReward
			local tin = interactive:FindFirstChild("MoneyTin")
			SoundBank.PlayOneShot("CoinTinDrop1", (tin and tin:FindFirstChildWhichIsA("BasePart", true)) or pumpBody, 55, 1.5)
			if c.anomaly then
				AnomalyBook.Survived(c.anomaly) -- รอดจากผีตัวนี้ -> ปลดล็อกในสมุดของทุกคน
			end
			say("Ghost_Rejected", speaker)
			print("✅ ไล่ผีถูกต้อง +" .. CONFIG.RejectGhostReward .. "฿ รวม " .. money)
		else
			say(pick({ "Rejected_1", "Rejected_2" }), speaker)
			print("😤 ปิดร้านใส่ลูกค้าปกติ อดได้เงิน")
		end
		broadcastHUD()
		task.delay(3, openShutter)
	elseif not leaveEarly then
		say(if ghost then "Ghost_NoOne" else pick({ "NoOne_1", "NoOne_2" }), speaker)
		print("⌛ ไม่มีใครตัดสินใจ ลูกค้าขับออกไปเอง")
	end
	present = false
	task.wait(2.6) -- ให้อ่านประโยคสุดท้ายทัน
	CustomerSpeech:FireAllClients(nil)
	currentHead = nil
	customerTalking = false

	-- ออกจากคิว คันหลังเลื่อนขึ้นมาได้เลย แล้วขี่ออก
	local idx = table.find(queue, c)
	if idx then
		table.remove(queue, idx)
	end
	currentVehicle = nil
	currentVehicleIsAnomaly = false
	currentAnomaly = nil
	AnomalyManager.SetGhostPresent(false)
	publishState()
	task.wait(1)
	-- ผีที่โดนปิดร้านใส่: ออกไปช้าๆ ถ้าใครวิ่งตามไปใกล้ๆ ผีหันมาหลอกแล้วคนนั้นล้มตึง
	local chased = false
	local watching = ghost and choice == "reject"
	if watching then
		task.spawn(function()
			while watching and v.Parent and not chased do
				for _, p in ipairs(Players:GetPlayers()) do
					local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and not root.Anchored then
						local d = (root.Position - v:GetPivot().Position).Magnitude
						local fromShop = (root.Position - stopPoint.Position).Magnitude
						if d < CONFIG.ChaseRadius and fromShop > CONFIG.ChaseMinFromShop then
							chased = true
							print("👻 [" .. p.Name .. "] วิ่งตามผีไป โดนหลอกล้มตึง")
							CustomerSpeech:FireAllClients("Ghost_Chased", getHead(v), speaker, nil)
							TriggerJumpscare:FireClient(p, c.anomaly, v, "chased") -- (ไม่ได้เติมน้ำมัน: ข้อความต่างจากตอนเติมให้ผี)
							task.wait(0.35)
							knockDown(p, CONFIG.KnockdownTime)
							task.delay(3, function()
								CustomerSpeech:FireAllClients(nil)
							end)
							break
						end
					end
				end
				task.wait(0.1)
			end
		end)
	end
	if c.kind == "walker" or c.kind == "bicycle" then
		Pedestrian.WalkTo(v, stopPoint.Position - backDir() * 55, if watching then CONFIG.WalkSpeed * 0.7 else CONFIG.WalkSpeed)
	else
		local exit = exitPoint.Position
		driveTo(v, Vector3.new(exit.X, exit.Y, exit.Z), false, if watching then CONFIG.GhostLeaveSpeed else nil)
	end
	watching = false
	if chased and (c.kind == "walker" or c.kind == "bicycle") then
		Pedestrian.FadeAway(v, 1)
	else
		v:Destroy()
	end
	-- รถไปแล้ว: คืนวิทยุ หุ่นไล่กา ผีตานีหลังกอกล้วย น้ำมัน ให้ปกติ
	AnomalyManager.ResetAnomalies()
end

local function clearQueue()
	for _, c in ipairs(queue) do
		if c.v.Parent then
			c.v:Destroy()
		end
	end
	table.clear(queue)
	for _, sh in ipairs(shelters) do
		if sh.v.Parent then
			sh.v:Destroy()
		end
	end
	table.clear(shelters)
	customerTalking = false
	for _, d in ipairs(Workspace:GetChildren()) do
		if d.Name == "RoadEvent" or d.Name == "Coyote" or d.Name == "Teen" or d.Name == "Ordinand" or d.Name == "ParadeDancer" then
			d:Destroy()
		end
	end
	currentVehicle = nil
	AnomalyManager.ResetAnomalies()
end

-- ---------------------------------------------------------------- สวดตอนร้านว่าง: บางทีเรียกของมาเอง
local lastSummonAt = -math.huge
local summoned: string? = nil
local SUMMON_WHISPER = { "Pray_Summon_1", "Pray_Summon_2", "Pray_Summon_3" }

local function summonByPrayer(p: Player)
	local pool = {}
	for _, k in ipairs(CONFIG.PraySummonKeys) do
		if AnomalyManager.Anomalies[k] then
			table.insert(pool, k)
		end
	end
	if #pool == 0 then
		return
	end
	local key = pick(pool)
	summoned = key
	lastSummonAt = os.clock()
	AnomalyManager.Apply(key, nil :: any)
	if math.random() < CONFIG.PraySummonGhostNext then
		forceGhostNext = true
	end
	print("🕯️ [" .. p.Name .. "] สวดตอนร้านว่าง เรียก " .. key .. " มา" .. (if forceGhostNext then " (ลูกค้าคนถัดไปเป็นผี)" else ""))
	if not customerTalking and not replyOpen then
		CustomerSpeech:FireAllClients(pick(SUMMON_WHISPER), nil, { ghost = "WhisperSpeaker" }, nil)
		task.delay(3.2, function()
			if not customerTalking and not replyOpen then
				CustomerSpeech:FireAllClients(nil)
			end
		end)
	end
	local dur = rand(CONFIG.PraySummonDuration)
	task.delay(dur, function()
		-- ลูกค้าที่ตู้ตอนนี้ไม่ได้ใช้ผีตัวเดียวกัน -> เก็บผีที่เรียกมากลับ
		if summoned == key and currentAnomaly ~= key then
			AnomalyManager.Reset(key)
		end
		if summoned == key then
			summoned = nil
		end
	end)
end

local function prayerSummonLoop()
	local rolled: { [Player]: number } = {} -- สุ่มไปแล้วกับการพนมมือรอบไหน
	while true do
		task.wait(0.5)
		local idle = remotes:GetAttribute("ShopOpen") == true and not gameOver and #queue == 0 and not roadEventRunning and summoned == nil
		if idle and os.clock() - lastSummonAt > CONFIG.PraySummonCooldown then
			for _, p in ipairs(Prayer.Praying()) do
				local started = Prayer.StartedAt(p)
				local dur = Prayer.Duration(p)
				if started and dur and dur >= CONFIG.PraySummonAfter and rolled[p] ~= started then
					rolled[p] = started
					if math.random() < CONFIG.PraySummonChance then
						summonByPrayer(p)
						break
					end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- ลูปเกม
local function resetGame()
	money = 0
	incense = CONFIG.StartIncense
	gameOver = false
	forceGhostNext = false
	summoned = nil
	clearQueue()
	Weather.Reset()
	refreshIncense()
	setFuelLevel(1, 0.5)
	broadcastHUD()
end

-- เริ่มคืน: แผงสังกะสีปิดไว้ ยังไม่มีลูกค้า จนกว่าจะมีคนดึงเชือกเปิดร้าน
local function waitForShopOpen()
	local p = shutterDoor.Position
	shutterDoor.Position = Vector3.new(p.X, shutterOpenY - shutterDrop, p.Z)
	shopOpened = false
	openPrompt.Enabled = true
	GameState:FireAllClients("Waiting")
	remotes:SetAttribute("ShopOpen", false)
	local conn = openPrompt.Triggered:Connect(function(player)
		print("🔓 [" .. player.Name .. "] เปิดร้าน")
		shopOpened = true
	end)
	while not shopOpened do
		task.wait(0.2)
	end
	conn:Disconnect()
	openPrompt.Enabled = false
	remotes:SetAttribute("ShopOpen", true)
	openShutter()
	GameState:FireAllClients("Playing")
end

-- ผู้เล่นที่เข้ามาตอนร้านยังปิด ให้เห็นข้อความรอเปิดร้านด้วย
Players.PlayerAdded:Connect(function(p)
	task.wait(3)
	if openPrompt.Enabled then
		GameState:FireClient(p, "Waiting")
	end
end)

function CoreLoop.Start()
	math.randomseed(os.time())
	-- แม่แบบรถไทย 8 คัน (สร้างด้วยโค้ด) ถ้ายังไม่มีใน ServerStorage ให้สร้างก่อน
	if not templates:FindFirstChild("ThaiPickupOld") then
		local ok, err = pcall(function()
			local MB = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapBuilder"):Clone()) :: any
			MB.BuildThaiVehicleTemplates()
		end)
		if not ok then
			warn("[CoreLoop] สร้างแม่แบบรถไทยไม่ได้ ใช้มอไซค์อย่างเดียว:", err)
		end
	end
	AnomalyManager.Init()
	task.spawn(prayerSummonLoop)
	Weather.Start(function()
		return remotes:GetAttribute("ShopOpen") == true and not gameOver
	end)
	task.spawn(function()
		while true do
			resetGame()
			waitForShopOpen()
			task.spawn(spawnerLoop)
			while not gameOver do
				local front = queue[1]
				if front and front.atPump and not front.serving then
					serveCustomer(front)
					if incense <= 0 then
						gameOver = true
						print("💀 ธูปดับครบ 3 ดอก Game Over")
					elseif money >= CONFIG.TargetMoney then
						gameOver = true
						for _, player in ipairs(Players:GetPlayers()) do
							LeaderboardStats.Increment("completions", player.UserId, 1)
						end
						GameState:FireAllClients("Win")
						print("🏆 ครบ " .. CONFIG.TargetMoney .. "฿ ชนะ!")
					end
				elseif incense <= 0 then
					-- (ธูปหมดระหว่างไม่มีลูกค้า เช่น ทดสอบ) ก็จบเกมเหมือนกัน
					gameOver = true
				else
					task.wait(0.2)
				end
			end
			if incense <= 0 then
				-- แพ้: ทุกคนล้มนอนตาย จอแดง ถามว่าจะเริ่มใหม่ไหม รอจนมีคนกด
				losePending = true
				restartBy = nil
				clearQueue()
				for _, p in ipairs(Players:GetPlayers()) do
					collapse(p)
				end
				GameState:FireAllClients("Lose")
				while not restartBy do
					task.wait(0.3)
				end
				task.wait(1.2) -- ให้เห็นว่าใครกดเริ่มใหม่
				losePending = false
				-- เกิดใหม่ทุกคน (ลุกขึ้น ควบคุมได้อีกครั้ง)
				for _, p in ipairs(Players:GetPlayers()) do
					p:LoadCharacter()
				end
				task.wait(1)
			else
				task.wait(CONFIG.RestartDelay)
			end
		end
	end)
end

CoreLoop.Config = CONFIG
return CoreLoop
