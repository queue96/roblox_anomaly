--!strict
-- ScarecrowRoam.server.luau — หุ่นไล่กาย้ายจุดเมื่อไม่มีใครมอง (Weeping Angel) ตัดสินที่ server ที่เดียว
-- (ผู้ใช้ 2026-11-22 "หุ่นไล่กาย้ายที่ทำให้เห็นเหมือนกันทุกคน": เดิม client/SceneryGhosts แต่ละเครื่องสุ่มย้ายเอง
--  ย้ายหุ่นตัวจริงในเครื่องตัวเอง = แต่ละคนเห็นหุ่นคนละที่)
--   · กติกาเดิม: ครึ่งแรกของคืน (NightProgress < 0.5) อยู่ที่เดิม · ย้ายได้คืนละไม่เกิน MAX_MOVES ครั้ง ทุก 65-110 วิ
--     ย้ายเฉพาะตอนไม่มีผู้เล่นคนไหนหันไปทางจุดเดิมและจุดใหม่ (ดูจากทิศหัวตัวละคร) · ไฟดับไม่ย้าย
--   · เปิดร้าน (คืนใหม่) / ไฟกลับมาหลังดับ = กลับเสากลางทุ่ง (จุด 1) ตอนไม่มีใครมอง
--   · บอก client ผ่าน attribute ที่ตัวหุ่น: Spot (เลขจุด, "vanish" = หายตัว) + SpotCFrame (ตำแหน่งที่ยืนจริง)
--     client/SceneryGhosts ยังซ่อนหุ่นเองตอนไฟดับ / ตอนหุ่นดักข้างหลัง แล้วคืนกลับมาที่ SpotCFrame
--   · แผง admin: ServerStorage.ScarecrowRoamCmd (BindableEvent) "move" = จุดถัดไป, "home" = กลับเสา
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- จุดที่หุ่นไปยืนได้ (x, z) เหมือนชุดเดิมของ client · "vanish" = หายตัวไปเลยชั่วคราว
local SPOTS: { any } = {
	{ 12.16, -45.64 }, -- 1 แปลงนากลางทุ่ง (บ้าน)
	{ -23.5, -51.0 }, -- 2 หน้าเถียงนาร้าง
	{ 19.5, 4.5 }, -- 3 ข้างเพิงหน้าดงกล้วย
	{ -31.0, 2.0 }, -- 4 ลานหญ้าหน้าศาล
	"vanish", -- 5 หายตัว
}
local MAX_MOVES = 2
local EVERY = { 65, 110 }
local LOOK_DIST = 220 -- ไกลกว่านี้หมอกกลืน ไม่นับว่าเห็น (เท่า client UNSEEN_DIST)
local LOOK_DOT = 0.15 -- มุมมองด้านหน้า ~160° รอบทิศหัว (ใจกว้างไว้: กล้องจริงอยู่ที่ client)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ap = Workspace:WaitForChild("AnomalyProps")

local cmd = ServerStorage:FindFirstChild("ScarecrowRoamCmd") :: BindableEvent?
if not cmd then
	local b = Instance.new("BindableEvent")
	b.Name = "ScarecrowRoamCmd"
	b.Parent = ServerStorage
	cmd = b
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

local function shopFront(): Vector3
	local wps = Workspace:FindFirstChild("VehicleWaypoints")
	local stop = wps and wps:FindFirstChild("StopPoint") :: BasePart?
	return if stop then stop.Position else Vector3.new(-4, 2, -7)
end

-- หุ่นในฉาก (GameManager อาจสลับเป็น ScarecrowV2 ตอนเริ่ม: หาใหม่ทุกครั้ง)
local homeOffset: number? = nil
local function scarecrow(): Model?
	local sc = ap:FindFirstChild("Scarecrow") :: Model?
	if sc and homeOffset == nil then
		local piv = sc:GetPivot()
		homeOffset = piv.Position.Y - groundAt(piv.Position.X, piv.Position.Z)
	end
	return sc
end

local spot = 1
local lastCF: CFrame? = nil
local function spotCF(idx: number): CFrame?
	local c = SPOTS[idx]
	if type(c) ~= "table" then
		return nil
	end
	local y = groundAt(c[1], c[2]) + (homeOffset or 0)
	local p = Vector3.new(c[1], y, c[2])
	local f = shopFront()
	-- หน้าหุ่นอยู่ฝั่ง -LookVector ของ pivot: หมุน 180° ให้หันหน้าเข้าหาร้าน (เหมือนเดิมใน client)
	return CFrame.lookAt(p, Vector3.new(f.X, y, f.Z)) * CFrame.Angles(0, math.pi, 0)
end

local function place(idx: number)
	local sc = scarecrow()
	if not sc then
		return
	end
	spot = idx
	local cf = spotCF(idx)
	if cf then
		lastCF = cf
		sc:PivotTo(cf)
		sc:SetAttribute("Spot", idx)
		sc:SetAttribute("SpotCFrame", cf)
	else
		-- หายตัว: ลงไปใต้ดิน (ทุกเครื่องเห็นเหมือนกัน) จำจุดล่าสุดไว้ให้ client
		local cur = lastCF or sc:GetPivot()
		sc:PivotTo(cur - Vector3.new(0, 300, 0))
		sc:SetAttribute("Spot", "vanish")
		sc:SetAttribute("SpotCFrame", cur - Vector3.new(0, 300, 0))
	end
end

local function seen(p: Vector3): boolean
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		local head = ch and (ch:FindFirstChild("Head") or ch:FindFirstChild("BodyHead") or ch:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if head then
			for _, dy in ipairs({ 1.0, 3.2, 5.2 }) do
				local to = (p + Vector3.new(0, dy, 0)) - head.Position
				local d = to.Magnitude
				if d > 0.1 and d <= LOOK_DIST and (to / d):Dot(head.CFrame.LookVector) > LOOK_DOT then
					return true
				end
			end
		end
	end
	return false
end

local function currentPos(): Vector3
	local cf = spotCF(spot)
	if cf then
		return cf.Position
	end
	local sc = scarecrow()
	return if sc then sc:GetPivot().Position else Vector3.new(12.16, 0, -45.64)
end

local function powerOn(): boolean
	return ReplicatedStorage:GetAttribute("PowerOn") ~= false
end

local function inCutscene(): boolean
	return ReplicatedStorage:GetAttribute("CutsceneRunning") == true
end

-- กลับเสา (จุด 1) ตอนไม่มีใครมองทั้งจุดปัจจุบันและเสา (รอไม่เกิน 60 วิ แล้วกลับเลย)
local homeToken = 0
local function goHome()
	homeToken += 1
	local my = homeToken
	task.spawn(function()
		local t0 = os.clock()
		while my == homeToken and os.clock() - t0 < 60 do
			local home = spotCF(1)
			if not (seen(currentPos()) or (home and seen(home.Position))) then
				break
			end
			task.wait(0.5)
		end
		if my == homeToken and powerOn() then
			place(1)
		end
	end)
end

local moves = 0
task.spawn(function()
	task.wait(5) -- รอ GameManager สลับหุ่นเป็นรุ่นใหม่ก่อน
	if scarecrow() then
		place(1)
	end
	local wasOpen = remotes:GetAttribute("ShopOpen") == true
	local wasPower = powerOn()
	local nextMove = os.clock() + EVERY[1] + math.random() * (EVERY[2] - EVERY[1])
	while true do
		task.wait(0.5)
		local open = remotes:GetAttribute("ShopOpen") == true
		local power = powerOn()
		if open ~= wasOpen then
			-- คืนใหม่ / ปิดร้าน: นับใหม่ กลับเสา
			wasOpen = open
			moves = 0
			goHome()
		end
		if power and not wasPower and open then
			goHome() -- ไฟกลับมาหลังดับ
		end
		wasPower = power
		if os.clock() >= nextMove then
			nextMove = os.clock() + EVERY[1] + math.random() * (EVERY[2] - EVERY[1])
			local progress = (remotes:GetAttribute("NightProgress") :: number?) or 0
			local test = ReplicatedStorage:GetAttribute("TestMode") == true
			if open and power and not test and not inCutscene() and progress >= 0.5 and moves < MAX_MOVES and scarecrow() then
				-- รอให้ไม่มีใครมองจุดปัจจุบัน (ไม่เกิน 40 วิ)
				local t0 = os.clock()
				while spot ~= 5 and seen(currentPos()) and os.clock() - t0 < 40 do
					task.wait(0.4)
				end
				if powerOn() and (spot == 5 or not seen(currentPos())) then
					local cands = {}
					for i = 1, #SPOTS do
						if i ~= spot then
							local cf = spotCF(i)
							if not cf or not seen(cf.Position) then
								table.insert(cands, i)
							end
						end
					end
					if #cands > 0 then
						local pick = cands[math.random(#cands)]
						place(pick)
						moves += 1
						print(("🌾 หุ่นไล่กาย้ายไปจุด %s (คืนนี้ %d/%d)"):format(tostring(SPOTS[pick] == "vanish" and "หายตัว" or pick), moves, MAX_MOVES))
					end
				end
			end
		end
	end
end)

;(cmd :: BindableEvent).Event:Connect(function(what: string)
	if what == "move" then
		place((spot % #SPOTS) + 1)
	elseif what == "home" then
		homeToken += 1
		place(1)
	end
end)
