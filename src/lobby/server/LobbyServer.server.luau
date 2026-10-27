-- LobbyServer.server.luau
-- สคริปต์ฝั่ง Server ของ place "Lobby" (Start Place) — sync ผ่าน lobby.project.json พอร์ต 34873
-- หน้าที่ (ทำต่อ): รวมผู้เล่น 1–4 คนท้ายกระบะ -> นับถอยหลัง -> ReserveServer + TeleportAsync ไป place เกม

local RunService = game:GetService("RunService")

-- place แมพเกม (Pump Lot) ใน experience เดียวกัน
local GAME_PLACE_ID = 114125276809667

-- TeleportService ใช้ใน Studio ไม่ได้ ตอนเทสใน Studio ให้ print แทนการส่งผู้เล่นจริง
local IS_STUDIO = RunService:IsStudio()

print(("✅ [Lobby] Server พร้อม | ปลายทาง PlaceId %d | Studio = %s"):format(GAME_PLACE_ID, tostring(IS_STUDIO)))
