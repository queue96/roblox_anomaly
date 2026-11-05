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
