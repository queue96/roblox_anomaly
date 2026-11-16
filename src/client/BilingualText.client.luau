-- BilingualText.client.luau
-- ข้อความในฉากที่ Server ตั้งไว้ 2 ภาษา (shared/Bilingual) แสดงตามภาษาของผู้เล่นคนนี้
-- เช่น ป้ายมรณะของลูกค้าผี "น้องต้น / มรณะ 16 พ.ย. 2569" / "Ton / DIED 16 NOV 2026" (AnomalyManager Anomaly_Cemetery)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bilingual = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bilingual")) :: any
Bilingual.Run()
