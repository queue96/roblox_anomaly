-- SettingsController.client.luau
-- ปุ่ม ⚙ มุมขวาบน เปิดหน้าตั้งค่า (สไตล์เดียวกับ HUD: แถบดำ หัวข้อเทาหม่น ตัวหนังสือครีม)
--   ภาษา ไทย/English · แสดงเงิน/ธูป/ปุ่ม (HUD) · มือถือไฟฉาย · สอนเล่น · ไฮไลต์งาน · ปุ่มควบคุม · ยอมแพ้
--   (ไม่มีปรับเสียงแล้ว ผู้ใช้ 2026-11-23: ความดังเพลง/เอฟเฟกต์ตายตัว MUSIC_LEVEL / SFX_LEVEL)
-- ค่าเก็บเป็น Attribute บน Player (Server จำลง DataStore ใน PlayerSettings.server.luau)
-- เสียง: แบ่งทุก Sound เข้า SoundGroup "Music" (วิทยุ/สวด) กับ "SFX" (ที่เหลือ) ความดังตายตัว (ผู้เล่นปรับเองไม่ได้)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
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

-- ความดังตายตัว = ค่าเริ่มต้นเดิมของแถบเลื่อน (เพลง 70% / เอฟเฟกต์ 80%) คูณ MASTER_SCALE 0.5 (ไม่ให้ดังแสบหู โดยเฉพาะตอนผีหลอก)
--   ค่าที่ผู้เล่นเคยเลื่อนไว้ (บันทึกใน DataStore) ไม่ใช้แล้ว
--   คูณตามอุปกรณ์ Shared.DeviceInfo.VolumeBoost (คอม 1.6 / มือถือ 3.0 / แท็บเล็ต 1.8)
-- ไม่มีโมดูล (เช่น place ที่ยังไม่ sync) = ไม่ค้าง ใช้ความดังเท่าคอม
local deviceModule = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DeviceInfo", 5)
local DeviceInfo = if deviceModule then require(deviceModule) :: any else nil
local MASTER_SCALE = 0.5
local MUSIC_LEVEL = 0.7
local SFX_LEVEL = 0.8
local function applyVolumes()
	local boost = if DeviceInfo then DeviceInfo.VolumeBoost() else 1
	musicGroup.Volume = MUSIC_LEVEL * MASTER_SCALE * boost
	sfxGroup.Volume = SFX_LEVEL * MASTER_SCALE * boost
end
applyVolumes()
-- ขนาดจอจริงมาทีหลังได้ (มือถือ/แท็บเล็ตตัดสินจากขนาดจอ): คิดใหม่เมื่อจอเปลี่ยน
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyVolumes)
end

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

-- (Lobby ที่ยังไม่ได้ sync ไฟล์ SafeArea: ไม่เว้นเพิ่ม แทนที่จะค้างรอ)
local safeMod = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SafeArea", 5)
local EDGE = if safeMod then (require(safeMod) :: any).Pad() else 0
-- ปุ่มตั้งค่า (ขนาดกะทัดรัด โทนดาร์กหม่นคุมธีมเดียวกับ HUD มุมขวาล่าง)
local gear = new("TextButton", {
	Name = "SettingsButton",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16 - EDGE, 0, 14), -- มือถือเว้นขอบเพิ่ม (shared/SafeArea)
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
	Size = UDim2.new(0, 560, 0, 0), -- (460 -> 560: ปุ่มภาษา 5 ปุ่ม 2026-11-23)
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.Ink,
	BackgroundTransparency = 0.05,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 10,
}, gui)
new("UIStroke", { Color = C.Line, Thickness = 1 }, panel)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, if Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y < 500 then 3 else 6) }, panel)
new("UIPadding", { PaddingBottom = UDim.new(0, if Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.Y < 500 then 8 else 14) }, panel)

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
-- จอเตี้ย (มือถือแนวนอน): แถวเตี้ยลง ให้ทุกแถว (รวมปุ่มยอมแพ้) อยู่ในจอ
local SHORT_SCREEN = Workspace.CurrentCamera ~= nil and Workspace.CurrentCamera.ViewportSize.Y < 500
local ROW_H = if SHORT_SCREEN then 31 else 40
local function row(order: number, labelKey: string): (Frame, TextLabel)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, ROW_H), BackgroundTransparency = 1, LayoutOrder = order }, panel)
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

-- ภาษา: ปุ่มละภาษา [ไทย] [English] [Indonesia] [Português] [Español] (LanguageModule.Langs ชื่อในภาษานั้นเอง)
do
	local r = row(1, "Language")
	local langs = LanguageModule.Langs
	local BTN_W, GAP = 78, 6
	local btns: { [string]: TextButton } = {}
	for i, code in ipairs(langs) do
		local b = button(r, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -(#langs - i) * (BTN_W + GAP), 0.5, 0),
			Size = UDim2.new(0, BTN_W, 0, 30),
			Text = LanguageModule.LangNames[code],
			TextSize = 14,
		})
		b.Activated:Connect(function()
			set("Lang", code)
		end)
		btns[code] = b
	end
	table.insert(refreshers, function()
		local cur = lang()
		for code, b in pairs(btns) do
			b.BackgroundColor3 = if code == cur then C.Blood else C.Ink
		end
	end)
end

-- (แถบเลื่อนเสียงเพลง / เสียงเอฟเฟกต์ ตัดออกแล้ว ผู้ใช้ 2026-11-23 "ไม่ให้ผู้เล่นปรับเสียงเอง": ความดังตายตัวที่ applyVolumes)

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
	toggle(7, "ShowTaskGlow", "ShowTaskGlow") -- ของที่ต้องทำเรืองแสง (TaskGlow)
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
type Control = { key: { [string]: string } | string, [string]: string } -- th / en / id / pt / es (ภาษาที่ไม่มี = อังกฤษ)
local CONTROLS: { Control }
if IN_LOBBY and IS_TOUCH then
	CONTROLS = {
		{ key = { th = "จอยซ้าย", en = "Left stick", id = "Joystick kiri", pt = "Joystick esquerdo", es = "Joystick izquierdo" }, th = "เดิน", en = "Move", id = "Berjalan", pt = "Andar", es = "Caminar" },
		{ key = { th = "ลากจอ", en = "Drag screen", id = "Geser layar", pt = "Arrastar a tela", es = "Arrastrar la pantalla" }, th = "หมุนกล้อง", en = "Turn the camera", id = "Putar kamera", pt = "Girar a câmera", es = "Girar la cámara" },
		{ key = { th = "ปุ่มกระโดด", en = "Jump button", id = "Tombol lompat", pt = "Botão de pulo", es = "Botón de salto" }, th = "กระโดด", en = "Jump", id = "Lompat", pt = "Pular", es = "Saltar" },
		{ key = { th = "วงแดง", en = "Red ring", id = "Lingkaran merah", pt = "Círculo vermelho", es = "Círculo rojo" }, th = "เดินเข้าวง สร้าง / ร่วมห้อง", en = "Walk in to host / join a room", id = "Masuk untuk membuat / bergabung ke room", pt = "Entre para criar / entrar numa sala", es = "Entra para crear / unirte a una sala" },
		{ key = { th = "สมุดผี", en = "Ghost Book", id = "Buku Hantu", pt = "Livro de Fantasmas", es = "Libro de Fantasmas" }, th = "ดูผีที่เคยรอดมาแล้ว", en = "See the ghosts you've survived", id = "Lihat hantu yang sudah kamu lewati", pt = "Veja os fantasmas que você sobreviveu", es = "Mira los fantasmas que sobreviviste" },
	}
elseif IN_LOBBY then
	CONTROLS = {
		{ key = "WASD", th = "เดิน", en = "Move", id = "Berjalan", pt = "Andar", es = "Caminar" },
		{ key = { th = "คลิกขวาค้าง + ลาก", en = "Hold right-click + drag", id = "Tahan klik kanan + geser", pt = "Segure o botão direito + arraste", es = "Mantén clic derecho + arrastra" }, th = "หมุนกล้อง", en = "Turn the camera", id = "Putar kamera", pt = "Girar a câmera", es = "Girar la cámara" },
		{ key = "Space", th = "กระโดด", en = "Jump", id = "Lompat", pt = "Pular", es = "Saltar" },
		{ key = { th = "วงแดง", en = "Red ring", id = "Lingkaran merah", pt = "Círculo vermelho", es = "Círculo rojo" }, th = "เดินเข้าวง สร้าง / ร่วมห้อง", en = "Walk in to host / join a room", id = "Masuk untuk membuat / bergabung ke room", pt = "Entre para criar / entrar numa sala", es = "Entra para crear / unirte a una sala" },
		{ key = { th = "สมุดผี", en = "Ghost Book", id = "Buku Hantu", pt = "Livro de Fantasmas", es = "Libro de Fantasmas" }, th = "ดูผีที่เคยรอดมาแล้ว", en = "See the ghosts you've survived", id = "Lihat hantu yang sudah kamu lewati", pt = "Veja os fantasmas que você sobreviveu", es = "Mira los fantasmas que sobreviviste" },
	}
elseif IS_TOUCH then
	CONTROLS = {
		{ key = { th = "จอยซ้าย", en = "Left stick", id = "Joystick kiri", pt = "Joystick esquerdo", es = "Joystick izquierdo" }, th = "เดิน", en = "Move", id = "Berjalan", pt = "Andar", es = "Caminar" },
		{ key = { th = "ลากจอ", en = "Drag screen", id = "Geser layar", pt = "Arrastar a tela", es = "Arrastrar la pantalla" }, th = "มองรอบตัว", en = "Look around", id = "Melihat sekeliling", pt = "Olhar em volta", es = "Mirar alrededor" },
		{ key = { th = "ปุ่มที่ขึ้นมา", en = "Pop-up button", id = "Tombol yang muncul", pt = "Botão que aparece", es = "Botón que aparece" }, th = "แตะ / แตะค้าง ใช้ของ เติมน้ำมัน ดึงเชือก ถวาย", en = "Tap / hold to use, refuel, pull the rope, offer", id = "Sentuh / tahan untuk memakai, isi bensin, tarik tali, persembahkan", pt = "Toque / segure para usar, abastecer, puxar a corda, oferecer", es = "Toca / mantén para usar, cargar gasolina, jalar la cuerda, ofrecer" },
		{ key = { th = "สวด", en = "Pray", id = "Berdoa", pt = "Rezar", es = "Rezar" }, th = "พนมมือเปิดตาทิพย์ ดูผี", en = "Pray to see ghosts", id = "Berdoa untuk melihat hantu", pt = "Reze para ver fantasmas", es = "Reza para ver fantasmas" },
		{ key = { th = "นั่งยอง", en = "Crouch", id = "Jongkok", pt = "Agachar", es = "Agacharse" }, th = "นั่งยอง", en = "Crouch", id = "Jongkok", pt = "Agachar", es = "Agacharse" },
		{ key = { th = "ช่องด้านล่าง", en = "Bottom slots", id = "Slot bawah", pt = "Slots de baixo", es = "Espacios de abajo" }, th = "ไฟฉาย · ขนมไทย · แกลลอน", en = "Flashlight · Thai sweets · Jerry can", id = "Senter · Kue Thailand · Jeriken", pt = "Lanterna · Doces tailandeses · Galão", es = "Linterna · Dulces tailandeses · Bidón" },
		{ key = { th = "แตะตรงไหนก็ได้", en = "Tap anywhere", id = "Sentuh di mana saja", pt = "Toque em qualquer lugar", es = "Toca en cualquier lugar" }, th = "มินิเกม สูบ / อัดลม / สตาร์ทเครื่อง", en = "Minigames: pump / air / start the generator", id = "Minigame: pompa / angin / nyalakan genset", pt = "Minijogos: bombear / ar / ligar o gerador", es = "Minijuegos: bombear / aire / arrancar el generador" },
		{ key = "✕", th = "ปิดมินิเกม", en = "Close a minigame", id = "Tutup minigame", pt = "Fechar um minijogo", es = "Cerrar un minijuego" },
		{ key = { th = "แตะกล่องคำแนะนำ", en = "Tap the tips box", id = "Sentuh kotak tips", pt = "Toque na caixa de dicas", es = "Toca el cuadro de consejos" }, th = "ซ่อน / แสดงคำแนะนำ", en = "Hide / show tips", id = "Sembunyikan / tampilkan tips", pt = "Ocultar / mostrar dicas", es = "Ocultar / mostrar consejos" },
		{ key = { th = "ปุ่ม ข้าม", en = "Skip button", id = "Tombol Lewati", pt = "Botão Pular", es = "Botón Saltar" }, th = "โหวตข้ามคัทซีน (ทุกคนต้องโหวต)", en = "Vote to skip a cutscene (everyone must vote)", id = "Pilih lewati cutscene (semua harus memilih)", pt = "Votar para pular a cena (todos precisam votar)", es = "Votar para saltar la escena (todos deben votar)" },
	}
else
	CONTROLS = {
		{ key = "WASD", th = "เดิน", en = "Move", id = "Berjalan", pt = "Andar", es = "Caminar" },
		{ key = { th = "เมาส์", en = "Mouse", id = "Mouse", pt = "Mouse", es = "Mouse" }, th = "มองรอบตัว", en = "Look around", id = "Melihat sekeliling", pt = "Olhar em volta", es = "Mirar alrededor" },
		{ key = "V / Alt", th = "ปลดล็อกเมาส์", en = "Free the mouse", id = "Lepas mouse", pt = "Soltar o mouse", es = "Liberar el mouse" },
		{ key = { th = "E (กดค้าง)", en = "E (hold)", id = "E (tahan)", pt = "E (segurar)", es = "E (mantener)" }, th = "ใช้ของ เติมน้ำมัน ดึงเชือก ถวาย", en = "Use, refuel, pull the rope, offer", id = "Pakai, isi bensin, tarik tali, persembahkan", pt = "Usar, abastecer, puxar a corda, oferecer", es = "Usar, cargar gasolina, jalar la cuerda, ofrecer" },
		{ key = "G", th = "พนมมือเปิดตาทิพย์ ดูผี", en = "Pray to see ghosts", id = "Berdoa untuk melihat hantu", pt = "Reze para ver fantasmas", es = "Reza para ver fantasmas" },
		{ key = "C", th = "นั่งยอง", en = "Crouch", id = "Jongkok", pt = "Agachar", es = "Agacharse" },
		{ key = "1 · 2 · 3", th = "ไฟฉาย · ขนมไทย · แกลลอน", en = "Flashlight · Thai sweets · Jerry can", id = "Senter · Kue Thailand · Jeriken", pt = "Lanterna · Doces tailandeses · Galão", es = "Linterna · Dulces tailandeses · Bidón" },
		{ key = { th = "Space / คลิก", en = "Space / Click", id = "Space / Klik", pt = "Space / Clique", es = "Space / Clic" }, th = "มินิเกม สูบ / อัดลม / สตาร์ทเครื่อง", en = "Minigames: pump / air / start the generator", id = "Minigame: pompa / angin / nyalakan genset", pt = "Minijogos: bombear / ar / ligar o gerador", es = "Minijuegos: bombear / aire / arrancar el generador" },
		{ key = "X", th = "ปิดมินิเกม", en = "Close a minigame", id = "Tutup minigame", pt = "Fechar um minijogo", es = "Cerrar un minijuego" },
		{ key = "H", th = "ซ่อน / แสดงคำแนะนำ", en = "Hide / show tips", id = "Sembunyikan / tampilkan tips", pt = "Ocultar / mostrar dicas", es = "Ocultar / mostrar consejos" },
		{ key = "Enter", th = "โหวตข้ามคัทซีน (ทุกคนต้องโหวต)", en = "Vote to skip a cutscene (everyone must vote)", id = "Pilih lewati cutscene (semua harus memilih)", pt = "Votar para pular a cena (todos precisam votar)", es = "Votar para saltar la escena (todos deben votar)" },
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
		local k = c.key
		keyLabel.Text = if type(k) == "string" then k else LanguageModule.Pick(k, lang())
		desc.Text = LanguageModule.Pick(c, lang())
	end)
end
local controlsBack = button(controlsPage, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.new(0, 140, 0, 36),
})
-- แถวในหน้าตั้งค่า: "ปุ่มควบคุม  [ดู ▸]"
do
	local r = row(8, "Controls")
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

-- ยอมแพ้ระหว่างเล่น (เฉพาะในเกม): กลับ Lobby คนเดียว เพื่อนในร้านเล่นต่อได้
--   แตะครั้งแรก = ถามยืนยัน (4 วิ) แตะอีกครั้ง = ส่ง "quit" (server/CoreLoop: DeathChoice -> backToLobby)
if not IN_LOBBY then
	local r = row(9, "GiveUp")
	local quitBtn = button(r, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 150, 0, 30) })
	local armed = false
	local sent = false
	local function draw()
		quitBtn.Text = ui(if armed then "GiveUpConfirm" else "GiveUpBtn")
		quitBtn.BackgroundColor3 = if armed then C.Blood else C.Ink
	end
	quitBtn.Activated:Connect(function()
		if sent then
			return
		end
		if not armed then
			armed = true
			draw()
			task.delay(4, function()
				if armed and not sent then
					armed = false
					draw()
				end
			end)
			return
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local dc = remotes and remotes:FindFirstChild("DeathChoice")
		if dc and dc:IsA("RemoteEvent") then
			sent = true
			quitBtn.Text = ui("GoingToLobby")
			local leaving = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeavingScreen")) :: any
			leaving.Show() -- จอดำ "กำลังกลับวัด..." ไม่ให้ดูเหมือนค้าง
			dc:FireServer("quit")
		end
	end)
	table.insert(refreshers, function()
		if not sent then
			draw()
		end
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
