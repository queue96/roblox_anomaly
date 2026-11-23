-- Flashlight.server.luau
-- Phase 4: ไฟฉายกบ (StarterPack.FrogFlashlight) หยิบขึ้นมาถือแล้วสว่างทันที (ไม่ต้องคลิกเปิด/ปิด)
-- ถ่านไฟฉาย: player attribute "Battery" (0-1) ลดลงตอนไฟเปิดอยู่ในมือ และชาร์จคืนเองเรื่อยๆ ตอนไม่ได้ส่อง
--   (ผู้ใช้ 2026-11-13: ตัดระบบกล่องถ่าน/ช่องถ่านออก ให้แบตรีเอง)
--   หมดตอนถืออยู่ = ไฟดับ (tool attribute On = false) แล้วชาร์จคืนในมือได้ สว่างอีกครั้งเมื่อถึง RELIGHT_AT
--   ใกล้หมด HUD กะพริบไฟ (HUDController)
-- admin: game.ServerStorage.FlashlightRefill:Fire(player, 1)   -- 1 = เต็ม, 0.5 = ครึ่ง (รวมไม่เกินเต็ม)

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAME = "FrogFlashlight"
local RunService = game:GetService("RunService")
local DRAIN_TIME = 100 -- วินาทีที่ถ่านเต็มเปิดส่องได้ต่อเนื่อง
local RECHARGE_TIME = 45 -- วินาทีที่ชาร์จจาก 0 จนเต็ม (ตอนเก็บไฟฉาย หรือถืออยู่แต่ไฟดับเพราะหมด)
local RELIGHT_AT = 0.2 -- หมดแล้วชาร์จในมือจนถึงเท่านี้ = ไฟติดเอง (ไม่กะพริบติด-ดับตรงขอบ 0)

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
	-- ไฟฉายตราช้าง: กระจกหน้าเรืองแสงตอนเปิด / แผงข้างเรืองแสงตอนเปิด
	local eLens = tool:FindFirstChild("ElephantLens", true)
	if eLens and eLens:IsA("BasePart") then
		eLens.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		eLens.Transparency = if on then 0 else 0.35
	end
	local ePanel = tool:FindFirstChild("ElephantSidePanel", true)
	if ePanel and ePanel:IsA("BasePart") then
		ePanel.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		ePanel.Color = if on then Color3.fromRGB(235, 240, 255) else Color3.fromRGB(150, 152, 158)
	end
	tool:SetAttribute("On", on)
end

-- ---------------------------------------------------------------- หน้าตาไฟฉายตราช้าง (Game Pass)
-- เจ้าของที่หยิบมาใช้แล้ว (player attribute ElephantInUse จากเคาน์เตอร์ server/RobuxShop) ถือโมเดลไฟฉายตราช้างแทนไฟฉายกบ: ซ่อนชิ้นกบ แล้วเชื่อมโมเดลใหม่กับ Handle
--   มือกำกลางคานหูหิ้ว (ไฟฉายกบ: มือกำที่ Handle + 0.3 ตามแกน ดู HUDController.FLASHLIGHT_GRIP_BACK) ตัวไฟฉายห้อยใต้มือ
--   ไฟ (BeamLight) ย้ายไปติดกระจกหน้า · ยังไม่ได้ Import โมเดล (ไม่มีแม่แบบใน ServerStorage) = ไฟฉายกบเหมือนเดิม
--   tool attribute Skin = "Elephant": client/HUDController สร้างไฟฉายมุมมองบุคคลที่หนึ่งใหม่เมื่อค่านี้เปลี่ยน
local RobuxShop = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RobuxShop")) :: any
local GRIP_BACK = 0.3
local FROG_PARTS = { "FlashlightModel", "FlashlightLens" }
local function ownerOf(tool: Tool): Player?
	local par = tool.Parent
	if not par then
		return nil
	end
	if par:IsA("Backpack") then
		local p = par.Parent
		return if p and p:IsA("Player") then p else nil
	end
	return Players:GetPlayerFromCharacter(par)
end
local function applySkin(tool: Tool)
	local owner = ownerOf(tool)
	if not owner then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	local want = owner:GetAttribute("ElephantLight") == true and owner:GetAttribute("ElephantInUse") == true and RobuxShop.ElephantTemplate() ~= nil
	local has = tool:GetAttribute("Skin") == "Elephant"
	if want == has then
		return
	end
	if want then
		local folder = Instance.new("Folder")
		folder.Name = "ElephantSkin"
		folder.Parent = handle
		local mainCF = handle.CFrame * CFrame.new(0, 0, GRIP_BACK) * CFrame.new(-RobuxShop.ELEPHANT_GRIP)
		local parts = RobuxShop.PlaceElephant(mainCF, 1, folder)
		if not parts then
			folder:Destroy()
			return
		end
		for _, p in pairs(parts) do
			p.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end
		for _, n in ipairs(FROG_PARTS) do
			local fp = handle:FindFirstChild(n)
			if fp and fp:IsA("BasePart") then
				fp:SetAttribute("SkinBaseTransparency", fp.Transparency)
				fp.Transparency = 1
			end
		end
		local lens = parts.ElephantLens
		if lens then
			for _, l in ipairs(handle:GetChildren()) do
				if l:IsA("Light") then
					l.Parent = lens
				end
			end
		end
		tool:SetAttribute("Skin", "Elephant")
	else
		local folder = handle:FindFirstChild("ElephantSkin")
		if folder then
			for _, l in ipairs(folder:GetDescendants()) do
				if l:IsA("Light") then
					l.Parent = handle
				end
			end
			folder:Destroy()
		end
		for _, n in ipairs(FROG_PARTS) do
			local fp = handle:FindFirstChild(n)
			if fp and fp:IsA("BasePart") then
				fp.Transparency = (fp:GetAttribute("SkinBaseTransparency") :: number?) or 0
			end
		end
		tool:SetAttribute("Skin", nil)
	end
	setOn(tool, tool:GetAttribute("On") == true)
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

-- ไฟฉายตราช้าง (server/RobuxShop): ไฟบนตัวไฟฉายที่คนอื่นเห็นส่องไกลขึ้น สว่างขึ้น
local function applyElephant(tool: Tool, owner: Player?)
	local on = owner ~= nil and owner:GetAttribute("ElephantLight") == true and owner:GetAttribute("ElephantInUse") == true
	for _, l in ipairs(lightsOf(tool)) do
		if l:GetAttribute("BaseRange") == nil then
			l:SetAttribute("BaseRange", (l :: any).Range)
			l:SetAttribute("BaseBrightness", l.Brightness)
		end
		local range = l:GetAttribute("BaseRange") :: number
		local bright = l:GetAttribute("BaseBrightness") :: number
		(l :: any).Range = if on then math.min(60, range * 1.7) else range
		l.Brightness = if on then bright * 1.6 else bright
	end
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
		applySkin(tool)
		setOn(tool, inHand and (not p or (p:GetAttribute("Battery") or 1) > 0))
		applyElephant(tool, p)
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
	local function onElephantChanged()
		local char = player.Character
		local tool = char and char:FindFirstChild(TOOL_NAME)
		if tool and tool:IsA("Tool") then
			applyElephant(tool, player)
		end
		-- หน้าตา: ไฟฉายในมือหรือในกระเป๋า
		local holders: { Instance } = {}
		if player.Character then
			table.insert(holders, player.Character)
		end
		local bp = player:FindFirstChildOfClass("Backpack")
		if bp then
			table.insert(holders, bp)
		end
		for _, holder in ipairs(holders) do
			local t = holder:FindFirstChild(TOOL_NAME)
			if t and t:IsA("Tool") then
				applySkin(t)
			end
		end
	end
	player:GetAttributeChangedSignal("ElephantLight"):Connect(onElephantChanged)
	player:GetAttributeChangedSignal("ElephantInUse"):Connect(onElephantChanged)
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
		if p:GetAttribute("ElephantLight") == true and p:GetAttribute("ElephantInUse") == true then
			b = 1 -- ไฟฉายตราช้าง (server/RobuxShop): ถ่านไม่มีวันหมด
			if tool and tool:IsA("Tool") and not tool:GetAttribute("On") then
				setOn(tool, true)
			end
		elseif tool and tool:IsA("Tool") and tool:GetAttribute("On") then
			b = math.max(0, b - step / DRAIN_TIME)
			if b <= 0 then
				setOn(tool, false) -- ถ่านหมด
			end
		else
			b = math.min(1, b + step / RECHARGE_TIME)
			if tool and tool:IsA("Tool") and b >= RELIGHT_AT then
				setOn(tool, true) -- หมดในมือ ชาร์จพอแล้ว สว่างอีกครั้ง
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

