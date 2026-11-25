--!nonstrict
-- LingerFX.client.luau — เอฟเฟกต์ฝั่งผู้เล่นของผีวนรอบร้าน (server/GhostLinger "circle" = กุมาร, "roof" = กระหัง)  ผู้ใช้ 2026-11-26
--   แผงปิดอยู่ คนในร้านมองไม่เห็นผี: เล่าด้วยเสียง ฝุ่น ไฟ หลอดไส้ จอสั่น (shared/ShopFX)
--   กุมาร (tag KumanRunner): เสียงฝีเท้าตามตัว หยุดเมื่อตัวหยุด · เคาะผนังเบาๆ ระดับเด็ก · ตอนจบเสียงเท้าวิ่งเข้ามาในร้านหลังเรา + ถาดขนมขยับ
--   กระหัง (tag RoofGhost): ฝุ่นร่วงตามทาง หลอดแกว่งตอนผ่าน หยุดเหนือหัว (ฝุ่นร่วงใส่) แล้วกระทืบ
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundBank = require(Shared:WaitForChild("SoundBank")) :: any
local ShopFX = require(Shared:WaitForChild("ShopFX")) :: any
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local interactive = Workspace:WaitForChild("InteractiveProps")

local CEIL = 11.7 -- ใต้แผ่นหลังคา (หลังคาเรียบ ~12.0)
-- เสียงเท้ากุมาร = ไฟล์เดียวกับเสียงเท้าผู้เล่น (AmbienceController HorrorFootsteps) ความเร็วใกล้ปกติ
--   (ผู้ใช้ 2026-11-26: WalkDirtHurry เร่ง 1.45 เท่า "ไม่ไหว ลองใช้เสียงเท้าปรกติ")
local FOOT_ID = "rbxassetid://135952279207329"
local FOOT_VOLUME = 0.75

local function shackBox(): (CFrame?, Vector3?)
	local env = Workspace:FindFirstChild("MapEnvironment")
	local s = env and env:FindFirstChild("ShackStructure")
	if s and s:IsA("Model") then
		return s:GetBoundingBox()
	end
	return nil, nil
end
local function insideShop(pos: Vector3): boolean
	local cf, size = shackBox()
	local door = interactive:FindFirstChild("ShutterDoor") :: BasePart?
	if not (cf and size and door) then
		return false
	end
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) < size.X / 2 - 0.4 and pos.Z > door.Position.Z + 0.3 and lp.Z < size.Z / 2
end

local function oneShot(preset: string, pos: Vector3, volume: number, speed: number, minDist: number, maxDist: number, life: number)
	local att = ShopFX.Emitter(pos, "LingerEmitter")
	local s = SoundBank.CreateSound(preset, att, maxDist)
	if s then
		s.RollOffMinDistance = minDist
		s.Volume *= volume
		s.PlaybackSpeed *= speed
		s:Play()
	end
	task.delay(life, function()
		if s then
			TweenService:Create(s, TweenInfo.new(0.25), { Volume = 0 }):Play()
			task.wait(0.3)
		end
		att:Destroy()
	end)
	return s
end

local function liveGhost(m: Instance): boolean
	return m.Parent ~= nil and m:GetAttribute("KnockEnd") ~= true
end

local function footSound(parent: Instance, wood: boolean, minDist: number, maxDist: number): Sound
	local s = Instance.new("Sound")
	s.Name = "KumanSteps"
	s.SoundId = FOOT_ID
	s.Looped = true
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = minDist
	s.RollOffMaxDistance = maxDist
	local g = SoundService:FindFirstChild("SFX")
	if g and g:IsA("SoundGroup") then
		s.SoundGroup = g
	end
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = if wood then 2 else 1
	eq.MidGain = if wood then -1 else 0
	eq.HighGain = if wood then -10 else -7
	eq.Parent = s
	s.Parent = parent
	return s
end

-- ---------------------------------------------------------------- กุมารวิ่งรอบร้าน
local function runKuman(m: Model)
	local root = m:WaitForChild("RootPart", 5) :: BasePart?
	if not root then
		return
	end
	local steps = footSound(root, false, 11, 75)
	local last, vel = root.Position, 0
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function(dt)
		local live = liveGhost(m)
		local p = root.Position
		local v = (p - last).Magnitude / math.max(dt, 1e-3)
		last = p
		if v < 60 then -- วาร์ปไปอีกฝั่ง: ไม่นับเป็นความเร็ว
			vel += (v - vel) * math.min(1, dt * 14)
		end
		local moving = live and vel > 2.5 and m:GetAttribute("Silent") ~= true
		steps.Volume += ((if moving then FOOT_VOLUME else 0) - steps.Volume) * math.min(1, dt * (if moving then 10 else 22))
		if moving then
			steps.PlaybackSpeed = math.clamp(0.9 + vel * 0.016, 1.0, 1.2) -- เดินปกติ 10 studs/วิ = ~1.05
			if not steps.IsPlaying then
				steps:Play()
			end
		elseif steps.IsPlaying and steps.Volume < 0.01 then
			steps:Stop()
		end
		if not live then
			conn:Disconnect()
			steps:Destroy()
		end
	end)
end

-- เคาะผนังเบาๆ 3 ที ระดับเด็ก
local function knockLow(pos: Vector3)
	for i, t in ipairs({ 0, 0.36, 0.66 }) do
		task.delay(t, function()
			oneShot("ShutterKnock", pos, 0.15 + 0.03 * i, 1.5 + math.random() * 0.12, 9, 70, 1.4)
		end)
	end
end

-- เสียงเท้าเข้ามาในร้าน: วิ่งจากข้างหลังซ้าย/ขวาผ่านหลังเราไปอีกข้าง แล้วหัวเราะข้างหู (เฉพาะคนที่อยู่ในร้าน ของใครของมัน)
local function runInside(m: Instance?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local cam = Workspace.CurrentCamera
	if not (hrp and cam and insideShop(hrp.Position)) then
		return
	end
	local side = if math.random() < 0.5 then 1 else -1
	local att = ShopFX.Emitter(hrp.Position, "KumanInside")
	local s = footSound(att, true, 6, 45)
	s.Volume = FOOT_VOLUME
	s.PlaybackSpeed = 1.1
	s:Play()
	local dur = 1.9
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function()
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
		local right = look:Cross(Vector3.yAxis)
		-- โค้งผ่านหลัง: ใกล้สุด 2.6 studs ตอนกลางทาง
		local x = side * (9 - 18 * k)
		att.WorldPosition = hrp.Position - look * (2.6 + 1.5 * math.abs(1 - 2 * k)) + right * x - Vector3.new(0, 2.4, 0)
		if k >= 1 then
			conn:Disconnect()
		end
	end)
	task.wait(dur)
	s:Stop()
	att:Destroy()
	task.wait(0.9)
	-- หัวเราะข้างหู ฝั่งตรงข้ามกับที่วิ่งไป
	local look = cam.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local right = flat:Cross(Vector3.yAxis)
	oneShot("Ghost_Kuman_Laugh", hrp.Position + right * side * 2 - flat * 1.6 + Vector3.new(0, 0.4, 0), 0.95, 1.06, 4, 30, 2.6)
end

-- ถาดขนมบนเคาน์เตอร์ขยับเอง (บนเครื่องนี้) แล้วค่อยคืนที่ตอนไม่มีใครดู/ครบเวลา
local trayBusy = false
local function nudgeTray()
	local tray = interactive:FindFirstChild("DessertTray")
	if trayBusy or not (tray and tray:IsA("Model")) then
		return
	end
	trayBusy = true
	local from = tray:GetPivot()
	local to = from * CFrame.new(0.55, 0, 0.25) * CFrame.Angles(0, math.rad(24), 0)
	oneShot("CoinTinDrop1", from.Position, 0.7, 0.75, 6, 45, 1.5)
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(k)
		tray:PivotTo(from:Lerp(to, k))
	end)
	TweenService:Create(v, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()
	task.wait(14)
	local t0 = os.clock()
	while os.clock() - t0 < 25 do
		local cam = Workspace.CurrentCamera
		if cam and (from.Position - cam.CFrame.Position).Unit:Dot(cam.CFrame.LookVector) < 0.2 then
			break
		end
		task.wait(0.3)
	end
	v:Destroy()
	tray:PivotTo(from)
	trayBusy = false
end

-- ---------------------------------------------------------------- กระหังบนหลังคา
local function runRoof(m: Model)
	local root = m:WaitForChild("RootPart", 5) :: BasePart?
	if not root then
		return
	end
	local dust, em = ShopFX.Dust(Vector3.new(2.2, 0.2, 2.2), Vector3.new(root.Position.X, CEIL, root.Position.Z))
	local last, nextDust, nextSwing = root.Position, 0, 0
	local conn: RBXScriptConnection
	conn = RunService.PreRender:Connect(function(dt)
		local live = liveGhost(m)
		local clock = os.clock()
		local p = root.Position
		local flat = Vector3.new(p.X - last.X, 0, p.Z - last.Z)
		local v = flat.Magnitude / math.max(dt, 1e-3)
		last = p
		local onRoof = live and p.Y < 16
		dust.Position = Vector3.new(p.X, CEIL, p.Z)
		-- ฝุ่นร่วงตามทางที่มันผ่าน + ตอนนั่งทับหัวเรา (attribute Trickle)
		if onRoof and clock >= nextDust then
			if v > 1.5 and v < 60 then
				nextDust = clock + 0.1
				em:Emit(3)
			elseif m:GetAttribute("Trickle") == true then
				nextDust = clock + 0.16 + math.random() * 0.2
				em:Emit(2)
			end
		end
		-- หลอดไส้แกว่งตอนมันผ่านเหนือ
		if onRoof and v > 1.5 and v < 60 and clock >= nextSwing then
			local hb = ShopFX.HangingBulb()
			if hb then
				local hp = hb:GetPivot().Position
				if Vector3.new(hp.X - p.X, 0, hp.Z - p.Z).Magnitude < 4.5 then
					nextSwing = clock + 0.5
					ShopFX.Swing(1.1)
				end
			end
		end
		if not live then
			conn:Disconnect()
			task.delay(3, function()
				dust:Destroy()
			end)
		end
	end)
end

-- ---------------------------------------------------------------- เชื่อมต่อ
local function bind(tag: string, fn: (Model) -> ())
	-- ร่างโคลนในจอผีหลอก (ViewportFrame) มี tag ติดมาด้วย: ไม่เล่นเอฟเฟกต์
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(m)
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then
			task.spawn(fn, m)
		end
	end)
	for _, m in ipairs(CollectionService:GetTagged(tag)) do
		if m:IsA("Model") and m:IsDescendantOf(Workspace) then
			task.spawn(fn, m)
		end
	end
end
bind("KumanRunner", runKuman)
bind("RoofGhost", runRoof)

local remote = remotes:WaitForChild("LingerFX", 60)
if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function(kind: string, a: any, b: any)
		if kind == "hush" then
			ShopFX.Hush("linger", a == true)
		elseif kind == "knockLow" then
			knockLow(a)
		elseif kind == "inside" then
			runInside(a)
		elseif kind == "tray" then
			nudgeTray()
		elseif kind == "slam" then
			ShopFX.RoofSlam(a, b)
		end
	end)
end
