-- LobbyServer.server.luau
-- สคริปต์ฝั่ง Server ของ place "Lobby" (Start Place) — sync ผ่าน lobby.project.json พอร์ต 34873
-- 1) บรรยากาศวัดร้างตอนเที่ยงคืน
-- 2) โซนสร้างห้อง: เดินเข้าวง RoomPad ที่ว่าง = เป็นเจ้าของห้อง เลือกจำนวนผู้เล่น (1–6) + ความยาก
--    คนอื่นเดินเข้าวงเดียวกัน = เข้าห้อง (จนเต็ม), เดินออกจากวง = ออกจากห้อง (เจ้าของออก = ปิดห้อง)
--    เจ้าของห้องกด "เริ่มเกม" = ReserveServer + TeleportAsync ไป Pump Lot ทันที
--    พร้อม TeleportData { roomId, difficulty, maxPlayers, hostUserId } (ดูสัญญาใน Shared.Difficulty)
--    ไม่กดเริ่มใน 30 วิ = ปิดห้อง ดีดทุกคนกลับจุดเกิด ต้องสร้างใหม่ · กดยกเลิก/ไม่ตั้งห้องใน 30 วิ = ดีดกลับจุดเกิด

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
MapBuilder.SetNightLighting()
-- แสงจันทร์จางๆ พอเห็นรูปทรงอาคารทั้งวัด (มืดกว่านี้แล้วกลางลานดำสนิท)
Lighting.Brightness = 0.6
Lighting.Ambient = Color3.fromRGB(24, 28, 36)
Lighting.OutdoorAmbient = Color3.fromRGB(36, 42, 54)
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
if atmo then
	atmo.Density = 0.45
	atmo.Haze = 2.2
	atmo.Color = Color3.fromRGB(95, 108, 120)
	atmo.Decay = Color3.fromRGB(36, 46, 58)
end
-- หมอกหนาทึบ: เห็นชัดในลาน แต่ป่ารอบวัดค่อยๆ จมหายในหมอก (ไม่เห็นขอบแมพ)
Lighting.FogColor = Color3.fromRGB(46, 52, 60)
Lighting.FogStart = 35
Lighting.FogEnd = 230
if atmo then
	atmo.Density = 0.55
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
grade.Saturation = -0.35
grade.Contrast = 0.12
grade.Brightness = -0.03
grade.TintColor = Color3.fromRGB(215, 225, 240)
grade.Parent = Lighting

-- ---------------------------------------------------------------- 2) โซนสร้างห้อง
local COUNTDOWN = 30 -- วินาทีที่เจ้าของห้องต้องกดเริ่ม (และเวลาตั้งห้องในหน้าต่างเลือก)
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
	launching: boolean,
}

local pads: { BasePart } = {}
local rooms: { [BasePart]: Room } = {}
local pendingHost: { [BasePart]: Player } = {}
local pendingSince: { [BasePart]: number } = {}
local onPad: { [Player]: BasePart? } = {}
local cooldownUntil: { [Player]: number } = {}

-- ป้ายลอยเหนือวง (Server แก้ข้อความ ทุกคนเห็นตรงกัน)
local function ensureSign(pad: BasePart): TextLabel
	local gui = pad:FindFirstChild("RoomSign") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "RoomSign"
		-- ลอยสูงเหนือวง + AlwaysOnTop ไม่ให้ตัวหนังสือจมพื้น/โดนหมอกกลืน
		g.Size = UDim2.fromScale(14, 4.5)
		g.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
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
		label.Text = ("ห้อง %d · %s\n%s · %d/%d คน\nรอเริ่มเกม · ปิดใน %d วิ"):format(i, room.host.DisplayName, d.th, #room.members, room.maxPlayers, room.countdown)
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

local function closeRoom(pad: BasePart, th: string, en: string)
	local room = rooms[pad]
	if not room then
		return
	end
	rooms[pad] = nil
	for _, p in ipairs(room.members) do
		RoomState:FireClient(p, nil)
		Notice:FireClient(p, th, en)
		cooldownUntil[p] = os.clock() + REJOIN_COOLDOWN
	end
	refresh(pad)
end

local function leaveRoom(player: Player, pad: BasePart)
	if pendingHost[pad] == player then
		pendingHost[pad] = nil
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
	RoomState:FireClient(player, nil)
	refresh(pad)
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
			return
		end
		table.insert(room.members, player)
		refresh(pad)
	elseif not pendingHost[pad] then
		pendingHost[pad] = player
		pendingSince[pad] = os.clock()
		OpenSetup:FireClient(player, pad:GetAttribute("PadIndex"), COUNTDOWN)
		refresh(pad)
	end
end

local function launch(room: Room)
	room.launching = true
	refresh(room.pad)
	local data = {
		roomId = room.id,
		difficulty = room.difficulty,
		maxPlayers = room.maxPlayers,
		hostUserId = room.host.UserId,
	}
	if IS_STUDIO then
		print(("🚚 [Lobby] (Studio) จะส่ง %d คนไป PlaceId %d | %s"):format(#room.members, GAME_PLACE_ID, HttpService:JSONEncode(data)))
		for _, p in ipairs(room.members) do
			Notice:FireClient(p, "เทสใน Studio: Teleport ใช้ไม่ได้ ดูข้อมูลห้องใน Output", "Studio test: teleport is disabled, see Output")
		end
		local list = table.clone(room.members)
		closeRoom(room.pad, "ห้องถูกรีเซ็ต (เทสใน Studio)", "Room reset (Studio test)")
		for _, p in ipairs(list) do
			sendToSpawn(p)
		end
		return
	end
	local ok, err = pcall(function()
		local code = TeleportService:ReserveServer(GAME_PLACE_ID)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(GAME_PLACE_ID, room.members, options)
	end)
	if not ok then
		warn("[Lobby] Teleport ไม่สำเร็จ: " .. tostring(err))
		closeRoom(room.pad, "ส่งไปเกมไม่สำเร็จ ลองใหม่อีกครั้ง", "Teleport failed, please try again")
		return
	end
	print(("🚚 [Lobby] ส่ง %d คนไปเกม | %s"):format(#room.members, HttpService:JSONEncode(data)))
	-- ห้องปิดเมื่อผู้เล่นออกจากเซิร์ฟเวอร์ไปแล้ว (PlayerRemoving) หรือครบ 15 วิ ถ้า Teleport ค้าง
	task.delay(15, function()
		if rooms[room.pad] == room then
			closeRoom(room.pad, "ส่งไปเกมไม่สำเร็จ ลองใหม่อีกครั้ง", "Teleport failed, please try again")
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
	pendingHost[pad] = nil
	local room: Room = {
		id = HttpService:GenerateGUID(false),
		pad = pad,
		host = player,
		members = { player },
		maxPlayers = math.clamp(math.floor(maxPlayers), 1, Difficulty.MaxPlayers),
		difficulty = difficulty,
		countdown = COUNTDOWN,
		launching = false,
	}
	rooms[pad] = room
	-- คนที่ยืนรออยู่ในวงก่อนแล้วได้เข้าห้องเลย
	for other, p in pairs(onPad) do
		if p == pad and other ~= player then
			enterPad(other, pad)
		end
	end
	refresh(pad)
end)

CancelSetup.OnServerEvent:Connect(function(player: Player)
	local pad = onPad[player]
	if pad and pendingHost[pad] == player then
		pendingHost[pad] = nil
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
			-- ทำงานเฉพาะตอนเดินเข้า/ออกวง (ยืนแช่ไม่ทำซ้ำ) คนที่ยืนรอขณะเจ้าของตั้งห้องจะถูกดึงเข้าตอนกดยืนยัน
			if now ~= before then
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
			-- ห้องที่เจ้าของไม่กดเริ่มใน 30 วิ: ปิดห้อง ดีดทุกคนกลับจุดเกิด
			for pad, room in pairs(rooms) do
				if not room.launching then
					room.countdown -= 1
					if room.countdown <= 0 then
						local list = table.clone(room.members)
						closeRoom(pad, "หมดเวลา ห้องถูกปิด สร้างห้องใหม่ได้", "Time's up, the room closed. Create a new one")
						for _, p in ipairs(list) do
							sendToSpawn(p)
						end
					else
						refresh(pad)
					end
				end
			end
			-- หน้าต่างตั้งห้องค้างเกิน 30 วิ: ปิดหน้าต่าง ดีดกลับจุดเกิด
			for pad, p in pairs(pendingHost) do
				if os.clock() - (pendingSince[pad] or 0) > COUNTDOWN then
					pendingHost[pad] = nil
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
