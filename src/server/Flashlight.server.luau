-- Flashlight.server.luau
-- Phase 4: ไฟฉายกบ (StarterPack.FrogFlashlight) หยิบขึ้นมาถือแล้วสว่างทันที (ไม่ต้องคลิกเปิด/ปิด)
-- ถ่านไฟฉาย: player attribute "Battery" (0-1) หมดลงตอนถือไฟฉายอยู่ ไม่ชาร์จคืนเอง (ผู้ใช้ 2026-11-05: จะขายถ่านด้วย Robux)
--   เข้าเกมมา (เซิร์ฟเวอร์ใหม่ทุกครั้งที่เริ่มจาก Lobby) = ถ่านเต็ม 1 ก้อน ใช้หมดแล้วต้องเติม
--   หมด = ไฟดับเองแม้ถืออยู่ (tool attribute On = false) / ใกล้หมด HUD กะพริบไฟ (HUDController)
-- เติมถ่าน (ตอนซื้อสำเร็จ เช่น MarketplaceService.ProcessReceipt ของ Developer Product ถ่าน):
--   game.ServerStorage.FlashlightRefill:Fire(player, 1)   -- 1 = เต็มก้อน, 0.5 = ครึ่งก้อน (รวมไม่เกินเต็ม)

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAME = "FrogFlashlight"
local RunService = game:GetService("RunService")
local DRAIN_TIME = 100 -- วินาทีที่ถ่านเต็มก้อนเปิดได้ (ไม่ชาร์จคืนเองแล้ว)

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function lightsOf(tool: Tool): { Light }
	local list = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Light") then
			table.insert(list, d)
		end
	end
	return list
end

local function setOn(tool: Tool, on: boolean)
	for _, l in ipairs(lightsOf(tool)) do
		l.Enabled = on
	end
	local lens = tool:FindFirstChild("FlashlightLens", true)
	if lens and lens:IsA("BasePart") then
		if lens:GetAttribute("OnMaterial") == nil then
			lens:SetAttribute("OnMaterial", lens.Material.Name)
		end
		lens.Material = if on then Enum.Material[lens:GetAttribute("OnMaterial")] else Enum.Material.SmoothPlastic
	end
	tool:SetAttribute("On", on)
end

-- ตัวชาวบ้าน (มี RootPart, ไม่มีแขน RightHand): Roblox ไม่เชื่อม Handle ให้ -> ไฟฉายร่วงลงพื้น
-- เชื่อม Handle กับ HumanoidRootPart ไว้ที่มือซ้ายตามท่าถือไฟฉาย; แต่ละเครื่องขยับ C0 ให้ตรงกระดูกมือจริงทุกเฟรม
-- (client/HeadTurnOthers สำหรับคนอื่น; ตัวเราเองซ่อนชิ้นนี้ ใช้ไฟฉายของ HUDController แทน)
local GRIP_NAME = "VillagerGrip"
local GRIP_REST = CFrame.new(-0.85, 1.25, -2.0) -- มือซ้ายในกรอบ HumanoidRootPart (ท่าถือไฟฉาย มองตรง)
local function gripVillager(tool: Tool, char: Model?)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	local old = handle:FindFirstChild(GRIP_NAME)
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (char and root and char:FindFirstChild("RootPart")) then
		if old then
			old:Destroy()
		end
		return
	end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
		end
	end
	local w = (old or Instance.new("Weld")) :: Weld
	w.Name = GRIP_NAME
	w.Part0 = root
	w.Part1 = handle
	-- มือที่ถือ: ผู้เล่นเลือกในตั้งค่า (FlashHand ค่าเริ่มต้นขวา) มือขวา = ตำแหน่งกลับซ้าย-ขวา (client ขยับตามกระดูกจริงอยู่ดี)
	local pl = game:GetService("Players"):GetPlayerFromCharacter(char)
	local right = not (pl and pl:GetAttribute("FlashHand") == "L")
	w.C0 = if right then CFrame.new(-GRIP_REST.X, GRIP_REST.Y, GRIP_REST.Z) * GRIP_REST.Rotation else GRIP_REST
	w.C1 = CFrame.new()
	w.Parent = handle
end

local function hook(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or hooked[tool] then
		return
	end
	hooked[tool] = true
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
		elseif d:IsA("Light") then
			-- ไฟอยู่ระดับเอว ถ้าเปิดเงาจะทอดเงาตัวละคร/แขนตัวเองเป็นแผ่นดำทับลำแสง (LightingStyle Realistic เงาคมมาก)
			d.Shadows = false
		end
	end
	-- หยิบขึ้นมาถือ (อยู่ใน Character) = สว่างทันที, เก็บเข้ากระเป๋า = ปิดไฟ
	-- ดูจากที่อยู่ของ tool ไม่ใช่ tool.Equipped: ตัวผู้เล่นชาวบ้านไม่มีแขน RightHand ให้ Roblox จับ tool -> Equipped ไม่เกิด
	local function update()
		local char = tool.Parent
		local inHand = char ~= nil and char:IsA("Model") and char:FindFirstChildOfClass("Humanoid") ~= nil
		local p = if inHand then Players:GetPlayerFromCharacter(char) else nil
		setOn(tool, inHand and (not p or (p:GetAttribute("Battery") or 1) > 0))
		gripVillager(tool, if inHand then char :: Model else nil)
	end
	update()
	tool:GetPropertyChangedSignal("Parent"):Connect(update)
end

local starterTool = StarterPack:FindFirstChild(TOOL_NAME)
if starterTool and starterTool:IsA("Tool") then
	setOn(starterTool, true)
end

local function watch(container: Instance)
	for _, c in ipairs(container:GetChildren()) do
		hook(c)
	end
	container.ChildAdded:Connect(hook)
end

local function onPlayer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
	if backpack then
		watch(backpack)
	end
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			watch(c)
		end
	end)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

-- ---------------------------------------------------------------- ถ่าน
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then
		return
	end
	local step = acc
	acc = 0
	for _, p in ipairs(Players:GetPlayers()) do
		local b = p:GetAttribute("Battery")
		if type(b) ~= "number" then
			b = 1
		end
		local char = p.Character
		local tool = char and char:FindFirstChild(TOOL_NAME)
		if tool and tool:IsA("Tool") then
			b = math.max(0, b - step / DRAIN_TIME)
			if b <= 0 and tool:GetAttribute("On") then
				setOn(tool, false) -- ถ่านหมด
			end
		end
		if math.abs((p:GetAttribute("Battery") or -1) - b) > 0.001 then
			p:SetAttribute("Battery", b)
		end
	end
end)

-- ---------------------------------------------------------------- เติมถ่าน (ซื้อถ่าน / admin)
local ServerStorage = game:GetService("ServerStorage")
local refill = ServerStorage:FindFirstChild("FlashlightRefill") :: BindableEvent?
if not refill then
	local ev = Instance.new("BindableEvent")
	ev.Name = "FlashlightRefill"
	ev.Parent = ServerStorage
	refill = ev
end
local refillEvent = refill :: BindableEvent
refillEvent.Event:Connect(function(player: Player, amount: number?)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local b = player:GetAttribute("Battery")
	b = if type(b) == "number" then b else 1
	b = math.min(1, b + math.clamp(amount or 1, 0, 1))
	player:SetAttribute("Battery", b)
	-- ถืออยู่ตอนถ่านหมดแล้วไฟดับ: เติมแล้วสว่างทันที
	local char = player.Character
	local tool = char and char:FindFirstChild(TOOL_NAME)
	if tool and tool:IsA("Tool") and b > 0 then
		setOn(tool, true)
	end
	print(("🔋 [%s] เติมถ่านไฟฉาย -> %d%%"):format(player.Name, math.floor(b * 100 + 0.5)))
end)

-- ซื้อถ่าน = ได้ "ถ่านไฟฉาย" เข้าช่องของที่ 4 (client/ItemSlots) ซ้อนได้หลายก้อน (attribute Count)
--   ถือไฟฉาย (1) + ถ่านต่ำกว่าครึ่ง แล้วกด 4 = ใส่ถ่านก้อนใหม่ (ถ่านเต็ม)
--   ซื้อที่ "กล่องถ่านไฟฉาย" วางบนเคาน์เตอร์ในร้าน (ไม่มีปุ่มบนจอ ไม่บังคับ ผู้เล่นเห็นแล้วไปกดเอง ผู้ใช้ 2026-11-05)
--   ช่วงนี้ฟรี (ยังไม่มี Developer Product): ทีหลังเปลี่ยนเป็น MarketplaceService:PromptProductPurchase(player, BATTERY_PRODUCT_ID)
--   แล้วเรียก giveBattery ใน ProcessReceipt แทน
local FREE_BATTERY = true
local BATTERY_TOOL = "FlashlightBattery"
local MAX_BATTERIES = 9

local function batteryTool(player: Player): Tool?
	for _, c in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		local t = c and c:FindFirstChild(BATTERY_TOOL)
		if t and t:IsA("Tool") then
			return t
		end
	end
	return nil
end

-- ถ่านก้อนกลมแบบถ่านไฟฉายไทยเก่า: ตัวดำ ปลอกแดง ขั้วบวกเงิน (ไว้ทำรูปในช่องของ)
local function makeBatteryTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = BATTERY_TOOL
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90)) -- ทรงกระบอกตั้ง
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = tool
		return p
	end
	part("Body", Vector3.new(1.4, 0.62, 0.62), CFrame.new(0, 0, 0), Color3.fromRGB(25, 24, 24), Enum.Material.SmoothPlastic)
	part("Band", Vector3.new(0.5, 0.64, 0.64), CFrame.new(0, 0.35, 0), Color3.fromRGB(190, 32, 28), Enum.Material.SmoothPlastic)
	part("Cap", Vector3.new(0.08, 0.6, 0.6), CFrame.new(0, 0.74, 0), Color3.fromRGB(190, 190, 185), Enum.Material.Metal)
	part("Tip", Vector3.new(0.12, 0.2, 0.2), CFrame.new(0, 0.82, 0), Color3.fromRGB(205, 205, 200), Enum.Material.Metal)
	part("Base", Vector3.new(0.06, 0.6, 0.6), CFrame.new(0, -0.73, 0), Color3.fromRGB(170, 170, 165), Enum.Material.Metal)
	-- ถือไม่ได้ (ใช้ทันทีจากช่องของ): ถ้าหลุดเข้าตัวละครก็กลับเข้ากระเป๋า
	tool:GetPropertyChangedSignal("Parent"):Connect(function()
		local char = tool.Parent
		if char and char:IsA("Model") then
			local pl = Players:GetPlayerFromCharacter(char)
			local bp = pl and pl:FindFirstChildOfClass("Backpack")
			if bp then
				task.defer(function()
					tool.Parent = bp
				end)
			end
		end
	end)
	return tool
end

local function giveBattery(player: Player, n: number?): boolean
	local t = batteryTool(player)
	local count = if t then (t:GetAttribute("Count") or 1) else 0
	if count >= MAX_BATTERIES then
		return false
	end
	count = math.min(MAX_BATTERIES, count + (n or 1))
	if not t then
		local bp = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
		if not bp then
			return false
		end
		t = makeBatteryTool()
		t.Parent = bp
	end
	local tt = t :: Tool
	tt:SetAttribute("Count", count)
	print(("🔋 [%s] ได้ถ่านไฟฉาย (มี %d ก้อน)"):format(player.Name, count))
	return true
end

-- ใส่ถ่านได้เมื่อถือไฟฉายอยู่ (กด 1 ก่อน) และถ่านเหลือต่ำกว่าครึ่ง (ผู้ใช้ 2026-11-05) ไม่งั้นบอกเหตุผลในกล่องล่างจอ
local REFILL_BELOW = 0.5
local function notice(player: Player, key: string)
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local n = remotes and remotes:FindFirstChild("Notice")
	if n and n:IsA("RemoteEvent") then
		n:FireClient(player, key, 3)
	end
end
local function useBattery(player: Player)
	local t = batteryTool(player)
	if not t then
		return
	end
	local char = player.Character
	local flash = char and char:FindFirstChild(TOOL_NAME)
	if not (flash and flash:IsA("Tool")) then
		notice(player, "BatteryNeedFlash")
		return
	end
	local b = player:GetAttribute("Battery")
	if type(b) == "number" and b >= REFILL_BELOW then
		notice(player, "BatteryStillHigh")
		return
	end
	local count = (t:GetAttribute("Count") or 1) - 1
	refillEvent:Fire(player, 1)
	if count <= 0 then
		t:Destroy()
	else
		t:SetAttribute("Count", count)
	end
end

task.spawn(function()
	local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
	if not remotes then
		return
	end
	local function remote(name: string): RemoteEvent
		local r = remotes:FindFirstChild(name) :: RemoteEvent?
		if not r then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = remotes
			r = ev
		end
		return r :: RemoteEvent
	end
	local last: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	local function throttled(player: Player): boolean
		if os.clock() - (last[player] or 0) < 0.6 then
			return true
		end
		last[player] = os.clock()
		return false
	end
	-- C->S ใช้ถ่าน 1 ก้อนจากช่องที่ 4
	remote("UseBattery").OnServerEvent:Connect(function(player: Player)
		if not throttled(player) then
			useBattery(player)
		end
	end)
end)

-- ---------------------------------------------------------------- กล่องถ่านไฟฉายบนเคาน์เตอร์ (ที่ซื้อถ่าน)
-- วางระหว่างกระป๋องเงินกับวิทยุ ข้อความปุ่มแปลตามภาษาใน client/HUDController (PROMPTS.BuyBatteryPrompt)
local function buildBatteryBox()
	local ip = workspace:WaitForChild("InteractiveProps", 60)
	if not ip or ip:FindFirstChild("BatteryBox") then
		return
	end
	local counter = workspace:FindFirstChild("CounterTable", true)
	local top = if counter and counter:IsA("BasePart") then counter.Position.Y + counter.Size.Y / 2 else 5.84
	local z = if counter and counter:IsA("BasePart") then counter.Position.Z + 0.3 else 13.3
	local base = CFrame.new(1.2, top, z) * CFrame.Angles(0, math.rad(12), 0)
	local m = Instance.new("Model")
	m.Name = "BatteryBox"
	local function box(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = base * cf
		p.Color = color
		p.Material = mat
		p.Anchored = true
		p.CanCollide = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	-- กล่องกระดาษแข็งเปิดฝา (พื้น + 4 ด้าน)
	local W, D, H, T = 1.3, 0.8, 0.45, 0.05
	local card = Color3.fromRGB(176, 138, 88)
	local floor = box("Floor", Vector3.new(W, T, D), CFrame.new(0, T / 2, 0), card, Enum.Material.Cardboard)
	box("Front", Vector3.new(W, H, T), CFrame.new(0, H / 2, -D / 2), Color3.fromRGB(196, 60, 40), Enum.Material.Cardboard)
	box("Back", Vector3.new(W, H + 0.25, T), CFrame.new(0, (H + 0.25) / 2, D / 2), card, Enum.Material.Cardboard)
	box("Left", Vector3.new(T, H, D), CFrame.new(-W / 2, H / 2, 0), card, Enum.Material.Cardboard)
	box("Right", Vector3.new(T, H, D), CFrame.new(W / 2, H / 2, 0), card, Enum.Material.Cardboard)
	-- ถ่านตั้งเรียงในกล่อง 2 แถว
	for row = 0, 1 do
		for i = 0, 3 do
			local x = -0.45 + i * 0.3
			local zz = -0.16 + row * 0.32
			local c = CFrame.new(x, 0.35, zz) * CFrame.Angles(0, 0, math.rad(90))
			local body = box("Cell", Vector3.new(0.6, 0.24, 0.24), c, Color3.fromRGB(25, 24, 24), Enum.Material.SmoothPlastic)
			body.Shape = Enum.PartType.Cylinder
			local band = box("CellBand", Vector3.new(0.2, 0.25, 0.25), c * CFrame.new(0.16, 0, 0), Color3.fromRGB(190, 32, 28), Enum.Material.SmoothPlastic)
			band.Shape = Enum.PartType.Cylinder
			local tip = box("CellTip", Vector3.new(0.05, 0.09, 0.09), c * CFrame.new(0.32, 0, 0), Color3.fromRGB(205, 205, 200), Enum.Material.Metal)
			tip.Shape = Enum.PartType.Cylinder
		end
	end
	m.PrimaryPart = floor
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyBatteryPrompt"
	prompt.ActionText = "Buy battery"
	prompt.ObjectText = "Battery box"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = floor
	m.Parent = ip
	local last: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any
	prompt.Triggered:Connect(function(player: Player)
		if not FREE_BATTERY or os.clock() - (last[player] or 0) < 0.8 then
			return
		end
		last[player] = os.clock()
		if not giveBattery(player, 1) then
			notice(player, "BatteryFull")
		end
	end)
end
task.spawn(buildBatteryBox)
