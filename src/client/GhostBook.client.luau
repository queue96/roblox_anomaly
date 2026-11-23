--!strict
-- GhostBook.client.luau — สมุดหมอผี (Game Pass 499): ปุ่ม "สมุดหมอผี" ซ้ายปุ่มตั้งค่า มุมขวาบน (เฉพาะคนที่มี Pass)
--   คอมกด F2 ได้ด้วย (ยกเว้น admin ที่ F2 เป็นแผง admin อยู่แล้ว)
--   หน้าสมุด: ลูกค้าผี / ผีใหญ่ / ผีวนรอบร้าน / ผีฉาก · กดแล้วถาม server (server/GhostBook) ก่อนทุกครั้ง
--   ผีฉากเห็นคนเดียว: server ตอบตกลงแล้วเครื่องนี้ตั้ง SceneryTest / ScarecrowTest เอง (client/SceneryGhosts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fn = remotes:WaitForChild("GhostBook", 30) :: RemoteFunction?
if not fn then
	return
end
local bookFn = fn :: RemoteFunction

local function lang(): string
	return LanguageModule.Normalize(player:GetAttribute("Lang") :: string?)
end
local function ui(key: string): string
	return LanguageModule.GetUI(key, lang())
end

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(20, 16, 14),
	Card = Color3.fromRGB(34, 26, 22),
	CardHover = Color3.fromRGB(70, 28, 22),
	Line = Color3.fromRGB(90, 60, 40),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(165, 156, 136),
	Gold = Color3.fromRGB(214, 170, 60),
	Blood = Color3.fromRGB(170, 26, 22),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local gui = new("ScreenGui", {
	Name = "GhostBookGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 7,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
pcall(function()
	require(Shared:WaitForChild("UiFit", 5)).Attach(gui)
end)

-- ---------------------------------------------------------------- ปุ่มเปิด (ซ้ายปุ่มตั้งค่า)
local openBtn = new("TextButton", {
	Name = "GhostBookButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -150, 0, 14),
	Size = UDim2.new(0, 0, 0, 24),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(40, 14, 12),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	FontFace = FONT,
	TextSize = 13,
	TextColor3 = C.Gold,
	AutoButtonColor = false,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, openBtn)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, openBtn)
new("UIStroke", { Color = C.Gold, Thickness = 1, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, openBtn)
task.spawn(function()
	local sg = player.PlayerGui:WaitForChild("SettingsGui", 20)
	local sb = sg and sg:WaitForChild("SettingsButton", 20) :: GuiObject?
	if not sb then
		return
	end
	local function place()
		local us = gui:FindFirstChildOfClass("UIScale")
		local k = if us and us.Scale > 0 then us.Scale else 1
		local right = (gui.AbsoluteSize.X - sb.AbsolutePosition.X) / k + 10
		openBtn.Position = UDim2.new(1, -right, 0, 14)
	end
	place()
	sb:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	sb:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
end)

-- ---------------------------------------------------------------- หน้าสมุด
local panel = new("Frame", {
	Name = "Book",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.85), -- จอมือถือเตี้ย: ย่อตามจอ / จอใหญ่ไม่เกิน 560x430
	BackgroundColor3 = C.Panel,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, panel)
new("UIStroke", { Color = C.Gold, Thickness = 2, Transparency = 0.2 }, panel)
new("UISizeConstraint", { MaxSize = Vector2.new(560, 430) }, panel)
local title = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -60, 0, 28),
	FontFace = FONT,
	TextSize = 22,
	TextColor3 = C.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local hint = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 36),
	Size = UDim2.new(1, -32, 0, 18),
	FontFace = FONT,
	TextSize = 12,
	TextColor3 = C.Dim,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, panel)
local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(30, 26),
	BackgroundColor3 = C.Card,
	BorderSizePixel = 0,
	FontFace = FONT,
	TextSize = 16,
	TextColor3 = C.Cream,
	Text = "X",
	AutoButtonColor = false,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, closeBtn)
local status = new("TextLabel", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -6),
	Size = UDim2.new(1, -32, 0, 20),
	FontFace = FONT,
	TextSize = 13,
	TextColor3 = C.Cream,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, panel)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 60),
	Size = UDim2.new(1, -24, 1, -90),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.Line,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local busy = false
local statusToken = 0
local function setStatus(text: string, color: Color3?)
	statusToken += 1
	local my = statusToken
	status.Text = text
	status.TextColor3 = color or C.Cream
	task.delay(4, function()
		if statusToken == my then
			status.Text = ""
		end
	end)
end

local function setOpen(on: boolean)
	panel.Visible = on
end

local function summon(kind: string, arg: string)
	if busy then
		return
	end
	busy = true
	local ok, okRes, reason, secs = pcall(function()
		return bookFn:InvokeServer(kind, arg)
	end)
	busy = false
	if not ok then
		return
	end
	if okRes then
		if kind == "scenery" then
			if arg == "ScarecrowClose" then
				player:SetAttribute("ScarecrowTest", "close:" .. os.clock())
			else
				player:SetAttribute("SceneryTest", arg .. ":" .. os.clock())
			end
		end
		setOpen(false)
	elseif type(reason) == "string" then
		local text = ui(reason)
		if type(secs) == "number" then
			text = string.gsub(text, "{sec}", tostring(secs))
		end
		setStatus(text, C.Blood)
	end
end

local order = 0
local function header(key: string)
	order += 1
	new("TextLabel", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 22),
		FontFace = FONT,
		TextSize = 15,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = ui(key),
	}, list)
end
local function grid(): Frame
	order += 1
	local g = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, list)
	new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, g)
	return g
end
local function button(parent: Instance, text: string, kind: string, arg: string)
	local b = new("TextButton", {
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		FontFace = FONT,
		TextSize = 13,
		TextColor3 = C.Cream,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = text,
		AutoButtonColor = false,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, b)
	new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = C.CardHover
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = C.Card
	end)
	b.Activated:Connect(function()
		b.BackgroundColor3 = C.Blood
		TweenService:Create(b, TweenInfo.new(0.35), { BackgroundColor3 = C.Card }):Play()
		summon(kind, arg)
	end)
end

local function build()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
	openBtn.Text = "📖 " .. ui("GhostBookName")
	title.Text = "📖 " .. ui("GhostBookName")
	hint.Text = ui("GBook_Hint")
	header("GBook_Customer")
	local g = grid()
	for _, key in ipairs(LanguageModule.BookOrder) do
		if string.sub(key, 1, 8) == "Anomaly_" then
			local name = LanguageModule.GetBook(key, lang())
			button(g, name, "customer", key)
		end
	end
	header("GBook_Big")
	g = grid()
	for _, k in ipairs(IDS.BOOK_BIG) do
		local name = LanguageModule.GetBook("Big_" .. k, lang())
		button(g, name, "big", k)
	end
	header("GBook_Linger")
	g = grid()
	for _, k in ipairs(IDS.BOOK_LINGER) do
		button(g, ui("GB_" .. k), "linger", k)
	end
	header("GBook_Scenery")
	g = grid()
	for _, k in ipairs(IDS.BOOK_SCENERY) do
		button(g, ui("GB_" .. k), "scenery", k)
	end
	button(g, ui("GB_ScarecrowClose"), "scenery", "ScarecrowClose")
end
build()
player:GetAttributeChangedSignal("Lang"):Connect(build)

local function refreshOwned()
	local owned = player:GetAttribute("GhostBook") == true
	openBtn.Visible = owned
	if not owned then
		setOpen(false)
	end
end
player:GetAttributeChangedSignal("GhostBook"):Connect(refreshOwned)
refreshOwned()

openBtn.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.F2 then
		return
	end
	-- admin ใช้ F2 เปิดแผง admin อยู่แล้ว: ใช้ปุ่มบนจอแทน
	if player:GetAttribute("Admin") == true or player:GetAttribute("GhostBook") ~= true then
		return
	end
	setOpen(not panel.Visible)
end)
