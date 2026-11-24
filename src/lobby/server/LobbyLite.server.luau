--!strict
-- LobbyLite.server.luau — ลดของในฉาก Lobby ตอนเปิดเซิร์ฟเวอร์ ก่อนผู้เล่นเข้า (ผู้ใช้ 2026-11-23: Lobby อยู่ไม่นาน ไม่ต้องสวยสุด)
--   ไฟล์ place ไม่ถูกแก้: ลบตอนรันเท่านั้น อยากได้คืนแค่แก้ค่าด้านล่าง
--   ต้นป่าเป็น mesh แล้ว (2026-11-24 MapBuilder.SwapMangoLeavesV2) ข้อ 2 จึงมีผลเฉพาะต้นป่าที่ยังเป็นแผ่น LeafCard · ต้นในลาน 4 ต้นยังเป็นแผ่นเดิม (ข้อ 3)
--   1) ป่ารอบวัด (TempleLobby.Forest): ต้นที่ไกลจากกลางลานเกิน FOREST_KEEP studs (ท้ายหมอก) ลบทั้งต้น
--   2) ป่าที่เหลือ (อยู่หลังหมอก ไม่ใช่มะม่วง 4 ต้นในลาน): ใบเหลือครึ่งเดียว (ลบแผ่นเว้นแผ่น)
--   3) แผ่นใบนอนทุกต้น: ไม่ต้องมีรูปด้านบน (ผู้เล่นยืนบนพื้น มองเห็นแต่ใต้ใบ)
local Workspace = game:GetService("Workspace")

local FOREST_KEEP = 225 -- studs จากกลางลาน: ต้นที่ไกลกว่านี้ลบ · math.huge = เก็บทุกต้น
local THIN_FOREST = true -- ป่าหลังหมอก: ใบเหลือครึ่ง
local DROP_LEAF_TOP = true -- แผ่นใบนอน: ลบรูปด้านบน
local PLAZA_CENTER = Vector3.new(0, 0, 32)

local lobby = Workspace:WaitForChild("TempleLobby", 30)
if not lobby then
	return
end

-- กำแพงล่องหนรอบแมพ (TempleLobby.InvisibleWalls): ในไฟล์ place เป็นสีฟ้าใสให้ผู้พัฒนาเห็นและลากย้าย/ยืดได้ในโหมด edit
--   (ผู้ใช้ 2026-11-23) ตอนเล่นซ่อนทั้งหมด ชนเหมือนเดิม
do
	local walls = lobby:FindFirstChild("InvisibleWalls")
	if walls then
		for _, w in ipairs(walls:GetDescendants()) do
			if w:IsA("BasePart") then
				w.Transparency = 1
				w.CastShadow = false
				w.CanCollide = true
				w.Anchored = true
			end
		end
	end
end

local t0 = os.clock()
local removedTrees, removedParts, removedDecals = 0, 0, 0
local function countGone(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			removedParts += 1
		elseif d:IsA("Decal") then
			removedDecals += 1
		end
	end
end

local forest = lobby:FindFirstChild("Forest")
if forest then
	for _, tree in ipairs(forest:GetChildren()) do
		local cf = if tree:IsA("Model") then tree:GetPivot() elseif tree:IsA("BasePart") then tree.CFrame else nil
		if cf and (Vector3.new(cf.X, 0, cf.Z) - PLAZA_CENTER).Magnitude > FOREST_KEEP then
			-- 1) ไกลเกิน: ลบทั้งต้น
			countGone(tree)
			removedTrees += 1
			tree:Destroy()
		elseif THIN_FOREST then
			-- 2) ใบเหลือครึ่ง (แผ่นเว้นแผ่น ตามลำดับในต้น: กระจายทั่วพุ่ม ไม่แหว่งเป็นด้าน)
			local i = 0
			for _, d in ipairs(tree:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "LeafCard" then
					i += 1
					if i % 2 == 0 then
						countGone(d)
						removedParts += 1
						d:Destroy()
					end
				end
			end
		end
	end
end

-- 3) แผ่นใบนอน: ลบรูปด้านบน
if DROP_LEAF_TOP then
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("Decal") and d.Face == Enum.NormalId.Top and d.Parent and d.Parent.Name == "LeafCard" then
			removedDecals += 1
			d:Destroy()
		end
	end
end

print(string.format("🌿 [LobbyLite] ลบต้นไม้ไกล %d ต้น · ชิ้นส่วน %d · รูปใบ %d · %.2f วิ", removedTrees, removedParts, removedDecals, os.clock() - t0))
