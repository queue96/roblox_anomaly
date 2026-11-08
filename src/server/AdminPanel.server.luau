--!strict
-- AdminPanel.server.luau
-- โหมด admin: เรียกอีเวนต์ / ลูกค้า / ผีแต่ละตัวได้ทันทีโดยไม่ต้องรอสุ่ม (แผงอยู่ใน client/AdminPanel.client.luau, กด F2)
--   ใช้ได้เฉพาะ: ใน Studio, เจ้าของ experience, หรือ user ใน ADMINS
--   คำสั่งส่งต่อให้ CoreLoop ผ่าน ServerStorage.DevDecision (BindableEvent เดียวกับที่ใช้ทดสอบจาก Command Bar)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local AnomalyManager = require(script.Parent:WaitForChild("AnomalyManager"))

local ADMINS = {
	[5022620650] = true, -- queue966 (เจ้าของ experience)
	[8243838297] = true, -- Aunival_Games
}

-- คำสั่งที่กดได้ (ชื่อตรงกับที่ CoreLoop รับใน DevDecision)
local ALLOWED = {
	walker = true, car = true, tuktuk = true, bicycle = true, spawn = true, shelter = true,
	racer = true, party = true, parade = true,
	rain = true, clear = true, powercut = true,
	lose = true, -- ทุกคนตาย (แพ้ทั้งร้าน: ธูปหมด)
	-- 2026-11-03
	shopready = true, -- จัดร้านพร้อมขายทันที
	fuelempty = true, fuelfull = true, -- น้ำมันในตู้หมด / เต็ม
	hungry = true, offer = true, dessert = true, -- ศาลหมดเวลาคุ้มครอง / ถวายแล้ว / แจกขนม
	["curse:shake"] = true, ["curse:slow"] = true, ["curse:stumble"] = true,
	intro = true, win = true, -- คัทซีนเปิดคืน / ชนะทันที (คัทซีนเช้า + สรุปผล)
	["scenery:Tani"] = true, ["scenery:Scarecrow"] = true, ["scenery:Shadow"] = true, ["scenery:hide"] = true, -- ผีฉาก
}

-- ผีใหญ่ (เดิมปุ่มบนแผงส่งไปแต่ไม่อยู่ใน ALLOWED จึงกดแล้วไม่มีอะไรเกิดขึ้น)
local BIG = { ["big:Krasue"] = true, ["big:Pret"] = true, ["big:Funeral"] = true, ["big:Pop"] = true }

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local AdminRemote = remotes:FindFirstChild("Admin") or Instance.new("RemoteEvent")
AdminRemote.Name = "Admin"
AdminRemote.Parent = remotes

local function isAdmin(p: Player): boolean
	return RunService:IsStudio() or ADMINS[p.UserId] == true or (game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId)
end

local function devDecision(): BindableEvent
	return ServerStorage:WaitForChild("DevDecision") :: BindableEvent
end

-- รายชื่อผีให้แผงแสดงปุ่ม
ReplicatedStorage:SetAttribute("AdminAnomalies", HttpService:JSONEncode(AnomalyManager.Keys))

local function onPlayer(p: Player)
	if isAdmin(p) then
		p:SetAttribute("Admin", true)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

local last: { [Player]: number } = {}
AdminRemote.OnServerEvent:Connect(function(p: Player, cmd: any)
	if not isAdmin(p) or type(cmd) ~= "string" then
		return
	end
	if last[p] and os.clock() - last[p] < 0.3 then
		return -- กันกดรัว
	end
	last[p] = os.clock()
	-- คัทซีนแบบกำหนดจำนวนคน (Studio): "intro@3" / "win@5" = ผู้เล่นจริง + หุ่นทดสอบเติมให้ครบ (Cutscene.luau อ่าน attribute ครั้งเดียวแล้วล้าง)
	local cutKind, cutN = string.match(cmd, "^(%a+)@(%d)$")
	if (cutKind == "intro" or cutKind == "win") and RunService:IsStudio() then
		local n = math.clamp(tonumber(cutN) or 0, 1, 6)
		devDecision():SetAttribute("CutsceneDummies", math.max(0, n - #Players:GetPlayers()))
		devDecision():Fire(cutKind)
		print(string.format("🛠️ [Admin %s] %s", p.Name, cmd))
		return
	end
	local key = string.match(cmd, "^anomaly:(.+)$")
	local killId = tonumber(string.match(cmd, "^kill:(%d+)$") or "")
	local reviveId = tonumber(string.match(cmd, "^revive:(%d+)$") or "")
	if killId then
		-- ให้ผู้เล่นคนนี้ตาย (ตัวเองหรือคนอื่นในห้อง): ล้มนอน จอตาย เลือกเกิดใหม่ (เฉพาะคนนั้น) หรือกลับ Lobby
		if not Players:GetPlayerByUserId(killId) then
			return
		end
		devDecision():Fire("kill:" .. killId)
	elseif reviveId then
		-- ชุบคนที่ตาย (คนเดียว): ลุกขึ้นตรงที่ล้ม เล่นต่อ
		if not Players:GetPlayerByUserId(reviveId) then
			return
		end
		devDecision():Fire("revive:" .. reviveId)
	elseif key then
		if not AnomalyManager.Anomalies[key] then
			return
		end
		if AnomalyManager.NeedsRain(key) then
			devDecision():Fire("rain")
		end
		devDecision():SetAttribute("ForceAnomaly", key) -- ลูกค้าคันถัดไปเป็นผีตัวนี้
		devDecision():Fire(AnomalyManager.KindFor(key) == "walker" and "walker" or "spawn")
	elseif cmd == "testmode:on" or cmd == "testmode:off" then
		-- โหมดทดสอบ: เกมไม่สุ่มอะไรเอง (ลูกค้า ขาจร ฝน ไฟดับ ผีใหญ่ ผีฉาก สวดเรียกผี ศาลหลอก) มีแต่ที่กดจากแผงนี้
		-- อ่านจาก ReplicatedStorage attribute "TestMode" (CoreLoop / Weather / client SceneryGhosts / HauntEffects)
		ReplicatedStorage:SetAttribute("TestMode", cmd == "testmode:on")
	elseif BIG[cmd] then
		devDecision():Fire(cmd) -- ผีใหญ่บุกประชิด (CoreLoop รับ "big:<ชื่อ>")
	elseif ALLOWED[cmd] then
		devDecision():Fire(cmd)
	else
		return
	end
	print(string.format("🛠️ [Admin %s] %s", p.Name, cmd))
end)
