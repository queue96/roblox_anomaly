# TireStack v2 — ยางเก่ามุมปะยาง (กองยาง 4 เส้น / ยางพิง / ยางติดกระทะ) ปั้นใหม่ มีดอกยาง แก้มยาง ฝุ่นดิน (ผู้ใช้ 2026-11-08)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/tire_stack_v2.py
# ผลลัพธ์: assets/models/TireStackV2/upload/ · ชั้นนอก: ภาพตัวอย่าง + .blend
# แต่ละชิ้น origin = พื้นใต้กึ่งกลางของชิ้นนั้น (ซ้อนกันที่ 0,0,0 ในไฟล์) ขนาดเท่าชิ้นเดิมใน TireStack.fbx:
#   TireStack_4 2.72 x 2.65 x 2.76 (สูง) · TireLeaning 2.40 x 1.28 x 2.43 (เอียง 14°) · TireWithRim 2.41 x 2.39 x 0.72
#   (MapBuilder.SwapTireStackV2 แทนทุกชิ้นชื่อนี้ในฉาก + TireLoose ด้วย TireLeaning ตามตำแหน่ง/มุมของชิ้นเดิม)
import bpy, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "TireStackV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, lathe, put, L = V.G, V.box, V.lathe_axis, V.put, V.L
ZUP = (0, 0, 1)
R = random.Random(1108)

STACK, LEAN, RIM = "TireStack_4", "TireLeaning", "TireWithRim"

# ---------------------------------------------------------------- วัสดุ (ยางเก่าซีดเทา ฝุ่นดินแดงท่อนล่าง)
V.make_mat("TireRubber", L((36, 35, 34)), 0.85, dirt=0.42, bump=0.06, bump_scale=260)
V.make_mat("TireWorn", L((48, 46, 44)), 0.88, dirt=0.48, bump=0.08, bump_scale=220)
V.make_mat("RimSteel", L((58, 58, 56)), 0.6, metal=0.6, dirt=0.6, wear=0.5, rust=0.45)
V.make_mat("RimPaint", L((104, 102, 96)), 0.6, metal=0.4, dirt=0.65, wear=0.55, rust=0.4)
P.flat("Hole", L((14, 13, 12)), rough=0.9, dirt=0.0)
V.make_mat("Mud", L((96, 64, 40)), 0.95, dirt=0.3, bump=0.5, bump_scale=60)
P.flat("Water", L((22, 27, 24)), rough=0.08, dirt=0.0, noise=0.05)


def tire(R_out, W, r_in, lugs=30, n=96, wear=0.0, seed=0):
    """ยางรอบแกน Z ก้นอยู่ที่ z = 0 · ดอกยางบั้งสลับซ้ายขวา + ร่องกลาง · แก้มยางมีเส้นนูน 2 วง"""
    rr = random.Random(seed)
    h = W / 2
    # โปรไฟล์หน้าตัด (z, radius, kind) เดินรอบหน้าตัดปิด
    prof = [(-h * 0.88, r_in, "b"), (-h, r_in + 0.06, "s"), (-h * 1.02, r_in + 0.22, "s"), (-h * 1.04, (r_in + R_out) / 2, "rib"), (-h * 1.0, R_out - 0.2, "s"),
            (-h * 0.9, R_out - 0.07, "s"), (-h * 0.74, R_out - 0.01, "tL"), (-h * 0.4, R_out, "tL"), (-h * 0.12, R_out, "tL"), (0.0, R_out - 0.03, "g"),
            (h * 0.12, R_out, "tR"), (h * 0.4, R_out, "tR"), (h * 0.74, R_out - 0.01, "tR"), (h * 0.9, R_out - 0.07, "s"), (h * 1.0, R_out - 0.2, "s"),
            (h * 1.04, (r_in + R_out) / 2, "rib"), (h * 1.02, r_in + 0.22, "s"), (h, r_in + 0.06, "s"), (h * 0.88, r_in, "b"), (h * 0.3, r_in - 0.02, "b"), (-h * 0.3, r_in - 0.02, "b")]
    m = len(prof)
    g = G()
    wob = [rr.uniform(-0.012, 0.012) for _ in range(6)]
    for i in range(n):
        a = 2 * math.pi * i / n
        # ยางเก่าบิดเบี้ยวนิดๆ
        warp = 1.0 + sum(wob[k] * math.sin((k + 2) * a + k) for k in range(6))
        for (z, r, kind) in prof:
            rad = r
            if kind in ("tL", "tR"):
                ph = lugs * a + (0 if kind == "tL" else math.pi / 2) + (z / h) * 1.2
                lug = 1.0 if math.sin(ph) > -0.25 else 0.0
                rad = r - (1 - lug) * (0.06 * (1 - wear))
            if kind == "rib":
                rad = r
            rad *= warp
            zz = z + (0.015 if kind == "rib" and z > 0 else -0.015 if kind == "rib" else 0.0)
            g.v.append((math.cos(a) * rad, math.sin(a) * rad, zz + h))
    for i in range(n):
        j = (i + 1) % n
        for k in range(m):
            k2 = (k + 1) % m
            g.f.append((i * m + k, i * m + k2, j * m + k2, j * m + k))
    return g


def rim(R_r, W, dish=0.16):
    """กระทะเหล็กเก่า (แกน Z) จานลึก มีรูน็อต 5 รู + รูระบาย 6 รู + รูกลาง"""
    h = W / 2
    g = G()
    g.merge(lathe((0, 0, 0), ZUP, [(h * 0.82, R_r + 0.07), (h * 0.9, R_r), (h * 0.6, R_r - 0.03), (-h * 0.6, R_r - 0.03), (-h * 0.9, R_r), (-h * 0.82, R_r + 0.07)], n=48))
    disc = lathe((0, 0, 0), ZUP, [(dish, R_r - 0.04), (dish + 0.02, R_r * 0.72), (dish + 0.08, R_r * 0.52), (dish + 0.1, R_r * 0.3), (dish + 0.08, 0.16), (dish + 0.02, 0.14), (dish, 0.0)], n=40)
    return g, disc


# ---------------------------------------------------------------- กองยาง 4 เส้น (สูงรวม 2.76)
TW = 0.69
for k in range(4):
    g = tire(1.33 - 0.015 * (k % 2), TW, 0.78, lugs=30 + k * 2, wear=0.2 + 0.25 * (k % 3), seed=k)
    m = Matrix.Translation(Vector((R.uniform(-0.05, 0.05), R.uniform(-0.05, 0.05), k * TW))) @ Matrix.Rotation(R.uniform(0, 6.28), 4, "Z")
    if k == 3:
        m = m @ Matrix.Translation(Vector((0, 0, TW / 2))) @ Matrix.Rotation(math.radians(3), 4, "X") @ Matrix.Translation(Vector((0, 0, -TW / 2)))
    put(STACK, P.xform(g, m), "TireRubber" if k % 2 == 0 else "TireWorn")
# น้ำขังเขียวดำในยางเส้นบน (ยางกองกลางแจ้ง) + ดินติดเส้นล่าง
put(STACK, P.extrude_z([(math.cos(a) * 0.9, math.sin(a) * 0.9) for a in [2 * math.pi * i / 20 for i in range(20)]], 3 * TW + 0.05, 3 * TW + 0.07), "Water")

# ---------------------------------------------------------------- ยางพิง (เส้นเล็กกว่า เอียงพิง 14°)
LR, LW = 1.2, 0.62
g = tire(LR, LW, 0.72, lugs=28, wear=0.55, seed=11)
m = Matrix.Rotation(math.radians(14), 4, "X") @ Matrix.Translation(Vector((0, 0, LR))) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Translation(Vector((0, 0, -LW / 2)))
gl = P.xform(g, m)
zmin = min(v[2] for v in gl.v)
ymid = (min(v[1] for v in gl.v) + max(v[1] for v in gl.v)) / 2
gl = P.xform(gl, Matrix.Translation(Vector((0, -ymid, -zmin))))
put(LEAN, gl, "TireWorn")

# ---------------------------------------------------------------- ยางติดกระทะ (นอนราบ)
RR, RW = 1.2, 0.72
put(RIM, tire(RR, RW, 0.82, lugs=32, wear=0.35, seed=21), "TireRubber")
rg, disc = rim(0.82, RW)
put(RIM, P.xform(rg, Matrix.Translation(Vector((0, 0, RW / 2)))), "RimSteel")
put(RIM, P.xform(disc, Matrix.Translation(Vector((0, 0, RW / 2)))), "RimPaint")
top = RW / 2 + 0.16 + 0.1
for i in range(5):                                          # รูน็อต
    a = 2 * math.pi * i / 5
    put(RIM, P.cyl((math.cos(a) * 0.24, math.sin(a) * 0.24, top - 0.005), ZUP, 0.045, 0.012, n=8), "Hole")
for i in range(6):                                          # รูระบายรูปไข่
    a = 2 * math.pi * (i + 0.5) / 6
    c = (math.cos(a) * 0.5, math.sin(a) * 0.5)
    pts = [(c[0] + math.cos(a) * 0.1 * math.cos(t) - math.sin(a) * 0.06 * math.sin(t), c[1] + math.sin(a) * 0.1 * math.cos(t) + math.cos(a) * 0.06 * math.sin(t)) for t in [2 * math.pi * k / 12 for k in range(12)]]
    put(RIM, P.extrude_z(pts, RW / 2 + 0.16 + 0.02 + 0.05, RW / 2 + 0.16 + 0.02 + 0.062), "Hole")
put(RIM, P.cyl((0, 0, top - 0.005), ZUP, 0.12, 0.012, n=14), "Hole")
put(RIM, P.cyl((0.0, 0.62, RW / 2 + 0.18), ZUP, 0.03, 0.14, n=6), "RimSteel")        # จุ๊บลม

# ---------------------------------------------------------------- object + bake + export
ORDER = [STACK, LEAN, RIM]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
if not NO_BAKE:
    P.bake_all(OBJ, {STACK: "TireStackV2_Stack", LEAN: "TireStackV2_Leaning", RIM: "TireStackV2_Rim"}, {STACK: 1024, LEAN: 512, RIM: 1024})
P.export_fbx(OBJ, os.path.join(UP, "TireStackV2.fbx"), STACK)


def preview():
    OBJ[LEAN].location = Vector((3.4, 0.4, 0)) * V.S
    OBJ[RIM].location = Vector((-3.4, -0.6, 0)) * V.S
    cam, sun, world = P.stage(ground=(0.33, 0.22, 0.14))
    P.add_person(ROOT, (1.0, 2.6, 0.0), yaw_deg=-10)
    P.shot(cam, os.path.join(OUT, "TireStackV2.png"), (0, 0, 1.3), (-0.3, -1.2, 0.55), 15.0)
    P.shot(cam, os.path.join(OUT, "TireStackV2_close.png"), (0, 0, 2.0), (0.4, -1.0, 0.6), 6.0)
    P.shot(cam, os.path.join(OUT, "TireStackV2_rim.png"), (-3.4, -0.6, 0.5), (0.0, -0.6, 1.0), 5.0)
    P.night(world, sun, (1.0, -5.0, 8.0), energy=70)
    P.shot(cam, os.path.join(OUT, "TireStackV2_night.png"), (0, 0, 1.3), (-0.3, -1.2, 0.5), 15.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "tire_stack_v2.blend"))
P.log("done")
