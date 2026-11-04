--!nonstrict
-- HauntEffects.client.luau
-- อาการหลอนบนจอของผู้เล่นคนนี้ (2026-11-03)
--   * ได้ยินเสียงกระซิบ (CustomerSpeech ที่ผู้พูดเป็น "WhisperSpeaker": สวดเรียกผี / ศาลไม่คุ้มครอง)
--     -> ตาปรือจะหลับ แบบเรื่องเล่า "ธี่หยด": หนังตาบน/ล่างค่อยๆ ปิด-ลืม หนักขึ้นทีละรอบ ภาพเบลอ มืดลง หัวสัปหงก
--   * Remotes.Curse (ศาลพระภูมิไม่ได้รับของถวาย): "drowsy" ตาจะหลับ / "shake" จอเขย่า / "slow" เดินช้า ตัวหนัก / "stumble" สะดุดล้ม
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ---------------------------------------------------------------- หนังตา (กรอบดำบน/ล่าง ขอบนุ่ม)
local gui = Instance.new("ScreenGui")
gui.Name = "HauntEffects"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 40 -- เหนือ HUD ใต้ jumpscare / จอตาย
gui.Parent = player:WaitForChild("PlayerGui")

-- หนังตาเป็นวงรีกว้างกว่าจอ (ขอบเป็นแนวโค้งแบบเปลือกตา ไม่ใช่แถบดำตรงแบบจอหนัง)
-- สีดำโปร่งๆ ขอบจางยาว (เบลอ) — ผู้ใช้ 2026-11-04: ไม่เอาสีแดงทึบ
local LID_ALPHA = 0.18 -- หนังตาโปร่งนิดๆ ยังเห็นภาพลางๆ
local function lid(top: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = if top then "LidTop" else "LidBottom"
	f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	f.BackgroundTransparency = LID_ALPHA
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, if top then 1 else 0)
	f.Position = UDim2.fromScale(0.5, if top then 0 else 1)
	f.Size = UDim2.new(1.8, 0, 0.62, 0)
	f.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	-- ขอบหนังตาจาง (ไม่ใช่เส้นตรงแข็ง) + โค้งนิดๆ
	local g = Instance.new("UIGradient")
	g.Rotation = if top then 90 else 270
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.05),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	-- ด้านหลังวงรี (ฝั่งขอบจอ) โค้งกลับเข้ามา: ตอนหนังตาลงมาลึกจะเห็นช่องโหว่ที่มุมบน/ล่างของจอ
	-- -> แผ่นทึบเต็มความกว้างวงรี ตั้งแต่กลางวงรีออกไปเลยขอบจอ (ขอบหนังตาด้านในยังโค้งเหมือนเดิม)
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = f.BackgroundColor3
	back.BackgroundTransparency = LID_ALPHA
	back.BorderSizePixel = 0
	back.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	back.Position = UDim2.fromScale(0, 0.5)
	back.Size = UDim2.fromScale(1, 2.5)
	back.Parent = f
	return f
end
local lidTop = lid(true)
local lidBottom = lid(false)

local blur = Instance.new("BlurEffect")
blur.Name = "DrowsyBlur"
blur.Size = 0
blur.Parent = Lighting
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "DrowsyGrade"
grade.Parent = Lighting

-- เปิดตา = 0, ปิดสนิท = 1 (หนังตาบน/ล่างมาเจอกันกลางจอ)
-- อาการหลอน (ตาจะหลับ ฯลฯ) หรี่ได้สุดแค่ LID_MAX (ผู้ใช้เลือกระดับนี้ 2026-11-03: ยังเห็นทางพอเล่นต่อได้)
-- force = ปิดได้สนิท (ใช้ตอนตาย: client/DeathScreen ผ่าน _G.HauntLids)
local LID_MAX = 0.62
local function setLids(closed: number, time: number, style: Enum.EasingStyle?, force: boolean?)
	if not force then
		closed = math.min(closed, LID_MAX)
	end
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	-- หนังตาสูง 0.62 ของจอ (ขอบจาง 30%): ปิดสนิทเลื่อนมาถึง 0.75 ส่วนทึบทับกันกลางจอพอดี
	TweenService:Create(lidTop, info, { Position = UDim2.fromScale(0.5, closed * 0.75) }):Play()
	TweenService:Create(lidBottom, info, { Position = UDim2.fromScale(0.5, 1 - closed * 0.75) }):Play()
end

-- ---------------------------------------------------------------- กล้อง: สัปหงก / เขย่า (ซ้อนหลังกล้องปกติทุกเฟรม)
local nod = 0 -- องศาก้มหัว
local roll = 0
local shakeUntil = 0
local shakeAmp = 0
RunService:BindToRenderStep("HauntCameraOffset", Enum.RenderPriority.Camera.Value + 2, function()
	local cam = Workspace.CurrentCamera
	if not cam or cam.CameraType == Enum.CameraType.Scriptable then
		return
	end
	local off = CFrame.Angles(math.rad(-nod), 0, math.rad(roll))
	local now = os.clock()
	if now < shakeUntil then
		local k = math.clamp((shakeUntil - now) / 0.6, 0, 1) * shakeAmp
		off = off * CFrame.Angles(math.rad((math.noise(now * 18, 1) * 2) * k), math.rad((math.noise(now * 18, 7) * 2) * k), math.rad(math.noise(now * 12, 13) * 1.5 * k))
	end
	if off ~= CFrame.identity then
		cam.CFrame = cam.CFrame * off
	end
end)

local nodValue = Instance.new("NumberValue")
nodValue.Changed:Connect(function(v)
	nod = v
end)
local rollValue = Instance.new("NumberValue")
rollValue.Changed:Connect(function(v)
	roll = v
end)

-- ---------------------------------------------------------------- ตาจะหลับ (ธี่หยด)
local drowsyToken = 0
local function drowsy(seconds: number)
	drowsyToken += 1
	local token = drowsyToken
	local function live(): boolean
		return drowsyToken == token
	end
	task.spawn(function()
		TweenService:Create(blur, TweenInfo.new(1.2), { Size = 10 }):Play()
		TweenService:Create(grade, TweenInfo.new(1.2), { Brightness = -0.12, Saturation = -0.45, Contrast = 0.1 }):Play()
		-- กะพริบปรือ 2 ครั้ง แล้วสุ่ม: ลืมตาหยุดแค่นั้น / หลับ (ปิดค้างครู่หนึ่ง) แล้วสะดุ้งตื่น
		-- (ผู้ใช้ 2026-11-04: กะพริบแค่ 2 ครั้ง เดิม 3 ครั้งหนักขึ้นเรื่อยๆ)
		-- (ไม่บังคับกล้องก้มลง/เอียง: ผู้ใช้ให้เอาออก 2026-11-03 — อาการอยู่ที่หนังตา เบลอ มืดลงเท่านั้น)
		local beats = { { 0.4, 1.3 }, { 0.5, 1.4 } }
		local per = math.max(2.0, (seconds - 1) / (#beats + 1))
		for _, b in ipairs(beats) do
			if not live() then
				return
			end
			setLids(b[1], b[2])
			task.wait(b[2] + 0.25)
			if not live() then
				return
			end
			-- พยายามลืมตา (ไม่สุด)
			local back = math.max(0.3, per - b[2] - 0.25)
			setLids(b[1] * 0.45, back)
			task.wait(back)
		end
		if not live() then
			return
		end
		if math.random() < 0.5 then
			-- หลับ: หนังตาปิดลงช้าๆ ค้างไว้ครู่หนึ่ง
			setLids(LID_MAX, 1.6)
			task.wait(1.6 + math.max(0.8, per - 1.6))
			if not live() then
				return
			end
		end
		-- สะดุ้งตื่น / ลืมตา
		setLids(0, 0.18, Enum.EasingStyle.Quad)
		shakeUntil, shakeAmp = os.clock() + 0.35, 1.2
		TweenService:Create(blur, TweenInfo.new(1.5), { Size = 0 }):Play()
		TweenService:Create(grade, TweenInfo.new(1.5), { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
	end)
end

-- เสียงกระซิบ + ตาปรือ (นิยามด้านล่าง ใช้ใน Remotes.Curse ด้วย)
local whisperFn: (() -> ())? = nil

local function shake(seconds: number, amp: number?)
	shakeUntil = os.clock() + seconds
	shakeAmp = amp or 2.2
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 6 }):Play()
	task.delay(seconds, function()
		if os.clock() >= shakeUntil - 0.05 then
			TweenService:Create(blur, TweenInfo.new(0.8), { Size = 0 }):Play()
		end
	end)
end

local function heavy(seconds: number)
	setLids(0.22, 1.2)
	TweenService:Create(grade, TweenInfo.new(1), { Saturation = -0.6, Brightness = -0.05 }):Play()
	task.delay(seconds, function()
		setLids(0, 1.5)
		TweenService:Create(grade, TweenInfo.new(1.5), { Saturation = 0, Brightness = 0 }):Play()
	end)
end

local function stumble(seconds: number)
	-- สะดุด: กล้องวูบลง ภาพมืดแวบ เขย่า
	shake(0.6, 4)
	setLids(0.85, 0.15, Enum.EasingStyle.Quad)
	task.delay(0.4, function()
		setLids(0, 0.6)
	end)
	TweenService:Create(grade, TweenInfo.new(0.2), { Brightness = -0.3 }):Play()
	task.delay(seconds, function()
		TweenService:Create(grade, TweenInfo.new(1), { Brightness = 0 }):Play()
	end)
end

local curseRemote = remotes:WaitForChild("Curse") :: RemoteEvent
curseRemote.OnClientEvent:Connect(function(symptom: string, seconds: number?)
	local s = seconds or 4
	if symptom == "drowsy" then
		if whisperFn then
			whisperFn()
		else
			drowsy(s)
		end
	elseif symptom == "shake" then
		shake(s)
	elseif symptom == "slow" then
		heavy(s)
	elseif symptom == "stumble" then
		stumble(s)
	end
end)

-- เสียงกระซิบธี่หยด (เจ้าของเกมอัปโหลด ~28 วิ) ข้างหูคนเดียว เล่นแค่ WHISPER_LEN วิ เบา 10% ระหว่างนั้นตาปรือจะหลับ
--   ดังเมื่อ: ศาลไม่คุ้มครอง (อาการ drowsy) / สวดเรียกผี (บทพูด WhisperSpeaker) / สุ่มเองนานๆ ครั้งตอนร้านเปิด
--   (ผู้ใช้ 2026-11-04: เอากลับมา หลังเอาออกจากเสียงสุ่มรอบทุ่งเมื่อ 2026-11-03)
local WHISPER_ID = "rbxassetid://116827997071173"
local WHISPER_VOLUME = 0.1
local WHISPER_LEN = 15
local WHISPER_EVERY = { 240, 480 }
local whisperUntil = 0
local function whisper()
	if os.clock() < whisperUntil or Lighting:GetAttribute("Cutscene") == true then
		return
	end
	whisperUntil = os.clock() + WHISPER_LEN + 1
	local s = Instance.new("Sound")
	s.Name = "HauntWhisper"
	s.SoundId = WHISPER_ID
	s.Volume = 0
	s.Parent = game:GetService("SoundService")
	s:Play()
	TweenService:Create(s, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Volume = WHISPER_VOLUME }):Play()
	drowsy(WHISPER_LEN)
	task.delay(WHISPER_LEN - 1, function()
		TweenService:Create(s, TweenInfo.new(1, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
	end)
	task.delay(WHISPER_LEN + 0.1, function()
		s:Destroy()
	end)
end

whisperFn = whisper

local speechRemote = remotes:WaitForChild("CustomerSpeech") :: RemoteEvent
speechRemote.OnClientEvent:Connect(function(key: string?, _head: any, who: any)
	if key and type(who) == "table" and who.ghost == "WhisperSpeaker" then
		whisper()
	end
end)

task.spawn(function()
	while true do
		task.wait(WHISPER_EVERY[1] + math.random() * (WHISPER_EVERY[2] - WHISPER_EVERY[1]))
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if remotes:GetAttribute("ShopOpen") == true and hum and hum.Health > 0 then
			whisper()
		end
	end
end)

-- ตาย / เกิดใหม่ / คัทซีน: ล้างอาการ
local function clear()
	drowsyToken += 1
	setLids(0, 0.3)
	nodValue.Value, rollValue.Value = 0, 0
	shakeUntil = 0
	blur.Size = 0
	grade.Brightness, grade.Saturation, grade.Contrast = 0, 0, 0
end
player.CharacterAdded:Connect(clear)
_G.ClearHauntEffects = clear
-- client/DeathScreen: ตาริบหรี่แล้วปิดสนิทตอนตาย (closed 0..1, วินาที)
_G.HauntLids = function(closed: number, time: number)
	drowsyToken += 1 -- หยุดอาการตาจะหลับที่ค้างอยู่
	setLids(closed, time, Enum.EasingStyle.Sine, true)
end
