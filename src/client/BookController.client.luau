-- BookController.client.luau
-- สมุดบันทึกผีไทย (Phase 5 ข้อ 2): ปุ่ม "สมุดผี" ข้างปุ่มตั้งค่า มุมขวาบน -> หน้าต่างรายชื่อผี
--   ผีที่เคยรอดมาแล้ว = เห็นชื่อ + คำใบ้วิธีสังเกต + จำนวนครั้งที่รอด / ยังไม่เคยเจอ = "???"
--   ข้อมูลมาจาก Attribute "Book" บนตัวผู้เล่น (Server: AnomalyBook.luau จำไว้ใน DataStore)
--   ปลดล็อกใหม่ -> แจ้งเตือนกลางจอด้านบน + ปุ่มสมุดกะพริบแดง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local BookUnlocked = remotes:WaitForChild("BookUnlocked") :: RemoteEvent

local function lang(): string
	return LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?)
end
local function ui(key: string): string
	return LanguageModule.GetUI(key, lang())
end

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Card = Color3.fromRGB(22, 19, 16),
	CardLocked = Color3.fromRGB(12, 11, 10),
	Bar = Color3.fromRGB(58, 54, 46),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(150, 142, 124),
	Faint = Color3.fromRGB(90, 84, 72),
	Blood = Color3.fromRGB(150, 18, 16),
	Ember = Color3.fromRGB(230, 120, 50),
	Line = Color3.fromRGB(80, 72, 60),
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

-- ---------------------------------------------------------------- ข้อมูลสมุด
local function readBook(): { [string]: number }
	local t = {}
	local raw = localPlayer:GetAttribute("Book")
	if type(raw) == "string" then
		for k, n in string.gmatch(raw, "([%w_]+):(%d+)") do
			t[k] = tonumber(n) :: number
		end
	end
	return t
end

-- ---------------------------------------------------------------- UI
local gui = new("ScreenGui", {
	Name = "BookGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 6,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, localPlayer:WaitForChild("PlayerGui"))

-- ปุ่มสมุด (หน้าตาเหมือนปุ่มตั้งค่า วางซ้ายของปุ่มตั้งค่า)
local bookBtn = new("TextButton", {
	Name = "BookButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -150, 0, 16),
	Size = UDim2.new(0, 0, 0, 30),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextSize = 17,
	TextColor3 = C.Cream,
	AutoButtonColor = false,
}, gui)
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, bookBtn)
new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bookBtn)

-- วางให้อยู่ซ้ายปุ่มตั้งค่าเสมอ (ปุ่มตั้งค่ากว้างไม่เท่ากันตามภาษา)
task.spawn(function()
	local sg = localPlayer.PlayerGui:WaitForChild("SettingsGui", 20)
	local sb = sg and sg:WaitForChild("SettingsButton", 20) :: GuiObject?
	if not sb then
		return
	end
	local function place()
		local right = gui.AbsoluteSize.X - sb.AbsolutePosition.X + 10
		bookBtn.Position = UDim2.new(1, -right, 0, 16)
	end
	place()
	sb:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	sb:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
end)

-- หน้าต่างสมุด
local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 600, 0, 480),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(600, 480) }, panel)
new("UIStroke", { Color = C.Line, Thickness = 1 }, panel)
local header = new("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundColor3 = C.Bar,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 22,
}, panel)
-- ปุ่มปิด X (เส้นไขว้ เหมือนหน้าตั้งค่า)
local closeBtn = new("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.new(0, 28, 0, 28),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Modal = true,
}, header)
local xLines = {}
for _, angle in ipairs({ 45, -45 }) do
	table.insert(xLines, new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 18, 0, 2),
		Rotation = angle,
		BackgroundColor3 = C.Dim,
		BorderSizePixel = 0,
	}, closeBtn))
end
closeBtn.MouseEnter:Connect(function()
	for _, l in ipairs(xLines) do
		l.BackgroundColor3 = Color3.fromRGB(220, 60, 50)
	end
end)
closeBtn.MouseLeave:Connect(function()
	for _, l in ipairs(xLines) do
		l.BackgroundColor3 = C.Dim
	end
end)

local countLabel = new("TextLabel", {
	Name = "Count",
	Position = UDim2.new(0, 0, 0, 42),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Ember,
	TextSize = 18,
}, panel)

local list = new("ScrollingFrame", {
	Name = "List",
	Position = UDim2.new(0, 16, 0, 74),
	Size = UDim2.new(1, -32, 1, -88),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.Faint,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, panel)
new("UIGridLayout", {
	CellSize = UDim2.new(0.5, -6, 0, 104),
	CellPadding = UDim2.new(0, 10, 0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, list)

local cards: { [string]: { frame: Frame, name: TextLabel, desc: TextLabel, count: TextLabel } } = {}
for i, key in ipairs(LanguageModule.BookOrder) do
	local f = new("Frame", { Name = key, BackgroundColor3 = C.CardLocked, BorderSizePixel = 0, LayoutOrder = i }, list)
	local stroke = new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.3 }, f)
	stroke.Name = "Stroke"
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, f)
	local num = new("TextLabel", {
		Name = "Number",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 30, 0, 22),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Faint,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = string.format("%02d", i),
	}, f)
	local name = new("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -34, 0, 24),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, f)
	local desc = new("TextLabel", {
		Name = "Desc",
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, f)
	local count = new("TextLabel", {
		Name = "Count",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Ember,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	local _ = num
	cards[key] = { frame = f, name = name, desc = desc, count = count }
end

local function refresh()
	local book = readBook()
	local l = lang()
	local found = 0
	for _, key in ipairs(LanguageModule.BookOrder) do
		local n = book[key] or 0
		local card = cards[key]
		if n > 0 then
			found += 1
			local title, text = LanguageModule.GetBook(key, l)
			card.frame.BackgroundColor3 = C.Card
			card.name.Text = title
			card.name.TextColor3 = C.Cream
			card.desc.Text = text
			card.desc.TextColor3 = C.Dim
			card.count.Text = (string.gsub(ui("BookSurvived"), "{n}", tostring(n)))
			;(card.frame:FindFirstChild("Stroke") :: UIStroke).Color = C.Blood
		else
			card.frame.BackgroundColor3 = C.CardLocked
			card.name.Text = ui("BookLockedName")
			card.name.TextColor3 = C.Faint
			card.desc.Text = ui("BookLockedHint")
			card.desc.TextColor3 = C.Faint
			card.count.Text = ""
			;(card.frame:FindFirstChild("Stroke") :: UIStroke).Color = C.Line
		end
	end
	local total = #LanguageModule.BookOrder
	local countText = (string.gsub(ui("BookCount"), "{n}", tostring(found)))
	countLabel.Text = (string.gsub(countText, "{total}", tostring(total)))
	header.Text = ui("BookTitle")
	bookBtn.Text = ui("BookButton")
end
refresh()
localPlayer:GetAttributeChangedSignal("Book"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("Lang"):Connect(refresh)

-- ---------------------------------------------------------------- เปิด / ปิด
local hasNew = false
local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		hasNew = false
		refresh()
	end
	bookBtn.BackgroundColor3 = if open then C.Blood else C.Ink
end
bookBtn.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)
bookBtn.MouseEnter:Connect(function()
	bookBtn.BackgroundColor3 = C.Blood
end)
bookBtn.MouseLeave:Connect(function()
	bookBtn.BackgroundColor3 = if panel.Visible then C.Blood else C.Ink
end)

-- ---------------------------------------------------------------- แจ้งเตือนปลดล็อกใหม่
local toast = new("Frame", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.new(0, 0, 0, 40),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UIStroke", { Color = C.Blood, Thickness = 1 }, toast)
new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, toast)
local toastText = new("TextLabel", {
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 19,
}, toast)
local toastToken = 0
BookUnlocked.OnClientEvent:Connect(function(key: string)
	local title = LanguageModule.GetBook(key, lang())
	toastText.Text = ui("BookNew") .. ":  " .. title
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toastText.TextTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(toastText, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	toastToken += 1
	local my = toastToken
	task.delay(4.5, function()
		if toastToken ~= my then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		local t = TweenService:Create(toastText, TweenInfo.new(0.8), { TextTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		if toastToken == my then
			toast.Visible = false
		end
	end)
	-- ปุ่มสมุดกะพริบแดงจนกว่าจะเปิดดู
	hasNew = true
	task.spawn(function()
		while hasNew and not panel.Visible do
			bookBtn.BackgroundColor3 = C.Blood
			task.wait(0.6)
			if not hasNew or panel.Visible then
				break
			end
			bookBtn.BackgroundColor3 = C.Ink
			task.wait(0.6)
		end
	end)
end)
