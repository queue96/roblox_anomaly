-- Weather.luau (ModuleScript ฝั่ง Server)
-- ฝนเป็นเอกลักษณ์ของคืน: บางคืนตกรอบเดียวยาวๆ คืนอื่นไม่ตกเลย (ผู้ใช้ 2026-11-05)
--   สถานะอยู่ที่ ReplicatedStorage.Remotes:GetAttribute("Weather") = "Clear" | "Rain"
--   Client (WeatherController) อ่านแล้วทำเม็ดฝน เสียงฝน พื้นเปียก แอ่งน้ำ
--   CoreLoop อ่าน Weather.IsRaining() เพื่อปรับลูกค้า (เดินมากางร่ม / บทพูด) แต่ความถี่ลูกค้าเท่าตอนไม่ตก
-- ทดสอบ: ServerStorage.DevDecision:Fire("rain") / Fire("clear") สั่งแล้วจะยกเลิกฝนที่สุ่มไว้ของคืนนั้น
--   และ "rain" จะตกไปจนกว่าจะสั่ง "clear" หรือจบคืน

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = {}

Weather.Config = {
	RainNightChance = 0.35, -- โอกาสที่คืนนี้จะเป็นคืนฝน (สุ่มครั้งเดียวตอนเปิดร้าน)
	RainStartAfter = { 180, 540 }, -- ฝนเริ่มหลังเปิดร้านเท่านี้ (วินาที)
	RainDuration = { 240, 420 }, -- ฝนตกนานเท่านี้ (วินาที)
}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local raining = false
local token = 0 -- เปลี่ยนเมื่อจบคืนหรือถูกสั่งจาก Dev (ยกเลิกฝนที่สุ่มไว้)

local function set(rain: boolean)
	if raining == rain then
		return
	end
	raining = rain
	remotes:SetAttribute("Weather", if rain then "Rain" else "Clear")
	print(if rain then "🌧️ ฝนตก" else "🌤️ ฝนหยุด")
end

function Weather.IsRaining(): boolean
	return raining
end

function Weather.Set(rain: boolean)
	token += 1
	set(rain)
end

local function rand(r: { number }): number
	return r[1] + math.random() * (r[2] - r[1])
end

function Weather.Start()
	remotes:SetAttribute("Weather", "Clear")
end

-- เปิดร้าน: สุ่มว่าคืนนี้ฝนตกไหม ถ้าตกจะตกรอบเดียว
function Weather.BeginNight()
	token += 1
	local my = token
	set(false)
	if math.random() >= Weather.Config.RainNightChance then
		print("🌤️ คืนนี้ไม่มีฝน")
		return
	end
	local startAfter = rand(Weather.Config.RainStartAfter)
	local duration = rand(Weather.Config.RainDuration)
	print(string.format("🌧️ คืนนี้ฝนจะตกหลังเปิดร้าน %.0f วิ นาน %.0f วิ", startAfter, duration))
	task.delay(startAfter, function()
		-- โหมดทดสอบ (แผง admin): ฝนไม่ตกเอง (ปุ่ม "ฝนตก" ยังใช้ได้)
		if my ~= token or ReplicatedStorage:GetAttribute("TestMode") == true then
			return
		end
		set(true)
		task.delay(duration, function()
			if my == token then
				set(false)
			end
		end)
	end)
end

-- จบคืน / เริ่มคืนใหม่: ฟ้าโปร่ง และยกเลิกฝนที่สุ่มไว้
function Weather.Reset()
	token += 1
	set(false)
end

return Weather
