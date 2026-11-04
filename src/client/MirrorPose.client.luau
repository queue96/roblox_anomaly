--!strict
-- MirrorPose.client.luau
-- ผีที่ติด tag "MirrorPose" + ObjectValue "MirrorSource": ทำท่าสะท้อนซ้าย-ขวาของผีอีกตัวทุกเฟรม
--   ใช้กับคนแบกโลงคานขวา (server/BigEvents ขบวนแห่ศพ): ท่า coffin_walk มีแต่แบกบ่าขวา -> สะท้อนเป็นบ่าซ้าย
-- วิธี: การขยับของกระดูก X ฝั่งต้นทาง (เทียบท่ายืนตรงในกรอบ RootPart) สะท้อนข้ามแกน X แล้วใส่ให้กระดูกคู่ (.L <-> .R)
--   Transform = (กรอบพ่อที่ต้องการ * Bone.CFrame)^-1 * กรอบที่ต้องการ   (ทำบนเครื่องนี้ Bone.Transform ไม่ replicate)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

type Rig = { root: BasePart, bones: { Bone }, byName: { [string]: Bone }, rest: { [Bone]: CFrame } }

local function rigOf(m: Model): Rig?
	local root = m:FindFirstChild("RootPart") :: BasePart?
	if not root then
		return nil
	end
	local bones: { Bone } = {}
	local byName: { [string]: Bone } = {}
	local rest: { [Bone]: CFrame } = {}
	-- GetDescendants เรียงพ่อก่อนลูก: ท่ายืนตรงในกรอบ RootPart ต่อกันเป็นสาย
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Bone") then
			table.insert(bones, d)
			byName[d.Name] = d
			local p = d.Parent
			rest[d] = (if p and p:IsA("Bone") then rest[p] else CFrame.identity) * d.CFrame
		end
	end
	return { root = root, bones = bones, byName = byName, rest = rest }
end

local function partner(n: string): string
	if string.sub(n, -2) == ".L" then
		return string.sub(n, 1, -3) .. ".R"
	elseif string.sub(n, -2) == ".R" then
		return string.sub(n, 1, -3) .. ".L"
	end
	return n
end

-- สะท้อนข้ามระนาบ YZ (กลับด้านซ้าย-ขวาของตัว): M * cf * M
local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

type Pair = { target: Rig, source: Rig, model: Model, src: Model }
local pairs_: { [Model]: Pair } = {}

local function track(m: Instance)
	if not m:IsA("Model") then
		return
	end
	task.spawn(function()
		local ov = m:WaitForChild("MirrorSource", 10) :: ObjectValue?
		-- ตัวต้นทางอาจมาถึงเครื่องนี้ทีหลัง ObjectValue (Value ยังเป็น nil): รอสักพัก
		local t0 = os.clock()
		while ov and not ov.Value and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		local src = ov and ov.Value
		if not (src and src:IsA("Model")) then
			return
		end
		-- StreamingEnabled: ชิ้นในโมเดลมาไม่พร้อมกัน รอ RootPart (กระดูกอยู่ใต้ชิ้นนี้) ของทั้งสองตัว
		if not (m:WaitForChild("RootPart", 10) and src:WaitForChild("RootPart", 10)) then
			return
		end
		task.wait(0.3)
		local t, s = rigOf(m), rigOf(src)
		if t and s then
			pairs_[m] = { target = t, source = s, model = m, src = src }
		end
	end)
end
for _, m in ipairs(CollectionService:GetTagged("MirrorPose")) do
	track(m)
end
CollectionService:GetInstanceAddedSignal("MirrorPose"):Connect(track)
CollectionService:GetInstanceRemovedSignal("MirrorPose"):Connect(function(m)
	pairs_[m :: Model] = nil
end)

RunService.RenderStepped:Connect(function()
	for m, p in pairs(pairs_) do
		if not (m.Parent and p.src.Parent) then
			pairs_[m] = nil
			continue
		end
		local srcRoot = p.source.root.CFrame
		local desired: { [Bone]: CFrame } = {}
		for _, b in ipairs(p.target.bones) do
			local parent = b.Parent
			local parentCF = if parent and parent:IsA("Bone") then desired[parent] or p.target.rest[parent] else CFrame.identity
			local sb = p.source.byName[partner(b.Name)]
			local d: CFrame
			if sb then
				-- การขยับของกระดูกต้นทาง (ท่าปัจจุบันเทียบท่ายืนตรง) สะท้อนแล้วใส่ท่ายืนตรงของกระดูกนี้
				local delta = srcRoot:ToObjectSpace(sb.TransformedWorldCFrame) * p.source.rest[sb]:Inverse()
				d = mirror(delta) * p.target.rest[b]
			else
				d = parentCF * b.CFrame
			end
			desired[b] = d
			b.Transform = (parentCF * b.CFrame):Inverse() * d
		end
	end
end)
