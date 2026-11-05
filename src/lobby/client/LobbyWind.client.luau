--!strict
-- LobbyWind.client.luau — ลมพัดในวัด (เฉพาะเครื่องตัวเอง ไม่แตะของฝั่ง Server)
--   หญ้า / กอกล้วย / พุ่มใบมะม่วง / ผ้าสามสี+รากย้อยต้นไทร / ธงงานศพ โยกเอนตามลม เป็นจังหวะลมกระโชกเบาๆ
--   หมอกพื้น (GroundMist) ลอยตามลม (Workspace.GlobalWind)
-- หมุนทั้งกลุ่มรอบจุดโคน (หญ้า กล้วย) / โคนพุ่มใบ (มะม่วง) / ขอบบน (ธง ผ้า) ด้วย BulkMoveTo
-- ประหยัด: ไกลกล้องเกิน FAR ไม่ขยับ, ระยะกลางอัปเดตห่างขึ้น, ใบมะม่วงในป่ารอบนอกนับรวมไม่เกิน PART_BUDGET ต่อรอบ
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local lobby = Workspace:WaitForChild("TempleLobby", 30)
if not lobby then
	return
end

local WIND_DIR = Vector3.new(0.94, 0, 0.34).Unit -- ลมพัดจากทุ่งฝั่งตะวันตกเข้าวัด
local TILT_AXIS = Vector3.new(0, 1, 0):Cross(WIND_DIR).Unit -- เอนไปทางที่ลมพัด
local NEAR, FAR = 70, 150
local PART_BUDGET = 1200 -- ชิ้นที่ขยับได้ต่อรอบ (ใบไม้แยกชิ้นเยอะมาก)
local TICK = 1 / 30

Workspace.GlobalWind = WIND_DIR * 7

type Group = {
	parts: { BasePart },
	orig: { CFrame },
	pivot: Vector3,
	axis: Vector3,
	amp: number, -- องศา
	freq: number, -- รอบ/วินาที
	phase: number,
	flutter: number, -- สั่นถี่ซ้อน (ธง/ผ้า) สัดส่วนของ amp
	interval: number, -- อัปเดตทุกกี่รอบ (กลุ่มชิ้นเยอะ = ห่างขึ้น สลับรอบกันไม่ให้ชนกัน)
	slot: number,
}
local groups: { Group } = {}

local function collect(roots: { Instance }): { BasePart }
	local list = {}
	for _, r in ipairs(roots) do
		if r:IsA("BasePart") then
			table.insert(list, r)
		end
		for _, d in ipairs(r:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

local function add(roots: { Instance }, pivot: Vector3, amp: number, freq: number, opts: { axis: Vector3?, flutter: number? }?)
	local parts = collect(roots)
	if #parts == 0 then
		return
	end
	local orig = table.create(#parts)
	for i, p in ipairs(parts) do
		if not p.Anchored then
			return -- ของที่ฟิสิกส์คุม ไม่ยุ่ง
		end
		orig[i] = p.CFrame
	end
	table.insert(groups, {
		parts = parts,
		orig = orig,
		pivot = pivot,
		axis = (opts and opts.axis) or TILT_AXIS,
		amp = amp,
		freq = freq,
		-- ลมมาถึงไม่พร้อมกัน: เฟสตามตำแหน่งตามแนวลม + สุ่มนิดหน่อย
		phase = pivot:Dot(WIND_DIR) * 0.08 + math.random() * 0.8,
		flutter = (opts and opts.flutter) or 0,
		-- ใบมะม่วง (~700 ชิ้น/ต้น) ขยับ 10 ครั้ง/วิ พอ (แกว่งช้าและน้อย ตาแยกไม่ออก) ของชิ้นน้อยขยับทุกรอบ
		interval = if #parts > 200 then 3 elseif #parts > 40 then 2 else 1,
		slot = #groups,
	})
end

local function base(m: Model): Vector3
	local cf, size = m:GetBoundingBox()
	return cf.Position - Vector3.new(0, size.Y / 2, 0)
end

-- ---------------------------------------------------------------- เก็บของที่ไหวตามลม
local function scan(container: Instance, background: boolean?)
	for _, m in ipairs(container:GetChildren()) do
		local name = m.Name
		if not m:IsA("Model") then
			-- ธงงานศพ (Part ห้อยจากเสา): แกว่งรอบขอบบน
			if m:IsA("BasePart") and name == "FuneralFlag" then
				local top = m.Position + Vector3.new(0, m.Size.Y / 2, 0)
				local face = m.CFrame.LookVector
				local axis = Vector3.new(0, 1, 0):Cross(Vector3.new(face.X, 0, face.Z))
				add({ m }, top, 12, 0.9, { axis = if axis.Magnitude > 0.01 then axis.Unit else TILT_AXIS, flutter = 0.5 })
			end
			continue
		end
		if string.match(name, "^LobbyGrass_") then
			add({ m }, base(m), 9, 0.75)
		elseif string.match(name, "^BananaTree_") then
			local leaves = {}
			for _, c in ipairs(m:GetChildren()) do
				if c.Name ~= "BananaClump_Base" then
					table.insert(leaves, c)
				end
			end
			add(leaves, base(m), 3.5, 0.45)
		elseif string.match(name, "Mango") and m:FindFirstChild("MangoLeaves") and not background then
			-- (ป่ารอบนอกในหมอก: ใบมะม่วงรวมกันหมื่นกว่าชิ้น ขยับแล้วหนักเกิน เห็นไม่ชัดอยู่แล้ว -> นิ่ง)
			local trunk = m:FindFirstChild("MangoTrunk") :: BasePart?
			local leaves = m:FindFirstChild("MangoLeaves") :: Instance
			local twigs = m:FindFirstChild("MangoTwigs")
			local _, lsize = (leaves :: Model):GetBoundingBox()
			local lcf = (leaves :: Model):GetBoundingBox()
			-- หมุนรอบโคนพุ่มใบ (ปลายลำต้น) ลำต้นนิ่ง
			local pivot = Vector3.new(lcf.Position.X, lcf.Position.Y - lsize.Y / 2, lcf.Position.Z)
			if trunk then
				pivot = Vector3.new(trunk.Position.X, pivot.Y, trunk.Position.Z)
			end
			add(if twigs then { leaves, twigs } else { leaves }, pivot, 2, 0.32)
		elseif name == "LobbyBanyanTree" then
			for _, n in ipairs({ "SacredThaiRibbons", "BanyanAerialRoots" }) do
				local p = m:FindFirstChild(n) :: BasePart?
				if p then
					local top = p.Position + Vector3.new(0, p.Size.Y / 2, 0)
					add({ p }, top, if n == "SacredThaiRibbons" then 3 else 1.2, 0.55, { flutter = if n == "SacredThaiRibbons" then 0.35 else 0 })
				end
			end
		elseif name == "FuneralFlag" or string.match(name, "^FuneralFlag_") then
			scan(m)
		end
	end
end
local decor = lobby:FindFirstChild("SpookyDecor")
if decor then
	scan(decor)
end
scan(lobby)
local forest = lobby:FindFirstChild("Forest")
if forest then
	scan(forest, true)
end

-- หมอกพื้นลอยตามลม
for _, d in ipairs(lobby:GetDescendants()) do
	if d:IsA("ParticleEmitter") and d:FindFirstAncestor("GroundMist") then
		d.WindAffectsDrag = true
		if d.Drag <= 0 then
			d.Drag = 1
		end
	end
end

-- ---------------------------------------------------------------- ขยับ
-- ลมกระโชก: แรงลมขึ้นลงช้าๆ ทั้งวัด (ต่ำสุดยังพัดเบาๆ อยู่)
local function gust(t: number): number
	return 0.55 + 0.3 * math.sin(t * 0.21) + 0.15 * math.sin(t * 0.53 + 1.3)
end

local acc = 0
local tickNo = 0
local load = 1 -- 1..4: ใช้เวลาเกิน ~2.5 ms ต่อรอบ = อัปเดตห่างขึ้น (มือถือ/เครื่องช้า)
local avgMs = 0
local partsBuf: { BasePart } = {}
local cfBuf: { CFrame } = {}
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK then
		return
	end
	acc = 0
	tickNo += 1
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	local t0 = t
	local g = gust(t)
	table.clear(partsBuf)
	table.clear(cfBuf)
	local used = 0
	for _, gr in ipairs(groups) do
		local d = (gr.pivot - camPos).Magnitude
		if d > FAR then
			continue
		end
		-- ระยะกลางอัปเดตห่างขึ้นเท่าตัว + เครื่องอืด (load) ห่างขึ้นอีก
		local every = gr.interval * (if d > NEAR then 2 else 1) * load
		if (tickNo + gr.slot) % every ~= 0 then
			continue
		end
		if used + #gr.parts > PART_BUDGET then
			continue
		end
		local w = t * gr.freq * 2 * math.pi + gr.phase
		local s = 0.7 * math.sin(w) + 0.3 * math.sin(w * 2.3 + 0.7)
		if gr.flutter > 0 then
			s += gr.flutter * math.sin(w * 4.1 + 1.9)
		end
		-- เอนตามลมเป็นหลัก (ค่าเฉลี่ยไม่เป็นศูนย์) + แกว่งกลับไปมา
		local ang = math.rad(gr.amp * g * (0.45 + 0.55 * s))
		local rot = CFrame.new(gr.pivot) * CFrame.fromAxisAngle(gr.axis, ang) * CFrame.new(-gr.pivot)
		for i, p in ipairs(gr.parts) do
			used += 1
			partsBuf[used] = p
			cfBuf[used] = rot * gr.orig[i]
		end
	end
	if used > 0 then
		Workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- ตรวจภาระ (ดูได้ใน Studio: attribute WindMs / WindParts ของสคริปต์นี้)
	local ms = (os.clock() - t0) * 1000
	avgMs = avgMs * 0.95 + ms * 0.05
	if avgMs > 2.5 and load < 4 then
		load += 1
		avgMs = 1.8
	elseif avgMs < 0.8 and load > 1 then
		load -= 1
		avgMs = 1.5
	end
	script:SetAttribute("WindMs", math.floor(avgMs * 10) / 10)
	script:SetAttribute("WindParts", used)
	script:SetAttribute("WindLoad", load)
end)

print(("🍃 [Lobby] ลมพัด: %d กลุ่ม"):format(#groups))
