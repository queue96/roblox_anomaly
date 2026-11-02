--!nonstrict
-- ItemSlots.client.luau
-- ช่องของถัดจากช่องไฟฉาย [1] (HUDController): [2] ขนมไทย (ถวายศาลพระภูมิ) / [3] แกลลอนน้ำมัน (ว่าง/เต็ม)
-- กดเลข / แตะช่องเพื่อถือ-เก็บ  ช่องโผล่เฉพาะตอนมีของ  (Tool สร้างฝั่ง Server ใน CoreLoop)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local function ui(key: string): string
	return LanguageModule.GetUI(key, player:GetAttribute("Lang") or player.LocaleId)
end

local C = {
	Ink = Color3.fromRGB(14, 13, 11),
	Badge = Color3.fromRGB(26, 24, 20),
	Line = Color3.fromRGB(70, 64, 54),
	LineHot = Color3.fromRGB(185, 140, 88),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(196, 188, 168),
	Ember = Color3.fromRGB(230, 120, 50),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local gui = Instance.new("ScreenGui")
gui.Name = "ItemSlots"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.AutoLocalize = false
gui.Parent = player:WaitForChild("PlayerGui")

-- อยู่ขวาของช่องไฟฉาย (ช่องไฟฉายกึ่งกลางจอล่าง กว้างราว 130)
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0, 1)
bar.Position = UDim2.new(0.5, 74, 1, -14)
bar.Size = UDim2.fromOffset(0, 26)
bar.AutomaticSize = Enum.AutomaticSize.X
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar

type Slot = { tool: string, key: Enum.KeyCode, num: string, label: string, button: TextButton, text: TextLabel, badge: TextLabel, stroke: UIStroke }
local slots: { Slot } = {}

local function makeSlot(order: number, num: string, tool: string, key: Enum.KeyCode, label: string): Slot
	local b = Instance.new("TextButton")
	b.Name = tool .. "Slot"
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(0, 26)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.BackgroundColor3 = C.Ink
	b.BackgroundTransparency = 0.2
	b.BorderSizePixel = 0
	b.Text = ""
	b.AutoButtonColor = false
	b.Visible = false
	b.Parent = bar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
	local pad = Instance.new("UIPadding", b)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10)
	local l = Instance.new("UIListLayout", b)
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 7)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	local st = Instance.new("UIStroke", b)
	st.Color = C.Line
	st.Transparency = 0.2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = C.Badge
	badge.Size = UDim2.fromOffset(16, 16)
	badge.FontFace = FONT
	badge.TextColor3 = C.Dim
	badge.TextSize = 11
	badge.Text = num
	badge.LayoutOrder = 1
	badge.Parent = b
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 2)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromOffset(0, 20)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.FontFace = FONT
	t.TextColor3 = C.Dim
	t.TextSize = 13
	t.LayoutOrder = 2
	t.Parent = b
	local s: Slot = { tool = tool, key = key, num = num, label = label, button = b, text = t, badge = badge, stroke = st }
	table.insert(slots, s)
	return s
end

makeSlot(2, "2", "ThaiDessert", Enum.KeyCode.Two, "DessertSlot")
makeSlot(3, "3", "FuelCan", Enum.KeyCode.Three, "CanSlot")

local function find(name: string): (Tool?, boolean)
	local char = player.Character
	local t = char and char:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t, true
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil, false
end

local function refresh()
	local show = player:GetAttribute("ShowHUD") ~= false
	for _, s in ipairs(slots) do
		local tool, equipped = find(s.tool)
		s.button.Visible = tool ~= nil and show
		local txt = ui(s.label)
		if s.tool == "FuelCan" and tool then
			txt ..= " " .. ui(if tool:GetAttribute("Full") then "CanFull" else "CanEmpty")
		end
		s.text.Text = txt
		s.stroke.Color = if equipped then C.LineHot else C.Line
		s.text.TextColor3 = if equipped then C.Cream else C.Dim
		s.badge.TextColor3 = if equipped then C.Cream else C.Dim
	end
end

local function toggle(s: Slot)
	if player:GetAttribute("Praying") == true then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local tool, equipped = find(s.tool)
	if not tool then
		return
	end
	if equipped then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
	task.defer(refresh)
end

for _, s in ipairs(slots) do
	s.button.Activated:Connect(function()
		toggle(s)
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for _, s in ipairs(slots) do
		if input.KeyCode == s.key then
			toggle(s)
		end
	end
end)

-- ---------------------------------------------------------------- นับถอยหลังศาลพระภูมิ (มุมขวาบน ใต้ปุ่มตั้งค่า)
-- บอกว่าศาลคุ้มครองอีกนานแค่ไหน จะได้วางแผนไปถวายขนมทัน: ปกติสีครีม / ใกล้หมดสีส้มกะพริบ / หมดแล้วสีแดง
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shrine = Instance.new("Frame")
shrine.Name = "ShrineTimer"
shrine.AnchorPoint = Vector2.new(1, 0)
shrine.Position = UDim2.new(1, -16, 0, 50)
shrine.Size = UDim2.fromOffset(176, 40)
shrine.BackgroundColor3 = C.Ink
shrine.BackgroundTransparency = 0.2
shrine.BorderSizePixel = 0
shrine.Visible = false
shrine.Parent = gui
Instance.new("UICorner", shrine).CornerRadius = UDim.new(0, 3)
local shrineStroke = Instance.new("UIStroke", shrine)
shrineStroke.Color = C.Line
shrineStroke.Transparency = 0.2
shrineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local shrineTitle = Instance.new("TextLabel")
shrineTitle.BackgroundTransparency = 1
shrineTitle.Position = UDim2.fromOffset(10, 3)
shrineTitle.Size = UDim2.new(1, -20, 0, 16)
shrineTitle.FontFace = FONT
shrineTitle.TextSize = 12
shrineTitle.TextColor3 = C.Dim
shrineTitle.TextXAlignment = Enum.TextXAlignment.Left
shrineTitle.Parent = shrine
local shrineTime = Instance.new("TextLabel")
shrineTime.BackgroundTransparency = 1
shrineTime.Position = UDim2.fromOffset(10, 3)
shrineTime.Size = UDim2.new(1, -20, 0, 16)
shrineTime.FontFace = FONT
shrineTime.TextSize = 14
shrineTime.TextColor3 = C.Cream
shrineTime.TextXAlignment = Enum.TextXAlignment.Right
shrineTime.Parent = shrine
local shrineBarBg = Instance.new("Frame")
shrineBarBg.Position = UDim2.new(0, 10, 0, 25)
shrineBarBg.Size = UDim2.new(1, -20, 0, 6)
shrineBarBg.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
shrineBarBg.BorderSizePixel = 0
shrineBarBg.Parent = shrine
Instance.new("UIStroke", shrineBarBg).Color = C.Line
local shrineBar = Instance.new("Frame")
shrineBar.Size = UDim2.fromScale(1, 1)
shrineBar.BackgroundColor3 = C.Cream
shrineBar.BorderSizePixel = 0
shrineBar.Parent = shrineBarBg

local BLOOD = Color3.fromRGB(205, 36, 28)
local blink = false
local function refreshShrine()
	local left = remotes:GetAttribute("OfferingLeft")
	local total = remotes:GetAttribute("OfferingTotal")
	local show = type(left) == "number" and left >= 0 and player:GetAttribute("ShowHUD") ~= false
	shrine.Visible = show
	if not show then
		return
	end
	total = if type(total) == "number" and total > 0 then total else 150
	blink = not blink
	if left <= 0 then
		shrineTitle.Text = "🕯 " .. ui("ShrineTimerCursed")
		shrineTime.Text = ""
		shrineBar.Size = UDim2.fromScale(0, 1)
		shrineStroke.Color = if blink then BLOOD else C.Line
		shrineTitle.TextColor3 = BLOOD
		return
	end
	local warn = left <= 25
	shrineTitle.Text = "🕯 " .. ui(if warn then "ShrineTimerSoon" else "ShrineTimer")
	shrineTime.Text = string.format("%d:%02d", left // 60, left % 60)
	shrineBar.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
	shrineBar.BackgroundColor3 = if warn then C.Ember else C.Cream
	shrineTime.TextColor3 = if warn then C.Ember else C.Cream
	shrineTitle.TextColor3 = if warn then C.Ember else C.Dim
	shrineStroke.Color = if warn and blink then C.Ember else C.Line
end
remotes:GetAttributeChangedSignal("OfferingLeft"):Connect(refreshShrine)
player:GetAttributeChangedSignal("ShowHUD"):Connect(refreshShrine)
player:GetAttributeChangedSignal("Lang"):Connect(refreshShrine)
refreshShrine()

-- ติดตามของในกระเป๋า/มือ (หยิบ ถวาย เติม/เทแกลลอน)
local watched: { [Instance]: RBXScriptConnection } = {}
local function watch(container: Instance?)
	if not container or watched[container] then
		return
	end
	watched[container] = container.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			c:GetAttributeChangedSignal("Full"):Connect(refresh)
		end
		refresh()
	end)
	container.ChildRemoved:Connect(refresh)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Tool") then
			c:GetAttributeChangedSignal("Full"):Connect(refresh)
		end
	end
end
local function onChar(char: Model)
	watch(char)
	watch(player:WaitForChild("Backpack", 10))
	refresh()
end
if player.Character then
	onChar(player.Character)
end
player.CharacterAdded:Connect(onChar)
player:GetAttributeChangedSignal("ShowHUD"):Connect(refresh)
player:GetAttributeChangedSignal("Lang"):Connect(refresh)
task.spawn(function()
	while true do
		task.wait(1)
		refresh()
	end
end)
