--!strict
-- RobuxShop.client.luau — ฝั่งเครื่องผู้เล่นของร้านค้า Robux (ระบบหลัก server/RobuxShop.server)
--   ปุ่มที่ไฟฉายตราช้างบนเคาน์เตอร์: ข้อความต่างกันแต่ละคน (ตั้งเฉพาะเครื่องนี้)
--     ไม่มี Pass = "ซื้อ ⏣49" · มี Pass ยังใช้ไฟฉายกบ = "หยิบไฟฉายตราช้าง" · ใช้อยู่ = "กลับไปใช้ไฟฉายกบ"
--   StreamingEnabled: ปุ่มอาจมาถึงทีหลัง -> ตั้งข้อความทุกครั้งที่ปุ่มโผล่ (PromptShown) และเมื่อสถานะเปลี่ยน

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any
local PROMPT_NAME = "BuyElephantPrompt"

local function ui(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize(player:GetAttribute("Lang") :: string?))
end

local known: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function apply(prompt: ProximityPrompt)
	prompt.AutoLocalize = false
	local own = player:GetAttribute("ElephantLight") == true
	local using = own and player:GetAttribute("ElephantInUse") == true
	prompt.ActionText = ui(if not own then "BuyElephant" elseif using then "ElephantReturn" else "ElephantPick")
	prompt.ObjectText = ui("ElephantName")
	known[prompt] = true
end
local function applyAll()
	for p in pairs(known) do
		if p.Parent then
			apply(p)
		end
	end
end

ProximityPromptService.PromptShown:Connect(function(p: ProximityPrompt)
	if p.Name == PROMPT_NAME then
		apply(p)
	end
end)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") and d.Name == PROMPT_NAME then
		apply(d)
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") and d.Name == PROMPT_NAME then
		apply(d)
	end
end
for _, a in ipairs({ "ElephantLight", "ElephantInUse", "Lang" }) do
	player:GetAttributeChangedSignal(a):Connect(applyAll)
end
