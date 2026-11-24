-- DevCommand.luau — remove the customer Krasue book portrait + compile check (2026-11-24)
return {
	id = "lobby_drop_krasue_20261124_1",
	placeId = 70980777393906,
	run = function()
		task.wait(3)
		local CHS = game:GetService("ChangeHistoryService")
		local SES = game:GetService("ScriptEditorService")
		CHS:SetWaypoint("Before remove customer Krasue portrait")
		for _, root in ipairs({ game:GetService("ReplicatedStorage"), game:GetService("ServerStorage") }) do
			local bp = root:FindFirstChild("BookPortraits")
			local m = bp and bp:FindFirstChild("Anomaly_Krasue")
			if m then
				print("DEVCMD|REMOVE", m:GetFullName())
				m.Parent = nil
			end
			if bp then
				print("DEVCMD|LEFT", bp:GetFullName(), bp:FindFirstChild("Anomaly_Krasue") == nil, "big", bp:FindFirstChild("Big_Krasue") ~= nil, #bp:GetChildren())
			end
		end
		CHS:SetWaypoint("Remove customer Krasue portrait")
		local names = { AnomalyManager = true, CoreLoop = true, AnomalyBook = true, LanguageModule = true, AdminPanel = true, JumpscareController = true, PrayerController = true, RiderMotion = true, RobuxShop = true }
		for _, root in ipairs({ game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage"), game:GetService("StarterPlayer") }) do
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("LuaSourceContainer") and names[d.Name] then
					local src = (d :: any).Source
					local t = Instance.new("ModuleScript")
					t.Parent = game:GetService("ServerStorage")
					local ok, err = pcall(function()
						SES:UpdateSourceAsync(t, function()
							return "local __skip = (game ~= nil)" .. string.char(10) .. "if __skip then return {} end" .. string.char(10) .. src
						end)
					end)
					local okc = false
					if ok then
						okc, err = pcall(require, t)
					end
					t:Destroy()
					print("DEVCMD|SRC", d:GetFullName(), "compile", okc, "oldKey", string.find(src, "Anomaly_Krasue", 1, true) ~= nil, if okc then "" else tostring(err))
				end
			end
		end
	end,
}
