-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "set-sky-no-stars-1",
	run = function()
		local Lighting = game:GetService("Lighting")
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if not sky then
			sky = Instance.new("Sky")
			sky.Name = "NightSky"
			sky.Parent = Lighting
		end
		sky.StarCount = 0
		sky.CelestialBodiesShown = true
		print("DEVCMD|Sky StarCount=0 done")
	end,
}
