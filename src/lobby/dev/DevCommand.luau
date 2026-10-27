-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "rebuild-temple-1",
	placeId = 70980777393906,
	run = function()
		local ServerStorage = game:GetService("ServerStorage")
		local MapBuilder = require(game:GetService("ReplicatedStorage").Shared.MapBuilder:Clone())
		local lobby = MapBuilder.BuildTempleLobby(Vector3.zero, true, 3)
		local n = 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		local cf, size = lobby:GetBoundingBox()
		print(("DEVCMD|TempleLobby parts=%d size=(%.0f, %.0f, %.0f) center=(%.0f, %.0f)"):format(n, size.X, size.Y, size.Z, cf.X, cf.Z))
		for _, c in ipairs(lobby:GetChildren()) do
			if c:IsA("Model") then
				local p = c:GetPivot()
				local _, ry = p:ToOrientation()
				print(("DEVCMD|  %s at (%.0f, %.0f) yaw %.0f scale %.2f"):format(c.Name, p.X, p.Z, math.deg(ry), c:GetScale()))
			end
		end
		local old = ServerStorage:FindFirstChild("ArchivedPlaceholders")
		print("DEVCMD|archived old lobby: " .. tostring(old ~= nil and old:FindFirstChild("TempleLobby") ~= nil))
	end,
}
