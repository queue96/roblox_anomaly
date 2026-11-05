--!strict
-- SacredGuard.server.luau
-- กันผู้เล่นปีน/ยืนบนของศักดิ์สิทธิ์: พระพุทธรูป, เจดีย์ (BoneStupa), ศาลพระภูมิ, ต้นไทร
-- ใช้ทั้งสอง place: แมพเกม (default.project.json -> src/server) และ Lobby (lobby.project.json แมพไฟล์นี้เข้า Server)
--
-- วิธี: เสา "SacredBlocker" ล่องหนครอบรอยฐานของแต่ละชิ้น สูงจากฐานขึ้นไปเหนือยอดอีก PILLAR_ABOVE studs
--   ผนังตั้งตรงเรียบ ปีนไม่ได้ และยอดเสาสูงเกินระยะกระโดด จึงขึ้นไปยืนบนของชิ้นนั้นไม่ได้
--   CanQuery = false: raycast / กล้อง / ProximityPrompt (ถวายขนมที่ศาล, สวดมนต์หน้าพระ) มองทะลุเสา ใช้งานได้ตามเดิม
--   ชนผู้เล่นเท่านั้น (กลุ่ม SacredBlock ไม่ชนกลุ่ม NPC) ลูกค้า/ผีในแมพเกมไม่ติดเสา
--   พื้นรอบๆ เดินได้ตามเดิม เพราะเสามีขนาดเท่ารอยฐานของชิ้นนั้นเอง
-- รากต้นไทร (BanyanRoots) แผ่กว้างบนพื้น: ปิดการชนแทน (เดินผ่านรากบนพื้นได้ แต่ขึ้นไปยืนบนรากไม่ได้)
-- ชิ้นอื่นที่อยากกันเพิ่ม: ใส่ tag "Sacred" (CollectionService) ที่ Model หรือ BasePart นั้น

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")

local GROUP = "SacredBlock"
local PILLAR_ABOVE = 20 -- สูงเหนือยอดของชิ้น (กระโดดได้ราว 7 studs)
local PAD = 0.3 -- เผื่อขอบรอบรอยฐานเล็กน้อย

if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

-- กลุ่ม NPC (server/CollisionGroups ในแมพเกม) อาจลงทะเบียนทีหลัง: ตั้งให้ไม่ชนเมื่อพบ
local function ignoreNpc()
	if PhysicsService:IsCollisionGroupRegistered("NPC") then
		PhysicsService:CollisionGroupSetCollidable(GROUP, "NPC", false)
	end
end

-- ชื่อที่ถือว่าศักดิ์สิทธิ์ (ทั้งก้อนเป็นเสาเดียว)
local function isSacredName(inst: Instance): boolean
	local n = inst.Name
	if inst:IsA("Model") then
		return n:match("^BuddhaTrio") ~= nil -- พระประธาน 3 องค์ + ฐาน (ศาลา / โบสถ์ใน Lobby)
			or n:match("^BoneStupa_") ~= nil -- เจดีย์บรรจุอัฐิใน Lobby
	elseif inst:IsA("BasePart") then
		return n:match("^SpiritHouseOnStilts") ~= nil -- ศาลพระภูมิ (ทั้งสอง place)
			or n == "TempleGate_Buddha" -- พระบนซุ้มประตูวัด
			or n == "BanyanTrunk" -- ลำต้นไทร (ทั้งสอง place)
	end
	return false
end

local folder = workspace:FindFirstChild("SacredBlockers") or Instance.new("Folder")
folder.Name = "SacredBlockers"
folder.Parent = workspace

local done: { [Instance]: boolean } = {}

local function partsOf(inst: Instance): { BasePart }
	local list = {}
	if inst:IsA("BasePart") then
		table.insert(list, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- เสาตั้งตรง หมุนเฉพาะแกน Y ตามชิ้นหลัก ครอบมุมทั้ง 8 ของทุกชิ้นในก้อน
local function addPillar(target: Instance)
	if done[target] then
		return
	end
	local parts = partsOf(target)
	if #parts == 0 then
		return
	end
	done[target] = true
	local main: BasePart = parts[1]
	if target:IsA("Model") and target.PrimaryPart then
		main = target.PrimaryPart
	else
		for _, p in ipairs(parts) do
			if p.Size.Magnitude > main.Size.Magnitude then
				main = p
			end
		end
	end
	local look = main.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local frame = CFrame.lookAt(main.Position, main.Position + flat.Unit)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, p in ipairs(parts) do
		local h = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local w = p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
					local l = frame:PointToObjectSpace(w)
					minV = minV:Min(l)
					maxV = maxV:Max(l)
				end
			end
		end
	end
	local top = maxV.Y + PILLAR_ABOVE
	local size = Vector3.new(maxV.X - minV.X + PAD * 2, top - minV.Y, maxV.Z - minV.Z + PAD * 2)
	local center = Vector3.new((maxV.X + minV.X) / 2, (top + minV.Y) / 2, (maxV.Z + minV.Z) / 2)

	local b = Instance.new("Part")
	b.Name = "SacredBlocker_" .. target.Name
	b.Anchored = true
	b.CanCollide = true
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
	b.Transparency = 1
	b.Size = size
	b.CFrame = frame * CFrame.new(center)
	b.CollisionGroup = GROUP
	b:SetAttribute("Guards", target:GetFullName())
	b.Parent = folder
end

local function consider(inst: Instance)
	if not inst:IsDescendantOf(workspace) or inst:IsDescendantOf(folder) then
		return
	end
	if inst:IsA("BasePart") and inst.Name == "BanyanRoots" then
		inst.CanCollide = false
		return
	end
	if isSacredName(inst) or CollectionService:HasTag(inst, "Sacred") then
		-- ชิ้นที่อยู่ใต้ก้อนที่กันไว้แล้วไม่ต้องทำซ้ำ
		local p = inst.Parent
		while p and p ~= workspace do
			if done[p] then
				return
			end
			p = p.Parent
		end
		addPillar(inst)
	end
end

local function scan()
	ignoreNpc()
	for _, d in ipairs(workspace:GetDescendants()) do
		consider(d)
	end
end

scan()
CollectionService:GetInstanceAddedSignal("Sacred"):Connect(consider)
-- ฉากบางส่วนโหลด/สร้างทีหลัง (และกลุ่ม NPC ลงทะเบียนทีหลัง): สแกนซ้ำอีกรอบ
task.delay(5, scan)
print(("[SacredGuard] กันปีนของศักดิ์สิทธิ์ %d ชิ้น"):format(#folder:GetChildren()))
