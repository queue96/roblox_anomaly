--!strict
-- PassShop.server.luau — Lobby: แผงขาย Game Pass หน้ารถเข็นขายของ (ShopCart_Main ข้างประตูวัด) (ผู้ใช้ 2026-11-23)
--   ไฟฉายตราช้าง / สวดมนต์ไว / รองเท้าแตะติดปีก ราคา 49 ทุกอัน (รหัสใน shared/RobuxShop)
--   เกมเดียวกับแมพปั๊ม: ซื้อที่นี่แล้วเข้าแมพปั๊มได้ผลทันที (server/RobuxShop.server ในแมพปั๊มเช็กให้ตอนเข้า)
--   ใน Lobby: ตั้ง player attribute ตามที่มี (client/PassShop ซ่อนปุ่มซื้อของที่มีแล้ว) + รองเท้าแตะเดินเร็วขึ้นที่นี่ด้วย

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any

local function ui(key: string): any
	return LanguageModule.UI[key]
end

local function notice(player: Player, key: string)
	local e = ui(key)
	local remotes = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = remotes and remotes:FindFirstChild("Notice")
	if e and remote and remote:IsA("RemoteEvent") then
		-- LobbyClient หาภาษาอื่นจาก LanguageModule.UI ด้วยข้อความอังกฤษ
		remote:FireClient(player, e.th, e.en)
	end
end

-- แผงขาย: lobby/server/PassStallBuilder (ใช้ร่วมกับ DevCommand ที่วางแผงในโหมด edit)
local Builder = require(script.Parent:WaitForChild("PassStallBuilder")) :: any
type Item = { attr: string, passId: number, sign: string, name: string, buy: string?, build: (CFrame, Instance) -> () }
local ITEMS: { Item } = Builder.ITEMS
local prompts: { [ProximityPrompt]: Item } = Builder.Build()

local GOT = { ElephantLight = "Shop_ElephantGot", FastPrayer = "Shop_FastPrayGot", WingSandals = "Shop_SandalsGot", GhostBook = "Shop_GhostBookGot", BigRoom = "Shop_BigRoomGot" }

-- ป้ายทอง "📖 หมอผี" ใน Lobby เป็นแถวบนสุดของป้ายชื่อ (lobby/server/LobbyNameplates)

-- ---------------------------------------------------------------- เจ้าของ Game Pass
local function applySandals(player: Player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed * (if player:GetAttribute("WingSandals") == true then IDS.SANDALS_SPEED else 1)
	end
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("WingSandals"):Connect(function()
		applySandals(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		applySandals(player)
	end)
	-- ทุก Game Pass (รวมห้องใหญ่ที่ไม่ได้วางบนแผง: ขายตรงหน้าตั้งห้อง)
	for _, item in ipairs(IDS.PASSES) do
		if item.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, item.id)
			if ok and owns then
				player:SetAttribute(item.attr, true)
			end
		end
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

for pr, item in pairs(prompts) do
	pr.Triggered:Connect(function(player: Player)
		if player:GetAttribute(item.attr) == true then
			notice(player, "Shop_Owned")
			return
		end
		if item.passId == 0 then
			warn("[PassShop] ยังไม่ได้ใส่รหัส Game Pass ของ " .. item.attr .. " ใน shared/RobuxShop")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, item.passId)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, item in ipairs(IDS.PASSES) do
		if item.id == passId then
			player:SetAttribute(item.attr, true)
			notice(player, GOT[item.attr])
		end
	end
end)
