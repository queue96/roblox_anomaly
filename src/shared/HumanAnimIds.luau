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
	}),
	-- human_female, human_child, human_elder_male, human_elder_female: not published yet
}
