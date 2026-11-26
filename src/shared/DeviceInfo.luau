--!strict
-- DeviceInfo.luau (ReplicatedStorage.Shared) — อุปกรณ์ของผู้เล่น (ใช้ฝั่ง Client เท่านั้น)
--   DeviceInfo.IsPhone()     = มือถือ: จอสัมผัสที่ด้านสั้นของจอ < 500 (แท็บเล็ต/คอม/คอนโซล = false)
--   DeviceInfo.VolumeBoost() = ตัวคูณความดังเสียงทั้งเกม (ทุก SoundGroup) แยกตามอุปกรณ์: มือถือ / แท็บเล็ตดังกว่าคอม (ลำโพงเบากว่ามาก)
-- ปรับความดังที่เดียว: PC_VOLUME_BOOST / PHONE_VOLUME_BOOST / TABLET_VOLUME_BOOST
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DeviceInfo = {}

-- มือถือ 1.8 -> 3.0 (ผู้ใช้ 2026-11-26 "เล่นในมือถือ ขนาดปรับเสียงสุดแล้วเสียงยังเบา") · แท็บเล็ตเดิมไม่คูณเลย
-- คอม/คอนโซล 1 -> 1.6 (ผู้ใช้ 2026-11-26: เกม Roblox อื่นเสียงดัง ผู้เล่นมักลดเสียง Roblox ค้างไว้ มาแมพเราเลยเบา)
local PC_VOLUME_BOOST = 1.6
local PHONE_VOLUME_BOOST = 3.0
local TABLET_VOLUME_BOOST = 1.8

function DeviceInfo.IsPhone(): boolean
	if not UserInputService.TouchEnabled then
		return false
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return false
	end
	local vp = cam.ViewportSize
	return math.min(vp.X, vp.Y) < 500
end

-- แท็บเล็ต = จอสัมผัสที่ไม่มีคีย์บอร์ด และไม่ใช่มือถือ (โน้ตบุ๊กจอสัมผัสมีคีย์บอร์ด = นับเป็นคอม)
function DeviceInfo.VolumeBoost(): number
	if DeviceInfo.IsPhone() then
		return PHONE_VOLUME_BOOST
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return TABLET_VOLUME_BOOST
	end
	return PC_VOLUME_BOOST
end

return DeviceInfo
