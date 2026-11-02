--!strict
-- CollisionGroups.luau (ModuleScript ฝั่ง Server)
-- ผู้เล่นเดินทะลุลูกค้า / รถลูกค้า / คนหลบฝน / ขาจรบนถนนได้ ไม่ชนกัน (ไม่ติดขวางตอนเดินรอบตู้ปั๊ม)
--   กลุ่ม "Players" = ตัวผู้เล่น (server/PlayerVillager), กลุ่ม "NPC" = ทุกอย่างที่ CoreLoop เสกขึ้นมา
--   สองกลุ่มนี้ไม่ชนกัน ส่วนกับพื้น / ฉาก / ของอื่น ยังชนตามปกติ
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}

CollisionGroups.PLAYERS = "Players"
CollisionGroups.NPC = "NPC"

for _, g in ipairs({ CollisionGroups.PLAYERS, CollisionGroups.NPC }) do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable(CollisionGroups.PLAYERS, CollisionGroups.NPC, false)

-- ใส่ทุกชิ้นในโมเดลลงกลุ่ม รวมชิ้นที่ถูกเพิ่มทีหลัง (ร่ม แกลลอน จักรยานที่เข็นมา ฯลฯ)
function CollisionGroups.Set(model: Instance, group: string)
	local function apply(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	apply(model)
	for _, d in ipairs(model:GetDescendants()) do
		apply(d)
	end
	model.DescendantAdded:Connect(apply)
end

return CollisionGroups
