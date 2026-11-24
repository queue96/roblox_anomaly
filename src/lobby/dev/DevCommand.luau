-- DevCommand.luau — read-only: is today's scene work still in the place (2026-11-24)
return {
	id = "state_20261124_1",
	run = function()
		local dd, far, mango, metal = 0, 0, 0, {}
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("MeshPart") then
				if d:GetAttribute("VegDedupe") then dd += 1 end
				if d:GetAttribute("FarVeg") then far += 1 end
				if d.Name == "MangoFar" then mango += 1 end
			elseif d:IsA("SurfaceAppearance") and d.MetalnessMap ~= "" then
				metal[d.MetalnessMap] = true
			end
		end
		local m = 0
		for _ in pairs(metal) do m += 1 end
		local soft = 0
		local otl = workspace:FindFirstChild("MapEnvironment") and workspace.MapEnvironment:FindFirstChild("OuterTreeLine")
		for _, d in ipairs(otl and otl:GetDescendants() or {}) do
			if d:IsA("BasePart") and d.CanCollide then soft += 1 end
		end
		local bp = game:GetService("ReplicatedStorage"):FindFirstChild("BookPortraits") or game:GetService("ServerStorage"):FindFirstChild("BookPortraits")
		local radio = bp and bp:FindFirstChild("Anomaly_MonkRadio")
		print("DEVCMD|STATE", game.PlaceId, "WS", #workspace:GetDescendants(), "dedupe", dd, "farveg", far, "mangoFar", mango, "metalMaps", m, "borderCollide", soft, "portraits", bp and #bp:GetChildren(), "radioV2", radio and radio:FindFirstChild("RadioDial", true) ~= nil)
		print("DEVCMD|STATE2 archTemple", (function()
			local a = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
			local t = a and a:FindFirstChild("TempleLobby")
			return t and #t:GetDescendants()
		end)(), game.PlaceVersion)
	end,
}
