--!strict
-- AnimationIds of the ghost clips (KeyframeSequences in Studio: ServerStorage.GhostAnims.<ghost>.<ghost>_<clip>,
-- built from assets/models/roblox/ghost_anims/<ghost>_anims.json with tools/studio/HumanAnimImport.luau, then
-- Save to Roblox). A ghost with no id for a clip is still shown, just without that clip (rest pose).
-- ONCE = clips that play one time and hold the last frame; every other clip loops.
local function ids(t: { [string]: number }): { [string]: string }
	local out = {}
	for clip, id in pairs(t) do
		out[clip] = "rbxassetid://" .. tostring(id)
	end
	return out
end

return {
	ONCE = { Shriek = true, LandOnRoof = true, nak_reach = true },
	ghost_headless = ids({}), -- pillion_hug
	ghost_mirror = ids({}), -- pillion_hug, pillion_look
	ghost_tani = ids({}), -- ghost_idle, tani_peek
	ghost_dancer = ids({}), -- dancer_dance, dancer_idle
	ghost_funeral_man = ids({}), -- coffin_walk, ghost_glide
	ghost_funeral_woman = ids({}),
	ghost_funeral_elder_man = ids({}),
	ghost_funeral_elder_woman = ids({}),
	ghost_child = ids({}), -- ghost_idle, ghost_glide
	ghost_kuman_thong = ids({}), -- kuman_sit, kuman_giggle, run
	ghost_mae_nak = ids({}), -- nak_cradle, nak_reach
	ghost_shroud = ids({}), -- shroud_idle, shroud_glide
	ghost_ta_khon = ids({}), -- ride_moto, mask_tilt
	Pret = ids({}), -- Idle, TallSlowWalk, Shriek
	Krahang = ids({}), -- FlapFly, Glide, LandOnRoof, PeekOverEdge
	Krasue = ids({}), -- Float, Lunge, Sniff, HairWhip
	Pop = ids({}), -- TwitchWalk, LickLips, KnockShutter, PossessedSnap
}
