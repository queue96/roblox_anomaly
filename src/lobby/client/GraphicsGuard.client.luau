--!strict
-- GraphicsGuard.client.luau — Lobby: ไฟทำเงาจาก 30 ดวงเหลือเฉพาะดวงที่ดูสำคัญ + ลดเอฟเฟกต์ตอนเฟรมตก (ระบบอยู่ shared/GfxGuard)
--   เดิมทุกดวงในลานวัดทำเงา (เสาไฟ 12 ต้นระยะ 46 คำนวณเงาทับกันทั้งลาน) -> มือถือร้อน กราฟิก Auto ตัดเงาทิ้งหมด
--   ผู้ใช้ 2026-11-23: Lobby ผู้เล่นอยู่ไม่นาน ไม่ต้องสวยสุด -> เบาไว้ก่อน
--   main  : ไฟหน้าอุโบสถ (เงาไว้เสมอ)
--   decor : เสาไฟ 2 ต้นข้างจุดเกิด + ไฟซุ้มประตู (PC มีเงา / มือถือไม่มี)
--   off   : เสาไฟที่เหลือ เทียน ถ่านเมรุ ไฟกุฏิ ฯลฯ ยังสว่างแต่ไม่ทำเงาทุกเครื่อง
--   เอฟเฟกต์ (LobbyServer สร้าง): เบลอทั้งจอ + DOF ปิดทุกเครื่อง · Bloom เฉพาะ PC (GfxTrim 2 = ปิด)

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DeviceInfo = require(Shared:WaitForChild("DeviceInfo")) :: any
local GfxGuard = require(Shared:WaitForChild("GfxGuard")) :: any

local IS_PHONE = DeviceInfo.IsPhone() == true

local DECOR = { PlazaPole_5 = true, PlazaPole_8 = true, GateLamp = true }
local MAIN = { UbosotFacadeLight = true }

local function classify(l: Light): string?
	local a: Instance? = l.Parent
	local lobby = workspace:FindFirstChild("TempleLobby")
	if not (lobby and l:IsDescendantOf(lobby)) then
		return nil -- ไฟที่สคริปต์อื่นสร้าง (แผงขาย Game Pass ฯลฯ) ไม่แตะ
	end
	while a and a ~= lobby do
		if MAIN[a.Name] then
			return "main"
		elseif DECOR[a.Name] then
			return "decor"
		end
		a = a.Parent
	end
	return "off"
end

local current = 0
local function applyEffects()
	local t = current
	local blur = Lighting:FindFirstChild("LobbySoftBlur")
	if blur and blur:IsA("BlurEffect") then
		blur.Enabled = false
	end
	local dof = Lighting:FindFirstChild("LobbyDepthOfField")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = false
	end
	local bloom = Lighting:FindFirstChild("LobbyBloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = not IS_PHONE and t < 2
	end
	-- Bloom เก่าในไฟล์ place (ชื่อ "Bloom" Intensity 0): ภาพไม่ต่างแต่เป็นอีกหนึ่งรอบเรนเดอร์ทั้งจอ (แมพปั๊มปิดแบบเดียวกันใน AmbienceController)
	local legacy = Lighting:FindFirstChild("Bloom")
	if legacy and legacy:IsA("BloomEffect") and legacy.Intensity <= 0.001 then
		legacy.Enabled = false
	end
end
Lighting.ChildAdded:Connect(function()
	task.defer(applyEffects)
end)

GfxGuard.Start({
	isPhone = IS_PHONE,
	classify = classify,
	onTrim = function(t: number)
		current = t
		applyEffects()
	end,
})
