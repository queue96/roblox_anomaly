--!strict
-- AdminPanel.client.luau
-- แผง admin (กด F2 เปิด/ปิด) เห็นเฉพาะคนที่ server ติด attribute Admin = true ให้ (ดู server/AdminPanel.server.luau)
-- ปุ่มเรียกลูกค้า อีเวนต์บนถนน สภาพอากาศ ไฟดับ และผีแต่ละตัว ได้ทันทีไม่ต้องรอสุ่ม
-- สั่งผู้เล่นตาย (ตัวเองหรือคนอื่นในห้อง ทีละคน) / ทุกคนตาย (แพ้ทั้งร้าน)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- ธีมเดียวกับ HUD (HUDController): หมึกดำ ครีม ขอบเทาน้ำตาล ฟอนต์พิมพ์ดีดเก่า
local C = {
	Ink = Color3.fromRGB(8, 7, 6),
	Panel = Color3.fromRGB(22, 20, 17),
	Button = Color3.fromRGB(26, 24, 20),
	Line = Color3.fromRGB(70, 64, 54),
	LineHot = Color3.fromRGB(185, 140, 88),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(165, 156, 136),
	Ember = Color3.fromRGB(230, 120, 50),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local function start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Admin") :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "AdminPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- กล้องล็อกมุมมองบุคคลที่หนึ่ง: ปุ่ม Modal ที่มองเห็นอยู่ทำให้ Roblox ปล่อยเมาส์ออกมากดแผงได้
	local modal = Instance.new("TextButton")
	modal.Modal = true
	modal.Size = UDim2.fromOffset(0, 0)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Parent = gui

	local frame = Instance.new("ScrollingFrame")
	frame.Size = UDim2.fromOffset(300, 460)
	frame.Position = UDim2.new(1, -316, 0.5, -230)
	frame.BackgroundColor3 = C.Panel
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 4
	frame.ScrollBarImageColor3 = C.Line
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.CanvasSize = UDim2.new()
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)
	local fs = Instance.new("UIStroke", frame)
	fs.Color = C.Line
	fs.Transparency = 0.2
	local pad = Instance.new("UIPadding", frame)
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 8)
	local list = Instance.new("UIListLayout", frame)
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder

	local order = 0
	local function label(text: string)
		order += 1
		local l = Instance.new("TextLabel")
		l.LayoutOrder = order
		l.Size = UDim2.new(1, 0, 0, 22)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = C.Ember
		l.FontFace = FONT
		l.TextSize = 15
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = frame
	end
	local function button(text: string, cmd: string, parent: GuiObject?)
		order += 1
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 28)
		b.BackgroundColor3 = C.Button
		b.BackgroundTransparency = 0.1
		b.TextColor3 = C.Cream
		b.FontFace = FONT
		b.TextSize = 14
		b.Text = text
		b.AutoButtonColor = false
		b.Parent = parent or frame
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
		local st = Instance.new("UIStroke", b)
		st.Color = C.Line
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		b.MouseEnter:Connect(function()
			st.Color = C.LineHot
		end)
		b.MouseLeave:Connect(function()
			st.Color = C.Line
		end)
		b.Activated:Connect(function()
			remote:FireServer(cmd)
		end)
	end

	label("Admin  [F2]")
	label("ลูกค้า")
	button("มอเตอร์ไซค์", "spawn")
	button("รถยนต์ (ดีเซล)", "car")
	button("ตุ๊กตุ๊ก", "tuktuk")
	button("คนเดินถือแกลลอน", "walker")
	button("จักรยานยางแบน", "bicycle")
	button("คนมาหลบฝน", "shelter")
	label("อีเวนต์บนถนน")
	button("รถซิ่ง", "racer")
	button("รถแห่ / รถแดนซ์", "party")
	button("ขบวนแห่นาค", "parade")
	label("ร้าน / อากาศ")
	button("ไฟดับ (ต้องไปสตาร์ทเครื่องปั่นไฟ)", "powercut")
	button("ฝนตก", "rain")
	button("ฟ้าใส", "clear")
	button("น้ำมันในตู้หมด (แกลลอน + ถังหลังร้าน)", "fuelempty")
	button("น้ำมันในตู้เต็ม", "fuelfull")
	label("ศาลพระภูมิ / อาการแปลกๆ")
	button("ศาลหิว (เริ่มโดนหลอกไม่หยุด)", "hungry")
	button("ถวายขนมแล้ว (หยุดอาการ)", "offer")
	button("แจกขนมทุกคน", "dessert")
	button("กระซิบ + ตาจะหลับ", "curse:drowsy")
	button("จอเขย่า", "curse:shake")
	button("เดินช้า", "curse:slow")
	button("เดินๆ อยู่ล้ม", "curse:stumble")
	label("ผีฉาก (โผล่ให้เห็นเฉยๆ มองค้างนาน = พุ่งใส่หน้า)")
	button("ผีตานีหลังกอกล้วย", "scenery:Tani")
	button("หุ่นไล่กาใกล้ร้าน", "scenery:Scarecrow")
	button("เงาหลังต้นไทร", "scenery:Shadow")
	button("ซ่อนผีฉาก", "scenery:hide")
	label("คัทซีน")
	button("เล่นคัทซีนเปิดคืน", "intro")
	button("ชนะทันที (คัทซีนเช้า + สรุปผล)", "win")
	label("ผู้เล่น (สั่งตาย / ชุบ)")
	-- ปุ่มต่อผู้เล่นในห้อง (ตัวเอง + คนอื่น) สร้างใหม่ทุกครั้งที่มีคนเข้า/ออก: ตายคนเดียว ร้านเล่นต่อ / ชุบคนที่ตาย
	order += 1
	local playersBox = Instance.new("Frame")
	playersBox.LayoutOrder = order
	playersBox.Size = UDim2.new(1, 0, 0, 0)
	playersBox.AutomaticSize = Enum.AutomaticSize.Y
	playersBox.BackgroundTransparency = 1
	playersBox.Parent = frame
	local pl = Instance.new("UIListLayout", playersBox)
	pl.Padding = UDim.new(0, 4)
	pl.SortOrder = Enum.SortOrder.LayoutOrder
	local function refreshPlayers()
		for _, c in ipairs(playersBox:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local who = p.DisplayName .. (if p == player then " (ฉัน)" else "")
			button("ตาย: " .. who, "kill:" .. p.UserId, playersBox)
			button("ชุบ: " .. who, "revive:" .. p.UserId, playersBox)
		end
	end
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
	button("ทุกคนตาย (แพ้ทั้งร้าน)", "lose")
	label("ผี (ลูกค้าคันถัดไป)")
	local ok, keys = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("AdminAnomalies") or "[]")
	end)
	for _, k in ipairs(if ok then keys else {}) do
		button(string.gsub(k, "^Anomaly_", ""), "anomaly:" .. k)
	end

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
