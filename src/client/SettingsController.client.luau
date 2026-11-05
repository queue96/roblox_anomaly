-- SettingsController.client.luau
-- ปุ่ม ⚙ มุมขวาบน เปิดหน้าตั้งค่า (สไตล์เดียวกับ HUD: แถบดำ หัวข้อเทาหม่น ตัวหนังสือครีม)
--   ภาษา ไทย/English · เสียงเพลง · เสียงเอฟเฟกต์ · แสดงเงิน/ธูป/ปุ่ม (HUD) · แสดงป้ายชื่อวัตถุ (ZoneLabel)
-- ค่าเก็บเป็น Attribute บน Player (Server จำลง DataStore ใน PlayerSettings.server.luau)
-- เสียง: แบ่งทุก Sound เข้า SoundGroup "Music" (วิทยุ/สวด) กับ "SFX" (ที่เหลือ) แล้วปรับ Volume ฝั่ง Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local SetSetting = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetSetting") :: RemoteEvent

local function lang(): string
	return LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?)
end
local function ui(key: string): string
	return LanguageModule.GetUI(key, lang())
end

-- เปลี่ยนค่าบนจอทันที แล้วส่งให้ Server ยืนยัน + บันทึก
local function set(name: string, value: any)
	localPlayer:SetAttribute(name, value)
	SetSetting:FireServer(name, value)
end

-- ---------------------------------------------------------------- เสียง: SoundGroup Music / SFX
local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	return g :: SoundGroup
end
local musicGroup = group("Music")
local sfxGroup = group("SFX")
local MUSIC_NAMES = { RadioMusic = true, MonkChant = true }

local function classify(d: Instance)
	if d:IsA("Sound") then
		local isMusic = MUSIC_NAMES[d.Name] or d:GetAttribute("SoundCategory") == "Music"
		d.SoundGroup = if isMusic then musicGroup else sfxGroup
	end
end
for _, root in ipairs({ Workspace, SoundService, ReplicatedStorage, localPlayer }) do
	for _, d in ipairs(root:GetDescendants()) do
		classify(d)
	end
	root.DescendantAdded:Connect(classify)
end

-- 100% ในหน้าตั้งค่า = ดัง 50% ของเสียงจริง (ไม่ให้ดังแสบหู โดยเฉพาะตอนผีหลอก)
--   มือถือ: คูณเพิ่ม (ลำโพงมือถือเบากว่าคอมมาก) Shared.DeviceInfo.VolumeBoost / อุปกรณ์อื่นเท่าคอม
-- ไม่มีโมดูล (เช่น place ที่ยังไม่ sync) = ไม่ค้าง ใช้ความดังเท่าคอม
local deviceModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DeviceInfo", 5)
local DeviceInfo = if deviceModule then require(deviceModule) :: any else nil
local MASTER_SCALE = 0.5
local function applyVolumes()
	local boost = if DeviceInfo then DeviceInfo.VolumeBoost() else 1
	musicGroup.Volume = ((localPlayer:GetAttribute("MusicVolume") or 0.7) :: number) * MASTER_SCALE * boost
	sfxGroup.Volume = ((localPlayer:GetAttribute("SfxVolume") or 0.8) :: number) * MASTER_SCALE * boost
end
applyVolumes()
-- ขนาดจอจริงมาทีหลังได้ (มือถือ/แท็บเล็ตตัดสินจากขนาดจอ): คิดใหม่เมื่อจอเปลี่ยน
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyVolumes)
end
localPlayer:GetAttributeChangedSignal("MusicVolume"):Connect(applyVolumes)
localPlayer:GetAttributeChangedSignal("SfxVolume"):Connect(applyVolumes)

-- ป้ายชื่อวัตถุ (ShowLabels) จัดการใน ObjectLabels.client.luau

-- ---------------------------------------------------------------- UI
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Bar = Color3.fromRGB(58, 54, 46),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(150, 142, 124),
	Blood = Color3.fromRGB(150, 18, 16),
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

local gui = new("ScreenGui", {
	Name = "SettingsGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	AutoLocalize = false,
	DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, localPlayer:WaitForChild("PlayerGui"))
-- จอเตี้ย (โน้ตบุ๊ก 14 นิ้ว) ย่อตามความสูงจอ (shared/UiFit ค่าเดียวกันทุกกล่อง)
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiFit")).Attach(gui)

-- ปุ่มตั้งค่า (ขนาดกะทัดรัด โทนดาร์กหม่นคุมธีมเดียวกับ HUD มุมขวาล่าง)
local gear = new("TextButton", {
	Name = "SettingsButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 14),
	Size = UDim2.new(0, 0, 0, 32),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = Color3.fromRGB(16, 14, 12),
	BackgroundTransparency = 0.25,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextSize = 16,
	TextColor3 = C.Dim,
	AutoButtonColor = false,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, gear)
new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, gear)
new("UIStroke", { Color = Color3.fromRGB(70, 64, 54), Thickness = 1, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, gear)
local gearOpen = false
gear.MouseEnter:Connect(function()
	gear.BackgroundColor3 = Color3.fromRGB(48, 22, 20)
	gear.TextColor3 = C.Cream
end)
gear.MouseLeave:Connect(function()
	gear.BackgroundColor3 = if gearOpen then Color3.fromRGB(48, 22, 20) else Color3.fromRGB(16, 14, 12)
	gear.TextColor3 = if gearOpen then C.Cream else C.Dim
end)

-- หน้าตั้งค่า
local panel = new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 460, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UIStroke", { Color = C.Line, Thickness = 1 }, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, panel)
new("UIPadding", { PaddingBottom = UDim.new(0, 14) }, panel)

local header = new("TextLabel", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = C.Bar,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 22,
	LayoutOrder = 0,
}, panel)

local refreshers: { () -> () } = {}

-- 1 แถว = ชื่อซ้าย + ตัวควบคุมขวา
local function row(order: number, labelKey: string): (Frame, TextLabel)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = order }, panel)
	new("UIPadding", { PaddingLeft = UDim.new(0, 22), PaddingRight = UDim.new(0, 22) }, r)
	local l = new("TextLabel", {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	table.insert(refreshers, function()
		l.Text = ui(labelKey)
	end)
	return r, l
end

local function button(parent: Instance, props: { [string]: any }): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 17,
		AutoButtonColor = false,
	}, parent)
	new("UIStroke", { Color = C.Line, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	return b
end

-- ภาษา: [ไทย] [English]
do
	local r = row(1, "Language")
	local thBtn = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	local enBtn = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	thBtn.Activated:Connect(function()
		set("Lang", "th")
	end)
	enBtn.Activated:Connect(function()
		set("Lang", "en")
	end)
	table.insert(refreshers, function()
		thBtn.Text = ui("LangThai")
		enBtn.Text = ui("LangEnglish")
		local th = lang() == "th"
		thBtn.BackgroundColor3 = if th then C.Blood else C.Ink
		enBtn.BackgroundColor3 = if th then C.Ink else C.Blood
	end)
end

-- แถบเลื่อนเสียง 0-100
local function slider(order: number, name: string, labelKey: string)
	local r = row(order, labelKey)
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.new(0, 150, 0, 8),
		BackgroundColor3 = Color3.fromRGB(40, 36, 30),
		BorderSizePixel = 0,
		Active = true,
	}, r)
	new("UIStroke", { Color = C.Line, Thickness = 1 }, bar)
	local fill = new("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Blood, BorderSizePixel = 0 }, bar)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 14, 0, 20),
		BackgroundColor3 = C.Cream,
		BorderSizePixel = 0,
	}, bar)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, knob)
	local pct = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 40, 1, 0),
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, r)

	local function draw(v: number)
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		pct.Text = tostring(math.round(v * 100))
	end
	local dragging = false
	local lastSent = 0
	local function fromInput(x: number)
		local v = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		v = math.round(v * 20) / 20 -- ทีละ 5%
		localPlayer:SetAttribute(name, v)
		if os.clock() - lastSent > 0.25 then
			lastSent = os.clock()
			SetSetting:FireServer(name, v)
		end
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromInput(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			SetSetting:FireServer(name, localPlayer:GetAttribute(name)) -- ส่งค่าสุดท้ายให้แน่นอน
		end
	end)
	table.insert(refreshers, function()
		draw((localPlayer:GetAttribute(name) or 0.7) :: number)
	end)
	localPlayer:GetAttributeChangedSignal(name):Connect(function()
		draw((localPlayer:GetAttribute(name) or 0.7) :: number)
	end)
end
slider(2, "MusicVolume", "MusicVolume")
slider(3, "SfxVolume", "SfxVolume")

-- สวิตช์ เปิด/ปิด
local function toggle(order: number, name: string, labelKey: string)
	local r = row(order, labelKey)
	local b = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	b.Activated:Connect(function()
		set(name, localPlayer:GetAttribute(name) == false)
	end)
	table.insert(refreshers, function()
		local on = localPlayer:GetAttribute(name) ~= false
		b.Text = ui(if on then "On" else "Off")
		b.BackgroundColor3 = if on then C.Blood else C.Ink
	end)
end
toggle(4, "ShowHUD", "ShowHUD")
-- สอนเล่น เปิด/ปิด (เฉพาะในเกม: Lobby ไม่มีการ์ดสอน)
if workspace:FindFirstChild("TempleLobby") == nil then
	toggle(6, "ShowTutorial", "ShowTutorial")
end

-- มือถือไฟฉาย: [ซ้าย] [ขวา] (ค่าเริ่มต้นขวา) แกลลอน/ขนมย้ายไปมืออีกข้างเอง
do
	local r = row(5, "FlashHand")
	local leftBtn = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	local rightBtn = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	leftBtn.Activated:Connect(function()
		set("FlashHand", "L")
	end)
	rightBtn.Activated:Connect(function()
		set("FlashHand", "R")
	end)
	table.insert(refreshers, function()
		leftBtn.Text = ui("HandLeft")
		rightBtn.Text = ui("HandRight")
		local left = localPlayer:GetAttribute("FlashHand") == "L"
		leftBtn.BackgroundColor3 = if left then C.Blood else C.Ink
		rightBtn.BackgroundColor3 = if left then C.Ink else C.Blood
	end)
end

-- ---------------------------------------------------------------- ปุ่มควบคุม (ย้ายมาจากป้ายปุ่มคีย์บน HUD)
-- แยกเป็นหน้าย่อย (กด "ดู") เพราะรายการยาว จอมือถือเตี้ย / รายการตามอุปกรณ์ (คอม = คีย์, มือถือ = ปุ่มบนจอ)
-- และตามที่อยู่ (Lobby / ในเกม) ให้ตรงกับที่เกมมีตอนนี้ (HUDController, PrayerController, Animate, ItemSlots,
-- GeneratorMinigame, TutorialController, CutsceneController)
local IS_TOUCH = LanguageModule.TouchMode
local IN_LOBBY = workspace:FindFirstChild("TempleLobby") ~= nil
type Control = { key: { th: string, en: string } | string, th: string, en: string }
local CONTROLS: { Control }
if IN_LOBBY and IS_TOUCH then
	CONTROLS = {
		{ key = { th = "จอยซ้าย", en = "Left stick" }, th = "เดิน", en = "Move" },
		{ key = { th = "ลากจอ", en = "Drag screen" }, th = "หมุนกล้อง", en = "Turn the camera" },
		{ key = { th = "ปุ่มกระโดด", en = "Jump button" }, th = "กระโดด", en = "Jump" },
		{ key = { th = "วงแดง", en = "Red ring" }, th = "เดินเข้าวง สร้าง / ร่วมห้อง", en = "Walk in to host / join a room" },
		{ key = { th = "สมุดผี", en = "Ghost Book" }, th = "ดูผีที่เคยรอดมาแล้ว", en = "See the ghosts you've survived" },
	}
elseif IN_LOBBY then
	CONTROLS = {
		{ key = "WASD", th = "เดิน", en = "Move" },
		{ key = { th = "คลิกขวาค้าง + ลาก", en = "Hold right-click + drag" }, th = "หมุนกล้อง", en = "Turn the camera" },
		{ key = "Space", th = "กระโดด", en = "Jump" },
		{ key = { th = "วงแดง", en = "Red ring" }, th = "เดินเข้าวง สร้าง / ร่วมห้อง", en = "Walk in to host / join a room" },
		{ key = { th = "สมุดผี", en = "Ghost Book" }, th = "ดูผีที่เคยรอดมาแล้ว", en = "See the ghosts you've survived" },
	}
elseif IS_TOUCH then
	CONTROLS = {
		{ key = { th = "จอยซ้าย", en = "Left stick" }, th = "เดิน", en = "Move" },
		{ key = { th = "ลากจอ", en = "Drag screen" }, th = "มองรอบตัว", en = "Look around" },
		{ key = { th = "ปุ่มที่ขึ้นมา", en = "Pop-up button" }, th = "แตะ / แตะค้าง ใช้ของ เติมน้ำมัน ดึงเชือก ถวาย", en = "Tap / hold to use, refuel, pull the rope, offer" },
		{ key = { th = "สวด", en = "Pray" }, th = "พนมมือเปิดตาทิพย์ ดูผี", en = "Pray to see ghosts" },
		{ key = { th = "นั่งยอง", en = "Crouch" }, th = "นั่งยองหลบผีใหญ่", en = "Crouch and hide from big ghosts" },
		{ key = { th = "ช่องด้านล่าง", en = "Bottom slots" }, th = "ไฟฉาย · ขนมไทย · แกลลอน", en = "Flashlight · Thai sweets · Jerry can" },
		{ key = { th = "แตะตรงไหนก็ได้", en = "Tap anywhere" }, th = "มินิเกม สูบ / อัดลม / สตาร์ทเครื่อง", en = "Minigames: pump / air / start the generator" },
		{ key = "✕", th = "ปิดมินิเกม", en = "Close a minigame" },
		{ key = { th = "แตะกล่องคำแนะนำ", en = "Tap the tips box" }, th = "ซ่อน / แสดงคำแนะนำ", en = "Hide / show tips" },
		{ key = { th = "ปุ่ม ข้าม", en = "Skip button" }, th = "โหวตข้ามคัทซีน (ทุกคนต้องโหวต)", en = "Vote to skip a cutscene (everyone must vote)" },
	}
else
	CONTROLS = {
		{ key = "WASD", th = "เดิน", en = "Move" },
		{ key = { th = "เมาส์", en = "Mouse" }, th = "มองรอบตัว", en = "Look around" },
		{ key = "V / Alt", th = "ปลดล็อกเมาส์", en = "Free the mouse" },
		{ key = { th = "E (กดค้าง)", en = "E (hold)" }, th = "ใช้ของ เติมน้ำมัน ดึงเชือก ถวาย", en = "Use, refuel, pull the rope, offer" },
		{ key = "G", th = "พนมมือเปิดตาทิพย์ ดูผี", en = "Pray to see ghosts" },
		{ key = "C", th = "นั่งยองหลบผีใหญ่", en = "Crouch and hide from big ghosts" },
		{ key = "1 · 2 · 3", th = "ไฟฉาย · ขนมไทย · แกลลอน", en = "Flashlight · Thai sweets · Jerry can" },
		{ key = { th = "Space / คลิก", en = "Space / Click" }, th = "มินิเกม สูบ / อัดลม / สตาร์ทเครื่อง", en = "Minigames: pump / air / start the generator" },
		{ key = "X", th = "ปิดมินิเกม", en = "Close a minigame" },
		{ key = "H", th = "ซ่อน / แสดงคำแนะนำ", en = "Hide / show tips" },
		{ key = "Enter", th = "โหวตข้ามคัทซีน (ทุกคนต้องโหวต)", en = "Vote to skip a cutscene (everyone must vote)" },
	}
end

local controlsPage = new("Frame", {
	Name = "Controls",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0, 460, 0.86, 0),
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(460, 520) }, controlsPage)
new("UIStroke", { Color = C.Line, Thickness = 1 }, controlsPage)
local controlsHeader = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = C.Bar,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	FontFace = FONT_BODY,
	TextColor3 = C.Cream,
	TextSize = 22,
}, controlsPage)
local controlsList = new("ScrollingFrame", {
	Position = UDim2.new(0, 0, 0, 40),
	Size = UDim2.new(1, 0, 1, -94),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = C.Line,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, controlsPage)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, controlsList)
new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }, controlsList)
for i, c in ipairs(CONTROLS) do
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = i }, controlsList)
	-- ปุ่ม/คีย์ซ้าย (ป้ายเข้ม ตัวครีม) · คำอธิบายขวา
	local keyLabel = new("TextLabel", {
		Size = UDim2.new(0, 132, 0, 26),
		Position = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = Color3.fromRGB(16, 14, 12),
		BorderSizePixel = 0,
		FontFace = FONT_BODY,
		TextColor3 = C.Cream,
		TextSize = 15,
		TextWrapped = true,
	}, r)
	new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, keyLabel)
	local desc = new("TextLabel", {
		Position = UDim2.new(0, 144, 0, 0),
		Size = UDim2.new(1, -144, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = FONT_BODY,
		TextColor3 = C.Dim,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, r)
	table.insert(refreshers, function()
		local th = lang() == "th"
		local k = c.key
		keyLabel.Text = if type(k) == "string" then k elseif th then k.th else k.en
		desc.Text = if th then c.th else c.en
	end)
end
local controlsBack = button(controlsPage, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0, 140, 0, 36),
})
-- แถวในหน้าตั้งค่า: "ปุ่มควบคุม  [ดู ▸]"
do
	local r = row(7, "Controls")
	local open = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 86, 0, 30) })
	open.Activated:Connect(function()
		panel.Visible = false
		controlsPage.Visible = true
	end)
	controlsBack.Activated:Connect(function()
		controlsPage.Visible = false
		panel.Visible = true
	end)
	table.insert(refreshers, function()
		open.Text = ui("ControlsOpen")
		controlsHeader.Text = ui("Controls")
		controlsBack.Text = ui("ControlsBack")
	end)
end

-- ปุ่มปิด ✕ มุมขวาบนของหัวหน้าต่าง (Modal = ปลดล็อกเมาส์ตอนเปิดหน้าตั้งค่า)
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
-- วาด X จากเส้น 2 เส้นไขว้กัน (ฟอนต์ไม่มีตัว ✕)
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
local function tintX(c: Color3)
	for _, l in ipairs(xLines) do
		l.BackgroundColor3 = c
	end
end
closeBtn.MouseEnter:Connect(function()
	tintX(Color3.fromRGB(220, 60, 50))
end)
closeBtn.MouseLeave:Connect(function()
	tintX(C.Dim)
end)
table.insert(refreshers, function()
	header.Text = ui("Settings")
	gear.Text = ui("Settings")
end)

local function refresh()
	for _, f in ipairs(refreshers) do
		f()
	end
end
refresh()
for _, a in ipairs({ "Lang", "ShowHUD", "ShowLabels", "FlashHand", "ShowTutorial" }) do
	localPlayer:GetAttributeChangedSignal(a):Connect(refresh)
end

local function setOpen(open: boolean)
	panel.Visible = open
	controlsPage.Visible = false
	gearOpen = open
	gear.BackgroundColor3 = if open then Color3.fromRGB(48, 22, 20) else Color3.fromRGB(16, 14, 12)
	gear.TextColor3 = if open then C.Cream else C.Dim
	if open then
		refresh()
	end
end
gear.Activated:Connect(function()
	setOpen(not panel.Visible)
end)
closeBtn.Activated:Connect(function()
	setOpen(false)
end)
