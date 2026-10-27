-- Difficulty.luau — ระดับความยากที่เลือกในโซนสร้างห้องของ Lobby แล้วส่งไป place เกม (Pump Lot) ทาง TeleportData
-- ใช้ร่วมกันทั้ง 2 place (Lobby sync ไฟล์นี้ผ่าน lobby.project.json, เกม sync ทั้ง src/shared)
--
-- สัญญา TeleportData ที่ Lobby ส่งไป (อ่านฝั่งเกมด้วย player:GetJoinData().TeleportData):
--   { roomId = string, difficulty = "easy" | "normal" | "hard" | "nightmare", maxPlayers = 1..6, hostUserId = number }
--
-- reward = ตัวคูณเงินรางวัลตอนจบเกม (ยากมาก ได้มาก)
-- anomalyMult / incense = ค่าที่แนะนำให้ฝั่งเกมใช้ปรับความถี่ผี และจำนวนธูป (ชีวิตทีม)

local Difficulty = {}

Difficulty.MaxPlayers = 6
Difficulty.Default = "normal"
Difficulty.Order = { "easy", "normal", "hard", "nightmare" }

Difficulty.Levels = {
	easy = { th = "ง่าย", en = "Easy", reward = 1, anomalyMult = 0.8, incense = 4, color = Color3.fromRGB(120, 170, 110) },
	normal = { th = "ปกติ", en = "Normal", reward = 1.5, anomalyMult = 1, incense = 3, color = Color3.fromRGB(210, 180, 100) },
	hard = { th = "ยาก", en = "Hard", reward = 2, anomalyMult = 1.3, incense = 3, color = Color3.fromRGB(210, 120, 70) },
	nightmare = { th = "นรก", en = "Nightmare", reward = 3, anomalyMult = 1.6, incense = 2, color = Color3.fromRGB(190, 40, 40) },
}

function Difficulty.Get(id: string?)
	return Difficulty.Levels[id or ""] or Difficulty.Levels[Difficulty.Default]
end

function Difficulty.IsValid(id: any): boolean
	return type(id) == "string" and Difficulty.Levels[id] ~= nil
end

return Difficulty
