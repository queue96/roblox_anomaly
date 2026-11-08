# ThaiPickupOld v2 — กระบะเก่าโทรมคอกเหล็ก ปั้นใหม่ทั้งคัน (ผู้ใช้ 2026-11-08 "ทำกระบะก่อน" สีเดียว)
# รัน: blender -b --factory-startup --python tools/blender/pickup_v2.py
# ผลลัพธ์: assets/models/PickupV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ชุดเครื่องมือ tools/blender/vehlib.py (แยกมาจาก customer_bike_v2.py)
# แกน Blender: หน้ารถ -Y, ซ้าย +X (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
# ตำแหน่งที่ต้องตรงกับแม่แบบเดิมในเกม (src/shared/ThaiVehicleRigs.luau ThaiPickupOld):
#   ล้อ Roblox (±3.01, 1.62, -6.30 / 5.60) r 1.62 กว้าง 1.15 · ไฟหน้า (±2.62, 3.35, -10.66) 1.2x0.7 · ไฟท้าย (±3.4, 4.0, 10.14) 0.7x1.4
#   ป้าย หน้า (0, 1.85, -10.97) / หลัง (0, 1.90, 10.68) · เบาะคนขับ (DriverSeat) Roblox (1.65, 3.40, 0.20) บนเบาะ 3.55
#   สะโพกคนขับที่เกมคำนวณ (CoreLoop.seatDriver/humanizeDriver) ~ (1.65, 3.55, 0.43) -> เบาะจริงต่ำกว่านั้น 0.3
#   มือจับพวงมาลัย (humanizeDriver drive_car) ~ (2.20 / 1.35, 5.15, -1.52) -> พวงมาลัยศูนย์กลาง (1.78, 5.15, -1.45) รัศมี 0.48
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "PickupV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = int(os.environ.get("VEH_TEX", "1024"))
V.SAMPLES = int(os.environ.get("VEH_SAMPLES", "16"))
NO_BAKE = os.environ.get("VEH_NOBAKE") == "1"
S = V.S
G, loft, tube, lathe_x, lathe_axis, box, ring_y, ring_z, put, L = V.G, V.loft, V.tube, V.lathe_x, V.lathe_axis, V.box, V.ring_y, V.ring_z, V.put, V.L
sup = V.sup

WF_Y, WR_Y, AX_Z, WR, WW, WX = -6.30, 5.60, 1.62, 1.62, 1.15, 3.01
V.FRONT_Y, V.AXLE_Z = WF_Y, AX_Z  # ดอกยาง: ล้อปั้นที่ x = 0, y = ล้อหน้า
V.TREAD_N = 64.0
BELT, ROCK = 4.90, 1.95  # ขอบกระจกล่าง / ขอบล่างตัวถัง
ROOF = 8.80
ARCH_R = 2.05


def log(*a):
    print("PK|", *a)


def arch_bottom(y, base):
    for wy in (WF_Y, WR_Y):
        d = y - wy
        if abs(d) < ARCH_R:
            base = max(base, AX_Z + math.sqrt(ARCH_R * ARCH_R - d * d))
    return base


def loft_open(rings):
    g = G()
    n = len(rings[0])
    for r in rings:
        g.v += [tuple(p) for p in r]
    for j in range(len(rings) - 1):
        for i in range(n - 1):
            a, b = j * n + i, j * n + i + 1
            g.f.append((a, b, b + n, a + n))
    return g


def rect_y(y, x0, x1, z0, z1):
    return [(x1, y, z0), (x1, y, z1), (x0, y, z1), (x0, y, z0)]


def slab_y(ys, x0, x1, top, bot):
    """แผ่นหนาตามแนวยาว: x0..x1 คงที่ บน/ล่าง เปลี่ยนตาม y (ขอบล่างโค้งตามซุ้มล้อได้)"""
    return loft([rect_y(y, x0, x1, bot(y), top(y)) for y in ys])


def ys(a, b, n):
    return [a + (b - a) * i / n for i in range(n + 1)]


# ---------------------------------------------------------------- วัสดุ (สีเดียว: น้ำตาลแดงม่วงซีด + สนิมเยอะ ตามภาพอ้างอิง)
V.make_mat("pk_paint", L((96, 54, 58)), 0.55, 0.0, dirt=0.6, wear=0.28, bump=0.05, bump_scale=90, rust=0.55, stripe=(3.95, 4.12, L((178, 172, 160))))
V.make_mat("pk_chrome", L((190, 190, 192)), 0.22, 1.0, dirt=0.5, rust=0.6)
V.make_mat("pk_black", L((24, 23, 22)), 0.6, 0.0, dirt=0.6, wear=0.2, bump=0.06, bump_scale=200)
V.make_mat("pk_under", L((34, 30, 27)), 0.75, 0.3, dirt=0.9, rust=0.5)
V.make_mat("pk_rack", L((70, 52, 40)), 0.6, 0.5, dirt=0.5, rust=0.85)
V.make_mat("pk_bed", L((58, 46, 38)), 0.7, 0.4, dirt=0.8, rust=0.7, bump=0.1, bump_scale=140)
V.make_mat("pk_rim", L((150, 150, 148)), 0.4, 0.6, dirt=0.7, rust=0.45)
V.make_mat("pk_tire", L((20, 20, 20)), 0.88, 0.0, dirt=0.3, bump=0.32, kind="tread")
V.make_mat("pk_glass", L((26, 30, 32)), 0.08, 0.0, dirt=0.25)
V.make_mat("pk_lens", L((235, 230, 215)), 0.15, 0.0, dirt=0.3)
V.make_mat("pk_amber", L((230, 120, 30)), 0.2, 0.0, dirt=0.3)
V.make_mat("pk_red", L((150, 20, 18)), 0.2, 0.0, dirt=0.3)
V.make_mat("pk_dash", L((40, 38, 36)), 0.65, 0.0, dirt=0.4, wear=0.3, bump=0.08, bump_scale=220)
V.make_mat("pk_vinyl", L((74, 52, 40)), 0.5, 0.0, dirt=0.4, wear=0.4, bump=0.35, kind="pleat")
V.make_mat("pk_trim", L((120, 114, 104)), 0.7, 0.0, dirt=0.5, bump=0.05, bump_scale=200)
V.make_mat("pk_mat", L((30, 30, 30)), 0.9, 0.0, dirt=0.7, bump=0.2, bump_scale=60)
V.make_mat("pk_gauge", L((12, 14, 14)), 0.1, 0.0, dirt=0.1)

BODY, RACK, GLASS, INT, WHEEL = "PickupBody", "PickupRack", "PickupGlass", "PickupInterior", "PickupWheel"

# ================================================================ ตัวถัง
# 1) หน้ารถ: ฝากระโปรง + บังโคลนหน้า + จมูก (ปิดทึบ ขอบล่างเว้าตามซุ้มล้อหน้า)
front = []
for y in ys(-10.62, -3.35, 22):
    t = (y + 10.62) / 7.27
    top = 4.05 + 0.45 * min(1, t * 6) + 0.25 * t
    hx = 3.62 + 0.18 * min(1, t * 5)
    bot = arch_bottom(y, ROCK)
    front.append(ring_y(0, y, (top + bot) / 2, hx, (top - bot) / 2, 28, 6.0))
put(BODY, loft(front), "pk_paint", 1)
# 2) ห้องโดยสารส่วนล่าง (เปิดด้านบน: ข้างใน = PickupInterior)
tub = []
for y in ys(-3.42, 1.58, 12):
    pts = []
    hx = 3.78
    for k in range(13):
        a = math.pi * k / 12  # 0 = ขวาบน ... ลงล่าง ... ซ้ายบน
        x = hx * math.cos(a) * -1
        if k == 0 or k == 12:
            z = BELT
        else:
            z = ROCK + (BELT - ROCK) * (1 - abs(sup(math.sin(a), 0, 8.0))) * 0.98
        pts.append((x if k not in (0, 12) else (hx if k == 0 else -hx), y, z))
    # ใช้หน้าตัดแบบกล่องมุมมน: ข้าง x = ±hx ตรง ล่างมน
    pts = []
    prof = [(hx, BELT), (hx, 3.0), (hx - 0.02, 2.25), (hx - 0.12, ROCK + 0.04), (hx - 0.35, ROCK), (-(hx - 0.35), ROCK), (-(hx - 0.12), ROCK + 0.04), (-(hx - 0.02), 2.25), (-hx, 3.0), (-hx, BELT)]
    for x, z in prof:
        pts.append((x, y, z))
    tub.append(pts)
put(BODY, loft_open(tub), "pk_paint", 0)
# ขอบบนประตู (คิ้วยาง) + ร่องประตู + มือจับ
for sx in (1, -1):
    put(BODY, tube([(sx * 3.80, -3.3, BELT + 0.02), (sx * 3.80, 1.45, BELT + 0.02)], 0.06, 6), "pk_black", 0)
    door = [(sx * 3.795, -3.15, 4.85), (sx * 3.795, -3.2, 2.15), (sx * 3.795, 0.95, 2.15), (sx * 3.795, 0.98, 4.85)]
    put(BODY, tube(door, 0.02, 4, cap=False), "pk_black", 0)
    put(BODY, box((sx * 3.83, 0.62, 4.35), (0.06, 0.55, 0.12)), "pk_chrome", 0, bevel=0.02)
    # กระจกมองข้าง
    put(BODY, tube([(sx * 3.78, -2.95, 5.35), (sx * 4.05, -2.95, 5.6)], 0.05, 6), "pk_black", 0)
    put(BODY, box((sx * 4.16, -2.95, 5.85), (0.22, 0.14, 0.62)), "pk_black", 2, bevel=0.0)
# 3) หลังคา + เสา + ผนังหลังห้องโดยสาร
roof = []
for y in ys(-1.98, 1.48, 10):
    roof.append(ring_y(0, y, ROOF - 0.12, 3.36, 0.14, 24, 4.0))
put(BODY, loft(roof), "pk_paint", 1)
for sx in (1, -1):
    put(BODY, tube([(sx * 3.58, -3.22, BELT), (sx * 3.46, -2.55, 6.85), (sx * 3.34, -1.92, ROOF - 0.2)], 0.13, 10), "pk_paint", 0)
    put(BODY, tube([(sx * 3.6, 1.45, BELT), (sx * 3.45, 1.45, 7.0), (sx * 3.32, 1.42, ROOF - 0.2)], 0.17, 10), "pk_paint", 0)
    # ยางขอบกระจกข้าง
    edge = [(sx * 3.56, -3.12, BELT + 0.06), (sx * 3.44, -2.5, 6.9), (sx * 3.33, -1.86, ROOF - 0.32), (sx * 3.33, 1.3, ROOF - 0.32), (sx * 3.48, 1.32, 6.9), (sx * 3.56, 1.32, BELT + 0.06)]
    put(BODY, tube(edge, 0.035, 5, cap=False), "pk_black", 0)
# ผนังหลัง: ช่วงล่าง (ใต้ขอบกระจก) + กรอบกระจกหลัง
put(BODY, box((0, 1.53, (ROCK + BELT) / 2), (7.5, 0.12, BELT - ROCK)), "pk_paint", 0, bevel=0.03)
for z0, z1 in ((BELT, 5.3), (8.3, ROOF - 0.05)):
    put(BODY, box((0, 1.53, (z0 + z1) / 2), (6.9, 0.12, z1 - z0)), "pk_paint", 0, bevel=0.03)
for sx in (1, -1):
    put(BODY, box((sx * 3.15, 1.53, 6.8), (0.55, 0.12, 3.0)), "pk_paint", 0, bevel=0.03)
put(BODY, tube([(-2.88, 1.6, 5.3), (2.88, 1.6, 5.3), (2.88, 1.6, 8.3), (-2.88, 1.6, 8.3), (-2.88, 1.6, 5.3)], 0.035, 5, cap=False), "pk_black", 0)
# แผงใต้กระจกหน้า (ช่องปัดน้ำฝน) + ที่ปัดน้ำฝน
put(BODY, box((0, -3.28, 4.88), (7.2, 0.4, 0.12)), "pk_black", 0, bevel=0.03)
for x0 in (-1.9, 1.2):
    put(BODY, tube([(x0, -3.18, 5.0), (x0 + 1.6, -2.95, 5.35)], 0.025, 4), "pk_black", 0)
# 4) กระบะท้าย: พื้น ผนังหน้า ผนังข้าง (ขอบล่างเว้าซุ้มล้อหลัง) ฝาท้าย
put(BODY, box((0, 5.88, 3.62), (7.0, 8.2, 0.25)), "pk_bed", 0, bevel=0.03)
for k in range(9):  # ร่องพื้นกระบะ
    x = -3.0 + 6.0 * k / 8
    put(BODY, box((x, 5.88, 3.76), (0.12, 8.0, 0.05)), "pk_bed", 0)
put(BODY, box((0, 1.78, 4.25), (7.4, 0.14, 1.45)), "pk_paint", 0, bevel=0.03)
for sx in (1, -1):
    x0, x1 = (3.50, 3.84) if sx > 0 else (-3.84, -3.50)
    put(BODY, slab_y(ys(1.72, 10.05, 40), x0, x1, lambda y: 4.95, lambda y: arch_bottom(y, ROCK + 0.05)), "pk_paint", 0, bevel=0.04)
    put(BODY, tube([(sx * 3.67, 1.72, 4.98), (sx * 3.67, 10.05, 4.98)], 0.11, 8), "pk_paint", 0)
    # ไฟท้าย (เลนส์ + กรอบ) ตรงกับชิ้นไฟในเกม Roblox (±3.4, 4.0, 10.14)
    put(BODY, box((sx * 3.40, 10.06, 4.0), (0.86, 0.12, 1.56)), "pk_black", 0, bevel=0.03)
    put(BODY, box((sx * 3.40, 10.12, 4.0), (0.72, 0.04, 1.42)), "pk_red", 0)
put(BODY, box((0, 10.0, 3.62), (6.9, 0.18, 2.62)), "pk_paint", 0, bevel=0.04)
for z in (3.2, 4.0):
    put(BODY, box((0, 10.1, z), (6.4, 0.06, 0.12)), "pk_paint", 0, bevel=0.02)
for sx in (1, -1):
    put(BODY, tube([(sx * 3.2, 10.12, 4.85), (sx * 3.2, 10.12, 4.6)], 0.05, 6), "pk_chrome", 0)
# ซุ้มล้อด้านใน (ดำ) กันมองทะลุ
for wy in (WF_Y, WR_Y):
    for sx in (1, -1):
        rings = []
        for k in range(15):
            a = math.radians(-8 + 196 * k / 14)
            cy, cz = wy - ARCH_R * 0.99 * math.cos(a), AX_Z + ARCH_R * 0.99 * math.sin(a)
            rings.append([(sx * 3.05 + dx, cy, cz + dz) for dx, dz in ((-0.75, 0), (0.75, 0), (0.75, 0.06), (-0.75, 0.06))])
        g = G()
        for r in rings:
            g.v += r
        for j in range(len(rings) - 1):
            for i in range(4):
                a_, b_ = j * 4 + i, j * 4 + (i + 1) % 4
                g.f.append((a_, b_, b_ + 4, a_ + 4))
        put(BODY, g, "pk_under", 0)
        if wy == WR_Y:
            put(BODY, box((sx * 3.3, wy + 2.0, 1.25), (0.9, 0.06, 1.35)), "pk_black", 0)  # บังโคลนยาง
# 5) กันชน + กระจังหน้า + ไฟหน้า
put(BODY, ring_bumper := loft([ring_y(0, y, 1.9, 3.95, 0.55, 24, 6.0) for y in ys(-10.98, -10.5, 2)]), "pk_chrome", 1)
put(BODY, loft([ring_y(0, y, 1.85, 3.88, 0.5, 24, 6.0) for y in ys(10.22, 10.7, 2)]), "pk_chrome", 1)
put(BODY, box((0, -10.66, 3.38), (3.9, 0.12, 1.3)), "pk_black", 0, bevel=0.03)
for k in range(5):
    put(BODY, box((0, -10.72, 2.86 + k * 0.26), (3.8, 0.06, 0.07)), "pk_chrome", 0)
put(BODY, tube([(-1.95, -10.72, 2.74), (1.95, -10.72, 2.74), (1.95, -10.72, 4.02), (-1.95, -10.72, 4.02), (-1.95, -10.72, 2.74)], 0.05, 6, cap=False), "pk_chrome", 0)
for sx in (1, -1):
    hx = sx * 2.62
    put(BODY, box((hx, -10.63, 3.35), (1.42, 0.14, 0.92)), "pk_chrome", 0, bevel=0.03)  # กรอบไฟหน้า (ชิ้นไฟจริงในเกมอยู่หน้าสุด y -10.66)
    put(BODY, box((hx, -10.69, 3.35), (1.24, 0.04, 0.74)), "pk_lens", 0)
    put(BODY, box((hx, -10.68, 2.66), (0.9, 0.08, 0.26)), "pk_amber", 0, bevel=0.02)
# 6) ใต้ท้องรถ: แชสซี เพลาหลัง แหนบ ถังน้ำมัน ท่อไอเสีย
for sx in (1, -1):
    put(BODY, box((sx * 1.7, 0.0, 1.45), (0.35, 19.5, 0.45)), "pk_under", 0, bevel=0.03)
    put(BODY, box((sx * 2.35, WR_Y, 1.25), (0.3, 4.2, 0.18)), "pk_under", 0, bevel=0.03)
put(BODY, tube([(-2.6, WR_Y, AX_Z), (2.6, WR_Y, AX_Z)], 0.16, 12), "pk_under", 0)
put(BODY, lathe_axis((0, WR_Y, AX_Z), (0, 1, 0), [(-0.3, 0.0), (-0.3, 0.25), (-0.1, 0.42), (0.15, 0.42), (0.3, 0.2), (0.32, 0.0)], 16), "pk_under", 0)
put(BODY, tube([(-2.4, WF_Y, AX_Z + 0.1), (2.4, WF_Y, AX_Z + 0.1)], 0.12, 10), "pk_under", 0)
put(BODY, box((2.2, 2.9, 1.75), (1.5, 2.2, 0.9)), "pk_under", 2)
ex = [(-0.6, -4.0, 1.0), (-1.2, -1.0, 0.95), (-1.25, 6.5, 1.05), (-1.6, 8.6, 1.05), (-2.0, 10.3, 1.0)]
put(BODY, tube(ex, 0.12, 10), "pk_under", 0)
put(BODY, box((-1.25, 3.5, 1.05), (0.6, 2.4, 0.55)), "pk_under", 2)
put(BODY, lathe_axis((-2.0, 10.35, 1.0), (0, 1, 0), [(0, 0.12), (0.12, 0.12), (0.12, 0.09), (0.0, 0.09)], 10), "pk_chrome", 0)

# ================================================================ คอกเหล็ก (สนิม)
posts_y = [1.95, 3.6, 5.3, 7.0, 8.6, 9.95]
rails_z = [6.3, 7.45, 8.55, 9.6]
for sx in (1, -1):
    for y in posts_y:
        put(RACK, tube([(sx * 3.66, y, 4.95), (sx * 3.66, y, 9.62)], 0.075, 8), "pk_rack", 0)
    for z in rails_z:
        put(RACK, tube([(sx * 3.66, 1.95, z), (sx * 3.66, 9.95, z)], 0.06, 8), "pk_rack", 0)
for x in (-1.8, 0.0, 1.8):
    put(RACK, tube([(x, 1.95, 4.95), (x, 1.95, 9.62)], 0.065, 8), "pk_rack", 0)
for z in rails_z:
    put(RACK, tube([(-3.66, 1.95, z), (3.66, 1.95, z)], 0.06, 8), "pk_rack", 0)
for z in (7.45, 9.6):
    put(RACK, tube([(-3.66, 9.95, z), (3.66, 9.95, z)], 0.06, 8), "pk_rack", 0)
# ขายึดคอกกับขอบกระบะ
for sx in (1, -1):
    for y in posts_y:
        put(RACK, box((sx * 3.66, y, 5.02), (0.26, 0.26, 0.12)), "pk_rack", 0)

# ================================================================ กระจก (สองด้าน: MeshPart ไม่วาดด้านหลัง)
def glass_quad(pts, inward):
    g = G()
    n = 6
    P = [Vector(p) for p in pts]  # a b c d (วนรอบ)
    for i in range(n + 1):
        for j in range(n + 1):
            u, w = i / n, j / n
            p = P[0].lerp(P[1], u).lerp(P[3].lerp(P[2], u), w)
            g.v.append(tuple(p))
    for i in range(n):
        for j in range(n):
            a = i * (n + 1) + j
            g.f.append((a, a + n + 1, a + n + 2, a + 1))
    back = G()
    back.v = [tuple(Vector(p) + Vector(inward) * 0.02) for p in g.v]
    back.f = [tuple(reversed(f)) for f in g.f]
    return g.merge(back)


put(GLASS, glass_quad([(-3.48, -3.18, BELT + 0.05), (3.48, -3.18, BELT + 0.05), (3.3, -1.92, ROOF - 0.28), (-3.3, -1.92, ROOF - 0.28)], (0, 0.5, -0.4)), "pk_glass", 0)
for sx in (1, -1):
    put(GLASS, glass_quad([(sx * 3.55, -3.08, BELT + 0.08), (sx * 3.55, 1.3, BELT + 0.08), (sx * 3.34, 1.3, ROOF - 0.32), (sx * 3.34, -1.86, ROOF - 0.32)], (-sx, 0, 0)), "pk_glass", 0)
put(GLASS, glass_quad([(2.86, 1.55, 5.32), (-2.86, 1.55, 5.32), (-2.86, 1.55, 8.28), (2.86, 1.55, 8.28)], (0, -1, 0)), "pk_glass", 0)

# ================================================================ ภายในห้องโดยสาร (เห็นผ่านกระจก)
DRV_X = -1.78  # คนขับนั่งขวา (Roblox +X = Blender -X)
put(INT, box((0, -0.92, 2.08), (7.3, 4.9, 0.12)), "pk_mat", 0)
put(INT, loft([ring_y(0, y, 4.78, 3.45, 0.5, 20, 4.0) for y in ys(-3.15, -2.25, 3)]), "pk_dash", 1)
put(INT, box((0, -3.2, 3.2), (7.2, 0.1, 2.2)), "pk_dash", 0)
# หน้าปัด + ไมล์ (ฝั่งคนขับ)
put(INT, box((DRV_X, -2.28, 5.05), (1.6, 0.22, 0.62)), "pk_dash", 0, bevel=0.05)
for dx in (-0.38, 0.38):
    put(INT, lathe_axis((DRV_X + dx, -2.16, 5.06), (0, 1, 0), [(0, 0.0), (0, 0.24), (0.02, 0.24), (0.02, 0.0)], 18), "pk_gauge", 0)
# พวงมาลัย + แกน
wc = Vector((DRV_X, -1.45, 5.15))
ax = Vector((0, 0.55, 0.62)).normalized()
u = Vector((1, 0, 0))
w = ax.cross(u).normalized()
rim = [tuple(wc + (u * math.cos(2 * math.pi * i / 28) + w * math.sin(2 * math.pi * i / 28)) * 0.48) for i in range(29)]
put(INT, tube(rim, 0.05, 8, cap=False), "pk_dash", 0)
for a in (0, 2 * math.pi / 3, 4 * math.pi / 3):
    put(INT, tube([tuple(wc), tuple(wc + (u * math.cos(a + math.pi / 2) + w * math.sin(a + math.pi / 2)) * 0.46)], 0.035, 6), "pk_dash", 0)
put(INT, tube([tuple(wc), tuple(wc - ax * 1.1)], 0.07, 8), "pk_dash", 0)
put(INT, lathe_axis(tuple(wc), tuple(ax), [(-0.05, 0.0), (-0.05, 0.12), (0.04, 0.1), (0.05, 0.0)], 14), "pk_dash", 0)
# เบาะยาว (ยาวเต็มห้อง) บนเบาะต่ำกว่าสะโพกคนขับ 0.3
put(INT, loft([ring_y(0, y, 3.02, 3.32, 0.26, 24, 4.0) for y in ys(-0.75, 1.1, 4)]), "pk_vinyl", 1)
back = []
for k, (y, z) in enumerate([(1.0, 3.3), (1.08, 4.4), (1.16, 5.4), (1.22, 6.3)]):
    back.append(ring_z(0, y, z, 3.3, 0.2, 20, 4.0))
put(INT, loft(back), "pk_vinyl", 1)
put(INT, box((0, 0.2, 2.45), (6.6, 1.6, 0.75)), "pk_dash", 0)
# แผงประตูด้านใน + หลังคาด้านใน + ผนังหลังด้านใน
for sx in (1, -1):
    put(INT, box((sx * 3.62, -0.9, 3.5), (0.1, 4.75, 2.8)), "pk_trim", 0, bevel=0.03)
    put(INT, box((sx * 3.55, -0.2, 4.05), (0.2, 1.4, 0.12)), "pk_dash", 0)
put(INT, box((0, -0.25, ROOF - 0.32), (6.6, 3.4, 0.06)), "pk_trim", 0)
put(INT, box((0, 1.45, 3.4), (7.3, 0.06, 2.9)), "pk_trim", 0)
# คันเกียร์ เบรกมือ แป้นเหยียบ
put(INT, tube([(-0.3, -1.9, 2.15), (-0.32, -1.6, 3.6)], 0.035, 6), "pk_dash", 0)
put(INT, V.box((-0.32, -1.58, 3.66), (0.18, 0.18, 0.18)), "pk_dash", 2)
for dx in (-0.35, 0.0, 0.4):
    put(INT, box((DRV_X + dx, -2.7, 2.45), (0.25, 0.08, 0.35)), "pk_dash", 0)

# ================================================================ ล้อ (กระทะเหล็ก + ฝาครอบดุม) ปั้นที่ x = 0 ด้านนอก = +X (ล้อซ้าย) ในเกม Clone ไปทั้ง 4 ล้อ
cy, cz = WF_Y, AX_Z
prof = []
for k in range(17):
    t = -1 + 2 * k / 16
    a = t * math.pi * 0.6
    r = 1.30 + 0.32 * math.cos(a)
    prof.append((WW / 2 * math.sin(a) * 1.08, min(WR, r)))
prof = [(-0.5, 1.10), ] + prof + [(0.5, 1.10)]
put(WHEEL, lathe_x(cy, cz, prof, 56), "pk_tire", 0)
rimp = [(-0.48, 1.1), (-0.48, 1.16), (-0.42, 1.18), (-0.4, 1.06), (0.3, 1.06), (0.38, 1.0), (0.42, 0.62), (0.46, 0.5), (0.46, 0.0)]
put(WHEEL, lathe_x(cy, cz, rimp, 48), "pk_rim", 0)
put(WHEEL, lathe_x(cy, cz, [(0.38, 1.06), (0.44, 1.18), (0.5, 1.16), (0.5, 1.10)], 48), "pk_rim", 0)
# รูระบายบนกระทะ + น็อตล้อ + ฝาครอบดุม
for i in range(6):
    a = 2 * math.pi * i / 6
    put(WHEEL, lathe_axis((0.465, cy + 0.82 * math.cos(a), cz + 0.82 * math.sin(a)), (1, 0, 0), [(0, 0.0), (0, 0.13), (0.01, 0.13), (0.01, 0.0)], 12), "pk_under", 0)
    put(WHEEL, lathe_axis((0.47, cy + 0.42 * math.cos(a + 0.5), cz + 0.42 * math.sin(a + 0.5)), (1, 0, 0), [(0, 0.06), (0.07, 0.06), (0.08, 0.0)], 6), "pk_chrome", 0)
put(WHEEL, lathe_axis((0.47, cy, cz), (1, 0, 0), [(0, 0.3), (0.05, 0.3), (0.1, 0.24), (0.13, 0.1), (0.14, 0.0)], 24), "pk_chrome", 0)
put(WHEEL, lathe_x(cy, cz, [(-0.56, 0.0), (-0.56, 0.7), (-0.2, 0.7), (-0.2, 0.0)], 24), "pk_under", 0)

# ---------------------------------------------------------------- สร้าง object
ORDER = [BODY, RACK, GLASS, INT, WHEEL]
OBJ = {n: V.build_object(n) for n in ORDER}
BBOX = {}
for n, ob in OBJ.items():
    cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c = (mn + mx) / 2
    sz = mx - mn
    # Roblox: X = -bx, Y = bz, Z = by
    BBOX[n] = ((-c.x, c.z, c.y), (sz.x, sz.z, sz.y))
    log(f"BBOX {n} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({sz.x:.3f},{sz.z:.3f},{sz.y:.3f})")

BAKED = {BODY: "PickupV2_Body", RACK: "PickupV2_Rack", GLASS: "PickupV2_Glass", INT: "PickupV2_Interior", WHEEL: "PickupV2_Wheel"}
if not NO_BAKE:
    for name, stem in BAKED.items():
        ob = OBJ[name]
        V.uv_unwrap(ob)
        log("baking", name)
        imgs = V.bake(ob, stem)
        mat = V.final_material(stem, imgs)
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0

bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ[BODY]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "PickupV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "PickupV2.fbx"))


# ---------------------------------------------------------------- ภาพตัวอย่าง (+ ล้ออีก 3 ล้อ + คนขับนั่งเทียบ เฉพาะในภาพ)
def preview():
    scn = bpy.context.scene
    extra = []
    wob = OBJ[WHEEL]
    for (rx, rz) in ((3.01, WF_Y), (-3.01, WR_Y), (3.01, WR_Y)):
        c = wob.copy()
        c.data = wob.data
        scn.collection.objects.link(c)
        m = Matrix.Translation(Vector((0, rz - WF_Y, 0)) * S)
        if rx > 0:  # ฝั่งขวา (Roblox +X = Blender -X): หมุน 180° รอบแกนตั้งที่ดุม
            hub = Vector((0, WF_Y, AX_Z)) * S
            m = m @ Matrix.Translation(hub) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation(-hub)
        c.matrix_world = Matrix.Translation(Vector((-rx, 0, 0)) * S) @ m
        extra.append(c)
    wob.location = Vector((-(-3.01), 0, 0)) * S  # ล้อหน้าซ้าย (Roblox -X = Blender +X)
    # คนขับ (human_base ท่า drive_car) สะโพกที่ (1.65, 3.55, 0.43) Roblox
    rider = []
    path = os.path.join(ROOT, "human_base", "human_base.blend")
    if os.path.exists(path):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_farmer") or n == "Hair_student"]
            dst.actions = [n for n in src.actions if n == "drive_car"]
        rider = [o for o in dst.objects if o]
        for o in rider:
            scn.collection.objects.link(o)
        rig = next((o for o in rider if o.type == "ARMATURE"), None)
        if rig and dst.actions:
            rig.animation_data_create()
            rig.animation_data.action = dst.actions[0]
            scn.frame_set(1)
            hips = rig.data.bones["hips"].head_local
            rig.location = Vector((-1.65, 0.43, 3.55)) * S - hips
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1400, 860
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-12, -12, 0), (12, -12, 0), (12, 12, 0), (-12, 12, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gm = bpy.data.materials.new("G")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.2, 0.15, 1)
    gp.materials.append(gm)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((0, 0, 4.2)) * S

    def shot(fn, d, lens=50, dist=9.5, show_rider=True, t=None):
        for o in rider:
            o.hide_render = not show_rider
        cam.data.lens = lens
        tt = t if t is not None else tgt
        cam.location = tt + Vector(d).normalized() * dist
        cam.rotation_euler = (tt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    gm_ = OBJ[GLASS].data.materials[0] if OBJ[GLASS].data.materials else None
    if gm_ and gm_.use_nodes:
        bsg = next(n for n in gm_.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsg.inputs["Alpha"].default_value = 0.45  # ในเกม Transparency 0.55
    shot("PickupV2.png", (-1.0, -1.3, 0.45))
    shot("PickupV2_side.png", (-1.0, 0.0, 0.1), dist=10.5)
    shot("PickupV2_rear.png", (0.8, 1.3, 0.5))
    shot("PickupV2_front.png", (0.25, -1.0, 0.25), dist=8.0)
    shot("PickupV2_cab.png", (-1.0, -0.35, 0.25), lens=60, dist=4.0, t=Vector((-1.2, -1.0, 5.6)) * S)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "pickup_v2.blend"))
log("done")
