-- DevCommand.luau — Build updated Mixamo KeyframeSequences in ServerStorage.GhostAnims
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	id = "compile_scenery_pop_crawl_1",
	placeId = 114125276809667,
	run = function()
		do
			local src = game:GetService("StarterPlayer").StarterPlayerScripts.Client.SceneryGhosts
			local m = Instance.new("ModuleScript")
			m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. src.Source
			m.Parent = ServerStorage
			local ok, err = pcall(require, m)
			m:Destroy()
			print("DEVCMD|COMPILE SceneryGhosts " .. (if ok then "ok" else "FAIL " .. tostring(err)))
			local d = ReplicatedStorage.Shared.GhostClipData:Clone()
			d.Parent = ReplicatedStorage.Shared
			local ok2, Data = pcall(require, d)
			d:Destroy()
			print("DEVCMD|GhostClipData " .. (if ok2 and Data.tani_walk then string.format("ok tani_walk len=%.2f keys=%d", Data.tani_walk.length, #Data.tani_walk.times) else "FAIL " .. tostring(Data)))
		end
		local mocapFolder = ServerStorage:FindFirstChild("MocapData")
		local gmFolder = mocapFolder and mocapFolder:FindFirstChild("ghost_mocap")
		if not gmFolder then
			warn("DEVCMD|Missing ServerStorage.MocapData.ghost_mocap")
			return
		end

		local parts = {}
		for i = 0, 50 do
			local sv = gmFolder:FindFirstChild(string.format("part%03d", i)) :: StringValue?
			if not sv then
				break
			end
			table.insert(parts, sv.Value)
		end
		local data = HttpService:JSONDecode(table.concat(parts, ""))
		local H = require(ServerStorage:WaitForChild("HumanAnimImport"):Clone())
		local gt = ServerStorage:WaitForChild("GhostTemplates")

		local ga = ServerStorage:FindFirstChild("GhostAnims")
		if not ga then
			ga = Instance.new("Folder")
			ga.Name = "GhostAnims"
			ga.Parent = ServerStorage
		end

		local GHOST_CLIPS = {
			Pop = {
				TwitchWalk = "Pop_TwitchWalk",
				LickLips = "Pop_LickLips",
				PossessedSnap = "Pop_PossessedSnap",
				KnockShutter = "Pop_KnockShutter",
				Crawl = "Pop_Crawl",
			},
			ghost_dancer = {
				dancer_dance = "dancer_dance",
				dancer_idle = "dancer_idle",
			},
			ghost_tani = {
				ghost_idle = "ghost_idle",
				tani_peek = "tani_peek",
				tani_walk = "tani_walk",
			},
			ghost_mae_nak = {
				nak_cradle = "nak_cradle",
				nak_reach = "nak_reach",
			},
			ghost_funeral_man = {
				coffin_walk = "coffin_walk",
				ghost_glide = "ghost_glide",
			},
			ghost_funeral_woman = {
				coffin_walk = "coffin_walk",
				ghost_glide = "ghost_glide",
			},
			ghost_funeral_elder_man = {
				coffin_walk = "coffin_walk",
				ghost_glide = "ghost_glide",
			},
			ghost_funeral_elder_woman = {
				coffin_walk = "coffin_walk",
				ghost_glide = "ghost_glide",
			},
			ghost_shroud = {
				shroud_idle = "shroud_idle",
				shroud_glide = "shroud_glide",
			},
			ghost_headless = {
				pillion_hug = "pillion_hug",
			},
			ghost_mirror = {
				pillion_hug = "pillion_hug",
				pillion_look = "pillion_look",
			},
			ghost_ta_khon = {
				mask_tilt = "mask_tilt",
			},
			ghost_child = {
				ghost_idle = "ghost_idle",
				ghost_glide = "ghost_glide",
			},
		}

		local ONCE = { PossessedSnap = true, nak_reach = true }
		local builtCount = 0

		for gname, clipMap in pairs(GHOST_CLIPS) do
			local model = gt:FindFirstChild(gname) :: Model?
			if model then
				local gFolder = ga:FindFirstChild(gname)
				if not gFolder then
					gFolder = Instance.new("Folder")
					gFolder.Name = gname
					gFolder.Parent = ga
				end
				for clipName, srcKey in pairs(clipMap) do
					local clipData = data.clips[srcKey]
					if clipData then
						local kfsName = gname .. "_" .. clipName
						local old = gFolder:FindFirstChild(kfsName)
						if old then
							old:Destroy()
						end
						local kfs = H.build(model, data.rest, clipData, kfsName)
						kfs.Loop = not ONCE[clipName]
						kfs.Parent = gFolder
						builtCount += 1
					end
				end
			end
		end

		print(string.format("DEVCMD|Built %d Mixamo GhostAnims KeyframeSequences in ServerStorage.GhostAnims!", builtCount))
	end,
}
