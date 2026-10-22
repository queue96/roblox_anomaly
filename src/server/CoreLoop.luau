-- CoreLoop.luau (ModuleScript ฝั่ง Server)
-- Phase 3: ลูปหลักของเกม "ปั๊มหลอดท้ายทุ่ง"
--   รถลูกค้า (Clone จาก ServerStorage.VehicleTemplates) ขี่จาก SpawnPoint มาจอดที่ StopPoint
--   -> ล็อกปุ่ม 3 วินาทีให้ผู้เล่นส่องไฟฉายดูก่อน
--   -> ผู้เล่นเลือก "เติมน้ำมัน" (กดค้าง 3 วิ ที่ตู้ปั๊ม) หรือ "ดึงแผงปิดร้าน" (กดค้าง 0.5 วิ ที่เชือก)
--   -> ตรวจคำตอบจาก currentVehicleIsAnomaly: ถูกได้เงิน / เติมให้ผีธูปดับ 1 ดอก + หักเงิน
--   -> รถขี่ออกไปทาง ExitPoint แล้วเสกคันต่อไป  ครบ 500฿ = ชนะ  ธูปดับครบ 3 ดอก = แพ้
-- Phase 4: ชนิดผีทั้งหมดอยู่ใน AnomalyManager.luau (Apply ตอนเสกรถ, ResetAnomalies ตอนรถขี่ออกไป)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CoreLoop = {}

-- ---------------------------------------------------------------- ค่าปรับเกม
local CONFIG = {
	TargetMoney = 500,
	Prices = { 80, 100, 120 }, -- ราคาที่ผู้เล่นตอบได้ (เงินที่ได้ = ราคาที่ตอบ)
	NormalPrice = 100, -- ไม่มีใครตอบ = ราคานี้
	ExpensiveRefuseChance = 0.5, -- ตอบแพง (120) ลูกค้าปกติมีโอกาสไม่เอา
	ReplyTime = 8, -- วินาทีที่เปิดให้ตอบราคา
	RejectGhostReward = 50, -- ดึงแผงปิดร้านใส่ผีได้ถูกต้อง
	GhostFuelPenalty = 100, -- เผลอเติมน้ำมันให้ผี (หักเงิน + ธูปดับ 1 ดอก)
	StartIncense = 3,
	AnomalyChance = 0.4,
	InspectLock = 3, -- วินาทีที่ล็อกปุ่มหลังรถจอด (ให้ส่องไฟฉายดู)
	DecisionTime = 25, -- ถ้าไม่มีใครตัดสินใจ ลูกค้าจะขับออกไปเอง
	DriveSpeed = 24, -- studs / วินาที
	GreetReplyTime = 5, -- วินาทีที่เปิดให้ทักทายตอบ
	-- จังหวะลูกค้า: สุ่มรูปแบบทุกครั้ง (น้ำหนัก = โอกาส)
	Pacing = {
		{ kind = "lull", weight = 2, count = 1, gap = { 16, 26 } }, -- เงียบๆ นานๆ มาที
		{ kind = "steady", weight = 4, count = 1, gap = { 7, 12 } }, -- มาเรื่อยๆ
		{ kind = "pair", weight = 2, count = 2, spacing = { 1.5, 3 }, gap = { 12, 18 } }, -- มาพร้อมกัน 2 คัน
		{ kind = "rush", weight = 1, count = 3, spacing = { 3, 6 }, gap = { 18, 26 } }, -- มาต่อๆ กัน 3 คัน
	},
	MaxQueue = 3, -- ที่ตู้ปั๊ม 1 + รอคิว 2
	QueueSpacing = 9, -- ระยะห่างคันที่รอคิว (studs)
	-- รอนานแล้วไม่พอใจ
	ImpatientAfter = { 16, 24 }, -- วินาทีหลังเปิดปุ่ม (รวมช่วงถามราคา): บ่นครั้งที่ 1, 2
	QueueAnnoyedAfter = 14, -- รอคิวนานเกินนี้ มาถึงก็บ่นเลย
	SlowPenalty = 20, -- เติมช้า (บ่นไปแล้ว) ลูกค้าจ่ายน้อยลง
	RestartDelay = 12,
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
local pumpPrompt = setupPrompt("PumpFuelPrompt", pumpBody, 3, "Fill Up", "Gas Pump") -- ข้อความจริงตามภาษาผู้เล่นตั้งฝั่ง Client (HUDController)
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
local function pickCharacter(voice: string?)
	local pool = {}
	for _, c in ipairs(CHARACTERS) do
		if voice == nil or c.voice == voice then
			table.insert(pool, c)
		end
	end
	return pick(if #pool > 0 then pool else CHARACTERS)
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
local function driveTo(v: Model, target: Vector3, brake: boolean)
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
		local speed = CONFIG.DriveSpeed
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
	local p = shutterDoor.Position
	local t = TweenService:Create(shutterDoor, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = Vector3.new(p.X, shutterOpenY - shutterDrop, p.Z),
	})
	t:Play()
	t.Completed:Wait()
end

local function openShutter()
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
	local t = TweenService:Create(fuelLiquid, TweenInfo.new(time, Enum.EasingStyle.Sine), {
		Size = Vector3.new(fuelFull.X, h, fuelFull.Z),
		Position = Vector3.new(p.X, fuelBottom + h / 2, p.Z),
	})
	t:Play()
	return t
end

-- ---------------------------------------------------------------- การตัดสินใจของผู้เล่น
-- ใช้ได้ทั้งจาก ProximityPrompt และจากการทดสอบ (require(ServerScriptService.Server.CoreLoop).Decide("fuel"))
function CoreLoop.Decide(choice: string, who: string?): boolean
	if decision or not currentVehicle or gameOver or not pumpPrompt.Enabled then
		return false
	end
	decision = choice
	pumpPrompt.Enabled = false
	rejectPrompt.Enabled = false
	print((if choice == "fuel" then "⛽ [" else "🚧 [") .. (who or "?") .. "] " .. (if choice == "fuel" then "เติมน้ำมันให้ลูกค้า" else "ดึงแผงปิดร้าน!"))
	decisionMade:Fire()
	return true
end

pumpPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("fuel", player.Name)
end)

rejectPrompt.Triggered:Connect(function(player)
	CoreLoop.Decide("reject", player.Name)
end)

-- ทดสอบจาก Command Bar / เครื่องมือ: ServerStorage.DevDecision:Fire("fuel" | "reject")
-- (require โมดูลนี้จาก Command Bar จะได้สำเนาใหม่คนละตัวกับที่เกมใช้ จึงต้องสั่งผ่าน BindableEvent)
local devDecision = ServerStorage:FindFirstChild("DevDecision") or Instance.new("BindableEvent")
devDecision.Name = "DevDecision"
devDecision.Parent = ServerStorage
local chooseReply: (string, string) -> boolean
local devSpawn: () -> ()
local shopOpened = false
devDecision.Event:Connect(function(choice: string)
	-- "fuel" | "reject" | "reply:100" | "open"
	local amount = string.match(choice, "^reply:(%w+)$") -- reply:100 / reply:hello / reply:both
	if amount then
		chooseReply(amount, "DevDecision")
	elseif choice == "open" then
		shopOpened = true
	elseif choice == "spawn" then
		devSpawn() -- เสกลูกค้าเพิ่ม 1 คันทันที (ทดสอบคิว)
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
		promptsOpen = pumpPrompt.Enabled,
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
local function say(key: string, speaker: { [string]: string }, vars: { [string]: any }?, hold: number?)
	CustomerSpeech:FireAllClients(key, currentHead, speaker, vars)
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
function chooseReply(id: string, who: string): boolean
	if not replyOpen then
		return false
	end
	for _, o in ipairs(replyOptions) do
		if o.id == id then
			replyOpen = false
			replyId = id
			replyBy = who
			DialogueReply:FireAllClients("close", who, id)
			return true
		end
	end
	return false
end
DialogueReply.OnServerEvent:Connect(function(player, id: any)
	if type(id) == "string" or type(id) == "number" then
		chooseReply(tostring(id), player.DisplayName)
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
	local p = stop + back * (CONFIG.QueueSpacing * (i - 1))
	return Vector3.new(p.X, groundAt(p), p.Z)
end

local function spawnCustomer()
	local v = pickTemplate():Clone()
	local forced = devDecision:GetAttribute("ForceAnomaly")
	devDecision:SetAttribute("ForceAnomaly", nil)
	local ghost
	if forced == "Normal" then
		ghost = false
	elseif type(forced) == "string" and AnomalyManager.Anomalies[forced] then
		ghost = true
	else
		forced = nil
		ghost = math.random() < CONFIG.AnomalyChance
	end
	local anomaly: string? = nil
	local deferred: string? = nil
	if ghost then
		anomaly = if forced then forced else AnomalyManager.Random()
		if AnomalyManager.IsWorld(anomaly :: string) then
			deferred = anomaly
		else
			AnomalyManager.Apply(anomaly :: string, v)
		end
	end
	local useAnomalyLine = ghost and math.random() < 0.6
	local c: Customer = {
		v = v,
		ghost = ghost,
		anomaly = anomaly,
		deferredWorld = deferred,
		who = pickCharacter(if useAnomalyLine then ANOMALY_VOICE[anomaly :: string] else nil),
		useAnomalyLine = useAnomalyLine,
		spawnedAt = os.clock(),
		queuedSince = nil,
		atPump = false,
		serving = false,
	}
	v:SetAttribute("IsAnomaly", ghost)
	v:SetAttribute("AnomalyKey", anomaly or "")
	local start = spawnPoint.Position
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, Vector3.new(stopPoint.Position.X, start.Y, stopPoint.Position.Z)))
	v.Name = "Customer"
	v.Parent = Workspace
	table.insert(queue, c)
	print("🛵 ลูกค้ามา (" .. (if ghost then "ผี " .. tostring(anomaly) else "ปกติ") .. ") คิว " .. #queue)

	-- ขี่ไปช่องของตัวเอง แล้วเลื่อนขึ้นเรื่อยๆ จนถึงตู้ปั๊ม
	task.spawn(function()
		while v.Parent and not c.serving and not gameOver do
			local idx = table.find(queue, c)
			if not idx then
				return
			end
			local target = slotPos(idx)
			local flat = Vector3.new(target.X - v:GetPivot().Position.X, 0, target.Z - v:GetPivot().Position.Z)
			if flat.Magnitude > 0.5 then
				driveTo(v, target, true)
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

function devSpawn()
	if not gameOver and #queue < CONFIG.MaxQueue then
		spawnCustomer()
	end
end

-- เลือกจังหวะครั้งถัดไป
local function pickPacing()
	local total = 0
	for _, p in ipairs(CONFIG.Pacing) do
		total += p.weight
	end
	local r = math.random() * total
	for _, p in ipairs(CONFIG.Pacing) do
		r -= p.weight
		if r <= 0 then
			return p
		end
	end
	return CONFIG.Pacing[1]
end

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- ปล่อยลูกค้าเข้ามาตามจังหวะ (หยุดเมื่อคิวเต็ม)
local function spawnerLoop()
	task.wait(rand({ 3, 5 }))
	while not gameOver do
		local pace = pickPacing()
		for i = 1, pace.count do
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
		local gap = rand(pace.gap)
		local t0 = os.clock()
		while os.clock() - t0 < gap and not gameOver do
			task.wait(0.5)
		end
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
	publishState()

	local ghost = c.ghost
	local who = c.who
	local speaker = { name = who.name }
	local arrivedAt = os.clock()
	currentHead = v:FindFirstChild("DriverNPC") and v.DriverNPC:FindFirstChild("Head")
	local annoyed = 0

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
		say(if greet == "both" then "PlayerGreetBoth" else "PlayerHello", { player = replyBy :: string }, nil, 1.6)
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

	local order = if c.useAnomalyLine then c.anomaly :: string else who.order
	say(order, speaker, nil, 3.2)
	-- ล็อกปุ่มอย่างน้อย InspectLock วิหลังรถจอด (ให้ส่องไฟฉายดู)
	task.wait(math.max(0, CONFIG.InspectLock - (os.clock() - arrivedAt)))
	if not gameOver then
		pumpPrompt.Enabled = true
		rejectPrompt.Enabled = true
	end
	local promptsAt = os.clock()

	-- ถามราคา
	local price = CONFIG.NormalPrice
	local leaveEarly = false
	if not decision and not gameOver then
		say("AskPrice", speaker)
		local answered = askReply(PRICE_OPTIONS, CONFIG.ReplyTime)
		if answered then
			price = tonumber(answered) :: number
			say("PlayerQuote", { player = replyBy :: string }, { amount = price }, 1.6)
			if ghost then
				say("Ghost_Price", speaker, nil, 2.4)
			elseif price < CONFIG.NormalPrice then
				say("Price_Cheap", speaker, { amount = price }, 2.4)
			elseif price == CONFIG.NormalPrice then
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
		pumpPrompt.Enabled = false
		rejectPrompt.Enabled = false
		print("💸 ตั้งราคาแพงไป ลูกค้าไม่เติม")
	else
		choice, annoyed = waitDecisionImpatient(c, speaker, annoyed, promptsAt)
		pumpPrompt.Enabled = false
		rejectPrompt.Enabled = false
	end

	-- ตรวจคำตอบ
	if choice == "fuel" then
		local fillTween = setFuelLevel(0.15, 2)
		if fillTween then
			fillTween.Completed:Wait()
		end
		if ghost then
			-- เติมให้ผี: ธูปดับ 1 ดอก + หักเงิน + ผีหลอก
			say("Ghost_Pay", speaker, { amount = price }, 1.5)
			incense -= 1
			money = math.max(0, money - CONFIG.GhostFuelPenalty)
			refreshIncense()
			TriggerJumpscare:FireAllClients(c.anomaly)
			print("👻 เติมน้ำมันให้ผี! ธูปเหลือ " .. incense)
		elseif annoyed > 0 then
			local paid = math.max(0, price - CONFIG.SlowPenalty)
			money += paid
			say("Pay_Slow", speaker, { amount = paid })
			print("😒 เติมช้า ลูกค้าจ่ายแค่ " .. paid .. "฿ รวม " .. money)
		else
			money += price
			say(pick({ "Pay_1", "Pay_2", "Pay_3" }), speaker, { amount = price })
			print("💰 ลูกค้าปกติ +" .. price .. "฿ รวม " .. money)
		end
		broadcastHUD()
		setFuelLevel(1, 3)
	elseif choice == "reject" then
		closeShutter()
		if ghost then
			money += CONFIG.RejectGhostReward
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
	task.wait(2.6) -- ให้อ่านประโยคสุดท้ายทัน
	CustomerSpeech:FireAllClients(nil)
	currentHead = nil

	-- ออกจากคิว คันหลังเลื่อนขึ้นมาได้เลย แล้วขี่ออก
	local idx = table.find(queue, c)
	if idx then
		table.remove(queue, idx)
	end
	currentVehicle = nil
	currentVehicleIsAnomaly = false
	currentAnomaly = nil
	publishState()
	task.wait(1)
	local exit = exitPoint.Position
	driveTo(v, Vector3.new(exit.X, exit.Y, exit.Z), false)
	v:Destroy()
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
	currentVehicle = nil
	AnomalyManager.ResetAnomalies()
end

-- ---------------------------------------------------------------- ลูปเกม
local function resetGame()
	money = 0
	incense = CONFIG.StartIncense
	gameOver = false
	clearQueue()
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
	AnomalyManager.Init()
	task.spawn(function()
		while true do
			resetGame()
			waitForShopOpen()
			task.spawn(spawnerLoop)
			while not gameOver do
				local front = queue[1]
				if front and front.atPump and not front.serving then
					serveCustomer(front)
					if money >= CONFIG.TargetMoney then
						gameOver = true
						GameState:FireAllClients("Win")
						print("🏆 ครบ " .. CONFIG.TargetMoney .. "฿ ชนะ!")
					elseif incense <= 0 then
						gameOver = true
						GameState:FireAllClients("Lose")
						print("💀 ธูปดับครบ 3 ดอก Game Over")
					end
				else
					task.wait(0.2)
				end
			end
			task.wait(CONFIG.RestartDelay)
		end
	end)
end

CoreLoop.Config = CONFIG
return CoreLoop
