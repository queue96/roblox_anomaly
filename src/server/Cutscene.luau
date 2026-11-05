--!nonstrict
-- Cutscene.luau (ModuleScript ฝั่ง Server, require จาก CoreLoop)
-- คัทซีนเปิดคืน (Intro) และจบคืนแบบชนะ (Outro) — ตัวละคร/รถ/แผงร้านขยับจริงฝั่ง Server (ทุกคนเห็นเหมือนกัน)
-- ส่วนกล้อง แถบดำ ซับไตเติล แสงเย็น/เช้า และปุ่มข้าม อยู่ฝั่ง Client (client/CutsceneController.client.luau)
--
--   Intro: เย็นใกล้ค่ำ พี่ชายขี่รถพาผู้เล่นมาส่งหน้าร้าน -> "คืนนี้เฝ้าร้านให้พี่หน่อยนะ" -> ผู้เล่นตอบตกลง
--          -> ลงรถ พี่ชายเดินอ้อมไปหลังร้าน ดึงเชือกเปิดแผง -> ขี่รถออกไป -> ผู้เล่นเดินเข้าร้าน -> ตะวันตก เข้ากลางคืน
--   Outro: ตะวันขึ้น ผู้เล่นปิดร้านอยู่หลังร้าน -> พี่ชายขี่รถกลับมารับ -> ผู้เล่นเดินออกมาหา -> "เมื่อคืนเป็นไงบ้าง"
--          -> "ผ่านไปได้ด้วยดี" -> ขึ้นรถออกไป -> หน้าจอสรุปผล
--   ข้ามแบบโหวต (Client ส่ง "skip"): นับคะแนนแล้วบอกทุกคน ("skipvote", โหวต, ทั้งหมด) ยังไม่มีใครออกจากคัทซีน
--   โหวตครบทุกคนที่ดูอยู่ = ข้ามพร้อมกันทั้งหมด (Intro: ยืนในร้าน เปิดร้านให้เลย) / เล่นคนเดียว = ข้ามทันที
--
-- Remote: Remotes.Cutscene
--   S->C ("start", kind) / ("cam", spec) / ("say", key, who, head) / ("fade", black, seconds) / ("sunset", seconds)
--        ("end", kind) / ("summary", data)
--   C->S ("ready") หลังหน้าโหลดหาย / ("skip") = โหวตข้าม
--   S->C ("skipvote", votes, total) จำนวนโหวตข้ามตอนนี้
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SoundBank"))
local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))

local Cutscene = {}

local D: { [string]: any } = nil -- ของจาก CoreLoop (Cutscene.Init)
local remote: RemoteEvent = nil
local ready: { [Player]: boolean } = {}
local participants: { [Player]: boolean } = {}
local skipped: { [Player]: boolean } = {}
local skipVotes: { [Player]: boolean } = {} -- โหวตข้ามคัทซีนรอบนี้ (ข้ามเมื่อครบทุกคนที่ดูอยู่)
local checkSkipVotes: () -> ()
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

-- ---------------------------------------------------------------- หุ่นทดสอบหลายคน (Studio เท่านั้น)
-- ServerStorage.DevDecision:SetAttribute("CutsceneDummies", n) แล้ว Fire("intro") / Fire("win")
-- = คัทซีนรอบนั้นมีหุ่นเพิ่ม n ตัว (โคลนตัวผู้เล่นจริง) ร่วมคัทซีนเหมือนผู้เล่นอีก n คน: นั่งรถ ลงรถ เดิน ผ่านโค้ดเดียวกันทั้งหมด
-- ไว้ทดสอบที่นั่ง/จุดลงรถ/กล้องตอนหลายคน โดยไม่ต้องเปิดหลาย client — เกมจริง (ไม่ใช่ Studio) ไม่มีหุ่นเลย
-- หุ่น = ตาราง { Character, Parent, UserId, DisplayName, Name } แทน Player (ไม่ส่ง remote หา / เดินด้วย Humanoid:MoveTo ฝั่ง Server)
local HumanAnimIds = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("HumanAnimIds"))
local fakes: { any } = {}

local function isFake(p: any): boolean
	return type(p) == "table"
end

-- ส่ง remote เฉพาะผู้เล่นจริง
local function send(p: any, ...)
	if not isFake(p) then
		remote:FireClient(p, ...)
	end
end

local function clearFakes()
	for _, f in ipairs(fakes) do
		participants[f] = nil
		skipped[f] = nil
		follow[f] = nil
		f.Parent = nil
		if f.Character then
			f.Character:Destroy()
		end
	end
	table.clear(fakes)
end

local function makeFakes(n: number)
	clearFakes()
	local base: Model? = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			base = p.Character
			break
		end
	end
	if not base then
		return
	end
	local was = base.Archivable
	base.Archivable = true
	local ids = HumanAnimIds.human_base
	for i = 1, n do
		local m = base:Clone()
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		local root = m and m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (m and hum and root) then
			continue
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Tool") then
				d:Destroy()
			end
		end
		m.Name = "CutsceneDummy" .. i
		m:SetAttribute("CutsceneDummy", true)
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		m:PivotTo(base:GetPivot() * CFrame.new(i * 3, 0, 0))
		m.Parent = Workspace
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		local f = { Character = m, Parent = Workspace, UserId = 1e12 + i, DisplayName = "Dummy" .. i, Name = "Dummy" .. i }
		table.insert(fakes, f)
		-- ท่าทาง (ตัวผู้เล่นจริงใช้ Animate.client: หุ่นไม่มี client -> เล่นท่าเองฝั่ง Server)
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local tracks: { [string]: AnimationTrack } = {}
		local current: string? = nil
		task.spawn(function()
			while m.Parent do
				local want = if hum.Sit then (hum:GetAttribute("SitClip") or "sit") elseif root.AssemblyLinearVelocity.Magnitude > 1 then "walk" else "idle"
				if want ~= current and ids[want] then
					if current and tracks[current] then
						tracks[current]:Stop(0.2)
					end
					if not tracks[want] then
						local a = Instance.new("Animation")
						a.AnimationId = ids[want]
						tracks[want] = animator:LoadAnimation(a)
						tracks[want].Looped = true
					end
					tracks[want]:Play(0.2)
					current = want
				end
				task.wait(0.15)
			end
		end)
	end
	base.Archivable = was
end

-- หุ่นเดินตามเส้นทาง (แทน Client "walkpath")
local function fakeWalk(p: any, route: { Vector3 })
	local c = p.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hum and root) then
		return
	end
	task.spawn(function()
		for k, pt in ipairs(route) do
			local last = k == #route
			local t0 = os.clock()
			hum:MoveTo(pt)
			while c.Parent and not root.Anchored and os.clock() - t0 < 6 do
				if (Vector3.new(pt.X - root.Position.X, 0, pt.Z - root.Position.Z)).Magnitude < (if last then 0.6 else 1.4) then
					break
				end
				task.wait()
			end
		end
		if c.Parent then
			hum:Move(Vector3.zero)
		end
	end)
end

local function fire(...)
	for _, p in ipairs(active()) do
		send(p, ...)
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

-- แจกจุดยืนในร้านทีละคน (คนกดข้ามก่อนได้จุดก่อน คนดูจบได้จุดถัดไป) เริ่มนับใหม่ทุกคัทซีน
local shopSlots = 0
local function nextShopSpot(): CFrame
	shopSlots += 1
	return shopSpot(shopSlots)
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
	-- เบาะผู้โดยสารทุกตัว (PassengerSeat*, RearSeat* ...) ยกเว้นเบาะคนขับ — เดิมนับแค่ PassengerSeat*
	-- เก๋ง 3 คนเลยมีเบาะเดียว อีก 2 คนไปนั่งบนฝากระโปรงท้าย (ซ้อนกันกับจุด "ท้ายกระบะ")
	local seats = {}
	for _, d in ipairs(v:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsA("VehicleSeat") and string.find(d.Name, "Seat") and not string.find(d.Name, "Driver") then
			table.insert(seats, d)
		end
	end
	-- หน้าไปหลัง (หน้ารถ = -Z) แล้วซ้ายไปขวา: คนแรก (คนพูด) นั่งหน้า
	table.sort(seats, function(a, b)
		local la, lb = piv:PointToObjectSpace(a.Position), piv:PointToObjectSpace(b.Position)
		if math.abs(la.Z - lb.Z) > 0.5 then
			return la.Z < lb.Z
		end
		return la.X < lb.X
	end)
	local spots = {}
	-- มอไซค์: ซ้อนท้ายถอยไปท้ายเบาะ ไม่นั่งชิดหลังคนขับ
	local back = if string.find(string.lower(v.Name), "moto") or string.find(string.lower(v:GetAttribute("Template") or ""), "moto") then 0.25 else 0
	for _, s in ipairs(seats) do
		local top = piv:PointToObjectSpace(s.Position + Vector3.new(0, s.Size.Y / 2, 0))
		table.insert(spots, CFrame.new(top + Vector3.new(0, SIT_UP, back)))
	end
	-- ท้ายกระบะ: ม้านั่งไม้ยาวชิดผนังกระบะสองข้าง นั่งหันหน้าเข้าหากัน (แบบรถสองแถว)
	-- (เดิมนั่งท่านั่งเก้าอี้ลงบนพื้นกระบะตรงๆ: สะโพกเท่าพื้น หน้าแข้ง/เท้าจมพื้นกระบะ ~1.5 studs ขาทะลุรถ
	--  และสองแถวนั่งห่างกันแค่ 2.6 เท้าสองฝั่งชนกันกลางกระบะ)
	-- ท่า sit: ฝ่าเท้าต่ำกว่า HumanoidRootPart ~1.65 / เท้ายื่นไปหน้า ~1.3 -> ม้านั่งสูง 1.45 จากพื้น เท้าวางพื้นพอดี
	if #spots < n then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { v }
		local _, size = v:GetBoundingBox()
		-- พื้นกระบะ + ผนังด้านใน: ยิงลงกลางกระบะหาพื้น แล้วยิงออกข้างหาผนัง
		local midZ = size.Z / 2 - 4.5
		local fromTop = piv:PointToWorldSpace(Vector3.new(0, 12, midZ))
		local floorHit = Workspace:Raycast(fromTop, Vector3.new(0, -14, 0), params)
		local floorY = if floorHit then piv:PointToObjectSpace(floorHit.Position).Y else 3
		local innerX = 3.2
		local sideHit = Workspace:Raycast(piv:PointToWorldSpace(Vector3.new(0, floorY + 1, midZ)), piv:VectorToWorldSpace(Vector3.new(size.X, 0, 0)), params)
		if sideHit then
			innerX = math.abs(piv:PointToObjectSpace(sideHit.Position).X)
		end
		local BENCH_H, BENCH_W = 1.45, 0.9
		local benchX = innerX - BENCH_W / 2 - 0.05
		-- ท้ายกระบะ (ฝาท้าย) ถึงหลังห้องคนขับ: ไล่จากท้ายเข้าหาห้องคนขับ ห่างกันคนละ 2 studs
		local rearZ = size.Z / 2 - 2.1
		local perSide = math.ceil((n - #spots) / 2)
		local length = math.max(2, perSide * 2.0)
		local holder = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
		for _, side in ipairs(if v:FindFirstChild("CutsceneBench") then {} else { -1, 1 }) do
			local bench = Instance.new("Part")
			bench.Name = "CutsceneBench"
			bench.Anchored = holder == nil or holder.Anchored
			bench.CanCollide = false
			bench.CanQuery = false
			bench.Massless = true
			bench.Material = Enum.Material.Wood
			bench.Color = Color3.fromRGB(105, 76, 52)
			bench.Size = Vector3.new(BENCH_W, 0.3, length + 0.6)
			bench.CFrame = piv * CFrame.new(side * benchX, floorY + BENCH_H - 0.15, rearZ - length / 2 + 1.0)
			if holder and not holder.Anchored then
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = bench, holder
				w.Parent = bench
			end
			bench.Parent = v
		end
		local i = 0
		while #spots < n do
			i += 1
			local side = if i % 2 == 1 then -1 else 1
			local k = math.floor((i - 1) / 2)
			local x = side * (benchX + 0.05) -- สะโพกเยื้องเข้าผนังนิดเดียว (หลังพิงผนัง)
			local z = rearZ - 0.3 - k * 2.0
			local hip = Vector3.new(x, floorY + BENCH_H + SIT_UP, z)
			-- หันหน้าเข้ากลางกระบะ (ฝั่งซ้ายหัน +X, ฝั่งขวาหัน -X)
			table.insert(spots, CFrame.lookAt(hip, hip + Vector3.new(-side, 0, 0)))
		end
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
	-- StreamingEnabled: ส่งรถทั้งคันให้ทุกเครื่องทันที (ไม่งั้นชิ้นรถ/คนขับค่อยๆ โผล่ระหว่างคัทซีน)
	v.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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

-- ระยะจากกลางรถถึงขอบตัวรถตามทิศ dir (แนวราบ) + กลางกล่องรถ — ไว้วางคนยืนข้างรถให้พ้นตัวรถจริง
-- (เดิมใช้ระยะตายตัว 2.6 จาก pivot: พอดีมอไซค์ แต่เก๋ง/กระบะกว้าง ~9 studs คนเลยยืนจมอยู่ในตัวรถ)
local function extentAlong(v: Model, dir: Vector3): (number, Vector3)
	local cf, size = v:GetBoundingBox()
	local d = Vector3.new(dir.X, 0, dir.Z)
	d = if d.Magnitude > 0 then d.Unit else Vector3.new(0, 0, 1)
	local half = math.abs(cf.RightVector:Dot(d)) * size.X / 2 + math.abs(cf.LookVector:Dot(d)) * size.Z / 2
	return half, cf.Position
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
	w.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	w:PivotTo(cf)
	w.Parent = Workspace
	-- ท่ายืนตั้งแต่โผล่ (Pedestrian.Build ยังไม่เล่นท่าอะไร: เดิมพี่ชายยืนท่า T ตั้งแต่ลงรถจนเริ่มเดิน ~1.3 วิ)
	HumanNPC.SetMoving(w, false)
	return w
end

local function headOf(m: Instance?): BasePart?
	if not m then
		return nil
	end
	local h = m:FindFirstChild("Head", true)
	return if h and h:IsA("BasePart") then h else nil
end

-- ---------------------------------------------------------------- จังหวะ
-- คัทซีนยังเล่นต่อไหม: ยังมีผู้เล่นจริงดูอยู่ (หุ่นทดสอบไม่นับ: ผู้เล่นจริงกดข้ามครบ = จบเลย ไม่เล่นต่อให้หุ่นดู)
local function alive(t: number): boolean
	if token ~= t then
		return false
	end
	for _, p in ipairs(active()) do
		if not isFake(p) then
			return true
		end
	end
	return false
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

-- ความยาวจริงของเสียงพากย์คัทซีน (วัดตอนเริ่มเซิร์ฟ) — เดิม hold ตายตัวสั้นกว่าเสียง: พูดยังไม่จบฉากก็ไปต่อ
-- (Intro_Brother_3 เสียง 3.7 วิ แต่รอแค่ 3.0 แล้วขับออกเลย / Intro_Player_1 เสียง 4.6 รอ 2.6 · ผู้ใช้ 2026-11-05)
local VOICE_TAIL = 0.35 -- เผื่อหลังเสียงจบนิดหนึ่งก่อนบรรทัดถัดไป
local voiceLen: { [string]: number } = {}
task.spawn(function()
	local folder = Instance.new("Folder")
	folder.Name = "CutsceneVoiceProbe"
	folder.Parent = game:GetService("SoundService")
	for k, id in pairs(SoundBank.DialogueUploadedIds) do
		if string.sub(k, 1, 6) == "Intro_" or string.sub(k, 1, 6) == "Outro_" then
			local s = Instance.new("Sound")
			s.SoundId = id
			s.Volume = 0
			s.Parent = folder
			task.spawn(function()
				local t0 = os.clock()
				while not s.IsLoaded and os.clock() - t0 < 20 do
					task.wait(0.2)
				end
				if s.TimeLength > 0 then
					voiceLen[k] = s.TimeLength
				end
				s:Destroy()
			end)
		end
	end
end)
local function lineLength(key: string): number
	return math.max(voiceLen[key] or 0, voiceLen[key .. "_M"] or 0, voiceLen[key .. "_F"] or 0)
end

local function say(t: number, key: string, who: { [string]: any }, head: BasePart?, hold: number): boolean
	fire("say", key, who, head)
	local len = lineLength(key)
	return wait_(t, if len > 0 then math.max(hold, len + VOICE_TAIL) else hold)
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

-- กล้องไม่โดนฉากบัง: ลองตำแหน่งตามลำดับ เลือกอันแรกที่มองเห็นจุดเป้าหมายโล่งๆ (ไม่มีตู้ปั๊ม/เสา/ผนังทึบขวาง และกล้องไม่ฝังในของ)
-- ignore = ตัวละคร/รถในฉากที่ไม่นับว่าบัง
-- เส้น a->b ผ่านกล่อง (cf, size) ไหม (ไม่นับช่วงต้นเส้น 5% = ตัวเป้ายืนชิดรถได้)
local function segmentHitsBox(a: Vector3, b: Vector3, cf: CFrame, size: Vector3): boolean
	local la, lb = cf:PointToObjectSpace(a), cf:PointToObjectSpace(b)
	local d = lb - la
	local t0, t1 = 0.05, 1
	for _, ax in ipairs({ "X", "Y", "Z" }) do
		local h = (size :: any)[ax] / 2
		local o, dv = (la :: any)[ax], (d :: any)[ax]
		if math.abs(dv) < 1e-6 then
			if o < -h or o > h then
				return false
			end
		else
			local e0, e1 = (-h - o) / dv, (h - o) / dv
			if e0 > e1 then
				e0, e1 = e1, e0
			end
			t0, t1 = math.max(t0, e0), math.min(t1, e1)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
end

local function clearCamPos(candidates: { Vector3 }, target: Vector3, ignore: { Instance }): Vector3
	-- รถพี่ชาย: ชิ้นที่มองเห็นของรถไม่รับ raycast (เหลือแค่กล่องชนล่องหน) -> เช็กกับกล่องรถแทน
	-- กล้องอยู่ในตัวรถ / เส้นสายตาผ่านตัวรถ = นับว่าบัง (เดิมกล้องไปอยู่ในกระบะ/ห้องคนขับ ภาพเห็นแต่ตัวรถ)
	local veh = Workspace:FindFirstChild("BrotherVehicle")
	local vehCF, vehSize
	if veh and veh:IsA("Model") and not table.find(ignore, veh) then
		vehCF, vehSize = veh:GetBoundingBox()
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- ตัวผู้เล่นไม่ชน/ray ไม่โดน: เช็กระยะจากเส้นสายตาเอง (ยืนขวางกลางเฟรม = นับว่าบัง)
	local list = table.clone(ignore)
	local bodies: { Vector3 } = {}
	local everyone: { any } = table.clone(Players:GetPlayers())
	table.move(fakes, 1, #fakes, #everyone + 1, everyone)
	for _, p in ipairs(everyone) do
		if p.Character then
			table.insert(list, p.Character)
			local r = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				table.insert(bodies, r.Position)
			end
		end
	end
	for _, pos in ipairs(candidates) do
		local skip = table.clone(list)
		local blocked = false
		local seg = pos - target
		if vehCF and segmentHitsBox(target, pos, vehCF, vehSize) then
			blocked = true
		end
		for _, b in ipairs(bodies) do
			local t = math.clamp((b - target):Dot(seg) / seg:Dot(seg), 0, 1)
			local near = target + seg * t
			if t > 0.08 and t < 0.95 and Vector3.new(b.X - near.X, 0, b.Z - near.Z).Magnitude < 1.4 then
				blocked = true
				break
			end
		end
		for _ = 1, if blocked then 0 else 8 do
			params.FilterDescendantsInstances = skip
			local hit = Workspace:Raycast(target, pos - target, params)
			if not hit then
				break
			end
			-- ของโปร่งใส (กำแพงล่องหน แสง) ไม่นับว่าบัง — ของประกอบฉากทึบแม้ CanCollide ปิด (ตู้ปั๊ม ใบกล้วย) นับว่าบัง
			if hit.Instance.Transparency > 0.6 then
				table.insert(skip, hit.Instance)
			else
				blocked = true
				break
			end
		end
		if not blocked then
			return pos
		end
	end
	return candidates[1]
end

-- ผู้เล่นเดินเองทั้งเส้นทางต่อเนื่อง (Client "walkpath") ไม่ถึงปลายทางในเวลาที่ควรก็วาร์ปไปปลายทาง
-- คืนฟังก์ชัน allArrived(): true เมื่อทุกคนเดินถึงปลายทางแล้ว (หรือวาร์ปไปแล้ว / หลุดออกจากเกม) ไว้ตัดไปช็อตถัดไปทันที
-- opts.finals[i] = ปลายทางเฉพาะคน (แทนการกระจายรอบจุดสุดท้ายด้วย spread)
-- opts.leads[i] = จุดแรกเฉพาะคน (ก้าวออกจากแถว/หลบของก่อนเข้าเส้นทางรวม) / opts.befores[i] = จุดก่อนปลายทางเฉพาะคน
local function walkPlayers(players: { Player }, path: { Vector3 }, spread: number, opts: { [string]: any }?): () -> boolean
	local o = opts or {}
	local pending = #players
	for i, p in ipairs(players) do
		task.spawn(function()
			local root, hum = rootOf(p)
			if not (root and hum) then
				pending -= 1
				return
			end
			follow[p] = nil
			root.Anchored = false
			hum.Sit = false
			-- เดินเรียงแถวตามทาง (ออกตัวห่างกันทีละนิด) แล้วค่อยกระจายยืนข้างกันที่จุดสุดท้าย
			task.wait((i - 1) * 0.6)
			-- ส่งทางทั้งเส้นให้ Client เดินต่อเนื่องทีเดียว (เดิมส่งทีละจุด: Client หยุดที่ทุกมุมรอ Server สั่งจุดถัดไป
			-- + Server สั่ง hum:MoveTo ชนกับ Client -> เดินกระตุกเป็นช่วงๆ ไม่ลื่นเหมือนพี่ชาย)
			local route = table.clone(path)
			route[#route] = if o.finals and o.finals[i] then o.finals[i] else path[#path] + Vector3.new(((i - 1) % 3) * spread, 0, math.floor((i - 1) / 3) * spread)
			if o.befores and o.befores[i] then
				table.insert(route, #route, o.befores[i])
			end
			if o.leads and o.leads[i] then
				table.insert(route, 1, o.leads[i])
			end
			if isFake(p) then
				fakeWalk(p, route)
			else
				remote:FireClient(p, "walkpath", route)
			end
			-- Server แค่คอยดู: ไม่ถึงปลายทางในเวลาที่ควร (ระยะรวม / ความเร็วเดิน + 4 วิ) = วาร์ปไปปลายทาง
			local total, prev = 0, root.Position
			for _, pt in ipairs(route) do
				total += (Vector3.new(pt.X - prev.X, 0, pt.Z - prev.Z)).Magnitude
				prev = pt
			end
			local final = route[#route]
			local limit = total / math.max(hum.WalkSpeed, 4) + 4
			local t0 = os.clock()
			-- ถึง = ห่างปลายทางไม่เกิน 0.9 (Client หยุดที่ 0.6) ตัวหยุดแล้วจริง ไม่ตัดช็อตตอนยังก้าวอยู่
			while p.Parent and root.Parent and (Vector3.new(root.Position.X - final.X, 0, root.Position.Z - final.Z)).Magnitude > 0.9 do
				if os.clock() - t0 > limit then
					root.CFrame = CFrame.new(final + Vector3.new(0, 3, 0)) * (root.CFrame - root.CFrame.Position)
					break
				end
				task.wait(0.1)
			end
			pending -= 1
		end)
	end
	return function()
		return pending <= 0
	end
end

-- จุดนี้ยืนได้ไหม: กล่องขนาดตัวคน (ไม่รวมเท้า 0.6 studs ล่าง) ไม่ชนของทึบที่ CanCollide
-- ใช้ GetPartsInPart (รูปทรงชนจริง) — GetPartBoundsInBox เทียบแค่กล่องครอบ ราก/กอกล้วย/เสาไฟที่เป็น mesh ใหญ่เลยกินที่เกินจริง
local probe: Part? = nil
local function standBlocked(pos: Vector3, skip: { Instance }): boolean
	if not probe then
		local pr = Instance.new("Part")
		pr.Name = "CutsceneStandProbe"
		pr.Anchored = true
		pr.CanCollide = false
		pr.CanQuery = false
		pr.CanTouch = false
		pr.Transparency = 1
		pr.Size = Vector3.new(1.6, 4.2, 1.4)
		pr.Parent = Workspace
		probe = pr
	end
	local pr = probe :: Part
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(skip)
	table.insert(list, pr)
	op.FilterDescendantsInstances = list
	-- pos = ระดับ HumanoidRootPart (พื้น + 3): กล่องจากพื้น +0.6 ถึง +4.8
	pr.CFrame = CFrame.new(pos + Vector3.new(0, -0.3, 0))
	for _, h in ipairs(Workspace:GetPartsInPart(pr, op)) do
		if h.CanCollide and h.Transparency < 0.9 then
			return true
		end
	end
	return false
end

-- จุดยืนว่าง n จุดรอบ center (ในร้าน) ห่างกัน gap: ไม่ทับโต๊ะ/ม้านั่ง/เสา ไม่ออกนอกร้าน เรียงจากใกล้ center ไปไกล
-- (เดิมกระจายเป็นตารางตายตัวจากจุดสุดท้าย: 5 คนขึ้นไปบางจุดอยู่ในโต๊ะ/ม้านั่ง คนติดแล้วคนหลังเดินดันทะลุกัน)
local function freeSpotsNear(center: Vector3, n: number, gap: number, ignore: { Instance }, outdoor: boolean?): { Vector3 }
	local skip = table.clone(ignore)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, f in ipairs(fakes) do
		table.insert(skip, f.Character)
	end
	local cands = {}
	for gx = -3, 3 do
		for gz = -3, 3 do
			table.insert(cands, center + Vector3.new(gx * gap, 0, gz * gap))
		end
	end
	table.sort(cands, function(a, b)
		return (a - center).Magnitude < (b - center).Magnitude
	end)
	local out = {}
	for _, c in ipairs(cands) do
		if #out >= n then
			break
		end
		local y = D.Pedestrian.FloorAt(c, skip)
		local pos = Vector3.new(c.X, y + 3, c.Z)
		local ok = (outdoor or D.insideShop(pos)) and not standBlocked(pos, skip)
		if ok then
			table.insert(out, if outdoor then pos else Vector3.new(c.X, center.Y, c.Z))
		end
	end
	while #out < n do -- ที่ว่างไม่พอ (ไม่ควรเกิด): ซ้อนแถวหลังจุดสุดท้าย
		table.insert(out, center + Vector3.new((#out % 3) * gap, if outdoor then 3 else 0, math.floor(#out / 3) * gap))
	end
	return out
end

-- จุดยืนข้างรถฝั่งร้าน สำหรับผู้เล่น n คน (ลงรถ / เดินมาหาพี่ชาย) เรียงตามความสำคัญ:
-- แถวแรกชิดรถเรียงไปทางหัวรถ (พี่ชายยืนท้ายรถ และเดินออกไปทางท้ายรถ = ไม่เดินผ่านใคร) ห่างกัน 1.9 studs
-- จุดที่ชนของทึบ (ตู้ปั๊ม เสาไฟ ปั๊มลม) ข้ามไปจุดถัดไป / แถวถัดไปถอยไปทางร้านอีก 2 studs
-- คืน (จุดยืน, แถวของแต่ละจุด 0 = ชิดรถ, ระยะแถวแรกจากกลางรถ, กลางรถ)
local STAND_GAP = 1.9
local function standSpots(v: Model, n: number, P: any, ignore: { Instance }): ({ Vector3 }, { number }, number, Vector3)
	local halfW, vMid = extentAlong(v, P.shopDir)
	local skip = table.clone(ignore)
	table.insert(skip, v)
	local everyone: { any } = table.clone(Players:GetPlayers())
	table.move(fakes, 1, #fakes, #everyone + 1, everyone)
	for _, p in ipairs(everyone) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	local free, blocked = {}, {}
	for row = 0, 2 do
		for col = 0, 4 do
			local flat = vMid + P.shopDir * (halfW + 1.3 + row * 2.0) + P.road * (0.8 + col * STAND_GAP)
			local pos = ground(flat) + Vector3.new(0, 3, 0)
			local solid = standBlocked(pos, skip)
			table.insert(if solid then blocked else free, { pos, row })
		end
	end
	local out, rows = {}, {}
	for _, list in ipairs({ free, blocked }) do -- ที่ว่างไม่พอ (ไม่ควรเกิด) ก็ยังได้จุดไม่ซ้ำกัน
		for _, e in ipairs(list) do
			if #out >= n then
				break
			end
			table.insert(out, e[1])
			table.insert(rows, e[2])
		end
	end
	return out, rows, halfW + 1.3, vMid
end

-- กล้องช็อตคุยกับคนขับตอนรถจอด: หน้ารถเฉียงฝั่งถนน ถอยห่างตามขนาดรถ
-- (เดิมตายตัว (7, 4.2, -7) จาก pivot: พอดีมอไซค์ แต่เก๋ง/กระบะกว้าง ~9 ยาว ~21 กล้องเลยชิดข้างรถ ข้างกระบะเต็มจอ)
local function talkCamPos(v: Model): Vector3
	local vp = v:GetPivot()
	local halfX = extentAlong(v, vp.RightVector)
	local halfZ = extentAlong(v, vp.LookVector)
	local _, size = v:GetBoundingBox()
	local x = math.max(7, halfX + 5)
	local z = -math.max(7, halfZ * 0.35 + 5)
	local y = 4.2 + math.max(0, size.Y - 4.2) * 0.6
	return clearCamPos({
		vp:PointToWorldSpace(Vector3.new(x, y, z)),
		vp:PointToWorldSpace(Vector3.new(x * 0.8, y + 1.5, z * 1.2)),
		vp:PointToWorldSpace(Vector3.new(7, 4.2, -7)),
	}, vp:PointToWorldSpace(Vector3.new(0, 4, 0.6)), { v })
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

-- กล้องตั้งนิ่งริมถนนฝั่งตรงข้ามร้าน เลยจุดจอดไปนิด หันมองรถที่วิ่งเข้ามา (แพนตามแบบนุ่มๆ ฝั่ง Client)
-- เดิมเป็นกล้องวิ่งตามข้างรถ: ตำแหน่งรถมาจาก server เป็นช่วงๆ กล้องที่ติดรถจึงสั่นทั้งภาพ โดยเฉพาะเครื่องสเปกต่ำ
local function roadsideShot(P: any, stopPos: Vector3, v: Model): { [string]: any }
	local spot = stopPos - P.shopDir * 9 + P.road * 7
	return { mode = "lookat", pos = ground(spot) + Vector3.new(0, 3.2, 0), target = v, look = Vector3.new(0, 2.2, 0), fov = 50, smooth = 4 }
end

-- ---------------------------------------------------------------- โหลดฉากก่อนเล่น
-- (เคยเห็นโมเดลรถ/พี่ชาย/ร้านค่อยๆ โผล่ช่วงต้นคัทซีน: StreamingEnabled ยังส่งฉากรอบจุดคัทซีนไม่ครบ + mesh/texture ยังโหลดไม่เสร็จ)
-- Server ขอส่งฉากรอบจุดที่กล้องจะไป -> Client โหลด mesh/texture ของรถ+พี่ชาย (ContentProvider:PreloadAsync)
-- -> ตอบ "preloaded" -> ค่อยเริ่มคัทซีน (จอยังดำอยู่ระหว่างนี้) ไม่เกิน PRELOAD_MAX วิ
local PRELOAD_MAX = 15
local preloaded: { [Player]: number } = {}
local function preloadScene(t: number, models: { Instance }, spots: { Vector3 })
	for _, p in ipairs(active()) do
		task.spawn(function()
			for _, pos in ipairs(spots) do
				pcall(function()
					p:RequestStreamAroundAsync(pos, 10)
				end)
			end
			if isFake(p) then
				preloaded[p] = t
			elseif p.Parent then
				remote:FireClient(p, "preload", models, t)
			end
		end)
	end
	local t0 = os.clock()
	while os.clock() - t0 < PRELOAD_MAX do
		local all = true
		for _, p in ipairs(active()) do
			if preloaded[p] ~= t then
				all = false
			end
		end
		if all or token ~= t then
			return
		end
		task.wait(0.1)
	end
	warn("[Cutscene] โหลดฉากไม่ครบใน " .. PRELOAD_MAX .. " วิ เริ่มคัทซีนเลย")
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
		-- (ที่นั่งไม่พอ = ต่อแถวไปท้ายรถ ไม่วางทับที่นั่งสุดท้าย)
		pin(p, v, spots[i] or (spots[#spots] or CFrame.new(0, 4, 1.6)) * CFrame.new(0, 0, (i - #spots) * 1.6), true, pillionClip(v))
	end
	-- พี่ชายตอนเดิน: สร้างไว้ก่อน (ซ่อนใต้ดิน) ให้โหลดพร้อมรถ ตอนลงรถค่อยย้ายมาวาง
	local bro = walkerAt(CFrame.new(startPos - Vector3.new(0, 200, 0)))
	preloadScene(t, { v, bro }, { startPos, stopPos, D.shutterDoor.Position })
	if not alive(t) then
		return v, bro
	end
	fire("start", "intro")
	-- 1) ขี่มาตามถนนตอนเย็น: กล้องตั้งริมถนนฝั่งตรงข้ามร้าน แพนตามรถ (ไม่วิ่งตามรถ: เครื่องสเปกต่ำเห็นภาพกระตุก)
	fire("cam", roadsideShot(P, stopPos, v))
	if not run(t, function()
		D.driveTo(v, stopPos - P.road * 9, false, 18)
		D.driveTo(v, stopPos, true, 18)
	end) then
		return v, bro
	end
	-- 2) จอดหน้าร้าน คุยกัน
	local drvHead = headOf(driverOf(v))
	local vp = v:GetPivot()
	fire("cam", { mode = "fixed", pos = talkCamPos(v), look = vp:PointToWorldSpace(Vector3.new(0, 4, 0.6)), fov = 50 })
	if not wait_(t, 1.0) then
		return v, bro
	end
	if not say(t, "Intro_Brother_1", BROTHER, drvHead, 3.4) then
		return v, bro
	end
	fire("say", nil)
	if not wait_(t, 0.8) then -- ผู้เล่นไม่มีบทพูด (ผู้ใช้ 2026-11-05): เว้นจังหวะก่อนลงรถ
		return v, bro
	end
	-- 3) ลงจากรถ: ผู้เล่นยืนหน้าร้าน พี่ชายลงเดิน
	vp = v:GetPivot()
	-- จุดลงรถคิดจากขนาดรถจริง: ฝั่งร้าน พ้นขอบตัวรถ (เดิม 2.6 จาก pivot = ยืนจมในเก๋ง/กระบะ)
	local halfW, vMid = extentAlong(v, P.shopDir)
	showDriver(v, false)
	-- พี่ชายลงก่อน ยืนเยื้องท้ายรถ
	bro:PivotTo(CFrame.lookAt(ground(vMid + P.shopDir * (halfW + 1.0) - P.road * 1.4), ground(vMid + P.shopDir * (halfW + 5))))
	-- ผู้เล่นลงทีละคนตามลำดับที่นั่ง (หน้าไปหลัง) ไปยืนจุดของตัวเอง (ไม่ทับกัน ไม่ทับพี่ชาย ไม่จมตู้ปั๊ม/เสาไฟ)
	local exiting = active()
	local exitAt = standSpots(v, #exiting, P, { bro })
	for i, p in ipairs(exiting) do
		if p.Parent and not skipped[p] then
			local pos = exitAt[i]
			pin(p, nil, CFrame.lookAt(pos, pos + P.shopDir), false)
			if i < #exiting and not wait_(t, 0.3) then
				return v, bro
			end
		end
	end
	-- 4) พี่ชายเดินอ้อมไปหลังร้าน (กล้องกว้างหน้าร้าน)
	-- กล้องอยู่ฝั่งถนน มองข้ามรถไปหาพี่ชาย/ผู้เล่น: รถสูง (เก๋ง/ตุ๊กตุ๊ก/กระบะ) บังครึ่งล่างของภาพ -> ยกกล้องตามความสูงรถ
	local _, vSize = v:GetBoundingBox()
	local lift = math.max(0, vSize.Y - 4.2)
	fire("cam", { mode = "fixed", pos = Vector3.new(P.stop.X + 10, P.stop.Y + 6 + lift, P.stop.Z - 10), look = Vector3.new(P.sideX + 4, P.stop.Y + 3, P.stop.Z + 10), fov = 55 })
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
	-- (กระบะยาว ~21 studs: จุดเดิมอยู่ในห้องคนขับพอดี ภาพโดนตัวรถบัง -> ลองจุดถัดไป: เลยหัวรถ / ยกข้ามหลังคา / ถอยไปฝั่งถนน
	--  รถนับว่าบัง ไม่ใส่ใน ignore)
	local shutterLook = Vector3.new(P.rope.X, P.stop.Y + 4, P.rope.Z)
	local shutterCam = clearCamPos({
		Vector3.new(P.stop.X + 10, P.stop.Y + 4.5, P.stop.Z - 7),
		Vector3.new(P.stop.X + 14, P.stop.Y + 5, P.stop.Z - 7),
		Vector3.new(P.stop.X + 10, P.stop.Y + 7 + lift, P.stop.Z - 7),
		Vector3.new(P.stop.X + 10, P.stop.Y + 7 + lift, P.stop.Z - 14),
	}, shutterLook, { bro })
	fire("cam", { mode = "fixed", pos = shutterCam, look = shutterLook, fov = 55 })
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
		D.Pedestrian.WalkTo(bro, ground(vMid + P.shopDir * (halfW + 1.0) - P.road * 1.6), 7)
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
	-- ตั้งตามทิศโลก (ถนน/ร้าน) ไม่ใช่ทิศรถ: รถบางคันจอดหันกลับด้าน กล้องเลยไปฝังอยู่ในตู้ปั๊ม/หลังเสา
	local broHead = headOf(bro)
	local headPos = if broHead then broHead.Position else bp + Vector3.new(0, 4.6, 0)
	-- รถนับว่าบังด้วย (รถคันใหญ่/ซาเล้งหลังคาสูงเคยบังหน้าพี่ชาย) -> มีมุมสูงข้ามหลังคารถสำรองไว้
	local camAt = clearCamPos({
		ground(bp - P.shopDir * 8 - P.road * 3) + Vector3.new(0, 5, 0),
		ground(bp - P.road * 7 - P.shopDir * 1) + Vector3.new(0, 4.5, 0),
		ground(bp - P.shopDir * 8 + P.road * 3) + Vector3.new(0, 5, 0),
		ground(bp - P.shopDir * 7 - P.road * 2) + Vector3.new(0, 7.5, 0),
		ground(bp - P.shopDir * 6) + Vector3.new(0, 9, 0),
		-- รถคันใหญ่ (กระบะ/เก๋ง) ขวางฝั่งถนนหมด: ถ่ายเลียบข้างรถฝั่งร้านจากทางท้ายรถ
		ground(bp - P.road * 7 + P.shopDir * 0.5) + Vector3.new(0, 4.5, 0),
		ground(bp - P.road * 9 + P.shopDir * 2) + Vector3.new(0, 5, 0),
		ground(bp - P.road * 5 + P.shopDir * 4) + Vector3.new(0, 5.5, 0),
	}, headPos, { bro })
	fire("cam", { mode = "lookat", pos = camAt, target = bro, look = Vector3.new(0, 4.6, 0), fov = 42 })
	if not say(t, "Intro_Brother_3", BROTHER, headOf(bro), 3.0) then
		return v, bro
	end
	-- พูดจบแล้วหยุดนิ่งสักครู่ก่อนขึ้นรถขับออก (ผู้ใช้ 2026-11-05)
	fire("say", nil)
	if not wait_(t, 1.0) then
		return v, bro
	end
	bro:Destroy()
	showDriver(v, true)
	-- กล้องมองพี่ชายขี่ออก: ตั้งฝั่งถนน (ตรงข้ามร้าน) — ผู้เล่นยืนฝั่งร้านของรถ รถจึงอยู่หน้าผู้เล่นตลอดทาง ไม่โดนตัวผู้เล่นบัง
	-- (เดิมกล้องอยู่ระหว่างรถกับตู้ปั๊ม = ผู้เล่นยืนขวางกลางเฟรม / เดิมกว่านั้นฝังอยู่ในตู้ปั๊ม)
	local stopG = Vector3.new(P.stop.X, P.stop.Y, P.stop.Z)
	local vAim = v:GetPivot().Position + Vector3.new(0, 2, 0)
	local driveCam = clearCamPos({
		stopG - P.shopDir * 9 - P.road * 4 + Vector3.new(0, 4.5, 0),
		stopG - P.shopDir * 8 + P.road * 2 + Vector3.new(0, 4, 0),
		stopG - P.shopDir * 7 + P.road * 7 + Vector3.new(0, 4, 0),
	}, vAim, { v })
	fire("cam", { mode = "lookat", pos = driveCam, target = v, look = Vector3.new(0, 2, 0), fov = 55 })
	if not run(t, function()
		D.driveTo(v, ground(D.exitPoint.Position), false, 20)
	end) then
		return v
	end
	v:Destroy()
	-- 7) ผู้เล่นเดินเข้าร้าน (กล้องในร้านมุมหลังร้าน มองออกไปทางประตู เห็นผู้เล่นเดินเข้ามาหากล้อง) -> แผงประตูปิดลง -> ตะวันตกดิน -> กลางคืน
	--    ร้านปิดอยู่ตอนเริ่มเล่น: ผู้เล่นดึงเชือกเปิดร้านเองเพื่อเริ่มคืน (เหมือนเดิม)
	local ps = active()
	do
		-- กล้องเริ่มในร้านเลย (ไม่ถ่ายจากนอกร้าน): หลังร้านฝั่งขวาของทางเดิน สูงต่ำกว่าคานหลังคา มองไปที่ช่องประตูฝั่งทางเดิน
		local shackCF, shackSize = D.shack:GetBoundingBox()
		local backZ = shackCF.Position.Z + shackSize.Z / 2
		local doorway = Vector3.new(P.aisleX - 0.7, P.stop.Y + 3.5, D.shutterDoor.Position.Z - 1.2)
		local inCam = clearCamPos({
			Vector3.new(P.aisleX + 6.8, P.stop.Y + 6, backZ - 5.5),
			Vector3.new(P.aisleX + 8.8, P.stop.Y + 6.5, backZ - 7.5),
			Vector3.new(P.aisleX - 1.2, P.stop.Y + 6, backZ - 5.5),
		}, doorway, {})
		fire("cam", { mode = "fixed", pos = inCam, look = doorway, fov = 60 })
	end
	-- เดินเข้าทางเดินซ้ายเรียงแถว อ้อมปลายโต๊ะไปยืนหลังโต๊ะ (ไม่เดินทะลุ/ติดโต๊ะ)
	local y = P.stop.Y
	-- จบที่หลังโต๊ะฝั่งทางเดิน (ไม่เดินต่อไปกลางร้าน: ตอนคัทซีนจบแล้วยังเดินไม่ถึง ตัวจะเดินข้างตามกล้อง)
	local path = table.clone(P.doorPath)
	path[#path] = Vector3.new(P.aisleX + 1.5, y, P.counterBack + 1.8)
	-- คนที่ยืนใกล้ประตูที่สุด (ทางท้ายรถ) ออกเดินก่อน = ไม่มีใครเดินแซงทะลุกัน
	-- ทุกคนก้าวออกไปทางถนน (ที่รถเพิ่งออกไป) 2.2 studs ก่อน: แถวหลังไม่เดินเฉียดตู้ปั๊ม
	local doorEntry = path[1]
	table.sort(ps, function(a, b)
		local ra, rb = rootOf(a), rootOf(b)
		local da = if ra then (Vector3.new(ra.Position.X - doorEntry.X, 0, ra.Position.Z - doorEntry.Z)).Magnitude else 0
		local db = if rb then (Vector3.new(rb.Position.X - doorEntry.X, 0, rb.Position.Z - doorEntry.Z)).Magnitude else 0
		return da < db
	end)
	local leads = {}
	for i, p in ipairs(ps) do
		local r = rootOf(p)
		if r then
			leads[i] = Vector3.new(r.Position.X, y, r.Position.Z) - P.shopDir * 2.2
		end
	end
	-- จุดยืนสุดท้ายหลังโต๊ะคนละจุด (ว่างจริง): คนแรกที่เข้าร้านเดินไปจุดลึกสุด (ไกลประตู) คนถัดไปจุดที่ใกล้ประตูกว่า = ไม่มีใครเดินผ่านคนที่ยืนแล้ว
	local spotsIn = freeSpotsNear(path[#path], #ps, 2.0, {})
	local doorIn = path[#path - 1] or path[1]
	table.sort(spotsIn, function(a, b)
		return (Vector3.new(a.X - doorIn.X, 0, a.Z - doorIn.Z)).Magnitude > (Vector3.new(b.X - doorIn.X, 0, b.Z - doorIn.Z)).Magnitude
	end)
	walkPlayers(ps, path, 1.8, { leads = leads, finals = spotsIn })
	-- รอจนทุกคนเดินถึงหลังโต๊ะจริง (ไม่ใช่แค่พ้นแผง: เดิมช็อตถัดไปเริ่มตอนผู้เล่นยังอยู่ปากประตู กล้องที่ถอยหลังผู้เล่นเลยหลุดออกนอกผนัง)
	-- ไม่เกิน 12 วิ (walkPlayers วาร์ปให้ถ้าติด)
	local finalSpot = path[#path]
	-- หลายคนยืนกระจายรอบจุดสุดท้าย: นับว่าถึงเมื่ออยู่ในระยะจุดที่ไกลสุดที่แจกไป
	local reach = 1.8
	for _, sp in ipairs(spotsIn) do
		reach = math.max(reach, (Vector3.new(sp.X - finalSpot.X, 0, sp.Z - finalSpot.Z)).Magnitude + 1.2)
	end
	local t0 = os.clock()
	while os.clock() - t0 < 12 do
		local all = true
		for _, p in ipairs(active()) do
			local root = rootOf(p)
			if root and (not D.insideShop(root.Position) or Vector3.new(root.Position.X - finalSpot.X, 0, root.Position.Z - finalSpot.Z).Magnitude > reach) then
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
	if not wait_(t, 0.5) then
		return
	end
	-- 8) ลมกรรโชกพัดเข้าหน้าร้าน (เสียงลม ฝุ่น ใบไม้ปลิว กล้องสั่น) จนแผงสังกะสีหล่นปิดเอง -> ผู้เล่นหันไปมอง "อ้าวเห้ย..."
	--    กล้องในร้าน มองข้ามหัวผู้เล่นไปที่แผงหน้าร้าน
	local door = D.shutterDoor.Position
	-- กล้องอยู่หลังผู้เล่น (ฝั่งในร้าน) มองข้ามไหล่ไปที่แผง: เห็นทั้งคนและแผงที่ปิดลง
	local sum, cnt = Vector3.zero, 0
	for _, p in ipairs(active()) do
		local r = rootOf(p)
		if r then
			sum += r.Position
			cnt += 1
		end
	end
	local mid = if cnt > 0 then sum / cnt else Vector3.new(P.aisleX + 1.5, y, P.counterBack + 1.8)
	local away = Vector3.new(mid.X - door.X, 0, mid.Z - door.Z)
	away = if away.Magnitude > 0.1 then away.Unit else P.shopDir
	-- (ถอยห่างพอ: กล้องโหมด fixed ค่อยๆ ดันเข้าหาจุดมอง ~2.5 studs) เยื้องข้างนิดให้หัวไม่บังแผง
	local side = away:Cross(Vector3.yAxis)
	local camPos = Vector3.new(mid.X, if cnt > 0 then mid.Y + 3.2 else y + 6, mid.Z) + away * 6 - side * 1.6
	-- กล้องต้องเริ่มในร้านเสมอ (เดิมผู้เล่นยืนชิดผนังซ้าย กล้องถอยหลังผู้เล่น 6 studs เลยไปอยู่นอกผนังแล้วค่อยดันเข้ามา)
	-- บีบให้อยู่ในกล่องเพิง ห่างผนัง 2.5 studs แล้วเลือกจุดที่มองเห็นแผงโล่งๆ (มีจุดหลังร้านสำรอง)
	do
		local shackCF, shackSize = D.shack:GetBoundingBox()
		local function inside(p: Vector3): Vector3
			local lp = shackCF:PointToObjectSpace(p)
			local hx, hz = shackSize.X / 2 - 2.5, shackSize.Z / 2 - 2.5
			return shackCF:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -hx, hx), lp.Y, math.clamp(lp.Z, -hz, hz)))
		end
		local backZ = shackCF.Position.Z + shackSize.Z / 2
		camPos = clearCamPos({
			inside(camPos),
			inside(Vector3.new(mid.X + 3, y + 6, backZ - 6)),
			inside(Vector3.new(P.aisleX + 6.8, y + 6, backZ - 5.5)),
		}, Vector3.new(door.X, y + 3.4, door.Z), {})
	end
	fire("cam", { mode = "fixed", pos = camPos, look = Vector3.new(door.X, y + 3.4, door.Z), fov = 58 })
	if not wait_(t, 0.6) then
		return
	end
	fire("gust", door, P.shopDir)
	if not wait_(t, 1.1) then
		return
	end
	D.resetShutter() -- แผงสังกะสีปิดลงหลังผู้เล่นเข้าร้าน (ถ้ายังไม่มีใครข้ามไปดึงเชือกเปิดร้านจริงแล้ว)
	fire("shake", 0.45, 0.6)
	-- ทุกคนหันไปทางแผงที่ปิดลง
	for _, p in ipairs(active()) do
		local r = rootOf(p)
		if r then
			pin(p, nil, CFrame.lookAt(r.Position, Vector3.new(door.X, r.Position.Y, door.Z)), false)
		end
	end
	if not wait_(t, 0.7) then
		return
	end
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
	table.clear(skipVotes)
	shopSlots = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if ready[p] and p.Character then
			participants[p] = true
		end
	end
	-- (ครั้งเดียว: อ่านแล้วล้าง คัทซีนรอบถัดไปไม่มีหุ่นถ้าไม่สั่งใหม่)
	local dev = game:GetService("ServerStorage"):FindFirstChild("DevDecision")
	local nFake = dev and tonumber(dev:GetAttribute("CutsceneDummies"))
	if dev then
		dev:SetAttribute("CutsceneDummies", nil)
	end
	if RunService:IsStudio() and nFake and nFake > 0 and next(participants) ~= nil then
		makeFakes(math.min(nFake, 8))
		for _, f in ipairs(fakes) do
			participants[f] = true
		end
	end
	return token
end

local function finish(kind: string, place: boolean)
	for _, p in ipairs(active()) do
		do
			send(p, "end", kind)
			release(p, if place then nextShopSpot() else nil)
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
	for _, p in ipairs(active()) do
		do
			local root = rootOf(p)
			local inside = root and D.insideShop(root.Position)
			send(p, "end", "intro")
			release(p, if inside then nil else nextShopSpot())
		end
	end
	clearFakes()
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
	-- แผงหน้าร้านต้องเปิดอยู่ตอนเริ่ม (แล้วค่อยปิดลงในข้อ 1)
	D.showShutterOpen()
	-- รถพี่ชาย: สร้างไว้ตั้งแต่ต้นคัทซีน (จอดรอที่จุดเกิดไกลๆ) ให้ส่งถึงทุกเครื่องก่อนถึงช็อตขี่มารับ
	-- (เดิมสร้างตอนจะถ่ายพอดี Client ยังไม่มีรถ = กล้องหาเป้าไม่เจอ ค้างมุมเดิม ไม่จับที่พี่ชาย)
	local startPos = ground(D.spawnPoint.Position)
	local stopPos = ground(P.stop + P.shopDir * 0.5)
	local v = buildVehicle(n, CFrame.lookAt(startPos, startPos + P.road))
	if not v then
		return
	end
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
	-- มุมหลังร้านฝั่งซ้าย: จุดยืนว่างจริงคนละจุด (เดิมตารางแถวละ 2 คน: คนที่ 3 ขึ้นไปยืนบนยอดกอกล้วย
	-- เพราะยิงหาพื้นโดนกอกล้วยก่อน -> ตัวค้างเดินไม่ได้ ถูกวาร์ปไปหน้ารถ) คนแรกที่ออกเดินยืนใกล้ทางเดินสุด
	local outPs = active()
	local backAt = freeSpotsNear(Vector3.new(P.sideX + 1.5, P.stop.Y, P.backZ + 0.5), #outPs, 1.9, {}, true)
	local lane = Vector3.new(P.sideX, P.stop.Y, P.backZ)
	table.sort(backAt, function(a, b)
		return (Vector3.new(a.X - lane.X, 0, a.Z - lane.Z)).Magnitude < (Vector3.new(b.X - lane.X, 0, b.Z - lane.Z)).Magnitude
	end)
	for i, p in ipairs(outPs) do
		local _, hum = rootOf(p)
		if hum then
			hum:SetAttribute("PoseClip", nil)
		end
		local pos = backAt[i]
		pin(p, nil, CFrame.lookAt(pos, pos - P.shopDir), false)
	end
	fire("fade", false, 0.6)
	-- 2) พี่ชายขี่รถกลับมา: กล้องริมถนนหันตามหัวพี่ชาย (คนขับ) ไม่ใช่กลางรถ
	local shot = roadsideShot(P, stopPos, v)
	local broHead = headOf(driverOf(v))
	if broHead then
		shot.target = broHead
		shot.look = Vector3.new(0, -0.3, 0)
	end
	fire("cam", shot)
	if not run(t, function()
		D.driveTo(v, stopPos - P.road * 9, false, 18)
		D.driveTo(v, stopPos, true, 18)
	end) then
		return v
	end
	-- 3) ผู้เล่นเดินออกมาจากหลังร้าน
	local vp = v:GetPivot()
	-- จุดนัดพบ: จุดยืนข้างรถฝั่งร้านแบบเดียวกับตอนลงรถ (เดิม 3.2 จาก pivot + กระจายตามแกนโลก = ยืนจมในเก๋ง/กระบะ / ทับตู้ปั๊ม)
	local walkers = active()
	local slots, rows, rowDist, vMid = standSpots(v, #walkers, P, {})
	local meet = ground(vMid + P.shopDir * rowDist)
	-- เดินมาจากท้ายรถ: คนแรกที่ออกเดินไปจุดที่ไกลสุด (ทางหัวรถ / แถวนอก) คนถัดไปจุดที่ใกล้กว่า = ไม่มีใครเดินผ่านคนที่ยืนรอแล้ว
	local order = {}
	for i = 1, #slots do
		order[i] = i
	end
	table.sort(order, function(a, b)
		local da, db = slots[a]:Dot(P.road), slots[b]:Dot(P.road)
		if math.abs(da - db) > 0.3 then
			return da > db
		end
		return rows[a] > rows[b]
	end)
	-- แถวนอก: เดินเลียบรถมาตามแถวแรกก่อน (เลยหัวแถวแรกไม่ได้: เสาไฟ) แล้วค่อยก้าวออกไปยืน = ไม่เฉียดตู้ปั๊ม
	local lineZ = vMid + P.shopDir * (rowDist - 0.7)
	local headX = -math.huge
	for i, pos in ipairs(slots) do
		if rows[i] == 0 then
			headX = math.max(headX, pos:Dot(P.road))
		end
	end
	local finals, befores = {}, {}
	for k, idx in ipairs(order) do
		local pos = slots[idx]
		finals[k] = Vector3.new(pos.X, meet.Y, pos.Z)
		if rows[idx] > 0 and headX > -math.huge then
			local along = math.min(pos:Dot(P.road), headX)
			local b = lineZ - P.road * lineZ:Dot(P.road) + P.road * along
			befores[k] = Vector3.new(b.X, meet.Y, b.Z)
		end
	end
	fire("cam", { mode = "fixed", pos = Vector3.new(P.sideX - 9, P.stop.Y + 5, P.stop.Z - 4), look = Vector3.new(P.sideX + 2, P.stop.Y + 3, P.stop.Z + 14), fov = 60 })
	-- เดินถึงหน้ารถแล้วหยุดปุ๊บ = ตัดไปช็อตคุยกันเลย (เดิมรอตายตัว 7.5 วิ ยืนนิ่งรอนาน) ไม่เกิน 12 วิ
	local arrived = walkPlayers(walkers, { Vector3.new(P.sideX, meet.Y, P.backZ), Vector3.new(P.sideX, meet.Y, P.stop.Z + 6), meet }, 2.2, { finals = finals, befores = befores })
	local walkT0 = os.clock()
	while not arrived() and os.clock() - walkT0 < 12 do
		if not wait_(t, 0.1) then
			return v
		end
	end
	-- 4) คุยกัน
	for _, p in ipairs(active()) do
		local root = rootOf(p)
		if root then
			pin(p, nil, CFrame.lookAt(root.Position, Vector3.new(vp.Position.X, root.Position.Y, vp.Position.Z)), false)
		end
	end
	fire("cam", { mode = "fixed", pos = talkCamPos(v), look = vp:PointToWorldSpace(Vector3.new(0, 4, 2)), fov = 50 })
	if not say(t, "Outro_Brother_1", BROTHER, headOf(driverOf(v)), 3.0) then
		return v
	end
	fire("say", nil)
	if not wait_(t, 1.0) then -- ผู้เล่นไม่มีบทพูด: เว้นจังหวะระหว่างประโยคพี่ชาย
		return v
	end
	if not say(t, "Outro_Brother_2", BROTHER, headOf(driverOf(v)), 2.6) then
		return v
	end
	fire("say", nil)
	-- เหมือนตอนเปิดเกม: พูดจบ เว้นนิดหนึ่งก่อนขึ้นรถ
	if not wait_(t, 0.8) then
		return v
	end
	-- 5) ขึ้นรถ ขี่ออกไปรับแสงเช้า
	-- ขึ้นรถทีละคน ที่นั่งตามลำดับเดียวกับขามา (ไม่นั่งซ้อนกัน)
	local spots = seatSpots(v, n)
	local boarding = active()
	for i, p in ipairs(boarding) do
		if p.Parent and not skipped[p] then
			pin(p, v, spots[i] or (spots[#spots] or CFrame.new(0, 4, 1.6)) * CFrame.new(0, 0, (i - #spots) * 1.6), true, pillionClip(v))
			if i < #boarding and not wait_(t, 0.3) then
				return v
			end
		end
	end
	-- กล้องหน้าร้านมองรถขี่ออก: เดิมตั้งที่ StopPoint + 9 ทางร้าน = ฝังอยู่ในตู้ปั๊ม -> ยืนระหว่างรถกับตู้ปั๊มแทน (เลือกมุมที่ไม่โดนบัง)
	local stopG = Vector3.new(P.stop.X, P.stop.Y, P.stop.Z)
	local vAim = v:GetPivot().Position + Vector3.new(0, 2, 0)
	local shopFront = clearCamPos({
		stopG + P.shopDir * 5 + P.road * 4 + Vector3.new(0, 4, 0),
		stopG + P.shopDir * 5 - P.road * 6 + Vector3.new(0, 4, 0),
		stopG + P.shopDir * 4.5 - P.road * 2 + Vector3.new(0, 4.5, 0),
	}, vAim, { v })
	fire("cam", { mode = "lookat", pos = shopFront, target = v, look = Vector3.new(0, 2, 0), fov = 55 })
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
		send(p, "summary", summary)
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
	clearFakes()
	token += 1
end

function Cutscene.Running(): string?
	return running
end

-- นับโหวตข้าม: ผู้เล่นจริงที่ยังดูคัทซีนอยู่ (หุ่นทดสอบใน Studio นับว่าโหวตแล้ว) ครบ = ข้ามพร้อมกันทุกคน
checkSkipVotes = function()
	if not running then
		return
	end
	local viewers: { Player } = {}
	for p in pairs(participants) do
		if not isFake(p) and p.Parent and not skipped[p] then
			table.insert(viewers, p)
		end
	end
	if #viewers == 0 then
		return
	end
	local votes = 0
	for _, p in ipairs(viewers) do
		if skipVotes[p] then
			votes += 1
		end
	end
	for _, p in ipairs(viewers) do
		remote:FireClient(p, "skipvote", votes, #viewers)
	end
	if votes < #viewers then
		return
	end
	local kind = running
	for _, p in ipairs(viewers) do
		skipped[p] = true
		remote:FireClient(p, "end", kind)
		-- จุดยืนในร้านไม่ซ้ำกัน (Outro เดิมใช้จุดที่ 1 ทุกคน = ยืนทับกัน)
		release(p, nextShopSpot())
	end
	-- หุ่นทดสอบ: ข้ามไปด้วย (ไม่มีใครดูต่อแล้ว)
	for _, f in ipairs(fakes) do
		if participants[f] and not skipped[f] then
			skipped[f] = true
		end
	end
	print("⏭️ ทุกคนโหวตครบ: ข้ามคัทซีน " .. tostring(kind))
end

function Cutscene.Init(deps: { [string]: any })
	D = deps
	remote = deps.remote("Cutscene")
	remote.OnServerEvent:Connect(function(p: Player, action: any, arg: any)
		if action == "preloaded" then
			if type(arg) == "number" then
				preloaded[p] = arg
			end
		elseif action == "ready" then
			ready[p] = true
			-- ไม่มีคัทซีนรอให้ดู (เข้ามากลางคืน / คัทซีนเล่นไปแล้ว): บอกให้ Client เอาจอดำออก
			if not introWaiting then
				remote:FireClient(p, "nocutscene")
			end
		elseif action == "skip" and running and participants[p] and not skipped[p] and not skipVotes[p] then
			skipVotes[p] = true
			print("⏭️ [" .. p.Name .. "] โหวตข้ามคัทซีน " .. tostring(running))
			checkSkipVotes()
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		ready[p] = nil
		preloaded[p] = nil
		participants[p] = nil
		skipped[p] = nil
		follow[p] = nil
		skipVotes[p] = nil
		-- คนที่ยังไม่โหวตออกไป: ที่เหลืออาจโหวตครบแล้ว
		task.defer(checkSkipVotes)
	end)
	-- ตายแล้วเกิดใหม่ระหว่างคัทซีน: ตัวใหม่ไม่ต้องยึด
	Players.PlayerAdded:Connect(function(p)
		p.CharacterAdded:Connect(function()
			follow[p] = nil
		end)
	end)
end

return Cutscene
