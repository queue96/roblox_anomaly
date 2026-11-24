-- PlayerSettings.server.luau
-- การตั้งค่าของผู้เล่น (จำไว้ใน DataStore ครั้งหน้าเข้ามาใช้ค่าเดิม) อยู่เป็น Attribute บนตัว Player:
--   Lang        "th"|"en"|"id"|"pt"|"es"  เข้าครั้งแรก: ตามประเทศ (LanguageModule.FromCountry) ไม่ก็ภาษาเครื่อง นอกนั้น "en"
--   ShowHUD     boolean       แสดงเงิน / ธูป / ป้ายปุ่มคีย์ (คำพูดลูกค้าและแถบประกาศแสดงเสมอ)
--   ShowLabels  boolean       แสดงป้ายชื่อตามวัตถุในฉาก (ZoneLabel)
--   ShowTutorial boolean      แสดงการ์ดสอนเล่น (ปิดได้ในหน้าตั้งค่า)
--   ShowTaskGlow boolean      ของที่ต้องทำเรืองแสง + ป้ายลอยบนของ ตลอดเวลาที่งานค้าง (TaskGlow)
--   FlashHand   "R" | "L"     มือที่ถือไฟฉาย (ค่าเริ่มต้นขวา) แกลลอน/ขนมอยู่มืออีกข้าง (shared/HeadTurn.Sides)
--   LangChosen  boolean       ผู้เล่นยืนยันภาษาเองแล้ว (หน้าเลือกภาษาครั้งแรกก่อนฉากเปิด Lobby)
--   TutSeen     string        เรื่องที่สอนเล่นไปแล้ว (คั่นด้วย ,) สอนแล้วไม่สอนซ้ำ (TutorialController)
-- Client เปลี่ยนค่าผ่าน Remotes.SetSetting:FireServer(name, value) (หน้าตั้งค่าใน SettingsController)

local DataStoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))

local STORE_NAME = "PlayerSettings_v1"
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
if not okStore then
	warn("[PlayerSettings] ใช้ DataStore ไม่ได้ จะไม่จำการตั้งค่า:", store)
	store = nil
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local setSetting = remotes:FindFirstChild("SetSetting") or Instance.new("RemoteEvent")
setSetting.Name = "SetSetting"
setSetting.Parent = remotes

-- ค่าเริ่มต้น + ตัวตรวจค่า (คืนค่าที่ถูกต้อง หรือ nil ถ้าใช้ไม่ได้)
local function bool(v: any): boolean?
	if type(v) == "boolean" then
		return v
	end
	return nil
end
local SETTINGS: { [string]: { default: any, check: (any) -> any } } = {
	Lang = {
		default = "en",
		check = function(v)
			-- ภาษาที่รองรับ (LanguageModule.Langs: th en id pt es)
			return if type(v) == "string" and table.find(LanguageModule.Langs, v) then v else nil
		end,
	},
	-- (MusicVolume / SfxVolume ตัดออกแล้ว ผู้ใช้ 2026-11-23 "ไม่ให้ผู้เล่นปรับเสียงเอง": ความดังตายตัวใน SettingsController)
	ShowHUD = { default = true, check = bool },
	ShowLabels = { default = true, check = bool },
	ShowTutorial = { default = true, check = bool }, -- ปิด = ไม่ขึ้นการ์ดสอนเล่นเลย (TutorialController)
	ShowTaskGlow = { default = true, check = bool }, -- ปิด = ของที่ต้องทำไม่เรืองแสง ไม่มีป้ายลอย (TaskGlow)
	FlashHand = {
		default = "R",
		check = function(v)
			return if v == "R" or v == "L" then v else nil
		end,
	},
	-- เลือกภาษาเองแล้วหรือยัง (หน้าเลือกภาษาก่อนฉากเปิด Lobby ครั้งแรก: LobbyIntro.client) ยืนยันแล้ว = ไม่ถามอีก
	LangChosen = { default = false, check = bool },
	-- เห็นคำแนะนำตั้งกราฟิกแล้ว (lobby/client/GraphicsTip ขึ้นครั้งเดียว)
	GfxTipSeen = { default = false, check = bool },
	-- เรื่องที่เคยสอนแล้ว (TutorialController): "flash,shop,gen,fuel,offer,ghost" สอนแล้วไม่สอนซ้ำ
	TutSeen = {
		default = "",
		check = function(v)
			return if type(v) == "string" and #v <= 120 and string.match(v, "^[%w_,]*$") then v else nil
		end,
	},
}

local function keyFor(player: Player): string
	return "u" .. player.UserId
end

-- ภาษาเริ่มต้นจากประเทศ / ภาษาเครื่อง
local function detectLanguage(player: Player): string
	local ok, region = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	-- ประเทศก่อน (ไทย / อินโดนีเซีย / บราซิล-โปรตุเกส / ประเทศที่พูดสเปน) แล้วค่อยภาษาเครื่อง ไม่ตรงอะไรเลย = อังกฤษ
	local fromCountry = if ok then LanguageModule.FromCountry(region) else nil
	if fromCountry then
		return fromCountry
	end
	return LanguageModule.Normalize(player.LocaleId)
end

local function load(player: Player): { [string]: any }?
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(keyFor(player))
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local inFlight = 0 -- จำนวนการบันทึกที่ยังไม่เสร็จ (ตอนปิดเซิร์ฟเวอร์ต้องรอให้เสร็จก่อน)
local function save(player: Player)
	if not store then
		return
	end
	local key = keyFor(player) -- อ่านไว้ก่อน (ผู้เล่นอาจออกไปแล้วตอนบันทึกจริง)
	local snapshot = {}
	for name in pairs(SETTINGS) do
		snapshot[name] = player:GetAttribute(name)
	end
	inFlight += 1
	task.spawn(function()
		local ok, err
		for attempt = 1, 3 do -- ลองใหม่ได้ 3 ครั้ง (DataStore ล่มชั่วคราว / โดนจำกัดความถี่)
			ok, err = pcall(function()
				store:UpdateAsync(key, function(old)
					local data = if type(old) == "table" then old else {}
					for k, v in pairs(snapshot) do
						data[k] = v
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
			warn("[PlayerSettings] บันทึกการตั้งค่าไม่สำเร็จ:", err)
		end
		inFlight -= 1
	end)
end

local function onPlayer(player: Player)
	local saved = load(player)
	local firstTime = saved == nil or saved.Lang == nil
	for name, s in pairs(SETTINGS) do
		local v = saved and s.check(saved[name])
		if v == nil then
			v = if name == "Lang" then detectLanguage(player) else s.default
		end
		player:SetAttribute(name, v)
	end
	if firstTime then
		save(player) -- จำภาษาที่ตรวจได้ตอนเข้าครั้งแรก
	end
end

-- เปลี่ยนรัวๆ ได้ (เช่น ลากแถบเสียง) แต่บันทึกลง DataStore ครั้งเดียวหลังหยุด 3 วินาที
local pendingSave: { [Player]: number } = {}
setSetting.OnServerEvent:Connect(function(player: Player, name: any, value: any)
	local s = type(name) == "string" and SETTINGS[name]
	if not s then
		return
	end
	local v = s.check(value)
	if v == nil then
		return
	end
	player:SetAttribute(name, v)
	local token = (pendingSave[player] or 0) + 1
	pendingSave[player] = token
	task.delay(3, function()
		if pendingSave[player] == token and player.Parent then
			pendingSave[player] = nil
			save(player)
		end
	end)
end)

Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(p)
	if pendingSave[p] then
		pendingSave[p] = nil
		save(p)
	end
end)

-- เซิร์ฟเวอร์กำลังปิด (คนสุดท้ายออก / อัปเดตเกม): บันทึกที่ค้างอยู่ทั้งหมด แล้วรอให้เสร็จ (สูงสุด ~25 วิ)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		if pendingSave[p] then
			pendingSave[p] = nil
			save(p)
		end
	end
	local t0 = os.clock()
	while inFlight > 0 and os.clock() - t0 < 25 do
		task.wait(0.2)
	end
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
