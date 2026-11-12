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
	curClip: Clip?,
	curName: string?,
	curT0: number,
	prevClip: Clip?,
	prevT0: number,
	switchAt: number,
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
	if root and hips then
		local dy = math.abs(hips.WorldPosition.Y - root.Position.Y)
		if dy > 0.2 then
			hipScale = math.clamp(dy / 2.95, 0.4, 2.5)
		end
	end
	st = {
		bones = bones,
		root = root,
		hipScale = hipScale,
		curClip = nil,
		curName = nil,
		curT0 = 0,
		prevClip = nil,
		prevT0 = 0,
		switchAt = 0,
	}
	states[m] = st
	return st
end

local function stepGhost(m: Model, now: number)
	local clipName = m:GetAttribute("GhostClip")
	if type(clipName) ~= "string" or clipName == "" then
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
