--!strict
-- TempleMerit.server.luau — Lobby: ตู้ร่วมทำบุญ (Robux)
--   ผู้ใช้ 2026-11-23: ตัดระบบสวดมนต์หน้าพระรับ 10 บาท (Mockup) ออก · ตู้ทำบุญรับ Robux จริง ยอดตามที่ตั้งใน shared/RobuxShop.DONATE_PRODUCTS
--   กดที่ตู้ = เปิดหน้าต่างเลือกยอด (lobby/client/ShopMenu แท็บทำบุญ) -> Developer Product
--   ProcessReceipt ของ Lobby อยู่ที่นี่ที่เดียว · ยอดสะสมขึ้นป้ายผู้ร่วมทำบุญสูงสุด (LeaderboardStats "donations" หน่วย Robux)
--   กันนับซ้ำ: เก็บ PurchaseId ล่าสุดของแต่ละคนใน DataStore (Roblox อาจส่งใบเสร็จเดิมซ้ำถ้าตอบช้า)
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LeaderboardStats = require(Shared:WaitForChild("LeaderboardStats")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any

local store = DataStoreService:GetDataStore("TempleDonate_v1")

-- remote ให้ client เปิดหน้าต่างทำบุญ (lobby/client/ShopMenu)
local remotes = ReplicatedStorage:FindFirstChild("TempleRemotes") or Instance.new("Folder")
remotes.Name = "TempleRemotes"
remotes.Parent = ReplicatedStorage
local openDonate = remotes:FindFirstChild("OpenDonate") or Instance.new("RemoteEvent")
openDonate.Name = "OpenDonate"
openDonate.Parent = remotes

local AMOUNT: { [number]: number } = {}
for _, d in ipairs(IDS.DONATE_PRODUCTS) do
	if d.id ~= 0 then
		AMOUNT[d.id] = d.amount
	end
end

local function notice(player: Player, key: string)
	local e = LanguageModule.UI[key]
	local lobbyRemotes = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = lobbyRemotes and lobbyRemotes:FindFirstChild("Notice")
	if e and remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, e.th, e.en)
	end
end

-- ---------------------------------------------------------------- ตู้ร่วมทำบุญ
task.spawn(function()
	local lobby = workspace:WaitForChild("TempleLobby", 30)
	if not lobby then
		return
	end
	-- ปุ่มสวดมนต์เดิม (ถ้ามีค้างในไฟล์ place) เอาออก
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("ProximityPrompt") and (d.Name == "DailyPrayerPrompt" or d.Name == "MockDonationPrompt") then
			d:Destroy()
		end
	end
	local box = lobby:FindFirstChild("DonationBox", true)
	if box and box:IsA("Model") then
		box = box.PrimaryPart or box:FindFirstChildWhichIsA("BasePart", true)
	end
	if not (box and box:IsA("BasePart")) then
		warn("[TempleMerit] ไม่เจอตู้ร่วมทำบุญ (TempleLobby.DonationBox)")
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DonatePrompt"
	local a, o = LanguageModule.UI.DonatePrompt, LanguageModule.UI.DonateBoxName
	Bilingual.Prompt(prompt, a.th, a.en, o.th, o.en, {
		id = { a.id, o.id },
		pt = { a.pt, o.pt },
		es = { a.es, o.es },
	})
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player: Player)
		openDonate:FireClient(player)
	end)
end)

-- ---------------------------------------------------------------- ใบเสร็จ
MarketplaceService.ProcessReceipt = function(info)
	local amount = AMOUNT[info.ProductId]
	if not amount then
		warn("[TempleMerit] ไม่รู้จักสินค้า", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local fresh, total = false, 0
	local ok, err = pcall(function()
		store:UpdateAsync("u" .. info.PlayerId, function(old)
			fresh = false
			local data = if type(old) == "table" then old else {}
			local ids = if type(data.ids) == "table" then data.ids else {}
			for _, id in ipairs(ids) do
				if id == info.PurchaseId then
					total = tonumber(data.total) or 0
					return nil -- ใบเสร็จนี้นับไปแล้ว
				end
			end
			table.insert(ids, info.PurchaseId)
			while #ids > 30 do
				table.remove(ids, 1)
			end
			data.ids = ids
			data.total = (tonumber(data.total) or 0) + amount
			total = data.total
			fresh = true
			return data
		end)
	end)
	if not ok then
		warn("[TempleMerit] บันทึกยอดทำบุญไม่สำเร็จ จะลองใหม่:", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if fresh then
		LeaderboardStats.Increment("donations", info.PlayerId, amount)
		if player then
			notice(player, "Donate_Thanks")
		end
	end
	if player then
		player:SetAttribute("TempleDonated", total)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
