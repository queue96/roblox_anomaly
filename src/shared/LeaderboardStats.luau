-- LeaderboardStats.luau
-- สถิติแบบ OrderedDataStore ใช้ร่วมกันระหว่าง Pump Lot (เขียนสถิติ) และ Lobby (อ่านอันดับ)

local DataStoreService = game:GetService("DataStoreService")

local LeaderboardStats = {}

local STORES = {
	donations = "TempleDonationLeaderboard_v1",
	completions = "GameCompletionLeaderboard_v1",
	anomalies = "AnomalyCollectionLeaderboard_v1",
}

local stores: { [string]: OrderedDataStore } = {}

local function getStore(category: string): OrderedDataStore?
	local name = STORES[category]
	if not name then
		warn("[LeaderboardStats] ไม่รู้จักหมวดอันดับ: " .. category)
		return nil
	end
	if not stores[category] then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(name)
		end)
		if not ok then
			warn("[LeaderboardStats] เปิด OrderedDataStore ไม่สำเร็จ:", result)
			return nil
		end
		stores[category] = result
	end
	return stores[category]
end

function LeaderboardStats.Increment(category: string, userId: number, amount: number)
	if amount <= 0 then
		return
	end
	local store = getStore(category)
	if not store then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:IncrementAsync("u" .. tostring(userId), amount)
		end)
		if not ok then
			warn("[LeaderboardStats] บันทึกอันดับ " .. category .. " ไม่สำเร็จ:", err)
		end
	end)
end

function LeaderboardStats.GetTop(category: string, count: number): { { userId: number, value: number } }
	local store = getStore(category)
	if not store then
		return {}
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, count)
	end)
	if not ok then
		warn("[LeaderboardStats] อ่านอันดับ " .. category .. " ไม่สำเร็จ:", pages)
		return {}
	end
	local rows = {}
	for _, entry in ipairs((pages :: DataStorePages):GetCurrentPage()) do
		local userId = tonumber(string.match(entry.key, "^u(%d+)$"))
		if userId and type(entry.value) == "number" then
			table.insert(rows, { userId = userId, value = math.floor(entry.value) })
		end
	end
	return rows
end

return LeaderboardStats
