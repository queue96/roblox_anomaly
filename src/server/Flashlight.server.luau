-- Flashlight.server.luau
-- Phase 4: ไฟฉายกบ (StarterPack.FrogFlashlight) คลิกเพื่อเปิด/ปิด SpotLight
-- Tool.Activated ยิงมาถึง Server เองอยู่แล้ว ไม่ต้องใช้ RemoteEvent; เปิด/ปิดฝั่ง Server ทุกคนจึงเห็นแสงตรงกัน

local Players = game:GetService("Players")

local TOOL_NAME = "FrogFlashlight"
local CLICK_SOUND = "rbxassetid://9117159106" -- เสียงคลิกสวิตช์ (ตัดช่วงต้นของเสียงวิทยุคลิก)

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
	local handle = tool:FindFirstChild("Handle")
	local click: Sound? = nil
	if handle then
		click = Instance.new("Sound")
		click.Name = "Click"
		click.SoundId = CLICK_SOUND
		click.Volume = 0.4
		click.RollOffMaxDistance = 30
		click.Parent = handle
	end
	-- เริ่มแบบเปิดไฟ (ตามค่าเดิมของ SpotLight)
	local first = lightsOf(tool)[1]
	setOn(tool, if first then first.Enabled else true)
	tool.Activated:Connect(function()
		setOn(tool, not tool:GetAttribute("On"))
		if click then
			click.TimePosition = 0
			click:Play()
			task.delay(0.15, function()
				click:Stop()
			end)
		end
	end)
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
