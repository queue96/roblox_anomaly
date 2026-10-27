-- AnomalyBook.luau (ModuleScript ฝั่ง Server)
-- Phase 5 ข้อ 2: สมุดบันทึกผีไทย (Anomaly Collection Book)
--   รอดจากผีตัวไหน (ดึงแผงปิดร้านใส่ผีได้ถูกตัว) = ปลดล็อกผีตัวนั้นในสมุดของ "ทุกคนที่อยู่ในร้านตอนนั้น"
--   จำไว้ใน DataStore แยกต่อคน: { [anomalyKey] = จำนวนครั้งที่รอด }
--   ส่งให้ Client ทาง Attribute บน Player: "Book" = "Anomaly_Headless:2,Anomaly_Tani:1"
--   ปลดล็อกครั้งแรก -> Remotes.BookUnlocked:FireClient(player, key) ให้ขึ้นแจ้งเตือน
-- ทดสอบ: ServerStorage.DevDecision:Fire("book:Anomaly_Krasue") (ปลดให้ทุกคน) / Fire("bookreset")

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LeaderboardStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardStats"))

local AnomalyBook = {}

local STORE_NAME = "AnomalyBook_v1"
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not okStore then
	warn("[AnomalyBook] ใช้ DataStore ไม่ได้ สมุดจะไม่ถูกจำ:", store)
	store = nil
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local unlocked = remotes:FindFirstChild("BookUnlocked") or Instance.new("RemoteEvent")
unlocked.Name = "BookUnlocked"
unlocked.Parent = remotes

local books: { [Player]: { [string]: number } } = {}
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local inFlight = 0

local function keyFor(player: Player): string
	return "u" .. player.UserId
end

local function publish(player: Player)
	local parts = {}
	for k, n in pairs(books[player] or {}) do
		table.insert(parts, k .. ":" .. n)
	end
	table.sort(parts)
	player:SetAttribute("Book", table.concat(parts, ","))
end

local function save(player: Player)
	if not store or not loaded[player] then
		return
	end
	dirty[player] = nil
	local key = keyFor(player)
	local snapshot = table.clone(books[player] or {})
	inFlight += 1
	task.spawn(function()
		local ok, err
		for attempt = 1, 3 do
			ok, err = pcall(function()
				store:UpdateAsync(key, function(old)
					-- รวมกับของเดิม (เผื่อเล่นหลายเซิร์ฟเวอร์พร้อมกัน): เอาจำนวนครั้งที่มากกว่า
					local data = if type(old) == "table" then old else {}
					for k, n in pairs(snapshot) do
						data[k] = math.max(tonumber(data[k]) or 0, n)
					end
					return data
				end)
			end)
			if ok then
				break
			end
			task.wait(attempt * 1.5)
		end
		if not ok then
			warn("[AnomalyBook] บันทึกสมุดไม่สำเร็จ:", err)
		end
		inFlight -= 1
	end)
end

local function load(player: Player)
	local data = {}
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok and type(result) == "table" then
			for k, n in pairs(result) do
				if type(k) == "string" and tonumber(n) then
					data[k] = tonumber(n) :: number
				end
			end
		end
	end
	books[player] = data
	loaded[player] = true
	publish(player)
end

-- รอดจากผี key: ปลดล็อก/นับเพิ่มให้ผู้เล่นทุกคนในเซิร์ฟเวอร์
function AnomalyBook.Survived(key: string)
	for _, p in ipairs(Players:GetPlayers()) do
		local b = books[p]
		if b then
			local first = (b[key] or 0) == 0
			b[key] = (b[key] or 0) + 1
			publish(p)
			dirty[p] = true
			if first then
				LeaderboardStats.Increment("anomalies", p.UserId, 1)
				unlocked:FireClient(p, key)
				print("📘 [" .. p.Name .. "] ปลดล็อกผีในสมุด: " .. key)
			end
		end
	end
	-- บันทึกทันที (สมุดเปลี่ยนไม่บ่อย)
	for _, p in ipairs(Players:GetPlayers()) do
		if dirty[p] then
			save(p)
		end
	end
end

-- ล้างสมุด (ทดสอบ)
function AnomalyBook.Reset()
	for _, p in ipairs(Players:GetPlayers()) do
		books[p] = {}
		publish(p)
		if store then
			pcall(function()
				store:RemoveAsync(keyFor(p))
			end)
		end
	end
end

Players.PlayerAdded:Connect(load)
Players.PlayerRemoving:Connect(function(p)
	if dirty[p] then
		save(p)
	end
	task.delay(30, function()
		books[p] = nil
		loaded[p] = nil
		dirty[p] = nil
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(load, p)
end

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		if dirty[p] then
			save(p)
		end
	end
	local t0 = os.clock()
	while inFlight > 0 and os.clock() - t0 < 25 do
		task.wait(0.2)
	end
end)

return AnomalyBook
