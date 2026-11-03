--!strict
-- ModelIcon.luau (ReplicatedStorage.Shared) — รูปของจากโมเดล 3D จริงใน ViewportFrame (ไม่ต้องอัปโหลดภาพ)
-- ใช้ในช่องของ (client/ItemSlots) และแผงสอนเล่น (client/TutorialController): บางคนไม่อ่าน ดูแต่รูป
--   local vf = ModelIcon.Make(UDim2.fromOffset(36, 36))
--   ModelIcon.Set(vf, tool หรือ model หรือ part)   -- เปลี่ยนรูปทีหลังได้ / nil = ว่าง
-- คัดลอกเฉพาะชิ้นที่มองเห็น (ไม่เอาสคริปต์ ปุ่มกด เสียง แสง) แล้วตั้งกล้องมองจากหน้า-ขวา-บนให้พอดีกรอบ
-- ของในโลกที่ StreamingEnabled ยังไม่ส่งมา = Set คืน false (เรียกซ้ำทีหลังได้)
local ModelIcon = {}

local KEEP = { SpecialMesh = true, SurfaceAppearance = true, Decal = true, Texture = true }
local MAX_PARTS = 300

function ModelIcon.Make(size: UDim2): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = "ModelIcon"
	vf.Size = size
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(175, 170, 160)
	vf.LightColor = Color3.fromRGB(255, 244, 226)
	vf.LightDirection = Vector3.new(-0.6, -1, -0.8)
	return vf
end

local function partsOf(source: Instance): { BasePart }
	local list = {}
	if source:IsA("BasePart") then
		table.insert(list, source)
	end
	for _, d in ipairs(source:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" then
			table.insert(list, d)
			if #list >= MAX_PARTS then
				break
			end
		end
	end
	return list
end

-- view: ทิศกล้องในกรอบของของ (-Z = ด้านหน้า) ค่าเริ่มต้น = หน้า-ขวา-บน
-- focus: ถ่ายแค่บางส่วนของโมเดล { center = จุดกลาง (ในกรอบของ source), radius = รัศมี studs } เช่น ตัวศาลไม่เอาเสา
function ModelIcon.Set(vf: ViewportFrame, source: Instance?, view: Vector3?, focus: { center: Vector3, radius: number }?): boolean
	vf:ClearAllChildren()
	if not source then
		return false
	end
	local parts = partsOf(source)
	if #parts == 0 then
		return false
	end
	local world = Instance.new("WorldModel")
	for _, p in ipairs(parts) do
		local ok, c = pcall(function()
			local wasArchivable = p.Archivable
			p.Archivable = true
			local copy = p:Clone()
			p.Archivable = wasArchivable
			return copy
		end)
		if ok and c then
			for _, ch in ipairs(c:GetChildren()) do
				if not KEEP[ch.ClassName] then
					ch:Destroy()
				end
			end
			c.Anchored = true
			c.LocalTransparencyModifier = 0 -- (ไฟฉายในมือถูกซ่อนบนจอตัวเอง: รูปต้องเห็น)
			c.CFrame = p.CFrame
			c.Parent = world
		end
	end
	world.Parent = vf
	local cf, size = world:GetBoundingBox()
	local pivot = if source:IsA("Model") then source:GetPivot() elseif source:IsA("BasePart") then source.CFrame else cf
	local rot = pivot - pivot.Position
	local dir = rot:VectorToWorldSpace((view or Vector3.new(0.65, 0.5, -1)).Unit)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local center = cf.Position
	local r = math.max(size.Magnitude / 2, 0.2)
	if focus then
		center = pivot:PointToWorldSpace(focus.center)
		r = focus.radius
	end
	local dist = r / math.sin(math.rad(cam.FieldOfView / 2)) * 1.02
	cam.CFrame = CFrame.lookAt(center + dir * dist, center)
	cam.Parent = vf
	vf.CurrentCamera = cam
	return true
end

return ModelIcon
