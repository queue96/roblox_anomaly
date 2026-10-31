-- DevCommand.luau — Idle
return {
	id = "idle_" .. tostring(os.time()),
	run = function()
		print("DEVCMD|ALL_SYNCED_READY")
	end,
}
