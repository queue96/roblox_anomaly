-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "spread-banana-grove-2",
	placeId = 114125276809667,
	run = function()
		local MapBuilder = require(game:GetService("ReplicatedStorage").Shared.MapBuilder:Clone())
		MapBuilder.SpreadBananaGrove()
		print("DEVCMD|SpreadBananaGrove done")
	end,
}
