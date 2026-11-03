--!strict
-- HeadTurn.luau
-- ตัวชาวบ้านมองตามมุมกล้อง โดยไม่หมุนทั้งตัว
--   ซ้าย/ขวา (yaw, ไม่เกิน LIMIT): คอ + หัวหัน ตัวอยู่กับที่
--   ก้ม/เงย (pitch): ลำตัว (spine + chest) เอนตามส่วนหนึ่ง คอ + หัวรับส่วนที่เหลือ
--   ถือไฟฉาย (aim 0..1): แขนที่ถือไฟฉาย (M.Sides: ผู้เล่นเลือกได้ ค่าเริ่มต้นขวา) ชี้ไปทางที่มอง -> ไฟฉายส่องตามสายตา
--   ตัวผู้เล่นเอง: character/Animate (คืนตำแหน่ง/ทิศของกระดูกหัวก่อน-หลังหมุน ใช้เลื่อนกล้องตามหัว)
--   ตัวผู้เล่นคนอื่น: client/HeadTurnOthers (มุมจาก attribute "HeadYaw"/"HeadPitch" ของตัวละคร ที่เซิร์ฟเวอร์ตั้งให้)
-- เรียกทุกเฟรมหลังท่าทางคำนวณเสร็จ (RunService.PreSimulation): Animator เขียน Bone.Transform ใหม่ทุกเฟรม
--   กระดูกที่ท่าไม่ได้แตะ ค่าที่เราเขียนจะค้างอยู่ -> จำค่าก่อนหมุนไว้ ถ้า Transform ยังเป็นค่าที่เราเขียน ใช้ค่าเดิมนั้นเป็นฐาน
local M = {}

M.LIMIT = math.rad(45)
-- สัดส่วนที่แต่ละกระดูกรับ (ของมุมเต็ม). yaw: ตัวไม่หัน คอ+หัวรวม 1
-- pitch: ลำตัว 0.25 คอ+หัว 0.4 ที่เหลือ = ลูกตา (ก้มมองเต็มมุมด้วยหัวอย่างเดียว ตา/กล้องจะยุบลงต่ำเกินจริง)
local YAW = { neck = 0.4, head = 0.6 }
local PITCH = { spine = 0.1, chest = 0.15, neck = 0.15, head = 0.25 }
-- แขนไฟฉาย: จับจากด้านบน (มือคว่ำบนกระบอก แขนท่อนล่างพาดหน้าอก หัวไฟโผล่ทางฝั่งนิ้วก้อย ส่องไปข้างหน้า)
--   ท่าที่ข้อมือไม่ต้องบิดเกินจริง: คว่ำมือ + แขนท่อนล่างชี้เฉียงเข้าหาลำตัว -> แนวกำมือ (นิ้วชี้ -> นิ้วก้อย) ชี้ไปข้างหน้าเอง
--   (เดิมให้แนวกำมือชี้หน้าโดยแขนท่อนล่างชี้หน้าด้วย ข้อมือต้องบิด/หัก ~90° ดูเหมือนมือหัก)
--   ตำแหน่งมือ HAND_POS (หน้าอกซ้าย ในกรอบตัว) + ทิศแขนท่อนล่าง -> ข้อศอกอยู่ที่ มือ - ทิศแขนท่อนล่าง x ความยาว
--   (เงย/ก้ม/หันหัว: หมุนตำแหน่งมือรอบหัวไหล่ตามสายตา)
--   1) หัวไหล่: แขนท่อนบนชี้ไปที่ข้อศอกนั้น
--   2) แขนท่อนล่าง: ชี้เฉียงเข้าหาลำตัว FORE_ACROSS ลาดลง FORE_DROP แล้วบิดรอบแกนแขน (คว่ำมือ) ให้ฝั่งฝ่ามือชี้ลง
--   3) ข้อมือ: ปรับนิดเดียวให้แนวกำมือ (โคนนิ้วชี้ -> โคนนิ้วก้อย = ทิศหัวไฟ) ชี้ไปทางที่มอง
-- มือที่ถือไฟฉาย: ผู้เล่นเลือกในหน้าตั้งค่า (attribute FlashHand ของ Player "R"/"L" ค่าเริ่มต้นขวา) ของอื่น (แกลลอน/ขนม) อยู่มืออีกข้าง
-- ตัวที่ไม่ใช่ผู้เล่น (NPC) = ไฟฉายมือซ้ายแบบเดิม
local Players = game:GetService("Players")
function M.Sides(char: Model): (string, string)
	local pl = Players:GetPlayerFromCharacter(char)
	if not pl then
		return "L", "R"
	end
	local f = if pl:GetAttribute("FlashHand") == "L" then "L" else "R"
	return f, if f == "L" then "R" else "L"
end
local AIM_DROP = math.rad(-4) -- หัวไฟเงยขึ้นนิด
local FORE_DROP = math.rad(10) -- แขนท่อนล่างลาดลงนิด
local FORE_ACROSS = math.rad(60) -- แขนท่อนล่างเฉียงเข้าหาลำตัว (0 = ชี้หน้า, 90 = พาดขวางหน้าอก)
local HAND_POS = Vector3.new(-0.4, 2.05, -1.45) -- ข้อมือซ้ายในกรอบ HumanoidRootPart ตอนมองตรง (มือขวา: x กลับด้าน)
local BODY = { "spine", "chest", "neck", "head" }
-- กระดูกแขนของแต่ละข้าง (คืนท่าฐานทั้งสองข้างทุกเฟรม: สลับมือแล้วแขนข้างเดิมไม่ค้างท่าชี้)
local ARM_BONES = { "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R" }
local WATCH: { [string]: boolean } = {}
for _, n in ipairs(ARM_BONES) do
	WATCH[n] = true
end
for _, n in ipairs({ "index_01.L", "pinky_01.L", "index_01.R", "pinky_01.R" }) do
	WATCH[n] = true
end

type State = { bones: { [string]: Bone }, written: { [Bone]: CFrame }, base: { [Bone]: CFrame } }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(char: Model): State?
	local st = states[char]
	if st and st.bones.head and st.bones.head.Parent then
		return st
	end
	local found: { [string]: Bone } = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Bone") and (PITCH[d.Name] or WATCH[d.Name]) then
			found[d.Name] = d
		end
	end
	if not found.head then
		return nil
	end
	st = { bones = found, written = {}, base = {} }
	states[char] = st
	return st
end

-- คืน: CFrame โลกของกระดูกหัว ก่อนหมุน และหลังหมุน (ไม่มีกระดูกหัว: nil)
function M.apply(char: Model, yaw: number, pitch: number?, aim: number?): (CFrame?, CFrame?)
	local st = stateOf(char)
	local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("RootPart")
	if not st or not (root and root:IsA("BasePart")) then
		return nil, nil
	end
	local p = pitch or 0
	local a = aim or 0
	local side = M.Sides(char)
	local ARM, FORE_L, HAND_L = "upper_arm." .. side, "forearm." .. side, "hand." .. side
	local KNUCKLE_INDEX, KNUCKLE_PINKY = "index_01." .. side, "pinky_01." .. side
	local mirror = if side == "R" then -1 else 1 -- มือขวา: กลับซ้าย-ขวา (ตำแหน่งมือ ทิศแขนท่อนล่าง)
	local ORDER = { "spine", "chest", "neck", "head", ARM, FORE_L, HAND_L } -- พ่อก่อนลูก
	-- 1) คืนทุกกระดูกเป็นท่าจาก Animator (ฐาน) — ลำตัว + แขนทั้งสองข้าง
	local restore = table.clone(BODY)
	for _, n in ipairs(ARM_BONES) do
		table.insert(restore, n)
	end
	for _, name in ipairs(restore) do
		local b = st.bones[name]
		if b then
			local cur = b.Transform
			local base = if st.written[b] == cur then st.base[b] else cur
			st.base[b] = base
			if cur ~= base then
				b.Transform = base
			end
			st.written[b] = nil
		end
	end
	local headBefore = st.bones.head.TransformedWorldCFrame
	if math.abs(yaw) < 1e-3 and math.abs(p) < 1e-3 and a <= 0.01 then
		return headBefore, headBefore
	end
	-- 2) หมุนรอบแกนของตัว: yaw รอบแกนตั้ง, pitch รอบแกนขวา (ลำตัว: แกนขวาของตัว / คอ หัว แขน: แกนขวาหลังหันตาม yaw)
	local rcf = root.CFrame
	local up = rcf.UpVector
	local rightBody = rcf.RightVector
	local rightLook = CFrame.fromAxisAngle(up, yaw):VectorToWorldSpace(rightBody)
	for _, name in ipairs(ORDER) do
		local b = st.bones[name]
		if not b then
			continue
		end
		local w: CFrame
		if name == ARM or name == FORE_L or name == HAND_L then
			if a <= 0.01 then
				continue
			end
			local forward = CFrame.fromAxisAngle(up, yaw):VectorToWorldSpace(rcf.LookVector)
			local look = CFrame.fromAxisAngle(rightLook, p):VectorToWorldSpace(forward)
			local function arc(d: Vector3, want: Vector3): CFrame
				local axis = d:Cross(want)
				local ang = math.acos(math.clamp(d:Dot(want), -1, 1)) * a
				return if axis.Magnitude > 1e-5 and ang > 1e-4 then CFrame.fromAxisAngle(axis.Unit, ang) else CFrame.new()
			end
			local hand = st.bones[HAND_L]
			if not hand then
				continue
			end
			-- ทิศแขนท่อนล่างที่ต้องการ: เฉียงเข้าหาลำตัว (มือซ้าย: ไปทางขวา) ลาดลงนิด เงย/ก้มตามสายตา
			local across = CFrame.fromAxisAngle(up, -FORE_ACROSS * mirror):VectorToWorldSpace(forward)
			local foreWant = CFrame.fromAxisAngle(rightLook, p - FORE_DROP):VectorToWorldSpace(across).Unit
			local fore = st.bones[FORE_L]
			if not fore then
				continue
			end
			if name == ARM then
				-- แขนท่อนบนชี้ไปที่ข้อศอก ที่ทำให้ข้อมืออยู่ที่ HAND_POS (หมุนรอบหัวไหล่ตามสายตา)
				local sh = b.TransformedWorldCFrame.Position
				local el = fore.TransformedWorldCFrame.Position
				local lf = (hand.TransformedWorldCFrame.Position - el).Magnitude
				local view = CFrame.fromAxisAngle(rightLook, p) * CFrame.fromAxisAngle(up, yaw)
				local hp = Vector3.new(HAND_POS.X * mirror, HAND_POS.Y, HAND_POS.Z)
				local target = sh + view:VectorToWorldSpace(rcf:PointToWorldSpace(hp) - sh)
				local elbow = target - foreWant * lf
				local d, want = el - sh, elbow - sh
				if d.Magnitude < 1e-4 or want.Magnitude < 1e-4 then
					continue
				end
				w = arc(d.Unit, want.Unit)
			elseif name == FORE_L then
				-- ชี้แขนท่อนล่างไปทาง foreWant แล้วคว่ำมือ: บิดรอบแกนแขนให้ฝั่งฝ่ามือ (ข้อมือ -> ของในมือ) ชี้ลง
				local el = b.TransformedWorldCFrame.Position
				local wrist = hand.TransformedWorldCFrame.Position
				local d = wrist - el
				local c = M.grip(char, side, "flashlight")
				if not c or d.Magnitude < 1e-4 then
					continue
				end
				local aim = arc(d.Unit, foreWant)
				local f = aim:VectorToWorldSpace(d.Unit)
				local n = aim:VectorToWorldSpace(c - wrist)
				n -= f * n:Dot(f)
				local tgt = -up
				tgt -= f * tgt:Dot(f)
				w = aim
				if n.Magnitude > 1e-4 and tgt.Magnitude > 1e-4 then
					n, tgt = n.Unit, tgt.Unit
					local ang = math.atan2(n:Cross(tgt):Dot(f), n:Dot(tgt)) * a
					w = CFrame.fromAxisAngle(f, ang) * aim
				end
			else
				-- ข้อมือ: แนวกำมือ (นิ้วชี้ -> นิ้วก้อย) ชี้ไปทางที่มอง
				local ki, kp = st.bones[KNUCKLE_INDEX], st.bones[KNUCKLE_PINKY]
				local d = ki and kp and (kp.TransformedWorldCFrame.Position - ki.TransformedWorldCFrame.Position)
				if not (d and d.Magnitude > 1e-4) then
					continue
				end
				w = arc(d.Unit, CFrame.fromAxisAngle(rightLook, -AIM_DROP):VectorToWorldSpace(look).Unit)
			end
		else
			local y = yaw * (YAW[name] or 0)
			local pp = p * PITCH[name]
			if math.abs(y) < 1e-4 and math.abs(pp) < 1e-4 then
				continue
			end
			local right = if YAW[name] then rightLook else rightBody
			w = CFrame.fromAxisAngle(right, pp) * CFrame.fromAxisAngle(up, y) -- หมุนในโลก (yaw ก่อน แล้วเงย/ก้ม)
		end
		local f = b.TransformedWorldCFrame.Rotation
		local t = st.base[b] * (f:Inverse() * w * f)
		b.Transform = t
		st.written[b] = t
	end
	return headBefore, st.bones.head.TransformedWorldCFrame
end

-- ของในมือ (มือท่า grip_flashlight / grip_umbrella ใน build_anims.py): จุดกลางของ และแนวของ ในโลก
-- มือท่านั้นหามาจากการ "แบมือ -> วางของบนฝ่ามือ -> งอนิ้วจนแตะของ" ใน Blender ตำแหน่งของจึงต้องตรงกับตอนนั้น:
--   กรอบมือ = ข้อมือ (hand), X = โคนนิ้วก้อย -> โคนนิ้วชี้ (แนวของ), Y = ไปทางโคนนิ้วกลาง (ตั้งฉาก X), Z = X x Y
--   จุดกลางของ = ข้อมือ + X*cx + Y*cy + Z*cz (studs) ค่าจากการค้นหา (ไฟฉาย รัศมี 0.155 / ร่ม-กำมือ รัศมี 0.088)
--   มือขวาเป็นเงาของมือซ้าย: Z (= X x Y) กลับทิศ -> cz กลับเครื่องหมาย
--   ใช้ตำแหน่งกระดูกอย่างเดียว ไม่พึ่งแกนของกระดูก (Roblox วางแกนกระดูกต่างจาก Blender ได้)
-- kind: "flashlight" | "fist" (ร่ม / หูแกลลอน) ไม่ระบุ = แบบเดิม (ซ้าย = ไฟฉาย, ขวา = ร่ม)
local GRIP_Z = { flashlight = 0.2118, fist = 0.1418 }
function M.grip(char: Model, side: string, kind: string?): (Vector3?, Vector3?)
	local function pos(n: string): Vector3?
		local x = char:FindFirstChild(n .. "." .. side, true)
		return if x and x:IsA("Bone") then x.TransformedWorldCFrame.Position else nil
	end
	local o, kf, kb, mid = pos("hand"), pos("index_01"), pos("pinky_01"), pos("middle_01")
	local k = kind or (if side == "L" then "flashlight" else "fist")
	local g = Vector3.new(0, 0.2011, (GRIP_Z[k] or GRIP_Z.fist) * (if side == "L" then -1 else 1))
	if not (o and kf and kb and mid) then
		return nil, nil
	end
	local x = kf - kb
	if x.Magnitude < 1e-4 then
		return nil, nil
	end
	x = x.Unit
	local y = mid - o
	y -= x * y:Dot(x)
	if y.Magnitude < 1e-4 then
		return nil, nil
	end
	y = y.Unit
	local z = x:Cross(y)
	return o + x * g.X + y * g.Y + z * g.Z, x
end

return M
