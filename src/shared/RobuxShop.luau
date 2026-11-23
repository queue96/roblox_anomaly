--!strict
-- RobuxShop.luau — รหัสสินค้า Robux (เกมเดียวกัน universe 10772011031: ซื้อที่ Lobby ได้ผลในแมพปั๊ม)
--   แมพปั๊ม: server/RobuxShop.server (ขาตั้งไฟฉาย / ป้ายผี / ต่อธูป + ให้ผลของ Game Pass ทุกอัน)
--   Lobby:   lobby/server/PassShop.server (แผงขาย Game Pass หน้ารถเข็นขายของ)
--   0 = ยังไม่ได้สร้างใน Creator Hub: ปุ่มซื้อยังขึ้น แต่กดแล้วเตือนใน Output แทนการเปิดหน้าซื้อ
local M = {
	-- Game Pass (ซื้อครั้งเดียว ได้ตลอดไป) 49 Robux ทุกอัน
	ElephantPassId = 2092614961, -- ไฟฉายตราช้าง: ส่องไกล สว่าง ถ่านไม่หมด
	FastPrayPassId = 2092410992, -- สวดมนต์ไว: พนมมือเปิดตาทิพย์ 1.5 -> 0.9 วิ
	SandalsPassId = 2092603080, -- รองเท้าแตะติดปีก: เดินเร็วขึ้น 15%
	BigRoomPassId = 2096527027, -- ห้องใหญ่ 99: คนสร้างห้องเลือกได้ถึง 6 คน (ฟรี FREE_ROOM_SIZE) เพื่อนที่เข้าไม่ต้องมี
	GhostBookPassId = 2092681074, -- สมุดหมอผี 499: เรียกผีได้เอง (client/GhostBook + server/GhostBook)
	-- Developer Product 19 Robux (แมพปั๊มเท่านั้น)
	PrankProductId = 3735073122, -- ป้ายผีหลอกทุกคนในห้อง (ยกเว้นคนซื้อ)
	IncenseProductId = 3735073225, -- ต่อธูป 1 ดอก (ไม่เกินจำนวนเริ่ม)
	-- รูปบนป้ายผี (Decal / Image ที่อัปโหลดแล้ว)
	PosterImage = "rbxassetid://100252335354240", -- ป้ายผีหน้าหลอนผมยาว ไม่มีเลือด/อวัยวะ (ตัวเก่า 114833548723474 โดน Roblox ลบเพราะมีไส้ 2026-11-23)

	FAST_SIGHT_DELAY = 0.9, -- วินาที (ปกติ 1.5 ใน client/PrayerController)
	SANDALS_SPEED = 1.15, -- คูณความเร็วเดินปกติ
	FREE_ROOM_SIZE = 4, -- ห้องปกติ (ไม่มี Pass ห้องใหญ่) เล่นได้สูงสุดกี่คน · สูงสุดจริง = shared/Difficulty.MaxPlayers
	BOOK_COOLDOWN = 60, -- วินาทีระหว่างการเรียกผีจากสมุดหมอผี (ต่อคน)
}

-- Game Pass -> player attribute ที่ระบบในเกมอ่าน / ชื่อของใน LanguageModule.UI
M.PASSES = {
	{ id = M.ElephantPassId, attr = "ElephantLight", name = "ElephantName" },
	{ id = M.FastPrayPassId, attr = "FastPrayer", name = "FastPrayName" },
	{ id = M.SandalsPassId, attr = "WingSandals", name = "SandalsName" },
	{ id = M.GhostBookPassId, attr = "GhostBook", name = "GhostBookName" },
	{ id = M.BigRoomPassId, attr = "BigRoom", name = "BigRoomName" },
}

-- เมนู SHOP ซ้ายจอใน Lobby (lobby/client/ShopMenu): ลำดับ / ไอคอน / คำอธิบาย / ราคาสำรอง (ราคาจริงอ่านจาก Roblox)
M.SHOP_PASSES = {
	{ id = M.GhostBookPassId, attr = "GhostBook", name = "GhostBookName", desc = "GhostBookDesc", icon = "📖", price = 499 },
	{ id = M.ElephantPassId, attr = "ElephantLight", name = "ElephantName", desc = "ElephantDesc", icon = "🔦", price = 49 },
	{ id = M.BigRoomPassId, attr = "BigRoom", name = "BigRoomName", desc = "BigRoomDesc", icon = "👥", price = 99 },
	{ id = M.FastPrayPassId, attr = "FastPrayer", name = "FastPrayName", desc = "FastPrayDesc", icon = "📿", price = 49 },
	{ id = M.SandalsPassId, attr = "WingSandals", name = "SandalsName", desc = "SandalsDesc", icon = "👡", price = 49 }, -- 🩴 (Unicode 13) ไม่มีในฟอนต์ Roblox ขึ้นเป็นกล่อง
}

-- ร่วมทำบุญ (Developer Product ซื้อซ้ำได้) ที่ตู้ร่วมทำบุญ + แท็บทำบุญในเมนู SHOP · ยอดขึ้นป้ายผู้ร่วมทำบุญสูงสุด (หน่วย Robux)
--   lobby/server/TempleMerit = ProcessReceipt ของ Lobby (ที่เดียวในแมพ Lobby)
M.DONATE_PRODUCTS = {
	{ amount = 10, id = 3735265659 }, -- Temple Donation 10 (ปิดราคาตามภูมิภาค: ยอดเท่ากันทุกประเทศ)
	{ amount = 50, id = 3735265772 },
	{ amount = 100, id = 3735265893 },
	{ amount = 500, id = 3735266050 },
}

-- สมุดหมอผี: ผีที่เรียกได้ (ลูกค้าผีอ่านจาก LanguageModule.BookOrder ที่ขึ้นต้น "Anomaly_")
M.BOOK_BIG = { "Krasue", "Pret" }
M.BOOK_LINGER = { "knock", "circle", "roof" }
M.BOOK_SCENERY = { "Tani", "Scarecrow", "Shadow", "HutShadow", "Dancer", "ShadowRun", "Kuman" }

-- ---------------------------------------------------------------- โมเดลไฟฉายตราช้าง (Blender: tools/blender/elephant_flashlight.py)
-- แม่แบบ = Model "ElephantFlashlight" ใน ServerStorage (Import 3D จาก assets/models/ElephantFlashlight/upload/ElephantFlashlight.fbx)
--   ไม่มีแม่แบบ = ใช้ไฟฉายกบ / ไฟฉายประกอบจาก Part เดิมไปก่อน
-- ขนาด / ตำแหน่ง (studs, Roblox) จาก log ของสคริปต์ Blender: เทียบกับกึ่งกลางชิ้นหลัก · ลำแสงชี้ -Z · หูหิ้วด้านบน +Y
--   ตั้ง Size เองทุกชิ้น: Import 3D ย่อขยายมาเท่าไหร่ก็ได้ขนาดตรง
M.ELEPHANT_PARTS = {
	ElephantFlashlight = { size = Vector3.new(0.662, 0.988, 1.0), rel = Vector3.new(0, 0, 0) },
	ElephantLens = { size = Vector3.new(0.55, 0.55, 0.006), rel = Vector3.new(0, -0.171, -0.497) },
	ElephantSidePanel = { size = Vector3.new(0.006, 0.16, 0.36), rel = Vector3.new(-0.247, -0.171, 0.13) },
}
M.ELEPHANT_GRIP = Vector3.new(0, 0.429, 0.15) -- กลางคานหูหิ้ว (จุดที่มือกำ) เทียบกึ่งกลางชิ้นหลัก
M.ELEPHANT_HALF_HEIGHT = 0.494 -- กึ่งกลางชิ้นหลักสูงจากก้นไฟฉายเท่านี้

function M.ElephantTemplate(): Instance?
	local ok, ss = pcall(function()
		return game:GetService("ServerStorage")
	end)
	local t = ok and ss and ss:FindFirstChild("ElephantFlashlight")
	if t and t:FindFirstChild("ElephantFlashlight", true) then
		return t
	end
	return nil
end

-- วางโมเดลไฟฉายตราช้าง: mainCF = กึ่งกลางชิ้นหลัก (ทิศ = ทิศไฟฉาย) · scale = ขนาด (1 = ถือในมือ)
--   คืนรายการชิ้น (ไม่มีแม่แบบ = nil) · ชิ้นไม่ชน ไม่มีน้ำหนัก (ผู้เรียกตั้ง Anchored / เชื่อม Weld เอง)
function M.PlaceElephant(mainCF: CFrame, scale: number, parent: Instance): { [string]: BasePart }?
	local tpl = M.ElephantTemplate()
	if not tpl then
		return nil
	end
	local out: { [string]: BasePart } = {}
	for name, info in pairs(M.ELEPHANT_PARTS) do
		local src = tpl:FindFirstChild(name, true)
		if src and src:IsA("BasePart") then
			local p = src:Clone()
			for _, ch in ipairs(p:GetChildren()) do
				if ch:IsA("JointInstance") or ch:IsA("WeldConstraint") then
					ch:Destroy()
				end
			end
			p.Name = name
			p.Size = info.size * scale
			p.CFrame = mainCF * CFrame.new(info.rel * scale)
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			if name == "ElephantLens" then
				p.Material = Enum.Material.Glass
				p.Color = Color3.fromRGB(255, 240, 200)
				p.Transparency = 0.35
			elseif name == "ElephantSidePanel" then
				p.Material = Enum.Material.Neon
				p.Color = Color3.fromRGB(235, 240, 255)
			end
			p.Parent = parent
			out[name] = p
		end
	end
	return out
end

-- ความเร็วเดินปกติของผู้เล่นคนนี้ (มีรองเท้าแตะติดปีก = เร็วขึ้น) ใช้แทน StarterPlayer.CharacterWalkSpeed ตอนคืนความเร็ว
function M.WalkSpeed(player: Player?): number
	local base = game:GetService("StarterPlayer").CharacterWalkSpeed
	if player and player:GetAttribute("WingSandals") == true then
		return base * M.SANDALS_SPEED
	end
	return base
end

-- ป้ายทอง "📖 หมอผี" เหนือหัวคนที่มีสมุดหมอผี (ฝั่ง Server: แมพปั๊ม server/GhostBook · Lobby lobby/server/PassShop)
--   height = ระยะเหนือหัว (Lobby สูงกว่าเพราะมีป้ายชื่อ LobbyNameplates อยู่แล้ว) · เจ้าของไม่เห็นป้ายตัวเอง
local function shamanTag(player: Player, char: Model, height: number)
	local old = char:FindFirstChild("ShamanTag")
	if old then
		old:Destroy()
	end
	if player:GetAttribute("GhostBook") ~= true then
		return
	end
	local head = char:WaitForChild("Head", 10) :: BasePart?
	if not head or char.Parent == nil then
		return
	end
	local Shared = script.Parent
	local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any
	local Bilingual = require(Shared:WaitForChild("Bilingual")) :: any
	local gui = Instance.new("BillboardGui")
	gui.Name = "ShamanTag"
	gui.Size = UDim2.fromOffset(180, 26)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	gui.PlayerToHideFrom = player
	gui.Adornee = head
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
	t.TextColor3 = Color3.fromRGB(245, 200, 90)
	t.TextSize = 17
	t.TextStrokeColor3 = Color3.fromRGB(60, 10, 6)
	t.TextStrokeTransparency = 0.2
	t.Parent = gui
	local e = LanguageModule.UI.ShamanTitle
	Bilingual.Text(t, "📖 " .. e.th, "📖 " .. e.en, { id = "📖 " .. e.id, pt = "📖 " .. e.pt, es = "📖 " .. e.es })
	-- ประกายทองช้าๆ ให้ดูเป็นของหายาก
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 236, 170)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	grad.Parent = t
	-- รูปลักษณ์อวตารโหลดเสร็จแล้ว Roblox เปลี่ยน Head ใหม่: ย้ายป้ายตาม
	local c = char.ChildAdded:Connect(function(ch)
		if ch.Name == "Head" and ch:IsA("BasePart") then
			gui.Adornee = ch
		end
	end)
	gui.Destroying:Connect(function()
		c:Disconnect()
	end)
	gui.Parent = char
end

function M.WatchShamanTags(height: number)
	local Players = game:GetService("Players")
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			shamanTag(player, char, height)
		end)
		player:GetAttributeChangedSignal("GhostBook"):Connect(function()
			if player.Character then
				task.spawn(shamanTag, player, player.Character, height)
			end
		end)
		if player.Character then
			task.spawn(shamanTag, player, player.Character, height)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return M
