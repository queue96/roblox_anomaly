--!strict
-- GhostBook.server.luau — สมุดหมอผี (Game Pass 499, ผู้ใช้ 2026-11-23): ผู้เล่นที่มี Pass เรียกผีได้เอง
--   เฉพาะส่วนเรียกผี (ไม่มีปุ่มชนะ/แพ้/ฆ่า/เสกของ เหมือนแผง admin)
--   ลูกค้าผี: เลือกตัวได้ มาเป็นคันถัดไป · ผีใหญ่บุก (กระสือ / เปรต) · ผีวนรอบร้าน (ปิดแผงให้เอง) · ผีฉาก (เห็นคนเดียว: client ทำเอง)
--   กติกา: 1 ครั้งต่อ shared/RobuxShop.BOOK_COOLDOWN วินาทีต่อคน · ต้องเปิดร้านแล้ว เกมยังไม่จบ ไม่อยู่ในคัทซีน
--          ผีที่เรียกไม่ได้เงิน ไม่ปลดล็อกสมุดผี ไม่นับกระดานอันดับ (CoreLoop: Customer.fromBook / Big.fromBook)
--          เรียกของที่คนอื่นเห็นได้ = ขึ้นข้อความบอกทั้งห้อง (ไม่บอกว่าผีตัวไหน ยังต้องสังเกตเอง)
-- client/GhostBook เรียก Remotes.GhostBook:InvokeServer(kind, arg) -> (ok, reasonKey?, seconds?)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notice = remotes:WaitForChild("Notice") :: RemoteEvent
local fn = remotes:FindFirstChild("GhostBook") or Instance.new("RemoteFunction")
fn.Name = "GhostBook"
fn.Parent = remotes

local function listHas(list: { string }, v: any): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

local CUSTOMERS: { string } = {}
for _, k in ipairs(LanguageModule.BookOrder) do
	if string.sub(k, 1, 8) == "Anomaly_" then
		table.insert(CUSTOMERS, k)
	end
end

-- ป้ายทอง "📖 หมอผี" เหนือหัวคนที่มีสมุด (คนอื่นเห็น ตัวเองไม่เห็น)
IDS.WatchShamanTags(1.6)

local lastUse: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(p)
	lastUse[p] = nil
end)

local function shopRunning(): boolean
	return remotes:GetAttribute("ShopOpen") == true
		and remotes:GetAttribute("GameOver") ~= true
		and ReplicatedStorage:GetAttribute("CutsceneRunning") ~= true
end

local function announce(by: Player)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= by then
			Notice:FireClient(p, "GBook_Summoned", 5, { name = by.DisplayName })
		end
	end
end

fn.OnServerInvoke = function(player: Player, kind: any, arg: any): (boolean, string?, number?)
	if player:GetAttribute("GhostBook") ~= true then
		return false, nil, nil
	end
	local now = os.clock()
	local left = IDS.BOOK_COOLDOWN - (now - (lastUse[player] or -math.huge))
	if left > 0 then
		return false, "GBook_Cooldown", math.ceil(left)
	end
	local devDecision = ServerStorage:FindFirstChild("DevDecision") :: BindableEvent?
	local CoreLoop = require(script.Parent:WaitForChild("CoreLoop")) :: any
	if kind == "scenery" then
		-- ผีฉากเกิดบนเครื่องคนเรียกคนเดียว: server แค่นับคูลดาวน์ให้ (client ตั้ง SceneryTest เอง)
		if not (listHas(IDS.BOOK_SCENERY, arg) or arg == "ScarecrowClose") or not shopRunning() then
			return false, "GBook_NotNow", nil
		end
	elseif kind == "customer" then
		local AnomalyManager = require(script.Parent:WaitForChild("AnomalyManager")) :: any
		if not listHas(CUSTOMERS, arg) or not AnomalyManager.Anomalies[arg] or not shopRunning() or not devDecision or CoreLoop.Big.running then
			return false, "GBook_NotNow", nil
		end
		devDecision:SetAttribute("ForceAnomaly", arg)
		devDecision:SetAttribute("ForceFromBook", true)
		devDecision:Fire(if AnomalyManager.KindFor(arg) == "walker" then "walker" else "ghost")
		announce(player)
	elseif kind == "big" then
		if not listHas(IDS.BOOK_BIG, arg) or not shopRunning() or not devDecision or CoreLoop.Big.running or remotes:GetAttribute("BigEvent") ~= nil then
			return false, "GBook_NotNow", nil
		end
		CoreLoop.Big.fromBook = true
		devDecision:Fire("big:" .. arg)
		announce(player)
	elseif kind == "linger" then
		if not listHas(IDS.BOOK_LINGER, arg) or not shopRunning() or not devDecision or CoreLoop.Big.running then
			return false, "GBook_NotNow", nil
		end
		devDecision:Fire("linger:" .. arg)
		announce(player)
	else
		return false, nil, nil
	end
	lastUse[player] = now
	print(string.format("📖 [สมุดหมอผี %s] %s:%s", player.Name, tostring(kind), tostring(arg)))
	return true, nil, nil
end

-- ทดสอบจากแผง admin: ServerStorage.RobuxShopTest "ghostbook" สลับมี/ไม่มี (server/RobuxShop)
