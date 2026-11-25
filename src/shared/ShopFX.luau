--!nonstrict
-- ShopFX.luau (ReplicatedStorage.Shared, ใช้ฝั่ง Client) — ร้านตอบสนองตอนผีวน (client/KnockFX, client/LingerFX)
--   จอสั่น / ฝุ่นจากสังกะสี / ไฟในร้านวูบ / หลอดไส้เหวี่ยง / จิ้งหรีดเงียบ
--   ทุกอย่างอยู่บนเครื่องนี้ ไม่แตะค่าฝั่ง Server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ShopFX = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundBank = require(script.Parent:WaitForChild("SoundBank")) :: any
local CEIL = 11.7 -- ใต้แผ่นหลังคาเพิง (หลังคาเรียบ ~12.0)

-- ---------------------------------------------------------------- จอสั่น
local shakes: { { at: number, amp: number, len: number } } = {}
RunService:BindToRenderStep("ShopFXShake", Enum.RenderPriority.Camera.Value + 3, function()
	if #shakes == 0 then
		return
	end
	local cam = Workspace.CurrentCamera
	local now = os.clock()
	local amp = 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local k = 1 - (now - s.at) / s.len
		if k <= 0 then
			table.remove(shakes, i)
		else
			amp = math.max(amp, s.amp * k * k)
		end
	end
	if cam and cam.CameraType ~= Enum.CameraType.Scriptable and amp > 0 then
		cam.CFrame *= CFrame.Angles(math.rad(math.noise(now * 22, 3) * 2 * amp), math.rad(math.noise(now * 22, 9) * 2 * amp), math.rad(math.noise(now * 17, 15) * 1.4 * amp))
	end
end)

-- แรงตามระยะ: ใกล้กว่า near = เต็ม ไกลกว่า far = ไม่สั่น · flat = วัดระยะแนวราบอย่างเดียว (ของบนหลังคา)
function ShopFX.Shake(pos: Vector3, amp: number, len: number, near: number, far: number, flat: boolean?)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local off = cam.CFrame.Position - pos
	if flat then
		off = Vector3.new(off.X, 0, off.Z)
	end
	local a = amp * math.clamp((far - off.Magnitude) / (far - near), 0, 1)
	if a > 0.03 then
		table.insert(shakes, { at = os.clock(), amp = a, len = len })
	end
end

-- ---------------------------------------------------------------- ฝุ่นร่วงจากสังกะสี
function ShopFX.Dust(size: Vector3, pos: Vector3): (Part, ParticleEmitter)
	local p = Instance.new("Part")
	p.Name = "ShopDust"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.Position = pos
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(140, 128, 108))
	e.LightInfluence = 1
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.75) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(1.0, 2.0)
	e.Speed = NumberRange.new(0.4, 1.6)
	e.Acceleration = Vector3.new(0, -3.2, 0)
	e.Drag = 0.6
	e.SpreadAngle = Vector2.new(25, 25)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = p
	p.Parent = Workspace.CurrentCamera
	return p, e
end

-- ---------------------------------------------------------------- ไฟในร้านวูบ (ไม่รวมไฟเสานอกร้าน) + หลอดไส้เหวี่ยง
local LIGHT_PARTS = { ShackLight_Neon = true, ShackLightBulb = true, Bulb = true, Filament = true, StormLantern_Neon = true }
local lights: { { l: Light, b: number } }? = nil
local bulbs: { BasePart } = {}
local hanging: Model? = nil

local function scan()
	local list = {}
	bulbs = {}
	local env = Workspace:FindFirstChild("MapEnvironment")
	for _, d in ipairs(env and env:GetDescendants() or {}) do
		if d:IsA("BasePart") and LIGHT_PARTS[d.Name] then
			table.insert(bulbs, d)
			for _, l in ipairs(d:GetDescendants()) do
				if l:IsA("Light") then
					table.insert(list, { l = l, b = l.Brightness })
				end
			end
		elseif d.Name == "HangingBulb" and d:IsA("Model") then
			hanging = d
		end
	end
	lights = list
end

function ShopFX.Busy(): boolean -- ลางผีใหญ่ / ผีใหญ่ คุมไฟอยู่ (client/AmbienceController)
	return remotes:GetAttribute("BigOmen") == true or remotes:GetAttribute("BigEvent") ~= nil
end
function ShopFX.LightsOn(): boolean
	return ReplicatedStorage:GetAttribute("PowerOn") ~= false and ReplicatedStorage:GetAttribute("BreakerOn") ~= false
end

local function setLights(f: number)
	for _, e in ipairs(lights or {}) do
		if e.l.Parent then
			e.l.Brightness = e.b * f
		end
	end
	for _, p in ipairs(bulbs) do
		if p.Parent then
			(p :: any).LocalTransparencyModifier = (1 - f) * 0.75
		end
	end
end

local dipAt, dipAmp, dipLen = 0, 0, 0.1
local dipConn: RBXScriptConnection? = nil
-- amp 0..1 = หรี่แค่ไหน · len วินาที (> 0.5 = ติดๆ ดับๆ ก่อนกลับมา)
function ShopFX.Dip(amp: number, len: number)
	if ShopFX.Busy() or not ShopFX.LightsOn() then
		return
	end
	if not dipConn then
		scan() -- ค่าความสว่างปกติ ณ ตอนนี้
	end
	dipAt, dipAmp, dipLen = os.clock(), amp, len
	if dipConn then
		return
	end
	dipConn = RunService.PreRender:Connect(function()
		local clock = os.clock()
		local k = (clock - dipAt) / dipLen
		if k >= 1 or ShopFX.Busy() or not ShopFX.LightsOn() then
			(dipConn :: RBXScriptConnection):Disconnect()
			dipConn = nil
			if not ShopFX.Busy() then
				setLights(1)
			end
			return
		end
		local f = 1 - dipAmp * (1 - k) ^ 0.6
		if dipLen > 0.5 and math.noise(clock * 24, 5) > 0.1 then
			f = math.min(f, 0.12)
		end
		setLights(math.clamp(f, 0, 1))
	end)
end

function ShopFX.HangingBulb(): Model?
	if not (hanging and hanging.Parent) then
		scan()
	end
	return hanging
end
function ShopFX.Swing(v: number)
	local h = ShopFX.HangingBulb()
	if h then
		h:SetAttribute("Kick", v) -- client/AmbienceController swayHangingBulb
	end
end

-- ---------------------------------------------------------------- จิ้งหรีดเงียบ (AmbienceController ฟัง attribute KnockHush)
local hushers: { [any]: boolean } = {}
function ShopFX.Hush(owner: any, on: boolean)
	hushers[owner] = if on then true else nil
	ReplicatedStorage:SetAttribute("KnockHush", if next(hushers) ~= nil then true else nil)
end

-- จุดปล่อยเสียงชั่วคราวในฉาก
function ShopFX.Emitter(pos: Vector3, name: string): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	return a
end

-- ลงกระแทก / กระทืบหลังคา (กระหัง, มือเปรต) p = แรง 0..1 (1 = ทุบสุดท้าย)
function ShopFX.RoofSlam(pos: Vector3, p: number)
	local final = p >= 0.985
	local att = ShopFX.Emitter(Vector3.new(pos.X, 12.2, pos.Z), "RoofSlam")
	local s = SoundBank.CreateSound("ShutterKnock", att, 110)
	if s then
		s.RollOffMinDistance = 14
		s.Volume *= (0.3 + 0.8 * p) * (if final then 1.2 else 1)
		s.PlaybackSpeed *= (if final then 0.58 else 0.8 - 0.14 * p) * (0.97 + math.random() * 0.06)
		s:Play()
	end
	local d1, e1 = ShopFX.Dust(Vector3.new(5, 0.2, 5), Vector3.new(pos.X, CEIL, pos.Z))
	e1:Emit(math.floor(10 + 30 * p))
	local d2, e2 = ShopFX.Dust(Vector3.new(26, 0.2, 15), Vector3.new(0, CEIL, 18))
	if p > 0.7 then
		e2:Emit(math.floor(34 * p) + (if final then 30 else 0))
	end
	task.delay(3.2, function()
		d1:Destroy()
		d2:Destroy()
		att:Destroy()
	end)
	ShopFX.Swing(p * p * (if final then 4.2 else 3))
	ShopFX.Shake(pos, p * p * (if final then 1.8 else 1.1), if final then 0.75 else 0.4, 4, 26, true)
	if p > 0.5 then
		ShopFX.Dip(if final then 0.97 else 0.35 + 0.45 * p, if final then 0.8 else 0.2)
	end
end

return ShopFX
