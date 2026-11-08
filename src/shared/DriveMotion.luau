--!strict
-- DriveMotion.luau (ReplicatedStorage.Shared) — รถลูกค้าขยับลื่นบนเครื่องผู้เล่น (ผู้ใช้ 2026-11-08: เล่นจริงรถขยับหน่วงๆ)
--   เดิม Server PivotTo รถทุกเฟรม: เล่นจริงตำแหน่งส่งถึงเครื่องผู้เล่นไม่ทุกเฟรมและไม่มีการเกลี่ย = ขยับเป็นช่วงๆ
--   ตอนนี้ Server บอกครั้งเดียวผ่าน attribute ของรถ (DriveFrom / DriveTo / DriveSpeed / DriveBrake / DriveT0 / DriveId)
--   แล้วรอจนครบเวลา -> PivotTo จุดปลายทีเดียว  ระหว่างทางเครื่องผู้เล่นขยับรถเอง (client/SmoothDrive) ด้วยสูตรเดียวกันนี้
--   ความเร็วแบบเบรก (brake) เท่าสูตรเดิมใน CoreLoop.driveTo: speed = max(3, min(speed, ระยะที่เหลือ × 1.6))
local Workspace = game:GetService("Workspace")

local DriveMotion = {}

DriveMotion.TAG = "SmoothDrive"

local K = 1.6 -- เบรก: ความเร็ว = ระยะที่เหลือ × K
local VMIN = 3 -- เบรก: ช้าสุด

-- ระยะที่เหลือ ณ เวลา t (วินาทีหลังเริ่ม)
function DriveMotion.Remaining(t: number, dist: number, speed: number, brake: boolean): number
	if t <= 0 then
		return dist
	end
	if not brake then
		return math.max(0, dist - speed * t)
	end
	if speed <= VMIN then
		return math.max(0, dist - VMIN * t)
	end
	local rA, rC = speed / K, VMIN / K
	if dist > rA then
		local tA = (dist - rA) / speed
		if t <= tA then
			return dist - speed * t
		end
		t -= tA
		dist = rA
	end
	if dist > rC then
		local tB = math.log(dist / rC) / K
		if t <= tB then
			return dist * math.exp(-K * t)
		end
		t -= tB
		dist = rC
	end
	return math.max(0, dist - VMIN * t)
end

-- เวลาที่ใช้ทั้งหมด (วินาที)
function DriveMotion.Duration(dist: number, speed: number, brake: boolean): number
	if not brake then
		return dist / math.max(speed, 0.01)
	end
	if speed <= VMIN then
		return dist / VMIN
	end
	local rA, rC = speed / K, VMIN / K
	local t = 0
	if dist > rA then
		t += (dist - rA) / speed
		dist = rA
	end
	if dist > rC then
		t += math.log(dist / rC) / K
		dist = rC
	end
	return t + dist / VMIN
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
function DriveMotion.Ground(p: Vector3): number
	local hit = Workspace:Raycast(Vector3.new(p.X, p.Y + 40, p.Z), Vector3.new(0, -80, 0), groundParams)
	return if hit then hit.Position.Y else p.Y
end

export type Drive = { from: Vector3, to: Vector3, dir: Vector3, dist: number, speed: number, brake: boolean, t0: number, dur: number, id: number }

-- อ่านการขี่รอบปัจจุบันจาก attribute ของรถ (ไม่มี = nil)
function DriveMotion.Read(v: Instance): Drive?
	local from, to = v:GetAttribute("DriveFrom"), v:GetAttribute("DriveTo")
	local speed, t0, id = v:GetAttribute("DriveSpeed"), v:GetAttribute("DriveT0"), v:GetAttribute("DriveId")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(speed) ~= "number" or type(t0) ~= "number" or type(id) ~= "number" then
		return nil
	end
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 0.01 then
		return nil
	end
	local brake = v:GetAttribute("DriveBrake") == true
	return { from = from, to = to, dir = flat.Unit, dist = dist, speed = speed, brake = brake, t0 = t0, dur = DriveMotion.Duration(dist, speed, brake), id = id }
end

-- ตำแหน่งรถ ณ เวลา elapsed: (CFrame, ระยะที่ไปแล้ว)
function DriveMotion.PoseAt(d: Drive, elapsed: number): (CFrame, number)
	local s = d.dist - DriveMotion.Remaining(math.min(elapsed, d.dur), d.dist, d.speed, d.brake)
	if elapsed >= d.dur then
		s = d.dist
	end
	local p = d.from + d.dir * s
	p = Vector3.new(p.X, DriveMotion.Ground(p), p.Z)
	return CFrame.lookAt(p, p + d.dir), s
end

-- Server: ตำแหน่งจริงของรถตอนนี้ (ระหว่างขี่ ตัวรถฝั่ง Server ยังอยู่จุดเริ่ม) ใช้กับของที่ต้องตามรถ เช่น คนเดิน/เต้นตามรถแห่
function DriveMotion.LivePivot(v: Model): CFrame
	local d = DriveMotion.Read(v)
	if d and v:GetAttribute("Driving") == true then
		local cf = DriveMotion.PoseAt(d, Workspace:GetServerTimeNow() - d.t0)
		return cf
	end
	return v:GetPivot()
end

-- ล้อของรถ: แม่แบบเก่า (FrontWheel / RearWheel / SidecarWheel) และรถไทย (ทุกชิ้นใน Model "Wheels" ทุกชั้น)
function DriveMotion.WheelsOf(v: Instance): { BasePart }
	local list = {}
	for _, n in ipairs({ "FrontWheel", "RearWheel", "SidecarWheel" }) do
		local w = v:FindFirstChild(n)
		if w and w:IsA("BasePart") then
			table.insert(list, w)
		end
	end
	for _, group in ipairs(v:GetDescendants()) do
		if group.Name == "Wheels" and group:IsA("Model") then
			for _, d in ipairs(group:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(list, d)
				end
			end
		end
	end
	return list
end

-- หมุนล้อตามระยะที่ไป step (studs) รอบแกนขวางของรถ / รัศมีล้อแต่ละวง
function DriveMotion.SpinWheels(wheels: { BasePart }, right: Vector3, step: number)
	for _, w in ipairs(wheels) do
		if w.Parent then
			local r = math.max(w.Size.Y, w.Size.Z) / 2
			local c = w.Position
			w.CFrame = CFrame.new(c) * CFrame.fromAxisAngle(right, -step / math.max(r, 0.2)) * (w.CFrame - c)
		end
	end
end

return DriveMotion
