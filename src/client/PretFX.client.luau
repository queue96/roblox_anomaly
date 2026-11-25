--!nonstrict
-- PretFX.client.luau — ผีใหญ่เปรต (server/BigEvents runGiant) ฝั่งผู้เล่น  (ผู้ใช้ 2026-11-26 เลือกข้อ 1-5)
--   คนที่ทำถูก (ปิดแผง ดับไฟ) มองไม่เห็นมัน: เล่าด้วยเสียงก้าวเท้า พื้น/ร้านสั่น เสียงหายใจที่ลดลงมาจากฟ้า มือลูบหลังคา เสียงหวีดจากปากบนฟ้า
--   Remotes.BigFX(kind, data) เวลาเป็นเวลา Server: steps / cry / breath / hand / slam / stop
--   ตัวเปรต (tag GiantGhost): นั่งยองก้มตัว (attribute BowT0 / BowDur / BowDir) และมือขวายื่นแตะหลังคา (HandT0 / HandDur / HandX0 / HandX1 / HandY / HandZ)
--   กระดูกเขียนทับท่า Animator ทุกเฟรม (จำค่าท่าเดิมไว้ ไม่สะสมในเฟรมที่ Animator ไม่อัปเดต)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundBank = require(Shared:WaitForChild("SoundBank")) :: any
local ShopFX = require(Shared:WaitForChild("ShopFX")) :: any
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local interactive = Workspace:WaitForChild("InteractiveProps")

local LAG = 0.15 -- วิ: ตัวผีวาดย้อนหลังราวนี้ (shared/NetSmooth) เสียงเท้าช้าตาม ให้ตรงภาพ
local CEIL = 11.7
local token = 0 -- "stop" = ตัดเสียง/เอฟเฟกต์ที่ค้างอยู่ทั้งหมด

local function sfx(id: string, parent: Instance, volume: number, speed: number, minD: number, maxD: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minD
	s.RollOffMaxDistance = maxD
	local g = SoundService:FindFirstChild("SFX")
	if g and g:IsA("SoundGroup") then
		s.SoundGroup = g
	end
	s.Parent = parent
	return s
end
local function eq(s: Sound, low: number, mid: number, high: number)
	local e = Instance.new("EqualizerSoundEffect")
	e.LowGain, e.MidGain, e.HighGain = low, mid, high
	e.Parent = s
end
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- ---------------------------------------------------------------- 1) ก้าวเท้ายักษ์
local roofDust: ParticleEmitter? = nil
local function dustAll(n: number)
	if not (roofDust and roofDust.Parent) then
		local _, e = ShopFX.Dust(Vector3.new(26, 0.2, 15), Vector3.new(0, CEIL, 18))
		roofDust = e
	end
	(roofDust :: ParticleEmitter):Emit(math.floor(n))
end

local function step(pos: Vector3)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local off = cam.CFrame.Position - pos
	local d = Vector3.new(off.X, 0, off.Z).Magnitude
	local att = ShopFX.Emitter(pos, "PretStep")
	-- ตึง: ระเบิดช้าๆ ตัดแหลมจนเหลือเสียงทุ้ม + เสียงกระแทกสั้นๆ ให้มีหัวเสียง
	local boom = sfx("rbxasset://sounds/impact_explosion_03.mp3", att, 2.4, 0.5 + math.random() * 0.05, 34, 260)
	eq(boom, 8, -8, -34)
	boom:Play()
	local hit = sfx("rbxasset://sounds/action_jump_land.mp3", att, 2.2, 0.42, 30, 170)
	eq(hit, 6, 0, -14)
	hit:Play()
	task.delay(4.5, function()
		att:Destroy()
	end)
	local near = math.clamp(1 - d / 115, 0, 1)
	ShopFX.Shake(pos, 1.5, 0.6, 18, 135, true)
	if near > 0 then
		ShopFX.Swing(0.3 + 2.6 * near * near)
		dustAll(2 + 26 * near * near)
		-- สังกะสีทั้งร้านสั่นตาม (มาช้ากว่าเท้านิดหนึ่ง)
		local door = interactive:FindFirstChild("ShutterDoor") :: BasePart?
		if door and near > 0.3 then
			task.delay(0.07 + d / 900, function()
				local s = SoundBank.CreateSound("ShutterKnock", door, 90)
				if s then
					s.RollOffMinDistance = 14
					s.Volume *= 0.05 + 0.16 * near * near
					s.PlaybackSpeed = 0.62 + math.random() * 0.1
					s:Play()
					task.delay(3, function()
						s:Destroy()
					end)
				end
			end)
		end
	end
end

-- ---------------------------------------------------------------- 4) เสียงหวีดจากปาก (สูง ~60 studs)
local function cry(pos: Vector3, vol: number, speed: number)
	local att = ShopFX.Emitter(pos, "PretCry")
	local s = SoundBank.CreateSound("Ghost_Pret", att, 340)
	if s then
		s.RollOffMinDistance = 46
		s.Volume *= 2.1 * vol
		s.PlaybackSpeed *= speed
		local r = Instance.new("ReverbSoundEffect")
		r.DecayTime = 4.5
		r.DryLevel = 0
		r.WetLevel = -9
		r.Parent = s
		s:Play()
		task.delay(6, function()
			TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 }):Play()
		end)
	end
	task.delay(8, function()
		att:Destroy()
	end)
end

-- ---------------------------------------------------------------- 2) หายใจลดต่ำลงมาจากฟ้า
local function breath(t0: number, from: Vector3, to: Vector3, down: number, total: number)
	local my = token
	local att = ShopFX.Emitter(from, "PretBreath")
	local s = SoundBank.CreateSound("BreathNeckLeft", att, 130)
	if not s then
		att:Destroy()
		return
	end
	s.Looped = true
	s.RollOffMinDistance = 15
	local vol = s.Volume * 3.2
	s.Volume = 0
	s.PlaybackSpeed = 0.5 -- ช้า ทุ้ม = ตัวใหญ่
	eq(s, 6, 0, -14)
	s:Play()
	TweenService:Create(s, TweenInfo.new(1.2), { Volume = vol }):Play()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local el = now() - t0
		local k = math.clamp(el / down, 0, 1)
		att.WorldPosition = from:Lerp(to, k * k * (3 - 2 * k))
		if el > total or token ~= my then
			conn:Disconnect()
			TweenService:Create(s, TweenInfo.new(0.9), { Volume = 0 }):Play()
			task.delay(1, function()
				att:Destroy()
			end)
		end
	end)
end

-- ---------------------------------------------------------------- 3) มือลูบหลังคา
local function roofPanels(): { { p: BasePart, cf: CFrame } }
	local out = {}
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure")
	for _, p in ipairs(shack and shack:GetDescendants() or {}) do
		if p:IsA("BasePart") and p.Name == "TinRoofPanel" then
			table.insert(out, { p = p, cf = p.CFrame })
		end
	end
	return out
end
local handBusy = false
local function hand(t0: number, drag: number, hold: number, x0: number, x1: number, z: number)
	if handBusy then
		return
	end
	handBusy = true
	local my = token
	local panels = roofPanels()
	local att = ShopFX.Emitter(Vector3.new(x0, 12.2, z), "PretHand")
	local scrape = SoundBank.CreateSound("ShutterOpenPull", att, 100)
	local vol = 1
	if scrape then
		scrape.Looped = true
		scrape.RollOffMinDistance = 13
		vol = scrape.Volume * 0.85
		scrape.Volume = 0
		scrape.PlaybackSpeed = 0.34 -- ลากช้าๆ บนสังกะสี
		eq(scrape, 4, 1, -9)
		scrape:Play()
	end
	local dust, em = ShopFX.Dust(Vector3.new(4.5, 0.2, 5), Vector3.new(x0, CEIL, z))
	local nextDust, nextShake = 0, 0
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local el = now() - t0
		local k = math.clamp(el / drag, 0, 1)
		k = k * k * (3 - 2 * k)
		local x = x0 + (x1 - x0) * k
		local weight = math.clamp(el / 0.35, 0, 1) * math.clamp((drag + hold - el) / 0.5, 0, 1)
		local moving = el > 0 and el < drag
		att.WorldPosition = Vector3.new(x, 12.2, z)
		dust.Position = Vector3.new(x, CEIL, z)
		if scrape then
			scrape.Volume = if moving then vol * math.clamp(el / 0.4, 0, 1) * math.clamp((drag - el) / 0.35, 0, 1) else 0
			scrape.PlaybackSpeed = 0.34 + 0.05 * math.noise(el * 2.2, 4)
		end
		-- แผ่นหลังคายุบตามแนวมือ
		for _, r in ipairs(panels) do
			if r.p.Parent then
				local off = r.cf.Position.X - x
				local sag = 0.34 * math.exp(-(off / 3.4) ^ 2) * weight
				r.p.CFrame = r.cf * CFrame.new(0, -sag, 0)
			end
		end
		local clock = os.clock()
		if moving and clock > nextDust then
			nextDust = clock + 0.07
			em:Emit(3)
		end
		if moving and clock > nextShake then
			nextShake = clock + 0.22
			ShopFX.Shake(Vector3.new(x, 12, z), 0.28, 0.35, 5, 30, true)
		end
		if el > drag + hold or token ~= my then
			conn:Disconnect()
			for _, r in ipairs(panels) do
				if r.p.Parent then
					r.p.CFrame = r.cf
				end
			end
			att:Destroy()
			handBusy = false
			task.delay(3, function()
				dust:Destroy()
			end)
		end
	end)
end

-- ---------------------------------------------------------------- ตัวเปรต: นั่งยองก้มตัว + มือขวาแตะหลังคา
local DROP = 21 -- studs: สะโพกลดลงตอนก้มสุด
local BEND = { spine = -46, chest = -40, neck = 14, head = 6 } -- องศา (ลบ = ก้มไปข้างหน้า)
local ORDER = { "hips", "spine", "chest", "neck", "head", "upper_arm.R", "forearm.R", "upper_arm.L", "forearm.L", "thigh.L", "shin.L", "thigh.R", "shin.R" }

local function addWorldRotation(b: Bone, rw: CFrame)
	local t = b.Transform
	local p = b.TransformedWorldCFrame.Rotation * t.Rotation:Inverse()
	b.Transform = CFrame.new(t.Position) * (p:Inverse() * rw * p * t.Rotation)
end
local function addWorldOffset(b: Bone, v: Vector3)
	local t = b.Transform
	local p = b.TransformedWorldCFrame.Rotation * t.Rotation:Inverse()
	b.Transform = CFrame.new(p:Inverse() * v) * t
end
local function aim(b: Bone, from: Vector3, to: Vector3, w: number)
	if from.Magnitude < 1e-3 or to.Magnitude < 1e-3 then
		return
	end
	local f, t = from.Unit, to.Unit
	local axis = f:Cross(t)
	if axis.Magnitude > 1e-4 then
		addWorldRotation(b, CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(f:Dot(t), -1, 1)) * w))
	end
end
-- แขน/ขา 2 ท่อนไปถึงเป้า: pole = ทิศที่ศอก/เข่าชี้
local function twoBone(up: Bone, low: Bone, tip: Bone, target: Vector3, pole: Vector3, w: number)
	local S, E, H = up.TransformedWorldCFrame.Position, low.TransformedWorldCFrame.Position, tip.TransformedWorldCFrame.Position
	local a, b = (E - S).Magnitude, (H - E).Magnitude
	local to = target - S
	local d = math.clamp(to.Magnitude, math.abs(a - b) + 0.1, (a + b) * 0.995)
	local dir = to.Unit
	local T = S + dir * d
	local side = pole - dir * pole:Dot(dir)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.yAxis
	local x = (a * a - b * b + d * d) / (2 * d)
	local e2 = S + dir * x + side * math.sqrt(math.max(0, a * a - x * x))
	aim(up, E - S, e2 - S, w)
	E, H = low.TransformedWorldCFrame.Position, tip.TransformedWorldCFrame.Position
	aim(low, H - E, T - E, w)
end

local function smooth(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function runGiant(m: Model)
	local bones: { [string]: Bone } = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and not bones[d.Name] then
			bones[d.Name] = d
		end
	end
	local mem: { [Bone]: { base: CFrame, wrote: CFrame } } = {}
	local feet: { [string]: Vector3 } = {}
	local conn: RBXScriptConnection
	conn = RunService.PreSimulation:Connect(function()
		if not m:IsDescendantOf(Workspace) then
			conn:Disconnect()
			return
		end
		local t = now() - LAG
		local bow = 0
		local bt0 = m:GetAttribute("BowT0")
		if type(bt0) == "number" then
			local k = smooth((t - bt0) / math.max(0.1, m:GetAttribute("BowDur") or 1))
			bow = if m:GetAttribute("BowDir") == -1 then 1 - k else k
		end
		local handW, handAt = 0, Vector3.zero
		local ht0 = m:GetAttribute("HandT0")
		if type(ht0) == "number" then
			local drag, hold = m:GetAttribute("HandDrag") or 1, m:GetAttribute("HandHold") or 0.5
			local el = t - ht0
			handW = smooth((el + 1.0) / 1.0) * smooth((drag + hold + 1.0 - el) / 1.0)
			local k = smooth(el / drag)
			local x0, x1 = m:GetAttribute("HandX0") or 0, m:GetAttribute("HandX1") or 0
			-- ก่อนแตะ / หลังยก: มือลอยเหนือหลังคา
			local lift = 6 * (1 - smooth((el + 0.35) / 0.35) * smooth((drag + hold - el) / 0.35 + 0.0))
			handAt = Vector3.new(x0 + (x1 - x0) * k, (m:GetAttribute("HandY") or 12.5) + lift, m:GetAttribute("HandZ") or 14)
		end
		if bow <= 0.001 and handW <= 0.001 then
			-- ท่าเดินปกติ: ปล่อยให้ Animator คุมทั้งหมด (คืนท่าเดิมครั้งเดียว)
			if next(mem) ~= nil then
				for b, r in pairs(mem) do
					if b.Transform:FuzzyEq(r.wrote, 1e-4) then
						b.Transform = r.base
					end
				end
				table.clear(mem)
				table.clear(feet)
			end
			return
		end
		-- ท่าเดิมของเฟรมนี้ (Animator ไม่ได้เขียนใหม่ = ใช้ค่าที่จำไว้)
		for _, n in ipairs(ORDER) do
			local b = bones[n]
			if b then
				local r = mem[b]
				if not r then
					r = { base = b.Transform, wrote = b.Transform }
					mem[b] = r
				elseif not b.Transform:FuzzyEq(r.wrote, 1e-4) then
					r.base = b.Transform
				end
				b.Transform = r.base
			end
		end
		local pv = m:GetPivot()
		local right, look = pv.RightVector, pv.LookVector
		-- เท้าอยู่ที่เดิม สะโพกลดลง เข่างอไปข้างหน้า
		for _, s in ipairs({ "L", "R" }) do
			local f = bones["foot." .. s]
			if f then
				feet[s] = f.TransformedWorldCFrame.Position
			end
		end
		local hips = bones.hips
		if hips then
			addWorldOffset(hips, Vector3.new(0, -DROP * bow, 0) - look * (1.0 * bow))
		end
		for _, s in ipairs({ "L", "R" }) do
			local th, sh, f = bones["thigh." .. s], bones["shin." .. s], bones["foot." .. s]
			if th and sh and f and feet[s] then
				local out = right * (if s == "R" then 0.35 else -0.35)
				twoBone(th, sh, f, feet[s], look + out, 1)
			end
		end
		for _, n in ipairs({ "spine", "chest", "neck", "head" }) do
			local b = bones[n]
			if b then
				addWorldRotation(b, CFrame.fromAxisAngle(right, math.rad(BEND[n]) * bow))
			end
		end
		-- แขนสองข้างยันพื้นข้างหน้า (ไม่งั้นแขนกางไปข้างหลังเหมือนปีก)
		for _, s in ipairs({ "L", "R" }) do
			local up, low, tip = bones["upper_arm." .. s], bones["forearm." .. s], bones["hand." .. s]
			if up and low and tip then
				local side = if s == "R" then 1 else -1
				local to = pv:PointToWorldSpace(Vector3.new(side * 13, 5, -11))
				twoBone(up, low, tip, to, right * side - look * 0.4, bow)
			end
		end
		if handW > 0 then
			local up, low, tip = bones["upper_arm.R"], bones["forearm.R"], bones["hand.R"]
			if up and low and tip then
				twoBone(up, low, tip, handAt, Vector3.new(0, 1, 0) + right * 0.5, handW)
			end
		end
		for b, r in pairs(mem) do
			r.wrote = b.Transform
		end
	end)
end
CollectionService:GetInstanceAddedSignal("GiantGhost"):Connect(function(m)
	if m:IsA("Model") and m:IsDescendantOf(Workspace) then
		runGiant(m)
	end
end)
for _, m in ipairs(CollectionService:GetTagged("GiantGhost")) do
	if m:IsA("Model") and m:IsDescendantOf(Workspace) then
		runGiant(m)
	end
end

-- ---------------------------------------------------------------- เชื่อมต่อ
local remote = remotes:WaitForChild("BigFX", 60)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any, d: any, e: any, f: any)
		local my = token
		if kind == "steps" then
			for _, st in ipairs(a) do
				local wait = st.t + LAG - now()
				if wait > -0.3 then
					task.delay(math.max(0, wait), function()
						if token == my then
							step(st.p)
						end
					end)
				end
			end
		elseif kind == "cry" then
			cry(a, b, c or 1)
		elseif kind == "breath" then
			breath(a, b, c, d, e)
		elseif kind == "hand" then
			task.delay(math.max(0, a + LAG - now()), function()
				if token == my then
					hand(a + LAG, b, c, d, e, f)
				end
			end)
		elseif kind == "slam" then
			task.delay(LAG, function()
				if token == my then
					ShopFX.RoofSlam(a, b)
				end
			end)
		elseif kind == "stop" then
			token += 1
		end
	end)
end
