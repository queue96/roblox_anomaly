--!nonstrict
-- TutorialController.client.luau
-- แผงมุมซ้ายกลางจอ ทำ 2 อย่างในแผงเดียว (เดิมแยกกล่องเตรียมร้านไว้กลางจอ ซ้ำซ้อน):
--   1) ช่วงเตรียมร้าน (ทุกคืน): ดึงเชือกเปิดร้านแล้ว "ลูกค้ามาใน 0:24" + รายการงาน (รูป + ข้อความ) ทำแล้วขึ้นสีเขียว
--      (server/CoreLoop: Remotes.PrepLeft / PrepOffered, ไฟ = ReplicatedStorage.PowerOn, น้ำมัน = PetrolLevel/DieselLevel)
--   2) สอนเล่นทีละขั้น (ครั้งแรกที่เข้าเกม หลังคัทซีนเปิดคืน): ข้อความ + รูปของที่ต้องไปทำ + กรอบเรืองแสงที่ของในฉาก
--      ทำขั้นนั้นสำเร็จ (ใครในทีมทำก็ได้ ยกเว้นไฟฉาย/แกลลอนที่เป็นของตัวเอง) -> ไปขั้นถัดไปเอง
--   รูปทั้งหมดเป็นโมเดล 3D จริงในฉาก (shared/ModelIcon) บางคนไม่อ่าน ดูแต่รูป
--   กด H ซ่อน/แสดง  ·  ขั้นที่ทำเสร็จไปก่อนแล้ว (เช่น เพื่อนเปิดร้านแล้ว) ข้ามไปเลย
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

-- ขั้นตอน: key = ข้อความใน LanguageModule.UI, done() = ทำเสร็จแล้ว, targets() = ของที่ทำกรอบเรืองแสง,
--          icon() = ของที่เอามาทำรูปในแผง (โมเดลจริง)
type Step = { key: string, done: () -> boolean, targets: () -> { Instance }, icon: () -> Instance?, hold: number? }
local STEPS: { Step } = {
	{
		key = "Tut_Flashlight",
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
		key = "Tut_OpenShop",
		done = function()
			return remotes:GetAttribute("ShopOpen") == true
		end,
		targets = function()
			return { interactive("RejectRope") }
		end,
		icon = function()
			return interactive("ShutterDoor")
		end,
	},
	{
		key = "Tut_Generator",
		done = function()
			return ReplicatedStorage:GetAttribute("PowerOn") ~= false
		end,
		targets = function()
			return { generator() }
		end,
		icon = generator,
	},
	{
		key = "Tut_TakeCan",
		done = function()
			return findTool("FuelCan") ~= nil or fuelled()
		end,
		targets = function()
			return { interactive("FuelCanSpot") }
		end,
		icon = function()
			return interactive("FuelCanSpot")
		end,
	},
	{
		key = "Tut_FillCan",
		done = function()
			local can = findTool("FuelCan")
			return (can ~= nil and can:GetAttribute("Full") == true) or fuelled()
		end,
		targets = drums,
		icon = function()
			return drums()[1]
		end,
	},
	{
		key = "Tut_Pour",
		done = fuelled,
		targets = function()
			return { interactive("FuelPumps") }
		end,
		icon = pumps,
	},
	{
		key = "Tut_Offer",
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
		key = "Tut_Ghosts",
		done = function()
			return false
		end,
		targets = function()
			return { interactive("RejectRope") }
		end,
		icon = function()
			return interactive("ShutterDoor")
		end,
		hold = 12, -- ขั้นสุดท้ายเป็นคำอธิบาย: แสดงแล้วจบเอง
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
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 16, 0.42, 0)
panel.Size = UDim2.fromOffset(260, 0)
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
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = prepBox
	local rl = Instance.new("UIListLayout", row)
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.VerticalAlignment = Enum.VerticalAlignment.Center
	rl.Padding = UDim.new(0, 8)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	local icon = iconWell(row, 40, 1) -- รูปใหญ่พอให้ดูรูปอย่างเดียวก็รู้ว่าต้องทำอะไร
	local text = label(row, 2, 13, C.Cream, 40)
	text.Size = UDim2.new(1, -48, 0, 40)
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
stepBox.LayoutOrder = 3
stepBox.BackgroundTransparency = 1
stepBox.Size = UDim2.new(1, 0, 0, 0)
stepBox.AutomaticSize = Enum.AutomaticSize.Y
stepBox.Visible = false
stepBox.Parent = panel
local sl = Instance.new("UIListLayout", stepBox)
sl.Padding = UDim.new(0, 4)
sl.SortOrder = Enum.SortOrder.LayoutOrder
local title = label(stepBox, 1, 11, C.Ember, 14)
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
local stepIcon = iconWell(stepRow, 60, 1)
local body = label(stepRow, 2, 13, C.Cream)
body.Size = UDim2.new(1, -67, 0, 0)
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
	body.Text = ui(s.key)
	hint.Text = ui("Tut_Hide")
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
	local prepping = type(left) == "number"
	prepBox.Visible = prepping
	if prepping then
		prepTitle.Text = ui("PrepTitle")
		prepTime.Text = string.format("%d:%02d", left // 60, left % 60)
		prepTime.TextColor3 = if left <= 10 then C.Blood else C.Ember
		for _, r in ipairs(prepRows) do
			local done = r.task.done()
			r.text.Text = (if done then "✓ " else "") .. ui(r.task.key)
			r.text.TextColor3 = if done then C.Done else C.Cream
			r.icon.ImageTransparency = if done then 0.55 else 0
			r.shown = setIcon(r.icon, r.task.icon(), r.shown)
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
	gui.Enabled = any and not hidden and not cutscene
	for _, h in ipairs(highlights) do
		h.Enabled = teaching and not hidden and not cutscene
	end
end

local function run()
	if running then
		return
	end
	running = true
	for i, s in ipairs(STEPS) do
		if s.done() and not s.hold then
			continue -- ทำไปแล้ว (เพื่อนทำ / ทำก่อนสอน)
		end
		current = i
		iconShown = nil
		draw()
		highlight(s.targets())
		local t0 = os.clock()
		while true do
			refresh()
			if s.hold and os.clock() - t0 >= s.hold then
				break
			end
			if not s.hold and s.done() then
				break
			end
			-- จบคืนระหว่างสอน: เลิกสอน
			if remotes:GetAttribute("GameOver") == true then
				clearHighlights()
				running = false
				current = 0
				refresh()
				return
			end
			task.wait(0.3)
		end
		-- สำเร็จ: แผงแวบสีทองก่อนไปขั้นต่อไป
		stroke.Color = C.Gold
		task.wait(0.6)
		stroke.Color = C.Line
	end
	clearHighlights()
	running = false
	current = 0
	refresh()
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
