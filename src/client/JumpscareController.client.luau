-- JumpscareController.client.luau
-- ผีหลอกเต็มจอตอนเติมน้ำมันให้ผี (TriggerJumpscare: anomalyKey, model)
--   ใช้ตัวผีจริงจากฉาก (หัวคนขับ/ผีซ้อนท้าย/ผีตานี/หุ่นไล่กา) Clone ใส่ ViewportFrame แล้วพุ่งเข้าหาจอ
--   + เสียงหลอน + สีจอ + เอฟเฟกต์เฉพาะของผีแต่ละแบบ (เลือดหยด, ขาวดำ, ฟ้าแลบ ...)
-- เสียงทุกตัวอยู่ใน SoundGroup SFX (ปรับระดับได้จากหน้าตั้งค่า)

local ContentProvider = game:GetService("ContentProvider")
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
	Jumpscare_1 = "rbxassetid://105012119508747",
	Jumpscare_2 = "rbxassetid://86851276922466",
}

-- เอฟเฟกต์ของผีแต่ละแบบ
--   focus = แบบที่จะเอามาโชว์ ("head" หัวคนขับ, "passenger", "tani", "scarecrow", "body" ทั้งตัวคนขับ)
--   tint = สีจอ  extra = เอฟเฟกต์พิเศษ
local FX = {
	Anomaly_Headless = { focus = "passenger", tint = Color3.fromRGB(140, 0, 0), extra = "blood" },
	Anomaly_Cemetery = { focus = "head", tint = Color3.fromRGB(60, 60, 60), extra = "grey" },
	Anomaly_WheelHair = { focus = "head", tint = Color3.fromRGB(20, 10, 10), extra = "hair" },
	Anomaly_NeckTwist = { focus = "head", tint = Color3.fromRGB(110, 0, 0), spin = true },
	Anomaly_CreepySmile = { focus = "head", tint = Color3.fromRGB(90, 0, 20) },
	Anomaly_Krasue = { focus = "body", tint = Color3.fromRGB(170, 20, 0), extra = "blood" },
	Anomaly_MonkRadio = { focus = "head", tint = Color3.fromRGB(50, 50, 55), extra = "static" },
	-- ผีตานี / หุ่นไล่กา: ตัวจริงเป็น MeshPart ที่ ViewportFrame วาดไม่ขึ้น ใช้หน้าหลอนของลูกค้าแทน (เสียง/สีจอยังเป็นของตัวเอง)
	Anomaly_Tani = { focus = "head", tint = Color3.fromRGB(20, 80, 30) },
	Anomaly_Scarecrow = { focus = "head", tint = Color3.fromRGB(90, 40, 0) },
	-- ผีฉาก (client/SceneryGhostWatch: มองค้างนาน = พุ่งใส่หน้าคนที่มองคนเดียว)
	Scenery_Tani = { focus = "rigged", tint = Color3.fromRGB(20, 80, 30) },
	Scenery_Scarecrow = { focus = "scarecrow", tint = Color3.fromRGB(90, 40, 0) },
	Scenery_Shadow = { focus = "shadow", tint = Color3.fromRGB(10, 0, 0) },
	-- ผีฉากแบบมีกระดูก (AnomalyManager.RIGGED_SCENERY): ตัวผีที่โผล่อยู่ส่งมาเป็น source
	Scenery_Dancer = { focus = "rigged", tint = Color3.fromRGB(110, 10, 40) },
	Scenery_MaeNak = { focus = "rigged", tint = Color3.fromRGB(60, 20, 70) },
	Scenery_Kuman = { focus = "rigged", tint = Color3.fromRGB(150, 110, 0) },
	Scenery_Child = { focus = "rigged", tint = Color3.fromRGB(40, 50, 60) },
	Scenery_Shroud = { focus = "rigged", tint = Color3.fromRGB(120, 110, 70) },
	Scenery_Krasue = { focus = "rigged", tint = Color3.fromRGB(170, 20, 0) },
	Scenery_Pop = { focus = "rigged", tint = Color3.fromRGB(90, 0, 10) },
	Scenery_Pret = { focus = "rigged", tint = Color3.fromRGB(50, 40, 30) },
	Scenery_Krahang = { focus = "rigged", tint = Color3.fromRGB(80, 50, 10) },
	-- ผีใหญ่บุกประชิด (server/BigEvents): source = กลุ่มผีที่กำลังเดินอยู่
	Big_Krasue = { focus = "rigged", tint = Color3.fromRGB(170, 20, 0) },
	Big_Pret = { focus = "rigged", tint = Color3.fromRGB(50, 40, 30) },
	Big_Funeral = { focus = "rigged", tint = Color3.fromRGB(200, 200, 190), extra = "grey" },
	Big_Pop = { focus = "rigged", tint = Color3.fromRGB(90, 0, 10) },
	-- ผีเดินมาซื้อทั้งร่าง (source = ตัวผี) / เปิดแผงตอนผียังวนอยู่หน้าร้าน (source = กลุ่มผี GhostLinger)
	Anomaly_GhostWalkIn = { focus = "rigged", tint = Color3.fromRGB(120, 0, 20) },
	Linger_Scare = { focus = "rigged", tint = Color3.fromRGB(110, 0, 0) },
	Anomaly_TaKhon = { focus = "rider", tint = Color3.fromRGB(130, 0, 0) },
	Anomaly_MirrorGhost = { focus = "passenger", tint = Color3.fromRGB(40, 60, 70) },
	Anomaly_BloodFuel = { focus = "head", tint = Color3.fromRGB(150, 0, 0), extra = "blood" },
	Anomaly_NoUmbrella = { focus = "head", tint = Color3.fromRGB(200, 210, 255), extra = "lightning" },
}
local DEFAULT_FX = { focus = "head", tint = Color3.fromRGB(120, 0, 0) }

-- ---------------------------------------------------------------- เสียง
local SCARE_VOLUME = 7 -- เสียงผีหลอกที่เจ้าของเกมอัปโหลด (สูงสุด 10, กลุ่ม SFX ถูกหารครึ่งอยู่แล้ว)
local sfxGroup = SoundService:FindFirstChild("SFX")

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "Jumpscare"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- เต็มจอจริงถึงขอบ (มือถือมีติ่ง/ขอบโค้ง: ค่าเริ่มต้นถูกบีบไว้ใน safe area เหลือแถบเกินขอบ)
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
local function ghostModel(key: string?, focus: string, source: Instance?): (Model?, BasePart?, { Instance })
	local m = Instance.new("Model")
	local focusPart: BasePart? = nil
	local roots: { Instance } = {} -- ของจริงในฉากที่ถูก Clone มา (ตอนเผยร่างผีในฉาก: ซ่อนของจริงไว้)
	local function addClone(inst: Instance)
		table.insert(roots, inst)
		local c = inst:Clone()
		-- ชาวบ้านแบบใหม่ (กระดูก): ท่าที่กำลังเล่นอยู่ไม่ติดมากับ Clone -> คัดลอก Transform ของกระดูกทีละท่อน
		local srcList, dstList = inst:GetDescendants(), c:GetDescendants()
		if #srcList == #dstList then
			for i, sd in ipairs(srcList) do
				local dd = dstList[i]
				if sd:IsA("Bone") and dd:IsA("Bone") then
					dd.Transform = sd.Transform
				end
			end
		end
		-- ผีหันหัวกลับ: ใช้หัวที่หมุนแล้ว (TwistedHead) แทนหัวจริง
		local twisted = c:FindFirstChild("TwistedHead", true)
		if twisted and twisted.Parent then
			local orig = twisted.Parent:FindFirstChild("Head")
			if orig then
				orig:Destroy()
			end
			twisted.Name = "Head"
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			elseif d:HasTag("GhostOnly") or d:HasTag("NormalOnly") then
				-- ตอนผีหลอกเห็นร่างจริงเสมอ (ไม่ต้องพนมมือ): ของผีแสดง ของปกติที่ผีบังไว้ซ่อน
				local prop = d:GetAttribute("VeilProp")
				local value = if d:HasTag("GhostOnly") then d:GetAttribute("VeilShow") else d:GetAttribute("VeilHide")
				if type(prop) == "string" and value ~= nil then
					(d :: any)[prop] = value
				end
				d:RemoveTag("GhostOnly")
				d:RemoveTag("NormalOnly")
			end
		end
		c.Parent = m
		return c
	end
	-- rigged ghost (GhostNPC): skinned mesh parts are placed at the origin, so focus on an invisible marker at a bone
	local function boneFocus(c: Instance, boneName: string): BasePart?
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("Bone") and d.Name == boneName then
				local p = Instance.new("Part")
				p.Name = "FocusMarker"
				p.Size = Vector3.new(0.6, 0.6, 0.6)
				p.Transparency = 1
				p.Anchored = true
				p.CanCollide = false
				p.CanQuery = false
				p.CFrame = d.WorldCFrame
				p.Parent = c
				return p
			end
		end
		return nil
	end
	local anomalyProps = Workspace:FindFirstChild("AnomalyProps")
	if focus == "tani" and anomalyProps and anomalyProps:FindFirstChild("PhiTaniGhostModel") then
		local c = addClone(anomalyProps.PhiTaniGhostModel)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "RootPart" then
				d.Transparency = 0
			end
		end
		focusPart = boneFocus(c, "head")
	elseif focus == "tani" and anomalyProps and anomalyProps:FindFirstChild("PhiTaniGhost") then
		local c = addClone(anomalyProps.PhiTaniGhost)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 0
			end
		end
		focusPart = c:FindFirstChild("TaniHead", true) :: BasePart?
	elseif focus == "shadow" and anomalyProps and anomalyProps:FindFirstChild("BanyanShadowAnomaly") then
		local c = addClone(anomalyProps.BanyanShadowAnomaly)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = if string.find(d.Name, "Eye") then 0 else 0.05
			end
		end
		focusPart = c:FindFirstChild("ShadowHead", true) :: BasePart?
	elseif focus == "scarecrow" and anomalyProps and (anomalyProps:FindFirstChild("ScarecrowApparition") or anomalyProps:FindFirstChild("Scarecrow")) then
		local c = addClone(anomalyProps:FindFirstChild("ScarecrowApparition") or anomalyProps.Scarecrow)
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency > 0 and d.Transparency < 1 then
				d.Transparency = 0
			end
		end
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
	elseif focus == "rigged" and source then
		local c = addClone(source)
		if c:GetAttribute("GhostName") == "Pop" or c.Name == "Pop" then
			c:SetAttribute("GhostName", "Pop")
			c:SetAttribute("GhostClip", "PossessedSnap")
			c:SetAttribute("GhostClipT0", Workspace:GetServerTimeNow())
		elseif not c:GetAttribute("GhostClip") and source:GetAttribute("GhostClip") then
			c:SetAttribute("GhostClip", source:GetAttribute("GhostClip"))
			c:SetAttribute("GhostClipT0", Workspace:GetServerTimeNow())
		end
		local boneName = source:GetAttribute("FocusBone")
		focusPart = boneFocus(c, if type(boneName) == "string" then boneName else "head")
	elseif source then
		-- กระสือ (ชาวบ้าน): ร่างผีคือ KrasueModel ในรถ ส่วนคนขับเป็น NormalOnly (ถูกซ่อนใน Clone)
		-- เดิม Clone คนขับ -> ตอนหลอกเห็นแต่ตัวล่องหน หน้าหาย (ผู้ใช้ 2026-11-08)
		if focus == "body" and source:FindFirstChild("KrasueModel") then
			local c = addClone(source.KrasueModel)
			local boneName = source.KrasueModel:GetAttribute("FocusBone")
			-- กระดูกหัวของแม่แบบกระสือชื่อ "Head" (ตัวใหญ่) ไม่ใช่ "head" แบบชาวบ้าน
			focusPart = boneFocus(c, if type(boneName) == "string" then boneName else "Head") or boneFocus(c, "head")
		elseif focus == "rider" and source:FindFirstChild("GhostRiderModel") then
			local c = addClone(source.GhostRiderModel)
			focusPart = boneFocus(c, "head")
		elseif focus == "passenger" and source:FindFirstChild("GhostPassengerModel") then
			local c = addClone(source.GhostPassengerModel)
			focusPart = boneFocus(c, "neck")
		elseif focus == "passenger" and source:FindFirstChild("GhostPassenger") then
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
		return nil, nil, roots
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return m, focusPart, roots
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
-- ผีหลอกทุกแบบใช้เสียงที่เจ้าของเกมอัปโหลดเท่านั้น (ผู้ใช้ 2026-11-05) · โหลดไฟล์ไว้ตั้งแต่เข้าเกม เสียงจึงมาพร้อมภาพ
-- สุ่มจากไฟล์ที่โหลดสำเร็จ ไฟล์ที่ Roblox ยังไม่อนุมัติจะถูกข้ามไปเอง · ยังโหลดไม่เสร็จเลย = สั่งเล่น Jumpscare_1
local scareSounds: { Sound } = {}
for _, key in ipairs({ "Jumpscare_1", "Jumpscare_2" }) do
	local s = Instance.new("Sound")
	s.Name = "Scare" .. key
	s.SoundId = SND[key]
	s.Volume = SCARE_VOLUME
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		s.SoundGroup = sfxGroup
	end
	s.Parent = SoundService
	table.insert(scareSounds, s)
end
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(scareSounds)
	end)
end)
local function playScareSound()
	local ready = {}
	for _, s in ipairs(scareSounds) do
		if s.IsLoaded then
			table.insert(ready, s)
		end
	end
	if #ready == 0 then
		scareSounds[1]:Play()
		return
	end
	ready[math.random(#ready)]:Play()
end

-- จอผีหลอกเต็มจอ (รวมไม่เกิน 2 วินาที: พุ่งเข้า 0.18 + ค้าง ~1.0 + จางออก 0.55)
--   opts.side = -1/1 โผล่จากด้านซ้าย/ขวาของจอ (ผีวูบหลบไปด้านข้างก่อน) · opts.instant = โผล่ประชิดทันที ไม่พุ่ง (ผีหายวับแล้วกลับมา)
local DASH = 0.18
local HOLD = 1.0
local FADE_OUT = 0.55
local function showScare(key: string?, source: Instance?, opts: { side: number?, instant: boolean? }?)
	local fx = (key and FX[key]) or DEFAULT_FX
	local side = (opts and opts.side) or 0
	local instant = (opts and opts.instant) == true
	playScareSound()

	local model, focus = ghostModel(key, fx.focus, source)
	-- ผีทั้งตัวสีทึบ (หุ่นไล่กา/ตานี) ต้องสว่างกว่าหน้าคนนิดหน่อย ไม่งั้นจมหายในจอมืด
	vp.Ambient = if fx.focus == "scarecrow" or fx.focus == "tani" or fx.focus == "shadow" then Color3.fromRGB(175, 165, 160) else Color3.fromRGB(135, 125, 125)
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
	tintFrame.BackgroundTransparency = 0.6
	vp.ImageTransparency = 0
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
	if instant then
		-- โผล่ประชิดทันที: แฟลชขาววูบเดียว
		tintFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		tintFrame.BackgroundTransparency = 0.2
		TweenService:Create(tintFrame, TweenInfo.new(0.25), { BackgroundTransparency = 0.6, BackgroundColor3 = fx.tint }):Play()
	end

	-- กล้องใน Viewport: เริ่มไกล (หรือจากด้านข้าง) แล้วเข้ามาหยุดที่ระยะเห็นหน้า+ไหล่ชัดๆ (หน้า = -Z ของชิ้นโฟกัส)
	local conn: RBXScriptConnection? = nil
	if focus then
		local target = focus.Position
		local front = focus.CFrame.LookVector
		local size = math.max(focus.Size.X, focus.Size.Y, focus.Size.Z)
		-- ผีทั้งตัว (หุ่นไล่กา / ผีตานี): จัดเฟรมจากกรอบทั้งตัว เล็งช่วงหัว (บน 1/3) หน้า = ทิศหน้าของโมเดล
		if model and (fx.focus == "scarecrow" or fx.focus == "tani" or fx.focus == "shadow") then
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
		local right = front:Cross(up)
		if right.Magnitude < 0.01 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end
		-- หยุดห่างพอเห็นหน้าทั้งหน้า + ไหล่ (เดิม 1.05 ใกล้จนเห็นแค่จมูก/ตา)
		local far, near = size * 9, size * 2.1
		local t0 = os.clock()
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local k = if instant then 1 else math.clamp(t / DASH, 0, 1)
			local ease = 1 - (1 - k) * (1 - k)
			local dist = if side ~= 0 then near else far + (near - far) * (k * k)
			-- โผล่จากด้านข้าง: เลื่อนกล้องเข้าจากฝั่งนั้น
			local lateral = if side ~= 0 then right * (-side) * size * 5 * (1 - ease) else Vector3.zero
			-- สั่นเบาๆ หลังเข้าถึงหน้า (สั่นแรงเกินไปจะมองหน้าผีไม่ชัด)
			local shake = if k >= 1 and t < 0.6 then Vector3.new(math.random(-4, 4), math.random(-4, 4), 0) / 100 * size else Vector3.zero
			local camPos = target + front * dist + lateral + shake
			vpCam.CFrame = CFrame.lookAt(camPos, target + shake * 0.5 + lateral * 0.3)
			if fx.spin and model then
				-- หันหัวกลับมาทางเราแบบกระตุก
				local ang = math.rad(math.clamp((t - 0.15) / 0.22, 0, 1) * 180)
				focus.CFrame = CFrame.new(target) * (focus.CFrame - focus.Position) * CFrame.Angles(0, ang - (focus:GetAttribute("Spun") or 0), 0)
				focus:SetAttribute("Spun", ang)
			end
			-- กะพริบช่วงท้าย
			vp.ImageTransparency = if t > 0.8 and math.random() < 0.2 then 0.6 else 0
		end)
	end

	-- สั่นกล้องจริงด้วย
	local cam = Workspace.CurrentCamera
	task.spawn(function()
		for _ = 1, 10 do
			if cam then
				cam.CFrame *= CFrame.Angles(math.rad(math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
			end
			task.wait(0.03)
		end
	end)

	task.wait(gui:GetAttribute("DebugHold") or (DASH + HOLD)) -- (ทดสอบ: ตั้ง Attribute DebugHold ให้ค้างนานขึ้น)
	-- จางออก
	TweenService:Create(bg, TweenInfo.new(FADE_OUT), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(vp, TweenInfo.new(FADE_OUT * 0.7), { ImageTransparency = 1 }):Play()
	TweenService:Create(tintFrame, TweenInfo.new(FADE_OUT), { BackgroundTransparency = 1 }):Play()
	for _, d in ipairs(drips:GetChildren()) do
		if d:IsA("Frame") then
			TweenService:Create(d, TweenInfo.new(FADE_OUT), { BackgroundTransparency = 1 }):Play()
		end
	end
	task.wait(FADE_OUT)
	if conn then
		conn:Disconnect()
	end
	grey.Enabled = false
	gui.Enabled = false
	vp.ImageTransparency = 0
	clearViewport()
	drips:ClearAllChildren()
end

-- ---------------------------------------------------------------- เติมน้ำมันให้ผีเสร็จ: เผยร่างผีในฉากก่อนหลอก
-- server สุ่มท่า (ทุกคนเห็นเหมือนกัน) plan = { style, reveal, pause, side }
--   "lunge"  เผยร่างแล้วพุ่งเข้าหาเราตรงๆ
--   "side"   เผยร่างแล้ววูบหลบไปด้านซ้าย/ขวา หายไปแป๊บ แล้วโผล่จากด้านนั้น
--   "vanish" เผยร่างแล้วหายวับ เงียบไปพักหนึ่ง แล้วโผล่ประชิดหน้าทันที
local revealGrade = Instance.new("ColorCorrectionEffect")
revealGrade.Name = "GhostReveal"
revealGrade.Enabled = false
revealGrade.Parent = Lighting

-- ท่าตอนผีวิ่งหนี / พุ่งเข้าหา (ไม่ใช่ค้างท่าขี่มอไซ): เลือกจากชุดท่าของตัวนั้น
--   ชาวบ้าน (attribute Char): วิ่ง (ผ้านุ่งยาว = วิ่งก้าวสั้น) · พุ่งเข้าหา = ลอยร่อนแบบผี (ghost_glide)
--   ผีมีกระดูก (attribute GhostName): ท่าเคลื่อนที่ที่มี เช่น กระสือ Float/Lunge, กระหัง FlapFly, ปอบ TwitchWalk, เปรต TallSlowWalk
--   ท่าลอย (FLOAT_CLIPS) = ลอยอยู่ระดับเดิม / นอกนั้นลงมายืนบนพื้นก่อนวิ่ง
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HumanAnimIds = require(Shared:WaitForChild("HumanAnimIds")) :: any
local GhostAnimIds = require(Shared:WaitForChild("GhostAnimIds")) :: any
local SKIRT_OUTFITS = { sarong = true, blouse_sin = true, indigo_scarf = true, sabai = true }
local FLOAT_CLIPS = { Float = true, FlapFly = true, Glide = true, shroud_glide = true, Lunge = true }
local GHOST_MOVE_SIDE = { "run", "TwitchWalk", "ghost_glide", "Float", "FlapFly", "Glide", "shroud_glide", "coffin_walk", "TallSlowWalk" }
local GHOST_MOVE_LUNGE = { "Lunge", "ghost_glide", "run", "Float", "FlapFly", "Glide", "shroud_glide", "TwitchWalk", "coffin_walk", "TallSlowWalk" }

-- ผีโครงกระดูกคน (ghost_* 52 ท่อน ชุดเดียวกับชาวบ้าน) ที่ไม่มีท่าวิ่งของตัวเอง: ยืมท่าวิ่งของชาวบ้านที่ตัวเท่ากัน
local GHOST_CHAR: { [string]: string } = {
	ghost_funeral_woman = "human_female",
	ghost_mirror = "human_female",
	ghost_tani = "human_female",
	ghost_mae_nak = "human_female",
	ghost_dancer = "human_female",
	ghost_headless = "human_female",
	ghost_funeral_elder_man = "human_elder_male",
	ghost_funeral_elder_woman = "human_elder_female",
	ghost_child = "human_child",
	ghost_kuman_thong = "human_child",
}
local function humanRun(char: string, skirt: boolean): string?
	local set = HumanAnimIds[char] or HumanAnimIds.human_base
	local clip = if skirt then "run_skirt" else "run"
	return set[clip] or HumanAnimIds.human_base[clip]
end

-- Char / Outfit ของตัวนี้ หรือของชาวบ้านที่ร่างผีนี้ซ้อนอยู่ (GhostDouble อยู่ใน DriverNPC)
local function charOf(rig: Instance, top: Instance): (string?, string?)
	local a: Instance? = rig
	while a and a ~= top.Parent do
		local c = a:GetAttribute("Char")
		if type(c) == "string" then
			return c, a:GetAttribute("Outfit") :: any
		end
		a = a.Parent
	end
	return nil, nil
end

type Mover = { rig: Model, track: AnimationTrack?, floats: boolean }
local function prepareMove(model: Model, style: string): { Mover }
	local list: { Mover } = {}
	for _, rig in ipairs(model:GetDescendants()) do
		if not rig:IsA("Model") then
			continue
		end
		local ac = rig:FindFirstChildOfClass("AnimationController")
		if not ac then
			continue -- ชิ้นส่วน/อุปกรณ์ที่ไม่ใช่ตัวละคร
		end
		local id: string? = nil
		local floats = false
		local char, outfit = charOf(rig, model)
		local gname = rig:GetAttribute("GhostName")
		local skirt = SKIRT_OUTFITS[outfit :: any] == true
		if type(gname) == "string" and GhostAnimIds[gname] then
			local set = GhostAnimIds[gname]
			for _, c in ipairs(if style == "lunge" then GHOST_MOVE_LUNGE else GHOST_MOVE_SIDE) do
				if set[c] then
					id = set[c]
					floats = FLOAT_CLIPS[c] == true
					rig:SetAttribute("GhostClip", c)
					rig:SetAttribute("GhostClipT0", Workspace:GetServerTimeNow())
					break
				end
			end
			-- หนีออกไปด้านข้าง (ผู้ใช้ 2026-11-06): ผีร่างคนต้องวิ่งออกไปเท่านั้น ไม่ร่อน/ไถลไปเฉยๆ (ผีลอยอย่างกระสือยังลอย)
			if style == "side" and not floats and not set.run and string.sub(gname, 1, 6) == "ghost_" then
				id = humanRun(GHOST_CHAR[gname] or "human_base", false) or id
			end
		elseif char then
			-- ชาวบ้าน และร่างผีที่ซ้อนตัวชาวบ้าน (GhostDouble): วิ่ง (ผ้านุ่งยาว = วิ่งก้าวสั้น) · พุ่งเข้าหา = ร่อนแบบผี
			if style == "lunge" then
				local set = HumanAnimIds[char] or HumanAnimIds.human_base
				id = set.ghost_glide or HumanAnimIds.human_base.ghost_glide
			else
				id = humanRun(char, skirt)
			end
		else
			continue
		end
		-- ปล่อยมือ/เท้าที่จับแฮนด์ พวงมาลัย ที่พักเท้า (IK) ไม่งั้นวิ่งทั้งที่แขนยังกางจับแฮนด์
		for _, ik in ipairs(ac:GetChildren()) do
			if ik:IsA("IKControl") then
				ik.Enabled = false
			end
		end
		local an = ac:FindFirstChildOfClass("Animator") or rig:FindFirstChildWhichIsA("Animator", true)
		local track: AnimationTrack? = nil
		if id and an then
			local a = Instance.new("Animation")
			a.AnimationId = id
			local ok, tr = pcall(function()
				return (an :: Animator):LoadAnimation(a)
			end)
			if ok and tr then
				tr.Looped = true
				track = tr
			end
		end
		table.insert(list, { rig = rig, track = track, floats = floats })
	end
	return list
end

-- ลงจากรถมายืนบนพื้น หันไปทาง dir แล้วเริ่มท่า (ท่าโหลดไว้ตั้งแต่เริ่มเผยร่าง)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function startMove(movers: { Mover }, dir: Vector3, speed: number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	for _, mv in ipairs(movers) do
		local p = mv.rig:GetPivot().Position
		local y = p.Y
		if not mv.floats then
			local hit = Workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), groundParams)
			if hit then
				y = hit.Position.Y
			end
		end
		mv.rig:PivotTo(CFrame.lookAt(Vector3.new(p.X, y, p.Z), Vector3.new(p.X, y, p.Z) + flat))
		if mv.track then
			mv.track:Play(0.1, 1, speed)
		end
	end
end

local function revealGhost(key: string?, source: Instance?, plan: { [string]: any }): { side: number?, instant: boolean? }
	local fx = (key and FX[key]) or DEFAULT_FX
	local style = if type(plan.style) == "string" then plan.style else "lunge"
	local reveal = if type(plan.reveal) == "number" then plan.reveal else 1.3
	local pause = if type(plan.pause) == "number" then plan.pause else 0.25
	local side = if plan.side == -1 then -1 else 1
	local opts = { side = if style == "side" then side else 0, instant = style == "vanish" }
	local cam = Workspace.CurrentCamera
	local model, focus, roots = nil, nil, {}
	if source and source:IsDescendantOf(Workspace) then
		model, focus, roots = ghostModel(key, fx.focus, source)
	end
	if not (model and focus and cam) then
		if model then
			model:Destroy()
		end
		task.wait(reveal + pause)
		return opts
	end

	-- ร่างผี (Clone) ซ้อนทับของจริง: ค่อยๆ ชัดขึ้น ส่วนของจริง (หน้าคนปกติ) ค่อยๆ จางไป
	local fade: { { any } } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(fade, { d, d.Transparency })
			d.Transparency = 1
		end
	end
	local hidden: { any } = {}
	for _, r in ipairs(roots) do
		local list = r:GetDescendants()
		table.insert(list, r)
		for _, d in ipairs(list) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				table.insert(hidden, d)
			end
		end
	end
	model.Name = "GhostReveal"
	model.Parent = Workspace
	-- โหลดท่าวิ่ง/ลอยไว้ตั้งแต่เริ่มเผยร่าง (1.3 วิ) ถึงตอนขยับท่าพร้อมเล่นทันที
	local movers = if style ~= "vanish" then prepareMove(model, style) else {}

	local function setAlpha(a: number)
		for _, f in ipairs(fade) do
			f[1].Transparency = 1 + (f[2] - 1) * a
		end
	end
	local function hideReal(a: number)
		for _, d in ipairs(hidden) do
			if d.Parent then
				d.LocalTransparencyModifier = a
			end
		end
	end

	revealGrade.Enabled = true
	revealGrade.Brightness = 0
	revealGrade.Saturation = 0
	revealGrade.Contrast = 0
	local t0 = os.clock()
	while true do
		local a = math.clamp((os.clock() - t0) / reveal, 0, 1)
		local e = a * a * (3 - 2 * a)
		-- ครึ่งหลังกะพริบวูบวาบเล็กน้อย (ร่างผีไม่นิ่ง)
		local flick = if a > 0.45 and a < 1 and math.random() < 0.18 then 0.35 else 0
		setAlpha(math.max(0, e - flick))
		hideReal(e)
		revealGrade.Brightness = -0.12 * e
		revealGrade.Saturation = -0.45 * e
		revealGrade.Contrast = 0.15 * e
		if a >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
	setAlpha(1)

	local camPos = cam.CFrame.Position
	if style == "lunge" then
		startMove(movers, camPos - focus.Position, 1.4)
	elseif style == "side" then
		startMove(movers, cam.CFrame.RightVector * side, 1.2)
	end
	local start = model:GetPivot()
	if style == "lunge" then
		-- พุ่งเข้าหากล้อง (หยุดห่างราว 3 studs แล้วตัดเข้าจอผีหลอก)
		local toCam = camPos - focus.Position
		local travel = toCam * math.max(0, 1 - 3 / math.max(toCam.Magnitude, 3))
		local t1 = os.clock()
		while true do
			local k = math.clamp((os.clock() - t1) / pause, 0, 1)
			model:PivotTo(start + travel * (k * (0.6 + 0.4 * k)))
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	elseif style == "side" then
		-- วูบหลบไปด้านข้าง (ซ้าย/ขวาของจอเรา) แล้วจางหาย รอแป๊บ ค่อยโผล่จากด้านนั้น
		local dir = cam.CFrame.RightVector * side
		dir = Vector3.new(dir.X, 0, dir.Z)
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
		-- วิ่งออกไปให้เห็นท่าวิ่งเต็มๆ เกือบตลอดช่วง pause (เดิม 0.6 วิ แทบไม่ทันเห็นท่า)
		local dash = math.max(0.3, pause * 0.9)
		local t1 = os.clock()
		while true do
			local k = math.clamp((os.clock() - t1) / dash, 0, 1)
			model:PivotTo(start + dir * 11 * k)
			-- วิ่งออกไปเห็นชัดก่อน แล้วค่อยจางช่วงท้าย
			setAlpha(1 - math.max(0, k - 0.7) / 0.3)
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		setAlpha(0)
		task.wait(math.max(0, pause - dash))
	else
		-- หายวับ: เงียบ มืดลงนิดหนึ่ง แล้วโผล่ประชิด
		setAlpha(0)
		TweenService:Create(revealGrade, TweenInfo.new(0.3), { Brightness = -0.3 }):Play()
		task.wait(pause)
	end

	model:Destroy()
	TweenService:Create(revealGrade, TweenInfo.new(0.6), { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
	task.delay(0.7, function()
		revealGrade.Enabled = false
	end)
	-- ของจริงซ่อนไว้ต่อ (server ค่อยๆ ลบผี+รถทิ้งหลังหลอก) ถ้ายังอยู่อีกนานค่อยคืน
	task.delay(5, function()
		hideReal(0)
	end)
	return opts
end

-- ---------------------------------------------------------------- หัวเราะสะใจหลังหลอกได้ (ผู้ใช้ 2026-11-06)
-- เสียงหัวเราะของผีตัวที่หลอก (SoundBank.GhostSounds) ดังข้างหูหลังภาพผีจางออก ไม่รู้ตัวไหน = สุ่ม
local SoundBank = require(Shared:WaitForChild("SoundBank")) :: any
local LAUGH_BY_KEY: { [string]: string } = {
	Anomaly_Krasue = "Krasue",
	Anomaly_Headless = "Headless",
	Anomaly_MirrorGhost = "Mirror",
	Anomaly_Tani = "Tani",
	Big_Funeral = "FuneralMan",
	Scenery_Child = "Mirror",
	Scenery_Shroud = "FuneralWoman",
}
local LINGER_LAUGH = { knock = "Pop", circle = "Kuman", roof = "Krahang" }
local function laughFor(key: string?, source: Instance?): string?
	local name: string? = nil
	if key then
		name = LAUGH_BY_KEY[key] or string.match(key, "^Scenery_(%w+)$") or string.match(key, "^Big_(%w+)$")
	end
	if key == "Linger_Scare" and source then
		name = LINGER_LAUGH[source:GetAttribute("Behavior") :: any]
	end
	local set = name and SoundBank.GhostSounds[name]
	if set then
		return set.laugh
	end
	local all = {}
	for _, s in pairs(SoundBank.GhostSounds) do
		table.insert(all, s.laugh)
	end
	return if #all > 0 then all[math.random(#all)] else nil
end
local function laughAfterScare(key: string?, source: Instance?)
	local preset = laughFor(key, source)
	if not preset then
		return
	end
	local snd = SoundBank.CreateSound(preset, SoundService)
	if not snd then
		return
	end
	if sfxGroup and sfxGroup:IsA("SoundGroup") then
		snd.SoundGroup = sfxGroup
	end
	snd.Volume *= 1.6
	snd:Play()
	task.delay(7, function()
		snd:Destroy()
	end)
end

local busy = false
local function runScare(key: string?, source: Instance?, reason: string?, plan: any?)
	if busy then
		return
	end
	-- คัทซีนกำลังเล่น: ห้ามผีหลอก (ผู้ใช้ 2026-11-05)
	if ReplicatedStorage:GetAttribute("CutsceneRunning") == true or Lighting:GetAttribute("Cutscene") == true then
		return
	end
	busy = true
	local ok, err = pcall(function()
		local opts = nil
		if reason == "fueled" and type(plan) == "table" then
			opts = revealGhost(key, source, plan)
		end
		local laughSource = source
		showScare(key, source, opts)
		task.delay(0.15, laughAfterScare, key, laughSource)
	end)
	if not ok then
		warn("[Jumpscare] " .. tostring(err))
		gui.Enabled = false
		grey.Enabled = false
		revealGrade.Enabled = false
	end
	busy = false
end
TriggerJumpscare.OnClientEvent:Connect(function(key: string?, source: Instance?, reason: string?, plan: any?)
	runScare(key, source, reason, plan)
end)
-- ผีหลอกเฉพาะเครื่องนี้ (ผีฉาก: client/SceneryGhostWatch) ไม่ผ่านเซิร์ฟเวอร์ คนอื่นไม่เห็น
_G.LocalJumpscare = function(key: string, source: Instance?)
	task.spawn(runScare, key, source)
end
