--!strict
-- RiderMotion.client.luau — คนขับรถไม่แข็งทื่อ (ผู้ใช้ 2026-11-08: "โมเดลบางตัวดูแข็งๆ")
--   ฝั่งเครื่องผู้เล่นอย่างเดียว ไม่เพิ่มภาระเน็ต ตำแหน่งจริงฝั่ง Server ไม่เปลี่ยน
--   1) ตัวโยกตามรถ: เบรก = โน้มไปหน้า / ออกตัว = เอนหลังนิด + หายใจเบาๆ (หมุนทั้งตัวรอบข้อสะโพก)
--      หมุนแค่ RootPart (กระดูกทั้งชุดอยู่ใต้มัน ผิวตามกระดูก) เป้า IK มือ/เท้า (ชิ้น IKTargets) ไม่ขยับ
--      -> มือยังจับแฮนด์ เท้ายังอยู่ที่พักเท้า แขนขางอรับเอง
--   2) มอไซค์ 2 ล้อจอดนิ่ง: เท้าซ้ายลงแตะพื้น ตัวเอียงไปทางเท้านิดหนึ่ง ออกตัวแล้วยกเท้ากลับ
--   3) จอดอยู่: หันหน้ามองคนที่ยืนใกล้ๆ (คอ + หัว ผ่าน shared/HeadTurn ไม่แตะแขน)
--   คนขับ = vehicle.DriverNPC (attribute Human จาก server/HumanNPC.SeatIn) ในรถที่มี tag SmoothDrive
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DriveMotion = require(Shared:WaitForChild("DriveMotion")) :: any
-- (หันคอ/หัว: client/HumanEmotesRunner อ่าน attribute RiderLookYaw — ไม่เรียก shared/HeadTurn ตรงนี้แล้ว)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ---------------------------------------------------------------- ค่าปรับ
local LEAN_PER_ACCEL = 0.45 -- องศา ต่อ (studs/วิ²) เบรก = โน้มหน้า
local LEAN_FWD_MAX = 5
local LEAN_BACK_MAX = 3
local BREATH_DEG = 0.7 -- หายใจ (ก้ม-เงยเบาๆ)
local BREATH_HZ = 0.28
-- ปิดไว้ (ทดสอบใน Play 2026-11-08): เบาะมอไซค์สูงกว่าขา เท้าลงไม่ถึงพื้น ห้อยลอย 0.8-1.1 studs ดูแย่กว่าไม่ลง
--   จะเปิดต้องให้รถเอียง + เลื่อนก้นลงข้างเบาะด้วย (หรือเบาะเตี้ยลง)
local FOOT_DOWN = false
local FOOT_DELAY = 0.35 -- จอดนิ่งนานเท่านี้ค่อยวางเท้า
local FOOT_TIME = 0.4 -- วิ: วาง/ยกเท้า
local FOOT_SIDE = 1.05 -- studs: เท้าลงห่างกลางสะโพกไปทางซ้าย
local FOOT_FWD = 0.3 -- studs: เท้าลงหน้าสะโพก
local FOOT_ROLL = 3.5 -- องศา: ตัวเอียงไปทางเท้าที่ลงพื้น
local LOOK_RANGE = 24 -- studs: หันมองคนในระยะนี้
local LOOK_MAX = math.rad(50)
-- ผีที่เล่นกับคอ/หัวเอง: ไม่หันมอง (ไม่งั้นทับท่าผี)
local NO_LOOK = { Anomaly_NeckTwist = true, Anomaly_Headless = true, Anomaly_TaKhon = true, Anomaly_Krasue = true }

type Rider = {
	v: Model,
	d: Model,
	hipLocal: Vector3, -- จุดหมุน (ข้อสะโพก) เทียบ pivot รถ
	roots: { [BasePart]: CFrame }, -- RootPart (ตัวจริง + ร่างผีซ้อน) เทียบ pivot รถ ตอนยังไม่หมุน
	newRoots: { BasePart }, -- RootPart ที่เพิ่งเข้ามา: จำตำแหน่งในเฟรม render ถัดไป (เดิมไล่ GetDescendants ทุกเฟรม)
	conn: RBXScriptConnection?,
	lastPos: Vector3?,
	speed: number,
	accel: number,
	lean: number,
	still: number, -- จอดนิ่งมากี่วิ
	foot: number, -- 0 = บนที่พัก, 1 = แตะพื้น
	footAtt: Attachment?,
	footBase: Vector3?,
	footGround: Vector3?, -- ตำแหน่งเท้าบนพื้น (เทียบชิ้น IKTargets) ตอนจอดครั้งนี้
	twoWheel: boolean,
	seed: number,
	yaw: number,
}
local riders: { [Model]: Rider } = {}

local function hipsBone(d: Model): Bone?
	for _, b in ipairs(d:GetDescendants()) do
		if b:IsA("Bone") and b.Name == "hips" then
			return b
		end
	end
	return nil
end

local function attach(v: Model): Rider?
	local d = v:FindFirstChild("DriverNPC")
	if not (d and d:IsA("Model") and d:GetAttribute("Human") == true) then
		return nil
	end
	local hips = hipsBone(d)
	if not hips then
		return nil
	end
	local pv = v:GetPivot()
	local holder = d:FindFirstChild("IKTargets")
	local footAtt = holder and holder:FindFirstChild("footL")
	local r: Rider = {
		v = v,
		d = d,
		hipLocal = pv:PointToObjectSpace(hips.WorldPosition),
		roots = {},
		newRoots = {},
		conn = nil,
		lastPos = nil,
		speed = 0,
		accel = 0,
		lean = 0,
		still = 0,
		foot = 0,
		footAtt = if footAtt and footAtt:IsA("Attachment") then footAtt else nil,
		footBase = if footAtt and footAtt:IsA("Attachment") then footAtt.Position else nil,
		footGround = nil,
		twoWheel = d:GetAttribute("SeatClip") == "ride_moto" and #DriveMotion.WheelsOf(v) == 2,
		seed = math.random() * 10,
		yaw = 0,
	}
	-- คอ/หัวของตัวนี้ RiderMotion เป็นคนคิดมุมมอง (attribute RiderLookYaw) -> ชั้นมีชีวิตไม่สุ่มมองเอง (client/HumanEmotesRunner)
	--   สองระบบเขียนกระดูกเดียวกัน ในเฟรมที่ Animator ไม่อัปเดต ต่างคนเอาค่าของอีกฝ่ายเป็นฐาน = หัวหมุนสะสมแล้วดีดกลับ (กระตุก)
	d:SetAttribute("HeadByRider", true)
	-- RootPart (ตัวจริง + ร่างผีซ้อนที่ Server ใส่ทีหลัง): ฟังตอนเข้ามาแทนการไล่หาทุกเฟรม (Performance 2026-11-12)
	for _, p in ipairs(d:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "RootPart" then
			table.insert(r.newRoots, p)
		end
	end
	r.conn = d.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") and p.Name == "RootPart" then
			table.insert(r.newRoots, p)
		end
	end)
	return r
end

local function drop(v: Model)
	local r = riders[v]
	if r and r.conn then
		r.conn:Disconnect()
	end
	riders[v] = nil
end

local function watch(inst: Instance)
	if inst:IsA("Model") and not riders[inst] then
		local r = attach(inst)
		if r then
			riders[inst] = r
		end
	end
end
for _, v in ipairs(CollectionService:GetTagged(DriveMotion.TAG)) do
	watch(v)
end
CollectionService:GetInstanceAddedSignal(DriveMotion.TAG):Connect(watch)
-- คนขับมาทีหลังรถ (HumanNPC.SeatIn ใส่ DriverNPC ตอนสร้างรถ แต่รถอาจส่งมาก่อน): ลองใหม่เป็นระยะ
task.spawn(function()
	while true do
		task.wait(1)
		for _, v in ipairs(CollectionService:GetTagged(DriveMotion.TAG)) do
			local r = riders[v :: Model]
			if not r or not r.d.Parent or r.d.Parent ~= v then
				drop(v :: Model)
				watch(v)
			end
		end
	end
end)

local function ease(x: number): number
	return x * x * (3 - 2 * x)
end

-- หลังระบบขยับรถ (client/SmoothDrive: "SmoothDrive" = First, "NetSmooth" = First+1) ค่อยวางตัวคนขับทับ
RunService:BindToRenderStep("RiderMotion", Enum.RenderPriority.First.Value + 3, function(dt: number)
	if dt <= 0 then
		return
	end
	local now = os.clock()
	for v, r in pairs(riders) do
		if not (v.Parent and r.d.Parent == v) then
			drop(v)
			continue
		end
		local pv = v:GetPivot()
		-- RootPart ใหม่ (ร่างผีซ้อนที่ Server ใส่ทีหลัง): จำตำแหน่งเทียบรถตอนยังไม่หมุน
		if #r.newRoots > 0 then
			for _, p in ipairs(r.newRoots) do
				if p.Parent and not r.roots[p] then
					r.roots[p] = pv:ToObjectSpace(p.CFrame)
				end
			end
			table.clear(r.newRoots)
		end
		-- ความเร็ว / ความเร่งตามทิศหน้ารถ (กรองให้นุ่ม)
		local pos = pv.Position
		local last = r.lastPos
		r.lastPos = pos
		if last and (pos - last).Magnitude < 15 then
			local sp = (pos - last):Dot(pv.LookVector) / dt
			local prev = r.speed
			r.speed += (sp - r.speed) * (1 - math.exp(-dt * 8))
			r.accel += ((r.speed - prev) / dt - r.accel) * (1 - math.exp(-dt * 5))
		else
			r.speed, r.accel = 0, 0
		end
		local leanWant = math.clamp(-r.accel * LEAN_PER_ACCEL, -LEAN_BACK_MAX, LEAN_FWD_MAX)
		r.lean += (leanWant - r.lean) * (1 - math.exp(-dt * 4))
		local breath = BREATH_DEG * math.sin(now * BREATH_HZ * 2 * math.pi + r.seed)

		-- เท้าลงพื้นตอนจอด (มอไซค์ 2 ล้อ)
		local driving = v:GetAttribute("Driving") == true
		if not driving and math.abs(r.speed) < 0.3 then
			r.still += dt
		else
			r.still = 0
		end
		local footWant = if FOOT_DOWN and r.twoWheel and r.still > FOOT_DELAY then 1 else 0
		r.foot = math.clamp(r.foot + (if footWant > r.foot then dt else -dt) / FOOT_TIME, 0, 1)
		local att, base = r.footAtt, r.footBase
		if att and base and att.Parent and (att.Parent :: Instance):IsA("BasePart") then
			local holder = att.Parent :: BasePart
			if r.foot > 0 then
				if not r.footGround then
					local w = pv:PointToWorldSpace(r.hipLocal + Vector3.new(-FOOT_SIDE, 0, -FOOT_FWD))
					local gy = DriveMotion.Ground(w)
					r.footGround = holder.CFrame:PointToObjectSpace(Vector3.new(w.X, gy + 0.12, w.Z))
				end
				att.Position = base:Lerp(r.footGround :: Vector3, ease(r.foot))
			else
				r.footGround = nil
				if att.Position ~= base then
					att.Position = base
				end
			end
		end
		local roll = FOOT_ROLL * ease(r.foot)

		-- หมุนทั้งตัวรอบข้อสะโพก (ในกรอบรถ: ก้ม/เงย รอบแกนขวา, เอียงซ้าย รอบแกนหน้า)
		local rotLocal = CFrame.Angles(-math.rad(r.lean + breath), 0, math.rad(roll))
		local hipW = pv:PointToWorldSpace(r.hipLocal)
		local rotW = CFrame.new(hipW) * (pv.Rotation * rotLocal * pv.Rotation:Inverse()) * CFrame.new(-hipW)
		for p, rel in pairs(r.roots) do
			if p.Parent then
				p.CFrame = rotW * (pv * rel)
			else
				r.roots[p] = nil
			end
		end
	end
end)

-- หันมองคน (หลังท่าทาง + IK คำนวณเสร็จ: PreSimulation แบบเดียวกับ shared/HeadTurn)
RunService.PreSimulation:Connect(function(dt: number)
	local anomaly = remotes:GetAttribute("Anomaly")
	local blocked = type(anomaly) == "string" and NO_LOOK[anomaly] == true
	for v, r in pairs(riders) do
		local head: BasePart? = r.d:FindFirstChild("Head") :: BasePart?
		local want = 0
		if not blocked and r.still > 1 and head then
			local root = r.d:FindFirstChild("RootPart") :: BasePart?
			local best, bestD = nil :: Vector3?, LOOK_RANGE
			for _, pl in ipairs(Players:GetPlayers()) do
				local ch = pl.Character
				local h = ch and ch:FindFirstChild("Head") :: BasePart?
				if h then
					local dd = (h.Position - head.Position).Magnitude
					if dd < bestD then
						best, bestD = h.Position, dd
					end
				end
			end
			if best and root then
				local lp = v:GetPivot():VectorToObjectSpace(best - head.Position)
				want = math.clamp(math.atan2(-lp.X, -lp.Z), -LOOK_MAX, LOOK_MAX)
			end
		end
		r.yaw += (want - r.yaw) * (1 - math.exp(-dt * 3))
		-- หมุนคอ/หัวจริงที่ client/HumanEmotesRunner (shared/NpcLife riderYaw) เพื่อให้มีคนเขียนกระดูกคนเดียว
		--   (เดิม HeadTurn.apply ตรงนี้ + ท่าประกอบคำพูดของคนนั่งรถ = สองระบบเขียนคอ/หัว -> สะสมแล้วดีด)
		r.d:SetAttribute("RiderLookYaw", if math.abs(r.yaw) > 1e-3 then r.yaw else 0)
	end
end)
