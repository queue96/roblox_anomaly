--!strict
-- HumanEmotesRunner.client.luau
-- เล่นท่าอารมณ์ (shared/HumanEmotes) และขาเดินของคนเต้นตามขบวน บนกระดูกของตัวละครชาวบ้านทุกตัวในเครื่องนี้
--   ตัวที่ติด tag "HumanEmote" (HumanEmotes.Play / server ติดให้คนเต้นตามรถ):
--     attribute Emote/EmoteStart/EmoteStop -> ท่าจาก HumanClipData ผสมทับท่าของ Animator (เข้า 0.25 วิ / ออก 0.3 วิ)
--     attribute WalkLegs (studs/วิ) -> สะโพกกับขาใช้ท่าเดิน ส่วนบนเต้นต่อ (ผสมเข้า/ออกนุ่มๆ)
-- เขียน Bone.Transform หลังท่าทางคำนวณเสร็จ (PreSimulation) แบบเดียวกับ shared/HeadTurn:
--   Animator ไม่ได้เขียนกระดูกทุกเฟรม -> จำท่าฐาน (ของ Animator) ไว้ ไม่เอาค่าที่เราเขียนเองไปผสมซ้ำ
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("HumanClipData")) :: any
local PoseHooks = require(Shared:WaitForChild("PoseHooks")) :: any

local TAG = "HumanEmote"
local FADE_IN, FADE_OUT = 0.25, 0.3
local WALK_CLIP_SPEED = 4.3 -- ท่าเดินความเร็ว 1 = เดิน 4.3 studs/วิ (server/HumanNPC)
-- ถือของ (Tool ในตัวละคร) -> ท่าแขนจาก HumanClipData ทับท่าเดิน/ยืน (สลับมือ 2026-11-03)
--   ไฟฉาย: มือขวา (shared/HeadTurn ชี้แขนตามสายตาต่อ) / แกลลอน: มือซ้ายหิ้วข้างตัว / ขนมตาลบนใบตอง: มือซ้ายแบหงาย
--   มือไหนถืออะไร: shared/HeadTurn.Sides (ผู้เล่นเลือกมือถือไฟฉายในตั้งค่า ค่าเริ่มต้นขวา ของอื่นอยู่มืออีกข้าง)
local HeadTurn = require(Shared:WaitForChild("HeadTurn")) :: any
local HOLD_CLIPS: { [string]: { L: string, R: string, flash: boolean? } } = {
	FuelCan = { L = "carry_gallon_l", R = "carry_gallon_r" },
	ThaiDessert = { L = "hold_tray_l", R = "hold_tray_r" },
	FrogFlashlight = { L = "hold_flashlight", R = "hold_flashlight_r", flash = true },
}

-- ---------------------------------------------------------------- ข้อมูลท่า -> CFrame (แปลงครั้งเดียวต่อท่า)
type Clip = { length: number, once: boolean, times: { number }, tracks: { [string]: { CFrame } } }
local clips: { [string]: Clip } = {}
local function clipOf(name: string): Clip?
	local c = clips[name]
	if c then
		return c
	end
	local d = Data[name]
	if not d then
		return nil
	end
	local tracks = {}
	for bone, keys in pairs(d.tracks) do
		local list = {}
		for i, k in ipairs(keys) do
			list[i] = CFrame.new(k[1], k[2], k[3], k[4], k[5], k[6], k[7])
		end
		tracks[bone] = list
	end
	c = { length = d.length, once = d.once, times = d.times, tracks = tracks }
	clips[name] = c
	return c
end

-- ท่าของกระดูกนี้ ณ เวลา t (วินาทีในคลิป)
local function sample(c: Clip, keys: { CFrame }, t: number): CFrame
	if #keys == 1 then
		return keys[1]
	end
	local times = c.times
	local n = math.min(#times, #keys)
	if t <= times[1] then
		return keys[1]
	end
	for i = 1, n - 1 do
		if t < times[i + 1] then
			local a = (t - times[i]) / (times[i + 1] - times[i])
			return keys[i]:Lerp(keys[i + 1], a)
		end
	end
	return keys[n]
end

local function clipTime(c: Clip, elapsed: number): number
	if c.once then
		return math.min(elapsed, c.length)
	end
	return elapsed % c.length
end

-- ---------------------------------------------------------------- สถานะต่อตัว
type State = { bones: { [string]: Bone }, base: { [Bone]: CFrame }, written: { [Bone]: CFrame }, legW: number, legPhase: number, touched: { [Bone]: boolean }, holdW: { [string]: number } }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(m: Model): State
	local st = states[m]
	if not st then
		local bones = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("Bone") and not bones[d.Name] then
				bones[d.Name] = d
			end
		end
		st = { bones = bones, base = {}, written = {}, legW = 0, legPhase = 0, touched = {}, holdW = {} }
		states[m] = st
	end
	return st
end

-- ท่าฐานของกระดูก (ของ Animator / ระบบอื่น) ไม่ใช่ค่าที่เราเขียนไว้เฟรมก่อน
local function baseOf(st: State, b: Bone): CFrame
	local cur = b.Transform
	local base = if st.written[b] == cur then (st.base[b] or cur) else cur
	st.base[b] = base
	return base
end

local function write(st: State, b: Bone, cf: CFrame)
	b.Transform = cf
	st.written[b] = cf
	st.touched[b] = true
end

-- คืนกระดูกที่เคยเขียนแต่เฟรมนี้ไม่ได้เขียนแล้ว กลับเป็นท่าฐาน
local function release(st: State, keep: { [Bone]: boolean })
	for b in pairs(st.touched) do
		if not keep[b] then
			if st.written[b] == b.Transform and st.base[b] then
				b.Transform = st.base[b]
			end
			st.touched[b] = nil
			st.written[b] = nil
		end
	end
end

local Players = game:GetService("Players")
local NpcLife = require(Shared:WaitForChild("NpcLife")) :: any
local LOOK_PLAYER_RANGE = 18 -- studs: NPC บางทีหันมองผู้เล่นที่อยู่ใกล้
local lastPos: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local avgSpeed: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local movingNow: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local stillW: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
-- ท่าประกอบคำพูดของคนนั่งรถ (shared/SeatGestureData: delta เทียบเฟรมแรก ลำตัว/คอ/หัว/ไหล่) — client/NpcGestures ตั้ง attribute
--   SeatGesture = ชื่อท่า, SeatGestureT0 = os.clock() ตอนเริ่ม, SeatGestureLen = ความยาว (ไม่ใส่ = ทั้งท่า)
local SeatGest = require(Shared:WaitForChild("SeatGestureData")) :: any
type GClip = { length: number, times: { number }, tracks: { [string]: { CFrame } } }
local gclips: { [string]: GClip } = {}
local function gclipOf(name: string): GClip?
	local c = gclips[name]
	if c then
		return c
	end
	local d = SeatGest[name]
	if not d then
		return nil
	end
	local tracks = {}
	for bone, keys in pairs(d.tracks) do
		local list = {}
		for i, k in ipairs(keys) do
			list[i] = CFrame.new(0, 0, 0, k[1], k[2], k[3], k[4])
		end
		tracks[bone] = list
	end
	c = { length = d.length, times = d.times, tracks = tracks }
	gclips[name] = c
	return c
end
local function seatGestureDeltas(rig: Instance): { [string]: CFrame }?
	local name, t0 = rig:GetAttribute("SeatGesture"), rig:GetAttribute("SeatGestureT0")
	if type(name) ~= "string" or type(t0) ~= "number" then
		return nil
	end
	local c = gclipOf(name)
	if not c then
		return nil
	end
	local len = rig:GetAttribute("SeatGestureLen")
	local dur = if type(len) == "number" then len else c.length
	local el = os.clock() - t0
	if el < 0 or el > dur then
		return nil
	end
	local w = math.clamp(math.min(el / 0.3, (dur - el) / 0.4), 0, 1)
	w = w * w * (3 - 2 * w)
	local tt = el % c.length
	local times = c.times
	local i = 1
	while i < #times and times[i + 1] <= tt do
		i += 1
	end
	local a = if i < #times then (tt - times[i]) / math.max(1e-4, times[i + 1] - times[i]) else 0
	local out = {}
	for bone, keys in pairs(c.tracks) do
		local k0 = keys[math.min(i, #keys)]
		local k1 = keys[math.min(i + 1, #keys)]
		out[bone] = CFrame.identity:Lerp(k0:Lerp(k1, a), w)
	end
	return out
end
local LIFE_ORDER = { "hips", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R", "spine", "chest", "shoulder.L", "shoulder.R", "neck", "head" } -- พ่อก่อนลูก
RunService.PreSimulation:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	-- ตัวที่ติด tag + ตัวผู้เล่นทุกคน (ถือของ / ท่าอารมณ์ของผู้เล่น)
	local list = CollectionService:GetTagged(TAG)
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c:FindFirstChild("RootPart") and not CollectionService:HasTag(c, TAG) then
			table.insert(list, c)
		end
	end
	-- NPC ทุกแบบตัว (ชั้นมีชีวิต: tag ที่ DriverNPC) — ยกเว้นตัวที่ Walker ข้างนอกติด tag ท่าอารมณ์อยู่แล้ว (ทำในรอบของ Walker)
	for _, c in ipairs(CollectionService:GetTagged("HumanLife")) do
		local parent = c.Parent
		if not CollectionService:HasTag(c, TAG) and not (parent and CollectionService:HasTag(parent, TAG)) then
			table.insert(list, c)
		end
	end
	for _, m in ipairs(list) do
		if not (m:IsA("Model") and m:IsDescendantOf(workspace)) then
			continue
		end
		local st = stateOf(m)
		local keep: { [Bone]: boolean } = {}
		local poses: { [Bone]: CFrame } = {}
		-- 1) ท่าอารมณ์
		local name = m:GetAttribute("Emote")
		local start = m:GetAttribute("EmoteStart")
		local stop = m:GetAttribute("EmoteStop")
		local emoteW = 0
		local c = if type(name) == "string" and type(start) == "number" then clipOf(name) else nil
		if c and type(start) == "number" then
			emoteW = math.clamp((t - start) / FADE_IN, 0, 1)
			if type(stop) == "number" then
				emoteW = math.min(emoteW, 1 - math.clamp((t - stop) / FADE_OUT, 0, 1))
			end
			if emoteW > 0 then
				local ct = clipTime(c, t - start)
				for bone, keys in pairs(c.tracks) do
					local b = st.bones[bone]
					if b then
						poses[b] = baseOf(st, b):Lerp(sample(c, keys, ct), emoteW)
					end
				end
			end
		end
		-- 2) ขาเดินตามขบวน (ระหว่างเล่นท่าอารมณ์เต็มตัว ไม่ใช้)
		local speed = m:GetAttribute("WalkLegs")
		local wantLegs = if type(speed) == "number" and speed > 0.05 and emoteW < 0.5 then 1 else 0
		st.legW += (wantLegs - st.legW) * math.min(1, dt * 5)
		if st.legW < 0.002 then
			st.legW = 0
		end
		if type(speed) == "number" and speed > 0 then
			st.legPhase += dt * speed / WALK_CLIP_SPEED
		end
		local walk = if st.legW > 0 then clipOf("walk") else nil
		if walk then
			local wt = st.legPhase % walk.length
			for bone, keys in pairs(walk.tracks) do
				local b = st.bones[bone]
				if b then
					local from = poses[b] or baseOf(st, b)
					poses[b] = from:Lerp(sample(walk, keys, wt), st.legW)
				end
			end
		end
		-- 3) ท่าถือของ (เฉพาะกระดูกแขนในคลิป)
		local flashSide, itemSide = HeadTurn.Sides(m)
		for toolName, pair in pairs(HOLD_CLIPS) do
			local tool = m:FindFirstChild(toolName)
			for _, sd in ipairs({ "L", "R" }) do
			local clipName = pair[sd]
			local mine = sd == (if pair.flash then flashSide else itemSide)
			local want = if mine and tool and tool:IsA("Tool") and emoteW < 0.5 then 1 else 0
			local w = st.holdW[clipName] or 0
			w += (want - w) * math.min(1, dt * 8)
			if w < 0.002 then
				w = 0
			end
			st.holdW[clipName] = w
			local hc = if w > 0 then clipOf(clipName) else nil
			if hc then
				local ht = (t * 1.0) % hc.length
				for bone, keys in pairs(hc.tracks) do
					local b = st.bones[bone]
					if b then
						local from = poses[b] or baseOf(st, b)
						poses[b] = from:Lerp(sample(hc, keys, ht), w)
					end
				end
			end
			end
		end
		-- 4) ชั้นมีชีวิต (shared/NpcLife): หายใจ มองไปมา ถ่ายน้ำหนัก ขยับเล็กๆ — NPC เท่านั้น ใกล้กล้อง ไม่ใช่ผี/ท่านอน
		--   ตัวที่มีกระดูก = DriverNPC (Walker ห่ออยู่ / หรือ DriverNPC ในรถเอง) · Clip อยู่ที่ Walker หรือรถ (key ของ HumanNPC)
		local rigM = (m:FindFirstChild("DriverNPC") or m) :: Instance
		local root = rigM:FindFirstChild("RootPart") or rigM:FindFirstChild("HumanoidRootPart")
		local holder = rigM.Parent
		local clip = rigM:GetAttribute("Clip") or m:GetAttribute("Clip") or (holder and holder:GetAttribute("Clip"))
		local skipLife = Players:GetPlayerFromCharacter(m) ~= nil or m:GetAttribute("NoLife") == true
			or (type(clip) == "string" and (string.sub(clip, 1, 5) == "ghost" or string.find(clip, "lying") ~= nil))
		if not skipLife and root and root:IsA("BasePart") and (root.Position - camPos).Magnitude < NpcLife.RANGE then
			local seated = rigM:GetAttribute("SeatClip") ~= nil
			-- เดินอยู่ไหม: ดูจากระยะที่ RootPart เลื่อน (คนเดินถนนเลื่อนด้วย CFrame ความเร็ว physics = 0)
			--   ตำแหน่งจาก server มาเป็นช่วงๆ: บางเฟรมเลื่อน บางเฟรมนิ่ง -> เฉลี่ยความเร็ว + ไล่น้ำหนัก "ยืนนิ่ง" นุ่มๆ
			--   (เดิมเช็คเฟรมต่อเฟรม การถ่ายน้ำหนักติด-ดับสลับทุกเฟรม = ตัวสั่น)
			local lp = lastPos[m]
			local raw = if lp and dt > 0 then ((root.Position - lp) * Vector3.new(1, 0, 1)).Magnitude / dt else 0
			lastPos[m] = root.Position
			local sp = (avgSpeed[m] or 0) + (math.min(raw, 30) - (avgSpeed[m] or 0)) * math.min(1, dt * 3)
			avgSpeed[m] = sp
			local wasMoving = movingNow[m] == true
			local moving = not seated and (if wasMoving then sp > 0.8 else sp > 1.6)
			movingNow[m] = moving
			local sw = (stillW[m] or 1) + ((if moving then 0 else 1) - (stillW[m] or 1)) * math.min(1, dt * 2.5)
			stillW[m] = sw
			local lookAt: Vector3? = nil
			local bestD = LOOK_PLAYER_RANGE
			for _, p in ipairs(Players:GetPlayers()) do
				local h = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
				if h then
					local d = (h.Position - root.Position).Magnitude
					if d < bestD then
						lookAt, bestD = h.Position, d
					end
				end
			end
			local ok, offs = pcall(NpcLife.Offsets, rigM, root, os.clock(), dt, { seated = seated, noHead = seated or rigM:GetAttribute("HeadByRider") == true, riderYaw = rigM:GetAttribute("RiderLookYaw"), moving = moving, still = sw, emoteW = emoteW, lookAt = lookAt })
			if ok then
				local gest = seatGestureDeltas(rigM) or {}
				for _, bname in ipairs(LIFE_ORDER) do
					local w = offs[bname]
					local g = gest[bname]
					local b = if w or g then st.bones[bname] else nil
					if b then
						local from = poses[b] or baseOf(st, b)
						if w then
							local f = b.TransformedWorldCFrame.Rotation
							from = from * (f:Inverse() * w * f)
						end
						poses[b] = if g then from * g else from
					end
				end
				-- ร่างผีซ้อน (HumanNPC.MakeDouble) ขยับตามตัวจริงเป๊ะ: ผีต้องไม่แข็งกว่าคน (ไม่งั้นดูออกว่าตัวไหนผี)
				local dbl = rigM:FindFirstChild("GhostDouble")
				if dbl and dbl:IsA("Model") then
					local st2 = stateOf(dbl)
					local keep2: { [Bone]: boolean } = {}
					for _, bname in ipairs(LIFE_ORDER) do
						local w = offs[bname]
						local g = gest[bname]
						local b2 = if w or g then st2.bones[bname] else nil
						if b2 then
							local v = baseOf(st2, b2)
							if w then
								local f2 = b2.TransformedWorldCFrame.Rotation
								v = v * (f2:Inverse() * w * f2)
							end
							write(st2, b2, if g then v * g else v)
							keep2[b2] = true
						end
					end
					release(st2, keep2)
				end
			end
		end
		for b, cf in pairs(poses) do
			write(st, b, cf)
			keep[b] = true
		end
		release(st, keep)
	end
	-- ท่าครบทุกตัวแล้ว: วางของในมือตามกระดูกที่เพิ่งเขียน (client/HeldItems)
	PoseHooks.Run(dt)
end)

-- ---------------------------------------------------------------- หน้าตา (สลับ SurfaceAppearance ผิว) + กะพริบตา
-- หน้าที่ต้องการ: attribute Face > หน้าคู่ท่าอารมณ์ที่เล่นอยู่ (HumanEmotes.EMOTE_FACE) > กะพริบตา > หน้าปกติ
-- ชุด SurfaceAppearance อยู่ ReplicatedStorage.Shared.HumanFaceSets (src/shared/HumanFaceSets.model.json)
-- สลับเฉพาะในเครื่องนี้ (ทุกเครื่องคิดจาก attribute เดียวกัน เลยเห็นเหมือนกัน) คืนชุดเดิมเมื่อกลับหน้าปกติ
local HumanEmotes = require(Shared:WaitForChild("HumanEmotes")) :: any
local faceSets = Shared:WaitForChild("HumanFaceSets", 10)
local BLINK_TIME = 0.13
local BLINK_RANGE = 60 -- ไกลกว่านี้ไม่ต้องกะพริบ (มองไม่เห็นอยู่ดี)
type FaceState = { shown: string?, nextBlink: number, blinkUntil: number }
local faceStates: { [Model]: FaceState } = setmetatable({}, { __mode = "k" }) :: any

local function skinParts(m: Model): { MeshPart }
	if m:FindFirstChild("BodyUpper", true) then
		return {}
	end
	local list = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("MeshPart") and (d.Name == "BodyHead" or d.Name == "Body" or string.sub(d.Name, 1, 5) == "Skin_") and d:FindFirstChildOfClass("SurfaceAppearance") then
			table.insert(list, d)
		end
	end
	return list
end

local function showFace(m: Model, fs: FaceState, face: string?)
	if fs.shown == face then
		return
	end
	local set = if face and faceSets then faceSets:FindFirstChild(face) else nil
	-- ภาพหน้ายังไม่ได้อัปโหลด (ไฟล์ในเครื่อง rbxasset:// = ผิวเป็นสีเทา): ไม่สลับ คงหน้าปกติไว้
	-- (สคริปต์อ่าน ColorMap ไม่ได้ -> ชุดที่อัปโหลดแล้วติด attribute Uploaded ใน HumanFaceSets.model.json)
	if set and set:GetAttribute("Uploaded") ~= true then
		set = nil
	end
	-- หน้าปกติ = ชุด "normal" (ผิวมาตรฐานของ human_base) — สคริปต์ในเกม Clone ผิวเดิมของ NPC ไม่ได้ และย้ายตัวเดิมกลับแล้วไม่ติด
	-- หาชิ้นผิวใหม่ทุกครั้ง (StreamingEnabled: ชิ้นอาจถูกส่งมาใหม่)
	local src = set or (faceSets and faceSets:FindFirstChild("normal"))
	local wantName = if set then face else nil
	if src then
		for _, part in ipairs(skinParts(m)) do
			local cur = part:FindFirstChildOfClass("SurfaceAppearance")
			local shownNow = cur and cur:GetAttribute("FaceSet")
			-- ผิวเดิมจาก server (ไม่มี FaceSet) + ต้องการหน้าปกติ = ไม่ต้องทำอะไร
			if shownNow ~= wantName then
				if cur then
					cur:Destroy()
				end
				local sa = src:Clone()
				sa:SetAttribute("FaceSet", wantName)
				sa.Parent = part
			end
		end
	end
	fs.shown = if set then face else nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.03 then
		return
	end
	acc = 0
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local list = CollectionService:GetTagged(TAG)
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and c:FindFirstChild("RootPart") and not CollectionService:HasTag(c, TAG) then
			table.insert(list, c)
		end
	end
	for _, m in ipairs(list) do
		if not (m:IsA("Model") and m:IsDescendantOf(workspace)) then
			continue
		end
		local fs = faceStates[m]
		if not fs then
			if not m:FindFirstChild("BodyHead", true) then
				continue
			end
			fs = { shown = nil, nextBlink = now + 1 + math.random() * 4, blinkUntil = 0 }
			faceStates[m] = fs
		end
		local want = m:GetAttribute("Face")
		if type(want) ~= "string" then
			local e = HumanEmotes.Playing(m)
			want = if e then HumanEmotes.EMOTE_FACE[e] else nil
		end
		if type(want) ~= "string" and m:GetAttribute("NoBlink") ~= true then
			if now >= fs.nextBlink then
				local head = m:FindFirstChild("BodyHead", true) :: BasePart?
				if head and (head.Position - camPos).Magnitude < BLINK_RANGE then
					fs.blinkUntil = now + BLINK_TIME
				end
				fs.nextBlink = now + 2 + math.random() * 4
			end
			if now < fs.blinkUntil then
				want = "blink"
			end
		end
		showFace(m, fs, if type(want) == "string" then want else nil)
	end
end)

