--!strict
-- PoseHooks.luau (ReplicatedStorage.Shared) — งานที่ต้องทำ "หลัง" client/HumanEmotesRunner เขียนท่าลงกระดูกเฟรมนี้แล้ว
-- เช่น client/HeldItems วางของตรงมือ: ถ้าแยกกันต่อ PreSimulation ลำดับไม่แน่นอน บางเฟรมของจะไปตามมือท่าเก่า
-- (ท่าเดิน/ห้อยแขน) -> แกลลอนสั่น ขนมหลุดออกจากมือ
local PoseHooks = {}

local hooks: { (number) -> () } = {}

-- คืนฟังก์ชันยกเลิก (สคริปต์ในตัวละครที่ถูกลบตอนเกิดใหม่ต้องเรียก ไม่งั้นค้างทำงานกับตัวเก่า)
function PoseHooks.After(fn: (number) -> ()): () -> ()
	table.insert(hooks, fn)
	return function()
		local i = table.find(hooks, fn)
		if i then
			table.remove(hooks, i)
		end
	end
end

-- เรียกโดย HumanEmotesRunner ทุกเฟรม หลังเขียนท่าครบทุกตัว
function PoseHooks.Run(dt: number)
	for _, fn in ipairs(hooks) do
		local ok, err = pcall(fn, dt)
		if not ok then
			warn("[PoseHooks]", err)
		end
	end
end

return PoseHooks
