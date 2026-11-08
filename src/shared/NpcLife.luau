--!strict
-- NpcLife.luau — ชั้น "มีชีวิต" ซ้อนบนท่าของ Animator ให้ NPC ชาวบ้านไม่แข็งทื่อ (ผู้ใช้ 2026-11-08: "แอนิเมชั่นมันแข็งมากๆ")
--   ท่าเดิมจาก build_anims.py ขยับน้อยมาก (ยืน: อก 1.2° / นั่งมอไซค์: หันหัว 4°) เป็นคลื่นเดียว ลูปสั้น ทุกตัวพร้อมกัน
--   ชั้นนี้เติม (สุ่มต่อตัว ไม่มีใครเหมือนกัน):
--     หายใจ: อก หลัง ไหล่ขึ้นลง (คลื่น 2 ความถี่ ไม่เป็นจังหวะเป๊ะ)
--     มองไปมา: หันไปจุดใหม่ ค้าง 1.5-5 วิ แล้วหันต่อ (บางครั้งมองผู้เล่นที่อยู่ใกล้) คอ/หัวตามอกช้ากว่า
--     ถ่ายน้ำหนัก (ยืนนิ่ง): สะโพกเอียง ขาข้างที่พักงอเข่า ค้างแล้วสลับข้าง
--     ขยับเล็กๆ นานๆ ครั้ง: ยักไหล่ เอียงคอ ก้มมอง ยืดคอ
--   นั่งรถ (attribute SeatClip) หรือตัวที่ RiderMotion ดูแล (attribute HeadByRider เช่นลูกค้าเดินมาเติม): ไม่แตะคอ/หัว
--   (client/RiderMotion หันมองคนเองผ่าน shared/HeadTurn: กระดูกเดียวต้องมีคนเขียนคนเดียว)
-- คืนค่า: { [ชื่อกระดูก] = CFrame หมุนในพิกัดโลก } ให้ client/HumanEmotesRunner คูณทับท่าฐาน (แบบเดียวกับ shared/HeadTurn: ไม่พึ่งแกนกระดูก)
local M = {}

M.RANGE = 70 -- studs จากกล้อง: ไกลกว่านี้ไม่คำนวณ
local rad = math.rad

type Life = {
	rng: Random,
	breathHz: number,
	breathPh: number,
	breathAmp: number,
	gYaw: number, gPitch: number, -- มองอยู่
	tYaw: number, tPitch: number, -- เป้าที่จะหันไป
	nextGlance: number,
	shift: number, tShift: number, nextShift: number,
	settle: number, tSettle: number, nextSettle: number,
	fidget: string?, fidgetT0: number, nextFidget: number,
	energy: number,
}
local lives: { [Model]: Life } = setmetatable({}, { __mode = "k" }) :: any

local function lifeOf(m: Model, now: number): Life
	local L = lives[m]
	if L then
		return L
	end
	local rng = Random.new()
	local char = m:GetAttribute("Char")
	-- คนแก่ขยับช้าและน้อยกว่า เด็กขยับมากกว่า
	local energy = if type(char) == "string" and string.find(char, "elder") then 0.7 elseif char == "human_child" then 1.25 else 1.0
	L = {
		rng = rng,
		breathHz = rng:NextNumber(0.2, 0.3) * (if energy > 1 then 1.2 else 1),
		breathPh = rng:NextNumber(0, math.pi * 2),
		breathAmp = rng:NextNumber(0.85, 1.25),
		gYaw = 0, gPitch = 0, tYaw = 0, tPitch = 0,
		nextGlance = now + rng:NextNumber(0.5, 3),
		shift = 0, tShift = rng:NextNumber(-1, 1), nextShift = now + rng:NextNumber(2, 6),
		settle = 0, tSettle = 0, nextSettle = now + rng:NextNumber(3, 8),
		fidget = nil, fidgetT0 = 0, nextFidget = now + rng:NextNumber(5, 14),
		energy = energy,
	}
	lives[m] = L
	return L
end

-- ไล่ค่าเข้าหาเป้าแบบนุ่ม (เร็วตอนแรก ช้าลงตอนใกล้ = เหมือนคนหัน)
local function approach(cur: number, target: number, rate: number, dt: number): number
	return cur + (target - cur) * (1 - math.exp(-rate * dt))
end

-- ท่าขยับเล็กๆ: ซองคลื่น ขึ้น-ค้าง-ลง (0..1)
local function envelope(x: number, dur: number): number
	if x <= 0 or x >= dur then
		return 0
	end
	local a = math.min(x / (dur * 0.3), 1)
	local b = math.min((dur - x) / (dur * 0.35), 1)
	local s = math.min(a, b)
	return s * s * (3 - 2 * s)
end

local FIDGETS = { shrug = 1.3, tilt = 2.2, lookdown = 2.6, neck = 1.8 }
local FIDGET_LIST = { "shrug", "tilt", "lookdown", "neck" }

-- m = NPC, root = RootPart, now = เวลา (วิ), dt, opts: seated, moving, emoteW (0..1), camPos, lookAt (ตำแหน่งที่น่ามอง เช่นหัวผู้เล่นใกล้ๆ)
function M.Offsets(m: Model, root: BasePart, now: number, dt: number, opts: { seated: boolean, noHead: boolean?, riderYaw: any?, moving: boolean, still: number?, emoteW: number, lookAt: Vector3? }): { [string]: CFrame }
	local L = lifeOf(m, now)
	local rng = L.rng
	local out: { [string]: CFrame } = {}
	local cf = root.CFrame
	local up, right, look = cf.UpVector, cf.RightVector, cf.LookVector
	local calm = 1 - math.clamp(opts.emoteW, 0, 1) -- เล่นท่าอารมณ์อยู่: เหลือแค่หายใจ
	local e = L.energy
	local still = math.clamp(opts.still or (if opts.moving then 0 else 1), 0, 1) -- 1 = ยืนนิ่ง (ไล่นุ่มๆ จาก client/HumanEmotesRunner)

	-- ---------------------------------------------------------------- หายใจ (คลื่นหลัก + คลื่นเร็วกว่าเล็กน้อย ไม่ซ้ำจังหวะเป๊ะ)
	local w = math.pi * 2 * L.breathHz
	local br = math.sin(w * now + L.breathPh) * 0.8 + math.sin(w * 2.37 * now + L.breathPh * 1.7) * 0.2
	br *= L.breathAmp * (0.5 + 0.5 * still)
	local function add(bone: string, axis: Vector3, deg: number)
		if math.abs(deg) < 1e-3 then
			return
		end
		local r = CFrame.fromAxisAngle(axis, rad(deg))
		out[bone] = if out[bone] then r * out[bone] else r
	end
	add("chest", right, 1.8 * br) -- หายใจเข้า: อกยกเชิดนิดๆ
	add("spine", right, 0.7 * br)
	add("shoulder.L", look, 1.4 * br) -- ไหล่ยกขึ้นตอนหายใจเข้า (หมุนรอบแกนหน้า: บวก = ไหล่ซ้ายขึ้น)
	add("shoulder.R", look, -1.4 * br)

	-- คนที่ RiderMotion ดูแล: หันมองผู้เล่นตามมุมที่ RiderMotion คิด (คอ 0.4 หัว 0.6 แบบ shared/HeadTurn) เขียนที่นี่ที่เดียว
	if type(opts.riderYaw) == "number" and math.abs(opts.riderYaw) > 1e-3 then
		add("neck", up, math.deg(opts.riderYaw) * 0.4)
		add("head", up, math.deg(opts.riderYaw) * 0.6)
	end

	if calm <= 0.01 then
		return out
	end

	-- ---------------------------------------------------------------- ขยับตัวให้นั่ง/ยืนสบาย (เอนหน้าหลังเล็กน้อย ค้างนานๆ)
	if now >= L.nextSettle then
		L.tSettle = rng:NextNumber(-1, 1)
		L.nextSettle = now + rng:NextNumber(4, 10)
	end
	L.settle = approach(L.settle, L.tSettle, 1.2, dt)
	add("spine", right, -2.2 * L.settle * calm * e)
	add("chest", up, 2.5 * L.settle * calm)

	-- ---------------------------------------------------------------- มองไปมา (ไม่ใช่คนนั่งรถ: RiderMotion หันหัวเอง)
	if not (opts.seated or opts.noHead) then
		if now >= L.nextGlance then
			local r = rng:NextNumber()
			if opts.lookAt and r < 0.45 then
				-- มองผู้เล่นที่อยู่ใกล้ (มุมในกรอบตัว)
				local head = root.Position + up * 2.2
				local d = cf:VectorToObjectSpace(opts.lookAt - head)
				L.tYaw = math.clamp(math.atan2(-d.X, -d.Z), rad(-55), rad(55))
				L.tPitch = math.clamp(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)), rad(-20), rad(15))
			elseif r < 0.75 then
				L.tYaw = rng:NextNumber(-1, 1) * rad(40)
				L.tPitch = rng:NextNumber(-12, 6) * math.pi / 180
			else
				L.tYaw = rng:NextNumber(-0.15, 0.15) -- มองตรงไปข้างหน้า
				L.tPitch = 0
			end
			L.nextGlance = now + rng:NextNumber(1.5, 5) / e
		end
		local rate = if opts.moving then 2.5 else 4
		L.gYaw = approach(L.gYaw, L.tYaw, rate * e, dt)
		L.gPitch = approach(L.gPitch, L.tPitch, rate * e, dt)
		local gy, gp = L.gYaw * calm, L.gPitch * calm
		-- อกหันส่วนหนึ่ง คอ หัว รับที่เหลือ (หัวนำ อกตามทีหลังเล็กน้อยจากความหน่วงของ approach)
		add("chest", up, math.deg(gy) * 0.15)
		local rightLook = CFrame.fromAxisAngle(up, gy * 0.5):VectorToWorldSpace(right)
		add("neck", up, math.deg(gy) * 0.35)
		add("head", up, math.deg(gy) * 0.5)
		add("neck", rightLook, math.deg(gp) * 0.35) -- รอบแกนขวา: บวก = เงย
		add("head", rightLook, math.deg(gp) * 0.55)
	end

	-- ---------------------------------------------------------------- ถ่ายน้ำหนัก (ยืนนิ่งเท่านั้น)
	if not opts.seated and still > 0.01 then
		if now >= L.nextShift then
			L.tShift = if L.tShift > 0 then rng:NextNumber(-1, -0.35) else rng:NextNumber(0.35, 1)
			L.nextShift = now + rng:NextNumber(3.5, 9)
		end
		L.shift = approach(L.shift, L.tShift, 1.6, dt)
		local s = L.shift * calm * e * still
		add("hips", look, 2.0 * s) -- สะโพกเอียง
		add("spine", look, -1.3 * s) -- ลำตัวเอียงกลับให้หัวอยู่กลาง
		add("chest", look, -0.6 * s)
		add("thigh.L", look, -2.0 * s) -- ขาตั้งตรงเหมือนเดิม
		add("thigh.R", look, -2.0 * s)
		-- ขาข้างที่พัก: งอเข่านิด (เข่ามาข้างหน้า เท้าอยู่ที่เดิม)
		local relaxL, relaxR = math.max(0, -s), math.max(0, s) -- s > 0: สะโพกขวาตก = ขาขวาพัก
		add("thigh.L", right, 3.0 * relaxL)
		add("shin.L", right, -6.0 * relaxL)
		add("foot.L", right, 3.0 * relaxL)
		add("thigh.R", right, 3.0 * relaxR)
		add("shin.R", right, -6.0 * relaxR)
		add("foot.R", right, 3.0 * relaxR)
	end

	-- ---------------------------------------------------------------- ขยับเล็กๆ นานๆ ครั้ง
	if still > 0.01 then
		if not L.fidget and now >= L.nextFidget and still > 0.9 then
			L.fidget = FIDGET_LIST[rng:NextInteger(1, #FIDGET_LIST)]
			if (opts.seated or opts.noHead) and (L.fidget == "tilt" or L.fidget == "lookdown" or L.fidget == "neck") then
				L.fidget = "shrug" -- นั่งรถ: ไม่แตะคอ/หัว
			end
			L.fidgetT0 = now
		end
		local f = L.fidget
		if f then
			local dur = FIDGETS[f]
			local k = envelope(now - L.fidgetT0, dur) * calm * still
			if now - L.fidgetT0 >= dur then
				L.fidget = nil
				L.nextFidget = now + rng:NextNumber(6, 16) / e
			elseif f == "shrug" then
				add("shoulder.L", look, 5 * k)
				add("shoulder.R", look, -5 * k)
				add("chest", right, 1.5 * k)
			elseif f == "tilt" then
				add("head", look, 7 * k * (if L.breathPh > math.pi then 1 else -1))
			elseif f == "lookdown" then
				add("neck", right, -7 * k) -- ก้ม
				add("head", right, -9 * k)
			elseif f == "neck" then
				local wob = math.sin((now - L.fidgetT0) / dur * math.pi * 2)
				add("neck", look, 6 * k * wob)
				add("head", right, -3 * k)
			end
		end
	end
	return out
end

return M
