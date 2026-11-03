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
local Cutscene: any -- (require ทีหลัง หลังฟังก์ชันรถ/แผงร้านพร้อม)

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
	DieselPumpOffset = 7, -- (สำรอง) ถ้าไม่มี InteractiveProps.DieselPump ในฉาก Clone ตู้ 1 ไปวางข้างๆ ห่างเท่านี้ไปทางขาออก
	AirStopOffset = 12, -- จุดจอดเติมลม (หน้าถังลม)
	ExpensiveRefuseChance = 0.5, -- ตอบแพง (120) ลูกค้าปกติมีโอกาสไม่เอา
	ReplyTime = 8, -- วินาทีที่เปิดให้ตอบราคา
	RejectGhostReward = 50, -- ดึงแผงปิดร้านใส่ผีได้ถูกต้อง
	GhostFuelPenalty = 100, -- เผลอเติมน้ำมันให้ผี (หักเงิน + ธูปดับ 1 ดอก)
	StartIncense = 3,
	AnomalyChance = 0.4,
	InspectLock = 4, -- วินาทีที่ล็อกปุ่มหลังรถจอด (ให้ส่องไฟฉายดู / พนมมือดู)
	DecisionTime = 75, -- ถ้าไม่มีใครตัดสินใจ ลูกค้าจะขับออกไปเอง (เผื่อเวลาพนมมือเช็กผีและเดินไปตู้)
	DriveSpeed = 24, -- studs / วินาที
	GreetReplyTime = 5, -- วินาทีที่เปิดให้ทักทายตอบ
	-- จังหวะลูกค้า: มาทีละ 1 คัน/คนเท่านั้น (ห้ามมาพร้อมกัน 2 กลุ่ม) -> พอออกไปพ้นแมพแล้ว พักตาม rest วินาที
	Pacing = {
		{ kind = "single", weight = 3, count = 1, rest = { 35, 55 } }, -- มาคันเดียว พักให้บรรยากาศเงียบเหงา
		{ kind = "quiet", weight = 2, count = 1, rest = { 60, 90 } }, -- มาคันเดียว แล้วเงียบไปนาน
	},
	FirstWaveDelay = { 18, 28 }, -- หลังเปิดร้าน รอให้เงียบสักพักก่อนคันแรกจะมา
	-- ฝนตก: ลูกค้ามาน้อยลงและทิ้งช่วงห่างขึ้น (มาทีละ 1 ราย ไม่ซ้อนกัน)
	RainPacing = {
		{ kind = "single", weight = 3, count = 1, rest = { 45, 70 } },
		{ kind = "quiet", weight = 2, count = 1, rest = { 70, 100 } },
	},
	WalkerChance = 0.25, -- ลูกค้าเดินมาถือแกลลอน (ปกติ)
	WalkerChanceRain = 0.5, -- (ฝนตก) เดินกางร่มมา
	WalkSpeed = 7,
	WalkerStartDistance = 55, -- คนเดินโผล่มาห่างตู้ปั๊มเท่านี้ (ตามถนน)
	RiderUmbrellaChance = 0, -- ไม่ใช้แล้ว: คนขับไม่กางร่ม (มือจับแฮนด์)
	MaxShelter = 1, -- คนหลบฝนพร้อมกันได้สูงสุด
	ShelterGhostChance = 0.3, -- คนหลบฝนเป็นผี (ฝนหยุดแล้วจางหายไป)
	ShelterTalkEvery = { 16, 26 }, -- คนหลบฝนชวนคุยทุกๆ (เฉพาะตอนไม่มีลูกค้า)
	ShelterSpots = { Vector3.new(9, 0, 10.5), Vector3.new(12.5, 0, 10.8) }, -- ใต้ชายคาหน้าร้าน (y หาเอง)
	-- ขาจร (ไม่ได้มาใช้บริการ) โผล่ช่วงร้านว่างระหว่างระลอก: เด็กแว้น / รถซิ่งเปิดเพลง / รถแห่งานบวช
	RoadEventChance = 0.25, -- โอกาสต่อช่วงพัก (ลดลงไม่ให้ถนนดูคึกคักเกินไป)
	RoadEvents = {
		{ kind = "racer", weight = 3, rain = true },
		{ kind = "party", weight = 2, rain = false },
		{ kind = "parade", weight = 1, rain = false },
	},
	MaxQueue = 1, -- ห้ามมีคิวต่อแถว มาได้ทีละ 1 รายเท่านั้น
	QueueSpacing = 9, -- ระยะห่างคันที่รอคิว (studs)
	-- รอนานแล้วไม่พอใจ
	ImpatientAfter = { 40, 60 }, -- วินาทีหลังเปิดปุ่ม (รวมช่วงถามราคา): บ่นครั้งที่ 1, 2
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
	PraySummonKeys = { "Anomaly_MonkRadio" },
	SceneryEvery = { 150, 300 }, -- ผีฉาก (ตานี / หุ่นไล่กา / เงาหลังต้นไทร) โผล่ทุกๆ กี่วินาที (สุ่ม) นานๆ ครั้ง
	SceneryStay = { 25, 40 }, -- โผล่ค้างให้เห็นกี่วินาที

	-- น้ำมันในตู้ (2026-11-03): เติม 1 ครั้งใช้เท่านี้ของหลอด หมดแล้วต้องเอาแกลลอนในร้านไปตักจากถังหลังร้านมาเท
	FuelPerFill = 0.25, -- หลอดเต็ม = เติมได้ 4 ครั้ง
	PourBelow = 0.24, -- ปุ่มเทน้ำมันใส่ตู้โผล่เมื่อตู้หมด (เหลือไม่พอเติม 1 ครั้ง = หลอดว่างเปล่า)
	CanFillTime = 2.0, -- กดค้างตักน้ำมันจากถัง (วินาที)
	CanPourTime = 2.5, -- กดค้างเทใส่ตู้

	-- ขนมถวายศาลพระภูมิ (2026-11-03): ไม่ถวาย = ศาลไม่คุ้มครอง โดนหลอกไม่หยุด
	-- ช่วงเตรียมร้าน (2026-11-03): ดึงเชือกเปิดร้านแล้วนับถอยหลังเท่านี้ก่อนลูกค้าคนแรกมา (ถวายขนม ติดไฟ เติมน้ำมัน)
	PrepTime = 60,
	-- ศาลคุ้มครองตอนต้นคืน (นับจากเปิดร้าน): ยังไม่ถวายเมื่อครบเวลานี้ = ศาลไม่คุ้มครอง (ไม่เกิน PrepTime)
	OfferingGrace = 45,
	OfferingDuration = 150, -- ถวาย 1 ครั้งคุ้มครองนานเท่านี้
	OfferingWarn = 25, -- เหลือเวลาคุ้มครองเท่านี้ เตือนทุกคน
	CurseEvery = { 9, 16 }, -- ศาลไม่คุ้มครอง: อาการแปลกๆ ทุกๆ
	CurseAnomalyChance = 0.75, -- ศาลไม่คุ้มครอง: ลูกค้าเป็นผีบ่อยขึ้น
	CurseSlowSpeed = 5, -- เดินช้า (ปกติ 10)

	-- ปิดร้านใส่ผี (2026-11-03): ใครยังอยู่นอกร้านโดนผีหลอกทันที แล้วผีหายวับไป (ไม่ขี่/เดินออกไปให้ไล่ตาม)
	RejectScareDelay = 0.6,

	-- จบคืนแบบชนะ: คัทซีน + หน้าสรุปผล แล้วรอให้ทุกคนกด "เฝ้าต่ออีกคืน" (หรือหมดเวลา) ค่อยเริ่มคืนใหม่
	SummaryTimeout = 60,
	WageBase = 200, -- ค่าเฝ้าร้านต่อคน (คูณตัวคูณความยากจาก Lobby)
	WagePerFill = 15,
	WagePerGhost = 40,
	WagePerOffering = 25,
}

-- ---------------------------------------------------------------- ฉากและของในฉาก
local interactive = Workspace:WaitForChild("InteractiveProps")
-- ตู้หลอด + ตู้ดีเซลรวมอยู่ใน InteractiveProps.FuelPumps (ฐานปูนเดียวกัน, MapBuilder.GroupFuelPumps) ถ้ายังไม่รวมอยู่ใน InteractiveProps ตรงๆ
local pumpGroup = interactive:FindFirstChild("FuelPumps") or interactive
local gasPump = pumpGroup:WaitForChild("GasPump") :: Model
local pumpBody = gasPump.PrimaryPart or (gasPump:FindFirstChild("GasPump") :: BasePart?) or (gasPump:FindFirstChild("PumpBase") :: BasePart?) or (gasPump:FindFirstChildWhichIsA("BasePart") :: BasePart)
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
local ServiceMinigame = remote("ServiceMinigame") -- S->C ("open", choice) / ("close")  C->S ("complete", choice)
local Notice = remote("Notice") -- S->C (uiKey, seconds?) ข้อความบรรยายสั้นๆ ในกล่องล่างจอ
local Curse = remote("Curse") -- S->C (symptom, seconds) อาการตอนศาลไม่คุ้มครอง / เสียงกระซิบ: "drowsy" | "shake" | "slow" | "stumble"
local SummaryRemote = remote("Summary") -- C->S ("continue") กด "เฝ้าต่ออีกคืน" ในหน้าสรุปผล  S->C ("votes", n, total)

-- แพ้ (ธูปดับหมด): ผู้เล่นทุกคนล้มนอนตาย จอแดง รอให้มีคนกด "เริ่มใหม่" (ใครกดก่อนนับทั้งร้าน)
-- ล้มคว่ำหน้าลงพื้น (ทำฝั่ง Server ทุกคนเห็นเหมือนกัน) ยึดตัวไว้ เดินไม่ได้ จนกว่าจะเกิดใหม่
-- คว่ำ ไม่ใช่หงาย: ตัวละครไม่มีหน้าตาตอนตาย นอนหงายแล้วเห็นหน้าปกติ ดูไม่เหมือนตาย
local Prayer = require(script.Parent:WaitForChild("Prayer"))
local ShrineHand = require(script.Parent:WaitForChild("ShrineHand"))
local JerryCan = require(script.Parent:WaitForChild("JerryCan"))
local HumanEmotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HumanEmotes"))
local CollisionGroups = require(script.Parent:WaitForChild("CollisionGroups"))
local function collapse(player: Player)
	Prayer.Stop(player) -- ล้มแล้วเลิกพนมมือ
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then
		return
	end
	-- ของในมือ (ไฟฉาย แกลลอน ขนม) เก็บเข้ากระเป๋า: ยกเลิกท่าถือ / ไม่มีของลอยค้างตอนกล้องจอตายมองร่าง
	hum:UnequipTools()
	-- ระหว่างนอนอยู่ หยิบของขึ้นมือใหม่ไม่ได้ (กันกดปุ่มช่องของตอนตาย) จนกว่าจะลุก (standUp / เกิดใหม่)
	local guard: RBXScriptConnection
	guard = char.ChildAdded:Connect(function(c)
		if not root.Anchored or not char.Parent then
			guard:Disconnect()
			return
		end
		if c:IsA("Tool") then
			task.defer(function()
				if root.Anchored and c.Parent == char then
					c.Parent = player:FindFirstChildOfClass("Backpack")
				end
			end)
		end
	end)
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
	local lying = CFrame.new(root.Position.X, groundY + 0.6, root.Position.Z) * yaw * CFrame.Angles(math.rad(-85), 0, 0) -- -85 = คว่ำ
	root.Anchored = true
	TweenService:Create(root, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = lying }):Play()
end

-- ลุกขึ้นจากท่าล้ม ตรงจุดเดิม หันทางเดิม เดินได้อีกครั้ง
local function standUp(player: Player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or not root.Anchored then
		return
	end
	local p = root.Position
	local look = Vector3.yAxis:Cross(root.CFrame.RightVector) -- ทิศหน้าเดิม (แกนขวาไม่เปลี่ยนตอนล้ม)
	root.CFrame = CFrame.lookAt(p + Vector3.new(0, 2.6, 0), p + Vector3.new(0, 2.6, 0) + Vector3.new(look.X, 0, look.Z))
	root.Anchored = false
	local sp = game:GetService("StarterPlayer")
	hum.WalkSpeed = sp.CharacterWalkSpeed
	hum.JumpPower = sp.CharacterJumpPower
	hum.JumpHeight = sp.CharacterJumpHeight
	hum.AutoRotate = true
end

-- ล้มตึงชั่วคราว แล้วลุกขึ้นมาเล่นต่อ (ตามผีไป)
local function knockDown(player: Player, seconds: number)
	collapse(player)
	task.delay(seconds, function()
		standUp(player)
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
-- ตายคนเดียว (คำสั่ง admin "kill:<UserId>"): ล้มนอน + จอตายเฉพาะคนนั้น ร้านเล่นต่อ กดเริ่มใหม่ = คนนั้นเกิดใหม่คนเดียว
local soloDead: { [Player]: boolean } = {}
local function killOne(p: Player)
	if soloDead[p] or losePending or not p.Character then
		return
	end
	soloDead[p] = true
	collapse(p)
	GameState:FireClient(p, "Lose")
	print("💀 [" .. p.Name .. "] ตาย (admin)")
end
-- ชุบชีวิต (คำสั่ง admin "revive:<UserId>"): คนที่ตายคนเดียวลุกขึ้นตรงที่ล้ม เล่นต่อได้ทันที จอตายปิด
-- (แพ้ทั้งร้านอยู่ = ชุบไม่ได้ ต้องกดเริ่มคืนใหม่)
local function reviveOne(p: Player)
	if not soloDead[p] or losePending then
		return
	end
	soloDead[p] = nil
	standUp(p)
	DeathChoice:FireClient(p, "revive") -- DeathScreen: ปิดจอตาย คืนกล้อง/การควบคุม
	print("✨ [" .. p.Name .. "] ชุบชีวิต (admin)")
end
Players.PlayerRemoving:Connect(function(p)
	soloDead[p] = nil
end)
DeathChoice.OnServerEvent:Connect(function(player, choice: any)
	if choice == "restart" and soloDead[player] and not losePending then
		soloDead[player] = nil
		DeathChoice:FireClient(player, "restart", player.DisplayName)
		task.delay(1.2, function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	elseif choice == "restart" and losePending and not restartBy then
		restartBy = player.DisplayName
		DeathChoice:FireAllClients("restart", player.DisplayName)
		print("🔁 [" .. player.Name .. "] เลือกเริ่มใหม่")
	elseif choice == "quit" then
		backToLobby(player)
	end
end)

-- ---------------------------------------------------------------- ปุ่มกด (ProximityPrompt)
local PROMPT_RANGE = 9 -- วัดถึงกลางชิ้นที่ติดปุ่ม (ตู้ใหญ่): ยืนหน้าตู้ = ราว 5-7
local function setupPrompt(name: string, rootInstance: Instance, targetPart: BasePart, hold: number, action: string, object: string): ProximityPrompt
	local existing: { ProximityPrompt } = {}
	for _, d in ipairs(rootInstance:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == name then
			table.insert(existing, d)
		end
	end
	for i = 2, #existing do
		existing[i]:Destroy()
	end
	local prompt = existing[1] or Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.Parent = targetPart
	prompt.HoldDuration = hold
	prompt.ActionText = action
	prompt.ObjectText = object
	-- ต้องเดินไปถึงหน้าวัตถุ (ไม่กดจากไกล) และหันไปมองมันด้วย (PromptFacing ฝั่ง client ปิดปุ่มเมื่อไม่ได้มอง)
	prompt.MaxActivationDistance = PROMPT_RANGE
	-- ไม่ใช้ RequiresLineOfSight: ชิ้นของตู้เอง (กระจก หัวจ่าย) บังจุดกลางตู้ ทำให้กดไม่ได้เลย
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("NeedsFacing", true)
	prompt:SetAttribute("Range", PROMPT_RANGE)
	prompt.AutoLocalize = false
	prompt.Enabled = false
	return prompt
end
-- ทิศถนน (จากจุดเกิดรถ -> ขาออก)
local ROAD_DIR = Vector3.new(stopPoint.Position.X - spawnPoint.Position.X, 0, stopPoint.Position.Z - spawnPoint.Position.Z).Unit

-- ตู้ 2: ดีเซล (น้ำมันสีเขียว) สำหรับรถยนต์ — ใช้ InteractiveProps.DieselPump ถ้าวางไว้เอง ไม่งั้น Clone ตู้ 1 ไปวางถัดไป
local dieselPump = pumpGroup:FindFirstChild("DieselPump") :: Model?
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
	c.Parent = pumpGroup
	dieselPump = c
end
local dieselBody = (dieselPump :: Model).PrimaryPart or ((dieselPump :: Model):FindFirstChild("GasPump") :: BasePart?) or ((dieselPump :: Model):FindFirstChild("PumpBase") :: BasePart?) or ((dieselPump :: Model):FindFirstChildWhichIsA("BasePart") :: BasePart)
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

local pumpPrompt = setupPrompt("PumpFuelPrompt", gasPump, pumpBody, 0, "Fill Petrol", "Petrol Pump")
local dieselPrompt = setupPrompt("DieselFuelPrompt", dieselPump :: Model, dieselBody, 0, "Fill Diesel", "Diesel Pump")
local airPrompt = setupPrompt("AirPumpPrompt", airCompressor or gasPump, airBody or pumpBody, 0, "Pump Air", "Air Compressor")
local rejectPrompt = setupPrompt("RejectCustomerPrompt", rejectRope, rejectRope, 0.4, "Close Shop", "Shutter Rope")
local openPrompt = setupPrompt("OpenShopPrompt", rejectRope, rejectRope, 0.4, "Open Shop", "Shutter Rope") -- ก่อนเริ่มคืน

-- ---------------------------------------------------------------- สถานะเกม
local money = 0
local incense = CONFIG.StartIncense
local gameOver = false
local currentVehicle: Model? = nil
local currentVehicleIsAnomaly = false
local currentAnomaly: string? = nil
local decision: string? = nil -- "fuel" | "reject" | nil
local decisionMade = Instance.new("BindableEvent")
local shopOpened = false
local isShutterOpen = false -- เริ่มต้นคืนปิดอยู่
local shutterTweening = false
local shutterRejectThread: thread? = nil
-- ต้องประกาศก่อน updateShutterPrompts ไม่งั้นฟังก์ชันนั้นจะอ่านตัวแปร global (nil) แทน ปุ่มปั๊มเลยไม่เคยเปิด
local servicePromptsOpen = false
local activeMinigamePlayer: Player? = nil
local currentSpeaker: any = nil
local decisionBy: string? = nil -- ชื่อผู้เล่นที่ตัดสินใจล่าสุด (เติม / ดึงแผง) ใช้นับสถิติ
local petrolLevel = 1 -- น้ำมันในหลอดตู้ 1 (0..1)
local dieselLevel = 1 -- ตู้ 2
local offeringUntil = math.huge -- ศาลคุ้มครองถึงเมื่อไหร่ (os.clock) เริ่มนับตอนเปิดร้าน
local offeringWarned = false
-- สถิติคืนนี้ (หน้าสรุปผลตอนชนะ)
type PStat = { name: string, fills: number, earned: number, ghosts: number, offerings: number }
local stats = { anomalies = 0, caught = 0, fooled = 0, offerings = 0, players = {} :: { [number]: PStat } }
local function pstat(who: string?): PStat?
	local p = who and Players:FindFirstChild(who)
	if not (p and p:IsA("Player")) then
		return nil
	end
	local s = stats.players[p.UserId]
	if not s then
		s = { name = p.DisplayName, fills = 0, earned = 0, ghosts = 0, offerings = 0 }
		stats.players[p.UserId] = s
	end
	return s
end
local function resetStats()
	stats.anomalies, stats.caught, stats.fooled, stats.offerings = 0, 0, 0, 0
	table.clear(stats.players)
end

local function publishState()
	remotes:SetAttribute("Money", money)
	remotes:SetAttribute("Incense", incense)
	remotes:SetAttribute("IsAnomaly", currentVehicleIsAnomaly)
	remotes:SetAttribute("Anomaly", currentAnomaly or "")
	remotes:SetAttribute("GameOver", gameOver)
	remotes:SetAttribute("PetrolLevel", petrolLevel)
	remotes:SetAttribute("DieselLevel", dieselLevel)
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
local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))
local Weather = require(script.Parent:WaitForChild("Weather"))
local Power = require(script.Parent:WaitForChild("Power"))
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

-- ล้อของรถ: แม่แบบเก่า (FrontWheel / RearWheel / SidecarWheel) และรถไทยจาก ThaiVehicleRigs (ทุกชิ้นใน Model "Wheels":
-- Wheel_FL, Wheel_F, Wheel_RL1 ...) เดิมหาแค่ชื่อแบบเก่า รถไทย (กระบะ เก๋ง ตุ๊กตุ๊ก รถแห่ ฯลฯ) ล้อจึงไม่หมุน
local function wheelsOf(v: Model): { BasePart }
	local list = {}
	for _, n in ipairs({ "FrontWheel", "RearWheel", "SidecarWheel" }) do
		local w = v:FindFirstChild(n)
		if w and w:IsA("BasePart") then
			table.insert(list, w)
		end
	end
	-- หา "Wheels" ทุกชั้น: จักรยานที่คนเดินเข็นมาอยู่ใต้ตัวคน (PushedBicycle)
	for _, group in ipairs(v:GetDescendants()) do
		if group.Name == "Wheels" and group:IsA("Model") then
			for _, d in ipairs(group:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

-- หมุนล้อตามระยะที่รถเคลื่อนไป step (studs) รอบแกนขวางของรถ / รัศมีของล้อแต่ละวง (ล้อเล็กหมุนเร็วกว่า)
local function spinWheels(wheels: { BasePart }, right: Vector3, step: number)
	for _, w in ipairs(wheels) do
		local r = math.max(w.Size.Y, w.Size.Z) / 2
		local c = w.Position
		w.CFrame = CFrame.new(c) * CFrame.fromAxisAngle(right, -step / math.max(r, 0.2)) * (w.CFrame - c)
	end
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
		spinWheels(wheels, v:GetPivot().RightVector, step)
	end)
	while not done do
		task.wait()
	end
end

-- ---------------------------------------------------------------- ฉากประกอบ (แผงสังกะสี, น้ำมันในหลอดแก้ว)
local openY = (shutterDoor:GetAttribute("OpenY") or 15.5)
local closedY = (shutterDoor:GetAttribute("ClosedY") or 6.0)

local function updateShutterPrompts()
	if not shopOpened then
		openPrompt.Enabled = true
		rejectPrompt.Enabled = false
		return
	end
	openPrompt.Enabled = not isShutterOpen and not shutterTweening
	rejectPrompt.Enabled = isShutterOpen and not shutterTweening

	-- ปั๊มน้ำมัน/ดีเซล/ลม จะกดได้เฉพาะตอนเปิดรับบริการ (ถ้าปิดแผงไล่ลูกค้าอยู่ จะกดไม่ได้)
	local canService = servicePromptsOpen and not shutterRejectThread
	pumpPrompt.Enabled = canService
	dieselPrompt.Enabled = canService
	airPrompt.Enabled = canService
end

local function closeShutter()
	if shutterTweening then return end
	shutterTweening = true
	updateShutterPrompts()
	SoundBank.PlayOneShot("ShutterCloseSlam", shutterDoor, 75, 2.0)
	local p = shutterDoor.Position
	local t = TweenService:Create(shutterDoor, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = Vector3.new(p.X, closedY, p.Z),
	})
	t:Play()
	t.Completed:Wait()
	isShutterOpen = false
	shutterTweening = false
	updateShutterPrompts()
end

local function openShutter()
	if shutterTweening then return end
	shutterTweening = true
	updateShutterPrompts()
	SoundBank.PlayOneShot("ShutterOpenPull", shutterDoor, 65, 2.2)
	local p = shutterDoor.Position
	local t = TweenService:Create(shutterDoor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = Vector3.new(p.X, openY, p.Z),
	})
	t:Play()
	t.Completed:Wait()
	isShutterOpen = true
	shutterTweening = false
	updateShutterPrompts()
end

local function toggleShutter(wantOpen: boolean, who: string?)
	if shutterTweening or not shopOpened or wantOpen == isShutterOpen then
		return
	end

	if wantOpen then
		-- ดึงแผงเปิดขึ้น
		if shutterRejectThread then
			task.cancel(shutterRejectThread)
			shutterRejectThread = nil
			print("↩️ เปิดแผงทันเวลา! ยกเลิกการนับถอยหลังปฏิเสธ")
			if currentVehicle and not decision and not currentVehicleIsAnomaly and currentSpeaker then
				say(pick({ "นึกว่าจะไม่ขายซะแล้ว", "ตกใจหมด นึกว่าแผงหล่นใส่", "ฮ่าๆ แผงมันฝืดเหรอช่าง?" }), currentSpeaker, nil, 2.2)
			end
		end
		openShutter()
	else
		-- ดึงแผงปิดลง
		closeShutter()
		ServiceMinigame:FireAllClients("close")

		-- Taco Anomaly Mechanic: ปิดแผงต่อหน้าลูกค้าที่กำลังรอรับบริการ
		if currentVehicle and not decision then
			print("🚧 แผงปิดต่อหน้าลูกค้า! เริ่มนับถอยหลัง 3.5 วินาที ถ้าไม่เปิดจะถือว่าปฏิเสธ...")
			task.delay(0.6, function()
				if not isShutterOpen and currentVehicle and not decision and currentSpeaker then
					if currentVehicleIsAnomaly then
						say("...", currentSpeaker, nil, 2.0)
					else
						say(pick({ "เอ้า ปิดทำไม?", "ฮัลโหล มีใครอยู่ไหม?", "เฮ้ย ปิดแผงทำไมเนี่ย?" }), currentSpeaker, nil, 2.2)
					end
				end
			end)

			if shutterRejectThread then
				task.cancel(shutterRejectThread)
			end
			shutterRejectThread = task.delay(3.5, function()
				shutterRejectThread = nil
				if not isShutterOpen and currentVehicle and not decision then
					print("⏱️ ปิดแผงใส่นานเกิน 3.5 วิ -> ถือว่าปฏิเสธลูกค้า/ไล่ผีสำเร็จ!")
					CoreLoop.Decide("reject", who or "Shutter")
				end
			end)
		end
	end
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
	-- หลอดว่างเปล่า = น้ำมันหายไปหมด (ไม่เหลือคราบก้นหลอด)
	if fuelLiquid:GetAttribute("BaseT") == nil then
		fuelLiquid:SetAttribute("BaseT", fuelLiquid.Transparency)
	end
	fuelLiquid.Transparency = if frac <= 0.001 then 1 else fuelLiquid:GetAttribute("BaseT")
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
	if dieselLiquid:GetAttribute("BaseT") == nil then
		dieselLiquid:SetAttribute("BaseT", dieselLiquid.Transparency)
	end
	dieselLiquid.Transparency = if frac <= 0.001 then 1 else dieselLiquid:GetAttribute("BaseT")
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
local function setServicePrompts(on: boolean)
	servicePromptsOpen = on
	if not on then
		activeMinigamePlayer = nil
	end
	updateShutterPrompts()
	if not on or not isShutterOpen then
		ServiceMinigame:FireAllClients("close")
	end
end

local DECIDE_TEXT = { fuel = "เติมน้ำมันหลอด", diesel = "เติมดีเซล", air = "เติมลม", reject = "ดึงแผงปิดร้าน!" }
function CoreLoop.Decide(choice: string, who: string?): boolean
	if decision or not currentVehicle or gameOver or not servicePromptsOpen then
		return false
	end
	decision = choice
	decisionBy = who
	setServicePrompts(false)
	print("[" .. (who or "?") .. "] " .. (DECIDE_TEXT[choice] or choice))
	decisionMade:Fire()
	return true
end

local function startMinigameForPlayer(player: Player, stationChoice: string)
	if decision or not currentVehicle or gameOver or not servicePromptsOpen then
		return
	end
	-- น้ำมันในตู้ไม่พอเติม 1 ครั้ง: ต้องไปเอาแกลลอนมาเทก่อน
	local level = if stationChoice == "fuel" then petrolLevel elseif stationChoice == "diesel" then dieselLevel else 1
	if level < CONFIG.FuelPerFill - 0.001 then
		Notice:FireClient(player, "FuelEmpty", 6)
		SoundBank.PlayOneShot("PumpCrankLoop", if stationChoice == "diesel" then dieselBody else pumpBody, 40, 0.6)
		return
	end
	Prayer.Stop(player)
	activeMinigamePlayer = player
	ServiceMinigame:FireClient(player, "open", stationChoice)
end

pumpPrompt.Triggered:Connect(function(player)
	startMinigameForPlayer(player, "fuel")
end)
dieselPrompt.Triggered:Connect(function(player)
	startMinigameForPlayer(player, "diesel")
end)
airPrompt.Triggered:Connect(function(player)
	startMinigameForPlayer(player, "air")
end)

ServiceMinigame.OnServerEvent:Connect(function(player, action: any, stationChoice: any)
	if action == "complete" and (stationChoice == "fuel" or stationChoice == "diesel" or stationChoice == "air") then
		activeMinigamePlayer = nil
		CoreLoop.Decide(stationChoice, player.Name)
	elseif action == "cancel" or action == "close" then
		if activeMinigamePlayer == player then
			activeMinigamePlayer = nil
		end
	end
end)

rejectPrompt.Triggered:Connect(function(player)
	if shopOpened then
		toggleShutter(false, player.Name)
	end
end)

openPrompt.Triggered:Connect(function(player)
	if not shopOpened then
		print("🔓 [" .. player.Name .. "] เปิดร้าน")
		shopOpened = true
	else
		toggleShutter(true, player.Name)
	end
end)

local Items: { [string]: any } = {} -- ของในบล็อกนี้ที่ใช้ข้างนอก (บล็อก do ลดจำนวน local ของสคริปต์ ไม่ให้เกิน 200)
do
-- ---------------------------------------------------------------- น้ำมันในตู้หมด -> แกลลอน + ถังน้ำมันหลังร้าน
-- หยิบแกลลอนในร้าน (ช่อง [3]) -> ตักน้ำมันจากถังหลังร้าน (ImportedYardProps.FuelDrum*) -> เทใส่ตู้หน้าร้าน (เต็มหลอด)
-- ของในร้าน (ชั้นแกลลอน / ถาดขนม) ถ้าผู้พัฒนาวางไว้เองใน InteractiveProps ชื่อ FuelCanSpot / DessertTray จะใช้ของนั้น
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
local function floorBelow(p: Vector3, ignore: { Instance }): Vector3
	floorParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(p, Vector3.new(0, -20, 0), floorParams)
	return if hit then hit.Position else p - Vector3.new(0, 3, 0)
end

local function weldAll(model: Instance, root: BasePart)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = d
		end
	end
end

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
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- แกลลอนน้ำมัน (ใช้ทั้งเป็นของวางในร้านและเป็น Handle ของ Tool) — ทรง/คราบ/เปลือกน้ำมัน อยู่ใน server/JerryCan
local buildCan = JerryCan.Build

-- ขนมตาลห่อใบตองวางบนใบตอง (ไม่มีขัน/จาน): จุดอ้างอิง = กลางใต้แผ่นใบตอง (วางบนพื้นผิวได้เลย)
--   ห่อทรงสูงยอดพับแหลม 3 ห่อเรียงด้านหลัง + ห่อที่แกะแล้วด้านหน้า (เนื้อขนมตาลเหลืองส้ม โรยมะพร้าวขูด)
--   ชิ้นชื่อขึ้นต้นด้วย "Sweet" = ขนม (มือผีที่ศาล ShrineHand หยิบไปเฉพาะชิ้นพวกนี้ ใบตองรองวางอยู่ต่อ)
-- ถ้านำเข้า LeafSweets.fbx ไว้ที่ ServerStorage.ImportedProps.LeafSweets (Model: LeafTray, OpenWrap, SweetCake, Wrapped;
-- pivot = กลางใต้ใบตอง) จะใช้โมเดลนั้นแทน — ชิ้นที่ถือ/ถวายไม่เอา Wrapped (ห่อที่ยังไม่แกะอยู่ที่จุดหยิบ)
local LEAF = Color3.fromRGB(78, 128, 52)
local LEAF_LIGHT = Color3.fromRGB(104, 152, 62)
local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.Anchored = true
	w.CanCollide = false
	w.CastShadow = false
	w.Parent = parent
	return w
end
local function buildLeafSweets(parent: Instance, cf: CFrame, leafName: string?, wrapped: boolean?): BasePart
	local imported = ServerStorage:FindFirstChild("ImportedProps") and ServerStorage.ImportedProps:FindFirstChild("LeafSweets")
	if imported and imported:IsA("Model") and imported:FindFirstChild("LeafTray") then
		local m = imported:Clone()
		local leaf = m:FindFirstChild("LeafTray") :: BasePart
		local rel = m:GetPivot()
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and (wrapped or d.Name ~= "Wrapped") then
				d.CFrame = cf * rel:ToObjectSpace(d.CFrame)
				d.Anchored = true
				d.CanCollide = false
				d.Parent = parent
			end
		end
		leaf.Name = leafName or "Handle"
		m:Destroy()
		return leaf
	end
	-- แผ่นใบตอง: สี่เหลี่ยมกลาง + ปลายแหลมสองด้าน (ลิ่ม) + เส้นกลางใบ (ชิ้นเดียวที่แกะแล้ว = ใบเล็กลง)
	local k = if wrapped then 1 else 0.55
	local leaf = propPart(parent, leafName or "Handle", Vector3.new(1.0 * k, 0.04, 0.78 * k), cf * CFrame.new(0, 0.02, 0), LEAF)
	for _, sg in ipairs({ -1, 1 }) do
		local tipCF = cf * CFrame.new(sg * 0.68 * k, 0.02, 0) * CFrame.Angles(0, if sg > 0 then math.rad(-90) else math.rad(90), 0)
		wedge(parent, "LeafTipA", Vector3.new(0.39 * k, 0.04, 0.36 * k), tipCF * CFrame.new(0.195 * k, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), LEAF)
		wedge(parent, "LeafTipB", Vector3.new(0.39 * k, 0.04, 0.36 * k), tipCF * CFrame.new(-0.195 * k, 0, 0) * CFrame.Angles(0, 0, math.rad(-90)), LEAF)
	end
	propPart(parent, "LeafRib", Vector3.new(1.5 * k, 0.045, 0.03), cf * CFrame.new(0, 0.022, 0), LEAF_LIGHT)
	-- ขนมตาลชิ้นที่แกะแล้ว (ชิ้นที่ถือ/ถวาย): ใบตองห่อคลี่ + เนื้อขนมตาล + มะพร้าวขูด
	--   ใบตองห่อไม่ขึ้นต้นด้วย "Sweet" = มือผีหยิบไปแค่ชิ้นขนม ใบตองวางอยู่ที่เดิม
	local open = cf * CFrame.new(0, 0.05, if wrapped then -0.2 else 0) * CFrame.Angles(0, math.rad(25), 0)
	propPart(parent, "OpenWrap", Vector3.new(0.46, 0.025, 0.3), open, LEAF_LIGHT)
	-- ขนมตาลก้อนกลม (ทรงกลมอย่างเดียว) โรยมะพร้าวขูดบนหัว
	propPart(parent, "Sweet_Cake", Vector3.new(0.24, 0.24, 0.24), open * CFrame.new(0, 0.13, 0), Color3.fromRGB(244, 168, 44), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for n = 1, 5 do
		propPart(parent, "Sweet_Coconut" .. n, Vector3.new(0.09, 0.025, 0.02), open * CFrame.new((n - 3) * 0.025, 0.25, (n % 2 - 0.5) * 0.04) * CFrame.Angles(0, math.rad(n * 47), 0), Color3.fromRGB(246, 244, 236), Enum.Material.Fabric)
	end
	if not wrapped then
		return leaf
	end
	-- ถาดที่หยิบ: ห่อขนมตาลที่ยังไม่แกะ 3 ห่อ ตั้งเรียงด้านหลังของใบ (ฝั่ง +Z) — วางอยู่ที่เดิม ไม่ได้หยิบติดมือไป
	local WRAP = { Color3.fromRGB(104, 150, 62), Color3.fromRGB(88, 136, 54), Color3.fromRGB(116, 160, 70) }
	for i = 1, 3 do
		local base = cf * CFrame.new((i - 2) * 0.26, 0.04 + 0.15, 0.14) * CFrame.Angles(0, math.rad((i - 2) * 10), 0)
		local col = WRAP[i]
		propPart(parent, "Wrapped" .. i, Vector3.new(0.22, 0.3, 0.17), base, col)
		local roof = 0.2
		wedge(parent, "Wrapped" .. i .. "_TopL", Vector3.new(0.22, roof, 0.085), base * CFrame.new(0, 0.15 + roof / 2, -0.0425), col)
		wedge(parent, "Wrapped" .. i .. "_TopR", Vector3.new(0.22, roof, 0.085), base * CFrame.new(0, 0.15 + roof / 2, 0.0425) * CFrame.Angles(0, math.rad(180), 0), col)
		propPart(parent, "Wrapped" .. i .. "_Pin", Vector3.new(0.3, 0.025, 0.025), base * CFrame.new(0, 0.15 + roof * 0.45, 0), Color3.fromRGB(205, 186, 140))
	end
	return leaf
end

-- จุดมือในท่าถือ เทียบ HumanoidRootPart (สะโพก 3.08 เหนือพื้น) — ค่าจาก server/Pedestrian (HUMAN_LEFT_HAND / HUMAN_RIGHT_HAND)
local HELD_REST: { [string]: CFrame } = {
	FuelCan = CFrame.new(-1.41, 2.97 - 3.08 - 0.79, -0.25), -- ท่า carry_gallon_l มือซ้ายห้อยข้างตัว (หูแกลลอนในกำมือ)
	ThaiDessert = CFrame.new(-0.9, 3.4 - 3.08, -1.2), -- ท่า hold_tray_l มือซ้ายแบหงายหน้าท้อง ใบตองขนมบนฝ่ามือ
}

local function makeTool(name: string, build: (Instance, CFrame) -> Part, grip: CFrame, scale: number?): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = grip
	local handle = build(tool, CFrame.new())
	if scale and scale ~= 1 then -- ย่อรอบจุดอ้างอิง (จุดที่มือกำอยู่กับที่)
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Size *= scale
				d.CFrame = CFrame.new(d.Position * scale) * d.CFrame.Rotation
			end
		end
	end
	tool:SetAttribute("GripOffset", handle.CFrame) -- Handle เทียบจุดอ้างอิงของ build (client/HeldItems ใช้วางของในมือ)
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	weldAll(tool, handle)
	-- ตัวผู้เล่นชาวบ้านไม่มีแขน RightHand ให้ Roblox จับ Tool (ของร่วงพื้น/มองไม่เห็นในมือ):
	-- ถืออยู่ = เชื่อม Handle กับ HumanoidRootPart (Weld "VillagerGrip") ที่ตำแหน่งมือในท่าถือ
	-- แต่ละเครื่องเลื่อน C0 ให้ตรงกระดูกมือจริงทุกเฟรม (client/HeldItems) — ค่าตรงนี้แค่ตำแหน่งตั้งต้น
	local rest = HELD_REST[name] or CFrame.new(0, 0, -1.5)
	tool:GetPropertyChangedSignal("Parent"):Connect(function()
		local old = handle:FindFirstChild("VillagerGrip")
		local char = tool.Parent
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (char and root and char:FindFirstChild("RootPart")) then
			if old then
				old:Destroy()
			end
			return
		end
		local w = (old or Instance.new("Weld")) :: Weld
		w.Name = "VillagerGrip"
		w.Part0 = root
		w.Part1 = handle
		-- มือที่ถือของ = มืออีกข้างจากไฟฉาย (ตั้งค่า FlashHand ค่าเริ่มต้นขวา -> ของอยู่มือซ้าย = HELD_REST)
		local pl = Players:GetPlayerFromCharacter(char)
		local itemRight = pl ~= nil and pl:GetAttribute("FlashHand") == "L"
		w.C0 = if itemRight then CFrame.new(-rest.X, rest.Y, rest.Z) * rest.Rotation else rest
		w.C1 = CFrame.new()
		w.Parent = handle
	end)
	return tool
end

local function findTool(player: Player, name: string): Tool?
	local char = player.Character
	local t = char and char:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil
end

-- ต้องถืออยู่ในมือ (ไม่ใช่แค่อยู่ในกระเป๋า)
local function heldTool(player: Player, name: string): Tool?
	local t = player.Character and player.Character:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil
end

local function giveTool(player: Player, tool: Tool)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		tool.Parent = bp
	else
		tool:Destroy()
	end
end

-- fuel = "Petrol" (ถังแดง -> ตู้หลอดแดงเท่านั้น) | "Diesel" (ถังน้ำเงิน -> ตู้ดีเซลเขียวเท่านั้น)
local CAN_DIESEL = Color3.fromRGB(110, 190, 90)
local function setCanFull(tool: Tool, full: boolean, fuel: string?)
	tool:SetAttribute("Full", full)
	tool:SetAttribute("Fuel", if full then fuel else nil)
	-- เต็ม = น้ำมันทะลุพลาสติก (เบนซินชมพูแดง / ดีเซลเขียว), เปล่า = ขาว
	JerryCan.SetFull(tool, full, if fuel == "Diesel" then CAN_DIESEL else nil)
end

-- ชั้นวางแกลลอนในร้าน (มุมหลังร้านฝั่งซ้าย) + ถาดขนมบนโต๊ะเคาน์เตอร์
local shack = Workspace:WaitForChild("MapEnvironment"):WaitForChild("ShackStructure") :: Model
local shackCF, shackSize = shack:GetBoundingBox()
local function insideShop(pos: Vector3): boolean
	local lp = shackCF:PointToObjectSpace(pos)
	return math.abs(lp.X) < shackSize.X / 2 - 0.4 and pos.Z > shutterDoor.Position.Z + 0.3 and lp.Z < shackSize.Z / 2
end

local canSpot = interactive:FindFirstChild("FuelCanSpot") :: Instance?
if not canSpot then
	local m = Instance.new("Model")
	m.Name = "FuelCanSpot"
	local floor = floorBelow(Vector3.new(shackCF.Position.X - shackSize.X / 2 + 3.5, rejectRope.Position.Y, shackCF.Position.Z + shackSize.Z / 2 - 4), { m })
	local body = buildCan(m, CFrame.new(floor + Vector3.new(0, 0.43, 0)) * CFrame.Angles(0, math.rad(30), 0))
	body.Name = "CanBody"
	m.PrimaryPart = body
	m.Parent = interactive
	canSpot = m
end
local canSpotPart = ((canSpot :: Instance):IsA("BasePart") and canSpot or (canSpot :: Model).PrimaryPart or (canSpot :: Instance):FindFirstChildWhichIsA("BasePart", true)) :: BasePart
local takeCanPrompt = setupPrompt("TakeCanPrompt", canSpot :: Instance, canSpotPart, 0, "Take", "Jerry Can")
-- หยิบของในร้าน: ต้องเดินเข้าไปถึงตัวของ (ไม่กดจากหลังร้าน/ทะลุผนัง: client/PromptFacing เช็กผนังบัง + เลือกปุ่มที่ใกล้สุด)
local TAKE_RANGE = 5
takeCanPrompt.MaxActivationDistance = TAKE_RANGE
takeCanPrompt:SetAttribute("Range", TAKE_RANGE)
takeCanPrompt:SetAttribute("HideIfHasTool", "FuelCan") -- มีแกลลอนอยู่แล้ว ไม่ขึ้นปุ่มหยิบเพิ่ม
takeCanPrompt.Enabled = true

-- ถังหลังร้าน 1:1 กับตู้หน้าร้าน: ถังแดง (FuelDrum_Red) = เบนซิน -> ตู้หลอดแดงเท่านั้น, ถังน้ำเงิน (FuelDrum) = ดีเซล -> ตู้ดีเซลเขียวเท่านั้น
local drums: { { part: BasePart, fuel: string? } } = {}
do
	local yard = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("ImportedYardProps")
	for _, pair in ipairs({ { "FuelDrum_Red", "Petrol" }, { "FuelDrum", "Diesel" } }) do
		local d = yard and yard:FindFirstChild(pair[1])
		if d and d:IsA("BasePart") then
			table.insert(drums, { part = d, fuel = pair[2] })
		end
	end
	if #drums == 0 then
		-- ไม่มีถังในฉาก: วางถังสำรองหลังร้าน (ถังเดียว เทได้ทั้ง 2 ตู้)
		local pos = floorBelow(Vector3.new(shackCF.Position.X - shackSize.X / 2 + 5, shackCF.Position.Y + 6, shackCF.Position.Z + shackSize.Z / 2 + 3), {})
		table.insert(drums, { part = propPart(interactive, "FuelDrum", Vector3.new(3, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 70, 120), Enum.Material.Metal, Enum.PartType.Cylinder), fuel = nil })
	end
end
for _, entry in ipairs(drums) do
	local drum, fuel = entry.part, entry.fuel
	local fp = setupPrompt("FillCanPrompt", drum, drum, CONFIG.CanFillTime, "Fill Can", if fuel == "Petrol" then "Petrol Drum" elseif fuel == "Diesel" then "Diesel Drum" else "Fuel Drum")
	fp.Enabled = true
	fp:SetAttribute("NeedsTool", "FuelCan") -- ต้องถือแกลลอนในมือก่อน
	fp.Triggered:Connect(function(player)
		local can = heldTool(player, "FuelCan")
		if not can or can:GetAttribute("Full") then
			Notice:FireClient(player, "NeedCan", 3)
			return
		end
		setCanFull(can, true, fuel)
		SoundBank.PlayOneShot("FuelGlugLoop", drum, 45, 1.6)
		print("🛢️ [" .. player.Name .. "] ตักน้ำมัน " .. tostring(fuel) .. " ใส่แกลลอน")
	end)
end

local pourPetrolPrompt = setupPrompt("PourPetrolPrompt", gasPump, pumpBody, CONFIG.CanPourTime, "Pour Fuel", "Petrol Pump")
local pourDieselPrompt = setupPrompt("PourDieselPrompt", dieselPump :: Model, dieselBody, CONFIG.CanPourTime, "Pour Diesel", "Diesel Pump")
-- ปุ่มเทใช้ E เหมือนทุกปุ่ม: ถือแกลลอนอยู่ = ขึ้นแต่ปุ่มเท (client/PromptFacing ซ่อนปุ่มเติมให้ลูกค้าบนตู้เดียวกัน)
for _, pp in ipairs({ pourPetrolPrompt, pourDieselPrompt }) do
	pp:SetAttribute("NeedsTool", "FuelCan")
end
local function updatePourPrompts()
	pourPetrolPrompt.Enabled = petrolLevel < CONFIG.PourBelow
	pourDieselPrompt.Enabled = dieselLevel < CONFIG.PourBelow
	publishState()
end
-- แผงน้ำมันขวดหน้าร้าน (ShackDressing.FuelBottleRack): ประกอบฉากเท่านั้น ไม่ได้ขาย / ไม่มีปุ่มเติม
-- ขวดตามสีตู้: ว่างตอนเริ่มคืนเหมือนตู้ เทแกลลอนใส่ตู้หลอด = ขวดแดง (FuelRed) เต็ม, ตู้ดีเซล = ขวดเขียว (FuelGreen) เต็ม
local rackModel = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("FuelBottleRack", true)
local function rackPart(name: string): BasePart?
	local part = rackModel and rackModel:FindFirstChild(name)
	if part and part:IsA("BasePart") then
		if part:GetAttribute("BaseT") == nil then
			part:SetAttribute("BaseT", part.Transparency)
		end
		return part
	end
	return nil
end
local rackRed, rackGreen = rackPart("FuelRed"), rackPart("FuelGreen")
local function showRack(part: BasePart?, on: boolean)
	if part then
		part.Transparency = if on then (part:GetAttribute("BaseT") or 0) else 1
	end
end
local function setRackFilled(petrolOn: boolean, dieselOn: boolean?)
	showRack(rackRed, petrolOn)
	showRack(rackGreen, if dieselOn == nil then petrolOn else dieselOn)
end
local function pour(player: Player, diesel: boolean)
	local can = heldTool(player, "FuelCan")
	if not (can and can:GetAttribute("Full")) then
		Notice:FireClient(player, "NeedCan", 3)
		return
	end
	-- 1:1 ถังกับตู้: แกลลอนจากถังแดงเทได้แค่ตู้หลอด, ถังน้ำเงินเทได้แค่ตู้ดีเซล (ถังสำรองไม่มีชนิด = เทได้ทั้งคู่)
	local fuel = can:GetAttribute("Fuel")
	if fuel ~= nil and fuel ~= (if diesel then "Diesel" else "Petrol") then
		Notice:FireClient(player, if diesel then "WrongCanDiesel" else "WrongCanPetrol", 4)
		return
	end
	setCanFull(can, false)
	SoundBank.PlayOneShot("FuelGlugLoop", if diesel then dieselBody else pumpBody, 50, 2.0)
	if diesel then
		dieselLevel = 1
		setDieselLevel(1, 2.5)
		showRack(rackGreen, true)
	else
		petrolLevel = 1
		setFuelLevel(1, 2.5)
		showRack(rackRed, true)
	end
	updatePourPrompts()
	print("⛽ [" .. player.Name .. "] เทน้ำมันใส่ตู้ " .. (if diesel then "ดีเซล" else "หลอด") .. " เต็มแล้ว")
end
pourPetrolPrompt.Triggered:Connect(function(player)
	pour(player, false)
end)
pourDieselPrompt.Triggered:Connect(function(player)
	pour(player, true)
end)

takeCanPrompt.Triggered:Connect(function(player)
	if findTool(player, "FuelCan") then
		return
	end
	local can = makeTool("FuelCan", buildCan, CFrame.new(0, -0.79, -0.15))
	setCanFull(can, false)
	giveTool(player, can)
end)

-- ใช้น้ำมันจากตู้ 1 ครั้ง (เติมให้ลูกค้า/ผี) แล้วเตือนถ้าใกล้หมด
local function useFuel(diesel: boolean, time: number): Tween?
	local t
	if diesel then
		dieselLevel = math.max(0, dieselLevel - CONFIG.FuelPerFill)
		t = setDieselLevel(dieselLevel, time)
	else
		petrolLevel = math.max(0, petrolLevel - CONFIG.FuelPerFill)
		t = setFuelLevel(petrolLevel, time)
	end
	updatePourPrompts()
	local left = if diesel then dieselLevel else petrolLevel
	if left < CONFIG.FuelPerFill - 0.001 then
		Notice:FireAllClients("FuelEmpty", 6)
	elseif left < CONFIG.FuelPerFill * 2 - 0.001 then
		Notice:FireAllClients("FuelLow", 3)
	end
	return t
end

-- ---------------------------------------------------------------- ขนมไทยถวายศาลพระภูมิ (ช่อง [2])
local tray = interactive:FindFirstChild("DessertTray") :: Instance?
if not tray then
	local m = Instance.new("Model")
	m.Name = "DessertTray"
	local counter = shack:FindFirstChild("CounterTable", true) :: BasePart?
	local top = if counter then counter.Position + Vector3.new(2.6, counter.Size.Y / 2, 0) else floorBelow(shackCF.Position + Vector3.new(2, 0, 0), {}) + Vector3.new(0, 3, 0)
	top = floorBelow(top + Vector3.new(0, 1.5, 0), { m })
	local plate = buildLeafSweets(m, CFrame.new(top), "TrayPlate", true)
	m.PrimaryPart = plate
	m.Parent = interactive
	tray = m
end
local trayPart = ((tray :: Instance):IsA("BasePart") and tray or (tray :: Model).PrimaryPart or (tray :: Instance):FindFirstChildWhichIsA("BasePart", true)) :: BasePart
local takeDessertPrompt = setupPrompt("TakeDessertPrompt", tray :: Instance, trayPart, 0, "Take sweets", "Sweets tray")
takeDessertPrompt.MaxActivationDistance = TAKE_RANGE
takeDessertPrompt:SetAttribute("Range", TAKE_RANGE)
takeDessertPrompt:SetAttribute("HideIfHasTool", "ThaiDessert")
takeDessertPrompt.Enabled = true
local function giveDessert(player: Player)
	if not findTool(player, "ThaiDessert") then
		-- ขนมตาลชิ้นที่แกะแล้วบนใบตอง วางบนฝ่ามือที่แบหงาย (ย่อ 75% ไม่บังจอมุมบุคคลที่ 1)
		giveTool(player, makeTool("ThaiDessert", buildLeafSweets, CFrame.new(), 0.75))
	end
end
takeDessertPrompt.Triggered:Connect(giveDessert)

local shrineBody = (spirit:FindFirstChild("SpiritHouseOnStilts") or spirit:FindFirstChildWhichIsA("BasePart", true)) :: BasePart
local offerPrompt = setupPrompt("OfferDessertPrompt", spirit, shrineBody, 1.0, "Offer sweets", "Spirit House")
offerPrompt.MaxActivationDistance = 11
offerPrompt:SetAttribute("Range", 11)
offerPrompt:SetAttribute("NeedsTool", "ThaiDessert") -- ต้องถือขนมในมือก่อน
offerPrompt.Enabled = true
local offeredPlate: Model? = nil
offerPrompt.Triggered:Connect(function(player)
	local d = heldTool(player, "ThaiDessert")
	if not d then
		Notice:FireClient(player, "ShrineHungry", 4)
		return
	end
	d:Destroy()
	offeringUntil = os.clock() + CONFIG.OfferingDuration
	offeringWarned = false
	stats.offerings += 1
	local s = pstat(player.Name)
	if s then
		s.offerings += 1
	end
	-- จานขนมวางหน้าศาลข้างธูป (หายไปเมื่อหมดเวลาคุ้มครอง)
	if offeredPlate then
		offeredPlate:Destroy()
	end
	-- ขนมตาลบนใบตองวางบนแท่นหน้าศาลข้างกระถางธูป (ย่อ 80% ให้พอดีศาล) แล้วสักพักมือผียื่นออกมาหยิบขนมเข้าไปในศาล
	do
		local m = Instance.new("Model")
		m.Name = "OfferedSweets"
		local _, spot = ShrineHand.Spots(spirit, shrineBody)
		local base = floorBelow(spot + Vector3.new(0, 0.6, 0), { m, spirit:FindFirstChild("Incense1") :: Instance, spirit:FindFirstChild("Incense2") :: Instance, spirit:FindFirstChild("Incense3") :: Instance })
		if base.Y < spot.Y - 1.5 then
			base = spot - Vector3.new(0, 0.4, 0) -- ทะลุรูของ collision ลงไปถึงพื้น: วางระดับระเบียงศาลแทน
		end
		local _, ry = shrineBody.CFrame:ToOrientation()
		buildLeafSweets(m, CFrame.new(base) * CFrame.Angles(0, ry, 0), "LeafTray")
		for _, part in ipairs(m:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size *= 0.8 -- ขนมชิ้นเดียวบนใบตอง ย่อนิดหน่อยให้พอดีแท่นหน้าศาล
				part.CFrame = CFrame.new(base + (part.Position - base) * 0.8) * part.CFrame.Rotation
			end
		end
		m.Parent = spirit
		offeredPlate = m
		ShrineHand.Take(m, spirit, shrineBody, nil, function(at: BasePart): Sound?
			-- เสียงตอนมือผีออกมาหยิบขนม (ดัง 50% ของไฟล์) ShrineHand เฟดลงเองถ้าหยิบจบก่อนเสียงจบ
			local s = Instance.new("Sound")
			s.Name = "GhostTakeSound"
			s.SoundId = "rbxassetid://75963826001031"
			s.Volume = 0.5
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 6
			s.RollOffMaxDistance = 40
			s.Parent = at
			s.Ended:Connect(function()
				s:Destroy()
			end)
			s:Play()
			return s
		end)
	end
	SoundBank.PlayOneShot("CoinTinDrop1", shrineBody, 40, 1.2)
	Notice:FireAllClients("ShrineOffered", 4)
	remotes:SetAttribute("Cursed", false)
	print("🍡 [" .. player.Name .. "] ถวายขนมศาลพระภูมิ คุ้มครองอีก " .. CONFIG.OfferingDuration .. " วิ")
end)
-- เกิดใหม่/ตื่นมา: ไม่มีขนมติดตัว ต้องไปหยิบที่ถาดขนมในร้านเอง (ผู้ใช้ขอ 2026-11-03)

local function cursed(): boolean
	return remotes:GetAttribute("ShopOpen") == true and not gameOver and os.clock() > offeringUntil
end

-- อาการตอนศาลไม่คุ้มครอง: สุ่มคนที่ยังยืนอยู่ (ไม่นอนล้ม) โดนทีละ 1 อาการ
local CURSE_WHISPER = { "Curse_Whisper_1", "Curse_Whisper_2", "Curse_Whisper_3", "Curse_Whisper_4" }
local slowUntil: { [Player]: number } = {}
local function curseOne(p: Player, symptom: string?)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not (root and hum) or root.Anchored or hum.Health <= 0 then
		return
	end
	local s = symptom or pick({ "drowsy", "drowsy", "shake", "slow", "stumble" })
	if s == "drowsy" then
		-- เสียงกระซิบข้างหู + ตาปรือจะหลับ (ฝั่ง Client เห็นเสียงกระซิบแล้วเล่นตาปรือเอง)
		CustomerSpeech:FireClient(p, pick(CURSE_WHISPER), nil, { ghost = "WhisperSpeaker" }, nil)
		task.delay(3.4, function()
			CustomerSpeech:FireClient(p, nil)
		end)
	elseif s == "slow" then
		slowUntil[p] = os.clock() + 8
		hum.WalkSpeed = CONFIG.CurseSlowSpeed
		Curse:FireClient(p, "slow", 8)
		task.delay(8.1, function()
			if slowUntil[p] and os.clock() >= slowUntil[p] then
				slowUntil[p] = nil
				local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if h and r and not r.Anchored and h.WalkSpeed == CONFIG.CurseSlowSpeed then
					h.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed
				end
			end
		end)
	elseif s == "stumble" then
		-- เดินๆ อยู่สะดุดล้ม (ยืนนิ่ง/พนมมือ = ใช้อาการอื่นแทน)
		if hum.MoveDirection.Magnitude > 0.1 and not Prayer.Duration(p) then
			Curse:FireClient(p, "stumble", 2.5)
			knockDown(p, 2.2)
		else
			Curse:FireClient(p, "shake", 2.5)
		end
	else
		Curse:FireClient(p, s, if s == "shake" then 2.5 else 5)
	end
	print("🌑 ศาลไม่คุ้มครอง [" .. p.Name .. "] " .. s)
end

task.spawn(function()
	while true do
		task.wait(1)
		local open = remotes:GetAttribute("ShopOpen") == true and not gameOver
		-- แถบนับถอยหลังศาลบน HUD (ItemSlots.client): วินาทีที่ศาลยังคุ้มครอง (0 = ไม่คุ้มครองแล้ว, -1 = ยังไม่เริ่มคืน)
		remotes:SetAttribute("OfferingLeft", if open and offeringUntil < math.huge then math.max(0, math.floor(offeringUntil - os.clock())) else -1)
		remotes:SetAttribute("OfferingTotal", CONFIG.OfferingDuration)
		if open and offeringUntil < math.huge then
			local left = offeringUntil - os.clock()
			if left <= CONFIG.OfferingWarn and left > 0 and not offeringWarned then
				offeringWarned = true
				Notice:FireAllClients("ShrineHungry", 5)
			end
		end
		if cursed() then
			if remotes:GetAttribute("Cursed") ~= true then
				remotes:SetAttribute("Cursed", true)
				Notice:FireAllClients("ShrineCursed", 5)
				if offeredPlate then
					offeredPlate:Destroy()
					offeredPlate = nil
				end
			end
			task.wait(CONFIG.CurseEvery[1] + math.random() * (CONFIG.CurseEvery[2] - CONFIG.CurseEvery[1]))
			if cursed() then
				local ps = Players:GetPlayers()
				if #ps > 0 then
					curseOne(ps[math.random(#ps)])
				end
			end
		end
	end
end)

	Items.insideShop = insideShop
	Items.updatePourPrompts = updatePourPrompts
	Items.useFuel = useFuel
	Items.giveDessert = giveDessert
	Items.curseOne = curseOne
	Items.cursed = cursed
	Items.setRackFilled = setRackFilled
	Items.shack = shack
	Items.clearOffering = function()
		if offeredPlate then
			offeredPlate:Destroy()
			offeredPlate = nil
		end
	end
end

-- ทดสอบจาก Command Bar / เครื่องมือ: ServerStorage.DevDecision:Fire("fuel" | "reject")
-- (require โมดูลนี้จาก Command Bar จะได้สำเนาใหม่คนละตัวกับที่เกมใช้ จึงต้องสั่งผ่าน BindableEvent)
local devDecision = ServerStorage:FindFirstChild("DevDecision") or Instance.new("BindableEvent")
devDecision.Name = "DevDecision"
devDecision.Parent = ServerStorage
local chooseReply: (string, string, string?) -> boolean
local devSpawn: (string) -> ()
local devRoadEvent: (string) -> ()
-- shopOpened is declared in state section
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
	elseif string.sub(choice, 1, 8) == "scenery:" then
		-- ทดสอบผีฉาก: "scenery:Tani" / "scenery:Scarecrow" / "scenery:Shadow" / "scenery:hide"
		local k = string.sub(choice, 9)
		for _, kk in ipairs(AnomalyManager.SceneryKinds) do
			AnomalyManager.HideScenery(kk)
		end
		if k ~= "hide" then
			AnomalyManager.ShowScenery(k)
		end
	elseif choice == "rain" or choice == "clear" then
		Weather.Set(choice == "rain")
	elseif choice == "powercut" then
		Power.Cut() -- ไฟร้านดับ ต้องไปสตาร์ทเครื่องปั่นไฟ
	elseif choice == "incense1" then
		incense = 1 -- ทดสอบ: เหลือธูปดอกสุดท้าย
		refreshIncense()
		broadcastHUD()
	elseif string.sub(choice, 1, 5) == "kill:" then
		local p = Players:GetPlayerByUserId(tonumber(string.sub(choice, 6)) or 0)
		if p then
			killOne(p) -- ผู้เล่นคนนี้ตายคนเดียว (แผง admin)
		end
	elseif string.sub(choice, 1, 7) == "revive:" then
		local p = Players:GetPlayerByUserId(tonumber(string.sub(choice, 8)) or 0)
		if p then
			reviveOne(p) -- ชุบคนที่ตาย (แผง admin)
		end
	elseif choice == "lose" then
		incense = 0 -- ทดสอบฉากตาย: คันถัดไปจบเกม (หรือทันทีถ้าไม่มีลูกค้า)
		refreshIncense()
		broadcastHUD()
	elseif choice == "restart" then
		if losePending and not restartBy then
			restartBy = "DevDecision"
			DeathChoice:FireAllClients("restart", "DevDecision")
		end
	elseif choice == "fuelempty" or choice == "fuelfull" then
		-- น้ำมันในตู้หมด (ทดสอบแกลลอน + ถังหลังร้าน) / เติมเต็ม
		local lv = if choice == "fuelempty" then 0 else 1
		petrolLevel, dieselLevel = lv, lv
		setFuelLevel(lv, 1)
		setDieselLevel(lv, 1)
		Items.setRackFilled(lv == 1)
		Items.updatePourPrompts()
		if lv == 0 then
			Notice:FireAllClients("FuelEmpty", 6)
		end
	elseif choice == "hungry" then
		-- ศาลหมดเวลาคุ้มครองทันที (เริ่มอาการแปลกๆ) — ต้องเปิดร้านแล้ว
		offeringUntil = os.clock() - 1
		offeringWarned = true
	elseif choice == "offer" then
		offeringUntil = os.clock() + CONFIG.OfferingDuration
		offeringWarned = false
		remotes:SetAttribute("Cursed", false)
		Notice:FireAllClients("ShrineOffered", 4)
	elseif choice == "dessert" then
		for _, p in ipairs(Players:GetPlayers()) do
			Items.giveDessert(p)
		end
	elseif string.sub(choice, 1, 6) == "curse:" then
		-- อาการเดียวกับตอนศาลไม่คุ้มครอง ใส่ทุกคนทันที: drowsy / shake / slow / stumble
		for _, p in ipairs(Players:GetPlayers()) do
			Items.curseOne(p, string.sub(choice, 7))
		end
	elseif choice == "intro" then
		task.spawn(Cutscene.Intro) -- เล่นคัทซีนเปิดคืนซ้ำ (ร้านเปิดอยู่แล้วก็เล่นได้)
	elseif choice == "win" then
		money = math.max(money, CONFIG.TargetMoney) -- ลูปเกมจับได้แล้วเข้าคัทซีนเช้า + สรุปผล
		broadcastHUD()
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

-- จุดที่คันหน้าสุดไปจอดรับบริการ: น้ำมันหลอด / ดีเซล = StopPoint หน้าร้าน (ตู้ 2 อยู่ข้างตู้ 1 ที่ไฟส่องถึง), เติมลม = หน้าถังลม
local function serviceTarget(service: string): Vector3
	local stop = stopPoint.Position
	local p = stop
	if service == "air" then
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

-- ไฟหน้าส่องถนนให้เห็นแสงมาก่อนตัวรถ: ดันจุดกำเนิดแสงออกไปหน้าเลนส์ (เดิมอยู่กลางชิ้นไฟที่ฝังในตัวถัง
-- SpotLight ที่เปิดเงาจึงโดนตัวถังบังจนแทบไม่มีแสงลงพื้น) แล้วส่องไกลขึ้น
local HEADLIGHT_PUSH = 1.2
local function brightenHeadlights(m: Model)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("SpotLight") and d.Name == "HeadlightBeam" then
			local att = d.Parent
			if att and att:IsA("Attachment") and not att:GetAttribute("Pushed") then
				att:SetAttribute("Pushed", true)
				att.WorldCFrame = att.WorldCFrame * CFrame.new(0, 0, -HEADLIGHT_PUSH)
			end
			d.Enabled = true
			if d.Range >= 40 then -- จักรยาน (ไฟดวงเล็ก ระยะ 26) คงเดิม
				d.Range = 60
				d.Brightness = math.max(d.Brightness, 4)
			end
		end
	end
end

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
	brightenHeadlights(m)
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

-- คนขับแบบกล่องเดิม -> ชาวบ้านแบบใหม่นั่งท่าขับตามประเภทรถ (ถ้ามีแม่แบบและท่า publish แล้ว)
--   สะโพกวางที่ขอบล่างของ Torso คนขับเดิม (ตรงเบาะพอดี ทั้งมอไซค์ ซาเล้ง รถยนต์ ตุ๊กตุ๊ก)
--   กระสือยังใช้คนขับเดิม (ชาวบ้านแบบใหม่เป็นผิวชิ้นเดียว ซ่อนขาไม่ได้)
local function driverClipFor(v: Model): string
	local n = string.lower(v.Name)
	if string.find(n, "tuktuk") then
		return "drive_tuktuk"
	elseif string.find(n, "bicycle") then
		return "ride_bicycle"
	elseif string.find(n, "moto") or string.find(n, "bike") or string.find(n, "saleng") then
		return "ride_moto"
	end
	return "drive_car"
end
local function humanizeDriver(v: Model, look: { [string]: any }?)
	local old = v:FindFirstChild("DriverNPC") :: Model?
	if not old or old:GetAttribute("Human") or not HumanNPC.Available() then
		return
	end
	local torso = old:FindFirstChild("Torso") :: BasePart?
	if not torso then
		return
	end
	local piv = v:GetPivot()
	local rot = piv - piv.Position
	local hip = CFrame.new((torso.CFrame * CFrame.new(0, -torso.Size.Y / 2, 0)).Position) * rot
	local clip0 = driverClipFor(v)
	if clip0 == "drive_car" then
		hip = hip * CFrame.new(0, 0, -0.5) -- รถยนต์: นั่งชิดพวงมาลัยขึ้น (แขนเอื้อมถึง)
	elseif clip0 == "ride_moto" then
		hip = hip * CFrame.new(0, 0.12, 0.15) -- มอไซค์: นั่งบนเบาะ สูงขึ้น/ถอยหลังนิด ต้นขาไม่จมเข้าไปในตัวถัง
	end
	-- look.hipForward: เลื่อนคนขับไปหน้าอีก (พี่ชายในคัทซีน เว้นเบาะหลังให้คนซ้อน)
	if look and type(look.hipForward) == "number" then
		hip = hip * CFrame.new(0, 0, -look.hipForward)
	end
	-- มือ/เท้าของคนขับเดิมวางอยู่บนแฮนด์และที่พักเท้าของรถพอดี: ใช้เป็นเป้า IK (+X ในรถ = ขวาของคนขับ)
	local clip = driverClipFor(v)
	local targets = {}
	for _, part in ipairs(old:GetDescendants()) do
		if part:IsA("BasePart") and (part.Name == "Hand" or part.Name == "LeftFoot" or part.Name == "RightFoot") then
			local lp = piv:PointToObjectSpace(part.Position)
			local right = lp.X > 0
			if part.Name == "Hand" then
				local key = if right then "handR" else "handL"
				local hp = lp
				if clip == "drive_car" then
					-- รถยนต์: มือคนขับเดิม (ท่าจับแฮนด์มอไซค์) สั้นกว่าพวงมาลัย -> วางบนขอบพวงมาลัยหน้าเบาะ
					hp = piv:PointToObjectSpace(hip.Position) + Vector3.new(if right then 0.55 else -0.3, 1.6, -1.95)
				end
				-- ศอกงอออกข้างและลงล่าง
				targets[key] = { pos = piv:PointToWorldSpace(hp), pole = piv:PointToWorldSpace(hp + Vector3.new(if right then 1.2 else -1.2, -1.2, 1.0)) }
			else
				-- ข้างตามตำแหน่งจริง (เหมือนมือ) ไม่ใช่ชื่อชิ้น: คนขับแบบเก่าตั้งชื่อเท้ากลับข้าง ("RightFoot" อยู่ฝั่ง -X = ซ้าย)
				-- ใช้ชื่อ = ขาขวาเอื้อมไปเท้าซ้าย ขาไขว้กันทะลุตัวรถ
				local key = if right then "footR" else "footL"
				local side = if right then 1 else -1
				local fp = lp
				local pole = Vector3.new(0, 2.5, -2.0) -- เข่าชี้ขึ้นไปข้างหน้า
				if clip == "drive_car" then
					-- รถยนต์: เท้าคนขับเดิม (ท่าขี่มอไซค์) ต่ำกว่าพื้นรถ ยกขึ้นและยื่นไปหน้าแป้นเหยียบ
					fp = Vector3.new(lp.X * 0.6, piv:PointToObjectSpace(hip.Position).Y - 1.5, lp.Z - 1.3)
				elseif clip == "ride_moto" then
					-- มอไซค์: เท้าบนที่พักเท้าหลังบังลม ชิดตัวรถขึ้นนิด / เข่ากางออกข้าง (ไม่ชี้ตรงไปทะลุบังลมหน้า)
					fp = Vector3.new(side * math.max(0.6, math.abs(lp.X) * 0.8), lp.Y + 0.1, lp.Z + 0.45)
					pole = Vector3.new(side * 1.6, 1.4, -0.8)
				end
				targets[key] = { pos = piv:PointToWorldSpace(fp), pole = piv:PointToWorldSpace(fp + pole) }
			end
		end
	end
	-- คนขับรถยนต์ไม่ใส่หมวกทุกชนิด (งอบ/หมวกกันน็อกชนหลังคารถ)
	local opts: { [string]: any } = {
		teen = string.find(string.lower(v.Name), "moto") ~= nil and math.random() < 0.6 or nil,
		noHat = clip == "drive_car" or nil,
	}
	-- look = ชุด/ทรงผมตายตัว (พี่ชายในคัทซีน ให้หน้าตาเหมือนตอนลงเดิน)
	for k, val in pairs(look or {}) do
		opts[k] = val
	end
	HumanNPC.SeatIn(v, hip, clip, opts, targets)
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

local GHOST_VANISH_AFTER = 1.0 -- เติมให้ผีแล้ว: ผีหลอกได้กี่วินาทีผี+รถเริ่มจางหาย
local GHOST_VANISH_FADE = 0.8 -- จางหายในกี่วินาที
local ENGINE_RANGE = 200 -- เสียงเครื่องยนต์รถลูกค้าได้ยินไกลเท่านี้ (studs)
local ENGINE_LEAD = 2 -- ได้ยินเสียงเครื่องกี่วินาทีก่อนรถโผล่ที่จุดเกิด
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
		-- ศาลไม่คุ้มครอง (ไม่ได้ถวายขนม): ผีมาบ่อยขึ้นมาก
		ghost = forceGhostNext or math.random() < (if Items.cursed() then CONFIG.CurseAnomalyChance else CONFIG.AnomalyChance)
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
		brightenHeadlights(v :: Model)
		-- คนขับไม่กางร่ม: สองมือจับแฮนด์ (IK ใน humanizeDriver)
	end
	local length = if walking then (if k == "bicycle" then 6 else 4) else (v :: Model):GetExtentsSize().Z

	local anomaly: string? = nil
	local deferred: string? = nil
	if ghost then
		local anomalyKind = if k == "vehicle" then "vehicle" elseif walking then "walker" else "car"
		anomaly = if forced then forced else AnomalyManager.RandomFor(anomalyKind, raining)
	end
	if not walking and anomaly ~= "Anomaly_Krasue" then
		humanizeDriver(v :: Model)
	end
	if ghost then
		if AnomalyManager.IsWorld(anomaly :: string) then
			deferred = anomaly
		else
			AnomalyManager.Apply(anomaly :: string, v)
		end
	end
	-- ผีพูดเหมือนคนปกติทุกประโยค ไม่มีคำใบ้ (ผู้ใช้ 2026-11-03: ให้รู้ว่าเป็นผีจากการเห็นตัวเองเท่านั้น)
	local useAnomalyLine = false
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
	-- เสียงเครื่องยนต์รถลูกค้าเดินเบาทุ้มๆ ไม่แสบหู (เล่นเฉพาะเมื่ออัปโหลดไฟล์ .wav เข้า UploadedSounds แล้ว ไม่ใช้เสียงเบิ้ลตัดสำรอง)
	-- ได้ยินไกล ENGINE_RANGE (จุดเกิดห่างร้าน ~134 studs: ระยะเดิม 70 กว่าจะได้ยินรถก็มาถึงครึ่งทางแล้ว)
	local engPresetName = if k == "car" then "DieselIdle" else "MotoIdle"
	local engPreset = SoundBank.Presets[engPresetName]
	local engReady = false
	if not walking and engPreset then
		local _, isCustom = SoundBank.ResolveId(engPreset)
		engReady = isCustom
	end
	if engReady then
		-- ได้ยินก่อนเห็นรถ: เสียงเครื่องค่อยๆ ดังขึ้นจากถนนไกลออกไป แล่นเข้าหาจุดเกิด ENGINE_LEAD วินาที แล้วรถค่อยโผล่
		local away = Vector3.new(start.X - stopPoint.Position.X, 0, start.Z - stopPoint.Position.Z).Unit
		local lead = Instance.new("Part")
		lead.Name = "ApproachingEngine"
		lead.Anchored = true
		lead.CanCollide = false
		lead.CanQuery = false
		lead.CanTouch = false
		lead.Transparency = 1
		lead.Size = Vector3.one
		lead.Position = start + away * (CONFIG.DriveSpeed * ENGINE_LEAD) + Vector3.new(0, 2, 0)
		lead.Parent = Workspace
		local snd = SoundBank.CreateSound(engPresetName, lead, ENGINE_RANGE)
		if snd then
			local vol = snd.Volume
			snd.Volume = 0
			snd:Play()
			TweenService:Create(snd, TweenInfo.new(ENGINE_LEAD * 0.8), { Volume = vol }):Play()
		end
		TweenService:Create(lead, TweenInfo.new(ENGINE_LEAD, Enum.EasingStyle.Linear), { Position = start + Vector3.new(0, 2, 0) }):Play()
		task.wait(ENGINE_LEAD)
		task.delay(0.3, function()
			lead:Destroy()
		end)
		if gameOver then
			v:Destroy() -- จบเกมระหว่างรอ: ไม่ต้องให้รถโผล่
			return
		end
	end
	v:PivotTo(CFrame.lookAt(start, Vector3.new(stopPoint.Position.X, start.Y, stopPoint.Position.Z)))
	v.Name = "Customer"
	CollisionGroups.Set(v, CollisionGroups.NPC) -- ผู้เล่นเดินทะลุได้
	v.Parent = Workspace
	if engReady then
		local engPart = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
		local engSnd = engPart and SoundBank.CreateSound(engPresetName, engPart, ENGINE_RANGE)
		if engSnd then
			engSnd:Play()
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
	CollisionGroups.Set(v, CollisionGroups.NPC)
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
			if not v.Parent or shelterSay(sh, "Shelter_Ask", 3.5) then
				break
			end
			task.wait(1)
		end
		-- ชวนคุยเป็นระยะจนฝนหยุด
		local nextTalk = os.clock() + CONFIG.ShelterTalkEvery[1] + math.random() * (CONFIG.ShelterTalkEvery[2] - CONFIG.ShelterTalkEvery[1])
		while v.Parent and Weather.IsRaining() and not gameOver do
			if os.clock() > nextTalk then
				if shelterSay(sh, pick(SHELTER_TALK), 4) then
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
			if shelterSay(sh, "Shelter_Leave", 3.2) then
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
	humanizeDriver(v) -- ชื่อแม่แบบยังอยู่ (เลือกท่าขับตามชื่อ) ก่อนเปลี่ยนชื่อเป็น RoadEvent
	v.Name = "RoadEvent"
	local start = spawnPoint.Position
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, start + ROAD_DIR))
	CollisionGroups.Set(v, CollisionGroups.NPC)
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
	local speed = 0 -- ความเร็วขบวน (studs/วิ, เฉลี่ยนุ่มๆ) -> ขาเดินของคนเต้น
	local conn = RunService.Heartbeat:Connect(function(dt)
		if not v.Parent then
			return
		end
		local t = os.clock() - t0
		local piv = v:GetPivot()
		local step = (piv.Position - lastPos).Magnitude
		local moving = step > 0.01
		lastPos = piv.Position
		speed += ((if dt > 0 then step / dt else 0) - speed) * math.min(1, dt * 4)
		for i, pp in ipairs(people) do
			if pp.m.Parent then
				local ph = t * 6 + i * 1.3
				-- ชาวบ้านแบบใหม่เต้นด้วยท่าจริงอยู่แล้ว: ไม่ต้องเด้งตัว/หมุนตัวทั้งตัว (ลอยจากพื้น, หันไปหาคนข้างๆ)
				local fake = pp.dance and not HumanNPC.Is(pp.m)
				local bob = if fake then math.abs(math.sin(ph)) * 0.5 else 0
				local sway = if fake then math.sin(ph * 0.5) * 0.35 else 0
				local cf = piv * pp.offset
				local y = groundAt(cf.Position)
				pp.m:PivotTo(CFrame.new(cf.Position.X, y + bob, cf.Position.Z) * (cf - cf.Position) * CFrame.Angles(0, sway, 0))
				-- ท่าเต้นของชาวบ้านแบบใหม่เล่นเมื่อค่า ~= 0: อย่าให้ผ่าน 0 (สลับไปท่ายืนชั่วขณะ)
				local a = if moving or pp.dance then math.sin(ph) * 0.5 else 0
				if pp.dance and HumanNPC.Is(pp.m) then
					a = 1
					-- ขบวนเคลื่อน: ขา/สะโพกเดินจริง ตัว หัว แขนเต้นต่อ (client/HumanEmotesRunner)
					HumanEmotes.SetWalkLegs(pp.m, if speed > 0.3 then speed else 0)
				end
				Pedestrian.Pose(pp.m, a)
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
			local wheels = wheelsOf(v)
			local lastK = 0
			while os.clock() - t0 < dur and v.Parent do
				local k = (os.clock() - t0) / dur
				spinWheels(wheels, v:GetPivot().RightVector, 30 * (k - lastK))
				lastK = k
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
	-- วัยรุ่น 4 คนเต้นอยู่ท้ายรถ
	local teenColors = { Color3.fromRGB(40, 90, 160), Color3.fromRGB(200, 170, 40), Color3.fromRGB(30, 30, 30), Color3.fromRGB(160, 40, 40) }
	-- ท่าส่ายสะโพก / ย่อต่ำ ให้เฉพาะแถวหลัง (ไม่มีใครยืนข้างหลัง) ทุกคนหันตามรถ เว้นระยะกัน
	-- ห้ามวางให้คนเต้นท่าพวกนี้หันก้นหรือหันหน้าเข้าหาคนอื่นใกล้ๆ (ไม่ให้ดูล่อแหลม)
	local frontDances = { "wan_bounce", "wan_rock", "wan_point", "wan_hands_up" }
	local backDances = { "wan_hip_shake", "wan_low_bounce", "wan_bounce", "wan_hands_up" }
	local function pick(list: { string }, used: { [string]: boolean }): string
		local pool = {}
		for _, d in ipairs(list) do
			if not used[d] then
				table.insert(pool, d)
			end
		end
		local d = pool[math.random(#pool)]
		used[d] = true
		return d
	end
	local usedDances = {}
	for i = 1, 4 do
		local back = i > 2
		local tm = Pedestrian.Build({ shirt = teenColors[i], teen = true, dance = pick(if back then backDances else frontDances, usedDances) })
		tm.Name = "Teen"
		CollisionGroups.Set(tm, CollisionGroups.NPC)
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
	roadSay("Coyote_Line", "Name_PartyDriver", 3, v) -- คนในรถทักแทน (ไม่มีคนยืนข้างรถแล้ว)
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
	CollisionGroups.Set(naga, CollisionGroups.NPC)
	naga.Parent = Workspace
	table.insert(people, { m = naga, offset = CFrame.new(0, 0, len / 2 + 3), dance = false })
	local colors = { Color3.fromRGB(230, 120, 40), Color3.fromRGB(60, 130, 200), Color3.fromRGB(200, 60, 90), Color3.fromRGB(240, 200, 60), Color3.fromRGB(120, 60, 160) }
	for i = 1, 10 do
		local m = Pedestrian.Build({ shirt = colors[(i - 1) % #colors + 1], teen = false, noHelmet = true, dance = "ramwong" })
		m.Name = "ParadeDancer"
		CollisionGroups.Set(m, CollisionGroups.NPC)
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

-- force = เรียกจากแผง admin: มาเลยแม้มีลูกค้ารอคิว/คนหลบฝน (สุ่มเองปกติ: รอให้หน้าร้านว่างก่อน)
local function runRoadEvent(kind: string?, force: boolean?)
	if roadEventRunning then
		if force then
			warn("[CoreLoop] ขาจรบนถนนยังวิ่งอยู่ (" .. tostring(kind) .. " ต้องรอคันเดิมผ่านไปก่อน)")
		end
		return
	end
	if not force and (#queue > 0 or #shelters > 0) then
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
	task.spawn(runRoadEvent, kind, true)
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
		-- รอจนไม่มีลูกค้าหรือคนหลบฝนค้างอยู่ในฉาก และไม่มีขาจรบนถนน
		waitWhile(function()
			return #queue > 0 or #shelters > 0 or roadEventRunning
		end)
		if gameOver then
			return
		end
		local pace = pickPacing()
		spawnCustomer()
		-- รอจนร้านว่างจริงๆ (ลูกค้าคนนี้ออกไปพ้นแมพแล้ว) แล้วค่อยนับเวลาพัก
		waitWhile(function()
			return #queue > 0
		end)
		local rest = rand(pace.rest)
		print(string.format("☕ ร้านว่าง พัก %.0f วิ (ลูกค้าคนถัดไป)", rest))
		if math.random() < CONFIG.RoadEventChance then
			task.delay(math.min(6, rest * 0.3), runRoadEvent)
		end
		waitWhile(function()
			return true
		end, rest)
		-- ขาจรยังอยู่บนถนน รอให้ผ่านไปก่อนค่อยปล่อยลูกค้าคนใหม่
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
		-- ถ้ามีคนกำลังเล่นมินิเกมเติมน้ำมัน/เติมลมอยู่ ให้ยืดเวลาออกไป (ไม่ตัดบทลูกค้าหนีไประหว่างเติม)
		if activeMinigamePlayer and activeMinigamePlayer.Parent then
			t0 = math.max(t0, os.clock() - (CONFIG.DecisionTime - 20))
		end

		-- ถ้ามีผู้เล่นกำลังพนมมือคุย/ตรวจผีอยู่ใกล้ๆ รถ ให้ชะลอเวลาหงุดหงิด
		local prayingNear = #Prayer.PrayingNear(c.v:GetPivot().Position, CONFIG.PrayReactRadius) > 0
		if prayingNear then
			t0 = math.max(t0, os.clock() - (CONFIG.DecisionTime - 30))
		end

		local waited = os.clock() - promptsAt -- นับจากตอนปุ่มเปิด (รวมช่วงถามราคา)
		if annoyed < 1 and waited > CONFIG.ImpatientAfter[1] and not prayingNear then
			annoyed = 1
			say(pick({ "Impatient_1", "Impatient_2" }), speaker)
		elseif annoyed < 2 and waited > CONFIG.ImpatientAfter[2] and not prayingNear then
			annoyed = 2
			say("Impatient_3", speaker)
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
	if ghost then
		stats.anomalies += 1
	end
	decisionBy = nil
	local who = c.who
	local speaker = { name = who.name, voice = who.voice, ghost = ghost }
	currentSpeaker = speaker
	local arrivedAt = os.clock()
	customerTalking = true
	currentHead = getHead(v)
	local annoyed = 0
	local present = true -- ลูกค้ายังคุยอยู่ที่ตู้ (ทักคนพนมมือได้)
	task.spawn(watchPrayers, c, speaker, function()
		return present and v.Parent ~= nil
	end)

	-- เมื่อลูกค้ารายใหม่มาถึง ถ้าแผงสังกะสีหน้าร้านปิดอยู่ (เช่น ปิดไล่ผีตัวก่อนหน้า) ให้ดึงเปิดต้อนรับลูกค้ารายใหม่ทันที
	if not isShutterOpen then
		openShutter()
	end

	-- เปิดปุ่มบริการทันทีที่ลูกค้ามาถึงตู้ปั๊ม! ผู้เล่นกดเติมได้เลย ไม่ต้องรอฟังบทสนทนายาว 6-10 วินาที
	if not gameOver then
		setServicePrompts(true)
	end
	local promptsAt = os.clock()

	-- บทสนทนาทักทายและสั่งบริการ (ทำงานคู่ขนาน ไม่บล็อกปุ่มเติมน้ำมัน)
	task.spawn(function()
		if c.queuedSince and os.clock() - c.queuedSince > CONFIG.QueueAnnoyedAfter and not ghost then
			annoyed = 1
			say("Greet_Waited", speaker, nil, 2.6)
		else
			say(who.greet, speaker, nil, 2.6)
		end

		if not present or gameOver or decision then return end

		local raining = Weather.IsRaining()
		if raining and math.random() < 0.5 then
			say(pick({ "RainTalk_1", "RainTalk_2", "RainTalk_3" }), speaker, nil, 2.6)
		end

		if not present or gameOver or decision then return end

		local sh = anyShelter()
		if sh and math.random() < 0.7 then
			local shSpeaker = { name = sh.who.name, voice = sh.who.voice, ghost = sh.ghost }
			-- (ผี/คนปกติคุยเหมือนกัน: ไม่ใบ้ด้วยข้อความ)
			say(pick({ "Shelter_ToCustomer_1", "Shelter_ToCustomer_2" }), shSpeaker, nil, 2.6, getHead(sh.v))
			say(pick({ "Chat_Reply_1", "Chat_Reply_2" }), speaker, nil, 2.4)
		end

		if not present or gameOver or decision then return end

		local order = if c.useAnomalyLine then c.anomaly :: string else c.order
		say(order, speaker, nil, 3.2)

		-- คิวคันหลังแซวให้รีบ
		local nextInLine = queue[2]
		if nextInLine and nextInLine.queuedSince and os.clock() - nextInLine.queuedSince > 6 and math.random() < 0.4 then
			say("Queue_Chime", { name = nextInLine.who.name, voice = nextInLine.who.voice, ghost = nextInLine.ghost }, nil, 2.4, getHead(nextInLine.v))
		end
	end)

	-- ราคาตามบริการ (น้ำมันหลอด / ดีเซล / เติมลม) ไม่มีตัวเลือกถามราคา
	local svc = CONFIG.Services[c.service] or CONFIG.Services.petrol
	local price = svc.normal
	local leaveEarly = false

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
			promptsAt = os.clock()
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
			-- น้ำมันในหลอดลดลงจริง (ไม่เติมคืนเอง) หมดแล้วต้องเอาแกลลอนไปตักจากถังหลังร้านมาเท
			local fillTween = Items.useFuel(c.service == "diesel" and not ghost, 2)
			if fillTween then
				fillTween.Completed:Wait()
			end
		end
		if ghost then
			-- เติมให้ผี: ธูปดับ 1 ดอก + หักเงิน + ผีหลอก
			say(pick({ "Pay_1", "Pay_2", "Pay_3" }), speaker, { amount = price }, 1.5)
			incense -= 1
			money = math.max(0, money - CONFIG.GhostFuelPenalty)
			refreshIncense()
			local spiritPart = spirit:FindFirstChildWhichIsA("BasePart", true)
			if spiritPart then
				SoundBank.PlayOneShot("IncenseExtinguish", spiritPart, 85, 3.0)
			end
			TriggerJumpscare:FireAllClients(c.anomaly, v)
			stats.fooled += 1
			print("👻 เติมน้ำมันให้ผี! ธูปเหลือ " .. incense)
			-- หลอกเสร็จ ผีกับรถหายวับไปตรงนั้น (ไม่ขับ/เดินออกไปต่อ): เริ่มจางตอนจอยังโดนผีหลอกเต็มจออยู่
			task.delay(GHOST_VANISH_AFTER, function()
				if v.Parent then
					for _, d in ipairs(v:GetDescendants()) do
						if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
							(d :: any).Enabled = false
						elseif d:IsA("Sound") then
							d:Stop()
						end
					end
					Pedestrian.FadeAway(v, GHOST_VANISH_FADE)
				end
			end)
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
			local s = pstat(decisionBy)
			if s then
				s.fills += 1
				s.earned += paid
			end
			print("😒 เติมช้า ลูกค้าจ่ายแค่ " .. paid .. "฿ รวม " .. money)
		else
			money += price
			local tin = interactive:FindFirstChild("MoneyTin")
			SoundBank.PlayOneShot("CoinTinDrop1", (tin and tin:FindFirstChildWhichIsA("BasePart", true)) or pumpBody, 55, 1.5)
			say(pick({ "Pay_1", "Pay_2", "Pay_3" }), speaker, { amount = price })
			local s = pstat(decisionBy)
			if s then
				s.fills += 1
				s.earned += price
			end
			print("💰 ลูกค้าปกติ +" .. price .. "฿ รวม " .. money)
		end
		broadcastHUD()
	elseif choice == "reject" then
		if isShutterOpen then
			closeShutter()
		end
		if ghost then
			money += CONFIG.RejectGhostReward
			stats.caught += 1
			local s = pstat(decisionBy)
			if s then
				s.ghosts += 1
			end
			local tin = interactive:FindFirstChild("MoneyTin")
			SoundBank.PlayOneShot("CoinTinDrop1", (tin and tin:FindFirstChildWhichIsA("BasePart", true)) or pumpBody, 55, 1.5)
			if c.anomaly then
				AnomalyBook.Survived(c.anomaly) -- รอดจากผีตัวนี้ -> ปลดล็อกในสมุดของทุกคน
			end
			-- ผีรู้ว่าเรารู้แล้ว: ใครยังอยู่นอกร้าน (ยังไม่ได้เข้าหลังแผง) โดนผีหลอกทันที แล้วผีหายวับไปตรงนั้น
			local outside = {}
			for _, p in ipairs(Players:GetPlayers()) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not root.Anchored and not soloDead[p] and not Items.insideShop(root.Position) then
					table.insert(outside, p)
				end
			end
			task.wait(CONFIG.RejectScareDelay)
			for _, p in ipairs(outside) do
				print("👻 [" .. p.Name .. "] ยังอยู่นอกร้านตอนปิดแผงใส่ผี โดนหลอก")
				TriggerJumpscare:FireClient(p, c.anomaly, v, "chased")
				task.delay(0.35, function()
					knockDown(p, CONFIG.KnockdownTime)
				end)
			end
			say(if #outside > 0 then "Ghost_Chased" else pick({ "Rejected_1", "Rejected_2" }), speaker)
			task.delay(if #outside > 0 then GHOST_VANISH_AFTER else 1.6, function()
				if v.Parent then
					for _, d in ipairs(v:GetDescendants()) do
						if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") then
							(d :: any).Enabled = false
						elseif d:IsA("Sound") then
							d:Stop()
						end
					end
					Pedestrian.FadeAway(v, GHOST_VANISH_FADE)
				end
			end)
			print("✅ ไล่ผีถูกต้อง +" .. CONFIG.RejectGhostReward .. "฿ รวม " .. money .. " (นอกร้านโดนหลอก " .. #outside .. " คน)")
		else
			say(pick({ "Rejected_1", "Rejected_2" }), speaker)
			print("😤 ปิดร้านใส่ลูกค้าปกติ อดได้เงิน")
		end
		broadcastHUD()
	elseif not leaveEarly then
		say(pick({ "NoOne_1", "NoOne_2" }), speaker)
		print("⌛ ไม่มีใครตัดสินใจ ลูกค้าขับออกไปเอง")
	end
	present = false
	task.wait(2.6) -- ให้อ่านประโยคสุดท้ายทัน
	CustomerSpeech:FireAllClients(nil)
	currentHead = nil
	customerTalking = false
	currentSpeaker = nil
	if shutterRejectThread then
		task.cancel(shutterRejectThread)
		shutterRejectThread = nil
	end

	currentVehicle = nil
	currentVehicleIsAnomaly = false
	currentAnomaly = nil
	AnomalyManager.SetGhostPresent(false)
	publishState()
	task.wait(1)
	-- ผีที่เติมให้ หรือโดนปิดร้านใส่: จางหายไปตรงนั้นแล้ว (ด้านบน) ไม่ขี่/เดินออกจากร้าน
	-- (เดิมผีที่โดนปิดร้านใส่ขี่ออกไปช้าๆ ให้วิ่งตาม -> เปลี่ยนเป็นหลอกคนที่อยู่นอกร้านทันทีแล้วหายไป 2026-11-03)
	local vanishing = ghost and (choice == "fuel" or choice == "reject")
	if vanishing then
		local t0 = os.clock()
		while v.Parent and os.clock() - t0 < 8 do
			task.wait(0.1)
		end
		if v.Parent then
			v:Destroy()
		end
	elseif c.kind == "walker" or c.kind == "bicycle" then
		Pedestrian.WalkTo(v, stopPoint.Position - backDir() * 55, CONFIG.WalkSpeed)
		v:Destroy()
	else
		local exit = exitPoint.Position
		driveTo(v, Vector3.new(exit.X, exit.Y, exit.Z), false)
		v:Destroy()
	end
	-- รถไปแล้วพ้นแมพ: เอาออกจากคิวและคืนวิทยุ หุ่นไล่กา ผีตานีหลังกอกล้วย น้ำมัน ให้ปกติ
	local idx = table.find(queue, c)
	if idx then
		table.remove(queue, idx)
	end
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

-- ผีฉาก: ไม่เกี่ยวกับลูกค้า โผล่ให้เห็นเฉยๆ นานๆ ครั้งตอนร้านเปิด (AnomalyManager.ShowScenery)
-- เสียงตอนเห็น / มองค้างนาน = ผีพุ่งใส่หน้าคนที่มอง อยู่ที่ client/SceneryGhostWatch
local sceneryNow: string? = nil
local function showSceneryGhost(kind: string?)
	local list = AnomalyManager.SceneryKinds
	local k = kind or list[math.random(#list)]
	if sceneryNow then
		AnomalyManager.HideScenery(sceneryNow)
	end
	if AnomalyManager.ShowScenery(k) then
		sceneryNow = k
		print("👁️ ผีฉากโผล่: " .. k)
		task.delay(rand(CONFIG.SceneryStay), function()
			if sceneryNow == k then
				AnomalyManager.HideScenery(k)
				sceneryNow = nil
			end
		end)
	end
end
local function sceneryLoop()
	while true do
		task.wait(rand(CONFIG.SceneryEvery))
		if remotes:GetAttribute("ShopOpen") == true and not gameOver and not sceneryNow then
			showSceneryGhost()
		end
	end
end

local function prayerSummonLoop()
	local rolled: { [Player]: number } = {} -- สุ่มไปแล้วกับการพนมมือรอบไหน
	while true do
		task.wait(0.5)
		-- ไฟดับ: พนมมือแทนไฟฉาย (ตาทิพย์เห็นในมืด) ผีมาหาถี่และบ่อยกว่าปกติ ไม่ต้องรอร้านว่าง
		local dark = not Power.IsOn()
		local idle = remotes:GetAttribute("ShopOpen") == true and not gameOver and (dark or #queue == 0) and not roadEventRunning and summoned == nil
		local cooldown = if dark then CONFIG.PraySummonCooldown / 3 else CONFIG.PraySummonCooldown
		local after = if dark then CONFIG.PraySummonAfter / 2 else CONFIG.PraySummonAfter
		local chance = if dark then math.min(0.9, CONFIG.PraySummonChance * 2.5) else CONFIG.PraySummonChance
		if idle and os.clock() - lastSummonAt > cooldown then
			for _, p in ipairs(Prayer.Praying()) do
				local started = Prayer.StartedAt(p)
				local dur = Prayer.Duration(p)
				-- ไฟดับ: พนมมือนานขึ้นเรื่อยๆ ก็สุ่มซ้ำได้ (ไม่ใช่ครั้งเดียวต่อการพนมมือ)
				local key = if started and dark then started + math.floor((dur or 0) / math.max(after, 1)) else started
				if started and dur and dur >= after and rolled[p] ~= key then
					rolled[p] = key
					if math.random() < chance then
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
	-- เริ่มคืน: ตู้ทั้ง 2 และแผงน้ำมันขวดว่างเปล่า ต้องเอาแกลลอนไปตักจากถังหลังร้านมาเติมก่อนขายได้
	petrolLevel, dieselLevel = 0, 0
	setFuelLevel(0, 0.5)
	setDieselLevel(0, 0.5)
	Items.setRackFilled(false)
	Items.updatePourPrompts()
	offeringUntil = math.huge
	offeringWarned = false
	remotes:SetAttribute("Cursed", false)
	Items.clearOffering()
	resetStats()
	broadcastHUD()
end

-- ---------------------------------------------------------------- คัทซีนเปิดคืน / จบคืน (Cutscene.luau)
Cutscene = require(script.Parent:WaitForChild("Cutscene"))
Cutscene.Init({
	remote = remote,
	templates = templates,
	prepThaiVehicle = prepThaiVehicle,
	seatDriver = seatDriver,
	humanizeDriver = humanizeDriver,
	driveTo = driveTo,
	groundAt = groundAt,
	Pedestrian = Pedestrian,
	spawnPoint = spawnPoint,
	stopPoint = stopPoint,
	exitPoint = exitPoint,
	ROAD_DIR = ROAD_DIR,
	shack = Items.shack,
	rejectRope = rejectRope,
	shutterDoor = shutterDoor,
	insideShop = Items.insideShop,
	-- พี่ชายดึงเชือกยกแผงให้ดู (ยังไม่เริ่มคืน)
	openShutter = function()
		if not isShutterOpen and not shutterTweening then
			openShutter()
		end
	end,
	-- จบคัทซีน: ถ้ายังไม่มีใครดึงเชือกเปิดร้านจริง แผงต้องปิดอยู่
	resetShutter = function()
		if not shopOpened and isShutterOpen and not shutterTweening then
			closeShutter()
		end
	end,
	-- คัทซีนจบเริ่ม: แผงต้องเปิดอยู่เสมอ (ทันที ไม่มีเสียง) แล้วค่อยปิดตามฉาก — เดิมถ้าแผงปิดอยู่ตอนชนะ (ปิดใส่ผี / admin ชนะก่อนเปิดร้าน) ฉากปิดร้านไม่มีอะไรขยับ
	showShutterOpen = function()
		if shutterTweening then
			return
		end
		local p = shutterDoor.Position
		shutterDoor.Position = Vector3.new(p.X, openY, p.Z)
		isShutterOpen = true
		updateShutterPrompts()
	end,
	-- เช้าแล้ว ปิดร้าน
	closeShop = function()
		if isShutterOpen and not shutterTweening then
			closeShutter()
		end
	end,
})

-- เริ่มคืน: แผงสังกะสีปิดไว้ -> คัทซีนพี่ชายมาส่ง (ข้ามได้) -> ผู้เล่นเข้าร้าน แผงปิด เข้ากลางคืน
-- -> ผู้เล่นดึงเชือกเปิดร้านเองเพื่อเริ่มคืน (ลูกค้าเริ่มมาหลังจากนั้น)
local function waitForShopOpen()
	local p = shutterDoor.Position
	shutterDoor.Position = Vector3.new(p.X, closedY, p.Z)
	isShutterOpen = false
	shopOpened = false
	updateShutterPrompts()
	remotes:SetAttribute("ShopOpen", false)
	remotes:SetAttribute("PrepLeft", nil)
	-- ไฟร้านดับตั้งแต่ก่อนคัทซีน (เครื่องปั่นไฟยังไม่ติด): คัทซีนเย็นเห็นร้านไฟปิด เข้ากลางคืนก็มืดต่อ
	-- (Client จำค่าแสงตอนเริ่มคัทซีน = ค่าไฟดับ แล้วคืนค่านี้ตอนจบ) ตัดแบบเงียบ: ไม่มีเสียงกระแทกตอนโหลดเข้าเกม
	Power.Cut(true)
	local introDone = false
	task.spawn(function()
		local ok, err = pcall(Cutscene.Intro)
		if not ok then
			warn("[CoreLoop] Intro ล้ม:", err)
		end
		introDone = true
	end)
	while not introDone do
		task.wait(0.2)
	end
	-- เข้ากลางคืนแล้วเครื่องปั่นไฟยังไม่ติด (ตัดไฟไว้ตั้งแต่ก่อนคัทซีน ด้านบน): ต้องเปิดไฟฉาย ดึงเชือกเปิดร้าน แล้วเดินไปสตาร์ทเครื่องเอง
	if not shopOpened then
		GameState:FireAllClients("Waiting") -- "ไปดึงเชือกเปิดแผงเพื่อเริ่มคืนนี้"
	end
	-- admin กด "ชนะทันที" ก่อนเปิดร้าน (เงินถึงเป้าแล้ว) = ไม่ต้องรอดึงเชือก ลูปหลักเข้าคัทซีนเช้าเลย
	while not shopOpened and money < CONFIG.TargetMoney do
		task.wait(0.2)
	end
	if not shopOpened then
		return
	end
	remotes:SetAttribute("ShopOpen", true)
	if not isShutterOpen then
		openShutter()
	end
	-- ต้องถวายขนมศาลภายในเวลานี้ (เตือนตั้งแต่ต้นคืน) ระหว่างช่วงเตรียมร้าน
	offeringUntil = os.clock() + math.min(CONFIG.OfferingGrace, CONFIG.PrepTime)
	offeringWarned = false
	GameState:FireAllClients("Playing")
	-- ตู้/แผงยังว่าง: บอกให้ไปเอาน้ำมันหลังร้านมาเติมก่อนลูกค้ามา
	task.delay(5.5, function()
		if remotes:GetAttribute("ShopOpen") and petrolLevel <= 0 and dieselLevel <= 0 then
			Notice:FireAllClients("StartRefuel", 6)
		end
	end)
	task.delay(12, function()
		if remotes:GetAttribute("ShopOpen") and os.clock() < offeringUntil and stats.offerings == 0 then
			Notice:FireAllClients("ShrineHungry", 6)
		end
	end)
	-- ช่วงเตรียมร้าน: ลูกค้ายังไม่มา (spawnerLoop เริ่มหลังฟังก์ชันนี้คืนค่า) นับถอยหลังบน HUD (client/ItemSlots)
	--   PrepLeft = วินาทีที่เหลือ, PrepOffered = ถวายขนมแล้วหรือยัง (ไฟ = ReplicatedStorage.PowerOn, น้ำมัน = PetrolLevel/DieselLevel)
	local prepEnd = os.clock() + CONFIG.PrepTime
	while os.clock() < prepEnd and not gameOver and money < CONFIG.TargetMoney do -- (admin ชนะทันทีระหว่างเตรียมร้าน = จบช่วงเตรียมเลย)
		remotes:SetAttribute("PrepLeft", math.ceil(prepEnd - os.clock()))
		remotes:SetAttribute("PrepOffered", stats.offerings > 0)
		task.wait(0.25)
	end
	remotes:SetAttribute("PrepLeft", nil)
	Notice:FireAllClients("PrepOver", 5)
	print("🚦 หมดเวลาเตรียมร้าน ลูกค้าเริ่มมา" .. (if stats.offerings == 0 then " (ยังไม่ถวายขนม: ศาลไม่คุ้มครอง)" else ""))
end

-- ผู้เล่นที่เข้ามาตอนร้านยังปิด (ไม่มีคัทซีนเล่นอยู่) ให้เห็นข้อความรอเปิดร้านด้วย
Players.PlayerAdded:Connect(function(p)
	task.wait(3)
	if openPrompt.Enabled and not Cutscene.Running() then
		GameState:FireClient(p, "Waiting")
	end
end)

-- ค่าเฝ้าร้าน: ตัวคูณความยากจากห้องใน Lobby (TeleportData.difficulty)
local Difficulty = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Difficulty"))
local function rewardMult(p: Player): number
	local ok, data = pcall(function()
		return p:GetJoinData().TeleportData
	end)
	local id = if ok and type(data) == "table" then data.difficulty else nil
	return Difficulty.Get(id).reward
end

local function buildSummary(): { [string]: any }
	local rows = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local s = stats.players[p.UserId] or { name = p.DisplayName, fills = 0, earned = 0, ghosts = 0, offerings = 0 }
		local wage = (CONFIG.WageBase + s.fills * CONFIG.WagePerFill + s.ghosts * CONFIG.WagePerGhost + s.offerings * CONFIG.WagePerOffering) * rewardMult(p)
		table.insert(rows, { userId = p.UserId, name = p.DisplayName, fills = s.fills, earned = s.earned, ghosts = s.ghosts, offerings = s.offerings, wage = math.floor(wage / 5 + 0.5) * 5 })
	end
	table.sort(rows, function(a, b)
		return a.earned > b.earned
	end)
	return {
		team = money,
		target = CONFIG.TargetMoney,
		anomalies = stats.anomalies,
		caught = stats.caught,
		fooled = stats.fooled,
		offerings = stats.offerings,
		incense = incense,
		maxIncense = CONFIG.StartIncense,
		players = rows,
	}
end

-- ชนะ: คัทซีนเช้า + หน้าสรุปผล แล้วรอทุกคนกด "เฝ้าต่ออีกคืน" (หรือหมดเวลา)
local summaryVotes: { [Player]: boolean } = {}
local summaryOpen = false
SummaryRemote.OnServerEvent:Connect(function(p, action: any)
	if action == "continue" and summaryOpen then
		summaryVotes[p] = true
		local n = 0
		for q in pairs(summaryVotes) do
			if q.Parent then
				n += 1
			end
		end
		SummaryRemote:FireAllClients("votes", n, #Players:GetPlayers())
	end
end)
local function winSequence()
	for _, p in ipairs(Players:GetPlayers()) do
		Prayer.Stop(p)
	end
	clearQueue()
	ServiceMinigame:FireAllClients("close")
	CustomerSpeech:FireAllClients(nil)
	remotes:SetAttribute("Cursed", false)
	-- เช้าแล้ว ขายหมด: ตู้และแผงน้ำมันขวดว่างเปล่าในคัทซีนจบ
	petrolLevel, dieselLevel = 0, 0
	setFuelLevel(0, 0.3)
	setDieselLevel(0, 0.3)
	Items.setRackFilled(false)
	Items.updatePourPrompts()
	local summary = buildSummary()
	print("🌅 ชนะ: คัทซีนเช้า + สรุปผล", summary.team, "฿")
	table.clear(summaryVotes)
	summaryOpen = true
	local ok, err = pcall(Cutscene.Outro, summary)
	if not ok then
		warn("[CoreLoop] Outro ล้ม:", err)
	end
	GameState:FireAllClients("Win")
	local t0 = os.clock()
	while os.clock() - t0 < CONFIG.SummaryTimeout do
		local all = #Players:GetPlayers() > 0
		for _, p in ipairs(Players:GetPlayers()) do
			if not summaryVotes[p] then
				all = false
			end
		end
		if all then
			break
		end
		task.wait(0.3)
	end
	summaryOpen = false
	SummaryRemote:FireAllClients("close")
end

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
	task.spawn(sceneryLoop)
	Weather.Start(function()
		return remotes:GetAttribute("ShopOpen") == true and not gameOver
	end)
	Power.Start(function()
		return remotes:GetAttribute("ShopOpen") == true and not gameOver
	end)
	task.spawn(function()
		while true do
			resetGame()
			-- (คืนใหม่: ไฟดับรอสตาร์ทเครื่องปั่นไฟ — waitForShopOpen ตัดไฟให้)
			waitForShopOpen()
			task.spawn(spawnerLoop)
			while not gameOver do
				local front = queue[1]
				if incense <= 0 then
					-- ธูปดับหมด (เติมให้ผีครบ หรือทดสอบ) จบเกม
					gameOver = true
					print("💀 ธูปดับครบ 3 ดอก Game Over")
				elseif money >= CONFIG.TargetMoney then
					-- ครบโควตา (หลังลูกค้าคนล่าสุด หรือ admin สั่งชนะ)
					gameOver = true
					for _, player in ipairs(Players:GetPlayers()) do
						LeaderboardStats.Increment("completions", player.UserId, 1)
					end
					print("🏆 ครบ " .. CONFIG.TargetMoney .. "฿ ชนะ!")
				elseif front and front.atPump and not front.serving then
					serveCustomer(front)
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
				-- เกิดใหม่ทุกคน (ลุกขึ้น ควบคุมได้อีกครั้ง) รวมคนที่ตายคนเดียวค้างอยู่
				table.clear(soloDead)
				for _, p in ipairs(Players:GetPlayers()) do
					p:LoadCharacter()
				end
				task.wait(1)
			else
				-- ชนะ: คัทซีนเช้า -> หน้าสรุปผล -> รอทุกคนกดเฝ้าต่อ แล้วเริ่มคืนใหม่ (คัทซีนเปิดคืนอีกรอบ)
				winSequence()
			end
		end
	end)
end

CoreLoop.Config = CONFIG
return CoreLoop
