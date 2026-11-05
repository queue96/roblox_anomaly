-- LobbyLeaderboards.server.luau
-- อัปเดตป้ายอันดับวัดจาก OrderedDataStore ทุก 2 นาที
-- และตั้ง attribute บน Player ให้ป้ายชื่อเหนือหัว (LobbyNameplates.server) ใช้:
--   Completions = จำนวนรอบที่เล่นจบ, CompletionsRank = อันดับบนป้าย "จบเกมมากที่สุด" (nil = ไม่ติดอันดับ)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardStats"))

local BOARDS = {
	{ model = "LeaderboardDonations", category = "donations", title = "ผู้ร่วมทำบุญสูงสุด", suffix = "฿", color = Color3.fromRGB(232, 190, 92) },
	{ model = "LeaderboardCompletions", category = "completions", title = "จบเกมมากที่สุด", suffix = "ครั้ง", color = Color3.fromRGB(126, 190, 152) },
	{ model = "LeaderboardAnomalies", category = "anomalies", title = "สะสมสิ่งผิดปกติมากที่สุด", suffix = "ชนิด", color = Color3.fromRGB(190, 122, 164) },
}

local names: { [number]: string } = {}
local lastCompletionRanks: { [number]: { rank: number, value: number } } = {}

-- จำนวนรอบที่จบของคนที่เพิ่งเข้ามา (อันดับใช้ผลรอบล่าสุดของป้าย)
local function loadCompletions(p: Player)
	local r = lastCompletionRanks[p.UserId]
	if r then
		p:SetAttribute("CompletionsRank", r.rank)
	end
	local value = LeaderboardStats.GetValue("completions", p.UserId)
	if value and p.Parent then
		p:SetAttribute("Completions", value)
	end
end
Players.PlayerAdded:Connect(loadCompletions)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(loadCompletions, p)
end

local function displayName(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then name else "ผู้เล่น " .. tostring(userId)
	return names[userId]
end

-- ป้ายแบบตาราง: หัวป้าย + แถวละ 1 คน (อันดับ · รูปหัว · ชื่อชิดซ้าย · สถิติชิดขวา) มีเส้นคั่นแถว ไม่มีเส้นคั่นคอลัมน์
--   ข้อความอยู่ด้าน Back ของแผ่นป้าย (หันเข้าลานวัด ดู MapBuilder.BuildTempleLobby มุมป้าย)
local INK = Color3.fromRGB(17, 13, 11)
local CREAM = Color3.fromRGB(238, 229, 204)
local DIM = Color3.fromRGB(165, 156, 136)
local LINE = Color3.fromRGB(90, 80, 64)
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local function boardCanvas(model: Model): Frame?
	local face = model:FindFirstChild("DonationBoard_Face", true)
	if not face or not face:IsA("BasePart") then
		return nil
	end
	for _, old in ipairs(face:GetChildren()) do
		if old.Name == "TempleLeaderboard" or old.Name == "TempleText" then
			old:Destroy()
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "TempleLeaderboard"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 34
	gui.LightInfluence = 0.25
	gui.Parent = face
	local root = Instance.new("Frame")
	root.Name = "Board"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = INK
	root.BackgroundTransparency = 0.12
	root.BorderSizePixel = 0
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 26)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.PaddingLeft = UDim.new(0, 30)
	pad.PaddingRight = UDim.new(0, 30)
	pad.Parent = root
	return root
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextColor3 = CREAM
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.6
	l.TextTruncate = Enum.TextTruncate.AtEnd
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local TITLE_H = 86
local ROWS = 5

local function drawBoard(root: Frame, spec: { [string]: any }, rows: { { userId: number, value: number } })
	text(root, {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_H - 16),
		Text = spec.title,
		TextColor3 = spec.color,
		TextSize = 54,
	})
	-- เส้นใต้หัวป้าย (สีของป้าย)
	local head = Instance.new("Frame")
	head.Position = UDim2.new(0, 0, 0, TITLE_H - 8)
	head.Size = UDim2.new(1, 0, 0, 3)
	head.BackgroundColor3 = spec.color
	head.BackgroundTransparency = 0.3
	head.BorderSizePixel = 0
	head.Parent = root

	local body = Instance.new("Frame")
	body.Name = "Rows"
	body.Position = UDim2.new(0, 0, 0, TITLE_H)
	body.Size = UDim2.new(1, 0, 1, -TITLE_H)
	body.BackgroundTransparency = 1
	body.Parent = root
	if #rows == 0 then
		text(body, { Size = UDim2.new(1, 0, 0.5, 0), Position = UDim2.fromScale(0, 0.2), Text = "ยังไม่มีข้อมูล\nNO RECORDS YET", TextColor3 = DIM, TextSize = 34 })
		return
	end
	local rowH = 1 / ROWS
	for rank, row in ipairs(rows) do
		local r = Instance.new("Frame")
		r.Name = "Row" .. rank
		r.Position = UDim2.fromScale(0, (rank - 1) * rowH)
		r.Size = UDim2.fromScale(1, rowH)
		r.BackgroundTransparency = 1
		r.Parent = body
		-- อันดับ
		text(r, {
			Size = UDim2.new(0, 50, 1, 0),
			Text = tostring(rank),
			TextSize = 44,
			TextColor3 = if rank == 1 then spec.color else DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- รูปหัวผู้เล่น (Roblox headshot)
		local pic = Instance.new("ImageLabel")
		pic.AnchorPoint = Vector2.new(0, 0.5)
		pic.Position = UDim2.new(0, 56, 0.5, 0)
		pic.Size = UDim2.new(0.72, 0, 0.72, 0)
		pic.SizeConstraint = Enum.SizeConstraint.RelativeYY
		pic.BackgroundColor3 = Color3.fromRGB(40, 34, 28)
		pic.BorderSizePixel = 0
		pic.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(row.userId)
		pic.Parent = r
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = pic
		-- ชื่อชิดซ้าย
		text(r, {
			Position = UDim2.new(0, 146, 0, 0),
			Size = UDim2.new(0.64, -146, 1, 0),
			Text = displayName(row.userId),
			TextSize = 44,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- สถิติชิดขวา
		text(r, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.36, 0, 1, 0),
			Text = ("%d %s"):format(row.value, spec.suffix),
			TextSize = 42,
			TextColor3 = spec.color,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		-- เส้นคั่นแถว (ไม่ใส่ใต้แถวสุดท้าย)
		if rank < #rows then
			local line = Instance.new("Frame")
			line.AnchorPoint = Vector2.new(0, 1)
			line.Position = UDim2.fromScale(0, 1)
			line.Size = UDim2.new(1, 0, 0, 2)
			line.BackgroundColor3 = LINE
			line.BackgroundTransparency = 0.25
			line.BorderSizePixel = 0
			line.Parent = r
		end
	end
end

local function refreshBoard(spec: { [string]: any })
	local lobby = workspace:FindFirstChild("TempleLobby")
	local model = lobby and lobby:FindFirstChild(spec.model, true)
	if not model or not model:IsA("Model") then
		return
	end
	local rows = LeaderboardStats.GetTop(spec.category, ROWS)
	if spec.category == "completions" then
		local rankOf = {}
		for rank, row in ipairs(rows) do
			rankOf[row.userId] = { rank = rank, value = row.value }
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local r = rankOf[p.UserId]
			p:SetAttribute("CompletionsRank", if r then r.rank else nil)
			if r then
				p:SetAttribute("Completions", r.value)
			end
		end
		lastCompletionRanks = rankOf
	end
	-- ชื่อผู้เล่นอ่านจากเว็บ (ช้า): เตรียมก่อนลบป้ายเก่า ป้ายจะไม่ว่างระหว่างรอ
	for _, row in ipairs(rows) do
		displayName(row.userId)
	end
	local root = boardCanvas(model)
	if root then
		drawBoard(root, spec, rows)
	end
end

task.spawn(function()
	-- ป้ายถูกสร้างใน Edit mode โดย DevCommand; รอไว้เผื่อเซิร์ฟเวอร์เริ่มก่อนฉากพร้อม
	for _ = 1, 30 do
		if workspace:FindFirstChild("TempleLobby") then
			break
		end
		task.wait(1)
	end
	while true do
		for _, spec in ipairs(BOARDS) do
			refreshBoard(spec)
		end
		task.wait(120)
	end
end)
