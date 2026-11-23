--!strict
-- GraphicsGuard.client.luau — แมพปั๊ม: เก็บเงาไฟไว้ให้นานที่สุด (ระบบอยู่ shared/GfxGuard)
--   มือถือ: เงาเฉพาะไฟเพดานร้าน + ไฟเสาหน้าร้าน (+ ไฟฉายของตัวเองใน HUDController) · ไฟประดับสว่างแต่ไม่ทำเงา
--           ระยะไฟในร้านสั้นลง: ถ้าเงาโดนตัด แสงจะไม่ลอดผนังออกไปสว่างข้างนอก
--   ทุกเครื่อง: เฟรมตกต่อเนื่อง -> GfxTrim ขึ้น (เบลอ/DOF/Bloom ปิดใน client/AmbienceController, ไฟประดับ/ไฟเสาเลิกทำเงา)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeviceInfo = require(Shared:WaitForChild("DeviceInfo")) :: any
local GfxGuard = require(Shared:WaitForChild("GfxGuard")) :: any

local KIND: { [string]: string } = {
	InteriorLight = "main", -- ไฟเพดานร้าน
	FlickerLight = "pole", -- ไฟเสาหน้าร้าน
	LanternLight = "decor", -- ตะเกียงบนเคาน์เตอร์
	HangingBulbLight = "decor", -- หลอดห้อย
	ShrineEerieGlow = "decor", -- ไฟศาล
}

GfxGuard.Start({
	isPhone = DeviceInfo.IsPhone() == true,
	classify = function(l: Light): string?
		return KIND[l.Name]
	end,
	-- ไฟจุดรอบทิศในร้าน ระยะเดิม 26 / 20 / 16
	phoneRange = {
		InteriorLight = { 17, 1.15 },
		HangingBulbLight = { 13, 1.15 },
		LanternLight = { 11, 1.1 },
	},
})
