-- KeyHints.client.luau — ไอคอนปุ่มลัดขอบจอขวา (ผู้ใช้ 2026-11-16: อยากได้แบบแมพอ้างอิงที่มีไอคอนตา/แม่กุญแจ + ตัวอักษรปุ่ม)
--   (ไฟฉาย + F เคยอยู่ที่นี่ ย้ายกลับไปช่อง [1] ล่างจอใน HUDController แล้ว ผู้ใช้ 2026-11-26: ทับรูปศาลพระภูมิบนจอเล็ก)
--   ตา + G  = พนมมือเปิดตาทิพย์ (PrayerController) · พนมมืออยู่ = ตาเรืองสีทอง
--   แม่กุญแจ + V = ปลด/ล็อกเมาส์ (HUDController ตั้ง attribute MouseUnlocked) · ปลดอยู่ = ห่วงกุญแจยกขึ้น
--   ไอคอนวาดด้วย Frame + UIStroke (เส้นขาวบางจางๆ) ไม่ต้องอัปโหลดรูป · ไม่รับคลิก (แค่บอกปุ่ม)
--   จอย: ตา = Y และซ่อนแม่กุญแจ · มือถือ/จอสัมผัส: ซ่อนทั้งหมด (มีปุ่ม 🙏 บนจอแล้ว) · คัทซีน: ซ่อน
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local IDLE = Color3.fromRGB(235, 232, 225)
local ACTIVE = Color3.fromRGB(255, 205, 120)
local IDLE_T = 0.45 -- จางๆ ไม่บังฉาก
local ACTIVE_T = 0.1
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local gui = Instance.new("ScreenGui")
gui.Name = "KeyHints"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 0
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local column = Instance.new("Frame")
column.Name = "Column"
column.AnchorPoint = Vector2.new(1, 0.5)
column.Position = UDim2.new(1, -18, 0.47, 0)
column.Size = UDim2.fromOffset(56, 300)
column.BackgroundTransparency = 1
column.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 22)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = column

local function frame(parent: Instance, size: UDim2, pos: UDim2, corner: number?, stroke: number?, fill: boolean?): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = size
	f.Position = pos
	f.BorderSizePixel = 0
	f.BackgroundColor3 = IDLE
	f.BackgroundTransparency = if fill then IDLE_T else 1
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(corner, 0)
		c.Parent = f
	end
	if stroke then
		local s = Instance.new("UIStroke")
		s.Thickness = stroke
		s.Color = IDLE
		s.Transparency = IDLE_T
		s.Parent = f
	end
	f.Parent = parent
	return f
end

-- ช่องไอคอน + ตัวอักษรปุ่มข้างใต้
local function slot(order: number, name: string): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.LayoutOrder = order
	holder.Size = UDim2.fromOffset(56, 80) -- ตัวอักษรห่างก้นไอคอน (เดิม 72: V ติดก้นแม่กุญแจดูเป็นเข็ม)
	holder.BackgroundTransparency = 1
	holder.Parent = column
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	icon.Size = UDim2.fromOffset(44, 44)
	icon.BackgroundTransparency = 1
	icon.Parent = holder
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0.5, 1)
	key.Position = UDim2.new(0.5, 0, 1, 0)
	key.Size = UDim2.fromOffset(40, 26)
	key.BackgroundTransparency = 1
	key.FontFace = FONT
	key.TextSize = 26
	key.TextColor3 = IDLE
	key.TextTransparency = IDLE_T
	key.Parent = holder
	return icon, key
end

-- ตา (ตาทิพย์): ขอบตาทรงเมล็ดอัลมอนด์ (หัวตา/หางตาแหลม ผู้ใช้ 2026-11-16: ทรงแคปซูลเดิมดูไม่เหมือนตา) + ม่านตา + ตาดำ
--   หนังตาบน/ล่าง = วงกลมใหญ่ 2 วง (จุดศูนย์กลางอยู่ใต้/เหนือตา) โชว์เฉพาะส่วนโค้งที่เป็นหนังตาด้วย UIGradient บนเส้น
local eyeIcon, eyeKey = slot(1, "Pray")
do
	local W, H = 40, 22 -- กว้างหัวตาถึงหางตา / สูงตาตอนเปิด
	local h = H / 2
	local r = (W * W / 4 + h * h) / (2 * h) -- รัศมีวงที่โค้งผ่านหัวตา-หางตา สูง h
	local f = h / (2 * r) -- สัดส่วนของวง (จากขอบวง) ที่เป็นหนังตา
	for _, top in ipairs({ true, false }) do
		local lid = frame(eyeIcon, UDim2.fromOffset(r * 2, r * 2), UDim2.fromOffset(22, 22 + (if top then 1 else -1) * (r - h)), 0.5, 2)
		local g = Instance.new("UIGradient")
		g.Rotation = 90 -- 0 = บนสุดของวง, 1 = ล่างสุด
		g.Transparency = if top
			then NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(f, 0),
				NumberSequenceKeypoint.new(f + 0.001, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			else NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1 - f - 0.001, 1),
				NumberSequenceKeypoint.new(1 - f, 0),
				NumberSequenceKeypoint.new(1, 0),
			})
		g.Parent = lid:FindFirstChildOfClass("UIStroke")
	end
end
frame(eyeIcon, UDim2.fromOffset(16, 16), UDim2.fromScale(0.5, 0.5), 0.5, 2)
local pupil = frame(eyeIcon, UDim2.fromScale(0.16, 0.16), UDim2.fromScale(0.5, 0.5), 0.5, nil, true)

-- แม่กุญแจตามภาพร่างผู้ใช้ (2026-11-16): ตัวกุญแจกรอบสี่เหลี่ยมเส้น + จุดรูกุญแจ · ห่วง = โค้งครึ่งวง + ขา 2 ข้าง
--   ล็อก = ห่วงตั้งกลางตัวกุญแจ · ปลดล็อก = ห่วงเลื่อนไปขวา (ขาซ้ายยังอยู่บนตัวกุญแจ ขาขวาลอยเลยออกไป)
--   โค้ง = วงกลมเส้น UIStroke แบบเดียวกับตัวกุญแจ (สว่าง/จางเท่ากัน) ซ่อนครึ่งล่างด้วย UIGradient บนเส้น
--   (ห้าม CanvasGroup: ไม่ตัดเส้น UIStroke และภาพในกลุ่มสว่างกว่าชิ้นอื่น ผู้ใช้เห็นห่วงขาวจ้ากว่าตัวกุญแจ)
local lockIcon, lockKey = slot(2, "Mouse")
local SH_W, SH_STROKE, SH_TOP, LEG_LEN = 20, 2.5, 2, 8
local LOCK_X, OPEN_X = 22, 37 -- กึ่งกลางห่วง: ล็อก / ปลดล็อก
local ARC_Y = SH_W / 2 -- จุดศูนย์กลางโค้ง (เส้นวาดออกด้านนอกกรอบ: ขอบนอกบนสุดอยู่ที่ y = 0) = จุดเริ่มขา
local shackle = Instance.new("Frame")
shackle.Name = "Shackle"
shackle.AnchorPoint = Vector2.new(0.5, 0)
shackle.Position = UDim2.fromOffset(LOCK_X, SH_TOP)
shackle.Size = UDim2.fromOffset(SH_W, ARC_Y + LEG_LEN)
shackle.BackgroundTransparency = 1
shackle.Parent = lockIcon
local ring = frame(shackle, UDim2.fromOffset(SH_W - SH_STROKE * 2, SH_W - SH_STROKE * 2), UDim2.fromOffset(SH_W / 2, ARC_Y), 0.5, SH_STROKE)
local half = Instance.new("UIGradient") -- บนลงล่าง: ครึ่งบนเห็น ครึ่งล่างล่องหน
half.Rotation = 90
half.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
half.Parent = ring:FindFirstChildOfClass("UIStroke")
local function leg(x: number)
	local l = Instance.new("Frame")
	l.Name = "Leg"
	l.Position = UDim2.fromOffset(x, ARC_Y)
	l.Size = UDim2.fromOffset(SH_STROKE, LEG_LEN)
	l.BorderSizePixel = 0
	l.BackgroundColor3 = IDLE
	l.BackgroundTransparency = IDLE_T
	l.Parent = shackle
end
leg(0)
leg(SH_W - SH_STROKE)
-- ตัวกุญแจ: กรอบเส้น (ขอบบนด้านนอกแตะปลายขาพอดี) + จุดรูกุญแจตรงกลาง
local BODY_W, BODY_H = 24, 20
local bodyTop = SH_TOP + ARC_Y + LEG_LEN + SH_STROKE -- ขอบด้านในของกรอบ (UIStroke วาดออกด้านนอก)
local body = frame(lockIcon, UDim2.fromOffset(BODY_W, BODY_H), UDim2.fromOffset(22, bodyTop + BODY_H / 2), 0.08, SH_STROKE)
frame(body, UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5), 0.5, nil, true)
lockKey.Text = "V"

-- ---------------------------------------------------------------- สี/สถานะ
local function paint(root: Instance, color: Color3, t: number)
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Sine)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("UIStroke") then
			TweenService:Create(d, info, { Color = color, Transparency = t }):Play()
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 and d.Name ~= "BatteryFill" then
			TweenService:Create(d, info, { BackgroundColor3 = color, BackgroundTransparency = t }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextColor3 = color, TextTransparency = t }):Play()
		end
	end
end

local function updatePray()
	local on = localPlayer:GetAttribute("Praying") == true
	paint(eyeIcon.Parent :: Instance, if on then ACTIVE else IDLE, if on then ACTIVE_T else IDLE_T)
	pupil.Size = if on then UDim2.fromScale(0.24, 0.24) else UDim2.fromScale(0.16, 0.16)
end

local function updateMouse()
	local unlocked = localPlayer:GetAttribute("MouseUnlocked") == true
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Back)
	TweenService:Create(shackle, info, { Position = UDim2.fromOffset(if unlocked then OPEN_X else LOCK_X, SH_TOP) }):Play()
	paint(lockIcon.Parent :: Instance, if unlocked then ACTIVE else IDLE, if unlocked then ACTIVE_T else IDLE_T)
end

-- คีย์บอร์ด = G / V · จอย = Y (ไม่มีเมาส์) · จอสัมผัส = ซ่อน
local mode = "kb"
local function updateMode()
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		mode = "touch"
	elseif last.Name:sub(1, 7) == "Gamepad" then
		mode = "pad"
	elseif last == Enum.UserInputType.Keyboard or last.Name:sub(1, 5) == "Mouse" then
		mode = "kb"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		mode = "touch"
	end
	eyeKey.Text = if mode == "pad" then "Y" else "G"
	lockIcon.Parent.Visible = mode == "kb"
	column.Visible = mode ~= "touch" and Lighting:GetAttribute("Cutscene") ~= true
end

localPlayer:GetAttributeChangedSignal("Praying"):Connect(updatePray)
localPlayer:GetAttributeChangedSignal("MouseUnlocked"):Connect(updateMouse)
UserInputService.LastInputTypeChanged:Connect(updateMode)
Lighting:GetAttributeChangedSignal("Cutscene"):Connect(updateMode)
updateMode()
updatePray()
updateMouse()
