-- ObjectLabels.client.luau
-- ป้ายชื่อที่ลอยตามวัตถุในฉาก (BillboardGui "ZoneLabel" ที่ทำไว้ตอนสร้างฉาก)
-- ฝั่ง Client เปลี่ยนหน้าตาให้เรียบ: ชื่อสั้นๆ ตามภาษาผู้เล่น ไม่มีอีโมจิ/คำอธิบาย ไม่มีพื้นหลัง เห็นเฉพาะตอนเดินเข้าใกล้
--   ป้ายของผีหรือจุดช่วยของ Dev (เช่น ผีตานี เงาหลังต้นไทร StopPoint) ซ่อนตลอด ไม่ให้ผู้เล่นรู้ล่วงหน้า
--   ซ่อนทั้งหมดได้จากหน้าตั้งค่า (Attribute ShowLabels)
-- ของใน Edit mode ไม่ถูกแตะ (แก้เฉพาะสำเนาบนเครื่องผู้เล่น)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))

-- ชื่อ Instance (ตัวป้ายเองหรือบรรพบุรุษ) -> คีย์ใน LanguageModule.Labels  /  false = ซ่อนตลอด
local LABEL_FOR: { [string]: string | boolean } = {
	DieselPump = "DieselPump", -- ก่อน GasPump: ตู้ดีเซล Clone มาจากตู้ 1 (ข้างในมีชิ้นชื่อ GasPump)
	GasPump = "GasPump",
	Radio = "Radio",
	CutoutSwitch = "CutoutSwitch",
	RejectRope = "RejectRope",
	MoneyTin = "MoneyTin",
	Generator = "Generator",
	AirCompressor = "AirCompressor",
	SpiritHouse = "SpiritHouse",
	KilometerMilestone = "KilometerMilestone",
	DistantRiceHut = "DistantRiceHut",
	OldMarbleBenchSet = "MarbleBench",
	SacredBanyanTree = "BanyanTree",
	IceBox = "IceBox",
	TinOuthouse = "Outhouse",
	OldMirror = "Mirror",
	OwnerPhoto = "OwnerPhoto",
	Scarecrow = "Scarecrow",
	-- ซ่อนตลอด
	PhiTaniGhost = false,
	BanyanShadowAnomaly = false,
	VehicleWaypoints = false,
}

local CREAM = Color3.fromRGB(226, 218, 198)
local FONT = Font.fromEnum(Enum.Font.SpecialElite)

local labels: { [BillboardGui]: { key: string?, text: TextLabel? } } = {}

local function lookup(gui: BillboardGui): string | boolean | nil
	local node: Instance? = gui.Parent
	while node and node ~= Workspace do
		local v = LABEL_FOR[node.Name]
		if v ~= nil then
			return v
		end
		node = node.Parent
	end
	return nil
end

local function render(gui: BillboardGui)
	local info = labels[gui]
	if not info then
		return
	end
	local show = info.key ~= nil and localPlayer:GetAttribute("ShowLabels") ~= false
	gui.Enabled = show
	if info.text and info.key then
		info.text.Text = LanguageModule.GetLabel(info.key, LanguageModule.Normalize(localPlayer:GetAttribute("Lang") :: string?))
	end
end

local function restyle(d: Instance)
	if not (d:IsA("BillboardGui") and d.Name == "ZoneLabel") or labels[d] then
		return
	end
	local gui = d :: BillboardGui
	local key = lookup(gui)
	if type(key) ~= "string" then
		labels[gui] = { key = nil } -- ไม่รู้จัก / ป้ายผี -> ซ่อน
		render(gui)
		return
	end
	gui:ClearAllChildren()
	gui.AutoLocalize = false
	gui.Size = UDim2.new(0, 200, 0, 24)
	gui.MaxDistance = 24 -- เห็นเฉพาะตอนเข้าใกล้
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = FONT
	t.TextSize = 15
	t.TextColor3 = CREAM
	t.TextTransparency = 0.1
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = t
	labels[gui] = { key = key, text = t }
	render(gui)
end

local function renderAll()
	for gui in pairs(labels) do
		if gui.Parent then
			render(gui)
		else
			labels[gui] = nil
		end
	end
end

for _, d in ipairs(Workspace:GetDescendants()) do
	restyle(d)
end
Workspace.DescendantAdded:Connect(restyle)
localPlayer:GetAttributeChangedSignal("ShowLabels"):Connect(renderAll)
localPlayer:GetAttributeChangedSignal("Lang"):Connect(renderAll)
