# ShackShelf v2 — ชั้นไม้ร้านโชห่วยในเพิง + ของชำไทย (ไม่มียี่ห้อ/ตัวหนังสือ) ปั้นใหม่ทั้งชุด (ผู้ใช้ 2026-11-08 "ขอดีๆ ละเอียดๆ")
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/shack_shelf_v2.py
# ผลลัพธ์: assets/models/ShackShelfV2/upload/ (FBX + texture) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ vehlib.py + proplib.py · แกน Blender: หน้าชั้น -Y, หลังชิดผนัง +Y (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
#
# ชื่อชิ้น (ดู MapBuilder.SwapShackShelfV2):
#   ShackShelf         โครงไม้ + แผ่นชั้น (ชิ้นเดียวที่ชน)
#   ShelfGoods_Lower   ของชั้น 1-2 (ล่าง) ไม่ชน
#   ShelfGoods_Upper   ของชั้น 3-5 + ขนมแผงห้อยหน้าชั้น ไม่ชน
# ขนาดเทียบของเดิม: 6.02 x 7.01 x 1.42 (กว้าง x สูง x ลึก)
import bpy, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "ShackShelfV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, tube, lathe, put, L = V.G, V.box, V.tube, V.lathe_axis, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)
R = random.Random(20261108)

FRAME, LOW, UPP = "ShackShelf", "ShelfGoods_Lower", "ShelfGoods_Upper"
W, D, H = 6.0, 1.40, 7.0
PX, PY, PS = W / 2 - 0.11, D / 2 - 0.11, 0.22        # เสา
LEVELS = [0.30, 1.76, 3.22, 4.68, 6.14]              # ความสูงใต้แผ่นชั้น
PT = 0.08                                            # ความหนาแผ่นชั้น
TOP = [z + PT for z in LEVELS]                       # ผิวบนชั้น (วางของ)
X0, X1 = -W / 2 + 0.25, W / 2 - 0.25                 # ช่วงวางของ
Y0, Y1 = -D / 2 + 0.12, D / 2 - 0.12

# ---------------------------------------------------------------- วัสดุ
P.wood("Post", L((118, 92, 64)), rough=0.8, dirt=0.5, grain_axis="Z", grain=1.0, gray=0.35)
P.wood("Plank", L((132, 100, 66)), rough=0.8, dirt=0.55, grain_axis="X", grain=1.2, gray=0.25)
P.wood("PlankDark", L((100, 74, 48)), rough=0.8, dirt=0.55, grain_axis="X", grain=1.2, gray=0.2)
V.make_mat("Nail", L((45, 40, 36)), 0.6, metal=0.5, dirt=0.2, rust=0.4)
P.flat("Paper", L((196, 190, 172)), rough=0.85, dirt=0.4, noise=0.12)
P.flat("Ink", L((40, 36, 34)), rough=0.7, dirt=0.0)
COLS = {
    "Red": (176, 40, 34), "Yellow": (222, 182, 52), "Orange": (214, 112, 38), "Blue": (40, 86, 150), "Green": (52, 120, 64),
    "White": (226, 222, 210), "Pink": (214, 120, 140), "Teal": (40, 140, 138), "Purple": (110, 70, 130), "Cream": (226, 208, 160),
}
for n, c in COLS.items():
    P.flat("Lab" + n, L(c), rough=0.55, dirt=0.35)        # ฉลากกระดาษ / กล่องพิมพ์
    P.flat("Pla" + n, L(c), rough=0.35, dirt=0.3)         # พลาสติก
P.flat("GlassBrown", L((70, 38, 18)), rough=0.08, dirt=0.25, noise=0.02)
P.flat("GlassGreen", L((48, 98, 60)), rough=0.08, dirt=0.25, noise=0.02)
P.flat("GlassClear", L((170, 186, 176)), rough=0.08, dirt=0.3, noise=0.02)
P.flat("OilGold", L((200, 150, 40)), rough=0.1, dirt=0.2, noise=0.02)
V.make_mat("Tin", L((170, 170, 166)), 0.35, metal=0.9, dirt=0.4, rust=0.05)
V.make_mat("CapRed", L((170, 36, 30)), 0.35, metal=0.6, dirt=0.3)
V.make_mat("CapGold", L((180, 146, 70)), 0.35, metal=0.9, dirt=0.3)
P.flat("Cardboard", L((168, 128, 84)), rough=0.85, dirt=0.5, noise=0.1)
P.flat("Tape", L((190, 160, 110)), rough=0.4, dirt=0.2)
V.make_mat("Sack", L((214, 206, 186)), 0.9, dirt=0.5, bump=0.5, bump_scale=160)
P.flat("Egg", L((206, 168, 128)), rough=0.6, dirt=0.25, noise=0.05)
P.flat("EggTray", L((150, 140, 120)), rough=0.9, dirt=0.4, noise=0.1)
P.flat("Candy", L((230, 120, 90)), rough=0.3, dirt=0.1, noise=0.25)

# ---------------------------------------------------------------- โครงไม้
for sx in (1, -1):
    for sy in (1, -1):
        put(FRAME, box((sx * PX, sy * PY, H / 2), (PS, PS, H)), "Post", bevel=0.02)
        put(FRAME, box((sx * PX, sy * PY, 0.03), (PS + 0.06, PS + 0.06, 0.06)), "PlankDark")   # รองขา
for i, z in enumerate(LEVELS):
    # คานรับชั้น หน้า/หลัง + ข้าง
    for sy in (1, -1):
        put(FRAME, box((0, sy * (PY - 0.02), z - 0.06), (W - 0.1, 0.1, 0.12)), "PlankDark", bevel=0.01)
    for sx in (1, -1):
        put(FRAME, box((sx * PX, 0, z - 0.06), (0.1, D - 0.2, 0.12)), "PlankDark", bevel=0.01)
    # แผ่นชั้น 3 แผ่น มีร่องห่าง แผ่นไม่เท่ากันนิดๆ
    ys = [-0.43, 0.0, 0.43]
    for k, y in enumerate(ys):
        dz = R.uniform(-0.008, 0.008)
        put(FRAME, box((R.uniform(-0.02, 0.02), y, z + PT / 2 + dz), (W - 0.04 + R.uniform(-0.04, 0.0), 0.4, PT)), "Plank" if (i + k) % 3 else "PlankDark", bevel=0.012)
    # ตะปูหัวชั้น
    for sx in (1, -1):
        for y in ys:
            put(FRAME, P.dome((sx * PX, y, z + PT), ZUP, 0.025, 0.012, n=6), "Nail")
    # ขอบกันของตกหน้าชั้น (ยกเว้นชั้นล่างสุด)
    if i > 0:
        put(FRAME, box((0, -D / 2 + 0.02, z + PT + 0.05), (W - 0.3, 0.04, 0.1)), "PlankDark", bevel=0.008)
put(FRAME, box((0, 0, H - 0.04), (W, D, 0.08)), "Plank", bevel=0.015)                          # แผ่นหลังคาชั้น
# คานขวางหลัง (กากบาท) + คานข้าง
dx, dz = 2 * PX, LEVELS[-1] - LEVELS[0]
ang = math.degrees(math.atan2(dz, dx))
for s in (1, -1):
    put(FRAME, P.box_rot((0, PY + 0.06, (LEVELS[0] + LEVELS[-1]) / 2), (math.hypot(dx, dz), 0.04, 0.16), "Y", s * ang), "PlankDark")
for sx in (1, -1):
    for z in ((LEVELS[1] + LEVELS[2]) / 2, (LEVELS[3] + LEVELS[4]) / 2):
        put(FRAME, box((sx * (PX + 0.12), 0, z), (0.04, D - 0.1, 0.16)), "PlankDark")
# กระดาษหนังสือพิมพ์ปูชั้น 2 และ 4 (ชายห้อยหน้าชั้นนิดๆ)
for lv in (1, 3):
    z = TOP[lv] + 0.003
    put(FRAME, box((-0.3, 0.02, z), (3.8, D - 0.3, 0.006)), "Paper")
    put(FRAME, P.box_rot((-0.3, -D / 2 + 0.13, z - 0.06), (3.8, 0.006, 0.13), "X", 8), "Paper")
    for k in range(6):                                         # แถวตัวหนังสือจางๆ (เส้นเทา)
        put(FRAME, box((-1.2 + (k % 2) * 1.4, -0.35 + k * 0.11, z + 0.002), (1.1, 0.03, 0.003)), "Ink")


# ---------------------------------------------------------------- ตัวช่วยวางของ
def at(g, pos, yaw=0.0):
    return P.xform(g, Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(yaw), 4, "Z"))


def bottle(obj, pos, h, r, glass, cap, label=None, neck=None, yaw=0.0):
    nk = neck or r * 0.36
    prof = [(0.0, 0.0), (0.0, r * 0.88), (0.02, r), (h * 0.55, r), (h * 0.64, r * 0.82), (h * 0.74, nk * 1.15), (h * 0.9, nk), (h * 0.9, 0.0)]
    put(obj, at(lathe((0, 0, 0), ZUP, prof, n=12), pos, yaw), glass)
    put(obj, at(P.cyl((0, 0, h * 0.9), ZUP, nk * 1.25, h * 0.1, n=10), pos, yaw), cap)
    if label:
        put(obj, at(P.ring_band((0, 0, 0), ZUP, r - 0.01, r + 0.008, h * 0.14, h * 0.46, n=12), pos, yaw), label)


def can(obj, pos, h, r, label, top="Tin", yaw=0.0, stripe=None):
    put(obj, at(lathe((0, 0, 0), ZUP, [(0, 0), (0, r * 0.94), (0.015, r), (h - 0.015, r), (h, r * 0.94), (h, 0)], n=12), pos, yaw), top)
    put(obj, at(P.ring_band((0, 0, 0), ZUP, r - 0.005, r + 0.006, h * 0.1, h * 0.9, n=12), pos, yaw), label)
    if stripe:
        put(obj, at(P.ring_band((0, 0, 0), ZUP, r, r + 0.01, h * 0.42, h * 0.58, n=12), pos, yaw), stripe)


def pack(obj, pos, s, mat, face=None, yaw=0.0, bev=0.012, band=None):
    """กล่อง/ห่อ (s = กว้าง, ลึก, สูง) วางก้นที่ pos · face = แผงหน้า · band = แถบคาด"""
    w, d, h = s
    put(obj, at(box((0, 0, h / 2), s), pos, yaw), mat, bevel=bev)
    if face:
        put(obj, at(box((0, -d / 2 - 0.004, h * 0.55), (w * 0.72, 0.008, h * 0.5)), pos, yaw), face)
        if h > 0.3:                                            # แถวตัวหนังสือจางๆ บนฉลาก (ไม่มีคำจริง)
            for k in range(3):
                put(obj, at(box((-w * 0.06 * k, -d / 2 - 0.009, h * (0.68 - k * 0.1)), (w * (0.5 - 0.1 * k), 0.004, h * 0.035)), pos, yaw), "Ink")
    if band:
        put(obj, at(box((0, 0, h * 0.2), (w + 0.006, d + 0.006, h * 0.12)), pos, yaw), band)


def noodle(obj, pos, mat, face, yaw=0.0):
    """บะหมี่ซอง: ห่อพอง + ปลายจีบสองข้าง"""
    w, d, h = 0.42, 0.32, 0.1
    put(obj, at(box((0, 0, h / 2), (w - 0.06, d, h)), pos, yaw), mat, bevel=0.03)
    for sx in (1, -1):
        put(obj, at(box((sx * (w / 2 - 0.02), 0, h / 2), (0.04, d, 0.02)), pos, yaw), mat)
    put(obj, at(box((0, -d / 2 - 0.005, h / 2), (0.2, 0.006, 0.06)), pos, yaw), face)


# ---------------------------------------------------------------- ชั้น 1 (ล่างสุด): กระสอบข้าว / ลังน้ำอัดลม / แกลลอนน้ำมันเครื่อง 2T
z = TOP[0]
SK = (-2.05, 0.02, z)
put(LOW, at(box((0, 0, 0.5), (1.0, 0.8, 1.0)), SK, 6), "Sack", subdiv=2)
put(LOW, at(box((0, -0.335, 0.45), (0.5, 0.012, 0.3)), SK, 6), "LabGreen")                    # ลายพิมพ์หน้ากระสอบ
put(LOW, at(box((0, -0.342, 0.45), (0.3, 0.012, 0.1)), SK, 6), "LabRed")
put(LOW, at(box((0, -0.33, 0.24), (0.56, 0.012, 0.04)), SK, 6), "LabRed")
put(LOW, at(lathe((0, 0, 0.78), ZUP, [(0, 0.16), (0.05, 0.08), (0.12, 0.06), (0.17, 0.12), (0.19, 0.0)], n=8), SK, 0), "Sack")   # ปากกระสอบมัด
# ลังพลาสติกแดง + ขวดแก้ว 3x4
CR = (-0.55, 0.0, z)
cw, cd, ch = 1.25, 0.9, 0.5
for (c, s) in (((0, -cd / 2 + 0.03, ch / 2), (cw, 0.06, ch)), ((0, cd / 2 - 0.03, ch / 2), (cw, 0.06, ch)),
               ((-cw / 2 + 0.03, 0, ch / 2), (0.06, cd, ch)), ((cw / 2 - 0.03, 0, ch / 2), (0.06, cd, ch)), ((0, 0, 0.03), (cw, cd, 0.06))):
    put(LOW, at(box(c, s), CR), "PlaRed", bevel=0.01)
for (c, s) in (((-cw / 2 + 0.03, 0, ch - 0.12), (0.07, 0.3, 0.1)), ((cw / 2 - 0.03, 0, ch - 0.12), (0.07, 0.3, 0.1))):
    put(LOW, at(box(c, s), CR), "Ink")                                                          # ช่องหูหิ้ว
for ix in range(4):
    for iy in range(3):
        if (ix, iy) == (3, 0):
            continue
        bottle(LOW, (CR[0] - 0.45 + ix * 0.3, CR[1] - 0.27 + iy * 0.27, z + 0.06), 0.82, 0.11, "GlassGreen" if (ix + iy) % 3 else "GlassBrown", "CapRed")
# แกลลอนน้ำมันเครื่อง (ขวดแบนมีหูจับ)
for k, (x, col) in enumerate(((0.75, "Blue"), (1.3, "Blue"), (1.85, "Red"), (2.4, "Blue"))):
    p = (x + R.uniform(-0.03, 0.03), R.uniform(-0.05, 0.08), z)
    yaw = R.uniform(-6, 6)
    pack(LOW, p, (0.46, 0.26, 0.7), "Pla" + col, face="LabYellow", yaw=yaw, bev=0.04)
    put(LOW, at(P.cyl((0.12, 0, 0.7), ZUP, 0.05, 0.08, n=8), p, yaw), "PlaWhite")
    put(LOW, at(box((-0.1, 0, 0.76), (0.18, 0.07, 0.12)), p, yaw), "Pla" + col, bevel=0.02)

# ---------------------------------------------------------------- ชั้น 2: น้ำมันพืช / น้ำปลา / แผงไข่
z = TOP[1]
for k in range(6):
    bottle(LOW, (-2.45 + (k % 3) * 0.3, -0.18 + (k // 3) * 0.3, z), 0.95, 0.12, "OilGold", "PlaRed" if k % 2 else "PlaYellow", label="LabRed", neck=0.05, yaw=R.uniform(0, 360))
for k in range(7):
    bottle(LOW, (-1.35 + k * 0.24, -0.25 + (k % 2) * 0.22, z), 1.0, 0.1, "GlassBrown", "CapRed", label="LabCream", neck=0.035, yaw=R.uniform(0, 360))
for k in range(4):
    bottle(LOW, (-1.2 + k * 0.32, 0.28, z), 0.75, 0.09, "GlassClear", "CapGold", label="LabTeal", neck=0.03)
# แผงไข่ 5x6
EG = (1.15, -0.05, z)
put(LOW, at(box((0, 0, 0.04), (1.05, 0.9, 0.08)), EG, 3), "EggTray", bevel=0.01)
for ix in range(6):
    for iy in range(5):
        if R.random() < 0.12:
            continue
        put(LOW, at(lathe((0, 0, 0), ZUP, [(0.0, 0.0), (0.0, 0.045), (0.025, 0.07), (0.07, 0.078), (0.12, 0.065), (0.16, 0.035), (0.175, 0.0)], n=8), (EG[0] - 0.42 + ix * 0.17, EG[1] - 0.34 + iy * 0.17, z + 0.05), 0), "Egg")
pack(LOW, (2.25, 0.0, z), (0.7, 0.7, 0.6), "Cardboard", band="Tape", yaw=-4, bev=0.01)
pack(LOW, (2.25, 0.0, z + 0.6), (0.55, 0.55, 0.34), "Cardboard", band="Tape", yaw=9, bev=0.01)

# ---------------------------------------------------------------- ชั้น 3: บะหมี่ซอง / ปลากระป๋อง / ผงซักฟอก
z = TOP[2]
noo = [("LabYellow", "LabRed"), ("LabOrange", "LabWhite"), ("LabGreen", "LabYellow"), ("LabRed", "LabYellow")]
for col in range(4):
    m, f = noo[col]
    for row in range(2):
        for k in range(5 - row - (col % 2)):
            noodle(UPP, (-2.45 + col * 0.46, -0.2 + row * 0.38, z + k * 0.1), m, f, yaw=R.uniform(-5, 5))
# ปลากระป๋องเรียงพีระมิด
for layer, n in enumerate((5, 4, 3)):
    for k in range(n):
        x = -0.35 + k * 0.24 + layer * 0.12
        can(UPP, (x, -0.22, z + layer * 0.17), 0.17, 0.11, "LabRed" if k % 2 else "LabYellow", stripe="LabWhite" if layer == 0 else None)
for k in range(6):
    can(UPP, (-0.3 + k * 0.22, 0.25, z), 0.32, 0.1, "LabGreen" if k % 3 else "LabOrange")
for k in range(3):
    pack(UPP, (1.35 + k * 0.48, -0.05 + R.uniform(-0.04, 0.04), z), (0.42, 0.24, 0.6), "LabBlue", face="LabWhite", yaw=R.uniform(-4, 4), band="LabRed")
pack(UPP, (2.45, 0.1, z), (0.36, 0.5, 0.36), "LabWhite", face="LabTeal", yaw=-8)

# ---------------------------------------------------------------- ชั้น 4: โหลขนม / ไม้ขีด / ทิชชู่ / ยากันยุง
z = TOP[3]
for k, (lid, body) in enumerate((("PlaRed", "Candy"), ("PlaGreen", "LabYellow"), ("PlaRed", "LabPink"), ("PlaBlue", "LabOrange"))):
    p = (-2.4 + k * 0.5, 0.0, z)
    put(UPP, at(lathe((0, 0, 0), ZUP, [(0, 0), (0, 0.19), (0.02, 0.21), (0.44, 0.21), (0.44, 0.0)], n=14), p), body)       # ขนมเต็มโหล
    put(UPP, at(lathe((0, 0, 0), ZUP, [(0.44, 0.0), (0.44, 0.212), (0.5, 0.212), (0.55, 0.18), (0.6, 0.16), (0.6, 0)], n=14), p), "GlassClear")   # ไหล่โหลว่าง
    for zz in (0.02, 0.4):
        put(UPP, at(P.ring_band((0, 0, 0), ZUP, 0.205, 0.22, zz, zz + 0.025, n=14), p), "GlassClear")
    put(UPP, at(P.cyl((0, 0, 0.58), ZUP, 0.19, 0.1, n=14), p), lid)
for k in range(10):                                                                          # ไม้ขีดตั้งเป็นตั้ง
    pack(UPP, (-0.35 + (k // 5) * 0.2, -0.25, z + (k % 5) * 0.06), (0.16, 0.1, 0.06), "LabYellow" if k % 2 else "LabRed", bev=0.004)
for ix in range(3):                                                                          # ทิชชู่ม้วน 3x2 ในห่อ
    for iy in range(2):
        for iz in range(2):
            put(UPP, at(P.cyl((0, 0, 0), ZUP, 0.13, 0.27, n=12), (0.25 + ix * 0.27, -0.12 + iy * 0.27, z + iz * 0.27)), "LabWhite")
put(UPP, at(box((0, 0, 0.55), (0.86, 0.58, 0.04)), (0.52, 0.01, z)), "PlaPink")
for k in range(5):                                                                           # กล่องยากันยุง
    pack(UPP, (1.6 + (k % 2) * 0.05, 0.0, z + k * 0.09), (0.55, 0.42, 0.09), "LabGreen", face="LabRed" if k == 4 else None, yaw=R.uniform(-8, 8), bev=0.008)
for k in range(4):
    bottle(UPP, (2.3 + (k % 2) * 0.22, -0.2 + (k // 2) * 0.3, z), 0.6, 0.08, "PlaWhite", "PlaBlue", label="LabBlue", neck=0.04)

# ---------------------------------------------------------------- ชั้น 5 (บนสุด): ลังกระดาษ / ตะกร้า / ขวดน้ำอัดลมเปล่า
z = TOP[4]
pack(UPP, (-2.2, 0.0, z), (1.1, 0.9, 0.6), "Cardboard", band="Tape", yaw=3, bev=0.01)
pack(UPP, (-1.0, 0.05, z), (0.8, 0.8, 0.45), "Cardboard", band="Tape", yaw=-6, bev=0.01)
for k in range(5):
    bottle(UPP, (0.1 + k * 0.26, -0.15 + (k % 2) * 0.2, z), 0.8, 0.1, "GlassGreen", "CapGold", label="LabWhite", neck=0.035)
BK = (1.95, 0.0, z)                                                                          # ตะกร้าสาน
put(UPP, at(lathe((0, 0, 0), ZUP, [(0, 0), (0, 0.32), (0.04, 0.36), (0.4, 0.44), (0.42, 0.46), (0.42, 0.41), (0.05, 0.31), (0.05, 0.0)], n=16), BK), "PlankDark")
for k in range(3):
    put(UPP, at(P.ring_band((0, 0, 0), ZUP, 0.36 + k * 0.03, 0.38 + k * 0.03 + 0.012, 0.08 + k * 0.12, 0.11 + k * 0.12, n=16), BK), "Plank")

# ---------------------------------------------------------------- ขนมแผงห้อยหน้าชั้น 2 สาย (เชือก + ซองขนม)
for sx, cols in ((-1, ("Orange", "Yellow", "Red", "Orange", "Green", "Yellow")), (1, ("Purple", "Teal", "Pink", "Purple", "Teal", "Pink"))):
    x = sx * (PX - 0.4)
    yb = -D / 2 - 0.1
    put(UPP, P.cyl((x, yb, 4.75), ZUP, 0.012, H - 0.1 - 4.75, n=4), "Ink")
    put(UPP, box((x, -D / 2 - 0.05, H - 0.1), (0.05, 0.12, 0.04)), "Nail")
    for k, c in enumerate(cols):
        zc = H - 0.42 - k * 0.36
        put(UPP, P.box_rot((x, yb, zc), (0.3, 0.05, 0.3), "X", R.uniform(-6, 6)), "Pla" + c, bevel=0.015)
        put(UPP, P.box_rot((x, yb - 0.028, zc - 0.02), (0.18, 0.006, 0.12), "X", 0), "LabWhite")
        put(UPP, box((x, yb, zc + 0.16), (0.3, 0.04, 0.03)), "Pla" + c)


# ---------------------------------------------------------------- object + bake + export
ORDER = [FRAME, LOW, UPP]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
if not NO_BAKE:
    P.bake_all(OBJ, {FRAME: "ShackShelfV2_Frame", LOW: "ShackShelfV2_GoodsLower", UPP: "ShackShelfV2_GoodsUpper"}, {FRAME: 1024, LOW: 1024, UPP: 1024})
P.export_fbx(OBJ, os.path.join(UP, "ShackShelfV2.fbx"), FRAME)


def preview():
    cam, sun, world = P.stage()
    # ผนังสังกะสีหลังชั้นจำลอง (ให้เห็นบรรยากาศ)
    wm = bpy.data.meshes.new("Wall")
    s = V.S
    wm.from_pydata([(-6 * s, 0.9 * s, 0), (6 * s, 0.9 * s, 0), (6 * s, 0.9 * s, 9 * s), (-6 * s, 0.9 * s, 9 * s)], [], [(0, 1, 2, 3)])
    wob = bpy.data.objects.new("Wall", wm)
    wmat = bpy.data.materials.new("WallM")
    wmat.use_nodes = True
    wmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.18, 0.16, 0.14, 1)
    wm.materials.append(wmat)
    bpy.context.scene.collection.objects.link(wob)
    P.add_person(ROOT, (4.4, -1.4, 0.0), yaw_deg=-30)
    P.shot(cam, os.path.join(OUT, "ShackShelfV2.png"), (0, 0, 3.4), (-0.5, -1.3, 0.25), 17.0)
    P.shot(cam, os.path.join(OUT, "ShackShelfV2_front.png"), (0, 0, 3.5), (0.0, -1.0, 0.05), 15.0)
    P.shot(cam, os.path.join(OUT, "ShackShelfV2_low.png"), (0, 0, 1.6), (0.25, -1.0, 0.25), 6.5)
    P.shot(cam, os.path.join(OUT, "ShackShelfV2_mid.png"), (-0.6, 0, 4.2), (-0.3, -1.0, 0.1), 6.0)
    P.night(world, sun, (1.0, -5.0, 8.5), energy=80)
    P.shot(cam, os.path.join(OUT, "ShackShelfV2_night.png"), (0, 0, 3.4), (-0.4, -1.3, 0.2), 16.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "shack_shelf_v2.blend"))
P.log("done")
