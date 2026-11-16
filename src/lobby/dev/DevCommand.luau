-- DevCommand.luau — compile GhostNPC + confirm the Ta Khon templates now use TintMask (2026-11-17)
return {
	id = "takhon_verify_20261117c",
	placeId = 114125276809667,
	run = function()
		local ss = game:GetService("ServerStorage")
		local rs = game:GetService("ReplicatedStorage")
		local src = game:GetService("ServerScriptService"):FindFirstChild("GhostNPC", true)
		local s = string.gsub(src.Source, "\n[ \t]*%-%-[^\n]*", "\n")
		local m = Instance.new("ModuleScript")
		m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. s
		local ok, err = pcall(require, m)
		print("DEVCMD|COMPILE GhostNPC synced=" .. tostring(string.find(src.Source, "fixClothAlpha", 1, true) ~= nil) .. " " .. (if ok then "OK" else "FAIL " .. tostring(err)))
		for _, where in ipairs({ ss.GhostTemplates, rs.GhostModels }) do
			local g = where.ghost_ta_khon
			for _, n in ipairs({ "BodyUpper", "BodyLower" }) do
				local sa = g[n]:FindFirstChildOfClass("SurfaceAppearance")
				print(string.format("DEVCMD|%s.%s alpha %s normal %s rough %s tint (%d,%d,%d)", where.Name, n, sa.AlphaMode.Name, tostring(sa.NormalMap ~= ""), tostring(sa.RoughnessMap ~= ""), sa.Color.R * 255, sa.Color.G * 255, sa.Color.B * 255))
			end
		end
	end,
}
