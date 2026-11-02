--!nonstrict
-- Cutscene.luau (ModuleScript ฝั่ง Server, require จาก CoreLoop)
-- คัทซีนเปิดคืน (Intro) และจบคืนแบบชนะ (Outro) — ตัวละคร/รถ/แผงร้านขยับจริงฝั่ง Server (ทุกคนเห็นเหมือนกัน)
-- ส่วนกล้อง แถบดำ ซับไตเติล แสงเย็น/เช้า และปุ่มข้าม อยู่ฝั่ง Client (client/CutsceneController.client.luau)
--
--   Intro: เย็นใกล้ค่ำ พี่ชายขี่รถพาผู้เล่นมาส่งหน้าร้าน -> "คืนนี้เฝ้าร้านให้พี่หน่อยนะ" -> ผู้เล่นตอบตกลง
--          -> ลงรถ พี่ชายเดินอ้อมไปหลังร้าน ดึงเชือกเปิดแผง -> ขี่รถออกไป -> ผู้เล่นเดินเข้าร้าน -> ตะวันตก เข้ากลางคืน
--   Outro: ตะวันขึ้น ผู้เล่นปิดร้านอยู่หลังร้าน -> พี่ชายขี่รถกลับมารับ -> ผู้เล่นเดินออกมาหา -> "เมื่อคืนเป็นไงบ้าง"
--          -> "ผ่านไปได้ด้วยดี" -> ขึ้นรถออกไป -> หน้าจอสรุปผล
--   แต่ละคนกดข้ามได้เอง (Client ส่ง "skip"): คนนั้นได้ตัวคืนทันที (Intro: ยืนในร้าน) คัทซีนเล่นต่อให้คนอื่น
--   ข้ามครบทุกคน = จบคัทซีนทันที (Intro: เปิดร้านให้เลย)
--
-- Remote: Remotes.Cutscene
--   S->C ("start", kind) / ("cam", spec) / ("say", key, who, head) / ("fade", black, seconds) / ("sunset", seconds)
--        ("end", kind) / ("summary", data)
--   C->S ("ready") หลังหน้าโหลดหาย / ("skip")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SoundBank"))

local Cutscene = {}

local D: { [string]: any } = nil -- ของจาก CoreLoop (Cutscene.Init)
local remote: RemoteEvent = nil
local ready: { [Player]: boolean } = {}
local participants: { [Player]: boolean } = {}
local skipped: { [Player]: boolean } = {}
local follow: { [Player]: { v: Model, cf: CFrame } } = {}
local running: string? = nil
local introWaiting = false -- คัทซีนเปิดคืนกำลังรอผู้เล่นโหลดเสร็จ (ผู้เล่นใหม่ที่ ready ช่วงนี้ = ได้ดูคัทซีน)
-- ReplicatedStorage.CutsceneRunning: ระบบเสียงสุ่ม (AnomalyManager / AmbienceController) เงียบระหว่างคัทซีน
local function setRunning(kind: string?)
	running = kind
	game:GetService("ReplicatedStorage"):SetAttribute("CutsceneRunning", kind ~= nil)
end
local token = 0

local BROTHER_LOOK = { outfit = "red_shirt", hair = "side_part" }
local BROTHER = { name = "Name_Brother", voice = "Boonmee" }

-- ---------------------------------------------------------------- ผู้เล่นในคัทซีน
local function rootOf(p: Player): (BasePart?, Humanoid?)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?, c and c:FindFirstChildOfClass("Humanoid")
end

local function active(): { Player }
	local list = {}
	for p in pairs(participants) do
		if p.Parent and not skipped[p] then
			table.insert(list, p)
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

local function fire(...)
	for _, p in ipairs(active()) do
		remote:FireClient(p, ...)
	end
end

-- คนซ้อนมอไซค์: ท่าขี่มอไซค์ (ขาคร่อม) มือยื่นไปจับแฮนด์ -> IK ดึงมือกลับมาวางบนต้นขาตัวเอง
-- เป้ามือเป็น Attachment ในชิ้นของรถ (ขยับตามรถเอง) ลบทิ้งตอนลงรถ
local function clearPillionIK(p: Player)
	local _, hum = rootOf(p)
	if hum then
		for _, c in ipairs(hum:GetChildren()) do
			if c:IsA("IKControl") and string.sub(c.Name, 1, 10) == "PillionIK_" then
				c:Destroy()
			end
		end
	end
	for _, d in ipairs(Workspace:GetChildren()) do
		if d.Name == "BrotherVehicle" then
			for _, a in ipairs(d:GetDescendants()) do
				if a:IsA("Attachment") and string.sub(a.Name, 1, 8) == "Pillion_" and a:GetAttribute("UserId") == p.UserId then
					a:Destroy()
				end
			end
		end
	end
end
local function addPillionIK(p: Player, v: Model, seatCF: CFrame)
	clearPillionIK(p)
	local c = p.Character
	local _, hum = rootOf(p)
	local holder = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
	if not (c and hum and holder) then
		return
	end
	local function bone(n: string): Bone?
		local b = c:FindFirstChild(n, true)
		return if b and b:IsA("Bone") then b else nil
	end
	-- seatCF = จุดสะโพก (เทียบ pivot รถ, หน้า = -Z): มือวางบนต้นขาเหนือเข่านิดหน่อย ศอกกางออกข้างไปหลัง
	for _, side in ipairs({ { "L", -1 }, { "R", 1 } }) do
		local root, tip = bone("upper_arm." .. side[1]), bone("hand." .. side[1])
		if root and tip then
			local a = Instance.new("Attachment")
			a.Name = "Pillion_hand" .. side[1]
			a:SetAttribute("UserId", p.UserId)
			a.Parent = holder
			a.WorldPosition = v:GetPivot():PointToWorldSpace((seatCF * CFrame.new(side[2] * 0.62, 0.35, -0.85)).Position)
			local pole = Instance.new("Attachment")
			pole.Name = "Pillion_pole" .. side[1]
			pole:SetAttribute("UserId", p.UserId)
			pole.Parent = holder
			pole.WorldPosition = v:GetPivot():PointToWorldSpace((seatCF * CFrame.new(side[2] * 1.6, 1.2, 0.6)).Position)
			local ik = Instance.new("IKControl")
			ik.Name = "PillionIK_" .. side[1]
			ik.Type = Enum.IKControlType.Position
			ik.ChainRoot = root
			ik.EndEffector = tip
			ik.Target = a
			ik.Pole = pole
			ik.Weight = 1
			ik.Parent = hum
		end
	end
end

-- ยึดตัวไว้กับจุด (ตามรถ หรือยืนนิ่ง) ทุกเฟรม: anchored ฝั่ง Server = ทุกคนเห็นตำแหน่งเดียวกัน
local function pin(p: Player, v: Model?, cf: CFrame, sit: boolean, clip: string?)
	local root, hum = rootOf(p)
	if not (root and hum) then
		return
	end
	hum:UnequipTools()
	root.Anchored = true
	hum:SetAttribute("SitClip", if sit then clip else nil) -- ท่านั่งเฉพาะ (Animate.client)
	hum.Sit = sit
	if v then
		follow[p] = { v = v, cf = cf }
		root.CFrame = v:GetPivot() * cf
	else
		follow[p] = nil
		root.CFrame = cf
	end
	if v and sit and clip == "ride_moto" then
		addPillionIK(p, v, cf)
	else
		clearPillionIK(p)
	end
end

local function release(p: Player, at: CFrame?)
	follow[p] = nil
	clearPillionIK(p)
	local _, h = rootOf(p)
	if h then
		h:SetAttribute("PoseClip", nil)
	end
	local root, hum = rootOf(p)
	if root and hum then
		if at then
			root.CFrame = at
		end
		root.Anchored = false
		hum:SetAttribute("SitClip", nil)
		hum.Sit = false
		hum.Jump = false
	end
end

RunService.Heartbeat:Connect(function()
	for p, f in pairs(follow) do
		local root = rootOf(p)
		if root and f.v.Parent then
			root.CFrame = f.v:GetPivot() * f.cf
		else
			follow[p] = nil
		end
	end
end)

-- จุดยืนในร้าน (หลังแผง) สำหรับคนที่ข้าม Intro / จบคัทซีน
local function shopSpot(i: number): CFrame
	local spawnPart = Workspace:FindFirstChild("ShackSpawn", true)
	local base = if spawnPart and spawnPart:IsA("BasePart") then spawnPart.Position else Vector3.new(0, 2.5, 21)
	local pos = base + Vector3.new(((i - 1) % 3 - 1) * 2.4, 3, -math.floor((i - 1) / 3) * 2.4)
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)) -- หันหน้าออกถนน
end

-- ---------------------------------------------------------------- รถพี่ชาย
-- 1 คน = มอไซค์ซ้อนท้าย, 2 คน = ตุ๊กตุ๊ก, 3 คน = เก๋ง, 4+ = กระบะ (นั่งหน้า 1 ที่เหลือนั่งท้ายกระบะ)
local function vehicleFor(n: number): string
	if n <= 1 then
		return "ThaiRacingMoto"
	elseif n == 2 then
		return "ThaiTukTuk"
	elseif n == 3 then
		return "ThaiSedanSoluna"
	end
	return "ThaiPickupOld"
end

-- ท่านั่งของผู้เล่นบนรถคันนี้: มอไซค์ = คร่อมเบาะขากาง (ท่าขี่มอไซค์), อื่นๆ = ท่านั่งปกติ
local function pillionClip(v: Model): string?
	local tpl = string.lower(v:GetAttribute("Template") or v.Name)
	return if string.find(tpl, "moto") then "ride_moto" else nil
end

-- ที่นั่งผู้เล่น (เทียบ pivot รถ): เบาะ PassengerSeat* ก่อน ที่เหลือนั่งพื้นท้ายกระบะ
local SIT_UP = 0.2 -- ท่า sit ของชาวบ้าน: กระดูกสะโพกอยู่ระดับ HumanoidRootPart -> วางรากสูงกว่าผิวเบาะแค่ความหนาต้นขา
local function seatSpots(v: Model, n: number): { CFrame }
	local piv = v:GetPivot()
	local seats = {}
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("BasePart") and string.sub(d.Name, 1, 13) == "PassengerSeat" then
			table.insert(seats, d)
		end
	end
	table.sort(seats, function(a, b)
		return a.Name < b.Name
	end)
	local spots = {}
	-- มอไซค์: ซ้อนท้ายถอยไปท้ายเบาะ ไม่นั่งชิดหลังคนขับ
	local back = if string.find(string.lower(v.Name), "moto") or string.find(string.lower(v:GetAttribute("Template") or ""), "moto") then 0.25 else 0
	for _, s in ipairs(seats) do
		local top = piv:PointToObjectSpace(s.Position + Vector3.new(0, s.Size.Y / 2, 0))
		table.insert(spots, CFrame.new(top + Vector3.new(0, SIT_UP, back)))
	end
	-- ท้ายกระบะ: ยิงลงหาพื้นกระบะ
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { v }
	local _, size = v:GetBoundingBox()
	local i = 0
	while #spots < n and i < 8 do
		i += 1
		local local_ = Vector3.new(if i % 2 == 1 then -1.3 else 1.3, 0, size.Z / 2 - 1.6 - math.floor((i - 1) / 2) * 2)
		local from = piv:PointToWorldSpace(local_ + Vector3.new(0, 12, 0))
		local hit = Workspace:Raycast(from, Vector3.new(0, -14, 0), params)
		local y = if hit then piv:PointToObjectSpace(hit.Position).Y else 3
		table.insert(spots, CFrame.new(local_.X, y + SIT_UP - 0.3, local_.Z) * CFrame.Angles(0, if i % 2 == 1 then math.rad(90) else math.rad(-90), 0))
	end
	return spots
end

local function buildVehicle(n: number, at: CFrame): Model?
	local name = vehicleFor(n)
	local tpl = D.templates:FindFirstChild(name) or D.templates:FindFirstChild("ThaiPickupOld")
	if not tpl then
		return nil
	end
	local v = tpl:Clone() :: Model
	D.prepThaiVehicle(v)
	D.seatDriver(v)
	v:PivotTo(at)
	-- (เลือกท่าขับจากชื่อรถ: เปลี่ยนชื่อทีหลัง) มอไซค์: พี่ชายนั่งชิดหน้าเบาะ เว้นที่ให้คนซ้อน
	local look = table.clone(BROTHER_LOOK)
	if string.find(string.lower(tpl.Name), "moto") then
		look.hipForward = 0.35
	end
	D.humanizeDriver(v, look)
	v:SetAttribute("Template", v.Name)
	v.Name = "BrotherVehicle"
	v.Parent = Workspace
	-- เสียงเครื่องยนต์ (มอไซค์ / ตุ๊กตุ๊ก = เสียงมอไซค์, เก๋ง/กระบะ = ดีเซล) ดังกว่าลูกค้านิดหน่อยให้เด่นในคัทซีน
	local moto = string.find(string.lower(tpl.Name), "moto") ~= nil or tpl.Name == "ThaiTukTuk"
	local part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
	local snd = part and SoundBank.CreateSound(if moto then "MotoIdle" else "DieselIdle", part, 220)
	if snd then
		snd.Name = "BrotherEngine"
		snd.Volume *= 1.8
		snd.Looped = true
		snd:Play()
	end
	return v
end

local function driverOf(v: Model): Model?
	return v:FindFirstChild("DriverNPC") :: Model?
end

-- ซ่อน/แสดงคนขับบนรถ (ตอนพี่ชายลงไปเดิน) จำความโปร่งใสเดิมไว้
local function showDriver(v: Model, on: boolean)
	-- ลงจากรถ = ดับเครื่อง / ขึ้นรถ = สตาร์ทใหม่
	local eng = v:FindFirstChild("BrotherEngine", true)
	if eng and eng:IsA("Sound") then
		if on then
			eng:Play()
		else
			eng:Stop()
		end
	end
	local d = driverOf(v)
	if not d then
		return
	end
	for _, p in ipairs(d:GetDescendants()) do
		if p:IsA("BasePart") then
			if on then
				local t = p:GetAttribute("CutsceneT")
				if t ~= nil then
					p.Transparency = t
					p:SetAttribute("CutsceneT", nil)
				end
			elseif p:GetAttribute("CutsceneT") == nil then
				p:SetAttribute("CutsceneT", p.Transparency)
				p.Transparency = 1
			end
		elseif p:IsA("Decal") then
			p.Transparency = if on then 0 else 1
		end
	end
end

local function walkerAt(cf: CFrame): Model
	local w = D.Pedestrian.Build(BROTHER_LOOK)
	w.Name = "BrotherWalker"
	w:PivotTo(cf)
	w.Parent = Workspace
	return w
end

local function headOf(m: Instance?): BasePart?
	if not m then
		return nil
	end
	local h = m:FindFirstChild("Head", true)
	return if h and h:IsA("BasePart") then h else nil
end

local function playerHead(p: Player): BasePart?
	local c = p.Character
	local h = c and c:FindFirstChild("Head")
	return if h and h:IsA("BasePart") then h else nil
end

-- ---------------------------------------------------------------- จังหวะ
local function alive(t: number): boolean
	return token == t and #active() > 0
end

-- รอแบบหยุดได้ทันทีถ้าข้ามครบทุกคน
local function wait_(t: number, seconds: number): boolean
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if not alive(t) then
			return false
		end
		task.wait(0.1)
	end
	return alive(t)
end

local function say(t: number, key: string, who: { [string]: any }, head: BasePart?, hold: number): boolean
	fire("say", key, who, head)
	return wait_(t, hold)
end

-- ทำงานยาวๆ (ขับรถ/เดิน) แบบไม่บล็อก แล้วรอจนเสร็จหรือข้ามครบ
local function run(t: number, fn: () -> ()): boolean
	local done = false
	task.spawn(function()
		pcall(fn)
		done = true
	end)
	while not done do
		if not alive(t) then
			return false
		end
		task.wait(0.1)
	end
	return alive(t)
end

local function ground(p: Vector3): Vector3
	return Vector3.new(p.X, D.groundAt(p), p.Z)
end

-- ผู้เล่นเดินเอง (Humanoid:MoveTo) ทีละจุด หมดเวลาก็วาร์ปไปจุดนั้น
local function walkPlayers(players: { Player }, path: { Vector3 }, spread: number)
	for i, p in ipairs(players) do
		task.spawn(function()
			local root, hum = rootOf(p)
			if not (root and hum) then
				return
			end
			follow[p] = nil
			root.Anchored = false
			hum.Sit = false
			-- เดินเรียงแถวตามทาง (ออกตัวห่างกันทีละนิด) แล้วค่อยกระจายยืนข้างกันที่จุดสุดท้าย
			task.wait((i - 1) * 0.6)
			for k, pt in ipairs(path) do
				local last = k == #path
				local target = if last then pt + Vector3.new(((i - 1) % 3) * spread, 0, math.floor((i - 1) / 3) * spread) else pt
				-- ตัวผู้เล่นเป็นของ Client: สั่ง MoveTo ฝั่ง Server แล้วไม่เดิน -> ให้ Client เดินตัวเอง (Server คอยดู/วาร์ปถ้าติด)
				remote:FireClient(p, "walkto", target)
				hum:MoveTo(target)
				local t0 = os.clock()
				while p.Parent and root.Parent and (Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)).Magnitude > 1.5 do
					if os.clock() - t0 > 7 then
						root.CFrame = CFrame.new(target + Vector3.new(0, 3, 0)) * (root.CFrame - root.CFrame.Position)
						break
					end
					task.wait(0.1)
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------- จุดในฉาก
local function points()
	local stop = D.stopPoint.Position
	local road = D.ROAD_DIR :: Vector3
	local shopDir = Vector3.new(0, 0, 1) -- ร้านอยู่ฝั่ง +Z ของถนน
	local _, shackSize = D.shack:GetBoundingBox()
	local shackCF = D.shack:GetBoundingBox()
	local halfX = shackSize.X / 2
	local backZ = shackCF.Position.Z + shackSize.Z / 2
	local rope = D.rejectRope.Position
	-- ขอบโต๊ะเคาน์เตอร์ / ม้านั่งหน้าร้าน (world AABB)
	local function box(name: string): (Vector3?, Vector3?)
		local p = D.shack:FindFirstChild(name, true)
		if not (p and p:IsA("BasePart")) then
			return nil, nil
		end
		local cf, s = p.CFrame, p.Size
		local ext = (cf.RightVector * s.X):Abs() + (cf.UpVector * s.Y):Abs() + (cf.LookVector * s.Z):Abs()
		return p.Position - ext / 2, p.Position + ext / 2
	end
	local cMin, cMax = box("CounterTable")
	local bMin = box("WoodenBench")
	local counterBack = if cMax then cMax.Z else rope.Z + 2.6
	local aisleX = math.min(if cMin then cMin.X else rope.X - 2, if bMin then bMin.X else math.huge) - 1.3
	-- หน้าร้าน: ชั้นน้ำมันขวด (FuelBottleRack) + ฐานตู้น้ำมันขวางทาง -> เลนเดินซ้ายของชั้น
	local rack = Workspace:FindFirstChild("MapEnvironment") and Workspace.MapEnvironment:FindFirstChild("FuelBottleRack", true)
	local rackMinX = if rack and rack:IsA("Model") then (rack:GetBoundingBox().Position.X - rack:GetExtentsSize().X / 2) else aisleX
	local laneX = rackMinX - 1.0
	return {
		stop = stop,
		road = road,
		shopDir = shopDir,
		sideX = shackCF.Position.X - halfX - 3.5, -- ทางเดินอ้อมข้างร้าน (ฝั่ง -X ไปทางเครื่องปั่นไฟ)
		backZ = backZ + 3,
		rope = rope,
		-- ความสูงจุดเดินในร้าน = ระดับถนน + นิดหน่อย (FloorAt ยิงลงจาก Y+3: ถ้าเริ่มสูงเท่าเชือกจะไปโดนชั้น/คานแทนพื้น)
		-- เชือกห้อยเหนือโต๊ะเคาน์เตอร์: ยืนดึงจากหลังโต๊ะ
		ropeStand = Vector3.new(rope.X, stop.Y + 1, counterBack + 1.2),
		inside = Vector3.new(shackCF.Position.X - 2, stop.Y + 1, backZ - 4),
		-- ทางเดินในร้าน: อ้อมปลายโต๊ะเคาน์เตอร์ฝั่งซ้าย (เลยม้านั่งไปด้วย) ไม่เดินทะลุโต๊ะ
		aisleX = aisleX,
		counterBack = counterBack,
		-- ทางเข้า/ออกร้าน (ถนน <-> หลังโต๊ะ) ไม่ชนตู้น้ำมัน ชั้นขวด เสา โต๊ะ ม้านั่ง
		doorPath = {
			Vector3.new(laneX, stop.Y, stop.Z + 4.5),
			Vector3.new(laneX, stop.Y, D.shutterDoor.Position.Z - 2.6),
			Vector3.new(aisleX, stop.Y, D.shutterDoor.Position.Z - 1.2),
			Vector3.new(aisleX, stop.Y, counterBack + 1.4),
		},
	}
end

-- ---------------------------------------------------------------- Intro
local function introBody(t: number)
	local P = points()
	local players = active()
	local n = math.max(1, #players)
	local startPos = ground(D.spawnPoint.Position)
	local stopPos = ground(P.stop + P.shopDir * 0.5)
	local v = buildVehicle(n, CFrame.lookAt(startPos, startPos + P.road))
	if not v then
		return
	end
	local spots = seatSpots(v, n)
	for i, p in ipairs(players) do
		pin(p, v, spots[math.min(i, #spots)] or CFrame.new(0, 4, 1.6), true, pillionClip(v))
	end
	fire("start", "intro")
	-- 1) ขี่มาตามถนนตอนเย็น: กล้องตามข้างรถ
	fire("cam", { mode = "track", target = v, offset = Vector3.new(-9, 3.5, 5), look = Vector3.new(0, 2.5, -2), smooth = 6 })
	if not run(t, function()
		D.driveTo(v, stopPos - P.road * 9, false, 18)
		D.driveTo(v, stopPos, true, 18)
	end) then
		return v
	end
	-- 2) จอดหน้าร้าน คุยกัน
	local drvHead = headOf(driverOf(v))
	local vp = v:GetPivot()
	fire("cam", { mode = "fixed", pos = vp:PointToWorldSpace(Vector3.new(7, 4.2, -7)), look = vp:PointToWorldSpace(Vector3.new(0, 4, 0.6)), fov = 50 })
	if not wait_(t, 1.0) then
		return v
	end
	if not say(t, "Intro_Brother_1", BROTHER, drvHead, 3.4) then
		return v
	end
	local first = active()[1]
	if not first then
		return v
	end
	if not say(t, "Intro_Player_1", { player = first.DisplayName }, playerHead(first), 2.6) then
		return v
	end
	-- 3) ลงจากรถ: ผู้เล่นยืนหน้าร้าน พี่ชายลงเดิน
	fire("say", nil)
	vp = v:GetPivot()
	for i, p in ipairs(active()) do
		-- ยืนเยื้องไปทางหัวรถ (พี่ชายยืนท้ายรถ ไม่ทับกัน)
		local pos = ground(vp.Position + P.shopDir * 2.6 + P.road * (1.8 + (i - 1) * 1.9)) + Vector3.new(0, 3, 0)
		pin(p, nil, CFrame.lookAt(pos, pos + P.shopDir), false)
	end
	showDriver(v, false)
	local bro = walkerAt(CFrame.lookAt(ground(vp.Position + P.shopDir * 2.2 - P.road * 1.2), ground(vp.Position + P.shopDir * 6)))
	-- 4) พี่ชายเดินอ้อมไปหลังร้าน (กล้องกว้างหน้าร้าน)
	fire("cam", { mode = "fixed", pos = Vector3.new(P.stop.X + 10, P.stop.Y + 6, P.stop.Z - 10), look = Vector3.new(P.sideX + 4, P.stop.Y + 3, P.stop.Z + 10), fov = 55 })
	local corner = Vector3.new(P.sideX, P.stop.Y, P.stop.Z + 6)
	if not run(t, function()
		-- เดินเลียบถนนหน้าตู้น้ำมันไปก่อน (ไม่ตัดผ่านฐานตู้) แล้วค่อยเลี้ยวเข้าข้างร้าน
		D.Pedestrian.WalkTo(bro, Vector3.new(P.sideX + 4, P.stop.Y, bro:GetPivot().Position.Z), 7)
		D.Pedestrian.WalkTo(bro, corner, 7)
		D.Pedestrian.WalkTo(bro, Vector3.new(P.sideX, P.stop.Y, P.backZ - 8), 7)
	end) then
		return v, bro
	end
	-- 5) ในร้าน: พี่ชายเดินจากหลังร้านมาดึงเชือก แผงเปิด
	bro:PivotTo(CFrame.lookAt(ground(P.inside), ground(P.ropeStand)))
	local floorY = D.Pedestrian.FloorAt(P.inside, { bro })
	bro:PivotTo(CFrame.lookAt(Vector3.new(P.inside.X, floorY, P.inside.Z), Vector3.new(P.ropeStand.X, floorY, P.ropeStand.Z)))
	fire("cam", { mode = "fixed", pos = Vector3.new(P.rope.X + 7, P.rope.Y - 1, P.rope.Z + 9), look = Vector3.new(P.rope.X, P.rope.Y - 2.5, P.rope.Z + 1), fov = 60 })
	if not run(t, function()
		D.Pedestrian.WalkTo(bro, P.ropeStand, 6, true)
		D.Pedestrian.Face(bro, P.rope)
	end) then
		return v, bro
	end
	if not wait_(t, 0.5) then
		return v, bro
	end
	-- กล้องนอกร้าน: แผงสังกะสีเลื่อนขึ้น เห็นพี่ชายในร้าน ผู้เล่นรอหน้าร้าน
	fire("cam", { mode = "fixed", pos = Vector3.new(P.stop.X + 10, P.stop.Y + 4.5, P.stop.Z - 7), look = Vector3.new(P.rope.X, P.stop.Y + 4, P.rope.Z), fov = 55 })
	D.openShutter() -- (แค่ยกแผงให้เห็น: คืนจริงเริ่มเมื่อผู้เล่นดึงเชือกเปิดร้านเอง)
	if not wait_(t, 1.4) then
		return v, bro
	end
	if not say(t, "Intro_Brother_2", BROTHER, headOf(bro), 3.6) then
		return v, bro
	end
	-- 6) พี่ชายเดินออกมาขึ้นรถ ขี่ออกไป
	vp = v:GetPivot()
	if not run(t, function()
		-- หลังโต๊ะ -> อ้อมปลายโต๊ะฝั่งซ้าย -> ออกหน้าร้านทางเลนซ้ายของชั้นขวด (ไม่ชนตู้น้ำมัน) -> ไปที่รถ
		D.Pedestrian.WalkTo(bro, Vector3.new(P.aisleX, P.ropeStand.Y, P.ropeStand.Z), 6, true)
		for i = #P.doorPath, 1, -1 do
			D.Pedestrian.WalkTo(bro, P.doorPath[i], 7, true)
		end
		D.Pedestrian.WalkTo(bro, ground(vp.Position + P.shopDir * 2.4 - P.road * 1.6), 7)
	end) then
		return v, bro
	end
	-- คุยกันก่อนขี่ออก: พี่ชาย (ท้ายรถ) กับผู้เล่น (หัวรถ) หันหน้าเข้าหากัน ห่างกันพอไม่ทับตัว
	local firstP = active()[1]
	local fr = firstP and rootOf(firstP)
	D.Pedestrian.Face(bro, if fr then fr.Position else D.shutterDoor.Position)
	local bp = bro:GetPivot().Position
	for _, p in ipairs(active()) do
		local r = rootOf(p)
		if r then
			pin(p, nil, CFrame.lookAt(r.Position, Vector3.new(bp.X, r.Position.Y, bp.Z)), false)
		end
	end
	-- กล้องฝั่งถนน (ฝั่งร้านมีตู้ปั๊มบัง) มองข้ามรถไปหาพี่ชาย
	fire("cam", { mode = "lookat", pos = vp:PointToWorldSpace(Vector3.new(-7, 4.5, -4)), target = bro, look = Vector3.new(0, 4.6, 0), fov = 42 })
	if not say(t, "Intro_Brother_3", BROTHER, headOf(bro), 3.0) then
		return v, bro
	end
	bro:Destroy()
	showDriver(v, true)
	local shopFront = Vector3.new(P.stop.X, P.stop.Y, P.stop.Z) + P.shopDir * 9
	fire("cam", { mode = "lookat", pos = shopFront + Vector3.new(0, 4, 0), target = v, look = Vector3.new(0, 2, 0), fov = 55 })
	if not run(t, function()
		D.driveTo(v, ground(D.exitPoint.Position), false, 20)
	end) then
		return v
	end
	v:Destroy()
	-- 7) ผู้เล่นเดินเข้าร้าน (กล้องนอกร้านเห็นเดินเข้าไปจนถึงข้างใน) -> แผงประตูปิดลง -> ตะวันตกดิน -> กลางคืน
	--    ร้านปิดอยู่ตอนเริ่มเล่น: ผู้เล่นดึงเชือกเปิดร้านเองเพื่อเริ่มคืน (เหมือนเดิม)
	local ps = active()
	fire("cam", { mode = "fixed", pos = Vector3.new(P.stop.X + 5, P.stop.Y + 4.5, P.stop.Z - 10), look = Vector3.new(P.aisleX + 5, P.stop.Y + 3.5, D.shutterDoor.Position.Z + 4), fov = 60 })
	-- เดินเข้าทางเดินซ้ายเรียงแถว อ้อมปลายโต๊ะไปยืนหลังโต๊ะ (ไม่เดินทะลุ/ติดโต๊ะ)
	local y = P.stop.Y
	-- จบที่หลังโต๊ะฝั่งทางเดิน (ไม่เดินต่อไปกลางร้าน: ตอนคัทซีนจบแล้วยังเดินไม่ถึง ตัวจะเดินข้างตามกล้อง)
	local path = table.clone(P.doorPath)
	path[#path] = Vector3.new(P.aisleX + 1.5, y, P.counterBack + 1.8)
	walkPlayers(ps, path, 1.8)
	-- รอจนทุกคนเข้าไปหลังแผงจริง (ไม่เกิน 9 วิ walkPlayers วาร์ปให้ถ้าติด)
	local t0 = os.clock()
	while os.clock() - t0 < 9 do
		local all = true
		for _, p in ipairs(active()) do
			local root = rootOf(p)
			if root and not D.insideShop(root.Position) then
				all = false
			end
		end
		if all then
			break
		end
		if not wait_(t, 0.2) then
			return
		end
	end
	if not wait_(t, 0.8) then
		return
	end
	D.resetShutter() -- แผงสังกะสีปิดลงหลังผู้เล่นเข้าร้าน (ถ้ายังไม่มีใครข้ามไปดึงเชือกเปิดร้านจริงแล้ว)
	fire("sunset", 3.5)
	if not wait_(t, 2.8) then
		return
	end
	fire("fade", true, 1.0)
	wait_(t, 1.6)
	return nil
end

-- รอให้ผู้เล่นโหลดเสร็จ (หน้าโหลดหาย) ก่อนเริ่ม Intro (คืนแรก server เริ่มก่อนผู้เล่นเข้า)
local function waitReady(maxWait: number)
	local t0 = os.clock()
	while os.clock() - t0 < maxWait do
		local ps = Players:GetPlayers()
		local allReady = #ps > 0
		for _, p in ipairs(ps) do
			if not ready[p] or not p.Character then
				allReady = false
			end
		end
		if allReady then
			return
		end
		task.wait(0.25)
	end
end

local function begin(kind: string): number
	token += 1
	setRunning(kind)
	table.clear(participants)
	table.clear(skipped)
	for _, p in ipairs(Players:GetPlayers()) do
		if ready[p] and p.Character then
			participants[p] = true
		end
	end
	return token
end

local function finish(kind: string, place: boolean)
	local i = 0
	for p in pairs(participants) do
		if p.Parent and not skipped[p] then
			i += 1
			remote:FireClient(p, "end", kind)
			release(p, if place then shopSpot(i) else nil)
		end
	end
	table.clear(follow)
	table.clear(participants)
	setRunning(nil)
end

-- คัทซีนเปิดคืน: บล็อกจนจบหรือข้ามครบ (จบแล้วแผงร้านปิดเสมอ รอผู้เล่นดึงเชือกเปิดร้านเริ่มคืน)
function Cutscene.Intro()
	introWaiting = true
	waitReady(90)
	introWaiting = false
	if #Players:GetPlayers() == 0 then
		D.resetShutter()
		return
	end
	local t = begin("intro")
	if next(participants) == nil then
		D.resetShutter()
		setRunning(nil)
		return
	end
	local ok, a, b = pcall(introBody, t)
	if not ok then
		warn("[Cutscene] Intro error:", a)
	end
	for _, m in ipairs({ a, b }) do
		if typeof(m) == "Instance" and m.Parent then
			m:Destroy()
		end
	end
	for _, d in ipairs(Workspace:GetChildren()) do
		if d.Name == "BrotherVehicle" or d.Name == "BrotherWalker" then
			d:Destroy()
		end
	end
	D.resetShutter()
	-- คนที่ยังดูอยู่ (ไม่ได้ข้าม): ยืนในร้านตรงที่เดินมาถึง ถ้ายังอยู่นอกร้านวาร์ปเข้าไป
	local i = 0
	for p in pairs(participants) do
		if p.Parent and not skipped[p] then
			i += 1
			local root = rootOf(p)
			local inside = root and D.insideShop(root.Position)
			remote:FireClient(p, "end", "intro")
			release(p, if inside then nil else shopSpot(i))
		end
	end
	table.clear(follow)
	table.clear(participants)
	setRunning(nil)
	token += 1
end

-- ---------------------------------------------------------------- Outro
local function outroBody(t: number)
	local P = points()
	local players = active()
	local n = math.max(1, #players)
	-- 1) เช้ามืด ผู้เล่นยืนหลังโต๊ะดึงเชือกปิดร้าน (คนแรกดึง คนอื่นยืนข้างๆ หลังโต๊ะ) กล้องหน้าร้านเห็นแผงเลื่อนลงมาบัง
	local floorY = D.Pedestrian.FloorAt(P.ropeStand, {}) + 3
	for i, p in ipairs(players) do
		local pos = Vector3.new(P.ropeStand.X + (i - 1) * 2.0, floorY, P.ropeStand.Z + math.floor((i - 1) / 4) * 1.8)
		pin(p, nil, CFrame.lookAt(pos, pos - P.shopDir), false) -- ยืนเฉยๆ หลังโต๊ะ (ไม่ใช้ท่าดึงเชือก) แผงปิดลงเอง
	end
	fire("start", "outro")
	local rope = P.rope
	-- (มุมเฉียงจากขวา ไม่ให้ตู้น้ำมันบัง)
	fire("cam", { mode = "fixed", pos = Vector3.new(rope.X + 9, P.stop.Y + 5.2, D.shutterDoor.Position.Z - 7.7), look = Vector3.new(rope.X + 0.5, P.stop.Y + 4.5, P.ropeStand.Z), fov = 50 })
	if not wait_(t, 1.6) then
		return
	end
	D.closeShop()
	if not wait_(t, 1.4) then
		return
	end
	-- ตัดภาพ (จอดำแวบ) ไปหลังร้าน: ผู้เล่นปิดร้านเสร็จ ออกทางหลังร้าน
	fire("fade", true, 0.4)
	if not wait_(t, 0.5) then
		return
	end
	for i, p in ipairs(active()) do
		local _, hum = rootOf(p)
		if hum then
			hum:SetAttribute("PoseClip", nil)
		end
		-- มุมหลังร้านฝั่งซ้าย (ไม่ทับถังน้ำมันหลังร้านที่ x ≈ -13) ยืนเป็นแถวละ 2 คน
		local pos = ground(Vector3.new(P.sideX + 1.2 + ((i - 1) % 2) * 1.8, P.stop.Y, P.backZ + 0.5 + math.floor((i - 1) / 2) * 1.8)) + Vector3.new(0, 3, 0)
		pin(p, nil, CFrame.lookAt(pos, pos - P.shopDir), false)
	end
	fire("fade", false, 0.6)
	-- 2) พี่ชายขี่รถกลับมา
	local startPos = ground(D.spawnPoint.Position)
	local stopPos = ground(P.stop + P.shopDir * 0.5)
	local v = buildVehicle(n, CFrame.lookAt(startPos, startPos + P.road))
	if not v then
		return
	end
	fire("cam", { mode = "track", target = v, offset = Vector3.new(-8, 3.5, -9), look = Vector3.new(0, 2.5, 0), smooth = 6 })
	if not run(t, function()
		D.driveTo(v, stopPos - P.road * 9, false, 18)
		D.driveTo(v, stopPos, true, 18)
	end) then
		return v
	end
	-- 3) ผู้เล่นเดินออกมาจากหลังร้าน
	local vp = v:GetPivot()
	local meet = ground(vp.Position + P.shopDir * 3.2)
	fire("cam", { mode = "fixed", pos = Vector3.new(P.sideX - 9, P.stop.Y + 5, P.stop.Z - 4), look = Vector3.new(P.sideX + 2, P.stop.Y + 3, P.stop.Z + 14), fov = 60 })
	walkPlayers(active(), { Vector3.new(P.sideX, meet.Y, P.backZ), Vector3.new(P.sideX, meet.Y, P.stop.Z + 6), meet }, 2.2)
	if not wait_(t, 7.5) then
		return v
	end
	-- 4) คุยกัน
	for _, p in ipairs(active()) do
		local root = rootOf(p)
		if root then
			pin(p, nil, CFrame.lookAt(root.Position, Vector3.new(vp.Position.X, root.Position.Y, vp.Position.Z)), false)
		end
	end
	fire("cam", { mode = "fixed", pos = vp:PointToWorldSpace(Vector3.new(7, 4.2, -7)), look = vp:PointToWorldSpace(Vector3.new(0, 4, 2)), fov = 50 })
	if not say(t, "Outro_Brother_1", BROTHER, headOf(driverOf(v)), 3.0) then
		return v
	end
	local first = active()[1]
	if not first then
		return v
	end
	if not say(t, "Outro_Player_1", { player = first.DisplayName }, playerHead(first), 3.4) then
		return v
	end
	if not say(t, "Outro_Brother_2", BROTHER, headOf(driverOf(v)), 2.6) then
		return v
	end
	fire("say", nil)
	-- 5) ขึ้นรถ ขี่ออกไปรับแสงเช้า
	local spots = seatSpots(v, n)
	for i, p in ipairs(active()) do
		pin(p, v, spots[math.min(i, #spots)] or CFrame.new(0, 4, 1.6), true, pillionClip(v))
	end
	local shopFront = Vector3.new(P.stop.X, P.stop.Y, P.stop.Z) + P.shopDir * 9
	fire("cam", { mode = "lookat", pos = shopFront + Vector3.new(-3, 4, 0), target = v, look = Vector3.new(0, 2, 0), fov = 55 })
	if not run(t, function()
		task.delay(3.5, function()
			if alive(t) then
				fire("fade", true, 1.2)
			end
		end)
		D.driveTo(v, ground(D.exitPoint.Position), false, 18)
	end) then
		return v
	end
	return v
end

-- คัทซีนจบคืน (ชนะ): บล็อกจนจบหรือข้ามครบ แล้วผู้เล่นกลับมายืนในร้าน (ร้านปิด) — หน้าสรุปผลขึ้นฝั่ง Client
function Cutscene.Outro(summary: { [string]: any })
	local t = begin("outro")
	for p in pairs(participants) do
		remote:FireClient(p, "summary", summary)
	end
	-- คนที่ยังโหลดไม่เสร็จก็ได้หน้าสรุป
	for _, p in ipairs(Players:GetPlayers()) do
		if not participants[p] then
			remote:FireClient(p, "summary", summary)
			remote:FireClient(p, "end", "outro")
		end
	end
	if next(participants) == nil then
		setRunning(nil)
		return
	end
	local ok, v = pcall(outroBody, t)
	if not ok then
		warn("[Cutscene] Outro error:", v)
	end
	if typeof(v) == "Instance" and v.Parent then
		v:Destroy()
	end
	for _, d in ipairs(Workspace:GetChildren()) do
		if d.Name == "BrotherVehicle" or d.Name == "BrotherWalker" then
			d:Destroy()
		end
	end
	finish("outro", true)
	token += 1
end

function Cutscene.Running(): string?
	return running
end

function Cutscene.Init(deps: { [string]: any })
	D = deps
	remote = deps.remote("Cutscene")
	remote.OnServerEvent:Connect(function(p: Player, action: any)
		if action == "ready" then
			ready[p] = true
			-- ไม่มีคัทซีนรอให้ดู (เข้ามากลางคืน / คัทซีนเล่นไปแล้ว): บอกให้ Client เอาจอดำออก
			if not introWaiting then
				remote:FireClient(p, "nocutscene")
			end
		elseif action == "skip" and running and participants[p] and not skipped[p] then
			skipped[p] = true
			remote:FireClient(p, "end", running)
			if running == "intro" then
				local i = 0
				for q in pairs(skipped) do
					i += 1
					if q == p then
						break
					end
				end
				release(p, shopSpot(i))
			else
				release(p, shopSpot(1))
			end
			print("⏭️ [" .. p.Name .. "] ข้ามคัทซีน " .. tostring(running))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		ready[p] = nil
		participants[p] = nil
		skipped[p] = nil
		follow[p] = nil
	end)
	-- ตายแล้วเกิดใหม่ระหว่างคัทซีน: ตัวใหม่ไม่ต้องยึด
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			follow[p] = nil
		end)
	end)
end

return Cutscene
