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

type State = { drive: any, lag: number, lastS: number, wheels: { BasePart }, done: boolean, seed: number, odo0: number }
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
	states[v] = { drive = d, lag = lag, lastS = 0, wheels = DriveMotion.WheelsOf(v), done = false, seed = (cur and cur.seed) or math.random() * 100, odo0 = if cur then cur.odo0 + cur.lastS else 0 }
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
	return cf * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll)
end

RunService:BindToRenderStep("SmoothDrive", Enum.RenderPriority.First.Value, function(dt: number)
	local now = Workspace:GetServerTimeNow()
	for v, st in pairs(states) do
		if st.done then
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
		v:PivotTo(placed)
		if step > 0 then
			-- หมุนรอบแกนเพลาจริงของรถตอนนี้ (รวมเอียง) ไม่งั้นล้อค่อยๆ บิดเบี้ยวสะสม
			DriveMotion.SpinWheels(st.wheels, placed.RightVector, step)
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

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild(NetSmooth.REMOTE, 60)
	if not (remote and remote:IsA("UnreliableRemoteEvent")) then
		return
	end
	remote.OnClientEvent:Connect(function(t: number, batch: { any })
		if type(t) ~= "number" or type(batch) ~= "table" then
			return
		end
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

RunService:BindToRenderStep("NetSmooth", Enum.RenderPriority.First.Value + 1, function()
	local rt = Workspace:GetServerTimeNow() - NetSmooth.DELAY
	for m, b in pairs(bufs) do
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
		m:PivotTo(pose)
	end
end)
