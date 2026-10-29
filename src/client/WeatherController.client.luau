-- WeatherController.client.luau
-- ฝนตกฝั่ง Client ตาม ReplicatedStorage.Remotes:GetAttribute("Weather") ("Rain" | "Clear")
--   เม็ดฝน (ParticleEmitter ลอยตามกล้อง), เสียงฝน (SoundGroup SFX), พื้นดินสีเข้มขึ้นเหมือนเปียก, แอ่งน้ำบนถนนหน้าร้าน
--   ฝนหยุดแล้วพื้นค่อยๆ แห้ง แอ่งน้ำค่อยๆ หาย

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local terrain = Workspace.Terrain

local RAIN_TEXTURE = "rbxassetid://99672676947809" -- เส้นเม็ดฝนบางๆ สีขาว (ทำเอง 64x256)
local RAIN_SOUND = "rbxassetid://13039198193" -- heavy rain loop
local RAIN_RATE = 1300 -- ต่อตัวปล่อย (มี 2 ตัว)

-- ---------------------------------------------------------------- เม็ดฝน (แบ่งโซนปล่อยฝนรอบนอกกระท่อม ไม่ให้เม็ดฝนทะลุหลังคาลงมาในเพิงร้าน)
local emitterFolder = Instance.new("Folder")
emitterFolder.Name = "RainEmitters"
emitterFolder.Parent = Workspace

local baseRain = Instance.new("ParticleEmitter")
baseRain.Name = "Rain"
baseRain.Texture = RAIN_TEXTURE
baseRain.Shape = Enum.ParticleEmitterShape.Box
baseRain.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
baseRain.Rate = 0
baseRain.Lifetime = NumberRange.new(0.55, 0.7)
baseRain.Speed = NumberRange.new(85, 95)
baseRain.EmissionDirection = Enum.NormalId.Bottom
baseRain.SpreadAngle = Vector2.new(0, 0) -- ตกตรงลงพื้น 100% ไม่ปลิวเฉียงลอดชายคาเข้าเพิง
baseRain.Acceleration = Vector3.zero
baseRain.Size = NumberSequence.new(2.4)
baseRain.Orientation = Enum.ParticleOrientation.FacingCamera -- (VelocityParallel ทำให้เส้นนอนขวาง)
baseRain.Transparency = NumberSequence.new(0.25)
baseRain.Color = ColorSequence.new(Color3.fromRGB(200, 208, 220))
baseRain.LightEmission = 0.1
baseRain.LightInfluence = 0.7

-- คำนวณขอบเขตหลังคาเพิงร้าน (ShackStructure) ในแกนโลกจริง (World Space) และแคชค่าไว้ไม่ให้คำนวณซ้ำทุกเฟรม
local cachedBounds: { number }? = nil
local function getShackBounds(): (number, number, number, number)
	if cachedBounds then
		return cachedBounds[1], cachedBounds[2], cachedBounds[3], cachedBounds[4]
	end
	local minX, maxX = -18.5, 18.5
	local minZ, maxZ = 5.0, 30.0
	local env = Workspace:FindFirstChild("MapEnvironment")
	local shack = env and env:FindFirstChild("ShackStructure")
	local foundPart = false
	if shack then
		for _, d in ipairs(shack:GetDescendants()) do
			if d:IsA("BasePart") then
				foundPart = true
				local cf = d.CFrame
				local hx, hy, hz = d.Size.X * 0.5, d.Size.Y * 0.5, d.Size.Z * 0.5
				for _, sx in ipairs({ -hx, hx }) do
					for _, sy in ipairs({ -hy, hy }) do
						for _, sz in ipairs({ -hz, hz }) do
							local wp = cf:PointToWorldSpace(Vector3.new(sx, sy, sz))
							if wp.X < minX then
								minX = wp.X
							end
							if wp.X > maxX then
								maxX = wp.X
							end
							if wp.Z < minZ then
								minZ = wp.Z
							end
							if wp.Z > maxZ then
								maxZ = wp.Z
							end
						end
					end
				end
			end
		end
	end
	if foundPart then
		cachedBounds = { minX, maxX, minZ, maxZ }
	end
	return minX, maxX, minZ, maxZ
end

local rainZones: { { name: string, part: BasePart, emitters: { ParticleEmitter }, scale: number } } = {}
local function addRainZone(name: string, emitterCount: number, rateScale: number)
	local p = Instance.new("Part")
	p.Name = "RainZone_" .. name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(10, 1, 10)
	p.CFrame = CFrame.new(0, 42, 0)
	p.Parent = emitterFolder

	local list = {}
	for i = 1, emitterCount do
		local em = baseRain:Clone()
		em.Name = "Rain" .. i
		em.Parent = p
		table.insert(list, em)
	end
	table.insert(rainZones, { name = name, part = p, emitters = list, scale = rateScale })
end

-- 4 โซนรอบนอกเพิงร้าน: ด้านหน้าถนน+ตู้ปั๊ม, ด้านซ้าย, ด้านขวา (ศาลพระภูมิ), ด้านหลังเพิง
addRainZone("Front", 2, 1.0)
addRainZone("Left", 1, 0.35)
addRainZone("Right", 1, 0.35)
addRainZone("Back", 1, 0.65)

local lastRainY = -9999
local function updateRainZoneTransforms(y: number, forceSize: boolean?)
	if not forceSize and math.abs(y - lastRainY) < 0.25 and cachedBounds ~= nil then
		return
	end
	lastRainY = y
	local sMinX, sMaxX, sMinZ, sMaxZ = getShackBounds()
	-- เว้นระยะห่างรอบชายคาเพิงอีกด้านละ 3.5 studs ไม่ให้เม็ดฝนตกเฉียดขอบหลังคาเข้ามาด้านใน
	local padMinX = sMinX - 3.5
	local padMaxX = sMaxX + 3.5
	local padMinZ = sMinZ - 3.5
	local padMaxZ = sMaxZ + 3.5
	local shackCenterZ = (padMinZ + padMaxZ) * 0.5
	local shackDepth = padMaxZ - padMinZ
	local shackCenterX = (padMinX + padMaxX) * 0.5

	for _, z in ipairs(rainZones) do
		if z.name == "Front" then
			if forceSize then
				z.part.Size = Vector3.new(110, 1, 56)
			end
			z.part.CFrame = CFrame.new(shackCenterX, y, padMinZ - 28)
		elseif z.name == "Left" then
			if forceSize then
				z.part.Size = Vector3.new(42, 1, shackDepth)
			end
			z.part.CFrame = CFrame.new(padMinX - 21, y, shackCenterZ)
		elseif z.name == "Right" then
			if forceSize then
				z.part.Size = Vector3.new(42, 1, shackDepth)
			end
			z.part.CFrame = CFrame.new(padMaxX + 21, y, shackCenterZ)
		elseif z.name == "Back" then
			if forceSize then
				z.part.Size = Vector3.new(110, 1, 36)
			end
			z.part.CFrame = CFrame.new(shackCenterX, y, padMaxZ + 18)
		end
	end
end

updateRainZoneTransforms(42, true)

local function setAllRainRates(baseRate: number)
	for _, z in ipairs(rainZones) do
		local r = baseRate * z.scale
		for _, em in ipairs(z.emitters) do
			em.Rate = r
		end
	end
end

RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if cam and rainZones[1] and rainZones[1].emitters[1].Rate > 0 then
		updateRainZoneTransforms(cam.CFrame.Position.Y + 38)
	end
end)

-- ---------------------------------------------------------------- เสียงฝน
local sound = Instance.new("Sound")
sound.Name = "RainLoop"
sound.SoundId = RAIN_SOUND
sound.Looped = true
sound.Volume = 0
local sfx = SoundService:FindFirstChild("SFX")
if sfx and sfx:IsA("SoundGroup") then
	sound.SoundGroup = sfx
end
sound.Parent = SoundService

-- ---------------------------------------------------------------- พื้นเปียก (Terrain สีเข้มขึ้น)
local WET_MATERIALS = { Enum.Material.Ground, Enum.Material.Mud, Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Sand, Enum.Material.Rock }
local dryColors: { [Enum.Material]: Color3 } = {}
for _, m in ipairs(WET_MATERIALS) do
	dryColors[m] = terrain:GetMaterialColor(m)
end
local wetness = 0 -- 0 แห้ง .. 1 เปียกสุด
local function applyWetness()
	for m, c in pairs(dryColors) do
		local f = 1 - 0.32 * wetness
		terrain:SetMaterialColor(m, Color3.new(c.R * f, c.G * f, c.B * f * 1.03))
	end
end

-- ---------------------------------------------------------------- แอ่งน้ำบนถนนหน้าร้าน
-- สร้างตอนฝนเริ่มตก (Terrain ต้องโหลดมาถึงเครื่องก่อน ไม่งั้นยิงหาพื้นไม่เจอ) ตำแหน่งสุ่มแบบคงที่ทุกครั้ง
local puddles: { BasePart } = {}
local PUDDLE_SPOTS: { { number } } = {}
local puddleDone: { [number]: boolean } = {}
local folder = Instance.new("Folder")
folder.Name = "Puddles"
folder.Parent = Workspace
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { terrain }
local rng = Random.new(7)
do
	local waypoints = Workspace:WaitForChild("VehicleWaypoints")
	local stop = (waypoints:WaitForChild("StopPoint") :: BasePart).Position
	-- ตามถนนดินหน้าร้าน + รอบตู้ปั๊ม
	for _ = 1, 22 do
		table.insert(PUDDLE_SPOTS, { stop.X + rng:NextNumber(-55, 55), stop.Z + rng:NextNumber(-5, 4), rng:NextNumber(2.5, 7) })
	end
	for _ = 1, 5 do
		table.insert(PUDDLE_SPOTS, { stop.X + rng:NextNumber(-8, 6), stop.Z + rng:NextNumber(4, 10), rng:NextNumber(2, 4.5) })
	end
end
local function puddle(x: number, z: number, d: number): boolean
		local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
		if not hit then
			return false
		end
		for i = 1, 2 do -- 2 วงซ้อนกันให้ทรงไม่กลมเป๊ะ
			local p = Instance.new("Part")
			p.Name = "Puddle"
			p.Shape = Enum.PartType.Cylinder
			local s = d * (if i == 1 then 1 else rng:NextNumber(0.55, 0.8))
			p.Size = Vector3.new(0.05, s, s)
			local off = if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-0.4, 0.4) * d, 0, rng:NextNumber(-0.4, 0.4) * d)
			p.CFrame = CFrame.new(hit.Position + off + Vector3.new(0, 0.04 + i * 0.005, 0)) * CFrame.Angles(0, 0, math.rad(90))
			p.Color = Color3.fromRGB(26, 30, 36)
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0.3
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = folder
			table.insert(puddles, p)
		end
		return true
end
local function ensurePuddles()
	for i, spot in ipairs(PUDDLE_SPOTS) do
		if not puddleDone[i] and puddle(spot[1], spot[2], spot[3]) then
			puddleDone[i] = true
		end
	end
end
local function applyPuddles()
	for _, p in ipairs(puddles) do
		p.Transparency = 1 - 0.7 * wetness
	end
end

-- ---------------------------------------------------------------- เปลี่ยนสภาพอากาศ
local raining = false
local function update()
	raining = remotes:GetAttribute("Weather") == "Rain"
	if raining then
		if not sound.IsPlaying then
			sound:Play()
		end
		TweenService:Create(sound, TweenInfo.new(4), { Volume = 0.3 }):Play()
	else
		TweenService:Create(sound, TweenInfo.new(5), { Volume = 0 }):Play()
	end
end
remotes:GetAttributeChangedSignal("Weather"):Connect(update)
update()

-- ค่อยๆ เปลี่ยน: ฝนตกหนักขึ้นใน 4 วิ, พื้นเปียกใน ~20 วิ, แห้งช้ากว่า (~60 วิ)
local rateNow = 0
task.spawn(function()
	while true do
		local dt = task.wait(0.25)
		local targetRate = if raining then RAIN_RATE else 0
		rateNow += math.clamp(targetRate - rateNow, -RAIN_RATE * dt / 3, RAIN_RATE * dt / 4)
		setAllRainRates(rateNow)
		local target = if raining then 1 else 0
		local speed = if raining then dt / 20 else dt / 60
		local before = wetness
		wetness = math.clamp(wetness + math.clamp(target - wetness, -speed, speed), 0, 1)
		if math.abs(wetness - before) > 0.0001 then
			if raining then
				ensurePuddles()
			end
			applyWetness()
			applyPuddles()
		end
		if not raining and sound.IsPlaying and sound.Volume < 0.01 then
			sound:Stop()
		end
	end
end)

-- ---------------------------------------------------------------- ฟ้าแลบ (Server ตั้ง ThunderAt ก่อนเสียงฟ้าร้องไม่ถึงวิ)
local Lighting = game:GetService("Lighting")
local flashFx = Instance.new("ColorCorrectionEffect")
flashFx.Name = "LightningFlash"
flashFx.Brightness = 0
flashFx.TintColor = Color3.fromRGB(220, 230, 255)
flashFx.Parent = Lighting
remotes:GetAttributeChangedSignal("ThunderAt"):Connect(function()
	if not raining then
		return
	end
	task.spawn(function()
		for i = 1, (if math.random() < 0.5 then 2 else 1) do
			flashFx.Brightness = 0.55 + math.random() * 0.25
			TweenService:Create(flashFx, TweenInfo.new(0.25), { Brightness = 0 }):Play()
			task.wait(0.12 + math.random() * 0.15)
		end
	end)
end)
