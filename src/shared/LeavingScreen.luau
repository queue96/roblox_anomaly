--!strict
-- LeavingScreen.luau (ReplicatedStorage.Shared) — จอดำ "กำลังกลับวัด..." ตอนกดกลับ Lobby (ฝั่ง Client)
--   วาร์ปข้าม place ใช้เวลาหลายวินาที ถ้าจอไม่เปลี่ยนเลยผู้เล่นจะคิดว่าเกมค้าง
--   LeavingScreen.Show()  เรียกตอนกดปุ่ม (หน้าสรุปจบคืน / จอตาย / ยอมแพ้ในหน้าตั้งค่า)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LeavingScreen = {}

local shown: ScreenGui? = nil

function LeavingScreen.Show()
	if shown and shown.Parent then
		return
	end
	-- มีหน้าจอวาร์ปสวยๆ ของ LoadingScreen (ภาพ Key Art) ใช้อันนั้น
	local tp = (_G :: any).ShowTeleportScreen
	if type(tp) == "function" and pcall(tp, { destination = "lobby" }) then
		return
	end
	local player = Players.LocalPlayer
	local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any
	local lang = LanguageModule.Normalize(player:GetAttribute("Lang") :: string?)

	local sg = Instance.new("ScreenGui")
	sg.Name = "LeavingScreen"
	sg.IgnoreGuiInset = true
	sg.ScreenInsets = Enum.ScreenInsets.None
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 300 -- ทับทุกอย่าง (หน้าสรุป 70, คัทซีน 60, จอตาย 20)
	sg.Parent = player:WaitForChild("PlayerGui")
	shown = sg

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 1
	bg.BorderSizePixel = 0
	bg.Active = true -- กันกดปุ่มข้างหลังซ้ำ
	bg.Parent = sg

	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.new(0.8, 0, 0, 40)
	t.BackgroundTransparency = 1
	t.FontFace = Font.fromEnum(Enum.Font.SpecialElite)
	t.TextColor3 = Color3.fromRGB(236, 228, 208)
	t.TextSize = 26
	t.TextTransparency = 1
	t.Text = LanguageModule.GetUI("GoingToLobby", lang)
	t.Parent = bg

	TweenService:Create(bg, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	-- จุดไข่ปลาวิ่งให้รู้ว่ายังทำงานอยู่
	task.spawn(function()
		local base = string.gsub(t.Text, "%.+$", "")
		local n = 0
		while sg.Parent do
			n = n % 3 + 1
			t.Text = base .. string.rep(".", n)
			task.wait(0.45)
		end
	end)
	-- วาร์ปไม่สำเร็จ (Server เตะออกแทน / ค้าง): 20 วิแล้วยังอยู่ = เอาจอดำออก ให้กดใหม่ได้
	task.delay(20, function()
		if sg.Parent then
			sg:Destroy()
		end
	end)
end

return LeavingScreen
