-- LobbyClient.client.luau
-- สคริปต์ฝั่ง Client ของ place "Lobby" — sync ผ่าน lobby.project.json พอร์ต 34873
-- หน้าที่ (ทำต่อ): UI ใน Lobby เช่น ปุ่มสลับภาษา TH/EN, นับถอยหลังท้ายกระบะ, สมุดสะสมผี

local Players = game:GetService("Players")

print("✅ [Lobby] Client พร้อม: " .. Players.LocalPlayer.Name)
