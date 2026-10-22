-- CoreLoop.luau (ModuleScript ฝั่ง Server)
-- Phase 3: ลูปหลักของเกม "ปั๊มหลอดท้ายทุ่ง"
--   รถลูกค้า (Clone จาก ServerStorage.VehicleTemplates) ขี่จาก SpawnPoint มาจอดที่ StopPoint
--   -> ล็อกปุ่ม 3 วินาทีให้ผู้เล่นส่องไฟฉายดูก่อน
--   -> ผู้เล่นเลือก "เติมน้ำมัน" (กดค้าง 3 วิ ที่ตู้ปั๊ม) หรือ "ดึงแผงปิดร้าน" (กดค้าง 0.5 วิ ที่เชือก)
--   -> ตรวจคำตอบจาก currentVehicleIsAnomaly: ถูกได้เงิน / เติมให้ผีธูปดับ 1 ดอก + หักเงิน
--   -> รถขี่ออกไปทาง ExitPoint แล้วเสกคันต่อไป  ครบ 500฿ = ชนะ  ธูปดับครบ 3 ดอก = แพ้
-- Phase 4 จะเพิ่มชนิดผีโดยใส่ฟังก์ชันใน ANOMALIES (ตอนนี้มี 3 แบบที่ใช้ชิ้นส่วนในรถแม่แบบ)

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
	FuelReward = 100, -- เติมน้ำมันให้ลูกค้าปกติ
	RejectGhostReward = 50, -- ดึงแผงปิดร้านใส่ผีได้ถูกต้อง
	GhostFuelPenalty = 100, -- เผลอเติมน้ำมันให้ผี (หักเงิน + ธูปดับ 1 ดอก)
	StartIncense = 3,
	AnomalyChance = 0.4,
	InspectLock = 3, -- วินาทีที่ล็อกปุ่มหลังรถจอด (ให้ส่องไฟฉายดู)
	DecisionTime = 25, -- ถ้าไม่มีใครตัดสินใจ ลูกค้าจะขับออกไปเอง
	DriveSpeed = 24, -- studs / วินาที
	NextCustomerDelay = { 3, 6 },
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
local GameState = remote("GameState") -- ("Win" | "Lose" | "Playing", messageKey)

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
	prompt.Enabled = false
	return prompt
end
local pumpPrompt = setupPrompt("PumpFuelPrompt", pumpBody, 3, "เติมน้ำมัน / Fill Up", "ตู้ปั๊มหลอด / Gas Pump")
local rejectPrompt = setupPrompt("RejectCustomerPrompt", rejectRope, 0.5, "ปิดร้าน! / Close Shop!", "เชือกแผงสังกะสี / Shutter Rope")

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

-- ---------------------------------------------------------------- ผีที่ซ่อนในรถแม่แบบ
local function showPart(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		local t = d:GetAttribute("ShowTransparency")
		if t ~= nil and (d:IsA("BasePart") or d:IsA("Decal")) then
			(d :: any).Transparency = t
		end
	end
end

-- key = ชื่อ anomaly (ใช้เป็นคีย์บทพูดใน LanguageModule ด้วย), ฟังก์ชันรับรถที่ Clone แล้ว
local ANOMALIES: { [string]: (Model) -> () } = {
	Anomaly_Headless = function(v)
		local g = v:FindFirstChild("GhostPassenger")
		if g then
			showPart(g)
		end
	end,
	Anomaly_Cemetery = function(v)
		local plate = v:FindFirstChild("LicensePlate")
		if plate then
			plate.NormalPlate.Enabled = false
			plate.GhostPlate.Enabled = true
		end
	end,
	Anomaly_WheelHair = function(v)
		local h = v:FindFirstChild("WheelHairAnomaly")
		if h then
			showPart(h)
		end
	end,
}
local ANOMALY_KEYS = {}
for k in pairs(ANOMALIES) do
	table.insert(ANOMALY_KEYS, k)
end
table.sort(ANOMALY_KEYS)
local NORMAL_LINES = { "Normal_Uncle", "Normal_Aunt", "Normal_Student", "Normal_Farmer" }

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
devDecision.Event:Connect(function(choice: string)
	CoreLoop.Decide(choice, "DevDecision")
end)

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

-- ---------------------------------------------------------------- 1 รอบลูกค้า
local function pickTemplate(): Model
	local bike = templates:FindFirstChild("CustomerBike") :: Model
	local saleng = templates:FindFirstChild("Saleng") :: Model?
	if saleng and math.random() < 0.3 then
		return saleng
	end
	return bike
end

local function serveOneCustomer()
	local tpl = pickTemplate()
	local v = tpl:Clone()
	currentVehicleIsAnomaly = math.random() < CONFIG.AnomalyChance
	currentAnomaly = nil
	if currentVehicleIsAnomaly then
		currentAnomaly = ANOMALY_KEYS[math.random(#ANOMALY_KEYS)]
		ANOMALIES[currentAnomaly](v)
	end
	publishState()
	v:SetAttribute("IsAnomaly", currentVehicleIsAnomaly)
	v:SetAttribute("AnomalyKey", currentAnomaly or "")
	local start = spawnPoint.Position
	local stop = stopPoint.Position
	start = Vector3.new(start.X, groundAt(start), start.Z)
	v:PivotTo(CFrame.lookAt(start, Vector3.new(stop.X, start.Y, stop.Z)))
	v.Name = "Customer"
	v.Parent = Workspace
	currentVehicle = v
	decision = nil

	-- ขี่มาจอด
	driveTo(v, stop, true)
	if gameOver then
		v:Destroy()
		return
	end
	-- พูดสั่งน้ำมัน (แต่ละ Client แปลภาษาเองตาม LocaleId)
	local head = v:FindFirstChild("DriverNPC") and v.DriverNPC:FindFirstChild("Head")
	local line = if currentVehicleIsAnomaly and math.random() < 0.6 then currentAnomaly else NORMAL_LINES[math.random(#NORMAL_LINES)]
	CustomerSpeech:FireAllClients(line, head)
	-- ล็อกปุ่ม 3 วิแรกให้ส่องไฟฉาย
	task.wait(CONFIG.InspectLock)
	if not gameOver then
		pumpPrompt.Enabled = true
		rejectPrompt.Enabled = true
	end
	local choice = waitDecision(CONFIG.DecisionTime)
	pumpPrompt.Enabled = false
	rejectPrompt.Enabled = false
	CustomerSpeech:FireAllClients(nil)

	-- ตรวจคำตอบ
	if choice == "fuel" then
		local fillTween = setFuelLevel(0.15, 2)
		if fillTween then
			fillTween.Completed:Wait()
		end
		if currentVehicleIsAnomaly then
			-- เติมให้ผี: ธูปดับ 1 ดอก + หักเงิน + ผีหลอก
			incense -= 1
			money = math.max(0, money - CONFIG.GhostFuelPenalty)
			refreshIncense()
			TriggerJumpscare:FireAllClients(currentAnomaly)
			print("👻 เติมน้ำมันให้ผี! ธูปเหลือ " .. incense)
		else
			money += CONFIG.FuelReward
			print("💰 ลูกค้าปกติ +" .. CONFIG.FuelReward .. "฿ รวม " .. money)
		end
		broadcastHUD()
		setFuelLevel(1, 3)
	elseif choice == "reject" then
		closeShutter()
		if currentVehicleIsAnomaly then
			money += CONFIG.RejectGhostReward
			print("✅ ไล่ผีถูกต้อง +" .. CONFIG.RejectGhostReward .. "฿ รวม " .. money)
		else
			print("😤 ปิดร้านใส่ลูกค้าปกติ อดได้เงิน")
		end
		broadcastHUD()
		task.delay(3, openShutter)
	else
		print("⌛ ไม่มีใครตัดสินใจ ลูกค้าขับออกไปเอง")
	end

	-- ขี่ออก
	task.wait(1)
	local exit = exitPoint.Position
	driveTo(v, Vector3.new(exit.X, exit.Y, exit.Z), false)
	v:Destroy()
	currentVehicle = nil
end

-- ---------------------------------------------------------------- ลูปเกม
local function resetGame()
	money = 0
	incense = CONFIG.StartIncense
	gameOver = false
	refreshIncense()
	setFuelLevel(1, 0.5)
	broadcastHUD()
	GameState:FireAllClients("Playing")
end

function CoreLoop.Start()
	math.randomseed(os.time())
	task.spawn(function()
		while true do
			resetGame()
			task.wait(4)
			while not gameOver do
				serveOneCustomer()
				if money >= CONFIG.TargetMoney then
					gameOver = true
					GameState:FireAllClients("Win")
					print("🏆 ครบ " .. CONFIG.TargetMoney .. "฿ ชนะ!")
				elseif incense <= 0 then
					gameOver = true
					GameState:FireAllClients("Lose")
					print("💀 ธูปดับครบ 3 ดอก Game Over")
				else
					task.wait(math.random(CONFIG.NextCustomerDelay[1], CONFIG.NextCustomerDelay[2]))
				end
			end
			task.wait(CONFIG.RestartDelay)
		end
	end)
end

CoreLoop.Config = CONFIG
return CoreLoop
