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
		-- ปิดวงแสงบาเรีย (ForceField) รอบตัวตอนเกิดทันที
		local ff = char:FindFirstChildOfClass("ForceField")
		if ff then
			ff:Destroy()
		end
		char.ChildAdded:Connect(function(c)
			if c:IsA("ForceField") then
				c:Destroy()
			end
		end)
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

-- ปิด ForceField ประจำจุดเกิดทุกจุดในแมพ
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") then
		d.Duration = 0
	end
end
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("SpawnLocation") then
		d.Duration = 0
	end
end)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local MapBuilder = require(Shared:WaitForChild("MapBuilder"):Clone())

-- 1. ถ้าใน Workspace มีฉากอยู่แล้ว จะไม่สั่ง Build() รีเซ็ตทับตำแหน่งที่คุณลากจัดวางด้วยมือ!
--    (จะสั่งสร้างใหม่อัตโนมัติเฉพาะกรณีที่ยังไม่มีโฟลเดอร์ MapEnvironment เท่านั้น)
if not Workspace:FindFirstChild("MapEnvironment") or not Workspace:FindFirstChild("InteractiveProps") then
	MapBuilder.Build()
end

-- (เดิมเรียก MapBuilder.SpreadBananaGrove() ตรงนี้ ซึ่งย้ายกอกล้วยกลับไปตำแหน่งตายตัวเดิมทุกครั้งที่กด Play
--  ตอนนี้จัดตำแหน่งไว้ในไฟล์ place แล้วด้วย MapBuilder.SpaceBananaGrove() — เว้นทางเดินไปเครื่องปั่นไฟ — จึงไม่ย้ายตอนเล่นอีก)

-- บังคับเปลี่ยนแสงเป็นตอนเที่ยงคืนมืดหลอนเฉพาะตอนกด Play เข้าเกม! (พอออกจากโหมด Play แมพจะกลับไปสว่างให้ Dev ง่ายๆ)
MapBuilder.SetNightLighting()

-- ปิดเงาใบไม้/ทุ่งนา/ต้นไม้ขอบแมพ, ลบสำเนาเก่าใน ServerStorage, ลบป้ายข้อความลอย และปรับสีต้นข้าวไม่ให้สะท้อนไฟฉายสว่างเกินไป
MapBuilder.OptimizeShadowsAndCleanup()
MapBuilder.RemoveZoneLabels()
MapBuilder.DarkenRiceAndFoliage()
MapBuilder.LabelKilometerPost() -- ข้อความหลักกิโล (กม. 67)

-- Performance (2026-11-07): ให้คนที่ตั้งกราฟิก Auto ได้ระดับสูงพอจะเห็นเงา
--   1) ไฟดวงเล็ก (ธูป / ตะเกียง) ไม่ทำเงา: เงาจากไฟวงเล็กแทบไม่เห็น แต่ทำเงาแบบไฟดวงใหญ่เท่ากัน (ไฟฉายทำเงาแทน)
--   2) ของตกแต่งใน MapEnvironment ไม่ต้องรับการชน (CanTouch) ไม่มีสคริปต์ไหนฟัง .Touched ของฉาก (เว้นเบาะนั่ง)
do
	local lightsOff, touchOff = 0, 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("Light") and d.Shadows and d.Parent then
			local n = d.Parent.Name
			if n == "StormLantern_Neon" or string.match(n, "^Incense%d*_Neon$") then
				d.Shadows = false
				lightsOff += 1
			end
		end
	end
	local env = Workspace:FindFirstChild("MapEnvironment")
	if env then
		for _, d in ipairs(env:GetDescendants()) do
			if d:IsA("BasePart") and d.CanTouch and not d:IsA("Seat") and not d:IsA("VehicleSeat") then
				d.CanTouch = false
				touchOff += 1
			end
		end
	end
	print(string.format("⚡ Performance: ปิดเงาไฟเล็ก %d ดวง · ปิด CanTouch ของตกแต่ง %d ชิ้น", lightsOff, touchOff))
end

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

-- พื้นไม้ในร้าน (PorchDeck โมเดลนำเข้า): ตัวชนแบบหยาบ (Default) ต่ำกว่าผิวไม้ที่มองเห็น 0.08-0.18 studs
-- คนยืนบนตัวชน เท้าเลยจมไม้นิดๆ (ผู้ใช้ 2026-11-06) -> แผ่นล่องหนบางๆ ทับพอดีผิวไม้ให้ยืน/ยิงหาพื้นแทน
-- (อยู่ใน ShackStructure + วัสดุ WoodPlanks: เสียงเท้ายังเป็นพื้นไม้ client/AmbienceController)
do
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure")
	local deck = shack and shack:FindFirstChild("PorchDeck", true) :: BasePart?
	if shack and deck and not shack:FindFirstChild("DeckWalkSurface") then
		-- วัดในเกม: บนพื้น Part ตัวละครยืนต่ำกว่าบนดิน (Terrain) ราว 0.07 -> ยกแผ่นเหนือขอบบนกล่องไม้ 0.05
		-- ปลายเท้าจึงวางพอดีผิวไม้ (เท่ากับตอนยืนบนดิน ปลายเท้าแตะพื้นพอดี)
		local DECK_SURFACE_ABOVE_TOP = 0.05
		local top = deck.Position.Y + deck.Size.Y / 2 + DECK_SURFACE_ABOVE_TOP
		local THICK = 0.2
		local p = Instance.new("Part")
		p.Name = "DeckWalkSurface"
		p.Size = Vector3.new(deck.Size.X, THICK, deck.Size.Z)
		p.CFrame = CFrame.new(deck.Position.X, top - THICK / 2, deck.Position.Z) * deck.CFrame.Rotation
		p.Anchored = true
		p.CanCollide = true
		p.CanQuery = true
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Material = Enum.Material.WoodPlanks
		p.Parent = shack
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
		task.wait(math.random(60, 120)) -- (เดิม 25-55 ถี่เกิน ผู้ใช้ 2026-11-05)
		-- กะพริบเบาๆ 1-2 ครั้ง นานๆ ที ไม่ให้ถี่จนลายตา (ไฟดับอยู่ = ไม่กะพริบ ไม่งั้นไฟจะกลับมาติดเอง)
		for _ = 1, if game:GetService("ReplicatedStorage"):GetAttribute("PowerOn") == false then 0 else math.random(1, 2) do
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
-- หน้าโหลดฝั่งผู้เล่นรอค่านี้: ฉาก ไฟร้าน และระบบเกมพร้อมแล้ว (LoadingScreen.client)
game:GetService("ReplicatedStorage"):SetAttribute("SceneReady", true)

print("✅ [Server] ปั๊มหลอดท้ายทุ่ง: โหลดฉาก + ไฟนีออนกะพริบ + Core Loop (รถลูกค้า เงินโควตา ธูป 3 ดอก) + พนมมือ เรียบร้อย!")
