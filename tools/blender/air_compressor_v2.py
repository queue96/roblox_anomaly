# AirCompressor v2 — ถังปั๊มลมร้านปะยาง (ถังนอน + หัวปั๊มลูกสูบคู่ตัววี + มอเตอร์ + สายพาน) ปั้นใหม่ทั้งชุด (ผู้ใช้ 2026-11-08 "ขอดีๆ ละเอียดๆ")
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/air_compressor_v2.py
# ผลลัพธ์: assets/models/AirCompressorV2/upload/ (FBX + texture) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ vehlib.py + proplib.py · แกน Blender: หน้าถัง -Y (หันออกถนน), ถังยาวตามแกน X (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
#
# ชื่อชิ้น (ดู MapBuilder.SwapAirCompressorV2):
#   AirCompressor         ตัวถัง + หัวปั๊ม + มอเตอร์ + สายลม (ชิ้นใหญ่สุด CoreLoop เอา AirPumpPrompt มาติดที่นี่ · ชิ้นเดียวที่ชน)
#   Flywheel              มู่เล่หัวปั๊ม (แยกไว้หมุนได้ แกนหมุน = แกน Y ที่ FLY_C)
#   PressureGauge_Needle  เข็มเกจ (แยกไว้ขยับ ศูนย์หมุนที่ GAUGE_C แกน Y)
#   ReliefValve           วาล์วนิรภัยทองเหลือง (ชื่อเดิม)
# ขนาดเทียบของเดิม: 4.45 x 4.00 x 2.46
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "AirCompressorV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, tube, lathe, put, L = V.G, V.box, V.tube, V.lathe_axis, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)

MAIN, FLY, NEEDLE, VALVE = "AirCompressor", "Flywheel", "PressureGauge_Needle", "ReliefValve"

TANK_Z, TANK_R, TANK_HL = 1.42, 0.72, 1.50       # ศูนย์กลางถัง / รัศมี / ครึ่งความยาวช่วงตรง
PLATE_Z = 2.22                                     # แผ่นแท่นเครื่องบนถัง (ผิวบน)
FLY_C = Vector((-0.72, -0.66, 2.62))               # ศูนย์มู่เล่ (หน้าหัวปั๊ม)
FLY_R = 0.56
MOT_C = Vector((0.62, -0.05, 2.58))                # มอเตอร์ (แกนตามแนว Y)
PUL_C = Vector((MOT_C.x, -0.66, MOT_C.z))
PUL_R = 0.13
GAUGE_C = Vector((1.46, -0.42, 3.02))              # หน้าปัดเกจ (หันหน้า -Y)

# ---------------------------------------------------------------- วัสดุ
V.make_mat("TankPaint", L((46, 88, 132)), 0.55, metal=0.15, dirt=0.55, wear=0.55, rust=0.18, coat=0.1)
V.make_mat("CastIron", L((58, 58, 60)), 0.6, metal=0.55, dirt=0.5, wear=0.35, rust=0.15, bump=0.25, bump_scale=120)
V.make_mat("Alu", L((165, 167, 168)), 0.45, metal=0.9, dirt=0.55, wear=0.2)
V.make_mat("MotorPaint", L((128, 146, 136)), 0.6, metal=0.1, dirt=0.55, wear=0.45, rust=0.08)
V.make_mat("DarkSteel", L((50, 50, 53)), 0.55, metal=0.6, dirt=0.45, wear=0.35, rust=0.25)
V.make_mat("Galv", L((150, 152, 148)), 0.45, metal=0.85, dirt=0.45, wear=0.2, rust=0.06)
V.make_mat("Copper", L((176, 104, 64)), 0.4, metal=1.0, dirt=0.45, wear=0.2)
V.make_mat("Brass", L((178, 138, 62)), 0.35, metal=1.0, dirt=0.35, wear=0.3)
V.make_mat("Chrome", L((205, 205, 210)), 0.2, metal=1.0, dirt=0.25)
V.make_mat("Rubber", L((26, 25, 24)), 0.82, dirt=0.35, bump=0.25, bump_scale=90)
V.make_mat("RedHose", L((150, 30, 26)), 0.55, dirt=0.45)
V.make_mat("Belt", L((30, 29, 28)), 0.75, dirt=0.3)
V.make_mat("YellowPaint", L((205, 160, 40)), 0.55, dirt=0.5, wear=0.5, rust=0.1)
P.flat("DialFace", L((232, 226, 205)), rough=0.4, dirt=0.3)
P.flat("Ink", L((25, 22, 20)), rough=0.5, dirt=0.0)
P.flat("RedInk", L((170, 30, 25)), rough=0.5, dirt=0.0)
P.flat("Label", L((224, 190, 60)), rough=0.6, dirt=0.4)
P.flat("Cable", L((20, 20, 20)), rough=0.6, dirt=0.3)


def convex_hull(pts):
    pts = sorted(set(pts))

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def circles_hull(cs, n=40):
    """ขอบนอกของวงกลมหลายวง (x, z, r) = เส้นสายพาน / ฝาครอบ"""
    pts = []
    for cx, cz, r in cs:
        for i in range(n):
            a = 2 * math.pi * i / n
            pts.append((round(cx + r * math.cos(a), 5), round(cz + r * math.sin(a), 5)))
    return convex_hull(pts)


def z_range_in(poly, x):
    zs = []
    n = len(poly)
    for i in range(n):
        (x0, z0), (x1, z1) = poly[i], poly[(i + 1) % n]
        if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
            zs.append(z0 + (z1 - z0) * (x - x0) / (x1 - x0))
    return (min(zs), max(zs)) if len(zs) >= 2 else None


# ---------------------------------------------------------------- ถังลม
prof = [(-TANK_HL - 0.36, 0.0), (-TANK_HL - 0.34, 0.2), (-TANK_HL - 0.28, 0.4), (-TANK_HL - 0.18, 0.58), (-TANK_HL - 0.07, 0.69), (-TANK_HL, TANK_R),
        (TANK_HL, TANK_R), (TANK_HL + 0.07, 0.69), (TANK_HL + 0.18, 0.58), (TANK_HL + 0.28, 0.4), (TANK_HL + 0.34, 0.2), (TANK_HL + 0.36, 0.0)]
put(MAIN, lathe((0, 0, TANK_Z), XAX, prof, n=48), "TankPaint")
for x in (-TANK_HL, TANK_HL):                                   # รอยเชื่อมฝาถัง
    put(MAIN, P.ring_band((0, 0, TANK_Z), XAX, TANK_R - 0.02, TANK_R + 0.018, x - 0.025, x + 0.025, n=48), "TankPaint")
put(MAIN, box((0, 0, TANK_Z - TANK_R - 0.005), (TANK_HL * 2, 0.05, 0.03)), "TankPaint")   # รอยเชื่อมใต้ถัง
# ป้ายเหลืองเตือน + ป้ายทองเหลืองบอกแรงดัน (แปะโค้งตามถัง: แผ่นบางหลายชิ้น)
for (x0, x1, a0, a1, mat) in ((-0.45, 0.35, 235, 280, "Label"), (0.65, 1.05, 250, 275, "Brass")):
    rings = []
    for x in (x0, x1):
        r = TANK_R + 0.006
        rings.append([(x, math.cos(math.radians(a)) * r, TANK_Z + math.sin(math.radians(a)) * r) for a in [a0 + (a1 - a0) * i / 8 for i in range(9)]] +
                     [(x, math.cos(math.radians(a)) * (r + 0.01), TANK_Z + math.sin(math.radians(a)) * (r + 0.01)) for a in [a1 - (a1 - a0) * i / 8 for i in range(9)]])
    put(MAIN, V.loft(rings), mat)
# ลายบนป้ายเหลือง: ขีดดำ (เหมือนตัวหนังสือจางๆ ไม่มียี่ห้อ)
for k in range(4):
    a = math.radians(243 + k * 9)
    r = TANK_R + 0.018
    put(MAIN, P.box_rot((-0.05, math.cos(a) * r, TANK_Z + math.sin(a) * r), (0.6 - k * 0.08, 0.008, 0.03), "X", math.degrees(a) - 270), "Ink")

# ขา: ล้อ 2 ข้างฝั่ง -X, ขาเหล็กฉากฝั่ง +X, มือจับ
AX_X, WR = -1.12, 0.36
put(MAIN, P.cyl((AX_X, -0.92, WR), YAX, 0.035, 1.84, n=8), "DarkSteel")
for sy in (1, -1):
    # แผ่นยึดเพลา
    put(MAIN, V.loft([[(AX_X - 0.12, sy * 0.38, WR - 0.06), (AX_X + 0.12, sy * 0.38, WR - 0.06), (AX_X + 0.18, sy * 0.38, TANK_Z - 0.55), (AX_X - 0.18, sy * 0.38, TANK_Z - 0.55)],
                      [(AX_X - 0.12, sy * 0.44, WR - 0.06), (AX_X + 0.12, sy * 0.44, WR - 0.06), (AX_X + 0.18, sy * 0.44, TANK_Z - 0.55), (AX_X - 0.18, sy * 0.44, TANK_Z - 0.55)]]), "TankPaint")
    # ล้อ: ยางตัน + กระทะเหล็กมีรู
    wy = sy * 0.82
    put(MAIN, lathe((AX_X, wy, WR), YAX, [(-0.07, 0.2), (-0.08, 0.3), (-0.06, 0.35), (0.0, WR), (0.06, 0.35), (0.08, 0.3), (0.07, 0.2)], n=28), "Rubber")
    put(MAIN, lathe((AX_X, wy, WR), YAX, [(-0.07, 0.0), (-0.07, 0.08), (-0.05, 0.1), (-0.05, 0.2), (0.05, 0.2), (0.05, 0.1), (0.07, 0.08), (0.07, 0.0)], n=20), "YellowPaint")
    for i in range(5):
        a = 2 * math.pi * i / 5
        put(MAIN, P.cyl((AX_X + math.cos(a) * 0.145, wy - sy * 0.055, WR + math.sin(a) * 0.145), (0, -sy, 0), 0.03, 0.005, n=8), "DarkSteel")
    put(MAIN, P.dome((AX_X, wy + sy * 0.07, WR), (0, sy, 0), 0.05, 0.04), "Galv")
    # ขาฉากฝั่ง +X
    lx = 1.15
    put(MAIN, V.tube([(lx - 0.05, sy * 0.3, TANK_Z - 0.62), (lx + 0.02, sy * 0.48, 0.45), (lx + 0.04, sy * 0.52, 0.06)], 0.05, n=6), "TankPaint")
    put(MAIN, P.cyl((lx + 0.04, sy * 0.52, 0.0), ZUP, 0.12, 0.07, n=12), "Rubber")
# มือจับลาก (ฝั่ง +X)
hx = TANK_HL + 0.42
put(MAIN, V.tube(P.spline([(TANK_HL + 0.18, 0.42, TANK_Z + 0.42), (hx, 0.45, TANK_Z + 0.62), (hx + 0.1, 0.3, TANK_Z + 0.78), (hx + 0.1, -0.3, TANK_Z + 0.78),
                           (hx, -0.45, TANK_Z + 0.62), (TANK_HL + 0.18, -0.42, TANK_Z + 0.42)], per=6), 0.045, n=8), "DarkSteel")
put(MAIN, P.cyl((hx + 0.1, -0.24, TANK_Z + 0.78), YAX, 0.07, 0.48, n=12), "Rubber")

# วาล์วถ่ายน้ำใต้ถัง + คราบสนิมไหล
put(MAIN, P.cyl((0.2, 0, TANK_Z - TANK_R + 0.02), (0, 0, -1), 0.06, 0.1, n=8), "Brass")
put(MAIN, P.box_rot((0.2, 0.0, TANK_Z - TANK_R - 0.14), (0.14, 0.04, 0.04), "Z", 30), "Brass")

# ---------------------------------------------------------------- แท่นเครื่องบนถัง
put(MAIN, box((0, -0.05, PLATE_Z - 0.03), (2.9, 1.08, 0.06)), "TankPaint", bevel=0.015)
for x in (-1.25, -0.2, 0.25, 1.25):                       # ขาแท่นเชื่อมกับถัง
    for sy in (1, -1):
        put(MAIN, box((x, sy * 0.36, (PLATE_Z + TANK_Z + 0.6) / 2 - 0.03), (0.08, 0.06, PLATE_Z - TANK_Z - 0.6)), "TankPaint")
for x in (-1.1, -0.35, 0.35, 0.9):                        # น็อตยึดเครื่อง
    for y in (-0.42, 0.32):
        put(MAIN, P.cyl((x, y, PLATE_Z), ZUP, 0.04, 0.05, n=6), "DarkSteel")

# ---------------------------------------------------------------- หัวปั๊ม (ห้องข้อเหวี่ยง + กระบอกสูบคู่ตัววี มีครีบระบายความร้อน)
PX = FLY_C.x
put(MAIN, box((PX, 0.0, PLATE_Z + 0.26), (0.62, 0.72, 0.52)), "CastIron", bevel=0.05)
put(MAIN, P.cyl((PX, -0.36, FLY_C.z), (0, -1, 0), 0.2, 0.12, n=16), "CastIron")       # ฝาลูกปืนด้านมู่เล่
put(MAIN, P.cyl((PX, 0.36, FLY_C.z), YAX, 0.16, 0.08, n=16), "CastIron")
put(MAIN, P.cyl((PX, 0.0, PLATE_Z + 0.02), (0, -1, 0), 0.06, 0.38, n=8, cap=True), "Galv")  # ช่องดูน้ำมัน
put(MAIN, P.cyl((PX + 0.32, -0.15, PLATE_Z + 0.18), XAX, 0.05, 0.04, n=10), "Chrome")      # ตาแมวน้ำมัน
for ang in (-28, 28):
    base = Vector((PX, 0.0, PLATE_Z + 0.52))
    ax = Vector((math.sin(math.radians(ang)), 0, math.cos(math.radians(ang))))
    rot = Matrix.Translation(base) @ Matrix.Rotation(math.radians(ang), 4, "Y")
    g = G()
    g.merge(P.cyl((0, 0, 0), ZUP, 0.15, 0.5, n=14))
    for k in range(8):
        g.merge(P.ring_band((0, 0, 0), ZUP, 0.14, 0.24, 0.06 + k * 0.052, 0.078 + k * 0.052, n=14))
    put(MAIN, P.xform(g, rot), "Alu")
    head = G()
    head.merge(box((0, 0, 0.56), (0.42, 0.42, 0.14)))
    for hxx in (-0.15, 0.15):
        for hyy in (-0.15, 0.15):
            head.merge(P.cyl((hxx, hyy, 0.63), ZUP, 0.03, 0.04, n=6))
    put(MAIN, P.xform(head, rot), "CastIron", bevel=0.02)
    # หม้อกรองอากาศ
    filt = G()
    filt.merge(P.cyl((0.0, 0.0, 0.63), ZUP, 0.05, 0.1, n=8))
    filt.merge(lathe((0, 0, 0.72), ZUP, [(0, 0.0), (0, 0.17), (0.02, 0.18), (0.12, 0.18), (0.14, 0.16), (0.15, 0.0)], n=18))
    put(MAIN, P.xform(filt, rot), "DarkSteel")
    for k in range(5):
        rb = P.ring_band((0, 0, 0.75 + k * 0.022), ZUP, 0.17, 0.185, 0.0, 0.01, n=18)
        put(MAIN, P.xform(rb, rot), "Galv")
# ท่อทองแดงส่งลม (หัวปั๊ม -> ถัง) งอเป็นขด
hd = (Matrix.Translation(Vector((PX, 0, PLATE_Z + 0.52))) @ Matrix.Rotation(math.radians(28), 4, "Y")) @ Vector((0.21, 0.1, 0.56))
cop = P.spline([tuple(hd), tuple(hd + Vector((0.12, 0.08, 0.0))), (PX + 0.45, 0.38, PLATE_Z + 0.55), (PX + 0.3, 0.48, PLATE_Z + 0.25),
                (PX + 0.55, 0.5, PLATE_Z + 0.12), (PX + 0.75, 0.48, PLATE_Z - 0.06), (PX + 0.8, 0.45, TANK_Z + 0.62)], per=7)
put(MAIN, V.tube(cop, 0.035, n=8), "Copper")
put(MAIN, P.cyl((PX + 0.8, 0.45, TANK_Z + 0.6), ZUP, 0.06, 0.08, n=6), "Brass")

# ---------------------------------------------------------------- มอเตอร์ไฟฟ้า
M = MOT_C
put(MAIN, lathe(M - Vector((0, 0.42, 0)), YAX, [(0.0, 0.0), (0.0, 0.2), (0.04, 0.27), (0.1, 0.3), (0.72, 0.3), (0.78, 0.27), (0.84, 0.18), (0.84, 0.0)], n=28), "MotorPaint")
for k in range(10):                                        # ครีบตามยาวรอบตัวมอเตอร์
    a = math.radians(-30 + k * 24)
    if 75 < math.degrees(a) % 360 < 105:
        continue
    put(MAIN, P.box_rot((M.x + math.cos(a) * 0.31, M.y - 0.03, M.z + math.sin(a) * 0.31), (0.045, 0.58, 0.03), "Y", -math.degrees(a)), "MotorPaint")
put(MAIN, box((M.x, M.y - 0.03, PLATE_Z + 0.04), (0.5, 0.6, 0.08)), "MotorPaint", bevel=0.01)     # ฐานมอเตอร์
for sx in (-1, 1):
    put(MAIN, box((M.x + sx * 0.18, M.y - 0.03, (PLATE_Z + M.z - 0.2) / 2), (0.08, 0.5, M.z - 0.2 - PLATE_Z)), "MotorPaint")
put(MAIN, box((M.x, M.y + 0.05, M.z + 0.36), (0.26, 0.3, 0.14)), "MotorPaint", bevel=0.015)        # กล่องต่อสายไฟ
put(MAIN, P.cyl((M.x, M.y + 0.2, M.z + 0.36), YAX, 0.04, 0.08, n=8), "DarkSteel")
# ฝาครอบพัดลมท้ายมอเตอร์ (ซี่ตะแกรง)
put(MAIN, P.ring_band(M, YAX, 0.27, 0.31, 0.42, 0.52, n=28), "MotorPaint")
for k in range(9):
    z = M.z - 0.24 + k * 0.06
    w = 2 * math.sqrt(max(0.0, 0.27 ** 2 - (z - M.z) ** 2))
    if w > 0.02:
        put(MAIN, box((M.x, M.y + 0.5, z), (w, 0.02, 0.02)), "DarkSteel")
# เพลา + มู่เล่เล็ก (มอเตอร์)
put(MAIN, P.cyl(M - Vector((0, 0.42, 0)), (0, -1, 0), 0.04, PUL_C.y * -1 + M.y - 0.42 + 0.06, n=8), "Galv")
put(MAIN, lathe(PUL_C, YAX, [(-0.05, 0.0), (-0.05, PUL_R + 0.03), (-0.025, PUL_R), (0.025, PUL_R), (0.05, PUL_R + 0.03), (0.05, 0.0)], n=18), "CastIron")
# ป้ายข้อมูลมอเตอร์
put(MAIN, box((M.x, M.y - 0.12, M.z + 0.305), (0.2, 0.22, 0.01)), "Alu")
# สายไฟจากกล่อง -> ลงพื้นด้านหลัง
put(MAIN, V.tube(P.spline([(M.x, M.y + 0.24, M.z + 0.36), (M.x + 0.1, M.y + 0.45, M.z + 0.2), (M.x + 0.25, 0.62, PLATE_Z - 0.1), (M.x + 0.35, 0.75, 1.4),
                            (M.x + 0.3, 0.85, 0.5), (M.x + 0.2, 1.05, 0.05), (M.x - 0.2, 1.35, 0.03), (M.x - 0.7, 1.45, 0.03)], per=6), 0.03, n=6), "Cable")

# ---------------------------------------------------------------- สายพาน + ฝาครอบ
hull = circles_hull([(FLY_C.x, FLY_C.z, FLY_R - 0.05), (PUL_C.x, PUL_C.z, PUL_R)], n=48)
belt = [(x, FLY_C.y, z) for x, z in hull]
put(MAIN, V.tube(belt + [belt[0], belt[1]], 0.032, n=6, cap=False), "Belt")
GY = FLY_C.y - 0.14
gh = circles_hull([(FLY_C.x, FLY_C.z, FLY_R + 0.08), (PUL_C.x, PUL_C.z, PUL_R + 0.12)], n=48)
gl = [(x, GY, z) for x, z in gh]
put(MAIN, V.tube(gl + [gl[0], gl[1]], 0.03, n=6, cap=False), "YellowPaint")
put(MAIN, V.tube([(x, GY + 0.09, z) for x, z in gh] + [(gh[0][0], GY + 0.09, gh[0][1]), (gh[1][0], GY + 0.09, gh[1][1])], 0.022, n=6, cap=False), "YellowPaint")
xs = [min(p[0] for p in gh) + 0.06 + i * 0.075 for i in range(60)]
for x in xs:
    zr = z_range_in(gh, x)
    if not zr or x > max(p[0] for p in gh) - 0.04:
        continue
    put(MAIN, P.cyl((x, GY, zr[0] + 0.02), ZUP, 0.012, zr[1] - zr[0] - 0.04, n=4, cap=False), "YellowPaint")
for z in (FLY_C.z - 0.2, FLY_C.z + 0.2):
    zr = None
    put(MAIN, P.cyl((min(p[0] for p in gh) + 0.05, GY, z), XAX, 0.014, max(p[0] for p in gh) - min(p[0] for p in gh) - 0.1, n=4, cap=False), "YellowPaint")
for (x, z) in ((FLY_C.x, PLATE_Z + 0.02), (PUL_C.x, PLATE_Z + 0.02)):   # ขายึดฝาครอบ
    put(MAIN, box((x, GY + 0.05, z + 0.09), (0.06, 0.12, 0.18)), "YellowPaint")

# ---------------------------------------------------------------- ท่อร่วม: สวิตช์แรงดัน + เกจ + วาล์วจ่ายลม
MX = GAUGE_C.x
put(MAIN, P.cyl((MX, -0.2, TANK_Z + TANK_R - 0.05), ZUP, 0.06, PLATE_Z - TANK_Z - TANK_R + 0.12, n=10), "Galv")
put(MAIN, box((MX, -0.2, PLATE_Z + 0.12), (0.18, 0.18, 0.18)), "Brass", bevel=0.02)                    # ข้อต่อ 4 ทาง
put(MAIN, box((MX, 0.15, PLATE_Z + 0.24), (0.32, 0.26, 0.4)), "DarkSteel", bevel=0.03)                 # กล่องสวิตช์แรงดัน
put(MAIN, P.cyl((MX, 0.15, PLATE_Z + 0.44), ZUP, 0.08, 0.1, n=14), "RedInk")                           # ปุ่มเปิดปิดแดง
put(MAIN, P.cyl((MX, -0.2, PLATE_Z + 0.2), ZUP, 0.04, GAUGE_C.z - PLATE_Z - 0.38, n=8), "Brass")      # ก้านเกจ
put(MAIN, box((MX, GAUGE_C.y + 0.1, GAUGE_C.z - 0.19), (0.07, 0.25, 0.07)), "Brass")
put(MAIN, P.ring_band(GAUGE_C + Vector((0, 0.1, 0)), (0, -1, 0), 0.16, 0.2, 0.0, 0.12, n=28), "Chrome")
put(MAIN, P.cyl(GAUGE_C + Vector((0, 0.1, 0)), (0, -1, 0), 0.2, 0.06, n=28), "Chrome")
put(MAIN, P.cyl(GAUGE_C + Vector((0, 0.04, 0)), (0, -1, 0), 0.165, 0.01, n=28), "DialFace")
for i in range(13):
    a = math.radians(225 - i * 22.5)
    r0 = 0.11 if i % 2 == 0 else 0.13
    mat = "RedInk" if i >= 10 else "Ink"
    p0 = GAUGE_C + Vector((math.cos(a) * r0, 0.025, math.sin(a) * r0))
    p1 = GAUGE_C + Vector((math.cos(a) * 0.15, 0.025, math.sin(a) * 0.15))
    put(MAIN, V.tube([tuple(p0), tuple(p1)], 0.007, n=4), mat)
# วาล์วจ่ายลม (ก้านโยกแดง) + ข้อต่อสายลม
put(MAIN, P.cyl((MX, -0.29, PLATE_Z + 0.12), (0, -1, 0), 0.05, 0.12, n=10), "Brass")
put(MAIN, P.box_rot((MX + 0.08, -0.4, PLATE_Z + 0.2), (0.24, 0.04, 0.05), "Y", -20), "RedInk")
OUT_P = Vector((MX, -0.42, PLATE_Z + 0.12))

# ---------------------------------------------------------------- สายลมแดงขดแขวนมือจับ + หัวเติมลม
hang = Vector((hx + 0.1, -0.05, TANK_Z + 0.78 + 0.12))      # ขดพาดบนด้ามจับ
pts = [tuple(OUT_P), tuple(OUT_P + Vector((0.12, -0.08, -0.05))), (MX + 0.42, -0.6, PLATE_Z - 0.02), (hx + 0.2, -0.42, hang.z + 0.02), (hang.x + 0.02, -0.2, hang.z + 0.04)]
coil = []
for k in range(int(2.6 * 20) + 1):                        # ขดห้อยจากมือจับ 2.6 รอบ
    t = k / 20
    a = math.pi / 2 + 2 * math.pi * t
    coil.append((hang.x + 0.02 + 0.05 * t, hang.y + 0.4 * math.cos(a) * 0.9, hang.z - 0.4 + 0.4 * math.sin(a)))
tail = [(coil[-1][0] + 0.05, coil[-1][1] - 0.1, coil[-1][2] - 0.3), (hang.x + 0.25, -0.45, 0.55)]
hose = P.spline(pts + [coil[0]], per=6) + coil[1:] + P.spline([coil[-1]] + tail, per=6)[1:]
put(MAIN, V.tube(hose, 0.05, n=10), "RedHose")
CHUCK = Vector(tail[-1])
put(MAIN, V.lathe_axis(CHUCK, (0, 0, -1), [(0, 0.06), (0.03, 0.07), (0.12, 0.07), (0.14, 0.05), (0.26, 0.04), (0.3, 0.05), (0.34, 0.0)], n=12), "Brass")
put(MAIN, P.box_rot(tuple(CHUCK + Vector((0, -0.07, -0.08))), (0.03, 0.03, 0.2), "X", 25), "Chrome")

# ---------------------------------------------------------------- มู่เล่ (แยกชิ้น หมุนได้)
C = FLY_C
put(FLY, lathe(C, YAX, [(-0.07, FLY_R - 0.16), (-0.07, FLY_R - 0.02), (-0.05, FLY_R), (-0.02, FLY_R - 0.04), (0.02, FLY_R - 0.04), (0.05, FLY_R), (0.07, FLY_R - 0.02), (0.07, FLY_R - 0.16), (-0.07, FLY_R - 0.16)], n=40), "CastIron")
put(FLY, lathe(C, YAX, [(-0.09, 0.0), (-0.09, 0.1), (-0.06, 0.13), (0.06, 0.13), (0.09, 0.1), (0.09, 0.0)], n=18), "CastIron")
for i in range(6):                                          # ซี่ใบพัด (เป่าลมหัวปั๊ม) บิดนิดๆ
    a = 2 * math.pi * i / 6
    spoke = P.box_rot((0, 0, (FLY_R - 0.03) / 2 + 0.05), (0.1, 0.035, FLY_R - 0.2), "Z", 25)
    put(FLY, P.xform(spoke, Matrix.Translation(C) @ Matrix.Rotation(a, 4, "Y")), "CastIron")
put(FLY, P.cyl(C, (0, -1, 0), 0.05, 0.12, n=8), "Galv")

# ---------------------------------------------------------------- เข็มเกจ (ชี้ ~ 7 bar)
na = math.radians(225 - 7 * 22.5)
put(NEEDLE, V.tube([tuple(GAUGE_C + Vector((-math.cos(na) * 0.03, 0.015, -math.sin(na) * 0.03))), tuple(GAUGE_C + Vector((math.cos(na) * 0.14, 0.015, math.sin(na) * 0.14)))], [0.012, 0.004], n=4), "RedInk")
put(NEEDLE, P.dome(GAUGE_C + Vector((0, 0.02, 0)), (0, -1, 0), 0.022, 0.014), "Chrome")

# ---------------------------------------------------------------- วาล์วนิรภัย (บนข้อต่อ 4 ทาง)
VC = Vector((MX - 0.15, -0.2, PLATE_Z + 0.12))
put(VALVE, P.cyl(VC, (-1, 0, 0), 0.04, 0.06, n=8), "Brass")
put(VALVE, lathe(VC + Vector((-0.1, 0, 0)), ZUP, [(-0.05, 0.0), (-0.05, 0.05), (0.0, 0.06), (0.12, 0.05), (0.16, 0.035), (0.22, 0.03), (0.24, 0.0)], n=12), "Brass")
put(VALVE, V.tube(V.arc((VC.y, VC.z + 0.27), 0.05, 0, 2 * math.pi, 12, x=VC.x - 0.1), 0.011, n=5), "Brass")   # ห่วงดึง

# ---------------------------------------------------------------- object + bake + export
ORDER = [MAIN, FLY, NEEDLE, VALVE]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"FLY_C_rbx=({-FLY_C.x:.3f},{FLY_C.z:.3f},{FLY_C.y:.3f}) GAUGE_C_rbx=({-GAUGE_C.x:.3f},{GAUGE_C.z:.3f},{GAUGE_C.y:.3f})")
if not NO_BAKE:
    P.bake_all(OBJ, {MAIN: "AirCompressorV2_Body", FLY: "AirCompressorV2_Flywheel", NEEDLE: "AirCompressorV2_Needle", VALVE: "AirCompressorV2_Valve"},
               {MAIN: 1024, FLY: 512, NEEDLE: 128, VALVE: 256})
P.export_fbx(OBJ, os.path.join(UP, "AirCompressorV2.fbx"), MAIN)


def preview():
    cam, sun, world = P.stage()
    P.add_person(ROOT, (3.4, 0.6, 0.0), yaw_deg=-35)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2.png"), (0, 0, 1.9), (-0.55, -1.2, 0.42), 13.0)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2_front.png"), (0, 0, 1.9), (0.0, -1.0, 0.15), 11.0)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2_head.png"), (-0.2, -0.3, 2.8), (-0.6, -1.0, 0.45), 5.5)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2_gauge.png"), (1.6, -0.4, 2.5), (0.5, -1.0, 0.25), 4.5)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2_back.png"), (0, 0, 1.9), (0.7, 1.1, 0.4), 12.0)
    P.night(world, sun, (-2.0, -5.0, 8.0), energy=90)
    P.shot(cam, os.path.join(OUT, "AirCompressorV2_night.png"), (0, 0, 1.9), (-0.5, -1.2, 0.4), 13.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "air_compressor_v2.blend"))
P.log("done")
