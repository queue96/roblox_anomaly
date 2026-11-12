-- DevCommand.luau — remove the temporary Kuman preview folder
return {
	id = "kuman_v2_cleanup_1",
	placeId = 114125276809667,
	run = function()
		local f = workspace:FindFirstChild("_KumanPreview")
		if f then
			f:Destroy()
		end
		print("DEVCMD|preview removed=" .. tostring(f ~= nil) .. " ws import left=" .. tostring(workspace:FindFirstChild("ghost_kuman_v2") ~= nil))
	end,
}
