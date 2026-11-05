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
function GhostLinger.Start(mustStay: boolean?): boolean
	if current then
		GhostLinger.Stop()
	end
	local behavior = pickBehavior(mustStay)
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
		-- ปอบเคาะแผงจากด้านนอก (หมัดถึงแผงที่ 1.94 studs) แผงสั่นเป็นจังหวะ
		local x = d.Position.X + (math.random() - 0.5) * 10
		local z = d.Position.Z - d.Size.Z / 2 - 1.94
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
					SoundBank.PlayOneShot("ShutterCloseSlam", d, 60, 0.4)
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
		-- หลังคา: กระหังโฉบลงหลังคา ยืนชะโงกจากชายคาหน้าร้าน
		local x = (math.random() - 0.5) * (ssize.X - 8)
		local z = d.Position.Z + 4.5
		local top = roofAt(scf.X + x, z)
		local feet = Vector3.new(scf.X + x, top, z)
		local m = spawnIn(group, "Krahang", CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 0)), "LandOnRoof")
		root = m and m:FindFirstChild("RootPart") :: BasePart?
		if m then
			-- ร่อนลงมาจากข้างบน แล้วชะโงกมองหน้าร้าน
			local face = feet + Vector3.new(0, 0, -1)
			local cv = Instance.new("CFrameValue")
			cv.Value = CFrame.lookAt(feet + Vector3.new(0, 18, 8), feet + Vector3.new(0, 18, 7))
			local tw = TweenService:Create(cv, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = CFrame.lookAt(feet, face) })
			cv.Changed:Connect(function(v)
				if m.Parent then
					m:PivotTo(v)
				end
			end)
			tw:Play()
			task.delay(2.4, function()
				cv:Destroy()
				if m.Parent and current and current.token == my then
					GhostNPC.Play(m, "PeekOverEdge")
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
