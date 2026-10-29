-- Flashlight.server.luau
-- Phase 4: ไฟฉายกบ (StarterPack.FrogFlashlight) หยิบขึ้นมาถือแล้วสว่างทันที (ไม่ต้องคลิกเปิด/ปิด)

local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAME = "FrogFlashlight"

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

local function hook(tool: Instance)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or hooked[tool] then
		return
	end
	hooked[tool] = true
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	-- หยิบขึ้นมาถือ (อยู่ใน Character) = สว่างทันที, เก็บเข้ากระเป๋า = ปิดไฟ
	local isEquipped = tool.Parent ~= nil and tool.Parent:IsA("Model")
	setOn(tool, isEquipped)
	tool.Equipped:Connect(function()
		setOn(tool, true)
	end)
	tool.Unequipped:Connect(function()
		setOn(tool, false)
	end)
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
