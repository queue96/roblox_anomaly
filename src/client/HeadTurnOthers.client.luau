--!strict
-- HeadTurnOthers.client.luau
-- ผู้เล่นคนอื่นมองตามมุมกล้องของเขา: หัวหัน ลำตัวเอนตอนก้ม/เงย แขนไฟฉายชี้ตาม
--   (attribute "HeadYaw"/"HeadPitch" ของตัวละคร จาก server/PlayerVillager)
-- ตัวเราเอง: character/Animate ทำเอง (ไม่รอค่าจากเซิร์ฟเวอร์)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HeadTurn = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeadTurn")) :: any
local PoseHooks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PoseHooks")) :: any
local me = Players.LocalPlayer

type Shown = { yaw: number, pitch: number, aim: number }
local shown: { [Model]: Shown } = setmetatable({}, { __mode = "k" }) :: any

local function num(v: any): number
	return if type(v) == "number" then v else 0
end

-- ไฟฉายในมือของเขา (มือที่เขาเลือก): เลื่อน Weld "VillagerGrip" (server/Flashlight เชื่อมไว้กับ HumanoidRootPart)
-- ให้กระบอกลอดรูกำมือ (แขนชี้รูกำมือตามสายตาอยู่แล้ว) -> ลำแสง BeamLight ใน Handle ส่องไปทางที่เขามอง
local GRIP_BACK = 0.3 -- เหมือน HUDController.FLASHLIGHT_GRIP_BACK
local function placeFlashlight(char: Model)
	local tool = char:FindFirstChild("FrogFlashlight")
	local handle = tool and tool:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("VillagerGrip") :: Weld?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (grip and root) then
		return
	end
	local center, axis = HeadTurn.grip(char, (HeadTurn.Sides(char)), "flashlight")
	if not (center and axis) then
		return
	end
	axis = -axis -- จับจากด้านบน: หัวไฟโผล่ทางฝั่งนิ้วก้อย (shared/HeadTurn)
	local pos = center + axis * GRIP_BACK
	grip.C0 = root.CFrame:ToObjectSpace(CFrame.lookAt(pos, pos + axis))
end

-- หลัง client/HumanEmotesRunner เขียนท่าถือไฟฉาย (hold_flashlight_r) ลงกระดูกแล้ว ค่อยชี้แขนตามสายตา (shared/PoseHooks)
PoseHooks.After(function(dt)
	local k = math.min(1, dt * 10) -- ค่ามาเป็นช่วงๆ (~10 ครั้ง/วินาที): ไล่ตามนุ่มๆ
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		if p ~= me and char and char:FindFirstChild("RootPart") then
			local s = shown[char]
			if not s then
				s = { yaw = 0, pitch = 0, aim = 0 }
				shown[char] = s
			end
			-- ถือไฟฉายอยู่ (และไม่ได้พนมมือ) = ท่าถือไฟฉาย -> แขนชี้ตามสายตา
			local holding = char:FindFirstChild("FrogFlashlight") ~= nil and p:GetAttribute("Praying") ~= true
			s.yaw += (num(char:GetAttribute("HeadYaw")) - s.yaw) * k
			s.pitch += (num(char:GetAttribute("HeadPitch")) - s.pitch) * k
			s.aim += ((if holding then 1 else 0) - s.aim) * math.min(1, dt * 8)
			HeadTurn.apply(char, s.yaw, s.pitch, s.aim)
			if holding then
				placeFlashlight(char)
			end
		end
	end
end)
