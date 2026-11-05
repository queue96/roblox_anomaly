--!strict
-- AnimPreload.client.luau — โหลดท่าทุกท่า (ชาวบ้าน + ผี) ไว้ตั้งแต่เข้าเกม
--   ท่าอยู่เป็นเลข id ในโมดูล (HumanAnimIds / GhostAnimIds) ไม่ใช่ Animation ในฉาก หน้าโหลดจึงไม่เคยโหลดให้
--   เดิมโหลดตอนผี/ลูกค้าจะขยับ -> โหลดไม่ทัน ตัวค้างท่า A / ท่าเดิมแวบหนึ่ง (ผู้ใช้ 2026-11-05)
--   โหลดทีละชุดเบาๆ เบื้องหลัง ไม่บล็อกการเล่น (หน้าโหลดยังทำงานของมันตามปกติ)
-- ฝั่ง Server อุ่นท่าไว้ด้วยเหมือนกัน (server/AnimWarmup)
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local sets: { any } = {}
for _, name in ipairs({ "HumanAnimIds", "GhostAnimIds" }) do
	local mod = shared:WaitForChild(name, 10)
	if mod then
		local ok, t = pcall(require, mod)
		if ok and type(t) == "table" then
			table.insert(sets, t)
		end
	end
end

local seen: { [string]: boolean } = {}
local anims: { Animation } = {}
for _, set in ipairs(sets) do
	for _, clips in pairs(set) do
		if type(clips) == "table" then
			for _, id in pairs(clips) do
				if type(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://" and not seen[id] then
					seen[id] = true
					local a = Instance.new("Animation")
					a.AnimationId = id
					table.insert(anims, a)
				end
			end
		end
	end
end

-- ท่าที่ใช้บ่อยก่อน (ชาวบ้านเดิน/ยืน/ขับรถ) เรียงตามลำดับโมดูลแล้ว ส่งทีละ 20
local BATCH = 20
task.spawn(function()
	local t0 = os.clock()
	for i = 1, #anims, BATCH do
		local batch = table.move(anims, i, math.min(i + BATCH - 1, #anims), 1, {})
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		task.wait()
	end
	print(("🎞️ [Client] โหลดท่าไว้ล่วงหน้า %d ท่า (%.1f วิ)"):format(#anims, os.clock() - t0))
	-- ตัวผี (mesh / ผิว) ใน ReplicatedStorage.GhostModels: หน้าโหลดโหลดให้แล้ว แต่ถ้ากดข้ามหน้าโหลดจะไม่ครบ -> โหลดต่อเบื้องหลัง
	local models = ReplicatedStorage:WaitForChild("GhostModels", 30)
	if models then
		local list: { Instance } = {}
		for _, d in ipairs(models:GetDescendants()) do
			if d:IsA("MeshPart") or d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
				table.insert(list, d)
			end
		end
		for i = 1, #list, BATCH do
			local batch = table.move(list, i, math.min(i + BATCH - 1, #list), 1, {})
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			task.wait()
		end
	end
end)
