-- GameManager.server.luau
-- สคริปต์ควบคุมระบบหลักฝั่ง Server ของเกม "ปั๊มหลอด & เพิงปะยางท้ายทุ่ง"

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local MapBuilder = require(Shared:WaitForChild("MapBuilder"))

-- 1. สร้างและตกแต่งฉาก 3D แบบละเอียด (Detailed Map) อัตโนมัติ
MapBuilder.Build()

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

-- 3. ทดสอบระบบดึงเชือกปิดแผงสังกะสีหน้าร้าน (RejectRope -> ShutterDoor)
local interactive = Workspace:WaitForChild("InteractiveProps")
local shutterDoor = interactive:WaitForChild("ShutterDoor") :: Part
local rejectRope = interactive:WaitForChild("RejectRope") :: Part
local rejectPrompt = rejectRope:WaitForChild("RejectCustomerPrompt") :: ProximityPrompt

local isShutterBusy = false
rejectPrompt.Triggered:Connect(function(player)
	if isShutterBusy then
		return
	end
	isShutterBusy = true

	print("🚧 [" .. player.Name .. "] ดึงเชือกปิดแผงสังกะสีหน้าร้าน!")
	local closedPos = Vector3.new(shutterDoor.Position.X, shutterDoor:GetAttribute("ClosedY") or 6, shutterDoor.Position.Z)
	local openPos = Vector3.new(shutterDoor.Position.X, shutterDoor:GetAttribute("OpenY") or 15.5, shutterDoor.Position.Z)

	-- เลื่อนแผงสังกะสีลงมาปิดร้าน
	local closeTween = TweenService:Create(shutterDoor, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = closedPos,
	})
	closeTween:Play()
	closeTween.Completed:Wait()

	task.wait(3) -- ปิดร้านกันผีไว้ 3 วินาทีแล้วเปิดกลับขึ้นไป

	local openTween = TweenService:Create(shutterDoor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = openPos,
	})
	openTween:Play()
	openTween.Completed:Wait()

	isShutterBusy = false
end)

print("✅ [Server] ปั๊มหลอดท้ายทุ่ง: โหลดฉาก Greybox + ไฟนีออนกะพริบ + เชือกดึงแผงสังกะสี เรียบร้อย!")
