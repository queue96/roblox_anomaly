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
-- ถือของ (Tool ในตัวละคร) -> ท่าแขนจาก HumanClipData ทับท่าเดิน/ยืน (ไฟฉายยังอยู่มือซ้าย)
--   แกลลอน: มือขวาหิ้วข้างตัว / ขนมตาลบนใบตอง: มือขวาแบหงายหน้าท้อง
local HOLD_CLIPS: { [string]: string } = { FuelCan = "carry_gallon_r", ThaiDessert = "hold_tray_r" }

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
RunService.PreSimulation:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	-- ตัวที่ติด tag + ตัวผู้เล่นทุกคน (ถือของ / ท่าอารมณ์ของผู้เล่น)
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
		for toolName, clipName in pairs(HOLD_CLIPS) do
			local tool = m:FindFirstChild(toolName)
			local want = if tool and tool:IsA("Tool") and emoteW < 0.5 then 1 else 0
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

