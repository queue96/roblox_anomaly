-- SoundBank.luau
-- คลังเสียงและระบบแต่งเสียงนุ่มลึก ไม่แสบหู (Warm Low-Pass / Soft EQ) สำหรับเกม "ปั๊มหลอดท้ายทุ่ง"
-- รองรับทั้ง:
--   1. เสียงพร้อมใช้ทันทีจาก Roblox Creator Store (แต่งด้วย EqualizerSoundEffect + PitchShift + Reverb)
--   2. เสียงจากไฟล์ .wav ที่สังเคราะห์ด้วย tools/audio/generate_sounds.py (ถ้าคุณอัปโหลดไฟล์ใน assets/sounds/ ขึ้น Roblox แล้วเอา rbxassetid:// มาใส่ใน CUSTOM_UPLOADED_IDS ระบบจะสลับไปใช้ไฟล์ที่คุณอัปโหลดทันที!)

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
	Chant1_Kusala_Normal = "",      -- assets/sounds/chant_thai_1_kusala_normal.wav (กุสลา ธัมมา - สวดปกติ)
	Chant2_Anicca_Normal = "",      -- assets/sounds/chant_thai_2_anicca_normal.wav (อนิจจา วะตะ สังขารา - สวดปกติ)
	Chant3_PhraMalai_Normal = "",   -- assets/sounds/chant_thai_3_phra_malai_normal.wav (สัพเพ สัตตา แผ่เมตตา - สวดปกติ)
	Chant4_NamoTassa_Normal = "",   -- assets/sounds/chant_thai_4_namo_tassa_normal.wav (นะโม ตัสสะ 3 จบ - สวดปกติ)

	Chant1_Kusala_Scared = "",      -- assets/sounds/chant_thai_1_kusala_scared.wav (กุสลา ธัมมา - สวดเร็วกลัวผี!)
	Chant2_Anicca_Scared = "",      -- assets/sounds/chant_thai_2_anicca_scared.wav (อนิจจา วะตะ สังขารา - สวดเร็วกลัวผี!)
	Chant3_PhraMalai_Scared = "",   -- assets/sounds/chant_thai_3_phra_malai_scared.wav (สัพเพ สัตตา - สวดเร็วกลัวผี!)
	Chant4_NamoTassa_Scared = "",   -- assets/sounds/chant_thai_4_namo_tassa_scared.wav (นะโม ตัสสะ 3 จบ - สวดเร็วกลัวผี!)

	-- ชื่อเดิม (Alias ชี้ไปที่ชุดสวดเร็วกลัวผี)
	Chant1_Kusala = "",
	Chant2_Anicca = "",
	Chant3_PhraMalai = "",
	Chant4_NamoTassa = "",

	-- 5) เสียงขาจรบนถนน: เด็กแว้น + เพลงแดนซ์รถเครื่องเสียง + เพลงรถแห่งานบวช
	RacerMotoRevCut = "",       -- assets/sounds/sfx_racer_moto_rev_cut.wav
	RacerWheeliePass = "",      -- assets/sounds/sfx_racer_wheelie_pass.wav
	DanceMusic1_SaiYor = "",    -- assets/sounds/music_thai_dance_1_sai_yor.wav
	DanceMusic2_MorlamEDM = "", -- assets/sounds/music_thai_dance_2_morlam_edm.wav
	ParadeMusic1_RotHae = "",   -- assets/sounds/music_parade_1_rothe_isan.wav
	ParadeMusic2_KlongYao = "", -- assets/sounds/music_parade_2_klongyao_brass.wav

	-- 6) เสียงอุทานสั้นๆ / เสียงหนาวสั่น / เสียงหวาดกลัวผวา (assets/sounds/reactions/React_*.wav)
	React_Startle_Huh_M1 = "",  -- เฮ้ย! (ชาย)
	React_Startle_Huh_M2 = "",  -- เฮ้ย! อีหยังวะ! (ชาย)
	React_Startle_Huh_F1 = "",  -- เฮ้ย! (หญิง)
	React_Startle_Huh_F2 = "",  -- ว้าย! ตกใจเบิดเลย! (หญิง)
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
SoundBank.DialogueUploadedIds = {
	-- ตัวอย่าง: Greet_Uncle = "rbxassetid://...", AskPrice_M = "rbxassetid://...", PlayerHello_F = "rbxassetid://..."
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
		id = "rbxassetid://9113542694", -- เสียงกระแทกแผ่นสังกะสี/ไม้ทุ้มๆ
		customKey = "ShutterCloseSlam",
		volume = 0.55,
		speed = 1.0,
		low = 6,
		mid = -3,
		high = -22, -- ทุ้มหนักแน่น ไม่แหลมบาดหู
		reverbWet = -8,
		reverbDecay = 1.8,
	},
	ShutterOpenPull = {
		id = "rbxassetid://9117159106",
		customKey = "ShutterOpenPull",
		volume = 0.38,
		speed = 1.0,
		low = 4,
		mid = -2,
		high = -20,
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
}

-- ---------------------------------------------------------------- 3. สถานีเพลงวิทยุลูกทุ่งเหงาๆ หลอนๆ 5 คลื่น (Vintage AM Luk Thung Stations)
-- สลับคลื่นได้ หรือสุ่มเปลี่ยนเพลงตอนเที่ยงคืน มีทั้งขลุ่ย/ดนตรีเก่า/ลูกคอเอื้อนช้าๆ แต่ง EQ วิทยุทรานซิสเตอร์ AM นุ่มๆ
SoundBank.RadioStations = {
	{
		name = "LukThung_1_LamnamThungMued",
		titleTH = "คลื่น AM 1: ลำนำทุ่งมืด (ลูกทุ่งเก่าเหงาๆ)",
		id = "rbxassetid://108772936146894",
		customKey = "LukThung1",
		volume = 0.32,
		speed = 1.0, -- ช้าลงนิดๆ ให้ได้อารมณ์แผ่นเสียง/เทปเก่าเหงาๆ
		pitchOctave = 0.96,
		low = -8,
		mid = 4,
		high = -20, -- ลำโพงวิทยุ AM อุ่นๆ ไม่บาดหู
		reverbWet = -6,
		reverbDecay = 2.8,
	},
	{
		name = "LukThung_2_KhluiSaoTaiSai",
		titleTH = "คลื่น AM 2: ขลุ่ยเศร้าใต้ต้นไทร (โหยหวนช้าๆ)",
		id = "rbxassetid://108772936146894",
		customKey = "LukThung2",
		volume = 0.30,
		speed = 1.0, -- โหยหวนช้าๆ เหมือนเพลงลูกทุ่งยุคแผ่นครั่ง
		pitchOctave = 0.90,
		low = -6,
		mid = 5,
		high = -22,
		reverbWet = -4,
		reverbDecay = 3.4,
	},
	{
		name = "LukThung_3_WinyanRakThungNa",
		titleTH = "คลื่น AM 3: วิญญาณรักท้ายทุ่ง (ลูกคอเทปยาน)",
		id = "rbxassetid://9040293936",
		customKey = "LukThung3",
		volume = 0.24,
		speed = 1.0, -- ดึงจังหวะลงครึ่งหนึ่ง + กดคีย์ต่ำ กลายเป็นเพลงจังหวะลูกทุ่งช้าๆ หลอนๆ
		pitchOctave = 0.78,
		low = -4,
		mid = 3,
		high = -24,
		reverbWet = -5,
		reverbDecay = 3.2,
	},
	{
		name = "LukThung_4_KlomKhuenDueanDap",
		titleTH = "คลื่น AM 4: กล่อมคืนเดือนดับ (ดนตรีไทยโบราณวังเวง)",
		id = "rbxassetid://9043078311",
		customKey = "LukThung4",
		volume = 0.25,
		speed = 1.0,
		pitchOctave = 0.82,
		low = -4,
		mid = 4,
		high = -22,
		reverbWet = -3,
		reverbDecay = 3.8,
	},
	{
		name = "LukThung_5_AMDetunedGhost",
		titleTH = "คลื่น AM 5: คลื่นแทรกวิญญาณลูกทุ่ง (คลื่นเพี้ยนกลางดึก)",
		id = "rbxassetid://108772936146894",
		customKey = "LukThung5",
		volume = 0.28,
		speed = 1.0,
		pitchOctave = 0.85,
		low = -10,
		mid = 5,
		high = -24,
		reverbWet = -2,
		reverbDecay = 4.0,
	},
}

-- ---------------------------------------------------------------- 3.5 บทสวดมนต์สำเนียงไทยบ้านอีสาน 4 บท (โทนเสียงเดียวกัน แยก 2 โหมด: ปกติ vs เจอผีสวดเร็ว!)
-- 1) โหมดสวดปกติ (NormalChants): สวดเนิบๆ สำรวม สบายใจ ตอนยังไม่มีผี
SoundBank.MonkChantsNormal = {
	{
		name = "Chant1_Kusala_Normal",
		titleTH = "บทที่ 1 (สวดปกติ): กุสลา ธัมมา",
		id = "rbxassetid://1845929179",
		customKey = "Chant1_Kusala_Normal",
		volume = 0.42,
		speed = 1.14, -- ชดเชยสปีดให้ไฟล์ที่อัปโหลดไปแล้วพูดกระชับเป็นธรรมชาติ ไม่ยืด โดยไม่ต้องอัปโหลดใหม่
		pitchOctave = 0.96,
		low = 0,
		mid = 3,
		high = -8,
	},
	{
		name = "Chant2_Anicca_Normal",
		titleTH = "บทที่ 2 (สวดปกติ): อนิจจา วะตะ สังขารา",
		id = "rbxassetid://1845929179",
		customKey = "Chant2_Anicca_Normal",
		volume = 0.42,
		speed = 1.14,
		pitchOctave = 0.94,
		low = 1,
		mid = 3,
		high = -8,
	},
	{
		name = "Chant3_PhraMalai_Normal",
		titleTH = "บทที่ 3 (สวดปกติ): สัพเพ สัตตา แผ่เมตตา",
		id = "rbxassetid://1845929179",
		customKey = "Chant3_PhraMalai_Normal",
		volume = 0.40,
		speed = 1.14,
		pitchOctave = 0.95,
		low = -2,
		mid = 3,
		high = -8,
	},
	{
		name = "Chant4_NamoTassa_Normal",
		titleTH = "บทที่ 4 (สวดปกติ): นะโม ตัสสะ 3 จบ",
		id = "rbxassetid://1845929179",
		customKey = "Chant4_NamoTassa_Normal",
		volume = 0.44,
		speed = 1.14,
		pitchOctave = 0.96,
		low = 0,
		mid = 3,
		high = -8,
	},
}

-- 2) โหมดสวดรัวเร็วตอนเจอผี! (MonkChantsScared / MonkChants): โทนเสียงคนเดิมแต่สวดรัวเร็ว ลนลาน กลัวผี!
SoundBank.MonkChantsScared = {
	{
		name = "Chant1_Kusala_Scared",
		titleTH = "บทที่ 1 (เจอผี-สวดเร็ว!): กุสลา ธัมมา",
		id = "rbxassetid://1845929179",
		customKey = "Chant1_Kusala_Scared",
		fallbackCustomKey = "Chant1_Kusala",
		volume = 0.54,
		speed = 1.0, -- เร่งสปีดรัวเร็วแบบคนกลัวผีลนลาน!
		pitchOctave = 0.78, -- ชดเชยคีย์ให้ยังเป็นโทนเสียงคนเดิม ไม่แหลมเป็นเสียงการ์ตูน
		low = 0,
		mid = 4,
		high = -18,
		reverbWet = -5,
		reverbDecay = 2.2,
	},
	{
		name = "Chant2_Anicca_Scared",
		titleTH = "บทที่ 2 (เจอผี-สวดเร็ว!): อนิจจา วะตะ สังขารา",
		id = "rbxassetid://1845929179",
		customKey = "Chant2_Anicca_Scared",
		fallbackCustomKey = "Chant2_Anicca",
		volume = 0.55,
		speed = 1.0,
		pitchOctave = 0.79,
		low = 1,
		mid = 4,
		high = -18,
		reverbWet = -4,
		reverbDecay = 2.4,
	},
	{
		name = "Chant3_PhraMalai_Scared",
		titleTH = "บทที่ 3 (เจอผี-สวดเร็ว!): สัพเพ สัตตา แผ่เมตตา",
		id = "rbxassetid://1845929179",
		customKey = "Chant3_PhraMalai_Scared",
		fallbackCustomKey = "Chant3_PhraMalai",
		volume = 0.52,
		speed = 1.0,
		pitchOctave = 0.77,
		low = -8,
		mid = 5,
		high = -20,
		reverbWet = -5,
		reverbDecay = 2.2,
	},
	{
		name = "Chant4_NamoTassa_Scared",
		titleTH = "บทที่ 4 (เจอผี-สวดเร็ว!): นะโม ตัสสะ 3 จบ",
		id = "rbxassetid://1845929179",
		customKey = "Chant4_NamoTassa_Scared",
		fallbackCustomKey = "Chant4_NamoTassa",
		volume = 0.56,
		speed = 1.0,
		pitchOctave = 0.76,
		low = 0,
		mid = 4,
		high = -18,
		reverbWet = -4,
		reverbDecay = 2.2,
	},
}
SoundBank.MonkChants = SoundBank.MonkChantsScared

-- คืนค่า Preset บทสวดตามหมายเลขบท (1..4) และสถานะว่าเจอผีหรือไม่ (isGhostPresent)
function SoundBank.GetChantPreset(index: number?, isGhostPresent: boolean?): any
	local list = if isGhostPresent then SoundBank.MonkChantsScared else SoundBank.MonkChantsNormal
	local idx = ((index or math.random(#list)) - 1) % #list + 1
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
		or string.sub(dialogueKey, 1, 10) == "Pray_Reply"

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
	local uploadedId = SoundBank.DialogueUploadedIds[genderKey]
		or SoundBank.DialogueUploadedIds[dialogueKey]
		or findInUploadedFolder(genderKey)
		or findInUploadedFolder(dialogueKey)
	if type(uploadedId) == "string" and uploadedId ~= "" and targetParent then
		local snd = Instance.new("Sound")
		snd.Name = "Dialogue_" .. genderKey
		snd.SoundId = uploadedId
		snd.Volume = 0.58
		snd.PlaybackSpeed = prof.uploadedSpeed or 1.04 -- ชดเชยสปีดให้ไฟล์ที่อัปโหลดไว้แล้วพูดกระชับ ไม่ยืด โดยไม่ต้องอัปโหลดใหม่!
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = 7
		snd.RollOffMaxDistance = 60
		SoundBank.ApplyWarmEffects(snd, { low = prof.low or 2, mid = prof.mid or 2, high = prof.high or -6 })
		snd.Parent = targetParent
		snd:Play()
		task.delay(6.5, function()
			if snd and snd.Parent then
				snd:Destroy()
			end
		end)
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

return SoundBank
