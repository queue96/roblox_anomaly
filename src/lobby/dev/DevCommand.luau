-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "rebuild-temple-3",
	placeId = 70980777393906,
	run = function()
		local MapBuilder = require(game:GetService("ReplicatedStorage").Shared.MapBuilder:Clone())
		local lobby = MapBuilder.BuildTempleLobby(Vector3.zero, true, 2)
		local arch = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
		if arch then
			arch:Destroy()
		end
		local spooky = lobby.SpookyDecor
		local poles, lights = 0, 0
		for _, c in ipairs(spooky:GetChildren()) do
			if c.Name:match("^PlazaPole_") then
				poles += 1
			end
		end
		for _, d in ipairs(lobby:GetDescendants()) do
			if d:IsA("PointLight") then
				lights += 1
			end
		end
		print(("DEVCMD|poles=%d wires=%d pointLights=%d"):format(poles, #spooky.PowerWires:GetChildren(), lights))
	end,
}
