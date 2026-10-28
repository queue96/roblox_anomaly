-- PrayerController.client.luau
-- ระบบพนมมือฝั่ง Client (เพิ่มเมื่อ 2026-10-28)
--   กดค้าง G (คีย์บอร์ด) / ปุ่ม Y (จอย) / ปุ่ม 🙏 บนจอมือถือ -> Remotes.Pray:FireServer(true/false)
--   Server ตั้ง localPlayer:GetAttribute("Praying") + ท่าพนมมือ (Prayer.luau)
--   พนมมือครบ SIGHT_DELAY วินาที = "ตาทิพย์เปิด": เห็นของที่ติด tag GhostOnly / ของที่ติด NormalOnly หายไป
--     (เฉพาะเครื่องตัวเอง เพื่อนที่ไม่ได้พนมมือยังเห็นเป็นปกติ) ค่าที่ใช้อยู่ใน attribute VeilProp / VeilShow / VeilHide / VeilFade
--   HUD: แถบสวดกลางล่างจอ (นะโม ตัสสะ... + หลอดนับเวลา) และจอโทนเย็นซีดตอนตาทิพย์เปิด

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundService = game:GetService("SoundService")
local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local function ui(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?))
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local PrayRemote = remotes:WaitForChild("Pray") :: RemoteEvent

local SIGHT_DELAY = 1.5 -- พนมมือนานเท่านี้ถึงจะเห็นผี
local GHOST_TAG = "GhostOnly"
local NORMAL_TAG = "NormalOnly"
local DEFAULT_FADE = 0.6

-- ---------------------------------------------------------------- ม่านตาทิพย์
local sightOpen = false

-- เฉพาะของในฉาก (ไม่แตะร่าง Clone ในจอผีหลอก ViewportFrame)
local function inWorld(d: Instance): boolean
	return d:IsDescendantOf(Workspace) or d:IsDescendantOf(game:GetService("SoundService"))
end

local function setVeil(d: Instance, visible: boolean, instant: boolean)
	local prop = d:GetAttribute("VeilProp")
	if type(prop) ~= "string" then
		return
	end
	local value = if visible then d:GetAttribute("VeilShow") else d:GetAttribute("VeilHide")
	if value == nil then
		return
	end
	if type(value) == "boolean" then
		(d :: any)[prop] = value
		return
	end
	local fade = d:GetAttribute("VeilFade")
	local t = if instant then 0 else (if type(fade) == "number" then fade else DEFAULT_FADE)
	if t <= 0 then
		(d :: any)[prop] = value
	else
		TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Sine), { [prop] = value }):Play()
	end
end

local function applyAll(instant: boolean)
	for _, d in ipairs(CollectionService:GetTagged(GHOST_TAG)) do
		if inWorld(d) then
			setVeil(d, sightOpen, instant)
		end
	end
	for _, d in ipairs(CollectionService:GetTagged(NORMAL_TAG)) do
		if inWorld(d) then
			setVeil(d, not sightOpen, instant)
		end
	end
end

CollectionService:GetInstanceAddedSignal(GHOST_TAG):Connect(function(d)
	if inWorld(d) then
		setVeil(d, sightOpen, not sightOpen)
	end
end)
CollectionService:GetInstanceAddedSignal(NORMAL_TAG):Connect(function(d)
	if inWorld(d) then
		setVeil(d, not sightOpen, sightOpen)
	end
end)
-- Server เอา tag ออก (ผีไปแล้ว) -> คืนค่าปกติ
CollectionService:GetInstanceRemovedSignal(GHOST_TAG):Connect(function(d)
	if d.Parent then
		setVeil(d, false, true)
	end
end)
CollectionService:GetInstanceRemovedSignal(NORMAL_TAG):Connect(function(d)
	if d.Parent then
		setVeil(d, true, true)
	end
end)

-- ---------------------------------------------------------------- จอโทนเย็นซีดตอนตาทิพย์เปิด
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "PrayerSight"
grade.Enabled = false
grade.Parent = Lighting
local SIGHT_GRADE = { Saturation = -0.55, Contrast = 0.12, TintColor = Color3.fromRGB(200, 215, 235), Brightness = 0.03 }
local NO_GRADE = { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1), Brightness = 0 }
for k, v in pairs(NO_GRADE) do
	(grade :: any)[k] = v
end

-- ---------------------------------------------------------------- HUD: แถบสวด (อยู่ด้านข้างขวาเหนือปุ่มคีย์ ไม่มี Emoji มีแค่ข้อความสั้นๆ "กำลังสวด" + หลอดส้ม)
local gui = Instance.new("ScreenGui")
gui.Name = "PrayerHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "PrayBar"
bar.AnchorPoint = Vector2.new(1, 1)
bar.Position = UDim2.new(1, -30, 1, -238) -- ชิดขวา เหนือแถบปุ่มคีย์ ไม่บังกลางจอ
bar.Size = UDim2.new(0, 150, 0, 30)
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0
bar.Visible = false
bar.Parent = gui

local label = Instance.new("TextLabel")
label.Name = "Text"
label.BackgroundTransparency = 1
label.Position = UDim2.new(0, 0, 0, 0)
label.Size = UDim2.new(1, 0, 0, 20)
label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
label.TextColor3 = Color3.fromRGB(236, 228, 208)
label.TextXAlignment = Enum.TextXAlignment.Right
label.TextScaled = true
label.AutoLocalize = false
label.Parent = bar
local sizeLimit = Instance.new("UITextSizeConstraint")
sizeLimit.MaxTextSize = 16
sizeLimit.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = label

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(1, 0)
track.Position = UDim2.new(1, 0, 0, 23)
track.Size = UDim2.new(1, 0, 0, 4)
track.BackgroundColor3 = Color3.fromRGB(48, 44, 38)
track.BorderSizePixel = 0
track.Parent = bar
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(230, 120, 50) -- หลอดสีส้ม
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

-- ---------------------------------------------------------------- เสียงสวดมนต์เฉพาะตัวผู้เล่น (ดังที่ตัว Player เอง และได้ยินเฉพาะเครื่องตัวเองเท่านั้น)
local myChantSound: Sound? = nil
local currentChantIndex = 0
local currentChantScared = false

local function isGhostDetectedNow(): boolean
	if remotes:GetAttribute("IsAnomaly") == true then
		return true
	end
	for _, d in ipairs(CollectionService:GetTagged(GHOST_TAG)) do
		if d:IsDescendantOf(Workspace) then
			return true
		end
	end
	return false
end

local function stopMyChant()
	if myChantSound then
		local s = myChantSound
		myChantSound = nil
		TweenService:Create(s, TweenInfo.new(0.2), { Volume = 0 }):Play()
		task.delay(0.22, function()
			if s then
				s:Stop()
				s:Destroy()
			end
		end)
	end
end

local function playOrUpdateMyChant(scaredMode: boolean, forceNewIndex: boolean?)
	if forceNewIndex or currentChantIndex == 0 then
		currentChantIndex = (currentChantIndex % 4) + 1
	end
	currentChantScared = scaredMode
	local preset = SoundBank.GetChantPreset(currentChantIndex, scaredMode)
	if not preset then
		return
	end
	local soundId, isCustom = SoundBank.ResolveId(preset)
	if not isCustom then
		-- ถ้ายังไม่ได้ลากไฟล์ chant_thai_*.wav เข้า UploadedSounds ไม่ต้องเอาเสียงพระวัดสำรองมาเล่น
		return
	end
	local char = localPlayer.Character
	local head = (char and char:FindFirstChild("Head") :: BasePart?) or SoundService
	if not myChantSound or not myChantSound.Parent then
		local s = Instance.new("Sound")
		s.Name = "PlayerSelfChant"
		s.Looped = true
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = 35
		SoundBank.ApplyWarmEffects(s, { low = 2, mid = 3, high = -14 })
		s.Parent = head
		myChantSound = s
	end
	local snd = myChantSound :: Sound
	snd.PlaybackSpeed = preset.speed or 1.0
	if snd.SoundId ~= soundId then
		snd.SoundId = soundId
		snd.Volume = preset.volume or 0.48
		snd:Play()
	elseif not snd.IsPlaying then
		snd.Volume = preset.volume or 0.48
		snd:Play()
	end
end

-- ถ้าระหว่างพนมมืออยู่แล้วผีโผล่มา (หรือตาทิพย์เปิดแล้วเห็นผี) ให้สลับเสียงสวดของตัวเองเป็นโหมดสวดเร็วกลัวผีทันที!
remotes:GetAttributeChangedSignal("IsAnomaly"):Connect(function()
	if localPlayer:GetAttribute("Praying") == true and sightOpen then
		local ghostNow = isGhostDetectedNow()
		if ghostNow ~= currentChantScared then
			playOrUpdateMyChant(ghostNow, false)
		end
	end
end)

-- ---------------------------------------------------------------- สถานะพนมมือ (ยึดตาม attribute ที่ Server ตั้ง)
local prayToken = 0
local function setSight(open: boolean)
	if sightOpen == open then
		return
	end
	sightOpen = open
	applyAll(false)
	grade.Enabled = true
	TweenService:Create(grade, TweenInfo.new(if open then 0.8 else 0.5), if open then SIGHT_GRADE else NO_GRADE):Play()
	label.Text = ui(if open then "PraySightOpen" else "PrayChanting")
	label.TextColor3 = Color3.fromRGB(236, 228, 208)
	if open and localPlayer:GetAttribute("Praying") == true then
		-- พอตาทิพย์เปิด ถ้ามีผีอยู่ตรงหน้า ให้เปลี่ยนจากสวดปกติเป็นสวดเร็วกลัวผีทันที!
		if isGhostDetectedNow() and not currentChantScared then
			playOrUpdateMyChant(true, false)
		end
	end
end

local function onPrayingChanged()
	local praying = localPlayer:GetAttribute("Praying") == true
	prayToken += 1
	local token = prayToken
	if praying then
		bar.Visible = true
		label.Text = ui("PrayChanting")
		label.TextColor3 = Color3.fromRGB(236, 228, 208)
		fill.Size = UDim2.fromScale(0, 1)
		-- เริ่มสวดด้วยโหมดปกติที่ตัวผู้เล่นเอง (ถ้าตาทิพย์เปิดแล้วเจอผี จะสลับเป็นสวดเร็วอัตโนมัติ)
		playOrUpdateMyChant(false, true)
		TweenService:Create(fill, TweenInfo.new(SIGHT_DELAY, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		task.delay(SIGHT_DELAY, function()
			if prayToken == token then
				setSight(true)
			end
		end)
	else
		bar.Visible = false
		stopMyChant()
		setSight(false)
	end
end
localPlayer:GetAttributeChangedSignal("Praying"):Connect(onPrayingChanged)
localPlayer:GetAttributeChangedSignal("Lang"):Connect(function()
	if bar.Visible then
		label.Text = ui(if sightOpen then "PraySightOpen" else "PrayChanting")
	end
end)
onPrayingChanged()
applyAll(true)

-- ---------------------------------------------------------------- ปุ่มกด (กดค้าง = พนมมือ ปล่อย = เลิก)
local holding = false
local function onPray(_name: string, state: Enum.UserInputState, _input: InputObject)
	if state == Enum.UserInputState.Begin then
		holding = true
		PrayRemote:FireServer(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if holding then
			holding = false
			PrayRemote:FireServer(false)
		end
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("Pray", onPray, true, Enum.KeyCode.G, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Pray", "สวด")
ContextActionService:SetPosition("Pray", UDim2.new(1, -170, 1, -150))

-- เกิดใหม่ระหว่างกดค้าง: Server ล้างสถานะแล้ว ฝั่งนี้ก็ล้างด้วย
localPlayer.CharacterAdded:Connect(function()
	holding = false
end)
