# Pass Stall Items — ของบนแผงขาย Game Pass ใน Lobby (ผู้ใช้ 2026-11-23: ปั้นให้ดีกว่าชิ้นส่วน Part แต่ไม่ละเอียดยิบ Lobby จะได้โหลดไม่เพิ่มมาก)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/pass_stall_items.py
# ผลลัพธ์: assets/models/PassStallItems/upload/ (FBX 1 ไฟล์ 3 ชิ้น + texture 256 px ชิ้นละชุด) · ชั้นนอก: ภาพตัวอย่าง
# ใช้ vehlib.py + proplib.py · หน่วย studs · แกน Blender: หน้าของ (ฝั่งลูกค้า) -Y, origin = พื้นใต้กึ่งกลางของ
#   (Roblox: X = -bx, Y = bz, Z = by) โค้ดเกม lobby/server/PassStallBuilder ตั้ง Size/CFrame เองจาก log BBOX
#
# ชื่อชิ้น (ServerStorage.PassStallItems ใน Lobby):
#   PassGhostBook    สมุดหมอผี: ปกหนังเก่าสีเข้ม สันโค้ง หน้ากระดาษเหลือง มุมทอง ยันต์วงกลมทอง (ลายเรขาคณิตสมมติ) เชือกแดงมัด ที่คั่นแดง
#   PassSandals      รองเท้าแตะติดปีก 1 คู่: พื้นยางเข้ม แผ่นรองสีน้ำตาลอ่อน สายแดง ปีกทองข้างสาย (ไม่ใช้ขาว-น้ำเงินแบบยี่ห้อดัง)
#   PassPrayerBeads  สร้อยประคำไม้บนเบาะแดง ลูกใหญ่ทอง พู่ + ถ้วยทองเหลืองปักธูป (ก้านธูป/ควัน โค้ดเกมสร้างเอง)
#   กฎ: ไม่มีเลือด / อวัยวะ / สัญลักษณ์จริง / โลโก้ (CLAUDE.md)
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "PassStallItems")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
PREVIEW_ONLY = os.environ.get("PROP_PREVIEW_ONLY") == "1"
G, box, put, L = V.G, V.box, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)

BOOK, SANDALS, BEADS = "PassGhostBook", "PassSandals", "PassPrayerBeads"
TEX = 256  # texture ต่อชิ้น (เล็ก: Lobby โหลดเร็ว)


def extrude_x(poly, x0, x1):
    """รูปปิด 2D [(y, z)] ดันหนาตามแกน X"""
    g = P.extrude_y(poly, x0, x1)  # -> (y, x, z)
    g.v = [(b, a, c) for a, b, c in g.v]
    return g


def sphere(c, r, n=8, rings=5):
    prof = [(r - r * math.cos(math.pi * i / rings), r * math.sin(math.pi * i / rings)) for i in range(rings + 1)]
    return V.lathe_axis(Vector(c) - Vector((0, 0, r)), ZUP, prof, n)


def ellipse(cx, cy, rx, ry, n=16, rot=0.0):
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        out.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return out


# ---------------------------------------------------------------- วัสดุ
V.make_mat("Leather", L((58, 34, 26)), 0.6, dirt=0.35, wear=0.35, bump=0.25, bump_scale=220)
P.flat("Pages", L((226, 208, 160)), rough=0.85, dirt=0.35, noise=0.08)
P.flat("Gold", L((214, 170, 60)), rough=0.3, metal=0.9, dirt=0.15)
P.flat("SealRed", L((176, 26, 30)), rough=0.4, dirt=0.15)
V.make_mat("Cord", L((168, 30, 32)), 0.7, dirt=0.2, bump=0.3, bump_scale=400)
V.make_mat("SoleRubber", L((44, 36, 32)), 0.85, dirt=0.2, bump=0.2, bump_scale=300)
P.flat("Footbed", L((196, 150, 98)), rough=0.75, dirt=0.3, noise=0.07)
V.make_mat("Strap", L((182, 32, 34)), 0.5, dirt=0.15)
V.make_mat("Velvet", L((140, 22, 30)), 0.9, dirt=0.3, bump=0.15, bump_scale=500)
P.wood("BeadWood", L((128, 72, 38)), rough=0.45, dirt=0.2, grain_axis="Z", grain=1.0, bump=0.2)
P.flat("Brass", L((190, 140, 60)), rough=0.35, metal=0.85, dirt=0.3)
P.flat("Tassel", L((206, 132, 44)), rough=0.8, dirt=0.15, noise=0.12)

# ================================================================= สมุดหมอผี (กว้าง 1.35 ลึก 1.0 หนา 0.3)
BW, BD, BT, CV = 1.35, 1.0, 0.3, 0.045     # กว้าง (X) ลึก (Y) หนา ความหนาปก
SX = -BW / 2                                # สันหนังสืออยู่ซ้ายมือคนดู
put(BOOK, box((0.02, 0, CV / 2), (BW - 0.04, BD, CV)), "Leather", bevel=0.012)              # ปกล่าง
put(BOOK, box((0.02, 0, BT - CV / 2), (BW - 0.04, BD, CV)), "Leather", bevel=0.012)         # ปกบน
put(BOOK, V.lathe_axis((SX + 0.06, -BD / 2, BT / 2), YAX, [(0, 0), (0, BT / 2), (BD, BT / 2), (BD, 0)], n=12), "Leather")  # สันโค้ง
for y in (-BD / 2 + 0.1, BD / 2 - 0.1):                                                      # สันนูนเป็นปล้อง
    put(BOOK, P.ring_band((SX + 0.06, y, BT / 2), YAX, BT / 2 - 0.01, BT / 2 + 0.018, -0.03, 0.03, n=12), "Leather")
put(BOOK, box((0.05, 0, BT / 2), (BW - 0.16, BD - 0.06, BT - 2 * CV + 0.004)), "Pages")     # สันหน้ากระดาษ
# มุมทองฝั่งเปิด (หน้า/หลัง ด้านขวา) บน-ล่าง
for y, sy in ((-BD / 2, 1), (BD / 2, -1)):
    for z in (CV / 2, BT - CV / 2):
        tri = [(BW / 2 + 0.008, y - sy * 0.008), (BW / 2 - 0.2, y - sy * 0.008), (BW / 2 + 0.008, y + sy * 0.2)]
        put(BOOK, P.extrude_z(tri, z - CV / 2 - 0.008, z + CV / 2 + 0.008), "Gold")
# ยันต์ทองกลางปก: วงแหวนคู่ + ดาวแปดแฉก (สี่เหลี่ยมซ้อน 2 ชั้นเอียง 45) + ตราครั่งแดงตรงกลาง
TOP = BT + 0.002
put(BOOK, P.ring_band((0.08, 0, TOP), ZUP, 0.25, 0.28, 0, 0.012, n=32), "Gold")
put(BOOK, P.ring_band((0.08, 0, TOP), ZUP, 0.205, 0.22, 0, 0.012, n=32), "Gold")
for deg in (0, 45):
    put(BOOK, P.box_rot((0.08, 0, TOP + 0.006), (0.26, 0.26, 0.012), "Z", deg), "Gold")
put(BOOK, P.dome((0.08, 0, TOP + 0.012), ZUP, 0.085, 0.035, n=16), "SealRed")
for i in range(8):                                                                           # จุดทองรอบวง
    a = 2 * math.pi * (i + 0.5) / 8
    put(BOOK, P.dome((0.08 + math.cos(a) * 0.235, math.sin(a) * 0.235, TOP), ZUP, 0.014, 0.012, n=6), "Gold")
# เชือกแดงมัดรอบเล่ม (แนวหน้า-หลัง ใกล้ฝั่งเปิด)
cx = BW / 2 - 0.26
loop = []
for y, z in ((-BD / 2 - 0.012, 0.03), (-BD / 2 - 0.012, BT - 0.03), (-BD / 2 + 0.04, BT + 0.014), (BD / 2 - 0.04, BT + 0.014),
             (BD / 2 + 0.012, BT - 0.03), (BD / 2 + 0.012, 0.03), (BD / 2 - 0.04, -0.01), (-BD / 2 + 0.04, -0.01), (-BD / 2 - 0.012, 0.03)):
    loop.append((cx, y, z))
put(BOOK, V.tube(P.spline(loop, per=3), 0.017, n=6), "Cord")
put(BOOK, V.tube(P.spline([(cx, -BD / 2 - 0.015, BT * 0.6), (cx + 0.06, -BD / 2 - 0.06, BT * 0.35), (cx + 0.1, -BD / 2 - 0.12, 0.012)], per=4), 0.016, n=6), "Cord")  # ปลายเชือกห้อย
# ที่คั่นหนังสือแดงโผล่หน้าเล่ม
put(BOOK, P.box_rot((-0.25, -BD / 2 - 0.05, BT * 0.55), (0.09, 0.14, 0.008), "X", 70), "Cord")
put(BOOK, P.box_rot((-0.25, -BD / 2 - 0.12, 0.012), (0.09, 0.12, 0.008), "X", 0), "Cord")

# ================================================================= รองเท้าแตะติดปีก (คู่) ยาว 1.15
SL = 1.15


def sole_outline(n=22):
    """ขอบพื้นรองเท้า (x, y): ปลายเท้า (-Y) กว้างมน ส้น (+Y) แคบกว่าและมน เว้าช่วงอุ้งเท้านิดๆ"""
    def w(t):  # t = 0 ปลายเท้า .. 1 ส้น
        if t < 0.28:
            return 0.25 * math.sqrt(max(0.0, 1 - (1 - t / 0.28) ** 2))
        if t > 0.8:
            return 0.19 * math.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2))
        k = (t - 0.28) / 0.52
        return 0.25 + (0.19 - 0.25) * k - 0.025 * math.exp(-((t - 0.6) / 0.1) ** 2)
    right, left = [], []
    for i in range(n + 1):
        t = i / n
        y = -SL / 2 + t * SL
        right.append((w(t), y))
        left.append((-w(t) * 0.9, y))
    return right + left[::-1][1:-1]


def sandal(ox, mirror, yaw):
    rotm = P.rot_at((ox, 0, 0), "Z", yaw)
    ol = [(ox + x * mirror, y) for x, y in sole_outline()]
    out = []
    out.append((P.extrude_z(ol, 0.0, 0.055), "SoleRubber"))
    inner = [(ox + (x - ox) * 0.94, y * 0.96) for x, y in ol]
    out.append((P.extrude_z(inner, 0.055, 0.095), "Footbed"))
    post = (ox + 0.01 * mirror, -0.25, 0.095)
    out.append((P.cyl(post, ZUP, 0.03, 0.08, n=8), "Strap"))
    for side in (1, -1):
        sx = side * mirror
        end = (ox + 0.2 * sx, 0.03, 0.1)
        pts = [(post[0], post[1], 0.17), (ox + 0.07 * sx, -0.18, 0.19), (ox + 0.16 * sx, -0.07, 0.15), end]
        out.append((V.tube(P.spline(pts, per=4), 0.034, n=6), "Strap"))
    # ปีกทองด้านนอกตรงปลายสาย: ขนนก 4 เส้นบานไปทางส้น เอียงออกด้านนอกให้เห็นจากด้านบน
    bx, by, bz = ox + 0.2 * mirror, 0.03, 0.12
    tilt = P.rot_at((bx, by, bz), "Y", 40 * mirror)
    for k, (ln, ang) in enumerate(((0.36, 12), (0.31, 30), (0.25, 48), (0.18, 66))):
        a = math.radians(ang)
        cy, cz = by + math.cos(a) * ln / 2, bz + math.sin(a) * ln / 2
        wd = 0.05
        pts = [(cy + math.cos(a) * math.cos(t) * ln / 2 - math.sin(a) * math.sin(t) * wd,
                cz + math.sin(a) * math.cos(t) * ln / 2 + math.cos(a) * math.sin(t) * wd) for t in [2 * math.pi * i / 12 for i in range(12)]]
        out.append((P.xform(extrude_x(pts, bx - 0.012 + k * 0.004 * mirror, bx + 0.012 + k * 0.004 * mirror), tilt), "Gold"))
    out.append((sphere((bx, by, bz), 0.045, n=8, rings=4), "Gold"))  # หมุดทองตรงโคนปีก
    for g, m in out:
        put(SANDALS, P.xform(g, rotm), m)


sandal(-0.33, -1, 6)    # ข้างซ้ายคนดู (ปีกออกด้านนอก)
sandal(0.33, 1, -6)

# ================================================================= สร้อยประคำบนเบาะ (เบาะ 1.6 x 1.3)
CH = 0.2
put(BEADS, box((0, 0, CH / 2), (1.6, 1.3, CH)), "Velvet", bevel=0.07)
for x, y in ((-0.78, -0.63), (0.78, -0.63), (-0.78, 0.63), (0.78, 0.63)):                 # พู่ทองที่มุมเบาะ
    put(BEADS, sphere((x, y, CH * 0.55), 0.045, n=8, rings=4), "Gold")
    put(BEADS, V.lathe_axis((x * 1.04, y * 1.05, CH * 0.5), (x, y, -0.9), [(0, 0.02), (0.06, 0.035), (0.16, 0.05), (0.17, 0)], n=8), "Tassel")
NB, RX, RY, BR = 24, 0.46, 0.38, 0.068
for i in range(NB):
    a = 2 * math.pi * (i + 0.5) / NB - math.pi / 2
    if math.sin(a) < -0.98:  # เว้นช่องหน้าสุดให้ลูกใหญ่
        continue
    put(BEADS, sphere((math.cos(a) * RX, math.sin(a) * RY + 0.05, CH + BR), BR, n=8, rings=5), "BeadWood")
gy = 0.05 - RY - 0.02
put(BEADS, sphere((0, gy, CH + 0.09), 0.09, n=10, rings=6), "Gold")                       # ลูกใหญ่
put(BEADS, P.cyl((0, gy - 0.08, CH + 0.06), (0, -1, 0), 0.035, 0.06, n=8), "Gold")
put(BEADS, V.lathe_axis((0, gy - 0.14, CH + 0.06), (0, -1, -0.12), [(0, 0.03), (0.08, 0.05), (0.26, 0.085), (0.27, 0)], n=10), "Tassel")
# ถ้วยทองเหลืองปักธูป (หลังขวาของคนดู: x บวก = ขวา)
CUPX, CUPY = 0.56, 0.4
put(BEADS, V.lathe_axis((CUPX, CUPY, CH), ZUP, [(0, 0), (0, 0.07), (0.02, 0.1), (0.11, 0.115), (0.12, 0.1), (0.1, 0.09), (0.1, 0)], n=16), "Brass")

ORDER = [BOOK, SANDALS, BEADS]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"INCENSE_CUP_rbx=({-CUPX:.3f},{CH + 0.1:.3f},{CUPY:.3f})")


# ---------------------------------------------------------------- ภาพตัวอย่าง (วางเรียงกันเฉพาะในภาพ)
def previews():
    cam, sun, world = P.stage(ground=(0.36, 0.24, 0.15), bg=(0.4, 0.42, 0.45), sun=3.2, size=8)
    offs = {BOOK: -2.1, SANDALS: 0.0, BEADS: 2.2}
    for n, ob in OBJ.items():
        ob.location.x = offs[n] * V.S
    P.shot(cam, os.path.join(OUT, "PassStallItems_front34.png"), (0, 0, 0.2), (0.25, -1.0, 0.75), 8.5, lens=50, res=(1500, 800))
    P.shot(cam, os.path.join(OUT, "PassStallItems_top.png"), (0, 0, 0.1), (0.0, -0.35, 1.0), 8.0, lens=50, res=(1500, 800))
    for ob in OBJ.values():
        ob.location.x = 0


if PREVIEW_ONLY:
    previews()
else:
    if not NO_BAKE:
        P.bake_all(OBJ, {BOOK: "PassGhostBook", SANDALS: "PassSandals", BEADS: "PassPrayerBeads"}, {BOOK: TEX, SANDALS: TEX, BEADS: TEX})
    P.export_fbx(OBJ, os.path.join(UP, "PassStallItems.fbx"), BOOK)
    previews()
