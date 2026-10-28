-- DeathScreen.client.luau
-- แพ้ (ธูปดับหมด): ตัวละครล้มนอนตาย (Server ทำ), ควบคุมไม่ได้, กล้องค่อยๆ ลอยขึ้นมองร่างตัวเอง, จอแดง
-- แล้วถาม "เริ่มคืนใหม่ไหม?" [เริ่มใหม่] [กลับ Lobby (Teleport)]  ใครกดเริ่มใหม่ก่อนนับทั้งร้าน
-- เกิดใหม่ (Server LoadCharacter) แล้วจอนี้หายไปเอง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameState = remotes:WaitForChild("GameState") :: RemoteEvent
local DeathChoice = remotes:WaitForChild("DeathChoice") :: RemoteEvent

local function lang(): string
	return LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?)
end
local function ui(key: string): string
	return LanguageModule.GetUI(key, lang())
end

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(190, 170, 160),
	Blood = Color3.fromRGB(150, 18, 16),
	Line = Color3.fromRGB(120, 60, 50),
}
local FONT_BODY = Font.fromEnum(Enum.Font.SpecialElite)
local FONT_SCARY = Font.fromEnum(Enum.Font.Creepster)

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

-- ---------------------------------------------------------------- ควบคุมตัวละคร
local function controls()
	local ok, mod = pcall(function()
		return require(localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")) :: any
	end)
	return if ok and mod then mod:GetControls() else nil
end

-- ---------------------------------------------------------------- UI
local gui = new("ScreenGui", {
	Name = "DeathScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 20,
	Enabled = false,
}, localPlayer:WaitForChild("PlayerGui"))

local red = new("Frame", { Name = "Red", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(110, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
-- ขอบจอดำ
local edge = new("Frame", { Name = "Edge", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0 }, gui)
new("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.78, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	}),
}, edge)

local box = new("Frame", {
	Name = "Box",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.7, 0, 0, 230),
	BackgroundTransparency = 1,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(820, 260) }, box)
local title = new("TextLabel", {
	Name = "Title",
	Size = UDim2.new(1, 0, 0, 70),
	BackgroundTransparency = 1,
	FontFace = FONT_SCARY,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(235, 40, 30),
	TextTransparency = 1,
}, box)
new("UITextSizeConstraint", { MaxTextSize = 64 }, title)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.2 }, title)
local message = new("TextLabel", {
	Name = "Message",
	Position = UDim2.new(0, 0, 0, 78),
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextScaled = true,
	TextColor3 = C.Cream,
	TextTransparency = 1,
}, box)
new("UITextSizeConstraint", { MaxTextSize = 26 }, message)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, message)
local ask = new("TextLabel", {
	Name = "Ask",
	Position = UDim2.new(0, 0, 0, 130),
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextScaled = true,
	TextColor3 = C.Dim,
	TextTransparency = 1,
}, box)
new("UITextSizeConstraint", { MaxTextSize = 22 }, ask)

local buttons = new("Frame", { Name = "Buttons", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 172), Size = UDim2.new(0, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Visible = false }, box)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, buttons)
local function button(order: number): TextButton
	local b = new("TextButton", {
		Size = UDim2.new(0, 160, 0, 40),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 20,
		AutoButtonColor = false,
		LayoutOrder = order,
	}, buttons)
	new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = C.Blood
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = C.Ink
	end)
	return b
end
local restartBtn = button(1)
restartBtn.Modal = true -- ปลดล็อกเมาส์
local quitBtn = button(2)

local function drawTexts()
	title.Text = if lang() == "th" then "คืนนี้... คุณไม่รอด" else "YOU DID NOT SURVIVE"
	message.Text = ui("Lose")
	ask.Text = ui("AskRestart")
	restartBtn.Text = ui("Restart")
	quitBtn.Text = ui("Quit")
end
drawTexts()
localPlayer:GetAttributeChangedSignal("Lang"):Connect(drawTexts)

-- ---------------------------------------------------------------- เปิด / ปิดจอตาย
local dead = false
local pulseToken = 0

local function showDeath()
	if dead then
		return
	end
	dead = true
	-- ถ้าผีกำลังหลอกเต็มจออยู่ (ธูปดอกสุดท้าย) ให้หลอกจบก่อนค่อยขึ้นจอตาย
	local scare = localPlayer.PlayerGui:FindFirstChild("Jumpscare") :: ScreenGui?
	local t0 = os.clock()
	while scare and scare.Enabled and os.clock() - t0 < 4 do
		task.wait(0.05)
	end
	drawTexts()
	local ctl = controls()
	if ctl then
		ctl:Disable()
	end
	gui.Enabled = true
	buttons.Visible = false
	restartBtn.Active = true
	quitBtn.Active = true
	red.BackgroundTransparency = 1
	edge.BackgroundTransparency = 1
	for _, t in ipairs({ title, message, ask }) do
		t.TextTransparency = 1
	end
	TweenService:Create(red, TweenInfo.new(1.2), { BackgroundTransparency = 0.6 }):Play()
	TweenService:Create(edge, TweenInfo.new(1.5), { BackgroundTransparency = 0 }):Play()
	-- กล้องค่อยๆ ลอยขึ้นมองร่างที่นอนอยู่
	local cam = Workspace.CurrentCamera
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if cam and root then
		task.delay(0.9, function()
			if not dead then
				return
			end
			cam.CameraType = Enum.CameraType.Scriptable
			local p = root.Position
			-- ลอยขึ้นเหนือร่าง แต่ไม่ทะลุหลังคา/ชายคา (ยิงหาเพดานก่อน)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char :: Instance }
			local hit = Workspace:Raycast(p, Vector3.new(0, 10, 0), params)
			-- ไม่ลอยสูง (หลังคาสังกะสีบางชิ้นยิงไม่โดน ถ้าลอยสูงกล้องจะจมในหลังคาจนจอขาว)
			local up = if hit then math.clamp((hit.Position.Y - p.Y) - 0.8, 2.5, 4.5) else 4.5
			TweenService:Create(cam, TweenInfo.new(3.5, Enum.EasingStyle.Sine), { CFrame = CFrame.lookAt(p + Vector3.new(1.2, up, 2.4), p) }):Play()
		end)
	end
	task.delay(1.2, function()
		TweenService:Create(title, TweenInfo.new(1.4), { TextTransparency = 0 }):Play()
		TweenService:Create(message, TweenInfo.new(1.8), { TextTransparency = 0 }):Play()
	end)
	task.delay(3, function()
		if dead then
			TweenService:Create(ask, TweenInfo.new(1), { TextTransparency = 0 }):Play()
			buttons.Visible = true
		end
	end)
	-- จอแดงเต้นช้าๆ เหมือนชีพจร
	pulseToken += 1
	local my = pulseToken
	task.spawn(function()
		task.wait(1.4)
		while dead and pulseToken == my do
			TweenService:Create(red, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.7 }):Play()
			task.wait(0.95)
			TweenService:Create(red, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 0.55 }):Play()
			task.wait(0.95)
		end
	end)
end

local function hideDeath()
	if not dead then
		return
	end
	dead = false
	pulseToken += 1
	gui.Enabled = false
	local ctl = controls()
	if ctl then
		ctl:Enable()
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end

restartBtn.Activated:Connect(function()
	if dead and restartBtn.Active then
		DeathChoice:FireServer("restart")
	end
end)
quitBtn.Activated:Connect(function()
	if dead and quitBtn.Active then
		quitBtn.Active = false
		quitBtn.Text = ui("GoingToLobby") -- Server Teleport กลับ Lobby
		if _G.ShowTeleportScreen then
			_G.ShowTeleportScreen({ destination = "lobby" })
		end
		DeathChoice:FireServer("quit")
	end
end)

DeathChoice.OnClientEvent:Connect(function(kind: string, who: string?)
	if kind == "restart" and dead then
		buttons.Visible = false
		restartBtn.Active = false
		ask.Text = string.gsub(ui("RestartBy"), "{name}", who or "?")
	end
end)

GameState.OnClientEvent:Connect(function(state: string)
	if state == "Lose" then
		showDeath()
	elseif state == "Waiting" or state == "Playing" then
		hideDeath()
	end
end)

-- เกิดใหม่ = กลับมาเล่นต่อ
localPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	hideDeath()
end)
