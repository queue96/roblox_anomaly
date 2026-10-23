-- ThaiVehicleDrive.server.luau
-- ขับรถไทยที่วางด้วย MapBuilder.SpawnThaiVehicle() (tag "PlayerVehicle")
--   กด F ที่รถเพื่อขึ้นนั่ง (หรือเดินชนเบาะ), นั่ง VehicleSeat แล้วกด W/S เร่ง-ถอย, A/D เลี้ยว, L เปิด/ปิดไฟหน้า, Space ลงจากรถ
-- ขับแบบ arcade: LinearVelocity (แนวราบ) + AlignOrientation (หันตามพวงมาลัย เอียงตามพื้นใต้ล้อไม่เกิน 22° ไม่พลิกคว่ำ)
-- รถลอยบนลูกบอลลื่นที่ล้อ (Colliders.Skid*) ล้อเป็น Motor6D หมุนตามความเร็ว ล้อหน้าเลี้ยวตามพวงมาลัย
-- รถลูกค้าของ CoreLoop (Clone แล้ว anchored ไม่มี tag) ไม่ถูกสคริปต์นี้แตะ

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ACCEL = 18 -- studs/s²
local BRAKE = 34
local STEER_DEG = 28 -- มุมเลี้ยวของล้อหน้า (ภาพ)
local MAX_TILT = math.rad(22) -- เอียงตามพื้นได้ไม่เกินนี้ (กันพลิกคว่ำ)

-- ยิงลงพื้นใต้ลูกบอลล้อ: ไม่นับตัวรถเองและตัวละคร
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

type Car = {
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	lin: LinearVelocity,
	ang: AlignOrientation,
	yaw: number,
	skids: { { part: BasePart, front: boolean, side: number } },
	up: Vector3,
	axles: { Motor6D },
	speed: number,
	spin: number,
	leds: { BasePart },
	ledColors: { Color3 },
	ledT: number,
}
local cars: { [Model]: Car } = {}

local function setLights(m: Model, on: boolean)
	m:SetAttribute("LightsOn", on)
	local lights = m:FindFirstChild("Lights")
	if not lights then
		return
	end
	for _, d in ipairs(lights:GetDescendants()) do
		if d:IsA("Light") then
			d.Enabled = on
		elseif d:IsA("BasePart") then
			d.Material = if on then Enum.Material.Neon else Enum.Material.Glass
			d.Transparency = if on then 0 else 0.4
		end
	end
end

local function setup(m: Model)
	if cars[m] or not m:IsA("Model") then
		return
	end
	local chassis = m.PrimaryPart
	local seat = m:FindFirstChildWhichIsA("VehicleSeat", true)
	if not (chassis and seat) then
		return
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	local att = Instance.new("Attachment")
	att.Name = "DriveAttachment"
	att.Parent = chassis
	local mass = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and not d.Massless then
			mass += d:GetMass()
		end
	end
	local lin = Instance.new("LinearVelocity")
	lin.Name = "DriveVelocity"
	lin.Attachment0 = att
	lin.RelativeTo = Enum.ActuatorRelativeTo.World
	lin.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lin.PrimaryTangentAxis = Vector3.xAxis
	lin.SecondaryTangentAxis = Vector3.zAxis
	lin.PlaneVelocity = Vector2.zero
	lin.MaxForce = mass * Workspace.Gravity * 3 + 2000
	lin.Parent = chassis
	-- ล็อกให้ตั้งตรงเสมอ (ไม่ล้ม ไม่เอียงตามแรงชน) และหมุนรอบแกน Y ตามพวงมาลัย
	local _, yaw0, _ = chassis.CFrame:ToEulerAnglesYXZ()
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, yaw0, 0))
	local ang = Instance.new("AlignOrientation")
	ang.Name = "DriveTurn"
	ang.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ang.Attachment0 = att
	ang.CFrame = CFrame.Angles(0, yaw0, 0)
	ang.MaxTorque = math.huge
	ang.Responsiveness = 60
	ang.Parent = chassis
	local axles = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == "Axle" then
			table.insert(axles, d)
		end
	end
	local leds, ledColors = {}, {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d:HasTag("VehicleLED") then
			table.insert(leds, d)
		end
	end
	for c in string.gmatch(m:GetAttribute("LedColors") or "", "[^;]+") do
		local r, g, b = string.match(c, "(%d+),(%d+),(%d+)")
		table.insert(ledColors, Color3.fromRGB(tonumber(r) :: number, tonumber(g) :: number, tonumber(b) :: number))
	end
	-- ปุ่มไฟหน้า (คนขับกด L)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HeadlightPrompt"
	prompt.ActionText = "Lights"
	prompt.ObjectText = m.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.L
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = seat
	local lastToggle = 0
	prompt.Triggered:Connect(function(player)
		local hum = seat.Occupant
		if hum and hum.Parent == player.Character and os.clock() - lastToggle > 0.35 then -- กันกดเบิ้ล (กดลง/ปล่อย)
			lastToggle = os.clock()
			setLights(m, not m:GetAttribute("LightsOn"))
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant ~= nil
	end)
	-- ปุ่มขึ้นรถทุกที่นั่ง (กด F) เผื่อพื้นรถสูงจนเดินชนเบาะไม่ถึง ซ่อนเมื่อมีคนนั่ง
	for _, s in ipairs(m:GetDescendants()) do
		if s:IsA("Seat") or s:IsA("VehicleSeat") then
			local sitPrompt = Instance.new("ProximityPrompt")
			sitPrompt.Name = "SitPrompt"
			sitPrompt.ActionText = if s:IsA("VehicleSeat") then "Drive" else "Sit"
			sitPrompt.ObjectText = m.Name
			sitPrompt.KeyboardKeyCode = Enum.KeyCode.F
			sitPrompt.HoldDuration = 0
			sitPrompt.MaxActivationDistance = 9
			sitPrompt.RequiresLineOfSight = false
			sitPrompt.Parent = s
			sitPrompt.Triggered:Connect(function(player)
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and not s.Occupant and not hum.SeatPart then
					(s :: any):Sit(hum)
				end
			end)
			s:GetPropertyChangedSignal("Occupant"):Connect(function()
				sitPrompt.Enabled = s.Occupant == nil
			end)
		end
	end
	local skids = {}
	local cols = m:FindFirstChild("Colliders")
	for _, sk in ipairs(if cols then cols:GetChildren() else {}) do
		if sk:IsA("BasePart") and sk.Name:match("^Skid") then
			local rel = chassis.CFrame:PointToObjectSpace(sk.Position)
			table.insert(skids, { part = sk, front = rel.Z < 0, side = if math.abs(rel.X) < 0.3 then 0 else math.sign(rel.X) })
		end
	end
	pcall(function()
		chassis:SetNetworkOwner(nil) -- ให้ Server คุมฟิสิกส์ ผู้โดยสารทุกคนเห็นตรงกัน
	end)
	setLights(m, m:GetAttribute("LightsOn") ~= false)
	cars[m] = {
		model = m,
		chassis = chassis,
		seat = seat,
		lin = lin,
		ang = ang,
		yaw = yaw0,
		skids = skids,
		up = Vector3.yAxis,
		axles = axles,
		speed = 0,
		spin = 0,
		leds = leds,
		ledColors = ledColors,
		ledT = 0,
	}
	m.Destroying:Connect(function()
		cars[m] = nil
	end)
end

CollectionService:GetInstanceAddedSignal("PlayerVehicle"):Connect(setup)
CollectionService:GetInstanceRemovedSignal("PlayerVehicle"):Connect(function(m)
	cars[m :: Model] = nil
end)
for _, m in ipairs(CollectionService:GetTagged("PlayerVehicle")) do
	task.spawn(setup, m)
end

RunService.Heartbeat:Connect(function(dt)
	for m, c in pairs(cars) do
		if not m.Parent then
			cars[m] = nil
			continue
		end
		local maxSpeed = m:GetAttribute("MaxSpeed") or 30
		local turnRate = m:GetAttribute("TurnRate") or 1.5
		local throttle = if c.seat.Occupant then c.seat.ThrottleFloat else 0
		local steer = if c.seat.Occupant then c.seat.SteerFloat else 0
		local target = throttle * maxSpeed * (if throttle < 0 then 0.4 else 1)
		local rate = if (target == 0 or math.sign(target) ~= math.sign(c.speed)) then BRAKE else ACCEL
		if c.speed < target then
			c.speed = math.min(target, c.speed + rate * dt)
		else
			c.speed = math.max(target, c.speed - rate * dt)
		end
		-- เลี้ยวได้เมื่อรถเคลื่อนที่ (ถอยหลังเลี้ยวกลับด้าน)
		c.yaw -= steer * turnRate * math.clamp(c.speed / 8, -1, 1) * dt
		-- เอียงตามพื้น: ระนาบจากจุดใต้ล้อหน้า/หลัง/ซ้าย/ขวา (ไม่เอียงเกิน MAX_TILT) ล้อจึงแตะพื้นครบ ไม่มีช่องใต้ท้องรถให้มุด
		local exclude = { m }
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl.Character then
				table.insert(exclude, pl.Character)
			end
		end
		groundParams.FilterDescendantsInstances = exclude
		local sums = { f = Vector3.zero, b = Vector3.zero, l = Vector3.zero, r = Vector3.zero }
		local cnt = { f = 0, b = 0, l = 0, r = 0 }
		for _, sk in ipairs(c.skids) do
			local hit = Workspace:Raycast(sk.part.Position + Vector3.new(0, 2, 0), Vector3.new(0, -sk.part.Size.Y / 2 - 6, 0), groundParams)
			if hit then
				local k = if sk.front then "f" else "b"
				sums[k] += hit.Position
				cnt[k] += 1
				if sk.side ~= 0 then
					local s2 = if sk.side < 0 then "l" else "r"
					sums[s2] += hit.Position
					cnt[s2] += 1
				end
			end
		end
		local up = Vector3.yAxis
		if cnt.f > 0 and cnt.b > 0 then
			local fwd = sums.f / cnt.f - sums.b / cnt.b
			local right = if cnt.l > 0 and cnt.r > 0 then (sums.r / cnt.r - sums.l / cnt.l) else fwd:Cross(Vector3.yAxis)
			local n = right:Cross(fwd)
			if n.Magnitude > 1e-3 then
				n = n.Unit
				if n.Y < 0 then
					n = -n
				end
				local ang = math.acos(math.clamp(n.Y, -1, 1))
				if ang > MAX_TILT then
					local h = Vector3.new(n.X, 0, n.Z).Unit
					n = (Vector3.yAxis * math.cos(MAX_TILT) + h * math.sin(MAX_TILT)).Unit
				end
				up = n
			end
		end
		c.up = c.up:Lerp(up, math.min(1, dt * 8)).Unit
		local flatLook = CFrame.Angles(0, c.yaw, 0).LookVector
		local look = (flatLook - c.up * flatLook:Dot(c.up)).Unit
		c.ang.CFrame = CFrame.lookAt(Vector3.zero, look, c.up)
		local v = flatLook * c.speed
		c.lin.PlaneVelocity = Vector2.new(v.X, v.Z)
		-- ล้อหมุน + ล้อหน้าเลี้ยว
		if #c.axles > 0 and (math.abs(c.speed) > 0.05 or steer ~= 0) then
			for _, a in ipairs(c.axles) do
				local r = a:GetAttribute("Radius") or 1
				local spin = (a:GetAttribute("Spin") or 0) - c.speed * dt / r
				a:SetAttribute("Spin", spin % (math.pi * 2))
				local base = a:GetAttribute("BaseC0") or a.C0
				local st = if a:GetAttribute("Steer") then CFrame.Angles(0, -steer * math.rad(STEER_DEG), 0) else CFrame.identity
				a.C0 = base * st * CFrame.Angles(spin, 0, 0)
			end
		end
		-- ไฟ LED ตู้ลำโพงไล่สีตอนมีคนขับ
		if #c.leds > 0 and #c.ledColors > 0 and c.seat.Occupant then
			c.ledT += dt
			if c.ledT > 0.25 then
				c.ledT = 0
				local shift = math.floor(os.clock() * 4)
				for i, p in ipairs(c.leds) do
					local col = c.ledColors[((p:GetAttribute("LedIndex") or i) + shift) % #c.ledColors + 1]
					local light = p:FindFirstChildWhichIsA("Light")
					if light then
						light.Color = col
					else
						p.Color = col
					end
				end
			end
		end
	end
end)
