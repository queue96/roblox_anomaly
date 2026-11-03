--!strict
-- UiFit.luau (ReplicatedStorage.Shared) — ย่อ HUD ตามความสูงจอ ที่เดียวสำหรับทุกกล่อง
-- จอเตี้ย (โน้ตบุ๊ก 14 นิ้ว ~700 px) กล่องกินที่เยอะ: ย่อลงตามความสูงจอ แต่ไม่ให้เล็กจนอ่านไม่ออก
--   UiFit.Attach(screenGui)   -- ใส่ UIScale ให้ทั้ง ScreenGui (ตำแหน่งชิดขอบจอยังชิดขอบเหมือนเดิม)
-- ปรับ 2 ค่านี้ที่เดียว: REF_HEIGHT = ความสูงจอที่แสดง 100%, MIN_SCALE = ย่อได้น้อยสุด
local Workspace = game:GetService("Workspace")

local UiFit = {}

local REF_HEIGHT = 900
local MIN_SCALE = 0.88

function UiFit.Scale(): number
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	return math.clamp(cam.ViewportSize.Y / REF_HEIGHT, MIN_SCALE, 1)
end

local scales: { UIScale } = {}
local watching = false

function UiFit.Attach(target: Instance): UIScale
	local s = target:FindFirstChild("UiFitScale") :: UIScale?
	if not s then
		s = Instance.new("UIScale")
		s.Name = "UiFitScale";
		(s :: UIScale).Parent = target
	end
	local us = s :: UIScale
	us.Scale = UiFit.Scale()
	table.insert(scales, us)
	if not watching and Workspace.CurrentCamera then
		watching = true
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local v = UiFit.Scale()
			for _, x in ipairs(scales) do
				x.Scale = v
			end
		end)
	end
	return us
end

return UiFit
