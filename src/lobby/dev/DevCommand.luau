-- DevCommand.luau — compile check SceneryGhosts one scare (2026-11-17)
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
	id = "compile_scenery_one_scare_20261117d",
	placeId = 114125276809667,
	run = function()
		local sps = game:GetService("StarterPlayer").StarterPlayerScripts
		compile(sps:FindFirstChild("SceneryGhosts", true), "SceneryGhosts")
	end,
}
