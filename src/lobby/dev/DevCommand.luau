-- DevCommand.luau — Lobby: temple notice translations synced + compile (2026-11-23)
return {
	id = "check_lobby_temple_notice_20261123_1",
	placeId = 70980777393906,
	run = function()
		local SES = game:GetService("ScriptEditorService")
		local want = {
			LobbyClient = 'es = "Ya rezaste hoy. Vuelve mañana."',
			LanguageModule = 'GenKeyTap = {',
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
		local lmSrc = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
		local lmMod = lmSrc and lmSrc:FindFirstChild("LanguageModule")
		if lmMod then
			local c = lmMod:Clone()
			local okR, LM = pcall(require, c)
			if okR then
				for _, k in ipairs({ "GenStarting", "GenShocked", "GenKeyTap", "PrayButton" }) do
					print("DEVCMD|UI", k, LM.GetUI(k, "th"), "|", LM.GetUI(k, "es"), "|", LM.GetUI(k, "id"))
				end
			else
				print("DEVCMD|LMERR", LM)
			end
			c:Destroy()
		end
	end,
}
