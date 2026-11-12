--!strict
-- GhostLinger.luau (ModuleScript ฝั่ง Server)
-- ปิดแผงใส่ผีแล้ว ผีไม่ได้ไปไหนทันทีเสมอ: บางตัวหายวับ บางตัวมาเคาะแผงสังกะสี วิ่งป่วนรอบร้าน หรือวิ่งเล่นบนหลังคา
--   ระหว่างผียังวนอยู่ (Active) ถ้ามีคนเปิดแผง = โดนหลอกทั้งร้าน (CoreLoop.toggleShutter เรียก Scare)
--   ต้องรอจนผีหายไปเองถึงจะเปิดร้านได้ปลอดภัย · ลูกค้าคนถัดไปรอจนผีไปแล้ว
--   คนที่โดนหลอกนอกร้านนอนล้มตาปรือจนผีตัวนี้ไป (CoreLoop.Rampage)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))

local GhostLinger = {}

GhostLinger.Config = {
	Stay = { 14, 22 }, -- วินาทีที่ผีวนอยู่หลังโดนปิดแผงใส่
	-- น้ำหนักสุ่มพฤติกรรม (vanish = หายไปทันทีแบบเดิม)
	Weights = { vanish = 3.5, knock = 2.5, circle = 2, roof = 2 },
	RunSpeed = 13, -- วิ่งรอบร้าน (studs/วินาที)
}

local interactive = Workspace:WaitForChild("InteractiveProps")
local shack = Workspace:WaitForChild("MapEnvironment"):WaitForChild("ShackStructure") :: Model

local current: { group: Model, conn: RBXScriptConnection?, token: number }? = nil
local token = 0

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
		if not ((k == "vanish" and mustStay) or (k == "knock" and not closed)) then
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

function GhostLinger.Start(mustStay: boolean?, picked: string?): boolean
	if current then
		GhostLinger.Stop()
	end
	local behavior = picked or pickBehavior(mustStay)
	if behavior == "vanish" then
		return false
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
	local conn: RBXScriptConnection? = nil
	local root: BasePart? = nil

	if behavior == "knock" then
		-- ปอบเคาะแผงจากด้านนอก แผงสั่นเป็นจังหวะ
		-- ระยะเท้า-แผง: ท่า mocap Pop_KnockShutter บนร่าง v2 ปลายนิ้วยื่นไปหน้าสุด 2.48 studs (วัดใน Studio 2026-11-13)
		-- เดิม 1.94 (ท่าเก่า) มือทะลุแผง (ผู้ใช้ 2026-11-13) -> 2.52 ปลายนิ้วแตะผิวแผงพอดี
		local x = d.Position.X + (math.random() - 0.5) * 10
		local z = d.Position.Z - d.Size.Z / 2 - 2.52
		local feet = Vector3.new(x, groundAt(x, z), z)
		local m = spawnIn(group, "Pop", CFrame.lookAt(feet, feet + Vector3.new(0, 0, 1)), "KnockShutter")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		local rest = d.CFrame
		local t0 = os.clock()
		conn = RunService.Heartbeat:Connect(function()
			-- แผงยังปิดอยู่ (ไม่ได้ถูกยกขึ้น): สั่นตามจังหวะเคาะ
			if not current or current.token ~= my then
				return
			end
			if math.abs(d.Position.Y - rest.Position.Y) < 0.3 then
				local t = os.clock() - t0
				local hit = math.max(0, math.sin(t * 9)) ^ 6
				d.CFrame = rest * CFrame.new(0, 0, hit * 0.12)
			end
		end)
		task.delay(0.1, function()
			while current and current.token == my do
				if root then
					-- เล่นจนจบไฟล์ (เดิมตัดที่ 0.6 วิ เสียงขาด ผู้ใช้ 2026-11-08) ดังจากในร้านชัด (เริ่มเบาลงหลัง 14 studs)
					local s = SoundBank.PlayOneShot("ShutterKnock", d, 110, 3)
					if s then
						s.RollOffMinDistance = 14
					end
				end
				task.wait(0.9 + math.random() * 0.8)
			end
			if math.abs(d.Position.Y - rest.Position.Y) < 0.3 then
				d.CFrame = rest
			end
		end)
	elseif behavior == "circle" then
		-- กุมารทองวิ่งวนรอบเพิง (สี่เหลี่ยมห่างผนัง 4 studs)
		local hx, hz = ssize.X / 2 + 4, ssize.Z / 2 + 4
		local corners = {
			scf:PointToWorldSpace(Vector3.new(-hx, 0, -hz)),
			scf:PointToWorldSpace(Vector3.new(hx, 0, -hz)),
			scf:PointToWorldSpace(Vector3.new(hx, 0, hz)),
			scf:PointToWorldSpace(Vector3.new(-hx, 0, hz)),
		}
		local lens, total = {}, 0
		for i = 1, 4 do
			local a, b = corners[i], corners[i % 4 + 1]
			lens[i] = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
			total += lens[i]
		end
		local m = spawnIn(group, "ghost_kuman_thong", CFrame.new(corners[1]), "run")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		local t0 = os.clock()
		conn = RunService.Heartbeat:Connect(function()
			if not (m and m.Parent) then
				return
			end
			local s = ((os.clock() - t0) * cfg.RunSpeed) % total
			for i = 1, 4 do
				if s <= lens[i] then
					local a, b = corners[i], corners[i % 4 + 1]
					local p = a:Lerp(b, s / lens[i])
					local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
					local feet = Vector3.new(p.X, groundAt(p.X, p.Z), p.Z)
					m:PivotTo(CFrame.lookAt(feet, feet + dir))
					return
				end
				s -= lens[i]
			end
		end)
	else
		-- หลังคา: กระหังโฉบลงหลังคา ชะโงกจากชายคาหน้าร้าน แล้วย่องไปมาบนหลังคา
		-- (ผู้ใช้ 2026-11-06) ห้ามเท้าทะลุหลังคาลงมาในร้าน + คนในร้านต้องได้ยินว่าผีอยู่บนหลังคาตรงไหน (เสียง 3D ที่ตัวผี)
		local z = d.Position.Z + 4.5
		local halfX = math.max(2, (ssize.X - 8) / 2)
		local function spot(x: number): Vector3
			return Vector3.new(scf.X + x, roofTop(scf.X + x, z), z)
		end
		local x = (math.random() - 0.5) * 2 * halfX
		local feet = spot(x)
		local m = spawnIn(group, "Krahang", CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 0)), "LandOnRoof")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		if m and root then
			local rootPart = root :: BasePart
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
			-- เสียงบนหลังคา: ฝีเท้าย่ำสังกะสีติดตัวผี (คนในร้านได้ยินจากทิศที่ผีอยู่)
			local steps = SoundBank.CreateSound("RoofTinSteps", rootPart, 70)
			if steps then
				steps.Looped = true
				steps.Volume = 0
				steps.RollOffMinDistance = 10
			end
			local function stepping(on: boolean)
				if steps then
					if on and not steps.IsPlaying then
						steps:Play()
					end
					-- ฝีเท้าย่ำสังกะสี: ดังขึ้น (เดิม 0.9 ผู้ใช้ 2026-11-08)
					TweenService:Create(steps, TweenInfo.new(0.25), { Volume = if on then 1.6 else 0 }):Play()
				end
			end
			local function thud()
				-- กระหังตกกระแทกหลังคาสังกะสี: ดังชัด (เดิม ShutterCloseSlam × 0.55 ตัด 1.2 วิ เบาไป ผู้ใช้ 2026-11-08)
				local s = SoundBank.PlayOneShot("ShutterKnock", rootPart, 100, 3)
				if s then
					s.RollOffMinDistance = 14
					s.PlaybackSpeed = 0.7 + math.random() * 0.15 -- ทุ้มกว่าแผง = ตกลงบนหลังคา
				end
			end
			-- ร่อนลงมาจากข้างบน แล้วชะโงกมองหน้าร้าน
			local cv = Instance.new("CFrameValue")
			cv.Value = CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 7))
			local tw = TweenService:Create(cv, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = CFrame.lookAt(feet, feet + Vector3.new(0, 0, -1)) })
			cv.Changed:Connect(function(v)
				if m.Parent and not base then
					m:PivotTo(v)
				end
			end)
			tw:Play()
			task.spawn(function()
				task.wait(2.2)
				cv:Destroy()
				if not (m.Parent and current and current.token == my) then
					return
				end
				place(CFrame.lookAt(feet, feet + Vector3.new(0, 0, -1)))
				thud()
				GhostNPC.Play(m, "PeekOverEdge")
				-- ย่องไปมาบนหลังคา: ไปจุดใหม่ (เสียงฝีเท้าย้ายตาม) หยุดชะโงก หัวเราะเป็นพักๆ
				while m.Parent and current and current.token == my do
					task.wait(2.5 + math.random() * 2.5)
					if not (m.Parent and current and current.token == my) then
						break
					end
					local nx = math.clamp(x + (if math.random() < 0.5 then -1 else 1) * (4 + math.random() * 5), -halfX, halfX)
					if math.abs(nx - x) < 2 then
						nx = if x > 0 then -halfX * 0.6 else halfX * 0.6
					end
					local from, to = spot(x), spot(nx)
					local dir = Vector3.new(to.X - from.X, 0, 0).Unit
					GhostNPC.Play(m, "Glide", 1.3)
					stepping(true)
					local dist = math.abs(nx - x)
					local dur = dist / 5.5
					local t0 = os.clock()
					while m.Parent and current and current.token == my do
						local k = math.clamp((os.clock() - t0) / dur, 0, 1)
						local p = from:Lerp(to, k)
						p = Vector3.new(p.X, roofTop(p.X, p.Z), p.Z)
						place(CFrame.lookAt(p, p + dir))
						if k >= 1 then
							break
						end
						RunService.Heartbeat:Wait()
					end
					stepping(false)
					x = nx
					if not (m.Parent and current and current.token == my) then
						break
					end
					thud()
					local stop = spot(x)
					place(CFrame.lookAt(stop, stop + Vector3.new(0, 0, -1)))
					GhostNPC.Play(m, "PeekOverEdge")
					if math.random() < 0.5 then
						SoundBank.PlayOneShot(if math.random() < 0.5 then "Ghost_Krahang_Laugh" else "Ghost_Krahang", rootPart, 80, 4)
					end
				end
				stepping(false)
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
	SoundBank.PlayOneShot(if behavior == "roof" then "Ghost_Krahang_Laugh" elseif behavior == "circle" then "Ghost_Kuman_Laugh" else "Ghost_Pop_Laugh", root, 90, 5)
	local stay = cfg.Stay[1] + math.random() * (cfg.Stay[2] - cfg.Stay[1])
	task.delay(stay, function()
		if current and current.token == my then
			GhostLinger.Stop()
		end
	end)
	print("👻 ผียังวนอยู่หลังปิดแผง: " .. behavior .. string.format(" (%.0f วิ)", stay))
	return true
end

return GhostLinger
