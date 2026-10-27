-- LobbyServer.server.luau
-- สคริปต์ฝั่ง Server ของ place "Lobby" (Start Place) — sync ผ่าน lobby.project.json พอร์ต 34873
-- หน้าที่ (ทำต่อ): โซนสร้างห้อง เลือกจำนวนผู้เล่น 1–6 + ความยาก -> นับถอยหลัง -> ReserveServer + TeleportAsync ไป place เกม

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- place แมพเกม (Pump Lot) ใน experience เดียวกัน
local GAME_PLACE_ID = 114125276809667

-- TeleportService ใช้ใน Studio ไม่ได้ ตอนเทสใน Studio ให้ print แทนการส่งผู้เล่นจริง
local IS_STUDIO = RunService:IsStudio()

-- บรรยากาศวัดร้างตอนเที่ยงคืน: ใช้แสงกลางคืนชุดเดียวกับแมพเกม แล้วกดให้ซีดและเย็นกว่า
local MapBuilder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapBuilder"):Clone())
MapBuilder.SetNightLighting()
-- แสงจันทร์จางๆ พอเห็นรูปทรงอาคารทั้งวัด (มืดกว่านี้แล้วกลางลานดำสนิท)
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(24, 28, 36)
Lighting.OutdoorAmbient = Color3.fromRGB(36, 42, 54)
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then
	atmo.Density = 0.45
	atmo.Haze = 2.2
	atmo.Color = Color3.fromRGB(95, 108, 120)
	atmo.Decay = Color3.fromRGB(36, 46, 58)
end
local grade = Lighting:FindFirstChild("LobbyGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "LobbyGrade"
grade.Saturation = -0.35
grade.Contrast = 0.12
grade.Brightness = -0.03
grade.TintColor = Color3.fromRGB(215, 225, 240)
grade.Parent = Lighting

print(("✅ [Lobby] Server พร้อม | ปลายทาง PlaceId %d | Studio = %s"):format(GAME_PLACE_ID, tostring(IS_STUDIO)))
