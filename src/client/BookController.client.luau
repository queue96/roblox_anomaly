-- BookController.client.luau
-- สมุดบันทึกผีไทย (Phase 5 ข้อ 2): ปุ่ม "สมุดผี" ซ้ายจอใต้ปุ่ม SHOP (เฉพาะ lobby) -> หน้าต่างรายชื่อผี
--   การ์ดละ 1 ผี: รูปจากโมเดล (Shared.BookPortrait ใช้ ReplicatedStorage.BookPortraits) + ชื่อ + ปุ่ม "ลักษณะ"
--   ปุ่มลักษณะ -> หน้าลักษณะ: รูปใหญ่ (กล้องส่ายช้าๆ) + ชื่อ + จำนวนครั้งที่รอด + วิธีสังเกต
--   ยังไม่เคยเจอ = รูปเป็น "?" เห็นแค่ชื่อ ปุ่มลักษณะกดไม่ได้
--   ข้อมูลมาจาก Attribute "Book" บนตัวผู้เล่น (Server: AnomalyBook.luau จำไว้ใน DataStore)
--   ปลดล็อกใหม่ -> แจ้งเตือนกลางจอด้านบน + ปุ่มสมุดกะพริบแดง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
	Dim = Color3.fromRGB(165, 156, 136),
	Faint = Color3.fromRGB(90, 84, 72),
	Blood = Color3.fromRGB(150, 18, 16),
	Ember = Color3.fromRGB(230, 120, 50),
	Line = Color3.fromRGB(70, 64, 54),
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
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiFit")).Attach(gui) -- คอมจอใหญ่ขยาย / จอเตี้ยย่อ (shared/UiFit)

-- ปุ่มสมุด: แสดงเฉพาะใน lobby (ในเกมซ่อนไว้ตามคำขอเดิม ไม่ให้รกจอ) — ดูสมุดได้ที่ lobby ก่อนออกกะ
local LOBBY_PLACE_ID = 70980777393906
local function isLobby(): boolean
	if game.PlaceId == LOBBY_PLACE_ID then
		return true
	end
	return game.PlaceId == 0 and workspace:FindFirstChild("TempleLobby") ~= nil
end
-- ปุ่มอยู่ซ้ายจอ ใต้ปุ่ม SHOP (lobby/client/ShopMenu) หน้าตาและขนาดเดียวกัน (ผู้ใช้ 2026-11-24)
-- ScreenGui แยก DisplayOrder ต่ำกว่า: หน้าต่างร้านค้า / หน้าต่างสมุดบังปุ่มได้
local btnGui = new("ScreenGui", {
	Name = "BookButtonGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = isLobby(),
}, localPlayer:WaitForChild("PlayerGui"))
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiFit")).Attach(btnGui)
local BTN_IDLE = Color3.fromRGB(14, 12, 12)
local BTN_HOT = Color3.fromRGB(48, 22, 20)
local BTN = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 70 else 78 -- เท่าปุ่ม SHOP
local bookBtn = new("TextButton", {
	Name = "BookButton",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 14, 0.42, 6), -- ปุ่ม SHOP อยู่เหนือเส้น 0.42 ห่างกัน 12
	Size = UDim2.fromOffset(BTN, BTN),
	BackgroundColor3 = BTN_IDLE,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Text = "",
	AutoButtonColor = false,
}, btnGui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, bookBtn)
new("UIStroke", { Color = Color3.fromRGB(150, 146, 140), Thickness = 2.5, Transparency = 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bookBtn)
new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0.54, 0),
	Position = UDim2.fromScale(0, 0.06),
	Text = "📖",
	TextScaled = true,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
}, bookBtn)
local bookBtnText = new("TextLabel", { -- ภาษาอื่นชื่อยาว (Libro de Fantasmas) = ขึ้น 2 บรรทัด
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -8, 0.34, 0),
	Position = UDim2.new(0, 4, 0.62, 0),
	TextScaled = true,
	TextWrapped = true,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
}, bookBtn)
new("UITextSizeConstraint", { MaxTextSize = 20 }, bookBtnText)

-- หน้าต่างสมุด (ย่อตามจอ: มือถือแนวนอนก็ไม่ล้น)
local BookPortrait = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BookPortrait"))
local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.92, 0.88),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(720, 540) }, panel)
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
	ZIndex = 20,
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
	ZIndex = 21,
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
		ZIndex = 22,
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

-- แท็บสลับระหว่าง ผี / ฉากจบ
local activeTab = "ghosts"
local tabBar = new("Frame", {
	Name = "Tabs",
	Position = UDim2.new(0, 14, 0, 42),
	Size = UDim2.new(1, -28, 0, 28),
	BackgroundTransparency = 1,
}, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabBar)
local function makeTab(order: number): TextButton
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = C.CardLocked,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 16,
		AutoButtonColor = false,
	}, tabBar)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
	local st = new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	st.Name = "Stroke"
	return b
end
local tabGhostsBtn = makeTab(1)
local tabEndingsBtn = makeTab(2)

local countLabel = new("TextLabel", {
	Name = "Count",
	Position = UDim2.new(0, 0, 0, 74),
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Ember,
	TextSize = 17,
}, panel)

-- รายการผี: แบ่งหน้า (กดปุ่ม ‹ › เปลี่ยนหน้า ไม่ต้องเลื่อน) จำนวนการ์ดต่อหน้าตามขนาดกรอบ
local list = new("Frame", {
	Name = "List",
	Position = UDim2.new(0, 14, 0, 100),
	Size = UDim2.new(1, -28, 1, -154),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, panel)

-- รายการฉากจบ 4 แบบ (แท็บ "ฉากจบ")
local ENDING_ACCENT: { [string]: Color3 } = {
	Ending_Bad = Color3.fromRGB(220, 48, 40),
	Ending_Normal = Color3.fromRGB(235, 202, 138),
	Ending_True = Color3.fromRGB(248, 212, 105),
	Ending_Secret = Color3.fromRGB(205, 62, 98),
}
local endingsList = new("ScrollingFrame", {
	Name = "EndingsList",
	Position = UDim2.new(0, 14, 0, 100),
	Size = UDim2.new(1, -28, 1, -114),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Faint,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Visible = false,
}, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, endingsList)
new("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, endingsList)

type EndingCard = { frame: Frame, stripe: Frame, stroke: UIStroke, tag: TextLabel, status: TextLabel, title: TextLabel, body: TextLabel }
local endingCards: { [string]: EndingCard } = {}
for i, key in ipairs(LanguageModule.EndingOrder) do
	local f = new("Frame", {
		Name = key,
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.CardLocked,
		BorderSizePixel = 0,
	}, endingsList)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
	local st = new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.25 }, f)
	local stripe = new("Frame", {
		Size = UDim2.new(0, 4, 1, 0),
		BackgroundColor3 = C.Line,
		BorderSizePixel = 0,
	}, f)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, stripe)
	local inner = new("Frame", {
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -24, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, f)
	new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }, inner)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, inner)
	local topRow = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 }, inner)
	local tag = new("TextLabel", {
		Size = UDim2.new(0.65, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextSize = 13,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, topRow)
	local status = new("TextLabel", {
		Position = UDim2.fromScale(0.65, 0),
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextSize = 13,
		TextColor3 = C.Faint,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, topRow)
	local title = new("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 24),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextSize = 20,
		TextColor3 = C.Cream,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, inner)
	local body = new("TextLabel", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextSize = 15,
		TextColor3 = C.Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LineHeight = 1.2,
	}, inner)
	endingCards[key] = { frame = f, stripe = stripe, stroke = st, tag = tag, status = status, title = title, body = body }
end
local grid = new("UIGridLayout", {
	CellSize = UDim2.new(0.25, -9, 0, 200),
	CellPadding = UDim2.new(0, 12, 0, 12),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, list)
local perPage = 8
local page = 1
local applyPage: () -> () = function() end
-- จอแคบ (มือถือ) เหลือ 3 คอลัมน์ การ์ดไม่เล็กเกินจนอ่านชื่อไม่ออก / จอเตี้ยเหลือแถวเดียว
local function fitGrid()
	local w, h = list.AbsoluteSize.X, list.AbsoluteSize.Y
	local cols = if w < 520 then 3 else 4
	local cellH = if w < 520 then 184 else 200
	local rows = math.max(1, math.floor((h + 12) / (cellH + 12)))
	grid.CellSize = UDim2.new(1 / cols, -math.ceil(12 * (cols - 1) / cols), 0, cellH)
	perPage = cols * rows
	applyPage()
end
list:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)

local function smallButton(parent: Instance, props: { [string]: any }): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = C.Bar,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 15,
		AutoButtonColor = false,
	}, parent)
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, b)
	new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end

-- ภาพ "?" ของผีที่ยังไม่เจอ
local function mountUnknown(holder: GuiObject)
	BookPortrait.Backdrop(holder)
	new("TextLabel", {
		Name = "Unknown",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		Text = "?",
		TextColor3 = C.Faint,
		TextScaled = true,
		ZIndex = 4,
	}, holder)
	new("UITextSizeConstraint", { MaxTextSize = 90 }, holder:FindFirstChild("Unknown") :: TextLabel)
end

type Card = { frame: Frame, pic: Frame, name: TextLabel, btn: TextButton, shown: string? }
local cards: { [string]: Card } = {}
local openDetail: (key: string) -> ()

for i, key in ipairs(LanguageModule.BookOrder) do
	local f = new("Frame", { Name = key, BackgroundColor3 = C.CardLocked, BorderSizePixel = 0, LayoutOrder = i }, list)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, f)
	local stroke = new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.3 }, f)
	stroke.Name = "Stroke"
	local pic = new("Frame", {
		Name = "Pic",
		Position = UDim2.new(0, 6, 0, 6),
		Size = UDim2.new(1, -12, 1, -74),
		BackgroundColor3 = C.Ink,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, f)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, pic)
	new("TextLabel", {
		Name = "Number",
		Position = UDim2.new(0, 10, 0, 8),
		Size = UDim2.new(0, 30, 0, 18),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("%02d", i),
		ZIndex = 6,
	}, f)
	local name = new("TextLabel", {
		Name = "Name",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 6, 1, -34),
		Size = UDim2.new(1, -12, 0, 34),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 15,
		TextWrapped = true,
	}, f)
	local btn = smallButton(f, {
		Name = "Details",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, 0, 26),
	})
	btn.Activated:Connect(function()
		if btn.Active then
			openDetail(key)
		end
	end)
	btn.MouseEnter:Connect(function()
		if btn.Active then
			btn.BackgroundColor3 = Color3.fromRGB(48, 22, 20)
		end
	end)
	btn.MouseLeave:Connect(function()
		if btn.Active then
			btn.BackgroundColor3 = C.Bar
		end
	end)
	cards[key] = { frame = f, pic = pic, name = name, btn = btn, shown = nil }
end

-- ---------------------------------------------------------------- เปลี่ยนหน้า
local pager = new("Frame", {
	Name = "Pager",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(0, 260, 0, 34),
	BackgroundTransparency = 1,
}, panel)
local prevBtn = smallButton(pager, { Name = "Prev", Size = UDim2.new(0, 56, 1, 0), Text = "‹", TextSize = 26 })
local nextBtn = smallButton(pager, {
	Name = "Next",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, 0),
	Size = UDim2.new(0, 56, 1, 0),
	Text = "›",
	TextSize = 26,
})
local pageLabel = new("TextLabel", {
	Name = "Page",
	Position = UDim2.new(0, 60, 0, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 18,
}, pager)
local function pageCount(): number
	return math.max(1, math.ceil(#LanguageModule.BookOrder / perPage))
end
applyPage = function()
	local pages = pageCount()
	page = math.clamp(page, 1, pages)
	local first = (page - 1) * perPage + 1
	for i, key in ipairs(LanguageModule.BookOrder) do
		cards[key].frame.Visible = i >= first and i < first + perPage
	end
	pageLabel.Text = string.format("%d / %d", page, pages)
	for _, b in ipairs({ prevBtn, nextBtn }) do
		local enabled = if b == prevBtn then page > 1 else page < pages
		b.Active = enabled
		b.TextColor3 = if enabled then C.Cream else C.Faint
		b.BackgroundColor3 = if enabled then C.Bar else C.CardLocked
	end
end
local function turn(delta: number)
	local before = page
	page = math.clamp(page + delta, 1, pageCount())
	if page ~= before then
		applyPage()
	end
end
prevBtn.Activated:Connect(function()
	turn(-1)
end)
nextBtn.Activated:Connect(function()
	turn(1)
end)
for _, b in ipairs({ prevBtn, nextBtn }) do
	b.MouseEnter:Connect(function()
		if b.Active then
			b.BackgroundColor3 = Color3.fromRGB(48, 22, 20)
		end
	end)
	b.MouseLeave:Connect(function()
		if b.Active then
			b.BackgroundColor3 = C.Bar
		end
	end)
end
fitGrid()

-- ---------------------------------------------------------------- หน้าลักษณะ (ซ้อนในหน้าต่างสมุด)
local detail = new("Frame", {
	Name = "Detail",
	Position = UDim2.new(0, 0, 0, 36),
	Size = UDim2.new(1, 0, 1, -36),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
}, panel)
local detailPic = new("Frame", {
	Name = "Pic",
	Position = UDim2.new(0, 16, 0, 16),
	Size = UDim2.new(0.46, -24, 1, -32),
	BackgroundColor3 = C.Ink,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 10,
}, detail)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, detailPic)
new("UIStroke", { Color = C.Blood, Thickness = 1, Transparency = 0.2 }, detailPic)
local info = new("Frame", {
	Name = "Info",
	Position = UDim2.new(0.46, 8, 0, 16),
	Size = UDim2.new(0.54, -24, 1, -32),
	BackgroundTransparency = 1,
	ZIndex = 10,
}, detail)
local dName = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 26,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	AutomaticSize = Enum.AutomaticSize.Y,
	ZIndex = 11,
}, info)
local dCount = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Ember,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, info)
local dHead = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Dim,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 11,
}, info)
-- เส้นคั่นบางๆ
new("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Line, BorderSizePixel = 0, ZIndex = 11 }, info)
local dScroll = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -150),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Faint,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ZIndex = 11,
}, info)
local dDesc = new("TextLabel", {
	Size = UDim2.new(1, -8, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 18,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	LineHeight = 1.15,
	ZIndex = 12,
}, dScroll)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, info)
for i, o in ipairs({ dName, dCount, dHead, info:FindFirstChildOfClass("Frame") :: Frame, dScroll }) do
	o.LayoutOrder = i
end
local backBtn = smallButton(detail, {
	Name = "Back",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.new(0, 110, 0, 32),
	TextSize = 17,
	ZIndex = 12,
})
backBtn.MouseEnter:Connect(function()
	backBtn.BackgroundColor3 = Color3.fromRGB(48, 22, 20)
end)
backBtn.MouseLeave:Connect(function()
	backBtn.BackgroundColor3 = C.Bar
end)

local detailKey: string? = nil
local detailVF: ViewportFrame? = nil
local function closeDetail()
	detail.Visible = false
	detailKey = nil
	detailVF = nil
	for _, c in ipairs(detailPic:GetChildren()) do
		if not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end
backBtn.Activated:Connect(closeDetail)

local function fillDetail()
	local key = detailKey
	if not key then
		return
	end
	local l = lang()
	local title, text = LanguageModule.GetBook(key, l)
	local n = readBook()[key] or 0
	dName.Text = title
	dCount.Text = (string.gsub(ui("BookSurvived"), "{n}", tostring(n)))
	dHead.Text = ui("BookTraits")
	dDesc.Text = text
	backBtn.Text = ui("BookBack")
end

openDetail = function(key: string)
	if (readBook()[key] or 0) <= 0 then
		return -- ยังไม่เจอ: ดูลักษณะไม่ได้
	end
	closeDetail()
	detailKey = key
	detailVF = BookPortrait.Mount(detailPic, key, 4)
	fillDetail()
	detail.Visible = true
end

-- หน้าลักษณะ: กล้องส่ายช้าๆ รอบฉาก ให้รูปดูมีชีวิต
RunService.RenderStepped:Connect(function()
	local vf = detailVF
	if vf and detail.Visible and panel.Visible then
		BookPortrait.Frame(vf, math.sin(os.clock() * 0.45) * 28)
	end
end)

-- วาดรูปการ์ด: เปลี่ยนเฉพาะตอนสถานะเปลี่ยน (เจอแล้ว / ยังไม่เจอ) ไม่สร้างใหม่ทุกครั้ง
local function drawPic(card: Card, key: string, found: boolean)
	local want = if found then "found" else "unknown"
	if card.shown == want then
		return
	end
	for _, c in ipairs(card.pic:GetChildren()) do
		if not c:IsA("UICorner") then
			c:Destroy()
		end
	end
	if found then
		BookPortrait.Mount(card.pic, key)
	else
		mountUnknown(card.pic)
	end
	card.shown = want
end

local function refresh()
	local book = readBook()
	local l = lang()
	local found = 0
	for _, key in ipairs(LanguageModule.BookOrder) do
		local n = book[key] or 0
		local card = cards[key]
		local title = LanguageModule.GetBook(key, l)
		card.name.Text = title
		local isFound = n > 0
		if isFound then
			found += 1
		end
		-- รูปสร้างตอนเปิดสมุดครั้งแรก (ไม่โหลดโมเดลตั้งแต่เข้าเกม)
		if panel.Visible then
			drawPic(card, key, isFound)
		end
		card.frame.BackgroundColor3 = if isFound then C.Card else C.CardLocked
		card.name.TextColor3 = if isFound then C.Cream else C.Dim
		;(card.frame:FindFirstChild("Stroke") :: UIStroke).Color = if isFound then C.Blood else C.Line
		card.btn.Active = isFound
		card.btn.Text = if isFound then ui("BookDetails") else ui("BookNotFound")
		card.btn.TextColor3 = if isFound then C.Cream else C.Faint
		card.btn.BackgroundColor3 = if isFound then C.Bar else C.CardLocked
	end
	local endingFound = 0
	for i, key in ipairs(LanguageModule.EndingOrder) do
		local n = book[key] or 0
		local ec = endingCards[key]
		local labelText, titleText, epilogueText, hintText = LanguageModule.GetEnding(key, l)
		local accent = ENDING_ACCENT[key] or C.Ember
		local unlocked = n > 0
		if unlocked then
			endingFound += 1
		end
		ec.frame.BackgroundColor3 = if unlocked then C.Card else C.CardLocked
		ec.stroke.Color = if unlocked then accent else C.Line
		ec.stroke.Transparency = if unlocked then 0.35 else 0.3
		ec.stripe.BackgroundColor3 = if unlocked then accent else C.Faint
		ec.tag.Text = LanguageModule.FormatEndingNumber(key, l) .. "  ·  " .. labelText
		ec.tag.TextColor3 = if unlocked then accent else C.Faint
		ec.status.Text = if unlocked then (string.gsub(ui("BookEndingSeen"), "{n}", tostring(n))) else ui("BookEndingLocked")
		ec.status.TextColor3 = if unlocked then C.Dim else C.Faint
		ec.title.Text = if unlocked then titleText else ui("BookLockedName")
		ec.title.TextColor3 = if unlocked then C.Cream else C.Dim
		ec.body.Text = if unlocked then epilogueText else hintText
		ec.body.TextColor3 = if unlocked then C.Cream else C.Faint
	end
	local totalGhosts = #LanguageModule.BookOrder
	local totalEndings = #LanguageModule.EndingOrder
	tabGhostsBtn.Text = (string.gsub(string.gsub(ui("BookTabGhosts"), "{n}", tostring(found)), "{total}", tostring(totalGhosts)))
	tabEndingsBtn.Text = (string.gsub(string.gsub(ui("BookTabEndings"), "{n}", tostring(endingFound)), "{total}", tostring(totalEndings)))
	local onGhosts = activeTab == "ghosts"
	list.Visible = onGhosts
	pager.Visible = onGhosts
	endingsList.Visible = not onGhosts
	for _, pair in ipairs({ { tabGhostsBtn, onGhosts }, { tabEndingsBtn, not onGhosts } }) do
		local b = pair[1] :: TextButton
		local on = pair[2] :: boolean
		b.BackgroundColor3 = if on then C.Bar else C.CardLocked
		b.TextColor3 = if on then C.Cream else C.Dim
		local st = b:FindFirstChild("Stroke") :: UIStroke?
		if st then
			st.Color = if on then C.Ember else C.Line
		end
	end
	if onGhosts then
		countLabel.Text = (string.gsub(string.gsub(ui("BookCount"), "{n}", tostring(found)), "{total}", tostring(totalGhosts)))
	else
		countLabel.Text = (string.gsub(string.gsub(ui("BookEndingCount"), "{n}", tostring(endingFound)), "{total}", tostring(totalEndings)))
	end
	header.Text = ui("BookTitle")
	bookBtnText.Text = ui("BookButton")
	fillDetail()
end
tabGhostsBtn.Activated:Connect(function()
	if activeTab ~= "ghosts" then
		activeTab = "ghosts"
		closeDetail()
		refresh()
	end
end)
tabEndingsBtn.Activated:Connect(function()
	if activeTab ~= "endings" then
		activeTab = "endings"
		closeDetail()
		refresh()
	end
end)
refresh()
localPlayer:GetAttributeChangedSignal("Book"):Connect(refresh)
localPlayer:GetAttributeChangedSignal("Lang"):Connect(refresh)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if panel.Visible then
		refresh()
	else
		closeDetail()
	end
end)


-- ---------------------------------------------------------------- เปิด / ปิด
local hasNew = false
local function setOpen(open: boolean)
	panel.Visible = open
	if open then
		hasNew = false
		refresh()
	end
	bookBtn.BackgroundColor3 = if open then BTN_HOT else BTN_IDLE
end
bookBtn.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)
bookBtn.MouseEnter:Connect(function()
	bookBtn.BackgroundColor3 = BTN_HOT
end)
bookBtn.MouseLeave:Connect(function()
	bookBtn.BackgroundColor3 = if panel.Visible then BTN_HOT else BTN_IDLE
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
	if string.sub(key, 1, 7) == "Ending_" then
		local _, endTitle = LanguageModule.GetEnding(key, lang())
		toastText.Text = ui("BookEndingNew") .. ":  " .. endTitle
	else
		local title = LanguageModule.GetBook(key, lang())
		toastText.Text = ui("BookNew") .. ":  " .. title
	end
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
			bookBtn.BackgroundColor3 = BTN_IDLE
			task.wait(0.6)
		end
	end)
end)
