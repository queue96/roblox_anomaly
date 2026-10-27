-- LobbyClient.client.luau
-- สคริปต์ฝั่ง Client ของ place "Lobby" — sync ผ่าน lobby.project.json พอร์ต 34873
-- บรรยากาศวัด: เสียงจิ้งหรีด/ลมหวิว, หลอดไฟ/เทียนกะพริบ (tag FlickerLamp), เงาคนใต้ต้นไทรจางหายเมื่อเดินเข้าใกล้ (tag Apparition)
-- หน้าที่ (ทำต่อ): UI ใน Lobby เช่น ปุ่มสลับภาษา TH/EN, เลือกจำนวนผู้เล่น/ความยากในโซนสร้างห้อง, สมุดสะสมผี

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- เสียงชุดเดียวกับ AmbienceController ของแมพเกม
local function loop(name: string, id: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end
loop("LobbyCrickets", "rbxassetid://9112764023", 0.35)
loop("LobbyCricketsFar", "rbxassetid://9112764040", 0.2)
loop("LobbyEerieAir", "rbxassetid://9114244841", 0.25)

-- หลอดไฟ/เทียนกะพริบ: ปกติสว่างนิ่ง แล้วสะดุดวูบเป็นพักๆ (สุ่มจังหวะแยกกันทุกดวง)
local function flicker(part: Instance)
	local light = part:FindFirstChildOfClass("PointLight")
	if not light or not part:IsA("BasePart") then
		return
	end
	local base = light.Brightness
	task.spawn(function()
		local rng = Random.new()
		while part.Parent do
			task.wait(rng:NextNumber(2, 9))
			for _ = 1, rng:NextInteger(2, 5) do
				light.Brightness = base * rng:NextNumber(0.05, 0.4)
				part.Transparency = 0.6
				task.wait(rng:NextNumber(0.04, 0.12))
				light.Brightness = base
				part.Transparency = 0
				task.wait(rng:NextNumber(0.05, 0.2))
			end
		end
	end)
end
for _, p in ipairs(CollectionService:GetTagged("FlickerLamp")) do
	flicker(p)
end
CollectionService:GetInstanceAddedSignal("FlickerLamp"):Connect(flicker)

-- เงาคนใต้ต้นไทร: เห็นได้จากไกลๆ พอเดินเข้าใกล้ 45 studs จะจางหายไป ถอยออกเกิน 70 studs ค่อยกลับมายืนที่เดิม
local NEAR, FAR = 45, 70
local function haunt(ghost: Instance)
	if not ghost:IsA("Model") then
		return
	end
	local parts = {}
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[d] = d.Transparency
		end
	end
	local shown = true
	local function fade(visible: boolean)
		shown = visible
		for p, t in pairs(parts) do
			TweenService:Create(p, TweenInfo.new(if visible then 2.5 else 0.6), { Transparency = if visible then t else 1 }):Play()
		end
	end
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not ghost.Parent then
			conn:Disconnect()
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local d = (root.Position - ghost:GetPivot().Position).Magnitude
		if shown and d < NEAR then
			fade(false)
		elseif not shown and d > FAR then
			fade(true)
		end
	end)
end
for _, g in ipairs(CollectionService:GetTagged("Apparition")) do
	haunt(g)
end
CollectionService:GetInstanceAddedSignal("Apparition"):Connect(haunt)

-- ---------------------------------------------------------------- โซนสร้างห้อง (UI)
-- OpenSetup(padIndex) -> หน้าต่างเลือกจำนวนผู้เล่น 1–6 + ความยาก (แสดงตัวคูณเงินรางวัล) -> ConfirmRoom
-- RoomState(state) -> แผงสถานะห้องมุมจอ (จำนวนคน, ความยาก, นับถอยหลัง, ปุ่มเริ่มเลยสำหรับเจ้าของห้อง)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Difficulty = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Difficulty"))
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local OpenSetup = remotes:WaitForChild("OpenSetup") :: RemoteEvent
local ConfirmRoom = remotes:WaitForChild("ConfirmRoom") :: RemoteEvent
local CancelSetup = remotes:WaitForChild("CancelSetup") :: RemoteEvent
local StartNow = remotes:WaitForChild("StartNow") :: RemoteEvent
local RoomState = remotes:WaitForChild("RoomState") :: RemoteEvent
local Notice = remotes:WaitForChild("Notice") :: RemoteEvent

local TH = string.sub(string.lower(player.LocaleId), 1, 2) == "th"
local function tr(th: string, en: string): string
	return if TH then th else en
end

local INK = Color3.fromRGB(235, 222, 204)
local PANEL = Color3.fromRGB(22, 18, 18)
local BLOOD = Color3.fromRGB(150, 36, 30)

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyRoomGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function frame(parent: Instance, size: UDim2, pos: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = BLOOD
	s.Thickness = 2
	s.Parent = f
	f.Parent = parent
	return f
end
local function text(parent: Instance, str: string, size: UDim2, pos: UDim2, scale: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = size
	t.Position = pos
	t.Text = str
	t.TextColor3 = INK
	t.Font = Enum.Font.GothamMedium
	t.TextScaled = true
	t.TextWrapped = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = scale or 22
	c.Parent = t
	t.Parent = parent
	return t
end
local function button(parent: Instance, str: string, size: UDim2, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Text = str
	b.TextColor3 = INK
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(48, 38, 36)
	b.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local k = Instance.new("UITextSizeConstraint")
	k.MaxTextSize = 20
	k.Parent = b
	b.Parent = parent
	return b
end

-- หน้าต่างตั้งห้อง
local setup = frame(gui, UDim2.fromOffset(420, 330), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
setup.Visible = false
local setupTitle = text(setup, "", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(10, 10), 26)
text(setup, tr("จำนวนผู้เล่น", "Players"), UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 52), 18)
local chosenPlayers, chosenDiff = 4, Difficulty.Default
local countButtons: { TextButton } = {}
for i = 1, Difficulty.MaxPlayers do
	local b = button(setup, tostring(i), UDim2.fromOffset(56, 40), UDim2.fromOffset(10 + (i - 1) * 67, 78))
	countButtons[i] = b
	b.Activated:Connect(function()
		chosenPlayers = i
		for k, other in ipairs(countButtons) do
			other.BackgroundColor3 = if k == i then BLOOD else Color3.fromRGB(48, 38, 36)
		end
	end)
end
text(setup, tr("ความยาก (ยิ่งยาก เงินรางวัลตอนจบยิ่งเยอะ)", "Difficulty (harder = bigger reward)"), UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 128), 18)
local diffButtons: { [string]: TextButton } = {}
for i, id in ipairs(Difficulty.Order) do
	local d = Difficulty.Levels[id]
	local b = button(setup, ("%s\n×%s"):format(if TH then d.th else d.en, tostring(d.reward)), UDim2.fromOffset(95, 62), UDim2.fromOffset(10 + (i - 1) * 101, 154))
	diffButtons[id] = b
	b.TextColor3 = d.color
	b.Activated:Connect(function()
		chosenDiff = id
		for k, other in pairs(diffButtons) do
			other.BackgroundColor3 = if k == id then Color3.fromRGB(70, 30, 28) else Color3.fromRGB(48, 38, 36)
		end
	end)
end
local confirm = button(setup, tr("สร้างห้อง", "Create room"), UDim2.fromOffset(190, 46), UDim2.fromOffset(10, 270))
confirm.BackgroundColor3 = BLOOD
local cancel = button(setup, tr("ยกเลิก", "Cancel"), UDim2.fromOffset(190, 46), UDim2.fromOffset(220, 270))
local function selectDefaults()
	countButtons[chosenPlayers].BackgroundColor3 = BLOOD
	diffButtons[chosenDiff].BackgroundColor3 = Color3.fromRGB(70, 30, 28)
end
selectDefaults()
confirm.Activated:Connect(function()
	setup.Visible = false
	ConfirmRoom:FireServer(chosenPlayers, chosenDiff)
end)
cancel.Activated:Connect(function()
	setup.Visible = false
	CancelSetup:FireServer()
end)
OpenSetup.OnClientEvent:Connect(function(padIndex: number?)
	if padIndex then
		setupTitle.Text = tr(("ตั้งห้องที่ %d"):format(padIndex), ("Set up room %d"):format(padIndex))
		setup.Visible = true
	else
		setup.Visible = false
	end
end)

-- แผงสถานะห้อง (มุมขวาบน)
local status = frame(gui, UDim2.fromOffset(280, 150), UDim2.new(1, -16, 0, 70), Vector2.new(1, 0))
status.Visible = false
local statusText = text(status, "", UDim2.new(1, -20, 0, 92), UDim2.fromOffset(10, 8), 20)
statusText.TextXAlignment = Enum.TextXAlignment.Left
local startBtn = button(status, tr("ออกเดินทางเลย", "Leave now"), UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 106))
startBtn.BackgroundColor3 = BLOOD
startBtn.Activated:Connect(function()
	StartNow:FireServer()
end)
RoomState.OnClientEvent:Connect(function(s)
	if not s then
		status.Visible = false
		return
	end
	local d = Difficulty.Get(s.difficulty)
	status.Visible = true
	startBtn.Visible = s.isHost and not s.launching
	status.Size = UDim2.fromOffset(280, if startBtn.Visible then 150 else 108)
	local line3 = if s.launching
		then tr("กำลังออกเดินทาง...", "Departing...")
		else tr(("ออกเดินทางใน %d วิ · เดินออกจากวงเพื่อออก"):format(s.countdown), ("Leaving in %ds · step out to leave"):format(s.countdown))
	statusText.Text = ("%s\n%s · %d/%d · ×%s\n%s"):format(
		tr("ห้องของ ", "Room of ") .. s.hostName,
		if TH then d.th else d.en,
		s.count,
		s.maxPlayers,
		tostring(d.reward),
		line3
	)
end)

-- ข้อความแจ้งเตือนสั้นๆ กลางจอล่าง
local toast = text(gui, "", UDim2.fromOffset(520, 40), UDim2.new(0.5, -260, 1, -120), 22)
toast.TextStrokeTransparency = 0.3
local toastId = 0
Notice.OnClientEvent:Connect(function(th: string, en: string)
	toastId += 1
	local my = toastId
	toast.Text = tr(th, en)
	task.delay(4, function()
		if toastId == my then
			toast.Text = ""
		end
	end)
end)

print("✅ [Lobby] Client พร้อม: " .. player.Name)
