--!strict
-- GeneratorMinigame.client.luau
-- หน้าจอสตาร์ทเครื่องปั่นไฟ (ระบบหลักอยู่ server/Power.luau) สีและฟอนต์ชุดเดียวกับ HUD (หมึกดำ ครีม แดงเลือด พิมพ์ดีดเก่า)
--   แถบความคืบหน้า: ขึ้นเองตอนยืนซ่อมอยู่ใกล้เครื่อง
--   วงจังหวะ: เข็มหมุนรอบวง กด Space (มือถือแตะวง) ตอนเข็มอยู่ในช่อง
--     ส่วนแดง = บูสต์ แถบขึ้นเยอะ รอบถัดไปมาเร็วขึ้น / ช่องขาว = แถบขึ้นนิดเดียว (ค่าอยู่ใน Power.Config)
--     นอกช่องหรือไม่กด = โดนไฟช็อต: จอแวบฟ้า สั่น กระเด็นถอยจากเครื่อง มินิเกมปิด ต้องเดินกลับไปกดที่เครื่องใหม่
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Generator") :: RemoteEvent

-- สีชุดเดียวกับ HUDController
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(22, 20, 17),
	Line = Color3.fromRGB(70, 64, 54),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(165, 156, 136),
	BloodLit = Color3.fromRGB(205, 36, 28),
	Ember = Color3.fromRGB(230, 120, 50),
	Paper = Color3.fromRGB(226, 218, 196),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local SWEEP_TIME = 1.15 -- วินาทีที่เข็มหมุนครบรอบ
local ZONE = 42 -- องศาของช่องสีครีม
local GREAT = 13 -- องศาปลายช่อง (ส่วนแดง = บูสต์)
local LATE_GRACE = 12 -- กดเลยปลายช่องไปไม่เกินนี้ (องศา) ยังนับเป็นแดง (เข็มหมุน ~310°/วินาที: 12° = 0.04 วินาที)
local EDGE_GRACE = 2 -- ขอบช่องเผื่อให้นิดหน่อย
local GAP = { 0.9, 1.3 } -- เว้นระหว่างรอบ (วินาที)
local GAP_GREAT = { 0.4, 0.6 } -- หลังโดนส่วนแดง: รอบถัดไปมาเร็วขึ้น
local R = 74 -- รัศมีวง (px)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local gui = new("ScreenGui", { Name = "GeneratorMinigame", ResetOnSpawn = false, Enabled = false, DisplayOrder = 40, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

-- แถบความคืบหน้า (ล่างกลาง แบบเดียวกับกล่อง HUD)
local panel = new("Frame", { Size = UDim2.fromOffset(340, 58), Position = UDim2.new(0.5, 0, 0.5, R + 64), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, panel)
new("UIStroke", { Color = C.Line, Thickness = 1, Transparency = 0.2 }, panel)
local title = new("TextLabel", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 5), BackgroundTransparency = 1, FontFace = FONT, TextSize = 16, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Text = "Generator - starting..." }, panel)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }, title)
local barBg = new("Frame", { Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 36), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.1, BorderSizePixel = 0 }, panel)
new("UIStroke", { Color = C.Line, Thickness = 1 }, barBg)
local barFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.Ember, BorderSizePixel = 0 }, barBg)

-- วงจังหวะ (กลางจอ)
local ring = new("Frame", { Size = UDim2.fromOffset(R * 2, R * 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, gui)
local circle = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, ring)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, circle)
new("UIStroke", { Color = C.Dim, Thickness = 2, Transparency = 0.25 }, circle)
local zoneHolder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, ring)
-- GUI หมุนรอบจุดกลางของชิ้นเอง: หมุนกรอบขนาดเท่าวง (จุดกลาง = กลางวง) แล้ววางเข็มชิดขอบบนของกรอบ
local needle = new("Frame", { Size = UDim2.new(1, 32, 1, 32), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 3 }, ring)
new("Frame", { Size = UDim2.new(0, 4, 0.5, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.BloodLit, BorderSizePixel = 0, ZIndex = 3 }, needle)
-- ป้ายคีย์กลางวง (กระดาษ ขอบหมึก แบบปุ่มคีย์ใน HUD)
local key = new("TextButton", { Size = UDim2.fromOffset(92, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.1, FontFace = FONT, TextSize = 20, TextColor3 = C.Paper, Text = "Space", AutoButtonColor = false, ZIndex = 4 }, ring)
new("UICorner", { CornerRadius = UDim.new(0, 4) }, key)
new("UIStroke", { Color = C.Paper, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, key)
local result = new("TextLabel", { Size = UDim2.fromOffset(240, 26), Position = UDim2.new(0.5, 0, 0.5, R + 22), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, FontFace = FONT, TextSize = 18, TextColor3 = C.Cream, Text = "" }, gui)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, result)

-- ช่องสีครีมเป็นขีดสั้นๆ เรียงตามวง (GUI วาดเส้นโค้งตรงๆ ไม่ได้)
local function drawZone(startDeg: number)
	zoneHolder:ClearAllChildren()
	for a = 0, ZONE, 3 do
		local deg = startDeg + a
		local rad = math.rad(deg)
		local great = a >= ZONE - GREAT
		new("Frame", {
			Size = UDim2.fromOffset(if great then 7 else 6, if great then 7 else 5),
			Position = UDim2.new(0.5, math.sin(rad) * R, 0.5, -math.cos(rad) * R),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = deg,
			BackgroundColor3 = if great then C.BloodLit else Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, zoneHolder)
	end
end

local TweenService = game:GetService("TweenService")
local fillTime = 0.6 -- แถบวิ่งไปค่าใหม่ใช้เวลาเท่านี้ (โดนส่วนแดง = เร็วกว่า)
local function fillTo(v: number)
	TweenService:Create(barFill, TweenInfo.new(fillTime, Enum.EasingStyle.Quad), { Size = UDim2.new(v, 0, 1, 0) }):Play()
end

local open = false
local checking = false
local checkStart = 0
local zoneAt = 0
local nextCheck = 0

local function say(text: string, color: Color3)
	result.Text = text
	result.TextColor3 = color
	task.delay(0.9, function()
		if result.Text == text then
			result.Text = ""
		end
	end)
end

local function finishCheck(r: string)
	checking = false
	ring.Visible = false
	local gap = if r == "great" then GAP_GREAT else GAP
	nextCheck = os.clock() + gap[1] + math.random() * (gap[2] - gap[1])
	fillTime = if r == "great" then 0.25 else 0.6
	if r == "great" then
		say("Great!", C.BloodLit)
		remote:FireServer("great")
	elseif r == "good" then
		say("Good", Color3.new(1, 1, 1))
		remote:FireServer("good")
	else
		-- ไฟช็อต: เซิร์ฟเวอร์ปิดมินิเกมแล้วส่ง "shock" กลับมา (จอแวบ สั่น กระเด็น) / ไม่มีรอบใหม่ระหว่างรอ
		nextCheck = math.huge
		remote:FireServer("miss")
	end
end

local function press()
	if not checking then
		return
	end
	-- ใช้มุมเข็มที่เห็นบนจอ (เฟรมล่าสุด) ไม่ใช่เวลาตอนกด: กดตอนเห็นเข็มอยู่ในแดง = นับแดง
	-- ส่วนแดงอยู่ปลายช่อง ติดกับนอกช่อง: กดช้าไปนิด (LATE_GRACE) ยังนับแดง ไม่โดนไฟช็อต
	local deg = needle.Rotation
	if deg >= zoneAt + ZONE - GREAT - EDGE_GRACE and deg <= zoneAt + ZONE + LATE_GRACE then
		finishCheck("great")
	elseif deg >= zoneAt - EDGE_GRACE and deg < zoneAt + ZONE - GREAT - EDGE_GRACE then
		finishCheck("good")
	else
		finishCheck("miss")
	end
end
key.Activated:Connect(press)

-- Space ปกติคือกระโดด: ระหว่างซ่อมให้ Space เป็นปุ่มดึงแทน (ไม่ให้ตัวกระโดดหนีจากเครื่อง)
local function onSpace(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press()
	end
	return Enum.ContextActionResult.Sink
end

RunService.RenderStepped:Connect(function()
	if not open then
		return
	end
	if checking then
		local deg = (os.clock() - checkStart) / SWEEP_TIME * 360
		needle.Rotation = math.max(deg, 0)
		if deg > zoneAt + ZONE + LATE_GRACE + 6 then
			finishCheck("miss") -- เลยช่องไปแล้วยังไม่กด
		end
	elseif os.clock() >= nextCheck then
		checking = true
		checkStart = os.clock() + 0.4 -- เห็นวงก่อนเข็มเริ่มหมุนนิดหนึ่ง
		zoneAt = 110 + math.random() * (300 - 110 - ZONE)
		drawZone(zoneAt)
		needle.Rotation = 0
		key.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then "Tap" else "Space"
		ring.Visible = true
	end
end)

local function setOpen(on: boolean)
	if on and not open then
		ContextActionService:BindActionAtPriority("GeneratorPull", onSpace, false, Enum.ContextActionPriority.High.Value + 1, Enum.KeyCode.Space)
	elseif not on and open then
		ContextActionService:UnbindAction("GeneratorPull")
	end
	open = on
	gui.Enabled = on
	ProximityPromptService.Enabled = not on -- ซ่อนปุ่ม "Start Generator" (และปุ่มอื่น) ระหว่างซ่อม
	checking = false
	ring.Visible = false
	result.Text = ""
	nextCheck = os.clock() + 0.7
end

-- ---------------------------------------------------------------- ไฟช็อต
-- จอแยกต่างหาก (หน้ามินิเกมปิดไปแล้วตอนโดนช็อต): แสงฟ้าแวบ + ข้อความ
local shockGui = new("ScreenGui", { Name = "GeneratorShock", ResetOnSpawn = false, DisplayOrder = 41, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None }, player:WaitForChild("PlayerGui"))
local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 225, 255), BackgroundTransparency = 1, BorderSizePixel = 0 }, shockGui)
local shockText = new("TextLabel", { Size = UDim2.fromOffset(420, 52), Position = UDim2.new(0.5, 0, 0.5, R + 22), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, FontFace = FONT, TextSize = 20, TextColor3 = C.Cream, TextWrapped = true, Text = "" }, shockGui)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, shockText)
local shakeUntil = 0
RunService:BindToRenderStep("GeneratorShockShake", Enum.RenderPriority.Camera.Value + 5, function()
	local left = shakeUntil - os.clock()
	if left <= 0 then
		return
	end
	local cam = workspace.CurrentCamera
	local k = math.min(1, left / 0.5) * 0.06
	cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k * 2)
end)

local function onShock(from: Vector3?)
	flash.BackgroundTransparency = 0.15
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	shakeUntil = os.clock() + 0.5
	shockText.Text = "Shocked! Go back and press the generator to keep going"
	shockText.TextColor3 = C.Cream
	task.delay(2.6, function()
		if shockText.Text ~= "" then
			TweenService:Create(shockText, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.45, function()
				shockText.Text = ""
				shockText.TextTransparency = 0
			end)
		end
	end)
	-- กระเด็นถอยออกจากเครื่อง (ตัวเราเป็นของเครื่องเรา: ผลักฝั่งนี้)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and from then
		local away = root.Position - from
		away = Vector3.new(away.X, 0, away.Z)
		away = if away.Magnitude > 0.1 then away.Unit else -root.CFrame.LookVector
		-- ตั้งความเร็วตัวตรงๆ ไม่ได้ผล (Humanoid หยุดความเร็วแนวนอนทันที) -> ดันด้วย LinearVelocity สั้นๆ
		local att = Instance.new("Attachment")
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = att
		lv.MaxForce = 1e6
		lv.VectorVelocity = away * 22 + Vector3.new(0, 9, 0)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = root
		task.delay(0.22, function()
			lv:Destroy()
			att:Destroy()
		end)
	end
end

-- แถบเต็ม = เครื่องติดแล้ว: ไม่มีวงรอบใหม่อีก (ระหว่างรอหน้าจอปิด 1.4 วินาที เดิมวงเด้งขึ้นมาให้กดอีกรอบ)
local function stopRounds()
	nextCheck = math.huge
	checking = false
	ring.Visible = false
end

remote.OnClientEvent:Connect(function(what: string, value: any)
	if what == "open" then
		title.Text = "Generator - starting..."
		setOpen(true)
		barFill.Size = UDim2.new(if type(value) == "number" then value else 0, 0, 1, 0)
	elseif what == "progress" then
		local v = if type(value) == "number" then value else 0
		fillTo(v)
		if v >= 1 then
			stopRounds()
		end
	elseif what == "done" then
		title.Text = "Generator running - lights are back"
		fillTo(1)
		stopRounds()
		task.delay(1.4, function()
			setOpen(false)
		end)
	elseif what == "close" then
		setOpen(false)
	elseif what == "shock" then
		setOpen(false)
		onShock(if typeof(value) == "Vector3" then value else nil)
	end
end)
