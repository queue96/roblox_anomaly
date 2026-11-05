-- LobbyClient.client.luau
-- สคริปต์ฝั่ง Client ของ place "Lobby" — sync ผ่าน lobby.project.json พอร์ต 34873
-- บรรยากาศวัด: เสียงจิ้งหรีด/ลมหวิว, หลอดไฟ/เทียนกะพริบ (tag FlickerLamp), เงาคนใต้ต้นไทรจางหายเมื่อเดินเข้าใกล้ (tag Apparition)
-- หน้าที่ (ทำต่อ): UI ใน Lobby เช่น ปุ่มสลับภาษา TH/EN, เลือกจำนวนผู้เล่น/ความยากในโซนสร้างห้อง, สมุดสะสมผี

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- ขอบจอมืดสลัว (Screen Vignette) ให้ฉากวัดกลางคืนดูมีมิติและลุ่มลึก
do
	local vignetteGui = Instance.new("ScreenGui")
	vignetteGui.Name = "LobbyVignette"
	vignetteGui.IgnoreGuiInset = true
	vignetteGui.ScreenInsets = Enum.ScreenInsets.None -- เต็มจอจริงถึงขอบ (มือถือมีติ่ง/ขอบโค้ง: ค่าเริ่มต้นถูกบีบไว้ใน safe area เหลือแถบเกินขอบ)
	vignetteGui.ResetOnSpawn = false
	vignetteGui.DisplayOrder = 0
	vignetteGui.Parent = player:WaitForChild("PlayerGui")

	local function edge(name: string, pos: UDim2, anchor: Vector2, size: UDim2, rot: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = anchor
		f.Position = pos
		f.Size = size
		f.BackgroundColor3 = Color3.fromRGB(3, 5, 8)
		f.BackgroundTransparency = 0.40
		f.BorderSizePixel = 0
		f.Active = false
		f.Interactable = false
		f.Parent = vignetteGui

		local g = Instance.new("UIGradient")
		g.Rotation = rot
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.45, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end

	edge("TopEdge", UDim2.fromScale(0, 0), Vector2.new(0, 0), UDim2.fromScale(1, 0.22), 90)
	edge("BottomEdge", UDim2.fromScale(0, 1), Vector2.new(0, 1), UDim2.fromScale(1, 0.22), 270)
	edge("LeftEdge", UDim2.fromScale(0, 0), Vector2.new(0, 0), UDim2.fromScale(0.18, 1), 0)
	edge("RightEdge", UDim2.fromScale(1, 0), Vector2.new(1, 0), UDim2.fromScale(0.18, 1), 180)
end

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

-- เพลงพื้นหลังใน Lobby (เจ้าของเกมอัปโหลด 2 เพลง): สุ่มเพลงแรก แล้วสลับกันเล่นไปเรื่อยๆ จบเพลงก็ต่อเพลงถัดไป
-- อยู่กลุ่ม Music (ปรับได้ในหน้าตั้งค่า) ดังพอให้เสียงจิ้งหรีด/ลมยังได้ยิน
local LOBBY_MUSIC = { "rbxassetid://104311340770672", "rbxassetid://130247096894596" }
local LOBBY_MUSIC_VOLUME = 0.175 -- ลดครึ่งหนึ่ง (เดิม 0.35)
do
	local music = Instance.new("Sound")
	music.Name = "LobbyMusic"
	music.Volume = LOBBY_MUSIC_VOLUME
	music.Looped = false
	music:SetAttribute("SoundCategory", "Music")
	music.Parent = SoundService
	local idx = math.random(#LOBBY_MUSIC)
	local function playNext()
		music.SoundId = LOBBY_MUSIC[idx]
		idx = idx % #LOBBY_MUSIC + 1
		-- เปลี่ยน SoundId แล้วต้องรอโหลดก่อนค่อย Play (เรียก Play ทันทีใน Ended = เงียบ ไม่ขึ้นเพลงถัดไป)
		task.spawn(function()
			local t0 = os.clock()
			while not music.IsLoaded and os.clock() - t0 < 10 do
				task.wait(0.1)
			end
			music.TimePosition = 0
			music:Play()
		end)
	end
	music.Ended:Connect(playNext)
	playNext()
end

-- หลอดไฟ/เทียนกะพริบ: ปกติสว่างนิ่ง แล้วสะดุดวูบเป็นพักๆ (สุ่มจังหวะแยกกันทุกดวง)
local function flicker(part: Instance)
	local light = part:FindFirstChildOfClass("PointLight")
	if not light or not part:IsA("BasePart") then
		return
	end
	local base = light.Brightness
	-- เพิ่มแมลงเม่าบินตอมไฟเสาไม้ในวัด (เฉพาะโคมไฟเสาสูง ไม่ติดที่เทียนดวงเล็ก)
	if light.Range >= 20 and not part:FindFirstChild("NightMoths") then
		local moths = Instance.new("ParticleEmitter")
		moths.Name = "NightMoths"
		moths.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		moths.Shape = Enum.ParticleEmitterShape.Sphere
		moths.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		moths.Rate = 5
		moths.Lifetime = NumberRange.new(2.2, 3.8)
		moths.Speed = NumberRange.new(0.9, 1.8)
		moths.SpreadAngle = Vector2.new(180, 180)
		moths.Acceleration = Vector3.new(0, 0.55, 0)
		moths.Drag = 1.6
		moths.Rotation = NumberRange.new(0, 360)
		moths.RotSpeed = NumberRange.new(-180, 180)
		moths.Color = ColorSequence.new(Color3.fromRGB(245, 225, 175))
		moths.LightEmission = 0.55
		moths.LightInfluence = 0.45
		moths.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.5, 0.13),
			NumberSequenceKeypoint.new(1, 0.04),
		})
		moths.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.22),
			NumberSequenceKeypoint.new(0.8, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		moths.Parent = part
	end
	task.spawn(function()
		local rng = Random.new()
		while part.Parent do
			task.wait(rng:NextNumber(20, 48))
			for _ = 1, rng:NextInteger(1, 2) do
				light.Brightness = base * rng:NextNumber(0.15, 0.45)
				part.Transparency = 0.6
				task.wait(rng:NextNumber(0.04, 0.1))
				light.Brightness = base
				part.Transparency = 0
				task.wait(rng:NextNumber(0.06, 0.16))
			end
		end
	end)
end
for _, p in ipairs(CollectionService:GetTagged("FlickerLamp")) do
	flicker(p)
end
CollectionService:GetInstanceAddedSignal("FlickerLamp"):Connect(flicker)

-- ควันธูปลอยจากศาลพระภูมิใต้ต้นไทรในวัด Lobby
task.spawn(function()
	local lobby = workspace:WaitForChild("TempleLobby", 15)
	local spooky = lobby and lobby:WaitForChild("SpookyDecor", 10)
	if not spooky then
		return
	end
	for i = 1, 3 do
		local tip = spooky:FindFirstChild("Incense" .. i .. "_Neon", true)
		if tip and tip:IsA("BasePart") and not tip:FindFirstChild("IncenseSmoke") then
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "IncenseSmoke"
			smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
			smoke.Rate = 8
			smoke.Lifetime = NumberRange.new(2.2, 3.4)
			smoke.Speed = NumberRange.new(0.22, 0.42)
			smoke.SpreadAngle = Vector2.new(10, 10)
			smoke.Acceleration = Vector3.new(0.28, 1.35, 0.12)
			smoke.Drag = 0.65
			smoke.Rotation = NumberRange.new(0, 360)
			smoke.RotSpeed = NumberRange.new(-25, 25)
			smoke.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(225, 212, 195)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(145, 152, 165)),
			})
			smoke.Brightness = 0.75
			smoke.LightInfluence = 0.35
			smoke.LightEmission = 0.08
			smoke.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.06),
				NumberSequenceKeypoint.new(0.4, 0.22),
				NumberSequenceKeypoint.new(1, 0.56),
			})
			smoke.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.65),
				NumberSequenceKeypoint.new(0.22, 0.42),
				NumberSequenceKeypoint.new(0.75, 0.72),
				NumberSequenceKeypoint.new(1, 1),
			})
			smoke.Parent = tip
		end
	end
end)

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
	Dim = Color3.fromRGB(165, 156, 136),
	Blood = Color3.fromRGB(150, 18, 16),
	BloodLit = Color3.fromRGB(205, 36, 28),
	Panel = Color3.fromRGB(22, 20, 17),
	Line = Color3.fromRGB(70, 64, 54),
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

-- มือถือ/แท็บเล็ต (จอสัมผัส ไม่มีคีย์บอร์ด): ตัวหนังสือใหญ่ขึ้น ปุ่มกดง่ายขึ้น ป้ายคีย์ไม่ทับปุ่มกระโดด
-- (จอสัมผัส + จอเตี้ย ก็นับด้วย: เครื่องจำลองมือถือใน Studio รายงานว่ามีคีย์บอร์ด แต่โน้ตบุ๊กจอสัมผัสจอสูงเกิน 500 อยู่แล้ว)
local IS_TOUCH = UserInputService.TouchEnabled
	and (not UserInputService.KeyboardEnabled or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 500))

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
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, p)
	new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.2 }, p)
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
			l.BackgroundColor3 = C.BloodLit
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
local chosenPlayers = 4
-- ไม่มีให้เลือกความยากแล้ว: ส่งค่าเริ่มต้น (Shared.Difficulty.Default) ให้ Server เสมอ
local ROOM_DIFFICULTY = Difficulty.Default
-- ขนาดปุ่ม/ตัวหนังสือ: มือถือใหญ่ขึ้นให้นิ้วกดโดน
local NUM_BTN = if IS_TOUCH then 46 else 34
local NUM_GAP = if IS_TOUCH then 8 else 6
local ROW_H = if IS_TOUCH then 58 else 46
local LABEL_SIZE = if IS_TOUCH then 21 else 18

closeButton(setupHead, function()
	setup.Visible = false
	CancelSetup:FireServer()
end)

local countRow, countLabel = row(setup, 1, ROW_H)
countLabel.TextSize = LABEL_SIZE
local countButtons: { TextButton } = {}
for i = 1, Difficulty.MaxPlayers do
	countButtons[i] = button(countRow, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(Difficulty.MaxPlayers - i) * (NUM_BTN + NUM_GAP), 0.5, 0),
		Size = UDim2.new(0, NUM_BTN, 0, NUM_BTN),
		Text = tostring(i),
		TextSize = if IS_TOUCH then 24 else 19,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, countButtons[i])
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
local confirmRow = new("Frame", { Size = UDim2.new(1, 0, 0, if IS_TOUCH then 60 else 48), BackgroundTransparency = 1, LayoutOrder = 4 }, setup)
new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, confirmRow)
local setupTimer = new("TextLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 0, 0.5, 0),
	Size = UDim2.new(0.5, 0, 1, 0),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = if IS_TOUCH then 18 else 16,
	TextXAlignment = Enum.TextXAlignment.Left,
}, confirmRow)
local confirm = button(confirmRow, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.new(0, if IS_TOUCH then 200 else 170, 0, if IS_TOUCH then 48 else 38),
	BackgroundColor3 = C.Blood,
	TextSize = if IS_TOUCH then 22 else 19,
})
new("UICorner", { CornerRadius = UDim.new(0, 3) }, confirm)

local function drawSetup()
	setupHead.Text = tr(("ตั้งห้องที่ %d"):format(setupPad), ("Set up room %d"):format(setupPad))
	countLabel.Text = tr("จำนวนผู้เล่น", "Players")
	confirm.Text = tr("สร้างห้อง", "Create room")
	for i, b in ipairs(countButtons) do
		b.BackgroundColor3 = if i == chosenPlayers then C.Blood else C.Ink
	end
end
table.insert(refreshers, drawSetup)
for i, b in ipairs(countButtons) do
	b.Activated:Connect(function()
		chosenPlayers = i
		drawSetup()
	end)
end
confirm.Activated:Connect(function()
	setup.Visible = false
	ConfirmRoom:FireServer(chosenPlayers, ROOM_DIFFICULTY)
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
if IS_TOUCH then
	-- ขยายหน้าต่างตั้งห้อง/สถานะห้องให้นิ้วกดโดน (ปุ่ม 30 px เล็กเกินไปบนจอมือถือ)
	-- จอเตี้ยมาก (มือถือแนวนอน ~360 px) ไม่ขยายเกินจนล้นจอ
	local cam = workspace.CurrentCamera
	local h = if cam then cam.ViewportSize.Y else 400
	local scale = math.clamp(h / 340, 1, 1.12)
	new("UIScale", { Scale = scale }, setup)
	new("UIScale", { Scale = scale }, status)
	-- มุมขวาบนบนมือถือมีปุ่มสมุดผีอยู่แล้ว: เลื่อนสถานะห้องลงมาอีกนิด
	status.Position = UDim2.new(1, -14, 0, 64)
end
local statusHead = header(status)
statusHead.TextSize = 19
local function infoRow(order: number): (TextLabel, TextLabel)
	local r, l = row(status, order, if IS_TOUCH then 32 else 28)
	l.TextSize = if IS_TOUCH then 19 else 16
	l.TextColor3 = C.Dim
	local v = valueLabel(r)
	v.TextColor3 = C.Cream
	v.TextSize = if IS_TOUCH then 20 else 17
	return l, v
end
local playersL, playersV = infoRow(1)
local timeL, timeV = infoRow(3)
local leaveHint = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = if IS_TOUCH then 16 else 15,
	TextWrapped = true,
	LayoutOrder = 4,
}, status)
local ACT_H = if IS_TOUCH then 46 else 36
local actionRow = new("Frame", { Size = UDim2.new(1, 0, 0, ACT_H + 8), BackgroundTransparency = 1, LayoutOrder = 5 }, status)
new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, actionRow)
local startBtn = button(actionRow, { Size = UDim2.new(0.49, 0, 0, ACT_H), Position = UDim2.new(0, 0, 0.5, -ACT_H / 2), BackgroundColor3 = C.Blood, TextSize = if IS_TOUCH then 21 else 18 })
local leaveBtn = button(actionRow, { Size = UDim2.new(0.49, 0, 0, ACT_H), Position = UDim2.new(0.51, 0, 0.5, -ACT_H / 2), BackgroundColor3 = C.Bar, TextSize = if IS_TOUCH then 21 else 18 })
new("UICorner", { CornerRadius = UDim.new(0, 3) }, startBtn)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, leaveBtn)
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
	status.Visible = true
	statusHead.Text = tr("ห้องของ ", "Room of ") .. s.hostName
	playersL.Text = tr("ผู้เล่น", "Players")
	playersV.Text = ("%d / %d"):format(s.count, s.maxPlayers)
	if s.launching then
		timeL.Text = tr("สถานะ", "Status")
		timeV.Text = tr("กำลังไปที่ปั๊ม...", "Heading to the pump...")
	elseif s.fullCountdown then
		timeL.Text = tr("เต็มแล้ว · ไปเกมใน", "Full · teleporting in")
		timeV.Text = tr(("%d"):format(s.fullCountdown), ("%d"):format(s.fullCountdown))
		timeV.TextColor3 = C.BloodLit
	else
		timeL.Text = tr("เริ่มเกมอัตโนมัติใน", "Auto-start in")
		timeV.Text = tr(("%d วิ"):format(s.countdown), ("%ds"):format(s.countdown))
		timeV.TextColor3 = if s.countdown <= 10 then C.BloodLit else C.Cream
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
		startBtn.Size = UDim2.new(0.49, 0, 0, ACT_H)
		leaveBtn.Size = UDim2.new(0.49, 0, 0, ACT_H)
		leaveBtn.Position = UDim2.new(0.51, 0, 0.5, -ACT_H / 2)
	else
		leaveBtn.Size = UDim2.new(1, 0, 0, ACT_H)
		leaveBtn.Position = UDim2.new(0, 0, 0.5, -ACT_H / 2)
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
			setupTimer.TextColor3 = if left <= 10 then C.BloodLit else C.Dim
		end
	end
end)

-- ---------------------------------------------------------------- ข้อความแจ้งเตือนสั้นๆ (กลางจอบน ไม่บังพื้นที่พื้น/วงห้อง)
local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.new(0, 560, 0, 30),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = if IS_TOUCH then 22 else 20,
	TextWrapped = true,
	Text = "",
}, gui)
if IS_TOUCH then
	-- จอมือถือแคบ: กว้างตามจอ ไม่ล้น
	-- ต่ำลงมาจากแถบบน (มุมขวาบนมีกล่องสถานะห้อง) กว้างไม่เกินกลางจอ
	toast.Size = UDim2.new(0.55, 0, 0, 52)
	toast.Position = UDim2.new(0.5, 0, 0.24, 0)
end
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
