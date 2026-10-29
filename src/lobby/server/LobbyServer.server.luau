-- LobbyServer.server.luau
-- สคริปต์ฝั่ง Server ของ place "Lobby" (Start Place) — sync ผ่าน lobby.project.json พอร์ต 34873
-- 1) บรรยากาศวัดร้างตอนเที่ยงคืน
-- 2) โซนสร้างห้อง: เดินเข้าวง RoomPad ที่ว่าง = เป็นเจ้าของห้อง เลือกจำนวนผู้เล่น (1–6) + ความยาก
--    คนอื่นเดินเข้าวงเดียวกัน = เข้าห้อง (จนเต็ม), ระหว่างรอถูกกั้นในวงและออกจากปุ่ม UI เท่านั้น
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
end
Players.PlayerAdded:Connect(function(p)
	p.CameraMaxZoomDistance = MAX_ZOOM
end)

local grade = Lighting:FindFirstChild("LobbyGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "LobbyGrade"
grade.Saturation = -0.42
grade.Contrast = 0.16
grade.Brightness = -0.03
grade.TintColor = Color3.fromRGB(194, 211, 232)
grade.Parent = Lighting
local bloom = Lighting:FindFirstChild("LobbyBloom") or Instance.new("BloomEffect")
bloom.Name = "LobbyBloom"
bloom.Intensity = 0.35
bloom.Size = 28
bloom.Threshold = 1.1
bloom.Parent = Lighting

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

-- กำแพงม่านพลังรอบวง (TempleLobby.RoomPads.RoomPadWall_n จาก MapBuilder): เปิดตอนกำลังตั้งห้อง
local function setWall(pad: BasePart, on: boolean)
	local wall = pad.Parent and pad.Parent:FindFirstChild("RoomPadWall_" .. tostring(pad:GetAttribute("PadIndex")))
	if not wall then
		return
	end
	for _, w in ipairs(wall:GetChildren()) do
		if w:IsA("BasePart") then
			w.CanCollide = on
			w.Transparency = if on then 0.15 else 1
		end
	end
end
local function setPending(pad: BasePart, player: Player?)
	pendingHost[pad] = player
	pendingSince[pad] = if player then os.clock() else nil
	setWall(pad, player ~= nil)
end
local onPad: { [Player]: BasePart? } = {}
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
		t.TextColor3 = Color3.fromRGB(235, 220, 200)
		t.TextStrokeTransparency = 0.3
		t.Font = Enum.Font.GothamMedium
		t.TextScaled = true
		t.Parent = g
		g.Parent = pad
		gui = g
	else
		gui.Adornee = anchor
		gui.StudsOffset = Vector3.zero
		gui.StudsOffsetWorldSpace = Vector3.zero
	end
	return (gui :: BillboardGui):FindFirstChild("Text") :: TextLabel
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
		local d = Difficulty.Get(room.difficulty)
		if room.launching then
			label.Text = ("ห้อง %d · %s\n%s · %d/%d คน\nกำลังส่งไปเกม..."):format(i, room.host.DisplayName, d.th, #room.members, room.maxPlayers)
		elseif room.fullCountdown then
			label.Text = ("ห้อง %d · %s\n%s · %d/%d คน\nเต็มแล้ว · ไปเกมใน %d"):format(i, room.host.DisplayName, d.th, #room.members, room.maxPlayers, room.fullCountdown)
		else
			label.Text = ("ห้อง %d · %s\n%s · %d/%d คน\nรอผู้เล่น · เริ่มใน %d วิ"):format(i, room.host.DisplayName, d.th, #room.members, room.maxPlayers, room.countdown)
		end
		label.TextColor3 = d.color
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
		label.Text = ("ห้อง %d\n%s กำลังตั้งห้อง..."):format(i, pendingHost[pad].DisplayName)
		label.TextColor3 = Color3.fromRGB(235, 220, 200)
	else
		label.Text = ("ห้อง %d · ว่าง\nเดินเข้าวงเพื่อสร้างห้อง\nRoom %d · walk in to host"):format(i, i)
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
		startFullCountdown(room)
		refresh(pad)
	elseif not pendingHost[pad] then
		setPending(pad, player)
		OpenSetup:FireClient(player, pad:GetAttribute("PadIndex"), SETUP_COUNTDOWN)
		refresh(pad)
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
	}
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
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
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

ConfirmRoom.OnServerEvent:Connect(function(player: Player, maxPlayers: any, difficulty: any)
	local pad = onPad[player]
	if not pad or pendingHost[pad] ~= player or rooms[pad] then
		return
	end
	if type(maxPlayers) ~= "number" or not Difficulty.IsValid(difficulty) then
		return
	end
	setPending(pad, nil)
	local room: Room = {
		id = HttpService:GenerateGUID(false),
		pad = pad,
		host = player,
		members = { player },
		maxPlayers = math.clamp(math.floor(maxPlayers), 1, Difficulty.MaxPlayers),
		difficulty = difficulty,
		countdown = WAITING_COUNTDOWN,
		fullCountdown = nil,
		fullDeadline = nil,
		launching = false,
	}
	rooms[pad] = room
	-- ผู้เล่นที่เข้าห้องถูกกั้นไว้จนกว่าจะกดออกจาก UI หรือเกมเริ่ม
	setWall(pad, true)
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
		if p:IsA("BasePart") and not table.find(pads, p) then
			table.insert(pads, p)
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
			if not isRoomMember and now ~= before then
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

print(("✅ [Lobby] Server พร้อม | ปลายทาง PlaceId %d | Studio = %s"):format(GAME_PLACE_ID, tostring(IS_STUDIO)))
