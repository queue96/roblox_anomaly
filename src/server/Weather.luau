-- Weather.luau (ModuleScript ฝั่ง Server)
-- ตัดระบบฝนตกออกแล้ว (2026-11-16): คืนค่าสถานะฟ้าใส ("Clear") เสมอ

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weather = {}

Weather.Config = {
	RainNightChance = 0,
	RainStartAfter = { 180, 540 },
	RainDuration = { 240, 420 },
}

local remotes = ReplicatedStorage:WaitForChild("Remotes")

function Weather.IsRaining(): boolean
	return false
end

function Weather.Set(_rain: boolean)
	remotes:SetAttribute("Weather", "Clear")
end

function Weather.Start()
	remotes:SetAttribute("Weather", "Clear")
end

function Weather.BeginNight()
	remotes:SetAttribute("Weather", "Clear")
end

function Weather.Reset()
	remotes:SetAttribute("Weather", "Clear")
end

return Weather
