--!strict
-- PassShop.client.luau — Lobby: ปุ่มซื้อบนแผงขาย Game Pass (lobby/server/PassStallBuilder)
--   ของที่มีแล้ว: ปุ่มยังขึ้น (กด E ได้ทุกชิ้น ผู้ใช้ 2026-11-23) แต่เปลี่ยนข้อความเป็น "มีแล้ว ✓" เฉพาะเครื่องนี้
--   (เดิมซ่อนปุ่ม: เจ้าของเกมมี Game Pass ทุกอันอัตโนมัติ เลยไม่เห็นปุ่มซื้อเลย)
--   เขียน attribute Action<ภาษา> บนเครื่องนี้ -> shared/Bilingual เปลี่ยนข้อความตามภาษาเอง
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any

local player = Players.LocalPlayer
local stall = workspace:WaitForChild("PassStall", 60)
if not stall then
	return
end

local OWNED = LanguageModule.UI.Shop_OwnedShort
local LANGS = { "TH", "EN", "ID", "PT", "ES" }

local function hook(d: Instance)
	if not d:IsA("ProximityPrompt") then
		return
	end
	local attr = d:GetAttribute("PassAttr")
	if type(attr) ~= "string" then
		return
	end
	local function apply()
		d.Enabled = true
		if player:GetAttribute(attr) == true and d:GetAttribute("OwnedShown") ~= true then
			d:SetAttribute("OwnedShown", true)
			for _, l in ipairs(LANGS) do
				d:SetAttribute("Action" .. l, OWNED[string.lower(l)] or OWNED.en)
			end
		end
	end
	player:GetAttributeChangedSignal(attr):Connect(apply)
	apply()
end
for _, d in ipairs(stall:GetDescendants()) do
	hook(d)
end
stall.DescendantAdded:Connect(hook)
