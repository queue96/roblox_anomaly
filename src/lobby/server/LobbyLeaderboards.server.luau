-- LobbyLeaderboards.server.luau
-- อัปเดตป้ายอันดับวัดจาก OrderedDataStore ทุก 2 นาที

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardStats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LeaderboardStats"))

local BOARDS = {
	{ model = "LeaderboardDonations", category = "donations", title = "ผู้ร่วมทำบุญสูงสุด", suffix = "฿", color = Color3.fromRGB(232, 190, 92) },
	{ model = "LeaderboardCompletions", category = "completions", title = "จบเกมมากที่สุด", suffix = "ครั้ง", color = Color3.fromRGB(126, 190, 152) },
	{ model = "LeaderboardAnomalies", category = "anomalies", title = "สะสมสิ่งผิดปกติมากที่สุด", suffix = "ชนิด", color = Color3.fromRGB(190, 122, 164) },
}

local names: { [number]: string } = {}

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

local function boardLabel(model: Model): TextLabel?
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
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(17, 13, 11)
	label.BackgroundTransparency = 0.18
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(238, 229, 204)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	label.Font = Enum.Font.SpecialElite
	label.TextSize = 25
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = label
	return label
end

local function refreshBoard(spec: { [string]: any })
	local lobby = workspace:FindFirstChild("TempleLobby")
	local model = lobby and lobby:FindFirstChild(spec.model, true)
	if not model or not model:IsA("Model") then
		return
	end
	local label = boardLabel(model)
	if not label then
		return
	end
	local rows = LeaderboardStats.GetTop(spec.category, 5)
	local lines = { spec.title, "────────────" }
	if #rows == 0 then
		table.insert(lines, "ยังไม่มีข้อมูล")
		table.insert(lines, "NO RECORDS YET")
	else
		for rank, row in ipairs(rows) do
			table.insert(lines, ("%d. %s  %d %s"):format(rank, displayName(row.userId), row.value, spec.suffix))
		end
	end
	label.TextColor3 = spec.color
	label.Text = table.concat(lines, "\n")
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
