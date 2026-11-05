--!strict
-- MatchGuard.server.luau (place เกม Pump Lot) — ใครเข้าเซิร์ฟเวอร์เกมนี้ได้บ้าง + หลุดแล้วกลับมาได้
--   เข้าได้เฉพาะสมาชิกห้องที่ Lobby ส่งมา (TeleportData.members) หรือสมาชิกที่หลุดแล้วกลับมา (TeleportData.rejoin)
--   คนอื่น (กด "เข้าร่วม" ตามเพื่อนจากหน้าโปรไฟล์ / เปิด place เกมตรงๆ) -> ส่งกลับ Lobby ทันที
--   สมาชิกที่อยู่ในเกม: จดไว้ใน MemoryStore (match_<UserId>) ว่าอยู่เซิร์ฟเวอร์ไหน
--     หลุดเกม (ไม่ได้กดกลับ Lobby เอง) แล้วเปิดเกมใหม่ -> Lobby ถามว่าจะกลับเข้าเกมเดิมไหม (LobbyServer: RejoinOffer)
--     ออกเอง (กดกลับ Lobby / ยอมแพ้: attribute LeftOnPurpose) -> ลบที่จดไว้
--   เซิร์ฟเวอร์ยังอยู่ไหม: alive_<JobId> ต่ออายุทุก 30 วิ (หมดอายุ 90 วิ) ทุกคนหลุดหมด เซิร์ฟเวอร์ปิด = กลับเข้าไม่ได้แล้ว
-- Studio: ไม่ตรวจ (ทดสอบในเครื่องไม่มี TeleportData)
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 70980777393906
local ENTRY_TTL = 3 * 60 * 60 -- จดว่าอยู่เกมไหนไว้นานสุด 3 ชั่วโมง
local ALIVE_TTL = 90
local ALIVE_EVERY = 30

if RunService:IsStudio() then
	return
end

local map = MemoryStoreService:GetSortedMap("PumpLotMatches")

-- สมาชิกของเซิร์ฟเวอร์นี้ (UserId) + รหัสเข้าเซิร์ฟเวอร์ (ReservedServerAccessCode) ที่ Lobby ส่งมา
local members: { [number]: boolean } = {}
local accessCode: string? = nil
local difficulty: any = nil

local function joinData(p: Player): { [string]: any }?
	local ok, data = pcall(function()
		return p:GetJoinData().TeleportData
	end)
	return if ok and type(data) == "table" then data else nil
end

local function remember(p: Player)
	local entry = {
		placeId = game.PlaceId,
		jobId = game.JobId,
		code = accessCode,
		difficulty = difficulty,
	}
	task.spawn(function()
		pcall(function()
			map:SetAsync("match_" .. p.UserId, entry, ENTRY_TTL)
		end)
	end)
end

local function forget(userId: number)
	task.spawn(function()
		pcall(function()
			map:RemoveAsync("match_" .. userId)
		end)
	end)
end

local function sendAway(p: Player)
	print("🚪 [MatchGuard] " .. p.Name .. " ไม่ได้อยู่ในห้องนี้ -> ส่งกลับ Lobby")
	local ok = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { p })
	end)
	if not ok then
		p:Kick(if p.LocaleId:sub(1, 2) == "th" then "เข้าเกมได้จากวัด (Lobby) เท่านั้น" else "Please join from the temple Lobby.")
	end
end

local function onJoin(p: Player)
	local data = joinData(p)
	-- ห้องที่ Lobby ส่งมา: คนแรกที่มาถึงตั้งรายชื่อสมาชิกของเซิร์ฟเวอร์นี้
	if data and type(data.members) == "table" then
		for _, id in ipairs(data.members) do
			if type(id) == "number" then
				members[id] = true
			end
		end
		if type(data.accessCode) == "string" and accessCode == nil then
			accessCode = data.accessCode
		end
		if difficulty == nil then
			difficulty = data.difficulty
		end
	end
	-- ข้อมูลห้องแบบเก่า (Lobby รุ่นก่อนไม่ส่ง members): มีข้อมูลห้อง = มาจาก Lobby จริง ให้เข้าได้
	local legacy = data ~= nil and data.members == nil and data.roomId ~= nil
	if members[p.UserId] or legacy then
		members[p.UserId] = true
		remember(p)
		return
	end
	sendAway(p)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(p)
	-- ออกเอง = ไม่ต้องชวนกลับ / หลุด (ปิดแอป เน็ตหลุด) = เก็บไว้ให้กลับเข้ามาได้
	if p:GetAttribute("LeftOnPurpose") == true then
		forget(p.UserId)
	end
end)

-- บอกว่าเซิร์ฟเวอร์นี้ยังเปิดอยู่
task.spawn(function()
	while true do
		pcall(function()
			map:SetAsync("alive_" .. game.JobId, true, ALIVE_TTL)
		end)
		task.wait(ALIVE_EVERY)
	end
end)
game:BindToClose(function()
	pcall(function()
		map:RemoveAsync("alive_" .. game.JobId)
	end)
end)
