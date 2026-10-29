-- GrassWind.client.luau
-- ต้นไม้ใบหญ้าพริ้วตามลม (ทุกต้นเอนไปทางเดียวกัน มีคลื่นลมวิ่งผ่านทุ่ง) และเอนหลบเมื่อมีคนเดินชน
-- tag ตั้งโดย MapBuilder.TagWindPlants:
--   "WindSway"    = ทั้งต้นเอนจากโคน (กอหญ้า/ตะไคร้, แผ่นต้นข้าว, ต้นกล้วย, ต้นไม้ชายทุ่ง) ใช้ได้ทั้ง Model และ BasePart
--                   attribute: SwayAmp (แรงเอน, default 1), SwaySpeed (ความเร็ว, default 1), SwayPush = false (ไม่เอนหลบคน)
--   "LeafFlutter" = Model ที่เก็บแผ่นใบไม้ (BanyanLeaves / MangoLeaves): ลำต้นนิ่ง ใบไหวทีละใบ + ทั้งพุ่มโยกเบาๆ
-- ขยับเฉพาะฝั่ง Client เท่านั้น และอัปเดตเฉพาะต้นที่อยู่ใกล้กล้อง เพื่อประหยัดเครื่อง

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "WindSway"
local LEAF_TAG = "LeafFlutter"
local WIND_DIR = Vector3.new(1, 0, 0.35).Unit -- ทิศลม (ทุกกอเอนไปทางนี้)
local WIND_SPEED = 1.6 -- ความเร็วการแกว่ง
local GUST_WAVE = 0.08 -- ความถี่คลื่นลมที่วิ่งผ่านทุ่ง (ต่อ stud)
local BASE_LEAN = math.rad(4) -- มุมเอนตามลมพื้นฐาน
local SWAY = math.rad(5) -- มุมแกว่งเพิ่มตามจังหวะลม
local PUSH_RADIUS = 3.5 -- ระยะที่ตัวละครเดินชนแล้วกอเอนหลบ
local PUSH_ANGLE = math.rad(32)
local ACTIVE_RANGE = 85 -- อัปเดตเฉพาะกอที่อยู่ในระยะสายตากลางคืน (หมอกบังเกิน ~65 studs)
local UPDATE_HZ = 30
local LEAF_RANGE = 60 -- พุ่มใบไม้ใหญ่มีใบหลายพันแผ่น ขยับเฉพาะพุ่มใกล้กล้อง
local LEAF_HZ = 12 -- ใบไม้อัปเดตถี่น้อยกว่าหญ้า (ทดสอบแล้ว: ขยับใบทั้งแมพ ~6000 แผ่นที่ 30Hz ทำ FPS ตก 37 -> 28)
local LEAF_FLUTTER = math.rad(5) -- มุมไหวของใบแต่ละใบ
local LEAF_DRIFT = 0.35 -- ระยะ (studs) ที่ยอดพุ่มโยกไปตามลม

type Entry = {
	inst: PVInstance,
	base: CFrame,
	root: Vector3, -- จุดหมุน = โคนต้น (ก้น bounding box ตรงแนว pivot)
	phase: number,
	amp: number,
	speed: number,
	canPush: boolean,
	push: Vector3,
}
local entries: { Entry } = {}
local byInst: { [Instance]: Entry } = {}

type Leaf = { part: BasePart, base: CFrame, phase: number, axis: Vector3, height: number }
type LeafGroup = { model: Model, center: Vector3, phase: number, leaves: { Leaf } }
local leafGroups: { LeafGroup } = {}
local byLeafModel: { [Model]: LeafGroup } = {}

local windAxis = Vector3.new(0, 1, 0):Cross(WIND_DIR) -- แกนหมุนที่ทำให้ยอดเอนไปตามลม

local function add(inst: Instance)
	if not (inst:IsA("Model") or inst:IsA("BasePart")) or byInst[inst] then
		return
	end
	local pv = inst :: PVInstance
	local pivot = pv:GetPivot()
	local bottomY
	if inst:IsA("Model") then
		local cf, size = inst:GetBoundingBox()
		bottomY = cf.Position.Y - size.Y / 2
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
	else
		local part = inst :: BasePart
		part.CastShadow = false
		bottomY = math.min(pivot.Position.Y, part.Position.Y - part.Size.Y / 2)
	end
	local e: Entry = {
		inst = pv,
		base = pivot,
		root = Vector3.new(pivot.Position.X, bottomY, pivot.Position.Z),
		phase = pivot.Position:Dot(WIND_DIR) * GUST_WAVE,
		amp = (inst:GetAttribute("SwayAmp") :: number?) or 1,
		speed = (inst:GetAttribute("SwaySpeed") :: number?) or 1,
		canPush = inst:GetAttribute("SwayPush") ~= false,
		push = Vector3.zero,
	}
	byInst[inst] = e
	table.insert(entries, e)
end

local function remove(inst: Instance)
	local e = byInst[inst]
	if not e then
		return
	end
	byInst[inst] = nil
	local i = table.find(entries, e)
	if i then
		table.remove(entries, i)
	end
end

local function addLeaves(inst: Instance)
	if not inst:IsA("Model") or byLeafModel[inst] then
		return
	end
	local cf, size = inst:GetBoundingBox()
	local bottomY = cf.Position.Y - size.Y / 2
	local rng = Random.new(math.floor(cf.Position.X * 7 + cf.Position.Z * 13))
	local g: LeafGroup = {
		model = inst,
		center = cf.Position,
		phase = cf.Position:Dot(WIND_DIR) * GUST_WAVE,
		leaves = {},
	}
	for _, p in ipairs(inst:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CastShadow = false
			local flat = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			table.insert(g.leaves, {
				part = p,
				base = p.CFrame,
				phase = rng:NextNumber(0, math.pi * 2),
				axis = if flat.Magnitude > 0.01 then flat.Unit else windAxis,
				height = math.clamp((p.Position.Y - bottomY) / math.max(size.Y, 1), 0, 1),
			})
		end
	end
	byLeafModel[inst] = g
	table.insert(leafGroups, g)
end

local function removeLeaves(inst: Instance)
	local g = byLeafModel[inst :: Model]
	if not g then
		return
	end
	byLeafModel[inst :: Model] = nil
	local i = table.find(leafGroups, g)
	if i then
		table.remove(leafGroups, i)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
CollectionService:GetInstanceAddedSignal(LEAF_TAG):Connect(addLeaves)
CollectionService:GetInstanceRemovedSignal(LEAF_TAG):Connect(removeLeaves)

-- ทยอยลงทะเบียนต้นไม้และพุ่มใบไม้เป็นชุดๆ ตอนเริ่มเกม เพื่อไม่ให้เฟรมแรกสะดุดจากการคำนวณ GetBoundingBox พร้อมกันหลายร้อยต้น
task.spawn(function()
	for i, inst in ipairs(CollectionService:GetTagged(TAG)) do
		add(inst)
		if i % 60 == 0 then
			task.wait()
		end
	end
	for i, inst in ipairs(CollectionService:GetTagged(LEAF_TAG)) do
		addLeaves(inst)
		if i % 8 == 0 then
			task.wait()
		end
	end
end)

local function characterRoots(): { Vector3 }
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function gustAt(t: number, phase: number, speed: number): number
	local w = t * WIND_SPEED * speed
	return 0.5 + 0.5 * math.sin(w - phase) + 0.15 * math.sin(w * 2.7 - phase * 1.7)
end

local leafParts: { BasePart } = {}
local leafCFrames: { CFrame } = {}

local acc = 0
local leafAcc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 1 / UPDATE_HZ then
		return
	end
	local step = acc
	acc = 0
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	local roots = characterRoots()
	for _, e in ipairs(entries) do
		local p = e.base.Position
		if (p - camPos).Magnitude < ACTIVE_RANGE then
			-- ลม: เอนตามลมเสมอ + แกว่งตามคลื่นลม (เฟสตามตำแหน่ง = คลื่นวิ่งผ่านทุ่งทางเดียวกัน)
			local windAngle = (BASE_LEAN + SWAY * gustAt(t, e.phase, e.speed)) * e.amp
			local rot = CFrame.fromAxisAngle(windAxis, windAngle)
			if e.canPush then
				-- คนเดินชน: เอนหลบออกจากตัวละคร แล้วค่อย ๆ ตั้งกลับ
				local target = Vector3.zero
				for _, r in ipairs(roots) do
					local d = Vector3.new(p.X - r.X, 0, p.Z - r.Z)
					local dist = d.Magnitude
					if dist < PUSH_RADIUS and math.abs(p.Y - r.Y) < 6 then
						local away = if dist > 0.05 then d.Unit else WIND_DIR
						target += away * (1 - dist / PUSH_RADIUS)
					end
				end
				if target.Magnitude > 1 then
					target = target.Unit
				end
				local k = if target.Magnitude > e.push.Magnitude then 0.45 else 0.08 -- เอนเร็ว ตั้งกลับช้า
				e.push = e.push:Lerp(target, math.min(1, k * step * UPDATE_HZ))
				if e.push.Magnitude > 0.01 then
					local pushAxis = Vector3.new(0, 1, 0):Cross(e.push.Unit)
					rot = CFrame.fromAxisAngle(pushAxis, PUSH_ANGLE * e.push.Magnitude) * rot
				end
			end
			e.inst:PivotTo(CFrame.new(e.root) * rot * (e.base - e.root))
		end
	end

	-- พุ่มใบไม้ใหญ่: ใบแต่ละใบไหวคนละจังหวะ + ใบที่อยู่สูงโยกไปตามลมมากกว่า (ย้ายทีเดียวด้วย BulkMoveTo)
	leafAcc += step
	if leafAcc < 1 / LEAF_HZ then
		return
	end
	leafAcc = 0
	table.clear(leafParts)
	table.clear(leafCFrames)
	for _, g in ipairs(leafGroups) do
		if (g.center - camPos).Magnitude < LEAF_RANGE then
			local gust = gustAt(t, g.phase, 0.6)
			local drift = WIND_DIR * (LEAF_DRIFT * gust)
			for _, leaf in ipairs(g.leaves) do
				local flutter = math.sin(t * 3.1 + leaf.phase) * (0.55 + 0.45 * gust)
				local rot = CFrame.fromAxisAngle(leaf.axis, LEAF_FLUTTER * flutter)
				table.insert(leafParts, leaf.part)
				table.insert(leafCFrames, (leaf.base + drift * leaf.height) * rot)
			end
		end
	end
	if #leafParts > 0 then
		Workspace:BulkMoveTo(leafParts, leafCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
