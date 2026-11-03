--!strict
-- PromptFacing.client.luau
-- เลือกว่าปุ่มกด (ProximityPrompt) อันไหนกดได้บนเครื่องนี้ — ทุกปุ่มใน Workspace:
--   1) ต้องเดินเข้าไปใกล้ในระยะของปุ่ม (attribute Range ถ้า server ตั้งไว้ ไม่งั้นใช้ MaxActivationDistance เดิม)
--   2) ปุ่มที่ server ติด NeedsFacing: ต้องหันกล้องไปทางวัตถุนั้นด้วย
--   3) ห้ามกดทะลุผนัง: ยิง ray จากกล้องไปหาวัตถุ ถ้าชนอย่างอื่นที่ทึบก่อน (ผนัง ชั้นวาง) = กดไม่ได้
--   4) ขึ้นปุ่มแค่อันเดียว: วัตถุที่ใกล้ที่สุด (ปุ่มหลายอันบนวัตถุเดียวกัน เช่น ตู้น้ำมัน E/F ขึ้นพร้อมกันได้)
--   5) ของในมือ: attribute NeedsTool = ต้องถือ Tool ชื่อนี้อยู่ในมือก่อน (ถวายขนม / ตัก-เท-เติมน้ำมันด้วยแกลลอน)
--                HideIfHasTool = มี Tool ชื่อนี้แล้ว (ในมือหรือกระเป๋า) ไม่ต้องขึ้นปุ่มหยิบอีก
-- ทำฝั่ง client โดยตั้ง MaxActivationDistance ของปุ่มในเครื่องนี้ (0 = กดไม่ได้) server ยังเช็กซ้ำตอนกดเสมอ
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local LOOK_COS = math.cos(math.rad(50)) -- ต้องมองให้วัตถุอยู่ไม่เกิน 50° จากกลางจอ (ตู้ใหญ่: มองหัวจ่ายก็นับ)
local CHECK_EVERY = 0.1
local OWNER_MAX_SIZE = 25 -- Model ที่ติดปุ่มใหญ่กว่านี้ (ทั้งร้าน/ทั้งลาน) ไม่นับเป็น "ตัววัตถุ" ตอนเช็กผนังบัง

type Info = { base: number, set: number? }
local prompts: { [ProximityPrompt]: Info } = {}

local function track(d: Instance)
	if d:IsA("ProximityPrompt") and not prompts[d] then
		prompts[d] = { base = d.MaxActivationDistance }
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do
	track(d)
end
Workspace.DescendantAdded:Connect(track)
Workspace.DescendantRemoving:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		prompts[d] = nil
	end
end)

local function targetPos(p: ProximityPrompt): Vector3?
	local parent = p.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

-- "ตัววัตถุ" ของปุ่ม: ชิ้นที่ติดปุ่ม + Model ที่ใกล้ที่สุดที่ครอบอยู่ (ไม่ใหญ่เกิน) — ray ชนพวกนี้ = มองเห็นวัตถุ
local ownerCache: { [ProximityPrompt]: Instance } = setmetatable({}, { __mode = "k" }) :: any
local function ownerOf(p: ProximityPrompt): Instance?
	local o = ownerCache[p]
	if o and o.Parent then
		return o
	end
	local parent = p.Parent
	if parent and parent:IsA("Attachment") then
		parent = parent.Parent
	end
	if not parent then
		return nil
	end
	local owner: Instance = parent
	local m = parent:FindFirstAncestorOfClass("Model")
	if m and m ~= Workspace and m:GetExtentsSize().Magnitude < OWNER_MAX_SIZE then
		owner = m
	end
	ownerCache[p] = owner
	return owner
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function canSee(from: Vector3, p: ProximityPrompt, pos: Vector3, char: Model): boolean
	local owner = ownerOf(p)
	local ignore: { Instance } = { char }
	if owner then
		table.insert(ignore, owner)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		table.insert(ignore, cam)
	end
	for _ = 1, 8 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, pos - from, rayParams)
		if not hit then
			return true
		end
		local inst = hit.Instance
		-- ของโปร่ง/ไม่มีตัวตน (ใบไม้ แสง ม่าน ผู้เล่นคนอื่น) ไม่นับว่าบัง
		local model = inst:FindFirstAncestorOfClass("Model")
		local see = inst.Transparency > 0.6 or not inst.CanCollide or (model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil)
		if not see then
			return false
		end
		table.insert(ignore, inst)
	end
	return true
end

local function hasTool(char: Model, name: string, equippedOnly: boolean): boolean
	local t = char:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return true
	end
	if equippedOnly then
		return false
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return t ~= nil and t:IsA("Tool")
end

local function setRange(p: ProximityPrompt, info: Info, want: number)
	-- server เปลี่ยนค่าเอง (ไม่ใช่ค่าที่เราตั้ง) = ใช้เป็นระยะใหม่
	if info.set ~= nil and p.MaxActivationDistance ~= info.set then
		info.base = p.MaxActivationDistance
	end
	if p.MaxActivationDistance ~= want then
		p.MaxActivationDistance = want
	end
	info.set = want
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < CHECK_EVERY then
		return
	end
	acc = 0
	local cam = Workspace.CurrentCamera
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (cam and char and root) then
		return
	end
	local camCf = cam.CFrame
	-- รอบแรก: ปุ่มไหนกดได้บ้าง (ในระยะ หันไปหา ไม่มีผนังบัง ถือของครบ)
	local best: ProximityPrompt? = nil
	local bestScore = math.huge
	local ok: { [ProximityPrompt]: boolean } = {}
	for p, info in pairs(prompts) do
		if info.set ~= nil and p.MaxActivationDistance ~= info.set then
			info.base = p.MaxActivationDistance
			info.set = nil
		end
		local pos = targetPos(p)
		local attr = p:GetAttribute("Range")
		local range = if type(attr) == "number" then attr else info.base
		local good = pos ~= nil and p.Enabled and range > 0
		local dist = math.huge
		if good and pos then
			dist = (pos - root.Position).Magnitude
			good = dist <= range
		end
		if good then
			local need = p:GetAttribute("NeedsTool")
			if type(need) == "string" and not hasTool(char, need, true) then
				good = false
			end
			local hide = p:GetAttribute("HideIfHasTool")
			if good and type(hide) == "string" and hasTool(char, hide, false) then
				good = false
			end
		end
		local to = if pos then pos - camCf.Position else Vector3.zero
		local dot = if to.Magnitude > 0 then camCf.LookVector:Dot(to.Unit) else 1
		if good and p:GetAttribute("NeedsFacing") then
			good = to.Magnitude < 3.5 or dot >= LOOK_COS
		end
		if good and pos then
			good = canSee(camCf.Position, p, pos, char)
		end
		if good then
			ok[p] = true
			-- ใกล้สุดก่อน ถ้าพอๆ กันเลือกอันที่มองตรงกว่า
			local score = dist + (1 - dot) * 3
			if score < bestScore then
				bestScore = score
				best = p
			end
		end
	end
	-- รอบสอง: เปิดเฉพาะปุ่มของวัตถุที่ใกล้ที่สุด (ปุ่มอื่นบนชิ้นเดียวกันเปิดด้วย)
	local bestParent = best and best.Parent
	for p, info in pairs(prompts) do
		local attr = p:GetAttribute("Range")
		local range = if type(attr) == "number" then attr else info.base
		local on = ok[p] == true and p.Parent == bestParent
		setRange(p, info, if on then range else 0)
	end
end)
