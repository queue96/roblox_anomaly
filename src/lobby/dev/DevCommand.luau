-- DevCommand.luau — scarecrow roaming moved to the server (ScarecrowRoam), back-scare once a night, knock ghost limits:
-- confirm the scripts reached Studio and compile (2026-11-22)
return {
	id = "check_scarecrow_server_knock_20261122_1",
	placeId = 114125276809667,
	run = function()
		local want = {
			ScarecrowRoam = "local MAX_MOVES = 2",
			SceneryGhosts = "closeScaresThisNight < MAX_CLOSE_SCARES",
			AdminPanel = "scarecrow:move",
			GhostLinger = "KnockMax = 3",
		}
		local seen = {}
		for _, d in ipairs(game:GetDescendants()) do
			local ok, isSrc = pcall(function()
				return d:IsA("LuaSourceContainer")
			end)
			if ok and isSrc and want[d.Name] then
				local src = (d :: any).Source :: string
				local m = Instance.new("ModuleScript")
				m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. src
				m.Parent = workspace
				local okc, err = pcall(require, m)
				m:Destroy()
				print("DEVCMD|SRC", d:GetFullName(), d.ClassName, #src, "has", string.find(src, want[d.Name], 1, true) ~= nil, "compile", okc, if okc then "" else tostring(err))
				seen[d.Name] = true
			end
		end
		for n in pairs(want) do
			if not seen[n] then
				print("DEVCMD|MISSING", n)
			end
		end
		local sc = workspace.AnomalyProps:FindFirstChild("Scarecrow")
		print("DEVCMD|scarecrow", sc and sc:GetFullName(), sc and tostring(sc:GetPivot().Position))
	end,
}
