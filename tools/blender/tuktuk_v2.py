# ThaiTukTuk v2 — ตุ๊กตุ๊กสีน้ำเงิน หลังคาผ้าใบดำ ป้าย TAXI ปั้นใหม่ทั้งคัน (ผู้ใช้ 2026-11-08 "เหลือรถตุ๊กๆ")
# รัน: blender -b --factory-startup --python tools/blender/tuktuk_v2.py
# ผลลัพธ์: assets/models/TukTukV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ tools/blender/vehlib.py · แกน Blender: หน้ารถ -Y, ซ้าย +X (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
# ตำแหน่งตามแม่แบบเดิม (src/shared/ThaiVehicleRigs.luau ThaiTukTuk, Roblox):
#   ล้อหน้า (0, 1, -4.7) ล้อหลัง (±2.15, 1, 2.9) r 1.0 กว้าง 0.7 · ไฟหน้ากลม (±0.62, 3.2, -6.26) Ø0.62 · ไฟท้าย (±1.8, 4.7, 4.16) 0.8x0.6
#   ป้ายหลัง (0, 2.5, 4.1) · ป้าย TAXI บนหลังคา (0, 8.9, -2.98 / -2.62) 1.75x0.75 · กระจกหน้า (0, 6.05, -3.2) 2.9x3.1
#   เบาะคนขับ (DriverSeat) (0, 3.0, -1.7) บน 3.15 · เบาะผู้โดยสาร (±1.05, 2.6, 2.7) บน 2.75 · พื้น 1.65
#   สะโพกคนขับที่เกมคำนวณ ~ (0, 3.15, -0.97) -> เบาะจริง 2.85
#   แฮนด์ (ใหม่: CoreLoop.humanizeDriver ใช้เป้ามือนี้เมื่อ TukTukVersion = 2) = สะโพก + (±0.95, 0.75, -1.6) = (±0.95, 3.90, -2.57)
#   เท้า = สะโพก + (±0.45, -1.5, -0.9) = (±0.45, 1.65, -1.87) บนพื้นห้องคนขับ
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "TukTukV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = int(os.environ.get("VEH_TEX", "1024"))
V.SAMPLES = int(os.environ.get("VEH_SAMPLES", "16"))
NO_BAKE = os.environ.get("VEH_NOBAKE") == "1"
S = V.S
G, loft, tube, lathe_x, lathe_axis, box, ring_y, ring_z, put, L = V.G, V.loft, V.tube, V.lathe_x, V.lathe_axis, V.box, V.ring_y, V.ring_z, V.put, V.L

WF_Y, WR_Y, WR_X, AX_Z, WR, WW = -4.7, 2.9, 2.15, 1.0, 1.0, 0.7
V.FRONT_Y, V.AXLE_Z, V.TREAD_N = WF_Y, AX_Z, 40.0
FLOOR = 1.65
ROOF = 8.2


def log(*a):
    print("TT|", *a)


def ys(a, b, n):
    return [a + (b - a) * i / n for i in range(n + 1)]


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- วัสดุ: น้ำเงินกรุงเทพ + ชุบ + หลังคาผ้าใบดำ
V.make_mat("tt_paint", L((24, 62, 138)), 0.32, 0.15, dirt=0.45, wear=0.3, bump=0.03, bump_scale=120, rust=0.1, coat=0.6)
V.make_mat("tt_chrome", L((205, 205, 210)), 0.15, 1.0, dirt=0.35, rust=0.15)
V.make_mat("tt_black", L((22, 22, 22)), 0.6, 0.0, dirt=0.5, bump=0.06, bump_scale=200)
V.make_mat("tt_canvas", L((26, 26, 28)), 0.85, 0.0, dirt=0.4, bump=0.25, bump_scale=90)
V.make_mat("tt_under", L((32, 30, 28)), 0.8, 0.3, dirt=0.9, rust=0.4)
V.make_mat("tt_tire", L((20, 20, 20)), 0.88, 0.0, dirt=0.3, bump=0.32, kind="tread")
V.make_mat("tt_rim", L((190, 190, 192)), 0.3, 0.8, dirt=0.6, rust=0.2)
V.make_mat("tt_glass", L((30, 36, 40)), 0.06, 0.0, dirt=0.2)
V.make_mat("tt_lens", L((236, 232, 220)), 0.12, 0.0, dirt=0.25)
V.make_mat("tt_amber", L((230, 120, 30)), 0.2, 0.0, dirt=0.3)
V.make_mat("tt_red", L((150, 20, 18)), 0.2, 0.0, dirt=0.3)
V.make_mat("tt_vinyl", L((150, 28, 30)), 0.5, 0.0, dirt=0.4, wear=0.3, bump=0.3, kind="pleat")
V.make_mat("tt_sign", L((235, 210, 60)), 0.4, 0.0, dirt=0.3)
V.make_mat("tt_mat", L((40, 38, 36)), 0.9, 0.0, dirt=0.7, bump=0.25, bump_scale=60)

BODY, GLASS, INT, WHEEL = "TukBody", "TukGlass", "TukInterior", "TukWheel"

# ================================================================ ตัวถัง
# 1) จมูกหน้า (ครอบล้อหน้า) ทรงกลมมน
rings = []
for y in ys(-6.3, -3.05, 14):
    t = (y + 6.3) / 3.25
    top = 3.95 + 0.7 * ease(t * 1.3)
    d = y - WF_Y
    bot = 1.45 if abs(d) >= 1.25 else max(1.45, AX_Z + math.sqrt(1.25 ** 2 - d * d))
    hx = 1.0 + 0.3 * ease(t * 2.5)
    rings.append(ring_y(0, y, (top + bot) / 2, hx, (top - bot) / 2, 24, 3.2))
put(BODY, loft(rings), "tt_paint", 1)
# กันชนหน้าชุบ + กระจังซี่ + ไฟหน้ากลม (กรอบชุบ) + ไฟเลี้ยว
put(BODY, tube([(1.2, -6.15, 2.05), (1.25, -6.45, 2.1), (0, -6.6, 2.12), (-1.25, -6.45, 2.1), (-1.2, -6.15, 2.05)], 0.08, 10), "tt_chrome", 0)
for k in range(5):
    put(BODY, box((0, -6.33, 2.55 + k * 0.17), (0.75, 0.05, 0.06)), "tt_chrome", 0)
for sx in (1, -1):
    c = (sx * 0.62, -6.18, 3.2)
    put(BODY, lathe_axis(c, (0, -1, 0), [(0, 0.0), (0, 0.4), (0.06, 0.4), (0.1, 0.36), (0.1, 0.0)], 24), "tt_chrome", 0)
    put(BODY, lathe_axis((sx * 0.62, -6.27, 3.2), (0, -1, 0), [(0, 0.0), (0, 0.32), (0.02, 0.3), (0.03, 0.0)], 24), "tt_lens", 0)
    put(BODY, lathe_axis((sx * 1.08, -5.6, 3.75), (sx * 0.5, -1, 0), [(0, 0.0), (0, 0.14), (0.08, 0.12), (0.12, 0.0)], 14), "tt_amber", 0)
# บังโคลนหน้า + ตะเกียบล้อหน้า
rings = []
for k in range(13):
    a = math.radians(30 + 120 * k / 12)
    cy, cz = WF_Y - 1.18 * math.cos(a), AX_Z + 1.18 * math.sin(a)
    nrm = Vector((0, -math.cos(a), math.sin(a)))
    rings.append([tuple(Vector((0, cy, cz)) + Vector((0.42 * V.sup(math.cos(2 * math.pi * i / 12), 0, 3.0), 0, 0)) + nrm * 0.03 * V.sup(math.sin(2 * math.pi * i / 12), 0, 3.0)) for i in range(12)])
put(BODY, loft(rings), "tt_black", 0)
for sx in (1, -1):
    put(BODY, tube([(sx * 0.42, WF_Y, AX_Z), (sx * 0.42, WF_Y + 0.25, 2.6)], 0.07, 8), "tt_chrome", 0)
# 2) ห้องคนขับ: พื้น แผงข้างเตี้ย (สีตัวรถ) แผงหน้าใต้กระจก
put(BODY, box((0, -0.7, FLOOR - 0.12), (4.8, 6.7, 0.24)), "tt_black", 0, bevel=0.03)
for sx in (1, -1):
    put(BODY, box((sx * 1.2, -1.8, 2.3), (0.12, 2.6, 1.3)), "tt_paint", 0, bevel=0.04)
    put(BODY, tube([(sx * 1.2, -3.1, 2.98), (sx * 1.2, -0.5, 2.98)], 0.05, 6), "tt_chrome", 0)
# 3) ห้องผู้โดยสาร: แผงข้าง (ครอบล้อหลัง) + ผนังหลัง (ไฟท้าย ป้าย)
for sx in (1, -1):
    x0, x1 = (2.22, 2.40) if sx > 0 else (-2.40, -2.22)
    pts = []
    for y in ys(0.7, 4.05, 20):
        d = y - WR_Y
        bot = FLOOR if abs(d) >= 1.15 else max(FLOOR, AX_Z + math.sqrt(1.15 ** 2 - d * d))
        pts.append([(x1, y, bot), (x1, y, 3.95), (x0, y, 3.95), (x0, y, bot)])
    put(BODY, loft(pts), "tt_paint", 0, bevel=0.03)
    put(BODY, tube([(sx * 2.32, 0.7, 3.98), (sx * 2.32, 4.05, 3.98)], 0.06, 8), "tt_chrome", 0)
    put(BODY, tube([(sx * 2.42, 0.9, 2.6), (sx * 2.42, 3.9, 2.6)], 0.035, 6), "tt_chrome", 0)
    # แผงต่อห้องคนขับ -> ห้องผู้โดยสาร (เฉียง)
    put(BODY, box((sx * 1.75, 0.25, 2.8), (1.15, 0.12, 2.3)), "tt_paint", 0, bevel=0.04)
put(BODY, box((0, 3.95, 3.5), (4.8, 0.22, 3.7)), "tt_paint", 0, bevel=0.05)
for sx in (1, -1):
    put(BODY, box((sx * 1.8, 4.08, 4.7), (0.92, 0.1, 0.72)), "tt_black", 0, bevel=0.02)
    put(BODY, box((sx * 1.8, 4.14, 4.7), (0.8, 0.04, 0.6)), "tt_red", 0)
put(BODY, box((0, 4.07, 2.5), (1.55, 0.06, 0.82)), "tt_black", 0, bevel=0.02)
put(BODY, tube([(-2.2, 4.25, 1.55), (2.2, 4.25, 1.55)], 0.07, 8), "tt_chrome", 0)
# ซุ้มล้อหลังด้านใน
for sx in (1, -1):
    rings = []
    for k in range(13):
        a = math.radians(-5 + 190 * k / 12)
        cy, cz = WR_Y - 1.15 * math.cos(a), AX_Z + 1.15 * math.sin(a)
        rings.append([(sx * WR_X + dx, cy, cz + dz) for dx, dz in ((-0.45, 0), (0.45, 0), (0.45, 0.05), (-0.45, 0.05))])
    g = G()
    for r in rings:
        g.v += r
    for j in range(len(rings) - 1):
        for i in range(4):
            a_, b_ = j * 4 + i, j * 4 + (i + 1) % 4
            g.f.append((a_, b_, b_ + 4, a_ + 4))
    put(BODY, g, "tt_under", 0)
# 4) เสา + กรอบกระจกหน้า + หลังคาผ้าใบ (ขอบมน) + ป้าย TAXI
for sx in (1, -1):
    put(BODY, tube([(sx * 1.48, -3.25, 4.5), (sx * 1.5, -3.25, 7.65), (sx * 1.6, -3.3, ROOF - 0.05)], 0.07, 8), "tt_chrome", 0)
    put(BODY, tube([(sx * 2.3, 0.45, 3.95), (sx * 2.3, 0.45, ROOF - 0.05)], 0.07, 8), "tt_chrome", 0)
    put(BODY, tube([(sx * 2.3, 3.95, 3.95), (sx * 2.3, 3.95, ROOF - 0.05)], 0.07, 8), "tt_chrome", 0)
    put(BODY, tube([(sx * 1.55, -3.2, 6.6), (sx * 2.3, 0.45, 6.6)], 0.04, 6), "tt_chrome", 0)
    # กระจกมองข้าง
    put(BODY, tube([(sx * 1.5, -3.25, 6.2), (sx * 1.95, -3.35, 6.5)], 0.03, 6), "tt_chrome", 0)
    put(BODY, lathe_axis((sx * 2.0, -3.3, 6.55), (0, 1, 0), [(-0.05, 0.0), (-0.05, 0.16), (0.02, 0.16), (0.03, 0.0)], 14), "tt_black", 0)
put(BODY, tube([(-1.48, -3.25, 4.5), (1.48, -3.25, 4.5)], 0.05, 8), "tt_chrome", 0)
put(BODY, tube([(-1.5, -3.25, 7.65), (1.5, -3.25, 7.65)], 0.05, 8), "tt_chrome", 0)
roof = [ring_y(0, y, ROOF + 0.12, 2.48 - 0.12 * ease((-2.6 - y) / 0.9), 0.17, 24, 3.0) for y in ys(-3.5, 4.12, 14)]
put(BODY, loft(roof), "tt_canvas", 1)
rim_pts = []
for y in ys(-3.5, 4.12, 14):
    rim_pts.append((2.5 - 0.12 * ease((-2.6 - y) / 0.9), y, ROOF - 0.04))
loop = rim_pts + [(-x, y, z) for (x, y, z) in reversed(rim_pts)] + [rim_pts[0]]
put(BODY, tube(loop, 0.05, 6, cap=False), "tt_chrome", 0)  # ขอบชุบรอบหลังคา (เส้น ไม่ใช่แผ่น)
put(BODY, box((0, -2.8, 8.9), (1.7, 0.3, 0.72)), "tt_sign", 0, bevel=0.05)
put(BODY, tube([(0, -2.8, 8.4), (0, -2.8, 8.55)], 0.08, 8), "tt_chrome", 0)
# 5) ใต้ท้อง: แชสซี เครื่องยนต์ใต้เบาะหลัง ท่อไอเสีย
put(BODY, box((0, -1.0, 1.25), (0.5, 8.0, 0.3)), "tt_under", 0, bevel=0.03)
put(BODY, box((0, 2.6, 1.15), (1.8, 1.6, 0.6)), "tt_under", 2)
put(BODY, tube([(-0.6, 2.2, 0.95), (-1.2, 3.6, 0.9), (-1.4, 4.4, 0.95)], 0.08, 8), "tt_under", 0)
put(BODY, lathe_axis((-1.4, 4.45, 0.95), (0, 1, 0), [(0, 0.08), (0.1, 0.08), (0.1, 0.06), (0.0, 0.06)], 10), "tt_chrome", 0)
put(BODY, tube([(-WR_X, WR_Y, AX_Z), (WR_X, WR_Y, AX_Z)], 0.1, 10), "tt_under", 0)

# ================================================================ กระจกหน้า (สองด้าน)
def glass_quad(pts, inward):
    g = G()
    n = 5
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


put(GLASS, glass_quad([(-1.44, -3.22, 4.55), (1.44, -3.22, 4.55), (1.46, -3.22, 7.6), (-1.46, -3.22, 7.6)], (0, 1, 0)), "tt_glass", 0)

# ================================================================ ภายใน: แฮนด์ แผงหน้าปัด เบาะคนขับ เบาะผู้โดยสาร
GX, GY, GZ = 0.95, -2.57, 3.90  # มือจับ
put(INT, loft([ring_y(0, y, 4.1, 1.2, 0.42, 20, 3.0) for y in ys(-3.15, -2.8, 2)]), "tt_black", 1)
put(INT, tube([(0, -2.95, 3.6), (0, -2.75, 3.85)], 0.07, 8), "tt_chrome", 0)
bar = [(-1.1, GY + 0.02, GZ), (-0.6, GY - 0.06, GZ - 0.02), (0, -2.75, 3.85), (0.6, GY - 0.06, GZ - 0.02), (1.1, GY + 0.02, GZ)]
put(INT, tube(bar, 0.045, 10), "tt_chrome", 0)
for sx in (1, -1):
    put(INT, tube([(sx * 0.78, GY, GZ), (sx * 1.12, GY + 0.02, GZ)], 0.075, 14), "tt_black", 0)
    put(INT, tube([(sx * 0.7, GY - 0.12, GZ + 0.02), (sx * 1.05, GY - 0.2, GZ - 0.02)], 0.02, 6), "tt_chrome", 0)
put(INT, lathe_axis((0, -2.98, 4.35), (0, 0.6, 0.8), [(0, 0.0), (0, 0.2), (0.03, 0.2), (0.04, 0.0)], 18), "tt_black", 0)
# เบาะคนขับ (บน 2.85) + พนักพิง
put(INT, loft([ring_y(0, y, 2.62, 1.0, 0.23, 20, 4.0) for y in ys(-2.3, -1.05, 3)]), "tt_vinyl", 1)
put(INT, box((0, -1.65, 2.05), (1.8, 1.2, 0.8)), "tt_black", 0)
put(INT, loft([ring_z(0, y, z, 1.0, 0.15, 18, 4.0) for (y, z) in ((-0.95, 2.8), (-0.88, 3.6), (-0.82, 4.4))]), "tt_vinyl", 1)
# เบาะผู้โดยสาร (บน 2.45 พอดีสะโพกผู้โดยสาร) + พนักพิงยาว + พื้นยาง
put(INT, loft([ring_y(0, y, 2.22, 2.15, 0.23, 24, 4.0) for y in ys(1.95, 3.35, 3)]), "tt_vinyl", 1)
put(INT, loft([ring_z(0, y, z, 2.15, 0.16, 22, 4.0) for (y, z) in ((3.5, 2.5), (3.62, 3.5), (3.72, 4.6))]), "tt_vinyl", 1)
put(INT, box((0, 0.5, FLOOR + 0.02), (4.4, 6.0, 0.04)), "tt_mat", 0)
put(INT, tube([(-2.1, 0.55, 3.6), (2.1, 0.55, 3.6)], 0.05, 8), "tt_chrome", 0)  # ราวจับ

# ================================================================ ล้อ (ล้อเล็ก กระทะชุบ) ปั้นที่ x = 0, y = ล้อหน้า, ด้านนอก = +X
cy, cz = WF_Y, AX_Z
prof = []
for k in range(15):
    t = -1 + 2 * k / 14
    a = t * math.pi * 0.6
    r = 0.78 + 0.22 * math.cos(a)
    prof.append((WW / 2 * math.sin(a) * 1.08, min(WR, r)))
prof = [(-0.32, 0.66)] + prof + [(0.32, 0.66)]
put(WHEEL, lathe_x(cy, cz, prof, 48), "tt_tire", 0)
put(WHEEL, lathe_x(cy, cz, [(-0.3, 0.66), (-0.3, 0.7), (0.26, 0.7), (0.3, 0.66), (0.33, 0.45), (0.35, 0.2), (0.35, 0.0)], 40), "tt_rim", 0)
for i in range(5):
    a = 2 * math.pi * i / 5
    put(WHEEL, lathe_axis((0.35, cy + 0.45 * math.cos(a), cz + 0.45 * math.sin(a)), (1, 0, 0), [(0, 0.0), (0, 0.09), (0.01, 0.09), (0.01, 0.0)], 10), "tt_under", 0)
put(WHEEL, lathe_axis((0.355, cy, cz), (1, 0, 0), [(0, 0.15), (0.04, 0.15), (0.06, 0.08), (0.07, 0.0)], 16), "tt_chrome", 0)

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
BAKED = {BODY: "TukTukV2_Body", GLASS: "TukTukV2_Glass", INT: "TukTukV2_Interior", WHEEL: "TukTukV2_Wheel"}
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
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "TukTukV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "TukTukV2.fbx"))


def preview():
    scn = bpy.context.scene
    wob = OBJ[WHEEL]
    for rx in (WR_X, -WR_X):
        c = wob.copy()
        c.data = wob.data
        scn.collection.objects.link(c)
        m = Matrix.Translation(Vector((0, WR_Y - WF_Y, 0)) * S)
        if rx > 0:
            hub = Vector((0, WF_Y, AX_Z)) * S
            m = m @ Matrix.Translation(hub) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Translation(-hub)
        c.matrix_world = Matrix.Translation(Vector((-rx, 0, 0)) * S) @ m
    rider = []
    path = os.path.join(ROOT, "human_base", "human_base.blend")
    if os.path.exists(path):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_farmer") or n == "Hair_student"]
            dst.actions = [n for n in src.actions if n == "drive_tuktuk"]
        rider = [o for o in dst.objects if o]
        for o in rider:
            scn.collection.objects.link(o)
        rig = next((o for o in rider if o.type == "ARMATURE"), None)
        if rig and dst.actions:
            rig.animation_data_create()
            rig.animation_data.action = dst.actions[0]
            scn.frame_set(1)
            rig.location = Vector((0, -0.97, 3.15)) * S - rig.data.bones["hips"].head_local
    gm_ = OBJ[GLASS].data.materials[0] if OBJ[GLASS].data.materials else None
    if gm_ and gm_.use_nodes:
        next(n for n in gm_.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Alpha"].default_value = 0.45
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1300, 860
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-10, -10, 0), (10, -10, 0), (10, 10, 0), (-10, 10, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gmat = bpy.data.materials.new("G")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.2, 0.15, 1)
    gp.materials.append(gmat)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((0, -0.8, 4.4)) * S

    def shot(fn, d, dist=7.0, lens=50):
        cam.data.lens = lens
        cam.location = tgt + Vector(d).normalized() * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    shot("TukTukV2.png", (-1.0, -1.3, 0.4))
    shot("TukTukV2_side.png", (-1.0, 0.0, 0.08), dist=7.6)
    shot("TukTukV2_rear.png", (0.8, 1.3, 0.45))
    shot("TukTukV2_front.png", (0.3, -1.0, 0.2), dist=6.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tuktuk_v2.blend"))
log("done")
