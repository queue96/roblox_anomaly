-- GameManager.server.luau
-- สคริปต์ควบคุมระบบหลักฝั่ง Server ของเกม "ปั๊มหลอด & เพิงปะยางท้ายทุ่ง"

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- บังคับมุมมองบุคคลที่ 1 (First-Person), ล็อกห้ามกระโดด และปรับความเร็วเดินให้ช้าลงเข้ากับบรรยากาศสยองขวัญ
local WALK_SPEED = 10
StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
StarterPlayer.CharacterWalkSpeed = WALK_SPEED
StarterPlayer.CharacterJumpPower = 0
StarterPlayer.CharacterJumpHeight = 0

local function applyCharacterMovement(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.WalkSpeed = WALK_SPEED
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
end

local function setupPlayer(p: Player)
	p.CameraMode = Enum.CameraMode.LockFirstPerson
	if p.Character then
		task.spawn(applyCharacterMovement, p.Character)
	end
	p.CharacterAdded:Connect(applyCharacterMovement)
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local MapBuilder = require(Shared:WaitForChild("MapBuilder"):Clone())

-- 1. ถ้าใน Workspace มีฉากอยู่แล้ว จะไม่สั่ง Build() รีเซ็ตทับตำแหน่งที่คุณลากจัดวางด้วยมือ!
--    (จะสั่งสร้างใหม่อัตโนมัติเฉพาะกรณีที่ยังไม่มีโฟลเดอร์ MapEnvironment เท่านั้น)
if not Workspace:FindFirstChild("MapEnvironment") or not Workspace:FindFirstChild("InteractiveProps") then
	MapBuilder.Build()
end

-- กระจายกอกล้วยด้านหลังร้านไม่ให้กระจุกแออัดอยู่จุดเดียว
MapBuilder.SpreadBananaGrove()

-- บังคับเปลี่ยนแสงเป็นตอนเที่ยงคืนมืดหลอนเฉพาะตอนกด Play เข้าเกม! (พอออกจากโหมด Play แมพจะกลับไปสว่างให้ Dev ง่ายๆ)
MapBuilder.SetNightLighting()

-- ปิดเงาใบไม้/ทุ่งนา/ต้นไม้ขอบแมพ, ลบสำเนาเก่าใน ServerStorage, ลบป้ายข้อความลอย และปรับสีต้นข้าวไม่ให้สะท้อนไฟฉายสว่างเกินไป
MapBuilder.OptimizeShadowsAndCleanup()
MapBuilder.RemoveZoneLabels()
MapBuilder.DarkenRiceAndFoliage()

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
	local neonPart = dirtRoad:WaitForChild("NeonLightPart") :: BasePart
	local flickerLight = neonPart:WaitForChild("FlickerLight") :: PointLight

	-- บังคับเปิดไฟเสาไม้หน้าร้านตั้งแต่เริ่มเกม และไม่ให้ตัวโคมเสาไฟบังแสงตัวเอง
	neonPart.CastShadow = false
	neonPart.Material = Enum.Material.Neon
	neonPart.Color = Color3.fromRGB(255, 240, 200)
	local pole = dirtRoad:FindFirstChild("WoodenPole")
	if pole and pole:IsA("BasePart") then
		pole.CastShadow = false
	end
	flickerLight.Enabled = true
	flickerLight.Brightness = 2.2
	flickerLight.Range = 52

	while true do
		task.wait(math.random(25, 55))
		-- กะพริบเบาๆ 1-2 ครั้ง นานๆ ที ไม่ให้ถี่จนลายตา
		for _ = 1, math.random(1, 2) do
			flickerLight.Enabled = true
			flickerLight.Brightness = 0.35
			neonPart.Color = Color3.fromRGB(90, 85, 70)
			task.wait(0.06)
			flickerLight.Enabled = true
			flickerLight.Brightness = 2.2
			neonPart.Color = Color3.fromRGB(255, 240, 200)
			task.wait(0.08)
		end
	end
end)

-- 3. Phase 3 Core Loop: รถลูกค้าขี่มาจอด, เติมน้ำมัน/ดึงแผงปิดร้าน (เชือก RejectRope -> ShutterDoor), เงิน 500฿, ธูป 3 ดอก
--    รายละเอียดอยู่ใน CoreLoop.luau (ModuleScript ในโฟลเดอร์เดียวกัน)
local CoreLoop = require(script.Parent:WaitForChild("CoreLoop"))
CoreLoop.Start()

print("✅ [Server] ปั๊มหลอดท้ายทุ่ง: โหลดฉาก + ไฟนีออนกะพริบ + Core Loop (รถลูกค้า เงินโควตา ธูป 3 ดอก) + พนมมือ เรียบร้อย!")
