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
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
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

-- ป้ายปุ่มคีย์แบบกระดาษเก่า [Q] + คำอธิบาย
local function keyHint(parent: Instance, key: string, order: number): (TextLabel, TextLabel)
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local badge = new("TextLabel", {
		BackgroundColor3 = C.Paper,
		Size = UDim2.new(0, 0, 0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = FONT_BODY,
		TextColor3 = C.Ink,
		TextSize = 16,
		Text = key,
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

-- ---------------------------------------------------------------- แผงเงิน + ธูป (มุมขวาล่าง ไม่มีพื้นหลัง มีแค่เงาจางๆ)
local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -22, 1, -18),
	Size = UDim2.new(0, 230, 0, 84),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, gui)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 0.2), NumberSequenceKeypoint.new(1, 0) }) }, panel)
local function shadow(t: TextLabel)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.3 }, t)
end
local moneyTitle = text(panel, { Name = "MoneyTitle", Position = UDim2.new(0, 0, 0, 2), Size = UDim2.new(1, -10, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Dim, MaxTextSize = 15 })
local moneyText = text(panel, { Name = "Money", Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, -10, 0, 36), TextXAlignment = Enum.TextXAlignment.Right, FontFace = FONT_SCARY, TextColor3 = C.Cream, Text = "฿0 / ฿500", MaxTextSize = 32 })
local incenseText = text(panel, { Name = "Incense", Position = UDim2.new(0, 0, 0, 58), Size = UDim2.new(1, -10, 0, 22), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Ember, MaxTextSize = 17 })
shadow(moneyTitle)
shadow(moneyText)
shadow(incenseText)
tremble(moneyText, 1, false)

local lastIncense, lastMaxIncense = 3, 3
local function drawIncense()
	incenseText.Text = ui("Incense") .. "  " .. string.rep("🕯️", lastIncense) .. string.rep("⚫", lastMaxIncense - lastIncense)
end

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

-- ---------------------------------------------------------------- กล่องคำพูดลูกค้า (ล่างจอ แบบไดอารี่)
local dialog = new("Frame", {
	Name = "Dialogue",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -112), -- เหนือช่องเก็บของ (Hotbar)
	Size = UDim2.new(0.62, 0, 0, 96),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(900, 110) }, dialog)
new("UIStroke", { Color = Color3.fromRGB(70, 64, 54), Thickness = 1, Transparency = 0.2 }, dialog)
local dialogHeader = new("Frame", { Name = "Header", BackgroundColor3 = C.Bar, BackgroundTransparency = 0.1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28) }, dialog)
local speaker = text(dialogHeader, { Name = "Speaker", Position = UDim2.new(0, 0, 0, 3), Size = UDim2.new(1, 0, 1, -6), TextXAlignment = Enum.TextXAlignment.Center, MaxTextSize = 19 })
local line = text(dialog, {
	Name = "Line",
	Position = UDim2.new(0, 22, 0, 38),
	Size = UDim2.new(1, -44, 1, -48),
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	MaxTextSize = 22,
})

local bubbleKey: string? = nil
local bubbleVars: { [string]: any }? = nil
local bubbleSpeaker: { [string]: string }? = nil
local typeToken = 0

-- หัวกล่อง: ชื่อลูกค้า (แปลตามภาษา) หรือชื่อผู้เล่นที่ตอบ (สีส้มถ่าน)
local function drawSpeaker()
	local sp = bubbleSpeaker
	if sp and sp.ghost then
		speaker.Text = sp.ghost -- เสียงกระซิบไม่รู้ที่มา
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

-- ---------------------------------------------------------------- แถบปุ่มคีย์ (ขวาล่าง)
-- เรียงแนวตั้ง ชิดขวา อยู่เหนือแผงเงิน
local hints = new("Frame", { Name = "KeyHints", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -128), Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, hints)
local hintClickKey, hintClick = keyHint(hints, "", 1)
local hintEKey, hintE = keyHint(hints, "E", 2)

-- ---------------------------------------------------------------- ซ่อน/แสดง HUD ตามการตั้งค่า (คำพูดลูกค้า + แถบประกาศแสดงเสมอ)
local function applyShowHUD()
	local show = localPlayer:GetAttribute("ShowHUD") ~= false
	panel.Visible = show
	hints.Visible = show
end
applyShowHUD()
localPlayer:GetAttributeChangedSignal("ShowHUD"):Connect(applyShowHUD)

-- ---------------------------------------------------------------- เงิน + ธูป
local lastMoney = 0
UpdateHUD.OnClientEvent:Connect(function(money: number, target: number, incense: number, maxIncense: number)
	moneyText.Text = string.format("฿%d / ฿%d", money, target)
	if money > lastMoney then
		moneyText.TextColor3 = Color3.fromRGB(170, 230, 140)
		TweenService:Create(moneyText, TweenInfo.new(1), { TextColor3 = C.Cream }):Play()
	elseif money < lastMoney then
		moneyText.TextColor3 = C.BloodLit
		TweenService:Create(moneyText, TweenInfo.new(1.5), { TextColor3 = C.Cream }):Play()
	end
	lastMoney = money
	lastIncense, lastMaxIncense = incense, maxIncense
	drawIncense()
end)

-- ---------------------------------------------------------------- คำพูดลูกค้า
CustomerSpeech.OnClientEvent:Connect(function(key: string?, _head: BasePart?, who: { [string]: string }?, vars: { [string]: any }?)
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
				dialog.BackgroundTransparency = 0.18
			end
		end)
		return
	end
	dialog.BackgroundTransparency = 0.18
	dialog.Visible = true
	drawSpeaker()
	typeLine(LanguageModule.GetText(key, lang(), vars))
end)

-- ---------------------------------------------------------------- ผีหลอก (เติมน้ำมันให้ผี)
TriggerJumpscare.OnClientEvent:Connect(function(_anomalyKey: string?)
	flash.BackgroundTransparency = 0.1
	TweenService:Create(flash, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	showBanner("Jumpscare", true, 3)
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
	if state == "Win" then
		showBanner("Win", false, 10)
	elseif state == "Lose" then
		showBanner("Lose", true, 10)
	elseif state == "Waiting" then
		showBanner("WaitOpen", false, 600) -- ค้างไว้จนกว่าจะมีคนเปิดร้าน
	elseif state == "Playing" then
		showBanner("NewNight", false, 4)
	end
end)

-- ---------------------------------------------------------------- ปุ่ม ProximityPrompt (เปลี่ยนข้อความฝั่ง Client ตามภาษาของเรา)
local PROMPTS = {
	PumpFuelPrompt = { "FillUp", "GasPump" },
	RejectCustomerPrompt = { "CloseShop", "ShutterRope" },
	OpenShopPrompt = { "OpenShop", "ShutterRope" },
}
local function localizePrompt(p: Instance)
	local keys = PROMPTS[p.Name]
	if keys and p:IsA("ProximityPrompt") then
		p.AutoLocalize = false
		p.ActionText = ui(keys[1])
		p.ObjectText = ui(keys[2])
	end
end
local interactive = workspace:WaitForChild("InteractiveProps")
for _, d in ipairs(interactive:GetDescendants()) do
	localizePrompt(d)
end
interactive.DescendantAdded:Connect(localizePrompt)

-- เปลี่ยนภาษาทุกข้อความที่แสดงอยู่
local function refreshLanguage()
	moneyTitle.Text = ui("Money")
	drawIncense()
	hintClickKey.Text = ui("KeyClick")
	hintClick.Text = ui("HintFlashlight")
	hintE.Text = ui("HintHold")
	drawSpeaker()
	drawReplies()
	if bannerKey and bannerBar.Visible then
		banner.Text = ui(bannerKey)
	end
	if bubbleKey and dialog.Visible then
		typeToken += 1
		line.Text = LanguageModule.GetText(bubbleKey, lang(), bubbleVars)
		line.MaxVisibleGraphemes = -1
	end
	for _, d in ipairs(interactive:GetDescendants()) do
		localizePrompt(d)
	end
end
refreshLanguage()
localPlayer:GetAttributeChangedSignal("Lang"):Connect(refreshLanguage)
