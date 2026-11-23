--!strict
-- RobuxShop.client.luau — ฝั่งเครื่องผู้เล่นของร้านค้า Robux (ระบบหลัก server/RobuxShop.server)
--   มีไฟฉายตราช้างแล้ว: ซ่อนปุ่มซื้อที่ขาตั้งโชว์เฉพาะเครื่องนี้ (คนอื่นที่ยังไม่มียังเห็นปุ่ม)

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local shop = workspace:WaitForChild("RobuxShop", 60)
if not shop then
	return
end
local display = shop:WaitForChild("ElephantFlashlightDisplay", 30)
local prompt = display and display:FindFirstChild("BuyElephantPrompt", true) :: ProximityPrompt?
if not prompt then
	return
end
local buy = prompt :: ProximityPrompt

local function apply()
	buy.Enabled = player:GetAttribute("ElephantLight") ~= true
end
player:GetAttributeChangedSignal("ElephantLight"):Connect(apply)
apply()
