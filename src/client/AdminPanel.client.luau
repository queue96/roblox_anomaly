--!strict
-- AdminPanel.client.luau
-- แผง admin (กด F2 เปิด/ปิด) เห็นเฉพาะคนที่ server ติด attribute Admin = true ให้ (ดู server/AdminPanel.server.luau)
-- ปุ่มเรียกลูกค้า อีเวนต์บนถนน สภาพอากาศ ไฟดับ และผีแต่ละตัว ได้ทันทีไม่ต้องรอสุ่ม
-- สั่งผู้เล่นตาย (ตัวเองหรือคนอื่นในห้อง ทีละคน) / ทุกคนตาย (แพ้ทั้งร้าน)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

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
	-- cmd: ข้อความคำสั่ง หรือฟังก์ชันที่คืนคำสั่ง (ปุ่มที่ขึ้นกับตัวเลือกบนแผง เช่น จำนวนคนในคัทซีน)
	local function button(text: string, cmd: string | () -> string, parent: GuiObject?): TextButton
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
			local c = if type(cmd) == "function" then cmd() else cmd
			-- ผีฉากเกิดบนเครื่องตัวเอง (client/SceneryGhosts) ไม่ผ่านเซิร์ฟเวอร์
			if type(c) == "string" and string.sub(c, 1, 8) == "scenery:" then
				Players.LocalPlayer:SetAttribute("SceneryTest", string.sub(c, 9) .. ":" .. os.clock())
				return
			end
			remote:FireServer(c)
		end)
		return b
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
	button("จัดร้านพร้อมขายทันที (เปิดร้าน ไฟ น้ำมัน ถวายขนม)", "shopready")
	button("ไฟดับ (ต้องไปสตาร์ทเครื่องปั่นไฟ)", "powercut")
	button("ฝนตก", "rain")
	button("ฟ้าใส", "clear")
	button("น้ำมันในตู้หมด (แกลลอน + ถังหลังร้าน)", "fuelempty")
	button("น้ำมันในตู้เต็ม", "fuelfull")
	label("ศาลพระภูมิ / อาการแปลกๆ")
	button("ศาลหิว (เริ่มโดนหลอกไม่หยุด)", "hungry")
	button("ถวายขนมแล้ว (หยุดอาการ)", "offer")
	button("แจกขนมทุกคน", "dessert")
	button("จอเขย่า", "curse:shake")
	button("เดินช้า", "curse:slow")
	button("เดินๆ อยู่ล้ม", "curse:stumble")
	label("ผีฉาก (เห็นเฉพาะเครื่องตัวเอง มองค้างนาน = พุ่งใส่หน้า)")
	button("ผีตานีหลังกอกล้วย", "scenery:Tani")
	button("หุ่นไล่กาใกล้ร้าน", "scenery:Scarecrow")
	button("เงาหลังต้นไทร", "scenery:Shadow")
	button("ผีนางรำโคนต้นไทร", "scenery:Dancer")
	button("แม่นาคริมคันนา", "scenery:MaeNak")
	button("กุมารทองข้างศาล", "scenery:Kuman")
	button("ผีเด็กฝั่งตรงข้าม", "scenery:Child")
	button("ศพห่อผ้าขาวกลางทุ่ง", "scenery:Shroud")
	button("กระสือเหนือทุ่งนา", "scenery:Krasue")
	button("ปอบริมถนน", "scenery:Pop")
	button("เปรตเดินท้ายทุ่ง", "scenery:Pret")
	button("กระหังบินข้ามทุ่ง", "scenery:Krahang")
	button("ซ่อนผีฉาก", "scenery:hide")
	label("ผีใหญ่บุกประชิด (ดับไฟที่สะพานไฟ + นั่งยอง C)")
	button("แสงไฟผีกระสือ", "big:Krasue")
	button("เปรตเดินผ่าน", "big:Pret")
	button("ขบวนแห่ศพ", "big:Funeral")
	button("ปอบเคาะแผง", "big:Pop")
	label("คัทซีน")
	-- Studio: เลือกจำนวนคนในคัทซีน (ผู้เล่นจริง + หุ่นทดสอบเติมให้ครบ) ไว้ดูที่นั่ง/ลงรถ/กล้องตอนหลายคน
	-- รถเปลี่ยนตามจำนวน: 1 มอไซค์ / 2 ตุ๊กตุ๊ก / 3 เก๋ง / 4-6 กระบะ
	local cutN = 0 -- 0 = ตามผู้เล่นจริงในห้อง (ไม่เติมหุ่น)
	local function cutCmd(kind: string): () -> string
		return function()
			return if cutN > 0 then kind .. "@" .. cutN else kind
		end
	end
	if RunService:IsStudio() then
		order += 1
		local hint = Instance.new("TextLabel")
		hint.LayoutOrder = order
		hint.Size = UDim2.new(1, 0, 0, 18)
		hint.BackgroundTransparency = 1
		hint.Text = "จำนวนคน (เติมหุ่นให้ครบ · Studio)"
		hint.TextColor3 = C.Dim
		hint.FontFace = FONT
		hint.TextSize = 13
		hint.TextXAlignment = Enum.TextXAlignment.Left
		hint.Parent = frame
		order += 1
		local row = Instance.new("Frame")
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.Parent = frame
		local rl = Instance.new("UIListLayout", row)
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.Padding = UDim.new(0, 4)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		local chips: { [number]: TextButton } = {}
		local function paint()
			for n, chip in pairs(chips) do
				local on = n == cutN
				chip.BackgroundColor3 = if on then C.LineHot else C.Button
				chip.TextColor3 = if on then C.Ink else C.Cream
			end
		end
		for n = 0, 6 do
			local chip = Instance.new("TextButton")
			chip.LayoutOrder = n
			chip.Size = UDim2.new(1 / 7, -4, 1, 0)
			chip.BackgroundColor3 = C.Button
			chip.BackgroundTransparency = 0.1
			chip.TextColor3 = C.Cream
			chip.FontFace = FONT
			chip.TextSize = 14
			chip.Text = if n == 0 then "จริง" else tostring(n)
			chip.AutoButtonColor = false
			chip.Parent = row
			Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 3)
			local st = Instance.new("UIStroke", chip)
			st.Color = C.Line
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			chip.Activated:Connect(function()
				cutN = n
				paint()
			end)
			chips[n] = chip
		end
		paint()
	end
	button("เล่นคัทซีนเปิดคืน", cutCmd("intro"))
	button("ชนะทันที (คัทซีนเช้า + สรุปผล)", cutCmd("win"))
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
