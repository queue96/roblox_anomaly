-- Weather.luau (ModuleScript ฝั่ง Server)
-- ฝนตกเป็นช่วงๆ ระหว่างคืน: สถานะอยู่ที่ ReplicatedStorage.Remotes:GetAttribute("Weather") = "Clear" | "Rain"
--   Client (WeatherController) อ่านแล้วทำเม็ดฝน เสียงฝน พื้นเปียก แอ่งน้ำ
--   CoreLoop อ่าน Weather.IsRaining() เพื่อปรับลูกค้า (มาน้อยลง / เดินมากางร่ม / มาหลบฝน)
-- ทดสอบ: ServerStorage.DevDecision:Fire("rain") / Fire("clear")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = {}

Weather.Config = {
	ClearSpell = { 70, 150 }, -- ฟ้าโปร่งนานเท่านี้ก่อนลุ้นฝน (วินาที)
	RainChance = 0.45, -- ครบเวลาแล้วมีโอกาสฝนตกเท่านี้ (ไม่ตกก็รอรอบใหม่)
	RainSpell = { 80, 160 }, -- ฝนตกนานเท่านี้
}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local raining = false
local token = 0 -- เปลี่ยนเมื่อถูกสั่งจาก Dev (ตัดรอบสุ่มเดิม)

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

-- สุ่มฝนวนไปเรื่อยๆ ขณะที่ active() เป็นจริง (เช่น ร้านเปิดอยู่)
function Weather.Start(active: () -> boolean)
	remotes:SetAttribute("Weather", "Clear")
	task.spawn(function()
		while true do
			local my = token
			local wait = rand(if raining then Weather.Config.RainSpell else Weather.Config.ClearSpell)
			local t0 = os.clock()
			while os.clock() - t0 < wait and my == token do
				task.wait(1)
			end
			if my == token then
				if raining then
					set(false)
				elseif active() and math.random() < Weather.Config.RainChance then
					set(true)
				end
			end
		end
	end)
end

-- เริ่มคืนใหม่: ฟ้าโปร่ง
function Weather.Reset()
	token += 1
	set(false)
end

return Weather
