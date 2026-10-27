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

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
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

-- ---------------------------------------------------------------- HUD: แถบสวด
local gui = Instance.new("ScreenGui")
gui.Name = "PrayerHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bar = Instance.new("Frame")
bar.Name = "PrayBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -222) -- เหนือกล่องคำพูดลูกค้า
bar.Size = UDim2.new(0, 380, 0, 44)
bar.BackgroundColor3 = Color3.fromRGB(8, 7, 6)
bar.BackgroundTransparency = 0.35
bar.BorderSizePixel = 0
bar.Visible = false
bar.Parent = gui
local grad = Instance.new("UIGradient")
grad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0),
	NumberSequenceKeypoint.new(0.85, 0),
	NumberSequenceKeypoint.new(1, 1),
})
grad.Parent = bar

local label = Instance.new("TextLabel")
label.Name = "Text"
label.BackgroundTransparency = 1
label.Position = UDim2.new(0, 0, 0, 4)
label.Size = UDim2.new(1, 0, 0, 28)
label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
label.TextColor3 = Color3.fromRGB(236, 228, 208)
label.TextScaled = true
label.AutoLocalize = false
label.Parent = bar
local sizeLimit = Instance.new("UITextSizeConstraint")
sizeLimit.MaxTextSize = 20
sizeLimit.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = label

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, 36)
track.Size = UDim2.new(0, 240, 0, 3)
track.BackgroundColor3 = Color3.fromRGB(58, 54, 46)
track.BorderSizePixel = 0
track.Parent = bar
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(230, 120, 50)
fill.BorderSizePixel = 0
fill.Parent = track

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
	label.TextColor3 = if open then Color3.fromRGB(190, 215, 240) else Color3.fromRGB(236, 228, 208)
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
		TweenService:Create(fill, TweenInfo.new(SIGHT_DELAY, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		task.delay(SIGHT_DELAY, function()
			if prayToken == token then
				setSight(true)
			end
		end)
	else
		bar.Visible = false
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
ContextActionService:SetTitle("Pray", "🙏")
ContextActionService:SetPosition("Pray", UDim2.new(1, -170, 1, -150))

-- เกิดใหม่ระหว่างกดค้าง: Server ล้างสถานะแล้ว ฝั่งนี้ก็ล้างด้วย
localPlayer.CharacterAdded:Connect(function()
	holding = false
end)
