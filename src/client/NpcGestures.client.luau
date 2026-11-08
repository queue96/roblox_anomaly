--!strict
-- NpcGestures.client.luau — ลูกค้า/ชาวบ้านที่ยืนอยู่ ทำท่าประกอบคำพูด (mocap 2026-11-09, ผู้ใช้: "แอนิเมชั่นมันแข็งมากๆ")
--   ฟัง Remotes.CustomerSpeech (server/CoreLoop say: key, หัวของคนพูด) -> เล่นท่าบนตัวนั้นเฉพาะในเครื่องนี้ (ทุกเครื่องได้ event เดียวกัน)
--   ไม่แก้ CoreLoop (ไฟล์ชนเพดาน local 200)
--   จ่ายเงิน = พยักหน้า · ถูกปฏิเสธ/ยอมแพ้ = ส่ายหน้า · รอนาน/จ่ายน้อย = ยักไหล่ · ทักทาย = โบกมือ · อื่นๆ = คุย (สุ่ม 2 แบบ) ราว 2.6 วิ
--   คนนั่งรถ (attribute SeatClip): ท่า mocap ทั้งตัวใช้ไม่ได้ (ลำตัวตั้งตรง ขายืดออกจากรถ) -> ตั้ง attribute SeatGesture ให้
--   client/HumanEmotesRunner เล่นแบบครึ่งตัวบน (shared/SeatGestureData: ลำตัว/คอ/หัว/ไหล่ บวกทับท่านั่ง มือยังจับแฮนด์ด้วย IK)
--   ทักทายของคนนั่งรถ = พยักหน้า (โบกมือต้องปล่อยแฮนด์)
--   ร่างผีซ้อน (GhostDouble) เล่นท่าเดียวกันพร้อมกัน (Animator ทุกตัวใต้ DriverNPC)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ids = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HumanAnimIds")) :: any
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local speech = remotes:WaitForChild("CustomerSpeech") :: RemoteEvent

local RANGE = 60 -- studs จากกล้อง
local TALK_TIME = 2.6
local FADE_IN, FADE_OUT = 0.3, 0.4

local function gestureFor(key: string): string?
	if key == "..." or key == "Queue_Chime" then
		return nil
	end
	local function starts(p: string): boolean
		return string.sub(key, 1, #p) == p
	end
	if starts("Pay_Slow") or starts("Impatient") then
		return "shrug"
	elseif starts("Pay_") then
		return "nod_yes"
	elseif starts("Rejected") or starts("Wrong_GiveUp") or starts("Shutter_Closed") or starts("Ghost_Chased") then
		return "shake_no"
	elseif starts("Greet") or starts("Hello") then
		return "wave"
	end
	return if math.random() < 0.5 then "talk" else "talk_2"
end

local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local playing: { [Instance]: { AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function trackOf(an: Animator, id: string): AnimationTrack
	local c = cache[an]
	if not c then
		c = {}
		cache[an] = c
	end
	local tr = c[id]
	if not tr then
		local a = Instance.new("Animation")
		a.AnimationId = id
		tr = an:LoadAnimation(a)
		tr.Priority = Enum.AnimationPriority.Action
		c[id] = tr
	end
	return tr
end

speech.OnClientEvent:Connect(function(key: any, head: any)
	if type(key) ~= "string" or typeof(head) ~= "Instance" then
		return
	end
	local d = (head :: Instance).Parent
	if not (d and d:IsA("Model") and d:GetAttribute("Human") == true) then
		return
	end
	local cam = workspace.CurrentCamera
	local root = d:FindFirstChild("RootPart") :: BasePart?
	if not (cam and root) or (root.Position - cam.CFrame.Position).Magnitude > RANGE then
		return
	end
	local g = gestureFor(key)
	if not g then
		return
	end
	if d:GetAttribute("SeatClip") ~= nil then
		local sg = if g == "wave" then "nod_yes" else g
		d:SetAttribute("SeatGesture", sg)
		d:SetAttribute("SeatGestureT0", os.clock())
		d:SetAttribute("SeatGestureLen", if sg == "talk" or sg == "talk_2" then TALK_TIME else nil)
		return
	end
	local char = d:GetAttribute("Char")
	local own = (type(char) == "string" and Ids[char]) or {}
	local id = own[g] or (Ids.human_base or {})[g]
	if not id then
		return
	end
	-- ท่าก่อนหน้าของตัวนี้ยังเล่นอยู่: หยุดก่อน
	for _, old in ipairs(playing[d] or {}) do
		old:Stop(0.2)
	end
	local list = {}
	for _, an in ipairs(d:GetDescendants()) do
		if an:IsA("Animator") then
			local tr = trackOf(an, id)
			local loop = g == "talk" or g == "talk_2"
			tr.Looped = loop
			tr:Play(FADE_IN)
			table.insert(list, tr)
			task.spawn(function()
				local t0 = os.clock()
				while tr.Length == 0 and os.clock() - t0 < 2 do
					task.wait(0.05)
				end
				-- ท่าครั้งเดียว: หยุดแบบค่อยๆ จางก่อนจบ (ปล่อยให้จบเองน้ำหนักตกทันที = ดีดกลับท่ายืน)
				local hold = if loop then TALK_TIME else math.max(0.2, tr.Length - FADE_OUT)
				task.wait(hold)
				if tr.IsPlaying then
					tr:Stop(FADE_OUT)
				end
			end)
		end
	end
	playing[d] = list
end)

