-- LobbyNameplates.server.luau
-- ป้ายชื่อเหนือหัวผู้เล่นใน Lobby (ทุกคนเห็นตรงกัน)
--   แถวบน (เล็ก): 🏆 จำนวนรอบที่เล่นจบ · TOP n ถ้าติดป้าย "จบเกมมากที่สุด"
--   แถวล่าง: DisplayName
--   แถวบนสุด (มีสมุดหมอผี Game Pass): "📖 หมอผี" สีทอง (attribute GhostBook จาก lobby/server/PassShop)
-- ข้อมูลมาจาก attribute Completions / CompletionsRank ที่ LobbyLeaderboards.server ตั้งไว้บน Player
-- ซ่อนป้ายชื่อเดิมของ Roblox (Humanoid.DisplayDistanceType = None)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any

-- ธีมเดียวกับ HUD
local CREAM = Color3.fromRGB(236, 228, 208)
local DIM = Color3.fromRGB(165, 156, 136)
local GOLD = Color3.fromRGB(232, 190, 92)
local INK = Color3.fromRGB(8, 7, 6)
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local function label(name: string, parent: Instance, y: number, h: number, color: Color3, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.new(0, 0, 0, y)
	t.Size = UDim2.new(1, 0, 0, h)
	t.FontFace = FONT
	t.TextColor3 = color
	t.TextSize = size
	t.TextStrokeColor3 = INK
	t.TextStrokeTransparency = 0.35
	t.Parent = parent
	return t
end

local function build(player: Player, char: Model)
	local head = char:WaitForChild("Head", 10) :: BasePart?
	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not (head and humanoid) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local old = char:FindFirstChild("LobbyNameplate")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LobbyNameplate"
	gui.Size = UDim2.fromOffset(200, 60)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = head

	local shaman = label("Shaman", gui, 0, 20, Color3.fromRGB(245, 200, 90), 16)
	shaman.TextStrokeColor3 = Color3.fromRGB(60, 10, 6)
	shaman.TextStrokeTransparency = 0.2
	do
		local e = LanguageModule.UI.ShamanTitle
		Bilingual.Text(shaman, "📖 " .. e.th, "📖 " .. e.en, { id = "📖 " .. e.id, pt = "📖 " .. e.pt, es = "📖 " .. e.es })
	end
	local stats = label("Stats", gui, 20, 16, DIM, 13)
	local name = label("Name", gui, 36, 22, CREAM, 18)
	name.Text = player.DisplayName

	local function update()
		local done = player:GetAttribute("Completions")
		local rank = player:GetAttribute("CompletionsRank")
		local parts = {}
		if type(done) == "number" then
			table.insert(parts, "🏆 " .. tostring(done))
		end
		if type(rank) == "number" then
			table.insert(parts, "TOP " .. tostring(rank))
		end
		stats.Text = table.concat(parts, "  ·  ")
		stats.Visible = #parts > 0
		-- ติดอันดับ: แถวบนเป็นสีทอง
		stats.TextColor3 = if type(rank) == "number" then GOLD else DIM
		shaman.Visible = player:GetAttribute("GhostBook") == true
	end
	update()
	local c1 = player:GetAttributeChangedSignal("Completions"):Connect(update)
	local c2 = player:GetAttributeChangedSignal("CompletionsRank"):Connect(update)
	local c4 = player:GetAttributeChangedSignal("GhostBook"):Connect(update)
	gui.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
		c4:Disconnect()
	end)
	-- อยู่ใต้ตัว Model ไม่ใช่ใต้ Head: ตอนรูปลักษณ์อวตารโหลดเสร็จ Roblox เปลี่ยน Head ใหม่ (ป้ายบน Head เก่าหายไปด้วย)
	local c3 = char.ChildAdded:Connect(function(c)
		if c.Name == "Head" and c:IsA("BasePart") then
			gui.Adornee = c
		end
	end)
	gui.Destroying:Connect(function()
		c3:Disconnect()
	end)
	gui.Parent = char
end

local function hook(player: Player)
	player.CharacterAdded:Connect(function(char)
		build(player, char)
	end)
	if player.Character then
		task.spawn(build, player, player.Character)
	end
end
Players.PlayerAdded:Connect(hook)
for _, p in ipairs(Players:GetPlayers()) do
	hook(p)
end
