-- DevCommand.luau — compile SceneryGhosts after Tani is faint again
local function compile(name: string)
	local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild(name, true)
	local m = Instance.new("ModuleScript")
	m.Source = "local __skip = (game ~= nil)\nif __skip then return {} end\n" .. (src :: any).Source
	local ok, err = pcall(require, m)
	print("DEVCMD|COMPILE " .. name .. " " .. (if ok then "OK" else "FAIL " .. tostring(err)))
end
return {
	id = "tani_faint_compile_20261116zf",
	placeId = 114125276809667,
	run = function()
		compile("SceneryGhosts")
	end,
}
