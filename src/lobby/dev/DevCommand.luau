-- DevCommand.luau — คำสั่งที่ ClaudeDevBridge (plugin) รันใน Studio ครั้งเดียวต่อ id ใหม่ (Edit mode เท่านั้น)
-- ไม่ถูกรันตอนเล่นเกม; ผลลัพธ์ print ขึ้นต้น DEVCMD| ให้อ่านจาก log ของ Studio

return {
	id = "clean-archive-1",
	placeId = 70980777393906,
	run = function()
		local arch = game:GetService("ServerStorage"):FindFirstChild("ArchivedPlaceholders")
		local folder = arch and arch:FindFirstChild("TempleLobby")
		local n = folder and #folder:GetChildren() or 0
		if folder then
			folder:Destroy()
		end
		if arch and #arch:GetChildren() == 0 then
			arch:Destroy()
		end
		local spooky = workspace.TempleLobby:FindFirstChild("SpookyDecor")
		local counts = {}
		for _, c in ipairs(spooky:GetChildren()) do
			local k = c.Name:gsub("_%d+$", "")
			counts[k] = (counts[k] or 0) + 1
		end
		local list = {}
		for k, v in pairs(counts) do
			table.insert(list, k .. "×" .. v)
		end
		table.sort(list)
		print("DEVCMD|removed archived lobbies: " .. n)
		print("DEVCMD|SpookyDecor: " .. table.concat(list, ", "))
	end,
}
