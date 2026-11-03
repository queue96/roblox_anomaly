--!strict
-- Animate.client.luau (StarterCharacterScripts: แทนสคริปต์ท่าทางมาตรฐานของ Roblox)
-- ท่าของตัวผู้เล่นชาวบ้าน (server/PlayerVillager.server.luau) จาก ReplicatedStorage.Shared.HumanAnimIds
--   ท่าหลัก: idle / walk / fall / sit ตามสถานะ Humanoid
--   ท่าซ้อน (ขยับแค่แขน/ตัวบน): ถือไฟฉาย (มือซ้าย), พนมมือ (มือว่าง)
--     (เติมน้ำมัน / เติมลม / ดึงเชือก / สตาร์ทเครื่องปั่นไฟ: เล่นแค่มินิเกม ไม่มีท่าของตัวละคร)
--   มุมมองบุคคลที่หนึ่ง: ก้มแล้วเห็นตัว แขน ขา ของตัวเอง (Roblox ซ่อนตัวเองให้ ต้องเปิดกลับทุกเฟรม)
--     หัวของตัวเอง (BodyHead) ผม หมวก ซ่อนบนจอเราเอง (คนอื่นยังเห็น) ไม่มีจมูกหรือผมบังกล้อง
-- ตัวที่ไม่ใช่ชาวบ้าน (ไม่มี RootPart) = ไม่ทำอะไร
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent :: Model
local hum = char:WaitForChild("Humanoid") :: Humanoid
-- ชิ้นของตัวละครอาจยังมาไม่ครบตอนสคริปต์เริ่ม (StreamingEnabled): รอ RootPart สักครู่ก่อนตัดสินว่าไม่ใช่ชาวบ้าน
if not char:WaitForChild("RootPart", 8) then
	return
end
local animator = hum:WaitForChild("Animator") :: Animator

-- กล้องระดับตา (AmbienceController บวกค่านี้เข้า CameraOffset)
-- วัดในเกม: y +1.05 = ระดับตา. หัวของตัวเอง (ชิ้น BodyHead) ซ่อนบนจอเราเอง กล้องจึงอยู่ที่ตาได้โดยไม่เห็นจมูก
-- (ไฟล์เก่าที่ยังไม่มีชิ้น BodyHead: ดันกล้องไปหน้าปลายจมูกแทน)
local hasHead = char:WaitForChild("BodyHead", 3) ~= nil
local EYE = if hasHead then Vector3.new(0, 1.05, -0.62) else Vector3.new(0, 1.05, -0.75)
local EYE_PRAY = if hasHead then Vector3.new(0, 1.0, -0.7) else Vector3.new(0, 0.9, -1.15)
hum:SetAttribute("EyeOffset", EYE)

local ids = (require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HumanAnimIds")) :: any).human_base or {}
local WALK_CLIP_SPEED = 4.3

local tracks: { [string]: AnimationTrack } = {}
local function track(name: string, priority: Enum.AnimationPriority?): AnimationTrack?
	if tracks[name] == nil then
		local id = ids[name]
		if not id then
			return nil
		end
		local a = Instance.new("Animation")
		a.AnimationId = id
		local t = animator:LoadAnimation(a)
		t.Looped = true
		if priority then
			t.Priority = priority
		end
		tracks[name] = t
	end
	return tracks[name]
end
-- โหลดล่วงหน้า (ท่าที่ยังโหลดไม่เสร็จเล่นไม่ออก ตัวจะเป็นท่า A แวบหนึ่ง)
for _, n in ipairs({ "idle", "walk", "fall", "sit", "ride_moto", "pull_rope" }) do
	track(n, Enum.AnimationPriority.Core)
end
for _, n in ipairs({ "hold_flashlight", "pray" }) do
	track(n, Enum.AnimationPriority.Action)
end

-- ---------------------------------------------------------------- ท่าหลัก
local base: string? = nil
-- หันตัวอยู่กับที่: ท่าเดินเบาๆ ซ้อนท่ายืน (Core เท่ากัน Roblox ผสมตามน้ำหนัก) = ก้าวสั้นๆ ไม่ใช่ก้าวเต็มท่า
local TURN_WEIGHT = 0.4
local turnStep = false
local function setTurnStep(on: boolean)
	if on == turnStep then
		return
	end
	local w = tracks.walk
	if not w or w.Length == 0 then
		return
	end
	turnStep = on
	if on then
		w:Play(0.25, TURN_WEIGHT, 0.9)
	else
		w:Stop(0.25)
	end
end
local function setBase(name: string, speed: number?)
	local t = track(name, Enum.AnimationPriority.Core)
	if not t then
		return
	end
	if base == name then
		if speed then
			t:AdjustSpeed(speed)
		end
		return
	end
	if t.Length == 0 then
		return -- ยังโหลดไม่เสร็จ: เล่นท่าเดิมต่อไปก่อน
	end
	if turnStep then
		turnStep = false -- ท่าเดินซ้อนตอนหันถูกแทนด้วยท่าใหม่ (หรือเดินจริงเต็มน้ำหนัก)
		if tracks.walk and name ~= "walk" then
			tracks.walk:Stop(0.2)
		end
	end
	t:Play(0.2, 1, speed or 1)
	if base and tracks[base] and base ~= name then
		tracks[base]:Stop(0.2)
	end
	base = name
end

local speedNow = 0
hum.Running:Connect(function(s)
	speedNow = s
end)

-- ---------------------------------------------------------------- ท่าซ้อน
local overlayOn: { [string]: boolean } = {}
local function setOverlay(name: string, on: boolean)
	if (overlayOn[name] or false) == on then
		return
	end
	local t = track(name, Enum.AnimationPriority.Action)
	if not t then
		return
	end
	overlayOn[name] = on
	if on then
		-- เต็มท่าทุกท่า: ถือไฟฉายเคยเล่นครึ่งท่า (0.55) นิ้วจึงงอไม่ถึงกระบอก จมหายเข้าไปในไฟฉาย มือหายจากจอ
		-- (แขนชี้ตามสายตาด้วย shared/HeadTurn อยู่แล้ว ไม่ต้องลดท่าเพื่อเลี่ยงบังจอ)
		t:Play(0.25, 1)
	else
		t:Stop(0.25)
	end
end

-- ---------------------------------------------------------------- มุมมองบุคคลที่หนึ่ง: เห็นตัวเอง
local HIDE_IN_FPP = { "Hair_", "_helmet", "_visor", "_ngob" }
local function hiddenInFpp(n: string): boolean
	for _, k in ipairs(HIDE_IN_FPP) do
		if string.find(n, k, 1, true) then
			return true
		end
	end
	return n == "Head" or n == "BodyHead" or n == "HumanoidRootPart" or n == "RootPart"
end
local bodyParts: { BasePart } = {}
for _, d in ipairs(char:GetDescendants()) do
	if d:IsA("BasePart") then
		table.insert(bodyParts, d)
	end
end
char.DescendantAdded:Connect(function(d)
	if d:IsA("BasePart") then
		table.insert(bodyParts, d)
	end
end)

-- ก้มได้ไม่เกิน 65°: ก้มลึกกว่านี้กล้องมองทะลุเข้าไปในตัวเอง (ผิวมีด้านเดียว มองจากข้างในจะหายไป)
local MAX_DOWN = math.rad(-65)
RunService:BindToRenderStep("VillagerPitchLimit", Enum.RenderPriority.Camera.Value + 1, function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cf = cam.CFrame
	local pitch, yaw = cf:ToOrientation()
	if pitch < MAX_DOWN then
		cam.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(MAX_DOWN, yaw, 0)
	end
end)

-- ---------------------------------------------------------------- มองตามกล้อง: หัว ลำตัว แขนไฟฉาย
-- ซ้าย/ขวา: 45° แรกหันแค่หัว ตัวไม่หมุน. เกินนั้นตัวหมุนตามแค่พอให้หัวหันค้างไว้ที่ 45° (ก้าวสั้นๆ ตามด้านล่าง)
--   เดินอยู่: ตัวหันตามกล้องเหมือนเดิม
-- ก้ม/เงย: ลำตัวเอนตามส่วนหนึ่ง คอ+หัวรับที่เหลือ. ถือไฟฉาย: แขนซ้ายชี้ไปทางที่มอง (shared/HeadTurn)
-- ปิด AutoRotate ของ Humanoid แล้วหมุนตัวเอง. ล้ม (ยึดตัวไว้ / WalkSpeed 0) หรือนั่ง: ไม่ยุ่ง
-- มุมส่งให้เซิร์ฟเวอร์ (Remotes.HeadTurn) -> attribute "HeadYaw"/"HeadPitch" ของตัวละคร -> คนอื่นเห็นด้วย
local HeadTurn = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HeadTurn")) :: any
local HEAD_LIMIT: number = HeadTurn.LIMIT
-- จุดที่กล้องบุคคลที่หนึ่งยึด (ก่อนบวก CameraOffset) ในกรอบของ HumanoidRootPart: วัดในเกม
local CAM_SUBJECT = Vector3.new(0, 1.5, 0)
local headYaw = 0
local headPitch = 0
local armAim = 0
local sentYaw, sentPitch = 0, 0
local sentAt = 0
local headRemote: RemoteEvent? = nil
local headBefore: CFrame? = nil
local headAfter: CFrame? = nil
local function wrapAngle(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end
RunService:BindToRenderStep("VillagerBodyYaw", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local cam = workspace.CurrentCamera
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (cam and root) then
		return
	end
	local free = not root.Anchored and hum.WalkSpeed > 0 and not hum.Sit and hum.Health > 0
	-- คัทซีน (CutsceneController ตั้ง Lighting.Cutscene): กล้องอยู่ไกลตัว -> CutsceneController หมุนตัวไปทางที่เดินเอง
	-- (ปิด AutoRotate: RotationType ของผู้เล่นเป็น CameraRelative ถ้าเปิด ตัวจะหันตามกล้องคัทซีน เดินเฉียงข้าง)
	local cutscene = game:GetService("Lighting"):GetAttribute("Cutscene") == true
	if cutscene and hum.AutoRotate then
		hum.AutoRotate = false
	end
	if not free or cutscene then
		headYaw, headPitch = 0, 0
		return
	end
	if hum.AutoRotate then
		hum.AutoRotate = false
	end
	local camPitch, camYaw = cam.CFrame:ToOrientation()
	local _, bodyYaw = root.CFrame:ToOrientation()
	local diff = wrapAngle(camYaw - bodyYaw)
	local target = bodyYaw
	if hum.MoveDirection.Magnitude > 0.1 then
		target = bodyYaw + diff * math.min(1, dt * 12) -- เดิน: ตัวหันตามกล้องเร็วๆ
	elseif math.abs(diff) > HEAD_LIMIT then
		target = camYaw - math.sign(diff) * HEAD_LIMIT
	end
	if target ~= bodyYaw then
		root.CFrame = CFrame.new(root.Position) * CFrame.fromOrientation(0, target, 0)
	end
	headYaw = math.clamp(wrapAngle(camYaw - target), -HEAD_LIMIT, HEAD_LIMIT)
	headPitch = math.clamp(camPitch, math.rad(-65), math.rad(70))
	-- แขนไฟฉายชี้ตามสายตา: ค่อยๆ เข้า/ออกตามท่าถือไฟฉาย
	local wantAim = if overlayOn.hold_flashlight then 1 else 0
	armAim += (wantAim - armAim) * math.min(1, dt * 8)
	if not headRemote then
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		headRemote = remotes and remotes:FindFirstChild("HeadTurn") :: RemoteEvent?
	end
	if
		headRemote
		and os.clock() - sentAt > 0.1
		and (math.abs(headYaw - sentYaw) > math.rad(2) or math.abs(headPitch - sentPitch) > math.rad(2))
	then
		sentAt = os.clock()
		sentYaw, sentPitch = headYaw, headPitch
		headRemote:FireServer(headYaw, headPitch)
	end
end)
-- หลังท่าทางคำนวณเสร็จ (ก่อนฟิสิกส์/วาด): หมุนลำตัว คอ หัว แขน
RunService.PreSimulation:Connect(function()
	headBefore, headAfter = HeadTurn.apply(char, headYaw, headPitch, armAim)
end)
-- ตำแหน่งตา (CameraOffset ในกรอบของตัว) ให้ตามหัวที่หัน/เอนจริง: ตาติดอยู่กับหัว ไม่ค้างอยู่ที่เดิม
-- (ไม่งั้นหันข้างแล้วกล้องค้างหน้าอก เห็นไหล่ตัวเอง / ก้มแล้วตัวเอนเข้ามาทับกล้อง)
local function eyeFollowHead(eye: Vector3): Vector3
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (root and headBefore and headAfter) then
		return eye
	end
	local rcf = root.CFrame
	local hb = rcf:ToObjectSpace(headBefore)
	local ha = rcf:ToObjectSpace(headAfter)
	return ha:PointToWorldSpace(hb:PointToObjectSpace(CAM_SUBJECT + eye)) - CAM_SUBJECT
end

-- กล้องออกจากหัวแล้ว (จอตาย: กล้องลอยขึ้นมองร่าง ฯลฯ) = เห็นตัวเองครบ หัว ผม หมวก (ซ่อนเฉพาะตอนกล้องอยู่ที่ตา)
local OUT_OF_HEAD = 2.5
local headMarker = char:FindFirstChild("Head") :: BasePart?
RunService:BindToRenderStep("VillagerBodyVisible", Enum.RenderPriority.Camera.Value + 2, function()
	local cam = workspace.CurrentCamera
	local outside = cam ~= nil and headMarker ~= nil and (cam.CFrame.Position - headMarker.Position).Magnitude > OUT_OF_HEAD
	for i = #bodyParts, 1, -1 do
		local p = bodyParts[i]
		if not p:IsDescendantOf(char) then
			table.remove(bodyParts, i) -- ของที่เก็บเข้ากระเป๋าแล้ว (หยิบใหม่ = ใส่รายการใหม่)
		else
			-- ของในมือ (Tool เช่นไฟฉาย) ซ่อนบนจอเรา: HUDController วางไฟฉายที่เห็นในมือแทน
			-- (ไม่ซ่อน = เห็นไฟฉายจริงลอยอยู่อีกอัน ที่จุดเชื่อม VillagerGrip ของเซิร์ฟเวอร์)
			local hide = if outside
				then (p.Name == "HumanoidRootPart" or p.Name == "RootPart" or p.Name == "Head")
				else (hiddenInFpp(p.Name) or (p:FindFirstAncestorOfClass("Tool") ~= nil and p:FindFirstAncestorOfClass("Tool").Name == "FrogFlashlight"))
			local want = if hide then 1 else 0
			if p.LocalTransparencyModifier ~= want then
				p.LocalTransparencyModifier = want
			end
		end
	end
end)

-- ---------------------------------------------------------------- ทุกเฟรม: เลือกท่า
local lastYaw = 0
local turningUntil = 0
local dtNow = 1 / 60
RunService.Heartbeat:Connect(function(dt)
	dtNow = dt
	if hum.Health <= 0 then
		return
	end
	local state = hum:GetState()
	-- หันตัวอยู่กับที่ (มุมบุคคลที่หนึ่ง ตัวหันตามกล้อง): ก้าวเท้าตาม ไม่ให้ตัวหมุนลื่นเหมือนยืนบนจานหมุน
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local turnRate = if root then math.abs(root.AssemblyAngularVelocity.Y) else 0
	local yaw = if root then select(2, root.CFrame:ToOrientation()) else 0
	if root then
		local d = math.abs(((yaw - lastYaw + math.pi) % (2 * math.pi)) - math.pi) / math.max(dtNow, 1 / 240)
		turnRate = math.max(turnRate, d)
		lastYaw = yaw
	end
	if turnRate > 1.2 then
		turningUntil = os.clock() + 0.25 -- ก้าวต่ออีกนิดหลังหยุดหัน (ไม่ตัดท่ากลางก้าว)
	end
	-- ล้มตาย (Server ยึดตัวไว้นอนคว่ำ): นอนนิ่ง ไม่หายใจ ไม่ก้าว = ท่ายืนเฟรมแรกหยุดค้าง (แขนแนบตัว)
	--   (ตัวหมุนตอนล้มอย่านับเป็นการหันตัว ไม่งั้นท่าก้าวเล่นระหว่างล้ม)
	-- นั่งซ้อนรถในคัทซีน (Server ยึดตัว anchored + Sit = true): ท่านั่ง ไม่ใช่ท่าล้มนิ่ง
	-- (คัทซีนยึดตัวยืนรอ = ยืนหายใจปกติ ไม่ใช่ท่าล้มนิ่ง)
	local downed = root ~= nil and root.Anchored and not hum.Sit and game:GetService("Lighting"):GetAttribute("Cutscene") ~= true
	-- ท่าตามบทคัทซีน (Server ตั้ง attribute PoseClip เช่น "pull_rope" ตอนดึงเชือกปิดร้าน)
	local pose = hum:GetAttribute("PoseClip")
	if type(pose) == "string" and ids[pose] then
		setBase(pose)
	elseif downed then
		turningUntil = 0
		setTurnStep(false)
		setBase("idle", 0)
		local idle = tracks.idle
		if idle and idle.TimePosition ~= 0 then
			idle.TimePosition = 0
		end
	elseif hum.Sit or state == Enum.HumanoidStateType.Seated then
		-- ท่านั่งเฉพาะ (Server ตั้ง attribute SitClip): ซ้อนมอไซค์ในคัทซีน = "ride_moto" ขากางคร่อมเบาะ ไม่หนีบเข่าแบบนั่งเก้าอี้
		local clip = hum:GetAttribute("SitClip")
		setBase(if type(clip) == "string" and ids[clip] then clip else "sit")
	elseif state == Enum.HumanoidStateType.Freefall then
		setBase("fall")
	elseif speedNow > 0.6 then
		setBase("walk", math.clamp(speedNow / WALK_CLIP_SPEED, 0.6, 2.4))
	elseif os.clock() < turningUntil then
		setBase("idle", 1)
		setTurnStep(true) -- ก้าวสั้นๆ ตอนหันตัว (เดินเบาๆ ซ้อนท่ายืน)
	else
		setBase("idle", 1) -- ความเร็ว 1: คืนจากตอนนอนนิ่ง (ความเร็ว 0) หลังชุบ
		setTurnStep(false)
	end

	local praying = player:GetAttribute("Praying") == true
	-- พนมมือ: ท่าก้มหัว จมูกเลื่อนมาหน้ากล้อง -> ดันกล้องไปข้างหน้าและลงตามหัวที่ก้ม
	-- CameraOffset อยู่ในกรอบของตัว: ตาตามหัวที่หัน/เอน (eyeFollowHead)
	hum:SetAttribute("EyeOffset", eyeFollowHead(if praying then EYE_PRAY else EYE))
	local flashlight = char:FindFirstChild("FrogFlashlight") ~= nil
	-- ล้มตาย: ยกเลิกท่าถือ/พนมมือทั้งหมดด้วย (downed ด้านบน)
	-- พนมมือ = มือว่าง ไม่ถืออะไร
	setOverlay("pray", praying and not downed)
	setOverlay("hold_flashlight", flashlight and not praying and not downed)
	-- ของในมือขวา (client/HeldItems วางของตรงมือ): ท่าเล่นจากข้อมูลใน client/HumanEmotesRunner
	--   ขนมตาลบนใบตอง = แบมือหงาย (hold_tray_r), แกลลอน = หิ้วข้างตัว (carry_gallon_r) / ไฟฉายมือซ้ายพร้อมกันได้
end)
