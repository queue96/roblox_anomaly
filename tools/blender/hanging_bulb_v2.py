# HangingBulbV2 — หลอดไส้แบบเก่าห้อยสายไฟในเพิง + แมลงเม่าตัวจิ๋ว (ผู้ใช้ 2026-11-16 ส่งรูปหลอดไส้ขดวงแก้วอำพัน)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/hanging_bulb_v2.py
# ผลลัพธ์: assets/models/HangingBulbV2/upload/HangingBulbV2.fbx (+ texture ขั้วหลอด) · ชั้นนอก: ภาพตัวอย่าง + .blend
#
# ชิ้นในไฟล์ (origin ของไฟล์ = จุดต่อสายไฟบนยอดขั้วหลอด, หลอดห้อยลง -Z):
#   Bulb_Socket    ขั้วเบกาไลต์สีน้ำตาลเข้ม + สวิตช์บิดด้านข้าง + ปลอกทองเหลือง + ลวดขาไส้หลอด (bake texture)
#   Bulb_Glass     กระเปาะแก้วทรงลูกแพร์มีจุกปลาย (ไม่มี texture: Studio ตั้ง Neon อำพันโปร่งแสง)
#   Bulb_Filament  ไส้หลอดขดสปริง + ห่วงไส้ (ไม่มี texture: Studio ตั้ง Neon ส้มสว่าง)
#   Moth_Body / Moth_WingL / Moth_WingR  แมลงเม่า (ตัวยาว 0.09 studs ปีกกาง ~0.17) origin = กลางลำตัว หัวไป -Y
#     ไม่ละเอียด (มองไม่เห็นอยู่แล้ว) ไม่มี texture · ปีกแยกชิ้นให้ client กระพือเอง บานพับที่ |x| = WING_HINGE
# MapBuilder.SwapHangingBulbV2 ใช้ค่า BBOX ใน log นี้
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "HangingBulbV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, put, L, lathe = V.G, V.put, V.L, V.lathe_axis
DOWN = (0, 0, -1)
O = (0, 0, 0)

SOCKET, GLASS, FIL = "Bulb_Socket", "Bulb_Glass", "Bulb_Filament"
BODY, WL, WR = "Moth_Body", "Moth_WingL", "Moth_WingR"
WING_HINGE = 0.012

# ---------------------------------------------------------------- วัสดุ
V.make_mat("Bakelite", L((44, 32, 25)), 0.42, dirt=0.45, wear=0.25, bump=0.04, bump_scale=300)
V.make_mat("Brass", L((150, 116, 58)), 0.38, metal=0.85, dirt=0.55, wear=0.3, rust=0.25)
V.make_mat("LeadWire", L((88, 84, 80)), 0.45, metal=0.8, dirt=0.2)
P.flat("GlassPrev", (1.0, 0.55, 0.2), rough=0.1, dirt=0.0)
P.flat("FilPrev", (1.0, 0.75, 0.35), rough=0.5, dirt=0.0)
P.flat("MothBody", L((112, 92, 70)), rough=0.95, dirt=0.0, noise=0.12)
P.flat("MothWing", L((192, 176, 146)), rough=0.9, dirt=0.0, noise=0.15)

# ---------------------------------------------------------------- ขั้วหลอด (t = ระยะลงจากจุดต่อสายไฟ, r = รัศมี) studs
put(SOCKET, lathe(O, DOWN, [(0.0, 0.0), (0.0, 0.028), (0.018, 0.032), (0.022, 0.055), (0.04, 0.08), (0.065, 0.094), (0.095, 0.1),
                            (0.1, 0.094), (0.106, 0.1), (0.26, 0.103), (0.272, 0.096), (0.282, 0.09), (0.282, 0.0)], n=32), "Bakelite")
# ร่องเกลียวบนตัวขั้ว 2 เส้น
for t in (0.15, 0.2):
    put(SOCKET, lathe(O, DOWN, [(t - 0.006, 0.103), (t, 0.107), (t + 0.006, 0.103)], n=32), "Bakelite")
# สวิตช์บิด: แกนยื่นออกด้านข้าง + ใบบิดแบน (เหมือนในรูป)
put(SOCKET, P.cyl((0.095, 0, -0.08), (1, 0, 0), 0.016, 0.06, n=10), "Bakelite")
put(SOCKET, P.box_rot((0.165, 0, -0.085), (0.026, 0.05, 0.075), "X", 8), "Bakelite")
# ปลอกทองเหลืองที่ปากขั้ว (คอแก้วเสียบอยู่ข้างใน)
put(SOCKET, lathe(O, DOWN, [(0.272, 0.084), (0.276, 0.086), (0.31, 0.083), (0.318, 0.078), (0.318, 0.068)], n=32), "Brass")
# ลวดขาไส้หลอด 2 เส้น (อยู่ในแก้ว เห็นเป็นเส้นเข้มหลังแก้วอำพัน)
CZ0, CZ1, CR, TURNS = -0.50, -0.64, 0.032, 3.5
put(SOCKET, V.tube([(0.018, 0, -0.32), (0.022, 0, -0.42), (CR, 0, CZ0)], 0.0055, n=6), "LeadWire")
put(SOCKET, V.tube([(-0.018, 0, -0.32), (-0.04, 0, -0.44), (-0.05, 0, -0.56), (-CR, 0, CZ1)], 0.0055, n=6), "LeadWire")
put(SOCKET, lathe((0, 0, -0.315), DOWN, [(0.0, 0.026), (0.03, 0.02), (0.08, 0.012), (0.09, 0.0)], n=12), "LeadWire")  # แท่งแก้วยึดขา (เข้ม)

# ---------------------------------------------------------------- กระเปาะแก้วทรงลูกแพร์ + จุกปลาย
put(GLASS, lathe(O, DOWN, [(0.3, 0.0), (0.3, 0.07), (0.335, 0.072), (0.37, 0.082), (0.405, 0.102), (0.44, 0.126), (0.48, 0.146), (0.525, 0.159),
                           (0.575, 0.164), (0.625, 0.161), (0.67, 0.149), (0.71, 0.127), (0.74, 0.096), (0.76, 0.06), (0.768, 0.03),
                           (0.772, 0.016), (0.786, 0.008), (0.79, 0.0)], n=40), "GlassPrev")

# ---------------------------------------------------------------- ไส้หลอด: ขดสปริงแนวตั้ง + ห่วงไส้เอียง (ตามรูป)
coil = []
N = int(TURNS * 16)
for i in range(N + 1):
    t = i / N
    a = 2 * math.pi * TURNS * t
    coil.append((CR * math.cos(a), CR * math.sin(a), CZ0 + (CZ1 - CZ0) * t))
put(FIL, V.tube(coil, 0.0075, n=6), "FilPrev")
loop = []
tilt = math.radians(68)
for i in range(41):
    a = 2 * math.pi * i / 40
    x, y = 0.078 * math.cos(a), 0.078 * math.sin(a)
    loop.append((x, y * math.cos(tilt), -0.6 + y * math.sin(tilt)))
put(FIL, V.tube(loop, 0.006, n=6), "FilPrev")

# ---------------------------------------------------------------- แมลงเม่า (หัว -Y) origin = กลางลำตัว
body = V.loft([V.ring_y(0, y, 0, r, r * 0.9, n=8) for y, r in ((-0.046, 0.003), (-0.042, 0.009), (-0.034, 0.012), (-0.026, 0.01),
                                                               (-0.017, 0.013), (0.0, 0.014), (0.02, 0.013), (0.036, 0.008), (0.047, 0.002))])
put(BODY, body, "MothBody")
put(BODY, V.tube([(0.005, -0.042, 0.003), (0.016, -0.062, 0.013), (0.024, -0.07, 0.016)], 0.0025, n=4), "MothBody")   # หนวด
put(BODY, V.tube([(-0.005, -0.042, 0.003), (-0.016, -0.062, 0.013), (-0.024, -0.07, 0.016)], 0.0025, n=4), "MothBody")
# ปีก (ปีกหน้า+ปีกหลังรวมเป็นแผ่นเดียว) กางลู่ไปข้างหลังแบบแมลงเม่าเกาะ/บิน
wing = [(WING_HINGE, -0.026), (0.04, -0.031), (0.068, -0.02), (0.084, -0.002), (0.08, 0.016), (0.056, 0.03), (0.03, 0.04), (WING_HINGE, 0.03)]  # ทรงสามเหลี่ยมลู่หลัง
put(WL, P.extrude_z(wing, -0.002, 0.002), "MothWing")
put(WR, P.extrude_z([(-x, y) for x, y in wing], -0.002, 0.002), "MothWing")

# ---------------------------------------------------------------- object + bake + export
ORDER = [SOCKET, GLASS, FIL, BODY, WL, WR]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
if not NO_BAKE:
    P.bake_all(OBJ, {SOCKET: "HangingBulbV2_Socket"}, {SOCKET: 256})
P.export_fbx(OBJ, os.path.join(UP, "HangingBulbV2.fbx"), SOCKET)
P.log(f"WING_HINGE={WING_HINGE}")


# ---------------------------------------------------------------- ภาพตัวอย่าง (วัสดุ preview เท่านั้น ไม่ได้ export)
def emit_mat(name, col, strength, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*col, 1)
    bs.inputs["Emission Color"].default_value = (*col, 1)
    bs.inputs["Emission Strength"].default_value = strength
    bs.inputs["Alpha"].default_value = alpha
    bs.inputs["Roughness"].default_value = 0.15
    if alpha < 1:
        m.surface_render_method = "BLENDED"
    return m


def preview():
    OBJ[GLASS].data.materials.clear()
    OBJ[GLASS].data.materials.append(emit_mat("GlassShow", (0.85, 0.36, 0.07), 0.35, 0.6))
    OBJ[FIL].data.materials.clear()
    OBJ[FIL].data.materials.append(emit_mat("FilShow", (1.0, 0.72, 0.32), 25.0))
    for n in (BODY, WL, WR):
        OBJ[n].location = Vector((0.32, -0.15, -0.5)) * V.S
        OBJ[n].rotation_euler = (math.radians(25), 0, math.radians(30))
    OBJ[WL].rotation_euler = (math.radians(25), math.radians(-20), math.radians(30))
    OBJ[WR].rotation_euler = (math.radians(25), math.radians(20), math.radians(30))
    # สายไฟ (ในเกมเป็น Part เดิม) เพื่อดูภาพรวม
    cord = P.cyl((0, 0, 0), (0, 0, 1), 0.03, 1.0, n=8)
    me = bpy.data.meshes.new("Cord")
    me.from_pydata([tuple(Vector(p) * V.S) for p in cord.v], [], cord.f)
    co = bpy.data.objects.new("Cord", me)
    co.data.materials.append(V.MATS["Bakelite"])
    bpy.context.scene.collection.objects.link(co)
    cam, sun, world = P.stage(ground=(0.05, 0.05, 0.05), bg=(0.09, 0.09, 0.1), sun=0.0)
    lp = bpy.data.objects.new("FilLight", bpy.data.lights.new("FilLight", "POINT"))
    lp.data.energy = 3.0
    lp.data.color = (1.0, 0.7, 0.35)
    lp.data.shadow_soft_size = 0.005
    lp.location = Vector((0, 0, -0.58)) * V.S
    bpy.context.scene.collection.objects.link(lp)
    for o in bpy.context.scene.objects:
        if o.name == "Ground":
            o.location.z = -3 * V.S
    P.shot(cam, os.path.join(OUT, "HangingBulbV2.png"), (0, 0, -0.42), (0.15, -1.0, 0.05), 2.2, res=(900, 1200))
    P.shot(cam, os.path.join(OUT, "HangingBulbV2_side.png"), (0, 0, -0.42), (1.0, -0.25, 0.25), 2.2, res=(900, 1200))
    P.shot(cam, os.path.join(OUT, "HangingBulbV2_moth.png"), (0.32, -0.15, -0.5), (0.3, -1.0, 0.6), 0.6, res=(1000, 800))
    P.shot(cam, os.path.join(OUT, "HangingBulbV2_far.png"), (0, 0, -0.4), (0.2, -1.0, -0.35), 7.0, res=(1000, 800))


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "hanging_bulb_v2.blend"))
P.log("done")
