-- BilingualText.client.luau
-- ข้อความในฉากที่ Server ตั้งไว้ 2 ภาษา (shared/Bilingual) แสดงตามภาษาของผู้เล่นคนนี้
-- เช่น ป้ายทะเบียนผี "4444 ตาย" / "4444 DEAD" (AnomalyManager Anomaly_Cemetery)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bilingual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilingual")) :: any
Bilingual.Run()
