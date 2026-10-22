-- GrassWind.client.luau
-- กอหญ้าพริ้วตามลม (ทุกกอเอนไปทางเดียวกัน มีคลื่นลมวิ่งผ่านทุ่ง) และเอนหลบเมื่อมีคนเดินชน
-- ทำงานกับ Model ที่ติด CollectionService tag "WindSway" (ตั้งโดย MapBuilder.TagWindPlants)
-- ขยับเฉพาะฝั่ง Client เท่านั้น และอัปเดตเฉพาะกอที่อยู่ใกล้กล้อง เพื่อประหยัดเครื่อง

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "WindSway"
local WIND_DIR = Vector3.new(1, 0, 0.35).Unit -- ทิศลม (ทุกกอเอนไปทางนี้)
local WIND_SPEED = 1.6 -- ความเร็วการแกว่ง
local GUST_WAVE = 0.08 -- ความถี่คลื่นลมที่วิ่งผ่านทุ่ง (ต่อ stud)
local BASE_LEAN = math.rad(4) -- มุมเอนตามลมพื้นฐาน
local SWAY = math.rad(5) -- มุมแกว่งเพิ่มตามจังหวะลม
local PUSH_RADIUS = 3.5 -- ระยะที่ตัวละครเดินชนแล้วกอเอนหลบ
local PUSH_ANGLE = math.rad(32)
local ACTIVE_RANGE = 110 -- อัปเดตเฉพาะกอที่อยู่ในระยะนี้จากกล้อง
local UPDATE_HZ = 30

type Entry = { model: Model, base: CFrame, phase: number, amp: number, push: Vector3 }
local entries: { Entry } = {}
local byModel: { [Model]: Entry } = {}

local windAxis = Vector3.new(0, 1, 0):Cross(WIND_DIR) -- แกนหมุนที่ทำให้ยอดเอนไปตามลม

local function add(inst: Instance)
	if not inst:IsA("Model") or byModel[inst] then
		return
	end
	local pivot = inst:GetPivot()
	local e: Entry = {
		model = inst,
		base = pivot,
		phase = pivot.Position:Dot(WIND_DIR) * GUST_WAVE,
		amp = (inst:GetAttribute("SwayAmp") :: number?) or 1,
		push = Vector3.zero,
	}
	byModel[inst] = e
	table.insert(entries, e)
end

local function remove(inst: Instance)
	local e = byModel[inst :: Model]
	if not e then
		return
	end
	byModel[inst :: Model] = nil
	local i = table.find(entries, e)
	if i then
		table.remove(entries, i)
	end
end

for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	add(inst)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

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

local acc = 0
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
			local gust = 0.5 + 0.5 * math.sin(t * WIND_SPEED - e.phase) + 0.15 * math.sin(t * WIND_SPEED * 2.7 - e.phase * 1.7)
			local windAngle = (BASE_LEAN + SWAY * gust) * e.amp
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
			local rot = CFrame.fromAxisAngle(windAxis, windAngle)
			if e.push.Magnitude > 0.01 then
				local pushAxis = Vector3.new(0, 1, 0):Cross(e.push.Unit)
				rot = CFrame.fromAxisAngle(pushAxis, PUSH_ANGLE * e.push.Magnitude) * rot
			end
			e.model:PivotTo(CFrame.new(p) * rot * (e.base - p))
		end
	end
end)
