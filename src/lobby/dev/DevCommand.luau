-- DevCommand.luau — Inspect GasPump & prompts
return {
	id = "inspect_pump_" .. tostring(os.time()),
	run = function()
		local ws = game:GetService("Workspace")
		local ip = ws:FindFirstChild("InteractiveProps")
		print("DEVCMD|InteractiveProps:", ip ~= nil)
		if ip then
			local gp = ip:FindFirstChild("GasPump")
			print("DEVCMD|GasPump model:", gp ~= nil)
			if gp then
				print("DEVCMD|GasPump children:")
				for _, c in ipairs(gp:GetChildren()) do
					print("  DEVCMD|child:", c.Name, c.ClassName)
					for _, d in ipairs(c:GetChildren()) do
						print("    DEVCMD|grandchild:", d.Name, d.ClassName)
					end
				end
			end
			local dp = ip:FindFirstChild("DieselPump")
			print("DEVCMD|DieselPump model:", dp ~= nil)
			if dp then
				print("DEVCMD|DieselPump children:")
				for _, c in ipairs(dp:GetChildren()) do
					print("  DEVCMD|child:", c.Name, c.ClassName)
				end
			end
			print("DEVCMD|All ProximityPrompts in Workspace:")
			for _, p in ipairs(ws:GetDescendants()) do
				if p:IsA("ProximityPrompt") then
					print("  DEVCMD|Prompt:", p.Name, "Parent:", p.Parent:GetFullName(), "Enabled:", p.Enabled, "Distance:", p.MaxActivationDistance, "Hold:", p.HoldDuration)
				end
			end
		end
	end,
}
