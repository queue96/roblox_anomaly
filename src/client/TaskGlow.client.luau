--!strict
-- TaskGlow.client.luau
-- ของที่ต้องจัดการเรืองแสงในฉาก ตลอดเวลาที่งานนั้นยังค้าง (ทุกคืน ไม่ใช่แค่ครั้งแรกที่สอน) ผู้ใช้ 2026-11-23
--   งานหลายขั้น: เรืองเฉพาะ "ของชิ้นถัดไป" ตามของที่ถืออยู่ในมือ ทำขั้นนั้นเสร็จ แสงย้ายไปชิ้นต่อไปเอง
--     ปั่นไฟ (ไฟดับ):             เครื่องปั่นไฟ (1/1)
--     กรอกน้ำมัน (ตู้หมด):        ไม่มีแกลลอน = จุดวางแกลลอน (1/3) · แกลลอนเปล่า = ถังน้ำมัน (2/3) · แกลลอนเต็ม = ตู้ปั๊ม (3/3)
--     ถวายขนม (ศาลต้องการขนม):   ไม่มีขนม = ถาดขนมบนเคาน์เตอร์ (1/2) · ถือขนม = ศาลพระภูมิ (2/2)
--   กรอบเรืองทองกะพริบช้า เห็นทะลุของที่บัง + ป้ายเล็ก "1/3 · หยิบแกลลอน" ลอยบนของ
--   เล่นกับเพื่อน: เพื่อนถือแกลลอน/ขนมอยู่แล้ว (เราไม่ได้ถือ) = งานนั้นมีคนทำ ไม่ต้องเรืองให้เรา
--   ปิดได้ในหน้าตั้งค่า (ShowTaskGlow) · ไม่แสดงระหว่างคัทซีน
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local GOLD = Color3.fromRGB(226, 186, 110)
local INK = Color3.fromRGB(14, 13, 11)
local CREAM = Color3.fromRGB(236, 228, 208)
local FONT = Font.fromEnum(Enum.Font.SpecialElite)
local OFFER_SOON = 60 -- เวลาคุ้มครองของศาลเหลือไม่เกินนี้ (วินาที) = ถึงเวลาถวาย (เท่ากับ TutorialController)

local function ui(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize(player:GetAttribute("Lang") :: string?))
end

-- ---------------------------------------------------------------- ของในฉาก (ชื่อเดียวกับ TutorialController)
local function interactive(name: string): Instance?
	local ip = Workspace:FindFirstChild("InteractiveProps")
	return ip and ip:FindFirstChild(name, true)
end
local function holds(p: Player, name: string, backpackToo: boolean): Tool?
	local c = p.Character
	local t = c and c:FindFirstChild(name)
	if t and t:IsA("Tool") then
		return t
	end
	if backpackToo then
		local bp = p:FindFirstChildOfClass("Backpack")
		t = bp and bp:FindFirstChild(name)
		if t and t:IsA("Tool") then
			return t
		end
	end
	return nil
end
-- เพื่อนคนอื่นถือของชิ้นนี้อยู่ (เห็นเฉพาะที่ถือในมือ: กระเป๋าของคนอื่นไม่ส่งมาเครื่องเรา)
local function friendHolds(name: string): boolean
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and holds(p, name, false) then
			return true
		end
	end
	return false
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
local function list(...: Instance?): { Instance }
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then
			table.insert(out, v)
		end
	end
	return out
end

-- งานที่ค้างอยู่ตอนนี้: { targets, step, total, key }
type Want = { targets: { Instance }, step: number, total: number, key: string }
local function pending(): { Want }
	local out: { Want } = {}
	-- ปั่นไฟ
	if ReplicatedStorage:GetAttribute("PowerOn") == false then
		table.insert(out, { targets = list(Workspace:FindFirstChild("Generator")), step = 1, total = 1, key = "Task_Generator" })
	end
	-- กรอกน้ำมัน
	if not fuelled() then
		local can = holds(player, "FuelCan", true)
		if can then
			if can:GetAttribute("Full") == true then
				table.insert(out, { targets = list(interactive("FuelPumps") or interactive("GasPump")), step = 3, total = 3, key = "Task_Pour" })
			else
				table.insert(out, { targets = drums(), step = 2, total = 3, key = "Task_FillCan" })
			end
		elseif not friendHolds("FuelCan") then
			table.insert(out, { targets = list(interactive("FuelCanSpot")), step = 1, total = 3, key = "Task_TakeCan" })
		end
	end
	-- ถวายขนม: ช่วงเตรียมร้านยังไม่ถวาย / เวลาคุ้มครองใกล้หมด / ศาลหิวแล้ว
	local left = remotes:GetAttribute("OfferingLeft")
	local prepping = type(remotes:GetAttribute("PrepLeft")) == "number" and remotes:GetAttribute("PrepOffered") ~= true
	local due = prepping or (type(left) == "number" and left >= 0 and left <= OFFER_SOON) or remotes:GetAttribute("Cursed") == true
	if holds(player, "ThaiDessert", true) then
		-- ถือขนมอยู่ = ศาลเรืองเสมอ (ขนมมีไว้ถวายอย่างเดียว ผู้ใช้ 2026-11-23 "อย่าลืมไฮไลต์ศาลด้วย")
		table.insert(out, { targets = list(Workspace:FindFirstChild("SpiritHouse")), step = 2, total = 2, key = "Task_Offer" })
	elseif due and not friendHolds("ThaiDessert") then
		table.insert(out, { targets = list(interactive("DessertTray")), step = 1, total = 2, key = "Task_TakeSweets" })
	end
	return out
end

-- ---------------------------------------------------------------- กรอบเรืองแสง + ป้าย
local gui = Instance.new("ScreenGui")
gui.Name = "TaskGlow"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

type Mark = { h: Highlight, bb: BillboardGui, label: TextLabel, text: string }
local marks: { [Instance]: Mark } = {}

local function anchorPart(t: Instance): BasePart?
	if t:IsA("BasePart") then
		return t
	end
	if t:IsA("Model") and t.PrimaryPart then
		return t.PrimaryPart
	end
	return t:FindFirstChildWhichIsA("BasePart", true)
end

local function topY(t: Instance): number?
	if t:IsA("BasePart") then
		return t.Position.Y + t.Size.Y / 2
	end
	if t:IsA("Model") then
		local cf, size = t:GetBoundingBox()
		return cf.Position.Y + size.Y / 2
	end
	return nil
end

local function makeMark(t: Instance): Mark?
	local part = anchorPart(t)
	if not part then
		return nil
	end
	local h = Instance.new("Highlight")
	h.Name = "TaskHighlight"
	h.Adornee = t
	h.FillColor = GOLD
	h.FillTransparency = 0.82
	h.OutlineColor = GOLD
	h.OutlineTransparency = 0.05
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = gui
	-- กะพริบช้าๆ
	TweenService:Create(h, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { OutlineTransparency = 0.65, FillTransparency = 0.95 }):Play()

	local bb = Instance.new("BillboardGui")
	bb.Name = "TaskBadge"
	bb.Adornee = part
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	-- BillboardGui ขยายตามข้อความเองไม่ได้ (เดิมกว้าง 0 = ไม่เห็นป้าย) -> กรอบกว้างพอ ป้ายจัดกลางขยายตามข้อความข้างใน
	bb.Size = UDim2.fromOffset(320, 30)
	local top = topY(t)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (if top then top - part.Position.Y else part.Size.Y / 2) + 1.4, 0)
	bb.Parent = gui
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 26)
	label.BackgroundColor3 = INK
	label.BackgroundTransparency = 0.2
	label.TextColor3 = CREAM
	label.FontFace = FONT
	label.TextSize = 15
	label.Parent = bb
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", label)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", label)
	stroke.Color = GOLD
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return { h = h, bb = bb, label = label, text = "" }
end

local function dropMark(t: Instance)
	local mk = marks[t]
	if mk then
		mk.h:Destroy()
		mk.bb:Destroy()
		marks[t] = nil
	end
end

local function update()
	local enabled = player:GetAttribute("ShowTaskGlow") ~= false and ReplicatedStorage:GetAttribute("CutsceneRunning") ~= true
	local wanted: { [Instance]: string } = {}
	if enabled then
		for _, w in ipairs(pending()) do
			for _, t in ipairs(w.targets) do
				wanted[t] = string.format("%d/%d · %s", w.step, w.total, ui(w.key))
			end
		end
	end
	for t in pairs(marks) do
		if not wanted[t] or not t.Parent then
			dropMark(t)
		end
	end
	for t, text in pairs(wanted) do
		local mk = marks[t]
		if not mk then
			mk = makeMark(t)
			if mk then
				marks[t] = mk
			end
		end
		if mk and mk.text ~= text then
			mk.text = text
			mk.label.Text = text
		end
	end
end

while true do
	local ok, err = pcall(update)
	if not ok then
		warn("[TaskGlow]", err)
	end
	task.wait(0.25)
end
