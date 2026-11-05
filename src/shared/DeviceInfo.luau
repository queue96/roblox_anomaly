--!strict
-- DeviceInfo.luau (ReplicatedStorage.Shared) — อุปกรณ์ของผู้เล่น (ใช้ฝั่ง Client เท่านั้น)
--   DeviceInfo.IsPhone()     = มือถือ: จอสัมผัสที่ด้านสั้นของจอ < 500 (แท็บเล็ต/คอม/คอนโซล = false)
--   DeviceInfo.VolumeBoost() = ตัวคูณความดังเสียงทั้งเกม: มือถือดังขึ้น (ลำโพงมือถือเบากว่าคอมมาก) อุปกรณ์อื่น = 1
-- ปรับความดังมือถือที่เดียว: PHONE_VOLUME_BOOST
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DeviceInfo = {}

local PHONE_VOLUME_BOOST = 1.8

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

function DeviceInfo.VolumeBoost(): number
	return if DeviceInfo.IsPhone() then PHONE_VOLUME_BOOST else 1
end

return DeviceInfo
