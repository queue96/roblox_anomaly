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
}

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
	local key = string.match(cmd, "^anomaly:(.+)$")
	if key then
		if not AnomalyManager.Anomalies[key] then
			return
		end
		if AnomalyManager.NeedsRain(key) then
			devDecision():Fire("rain")
		end
		devDecision():SetAttribute("ForceAnomaly", key) -- ลูกค้าคันถัดไปเป็นผีตัวนี้
		devDecision():Fire(AnomalyManager.KindFor(key) == "walker" and "walker" or "spawn")
	elseif ALLOWED[cmd] then
		devDecision():Fire(cmd)
	else
		return
	end
	print(string.format("🛠️ [Admin %s] %s", p.Name, cmd))
end)
