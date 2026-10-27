-- LobbyClient.client.luau
-- สคริปต์ฝั่ง Client ของ place "Lobby" — sync ผ่าน lobby.project.json พอร์ต 34873
-- บรรยากาศวัด: เสียงจิ้งหรีด/ลมหวิว, หลอดไฟ/เทียนกะพริบ (tag FlickerLamp), เงาคนใต้ต้นไทรจางหายเมื่อเดินเข้าใกล้ (tag Apparition)
-- หน้าที่ (ทำต่อ): UI ใน Lobby เช่น ปุ่มสลับภาษา TH/EN, เลือกจำนวนผู้เล่น/ความยากในโซนสร้างห้อง, สมุดสะสมผี

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- เสียงชุดเดียวกับ AmbienceController ของแมพเกม
local function loop(name: string, id: string, volume: number)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume
	s.Looped = true
	s.Parent = SoundService
	s:Play()
end
loop("LobbyCrickets", "rbxassetid://9112764023", 0.35)
loop("LobbyCricketsFar", "rbxassetid://9112764040", 0.2)
loop("LobbyEerieAir", "rbxassetid://9114244841", 0.25)

-- หลอดไฟ/เทียนกะพริบ: ปกติสว่างนิ่ง แล้วสะดุดวูบเป็นพักๆ (สุ่มจังหวะแยกกันทุกดวง)
local function flicker(part: Instance)
	local light = part:FindFirstChildOfClass("PointLight")
	if not light or not part:IsA("BasePart") then
		return
	end
	local base = light.Brightness
	task.spawn(function()
		local rng = Random.new()
		while part.Parent do
			task.wait(rng:NextNumber(2, 9))
			for _ = 1, rng:NextInteger(2, 5) do
				light.Brightness = base * rng:NextNumber(0.05, 0.4)
				part.Transparency = 0.6
				task.wait(rng:NextNumber(0.04, 0.12))
				light.Brightness = base
				part.Transparency = 0
				task.wait(rng:NextNumber(0.05, 0.2))
			end
		end
	end)
end
for _, p in ipairs(CollectionService:GetTagged("FlickerLamp")) do
	flicker(p)
end
CollectionService:GetInstanceAddedSignal("FlickerLamp"):Connect(flicker)

-- เงาคนใต้ต้นไทร: เห็นได้จากไกลๆ พอเดินเข้าใกล้ 45 studs จะจางหายไป ถอยออกเกิน 70 studs ค่อยกลับมายืนที่เดิม
local NEAR, FAR = 45, 70
local function haunt(ghost: Instance)
	if not ghost:IsA("Model") then
		return
	end
	local parts = {}
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[d] = d.Transparency
		end
	end
	local shown = true
	local function fade(visible: boolean)
		shown = visible
		for p, t in pairs(parts) do
			TweenService:Create(p, TweenInfo.new(if visible then 2.5 else 0.6), { Transparency = if visible then t else 1 }):Play()
		end
	end
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not ghost.Parent then
			conn:Disconnect()
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local d = (root.Position - ghost:GetPivot().Position).Magnitude
		if shown and d < NEAR then
			fade(false)
		elseif not shown and d > FAR then
			fade(true)
		end
	end)
end
for _, g in ipairs(CollectionService:GetTagged("Apparition")) do
	haunt(g)
end
CollectionService:GetInstanceAddedSignal("Apparition"):Connect(haunt)

print("✅ [Lobby] Client พร้อม: " .. player.Name)
