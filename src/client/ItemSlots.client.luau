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

-- แถบช่องของกลางจอล่าง: ไฟฉาย [1] (ช่องของ HUDController ย้ายมาอยู่แถบนี้) + ขนม [2] + แกลลอน [3]
-- ช่องที่ไม่มีของซ่อน (ไม่กินที่) แถบจึงอยู่กลางจอเสมอไม่ว่าจะมีกี่ชิ้น · ทุกช่องมีรูปโมเดลจริง (shared/ModelIcon)
local SLOT_H = 46
local ICON = 40
local ModelIcon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelIcon"))
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -12)
bar.Size = UDim2.fromOffset(0, SLOT_H)
bar.AutomaticSize = Enum.AutomaticSize.X
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = bar
-- จอเตี้ย (โน้ตบุ๊ก 14 นิ้ว) ย่อแถบช่องของ + เวลาศาลตามความสูงจอ (shared/UiFit ค่าเดียวกันทุกกล่อง)
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiFit")).Attach(gui)

-- รูปของในช่อง (ใส่ไว้หน้าป้ายเลข)
local function slotIcon(parent: Instance): ViewportFrame
	local well = Instance.new("Frame")
	well.Name = "IconWell"
	well.LayoutOrder = 0
	well.Size = UDim2.fromOffset(ICON, ICON)
	well.BackgroundColor3 = Color3.fromRGB(30, 28, 24)
	well.BorderSizePixel = 0
	well.Parent = parent
	Instance.new("UICorner", well).CornerRadius = UDim.new(0, 3)
	local vf = ModelIcon.Make(UDim2.fromScale(1, 1))
	vf.Parent = well
	return vf
end
local iconOf: { [Instance]: string } = {} -- ViewportFrame -> ของที่วาดอยู่ (ชื่อ + สภาพเต็ม/เปล่า)
local function setSlotIcon(vf: ViewportFrame, tool: Instance?)
	-- ถ่ายใหม่เมื่อของเปลี่ยนสภาพ (แกลลอนเปล่า/เต็ม สีต่างกัน)
	local key = tool and tool.Name .. tostring(tool:GetAttribute("Full"))
	if tool and iconOf[vf] ~= key then
		if ModelIcon.Set(vf, tool) then
			iconOf[vf] = key
		end
	end
end

-- ช่องไฟฉายของ HUDController: ย้ายเข้าแถบนี้ (ลำดับแรก) สูงเท่าช่องอื่น + รูปไฟฉาย
local flashIcon: ViewportFrame? = nil
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	local fs: Instance? = nil
	for _ = 1, 100 do
		fs = pg:FindFirstChild("FlashlightSlot", true)
		if fs then
			break
		end
		task.wait(0.1)
	end
	if fs and fs:IsA("GuiObject") then
		fs.Parent = bar
		fs.LayoutOrder = 1
		fs.Size = UDim2.new(0, 0, 0, SLOT_H)
		local p = fs:FindFirstChildOfClass("UIPadding")
		if p then
			p.PaddingLeft = UDim.new(0, 3)
		end
		-- ช่องไฟฉายกะทัดรัด: เอาป้ายเลขออก, หลอดถ่านไปอยู่ใต้คำว่า "ไฟฉาย" (ซ้อนกันแนวตั้ง)
		-- (HUDController ยังอ้างชิ้นเดิมอยู่: แค่ย้ายที่ ไม่สร้างใหม่)
		local stack = Instance.new("Frame")
		stack.Name = "TextStack"
		stack.LayoutOrder = 2
		stack.BackgroundTransparency = 1
		stack.Size = UDim2.fromOffset(0, SLOT_H - 8)
		stack.AutomaticSize = Enum.AutomaticSize.X
		local sl = Instance.new("UIListLayout", stack)
		sl.FillDirection = Enum.FillDirection.Vertical
		sl.VerticalAlignment = Enum.VerticalAlignment.Center
		sl.Padding = UDim.new(0, 4)
		sl.SortOrder = Enum.SortOrder.LayoutOrder
		for _, d in ipairs(fs:GetChildren()) do
			if d:IsA("TextLabel") then
				if d.Text == "1" then
					d.Visible = false -- ป้ายเลข [1]
				else
					d.TextSize = 15
					d.Size = UDim2.new(0, 0, 0, 18)
					d.LayoutOrder = 1
					d.Parent = stack
				end
			elseif d:IsA("Frame") and d.Name ~= "IconWell" and d:FindFirstChildWhichIsA("Frame") then
				-- หลอดถ่าน (Frame ที่มีแถบเติมข้างใน)
				d.Size = UDim2.fromOffset(50, 6)
				d.LayoutOrder = 2
				d.Parent = stack
			end
		end
		stack.Parent = fs
		flashIcon = slotIcon(fs)
	end
end)

type Slot = { tool: string, key: Enum.KeyCode, num: string, label: string, button: TextButton, text: TextLabel, badge: TextLabel, stroke: UIStroke, icon: ViewportFrame }
local slots: { Slot } = {}

local function makeSlot(order: number, num: string, tool: string, key: Enum.KeyCode, label: string): Slot
	local b = Instance.new("TextButton")
	b.Name = tool .. "Slot"
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(0, SLOT_H)
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
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 3), UDim.new(0, 10)
	local l = Instance.new("UIListLayout", b)
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 5)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	local st = Instance.new("UIStroke", b)
	st.Color = C.Line
	st.Transparency = 0.2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local badge = Instance.new("TextLabel")
	badge.BackgroundColor3 = C.Badge
	badge.Size = UDim2.fromOffset(20, 20)
	badge.FontFace = FONT
	badge.TextColor3 = C.Dim
	badge.TextSize = 13
	badge.Text = num
	badge.LayoutOrder = 1
	badge.Parent = b
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 2)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromOffset(0, 24)
	t.AutomaticSize = Enum.AutomaticSize.X
	t.FontFace = FONT
	t.TextColor3 = C.Dim
	t.TextSize = 15
	t.LayoutOrder = 2
	t.Parent = b
	local s: Slot = { tool = tool, key = key, num = num, label = label, button = b, text = t, badge = badge, stroke = st, icon = slotIcon(b) }
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
	if flashIcon then
		setSlotIcon(flashIcon, (find("FrogFlashlight")))
	end
	for _, s in ipairs(slots) do
		local tool, equipped = find(s.tool)
		s.button.Visible = tool ~= nil and show
		setSlotIcon(s.icon, tool)
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
	-- ล้มตาย/ล้มนอน (ตัวถูกยึด): หยิบของขึ้นมือไม่ได้ ไม่ให้กลับไปค้างท่าถือตอนนอน
	local root = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and root.Anchored and not hum.Sit and game:GetService("Lighting"):GetAttribute("Cutscene") ~= true then
		return
	end
	local tool, equipped = find(s.tool)
	if not tool then
		return
	end
	-- ย้าย Tool เข้า/ออกตัวเอง (ไม่ใช้ EquipTool ที่เก็บของอื่นทั้งหมด): ไฟฉายมือซ้ายถือค้างไว้ได้
	-- ของมือขวา (ขนมตาลบนใบตอง / แกลลอน) ถือได้ทีละอย่าง: หยิบอันใหม่ = เก็บอันเดิมเข้ากระเป๋า
	local bp = player:FindFirstChildOfClass("Backpack")
	if equipped then
		tool.Parent = bp
	else
		for _, other in ipairs(slots) do
			local t, held = find(other.tool)
			if t and held and t ~= tool then
				t.Parent = bp
			end
		end
		tool.Parent = player.Character
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
-- รูปซ้าย = ตัวศาลพระภูมิจริง (เฉพาะตัวเรือน ไม่เอาเสา/ฐาน)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local shrine = Instance.new("Frame")
shrine.Name = "ShrineTimer"
shrine.AnchorPoint = Vector2.new(1, 0)
shrine.Position = UDim2.new(1, -16, 0, 56)
shrine.Size = UDim2.fromOffset(240, 62)
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
shrineTitle.Position = UDim2.fromOffset(66, 8)
shrineTitle.Size = UDim2.new(1, -76, 0, 20)
shrineTitle.FontFace = FONT
shrineTitle.TextSize = 14
shrineTitle.TextColor3 = C.Dim
shrineTitle.TextXAlignment = Enum.TextXAlignment.Left
shrineTitle.Parent = shrine
local shrineTime = Instance.new("TextLabel")
shrineTime.BackgroundTransparency = 1
shrineTime.Position = UDim2.fromOffset(66, 8)
shrineTime.Size = UDim2.new(1, -76, 0, 20)
shrineTime.FontFace = FONT
shrineTime.TextSize = 18
shrineTime.TextColor3 = C.Cream
shrineTime.TextXAlignment = Enum.TextXAlignment.Right
shrineTime.Parent = shrine
local shrineBarBg = Instance.new("Frame")
shrineBarBg.Position = UDim2.new(0, 66, 0, 38)
shrineBarBg.Size = UDim2.new(1, -76, 0, 9)
shrineBarBg.BackgroundColor3 = Color3.fromRGB(26, 24, 20)
shrineBarBg.BorderSizePixel = 0
shrineBarBg.Parent = shrine
Instance.new("UIStroke", shrineBarBg).Color = C.Line
local shrineBar = Instance.new("Frame")
shrineBar.Size = UDim2.fromScale(1, 1)
shrineBar.BackgroundColor3 = C.Cream
shrineBar.BorderSizePixel = 0
shrineBar.Parent = shrineBarBg
-- รูปศาล: ถ่ายเฉพาะตัวเรือนด้านบน (ศาลเป็น mesh ชิ้นเดียวรวมเสา: เล็งกล้องไปที่ส่วนบน)
local shrineWell = Instance.new("Frame")
shrineWell.Position = UDim2.fromOffset(6, 6)
shrineWell.Size = UDim2.fromOffset(50, 50)
shrineWell.BackgroundColor3 = Color3.fromRGB(30, 28, 24)
shrineWell.BorderSizePixel = 0
shrineWell.Parent = shrine
Instance.new("UICorner", shrineWell).CornerRadius = UDim.new(0, 3)
local shrineIcon = ModelIcon.Make(UDim2.fromScale(1, 1))
shrineIcon.Parent = shrineWell
local shrineIconDone = false
local function setShrineIcon()
	if shrineIconDone then
		return
	end
	local sh = workspace:FindFirstChild("SpiritHouse")
	local body = sh and sh:FindFirstChild("SpiritHouseOnStilts")
	if body and body:IsA("BasePart") then
		-- ตัวเรือนอยู่ส่วนบนของ mesh (ฐาน+เสายาวลงล่าง) ด้านหน้าศาล = แกน (+X, -Z) ของชิ้น
		local top = body.Size.Y / 2
		shrineIconDone = ModelIcon.Set(shrineIcon, body, Vector3.new(0.75, 0.3, -0.75), { center = Vector3.new(0.8, top - 2.3, -0.2), radius = 2.4 })
	end
end

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
	setShrineIcon()
	shrineIcon.ImageColor3 = if left <= 0 then Color3.fromRGB(150, 90, 90) else Color3.new(1, 1, 1)
	if left <= 0 then
		shrineTitle.Text = ui("ShrineTimerCursed")
		shrineTime.Text = ""
		shrineBar.Size = UDim2.fromScale(0, 1)
		shrineStroke.Color = if blink then BLOOD else C.Line
		shrineTitle.TextColor3 = BLOOD
		return
	end
	local warn = left <= 25
	shrineTitle.Text = ui(if warn then "ShrineTimerSoon" else "ShrineTimer")
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
