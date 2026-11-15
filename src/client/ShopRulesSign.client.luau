--!strict
-- ShopRulesSign.client.luau
-- ป้ายกฎการเฝ้าร้านข้างฝาในเพิง (shared/MapBuilder buildShopRules, SurfaceGui tag "ShopRulesSign")
--   ข้อความตามภาษาผู้เล่น (attribute "Lang" เปลี่ยนได้ในหน้าตั้งค่า) จาก LanguageModule.UI ShopRules_*
--   ตัวหนังสือล้นกระดาษ (ภาษาอังกฤษยาวกว่า) = ย่อทุกบรรทัดลงทีละ 1 จนพอดี
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any
local player = Players.LocalPlayer

local function apply(gui: Instance)
	local body = gui:FindFirstChild("Body") :: Frame?
	local layout = body and body:FindFirstChildOfClass("UIListLayout")
	if not (body and layout) then
		return
	end
	local lang = LanguageModule.Normalize(player:GetAttribute("Lang") :: string?)
	local labels: { TextLabel } = {}
	for _, l in ipairs(body:GetChildren()) do
		if l:IsA("TextLabel") then
			l.Text = LanguageModule.GetUI(l.Name, lang)
			l.TextSize = (l:GetAttribute("BaseSize") :: number?) or l.TextSize
			table.insert(labels, l)
		end
	end
	task.spawn(function()
		for _ = 1, 16 do
			RunService.Heartbeat:Wait() -- รอ layout คำนวณขนาดใหม่
			local room = body.AbsoluteSize.Y * 0.91 -- หัก UIPadding บน 5% ล่าง 4%
			if room <= 0 or layout.AbsoluteContentSize.Y <= room then
				return
			end
			for _, l in ipairs(labels) do
				l.TextSize = math.max(12, l.TextSize - 1)
			end
		end
	end)
end

for _, g in ipairs(CollectionService:GetTagged("ShopRulesSign")) do
	apply(g)
end
CollectionService:GetInstanceAddedSignal("ShopRulesSign"):Connect(apply)
player:GetAttributeChangedSignal("Lang"):Connect(function()
	for _, g in ipairs(CollectionService:GetTagged("ShopRulesSign")) do
		apply(g)
	end
end)
