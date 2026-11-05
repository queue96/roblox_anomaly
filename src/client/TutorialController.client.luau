--!nonstrict
-- TutorialController.client.luau
-- แผงมุมซ้ายกลางจอ ทำ 2 อย่างในแผงเดียว (เดิมแยกกล่องเตรียมร้านไว้กลางจอ ซ้ำซ้อน):
--   1) ช่วงเตรียมร้าน (ทุกคืน): ดึงเชือกเปิดร้านแล้ว "ลูกค้ามาใน 0:24" + รายการงาน (รูป + ข้อความ) ทำแล้วขึ้นสีเขียว
--      (server/CoreLoop: Remotes.PrepLeft / PrepOffered, ไฟ = ReplicatedStorage.PowerOn, น้ำมัน = PetrolLevel/DieselLevel)
--   2) สอนเล่น 6 เรื่อง ทีละเรื่อง "เมื่อเหตุการณ์นั้นมาถึงจริง" (ไม่สอนรวดเดียวตั้งแต่เริ่ม): ไฟฉาย · เปิดร้าน ·
--      เครื่องปั่นไฟ · เติมน้ำมัน (หยิบ/ตัก/เท บอกทีละขั้น) · ถวายขนม (เวลาคุ้มครองใกล้หมด) · ดูผี (ลูกค้าคนแรกมา)
--      ทำสำเร็จ -> จำว่าเรียนแล้ว (PlayerSettings.TutSeen ใน DataStore) ครั้งหน้าไม่สอนซ้ำ
--      แสดงทีละอย่าง: ระหว่างสอนไม่โชว์รายการเตรียมร้าน / ช่วงเตรียมร้านโชว์แค่งานถัดไปที่ยังไม่ทำ
--   รูปทั้งหมดเป็นโมเดล 3D จริงในฉาก (shared/ModelIcon) บางคนไม่อ่าน ดูแต่รูป
--   กด H (มือถือ: แตะกล่อง) ซ่อน/แสดง  ·  เรื่องที่ทำเสร็จไปก่อนแล้ว (เช่น เพื่อนเปิดร้านแล้ว) ไม่ต้องสอน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local ModelIcon = require(Shared:WaitForChild("ModelIcon"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ui(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize(player:GetAttribute("Lang") :: string?))
end

-- ธีมเดียวกับ HUD
local C = {
	Ink = Color3.fromRGB(14, 13, 11),
	Line = Color3.fromRGB(70, 64, 54),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(196, 188, 168),
	Ember = Color3.fromRGB(230, 120, 50),
	Gold = Color3.fromRGB(226, 186, 110),
	Done = Color3.fromRGB(120, 190, 110),
	Blood = Color3.fromRGB(205, 36, 28),
	Well = Color3.fromRGB(30, 28, 24),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

-- ---------------------------------------------------------------- ของในฉาก
local function interactive(name: string): Instance?
	local ip = Workspace:FindFirstChild("InteractiveProps")
	return ip and ip:FindFirstChild(name, true)
end
local function findTool(name: string): Tool?
	local c = player.Character
	local t = c and c:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil
end
local function drums(): { Instance }
	local env = Workspace:FindFirstChild("MapEnvironment")
	local yard = env and env:FindFirstChild("ImportedYardProps")
	local out = {}
	for _, n in ipairs({ "FuelDrum", "FuelDrum_Red" }) do
		local d = yard and yard:FindFirstChild(n)
		if d then
			table.insert(out, d)
		end
	end
	return out
end
local function fuelled(): boolean
	return (remotes:GetAttribute("PetrolLevel") or 0) > 0 or (remotes:GetAttribute("DieselLevel") or 0) > 0
end
local function generator(): Instance?
	return Workspace:FindFirstChild("Generator")
end
local function pumps(): Instance?
	return interactive("FuelPumps") or interactive("GasPump")
end
local function shrine(): Instance?
	local s = Workspace:FindFirstChild("SpiritHouse")
	return s and (s:FindFirstChild("SpiritHouseOnStilts") or s)
end

-- ขั้นตอน: id = ชื่อที่จำไว้ใน TutSeen, trigger() = เหตุการณ์มาถึงแล้ว (เริ่มสอนตอนนี้), done() = ทำเสร็จแล้ว,
--          key = ข้อความใน LanguageModule.UI (ฟังก์ชันได้: เรื่องที่มีหลายขั้นย่อยบอกทีละขั้น),
--          targets() = ของที่ทำกรอบเรืองแสง, icon() = ของที่เอามาทำรูปในแผง (โมเดลจริง), hold = แสดงกี่วิแล้วจบเอง
type Step = {
	id: string,
	key: string | () -> string,
	trigger: () -> boolean,
	done: () -> boolean,
	targets: () -> { Instance },
	icon: () -> Instance?,
	hold: number?,
}
local seenCustomer = false -- ลูกค้าคนแรกของคืนมาแล้ว (CustomerSpeech) -> สอนดูผี
local powerOff = function(): boolean
	return ReplicatedStorage:GetAttribute("PowerOn") == false
end
local shopOpen = function(): boolean
	return remotes:GetAttribute("ShopOpen") == true
end
local function canState(): string
	local can = findTool("FuelCan")
	if not can then
		return "none"
	end
	return if can:GetAttribute("Full") == true then "full" else "empty"
end
local STEPS: { Step } = {
	{
		id = "flash",
		key = "Tut_Flashlight",
		trigger = powerOff, -- มืด (เริ่มคืนไฟดับ)
		done = function()
			local c = player.Character
			return c ~= nil and c:FindFirstChild("FrogFlashlight") ~= nil
		end,
		targets = function()
			return {}
		end,
		icon = function()
			return findTool("FrogFlashlight")
		end,
	},
	{
		id = "shop",
		key = "Tut_OpenShop",
		trigger = function()
			return not shopOpen()
		end,
		done = shopOpen,
		targets = function()
			return { interactive("RejectRope") }
		end,
		icon = function()
			return interactive("ShutterDoor")
		end,
	},
	{
		id = "gen",
		key = "Tut_Generator",
		trigger = function()
			return shopOpen() and powerOff()
		end,
		done = function()
			return not powerOff()
		end,
		targets = function()
			return { generator() }
		end,
		icon = generator,
	},
	{
		-- ตู้น้ำมันหมด: หยิบแกลลอน -> ตักที่ถัง -> เทใส่ตู้ (เรื่องเดียว บอกทีละขั้นตามของในมือ)
		id = "fuel",
		key = function()
			local st = canState()
			return if st == "none" then "Tut_TakeCan" elseif st == "empty" then "Tut_FillCan" else "Tut_Pour"
		end,
		trigger = function()
			return shopOpen() and not fuelled()
		end,
		done = fuelled,
		targets = function()
			local st = canState()
			if st == "none" then
				return { interactive("FuelCanSpot") }
			elseif st == "empty" then
				return drums()
			end
			return { interactive("FuelPumps") }
		end,
		icon = function()
			local st = canState()
			if st == "none" then
				return interactive("FuelCanSpot")
			elseif st == "empty" then
				return drums()[1]
			end
			return pumps()
		end,
	},
	{
		-- เวลาคุ้มครองของศาลใกล้หมด (หรือช่วงเตรียมร้านยังไม่ถวาย)
		id = "offer",
		key = "Tut_Offer",
		trigger = function()
			local left = remotes:GetAttribute("OfferingLeft")
			local prepping = type(remotes:GetAttribute("PrepLeft")) == "number" and remotes:GetAttribute("PrepOffered") ~= true
			return prepping or (type(left) == "number" and left <= 60)
		end,
		done = function()
			-- ถวายแล้ว = เวลาคุ้มครองเด้งขึ้นเกินช่วงผ่อนผันตอนเปิดร้าน
			local left = remotes:GetAttribute("OfferingLeft")
			local total = remotes:GetAttribute("OfferingTotal") or 150
			return type(left) == "number" and left > total - 10
		end,
		targets = function()
			return { Workspace:FindFirstChild("SpiritHouse") }
		end,
		icon = function()
			return findTool("ThaiDessert") or shrine()
		end,
	},
	{
		-- ลูกค้าคนแรกมาถึง: พนมมือดูผี / ผีห้ามเติม ปิดแผง (คำอธิบาย แสดงแล้วจบเอง)
		id = "ghost",
		key = "Tut_Ghosts",
		trigger = function()
			return seenCustomer
		end,
		done = function()
			return false
		end,
		targets = function()
			return { interactive("RejectRope") }
		end,
		icon = function()
			return interactive("ShutterDoor")
		end,
		hold = 12,
	},
}

-- งานช่วงเตรียมร้าน (ทุกคืน): รูป + ข้อความ + ทำแล้วหรือยัง
type Task = { key: string, done: () -> boolean, icon: () -> Instance? }
local PREP: { Task } = {
	{
		key = "PrepOffer",
		done = function()
			return remotes:GetAttribute("PrepOffered") == true
		end,
		icon = function()
			return findTool("ThaiDessert") or shrine()
		end,
	},
	{
		key = "PrepPower",
		done = function()
			return ReplicatedStorage:GetAttribute("PowerOn") ~= false
		end,
		icon = generator,
	},
	{ key = "PrepFuel", done = fuelled, icon = pumps },
}

-- ---------------------------------------------------------------- UI (มุมซ้ายกลางจอ)
local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.AutoLocalize = false
gui.DisplayOrder = 3
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Card"
-- มุมซ้ายบน ใต้แถบปุ่มของ Roblox (โลโก้ เมนู แชต ~58px) ไม่ทับปุ่มบนจอเตี้ยแบบมือถือ
panel.AnchorPoint = Vector2.new(0, 0)
local EDGE = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SafeArea")).Pad() -- มือถือเว้นขอบเพิ่ม
panel.Position = UDim2.new(0, 16 + EDGE, 0, 72)
panel.Size = UDim2.fromOffset(224, 0) -- เล็กลง ไม่รกจอ
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C.Ink
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 3)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = C.Line
stroke.Transparency = 0.2
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 7), UDim.new(0, 9), UDim.new(0, 9)
local list = Instance.new("UIListLayout", panel)
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder

-- มือถือ (ไม่มีปุ่ม H): แตะกล่องคำแนะนำ = ย่อเหลือป้ายเล็ก / แตะป้ายเล็ก = เปิดกลับ
local IS_TOUCH = (require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any).TouchMode == true
local tipsTab = Instance.new("TextButton")
tipsTab.Name = "TipsTab"
tipsTab.AnchorPoint = Vector2.new(0, 0)
tipsTab.Position = UDim2.new(0, 16 + EDGE, 0, 72)
tipsTab.Size = UDim2.fromOffset(0, 34)
tipsTab.AutomaticSize = Enum.AutomaticSize.X
tipsTab.BackgroundColor3 = C.Ink
tipsTab.BackgroundTransparency = 0.2
tipsTab.BorderSizePixel = 0
tipsTab.AutoButtonColor = false
tipsTab.FontFace = FONT
tipsTab.TextSize = 16
tipsTab.TextColor3 = C.Cream
tipsTab.Visible = false
tipsTab.Parent = gui
Instance.new("UICorner", tipsTab).CornerRadius = UDim.new(0, 3)
local tabStroke = Instance.new("UIStroke", tipsTab)
tabStroke.Color = C.Line
tabStroke.Transparency = 0.2
tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local tabPad = Instance.new("UIPadding", tipsTab)
tabPad.PaddingLeft, tabPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)

local function label(parent: Instance, order: number, size: number, color: Color3, h: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, h or 0)
	if not h then
		l.AutomaticSize = Enum.AutomaticSize.Y
	end
	l.FontFace = FONT
	l.TextSize = size
	l.TextWrapped = true
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

-- กรอบรูป (พื้นเข้ม ขอบบาง) ใส่ ViewportFrame
local function iconWell(parent: Instance, size: number, order: number): ViewportFrame
	local well = Instance.new("Frame")
	well.LayoutOrder = order
	well.Size = UDim2.fromOffset(size, size)
	well.BackgroundColor3 = C.Well
	well.BorderSizePixel = 0
	well.Parent = parent
	Instance.new("UICorner", well).CornerRadius = UDim.new(0, 3)
	local s = Instance.new("UIStroke", well)
	s.Color = C.Line
	s.Transparency = 0.3
	local vf = ModelIcon.Make(UDim2.fromScale(1, 1))
	vf.Parent = well
	return vf
end

-- ส่วนที่ 1: เตรียมร้าน (หัวเรื่อง + เวลา, แล้วรายการงาน)
local prepBox = Instance.new("Frame")
prepBox.Name = "PrepBox"
prepBox.LayoutOrder = 1
prepBox.BackgroundTransparency = 1
prepBox.Size = UDim2.new(1, 0, 0, 0)
prepBox.AutomaticSize = Enum.AutomaticSize.Y
prepBox.Visible = false
prepBox.Parent = panel
local pl = Instance.new("UIListLayout", prepBox)
pl.Padding = UDim.new(0, 4)
pl.SortOrder = Enum.SortOrder.LayoutOrder
local prepHead = Instance.new("Frame")
prepHead.LayoutOrder = 0
prepHead.BackgroundTransparency = 1
prepHead.Size = UDim2.new(1, 0, 0, 18)
prepHead.Parent = prepBox
local prepTitle = label(prepHead, 0, 12, C.Gold, 18)
local prepTime = label(prepHead, 0, 16, C.Ember, 18)
prepTime.TextXAlignment = Enum.TextXAlignment.Right
type Row = { frame: Frame, icon: ViewportFrame, text: TextLabel, task: Task, shown: Instance? }
local prepRows: { Row } = {}
for i, t in ipairs(PREP) do
	local row = Instance.new("Frame")
	row.LayoutOrder = i
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = prepBox
	local rl = Instance.new("UIListLayout", row)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0, 8)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	local icon = iconWell(row, 34, 1) -- รูปพอให้ดูรูปอย่างเดียวก็รู้ว่าต้องทำอะไร
	local text = label(row, 2, 12, C.Cream, 34)
	text.Size = UDim2.new(1, -42, 0, 34)
	table.insert(prepRows, { frame = row, icon = icon, text = text, task = t, shown = nil })
end
local divider = Instance.new("Frame")
divider.LayoutOrder = 2
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = C.Line
divider.BorderSizePixel = 0
divider.Visible = false
divider.Parent = panel

-- ส่วนที่ 2: สอนเล่น (หัวเรื่อง, แล้วรูป + ข้อความ, แล้วคำแนะนำปุ่ม H)
local stepBox = Instance.new("Frame")
stepBox.Name = "StepBox"
stepBox.LayoutOrder = 3
stepBox.BackgroundTransparency = 1
stepBox.Size = UDim2.new(1, 0, 0, 0)
stepBox.AutomaticSize = Enum.AutomaticSize.Y
stepBox.Visible = false
stepBox.Parent = panel
local sl = Instance.new("UIListLayout", stepBox)
sl.Padding = UDim.new(0, 4)
sl.SortOrder = Enum.SortOrder.LayoutOrder
-- หัวการ์ด: "วิธีเฝ้าร้าน (n/6)" + ปุ่ม [ข้าม] (เรื่องนี้ถือว่าเรียนแล้ว) [ซ่อน] (ย่อเหลือป้ายเล็ก กดเปิดกลับได้)
local BTN_H = if IS_TOUCH then 24 else 18
local titleRow = Instance.new("Frame")
titleRow.Name = "TitleRow"
titleRow.LayoutOrder = 1
titleRow.BackgroundTransparency = 1
titleRow.Size = UDim2.new(1, 0, 0, BTN_H)
titleRow.Parent = stepBox
local title = label(titleRow, 1, 11, C.Ember, BTN_H)
title.Size = UDim2.new(1, -(if IS_TOUCH then 118 else 96), 0, BTN_H)
local function cardButton(order: number, w: number): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -(order - 1) * (w + 4), 0, 0)
	b.Size = UDim2.fromOffset(w, BTN_H)
	b.BackgroundColor3 = C.Well
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.FontFace = FONT
	b.TextSize = if IS_TOUCH then 13 else 11
	b.TextColor3 = C.Dim
	b.Parent = titleRow
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
	local st = Instance.new("UIStroke", b)
	st.Color = C.Line
	st.Transparency = 0.2
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.MouseEnter:Connect(function()
		b.TextColor3 = C.Cream
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = C.Dim
	end)
	return b
end
local hideBtn = cardButton(1, if IS_TOUCH then 54 else 44)
local skipBtn = cardButton(2, if IS_TOUCH then 54 else 44)
hideBtn.Name = "HideTip"
skipBtn.Name = "SkipTip"
local skipCurrent = false
local stepRow = Instance.new("Frame")
stepRow.LayoutOrder = 2
stepRow.BackgroundTransparency = 1
stepRow.Size = UDim2.new(1, 0, 0, 0)
stepRow.AutomaticSize = Enum.AutomaticSize.Y
stepRow.Parent = stepBox
local srl = Instance.new("UIListLayout", stepRow)
srl.FillDirection = Enum.FillDirection.Horizontal
srl.Padding = UDim.new(0, 7)
srl.SortOrder = Enum.SortOrder.LayoutOrder
local stepIcon = iconWell(stepRow, 44, 1)
local body = label(stepRow, 2, 12, C.Cream)
body.Size = UDim2.new(1, -51, 0, 0)
local hint = label(stepBox, 3, 10, C.Dim, 12)

-- จอเตี้ย (โน้ตบุ๊ก 14 นิ้ว) ย่อทั้งแผงตามความสูงจอ (shared/UiFit ค่าเดียวกันทุกกล่อง)
require(Shared:WaitForChild("UiFit")).Attach(gui)

-- กรอบเรืองแสงที่ของ (เห็นทะลุผนัง จะได้รู้ว่าอยู่ทางไหน)
local highlights: { Highlight } = {}
local function clearHighlights()
	for _, h in ipairs(highlights) do
		h:Destroy()
	end
	table.clear(highlights)
end
local function highlight(targets: { Instance? })
	clearHighlights()
	for _, t in ipairs(targets) do
		if t then
			local h = Instance.new("Highlight")
			h.Name = "TutorialHighlight"
			h.Adornee = t
			h.FillColor = C.Gold
			h.FillTransparency = 0.85
			h.OutlineColor = C.Gold
			h.OutlineTransparency = 0.1
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = gui
			table.insert(highlights, h)
			-- กะพริบเบาๆ
			TweenService:Create(h, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.7, FillTransparency = 0.95 }):Play()
		end
	end
end

local current = 0
local hidden = false
local running = false -- กำลังสอนอยู่
local iconShown: Instance? = nil
local function draw()
	local s = STEPS[current]
	if not s then
		return
	end
	title.Text = string.format("%s  (%d/%d)", ui("Tut_Title"), current, #STEPS)
	body.Text = ui(if type(s.key) == "function" then s.key() else s.key)
	hint.Text = ui("Tut_Hide")
	skipBtn.Text = ui("Tut_Skip")
	hideBtn.Text = ui("Tut_HideBtn")
end

-- รูปของ: ของในโลกอาจยังไม่ถูกส่งมา (StreamingEnabled) -> ลองใหม่ทุกรอบ refresh จนได้
local function setIcon(vf: ViewportFrame, source: Instance?, shown: Instance?): Instance?
	if source == shown and source ~= nil and #vf:GetChildren() > 0 then
		return shown
	end
	if source and ModelIcon.Set(vf, source) then
		return source
	end
	return nil
end

-- อัปเดตทั้งแผง (เรียกบ่อยๆ): ส่วนเตรียมร้าน, ส่วนสอน, แสดง/ซ่อนทั้งแผง
local function refresh()
	local left = remotes:GetAttribute("PrepLeft")
	local teachingNow = running and current > 0 and STEPS[current] ~= nil
	-- ทีละอย่าง: ระหว่างสอนไม่โชว์รายการเตรียมร้าน
	local prepping = type(left) == "number" and not teachingNow
	prepBox.Visible = prepping
	if prepping then
		prepTitle.Text = ui("PrepTitle")
		prepTime.Text = string.format("%d:%02d", left // 60, left % 60)
		prepTime.TextColor3 = if left <= 10 then C.Blood else C.Ember
		-- โชว์แค่งานถัดไปที่ยังไม่ทำ (ทำครบแล้ว = โชว์แต่เวลา)
		local shownOne = false
		for _, r in ipairs(prepRows) do
			local done = r.task.done()
			local show = not done and not shownOne
			r.frame.Visible = show
			if show then
				shownOne = true
				r.text.Text = ui(r.task.key)
				r.text.TextColor3 = C.Cream
				r.icon.ImageTransparency = 0
				r.shown = setIcon(r.icon, r.task.icon(), r.shown)
			end
		end
	end
	local teaching = running and current > 0 and STEPS[current] ~= nil
	stepBox.Visible = teaching
	divider.Visible = prepping and teaching
	if teaching then
		iconShown = setIcon(stepIcon, STEPS[current].icon(), iconShown)
	end
	local any = prepping or teaching
	local cutscene = ReplicatedStorage:GetAttribute("CutsceneRunning") == true
	-- ซ่อนแล้วยังเหลือป้ายเล็กให้แตะ/คลิกเปิดกลับ (คอมกด H ได้ด้วย)
	gui.Enabled = any and not cutscene
	panel.Visible = not hidden
	tipsTab.Visible = hidden
	tipsTab.Text = ui("Tut_Title") .. "  ▸"
	for _, h in ipairs(highlights) do
		h.Enabled = teaching and not hidden and not cutscene
	end
end

-- เรื่องที่เรียนแล้ว (จำใน DataStore ผ่าน PlayerSettings.TutSeen)
local setSetting = remotes:WaitForChild("SetSetting") :: RemoteEvent
local function seenSet(): { [string]: boolean }
	local out = {}
	local raw = player:GetAttribute("TutSeen")
	if type(raw) == "string" then
		for id in string.gmatch(raw, "[%w_]+") do
			out[id] = true
		end
	end
	return out
end
local function markSeen(id: string)
	local set = seenSet()
	if set[id] then
		return
	end
	set[id] = true
	local ids = {}
	for _, st in ipairs(STEPS) do
		if set[st.id] then
			table.insert(ids, st.id)
		end
	end
	local v = table.concat(ids, ",")
	player:SetAttribute("TutSeen", v)
	setSetting:FireServer("TutSeen", v)
end

-- สอน 1 เรื่องจนทำเสร็จ (หรือครบเวลา hold) คืน false = จบคืนระหว่างสอน
local function teach(i: number, s: Step): boolean
	running = true
	current = i
	iconShown = nil
	local lastKey = nil
	draw()
	highlight(s.targets())
	local t0 = os.clock()
	while true do
		-- เรื่องที่มีขั้นย่อย (เติมน้ำมัน): ข้อความ/กรอบเรืองแสง/รูปเปลี่ยนตามขั้น
		local k = if type(s.key) == "function" then s.key() else s.key
		if k ~= lastKey then
			lastKey = k
			iconShown = nil
			draw()
			highlight(s.targets())
		end
		refresh()
		if s.hold and os.clock() - t0 >= s.hold then
			break
		end
		if not s.hold and s.done() then
			break
		end
		if skipCurrent then
			break -- ผู้เล่นกดข้ามเรื่องนี้ (นับว่าเรียนแล้ว)
		end
		if player:GetAttribute("ShowTutorial") == false then
			-- ปิดการสอนจากหน้าตั้งค่ากลางคัน: เลิกสอน ไม่นับว่าเรียนแล้ว
			clearHighlights()
			running = false
			current = 0
			refresh()
			return true
		end
		if remotes:GetAttribute("GameOver") == true then
			clearHighlights()
			running = false
			current = 0
			refresh()
			return false
		end
		task.wait(0.3)
	end
	local wasSkipped = skipCurrent
	skipCurrent = false
	markSeen(s.id)
	if wasSkipped then
		clearHighlights()
		running = false
		current = 0
		refresh()
		return true
	end
	-- สำเร็จ: แผงแวบสีทองก่อนปิด
	stroke.Color = C.Gold
	task.wait(0.6)
	stroke.Color = C.Line
	clearHighlights()
	running = false
	current = 0
	refresh()
	return true
end

-- คอยดูเหตุการณ์ตลอดคืน: เรื่องไหนยังไม่เคยเรียน + เหตุการณ์มาถึง + ยังไม่เสร็จ = สอนเรื่องนั้น (ทีละเรื่อง ตามลำดับ)
local watching = false
local function run()
	if watching then
		return
	end
	watching = true
	while remotes:GetAttribute("GameOver") ~= true do
		local seen = seenSet()
		local allSeen = true
		for i, st in ipairs(STEPS) do
			if not seen[st.id] then
				allSeen = false
				local cutscene = ReplicatedStorage:GetAttribute("CutsceneRunning") == true
				local enabled = player:GetAttribute("ShowTutorial") ~= false
				if enabled and not cutscene and st.trigger() and (st.hold or not st.done()) then
					if not teach(i, st) then
						watching = false
						return
					end
					break -- ดูใหม่ตั้งแต่ต้น (เรื่องก่อนหน้าอาจเกิดขึ้นอีก)
				end
			end
		end
		if allSeen then
			break
		end
		task.wait(0.5)
	end
	watching = false
end

-- ลูกค้าคนแรกพูดขึ้นมา = ลูกค้ามาแล้ว (ใช้เริ่มสอนดูผี)
local speech = remotes:FindFirstChild("CustomerSpeech")
if speech and speech:IsA("RemoteEvent") then
	speech.OnClientEvent:Connect(function()
		seenCustomer = true
	end)
end

-- ช่วงเตรียมร้านเกิดทุกคืน (สอนจบไปแล้วก็ยังขึ้น)
remotes:GetAttributeChangedSignal("PrepLeft"):Connect(refresh)
remotes:GetAttributeChangedSignal("PrepOffered"):Connect(refresh)
remotes:GetAttributeChangedSignal("PetrolLevel"):Connect(refresh)
remotes:GetAttributeChangedSignal("DieselLevel"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("PowerOn"):Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("CutsceneRunning"):Connect(refresh)

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H and (running or prepBox.Visible) then
		hidden = not hidden
		refresh()
	end
end)
skipBtn.Activated:Connect(function()
	if running then
		skipCurrent = true
	end
end)
hideBtn.Activated:Connect(function()
	hidden = true
	refresh()
end)
tipsTab.Activated:Connect(function()
	hidden = false
	refresh()
end)
player:GetAttributeChangedSignal("ShowTutorial"):Connect(refresh)
player:GetAttributeChangedSignal("Lang"):Connect(function()
	draw()
	refresh()
end)

-- เริ่มสอนครั้งเดียวต่อการเข้าเกม: หลังคัทซีนเปิดคืนจบ (ดูจบ/ข้าม) หรือไม่มีคัทซีนแต่ร้านยังไม่เปิด
local cutscene = remotes:WaitForChild("Cutscene") :: RemoteEvent
local started = false
local function begin()
	if started then
		return
	end
	started = true
	task.delay(1.2, run) -- ให้จอดำ/แสงกลับมาก่อน
end
cutscene.OnClientEvent:Connect(function(kind: string, a: any)
	if kind == "end" and a == "intro" then
		begin()
	elseif kind == "nocutscene" and remotes:GetAttribute("ShopOpen") ~= true then
		begin()
	end
end)
refresh()
