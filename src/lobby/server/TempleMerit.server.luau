-- TempleMerit.server.luau
-- Mockup ก่อนมี Product ID: สวดมนต์ได้วันละครั้ง รับเครดิต 10 บาท แล้วร่วมทำบุญที่ตู้ได้ 10 บาท

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardStats"))
local store = DataStoreService:GetDataStore("TempleMerit_v1")
local profiles: { [Player]: { balance: number, prayerDay: string, donated: number } } = {}

local function key(player: Player): string
	return "u" .. player.UserId
end

local function today(): string
	return os.date("!%Y-%m-%d")
end

local function publish(player: Player)
	local profile = profiles[player]
	if profile then
		player:SetAttribute("TempleMerit", profile.balance)
		player:SetAttribute("TempleDonated", profile.donated)
	end
end

local function save(player: Player)
	local snapshot = profiles[player]
	if not snapshot then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				local data = if type(old) == "table" then old else {}
				data.balance = snapshot.balance
				data.prayerDay = snapshot.prayerDay
				data.donated = math.max(tonumber(data.donated) or 0, snapshot.donated)
				return data
			end)
		end)
		if not ok then
			warn("[TempleMerit] บันทึกไม่สำเร็จ:", err)
		end
	end)
end

local function load(player: Player)
	local profile = { balance = 0, prayerDay = "", donated = 0 }
	local ok, data = pcall(function()
		return store:GetAsync(key(player))
	end)
	if ok and type(data) == "table" then
		profile.balance = math.max(0, tonumber(data.balance) or 0)
		profile.prayerDay = type(data.prayerDay) == "string" and data.prayerDay or ""
		profile.donated = math.max(0, tonumber(data.donated) or 0)
	elseif not ok then
		warn("[TempleMerit] โหลดไม่ได้ ใช้ข้อมูลชั่วคราว:", data)
	end
	profiles[player] = profile
	publish(player)
end

local function notice(player: Player, th: string, en: string)
	local remotes = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = remotes and remotes:FindFirstChild("Notice")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, th, en)
	end
end

local function prayerPrompt(): ProximityPrompt?
	local lobby = workspace:FindFirstChild("TempleLobby")
	local plaques = lobby and lobby:FindFirstChild("BuddhaTrio_Plaques", true)
	if not plaques or not plaques:IsA("BasePart") then
		return nil
	end
	local prompt = plaques:FindFirstChild("DailyPrayerPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "DailyPrayerPrompt"
	prompt.ActionText = "สวดมนต์ · รับ 10 บาท/วัน"
	prompt.ObjectText = "พระประธาน"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = plaques
	return prompt
end

local function donationPrompt(): ProximityPrompt?
	local lobby = workspace:FindFirstChild("TempleLobby")
	local box = lobby and lobby:FindFirstChild("DonationBox", true)
	if not box or not box:IsA("BasePart") then
		return nil
	end
	local prompt = box:FindFirstChild("MockDonationPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "MockDonationPrompt"
	prompt.ActionText = "ร่วมทำบุญ 10 บาท · MOCK"
	prompt.ObjectText = "ตู้ร่วมทำบุญ"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	return prompt
end

task.spawn(function()
	for _ = 1, 30 do
		if workspace:FindFirstChild("TempleLobby") then
			break
		end
		task.wait(1)
	end
	local prayer = prayerPrompt()
	if prayer then
		prayer.Triggered:Connect(function(player)
			local profile = profiles[player]
			if not profile then
				return
			end
			if profile.prayerDay == today() then
				notice(player, "สวดมนต์วันนี้แล้ว กลับมาใหม่พรุ่งนี้", "You have prayed today. Please return tomorrow.")
				return
			end
			profile.prayerDay = today()
			profile.balance += 10
			publish(player)
			save(player)
			notice(player, "สวดมนต์สำเร็จ ได้รับ 10 บาท (เครดิตทดสอบ)", "Prayer complete. You received ฿10 mock credit.")
		end)
	end
	local donation = donationPrompt()
	if donation then
		donation.Triggered:Connect(function(player)
			local profile = profiles[player]
			if not profile or profile.balance < 10 then
				notice(player, "เครดิตไม่พอ · สวดมนต์หน้าพระเพื่อรับ 10 บาทก่อน", "Not enough credit. Pray at the Buddha statue first.")
				return
			end
			profile.balance -= 10
			profile.donated += 10
			publish(player)
			save(player)
			LeaderboardStats.Increment("donations", player.UserId, 10)
			notice(player, "ร่วมทำบุญ 10 บาทสำเร็จ (Mockup ยังไม่หัก Robux)", "Donated ฿10. Mockup only; no Robux charged.")
		end)
	end
end)

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(player)
	save(player)
	profiles[player] = nil
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end
