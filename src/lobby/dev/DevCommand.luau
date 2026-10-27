-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "rebuild-temple-19",
	placeId = 70980777393906,
	run = function()
		local MapBuilder = require(game:GetService("ReplicatedStorage").Shared.MapBuilder:Clone())
		MapBuilder.BuildTempleLobby(Vector3.zero, true, 2)
		local arch = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
		if arch then
			arch:Destroy()
		end
		local out = {}
		for _, pad in ipairs(game:GetService("CollectionService"):GetTagged("RoomPad")) do
			table.insert(out, ("%d@(%.0f,%.0f) r=%.0f"):format(pad:GetAttribute("PadIndex"), pad.Position.X, pad.Position.Z, pad.Size.Y / 2))
		end
		table.sort(out)
		print("DEVCMD|pads " .. #out .. ": " .. table.concat(out, "  "))
	end,
}
