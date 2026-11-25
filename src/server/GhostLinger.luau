--!strict
-- GhostLinger.luau (ModuleScript ฝั่ง Server)
-- ปิดแผงใส่ผีแล้ว ผีไม่ได้ไปไหนทันทีเสมอ: บางตัวหายวับ บางตัวมาเคาะแผงสังกะสี วิ่งป่วนรอบร้าน หรือวิ่งเล่นบนหลังคา
--   ระหว่างผียังวนอยู่ (Active) ถ้ามีคนเปิดแผง = โดนหลอกทั้งร้าน (CoreLoop.toggleShutter เรียก Scare)
--   ต้องรอจนผีหายไปเองถึงจะเปิดร้านได้ปลอดภัย · ลูกค้าคนถัดไปรอจนผีไปแล้ว
--   คนที่โดนหลอกนอกร้านนอนล้มตาปรือจนผีตัวนี้ไป (CoreLoop.Rampage)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))
local KnockPlan = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KnockPlan")) :: any

local GhostLinger = {}

GhostLinger.Config = {
	Stay = { 14, 22 }, -- วินาทีที่ผีวนอยู่หลังโดนปิดแผงใส่
	-- น้ำหนักสุ่มพฤติกรรม (vanish = หายไปทันทีแบบเดิม)
	Weights = { vanish = 3.5, knock = 2.5, circle = 2, roof = 2 },
	RunSpeed = 13, -- วิ่งรอบร้าน (studs/วินาที)
	-- ผู้ใช้ 2026-11-22 "ผีเคาะแผงอย่าให้เจอซ้ำของเดิม 1 เกมเจอได้มากสุดแค่ 3 ครั้ง"
	KnockMax = 3, -- ปอบเคาะแผงต่อคืน
	NoRepeat = true, -- ผีวนแบบเดียวกันห้ามออกติดกัน 2 ครั้ง (ไม่นับหายวับ vanish)
}

-- นับต่อคืน (รีเซ็ตเมื่อเปิดร้านคืนใหม่: Remotes ShopOpen false -> true)
local lastShown: string? = nil
local knockCount = 0
local kumanCount = 0
task.spawn(function()
	local remotesF = ReplicatedStorage:WaitForChild("Remotes")
	local was = remotesF:GetAttribute("ShopOpen") == true
	remotesF:GetAttributeChangedSignal("ShopOpen"):Connect(function()
		local open = remotesF:GetAttribute("ShopOpen") == true
		if open and not was then
			lastShown = nil
			knockCount = 0
			kumanCount = 0
		end
		was = open
	end)
end)

local interactive = Workspace:WaitForChild("InteractiveProps")
local shack = Workspace:WaitForChild("MapEnvironment"):WaitForChild("ShackStructure") :: Model

local current: { group: Model, conn: RBXScriptConnection?, token: number }? = nil
local token = 0

-- เอฟเฟกต์ของกุมาร/กระหังบนเครื่องผู้เล่น (client/LingerFX)
local fxRemote: RemoteEvent
do
	local remotesF = ReplicatedStorage:WaitForChild("Remotes")
	local e = remotesF:FindFirstChild("LingerFX")
	if not (e and e:IsA("RemoteEvent")) then
		e = Instance.new("RemoteEvent")
		e.Name = "LingerFX"
		e.Parent = remotesF
	end
	fxRemote = e :: RemoteEvent
end

-- คนที่ยืนอยู่ในร้าน (สุ่ม 1 คน) ผีเล็งคนนี้
local function victimPos(): Vector3?
	local cf, size = shack:GetBoundingBox()
	local dr = interactive:FindFirstChild("ShutterDoor") :: BasePart?
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hrp:IsA("BasePart") and hum and hum.Health > 0 then
			local lp = cf:PointToObjectSpace(hrp.Position)
			if math.abs(lp.X) < size.X / 2 and lp.Z < size.Z / 2 and (not dr or hrp.Position.Z > dr.Position.Z) then
				table.insert(list, hrp.Position)
			end
		end
	end
	return if #list > 0 then list[math.random(#list)] else nil
end

local function door(): BasePart?
	return interactive:FindFirstChild("ShutterDoor") :: BasePart?
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

-- หลังคาร้าน: ยิงลงมาจากข้างบน ชนอะไรก่อนในร้าน = ผิวหลังคา
local function roofAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { shack }
	local hit = Workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), params)
	return if hit then hit.Position.Y else 13
end

-- หลังคาสูงสุดใต้ตัวผี (ยิงหลายจุดรอบเท้า: ลอนสังกะสี/ขอบแผ่น ไม่ให้ส่วนไหนจมลงไปโผล่ใต้หลังคาในร้าน)
local ROOF_SKIN = 0.35 -- เนื้อเท้า/นิ้วเท้าหนาเกินกระดูกออกมา + กันลอนสังกะสี
local ROOF_FOOT = 1.6 -- รัศมีรอยเท้า (studs)
local function roofTop(x: number, z: number): number
	local top = roofAt(x, z)
	for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		top = math.max(top, roofAt(x + o[1] * ROOF_FOOT, z + o[2] * ROOF_FOOT))
	end
	return top
end

local function fade(root: Instance, t: number, time: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = t }):Play()
			else
				d.Transparency = t
			end
		end
	end
end

local function shutterClosed(): boolean
	local d = door()
	if not d then
		return false
	end
	local openY = d:GetAttribute("OpenY") or 15.5
	local closedY = d:GetAttribute("ClosedY") or 6.0
	return d.Position.Y < (openY + closedY) / 2
end

-- mustStay = ห้ามหายไปเฉยๆ (มีคนล้มรอผีปั่นป่วนอยู่) · แผงเปิดอยู่ = ไม่มีแผงให้เคาะ
local function pickBehavior(mustStay: boolean?): string
	local closed = shutterClosed()
	local w = {}
	for k, v in pairs(GhostLinger.Config.Weights) do
		local blocked = (k == "vanish" and mustStay) or (k == "knock" and not closed)
			or (k == "knock" and knockCount >= GhostLinger.Config.KnockMax)
			or (GhostLinger.Config.NoRepeat and k ~= "vanish" and k == lastShown)
		if not blocked then
			w[k] = v
		end
	end
	local total = 0
	for _, v in pairs(w) do
		total += v
	end
	local r = math.random() * total
	for k, v in pairs(w) do
		r -= v
		if r <= 0 then
			return k
		end
	end
	return if mustStay then "circle" else "vanish"
end

function GhostLinger.Active(): boolean
	return current ~= nil
end

function GhostLinger.Group(): Model?
	return if current then current.group else nil
end

-- จบเอง / ถูกเปิดแผง: ผีจางหาย คืนกลุ่มโมเดล (ใช้เป็น source ของจอผีหลอก)
function GhostLinger.Stop(): Model?
	local c = current
	current = nil
	if not c then
		return nil
	end
	if c.conn then
		c.conn:Disconnect()
	end
	local d = door()
	if d and d:GetAttribute("LingerRest") then
		d:SetAttribute("LingerRest", nil)
	end
	local g = c.group
	fxRemote:FireAllClients("hush", false)
	for _, m in ipairs(g:GetChildren()) do
		m:SetAttribute("KnockEnd", true) -- ผีเคาะแผง: หยุดเคาะ/เอฟเฟกต์ทุกเครื่อง (client/KnockFX)
	end
	task.delay(1.2, function()
		fade(g, 1, 1.2)
		task.delay(1.3, function()
			g:Destroy()
		end)
	end)
	return g
end

local function spawnIn(group: Model, name: string, cf: CFrame, clip: string): Model?
	local m = GhostNPC.Spawn(name, cf, clip)
	if m then
		m.Parent = group
	end
	return m
end

-- เริ่มหลังปิดแผงใส่ผี: คืน false = ผีหายไปทันที (ไม่วน)
-- สุ่มพฤติกรรมไว้ก่อน (CoreLoop ใช้ตัดสินว่าลูกค้าผีต้องพูดก่อนไหม: เคาะแผง = ไม่พูด เคาะเลย) แล้วส่งให้ Start
GhostLinger.Pick = pickBehavior

-- ลูกค้าผีที่เพิ่งถูกไล่ (CoreLoop ตั้งก่อน Start): ผีเคาะแผงแบบเลียนเสียงใช้เสียงคนนี้
GhostLinger.Speaker = nil :: { [string]: any }?
local DEFAULT_SPEAKER = { name = "Name_Boonmee", voice = "M", cast = "adult_m" } -- ยังไม่มีลูกค้า (แผง admin / สมุดหมอผี)

-- เลียนเสียงลูกค้า: ซับขึ้นชื่อลูกค้าคนเดิม เสียงอู้อี้ผ่านแผง (SoundBank อ่าน speaker.mimic = ความเร็วเสียง)
local function sayLines(lines: { any }, m: Model, my: number, alive: () -> boolean)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local speech = remotes and remotes:FindFirstChild("CustomerSpeech")
	if not (speech and speech:IsA("RemoteEvent")) then
		return
	end
	local who = GhostLinger.Speaker or DEFAULT_SPEAKER
	local head = m:FindFirstChild("BodyHead") or m:FindFirstChild("RootPart")
	for _, l in ipairs(lines) do
		task.delay(l.t, function()
			if not alive() then
				return
			end
			speech:FireAllClients(l.key, head, { name = who.name, voice = who.voice, cast = who.cast, mimic = l.speed }, nil)
			task.wait(2.8)
			if token == my then
				speech:FireAllClients(nil)
			end
		end)
	end
end

-- force = เรียกจากแผง admin (ทดสอบ): ใช้ picked ตรงๆ ไม่สุ่มใหม่ ไม่นับโควตา/ห้ามซ้ำของคืนนั้น
function GhostLinger.Start(mustStay: boolean?, picked: string?, force: boolean?): boolean
	if current then
		GhostLinger.Stop()
	end
	local behavior = picked or pickBehavior(mustStay)
	-- "knock:build|mimic|fake" / "circle:inside|leave" / "roof:fake|leave" (แผง admin) = บังคับแบบ
	local variant: string? = nil
	local bName, bVariant = string.match(behavior, "^(%a+):(%a+)$")
	if bName then
		behavior, variant = bName, bVariant
	end
	-- ที่เลือกไว้ล่วงหน้า (CoreLoop.Pick) แต่เกินโควตา/ซ้ำแล้ว: สุ่มใหม่
	if not force and (behavior == "knock" and knockCount >= GhostLinger.Config.KnockMax
		or (GhostLinger.Config.NoRepeat and behavior ~= "vanish" and behavior == lastShown)) then
		behavior = pickBehavior(mustStay)
	end
	if behavior == "vanish" then
		return false
	end
	if not force then
		lastShown = behavior
		if behavior == "knock" then
			knockCount += 1
		end
	end
	local d = door()
	if not d then
		return false
	end
	local cfg = GhostLinger.Config
	token += 1
	local my = token
	local group = Instance.new("Model")
	group.Name = "LingeringGhost"
	group:SetAttribute("FocusBone", "head")
	group:SetAttribute("Behavior", behavior)
	group.Parent = Workspace:FindFirstChild("AnomalyProps") or Workspace
	local scf, ssize = shack:GetBoundingBox()
	local stay = cfg.Stay[1] + math.random() * (cfg.Stay[2] - cfg.Stay[1])
	local conn: RBXScriptConnection? = nil
	local root: BasePart? = nil

	if behavior == "knock" then
		-- ปอบเคาะแผงจากด้านนอก จังหวะทั้งหมดอยู่ใน shared/KnockPlan (ครั้งที่ 1/2/3 ของคืนไม่ซ้ำแบบ)
		-- มือ = client/GhostAnimRunner, เสียง แผงสั่น ไฟ ฝุ่น จอ = client/KnockFX (ทุกเครื่องเล่นจากตารางเดียวกัน ตรงกันพอดี)
		-- ระยะเท้า-แผง: ท่า mocap Pop_KnockShutter บนร่าง v2 ปลายนิ้วยื่นไปหน้าสุด 2.48 studs (วัดใน Studio 2026-11-13)
		-- เดิม 1.94 (ท่าเก่า) มือทะลุแผง (ผู้ใช้ 2026-11-13) -> 2.52 ปลายนิ้วแตะผิวแผงพอดี
		if not variant then
			variant = if force then KnockPlan.ORDER[math.random(#KnockPlan.ORDER)] else KnockPlan.ORDER[(knockCount - 1) % #KnockPlan.ORDER + 1]
		end
		local plan = KnockPlan.Build(variant)
		stay = plan.finish
		group:SetAttribute("Variant", variant)
		local x = d.Position.X + (math.random() - 0.5) * 10
		local z = d.Position.Z - d.Size.Z / 2 - 2.52
		local feet = Vector3.new(x, groundAt(x, z), z)
		local m = spawnIn(group, "Pop", CFrame.lookAt(feet, feet + Vector3.new(0, 0, 1)), "KnockShutter")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		if m then
			local t0 = Workspace:GetServerTimeNow()
			m:SetAttribute("KnockHushTo", t0 + plan.hushTo)
			m:SetAttribute("KnockPlan", KnockPlan.Encode(plan, t0))
			m:SetAttribute("KnockFace", 2.52) -- ระยะเท้าถึงผิวแผง (หมัดแตะพอดี)
			game:GetService("CollectionService"):AddTag(m, "KnockGhost")
			sayLines(plan.lines, m, my, function()
				return current ~= nil and current.token == my
			end)
		end
	elseif behavior == "circle" then
		-- กุมารทองชวนเล่นซ่อนหา (ผู้ใช้ 2026-11-26): วิ่งรอบร้าน เร่ง/ชะลอ/กลับทิศ หยุดตรงผนังใกล้คน เคาะเบาๆ หัวเราะคิก
		--   บางทีไปโผล่อีกฝั่ง · ตอนจบเสียงเท้าเข้ามาในร้าน (เสียงเท้า เคาะ = client/LingerFX)
		local xMax, zBack = ssize.X / 2 + 4, scf.Z + ssize.Z / 2 + 4
		local zFront = d.Position.Z - 1.8 -- ใต้ชายคาหน้าแผง (เดิมวิ่งทะลุตู้ปั๊ม)
		local corners = {
			Vector3.new(scf.X - xMax, 0, zFront),
			Vector3.new(scf.X + xMax, 0, zFront),
			Vector3.new(scf.X + xMax, 0, zBack),
			Vector3.new(scf.X - xMax, 0, zBack),
		}
		local lens, total = {}, 0
		for i = 1, 4 do
			lens[i] = (corners[i % 4 + 1] - corners[i]).Magnitude
			total += lens[i]
		end
		local function at(sv: number): (Vector3, Vector3)
			local r = sv % total
			for i = 1, 4 do
				if r <= lens[i] then
					local a, b = corners[i], corners[i % 4 + 1]
					local p = a:Lerp(b, r / lens[i])
					return Vector3.new(p.X, groundAt(p.X, p.Z), p.Z), (b - a).Unit
				end
				r -= lens[i]
			end
			return corners[1], Vector3.xAxis
		end
		-- จุดบนเส้นรอบร้านที่ใกล้ตำแหน่งนี้สุด
		local function nearest(pos: Vector3, skip: number?): (number, number)
			local best, bestD, acc, bestI = 0, math.huge, 0, 1
			for i = 1, 4 do
				local a, b = corners[i], corners[i % 4 + 1]
				local dir = (b - a).Unit
				local t = math.clamp((Vector3.new(pos.X, 0, pos.Z) - a):Dot(dir), 0, lens[i])
				local dd = (Vector3.new(pos.X, 0, pos.Z) - (a + dir * t)).Magnitude
				if dd < bestD and i ~= skip then
					best, bestD, bestI = acc + t, dd, i
				end
				acc += lens[i]
			end
			return best, bestI
		end
		local sv = math.random() * total
		local first = at(sv)
		local m = spawnIn(group, "ghost_kuman_thong", CFrame.lookAt(first, Vector3.new(scf.X, first.Y, scf.Z)), "kuman_giggle")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		stay = 34 -- กันค้างเฉยๆ: จบเองตามบทด้านล่าง
		if m and root then
			local rootPart = root :: BasePart
			game:GetService("CollectionService"):AddTag(m, "KumanRunner")
			if not force then
				kumanCount += 1
			end
			-- variant "inside" / "leave" = บังคับตอนจบ (แผง admin) · ไม่บังคับ: ครั้งแรกของคืนเข้าร้านเสมอ ต่อไป 55%
			local finale = variant == "inside" or (variant ~= "leave" and ((not force and kumanCount <= 1) or math.random() < 0.55))
			local function alive(): boolean
				return m.Parent ~= nil and current ~= nil and current.token == my
			end
			local dirSign = if math.random() < 0.5 then 1 else -1
			local function tick(speed: number): boolean
				local dt = RunService.Heartbeat:Wait()
				if not alive() then
					return false
				end
				sv = (sv + dirSign * speed * dt) % total
				local p, dir = at(sv)
				m:PivotTo(CFrame.lookAt(p, p + dir * dirSign))
				return true
			end
			local function runFor(sec: number, speed: number): boolean
				GhostNPC.Play(m, "kuman_run", speed / 13)
				local t0 = os.clock()
				while os.clock() - t0 < sec do
					if not tick(speed) then
						return false
					end
				end
				return true
			end
			-- วิ่งไปจุดนี้ทางที่สั้นกว่า
			local function runTo(target: number, speed: number): boolean
				local ahead = (target - sv) % total
				dirSign = if ahead <= total / 2 then 1 else -1
				GhostNPC.Play(m, "kuman_run", speed / 13)
				local t0 = os.clock()
				while os.clock() - t0 < 5 do
					local left = if dirSign > 0 then (target - sv) % total else (sv - target) % total
					if left < speed / 40 or left > total - 1 then
						break
					end
					if not tick(speed) then
						return false
					end
				end
				return alive()
			end
			local function pause(sec: number): boolean
				local t0 = os.clock()
				while os.clock() - t0 < sec do
					task.wait()
					if not alive() then
						return false
					end
				end
				return true
			end
			-- หยุดหันหน้าเข้าหาคน (หรือกลางร้าน)
			local function faceIn(v: Vector3?)
				local p = at(sv)
				local to = v or Vector3.new(scf.X, p.Y, scf.Z)
				local flat = Vector3.new(to.X - p.X, 0, to.Z - p.Z)
				m:PivotTo(CFrame.lookAt(p, p + (if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis)))
				GhostNPC.Play(m, "kuman_giggle", 0.8)
			end
			-- จุดบนผนังตรงหน้าผี
			local function wallPoint(): Vector3
				local p = at(sv)
				return Vector3.new(math.clamp(p.X, scf.X - 16.3, scf.X + 16.3), p.Y + 2, math.clamp(p.Z, d.Position.Z - 0.2, scf.Z + ssize.Z / 2 - 1))
			end
			local function giggle(len: number)
				local snd = SoundBank.PlayOneShot("Ghost_Kuman_Laugh", rootPart, 75, len)
				if snd then
					snd.RollOffMinDistance = 12
				end
			end
			task.spawn(function()
				fxRemote:FireAllClients("hush", true)
				if not pause(0.9) then
					return
				end
				local firstSide: number? = nil
				for round = 1, 2 do
					if math.random() < 0.5 then
						dirSign = -dirSign
					end
					if not runFor(0.8 + math.random() * 0.7, 11 + math.random() * 4) then
						return
					end
					if math.random() < 0.4 then -- กลับทิศกะทันหัน
						dirSign = -dirSign
						if not runFor(0.45 + math.random() * 0.4, 13 + math.random() * 4) then
							return
						end
					end
					local v = victimPos()
					-- รอบแรก = ผนังที่ใกล้คนสุด · รอบสอง = ผนังด้านอื่น (เดาไม่ได้ว่าจะมาด้านไหน)
					local target, side = nearest(v or Vector3.new(scf.X + (math.random() - 0.5) * 20, 0, scf.Z), firstSide)
					firstSide = firstSide or side
					if not runTo(target, 18) then
						return
					end
					faceIn(v)
					if not pause(0.7 + math.random() * 0.5) then
						return
					end
					fxRemote:FireAllClients("knockLow", wallPoint())
					if not pause(1.2) then
						return
					end
					giggle(1.8)
					if not pause(0.9) then
						return
					end
					if round == 1 and math.random() < 0.7 then -- มาโผล่อีกฝั่งทันที (ไม่มีเสียงวิ่ง)
						sv = (sv + total / 2 + (math.random() - 0.5) * 10) % total
						faceIn(v)
						if not pause(0.35) then
							return
						end
						giggle(1.4)
						if not pause(0.6) then
							return
						end
					end
				end
				local v = victimPos()
				if finale and v then
					-- วิ่งพุ่งเข้าหาผนัง เงียบ ... แล้วเสียงเท้าอยู่ในร้าน
					local target = nearest(v)
					if not runTo(target, 21) then
						return
					end
					m:SetAttribute("Silent", true)
					fade(group, 1, 0.15)
					if not pause(1.1) then
						return
					end
					fxRemote:FireAllClients("inside")
					if not pause(1.3) then
						return
					end
					fxRemote:FireAllClients("tray")
					if not pause(3.0) then
						return
					end
				else
					if not runFor(1.8, 16) then
						return
					end
					m:SetAttribute("Silent", true)
					fade(group, 1, 0.6)
					if not pause(1.2) then
						return
					end
				end
				if alive() then
					GhostLinger.Stop()
				end
			end)
		end
	else
		-- หลังคา: กระหังโฉบลงหลังคา ชะโงกจากชายคาหน้าร้าน แล้วย่องไปมาบนหลังคา
		-- (ผู้ใช้ 2026-11-06) ห้ามเท้าทะลุหลังคาลงมาในร้าน + คนในร้านต้องได้ยินว่าผีอยู่บนหลังคาตรงไหน (เสียง 3D ที่ตัวผี)
		-- (2026-11-26) ตามคนในร้าน: มาหยุดเหนือหัว เงียบ ฝุ่นร่วงใส่ แล้วกระทืบ · บางครั้งหลอกว่าบินไปแล้วโฉบลงมาอีกที
		--   ฝุ่น ไฟ หลอดแกว่ง จอสั่น เสียงกระแทก = client/LingerFX
		local halfX = math.max(2, (ssize.X - 8) / 2)
		local zMin, zMax = d.Position.Z + 1.6, scf.Z + ssize.Z / 2 - 3
		local function spot(px: number, pz: number): Vector3
			local cx, cz = math.clamp(px, scf.X - halfX, scf.X + halfX), math.clamp(pz, zMin, zMax)
			return Vector3.new(cx, roofTop(cx, cz), cz)
		end
		local function randomSpot(): Vector3
			return spot(scf.X + (math.random() - 0.5) * 2 * halfX, zMin + math.random() * (zMax - zMin))
		end
		local feet = spot(scf.X + (math.random() - 0.5) * 2 * halfX, d.Position.Z + 4.5)
		stay = 40 -- กันค้างเฉยๆ: จบเองตามบทด้านล่าง
		local m = spawnIn(group, "Krahang", CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 0)), "LandOnRoof")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		if m and root then
			local rootPart = root :: BasePart
			-- เอาสากที่ขี่ออกเฉพาะฉากนี้: มองจากใต้ตัวตรงๆ รูปทรงดูไม่เหมาะสม (กฎความปลอดภัยบัญชี) ห้ามใส่กลับ
			local sak = m:FindFirstChild("Sak")
			if sak then
				sak:Destroy()
			end
			game:GetService("CollectionService"):AddTag(m, "RoofGhost")
			-- เท้า/นิ้วเท้าตามท่าที่เล่นอยู่ต่ำกว่าหลังคาเมื่อไหร่ ยกตัวขึ้นทันที (ท่าชะโงกย่อตัวต่ำกว่าเท้าตอนยืน)
			local feetBones: { Bone } = {}
			for _, b in ipairs(m:GetDescendants()) do
				if b:IsA("Bone") and (string.find(b.Name, "toe") or string.find(b.Name, "foot")) then
					table.insert(feetBones, b)
				end
			end
			local lift = 0
			local base: CFrame? = nil -- ตำแหน่งบนหลังคาก่อนยก (nil = ยังร่อนลงอยู่)
			local function place(cf: CFrame)
				base = cf
				m:PivotTo(cf + Vector3.new(0, lift, 0))
			end
			conn = RunService.Heartbeat:Connect(function()
				if not (base and m.Parent) then
					return
				end
				local p = (base :: CFrame).Position
				local floor = roofTop(p.X, p.Z)
				local low = math.huge
				for _, b in ipairs(feetBones) do
					low = math.min(low, b.TransformedWorldCFrame.Position.Y)
				end
				if low < math.huge then
					local deficit = floor + ROOF_SKIN - low
					-- ยกขึ้นทันทีถ้าจม / ค่อยๆ ลดลงเมื่อท่ายกเท้าขึ้นแล้ว (ไม่ลอยค้าง)
					lift = if deficit > 0 then lift + deficit else math.max(0, lift + math.max(deficit, -0.05))
					m:PivotTo((base :: CFrame) + Vector3.new(0, lift, 0))
				end
			end)
			-- เสียงตอนบิน/ร่อน ติดตัวผี (คนในร้านได้ยินจากทิศที่ผีอยู่): กระพือปีกกระด้งทุ้มๆ เป็นจังหวะ + ลมแหวกอากาศ
			-- (ผู้ใช้ 2026-11-16: เดิมเล่นเสียงย่ำสังกะสีสังเคราะห์ haunt_roof_tin_steps วนตอนร่อน ฟังเป็นเสียงลมซ่าๆ ไม่เข้ากับท่าบิน)
			-- strength 1 = โฉบลงมาจากฟ้า (ดัง เร็ว) · 0.75 = ร่อนเลียดหลังคาไปจุดใหม่ · ตอนเกาะนิ่ง = เงียบ ได้ยินแต่เสียงกระแทก/หัวเราะ
			local wings = SoundBank.CreateSound("KrahangWings", rootPart, 85)
			local air = SoundBank.CreateSound("KrahangAir", rootPart, 70)
			local wingVol = if wings then wings.Volume else 1
			local wingSpeed = if wings then wings.PlaybackSpeed else 1
			local airVol = if air then air.Volume else 1
			local airSpeed = if air then air.PlaybackSpeed else 1
			for _, s in ipairs({ wings, air } :: { Sound? }) do
				if s then
					s.Looped = true
					s.Volume = 0
					s.RollOffMinDistance = 12
				end
			end
			local function flying(strength: number, fadeTime: number?)
				local info = TweenInfo.new(fadeTime or 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
				local on = strength > 0
				if wings then
					if on and not wings.IsPlaying then
						-- เริ่มจากจุดสุ่มในไฟล์: แต่ละรอบจังหวะปีกไม่ซ้ำกัน
						wings.TimePosition = if wings.TimeLength > 1 then math.random() * (wings.TimeLength - 1) else 0
						wings:Play()
					end
					-- บินแรง = กระพือถี่และแหลมขึ้นนิด · ร่อน = ช้าทุ้ม
					TweenService:Create(wings, info, { Volume = wingVol * strength, PlaybackSpeed = wingSpeed * (0.85 + 0.3 * strength) }):Play()
				end
				if air then
					if on and not air.IsPlaying then
						air.TimePosition = if air.TimeLength > 1 then math.random() * (air.TimeLength - 1) else 0
						air:Play()
					end
					TweenService:Create(air, info, { Volume = airVol * strength, PlaybackSpeed = airSpeed * (0.8 + 0.4 * strength) }):Play()
				end
				if not on then
					task.delay((fadeTime or 0.3) + 0.05, function()
						for _, s in ipairs({ wings, air } :: { Sound? }) do
							if s and s.Volume <= 0.01 then
								s:Stop()
							end
						end
					end)
				end
			end
			local function stepping(on: boolean)
				flying(if on then 0.75 else 0, if on then 0.3 else 0.35)
			end
			local function slam(p: number)
				-- กระแทกหลังคาสังกะสี: เสียง + ฝุ่น + ไฟ + จอสั่น พร้อมกันบนเครื่องผู้เล่น (client/LingerFX roofSlam)
				fxRemote:FireAllClients("slam", rootPart.Position, p)
			end
			local function alive(): boolean
				return m.Parent ~= nil and current ~= nil and current.token == my
			end
			local function pause(sec: number): boolean
				local t0 = os.clock()
				while os.clock() - t0 < sec do
					task.wait()
					if not alive() then
						return false
					end
				end
				return true
			end
			-- หมอบก้มมองลงไปทาง v
			local CROUCH = CFrame.new(0, 0.35, 0) * CFrame.Angles(-math.rad(12), 0, 0) -- ยกนิดหนึ่ง: เอียงตัวแล้วปลายเท้าไม่จมใต้ฝ้า
			local HANG = 2.6 -- studs: เท้าถอยจากหัวเรา ให้หน้ามันยื่นมาอยู่เหนือหัวพอดี (ไม่ยืนคร่อม)
			local function facing(p: Vector3, v: Vector3?): CFrame
				local flat = if v then Vector3.new(v.X - p.X, 0, v.Z - p.Z) else Vector3.new(0, 0, -1)
				return CFrame.lookAt(p, p + (if flat.Magnitude > 0.6 then flat.Unit else Vector3.new(0, 0, -1)))
			end
			-- จุดยืนที่หน้ายื่นไปอยู่เหนือ v (เลือกทิศที่จุดยืนยังอยู่บนหลังคา)
			local function perch(v: Vector3): Vector3
				local from = (if base then (base :: CFrame).Position else rootPart.Position)
				local dir = Vector3.new(from.X - v.X, 0, from.Z - v.Z)
				local first = if dir.Magnitude > 0.5 then dir.Unit else Vector3.new(0, 0, 1)
				local best, bestErr = spot(v.X + first.X * HANG, v.Z + first.Z * HANG), math.huge
				for k = 0, 7 do
					local d8 = CFrame.Angles(0, k * math.pi / 4, 0) * first
					local s8 = spot(v.X + d8.X * HANG, v.Z + d8.Z * HANG)
					local err = math.abs(Vector3.new(s8.X - v.X, 0, s8.Z - v.Z).Magnitude - HANG)
					if err < bestErr - 0.05 then
						best, bestErr = s8, err
					end
				end
				return best
			end
			-- ร่อนเลียดหลังคาไปจุดนี้
			local function goTo(to: Vector3, speed: number): boolean
				local from = (if base then (base :: CFrame).Position else rootPart.Position)
				local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
				local dist = flat.Magnitude
				if dist < 0.8 then
					return alive()
				end
				GhostNPC.Play(m, "Glide", 1.3)
				stepping(true)
				local t0 = os.clock()
				local dur = dist / speed
				while alive() do
					local k = math.clamp((os.clock() - t0) / dur, 0, 1)
					local p = from:Lerp(to, k)
					p = Vector3.new(p.X, roofTop(p.X, p.Z), p.Z)
					place(CFrame.lookAt(p, p + flat.Unit))
					if k >= 1 then
						break
					end
					RunService.Heartbeat:Wait()
				end
				stepping(false)
				return alive()
			end
			-- บินจาก a ไป b (ไม่เกาะหลังคา)
			local function fly(a: CFrame, b: CFrame, sec: number, style: Enum.EasingStyle, dirn: Enum.EasingDirection): boolean
				base = nil
				local t0 = os.clock()
				while alive() do
					local k = math.clamp((os.clock() - t0) / sec, 0, 1)
					m:PivotTo(a:Lerp(b, TweenService:GetValue(k, style, dirn)))
					if k >= 1 then
						break
					end
					RunService.Heartbeat:Wait()
				end
				return alive()
			end
			local function stomp(p: number): boolean
				local at0 = (if base then base :: CFrame else m:GetPivot())
				if not fly(at0, at0 + Vector3.new(0, 1.7, 0), 0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) then
					return false
				end
				if not fly(at0 + Vector3.new(0, 1.7, 0), at0, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In) then
					return false
				end
				place(at0)
				slam(p)
				return true
			end
			local fake = variant == "fake" or (variant == nil and math.random() < 0.5)
			group:SetAttribute("Variant", if fake then "fake" else "leave")
			flying(1, 0.5) -- โฉบลงมา: เสียงปีก + ลมดังขึ้นตามตัวที่ใกล้เข้ามา แล้วเงียบวูบก่อนกระแทก
			task.spawn(function()
				task.wait()
				fxRemote:FireAllClients("hush", true)
				local top = CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 7))
				task.delay(1.75, function()
					if alive() then
						flying(0, 0.25)
					end
				end)
				if not fly(top, CFrame.lookAt(feet, feet + Vector3.new(0, 0, -1)), 2.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In) then
					return
				end
				place(CFrame.lookAt(feet, feet + Vector3.new(0, 0, -1)))
				slam(0.8)
				GhostNPC.Play(m, "PeekOverEdge")
				if not pause(1.5) then
					return
				end
				for round = 1, (if fake then 1 else 2) do
					local v = victimPos()
					local target = if v then perch(v) else randomSpot()
					if not goTo(target, 6.5) then
						return
					end
					place(facing(spot(target.X, target.Z), v) * CROUCH)
					GhostNPC.Play(m, "PeekOverEdge")
					slam(0.3)
					-- เงียบอยู่เหนือหัว ฝุ่นร่วง · คนขยับหนี มันขยับตาม (ไม่เกิน 2 ครั้ง)
					m:SetAttribute("Trickle", true)
					local quiet, moves = 2.6 + math.random() * 0.8, 0
					local t0 = os.clock()
					while os.clock() - t0 < quiet do
						task.wait(0.1)
						if not alive() then
							return
						end
						local now = victimPos()
						if now and moves < 2 and base then
							local seen = v or now
							local want = perch(now)
							if Vector3.new(now.X - seen.X, 0, now.Z - seen.Z).Magnitude > 4 then
								v = now
								moves += 1
								if not goTo(want, 8) then
									return
								end
								place(facing(spot(want.X, want.Z), now) * CROUCH)
								GhostNPC.Play(m, "PeekOverEdge")
								slam(0.3)
								t0 = os.clock() - quiet + 1.8 -- ตามทันแล้วเงียบอีก 1.8 วิ
							end
						end
					end
					m:SetAttribute("Trickle", nil)
					if not stomp(if round == 1 then 0.85 else 0.97) then
						return
					end
					if not pause(0.8) then
						return
					end
					if math.random() < 0.5 then
						SoundBank.PlayOneShot(if math.random() < 0.5 then "Ghost_Krahang_Laugh" else "Ghost_Krahang", rootPart, 80, 3)
					end
					if not pause(1.0) then
						return
					end
				end
				-- บินออกไป (เสียงปีกไกลออกไปจนเงียบ)
				GhostNPC.Play(m, "FlapFly")
				flying(1, 0.4)
				local here = m:GetPivot()
				local away = here.Position + Vector3.new(if math.random() < 0.5 then 26 else -26, 24, 30)
				task.delay(1.4, function()
					if alive() then
						flying(0, 1.3)
					end
				end)
				if not fly(here, CFrame.lookAt(away, away + (away - here.Position)), 2.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In) then
					return
				end
				fxRemote:FireAllClients("hush", false) -- จิ้งหรีดเริ่มร้องกลับมา = เหมือนไปแล้ว
				if fake then
					if not pause(4.2 + math.random() * 1.6) then
						return
					end
					local v = victimPos()
					local land = if v then perch(v) else randomSpot()
					local up = CFrame.lookAt(land + Vector3.new(0, 20, 0), land + Vector3.new(0, 20, -1))
					m:PivotTo(up)
					flying(1, 0.12)
					if not fly(up, facing(land, v) * CROUCH, 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In) then
						return
					end
					flying(0, 0.1)
					place(facing(land, v) * CROUCH)
					GhostNPC.Play(m, "PeekOverEdge")
					slam(1)
					if not pause(2.0) then
						return
					end
				end
				if alive() then
					GhostLinger.Stop()
				end
			end)
		end
	end

	if not root then
		if conn then
			conn:Disconnect()
		end
		group:Destroy()
		return false
	end
	fade(group, 1, 0)
	fade(group, 0, 1.2)
	current = { group = group, conn = conn, token = my }
	-- (ไม่หัวเราะเปิดตัวแล้วทุกแบบ 2026-11-26: เริ่มจากความเงียบ ให้รู้ตัวทีหลัง)
	task.delay(stay, function()
		if current and current.token == my then
			GhostLinger.Stop()
		end
	end)
	print("👻 ผียังวนอยู่หลังปิดแผง: " .. behavior .. (if variant then ":" .. variant else "") .. string.format(" (%.0f วิ)", stay))
	return true
end

return GhostLinger
