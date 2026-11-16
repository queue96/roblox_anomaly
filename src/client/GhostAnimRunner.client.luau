--!strict
-- GhostAnimRunner.client.luau
-- Plays Mixamo-retargeted ghost animations directly on Bone.Transform every PreSimulation frame
-- from ReplicatedStorage.Shared.GhostClipData (no manual AnimationId re-upload required).
-- Works for:
--   1) Server-spawned ghosts (server/GhostNPC -> tagged "RiggedGhost", attribute GhostClip)
--   2) Client scenery ghosts (client/SceneryGhosts -> tagged "RiggedGhost", attribute GhostClip)
--   3) ViewportFrame jumpscare clones (client/JumpscareController -> live Zombie Scream / lunge on screen)
-- Performance (2026-11-12): one key lookup per clip per frame (binary search) instead of a linear scan per bone,
-- and ghosts beyond CULL_DIST or behind the camera are skipped (their bones keep the last pose).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("GhostClipData")) :: any

local TAG = "RiggedGhost"
local FADE_TIME = 0.25
local CULL_DIST = 110 -- studs: night fog hides everything past ~65-70, keep a margin for tall ghosts
local NEAR_ALWAYS = 14 -- studs: closer than this always animates, even behind the camera (turning around)
local BEHIND_DOT = -0.35 -- direction · camera look below this = behind the camera

type Clip = {
	length: number,
	once: boolean,
	times: { number },
	tracks: { [string]: { CFrame } },
}

local clips: { [string]: Clip } = {}

local function resolveKey(ghostName: string?, clipName: string): string?
	if ghostName == "Pop" and Data["Pop_" .. clipName] then
		return "Pop_" .. clipName
	end
	if Data[clipName] then
		return clipName
	end
	return nil
end

local function clipOf(ghostName: string?, clipName: string): Clip?
	local key = resolveKey(ghostName, clipName)
	if not key then
		return nil
	end
	local c = clips[key]
	if c then
		return c
	end
	local d = Data[key]
	if not d then
		return nil
	end
	local tracks: { [string]: { CFrame } } = {}
	for bone, keys in pairs(d.tracks) do
		local list = table.create(#keys)
		for i, k in ipairs(keys) do
			list[i] = CFrame.new(k[1], k[2], k[3], k[4], k[5], k[6], k[7])
		end
		tracks[bone] = list
	end
	c = {
		length = d.length,
		once = d.once == true,
		times = d.times,
		tracks = tracks,
	}
	clips[key] = c
	return c
end

-- Key pair + blend factor for time t (shared by every bone of the clip this frame)
local function locate(c: Clip, t: number): (number, number, number)
	local times = c.times
	local n = #times
	if n <= 1 or t <= times[1] then
		return 1, 1, 0
	end
	if t >= times[n] then
		return n, n, 0
	end
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	return lo, hi, (t - times[lo]) / math.max(1e-4, times[hi] - times[lo])
end

local function sampleAt(keys: { CFrame }, i0: number, i1: number, a: number, posScale: number): CFrame
	local n = #keys
	local cf: CFrame
	if n == 1 then
		cf = keys[1]
	else
		local k0 = keys[if i0 < n then i0 else n]
		cf = if a > 0 then k0:Lerp(keys[if i1 < n then i1 else n], a) else k0
	end
	if posScale ~= 1 and cf.Position.Magnitude > 1e-4 then
		return (cf - cf.Position) + cf.Position * posScale
	end
	return cf
end

local function clipTime(c: Clip, elapsed: number): number
	if c.once then
		return math.min(math.max(0, elapsed), c.length)
	end
	return (elapsed % c.length + c.length) % c.length
end

type State = {
	bones: { [string]: Bone },
	root: BasePart?,
	hipScale: number,
	hipsRel: Vector3,
	curClip: Clip?,
	curName: string?,
	curT0: number,
	prevClip: Clip?,
	prevT0: number,
	switchAt: number,
	hostModel: Model?,
	hostNeck: Bone?,
	hostSpine: Bone?,
	hostRoot: BasePart?,
	lookYaw: number,
	lookPitch: number,
	lookAt: number,
}

local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(m: Model): State
	local st = states[m]
	if st then
		return st
	end
	local bones: { [string]: Bone } = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and not bones[d.Name] then
			bones[d.Name] = d
		end
	end
	local hipScale = 1.0
	local root = m:FindFirstChild("RootPart") :: BasePart?
	local hips = bones["hips"]
	local hipsRel = Vector3.new(0, 1.73, 0)
	if root and hips then
		hipsRel = root.CFrame:PointToObjectSpace(hips.WorldPosition)
		local dy = math.abs(hips.WorldPosition.Y - root.Position.Y)
		if dy > 0.2 then
			hipScale = math.clamp(dy / 2.95, 0.4, 2.5)
		end
	end
	st = {
		bones = bones,
		root = root,
		hipScale = hipScale,
		hipsRel = hipsRel,
		curClip = nil,
		curName = nil,
		curT0 = 0,
		prevClip = nil,
		prevT0 = 0,
		switchAt = 0,
		hostModel = nil,
		hostNeck = nil,
		hostSpine = nil,
		hostRoot = nil,
		lookYaw = 0,
		lookPitch = 0,
		lookAt = 0,
	}
	states[m] = st
	return st
end

-- ผีเด็กขี่คอ (Anomaly_ShoulderChild): ขาพาดบนบ่าสองข้างสมมาตร หน้าแข้งห้อยหน้าอก มือสองข้างวางเกาะบนกระหม่อมหัวลูกค้า
local function poseShoulderRide(st: State, now: number)
	local sw = math.sin(now * 1.6)
	local br = math.sin(now * 2.3)
	local pose: { [string]: CFrame } = {
		["hips"] = CFrame.Angles(math.rad(-2 + br * 1.0), 0, math.rad(sw * 1.2)),
		["spine"] = CFrame.Angles(math.rad(-4 + br * 1.2), 0, math.rad(sw * 1.5)),
		["chest"] = CFrame.Angles(math.rad(-4 + br * 1.2), 0, 0),
		["neck"] = CFrame.Angles(math.rad(14), math.rad(sw * 4), math.rad(sw * 2.5)),
		["head"] = CFrame.Angles(math.rad(14 + br * 2), math.rad(-sw * 3), math.rad(4 + sw * 3)),
		["thigh.L"] = CFrame.Angles(math.rad(-82), math.rad(14), math.rad(-24)),
		["thigh.R"] = CFrame.Angles(math.rad(-82), math.rad(-14), math.rad(24)),
		["shin.L"] = CFrame.Angles(math.rad(72 + sw * 2), 0, math.rad(8)),
		["shin.R"] = CFrame.Angles(math.rad(72 - sw * 2), 0, math.rad(-8)),
		["foot.L"] = CFrame.Angles(math.rad(-10), 0, 0),
		["foot.R"] = CFrame.Angles(math.rad(-10), 0, 0),
		["upper_arm.L"] = CFrame.Angles(math.rad(-40), math.rad(20), math.rad(60)),
		["upper_arm.R"] = CFrame.Angles(math.rad(-40), math.rad(-20), math.rad(-60)),
		["forearm.L"] = CFrame.Angles(math.rad(55), math.rad(35), math.rad(92)),
		["forearm.R"] = CFrame.Angles(math.rad(55), math.rad(-35), math.rad(-92)),
		["hand.L"] = CFrame.Angles(math.rad(22), 0, 0),
		["hand.R"] = CFrame.Angles(math.rad(22), 0, 0),
	}
	for bname, b in pairs(st.bones) do
		b.Transform = pose[bname] or CFrame.identity
	end
end

-- ยึดสะโพกผีเด็กขี่คอให้เกาะตามกระดูกคอ (neck) ของลูกค้าทุกเฟรม (ผิวไหล่บนสูงกว่า neck +0.30 และหลังหัวอยู่ที่ +0.35)
local function followShoulderHost(m: Model)
	if m:GetAttribute("ShoulderRider") ~= true then
		return
	end
	local v = m.Parent
	local d = v and v:FindFirstChild("DriverNPC")
	if not (d and d:IsA("Model")) then
		return
	end
	local st = stateOf(m)
	if st.hostModel ~= d then
		st.hostModel = d
		st.hostNeck = nil
		st.hostSpine = nil
		st.hostRoot = d:FindFirstChild("RootPart") :: BasePart?
		for _, b in ipairs(d:GetDescendants()) do
			if b:IsA("Bone") then
				if b.Name == "neck" then
					st.hostNeck = b
				elseif b.Name == "spine" then
					st.hostSpine = b
				end
			end
		end
	end
	local neck = st.hostNeck
	if not neck then
		return
	end
	local neckPos = neck.TransformedWorldCFrame.Position
	local refCF = if st.hostRoot then st.hostRoot.CFrame else (v :: Model):GetPivot()
	local lv = refCF.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	local yawRot = if flat.Magnitude > 1e-3 then CFrame.lookAt(Vector3.zero, flat.Unit) else (v :: Model):GetPivot().Rotation
	local spineAnimated = st.hostSpine ~= nil and st.hostSpine.Transform ~= CFrame.identity
	local off = if not spineAnimated and d:GetAttribute("SeatClip") == "ride_moto"
		then Vector3.new(0, 0.22, 0.08)
		else Vector3.new(0, 0.32, 0.34)
	local hipCF = (CFrame.new(neckPos) * yawRot) * CFrame.new(off)
	m:PivotTo(hipCF * CFrame.new(-st.hipsRel))
end

-- คอ/หัวหันตามผู้เล่น (attribute LookAtCamera = true, ผู้ใช้ 2026-11-16: เงาเกาะต้นไทร "ให้คอมองตามผู้เล่น ตัวไม่ต้องขยับ")
-- เรียกหลังเขียนท่าของ clip แล้ว: หมุนกระดูก neck (ส่วนหนึ่ง) และ head (ที่เหลือ) ทับท่าเดิมให้หน้าหันไปทางกล้อง
-- ตัว/แขน/ขาไม่แตะ · หันได้ไม่เกิน LOOK_YAW จากทิศหน้าลำตัว ก้ม/เงยไม่เกิน LOOK_PITCH · ค่อยๆ หันตาม (LOOK_RATE) ไม่สะบัด
local LOOK_YAW = math.rad(80)
local LOOK_PITCH = math.rad(35)
local LOOK_RATE = 2.2 -- ยิ่งมากยิ่งหันตามเร็ว (ต่อวินาที)
local LOOK_NECK = 0.4 -- สัดส่วนที่คอรับไป ที่เหลือเป็นของหัว

local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- หมุนกระดูก b เพิ่มในพิกัดโลก (rw) ทับท่าปัจจุบัน
local function addWorldRotation(b: Bone, rw: CFrame)
	local t = b.Transform
	local p = b.TransformedWorldCFrame.Rotation * t.Rotation:Inverse() -- ทิศของกระดูกก่อนคูณ Transform
	b.Transform = CFrame.new(t.Position) * (p:Inverse() * rw * p * t.Rotation)
end

local function lookAtCamera(m: Model, st: State, now: number)
	local head, neck = st.bones["head"], st.bones["neck"]
	local cam = Workspace.CurrentCamera
	if not (head and cam) then
		return
	end
	local fwd = m:GetPivot().LookVector
	local bodyYaw = math.atan2(-fwd.X, -fwd.Z)
	-- ทิศหน้าของหัวในท่าปัจจุบัน: ทิศหน้าลำตัวตอนกระดูกอยู่ท่าพัก หมุนตามที่ท่าพาหัวไป
	local headFwdLocal = head.WorldCFrame.Rotation:Inverse() * fwd
	local cur = head.TransformedWorldCFrame.Rotation * headFwdLocal
	local to = cam.CFrame.Position - head.TransformedWorldCFrame.Position
	if to.Magnitude < 0.5 then
		return
	end
	to = to.Unit
	local wantYaw = math.clamp(wrapAngle(math.atan2(-to.X, -to.Z) - bodyYaw), -LOOK_YAW, LOOK_YAW)
	local wantPitch = math.clamp(math.asin(math.clamp(to.Y, -1, 1)), -LOOK_PITCH, LOOK_PITCH)
	-- ค่อยๆ ตามเป้า (เฟรมแรก / เพิ่งกลับมาหลังถูกข้ามเฟรมนาน = เริ่มจากท่าเดิมของ clip)
	local dt = math.clamp(now - st.lookAt, 0, 0.1)
	local curYaw = wrapAngle(math.atan2(-cur.X, -cur.Z) - bodyYaw)
	local curPitch = math.asin(math.clamp(cur.Y, -1, 1))
	if st.lookAt == 0 or now - st.lookAt > 1 then
		st.lookYaw, st.lookPitch = curYaw, curPitch
	end
	st.lookAt = now
	local k = 1 - math.exp(-LOOK_RATE * dt)
	st.lookYaw += (wantYaw - st.lookYaw) * k
	st.lookPitch += (wantPitch - st.lookPitch) * k

	local function turn(b: Bone, share: number)
		-- ทิศหน้าของหัวตอนนี้ (หัวเป็นลูกของคอ: หมุนคอในพิกัดโลกเท่าไร หน้าก็หันตามเท่านั้น)
		local f = head.TransformedWorldCFrame.Rotation * headFwdLocal
		local dYaw = wrapAngle(st.lookYaw - wrapAngle(math.atan2(-f.X, -f.Z) - bodyYaw)) * share
		local dPitch = (st.lookPitch - math.asin(math.clamp(f.Y, -1, 1))) * share
		local right = f:Cross(Vector3.yAxis)
		local pitchRot = if right.Magnitude > 1e-3 then CFrame.fromAxisAngle(right.Unit, dPitch) else CFrame.identity
		addWorldRotation(b, CFrame.Angles(0, dYaw, 0) * pitchRot)
	end
	if neck then
		turn(neck, LOOK_NECK)
	end
	turn(head, 1) -- หัวรับส่วนที่เหลือทั้งหมด (คำนวณใหม่หลังคอหมุนแล้ว)
end

local function stepGhost(m: Model, now: number)
	local clipName = m:GetAttribute("GhostClip")
	if type(clipName) ~= "string" or clipName == "" then
		return
	end
	if clipName == "shoulder_ride" then
		local st = stateOf(m)
		followShoulderHost(m)
		poseShoulderRide(st, now)
		return
	end
	local gname = (m:GetAttribute("GhostName") :: string?) or m.Name
	local c = clipOf(gname, clipName)
	if not c then
		return
	end
	local st = stateOf(m)
	local speed = (m:GetAttribute("GhostClipSpeed") :: number?) or 1
	local attrT0 = m:GetAttribute("GhostClipT0") :: number?
	if st.curName ~= clipName then
		st.prevClip = st.curClip
		st.prevT0 = st.curT0
		st.curClip = c
		st.curName = clipName
		st.curT0 = attrT0 or now
		st.switchAt = now
	elseif attrT0 and math.abs(attrT0 - st.curT0) > 0.5 then
		st.curT0 = attrT0
	end

	local i0, i1, a = locate(c, clipTime(c, (now - st.curT0) * speed))
	local prev = st.prevClip
	local blend = if prev then math.clamp((now - st.switchAt) / FADE_TIME, 0, 1) else 1
	local p0, p1, pa = 1, 1, 0
	if prev and blend < 1 then
		p0, p1, pa = locate(prev, clipTime(prev, (now - st.prevT0) * speed))
	elseif prev then
		st.prevClip = nil -- crossfade finished
		prev = nil
	end

	local tracks = c.tracks
	for bname, b in pairs(st.bones) do
		local tr = tracks[bname]
		local pScale = if bname == "hips" or bname == "root" then st.hipScale else 1
		local cf = if tr then sampleAt(tr, i0, i1, a, pScale) else CFrame.identity
		if prev then
			local ptr = prev.tracks[bname]
			local pcf = if ptr then sampleAt(ptr, p0, p1, pa, pScale) else CFrame.identity
			cf = pcf:Lerp(cf, blend)
		end
		b.Transform = cf
	end
	-- (ร่างโคลนในจอจั๊มสแกร์อยู่ใน ViewportFrame ไม่ใช่ Workspace: ไม่หันตามกล้องโลกจริง)
	if m:GetAttribute("LookAtCamera") == true and m:IsDescendantOf(Workspace) then
		lookAtCamera(m, st, now)
	end
end

-- far away / behind the camera: skip this frame (the pose just holds; night fog hides it anyway)
local function culled(m: Model, camPos: Vector3, camLook: Vector3): boolean
	local st = states[m]
	local root = st and st.root
	local pos = if root then root.Position else m:GetPivot().Position
	local off = pos - camPos
	local dist = off.Magnitude
	if dist > CULL_DIST then
		return true
	end
	return dist > NEAR_ALWAYS and off.Unit:Dot(camLook) < BEHIND_DOT
end

local tagged: { [Instance]: boolean } = {}
for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
	tagged[inst] = true
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
	tagged[inst] = true
end)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(inst)
	tagged[inst] = nil
end)

-- ผีที่มี IKControl (ผีตาโขนขี่แทนคนขับ: มือจับแฮนด์ เท้าบนที่พักเท้า, server/AnomalyManager.copyRiderIK)
-- ต้องเขียนท่าก่อนขั้น animation (PreAnimation) ให้ IK ดึงมือ/เท้าทับท่าทีหลัง
-- ถ้าเขียนใน PreSimulation (หลัง IK) ท่า mocap จะทับผล IK มือหลุดแฮนด์ (ผู้ใช้ 2026-11-13: หน้ากากผีตาโขนไม่กำแฮนด์)
local function hasIK(m: Model): boolean
	local ac = m:FindFirstChildOfClass("AnimationController")
	return ac ~= nil and ac:FindFirstChildOfClass("IKControl") ~= nil
end

RunService.PreAnimation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	for inst in pairs(tagged) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) and hasIK(inst) then
			stepGhost(inst, now)
		end
	end
end)

local seen: { [Model]: boolean } = {}
RunService.PreSimulation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local cam = Workspace.CurrentCamera
	local camCF = if cam then cam.CFrame else CFrame.identity
	local camPos, camLook = camCF.Position, camCF.LookVector
	table.clear(seen)
	for inst in pairs(tagged) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
			seen[inst] = true
			-- first frame always poses (fresh clones would otherwise hold the rest pose until looked at)
			if hasIK(inst) then
				continue -- posed in PreAnimation above
			end
			if not states[inst] or not culled(inst, camPos, camLook) then
				stepGhost(inst, now)
			end
		end
	end
	local localFolder = Workspace:FindFirstChild("LocalSceneryGhosts")
	if localFolder then
		for _, ch in ipairs(localFolder:GetChildren()) do
			if ch:IsA("Model") and not seen[ch] then
				if not states[ch] or not culled(ch, camPos, camLook) then
					stepGhost(ch, now)
				end
			end
		end
	end
end)

-- หลัง RiderMotion (RenderPriority.First + 3) ขยับตัวคนขับตามรถแล้ว ให้ผีเด็กขี่คอขยับตามกระดูกคอคนขับในเฟรมเดียวกัน
RunService:BindToRenderStep("ShoulderRiderFollow", Enum.RenderPriority.First.Value + 4, function()
	for inst in pairs(tagged) do
		if inst:IsA("Model") and inst:GetAttribute("ShoulderRider") == true and inst:IsDescendantOf(Workspace) then
			followShoulderHost(inst)
		end
	end
end)

-- Also animate rigged ghosts inside the Jumpscare ViewportFrame during active jumpscares
local player = Players.LocalPlayer
RunService.RenderStepped:Connect(function()
	local pg = player and player:FindFirstChild("PlayerGui")
	local jgui = pg and pg:FindFirstChild("Jumpscare") :: ScreenGui?
	if not (jgui and jgui.Enabled) then
		return
	end
	local vp = jgui:FindFirstChild("Face")
	local wm = vp and vp:FindFirstChildOfClass("WorldModel")
	if not wm then
		return
	end
	local now = Workspace:GetServerTimeNow()
	for _, d in ipairs(wm:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("GhostClip") then
			stepGhost(d, now)
			local focusMarker = d:FindFirstChild("FocusMarker") :: BasePart?
			if focusMarker then
				local fboneName = (d:GetAttribute("FocusBone") :: string?) or "head"
				local st = states[d]
				local fbone = st and st.bones[fboneName]
				if fbone then
					focusMarker.CFrame = fbone.WorldCFrame
				end
			end
		end
	end
end)
