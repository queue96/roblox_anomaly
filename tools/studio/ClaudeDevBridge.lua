-- ClaudeDevBridge.lua — local Studio plugin (copy to %LOCALAPPDATA%\Roblox\Plugins\)
-- รันคำสั่งจาก ServerStorage.DevCommand (ModuleScript ที่ Rojo sync มาจาก src/lobby/dev/DevCommand.luau)
-- ใน Edit mode ครั้งเดียวต่อ id ใหม่ แล้ว print ผลขึ้น Output (ขึ้นต้น DEVCMD|) ให้ AI อ่านจาก log ของ Studio ได้
-- DevCommand ต้อง return { id = "ไม่ซ้ำ", placeId = <PlaceId ที่จะรัน>, run = function() ... end }

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

if RunService:IsRunning() then
	return
end

local busy = false

local function tryRun(mod: Instance)
	if busy or not mod:IsA("ModuleScript") or mod.Parent ~= ServerStorage then
		return
	end
	local ok, cmd = pcall(require, mod:Clone())
	if not ok then
		warn("DEVCMD|load error: " .. tostring(cmd))
		return
	end
	if type(cmd) ~= "table" or type(cmd.id) ~= "string" or type(cmd.run) ~= "function" then
		return
	end
	if cmd.placeId and cmd.placeId ~= game.PlaceId then
		return
	end
	local key = "last_" .. tostring(game.PlaceId)
	if plugin:GetSetting(key) == cmd.id then
		return
	end
	plugin:SetSetting(key, cmd.id)
	busy = true
	print("DEVCMD|start " .. cmd.id)
	local rec = ChangeHistoryService:TryBeginRecording("DevCommand " .. cmd.id)
	local ran, err = pcall(cmd.run)
	if rec then
		ChangeHistoryService:FinishRecording(rec, if ran then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
	end
	busy = false
	if ran then
		print("DEVCMD|done " .. cmd.id)
	else
		warn("DEVCMD|error " .. cmd.id .. " " .. tostring(err))
	end
end

local watched: { [Instance]: boolean } = {}
local function watch(mod: Instance)
	if mod.Name ~= "DevCommand" or watched[mod] then
		return
	end
	watched[mod] = true
	mod:GetPropertyChangedSignal("Source"):Connect(function()
		task.delay(0.5, tryRun, mod)
	end)
	task.delay(0.5, tryRun, mod)
end

for _, c in ipairs(ServerStorage:GetChildren()) do
	watch(c)
end
ServerStorage.ChildAdded:Connect(watch)
print("DEVCMD|bridge ready in place " .. tostring(game.PlaceId))
