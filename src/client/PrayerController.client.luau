-- PrayerController.client.luau
-- ระบบพนมมือฝั่ง Client (เพิ่มเมื่อ 2026-10-28, ปรับปรุงโหมด Toggle เปิด/ปิด เมื่อ 2026-10-30)
--   กด G (คีย์บอร์ด) / ปุ่ม Y (จอย) / ปุ่ม 🙏 บนจอมือถือ เพื่อเปิด/ปิดพนมมือ (Toggle)
--   Server ตั้ง localPlayer:GetAttribute("Praying") + ท่าพนมมือ (Prayer.luau) โดยผู้เล่นยังเดินสำรวจได้อิสระ
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
local DEFAULT_FADE = 2.0 -- ค่อยๆ เห็นจากจางๆ ชัดขึ้นเรื่อยๆ ตอนตาทิพย์เปิด (ผู้ใช้ 2026-11-16: ไม่ให้โผล่มาดื้อๆ)
local CLOSE_FADE = 0.8 -- ตอนเลิกพนมมือ ค่อยๆ จางกลับเป็นปกติ

-- ---------------------------------------------------------------- ม่านตาทิพย์
local sightOpen = false

-- เฉพาะของในฉาก (ไม่แตะร่าง Clone ในจอผีหลอก ViewportFrame)
local function inWorld(d: Instance): boolean
	return d:IsDescendantOf(Workspace) or d:IsDescendantOf(game:GetService("SoundService"))
end

-- ลูกค้าที่ยังไม่ได้จอดที่ร้านนานพอ (server ติด tag VeilLock ไว้ที่รถ/คน): พนมมือยังไม่เห็นผีของรายนี้
local LOCK_TAG = "VeilLock"
local function locked(d: Instance): boolean
	local a = d.Parent
	while a and a ~= Workspace do
		if CollectionService:HasTag(a, LOCK_TAG) then
			return true
		end
		a = a.Parent
	end
	return CollectionService:HasTag(d, LOCK_TAG)
end

local SHADOW_COLOR = Color3.fromRGB(16, 16, 18) -- โทนเงาดำเท่าสีผม: ช่วงโปร่งแสงไม่ให้หัวขาวทับผมจนดูหัวโล้น (2026-11-16)
local tintShown: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local veilSeq: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

local function isDriverReplacement(d: Instance): boolean
	local a = d.Parent
	while a and a ~= Workspace do
		local n = a.Name
		if n == "GhostDouble" or n == "BurnedCorpseDouble" or n == "GhostRiderModel" or n == "TwistedHead" then
			return true
		end
		a = a.Parent
	end
	return false
end

local function setPartTint(d: BasePart, sa: SurfaceAppearance?, col: Color3, saCol: Color3?)
	d.Color = col
	if sa and saCol then
		pcall(function()
			(sa :: any).Color = saCol
		end)
	end
end

local function tweenPartTint(d: BasePart, sa: SurfaceAppearance?, info: TweenInfo, col: Color3, saCol: Color3?)
	TweenService:Create(d, info, { Color = col }):Play()
	if sa and saCol then
		local ok, tw = pcall(function()
			return TweenService:Create(sa, info, { Color = saCol } :: any)
		end)
		if ok and tw then
			tw:Play()
		else
			pcall(function()
				(sa :: any).Color = saCol
			end)
		end
	end
end

local function setVeil(d: Instance, visible: boolean, instant: boolean)
	if locked(d) then
		-- ยังล็อก: ผีซ่อนไว้ ของปกติยังเห็น (เหมือนไม่ได้พนมมือ)
		if CollectionService:HasTag(d, "GhostOnly") then
			visible = false
		elseif CollectionService:HasTag(d, "NormalOnly") then
			visible = true
		end
	end
	local prop = d:GetAttribute("VeilProp")
	if type(prop) ~= "string" then
		return
	end
	local value = if visible then d:GetAttribute("VeilShow") else d:GetAttribute("VeilHide")
	if value == nil then
		return
	end
	local seq = (veilSeq[d] or 0) + 1
	veilSeq[d] = seq
	-- ของผีที่ค่อยๆ เปลี่ยนสีหลังโผล่ (น้ำมันเลือด: โผล่มาเป็นสีน้ำมันเดิมก่อน แล้วค่อยๆ แดง)
	--   VeilTintFrom / VeilTintTo (+ VeilTintSAFrom / VeilTintSATo ของ SurfaceAppearance) / VeilTintTime
	--   เล่นเฉพาะตอนเพิ่งโผล่ (ซ่อน -> เห็น) ไม่เล่นซ้ำตอน applyAll ระหว่างที่เห็นอยู่แล้ว
	local tintTo = d:GetAttribute("VeilTintTo")
	if typeof(tintTo) == "Color3" and d:IsA("BasePart") then
		if not visible then
			tintShown[d] = nil
		elseif not tintShown[d] then
			tintShown[d] = true
			local info = TweenInfo.new(tonumber(d:GetAttribute("VeilTintTime")) or 3, Enum.EasingStyle.Sine)
			local from = d:GetAttribute("VeilTintFrom")
			if typeof(from) == "Color3" then
				d.Color = from
			end
			TweenService:Create(d, info, { Color = tintTo }):Play()
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			local saFrom, saTo = d:GetAttribute("VeilTintSAFrom"), d:GetAttribute("VeilTintSATo")
			if sa and typeof(saTo) == "Color3" then
				local ok, tw = pcall(function()
					return TweenService:Create(sa, info, { Color = saTo } :: any)
				end)
				if ok and tw then
					if typeof(saFrom) == "Color3" then
						pcall(function()
							(sa :: any).Color = saFrom
						end)
					end
					tw:Play()
				else
					-- ไล่สีไม่ได้ = แดงทันที (ห้ามค้างเป็นสีน้ำมันเดิม)
					pcall(function()
						(sa :: any).Color = saTo
					end)
				end
			end
		end
	end
	local fade = d:GetAttribute("VeilFade")
	local defaultT = if sightOpen then DEFAULT_FADE else CLOSE_FADE
	local t = if instant then 0 else (if type(fade) == "number" then fade else defaultT)
	if type(value) == "boolean" then
		if d:IsA("Light") and t > 0 then
			local origB = d:GetAttribute("VeilOrigBrightness")
			if type(origB) ~= "number" then
				origB = (d :: any).Brightness
				d:SetAttribute("VeilOrigBrightness", origB)
			end
			if value then
				(d :: any).Brightness = 0;
				(d :: any)[prop] = true
				TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = origB }):Play()
			else
				TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Brightness = 0 }):Play()
			end
			return
		elseif (d:IsA("SurfaceGui") or d:IsA("BillboardGui")) and t > 0 then
			if value then
				(d :: any)[prop] = true
				for _, ch in ipairs(d:GetDescendants()) do
					if ch:IsA("TextLabel") then
						ch.TextTransparency = 1
						TweenService:Create(ch, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { TextTransparency = 0 }):Play()
					end
				end
				return
			end
		end
		(d :: any)[prop] = value
		return
	end
	-- การค่อยๆ โผล่ของโมเดลผี/คนโดยไม่ให้หัวโล้น (Roblox วาด BodyHead ทับชิ้นผมถ้า Transparency > 0 และหัวยังเป็นสีขาว):
	--   ขั้นที่ 1 (0 -> 0.45 วิ): ย้อมเป็นเงาดำเข้มเท่าสีผมขณะเฟดความทึบ (หรือมืดลงจากร่างคนจริง)
	--   ขั้นที่ 2 (0.45 -> 2.0 วิ): พอ Transparency = 0 (Depth Buffer ทำงานเต็มที่ ผมทับหัว 100%) ค่อยๆ ไล่สีจากเงาดำจนเห็นรายละเอียดผีชัดขึ้นเรื่อยๆ
	if prop == "Transparency" and d:IsA("BasePart") and tintTo == nil then
		local origCol = d:GetAttribute("VeilOrigColor") :: Color3?
		if typeof(origCol) ~= "Color3" then
			origCol = d.Color
			d:SetAttribute("VeilOrigColor", origCol)
		end
		local sa = d:FindFirstChildOfClass("SurfaceAppearance")
		local origSACol = d:GetAttribute("VeilOrigSAColor") :: Color3?
		if sa and typeof(origSACol) ~= "Color3" then
			origSACol = (sa :: any).Color
			d:SetAttribute("VeilOrigSAColor", origSACol)
		end
		if t <= 0 then
			d.Transparency = value
			setPartTint(d, sa, origCol :: Color3, origSACol)
			return
		end
		local isGhostPart = CollectionService:HasTag(d, GHOST_TAG)
		local isNormalPart = CollectionService:HasTag(d, NORMAL_TAG)
		if isGhostPart and visible then
			if isDriverReplacement(d) then
				-- ร่างผีที่ซ้อนทับคนขับ: รอ 0.45 วิให้คนขับมืดเป็นเงาดำก่อน แล้วสลับเป็นร่างผีที่ Transparency = 0 ค่อยๆ ชัดขึ้นจากเงาดำ
				d.Transparency = 1
				setPartTint(d, sa, SHADOW_COLOR, SHADOW_COLOR)
				task.delay(0.45, function()
					if veilSeq[d] ~= seq or not d.Parent then
						return
					end
					d.Transparency = value
					tweenPartTint(d, sa, TweenInfo.new(math.max(0.4, t - 0.45), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), origCol :: Color3, origSACol)
				end)
			else
				-- ผีที่โผล่เพิ่มขึ้นมา (เช่น ผีซ้อนท้าย / ผีเด็กขี่คอ): ก่อตัวจากเงาดำจางๆ จนทึบใน 0.50 วิ (สีเดียวกับผม ไม่เห็นหัวโล้น) แล้วค่อยๆ สว่างชัดขึ้นจนครบ 2 วิ
				setPartTint(d, sa, SHADOW_COLOR, SHADOW_COLOR)
				TweenService:Create(d, TweenInfo.new(0.50, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = value }):Play()
				task.delay(0.48, function()
					if veilSeq[d] ~= seq or not d.Parent then
						return
					end
					d.Transparency = value
					tweenPartTint(d, sa, TweenInfo.new(math.max(0.4, t - 0.48), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), origCol :: Color3, origSACol)
				end)
			end
			return
		elseif isNormalPart and not visible then
			-- ร่างคนปกติตอนตาทิพย์เปิด: ค่อยๆ มืดลงเป็นเงาดำใน 0.45 วิ (โดยยังทึบอยู่ ผมไม่หลุด) แล้วสลับให้ร่างผีขึ้นมาแทน
			local showVal = d:GetAttribute("VeilShow")
			if type(showVal) == "number" then
				d.Transparency = showVal
			end
			tweenPartTint(d, sa, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In), SHADOW_COLOR, SHADOW_COLOR)
			task.delay(0.45, function()
				if veilSeq[d] ~= seq or not d.Parent then
					return
				end
				d.Transparency = value
				setPartTint(d, sa, origCol :: Color3, origSACol)
			end)
			return
		elseif isGhostPart and not visible then
			-- ตอนเลิกพนมมือ: ผีค่อยๆ มืดกลับเป็นเงาดำแล้วจางหายไป
			tweenPartTint(d, sa, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), SHADOW_COLOR, SHADOW_COLOR)
			task.delay(0.32, function()
				if veilSeq[d] ~= seq or not d.Parent then
					return
				end
				if isDriverReplacement(d) then
					d.Transparency = value
					setPartTint(d, sa, origCol :: Color3, origSACol)
				else
					TweenService:Create(d, TweenInfo.new(0.40, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Transparency = value }):Play()
				end
			end)
			return
		elseif isNormalPart and visible then
			-- ตอนเลิกพนมมือ: ร่างคนปกติค่อยๆ สว่างกลับมาจากเงาดำ
			task.delay(0.32, function()
				if veilSeq[d] ~= seq or not d.Parent then
					return
				end
				setPartTint(d, sa, SHADOW_COLOR, SHADOW_COLOR)
				d.Transparency = value
				tweenPartTint(d, sa, TweenInfo.new(0.48, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), origCol :: Color3, origSACol)
			end)
			return
		end
	end
	if t <= 0 then
		(d :: any)[prop] = value
	else
		TweenService:Create(d, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { [prop] = value }):Play()
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
-- ปลดล็อก (จอดที่ร้านนานพอแล้ว): คนที่พนมมืออยู่เห็นผีทันที
CollectionService:GetInstanceRemovedSignal(LOCK_TAG):Connect(function()
	if sightOpen then
		applyAll(false)
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
-- ตาทิพย์เปิด: ยกเงามืดขึ้น (Contrast ติดลบ + Brightness) ให้มองเห็นรายละเอียดจับผิดผีได้ง่าย
local SIGHT_GRADE = { Saturation = -0.55, Contrast = -0.1, TintColor = Color3.fromRGB(200, 215, 235), Brightness = 0.1 }
-- สวดอยู่: ภาพค่อยๆ สว่างขึ้นจนตาทิพย์เปิด (Lighting.ExposureCompensation ฝั่ง Client)
local PRAY_EXPOSURE = 1.2

-- ---------------------------------------------------------------- เสียงรอบตัวทึบลงตอนสวด (เหมือนเข้าภวังค์) ให้เสียงสวดตัวเองเด่น
-- ใส่ EQ ที่ SoundGroup SFX (SettingsController จัดเสียงฉากทุกตัวเข้ากลุ่มนี้) เสียงสวดตัวเองอยู่กลุ่ม Music จึงไม่โดน
local function soundGroup(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	return g :: SoundGroup
end
local muffle = Instance.new("EqualizerSoundEffect")
muffle.Name = "PrayMuffle"
muffle.LowGain = 0
muffle.MidGain = 0
muffle.HighGain = 0
muffle.Priority = 10
muffle.Parent = soundGroup("SFX")
local MUFFLED = { LowGain = -4, MidGain = -12, HighGain = -28 }
local CLEAR = { LowGain = 0, MidGain = 0, HighGain = 0 }
local function setMuffle(on: boolean, seconds: number)
	TweenService:Create(muffle, TweenInfo.new(seconds, Enum.EasingStyle.Sine), if on then MUFFLED else CLEAR):Play()
end
-- ผีหลอก: เสียงต้องดังชัดเต็มที่ทันที แม้กำลังสวดอยู่
local jumpscareRemote = remotes:FindFirstChild("TriggerJumpscare")
if jumpscareRemote and jumpscareRemote:IsA("RemoteEvent") then
	jumpscareRemote.OnClientEvent:Connect(function()
		setMuffle(false, 0)
	end)
end
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
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiFit")).Attach(gui) -- ย่อตามความสูงจอ (shared/UiFit)

local bar = Instance.new("Frame")
bar.Name = "PrayBar"
bar.AnchorPoint = Vector2.new(1, 1)
bar.Position = UDim2.new(1, -16, 1, -106) -- ชิดขวา เหนือแถบปุ่ม V / G กะทัดรัด
bar.Size = UDim2.new(0, 140, 0, 22)
bar.BackgroundTransparency = 1
bar.BorderSizePixel = 0
bar.Visible = false
bar.Parent = gui
-- มือถือ: ขวาล่างเป็นปุ่มสวด/นั่งยอง/กระโดด -> ย้ายขึ้นมุมขวาบน ใต้แผงเงิน (แถวเดียวกับปุ่มตั้งค่า) ซ้ายรูปศาล (ItemSlots 60px)
if (require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any).TouchMode == true then
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, -84 - require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SafeArea")).Pad(), 0, 58) -- มือถือเว้นขอบเพิ่ม (shared/SafeArea)
end

local label = Instance.new("TextLabel")
label.Name = "Text"
label.BackgroundTransparency = 1
label.Position = UDim2.new(0, 0, 0, 0)
label.Size = UDim2.new(1, 0, 0, 15)
label.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
label.TextColor3 = Color3.fromRGB(220, 212, 194)
label.TextXAlignment = Enum.TextXAlignment.Right
label.TextScaled = true
label.AutoLocalize = false
label.Parent = bar
local sizeLimit = Instance.new("UITextSizeConstraint")
sizeLimit.MaxTextSize = 13
sizeLimit.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = label

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(1, 0)
track.Position = UDim2.new(1, 0, 0, 18)
track.Size = UDim2.new(1, 0, 0, 3)
track.BackgroundColor3 = Color3.fromRGB(48, 44, 38)
track.BorderSizePixel = 0
track.Parent = bar
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(185, 130, 70) -- หลอดสีส้มหม่นคุมโทน
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
	-- ลูกค้าที่ยังล็อกอยู่: เสียงสวดยังไม่เปลี่ยน (ไม่บอกใบ้ก่อนเห็นผี)
	local anyLocked = false
	for _, l in ipairs(CollectionService:GetTagged(LOCK_TAG)) do
		if l:IsDescendantOf(Workspace) then
			anyLocked = true
			break
		end
	end
	if remotes:GetAttribute("IsAnomaly") == true and not anyLocked then
		return true
	end
	for _, d in ipairs(CollectionService:GetTagged(GHOST_TAG)) do
		if d:IsDescendantOf(Workspace) and not locked(d) then
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
		s:SetAttribute("SoundCategory", "Music") -- อยู่กลุ่ม Music ไม่โดน PrayMuffle (ต้องตั้งก่อน Parent)
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

-- (เดิม) เจอผีระหว่างพนมมือ: เสียงสวดคงเดิม ไม่เปลี่ยนเป็นสวดเร็ว
-- แต่เล่นเสียงตกใจ GHOST_SIGHT_ID หนึ่งครั้งต่อการเจอผีหนึ่งรอบ (ผีหายไปแล้วโผล่ใหม่ = เล่นอีก)
local GHOST_SIGHT_ID = "rbxassetid://123314010660698"
local GHOST_SIGHT_VOLUME = 0.5
local ghostStung = false
-- ปิดแล้ว (2026-11-03): ผีที่มากับลูกค้า (เติมน้ำมัน / เติมลม / งานอื่นๆ) ไม่มีเสียงเฉลยตอนเจอ ให้ผู้เล่นสังเกตเอง
-- เสียงตอนเจอผีมีเฉพาะผีฉาก (client/SceneryGhostWatch)
local STING_FOR_EVENT_GHOSTS = false
local function onGhostCheck()
	if not STING_FOR_EVENT_GHOSTS then
		return
	end
	local ghostNow = isGhostDetectedNow()
	if not ghostNow then
		ghostStung = false
		return
	end
	if ghostStung or localPlayer:GetAttribute("Praying") ~= true or not sightOpen then
		return
	end
	ghostStung = true
	local s = Instance.new("Sound")
	s.Name = "GhostSightSting"
	s.SoundId = GHOST_SIGHT_ID
	s.Volume = GHOST_SIGHT_VOLUME
	s:SetAttribute("SoundCategory", "Music") -- ไม่โดน PrayMuffle (กลุ่ม SFX อู้อี้ตอนพนมมือ) ต้องได้ยินชัด
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(30, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end
remotes:GetAttributeChangedSignal("IsAnomaly"):Connect(onGhostCheck)
CollectionService:GetInstanceRemovedSignal(LOCK_TAG):Connect(function()
	task.defer(onGhostCheck)
end)
CollectionService:GetInstanceAddedSignal(GHOST_TAG):Connect(function()
	task.defer(onGhostCheck)
end)
CollectionService:GetInstanceRemovedSignal(GHOST_TAG):Connect(function()
	task.defer(onGhostCheck)
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
	grade:SetAttribute("Open", open) -- AmbienceController ฟังค่านี้เพื่อปรับ blur / vignette ตอนตาทิพย์เปิด
	TweenService:Create(grade, TweenInfo.new(if open then 0.8 else 0.5), if open then SIGHT_GRADE else NO_GRADE):Play()
	label.Text = ui(if open then "PraySightOpen" else "PrayChanting")
	label.TextColor3 = Color3.fromRGB(236, 228, 208)
	if open then
		onGhostCheck() -- ตาทิพย์เปิดแล้วมีผีอยู่ = เสียงตกใจ (เสียงสวดคงเดิม)
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
		-- Game Pass สวดมนต์ไว (shared/RobuxShop): เปิดตาทิพย์เร็วขึ้น
		local delay = if localPlayer:GetAttribute("FastPrayer") == true then 0.9 else SIGHT_DELAY
		TweenService:Create(fill, TweenInfo.new(delay, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
		TweenService:Create(Lighting, TweenInfo.new(delay, Enum.EasingStyle.Sine), { ExposureCompensation = PRAY_EXPOSURE }):Play()
		setMuffle(true, delay)
		task.delay(delay, function()
			if prayToken == token then
				setSight(true)
			end
		end)
	else
		bar.Visible = false
		stopMyChant()
		setSight(false)
		TweenService:Create(Lighting, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { ExposureCompensation = 0 }):Play()
		setMuffle(false, 0.6)
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

-- ---------------------------------------------------------------- ได้ยินเสียงสวดของผู้เล่นคนอื่น (เสียง 3D ที่หัวคนนั้น)
-- เสียงสวดของตัวเองสร้างฝั่ง Client เลยไม่ replicate: เครื่องนี้สร้างเสียงให้คนอื่นที่ Praying เองจาก attribute ของเขา
local otherChants: { [Player]: Sound } = {}
local otherChantIndex: { [Player]: number } = {}
local function stopOtherChant(p: Player)
	local s = otherChants[p]
	otherChants[p] = nil
	if s then
		TweenService:Create(s, TweenInfo.new(0.2), { Volume = 0 }):Play()
		task.delay(0.22, function()
			s:Destroy()
		end)
	end
end
local function onOtherPraying(p: Player)
	if p:GetAttribute("Praying") ~= true then
		stopOtherChant(p)
		return
	end
	local head = p.Character and p.Character:FindFirstChild("Head") :: BasePart?
	if not head or otherChants[p] then
		return
	end
	local idx = ((otherChantIndex[p] or (p.UserId % 4)) % 4) + 1 -- สวดคนละบทต่อรอบ เหมือนตัวเอง
	otherChantIndex[p] = idx
	local preset = SoundBank.GetChantPreset(idx, false)
	if not preset then
		return
	end
	local soundId, isCustom = SoundBank.ResolveId(preset)
	if not isCustom then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "OtherPlayerChant"
	s:SetAttribute("SoundCategory", "Music")
	s.SoundId = soundId
	s.Looped = true
	s.Volume = (preset.volume or 0.48) * 0.45 -- เบากว่าเสียงสวดของตัวเอง ได้ยินเพื่อนแค่แผ่วๆ
	s.PlaybackSpeed = preset.speed or 1.0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 35
	SoundBank.ApplyWarmEffects(s, { low = 2, mid = 3, high = -14 })
	s.Parent = head
	s:Play()
	otherChants[p] = s
end
local function watchOther(p: Player)
	if p == localPlayer then
		return
	end
	p:GetAttributeChangedSignal("Praying"):Connect(function()
		onOtherPraying(p)
	end)
	p.CharacterAdded:Connect(function()
		stopOtherChant(p)
		task.defer(onOtherPraying, p)
	end)
	onOtherPraying(p)
end
for _, p in ipairs(Players:GetPlayers()) do
	watchOther(p)
end
Players.PlayerAdded:Connect(watchOther)
Players.PlayerRemoving:Connect(stopOtherChant)

-- ---------------------------------------------------------------- ปุ่มกด (กดเพื่อเปิด/ปิดพนมมือ Toggle)
local lastToggle = 0
local function onPray(_name: string, state: Enum.UserInputState, _input: InputObject)
	if state == Enum.UserInputState.Begin then
		local now = os.clock()
		if now - lastToggle < 0.25 then
			return Enum.ContextActionResult.Sink
		end
		lastToggle = now
		local isPraying = localPlayer:GetAttribute("Praying") == true
		PrayRemote:FireServer(not isPraying)
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("Pray", onPray, true, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

-- ปุ่มบนมือถือ (ContextActionService): ใหญ่ขึ้นให้นิ้วกดง่าย + จางลงไม่บังฉาก
local function styleTouchButton(action: string, pos: UDim2)
	task.spawn(function()
		for _ = 1, 20 do
			local b = ContextActionService:GetButton(action)
			if b then
				b.Size = UDim2.fromOffset(80, 80)
				b.ImageTransparency = 0.5
				local title = b:FindFirstChild("ActionTitle")
				if title and title:IsA("TextLabel") then
					title.TextSize = 20
					title.TextTransparency = 0.15
				end
				ContextActionService:SetPosition(action, pos)
				return
			end
			task.wait(0.25)
		end
	end)
end
ContextActionService:SetTitle("Pray", ui("PrayButton"))
localPlayer:GetAttributeChangedSignal("Lang"):Connect(function()
	pcall(function()
		ContextActionService:SetTitle("Pray", ui("PrayButton"))
	end)
end)
-- จัดรอบปุ่มกระโดด (มุมขวาล่าง): สวดอยู่เหนือปุ่มกระโดด / นั่งยองอยู่ซ้ายปุ่มกระโดด (Animate.client)
styleTouchButton("Pray", UDim2.new(1, -125, 1, -215))

-- เกิดใหม่: รีเซ็ตค่าดีเลย์ปุ่ม
localPlayer.CharacterAdded:Connect(function()
	lastToggle = 0
end)
