-- GameManager.server.luau
-- สคริปต์ควบคุมระบบหลักฝั่ง Server ของเกม "ปั๊มหลอด & เพิงปะยางท้ายทุ่ง"

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local MapBuilder = require(Shared:WaitForChild("MapBuilder"):Clone())

-- 1. ถ้าใน Workspace มีฉากอยู่แล้ว จะไม่สั่ง Build() รีเซ็ตทับตำแหน่งที่คุณลากจัดวางด้วยมือ!
--    (จะสั่งสร้างใหม่อัตโนมัติเฉพาะกรณีที่ยังไม่มีโฟลเดอร์ MapEnvironment เท่านั้น)
if not Workspace:FindFirstChild("MapEnvironment") or not Workspace:FindFirstChild("InteractiveProps") then
	MapBuilder.Build()
end

-- บังคับเปลี่ยนแสงเป็นตอนเที่ยงคืนมืดหลอนเฉพาะตอนกด Play เข้าเกม! (พอออกจากโหมด Play แมพจะกลับไปสว่างให้ Dev ง่ายๆ)
MapBuilder.SetNightLighting()

-- ซ่อนจุดมาร์คของรถตอนเล่น: SpawnPoint (เขียว) / StopPoint (เหลือง) / ExitPoint (แดง)
-- เป็นตัวช่วยของ Dev: ระบบรถยังใช้ตำแหน่งได้ตามปกติ, ตอน Edit ยังมองเห็น
do
	local waypoints = Workspace:FindFirstChild("VehicleWaypoints")
	if waypoints then
		for _, d in ipairs(waypoints:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
				d.CastShadow = false
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				d.Enabled = false
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			end
		end
	end
end

-- 2. เอฟเฟกต์ไฟนีออนเสาไม้หน้าร้านกะพริบติดๆ ดับๆ (สร้างบรรยากาศหลอนชนบท)
task.spawn(function()
	local dirtRoad = Workspace:WaitForChild("MapEnvironment"):WaitForChild("DirtRoad")
	local neonPart = dirtRoad:WaitForChild("NeonLightPart")
	local flickerLight = neonPart:WaitForChild("FlickerLight") :: PointLight

	while true do
		task.wait(math.random(3, 8))
		-- กะพริบ 2-3 ครั้ง
		for _ = 1, math.random(2, 4) do
			flickerLight.Brightness = 0.2
			neonPart.Color = Color3.fromRGB(90, 85, 70)
			task.wait(0.07)
			flickerLight.Brightness = 1.8
			neonPart.Color = Color3.fromRGB(255, 240, 200)
			task.wait(0.09)
		end
	end
end)

-- 3. Phase 3 Core Loop: รถลูกค้าขี่มาจอด, เติมน้ำมัน/ดึงแผงปิดร้าน (เชือก RejectRope -> ShutterDoor), เงิน 500฿, ธูป 3 ดอก
--    รายละเอียดอยู่ใน CoreLoop.luau (ModuleScript ในโฟลเดอร์เดียวกัน)
local CoreLoop = require(script.Parent:WaitForChild("CoreLoop"))
CoreLoop.Start()

print("✅ [Server] ปั๊มหลอดท้ายทุ่ง: โหลดฉาก + ไฟนีออนกะพริบ + Core Loop (รถลูกค้า เงิน 500฿ ธูป 3 ดอก) เรียบร้อย!")
