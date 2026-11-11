--!strict
-- Rigged ghost models (ServerStorage.GhostTemplates, imported from assets/models/...fbx, Scale 0.01, Rig Custom,
-- Anchored). Clips come from shared/GhostAnimIds: a ghost without an id for a clip just stands in its rest pose.
--   GhostNPC.Has(name)                    template exists
--   GhostNPC.Spawn(name, cf, clip?)       clone with the feet (pivot) at cf, front = cf.LookVector; plays clip
--   GhostNPC.SpawnSeated(name, hip, clip) like Spawn, but the hips bone lands on hip (riders on a vehicle)
--   GhostNPC.Play(model, clip, speed?)    switch clip (waits until the model is in Workspace)
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GhostNPC = {}
-- ผีที่ Server ขยับเอง: เครื่องผู้เล่นเกลี่ยให้ลื่น (shared/NetSmooth; ผีที่นิ่ง/นั่งในรถไม่ถูกส่ง)
local NetSmooth = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NetSmooth")) :: any

local function templates(): Instance?
	return ServerStorage:FindFirstChild("GhostTemplates")
end

-- ผีฉากเกิดฝั่ง client (client/SceneryGhosts: แต่ละคนเห็นคนละตัว คนละเวลา) -> สำเนาแม่แบบไว้ใน ReplicatedStorage.GhostModels
do
	local src = templates()
	if src and not ReplicatedStorage:FindFirstChild("GhostModels") then
		local copy = src:Clone()
		copy.Name = "GhostModels"
		copy.Parent = ReplicatedStorage
	end
end

local function ids(): { [string]: any }
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("GhostAnimIds")
	if not mod then
		return {}
	end
	return require(mod :: ModuleScript) :: any
end

function GhostNPC.Has(name: string): boolean
	local f = templates()
	return f ~= nil and f:FindFirstChild(name) ~= nil
end

local function animator(m: Model): Animator?
	local ac = m:FindFirstChildOfClass("AnimationController")
	if not ac then
		ac = Instance.new("AnimationController")
		ac.Parent = m
	end
	local an = (ac :: Instance):FindFirstChildOfClass("Animator")
	if not an then
		an = Instance.new("Animator")
		an.Parent = ac
	end
	return an
end

local tracks: { [Model]: { current: AnimationTrack?, clip: string?, pending: string? } } = setmetatable({}, { __mode = "k" }) :: any

function GhostNPC.Play(m: Model, clip: string, speed: number?)
	local name = m:GetAttribute("GhostName") :: string?
	m:SetAttribute("GhostClip", clip)
	m:SetAttribute("GhostClipSpeed", speed or 1)
	m:SetAttribute("GhostClipT0", workspace:GetServerTimeNow())
	game:GetService("CollectionService"):AddTag(m, "RiggedGhost")
	local all = ids()
	local id = name and all[name] and all[name][clip]
	local st = tracks[m] or {}
	tracks[m] = st
	-- ท่าเดิมเล่นอยู่ / กำลังรอโหลด: ห้ามเริ่มใหม่ (ผู้ใช้ 2026-11-06: ผีเดินมาร้านท่า T)
	-- เริ่มท่าเดิมซ้ำแล้วหยุดอันเก่า = server ยังเล่นอันใหม่ แต่ client หยุดท่า ID นี้ทิ้งทั้งหมด -> ตัวค้างท่า T ทั้งทาง
	if st.clip == clip and (st.pending == clip or (st.current and st.current.IsPlaying)) then
		if speed and st.current then
			st.current:AdjustSpeed(speed)
		end
		return
	end
	st.clip = clip
	if not id then
		return
	end
	st.pending = clip
	task.spawn(function()
		-- Spawn calls this before the caller parents the model, so no parent yet just means "wait"
		local t0 = os.clock()
		while not m:IsDescendantOf(workspace) and st.clip == clip and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		if st.pending == clip then
			st.pending = nil
		end
		if not m:IsDescendantOf(workspace) or st.clip ~= clip then
			return
		end
		local an = animator(m)
		if not an then
			return
		end
		-- ท่าที่เล่นอยู่เป็นท่า ID เดียวกัน (สลับไปมาเร็วๆ ก่อนโหลดเสร็จ): ใช้อันเดิม ไม่เริ่มซ้อน
		if st.current and st.current.IsPlaying and st.current.Animation and st.current.Animation.AnimationId == id then
			if speed then
				st.current:AdjustSpeed(speed)
			end
			return
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local tr = an:LoadAnimation(a)
		tr.Looped = not (all.ONCE and all.ONCE[clip])
		tr:Play(0.3, 1, speed or 1)
		if st.current and st.current ~= tr then
			st.current:Stop(0.3)
		end
		st.current = tr
	end)
end

local function prep(name: string): Model?
	local f = templates()
	local t = f and f:FindFirstChild(name) :: Model?
	if not t then
		return nil
	end
	local m = t:Clone()
	m:SetAttribute("GhostName", name)
	game:GetService("CollectionService"):AddTag(m, "RiggedGhost")
	local sc = ids().SCALE
	if sc and sc[name] and sc[name] ~= 1 then
		m:ScaleTo(sc[name])
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = d.Name ~= "RootPart"
		end
	end
	return m
end

function GhostNPC.Spawn(name: string, cf: CFrame, clip: string?): Model?
	local m = prep(name)
	if not m then
		return nil
	end
	m:PivotTo(cf)
	if clip then
		GhostNPC.Play(m, clip)
	end
	NetSmooth.Track(m)
	return m
end

local function hipsOffset(m: Model): Vector3
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == "hips" then
			return m:GetPivot():PointToObjectSpace(d.WorldPosition)
		end
	end
	return Vector3.new(0, 3.1, 0)
end

function GhostNPC.SpawnSeated(name: string, hip: CFrame, clip: string?): Model?
	local m = prep(name)
	if not m then
		return nil
	end
	m:PivotTo(hip * CFrame.new(-hipsOffset(m)))
	if clip then
		GhostNPC.Play(m, clip)
	end
	NetSmooth.Track(m)
	return m
end

-- parts a script fades in/out (skip the invisible RootPart, it must stay hidden)
function GhostNPC.VisibleParts(m: Model): { BasePart }
	local out = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			table.insert(out, d)
		end
	end
	return out
end

return GhostNPC
