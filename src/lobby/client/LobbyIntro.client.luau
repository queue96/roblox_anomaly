-- LobbyIntro.client.luau
-- ฉากเปิดตัวตอนเข้า Lobby (ครั้งแรกของรอบที่เข้ามา ไม่เล่นซ้ำตอนเกิดใหม่)
--   1) ระหว่างหน้าโหลด: ผู้เล่นยืนข้างป้ายชื่อวัด หน้าประตูวัด (นอกรั้ว) หันหน้าออก ยืนท่า idle (ไม่ Anchor)
--   2) หน้าโหลดจางหาย: จอดำค่อยเฟดขึ้น กล้องเคลื่อนจากไกลผ่านหมอกหนา (หมอก Lighting + ม่านหมอกอนุภาค
--      เฉพาะจอเรา) มาหยุดที่ผู้เล่น หมอกเปิดออกช่วงท้าย -> ชื่อวัด + "แตะหน้าจอเพื่อเริ่ม" กระพริบ
--      ระหว่างนี้ซ่อนผู้เล่นคนอื่น/ป้ายชื่อเหนือหัว (เฉพาะจอเรา) ซ่อน UI อื่น และล็อกการเดิน
--   3) แตะ/คลิก/กดปุ่มใดก็ได้: ตัวละครหันไปทางประตู กล้องไปอยู่ด้านหลัง แล้วเดินไปหน้าประตูและเข้าวัดเอง
--      เข้าพ้นประตูแล้วจึงคืนการควบคุม

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- สัญญาณถึงหน้าโหลด (LoadingScreen.client): IntroPending = มีฉากเปิด รอก่อน / IntroReady = ฉากเปิดพร้อมแล้ว ปิดหน้าโหลดได้
--   หน้าโหลดค้างไว้จนฉากเปิดพร้อมจริง จะได้ตัดจากหน้าโหลดเข้าม่านหมอกทันที ไม่มีจอดำหรือภาพค้างคั่น
player:SetAttribute("IntroPending", true)
local function giveUp()
	player:SetAttribute("IntroReady", true)
end

local lobby = workspace:WaitForChild("TempleLobby", 30)
local gate = lobby and lobby:WaitForChild("TempleGate", 10)
if not (lobby and gate) then
	giveUp()
	return
end
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart", 15) :: BasePart?
local humanoid = char:WaitForChild("Humanoid", 15) :: Humanoid?
if not (root and humanoid) then
	giveUp()
	return
end

-- ธีมเดียวกับ HUD ในเกม
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(165, 156, 136),
	Ember = Color3.fromRGB(230, 120, 50),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local function isThai(): boolean
	local lang = (player:GetAttribute("Lang") :: string?) or player.LocaleId
	return string.sub(string.lower(lang), 1, 2) == "th"
end

-- ---------------------------------------------------------------- จุดยืน + มุมกล้อง
-- ยืนข้างป้ายชื่อวัด (ระหว่างเสาประตูขวากับป้าย) หันหน้าออก (+Z) เข้าหากล้อง
-- (ลานหน้าประตู: MapBuilder.BuildTempleLobby COURT_HW / COURT_D, ป้าย: TempleNameSign)
local gateCf = gate:GetBoundingBox()
local sign = lobby:FindFirstChild("TempleNameSign")
local signPos = if sign then (sign :: Model):GetPivot().Position else gateCf.Position + Vector3.new(24, 0, 5)
local standXZ = Vector3.new(signPos.X - 8.5, 0, signPos.Z + 4.5)
-- หน้าประตู: เดินมาตรงนี้ก่อนแล้วตรงเข้าประตู
local gateFrontXZ = Vector3.new(gateCf.Position.X, 0, gateCf.Position.Z + 5)
-- จุดเดินเข้าไปถึง: พ้นประตูเข้าลานวัด
local insideXZ = Vector3.new(gateCf.Position.X, 0, gateCf.Position.Z - 12)
local function groundY(xz: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(Vector3.new(xz.X, 60, xz.Z), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else 0.3
end
local hipToRoot = humanoid.HipHeight + root.Size.Y / 2
local standPos = Vector3.new(standXZ.X, groundY(standXZ) + hipToRoot, standXZ.Z)
local facing = CFrame.lookAt(standPos, standPos + Vector3.new(0, 0, 1))
local head = standPos + Vector3.new(0, 1.6, 0)

-- ภาพถ่าย: ตัวละครกลางค่อนซ้าย ป้ายชื่อวัดอยู่ขวา เสาประตูทองอยู่ซ้ายหลัง กล้องต่ำมองเงยนิดๆ
local SHOT_LOOK = head + Vector3.new(2.2, 0.6, -2)
local SHOT_START = CFrame.lookAt(head + Vector3.new(-3, -0.4, 15), SHOT_LOOK)
local SHOT_END = CFrame.lookAt(head + Vector3.new(-2.4, -0.3, 12.5), SHOT_LOOK + Vector3.new(0, 0.15, 0))
-- เริ่มกล้องไกลออกไปในหมอกหนา (ช่องว่างกลางแนวป่าหน้าวัด) แล้วค่อยๆ เคลื่อนมาหาผู้เล่น
local FLY_START = CFrame.lookAt(head + Vector3.new(-9, 7, 75), head + Vector3.new(0, 2, 0))

-- ---------------------------------------------------------------- ล็อกตัว + กล้อง
local controls = nil
pcall(function()
	local pm = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 3)
	controls = pm and require(pm :: ModuleScript):GetControls()
end)
if controls then
	controls:Disable()
end
char:PivotTo(facing)
-- ไม่ Anchor ตัว: ท่า idle (Animate) ยังเล่นอยู่ ยืนหายใจรอ ไม่แข็งทื่อ / ปิดการควบคุมไว้แล้วจึงไม่เดินไปไหน
humanoid.AutoRotate = false
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = FLY_START

-- ---------------------------------------------------------------- ซ่อนผู้เล่นคนอื่น (เฉพาะจอเรา)
local hiding = true
local hiddenHumanoids: { [Humanoid]: Enum.HumanoidDisplayDistanceType } = {}
local function setOthersHidden(on: boolean)
	for _, p in ipairs(Players:GetPlayers()) do
		-- ป้ายชื่อเหนือหัว (LobbyNameplates) ซ่อนทุกคนรวมตัวเราเอง ให้ภาพถ่ายโล่ง
		local plate = p.Character and p.Character:FindFirstChild("LobbyNameplate", true) :: BillboardGui?
		if plate then
			plate.Enabled = not on
		end
		local c = p ~= player and p.Character
		if c then
			for _, d in ipairs(c:GetDescendants()) do
				if d:IsA("BasePart") or d:IsA("Decal") then
					d.LocalTransparencyModifier = if on then 1 else 0
				end
			end
			local h = c:FindFirstChildOfClass("Humanoid")
			if h then
				if on and not hiddenHumanoids[h] then
					hiddenHumanoids[h] = h.DisplayDistanceType
					h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				elseif not on and hiddenHumanoids[h] then
					h.DisplayDistanceType = hiddenHumanoids[h]
					hiddenHumanoids[h] = nil
				end
			end
		end
	end
end
-- ป้ายลอยในฉาก (ป้ายห้องเหนือวง "Room n · walk in to host" ฯลฯ ที่ AlwaysOnTop ทะลุทุกอย่าง): ซ่อนเฉพาะจอเรา
--   ป้ายชื่อเหนือหัวผู้เล่นจัดการใน setOthersHidden แล้ว (อยู่ใต้ตัวละคร)
local hiddenBoards: { [BillboardGui]: boolean } = {}
local function hideWorldBoards()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Enabled and not hiddenBoards[d] then
			local model = d:FindFirstAncestorOfClass("Model")
			if not (model and Players:GetPlayerFromCharacter(model)) then
				hiddenBoards[d] = true
				d.Enabled = false
			end
		end
	end
end
local function restoreWorldBoards()
	for b in pairs(hiddenBoards) do
		if b.Parent then
			b.Enabled = true
		end
	end
	table.clear(hiddenBoards)
end
hideWorldBoards()
-- ทำทุกเฟรม: คนที่เพิ่งเข้ามา/ชุดที่โหลดทีหลังก็ถูกซ่อนด้วย (ป้ายในฉากเช็กทุก ~0.5 วิ พอ)
local boardTick = 0
RunService:BindToRenderStep("LobbyIntroHideOthers", Enum.RenderPriority.Character.Value + 1, function(dt)
	if hiding then
		setOthersHidden(true)
		boardTick += dt
		if boardTick > 0.5 then
			boardTick = 0
			hideWorldBoards()
		end
	end
end)

-- ---------------------------------------------------------------- UI
local playerGui = player:WaitForChild("PlayerGui")
local gui = Instance.new("ScreenGui")
gui.Name = "LobbyIntro"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- เต็มจอจริงถึงขอบ (มือถือมีติ่ง/ขอบโค้ง: ค่าเริ่มต้นถูกบีบไว้ใน safe area เหลือแถบเกินขอบ)
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

-- แถบดำบน-ล่างแบบภาพยนตร์
local bars = {}
for i, anchor in ipairs({ 0, 1 }) do
	local b = Instance.new("Frame")
	b.Name = if i == 1 then "BarTop" else "BarBottom"
	b.AnchorPoint = Vector2.new(0, anchor)
	b.Position = UDim2.fromScale(0, anchor)
	b.Size = UDim2.fromScale(1, 0.1)
	b.BackgroundColor3 = C.Ink
	b.BorderSizePixel = 0
	b.Parent = gui
	bars[i] = b
end

local prompt = Instance.new("TextLabel")
prompt.Name = "TapPrompt"
-- อยู่ในแถบดำล่าง ไม่ทับตัวละคร
prompt.AnchorPoint = Vector2.new(0.5, 0.5)
prompt.Position = UDim2.fromScale(0.5, 0.95)
prompt.Size = UDim2.new(0.8, 0, 0, 30)
prompt.BackgroundTransparency = 1
prompt.FontFace = FONT
prompt.TextColor3 = C.Ember
prompt.TextSize = 24
prompt.TextTransparency = 1
prompt.Parent = gui

local function applyText()
	local th = isThai()
	local touch = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or camera.ViewportSize.Y < 500)
	prompt.Text = if touch
		then (if th then "แตะหน้าจอเพื่อเริ่ม" else "Tap to continue")
		else (if th then "คลิกหรือกดปุ่มใดก็ได้เพื่อเริ่ม" else "Click or press any key to continue")
end
applyText()
player:GetAttributeChangedSignal("Lang"):Connect(applyText)

-- ซ่อน UI อื่นระหว่างโพสท่า (คืนค่าเดิมตอนจบ)
local hiddenGuis: { [ScreenGui]: boolean } = {}
-- ห้ามซ่อนหน้าโหลด (LoadingScreen.client สร้างชื่อ "RuralLoadingScreen" + หน้าคั่นวาร์ป): หน้าโหลดต้องค้างจนฉากเปิดพร้อม
local function keepVisible(g: ScreenGui): boolean
	return g == gui or string.find(g.Name, "Loading") ~= nil
end
local function hideOtherGuis()
	for _, g in ipairs(playerGui:GetChildren()) do
		if g:IsA("ScreenGui") and not keepVisible(g) and g.Enabled then
			hiddenGuis[g] = true
			g.Enabled = false
		end
	end
end
hideOtherGuis()
-- UI ที่สร้างทีหลัง (สคริปต์อื่นโหลดช้ากว่า) ก็ซ่อนด้วย
local guiAddedConn = playerGui.ChildAdded:Connect(function(g)
	if g:IsA("ScreenGui") and not keepVisible(g) then
		task.defer(function()
			if hiding and g.Enabled then
				hiddenGuis[g] = true
				g.Enabled = false
			end
		end)
	end
end)

-- ---------------------------------------------------------------- เดินเรื่อง
-- หมอกหนาเฉพาะจอเรา ตั้งไว้ตั้งแต่ก่อนหน้าโหลดหาย: พอหน้าโหลดจางก็เห็นม่านหมอกทันที (ไม่มีจอดำคั่น)
-- แล้วค่อยจางเป็นหมอกปกติของ lobby ตอนกล้องถึงตัวผู้เล่น
local Lighting = game:GetService("Lighting")
local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local fogNormal = { FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor }
local atmoNormal = if atmo then { Density = atmo.Density, Haze = atmo.Haze } else nil
Lighting.FogStart = 0
Lighting.FogEnd = 22
-- หมอกกลางคืนสีเข้มจะดูเป็นแค่ความมืด: ช่วงบินผ่านทำให้ขาวหม่นเห็นเป็นม่านหมอก
Lighting.FogColor = Color3.fromRGB(92, 104, 114)
if atmo then
	atmo.Density = math.min(0.75, atmo.Density + 0.3)
	atmo.Haze = math.min(3, atmo.Haze + 1.2)
end

-- เสียงตอนแตะ "ทึงงงง": เสียงเดียวกับตอนเห็นผีในฉาก (SceneryGhostWatch.SIGHT_ID ความดังเท่ากัน)
--   สร้าง + โหลดไว้ก่อน (ส่ง Sound ให้ PreloadAsync: ส่งเป็นข้อความจะถูกโหลดเป็นรูปแล้วเตือน) ให้ดังทันทีที่แตะ
local startSting = Instance.new("Sound")
startSting.Name = "IntroStartSting"
startSting.SoundId = "rbxassetid://123314010660698"
startSting.Volume = 0.5
startSting:SetAttribute("SoundCategory", "SFX")
startSting.Parent = game:GetService("SoundService")
-- โหลดของที่อยู่ในภาพฉากเปิด (ประตู ป้าย ตัวละคร เสียง) ให้เสร็จก่อนบอกหน้าโหลด (กันค้าง: สูงสุด 12 วิ)
do
	local preloadDone = false
	task.spawn(function()
		pcall(function()
			local list: { Instance } = { gate, char, startSting }
			local sign = lobby:FindFirstChild("TempleNameSign")
			if sign then
				table.insert(list, sign)
			end
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
		preloadDone = true
	end)
	local tp = os.clock()
	while not preloadDone and os.clock() - tp < 12 do
		task.wait(0.1)
	end
	-- ให้กล้อง/หมอก/ตำแหน่งตัวละครเรนเดอร์ไปสักครู่ก่อนเปิดม่าน
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = FLY_START
	task.wait(0.3)
	player:SetAttribute("IntroReady", true)
end

-- รอหน้าโหลดจางหาย (กันค้าง: สูงสุด 90 วิ) แล้วเริ่มบินผ่านหมอกทันที
local t0 = os.clock()
while not player:GetAttribute("LoadingScreenDone") and os.clock() - t0 < 90 do
	-- ระหว่างรอ ให้ตำแหน่ง/กล้องอยู่ที่เดิม (สคริปต์อื่นอาจตั้งกล้องกลับ)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = FLY_START
	task.wait(0.05)
end

-- ---------------------------------------------------------------- เลือกภาษา (เข้าครั้งแรก)
-- ยังไม่เคยยืนยันภาษา (PlayerSettings.LangChosen = false): ขึ้นหน้าเลือกภาษาบนม่านหมอกก่อนเล่นฉากเปิด
--   กดภาษาแล้วข้อความเปลี่ยนตามทันที / ยืนยันแล้วบันทึก (DataStore) ครั้งหน้าไม่ถามอีก
do
	-- ค่าการตั้งค่าโหลดจาก DataStore ฝั่ง Server: รอให้มาก่อน (กันค้าง 8 วิ ไม่มา = ไม่ถาม)
	local tw = os.clock()
	while player:GetAttribute("LangChosen") == nil and os.clock() - tw < 8 do
		task.wait(0.1)
	end
	if player:GetAttribute("LangChosen") == false then
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		local setSetting = remotes and remotes:FindFirstChild("SetSetting") :: RemoteEvent?
		local function set(name: string, value: any)
			player:SetAttribute(name, value) -- เปลี่ยนบนจอทันที
			if setSetting then
				setSetting:FireServer(name, value)
			end
		end

		local INK = Color3.fromRGB(8, 7, 6)
		local PANEL = Color3.fromRGB(22, 20, 17)
		local LINE = Color3.fromRGB(70, 64, 54)
		local BLOOD = Color3.fromRGB(150, 18, 16)
		local touch = UserInputService.TouchEnabled and (not UserInputService.KeyboardEnabled or camera.ViewportSize.Y < 500)

		local dim = Instance.new("Frame")
		dim.Name = "LanguagePicker"
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = INK
		dim.BackgroundTransparency = 0.45
		dim.BorderSizePixel = 0
		dim.ZIndex = 40
		dim.Parent = gui
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(440, 250)
		panel.BackgroundColor3 = PANEL
		panel.BackgroundTransparency = 0.05
		panel.BorderSizePixel = 0
		panel.ZIndex = 41
		panel.Parent = dim
		Instance.new("UICorner").Parent = panel
		local ps = Instance.new("UIStroke")
		ps.Color = LINE
		ps.Thickness = 1
		ps.Parent = panel
		-- มือถือแนวนอนจอเตี้ย: ขยายให้นิ้วกดง่ายแต่ไม่ล้นจอ
		local scale = Instance.new("UIScale")
		scale.Scale = if touch then math.clamp(camera.ViewportSize.Y / 330, 0.85, 1.15) else 1
		scale.Parent = panel

		local function label(text: string, y: number, h: number, size: number, color: Color3): TextLabel
			local l = Instance.new("TextLabel")
			l.Position = UDim2.new(0, 0, 0, y)
			l.Size = UDim2.new(1, 0, 0, h)
			l.BackgroundTransparency = 1
			l.FontFace = FONT
			l.Text = text
			l.TextSize = size
			l.TextColor3 = color
			l.ZIndex = 42
			l.Parent = panel
			return l
		end
		local titleTh = label("เลือกภาษา", 18, 30, 26, C.Cream)
		local titleEn = label("Choose your language", 48, 22, 17, C.Dim)
		local _ = titleTh
		local _2 = titleEn

		local function button(text: string, x: number, w: number, y: number, h: number, size: number): TextButton
			local b = Instance.new("TextButton")
			b.Position = UDim2.new(0, x, 0, y)
			b.Size = UDim2.fromOffset(w, h)
			b.BackgroundColor3 = INK
			b.BorderSizePixel = 0
			b.AutoButtonColor = false
			b.FontFace = FONT
			b.Text = text
			b.TextSize = size
			b.TextColor3 = C.Cream
			b.ZIndex = 42
			b.Parent = panel
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 4)
			c.Parent = b
			local st = Instance.new("UIStroke")
			st.Color = LINE
			st.Thickness = 1
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = b
			return b
		end
		local thBtn = button("ไทย", 30, 180, 92, 64, 26)
		local enBtn = button("English", 230, 180, 92, 64, 24)
		local okBtn = button("ยืนยัน", 30, 380, 178, 48, 22)
		okBtn.BackgroundColor3 = BLOOD

		local choice = if isThai() then "th" else "en"
		local function draw()
			for _, pair in ipairs({ { thBtn, "th" }, { enBtn, "en" } }) do
				local b, code = pair[1], pair[2]
				local on = choice == code
				b.BackgroundColor3 = if on then Color3.fromRGB(48, 22, 20) else INK
				b.TextColor3 = if on then C.Cream else C.Dim
				;(b:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = if on then C.Ember else LINE
			end
			okBtn.Text = if choice == "th" then "ยืนยัน" else "Confirm"
		end
		draw()
		thBtn.Activated:Connect(function()
			choice = "th"
			set("Lang", "th")
			draw()
		end)
		enBtn.Activated:Connect(function()
			choice = "en"
			set("Lang", "en")
			draw()
		end)
		local confirmed = Instance.new("BindableEvent")
		okBtn.Activated:Connect(function()
			confirmed:Fire()
		end)
		confirmed.Event:Wait()
		confirmed:Destroy()
		set("Lang", choice)
		set("LangChosen", true)
		TweenService:Create(dim, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		panel.Visible = false
		task.delay(0.4, function()
			dim:Destroy()
		end)
	end
end

local FLY_TIME = 6.5
-- ม่านหมอกตามทางที่กล้องผ่าน (เฉพาะจอเรา) กล้องทะลุผ่านเป็นชั้นๆ เห็นหมอกไหลผ่านหน้า
local mist = Instance.new("Folder")
mist.Name = "IntroMist"
mist.Parent = workspace
for _, a in ipairs({ 0.12, 0.32, 0.52, 0.72 }) do
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(34, 9, 10)
	p.CFrame = CFrame.new(FLY_START.Position:Lerp(SHOT_START.Position, a))
	p.Parent = mist
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 160, 168))
	e.LightEmission = 0.15
	e.LightInfluence = 0.3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 20) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.55),
		NumberSequenceKeypoint.new(0.75, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 7
	e.Speed = NumberRange.new(0.3, 1)
	e.SpreadAngle = Vector2.new(180, 30)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-8, 8)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = p
	e:Emit(24) -- มีหมอกพร้อมตั้งแต่เฟรมแรก
end
-- หมอกหนาค้างไว้เกือบตลอดทาง แล้วเปิดออกช่วงท้ายตอนถึงตัวผู้เล่น
TweenService:Create(Lighting, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In), fogNormal):Play()
if atmo and atmoNormal then
	TweenService:Create(atmo, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In), atmoNormal):Play()
end
-- เลิกปล่อยหมอกใหม่หลังกล้องผ่าน แล้วลบทิ้งเมื่อหมอกเดิมจางหมด
task.delay(FLY_TIME - 1, function()
	for _, e in ipairs(mist:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
		end
	end
	task.delay(9, function()
		mist:Destroy()
	end)
end)
local fly = TweenService:Create(camera, TweenInfo.new(FLY_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = SHOT_START })
fly:Play()
fly.Completed:Wait()
-- กันค่าค้าง (เช่น tween ถูกยกเลิก): คืนหมอกปกติ
Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor = fogNormal.FogStart, fogNormal.FogEnd, fogNormal.FogColor
if atmo and atmoNormal then
	atmo.Density, atmo.Haze = atmoNormal.Density, atmoNormal.Haze
end

local slow = TweenInfo.new(14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local push = TweenService:Create(camera, slow, { CFrame = SHOT_END })
push:Play()
task.wait(1.2)

-- "แตะหน้าจอ" กระพริบช้าๆ
local tapped = false
task.spawn(function()
	while not tapped do
		TweenService:Create(prompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TextTransparency = 0 }):Play()
		task.wait(1.1)
		if tapped then
			break
		end
		TweenService:Create(prompt, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TextTransparency = 0.65 }):Play()
		task.wait(1.1)
	end
end)

local done = Instance.new("BindableEvent")
local inputConn = UserInputService.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Gamepad1 then
		done:Fire()
	end
end)
done.Event:Wait()
tapped = true
inputConn:Disconnect()

startSting:Play()
startSting.Ended:Once(function()
	startSting:Destroy()
end)
task.delay(30, function()
	if startSting.Parent then
		startSting:Destroy()
	end
end)

-- ---------------------------------------------------------------- ไปมุมเล่น
push:Cancel()
for _, l in ipairs({ prompt }) do
	TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
end
for i, b in ipairs(bars) do
	TweenService:Create(b, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { Size = UDim2.fromScale(1, 0) }):Play()
	local _ = i
end

-- เดินเข้าวัดทันทีหลังแตะ (ระหว่างเสียงทึงงง): กล้องค้างตำแหน่งเดิม แค่หันมองตามตัวผู้เล่น
humanoid.AutoRotate = true
local camPos = camera.CFrame.Position
local lookAt = camera.CFrame.Position + camera.CFrame.LookVector * 12
local walking = true
RunService:BindToRenderStep("LobbyIntroFollow", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not walking then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local target = root.Position + Vector3.new(0, 1.6, 0)
	-- หันตามนุ่มๆ ไม่กระตุก
	lookAt = lookAt:Lerp(target, math.clamp(dt * 4, 0, 1))
	camera.CFrame = CFrame.lookAt(camPos, lookAt)
end)
local function walkTo(xz: Vector3, timeout: number)
	local target = Vector3.new(xz.X, root.Position.Y, xz.Z)
	local arrived = false
	local conn = humanoid.MoveToFinished:Connect(function()
		arrived = true
	end)
	humanoid:MoveTo(target)
	local t = os.clock()
	while not arrived and os.clock() - t < timeout do
		task.wait(0.1)
	end
	conn:Disconnect()
end
walkTo(gateFrontXZ, 5)
walkTo(insideXZ, 6)
walking = false
RunService:UnbindFromRenderStep("LobbyIntroFollow")

-- ถึงช่วงควบคุมเอง: เลื่อนกล้องจากจุดเดิมไปหลังตัวผู้เล่น (มุมกล้องปกติ) แบบค่อยเป็นค่อยไป ไม่ตัดภาพ
--   ปลายทาง = หลังตัว ระยะ 12.5 (ระยะซูมเริ่มต้นของกล้อง Custom) มองหัว แล้วจึงสลับเป็น Custom ที่มุมเดียวกัน
local fromCf = camera.CFrame
local MOVE = 1.6
local tm = os.clock()
while true do
	local a = math.clamp((os.clock() - tm) / MOVE, 0, 1)
	local e = TweenService:GetValue(a, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local head = root.Position + Vector3.new(0, 1.5, 0)
	local back = -root.CFrame.LookVector
	local toPos = head + back * 12 + Vector3.new(0, 4, 0)
	local pos = fromCf.Position:Lerp(toPos, e)
	local look = (fromCf.Position + fromCf.LookVector * 12):Lerp(head, e)
	camera.CFrame = CFrame.lookAt(pos, look)
	if a >= 1 then
		break
	end
	RunService.RenderStepped:Wait()
end
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom

-- คืนทุกอย่าง
if controls then
	controls:Enable()
end
hiding = false
RunService:UnbindFromRenderStep("LobbyIntroHideOthers")
setOthersHidden(false)
restoreWorldBoards()
guiAddedConn:Disconnect()
for g in pairs(hiddenGuis) do
	if g.Parent then
		g.Enabled = true
	end
end
task.wait(0.5)
gui:Destroy()
done:Destroy()
