-- DevCommand.luau — survey vehicle template lights
return {
	id = "survey_vehlights_1",
	placeId = 100908782853687,
	run = function()
		local t = game:GetService("ServerStorage"):FindFirstChild("VehicleTemplates")
		for _, m in ipairs(t:GetChildren()) do
			local piv = m:GetPivot()
			local n = 0
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("SpotLight") then
					n += 1
					local cf = if d.Parent:IsA("Attachment") then d.Parent.WorldCFrame else d.Parent.CFrame
					local dir = piv:VectorToObjectSpace(cf.LookVector)
					print(("DEVCMD|%s SPOT %s parent=%s en=%s b=%.1f r=%.0f a=%.0f face=%s dirLocal=%.2f,%.2f,%.2f"):format(m.Name, d.Name, d.Parent.Name, tostring(d.Enabled), d.Brightness, d.Range, d.Angle, d.Face.Name, dir.X, dir.Y, dir.Z))
				end
			end
			if n == 0 then print("DEVCMD|" .. m.Name .. " NO SPOT") end
		end
	end,
}
