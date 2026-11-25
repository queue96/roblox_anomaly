--!nonstrict
-- KnockFX.client.luau — ผีเคาะแผง (server/GhostLinger "knock"): เล่นทุกอย่างบนเครื่องนี้ตามตาราง shared/KnockPlan
--   * เสียงเคาะ + แผงสังกะสีกระแทก ตรงกับมือผี (มือ = client/GhostAnimRunner จากตารางเดียวกัน)
--   * ร้านสะเทือน (shared/ShopFX): หลอดไส้แกว่ง ไฟวูบ ฝุ่นร่วงจากสังกะสี จอสั่นตามระยะ จิ้งหรีดเงียบ
--   ทุกอย่างอยู่บนเครื่องนี้ ไม่แตะค่าฝั่ง Server (แผงคืนตำแหน่งเดิมทุกครั้ง)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KnockPlan = require(Shared:WaitForChild("KnockPlan")) :: any
local SoundBank = require(Shared:WaitForChild("SoundBank")) :: any
local ShopFX = require(Shared:WaitForChild("ShopFX")) :: any

local TAG = "KnockGhost"
local SOUND = "ShutterKnock"
local ONSET = 0.02 -- วิ: เริ่มก่อนนิดหนึ่ง (เสียงขึ้นทันทีแต่ดังสุดราว 0.1 วิ + แผงขยับเฟรมถัดไป)
local SHAKE_NEAR, SHAKE_FAR = 6, 28 -- studs จากจุดที่เคาะ

local interactive = Workspace:WaitForChild("InteractiveProps")
local function doorPart(): BasePart?
	return interactive:FindFirstChild("ShutterDoor") :: BasePart?
end

local function run(m: Model)
	local planText = m:GetAttribute("KnockPlan")
	local t0 = os.clock()
	while type(planText) ~= "string" and os.clock() - t0 < 5 and m.Parent do
		task.wait()
		planText = m:GetAttribute("KnockPlan")
	end
	local door = doorPart()
	if type(planText) ~= "string" or not door or not m.Parent then
		return
	end
	local hits = KnockPlan.Decode(planText)
	local hushTo = m:GetAttribute("KnockHushTo") or 0
	local closedY = door:GetAttribute("ClosedY") or 6
	local rest = CFrame.new(door.Position.X, closedY, door.Position.Z) * door.CFrame.Rotation
	local root = m:FindFirstChild("RootPart") :: BasePart?
	local px = if root then root.Position.X else door.Position.X
	local py = (if root then root.Position.Y else 2) + 4
	-- จุดเสียง: ที่มือเคาะบนแผง
	local att = ShopFX.Emitter(Vector3.new(px, py, door.Position.Z), "KnockEmitter")
	local pool: { Sound } = {}
	for _ = 1, 7 do
		local s = SoundBank.CreateSound(SOUND, att, 110)
		if s then
			s.RollOffMinDistance = 14
			table.insert(pool, s)
		end
	end
	local baseVol = if pool[1] then pool[1].Volume else 1
	local slot = 0
	local dustDoor, emDoor = ShopFX.Dust(Vector3.new(math.max(4, door.Size.X - 3), 0.2, 0.5), Vector3.new(door.Position.X, closedY + door.Size.Y / 2 - 0.2, door.Position.Z + 0.7))
	local dustRoof, emRoof = ShopFX.Dust(Vector3.new(22, 0.2, 9), Vector3.new(door.Position.X, closedY + door.Size.Y / 2 + 0.8, door.Position.Z + 6))
	ShopFX.Hush(m, true)
	local hushed = true
	local nextHit = 1
	local kickAt, kickAmp, kickTurn, kicking = 0, 0, 0, false
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local live = m.Parent ~= nil and m:GetAttribute("KnockEnd") ~= true
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		local closed = math.abs(door.Position.Y - closedY) < 0.3
		if hushed and (not live or now > hushTo) then
			hushed = false
			ShopFX.Hush(m, false)
		end
		-- เคาะ
		while live and nextHit <= #hits and now >= hits[nextHit].t - ONSET do
			local h = hits[nextHit]
			nextHit += 1
			if now - h.t < 0.4 and closed then -- เพิ่งเห็นตัวนี้กลางทาง / เครื่องค้าง: ไม่เล่นย้อนหลังรัวๆ
				local p = h.p
				local final = p >= 0.985
				slot = slot % math.max(1, #pool) + 1
				local s = pool[slot]
				if s then
					-- เบา = เสียงสูงสั้น (ข้อนิ้ว) · แรง = ทุ้มหนัก (ทั้งมือ)
					s.Volume = baseVol * (0.16 + 0.84 * p ^ 1.6) * (if final then 1.35 else 1)
					s.PlaybackSpeed = (if final then 0.74 else 1.32 - 0.42 * p) * (0.96 + math.random() * 0.08)
					s.TimePosition = 0
					s:Play()
				end
				kickAt, kickAmp, kicking = clock, 0.03 + 0.2 * p * p + (if final then 0.16 else 0), true
				kickTurn = math.clamp((px - door.Position.X) / 15, -1, 1) * 0.012 * p
				emDoor:Emit(math.floor(3 + 34 * p * p))
				if p > 0.75 then
					emRoof:Emit(math.floor(30 * p * p) + (if final then 30 else 0))
				end
				if p > 0.35 then
					ShopFX.Swing(p * p * (if final then 4.2 else 2.6))
				end
				ShopFX.Shake(att.WorldPosition, p * p * (if final then 1.5 else 0.75), if final then 0.7 else 0.26, SHAKE_NEAR, SHAKE_FAR)
				if p > 0.55 then
					ShopFX.Dip(if final then 0.96 else 0.35 + 0.4 * p, if final then 0.75 else 0.13)
				end
			end
		end
		-- แผงกระแทกเข้าในร้านแล้วสั่นกลับ
		if kicking then
			local t = clock - kickAt
			if not closed then
				kicking = false -- แผงกำลังถูกยก: ปล่อยให้ Server คุม
			elseif t > 0.4 or not live then
				door.CFrame = rest
				kicking = false
			else
				local k = math.exp(-t * 13) * math.cos(t * 52)
				door.CFrame = rest * CFrame.new(0, 0, kickAmp * k) * CFrame.Angles(0, -kickTurn * k, 0)
			end
		end
		-- จบ: คืนทุกอย่าง
		if not live and not kicking then
			conn:Disconnect()
			if closed and door.CFrame ~= rest and (door.Position - rest.Position).Magnitude < 1 then
				door.CFrame = rest
			end
			task.delay(3, function()
				dustDoor:Destroy()
				dustRoof:Destroy()
				att:Destroy()
			end)
		end
	end)
end

-- ร่างโคลนในจอผีหลอก (ViewportFrame) มี tag ติดมาด้วย: ไม่เล่นเอฟเฟกต์
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(m)
	if m:IsA("Model") and m:IsDescendantOf(Workspace) then
		task.spawn(run, m)
	end
end)
for _, m in ipairs(CollectionService:GetTagged(TAG)) do
	if m:IsA("Model") and m:IsDescendantOf(Workspace) then
		task.spawn(run, m)
	end
end
