--!nonstrict
-- TutorialController.client.luau
-- สอนเล่นทีละขั้นหลังคัทซีนเปิดคืนจบ (ครั้งแรกที่เข้าเกม): แผงคำแนะนำมุมซ้าย + กรอบเรืองแสงที่ของที่ต้องไปกด
--   ทำขั้นนั้นสำเร็จ (ใครในทีมทำก็ได้ ยกเว้นไฟฉาย/แกลลอนที่เป็นของตัวเอง) -> ไปขั้นถัดไปเอง
--   กด H ซ่อน/แสดง  ·  ขั้นที่ทำเสร็จไปก่อนแล้ว (เช่น เพื่อนเปิดร้านแล้ว) ข้ามไปเลย
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local function ui(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize(player:GetAttribute("Lang") :: string?))
end

-- ธีมเดียวกับ HUD
local C = {
	Ink = Color3.fromRGB(14, 13, 11),
	Line = Color3.fromRGB(70, 64, 54),
	Cream = Color3.fromRGB(236, 228, 208),
	Dim = Color3.fromRGB(196, 188, 168),
	Ember = Color3.fromRGB(230, 120, 50),
	Gold = Color3.fromRGB(226, 186, 110),
}
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

-- ---------------------------------------------------------------- ของในฉาก
local function interactive(name: string): Instance?
	local ip = Workspace:FindFirstChild("InteractiveProps")
	return ip and ip:FindFirstChild(name, true)
end
local function findTool(name: string): Tool?
	local c = player.Character
	local t = c and c:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	t = bp and bp:FindFirstChild(name)
	return if t and t:IsA("Tool") then t else nil
end
local function drums(): { Instance }
	local env = Workspace:FindFirstChild("MapEnvironment")
	local yard = env and env:FindFirstChild("ImportedYardProps")
	local out = {}
	for _, n in ipairs({ "FuelDrum", "FuelDrum_Red" }) do
		local d = yard and yard:FindFirstChild(n)
		if d then
			table.insert(out, d)
		end
	end
	return out
end
local function fuelled(): boolean
	return (remotes:GetAttribute("PetrolLevel") or 0) > 0 or (remotes:GetAttribute("DieselLevel") or 0) > 0
end

-- ขั้นตอน: key = ข้อความใน LanguageModule.UI, done() = ทำเสร็จแล้ว, targets() = ของที่ทำกรอบเรืองแสง
type Step = { key: string, done: () -> boolean, targets: () -> { Instance }, hold: number? }
local STEPS: { Step } = {
	{
		key = "Tut_Flashlight",
		done = function()
			local c = player.Character
			return c ~= nil and c:FindFirstChild("FrogFlashlight") ~= nil
		end,
		targets = function()
			return {}
		end,
	},
	{
		key = "Tut_OpenShop",
		done = function()
			return remotes:GetAttribute("ShopOpen") == true
		end,
		targets = function()
			return { interactive("RejectRope") }
		end,
	},
	{
		key = "Tut_Generator",
		done = function()
			return ReplicatedStorage:GetAttribute("PowerOn") ~= false
		end,
		targets = function()
			return { Workspace:FindFirstChild("Generator") }
		end,
	},
	{
		key = "Tut_TakeCan",
		done = function()
			return findTool("FuelCan") ~= nil or fuelled()
		end,
		targets = function()
			return { interactive("FuelCanSpot") }
		end,
	},
	{
		key = "Tut_FillCan",
		done = function()
			local can = findTool("FuelCan")
			return (can ~= nil and can:GetAttribute("Full") == true) or fuelled()
		end,
		targets = drums,
	},
	{
		key = "Tut_Pour",
		done = fuelled,
		targets = function()
			return { interactive("FuelPumps") }
		end,
	},
	{
		key = "Tut_Offer",
		done = function()
			-- ถวายแล้ว = เวลาคุ้มครองเด้งขึ้นเกินช่วงผ่อนผันตอนเปิดร้าน
			local left = remotes:GetAttribute("OfferingLeft")
			local total = remotes:GetAttribute("OfferingTotal") or 150
			return type(left) == "number" and left > total - 10
		end,
		targets = function()
			return { Workspace:FindFirstChild("SpiritHouse") }
		end,
	},
	{
		key = "Tut_Ghosts",
		done = function()
			return false
		end,
		targets = function()
			return { interactive("RejectRope") }
		end,
		hold = 12, -- ขั้นสุดท้ายเป็นคำอธิบาย: แสดงแล้วจบเอง
	},
}

-- ---------------------------------------------------------------- UI (มุมซ้ายกลางจอ)
local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.AutoLocalize = false
gui.DisplayOrder = 3
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 16, 0.42, 0)
panel.Size = UDim2.fromOffset(300, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = C.Ink
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 3)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = C.Line
stroke.Transparency = 0.2
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 10), UDim.new(0, 12), UDim.new(0, 12)
local list = Instance.new("UIListLayout", panel)
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder

local title = Instance.new("TextLabel")
title.LayoutOrder = 1
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 18)
title.FontFace = FONT
title.TextSize = 13
title.TextColor3 = C.Ember
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel
local body = Instance.new("TextLabel")
body.LayoutOrder = 2
body.BackgroundTransparency = 1
body.Size = UDim2.new(1, 0, 0, 0)
body.AutomaticSize = Enum.AutomaticSize.Y
body.FontFace = FONT
body.TextSize = 16
body.TextWrapped = true
body.TextColor3 = C.Cream
body.TextXAlignment = Enum.TextXAlignment.Left
body.Parent = panel
local hint = Instance.new("TextLabel")
hint.LayoutOrder = 3
hint.BackgroundTransparency = 1
hint.Size = UDim2.new(1, 0, 0, 14)
hint.FontFace = FONT
hint.TextSize = 11
hint.TextColor3 = C.Dim
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = panel

-- กรอบเรืองแสงที่ของ (เห็นทะลุผนัง จะได้รู้ว่าอยู่ทางไหน)
local highlights: { Highlight } = {}
local function clearHighlights()
	for _, h in ipairs(highlights) do
		h:Destroy()
	end
	table.clear(highlights)
end
local function highlight(targets: { Instance? })
	clearHighlights()
	for _, t in ipairs(targets) do
		if t then
			local h = Instance.new("Highlight")
			h.Name = "TutorialHighlight"
			h.Adornee = t
			h.FillColor = C.Gold
			h.FillTransparency = 0.85
			h.OutlineColor = C.Gold
			h.OutlineTransparency = 0.1
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = gui
			table.insert(highlights, h)
			-- กะพริบเบาๆ
			TweenService:Create(h, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.7, FillTransparency = 0.95 }):Play()
		end
	end
end

local current = 0
local hidden = false
local running = false
local function draw()
	local s = STEPS[current]
	if not s then
		return
	end
	title.Text = string.format("%s  (%d/%d)", ui("Tut_Title"), current, #STEPS)
	body.Text = ui(s.key)
	hint.Text = ui("Tut_Hide")
end

local function show(on: boolean)
	gui.Enabled = on and not hidden
	for _, h in ipairs(highlights) do
		h.Enabled = on and not hidden
	end
end

local function run()
	if running then
		return
	end
	running = true
	for i, s in ipairs(STEPS) do
		if s.done() and not s.hold then
			continue -- ทำไปแล้ว (เพื่อนทำ / ทำก่อนสอน)
		end
		current = i
		draw()
		highlight(s.targets())
		show(true)
		panel.BackgroundColor3 = C.Ink
		local t0 = os.clock()
		while true do
			-- คัทซีน / หน้าสรุปผล: ซ่อนไว้ก่อน
			show(ReplicatedStorage:GetAttribute("CutsceneRunning") ~= true)
			if s.hold and os.clock() - t0 >= s.hold then
				break
			end
			if not s.hold and s.done() then
				break
			end
			-- จบคืนระหว่างสอน: เลิกสอน
			if remotes:GetAttribute("GameOver") == true then
				clearHighlights()
				gui.Enabled = false
				return
			end
			task.wait(0.3)
		end
		-- สำเร็จ: แผงแวบสีทองก่อนไปขั้นต่อไป
		stroke.Color = C.Gold
		task.wait(0.6)
		stroke.Color = C.Line
	end
	clearHighlights()
	gui.Enabled = false
end

UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H and running and current > 0 then
		hidden = not hidden
		show(true)
	end
end)
player:GetAttributeChangedSignal("Lang"):Connect(draw)

-- เริ่มสอนครั้งเดียวต่อการเข้าเกม: หลังคัทซีนเปิดคืนจบ (ดูจบ/ข้าม) หรือไม่มีคัทซีนแต่ร้านยังไม่เปิด
local cutscene = remotes:WaitForChild("Cutscene") :: RemoteEvent
local started = false
local function begin()
	if started then
		return
	end
	started = true
	task.delay(1.2, run) -- ให้จอดำ/แสงกลับมาก่อน
end
cutscene.OnClientEvent:Connect(function(kind: string, a: any)
	if kind == "end" and a == "intro" then
		begin()
	elseif kind == "nocutscene" and remotes:GetAttribute("ShopOpen") ~= true then
		begin()
	end
end)
