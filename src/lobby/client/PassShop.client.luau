--!strict
-- PassShop.client.luau — Lobby: ซ่อนปุ่มซื้อของที่มีแล้วเฉพาะเครื่องนี้ (แผงขาย Game Pass จาก lobby/server/PassShop)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local stall = workspace:WaitForChild("PassStall", 60)
if not stall then
	return
end

local function hook(d: Instance)
	if not d:IsA("ProximityPrompt") then
		return
	end
	local attr = d:GetAttribute("PassAttr")
	if type(attr) ~= "string" then
		return
	end
	local function apply()
		d.Enabled = player:GetAttribute(attr) ~= true
	end
	player:GetAttributeChangedSignal(attr):Connect(apply)
	apply()
end
for _, d in ipairs(stall:GetDescendants()) do
	hook(d)
end
stall.DescendantAdded:Connect(hook)
