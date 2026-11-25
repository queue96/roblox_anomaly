-- SmoothDrive.client.luau — รถลูกค้าขยับลื่นบนเครื่องผู้เล่นเอง (ผู้ใช้ 2026-11-08: เล่นจริงรถขยับหน่วงๆ แปลกๆ)
--   Server (CoreLoop.driveTo) บอกการขี่ครั้งเดียวผ่าน attribute ของรถ แล้ว PivotTo จุดปลายตอนครบเวลา
--   ที่นี่ขยับรถทุกเฟรมตามสูตรเดียวกัน (shared/DriveMotion) + หมุนล้อ  ภาพลื่นเท่ากันทุกเครื่อง ไม่ขึ้นกับเน็ต
--   เริ่มนับจากตอนที่เครื่องนี้ได้รับคำสั่ง (หักเวลาเดินทางของเน็ตออกสูงสุด 0.5 วิ) รถจึงไม่กระโดดไปข้างหน้าตอนออกตัว
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DriveMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DriveMotion")) :: any

type State = { drive: any, lag: number, lastS: number, wheels: { BasePart }, scanAt: number, done: boolean, holdUntil: number, held: { [BasePart]: CFrame }, base: CFrame, seed: number, odo0: number }
local states: { [Model]: State } = {}

local function start(v: Model)
	local d = DriveMotion.Read(v)
	if not d then
		states[v] = nil
		return
	end
	local cur = states[v]
	if cur and cur.drive.id == d.id then
		return
	end
	-- เน็ตส่งคำสั่งมาช้าเท่าไหร่ ให้เริ่มช้าเท่านั้น (ไม่เกิน 0.5 วิ) / โมเดลเพิ่งส่งมากลางทาง = ตามไปตำแหน่งปัจจุบันเลย
	local late = Workspace:GetServerTimeNow() - d.t0
	local lag = if late <= 0.5 then math.max(0, late) else 0
	states[v] = { drive = d, lag = lag, lastS = 0, wheels = DriveMotion.WheelsOf(v), scanAt = os.clock() + 0.4, done = false, holdUntil = 0, held = if cur then cur.held else {}, base = v:GetPivot(), seed = (cur and cur.seed) or math.random() * 100, odo0 = if cur then cur.odo0 + cur.lastS else 0 }
end

local function watch(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local v = inst :: Model
	start(v)
	v:GetAttributeChangedSignal("DriveId"):Connect(function()
		start(v)
	end)
	v.AncestryChanged:Connect(function()
		if not v:IsDescendantOf(Workspace) then
			states[v] = nil
		end
	end)
end

for _, v in ipairs(CollectionService:GetTagged(DriveMotion.TAG)) do
	watch(v)
end
CollectionService:GetInstanceAddedSignal(DriveMotion.TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(DriveMotion.TAG):Connect(function(v)
	states[v :: Model] = nil
end)

-- ความรู้สึกถนนดิน (ผู้ใช้ 2026-11-08: ลื่นแล้วแต่ดู "ไถ" ไปกับพื้น): ขยับเรียบเป๊ะเกินไป ไม่มีอะไรบอกว่าวิ่งบนดินขรุขระ
--   1) เงย/ก้มตามพื้นหน้า-หลังรถ  2) โยกขึ้นลงเบาๆ ตามระยะทาง (โช้ค)  3) รถ 2 ล้อเอียงซ้ายขวานิดๆ
--   แรงตามความเร็วตอนนั้น (ใกล้หยุด = แทบไม่โยก) ผลอยู่บนเครื่องนี้อย่างเดียว ตำแหน่งจริงฝั่ง Server ไม่เปลี่ยน
local PITCH_SPAN = 1.3 -- studs: วัดพื้นหน้า/หลังจุดกลางรถ
local PITCH_MAX = math.rad(10)
local BOB_AMP = 0.07 -- studs ตอนวิ่งเต็มความเร็ว
local ROLL_AMP = math.rad(1.8) -- รถ 2 ล้อ
local FULL_SPEED = 10 -- studs/วิ ที่ถือว่าเต็มแรง

local function roadFeel(v: Model, st: State, cf: CFrame, s: number, speed: number): CFrame
	local k = math.clamp(speed / FULL_SPEED, 0, 1)
	local p, dir = cf.Position, cf.LookVector
	local front = DriveMotion.Ground(p + dir * PITCH_SPAN)
	local back = DriveMotion.Ground(p - dir * PITCH_SPAN)
	local pitch = math.clamp(math.atan2(front - back, PITCH_SPAN * 2), -PITCH_MAX, PITCH_MAX)
	local seed = st.seed
	local bob = (math.noise(s * 0.45, seed) * 0.8 + math.sin(s * 2.4) * 0.2) * BOB_AMP * k
	local roll = if #st.wheels <= 2 then math.noise(s * 0.18, seed + 7.3) * ROLL_AMP * (0.4 + 0.6 * k) else 0
	local wheelieLift = 0
	if v:GetAttribute("Wheelie") == true and st.drive.dist > 1 then
		local prog = math.clamp(s / st.drive.dist, 0, 1)
		if prog > 0.24 and prog < 0.74 then
			local w = (prog - 0.24) / 0.50
			local env = if w < 0.22 then math.sin((w / 0.22) * (math.pi / 2))
				elseif w > 0.78 then math.sin(((1 - w) / 0.22) * (math.pi / 2))
				else 1
			wheelieLift = env * math.rad(25)
		end
	end
	return cf * CFrame.new(0, bob + math.sin(wheelieLift) * 1.8, 0) * CFrame.Angles(pitch + wheelieLift, 0, roll)
end

RunService:BindToRenderStep("SmoothDrive", Enum.RenderPriority.First.Value, function(dt: number)
	local now = Workspace:GetServerTimeNow()
	for v, st in pairs(states) do
		if st.done then
			-- จอดแล้ว: ตำแหน่งจาก Server มาทับล้อให้กลับมุมเดิม (ล้อดีดตอนรถหยุด) คงมุมที่หมุนมาถึงไว้
			if st.holdUntil > 0 and v.Parent then
				local pv = v:GetPivot()
				for w, rel in pairs(st.held) do
					if w.Parent then
						w.CFrame = pv * rel
					end
				end
				if os.clock() > st.holdUntil then
					st.holdUntil = 0
				end
			end
			continue
		end
		if not v.Parent then
			states[v] = nil
			continue
		end
		local d = st.drive
		local elapsed = now - d.t0 - st.lag
		local cf, s = DriveMotion.PoseAt(d, elapsed)
		local step = s - st.lastS
		st.lastS = s
		local placed = cf
		if elapsed >= d.dur then
			-- จุดปลาย: วางตรงกับที่ Server วาง (ไม่โยก ไม่เอียง) ไม่ให้กระตุกตอนตำแหน่ง Server มาถึง
			st.done = true
		else
			placed = roadFeel(v, st, cf, st.odo0 + s, if dt > 0 then step / dt else 0)
		end
		-- มุมล้อเก็บไว้ฝั่งเรา (เทียบตัวรถ) วางใหม่ทุกเฟรม: ตำแหน่งล้อจาก Server (ไม่หมุน) มาทับตอนใกล้จอด = ล้อดีดหนึ่งครั้ง
		local pv0 = v:GetPivot()
		for _, w in ipairs(st.wheels) do
			if not st.held[w] then
				-- ล้อที่เน็ตเพิ่งส่งมากลางทางอยู่ที่จุดออกตัวของ Server: เทียบกับตัวรถตอนออกตัวแทน
				local a, b = pv0:ToObjectSpace(w.CFrame), st.base:ToObjectSpace(w.CFrame)
				st.held[w] = if a.Position.Magnitude <= b.Position.Magnitude then a else b
			end
		end
		v:PivotTo(placed)
		-- เน็ตส่งตัวรถมาก่อนล้อ: หาใหม่ช่วงแรกของเที่ยว (เดิมหาครั้งเดียวตอนออกตัว = ล้อไม่หมุนทั้งเที่ยว)
		if st.scanAt > 0 and os.clock() > st.scanAt then
			st.wheels = DriveMotion.WheelsOf(v)
			st.scanAt = if elapsed < 4 or #st.wheels == 0 then os.clock() + 0.5 else 0
		end
		for w, rel in pairs(st.held) do
			if w.Parent then
				if step > 0 then
					rel = CFrame.new(rel.Position) * CFrame.Angles(-DriveMotion.SpinAngle(w, step), 0, 0) * rel.Rotation
					st.held[w] = rel:Orthonormalize()
				end
				w.CFrame = placed * rel
			end
		end
		if st.done then
			st.holdUntil = os.clock() + 2
		end
	end
	-- ตัวละครที่ยึดกับรถ (คัทซีนซ้อนท้ายพี่ชาย: server/Cutscene CutscenePin) วางตามรถบนเครื่องนี้
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local pin = char and char:FindFirstChild("CutscenePin")
		if pin and pin:IsA("CFrameValue") then
			local veh = pin:FindFirstChild("Vehicle")
			local v = veh and (veh :: ObjectValue).Value
			local root = (char :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
			if v and v:IsA("Model") and v.Parent and root and root.Anchored then
				root.CFrame = v:GetPivot() * pin.Value
			end
		end
	end
end)

-- ---------------------------------------------------------------- ของอื่นที่ Server ขยับเองทุกเฟรม (shared/NetSmooth)
-- คนเดิน ผีเดินมาซื้อ ผีวนร้าน/บนหลังคา ขบวนผีใหญ่ โลง คนตามรถแห่: Server ส่งตำแหน่งทั้งก้อน 20 ครั้ง/วิ
-- ที่นี่วาดย้อนหลัง NetSmooth.DELAY วิ เกลี่ยระหว่างตำแหน่งที่ได้รับ (เน็ตส่งมาไม่สม่ำเสมอก็ยังลื่น)
local NetSmooth = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetSmooth")) :: any
type Snap = { t: number, cf: CFrame }
local bufs: { [Model]: { Snap } } = setmetatable({}, { __mode = "k" }) :: any
local STEP = 1 / NetSmooth.RATE
-- เวลาวาดย้อนหลัง ปรับเองตามเน็ตของเครื่องนี้ (2026-11-25): ตำแหน่งมาช้าเท่าไหร่ ย้อนเผื่อเท่านั้น + SLACK
--   เพิ่มเร็ว (เน็ตแย่ลง = กันค้าง) ลดช้าๆ (เน็ตดีขึ้น) และเลื่อนทีละนิดทุกเฟรม ภาพจึงไม่กระโดดตอนปรับ
local delay: number = NetSmooth.DELAY
local ageTop = 0 -- ความช้าช่วงแย่ล่าสุด (วิ)
local drawn: { [Model]: { at: number, cf: CFrame } } = setmetatable({}, { __mode = "k" }) :: any -- ท่าล่าสุดที่วาดจริง
-- ล้อจักรยานที่คนเข็น (PushedBicycle): Server ส่งตำแหน่งล้อ (ไม่หมุน) มาทับตลอด จึงเก็บมุมสะสมไว้แล้ววางใหม่ทุกครั้งที่วาด
type PushWheel = { part: BasePart, rel: CFrame, angle: number }
local pushed: { [Model]: { PushWheel } } = setmetatable({}, { __mode = "k" }) :: any
local function spinPushed(m: Model, cf: CFrame, prev: CFrame?)
	local list = pushed[m]
	if not list then
		local bike = m:FindFirstChild("PushedBicycle")
		local wheels = if bike then DriveMotion.WheelsOf(bike) else {}
		if #wheels == 0 then
			return
		end
		list = {}
		for _, w in ipairs(wheels) do
			table.insert(list, { part = w, rel = cf:ToObjectSpace(w.CFrame), angle = 0 })
		end
		pushed[m] = list
	end
	local step = if prev then (cf.Position - prev.Position):Dot(cf.LookVector) else 0
	if step > 3 then
		step = 0 -- วาร์ป
	end
	for _, w in ipairs(list) do
		if w.part.Parent then
			if step > 0.001 then
				w.angle = (w.angle + DriveMotion.SpinAngle(w.part, step)) % (2 * math.pi)
			end
			local at = cf * w.rel
			w.part.CFrame = CFrame.new(at.Position) * CFrame.fromAxisAngle(cf.RightVector, -w.angle) * at.Rotation
		end
	end
end

local function draw(m: Model, cf: CFrame)
	m:PivotTo(cf)
	local d = drawn[m]
	if m:FindFirstChild("PushedBicycle") then
		spinPushed(m, cf, if d and os.clock() - d.at < 0.3 then d.cf else nil)
	end
	if d then
		d.at, d.cf = os.clock(), cf
	else
		drawn[m] = { at = os.clock(), cf = cf }
	end
end

-- คนเดินทางตรง (NetSmooth.Walk): เดินเองจากเส้นทาง
type Walk = { id: number, from: Vector3, to: Vector3, dir: Vector3, dist: number, speed: number, t0: number, dur: number, lag: number, prev: any, blendAt: number?, blendPos: Vector3, blendRot: CFrame, dead: boolean }
local walks: { [Model]: Walk } = {}
local walkers: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local TURN_RATE = 10 -- คนเดินถึงแล้วหันหน้า (Pedestrian.Face หันทันที): ค่อยๆ หันบนเครื่องนี้
local BLEND = 0.25 -- วิ: หันตัว/ไหลเข้าเส้นทางใหม่

local function startWalk(m: Model)
	local from, to = m:GetAttribute("WalkFrom"), m:GetAttribute("WalkTo")
	local speed, t0, id = m:GetAttribute("WalkSpeed"), m:GetAttribute("WalkT0"), m:GetAttribute("WalkId")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(speed) ~= "number" or type(t0) ~= "number" or type(id) ~= "number" then
		return
	end
	local cur = walks[m]
	if cur and cur.id == id then
		return
	end
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 0.02 or speed <= 0 then
		return
	end
	local dur = dist / speed
	local late = Workspace:GetServerTimeNow() - t0
	if late > dur + 1 then
		return -- เดินจบไปนานแล้ว (เพิ่งเห็นตัวนี้)
	end
	-- คำสั่งมาช้าเท่าไหร่ เริ่มช้าเท่านั้น · เพิ่งเห็นกลางทาง = ตามไปตำแหน่งปัจจุบัน · เดินต่อจากทางเดิม = ช้าไม่น้อยกว่าทางเดิม
	local lag = if late <= 0.5 then math.max(0, late) else 0
	local prev: any = nil
	if cur and not cur.dead and t0 - (cur.t0 + cur.dur) < 0.3 then
		lag = math.max(lag, cur.lag)
		prev = cur
		cur.prev = nil
	end
	walks[m] = { id = id, from = from, to = to, dir = flat.Unit, dist = dist, speed = speed, t0 = t0, dur = dur, lag = lag, prev = prev, blendAt = nil, blendPos = Vector3.zero, blendRot = CFrame.identity, dead = false }
end

local function walkPoint(w: Walk, t: number): Vector3
	return w.from + w.dir * math.clamp(t * w.speed, 0, w.dist)
end

-- วาดตามเส้นทาง คืน true = เส้นทางคุมอยู่ (อย่าให้การเกลี่ยตำแหน่งทับ)
local function drawWalk(m: Model, w: Walk, now: number, rt: number): boolean
	local b = bufs[m]
	local last = b and b[#b]
	-- ตำแหน่งจริงไม่ตรงเส้นทาง (มีอย่างอื่นย้ายตัวนี้): เลิกใช้เส้นทาง กลับไปเกลี่ยตำแหน่ง
	if last and last.t > w.t0 + 0.2 and last.t < w.t0 + w.dur then
		local p = walkPoint(w, last.t - w.t0) - last.cf.Position
		if Vector3.new(p.X, 0, p.Z).Magnitude > 2.5 then
			w.dead = true
			return false
		end
	end
	local elapsed = now - w.t0 - w.lag
	if elapsed < 0 and w.prev then
		return drawWalk(m, w.prev, now, -math.huge)
	end
	w.prev = nil
	if elapsed >= w.dur and rt >= w.t0 + w.dur then
		return false -- ถึงแล้ว และตำแหน่งที่เกลี่ยก็ถึงแล้ว: ส่งต่อให้การเกลี่ย (หันหน้า ฯลฯ)
	end
	local p = walkPoint(w, elapsed)
	p = Vector3.new(p.X, DriveMotion.Ground(p), p.Z)
	local rot = CFrame.lookAt(Vector3.zero, w.dir)
	if not w.blendAt then
		local d = drawn[m]
		local shown = if d and os.clock() - d.at < 0.3 then d.cf else m:GetPivot()
		local off = shown.Position - p
		w.blendAt = os.clock()
		w.blendPos = if off.Magnitude < 4 then off else Vector3.zero
		w.blendRot = shown.Rotation
	end
	local a = math.clamp((os.clock() - (w.blendAt :: number)) / BLEND, 0, 1)
	a = a * a * (3 - 2 * a)
	draw(m, CFrame.new(p + w.blendPos * (1 - a)) * w.blendRot:Lerp(rot, a))
	return true
end

local function watchWalk(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local m = inst :: Model
	walkers[m] = true
	startWalk(m)
	m:GetAttributeChangedSignal("WalkId"):Connect(function()
		startWalk(m)
	end)
end
for _, m in ipairs(CollectionService:GetTagged(NetSmooth.WALK_TAG)) do
	watchWalk(m)
end
CollectionService:GetInstanceAddedSignal(NetSmooth.WALK_TAG):Connect(watchWalk)
CollectionService:GetInstanceRemovedSignal(NetSmooth.WALK_TAG):Connect(function(m)
	walks[m :: Model] = nil
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(NetSmooth.REMOTE, 60)
	if not (remote and remote:IsA("UnreliableRemoteEvent")) then
		return
	end
	remote.OnClientEvent:Connect(function(t: number, batch: { any })
		if type(t) ~= "number" or type(batch) ~= "table" then
			return
		end
		local age = math.clamp(Workspace:GetServerTimeNow() - t, 0, NetSmooth.DELAY_MAX)
		ageTop += (age - ageTop) * (if age > ageTop then 0.5 else 0.01)
		for i = 1, #batch - 1, 2 do
			local m, cf = batch[i], batch[i + 1]
			if typeof(m) == "Instance" and m:IsA("Model") and typeof(cf) == "CFrame" then
				local b = bufs[m]
				if not b then
					b = {}
					bufs[m] = b
				end
				local last = b[#b]
				if not last or t - last.t > 0.5 then
					-- เริ่มขยับใหม่ (นิ่งมานาน / เพิ่งเห็นครั้งแรก): เริ่มเกลี่ยจากตำแหน่งที่เห็นอยู่ตอนนี้
					local from = if last then last.cf else m:GetPivot()
					table.clear(b)
					table.insert(b, { t = t - STEP, cf = from })
				elseif (cf.Position - last.cf.Position).Magnitude > 25 then
					-- วาร์ป: ไม่ลากผ่านกลางทาง
					table.clear(b)
					table.insert(b, { t = t - STEP, cf = cf })
				end
				local tail = b[#b]
				if t > tail.t then -- ข้อความมาสลับลำดับ (unreliable): ทิ้งอันเก่า
					table.insert(b, { t = t, cf = cf })
				end
				while #b > 12 do
					table.remove(b, 1)
				end
			end
		end
	end)
end)

RunService:BindToRenderStep("NetSmooth", Enum.RenderPriority.First.Value + 1, function(dt: number)
	local want = math.clamp(ageTop + NetSmooth.DELAY_SLACK, NetSmooth.DELAY_MIN, NetSmooth.DELAY_MAX)
	delay += math.clamp(want - delay, -0.03 * dt, 0.3 * dt)
	local now = Workspace:GetServerTimeNow()
	local rt = now - delay
	local walking: { [Model]: boolean } = {}
	for m, w in pairs(walks) do
		if not m.Parent then
			walks[m] = nil
		elseif not NetSmooth.Nested(m) and drawWalk(m, w, now, rt) then
			walking[m] = true
		else
			walks[m] = nil
		end
	end
	for m, b in pairs(bufs) do
		if walking[m] then
			continue
		end
		if not m.Parent then
			bufs[m] = nil
			continue
		end
		local last = b[#b]
		if not last then
			bufs[m] = nil
			continue
		end
		local st = states[m]
		if st and (not st.done or st.drive.t0 >= last.t - 0.01) then
			continue -- รถกำลังขี่ / ขี่รอบใหม่หลังตำแหน่งล่าสุด (ระบบ DriveMotion ด้านบนคุม ไม่ดึงกลับไปที่เก่า)
		end
		if rt > last.t + 1.5 and walkers[m] and not NetSmooth.Nested(m) then
			-- ลูกค้ายืนรอ: คงท่าไว้ตลอด ตอนออกเดินใหม่ตำแหน่งจาก Server มาถึงก่อนคำสั่งเดินได้ ไม่งั้นแวบไปข้างหน้า/หันพรึ่บหนึ่งเฟรม
			local keep = drawn[m]
			local cur = m:GetPivot()
			if keep and (cur.Position - last.cf.Position).Magnitude < 4 then
				keep.at = os.clock()
				keep.cf = last.cf
				if not cur:FuzzyEq(last.cf, 1e-4) then
					draw(m, last.cf)
				end
				continue
			end
		end
		if rt > last.t + 1.5 then
			-- นิ่งมานานแล้ว: เลิกวาดทับ (ตำแหน่งจาก Server เท่ากับอันสุดท้ายอยู่แล้ว)
			bufs[m] = nil
			continue
		end
		if NetSmooth.Nested(m) then
			continue
		end
		local pose: CFrame
		if rt >= last.t then
			pose = last.cf
		elseif rt <= b[1].t then
			pose = b[1].cf
		else
			pose = last.cf
			for i = #b - 1, 1, -1 do
				local a = b[i]
				if a.t <= rt then
					local c = b[i + 1]
					pose = a.cf:Lerp(c.cf, (rt - a.t) / math.max(c.t - a.t, 1e-3))
					break
				end
			end
		end
		local d = drawn[m]
		if walkers[m] and d and os.clock() - d.at < 0.3 then
			pose = CFrame.new(pose.Position) * d.cf.Rotation:Lerp(pose.Rotation, 1 - math.exp(-TURN_RATE * dt))
		end
		draw(m, pose)
	end
end)
