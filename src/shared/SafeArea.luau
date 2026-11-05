--!strict
-- SafeArea.luau (ReplicatedStorage.Shared) — ระยะห่างจากขอบจอ (มือถือ: ขอบโค้ง/ติ่งจอ ปุ่มชิดขอบกดยากและดูอึดอัด)
--   SafeArea.Pad()            = ระยะเว้นเพิ่ม (px) จากขอบ safe area: มือถือ ~5% ของด้านสั้น อุปกรณ์อื่น 0
--   SafeArea.Frame(gui)       = Frame เต็มพื้นที่ปลอดภัยของจอ (ไม่โดนติ่ง/ขอบโค้ง) หด Pad() เข้ามาอีกชั้น
--                               ใช้กับ ScreenGui ที่ ScreenInsets = None (พื้นหลังเต็มจอ) แต่ปุ่ม/ข้อความต้องไม่ชิดขอบ
--   SafeArea.Changed(fn)      = เรียก fn ใหม่ทุกครั้งที่ขนาดจอเปลี่ยน (หมุนจอ / เปลี่ยนอุปกรณ์ในตัวจำลอง)
-- ปรับระยะที่เดียว: PHONE_PAD_RATIO / PHONE_PAD_MIN
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SafeArea = {}

local PHONE_PAD_RATIO = 0.05
local PHONE_PAD_MIN = 18

local function isPhone(): boolean
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local mod = shared and shared:FindFirstChild("DeviceInfo")
	if mod and mod:IsA("ModuleScript") then
		local ok, info = pcall(require, mod)
		if ok and type(info) == "table" and info.IsPhone then
			return info.IsPhone()
		end
	end
	return false
end

function SafeArea.Pad(): number
	if not isPhone() then
		return 0
	end
	local cam = Workspace.CurrentCamera
	local short = if cam then math.min(cam.ViewportSize.X, cam.ViewportSize.Y) else 360
	return math.max(PHONE_PAD_MIN, math.floor(short * PHONE_PAD_RATIO + 0.5))
end

function SafeArea.Changed(fn: () -> ())
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(fn)
	end
end

-- ScreenGui ตัววัดพื้นที่ปลอดภัย (ใช้ร่วมกันทุกกรอบ)
local probeArea: Frame? = nil
local function probe(): Frame
	if probeArea and probeArea.Parent then
		return probeArea
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "SafeAreaProbe"
	sg.IgnoreGuiInset = true
	sg.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	sg.ResetOnSpawn = false
	sg.Enabled = true
	local area = Instance.new("Frame")
	area.Size = UDim2.fromScale(1, 1)
	area.BackgroundTransparency = 1
	area.Interactable = false
	area.Parent = sg
	sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	probeArea = area
	return area
end

function SafeArea.Frame(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = "SafeArea"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 5
	f.Parent = parent
	local area = probe()
	local function fit()
		-- เทียบตำแหน่งจริงของ ScreenGui แม่ (ScreenInsets None = เต็มจอถึงขอบ) กับกรอบปลอดภัยของจอ (DeviceSafeInsets)
		local root = f.Parent
		local full: Vector2, fullPos: Vector2
		if root and (root:IsA("GuiObject") or root:IsA("LayerCollector")) then
			full, fullPos = (root :: any).AbsoluteSize, (root :: any).AbsolutePosition
		else
			local cam = Workspace.CurrentCamera
			full, fullPos = (if cam then cam.ViewportSize else Vector2.new(1280, 720)), Vector2.zero
		end
		local pad = SafeArea.Pad()
		local a, ap = area.AbsoluteSize, area.AbsolutePosition
		local left, top, right, bottom = 0, 0, 0, 0
		if a.X > 0 and full.X > 0 then
			left = math.max(0, ap.X - fullPos.X)
			top = math.max(0, ap.Y - fullPos.Y)
			right = math.max(0, (fullPos.X + full.X) - (ap.X + a.X))
			bottom = math.max(0, (fullPos.Y + full.Y) - (ap.Y + a.Y))
		end
		-- ขอบโค้งมือถือแนวนอน: เว้นซ้ายขวาเท่ากัน (ด้านที่ไม่มีติ่งก็โค้ง)
		local side = math.max(left, right)
		left, right = side + pad, side + pad
		top += pad
		bottom += pad
		f.Position = UDim2.fromOffset(left, top)
		f.Size = UDim2.new(1, -(left + right), 1, -(top + bottom))
	end
	area:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	area:GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
	SafeArea.Changed(fit)
	local root = f.Parent
	if root and (root:IsA("GuiObject") or root:IsA("LayerCollector")) then
		(root :: any):GetPropertyChangedSignal("AbsoluteSize"):Connect(fit);
		(root :: any):GetPropertyChangedSignal("AbsolutePosition"):Connect(fit)
	end
	fit()
	task.defer(fit)
	return f
end

return SafeArea
