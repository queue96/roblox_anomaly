--!strict
-- PassShop.server.luau — Lobby: แผงขาย Game Pass หน้ารถเข็นขายของ (ShopCart_Main ข้างประตูวัด) (ผู้ใช้ 2026-11-23)
--   ไฟฉายตราช้าง / สวดมนต์ไว / รองเท้าแตะติดปีก ราคา 49 ทุกอัน (รหัสใน shared/RobuxShop)
--   เกมเดียวกับแมพปั๊ม: ซื้อที่นี่แล้วเข้าแมพปั๊มได้ผลทันที (server/RobuxShop.server ในแมพปั๊มเช็กให้ตอนเข้า)
--   ใน Lobby: ตั้ง player attribute ตามที่มี (client/PassShop ซ่อนปุ่มซื้อของที่มีแล้ว) + รองเท้าแตะเดินเร็วขึ้นที่นี่ด้วย

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local IDS = require(Shared:WaitForChild("RobuxShop")) :: any
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any

local function ui(key: string): any
	return LanguageModule.UI[key]
end

local function notice(player: Player, key: string)
	local e = ui(key)
	local remotes = ReplicatedStorage:FindFirstChild("LobbyRemotes")
	local remote = remotes and remotes:FindFirstChild("Notice")
	if e and remote and remote:IsA("RemoteEvent") then
		-- LobbyClient หาภาษาอื่นจาก LanguageModule.UI ด้วยข้อความอังกฤษ
		remote:FireClient(player, e.th, e.en)
	end
end

local function bil(label: TextLabel, key: string)
	local e = ui(key)
	Bilingual.Text(label, e.th, e.en, { id = e.id, pt = e.pt, es = e.es })
end

local function part(props: { [string]: any }, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, key: string, color: Color3, font: Font)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.92, 0.86)
	t.Position = UDim2.fromScale(0.04, 0.07)
	t.FontFace = font
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.Parent = parent
	bil(t, key)
end

local function board(name: string, size: Vector3, cf: CFrame, key: string, parent: Instance, bgColor: Color3, textColor: Color3, stroke: Color3)
	local b = part({ Name = name, Size = size, CFrame = cf, Color = bgColor, Material = Enum.Material.Wood }, parent)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 90
	sg.LightInfluence = 0.3
	sg.Brightness = 1.3
	sg.Parent = b
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = bgColor
	bg.BorderSizePixel = 0
	bg.Parent = sg
	local st = Instance.new("UIStroke")
	st.Color = stroke
	st.Thickness = 5
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = bg
	label(bg, key, textColor, Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold))
	return b
end

-- ---------------------------------------------------------------- ที่ตั้ง: หน้ารถเข็นขายของคันหลัก หันไปทางลานวัด
local lobby = workspace:WaitForChild("TempleLobby", 30)
local cart = lobby and lobby:WaitForChild("ShopCart_Main", 10) :: Model?
local base: CFrame
if cart then
	local pv = cart:GetPivot()
	-- หน้ารถเข็น (ฝั่งป้าย) = -LookVector ของ pivot
	local front = -pv.LookVector
	local at = Vector3.new(pv.X, 0.1, pv.Z) + front * 5.5
	base = CFrame.lookAt(at, at + front)
else
	base = CFrame.lookAt(Vector3.new(14, 0.1, 78.5), Vector3.new(14, 0.1, 78.5) + Vector3.new(-0.707, 0, -0.707))
end

local folder = workspace:FindFirstChild("PassStall") or Instance.new("Folder")
folder.Name = "PassStall"
folder:ClearAllChildren()
folder.Parent = workspace

local WOOD = Color3.fromRGB(92, 64, 42)
local CLOTH = Color3.fromRGB(150, 24, 30)
local GOLD = Color3.fromRGB(214, 170, 60)
local TOP_Y = 3.1
part({ Name = "TableTop", Size = Vector3.new(13.4, 0.3, 2.8), CFrame = base * CFrame.new(0, TOP_Y - 0.15, 0), Color = WOOD, Material = Enum.Material.Wood, CanCollide = true }, folder)
part({ Name = "TableCloth", Size = Vector3.new(13.5, 1.6, 0.06), CFrame = base * CFrame.new(0, TOP_Y - 0.9, -1.42), Color = CLOTH, Material = Enum.Material.Fabric }, folder)
part({ Name = "ClothTrim", Size = Vector3.new(13.5, 0.14, 0.08), CFrame = base * CFrame.new(0, TOP_Y - 0.12, -1.43), Color = GOLD, Material = Enum.Material.Metal }, folder)
for _, x in ipairs({ -6.4, 6.4 }) do
	for _, z in ipairs({ -1.2, 1.2 }) do
		part({ Name = "Leg", Size = Vector3.new(0.3, TOP_Y - 0.3, 0.3), CFrame = base * CFrame.new(x, (TOP_Y - 0.3) / 2, z), Color = WOOD, Material = Enum.Material.Wood, CanCollide = true }, folder)
	end
end
-- ป้ายหัวแผงด้านหลัง
part({ Name = "PostL", Size = Vector3.new(0.25, 4.2, 0.25), CFrame = base * CFrame.new(-6.4, TOP_Y + 2.1, 1.25), Color = WOOD, Material = Enum.Material.Wood }, folder)
part({ Name = "PostR", Size = Vector3.new(0.25, 4.2, 0.25), CFrame = base * CFrame.new(6.4, TOP_Y + 2.1, 1.25), Color = WOOD, Material = Enum.Material.Wood }, folder)
board("TitleBoard", Vector3.new(12.6, 1.3, 0.12), base * CFrame.new(0, TOP_Y + 3.6, 1.25), "PassStallTitle", folder, Color3.fromRGB(40, 22, 14), Color3.fromRGB(245, 214, 120), GOLD)
local lamp = part({ Name = "StallLamp", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = base * CFrame.new(0, TOP_Y + 4.5, 0.6), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon }, folder)
do
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 210, 150)
	l.Brightness = 1.6
	l.Range = 14
	l.Shadows = false
	l.Parent = lamp
end

-- ---------------------------------------------------------------- ของบนโต๊ะ
local function elephantFlashlight(cf: CFrame, parent: Instance)
	local RED = Color3.fromRGB(168, 28, 24)
	local axis = cf * CFrame.new(0, 0.36, 0)
	part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 0.5, 0.5), CFrame = axis * CFrame.new(-0.2, 0, 0), Color = RED, Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.53, 0.53), CFrame = axis * CFrame.new(0.25, 0, 0), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "Neck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 0.65, 0.65), CFrame = axis * CFrame.new(0.66, 0, 0), Color = RED, Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "Head", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.85, 0.85), CFrame = axis * CFrame.new(0.95, 0, 0), Color = Color3.fromRGB(190, 190, 185), Material = Enum.Material.Metal }, parent)
	local lens = part({ Name = "Lens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.05, 0.72, 0.72), CFrame = axis * CFrame.new(1.16, 0, 0), Color = Color3.fromRGB(255, 236, 170), Material = Enum.Material.Neon }, parent)
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Right
	beam.Brightness = 1.5
	beam.Range = 10
	beam.Angle = 40
	beam.Color = Color3.fromRGB(255, 240, 200)
	beam.Parent = lens
end

local function prayerBeads(cf: CFrame, parent: Instance)
	part({ Name = "Cushion", Size = Vector3.new(1.7, 0.22, 1.4), CFrame = cf * CFrame.new(0, 0.11, 0), Color = Color3.fromRGB(170, 30, 36), Material = Enum.Material.Fabric }, parent)
	local center = cf * CFrame.new(0, 0.3, 0)
	local n = 22
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		part({ Name = "Bead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.17, 0.17, 0.17), CFrame = center * CFrame.new(math.cos(a) * 0.55, 0, math.sin(a) * 0.45), Color = Color3.fromRGB(110, 62, 30), Material = Enum.Material.Wood }, parent)
	end
	part({ Name = "GuruBead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.26, 0.26), CFrame = center * CFrame.new(0, 0, -0.5), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "Tassel", Size = Vector3.new(0.12, 0.05, 0.4), CFrame = center * CFrame.new(0, -0.02, -0.75), Color = GOLD, Material = Enum.Material.Fabric }, parent)
	-- ธูปเล็กๆ ปักข้าง ให้รู้ว่าเกี่ยวกับการสวด
	local stick = part({ Name = "Incense", Size = Vector3.new(0.05, 0.9, 0.05), CFrame = cf * CFrame.new(0.65, 0.65, 0.45), Color = Color3.fromRGB(170, 60, 40), Material = Enum.Material.Wood }, parent)
	local tip = part({ Name = "IncenseTip", Size = Vector3.new(0.07, 0.07, 0.07), CFrame = stick.CFrame * CFrame.new(0, 0.46, 0), Color = Color3.fromRGB(255, 90, 30), Material = Enum.Material.Neon }, parent)
	local smoke = Instance.new("Smoke")
	smoke.Size = 0.2
	smoke.RiseVelocity = 1.2
	smoke.Opacity = 0.08
	smoke.Color = Color3.fromRGB(220, 220, 220)
	smoke.Parent = tip
end

local function sandals(cf: CFrame, parent: Instance)
	-- สีน้ำตาลไม้ + สายแดง + ปีกทองเล็กๆ ข้างสาย (ไม่ใช้ขาว-น้ำเงินแบบรองเท้าแตะยี่ห้อดัง)
	local SOLE = Color3.fromRGB(120, 78, 44)
	local STRAP = Color3.fromRGB(176, 34, 30)
	local WING = Color3.fromRGB(232, 196, 90)
	for i, side in ipairs({ -0.38, 0.38 }) do
		local s = cf * CFrame.new(side, 0, 0) * CFrame.Angles(0, math.rad(if i == 1 then 8 else -8), 0)
		part({ Name = "Sole", Size = Vector3.new(0.55, 0.14, 1.35), CFrame = s * CFrame.new(0, 0.07, 0), Color = SOLE, Material = Enum.Material.Rubber }, parent)
		part({ Name = "Bottom", Size = Vector3.new(0.56, 0.06, 1.36), CFrame = s * CFrame.new(0, 0.02, 0), Color = Color3.fromRGB(70, 44, 24), Material = Enum.Material.Rubber }, parent)
		local post = s * CFrame.new(0, 0.14, -0.38)
		part({ Name = "ToePost", Size = Vector3.new(0.06, 0.12, 0.06), CFrame = post * CFrame.new(0, 0.06, 0), Color = STRAP, Material = Enum.Material.Rubber }, parent)
		for _, dir in ipairs({ -1, 1 }) do
			local mid = post * CFrame.new(dir * 0.14, 0.1, 0.22)
			part({ Name = "Strap", Size = Vector3.new(0.07, 0.07, 0.55), CFrame = mid * CFrame.Angles(math.rad(-12), math.rad(dir * 28), 0), Color = STRAP, Material = Enum.Material.Rubber }, parent)
		end
		-- ปีกเล็กๆ กางออกข้างสายทั้งสองฝั่ง (3 ขนต่อข้าง)
		for _, dir in ipairs({ -1, 1 }) do
			for k = 0, 2 do
				local w = s * CFrame.new(dir * (0.36 + k * 0.05), 0.24 + k * 0.05, 0.05 + k * 0.1) * CFrame.Angles(math.rad(-20 - k * 12), 0, math.rad(dir * (35 + k * 10)))
				part({ Name = "Feather", Size = Vector3.new(0.05, 0.36 - k * 0.07, 0.14), CFrame = w, Color = WING, Material = Enum.Material.Metal }, parent)
			end
		end
	end
end

-- สมุดหมอผี: สมุดปกหนังดำมุมทอง วางบนผ้ายันต์แดง มีเทียนเล่มเล็ก
local function ghostBook(cf: CFrame, parent: Instance)
	part({ Name = "Cloth", Size = Vector3.new(1.9, 0.04, 1.5), CFrame = cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, math.rad(6), 0), Color = Color3.fromRGB(160, 28, 26), Material = Enum.Material.Fabric }, parent)
	local book = cf * CFrame.new(-0.1, 0, 0) * CFrame.Angles(0, math.rad(-12), 0)
	part({ Name = "Pages", Size = Vector3.new(1.15, 0.24, 1.5), CFrame = book * CFrame.new(0, 0.16, 0), Color = Color3.fromRGB(214, 196, 150), Material = Enum.Material.SmoothPlastic }, parent)
	part({ Name = "CoverBottom", Size = Vector3.new(1.25, 0.05, 1.6), CFrame = book * CFrame.new(0, 0.05, 0), Color = Color3.fromRGB(26, 20, 18), Material = Enum.Material.Leather }, parent)
	part({ Name = "CoverTop", Size = Vector3.new(1.25, 0.05, 1.6), CFrame = book * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(26, 20, 18), Material = Enum.Material.Leather }, parent)
	part({ Name = "Spine", Size = Vector3.new(0.08, 0.3, 1.6), CFrame = book * CFrame.new(-0.62, 0.17, 0), Color = Color3.fromRGB(20, 16, 14), Material = Enum.Material.Leather }, parent)
	for _, z in ipairs({ -0.7, 0.7 }) do
		part({ Name = "Corner", Size = Vector3.new(0.22, 0.06, 0.16), CFrame = book * CFrame.new(0.52, 0.32, z), Color = GOLD, Material = Enum.Material.Metal }, parent)
	end
	-- ยันต์บนปก (วงทอง + จุดแดงเรือง)
	part({ Name = "Seal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.03, 0.62, 0.62), CFrame = book * CFrame.new(0.05, 0.33, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Metal }, parent)
	part({ Name = "SealCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.035, 0.3, 0.3), CFrame = book * CFrame.new(0.05, 0.335, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 30, 24), Material = Enum.Material.Neon }, parent)
	local candle = part({ Name = "Candle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.16, 0.16), CFrame = cf * CFrame.new(0.72, 0.27, 0.48) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(236, 228, 208), Material = Enum.Material.SmoothPlastic }, parent)
	local flame = part({ Name = "Flame", Shape = Enum.PartType.Ball, Size = Vector3.new(0.09, 0.14, 0.09), CFrame = candle.CFrame * CFrame.new(0.3, 0, 0), Color = Color3.fromRGB(255, 170, 60), Material = Enum.Material.Neon }, parent)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 150, 70)
	l.Brightness = 0.8
	l.Range = 5
	l.Parent = flame
end

type Item = { attr: string, passId: number, sign: string, name: string, buy: string?, build: (CFrame, Instance) -> () }
local ITEMS: { Item } = {
	{ attr = "ElephantLight", passId = IDS.ElephantPassId, sign = "ElephantSign", name = "ElephantName", build = elephantFlashlight },
	{ attr = "FastPrayer", passId = IDS.FastPrayPassId, sign = "FastPraySign", name = "FastPrayName", build = prayerBeads },
	{ attr = "WingSandals", passId = IDS.SandalsPassId, sign = "SandalsSign", name = "SandalsName", build = sandals },
	{ attr = "GhostBook", passId = IDS.GhostBookPassId, sign = "GhostBookSign", name = "GhostBookName", buy = "BuyGhostBook", build = ghostBook },
}
local GOT = { ElephantLight = "Shop_ElephantGot", FastPrayer = "Shop_FastPrayGot", WingSandals = "Shop_SandalsGot", GhostBook = "Shop_GhostBookGot", BigRoom = "Shop_BigRoomGot" }

-- ป้ายทอง "📖 หมอผี" ใน Lobby เป็นแถวบนสุดของป้ายชื่อ (lobby/server/LobbyNameplates)
local prompts: { [ProximityPrompt]: Item } = {}
for i, item in ipairs(ITEMS) do
	local x = (i - (#ITEMS + 1) / 2) * 3.25
	local spot = base * CFrame.new(x, TOP_Y, 0.15)
	local m = Instance.new("Model")
	m.Name = "Pass_" .. item.attr
	m.Parent = folder
	item.build(spot, m)
	-- ป้ายราคาตั้งเอียงหน้าของ
	board("PriceCard", Vector3.new(2.9, 1.25, 0.06), spot * CFrame.new(0, 0.62, -1.0) * CFrame.Angles(math.rad(-14), 0, 0), item.sign, m, Color3.fromRGB(240, 228, 200), Color3.fromRGB(60, 22, 16), CLOTH)
	-- จุดติดปุ่มกด (มองไม่เห็น)
	local anchor = part({ Name = "PromptAnchor", Size = Vector3.new(2.4, 1.2, 1.6), CFrame = spot * CFrame.new(0, 0.6, 0), Transparency = 1, CanQuery = false }, m)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "BuyPassPrompt"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr:SetAttribute("PassAttr", item.attr)
	pr.Parent = anchor
	local buy, nm = ui(item.buy or "BuyElephant"), ui(item.name)
	Bilingual.Prompt(pr, buy.th, buy.en, nm.th, nm.en, {
		id = { buy.id, nm.id },
		pt = { buy.pt, nm.pt },
		es = { buy.es, nm.es },
	})
	prompts[pr] = item
end

-- ---------------------------------------------------------------- เจ้าของ Game Pass
local function applySandals(player: Player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = game:GetService("StarterPlayer").CharacterWalkSpeed * (if player:GetAttribute("WingSandals") == true then IDS.SANDALS_SPEED else 1)
	end
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("WingSandals"):Connect(function()
		applySandals(player)
	end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		applySandals(player)
	end)
	-- ทุก Game Pass (รวมห้องใหญ่ที่ไม่ได้วางบนแผง: ขายตรงหน้าตั้งห้อง)
	for _, item in ipairs(IDS.PASSES) do
		if item.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, item.id)
			if ok and owns then
				player:SetAttribute(item.attr, true)
			end
		end
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

for pr, item in pairs(prompts) do
	pr.Triggered:Connect(function(player: Player)
		if player:GetAttribute(item.attr) == true then
			notice(player, "Shop_Owned")
			return
		end
		if item.passId == 0 then
			warn("[PassShop] ยังไม่ได้ใส่รหัส Game Pass ของ " .. item.attr .. " ใน shared/RobuxShop")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, item.passId)
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, item in ipairs(IDS.PASSES) do
		if item.id == passId then
			player:SetAttribute(item.attr, true)
			notice(player, GOT[item.attr])
		end
	end
end)
