--!strict
-- VehiclePaint.luau (ReplicatedStorage.Shared) — สุ่มสีรถลูกค้า (ผู้ใช้ 2026-11-08 "สีรถให้สุ่มมาได้ไหม")
--   มอไซค์ลูกค้ารุ่นใหม่ (tools/blender/customer_bike_v2.py) แยกชิ้นที่ทาสีออกมา: BodyPaint (ตัวถังท้าย + หน้ากาก)
--   และ HandlebarPaint (ฝาครอบแฮนด์ เรือนไฟหน้า ปลอกคอ บังโคลนหน้า) ผิวอบเป็นสีเทาอ่อน (มีฝุ่น สีถลอก แถบข้าง)
--   -> ย้อมทับด้วย SurfaceAppearance.Color ฝุ่น/รอยถลอก/ความเงายังอยู่ เบาะ ยาง เครื่อง ชิ้นชุบไม่เปลี่ยน
--   แถบข้างตัวรถอบขาวกว่าพื้น จึงออกมาเป็นสีเดียวกันแต่อ่อนกว่า
local VehiclePaint = {}

VehiclePaint.PARTS = { BodyPaint = true, HandlebarPaint = true }

-- สีรถบ้านนอกที่เห็นจริง (w = โอกาส)
VehiclePaint.PALETTE = {
	{ name = "red", c = Color3.fromRGB(128, 24, 26), w = 3 }, -- แดงเลือดหมู
	{ name = "blue", c = Color3.fromRGB(28, 52, 120), w = 3 }, -- น้ำเงิน
	{ name = "black", c = Color3.fromRGB(30, 30, 32), w = 2 }, -- ดำ
	{ name = "bronze", c = Color3.fromRGB(128, 118, 100), w = 2 }, -- เทาบรอนซ์
	{ name = "green", c = Color3.fromRGB(72, 86, 50), w = 1 }, -- เขียวขี้ม้า
	{ name = "white", c = Color3.fromRGB(200, 196, 184), w = 1 }, -- ขาวหม่น
	{ name = "orange", c = Color3.fromRGB(168, 78, 38), w = 1 }, -- ส้มอิฐ
}
VehiclePaint.DEFAULT = VehiclePaint.PALETTE[1].c

-- สุ่มสี (ถ่วงน้ำหนัก) + เพี้ยนนิดๆ ทีละคัน ไม่ให้เหมือนกันเป๊ะ
function VehiclePaint.Pick(): Color3
	local total = 0
	for _, p in ipairs(VehiclePaint.PALETTE) do
		total += p.w
	end
	local r = math.random() * total
	local pick = VehiclePaint.PALETTE[1]
	for _, p in ipairs(VehiclePaint.PALETTE) do
		r -= p.w
		if r <= 0 then
			pick = p
			break
		end
	end
	local h, s, v = pick.c:ToHSV()
	h = (h + (math.random() - 0.5) * 0.02) % 1
	s = math.clamp(s * (0.9 + math.random() * 0.2), 0, 1)
	v = math.clamp(v * (0.88 + math.random() * 0.24), 0, 1)
	return Color3.fromHSV(h, s, v)
end

function VehiclePaint.Apply(m: Instance, color: Color3)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and VehiclePaint.PARTS[d.Name] then
			local sa = d:FindFirstChildOfClass("SurfaceAppearance")
			local ok = sa ~= nil and pcall(function()
				(sa :: any).Color = color
			end)
			if not ok then
				d.Color = color -- ไม่มี SurfaceAppearance: ใช้สีของชิ้นแทน
			end
		end
	end
	if m:IsA("Model") then
		m:SetAttribute("PaintColor", color)
	end
end

function VehiclePaint.Randomize(m: Instance)
	VehiclePaint.Apply(m, VehiclePaint.Pick())
end

return VehiclePaint
