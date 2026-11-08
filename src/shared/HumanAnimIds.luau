--!strict
-- AnimationIds of the human clips (built in Studio from assets/models/roblox/<name>/<name>_anims.json with
-- tools/studio/HumanAnimImport.luau, then Save to Roblox). One set per character: each has its own way of
-- moving (STYLE in assets/models/human_base/build_anims.py). A clip of one character works on all its body
-- types (thin / fat / pregnant).
--
-- Long pha sin / sarong outfits must walk and run with walk_skirt / run_skirt (legs go through the cloth with
-- the normal ones).
local function ids(t: { [string]: number }): { [string]: string }
	local out = {}
	for clip, id in pairs(t) do out[clip] = "rbxassetid://" .. tostring(id) end
	return out
end

local T = {
	human_base = ids({
		-- mocap 2026-11-09 (ท่าใหม่: ยืนสุ่ม HumanNPC.idleIdOf / ท่าประกอบคำพูด client/NpcGestures)
		idle_weight = 117760911754379,
		idle_look = 73628187306276,
		idle_bored = 72472183221259, -- อัปโหลดชื่อ human_base_idle_look ซ้ำ (เช็กจำนวน keyframe = 142 = idle_bored)
		talk = 135741745363515,
		talk_2 = 100010464929061,
		wave = 105900967964784,
		shrug = 124059724202550,
		nod_yes = 135709885284286,
		shake_no = 132468731029918,
		idle = 81806819302068, -- mocap 2026-11-08 (เดิม 103800868829848)
		walk = 107367797483289, -- mocap 2026-11-08 (เดิม 132822592476604)
		run = 129700657811557,
		walk_skirt = 137905220707032,
		run_skirt = 128117301146048,
		ghost_idle = 91516636427185,
		ghost_glide = 127456756304366,
		ghost_dance = 109976651673999,
		ramwong = 135519924599414,
		wan_rock = 93177209830968,
		wan_bounce = 105754280128665,
		wan_point = 106947707514064,
		wan_cool = 93412543260590,
		wan_hands_up = 120111047239636,
		wan_hip_shake = 103216869960969,
		wan_low_bounce = 89148599673738,
		-- ท่าซ้อน (ขยับแค่แขน/ตัวบน เล่นทับท่าเดิน/ยืน, Action priority)
		pray = 104921245691493,
		hold_umbrella = 83559580599354,
		hold_flashlight = 96741468634387,
		carry_gallon = 105063801308289,
		-- ผู้เล่น
		jump = 96706447598577,
		fall = 119644102585370,
		sit = 97016491508456,
		fuel_pump = 105824342481209,
		pump_air = 71805771595701,
		pull_rope = 76764261672932,
		pull_start = 103585535082880,
		-- คนขับ
		drive_car = 98256091674043, -- mocap 2026-11-08 (เดิม 129503151043569)
		ride_moto = 107566656956832, -- mocap 2026-11-08 (เดิม 132408927006595)
		drive_tuktuk = 129793929550062, -- mocap 2026-11-08 (เดิม 134908139865752)
		ride_bicycle = 135362256541891,
	}),
	human_female = ids({
		-- mocap 2026-11-09 ท่ายืนสุ่ม (HumanNPC.idleIdOf)
		idle_weight = 111656036638011,
		idle_look = 126299132578367,
		idle_bored = 137908275510582,
		ghost_dance = 73112051931779,
		ghost_glide = 130706698260780,
		ghost_idle = 113169882084394,
		idle = 80399356954671, -- mocap 2026-11-08 (เดิม 129369161172079)
		ramwong = 91118819618736,
		run = 140167830796828,
		run_skirt = 108147959293862,
		walk = 93040531354141, -- mocap 2026-11-08 (เดิม 103773582554712)
		walk_skirt = 92833643435640,
		wan_bounce = 107742251134980,
		wan_cool = 96401431887142,
		wan_hands_up = 120552622314012,
		wan_hip_shake = 79942340342131,
		wan_low_bounce = 135959861316582,
		wan_point = 105777944945343,
		wan_rock = 77046318478662,
	}),
	human_child = ids({
		-- mocap 2026-11-09 ท่ายืนสุ่ม (HumanNPC.idleIdOf)
		idle_weight = 118998457719263,
		idle_look = 83420011339264,
		idle_bored = 120595603306604,
		ghost_dance = 122941362270230,
		ghost_glide = 82388356442584,
		ghost_idle = 100345992732110,
		idle = 103873101046606, -- mocap 2026-11-08 (เดิม 77739143578548)
		ramwong = 128858322441131,
		run = 96127724983333,
		run_skirt = 114646258071509,
		walk = 98217101131177, -- mocap 2026-11-08 (เดิม 77258023396732)
		walk_skirt = 120210620976113,
		wan_bounce = 105250719096311,
		wan_cool = 92409645819462,
		wan_hands_up = 71982611877798,
		wan_hip_shake = 134492548143267,
		wan_low_bounce = 82377970638315,
		wan_point = 94049584992041,
		wan_rock = 135629295621384,
	}),
	human_elder_male = ids({
		-- mocap 2026-11-09 ท่ายืนสุ่ม (HumanNPC.idleIdOf)
		idle_weight = 110136840486166,
		idle_look = 96409017120657,
		idle_old = 104020822668007,
		ghost_dance = 104396131538115,
		ghost_glide = 120833178064455,
		ghost_idle = 121857683656072,
		idle = 123679197324124, -- mocap 2026-11-08 (เดิม 132619334853140)
		ramwong = 86963774329372,
		run = 75453641777008,
		run_skirt = 140210160820494,
		walk = 79358790282345, -- mocap 2026-11-08 (เดิม 133206909891901)
		walk_skirt = 137131228611137,
		wan_bounce = 116111768404862,
		wan_cool = 73693894182782,
		wan_hands_up = 105229316614420,
		wan_hip_shake = 74448885549661,
		wan_low_bounce = 104382522178307,
		wan_point = 108084129340860,
		wan_rock = 132294356917846,
	}),
	human_elder_female = ids({
		-- mocap 2026-11-09 ท่ายืนสุ่ม (HumanNPC.idleIdOf)
		idle_look = 98275380123658,
		idle_weight = 103611153868323,
		idle_old = 83030472069469,
		ghost_dance = 118755911163939,
		ghost_glide = 131786192428104,
		ghost_idle = 74765094787834,
		idle = 103801004291370, -- mocap 2026-11-08 (เดิม 138025499029648)
		ramwong = 125229810760608,
		run = 96146168762393,
		run_skirt = 78737353699695,
		walk = 94793861520624, -- mocap 2026-11-08 (เดิม 83871222558672)
		walk_skirt = 84245106769410,
		wan_bounce = 81516894106622,
		wan_cool = 100905498951945,
		wan_hands_up = 104597426747468,
		wan_hip_shake = 111806258841550,
		wan_low_bounce = 73076320233683,
		wan_point = 117677053753844,
		wan_rock = 134944182421650,
	}),
}

-- ตัวผู้เล่น (character/Animate, หุ่นทดสอบใน server/Cutscene): ใช้ท่าชุดเดิมของ human_base (สูตรคณิตศาสตร์)
--   ท่า mocap ขยับไหล่/อก/หัว -> ท่าพนมมือ/ถือของ (ท่าซ้อน UPPER_ONLY ที่ทำบนท่ายืนเดิม) มือไม่แนบกัน และกล้องมุมบุคคลที่หนึ่งโยกตามหัว
local player = table.clone(T.human_base)
for clip, id in pairs({ idle = 103800868829848, walk = 132822592476604, ride_moto = 132408927006595, drive_car = 129503151043569, drive_tuktuk = 134908139865752 }) do
	player[clip] = "rbxassetid://" .. tostring(id)
end
T.player = player

return T
