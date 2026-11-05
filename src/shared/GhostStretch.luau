--!strict
-- GhostStretch.luau (ReplicatedStorage.Shared) — ยืดแขน/ขาผีแบบมีกระดูก (HumanRig: upper_arm/forearm/hand, thigh/shin/foot)
--   เลื่อนจุดต่อกระดูก (Bone.CFrame = ตำแหน่งพักเทียบกระดูกแม่) ให้ห่างออก: เนื้อ (skinned mesh) ยืดตาม
--   ท่าที่เล่นอยู่ (Animator เขียน Bone.Transform) ยังเล่นทับได้ตามปกติ ไม่ต้องทำท่าใหม่
--   ใช้ฝั่ง Client กับร่างผีที่สร้างบนเครื่องตัวเอง (client/SceneryGhosts)
--
--   GhostStretch.Set(model, "arm", "R", 4, 1.2)   แขนขวายาว 4 เท่าใน 1.2 วิ (factor 1 = คืนปกติ)
--   GhostStretch.Set(model, "leg", nil, 2.2, 1.5) ขาสองข้างยาว 2.2 เท่า
--   GhostStretch.LegLift(model)                     ขายาวขึ้นกี่ studs (ยกตัวขึ้นเท่านี้ เท้าจะได้แตะพื้นพอดี)
local RunService = game:GetService("RunService")

local GhostStretch = {}

local CHAIN = {
	arm = { "forearm", "hand" },
	leg = { "shin", "foot" },
}

type State = { rest: { [Bone]: CFrame }, factor: { [string]: number }, legLen: number, conn: { [string]: RBXScriptConnection } }
local states: { [Model]: State } = setmetatable({}, { __mode = "k" }) :: any

local function bonesOf(m: Model): { [string]: Bone }
	local t = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Bone") then
			t[d.Name] = d
		end
	end
	return t
end

local function state(m: Model): State
	local s = states[m]
	if s then
		return s
	end
	local b = bonesOf(m)
	local rest = {}
	for _, d in pairs(b) do
		rest[d] = d.CFrame
	end
	-- ความยาวขาจริง (studs): สะโพก -> เข่า -> ข้อเท้า วัดจากตำแหน่งในโลก
	local legLen = 0
	local th, sh, ft = b["thigh.L"], b["shin.L"], b["foot.L"]
	if th and sh and ft then
		legLen = (th.WorldPosition - sh.WorldPosition).Magnitude + (sh.WorldPosition - ft.WorldPosition).Magnitude
	end
	s = { rest = rest, factor = {}, legLen = legLen, conn = {} }
	states[m] = s
	return s
end

local function apply(m: Model, s: State, kind: string, side: string, f: number)
	local b = bonesOf(m)
	for _, name in ipairs(CHAIN[kind]) do
		local bone = b[name .. "." .. side]
		local r = bone and s.rest[bone]
		if bone and r then
			bone.CFrame = (r - r.Position) + r.Position * f
		end
	end
end

-- ยาวขึ้นจากปกติกี่ studs (ขาสองข้างใช้ factor เดียวกัน)
function GhostStretch.LegLift(m: Model): number
	local s = states[m]
	if not s then
		return 0
	end
	local f = s.factor["leg.L"] or 1
	return (f - 1) * s.legLen
end

function GhostStretch.Set(m: Model, kind: "arm" | "leg", side: string?, factor: number, time: number?)
	local s = state(m)
	local sides = if side then { side } else { "L", "R" }
	for _, sd in ipairs(sides) do
		local key = kind .. "." .. sd
		local from = s.factor[key] or 1
		if s.conn[key] then
			s.conn[key]:Disconnect()
			s.conn[key] = nil
		end
		local dur = time or 0
		if dur <= 0 then
			s.factor[key] = factor
			apply(m, s, kind, sd, factor)
		else
			local t0 = os.clock()
			s.conn[key] = RunService.RenderStepped:Connect(function()
				if not m.Parent then
					if s.conn[key] then
						s.conn[key]:Disconnect()
						s.conn[key] = nil
					end
					return
				end
				local a = math.clamp((os.clock() - t0) / dur, 0, 1)
				local e = a * a * (3 - 2 * a)
				local f = from + (factor - from) * e
				s.factor[key] = f
				apply(m, s, kind, sd, f)
				if a >= 1 and s.conn[key] then
					s.conn[key]:Disconnect()
					s.conn[key] = nil
				end
			end)
		end
	end
end

return GhostStretch
