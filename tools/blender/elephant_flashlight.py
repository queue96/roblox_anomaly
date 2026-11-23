# Elephant Flashlight — ไฟฉายตราช้าง (Game Pass) ทรงสปอตไลต์มีหูหิ้วด้านบน ตามรูปอ้างอิงของผู้ใช้ 2026-11-23
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/elephant_flashlight.py
# ผลลัพธ์: assets/models/ElephantFlashlight/upload/ (FBX + texture) · ชั้นนอก: ภาพตัวอย่าง
# ใช้ vehlib.py + proplib.py · แกน Blender: หัวไฟ (ลำแสง) ชี้ -Y, หูหิ้วด้านบน +Z (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
#   Roblox: ลำแสงชี้ -Z (LookVector) เหมือนไฟฉายกบ · จุดจับ = กลางคานหูหิ้ว (log GRIP_rbx) มือกำคานนี้แบบคว่ำมือ ตัวไฟฉายห้อยใต้มือ
#
# หน้าตา: ไฟฉายสปอตไลต์พลาสติก หัวแดงขอบหยัก ตัวดำมีร่องกันลื่น หูหิ้วดำปุ่มแดง แผงไฟ COB ขาวด้านข้าง
#   เหรียญช้างทองอีกด้าน (ตราช้าง)
#
# ชื่อชิ้น (โค้ดเกม server/RobuxShop + server/Flashlight):
#   ElephantFlashlight      ตัวไฟฉายทั้งหมด (ชิ้นหลัก มี texture)
#   ElephantLens            กระจกหน้า (ไม่มี texture: เกมตั้ง Neon สีเหลืองนวลตอนเปิดไฟ)
#   ElephantSidePanel       แผงไฟ COB ด้านข้าง (ไม่มี texture: เกมตั้ง Neon ขาว)
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "ElephantFlashlight")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
PREVIEW_ONLY = os.environ.get("PROP_PREVIEW_ONLY") == "1"
G, box, put, L = V.G, V.box, V.put, V.L
ZUP, XAX, YAX, FRONT = (0, 0, 1), (1, 0, 0), (0, 1, 0), (0, -1, 0)

MAIN, LENS, PANEL = "ElephantFlashlight", "ElephantLens", "ElephantSidePanel"

# ขนาด (studs): ยาว 1.0 หัวกว้าง 0.62 ตัว 0.47 (คนสูง ~6 studs: ไฟฉายจริง ~22 ซม. ขยายนิดให้เห็นชัดในเกม)
CZ = 0.30            # แกนกลางตัวไฟฉาย (สูงจากพื้น)
YB = 0.50            # ท้ายตัว
LEN = 1.0            # ยาวรวม: หน้าสุด y = YB - LEN = -0.5
RB = 0.235           # รัศมีตัว
RH = 0.31            # รัศมีหัวแดง
BAR_Z = CZ + 0.60    # ความสูงคานหูหิ้ว
BAR_Y0, BAR_Y1 = -0.10, 0.40
GRIP = Vector((0.0, (BAR_Y0 + BAR_Y1) / 2, BAR_Z))

# ---------------------------------------------------------------- วัสดุ
V.make_mat("RedPlastic", L((196, 30, 28)), 0.32, dirt=0.2, wear=0.25, bump=0.05, bump_scale=300)
V.make_mat("BlackPlastic", L((24, 23, 24)), 0.42, dirt=0.25, wear=0.3)
V.make_mat("Rubber", L((18, 18, 19)), 0.85, dirt=0.25, bump=0.4, bump_scale=500)
V.make_mat("Chrome", L((214, 214, 218)), 0.12, metal=1.0, dirt=0.1)
P.flat("Gold", L((214, 170, 60)), rough=0.3, metal=0.9, dirt=0.15)
P.flat("ButtonRed", L((220, 36, 30)), rough=0.3, dirt=0.1)
P.flat("LensGlass", L((240, 236, 220)), rough=0.05, dirt=0.0)
P.flat("PanelWhite", L((236, 238, 240)), rough=0.2, dirt=0.0)

# ---------------------------------------------------------------- ตัว (ดำ) แกนตาม -Y จากท้าย
back = Vector((0.0, YB, CZ))
put(MAIN, V.lathe_axis(back, FRONT, [(0.0, 0.0), (0.0, 0.15), (0.025, 0.205), (0.07, RB), (0.70, RB)], n=40), "BlackPlastic")
for t in (0.12, 0.2, 0.28):                                                     # ร่องกันลื่นท้ายตัว
    put(MAIN, P.ring_band(back + Vector((0, -t, 0)), FRONT, RB - 0.01, RB + 0.012, 0.0, 0.035, n=40), "Rubber")
# แหวนดำกันกระแทกต่อหัวแดง + บ่าหยักแบบในรูป
put(MAIN, V.lathe_axis(back + Vector((0, -0.62, 0)), FRONT, [(0.0, RB), (0.03, RB + 0.03), (0.1, RB + 0.03), (0.12, RB + 0.01)], n=40), "BlackPlastic")
for i in range(8):
    a = 2 * math.pi * (i + 0.5) / 8
    put(MAIN, P.box_rot((math.cos(a) * (RB + 0.04), YB - 0.66, CZ + math.sin(a) * (RB + 0.04)), (0.04, 0.1, 0.07), "Y", -math.degrees(a)), "BlackPlastic", bevel=0.01)

# ---------------------------------------------------------------- หัวแดง (บานออก) + ขอบหยัก
head0 = back + Vector((0, -0.70, 0))
put(MAIN, V.lathe_axis(head0, FRONT, [(0.0, RB + 0.01), (0.04, RB + 0.03), (0.16, RH - 0.02), (0.27, RH), (0.30, RH), (0.30, RH - 0.035), (0.29, RH - 0.045)], n=48), "RedPlastic")
for i in range(10):                                                             # ฟันหยักรอบขอบหัว
    a = 2 * math.pi * i / 10
    put(MAIN, P.box_rot((math.cos(a) * (RH + 0.006), YB - LEN + 0.065, CZ + math.sin(a) * (RH + 0.006)), (0.03, 0.11, 0.07), "Y", -math.degrees(a)), "RedPlastic", bevel=0.01)
for i in range(10):                                                             # ร่องตามยาวบนหัว
    a = 2 * math.pi * (i + 0.5) / 10
    r = RH - 0.05
    put(MAIN, P.box_rot((math.cos(a) * r, YB - 0.83, CZ + math.sin(a) * r), (0.02, 0.18, 0.03), "Y", -math.degrees(a)), "RedPlastic")
# ตัวสะท้อนแสงโครเมียม (กรวย) + หลอด LED
front = back + Vector((0, -(LEN - 0.012), 0))
put(MAIN, V.lathe_axis(front, YAX, [(0.0, RH - 0.04), (0.06, RH - 0.09), (0.15, 0.13), (0.2, 0.06), (0.2, 0.0)], n=48), "Chrome")
put(MAIN, P.dome(front + Vector((0, 0.16, 0)), FRONT, 0.035, 0.03, n=16), "PanelWhite")

# ---------------------------------------------------------------- หูหิ้ว (ดำ) + ปุ่มแดง
hp = P.spline([(0, BAR_Y0, CZ + RB - 0.04), (0, BAR_Y0 - 0.01, CZ + 0.42), (0, BAR_Y0 + 0.04, BAR_Z - 0.03), (0, BAR_Y0 + 0.14, BAR_Z),
               (0, BAR_Y1 - 0.12, BAR_Z), (0, BAR_Y1 - 0.02, BAR_Z - 0.04), (0, BAR_Y1, CZ + 0.42), (0, BAR_Y1, CZ + RB - 0.04)], per=6)
put(MAIN, V.tube(hp, 0.055, n=10), "BlackPlastic")
for y in (BAR_Y0 + 0.16, BAR_Y0 + 0.26, BAR_Y0 + 0.36):                          # ปุ่มนิ้วใต้คาน (ที่วางนิ้ว)
    put(MAIN, P.dome(Vector((0, y, BAR_Z - 0.045)), (0, 0, -1), 0.04, 0.03, n=12), "BlackPlastic")
put(MAIN, P.cyl(Vector((0, BAR_Y0 + 0.07, BAR_Z + 0.03)), ZUP, 0.045, 0.035, n=16), "ButtonRed")
put(MAIN, P.ring_band(Vector((0, BAR_Y0 + 0.07, BAR_Z + 0.02)), ZUP, 0.045, 0.06, 0.0, 0.02, n=16), "BlackPlastic")

# ---------------------------------------------------------------- แผงไฟ COB ด้านข้าง (+X) / เหรียญช้างทอง (-X)
PX = RB + 0.004
put(MAIN, box((PX - 0.004, 0.13, CZ), (0.02, 0.4, 0.2)), "Chrome", bevel=0.01)     # กรอบแผง
put(PANEL, box((PX + 0.008, 0.13, CZ + 0.045), (0.006, 0.36, 0.07)), "PanelWhite")
put(PANEL, box((PX + 0.008, 0.13, CZ - 0.045), (0.006, 0.36, 0.07)), "PanelWhite")
put(MAIN, box((PX + 0.01, 0.13, CZ), (0.004, 0.36, 0.012)), "BlackPlastic")         # เส้นแบ่งกลางแผง
EX = -RB - 0.004
put(MAIN, P.cyl(Vector((EX + 0.004, 0.13, CZ)), (-1, 0, 0), 0.09, 0.012, n=28), "Gold")
# ช้างนูนบนเหรียญ: หูใหญ่ + หัว + งวงม้วน + งาขาว หันไปทางหัวไฟ (-Y)
put(MAIN, P.cyl(Vector((EX - 0.004, 0.155, CZ + 0.012)), (-1, 0, 0), 0.045, 0.008, n=20), "BlackPlastic")
put(MAIN, P.cyl(Vector((EX - 0.008, 0.115, CZ + 0.018)), (-1, 0, 0), 0.034, 0.01, n=20), "BlackPlastic")
put(MAIN, V.tube(P.spline([(EX - 0.012, 0.09, CZ + 0.005), (EX - 0.012, 0.072, CZ - 0.02), (EX - 0.012, 0.07, CZ - 0.045),
                           (EX - 0.012, 0.085, CZ - 0.06), (EX - 0.012, 0.095, CZ - 0.05)], per=5), 0.011, n=6), "BlackPlastic")
put(MAIN, V.tube(P.spline([(EX - 0.014, 0.098, CZ - 0.005), (EX - 0.014, 0.085, CZ - 0.018), (EX - 0.014, 0.075, CZ - 0.02)], per=4), 0.006, n=5), "PanelWhite")

# ---------------------------------------------------------------- กระจกหน้า (ชิ้นแยก)
put(LENS, P.cyl(back + Vector((0, -(LEN - 0.006), 0)), FRONT, RH - 0.035, 0.006, n=48), "LensGlass")

ORDER = [MAIN, LENS, PANEL]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"GRIP_rbx=({-GRIP.x:.3f},{GRIP.z:.3f},{GRIP.y:.3f}) LENS_FRONT_rbx_z={YB - LEN:.3f} BODY_AXIS_rbx_y={CZ:.3f}")

# ---------------------------------------------------------------- ภาพตัวอย่าง
def previews():
    cam, sun, world = P.stage(ground=(0.18, 0.17, 0.16), bg=(0.4, 0.42, 0.45), sun=3.2, size=6)
    t = (0.0, 0.1, CZ + 0.15)
    P.shot(cam, os.path.join(OUT, "ElephantFlashlight_front34.png"), t, (0.9, -1.0, 0.45), 3.2, lens=60)
    P.shot(cam, os.path.join(OUT, "ElephantFlashlight_side.png"), t, (1.0, 0.0, 0.12), 3.0, lens=60)
    P.shot(cam, os.path.join(OUT, "ElephantFlashlight_back34.png"), t, (-0.9, 0.9, 0.5), 3.2, lens=60)
    # กลางคืน: เปิดไฟหน้า + แผงข้าง
    for name, col in ((LENS, (1.0, 0.92, 0.7)), (PANEL, (0.95, 0.97, 1.0))):
        ob = OBJ[name]
        ob.data.materials.clear()
        ob.data.materials.append(V.neon_material(name + "Glow", col))
    P.night(world, sun, (1.5, -1.5, 2.5), energy=25)
    P.shot(cam, os.path.join(OUT, "ElephantFlashlight_night.png"), t, (0.9, -1.0, 0.45), 3.2, lens=60)


if PREVIEW_ONLY:
    previews()
else:
    if not NO_BAKE:
        P.bake_all(OBJ, {MAIN: "ElephantFlashlight_Body"}, {MAIN: 1024})
    P.export_fbx(OBJ, os.path.join(UP, "ElephantFlashlight.fbx"), MAIN)
    previews()
