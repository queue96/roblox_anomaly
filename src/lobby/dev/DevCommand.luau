-- DevCommand.luau — compile check: natural low flashlight hold (HeadTurn / HUDController / HeadTurnOthers)
local function compile(src: Instance?, name: string)
	if not src then
		print("DEVCMD|COMPILE " .. name .. " MISSING")
		return
	end
	local s = (src :: any).Source
	s = string.gsub(s, "\n[ \t]*%-%-[^\n]*", "\n")
	local m = Instance.new("ModuleScript")
	m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. s
	local ok, err = pcall(require, m)
	print("DEVCMD|COMPILE " .. name .. " " .. (if ok then "OK" else "FAIL " .. tostring(err)))
end
return {
	id = "flash_hold_revert_20261116a",
	placeId = 114125276809667,
	run = function()
		local sps = game:GetService("StarterPlayer").StarterPlayerScripts
		compile(game:GetService("ReplicatedStorage").Shared:FindFirstChild("HeadTurn"), "HeadTurn")
		compile(sps:FindFirstChild("HUDController", true), "HUDController")
		compile(sps:FindFirstChild("HeadTurnOthers", true), "HeadTurnOthers")
	end,
}
