--!strict
-- UiFit.luau (ReplicatedStorage.Shared) — ย่อ HUD ตามความสูงจอ ที่เดียวสำหรับทุกกล่อง
-- จอเตี้ย (โน้ตบุ๊ก 14 นิ้ว ~700 px) กล่องกินที่เยอะ: ย่อลงตามความสูงจอ แต่ไม่ให้เล็กจนอ่านไม่ออก
--   UiFit.Attach(screenGui)   -- ใส่ UIScale ให้ทั้ง ScreenGui (ตำแหน่งชิดขอบจอยังชิดขอบเหมือนเดิม)
-- ปรับ 2 ค่านี้ที่เดียว: REF_HEIGHT = ความสูงจอที่แสดง 100%, MIN_SCALE = ย่อได้น้อยสุด
-- คอม (ไม่ใช่จอสัมผัส): จอสูงขึ้น = ขยาย UI ขึ้นด้วย (เดิมจอ 1080p ตัวหนังสือ/กล่องดูเล็กไปเทียบกับมือถือ ผู้ใช้ 2026-11-05)
--   PC_REF_HEIGHT = ความสูงจอที่แสดง 100% บนคอม, PC_MAX_SCALE = ขยายได้สุด · มือถือ/แท็บเล็ตใช้สูตรเดิม (โอเคแล้ว)
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UiFit = {}

local REF_HEIGHT = 900
local MIN_SCALE = 0.88
local PC_REF_HEIGHT = 560
local PC_MAX_SCALE = 1.7

local function isTouch(cam: Camera): boolean
	return UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or cam.ViewportSize.Y < 500)
end

function UiFit.Scale(): number
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	local h = cam.ViewportSize.Y
	if isTouch(cam) then
		return math.clamp(h / REF_HEIGHT, MIN_SCALE, 1)
	end
	return math.clamp(h / PC_REF_HEIGHT, MIN_SCALE, PC_MAX_SCALE)
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
