--!strict
-- BigEvents.luau (ModuleScript ฝั่ง Server)
-- ผีใหญ่บุกประชิด (GDD ข้อ 3 Tier 3 / ข้อ 27-30): ดึงแผงอย่างเดียวไม่พอ ต้องดับไฟ + นั่งยองนิ่งๆ ให้ผีผ่านไป
--   Krasue  แสงไฟผีกระสือลอยจากเถียงนามาวนหน้าเพิง        ดับไฟ + นั่งยอง
--   Pret    เปรตตัวสูงเท่าต้นตาลเดินผ่านถนนหน้าร้าน         ดับไฟ + นั่งยอง + ปิดไฟฉาย
--   Funeral ขบวนคนชุดขาวลอยผ่านถนนหน้าร้าน                 ปิดแผง + ดับไฟ + นั่งยอง
--   Pop     ปอบเดินกระตุกมาเคาะแผงหน้าร้าน                  ปิดแผง + ดับไฟ + ยืนนิ่ง (นั่งยองก็ได้)
-- ลำดับ: Warn (ผีเดินเข้ามา ข้อความบอกวิธีรับมือ) -> Danger (ผีถึงหน้าร้าน ตรวจกติกาทุก 0.25 วินาที) -> Leave (ผีออกไป)
--   ทำผิดครั้งแรก = จบช่วง Danger ทันที ผีเล่นท่าโกรธ คืนรายชื่อคนที่โดน (CoreLoop ตัดธูป + ผีหลอก)
-- ไฟ = server/Power (สะพานไฟ CutoutSwitch) · นั่งยอง = player attribute "Crouching" (Remotes.Crouch จาก client/Animate)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundBank = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundBank"))
local GhostNPC = require(script.Parent:WaitForChild("GhostNPC"))
local Power = require(script.Parent:WaitForChild("Power"))

local BigEvents = {}

BigEvents.Config = {
	Warn = 15, -- วินาที: ผีเดินเข้ามา ให้เวลาวิ่งไปสับสะพานไฟ / ปิดแผง / นั่งยอง
	Danger = 8, -- วินาที: ผีอยู่หน้าร้าน ตรวจกติกา
	Leave = 9, -- วินาที: ผีออกไป
	Grace = 0.6, -- ช่วงแรกของ Danger ยังไม่ตรวจ (คนที่กำลังจะนั่งลงพอดี)
	StillSpeed = 1.5, -- เร็วกว่านี้ (studs/วินาที) = ขยับ
}
BigEvents.Kinds = { "Krasue", "Pret", "Funeral", "Pop" }

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local CrouchRemote = remotes:FindFirstChild("Crouch") or Instance.new("RemoteEvent")
CrouchRemote.Name = "Crouch"
CrouchRemote.Parent = remotes
CrouchRemote.OnServerEvent:Connect(function(p: Player, on: any)
	p:SetAttribute("Crouching", on == true)
end)
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function()
		p:SetAttribute("Crouching", false)
	end)
end)

-- ---------------------------------------------------------------- ผังเดิน
-- pts = ตำแหน่ง (x, z) ตอนเริ่ม / จบ Warn / จบ Danger / จบ Leave (เดินเป็นเส้นตรงในแต่ละช่วง)
-- lift = ยกจากพื้นในแต่ละจุด · clips = ท่าช่วง Warn / Danger / Leave · angry = ท่าตอนจับได้ว่ามีคนทำผิด
-- face = ทิศที่หันตอนอยู่กับที่ (ไม่ใส่ = หันหาหน้าร้าน)
type Ghost = {
	name: string,
	pts: { { number } },
	lift: { number }?,
	clips: { string },
	angry: string?,
	face: Vector3?,
}
type Plan = {
	ghosts: { Ghost },
	rules: { lights: boolean, crouch: boolean, still: boolean, shutter: boolean, flashlight: boolean },
	voice: string,
	laugh: string?,
	focus: string?,
	glow: Color3?,
}

local function procession(): { Ghost }
	local list: { Ghost } = {}
	local names = { "ghost_funeral_elder_man", "ghost_funeral_man", "ghost_funeral_woman", "ghost_funeral_elder_woman", "ghost_shroud" }
	for i, n in ipairs(names) do
		local dx = -(i - 1) * 3.6
		table.insert(list, {
			name = n,
			pts = { { -78 + dx, -14 }, { -14 + dx, -14 }, { 20 + dx, -14 }, { 58 + dx, -14 } },
			lift = if n == "ghost_shroud" then { 0.5, 0.5, 0.5, 0.5 } else nil,
			clips = if n == "ghost_shroud" then { "shroud_glide", "shroud_glide", "shroud_glide" } else { "ghost_glide", "ghost_glide", "ghost_glide" },
		})
	end
	return list
end

local function plans(): { [string]: Plan }
	-- แผงหน้าร้าน: ปอบยืนห่างแผง 1.94 studs (ระยะหมัดในท่า KnockShutter)
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	local knockX = if door then door.Position.X + 6 else 6
	local knockZ = if door then door.Position.Z - door.Size.Z / 2 - 1.94 else 6
	return {
		Krasue = {
			ghosts = {
				{
					name = "Krasue",
					pts = { { -33, -58 }, { -4, -3 }, { 3, -3 }, { -60, -75 } },
					lift = { 7, 5.5, 5.5, 10 },
					clips = { "Float", "Sniff", "Float" },
					angry = "Lunge",
				},
			},
			rules = { lights = true, crouch = true, still = true, shutter = false, flashlight = false },
			voice = "Ghost_MaeNak",
			laugh = "Ghost_Pop_Laugh",
			focus = "Head",
			glow = Color3.fromRGB(255, 110, 40),
		},
		Pret = {
			ghosts = {
				{ name = "Pret", pts = { { -86, -17 }, { -18, -17 }, { 18, -17 }, { 58, -17 } }, clips = { "TallSlowWalk", "TallSlowWalk", "TallSlowWalk" }, angry = "Shriek" },
			},
			rules = { lights = true, crouch = true, still = true, shutter = false, flashlight = true },
			voice = "Ghost_Pret",
			laugh = "Ghost_Pret_Laugh",
		},
		Funeral = {
			ghosts = procession(),
			rules = { lights = true, crouch = true, still = true, shutter = true, flashlight = false },
			voice = "Ghost_Showtime",
		},
		Pop = {
			ghosts = {
				{
					name = "Pop",
					pts = { { 26, -22 }, { knockX, knockZ }, { knockX, knockZ }, { 32, -32 } },
					clips = { "TwitchWalk", "KnockShutter", "TwitchWalk" },
					angry = "PossessedSnap",
					face = Vector3.new(0, 0, 1),
				},
			},
			rules = { lights = true, crouch = false, still = true, shutter = true, flashlight = false },
			voice = "Ghost_Pop",
			laugh = "Ghost_Pop_Laugh",
		},
	}
end

-- ---------------------------------------------------------------- ช่วยเหลือ
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }
local function groundAt(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

local function fade(root: Instance, t: number, time: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "RootPart" then
			if time > 0 then
				TweenService:Create(d, TweenInfo.new(time), { Transparency = t }):Play()
			else
				d.Transparency = t
			end
		end
	end
end

local function shopFront(): Vector3
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	return if door then door.Position else Vector3.new(0, 0, 8)
end

local function shutterClosed(): boolean
	local props = Workspace:FindFirstChild("InteractiveProps")
	local door = props and props:FindFirstChild("ShutterDoor") :: BasePart?
	if not door then
		return true
	end
	local openY = door:GetAttribute("OpenY") or 15.5
	local closedY = door:GetAttribute("ClosedY") or 6.0
	return door.Position.Y < (openY + closedY) / 2
end

-- ผู้เล่นที่ต้องรับมือ: ยังมีชีวิต ไม่ได้ถูกยึดตัว (ตาย / คัทซีน)
local function activePlayers(): { Player }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hum and root and hum.Health > 0 and not root.Anchored then
			table.insert(out, p)
		end
	end
	return out
end

local function flashlightOn(p: Player): boolean
	local c = p.Character
	if not c then
		return false
	end
	for _, t in ipairs(c:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("On") == true then
			return true
		end
	end
	return false
end

-- คนนี้ทำผิดอะไร (nil = ไม่ผิด)
local function playerFault(p: Player, rules: any): string?
	local c = p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	if rules.crouch and p:GetAttribute("Crouching") ~= true then
		return "Crouch"
	end
	if rules.still then
		local v = root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > BigEvents.Config.StillSpeed then
			return "Move"
		end
	end
	if rules.flashlight and flashlightOn(p) then
		return "Flashlight"
	end
	return nil
end

-- ---------------------------------------------------------------- เดินตามผัง
type Live = { m: Model, g: Ghost }

local function placeAt(e: Live, phase: number, a: number)
	local p0, p1 = e.g.pts[phase], e.g.pts[phase + 1]
	local x = p0[1] + (p1[1] - p0[1]) * a
	local z = p0[2] + (p1[2] - p0[2]) * a
	local lift = 0
	if e.g.lift then
		lift = e.g.lift[phase] + (e.g.lift[phase + 1] - e.g.lift[phase]) * a
	end
	local feet = Vector3.new(x, groundAt(x, z) + lift, z)
	local dir = Vector3.new(p1[1] - p0[1], 0, p1[2] - p0[2])
	local look: Vector3
	if dir.Magnitude > 0.5 then
		look = dir.Unit
	elseif e.g.face then
		look = e.g.face
	else
		local f = shopFront()
		look = Vector3.new(f.X - x, 0, f.Z - z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, 1)
	end
	e.m:PivotTo(CFrame.lookAt(feet, feet + look))
end

-- ---------------------------------------------------------------- รัน
-- ctx.notice(key, seconds, players?) ข้อความล่างจอ · คืน { ok, faults = { [Player] = เหตุผล }, team = เหตุผลรวม?, group }
function BigEvents.Run(kind: string, ctx: { notice: (string, number, { Player }?) -> () }): { [string]: any }
	local plan = plans()[kind]
	if not plan then
		return { ok = true, faults = {} }
	end
	local cfg = BigEvents.Config
	local group = Instance.new("Model")
	group.Name = "BigEvent_" .. kind
	group:SetAttribute("FocusBone", plan.focus or "head")
	local live: { Live } = {}
	for _, g in ipairs(plan.ghosts) do
		local m = GhostNPC.Spawn(g.name, CFrame.new(), g.clips[1])
		if m then
			m.Parent = group
			local e = { m = m, g = g }
			placeAt(e, 1, 0)
			table.insert(live, e)
		end
	end
	if #live == 0 then
		group:Destroy()
		return { ok = true, faults = {} }
	end
	local root = live[1].m:FindFirstChild("RootPart") :: BasePart?
	if plan.glow and root then
		local l = Instance.new("PointLight")
		l.Color = plan.glow
		l.Range = 14
		l.Brightness = 2
		l.Parent = root
	end
	fade(group, 1, 0)
	group.Parent = Workspace:FindFirstChild("AnomalyProps") or Workspace
	fade(group, 0, 2.5)
	if root then
		SoundBank.PlayOneShot(plan.voice, root, 160, 6)
	end
	ctx.notice("Big_" .. kind .. "_Warn", cfg.Warn)

	-- ขยับตามผังทุกเฟรม (phase 1 = Warn, 2 = Danger, 3 = Leave)
	local durations = { cfg.Warn, cfg.Danger, cfg.Leave }
	local phase = 1
	local phaseStart = os.clock()
	local frozen = false
	local conn = RunService.Heartbeat:Connect(function()
		if frozen then
			return
		end
		local a = math.clamp((os.clock() - phaseStart) / durations[phase], 0, 1)
		for _, e in ipairs(live) do
			if e.m.Parent then
				placeAt(e, phase, a)
			end
		end
	end)
	local function setPhase(n: number)
		-- จบช่วงเดิมให้ตรงจุดพอดี แล้วเริ่มช่วงใหม่
		for _, e in ipairs(live) do
			placeAt(e, phase, 1)
		end
		phase = n
		phaseStart = os.clock()
		for _, e in ipairs(live) do
			-- ท่าเดิม = เล่นต่อ ไม่เริ่มท่าใหม่ (ไม่สะดุดกลางก้าว)
			if e.g.clips[n] ~= e.g.clips[n - 1] then
				GhostNPC.Play(e.m, e.g.clips[n])
			end
		end
	end

	task.wait(cfg.Warn)
	setPhase(2)
	ctx.notice("Big_Danger", cfg.Danger)
	if root and plan.laugh then
		SoundBank.PlayOneShot(plan.laugh, root, 160, 5)
	end

	-- ตรวจกติกา: ผิดครั้งแรก = จบ (ผิดทั้งทีม: ไฟ / แผง -> ทุกคนโดน)
	local faults: { [Player]: string } = {}
	local team: string? = nil
	local t0 = os.clock()
	while os.clock() - t0 < cfg.Danger do
		task.wait(0.25)
		if os.clock() - t0 < cfg.Grace then
			continue
		end
		if plan.rules.lights and Power.LightsOn() then
			team = "Lights"
		elseif plan.rules.shutter and not shutterClosed() then
			team = "Shutter"
		end
		if team then
			for _, p in ipairs(activePlayers()) do
				faults[p] = team
			end
			break
		end
		for _, p in ipairs(activePlayers()) do
			local f = playerFault(p, plan.rules)
			if f then
				faults[p] = f
			end
		end
		if next(faults) then
			break
		end
	end
	local ok = next(faults) == nil and team == nil

	if not ok then
		-- จับได้: ผีหยุดเดิน เล่นท่าโกรธ แล้วจางหายหลังผีหลอก
		frozen = true
		for _, e in ipairs(live) do
			if e.g.angry then
				GhostNPC.Play(e.m, e.g.angry)
			end
		end
		if root and plan.laugh then
			SoundBank.PlayOneShot(plan.laugh, root, 160, 4)
		end
		task.delay(4, function()
			conn:Disconnect()
			fade(group, 1, 1.5)
			task.delay(1.6, function()
				group:Destroy()
			end)
		end)
	else
		-- รอด: ผีเดินต่อจนพ้นไป
		task.wait(math.max(0, cfg.Danger - (os.clock() - t0)))
		setPhase(3)
		ctx.notice("Big_Pass", 5)
		task.delay(cfg.Leave, function()
			fade(group, 1, 1.5)
			task.delay(1.6, function()
				conn:Disconnect()
				group:Destroy()
			end)
		end)
	end
	return { ok = ok, faults = faults, team = team, group = group }
end

return BigEvents
