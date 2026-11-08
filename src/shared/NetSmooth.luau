--!strict
-- NetSmooth.luau (ReplicatedStorage.Shared) — ของที่ Server ขยับเองทุกเฟรม (คนเดิน ผี ขบวนผีใหญ่ โลง คนตามรถแห่)
-- ให้เครื่องผู้เล่นเห็นลื่น (ผู้ใช้ 2026-11-08: เล่นจริงขยับหน่วงๆ)
--   Server ยัง PivotTo ตามเดิมทุกอย่าง (โค้ดเกมที่อ่านตำแหน่งยังถูกต้อง) แค่ติด tag NetSmooth ให้โมเดลที่ขยับ
--   แล้วส่งตำแหน่งโมเดลทั้งก้อน (pivot เดียว) 20 ครั้ง/วิ พร้อมเวลา Server ผ่าน UnreliableRemoteEvent
--   เครื่องผู้เล่น (client/SmoothDrive) เก็บไว้แล้ววาดย้อนหลัง DELAY วิ เกลี่ยระหว่าง 2 ตำแหน่ง = ลื่นแม้เน็ตส่งมาไม่สม่ำเสมอ
--   โมเดลที่อยู่ในโมเดลอื่นที่ขยับเอง (ผีซ้อนท้ายในรถ, จักรยานที่คนเข็น) ไม่ส่ง: ขยับไปกับตัวแม่
--   รถลูกค้า (tag SmoothDrive) ใช้ระบบของตัวเอง (shared/DriveMotion)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NetSmooth = {}

NetSmooth.TAG = "NetSmooth"
NetSmooth.DRIVE_TAG = "SmoothDrive"
NetSmooth.RATE = 20 -- ครั้ง/วิ
NetSmooth.DELAY = 0.12 -- วิ: เครื่องผู้เล่นวาดย้อนหลังเท่านี้ (มากกว่า 2 รอบส่งนิดหน่อย)
NetSmooth.CHUNK = 8 -- โมเดลต่อ 1 ข้อความ (UnreliableRemoteEvent จำกัดขนาด ~900 bytes)
NetSmooth.REMOTE = "NetSmooth"

-- โมเดลนี้อยู่ในโมเดลอื่นที่ขยับเองอยู่แล้วไหม
function NetSmooth.Nested(m: Instance): boolean
	local a = m.Parent
	while a and a ~= Workspace do
		if a:IsA("Model") and (CollectionService:HasTag(a, NetSmooth.TAG) or CollectionService:HasTag(a, NetSmooth.DRIVE_TAG)) then
			return true
		end
		a = a.Parent
	end
	return false
end

local started = false
local function startServer()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local ev = remotes:FindFirstChild(NetSmooth.REMOTE) :: UnreliableRemoteEvent?
	if not ev then
		local e = Instance.new("UnreliableRemoteEvent")
		e.Name = NetSmooth.REMOTE
		e.Parent = remotes
		ev = e
	end
	local remote = ev :: UnreliableRemoteEvent
	local lastSent: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / NetSmooth.RATE then
			return
		end
		acc = 0
		local now = Workspace:GetServerTimeNow()
		local batch: { any } = {}
		for _, inst in ipairs(CollectionService:GetTagged(NetSmooth.TAG)) do
			if inst:IsA("Model") and inst:IsDescendantOf(Workspace) and not NetSmooth.Nested(inst) then
				local m = inst :: Model
				local cf = m:GetPivot()
				local last = lastSent[m]
				if not last or (last.Position - cf.Position).Magnitude > 0.003 or last.LookVector:Dot(cf.LookVector) < 0.99999 or last.UpVector:Dot(cf.UpVector) < 0.99999 then
					lastSent[m] = cf
					table.insert(batch, m)
					table.insert(batch, cf)
					if #batch >= NetSmooth.CHUNK * 2 then
						remote:FireAllClients(now, batch)
						batch = {}
					end
				end
			end
		end
		if #batch > 0 then
			remote:FireAllClients(now, batch)
		end
	end)
end

-- Server: ให้โมเดลนี้ขยับลื่นบนเครื่องผู้เล่น (เรียกซ้ำได้)
function NetSmooth.Track(m: Instance?)
	if not m or not RunService:IsServer() then
		return
	end
	if not CollectionService:HasTag(m, NetSmooth.TAG) then
		CollectionService:AddTag(m, NetSmooth.TAG)
		-- ทั้งก้อนส่งมาพร้อมกัน (StreamingEnabled): ไม่งั้นชิ้นที่มาทีหลังวางเพี้ยนจากชิ้นอื่น
		if m:IsA("Model") and m.ModelStreamingMode == Enum.ModelStreamingMode.Default then
			pcall(function()
				(m :: Model).ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			end)
		end
	end
	startServer()
end

return NetSmooth
