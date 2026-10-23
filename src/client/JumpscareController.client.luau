-- JumpscareController.client.luau
-- ผีหลอกเต็มจอตอนเติมน้ำมันให้ผี (TriggerJumpscare: anomalyKey, model)
--   ใช้ตัวผีจริงจากฉาก (หัวคนขับ/ผีซ้อนท้าย/ผีตานี/หุ่นไล่กา) Clone ใส่ ViewportFrame แล้วพุ่งเข้าหาจอ
--   + เสียงหลอน + สีจอ + เอฟเฟกต์เฉพาะของผีแต่ละแบบ (เลือดหยด, ขาวดำ, ฟ้าแลบ ...)
-- เสียงทุกตัวอยู่ใน SoundGroup SFX (ปรับระดับได้จากหน้าตั้งค่า)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local TriggerJumpscare = remotes:WaitForChild("TriggerJumpscare") :: RemoteEvent

local SND = {
	Sting = "rbxassetid://97921269926730", -- Scared Effect (เสียงตกใจหลัก)
	Sting2 = "rbxassetid://134690050450846",
	Scream = "rbxassetid://93232280469148",
	Bone = "rbxassetid://9113542694",
	Laugh = "rbxassetid://91272160888434",
	Bells = "rbxassetid://119445319966378",
	Static = "rbxassetid://9117159106",
	Crows = "rbxassetid://190872950",
	Crying = "rbxassetid://75664285683608",
	Glug = "rbxassetid://9117641837",
	Thunder = "rbxassetid://9120016037",
}

-- เอฟเฟกต์ของผีแต่ละแบบ
--   focus = แบบที่จะเอามาโชว์ ("head" หัวคนขับ, "passenger", "tani", "scarecrow", "body" ทั้งตัวคนขับ)
--   sounds = { {id, volume, delay, length?} }  tint = สีจอ  extra = เอฟเฟกต์พิเศษ
local FX = {
	Anomaly_Headless = { focus = "passenger", tint = Color3.fromRGB(140, 0, 0), sounds = { { "Sting", 1 }, { "Scream", 0.8, 0.1 } }, extra = "blood" },
	Anomaly_Cemetery = { focus = "head", tint = Color3.fromRGB(60, 60, 60), sounds = { { "Sting2", 1 }, { "Bells", 0.8, 0.05 } }, extra = "grey" },
	Anomaly_WheelHair = { focus = "head", tint = Color3.fromRGB(20, 10, 10), sounds = { { "Sting", 1 }, { "Scream", 0.8, 0.15 } }, extra = "hair" },
	Anomaly_NeckTwist = { focus = "head", tint = Color3.fromRGB(110, 0, 0), sounds = { { "Bone", 1 }, { "Bone", 1, 0.25 }, { "Sting", 0.9, 0.1 } }, spin = true },
	Anomaly_CreepySmile = { focus = "head", tint = Color3.fromRGB(90, 0, 20), sounds = { { "Sting", 1 }, { "Laugh", 0.9, 0.2 } } },
	Anomaly_Krasue = { focus = "body", tint = Color3.fromRGB(170, 20, 0), sounds = { { "Sting", 1 }, { "Scream", 0.9, 0.05 } }, extra = "blood" },
	Anomaly_MonkRadio = { focus = "head", tint = Color3.fromRGB(50, 50, 55), sounds = { { "Static", 1, 0, 1.2 }, { "Sting2", 1, 0.1 } }, extra = "static" },
	-- ผีตานี / หุ่นไล่กา: ตัวจริงเป็น MeshPart ที่ ViewportFrame วาดไม่ขึ้น ใช้หน้าหลอนของลูกค้าแทน (เสียง/สีจอยังเป็นของตัวเอง)
	Anomaly_Tani = { focus = "head", tint = Color3.fromRGB(20, 80, 30), sounds = { { "Crying", 0.8 }, { "Scream", 1, 0.3 } } },
	Anomaly_Scarecrow = { focus = "head", tint = Color3.fromRGB(90, 40, 0), sounds = { { "Crows", 1, 0, 3 }, { "Sting", 1, 0.05 } } },
	Anomaly_BloodFuel = { focus = "head", tint = Color3.fromRGB(150, 0, 0), sounds = { { "Glug", 1 }, { "Sting", 1, 0.15 } }, extra = "blood" },
	Anomaly_NoUmbrella = { focus = "head", tint = Color3.fromRGB(200, 210, 255), sounds = { { "Thunder", 1 }, { "Sting", 1, 0.05 } }, extra = "lightning" },
}
local DEFAULT_FX = { focus = "head", tint = Color3.fromRGB(120, 0, 0), sounds = { { "Sting", 1 } } }

-- ---------------------------------------------------------------- เสียง
local JUMPSCARE_BOOST = 3 -- ผีหลอกดังกว่าเสียงอื่นชัดเจน (กลุ่ม SFX ถูกหารครึ่งอยู่แล้ว)
local sfxGroup = SoundService:FindFirstChild("SFX")
local function play(key: string, volume: number, length: number?)
	local s = Instance.new("Sound")
	s.SoundId = SND[key]
	s.Volume = volume * JUMPSCARE_BOOST
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		s.SoundGroup = sfxGroup
	end
	s.Parent = SoundService
	s:Play()
	local life = length or 8
	task.delay(life, function()
		s:Stop()
		s:Destroy()
	end)
end

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "Jumpscare"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 15
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(0, 0, 0)
bg.BorderSizePixel = 0
bg.ZIndex = 1
bg.Parent = gui

local vp = Instance.new("ViewportFrame")
vp.Name = "Face"
vp.Size = UDim2.fromScale(1, 1)
vp.BackgroundTransparency = 1
vp.ZIndex = 2
vp.Ambient = Color3.fromRGB(120, 110, 110)
vp.LightColor = Color3.fromRGB(255, 220, 200)
vp.LightDirection = Vector3.new(0.3, -0.6, -1)
vp.Parent = gui
local vpCam = Instance.new("Camera")
vpCam.FieldOfView = 60
vpCam.Parent = vp
vp.CurrentCamera = vpCam

local tintFrame = Instance.new("Frame")
tintFrame.Size = UDim2.fromScale(1, 1)
tintFrame.BorderSizePixel = 0
tintFrame.BackgroundTransparency = 1
tintFrame.ZIndex = 3
tintFrame.Parent = gui

-- เลือดหยดจากขอบบน
local drips = Instance.new("Frame")
drips.Size = UDim2.fromScale(1, 1)
drips.BackgroundTransparency = 1
drips.ZIndex = 4
drips.Parent = gui

local grey = Instance.new("ColorCorrectionEffect")
grey.Name = "JumpscareGrade"
grey.Enabled = false
grey.Parent = Lighting

-- ---------------------------------------------------------------- เลือกตัวผีมาใส่จอ
local function ghostModel(key: string?, focus: string, source: Instance?): (Model?, BasePart?)
	local m = Instance.new("Model")
	local focusPart: BasePart? = nil
	local function addClone(inst: Instance)
		local c = inst:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			end
		end
		c.Parent = m
		return c
	end
	local anomalyProps = Workspace:FindFirstChild("AnomalyProps")
	if focus == "tani" and anomalyProps and anomalyProps:FindFirstChild("PhiTaniGhost") then
		local c = addClone(anomalyProps.PhiTaniGhost)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 0
			end
		end
		focusPart = c:FindFirstChild("TaniHead", true) :: BasePart?
	elseif focus == "scarecrow" and anomalyProps and anomalyProps:FindFirstChild("Scarecrow") then
		local c = addClone(anomalyProps.Scarecrow)
		-- ชิ้นล่องหน (กล่องป้ายเดิม) ทำให้กรอบเพี้ยน เอาออก
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency >= 1 then
				d:Destroy()
			end
		end
		-- โฟกัสส่วนบนของหุ่น (หัว)
		local best: BasePart? = nil
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and (not best or d.Position.Y > best.Position.Y) and d.Transparency < 1 then
				best = d
			end
		end
		focusPart = best
	elseif source then
		if focus == "passenger" and source:FindFirstChild("GhostPassenger") then
			local c = addClone(source.GhostPassenger)
			focusPart = c:FindFirstChild("NeckStump") :: BasePart?
		end
		if not focusPart then
			local driver = source:FindFirstChild("DriverNPC")
			if driver then
				local c = addClone(driver)
				local head = c:FindFirstChild("Head") :: BasePart?
				-- หน้าหลอนเสมอ (ยกเว้นหันหัวกลับ ที่จะหมุนให้เห็นทีหลัง)
				if head then
					-- ผิวซีดเขียว ตาโบ๋ดำ ลูกตาแดงเรือง ปากดำ (หน้าตอนหลอกต้องน่ากลัวกว่าตอนขี่รถมา)
					head.Color = Color3.fromRGB(176, 182, 168)
					local creepy = head:FindFirstChild("CreepyFace")
					if creepy then
						for _, d in ipairs(creepy:GetDescendants()) do
							if d:IsA("BasePart") then
								d.Transparency = 0
								if d.Name == "Eye" then
									d.Color = Color3.fromRGB(8, 6, 6)
									d.Material = Enum.Material.SmoothPlastic
								elseif d.Name == "Pupil" then
									d.Color = Color3.fromRGB(255, 30, 20)
									d.Material = Enum.Material.Neon
								elseif d.Name == "Smile" or d.Name == "SmileCorner" then
									d.Color = Color3.fromRGB(20, 4, 4)
								elseif d.Name == "Teeth" then
									d.Color = Color3.fromRGB(200, 190, 150)
								end
							end
						end
					end
					local face = head:FindFirstChild("FaceNormal")
					if face and face:IsA("Decal") then
						face.Transparency = 1
					end
				end
				focusPart = if focus == "body" then (c:FindFirstChild("Torso") :: BasePart?) or head else head
			end
		end
	end
	if not focusPart then
		m:Destroy()
		return nil, nil
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m, focusPart
end

-- ---------------------------------------------------------------- เอฟเฟกต์พิเศษ
local function bloodDrips()
	drips:ClearAllChildren()
	for _ = 1, 14 do
		local d = Instance.new("Frame")
		local w = math.random(6, 22)
		d.Size = UDim2.new(0, w, 0, 0)
		d.Position = UDim2.new(math.random(), 0, 0, 0)
		d.BackgroundColor3 = Color3.fromRGB(math.random(90, 140), 0, 0)
		d.BorderSizePixel = 0
		d.Parent = drips
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, w)
		c.Parent = d
		TweenService:Create(d, TweenInfo.new(math.random(10, 22) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, w, math.random(25, 75) / 100, 0),
		}):Play()
	end
end

local function hairStrands()
	drips:ClearAllChildren()
	for _ = 1, 40 do
		local h = Instance.new("Frame")
		h.Size = UDim2.new(0, math.random(2, 5), math.random(40, 110) / 100, 0)
		h.Position = UDim2.new(math.random(), 0, -0.1, 0)
		h.Rotation = math.random(-12, 12)
		h.BackgroundColor3 = Color3.fromRGB(8, 6, 6)
		h.BorderSizePixel = 0
		h.Parent = drips
	end
end

-- ---------------------------------------------------------------- เล่นผีหลอก
local busy = false
TriggerJumpscare.OnClientEvent:Connect(function(key: string?, source: Instance?)
	if busy then
		return
	end
	busy = true
	local fx = (key and FX[key]) or DEFAULT_FX
	for _, s in ipairs(fx.sounds) do
		task.delay(s[3] or 0, function()
			play(s[1], s[2], s[4])
		end)
	end

	local model, focus = ghostModel(key, fx.focus, source)
	-- ผีทั้งตัวสีทึบ (หุ่นไล่กา/ตานี) ต้องสว่างกว่าหน้าคนนิดหน่อย ไม่งั้นจมหายในจอมืด
	vp.Ambient = if fx.focus == "scarecrow" or fx.focus == "tani" then Color3.fromRGB(175, 165, 160) else Color3.fromRGB(120, 110, 110)
	local function clearViewport()
		for _, ch in ipairs(vp:GetChildren()) do
			if ch ~= vpCam then
				ch:Destroy()
			end
		end
	end
	clearViewport()
	local world = Instance.new("WorldModel")
	world.Parent = vp
	if model then
		model.Parent = world
	end

	gui.Enabled = true
	bg.BackgroundTransparency = 0.05
	tintFrame.BackgroundColor3 = fx.tint
	tintFrame.BackgroundTransparency = 0.55
	drips:ClearAllChildren()
	if fx.extra == "blood" then
		bloodDrips()
	elseif fx.extra == "hair" then
		hairStrands()
	elseif fx.extra == "grey" or fx.extra == "static" then
		grey.Enabled = true
		grey.Saturation = -1
		grey.Contrast = 0.4
	elseif fx.extra == "lightning" then
		tintFrame.BackgroundTransparency = 0
		TweenService:Create(tintFrame, TweenInfo.new(0.35), { BackgroundTransparency = 0.6 }):Play()
	end

	-- กล้องใน Viewport: เริ่มไกล แล้วพุ่งเข้าหน้า (หน้า = -Z ของชิ้นโฟกัส)
	local conn: RBXScriptConnection? = nil
	if focus then
		local target = focus.Position
		local front = focus.CFrame.LookVector
		local size = math.max(focus.Size.X, focus.Size.Y, focus.Size.Z)
		-- ผีทั้งตัว (หุ่นไล่กา / ผีตานี): จัดเฟรมจากกรอบทั้งตัว เล็งช่วงหัว (บน 1/3) หน้า = ทิศหน้าของโมเดล
		if model and (fx.focus == "scarecrow" or fx.focus == "tani") then
			local bcf, bsize = model:GetBoundingBox()
			target = bcf.Position + Vector3.new(0, bsize.Y * 0.32, 0)
			local inner = model:FindFirstChildWhichIsA("Model") or model -- ตัวผีจริงอยู่ข้างในโมเดลห่อ
			local look = inner:GetPivot().LookVector
			front = Vector3.new(look.X, 0, look.Z).Unit
			-- มีลูกตา: หน้า = ฝั่งที่ลูกตาอยู่ (pivot ของหุ่นไล่กาหันหลัง) และเล็งที่ระดับตา
			local eyes = {}
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") and string.find(d.Name, "Eye") then
					table.insert(eyes, d.Position)
				end
			end
			if #eyes > 0 then
				local sum = Vector3.zero
				for _, e in ipairs(eyes) do
					sum += e
				end
				local eyeAt = sum / #eyes
				local dir = Vector3.new(eyeAt.X - bcf.Position.X, 0, eyeAt.Z - bcf.Position.Z)
				if dir.Magnitude > 0.01 then
					front = dir.Unit
				end
				target = eyeAt
			end
			size = math.max(bsize.Y * 0.55, 2.5) -- ถอยให้เห็นทั้งหัว (ตาหุ่นไล่กาเล็กมากบนหน้ากว้าง)
		end
		local up = Vector3.new(0, 1, 0)
		local far, near = size * 9, size * 1.05 -- ใกล้จนหน้าเกือบเต็มจอ
		local t0 = os.clock()
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local k = math.clamp(t / 0.16, 0, 1) -- 0.16 วิ พุ่งเข้ามา
			local dist = far + (near - far) * (k * k)
			local shake = if k >= 1 then Vector3.new(math.random(-10, 10), math.random(-10, 10), 0) / 100 * size else Vector3.zero
			local camPos = target + front * dist + shake
			vpCam.CFrame = CFrame.lookAt(camPos, target + shake * 0.5)
			if fx.spin and model then
				-- หันหัวกลับมาทางเราแบบกระตุก
				local ang = math.rad(math.clamp((t - 0.2) / 0.25, 0, 1) * 180)
				focus.CFrame = CFrame.new(target) * (focus.CFrame - focus.Position) * CFrame.Angles(0, ang - (focus:GetAttribute("Spun") or 0), 0)
				focus:SetAttribute("Spun", ang)
			end
			-- กะพริบ
			vp.ImageTransparency = if t > 0.7 and math.random() < 0.25 then 0.6 else 0
		end)
	end

	-- สั่นกล้องจริงด้วย
	local cam = Workspace.CurrentCamera
	task.spawn(function()
		for _ = 1, 14 do
			if cam then
				cam.CFrame *= CFrame.Angles(math.rad(math.random(-3, 3)), math.rad(math.random(-3, 3)), 0)
			end
			task.wait(0.03)
		end
	end)

	task.wait(gui:GetAttribute("DebugHold") or 1.25) -- (ทดสอบ: ตั้ง Attribute DebugHold ให้ค้างนานขึ้น)
	-- จางออก
	TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(vp, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
	TweenService:Create(tintFrame, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	for _, d in ipairs(drips:GetChildren()) do
		if d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
	end
	task.wait(0.9)
	if conn then
		conn:Disconnect()
	end
	grey.Enabled = false
	gui.Enabled = false
	vp.ImageTransparency = 0
	clearViewport()
	drips:ClearAllChildren()
	busy = false
end)
