--!strict
-- SceneryGhosts.client.luau
-- ผีฉาก (ไม่ใช่ลูกค้า) โผล่ให้เห็นเป็นช่วงๆ — เกิดบนเครื่องนี้เครื่องเดียว: แต่ละคนเห็นคนละตัว คนละเวลา
--   โผล่ทีละตัว ไม่จำกัดจำนวนต่อคืน (ผู้ใช้ 2026-11-08) ห่างกัน Every · ไม่ซ้ำแบบเดิมจนกว่าจะออกครบทุกแบบ
--   ผีอยู่ที่ของมัน (ดงกล้วย / ต้นไทร / ทุ่ง) ขยับออกมาให้เห็นนิดเดียว + เรืองแสงจางๆ ไม่เดินมาหน้าร้านเอง
--   ผู้เล่นหันไปเห็น = ผีเดินเข้าหาคนนั้น (ผู้ใช้ 2026-11-04) เดินไล่ทัน / หนีนานเกิน HuntMax / ปิดแผงระหว่างถูกไล่ = ผีหลอก
--     ใครอยู่นอกร้าน (หรือคนที่ถูกไล่ถึงตัวตอนแผงเปิด) ล้ม + ตาปรือ จนผีปั่นป่วนเสร็จ (server: CoreLoop.Rampage / GhostLinger)
--   จ้องค้าง (กลางจอต่อเนื่อง StareTime) = วิ่ง/คลานพุ่งเข้าหาเร็วเกินคน ถึงตัว = ผีหลอกเต็มหน้า (ผู้ใช้ 2026-11-15)
--     วิ่ง: ตานี แม่นาค นางรำ กุมารทอง ผีเด็ก เงาหลังต้นไทร · ลอยพุ่ง: ศพห่อผ้า (ดู rush ใน KINDS)
--     (ตานี/แม่นาคเคยคลาน: หัวก้มลงพื้น จอหลอกเกาะหน้าเลยเอียง -> วิ่งตัวตรงแบบนางรำ ผู้ใช้ 2026-11-15 "แก้ตัวอื่นให้เป็นแบบนางรำ")
--   ผีเดินผ่าน (path: เปรต กระหัง) ยังใช้แบบเดิม: มองค้างนาน = พุ่งใส่หน้า (client/SceneryGhostWatch ใช้ tag "SceneryGhost")
--   หุ่นไล่กา: พอหันไปเห็น ไถลถอยหลังหายไปในทุ่ง (ไม่พุ่งใส่หน้า)
-- ไฟดับ (เครื่องปั่นไฟ) + พนมมือจนตาทิพย์เปิด: เห็นศพห่อผ้าขาวยืนเต็มทุ่ง -> ลงสมุด 1 อีเวนต์ต่อคืน (Remotes.OutageSwarm)
-- แม่แบบผี: ReplicatedStorage.GhostModels (server/GhostNPC สำเนามาจาก ServerStorage.GhostTemplates)
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local models = ReplicatedStorage:WaitForChild("GhostModels", 60)
local animIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostAnimIds")) :: any
local GhostStretch = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostStretch")) :: any
local GhostFloat = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostFloat")) :: any
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank")) :: any
local GhostMocap = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GhostMocap")) :: any
if not models then
	return
end

local CONFIG = {
	FirstAfter = { 100, 200 }, -- หลังเปิดร้าน (วินาที) ผีตัวแรก (เดิม 120-240)
	-- ห่างกันเท่านี้ (2026-11-05: 240-420 -> 330-540 ถี่เกิน / 2026-11-08: ไม่จำกัดรอบ + ถี่ขึ้นนิด -> 250-400 ผู้ใช้สั่ง)
	Every = { 250, 400 },
	FinaleFrom = 0.85, -- (= CoreLoop CONFIG.FinaleFrom) เงินถึงเท่านี้ = ช่วงท้ายคืน
	FinaleEvery = 0.6, -- ช่วงท้ายคืน: ห่างกันแค่ 60% ของ Every
	-- (เลิกใช้ MaxPerNight 3 / KindsPerNight 4 แล้ว: ไม่จำกัดจำนวน 2026-11-08)
	Stay = { 95, 130 }, -- โผล่ค้างรอนานขึ้นมาก (เดิม 30-45 วิ หายก่อนผู้เล่นหันมาเห็น · ผู้ใช้ 2026-11-17)
	SeeTime = 1.35, -- ต้องมองเห็นตรงกลางจอต่อเนื่องนานเท่านี้ถึงนับว่าเห็นจริง (กันหันกล้องปัดผ่านเฉยๆ แล้วผีเริ่มนับเวลาหาย)
	SeeDist = 110, -- ไกลกว่านี้ไม่นับว่าเห็น
	SeeCenter = 0.28, -- ห่างกลางจอไม่เกินสัดส่วนนี้ (เดิม 0.45 กว้างไป แค่หางตาก็นับว่าเห็นแล้ว)
	HuntSpeed = 7.5, -- เดินไล่ (studs/วินาที) ผู้เล่นเดิน 10 จึงเดินหนีได้
	HuntReach = 5, -- ถึงตัวในระยะนี้ = ผีหลอก
	HuntMax = 14, -- ไล่นานสุดกี่วินาที แล้วหลอกเลย (เดินหนีไม่พ้น ถ้ายังอยู่นอกร้าน)
	WatchTime = 20, -- ร้านยังเปิด: ผีที่ถูกเห็นยืนมองนานเท่านี้แล้วจางหาย (เดิม 9 วิ สั้นไป · ผู้ใช้ 2026-11-17)
	-- ตอนยืนมองคงทึบไว้ (ผู้ใช้ 2026-11-12: เดิม 0.55 จางไว + ชิ้นโปร่งแสงเรียงผิด หัววาดทับผม ดูหัวล้าน)
	WatchTransparency = 0,
	WatchFadeOut = 3, -- ยืนมองครบแล้วค่อยๆ จางหายนานเท่านี้ (วินาที)
	-- จ้องค้าง = วิ่ง/คลานพุ่งเข้าหาเร็วเกินคน แล้วผีหลอกเต็มหน้า (ผู้ใช้ 2026-11-15) เฉพาะผีที่มี rush ใน KINDS
	StareTime = 1.5, -- (2.5 -> 1.5 ผู้ใช้ 2026-11-22) ผีอยู่กลางจอต่อเนื่องกี่วินาที (เท่า SceneryGhostWatch STARE)
	StareCenter = 0.22, -- ห่างกลางจอไม่เกินสัดส่วนนี้ = กำลังจ้อง
	StareGrace = 0.4, -- ละสายตาสั้นๆ ไม่เกินนี้ ยังนับจ้องต่อ
	RushWindup = 0.2, -- หยุดนิ่งหันมามองก่อนพุ่ง (วินาที)
	RushSpeed = 160, -- studs/วินาที (ผู้เล่นเดิน 10: เร็วกว่าคน 16 เท่า · ผู้ใช้ 2026-11-15: 85 ยังช้า)
	RushReach = 4, -- ถึงตัวในระยะนี้ = ผีหลอก
	RushMax = 3, -- พุ่งนานสุดกี่วินาที แล้วหลอกเลย
	GlowColor = Color3.fromRGB(185, 205, 255),
	Glow = false, -- แสงเรืองรอบตัวผีฉาก (addGlow): ปิดทุกตัว ผู้ใช้ 2026-11-22 (เปิดกลับ = true; noGlow ต่อตัวยังใช้ได้)
	SwarmCount = 14, -- ศพห่อผ้าตอนไฟดับ
	SwarmRadius = { 24, 72 },
}

-- from -> to = ขยับออกมาจากที่ซ่อนให้เห็นง่ายขึ้น แต่ยังอยู่ในที่ของมัน (ดงกล้วย x 19..33 z 9..48 / ต้นไทร ราว -32, 22 / ทุ่งฝั่งตรงข้ามถนน)
-- path = เดินผ่านไปเรื่อยๆ (speed studs/วินาที) · moveClip = ท่าตอนเคลื่อน / clip = ท่าตอนหยุด · then = ท่าหลังหยุดสักพัก
type Kind = {
	model: string,
	from: { number },
	to: { number },
	clip: string,
	clipSpeed: number?, -- ความเร็วเล่นท่าตอนหยุด (ไม่ใส่ = 1)
	noFace: boolean?, -- ไม่หันตัวตามผู้เล่นตอนยืนมอง (ไม่มีคอหันตามด้วย) เช่น นางรำที่รำอยู่ หันแล้วท่าเพี้ยน
	lookOnly: boolean?, -- ตัวไม่หันตามผู้เล่น มีแต่คอ/หัวบิดมอง (attribute LookAtCamera -> client/GhostAnimRunner)
	armsDown: number?, -- แขนห้อยข้างตัว 0..1 (attribute ArmsDown -> client/GhostAnimRunner) ใช้คู่กับ stillBones ที่ล็อกแขน
	stillBones: string?, -- กระดูกที่ล็อกท่าพัก ไม่เล่นตามท่า (attribute StillBones, คั่นด้วย , ) เช่น ขาในผ้าซิ่น
	moveClip: string?,
	moveClipSpeed: number?, -- ความเร็วเล่นท่าตอนเคลื่อน (ท่าเดิน mocap เร็วกว่าที่ผีเคลื่อนจริง: ลดลงกันเท้าไถล)
	lift: number?,
	speed: number?,
	path: boolean?,
	huntSpeed: number?,
	glow: Color3?,
	focus: string?,
	after: { any }?,
	front: { { number } }?, -- จุดหน้าร้านที่สุ่มไปโผล่แทนที่ประจำ (เดินออกมาจากด้านหลังจุดนั้น 3 studs)
	frontChance: number?,
	-- ยืดแขน (shared/GhostStretch): at = กี่วินาทีหลังหยุด แขนยาว factor เท่า ค้าง hold วิ แล้วหดกลับ (วนซ้ำทุก every วิ)
	reach: { side: string, factor: number, at: number, hold: number, every: number }?,
	longLegs: number?, -- ขายาวกี่เท่า (ค่อยๆ ยืดหลังโผล่ แล้วเดินขาโย่งไปมา / เดินไล่ด้วยขายาว)
	hop: { height: number, rate: number }?, -- กระโดดดึ๋งๆ ตอนเคลื่อน (สูง studs, ครั้งต่อวินาที)
	float: boolean?, -- ลอย (shared/GhostFloat): ส่ายซ้ายขวา ขึ้นลง เอียงตัว พุ่งเป็นพักๆ เร็วขึ้นตามความดุของรอบ
	-- จ้องค้าง = พุ่งเข้าหา (CONFIG.Rush*): clip = ท่าตอนพุ่ง (กระดูกชื่อเดียวกันทุกตัว: ยืมท่าข้ามผีได้ เช่น Pop_Crawl), speed = ความเร็วเล่นท่า
	rush: { clip: string, speed: number, float: boolean? }?, -- float = ลอยพุ่ง/ลอยไล่ (ผีชุดยาวที่ขาอยู่ในผ้า เช่น นางรำ v2)
	pickByView: boolean?, -- เลือกระหว่างที่ประจำกับจุดหน้าร้าน (front) ตามมุมมอง: จุดที่ไม่มีใครมองและอยู่ค่อนไปทางหลังเรา
	roadRun: boolean?, -- วิ่งไปตามถนนผ่านหน้าร้าน ทางเดียวกับรถลูกค้า (roadRunPath)
	noGlow: boolean?, -- ไม่มีแสงเรืองรอบตัว (addGlow) ปอบวิ่งถนน: ผู้ใช้ 2026-11-15 ให้เอาแสงหน้าปอบออก
	screech: boolean?, -- เสียงกรีดแหลมดังติดตัวตลอดทาง (screechOn)
	fadeIn: number?, -- วินาทีที่ค่อยๆ ปรากฏ (ไม่ใส่ = 2)
	faint: number?, -- ตัวจางๆ: โปร่งค้างเท่านี้ตอนมองเห็น (attribute "Faint" ใช้ใน fade) ผู้ใช้ 2026-11-16
}
local CRAWL = { clip = "Pop_Crawl", speed = 3.5 } -- คลานสี่ขา (ท่าคลานของปอบ) ตอนนี้ไม่มีผีตัวไหนใช้
local RUN = { clip = "kuman_run", speed = 3.8 } -- วิ่งซอยเท้ายิกๆ
local FAINT = 0.45 -- ผีฉากตัวจางๆ (0 = ทึบ, 1 = ล่องหน) ผู้ใช้ 2026-11-16 "พวกนี้ทำให้ตัวจางๆ หน่อย"
local KINDS: { [string]: Kind } = {
	-- ตานี: เดินลากตัวออกจากดงกล้วย (tani_walk = Zombie Walk เล่นช้าลงให้เท้าไม่ไถล) ผู้ใช้ 2026-11-12: เดิม ghost_idle ไถลตัวแข็ง
	-- (ผู้ใช้ 2026-11-16 "ตานีผมยังหลุด": ท่าแอบมอง tani_peek ชะโงก + ชี้แขน ดูหัวกับผมแยกกัน -> ยืนเฉยๆ ghost_idle)
	-- ตานี v2 (ผู้ใช้ 2026-11-22): "ไม่ต้องขยับอะไรมาก แค่ยืนบิดคอมองเราเฉยๆ" + "ให้เห็นชัดขึ้น" + "เท้าดูแปลก"
	--   ยืนอยู่ที่เดิม (ไม่เดินออกจากดงกล้วยแล้ว) ตัวหันไปทางร้าน คอ/หัวหันตามผู้เล่น (LookAtCamera) ท่ายืนช้าลง
	--   ขา/สะโพกล็อกท่าพัก (StillBones: ผ้าซิ่นกับเท้าไม่บิด) · จางน้อยลง 0.45 -> 0.15 · จ้องค้างยังลอยพุ่ง (ขาอยู่ในผ้าซิ่น)
	-- (รอบ 4 "ขยับไปหลังๆ นิดนึง ตรงนี้สว่างและโจ่งแจ้งไป": ถอยเข้าดงกล้วย 3 studs จาก (21.4, 3.1) ตามทางเดินเดิม)
	-- (รอบ 5: ย้ายไปจุดที่ผู้ใช้วงไว้ริมดงกล้วยฝั่งนอก (39.5, 0.5) แสงไฟร้านจางถึงตรงนั้น ~36 studs + ปลูกกล้วยเพิ่ม 3 ต้น TaniCover)
	Tani = { model = "ghost_tani", from = { 39.5, 0.5 }, to = { 39.5, 0.5 }, clip = "tani_wave", speed = 0.8, lookOnly = true,
		-- (ผู้ใช้ 2026-11-22 รอบ 2 "ให้ยืนตัวตรงเลยไม่ได้หรอ": ghost_idle โน้มตัว/ก้มคอ -> ล็อกลำตัว คอ หัว ด้วย
		--  เหลือแขนห้อยตามท่า ส่วนคอ/หัวหมุนจากท่าตรงไปมองผู้เล่นด้วย LookAtCamera)
		-- (รอบ 3 "ทำไมต้องยืนทำมือแบบนี้": ghost_idle เป็นท่าผียื่นแขน -> ล็อกแขนด้วยแล้วให้ห้อยข้างตัว armsDown)
		-- (รอบ 7 "ให้ยืนโบกมือเรื่อยๆ": ท่าใหม่ tani_wave (tools/blender/tani_wave.py) แขนซ้ายห้อย แขนขวาโบก 3 ทีแล้วค้างมือ วน 6 วิ
		--  ปลดล็อกแขนให้เล่นตามท่า ไม่ใช้ armsDown แล้ว ลำตัว/ขา/คอ/หัวยังล็อก (คอหันมองด้วย LookAtCamera))
		stillBones = "root,hips,spine,chest,neck,head,thigh.L,thigh.R,shin.L,shin.R,foot.L,foot.R,toe.L,toe.R",
		rush = { clip = "tani_wave", speed = 1.4, float = true }, faint = 0.35, -- (0.15 -> 0.35 ผู้ใช้ 2026-11-22 "ทำให้ตัวจางกว่านี้หน่อย")
		noGlow = true }, -- (รอบ 6 ผู้ใช้ 2026-11-22: มีแสงเรืองออกมา -> ไม่มีแสงรอบตัวแล้ว ให้กลืนกับความมืด)
	-- นางรำ: รำอยู่ใต้ต้นไทร (เดิมครึ่งหนึ่งมารำหน้าร้าน ผู้ใช้ 2026-11-05 · เหลือต้นไทรที่เดียว 2026-11-16)
	Dancer = {
		model = "ghost_dancer",
		-- (ผู้ใช้ 2026-11-22: ยืนทับม้าหินอ่อน (-30, 13) -> (-33, 14) แล้ว "ขามันหด" = ขาจมในรากไทร (BanyanRoots)
		--  -> (-33, 6) จุดใกล้สุดที่ใต้ตัวเป็นดินจริง ไม่มีรากหรือของแข็งในกรอบตัว และโผล่ตรงนั้นเลย ไม่เดินผ่านราก)
		from = { -33, 6 },
		to = { -33, 6 },
		clip = "dancer_dance",
		clipSpeed = 1.5, -- ท่ารำไทย 18 วิ -> 12 วิต่อรอบ (ผู้ใช้: "รำเร็วกว่านี้หน่อย")
		speed = 0.7,
		-- (ผู้ใช้ 2026-11-16: เกิดใต้ต้นไทรที่เดียว เลิกจุดหน้าร้าน front {-16,-20} {-4,-21} {8,-20} {12,-2} และ pickByView)
		--   ยังรอให้จุดใต้ต้นไทรพ้นสายตาก่อนโผล่ (show) เหมือนผีฉากตัวอื่น
		faint = FAINT,
		-- นางรำ v2 (Hy3D, ผู้ใช้ 2026-11-22): ขาอยู่ในผ้านุ่งยาว วิ่งแล้วผ้าบิด -> ลอยพุ่งเข้าหาแทน ท่ารำตั้งวงค้างไว้
		rush = { clip = "dancer_idle", speed = 1.3, float = true },
		noFace = true, -- (ผู้ใช้ 2026-11-22: หันตามผู้เล่นแล้วท่ารำเพี้ยน) รำหันหน้าทางเดิมต่อไป
	},
	-- แม่นาก: ยื่นมือแล้วแขนยืดยาวออกมาหยิบของ (ตำนานยื่นมือเก็บมะนาว)
	MaeNak = {
		model = "ghost_mae_nak",
		from = { -46, -26 },
		to = { -42, -24 },
		clip = "nak_cradle",
		speed = 1.2,
		after = { 4, "nak_reach" },
		reach = { side = "R", factor = 4.5, at = 4.8, hold = 2.5, every = 9 },
		faint = FAINT,
		rush = RUN,
	},
	-- กุมารทอง: กระโดดดึ๋งๆ เข้ามา
	-- กุมารทอง v3 (ผู้ใช้ 2026-11-22): เกิดยืนข้างศาลเลย ไม่กระโดดเข้ามาจากที่อื่น (from = to) · กลับมาสุ่มใน KIND_LIST
	Kuman = { model = "ghost_kuman_thong", from = { -35, 12 }, to = { -35, 12 }, clip = "kuman_giggle", moveClip = "kuman_run", speed = 3, huntSpeed = 9, hop = { height = 2.6, rate = 1.7 }, rush = { clip = "kuman_run", speed = 4.2 }, faint = FAINT },
	-- ผีเด็ก: ขายืดสูงโย่ง เดินไปมา/เดินไล่ด้วยขายาว
	Child = { model = "ghost_child", from = { 30, -32 }, to = { 27, -29 }, clip = "ghost_idle", moveClip = "ghost_glide", speed = 1.6, longLegs = 2.4, rush = RUN, faint = FAINT },
	-- ศพห่อผ้า: ไม่มีขา ลอยพุ่งมาแทนวิ่ง
	Shroud = { model = "ghost_shroud", from = { -27, -50 }, to = { -25, -44 }, clip = "shroud_idle", moveClip = "shroud_glide", lift = 0.5, speed = 1.6, float = true, rush = { clip = "shroud_glide", speed = 4 }, faint = FAINT },
	Krasue = { model = "Krasue", from = { -38, -50 }, to = { -34, -44 }, clip = "Float", lift = 5.5, speed = 2.2, huntSpeed = 9, glow = Color3.fromRGB(255, 110, 40), focus = "Head", float = true },
	-- ปอบ: คลานสี่ขาตลอด ไม่ลุกยืน (ผู้ใช้ 2026-11-12: แยกจากปอบผีใหญ่ที่เดินกระตุกมาเคาะแผง)
	-- Running Crawl วนเร็ว: ตอนเคลื่อนเล่นช้าลงให้มือเท้าไม่ไถล · ตอนหยุดคลานย่องอยู่กับที่ช้ามาก
	-- ปอบ (ผู้ใช้ 2026-11-15): คลานสี่ขาพุ่งไปตามถนนตัดหน้าร้าน (ทางรถลูกค้า SpawnPoint <-> ExitPoint ~265 studs ราว 3.5 วิ)
	--   + เสียงกรีดแหลมดังยาวติดตัวตลอดทาง แล้วหายไปสุดถนน · ท่า Crawl = Running Crawl mocap ของปอบเอง (Pop_Crawl)
	--   (45 + ท่าวิ่งยืมของกุมาร ผู้ใช้ว่ายังช้าและท่าไม่ใช่ทั้งคลานทั้งวิ่ง -> 75 + ท่าคลาน) · from/to ใช้แค่ตอนหาจุดรถไม่เจอ
	--   (ผู้ใช้ 2026-11-16: ไม่สุ่มปอบแล้ว ย้ายไปหมวด "ไม่ใช้แล้ว" ใช้เงาดำวิ่งตัด ShadowRun แทน · ปุ่ม admin ยังเรียกได้)
	Pop = { model = "Pop", from = { -139, -11 }, to = { 126, -12 }, clip = "Crawl", moveClip = "Crawl", moveClipSpeed = 3.5, speed = 75, path = true, roadRun = true, screech = true, fadeIn = 0.2, noGlow = true },
	-- เงาดำวิ่งตัดถนน (ผู้ใช้ 2026-11-16 แทนปอบ): ร่างเงา ghost_shadow วิ่งเร็วมากไปตามถนนผ่านหน้าร้าน (ทางรถลูกค้า)
	--   + เสียงกรีด "scream" ดังยาวติดตัว แล้วค่อยๆ เบาลงและจางหายไปสุดถนน · ท่า Pop_Run = วิ่งสปรินต์ที่ทำจาก Walking mocap (ghost_mocap_retarget PART 9)
	ShadowRun = { model = "ghost_burned", from = { -139, -11 }, to = { 126, -12 }, clip = "Pop_Run", moveClip = "Pop_Run", moveClipSpeed = 1.65, speed = 100, path = true, roadRun = true, screech = true, fadeIn = 0.2, noGlow = true },
	Pret = { model = "Pret", from = { -80, -62 }, to = { 85, -62 }, clip = "TallSlowWalk", speed = 14, path = true }, -- 5x size (GhostAnimIds.SCALE): stride 5x longer too
	Krahang = { model = "Krahang", from = { 90, -30 }, to = { -95, -30 }, clip = "FlapFly", lift = 16, speed = 11, path = true, float = true },
	Scarecrow = { model = "", from = { 0, 0 }, to = { 0, 0 }, clip = "" },
	Shadow = { model = "", from = { 0, 0 }, to = { 0, 0 }, clip = "", rush = RUN, faint = FAINT },
	HutShadow = { model = "ghost_shadow", from = { -33, -55 }, to = { -33, -55 }, clip = "ghost_idle", rush = RUN, faint = 0.72 },
}
-- ไม่สุ่ม Pret แล้ว (ผู้ใช้ 2026-11-12): เปรตเดินผ่านถนนซ้ำกับผีใหญ่ Big_Pret ทำให้งงกติกา (ปุ่ม admin ยังเรียกได้)
-- ไม่สุ่ม Krasue / Krahang แล้ว (ผู้ใช้ 2026-11-15): ย้ายไปหมวด "ไม่ใช้แล้ว" ในแผง admin (ปุ่มยังเรียกดูได้)
-- ไม่สุ่ม Pop / MaeNak / Kuman / Child / Shroud แล้ว (ผู้ใช้ 2026-11-16): ย้ายไปหมวด "ไม่ใช้แล้ว" ในแผง admin
local KIND_LIST = { "Tani", "Dancer", "ShadowRun", "Scarecrow", "Shadow", "HutShadow", "Kuman" } -- Kuman กลับมา 2026-11-22

local function rand(r: { number }): number
	return r[1] + math.random() * (r[2] - r[1])
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

local function shopFront(): Vector3
	local wps = Workspace:FindFirstChild("VehicleWaypoints")
	local stop = wps and wps:FindFirstChild("StopPoint") :: BasePart?
	return if stop then stop.Position else Vector3.new(-4, 2, -7)
end

-- ผีที่มีผมแยกชิ้น (ตานี แม่นาค ปอบ ...): ห้ามโปร่งแสงครึ่งๆ กลางๆ เพราะ Roblox เรียงลำดับวาดชิ้นโปร่งแสงตามระยะ
-- หัววาดทับผม = ผมหลุดไปอยู่หลังหัว (ผู้ใช้ 2026-11-14: ตานีหลังกอกล้วยผมหลุด ตอนกำลังจางเข้า/ออก)
-- -> โผล่/หายแบบไฟกะพริบ (ทึบ <-> ล่องหน สลับถี่ๆ แล้วค้างที่ค่าสุดท้าย) แทนการค่อยๆ จาง
local function hasHair(root: Instance): boolean
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "Hair") then
			return true
		end
	end
	return false
end

-- ผมแยกชิ้นทึบเสมอตอนมองเห็น (ผู้ใช้ 2026-11-16 ตานีผมยังหลุดตอนตัวจาง): ชิ้นทึบวาดตามความลึกจริง
--   ผมจึงอยู่หน้าหัวถูกต้อง ไม่โดนหัวที่โปร่งวาดทับ (ตัวยังจางตาม Faint ได้)
--   ของที่วางบนตัว (มงกุฎ/ดอกไม้นางรำ Cloth_ · ผ้ามัดคางศพ/ลูกแม่นาค Prop_) ทึบด้วย: ลำดับวาดพังแบบเดียวกับผมได้
local function isHair(p: BasePart): boolean
	local n = p.Name
	return string.find(n, "Hair") ~= nil or string.sub(n, 1, 6) == "Cloth_" or string.sub(n, 1, 5) == "Prop_"
end
-- SOLID_HAIR = true: ผมและของบนตัวทึบ ตัวจาง (ข้อสรุป 2026-11-16)
--   ลองผมจางเท่าตัวแล้ว: Roblox วาดหัว/ตัวที่โปร่งทับผมที่โปร่ง = ตานีหัวล้าน มองไม่เห็นผม (รูปผู้ใช้) แก้ในเกมไม่ได้
--   ส่วน "ผมหลุด" ตอนผมทึบรอบก่อน มาจากท่าแอบมอง tani_peek (ชะโงก + ชี้แขน) ซึ่งเปลี่ยนเป็นยืนเฉยๆ แล้ว
local SOLID_HAIR = true
local function partGoal(p: BasePart, goal: number): number
	return if SOLID_HAIR and goal < 1 and isHair(p) then 0 else goal
end

-- goal = ค่าที่จะค้าง (0..1) · solid = ตัวตอน "ติด" ระหว่างกะพริบ (ผีจางๆ = ติดเป็นตัวจาง ไม่ใช่ทึบ)
local function flicker(parts: { BasePart }, goal: number, solid: number, time: number)
	local appear = goal < 1
	for _, p in ipairs(parts) do
		p:SetAttribute("FlickerTo", goal)
	end
	local steps = math.max(3, math.floor(time / 0.12))
	task.spawn(function()
		for i = 1, steps do
			if parts[1] and parts[1]:GetAttribute("FlickerTo") ~= goal then
				return -- a newer fade took over
			end
			-- ช่วงต้นติดสั้นดับนาน ช่วงท้ายกลับกัน (ค่อยๆ มีตัวตน / ค่อยๆ หาย)
			local k = i / steps
			local on = math.random() < (if appear then k else 1 - k)
			for _, p in ipairs(parts) do
				p.Transparency = if on then partGoal(p, solid) else 1
			end
			task.wait(time / steps)
		end
		if parts[1] and parts[1]:GetAttribute("FlickerTo") == goal then
			for _, p in ipairs(parts) do
				p.Transparency = partGoal(p, goal)
			end
		end
	end)
end

-- ผีจางๆ (attribute "Faint" บนตัวผี ผู้ใช้ 2026-11-16 "ทำให้ตัวจางๆ หน่อย"): "มองเห็น" = โปร่งเท่า Faint ไม่ทึบ
--   t = 1 ล่องหน / ต่ำกว่านั้นถูกยกขึ้นเป็นอย่างน้อย Faint · ก่อนเข้าจอหลอก ตั้ง Faint = 0 แล้ว fade 0 ทันที (solidNow)
--   ⚠️ ผมแยกชิ้นตอนโปร่งครึ่งๆ Roblox อาจวาดหัวทับผม (ดูหมายเหตุ hasHair) ผู้ใช้ขอจางเองรู้ความเสี่ยงนี้
local function fade(root: Instance, t: number, time: number)
	local faint = (root:GetAttribute("Faint") :: number?) or 0
	local goal = if t >= 1 then 1 else math.max(t, faint)
	if time > 0 and hasHair(root) then
		local parts = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "RootPart" and d.Name ~= "FocusMarker" then
				table.insert(parts, d)
			end
		end
		flicker(parts, goal, faint, time)
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" and d.Name ~= "FocusMarker" then
			d:SetAttribute("FlickerTo", nil) -- stops a running flicker
			local g = partGoal(d, goal)
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = g }):Play()
			else
				d.Transparency = g
			end
		end
	end
end

-- ทึบทันที (ก่อน JumpscareController โคลนตัวไปขึ้นจอหลอก: หน้าในจอหลอกต้องไม่จาง)
local function solidNow(m: Instance)
	m:SetAttribute("Faint", 0)
	fade(m, 0, 0)
end

-- ---------------------------------------------------------------- ผีมีกระดูก (ท่าเล่นบนเครื่องนี้เอง)
local function animator(m: Model): Animator
	local ac = m:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController")
	ac.Parent = m
	local an = ac:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	an.Parent = ac
	return an :: Animator
end

local function play(m: Model, clip: string, speed: number?)
	m:SetAttribute("GhostClip", clip)
	m:SetAttribute("GhostClipSpeed", speed or 1)
	m:SetAttribute("GhostClipT0", Workspace:GetServerTimeNow())
	-- ท่า mocap: client/GhostAnimRunner เขียนกระดูกเอง ไม่ต้องเล่นท่า ID เก่าซ้อน (หยุดอันที่ค้างอยู่)
	if GhostMocap.Has((m:GetAttribute("GhostName") :: string?) or m.Name, clip) then
		local ac = m:FindFirstChildOfClass("AnimationController")
		local an = ac and ac:FindFirstChildOfClass("Animator")
		if an then
			for _, tr in ipairs(an:GetPlayingAnimationTracks()) do
				tr:Stop(0)
			end
		end
		return
	end
	local set = animIds[m.Name]
	local id = set and set[clip]
	if not id then
		return
	end
	local an = animator(m)
	local a = Instance.new("Animation")
	a.AnimationId = id
	local tr = an:LoadAnimation(a)
	tr.Looped = not (animIds.ONCE and animIds.ONCE[clip])
	tr:Play(0.3)
	for _, other in ipairs(an:GetPlayingAnimationTracks()) do
		if other ~= tr then
			other:Stop(0.3)
		end
	end
end

local function spawnRigged(name: string): Model?
	local t = models:FindFirstChild(name) :: Model?
	if not t then
		return nil
	end
	local m = t:Clone()
	m:SetAttribute("GhostName", name)
	CollectionService:AddTag(m, "RiggedGhost")
	local sc = animIds.SCALE and animIds.SCALE[name]
	if sc and sc ~= 1 then
		m:ScaleTo(sc)
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	return m
end

-- แสงเรืองจางๆ ตรงอก (ที่มืดก็ยังเห็นเงาผี)
local function addGlow(m: Model, color: Color3)
	local root = m:FindFirstChild("RootPart") :: BasePart?
	if not root then
		return
	end
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 3.5, -1)
	a.Parent = root
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 11
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = a
end

-- ---------------------------------------------------------------- โผล่ / หาย
local folder = Instance.new("Folder")
folder.Name = "LocalSceneryGhosts"
folder.Parent = Workspace
local showId = 0
local current: { kind: string, m: Model, conn: RBXScriptConnection?, hunting: boolean? }? = nil

local function hide(fadeTime: number?)
	local c = current
	current = nil
	if not c then
		return
	end
	if c.conn then
		c.conn:Disconnect()
	end
	CollectionService:RemoveTag(c.m, "SceneryGhost")
	local t = fadeTime or 1.5
	fade(c.m, 1, t)
	for _, d in ipairs(c.m:GetDescendants()) do
		if d:IsA("Sound") and d.IsPlaying then
			TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = 0 }):Play()
		end
	end
	if c.kind == "Scarecrow" then
		-- ผีฉากหุ่นไล่กาจบ: คืนหุ่นตัวจริงเมื่อไฟไม่ได้ดับ
		task.delay(t + 0.1, function()
			if ReplicatedStorage:GetAttribute("PowerOn") ~= false then
				player:SetAttribute("ScarecrowTest", "restore:" .. os.clock())
			end
		end)
	end
	task.delay(t + 0.15, function()
		c.m:Destroy()
	end)
end

-- หุ่นไล่กา: ยืนครึ่งทางระหว่างที่เดิมกับตู้ปั๊ม (ไม่มีตาเรืองแสง ผู้ใช้ 2026-11-18) พอหันไปเห็น = ไถลถอยหลังหายไปในทุ่ง
local function showScarecrow(): Model?
	local ap = Workspace:FindFirstChild("AnomalyProps")
	local src = ap and ap:FindFirstChild("Scarecrow") :: Model?
	if not src then
		return nil
	end
	-- ซ่อนหุ่นตัวจริงไม่ให้มี 2 ตัวในฉากพร้อมกัน
	player:SetAttribute("ScarecrowTest", "vanish:" .. os.clock())
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			if string.find(d.Name, "Eye") then
				d.Color = Color3.fromRGB(26, 22, 20)
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	local from = Vector3.new(12.16, 0.01, -45.64)
	local front = shopFront()
	local p = from:Lerp(front, 0.2)
	p = Vector3.new(p.X, groundAt(p.X, p.Z) + (from.Y - groundAt(from.X, from.Z)), p.Z)
	-- หน้าหุ่นอยู่ฝั่ง -LookVector ของ pivot: หมุนกลับ 180° ให้หน้ามองร้าน
	m:PivotTo(CFrame.lookAt(p, Vector3.new(front.X, p.Y, front.Z)) * CFrame.Angles(0, math.pi, 0))
	m.Name = "ScarecrowLocal"
	fade(m, 1, 0)
	m.Parent = folder
	fade(m, 0, 2)
	local away = Vector3.new(from.X - p.X, 0, from.Z - p.Z).Unit
	local seenFor = 0
	local fleeing = false
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		if fleeing or not m.Parent then
			return
		end
		local cam = Workspace.CurrentCamera
		local cf, size = m:GetBoundingBox()
		local head = cf.Position + Vector3.new(0, size.Y * 0.3, 0)
		local sp, on = cam:WorldToViewportPoint(head)
		local vs = cam.ViewportSize
		local off = Vector2.new((sp.X - vs.X / 2) / (vs.X / 2), (sp.Y - vs.Y / 2) / (vs.Y / 2)).Magnitude
		if on and sp.Z > 0 and sp.Z < 110 and off < CONFIG.SeeCenter then
			seenFor += dt
		else
			seenFor = 0
		end
		if seenFor > 1.3 then
			fleeing = true
			conn:Disconnect()
			-- ไถลถอยหลังเร็วๆ จมลงดินนิดๆ แล้วจางหาย
			local start = m:GetPivot()
			local cv = Instance.new("CFrameValue")
			cv.Value = start
			cv.Changed:Connect(function(v)
				if m.Parent then
					m:PivotTo(v)
				end
			end)
			TweenService:Create(cv, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = start + away * 22 + Vector3.new(0, -2.5, 0) }):Play()
			fade(m, 1, 1.4)
			task.delay(1.5, function()
				cv:Destroy()
				if current and current.m == m then
					current = nil
				end
				m:Destroy()
				if ReplicatedStorage:GetAttribute("PowerOn") ~= false then
					player:SetAttribute("ScarecrowTest", "restore:" .. os.clock())
				end
			end)
		end
	end)
	current = { kind = "Scarecrow", m = m, conn = conn }
	return m
end

-- เงาหลังต้นไทร: ร่างเงาคนมีกระดูก ghost_shadow (assets/models/ShadowGhostV2, ผู้ใช้ 2026-11-15 "แข็งๆ" -> แก้)
--   ยืนตรงจุดของเงาเดิม (AnomalyProps.BanyanShadowAnomaly ที่ MapBuilder.HideBanyanShadowBehindTree ย้ายไปหลังลำต้น)
--   หันหาร้าน ยืนคอเอียงตัวห่อ (shadow_stand: Zombie Idle ลงร่างเงาเอง ผู้ใช้ 2026-11-15 ท่า tani_peek ที่ยืมมาแขนบิดไปข้างหลัง) ค่อยๆ ทึบขึ้น · จ้องค้าง = พุ่งใส่
--   ยังไม่มีแม่แบบ ghost_shadow ใน GhostModels = ใช้เงาเดิม (กล่อง + ลูกบอล) แบบเก่า
local SHADOW_CLIP = "shadow_stand"
local SHADOW_CLING_CLIP = "shadow_cling"
local function showShadow(): Model?
	local ap = Workspace:FindFirstChild("AnomalyProps")
	local src = ap and ap:FindFirstChild("BanyanShadowAnomaly") :: Model?
	if not src then
		return nil
	end
	if models and models:FindFirstChild("ghost_shadow") then
		local rm = spawnRigged("ghost_shadow")
		if rm then
			local torso = src:FindFirstChild("ShadowTorso") :: BasePart?
			local p = if torso then torso.Position else src:GetPivot().Position
			local feet = Vector3.new(p.X, groundAt(p.X, p.Z), p.Z)
			local f = shopFront()
			local look = Vector3.new(f.X - feet.X, 0, f.Z - feet.Z)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
			rm:PivotTo(CFrame.lookAt(feet, feet + look))
			-- ท่าเกาะต้นไม้ (ผู้ใช้ 2026-11-16): MapBuilder.HideBanyanShadowBehindTree วัดผิวลำต้นแล้วเก็บจุดยืน + ทิศไว้ที่ ClingCFrame
			-- ยืนนิ่งหลังขอบลำต้น มือขวาทาบต้นไม้ หัวโผล่มองร้าน (shadow_cling = ท่านิ่ง ไม่ขยับ) · ไม่มี attribute = ยืนแบบเดิม
			local cling = src:GetAttribute("ClingCFrame")
			local clip = SHADOW_CLIP
			if typeof(cling) == "CFrame" then
				rm:PivotTo(cling)
				clip = SHADOW_CLING_CLIP
				rm:SetAttribute("LookAtCamera", true) -- คอ/หัวหันตามผู้เล่น ตัวนิ่ง (client/GhostAnimRunner.lookAtCamera)
			end
			rm:SetAttribute("FocusBone", "head")
			rm:SetAttribute("Faint", KINDS.Shadow.faint) -- ตัวจางๆ
			rm.Name = "ShadowLocal"
			fade(rm, 1, 0)
			rm.Parent = folder
			fade(rm, 0, 3)
			play(rm, clip)
			current = { kind = "Shadow", m = rm }
			return rm
		end
	end
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanQuery = false
		end
	end
	m.Name = "ShadowLocal"
	m.Parent = folder
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(3), { Transparency = if string.find(d.Name, "Eye") then 0 else 0.35 }):Play()
		end
	end
	current = { kind = "Shadow", m = m }
	return m
end

local function shutterClosed(): boolean
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not door then
		return false
	end
	local openY = door:GetAttribute("OpenY") or 15.5
	local closedY = door:GetAttribute("ClosedY") or 6.0
	return door.Position.Y < (openY + closedY) / 2
end

-- ผู้เล่นอยู่ในร้านไหม (เหมือน CoreLoop.insideShop ฝั่ง server: ในกรอบเพิง และหลังแนวแผงสังกะสี)
local function insideShop(pos: Vector3): boolean
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not (shack and door) then
		return false
	end
	local cf, size = shack:GetBoundingBox()
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) < size.X / 2 - 0.4 and pos.Z > door.Position.Z + 0.3 and lp.Z < size.Z / 2
end

-- ตำแหน่งนี้อยู่ในตัวเพิงร้าน (กรอบกว้างกว่าผนัง 2 studs: ตัวผีไม่โผล่ผ่านผนัง/หลังคาเข้าไปในร้าน)
local function inShackBox(pos: Vector3): boolean
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure") :: Model?
	if not shack then
		return false
	end
	local cf, size = shack:GetBoundingBox()
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) < size.X / 2 + 2 and math.abs(lp.Z) < size.Z / 2 + 2
end

-- ผีมาหาได้เฉพาะคนที่ถูกขังอยู่นอกร้าน (แผงปิดแล้ว) ร้านยังเปิดอยู่ = ผีแค่ยืนมองลางๆ แล้วจางหาย (ผู้ใช้ 2026-11-05)
local function lockedOut(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and shutterClosed() and not insideShop(root.Position)
end

-- ผีอยู่ในสายตาผู้เล่นตอนนี้ไหม (อยู่ค่อนไปทางกลางจอ ไม่ไกลเกิน ไม่มีของทึบบัง)
local seeParams = RaycastParams.new()
seeParams.FilterType = Enum.RaycastFilterType.Exclude
local function inSight(p: Vector3, center: number?): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local sp, on = cam:WorldToViewportPoint(p)
	if not on or sp.Z <= 0 or sp.Z > CONFIG.SeeDist then
		return false
	end
	local vs = cam.ViewportSize
	if Vector2.new((sp.X - vs.X / 2) / (vs.X / 2), (sp.Y - vs.Y / 2) / (vs.Y / 2)).Magnitude > (center or CONFIG.SeeCenter) then
		return false
	end
	local camPos = cam.CFrame.Position
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _ = 1, 6 do
		seeParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(camPos, p - camPos, seeParams)
		if not hit then
			return true
		end
		-- ใบไม้ / ของโปร่ง / ไม่มีตัวตน ไม่นับว่าบัง
		if hit.Instance.Transparency > 0.5 or not hit.Instance.CanCollide then
			table.insert(ignore, hit.Instance)
		else
			return false
		end
	end
	return true
end

-- ผีไล่ถึงแล้ว: ให้ server ตัดสินว่าใครโดน (คนนอกร้าน ล้มจนผีปั่นป่วนเสร็จ) แล้วตอบกลับว่าเครื่องนี้โดนหลอกไหม
-- จอหลอกของผีฉาก = เกาะหน้า เวอร์ชันที่ผู้ใช้ชม "นางรำดีมากๆ" (2026-11-15): โผล่ประชิดทันที ไม่สั่น ท่ากรีดร้องค้างเฟรมเดียว
--   กล้องใกล้ 1.6 เล็งตามกระดูกหัวตอนโคลน ค้าง/จางเวลาปกติ (ค่าใน JumpscareController: CLING_NEAR / CLING_LIVE_FRAME / CLING_HOLD)
--   (ลองแบบอื่นแล้วผู้ใช้ไม่ชอบ: กล้องตามหัวจริง+ระยะ 2.1, ค้างสั้น 0.4, และแบบแรกสุดที่พุ่งเข้า+สั่น+ท่าวิ่ง)
local CLING: { cling: boolean }? = { cling = true }

local hitRemote: RemoteEvent? = nil
task.spawn(function()
	local r = remotes:WaitForChild("SceneryGhostHit") :: RemoteEvent
	hitRemote = r
	r.OnClientEvent:Connect(function(scared: boolean)
		local c = current
		if not c then
			return
		end
		if scared and _G.LocalJumpscare then
			solidNow(c.m)
			_G.LocalJumpscare("Scenery_" .. c.kind, c.m, CLING)
		end
		task.delay(if scared then 0.3 else 0, function()
			if current == c then
				hide(1)
			end
		end)
	end)
end)
local function strike(kind: string)
	local r = hitRemote
	if not r then
		hide(1)
		return
	end
	r:FireServer(kind)
	local c = current
	task.delay(3, function() -- server ไม่ตอบ: จางหายเอง
		if c and current == c then
			hide(1)
		end
	end)
end

-- ---------------------------------------------------------------- จ้องค้าง = พุ่งใส่ (ผู้ใช้ 2026-11-15)
-- ตัวนับจ้อง: เรียกทุกเฟรมด้วยตำแหน่งหัวผี คืน true เมื่อผีอยู่กลางจอต่อเนื่องครบ StareTime
-- จุดที่นับว่าจ้อง: หัว (focus) อก สะโพก (ผู้ใช้ 2026-11-22 "มองตั้งนานไม่วิ่งมา": เดิมนับแค่หัว
--   เสาเพิง/ตู้ปั๊มบังแค่หัว หรือมองที่ตัวแล้วหัวหลุดกลางจอ = ไม่นับ) ตำแหน่งตามท่าจริง (TransformedWorldCFrame)
local function stareSpots(m: Model, focus: Bone?): { Vector3 }
	local out: { Vector3 } = {}
	if focus then
		table.insert(out, focus.TransformedWorldCFrame.Position)
	end
	for _, n in ipairs({ "chest", "hips" }) do
		local b = m:FindFirstChild(n, true)
		if b and b:IsA("Bone") and b ~= focus then
			table.insert(out, b.TransformedWorldCFrame.Position)
		end
	end
	if #out == 0 then
		table.insert(out, m:GetPivot().Position + Vector3.new(0, 4, 0))
	end
	return out
end

local function stareTracker(): ({ Vector3 }, number) -> boolean
	local stare, away = 0, 0
	return function(spots: { Vector3 }, dt: number): boolean
		local seen = false
		for _, p in ipairs(spots) do
			if inSight(p, CONFIG.StareCenter) then
				seen = true
				break
			end
		end
		if seen then
			stare += dt
			away = 0
		else
			away += dt
			if away > CONFIG.StareGrace then
				stare = 0
			end
		end
		return stare >= CONFIG.StareTime
	end
end

-- จั้มสแกร์มีครั้งเดียว = ตอนผีมาถึงหน้า (จอหลอก JumpscareController เล่นเสียงหลอก + หัวเราะเอง)
--   ตอนวิ่งมาให้เงียบ (ผู้ใช้ 2026-11-17: เคยมีเสียง Jumpscare_1 ตอนเริ่มวิ่ง + จอหลอกตอนถึง = หลอก 2 ครั้ง)

-- เริ่มพุ่ง: เล่นท่าวิ่ง/คลานเร็วๆ เงียบๆ · ห้ามจางหายเองระหว่างพุ่ง (current.hunting)
local function rushBegin(_kind: string, m: Model, r: { clip: string, speed: number, float: boolean? })
	fade(m, 0, 0.2)
	play(m, r.clip, r.speed)
	if r.float and m:GetAttribute("GlideT0") == nil then
		m:SetAttribute("GlideT0", os.clock()) -- place(): ยกตัวลอยขึ้นจากพื้น + ส่ายแบบผีลอย
	end
	if current and current.m == m then
		current.hunting = true
	end
end

-- ก้าวพุ่งหนึ่งเฟรม: คืน (ตำแหน่งใหม่, ทิศหันหน้า, ถึงแล้วหรือยัง)
--   ชนกรอบเพิงร้าน (ผู้เล่นอยู่ในร้าน) = หลอกที่หน้าร้านเลย ไม่ทะลุผนังเข้าไป
local function rushStep(pos: Vector3, dt: number, since: number): (Vector3, Vector3?, boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return pos, nil, true
	end
	local gap = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
	local dir = if gap.Magnitude > 0.01 then gap.Unit else nil
	if gap.Magnitude <= CONFIG.RushReach or since >= CONFIG.RushMax or not dir then
		return pos, dir, true
	end
	local nextPos = pos + dir * math.min(CONFIG.RushSpeed * dt, gap.Magnitude - CONFIG.RushReach + 0.5)
	if not inShackBox(pos) and inShackBox(nextPos) then
		return pos, dir, true
	end
	return nextPos, dir, false
end

-- พุ่งถึงแล้ว: ถูกขังนอกร้าน = ให้ server ตัดสินแบบผีไล่ (ล้ม + ปั่นป่วน) / ไม่งั้น = ผีหลอกเต็มหน้าเฉพาะเครื่องนี้
local function rushScare(kind: string, m: Model)
	if lockedOut() then
		strike(kind)
		return
	end
	if _G.LocalJumpscare then
		solidNow(m)
		_G.LocalJumpscare("Scenery_" .. kind, m, CLING)
	end
	task.delay(0.3, function()
		if current and current.m == m then
			hide(0.3)
		end
	end)
end

-- เงาหลังต้นไทร (ร่างมีกระดูก): ยืนนิ่งที่เดิม จ้องค้าง = วิ่งพุ่งเข้าหา
local function attachShadowRush(m: Model)
	local r = KINDS.Shadow.rush
	if not r or not m:FindFirstChildWhichIsA("Bone", true) then
		return -- เงาเดิม (Part): ใช้จ้องค้างแล้วพุ่งใส่หน้าของ SceneryGhostWatch แบบเดิม
	end
	m:SetAttribute("NoStare", true)
	local head: Bone? = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == "head" then
			head = d
			break
		end
	end
	local stared = stareTracker()
	local pos = m:GetPivot().Position
	local rushing, done, rushGo = false, false, 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		if done or not m.Parent then
			return
		end
		if not rushing then
			if stared(stareSpots(m, head), dt) then
				rushing = true
				rushGo = os.clock() + CONFIG.RushWindup
				rushBegin("Shadow", m, r)
			end
			return
		end
		if os.clock() < rushGo then
			return
		end
		local arrived: boolean
		local dir: Vector3?
		pos, dir, arrived = rushStep(pos, dt, os.clock() - rushGo)
		local feet = Vector3.new(pos.X, groundAt(pos.X, pos.Z), pos.Z)
		if dir then
			m:PivotTo(CFrame.lookAt(feet, feet + dir))
		end
		if arrived then
			done = true
			rushScare("Shadow", m)
		end
	end)
	if current and current.m == m then
		current.conn = conn
	end
end

-- เงาดำที่กระท่อมปลายนา (HutShadow, ผู้ใช้ 2026-11-19):
--   ยืนอยู่นานที่หน้าเถียงนาร้างกลางทุ่ง (-33, -55) มองไกลๆ เห็นยืนจ้องมาทางร้านเฉยๆ ไม่วิ่งใส่ถ้าแค่ยืนมองไกลๆ
--   แต่ถ้าผู้เล่นเดินเข้าไปใกล้ในระยะ HUT_TRIGGER_DIST (48 studs) และเปิดไฟฉายส่องไปที่ตัวมันต่อเนื่อง HUT_FLASH_TIME (0.45 วิ)
--   มันจะวิ่งพุ่งเข้าชาร์จด้วยความเร็วสูง แล้ว Jumpscare เต็มหน้าทันที!
local HUT_POS = Vector3.new(-33.0, 0, -55.0)
local HUT_TRIGGER_DIST = 48 -- ระยะที่เดินเข้าไปใกล้เถียงนาแล้วส่องไฟฉายจะโดนพุ่งใส่ (จากหน้าร้านห่าง ~56 studs ต้องก้าวลงไปริมถนน/คันนา)
local HUT_FLASH_CENTER = 0.36 -- รัศมีลำแสงไฟฉายกลางจอ
local HUT_FLASH_TIME = 0.45 -- ส่องไฟฉายจี้ต่อเนื่องกี่วินาทีถึงเริ่มวิ่งพุ่งมา

local function isFlashlightOn(): boolean
	local char = player.Character
	local tool = char and char:FindFirstChild("FrogFlashlight")
	if not (tool and tool:IsA("Tool")) then
		return false
	end
	local origin = Workspace:FindFirstChild("CameraFlashlightOrigin")
	local beam = origin and origin:FindFirstChild("CameraBeamLight") :: SpotLight?
	if beam then
		return beam.Enabled
	end
	local bat = tool:GetAttribute("Battery")
	return type(bat) ~= "number" or bat > 0
end

local function showHutShadow(): Model?
	local feet = Vector3.new(HUT_POS.X, groundAt(HUT_POS.X, HUT_POS.Z), HUT_POS.Z)
	local f = shopFront()
	local look = Vector3.new(f.X - feet.X, 0, f.Z - feet.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, 1)

	local rm: Model? = nil
	if models and models:FindFirstChild("ghost_shadow") then
		rm = spawnRigged("ghost_shadow")
	end
	if not rm then
		local ap = Workspace:FindFirstChild("AnomalyProps")
		local src = ap and ap:FindFirstChild("BanyanShadowAnomaly") :: Model?
		if not src then
			return nil
		end
		rm = src:Clone()
		for _, d in ipairs(rm:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	local m = rm :: Model
	m:PivotTo(CFrame.lookAt(feet, feet + look))
	m:SetAttribute("FocusBone", "head")
	m:SetAttribute("Faint", KINDS.HutShadow.faint)
	m:SetAttribute("NoStare", true) -- ไม่ใช้จ้องไกลๆ แล้วพุ่ง ต้องเดินเข้าไปส่องไฟฉายในระยะเท่านั้น
	m.Name = "HutShadowLocal"
	fade(m, 1, 0)
	m.Parent = folder
	fade(m, 0, 3)
	if m:FindFirstChildWhichIsA("Bone", true) then
		-- ใช้ท่ายืนตรงปกติ (ghost_idle) ไม่ใช้ shadow_stand ที่คอเอียงตัวห่อ
		play(m, "ghost_idle")
	end

	local head: Bone? = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == "head" then
			head = d
			break
		end
	end

	local pos = feet
	local flashHold = 0
	local rushing, done, rushGo = false, false, 0
	local r = KINDS.HutShadow.rush or RUN

	local conn = RunService.Heartbeat:Connect(function(dt)
		if done or not m.Parent then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if not rushing then
			-- หันหน้ามองตามผู้เล่นตลอดเวลาที่ยืนอยู่หน้ากระท่อม
			local toPlayer = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			if toPlayer.Magnitude > 0.1 then
				m:PivotTo(CFrame.lookAt(pos, pos + toPlayer.Unit))
			end
			-- เช็กระยะห่าง + เปิดไฟฉายส่องตรงตัวผี
			local dist = toPlayer.Magnitude
			local targetPt = if head then head.WorldPosition else pos + Vector3.new(0, 4, 0)
			if dist <= HUT_TRIGGER_DIST and isFlashlightOn() and inSight(targetPt, HUT_FLASH_CENTER) then
				flashHold += dt
				if flashHold >= HUT_FLASH_TIME then
					rushing = true
					rushGo = os.clock() + CONFIG.RushWindup
					rushBegin("HutShadow", m, r)
				end
			else
				flashHold = math.max(0, flashHold - dt * 1.5)
			end
			return
		end
		if os.clock() < rushGo then
			return
		end
		local arrived: boolean
		local dir: Vector3?
		pos, dir, arrived = rushStep(pos, dt, os.clock() - rushGo)
		local curFeet = Vector3.new(pos.X, groundAt(pos.X, pos.Z), pos.Z)
		if dir then
			m:PivotTo(CFrame.lookAt(curFeet, curFeet + dir))
		end
		if arrived then
			done = true
			rushScare("HutShadow", m)
		end
	end)
	current = { kind = "HutShadow", m = m, conn = conn }
	return m
end

-- จุดเดินออกมา (from) และจุดหยุด (to) ของผีตัวนี้ · frontSpot = จุดหน้าร้านที่ show() สุ่มไว้แล้ว (nil = ที่ประจำ)
local function rigPath(def: Kind, frontSpot: { number }?, cross: { Vector3 }?): (Vector3, Vector3)
	if cross then
		return cross[1], cross[2]
	end
	local from = Vector3.new(def.from[1], 0, def.from[2])
	local to = Vector3.new(def.to[1], 0, def.to[2])
	if frontSpot then
		to = Vector3.new(frontSpot[1], 0, frontSpot[2])
		local f = shopFront()
		local away = Vector3.new(to.X - f.X, 0, to.Z - f.Z)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, -1)
		from = to + away * 3
	end
	return from, to
end

-- เสียงกรีดแหลมดังๆ ติดตัวผี (เสียง 3D อยู่ที่ RootPart วิ่งตามตัว) · ผีหาย = เสียงหายไปด้วย
--   SCREECH_ID = ไฟล์ "scream" ที่เจ้าของเกมอัปโหลด (2026-11-16) เล่นความเร็วปกติ ไม่แต่งเสียง
--   (ถ้าเอา id ออก = ใช้เสียงปอบ SoundBank Ghost_Pop เร่งให้แหลม + ดันเสียงแหลม ตัดทุ้ม แทน)
local SCREECH_ID: string? = "rbxassetid://92000290721684"
local SCREECH_VOL = 2.5
local function screechOn(m: Model): Sound?
	local root = m:FindFirstChild("RootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Screech"
	s.SoundId = SCREECH_ID or (SoundBank.ResolveId(SoundBank.Presets.Ghost_Pop))
	s.PlaybackSpeed = if SCREECH_ID then 1 else 1.55
	s.Looped = true -- กรีดยาวต่อเนื่องตลอดทางที่วิ่ง (ผู้ใช้ 2026-11-15 "กรีดดังยาวๆ") แล้วค่อยๆ เบาลงจนเงียบตอนวิ่งลับไป
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 18
	s.RollOffMaxDistance = 300
	if not SCREECH_ID then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -12
		eq.MidGain = 2
		eq.HighGain = 8
		eq.Parent = s
	end
	s.Parent = root
	s:Play()
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Volume = SCREECH_VOL }):Play()
	return s
end

local function showRigged(kind: string, def: Kind, frontSpot: { number }?, cross: { Vector3 }?): Model?
	local m = spawnRigged(def.model)
	if not m then
		return nil
	end
	local lift = def.lift or 0
	local from, to = rigPath(def, frontSpot, cross)
	local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local total = dir.Magnitude
	local unit = if total > 0.01 then dir.Unit else Vector3.new(0, 0, -1)
	-- ทางเข้ามา (ผู้ใช้ 2026-11-06): ไม่ตรงดิ่ง โค้งออกข้างหนึ่งแล้ววกเข้า (ผีบินผ่านฉากแบบ path ยังเป็นเส้นตรง)
	local arcSide = if math.random() < 0.5 then -1 else 1
	local arcCtrl = (from + to) / 2 + Vector3.new(-unit.Z, 0, unit.X) * arcSide * math.clamp(total * 0.5, 0, 10)
	local function along(k: number): (Vector3, Vector3)
		if def.path then
			return from + unit * (total * k), unit
		end
		local u = 1 - k
		local p = from * (u * u) + arcCtrl * (2 * u * k) + to * (k * k)
		local tan = (arcCtrl - from) * (2 * u) + (to - arcCtrl) * (2 * k)
		tan = Vector3.new(tan.X, 0, tan.Z)
		return p, if tan.Magnitude > 0.01 then tan.Unit else unit
	end
	-- dirNow = ทิศที่หันตอนเคลื่อน / nil = หยุดอยู่ หันหาหน้าร้าน
	local hopUntil = 0 -- กระโดดอยู่ (hop): ถึงเวลานี้
	local floatSeed, floatT0 = math.random() * 100, os.clock()
	local function extraY(): number
		local y = GhostStretch.LegLift(m)
		if def.hop and os.clock() < hopUntil then
			y += math.abs(math.sin(os.clock() * math.pi * def.hop.rate)) * def.hop.height
		end
		return y
	end
	local function place(pos: Vector3, dirNow: Vector3?)
		local feet = Vector3.new(pos.X, groundAt(pos.X, pos.Z) + lift + extraY(), pos.Z)
		local look: Vector3
		if dirNow then
			look = dirNow
		elseif def.path then
			look = unit
		else
			local f = shopFront()
			look = Vector3.new(f.X - feet.X, 0, f.Z - feet.Z)
			look = if look.Magnitude > 0.01 then look.Unit else unit
		end
		local glide0 = m:GetAttribute("GlideT0") :: number?
		if glide0 and not def.float then
			-- ลอยพุ่ง/ลอยไล่ (rush.float): ค่อยๆ ยกตัวพ้นพื้น 0.8 studs ใน 0.5 วิ แล้วส่ายแบบผีลอย (ผู้ใช้ 2026-11-22 นางรำ v2)
			feet += Vector3.new(0, math.min(1, (os.clock() - glide0) / 0.5) * 0.8, 0)
			local off, rot = GhostFloat.Offset(floatSeed, os.clock() - floatT0, look)
			feet += off
			m:PivotTo(CFrame.lookAt(feet, feet + look) * rot)
			return
		end
		if def.float then
			-- ลอย: ส่ายซ้ายขวา ขึ้นลง เอียงตัวตามทางส่าย ตลอดเวลา (ไม่ลอยนิ่งเป็นเส้นตรง)
			local off, rot = GhostFloat.Offset(floatSeed, os.clock() - floatT0, look)
			feet += off
			m:PivotTo(CFrame.lookAt(feet, feet + look) * rot)
			return
		end
		if def.roadRun and not m:FindFirstChildWhichIsA("Bone", true) then
			-- โมเดลชิ้นเดียวไม่มีกระดูก (Burned_corpse 96336906407826): โยกตัวขึ้นลงและโน้มหน้าตามจังหวะฝีเท้าตอนพุ่งตัดถนน
			local tRun = os.clock() - floatT0
			local bob = math.abs(math.sin(tRun * 18)) * 0.32
			local sway = math.sin(tRun * 18) * math.rad(5)
			m:PivotTo(CFrame.lookAt(feet + Vector3.new(0, bob, 0), feet + Vector3.new(0, bob, 0) + look) * CFrame.Angles(math.rad(-12), 0, sway))
			return
		end
		m:PivotTo(CFrame.lookAt(feet, feet + look))
	end
	place(from, unit)
	if CONFIG.Glow and not def.noGlow then
		addGlow(m, def.glow or CONFIG.GlowColor)
	end
	m:SetAttribute("FocusBone", def.focus or "head")
	if def.faint then
		m:SetAttribute("Faint", def.faint) -- ตัวจางๆ (fade ยกค่าโปร่งขึ้นเป็นอย่างน้อยเท่านี้)
	end
	if def.lookOnly then
		m:SetAttribute("LookAtCamera", true)
	end
	if def.stillBones then
		m:SetAttribute("StillBones", def.stillBones)
	end
	if def.armsDown then
		m:SetAttribute("ArmsDown", def.armsDown)
	end
	fade(m, 1, 0)
	m.Parent = folder
	fade(m, 0, def.fadeIn or 2)
	play(m, def.moveClip or def.clip, if def.moveClip then def.moveClipSpeed else def.clipSpeed)
	local screechSound: Sound? = nil
	if def.screech then
		screechSound = screechOn(m)
	end
	-- ผีลอย: เร็วขึ้นตามความดุของรอบ (shared/GhostFloat)
	local floatMult = if def.float then GhostFloat.SpeedMult() else 1
	local speed = (def.speed or 1) * floatMult
	local huntSpeed = (def.huntSpeed or CONFIG.HuntSpeed) * (if def.float then 0.75 + floatMult * 0.25 else 1)
	local focusName = def.focus or "head"
	local focusBone: Bone? = nil
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == focusName then
			focusBone = d
			break
		end
	end
	if not def.path then
		m:SetAttribute("NoStare", true) -- ผีตัวนี้เดินมาหาเมื่อถูกเห็น ไม่ใช้จ้องค้างแล้วพุ่งใส่หน้า
	end
	local t0 = os.clock()
	local arrived = false
	local pos = from
	local seenFor = 0
	local hunting = false
	local struck = false
	local huntStart = 0
	local watching = false
	local watchUntil = 0
	local rushing = false
	local rushGo = 0
	local stared = stareTracker()
	local function faceMe()
		if def.lookOnly or def.noFace then
			return -- ตัวไม่หัน มีแต่คอบิดมอง (LookAtCamera)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local d = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			if d.Magnitude > 0.1 then
				place(pos, d.Unit)
			end
		end
	end
	local function startHunt()
		hunting = true
		watching = false
		huntStart = os.clock()
		fade(m, 0, 0.6)
		if current and current.m == m then
			current.hunting = true
		end
		play(m, if def.model == "Pop" then "Crawl" else (def.moveClip or def.clip))
		if def.rush and def.rush.float and m:GetAttribute("GlideT0") == nil then
			m:SetAttribute("GlideT0", os.clock()) -- ลอยไล่แทนเดิน (นางรำ v2: ขาอยู่ในผ้านุ่ง)
		end
		-- (ไม่มีเสียงจั้มสแกร์ตอนเริ่มไล่: ให้หลอกครั้งเดียวตอนถึงตัว)
		-- ผีลอยมาหา: หัวเราะคิกคักล้อเลียนก่อนโฉบเข้ามา
		local root = m:FindFirstChild("RootPart")
		local set = SoundBank.GhostSounds[kind]
		if def.float and root and set then
			SoundBank.PlayOneShot(set.laugh, root, 70, 4)
		end
	end
	-- ผีลอยไล่แบบล้อหลอก (ผู้ใช้ 2026-11-06): โฉบเข้า-ถอยออกเป็นจังหวะ ส่ายวนข้าง พุ่งเป็นพักๆ
	-- ใกล้ถึงตัว (ใน TeaseClose studs) ถอยวนรอบหนึ่งแล้วพุ่งเข้าใส่เต็มแรง
	local function teaseStep(gap: Vector3, dt: number): Vector3
		local t = os.clock() - huntStart
		local dir = gap.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local dist = gap.Magnitude
		local surge = GhostFloat.Surge(floatSeed, t)
		local fwd: number
		if dist < CONFIG.HuntReach + 4 and t > 2.5 then
			fwd = 2.2 -- เล่นพอแล้ว: พุ่งใส่
		else
			-- โฉบเข้า 2 จังหวะ ถอย 1 จังหวะ (ถอยสั้นกว่าเข้า: ยังเข้าใกล้ขึ้นเรื่อยๆ)
			local beat = math.sin(t * 2.1 + floatSeed)
			fwd = if beat > -0.45 then 1.25 * surge else -0.7
		end
		-- วนอ้อมเข้ามาทางข้างเดียว (ยิ่งไกลยิ่งวนกว้าง) + ส่ายไปมา: ไม่พุ่งตรงเข้าหาเป็นเส้นตรง
		local orbit = arcSide * 1.1 * math.clamp((dist - CONFIG.HuntReach) / 14, 0, 1) + math.cos(t * 1.4 + floatSeed) * 0.6
		return (dir * fwd + side * orbit) * huntSpeed * dt
	end
	-- ผีเดินไล่ (ไม่ลอย): เดินโค้งอ้อมเข้ามาเหมือนกัน ไม่ตรงดิ่ง
	local function walkStep(gap: Vector3, dt: number): Vector3
		local dir = gap.Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local curl = arcSide * 0.75 * math.clamp((gap.Magnitude - CONFIG.HuntReach) / 14, 0, 1)
		return (dir + side * curl).Unit * huntSpeed * dt
	end
	local conn = RunService.Heartbeat:Connect(function(dt)
		if not m.Parent or struck then
			return
		end
		-- กำลังพุ่ง: หยุดหันมามองแป๊บ แล้ววิ่ง/คลานเข้าหาเร็วเกินคน ถึงตัว = ผีหลอก
		if rushing then
			if os.clock() < rushGo then
				faceMe()
				return
			end
			local arrived: boolean
			local dir: Vector3?
			pos, dir, arrived = rushStep(pos, dt, os.clock() - rushGo)
			place(pos, dir)
			if arrived then
				struck = true
				rushScare(kind, m)
			end
			return
		end
		-- จ้องค้าง (กลางจอต่อเนื่อง StareTime) = พุ่งใส่ ไม่ว่าจะกำลังโผล่ ยืนมอง หรือเดินไล่
		local r = def.rush
		if r then
			if stared(stareSpots(m, focusBone), dt) then
				rushing = true
				hunting = false
				watching = false
				rushGo = os.clock() + CONFIG.RushWindup
				rushBegin(kind, m, r)
				return
			end
		end
		-- ร้านยังเปิด: ยืนนิ่งหันมามองคนที่เห็น จางๆ แล้วหายไป (แผงปิดลงระหว่างนั้นและคนนี้อยู่นอกร้าน = เริ่มมาหา)
		if watching then
			if lockedOut() then
				startHunt()
				return
			end
			faceMe()
			if os.clock() >= watchUntil then
				hide(CONFIG.WatchFadeOut)
			end
			return
		end
		if hunting then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not (hum and root) or hum.Health <= 0 or Lighting:GetAttribute("Cutscene") == true then
				hide(1)
				return
			end
			-- แผงเปิดขึ้น / หนีเข้าร้านได้แล้ว = เลิกไล่ กลับไปยืนมองแล้วจางหาย
			if not lockedOut() then
				hunting = false
				watching = true
				watchUntil = os.clock() + CONFIG.WatchTime
				fade(m, CONFIG.WatchTransparency, 1)
				if current and current.m == m then
					current.hunting = false
				end
				play(m, def.clip, def.clipSpeed)
				return
			end
			local gap = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
			if gap.Magnitude <= CONFIG.HuntReach or os.clock() - huntStart >= CONFIG.HuntMax then
				struck = true
				strike(kind)
				return
			end
			if def.float then
				-- ส่าย/วนล้อหลอกแล้วห้ามทะลุเข้าตัวร้าน: ก้าวที่จะเข้าไปในกรอบเพิง = ไม่ขยับ
				local nextPos = pos + teaseStep(gap, dt)
				if inShackBox(pos) or not inShackBox(nextPos) then
					pos = nextPos
				end
			else
				local nextPos = pos + walkStep(gap, dt)
				if inShackBox(pos) or not inShackBox(nextPos) then
					pos = nextPos
				else
					pos += gap.Unit * huntSpeed * dt -- โค้งแล้วจะชนร้าน: ตรงเข้าหาแทน
				end
			end
			hopUntil = os.clock() + 0.1
			place(pos, gap.Unit)
			return
		end
		-- หันไปเห็น = เริ่มเดินเข้าหา
		if not def.path then
			local p = if focusBone then focusBone.WorldPosition else m:GetPivot().Position + Vector3.new(0, 4, 0)
			seenFor = if inSight(p) then seenFor + dt else 0
			if seenFor >= CONFIG.SeeTime then
				if lockedOut() then
					startHunt()
				else
					watching = true
					watchUntil = os.clock() + CONFIG.WatchTime
					fade(m, CONFIG.WatchTransparency, 1)
					play(m, def.clip, def.clipSpeed)
				end
				return
			end
		end
		if arrived then
			if def.float then
				place(pos) -- ลอยอยู่กับที่ก็ยังส่าย/ขึ้นลง
			end
			return
		end
		local s = (os.clock() - t0) * speed
		if s >= total then
			arrived = true
			pos = to
			-- ผีกระโดด (hop): จบการกระโดดก่อนวางตัว ไม่งั้นค้างกลางอากาศตรงจังหวะสุดท้าย (กุมารลอย ผู้ใช้ 2026-11-22)
			hopUntil = 0
			place(to)
			if def.roadRun then
				-- วิ่งตัดถนน: จางและหรี่เสียงมาตั้งแต่ช่วงท้ายทางแล้ว ไม่หยุดยืนที่ปลายทาง
				hide(0.8)
				return
			end
			if def.moveClip then
				play(m, def.clip, def.clipSpeed)
			end
			if def.after then
				task.delay(def.after[1], function()
					if m.Parent and not hunting and not rushing then
						play(m, def.after[2])
					end
				end)
			end
			if def.path then
				hide(1)
			end
			return
		end
		local prog = s / total
		if screechSound and prog > 0.55 then
			-- ช่วงครึ่งหลังของถนน: เสียงกรีดค่อยๆ เบาลงตามระยะที่วิ่งห่างออกไป ไม่ตัดจบห้วนๆ
			local fadeK = math.clamp((1 - prog) / 0.45, 0, 1)
			screechSound.Volume = SCREECH_VOL * (fadeK * fadeK)
		end
		if def.roadRun and prog > 0.78 and not m:GetAttribute("RoadFading") then
			m:SetAttribute("RoadFading", true)
			fade(m, 1, math.max(0.35, (total - s) / speed + 0.35))
		end
		local tan: Vector3
		pos, tan = along(prog)
		hopUntil = os.clock() + 0.1
		place(pos, tan)
	end)
	-- ขาโย่ง: ค่อยๆ ยืดหลังโผล่มาได้แป๊บ (ยกตัวตามความยาวขาที่เพิ่ม: เรียก place ซ้ำทุกเฟรมระหว่างยืด)
	if def.longLegs then
		task.delay(2.2, function()
			if not m.Parent then
				return
			end
			GhostStretch.Set(m, "leg", nil, def.longLegs, 2.5)
			local t1 = os.clock()
			while m.Parent and os.clock() - t1 < 2.7 do
				if arrived and not hunting and not rushing and not watching then
					place(pos)
				end
				RunService.Heartbeat:Wait()
			end
		end)
		-- ยืนอยู่ขายาว: เดินโย่งไปมาช้าๆ แถวที่ของมัน
		task.spawn(function()
			local dirSign = 1
			while m.Parent do
				task.wait(3.5)
				if m.Parent and arrived and not hunting and not rushing and not watching then
					play(m, def.moveClip or def.clip)
					local t1 = os.clock()
					local side = Vector3.new(-unit.Z, 0, unit.X) * dirSign
					while m.Parent and arrived and not hunting and not rushing and not watching and os.clock() - t1 < 2.5 do
						local dt = RunService.Heartbeat:Wait()
						pos += side * 1.4 * dt
						place(pos, side)
					end
					dirSign = -dirSign
					if m.Parent and not hunting and not rushing then
						play(m, def.clip, def.clipSpeed)
					end
				end
			end
		end)
	end
	-- ยืดแขนหยิบของ: หลังหยุดสักพัก แขนยาวออกไป ค้าง แล้วหดกลับ (วนซ้ำ)
	if def.reach then
		local r = def.reach
		task.spawn(function()
			while m.Parent and not arrived do
				task.wait(0.2)
			end
			task.wait(r.at)
			while m.Parent do
				if not hunting and not rushing then
					GhostStretch.Set(m, "arm", r.side, r.factor, 1.3)
					task.wait(1.3 + r.hold)
					if not m.Parent then
						break
					end
					GhostStretch.Set(m, "arm", r.side, 1, 0.9)
				end
				task.wait(r.every)
				if m.Parent and not hunting and not rushing then
					play(m, "nak_reach")
				end
				task.wait(0.8)
			end
		end)
	end
	current = { kind = kind, m = m, conn = conn }
	return m
end

-- ---------------------------------------------------------------- เกิดตอนไม่มีใครมอง (ผู้ใช้ 2026-11-15)
-- ผีฉากโผล่เฉพาะตอนจุดเกิดอยู่นอกสายตาเรา (หลังเรา / นอกจอ / มีของทึบบัง) -> หันกลับไปก็ยืนอยู่แล้ว ไม่เห็นตอนมันค่อยๆ โผล่
--   เช็กทั้งจุดเดินออกมาและจุดหยุด ที่ระดับเท้า อก หัว · ขอบจอเผื่อ 15% (โผล่ตรงขอบจอก็ยังนับว่าเห็น)
--   รอจนพ้นสายตา: เกิดเองรอได้นานสุด UnseenWait วิ (จ้องจุดนั้นตลอด = คืนนี้ข้ามตัวนี้ไป) · ปุ่ม admin รอไม่จำกัด (หันหลังให้จุดนั้นแล้วมันจะโผล่)
local UNSEEN_WAIT = 60
local UNSEEN_MARGIN = 0.15
local UNSEEN_DIST = 220 -- ไกลกว่านี้หมอกกลืนหมดแล้ว ไม่นับว่าเห็น
local spotParams = RaycastParams.new()
spotParams.FilterType = Enum.RaycastFilterType.Exclude
local function spotSeen(p: Vector3): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local camPos = cam.CFrame.Position
	if (p - camPos).Magnitude > UNSEEN_DIST then
		return false
	end
	local sp = cam:WorldToViewportPoint(p)
	if sp.Z <= 0 then
		return false -- อยู่ข้างหลังกล้อง
	end
	local vs = cam.ViewportSize
	local mx, my = vs.X * UNSEEN_MARGIN, vs.Y * UNSEEN_MARGIN
	if sp.X < -mx or sp.X > vs.X + mx or sp.Y < -my or sp.Y > vs.Y + my then
		return false
	end
	local ignore: { Instance } = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _ = 1, 6 do
		spotParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(camPos, p - camPos, spotParams)
		if not hit then
			return true
		end
		-- ใบไม้ / ของโปร่ง / ไม่มีตัวตน มองทะลุได้
		if hit.Instance.Transparency > 0.5 or not hit.Instance.CanCollide then
			table.insert(ignore, hit.Instance)
		else
			return false
		end
	end
	return true
end

-- จุดที่ผีตัวนี้จะไปโผล่ (ระดับพื้น) สำหรับเช็กว่ามีใครมองอยู่ไหม
local function spawnSpots(kind: string, def: Kind, frontSpot: { number }?): { Vector3 }
	local ap = Workspace:FindFirstChild("AnomalyProps")
	if kind == "Scarecrow" then
		local src = ap and ap:FindFirstChild("Scarecrow")
		if src and src:IsA("Model") then
			local from = src:GetPivot().Position
			local p = from:Lerp(shopFront(), 0.2)
			return { Vector3.new(p.X, groundAt(p.X, p.Z), p.Z) }
		end
		return {}
	elseif kind == "Shadow" then
		local src = ap and ap:FindFirstChild("BanyanShadowAnomaly")
		local torso = src and src:FindFirstChild("ShadowTorso", true)
		local p = if torso and torso:IsA("BasePart") then torso.Position elseif src and src:IsA("Model") then src:GetPivot().Position else nil
		return if p then { Vector3.new(p.X, groundAt(p.X, p.Z), p.Z) } else {}
	elseif kind == "HutShadow" then
		return { Vector3.new(HUT_POS.X, groundAt(HUT_POS.X, HUT_POS.Z), HUT_POS.Z) }
	elseif def.path or def.model == "" then
		return {} -- ผีบินผ่าน/เดินผ่านไกลๆ (ไม่ได้สุ่มแล้ว): ไม่ต้องรอ
	end
	local from, to = rigPath(def, frontSpot)
	local lift = def.lift or 0
	return {
		Vector3.new(from.X, groundAt(from.X, from.Z) + lift, from.Z),
		Vector3.new(to.X, groundAt(to.X, to.Z) + lift, to.Z),
	}
end

local function anySeen(spots: { Vector3 }): boolean
	for _, s in ipairs(spots) do
		for _, h in ipairs({ 0.8, 3, 5 }) do
			if spotSeen(s + Vector3.new(0, h, 0)) then
				return true
			end
		end
	end
	return false
end

-- วิ่งไปตามถนนผ่านหน้าร้าน (roadRun): ทางเดียวกับรถลูกค้า VehicleWaypoints.SpawnPoint (x -139) <-> ExitPoint (x 126)
--   ทิศสุ่ม · ไม่มีจุด = ใช้ from/to ของผีตัวนั้น
local function roadRunPath(): { Vector3 }?
	local w = Workspace:FindFirstChild("VehicleWaypoints")
	local a = w and w:FindFirstChild("SpawnPoint")
	local b = w and w:FindFirstChild("ExitPoint")
	if not (a and b and a:IsA("BasePart") and b:IsA("BasePart")) then
		return nil
	end
	local pa = Vector3.new(a.Position.X, 0, a.Position.Z)
	local pb = Vector3.new(b.Position.X, 0, b.Position.Z)
	return if math.random() < 0.5 then { pa, pb } else { pb, pa }
end

-- เลือกจุดตามมุมมอง (pickByView, ผู้ใช้ 2026-11-15 นางรำ): ที่ประจำ + จุดหน้าร้านทุกจุด
--   เอาเฉพาะจุดที่ตอนนี้ไม่มีใครมอง แล้วเลือกจุดที่อยู่ค่อนไปทางหลังเรามากที่สุด (สุ่มระหว่าง 2 อันดับแรกไม่ให้ซ้ำที่เดิม)
--   ทุกจุดอยู่ในสายตาหมด = สุ่มไปก่อน แล้ว show() รอจนพ้นสายตาเอง · คืน nil = ที่ประจำ
local function pickSpotByView(kind: string, def: Kind): { number }?
	local cam = Workspace.CurrentCamera
	local cands: { { spot: { number }?, score: number } } = {}
	local list: { { spot: { number }? } } = { { spot = nil } }
	for _, s in ipairs(def.front or {}) do
		table.insert(list, { spot = s })
	end
	for _, c in ipairs(list) do
		local spots = spawnSpots(kind, def, c.spot)
		if #spots > 0 and not anySeen(spots) then
			local score = 0
			if cam then
				local to = spots[#spots]
				local d = Vector3.new(to.X - cam.CFrame.Position.X, 0, to.Z - cam.CFrame.Position.Z)
				local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
				if d.Magnitude > 0.01 and look.Magnitude > 0.01 then
					score = d.Unit:Dot(look.Unit) -- -1 = ข้างหลังตรงๆ, 1 = ตรงหน้า
				end
			end
			table.insert(cands, { spot = c.spot, score = score })
		end
	end
	if #cands == 0 then
		return list[math.random(#list)].spot
	end
	table.sort(cands, function(a, b)
		return a.score < b.score
	end)
	return cands[math.random(math.min(2, #cands))].spot
end

local function lookingAtRoad(): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return true
	end
	local front = shopFront()
	local toRoad = Vector3.new(front.X - cam.CFrame.Position.X, 0, front.Z - cam.CFrame.Position.Z)
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if toRoad.Magnitude < 6 then
		return look.Z < 0.35
	end
	if toRoad.Magnitude < 0.01 or look.Magnitude < 0.01 then
		return true
	end
	return toRoad.Unit:Dot(look.Unit) > 0.25
end

local showToken = 0 -- show / hide ใหม่ = ยกเลิกตัวที่ยังรอพ้นสายตาอยู่
-- natural = เกิดเองตามตาราง (รอได้ไม่เกิน UNSEEN_WAIT และต้องยัง canShow) · คืน true = โผล่แล้ว
local function show(kind: string, natural: boolean?, canShowNow: (() -> boolean)?): boolean
	showToken += 1
	local token = showToken
	if current then
		hide(0.5)
	end
	local def = KINDS[kind]
	if not def then
		return false
	end
	local frontSpot: { number }? = nil
	if def.pickByView then
		frontSpot = pickSpotByView(kind, def)
	elseif def.front and #def.front > 0 and math.random() < (def.frontChance or 0.5) then
		frontSpot = def.front[math.random(#def.front)]
	end
	local spots = spawnSpots(kind, def, frontSpot)
	local t0 = os.clock()
	if def.roadRun and natural then
		-- เงาดำวิ่งตัดถนน: รอให้ผู้เล่นหันหน้ามาทางถนนหน้าร้านก่อนค่อยวิ่ง จะได้ไม่วิ่งผ่านไปตอนหันหลังอยู่ในร้าน (ผู้ใช้ 2026-11-17)
		while not lookingAtRoad() do
			task.wait(0.25)
			if token ~= showToken or current then
				return false
			end
			if os.clock() - t0 > UNSEEN_WAIT or (canShowNow and not canShowNow()) then
				return false
			end
		end
	end
	while anySeen(spots) do
		task.wait(0.4)
		if token ~= showToken or current then
			return false -- มีคำสั่งใหม่มาแทน
		end
		if natural and (os.clock() - t0 > UNSEEN_WAIT or (canShowNow and not canShowNow())) then
			return false
		end
	end
	if token ~= showToken then
		return false
	end
	local m: Model?
	if kind == "Scarecrow" then
		m = showScarecrow()
	elseif kind == "Shadow" then
		m = showShadow()
		if m then
			attachShadowRush(m)
		end
	elseif kind == "HutShadow" then
		m = showHutShadow()
	else
		m = showRigged(kind, def, frontSpot, if def.roadRun then roadRunPath() else nil)
	end
	if not m then
		return false
	end
	-- หุ่นไล่กาหนีเองตอนโดนมอง / เงากระท่อมต้องเดินเข้าไปเอาไฟฉายส่อง: ไม่ให้ SceneryGhostWatch จ้องไกลๆ แล้วพุ่งเอง
	if kind ~= "Scarecrow" and kind ~= "HutShadow" then
		showId += 1
		m:SetAttribute("SceneryKind", kind)
		m:SetAttribute("ShowId", showId)
		CollectionService:AddTag(m, "SceneryGhost")
	end
	local mine = m
	-- เงาดำที่กระท่อมปลายนาอยู่นานเป็นพิเศษ (180-240 วิ) รอให้ผู้เล่นสังเกตเห็นแล้วเดินเอาไฟฉายไปส่องดู
	local stayTime = if kind == "HutShadow" then rand({ 180, 240 }) else rand(CONFIG.Stay)
	task.delay(stayTime, function()
		if current and current.m == mine and not current.hunting then
			hide()
		end
	end)
	return true
end

-- admin (client/AdminPanel): เรียกผีฉากบนเครื่องตัวเอง ผ่าน attribute "SceneryTest" ของผู้เล่น ("ชนิด:เลขสุ่ม" / "hide:..")
--   จุดเกิดอยู่ในสายตา = รอจนหันหนีก่อนถึงโผล่ (กดซ่อน = ยกเลิกที่รออยู่)
player:GetAttributeChangedSignal("SceneryTest"):Connect(function()
	local v = player:GetAttribute("SceneryTest")
	local kind = if type(v) == "string" then string.match(v, "^(%w+)") else nil
	if kind == "hide" then
		showToken += 1
		hide(0.5)
	elseif kind then
		task.spawn(show, kind)
	end
end)

-- ---------------------------------------------------------------- ตารางเวลาของเครื่องนี้
local function canShow(): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return remotes:GetAttribute("ShopOpen") == true
		and ReplicatedStorage:GetAttribute("TestMode") ~= true -- โหมดทดสอบ: ไม่โผล่เอง (ปุ่ม admin ยังเรียกได้)
		and remotes:GetAttribute("BigEvent") == nil
		and remotes:GetAttribute("BigOmen") == nil -- ลางผีใหญ่ (จิ้งหรีดเงียบ): ไม่แย่งซีน
		and Workspace:GetServerTimeNow() >= (remotes:GetAttribute("CalmUntil") or 0) -- ช่วงพักหายใจหลังผีใหญ่ / ไฟกลับมา
		and Lighting:GetAttribute("Cutscene") ~= true
		and Lighting:GetAttribute("Dawn") ~= true
		and hum ~= nil
		and hum.Health > 0
end

task.spawn(function()
	while true do
		-- รอเปิดร้าน = เริ่มคืนใหม่ของเครื่องนี้: สุ่มชนิดผีที่จะเจอคืนนี้
		while remotes:GetAttribute("ShopOpen") ~= true do
			task.wait(1)
		end
		-- ไม่ซ้ำแบบเดิม: หยิบออกจากถุงทีละแบบ ครบทุกแบบแล้วเติมถุงใหม่ (ไม่เอาแบบที่เพิ่งออกเป็นตัวแรกของถุงใหม่)
		local tonight = table.clone(KIND_LIST)
		local lastKind: string? = nil
		local nextAt = os.clock() + rand(CONFIG.FirstAfter)
		while remotes:GetAttribute("ShopOpen") == true do
			task.wait(1)
			if current and (remotes:GetAttribute("BigEvent") ~= nil or remotes:GetAttribute("BigOmen") ~= nil or Lighting:GetAttribute("Dawn") == true) then
				hide(1) -- ผีใหญ่มา / ฟ้าสางจบคืน: ผีฉากหลบไปก่อน
			end
			if os.clock() >= nextAt and not current and canShow() then
				if #tonight == 0 then
					tonight = table.clone(KIND_LIST)
					local i = lastKind and table.find(tonight, lastKind)
					if i and #tonight > 1 then
						table.remove(tonight, i)
					end
				end
				-- ไม่ซ้ำตัวเดิม (ผู้ใช้ 2026-11-07): ออกครบทุกแบบก่อนถึงจะวนใหม่
				local kind = table.remove(tonight, math.random(#tonight)) :: string
				-- รอจนจุดเกิดพ้นสายตาก่อนโผล่ (show) · ไม่ได้โผล่ (จ้องจุดนั้นตลอด / ร้านปิด / ผีใหญ่มา) = คืนชนิดนี้ลงถุง ลองตัวอื่นอีกสักพัก
				if show(kind, true, canShow) then
					lastKind = kind
					-- ช่วงท้ายคืน (เงินถึง FinaleFrom ของ server/CoreLoop) ผีฉากถี่ขึ้น
					local progress = remotes:GetAttribute("NightProgress")
					local finale = type(progress) == "number" and progress >= CONFIG.FinaleFrom
					nextAt = os.clock() + rand(CONFIG.Every) * (if finale then CONFIG.FinaleEvery else 1)
				else
					table.insert(tonight, kind)
					nextAt = os.clock() + rand({ 20, 40 })
				end
			end
		end
		hide(0.5)
	end
end)

-- ---------------------------------------------------------------- ไฟดับ + ตาทิพย์: ศพห่อผ้าขาวเต็มทุ่ง
local swarm: { Model } = {}
local swarmReported = false
local function sightOpen(): boolean
	local grade = Lighting:FindFirstChild("PrayerSight")
	return player:GetAttribute("Praying") == true and grade ~= nil and grade:GetAttribute("Open") == true
end

local function clearSwarm()
	for _, m in ipairs(swarm) do
		fade(m, 1, 1.2)
		task.delay(1.3, function()
			m:Destroy()
		end)
	end
	table.clear(swarm)
end

local function buildSwarm()
	local center = Vector3.new(0, 0, 6)
	for i = 1, CONFIG.SwarmCount do
		local m = spawnRigged("ghost_shroud")
		if not m then
			return
		end
		local a = (i / CONFIG.SwarmCount) * math.pi * 2 + math.random() * 0.4
		local r = rand(CONFIG.SwarmRadius)
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local feet = Vector3.new(x, groundAt(x, z) + 0.4, z)
		m:PivotTo(CFrame.lookAt(feet, Vector3.new(center.X, feet.Y, center.Z)))
		fade(m, 1, 0)
		m.Parent = folder
		fade(m, 0.15, 2.5)
		play(m, "shroud_idle")
		table.insert(swarm, m)
	end
end

local lastShop = false
RunService.Heartbeat:Connect(function()
	local shop = remotes:GetAttribute("ShopOpen") == true
	if shop and not lastShop then
		swarmReported = false -- คืนใหม่
	end
	lastShop = shop
	local want = ReplicatedStorage:GetAttribute("PowerOn") == false and sightOpen() and Lighting:GetAttribute("Cutscene") ~= true
	if want and #swarm == 0 then
		buildSwarm()
		if not swarmReported then
			swarmReported = true
			local r = remotes:FindFirstChild("OutageSwarm") :: RemoteEvent?
			if r then
				r:FireServer()
			end
		end
	elseif not want and #swarm > 0 then
		clearSwarm()
	end
end)

-- ================================================================ หุ่นไล่กาขยับเองเมื่อละสายตา (Weeping Angel) + ตอนไฟดับ (ผู้ใช้ 2026-11-18)
-- 1. ตลอดคืนตอนไฟติด: ทุกๆ 28-55 วิ ถ้าผู้เล่นละสายตาจากจุดที่หุ่นยืนอยู่และจุดปลายทาง หุ่นไล่กาตัวจริง (AnomalyProps.Scarecrow)
--    จะเปลี่ยนจุดไปยืนตามจุดต่างๆ รอบทุ่ง/ริมถนน/ข้างดงกล้วย/ข้างศาล หรือหายตัวไปชั่วคราว (ไม่มีตาเรืองแสง)
-- 2. จังหวะที่ไฟดับ (PowerOn == false): หุ่นไล่กาตัวจริงกลางทุ่งจะหายตัวไปทันที
-- 3. ระหว่างไฟดับ: สุ่มจังหวะที่ผู้เล่นหมุนกล้องหันหน้า (yaw เปลี่ยนเร็ว) ให้ไปจ๊ะเอ๋หุ่นไล่การะยะประชิดตรงหน้า
--    พร้อมเสียง Jumpscare เบาๆ พอผู้เล่นหันมุมกล้องหลบไปทางอื่น หุ่นก็จะหายไปทันที
do
	local SoundService = game:GetService("SoundService")
	local SOFT_SCARE_ID = "rbxassetid://105012119508747" -- Jumpscare_1 แบบเบาๆ
	local SOFT_SCARE_VOL = 0.85

	-- จุดที่หุ่นไล่กาย้ายไปยืนได้ตามภาพที่ผู้ใช้กำหนด (x, z) · "vanish" = หายตัวไปเลยชั่วคราว
	-- ⚠️ ห้ามใช้ nil ใน array ของ Luau เพราะ `#ROAM_SPOTS` จะนับแค่ถึงตัวก่อน nil ทำให้ช่องหายตัวไม่ถูกสุ่ม!
	local ROAM_SPOTS: { any } = {
		{ 12.16, -45.64 }, -- 1) จุดที่ 1: แปลงนากลางทุ่ง (จุดเริ่มต้นเดิม)
		{ -23.5, -51.0 }, -- 2) จุดที่ 2: แปลงนาถัดไปฝั่งขวา (หน้าเถียงนาร้าง)
		{ 19.5, 4.5 }, -- 3) จุดที่ 3: ข้างเพิงฝั่งซ้าย (หน้าดงกล้วยตานี)
		{ -31.0, 2.0 }, -- 4) จุดที่ 4: ลานหญ้าหน้าศาลพระภูมิ/โต๊ะม้าหินฝั่งขวา
		"vanish", -- 5) หายตัวไปเลยชั่วคราว
	}

	local realScarecrow: Model? = nil
	local homePivot: CFrame? = nil
	local homeGroundOffset = 0
	local baseTrans: { [BasePart]: number } = {}
	local baseCollide: { [BasePart]: boolean } = {}
	local realHidden = false
	local currentSpotIdx = 1
	local lastVisiblePivot: CFrame? = nil

	local function initRealScarecrow(): Model?
		if realScarecrow and realScarecrow.Parent and next(baseTrans) ~= nil then
			return realScarecrow
		end
		local ap = Workspace:FindFirstChild("AnomalyProps")
		local sc = ap and ap:FindFirstChild("Scarecrow") :: Model?
		if not sc then
			return nil
		end
		realScarecrow = sc
		if not homePivot then
			local piv = sc:GetPivot()
			homePivot = piv
			lastVisiblePivot = piv
			homeGroundOffset = piv.Position.Y - groundAt(piv.Position.X, piv.Position.Z)
		end
		table.clear(baseTrans)
		table.clear(baseCollide)
		for _, d in ipairs(sc:GetDescendants()) do
			if d:IsA("BasePart") then
				-- ตัดตาเรืองแสงออกถาวร
				if string.find(d.Name, "Eye") then
					d.Color = Color3.fromRGB(26, 22, 20)
					d.Material = Enum.Material.SmoothPlastic
				end
				baseTrans[d] = if d.Transparency < 1 then d.Transparency else 0
				baseCollide[d] = d.CanCollide
			elseif d:IsA("Light") then
				d.Enabled = false
			end
		end
		return sc
	end

	local function setRealVisible(vis: boolean)
		local sc = initRealScarecrow()
		if not sc then
			return
		end
		realHidden = not vis
		for _, d in ipairs(sc:GetDescendants()) do
			if d:IsA("BasePart") then
				local t = baseTrans[d] or 0
				d.Transparency = if vis then t else 1
				d.CanCollide = if vis then (baseCollide[d] or false) else false
			end
		end
		-- ย้ายลงใต้ดินตอนซ่อน เพื่อกัน SurfaceAppearance / เงา / การชนค้างในฉาก
		if not vis then
			local piv = sc:GetPivot()
			if piv.Position.Y > -100 then
				lastVisiblePivot = piv
				sc:PivotTo(piv - Vector3.new(0, 300, 0))
			end
		elseif sc:GetPivot().Position.Y <= -100 then
			-- ตำแหน่งจริงมาจาก server/ScarecrowRoam (SpotCFrame) ทุกเครื่องเห็นจุดเดียวกัน · server ให้หายตัว (Spot = vanish) = ไม่ดึงกลับขึ้นมา
			local spotCF = sc:GetAttribute("SpotCFrame")
			if typeof(spotCF) == "CFrame" then
				if spotCF.Position.Y > -100 then
					sc:PivotTo(spotCF)
				end
			elseif lastVisiblePivot then
				sc:PivotTo(lastVisiblePivot)
			end
		end
	end

	local function anyPlayerLookingAt(p: Vector3): boolean
		if spotSeen(p) then
			return true
		end
		-- เช็กมุมมองของผู้เล่นคนอื่นในห้องด้วย (ห้ามย้ายถ้ามีเพื่อนคนไหนหันหน้าไปทางจุดนั้นอยู่)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local head = (other.Character:FindFirstChild("Head") or other.Character:FindFirstChild("HumanoidRootPart")) :: BasePart?
				if head then
					local toTarget = p - head.Position
					local dist = toTarget.Magnitude
					if dist <= UNSEEN_DIST and dist > 0.1 then
						local look = head.CFrame.LookVector
						-- มุมมองด้านหน้า ~125 องศา (dot > 0.15)
						if (toTarget / dist):Dot(look) > 0.15 then
							return true
						end
					end
				end
			end
		end
		return false
	end

	local function scarecrowBoxSeen(pos: Vector3): boolean
		return anyPlayerLookingAt(pos + Vector3.new(0, 1.0, 0))
			or anyPlayerLookingAt(pos + Vector3.new(0, 3.2, 0))
			or anyPlayerLookingAt(pos + Vector3.new(0, 5.2, 0))
	end

	local function currentRealGroundPos(): Vector3
		local sc0 = initRealScarecrow()
		local spotCF = sc0 and sc0:GetAttribute("SpotCFrame")
		if typeof(spotCF) == "CFrame" then
			return spotCF.Position
		end
		local coord = ROAM_SPOTS[currentSpotIdx]
		if type(coord) == "table" then
			return Vector3.new(coord[1], groundAt(coord[1], coord[2]), coord[2])
		end
		if lastVisiblePivot then
			return lastVisiblePivot.Position
		end
		if homePivot then
			return homePivot.Position
		end
		return Vector3.new(12.16, 0, -45.64)
	end

	-- (2026-11-22) ย้ายจุดทำที่ server/ScarecrowRoam แล้ว (ทุกคนเห็นเหมือนกัน): ที่นี่แค่โชว์หุ่นกลับมาที่จุดจริงของ server
	local function placeRealAtSpot(idx: number)
		local sc = initRealScarecrow()
		if not sc or not homePivot then
			return
		end
		if typeof(sc:GetAttribute("SpotCFrame")) == "CFrame" then
			setRealVisible(true)
			return
		end
		local coord = ROAM_SPOTS[idx]
		currentSpotIdx = idx
		if type(coord) ~= "table" then
			setRealVisible(false)
			return
		end
		local x, z = coord[1], coord[2]
		local y = groundAt(x, z) + homeGroundOffset
		local p = Vector3.new(x, y, z)
		local front = shopFront()
		local targetCF = CFrame.lookAt(p, Vector3.new(front.X, y, front.Z)) * CFrame.Angles(0, math.pi, 0)
		lastVisiblePivot = targetCF
		-- หน้าหุ่นอยู่ฝั่ง -LookVector ของ pivot จึงหมุน 180° ให้หันหน้าเข้าหาร้านเสมอ
		sc:PivotTo(targetCF)
		setRealVisible(true)
	end

	-- ---------------------------------------------------------------- ตอนไฟดับ: หันหน้าจ๊ะเอ๋หุ่นไล่การะยะประชิด + เสียงเบาๆ หันหลบแล้วหาย
	local closeModel: Model? = nil
	local closeConn: RBXScriptConnection? = nil
	-- หุ่นดักข้างหลังตอนไฟดับ: คืนละครั้ง (นับตอนผู้เล่นหันมาเจอจริง ผู้ใช้ 2026-11-22 "จั้มสแกจากข้างหลังแค่ครั้งเดียวพอ")
	local MAX_CLOSE_SCARES = 1
	local closeScaresThisNight = 0
	local nextOutagePopAt = 0

	local function clearCloseScarecrow(restoreReal: boolean?)
		local hadModel = closeModel ~= nil
		if closeConn then
			closeConn:Disconnect()
			closeConn = nil
		end
		if closeModel then
			closeModel:Destroy()
			closeModel = nil
		end
		-- ถ้าไม่ได้ไฟดับอยู่ (เช่น กดเทสต์ตอนไฟติด) พอหุ่นที่ตามหลังหายไปแล้ว ให้คืนหุ่นตัวจริงกลับเข้าจุดเดิมเมื่อไม่ได้มอง
		if hadModel and restoreReal and ReplicatedStorage:GetAttribute("PowerOn") ~= false then
			task.spawn(function()
				local sc = initRealScarecrow()
				if not sc or not homePivot then
					return
				end
				local idx = if type(ROAM_SPOTS[currentSpotIdx]) == "table" then currentSpotIdx else 1
				local c = ROAM_SPOTS[idx]
				local checkPos = if type(c) == "table" then Vector3.new(c[1], groundAt(c[1], c[2]), c[2]) else homePivot.Position
				while scarecrowBoxSeen(checkPos) do
					task.wait(0.5)
					if ReplicatedStorage:GetAttribute("PowerOn") == false or closeModel ~= nil then
						return
					end
				end
				placeRealAtSpot(idx)
			end)
		end
	end

	local function playSoftJumpscareSound()
		local s = Instance.new("Sound")
		s.Name = "ScarecrowCloseSting"
		s.SoundId = SOFT_SCARE_ID
		s.Volume = SOFT_SCARE_VOL
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx and sfx:IsA("SoundGroup") then
			s.SoundGroup = sfx
		end
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(6, function()
			if s.Parent then
				s:Destroy()
			end
		end)
	end

	local function spawnCloseScarecrow(forcePowerOff: boolean?): boolean
		local sc = initRealScarecrow()
		local cam = Workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (sc and cam and root) then
			return false
		end
		-- วางดักไว้ด้านหลังกล้อง (~150-210 องศาจากทิศที่มองอยู่) ระยะประชิด 4.5 studs
		-- เพื่อให้ผู้เล่นต้องหันหลัง/หันข้างมาเจอด้วยตัวเอง ไม่ใช่เสกโผล่ปุ๊บปั๊บต่อหน้า
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		if look.Magnitude < 0.05 then
			return false
		end
		look = look.Unit
		local dist = 4.5
		local rayP = RaycastParams.new()
		rayP.FilterType = Enum.RaycastFilterType.Exclude
		rayP.FilterDescendantsInstances = { player.Character :: Instance, folder, sc }

		local chosenDir: Vector3? = nil
		local chosenAngle = 0
		-- ลองสุ่มมุมด้านหลังผู้เล่น (180° ± 35° หรือเยื้องหลังซ้าย/ขวา) ที่ไม่มีกำแพงกั้นและอยู่นอกจอแน่นอน
		local baseAngles = { 180, 155, -155, 130, -130 }
		local startShift = math.random(0, #baseAngles - 1)
		for i = 1, #baseAngles do
			local deg = baseAngles[((i + startShift - 1) % #baseAngles) + 1] + (math.random() - 0.5) * 16
			local rad = math.rad(deg)
			local dir = CFrame.Angles(0, rad, 0):VectorToWorldSpace(look)
			local hit = Workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), dir * (dist + 0.8), rayP)
			if not (hit and hit.Instance.CanCollide and hit.Instance.Transparency < 0.5) then
				local testPos = root.Position + dir * dist + Vector3.new(0, 2.5, 0)
				local _, onScreen = cam:WorldToViewportPoint(testPos)
				if not onScreen then
					chosenDir = dir
					chosenAngle = math.atan2(dir.X, dir.Z)
					break
				end
			end
		end
		if not chosenDir then
			return false
		end
		local targetXZ = root.Position + chosenDir * dist

		clearCloseScarecrow()
		-- ตอนหุ่นไล่กาเริ่มแอบตามหลังผู้เล่น หุ่นไล่กาตัวหลักในทุ่งต้องหายไปทันที (ไม่ให้มีหุ่น 2 ตัวในฉากพร้อมกัน)
		setRealVisible(false)
		if current and current.kind == "Scarecrow" then
			hide(0.2)
		end
		local m = sc:Clone()
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Script") or d:IsA("ProximityPrompt") or d:IsA("Light") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				if string.find(d.Name, "Eye") then
					d.Color = Color3.fromRGB(26, 22, 20)
					d.Material = Enum.Material.SmoothPlastic
				end
				d.Transparency = baseTrans[d] or 0
			end
		end
		local y = groundAt(targetXZ.X, targetXZ.Z) + homeGroundOffset
		local pos = Vector3.new(targetXZ.X, y, targetXZ.Z)
		-- หันหน้าจ้องแผ่นหลังผู้เล่น รอให้ผู้เล่นหันมาจ๊ะเอ๋เอง
		m:PivotTo(CFrame.lookAt(pos, Vector3.new(root.Position.X, y, root.Position.Z)) * CFrame.Angles(0, math.pi, 0))
		m.Name = "ScarecrowOutageClose"
		m.Parent = folder
		closeModel = m

		local seenOnce = false
		local stungOnce = false
		local seenDuration = 0
		local lookAwayTime = 0
		local bornAt = os.clock()
		local stalkAngle = chosenAngle -- มุมข้างหลังที่หุ่นแอบเดินตามเกาะติดตอนผู้เล่นยังไม่หันมามอง
		local lastRootXZ = Vector3.new(root.Position.X, 0, root.Position.Z)

		closeConn = RunService.Heartbeat:Connect(function(dt)
			if not closeModel or not closeModel.Parent then
				clearCloseScarecrow()
				return
			end
			-- ถ้าไฟกลับมา หรือเข้าคัทซีน หรืออยู่ในหน้าโหลด/ยังไม่เปิดร้าน ให้หายทันที (ยกเว้นกดเทสต์จากปุ่ม Admin)
			local inCut = Lighting:GetAttribute("Cutscene") == true or ReplicatedStorage:GetAttribute("CutsceneRunning") == true
			local shopOpen = remotes:GetAttribute("ShopOpen") == true
			if (not forcePowerOff and (ReplicatedStorage:GetAttribute("PowerOn") ~= false or not shopOpen)) or inCut then
				clearCloseScarecrow()
				return
			end
			local c = Workspace.CurrentCamera
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not (c and r) then
				return
			end

			-- ตราบใดที่ผู้เล่นยังไม่หันมาเห็น: ถ้าผู้เล่นเดินเคลื่อนที่ ให้หุ่นแอบขยับตามข้างหลังผู้เล่นเงียบๆ (ระยะ 4.5 studs)
			-- แต่จะไม่หมุนหนีตามการหันเมาส์ เพื่อให้เวลาผู้เล่นหันหลังกลับมาจ๊ะเอ๋ได้ทันทีแม้กำลังเดินอยู่!
			if not seenOnce then
				local curRootXZ = Vector3.new(r.Position.X, 0, r.Position.Z)
				if (curRootXZ - lastRootXZ).Magnitude > 0.02 then
					lastRootXZ = curRootXZ
					-- เช็กว่าตำแหน่งที่จะขยับตามไป এখনওอยู่นอกจอและไม่ติดกำแพง
					local stalkDir = Vector3.new(math.sin(stalkAngle), 0, math.cos(stalkAngle))
					local nextXZ = curRootXZ + stalkDir * dist
					local testScreen, onScr = c:WorldToViewportPoint(Vector3.new(nextXZ.X, r.Position.Y + 2.2, nextXZ.Z))
					if not (onScr and testScreen.Z > 0) then
						local hit = Workspace:Raycast(r.Position + Vector3.new(0, 1.5, 0), stalkDir * (dist + 0.6), rayP)
						if not (hit and hit.Instance.CanCollide and hit.Instance.Transparency < 0.5) then
							local ny = groundAt(nextXZ.X, nextXZ.Z) + homeGroundOffset
							pos = Vector3.new(nextXZ.X, ny, nextXZ.Z)
							closeModel:PivotTo(CFrame.lookAt(pos, Vector3.new(r.Position.X, ny, r.Position.Z)) * CFrame.Angles(0, math.pi, 0))
						end
					end
				else
					-- ผู้เล่นยืนนิ่งแต่หมุนตัว: หันหน้าหุ่นจ้องผู้เล่นเสมอ
					closeModel:PivotTo(CFrame.lookAt(pos, Vector3.new(r.Position.X, pos.Y, r.Position.Z)) * CFrame.Angles(0, math.pi, 0))
				end
			end

			local cf, size = closeModel:GetBoundingBox()
			local chest = cf.Position + Vector3.new(0, size.Y * 0.15, 0)
			local head = cf.Position + Vector3.new(0, size.Y * 0.35, 0)
			local sp1, on1 = c:WorldToViewportPoint(chest)
			local sp2, on2 = c:WorldToViewportPoint(head)
			local vs = c.ViewportSize
			local inView = false
			local wellSeen = false
			for _, pair in ipairs({ { sp1, on1 }, { sp2, on2 } }) do
				local sp, on = pair[1], pair[2]
				if on and sp.Z > 0 then
					local dx = math.abs(sp.X - vs.X / 2) / (vs.X / 2)
					local dy = math.abs(sp.Y - vs.Y / 2) / (vs.Y / 2)
					if dx <= 0.85 and dy <= 0.90 then
						inView = true
					end
					-- เข้ามาในกรอบสายตาแล้วถึงดังเสียงจั๊มสแกร์เบาๆ และหยุดขยับตามทันที
					if dx <= 0.65 and dy <= 0.75 then
						wellSeen = true
					end
				end
			end
			if inView and not seenOnce then
				-- ทันทีที่ขอบตัวหุ่นเริ่มเข้าจอ ให้หยุดขยับตามผู้เล่นทันที (ยืนแข็งทื่อรอจ๊ะเอ๋)
				seenOnce = true
			end
			if wellSeen and not stungOnce then
				stungOnce = true
				seenOnce = true
				closeScaresThisNight += 1
				playSoftJumpscareSound()
			end
			if inView then
				if stungOnce then
					seenDuration += dt
					lookAwayTime = 0
				end
			elseif stungOnce and seenDuration >= 0.10 then
				lookAwayTime += dt
				-- พอหันเจอแล้วสะบัดมุมกล้องหลบพ้นจอปุ๊บ หายไปทันที
				if lookAwayTime >= 0.08 then
					clearCloseScarecrow(true)
				end
			elseif not stungOnce and os.clock() - bornAt > 25 then
				-- ตามหลังมา 25 วิแล้วยังไม่หันมาเจอ ก็สลายไปเงียบๆ รอรอบหน้า
				clearCloseScarecrow(true)
			end
		end)
		return true
	end

	-- ซ่อนหุ่นตัวจริงทันทีที่ไฟดับ และสุ่มวางหุ่นดักข้างหลังผู้เล่นเงียบๆ รอให้หันไปเจอเอง
	-- (ผู้ใช้ 2026-11-19: ตอนไฟดับตอนเริ่มเกมยังไม่ต้องหลอก/หุ่นยังไม่ต้องหาย ให้รอจนสตาร์ทเครื่องปั่นไฟติดครั้งแรกก่อน)
	local wasPowerOff = false
	local powerEverRestored = false
	local lastShopState = false
	local movesThisNight = 0
	local MAX_MOVES_PER_NIGHT = 2

	RunService.Heartbeat:Connect(function(_dt)
		local powerOff = ReplicatedStorage:GetAttribute("PowerOn") == false
		local shopOpen = remotes:GetAttribute("ShopOpen") == true
		local inCutscene = Lighting:GetAttribute("Cutscene") == true or ReplicatedStorage:GetAttribute("CutsceneRunning") == true
		local testMode = ReplicatedStorage:GetAttribute("TestMode") == true

		-- เริ่มคืนใหม่: รีเซ็ตจำนวนครั้งที่ย้าย และสถานะไฟติดครั้งแรกของคืน
		if shopOpen and not lastShopState then
			lastShopState = true
			powerEverRestored = not powerOff
			movesThisNight = 0
			closeScaresThisNight = 0
			wasPowerOff = false
			clearCloseScarecrow()
			placeRealAtSpot(1)
		elseif not shopOpen and lastShopState then
			lastShopState = false
			powerEverRestored = false
			movesThisNight = 0
			wasPowerOff = false
			clearCloseScarecrow()
			placeRealAtSpot(1)
		end

		if shopOpen and not powerOff and not powerEverRestored then
			powerEverRestored = true
		end

		-- ไฟดับจริงในเกม = ต้องเปิดร้านแล้ว + ผ่านการปั่นไฟติดตอนเริ่มเกมมาแล้ว (powerEverRestored) + ไม่อยู่ในคัทซีน
		local activeOutage = powerOff and shopOpen and powerEverRestored and not inCutscene

		if activeOutage and not wasPowerOff then
			wasPowerOff = true
			-- จังหวะที่ไฟดับระหว่างคืน: หุ่นไล่กาหายตัวไปเมื่อไม่มีใครมอง
			task.spawn(function()
				while ReplicatedStorage:GetAttribute("PowerOn") == false and not realHidden and scarecrowBoxSeen(currentRealGroundPos()) do
					task.wait(0.25)
				end
				if ReplicatedStorage:GetAttribute("PowerOn") == false then
					setRealVisible(false)
				end
			end)
			if current and current.kind == "Scarecrow" then
				hide(0.2)
			end
			-- รอ 4-9 วิหลังไฟดับถึงเริ่มสุ่มแอบมายืนดักข้างหลัง
			nextOutagePopAt = os.clock() + rand({ 4, 9 })
		elseif not activeOutage and wasPowerOff then
			wasPowerOff = false
			clearCloseScarecrow()
			-- ไฟกลับมา: รอจังหวะที่ไม่มีใครมองจุดเดิม แล้วคืนหุ่นกลับมาที่เสากลางทุ่ง
			if not powerOff then
				task.spawn(function()
					local sc = initRealScarecrow()
					if not sc or not homePivot then
						return
					end
					while scarecrowBoxSeen(homePivot.Position) do
						task.wait(0.5)
						if ReplicatedStorage:GetAttribute("PowerOn") == false then
							return
						end
					end
					placeRealAtSpot(1)
				end)
			end
		end

		-- ตอนไฟดับ (เฉพาะหลังปั่นไฟรอบแรกติดแล้ว): ซ่อนหุ่นตัวจริงเมื่อไม่มีใครมอง และสุ่มเอาหุ่นไปยืนดักข้างหลังเงียบๆ
		if activeOutage then
			if not realHidden and not scarecrowBoxSeen(currentRealGroundPos()) then
				setRealVisible(false)
			end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local praying = player:GetAttribute("Praying") == true
			if not testMode and hum and hum.Health > 0 and not praying and not closeModel and os.clock() >= nextOutagePopAt and closeScaresThisNight < MAX_CLOSE_SCARES then
				if math.random() < 0.55 and spawnCloseScarecrow() then
					-- โผล่ดักข้างหลังแล้ว รอผู้เล่นหันมาเจอ (หรือหมดเวลา 25 วิ) แล้วเว้น 16-30 วิ
					nextOutagePopAt = os.clock() + rand({ 16, 30 })
				else
					nextOutagePopAt = os.clock() + rand({ 4, 8 })
				end
			end
		end
	end)

	-- ลูปย้ายจุดเมื่อละสายตา: ย้ายไป server/ScarecrowRoam แล้ว (ผู้ใช้ 2026-11-22: ให้ทุกคนเห็นจุดเดียวกัน)
	--   กติกาเดิม (ครึ่งหลังของคืน ไม่มีใครมอง คืนละ 2 ครั้ง) อยู่ที่ server · เครื่องนี้แค่โชว์/ซ่อนหุ่นตาม SpotCFrame

	-- ปุ่มทดสอบจาก AdminPanel หรือเรียกผ่าน attribute ScarecrowTest ("close" / "move" / "vanish" / "home")
	player:GetAttributeChangedSignal("ScarecrowTest"):Connect(function()
		local v = player:GetAttribute("ScarecrowTest")
		local cmd = if type(v) == "string" then string.match(v, "^(%w+)") else nil
		if cmd == "close" then
			spawnCloseScarecrow(true)
		elseif cmd == "move" then
			local nextIdx = (currentSpotIdx % #ROAM_SPOTS) + 1
			placeRealAtSpot(nextIdx)
		elseif cmd == "vanish" then
			clearCloseScarecrow()
			if current and current.kind == "Scarecrow" then
				hide(0.2)
			end
			setRealVisible(false)
		elseif cmd == "home" then
			clearCloseScarecrow()
			placeRealAtSpot(1)
		elseif cmd == "restore" then
			local idx = if type(ROAM_SPOTS[currentSpotIdx]) == "table" then currentSpotIdx else 1
			placeRealAtSpot(idx)
		end
	end)
end
