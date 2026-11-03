--!strict
-- SceneryGhostWatch.client.luau
-- ผีฉาก (server/AnomalyManager.ShowScenery: ผีตานีหลังกอกล้วย / หุ่นไล่กาใกล้ร้าน / เงาหลังต้นไทร) โผล่ให้เห็นเฉยๆ นานๆ ครั้ง
--   พนมมือจนตาทิพย์เปิด แล้วหันไปเห็น (อยู่ในจอ ไม่มีอะไรบัง ไม่ไกลเกิน) = เสียงตกใจ 1 ครั้งต่อการโผล่ 1 รอบ
--     ไม่ได้สวดแล้วหันไปเจอ = ไม่มีเสียง (ของในฉากตอนปกติ เช่นหุ่นไล่กากลางทุ่ง ไม่ติด tag จึงไม่มีเสียงอยู่แล้ว)
--   มองค้างนาน (ผีอยู่กลางจอต่อเนื่อง STARE วินาที) = ผีพุ่งใส่หน้า เฉพาะคนที่มอง (client/JumpscareController _G.LocalJumpscare)
--     แล้วผีหายไปจากจอของคนนั้น (คนอื่นยังเห็นอยู่จนหมดเวลา)
-- ผีที่มากับลูกค้า (เติมน้ำมัน / เติมลม ฯลฯ) ไม่มีเสียงตอนเจอ: ผู้เล่นต้องสังเกตเอง
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local TAG = "SceneryGhost"
local SIGHT_ID = "rbxassetid://123314010660698" -- เสียงตกใจตอนเห็นผี (ชุดเดียวกับที่เคยใช้ตอนพนมมือเห็นผี)
local SIGHT_VOLUME = 0.5
local MAX_DIST = 140 -- ไกลกว่านี้ไม่นับว่าเห็น
local CENTER = 0.22 -- ผีอยู่ห่างกลางจอไม่เกินสัดส่วนนี้ (ของครึ่งจอ) = กำลังจ้องอยู่
local STARE = 2.5 -- จ้องต่อเนื่องกี่วินาทีถึงโดนพุ่งใส่หน้า
local GRACE = 0.4 -- ละสายตาสั้นๆ ไม่เกินนี้ ยังนับจ้องต่อ

type Watch = { stung: boolean, stare: number, away: number, scared: boolean }
local watches: { [string]: Watch } = {} -- key = ชนิด .. ShowId (โผล่รอบใหม่ = เริ่มใหม่)

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function focusPoint(m: Instance): Vector3?
	local eyes, n = Vector3.zero, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "Eye") then
			eyes += d.Position
			n += 1
		end
	end
	if n > 0 then
		return eyes / n
	end
	if m:IsA("Model") then
		local cf, size = m:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y * 0.3, 0)
	end
	return nil
end

-- ผีอยู่ในจอ + ไม่มีอะไรทึบบัง: คืนระยะจากกลางจอ (0 = กลางจอพอดี, 1 = ขอบจอ) หรือ nil = มองไม่เห็น
local function visibility(cam: Camera, m: Instance, p: Vector3): number?
	local camPos = cam.CFrame.Position
	if (p - camPos).Magnitude > MAX_DIST then
		return nil
	end
	local sp, onScreen = cam:WorldToViewportPoint(p)
	if not onScreen or sp.Z <= 0 then
		return nil
	end
	local vs = cam.ViewportSize
	local dx = (sp.X - vs.X / 2) / (vs.X / 2)
	local dy = (sp.Y - vs.Y / 2) / (vs.Y / 2)
	local ignore: { Instance } = { m }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	for _ = 1, 6 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(camPos, p - camPos, rayParams)
		if not hit then
			return math.sqrt(dx * dx + dy * dy)
		end
		-- ใบไม้ / ของโปร่ง / ไม่มีตัวตน ไม่นับว่าบัง
		if hit.Instance.Transparency > 0.5 or not hit.Instance.CanCollide then
			table.insert(ignore, hit.Instance)
		else
			return nil
		end
	end
	return math.sqrt(dx * dx + dy * dy)
end

local function sting()
	local s = Instance.new("Sound")
	s.Name = "SceneryGhostSting"
	s.SoundId = SIGHT_ID
	s.Volume = SIGHT_VOLUME
	s:SetAttribute("SoundCategory", "Music") -- ดังตอนพนมมือเท่านั้น: ไม่โดน PrayMuffle (กลุ่ม SFX อู้อี้ตอนสวด)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(30, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- ซ่อนผีจากจอเรา (คนอื่นยังเห็น)
local function hideLocally(m: Instance)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
	if m:IsA("BasePart") then
		m.LocalTransparencyModifier = 1
	end
end

-- ตาทิพย์เปิดอยู่ (PrayerController ตั้ง attribute Open บน Lighting.PrayerSight)
local function sightOpen(): boolean
	local grade = Lighting:FindFirstChild("PrayerSight")
	return player:GetAttribute("Praying") == true and grade ~= nil and grade:GetAttribute("Open") == true
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	local step = acc
	acc = 0
	local cam = Workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not cam or not hum or hum.Health <= 0 or Lighting:GetAttribute("Cutscene") == true then
		return
	end
	local live: { [string]: boolean } = {}
	for _, m in ipairs(CollectionService:GetTagged(TAG)) do
		if not m:IsDescendantOf(Workspace) then
			continue
		end
		local key = tostring(m:GetAttribute("SceneryKind")) .. ":" .. tostring(m:GetAttribute("ShowId"))
		live[key] = true
		local w = watches[key]
		if not w then
			w = { stung = false, stare = 0, away = 0, scared = false }
			watches[key] = w
			-- โผล่รอบใหม่: คืนการมองเห็น (เคยซ่อนจากจอเราไว้ตอนโดนหลอกรอบก่อน)
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		if w.scared then
			continue
		end
		local p = focusPoint(m)
		local off = p and visibility(cam, m, p)
		if off then
			if not w.stung and sightOpen() then
				w.stung = true
				sting()
			end
			if off <= CENTER then
				w.stare += step
				w.away = 0
			else
				w.away += step
			end
		else
			w.away += step
		end
		if w.away > GRACE then
			w.stare = 0
		end
		if w.stare >= STARE then
			w.scared = true
			local kind = tostring(m:GetAttribute("SceneryKind"))
			if _G.LocalJumpscare then
				_G.LocalJumpscare("Scenery_" .. kind, m)
			end
			task.delay(0.15, function()
				hideLocally(m)
			end)
		end
	end
	for k in pairs(watches) do
		if not live[k] then
			watches[k] = nil
		end
	end
end)
