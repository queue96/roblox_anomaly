-- LobbyServer.server.luau
-- สคริปต์ฝั่ง Server ของ place "Lobby" (Start Place) — sync ผ่าน lobby.project.json พอร์ต 34873
-- 1) บรรยากาศวัดร้างตอนเที่ยงคืน
-- 2) โซนสร้างห้อง: เดินเข้าวง RoomPad ที่ว่าง = เป็นเจ้าของห้อง เลือกจำนวนผู้เล่น (1–6) + ความยาก
--    คนอื่นเดินเข้าวงเดียวกัน = เข้าห้อง (จนเต็ม), ระหว่างรอสมาชิกถูกกั้นในวง (แสงจากพื้น + ขอบล่องหนที่ชนเฉพาะสมาชิก)
--    และออกจากปุ่ม UI เท่านั้น
--    ระหว่างเจ้าของห้องยังเลือกจำนวนผู้เล่นอยู่ วงถูกล็อก (ขอบชนทุกคน + ดันคนอื่นออก) จนกว่าจะยืนยันหรือยกเลิก
--    เจ้าของห้องกด "เริ่มเกม" = ReserveServer + TeleportAsync ไป Pump Lot ทันที; ห้องเต็มนับ 5 วิแล้วส่งอัตโนมัติ
--    พร้อม TeleportData { roomId, difficulty, maxPlayers, hostUserId } (ดูสัญญาใน Shared.Difficulty)
--    ตั้งค่าไม่เสร็จใน 30 วิ = ดีดกลับจุดเกิด; ห้องรอผู้เล่นได้ 60 วิ แล้วปิดและดีดทุกคนกลับ

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

-- place แมพเกม (Pump Lot) ใน experience เดียวกัน
local GAME_PLACE_ID = 114125276809667

-- TeleportService ใช้ใน Studio ไม่ได้ ตอนเทสใน Studio ให้ print แทนการส่งผู้เล่นจริง
local IS_STUDIO = RunService:IsStudio()

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Difficulty = require(Shared:WaitForChild("Difficulty"))
-- ป้ายห้อง 3D: แสดงตามภาษาของแต่ละคน (Client เขียนทับเอง shared/Bilingual)
local Bilingual = require(Shared:WaitForChild("Bilingual"))
-- สมุดผีชุดเดียวกับเกม (DataStore เดียวกันทั้ง experience) ให้ปุ่ม "สมุดผี" ใน Lobby เปิดดูของที่สะสมไว้ได้
-- การตั้งค่า (ภาษา/เสียง) มาจาก PlayerSettings.server.luau ที่ sync เข้ามาโฟลเดอร์เดียวกัน
require(script.Parent:WaitForChild("AnomalyBook"))

-- ---------------------------------------------------------------- 1) บรรยากาศ
-- ใช้แสงกลางคืนชุดเดียวกับแมพเกม แล้วกดให้ซีดและเย็นกว่า
local MapBuilder = require(Shared:WaitForChild("MapBuilder"):Clone())
MapBuilder.OptimizeShadowsAndCleanup()
MapBuilder.SetNightLighting()
-- แสงจันทร์จางและเย็น: หมอกจริงทำด้วยอนุภาคต่ำเหนือพื้น จึงไม่ใช้ Atmosphere หนาเกินจนฉากซีดขาว
Lighting.Brightness = 0.5
Lighting.Ambient = Color3.fromRGB(20, 25, 34)
Lighting.OutdoorAmbient = Color3.fromRGB(30, 37, 48)
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then
	atmo.Density = 0.34
	atmo.Haze = 1.3
	atmo.Color = Color3.fromRGB(68, 82, 100)
	atmo.Decay = Color3.fromRGB(22, 31, 44)
end
-- หมอกหนาทึบ: เห็นชัดในลาน แต่ป่ารอบวัดค่อยๆ จมหายในหมอก (ไม่เห็นขอบแมพ)
Lighting.FogColor = Color3.fromRGB(35, 45, 58)
Lighting.FogStart = 52
Lighting.FogEnd = 175
if atmo then
	atmo.Density = 0.4
	atmo.Offset = 0.2
end

-- ล็อกกล้อง: ซูมออกได้ไม่เกิน 22 studs กันมองข้ามป่าออกไปนอกแมพ
local StarterPlayer = game:GetService("StarterPlayer")
local MAX_ZOOM = 22
StarterPlayer.CameraMaxZoomDistance = MAX_ZOOM
for _, p in ipairs(Players:GetPlayers()) do
	p.CameraMaxZoomDistance = MAX_ZOOM
	p.CharacterAdded:Connect(function(char)
		local ff = char:FindFirstChildOfClass("ForceField")
		if ff then ff:Destroy() end
		char.ChildAdded:Connect(function(c)
			if c:IsA("ForceField") then c:Destroy() end
		end)
	end)
end
Players.PlayerAdded:Connect(function(p)
	p.CameraMaxZoomDistance = MAX_ZOOM
	p.CharacterAdded:Connect(function(char)
		local ff = char:FindFirstChildOfClass("ForceField")
		if ff then ff:Destroy() end
		char.ChildAdded:Connect(function(c)
			if c:IsA("ForceField") then c:Destroy() end
		end)
	end)
end)

local grade = Lighting:FindFirstChild("LobbyGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "LobbyGrade"
grade.Saturation = -0.42
grade.Contrast = 0.16
grade.Brightness = -0.03
grade.TintColor = Color3.fromRGB(194, 211, 232)
grade.Parent = Lighting
local oldNightBloom = Lighting:FindFirstChild("NightBloom")
if oldNightBloom then
	oldNightBloom:Destroy()
end
local bloom = Lighting:FindFirstChild("LobbyBloom") or Instance.new("BloomEffect")
bloom.Name = "LobbyBloom"
bloom.Intensity = 0.35
bloom.Size = 28
bloom.Threshold = 1.1
bloom.Threshold = 0.92
bloom.Intensity = 0.45
bloom.Size = 32
bloom.Parent = Lighting

local dof = (Lighting:FindFirstChild("NightDepthOfField") :: DepthOfFieldEffect?)
	or (Lighting:FindFirstChild("LobbyDepthOfField") :: DepthOfFieldEffect?)
	or Instance.new("DepthOfFieldEffect")
dof.Name = "LobbyDepthOfField"
dof.Enabled = true
dof.FocusDistance = 24
dof.InFocusRadius = 32
dof.NearIntensity = 0.08
dof.FarIntensity = 0.32
dof.Parent = Lighting

local softBlur = (Lighting:FindFirstChild("SoftFilmBlur") :: BlurEffect?)
	or (Lighting:FindFirstChild("LobbySoftBlur") :: BlurEffect?)
	or Instance.new("BlurEffect")
softBlur.Name = "LobbySoftBlur"
softBlur.Enabled = true
softBlur.Size = 1.3
softBlur.Parent = Lighting

-- ไม่มีผีใน Lobby: ลบเงาผี (tag "Apparition" เช่น SpookyDecor.LobbyApparition) ที่อาจติดมากับไฟล์ place / BuildTempleLobby
for _, g in ipairs(CollectionService:GetTagged("Apparition")) do
	if g:IsDescendantOf(workspace) then
		g:Destroy()
	end
end
CollectionService:GetInstanceAddedSignal("Apparition"):Connect(function(g)
	if g:IsDescendantOf(workspace) then
		g:Destroy()
	end
end)

-- ---------------------------------------------------------------- 2) โซนสร้างห้อง
local SETUP_COUNTDOWN = 30 -- เวลาตั้งค่าห้องในหน้าต่างเลือก
local WAITING_COUNTDOWN = 60 -- เวลารอผู้เล่นหลังสร้างห้อง
local FULL_ROOM_COUNTDOWN = 5 -- ห้องเต็มแล้วนับถอยหลังก่อน Teleport
local REJOIN_COOLDOWN = 3 -- วินาที หลังห้องปิด/ส่งไม่สำเร็จ ก่อนวงจะถามสร้างห้องใหม่

-- ดีดกลับจุดเกิด (กลางลาน)
local function sendToSpawn(player: Player)
	local char = player.Character
	local lobby = workspace:FindFirstChild("TempleLobby")
	local spawn = lobby and lobby:FindFirstChild("LobbySpawn") :: BasePart?
	if char and spawn then
		char:PivotTo(spawn.CFrame + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3)))
	end
end

local remotes = Instance.new("Folder")
remotes.Name = "LobbyRemotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local OpenSetup = remote("OpenSetup") -- S->C (padIndex | nil = ปิดหน้าต่าง)
local ConfirmRoom = remote("ConfirmRoom") -- C->S (maxPlayers, difficulty)
local CancelSetup = remote("CancelSetup") -- C->S
local StartNow = remote("StartNow") -- C->S เจ้าของห้องกดเริ่มเลย
local LeaveRoom = remote("LeaveRoom") -- C->S ออกจากห้องระหว่างรอ
local RoomState = remote("RoomState") -- S->C (state | nil)
local Notice = remote("Notice") -- S->C (th, en)
local RejoinOffer = remote("RejoinOffer") -- S->C (true = มีเกมค้างอยู่ ถามว่าจะกลับเข้าไหม)  C->S (true กลับ / false ไม่กลับ)
remotes.Parent = ReplicatedStorage

type Room = {
	id: string,
	pad: BasePart,
	host: Player,
	members: { Player },
	maxPlayers: number,
	difficulty: string,
	countdown: number,
	fullCountdown: number?,
	fullDeadline: number?,
	launching: boolean,
}

local pads: { BasePart } = {}
local rooms: { [BasePart]: Room } = {}
local pendingHost: { [BasePart]: Player } = {}
local pendingSince: { [BasePart]: number } = {}

-- ขอบวง (TempleLobby.RoomPads.RoomPadWall_n จาก MapBuilder): ไม่มีกรงให้เห็นแล้ว
--   ภาพ = แสงแดงสาดขึ้นจากพื้นรอบวง (Beam จางหายด้านบน) เปิดตอนตั้งห้อง/มีห้อง
--   ชน = WallSeg ล่องหน อยู่กลุ่ม RoomWall ที่ชนเฉพาะกลุ่ม RoomMember (สมาชิกห้อง)
--   คนข้างนอกเดินทะลุเข้ามาร่วมห้องได้ ส่วนสมาชิกเดินออกไม่ได้ (ออกจากปุ่ม UI เท่านั้น)
local PhysicsService = game:GetService("PhysicsService")
local WALL_GROUP = "RoomWall"
local MEMBER_GROUP = "RoomMember"
local PLAYER_GROUP = "LobbyPlayer" -- ผู้เล่นทั่วไปใน lobby: เดินทะลุกันได้
for _, g in ipairs({ WALL_GROUP, MEMBER_GROUP, PLAYER_GROUP }) do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable(WALL_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(WALL_GROUP, WALL_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(WALL_GROUP, MEMBER_GROUP, true)
PhysicsService:CollisionGroupSetCollidable(WALL_GROUP, PLAYER_GROUP, false)
-- ผู้เล่นทุกคนไม่ชนกันเอง (ทั้งคนทั่วไปและสมาชิกห้อง) แต่ยังชนพื้น/ฉากตามปกติ
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, MEMBER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(MEMBER_GROUP, MEMBER_GROUP, false)
-- ระหว่างเจ้าของห้องกำลังตั้งค่า (pending) วงถูกล็อก: ขอบล่องหนสลับมากลุ่มนี้ ชนทุกคน คนข้างนอกเดินเข้ามาไม่ได้
--   ขอบสูง 10 studs กระโดดข้ามไม่ได้ ยืนยัน/ยกเลิกแล้วสลับกลับเป็น WALL_GROUP (คนนอกเดินเข้ามาร่วมห้องได้)
local LOCKED_WALL_GROUP = "RoomWallLocked"
if not PhysicsService:IsCollisionGroupRegistered(LOCKED_WALL_GROUP) then
	PhysicsService:RegisterCollisionGroup(LOCKED_WALL_GROUP)
end
PhysicsService:CollisionGroupSetCollidable(LOCKED_WALL_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(LOCKED_WALL_GROUP, LOCKED_WALL_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(LOCKED_WALL_GROUP, WALL_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(LOCKED_WALL_GROUP, MEMBER_GROUP, true)
PhysicsService:CollisionGroupSetCollidable(LOCKED_WALL_GROUP, PLAYER_GROUP, true)

local LIGHT_HEIGHT = 6 -- ความสูงแสงที่สาดขึ้นจากพื้น (จางหมดที่ยอด)
local LIGHT_COLOR = Color3.fromRGB(255, 60, 40)

local function padWall(pad: BasePart): Instance?
	return pad.Parent and pad.Parent:FindFirstChild("RoomPadWall_" .. tostring(pad:GetAttribute("PadIndex")))
end

-- แปลงกำแพงเดิมในไฟล์ place: ซ่อนถาวร, ชนเฉพาะสมาชิก, ใส่ Beam แสงจากพื้น (ปิดไว้ก่อน)
local function prepareWall(pad: BasePart)
	local wall = padWall(pad)
	if not wall then
		return
	end
	for _, w in ipairs(wall:GetChildren()) do
		if w:IsA("BasePart") then
			w.Transparency = 1
			w.CanCollide = true
			w.CanQuery = false
			w.CollisionGroup = WALL_GROUP
			if not w:FindFirstChild("FloorLight") then
				local half = w.Size.Y / 2
				local floorY = pad.Position.Y - 0.15 - w.Position.Y -- ระดับพื้นลานในพิกัดของชิ้น
				local a0 = Instance.new("Attachment")
				a0.Name = "LightBottom"
				a0.Position = Vector3.new(0, math.max(floorY, -half), 0)
				-- แกนรองของ attachment กำหนดทิศความกว้างของ Beam: หมุนให้ชี้ตามแนวสัมผัสวง (แกน Z ของชิ้น)
				-- ไม่งั้นความกว้างขนานกับทิศ Beam แผ่นแสงจะแบนหายไป
				a0.Orientation = Vector3.new(90, 0, 0)
				a0.Parent = w
				local a1 = Instance.new("Attachment")
				a1.Name = "LightTop"
				a1.Position = a0.Position + Vector3.new(0, LIGHT_HEIGHT, 0)
				a1.Orientation = Vector3.new(90, 0, 0)
				a1.Parent = w
				local beam = Instance.new("Beam")
				beam.Name = "FloorLight"
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Width0 = w.Size.Z
				beam.Width1 = w.Size.Z
				beam.FaceCamera = false
				beam.Segments = 1
				beam.Color = ColorSequence.new(LIGHT_COLOR)
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Brightness = 4
				beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.1),
					NumberSequenceKeypoint.new(0.4, 0.65),
					NumberSequenceKeypoint.new(1, 1),
				})
				beam.Enabled = false
				beam.Parent = w
				-- แผ่นขอบเดิมบาง 0.4 สูง 10 ชนกันพอดีขอบ: แทรกผ่านรอยต่อได้ และกระโดดขึ้นไปยืนบนสันขอบแล้วข้ามได้
				-- หนาขึ้น + กว้างขึ้นให้ซ้อนกัน + สูงขึ้นอีก WALL_EXTRA (ยอดพ้นระยะกระโดด) ฐานอยู่ที่เดิม
				-- (ทำหลังสร้าง Beam ความกว้างแสงเท่าเดิม และเลื่อน attachment ชดเชย แสงจึงอยู่ที่พื้นเหมือนเดิม)
				local WALL_EXTRA = 8
				w.Size = Vector3.new(math.max(w.Size.X, 1.2), w.Size.Y + WALL_EXTRA, w.Size.Z * 1.3)
				w.CFrame += Vector3.new(0, WALL_EXTRA / 2, 0)
				a0.Position -= Vector3.new(0, WALL_EXTRA / 2, 0)
				a1.Position -= Vector3.new(0, WALL_EXTRA / 2, 0)
			end
		end
	end
end

local function setWall(pad: BasePart, on: boolean)
	local wall = padWall(pad)
	if not wall then
		return
	end
	for _, w in ipairs(wall:GetChildren()) do
		local beam = w:FindFirstChild("FloorLight") :: Beam?
		if beam then
			beam.Enabled = on
		end
	end
end

-- ล็อก/ปลดล็อกตัวผู้เล่นกับขอบวง
local lockedPlayers: { [Player]: boolean } = {}
local function applyGroup(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local group = if lockedPlayers[player] then MEMBER_GROUP else PLAYER_GROUP
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end
local function setLocked(player: Player, locked: boolean)
	lockedPlayers[player] = if locked then true else nil
	applyGroup(player)
end
local function hookCharacter(player: Player)
	local function onChar(char: Model)
		applyGroup(player)
		char.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") then
				d.CollisionGroup = if lockedPlayers[player] then MEMBER_GROUP else PLAYER_GROUP
			end
		end)
	end
	if player.Character then
		onChar(player.Character)
	end
	player.CharacterAdded:Connect(onChar)
end
for _, p in ipairs(Players:GetPlayers()) do
	hookCharacter(p)
end
Players.PlayerAdded:Connect(hookCharacter)
Players.PlayerRemoving:Connect(function(p)
	lockedPlayers[p] = nil
end)

-- ดึงตัวผู้เล่นเข้ามาด้านในวง (กันตัวคร่อมขอบตอนเพิ่งถูกล็อก หรือหลุดออกไปนอกวง)
local function pullInside(player: Player, pad: BasePart)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and root) then
		return
	end
	local inner = pad.Size.Y / 2 - 3.5
	local d = root.Position - pad.Position
	local flat = Vector3.new(d.X, 0, d.Z)
	if flat.Magnitude > inner then
		local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(1, 0, 0)
		local target = pad.Position + dir * inner
		char:PivotTo(CFrame.new(Vector3.new(target.X, root.Position.Y, target.Z)) * root.CFrame.Rotation)
	end
end

-- ขอบวงชนทุกคน (ล็อกระหว่างตั้งห้อง) หรือชนเฉพาะสมาชิก (ปกติ)
local function setWallLocked(pad: BasePart, locked: boolean)
	local wall = padWall(pad)
	if not wall then
		return
	end
	for _, w in ipairs(wall:GetChildren()) do
		if w:IsA("BasePart") then
			w.CollisionGroup = if locked then LOCKED_WALL_GROUP else WALL_GROUP
		end
	end
end

-- ดันผู้เล่นออกไปนอกขอบวง (คนที่ไม่ใช่เจ้าของห้องระหว่างวงถูกล็อก)
local function pushOutside(player: Player, pad: BasePart)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and root) then
		return
	end
	local outer = pad.Size.Y / 2 + 3
	local d = root.Position - pad.Position
	local flat = Vector3.new(d.X, 0, d.Z)
	local dir = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
	local target = pad.Position + dir * outer
	char:PivotTo(CFrame.new(Vector3.new(target.X, root.Position.Y, target.Z)) * root.CFrame.Rotation)
end

local lockedNoticeAt: { [Player]: number } = {}
local onPad: { [Player]: BasePart? } = {}
local function rejectWhileSetup(player: Player, pad: BasePart)
	onPad[player] = nil
	pushOutside(player, pad)
	if os.clock() - (lockedNoticeAt[player] or 0) > 3 then
		lockedNoticeAt[player] = os.clock()
		Notice:FireClient(player, "มีคนกำลังตั้งห้องนี้อยู่ รอสักครู่", "Someone is setting up this room, please wait")
	end
end

local function setPending(pad: BasePart, player: Player?)
	local before = pendingHost[pad]
	pendingHost[pad] = player
	pendingSince[pad] = if player then os.clock() else nil
	setWall(pad, player ~= nil)
	setWallLocked(pad, player ~= nil)
	if player then
		pullInside(player, pad)
		setLocked(player, true)
		-- คนอื่นที่ยืนอยู่ในวงพร้อมกัน: ดันออกไปก่อน จนกว่าเจ้าของห้องจะยืนยันหรือยกเลิก
		for other, p in pairs(onPad) do
			if p == pad and other ~= player then
				rejectWhileSetup(other, pad)
			end
		end
	elseif before and not (rooms[pad] and table.find(rooms[pad].members, before)) then
		setLocked(before, false)
	end
end
local cooldownUntil: { [Player]: number } = {}

-- ป้ายลอยเหนือวง (Server แก้ข้อความ ทุกคนเห็นตรงกัน)
local function ensureSign(pad: BasePart): TextLabel
	local anchor = pad:FindFirstChild("SignAnchor") :: Attachment?
	if not anchor then
		local a = Instance.new("Attachment")
		a.Name = "SignAnchor"
		a.Parent = pad
		a.WorldPosition = pad.Position + Vector3.new(0, 7.5, 0)
		anchor = a
	else
		anchor.WorldPosition = pad.Position + Vector3.new(0, 7.5, 0)
	end

	local gui = pad:FindFirstChild("RoomSign") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "RoomSign"
		g.Adornee = anchor
		g.Size = UDim2.fromScale(14, 4.5)
		g.StudsOffset = Vector3.zero
		g.StudsOffsetWorldSpace = Vector3.zero
		g.MaxDistance = 120
		g.AlwaysOnTop = true
		g.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.TextColor3 = Color3.fromRGB(236, 228, 208) -- ครีม + ฟอนต์พิมพ์ดีดเก่า ชุดเดียวกับ HUD ในเกม
		t.TextStrokeTransparency = 0.3
		t.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
		t.TextScaled = true
		t.Parent = g
		g.Parent = pad
		gui = g
	else
		gui.Adornee = anchor
		gui.StudsOffset = Vector3.zero
		gui.StudsOffsetWorldSpace = Vector3.zero
	end
	local label = (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
	-- ป้ายเก่าที่สร้างไว้ในไฟล์ place แล้ว: ปรับเป็นธีมเดียวกันด้วย
	label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
	label.TextColor3 = Color3.fromRGB(236, 228, 208)
	return label
end

local function members(room: Room): { number }
	local ids = {}
	for _, p in ipairs(room.members) do
		table.insert(ids, p.UserId)
	end
	return ids
end

local function refresh(pad: BasePart)
	local label = ensureSign(pad)
	local i = pad:GetAttribute("PadIndex") or 0
	local room = rooms[pad]
	if room then
		-- ไม่มีให้เลือกความยากแล้ว (ใช้ค่าเริ่มต้นเสมอ) ป้ายจึงไม่แสดงความยาก
		if room.launching then
			Bilingual.Text(label, ("ห้อง %d · %s\n%d/%d คน\nกำลังส่งไปเกม..."):format(i, room.host.DisplayName, #room.members, room.maxPlayers), ("Room %d · %s\n%d/%d players\nStarting the game..."):format(i, room.host.DisplayName, #room.members, room.maxPlayers))
		elseif room.fullCountdown then
			Bilingual.Text(label, ("ห้อง %d · %s\n%d/%d คน\nเต็มแล้ว · ไปเกมใน %d"):format(i, room.host.DisplayName, #room.members, room.maxPlayers, room.fullCountdown), ("Room %d · %s\n%d/%d players\nFull · starting in %d"):format(i, room.host.DisplayName, #room.members, room.maxPlayers, room.fullCountdown))
		else
			Bilingual.Text(label, ("ห้อง %d · %s\n%d/%d คน\nรอผู้เล่น · เริ่มใน %d วิ"):format(i, room.host.DisplayName, #room.members, room.maxPlayers, room.countdown), ("Room %d · %s\n%d/%d players\nWaiting · starts in %ds"):format(i, room.host.DisplayName, #room.members, room.maxPlayers, room.countdown))
		end
		label.TextColor3 = Color3.fromRGB(235, 220, 200)
		for _, p in ipairs(room.members) do
			RoomState:FireClient(p, {
				pad = i,
				hostName = room.host.DisplayName,
				isHost = p == room.host,
				count = #room.members,
				maxPlayers = room.maxPlayers,
				difficulty = room.difficulty,
				countdown = room.countdown,
				fullCountdown = room.fullCountdown,
				launching = room.launching,
			})
		end
	elseif pendingHost[pad] then
		Bilingual.Text(label, ("ห้อง %d\n%s กำลังตั้งห้อง...\nปิดชั่วคราว รอสักครู่"):format(i, pendingHost[pad].DisplayName), ("Room %d\n%s is setting up...\nLocked, please wait"):format(i, pendingHost[pad].DisplayName))
		label.TextColor3 = Color3.fromRGB(235, 220, 200)
	else
		Bilingual.Text(label, ("ห้อง %d · ว่าง\nเดินเข้าวงเพื่อสร้างห้อง"):format(i), ("Room %d · empty\nWalk in to host"):format(i))
		label.TextColor3 = Color3.fromRGB(235, 220, 200)
	end
end

local function closeRoom(pad: BasePart, th: string, en: string, keepPosition: boolean?)
	local room = rooms[pad]
	if not room then
		return
	end
	rooms[pad] = nil
	setWall(pad, false)
	for _, p in ipairs(room.members) do
		setLocked(p, false)
		RoomState:FireClient(p, nil)
		Notice:FireClient(p, th, en)
		cooldownUntil[p] = os.clock() + REJOIN_COOLDOWN
		onPad[p] = nil
		if not keepPosition then
			sendToSpawn(p)
		end
	end
	refresh(pad)
end

local function leaveRoom(player: Player, pad: BasePart)
	if pendingHost[pad] == player then
		setPending(pad, nil)
		OpenSetup:FireClient(player, nil)
		refresh(pad)
		return
	end
	local room = rooms[pad]
	if not room or room.launching then
		return
	end
	local idx = table.find(room.members, player)
	if not idx then
		return
	end
	if player == room.host then
		closeRoom(pad, "เจ้าของห้องออกไปแล้ว ห้องถูกปิด", "The host left, the room is closed")
		return
	end
	table.remove(room.members, idx)
	setLocked(player, false)
	room.fullCountdown = nil
	room.fullDeadline = nil
	RoomState:FireClient(player, nil)
	onPad[player] = nil
	cooldownUntil[player] = os.clock() + REJOIN_COOLDOWN
	sendToSpawn(player)
	refresh(pad)
end

local function startFullCountdown(room: Room)
	if not room.launching and not room.fullCountdown and #room.members >= room.maxPlayers then
		room.fullCountdown = FULL_ROOM_COUNTDOWN
		room.fullDeadline = os.clock() + FULL_ROOM_COUNTDOWN
	end
end

local function enterPad(player: Player, pad: BasePart)
	if (cooldownUntil[player] or 0) > os.clock() then
		return
	end
	local room = rooms[pad]
	if room then
		if room.launching or table.find(room.members, player) then
			return
		end
		if #room.members >= room.maxPlayers then
			Notice:FireClient(player, "ห้องนี้เต็มแล้ว", "This room is full")
			onPad[player] = nil
			cooldownUntil[player] = os.clock() + REJOIN_COOLDOWN
			sendToSpawn(player)
			return
		end
		table.insert(room.members, player)
		pullInside(player, pad)
		setLocked(player, true)
		startFullCountdown(room)
		refresh(pad)
	elseif not pendingHost[pad] then
		setPending(pad, player)
		OpenSetup:FireClient(player, pad:GetAttribute("PadIndex"), SETUP_COUNTDOWN)
		refresh(pad)
	elseif pendingHost[pad] ~= player then
		-- วงถูกล็อกระหว่างเจ้าของห้องเลือกจำนวนผู้เล่น: ห้ามเข้า ดันออกไปนอกวง
		rejectWhileSetup(player, pad)
	end
end

local function launch(room: Room)
	if room.launching then
		return
	end
	room.launching = true
	refresh(room.pad)
	local data = {
		roomId = room.id,
		difficulty = room.difficulty,
		maxPlayers = room.maxPlayers,
		hostUserId = room.host.UserId,
		members = {} :: { number }, -- server/MatchGuard ให้เข้าเกมได้เฉพาะคนในรายชื่อนี้ (กดเข้าร่วมตามเพื่อน = ส่งกลับ Lobby)
		accessCode = nil :: string?, -- รหัสเซิร์ฟเวอร์เกม: คนที่หลุดใช้กลับเข้ามาที่เดิม
	}
	for _, m in ipairs(room.members) do
		table.insert(data.members, m.UserId)
	end
	if IS_STUDIO then
		print(("🚚 [Lobby] (Studio) Teleport -> PlaceId %d | %s"):format(GAME_PLACE_ID, HttpService:JSONEncode(data)))
		task.wait(1.5)
		closeRoom(
			room.pad,
			"เริ่มเกมแล้ว! (ใน Roblox Studio วาร์ปข้าม Place ไม่ได้ — ต้อง Publish แล้วเล่นในแอป Roblox จริง)",
			"Game started! (Roblox Studio cannot teleport between places ? publish & test in Roblox app)",
			true
		)
		return
	end
	-- จองเซิร์ฟเวอร์เองก่อน (ได้รหัสไว้ให้คนหลุดกลับเข้ามา) จองไม่ได้ค่อยให้ TeleportAsync จองให้
	local okCode, code = pcall(function()
		return (TeleportService:ReserveServer(GAME_PLACE_ID))
	end)
	if okCode and type(code) == "string" then
		data.accessCode = code
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		if data.accessCode then
			options.ReservedServerAccessCode = data.accessCode
		else
			options.ShouldReserveServer = true
		end
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(GAME_PLACE_ID, room.members, options)
	end)
	if not ok then
		warn("[Lobby] Teleport (ShouldReserveServer) failed, retrying standard TeleportAsync: " .. tostring(err))
		ok, err = pcall(function()
			local fallbackOptions = Instance.new("TeleportOptions")
			fallbackOptions:SetTeleportData(data)
			TeleportService:TeleportAsync(GAME_PLACE_ID, room.members, fallbackOptions)
		end)
	end
	if not ok then
		warn("[Lobby] Teleport failed: " .. tostring(err))
		closeRoom(
			room.pad,
			"ส่งไปเกมไม่สำเร็จ ลองใหม่อีกครั้ง",
			"Teleport failed, please try again",
			true
		)
		return
	end
	print(("🚚 [Lobby] Teleporting %d players | %s"):format(#room.members, HttpService:JSONEncode(data)))
	task.delay(20, function()
		if rooms[room.pad] == room then
			closeRoom(
				room.pad,
				"ส่งไปเกมไม่สำเร็จ ลองใหม่อีกครั้ง",
				"Teleport failed, please try again",
				true
			)
		end
	end)
end

ConfirmRoom.OnServerEvent:Connect(function(player: Player, maxPlayers: any, _difficulty: any)
	local pad = onPad[player]
	if not pad or pendingHost[pad] ~= player or rooms[pad] then
		return
	end
	if type(maxPlayers) ~= "number" then
		return
	end
	setPending(pad, nil)
	local room: Room = {
		id = HttpService:GenerateGUID(false),
		pad = pad,
		host = player,
		members = { player },
		maxPlayers = math.clamp(math.floor(maxPlayers), 1, Difficulty.MaxPlayers),
		difficulty = Difficulty.Default, -- ไม่มีให้เลือกความยากใน Lobby แล้ว: ใช้ค่าเริ่มต้นเสมอ
		countdown = WAITING_COUNTDOWN,
		fullCountdown = nil,
		fullDeadline = nil,
		launching = false,
	}
	rooms[pad] = room
	-- ผู้เล่นที่เข้าห้องถูกกั้นไว้จนกว่าจะกดออกจาก UI หรือเกมเริ่ม (คนข้างนอกยังเดินเข้ามาร่วมได้)
	setWall(pad, true)
	setLocked(player, true)
	-- คนที่ยืนรออยู่ในวงก่อนแล้วได้เข้าห้องเลย
	for other, p in pairs(onPad) do
		if p == pad and other ~= player then
			if #room.members < room.maxPlayers then
				enterPad(other, pad)
			else
				onPad[other] = nil
				cooldownUntil[other] = os.clock() + REJOIN_COOLDOWN
				Notice:FireClient(other, "ห้องนี้เต็มแล้ว", "This room is full")
				sendToSpawn(other)
			end
		end
	end
	startFullCountdown(room)
	refresh(pad)
end)

LeaveRoom.OnServerEvent:Connect(function(player: Player)
	local pad = onPad[player]
	if pad then
		leaveRoom(player, pad)
	end
end)

CancelSetup.OnServerEvent:Connect(function(player: Player)
	local pad = onPad[player]
	if pad and pendingHost[pad] == player then
		setPending(pad, nil)
		cooldownUntil[player] = os.clock() + REJOIN_COOLDOWN
		refresh(pad)
		sendToSpawn(player)
	end
end)

-- เจ้าของห้องกดเริ่มเกม = ส่งไปเกมทันที
StartNow.OnServerEvent:Connect(function(player: Player)
	for _, room in pairs(rooms) do
		if room.host == player and not room.launching then
			task.spawn(launch, room)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local pad = onPad[player]
	if pad then
		leaveRoom(player, pad)
	end
	onPad[player] = nil
	cooldownUntil[player] = nil
	lockedNoticeAt[player] = nil
end)

-- ตรวจว่าใครยืนอยู่วงไหน (ระยะแนวราบ < รัศมีวง และสูงจากวงไม่เกิน 8 studs)
local function padUnder(root: BasePart): BasePart?
	for _, pad in ipairs(pads) do
		local r = pad.Size.Y / 2
		local d = root.Position - pad.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude < r and d.Y > -2 and d.Y < 8 then
			return pad
		end
	end
	return nil
end

task.spawn(function()
	local function addPad(p: Instance)
		-- เฉพาะวงใน Workspace (ชุดเก่าที่ถูก archive ไว้ ServerStorage ก็ยังติด tag อยู่)
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) and not table.find(pads, p) then
			table.insert(pads, p)
			prepareWall(p)
			refresh(p)
		end
	end
	for _, p in ipairs(CollectionService:GetTagged("RoomPad")) do
		addPad(p)
	end
	CollectionService:GetInstanceAddedSignal("RoomPad"):Connect(addPad)
	print(("🛖 [Lobby] โซนสร้างห้อง %d วง พร้อม"):format(#pads))

	local tick = 0
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local now = if root then padUnder(root) else nil
			local before = onPad[player]
			-- สมาชิกห้องถูกล็อกไว้: เดินออกจากวงไม่ใช่วิธีออกห้อง
			local isRoomMember = before and rooms[before] and table.find(rooms[before].members, player)
			-- ทำงานเฉพาะตอนเดินเข้า/ออกวงสำหรับผู้ที่ยังไม่ได้อยู่ในห้อง
			if isRoomMember and now ~= before and before then
				-- หลุดออกนอกวง / เกิดใหม่: ดึงกลับเข้าวงและล็อกใหม่
				pullInside(player, before)
				setLocked(player, true)
			elseif not isRoomMember and now ~= before then
				onPad[player] = now
				if before then
					leaveRoom(player, before)
				end
				if now then
					enterPad(player, now)
				end
			end
		end
		tick += 1
		if tick % 4 == 0 then
			-- ห้องเต็ม: แสดง 5, 4, 3, 2, 1 แล้วส่งไปเกมอัตโนมัติ
			for pad, room in pairs(rooms) do
				if not room.launching then
					if room.fullCountdown then
						local remaining = math.max(0, math.ceil((room.fullDeadline or os.clock()) - os.clock()))
						if remaining <= 0 then
							task.spawn(launch, room)
						elseif room.fullCountdown ~= remaining then
							room.fullCountdown = remaining
							refresh(pad)
						end
					else
						room.countdown -= 1
						if room.countdown <= 0 then
							if #room.members > 0 then
								task.spawn(launch, room)
							else
								closeRoom(pad, "หมดเวลารอผู้เล่น ห้องถูกปิด", "Waiting time expired, the room is closed")
							end
						else
							refresh(pad)
						end
					end
				end
			end
			-- หน้าต่างตั้งห้องค้างเกิน 30 วิ: ปิดหน้าต่าง ดีดกลับจุดเกิด
			for pad, p in pairs(pendingHost) do
				if os.clock() - (pendingSince[pad] or 0) > SETUP_COUNTDOWN then
					setPending(pad, nil)
					OpenSetup:FireClient(p, nil)
					Notice:FireClient(p, "หมดเวลาตั้งห้อง", "Room setup timed out")
					refresh(pad)
					sendToSpawn(p)
				end
			end
		end
	end
end)

-- หน้าโหลดฝั่งผู้เล่นรอค่านี้ (LoadingScreen.client): ฉาก lobby และระบบห้องพร้อมแล้ว
ReplicatedStorage:SetAttribute("SceneReady", true)
print(("✅ [Lobby] Server พร้อม | ปลายทาง PlaceId %d | Studio = %s"):format(GAME_PLACE_ID, tostring(IS_STUDIO)))

-- ---------------------------------------------------------------- หลุดเกมแล้วกลับเข้ามา
-- server/MatchGuard (place เกม) จดไว้ใน MemoryStore ว่าสมาชิกแต่ละคนอยู่เซิร์ฟเวอร์ไหน (ลบทิ้งเมื่อออกเอง)
-- เข้า Lobby มา + เซิร์ฟเวอร์นั้นยังเปิดอยู่ = ถามว่าจะกลับเข้าเกมเดิมไหม
local MemoryStoreService = game:GetService("MemoryStoreService")
local matchMap = MemoryStoreService:GetSortedMap("PumpLotMatches")
local pendingRejoin: { [Player]: { [string]: any } } = {}

local function checkRejoin(p: Player)
	if IS_STUDIO then
		return
	end
	local ok, entry = pcall(function()
		return matchMap:GetAsync("match_" .. p.UserId)
	end)
	if not (ok and type(entry) == "table" and type(entry.jobId) == "string") then
		return
	end
	local okAlive, alive = pcall(function()
		return matchMap:GetAsync("alive_" .. entry.jobId)
	end)
	if not (okAlive and alive) then
		pcall(function()
			matchMap:RemoveAsync("match_" .. p.UserId)
		end)
		return
	end
	if p.Parent then
		pendingRejoin[p] = entry
		RejoinOffer:FireClient(p, true)
	end
end

Players.PlayerAdded:Connect(function(p)
	task.delay(4, checkRejoin, p) -- รอฉากเปิด/หน้าโหลดขึ้นก่อน
end)
Players.PlayerRemoving:Connect(function(p)
	pendingRejoin[p] = nil
end)

RejoinOffer.OnServerEvent:Connect(function(p: Player, accept: any)
	local entry = pendingRejoin[p]
	pendingRejoin[p] = nil
	if not entry then
		return
	end
	if accept ~= true then
		pcall(function()
			matchMap:RemoveAsync("match_" .. p.UserId)
		end)
		return
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		if type(entry.code) == "string" then
			options.ReservedServerAccessCode = entry.code
		else
			options.ServerInstanceId = entry.jobId
		end
		options:SetTeleportData({ rejoin = true, difficulty = entry.difficulty })
		TeleportService:TeleportAsync(entry.placeId or GAME_PLACE_ID, { p }, options)
	end)
	if not ok then
		warn("[Lobby] Rejoin teleport failed: " .. tostring(err))
		Notice:FireClient(p, "กลับเข้าเกมเดิมไม่ได้ (เกมอาจจบไปแล้ว)", "Couldn't rejoin (the game may have ended)")
		pcall(function()
			matchMap:RemoveAsync("match_" .. p.UserId)
		end)
	end
end)
