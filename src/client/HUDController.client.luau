-- HUDController.client.luau
-- สคริปต์ควบคุมหน้าจอฝั่งผู้เล่น (Client)
-- Phase 3: แสดงเงินในกระป๋อง ฿x / ฿500, ธูป 3 ดอก, คำพูดลูกค้า (แปลภาษาตาม LocaleId), ผีหลอกเมื่อเติมน้ำมันให้ผี, ชนะ/แพ้
-- รับข้อมูลจาก ReplicatedStorage.Remotes (สร้างโดย CoreLoop ฝั่ง Server)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule"))
local locale = localPlayer.LocaleId

print("✅ [Client] ยินดีต้อนรับสู่ปั๊มหลอดท้ายทุ่ง:", localPlayer.Name, "| ภาษาเครื่อง:", locale)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateHUD = remotes:WaitForChild("UpdateHUD") :: RemoteEvent
local TriggerJumpscare = remotes:WaitForChild("TriggerJumpscare") :: RemoteEvent
local CustomerSpeech = remotes:WaitForChild("CustomerSpeech") :: RemoteEvent
local GameState = remotes:WaitForChild("GameState") :: RemoteEvent

-- ---------------------------------------------------------------- สร้าง UI
local gui = Instance.new("ScreenGui")
gui.Name = "PumpHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.new(0, 16, 0, 56)
panel.Size = UDim2.new(0, 230, 0, 86)
panel.BackgroundColor3 = Color3.fromRGB(16, 14, 12)
panel.BackgroundTransparency = 0.35
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local function label(name: string, y: number, size: number, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.new(0, 12, 0, y)
	t.Size = UDim2.new(1, -24, 0, size)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextColor3 = color
	t.Parent = panel
	return t
end
local moneyTitle = label("MoneyTitle", 6, 16, Color3.fromRGB(200, 190, 170))
moneyTitle.Text = LanguageModule.GetUI("Money", locale)
local moneyText = label("Money", 22, 28, Color3.fromRGB(255, 214, 90))
moneyText.Text = "฿0 / ฿500"
local incenseText = label("Incense", 54, 24, Color3.fromRGB(255, 140, 80))
incenseText.Text = LanguageModule.GetUI("Incense", locale) .. "  🕯️🕯️🕯️"

local banner = Instance.new("TextLabel")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.35)
banner.Size = UDim2.new(0.7, 0, 0, 70)
banner.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
banner.BackgroundTransparency = 0.25
banner.TextColor3 = Color3.fromRGB(240, 230, 210)
banner.Font = Enum.Font.GothamBold
banner.TextScaled = true
banner.Visible = false
banner.Parent = gui

local flash = Instance.new("Frame")
flash.Name = "ScareFlash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
flash.BackgroundTransparency = 1
flash.ZIndex = 10
flash.Parent = gui

local function showBanner(text: string, color: Color3, seconds: number)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.delay(seconds, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

-- ---------------------------------------------------------------- เงิน + ธูป
local lastMoney = 0
UpdateHUD.OnClientEvent:Connect(function(money: number, target: number, incense: number, maxIncense: number)
	moneyText.Text = string.format("฿%d / ฿%d", money, target)
	if money > lastMoney then
		moneyText.TextColor3 = Color3.fromRGB(140, 255, 140)
		TweenService:Create(moneyText, TweenInfo.new(0.8), { TextColor3 = Color3.fromRGB(255, 214, 90) }):Play()
	end
	lastMoney = money
	incenseText.Text = LanguageModule.GetUI("Incense", locale) .. "  " .. string.rep("🕯️", incense) .. string.rep("⚫", maxIncense - incense)
end)

-- ---------------------------------------------------------------- คำพูดลูกค้า (BillboardGui เหนือหัวคนขับ)
local bubble: BillboardGui? = nil
CustomerSpeech.OnClientEvent:Connect(function(key: string?, head: BasePart?)
	if bubble then
		bubble:Destroy()
		bubble = nil
	end
	if not key or not head then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "CustomerSpeech"
	b.Adornee = head
	b.Size = UDim2.new(0, 320, 0, 70)
	b.StudsOffset = Vector3.new(0, 2.6, 0)
	b.AlwaysOnTop = true
	b.MaxDistance = 60
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(245, 240, 225)
	t.BackgroundTransparency = 0.1
	t.TextColor3 = Color3.fromRGB(25, 20, 18)
	t.Font = Enum.Font.Gotham
	t.TextScaled = true
	t.TextWrapped = true
	t.Text = LanguageModule.GetText(key, locale)
	t.Parent = b
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = t
	b.Parent = localPlayer:WaitForChild("PlayerGui") -- BillboardGui ต้องอยู่ใน PlayerGui ตรงๆ (อยู่ใน ScreenGui จะไม่แสดง)
	bubble = b
end)

-- ---------------------------------------------------------------- ผีหลอก (เติมน้ำมันให้ผี)
TriggerJumpscare.OnClientEvent:Connect(function(_anomalyKey: string?)
	flash.BackgroundTransparency = 0.15
	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	showBanner(LanguageModule.GetUI("Jumpscare", locale), Color3.fromRGB(255, 70, 60), 3)
	local cam = workspace.CurrentCamera
	if cam then
		task.spawn(function()
			for _ = 1, 10 do
				cam.CFrame *= CFrame.Angles(math.rad(math.random(-2, 2)), math.rad(math.random(-2, 2)), 0)
				task.wait(0.03)
			end
		end)
	end
end)

-- ---------------------------------------------------------------- ชนะ / แพ้ / คืนใหม่
GameState.OnClientEvent:Connect(function(state: string)
	if state == "Win" then
		showBanner(LanguageModule.GetUI("Win", locale), Color3.fromRGB(255, 220, 110), 10)
	elseif state == "Lose" then
		showBanner(LanguageModule.GetUI("Lose", locale), Color3.fromRGB(255, 80, 70), 10)
	elseif state == "Playing" then
		showBanner(LanguageModule.GetUI("NewNight", locale), Color3.fromRGB(220, 220, 230), 4)
	end
end)
