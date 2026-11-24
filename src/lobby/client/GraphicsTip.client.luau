--!strict
-- GraphicsTip.client.luau — Lobby: แนะนำครั้งเดียวให้ตั้งกราฟิกเป็น Manual (ผู้ใช้ 2026-11-24)
--   เกมพึ่งแสงเงา แต่กราฟิก Automatic ของ Roblox ปิดเงาเองเมื่อลดระดับ และสคริปต์ตั้งระดับแทนผู้เล่นไม่ได้
--   ขึ้นเฉพาะ: คอม (มีคีย์บอร์ด) + ตั้งกราฟิกเป็น Automatic + เฟรมลื่น (เครื่องน่าจะไหว) + ยังไม่เคยเห็น (PlayerSettings GfxTipSeen)
--   เฟรมไม่ลื่น = ไม่ขึ้นและไม่นับว่าเห็นแล้ว (ไม่แนะนำให้เครื่องอ่อนปรับขึ้น)
--   ไม่บังจอ ไม่ล็อกเมาส์ · เปลี่ยนเป็น Manual แล้วการ์ดปิดเอง
--   ทดสอบ: ตั้ง attribute GfxTipTest = true ที่ตัวผู้เล่น (ข้ามทุกเงื่อนไข ไม่บันทึก)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local MIN_FPS = 50 -- เฟรมเฉลี่ยขั้นต่ำถึงจะแนะนำ
local MEASURE = 8 -- วินาทีที่วัดเฟรม

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LanguageModule = require(Shared:WaitForChild("LanguageModule")) :: any

if not UserInputService.KeyboardEnabled then -- โน้ตบุ๊กจอสัมผัสนับเป็นคอม
	return
end
local okSettings, gameSettings = pcall(function()
	return UserSettings():GetService("UserGameSettings")
end)
if not okSettings then
	return
end
local function isAuto(): boolean
	local ok, v = pcall(function()
		return gameSettings.SavedQualityLevel
	end)
	return ok and v == Enum.SavedQualitySetting.Automatic
end
local function testing(): boolean
	return player:GetAttribute("GfxTipTest") == true
end

-- รอหน้าโหลด + ฉากเปิด Lobby จบ (LobbyIntro ซ่อน UI ทุกอันที่สร้างระหว่างนั้น)
local playerGui = player:WaitForChild("PlayerGui")
local t0 = os.clock()
while player:GetAttribute("LoadingScreenDone") ~= true and os.clock() - t0 < 120 do
	task.wait(0.5)
end
task.wait(3)
while playerGui:FindFirstChild("LobbyIntro") do
	task.wait(0.5)
end
-- ค่าที่บันทึกไว้โหลดเสร็จ
t0 = os.clock()
while player:GetAttribute("GfxTipSeen") == nil and os.clock() - t0 < 20 do
	task.wait(0.5)
end
if not testing() then
	if player:GetAttribute("GfxTipSeen") ~= false or not isAuto() then
		return
	end
	task.wait(4)
	local frames = 0
	local conn = RunService.RenderStepped:Connect(function()
		frames += 1
	end)
	local m0 = os.clock()
	task.wait(MEASURE)
	conn:Disconnect()
	if frames / (os.clock() - m0) < MIN_FPS or not isAuto() then
		return
	end
end

local function T(key: string): string
	return LanguageModule.GetUI(key, LanguageModule.Normalize((player:GetAttribute("Lang") :: string?) or player.LocaleId))
end

local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local C_TEXT = Color3.fromRGB(236, 232, 226)
local C_DIM = Color3.fromRGB(186, 180, 172)
local C_GOLD = Color3.fromRGB(232, 190, 92)

local gui = Instance.new("ScreenGui")
gui.Name = "GraphicsTipGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.AutoLocalize = false
gui.DisplayOrder = 4
gui.Parent = playerGui
do
	local fit = Shared:FindFirstChild("UiFit")
	if fit then
		(require(fit) :: any).Attach(gui)
	end
end

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0, -380, 1, -14)
card.Size = UDim2.fromOffset(350, 0)
card.AutomaticSize = Enum.AutomaticSize.Y
card.BackgroundColor3 = Color3.fromRGB(14, 12, 12)
card.BackgroundTransparency = 0.08
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(150, 146, 140)
stroke.Thickness = 2
stroke.Transparency = 0.2
stroke.Parent = card
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)
pad.Parent = card
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = card

local function label(order: number, size: number, font: Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextSize = size
	l.FontFace = font
	l.TextColor3 = color
	l.Parent = card
	return l
end
local title = label(1, 18, BOLD, C_GOLD)
local body = label(2, 15, BODY, C_TEXT)
local steps = label(3, 15, BOLD, C_TEXT)
local note = label(4, 13, BODY, C_DIM)
local btn = Instance.new("TextButton")
btn.LayoutOrder = 5
btn.Size = UDim2.new(1, 0, 0, 32)
btn.BackgroundColor3 = Color3.fromRGB(40, 38, 38)
btn.TextSize = 15
btn.FontFace = BOLD
btn.TextColor3 = C_TEXT
btn.Parent = card
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = btn

local function refresh()
	title.Text = T("GfxTipTitle")
	body.Text = T("GfxTipBody")
	steps.Text = T("GfxTipSteps")
	note.Text = T("GfxTipNote")
	btn.Text = T("GfxTipOk")
end
refresh()
local langConn = player:GetAttributeChangedSignal("Lang"):Connect(refresh)

TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0, 14, 1, -14) }):Play()

-- ขึ้นแล้ว = นับว่าเห็นแล้ว (ออกเกมทั้งที่การ์ดยังเปิดอยู่ ครั้งหน้าไม่ขึ้นซ้ำ)
if not testing() then
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local setSetting = remotes and remotes:FindFirstChild("SetSetting")
	if setSetting and setSetting:IsA("RemoteEvent") then
		setSetting:FireServer("GfxTipSeen", true)
	end
end

local closed = false
local qualityConn: RBXScriptConnection? = nil
local function close()
	if closed then
		return
	end
	closed = true
	langConn:Disconnect()
	if qualityConn then
		qualityConn:Disconnect()
	end
	local t = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0, -380, 1, -14) })
	t:Play()
	t.Completed:Wait()
	gui:Destroy()
end
btn.Activated:Connect(close)
pcall(function()
	qualityConn = gameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
		if not isAuto() and not testing() then
			close()
		end
	end)
end)
