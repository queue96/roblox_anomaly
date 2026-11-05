-- DeathScreen.client.luau
-- แพ้ (ธูปดับหมด): ตัวละครล้มนอนตาย (Server ทำ), ควบคุมไม่ได้, ตาริบหรี่แล้วปิดสนิท แล้วลืมตาออกพร้อมกล้อง
-- แพนถอยขึ้นมองร่างตัวเอง, จอแดง
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
-- ไม่มี PlayerModule ใน PlayerScripts ก็ไม่เป็นไร (เกมนี้ไม่มี): ตอนแพ้ Server ยึดตัว + WalkSpeed 0 ให้อยู่แล้ว
-- (เดิม WaitForChild ไม่มีกำหนด = ค้างตลอด จอตายไม่ขึ้นเลย)
local function controls()
	local ok, mod = pcall(function()
		local ps = localPlayer:WaitForChild("PlayerScripts", 2)
		local pm = ps and ps:WaitForChild("PlayerModule", 1)
		return if pm then require(pm) :: any else nil
	end)
	return if ok and mod then mod:GetControls() else nil
end

-- ---------------------------------------------------------------- UI
local gui = new("ScreenGui", {
	Name = "DeathScreen",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None, -- เต็มจอจริงถึงขอบ (มือถือมีติ่ง/ขอบโค้ง: ค่าเริ่มต้นถูกบีบไว้ใน safe area เหลือแถบเกินขอบ)
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

-- ---------------------------------------------------------------- เพลงจอตาย
-- เล่นวนตอนจอถามว่าจะเริ่มใหม่หรือกลับ Lobby จนจอนี้ปิด (เจ้าของเกมอัปโหลด) กลุ่ม Music ปรับได้ในหน้าตั้งค่า
local DEATH_MUSIC_ID = "rbxassetid://111438100874990"
local DEATH_MUSIC_VOLUME = 0.5
local SoundService = game:GetService("SoundService")
local deathMusic = Instance.new("Sound")
deathMusic.Name = "DeathMusic"
deathMusic.SoundId = DEATH_MUSIC_ID
deathMusic.Volume = DEATH_MUSIC_VOLUME
deathMusic.Looped = true
deathMusic:SetAttribute("SoundCategory", "Music")
deathMusic.Parent = SoundService

-- ---------------------------------------------------------------- ศพให้เห็นบนจอตัวเอง
-- เกมนี้มุมมองบุคคลที่หนึ่ง: Roblox ซ่อนตัวเราเองบนจอเรา (LocalTransparencyModifier = 1) แม้กล้องถอยออกไปแล้ว
-- -> ตอนจอตายบังคับให้เห็นตัวเองทุกเฟรม + ไฟสลัวเหนือร่าง (ไฟดับ/กลางคืนมืดจนมองไม่เห็นศพ)
local RunService = game:GetService("RunService")
local corpseConn: boolean? = nil
local corpseLight: Instance? = nil
local function showCorpse(char: Model, root: BasePart)
	-- (หลังสคริปต์กล้อง/บุคคลที่หนึ่งทุกตัว ไม่ให้ถูกตั้งกลับเป็นซ่อน)
	RunService:UnbindFromRenderStep("DeathCorpseVisible")
	RunService:BindToRenderStep("DeathCorpseVisible", Enum.RenderPriority.Last.Value + 10, function()
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				d.LocalTransparencyModifier = 0
			end
		end
	end)
	corpseConn = true
	if corpseLight then
		corpseLight:Destroy()
	end
	local a = Instance.new("Attachment")
	a.Name = "CorpseLight"
	a.WorldPosition = root.Position + Vector3.new(0.6, 3.5, 1.2)
	a.Parent = Workspace.Terrain
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 190, 170)
	l.Brightness = 0
	l.Range = 9
	l.Shadows = true
	l.Parent = a
	TweenService:Create(l, TweenInfo.new(2.5), { Brightness = 1.6 }):Play()
	corpseLight = a
end
local function hideCorpse()
	if corpseConn then
		RunService:UnbindFromRenderStep("DeathCorpseVisible")
		corpseConn = nil
	end
	if corpseLight then
		corpseLight:Destroy()
		corpseLight = nil
	end
end

-- ---------------------------------------------------------------- ซ่อน HUD ที่ใช้ไม่ได้แล้วตอนตาย
-- เหลือแค่จอตาย + ปุ่มตั้งค่า (SettingsGui) ไม่ให้ข้อความ/ปุ่มเกมทับศพ (ผู้ใช้ขอ 2026-11-03)
-- ไม่แตะค่าตั้งค่า ShowHUD ของผู้เล่น: ปิด ScreenGui ชั่วคราวแล้วคืนค่าเดิมตอนชุบ/เกิดใหม่
local HIDE_ON_DEATH = { "PumpHUD", "ItemSlots", "Tutorial", "PrayerHUD", "BookGui", "GeneratorMinigame", "GeneratorShock" }
local NO_RESTORE = { GeneratorMinigame = true, GeneratorShock = true } -- หน้าจอชั่วคราว: ตายแล้วปิดทิ้ง ไม่เปิดคืน
local ProximityPromptService = game:GetService("ProximityPromptService")
local hiddenGuis: { [ScreenGui]: boolean } = {}
local hudHidden = false
local settingsOrder: number? = nil
local function hideHud()
	hudHidden = true
	-- ปุ่มตั้งค่าอยู่เหนือจอแดง/ขอบดำของจอตาย (ยังกดได้ ไม่หม่น)
	local sg = localPlayer.PlayerGui:FindFirstChild("SettingsGui")
	if sg and sg:IsA("ScreenGui") then
		settingsOrder = settingsOrder or sg.DisplayOrder
		sg.DisplayOrder = gui.DisplayOrder + 5
	end
	ProximityPromptService.Enabled = false
	task.spawn(function()
		-- ปิดซ้ำเรื่อยๆ ระหว่างตาย (สคริปต์ HUD บางตัวเปิดตัวเองกลับตอนสถานะเปลี่ยน)
		while hudHidden do
			for _, name in ipairs(HIDE_ON_DEATH) do
				local g = localPlayer.PlayerGui:FindFirstChild(name)
				if g and g:IsA("ScreenGui") and g.Enabled then
					if hiddenGuis[g] == nil then
						hiddenGuis[g] = true
					end
					g.Enabled = false
				end
			end
			ProximityPromptService.Enabled = false
			task.wait(0.2)
		end
	end)
end
local function showHud()
	if not hudHidden then
		return
	end
	hudHidden = false
	local sg = localPlayer.PlayerGui:FindFirstChild("SettingsGui")
	if sg and sg:IsA("ScreenGui") and settingsOrder then
		sg.DisplayOrder = settingsOrder
	end
	settingsOrder = nil
	for g in pairs(hiddenGuis) do
		if g.Parent and not NO_RESTORE[g.Name] then
			g.Enabled = true
		end
	end
	table.clear(hiddenGuis)
	ProximityPromptService.Enabled = true
end

-- ---------------------------------------------------------------- เปิด / ปิดจอตาย
local dead = false
local pulseToken = 0

local function showDeath()
	if dead then
		return
	end
	dead = true
	hideHud()
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
	-- ตาริบหรี่ (ลืม-ปิดไม่สุด 2-3 ครั้ง) แล้วปิดสนิท -> ตอนมืดย้ายกล้องไปชิดร่าง -> ลืมตาออกพร้อมแพนกล้องถอยขึ้น
	-- ให้เห็นว่าตัวเองนอนตายอยู่ (หนังตามาจาก client/HauntEffects)
	local lids = _G.HauntLids
	if lids then
		for _, step in ipairs({ { 0.5, 0.5 }, { 0.3, 0.35 }, { 0.7, 0.6 }, { 0.45, 0.35 }, { 0.85, 0.7 }, { 0.7, 0.4 }, { 1, 0.9 } }) do
			lids(step[1], step[2])
			task.wait(step[2] + 0.12)
			if not dead then
				return
			end
		end
		task.wait(0.8)
	end
	gui.Enabled = true
	deathMusic.Volume = DEATH_MUSIC_VOLUME
	deathMusic.TimePosition = 0
	deathMusic:Play()
	buttons.Visible = false
	restartBtn.Active = true
	quitBtn.Active = true
	red.BackgroundTransparency = 1
	edge.BackgroundTransparency = 1
	for _, t in ipairs({ title, message, ask }) do
		t.TextTransparency = 1
	end
	-- กล้อง: เริ่มชิดร่าง (ตอนตายังปิด) แล้วค่อยๆ แพนถอยขึ้นมองร่างที่นอนอยู่
	local cam = Workspace.CurrentCamera
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if char and root then
		showCorpse(char, root)
	end
	if cam and root then
		cam.CameraType = Enum.CameraType.Scriptable
		local p = root.Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char :: Instance }
		-- ไม่ลอยสูง (หลังคาสังกะสีบางชิ้นยิงไม่โดน ถ้าลอยสูงกล้องจะจมในหลังคาจนจอขาว)
		local hit = Workspace:Raycast(p, Vector3.new(0, 10, 0), params)
		local up = if hit then math.clamp((hit.Position.Y - p.Y) - 0.8, 2.5, 4.5) else 4.5
		cam.CFrame = CFrame.lookAt(p + Vector3.new(0.3, 1.2, 0.6), p)
		TweenService:Create(cam, TweenInfo.new(4.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(p + Vector3.new(1.2, up, 2.4), p) }):Play()
	end
	if lids then
		lids(0, 2.2)
	end
	TweenService:Create(red, TweenInfo.new(1.2), { BackgroundTransparency = 0.6 }):Play()
	TweenService:Create(edge, TweenInfo.new(1.5), { BackgroundTransparency = 0 }):Play()
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
	hideCorpse()
	showHud()
	pulseToken += 1
	gui.Enabled = false
	if _G.HauntLids then -- (ชุบชีวิตระหว่างตากำลังปิด: ลืมตา)
		_G.HauntLids(0, 0.3)
	end
	local fade = TweenService:Create(deathMusic, TweenInfo.new(0.8), { Volume = 0 })
	fade.Completed:Once(function()
		if not dead then
			deathMusic:Stop()
		end
	end)
	fade:Play()
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
	if kind == "revive" then
		hideDeath() -- admin ชุบชีวิต: ลุกขึ้นตรงที่ล้ม เล่นต่อ
	elseif kind == "restart" and dead then
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
