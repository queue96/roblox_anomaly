-- PlayerSettings.server.luau
-- การตั้งค่าของผู้เล่น (จำไว้ใน DataStore ครั้งหน้าเข้ามาใช้ค่าเดิม) อยู่เป็น Attribute บนตัว Player:
--   Lang        "th" | "en"   เข้าครั้งแรก: มาจากประเทศไทย (หรือเครื่องตั้งภาษาไทย) = "th" นอกนั้น = "en"
--   MusicVolume 0..1          เสียงเพลง (วิทยุ / สวด)
--   SfxVolume   0..1          เสียงเอฟเฟกต์ (หมาหอน จิ้งหรีด ฯลฯ)
--   ShowHUD     boolean       แสดงเงิน / ธูป / ป้ายปุ่มคีย์ (คำพูดลูกค้าและแถบประกาศแสดงเสมอ)
--   ShowLabels  boolean       แสดงป้ายชื่อตามวัตถุในฉาก (ZoneLabel)
-- Client เปลี่ยนค่าผ่าน Remotes.SetSetting:FireServer(name, value) (หน้าตั้งค่าใน SettingsController)

local DataStoreService = game:GetService("DataStoreService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local function volume(v: any): number?
	if type(v) == "number" and v == v then
		return math.clamp(v, 0, 1)
	end
	return nil
end
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
			return if v == "th" or v == "en" then v else nil
		end,
	},
	MusicVolume = { default = 0.7, check = volume },
	SfxVolume = { default = 0.8, check = volume },
	ShowHUD = { default = true, check = bool },
	ShowLabels = { default = true, check = bool },
}

local function keyFor(player: Player): string
	return "u" .. player.UserId
end

-- ภาษาเริ่มต้นจากประเทศ / ภาษาเครื่อง
local function detectLanguage(player: Player): string
	local ok, region = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if ok and region == "TH" then
		return "th"
	end
	if string.sub(string.lower(player.LocaleId), 1, 2) == "th" then
		return "th"
	end
	return "en"
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

local function save(player: Player)
	if not store then
		return
	end
	local snapshot = {}
	for name in pairs(SETTINGS) do
		snapshot[name] = player:GetAttribute(name)
	end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(keyFor(player), function(old)
				local data = if type(old) == "table" then old else {}
				for k, v in pairs(snapshot) do
					data[k] = v
				end
				return data
			end)
		end)
		if not ok then
			warn("[PlayerSettings] บันทึกการตั้งค่าไม่สำเร็จ:", err)
		end
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
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
