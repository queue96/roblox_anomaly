--!strict
-- KnockPlan.luau (ReplicatedStorage.Shared) — จังหวะผีเคาะแผง (ผู้ใช้ 2026-11-26 "ทำให้น่ากลัวกว่านี้")
--   เดิมเสียง / แผงสั่น / ท่ามือ เดินคนละนาฬิกา และแรงเท่ากันตลอด
--   ตอนนี้ Server (GhostLinger) คิดตารางเคาะทั้งหมดครั้งเดียว ส่งเป็น attribute "KnockPlan" ที่ตัวผี (เวลา Server)
--   ทุกเครื่องเล่นเองจากตารางเดียวกัน: มือ (client/GhostAnimRunner) + เสียง แผง ไฟ ฝุ่น จอ (client/KnockFX) จึงตรงกันเป๊ะ
local KnockPlan = {}

export type Hit = { t: number, p: number } -- t = วินาทีหลังเริ่ม (ใน Decode = เวลา Server) · p = แรง 0..1
export type Line = { t: number, key: string, speed: number } -- เลียนเสียงลูกค้า
export type Plan = { hits: { Hit }, lines: { Line }, hushTo: number, finish: number }

-- ครั้งที่ 1 / 2 / 3 ของคืน (GhostLinger.Config.KnockMax = 3) ไม่ซ้ำแบบกัน
KnockPlan.ORDER = { "build", "mimic", "fake" }

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

function KnockPlan.Build(variant: string): Plan
	local hits: { Hit } = {}
	local lines: { Line } = {}
	local t = 0
	-- เคาะ n ทีติดกัน ห่าง gap (ไม่เป๊ะเหมือนเครื่อง) แรง p -> p2
	local function burst(n: number, gap: number, p: number, p2: number?)
		for i = 1, n do
			local k = if n > 1 then (i - 1) / (n - 1) else 0
			table.insert(hits, { t = t, p = math.clamp(p + ((p2 or p) - p) * k + rand(-0.03, 0.03), 0.1, 1) })
			t += gap * rand(0.9, 1.1)
		end
	end
	local function say(key: string, speed: number, hold: number)
		table.insert(lines, { t = t, key = key, speed = speed })
		t += hold
	end
	local hushTo: number

	if variant == "mimic" then
		-- เลียนเสียงลูกค้าที่เพิ่งไล่ไป: สุภาพ -> เสียงต่ำยานลงทุกประโยค
		t = 1.6
		burst(2, 0.5, 0.22)
		t += 0.5
		say("Shutter_Closed_2", 0.96, 3.4)
		burst(2, 0.45, 0.32)
		t += 0.4
		say("Impatient_2", 0.87, 3.8)
		burst(3, 0.4, 0.5, 0.6)
		t += 0.5
		say("Shutter_Closed_1", 0.72, 2.8)
		t += rand(1.6, 2.6)
		hushTo = t
		if math.random() < 0.6 then
			burst(1, 0, 1)
		end
	elseif variant == "fake" then
		-- หลอกว่าไปแล้ว: รัวเร็ว เงียบ จิ้งหรีดเริ่มร้องกลับมา แล้วโครม
		t = 1.4
		burst(3, 0.42, 0.35)
		t += 0.8
		burst(5, 0.28, 0.6, 0.7)
		t += 0.5
		burst(8, 0.19, 0.8, 0.95)
		hushTo = t + 1.2
		t += rand(6, 8)
		burst(1, 0, 1)
		t += 0.38
		burst(5, 0.17, 0.9, 0.7)
	else
		-- ไล่ระดับ: เหมือนแขกมาเยี่ยม -> ทุบรัว -> เงียบสนิท -> (70%) ทุบสุดท้าย
		t = 1.8
		burst(3, 0.55, 0.22)
		t += 1.5
		burst(3, 0.5, 0.42)
		t += 1.0
		burst(4, 0.36, 0.62, 0.7)
		t += 0.6
		burst(10, 0.19, 0.8, 0.95)
		t += rand(3, 4.6)
		hushTo = t
		if math.random() < 0.7 then
			burst(1, 0, 1)
		end
	end
	return { hits = hits, lines = lines, hushTo = hushTo, finish = t + 1.6 }
end

function KnockPlan.Encode(plan: Plan, t0: number): string
	local out = {}
	for _, h in ipairs(plan.hits) do
		table.insert(out, string.format("%.3f,%.2f", t0 + h.t, h.p))
	end
	return table.concat(out, ";")
end

function KnockPlan.Decode(s: string): { Hit }
	local hits: { Hit } = {}
	for t, p in string.gmatch(s, "([%d%.]+),([%d%.]+)") do
		table.insert(hits, { t = tonumber(t) :: number, p = tonumber(p) :: number })
	end
	return hits
end

-- มือยื่นแค่ไหน ณ เวลา now: 1 = แตะแผงพอดี (ตรงกับเสียง) · 0 = งอพัก · ติดลบ = ง้างไปหลัง (แรงมาก = ง้างมาก)
local STRIKE = 0.07 -- วิ: จากง้างถึงแตะ
local HOLD = 0.04
local BACK = 0.22 -- วิ: ดึงมือกลับ
function KnockPlan.Reach(hits: { Hit }, now: number): number
	local prev: Hit?, nxt: Hit? = nil, nil
	for _, h in ipairs(hits) do
		if h.t <= now then
			prev = h
		else
			nxt = h
			break
		end
	end
	local rest = 0.15
	local e = rest
	if prev then
		local dt = now - prev.t
		if dt < HOLD then
			e = 1
		elseif dt < HOLD + BACK then
			local k = (dt - HOLD) / BACK
			e = 1 + (rest - 1) * (k * k * (3 - 2 * k))
		end
	end
	if nxt then
		local gap = nxt.t - (if prev then prev.t + HOLD else -math.huge)
		local wind = math.min(0.2 + 0.12 * nxt.p, gap * 0.6)
		local left = nxt.t - now
		local pull = -0.35 - 0.5 * nxt.p
		local strike = math.min(STRIKE, wind * 0.4)
		if left < strike then
			local k = 1 - left / strike
			e = pull + (1 - pull) * k * k
		elseif left < wind then
			local k = 1 - (left - strike) / (wind - strike)
			e = e + (pull - e) * (k * k * (3 - 2 * k))
		end
	end
	return e
end

return KnockPlan
