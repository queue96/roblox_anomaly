--!strict
-- HeldItems.client.luau
-- ของในมือ (Tool จาก server/CoreLoop: แกลลอน FuelCan / ขนมตาลบนใบตอง ThaiDessert) อยู่ในมือตัวละครจริงทุกคน รวมตัวเราเอง
--   server เชื่อม Handle กับ HumanoidRootPart ด้วย Weld "VillagerGrip" ไว้ที่ตำแหน่งมือคร่าวๆ
--   เครื่องนี้เลื่อน C0 ทุกเฟรมให้ของตรงกำมือของกระดูกจริง (ท่าซ้อนจาก character/Animate):
--     FuelCan     ท่า carry_gallon_r มือขวาห้อยข้างตัว หูแกลลอนอยู่ในกำมือ ตัวแกลลอนห้อยลง
--     ThaiDessert ท่า hold_tray_r    มือขวาแบหงาย ใบตองขนมวางราบบนฝ่ามือ หันตามตัว
--   ไฟฉายอยู่มือซ้าย ถือพร้อมของในมือขวาได้ (ItemSlots / HUDController ย้าย Tool เข้าตัวเอง ไม่ใช้ EquipTool)
--   (ไฟฉายมีระบบของตัวเอง: HUDController / HeadTurnOthers)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadTurn = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeadTurn")) :: any
local PoseHooks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PoseHooks")) :: any

type Hold = { side: string, offset: CFrame, upright: boolean, palm: boolean? }
local HOLD: { [string]: Hold } = {
	-- จุดอ้างอิงของแกลลอน = กลางตัว, กลางคานหูหิ้วอยู่ที่ (0, 0.79, 0.15) -> เลื่อนตัวแกลลอนลงจากกำมือ
	FuelCan = { side = "R", offset = CFrame.new(0, -0.79, -0.15), upright = false },
	-- ขนมตาลบนใบตอง: จุดอ้างอิง = กลางใต้ใบ -> วางราบบนฝ่ามือที่แบหงาย (ยกเหนือกลางฝ่ามือ 0.17: ใบตองโมเดลนำเข้าไม่จมนิ้ว)
	ThaiDessert = { side = "R", offset = CFrame.new(0, 0.17, 0), upright = true, palm = true },
}

-- กลางฝ่ามือ (มือแบ): ระหว่างข้อมือกับโคนนิ้วกลาง
local function palmCenter(char: Model, side: string): Vector3?
	local function pos(n: string): Vector3?
		local b = char:FindFirstChild(n .. "." .. side, true)
		return if b and b:IsA("Bone") then b.TransformedWorldCFrame.Position else nil
	end
	local h, m = pos("hand"), pos("middle_01")
	if not (h and m) then
		return nil
	end
	return h:Lerp(m, 0.6)
end

local function place(char: Model, root: BasePart, tool: Tool, hold: Hold)
	local handle = tool:FindFirstChild("Handle")
	local weld = handle and handle:FindFirstChild("VillagerGrip")
	if not (weld and weld:IsA("Weld")) then
		return
	end
	local center, axis
	if hold.palm then
		center = palmCenter(char, hold.side)
		axis = Vector3.yAxis
	else
		center, axis = HeadTurn.grip(char, hold.side)
	end
	if not (center and axis) then
		return
	end
	local fwd = root.CFrame.LookVector
	local frame: CFrame
	if hold.upright then
		-- ของวางราบเสมอ (ขนมไม่หก) หันตามตัว
		frame = CFrame.lookAt(center, center + Vector3.new(fwd.X, 0, fwd.Z))
	else
		-- หูแกลลอนตามแนวกำมือ (นิ้วก้อย -> นิ้วชี้) ตัวแกลลอนห้อยตั้งตรง
		local a = Vector3.new(axis.X, 0, axis.Z)
		if a.Magnitude < 0.2 then
			a = Vector3.new(fwd.X, 0, fwd.Z)
		end
		frame = CFrame.lookAt(center, center + a)
	end
	local offset = tool:GetAttribute("GripOffset")
	local handleCF = frame * hold.offset * (if typeof(offset) == "CFrame" then offset else CFrame.new())
	weld.C0 = root.CFrame:ToObjectSpace(handleCF)
end

-- หลัง client/HumanEmotesRunner เขียนท่าถือ (แบมือ / หิ้วแกลลอน) ลงกระดูกเฟรมนี้แล้วเท่านั้น (shared/PoseHooks)
-- (เดิมต่อ PreSimulation แยก: ลำดับไม่แน่นอน บางเฟรมวางของตามมือท่าเดิน -> แกลลอนสั่น ขนมไม่อยู่ในมือ)
PoseHooks.After(function()
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if char and root and char:FindFirstChild("RootPart") then
			for name, hold in pairs(HOLD) do
				local tool = char:FindFirstChild(name)
				if tool and tool:IsA("Tool") then
					place(char, root, tool, hold)
				end
			end
		end
	end
end)
