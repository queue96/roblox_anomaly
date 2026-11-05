--!strict
-- Bilingual.luau (ReplicatedStorage.Shared) — ข้อความที่ Server สร้าง (ป้าย 3D / ปุ่มกด) แต่ต้องแสดงตามภาษาของแต่ละคน
--   Server:  Bilingual.Text(label, "ไทย", "English")                 ตั้งทั้งสองภาษาไว้ใน attribute (Text ตั้งเป็นไทยไว้ก่อน)
--            Bilingual.Prompt(prompt, "ทำ", "Do", "ของ", "Thing")    ActionText / ObjectText ของ ProximityPrompt
--   Client:  Bilingual.Run()  ติดครั้งเดียวต่อเครื่อง: ทุกชิ้นที่ติด tag เปลี่ยนเป็นภาษาของผู้เล่น (attribute Lang) และเปลี่ยนตามทันที
-- (Server ตั้ง Text ทีเดียวทุกคนเห็นเหมือนกัน -> ต้องให้ Client เขียนทับเฉพาะเครื่องตัวเอง)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TAG = "Bilingual"

local Bilingual = {}

function Bilingual.Text(inst: Instance, th: string, en: string)
	(inst :: any).Text = th
	inst:SetAttribute("TextTH", th)
	inst:SetAttribute("TextEN", en)
	CollectionService:AddTag(inst, TAG)
end

function Bilingual.Prompt(p: ProximityPrompt, actionTH: string, actionEN: string, objectTH: string?, objectEN: string?)
	p.ActionText = actionTH
	if objectTH then
		p.ObjectText = objectTH
	end
	p:SetAttribute("ActionTH", actionTH)
	p:SetAttribute("ActionEN", actionEN)
	if objectTH then
		p:SetAttribute("ObjectTH", objectTH)
		p:SetAttribute("ObjectEN", objectEN or objectTH)
	end
	CollectionService:AddTag(p, TAG)
end

local running = false
function Bilingual.Run()
	if running or not RunService:IsClient() then
		return
	end
	running = true
	local player = Players.LocalPlayer
	local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any
	local function th(): boolean
		return LanguageModule.Normalize((player:GetAttribute("Lang") :: string?) or player.LocaleId) == "th"
	end
	local function apply(inst: Instance)
		local isTH = th()
		if inst:IsA("ProximityPrompt") then
			inst.AutoLocalize = false
			local a = inst:GetAttribute(if isTH then "ActionTH" else "ActionEN")
			if type(a) == "string" then
				inst.ActionText = a
			end
			local o = inst:GetAttribute(if isTH then "ObjectTH" else "ObjectEN")
			if type(o) == "string" then
				inst.ObjectText = o
			end
		elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
			inst.AutoLocalize = false
			local t = inst:GetAttribute(if isTH then "TextTH" else "TextEN")
			if type(t) == "string" then
				inst.Text = t
			end
		end
	end
	local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function hook(inst: Instance)
		apply(inst)
		if hooked[inst] then
			return
		end
		hooked[inst] = true
		-- Server เปลี่ยนข้อความ (เช่น ป้ายห้องนับถอยหลัง) = attribute เปลี่ยน -> เขียนทับใหม่
		inst.AttributeChanged:Connect(function()
			apply(inst)
		end)
		-- Server ตั้ง Text ใหม่ (ค่าไทย) ทับของเรา -> เขียนกลับเป็นภาษาของเรา (ค่าเท่ากันแล้วไม่วนซ้ำ)
		for _, prop in ipairs(if inst:IsA("ProximityPrompt") then { "ActionText", "ObjectText" } else { "Text" }) do
			inst:GetPropertyChangedSignal(prop):Connect(function()
				task.defer(apply, inst)
			end)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
		hook(inst)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(hook)
	player:GetAttributeChangedSignal("Lang"):Connect(function()
		for _, inst in ipairs(CollectionService:GetTagged(TAG)) do
			apply(inst)
		end
	end)
end

return Bilingual
