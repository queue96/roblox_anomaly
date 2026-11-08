# GasPump v2 — ตู้ปั๊มน้ำมันหลอดแก้วมือหมุนแบบชนบทไทย ปั้นใหม่ทั้งตู้ (ผู้ใช้ 2026-11-08 "ปั้นใหม่เลยขอดีๆ ละเอียดๆ")
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/gas_pump_v2.py
# ผลลัพธ์: assets/models/GasPumpV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ tools/blender/vehlib.py + proplib.py · แกน Blender: หน้าตู้ -Y, +X = ขวามือคนยืนหน้าตู้ (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
#
# ชื่อชิ้น (เกมใช้ชื่อเหล่านี้ อย่าเปลี่ยน · ดู MapBuilder.SwapGasPumpV2):
#   GasPump     ตัวตู้ + แท่นปูน + สายยาง + ป้ายบนหัว (ชิ้นเดียวที่ชน, PumpFuelPrompt อยู่ที่นี่)
#   GlassTube   หลอดแก้ว (ในเกมตั้ง Glass โปร่ง 0.55 เอง ไม่ bake)
#   FuelLiquid  น้ำมันเต็มหลอด (CoreLoop ยืด Size.Y จากก้นหลอด · สีอบเป็นครีมอ่อน เกมย้อม SurfaceAppearance.Color เป็นเบนซินส้ม/ดีเซลเขียว)
#   HandCrank   มือหมุนข้างตู้ (ฝั่ง +X) ดุมหมุนที่ CRANK_HUB แกนหมุน = แกน X
#   Nozzle      หัวจ่ายทองเหลืองแขวนตะขอ (ฝั่ง -X)
# ขนาดเทียบตู้เดิม: ตัวตู้ 3.42 x 7.13 x 3.46 · หลอดแก้ว Ø1.50 สูง 2.49 (ก้น 3.33) · น้ำมัน Ø1.37 สูง 1.71
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "GasPumpV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, tube, lathe, put, L = V.G, V.box, V.tube, V.lathe_axis, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)

BODY, GLASS, LIQ, CRANK, NOZ = "GasPump", "GlassTube", "FuelLiquid", "HandCrank", "Nozzle"

# ---------------------------------------------------------------- สัดส่วนหลัก (studs)
PAD_H = 0.45            # แท่นปูน
CAB_Z0, CAB_Z1 = 0.78, 3.15   # ตู้เหล็ก
CAB_HX, CAB_HY = 1.08, 0.98   # ครึ่งกว้าง / ครึ่งลึก
GL_Z0, GL_Z1 = 3.50, 5.95     # หลอดแก้ว
GL_R, GL_T = 0.75, 0.035
LQ_R, LQ_Z0, LQ_Z1 = 0.70, 3.53, 5.30   # น้ำมันเต็มหลอด (เว้นช่องอากาศด้านบน)
CRANK_HUB = Vector((CAB_HX + 0.02, 0.05, 2.35))
FRONT = -CAB_HY

# ---------------------------------------------------------------- วัสดุ
V.make_mat("Concrete", L((128, 126, 120)), 0.95, dirt=0.6, bump=0.5, bump_scale=35)
V.make_mat("RedPaint", L((150, 36, 28)), 0.55, metal=0.15, dirt=0.45, wear=0.55, rust=0.12, coat=0.15)
V.make_mat("CreamPaint", L((212, 198, 160)), 0.6, metal=0.05, dirt=0.55, wear=0.5, rust=0.05)
V.make_mat("DarkSteel", L((52, 52, 55)), 0.55, metal=0.6, dirt=0.4, wear=0.4, rust=0.25)
V.make_mat("Galv", L((150, 152, 148)), 0.45, metal=0.85, dirt=0.45, wear=0.2, rust=0.08)
V.make_mat("Chrome", L((205, 205, 210)), 0.2, metal=1.0, dirt=0.25)
V.make_mat("Brass", L((178, 138, 62)), 0.35, metal=1.0, dirt=0.35, wear=0.3)
V.make_mat("Rubber", L((28, 27, 26)), 0.8, dirt=0.3, bump=0.25, bump_scale=90)
V.make_mat("Oil", L((22, 18, 14)), 0.15, dirt=0.0)
P.flat("DialFace", L((230, 222, 196)), rough=0.4, dirt=0.3)
P.flat("Ink", L((25, 22, 20)), rough=0.5, dirt=0.0)
P.wood("Grip", L((112, 70, 38)), rough=0.6, dirt=0.35, grain_axis="X", grain=2.0)
P.flat("Glass", L((205, 225, 215)), rough=0.05, dirt=0.0, noise=0.0)
P.flat("Liquid", L((238, 226, 200)), rough=0.12, dirt=0.0, noise=0.008)

# ---------------------------------------------------------------- แท่นปูน + ถาดรองน้ำมัน
put(BODY, box((0, 0, PAD_H / 2), (3.05, 3.05, PAD_H)), "Concrete", bevel=0.07)
put(BODY, box((0, -1.22, PAD_H + 0.03), (1.05, 0.42, 0.06)), "Galv", bevel=0.015)          # ถาดสังกะสีหน้าตู้
put(BODY, box((0.05, -1.22, PAD_H + 0.065), (0.8, 0.28, 0.01)), "Oil")                     # คราบน้ำมันในถาด
put(BODY, P.extrude_z([(math.cos(a) * r, -1.45 + math.sin(a) * r * 0.6) for a, r in
                       [(i * math.pi / 5, 0.32 + 0.08 * math.sin(i * 2.3)) for i in range(10)]], PAD_H, PAD_H + 0.004), "Oil")  # หยดเลอะบนปูน

# ---------------------------------------------------------------- ตู้เหล็ก
put(BODY, box((0, 0, PAD_H + 0.16), (2.42, 2.22, 0.32)), "DarkSteel", bevel=0.04)            # ฐานรอง (ขาตู้)
rings = []
for z, k in ((CAB_Z0, 1.0), (CAB_Z0 + 0.04, 1.0), (CAB_Z1 - 0.04, 0.975), (CAB_Z1, 0.975)):
    rings.append(V.ring_z(0, 0, z, CAB_HX * k, CAB_HY * k, n=36, p=7))
put(BODY, V.loft(rings), "RedPaint")
# คิ้วคาดเอว (ขอบเหล็กพับ)
for z in (CAB_Z0 + 0.06, CAB_Z1 - 0.12):
    rr = [V.ring_z(0, 0, z, CAB_HX + 0.03, CAB_HY + 0.03, n=36, p=7), V.ring_z(0, 0, z + 0.07, CAB_HX + 0.03, CAB_HY + 0.03, n=36, p=7)]
    put(BODY, V.loft(rr), "DarkSteel")

# ประตูหน้าตู้ (แผงครีม + กรอบ + บานพับ + มือจับ + กุญแจ)
DZ0, DZ1, DX = 1.05, 2.55, 0.72
put(BODY, box((0, FRONT - 0.035, (DZ0 + DZ1) / 2), (DX * 2, 0.07, DZ1 - DZ0)), "CreamPaint", bevel=0.02)
for (c, s) in (((0, FRONT - 0.05, DZ1 + 0.04), (DX * 2 + 0.16, 0.06, 0.08)), ((0, FRONT - 0.05, DZ0 - 0.04), (DX * 2 + 0.16, 0.06, 0.08)),
               ((DX + 0.04, FRONT - 0.05, (DZ0 + DZ1) / 2), (0.08, 0.06, DZ1 - DZ0 + 0.16)), ((-DX - 0.04, FRONT - 0.05, (DZ0 + DZ1) / 2), (0.08, 0.06, DZ1 - DZ0 + 0.16))):
    put(BODY, box(c, s), "RedPaint", bevel=0.015)
for z in (DZ0 + 0.25, DZ1 - 0.25):
    put(BODY, P.cyl((-DX - 0.05, FRONT - 0.09, z - 0.13), ZUP, 0.04, 0.26, n=8), "DarkSteel")
put(BODY, box((DX - 0.16, FRONT - 0.09, 1.85), (0.07, 0.07, 0.36)), "Chrome", bevel=0.015)        # มือจับ
put(BODY, box((DX - 0.16, FRONT - 0.12, 1.63), (0.14, 0.04, 0.08)), "DarkSteel")                  # หูคล้องกุญแจ
put(BODY, box((DX - 0.16, FRONT - 0.17, 1.53), (0.16, 0.08, 0.16)), "Brass", bevel=0.02)           # แม่กุญแจ
put(BODY, V.tube(V.arc((FRONT - 0.17, 1.62), 0.05, 0, math.pi, 8, x=DX - 0.16), 0.012, n=6), "Chrome")
# ช่องระบายอากาศบนประตู (บานเกล็ด 5 ซี่)
put(BODY, box((0, FRONT - 0.072, 1.54), (0.86, 0.012, 0.66)), "DarkSteel")
for i in range(5):
    z = 1.3 + i * 0.12
    put(BODY, P.box_rot((0, FRONT - 0.09, z), (0.8, 0.03, 0.09), "X", -35), "CreamPaint")
# หมุดย้ำรอบประตู
for i in range(6):
    x = -DX + i * (2 * DX) / 5
    for z in (DZ1 + 0.04, DZ0 - 0.04):
        put(BODY, P.dome((x, FRONT - 0.08, z), (0, -1, 0), 0.025, 0.02), "DarkSteel")
# ป้ายทองเหลืองเปล่าใต้ประตู (ไม่มียี่ห้อ)
put(BODY, box((0, FRONT - 0.03, 0.9), (0.7, 0.03, 0.14)), "Brass", bevel=0.01)

# หน้าปัดวัดลิตร (เหนือประตู)
DIAL_C = Vector((0, FRONT - 0.02, 2.86))
put(BODY, P.ring_band(DIAL_C, (0, -1, 0), 0.2, 0.25, 0.0, 0.08, n=24), "Chrome")
put(BODY, P.cyl(DIAL_C, (0, -1, 0), 0.205, 0.04, n=24), "DialFace")
for i in range(11):
    a = math.radians(225 - i * 27)
    r0, r1 = (0.13 if i % 5 == 0 else 0.16), 0.19
    p0 = DIAL_C + Vector((math.cos(a) * r0, -0.045, math.sin(a) * r0))
    p1 = DIAL_C + Vector((math.cos(a) * r1, -0.045, math.sin(a) * r1))
    put(BODY, V.tube([tuple(p0), tuple(p1)], 0.008, n=4), "Ink")
na = math.radians(150)
put(BODY, V.tube([tuple(DIAL_C + Vector((0, -0.05, 0))), tuple(DIAL_C + Vector((math.cos(na) * 0.17, -0.05, math.sin(na) * 0.17)))], 0.01, n=4), "RedPaint")
put(BODY, P.dome(DIAL_C + Vector((0, -0.045, 0)), (0, -1, 0), 0.025, 0.015), "Chrome")

# บานเกล็ดข้างตู้ทั้ง 2 ฝั่ง
for sx in (1, -1):
    for i in range(6):
        z = 1.15 + i * 0.11
        put(BODY, P.box_rot((sx * (CAB_HX + 0.01), 0.35, z), (0.03, 0.75, 0.07), "Y", sx * 35), "RedPaint")
    for z in (1.02, 1.82):
        put(BODY, box((sx * (CAB_HX + 0.01), 0.35, z), (0.035, 0.9, 0.04)), "DarkSteel")

# ฝาตู้ + ฐานรองหลอดแก้ว
put(BODY, V.loft([V.ring_z(0, 0, CAB_Z1, 1.16, 1.06, n=36, p=7), V.ring_z(0, 0, CAB_Z1 + 0.18, 1.12, 1.02, n=36, p=7)]), "DarkSteel")
put(BODY, lathe((0, 0, CAB_Z1 + 0.18), ZUP, [(0, 0.98), (0.06, 0.98), (0.1, 0.9), (0.17, 0.88), (0.2, 0.84), (GL_Z0 - CAB_Z1 - 0.18 + 0.04, 0.84), (GL_Z0 - CAB_Z1 - 0.18 + 0.04, 0.0)], n=40), "Galv")
for i in range(8):                                     # น็อตยึดฐาน
    a = 2 * math.pi * (i + 0.5) / 8
    put(BODY, P.cyl((math.cos(a) * 0.93, math.sin(a) * 0.93, CAB_Z1 + 0.18), ZUP, 0.045, 0.06, n=6), "DarkSteel")

# ปลอกหลอดบน/ล่าง + เสาค้ำ 4 ต้น + แถบสเกลลิตร
put(BODY, P.ring_band((0, 0, 0), ZUP, GL_R - 0.01, GL_R + 0.07, GL_Z0 - 0.04, GL_Z0 + 0.1, n=40), "Galv")
put(BODY, P.ring_band((0, 0, 0), ZUP, GL_R - 0.01, GL_R + 0.07, GL_Z1 - 0.1, GL_Z1 + 0.04, n=40), "Galv")
for a in (45, 135, 225, 315):
    r = GL_R + 0.11
    x, y = math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r
    put(BODY, P.cyl((x, y, GL_Z0 - 0.04), ZUP, 0.045, GL_Z1 - GL_Z0 + 0.12, n=10), "Galv")
SA = math.radians(300)  # แถบสเกลด้านหน้าขวา
sx, sy = math.cos(SA), math.sin(SA)
tang = Vector((-sy, sx, 0))
put(BODY, P.box_rot((sx * (GL_R + 0.035), sy * (GL_R + 0.035), (LQ_Z0 + GL_Z1) / 2), (0.12, 0.02, GL_Z1 - LQ_Z0 - 0.12), "Z", math.degrees(SA) + 90), "Brass")
for i in range(11):                                   # ขีด 0-10 ลิตร (ขีดยาวทุก 5)
    z = LQ_Z0 + (LQ_Z1 - LQ_Z0) * i / 10
    w = 0.1 if i % 5 == 0 else 0.06
    c = Vector((sx * (GL_R + 0.05), sy * (GL_R + 0.05), z)) - tang * (0.06 - w / 2)
    put(BODY, P.box_rot(tuple(c), (w, 0.012, 0.018), "Z", math.degrees(SA) + 90), "Ink")

# หัวโดม + ท่อน้ำมันไหลกลับด้านหลัง + ป้ายวงกลม
TOP = GL_Z1 + 0.04
put(BODY, lathe((0, 0, TOP), ZUP, [(0, 0.88), (0.08, 0.88), (0.12, 0.84), (0.25, 0.74), (0.4, 0.52), (0.5, 0.26), (0.54, 0.0)], n=40), "RedPaint", subdiv=1)
put(BODY, P.ring_band((0, 0, 0), ZUP, 0.86, 0.91, TOP - 0.02, TOP + 0.1, n=40), "DarkSteel")
for i in range(10):
    a = 2 * math.pi * i / 10
    put(BODY, P.dome((math.cos(a) * 0.91, math.sin(a) * 0.91, TOP + 0.04), (math.cos(a), math.sin(a), 0), 0.025, 0.018), "DarkSteel")
put(BODY, V.tube(P.spline([(0, 0.62, TOP + 0.3), (0, 0.95, TOP + 0.26), (0, 1.04, TOP), (0, 1.04, CAB_Z1 + 0.6), (0, 1.0, CAB_Z1 + 0.18)], per=6), 0.05, n=10), "Galv")
put(BODY, P.cyl((0, 0, TOP + 0.5), ZUP, 0.05, 0.35, n=10), "DarkSteel")            # เสาป้าย
SIGN_C = Vector((0, 0, TOP + 0.85 + 0.48))
put(BODY, lathe(SIGN_C - Vector((0, 0.045, 0)), YAX, [(0, 0), (0, 0.42), (-0.01, 0.48), (0.03, 0.5), (0.06, 0.5), (0.1, 0.48), (0.09, 0.42), (0.09, 0.0)], n=40), "RedPaint")
put(BODY, P.cyl(SIGN_C + Vector((0, -0.055, 0)), YAX, 0.415, 0.11, n=40), "CreamPaint")
drop = []
for i in range(24):                                    # หยดน้ำมันนูนสองหน้า (ปลายแหลมด้านบน)
    t = 2 * math.pi * i / 24
    drop.append((SIGN_C.x - 0.19 * math.sin(t) * math.sin(t / 2), SIGN_C.z - 0.02 + 0.24 * math.cos(t)))
put(BODY, P.extrude_y(drop, -0.085, 0.085), "Ink")   # สีดำ: หยดแดงดูเป็นเลือด (ซ้ำกับผีน้ำมันเลือด + กฎ moderation)
put(BODY, P.dome((0, 0, TOP + 0.54), ZUP, 0.08, 0.05, n=10), "Chrome")

# ---------------------------------------------------------------- สายยาง (ฝั่ง -X) + ตะขอแขวนหัวจ่าย
OUTLET = Vector((-CAB_HX - 0.02, 0.45, 2.75))
put(BODY, P.cyl(OUTLET, (-1, 0, 0), 0.11, 0.12, n=10), "Brass")
put(BODY, P.cyl(OUTLET + Vector((-0.12, 0, 0)), (-1, 0, 0), 0.08, 0.1, n=10), "Brass")
HOOK = Vector((-CAB_HX - 0.02, -0.55, 2.40))
# ตะขอ: ยื่นออกจากตู้ 0.16 แล้วงอขึ้น (ปากหัวจ่ายคล้องอยู่บนปลายตะขอ)
put(BODY, V.tube([tuple(HOOK), tuple(HOOK + Vector((-0.12, 0, 0))), tuple(HOOK + Vector((-0.16, 0, 0.04))), tuple(HOOK + Vector((-0.16, 0, 0.12)))], 0.025, n=6), "DarkSteel")
put(BODY, box(tuple(HOOK + Vector((0.01, 0, 0))), (0.03, 0.14, 0.14)), "DarkSteel")
NOZ_X = HOOK.x - 0.30            # แนวด้ามหัวจ่าย (ห้อยตั้งข้างตู้)
NOZ_BOT = Vector((NOZ_X, HOOK.y, 1.72))   # ท้ายด้าม = ที่สายยางเข้า
NOZ_HEAD = Vector((NOZ_X, HOOK.y, 2.36))
hose = P.spline([tuple(OUTLET + Vector((-0.22, 0, 0))), (-1.42, 0.5, 2.5), (-1.58, 0.42, 1.6), (-1.52, 0.15, 0.85), (-1.44, -0.25, 0.68),
                 (-1.40, -0.55, 0.95), (NOZ_X, HOOK.y, 1.35), tuple(NOZ_BOT)], per=7)
put(BODY, V.tube(hose, 0.075, n=10), "Rubber")
# ปลอกรัดสายยางตามช่วง
for k in (3, 18, 36):
    p = Vector(hose[k])
    put(BODY, V.tube([tuple(p + (Vector(hose[k + 1]) - p).normalized() * -0.03), tuple(p + (Vector(hose[k + 1]) - p).normalized() * 0.03)], 0.088, n=10), "Galv")

# ---------------------------------------------------------------- หลอดแก้ว (ผนังสองชั้นให้เห็นทั้งด้านหน้าและหลัง)
put(GLASS, lathe((0, 0, 0), ZUP, [(GL_Z0, GL_R - GL_T), (GL_Z0, GL_R), (GL_Z1, GL_R), (GL_Z1, GL_R - GL_T), (GL_Z0 + 0.001, GL_R - GL_T)], n=48), "Glass")

# ---------------------------------------------------------------- น้ำมัน (ทรงกระบอกตัน ยืดตามแกนตั้งในเกม)
put(LIQ, lathe((0, 0, 0), ZUP, [(LQ_Z0, 0.0), (LQ_Z0, LQ_R), (LQ_Z1 - 0.02, LQ_R), (LQ_Z1, LQ_R - 0.03), (LQ_Z1, 0.0)], n=40), "Liquid")

# ---------------------------------------------------------------- มือหมุน (ฝั่ง +X)
H = CRANK_HUB
put(CRANK, P.cyl(H, XAX, 0.2, 0.08, n=20), "DarkSteel")
put(CRANK, P.cyl(H + Vector((0.08, 0, 0)), XAX, 0.07, 0.18, n=12), "Galv")
ARM_END = H + Vector((0.26, -0.18, -0.62))
put(CRANK, V.tube([tuple(H + Vector((0.26, 0, 0))), tuple(H + Vector((0.26, -0.09, -0.31))), tuple(ARM_END)], [0.07, 0.06, 0.05], n=10), "RedPaint")
put(CRANK, P.cyl(H + Vector((0.2, 0, 0)), XAX, 0.1, 0.12, n=14), "RedPaint")
put(CRANK, P.cyl(ARM_END, XAX, 0.035, 0.42, n=8), "Galv")
put(CRANK, V.lathe_axis(ARM_END + Vector((0.06, 0, 0)), XAX, [(0, 0.04), (0.02, 0.075), (0.15, 0.085), (0.28, 0.075), (0.32, 0.04)], n=14), "Grip")
put(CRANK, P.dome(ARM_END + Vector((0.42, 0, 0)), XAX, 0.05, 0.035), "Galv")

# ---------------------------------------------------------------- หัวจ่าย (แขวนตะขอ)
# ท้ายด้ามยาง (สายยางเข้าจากด้านล่าง) -> ด้ามจับ -> หัวทองเหลือง -> ปากจ่ายงอโค้งข้ามปลายตะขอแล้วชี้ลง
put(NOZ, V.lathe_axis(NOZ_BOT - Vector((0, 0, 0.04)), ZUP, [(0, 0.06), (0.02, 0.095), (0.12, 0.095), (0.14, 0.08)], n=14), "Brass")
put(NOZ, V.lathe_axis(NOZ_BOT + Vector((0, 0, 0.1)), ZUP, [(0, 0.075), (0.04, 0.085), (0.4, 0.085), (0.44, 0.075)], n=14), "Rubber")
for k in range(5):                                       # ร่องกันลื่นบนด้าม
    put(NOZ, P.ring_band(NOZ_BOT + Vector((0, 0, 0.17 + k * 0.07)), ZUP, 0.08, 0.092, 0.0, 0.02, n=14), "Rubber")
put(NOZ, V.lathe_axis(NOZ_HEAD - Vector((0, 0, 0.1)), ZUP, [(0, 0.09), (0.04, 0.11), (0.16, 0.11), (0.2, 0.085)], n=14), "Brass")
sp = P.spline([tuple(NOZ_HEAD + Vector((0, 0, 0.08))), tuple(NOZ_HEAD + Vector((0.04, 0, 0.2))), tuple(NOZ_HEAD + Vector((0.14, 0, 0.24))),
               tuple(NOZ_HEAD + Vector((0.24, 0, 0.17))), tuple(NOZ_HEAD + Vector((0.27, 0, 0.02)))], per=5)
put(NOZ, V.tube(sp, [0.05] * (len(sp) - 3) + [0.045, 0.04, 0.036], n=10), "Brass")
put(NOZ, P.ring_band(Vector(sp[-1]) - Vector((0, 0, 0.0)), (0, 0, -1), 0.0, 0.045, 0.0, 0.04, n=10), "DarkSteel")
put(NOZ, V.tube(V.arc((NOZ_HEAD.y, NOZ_HEAD.z - 0.3), 0.17, math.radians(105), math.radians(255), 10, plane="yz", x=NOZ_X), 0.018, n=6), "Galv")   # การ์ดไก (ด้านหน้า)
put(NOZ, P.box_rot(tuple(NOZ_HEAD + Vector((0, -0.12, -0.3))), (0.04, 0.05, 0.34), "X", -6), "DarkSteel")                                                 # ไกจ่าย

# ---------------------------------------------------------------- object + bake + export
ORDER = [BODY, GLASS, LIQ, CRANK, NOZ]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"CRANK_HUB_rbx=({-CRANK_HUB.x:.3f},{CRANK_HUB.z:.3f},{CRANK_HUB.y:.3f})")
if not NO_BAKE:
    P.bake_all(OBJ, {BODY: "GasPumpV2_Body", LIQ: "GasPumpV2_Liquid", CRANK: "GasPumpV2_Crank", NOZ: "GasPumpV2_Nozzle"},
               {BODY: 1024, LIQ: 256, CRANK: 512, NOZ: 512})
P.export_fbx(OBJ, os.path.join(UP, "GasPumpV2.fbx"), BODY)


def preview():
    gm = OBJ[GLASS].data.materials[0]
    bs = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Alpha"].default_value = 0.3
    bs.inputs["Transmission Weight"].default_value = 0.6
    lm = OBJ[LIQ].data.materials[0]
    lb = next(n for n in lm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    # ตัวอย่างใช้สีเบนซิน (ในเกมย้อมด้วย SurfaceAppearance.Color)
    if not lb.inputs["Base Color"].links:
        lb.inputs["Base Color"].default_value = (0.75, 0.32, 0.05, 1)
    else:
        mix = lm.node_tree.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = (0.85, 0.36, 0.06, 1)
        src = lb.inputs["Base Color"].links[0].from_socket
        lm.node_tree.links.new(src, mix.inputs["A"])
        lm.node_tree.links.new(mix.outputs["Result"], lb.inputs["Base Color"])
    cam, sun, world = P.stage()
    P.add_person(ROOT, (3.2, -0.6, 0.0), yaw_deg=-20)
    P.shot(cam, os.path.join(OUT, "GasPumpV2.png"), (0, 0, 3.6), (-0.75, -1.25, 0.35), 15.5)
    P.shot(cam, os.path.join(OUT, "GasPumpV2_front.png"), (0, 0, 3.8), (0.0, -1.0, 0.12), 13.0)
    P.shot(cam, os.path.join(OUT, "GasPumpV2_crank.png"), (0.6, -0.2, 2.6), (1.0, -0.8, 0.25), 7.0)
    P.shot(cam, os.path.join(OUT, "GasPumpV2_hose.png"), (-1.1, -0.3, 1.9), (-1.0, -0.9, 0.2), 7.0)
    P.shot(cam, os.path.join(OUT, "GasPumpV2_top.png"), (0, 0, 5.6), (-0.4, -1.0, 0.3), 7.5)
    P.night(world, sun, (1.5, -5.0, 9.0), energy=90)
    P.shot(cam, os.path.join(OUT, "GasPumpV2_night.png"), (0, 0, 3.6), (-0.6, -1.3, 0.3), 15.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "gas_pump_v2.blend"))
P.log("done")
