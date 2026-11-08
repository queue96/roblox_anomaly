--!strict
-- AdminPanel.client.luau
-- แผง admin (กด F2 เปิด/ปิด) เห็นเฉพาะคนที่ server ติด attribute Admin = true ให้ (ดู server/AdminPanel.server.luau)
-- แบ่งเป็นแท็บ: ร้าน / ลูกค้า / อีเวนต์ / ผีฉาก / ผู้เล่น · ปุ่มเรียงตาราง 2 ช่อง · แถบสถานะด้านบน · ข้อความยืนยันหลังกด
-- โหมดทดสอบ (สวิตช์บนสุด): เกมไม่สุ่มอะไรเองเลย มีแต่ที่กดจากแผงนี้ (ReplicatedStorage attribute "TestMode")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ธีมเดียวกับ HUD (HUDController): หมึกดำ ครีม ขอบเทาน้ำตาล
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(18, 16, 14),
	Card = Color3.fromRGB(28, 25, 21),
	Button = Color3.fromRGB(36, 32, 27),
	ButtonHot = Color3.fromRGB(52, 46, 38),
	Line = Color3.fromRGB(70, 64, 54),
	LineHot = Color3.fromRGB(185, 140, 88),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(150, 141, 122),
	Ember = Color3.fromRGB(230, 120, 50),
	Good = Color3.fromRGB(110, 190, 110),
	Bad = Color3.fromRGB(205, 75, 60),
	Info = Color3.fromRGB(95, 150, 205),
}
local TITLE_FONT = Font.fromEnum(Enum.Font.SpecialElite)
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local FONT_BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

type Style = "normal" | "primary" | "danger"

local function corner(o: Instance, r: number)
	Instance.new("UICorner", o).CornerRadius = UDim.new(0, r)
end
local function stroke(o: Instance, color: Color3, t: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = t or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end
local function text(parent: Instance, s: string, size: number, color: Color3, font: Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = s
	l.TextSize = size
	l.TextColor3 = color
	l.FontFace = font or FONT
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin") :: RemoteEvent
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- กล้องล็อกมุมมองบุคคลที่หนึ่ง: ปุ่ม Modal ที่มองเห็นอยู่ทำให้ Roblox ปล่อยเมาส์ออกมากดแผงได้
	local modal = Instance.new("TextButton")
	modal.Modal = true
	modal.Size = UDim2.fromOffset(0, 0)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Parent = gui

	-- ---------------------------------------------------------------- กรอบแผง
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.new(0, 400, 0.86, 0)
	panel.BackgroundColor3 = C.Panel
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Parent = gui
	corner(panel, 8)
	stroke(panel, C.Line, 0.1)
	local sizeCap = Instance.new("UISizeConstraint", panel)
	sizeCap.MaxSize = Vector2.new(400, 720)
	sizeCap.MinSize = Vector2.new(320, 360)

	-- หัวแผง
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundTransparency = 1
	header.Parent = panel
	local title = text(header, "แผงทดสอบ  ·  ADMIN", 18, C.Ember, TITLE_FONT)
	title.Position = UDim2.fromOffset(14, 0)
	title.Size = UDim2.new(1, -90, 1, 0)
	local keyHint = text(header, "F2", 13, C.Dim, FONT_BOLD)
	keyHint.Position = UDim2.new(1, -78, 0, 0)
	keyHint.Size = UDim2.fromOffset(30, 40)
	keyHint.TextXAlignment = Enum.TextXAlignment.Right
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = C.Button
	close.Text = "✕"
	close.TextColor3 = C.Cream
	close.TextSize = 16
	close.FontFace = FONT_BOLD
	close.AutoButtonColor = false
	close.Parent = header
	corner(close, 6)
	stroke(close, C.Line)
	close.Activated:Connect(function()
		gui.Enabled = false
	end)

	-- ---------------------------------------------------------------- สวิตช์โหมดทดสอบ
	local testCard = Instance.new("TextButton")
	testCard.Name = "TestMode"
	testCard.AutoButtonColor = false
	testCard.Text = ""
	testCard.Position = UDim2.fromOffset(10, 42)
	testCard.Size = UDim2.new(1, -20, 0, 58)
	testCard.BackgroundColor3 = C.Card
	testCard.Parent = panel
	corner(testCard, 6)
	local testStroke = stroke(testCard, C.Line)
	local testTitle = text(testCard, "", 15, C.Cream, FONT_BOLD)
	testTitle.Position = UDim2.fromOffset(12, 6)
	testTitle.Size = UDim2.new(1, -84, 0, 20)
	local testDesc = text(testCard, "", 12, C.Dim)
	testDesc.Position = UDim2.fromOffset(12, 26)
	testDesc.Size = UDim2.new(1, -84, 0, 28)
	testDesc.TextYAlignment = Enum.TextYAlignment.Top
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -12, 0.5, 0)
	track.Size = UDim2.fromOffset(52, 26)
	track.BackgroundColor3 = C.Button
	track.Parent = testCard
	corner(track, 13)
	stroke(track, C.Line)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(20, 20)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
	knob.BackgroundColor3 = C.Cream
	knob.Parent = track
	corner(knob, 10)
	local function paintTest()
		local on = ReplicatedStorage:GetAttribute("TestMode") == true
		testTitle.Text = if on then "🧪 โหมดทดสอบ: เปิด" else "🧪 โหมดทดสอบ: ปิด"
		testTitle.TextColor3 = if on then C.Ember else C.Cream
		testDesc.Text = if on
			then "เกมไม่สุ่มอะไรเอง: ลูกค้า ขาจร ฝน ไฟดับ ผีใหญ่ ผีฉาก ศาลหลอก มีแต่ที่กดจากแผงนี้"
			else "เกมเล่นปกติ (สุ่มลูกค้า/อีเวนต์เอง) · กดเพื่อหยุดทุกอย่างไว้ทดสอบทีละอย่าง"
		testStroke.Color = if on then C.Ember else C.Line
		track.BackgroundColor3 = if on then C.Ember else C.Button
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = if on then UDim2.new(1, -23, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) }):Play()
	end
	paintTest()
	ReplicatedStorage:GetAttributeChangedSignal("TestMode"):Connect(paintTest)

	-- ---------------------------------------------------------------- แถบสถานะ
	local status = Instance.new("Frame")
	status.Position = UDim2.fromOffset(10, 106)
	status.Size = UDim2.new(1, -20, 0, 24)
	status.BackgroundTransparency = 1
	status.Parent = panel
	local sl = Instance.new("UIListLayout", status)
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	local function chip(): TextLabel
		local l = text(status, "", 12, C.Cream, FONT_BOLD)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromOffset(0, 24)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.BackgroundTransparency = 0
		l.BackgroundColor3 = C.Card
		l.TextWrapped = false
		local p = Instance.new("UIPadding", l)
		p.PaddingLeft, p.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		corner(l, 12)
		return l
	end
	local shopChip, powerChip, rainChip, moneyChip = chip(), chip(), chip(), chip()
	local function paintStatus()
		local shop = remotes:GetAttribute("ShopOpen") == true
		shopChip.Text = if shop then "ร้านเปิด" else "ร้านปิด"
		shopChip.TextColor3 = if shop then C.Good else C.Dim
		local power = ReplicatedStorage:GetAttribute("PowerOn") ~= false
		powerChip.Text = if power then "ไฟติด" else "ไฟดับ"
		powerChip.TextColor3 = if power then C.Good else C.Bad
		local rain = remotes:GetAttribute("Weather") == "Rain"
		rainChip.Text = if rain then "ฝนตก" else "ฟ้าใส"
		rainChip.TextColor3 = if rain then C.Info else C.Dim
		moneyChip.Text = string.format("฿%d · ธูป %d", tonumber(remotes:GetAttribute("Money")) or 0, tonumber(remotes:GetAttribute("Incense")) or 0)
	end
	paintStatus()
	for _, a in ipairs({ "ShopOpen", "Weather", "Money", "Incense" }) do
		remotes:GetAttributeChangedSignal(a):Connect(paintStatus)
	end
	ReplicatedStorage:GetAttributeChangedSignal("PowerOn"):Connect(paintStatus)

	-- ---------------------------------------------------------------- แท็บ
	local tabBar = Instance.new("Frame")
	tabBar.Position = UDim2.fromOffset(10, 136)
	tabBar.Size = UDim2.new(1, -20, 0, 30)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel
	local tl = Instance.new("UIListLayout", tabBar)
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 4)
	tl.SortOrder = Enum.SortOrder.LayoutOrder

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local TABS = { { "shop", "ร้าน" }, { "customer", "ลูกค้า" }, { "event", "อีเวนต์" }, { "scenery", "ผีฉาก" }, { "people", "ผู้เล่น" } }
	local function selectTab(id: string)
		for k, page in pairs(pages) do
			page.Visible = k == id
		end
		for k, b in pairs(tabButtons) do
			local on = k == id
			b.BackgroundColor3 = if on then C.LineHot else C.Button
			b.TextColor3 = if on then C.Ink else C.Cream
		end
	end
	for i, t in ipairs(TABS) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #TABS, -4, 1, 0)
		b.BackgroundColor3 = C.Button
		b.Text = t[2]
		b.TextColor3 = C.Cream
		b.TextSize = 14
		b.FontFace = FONT_BOLD
		b.AutoButtonColor = false
		b.Parent = tabBar
		corner(b, 6)
		tabButtons[t[1]] = b
		b.Activated:Connect(function()
			selectTab(t[1])
		end)

		local page = Instance.new("ScrollingFrame")
		page.Name = t[1]
		page.Position = UDim2.fromOffset(10, 172)
		page.Size = UDim2.new(1, -20, 1, -172 - 40)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.ScrollBarThickness = 4
		page.ScrollBarImageColor3 = C.Line
		page.AutomaticCanvasSize = Enum.AutomaticSize.Y
		page.CanvasSize = UDim2.new()
		page.Visible = false
		page.Parent = panel
		local pl = Instance.new("UIListLayout", page)
		pl.Padding = UDim.new(0, 10)
		pl.SortOrder = Enum.SortOrder.LayoutOrder
		local pp = Instance.new("UIPadding", page)
		pp.PaddingRight = UDim.new(0, 8)
		pp.PaddingBottom = UDim.new(0, 8)
		pages[t[1]] = page
	end

	-- ---------------------------------------------------------------- ข้อความยืนยัน (ล่างแผง)
	local toast = text(panel, "", 13, C.Dim)
	toast.AnchorPoint = Vector2.new(0, 1)
	toast.Position = UDim2.new(0, 14, 1, -8)
	toast.Size = UDim2.new(1, -28, 0, 24)
	toast.TextTruncate = Enum.TextTruncate.AtEnd
	toast.TextWrapped = false
	toast.Text = "เลือกแท็บด้านบน แล้วกดปุ่มเพื่อสั่งทันที"
	local toastToken = 0
	local function notify(s: string, color: Color3?)
		toastToken += 1
		local my = toastToken
		toast.Text = s
		toast.TextColor3 = color or C.Good
		toast.TextTransparency = 0
		task.delay(3, function()
			if my == toastToken then
				TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 0.5 }):Play()
			end
		end)
	end

	-- ---------------------------------------------------------------- ตัวช่วยสร้างหมวด + ปุ่ม
	local orderOf: { [Instance]: number } = {}
	local function nextOrder(parent: Instance): number
		orderOf[parent] = (orderOf[parent] or 0) + 1
		return orderOf[parent]
	end
	-- หมวดในแท็บ: หัวข้อ (+ คำอธิบายสั้น) แล้วตารางปุ่ม 2 ช่อง (cols = 1 สำหรับปุ่มยาว)
	local function section(tab: string, heading: string, hint: string?, cols: number?): Frame
		local page = pages[tab]
		local box = Instance.new("Frame")
		box.LayoutOrder = nextOrder(page)
		box.Size = UDim2.new(1, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundTransparency = 1
		box.Parent = page
		local bl = Instance.new("UIListLayout", box)
		bl.Padding = UDim.new(0, 4)
		bl.SortOrder = Enum.SortOrder.LayoutOrder
		if heading ~= "" then
			local h = text(box, heading, 14, C.Ember, FONT_BOLD)
			h.LayoutOrder = 1
			h.Size = UDim2.new(1, 0, 0, 18)
		end
		if hint then
			local d = text(box, hint, 12, C.Dim)
			d.LayoutOrder = 2
			d.Size = UDim2.new(1, 0, 0, 0)
			d.AutomaticSize = Enum.AutomaticSize.Y
		end
		local grid = Instance.new("Frame")
		grid.LayoutOrder = 3
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.BackgroundTransparency = 1
		grid.Parent = box
		local g = Instance.new("UIGridLayout", grid)
		local n = cols or 2
		g.CellSize = UDim2.new(1 / n, -(4 * (n - 1)) / n, 0, 34)
		g.CellPadding = UDim2.fromOffset(4, 4)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		return grid
	end

	-- cmd: ข้อความคำสั่ง หรือฟังก์ชันที่คืนคำสั่ง (ปุ่มที่ขึ้นกับตัวเลือกบนแผง เช่น จำนวนคนในคัทซีน)
	local function button(parent: Instance, label: string, cmd: string | () -> string, style: Style?): TextButton
		local b = Instance.new("TextButton")
		b.LayoutOrder = nextOrder(parent)
		b.BackgroundColor3 = if style == "primary" then C.LineHot elseif style == "danger" then Color3.fromRGB(70, 28, 22) else C.Button
		b.TextColor3 = if style == "primary" then C.Ink else C.Cream
		b.FontFace = if style then FONT_BOLD else FONT
		b.TextSize = 14
		b.TextWrapped = true
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.Text = label
		b.AutoButtonColor = false
		b.Parent = parent
		corner(b, 6)
		local st = stroke(b, if style == "danger" then C.Bad else C.Line, 0.2)
		local base = b.BackgroundColor3
		b.MouseEnter:Connect(function()
			st.Color = C.LineHot
			if not style then
				b.BackgroundColor3 = C.ButtonHot
			end
		end)
		b.MouseLeave:Connect(function()
			st.Color = if style == "danger" then C.Bad else C.Line
			b.BackgroundColor3 = base
		end)
		b.Activated:Connect(function()
			local c = if type(cmd) == "function" then cmd() else cmd
			-- กดแล้วกระพริบให้รู้ว่ารับคำสั่งแล้ว
			b.BackgroundColor3 = C.Ember
			TweenService:Create(b, TweenInfo.new(0.35), { BackgroundColor3 = base }):Play()
			-- ผีฉากเกิดบนเครื่องตัวเอง (client/SceneryGhosts) ไม่ผ่านเซิร์ฟเวอร์
			if type(c) == "string" and string.sub(c, 1, 8) == "scenery:" then
				Players.LocalPlayer:SetAttribute("SceneryTest", string.sub(c, 9) .. ":" .. os.clock())
			else
				remote:FireServer(c)
			end
			notify("✓ " .. string.gsub(label, "\n", " "))
		end)
		return b
	end

	testCard.Activated:Connect(function()
		local on = ReplicatedStorage:GetAttribute("TestMode") == true
		remote:FireServer(if on then "testmode:off" else "testmode:on")
		notify(if on then "ปิดโหมดทดสอบ: เกมกลับมาสุ่มเองตามปกติ" else "เปิดโหมดทดสอบ: หยุดทุกอย่างที่เกิดเองแล้ว", C.Ember)
	end)

	-- ================================================================ แท็บ: ร้าน
	local g = section("shop", "เตรียมร้าน", "จัดร้านพร้อมขาย = เปิดแผง ไฟติด น้ำมันเต็ม ถวายขนม ข้ามช่วงเตรียมร้าน", 1)
	button(g, "⚡ จัดร้านพร้อมขายทันที", "shopready", "primary")
	g = section("shop", "น้ำมัน / ไฟ")
	button(g, "⛽ น้ำมันในตู้เต็ม", "fuelfull")
	button(g, "🫗 น้ำมันในตู้หมด", "fuelempty")
	button(g, "💡 ไฟดับ (ต้องสตาร์ทเครื่อง)", "powercut")
	g = section("shop", "อากาศ")
	button(g, "🌧️ ฝนตก", "rain")
	button(g, "☀️ ฟ้าใส", "clear")

	-- คัทซีน: Studio เลือกจำนวนคน (ผู้เล่นจริง + หุ่นทดสอบเติมให้ครบ) ไว้ดูที่นั่ง/ลงรถ/กล้องตอนหลายคน
	-- รถเปลี่ยนตามจำนวน: 1 มอไซค์ / 2 ตุ๊กตุ๊ก / 3 เก๋ง / 4-6 กระบะ
	local cutN = 0 -- 0 = ตามผู้เล่นจริงในห้อง (ไม่เติมหุ่น)
	local function cutCmd(kind: string): () -> string
		return function()
			return if cutN > 0 then kind .. "@" .. cutN else kind
		end
	end
	if RunService:IsStudio() then
		local chips = section("shop", "คัทซีน", "จำนวนคนในคัทซีน (เติมหุ่นให้ครบ · เฉพาะ Studio)")
		local cg = chips:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		cg.CellSize = UDim2.new(1 / 7, -4, 0, 30)
		local chipButtons: { [number]: TextButton } = {}
		local function paintChips()
			for n, c in pairs(chipButtons) do
				local on = n == cutN
				c.BackgroundColor3 = if on then C.LineHot else C.Button
				c.TextColor3 = if on then C.Ink else C.Cream
			end
		end
		for n = 0, 6 do
			local c = Instance.new("TextButton")
			c.LayoutOrder = n
			c.BackgroundColor3 = C.Button
			c.TextColor3 = C.Cream
			c.FontFace = FONT_BOLD
			c.TextSize = 14
			c.Text = if n == 0 then "จริง" else tostring(n)
			c.AutoButtonColor = false
			c.Parent = chips
			corner(c, 6)
			c.Activated:Connect(function()
				cutN = n
				paintChips()
			end)
			chipButtons[n] = c
		end
		paintChips()
		g = section("shop", "", nil)
	else
		g = section("shop", "คัทซีน")
	end
	button(g, "🎬 คัทซีนเปิดคืน", cutCmd("intro"))
	button(g, "🌅 ชนะทันที (สรุปผล)", cutCmd("win"))

	-- ================================================================ แท็บ: ลูกค้า
	g = section("customer", "เรียกลูกค้าปกติ", "มาได้ทีละ 1 ราย (มีลูกค้าอยู่ที่ตู้แล้วกดซ้ำจะไม่มา)")
	button(g, "🏍️ มอเตอร์ไซค์", "spawn")
	button(g, "🚗 รถยนต์ (ดีเซล)", "car")
	button(g, "🛺 ตุ๊กตุ๊ก", "tuktuk")
	button(g, "🚶 คนเดินถือแกลลอน", "walker")
	button(g, "🚲 จักรยานยางแบน", "bicycle")
	button(g, "☂️ คนมาหลบฝน", "shelter")
	g = section("customer", "ลูกค้าคันถัดไปเป็นผี", "เลือกผีแล้วลูกค้าจะมาทันที (ผีที่ต้องฝนตก เกมสั่งฝนให้เอง)")
	local ok, keys = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("AdminAnomalies") or "[]")
	end)
	for _, k in ipairs(if ok then keys else {}) do
		local name = k
		pcall(function()
			name = LanguageModule.GetBook(k, "th")
		end)
		if name == k then
			name = string.gsub(k, "^Anomaly_", "")
		end
		button(g, "👻 " .. name, "anomaly:" .. k)
	end

	-- ================================================================ แท็บ: อีเวนต์
	g = section("event", "ขาจรบนถนน", "ปกติเกิดเองคืนละ 1 ครั้ง · ปุ่มนี้เรียกได้ตลอด")
	button(g, "🏍️ เด็กแว้น / รถซิ่ง", "racer")
	button(g, "🔊 รถแห่ / รถแดนซ์", "party")
	button(g, "🥁 ขบวนแห่นาค", "parade")
	g = section("event", "ผีใหญ่บุกประชิด", "วิธีรอด: ดับไฟที่สะพานไฟ + นั่งยอง [C]")
	button(g, "🔴 แสงไฟผีกระสือ", "big:Krasue")
	button(g, "🧍 เปรตเดินผ่าน", "big:Pret")
	button(g, "⚰️ ขบวนแห่ศพ", "big:Funeral")
	button(g, "✊ ปอบเคาะแผง", "big:Pop")

	-- ================================================================ แท็บ: ผีฉาก
	g = section("scenery", "เรียกผีฉาก", "เห็นเฉพาะเครื่องตัวเอง · หันไปเห็น = เดินเข้าหา · บางตัวจ้องค้าง = พุ่งใส่หน้า")
	button(g, "ตานีหลังกอกล้วย", "scenery:Tani")
	button(g, "หุ่นไล่กาใกล้ร้าน", "scenery:Scarecrow")
	button(g, "เงาหลังต้นไทร", "scenery:Shadow")
	button(g, "นางรำโคนต้นไทร", "scenery:Dancer")
	button(g, "แม่นาคริมคันนา", "scenery:MaeNak")
	button(g, "กุมารทองข้างศาล", "scenery:Kuman")
	button(g, "ผีเด็กฝั่งตรงข้าม", "scenery:Child")
	button(g, "ศพห่อผ้ากลางทุ่ง", "scenery:Shroud")
	button(g, "กระสือเหนือทุ่งนา", "scenery:Krasue")
	button(g, "ปอบริมถนน", "scenery:Pop")
	button(g, "เปรตเดินท้ายทุ่ง", "scenery:Pret")
	button(g, "กระหังบินข้ามทุ่ง", "scenery:Krahang")
	g = section("scenery", "", nil, 1)
	button(g, "ซ่อนผีฉากที่โผล่อยู่", "scenery:hide")

	-- ================================================================ แท็บ: ผู้เล่น
	g = section("people", "ศาลพระภูมิ")
	button(g, "😈 ศาลหิว (เริ่มโดนหลอก)", "hungry")
	button(g, "🙏 ถวายขนมแล้ว", "offer")
	button(g, "🍡 แจกขนมทุกคน", "dessert")
	g = section("people", "อาการแปลกๆ (ทุกคน)")
	button(g, "📳 จอเขย่า", "curse:shake")
	button(g, "🐢 เดินช้า", "curse:slow")
	button(g, "🤕 เดินๆ อยู่ล้ม", "curse:stumble")
	-- ปุ่มต่อผู้เล่นในห้อง: แถวละคน (ชื่อ + ตาย + ชุบ) สร้างใหม่ทุกครั้งที่มีคนเข้า/ออก
	local peoplePage = pages.people
	local roster = Instance.new("Frame")
	roster.LayoutOrder = nextOrder(peoplePage)
	roster.Size = UDim2.new(1, 0, 0, 0)
	roster.AutomaticSize = Enum.AutomaticSize.Y
	roster.BackgroundTransparency = 1
	roster.Parent = peoplePage
	local rl = Instance.new("UIListLayout", roster)
	rl.Padding = UDim.new(0, 4)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	local rh = text(roster, "ผู้เล่นในห้อง", 14, C.Ember, FONT_BOLD)
	rh.LayoutOrder = 0
	rh.Size = UDim2.new(1, 0, 0, 18)
	local function refreshPlayers()
		for _, c in ipairs(roster:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for i, p in ipairs(Players:GetPlayers()) do
			local row = Instance.new("Frame")
			row.LayoutOrder = i
			row.Size = UDim2.new(1, 0, 0, 34)
			row.BackgroundColor3 = C.Card
			row.Parent = roster
			corner(row, 6)
			local n = text(row, p.DisplayName .. (if p == player then "  (ฉัน)" else ""), 14, C.Cream)
			n.Position = UDim2.fromOffset(10, 0)
			n.Size = UDim2.new(1, -150, 1, 0)
			n.TextTruncate = Enum.TextTruncate.AtEnd
			n.TextWrapped = false
			local btns = Instance.new("Frame")
			btns.AnchorPoint = Vector2.new(1, 0.5)
			btns.Position = UDim2.new(1, -4, 0.5, 0)
			btns.Size = UDim2.fromOffset(136, 26)
			btns.BackgroundTransparency = 1
			btns.Parent = row
			local bg = Instance.new("UIGridLayout", btns)
			bg.CellSize = UDim2.new(0.5, -2, 1, 0)
			bg.CellPadding = UDim2.fromOffset(4, 0)
			bg.SortOrder = Enum.SortOrder.LayoutOrder
			button(btns, "💀 ตาย", "kill:" .. p.UserId, "danger")
			button(btns, "✨ ชุบ", "revive:" .. p.UserId)
		end
	end
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
	g = section("people", "", nil, 1)
	button(g, "☠️ ทุกคนตาย (แพ้ทั้งร้าน)", "lose", "danger")

	selectTab("shop")

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			gui.Enabled = not gui.Enabled
		end
	end)
end

if player:GetAttribute("Admin") then
	start()
else
	local conn
	conn = player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") then
			conn:Disconnect()
			start()
		end
	end)
end
