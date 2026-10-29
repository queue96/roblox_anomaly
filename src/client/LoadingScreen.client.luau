-- LoadingScreen.client.luau
-- 1) ตอนเข้าแมพ Lobby (เข้าเกมครั้งแรก): แสดงหน้าจอโหลดทรัพยากรพร้อม Progress Bar 0-100% + ปุ่มข้าม (Skip)
-- 2) ตอนโหลดเข้าแมพเล่นจริง (Pump Lot): แสดงเฉพาะภาพ Key Art + ชื่อฉาก/คำแนะนำ (ไม่มีหลอดโหลดทรัพยากร) ค้างไว้อย่างน้อย 3 วินาทีให้พร้อมกันก่อนเข้าเกม
-- 3) ตอนวาร์ปข้าม Place (Lobby <-> Pump Lot): แสดงหน้าจอคั่นภาพ Key Art ระดับมืออาชีพผ่าน TeleportService:SetTeleportGui

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ภาพประกอบฉากหลังปั๊มหลอด & วัดท้ายทุ่งยามเที่ยงคืน (อัปโหลดไว้บน Roblox Asset Server)
local KEY_ART_ID = "rbxassetid://98063047584423"
local LOBBY_PLACE_ID = 70980777393906
local GAME_SPLASH_MIN_SECONDS = 1.2

local FONT_TITLE = Font.new("rbxasset://fonts/families/Srisakdi.json", Enum.FontWeight.Bold)
local FONT_BODY = Font.new("rbxasset://fonts/families/Sarabun.json", Enum.FontWeight.Regular)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Sarabun.json", Enum.FontWeight.Bold)

local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(16, 14, 12),
	BarBg = Color3.fromRGB(34, 30, 26),
	Line = Color3.fromRGB(92, 82, 66),
	Gold = Color3.fromRGB(228, 196, 128),
	Cream = Color3.fromRGB(238, 230, 212),
	Dim = Color3.fromRGB(172, 162, 144),
	Blood = Color3.fromRGB(168, 36, 28),
}

local function isTH(): boolean
	return (player:GetAttribute("Lang") or "th") == "th"
end

local function tr(th: string, en: string): string
	return if isTH() then th else en
end

local function isLobbyPlace(): boolean
	if game.PlaceId == LOBBY_PLACE_ID then
		return true
	end
	if game.PlaceId ~= 0 and game.PlaceId ~= LOBBY_PLACE_ID then
		return false
	end
	return Workspace:FindFirstChild("TempleLobby") ~= nil
end

local TIPS = {
	{
		th = "💡 คำแนะนำ: กดค้าง G เพื่อพนมมือเปิดตาทิพย์ ส่องดูความผิดปกติที่ตาเปล่ามองไม่เห็น",
		en = "💡 Tip: Hold G to put your hands together in prayer and reveal hidden anomalies.",
	},
	{
		th = "💡 คำแนะนำ: หากพบความผิดปกติ ห้ามเติมน้ำมันเด็ดขาด ให้รีบวิ่งไปดึงเชือกปิดแผงสังกะสีหน้าร้าน",
		en = "💡 Tip: If you spot an anomaly, NEVER refuel them — pull the rope to close the tin shutter.",
	},
	{
		th = "💡 คำแนะนำ: ธูป 3 ดอกที่ศาลพระภูมิคือพลังชีวิตของทีม หากเผลอเติมน้ำมันให้ผี ธูปจะดับทีละดอก",
		en = "💡 Tip: The 3 incense sticks at the spirit house are your team's lives.",
	},
	{
		th = "💡 คำแนะนำ: สังเกตป้ายทะเบียน เสียงวิทยุ เงาในดงกล้วย และระดับน้ำมันในหลอดแก้วให้ดี",
		en = "💡 Tip: Check license plates, radio static, the banana grove, and the glass fuel cylinder carefully.",
	},
	{
		th = "💡 คำแนะนำ: เก็บเงินให้ครบ 1,500 บาทก่อนที่ธูปทั้ง 3 ดอกจะดับลงเพื่อเอาชีวิตรอดผ่านคืนนี้",
		en = "💡 Tip: Earn 1,500 Baht before all 3 incense sticks burn out to survive the night.",
	},
}

local function makeLoadingGui(name: string): (ScreenGui, { [string]: any })
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 999
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = C.Ink
	root.BorderSizePixel = 0
	root.Parent = sg

	-- ภาพพื้นหลัง Key Art
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "KeyArt"
	bgImage.AnchorPoint = Vector2.new(0.5, 0.5)
	bgImage.Position = UDim2.fromScale(0.5, 0.5)
	bgImage.Size = UDim2.fromScale(1.04, 1.04)
	bgImage.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	bgImage.BorderSizePixel = 0
	bgImage.Image = KEY_ART_ID
	bgImage.ScaleType = Enum.ScaleType.Crop
	bgImage.ImageColor3 = Color3.fromRGB(220, 225, 235)
	bgImage.Parent = root

	-- เงามืดทับขอบบน-ล่างให้อ่านตัวหนังสือชัดเจน
	local darkOverlay = Instance.new("Frame")
	darkOverlay.Name = "DarkOverlay"
	darkOverlay.Size = UDim2.fromScale(1, 1)
	darkOverlay.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
	darkOverlay.BackgroundTransparency = 0.32
	darkOverlay.BorderSizePixel = 0
	darkOverlay.Parent = root

	local gradOverlay = Instance.new("Frame")
	gradOverlay.Name = "Vignette"
	gradOverlay.Size = UDim2.fromScale(1, 1)
	gradOverlay.BackgroundColor3 = Color3.fromRGB(4, 4, 6)
	gradOverlay.BorderSizePixel = 0
	gradOverlay.Parent = root

	local uig = Instance.new("UIGradient")
	uig.Rotation = 90
	uig.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.28, 0.65),
		NumberSequenceKeypoint.new(0.68, 0.55),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	uig.Parent = gradOverlay

	-- ส่วนหัวด้านบนซ้าย (ชื่อเกม + สถานที่)
	local headerBox = Instance.new("Frame")
	headerBox.Name = "HeaderBox"
	headerBox.Position = UDim2.new(0, 48, 0, 42)
	headerBox.Size = UDim2.new(1, -96, 0, 110)
	headerBox.BackgroundTransparency = 1
	headerBox.Parent = root

	local badge = Instance.new("TextLabel")
	badge.Name = "PlaceBadge"
	badge.Size = UDim2.new(0, 260, 0, 26)
	badge.BackgroundColor3 = C.Blood
	badge.BackgroundTransparency = 0.15
	badge.BorderSizePixel = 0
	badge.FontFace = FONT_BOLD
	badge.TextColor3 = C.Cream
	badge.TextSize = 15
	badge.Text = "  MIDNIGHT RURAL HORROR  "
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.Parent = headerBox
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = C.Gold
	badgeStroke.Transparency = 0.4
	badgeStroke.Thickness = 1
	badgeStroke.Parent = badge

	local title = Instance.new("TextLabel")
	title.Name = "GameTitle"
	title.Position = UDim2.new(0, 0, 0, 32)
	title.Size = UDim2.new(1, 0, 0, 46)
	title.BackgroundTransparency = 1
	title.FontFace = FONT_TITLE
	title.TextColor3 = C.Cream
	title.TextStrokeColor3 = C.Ink
	title.TextStrokeTransparency = 0.15
	title.TextSize = 42
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ปั๊มหลอดท้ายทุ่ง"
	title.Parent = headerBox

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.new(0, 0, 0, 80)
	subtitle.Size = UDim2.new(1, 0, 0, 26)
	subtitle.BackgroundTransparency = 1
	subtitle.FontFace = FONT_BODY
	subtitle.TextColor3 = C.Gold
	subtitle.TextStrokeTransparency = 0.35
	subtitle.TextSize = 20
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Text = ""
	subtitle.Parent = headerBox

	-- แผงด้านล่าง (คำแนะนำ + สถานะการโหลด + Progress Bar + ปุ่มข้าม)
	local bottomPanel = Instance.new("Frame")
	bottomPanel.Name = "BottomPanel"
	bottomPanel.AnchorPoint = Vector2.new(0.5, 1)
	bottomPanel.Position = UDim2.new(0.5, 0, 1, -36)
	bottomPanel.Size = UDim2.new(1, -96, 0, 118)
	bottomPanel.BackgroundColor3 = C.Panel
	bottomPanel.BackgroundTransparency = 0.18
	bottomPanel.BorderSizePixel = 0
	bottomPanel.Parent = root

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = C.Line
	panelStroke.Thickness = 1
	panelStroke.Parent = bottomPanel

	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "TipLabel"
	tipLabel.Position = UDim2.new(0, 24, 0, 14)
	tipLabel.Size = UDim2.new(1, -48, 0, 24)
	tipLabel.BackgroundTransparency = 1
	tipLabel.FontFace = FONT_BODY
	tipLabel.TextColor3 = C.Dim
	tipLabel.TextSize = 17
	tipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tipLabel.TextTruncate = Enum.TextTruncate.AtEnd
	tipLabel.Parent = bottomPanel

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Position = UDim2.new(0, 24, 0, 44)
	statusLabel.Size = UDim2.new(0.65, 0, 0, 26)
	statusLabel.BackgroundTransparency = 1
	statusLabel.FontFace = FONT_BOLD
	statusLabel.TextColor3 = C.Cream
	statusLabel.TextSize = 19
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = bottomPanel

	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "PercentLabel"
	percentLabel.AnchorPoint = Vector2.new(1, 0)
	percentLabel.Position = UDim2.new(1, -172, 0, 44)
	percentLabel.Size = UDim2.new(0, 120, 0, 26)
	percentLabel.BackgroundTransparency = 1
	percentLabel.FontFace = FONT_BOLD
	percentLabel.TextColor3 = C.Gold
	percentLabel.TextSize = 20
	percentLabel.TextXAlignment = Enum.TextXAlignment.Right
	percentLabel.Text = "0%"
	percentLabel.Parent = bottomPanel

	-- แถบ Progress Bar (แสดงเฉพาะตอนเข้าแมพ Lobby ครั้งแรก)
	local barTrack = Instance.new("Frame")
	barTrack.Name = "BarTrack"
	barTrack.Position = UDim2.new(0, 24, 0, 78)
	barTrack.Size = UDim2.new(1, -196, 0, 18)
	barTrack.BackgroundColor3 = C.BarBg
	barTrack.BorderSizePixel = 0
	barTrack.ClipsDescendants = true
	barTrack.Parent = bottomPanel

	local barTrackStroke = Instance.new("UIStroke")
	barTrackStroke.Color = C.Line
	barTrackStroke.Thickness = 1
	barTrackStroke.Parent = barTrack

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = C.Blood
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 24, 20)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(195, 48, 36)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 160, 85)),
	})
	fillGrad.Parent = barFill

	-- ปุ่มข้าม (Skip)
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name = "SkipButton"
	skipBtn.AnchorPoint = Vector2.new(1, 0.5)
	skipBtn.Position = UDim2.new(1, -24, 0, 74)
	skipBtn.Size = UDim2.new(0, 136, 0, 36)
	skipBtn.BackgroundColor3 = C.BarBg
	skipBtn.BorderSizePixel = 0
	skipBtn.AutoButtonColor = false
	skipBtn.FontFace = FONT_BOLD
	skipBtn.TextColor3 = C.Cream
	skipBtn.TextSize = 17
	skipBtn.Text = "ข้าม (Skip) ⏭"
	skipBtn.Parent = bottomPanel

	local skipStroke = Instance.new("UIStroke")
	skipStroke.Color = C.Gold
	skipStroke.Transparency = 0.25
	skipStroke.Thickness = 1
	skipStroke.Parent = skipBtn

	skipBtn.MouseEnter:Connect(function()
		skipBtn.BackgroundColor3 = C.Blood
	end)
	skipBtn.MouseLeave:Connect(function()
		skipBtn.BackgroundColor3 = C.BarBg
	end)

	return sg, {
		root = root,
		bgImage = bgImage,
		darkOverlay = darkOverlay,
		gradOverlay = gradOverlay,
		headerBox = headerBox,
		badge = badge,
		title = title,
		subtitle = subtitle,
		bottomPanel = bottomPanel,
		tipLabel = tipLabel,
		statusLabel = statusLabel,
		percentLabel = percentLabel,
		barTrack = barTrack,
		barFill = barFill,
		skipBtn = skipBtn,
	}
end

local gui, ui = makeLoadingGui("RuralLoadingScreen")
gui.Parent = playerGui

-- อนิเมชันซูมภาพพื้นหลังช้าๆ (Ken Burns effect)
task.spawn(function()
	while gui.Parent do
		if gui.Enabled then
			local t1 = TweenService:Create(ui.bgImage, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Size = UDim2.fromScale(1.09, 1.09),
			})
			t1:Play()
			task.wait(9)
			if gui.Enabled then
				local t2 = TweenService:Create(ui.bgImage, TweenInfo.new(9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Size = UDim2.fromScale(1.02, 1.02),
				})
				t2:Play()
				task.wait(9)
			end
		else
			task.wait(1)
		end
	end
end)

-- สลับคำแนะนำทุก 4.5 วินาที
local currentTipIdx = math.random(1, #TIPS)
local function updateTipText()
	local tip = TIPS[currentTipIdx]
	ui.tipLabel.Text = if isTH() then tip.th else tip.en
end
updateTipText()

task.spawn(function()
	while gui.Parent do
		task.wait(4.5)
		if gui.Enabled then
			currentTipIdx = (currentTipIdx % #TIPS) + 1
			updateTipText()
		end
	end
end)

local function setProgressMode(showBar: boolean)
	ui.barTrack.Visible = showBar
	ui.percentLabel.Visible = showBar
	ui.skipBtn.Visible = showBar
	ui.bottomPanel.Size = if showBar then UDim2.new(1, -96, 0, 118) else UDim2.new(1, -96, 0, 82)
	ui.statusLabel.Size = if showBar then UDim2.new(0.65, 0, 0, 26) else UDim2.new(1, -48, 0, 26)
end

local function setProgress(fraction: number, statusText: string?)
	local clamped = math.clamp(fraction, 0, 1)
	local pct = math.floor(clamped * 100 + 0.5)
	ui.percentLabel.Text = ("%d%%"):format(pct)
	TweenService:Create(ui.barFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(clamped, 1),
	}):Play()
	if statusText then
		ui.statusLabel.Text = statusText
	end
end

local function fadeOutGui(duration: number?)
	local dur = duration or 0.55
	local fadeInfo = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, desc in ipairs(ui.root:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			TweenService:Create(desc, fadeInfo, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("ImageLabel") then
			TweenService:Create(desc, fadeInfo, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("Frame") then
			TweenService:Create(desc, fadeInfo, { BackgroundTransparency = 1 }):Play()
		elseif desc:IsA("UIStroke") then
			TweenService:Create(desc, fadeInfo, { Transparency = 1 }):Play()
		end
	end
	TweenService:Create(ui.root, fadeInfo, { BackgroundTransparency = 1 }):Play()
	task.wait(dur + 0.05)
	gui.Enabled = false
end

local function resetGuiOpacity()
	ui.root.BackgroundTransparency = 0
	ui.bgImage.ImageTransparency = 0
	ui.bgImage.BackgroundTransparency = 0
	ui.darkOverlay.BackgroundTransparency = 0.32
	ui.gradOverlay.BackgroundTransparency = 0
	ui.badge.BackgroundTransparency = 0.15
	ui.badge.TextTransparency = 0
	ui.title.TextTransparency = 0
	ui.subtitle.TextTransparency = 0
	ui.bottomPanel.BackgroundTransparency = 0.18
	ui.tipLabel.TextTransparency = 0
	ui.statusLabel.TextTransparency = 0
	ui.percentLabel.TextTransparency = 0
	ui.barTrack.BackgroundTransparency = 0
	ui.barFill.BackgroundTransparency = 0
	ui.skipBtn.BackgroundTransparency = 0
	ui.skipBtn.TextTransparency = 0
	for _, desc in ipairs(ui.root:GetDescendants()) do
		if desc:IsA("UIStroke") then
			desc.Transparency = 0.25
		end
	end
end

-- ================================================================
-- 1) ตอนเข้า Place:
--    - ถ้าเป็นแมพ Lobby: โหลดทรัพยากรพร้อมหลอด Progress Bar 0-100% + ปุ่มข้าม (Skip)
--    - ถ้าเป็นแมพเล่นจริง (Pump Lot): แสดงเฉพาะหน้าจอภาพ Key Art (ไม่มีหลอดโหลด/ปุ่มข้าม) ค้างไว้อย่างน้อย 3 วินาทีให้ทุกคนเข้าพร้อมกัน
-- ================================================================
local skipped = false
ui.skipBtn.Activated:Connect(function()
	if not skipped then
		skipped = true
	end
end)

task.spawn(function()
	gui.Enabled = true
	resetGuiOpacity()

	local inLobby = isLobbyPlace()
	ui.title.Text = tr("ปั๊มหลอดท้ายทุ่ง", "MIDNIGHT RURAL GAS & TIRE")
	ui.badge.Text = if inLobby
		then tr("  🏯 วัดท้ายทุ่ง · LOBBY  ", "  🏯 TEMPLE LOBBY  ")
		else tr("  ⛽ กะดึกท้ายทุ่ง · NIGHT SHIFT  ", "  ⛽ NIGHT SHIFT  ")
	ui.subtitle.Text = if inLobby
		then tr("จุดรวมตัวก่อนออกกะดึก · เลือกความยากและสมาชิกทีม", "Gather your crew and choose your difficulty")
		else tr("สังเกตความผิดปกติ · ห้ามเติมน้ำมันให้ผีเด็ดขาด", "Spot the anomalies · Never refuel a ghost")

	pcall(function()
		ContentProvider:PreloadAsync({ ui.bgImage })
	end)

	if inLobby then
		-- แมพ Lobby: มีหลอด Progress Bar 0-100% + ปุ่มข้าม
		setProgressMode(true)
		ui.skipBtn.Text = tr("ข้าม (Skip) ⏭", "Skip ⏭")
		setProgress(0.05, tr("กำลังเตรียมฉาก...", "Preparing scene..."))

		if not game:IsLoaded() and not skipped then
			setProgress(0.12, tr("กำลังซิงค์ฉากจากเซิร์ฟเวอร์...", "Syncing world from server..."))
			while not game:IsLoaded() and not skipped do
				task.wait(0.1)
			end
		end

		local assetsToLoad = {}
		local seenAssetIds: { [string]: boolean } = {}
		local function addUniqueAsset(inst: Instance, assetId: string?)
			if type(assetId) == "string" and assetId ~= "" and not seenAssetIds[assetId] then
				seenAssetIds[assetId] = true
				table.insert(assetsToLoad, inst)
			end
		end
		for _, container in ipairs({ Workspace, ReplicatedStorage, SoundService }) do
			for _, inst in ipairs(container:GetDescendants()) do
				if inst:IsA("Sound") then
					addUniqueAsset(inst, inst.SoundId)
				elseif inst:IsA("Decal") or inst:IsA("Texture") or inst:IsA("ParticleEmitter") then
					addUniqueAsset(inst, (inst :: any).Texture)
				elseif inst:IsA("MeshPart") then
					addUniqueAsset(inst, inst.MeshId ~= "" and inst.MeshId or inst.TextureID)
				elseif inst:IsA("SpecialMesh") then
					addUniqueAsset(inst, inst.MeshId ~= "" and inst.MeshId or inst.TextureId)
				elseif inst:IsA("Animation") then
					addUniqueAsset(inst, inst.AnimationId)
				end
			end
		end

		local total = math.max(1, #assetsToLoad)
		local BATCH_SIZE = 45
		for i = 1, #assetsToLoad, BATCH_SIZE do
			if skipped then
				break
			end
			local batch = {}
			local batchEnd = math.min(i + BATCH_SIZE - 1, #assetsToLoad)
			for j = i, batchEnd do
				table.insert(batch, assetsToLoad[j])
			end
			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)
			local frac = 0.12 + (batchEnd / total) * 0.88
			setProgress(
				frac,
				tr(
					("กำลังโหลดทรัพยากร... (%d / %d)"):format(batchEnd, total),
					("Loading resources... (%d / %d)"):format(batchEnd, total)
				)
			)
			task.wait(0.01)
		end

		if not skipped then
			setProgress(1, tr("โหลดทรัพยากรเสร็จสมบูรณ์ 100%", "Resources loaded 100%"))
			task.wait(0.15)
		end
	else
		-- แมพเล่นเกม (Pump Lot): ไม่มีหลอด Progress Bar โหลดทรัพยากร แสดงเฉพาะหน้าจอภาพค้างไว้อย่างน้อย 3 วินาที
		setProgressMode(false)
		ui.statusLabel.Text = tr("กำลังเข้าสู่กะดึกที่ปั๊มหลอดท้ายทุ่ง...", "Entering the midnight shift at the gas shack...")
		local startTime = os.clock()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		local elapsed = os.clock() - startTime
		if elapsed < GAME_SPLASH_MIN_SECONDS then
			task.wait(GAME_SPLASH_MIN_SECONDS - elapsed)
		end
	end

	fadeOutGui(0.55)
end)

-- ================================================================
-- 2) หน้าจอคั่นระหว่างวาร์ปข้าม Place (Teleport Transition Screen — แสดงภาพ Key Art ไม่มีหลอด %)
-- ================================================================
local teleportActive = false
local teleportLoopToken = 0

local function showTeleportScreen(opts: { destination: string?, subtitleTH: string?, subtitleEN: string? }?)
	teleportActive = true
	teleportLoopToken += 1

	skipped = true -- ปิดลูปโหลดตอนเข้าเกมถ้ายังทำงานอยู่
	gui.Enabled = true
	resetGuiOpacity()
	updateTipText()
	setProgressMode(false)

	local dest = (opts and opts.destination) or (if isLobbyPlace() then "game" else "lobby")

	if dest == "game" then
		ui.badge.Text = tr("  🚚 กำลังเดินทางเข้าสู่กะดึก  ", "  🚚 HEADING TO NIGHT SHIFT  ")
		ui.title.Text = tr("กำลังเดินทางไปปั๊มหลอดท้ายทุ่ง...", "TRAVELING TO THE GAS SHACK...")
		ui.subtitle.Text = tr(
			opts and opts.subtitleTH or "กำลังเตรียมเซิร์ฟเวอร์และส่งสมาชิกในห้องเข้าสู่คืนอาถรรพ์",
			opts and opts.subtitleEN or "Reserving server and transporting your crew into the night"
		)
	else
		ui.badge.Text = tr("  🏯 กำลังเดินทางกลับวัด  ", "  🏯 RETURNING TO TEMPLE LOBBY  ")
		ui.title.Text = tr("กำลังเดินทางกลับวัดท้ายทุ่ง (Lobby)...", "RETURNING TO TEMPLE LOBBY...")
		ui.subtitle.Text = tr(
			opts and opts.subtitleTH or "กำลังเชื่อมต่อกลับไปยังลานวัดท้ายทุ่ง",
			opts and opts.subtitleEN or "Reconnecting to the Temple Lobby plaza"
		)
	end
	ui.statusLabel.Text = tr("กำลังเชื่อมต่อเซิร์ฟเวอร์ปลายทาง กรุณารอสักครู่...", "Connecting to destination server, please wait...")

	-- ส่ง ScreenGui ชุดนี้ให้ TeleportService คงไว้บนจอระหว่างสลับเซิร์ฟเวอร์
	pcall(function()
		local tpClone = gui:Clone()
		tpClone.Name = "TeleportBridgeGui"
		TeleportService:SetTeleportGui(tpClone)
	end)
end

local function hideTeleportScreen()
	if not teleportActive then
		return
	end
	teleportActive = false
	teleportLoopToken += 1
	fadeOutGui(0.45)
end

_G.ShowTeleportScreen = showTeleportScreen
_G.HideTeleportScreen = hideTeleportScreen

-- ผูกอัตโนมัติในแมพ Lobby: เมื่อห้องสั่งเริ่มเกม (state.launching == true) ให้ขึ้นหน้าจอ Teleport ทันที
task.spawn(function()
	local lobbyRemotes = ReplicatedStorage:WaitForChild("LobbyRoomRemotes", 10)
	if lobbyRemotes then
		local roomState = lobbyRemotes:WaitForChild("RoomState", 10) :: RemoteEvent?
		if roomState then
			roomState.OnClientEvent:Connect(function(state: any)
				if state and state.launching then
					local subTH = ("ห้องที่ %s · สมาชิก %d/%d คน · กำลังเคลื่อนย้ายไปแมพปั๊ม..."):format(
						tostring(state.pad or "?"),
						tonumber(state.count) or 1,
						tonumber(state.maxPlayers) or 4
					)
					local subEN = ("Room %s · Crew %d/%d · Transporting to the gas shack..."):format(
						tostring(state.pad or "?"),
						tonumber(state.count) or 1,
						tonumber(state.maxPlayers) or 4
					)
					showTeleportScreen({
						destination = "game",
						subtitleTH = subTH,
						subtitleEN = subEN,
					})
				elseif state == nil and teleportActive then
					hideTeleportScreen()
				end
			end)
		end
	end
end)
