# ShackInterior v2 — ของในเพิง: โต๊ะขายของ / ถังน้ำแข็ง / ลังน้ำอัดลม / กระป๋องใส่เงิน ปั้นใหม่ คุมโทนเก่า หม่น มอมแมมแบบเกม (ผู้ใช้ 2026-11-08)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/shack_interior_v2.py
# ผลลัพธ์: assets/models/ShackInteriorV2/upload/ · ชั้นนอก: ภาพตัวอย่าง + .blend
# แต่ละชุด origin = พื้นใต้กึ่งกลางชิ้นหลักของชุดนั้น (ซ้อนกันที่ 0,0,0 ในไฟล์) · ขนาดชิ้นหลักเท่าของเดิม (ShackInteriorProps.fbx):
#   CounterTable 14.03 x 3.82 (สูง) x 3.61 (+ CounterTable_Clutter ของใต้โต๊ะ ไม่ชน) · CoreLoop/Cutscene อ่าน Size ของโต๊ะ: ผิวบนโต๊ะ = ความสูงเดิม
#   IceBox 2.82 x 1.70 x 1.62 + IceBox_Lid (ฝาวางพิงหลังถังเหมือนเดิม) · SodaCrate 2.01 x 1.41 x 1.41 · MoneyTin Ø1.0 สูง 0.42 + MoneyTin_Lid
#   (MapBuilder.SwapShackInteriorV2 วางชิ้นหลักใหม่ที่ก้น/มุมของชิ้นเดิม ชิ้นรองตามระยะในไฟล์)
# ไม่แตะ: CutoutSwitch / OldMirror / OwnerPhoto / WallCalendar (ผูกกับระบบไฟ + ผี)
import bpy, math, os, sys, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "ShackInteriorV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, lathe, put, L = V.G, V.box, V.lathe_axis, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)
R = random.Random(81108)

TABLE, CLUT, ICE, LID, CRATE, TIN, TLID = "CounterTable", "CounterTable_Clutter", "IceBox", "IceBox_Lid", "SodaCrate", "MoneyTin", "MoneyTin_Lid"

# ---------------------------------------------------------------- วัสดุ (โทนเกม: ไม้ซีดเทา สีพลาสติกหม่น ฝุ่นจับตามซอก)
P.wood("TopWood", L((112, 90, 66)), rough=0.82, dirt=0.6, grain_axis="X", grain=1.1, gray=0.4)
P.wood("LegWood", L((96, 76, 56)), rough=0.85, dirt=0.65, grain_axis="Z", grain=1.0, gray=0.45)
P.wood("ShelfWood", L((88, 70, 52)), rough=0.85, dirt=0.65, grain_axis="X", grain=1.2, gray=0.45)
V.make_mat("Nail", L((44, 40, 36)), 0.6, metal=0.5, dirt=0.2, rust=0.4)
P.flat("Stain", L((62, 48, 34)), rough=0.88, dirt=0.0, noise=0.15)
P.flat("Newspaper", L((136, 130, 114)), rough=0.85, dirt=0.6, noise=0.14)
P.flat("Ink", L((40, 36, 33)), rough=0.7, dirt=0.0)
P.flat("Twine", L((150, 124, 84)), rough=0.9, dirt=0.3)
V.make_mat("BasinBlue", L((50, 74, 92)), 0.55, dirt=0.75, wear=0.3)
V.make_mat("JugBlue", L((56, 74, 100)), 0.55, dirt=0.75, wear=0.3)
P.flat("JugCap", L((150, 140, 110)), rough=0.5, dirt=0.4)
P.flat("Cardboard", L((128, 98, 66)), rough=0.85, dirt=0.6, noise=0.12)
P.flat("Rope", L((140, 118, 80)), rough=0.9, dirt=0.4)
V.make_mat("CoolerRed", L((118, 42, 36)), 0.6, dirt=0.75, wear=0.45)
V.make_mat("CoolerWhite", L((168, 162, 146)), 0.6, dirt=0.8, wear=0.3)
V.make_mat("CoolerInner", L((150, 146, 134)), 0.55, dirt=0.7)
P.flat("IceWater", L((58, 70, 72)), rough=0.08, dirt=0.0, noise=0.05)
P.flat("Ice", L((176, 190, 192)), rough=0.15, dirt=0.15, noise=0.05)
V.make_mat("CrateRed", L((112, 40, 34)), 0.6, dirt=0.8, wear=0.45)
V.make_mat("CrateYellow", L((128, 106, 52)), 0.65, dirt=0.75, wear=0.4)
P.flat("GlassGreen", L((44, 82, 52)), rough=0.08, dirt=0.4, noise=0.02)
P.flat("GlassBrown", L((62, 36, 18)), rough=0.08, dirt=0.4, noise=0.02)
V.make_mat("CapRust", L((130, 60, 40)), 0.5, metal=0.6, dirt=0.4, rust=0.5)
V.make_mat("TinBlue", L((54, 78, 104)), 0.5, metal=0.6, dirt=0.6, wear=0.6, rust=0.3)
V.make_mat("TinBand", L((138, 120, 86)), 0.5, metal=0.4, dirt=0.65, wear=0.5, rust=0.2)
P.flat("TinRed", L((108, 40, 34)), rough=0.5, dirt=0.5)
P.flat("Banknote", L((112, 120, 92)), rough=0.8, dirt=0.4)
P.flat("BanknoteRed", L((150, 86, 82)), rough=0.8, dirt=0.4)


def at(g, pos, yaw=0.0, tilt=None):
    m = Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    if tilt:
        m = m @ Matrix.Rotation(math.radians(tilt[1]), 4, tilt[0])
    return P.xform(g, m)


# ================================================================ โต๊ะขายของ 14.0 x 3.6 สูง 3.82
TW, TD, TH = 14.0, 3.6, 3.82
TOPT = 0.2
# ไม้หน้าโต๊ะ 3 แผ่น (กว้างไม่เท่ากัน แผ่นกลางยุบนิดๆ) ขอบมนสึก
ys = [(-1.2, 1.18), (0.0, 1.16), (1.2, 1.2)]
for k, (y, w) in enumerate(ys):
    put(TABLE, box((R.uniform(-0.04, 0.04), y, TH - TOPT / 2 - (0.01 if k == 1 else 0)), (TW - 0.05 * k, w, TOPT)), "TopWood", bevel=0.03)
# คิ้วรอบใต้หน้าโต๊ะ
for sy in (1, -1):
    put(TABLE, box((0, sy * (TD / 2 - 0.25), TH - TOPT - 0.22), (TW - 0.7, 0.1, 0.44)), "ShelfWood", bevel=0.015)
for sx in (1, -1):
    put(TABLE, box((sx * (TW / 2 - 0.35), 0, TH - TOPT - 0.22), (0.1, TD - 0.6, 0.44)), "ShelfWood", bevel=0.015)
# ขา 8 ต้น (4 คู่) + ไม้รองชั้นล่าง
LX = [-(TW / 2 - 0.35), -2.3, 2.3, TW / 2 - 0.35]
for x in LX:
    for sy in (1, -1):
        put(TABLE, box((x, sy * (TD / 2 - 0.25), (TH - TOPT) / 2), (0.3, 0.3, TH - TOPT)), "LegWood", bevel=0.025)
        put(TABLE, P.dome((x, sy * (TD / 2 - 0.25) - sy * 0.15, TH - TOPT - 0.22), (0, -sy, 0), 0.03, 0.012, n=6), "Nail")
    put(TABLE, box((x, 0, 0.62), (0.16, TD - 0.4, 0.16)), "ShelfWood")
for sy in (1, -1):
    put(TABLE, box((0, sy * (TD / 2 - 0.25), 0.62), (TW - 0.8, 0.14, 0.16)), "ShelfWood")
# ชั้นล่าง: ไม้ระแนง 5 แผ่น
for k in range(5):
    y = -1.25 + k * 0.62
    put(TABLE, box((0, y, 0.75), (TW - 0.9, 0.5, 0.08)), "ShelfWood", bevel=0.01)
# คราบแก้ว/รอยไหม้บนหน้าโต๊ะ (วงๆ)
for (x, y, r) in ((-4.2, -0.6, 0.24), (1.6, 0.9, 0.3), (5.2, -0.8, 0.22)):            # คราบจางๆ บนโต๊ะ (ไม่ใช่วงเส้นดำ)
    put(TABLE, P.extrude_z([(x + math.cos(a) * r * (1 + 0.25 * math.sin(2 * a + x)), y + math.sin(a) * r) for a in [2 * math.pi * i / 14 for i in range(14)]], TH + 0.001, TH + 0.003), "Stain")
put(TABLE, P.extrude_z([(3.0 + math.cos(a) * 0.7 * (1 + 0.2 * math.sin(3 * a)), -0.3 + math.sin(a) * 0.45) for a in [2 * math.pi * i / 16 for i in range(16)]], TH + 0.001, TH + 0.004), "Stain")

# ---------------------------------------------------------------- ของใต้โต๊ะ (ไม่ชน)
Z1 = 0.79
for k in range(3):                                     # ตั้งหนังสือพิมพ์เก่ามัดเชือก
    put(CLUT, at(box((0, 0, 0.09), (1.4, 1.0, 0.18)), (-5.4, -0.2, Z1 + k * 0.18), R.uniform(-8, 8)), "Newspaper", bevel=0.01)
put(CLUT, at(box((0, 0, 0.27), (0.06, 1.04, 0.56)), (-5.4, -0.2, Z1)), "Twine")
put(CLUT, at(box((0, 0, 0.27), (1.44, 0.06, 0.56)), (-5.4, -0.2, Z1)), "Twine")
for k in range(4):
    put(CLUT, at(box((0, -0.52, 0.09 + k * 0.12), (1.1, 0.005, 0.02)), (-5.4, -0.2, Z1)), "Ink")
put(CLUT, at(lathe((0, 0, 0), ZUP, [(0, 0), (0, 0.62), (0.02, 0.68), (0.5, 0.88), (0.54, 0.92), (0.54, 0.86), (0.06, 0.62), (0.06, 0.0)], n=28), (-3.0, 0.1, Z1)), "BasinBlue")   # กะละมัง
JG = (-0.6, 0.0, Z1)                                   # แกลลอนน้ำพลาสติก
put(CLUT, at(box((0, 0, 0.6), (0.9, 0.7, 1.2)), JG, 12), "JugBlue", bevel=0.12)
put(CLUT, at(P.cyl((0.22, 0, 1.2), ZUP, 0.13, 0.14, n=10), JG, 12), "JugCap")
put(CLUT, at(V.tube([(-0.25, 0, 1.18), (-0.15, 0, 1.36), (0.05, 0, 1.36), (0.1, 0, 1.2)], 0.05, n=6), JG, 12), "JugBlue")
for k in range(2):                                     # ลังกระดาษ
    put(CLUT, at(box((0, 0, 0.45), (1.5 - k * 0.3, 1.3 - k * 0.2, 0.9 - k * 0.3)), (2.0, -0.1, Z1 + k * 0.9), R.uniform(-6, 6)), "Cardboard", bevel=0.02)
coil = []
for k in range(4 * 24 + 1):                            # เชือกขดวางนอน
    a = 2 * math.pi * k / 24
    r = 0.45 - 0.004 * k
    coil.append((4.6 + math.cos(a) * r, 0.2 + math.sin(a) * r, Z1 + 0.06 + 0.035 * (k // 24)))
put(CLUT, V.tube(coil, 0.05, n=6, cap=True), "Rope")
for k in range(5):                                     # ขวดเปล่านอนกลิ้ง
    g = lathe((0, 0, 0), ZUP, [(0, 0), (0, 0.11), (0.5, 0.11), (0.62, 0.05), (0.8, 0.04), (0.8, 0)], n=10)
    put(CLUT, at(g, (5.4 + k * 0.24, -0.9 + (k % 2) * 0.1, Z1 + 0.11), R.uniform(-20, 20), ("Y", 90)), "GlassGreen" if k % 2 else "GlassBrown")

# ================================================================ ถังน้ำแข็ง 2.82 x 1.62 สูง 1.70 (ฝาเปิดวางพิงหลัง)
IW, ID, IH = 2.8, 1.6, 1.62
outer = [V.ring_z(0, 0, z, IW / 2 * k, ID / 2 * k, n=32, p=5) for z, k in ((0.0, 0.96), (0.05, 1.0), (IH - 0.05, 1.0))]
rim_ = [V.ring_z(0, 0, IH, IW / 2 - 0.02, ID / 2 - 0.02, n=32, p=5), V.ring_z(0, 0, IH, IW / 2 - 0.13, ID / 2 - 0.13, n=32, p=5)]
inner = [V.ring_z(0, 0, IH - 0.02, IW / 2 - 0.14, ID / 2 - 0.14, n=32, p=5), V.ring_z(0, 0, 0.2, IW / 2 - 0.18, ID / 2 - 0.18, n=32, p=5)]
put(ICE, V.loft(outer + rim_[:1], cap=False), "CoolerRed")
put(ICE, V.loft(rim_, cap=False), "CoolerWhite")
put(ICE, V.loft(inner, cap=False), "CoolerInner")
put(ICE, P.extrude_z(V.ring_z(0, 0, 0, IW / 2 - 0.18, ID / 2 - 0.18, n=32, p=5)[::1] and [(p[0], p[1]) for p in V.ring_z(0, 0, 0, IW / 2 - 0.16, ID / 2 - 0.16, n=32, p=5)], 1.18, 1.2), "IceWater")
put(ICE, box((0, 0, 0.025), (IW * 0.96, ID * 0.96, 0.05)), "CoolerRed")
# แถบขาวคาดล่าง + มือจับข้าง + จุกถ่ายน้ำ
put(ICE, V.loft([V.ring_z(0, 0, z, IW / 2 + 0.008, ID / 2 + 0.008, n=32, p=5) for z in (0.12, 0.26)], cap=False), "CoolerWhite")
for sx in (1, -1):
    put(ICE, box((sx * (IW / 2 + 0.05), 0, IH - 0.42), (0.12, 0.7, 0.16)), "CoolerWhite", bevel=0.04)
    put(ICE, box((sx * (IW / 2 + 0.02), 0, IH - 0.32), (0.06, 0.5, 0.05)), "CoolerInner")
put(ICE, P.cyl((0.9, -ID / 2, 0.22), (0, -1, 0), 0.07, 0.08, n=10), "CoolerWhite")
# น้ำแข็งก้อน + คอขวดโผล่ + กระป๋องลอย
for k in range(14):
    x, y = R.uniform(-1.1, 1.1), R.uniform(-0.55, 0.55)
    put(ICE, at(box((0, 0, 0), (0.22, 0.2, 0.16)), (x, y, 1.2), R.uniform(0, 90), ("X", R.uniform(-20, 20))), "Ice", bevel=0.03)
for k, (x, y) in enumerate(((-0.8, -0.2), (-0.45, 0.3), (0.1, -0.25), (0.5, 0.25), (0.85, -0.15))):
    put(ICE, at(lathe((0, 0, 0), ZUP, [(0, 0.11), (0.12, 0.11), (0.25, 0.05), (0.45, 0.04), (0.45, 0)], n=10), (x, y, 1.05), 0, ("X", R.uniform(-12, 12))), "GlassGreen" if k % 2 else "GlassBrown")
    put(ICE, at(P.cyl((0, 0, 0.45), ZUP, 0.05, 0.04, n=8), (x, y, 1.05), 0, None), "CapRust")
for (x, y) in ((-0.1, 0.35), (0.3, -0.35)):
    put(ICE, at(P.cyl((0, 0, 0), ZUP, 0.1, 0.26, n=10), (x, y, 1.12), R.uniform(0, 90), ("X", 70)), "TinRed")
# ฝาถัง: วางพิงหลังถัง เอียง 14° (เหมือนของเดิม)
LG = G()
LG.merge(V.loft([V.ring_z(0, 0, z, IW / 2 - 0.05, ID / 2 - 0.05, n=32, p=5) for z in (0.0, 0.18)]))
LG.merge(V.loft([V.ring_z(0, 0, z, IW / 2 - 0.2, ID / 2 - 0.2, n=32, p=5) for z in (-0.06, 0.0)]))
LG.merge(box((0, 0, 0.21), (0.9, 0.18, 0.06)))
m = Matrix.Translation(Vector((0, ID / 2 + 0.12, 0.0))) @ Matrix.Rotation(math.radians(-14), 4, "X") @ Matrix.Translation(Vector((0, 0, ID / 2 - 0.05))) @ Matrix.Rotation(math.radians(-90), 4, "X")
put(LID, P.xform(LG, m), "CoolerWhite")
put(LID, P.xform(V.loft([V.ring_z(0, 0, z, IW / 2 - 0.04, ID / 2 - 0.04, n=32, p=5) for z in (0.07, 0.12)], cap=False), m), "CoolerRed")

# ================================================================ ลังน้ำอัดลม 2.0 x 1.4 สูง 1.41
CW, CD, CH = 2.0, 1.4, 0.82
for (c, s) in (((0, -CD / 2 + 0.04, CH / 2), (CW, 0.08, CH)), ((0, CD / 2 - 0.04, CH / 2), (CW, 0.08, CH)), ((-CW / 2 + 0.04, 0, CH / 2), (0.08, CD, CH)),
               ((CW / 2 - 0.04, 0, CH / 2), (0.08, CD, CH)), ((0, 0, 0.04), (CW, CD, 0.08)), ((0, 0, CH * 0.55), (0.05, CD - 0.1, CH * 0.6)),
               ((-0.5, 0, CH * 0.55), (0.05, CD - 0.1, CH * 0.6)), ((0.5, 0, CH * 0.55), (0.05, CD - 0.1, CH * 0.6)), ((0, 0, CH * 0.55), (CW - 0.1, 0.05, CH * 0.6))):
    put(CRATE, box(c, s), "CrateRed", bevel=0.015)
for sx in (1, -1):
    put(CRATE, box((sx * (CW / 2 - 0.02), 0, CH - 0.2), (0.04, 0.5, 0.14)), "Ink")                   # ช่องหูหิ้ว
for sy in (1, -1):
    put(CRATE, box((0, sy * (CD / 2 + 0.003), CH * 0.5), (CW * 0.7, 0.006, 0.18)), "CrateYellow")   # แถบป้ายซีด
for ix in range(4):
    for iy in range(2):
        if (ix, iy) in ((2, 1),):
            continue
        x, y = -0.75 + ix * 0.5, -0.33 + iy * 0.66
        g = lathe((0, 0, 0), ZUP, [(0, 0), (0, 0.16), (0.02, 0.18), (0.75, 0.18), (0.95, 0.1), (1.25, 0.065), (1.25, 0)], n=12)
        put(CRATE, at(g, (x, y, 0.08), 0, ("X", R.uniform(-3, 3))), "GlassGreen" if (ix + iy) % 3 else "GlassBrown")
        if (ix + iy) % 4 != 1:
            put(CRATE, at(P.cyl((0, 0, 1.25), ZUP, 0.075, 0.06, n=10), (x, y, 0.08)), "CapRust")

# ================================================================ กระป๋องใส่เงิน (ปี๊บขนมกลม Ø1.0 สูง 0.42) + ฝา
TR, THh = 0.5, 0.42
dent = [1.0 + 0.015 * math.sin(3 * k) for k in range(28)]
tin = G()
rings = []
for z in (0.0, 0.03, THh - 0.03, THh):
    rings.append([(math.cos(2 * math.pi * k / 28) * TR * dent[k] * (0.97 if z in (0.0, THh) else 1.0), math.sin(2 * math.pi * k / 28) * TR * dent[k] * (0.97 if z in (0.0, THh) else 1.0), z) for k in range(28)])
put(TIN, V.loft(rings), "TinBlue")
put(TIN, P.ring_band((0, 0, 0), ZUP, TR * 0.99, TR + 0.008, 0.12, 0.3, n=28), "TinBand")
for k in range(14):                                    # ลายดอกเล็กๆ บนแถบ (สีซีด)
    a = 2 * math.pi * k / 14
    put(TIN, at(P.cyl((0, 0, 0), (1, 0, 0), 0.035, 0.008, n=8), (math.cos(a) * (TR + 0.006), math.sin(a) * (TR + 0.006), 0.21 + 0.04 * (k % 2)), math.degrees(a)), "TinRed")
LIDZ = THh - 0.02
put(TLID, lathe((0, 0, 0), ZUP, [(LIDZ, 0.0), (LIDZ, TR + 0.03), (LIDZ + 0.11, TR + 0.03), (LIDZ + 0.13, TR + 0.0), (LIDZ + 0.135, 0.0)], n=28), "TinBlue")
put(TLID, P.ring_band((0, 0, 0), ZUP, 0.24, 0.3, LIDZ + 0.134, LIDZ + 0.138, n=24), "TinBand")
for (a, col) in ((0.4, "Banknote"), (1.1, "BanknoteRed")):          # แบงก์โผล่ใต้ฝา
    put(TIN, at(box((0, 0, 0), (0.3, 0.12, 0.006)), (math.cos(a) * 0.5, math.sin(a) * 0.5, THh - 0.01), math.degrees(a), ("Y", -12)), col)

# ---------------------------------------------------------------- object + bake + export
ORDER = [TABLE, CLUT, ICE, LID, CRATE, TIN, TLID]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
if not NO_BAKE:
    P.bake_all(OBJ, {TABLE: "ShackInteriorV2_Table", CLUT: "ShackInteriorV2_Clutter", ICE: "ShackInteriorV2_IceBox", LID: "ShackInteriorV2_IceLid",
                     CRATE: "ShackInteriorV2_Crate", TIN: "ShackInteriorV2_Tin", TLID: "ShackInteriorV2_TinLid"},
               {TABLE: 1024, CLUT: 1024, ICE: 1024, LID: 512, CRATE: 512, TIN: 256, TLID: 256})
P.export_fbx(OBJ, os.path.join(UP, "ShackInteriorV2.fbx"), TABLE)


def preview():
    S = V.S
    for n, off in ((ICE, (9.5, 2.5, 0)), (LID, (9.5, 2.5, 0)), (CRATE, (-9.5, 2.5, 0)), (TIN, (3.0, -0.6, 3.82)), (TLID, (3.0, -0.6, 3.82))):
        OBJ[n].location = Vector(off) * S
    cam, sun, world = P.stage(ground=(0.2, 0.17, 0.14))
    P.add_person(ROOT, (5.5, -3.2, 0.0), yaw_deg=-10)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2.png"), (0, 1.0, 2.0), (-0.25, -1.2, 0.5), 30.0)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2_table.png"), (0, 0, 1.8), (0.15, -1.0, 0.25), 18.0)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2_icebox.png"), (9.5, 2.5, 1.0), (-0.4, -1.0, 0.8), 6.5)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2_crate_tin.png"), (-9.5, 2.5, 1.0), (0.3, -1.0, 0.7), 5.5)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2_tin.png"), (3.0, -0.6, 4.1), (0.2, -1.0, 0.8), 2.6)
    P.night(world, sun, (0.0, -3.0, 9.0), energy=70)
    P.shot(cam, os.path.join(OUT, "ShackInteriorV2_night.png"), (0, 1.0, 2.0), (-0.25, -1.2, 0.5), 30.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "shack_interior_v2.blend"))
P.log("done")
