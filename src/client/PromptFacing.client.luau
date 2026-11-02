--!strict
-- PromptFacing.client.luau
-- ปุ่มกด (เปิดร้าน เติมน้ำมัน เติมลม ฯลฯ) ที่ server ติด attribute NeedsFacing ไว้ จะกดได้เมื่อ
--   1) เดินไปถึงหน้าวัตถุ (ภายในระยะ Range ของปุ่ม) และ 2) หันกล้องไปทางวัตถุนั้น
-- ทำฝั่ง client โดยตั้ง MaxActivationDistance ของปุ่มในเครื่องนี้เป็น 0 ตอนไม่ได้มอง (server ไม่แก้ค่านี้หลังสร้าง)
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LOOK_COS = math.cos(math.rad(50)) -- ต้องมองให้วัตถุอยู่ไม่เกิน 50° จากกลางจอ (ตู้ใหญ่: มองหัวจ่ายก็นับ)
local CHECK_EVERY = 0.1

local prompts: { [ProximityPrompt]: boolean } = {}

local function track(p: Instance)
	if p:IsA("ProximityPrompt") and p:GetAttribute("NeedsFacing") then
		prompts[p] = true
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do
	track(d)
end
Workspace.DescendantAdded:Connect(function(d)
	track(d)
	if d:IsA("ProximityPrompt") then -- server อาจติด attribute หลังสร้างปุ่ม
		d:GetAttributeChangedSignal("NeedsFacing"):Connect(function()
			track(d)
		end)
	end
end)
Workspace.DescendantRemoving:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		prompts[d] = nil
	end
end)

local function targetPos(p: ProximityPrompt): Vector3?
	local parent = p.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent and parent:IsA("Model") then
		return parent:GetPivot().Position
	end
	return nil
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < CHECK_EVERY then
		return
	end
	acc = 0
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local camCf = cam.CFrame
	for p in pairs(prompts) do
		local pos = targetPos(p)
		local range = p:GetAttribute("Range")
		if pos and type(range) == "number" then
			local to = pos - camCf.Position
			local facing = to.Magnitude < 3.5 or camCf.LookVector:Dot(to.Unit) >= LOOK_COS
			local want = if facing then range else 0
			if p.MaxActivationDistance ~= want then
				p.MaxActivationDistance = want
			end
		end
	end
end)
