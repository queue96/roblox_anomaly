--!strict
-- GhostFloat.luau — ท่าลอยของผีที่ลอย (กระสือ ศพห่อผ้า กระหัง ผีเด็กร่อน ฯลฯ) ใช้ได้ทั้ง server และ client
-- ผู้ใช้ 2026-11-06: ลอยเป็นเส้นตรงช้าๆ เกินไป -> ต้องส่ายซ้ายขวา เอียงตัวตามทางส่าย ลอยขึ้นลง พุ่งเป็นพักๆ
-- และเร็วขึ้นตามความดุของรอบ (Remotes attribute "GhostFury" 0..1 จาก server/CoreLoop)
--
--   GhostFloat.Fury()                     ความดุตอนนี้ 0..1
--   GhostFloat.SpeedMult(fury?)           ตัวคูณความเร็วลอย (ดุมาก = เร็วมาก)
--   GhostFloat.Offset(seed, t, fwd, fury?) (เลื่อนตำแหน่ง, หมุนตัว) ทับตำแหน่งบนเส้นทาง (หน้า = fwd)
--                                          ส่ายข้าง + ขึ้นลง + เอียงตัวเข้าทางที่ส่าย + ก้มไปข้างหน้านิดๆ
--   GhostFloat.Surge(seed, t, fury?)      ตัวคูณความเร็วขณะนั้น (พุ่ง-ชะลอเป็นจังหวะ ไม่เรียบเท่ากันตลอด)
--   GhostFloat.Progress(seed, t, dur, fury?) ระยะทาง 0..1 ของเส้นทางยาว dur วินาที (เร็วตามความดุ + พุ่งเป็นพักๆ)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostFloat = {}

GhostFloat.Config = {
	SpeedMin = 1.35, -- ความดุ 0: เร็วกว่าเดิม (เดิมช้าเกิน)
	SpeedMax = 2.4, -- ความดุ 1
	Side = { 1.3, 2.8 }, -- ส่ายข้าง (studs) ความดุ 0 -> 1
	Bob = { 0.45, 0.8 }, -- ลอยขึ้นลง (studs)
	Roll = 14, -- เอียงตัวสุด (องศา) ตอนส่ายสุดทาง
	Lean = 8, -- ก้มตัวไปข้างหน้า (องศา) ตอนพุ่ง
}

local function lerp(r: { number }, k: number): number
	return r[1] + (r[2] - r[1]) * k
end

function GhostFloat.Fury(): number
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local v = remotes and remotes:GetAttribute("GhostFury")
	return if type(v) == "number" then math.clamp(v, 0, 1) else 0.3
end

function GhostFloat.SpeedMult(fury: number?): number
	local f = fury or GhostFloat.Fury()
	return GhostFloat.Config.SpeedMin + (GhostFloat.Config.SpeedMax - GhostFloat.Config.SpeedMin) * f
end

-- พุ่ง-ชะลอ: 0.55 .. 1.6 เท่า เปลี่ยนจังหวะไม่ซ้ำ (noise) ดุมาก = พุ่งแรงกว่า
function GhostFloat.Surge(seed: number, t: number, fury: number?): number
	local f = fury or GhostFloat.Fury()
	local n = math.noise(t * 0.55, seed * 0.37, 3.1) -- -0.5..0.5 ประมาณ
	return math.clamp(1 + n * (1.4 + f * 0.8), 0.55, 1.6 + f * 0.4)
end

-- ระยะ 0..1 บนเส้นทางที่เดิมใช้เวลา dur วินาที: เร็วขึ้นตามความดุ และพุ่งเป็นพักๆ (อินทิกรัลของ Surge แบบประมาณ)
function GhostFloat.Progress(seed: number, t: number, dur: number, fury: number?): number
	if dur <= 0 then
		return 1
	end
	local f = fury or GhostFloat.Fury()
	local base = t * GhostFloat.SpeedMult(f) / dur
	-- ส่วนพุ่ง/ชะลอ: เลื่อนไปมาไม่เกิน ~8% ของทาง (ไม่ถอยหลัง: ความชันรวมยังเป็นบวก)
	local wobble = math.noise(t * 0.45, seed * 0.37, 7.7) * 0.16 * math.min(1, t / 1.5)
	return math.clamp(base + wobble * math.min(1, base) * (1 - math.min(1, base)), 0, 1)
end

-- คืน (เลื่อนตำแหน่งในโลก, หมุนในกรอบตัวเอง) : cf = CFrame.lookAt(p + off, p + off + look) * rot
function GhostFloat.Offset(seed: number, t: number, fwd: Vector3, fury: number?): (Vector3, CFrame)
	local cfg = GhostFloat.Config
	local f = fury or GhostFloat.Fury()
	local flat = Vector3.new(fwd.X, 0, fwd.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local rate = 0.8 + f * 0.7
	-- ส่ายข้าง: sine หลักผสม noise (ไม่เป็นจังหวะเป๊ะ)
	local sidePhase = t * rate + seed
	local side = (math.sin(sidePhase) * 0.75 + math.noise(t * 0.6, seed, 1.3) * 0.6) * lerp(cfg.Side, f)
	-- ทิศที่กำลังส่ายไป (อนุพันธ์ของ sine): เอียงตัวเข้าไปทางนั้นเหมือนโฉบ
	local sideVel = math.cos(sidePhase)
	local up = math.sin(t * (1.5 + f * 0.6) + seed * 1.7) * lerp(cfg.Bob, f) + math.noise(t * 0.9, seed, 5.2) * 0.3
	local roll = math.rad(-sideVel * cfg.Roll * (0.7 + f * 0.5))
	-- ก้มไปข้างหน้ามากขึ้นตอนพุ่ง (noise ชุดเดียวกับ Surge)
	local lean = math.rad(-cfg.Lean * math.clamp(0.45 + math.noise(t * 0.55, seed * 0.37, 3.1) * 1.4, 0.15, 1))
	-- หมุนในกรอบของตัวเอง (หน้า = -Z): roll รอบแกนหน้า, lean รอบแกนข้าง
	return right * side + Vector3.new(0, up, 0), CFrame.Angles(lean, 0, roll)
end

return GhostFloat
