# ThaiSedanSoluna v2 — เก๋งยุค 90 สีบรอนซ์ทอง 4 ประตู ปั้นใหม่ทั้งคัน (ผู้ใช้ 2026-11-08 "ทำเก๋ง" สีเดียว)
# รัน: blender -b --factory-startup --python tools/blender/sedan_v2.py
# ผลลัพธ์: assets/models/SedanV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ tools/blender/vehlib.py · แกน Blender: หน้ารถ -Y, ซ้าย +X (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
# ตำแหน่งตามแม่แบบเดิม (src/shared/ThaiVehicleRigs.luau ThaiSedanSoluna, Roblox):
#   ล้อ (±2.95, 1.30, -6.0 / 5.6) r 1.3 กว้าง 1.0 · ไฟหน้า (±2.2, 2.78, -10.33) 1.4x0.45 · ไฟท้าย (±2.2, 3.25, 10.03) 1.5x0.5
#   ป้าย หน้า (0, 1.85, -10.39) / หลัง (0, 2.75, 10.05) · เบาะคนขับ (1.6, 2.45, -0.85) บน 2.60 · เบาะหลัง (±1.55, 2.45, 2.1)
#   สะโพกคนขับที่เกมคำนวณ ~ (1.6, 2.60, -0.62) -> เบาะจริง 2.30 · พื้นในรถ 1.10 (เท้า = สะโพก - 1.5)
#   มือจับพวงมาลัย ~ (2.15 / 1.30, 4.20, -2.57) -> พวงมาลัยศูนย์กลาง (1.73, 4.20, -2.50) รัศมี 0.48
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "SedanV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = int(os.environ.get("VEH_TEX", "1024"))
V.SAMPLES = int(os.environ.get("VEH_SAMPLES", "16"))
NO_BAKE = os.environ.get("VEH_NOBAKE") == "1"
S = V.S
G, loft, tube, lathe_x, lathe_axis, box, ring_y, ring_z, put, L, sup = V.G, V.loft, V.tube, V.lathe_x, V.lathe_axis, V.box, V.ring_y, V.ring_z, V.put, V.L, V.sup

WF_Y, WR_Y, AX_Z, WR, WW = -6.0, 5.6, 1.30, 1.30, 1.0
V.FRONT_Y, V.AXLE_Z, V.TREAD_N = WF_Y, AX_Z, 60.0
Y0, Y1 = -10.25, 9.95
ROCK = 1.38
ARCH_R = 1.72
ROOF = 7.05
W0 = 3.55


def log(*a):
    print("SD|", *a)


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def arch_bottom(y, base):
    for wy in (WF_Y, WR_Y):
        d = y - wy
        if abs(d) < ARCH_R:
            base = max(base, AX_Z + math.sqrt(ARCH_R * ARCH_R - d * d))
    return base


def ys(a, b, n):
    return [a + (b - a) * i / n for i in range(n + 1)]


def W(y):  # ครึ่งความกว้าง: หน้า/ท้ายมน
    return W0 - 0.45 * ease((Y0 + 1.6 - y) / 1.6) ** 1.5 - 0.38 * ease((y - (Y1 - 1.3)) / 1.3) ** 1.5


def belt(y):
    if y < -3.3:
        return 3.35 + 0.83 * math.sin(0.5 * math.pi * ease((y - Y0) / (-3.3 - Y0)) ** 0.8)
    if y > 8.7:
        return 4.22 - 0.5 * ease((y - 8.7) / (Y1 - 8.7)) ** 2
    return 4.2 + 0.02 * ease((y - 3.8) / 1.0)


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


# ---------------------------------------------------------------- วัสดุ (บรอนซ์ทอง ใช้มานานแต่ไม่ผุ)
V.make_mat("sd_paint", L((158, 130, 90)), 0.36, 0.25, dirt=0.5, wear=0.25, bump=0.03, bump_scale=120, rust=0.12, coat=0.5)
V.make_mat("sd_chrome", L((200, 200, 204)), 0.18, 1.0, dirt=0.35, rust=0.15)
V.make_mat("sd_black", L((22, 22, 22)), 0.6, 0.0, dirt=0.5, bump=0.06, bump_scale=200)
V.make_mat("sd_under", L((30, 28, 26)), 0.8, 0.3, dirt=0.9, rust=0.4)
V.make_mat("sd_tire", L((20, 20, 20)), 0.88, 0.0, dirt=0.3, bump=0.32, kind="tread")
V.make_mat("sd_cover", L((176, 178, 180)), 0.35, 0.6, dirt=0.6, wear=0.2)
V.make_mat("sd_glass", L((24, 30, 34)), 0.06, 0.0, dirt=0.2)
V.make_mat("sd_lens", L((236, 232, 220)), 0.12, 0.0, dirt=0.3)
V.make_mat("sd_amber", L((230, 120, 30)), 0.2, 0.0, dirt=0.3)
V.make_mat("sd_red", L((150, 20, 18)), 0.2, 0.0, dirt=0.3)
V.make_mat("sd_dash", L((48, 46, 44)), 0.6, 0.0, dirt=0.35, bump=0.08, bump_scale=220)
V.make_mat("sd_fabric", L((92, 86, 80)), 0.85, 0.0, dirt=0.3, bump=0.3, bump_scale=160)
V.make_mat("sd_trim", L((150, 144, 134)), 0.7, 0.0, dirt=0.4, bump=0.05, bump_scale=200)
V.make_mat("sd_mat", L((34, 32, 30)), 0.9, 0.0, dirt=0.6, bump=0.2, bump_scale=60)
V.make_mat("sd_gauge", L((12, 14, 14)), 0.1, 0.0, dirt=0.1)

BODY, GLASS, INT, WHEEL = "SedanBody", "SedanGlass", "SedanInterior", "SedanWheel"

# ================================================================ ตัวถัง
# 1) หน้ารถ (ฝากระโปรง + บังโคลนหน้า + จมูกมน)
rings = []
for y in ys(Y0, -3.3, 16):
    top, bot = belt(y), arch_bottom(y, ROCK + 0.25 * ease((Y0 + 1.0 - y) / 1.0))
    rings.append(ring_y(0, y, (top + bot) / 2, W(y), (top - bot) / 2, 28, 9.0))  # เหลี่ยมมน: ฝากระโปรงแบน ไหล่ชัด
put(BODY, loft(rings), "sd_paint", 1)
# 2) ท้ายรถ (ฝากระโปรงท้าย + บังโคลนหลัง) เริ่มหลังเบาะหลัง (= ชั้นวางของหลังเบาะ)
rings = []
for y in ys(3.85, Y1, 14):
    top, bot = belt(y), arch_bottom(y, ROCK + 0.3 * ease((y - (Y1 - 0.9)) / 0.9))
    rings.append(ring_y(0, y, (top + bot) / 2, W(y), (top - bot) / 2, 28, 9.0))  # เหลี่ยมมน: ฝากระโปรงแบน ไหล่ชัด
put(BODY, loft(rings), "sd_paint", 1)
# 3) ห้องโดยสารส่วนล่าง (เปิดด้านบน)
tub = []
for y in ys(-3.35, 3.9, 12):
    hx = W(y)
    prof = [(hx, 4.2), (hx, 2.7), (hx - 0.03, 2.0), (hx - 0.15, ROCK + 0.05), (hx - 0.4, ROCK), (-(hx - 0.4), ROCK), (-(hx - 0.15), ROCK + 0.05), (-(hx - 0.03), 2.0), (-hx, 2.7), (-hx, 4.2)]
    tub.append([(x, y, z) for x, z in prof])
put(BODY, loft_open(tub), "sd_paint", 0)
# คิ้วข้าง (ยางดำ) + ร่องประตู 4 บาน + มือจับ + กระจกมองข้าง
for sx in (1, -1):
    put(BODY, tube([(sx * (W0 + 0.02), -3.0, 2.55), (sx * (W0 + 0.02), 3.6, 2.55)], 0.06, 6), "sd_black", 0)
    put(BODY, tube([(sx * (W0 - 0.02), -3.2, 4.22), (sx * (W0 - 0.02), 3.75, 4.22)], 0.045, 6), "sd_black", 0)
    for (a, b) in ((-3.15, 0.85), (0.95, 3.7)):
        put(BODY, tube([(sx * (W0 + 0.005), a, 4.15), (sx * (W0 + 0.005), a, 1.55), (sx * (W0 + 0.005), b, 1.55), (sx * (W0 + 0.005), b, 4.15)], 0.018, 4, cap=False), "sd_black", 0)
        put(BODY, box((sx * (W0 + 0.03), b - 0.45, 3.75), (0.05, 0.45, 0.1)), "sd_chrome", 0, bevel=0.02)
    put(BODY, tube([(sx * 3.45, -3.0, 4.3), (sx * 3.75, -3.0, 4.55)], 0.05, 6), "sd_black", 0)
    put(BODY, loft([ring_z(sx * 3.95, -3.0, z, 0.2, 0.08, 14, 3.0) for z in (4.42, 4.62, 4.82)]), "sd_paint", 1)
# 4) หลังคา + เสา A/B/C
rr = []
for y in ys(-1.15, 2.8, 12):
    rr.append(ring_y(0, y, ROOF - 0.16, 3.12 - 0.06 * ((y - 0.8) / 2) ** 2, 0.18, 24, 2.6))
put(BODY, loft(rr), "sd_paint", 1)
for sx in (1, -1):
    put(BODY, tube([(sx * 3.4, -3.28, 4.22), (sx * 3.25, -2.2, 5.75), (sx * 3.08, -1.12, ROOF - 0.22)], 0.12, 10), "sd_paint", 0)
    put(BODY, tube([(sx * 3.42, 0.9, 4.22), (sx * 3.25, 0.9, 5.7), (sx * 3.1, 0.85, ROOF - 0.22)], 0.13, 10), "sd_black", 0)
    # เสา C กว้าง (แผ่น) จากหลังคาลงท้าย
    cp = [(sx * 3.08, 2.75, ROOF - 0.2), (sx * 3.2, 3.5, 5.8), (sx * 3.38, 4.25, 4.3)]
    put(BODY, tube(cp, [0.16, 0.22, 0.26], 10), "sd_paint", 0)
    edge = [(sx * 3.38, -3.15, 4.28), (sx * 3.22, -2.15, 5.78), (sx * 3.08, -1.05, ROOF - 0.32), (sx * 3.08, 2.6, ROOF - 0.32), (sx * 3.22, 3.45, 5.8), (sx * 3.36, 4.15, 4.3)]
    put(BODY, tube(edge, 0.03, 5, cap=False), "sd_black", 0)
# 5) หน้า: กระจัง กรอบไฟหน้า ไฟเลี้ยว กันชนสีตัวรถ + แถบดำ
put(BODY, box((0, Y0 - 0.02, 2.74), (1.9, 0.12, 0.4)), "sd_black", 0, bevel=0.03)
for k in range(3):
    put(BODY, box((0, Y0 - 0.07, 2.62 + k * 0.12), (1.8, 0.04, 0.04)), "sd_chrome", 0)
put(BODY, tube([(-0.95, Y0 - 0.08, 2.52), (0.95, Y0 - 0.08, 2.52), (0.95, Y0 - 0.08, 2.96), (-0.95, Y0 - 0.08, 2.96), (-0.95, Y0 - 0.08, 2.52)], 0.03, 6, cap=False), "sd_chrome", 0)
for sx in (1, -1):
    put(BODY, box((sx * 2.2, -10.24, 2.78), (1.56, 0.12, 0.58)), "sd_black", 0, bevel=0.04)
    put(BODY, box((sx * 2.2, -10.30, 2.78), (1.4, 0.04, 0.45)), "sd_lens", 0, bevel=0.02)
    put(BODY, box((sx * 3.15, -10.0, 2.78), (0.4, 0.3, 0.42)), "sd_amber", 0, bevel=0.04)
put(BODY, loft([ring_y(0, y, 1.85, 3.45, 0.45, 24, 5.0) for y in ys(-10.48, -9.9, 2)]), "sd_paint", 1)
put(BODY, box((0, -10.5, 2.05), (6.6, 0.06, 0.14)), "sd_black", 0)
# 6) ท้าย: ไฟท้ายยาว ช่องป้าย กันชน
for sx in (1, -1):
    put(BODY, box((sx * 2.2, 9.98, 3.25), (1.62, 0.12, 0.62)), "sd_black", 0, bevel=0.04)
    put(BODY, box((sx * 2.2, 10.04, 3.25), (1.5, 0.04, 0.5)), "sd_red", 0, bevel=0.02)
    put(BODY, box((sx * 1.6, 10.05, 3.25), (0.3, 0.035, 0.46)), "sd_amber", 0)
put(BODY, box((0, 9.99, 2.75), (1.7, 0.06, 0.88)), "sd_black", 0, bevel=0.02)
put(BODY, loft([ring_y(0, y, 1.85, 3.4, 0.45, 24, 5.0) for y in ys(9.8, 10.32, 2)]), "sd_paint", 1)
put(BODY, box((0, 10.33, 2.05), (6.4, 0.06, 0.14)), "sd_black", 0)
# ซุ้มล้อด้านใน
for wy in (WF_Y, WR_Y):
    for sx in (1, -1):
        rings = []
        for k in range(15):
            a = math.radians(-8 + 196 * k / 14)
            cy, cz = wy - ARCH_R * 0.99 * math.cos(a), AX_Z + ARCH_R * 0.99 * math.sin(a)
            rings.append([(sx * 2.95 + dx, cy, cz + dz) for dx, dz in ((-0.65, 0), (0.65, 0), (0.65, 0.06), (-0.65, 0.06))])
        g = G()
        for r in rings:
            g.v += r
        for j in range(len(rings) - 1):
            for i in range(4):
                a_, b_ = j * 4 + i, j * 4 + (i + 1) % 4
                g.f.append((a_, b_, b_ + 4, a_ + 4))
        put(BODY, g, "sd_under", 0)
# ใต้ท้อง + ท่อไอเสีย
put(BODY, box((0, 0, 1.18), (5.6, 18.5, 0.12)), "sd_under", 0)
put(BODY, tube([(-0.5, -3.0, 0.95), (-0.6, 6.5, 0.95), (-1.3, 9.0, 1.0), (-1.6, 10.2, 1.0)], 0.1, 10), "sd_under", 0)
put(BODY, box((-0.9, 7.6, 1.0), (1.2, 1.6, 0.4)), "sd_under", 2)
put(BODY, lathe_axis((-1.6, 10.25, 1.0), (0, 1, 0), [(0, 0.1), (0.1, 0.1), (0.1, 0.075), (0.0, 0.075)], 10), "sd_chrome", 0)

# ================================================================ กระจก (สองด้าน)
def glass_quad(pts, inward):
    g = G()
    n = 6
    P = [Vector(p) for p in pts]
    for i in range(n + 1):
        for j in range(n + 1):
            u, w = i / n, j / n
            g.v.append(tuple(P[0].lerp(P[1], u).lerp(P[3].lerp(P[2], u), w)))
    for i in range(n):
        for j in range(n):
            a = i * (n + 1) + j
            g.f.append((a, a + n + 1, a + n + 2, a + 1))
    back = G()
    back.v = [tuple(Vector(p) + Vector(inward) * 0.02) for p in g.v]
    back.f = [tuple(reversed(f)) for f in g.f]
    return g.merge(back)


put(GLASS, glass_quad([(-3.3, -3.2, 4.28), (3.3, -3.2, 4.28), (3.06, -1.12, ROOF - 0.3), (-3.06, -1.12, ROOF - 0.3)], (0, 0.6, -0.5)), "sd_glass", 0)
put(GLASS, glass_quad([(3.06, 2.7, ROOF - 0.3), (-3.06, 2.7, ROOF - 0.3), (-3.3, 4.2, 4.3), (3.3, 4.2, 4.3)], (0, -0.6, -0.6)), "sd_glass", 0)
for sx in (1, -1):
    put(GLASS, glass_quad([(sx * 3.38, -3.1, 4.3), (sx * 3.38, 0.82, 4.3), (sx * 3.1, 0.82, ROOF - 0.34), (sx * 3.1, -1.05, ROOF - 0.34)], (-sx, 0, 0)), "sd_glass", 0)
    put(GLASS, glass_quad([(sx * 3.38, 0.98, 4.3), (sx * 3.38, 4.05, 4.3), (sx * 3.1, 2.62, ROOF - 0.34), (sx * 3.1, 0.98, ROOF - 0.34)], (-sx, 0, 0)), "sd_glass", 0)

# ================================================================ ภายใน
DRV_X = -1.6  # คนขับขวา (Roblox +X)
put(INT, box((0, 0.3, 1.05), (6.7, 7.2, 0.1)), "sd_mat", 0)
put(INT, loft([ring_y(0, y, 3.75, 3.25, 0.48, 20, 4.0) for y in ys(-3.35, -2.55, 3)]), "sd_dash", 1)
put(INT, box((0, -3.3, 2.4), (6.6, 0.1, 2.3)), "sd_dash", 0)
put(INT, box((DRV_X, -2.6, 4.05), (1.5, 0.2, 0.55)), "sd_dash", 0, bevel=0.05)
for dx in (-0.35, 0.35):
    put(INT, lathe_axis((DRV_X + dx, -2.49, 4.06), (0, 1, 0), [(0, 0.0), (0, 0.22), (0.02, 0.22), (0.02, 0.0)], 18), "sd_gauge", 0)
put(INT, box((0, -2.75, 2.7), (0.9, 1.0, 1.3)), "sd_dash", 0, bevel=0.05)  # คอนโซลกลาง
wc = Vector((-1.73, -2.5, 4.2))
ax = Vector((0, 0.5, 0.66)).normalized()
u = Vector((1, 0, 0))
w = ax.cross(u).normalized()
rim = [tuple(wc + (u * math.cos(2 * math.pi * i / 28) + w * math.sin(2 * math.pi * i / 28)) * 0.48) for i in range(29)]
put(INT, tube(rim, 0.05, 8, cap=False), "sd_dash", 0)
for a in (0, math.pi, -math.pi / 2):
    put(INT, tube([tuple(wc), tuple(wc + (u * math.cos(a) + w * math.sin(a)) * 0.46)], 0.035, 6), "sd_dash", 0)
put(INT, tube([tuple(wc), tuple(wc - ax * 0.9)], 0.07, 8), "sd_dash", 0)
put(INT, lathe_axis(tuple(wc), tuple(ax), [(-0.05, 0.0), (-0.05, 0.13), (0.04, 0.11), (0.05, 0.0)], 14), "sd_dash", 0)
# เบาะหน้าแยก 2 ตัว (บนเบาะ 2.30) + เบาะหลังยาว
for sx in (1, -1):
    put(INT, loft([ring_y(sx * 1.6, y, 2.06, 0.9, 0.24, 20, 4.0) for y in ys(-1.75, 0.0, 3)]), "sd_fabric", 1)
    put(INT, loft([ring_z(sx * 1.6, y, z, 0.88, 0.2, 18, 4.0) for (y, z) in ((0.05, 2.2), (0.15, 3.2), (0.26, 4.2), (0.3, 4.65))]), "sd_fabric", 1)
    put(INT, box((sx * 1.6, 0.32, 4.95), (0.6, 0.22, 0.45)), "sd_fabric", 2)
    put(INT, box((sx * 1.6, -0.9, 1.5), (0.9, 1.4, 0.7)), "sd_dash", 0)
put(INT, loft([ring_y(0, y, 2.06, 3.0, 0.24, 24, 4.0) for y in ys(1.4, 2.85, 3)]), "sd_fabric", 1)
put(INT, loft([ring_z(0, y, z, 3.0, 0.2, 22, 4.0) for (y, z) in ((2.95, 2.2), (3.1, 3.2), (3.25, 4.2))]), "sd_fabric", 1)
put(INT, box((0, 3.6, 2.4), (6.4, 0.6, 2.3)), "sd_dash", 0)
for sx in (1, -1):
    put(INT, box((sx * 3.42, 0.3, 2.95), (0.1, 7.0, 2.5)), "sd_trim", 0, bevel=0.03)
    put(INT, box((sx * 3.34, -1.2, 3.25), (0.18, 1.3, 0.1)), "sd_dash", 0)
    put(INT, box((sx * 3.34, 2.2, 3.25), (0.18, 1.1, 0.1)), "sd_dash", 0)
put(INT, box((0, 0.8, ROOF - 0.34), (6.0, 3.9, 0.05)), "sd_trim", 0)
for dx in (-0.35, 0.0, 0.4):
    put(INT, box((DRV_X + dx, -2.9, 1.35), (0.25, 0.08, 0.35)), "sd_dash", 0)
put(INT, tube([(0, -2.3, 2.0), (0, -2.0, 2.9)], 0.035, 6), "sd_dash", 0)

# ================================================================ ล้อ (ฝาครอบล้อพลาสติกเงิน) ปั้นที่ x = 0 ด้านนอก = +X (ล้อซ้าย)
cy, cz = WF_Y, AX_Z
prof = []
for k in range(17):
    t = -1 + 2 * k / 16
    a = t * math.pi * 0.6
    r = 1.03 + 0.27 * math.cos(a)
    prof.append((WW / 2 * math.sin(a) * 1.08, min(WR, r)))
prof = [(-0.44, 0.88)] + prof + [(0.44, 0.88)]
put(WHEEL, lathe_x(cy, cz, prof, 56), "sd_tire", 0)
put(WHEEL, lathe_x(cy, cz, [(-0.42, 0.88), (-0.42, 0.93), (0.38, 0.93), (0.42, 0.88), (0.42, 0.0)], 48), "sd_under", 0)
cover = [(0.42, 0.9), (0.46, 0.88), (0.5, 0.75), (0.52, 0.5), (0.53, 0.2), (0.53, 0.0)]
put(WHEEL, lathe_x(cy, cz, cover, 48), "sd_cover", 0)
for i in range(10):  # ช่องลมบนฝาครอบ
    a = 2 * math.pi * i / 10
    put(WHEEL, box((0.535, cy + 0.62 * math.cos(a), cz + 0.62 * math.sin(a)), (0.02, 0.12, 0.12)), "sd_under", 0)
put(WHEEL, lathe_axis((0.535, cy, cz), (1, 0, 0), [(0, 0.18), (0.03, 0.18), (0.05, 0.1), (0.06, 0.0)], 18), "sd_chrome", 0)

# ---------------------------------------------------------------- object + bake + export
ORDER = [BODY, GLASS, INT, WHEEL]
OBJ = {n: V.build_object(n) for n in ORDER}
for n, ob in OBJ.items():
    cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c = (mn + mx) / 2
    sz = mx - mn
    log(f"BBOX {n} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({sz.x:.3f},{sz.z:.3f},{sz.y:.3f})")
BAKED = {BODY: "SedanV2_Body", GLASS: "SedanV2_Glass", INT: "SedanV2_Interior", WHEEL: "SedanV2_Wheel"}
if not NO_BAKE:
    for name, stem in BAKED.items():
        ob = OBJ[name]
        V.uv_unwrap(ob)
        log("baking", name)
        mat = V.final_material(stem, V.bake(ob, stem))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0
bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ[BODY]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "SedanV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "SedanV2.fbx"))


def preview():
    scn = bpy.context.scene
    wob = OBJ[WHEEL]
    for (rx, rz) in ((2.95, WF_Y), (-2.95, WR_Y), (2.95, WR_Y)):
        c = wob.copy()
        c.data = wob.data
        scn.collection.objects.link(c)
        m = Matrix.Translation(Vector((0, rz - WF_Y, 0)) * S)
        if rx > 0:
            hub = Vector((0, WF_Y, AX_Z)) * S
            m = m @ Matrix.Translation(hub) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation(-hub)
        c.matrix_world = Matrix.Translation(Vector((-rx, 0, 0)) * S) @ m
    wob.location = Vector((2.95, 0, 0)) * S
    rider = []
    path = os.path.join(ROOT, "human_base", "human_base.blend")
    if os.path.exists(path):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_red_shirt") or n == "Hair_side_part"]
            dst.actions = [n for n in src.actions if n == "drive_car"]
        rider = [o for o in dst.objects if o]
        for o in rider:
            scn.collection.objects.link(o)
        rig = next((o for o in rider if o.type == "ARMATURE"), None)
        if rig and dst.actions:
            rig.animation_data_create()
            rig.animation_data.action = dst.actions[0]
            scn.frame_set(1)
            rig.location = Vector((-1.6, -0.62, 2.60)) * S - rig.data.bones["hips"].head_local
    gm_ = OBJ[GLASS].data.materials[0] if OBJ[GLASS].data.materials else None
    if gm_ and gm_.use_nodes:
        next(n for n in gm_.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Alpha"].default_value = 0.45
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1400, 860
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-12, -12, 0), (12, -12, 0), (12, 12, 0), (-12, 12, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gmat = bpy.data.materials.new("G")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.2, 0.15, 1)
    gp.materials.append(gmat)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((0, 0, 3.4)) * S

    def shot(fn, d, dist=8.6, lens=50, t=None):
        cam.data.lens = lens
        tt = t if t is not None else tgt
        cam.location = tt + Vector(d).normalized() * dist
        cam.rotation_euler = (tt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    shot("SedanV2.png", (-1.0, -1.3, 0.42))
    shot("SedanV2_side.png", (-1.0, 0.0, 0.08), dist=9.8)
    shot("SedanV2_rear.png", (0.8, 1.3, 0.45))
    shot("SedanV2_front.png", (0.3, -1.0, 0.25), dist=7.5)
    shot("SedanV2_cab.png", (-1.0, -0.4, 0.3), lens=60, dist=3.8, t=Vector((-1.2, -1.2, 4.4)) * S)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "sedan_v2.blend"))
log("done")
