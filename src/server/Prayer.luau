-- Prayer.luau (ModuleScript ฝั่ง Server)
-- ระบบพนมมือ (เพิ่มเมื่อ 2026-10-28)
--   Client กดค้าง G / ปุ่ม 🙏 บนมือถือ -> Remotes.Pray:FireServer(true/false)
--   Server: ตั้ง player:SetAttribute("Praying", true) + ท่าพนมมือ (หมุน C0 ของไหล่/ศอก/คอ ตัวละคร R15 ทุกคนเห็น) + ยืนนิ่ง
--   Client ของคนที่พนมมือ (PrayerController) อ่าน attribute นี้แล้วเปิด "ตาทิพย์" เห็นของที่ติด tag GhostOnly
--   CoreLoop ใช้ Prayer.PrayingNear() ให้ลูกค้าทักคนที่พนมมือ และ Prayer.Praying() สุ่มผีโผล่ตอนสวดตอนร้านว่าง

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Prayer = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local PrayRemote = remotes:FindFirstChild("Pray") or Instance.new("RemoteEvent")
PrayRemote.Name = "Pray"
PrayRemote.Parent = remotes

local POSE_TIME = 0.35
local TOGGLE_COOLDOWN = 0.2 -- กันกดรัวๆ

type Session = { started: number, origC0: { [Motor6D]: CFrame } }
local sessions: { [Player]: Session } = {}
local lastToggle: { [Player]: number } = {}

-- ---------------------------------------------------------------- ท่าพนมมือ (R15)
-- หมุนชิ้นส่วนให้แกน -Y (ทิศจากข้อต่อไปปลายแขน) ชี้ไปทาง dir (พิกัดของ UpperTorso)
local function aim(dir: Vector3): CFrame
	local y = -dir.Unit
	local x = (Vector3.xAxis - y * y:Dot(Vector3.xAxis)).Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- side = 1 แขนขวา, -1 แขนซ้าย: ต้นแขนชี้ลง-ไปหน้า ศอกพับ ปลายแขนชี้ขึ้นมาประกบกันกลางอก
local function armPose(side: number): (CFrame, CFrame)
	local upper = aim(Vector3.new(-0.25 * side, -0.75, -0.6))
	local lower = aim(Vector3.new(-0.55 * side, 0.75, -0.35))
	return upper, upper:Inverse() * lower
end

local function motor(char: Model, part: string, name: string): Motor6D?
	local p = char:FindFirstChild(part)
	local m = p and p:FindFirstChild(name)
	return if m and m:IsA("Motor6D") then m else nil
end

-- ท่ายืนเดิมของข้อต่อ (จำครั้งแรกไว้ใน attribute กันค่าเพี้ยนตอนกดพนมมือรัวๆ ระหว่าง Tween)
local function restC0(m: Motor6D): CFrame
	local c = m:GetAttribute("RestC0")
	if typeof(c) ~= "CFrame" then
		c = m.C0
		m:SetAttribute("RestC0", c)
	end
	return c :: CFrame
end

local function tweenC0(m: Motor6D, c0: CFrame)
	TweenService:Create(m, TweenInfo.new(POSE_TIME, Enum.EasingStyle.Sine), { C0 = c0 }):Play()
end

local function applyPose(char: Model, s: Session)
	for _, side in ipairs({ 1, -1 }) do
		local prefix = if side == 1 then "Right" else "Left"
		local shoulder = motor(char, prefix .. "UpperArm", prefix .. "Shoulder")
		local elbow = motor(char, prefix .. "LowerArm", prefix .. "Elbow")
		if shoulder and elbow then
			local upperRot, elbowRot = armPose(side)
			s.origC0[shoulder] = restC0(shoulder)
			s.origC0[elbow] = restC0(elbow)
			tweenC0(shoulder, CFrame.new(restC0(shoulder).Position) * upperRot * shoulder.C1.Rotation)
			tweenC0(elbow, CFrame.new(restC0(elbow).Position) * elbowRot * elbow.C1.Rotation)
		end
	end
	-- ก้มหน้าเล็กน้อย
	local neck = motor(char, "Head", "Neck")
	if neck then
		s.origC0[neck] = restC0(neck)
		tweenC0(neck, restC0(neck) * CFrame.Angles(math.rad(-18), 0, 0))
	end
end

local function clearPose(s: Session)
	for m, c0 in pairs(s.origC0) do
		if m.Parent then
			tweenC0(m, c0)
		end
	end
end

-- ---------------------------------------------------------------- เริ่ม / หยุด
function Prayer.Start(player: Player): boolean
	if sessions[player] then
		return true
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and hum and root) or hum.Health <= 0 or root.Anchored then
		return false -- ล้มนอนอยู่ / ตายแล้ว พนมมือไม่ได้
	end
	local s: Session = { started = os.clock(), origC0 = {} }
	sessions[player] = s
	hum:UnequipTools() -- เก็บไฟฉายก่อน (มือต้องว่าง)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	applyPose(char, s)
	player:SetAttribute("Praying", true)
	return true
end

function Prayer.Stop(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	player:SetAttribute("Praying", false)
	clearPose(s)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- ถ้าโดนผีหลอกล้มอยู่ (root ยึดไว้) ไม่คืนความเร็วเดิน ให้ระบบล้มคืนเอง
	if hum and root and not root.Anchored and hum.Health > 0 then
		hum.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		hum.JumpPower = StarterPlayer.CharacterJumpPower
		hum.JumpHeight = StarterPlayer.CharacterJumpHeight
	end
end

-- พนมมือมานานเท่าไหร่ (วินาที) / nil = ไม่ได้พนมมือ
function Prayer.Duration(player: Player): number?
	local s = sessions[player]
	return if s then os.clock() - s.started else nil
end

-- เวลาเริ่มพนมมือรอบนี้ (ใช้แยกว่าเป็นการสวดครั้งใหม่หรือครั้งเดิม)
function Prayer.StartedAt(player: Player): number?
	local s = sessions[player]
	return if s then s.started else nil
end

function Prayer.Praying(): { Player }
	local list = {}
	for p in pairs(sessions) do
		table.insert(list, p)
	end
	return list
end

-- ผู้เล่นที่พนมมืออยู่ในระยะ radius จากจุด pos
function Prayer.PrayingNear(pos: Vector3, radius: number): { Player }
	local list = {}
	for p in pairs(sessions) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - pos).Magnitude <= radius then
			table.insert(list, p)
		end
	end
	return list
end

PrayRemote.OnServerEvent:Connect(function(player, on: any)
	local now = os.clock()
	if lastToggle[player] and now - lastToggle[player] < TOGGLE_COOLDOWN and on == true then
		return
	end
	lastToggle[player] = now
	if on == true then
		Prayer.Start(player)
	else
		Prayer.Stop(player)
	end
end)

local function hookCharacter(player: Player, char: Model)
	-- เกิดใหม่ = ไม่ได้พนมมือแล้ว
	sessions[player] = nil
	player:SetAttribute("Praying", false)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			Prayer.Stop(player)
		end)
	end
end

local function hookPlayer(player: Player)
	player:SetAttribute("Praying", false)
	player.CharacterAdded:Connect(function(char)
		hookCharacter(player, char)
	end)
	if player.Character then
		task.spawn(hookCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	hookPlayer(p)
end
Players.PlayerRemoving:Connect(function(p)
	sessions[p] = nil
	lastToggle[p] = nil
end)

return Prayer
