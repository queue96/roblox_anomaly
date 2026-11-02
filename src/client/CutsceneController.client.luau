--!nonstrict
-- CutsceneController.client.luau
-- ฝั่ง Client ของคัทซีนเปิดคืน / จบคืน (ตัวละครขยับจริงฝั่ง Server ใน server/Cutscene.luau)
--   กล้อง (ตามคำสั่ง "cam" จาก Server), แถบดำบน-ล่าง, ซับไตเติล + เสียงพากย์, จอดำ, แสงเย็นใกล้ค่ำ / เช้ามืด
--   ข้ามได้: Enter / ปุ่ม B (จอย) / แตะปุ่ม "ข้าม" -> ส่ง "skip" ไป Server แล้วคืนกล้องทันที
--   จบคืนแบบชนะ: หลังคัทซีน (หรือข้าม) ขึ้นหน้าสรุปผล: ใครเติมไปเท่าไหร่ เจอผีกี่ตัว ได้ค่าเฝ้าร้านกี่บาท
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local SoundBank = require(Shared:WaitForChild("SoundBank"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = remotes:WaitForChild("Cutscene") :: RemoteEvent
local summaryRemote = remotes:WaitForChild("Summary") :: RemoteEvent
local deathChoice = remotes:WaitForChild("DeathChoice") :: RemoteEvent

local function lang(): string
	return LanguageModule.Normalize(player:GetAttribute("Lang") :: string?)
end
local function ui(key: string, vars: { [string]: any }?): string
	local s = LanguageModule.GetUI(key, lang())
	if vars then
		s = string.gsub(s, "{(%w+)}", function(k)
			return if vars[k] ~= nil then tostring(vars[k]) else nil
		end)
	end
	return s
end

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(20, 18, 15),
	Line = Color3.fromRGB(90, 80, 62),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(196, 188, 168),
	Ember = Color3.fromRGB(230, 120, 50),
	Gold = Color3.fromRGB(226, 186, 110),
	Blood = Color3.fromRGB(150, 18, 16),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "Cutscene"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.AutoLocalize = false
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(top: boolean): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.Size = UDim2.fromScale(1, 0.12)
	f.Parent = gui
	return f
end
local barTop = bar(true)
local barBottom = bar(false)

local fade = Instance.new("Frame")
fade.Name = "Fade"
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1
fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1)
fade.ZIndex = 5
fade.Parent = gui

local subtitle = Instance.new("Frame")
subtitle.AnchorPoint = Vector2.new(0.5, 1)
subtitle.Position = UDim2.new(0.5, 0, 0.86, -10)
subtitle.Size = UDim2.new(0.7, 0, 0, 62)
subtitle.BackgroundTransparency = 1
subtitle.Visible = false
subtitle.ZIndex = 3
subtitle.Parent = gui
local speakerLbl = Instance.new("TextLabel")
speakerLbl.BackgroundTransparency = 1
speakerLbl.Size = UDim2.new(1, 0, 0, 20)
speakerLbl.FontFace = FONT
speakerLbl.TextSize = 16
speakerLbl.TextColor3 = C.Gold
speakerLbl.ZIndex = 3
speakerLbl.Parent = subtitle
local lineLbl = Instance.new("TextLabel")
lineLbl.BackgroundTransparency = 1
lineLbl.Position = UDim2.fromOffset(0, 22)
lineLbl.Size = UDim2.new(1, 0, 1, -22)
lineLbl.FontFace = FONT
lineLbl.TextSize = 20
lineLbl.TextWrapped = true
lineLbl.TextColor3 = C.Cream
lineLbl.ZIndex = 3
lineLbl.Parent = subtitle
for _, l in ipairs({ speakerLbl, lineLbl }) do
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Transparency = 0.2
	s.Parent = l
end

-- ปุ่มข้าม (Modal = ปล่อยเมาส์ออกมากดได้แม้กล้องล็อกมุมมองบุคคลที่ 1)
local skipBtn = Instance.new("TextButton")
skipBtn.AnchorPoint = Vector2.new(1, 1)
skipBtn.Position = UDim2.new(1, -24, 1, -18)
skipBtn.Size = UDim2.fromOffset(0, 30)
skipBtn.AutomaticSize = Enum.AutomaticSize.X
skipBtn.BackgroundColor3 = C.Panel
skipBtn.BackgroundTransparency = 0.25
skipBtn.TextColor3 = C.Cream
skipBtn.FontFace = FONT
skipBtn.TextSize = 15
skipBtn.Modal = true
skipBtn.AutoButtonColor = true
skipBtn.ZIndex = 6
skipBtn.Parent = gui
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 3)
local skipPad = Instance.new("UIPadding", skipBtn)
skipPad.PaddingLeft, skipPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
local skipStroke = Instance.new("UIStroke", skipBtn)
skipStroke.Color = C.Line
skipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local skipHint = Instance.new("TextLabel")
skipHint.AnchorPoint = Vector2.new(1, 1)
skipHint.Position = UDim2.new(1, -24, 1, -52)
skipHint.Size = UDim2.fromOffset(300, 16)
skipHint.BackgroundTransparency = 1
skipHint.TextXAlignment = Enum.TextXAlignment.Right
skipHint.FontFace = FONT
skipHint.TextSize = 12
skipHint.TextColor3 = C.Dim
skipHint.ZIndex = 6
skipHint.Parent = gui

-- ---------------------------------------------------------------- แสง: เย็นใกล้ค่ำ / เช้ามืด (เฉพาะเครื่องตัวเอง แล้วคืนค่ากลางคืน)
local function atmo(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end
local function grade(): ColorCorrectionEffect?
	local g = Lighting:FindFirstChild("ColdNightGrade")
	return if g and g:IsA("ColorCorrectionEffect") then g else nil
end
local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation" }
local ATMO_PROPS = { "Density", "Color", "Decay", "Haze", "Glare", "Offset" }
local GRADE_PROPS = { "TintColor", "Saturation", "Brightness", "Contrast" }

local PRESETS = {
	dusk = {
		light = { ClockTime = 17.7, Brightness = 2.4, Ambient = Color3.fromRGB(100, 78, 70), OutdoorAmbient = Color3.fromRGB(160, 120, 98), ExposureCompensation = 0.25 },
		atmo = { Density = 0.32, Color = Color3.fromRGB(235, 165, 120), Decay = Color3.fromRGB(150, 92, 100), Haze = 1.8, Glare = 0.7, Offset = 0.18 },
		grade = { TintColor = Color3.fromRGB(255, 226, 200), Saturation = 0.08, Brightness = 0.02, Contrast = 0.08 },
	},
	dawn = {
		light = { ClockTime = 6.35, Brightness = 2.0, Ambient = Color3.fromRGB(88, 90, 108), OutdoorAmbient = Color3.fromRGB(150, 142, 158), ExposureCompensation = 0.15 },
		atmo = { Density = 0.36, Color = Color3.fromRGB(210, 190, 205), Decay = Color3.fromRGB(170, 125, 115), Haze = 2.2, Glare = 0.55, Offset = 0.12 },
		grade = { TintColor = Color3.fromRGB(248, 236, 238), Saturation = -0.02, Brightness = 0.01, Contrast = 0.06 },
	},
}

local saved: { [string]: any }? = nil
local function snapshot()
	if saved then
		return
	end
	local s = { light = {}, atmo = {}, grade = {} }
	for _, k in ipairs(LIGHT_PROPS) do
		s.light[k] = (Lighting :: any)[k]
	end
	local a = atmo()
	if a then
		for _, k in ipairs(ATMO_PROPS) do
			s.atmo[k] = (a :: any)[k]
		end
	end
	local g = grade()
	if g then
		for _, k in ipairs(GRADE_PROPS) do
			s.grade[k] = (g :: any)[k]
		end
	end
	saved = s
	Lighting:SetAttribute("Cutscene", true) -- AmbienceController หยุดหมอกลอยระหว่างคัทซีน
end

local function apply(preset: { [string]: any }, time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if time <= 0 then
		for k, v in pairs(preset.light) do
			(Lighting :: any)[k] = v
		end
	else
		TweenService:Create(Lighting, info, preset.light):Play()
	end
	local a = atmo()
	if a and next(preset.atmo) then
		if time <= 0 then
			for k, v in pairs(preset.atmo) do
				(a :: any)[k] = v
			end
		else
			TweenService:Create(a, info, preset.atmo):Play()
		end
	end
	local g = grade()
	if g and next(preset.grade) then
		if time <= 0 then
			for k, v in pairs(preset.grade) do
				(g :: any)[k] = v
			end
		else
			TweenService:Create(g, info, preset.grade):Play()
		end
	end
end

local function restoreNight()
	if saved then
		apply(saved, 0)
		saved = nil
	end
	Lighting:SetAttribute("Cutscene", nil)
end

-- ปุ่มกดในฉาก (E / F / G ค้าง ฯลฯ) ไม่ขึ้นระหว่างคัทซีน: ปิดทั้งระบบเฉพาะเครื่องตัวเอง
local function setPrompts(on: boolean)
	pcall(function()
		game:GetService("ProximityPromptService").Enabled = on
	end)
end

-- ---------------------------------------------------------------- กล้อง
local active: string? = nil
local cam = { mode = "fixed" } :: { [string]: any }
local camStart = 0
local smoothCF: CFrame? = nil
local hiddenGuis: { ScreenGui } = {}

local function setCam(spec: { [string]: any })
	cam = spec
	camStart = os.clock()
	smoothCF = nil
	local c = Workspace.CurrentCamera
	if c then
		c.FieldOfView = spec.fov or 60
	end
end

local function update(dt: number)
	local c = Workspace.CurrentCamera
	if not (c and active) then
		return
	end
	c.CameraType = Enum.CameraType.Scriptable
	local t = os.clock() - camStart
	local cf: CFrame? = nil
	if cam.mode == "fixed" and cam.pos and cam.look then
		-- ดันกล้องเข้าช้าๆ ให้ภาพไม่นิ่งตาย
		local dir = (cam.look - cam.pos)
		local pos = cam.pos + (if dir.Magnitude > 0 then dir.Unit else Vector3.zero) * math.min(t * 0.25, 2.5)
		cf = CFrame.lookAt(pos, cam.look)
	elseif cam.mode == "track" and cam.target and cam.target.Parent then
		local piv = cam.target:GetPivot()
		local yaw = CFrame.lookAt(Vector3.zero, Vector3.new(piv.LookVector.X, 0, piv.LookVector.Z))
		local base = CFrame.new(piv.Position) * yaw
		cf = CFrame.lookAt(base:PointToWorldSpace(cam.offset or Vector3.new(-8, 4, 6)), base:PointToWorldSpace(cam.look or Vector3.zero))
	elseif cam.mode == "lookat" and cam.pos and cam.target and cam.target.Parent then
		cf = CFrame.lookAt(cam.pos, cam.target:GetPivot().Position + (cam.look or Vector3.zero))
	end
	if cf then
		if smoothCF and cam.smooth then
			smoothCF = smoothCF:Lerp(cf, math.clamp(dt * cam.smooth, 0, 1))
		else
			smoothCF = cf
		end
		c.CFrame = smoothCF :: CFrame
	end
	-- ตัวเองต้องเห็นในคัทซีน (มุมมองบุคคลที่ 1 ซ่อนตัวเองไว้)
	local char = player.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).LocalTransparencyModifier = 0
			end
		end
	end
end

local function hideOtherGuis(hide: boolean)
	if hide then
		table.clear(hiddenGuis)
		for _, g in ipairs(player.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled and g.Name ~= "Summary" and g.Name ~= "RuralLoadingScreen" then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	else
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
	end
end

-- ---------------------------------------------------------------- หน้าสรุปผล
local summaryData: { [string]: any }? = nil
local summaryGui: ScreenGui? = nil
local votesLbl: TextLabel? = nil

local function label(parent: Instance, text: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.Size = UDim2.new(1, 0, 0, size + 8)
	for k, v in pairs(props or {}) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function closeSummary()
	if summaryGui then
		summaryGui:Destroy()
		summaryGui = nil
		votesLbl = nil
	end
end

local function showSummary()
	local d = summaryData
	if not d then
		return
	end
	closeSummary()
	local sg = Instance.new("ScreenGui")
	sg.Name = "Summary"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.AutoLocalize = false
	sg.DisplayOrder = 70
	sg.Parent = player.PlayerGui
	summaryGui = sg
	local dim = Instance.new("Frame")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = C.Ink
	dim.BackgroundTransparency = 0.25
	dim.BorderSizePixel = 0
	dim.Parent = sg
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = C.Panel
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = sg
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 4)
	local ps = Instance.new("UIStroke", panel)
	ps.Color = C.Line
	local pad = Instance.new("UIPadding", panel)
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 18), UDim.new(0, 18), UDim.new(0, 22), UDim.new(0, 22)
	local list = Instance.new("UIListLayout", panel)
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local cons = Instance.new("UISizeConstraint", panel)
	cons.MaxSize = Vector2.new(560, 640)

	local o = 0
	local function nextOrder(): number
		o += 1
		return o
	end
	label(panel, "🌅 " .. ui("SummaryTitle"), 28, C.Gold, { LayoutOrder = nextOrder() })
	local baht = ui("Baht")
	local function stat(key: string, value: string)
		local row = Instance.new("Frame")
		row.LayoutOrder = nextOrder()
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.Parent = panel
		label(row, ui(key), 16, C.Dim, { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.7, 0, 1, 0) })
		label(row, value, 17, C.Cream, { TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.3, 0, 1, 0), Position = UDim2.fromScale(0.7, 0) })
	end
	stat("SummaryTeam", string.format("%d / %d %s", d.team or 0, d.target or 0, baht))
	stat("SummaryAnomalies", string.format("%d %s", d.anomalies or 0, ui("Units")))
	stat("SummaryCaught", string.format("%d %s", d.caught or 0, ui("Units")))
	stat("SummaryFooled", string.format("%d %s", d.fooled or 0, ui("Units")))
	stat("SummaryOfferings", string.format("%d %s", d.offerings or 0, ui("Times")))

	local sep = Instance.new("Frame")
	sep.LayoutOrder = nextOrder()
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = C.Line
	sep.BorderSizePixel = 0
	sep.Parent = panel

	-- ตารางรายคน
	local COLS = { { "SummaryPlayer", 0.34 }, { "SummaryFills", 0.14 }, { "SummaryEarned", 0.17 }, { "SummaryGhosts", 0.13 }, { "SummaryWage", 0.22 } }
	local function row(values: { string }, color: Color3, size: number)
		local r = Instance.new("Frame")
		r.LayoutOrder = nextOrder()
		r.Size = UDim2.new(1, 0, 0, size + 8)
		r.BackgroundTransparency = 1
		r.Parent = panel
		local x = 0
		for i, col in ipairs(COLS) do
			label(r, values[i], size, color, {
				Size = UDim2.new(col[2], 0, 1, 0),
				Position = UDim2.fromScale(x, 0),
				TextXAlignment = if i == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			x += col[2]
		end
	end
	local head = {}
	for _, col in ipairs(COLS) do
		table.insert(head, ui(col[1]))
	end
	row(head, C.Ember, 14)
	for _, p in ipairs(d.players or {}) do
		local me = p.userId == player.UserId
		row({
			(if me then "▶ " else "") .. tostring(p.name),
			tostring(p.fills),
			string.format("%d %s", p.earned, baht),
			tostring(p.ghosts),
			string.format("%d %s", p.wage, baht),
		}, if me then C.Gold else C.Cream, 16)
	end

	local btnRow = Instance.new("Frame")
	btnRow.LayoutOrder = nextOrder()
	btnRow.Size = UDim2.new(1, 0, 0, 44)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = panel
	local bl = Instance.new("UIListLayout", btnRow)
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	bl.Padding = UDim.new(0, 14)
	-- ปุ่มธีมเดียวกับ HUD/แผงตั้งค่า: พื้นหมึกดำ ขอบเทาน้ำตาล ชี้แล้วขอบ (และพื้นปุ่มอันตราย) เปลี่ยนสี
	local function button(text: string, hot: Color3, onClick: () -> ()): TextButton
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(190, 36)
		b.BackgroundColor3 = C.Ink
		b.BackgroundTransparency = 0.1
		b.TextColor3 = C.Cream
		b.FontFace = FONT
		b.TextSize = 17
		b.Text = text
		b.Modal = true
		b.AutoButtonColor = false
		b.Parent = btnRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
		local st = Instance.new("UIStroke", b)
		st.Color = C.Line
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.MouseEnter:Connect(function()
			if b.Active then
				st.Color = hot
				b.BackgroundColor3 = if hot == C.Blood then C.Blood else C.Ink
			end
		end)
		b.MouseLeave:Connect(function()
			st.Color = C.Line
			b.BackgroundColor3 = C.Ink
		end)
		b.Activated:Connect(onClick)
		return b
	end
	local nextBtn
	nextBtn = button(ui("SummaryNext"), C.Gold, function()
		summaryRemote:FireServer("continue")
		nextBtn.Active = false
		nextBtn.TextColor3 = C.Dim
		nextBtn.BackgroundTransparency = 0.5
	end)
	button("🏯 " .. ui("Quit"), C.Blood, function()
		deathChoice:FireServer("quit")
	end)
	votesLbl = label(panel, "", 13, C.Dim, { LayoutOrder = nextOrder() })
end

summaryRemote.OnClientEvent:Connect(function(kind: string, n: number?, total: number?)
	if kind == "votes" and votesLbl then
		votesLbl.Text = ui("SummaryWait", { n = string.format("%d/%d", n or 0, total or 0) })
	elseif kind == "close" then
		closeSummary()
		summaryData = nil
	end
end)

-- ---------------------------------------------------------------- เริ่ม / จบ / ข้าม
local function setSkipText()
	skipBtn.Text = ui("SkipBtn")
	skipHint.Text = ui("SkipCutscene")
end

local function startCutscene(kind: string)
	if active then
		return
	end
	active = kind
	if _G.ClearHauntEffects then
		_G.ClearHauntEffects()
	end
	setSkipText()
	snapshot()
	apply(if kind == "outro" then PRESETS.dawn else PRESETS.dusk, 0)
	hideOtherGuis(true)
	gui.Enabled = true
	fade.BackgroundTransparency = 0
	-- มุมมองบุคคลที่ 1 บังคับให้ตัวหันตามกล้อง: กล้องคัทซีนอยู่ไกล ตัวเลยหันผิดทาง (เดินถอยหลัง)
	-- -> ระหว่างคัทซีนใช้ Classic ตัวหันตามทิศเดินเอง (คืน LockFirstPerson ตอนจบ)
	player.CameraMode = Enum.CameraMode.Classic
	setPrompts(false)
	pcall(function()
		UserSettings():GetService("UserGameSettings").RotationType = Enum.RotationType.MovementRelative
	end)
	TweenService:Create(fade, TweenInfo.new(1.0), { BackgroundTransparency = 1 }):Play()
	barTop.Position = UDim2.fromScale(0, 0)
	barBottom.Position = UDim2.fromScale(0, 1)
	TweenService:Create(barTop, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0.12) }):Play()
	TweenService:Create(barBottom, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 0.88) }):Play()
	RunService:BindToRenderStep("CutsceneCamera", Enum.RenderPriority.Last.Value, update)
end

local function endCutscene(kind: string)
	if not active then
		if kind == "outro" then
			showSummary()
		end
		return
	end
	active = nil
	RunService:UnbindFromRenderStep("CutsceneCamera")
	subtitle.Visible = false
	-- หยุดเดินที่คัทซีนสั่งไว้ (ยังเดินไม่ถึงตอนจบ = เดินข้างไปเองหลังกล้องกลับมาที่ตา)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root then
		hum:MoveTo(root.Position)
		hum:Move(Vector3.zero)
	end
	-- จอดำแวบ คืนกล้อง/แสงกลางคืน แล้วค่อยสว่าง
	fade.BackgroundTransparency = 0
	restoreNight()
	local c = Workspace.CurrentCamera
	if c then
		c.CameraType = Enum.CameraType.Custom
		c.FieldOfView = 70
		-- เริ่มเล่นหันหน้าออกถนน (หน้าร้าน = -Z) ไม่ใช่ทิศกล้องสุดท้ายของคัทซีน
		local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
		if head then
			c.CFrame = CFrame.lookAt(head.Position, head.Position + Vector3.new(0, -0.15, -1))
		end
	end
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	setPrompts(true)
	hideOtherGuis(false)
	if kind == "outro" then
		showSummary()
	end
	task.delay(0.25, function()
		if active then
			return
		end
		local t = TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		if not active then
			gui.Enabled = false
		end
	end)
end

local function skip()
	if active then
		local kind = active
		remote:FireServer("skip")
		endCutscene(kind)
	end
end
skipBtn.Activated:Connect(skip)
ContextActionService:BindAction("CutsceneSkip", function(_, state)
	if state == Enum.UserInputState.Begin and active then
		skip()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonB)

remote.OnClientEvent:Connect(function(kind: string, a: any, b: any, c: any)
	if kind == "start" then
		startCutscene(a)
	elseif kind == "cam" then
		setCam(a)
	elseif kind == "say" then
		if not a then
			subtitle.Visible = false
			return
		end
		local who = b or {}
		speakerLbl.Text = if who.player then who.player elseif who.name then LanguageModule.GetName(who.name, lang()) else ""
		speakerLbl.TextColor3 = if who.player then C.Ember else C.Gold
		lineLbl.Text = LanguageModule.GetText(a, lang())
		subtitle.Visible = active ~= nil
		pcall(SoundBank.PlayDialogueVoice, a, who, c)
	elseif kind == "fade" then
		TweenService:Create(fade, TweenInfo.new(b or 0.8), { BackgroundTransparency = if a then 0 else 1 }):Play()
	elseif kind == "sunset" then
		-- ตะวันตกดิน: แสงส้มค่อยๆ หม่นลงจนมืด (ก่อนจอดำเข้ากลางคืน)
		local t = a or 4
		TweenService:Create(Lighting, TweenInfo.new(t, Enum.EasingStyle.Sine), { ClockTime = 18.35, Brightness = 0.9, ExposureCompensation = -0.3 }):Play()
		local g = grade()
		if g then
			TweenService:Create(g, TweenInfo.new(t), { TintColor = Color3.fromRGB(200, 170, 190), Brightness = -0.05 }):Play()
		end
	elseif kind == "walkto" then
		-- เดินตัวเองไปจุดนี้ (Server สั่งผ่าน Client เพราะตัวละครเป็นของ Client)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and typeof(a) == "Vector3" and active then -- คัทซีนจบ/ข้ามแล้ว = ไม่เดินตามคำสั่งเก่า
			hum:MoveTo(a)
		end
	elseif kind == "end" then
		endCutscene(a)
	elseif kind == "summary" then
		summaryData = a
	end
end)

player:GetAttributeChangedSignal("Lang"):Connect(setSkipText)

-- จอดำคั่นตั้งแต่เข้าเกมจนคัทซีนเปิดคืนเริ่ม: หน้าโหลดหายแล้วไม่เห็นในร้านแวบหนึ่งก่อนคัทซีน
-- (อยู่ใต้หน้าโหลด DisplayOrder 999) Server ตอบ "nocutscene" = ไม่มีคัทซีนให้ดู -> เอาจอดำออก
local preroll = true
setPrompts(false)
gui.Enabled = true
fade.BackgroundTransparency = 0
skipBtn.Visible = false
skipHint.Visible = false
barTop.Position = UDim2.fromScale(0, 0)
barBottom.Position = UDim2.fromScale(0, 1)
local function endPreroll()
	if not preroll then
		return
	end
	preroll = false
	skipBtn.Visible = true
	skipHint.Visible = true
	if not active then
		setPrompts(true)
		local t = TweenService:Create(fade, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
		t:Play()
		t.Completed:Wait()
		if not active then
			gui.Enabled = false
		end
	end
end
remote.OnClientEvent:Connect(function(kind: string)
	if kind == "start" then
		preroll = false
		skipBtn.Visible = true
		skipHint.Visible = true
	elseif kind == "nocutscene" or kind == "end" then
		task.spawn(endPreroll)
	end
end)
-- กันค้าง: ไม่มีอะไรตอบกลับเลย
task.delay(120, function()
	endPreroll()
end)

-- บอก Server ว่าโหลดเสร็จแล้ว (หน้าโหลดหาย) ให้เริ่มคัทซีนเปิดคืนได้
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	-- หน้าโหลดอาจยังไม่ถูกสร้างตอนสคริปต์นี้เริ่ม: รอให้โผล่ก่อน (ไม่งั้นบอก ready ทั้งที่ยังโหลดอยู่ คัทซีนไปเล่นใต้หน้าโหลด)
	pg:WaitForChild("RuralLoadingScreen", 8)
	local t0 = os.clock()
	while os.clock() - t0 < 90 do
		local ls = pg:FindFirstChild("RuralLoadingScreen")
		if (not ls or not (ls :: ScreenGui).Enabled) and player.Character then
			break
		end
		task.wait(0.25)
	end
	task.wait(0.5)
	remote:FireServer("ready")
end)
