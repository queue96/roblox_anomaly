-- DevCommand.luau — Pump Lot: ghost book synced + compile synced + compile (2026-11-23)
return {
	id = "check_shaman_pump_20261123_1",
	placeId = 114125276809667,
	run = function()
		local SES = game:GetService("ScriptEditorService")
		local want = {
			GhostBook = "WatchShamanTags(1.6)",
			RobuxShop = "WatchShamanTags",
			LanguageModule = "ShamanTitle",
		}
		local seen = {}
		for _, d in ipairs(game:GetDescendants()) do
			local ok, isSrc = pcall(function()
				return d:IsA("LuaSourceContainer")
			end)
			if ok and isSrc and want[d.Name] and not d:IsDescendantOf(game:GetService("ServerStorage")) then
				local src = (d :: any).Source :: string
				local m = Instance.new("ModuleScript")
				m.Parent = game:GetService("ServerStorage")
				local okSet, err = pcall(function()
					SES:UpdateSourceAsync(m, function()
						return "local __skip = (game ~= nil)" .. string.char(10) .. "if __skip then return {} end" .. string.char(10) .. src
					end)
				end)
				local okc = false
				if okSet then
					okc, err = pcall(require, m)
				end
				m:Destroy()
				print("DEVCMD|SRC", d:GetFullName(), #src, "has", string.find(src, want[d.Name], 1, true) ~= nil, "compile", okc, if okc then "" else tostring(err))
				seen[d.Name] = true
			end
		end
		for n in pairs(want) do
			if not seen[n] then
				print("DEVCMD|MISSING", n)
			end
		end
	end,
}
