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
	-- size multiplier applied when a ghost is cloned (Model:ScaleTo; clips scale with it). Pret: 5x (user 2026-11-05)
	SCALE = { Pret = 5 },
	ONCE = { Shriek = true, LandOnRoof = true, nak_reach = true, Lunge = true, Sniff = true, HairWhip = true, PossessedSnap = true },
	ghost_headless = ids({ pillion_hug = 78873226456252 }),
	ghost_mirror = ids({ pillion_hug = 91804513941402, pillion_look = 126959303493117 }),
	ghost_tani = ids({ ghost_idle = 133823304425459, tani_peek = 75686746403977 }),
	ghost_dancer = ids({ dancer_dance = 86686920333830, dancer_idle = 94261104886943 }),
	ghost_funeral_man = ids({ coffin_walk = 120520965103699, ghost_glide = 136941547644862 }),
	ghost_funeral_woman = ids({ coffin_walk = 71011177242344, ghost_glide = 99726662578277 }),
	ghost_funeral_elder_man = ids({ coffin_walk = 109770687233734, ghost_glide = 76991415181788 }),
	ghost_funeral_elder_woman = ids({ coffin_walk = 74971187427572, ghost_glide = 109652720326443 }),
	ghost_child = ids({ ghost_idle = 124883772234827, ghost_glide = 86474664561093 }),
	ghost_kuman_thong = ids({ kuman_sit = 70909429351205, kuman_giggle = 130406208011508, run = 80261206109085 }),
	ghost_mae_nak = ids({ nak_cradle = 124315963545474, nak_reach = 122508820984005 }),
	ghost_shroud = ids({ shroud_idle = 95715750395399, shroud_glide = 82277369190169 }),
	ghost_ta_khon = ids({ ride_moto = 87834972912668, mask_tilt = 113153843662589 }),
	Pret = ids({ Idle = 71398122894527, TallSlowWalk = 119338239942215, Shriek = 117225562688135 }),
	Krahang = ids({ FlapFly = 88813450469689, Glide = 72147294602733, LandOnRoof = 82898367901622, PeekOverEdge = 109953200095230 }),
	Krasue = ids({ Float = 81641072874464, Lunge = 117758248464276, Sniff = 110964156480540, HairWhip = 77051091289615 }),
	Pop = ids({ TwitchWalk = 71071901172533, LickLips = 89252227044099, KnockShutter = 93895985426542, PossessedSnap = 98200845968694 }),
}
