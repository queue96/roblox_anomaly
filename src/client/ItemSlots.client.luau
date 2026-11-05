--!nonstrict
-- ItemSlots.client.luau
-- ช่องของถัดจากช่องไฟฉาย [1] (HUDController): [2] ขนมไทย (ถวายศาลพระภูมิ) / [3] แกลลอนน้ำมัน (ว่าง/เต็ม)
-- กดเลข / แตะช่องเพื่อถือ-เก็บ  ช่องโผล่เฉพาะตอนมีของ  (Tool สร้างฝั่ง Server ใน CoreLoop)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
		-- ปุ่มซื้อถ่าน (ถ่านไม่ชาร์จเองแล้ว) ขึ้นตอนถ่านไม่เต็ม -> ได้ถ่านเข้าช่องที่ 4 · ช่วงนี้ฟรี ทีหลังเป็นซื้อด้วย Robux (server/Flashlight)
		--   คอม: กด B ได้เลย (เมาส์ล็อกกลางจอ) / มือถือ: แตะปุ่ม
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local buy = remotes:WaitForChild("BuyBattery", 20) :: RemoteEvent?
		if buy then
			local touch = LanguageModule.TouchMode == true
			local btn = Instance.new("TextButton")
			btn.Name = "BuyBattery"
			btn.LayoutOrder = 3
			btn.Size = UDim2.fromOffset(0, SLOT_H - 14)
			btn.AutomaticSize = Enum.AutomaticSize.X
			btn.BackgroundColor3 = Color3.fromRGB(48, 22, 20)
			btn.BackgroundTransparency = 0.1
			btn.BorderSizePixel = 0
			btn.AutoButtonColor = true
			btn.FontFace = FONT
			btn.TextColor3 = C.Cream
			btn.TextSize = if touch then 16 else 13
			btn.Visible = false
			btn.Parent = fs
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
			local bp = Instance.new("UIPadding", btn)
			bp.PaddingLeft, bp.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
			local bs = Instance.new("UIStroke", btn)
			bs.Color = C.Ember
			bs.Transparency = 0.3
			bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local function draw()
				btn.Text = ui(if touch then "BuyBattery" else "BuyBattery_Key")
				local b = player:GetAttribute("Battery")
				btn.Visible = type(b) == "number" and b < 0.99
			end
			draw()
			player:GetAttributeChangedSignal("Battery"):Connect(draw)
			player:GetAttributeChangedSignal("Lang"):Connect(draw)
			local function request()
				buy:FireServer()
			end
			btn.Activated:Connect(request)
			game:GetService("ContextActionService"):BindAction("BuyBattery", function(_, state)
				if state == Enum.UserInputState.Begin then
					request()
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.KeyCode.B)
		end
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
-- ถ่านไฟฉายที่ซื้อไว้ (server/Flashlight: Tool "FlashlightBattery" มี attribute Count) กด 4 = ใส่ถ่านใหม่ ไม่ต้องถือ
makeSlot(4, "4", "FlashlightBattery", Enum.KeyCode.Four, "BatterySlot")

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
		elseif s.tool == "FlashlightBattery" and tool then
			txt ..= " ×" .. tostring(tool:GetAttribute("Count") or 1)
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
	-- ถ่าน: ใช้ทันที (ใส่ถ่านก้อนใหม่ให้ไฟฉาย) ไม่ต้องหยิบขึ้นมือ
	if s.tool == "FlashlightBattery" then
		local use = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("UseBattery")
		if use and use:IsA("RemoteEvent") then
			use:FireServer()
		end
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
-- รูปศาลอย่างเดียว (ไม่มีตัวหนังสือ): เวลาคุ้มครองแสดงบนรูป ส่วนที่ใช้ไปแล้วมืดลงจากบนลงล่าง
--   ส่วนสว่างที่เหลือ = เวลาที่ยังคุ้มครอง (ลดจากบนลงล่าง) + เส้นระดับ / ใกล้หมดสีส้มกะพริบ / หมดแล้วรูปแดง
-- รูป = ตัวศาลพระภูมิจริง (เฉพาะตัวเรือน ไม่เอาเสา/ฐาน)
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SHRINE_SIZE = 60
local shrine = Instance.new("Frame")
shrine.Name = "ShrineTimer"
shrine.AnchorPoint = Vector2.new(1, 0)
shrine.Position = UDim2.new(1, -16 - require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SafeArea")).Pad(), 0, 56) -- มือถือเว้นขอบเพิ่ม
shrine.Size = UDim2.fromOffset(SHRINE_SIZE, SHRINE_SIZE)
shrine.BackgroundColor3 = Color3.fromRGB(30, 28, 24)
shrine.BackgroundTransparency = 0.1
shrine.BorderSizePixel = 0
shrine.ClipsDescendants = true
shrine.Visible = false
shrine.Parent = gui
Instance.new("UICorner", shrine).CornerRadius = UDim.new(0, 4)
local shrineStroke = Instance.new("UIStroke", shrine)
shrineStroke.Color = C.Line
shrineStroke.Thickness = 1.5
shrineStroke.Transparency = 0.1
shrineStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
-- รูปศาล: ถ่ายเฉพาะตัวเรือนด้านบน (ศาลเป็น mesh ชิ้นเดียวรวมเสา: เล็งกล้องไปที่ส่วนบน)
local shrineIcon = ModelIcon.Make(UDim2.fromScale(1, 1))
shrineIcon.ZIndex = 1
shrineIcon.Parent = shrine
-- ส่วนที่ใช้ไปแล้ว: เงามืดยาวลงมาจากด้านบน
local shrineSpent = Instance.new("Frame")
shrineSpent.Name = "Spent"
shrineSpent.Size = UDim2.fromScale(1, 0)
shrineSpent.BackgroundColor3 = Color3.fromRGB(6, 5, 4)
shrineSpent.BackgroundTransparency = 0.3
shrineSpent.BorderSizePixel = 0
shrineSpent.ZIndex = 2
shrineSpent.Parent = shrine
-- ส่วนที่เหลือ: แสงจางๆ สีของสถานะ (ครีม / ส้มเมื่อใกล้หมด) ชิดด้านล่าง
local shrineLeftFill = Instance.new("Frame")
shrineLeftFill.Name = "Remaining"
shrineLeftFill.AnchorPoint = Vector2.new(0, 1)
shrineLeftFill.Position = UDim2.fromScale(0, 1)
shrineLeftFill.Size = UDim2.fromScale(1, 1)
shrineLeftFill.BackgroundColor3 = C.Cream
shrineLeftFill.BackgroundTransparency = 0.88
shrineLeftFill.BorderSizePixel = 0
shrineLeftFill.ZIndex = 2
shrineLeftFill.Parent = shrine
-- เส้นระดับ: ขอบบนของส่วนที่เหลือ
local shrineLevel = Instance.new("Frame")
shrineLevel.Name = "Level"
shrineLevel.Size = UDim2.new(1, 0, 0, 2)
shrineLevel.BackgroundColor3 = C.Cream
shrineLevel.BorderSizePixel = 0
shrineLevel.ZIndex = 3
shrineLevel.Parent = shrineLeftFill
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
local function setLevel(frac: number, color: Color3)
	-- ลดจากบนลงล่าง: ส่วนที่เหลือชิดล่าง สูงตามเวลาที่เหลือ / ส่วนที่ใช้ไปมืดจากบน
	TweenService:Create(shrineLeftFill, TweenInfo.new(0.9, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, frac) }):Play()
	TweenService:Create(shrineSpent, TweenInfo.new(0.9, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1 - frac) }):Play()
	shrineLeftFill.BackgroundColor3 = color
	shrineLevel.BackgroundColor3 = color
	shrineLevel.Visible = frac > 0.02 and frac < 0.99
end
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
	if left <= 0 then
		-- หมดแล้ว: รูปแดงมืด ขอบแดงกะพริบ
		shrineIcon.ImageColor3 = Color3.fromRGB(150, 90, 90)
		setLevel(0, BLOOD)
		shrineStroke.Color = if blink then BLOOD else C.Line
		return
	end
	shrineIcon.ImageColor3 = Color3.new(1, 1, 1)
	local warn = left <= 25
	setLevel(math.clamp(left / total, 0, 1), if warn then C.Ember else C.Cream)
	shrineStroke.Color = if warn and blink then C.Ember elseif warn then C.Ember else C.Line
	shrineStroke.Transparency = if warn and not blink then 0.5 else 0.1
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
			c:GetAttributeChangedSignal("Count"):Connect(refresh) -- จำนวนถ่าน
		end
		refresh()
	end)
	container.ChildRemoved:Connect(refresh)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Tool") then
			c:GetAttributeChangedSignal("Full"):Connect(refresh)
			c:GetAttributeChangedSignal("Count"):Connect(refresh) -- จำนวนถ่าน
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
