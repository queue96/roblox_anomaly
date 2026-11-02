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

local function lid(top: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = if top then "LidTop" else "LidBottom"
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, if top then 1 else 0)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.Size = UDim2.new(1, 0, 0.62, 0)
	f.Parent = gui
	-- ขอบหนังตาจาง (ไม่ใช่เส้นตรงแข็ง) + โค้งนิดๆ
	local g = Instance.new("UIGradient")
	g.Rotation = if top then 90 else 270
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
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
local function setLids(closed: number, time: number, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	-- หนังตาสูง 0.62 ของจอ (ขอบจาง 30%): ปิดสนิทเลื่อนมาถึง 0.75 ส่วนทึบทับกันกลางจอพอดี
	TweenService:Create(lidTop, info, { Position = UDim2.fromScale(0, closed * 0.75) }):Play()
	TweenService:Create(lidBottom, info, { Position = UDim2.fromScale(0, 1 - closed * 0.75) }):Play()
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
		-- ปรือหนักขึ้นทีละรอบ: ครึ่งตา -> เกือบปิด -> ปิดสนิท (หัวตก) แล้วสะดุ้งลืมตา
		local beats = { { 0.45, 0.9, 6 }, { 0.72, 1.0, 11 }, { 1.0, 1.1, 18 } }
		local per = math.max(1.2, (seconds - 1) / #beats)
		for _, b in ipairs(beats) do
			if not live() then
				return
			end
			setLids(b[1], b[2])
			TweenService:Create(nodValue, TweenInfo.new(b[2], Enum.EasingStyle.Sine), { Value = b[3] }):Play()
			TweenService:Create(rollValue, TweenInfo.new(b[2], Enum.EasingStyle.Sine), { Value = (math.random() - 0.5) * 6 }):Play()
			task.wait(b[2] + 0.25)
			if not live() then
				return
			end
			-- พยายามลืมตา (ไม่สุด)
			setLids(b[1] * 0.35, per - b[2] - 0.25)
			TweenService:Create(nodValue, TweenInfo.new(per - b[2] - 0.25, Enum.EasingStyle.Sine), { Value = b[3] * 0.4 }):Play()
			task.wait(math.max(0.3, per - b[2] - 0.25))
		end
		if not live() then
			return
		end
		-- สะดุ้งตื่น
		setLids(0, 0.18, Enum.EasingStyle.Quad)
		TweenService:Create(nodValue, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Value = 0 }):Play()
		TweenService:Create(rollValue, TweenInfo.new(0.25), { Value = 0 }):Play()
		shakeUntil, shakeAmp = os.clock() + 0.35, 1.2
		TweenService:Create(blur, TweenInfo.new(1.5), { Size = 0 }):Play()
		TweenService:Create(grade, TweenInfo.new(1.5), { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
	end)
end

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
	TweenService:Create(nodValue, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Value = 5 }):Play()
	task.delay(seconds, function()
		setLids(0, 1.5)
		TweenService:Create(grade, TweenInfo.new(1.5), { Saturation = 0, Brightness = 0 }):Play()
		TweenService:Create(nodValue, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Value = 0 }):Play()
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
		drowsy(s)
	elseif symptom == "shake" then
		shake(s)
	elseif symptom == "slow" then
		heavy(s)
	elseif symptom == "stumble" then
		stumble(s)
	end
end)

-- เสียงกระซิบไม่รู้ที่มา = ตาปรือจะหลับ
local speechRemote = remotes:WaitForChild("CustomerSpeech") :: RemoteEvent
speechRemote.OnClientEvent:Connect(function(key: string?, _head: any, who: any)
	if key and type(who) == "table" and who.ghost == "WhisperSpeaker" then
		drowsy(5)
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
