--!strict
-- ShopMenu.client.luau — Lobby: ปุ่ม SHOP ซ้ายจอ + หน้าต่างร้านค้า (ผู้ใช้ 2026-11-23: แบบเกมสยองทั่วไป ไม่ต้องหรูมาก)
--   แท็บเกมพาส: ของทุกชิ้นใน shared/RobuxShop.SHOP_PASSES (ราคาจริงอ่านจาก Roblox) · มีแล้ว = ปุ่ม "มีแล้ว ✓"
--   แท็บทำบุญ: ยอด Robux ใน shared/RobuxShop.DONATE_PRODUCTS (ใบเสร็จ: lobby/server/TempleMerit)
--   กดที่ตู้ร่วมทำบุญ = เปิดหน้าต่างนี้ที่แท็บทำบุญ (TempleRemotes.OpenDonate)
--   ข้อความตามภาษาผู้เล่น (attribute Lang) เปลี่ยนตามทันที
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any

local player = Players.LocalPlayer
local ROBUX = utf8.char(0xE002)

local C = {
	Bg = Color3.fromRGB(14, 12, 12),
	Card = Color3.fromRGB(22, 20, 20),
	Line = Color3.fromRGB(150, 146, 140),
	Text = Color3.fromRGB(236, 232, 226),
	Dim = Color3.fromRGB(160, 154, 148),
	Btn = Color3.fromRGB(40, 38, 38),
	Gold = Color3.fromRGB(232, 190, 92),
	Red = Color3.fromRGB(176, 24, 28),
	Green = Color3.fromRGB(70, 140, 90),
}
local HORROR = Font.new("rbxasset://fonts/families/Creepster.json")
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

local function lang(): string
	return LanguageModule.Normalize((player:GetAttribute("Lang") :: string?) or player.LocaleId)
end
local function T(key: string): string
	return LanguageModule.GetUI(key, lang())
end

local function new(cls: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local function corner(o: Instance, px: number)
	new("UICorner", { CornerRadius = UDim.new(0, px) }, o)
end
local function stroke(o: Instance, color: Color3, th: number, tr: number?)
	new("UIStroke", { Color = color, Thickness = th, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

-- ข้อความที่ต้องเปลี่ยนตามภาษา: { label, key }
local localized: { { any } } = {}
local function loc(label: any, key: string)
	table.insert(localized, { label, key })
	label.Text = T(key)
end

local gui = new("ScreenGui", {
	Name = "ShopMenuGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 6,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
do
	local fit = Shared:FindFirstChild("UiFit")
	if fit then
		(require(fit) :: any).Attach(gui)
	end
end

-- ---------------------------------------------------------------- ปุ่ม SHOP ซ้ายจอ
local TOUCH = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local BTN = if TOUCH then 70 else 78
local shopBtn = new("TextButton", {
	Name = "ShopButton",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.42, 0),
	Size = UDim2.fromOffset(BTN, BTN),
	BackgroundColor3 = C.Bg,
	BackgroundTransparency = 0.12,
	Text = "",
	AutoButtonColor = true,
}, gui)
corner(shopBtn, 12)
stroke(shopBtn, C.Line, 2.5, 0.1)
new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0.62, 0),
	Position = UDim2.fromScale(0, 0.04),
	Text = "🏮",
	TextScaled = true,
	FontFace = BODY,
	TextColor3 = C.Text,
}, shopBtn)
new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0.3, 0),
	Position = UDim2.fromScale(0, 0.66),
	Text = "SHOP",
	TextScaled = true,
	FontFace = HORROR,
	TextColor3 = C.Text,
}, shopBtn)

-- ---------------------------------------------------------------- หน้าต่าง
local W, H = 640, 470
local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 5 }, gui)
local win = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H),
	BackgroundColor3 = C.Bg,
	ZIndex = 6,
}, dim)
corner(win, 10)
stroke(win, C.Line, 3, 0.05)
new("UISizeConstraint", { MaxSize = Vector2.new(W, H) }, win)
do -- พอดีจอมือถือเล็ก: ย่อทั้งหน้าต่างถ้าจอแคบ
	local sc = new("UIScale", {}, win)
	local function fitWin()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local guiScale = 1
		local ui = gui:FindFirstChildOfClass("UIScale")
		if ui then
			guiScale = ui.Scale
		end
		local vp = cam.ViewportSize / guiScale
		sc.Scale = math.min(1, (vp.X - 24) / W, (vp.Y - 24) / H)
	end
	fitWin()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWin)
	end
end

new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(24, 10),
	Size = UDim2.new(0, 220, 0, 56),
	Text = "SHOP",
	FontFace = HORROR,
	TextSize = 52,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.Text,
	ZIndex = 7,
}, win)
local subTitle = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(150, 26),
	Size = UDim2.new(0, 200, 0, 30),
	FontFace = BOLD,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.Dim,
	ZIndex = 7,
}, win)
loc(subTitle, "ShopTitle")
local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(48, 48),
	BackgroundColor3 = C.Red,
	Text = "X",
	FontFace = BOLD,
	TextSize = 30,
	TextColor3 = Color3.new(1, 1, 1),
	ZIndex = 7,
}, win)
corner(closeBtn, 6)
stroke(closeBtn, Color3.fromRGB(90, 10, 12), 2)

-- แท็บ
local tabs = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 74), Size = UDim2.new(1, -48, 0, 40), ZIndex = 7 }, win)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10) }, tabs)
local function tabButton(key: string): any
	local b = new("TextButton", { Size = UDim2.fromOffset(170, 40), BackgroundColor3 = C.Btn, FontFace = BOLD, TextSize = 19, TextColor3 = C.Text, ZIndex = 7 }, tabs)
	corner(b, 8)
	stroke(b, C.Line, 1.5, 0.4)
	loc(b, key)
	return b
end
local tabPass = tabButton("ShopTabPasses")
local tabDonate = tabButton("ShopTabDonate")

local body = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 126), Size = UDim2.new(1, -48, 1, -146), ZIndex = 7 }, win)

-- ---------------------------------------------------------------- แท็บเกมพาส
local passList = new("ScrollingFrame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = C.Line,
	BorderSizePixel = 0,
	ZIndex = 7,
}, body)
new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, passList)
new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, passList)

type Row = { item: any, price: number, btn: any }
local rows: { Row } = {}
local function refreshRow(r: Row)
	local owned = player:GetAttribute(r.item.attr) == true
	r.btn.Text = if owned then T("Shop_OwnedShort") else ROBUX .. " " .. tostring(r.price)
	r.btn.BackgroundColor3 = if owned then C.Green else C.Btn
	r.btn.AutoButtonColor = not owned
end

for i, item in ipairs(IDS.SHOP_PASSES) do
	local card = new("Frame", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = C.Card, ZIndex = 7 }, passList)
	corner(card, 8)
	stroke(card, C.Line, 2, 0.25)
	local iconTile = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(80, 80), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 8 }, card)
	corner(iconTile, 6)
	-- emoji ขนาดคงที่ให้เต็มช่องพอดี (TextScaled กับ emoji เล็ก/ใหญ่ไม่เท่ากันแต่ละตัว)
	new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = item.icon, TextSize = 54, FontFace = BODY, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 9 }, iconTile)
	local nm = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(104, 12),
		Size = UDim2.new(1, -250, 0, 34),
		FontFace = BOLD,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = C.Text,
		ZIndex = 8,
	}, card)
	loc(nm, item.name)
	local ds = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(104, 48),
		Size = UDim2.new(1, -250, 0, 42),
		FontFace = BODY,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = C.Dim,
		ZIndex = 8,
	}, card)
	loc(ds, item.desc)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(124, 56),
		BackgroundColor3 = C.Btn,
		FontFace = BOLD,
		TextSize = 24,
		TextColor3 = C.Text,
		ZIndex = 8,
	}, card)
	corner(btn, 8)
	stroke(btn, C.Line, 1.5, 0.5)
	local r: Row = { item = item, price = item.price, btn = btn }
	table.insert(rows, r)
	refreshRow(r)
	player:GetAttributeChangedSignal(item.attr):Connect(function()
		refreshRow(r)
	end)
	btn.Activated:Connect(function()
		if player:GetAttribute(item.attr) == true or item.id == 0 then
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	end)
	-- ราคาจริงจาก Roblox (เปลี่ยนราคาใน Creator Hub แล้วตามเอง)
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.id, Enum.InfoType.GamePass)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			r.price = info.PriceInRobux
			refreshRow(r)
		end
	end)
end

-- ---------------------------------------------------------------- แท็บทำบุญ
local donate = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 7 }, body)
local dHead = new("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 0, 40),
	FontFace = BOLD,
	TextSize = 28,
	TextColor3 = C.Gold,
	ZIndex = 8,
}, donate)
loc(dHead, "DonateHead")
local dDesc = new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 44),
	Size = UDim2.new(1, -40, 0, 50),
	FontFace = BODY,
	TextSize = 18,
	TextWrapped = true,
	TextColor3 = C.Dim,
	ZIndex = 8,
}, donate)
loc(dDesc, "DonateDesc")
local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 1, -112), ZIndex = 8 }, donate)
new("UIGridLayout", {
	CellSize = UDim2.new(0.5, -8, 0, 86),
	CellPadding = UDim2.fromOffset(16, 16),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
for i, d in ipairs(IDS.DONATE_PRODUCTS) do
	local b = new("TextButton", {
		LayoutOrder = i,
		BackgroundColor3 = C.Card,
		Text = "🙏  " .. ROBUX .. " " .. tostring(d.amount),
		FontFace = BOLD,
		TextSize = 30,
		TextColor3 = C.Gold,
		AutoButtonColor = true,
		ZIndex = 9,
	}, grid)
	corner(b, 8)
	stroke(b, C.Gold, 2, 0.35)
	b.Activated:Connect(function()
		if d.id == 0 then
			warn("[ShopMenu] ยังไม่ได้ใส่รหัสสินค้าทำบุญ " .. d.amount .. " ใน shared/RobuxShop.DONATE_PRODUCTS")
			return
		end
		MarketplaceService:PromptProductPurchase(player, d.id)
	end)
end

-- ---------------------------------------------------------------- เปิด / ปิด / สลับแท็บ
local function showTab(which: string)
	passList.Visible = which == "pass"
	donate.Visible = which == "donate"
	tabPass.BackgroundColor3 = if which == "pass" then C.Red else C.Btn
	tabDonate.BackgroundColor3 = if which == "donate" then C.Red else C.Btn
end
local function open(which: string)
	showTab(which)
	dim.Visible = true
	win.Position = UDim2.fromScale(0.5, 0.53)
	TweenService:Create(win, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
end
local function close()
	dim.Visible = false
end
shopBtn.Activated:Connect(function()
	if dim.Visible then
		close()
	else
		open("pass")
	end
end)
closeBtn.Activated:Connect(close)
tabPass.Activated:Connect(function()
	showTab("pass")
end)
tabDonate.Activated:Connect(function()
	showTab("donate")
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and dim.Visible then
		close()
	end
end)
showTab("pass")

-- กดที่ตู้ร่วมทำบุญ
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("TempleRemotes", 30)
	local ev = remotes and remotes:WaitForChild("OpenDonate", 10)
	if ev and ev:IsA("RemoteEvent") then
		ev.OnClientEvent:Connect(function()
			open("donate")
		end)
	end
end)

-- เปลี่ยนภาษา
player:GetAttributeChangedSignal("Lang"):Connect(function()
	for _, pair in ipairs(localized) do
		pair[1].Text = T(pair[2])
	end
	for _, r in ipairs(rows) do
		refreshRow(r)
	end
end)
