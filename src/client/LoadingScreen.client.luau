-- LoadingScreen.client.luau
-- 1) ตอนเข้าแมพ Lobby (เข้าเกมครั้งแรก): แสดงหน้าจอโหลดทรัพยากรพร้อม Progress Bar 0-100% + ปุ่มข้าม (Skip)
-- 2) ตอนโหลดเข้าแมพเล่นจริง (Pump Lot): แสดงเฉพาะภาพ Key Art + ชื่อฉาก/คำแนะนำ (ไม่มีหลอดโหลดทรัพยากร) ค้างไว้อย่างน้อย 3 วินาทีให้พร้อมกันก่อนเข้าเกม
-- 3) ตอนวาร์ปข้าม Place (Lobby <-> Pump Lot): แสดงหน้าจอคั่นภาพ Key Art ระดับมืออาชีพผ่าน TeleportService:SetTeleportGui

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ภาพประกอบฉากหลังปั๊มหลอด & วัดท้ายทุ่งยามเที่ยงคืน (อัปโหลดไว้บน Roblox Asset Server)
local KEY_ART_ID = "rbxassetid://98063047584423"
local LOBBY_PLACE_ID = 70980777393906
local GAME_SPLASH_MIN_SECONDS = 1.2
local INTRO_MUSIC_ID = "rbxassetid://112002298210648" -- เพลงเปิดตอนโหลดเข้าแมพปั๊ม (เจ้าของเกมอัปโหลด)
local INTRO_MUSIC_VOLUME = 0.5
local INTRO_FADE = 4 -- วินาทีที่เพลงเปิดค่อยๆ เบาลงหลังโหลดเสร็จ

local FONT_TITLE = Font.new("rbxasset://fonts/families/Srisakdi.json", Enum.FontWeight.Bold)
local FONT_BODY = Font.new("rbxasset://fonts/families/Sarabun.json", Enum.FontWeight.Regular)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Sarabun.json", Enum.FontWeight.Bold)

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(16, 14, 12),
	BarBg = Color3.fromRGB(34, 30, 26),
	Line = Color3.fromRGB(92, 82, 66),
	Gold = Color3.fromRGB(228, 196, 128),
	Cream = Color3.fromRGB(238, 230, 212),
	Dim = Color3.fromRGB(172, 162, 144),
	Blood = Color3.fromRGB(168, 36, 28),
}

-- ภาษาผู้เล่น (หน้าโหลดขึ้นก่อน Shared.LanguageModule จะโหลด: เลือกภาษาเองตรงนี้ ชุดเดียวกับ LanguageModule.Langs)
local LANGS = { th = true, en = true, id = true, pt = true, es = true }
local function langCode(): string
	local l = string.sub(string.lower(tostring(player:GetAttribute("Lang") or "th")), 1, 2)
	return if LANGS[l] then l else "en"
end

-- more = ภาษาอื่น { id = "...", pt = "...", es = "..." } ไม่ใส่ = อังกฤษ
local function tr(th: string, en: string, more: { [string]: string }?): string
	local l = langCode()
	if l == "th" then
		return th
	end
	return if more and more[l] then more[l] else en
end

local function isLobbyPlace(): boolean
	if game.PlaceId == LOBBY_PLACE_ID then
		return true
	end
	if game.PlaceId ~= 0 and game.PlaceId ~= LOBBY_PLACE_ID then
		return false
	end
	return Workspace:FindFirstChild("TempleLobby") ~= nil
end

-- คำแนะนำบนหน้าโหลด (ตรงกับเกมปัจจุบัน: CoreLoop.CONFIG / ItemSlots / PrayerController)
--   thTouch / enTouch = ข้อความสำหรับมือถือ (แตะปุ่มแทนการกดคีย์) / lobby = แสดงเฉพาะตอนโหลดเข้า Lobby
local TIPS = {
	{
		th = "คำแนะนำ: กด G เพื่อพนมมือเปิดตาทิพย์ ส่องดูความผิดปกติที่ตาเปล่ามองไม่เห็น",
		en = "Tip: Press G to put your hands together in prayer and reveal hidden anomalies.",
		id = "Tips: Tekan G untuk merapatkan tangan dan berdoa, memperlihatkan kejanggalan yang tersembunyi.", pt = "Dica: Aperte G para juntar as mãos e rezar, revelando anomalias escondidas.", es = "Consejo: Presiona G para juntar las manos y rezar, revelando anomalías ocultas.",
		thTouch = "คำแนะนำ: แตะปุ่ม สวด เพื่อพนมมือเปิดตาทิพย์ ส่องดูความผิดปกติที่ตาเปล่ามองไม่เห็น",
		enTouch = "Tip: Tap the Pray button to put your hands together and reveal hidden anomalies.",
		idTouch = "Tips: Sentuh tombol Berdoa untuk merapatkan tangan dan memperlihatkan kejanggalan yang tersembunyi.", ptTouch = "Dica: Toque no botão Rezar para juntar as mãos e revelar anomalias escondidas.", esTouch = "Consejo: Toca el botón Rezar para juntar las manos y revelar anomalías ocultas.",
	},
	{
		th = "คำแนะนำ: หากพบความผิดปกติ ห้ามเติมน้ำมันเด็ดขาด ให้รีบไปดึงเชือกปิดแผงสังกะสีหน้าร้าน",
		en = "Tip: If you spot an anomaly, NEVER refuel them — pull the rope to close the tin shutter.",
		id = "Tips: Kalau melihat kejanggalan, JANGAN isi bensinnya — tarik tali untuk menutup pintu seng.", pt = "Dica: Se notar uma anomalia, NUNCA abasteça — puxe a corda para fechar o portão de zinco.", es = "Consejo: Si ves una anomalía, NUNCA le cargues gasolina — jala la cuerda para bajar la cortina de lámina.",
	},
	{
		th = "คำแนะนำ: ธูป 3 ดอกที่ศาลพระภูมิคือชีวิตของทีม เผลอเติมน้ำมันให้ผีเมื่อไร ธูปจะดับทีละดอก",
		en = "Tip: The 3 incense sticks at the spirit house are your team's lives. Serve a ghost and one goes out.",
		id = "Tips: 3 batang dupa di rumah arwah adalah nyawa timmu. Layani hantu, satu batang padam.", pt = "Dica: Os 3 incensos da casa dos espíritos são as vidas do seu time. Atenda um fantasma e um apaga.", es = "Consejo: Los 3 inciensos de la casa de los espíritus son las vidas de tu equipo. Atiende a un fantasma y uno se apaga.",
	},
	{
		th = "คำแนะนำ: สังเกตป้ายทะเบียน เสียงวิทยุ เงาในดงกล้วย และสีน้ำมันในหลอดแก้วให้ดี",
		en = "Tip: Check license plates, the radio, the banana grove and the fuel in the glass cylinder carefully.",
		id = "Tips: Perhatikan baik-baik plat nomor, radio, kebun pisang, dan bensin di tabung kaca.", pt = "Dica: Repare bem nas placas, no rádio, no bananal e na gasolina do cilindro de vidro.", es = "Consejo: Fíjate bien en las placas, la radio, el platanal y la gasolina del cilindro de vidrio.",
	},
	{
		th = "คำแนะนำ: เก็บเงินให้ครบ 1,200 บาทก่อนธูปทั้ง 3 ดอกจะดับ เพื่อเอาชีวิตรอดผ่านคืนนี้",
		en = "Tip: Earn 1,200 Baht before all 3 incense sticks go out to survive the night.",
		id = "Tips: Kumpulkan 1.200 Baht sebelum ketiga batang dupa padam untuk selamat malam ini.", pt = "Dica: Junte 1.200 Baht antes que os 3 incensos apaguem para sobreviver à noite.", es = "Consejo: Junta 1,200 Baht antes de que se apaguen los 3 inciensos para sobrevivir a la noche.",
	},
	{
		th = "คำแนะนำ: เริ่มคืนมาไฟดับ กด 1 เปิดไฟฉาย ดึงเชือกเปิดร้าน แล้วรีบไปสตาร์ทเครื่องปั่นไฟ",
		en = "Tip: The night starts in a blackout — press 1 for your flashlight, open the shutter, then start the generator.",
		id = "Tips: Malam dimulai saat listrik padam — tekan 1 untuk senter, buka pintu seng, lalu nyalakan genset.", pt = "Dica: A noite começa sem luz — aperte 1 para a lanterna, abra o portão e ligue o gerador.", es = "Consejo: La noche empieza sin luz — presiona 1 para la linterna, sube la cortina y arranca el generador.",
		thTouch = "คำแนะนำ: เริ่มคืนมาไฟดับ แตะช่องไฟฉาย ดึงเชือกเปิดร้าน แล้วรีบไปสตาร์ทเครื่องปั่นไฟ",
		enTouch = "Tip: The night starts in a blackout — tap the flashlight slot, open the shutter, then start the generator.",
		idTouch = "Tips: Malam dimulai saat listrik padam — sentuh slot senter, buka pintu seng, lalu nyalakan genset.", ptTouch = "Dica: A noite começa sem luz — toque no slot da lanterna, abra o portão e ligue o gerador.", esTouch = "Consejo: La noche empieza sin luz — toca el espacio de la linterna, sube la cortina y arranca el generador.",
	},
	{
		th = "คำแนะนำ: เอาขนมไทย (ช่อง 2) ไปถวายศาลพระภูมิเป็นระยะ ไม่งั้นจะโดนหลอกไม่หยุด",
		en = "Tip: Keep offering Thai sweets (slot 2) at the spirit house, or the haunting won't stop.",
		id = "Tips: Terus persembahkan kue Thailand (slot 2) di rumah arwah, kalau tidak gangguan hantu tak akan berhenti.", pt = "Dica: Continue oferecendo doces tailandeses (slot 2) na casa dos espíritos, ou as assombrações não vão parar.", es = "Consejo: Sigue ofreciendo dulces tailandeses (espacio 2) en la casa de los espíritus, o los sustos no van a parar.",
		thTouch = "คำแนะนำ: แตะช่องขนมไทย แล้วไปถวายศาลพระภูมิเป็นระยะ ไม่งั้นจะโดนหลอกไม่หยุด",
		enTouch = "Tip: Tap the Thai sweets slot and keep offering them at the spirit house, or the haunting won't stop.",
		idTouch = "Tips: Sentuh slot kue Thailand dan terus persembahkan di rumah arwah, kalau tidak gangguan hantu tak akan berhenti.", ptTouch = "Dica: Toque no slot dos doces tailandeses e continue oferecendo na casa dos espíritos, ou as assombrações não vão parar.", esTouch = "Consejo: Toca el espacio de los dulces tailandeses y sigue ofreciéndolos en la casa de los espíritus, o los sustos no van a parar.",
	},
	{
		th = "คำแนะนำ: น้ำมันในตู้หมดได้ หยิบแกลลอน (ช่อง 3) ไปตักจากถังหลังร้าน แล้วมาเทใส่ตู้",
		en = "Tip: Pumps run dry — grab the jerry can (slot 3), fill it at the drum behind the shop, and pour it in.",
		id = "Tips: Pompa bisa kosong — ambil jeriken (slot 3), isi di drum belakang toko, lalu tuang ke pompa.", pt = "Dica: As bombas secam — pegue o galão (slot 3), encha no tambor atrás da loja e despeje na bomba.", es = "Consejo: Las bombas se vacían — toma el bidón (espacio 3), llénalo en el barril detrás de la tienda y viértelo en la bomba.",
		thTouch = "คำแนะนำ: น้ำมันในตู้หมดได้ แตะช่องแกลลอน ไปตักจากถังหลังร้าน แล้วมาเทใส่ตู้",
		enTouch = "Tip: Pumps run dry — tap the jerry can slot, fill it at the drum behind the shop, and pour it in.",
		idTouch = "Tips: Pompa bisa kosong — sentuh slot jeriken, isi di drum belakang toko, lalu tuang ke pompa.", ptTouch = "Dica: As bombas secam — toque no slot do galão, encha no tambor atrás da loja e despeje na bomba.", esTouch = "Consejo: Las bombas se vacían — toca el espacio del bidón, llénalo en el barril detrás de la tienda y viértelo en la bomba.",
	},
	-- ---- Lobby
	{
		lobby = true,
		th = "คำแนะนำ: เดินเข้าวงแดงเพื่อสร้างห้อง เพื่อนเดินเข้าวงเดียวกันเพื่อร่วมทีมได้จนกว่าห้องจะเต็ม",
		en = "Tip: Walk into a red ring to host a room. Friends walk into the same ring to join until it's full.",
		id = "Tips: Masuk ke lingkaran merah untuk membuat room. Teman masuk ke lingkaran yang sama untuk bergabung sampai penuh.", pt = "Dica: Entre num círculo vermelho para criar uma sala. Os amigos entram no mesmo círculo até lotar.", es = "Consejo: Entra a un círculo rojo para crear una sala. Tus amigos entran al mismo círculo hasta que se llene.",
	},
	{
		lobby = true,
		th = "คำแนะนำ: เปิดสมุดผีมุมขวาบน ดูผีที่เคยรอดมาแล้ว และวิธีสังเกตของแต่ละตัว",
		en = "Tip: Open the Ghost Book (top right) to see the ghosts you've survived and how to spot them.",
		id = "Tips: Buka Buku Hantu (kanan atas) untuk melihat hantu yang sudah kamu lewati dan cara mengenalinya.", pt = "Dica: Abra o Livro de Fantasmas (canto superior direito) para ver os fantasmas que você sobreviveu e como reconhecê-los.", es = "Consejo: Abre el Libro de Fantasmas (arriba a la derecha) para ver los fantasmas que sobreviviste y cómo reconocerlos.",
	},
	{
		lobby = true,
		th = "คำแนะนำ: ป้ายอันดับในวัดบอกคนที่ทำบุญมากที่สุด จบเกมมากที่สุด และสะสมผีได้มากที่สุด",
		en = "Tip: The boards in the temple rank top donors, most nights survived and most ghosts collected.",
		id = "Tips: Papan di kuil memeringkat donatur terbanyak, malam selamat terbanyak, dan hantu terkumpul terbanyak.", pt = "Dica: Os quadros do templo mostram quem mais doou, quem mais sobreviveu e quem mais coletou fantasmas.", es = "Consejo: Los tableros del templo muestran a quién más donó, quién más noches sobrevivió y quién más fantasmas reunió.",
	},
}

-- หน้าโหลดแบบใหม่ (ผู้ใช้ 2026-11-23): จอดำ + ฉากเส้นขาวของแมพเรา ไม่ต้องอัปโหลดรูป (ประกอบจาก Frame ทั้งหมด)
--   ชาวบ้านหิ้วแกลลอนวิ่งไปตู้ปั๊มหลอด (ยิ่งโหลดยิ่งเข้าใกล้ตู้) · น้ำมันในหลอดแก้ว = แถบโหลด
--   ตาผีแอบมองจากดงกล้วย · ศาลพระภูมิธูป 3 ดอก · หลอดไฟห้อยแกว่ง
--   ฉากวาดในพิกัด 320 x 180 (อัตราส่วน 16:9) แล้วย่อ/ขยายตามจอ
local SCENE_W, SCENE_H = 320, 180
local WHITE = Color3.fromRGB(255, 255, 255)
local AMBER = Color3.fromRGB(224, 164, 58)
local EMBER = Color3.fromRGB(255, 122, 46)
local BULB = Color3.fromRGB(255, 244, 204)

local function makeLoadingGui(name: string): (ScreenGui, { [string]: any })
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.IgnoreGuiInset = true
	sg.ScreenInsets = Enum.ScreenInsets.None -- เต็มจอจริงถึงขอบ
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.new(0, 0, 0)
	root.BorderSizePixel = 0
	root.Parent = sg

	-- ภาพ Key Art เดิม: ไม่ใช้บนหน้าโหลดแบบใหม่แล้ว (เก็บ object ไว้ให้โค้ดเก่าที่อ้างถึงไม่พัง)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "KeyArt"
	bgImage.Visible = false
	bgImage.BackgroundTransparency = 1
	bgImage.Parent = root

	-- ---------------------------------------------------------------- ฉาก
	local scene = Instance.new("Frame")
	scene.Name = "Scene"
	scene.AnchorPoint = Vector2.new(0.5, 0.5)
	scene.Position = UDim2.fromScale(0.5, 0.4)
	scene.Size = UDim2.fromScale(0.92, 0.62)
	scene.BackgroundTransparency = 1
	scene.Parent = root
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = SCENE_W / SCENE_H
	aspect.Parent = scene

	-- ชิ้นในฉาก: x, y = จุดกึ่งกลาง (หน่วยฉาก) · w, h = ขนาด · rot = องศา
	local function piece(nm: string, x: number, y: number, w: number, h: number, color: Color3, opts: { [string]: any }?): Frame
		local f = Instance.new("Frame")
		f.Name = nm
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x / SCENE_W, y / SCENE_H)
		f.Size = UDim2.fromScale(w / SCENE_W, h / SCENE_H)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.BackgroundTransparency = (opts and opts.transparency) or 0
		f.Rotation = (opts and opts.rot) or 0
		if opts and opts.round then
			local c = Instance.new("UICorner")
			c.CornerRadius = if opts.round == true then UDim.new(0.5, 0) else UDim.new(opts.round, 0)
			c.Parent = f
		end
		if opts and opts.outline then
			f.BackgroundTransparency = 1
			local s = Instance.new("UIStroke")
			s.Color = color
			s.Thickness = opts.outline
			s.Transparency = (opts and opts.strokeTransparency) or 0
			s.Parent = f
		end
		f.ZIndex = (opts and opts.z) or 2
		f.Parent = scene
		return f
	end
	-- เส้นตรงจากจุด a ไป b (หน่วยฉาก): แท่งบางหมุนตามมุม (ฉากล็อก 16:9 จึงคำนวณในหน่วยฉากได้ตรง)
	local function line(nm: string, ax: number, ay: number, bx: number, by: number, thick: number, transparency: number?): Frame
		local dx, dy = bx - ax, by - ay
		local len = math.sqrt(dx * dx + dy * dy)
		return piece(nm, (ax + bx) / 2, (ay + by) / 2, len, thick, WHITE, { rot = math.deg(math.atan2(dy, dx)), round = true, transparency = transparency })
	end

	-- ดงกล้วยซ้าย: ลำต้น 2 ท่อน + ใบ 4 ใบ (วงรีเส้นขอบ)
	line("BananaTrunk1", 38, 124, 44, 98, 1.3, 0.5)
	line("BananaTrunk2", 44, 98, 52, 74, 1.3, 0.5)
	piece("Leaf1", 37, 77, 34, 7, WHITE, { rot = 20, round = true, outline = 1, strokeTransparency = 0.5 })
	piece("Leaf2", 67, 67, 32, 7, WHITE, { rot = -12, round = true, outline = 1, strokeTransparency = 0.5 })
	piece("Leaf3", 37, 97, 26, 6, WHITE, { rot = -55, round = true, outline = 1, strokeTransparency = 0.5 })
	piece("Leaf4", 60, 84, 22, 6, WHITE, { rot = 35, round = true, outline = 1, strokeTransparency = 0.6 })
	local eyeL = piece("GhostEyeL", 60, 92, 4, 2.4, WHITE, { round = true, z = 3 })
	local eyeR = piece("GhostEyeR", 66, 92, 4, 2.4, WHITE, { round = true, z = 3 })

	-- หลอดไฟห้อย (แกว่ง: Heartbeat ด้านล่าง)
	local bulbCord = line("BulbCord", 150, 0, 150, 22, 0.8, 0.5)
	local bulb = piece("Bulb", 150, 25, 6, 6, BULB, { round = true })

	-- พื้น: ขีดประเลื่อนไปทางซ้าย
	local dashes: { Frame } = {}
	for i = 0, 9 do
		table.insert(dashes, piece("GroundDash" .. i, 50 + i * 26, 124, 6 + (i % 3) * 3, 1.2, WHITE, { transparency = 0.7 }))
	end

	-- ตู้ปั๊มหลอดแก้ว: น้ำมันในหลอด = แถบโหลด (barTrack / barFill ชื่อเดิม)
	piece("PumpCap", 199, 73, 18, 6, WHITE, { round = 0.25 })
	local tube = piece("PumpTube", 199, 98, 14, 44, WHITE, { outline = 1.2, round = 0.12, z = 3 })
	tube.ClipsDescendants = true
	local fuel = Instance.new("Frame")
	fuel.Name = "Fuel"
	fuel.AnchorPoint = Vector2.new(0, 1)
	fuel.Position = UDim2.fromScale(0, 1)
	fuel.Size = UDim2.fromScale(1, 0.05)
	fuel.BackgroundColor3 = AMBER
	fuel.BorderSizePixel = 0
	fuel.ZIndex = 2
	fuel.Parent = tube
	piece("PumpBase", 199, 122.5, 20, 5, WHITE, { round = 0.2 })
	line("Hose1", 206, 84, 213, 88, 1.2)
	line("Hose2", 213, 88, 212, 99, 1.2)
	piece("Nozzle", 212, 100.5, 4, 3, WHITE)

	-- ศาลพระภูมิขวา: เสา + หลังคา + ตัวศาล + ชั้นวาง + ธูป 3 ดอก
	piece("ShrinePost", 263, 110, 2.2, 28, WHITE, { transparency = 0.2 })
	line("RoofL", 250, 96, 263, 84, 1.6)
	line("RoofR", 263, 84, 276, 96, 1.6)
	piece("ShrineBox", 263, 101, 20, 10, WHITE, { outline = 1.2 })
	piece("ShrineShelf", 263, 110, 10, 2, WHITE)
	line("Incense1", 260, 109, 259, 102, 0.8)
	line("Incense2", 263, 109, 263, 101, 0.8)
	line("Incense3", 266, 109, 267, 102, 0.8)
	local embers = {
		piece("Ember1", 259, 101.5, 2.4, 2.4, EMBER, { round = true, z = 3 }),
		piece("Ember2", 263, 100.5, 2.4, 2.4, EMBER, { round = true, z = 3 }),
		piece("Ember3", 267, 101.5, 2.4, 2.4, EMBER, { round = true, z = 3 }),
	}

	-- ชาวบ้านหิ้วแกลลอน (ขยับทุกเฟรมด้านล่าง)
	local runner = {
		head = piece("RunnerHead", 120, 88, 13, 13, WHITE, { round = true, z = 4 }),
		eye = piece("RunnerEye", 123, 87, 2.2, 2.2, Color3.new(0, 0, 0), { round = true, z = 5 }),
		body = piece("RunnerBody", 120, 102.5, 9, 15, WHITE, { round = 0.45, z = 4 }),
		legA = piece("RunnerLegA", 118, 116, 3, 13, WHITE, { round = true, z = 3 }),
		legB = piece("RunnerLegB", 122, 116, 3, 13, WHITE, { round = true, z = 3 }),
		arm = piece("RunnerArm", 125, 103, 2.6, 9, WHITE, { round = true, z = 5 }),
		can = piece("JerryCan", 128, 112, 9, 10, WHITE, { round = 0.15, z = 5 }),
		spout = piece("JerryCanSpout", 131, 106, 2, 3, WHITE, { z = 5 }),
	}

	-- ---------------------------------------------------------------- ข้อความใต้ฉาก
	local bottomPanel = Instance.new("Frame")
	bottomPanel.Name = "BottomPanel"
	bottomPanel.AnchorPoint = Vector2.new(0.5, 0)
	bottomPanel.Position = UDim2.fromScale(0.5, 0.72)
	bottomPanel.Size = UDim2.fromScale(0.86, 0.2)
	bottomPanel.BackgroundTransparency = 1
	bottomPanel.Parent = root
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = bottomPanel

	local function textLine(nm: string, order: number, font: Font, color: Color3, size: number, transparency: number?): TextLabel
		local t = Instance.new("TextLabel")
		t.Name = nm
		t.LayoutOrder = order
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.FontFace = font
		t.TextColor3 = color
		t.TextTransparency = transparency or 0
		t.TextSize = size
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.Text = ""
		t.Parent = bottomPanel
		return t
	end
	local title = textLine("GameTitle", 1, FONT_BOLD, WHITE, 22)
	local subtitle = textLine("Subtitle", 2, FONT_BODY, WHITE, 15, 0.45)
	-- สถานะ + เปอร์เซ็นต์อยู่บรรทัดเดียวกัน
	local statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.LayoutOrder = 3
	statusRow.BackgroundTransparency = 1
	statusRow.Size = UDim2.new(1, 0, 0, 22)
	statusRow.Parent = bottomPanel
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.Padding = UDim.new(0, 10)
	rowList.Parent = statusRow
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.BackgroundTransparency = 1
	statusLabel.Size = UDim2.new(0, 0, 1, 0)
	statusLabel.AutomaticSize = Enum.AutomaticSize.X
	statusLabel.FontFace = FONT_BODY
	statusLabel.TextColor3 = WHITE
	statusLabel.TextTransparency = 0.2
	statusLabel.TextSize = 15
	statusLabel.Text = ""
	statusLabel.Parent = statusRow
	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "PercentLabel"
	percentLabel.BackgroundTransparency = 1
	percentLabel.Size = UDim2.new(0, 0, 1, 0)
	percentLabel.AutomaticSize = Enum.AutomaticSize.X
	percentLabel.FontFace = FONT_BOLD
	percentLabel.TextColor3 = AMBER
	percentLabel.TextSize = 16
	percentLabel.Text = "0%"
	percentLabel.Parent = statusRow
	local tipLabel = textLine("TipLabel", 4, FONT_BODY, WHITE, 14, 0.5)

	-- มุมล่าง: ชื่อด้านซ้าย (badge เดิม) + ปุ่มข้ามด้านขวา
	local badge = Instance.new("TextLabel")
	badge.Name = "PlaceBadge"
	badge.AnchorPoint = Vector2.new(0, 1)
	badge.Position = UDim2.new(0, 28, 1, -22)
	badge.Size = UDim2.new(0.5, 0, 0, 18)
	badge.BackgroundTransparency = 1
	badge.FontFace = FONT_BODY
	badge.TextColor3 = WHITE
	badge.TextTransparency = 0.65
	badge.TextSize = 13
	badge.TextXAlignment = Enum.TextXAlignment.Left
	badge.Text = ""
	badge.Parent = root

	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 1)
	skipBtn.Position = UDim2.new(1, -28, 1, -16)
	skipBtn.Size = UDim2.new(0, 110, 0, 32)
	skipBtn.BackgroundTransparency = 1
	skipBtn.AutoButtonColor = false
	skipBtn.FontFace = FONT_BODY
	skipBtn.TextColor3 = WHITE
	skipBtn.TextTransparency = 0.45
	skipBtn.TextSize = 15
	skipBtn.TextXAlignment = Enum.TextXAlignment.Right
	skipBtn.Text = tr("ข้าม ›", "Skip ›", { id = "Lewati ›", pt = "Pular ›", es = "Saltar ›" })
	skipBtn.Parent = root
	skipBtn.MouseEnter:Connect(function()
		skipBtn.TextTransparency = 0
	end)
	skipBtn.MouseLeave:Connect(function()
		skipBtn.TextTransparency = 0.45
	end)

	-- จอเตี้ย (มือถือแนวนอน): ตัวหนังสือเล็กลงตามความสูงจอ
	local function fitText()
		local h = root.AbsoluteSize.Y
		if h <= 0 then
			return
		end
		local k = math.clamp(h / 720, 0.72, 1.25)
		title.TextSize = math.floor(22 * k)
		subtitle.TextSize = math.floor(15 * k)
		statusLabel.TextSize = math.floor(15 * k)
		percentLabel.TextSize = math.floor(16 * k)
		tipLabel.TextSize = math.floor(14 * k)
		statusRow.Size = UDim2.new(1, 0, 0, math.floor(22 * k))
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitText)
	task.defer(fitText)

	-- ความโปร่งตั้งต้นของทุกชิ้น: ใช้คืนค่าหลังจางหาย (resetGuiOpacity)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d:SetAttribute("BaseBG", d.BackgroundTransparency)
			if d:IsA("TextLabel") or d:IsA("TextButton") then
				d:SetAttribute("BaseText", d.TextTransparency)
			end
		elseif d:IsA("UIStroke") then
			d:SetAttribute("BaseStroke", d.Transparency)
		end
	end

	return sg, {
		root = root,
		bgImage = bgImage,
		scene = scene,
		headerBox = bottomPanel,
		badge = badge,
		title = title,
		subtitle = subtitle,
		bottomPanel = bottomPanel,
		tipLabel = tipLabel,
		statusLabel = statusLabel,
		percentLabel = percentLabel,
		barTrack = tube,
		barFill = fuel,
		skipBtn = skipBtn,
		runner = runner,
		dashes = dashes,
		eyes = { eyeL, eyeR },
		bulb = bulb,
		bulbCord = bulbCord,
		embers = embers,
	}
end

local gui, ui = makeLoadingGui("RuralLoadingScreen")
gui.Parent = playerGui

-- ความคืบหน้าล่าสุด (0-1): ชาวบ้านวิ่งเข้าใกล้ตู้ปั๊มตามนี้
local progressNow = 0

-- ---------------------------------------------------------------- อนิเมชันฉาก (เฉพาะตอนหน้าโหลดเปิดอยู่)
do
	local RunService = game:GetService("RunService")
	local R = ui.runner
	local function at(f: GuiObject, x: number, y: number)
		f.Position = UDim2.fromScale(x / SCENE_W, y / SCENE_H)
	end
	-- แท่งยาว len ที่ปลายบนติดจุด (px, py) แกว่งทำมุม deg จากแนวดิ่ง
	local function swing(f: GuiObject, px: number, py: number, len: number, deg: number)
		local a = math.rad(deg)
		at(f, px - math.sin(a) * len / 2, py + math.cos(a) * len / 2)
		f.Rotation = deg
	end
	local runX = 100
	RunService.RenderStepped:Connect(function(dt)
		if not gui.Enabled then
			return
		end
		local t = os.clock()
		-- วิ่ง: ก้าวละ 0.36 วิ ตัวเด้ง · เข้าใกล้ตู้ปั๊มตามความคืบหน้า (100% = ถึงหน้าตู้)
		local target = 96 + progressNow * 78
		runX += (target - runX) * math.min(1, dt * 3)
		local ph = t * (2 * math.pi / 0.36)
		local bob = -math.abs(math.sin(ph)) * 3
		local leg = math.sin(ph) * 30
		local x = runX
		at(R.head, x, 88 + bob)
		at(R.eye, x + 3, 87 + bob)
		at(R.body, x, 102.5 + bob)
		swing(R.legA, x - 2, 109 + bob, 13, leg)
		swing(R.legB, x + 2, 109 + bob, 13, -leg)
		-- แขนถือแกลลอน: แกว่งน้อยๆ ตามจังหวะวิ่ง
		local armDeg = -10 + math.sin(ph) * 8
		swing(R.arm, x + 4.5, 99 + bob, 9, armDeg)
		local ha = math.rad(armDeg)
		local hx, hy = x + 4.5 - math.sin(ha) * 9, 99 + bob + math.cos(ha) * 9
		at(R.can, hx + 3, hy + 5)
		R.can.Rotation = armDeg * 0.6
		at(R.spout, hx + 6, hy - 0.5)
		-- พื้นเลื่อนไปทางซ้าย (วนเมื่อพ้นขอบ)
		for i, d in ipairs(ui.dashes) do
			local base = 50 + (i - 1) * 26
			local xx = 40 + ((base - 40 - t * 80) % 260)
			at(d, xx, 124)
		end
		-- ตาผีในดงกล้วย: ขยับซ้ายขวาเบาๆ + กะพริบทุก ~3 วิ
		local peek = math.sin(t * 2.6) * 1.5
		local blink = (t % 3.2) < 0.12
		for i, e in ipairs(ui.eyes) do
			at(e, (if i == 1 then 60 else 66) + peek, 92)
			e.Visible = not blink
		end
		-- หลอดไฟแกว่ง
		local sw = math.sin(t * 2.1) * 6
		swing(ui.bulbCord, 150, 0, 22, sw)
		local ba = math.rad(sw)
		at(ui.bulb, 150 - math.sin(ba) * 25, math.cos(ba) * 25)
		-- ธูป 3 ดอก: แสงไฟเต้นสลับกัน
		for i, e in ipairs(ui.embers) do
			e.BackgroundTransparency = 0.25 + 0.25 * math.sin(t * 4.5 + i * 1.3)
		end
	end)
end

-- สลับคำแนะนำทุก 4.5 วินาที: ใน Lobby แสดงทุกข้อ (รวมข้อของ Lobby) / ในเกมแสดงเฉพาะข้อของเกม
--   มือถือ (จอสัมผัส ไม่มีคีย์บอร์ด หรือจอเตี้ย) ใช้ข้อความแบบแตะปุ่ม
do
	local inLobbyTips = isLobbyPlace()
	local filtered = {}
	for _, t in ipairs(TIPS) do
		if inLobbyTips or not t.lobby then
			table.insert(filtered, t)
		end
	end
	TIPS = filtered
end
local function isTouchDevice(): boolean
	local cam = Workspace.CurrentCamera
	return UserInputService.TouchEnabled
		and (not UserInputService.KeyboardEnabled or (cam ~= nil and cam.ViewportSize.Y < 500))
end
local currentTipIdx = math.random(1, #TIPS)
local function updateTipText()
	local tip = TIPS[currentTipIdx]
	local touch = isTouchDevice()
	-- tip.<ภาษา> / tip.<ภาษา>Touch (มือถือ) · ภาษาที่ยังไม่แปล = อังกฤษ
	local l = langCode()
	local t = (touch and tip[l .. "Touch"]) or tip[l] or (touch and tip.enTouch) or tip.en
	ui.tipLabel.Text = t
end
updateTipText()

task.spawn(function()
	while gui.Parent do
		task.wait(4.5)
		if gui.Enabled then
			currentTipIdx = (currentTipIdx % #TIPS) + 1
			updateTipText()
		end
	end
end)

local function setProgressMode(showBar: boolean)
	ui.percentLabel.Visible = showBar
	ui.skipBtn.Visible = showBar
end

-- ความคืบหน้า = น้ำมันในหลอดแก้ว + ชาวบ้านวิ่งเข้าใกล้ตู้ (progressNow)
local function setProgress(fraction: number, statusText: string?)
	local clamped = math.clamp(fraction, 0, 1)
	progressNow = clamped
	local pct = math.floor(clamped * 100 + 0.5)
	ui.percentLabel.Text = ("%d%%"):format(pct)
	TweenService:Create(ui.barFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, math.max(0.05, clamped)),
	}):Play()
	if statusText then
		ui.statusLabel.Text = statusText
	end
end

local function fadeOutGui(duration: number?)
	local dur = duration or 0.55
	local fadeInfo = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, desc in ipairs(ui.root:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			TweenService:Create(desc, fadeInfo, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("ImageLabel") then
			TweenService:Create(desc, fadeInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("Frame") then
			TweenService:Create(desc, fadeInfo, { BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("UIStroke") then
			TweenService:Create(desc, fadeInfo, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(ui.root, fadeInfo, { BackgroundTransparency = 1 }):Play()
	task.wait(dur + 0.05)
	gui.Enabled = false
end

-- คืนความโปร่งตั้งต้นของทุกชิ้น (จำไว้ใน attribute ตอนสร้าง: BaseBG / BaseText / BaseStroke)
local function resetGuiOpacity()
	ui.root.BackgroundTransparency = 0
	for _, d in ipairs(ui.root:GetDescendants()) do
		local bg = d:GetAttribute("BaseBG")
		if type(bg) == "number" then
			(d :: any).BackgroundTransparency = bg
		end
		local tx = d:GetAttribute("BaseText")
		if type(tx) == "number" then
			(d :: any).TextTransparency = tx
		end
		local st = d:GetAttribute("BaseStroke")
		if type(st) == "number" then
			(d :: any).Transparency = st
		end
	end
end

-- ================================================================
-- 1) ตอนเข้า Place:
--    - ถ้าเป็นแมพ Lobby: โหลดทรัพยากรพร้อมหลอด Progress Bar 0-100% + ปุ่มข้าม (Skip)
--    - ถ้าเป็นแมพเล่นจริง (Pump Lot): แสดงเฉพาะหน้าจอภาพ Key Art (ไม่มีหลอดโหลด/ปุ่มข้าม) ค้างไว้อย่างน้อย 3 วินาทีให้ทุกคนเข้าพร้อมกัน
-- ================================================================
local skipped = false
ui.skipBtn.Activated:Connect(function()
	if not skipped then
		skipped = true
	end
end)

task.spawn(function()
	gui.Enabled = true
	resetGuiOpacity()

	local inLobby = isLobbyPlace()
	local intro: Sound? = nil
	if not inLobby then
		-- เพลงเปิดตอนโหลดเข้าแมพปั๊ม (~48 วิ): ยังโหลดไม่เสร็จ (เน็ตช้า) = เล่นวนไปเรื่อยๆ
		-- โหลดเสร็จ = ค่อยๆ เบาลงจนเงียบ (ไม่ต้องรอจบเพลง) / จบเพลงพอดีตอนนั้นก็จบไปเลย (endIntro ด้านล่าง)
		-- อยู่กลุ่ม Music (ปรับได้ในหน้าตั้งค่า)
		local s = Instance.new("Sound")
		s.Name = "IntroMusic"
		s.SoundId = INTRO_MUSIC_ID
		s.Volume = INTRO_MUSIC_VOLUME
		s.Looped = true
		s:SetAttribute("SoundCategory", "Music")
		s.Parent = SoundService
		s:Play()
		intro = s
	end
	-- โหลดเสร็จ: เลิกวน แล้วค่อยๆ เบาลง INTRO_FADE วินาที (ระหว่างนั้นเพลงจบเองก็หยุดเลย)
	local function endIntro()
		local s = intro
		if not s then
			return
		end
		intro = nil
		s.Looped = false
		s.Ended:Once(function()
			s:Destroy()
		end)
		local fade = TweenService:Create(s, TweenInfo.new(INTRO_FADE, Enum.EasingStyle.Sine), { Volume = 0 })
		fade.Completed:Once(function()
			if s.Parent then
				s:Destroy()
			end
		end)
		fade:Play()
	end
	ui.title.Text = tr("ปั๊มหลอดท้ายทุ่ง", "MIDNIGHT RURAL GAS & TIRE", { id = "POM BENSIN TENGAH SAWAH", pt = "POSTO NO MEIO DO ARROZAL", es = "GASOLINERA EN MEDIO DEL ARROZAL" })
	ui.badge.Text = if inLobby
		then tr("  วัดท้ายทุ่ง  ", "  TEMPLE LOBBY  ", { id = "  LOBBY KUIL  ", pt = "  LOBBY DO TEMPLO  ", es = "  LOBBY DEL TEMPLO  " })
		else tr("  กะดึกท้ายทุ่ง  ", "  NIGHT SHIFT  ", { id = "  SHIFT MALAM  ", pt = "  TURNO DA NOITE  ", es = "  TURNO DE NOCHE  " })
	ui.subtitle.Text = if inLobby
		then tr("จุดรวมตัวก่อนออกกะดึก · เดินเข้าวงแดงเพื่อสร้างหรือร่วมห้อง", "Gather before the night shift · walk into a red ring to host or join", { id = "Berkumpul sebelum shift malam · masuk ke lingkaran merah untuk membuat atau bergabung ke room", pt = "Reúna-se antes do turno da noite · entre num círculo vermelho para criar ou entrar numa sala", es = "Reúnanse antes del turno de noche · entra a un círculo rojo para crear o unirte a una sala" })
		else tr("สังเกตความผิดปกติ · ห้ามเติมน้ำมันให้ผีเด็ดขาด", "Spot the anomalies · Never refuel a ghost", { id = "Temukan kejanggalan · Jangan pernah isi bensin untuk hantu", pt = "Encontre as anomalias · Nunca abasteça um fantasma", es = "Encuentra las anomalías · Nunca le cargues gasolina a un fantasma" })

	-- หน้าโหลดแบบใหม่: ชื่อเกมอยู่มุมซ้ายล่าง กลางจอมีแค่สถานะ + เปอร์เซ็นต์ + คำแนะนำ
	ui.badge.Text = ui.title.Text
	ui.title.Visible = false
	ui.subtitle.Visible = false
	-- อย่าให้เห็นข้อความตั้งต้น "Label" / ปุ่มข้ามในแมพเล่นเกม
	ui.statusLabel.Text = tr("กำลังโหลด...", "Loading...", { id = "Memuat...", pt = "Carregando...", es = "Cargando..." })
	setProgressMode(true)
	setProgress(0.02)
	ui.skipBtn.Visible = false

	-- โหลดเสียง / mesh / texture / ท่าทาง ทั้งหมดที่อยู่ในฉาก (แถบวิ่งจาก p0 ถึง p1)
	local function preloadWorld(p0: number, p1: number)
		local assetsToLoad = {}
		local seenAssetIds: { [string]: boolean } = {}
		local function addUniqueAsset(inst: Instance, assetId: string?)
			if type(assetId) == "string" and assetId ~= "" and not seenAssetIds[assetId] then
				seenAssetIds[assetId] = true
				table.insert(assetsToLoad, inst)
			end
		end
		for _, container in ipairs({ Workspace, ReplicatedStorage, SoundService }) do
			for _, inst in ipairs(container:GetDescendants()) do
				if inst:IsA("Sound") then
					addUniqueAsset(inst, inst.SoundId)
				elseif inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("ParticleEmitter") then
					addUniqueAsset(inst, (inst :: any).Texture)
				elseif inst:IsA("MeshPart") then
					addUniqueAsset(inst, inst.MeshId ~= "" and inst.MeshId or inst.TextureID)
				elseif inst:IsA("SpecialMesh") then
					addUniqueAsset(inst, inst.MeshId ~= "" and inst.MeshId or inst.TextureId)
				elseif inst:IsA("SurfaceAppearance") then
					addUniqueAsset(inst, inst:GetFullName())
				elseif inst:IsA("Animation") then
					addUniqueAsset(inst, inst.AnimationId)
				end
			end
		end
		local total = math.max(1, #assetsToLoad)
		local BATCH_SIZE = 45
		for i = 1, #assetsToLoad, BATCH_SIZE do
			if skipped then
				break
			end
			local batch = {}
			local batchEnd = math.min(i + BATCH_SIZE - 1, #assetsToLoad)
			for k = i, batchEnd do
				table.insert(batch, assetsToLoad[k])
			end
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			setProgress(
				p0 + (batchEnd / total) * (p1 - p0),
				tr(("กำลังโหลดทรัพยากร... (%d / %d)"):format(batchEnd, total), ("Loading resources... (%d / %d)"):format(batchEnd, total), { id = ("Memuat aset... (%d / %d)"):format(batchEnd, total), pt = ("Carregando recursos... (%d / %d)"):format(batchEnd, total), es = ("Cargando recursos... (%d / %d)"):format(batchEnd, total) })
			)
			task.wait(0.01)
		end
	end

	-- รอเงื่อนไข (มีเวลาสูงสุดกันค้าง)
	local function waitFor(cond: () -> boolean, timeout: number)
		local t0 = os.clock()
		while not cond() and os.clock() - t0 < timeout and not skipped do
			task.wait(0.1)
		end
	end

	if inLobby then
		-- แมพ Lobby: ปิดหน้าโหลดเมื่อฉากพร้อมจริง (ไม่มีปุ่มข้าม: เคยเข้าไปทั้งที่ฉากยังโหลดไม่เสร็จ)
		local lobbyStart = os.clock()
		setProgressMode(true)
		ui.skipBtn.Visible = false
		setProgress(0.05, tr("กำลังเตรียมฉาก...", "Preparing scene...", { id = "Menyiapkan adegan...", pt = "Preparando a cena...", es = "Preparando la escena..." }))
		waitFor(function()
			return game:IsLoaded()
		end, 120)
		setProgress(0.12, tr("กำลังซิงค์ฉากจากเซิร์ฟเวอร์...", "Syncing world from server...", { id = "Menyinkronkan dunia dari server...", pt = "Sincronizando o mundo com o servidor...", es = "Sincronizando el mundo con el servidor..." }))
		waitFor(function()
			return ReplicatedStorage:GetAttribute("SceneReady") == true
		end, 120)
		preloadWorld(0.15, 0.92)
		setProgress(0.93, tr("กำลังเตรียมตัวละคร...", "Preparing your character...", { id = "Menyiapkan karaktermu...", pt = "Preparando seu personagem...", es = "Preparando tu personaje..." }))
		waitFor(function()
			local c = player.Character
			return c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil
		end, 30)
		-- ฉากเปิด Lobby (LobbyIntro.client): ค้างหน้าโหลดไว้จนฉากเปิดพร้อมจริง (วางตัว/หมอก/โหลดประตูกับป้ายเสร็จ)
		--   ปิดหน้าโหลดแล้วตัดเข้าม่านหมอกทันที ไม่มีจอดำคั่น (ฉากเปิดไม่มา/ไม่พร้อมใน 25 วิ ก็ปิดตามปกติ)
		setProgress(0.97, tr("กำลังเตรียมฉากเปิด...", "Preparing the opening scene...", { id = "Menyiapkan adegan pembuka...", pt = "Preparando a cena de abertura...", es = "Preparando la escena de apertura..." }))
		waitFor(function()
			return player:GetAttribute("IntroReady") == true
				or (player:GetAttribute("IntroPending") ~= true and os.clock() - lobbyStart > 3)
		end, 25)
		setProgress(1, tr("พร้อมแล้ว", "Ready", { id = "Siap", pt = "Pronto", es = "Listo" }))
		task.wait(0.3)
	else
		-- แมพเล่นเกม: ปิดหน้าโหลดเมื่อฉากพร้อมจริงเท่านั้น (เคยเข้าไปทั้งที่ไฟร้านยังไม่ติด / โมเดลยังไม่ขึ้น)
		--   1) game.Loaded  2) server สร้างฉาก + ระบบเกมเสร็จ (SceneReady)  3) โหลดทรัพยากรในฉาก
		--   4) ตัวละครเกิดแล้ว  5) ไฟหน้าร้านพร้อม (หรือไฟดับตั้งใจตอนเริ่มคืน: เครื่องปั่นไฟยังไม่ติด)
		setProgressMode(true)
		ui.skipBtn.Visible = false
		local startTime = os.clock()
		setProgress(0.04, tr("กำลังเข้าสู่กะดึกที่ปั๊มหลอดท้ายทุ่ง...", "Entering the midnight shift at the gas shack...", { id = "Memasuki shift tengah malam di pom bensin...", pt = "Entrando no turno da meia-noite no posto...", es = "Entrando al turno de medianoche en la gasolinera..." }))
		waitFor(function()
			return game:IsLoaded()
		end, 120)
		setProgress(0.12, tr("กำลังเตรียมฉาก...", "Preparing the scene...", { id = "Menyiapkan adegan...", pt = "Preparando a cena...", es = "Preparando la escena..." }))
		waitFor(function()
			return ReplicatedStorage:GetAttribute("SceneReady") == true
		end, 120)
		preloadWorld(0.15, 0.85)
		setProgress(0.88, tr("กำลังเตรียมตัวละคร...", "Preparing your character...", { id = "Menyiapkan karaktermu...", pt = "Preparando seu personagem...", es = "Preparando tu personaje..." }))
		waitFor(function()
			local c = player.Character
			return c ~= nil and c:FindFirstChild("HumanoidRootPart") ~= nil
		end, 30)
		setProgress(0.94, tr("พี่ชายกำลังขี่รถพาไปส่งที่ร้าน...", "Your brother is riding you to the shop...", { id = "Abangmu sedang membonceng kamu ke toko...", pt = "Seu irmão está te levando de moto até a loja...", es = "Tu hermano te lleva en moto a la tienda..." }))
		waitFor(function()
			local env = Workspace:FindFirstChild("MapEnvironment")
			local road = env and env:FindFirstChild("DirtRoad")
			local neon = road and road:FindFirstChild("NeonLightPart")
			local light = neon and neon:FindFirstChildWhichIsA("Light", true)
			-- ไฟดับตั้งใจ (เริ่มคืนเครื่องปั่นไฟยังไม่ติด) = ถือว่าพร้อม ไม่ต้องรอไฟ
			return (light ~= nil and light.Enabled) or ReplicatedStorage:GetAttribute("PowerOn") == false
		end, 20)
		setProgress(1, tr("พร้อมแล้ว", "Ready", { id = "Siap", pt = "Pronto", es = "Listo" }))
		local elapsed = os.clock() - startTime
		if elapsed < GAME_SPLASH_MIN_SECONDS then
			task.wait(GAME_SPLASH_MIN_SECONDS - elapsed)
		end
		-- รอคนอื่นในห้องโหลดเสร็จที่หน้านี้ (ไม่ใช่จอดำ) ผู้ใช้ 2026-11-06
		-- LoadReady -> client/CutsceneController บอก server ว่าเครื่องนี้พร้อม / server ตั้ง IntroWaiting จนครบทุกคน
		player:SetAttribute("LoadReady", true)
		task.wait(0.6) -- ให้ server นับเครื่องนี้ก่อน
		waitFor(function()
			if ReplicatedStorage:GetAttribute("IntroWaiting") ~= true then
				return true
			end
			local n = ReplicatedStorage:GetAttribute("ReadyCount") or 0
			local total = ReplicatedStorage:GetAttribute("ReadyTotal") or 0
			setProgress(1, tr(("กำลังรอผู้เล่นคนอื่นโหลด... (%d / %d)"):format(n, total), ("Waiting for other players... (%d / %d)"):format(n, total), { id = ("Menunggu pemain lain... (%d / %d)"):format(n, total), pt = ("Esperando outros jogadores... (%d / %d)"):format(n, total), es = ("Esperando a otros jugadores... (%d / %d)"):format(n, total) }))
			return false
		end, 90)
	end

	task.spawn(endIntro) -- แยก thread: เพลงพังอะไรก็ไม่ทำให้หน้าโหลดค้าง
	-- สัญญาณฝั่ง client ให้ฉากเปิดตัวใน Lobby (LobbyIntro.client) เริ่มพร้อมจังหวะหน้าโหลดจางหาย
	player:SetAttribute("LoadingScreenDone", true)
	fadeOutGui(0.55)
end)

-- ================================================================
-- 2) หน้าจอคั่นระหว่างวาร์ปข้าม Place (Teleport Transition Screen — แสดงภาพ Key Art ไม่มีหลอด %)
-- ================================================================
local teleportActive = false
local teleportLoopToken = 0

local function showTeleportScreen(opts: { destination: string?, subtitleTH: string?, subtitleEN: string? }?)
	teleportActive = true
	teleportLoopToken += 1

	skipped = true -- ปิดลูปโหลดตอนเข้าเกมถ้ายังทำงานอยู่
	gui.Enabled = true
	resetGuiOpacity()
	updateTipText()
	setProgressMode(false)

	local dest = (opts and opts.destination) or (if isLobbyPlace() then "game" else "lobby")

	if dest == "game" then
		ui.badge.Text = tr("  กำลังเดินทางเข้าสู่กะดึก  ", "  HEADING TO NIGHT SHIFT  ", { id = "  MENUJU SHIFT MALAM  ", pt = "  INDO PARA O TURNO DA NOITE  ", es = "  RUMBO AL TURNO DE NOCHE  " })
		ui.title.Text = tr("กำลังเดินทางไปปั๊มหลอดท้ายทุ่ง...", "TRAVELING TO THE GAS SHACK...", { id = "MENUJU POM BENSIN...", pt = "INDO PARA O POSTO...", es = "RUMBO A LA GASOLINERA..." })
		ui.subtitle.Text = tr(
			opts and opts.subtitleTH or "กำลังเตรียมเซิร์ฟเวอร์และส่งสมาชิกในห้องเข้าสู่คืนอาถรรพ์",
			opts and opts.subtitleEN or "Reserving server and transporting your crew into the night",
			{
				id = opts and (opts.subtitleID or opts.subtitleEN) or "Menyiapkan server dan membawa timmu ke malam yang angker",
				pt = opts and (opts.subtitlePT or opts.subtitleEN) or "Reservando o servidor e levando seu time para a noite assombrada",
				es = opts and (opts.subtitleES or opts.subtitleEN) or "Reservando el servidor y llevando a tu equipo a la noche embrujada",
			}
		)
	else
		ui.badge.Text = tr("  กำลังเดินทางกลับวัด  ", "  RETURNING TO TEMPLE LOBBY  ", { id = "  KEMBALI KE LOBBY KUIL  ", pt = "  VOLTANDO AO LOBBY DO TEMPLO  ", es = "  VOLVIENDO AL LOBBY DEL TEMPLO  " })
		ui.title.Text = tr("กำลังเดินทางกลับวัดท้ายทุ่ง (Lobby)...", "RETURNING TO TEMPLE LOBBY...", { id = "KEMBALI KE LOBBY KUIL...", pt = "VOLTANDO AO LOBBY DO TEMPLO...", es = "VOLVIENDO AL LOBBY DEL TEMPLO..." })
		ui.subtitle.Text = tr(
			opts and opts.subtitleTH or "กำลังเชื่อมต่อกลับไปยังลานวัดท้ายทุ่ง",
			opts and opts.subtitleEN or "Reconnecting to the Temple Lobby plaza",
			{
				id = opts and (opts.subtitleID or opts.subtitleEN) or "Menghubungkan kembali ke halaman Lobby kuil",
				pt = opts and (opts.subtitlePT or opts.subtitleEN) or "Reconectando ao pátio do Lobby do templo",
				es = opts and (opts.subtitleES or opts.subtitleEN) or "Reconectando a la plaza del Lobby del templo",
			}
		)
	end
	ui.title.Visible = true
	ui.subtitle.Visible = true
	ui.statusLabel.Text = tr("กำลังเชื่อมต่อเซิร์ฟเวอร์ปลายทาง กรุณารอสักครู่...", "Connecting to destination server, please wait...", { id = "Menghubungkan ke server tujuan, mohon tunggu...", pt = "Conectando ao servidor de destino, aguarde...", es = "Conectando al servidor de destino, espera un momento..." })

	-- ส่ง ScreenGui ชุดนี้ให้ TeleportService คงไว้บนจอระหว่างสลับเซิร์ฟเวอร์
	pcall(function()
		local tpClone = gui:Clone()
		tpClone.Name = "TeleportBridgeGui"
		TeleportService:SetTeleportGui(tpClone)
	end)
end

local function hideTeleportScreen()
	if not teleportActive then
		return
	end
	teleportActive = false
	teleportLoopToken += 1
	fadeOutGui(0.45)
end

_G.ShowTeleportScreen = showTeleportScreen
_G.HideTeleportScreen = hideTeleportScreen

-- ผูกอัตโนมัติในแมพ Lobby: เมื่อห้องสั่งเริ่มเกม (state.launching == true) ให้ขึ้นหน้าจอ Teleport ทันที
task.spawn(function()
	local lobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRoomRemotes", 10)
	if lobbyRemotes then
		local roomState = lobbyRemotes:WaitForChild("RoomState", 10) :: RemoteEvent?
		if roomState then
			roomState.OnClientEvent:Connect(function(state: any)
				if state and state.launching then
					local subTH = ("ห้องที่ %s · สมาชิก %d/%d คน · กำลังเคลื่อนย้ายไปแมพปั๊ม..."):format(
						tostring(state.pad or "?"),
						tonumber(state.count) or 1,
						tonumber(state.maxPlayers) or 4
					)
					local subEN = ("Room %s · Crew %d/%d · Transporting to the gas shack..."):format(
						tostring(state.pad or "?"),
						tonumber(state.count) or 1,
						tonumber(state.maxPlayers) or 4
					)
					showTeleportScreen({
						destination = "game",
						subtitleTH = subTH,
						subtitleEN = subEN,
					})
				elseif state == nil and teleportActive then
					hideTeleportScreen()
				end
			end)
		end
	end
end)
