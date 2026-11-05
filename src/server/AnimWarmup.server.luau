--!strict
-- AnimWarmup.server.luau — Server ดึงข้อมูลท่าทุกท่ามาเก็บไว้ตั้งแต่เปิดเซิร์ฟเวอร์
--   ผี/ลูกค้าเป็นของ Server (Animator ฝั่ง Server เล่นท่า) ครั้งแรกที่ LoadAnimation ต้องรอดาวน์โหลดท่า
--   (HumanNPC.swapTo รอจน track.Length > 0) -> ช่วงนั้นตัวค้างท่าเดิม/ท่า A ดูโหลดไม่ทัน
--   ดึงล่วงหน้าด้วย KeyframeSequenceProvider ให้ครั้งแรกที่ใช้จริงพร้อมเล่นทันที
-- ฝั่ง Client โหลดเองด้วย (client/AnimPreload)
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local ids: { string } = {}
local seen: { [string]: boolean } = {}
for _, name in ipairs({ "HumanAnimIds", "GhostAnimIds" }) do
	local mod = shared:WaitForChild(name, 10)
	local ok, set = pcall(require, mod)
	if ok and type(set) == "table" then
		for _, clips in pairs(set) do
			if type(clips) == "table" then
				for _, id in pairs(clips) do
					if type(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://" and not seen[id] then
						seen[id] = true
						table.insert(ids, id)
					end
				end
			end
		end
	end
end

-- ทีละ 6 ท่าพร้อมกัน ไม่ถล่มคำขอ
local t0 = os.clock()
local done, failed = 0, 0
local running = 0
for _, id in ipairs(ids) do
	while running >= 6 do
		task.wait()
	end
	running += 1
	task.spawn(function()
		local ok = pcall(function()
			KeyframeSequenceProvider:GetKeyframeSequenceAsync(id)
		end)
		if ok then
			done += 1
		else
			failed += 1
		end
		running -= 1
	end)
end
while running > 0 do
	task.wait()
end
print(("🎞️ [Server] อุ่นท่าไว้ล่วงหน้า %d/%d ท่า (%.1f วิ)%s"):format(done, #ids, os.clock() - t0, if failed > 0 then " ไม่สำเร็จ " .. failed else ""))
