--!strict
-- GfxGuard.luau (ReplicatedStorage.Shared) — เก็บเงาไฟไว้ให้นานที่สุด ใช้ทั้งแมพปั๊ม (client/GraphicsGuard) และ Lobby (lobby/client/GraphicsGuard)
--   Roblox ไม่ให้สคริปต์ตั้ง/อ่านระดับกราฟิกของผู้เล่น: พอเครื่องร้อน กราฟิก Auto ตัดเงาไฟทิ้ง ภาพไม่สวย
--   -> เราลดภาระของเราเองก่อน (ผู้ใช้ 2026-11-23)
--   ไฟแต่ละดวงจัดกลุ่มด้วย config.classify(light):
--     "main"  = เงาไว้เสมอ
--     "pole"  = ไฟหลักรอง: มือถือมีเงา / ตัดเงาเมื่อ trim ถึง 4
--     "decor" = ไฟประดับ: มือถือไม่มีเงา / PC ตัดเงาเมื่อ trim ถึง 3
--     "off"   = ไม่ทำเงาทุกเครื่อง (ไฟเล็ก/ไกล เงาแทบมองไม่เห็น)
--     nil     = ไม่แตะ
--   config.phoneRange[ชื่อ] = { ระยะ, คูณความสว่าง }: มือถือหดระยะไฟในอาคาร (ไม่มีเงา = แสงไม่ลอดผนังออกไปไกล)
--   ระดับ trim (Lighting attribute "GfxTrim"): เฟรมตกต่อเนื่อง 9 วิ = +1 · ดีต่อเนื่อง 2 นาที = -1
--     1 = เบลอทั้งจอ + DOF ปิด · 2 = Bloom ปิด · 3 = ไฟประดับไม่ทำเงา · 4 = ไฟหลักรองไม่ทำเงา
--     (เอฟเฟกต์ปิดโดยคนที่ฟัง GfxTrim: แมพปั๊ม client/AmbienceController / Lobby config.onTrim)
--     ถอยคืนแล้วตกอีกภายใน 1 นาที = ค้างระดับนั้นไปตลอด (ไม่สลับเปิด-ปิดไปมา)
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GfxGuard = {}

export type Config = {
	isPhone: boolean,
	classify: (Light) -> string?,
	phoneRange: { [string]: { number } }?,
	onTrim: ((number) -> ())?,
}

function GfxGuard.Start(config: Config)
	local IS_PHONE = config.isPhone
	local level = 0
	local lights: { [Light]: string } = {}

	local function wantShadows(kind: string): boolean
		if kind == "main" then
			return true
		elseif kind == "pole" then
			return level < 4
		elseif kind == "decor" then
			return not IS_PHONE and level < 3
		elseif kind == "off" then
			return false
		end
		return true
	end
	local function apply(l: Light, kind: string)
		if l:GetAttribute("GfxBaseShadows") == nil then
			l:SetAttribute("GfxBaseShadows", l.Shadows)
		end
		if l:GetAttribute("GfxBaseShadows") ~= true then
			return -- ไม่ได้ทำเงาตั้งแต่แรก ไม่แตะ
		end
		l.Shadows = wantShadows(kind)
	end
	local function track(d: Instance)
		if not d:IsA("Light") or lights[d] then
			return
		end
		local kind = config.classify(d)
		if not kind then
			return
		end
		lights[d] = kind
		if IS_PHONE and config.phoneRange then
			local key = if d.Name == "PointLight" or d.Name == "SpotLight" then (if d.Parent then d.Parent.Name else d.Name) else d.Name
			local r = config.phoneRange[key]
			if r then
				(d :: any).Range = math.min((d :: any).Range, r[1])
				d.Brightness = d.Brightness * r[2]
			end
		end
		apply(d, kind)
		d.Destroying:Connect(function()
			lights[d] = nil
		end)
	end
	-- StreamingEnabled: ไฟอาจมาถึงทีหลัง
	for _, d in ipairs(Workspace:GetDescendants()) do
		track(d)
	end
	Workspace.DescendantAdded:Connect(track)

	local function setLevel(n: number)
		n = math.clamp(n, 0, 4)
		if n == level then
			return
		end
		level = n
		Lighting:SetAttribute("GfxTrim", n)
		for l, kind in pairs(lights) do
			apply(l, kind)
		end
		if config.onTrim then
			config.onTrim(n)
		end
	end
	Lighting:SetAttribute("GfxTrim", 0)
	if config.onTrim then
		config.onTrim(0)
	end

	-- ---------------------------------------------------------------- วัดเฟรมเรต
	local WINDOW = 3 -- วินาทีต่อการวัด 1 รอบ
	local BAD_WINDOWS = 3 -- ตกติดกันกี่รอบถึงลดภาระ (9 วิ: ไม่นับกระตุกแวบเดียวตอนโหลด/ผีโผล่)
	local RECOVER_AFTER = 120 -- เฟรมดีต่อเนื่องกี่วินาทีถึงถอยคืน 1 ระดับ
	local WARMUP = 20 -- วินาทีแรกหลังเข้าไม่วัด (โหลดของ)

	local frames, elapsed = 0, 0
	local peak = 0
	local badRun = 0
	local goodTime = 0
	local recoveredAt = -math.huge
	local locked = false
	local startedAt = os.clock()
	local focused = true

	UserInputService.WindowFocusReleased:Connect(function()
		focused = false
	end)
	UserInputService.WindowFocused:Connect(function()
		focused = true
		frames, elapsed, badRun = 0, 0, 0
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not focused or os.clock() - startedAt < WARMUP then
			return
		end
		frames += 1
		elapsed += dt
		if elapsed < WINDOW then
			return
		end
		local fps = frames / elapsed
		frames, elapsed = 0, 0
		-- เพดานเฟรมของเครื่องนี้ (30 / 60 / 120...): จำค่าสูงสุดไว้ ลดลงช้าๆ (เครื่องล็อก 30 ไม่นับว่าตก)
		peak = math.max(fps, peak * 0.99)
		local bad = fps < math.min(50, peak * 0.8)
		if bad then
			badRun += 1
			goodTime = 0
			if badRun >= BAD_WINDOWS and level < 4 then
				badRun = 0
				if os.clock() - recoveredAt < 60 then
					locked = true
				end
				setLevel(level + 1)
			end
		else
			badRun = 0
			if fps >= peak * 0.92 then
				goodTime += WINDOW
			else
				goodTime = 0
			end
			if goodTime >= RECOVER_AFTER and level > 0 and not locked then
				goodTime = 0
				recoveredAt = os.clock()
				setLevel(level - 1)
			end
		end
	end)
end

return GfxGuard
