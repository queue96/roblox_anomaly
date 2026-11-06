--!strict
-- HeldItems.client.luau
-- ของในมือ (Tool จาก server/CoreLoop: แกลลอน FuelCan / ขนมตาลบนใบตอง ThaiDessert) อยู่ในมือตัวละครจริงทุกคน รวมตัวเราเอง
--   server เชื่อม Handle กับ HumanoidRootPart ด้วย Weld "VillagerGrip" ไว้ที่ตำแหน่งมือคร่าวๆ
--   เครื่องนี้เลื่อน C0 ทุกเฟรมให้ของตรงกำมือของกระดูกจริง (ท่าซ้อนจาก character/Animate):
--     FuelCan     ท่า carry_gallon_l มือซ้ายห้อยข้างตัว หูแกลลอนอยู่ในกำมือ ตัวแกลลอนห้อยลง
--     ThaiDessert ท่า hold_tray_l    มือซ้ายแบหงาย ใบตองขนมวางราบบนฝ่ามือ หันตามตัว
--   ไฟฉายอยู่มือขวา ถือพร้อมของในมือซ้ายได้ (สลับมือ 2026-11-03) (ItemSlots / HUDController ย้าย Tool เข้าตัวเอง ไม่ใช้ EquipTool)
--   (ไฟฉายมีระบบของตัวเอง: HUDController / HeadTurnOthers)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadTurn = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeadTurn")) :: any
local PoseHooks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PoseHooks")) :: any

type Hold = { offset: CFrame, upright: boolean, palm: boolean? }
local HOLD: { [string]: Hold } = {
	-- จุดอ้างอิงของแกลลอน = กลางตัว, กลางคานหูหิ้วอยู่ที่ (0, 0.79, 0.15) -> เลื่อนตัวแกลลอนลงจากกำมือ
	FuelCan = { offset = CFrame.new(0, -0.79, -0.15), upright = false },
	-- ขนมตาลบนใบตอง: จุดอ้างอิง = กลางใต้ใบ -> วางราบบนฝ่ามือที่แบหงาย (ยกเหนือกลางฝ่ามือ 0.17: ใบตองโมเดลนำเข้าไม่จมนิ้ว)
	ThaiDessert = { offset = CFrame.new(0, 0.17, 0), upright = true, palm = true },
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
	local _, side = HeadTurn.Sides(char) -- มืออีกข้างจากไฟฉาย (ตั้งค่า: มือถือไฟฉาย)
	local center, axis
	if hold.palm then
		center = palmCenter(char, side)
		axis = Vector3.yAxis
	else
		center, axis = HeadTurn.grip(char, side, "fist")
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

-- ---------------------------------------------------------------- แกลลอนของลูกค้าเดินเท้า (server/Pedestrian, tag NpcGallon)
-- server วางแกลลอนไว้ที่มือซ้ายของ human_base ตายตัว -> ผู้หญิง/เด็ก/คนแก่ หรือแขนที่ขยับตามท่า มือไม่ตรงหู (ผู้ใช้ 2026-11-06)
-- เครื่องนี้ย้ายแกลลอนให้หูหิ้วอยู่ในกำมือซ้ายจริงทุกเฟรม แบบเดียวกับแกลลอนในมือผู้เล่น (HOLD.FuelCan)
local CollectionService = game:GetService("CollectionService")
type NpcCan = { parts: { BasePart }, rel: { CFrame }, handle: BasePart }
local npcCans: { [Instance]: NpcCan } = {}
local function npcCan(g: Instance): NpcCan?
	local c = npcCans[g]
	if c then
		return c
	end
	local handle = g:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		return nil
	end
	local parts, rel = {}, {}
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(rel, handle.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	c = { parts = parts, rel = rel, handle = handle }
	npcCans[g] = c
	return c
end
CollectionService:GetInstanceRemovedSignal("NpcGallon"):Connect(function(g)
	npcCans[g] = nil
end)
local function placeNpcGallons()
	for _, g in ipairs(CollectionService:GetTagged("NpcGallon")) do
		local owner = g.Parent
		local rig = owner and owner:FindFirstChild("DriverNPC")
		if not (rig and rig:IsA("Model") and g:IsDescendantOf(workspace)) then
			continue
		end
		local center, axis = HeadTurn.grip(rig, "L", "fist")
		local c = npcCan(g)
		if not (center and axis and c) then
			continue
		end
		local fwd = (owner :: Model):GetPivot().LookVector
		local a = Vector3.new(axis.X, 0, axis.Z)
		if a.Magnitude < 0.2 then
			a = Vector3.new(fwd.X, 0, fwd.Z)
		end
		local handleCF = CFrame.lookAt(center, center + a) * HOLD.FuelCan.offset
		local cfs = table.create(#c.parts)
		for i, r in ipairs(c.rel) do
			cfs[i] = handleCF * r
		end
		workspace:BulkMoveTo(c.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end
PoseHooks.After(placeNpcGallons)

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
