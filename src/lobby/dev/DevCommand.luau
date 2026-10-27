-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "rebuild-temple-4",
	placeId = 70980777393906,
	run = function()
		local MapBuilder = require(game:GetService("ReplicatedStorage").Shared.MapBuilder:Clone())
		local lobby = MapBuilder.BuildTempleLobby(Vector3.zero, true, 2)
		local arch = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
		if arch then
			arch:Destroy()
		end
		local mango, banana = 0, 0
		for _, c in ipairs(lobby.Forest:GetChildren()) do
			if c.Name:match("^ForestMango") then
				mango += 1
			else
				banana += 1
			end
		end
		local parts = 0
		for _, d in ipairs(lobby:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		local pads = #game:GetService("CollectionService"):GetTagged("RoomPad")
		print(("DEVCMD|forest mango=%d banana=%d walls=%d pads=%d totalParts=%d ground=%s"):format(
			mango, banana, #lobby.InvisibleWalls:GetChildren(), pads, parts, tostring(lobby.TempleGround.Size)))
		print("DEVCMD|Shared: " .. table.concat((function()
			local t = {}
			for _, c in ipairs(game:GetService("ReplicatedStorage").Shared:GetChildren()) do
				table.insert(t, c.Name)
			end
			return t
		end)(), ", "))
	end,
}
