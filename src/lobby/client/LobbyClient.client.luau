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
loop("LobbyEerieAir", "rbxassetid://9114244841", 0.32)

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
-- RoomState(state) -> แผงห้องขวาบน (จำนวนคน, ความยาก, เวลาปิดห้อง, ปุ่มเริ่มเกมของเจ้าของห้อง)
-- ปุ่มสมุดผี / ตั้งค่า มาจาก BookController / SettingsController ตัวเดียวกับเกม (sync ผ่าน lobby.project.json)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Difficulty = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Difficulty"))
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local OpenSetup = remotes:WaitForChild("OpenSetup") :: RemoteEvent
local ConfirmRoom = remotes:WaitForChild("ConfirmRoom") :: RemoteEvent
local CancelSetup = remotes:WaitForChild("CancelSetup") :: RemoteEvent
local StartNow = remotes:WaitForChild("StartNow") :: RemoteEvent
local LeaveRoom = remotes:WaitForChild("LeaveRoom") :: RemoteEvent
local RoomState = remotes:WaitForChild("RoomState") :: RemoteEvent
local Notice = remotes:WaitForChild("Notice") :: RemoteEvent

local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
-- ภาษาเดียวกับหน้าตั้งค่า (Attribute "Lang" จาก PlayerSettings) ถ้ายังไม่มีใช้ภาษาเครื่อง
local function isTH(): boolean
	return LanguageModule.Normalize((player:GetAttribute("Lang") :: string?) or player.LocaleId) == "th"
end
local function tr(th: string, en: string): string
	return if isTH() then th else en
end
local refreshers: { () -> () } = {}
player:GetAttributeChangedSignal("Lang"):Connect(function()
	for _, f in ipairs(refreshers) do
		f()
	end
end)

-- สไตล์เดียวกับหน้าตั้งค่า/HUD ของเกม: แผงดำขอบเส้นบาง หัวข้อแถบเทาหม่น ตัวหนังสือครีม ฟอนต์พิมพ์ดีด ปุ่มที่เลือกเป็นสีเลือด
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Bar = Color3.fromRGB(58, 54, 46),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(150, 142, 124),
	Blood = Color3.fromRGB(150, 18, 16),
	Line = Color3.fromRGB(80, 72, 60),
	Paper = Color3.fromRGB(226, 218, 196),
}
local FONT_BODY = Font.fromEnum(Enum.Font.SpecialElite)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end

local gui = new("ScreenGui", {
	Name = "LobbyRoomGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local function panelFrame(name: string, width: number, props: { [string]: any }): Frame
	local p = new("Frame", {
		Name = name,
		Size = UDim2.new(0, width, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	new("UIStroke", { Color = C.Line, Thickness = 1 }, p)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, p)
	new("UIPadding", { PaddingBottom = UDim.new(0, 14) }, p)
	return p
end
local function header(parent: Instance): TextLabel
	return new("TextLabel", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = C.Bar,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 22,
		LayoutOrder = 0,
	}, parent)
end
-- 1 แถว = ชื่อซ้าย + ตัวควบคุมขวา
local function row(parent: Instance, order: number, height: number?): (Frame, TextLabel)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, height or 40), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, r)
	local l = new("TextLabel", {
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	return r, l
end
local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 17,
		AutoButtonColor = false,
	}, parent)
	new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	return b
end
-- ปุ่มปิด X (เส้นไขว้ 2 เส้น เหมือนหน้าตั้งค่า)
local function closeButton(head: Instance, onClick: () -> ())
	local x = new("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.new(0, 28, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Modal = true,
	}, head)
	local lines = {}
	for _, angle in ipairs({ 45, -45 }) do
		table.insert(lines, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 18, 0, 2),
			Rotation = angle,
			BackgroundColor3 = C.Dim,
			BorderSizePixel = 0,
		}, x))
	end
	x.MouseEnter:Connect(function()
		for _, l in ipairs(lines) do
			l.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
		end
	end)
	x.MouseLeave:Connect(function()
		for _, l in ipairs(lines) do
			l.BackgroundColor3 = C.Dim
		end
	end)
	x.Activated:Connect(onClick)
end

-- ---------------------------------------------------------------- หน้าต่างตั้งห้อง (กลางจอ)
-- ตั้งห้องภายใน 30 วิ ไม่งั้นหน้าต่างปิด ดีดกลับจุดเกิด (Server เป็นคนตัดสิน ตรงนี้แค่โชว์เวลา)
local setup = panelFrame("RoomSetup", 460, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
local setupHead = header(setup)
local setupPad = 0
local setupDeadline = 0
local chosenPlayers, chosenDiff = 4, Difficulty.Default

closeButton(setupHead, function()
	setup.Visible = false
	CancelSetup:FireServer()
end)

local countRow, countLabel = row(setup, 1)
local countButtons: { TextButton } = {}
for i = 1, Difficulty.MaxPlayers do
	countButtons[i] = button(countRow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(Difficulty.MaxPlayers - i) * 36, 0.5, 0),
		Size = UDim2.new(0, 30, 0, 30),
		Text = tostring(i),
	})
end

local diffRow, diffLabel = row(setup, 2)
local diffButtons: { [string]: TextButton } = {}
for i, id in ipairs(Difficulty.Order) do
	diffButtons[id] = button(diffRow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(#Difficulty.Order - i) * 64, 0.5, 0),
		Size = UDim2.new(0, 58, 0, 30),
	})
end

local function valueLabel(parent: Instance): TextLabel
	return new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.6, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, parent)
end
local rewardRow, rewardLabel = row(setup, 3, 30)
local rewardValue = valueLabel(rewardRow)

local confirmRow = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 4 }, setup)
new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, confirmRow)
local setupTimer = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.new(0.5, 0, 1, 0),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, confirmRow)
local confirm = button(confirmRow, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.new(0, 160, 0, 34),
	BackgroundColor3 = C.Blood,
	TextSize = 19,
})

local function drawSetup()
	setupHead.Text = tr(("ตั้งห้องที่ %d"):format(setupPad), ("Set up room %d"):format(setupPad))
	countLabel.Text = tr("จำนวนผู้เล่น", "Players")
	diffLabel.Text = tr("ความยาก", "Difficulty")
	rewardLabel.Text = tr("เงินรางวัลตอนจบ", "End reward")
	confirm.Text = tr("สร้างห้อง", "Create room")
	for i, b in ipairs(countButtons) do
		b.BackgroundColor3 = if i == chosenPlayers then C.Blood else C.Ink
	end
	for id, b in pairs(diffButtons) do
		local d = Difficulty.Levels[id]
		b.Text = if isTH() then d.th else d.en
		b.BackgroundColor3 = if id == chosenDiff then C.Blood else C.Ink
	end
	local d = Difficulty.Get(chosenDiff)
	rewardValue.Text = tr(("×%s  ยิ่งยาก ยิ่งได้เยอะ"):format(tostring(d.reward)), ("×%s  harder pays more"):format(tostring(d.reward)))
end
table.insert(refreshers, drawSetup)
for i, b in ipairs(countButtons) do
	b.Activated:Connect(function()
		chosenPlayers = i
		drawSetup()
	end)
end
for id, b in pairs(diffButtons) do
	b.Activated:Connect(function()
		chosenDiff = id
		drawSetup()
	end)
end
confirm.Activated:Connect(function()
	setup.Visible = false
	ConfirmRoom:FireServer(chosenPlayers, chosenDiff)
end)
OpenSetup.OnClientEvent:Connect(function(padIndex: number?, seconds: number?)
	if padIndex then
		setupPad = padIndex
		setupDeadline = os.clock() + (seconds or 30)
		drawSetup()
		setup.Visible = true
	else
		setup.Visible = false
	end
end)

-- ---------------------------------------------------------------- แผงห้อง (ขวาบน ใต้ปุ่มสมุดผี/ตั้งค่า)
-- เจ้าของกดเริ่มได้ตลอดช่วงรอ; ห้องเต็มนับ 5 วิแล้วไปเอง; ออกจากห้องด้วยปุ่มนี้เท่านั้น
local status = panelFrame("RoomStatus", 320, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 60) })
local statusHead = header(status)
statusHead.TextSize = 19
local function infoRow(order: number): (TextLabel, TextLabel)
	local r, l = row(status, order, 26)
	l.TextSize = 16
	l.TextColor3 = C.Dim
	local v = valueLabel(r)
	v.TextColor3 = C.Cream
	return l, v
end
local playersL, playersV = infoRow(1)
local diffL, diffV = infoRow(2)
local timeL, timeV = infoRow(3)
local leaveHint = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 15,
	LayoutOrder = 4,
}, status)
local actionRow = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 5 }, status)
new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, actionRow)
local startBtn = button(actionRow, { Size = UDim2.new(0.49, 0, 0, 32), Position = UDim2.new(0, 0, 0.5, -16), BackgroundColor3 = C.Blood, TextSize = 18 })
local leaveBtn = button(actionRow, { Size = UDim2.new(0.49, 0, 0, 32), Position = UDim2.new(0.51, 0, 0.5, -16), BackgroundColor3 = C.Bar, TextSize = 18 })
startBtn.Activated:Connect(function()
	startBtn.Visible = false
	StartNow:FireServer()
end)
leaveBtn.Activated:Connect(function()
	leaveBtn.Visible = false
	LeaveRoom:FireServer()
end)

local lastState = nil
local function drawStatus()
	local s = lastState
	if not s then
		status.Visible = false
		return
	end
	local d = Difficulty.Get(s.difficulty)
	status.Visible = true
	statusHead.Text = tr("ห้องของ ", "Room of ") .. s.hostName
	playersL.Text = tr("ผู้เล่น", "Players")
	playersV.Text = ("%d / %d"):format(s.count, s.maxPlayers)
	diffL.Text = tr("ความยาก", "Difficulty")
	diffV.Text = ("%s  ×%s"):format(if isTH() then d.th else d.en, tostring(d.reward))
	diffV.TextColor3 = d.color
	if s.launching then
		timeL.Text = tr("สถานะ", "Status")
		timeV.Text = tr("กำลังไปที่ปั๊ม...", "Heading to the pump...")
	elseif s.fullCountdown then
		timeL.Text = tr("เต็มแล้ว · ไปเกมใน", "Full · teleporting in")
		timeV.Text = tr(("%d"):format(s.fullCountdown), ("%d"):format(s.fullCountdown))
		timeV.TextColor3 = Color3.fromRGB(220, 60, 50)
	else
		timeL.Text = tr("รอผู้เล่น", "Waiting for players")
		timeV.Text = tr(("%d วิ"):format(s.countdown), ("%ds"):format(s.countdown))
		timeV.TextColor3 = if s.countdown <= 10 then Color3.fromRGB(220, 60, 50) else C.Cream
	end
	leaveHint.Text = if s.isHost
		then tr("กดเริ่มได้ทุกเมื่อ · ออกจากห้องด้วยปุ่มด้านล่าง", "Start anytime · use the button below to leave")
		else tr("รอเจ้าของห้องเริ่ม · ออกจากห้องด้วยปุ่มด้านล่าง", "Waiting for the host · use the button below to leave")
	startBtn.Text = tr("เริ่มเกม", "Start")
	leaveBtn.Text = tr("ออกจากห้อง", "Leave")
	actionRow.Visible = not s.launching
	startBtn.Visible = s.isHost and not s.launching
	leaveBtn.Visible = not s.launching
	if s.isHost then
		startBtn.Size = UDim2.new(0.49, 0, 0, 32)
		leaveBtn.Size = UDim2.new(0.49, 0, 0, 32)
		leaveBtn.Position = UDim2.new(0.51, 0, 0.5, -16)
	else
		leaveBtn.Size = UDim2.new(1, 0, 0, 32)
		leaveBtn.Position = UDim2.new(0, 0, 0.5, -16)
	end
end
table.insert(refreshers, drawStatus)
RoomState.OnClientEvent:Connect(function(s)
	lastState = s
	drawStatus()
end)

-- เวลาที่เหลือในหน้าต่างตั้งห้อง
task.spawn(function()
	while true do
		task.wait(0.25)
		if setup.Visible then
			local left = math.max(0, math.ceil(setupDeadline - os.clock()))
			setupTimer.Text = tr(("ปิดใน %d วิ"):format(left), ("Closes in %ds"):format(left))
			setupTimer.TextColor3 = if left <= 10 then Color3.fromRGB(220, 60, 50) else C.Dim
		end
	end
end)

-- ---------------------------------------------------------------- คำอธิบายปุ่ม (ขวาล่าง แบบป้ายกระดาษเหมือน HUD ในเกม)
local hints = new("Frame", { Name = "KeyHints", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -40), Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, hints)
local function keyHint(order: number): (TextLabel, TextLabel)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order }, hints)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local badge = new("TextLabel", {
		BackgroundColor3 = C.Paper,
		Size = UDim2.new(0, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BODY,
		TextColor3 = C.Ink,
		TextSize = 16,
		Rotation = math.random(-3, 3),
		LayoutOrder = 1,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, badge)
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, badge)
	new("UIStroke", { Color = Color3.fromRGB(90, 80, 62), Thickness = 1 }, badge)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 17,
		LayoutOrder = 0, -- คำอธิบายอยู่ซ้าย ป้ายคีย์อยู่ขวา
	}, holder)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }, label)
	return badge, label
end
-- { ป้าย TH, ป้าย EN, คำอธิบาย TH, คำอธิบาย EN }
local HINTS = {
	{ "WASD", "WASD", "เดิน", "Walk" },
	{ "วงแดง", "Ring", "เดินเข้าวง สร้าง / เข้าห้อง", "Walk into a ring to host / join" },
	{ "ออกห้อง", "Leave", "ใช้ปุ่มออกจากห้อง", "Use the Leave button" },
}
local hintLabels = {}
for i in ipairs(HINTS) do
	hintLabels[i] = { keyHint(i) }
end
local function drawHints()
	for i, h in ipairs(HINTS) do
		hintLabels[i][1].Text = tr(h[1], h[2])
		hintLabels[i][2].Text = tr(h[3], h[4])
	end
end
table.insert(refreshers, drawHints)
drawHints()

-- ---------------------------------------------------------------- ข้อความแจ้งเตือนสั้นๆ (กลางจอบน ไม่บังพื้นที่พื้น/วงห้อง)
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.new(0, 560, 0, 30),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 20,
	Text = "",
}, gui)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.2 }, toast)
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
