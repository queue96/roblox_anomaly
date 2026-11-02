--!strict
-- PlayerVillager.server.luau
-- ตัวผู้เล่น = ชาวบ้านแบบใหม่ (แม่แบบเดียวกับลูกค้า ServerStorage.HumanTemplates.human_base) ชุดม่อฮ่อม + ทรงผมสุ่มทุกครั้งที่เกิด
--   สร้าง StarterPlayer.StarterCharacter จากแม่แบบตอนเซิร์ฟเวอร์เริ่ม (ไม่ต้องเก็บไว้ในไฟล์ place)
--     - HumanoidRootPart ใหม่ระดับสะโพก (ชิ้นเดิม "RootPart" ที่เท้ายังเป็นแม่ของกระดูกทั้งหมด: ท่าที่ publish อ้างชื่อนี้)
--     - ทุกชิ้นปลด Anchored เชื่อม (WeldConstraint) กับ HumanoidRootPart, ไม่ชน ไม่มีมวล
--     - Humanoid + Animator (ท่าเล่นจาก client: client/VillagerAnimate ใน StarterCharacterScripts)
--     - ชิ้นล่องหน "Head" ที่หัว (โค้ดเดิมหาเสียง/ตำแหน่งจาก Character.Head)
--   ตอนเกิด: ชุดม่อฮ่อมทุกคน ผมสุ่ม ผ้าคาดเอวสีไม่ซ้ำกัน (HumanNPC.Dress ลบชุด/ผม/ผิวที่ไม่ได้ใช้)
-- ถ้าไม่มีแม่แบบ: ใช้ avatar ของ Roblox ตามเดิม
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local HumanNPC = require(script.Parent:WaitForChild("HumanNPC"))

local HIP = 3.08 -- สะโพก (กระดูก hips) สูงจากพื้นเท่านี้ (studs) ในแม่แบบ
-- หนา (แกน Z) 2 studs: กล้องมุมบุคคลที่หนึ่งอยู่หน้าหัวราว 0.6 จากกลางตัว ต้องอยู่ข้างในกล่องชนเสมอ
-- (เดิม 1: เดินชนกำแพง/รถแล้วกล้องทะลุเข้าไปเห็นข้างใน)
local HRP_SIZE = Vector3.new(2, 2, 2)

local function bone(m: Instance, name: string): Bone?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") and d.Name == name then
			return d
		end
	end
	return nil
end

local function buildStarterCharacter(): Model?
	local templates = ServerStorage:FindFirstChild("HumanTemplates")
	local tpl = templates and templates:FindFirstChild("human_base") :: Model?
	if not tpl then
		return nil
	end
	local c = tpl:Clone()
	c.Name = "StarterCharacter"
	c:PivotTo(CFrame.new(0, 0, 0))
	local ac = c:FindFirstChildOfClass("AnimationController")
	if ac then
		ac:Destroy() -- Humanoid.Animator ขับกระดูกแทน
	end
	local feet = (c:FindFirstChild("RootPart") :: BasePart).CFrame
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = HRP_SIZE
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CanTouch = true
	hrp.CanQuery = true
	hrp.CFrame = feet * CFrame.new(0, HIP, 0)
	hrp.Parent = c
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") and d ~= hrp then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("WeldConstraint")
			w.Part0 = hrp
			w.Part1 = d
			w.Parent = hrp
		end
	end
	hrp.Anchored = false
	-- ชิ้นล่องหนที่หัว
	local hb = bone(c, "head")
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1, 1.1, 1)
	head.Transparency = 1
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.Massless = true
	head.CFrame = CFrame.new((if hb then hb.WorldPosition else feet.Position + Vector3.new(0, 5.5, 0)) + Vector3.new(0, 0.4, 0))
	head.Parent = c
	local hw = Instance.new("WeldConstraint")
	hw.Part0 = hrp
	hw.Part1 = head
	hw.Parent = hrp
	c.PrimaryPart = hrp
	local hum = Instance.new("Humanoid")
	-- สะโพกสูง HIP จากพื้น: ก้นของ HumanoidRootPart อยู่สูงจากพื้น HIP - ครึ่งความสูงของมัน
	-- วัดในเกม: ตั้งตามสูตรแล้วตัวจมพื้น 0.36 (ปลายเท้าอยู่ใต้พื้น) -> บวกชดเชยให้รองเท้าวางบนพื้นพอดี
	hum.HipHeight = HIP - HRP_SIZE.Y / 2 + 0.36
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = c
	Instance.new("Animator").Parent = hum
	return c
end

-- มุมมองของผู้เล่น (character/Animate ส่งมา ~10 ครั้ง/วินาที) -> attribute "HeadYaw"/"HeadPitch" ของตัวละคร ให้คนอื่นเห็น
-- (client/HeadTurnOthers หมุนคอ หัว ลำตัว แขนไฟฉายตามค่านี้)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local headRemote: RemoteEvent = (remotes:FindFirstChild("HeadTurn") or Instance.new("RemoteEvent")) :: any
headRemote.Name = "HeadTurn"
headRemote.Parent = remotes
local HEAD_LIMIT = math.rad(45)
local function angle(v: any, lo: number, hi: number): number?
	if type(v) ~= "number" or v ~= v then
		return nil
	end
	return math.floor(math.clamp(v, lo, hi) * 100 + 0.5) / 100
end
headRemote.OnServerEvent:Connect(function(p: Player, yaw: any, pitch: any)
	local char = p.Character
	local y = angle(yaw, -HEAD_LIMIT, HEAD_LIMIT)
	if not (char and y) then
		return
	end
	char:SetAttribute("HeadYaw", y)
	char:SetAttribute("HeadPitch", angle(pitch, math.rad(-65), math.rad(70)) or 0)
end)

local starter: Model? = nil

-- ผู้เล่นทุกคนใส่ชุดม่อฮ่อม (ผมยังสุ่ม) ผ้าขาวม้าคาดเอวสีไม่ซ้ำกันในเซิร์ฟเวอร์ (บอกกันได้ว่าใครเป็นใคร)
-- ย้อมสีด้วย SurfaceAppearance.Color: คูณกับลายผ้าขาวม้าเดิม (ขาว = สีเดิม ชมพู) ดูตัวอย่างแล้วแยกกันชัด
local PLAYER_OUTFIT = "mohom"
local SASH_PARTS = { "Cloth_mohom_sash", "Cloth_mohom_sash_tails" }
local SASH_COLORS = {
	Color3.fromRGB(255, 255, 255), -- ชมพู (สีเดิม)
	Color3.fromRGB(120, 200, 255), -- ฟ้าม่วง
	Color3.fromRGB(140, 255, 140), -- เขียว
	Color3.fromRGB(255, 230, 110), -- ส้ม
	Color3.fromRGB(220, 140, 255), -- ม่วงบานเย็น
	Color3.fromRGB(110, 255, 255), -- ฟ้าเขียว
	Color3.fromRGB(255, 120, 110), -- แดง
	Color3.fromRGB(170, 170, 170), -- เทา
}
local sashOf: { [Player]: number } = {}

local function sashIndex(p: Player): number
	if sashOf[p] then
		return sashOf[p]
	end
	local used: { [number]: boolean } = {}
	for _, i in pairs(sashOf) do
		used[i] = true
	end
	local pick = math.random(#SASH_COLORS)
	for i = 1, #SASH_COLORS do
		if not used[i] then
			pick = i
			break
		end
	end
	sashOf[p] = pick
	return pick
end

local function dress(char: Model, p: Player)
	if not char:FindFirstChild("RootPart") or char:GetAttribute("Human") then
		return
	end
	HumanNPC.Dress(char, { outfit = PLAYER_OUTFIT, noHelmet = true })
	local color = SASH_COLORS[sashIndex(p)]
	for _, n in ipairs(SASH_PARTS) do
		local part = char:FindFirstChild(n)
		local sa = part and part:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			(sa :: any).Color = color
		end
	end
end

local function onPlayer(p: Player)
	local function onCharacter(char: Model)
		if char.Name ~= "StarterCharacter" and char:FindFirstChild("RootPart") then
			dress(char, p)
		end
	end
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then
		onCharacter(p.Character)
	end
end
Players.PlayerRemoving:Connect(function(p)
	sashOf[p] = nil -- คืนสีให้คนที่เข้ามาใหม่
end)

local ok, err = pcall(function()
	starter = buildStarterCharacter()
end)
if not ok then
	warn("[PlayerVillager] สร้างตัวผู้เล่นไม่ได้:", err)
end
if starter then
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	starter.Parent = StarterPlayer
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
		-- เกิดไปแล้วด้วย avatar เดิม (สคริปต์นี้เริ่มช้ากว่า): เกิดใหม่เป็นชาวบ้าน
		if p.Character and not p.Character:FindFirstChild("RootPart") then
			task.spawn(function()
				p:LoadCharacter()
			end)
		end
	end
end
