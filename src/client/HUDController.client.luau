-- HUDController.client.luau
-- สคริปต์ควบคุมหน้าจอฝั่งผู้เล่น (Client)
-- แสดงเงินในกระป๋อง ฿x / ฿500, ธูป 3 ดอก, คำพูดลูกค้า (กล่องล่างจอ), ผีหลอกเมื่อเติมน้ำมันให้ผี, ชนะ/แพ้
-- สไตล์: ชนบทหลอนๆ แถบดำโปร่ง หัวข้อแถบเทาหม่น ตัวหนังสือสีครีม ปุ่มคีย์เป็นป้ายกระดาษ ตัวแดงสั่นๆ ขอบจอมืด
-- ภาษา: ไทย/อังกฤษ ตาม player:GetAttribute("Lang") (Server ตั้งให้ตอนเข้าเกม + จำไว้) เปลี่ยนได้ในหน้าตั้งค่า (SettingsController)
--   ข้อความพวกนี้แปลเองด้วย LanguageModule จึงปิด AutoLocalize ไม่ให้ระบบแปลอัตโนมัติของ Roblox แปลซ้ำ
-- รับข้อมูลจาก ReplicatedStorage.Remotes (สร้างโดย CoreLoop ฝั่ง Server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
-- บังคับมุมมองบุคคลที่ 1 เสมอ และล็อกห้ามกระโดดฝั่ง Client
localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
localPlayer:GetPropertyChangedSignal("CameraMode"):Connect(function()
	if localPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		localPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end)
local function lockJumpOnCharacter(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end
if localPlayer.Character then
	task.spawn(lockJumpOnCharacter, localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(lockJumpOnCharacter)
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local function lang(): string
	return LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?)
end
local function ui(key: string): string
	return LanguageModule.GetUI(key, lang())
end

print("✅ [Client] ยินดีต้อนรับสู่ปั๊มหลอดท้ายทุ่ง:", localPlayer.Name, "| ภาษา:", lang())

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHUD = remotes:WaitForChild("UpdateHUD") :: RemoteEvent
local TriggerJumpscare = remotes:WaitForChild("TriggerJumpscare") :: RemoteEvent
local CustomerSpeech = remotes:WaitForChild("CustomerSpeech") :: RemoteEvent
local GameState = remotes:WaitForChild("GameState") :: RemoteEvent
local DialogueReply = remotes:WaitForChild("DialogueReply") :: RemoteEvent
local DeathChoice = remotes:WaitForChild("DeathChoice") :: RemoteEvent -- ("quit") = กลับ Lobby
local ServiceMinigame = remotes:WaitForChild("ServiceMinigame") :: RemoteEvent -- ("open", choice) / ("close")

-- ---------------------------------------------------------------- สีและฟอนต์
local C = {
	Ink = Color3.fromRGB(8, 7, 6), -- ดำอมน้ำตาล
	Bar = Color3.fromRGB(58, 54, 46), -- แถบหัวข้อเทาหม่น
	Cream = Color3.fromRGB(236, 228, 208), -- ตัวหนังสือครีม
	Dim = Color3.fromRGB(165, 156, 136),
	Blood = Color3.fromRGB(150, 18, 16),
	BloodLit = Color3.fromRGB(205, 36, 28),
	Ember = Color3.fromRGB(230, 120, 50),
	Paper = Color3.fromRGB(226, 218, 196), -- ป้ายกระดาษปุ่มคีย์
}
local FONT_BODY = Font.fromEnum(Enum.Font.SpecialElite) -- พิมพ์ดีดเก่า (ไทยจะใช้ฟอนต์สำรองของ Roblox)
local FONT_SCARY = Font.fromEnum(Enum.Font.Creepster) -- หัวข้อแดงๆ น่ากลัว

-- ---------------------------------------------------------------- helpers
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

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	new("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 28, MinTextSize = 8 }, t)
	props.MaxTextSize = nil
	for k, v in pairs(props) do
		(t :: any)[k] = v
	end
	return t
end

-- แถบดำโปร่ง ขอบซ้ายขวาค่อยๆ จางหาย (เหมือนแถบหัวข้อในเกมผีไทย)
local function fadeEdges(frame: GuiObject, edge: number)
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(edge, 0),
			NumberSequenceKeypoint.new(1 - edge, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, frame)
end

-- ป้ายปุ่มคีย์แบบดาร์กคุมโทน [G] + คำอธิบายขนาดกะทัดรัด
local function keyHint(parent: Instance, key: string, order: number): (TextLabel, TextLabel)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local badge = new("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(22, 20, 17),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 12,
		Text = key,
		LayoutOrder = 1,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, badge)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, badge)
	new("UIStroke", { Color = Color3.fromRGB(75, 68, 56), Thickness = 1, Transparency = 0.2 }, badge)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 13,
		LayoutOrder = 0, -- คำอธิบายอยู่ซ้าย ป้ายคีย์อยู่ขวา (ชิดขอบจอขวา)
	}, holder)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }, label)
	return badge, label
end

-- ---------------------------------------------------------------- ตัวหนังสือสั่นๆ (หวั่นไหว)
-- จดตำแหน่งเดิมไว้ แล้วสุ่มขยับทีละนิด + กะพริบจางๆ เป็นพักๆ
local trembling: { { obj: GuiObject, base: UDim2, px: number, flicker: boolean } } = {}
local function tremble(obj: GuiObject, px: number, flicker: boolean)
	table.insert(trembling, { obj = obj, base = obj.Position, px = px, flicker = flicker })
end
local nextJitter = 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now < nextJitter then
		return
	end
	nextJitter = now + 0.06 + math.random() * 0.08
	for _, t in ipairs(trembling) do
		if t.obj.Visible then
			local still = math.random() < 0.55
			local dx = if still then 0 else math.random(-t.px, t.px)
			local dy = if still then 0 else math.random(-t.px, t.px)
			t.obj.Position = t.base + UDim2.fromOffset(dx, dy)
			if t.flicker and t.obj:IsA("TextLabel") then
				t.obj.TextTransparency = if math.random() < 0.06 then 0.6 else 0
			end
		end
	end
end)

-- ---------------------------------------------------------------- ScreenGui
local gui = new("ScreenGui", {
	Name = "PumpHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, localPlayer:WaitForChild("PlayerGui"))

-- ขอบจอมืด (Vignette) จาก 4 ด้าน
for _, side in ipairs({ { "Top", 90, UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0) }, { "Bottom", 270, UDim2.new(1, 0, 0.3, 0), UDim2.fromScale(0, 0.7) }, { "Left", 0, UDim2.new(0.18, 0, 1, 0), UDim2.fromScale(0, 0) }, { "Right", 180, UDim2.new(0.18, 0, 1, 0), UDim2.fromScale(0.82, 0) } }) do
	local f = new("Frame", { Name = "Vignette" .. side[1], BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Size = side[3], Position = side[4], ZIndex = 0 }, gui)
	new("UIGradient", { Rotation = side[2], Transparency = NumberSequence.new(0.45, 1) }, f)
end

-- ---------------------------------------------------------------- แผงเงิน (มุมขวาล่าง ขนาดกะทัดรัด ตัดธูปออกให้ผู้เล่นเดินไปดูที่ศาลพระภูมิเอง)
local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.new(0, 174, 0, 32),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
}, gui)
new("UIStroke", { Color = Color3.fromRGB(70, 64, 54), Thickness = 1, Transparency = 0.25 }, panel)
local function shadow(t: TextLabel)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }, t)
end
local moneyTitle = text(panel, { Name = "MoneyTitle", Position = UDim2.new(0, 10, 0, 7), Size = UDim2.new(0.46, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Dim, MaxTextSize = 12 })
local moneyText = text(panel, { Name = "Money", Position = UDim2.new(0.42, 0, 0, 5), Size = UDim2.new(0.58, -10, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, FontFace = FONT_BODY, TextColor3 = C.Cream, Text = "฿0 / ฿1500", MaxTextSize = 15 })
shadow(moneyTitle)
shadow(moneyText)

-- ---------------------------------------------------------------- แถบประกาศกลางจอ (คืนใหม่ / ชนะ / แพ้ / ผีหลอก)
local bannerBar = new("Frame", {
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2),
	Size = UDim2.new(0.62, 0, 0, 64),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 11, -- อยู่เหนือจอแดงวาบ (ScareFlash ZIndex 10)
}, gui)
fadeEdges(bannerBar, 0.15)
local banner = text(bannerBar, { Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, MaxTextSize = 32 })
tremble(banner, 2, true)

-- ปุ่ม "กลับ Lobby" ใต้แถบประกาศ (ขึ้นตอนชนะ จนกว่าคืนใหม่จะเริ่ม)
local lobbyBtn = new("TextButton", {
	Name = "BackToLobby",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.2, 44),
	Size = UDim2.new(0, 200, 0, 40),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 20,
	AutoLocalize = false,
	AutoButtonColor = false,
	Modal = true, -- ปลดล็อกเมาส์
	Visible = false,
	ZIndex = 12,
}, gui)
new("UIStroke", { Color = C.Ember, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, lobbyBtn)
lobbyBtn.MouseEnter:Connect(function()
	lobbyBtn.BackgroundColor3 = C.Bar
end)
lobbyBtn.MouseLeave:Connect(function()
	lobbyBtn.BackgroundColor3 = C.Ink
end)
lobbyBtn.Activated:Connect(function()
	lobbyBtn.Active = false
	lobbyBtn.Text = ui("GoingToLobby")
	if _G.ShowTeleportScreen then
		_G.ShowTeleportScreen({ destination = "lobby" })
	end
	DeathChoice:FireServer("quit")
end)

-- จอแดงวาบตอนผีหลอก
local flash = new("Frame", { Name = "ScareFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10 }, gui)

local bannerKey: string? = nil
local bannerToken = 0
local function showBanner(key: string, scary: boolean, seconds: number)
	bannerKey = key
	bannerToken += 1
	local token = bannerToken
	banner.Text = ui(key)
	banner.FontFace = if scary then FONT_SCARY else FONT_BODY
	banner.TextColor3 = if scary then C.BloodLit else C.Cream
	bannerBar.Visible = true
	bannerBar.BackgroundTransparency = 1
	banner.TextTransparency = 1
	TweenService:Create(bannerBar, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()
	TweenService:Create(banner, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
	task.delay(seconds, function()
		if bannerToken ~= token then
			return
		end
		TweenService:Create(bannerBar, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(banner, TweenInfo.new(0.8), { TextTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		if bannerToken == token then
			bannerBar.Visible = false
			bannerKey = nil
		end
	end)
end

-- ---------------------------------------------------------------- ซับไตเติลคำพูดลูกค้า (แถบบางโปร่งแสงล่างจอ ไม่บังสายตา)
local DIALOG_BG_TRANSPARENCY = 0.38
local dialog = new("Frame", {
	Name = "Dialogue",
	ZIndex = 5,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -50), -- เหนือช่องไฟฉายกะทัดรัด ไม่บังกลางจอ
	Size = UDim2.new(0.52, 0, 0, 48),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = DIALOG_BG_TRANSPARENCY,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UISizeConstraint", { MinSize = Vector2.new(260, 0), MaxSize = Vector2.new(520, 52) }, dialog)
fadeEdges(dialog, 0.18)
local dialogHeader = new("Frame", { Name = "Header", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 3) }, dialog)
local speaker = text(dialogHeader, { Name = "Speaker", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Dim, MaxTextSize = 13 })
shadow(speaker)
local line = text(dialog, {
	Name = "Line",
	Position = UDim2.new(0, 16, 0, 19),
	Size = UDim2.new(1, -32, 1, -22),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextYAlignment = Enum.TextYAlignment.Center,
	TextWrapped = true,
	MaxTextSize = 15,
})
shadow(line)

local bubbleKey: string? = nil
local bubbleVars: { [string]: any }? = nil
local bubbleSpeaker: { [string]: string }? = nil
local typeToken = 0

-- หัวกล่อง: ชื่อลูกค้า (แปลตามภาษา) หรือชื่อผู้เล่นที่ตอบ (สีส้มถ่าน)
local function drawSpeaker()
	local sp = bubbleSpeaker
	if sp and type(sp.ghost) == "string" then
		-- เสียงกระซิบไม่รู้ที่มา (ถ้าเป็นคีย์ใน LanguageModule.UI ให้แปลตามภาษา)
		speaker.Text = if LanguageModule.UI[sp.ghost] then ui(sp.ghost) else sp.ghost
		speaker.TextColor3 = C.BloodLit
	elseif sp and sp.player then
		speaker.Text = sp.player
		speaker.TextColor3 = C.Ember
	elseif sp and sp.name then
		speaker.Text = LanguageModule.GetName(sp.name, lang())
		speaker.TextColor3 = C.Cream
	else
		speaker.Text = ui("Customer")
		speaker.TextColor3 = C.Cream
	end
end
-- พิมพ์ทีละตัวเหมือนเสียงกระซิบ (ใช้ MaxVisibleGraphemes รองรับสระ/วรรณยุกต์ไทย)
local function typeLine(s: string)
	typeToken += 1
	local token = typeToken
	line.Text = s
	line.MaxVisibleGraphemes = 0
	task.spawn(function()
		local n = utf8.len(s) or #s
		for i = 1, n do
			if typeToken ~= token then
				return
			end
			line.MaxVisibleGraphemes = i
			task.wait(0.025)
		end
		line.MaxVisibleGraphemes = -1
	end)
end

-- ---------------------------------------------------------------- ตอบราคา (ทุกคนเห็นเหมือนกัน ใครตอบก่อนได้ก่อน) เหนือกล่องคำพูด
local replyBar = new("Frame", {
	Name = "ReplyBar",
	ZIndex = 5,
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -216),
	Size = UDim2.new(0, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.XY,
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, replyBar)
local replyTitle = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 360, 0, 20), FontFace = FONT_BODY, TextColor3 = C.Dim, TextSize = 16, LayoutOrder = 0 }, replyBar)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4 }, replyTitle)
local replyRow = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 }, replyBar)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, replyRow)
local timerBar = new("Frame", { BackgroundColor3 = C.Blood, BorderSizePixel = 0, Size = UDim2.new(0, 360, 0, 2), LayoutOrder = 2 }, replyBar)

local replyButtons: { { button: TextButton, id: string, key: string } } = {}
local replyTween: Tween? = nil
local function closeReplies()
	replyBar.Visible = false
	if replyTween then
		replyTween:Cancel()
	end
	for _, r in ipairs(replyButtons) do
		r.button:Destroy()
	end
	table.clear(replyButtons)
end
local function sendReply(id: string)
	if replyBar.Visible then
		DialogueReply:FireServer(id)
	end
end
local function drawReplies()
	replyTitle.Text = ui("ReplyTitle")
	for i, r in ipairs(replyButtons) do
		r.button.Text = string.format("[%d]  %s", i, ui(r.key))
	end
end
DialogueReply.OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "open" then
		closeReplies()
		for i, opt in ipairs(a :: { { id: string, key: string } }) do
			local btn = new("TextButton", {
				Size = UDim2.new(0, 0, 0, 34),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = C.Ink,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				FontFace = FONT_BODY,
				TextColor3 = C.Cream,
				TextSize = 17,
				AutoButtonColor = false,
				LayoutOrder = i,
			}, replyRow)
			new("UIStroke", { Color = Color3.fromRGB(90, 80, 62), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
			new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, btn)
			btn.MouseEnter:Connect(function()
				btn.BackgroundColor3 = C.Blood
			end)
			btn.MouseLeave:Connect(function()
				btn.BackgroundColor3 = C.Ink
			end)
			btn.Activated:Connect(function()
				sendReply(opt.id)
			end)
			table.insert(replyButtons, { button = btn, id = opt.id, key = opt.key })
		end
		drawReplies()
		replyBar.Visible = true
		timerBar.Size = UDim2.new(0, 360, 0, 2)
		replyTween = TweenService:Create(timerBar, TweenInfo.new(tonumber(b) or 8, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })
		replyTween:Play()
	elseif kind == "close" then
		closeReplies()
	end
end)
-- กดเลข 1 / 2 / 3 ตอบได้เลย
local NUM_KEYS = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local i = NUM_KEYS[input.KeyCode]
	if i and replyButtons[i] then
		sendReply(replyButtons[i].id)
	end
end)

-- ---------------------------------------------------------------- ช่องไฟฉาย [1] คุมโทนดาร์ก (แทนที่ Hotbar มาตรฐานของ Roblox)
task.spawn(function()
	local StarterGui = game:GetService("StarterGui")
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then
			break
		end
		task.wait(0.3)
	end
end)

local flashlightSlot = new("TextButton", {
	Name = "FlashlightSlot",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(0, 0, 0, 26),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(14, 13, 11),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, flashlightSlot)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }, flashlightSlot)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, flashlightSlot)
local slotStroke = new("UIStroke", { Color = Color3.fromRGB(70, 64, 54), Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, flashlightSlot)
local slotKeyBadge = new("TextLabel", {
	BackgroundColor3 = Color3.fromRGB(26, 24, 20),
	Size = UDim2.new(0, 16, 0, 16),
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 11,
	Text = "1",
	LayoutOrder = 1,
}, flashlightSlot)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, slotKeyBadge)
local slotLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 0, 0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 13,
	Text = "ไฟฉาย",
	LayoutOrder = 2,
}, flashlightSlot)

local function findFlashlight(): (Tool?, boolean)
	local char = localPlayer.Character
	local equipped = char and char:FindFirstChild("FrogFlashlight")
	if equipped and equipped:IsA("Tool") then
		return equipped, true
	end
	local bp = localPlayer:FindFirstChildOfClass("Backpack")
	local inBag = bp and bp:FindFirstChild("FrogFlashlight")
	if inBag and inBag:IsA("Tool") then
		return inBag, false
	end
	return nil, false
end

-- ล็อกทั้งโมเดลกระบอกไฟฉายและลำแสงติดกับมุมกล้องโดยตรง (ความสว่างกำลังดีแบบเกมผี + ก้มมองพื้นใต้เท้าเห็นได้ชัดเจน)
local camLightPart = Instance.new("Part")
camLightPart.Name = "CameraFlashlightOrigin"
camLightPart.Size = Vector3.new(0.2, 0.2, 0.2)
camLightPart.Transparency = 1
camLightPart.Anchored = true
camLightPart.CanCollide = false
camLightPart.CanQuery = false
camLightPart.CanTouch = false
camLightPart.CastShadow = false

local camSpotLight = Instance.new("SpotLight")
camSpotLight.Name = "CameraBeamLight"
camSpotLight.Face = Enum.NormalId.Front
camSpotLight.Brightness = 2.4
camSpotLight.Range = 46
camSpotLight.Angle = 60
camSpotLight.Color = Color3.fromRGB(255, 244, 195)
camSpotLight.Shadows = false
camSpotLight.Enabled = false
camSpotLight.Parent = camLightPart
camLightPart.Parent = workspace

-- แสงอ่อนๆ ปลายลำแสงระยะใกล้เพื่อให้ตอนก้มมองเท้าตัวเองไม่มืดสนิทจากระยะ Voxel ของ Roblox
local camClosePart = Instance.new("Part")
camClosePart.Name = "CameraCloseLightOrigin"
camClosePart.Size = Vector3.new(0.2, 0.2, 0.2)
camClosePart.Transparency = 1
camClosePart.Anchored = true
camClosePart.CanCollide = false
camClosePart.CanQuery = false
camClosePart.CanTouch = false
camClosePart.CastShadow = false
local camCloseLight = Instance.new("PointLight")
camCloseLight.Name = "CameraCloseLight"
camCloseLight.Brightness = 0.65
camCloseLight.Range = 8
camCloseLight.Color = Color3.fromRGB(255, 244, 195)
camCloseLight.Shadows = false
camCloseLight.Enabled = false
camCloseLight.Parent = camClosePart
camClosePart.Parent = workspace

local camViewFolder = Instance.new("Model")
camViewFolder.Name = "CameraFlashlightViewmodel"
camViewFolder.Parent = workspace
local camViewParts: { { part: BasePart, relCF: CFrame } } = {}
local camViewSourceTool: Tool? = nil
local camViewVisibleState: boolean? = nil

local function hideHandToolInstance(d: Instance)
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = 1
		d.CastShadow = false
	elseif d:IsA("SpotLight") or d:IsA("PointLight") or d:IsA("SurfaceLight") then
		d.Enabled = false
	end
end

local function rebuildCameraFlashlightView(tool: Tool)
	if camViewSourceTool == tool and #camViewParts > 0 then
		return
	end
	camViewFolder:ClearAllChildren()
	table.clear(camViewParts)
	camViewSourceTool = tool
	camViewVisibleState = nil

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d ~= handle and d.Transparency < 0.99 then
			local clone = d:Clone()
			for _, child in ipairs(clone:GetChildren()) do
				if child:IsA("WeldConstraint") or child:IsA("JointInstance") or child:IsA("Light") or child:IsA("Sound") then
					child:Destroy()
				end
			end
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.LocalTransparencyModifier = 0
			clone.Parent = camViewFolder
			table.insert(camViewParts, {
				part = clone,
				relCF = handle.CFrame:ToObjectSpace(d.CFrame),
			})
		end
		-- ซ่อนโมเดลไฟฉายที่ติดมือตัวละครระดับเอวเพียงครั้งเดียวตอนสร้าง Viewmodel
		hideHandToolInstance(d)
	end
end

local function setCameraViewVisible(visible: boolean)
	if camViewVisibleState == visible then
		return
	end
	camViewVisibleState = visible
	for _, item in ipairs(camViewParts) do
		item.part.Transparency = if visible then 0 else 1
	end
end

local function updateCameraFlashlight(tool: Tool?, isEquipped: boolean)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	if isEquipped and tool then
		rebuildCameraFlashlightView(tool)
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		if handle and handle.LocalTransparencyModifier < 1 then
			for _, d in ipairs(tool:GetDescendants()) do
				hideHandToolInstance(d)
			end
		end
		local aimPoint = cam.CFrame.Position + cam.CFrame.LookVector * 45
		local handPos = (cam.CFrame * CFrame.new(0.58, -0.46, -1.05)).Position
		local handleCF = CFrame.lookAt(handPos, aimPoint)
		for _, item in ipairs(camViewParts) do
			item.part.CFrame = handleCF * item.relCF
		end
		setCameraViewVisible(true)

		-- ถอยจุดกำเนิด SpotLight ไปด้านหลังกล้อง 1.5 studs ตามแนวสายตา เพื่อให้ตอนก้มมองพื้นใต้เท้าระยะห่างพอให้ Voxel สว่าง
		camLightPart.CFrame = cam.CFrame * CFrame.new(0, 0, 1.5)
		camClosePart.CFrame = cam.CFrame * CFrame.new(0, 0, -2.2)
		if not camSpotLight.Enabled then
			camSpotLight.Enabled = true
			camCloseLight.Enabled = true
		end
	else
		setCameraViewVisible(false)
		if camSpotLight.Enabled then
			camSpotLight.Enabled = false
			camCloseLight.Enabled = false
		end
	end
end

local lastSlotHasTool: boolean? = nil
local lastSlotEquipped: boolean? = nil
local lastSlotShowHUD: boolean? = nil

local function updateFlashlightSlot()
	local tool, isEquipped = findFlashlight()
	local hasTool = tool ~= nil
	local showHUD = localPlayer:GetAttribute("ShowHUD") ~= false
	if hasTool ~= lastSlotHasTool or isEquipped ~= lastSlotEquipped or showHUD ~= lastSlotShowHUD then
		lastSlotHasTool = hasTool
		lastSlotEquipped = isEquipped
		lastSlotShowHUD = showHUD
		flashlightSlot.Visible = hasTool and showHUD
		slotStroke.Color = if isEquipped then Color3.fromRGB(185, 140, 88) else Color3.fromRGB(70, 64, 54)
		slotLabel.TextColor3 = if isEquipped then C.Cream else C.Dim
		slotKeyBadge.TextColor3 = if isEquipped then C.Cream else C.Dim
	end
	updateCameraFlashlight(tool, isEquipped)
end

local function toggleFlashlightEquip()
	if localPlayer:GetAttribute("Praying") == true then
		return
	end
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local tool, isEquipped = findFlashlight()
	if not tool then
		return
	end
	if isEquipped then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
	updateFlashlightSlot()
end
flashlightSlot.Activated:Connect(toggleFlashlightEquip)

-- ---------------------------------------------------------------- มินิเกมเติมน้ำมันหลอด / ดีเซล / เติมลมยาง
local mgFrame = new("Frame", {
	Name = "MinigameFrame",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.54),
	Size = UDim2.fromOffset(284, 188),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 9,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, mgFrame)
new("UIStroke", { Color = Color3.fromRGB(95, 82, 62), Thickness = 1, Transparency = 0.15 }, mgFrame)

local mgHeader = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 28),
	BackgroundColor3 = Color3.fromRGB(24, 21, 18),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	ZIndex = 9,
}, mgFrame)
local mgTitle = new("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -76, 1, 0),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	AutoLocalize = false,
	ZIndex = 10,
}, mgHeader)
local mgCloseBtn = new("TextButton", {
	Name = "CloseBtn",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(56, 20),
	BackgroundColor3 = Color3.fromRGB(36, 30, 26),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 11,
	Text = "[X] ปิด",
	AutoLocalize = false,
	AutoButtonColor = false,
	Modal = true,
	ZIndex = 10,
}, mgHeader)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, mgCloseBtn)
new("UIStroke", { Color = Color3.fromRGB(78, 68, 56), Thickness = 1, Transparency = 0.3 }, mgCloseBtn)

-- 1) โหมดสูบน้ำมันหลอด / ดีเซล (กดค้างให้ระดับน้ำมันขึ้นไปอยู่ในขีดสีทองแล้วปล่อย)
local mgFuelView = new("Frame", {
	Name = "FuelView",
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 1, -28),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 9,
}, mgFrame)
local mgTubeBg = new("Frame", {
	Name = "TubeBg",
	Position = UDim2.fromOffset(18, 12),
	Size = UDim2.fromOffset(44, 134),
	BackgroundColor3 = Color3.fromRGB(18, 16, 14),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 9,
}, mgFuelView)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, mgTubeBg)
new("UIStroke", { Color = Color3.fromRGB(90, 82, 68), Thickness = 1, Transparency = 0.2 }, mgTubeBg)
for _, pct in ipairs({ 0.25, 0.5, 0.75 }) do
	new("Frame", {
		Position = UDim2.new(0, 0, 1 - pct, 0),
		Size = UDim2.new(0.32, 0, 0, 1),
		BackgroundColor3 = Color3.fromRGB(110, 100, 85),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, mgTubeBg)
end
local mgFuelTargetZone = new("Frame", {
	Name = "TargetZone",
	Position = UDim2.fromScale(0, 0.16),
	Size = UDim2.fromScale(1, 0.18),
	BackgroundColor3 = Color3.fromRGB(215, 168, 64),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
	ZIndex = 10,
}, mgTubeBg)
new("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(245, 200, 95), BorderSizePixel = 0, ZIndex = 12 }, mgFuelTargetZone)
new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(245, 200, 95), BorderSizePixel = 0, ZIndex = 12 }, mgFuelTargetZone)
local mgFuelFill = new("Frame", {
	Name = "LiquidFill",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = Color3.fromRGB(218, 138, 38),
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	ZIndex = 10,
}, mgTubeBg)
local mgFuelHint = new("TextLabel", {
	Name = "Hint",
	Position = UDim2.fromOffset(76, 14),
	Size = UDim2.new(1, -88, 0, 76),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	AutoLocalize = false,
	ZIndex = 10,
}, mgFuelView)
local mgFuelBtn = new("TextButton", {
	Name = "PumpBtn",
	Position = UDim2.fromOffset(76, 104),
	Size = UDim2.new(1, -90, 0, 38),
	BackgroundColor3 = Color3.fromRGB(32, 28, 22),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 13,
	AutoLocalize = false,
	AutoButtonColor = false,
	ZIndex = 10,
}, mgFuelView)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, mgFuelBtn)
local mgFuelBtnStroke = new("UIStroke", { Color = Color3.fromRGB(165, 122, 68), Thickness = 1, Transparency = 0.2 }, mgFuelBtn)

-- 2) โหมดเติมลมยาง (กด Space / คลิก ตอนเข็มวิ่งเข้าโซนสีทอง ครบ 3 ครั้ง)
local mgAirView = new("Frame", {
	Name = "AirView",
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 1, -28),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 9,
}, mgFrame)
local mgAirPips = new("TextLabel", {
	Name = "Pips",
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -36, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = Color3.fromRGB(225, 175, 88),
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoLocalize = false,
	ZIndex = 10,
}, mgAirView)
local mgAirHint = new("TextLabel", {
	Name = "Hint",
	Position = UDim2.fromOffset(18, 34),
	Size = UDim2.new(1, -36, 0, 32),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	AutoLocalize = false,
	ZIndex = 10,
}, mgAirView)
local mgAirBarBg = new("Frame", {
	Name = "GaugeBg",
	Position = UDim2.fromOffset(18, 72),
	Size = UDim2.new(1, -36, 0, 26),
	BackgroundColor3 = Color3.fromRGB(18, 16, 14),
	BorderSizePixel = 0,
	ZIndex = 9,
}, mgAirView)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, mgAirBarBg)
new("UIStroke", { Color = Color3.fromRGB(90, 82, 68), Thickness = 1, Transparency = 0.2 }, mgAirBarBg)
local mgAirTargetZone = new("Frame", {
	Name = "TargetZone",
	Position = UDim2.fromScale(0.38, 0),
	Size = UDim2.fromScale(0.22, 1),
	BackgroundColor3 = Color3.fromRGB(215, 168, 64),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	ZIndex = 10,
}, mgAirBarBg)
local mgAirNeedle = new("Frame", {
	Name = "Needle",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.1, 0.5),
	Size = UDim2.new(0, 4, 1, 8),
	BackgroundColor3 = C.Cream,
	BorderSizePixel = 0,
	ZIndex = 11,
}, mgAirBarBg)
local mgAirBtn = new("TextButton", {
	Name = "AirBtn",
	Position = UDim2.fromOffset(18, 108),
	Size = UDim2.new(1, -36, 0, 36),
	BackgroundColor3 = Color3.fromRGB(32, 28, 22),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 13,
	AutoLocalize = false,
	AutoButtonColor = false,
	ZIndex = 10,
}, mgAirView)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, mgAirBtn)
new("UIStroke", { Color = Color3.fromRGB(165, 122, 68), Thickness = 1, Transparency = 0.2 }, mgAirBtn)

local activeMGType: string? = nil -- "fuel" | "diesel" | "air" | nil
local mgOpenedAt = 0
local mgOriginPos: Vector3? = nil
local mgDone = false
local mgHolding = false
local mgHasPumped = false
local mgFuelLevel = 0
local mgFuelTargetMin = 0.66
local mgFuelTargetMax = 0.84
local mgAirNeedlePos = 0
local mgAirNeedleDir = 1
local mgAirZoneMin = 0.36
local mgAirZoneMax = 0.58
local mgAirHits = 0
local MG_AIR_NEEDED = 3

local function updateAirPipsText()
	local filled = string.rep("● ", mgAirHits)
	local empty = string.rep("○ ", MG_AIR_NEEDED - mgAirHits)
	mgAirPips.Text = string.format("%s%s (%d/%d)", filled, empty, mgAirHits, MG_AIR_NEEDED)
end

local function randomizeFuelTarget()
	mgFuelTargetMin = 0.60 + math.random() * 0.16
	mgFuelTargetMax = mgFuelTargetMin + 0.18
	mgFuelTargetZone.Position = UDim2.fromScale(0, 1 - mgFuelTargetMax)
	mgFuelTargetZone.Size = UDim2.fromScale(1, mgFuelTargetMax - mgFuelTargetMin)
end

local function randomizeAirTarget()
	local width = 0.22 - mgAirHits * 0.02
	mgAirZoneMin = 0.18 + math.random() * (0.64 - width)
	mgAirZoneMax = mgAirZoneMin + width
	mgAirTargetZone.Position = UDim2.fromScale(mgAirZoneMin, 0)
	mgAirTargetZone.Size = UDim2.fromScale(width, 1)
end

local function closeMinigame()
	activeMGType = nil
	mgDone = false
	mgHolding = false
	mgHasPumped = false
	mgFrame.Visible = false
	mgFuelView.Visible = false
	mgAirView.Visible = false
end

local function finishMinigameSuccess(stationType: string)
	if mgDone then
		return
	end
	mgDone = true
	mgHolding = false
	if stationType == "air" then
		mgAirHint.Text = ui("MG_Success")
		mgAirHint.TextColor3 = Color3.fromRGB(155, 225, 130)
	else
		mgFuelHint.Text = ui("MG_Success")
		mgFuelHint.TextColor3 = Color3.fromRGB(155, 225, 130)
	end
	task.delay(0.32, function()
		if activeMGType == stationType then
			closeMinigame()
			ServiceMinigame:FireServer("complete", stationType)
		end
	end)
end

local function openMinigame(stationType: string)
	activeMGType = stationType
	mgOpenedAt = os.clock()
	mgDone = false
	mgHolding = false
	mgHasPumped = false
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	mgOriginPos = if root then root.Position else nil

	mgCloseBtn.Text = ui("MG_CancelHint")
	if stationType == "fuel" or stationType == "diesel" then
		mgTitle.Text = ui(if stationType == "diesel" then "MG_DieselTitle" else "MG_FuelTitle")
		mgFuelHint.Text = ui("MG_FuelHint")
		mgFuelHint.TextColor3 = C.Dim
		mgFuelBtn.Text = ui("MG_FuelBtn")
		mgFuelLevel = 0
		mgFuelFill.Size = UDim2.fromScale(1, 0)
		local isBlood = (remotes:GetAttribute("Anomaly") == "Anomaly_BloodFuel") and (localPlayer:GetAttribute("Praying") == true)
		mgFuelFill.BackgroundColor3 = if isBlood
			then Color3.fromRGB(165, 20, 20)
			elseif stationType == "diesel" then Color3.fromRGB(78, 165, 65)
			else Color3.fromRGB(218, 138, 38)
		randomizeFuelTarget()
		mgFuelView.Visible = true
		mgAirView.Visible = false
	else
		mgTitle.Text = ui("MG_AirTitle")
		mgAirHint.Text = ui("MG_AirHint")
		mgAirHint.TextColor3 = C.Dim
		mgAirBtn.Text = ui("MG_AirBtn")
		mgAirHits = 0
		mgAirNeedlePos = 0.08
		mgAirNeedleDir = 1
		updateAirPipsText()
		randomizeAirTarget()
		mgFuelView.Visible = false
		mgAirView.Visible = true
	end
	mgFrame.Visible = true
end

local function tryAirStrike()
	if activeMGType ~= "air" or mgDone or os.clock() - mgOpenedAt < 0.18 then
		return
	end
	if mgAirNeedlePos >= mgAirZoneMin - 0.025 and mgAirNeedlePos <= mgAirZoneMax + 0.025 then
		mgAirHits += 1
		updateAirPipsText()
		if mgAirHits >= MG_AIR_NEEDED then
			finishMinigameSuccess("air")
		else
			mgAirHint.Text = ui("MG_AirHint")
			mgAirHint.TextColor3 = Color3.fromRGB(225, 190, 110)
			randomizeAirTarget()
		end
	else
		mgAirHint.Text = ui("MG_AirMiss")
		mgAirHint.TextColor3 = C.BloodLit
	end
end

local function setFuelHolding(down: boolean)
	if (activeMGType ~= "fuel" and activeMGType ~= "diesel") or mgDone then
		return
	end
	if down and os.clock() - mgOpenedAt < 0.18 then
		return
	end
	if down then
		mgHolding = true
		mgHasPumped = true
		mgFuelBtn.BackgroundColor3 = Color3.fromRGB(58, 46, 32)
		mgFuelBtnStroke.Color = Color3.fromRGB(230, 175, 88)
	else
		local wasHolding = mgHolding
		mgHolding = false
		mgFuelBtn.BackgroundColor3 = Color3.fromRGB(32, 28, 22)
		mgFuelBtnStroke.Color = Color3.fromRGB(165, 122, 68)
		if wasHolding and mgHasPumped then
			if mgFuelLevel >= mgFuelTargetMin and mgFuelLevel <= mgFuelTargetMax then
				finishMinigameSuccess(activeMGType :: string)
			elseif mgFuelLevel < mgFuelTargetMin then
				mgHasPumped = false
				mgFuelHint.Text = ui("MG_FuelShort")
				mgFuelHint.TextColor3 = Color3.fromRGB(225, 175, 88)
			end
		end
	end
end

mgCloseBtn.Activated:Connect(closeMinigame)
mgFuelBtn.MouseButton1Down:Connect(function()
	setFuelHolding(true)
end)
mgFuelBtn.MouseButton1Up:Connect(function()
	setFuelHolding(false)
end)
mgAirBtn.MouseButton1Down:Connect(tryAirStrike)

ServiceMinigame.OnClientEvent:Connect(function(action: string, stationType: string?)
	if action == "open" and stationType then
		openMinigame(stationType)
	elseif action == "close" then
		closeMinigame()
	end
end)

-- ---------------------------------------------------------------- แถบปุ่มคีย์ (ขวาล่าง เหนือแผงเงิน: V ปลดล็อกเมาส์ / G พนมมือ)
local hints = new("Frame", { Name = "KeyHints", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -54), Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, hints)
local _hintVKey, hintV = keyHint(hints, "V", 1) -- ปลดล็อกเมาส์ในมุมมองบุคคลที่ 1
local _hintGKey, hintG = keyHint(hints, "G", 2) -- พนมมือ (PrayerController)

-- ปุ่ม Modal ล่องหนสำหรับปลดล็อกเมาส์ในมุมมองบุคคลที่ 1 (กด V หรือ LeftAlt เพื่อสลับปลดล็อก/ล็อกเมาส์)
local playerGui = localPlayer:WaitForChild("PlayerGui")
local mouseUnlocked = false
local mouseModalBtn = new("TextButton", {
	Name = "MouseUnlockModal",
	Size = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Text = "",
	Modal = true,
	Visible = false,
}, gui)
local cachedBookWin: GuiObject? = nil
local cachedSetWin: GuiObject? = nil
local cachedDeathGui: ScreenGui? = nil
local cachedDeathOverlay: GuiObject? = nil

local function isAnyModalOpen(): boolean
	if mouseUnlocked or lobbyBtn.Visible or mgFrame.Visible then
		return true
	end
	if not cachedBookWin or not cachedBookWin.Parent then
		local bookGui = playerGui:FindFirstChild("BookGui")
		cachedBookWin = bookGui and (bookGui:FindFirstChild("Panel") or bookGui:FindFirstChild("Window")) :: GuiObject?
	end
	if cachedBookWin and cachedBookWin.Visible then
		return true
	end
	if not cachedSetWin or not cachedSetWin.Parent then
		local setGui = playerGui:FindFirstChild("SettingsGui")
		cachedSetWin = setGui and (setGui:FindFirstChild("Panel") or setGui:FindFirstChild("Window")) :: GuiObject?
	end
	if cachedSetWin and cachedSetWin.Visible then
		return true
	end
	if not cachedDeathGui or not cachedDeathGui.Parent then
		local dg = playerGui:FindFirstChild("DeathScreen")
		cachedDeathGui = if dg and dg:IsA("ScreenGui") then dg else nil
		cachedDeathOverlay = cachedDeathGui and cachedDeathGui:FindFirstChild("Overlay") :: GuiObject?
	end
	if cachedDeathGui and cachedDeathGui.Enabled then
		if not cachedDeathOverlay or cachedDeathOverlay.Visible then
			return true
		end
	end
	return false
end
local function updateMouseHint()
	hintV.Text = ui(if mouseUnlocked then "HintLockMouse" else "HintUnlockMouse")
end
local function setMouseUnlocked(unlocked: boolean)
	mouseUnlocked = unlocked
	mouseModalBtn.Visible = unlocked
	UserInputService.MouseIconEnabled = isAnyModalOpen()
	updateMouseHint()
end
UserInputService.MouseIconEnabled = false
RunService:BindToRenderStep("PumpCameraFlashlight", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local showCursor = isAnyModalOpen()
	if UserInputService.MouseIconEnabled ~= showCursor then
		UserInputService.MouseIconEnabled = showCursor
	end
	updateFlashlightSlot()

	-- อัปเดตมินิเกมเติมน้ำมัน / เติมลม
	if mgFrame.Visible and activeMGType and not mgDone then
		local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and mgOriginPos and (root.Position - mgOriginPos).Magnitude > 12 then
			closeMinigame()
			return
		end
		if activeMGType == "fuel" or activeMGType == "diesel" then
			if mgHolding then
				mgFuelLevel += dt * 0.64
				if mgFuelLevel >= 1.0 then
					mgFuelLevel = 0
					mgHolding = false
					mgHasPumped = false
					mgFuelBtn.BackgroundColor3 = Color3.fromRGB(32, 28, 22)
					mgFuelBtnStroke.Color = Color3.fromRGB(165, 122, 68)
					mgFuelHint.Text = ui("MG_FuelOverflow")
					mgFuelHint.TextColor3 = C.BloodLit
					randomizeFuelTarget()
				end
			elseif mgFuelLevel > 0 then
				mgFuelLevel = math.max(0, mgFuelLevel - dt * 0.16)
			end
			mgFuelFill.Size = UDim2.fromScale(1, math.clamp(mgFuelLevel, 0, 1))
		elseif activeMGType == "air" then
			local speed = 1.15 + mgAirHits * 0.22
			mgAirNeedlePos += mgAirNeedleDir * dt * speed
			if mgAirNeedlePos >= 0.96 then
				mgAirNeedlePos = 0.96
				mgAirNeedleDir = -1
			elseif mgAirNeedlePos <= 0.04 then
				mgAirNeedlePos = 0.04
				mgAirNeedleDir = 1
			end
			mgAirNeedle.Position = UDim2.fromScale(mgAirNeedlePos, 0.5)
		end
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if mgFrame.Visible and activeMGType then
		if input.KeyCode == Enum.KeyCode.X or input.KeyCode == Enum.KeyCode.Backspace then
			closeMinigame()
			return
		elseif input.KeyCode == Enum.KeyCode.Space then
			if activeMGType == "air" then
				tryAirStrike()
			else
				setFuelHolding(true)
			end
			return
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			if activeMGType == "air" then
				tryAirStrike()
			else
				setFuelHolding(true)
			end
			return
		end
	end
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V or input.KeyCode == Enum.KeyCode.LeftAlt then
		setMouseUnlocked(not mouseUnlocked)
	elseif input.KeyCode == Enum.KeyCode.One then
		toggleFlashlightEquip()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if mgFrame.Visible and (activeMGType == "fuel" or activeMGType == "diesel") then
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setFuelHolding(false)
		end
	end
end)

-- ---------------------------------------------------------------- ซ่อน/แสดง HUD ตามการตั้งค่า (คำพูดลูกค้า + แถบประกาศแสดงเสมอ)
local function applyShowHUD()
	local show = localPlayer:GetAttribute("ShowHUD") ~= false
	panel.Visible = show
	hints.Visible = show
	updateFlashlightSlot()
end
applyShowHUD()
localPlayer:GetAttributeChangedSignal("ShowHUD"):Connect(applyShowHUD)

-- ---------------------------------------------------------------- เงิน
local lastMoney = 0
UpdateHUD.OnClientEvent:Connect(function(money: number, target: number, _incense: number, _maxIncense: number)
	moneyText.Text = string.format("฿%d / ฿%d", money, target)
	if money > lastMoney then
		moneyText.TextColor3 = Color3.fromRGB(170, 230, 140)
		TweenService:Create(moneyText, TweenInfo.new(1), { TextColor3 = C.Cream }):Play()
	elseif money < lastMoney then
		moneyText.TextColor3 = C.BloodLit
		TweenService:Create(moneyText, TweenInfo.new(1.5), { TextColor3 = C.Cream }):Play()
	end
	lastMoney = money
end)

-- ---------------------------------------------------------------- คำพูดลูกค้า
-- ข้อความบรรยาย (เนื้อเรื่อง / คำแนะนำ) ใช้กล่องล่างจอเดียวกับคำพูด แต่ไม่มีหัวชื่อคนพูด
-- (ไม่ขึ้นกลางจอ เผื่อเปลี่ยนเป็นมุมมองบุคคลที่หนึ่งในอนาคต)
local narrationKey: string? = nil
local narrationToken = 0
local function setHeader(show: boolean)
	dialogHeader.Visible = show
	line.Position = if show then UDim2.new(0, 16, 0, 19) else UDim2.new(0, 16, 0, 6)
	line.Size = if show then UDim2.new(1, -32, 1, -22) else UDim2.new(1, -32, 1, -12)
end
local function showNarration(key: string, seconds: number?)
	bubbleKey = nil
	narrationKey = key
	narrationToken += 1
	local token = narrationToken
	setHeader(false)
	dialog.BackgroundTransparency = DIALOG_BG_TRANSPARENCY
	dialog.Visible = true
	typeLine(ui(key))
	if seconds then
		task.delay(seconds, function()
			if narrationToken == token and narrationKey == key then
				narrationKey = nil
				dialog.Visible = false
				setHeader(true)
			end
		end)
	end
end

CustomerSpeech.OnClientEvent:Connect(function(key: string?, head: BasePart?, who: { [string]: any }?, vars: { [string]: any }?)
	if key then
		narrationKey = nil -- ลูกค้าพูดทับข้อความบรรยาย
		setHeader(true)
	elseif narrationKey then
		return
	end
	bubbleKey = key
	bubbleVars = vars
	bubbleSpeaker = who
	if not key then
		typeToken += 1
		local t = TweenService:Create(dialog, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		t:Play()
		task.delay(0.4, function()
			if not bubbleKey then
				dialog.Visible = false
				dialog.BackgroundTransparency = DIALOG_BG_TRANSPARENCY
			end
		end)
		return
	end
	dialog.BackgroundTransparency = DIALOG_BG_TRANSPARENCY
	dialog.Visible = true
	drawSpeaker()
	typeLine(LanguageModule.GetText(key, lang(), vars))
	-- เล่นเสียงพากย์ตามประโยคและเพศตัวละครผู้พูด (ลูกค้าชาย/หญิง หรือผู้เล่นชาย/หญิง)
	local voiceKey = if key == "PlayerQuote" and vars and vars.amount then "PlayerQuote_" .. tostring(vars.amount) else key
	SoundBank.PlayDialogueVoice(voiceKey, who, head)
end)

-- ---------------------------------------------------------------- ผีหลอก (เติมน้ำมันให้ผี)
TriggerJumpscare.OnClientEvent:Connect(function(_anomalyKey: string?, _source: Instance?, reason: string?)
	SoundBank.PlayReaction("Fear", SoundBank.DetectPlayerGender(localPlayer))
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	-- reason "chased" = วิ่งตามผีที่ไล่ไปแล้ว (ไม่ได้เติมน้ำมันให้)
	showBanner(if reason == "chased" then "JumpscareChased" else "Jumpscare", true, 3)
	local cam = workspace.CurrentCamera
	if cam then
		task.spawn(function()
			for _ = 1, 10 do
				cam.CFrame *= CFrame.Angles(math.rad(math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
				task.wait(0.03)
			end
		end)
	end
end)

-- ---------------------------------------------------------------- ชนะ / แพ้ / คืนใหม่
GameState.OnClientEvent:Connect(function(state: string)
	lobbyBtn.Visible = state == "Win"
	if state == "Win" then
		showBanner("Win", false, 10)
		lobbyBtn.Text = ui("Quit")
		lobbyBtn.Active = true
	elseif state == "Lose" then
		-- แพ้: จอตายสีแดง + ถามเริ่มใหม่ / กลับ Lobby อยู่ใน DeathScreen.client.luau
	elseif state == "Waiting" then
		showNarration("WaitOpen", 5) -- แสดง 5 วินาทีแล้วซ่อนอัตโนมัติ ไม่ค้างบังจอ
	elseif state == "Playing" then
		showNarration("NewNight", 5)
	end
end)

-- ---------------------------------------------------------------- ปุ่ม ProximityPrompt (เปลี่ยนข้อความฝั่ง Client ตามภาษาของเรา)
local PROMPTS = {
	PumpFuelPrompt = { "FillUp", "GasPump" },
	RejectCustomerPrompt = { "CloseShop", "ShutterRope" },
	OpenShopPrompt = { "OpenShop", "ShutterRope" },
	DieselFuelPrompt = { "FillDiesel", "DieselPump" },
	AirPumpPrompt = { "PumpAir", "AirCompressorName" },
}
local trackedPrompts: { [ProximityPrompt]: boolean } = {}
local function localizePrompt(p: Instance)
	local keys = PROMPTS[p.Name]
	if keys and p:IsA("ProximityPrompt") then
		trackedPrompts[p] = true
		p.AutoLocalize = false
		p.ActionText = ui(keys[1])
		p.ObjectText = ui(keys[2])
	end
end
-- สแกนเฉพาะโฟลเดอร์ที่มีปุ่มกดจริง (InteractiveProps และ AirCompressor) แทนการกวาดทั้ง Workspace 55,000+ ชิ้น
local interactiveProps = workspace:WaitForChild("InteractiveProps", 10)
if interactiveProps then
	for _, d in ipairs(interactiveProps:GetDescendants()) do
		localizePrompt(d)
	end
	interactiveProps.DescendantAdded:Connect(localizePrompt)
end
local airCompRoot = workspace:FindFirstChild("AirCompressor")
if airCompRoot then
	for _, d in ipairs(airCompRoot:GetDescendants()) do
		localizePrompt(d)
	end
	airCompRoot.DescendantAdded:Connect(localizePrompt)
end

-- เปลี่ยนภาษาทุกข้อความที่แสดงอยู่
local function refreshLanguage()
	moneyTitle.Text = ui("Money")
	updateMouseHint()
	hintG.Text = ui("HintPray")
	slotLabel.Text = ui("FlashlightSlot")
	drawSpeaker()
	drawReplies()
	if lobbyBtn.Visible and lobbyBtn.Active then
		lobbyBtn.Text = ui("Quit")
	end
	if bannerKey and bannerBar.Visible then
		banner.Text = ui(bannerKey)
	end
	if narrationKey and dialog.Visible then
		typeToken += 1
		line.Text = ui(narrationKey)
		line.MaxVisibleGraphemes = -1
	elseif bubbleKey and dialog.Visible then
		typeToken += 1
		line.Text = LanguageModule.GetText(bubbleKey, lang(), bubbleVars)
		line.MaxVisibleGraphemes = -1
	end
	for p in pairs(trackedPrompts) do
		if p.Parent then
			localizePrompt(p)
		else
			trackedPrompts[p] = nil
		end
	end
end
refreshLanguage()
localPlayer:GetAttributeChangedSignal("Lang"):Connect(refreshLanguage)
