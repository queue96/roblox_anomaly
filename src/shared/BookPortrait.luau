--!strict
-- BookPortrait.luau (ReplicatedStorage.Shared) — วาดรูปผีในสมุดผีจากโมเดลนิ่งใน ReplicatedStorage.BookPortraits
--   (สร้างด้วย tools/studio/BuildBookPortraits.luau ใน place เกม แล้ว copy มาไว้ place Lobby)
--   BookPortrait.Mount(holder, key) -> ใส่ฉากหลังลึกลับ + ViewportFrame + กล้องจัดเฟรมให้ คืน ViewportFrame (nil ถ้าไม่มีโมเดล)
--   ฉากหลัง: ไล่สีมืดเขียวหม่น -> แดงก่ำที่พื้น, แสงจางๆ ด้านหลังตัวผี, ขอบมืด (vignette)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BookPortrait = {}

local FOV = 26

local function folder(): Instance?
	return ReplicatedStorage:FindFirstChild("BookPortraits")
end

function BookPortrait.Has(key: string): boolean
	local f = folder()
	return f ~= nil and f:FindFirstChild(key) ~= nil
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

-- ฉากหลังลึกลับ (อยู่ใต้ ViewportFrame) — ใช้ทั้งการ์ดเล็กและหน้าลักษณะ
function BookPortrait.Backdrop(holder: GuiObject, radius: number?)
	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	bg.BorderSizePixel = 0
	bg.ZIndex = 1
	bg.Parent = holder
	corner(bg, radius or 3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 16, 18)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(22, 28, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 14, 12)),
	})
	g.Parent = bg

	-- แสงหม่นด้านหลังตัว (วงรีจางๆ ตรงกลางค่อนบน)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	-- ใหญ่กว่ากรอบ: ขอบวงรีหลุดออกนอกภาพ เหลือแค่แสงฟุ้งตรงกลาง
	glow.Position = UDim2.fromScale(0.5, 0.45)
	glow.Size = UDim2.fromScale(1.7, 1.3)
	glow.BackgroundColor3 = Color3.fromRGB(150, 170, 160)
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = bg
	corner(glow, 999)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.97),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(0.7, 0.97),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow

	-- หมอกที่พื้น
	local mist = Instance.new("Frame")
	mist.Name = "Mist"
	mist.AnchorPoint = Vector2.new(0.5, 1)
	mist.Position = UDim2.fromScale(0.5, 1)
	mist.Size = UDim2.fromScale(1, 0.32)
	mist.BackgroundColor3 = Color3.fromRGB(120, 130, 128)
	mist.BorderSizePixel = 0
	mist.ZIndex = 1
	mist.Parent = bg
	local mg = Instance.new("UIGradient")
	mg.Rotation = -90
	mg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	mg.Parent = mist
	return bg
end

-- ขอบมืดทับด้านบน ViewportFrame
local function vignette(holder: GuiObject)
	for _, s in ipairs({ { 0, 0 }, { 90, 0 }, { 180, 0 }, { 270, 0 } }) do
		local f = Instance.new("Frame")
		f.Name = "Vignette"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(4, 4, 4)
		f.BorderSizePixel = 0
		f.ZIndex = 3
		f.Interactable = false
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Rotation = s[1]
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.22, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
	end
end

-- ตั้งกล้องให้ทั้งฉากพอดีกรอบ: yawOffset หมุนกล้องรอบฉากเพิ่ม (หน้าลักษณะใช้หมุนช้าๆ)
function BookPortrait.Frame(vf: ViewportFrame, yawOffset: number?)
	local model = vf:FindFirstChildOfClass("Model")
	local cam = vf.CurrentCamera
	if not (model and cam) then
		return
	end
	local cf, size = model:GetBoundingBox()
	local yaw = ((model:GetAttribute("BookYaw") :: number?) or 0) + (yawOffset or 0)
	local front = (model:GetPivot().Rotation * CFrame.Angles(0, math.rad(yaw), 0)).LookVector
	local abs = vf.AbsoluteSize
	local aspect = if abs.Y > 0 then abs.X / abs.Y else 0.8
	local tanV = math.tan(math.rad(FOV / 2))
	local horiz = math.max(size.X, size.Z)
	-- ภาพระยะใกล้ (ไม่บังคับ): BookFocusY = จุดมองที่ความสูงเท่าไรของฉาก (0 = พื้น, 1 = ยอด)
	--   BookFit = ให้เห็นสูงแค่กี่ส่วนของฉาก เช่น 0.32 = เห็นแค่หัวกับไหล่
	local focusY = model:GetAttribute("BookFocusY") :: number?
	local fit = model:GetAttribute("BookFit") :: number?
	local target = cf.Position
	local dist
	if focusY and fit then
		target = cf.Position + Vector3.new(0, (focusY - 0.5) * size.Y, 0)
		dist = (size.Y * fit / 2) / tanV + math.min(size.X, size.Z) / 2
	else
		-- กล้องหมุนรอบฉากได้: กันขอบด้วยด้านที่กว้างที่สุด
		dist = math.max((size.Y / 2) / tanV, (horiz / 2) / (tanV * aspect)) * 1.1 + horiz / 2
	end
	cam.FieldOfView = FOV
	cam.CFrame = CFrame.lookAt(target + front * dist + Vector3.new(0, size.Y * (if fit then 0.02 else 0.1), 0), target)
	vf.LightDirection = (-front + Vector3.new(0.5, -1.2, 0.2)).Unit
end

-- ใส่รูปลงกรอบ holder (Frame) : ฉากหลัง + ViewportFrame + vignette
function BookPortrait.Mount(holder: GuiObject, key: string, radius: number?): ViewportFrame?
	BookPortrait.Backdrop(holder, radius)
	local f = folder()
	local src = f and f:FindFirstChild(key)
	if not (src and src:IsA("Model")) then
		return nil
	end
	local vf = Instance.new("ViewportFrame")
	vf.Name = "Portrait"
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundTransparency = 1
	vf.ZIndex = 2
	-- แสงเย็นหม่นแบบกลางคืน แต่พอเห็นรายละเอียด
	vf.Ambient = Color3.fromRGB(120, 128, 132)
	vf.LightColor = Color3.fromRGB(236, 222, 200)
	vf.Parent = holder
	local cam = Instance.new("Camera")
	cam.Parent = vf
	vf.CurrentCamera = cam
	src:Clone().Parent = vf
	BookPortrait.Frame(vf)
	-- ขนาดกรอบจริงรู้หลังวาง UI แล้ว: จัดเฟรมใหม่เมื่อขนาดเปลี่ยน
	vf:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		BookPortrait.Frame(vf)
	end)
	vignette(holder)
	return vf
end

return BookPortrait
