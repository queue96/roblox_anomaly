-- DevCommand.luau — Lobby: big ring compile + obstacle check at (0, 4) (2026-11-23)
return {
	id = "check_bigring_20261123_2",
	placeId = 70980777393906,
	run = function()
		local SES = game:GetService("ScriptEditorService")
		local want = { LobbyClient = "setupBig", LobbyServer = "BIG_RING_INDEX", LanguageModule = "BigRoomNeedPass", RobuxShop = "FREE_ROOM_SIZE" }
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
			end
		end
		-- ของที่อยู่ในรัศมีวงใหม่ (0, 4) r = 12
		local hits = {}
		local params = OverlapParams.new()
		for _, p in ipairs(workspace:GetPartBoundsInBox(CFrame.new(0, 4, 4), Vector3.new(24, 7, 24), params)) do
			local top = p
			while top.Parent and top.Parent ~= workspace and top.Parent.Name ~= "TempleLobby" do
				top = top.Parent
			end
			hits[top:GetFullName()] = (hits[top:GetFullName()] or 0) + 1
		end
		for k, v in pairs(hits) do
			print("DEVCMD|NEAR", k, v)
		end
	end,
}
