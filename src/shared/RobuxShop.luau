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
	PosterImage = "",

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

-- สมุดหมอผี: ผีที่เรียกได้ (ลูกค้าผีอ่านจาก LanguageModule.BookOrder ที่ขึ้นต้น "Anomaly_")
M.BOOK_BIG = { "Krasue", "Pret" }
M.BOOK_LINGER = { "knock", "circle", "roof" }
M.BOOK_SCENERY = { "Tani", "Scarecrow", "Shadow", "HutShadow", "Dancer", "ShadowRun", "Kuman" }

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
