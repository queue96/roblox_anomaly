-- DevCommand.luau — compile check: hair-safe flicker fade (SceneryGhosts) + instant veil for haired ghosts (PrayerController)
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function compile(inst: Instance?, label: string)
	if not inst or not inst:IsA("LuaSourceContainer") then
		print("DEVCMD|COMPILE " .. label .. " MISSING")
		return
	end
	local m = Instance.new("ModuleScript")
	m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. (inst :: any).Source
	m.Parent = ServerStorage
	local ok, err = pcall(require, m)
	m:Destroy()
	print("DEVCMD|COMPILE " .. label .. " " .. (if ok then "ok" else ("FAIL " .. tostring(err))))
end

return {
	id = "hair_flicker_compile_3",
	placeId = 114125276809667,
	run = function()
		local client = StarterPlayer.StarterPlayerScripts.Client
		compile(client:FindFirstChild("SceneryGhosts"), "SceneryGhosts")
		compile(client:FindFirstChild("PrayerController"), "PrayerController")
		local n = {}
		for _, m in ipairs(ServerStorage.GhostTemplates:GetChildren()) do
			for _, d in ipairs(m:GetChildren()) do
				if d:IsA("BasePart") and string.find(d.Name, "Hair") then
					table.insert(n, m.Name .. ":" .. d.Name)
				end
			end
		end
		print("DEVCMD|hair parts: " .. #n)
		local k = ServerStorage.GhostTemplates.ghost_kuman_thong
		print("DEVCMD|kuman v2=" .. tostring(k:FindFirstChild("LowerWide") ~= nil) .. " archived old=" .. tostring(ServerStorage.ArchivedPlaceholders:FindFirstChild("ghost_kuman_thong_v1") ~= nil)
			.. " batterybox in ws=" .. tostring(workspace:FindFirstChild("BatteryBox", true) ~= nil))
	end,
}
