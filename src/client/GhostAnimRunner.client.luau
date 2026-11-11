--!strict
-- GhostAnimRunner.client.luau
-- Plays Mixamo-retargeted ghost animations directly on Bone.Transform every PreSimulation frame
-- from ReplicatedStorage.Shared.GhostClipData (no manual AnimationId re-upload required).
-- Works for:
--   1) Server-spawned ghosts (server/GhostNPC -> tagged "RiggedGhost", attribute GhostClip)
--   2) Client scenery ghosts (client/SceneryGhosts -> tagged "RiggedGhost", attribute GhostClip)
--   3) ViewportFrame jumpscare clones (client/JumpscareController -> live Zombie Scream / lunge on screen)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("GhostClipData")) :: any

local TAG = "RiggedGhost"
local FADE_TIME = 0.25

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

local function sample(c: Clip, keys: { CFrame }, t: number, posScale: number): CFrame
	local cf: CFrame
	if #keys == 1 then
		cf = keys[1]
	else
		local times = c.times
		local n = math.min(#times, #keys)
		if t <= times[1] then
			cf = keys[1]
		else
			cf = keys[n]
			for i = 1, n - 1 do
				if t < times[i + 1] then
					local a = (t - times[i]) / math.max(1e-4, times[i + 1] - times[i])
					cf = keys[i]:Lerp(keys[i + 1], a)
					break
				end
			end
		end
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

	local el = (now - st.curT0) * speed
	local tCur = clipTime(c, el)
	local blend = if st.prevClip then math.clamp((now - st.switchAt) / FADE_TIME, 0, 1) else 1
	local tPrev = if st.prevClip and blend < 1 then clipTime(st.prevClip, (now - st.prevT0) * speed) else 0

	for bname, b in pairs(st.bones) do
		local tr = c.tracks[bname]
		local pScale = if bname == "hips" or bname == "root" then st.hipScale else 1
		local cf = if tr then sample(c, tr, tCur, pScale) else CFrame.identity
		if blend < 1 and st.prevClip then
			local ptr = st.prevClip.tracks[bname]
			local pcf = if ptr then sample(st.prevClip, ptr, tPrev, pScale) else CFrame.identity
			cf = pcf:Lerp(cf, blend)
		end
		b.Transform = cf
	end
end

RunService.PreSimulation:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local seen: { [Model]: boolean } = {}
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		if inst:IsA("Model") and inst:IsDescendantOf(Workspace) then
			seen[inst] = true
			stepGhost(inst, now)
		end
	end
	local localFolder = Workspace:FindFirstChild("LocalSceneryGhosts")
	if localFolder then
		for _, ch in ipairs(localFolder:GetChildren()) do
			if ch:IsA("Model") and not seen[ch] then
				seen[ch] = true
				stepGhost(ch, now)
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
