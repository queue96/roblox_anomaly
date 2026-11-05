-- SoundBank.luau
-- คลังเสียงและระบบแต่งเสียงนุ่มลึก ไม่แสบหู (Warm Low-Pass / Soft EQ) สำหรับเกม "ปั๊มหลอดท้ายทุ่ง"
-- รองรับทั้ง:
--   1. เสียงพร้อมใช้ทันทีจาก Roblox Creator Store (แต่งด้วย EqualizerSoundEffect + PitchShift + Reverb)
--   2. เสียงจากไฟล์ .wav ที่สังเคราะห์ด้วย tools/audio/generate_sounds.py (ถ้าคุณอัปโหลดไฟล์ใน assets/sounds/ ขึ้น Roblox แล้วเอา rbxassetid:// มาใส่ใน CUSTOM_UPLOADED_IDS ระบบจะสลับไปใช้ไฟล์ที่คุณอัปโหลดทันที!)

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundBank = {}

-- ---------------------------------------------------------------- 1. ตารางใส่ rbxassetid:// ของไฟล์เสียงใน assets/sounds/ (เผื่ออัปโหลดเพิ่มเอง)
-- ถ้ายังเป็น "" ระบบจะใช้เสียง Creator Store + เอฟเฟกต์แต่งเสียงด้านล่างให้อัตโนมัติทันที!
SoundBank.CustomUploadedIds = {
	-- 1) Gameplay SFX
	PumpCrankLoop = "",         -- assets/sounds/sfx_pump_crank_loop.wav
	FuelGlugLoop = "",          -- assets/sounds/sfx_fuel_glug_loop.wav
	ShutterCloseSlam = "",      -- assets/sounds/sfx_shutter_close_slam.wav
	ShutterOpenPull = "",       -- assets/sounds/sfx_shutter_open_pull.wav
	CoinTinDrop1 = "",          -- assets/sounds/sfx_coin_tin_drop_1.wav
	CoinTinDrop2 = "",          -- assets/sounds/sfx_coin_tin_drop_2.wav
	IncenseExtinguish = "",     -- assets/sounds/sfx_incense_extinguish.wav
	MotoApproachIdle = "",      -- assets/sounds/sfx_moto_approach_idle.wav
	PickupDieselIdle = "",      -- assets/sounds/sfx_pickup_diesel_idle.wav

	-- 2) เสียงหลอกผู้เล่น (Prank / Haunt)
	BreathNeckLeft = "",        -- assets/sounds/haunt_breath_neck_left.wav
	BreathNeckRight = "",       -- assets/sounds/haunt_breath_neck_right.wav
	BreathBehindSlow = "",      -- assets/sounds/haunt_breath_behind_slow.wav
	WalkDirtCircle = "",        -- assets/sounds/haunt_walk_dirt_circle.wav
	WalkDirtHurry = "",         -- assets/sounds/haunt_walk_dirt_hurry.wav
	WalkShopWood1 = "",         -- assets/sounds/haunt_walk_shop_wood_1.wav
	WalkShopWood2 = "",         -- assets/sounds/haunt_walk_shop_wood_2.wav
	RoofTinSteps = "",          -- assets/sounds/haunt_roof_tin_steps.wav
	ClimbTree1 = "",            -- assets/sounds/haunt_climb_tree_1.wav
	ClimbTree2 = "",            -- assets/sounds/haunt_climb_tree_2.wav

	-- 3) เพลงวิทยุลูกทุ่งเหงาๆ หลอนๆ
	LukThung1 = "",             -- assets/sounds/radio_lukthung_1_lamnam_thung_mued.wav
	LukThung2 = "",             -- assets/sounds/radio_lukthung_2_khlui_sao_tai_sai.wav
	LukThung3 = "",             -- assets/sounds/radio_lukthung_3_winyan_rak_nak_leng.wav
	LukThung4 = "",             -- assets/sounds/radio_lukthung_4_klom_khuen_duean_dap.wav
	LukThung5 = "",             -- assets/sounds/radio_lukthung_5_am_detuned_ghost.wav

	-- 4) เสียงพระ/ไทบ้านอีสานสวดมนต์ไทย 4 บท (โทนเสียงเดียวกัน แยกโหมดสวดปกติ & โหมดสวดรัวเร็วตอนเจอผี!)
	Chant1_Kusala_Normal = "rbxassetid://118042869785522",
	Chant2_Anicca_Normal = "rbxassetid://118042869785522",
	Chant3_PhraMalai_Normal = "rbxassetid://118042869785522",
	Chant4_NamoTassa_Normal = "rbxassetid://118042869785522",

	Chant1_Kusala_Scared = "rbxassetid://118042869785522",
	Chant2_Anicca_Scared = "rbxassetid://118042869785522",
	Chant3_PhraMalai_Scared = "rbxassetid://118042869785522",
	Chant4_NamoTassa_Scared = "rbxassetid://118042869785522",

	Chant1_Kusala = "rbxassetid://118042869785522",
	Chant2_Anicca = "rbxassetid://118042869785522",
	Chant3_PhraMalai = "rbxassetid://118042869785522",
	Chant4_NamoTassa = "rbxassetid://118042869785522",

	-- 5) เสียงขาจรบนถนน: เด็กแว้น + เพลงแดนซ์รถเครื่องเสียง + เพลงรถแห่งานบวช
	RacerMotoRevCut = "",       -- assets/sounds/sfx_racer_moto_rev_cut.wav
	RacerWheeliePass = "",      -- assets/sounds/sfx_racer_wheelie_pass.wav
	DanceMusic1_SaiYor = "",    -- assets/sounds/music_thai_dance_1_sai_yor.wav
	DanceMusic2_MorlamEDM = "", -- assets/sounds/music_thai_dance_2_morlam_edm.wav
	ParadeMusic1_RotHae = "",   -- assets/sounds/music_parade_1_rothe_isan.wav
	ParadeMusic2_KlongYao = "", -- assets/sounds/music_parade_2_klongyao_brass.wav

	-- 6) เสียงอุทานสั้นๆ / เสียงหนาวสั่น / เสียงหวาดกลัวผวา (assets/sounds/reactions/React_*.wav)
	React_Startle_Huh_M1 = "rbxassetid://129631914908386",  -- เฮ้ย! (ชาย)
	React_Startle_Huh_M2 = "rbxassetid://130158442655576",  -- เฮ้ย! อีหยังวะ! (ชาย)
	React_Startle_Huh_F1 = "rbxassetid://86655418231086",  -- เฮ้ย! (หญิง)
	React_Startle_Huh_F2 = "rbxassetid://114087252777494",  -- ว้าย! ตกใจเบิดเลย! (หญิง)
	React_Question_Haa_M1 = "", -- ห๊า?! (ชาย)
	React_Question_Haa_M2 = "", -- ห๊า... แม่นติ? (ชาย)
	React_Question_Haa_F1 = "", -- ห๊า?! (หญิง)
	React_Question_Haa_F2 = "", -- ห๊า... อีหยังเกาะ? (หญิง)
	React_Confused_Hmm_M = "",  -- หือ... เอ๊ะ... (ชาย)
	React_Confused_Hmm_F = "",  -- หือ... เอ๊ะ... (หญิง)
	React_Shock_Aow_M = "",     -- อ้าว! เฮ้ย! (ชาย)
	React_Shock_Aow_F = "",     -- อ้าว! ตายแล้ว! (หญิง)
	React_Cold_Shiver_M1 = "",  -- บรื๋อ... หนาวสั่น (ชาย 1)
	React_Cold_Shiver_M2 = "",  -- ฮึ่ย... หนาวสั่น (ชาย 2)
	React_Cold_Shiver_F1 = "",  -- บรื๋อ... หนาวสั่น (หญิง 1)
	React_Cold_Shiver_F2 = "",  -- ฮึ่ย... ลมหนาวขนลุก (หญิง 2)
	React_Fear_Panic_M1 = "",   -- เสียงหวาดกลัวผวา (ชาย 1)
	React_Fear_Panic_M2 = "",   -- เสียงหวาดกลัวผวา (ชาย 2)
	React_Fear_Panic_F1 = "",   -- เสียงหวาดกลัวผวา (หญิง 1)
	React_Fear_Panic_F2 = "",   -- เสียงหวาดกลัวผวา (หญิง 2)
	React_Fear_Tremble_M = "",  -- เสียงสั่นกลัวข้างหลัง (ชาย)
	React_Fear_Tremble_F = "",  -- เสียงสั่นกลัวข้างหลัง (หญิง)
}

-- ตารางใส่ rbxassetid:// ของไฟล์เสียงพากย์บทสนทนาทั้ง 151 ไฟล์ใน assets/sounds/dialogues/<Key>.wav
-- (รองรับทั้งคีย์ตรง เช่น "Greet_Uncle" และคีย์แยกเพศอัตโนมัติ เช่น "AskPrice_M" / "AskPrice_F" / "PlayerHello_M" / "PlayerHello_F")
-- เก็บสถิติเสียงพากย์ที่เกมเล่นจริง (เฉพาะใน Studio): print "VOICE|..." ลง Output / log ไว้นับว่าบทไหนได้ใช้จริง
local VOICE_LOG = game:GetService("RunService"):IsStudio()

SoundBank.DubbedVoiceVolume = 1.6 -- ความดังเสียงพากย์คนจริง (ไฟล์ TTS เดิม 0.58) เบา/ดังไปปรับตรงนี้

SoundBank.DialogueUploadedIds = {
	-- ตัวอย่าง: Greet_Uncle = "rbxassetid://...", AskPrice_M = "rbxassetid://...", PlayerHello_F = "rbxassetid://..."

	-- คัตซีนเปิดเกม (พากย์อีสานจริง assets/sounds/dialogues/*.mp3)
	-- (Intro_Brother_1-3 อัปโหลดใหม่รอบ 2026-11-04 แทนอันเก่า 101512046595571 / 71101982068825 / 118704825470823)
	Intro_Brother_1 = "rbxassetid://113642193083137",
	Intro_Brother_2 = "rbxassetid://90728172974668",
	Intro_Brother_3 = "rbxassetid://113949562141083",

	-- ลูกค้าทักทาย / คุยระหว่างรอ (ตามโปรไฟล์ลูกค้า ไม่แยกเพศ)
	Greet_Uncle = "rbxassetid://124079216219424",
	Greet_Aunt = "rbxassetid://135684387590380",
	Greet_Student = "rbxassetid://89982569853810",
	Greet_Farmer = "rbxassetid://124747645986293",
	Normal_Uncle = "rbxassetid://140569712863000",
	Normal_Aunt = "rbxassetid://118268650812731",
	Normal_Student = "rbxassetid://107405527295991",
	Normal_Farmer = "rbxassetid://90304011725352",

	-- สั่งน้ำมัน ตามประเภทยานพาหนะ
	Walker_Order_1 = "rbxassetid://80383433386927",
	Walker_Order_2 = "rbxassetid://106758192539257",
	Walker_Order_3 = "rbxassetid://73303762715875",
	Walker_Order_4 = "rbxassetid://116836694647618",
	Car_Order_1 = "rbxassetid://116893915864843",
	Car_Order_2 = "rbxassetid://138787121928225",
	Car_Order_3 = "rbxassetid://126135755891811",
	TukTuk_Order_1 = "rbxassetid://127881304792192",
	TukTuk_Order_2 = "rbxassetid://121497903379847",
	Bicycle_Order_1 = "rbxassetid://99921307413540",
	Bicycle_Order_2 = "rbxassetid://123603068735237",

	-- จ่ายเงิน (แยกเสียงชาย/หญิงตามลูกค้า)
	Pay_1_M = "rbxassetid://89727972519219",
	Pay_1_F = "rbxassetid://103715596216799",
	Pay_2_M = "rbxassetid://98285445493290",
	Pay_2_F = "rbxassetid://79980471421044",
	Pay_3_M = "rbxassetid://138230893125902",
	Pay_3_F = "rbxassetid://122927726611288",

	-- ลูกค้ารอนาน / เร่ง / ทักคิว
	Greet_Waited_M = "rbxassetid://88665687649497",
	Greet_Waited_F = "rbxassetid://107823156545973",
	Impatient_1_M = "rbxassetid://99326167547702",
	Impatient_1_F = "rbxassetid://80749077424250",
	Impatient_2_M = "rbxassetid://125685947008192",
	Impatient_2_F = "rbxassetid://137204654697077",
	Impatient_3_M = "rbxassetid://74873106276661",
	Impatient_3_F = "rbxassetid://113508307082559",
	Queue_Chime_M = "rbxassetid://113965823398340",
	Queue_Chime_F = "rbxassetid://82783583982805",
	NoOne_1_M = "rbxassetid://107718528797788",
	NoOne_1_F = "rbxassetid://90433543795714",
	NoOne_2_M = "rbxassetid://109429992064846",
	NoOne_2_F = "rbxassetid://95256866710286",

	-- เติมผิดตู้ / จ่ายช้า / โดนปฏิเสธ
	Wrong_NeedFuel_M = "rbxassetid://129287586147989",
	Wrong_NeedFuel_F = "rbxassetid://87420590770644",
	Wrong_NeedPetrol_M = "rbxassetid://86826626985185",
	Wrong_NeedPetrol_F = "rbxassetid://97082285254450",
	Wrong_NeedDiesel_M = "rbxassetid://89422788816781",
	Wrong_NeedDiesel_F = "rbxassetid://93982819043135",
	Wrong_NeedAir_M = "rbxassetid://109515457797724",
	Wrong_NeedAir_F = "rbxassetid://70544510139982",
	Pay_Slow_M = "rbxassetid://113082132363913",
	Pay_Slow_F = "rbxassetid://123532358154818",
	Rejected_1_M = "rbxassetid://125395137668895",
	Rejected_1_F = "rbxassetid://77530178287051",
	Rejected_2_M = "rbxassetid://131143966474701",
	Rejected_2_F = "rbxassetid://127722535641568",

	-- ลูกค้าพูดตอนแผงร้านเปิด / ปิดต่อหน้า
	Shutter_Open_1_M = "rbxassetid://98016373246241",
	Shutter_Open_1_F = "rbxassetid://122677831744462",
	Shutter_Open_2_M = "rbxassetid://114999698716069",
	Shutter_Open_2_F = "rbxassetid://72396976201656",
	Shutter_Open_3_M = "rbxassetid://112592122590868",
	Shutter_Open_3_F = "rbxassetid://79635255602673",
	Shutter_Closed_1_M = "rbxassetid://137332217812444",
	Shutter_Closed_1_F = "rbxassetid://74928695416599",
	Shutter_Closed_2_M = "rbxassetid://88666908641530",
	Shutter_Closed_2_F = "rbxassetid://140044696079853",
	Shutter_Closed_3_M = "rbxassetid://107782373965219",
	Shutter_Closed_3_F = "rbxassetid://73392531333493",

	-- ลูกค้าทักคนพนมมือ
	Pray_Ask_1_M = "rbxassetid://93125176294677",
	Pray_Ask_1_F = "rbxassetid://115035686543508",
	Pray_Ask_2_M = "rbxassetid://129074712887611",
	Pray_Ask_2_F = "rbxassetid://132894536569628",
	Pray_Ask_3_M = "rbxassetid://106825157155459",
	Pray_Ask_3_F = "rbxassetid://84278109213466",
	Pray_Ask_4_M = "rbxassetid://125312309692669",
	Pray_Ask_4_F = "rbxassetid://131695284992255",
	Pray_After_1_M = "rbxassetid://103221332740357",
	Pray_After_1_F = "rbxassetid://78994031383062",
	Pray_After_2_M = "rbxassetid://79656601360432",
	Pray_After_2_F = "rbxassetid://71773063993619",
	Pray_Ghost_1_M = "rbxassetid://105448388105251",
	Pray_Ghost_1_F = "rbxassetid://110910342680855",
	Pray_Ghost_2_M = "rbxassetid://118613079122215",
	Pray_Ghost_2_F = "rbxassetid://131498664469603",
	Pray_Ghost_3_M = "rbxassetid://135171697217682",
	Pray_Ghost_3_F = "rbxassetid://137619306973532",
	Pray_GhostAfter_1_M = "rbxassetid://139796578586671",
	Pray_GhostAfter_1_F = "rbxassetid://92175695828583",
	Pray_GhostAfter_2_M = "rbxassetid://123010882457849",
	Pray_GhostAfter_2_F = "rbxassetid://102927310075959",

	-- เสียงกระซิบตอนสวดเรียกผี
	Pray_Summon_1 = "rbxassetid://111442887245112",
	Pray_Summon_2 = "rbxassetid://128575611906473",
	Pray_Summon_3 = "rbxassetid://74307670216532",

	-- ฝน / คนหลบฝน (ยังมีแค่เพศเดียว อีกเพศใช้เสียงเดิม)
	RainTalk_1_M = "rbxassetid://108765476380825",
	Shelter_Ask_F = "rbxassetid://78514124480838",

	-- ขาจร: รถเครื่องเสียง / รถแห่
	Party_Line = "rbxassetid://115037195700895",
	Teen_Line = "rbxassetid://129476554217488",
	Coyote_Line = "rbxassetid://100042904022492",
	Parade_Invite = "rbxassetid://87431658575313",
}

-- ---------------------------------------------------------------- 2. พรีเซ็ตเสียงพร้อมใช้ทันที (Warm Non-Piercing EQ: HighGain ติดลบทุกอันเพื่อไม่ให้แสบหู)
export type SoundPreset = {
	id: string,
	customKey: string?,
	volume: number,
	speed: number?,
	looped: boolean?,
	low: number?,  -- Equalizer LowGain (-80..10)
	mid: number?,  -- Equalizer MidGain
	high: number?, -- Equalizer HighGain (ติดลบเสมอเพื่อตัดเสียงแหลมบาดหู)
	reverbWet: number?,
	reverbDecay: number?,
	pitchOctave: number?,
}

SoundBank.Presets = {
	-- ================= อุปกรณ์ในปั๊ม & ร้านค้า =================
	PumpCrankLoop = {
		id = "rbxassetid://9117159106", -- กลไกหมุนเก่าๆ
		customKey = "PumpCrankLoop",
		volume = 0.35,
		speed = 1.0,
		looped = true,
		low = 3,
		mid = 0,
		high = -18, -- ตัดแหลมไม่ให้แสบหู
	},
	-- ================= ไฟดับ / เครื่องปั่นไฟ (Power.luau) =================
	-- ยังใช้เสียงที่มีอยู่ปรับความเร็ว/โทนให้ใกล้เคียง เปลี่ยน id เป็นเสียงจริงได้ภายหลัง
	PowerOffClunk = {
		id = "rbxassetid://8109376048", -- คัตเอาต์ตัด: เสียงโลหะกระแทกทุ้มๆ
		customKey = "PowerOffClunk",
		volume = 0.5,
		speed = 0.7,
		looped = false,
		low = 6,
		mid = 0,
		high = -20,
	},
	GeneratorPull = {
		id = "rbxassetid://9117159106", -- ดึงเชือกสตาร์ท: กลไกหมุนครืด
		customKey = "GeneratorPull",
		volume = 0.55,
		speed = 1.6,
		looped = false,
		low = 2,
		mid = 2,
		high = -14,
	},
	GeneratorRun = {
		-- เครื่องปั่นไฟเดินเรียบๆ ต่อเนื่อง (Creator Store "engine_generator_loop_02")
		-- เดิมใช้เสียงท่อมอไซค์ลดความเร็ว (74974322876141): ดังๆ เบาๆ เป็นจังหวะ ไม่เหมือนเครื่องปั่นไฟ
		id = "rbxassetid://83031465221433",
		customKey = "GeneratorRun",
		volume = 0.07, -- เบาลงอีก (0.1 -> 0.07; เดิมสุด 0.32)
		speed = 1.0,
		looped = true,
		low = 3,
		mid = 0,
		high = -10,
	},
	GeneratorBackfire = {
		id = "rbxassetid://74974322876141", -- เครื่องสะดุด ปัง! (เล่นพร้อมเสียงไฟช็อตตอนกดพลาด)
		customKey = "GeneratorBackfire",
		volume = 0.21, -- 30% ของเดิม (0.7): ดังรวมกับไฟช็อตแล้วแสบหู
		speed = 1.4,
		looped = false,
		low = 8,
		mid = 2,
		high = -10,
	},
	GeneratorShock = {
		id = "rbxassetid://112638971195468", -- ไฟช็อตตอนกดพลาด: ประกายไฟฟ้าแตก (Creator Store "Electric sound")
		customKey = "GeneratorShock",
		volume = 0.12, -- ดังเกิน: เหลือ 30% (0.4 -> 0.12; แรกสุด 0.8)
		speed = 1.0,
		looped = false,
		low = 0,
		mid = 2,
		high = 0,
	},
	FuelGlugLoop = {
		id = "rbxassetid://9117641837", -- เสียงของเหลวไหลลงหลอด/ถัง
		customKey = "FuelGlugLoop",
		volume = 0.42,
		speed = 1.0,
		looped = true,
		low = 4,
		mid = -2,
		high = -16,
	},
	ShutterCloseSlam = {
		id = "rbxassetid://8109376048", -- เสียงปิดกระแทกแผงสังกะสี/ประตูเหล็กหน้าร้าน (Metal Door Close)
		forcePreset = true,
		volume = 0.70,
		speed = 1.0,
		noEffects = true,
	},
	ShutterOpenPull = {
		id = "rbxassetid://7274930890", -- เสียงดึงเปิดแผงสังกะสี (Metal Door Open)
		forcePreset = true,
		volume = 0.65,
		speed = 1.0,
		noEffects = true,
	},
	CoinTinDrop1 = {
		id = "rbxassetid://119445319966378", -- โลหะกระทบกระป๋องแบบนุ่ม
		customKey = "CoinTinDrop1",
		volume = 0.36,
		speed = 1.0,
		low = 0,
		mid = 2,
		high = -18,
	},
	CoinTinDrop2 = {
		id = "rbxassetid://119445319966378",
		customKey = "CoinTinDrop2",
		volume = 0.34,
		speed = 1.0,
		low = 2,
		mid = 1,
		high = -18,
	},
	IncenseExtinguish = {
		id = "rbxassetid://9116496074", -- เสียงฟู่เบาๆ ตอนธูปดับ
		customKey = "IncenseExtinguish",
		volume = 0.45,
		speed = 1.0,
		low = 5,
		mid = -4,
		high = -20,
		reverbWet = -6,
		reverbDecay = 2.8,
	},
	MotoIdle = {
		id = "rbxassetid://74974322876141",
		customKey = "MotoApproachIdle",
		volume = 0.28,
		speed = 1.0, -- ช้าลงให้เป็นเสียงเครื่องเดินเบาทุ้มๆ
		looped = true,
		low = 4,
		mid = -4,
		high = -24,
	},
	DieselIdle = {
		id = "rbxassetid://74974322876141",
		customKey = "PickupDieselIdle",
		volume = 0.32,
		speed = 1.0,
		looped = true,
		low = 6,
		mid = -5,
		high = -26,
	},

	-- ================= เสียงหลอกผู้เล่น (Haunt / Prank Sounds) =================
	-- 1. เสียงหายใจใกล้ๆ คอ (ซ้าย / ขวา / ข้างหลัง)
	BreathNeckLeft = {
		id = "rbxassetid://2643071410",
		customKey = "BreathNeckLeft",
		volume = 0.48,
		speed = 1.0,
		low = 5,
		mid = 2,
		high = -22, -- ลมหายใจอุ่นๆ ลึกๆ ไม่แหลมซ่า
		pitchOctave = 0.85,
	},
	BreathNeckRight = {
		id = "rbxassetid://2643071410",
		customKey = "BreathNeckRight",
		volume = 0.48,
		speed = 1.0,
		low = 5,
		mid = 2,
		high = -22,
		pitchOctave = 0.88,
	},
	BreathBehindSlow = {
		id = "rbxassetid://75664285683608", -- เสียงถอนหายใจ/สะอื้นเบาๆ ชิดหลังคอ
		customKey = "BreathBehindSlow",
		volume = 0.38,
		speed = 1.0,
		low = 6,
		mid = 0,
		high = -24,
		reverbWet = -10,
		reverbDecay = 1.6,
	},

	-- 2. เสียงเดินบนดินรอบร้าน (เดินวนช้าๆ / วิ่งย่ำดินเข้ามาหา)
	WalkDirtCircle = {
		id = "rbxassetid://135952279207329",
		customKey = "WalkDirtCircle",
		volume = 0.52,
		speed = 1.0,
		low = 4,
		mid = 1,
		high = -18,
		reverbWet = -12,
		reverbDecay = 1.8,
	},
	WalkDirtHurry = {
		id = "rbxassetid://135952279207329",
		customKey = "WalkDirtHurry",
		volume = 0.58,
		speed = 1.0,
		low = 5,
		mid = 2,
		high = -16,
	},

	-- 3. เสียงเดินในร้านไปมา & เดินบนหลังคาสังกะสี
	WalkShopWood1 = {
		id = "rbxassetid://135952279207329",
		customKey = "WalkShopWood1",
		volume = 0.46,
		speed = 1.0, -- ทุ้มต่ำเหมือนย่ำพื้นไม้กระดานเก่าในเพิง
		low = 7,
		mid = -2,
		high = -24,
		pitchOctave = 0.78,
		reverbWet = -8,
		reverbDecay = 1.4,
	},
	WalkShopWood2 = {
		id = "rbxassetid://9113542694", -- เสียงไม้ลั่นเอี๊ยดเบาๆ ในร้าน
		customKey = "WalkShopWood2",
		volume = 0.36,
		speed = 1.0,
		low = 6,
		mid = -1,
		high = -24,
		reverbWet = -8,
		reverbDecay = 1.5,
	},
	RoofTinSteps = {
		id = "rbxassetid://9113542694", -- เสียงย่ำบนสังกะสีเหนือหัว
		customKey = "RoofTinSteps",
		volume = 0.42,
		speed = 1.0,
		low = 5,
		mid = 0,
		high = -22,
		reverbWet = -6,
		reverbDecay = 2.0,
	},

	-- 4. เสียงขึ้นต้นไม้ / ตะกายเปลือกไม้ / กิ่งไม้สั่น
	ClimbTree1 = {
		id = "rbxassetid://9113542694",
		customKey = "ClimbTree1",
		volume = 0.48,
		speed = 1.0,
		low = 4,
		mid = 2,
		high = -18,
		reverbWet = -8,
		reverbDecay = 2.2,
	},
	ClimbTree2 = {
		id = "rbxassetid://135952279207329",
		customKey = "ClimbTree2",
		volume = 0.48,
		speed = 1.0,
		low = 3,
		mid = 2,
		high = -18,
		pitchOctave = 0.85,
		reverbWet = -8,
		reverbDecay = 2.2,
	},

	-- ================= 5. ขาจรบนถนน (เด็กแว้น / เพลงแดนซ์ / เพลงรถแห่) =================
	RacerMotoRevCut = {
		id = "rbxassetid://74974322876141", -- เสียงเบิ้ลท่อสูตรตัดรอบแบบตัดแหลมไม่แสบหู
		customKey = "RacerMotoRevCut",
		volume = 0.46,
		speed = 1.0,
		looped = true,
		low = 5,
		mid = 3,
		high = -18,
	},
	RacerWheeliePass = {
		id = "rbxassetid://74974322876141", -- เสียงยกล้อพุ่งผ่านหน้าร้าน
		customKey = "RacerWheeliePass",
		volume = 0.52,
		speed = 1.0,
		looped = false,
		low = 6,
		mid = 4,
		high = -18,
	},
	DanceMusic1_SaiYor = {
		id = "rbxassetid://9040293936", -- เพลงแดนซ์สายย่อสามช่า เบสแน่นตึ๊บๆ ไม่บาดหู
		customKey = "DanceMusic1_SaiYor",
		volume = 0.48,
		speed = 1.0,
		looped = true,
		low = 8,
		mid = 2,
		high = -16,
	},
	DanceMusic2_MorlamEDM = {
		id = "rbxassetid://9040293936", -- เพลงแดนซ์หมอลำซิ่ง EDM รถเครื่องเสียง
		customKey = "DanceMusic2_MorlamEDM",
		volume = 0.48,
		speed = 1.0,
		pitchOctave = 0.96,
		looped = true,
		low = 8,
		mid = 3,
		high = -16,
	},
	ParadeMusic1_RotHae = {
		id = "rbxassetid://9043078311", -- เพลงรถแห่งานบวชสามช่าอีสาน
		customKey = "ParadeMusic1_RotHae",
		volume = 0.46,
		speed = 1.0,
		looped = true,
		low = 6,
		mid = 4,
		high = -16,
	},
	ParadeMusic2_KlongYao = {
		id = "rbxassetid://9043078311", -- แตรวงกลองยาวแห่นาคท้ายทุ่ง
		customKey = "ParadeMusic2_KlongYao",
		volume = 0.46,
		speed = 1.0,
		pitchOctave = 0.95,
		looped = true,
		low = 7,
		mid = 4,
		high = -16,
	},

	-- ================= 6. เสียงอุทาน / หนาวสั่น / หวาดกลัว (แยกชาย _M และหญิง _F) =================
	React_Startle_Huh_M1 = {
		id = "rbxassetid://9114120102", -- เฮ้ย! (ชาย)
		customKey = "React_Startle_Huh_M1",
		volume = 0.44,
		speed = 1.0,
		pitchOctave = 0.88,
		low = 4,
		mid = 3,
		high = -18,
	},
	React_Startle_Huh_M2 = {
		id = "rbxassetid://9114120102",
		customKey = "React_Startle_Huh_M2",
		volume = 0.46,
		speed = 1.0,
		pitchOctave = 0.84,
		low = 5,
		mid = 3,
		high = -18,
	},
	React_Startle_Huh_F1 = {
		id = "rbxassetid://9114120102", -- เฮ้ย! / ว้าย! (หญิง)
		customKey = "React_Startle_Huh_F1",
		volume = 0.42,
		speed = 1.0,
		pitchOctave = 1.18,
		low = 1,
		mid = 4,
		high = -18,
	},
	React_Startle_Huh_F2 = {
		id = "rbxassetid://9114120102",
		customKey = "React_Startle_Huh_F2",
		volume = 0.44,
		speed = 1.0,
		pitchOctave = 1.22,
		low = 1,
		mid = 4,
		high = -18,
	},
	React_Question_Haa_M1 = {
		id = "rbxassetid://9114120102", -- ห๊า?! (ชาย)
		customKey = "React_Question_Haa_M1",
		volume = 0.40,
		speed = 1.0,
		pitchOctave = 0.92,
		low = 4,
		mid = 3,
		high = -18,
	},
	React_Question_Haa_F1 = {
		id = "rbxassetid://9114120102", -- ห๊า?! (หญิง)
		customKey = "React_Question_Haa_F1",
		volume = 0.40,
		speed = 1.0,
		pitchOctave = 1.16,
		low = 1,
		mid = 4,
		high = -18,
	},
	React_Cold_Shiver_M1 = {
		id = "rbxassetid://2643071410", -- บรื๋อ... หนาวสั่น (ชาย)
		customKey = "React_Cold_Shiver_M1",
		volume = 0.36,
		speed = 1.10,
		pitchOctave = 0.84,
		low = 5,
		mid = 2,
		high = -20,
	},
	React_Cold_Shiver_F1 = {
		id = "rbxassetid://75664285683608", -- บรื๋อ... หนาวสั่น (หญิง)
		customKey = "React_Cold_Shiver_F1",
		volume = 0.36,
		speed = 1.10,
		pitchOctave = 1.08,
		low = 2,
		mid = 3,
		high = -20,
	},
	React_Fear_Panic_M1 = {
		id = "rbxassetid://2643071410", -- เสียงหวาดกลัวผวา (ชาย)
		customKey = "React_Fear_Panic_M1",
		volume = 0.46,
		speed = 1.0,
		pitchOctave = 0.90,
		low = 4,
		mid = 3,
		high = -18,
	},
	React_Fear_Panic_F1 = {
		id = "rbxassetid://75664285683608", -- เสียงหวาดกลัวผวา (หญิง)
		customKey = "React_Fear_Panic_F1",
		volume = 0.46,
		speed = 1.0,
		pitchOctave = 1.12,
		low = 2,
		mid = 4,
		high = -18,
	},
	React_Fear_Tremble_M = {
		id = "rbxassetid://2643071410",
		customKey = "React_Fear_Tremble_M",
		volume = 0.38,
		speed = 1.0,
		pitchOctave = 0.82,
		low = 5,
		mid = 2,
		high = -22,
	},
	React_Fear_Tremble_F = {
		id = "rbxassetid://75664285683608",
		customKey = "React_Fear_Tremble_F",
		volume = 0.38,
		speed = 1.0,
		pitchOctave = 1.04,
		low = 2,
		mid = 3,
		high = -22,
	},

	-- ================= 7. เสียงผีแต่ละตัว (ผู้ใช้อัปโหลดเอง ชื่อใน Asset Manager อยู่ในวงเล็บ) =================
	-- ใช้กับโมเดลผีชุดใหม่ใน assets/models (ดู SoundBank.GhostSounds ด้านล่าง) · ยังไม่ได้ผูกกับ anomaly ไหน
	Ghost_Pret = { id = "rbxassetid://83832562118605", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },          -- (ghot_pret)
	Ghost_Pret_Laugh = { id = "rbxassetid://96531336289481", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },    -- (ghot_pret_luagh)
	Ghost_Krahang = { id = "rbxassetid://106658585103812", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },      -- (ghost_krahang)
	Ghost_Krahang_Laugh = { id = "rbxassetid://79000007807242", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 }, -- (ghost_krahang_luagh)
	Ghost_Pop = { id = "rbxassetid://118203855044367", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },          -- (ghost_pob)
	Ghost_Pop_Laugh = { id = "rbxassetid://135236414490615", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },    -- (ghost_pob_luagh)
	-- ghost_thani (85921914400493) ใช้ไม่ได้ -> ใช้เสียงกระซิบ Passenger_Whisper.wav ที่ลากไว้ใน UploadedSounds แทน (ถ้าไม่เจอใช้เสียงหายใจข้างคอ)
	Ghost_Tani = { id = "rbxassetid://2643071410", customKey = "Passenger_Whisper", volume = 0.6, speed = 1.0, low = 5, mid = 2, high = -22 },
	Ghost_Tani_Laugh = { id = "rbxassetid://126775500193812", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },   -- (ghost_thani_luagh)
	Ghost_MaeNak = { id = "rbxassetid://94253655567417", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },        -- (ghost_maenak)
	Ghost_MaeNak_Laugh = { id = "rbxassetid://97648829291844", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },  -- (ghost_maenak_luagh)
	Ghost_Kuman = { id = "rbxassetid://131044226335748", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },        -- (ghost_guman) กุมารทอง
	Ghost_Kuman_Laugh = { id = "rbxassetid://138950273308352", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },  -- (ghost_guman_luagh)
	Ghost_Showtime = { id = "rbxassetid://123185428314556", volume = 0.6, speed = 1.0, low = 3, mid = 1, high = -14 },     -- (ghost_showtime) เสียงตอนผีปรากฏตัว
	CoinDrop = { id = "rbxassetid://81683782868046", volume = 0.4, speed = 1.0, low = 0, mid = 2, high = -18 },            -- (effect_coindrop)
}

-- ผี -> ชื่อ preset เสียงพูด/คราง (voice) และเสียงหัวเราะ (laugh) ใช้ตอนผูกเสียงกับโมเดลผี
SoundBank.GhostSounds = {
	Pret = { voice = "Ghost_Pret", laugh = "Ghost_Pret_Laugh" },
	Krahang = { voice = "Ghost_Krahang", laugh = "Ghost_Krahang_Laugh" },
	Pop = { voice = "Ghost_Pop", laugh = "Ghost_Pop_Laugh" },
	Tani = { voice = "Ghost_Tani", laugh = "Ghost_Tani_Laugh" },
	MaeNak = { voice = "Ghost_MaeNak", laugh = "Ghost_MaeNak_Laugh" },
	Kuman = { voice = "Ghost_Kuman", laugh = "Ghost_Kuman_Laugh" },
	-- ผีที่ไม่มีเสียงของตัวเอง ยืมเสียงผีหญิง/ชายข้างบน (สลับคู่กันไม่ให้ตัวที่โผล่ใกล้กันเสียงซ้ำ)
	Krasue = { voice = "Ghost_MaeNak", laugh = "Ghost_Pop_Laugh" },
	Headless = { voice = "Ghost_Tani", laugh = "Ghost_MaeNak_Laugh" },     -- ไม่มีหัว ใช้เสียงกระซิบ
	Mirror = { voice = "Ghost_MaeNak", laugh = "Ghost_Tani_Laugh" },
	Dancer = { voice = "Ghost_Pop", laugh = "Ghost_MaeNak_Laugh" },
	FuneralMan = { voice = "Ghost_Pret", laugh = "Ghost_Krahang_Laugh" },
	FuneralElderMan = { voice = "Ghost_Krahang", laugh = "Ghost_Pret_Laugh" },
	FuneralWoman = { voice = "Ghost_MaeNak", laugh = "Ghost_Tani_Laugh" },
	FuneralElderWoman = { voice = "Ghost_Pop", laugh = "Ghost_MaeNak_Laugh" },
}

-- ---------------------------------------------------------------- 3. เพลงวิทยุ (เหลือเพลงเดียว radio_song ผู้ใช้สั่ง 2026-11-04 แทน 5 คลื่นลูกทุ่งเดิม)
SoundBank.RadioStations = {
	{
		name = "RadioSong",
		titleTH = "เพลงวิทยุ",
		id = "rbxassetid://101156490081905",
		volume = 0.35, -- ต้องตรงกับ RADIO_VOLUME.music ใน AnomalyManager
		speed = 1.0,
		low = -2,
		mid = 2,
		high = -6,
	},
}

-- ---------------------------------------------------------------- 3.5 บทสวดมนต์: นะโม ตัสสะ 3 จบ (แยก 2 โหมด: ปกติ vs เจอผีสวดเร็ว!)
-- 1) โหมดสวดปกติ (NormalChants): สวดเนิบๆ สำรวม ตอนเปิดตาทิพย์ทั่วไป
SoundBank.MonkChantsNormal = {
	{
		name = "Chant4_NamoTassa_Normal",
		titleTH = "บทสวดนะโม ตัสสะ 3 จบ (สวดปกติ)",
		id = "rbxassetid://1845929179",
		customKey = "Chant4_NamoTassa_Normal",
		fallbackCustomKey = "Chant4_NamoTassa",
		volume = 1.4, -- เดิม 0.50 เบาไป (ผู้ใช้ขอดังขึ้น 2026-11-03) อยู่กลุ่ม Music ที่คูณ 0.35 อีกที
		speed = 1.0,
		low = 1,
		mid = 2,
		high = -6,
	},
}

-- (โหมดสวดเร็วตอนเจอผี MonkChantsScared เอาออกแล้ว ผู้ใช้สั่ง 2026-11-03: สวดปกติทุกครั้ง ไม่ให้ฟังดูตลก)
SoundBank.MonkChants = SoundBank.MonkChantsNormal

-- คืนค่า Preset บทสวด (สวดปกติเสมอ isGhostPresent ไม่มีผลแล้ว เก็บพารามิเตอร์ไว้ให้โค้ดเดิมเรียกได้)
function SoundBank.GetChantPreset(index: number?, _isGhostPresent: boolean?): any
	local list = SoundBank.MonkChantsNormal
	local idx = ((index or 1) - 1) % #list + 1
	return list[idx], idx
end
-- ---------------------------------------------------------------- 4. ฟังก์ชันสร้างและปรับแต่ง Sound (รองรับลากวางใน ReplicatedStorage.UploadedSounds อัตโนมัติ!)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ตารางเทียบชื่อคีย์ในโค้ด -> ชื่อไฟล์ .wav ตอนลากเข้า Asset Manager ของ Roblox Studio
SoundBank.KeyToFileName = {
	PumpCrankLoop = "sfx_pump_crank_loop",
	FuelGlugLoop = "sfx_fuel_glug_loop",
	ShutterCloseSlam = "sfx_shutter_close_slam",
	ShutterOpenPull = "sfx_shutter_open_pull",
	CoinTinDrop1 = "sfx_coin_tin_drop_1",
	CoinTinDrop2 = "sfx_coin_tin_drop_2",
	IncenseExtinguish = "sfx_incense_extinguish",
	MotoApproachIdle = "sfx_moto_approach_idle",
	PickupDieselIdle = "sfx_pickup_diesel_idle",
	BreathNeckLeft = "haunt_breath_neck_left",
	BreathNeckRight = "haunt_breath_neck_right",
	BreathBehindSlow = "haunt_breath_behind_slow",
	WalkDirtCircle = "haunt_walk_dirt_circle",
	WalkDirtHurry = "haunt_walk_dirt_hurry",
	WalkShopWood1 = "haunt_walk_shop_wood_1",
	WalkShopWood2 = "haunt_walk_shop_wood_2",
	RoofTinSteps = "haunt_roof_tin_steps",
	ClimbTree1 = "haunt_climb_tree_1",
	ClimbTree2 = "haunt_climb_tree_2",
	LukThung1 = "radio_lukthung_1_lamnam_thung_mued",
	LukThung2 = "radio_lukthung_2_khlui_sao_tai_sai",
	LukThung3 = "radio_lukthung_3_winyan_rak_nak_leng",
	LukThung4 = "radio_lukthung_4_klom_khuen_duean_dap",
	LukThung5 = "radio_lukthung_5_am_detuned_ghost",
	Chant1_Kusala_Normal = "chant_thai_1_kusala_normal",
	Chant2_Anicca_Normal = "chant_thai_2_anicca_normal",
	Chant3_PhraMalai_Normal = "chant_thai_3_phra_malai_normal",
	Chant4_NamoTassa_Normal = "chant_thai_4_namo_tassa_normal",
	Chant4_NamoTassa = "chant_thai_4_namo_tassa",
	Chant1_Kusala_Scared = "chant_thai_1_kusala_scared",
	Chant2_Anicca_Scared = "chant_thai_2_anicca_scared",
	Chant3_PhraMalai_Scared = "chant_thai_3_phra_malai_scared",
	Chant4_NamoTassa_Scared = "chant_thai_4_namo_tassa_scared",
	RacerMotoRevCut = "sfx_racer_moto_rev_cut",
	RacerWheeliePass = "sfx_racer_wheelie_pass",
	DanceMusic1_SaiYor = "music_thai_dance_1_sai_yor",
	DanceMusic2_MorlamEDM = "music_thai_dance_2_morlam_edm",
	ParadeMusic1_RotHae = "music_parade_1_rothe_isan",
	ParadeMusic2_KlongYao = "music_parade_2_klongyao_brass",
}

-- ค้นหา SoundId จากโฟลเดอร์ UploadedSounds ใน ReplicatedStorage หรือ SoundService (เผื่อผู้ใช้ลากวางจาก Asset Manager ลงมาเลยโดยไม่ต้องก๊อปเลข ID)
local function sanitizeUploadedFolder(root: Instance?)
	if not root then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") and d.IsPlaying then
			d:Stop()
			d.Playing = false
		end
	end
end
sanitizeUploadedFolder(ReplicatedStorage:FindFirstChild("UploadedSounds"))
sanitizeUploadedFolder(SoundService:FindFirstChild("UploadedSounds"))

local function findInUploadedFolder(nameOrKey: string?): string?
	if not nameOrKey or nameOrKey == "" then
		return nil
	end
	local fileAlias = SoundBank.KeyToFileName[nameOrKey]
	for _, root in ipairs({ ReplicatedStorage:FindFirstChild("UploadedSounds"), SoundService:FindFirstChild("UploadedSounds") }) do
		if root then
			local inst = root:FindFirstChild(nameOrKey, true) or (if fileAlias then root:FindFirstChild(fileAlias, true) else nil)
			if inst and inst:IsA("Sound") and inst.SoundId ~= "" then
				if inst.IsPlaying then
					inst:Stop()
				end
				return inst.SoundId
			end
		end
	end
	return nil
end

function SoundBank.ResolveId(preset: any): (string, boolean)
	if preset.forcePreset then
		return preset.id, false
	end
	if preset.customKey then
		local cid = SoundBank.CustomUploadedIds[preset.customKey]
		if type(cid) == "string" and cid ~= "" then
			return cid, true
		end
		local fromFolder = findInUploadedFolder(preset.customKey)
		if fromFolder then
			return fromFolder, true
		end
	end
	if preset.fallbackCustomKey then
		local fid = SoundBank.CustomUploadedIds[preset.fallbackCustomKey]
		if type(fid) == "string" and fid ~= "" then
			return fid, true
		end
		local fromFolder = findInUploadedFolder(preset.fallbackCustomKey)
		if fromFolder then
			return fromFolder, true
		end
	end
	return preset.id, false
end

function SoundBank.ApplyWarmEffects(snd: Sound, preset: any)
	-- ลบเอฟเฟกต์เก่าทั้งหมดก่อน (ไม่ใช้ PitchShift และไม่ใส่ Reverb ค้างยาว เพื่อไม่ให้เสียงยืด/ยาน)
	for _, ch in ipairs(snd:GetChildren()) do
		if ch:IsA("SoundEffect") then
			ch:Destroy()
		end
	end
	if preset.noEffects then
		return
	end
	-- Equalizer ตัดเฉพาะปลายแหลมจัดเบาๆ ให้เสียงคมชัดเป็นธรรมชาติ ไม่ยืด ไม่บี้ และไม่แสบหู
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "WarmEQ"
	eq.LowGain = math.clamp(preset.low or 0, -6, 4)
	eq.MidGain = math.clamp(preset.mid or 0, -4, 4)
	eq.HighGain = math.clamp(preset.high or -8, -10, -4)
	eq.Parent = snd
end

function SoundBank.CreateSound(presetName: string, parent: Instance, maxDist: number?): Sound?
	local preset = SoundBank.Presets[presetName]
	if not preset then
		warn("[SoundBank] ไม่พบ Preset:", presetName)
		return nil
	end
	local snd = Instance.new("Sound")
	snd.Name = presetName
	snd.SoundId = SoundBank.ResolveId(preset)
	snd.Volume = preset.volume
	snd.PlaybackSpeed = preset.speed or 1.0
	snd.Looped = preset.looped == true
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = 6
	snd.RollOffMaxDistance = maxDist or 65
	SoundBank.ApplyWarmEffects(snd, preset)
	snd.Parent = parent
	return snd
end

-- เล่นเสียง 1 ครั้งแล้วทำความสะอาดตัวเอง (หรือใช้ตัวเดิมใน parent)
function SoundBank.PlayOneShot(presetName: string, parent: Instance, maxDist: number?, durationLimit: number?): Sound?
	local preset = SoundBank.Presets[presetName]
	if not preset then
		return nil
	end
	local snd = SoundBank.CreateSound(presetName, parent, maxDist)
	if not snd then
		return nil
	end
	snd:Play()
	local life = durationLimit or 6
	task.delay(life, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.35), { Volume = 0 }):Play()
			task.wait(0.4)
			snd:Stop()
			snd:Destroy()
		end
	end)
	return snd
end

-- เล่นเสียงที่ตำแหน่ง 3D ในฉาก (สร้าง Attachment ชั่วคราวบน Terrain)
function SoundBank.PlayAtPosition(presetName: string, worldPos: Vector3, maxDist: number?, durationLimit: number?): Sound?
	local att = Instance.new("Attachment")
	att.Name = "SfxEmitter_" .. presetName
	att.WorldPosition = worldPos
	att.Parent = Workspace.Terrain
	local snd = SoundBank.CreateSound(presetName, att, maxDist or 60)
	if snd then
		snd:Play()
	end
	local life = durationLimit or 6
	task.delay(life, function()
		if snd and snd.Parent then
			TweenService:Create(snd, TweenInfo.new(0.4), { Volume = 0 }):Play()
			task.wait(0.45)
		end
		if att and att.Parent then
			att:Destroy()
		end
	end)
	return snd
end

-- ---------------------------------------------------------------- 5. ระบบตรวจจับเพศตัวละครผู้เล่น (ชาย "M" / หญิง "F") & โทนเสียงพูดตามตัวละคร
local Players = game:GetService("Players")

-- โทนเสียงเฉพาะของแต่ละตัวละคร (uploadedSpeed ชดเชยสปีดให้ไฟล์ที่อัปโหลดไปแล้วพูดกระชับ ไม่ยืด โดยไม่ต้องอัปโหลดไฟล์ใหม่!)
SoundBank.VoiceProfiles = {
	Sommai   = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.08, low = 3, mid = 2, high = -6 },
	Boonmee  = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.04, low = 2, mid = 2, high = -6 },
	Ton      = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.00, low = 1, mid = 2, high = -6 },
	Daeng    = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.03, low = 2, mid = 2, high = -6 },
	Racer    = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.00, low = 1, mid = 3, high = -6 },
	Player_M = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.03, low = 2, mid = 2, high = -6 },
	Ghost_M  = { gender = "M", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.14, low = 3, mid = 2, high = -8 },

	Chaem    = { gender = "F", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.06, low = 0, mid = 2, high = -6 },
	Prik     = { gender = "F", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.12, low = 1, mid = 2, high = -6 },
	Noi      = { gender = "F", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.03, low = 0, mid = 2, high = -6 },
	Coyote   = { gender = "F", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.00, low = 0, mid = 3, high = -6 },
	Player_F = { gender = "F", baseId = "rbxassetid://9114120102", speed = 1.0, uploadedSpeed = 1.03, low = 0, mid = 2, high = -6 },
	Ghost_F  = { gender = "F", baseId = "rbxassetid://75664285683608", speed = 1.0, uploadedSpeed = 1.12, low = 1, mid = 2, high = -8 },
}

-- ตรวจจับเพศของตัวละครผู้เล่นอัตโนมัติ (หรือดึงจาก Attribute VoiceGender ถ้าผู้เล่นตั้งค่าไว้)
function SoundBank.DetectPlayerGender(player: Player?): string
	local plr = player
	if not plr then
		local ok, localPlr = pcall(function()
			return Players.LocalPlayer
		end)
		if ok then
			plr = localPlr
		end
	end
	if not plr then
		return "M"
	end

	-- 1. ถ้าตั้งค่า Attribute "VoiceGender" ไว้ ("M" หรือ "F") ให้ใช้ค่านั้นก่อน
	local attr = plr:GetAttribute("VoiceGender")
	if attr == "F" or attr == "Female" or attr == "หญิง" then
		return "F"
	elseif attr == "M" or attr == "Male" or attr == "ชาย" then
		return "M"
	end

	-- 2. ตรวจจากรูปร่าง/ทรงผม/เสื้อผ้าของ Character ปัจจุบัน
	local char = plr.Character
	if char then
		local cached = char:GetAttribute("DetectedVoiceGender")
		if cached == "M" or cached == "F" then
			return cached
		end
		local femaleHints = {
			"girl", "woman", "female", "ponytail", "pigtail", "bun", "longhair",
			"twin", "skirt", "dress", "bow", "ribbon", "blouse", "braid", "bangs", "princess", "cute",
		}
		local scoreF = 0
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("Accessory") or inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("CharacterMesh") or inst:IsA("MeshPart") then
				local lowName = string.lower(inst.Name)
				for _, kw in ipairs(femaleHints) do
					if string.find(lowName, kw, 1, true) then
						scoreF += 1
						break
					end
				end
			end
		end
		local gender = if scoreF >= 1 then "F" else "M"
		char:SetAttribute("DetectedVoiceGender", gender)
		return gender
	end

	return "M"
end

-- เล่นเสียงอุทานสั้นๆ / เสียงหนาวสั่น / เสียงหวาดกลัวผวา ตามเพศ ("M" หรือ "F")
function SoundBank.PlayReaction(category: string, gender: string?, parent: Instance?): Sound?
	local g = if gender == "F" then "F" else "M"
	local targetParent = parent or SoundService

	local map = {
		Startle  = if g == "F" then { "React_Startle_Huh_F1", "React_Startle_Huh_F2" } else { "React_Startle_Huh_M1", "React_Startle_Huh_M2" },
		Question = if g == "F" then { "React_Question_Haa_F1" } else { "React_Question_Haa_M1" },
		Cold     = if g == "F" then { "React_Cold_Shiver_F1" } else { "React_Cold_Shiver_M1" },
		Fear     = if g == "F" then { "React_Fear_Panic_F1" } else { "React_Fear_Panic_M1" },
		Tremble  = if g == "F" then { "React_Fear_Tremble_F" } else { "React_Fear_Tremble_M" },
	}
	local list = map[category] or map.Startle
	local presetName = list[math.random(#list)]
	if VOICE_LOG then
		print("VOICE|React_" .. category .. "|" .. presetName .. "|react")
	end
	local preset = SoundBank.Presets[presetName]
	if not preset then
		return nil
	end
	local _, isCustom = SoundBank.ResolveId(preset)
	if not isCustom then
		return nil -- เล่นเฉพาะเมื่อนำไฟล์ .wav เข้า UploadedSounds แล้ว เพื่อไม่ให้เสียงสำรองยืดกระตุก
	end
	return SoundBank.PlayOneShot(presetName, targetParent, 45, 3.0)
end

-- แปลงชื่อตัวละครใน LanguageModule / CoreLoop เป็นชื่อ VoiceProfile
local function resolveVoiceProfileName(speakerInfo: any, dialogueKey: string): string
	if type(speakerInfo) == "table" then
		if speakerInfo.player and typeof(speakerInfo.player) == "Instance" and speakerInfo.player:IsA("Player") then
			local g = speakerInfo.gender or SoundBank.DetectPlayerGender(speakerInfo.player)
			return if g == "F" then "Player_F" else "Player_M"
		end
		local voiceGender = speakerInfo.voice or speakerInfo.gender
		if speakerInfo.ghost then
			return if voiceGender == "F" then "Ghost_F" else "Ghost_M"
		end
		local rawName = tostring(speakerInfo.profile or speakerInfo.name or "")
		if string.find(rawName, "สมหมาย") or string.find(rawName, "Sommai") then
			return "Sommai"
		elseif string.find(rawName, "แช่ม") or string.find(rawName, "Chaem") then
			return "Chaem"
		elseif string.find(rawName, "ต้น") or string.find(rawName, "Ton") then
			return "Ton"
		elseif string.find(rawName, "บุญมี") or string.find(rawName, "Boonmee") then
			return "Boonmee"
		elseif string.find(rawName, "ปริก") or string.find(rawName, "Prik") then
			return "Prik"
		elseif string.find(rawName, "แดง") or string.find(rawName, "Daeng") then
			return "Daeng"
		elseif string.find(rawName, "น้อย") or string.find(rawName, "Noi") then
			return "Noi"
		end
		if voiceGender == "F" then
			return "Chaem"
		elseif voiceGender == "M" then
			return "Boonmee"
		end
	end

	-- เดาจากชื่อ Dialogue Key ถ้าไม่ได้ส่งตาราง speakerInfo มา
	if string.find(dialogueKey, "Uncle") then return "Sommai" end
	if string.find(dialogueKey, "Aunt") then return "Chaem" end
	if string.find(dialogueKey, "Student") then return "Ton" end
	if string.find(dialogueKey, "Farmer") then return "Boonmee" end
	if string.find(dialogueKey, "Coyote") then return "Coyote" end
	if string.find(dialogueKey, "Racer") or string.find(dialogueKey, "Teen") then return "Racer" end
	if string.find(dialogueKey, "Anomaly_") or string.find(dialogueKey, "Ghost") then
		return "Ghost_F"
	end
	if string.sub(dialogueKey, 1, 6) == "Player" then
		local g = SoundBank.DetectPlayerGender(nil)
		return if g == "F" then "Player_F" else "Player_M"
	end
	return "Boonmee"
end

-- คิวเสียงพากย์: เล่นทีละประโยค ประโยคใหม่รอให้ประโยคก่อนพูดจบก่อน (ไฟล์พากย์คนจริงยาวกว่าเวลาซับ เลยเคยพูดทับกัน)
local VOICE_QUEUE_MAX_WAIT = 10 -- รอคิวนานเกินนี้ (วินาที) ทิ้งประโยคนั้นไปเลย ไม่ให้เสียงช้ากว่าเหตุการณ์มากเกิน
local VOICE_GAP = 0.15 -- เว้นจังหวะหายใจระหว่างประโยค
local voiceQueue: { { play: () -> Sound?, maxLen: number, t: number } } = {}
local voiceQueueRunning = false
local playVoiceFile -- ประกาศไว้ก่อน ตัวจริงอยู่ท้ายไฟล์

local function runVoiceQueue()
	voiceQueueRunning = true
	while #voiceQueue > 0 do
		local item = table.remove(voiceQueue, 1)
		if os.clock() - item.t > VOICE_QUEUE_MAX_WAIT then
			if VOICE_LOG then
				print("VOICE_DROP|รอคิวนานเกินเลยไม่ได้เล่น")
			end
		else
			local snd = item.play()
			if snd then
				local t0 = os.clock()
				-- รอจนไฟล์โหลดและเล่นจบ (หรือถูกลบ / ครบเวลาสูงสุดของไฟล์นั้น / โหลดไม่ขึ้นใน 3 วิ เช่นไม่มีสิทธิ์ใช้ไฟล์)
				while
					snd.Parent
					and (snd.IsPlaying or (not snd.IsLoaded and os.clock() - t0 < 3))
					and os.clock() - t0 < item.maxLen
				do
					task.wait(0.05)
				end
				task.wait(VOICE_GAP)
			end
		end
	end
	voiceQueueRunning = false
end

local function enqueueVoice(play: () -> Sound?, maxLen: number)
	table.insert(voiceQueue, { play = play, maxLen = maxLen, t = os.clock() })
	if not voiceQueueRunning then
		task.spawn(runVoiceQueue)
	end
end

-- โหลดเสียงพากย์ทั้งหมดไว้ตั้งแต่เข้าเกม (ฝั่ง Client): เล่นได้ทันที ไม่ต้องรอดึงไฟล์ตอนลูกค้าพูด
-- ไฟล์ที่โหลดไม่ขึ้น (Roblox ยังไม่อนุมัติ / ไม่มีสิทธิ์) จำไว้แล้วข้าม ไม่ให้คิวเสียงค้างรอ และขึ้นใน Output ว่าไฟล์ไหน
local badVoiceIds: { [string]: boolean } = {}
function SoundBank.PreloadVoices()
	local folder = Instance.new("Folder")
	folder.Name = "VoicePreload"
	folder.Parent = SoundService
	local list = {}
	local keyOf: { [string]: string } = {}
	for key, id in pairs(SoundBank.DialogueUploadedIds) do
		local s = Instance.new("Sound")
		s.Name = key
		s.SoundId = id
		s.Parent = folder
		table.insert(list, s)
		keyOf[id] = key
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
					badVoiceIds[contentId] = true
					warn("[SoundBank] โหลดเสียงพากย์ไม่ขึ้น: " .. tostring(keyOf[contentId]) .. " " .. contentId)
				end
			end)
		end)
	end)
end

-- เล่นเสียงพากย์บทสนทนาให้ตรงกับคีย์ประโยค + ตำแหน่ง 3D ของผู้พูด:
--   - ถ้าเป็นเสียงของ Player: ดังที่ตัว Player เอง และให้ได้ยินเฉพาะเจ้าตัวเท่านั้น (คนอื่นไม่ได้ยินเสียงพากย์ของเรา)
--   - ถ้าเป็นเสียงของลูกค้า / คนหลบฝน / ขาจร: ดังแบบ 3D ที่ตัวลูกค้า (headPart) คนนั้นจริงๆ!
function SoundBank.PlayDialogueVoice(dialogueKey: string, speakerInfo: any, headPart: BasePart?)
	if type(dialogueKey) ~= "string" or dialogueKey == "" then
		return
	end
	local localPlr = Players.LocalPlayer
	local isPlayerLine = (type(speakerInfo) == "table" and speakerInfo.player ~= nil)
		or string.sub(dialogueKey, 1, 6) == "Player"

	local targetParent: Instance? = nil
	if isPlayerLine then
		-- ผู้เล่นแต่ละคนได้ยินเฉพาะเสียงพากย์ของตัวเองเท่านั้น!
		if type(speakerInfo) == "table" then
			if speakerInfo.userId and localPlr and speakerInfo.userId ~= localPlr.UserId then
				return
			end
			if speakerInfo.player and localPlr and speakerInfo.player ~= localPlr.DisplayName and speakerInfo.player ~= localPlr.Name then
				return
			end
		end
		local myChar = localPlr and localPlr.Character
		targetParent = (myChar and myChar:FindFirstChild("Head")) or SoundService
	else
		-- เสียงลูกค้า / คนหลบฝน / ขาจร: ต้องดังที่ตัวลูกค้าคนนั้น (headPart)
		targetParent = if headPart and headPart.Parent then headPart else nil
		if not targetParent then
			-- ถ้าเป็นเสียงกระซิบไร้ตัวตนรอบตัวผู้เล่น (เช่น Passenger_Whisper / Pray_Summon) ให้ดังที่หัวผู้เล่นเบาๆ
			local myChar = localPlr and localPlr.Character
			targetParent = (myChar and myChar:FindFirstChild("Head")) or SoundService
		end
	end

	local profName = resolveVoiceProfileName(speakerInfo, dialogueKey)
	local prof = SoundBank.VoiceProfiles[profName] or SoundBank.VoiceProfiles.Boonmee
	local gender = if isPlayerLine then SoundBank.DetectPlayerGender(localPlr) else (prof.gender or "M")
	local genderKey = dialogueKey .. "_" .. gender

	-- 1. เช็กว่ามีไฟล์เสียงพากย์เฉพาะประโยคนี้ใน DialogueUploadedIds หรือในโฟลเดอร์ ReplicatedStorage.UploadedSounds หรือยัง
	-- เสียงพากย์คนจริง (ใส่ id ใน DialogueUploadedIds) ดังกว่า / ความเร็วเดิม / เล่นจนจบไฟล์ ต่างจากไฟล์ TTS เดิมใน UploadedSounds
	local dubbedId = SoundBank.DialogueUploadedIds[genderKey] or SoundBank.DialogueUploadedIds[dialogueKey]
	if dubbedId and badVoiceIds[dubbedId] then
		dubbedId = nil
	end
	local uploadedId = dubbedId
		or findInUploadedFolder(genderKey)
		or findInUploadedFolder(dialogueKey)
	if VOICE_LOG then
		-- VOICE|คีย์ที่เกมเรียก|ไฟล์ที่ต้องพากย์ (คีย์_M/_F)|dub = มีเสียงพากย์จริงแล้ว / tts = เสียง AI เดิม / none = ไม่มีเสียง
		print("VOICE|" .. dialogueKey .. "|" .. genderKey .. "|" .. (if dubbedId then "dub" elseif uploadedId then "tts" else "none"))
	end
	if type(uploadedId) == "string" and uploadedId ~= "" and targetParent then
		-- เข้าคิว: ประโยคก่อนหน้ายังพูดไม่จบ ให้รอจบก่อนค่อยพูด (ไม่ให้เสียงทับกัน)
		enqueueVoice(function()
			return playVoiceFile(genderKey, uploadedId, dubbedId ~= nil, speakerInfo, prof, targetParent)
		end, if dubbedId then 20 else 6.5)
		return
	end

	-- 2. ถ้าเป็นประโยคตกใจ/สงสัย/หนาวฝน/โดนไล่ ให้เปล่งเสียงอุทาน ("เฮ้ย!", "ห๊า?!", "บรื๋อ...") ที่ตัวผู้พูดคนนั้น
	if targetParent then
		if string.find(dialogueKey, "Wrong_") or string.find(dialogueKey, "Rejected") or string.find(dialogueKey, "Impatient_3") then
			SoundBank.PlayReaction("Startle", gender, targetParent)
		elseif string.find(dialogueKey, "Alone_") or string.find(dialogueKey, "WhoTalking") or string.find(dialogueKey, "ExpensiveNo") then
			SoundBank.PlayReaction("Question", gender, targetParent)
		elseif string.find(dialogueKey, "RainTalk_1") then
			SoundBank.PlayReaction("Cold", gender, targetParent)
		end
	end
end

-- สร้างและเล่นไฟล์เสียงพากย์ 1 ประโยค (เรียกจากคิวเสียง)
function playVoiceFile(genderKey: string, uploadedId: string, isDubbed: boolean, speakerInfo: any, prof: any, targetParent: Instance): Sound?
	if targetParent ~= SoundService and not targetParent:IsDescendantOf(workspace) then
		return nil -- คนพูดหายไปจากฉากระหว่างรอคิวแล้ว
	end
	local snd = Instance.new("Sound")
	snd.Name = "Dialogue_" .. genderKey
	snd.SoundId = uploadedId
	-- เสียงกระซิบไร้ตัวตน (ศาลไม่คุ้มครอง / สวดเรียกผี) เบาเหลือ 30% ของเสียงพากย์ปกติ
	local whisper = type(speakerInfo) == "table" and speakerInfo.ghost == "WhisperSpeaker"
	local baseVolume = if isDubbed then SoundBank.DubbedVoiceVolume else 0.58
	snd.Volume = if whisper then baseVolume * 0.3 else baseVolume
	snd.PlaybackSpeed = if isDubbed then 1 else (prof.uploadedSpeed or 1.04) -- ชดเชยสปีดให้ไฟล์ที่อัปโหลดไว้แล้วพูดกระชับ ไม่ยืด โดยไม่ต้องอัปโหลดใหม่!
	snd.RollOffMode = Enum.RollOffMode.InverseTapered
	snd.RollOffMinDistance = if isDubbed then 16 else 7 -- กล้องคัตซีนอยู่ห่างหัวคนพูด ~10-15 studs
	snd.RollOffMaxDistance = 60
	SoundBank.ApplyWarmEffects(snd, { low = prof.low or 2, mid = prof.mid or 2, high = prof.high or -6 })
	snd.Parent = targetParent
	snd:Play()
	if isDubbed then
		snd.Ended:Once(function()
			snd:Destroy()
		end)
	end
	task.delay(if isDubbed then 20 else 6.5, function()
		if snd and snd.Parent then
			snd:Destroy()
		end
	end)
	return snd
end

return SoundBank
