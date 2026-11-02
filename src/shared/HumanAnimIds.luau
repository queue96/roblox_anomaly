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

return {
	human_base = ids({
		idle = 103800868829848,
		walk = 132822592476604,
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
		drive_car = 129503151043569,
		ride_moto = 132408927006595,
		drive_tuktuk = 134908139865752,
		ride_bicycle = 135362256541891,
	}),
	-- human_female, human_child, human_elder_male, human_elder_female: not published yet
}
