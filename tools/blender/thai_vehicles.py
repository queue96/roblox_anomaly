# รถและจักรยานสไตล์ไทย 8 คัน (ลูกค้าปั๊ม) — สร้างด้วย Blender แบบ headless
# รัน:  blender-launcher.exe --background --factory-startup --python tools/blender/thai_vehicles.py
# ผลลัพธ์: assets/models/<Vehicle>.fbx + <Vehicle>_Color/_Normal/_Roughness/_Metalness.png,
#          assets/models/previews/<Vehicle>.png + ThaiVehicles_Sheet.png, assets/models/thai_vehicles.blend,
#          assets/models/ThaiVehicles_Rig.json (ที่นั่ง ล้อ ไฟ กล่องชน และชิ้น proxy ให้ MapBuilder สร้างใน Studio)
# หน่วยตอนปั้นเป็น studs แล้วคูณ 0.28 ตอนสร้าง mesh (1 stud = 0.28 m)
# แกน Blender: หน้ารถหันไป -Y, ด้านซ้ายของรถ = +X (คนขับพวงมาลัยขวาอยู่ฝั่ง -X), origin = พื้นใต้กึ่งกลางรถ
# ขนาดขยายจากของจริงราว 1.3 เท่าให้ตัวละคร R15 (สูง ~5.2 studs, นั่งแล้วหัวสูงจากเบาะ ~3.4) นั่งได้ไม่ชนหลังคา
import bpy, bmesh, math, os, json
import numpy as np
from mathutils import Vector, Matrix
from contextlib import contextmanager

S = 0.28
ROOT = r"C:\Aunival\pump-lot-anomaly\assets\models"
PREV = os.path.join(ROOT, "previews")
ONLY = os.environ.get("VEH_ONLY", "")
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s)


# ---------------------------------------------------------------- palette
# c = สี sRGB, r = roughness, m = metalness, p = ลาย
PAL = {
    # กระบะเก่า
    "pk_paint": dict(c=(84, 54, 56), r=0.7, m=0.15, p="rustpaint"),
    "pk_paint_top": dict(c=(78, 52, 54), r=0.8, m=0.1, p="rustpaint_top"),
    "rust": dict(c=(104, 60, 36), r=0.95, m=0.2, p="rust"),
    "cage_rust": dict(c=(92, 78, 66), r=0.85, m=0.4, p="rust_light"),
    "engine": dict(c=(46, 42, 38), r=0.8, m=0.4, p="grime"),
    "rim_rust": dict(c=(150, 112, 80), r=0.85, m=0.35, p="rust_light"),
    # ทั่วไป
    "tire": dict(c=(30, 30, 30), r=0.92, m=0, p="tread"),
    "tire_side": dict(c=(34, 34, 34), r=0.9, m=0, p="plain"),
    "black": dict(c=(30, 30, 32), r=0.6, m=0.1, p="plain"),
    "black_gloss": dict(c=(22, 22, 26), r=0.25, m=0.3, p="plain"),
    "rubber": dict(c=(26, 26, 26), r=0.9, m=0, p="plain"),
    "grille": dict(c=(40, 40, 42), r=0.5, m=0.5, p="grille"),
    "chrome": dict(c=(196, 198, 204), r=0.15, m=1.0, p="chrome"),
    "steel": dict(c=(140, 142, 146), r=0.4, m=0.9, p="plain"),
    "glass": dict(c=(52, 64, 72), r=0.04, m=0.6, p="plain"),
    "glass_clear": dict(c=(120, 140, 150), r=0.03, m=0.3, p="plain"),
    "lens_white": dict(c=(232, 228, 210), r=0.1, m=0, p="lamp"),
    "lens_amber": dict(c=(226, 130, 40), r=0.1, m=0, p="lamp"),
    "lens_red": dict(c=(170, 24, 22), r=0.1, m=0, p="lamp"),
    "interior": dict(c=(70, 62, 54), r=0.85, m=0, p="plain"),
    "floor_mat": dict(c=(38, 36, 34), r=0.95, m=0, p="grime"),
    "seat_vinyl": dict(c=(46, 38, 34), r=0.6, m=0, p="vinyl"),
    "seat_cloth": dict(c=(86, 80, 72), r=0.9, m=0, p="canvas"),
    "plate": dict(c=(236, 236, 230), r=0.5, m=0, p="plate"),
    # เก๋งบรอนซ์ทอง
    "sd_paint": dict(c=(188, 180, 158), r=0.3, m=0.6, p="metallic"),
    "pk_stripe": dict(c=(150, 138, 118), r=0.8, m=0.1, p="rust_light"),
    "pk_stripe2": dict(c=(205, 200, 190), r=0.7, m=0.05, p="grime"),
    "sd_trim": dict(c=(70, 68, 66), r=0.5, m=0.1, p="plain"),
    # จักรยาน
    "bk_red": dict(c=(176, 30, 34), r=0.3, m=0.35, p="metallic"),
    "bk_blue": dict(c=(36, 72, 176), r=0.3, m=0.35, p="metallic"),
    "bk_yellow": dict(c=(214, 204, 40), r=0.4, m=0, p="plain"),
    "bk_silver": dict(c=(176, 180, 186), r=0.35, m=0.6, p="plain"),
    "basket": dict(c=(26, 26, 28), r=0.6, m=0.3, p="basket"),
    "bk_guard": dict(c=(46, 86, 196), r=0.5, m=0.2, p="basket"),
    "spoke": dict(c=(186, 188, 192), r=0.25, m=1.0, p="plain"),
    "saddle": dict(c=(30, 30, 30), r=0.55, m=0, p="vinyl"),
    # ตุ๊กตุ๊ก
    "tt_blue": dict(c=(28, 78, 168), r=0.35, m=0.3, p="metallic"),
    "tt_red": dict(c=(176, 26, 30), r=0.35, m=0.3, p="metallic"),
    "tt_roof": dict(c=(22, 22, 24), r=0.85, m=0, p="canvas"),
    "tt_seat": dict(c=(32, 70, 150), r=0.5, m=0, p="vinyl"),
    "sign_yellow": dict(c=(236, 200, 40), r=0.5, m=0, p="sign"),
    "floor_tread": dict(c=(150, 150, 154), r=0.5, m=0.8, p="treadplate"),
    # มอเตอร์ไซค์ซิ่ง
    "mt_orange": dict(c=(236, 92, 22), r=0.25, m=0.3, p="metallic"),
    "mt_black": dict(c=(24, 24, 28), r=0.3, m=0.3, p="plain"),
    "mt_white": dict(c=(220, 220, 224), r=0.35, m=0, p="plain"),
    "mt_purple": dict(c=(128, 50, 176), r=0.2, m=0.9, p="anodized"),
    "mt_gold": dict(c=(214, 166, 60), r=0.25, m=0.9, p="plain"),
    "mt_red": dict(c=(210, 30, 30), r=0.3, m=0.3, p="plain"),
    "spoke_c1": dict(c=(60, 220, 120), r=0.2, m=0.9, p="plain"),
    "spoke_c2": dict(c=(240, 60, 170), r=0.2, m=0.9, p="plain"),
    "spoke_c3": dict(c=(60, 160, 240), r=0.2, m=0.9, p="plain"),
    "spoke_c4": dict(c=(240, 210, 50), r=0.2, m=0.9, p="plain"),
    # กระบะรถแห่
    "st_blue": dict(c=(28, 104, 214), r=0.2, m=0.45, p="metallic"),
    "st_sticker": dict(c=(28, 104, 214), r=0.25, m=0.4, p="F_sticker"),
    "speaker": dict(c=(40, 40, 44), r=0.6, m=0.2, p="speaker"),
    "speaker_box": dict(c=(20, 20, 22), r=0.7, m=0, p="carpet"),
    "horn": dict(c=(170, 172, 176), r=0.3, m=0.8, p="plain"),
    "led": dict(c=(255, 255, 255), r=0.3, m=0, p="plain"),
    # รถแห่ 6 ล้อ
    "pt_red": dict(c=(206, 28, 30), r=0.25, m=0.4, p="metallic"),
    "pt_stripe": dict(c=(226, 226, 226), r=0.35, m=0.1, p="plain"),
    "pt_graphic": dict(c=(206, 28, 30), r=0.25, m=0.35, p="F_parade"),
    "pt_logo": dict(c=(214, 168, 60), r=0.3, m=0.8, p="logo"),
    "pt_vent": dict(c=(150, 18, 20), r=0.4, m=0.3, p="vent"),
    "interior_wall": dict(c=(60, 30, 40), r=0.8, m=0, p="carpet"),
    "floor_wood": dict(c=(120, 82, 52), r=0.7, m=0, p="planks"),
    "glass_dark": dict(c=(18, 20, 24), r=0.05, m=0.4, p="plain"),
    "led1": dict(c=(255, 40, 60), r=0.3, m=0, p="plain"),
    "led2": dict(c=(40, 255, 120), r=0.3, m=0, p="plain"),
    "led3": dict(c=(255, 150, 30), r=0.3, m=0, p="plain"),
    "led4": dict(c=(60, 140, 255), r=0.3, m=0, p="plain"),
    "led5": dict(c=(255, 60, 220), r=0.3, m=0, p="plain"),
}
KEYS = list(PAL.keys())

# ---------------------------------------------------------------- geometry builder (studs)


class B:
    def __init__(s, name):
        s.name = name
        s.v = []
        s.f = []
        s.k = []
        s.M = Matrix.Identity(4)
        s.smooth = False
        s.bevel = True  # ลบมุมคม (Bevel modifier) ให้ดูเป็นรถจริง ไม่ใช่กล่อง
        s.bw = 0.03  # ความกว้างมุมมน (เมตร)
        s.sa = 35  # มุม smooth shading (องศา)

    @contextmanager
    def xf(s, M):
        old = s.M
        s.M = old @ M
        try:
            yield
        finally:
            s.M = old

    def _v(s, p):
        s.v.append(s.M @ Vector(p))
        return len(s.v) - 1

    def face(s, idx, key):
        out = []
        for i in idx:
            if not out or out[-1] != i:
                out.append(i)
        if len(out) > 1 and out[0] == out[-1]:
            out.pop()
        if len(set(out)) >= 3:
            s.f.append(out)
            s.k.append(key)

    def hexa(s, P, key, keys=None, skip=()):
        keys = keys or {}
        i = [s._v(p) for p in P]
        F = {"bottom": (3, 2, 1, 0), "top": (4, 5, 6, 7), "front": (0, 1, 5, 4),
             "right": (1, 2, 6, 5), "back": (2, 3, 7, 6), "left": (3, 0, 4, 7)}
        for n, q in F.items():
            if n in skip:
                continue
            s.face([i[j] for j in q], keys.get(n, key))

    def box(s, x0, x1, y0, y1, z0, z1, key, keys=None, skip=()):
        s.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], key, keys, skip)

    def boxc(s, cx, cy, cz, sx, sy, sz, key, keys=None, skip=()):
        s.box(cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2, key, keys, skip)

    def boxm(s, x0, x1, y0, y1, z0, z1, key, keys=None):
        """กล่องสมมาตรซ้าย-ขวา (x0..x1 ฝั่ง +X แล้วสะท้อนไป -X)"""
        s.box(x0, x1, y0, y1, z0, z1, key, keys)
        s.box(-x1, -x0, y0, y1, z0, z1, key, keys)

    def lathe(s, cx, cy, prof, n, key, z0=0.0):
        rings = []
        for r, z in prof:
            if r < 1e-4:
                rings.append([s._v((cx, cy, z0 + z))] * n)
            else:
                rings.append([s._v((cx + r * math.cos(2 * math.pi * j / n), cy + r * math.sin(2 * math.pi * j / n), z0 + z)) for j in range(n)])
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(n):
                k = (j + 1) % n
                s.face([a[j], a[k], b[k], b[j]], key)
        if prof[0][0] > 1e-4:
            s.face(list(reversed(rings[0])), key)
        if prof[-1][0] > 1e-4:
            s.face(rings[-1], key)

    def ellipsoid(s, c, r, key, nu=12, nv=7):
        rings = []
        for i in range(nv + 1):
            t = math.pi * i / nv
            z, rr = -math.cos(t), math.sin(t)
            if rr < 1e-4:
                rings.append([s._v((c[0], c[1], c[2] + r[2] * z))] * nu)
            else:
                rings.append([s._v((c[0] + r[0] * rr * math.cos(2 * math.pi * j / nu), c[1] + r[1] * rr * math.sin(2 * math.pi * j / nu), c[2] + r[2] * z)) for j in range(nu)])
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(nu):
                k = (j + 1) % nu
                s.face([a[j], a[k], b[k], b[j]], key)

    def tube(s, pts, radii, key, n=10, cap=True):
        pts = [Vector(p) for p in pts]
        if isinstance(radii, (int, float)):
            radii = [radii] * len(pts)
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
            if prev_n is None:
                up = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 0, 1))
                nn = t.cross(up).normalized()
            else:
                nn = (prev_n - t * prev_n.dot(t)).normalized()
            prev_n = nn
            bb = t.cross(nn).normalized()
            r = radii[i]
            rings.append([s._v(p + (nn * math.cos(2 * math.pi * j / n) + bb * math.sin(2 * math.pi * j / n)) * r) for j in range(n)])
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(n):
                k = (j + 1) % n
                s.face([a[j], a[k], b[k], b[j]], key)
        if cap:
            s.face(list(reversed(rings[0])), key)
            s.face(rings[-1], key)

    def beam(s, p0, p1, w, h, key, side=(1, 0, 0)):
        """กล่องยาวจาก p0 ไป p1 กว้าง w (ตามแกน side) หนา h"""
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0).normalized()
        sd = Vector(side)
        sd = (sd - d * sd.dot(d))
        if sd.length < 1e-5:
            sd = Vector((0, 1, 0)) - d * d.y
        sd.normalize()
        up = d.cross(sd).normalized()
        a, b = sd * (w / 2), up * (h / 2)
        P = [p0 - a - b, p1 - a - b, p1 + a - b, p0 + a - b, p0 - a + b, p1 - a + b, p1 + a + b, p0 + a + b]
        s.hexa([tuple(p) for p in P], key)

    def prism_yz(s, poly, x0, x1, key, cap_key=None):
        """polygon ในระนาบ YZ ยืดตามแกน X"""
        cap_key = cap_key or key
        a = [s._v((x0, y, z)) for y, z in poly]
        b = [s._v((x1, y, z)) for y, z in poly]
        n = len(poly)
        s.face(a, cap_key)
        s.face(list(reversed(b)), cap_key)
        for j in range(n):
            k = (j + 1) % n
            s.face([a[j], a[k], b[k], b[j]], key)

    def loft(s, secs, key, segkey=None, cap_key=None):
        """secs = [(y, [(x, z) ...])] จำนวนจุดเท่ากันทุกหน้าตัด, segkey(j, i) -> key ของแถบที่ j ช่วงที่ i"""
        rings = [[s._v((x, y, z)) for x, z in pts] for y, pts in secs]
        n = len(secs[0][1])
        for i, (a, b) in enumerate(zip(rings[:-1], rings[1:])):
            for j in range(n):
                k = (j + 1) % n
                s.face([a[j], a[k], b[k], b[j]], segkey(j, i) if segkey else key)
        s.face(rings[0], cap_key or key)
        s.face(list(reversed(rings[-1])), cap_key or key)

    def torus(s, c, axis, R, rm, key, nu=24, nv=6):
        """ห่วงรอบแกน axis ('x' หรือ 'y' หรือ 'z')"""
        c = Vector(c)
        if axis == "x":
            e1, e2, ax = Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
        elif axis == "y":
            e1, e2, ax = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, 1, 0))
        else:
            e1, e2, ax = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
        rings = []
        for i in range(nu):
            a = 2 * math.pi * i / nu
            rad = e1 * math.cos(a) + e2 * math.sin(a)
            ctr = c + rad * R
            rings.append([s._v(ctr + (rad * math.cos(2 * math.pi * j / nv) + ax * math.sin(2 * math.pi * j / nv)) * rm) for j in range(nv)])
        for i in range(nu):
            a, b = rings[i], rings[(i + 1) % nu]
            for j in range(nv):
                k = (j + 1) % nv
                s.face([a[j], a[k], b[k], b[j]], key)

    def disc_x(s, c, r, w, key, n=16, key2=None):
        """ทรงกระบอกแกน X ศูนย์กลาง c ยาว w"""
        cx, cy, cz = c
        a = [s._v((cx - w / 2, cy + r * math.cos(2 * math.pi * j / n), cz + r * math.sin(2 * math.pi * j / n))) for j in range(n)]
        b = [s._v((cx + w / 2, cy + r * math.cos(2 * math.pi * j / n), cz + r * math.sin(2 * math.pi * j / n))) for j in range(n)]
        for j in range(n):
            k = (j + 1) % n
            s.face([a[j], a[k], b[k], b[j]], key)
        s.face(list(reversed(a)), key2 or key)
        s.face(b, key2 or key)

    def cone(s, p0, p1, r0, r1, key, n=10):
        """กรวย/ทรงกระบอกจาก p0 ไป p1"""
        s.tube([p0, p1], [r0, r1], key, n=n)


# ---------------------------------------------------------------- rig (ข้อมูลให้ Studio)
RIG = {}
OBJ_BBOX = {}


def rig(prop):
    return RIG.setdefault(prop, dict(seats=[], wheels=[], lights=[], cols=[], skids=[], proxy=[], plates=[], signs=[], speakers=[], ledbars=[]))


def r_pt(p):
    """Blender (x, y, z) -> แกน Roblox ของรถ (หน้า -Z, ขวา +X)"""
    return [round(-p[0], 3), round(p[2], 3), round(p[1], 3)]


def r_box(x0, x1, y0, y1, z0, z1):
    c = r_pt(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return c, [round(abs(x1 - x0), 3), round(abs(z1 - z0), 3), round(abs(y1 - y0), 3)]


def COL(prop, x0, x1, y0, y1, z0, z1, mirror=False, friction=None):
    """กล่องชนล่องหน (ตัวละครยืน/ชนได้)"""
    for xs in ((x0, x1), (-x1, -x0)) if mirror else ((x0, x1),):
        c, sz = r_box(xs[0], xs[1], y0, y1, z0, z1)
        d = dict(c=c, s=sz)
        if friction is not None:
            d["f"] = friction
        rig(prop)["cols"].append(d)


def PX(prop, key, x0, x1, y0, y1, z0, z1, shape="Block", mirror=False, rx=0, th=0.15, neon=False):
    """ชิ้น proxy (ใช้แสดงผลแทน mesh ระหว่างยังไม่ได้นำเข้า FBX)
    rx = 0 กล่องตามขอบเขต, rx > 0 แผ่น/แท่งเฉียงตามเส้นทแยงจากหน้า-บนไปหลัง-ล่าง, rx < 0 จากหน้า-ล่างไปหลัง-บน (หนา th)"""
    for xs in ((x0, x1), (-x1, -x0)) if mirror else ((x0, x1),):
        c, sz = r_box(xs[0], xs[1], y0, y1, z0, z1)
        d = dict(c=c, s=sz, k=key, sh=shape, n=1 if neon else 0)
        if rx:
            d["rx"] = 1 if rx > 0 else -1
            d["th"] = th
        rig(prop)["proxy"].append(d)


def SEAT(prop, name, kind, x, y, ztop, w=2.0, d=2.0, t=0.3):
    """ที่นั่ง: ผิวบนอยู่ที่ ztop (ตัวละครนั่งบนผิวบน) t = ความหนา (หนาไว้ให้เดินชนแล้วนั่งได้ง่าย)"""
    c = r_pt((x, y, ztop - t / 2))
    rig(prop)["seats"].append(dict(n=name, t=kind, c=c, s=[w, t, d]))


def WHEEL(prop, name, x, y, z, r, w, steer=False):
    rig(prop)["wheels"].append(dict(n=name, c=r_pt((x, y, z)), r=r, w=w, st=1 if steer else 0))
    rig(prop)["skids"].append(dict(c=r_pt((x, y, z)), r=r))


def LIGHT(prop, kind, x, y, z, sx, sz, round_=False):
    c, sz3 = r_box(x - sx / 2, x + sx / 2, y - 0.08, y + 0.08, z - sz / 2, z + sz / 2)
    rig(prop)["lights"].append(dict(t=kind, c=c, s=sz3, rd=1 if round_ else 0))


def PLATE(prop, x, y, z, front, w=1.9, h=0.95, text="ฆธ 186", prov="ราชบุรี"):
    c, sz = r_box(x - w / 2, x + w / 2, y - 0.04, y + 0.04, z - h / 2, z + h / 2)
    rig(prop)["plates"].append(dict(c=c, s=sz, front=1 if front else 0, t=text, p=prov))


# ---------------------------------------------------------------- parts ที่ใช้ซ้ำ
def car_wheel(b, x, y, z, r, w, rim="steel", lug=True):
    """ล้อรถยนต์แกน X: ยาง + กระทะสองด้าน"""
    side = 1 if x > 0 else -1
    with b.xf(Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y")):
        b.lathe(0, 0, [(r * 0.6, -w / 2), (r * 0.9, -w / 2), (r, -w * 0.3), (r, w * 0.3), (r * 0.9, w / 2), (r * 0.6, w / 2)], 24, "tire")
        for sgn in (-1, 1):
            zz = sgn * (w / 2)
            prof = [(r * 0.6, zz), (r * 0.53, zz + sgn * 0.06), (r * 0.3, zz + sgn * 0.02), (r * 0.16, zz + sgn * 0.1)]
            if sgn < 0:
                prof = list(reversed(prof))
            b.lathe(0, 0, prof, 16, rim)
        if lug:
            for j in range(5):
                a = 2 * math.pi * j / 5
                b.boxc(0.22 * r * math.cos(a), 0.22 * r * math.sin(a), side * (w / 2 + 0.08), 0.1, 0.1, 0.08, "steel")


def bike_wheel(b, y, z, R, spokes=16, rim="chrome", tire="tire", spoke_keys=("spoke",), tire_w=0.11, hub_w=0.36):
    b.torus((0, y, z), "x", R - tire_w, tire_w, tire, nu=40, nv=8)
    b.torus((0, y, z), "x", R - tire_w * 2 - 0.05, 0.05, rim, nu=40, nv=6)
    b.disc_x((0, y, z), 0.13, hub_w, "steel", n=8)
    rr = R - tire_w * 2 - 0.08
    for j in range(spokes):
        a = 2 * math.pi * j / spokes
        sx = hub_w / 2 * (1 if j % 2 else -1)
        p0 = (sx, y + 0.12 * math.cos(a + 0.5), z + 0.12 * math.sin(a + 0.5))
        p1 = (sx * 0.2, y + rr * math.cos(a), z + rr * math.sin(a))
        b.beam(p0, p1, 0.035, 0.035, spoke_keys[j % len(spoke_keys)])


def fender(b, y, z, R, w, key, a0, a1, th=0.06, n=12):
    """บังโคลนโค้งตามล้อ (มุมเป็นองศา 0 = ด้านหน้า, 90 = ด้านบน)"""
    pts = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        pts.append((y - R * math.cos(a), z + R * math.sin(a)))
    for i in range(n):
        (ya, za), (yb, zb) = pts[i], pts[i + 1]
        b.beam((0, ya, za), (0, yb, zb), w, th, key)


def rsec(y, wb, wt, z0, z1, rb=0.3, rt=0.5):
    """หน้าตัดตัวถัง 8 จุด (ล่างกว้าง wb บนกว้าง wt ครึ่งความกว้าง)"""
    rb = min(rb, (z1 - z0) / 3)
    rt = min(rt, (z1 - z0) / 3)
    return (y, [(-wb + rb, z0), (wb - rb, z0), (wb, z0 + rb), (wt, z1 - rt), (wt - rt, z1), (-wt + rt, z1), (-wt, z1 - rt), (-wb, z0 + rb)])


def arch_secs(yc, R, wb, wt, zlow, ztop, extra=0.15, top_fn=None):
    """หน้าตัดรอบซุ้มล้อ yc รัศมีซุ้ม R"""
    out = []
    for t in (-1.0, -0.98, -0.8, -0.45, 0.0, 0.45, 0.8, 0.98, 1.0):
        y = yc + t * (R + extra)
        if abs(t) >= 0.999:
            z0 = zlow
        else:
            z0 = max(zlow, (ztop - R) + R * math.sqrt(max(0.0, 1 - t * t)) + 0.0)
        zt = top_fn(y) if top_fn else ztop + 2
        out.append(rsec(y, wb, wt, z0, zt))
    return out


def cab(b, prop, y0, y1, W, zsill, zfloor, zbelt, zroof, ws_run, bk_run, paint, door_seams, glass_b, pillar_b=None, back_glass=True):
    """ห้องโดยสารแบบแผ่นบาง (มองจากข้างในเห็นผนัง) y0 = ฐานกระจกหน้า, y1 = หลังห้อง"""
    t = 0.22
    Wr = W - 0.45  # ขอบหลังคาหดเข้า
    yr0, yr1 = y0 + ws_run, y1 - bk_run
    # พื้น + ใต้ท้อง
    b.box(-W + t, W - t, y0, y1, zsill, zfloor, "floor_mat", keys={"bottom": "black"})
    # ผนังข้าง (ประตู) ใต้ขอบกระจก
    for sx in (1, -1):
        x0, x1 = (W - t, W) if sx > 0 else (-W, -W + t)
        b.box(x0, x1, y0, y1, zsill, zbelt, paint, keys={"left" if sx > 0 else "right": "interior"})
        for ys in door_seams:  # ร่องประตู
            b.box(x1 - 0.02 if sx > 0 else x0 - 0.03, x1 + 0.03 if sx > 0 else x0 + 0.02, ys - 0.04, ys + 0.04, zsill + 0.2, zbelt - 0.05, "black")
        # มือจับประตู
        for ys in door_seams[1:]:
            b.boxc(sx * (W + 0.03), ys - 0.55, zbelt - 0.45, 0.08, 0.6, 0.14, "chrome")
    # คอนโซลหน้า
    b.box(-W + t, W - t, y0, y0 + 1.0, zbelt - 1.1, zbelt + 0.15, "interior", keys={"top": "black"})
    # เสา A
    for sx in (1, -1):
        b.beam((sx * (W - 0.1), y0, zbelt), (sx * (Wr - 0.05), yr0, zroof), 0.24, 0.3, paint)
    # เสาหลัง (C) + ผนังหลัง
    for sx in (1, -1):
        b.beam((sx * (W - 0.1), y1, zbelt), (sx * (Wr - 0.05), yr1, zroof), 0.3, 0.45 if bk_run > 0.5 else 0.3, paint)
    if pillar_b is not None:
        for sx in (1, -1):
            b.beam((sx * (W - 0.12), pillar_b, zbelt), (sx * (Wr - 0.02), pillar_b + 0.05, zroof), 0.3, 0.25, paint)
    # หลังคาโค้ง (โป่งตรงกลาง ขอบมน)
    secs = []
    for t in (0.0, 0.12, 0.5, 0.88, 1.0):
        y = (yr0 - 0.05) + (yr1 - yr0 + 0.1) * t
        bulge = math.sin(math.pi * t)
        secs.append(oval(y, zroof - 0.2 - 0.1 * (1 - bulge), Wr * (0.94 + 0.06 * bulge), 0.17 + 0.05 * bulge, n=12, p=5))
    b.loft(secs, paint, lambda j, i: "interior" if (j <= 2 or j >= 10) else paint)
    # กระจกหน้า
    glass_b.beam((0, y0 + 0.05, zbelt + 0.05), (0, yr0, zroof - 0.15), (W + Wr) - 0.4, 0.06, "glass")
    # กระจกข้างสีชาเต็มบาน รูปทรงตามเสา A/C (mesh ไม่มี collision ผู้เล่นเดินผ่านประตูได้) + คิ้วขอบหน้าต่างดำ
    zt = zroof - 0.32
    zg = zbelt + 0.06
    yf = lambda z: y0 + (yr0 - y0) * (z - zbelt) / (zt - zbelt) + 0.28  # ขอบหน้าตามเสา A
    yk = lambda z: y1 - (y1 - yr1) * (z - zbelt) / (zt - zbelt) - 0.28  # ขอบหลังตามเสา C
    cuts = [-1e9] + ([pillar_b] if pillar_b is not None else []) + [1e9]
    for sx in (1, -1):
        xg = sx * (W - 0.16)
        for ya, yb in zip(cuts[:-1], cuts[1:]):
            ya2, yb2 = ya + 0.17, yb - 0.17
            poly = [(max(ya2, yf(zg)), zg), (min(yb2, yk(zg)), zg), (min(yb2, yk(zt)), zt), (max(ya2, yf(zt)), zt)]
            if poly[1][0] - poly[0][0] > 0.3:
                glass_b.prism_yz(poly, xg - 0.03, xg + 0.03, "glass")
        b.box(min(sx * (W - 0.02), sx * (W + 0.04)), max(sx * (W - 0.02), sx * (W + 0.04)), y0 + 0.2, y1 - 0.1, zbelt - 0.05, zbelt + 0.08, "black")
        # ขอบบนหน้าต่าง (รางน้ำหลังคา)
        b.beam((sx * (Wr - 0.02), yr0, zroof - 0.28), (sx * (Wr - 0.02), yr1, zroof - 0.28), 0.1, 0.1, "black")
    # กระจกหลัง
    if back_glass:
        glass_b.beam((0, y1 - 0.05, zbelt + 0.2), (0, yr1, zroof - 0.25), (W + Wr) - 0.7, 0.06, "glass")


def bench(b, x0, x1, y0, y1, ztop, key, back_h=2.6, back_tilt=0.4, frame="black"):
    """เบาะนั่ง y0 = ขอบหน้า, y1 = พนักหลัง"""
    b.box(x0, x1, y0, y1, ztop - 0.5, ztop, key)
    b.box(x0 + 0.1, x1 - 0.1, y0 + 0.2, y1 - 0.2, ztop - 1.3, ztop - 0.5, frame)
    b.hexa([(x0, y1 - 0.45, ztop - 0.1), (x1, y1 - 0.45, ztop - 0.1), (x1, y1, ztop - 0.1), (x0, y1, ztop - 0.1),
            (x0, y1 - 0.45 + back_tilt, ztop + back_h), (x1, y1 - 0.45 + back_tilt, ztop + back_h), (x1, y1 + back_tilt, ztop + back_h), (x0, y1 + back_tilt, ztop + back_h)], key)


def steering(b, x, y, z, R=0.75, tilt=55):
    with b.xf(Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(-tilt), 4, "X")):
        b.torus((0, 0, 0), "z", R, 0.08, "black", nu=16, nv=5)
        b.beam((0, 0, 0), (R, 0, 0), 0.12, 0.08, "black")
        b.beam((0, 0, 0), (-R, 0, 0), 0.12, 0.08, "black")
        b.cone((0, 0, 0), (0, 0, -1.2), 0.12, 0.12, "black", n=6)


def mirror_side(b, x, y, z, key="black", arm=0.5):
    sx = 1 if x > 0 else -1
    b.beam((x - sx * arm, y, z - 0.1), (x, y, z), 0.12, 0.12, key)
    b.boxc(x + sx * 0.15, y + 0.05, z + 0.15, 0.55, 0.12, 0.42, key, keys={"back": "chrome"})


# ---------------------------------------------------------------- เปลือกตัวรถแบบต่อเนื่อง (ผิวโค้งต่อกันทั้งคัน แบบรถจริง)
def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def car_shell(body, glass, inner, y0, y1, W, zb, zbelt, zroof, gh, paint, top_key, lower_key=None, pillars=(), seams=(),
              tumble=0.55, crown=0.12, boxy=0.0, step=0.3, extra=(), cap_front=None, cap_rear=None, rear_glass=0.4):
    """เปลือกตัวถังชิ้นเดียวจากหน้าตัด 16 จุดเรียงตามแนวยาว (ผิวโค้งต่อเนื่อง ซุ้มล้อโค้ง ขอบกระจก หลังคาโค้ง)
    W(y) ครึ่งความกว้าง, zb(y) ขอบล่าง (ยกขึ้นเป็นซุ้มล้อ), zbelt(y) ขอบกระจก/ผิวฝากระโปรง-ท้าย, zroof(y) หลังคา
    gh = (a0, a1, b0, b1): กระจกหน้าเอียง a0→a1, หลังคาเรียบ a1→b0, กระจกหลังเอียง b0→b1
    กระจก → builder glass (2 ด้าน), ผิวด้านในห้องโดยสาร → builder inner (มองจากในรถไม่ทะลุ)"""
    ys = set()
    n = int(math.ceil((y1 - y0) / step))
    for i in range(n + 1):
        ys.add(round(y0 + (y1 - y0) * i / n, 4))
    for y in list(gh) + list(extra):
        if y0 < y < y1:
            ys.add(round(y, 4))
    for y in seams:
        for d in (-0.05, 0.05):
            ys.add(round(y + d, 4))
    for y in pillars:
        for d in (-0.24, 0.24):
            ys.add(round(y + d, 4))
    ys = sorted(ys)
    a0, a1, b0, b1 = gh
    rings = []
    for y in ys:
        w, z0, zt = W(y), zb(y), zbelt(y)
        zr = max(zroof(y), zt + 0.06)
        h = zt - z0
        g = zr - zt
        wg = w * (0.965 - 0.015 * boxy)
        wr = wg - tumble * min(1.0, g / 3.0)
        rr = (0.12 + 0.18 * (1 - boxy)) * min(1.0, g / 1.5)
        half = [(0.0, z0), (w * (0.86 + 0.1 * boxy), z0), (w * (0.975 + 0.02 * boxy), z0 + 0.2 * h), (w, z0 + 0.6 * h),
                (w * (0.985 + 0.012 * boxy), zt), (wg, zt + 0.06), (wr, zr - rr), (wr - rr * 1.2, zr), (0.0, zr + crown * min(1.0, g / 2.0))]
        rings.append((y, half + [(-x, z) for x, z in reversed(half[1:-1])]))

    def key_for(j, ym):
        front, rear, flat = a0 < ym < a1, b0 < ym < b1, a1 <= ym <= b0
        cabin = a0 < ym < b1
        if j in (0, 15):
            return "black"
        if j in (1, 2, 3, 4, 11, 12, 13, 14):
            if cabin and j in (2, 3, 12, 13) and any(abs(ym - s0) < 0.06 for s0 in seams):
                return "black"
            return lower_key or paint
        if j in (5, 10):
            if any(abs(ym - p0) < 0.25 for p0 in pillars):
                return "black"
            # กระจกข้างยาวตามเสา A ลงไปจรดฐานกระจกหน้า ส่วนท้ายเหลือเสา C หนา (60% หลังของช่วงกระจกหลัง)
            if flat or front or (rear and ym < b0 + rear_glass * (b1 - b0)):
                return "GLASS"
            return paint if cabin else top_key
        if front or rear:
            return "GLASS" if j in (7, 8) else paint
        return paint if flat else top_key

    cache = {}

    def vid(bld, i, j, tag=""):
        k = (id(bld), i, j, tag)
        if k not in cache:
            y, ring = rings[i]
            x, z = ring[j % 16]
            cache[k] = bld._v((x, y, z))
        return cache[k]

    for i in range(len(rings) - 1):
        ym = (rings[i][0] + rings[i + 1][0]) / 2
        for j in range(16):
            key = key_for(j, ym)
            if key == "GLASS":
                # 2 ด้าน: ด้านนอก + ด้านใน (จุดแยกกัน ไม่ให้ normal กลับด้าน)
                glass.face([vid(glass, i + 1, j), vid(glass, i + 1, j + 1), vid(glass, i, j + 1), vid(glass, i, j)], "glass")
                glass.face([vid(glass, i, j, "in"), vid(glass, i, j + 1, "in"), vid(glass, i + 1, j + 1, "in"), vid(glass, i + 1, j, "in")], "glass")
                continue
            body.face([vid(body, i + 1, j), vid(body, i + 1, j + 1), vid(body, i, j + 1), vid(body, i, j)], key)
            # ผิวด้านในห้องโดยสาร (แผงประตู + เพดาน)
            if inner is not None and a0 <= ym <= b1 and j in (3, 4, 6, 7, 8, 9, 11, 12):
                inner.face([vid(inner, i, j), vid(inner, i, j + 1), vid(inner, i + 1, j + 1), vid(inner, i + 1, j)], "interior")
    body.face([vid(body, 0, j) for j in range(16)], cap_front or lower_key or paint)
    body.face([vid(body, len(rings) - 1, j) for j in reversed(range(16))], cap_rear or lower_key or paint)
    return rings


def shell_x(rings, y, z):
    """ความกว้างของเปลือก ณ (y, z) ด้านขวา (ไว้วางไฟ/ป้ายให้แนบผิว)"""
    best = min(rings, key=lambda r: abs(r[0] - y))[1]
    pts = best[:9]
    for (xa, za), (xb, zb_) in zip(pts[:-1], pts[1:]):
        if min(za, zb_) <= z <= max(za, zb_) and abs(zb_ - za) > 1e-6:
            return xa + (xb - xa) * (z - za) / (zb_ - za)
    return max(x for x, _ in pts)


def shell_interior(b, y0, y1, W, zsill, zfloor, zdash, key_floor="floor_mat"):
    b.box(-W + 0.3, W - 0.3, y0, y1, zsill + 0.1, zfloor, key_floor, keys={"bottom": "black"})
    b.box(-W + 0.35, W - 0.35, y0, y0 + 1.1, zdash - 1.0, zdash + 0.1, "interior", keys={"top": "black"})


# ---------------------------------------------------------------- 1) กระบะเก่าโทรม (Toyota Hilux Hero ยุค 90)
def make_pickup():
    P = "ThaiPickupOld"
    body, glass = B(P), B(P + "_Glass")
    wheels = {}
    Rw, Ww, TR = 1.62, 1.15, 3.0  # ล้อใหญ่ขึ้นตามภาพ ref
    YF, YR = -6.3, 5.6
    W = 3.8
    zs, zf, zb, zr = 1.2, 2.15, 4.75, 8.85  # ตัวถังลึก ห้องโดยสารสูงตามภาพ ref
    # ---- เปลือกตัวรถต่อเนื่อง (หน้า + ห้องโดยสาร) ทรงเหลี่ยมแบบกระบะยุค 90
    inner = B(P + "_Interior")
    glass.no_recalc = inner.no_recalc = True
    body.worlduv = True
    glass.bevel = inner.bevel = False
    y0s, y1s = -10.45, 1.55

    def Wf(y):
        return W - 0.3 * ease((y0s + 0.6 - y) / 0.6)

    def zbf_(y):
        z = zs + 0.3 * ease((y0s + 0.5 - y) / 0.5)
        d = abs(y - YF)
        if d < 1.9:
            z = max(z, Rw + math.sqrt(1.9 ** 2 - d * d) * 0.97)
        return z

    def hood_top(y):
        return 4.25 + 0.4 * ease((y - y0s) / 6.9) if y < -3.45 else zb

    def zroof_(y):
        if -3.45 < y < -2.05:
            return zb + (zr - zb) * ease((y + 3.45) / 1.4) ** 0.8
        return zr if y >= -2.05 else 0.0

    car_shell(body, glass, inner, y0s, y1s, Wf, zbf_, hood_top, zroof_, (-3.45, -2.05, 1.6, 1.7), "pk_paint", "pk_paint_top",
              seams=(-3.2, 1.3), tumble=0.3, crown=0.07, boxy=0.8, step=0.32)
    shell_interior(body, -3.45, y1s, W, zs, zf, 4.6)
    glass.box(-2.7, 2.7, y1s - 0.04, y1s + 0.05, 5.5, 8.2, "glass")  # กระจกหลังห้องคนขับ
    # ร่องฝากระโปรง (ปิดอยู่)
    for sx in (1, -1):
        body.beam((sx * 3.45, -10.1, hood_top(-10.1) + 0.02), (sx * 3.45, -3.6, hood_top(-3.6) + 0.02), 0.06, 0.04, "black")
    body.beam((-3.45, -3.6, hood_top(-3.6) + 0.02), (3.45, -3.6, hood_top(-3.6) + 0.02), 0.06, 0.04, "black")
    # กระจังหน้า ไฟหน้า ไฟเลี้ยว กันชน
    body.box(-1.95, 1.95, -10.6, -10.4, 2.55, 3.8, "grille")
    for zz in (2.9, 3.3):
        body.box(-1.95, 1.95, -10.66, -10.58, zz - 0.05, zz + 0.05, "chrome")
    for sx in (1, -1):
        body.box(min(sx * 2.0, sx * 3.25), max(sx * 2.0, sx * 3.25), -10.62, -10.42, 2.95, 3.75, "lens_white")
        body.box(min(sx * 2.0, sx * 3.25), max(sx * 2.0, sx * 3.25), -10.6, -10.42, 2.6, 2.85, "lens_amber")
    body.box(-3.9, 3.9, -10.95, -10.4, 1.3, 2.45, "rust", keys={"top": "chrome"})
    LIGHT(P, "head", 2.62, -10.66, 3.35, 1.2, 0.7)
    LIGHT(P, "head", -2.62, -10.66, 3.35, 1.2, 0.7)
    for sx in (1, -1):  # แถบสีซีดยาวตลอดข้างรถ
        body.box(min(sx * 3.79, sx * 3.84), max(sx * 3.79, sx * 3.84), -9.6, 1.5, 3.45, 3.7, "pk_stripe")
        body.box(min(sx * 3.81, sx * 3.86), max(sx * 3.81, sx * 3.86), 1.9, 9.85, 3.45, 3.7, "pk_stripe")
    for sx in (1, -1):  # แถบขาวเฉียงที่ประตูคนขับ/คนนั่ง
        xs = sx * (W + 0.03)
        body.hexa([(xs - 0.02, -1.4, 3.75), (xs + 0.02, -1.4, 3.75), (xs + 0.02, 0.2, 4.7), (xs - 0.02, 0.2, 4.7),
                   (xs - 0.02, -1.0, 3.75), (xs + 0.02, -1.0, 3.75), (xs + 0.02, 0.9, 4.7), (xs - 0.02, 0.9, 4.7)], "pk_stripe2")
    # ---- ห้องโดยสาร
    bench(body, -3.35, 3.35, -0.8, 1.15, 3.55, "seat_vinyl", back_h=2.7, back_tilt=0.3)
    steering(body, -1.65, -2.05, 5.2)
    body.box(-3.5, 3.5, -3.45, -2.4, 2.15, 3.2, "floor_mat")
    for sx in (1, -1):
        mirror_side(body, sx * (W + 0.55), -3.0, 5.5)
    SEAT(P, "DriverSeat", "VehicleSeat", -1.65, 0.2, 3.55, 2.2, 1.9)
    SEAT(P, "PassengerSeat", "Seat", 1.6, 0.2, 3.55, 2.2, 1.9)
    # ---- กระบะท้าย
    yb0, yb1, zbf = 1.8, 10.0, 3.7
    body.box(-3.55, 3.55, yb0, yb1, zbf - 0.4, zbf, "rust", keys={"top": "pk_paint_top"})
    for sx in (1, -1):
        def sb(y0, y1, z0, z1, key="pk_paint"):
            x0, x1 = (3.5, 3.82) if sx > 0 else (-3.82, -3.5)
            body.box(x0, x1, y0, y1, z0, z1, key, keys={"top": "rust"})
        sb(yb0, YR - 2.0, 1.3, 4.95)
        sb(YR + 2.0, yb1, 1.3, 4.95)
        sb(YR - 2.0, YR + 2.0, 3.65, 4.95)
        # ซุ้มล้อหลังโค้ง (ขอบ)
        fx = sx * 3.84
        for k in range(8):
            a0_, a1_ = math.pi * k / 8, math.pi * (k + 1) / 8
            body.beam((fx, YR - 1.95 * math.cos(a0_), Rw + 1.95 * math.sin(a0_) * 1.05), (fx, YR - 1.95 * math.cos(a1_), Rw + 1.95 * math.sin(a1_) * 1.05), 0.12, 0.18, "rust")
        body.box(min(sx * 2.5, sx * 3.5), max(sx * 2.5, sx * 3.5), YR - 1.6, YR + 1.6, zbf, zbf + 0.85, "pk_paint_top")  # ซุ้มล้อในกระบะ
        # ไฟท้าย
        body.box(min(sx * 3.0, sx * 3.84), max(sx * 3.0, sx * 3.84), yb1 - 0.02, yb1 + 0.12, 3.2, 4.6, "lens_red")
        LIGHT(P, "tail", sx * 3.4, yb1 + 0.14, 4.0, 0.7, 1.4)
    body.box(-3.55, 3.55, yb1 - 0.3, yb1, 1.6, 4.8, "pk_paint", keys={"front": "rust"})  # ฝาท้าย
    body.box(-3.9, 3.9, yb1, yb1 + 0.65, 1.55, 2.25, "rust", keys={"top": "steel"})  # กันชนหลัง (ขั้นเหยียบ)
    PLATE(P, 0, yb1 + 0.68, 1.9, False, w=1.7, h=0.85, text="บจ 4512")
    PLATE(P, 0, -10.97, 1.85, True, w=1.7, h=0.85, text="บจ 4512")
    # คอกเหล็ก
    zc = [4.95, 6.5, 8.05, 9.55]
    for sx in (1, -1):
        x = sx * 3.66
        for y in (yb0 + 0.15, 4.0, 6.0, 8.0, yb1 - 0.15):
            body.box(x - 0.09, x + 0.09, y - 0.09, y + 0.09, 4.9, 9.6, "cage_rust")
        for z in zc[1:]:
            body.box(x - 0.08, x + 0.08, yb0 + 0.1, yb1 - 0.1, z - 0.08, z + 0.08, "cage_rust")
        for y0_ in (yb0 + 0.15, 4.0, 6.0, 8.0):
            body.beam((x, y0_, 6.5), (x, y0_ + 2.0 if y0_ < 8 else yb1 - 0.15, 8.05), 0.06, 0.06, "cage_rust")
    for z in zc[1:] + [9.1]:
        body.box(-3.66, 3.66, yb0 + 0.06, yb0 + 0.24, z - 0.08, z + 0.08, "cage_rust")
    body.box(-3.66, 3.66, yb1 - 0.24, yb1 - 0.06, 9.47, 9.63, "cage_rust")
    for x in (-1.2, 1.2):
        body.box(x - 0.08, x + 0.08, yb0 + 0.06, yb0 + 0.24, zr - 0.2, 9.6, "cage_rust")
    # ---- ล้อ
    for n, x, y in (("Wheel_FL", TR, YF), ("Wheel_FR", -TR, YF), ("Wheel_RL", TR, YR), ("Wheel_RR", -TR, YR)):
        wb = B(n)
        car_wheel(wb, x, y, Rw, Rw, Ww, rim="rim_rust")
        wheels[n] = wb
        WHEEL(P, n, x, y, Rw, Rw, Ww, steer=y < 0)
    # ---- กล่องชน / proxy
    COL(P, -3.75, 3.75, -10.9, -3.45, 1.3, 4.65)
    COL(P, -3.75, 3.75, -3.45, 1.55, 1.2, 2.15)
    COL(P, -3.5, 3.5, -3.45, -2.6, 2.15, 4.8)
    COL(P, -3.4, 3.4, -3.45, -2.8, 4.8, 8.5)
    COL(P, -3.4, 3.4, -2.05, 1.55, 8.55, 8.85)
    COL(P, -3.75, 3.75, 1.3, 1.85, 2.15, 8.85)
    COL(P, -3.55, 3.55, yb0, yb1, 3.3, zbf, friction=0.8)
    COL(P, 3.5, 3.82, yb0, yb1, 1.3, 4.95, mirror=True)
    COL(P, 3.57, 3.75, yb0, yb1, 4.95, 9.6, mirror=True)
    COL(P, -3.75, 3.75, yb0, yb0 + 0.3, 8.85, 9.6)
    COL(P, -3.55, 3.55, yb1 - 0.3, yb1, 1.6, 4.8)
    COL(P, -3.9, 3.9, yb1, yb1 + 0.65, 1.3, 2.45, friction=0.8)
    COL(P, -3.5, 3.5, -3.45, yb1, 0.55, 1.2, friction=0)  # กันตัวละครมุดใต้ท้องรถ
    PX(P, "pk_paint", -3.75, 3.75, -10.4, -3.45, 1.2, 4.6)
    PX(P, "grille", -1.95, 1.95, -10.6, -10.4, 2.55, 3.8)
    PX(P, "rust", -3.9, 3.9, -10.95, -10.4, 1.3, 2.45)
    PX(P, "pk_paint", -3.8, 3.8, -3.45, 1.55, 1.2, 2.15)
    PX(P, "pk_paint", 3.58, 3.8, -3.45, 1.55, 2.15, 4.75, mirror=True)
    PX(P, "interior", -3.5, 3.5, -3.45, -2.45, 3.25, 4.5)
    PX(P, "pk_paint", -3.35, 3.35, -2.05, 1.55, 8.6, 8.85)
    PX(P, "pk_paint", -3.8, 3.8, 1.25, 1.55, 2.15, 8.85)
    PX(P, "glass", -3.3, 3.3, -3.45, -2.05, 4.8, 8.6, rx=-1, th=0.1)
    PX(P, "pk_paint", 3.3, 3.6, -3.45, -3.2, 4.75, 8.7, mirror=True)
    PX(P, "seat_vinyl", -3.35, 3.35, -0.8, 1.15, 3.05, 3.55)
    PX(P, "seat_vinyl", -3.35, 3.35, 0.75, 1.15, 3.5, 6.2)
    PX(P, "rust", -3.55, 3.55, yb0, yb1, 3.3, zbf)
    PX(P, "pk_paint", 3.5, 3.82, yb0, yb1, 3.35, 4.95, mirror=True)
    PX(P, "pk_paint", 3.5, 3.82, yb0, YR - 2.0, 1.3, 3.65, mirror=True)
    PX(P, "pk_paint", 3.5, 3.82, YR + 2.0, yb1, 1.3, 3.65, mirror=True)
    PX(P, "pk_paint", -3.55, 3.55, yb1 - 0.3, yb1, 1.6, 4.8)
    PX(P, "rust", -3.9, 3.9, yb1, yb1 + 0.65, 1.3, 2.45)
    PX(P, "cage_rust", 3.57, 3.75, yb0, yb1, 9.45, 9.65, mirror=True)
    PX(P, "cage_rust", 3.57, 3.75, yb0, yb1, 7.97, 8.13, mirror=True)
    PX(P, "cage_rust", 3.57, 3.75, yb0, yb1, 6.42, 6.58, mirror=True)
    for y in (yb0 + 0.15, 4.0, 6.0, 8.0, yb1 - 0.15):
        PX(P, "cage_rust", 3.57, 3.75, y - 0.09, y + 0.09, 4.9, 9.6, mirror=True)
    PX(P, "cage_rust", -3.66, 3.66, yb0 + 0.06, yb0 + 0.24, 9.45, 9.65)
    PX(P, "cage_rust", -3.66, 3.66, yb1 - 0.24, yb1 - 0.06, 9.47, 9.63)
    return P, [body, glass, inner] + list(wheels.values())


# ---------------------------------------------------------------- 2) เก๋งบรอนซ์ทอง (Toyota Soluna ยุค 90)
def make_sedan():
    P = "ThaiSedanSoluna"
    body, glass, inner = B(P), B(P + "_Glass"), B(P + "_Interior")
    glass.no_recalc = inner.no_recalc = True
    body.worlduv = True
    inner.bevel = glass.bevel = False
    body.bevel = False  # เปลือกโค้งต่อเนื่องอยู่แล้ว
    Rw, Ww, TR = 1.3, 1.0, 2.95
    YF, YR = -6.0, 5.6
    W0 = 3.6
    y0, y1 = -10.25, 9.95
    zs, zf = 1.25, 1.75

    def W(y):  # หน้า/ท้ายมนลงตามแบบรถเก๋งยุค 90
        return W0 - 0.5 * ease((y0 + 1.6 - y) / 1.6) ** 1.5 - 0.42 * ease((y - (y1 - 1.3)) / 1.3) ** 1.5

    def zb(y):
        z = zs + 0.25 * ease((y0 + 1.0 - y) / 1.0) + 0.3 * ease((y - (y1 - 0.9)) / 0.9)
        for yw in (YF, YR):
            d = abs(y - yw)
            if d < 1.55:
                z = max(z, Rw + math.sqrt(1.55 ** 2 - d * d))
        return z

    def zbelt(y):
        if y < -3.3:  # ฝากระโปรงลาดลงหาจมูก
            return 3.35 + 0.83 * math.sin(0.5 * math.pi * ease((y - y0) / (-3.3 - y0)) ** 0.8)
        if y > 4.4:  # ฝาท้ายสั้น ปลายโค้งลง
            return 4.22 - 0.5 * ease((y - 8.7) / (y1 - 8.7)) ** 2
        return 4.2

    def zroof(y):
        if -3.3 < y < -1.1:
            return 4.2 + (7.05 - 4.2) * ease((y + 3.3) / 2.2) ** 0.75
        if -1.1 <= y <= 2.75:
            return 7.05
        if 2.75 < y < 4.4:
            return 7.05 - (7.05 - 4.22) * ease((y - 2.75) / 1.65) ** 1.3
        return 0.0

    rings = car_shell(body, glass, inner, y0, y1, W, zb, zbelt, zroof, (-3.3, -1.1, 2.75, 4.4), "sd_paint", "sd_paint",
                      pillars=(0.85,), seams=(-3.1, 0.85, 3.85), tumble=0.65, crown=0.14)
    shell_interior(body, -3.3, 4.2, W0, zs, zf, 4.1)
    # คิ้วข้าง มือจับประตู กระจกมองข้าง
    for sx in (1, -1):
        xw = W0 + 0.02
        body.box(min(sx * xw, sx * (xw + 0.06)), max(sx * xw, sx * (xw + 0.06)), -2.9, 3.6, 2.55, 2.75, "sd_trim")
        for yd in (-0.1, 3.4):
            body.boxc(sx * (xw + 0.03), yd, 3.85, 0.08, 0.55, 0.13, "chrome")
        mirror_side(body, sx * (W0 + 0.35), -2.85, 4.5, key="sd_paint", arm=0.3)
    # หน้ารถ: ไฟหน้าโค้งรับมุม + กระจังคาดโครเมียม + โลโก้ + ช่องลมกันชน + ไฟเลี้ยว
    yf = y0 - 0.02
    for sx in (1, -1):
        xi, xo = sx * 1.45, sx * shell_x(rings, y0 + 0.3, 2.8) * 0.97
        body.hexa([(xi, yf - 0.02, 2.48), (xo, yf + 0.45, 2.52), (xo, yf + 0.8, 2.52), (xi, yf + 0.3, 2.48),
                   (xi, yf - 0.02, 3.0), (xo, yf + 0.45, 3.12), (xo, yf + 0.8, 3.12), (xi, yf + 0.3, 3.0)], "lens_white")
        body.hexa([(xo, yf + 0.5, 2.52), (xo * 1.02, yf + 1.2, 2.55), (xo * 1.02, yf + 1.45, 2.55), (xo, yf + 0.8, 2.52),
                   (xo, yf + 0.5, 2.9), (xo * 1.02, yf + 1.2, 2.9), (xo * 1.02, yf + 1.45, 2.9), (xo, yf + 0.8, 2.9)], "lens_amber")
        LIGHT(P, "head", sx * 2.2, yf - 0.06, 2.78, 1.4, 0.45)
        body.boxc(sx * 2.4, yf - 0.03, 1.85, 0.5, 0.08, 0.2, "lens_amber")
    body.box(-1.4, 1.4, yf - 0.06, yf + 0.1, 2.5, 2.95, "black")
    for zz in (2.6, 2.73, 2.86):
        body.box(-1.38, 1.38, yf - 0.1, yf - 0.04, zz - 0.025, zz + 0.025, "chrome")
    body.ellipsoid((0, yf - 0.1, 2.73), (0.26, 0.04, 0.17), "chrome", nu=12, nv=4)
    body.box(-1.7, 1.7, yf - 0.05, yf + 0.1, 1.62, 2.05, "grille")
    body.box(-3.0, 3.0, yf - 0.06, yf + 0.08, 2.22, 2.3, "sd_trim")
    PLATE(P, 0, yf - 0.12, 1.85, True, w=1.5, h=0.75, text="ฆธ 186")
    # ท้ายรถ: ไฟท้ายแดงอ้อมข้าง + คาดโครเมียม
    yr = y1 + 0.02
    for sx in (1, -1):
        xi, xo = sx * 1.15, sx * shell_x(rings, y1 - 0.3, 3.2) * 0.97
        body.hexa([(xi, yr + 0.02, 2.95), (xo, yr - 0.35, 2.95), (xo, yr - 0.75, 2.95), (xi, yr - 0.3, 2.95),
                   (xi, yr + 0.02, 3.55), (xo, yr - 0.35, 3.6), (xo, yr - 0.75, 3.6), (xi, yr - 0.3, 3.55)], "lens_red")
        LIGHT(P, "tail", sx * 2.2, yr + 0.06, 3.25, 1.5, 0.5)
    body.box(-1.15, 1.15, yr - 0.1, yr + 0.04, 3.2, 3.3, "chrome")
    body.box(-3.0, 3.0, yr - 0.08, yr + 0.06, 2.35, 2.45, "sd_trim")
    PLATE(P, 0, yr + 0.08, 2.75, False, w=1.5, h=0.75, text="ฆธ 186")
    # เบาะ พวงมาลัย
    for sx in (1, -1):
        bench(body, min(sx * 0.35, sx * 3.0), max(sx * 0.35, sx * 3.0), -1.8, 0.1, 2.6, "seat_cloth", back_h=2.6, back_tilt=0.35)
    bench(body, -3.1, 3.1, 1.3, 3.15, 2.6, "seat_cloth", back_h=2.3, back_tilt=0.4)
    body.box(-3.2, 3.2, 3.6, 4.15, 3.85, 4.15, "interior")
    steering(body, -1.6, -2.55, 4.15, R=0.7)
    SEAT(P, "DriverSeat", "VehicleSeat", -1.6, -0.85, 2.6, 2.2, 1.9)
    SEAT(P, "PassengerSeat", "Seat", 1.6, -0.85, 2.6, 2.2, 1.9)
    SEAT(P, "RearSeatL", "Seat", 1.55, 2.1, 2.6, 2.2, 1.8)
    SEAT(P, "RearSeatR", "Seat", -1.55, 2.1, 2.6, 2.2, 1.8)
    wheels = []
    for n, x, y in (("Wheel_FL", TR, YF), ("Wheel_FR", -TR, YF), ("Wheel_RL", TR, YR), ("Wheel_RR", -TR, YR)):
        wb = B(n)
        car_wheel(wb, x, y, Rw, Rw, Ww, rim="bk_silver", lug=False)
        sg = 1 if x > 0 else -1
        xo = x + sg * (Ww / 2 + 0.1)
        wb.torus((xo, y, Rw), "x", Rw * 0.62, 0.06, "bk_silver", nu=24, nv=4)
        wb.disc_x((xo, y, Rw), 0.22, 0.12, "bk_silver", n=10)
        for j in range(5):
            ang = 2 * math.pi * j / 5 + 0.3
            for d in (-0.13, 0.13):
                a2 = ang + d
                wb.beam((xo, y + 0.2 * math.cos(ang), Rw + 0.2 * math.sin(ang)), (xo - sg * 0.04, y + Rw * 0.6 * math.cos(a2), Rw + Rw * 0.6 * math.sin(a2)),
                        0.1, 0.1, "bk_silver", side=(0, -math.sin(ang), math.cos(ang)))
        wheels.append(wb)
        WHEEL(P, n, x, y, Rw, Rw, Ww, steer=y < 0)
    COL(P, -3.6, 3.6, y0, -3.3, 1.3, 4.2)
    COL(P, -3.6, 3.6, -3.3, 4.2, 1.25, 1.75)
    COL(P, -3.4, 3.4, -3.3, -2.3, 1.75, 4.25)
    COL(P, -3.2, 3.2, -3.3, -2.6, 4.25, 6.6)
    COL(P, -3.15, 3.15, -1.0, 2.9, 6.8, 7.05)
    COL(P, -3.6, 3.6, 3.75, y1, 1.3, 4.2)
    COL(P, -3.2, 3.2, 3.6, 4.2, 4.2, 6.4)
    PX(P, "sd_paint", -3.5, 3.5, y0, -3.3, 1.3, 3.9)
    PX(P, "grille", -1.4, 1.4, y0 - 0.06, y0 + 0.1, 2.5, 2.95)
    PX(P, "lens_white", 1.45, 3.1, y0 - 0.06, y0 + 0.4, 2.5, 3.1, mirror=True)
    PX(P, "sd_paint", -3.6, 3.6, -3.3, 4.2, 1.25, 1.75)
    PX(P, "sd_paint", 3.38, 3.6, -3.3, 4.2, 1.75, 4.2, mirror=True)
    PX(P, "sd_paint", -3.6, 3.6, 4.2, y1, 1.3, 4.2)
    PX(P, "lens_red", 1.15, 3.2, y1 - 0.6, y1, 2.95, 3.6, mirror=True)
    PX(P, "sd_paint", -3.0, 3.0, -0.75, 2.75, 6.8, 7.05)
    PX(P, "glass", -3.0, 3.0, -3.3, -0.75, 4.2, 6.95, rx=-1, th=0.1)
    PX(P, "glass", -2.9, 2.9, 2.75, 4.4, 4.2, 6.9, rx=1, th=0.1)
    PX(P, "glass", 3.0, 3.3, -0.6, 2.6, 4.3, 6.6, mirror=True)
    PX(P, "sd_paint", 3.0, 3.5, 0.6, 1.1, 4.2, 6.9, mirror=True)
    PX(P, "seat_cloth", 0.35, 3.0, -1.8, 0.1, 2.1, 2.6, mirror=True)
    PX(P, "seat_cloth", 0.35, 3.0, -0.2, 0.1, 2.6, 5.2, mirror=True)
    PX(P, "seat_cloth", -3.1, 3.1, 1.3, 3.15, 2.1, 2.6)
    PX(P, "seat_cloth", -3.1, 3.1, 2.8, 3.15, 2.6, 4.9)
    return P, [body, glass, inner] + wheels


# ---------------------------------------------------------------- 3-4) จักรยานแม่บ้าน
def make_bicycle(P, paint, blue):
    body = B(P)
    body.bw, body.sa = 0.008, 60
    R = 1.2
    YF, YR, ZH = -2.35, 2.2, R
    BB = (0.15, 0.95)
    seat_top = (1.0, 3.25)
    head_top, head_bot = (-1.72, 3.55), (-1.9, 2.95)
    # โครง: ท่อล่างคู่แบบเฟรมผู้หญิง (โค้ง) + ท่อนั่ง + ตะเกียบหลัง
    body.tube([(0, head_top[0], head_top[1] - 0.15), (0, -1.3, 2.7), (0, -0.55, 1.55), (0, BB[0] - 0.05, BB[1] + 0.12)], 0.11, paint, n=8)
    if blue:
        body.tube([(0, head_bot[0], head_bot[1] + 0.1), (0, -1.1, 1.95), (0, BB[0] - 0.15, BB[1] + 0.05)], 0.12, paint, n=8)
    else:  # เฟรมมิกซ์ท่อคู่วิ่งจากคอไปดุมหลัง
        for sx in (0.09, -0.09):
            body.tube([(sx, head_top[0], head_top[1] - 0.05), (sx, -0.2, 2.75), (sx * 2.2, 1.0, 2.45), (sx * 2.8, YR - 0.05, ZH + 0.1)], 0.055, paint, n=6)
    body.tube([(0, BB[0], BB[1]), (0, seat_top[0], seat_top[1])], 0.1, paint, n=8)
    body.tube([(0, head_bot[0], head_bot[1]), (0, head_top[0], head_top[1])], 0.11, paint, n=8)
    for sx in (0.2, -0.2):
        body.tube([(sx * 0.4, BB[0], BB[1]), (sx, YR - 0.05, ZH)], 0.06, paint, n=6)
        body.tube([(sx * 0.4, seat_top[0], seat_top[1] - 0.2), (sx, YR - 0.05, ZH + 0.05)], 0.055, paint, n=6)
    # หลักอาน + เบาะสปริง
    body.tube([(0, seat_top[0], seat_top[1]), (0, seat_top[0] + 0.08, seat_top[1] + 0.45)], 0.06, "chrome", n=6)
    sy, sz = seat_top[0] + 0.15, seat_top[1] + 0.62
    body.ellipsoid((0, sy, sz), (0.42, 0.62, 0.17), "saddle", nu=12, nv=6)
    body.boxc(0, sy + 0.4, sz, 0.75, 0.3, 0.2, "saddle")
    for sx in (0.25, -0.25):
        body.tube([(sx, sy + 0.4, sz - 0.12), (sx, sy + 0.4, sz - 0.42)], 0.05, "chrome", n=6)
    # ตะเกียบหน้า + คอแฮนด์ + แฮนด์ (ชิ้นแยก Handlebar หมุนเลี้ยวได้)
    hb = B(P + "_Handlebar")
    hb.bw, hb.sa = 0.008, 60
    for sx in (0.2, -0.2):
        hb.tube([(sx * 0.4, head_bot[0], head_bot[1]), (sx, YF + 0.12, ZH + 0.25), (sx, YF, ZH)], 0.055, paint if blue else "chrome", n=6)
    hb.tube([(0, head_top[0], head_top[1]), (0, head_top[0] + 0.05, head_top[1] + 0.55)], 0.06, "chrome", n=6)
    hz = head_top[1] + 0.55
    hb.tube([(-1.05, head_top[0] + 0.55, hz + 0.05), (-0.55, head_top[0] + 0.05, hz), (0.55, head_top[0] + 0.05, hz), (1.05, head_top[0] + 0.55, hz + 0.05)], 0.055, "chrome", n=6)
    for sx in (1, -1):
        hb.tube([(sx * 0.95, head_top[0] + 0.5, hz + 0.05), (sx * 1.2, head_top[0] + 0.72, hz + 0.08)], 0.085, "black" if not blue else "bk_blue", n=6)
    hb.boxc(0.55, head_top[0] + 0.15, hz + 0.05, 0.2, 0.25, 0.2, "steel")  # กระดิ่ง
    # ไฟหน้าดวงเล็ก (ไดนาโม)
    hb.cone((0, head_top[0] - 0.15, head_top[1] - 0.05), (0, head_top[0] - 0.55, head_top[1] - 0.05), 0.2, 0.24, "chrome", n=10)
    LIGHT(P, "head", 0, head_top[0] - 0.58, head_top[1] - 0.05, 0.4, 0.4, round_=True)
    if blue:  # ตะกร้าหน้า
        cy, cz = head_top[0] - 0.95, head_top[1] - 0.15
        hb.box(-0.75, 0.75, cy - 0.55, cy + 0.45, cz - 0.55, cz + 0.4, "basket", keys={"top": "basket"}, skip=("top",))
        hb.box(-0.72, 0.72, cy - 0.52, cy + 0.42, cz - 0.52, cz - 0.48, "black")
        hb.tube([(0, cy, cz - 0.5), (0, YF - 0.05, ZH + 0.15)], 0.04, "black", n=5)
    # บังโคลนโครเมียม
    fender(hb, YF, ZH, R + 0.12, 0.34, "chrome" if not blue else "bk_blue", 35, 150, n=8)
    fender(body, YR, ZH, R + 0.12, 0.34, "chrome" if not blue else "bk_blue", 30, 150, n=8)
    # ตะแกรงหลัง
    rz = 2.95 if not blue else 2.85
    body.box(-0.42, 0.42, 1.35, 3.05, rz - 0.06, rz, "chrome", keys={"top": "chrome"})
    for sx in (0.42, -0.42):
        body.tube([(sx, 1.4, rz - 0.05), (sx * 0.55, YR + 0.05, ZH + 0.05)], 0.04, "chrome", n=5)
        body.tube([(sx, 3.0, rz - 0.05), (sx * 0.55, YR + 0.1, ZH + 0.05)], 0.04, "chrome", n=5)
    if blue:  # เบาะซ้อนท้าย
        body.box(-0.55, 0.55, 1.45, 3.05, rz, rz + 0.32, "saddle")
        # ฝาครอบจานกลม + บังโซ่ (น้ำเงินขอบขาว) + ขาตั้งคู่
        body.disc_x((-0.4, BB[0], BB[1]), 0.44, 0.06, "bk_blue", n=20, key2="bk_blue")
        body.torus((-0.43, BB[0], BB[1]), "x", 0.44, 0.045, "mt_white", nu=20, nv=4)
        body.beam((-0.4, BB[0] + 0.5, BB[1] + 0.32), (-0.4, YR - 0.35, ZH + 0.25), 0.05, 0.3, "bk_blue")
        for sx in (1, -1):
            body.beam((sx * 0.25, 0.9, 0.9), (sx * 0.55, 1.15, 0.0), 0.08, 0.08, "black")
        # สติกเกอร์เหลืองตามท่อล่าง (ตัวอักษรเอียงแบบในภาพ)
        for sx in (0.125, -0.125):
            for k in range(3):
                t0, t1 = 0.12 + k * 0.22, 0.25 + k * 0.22
                pa = (sx, head_bot[0] + (BB[0] - head_bot[0]) * t0, head_bot[1] + (BB[1] + 0.1 - head_bot[1]) * t0)
                pb = (sx, head_bot[0] + (BB[0] - head_bot[0]) * t1, head_bot[1] + (BB[1] + 0.1 - head_bot[1]) * t1)
                body.beam(pa, pb, 0.02, 0.17, "bk_yellow" if k != 1 else "mt_white")
        # ตะแกรงกันกระโปรงเข้าล้อหลัง (ตาข่ายน้ำเงิน) สองข้าง
        arc = [(YR + (R - 0.18) * math.cos(math.radians(a)) * -1, ZH + (R - 0.18) * math.sin(math.radians(a))) for a in range(20, 101, 16)]
        for sx in (1, -1):
            x0 = sx * 0.24
            body.prism_yz([(YR, ZH + 0.12)] + arc, min(x0, x0 + sx * 0.03), max(x0, x0 + sx * 0.03), "bk_guard")
        SEAT(P, "PassengerSeat", "Seat", 0, 2.25, rz + 0.32, 1.8, 1.5, t=1.2)
    else:
        body.beam((0.22, 0.6, 0.9), (0.5, 0.9, 0.0), 0.08, 0.08, "chrome")
        body.beam((-0.38, BB[0] + 0.45, BB[1] + 0.3), (-0.38, YR - 0.3, ZH + 0.22), 0.04, 0.22, "chrome")  # บังโซ่โครเมียมแคบ
    # ไฟท้ายสะท้อนแสง
    body.box(-0.2, 0.2, 3.05, 3.15, rz - 0.4, rz - 0.15, "lens_red")
    LIGHT(P, "tail", 0, 3.17, rz - 0.27, 0.36, 0.22)
    # ใบจาน ขาจาน บันได
    body.disc_x((-0.33, BB[0], BB[1]), 0.48, 0.05, "steel", n=16)
    for sx, a in ((-0.42, 0.3), (0.42, 0.3 + math.pi)):
        e = (sx * 1.05, BB[0] + 0.8 * math.cos(a), BB[1] - 0.8 * math.sin(a))
        body.beam((sx, BB[0], BB[1]), e, 0.12, 0.08, "steel")
        body.boxc(e[0] + (0.25 if sx > 0 else -0.25), e[1], e[2], 0.5, 0.3, 0.12, "rubber")
    body.tube([(-0.33, BB[0] + 0.45, BB[1] + 0.05), (-0.33, YR, ZH + 0.12)], 0.03, "black", n=4)
    body.tube([(-0.33, BB[0] + 0.45, BB[1] - 0.25), (-0.33, YR, ZH - 0.12)], 0.03, "black", n=4)
    wheels = []
    for n, y in (("Wheel_F", YF), ("Wheel_R", YR)):
        wb = B(n)
        wb.bevel, wb.sa = False, 60
        bike_wheel(wb, y, ZH, R, spokes=20, rim="chrome", spoke_keys=("spoke",))
        wheels.append(wb)
        WHEEL(P, n, 0, y, ZH, R, 0.3, steer=y < 0)
    SEAT(P, "DriverSeat", "VehicleSeat", 0, sy + 0.1, sz + 0.17, 1.8, 1.3, t=1.4)
    COL(P, -0.3, 0.3, -2.1, 2.0, 1.1, 2.6)
    PX(P, paint, -0.12, 0.12, head_top[0] - 0.1, BB[0] + 0.1, 1.0, 3.5, rx=1, th=0.22)
    PX(P, paint, -0.1, 0.1, BB[0], seat_top[0] + 0.1, BB[1], seat_top[1], rx=-1, th=0.2)
    PX(P, paint, -0.25, 0.25, BB[0], YR, 1.0, 1.25)
    PX(P, "saddle", -0.42, 0.42, sy - 0.6, sy + 0.6, sz - 0.15, sz + 0.17)
    PX(P, "chrome", -0.42, 0.42, 1.35, 3.05, rz - 0.08, rz)
    PX(P, "chrome", -1.1, 1.1, head_top[0] + 0.0, head_top[0] + 0.15, hz - 0.06, hz + 0.06)
    PX(P, "chrome", -0.05, 0.05, head_top[0] - 0.05, head_top[0] + 0.05, head_bot[1], hz)
    PX(P, paint if blue else "chrome", -0.22, 0.22, YF - 0.05, YF + 0.05, ZH, head_bot[1], rx=-1, th=0.12)
    if blue:
        PX(P, "basket", -0.75, 0.75, head_top[0] - 1.5, head_top[0] - 0.5, head_top[1] - 0.7, head_top[1] + 0.25)
        PX(P, "saddle", -0.55, 0.55, 1.45, 3.05, rz, rz + 0.32)
    return P, [body, hb] + wheels


def make_red_bike():
    return make_bicycle("ThaiBicycleRed", "bk_red", False)


def make_blue_bike():
    return make_bicycle("ThaiBicycleBlue", "bk_blue", True)


# ---------------------------------------------------------------- 5) ตุ๊กตุ๊ก
def make_tuktuk():
    P = "ThaiTukTuk"
    body, glass = B(P), B(P + "_Glass")
    R = 1.0
    YF, YR, TR = -4.7, 2.9, 2.15
    zfl = 1.65
    W = 2.4
    # พื้นห้องโดยสาร (แผ่นเหล็กลาย) + กระโปรงล่าง
    body.box(-W, W, -2.9, 4.0, zfl - 0.4, zfl, "tt_blue", keys={"top": "floor_tread", "bottom": "black"})
    # หน้ารถทรงหัวเรือ (สีน้ำเงิน) ครอบล้อหน้า + บังลม
    secs = [oval(-6.12, 3.35, 0.5, 0.5), oval(-5.92, 3.25, 0.98, 0.95), oval(-5.2, 3.32, 1.2, 1.05), oval(-4.2, 3.22, 1.42, 1.2),
            oval(-3.4, 3.08, 1.6, 1.38), oval(-2.85, 2.98, 1.72, 1.55)]
    body.loft(secs, "tt_blue", lambda j, i: "tt_red" if j in (0, 1, 2, 17, 18, 19) else ("chrome" if j in (5, 15) and i > 0 else "tt_blue"))
    fender(body, YF, R, R + 0.15, 0.7, "tt_blue", -10, 190, th=0.1)
    for sx in (1, -1):
        body.cone((sx * 0.62, -5.75, 3.2), (sx * 0.62, -6.15, 3.2), 0.4, 0.42, "chrome", n=16)
        body.cone((sx * 0.62, -6.15, 3.2), (sx * 0.62, -6.22, 3.2), 0.36, 0.3, "lens_white", n=16)
        LIGHT(P, "head", sx * 0.62, -6.26, 3.2, 0.62, 0.62, round_=True)
        body.boxc(sx * 1.25, -5.35, 3.1, 0.3, 0.3, 0.25, "lens_amber")
    body.boxc(0, -6.0, 2.6, 0.9, 0.12, 0.45, "plate")
    # แฮนด์บังคับ + กระจกหน้า + หลังคาหน้า
    hb = B(P + "_Handlebar")
    hb.tube([(0, -3.5, 3.6), (0, -3.15, 4.75)], 0.1, "chrome", n=6)
    hb.tube([(-1.1, -2.75, 4.95), (-0.5, -3.1, 4.8), (0.5, -3.1, 4.8), (1.1, -2.75, 4.95)], 0.07, "chrome", n=6)
    for sx in (1, -1):
        hb.tube([(sx * 1.0, -2.8, 4.93), (sx * 1.3, -2.6, 4.98)], 0.1, "rubber", n=6)
    for sx in (0.32, -0.32):  # ตะเกียบหน้าแดง + กระบอกโช้คโครเมียม (ตามภาพ)
        hb.tube([(sx * 0.4, -4.3, 2.4), (sx, YF + 0.15, R + 0.45), (sx, YF, R)], 0.1, "tt_red", n=8)
        hb.cone((sx, YF + 0.2, R + 0.35), (sx, YF + 0.05, R + 0.05), 0.07, 0.07, "chrome", n=6)
    glass.beam((0, -3.25, 4.5), (0, -3.15, 7.6), 2.9, 0.06, "glass_clear")
    # กรอบกระจกหน้าสีแดง + ป้ายเล็กใต้กระจก
    for z0_, z1_ in ((4.4, 4.62), (7.5, 7.72)):
        body.box(-1.55, 1.55, -3.32, -3.12, z0_, z1_, "tt_red")
    body.box(-0.85, 0.85, -3.36, -3.3, 4.65, 5.2, "sign_yellow")
    for sx in (1, -1):
        body.beam((sx * 1.6, -3.3, 4.4), (sx * 1.6, -3.2, 7.95), 0.14, 0.14, "chrome")
        mirror_side(body, sx * 2.0, -3.3, 5.6, key="chrome", arm=0.35)
    # เบาะคนขับ (อานยาวสีน้ำเงิน)
    body.box(-1.15, 1.15, -2.4, -0.95, 2.6, 3.15, "tt_seat")
    body.box(-0.9, 0.9, -2.3, -1.05, zfl, 2.6, "black")
    body.box(-1.15, 1.15, -0.95, -0.7, 3.15, 4.4, "tt_seat")
    SEAT(P, "DriverSeat", "VehicleSeat", 0, -1.7, 3.15, 2.1, 1.4)
    # ห้องโดยสารหลัง: ข้างล่างสีแดง ขอบน้ำเงิน แผงหลังน้ำเงิน เบาะยาวน้ำเงิน
    for sx in (1, -1):
        x0, x1 = (W - 0.18, W) if sx > 0 else (-W, -W + 0.18)
        body.box(x0, x1, 1.9, 4.0, zfl, 3.75, "tt_red", keys={"top": "tt_blue"})
        body.box(x0, x1, -2.9, 1.9, zfl - 0.4, zfl + 0.35, "tt_red")
        body.box(min(sx * (W - 0.1), sx * (W + 0.05)), max(sx * (W - 0.1), sx * (W + 0.05)), 1.9, 4.0, 3.75, 3.95, "chrome")
    body.box(-W, W, 3.8, 4.05, zfl, 5.4, "tt_blue", keys={"front": "tt_red"})
    bench(body, -W + 0.2, W - 0.2, 1.95, 3.75, 2.75, "tt_seat", back_h=2.4, back_tilt=0.15, frame="tt_blue")
    SEAT(P, "PassengerSeatL", "Seat", 1.05, 2.7, 2.75, 1.9, 1.7)
    SEAT(P, "PassengerSeatR", "Seat", -1.05, 2.7, 2.75, 1.9, 1.7)
    # เสาหลังคา + หลังคาผ้าใบดำ + ป้าย TAXI
    for sx in (1, -1):
        for y in (-0.75, 3.85):
            body.box(sx * (W - 0.05) - 0.08, sx * (W - 0.05) + 0.08, y - 0.08, y + 0.08, zfl, 8.05, "chrome")
    secs = []
    for y, z in ((-3.75, 7.75), (-3.45, 8.2), (-3.0, 8.35), (3.9, 8.35), (4.15, 8.1)):
        secs.append(rsec(y, W + 0.12, W + 0.05, z - 0.3 if y > -3.6 else z - 0.15, z + 0.15, 0.05, 0.25))
    body.loft(secs, "tt_roof")
    body.box(-W - 0.1, W + 0.1, -3.5, 4.1, 7.95, 8.05, "tt_red")  # ระบายขอบหลังคา
    body.box(-0.95, 0.95, -2.95, -2.65, 8.45, 9.35, "tt_red", keys={"front": "sign_yellow", "back": "sign_yellow"})
    body.box(-0.15, 0.15, -2.85, -2.75, 8.25, 8.5, "chrome")
    rig(P)["signs"].append(dict(c=r_pt((0, -2.98, 8.9)), s=[1.75, 0.75, 0.04], front=1, t="TAXI"))
    rig(P)["signs"].append(dict(c=r_pt((0, -2.62, 8.9)), s=[1.75, 0.75, 0.04], front=0, t="TAXI"))
    # ท้ายรถ: เครื่องยนต์ ท่อไอเสีย ไฟท้าย ป้ายทะเบียน
    body.box(-1.4, 1.4, 2.0, 4.0, 0.75, zfl - 0.4, "engine")
    body.cone((-1.6, 3.6, 0.85), (-1.6, 4.6, 0.95), 0.16, 0.16, "chrome", n=8)
    for sx in (1, -1):
        body.box(min(sx * 1.4, sx * 2.2), max(sx * 1.4, sx * 2.2), 4.05, 4.15, 4.4, 5.0, "lens_red")
        LIGHT(P, "tail", sx * 1.8, 4.16, 4.7, 0.8, 0.6)
    PLATE(P, 0, 4.1, 2.5, False, w=1.4, h=0.7, text="1กข 245", prov="กรุงเทพมหานคร")
    # ล้อ
    wheels = []
    for n, x, y in (("Wheel_F", 0, YF), ("Wheel_RL", TR, YR), ("Wheel_RR", -TR, YR)):
        wb = B(n)
        car_wheel(wb, x if x != 0 else 0.0001, y, R, R, 0.7, rim="chrome", lug=x != 0)
        wheels.append(wb)
        WHEEL(P, n, x, y, R, R, 0.7, steer=y < 0)
    for sx in (1, -1):
        body.box(min(sx * 1.75, sx * 2.55), max(sx * 1.75, sx * 2.55), YR - 1.15, YR + 1.15, 2.2, 2.35, "tt_blue")  # บังโคลนหลัง
    COL(P, -1.3, 1.3, -6.1, -2.85, 1.4, 4.5)
    COL(P, -W, W, -2.9, 4.05, 1.25, zfl, friction=0.8)
    COL(P, W - 0.18, W, 1.9, 4.0, zfl, 3.95, mirror=True)
    COL(P, -W, W, 3.8, 4.05, zfl, 5.4)
    COL(P, -W - 0.1, W + 0.1, -3.5, 4.1, 7.95, 8.5)
    PX(P, "tt_blue", -1.2, 1.2, -6.0, -2.85, 1.6, 4.4)
    PX(P, "tt_blue", -W, W, -2.9, 4.0, zfl - 0.4, zfl)
    PX(P, "tt_red", W - 0.18, W, 1.9, 4.0, zfl, 3.75, mirror=True)
    PX(P, "tt_blue", -W, W, 3.8, 4.05, zfl, 5.4)
    PX(P, "tt_seat", -W + 0.2, W - 0.2, 1.95, 3.75, 2.25, 2.75)
    PX(P, "tt_seat", -W + 0.2, W - 0.2, 3.3, 3.75, 2.75, 5.1)
    PX(P, "tt_seat", -1.15, 1.15, -2.4, -0.95, 2.6, 3.15)
    PX(P, "tt_roof", -W - 0.12, W + 0.12, -3.5, 4.1, 8.0, 8.5)
    PX(P, "tt_red", -0.95, 0.95, -2.95, -2.65, 8.45, 9.35)
    PX(P, "glass", -1.45, 1.45, -3.3, -3.2, 4.5, 7.6)
    for y in (-0.75, 3.85):
        PX(P, "chrome", W - 0.13, W + 0.03, y - 0.08, y + 0.08, zfl, 8.05, mirror=True)
    PX(P, "chrome", 1.53, 1.67, -3.35, -3.2, 4.4, 7.95, mirror=True)
    PX(P, "chrome", -1.1, 1.1, -3.0, -2.85, 4.75, 4.95)
    return P, [body, glass, hb] + wheels


# ---------------------------------------------------------------- 6) มอเตอร์ไซค์ซิ่ง (Wave/Dream แต่ง)
def oval(y, zc, hw, hh, n=20, p=2.6, x0=0.0):
    """หน้าตัดทรงรีเหลี่ยมมน (superellipse) ศูนย์กลาง (x0, zc) เริ่มจากด้านล่างวนทวนเข็ม"""
    pts = []
    for i in range(n):
        t = -math.pi / 2 + 2 * math.pi * i / n
        c, s_ = math.cos(t), math.sin(t)
        pts.append((x0 + hw * math.copysign(abs(c) ** (2 / p), c), zc + hh * math.copysign(abs(s_) ** (2 / p), s_)))
    return (y, pts)


def make_moto():
    P = "ThaiRacingMoto"
    body = B(P)
    body.bw, body.sa = 0.01, 50
    R = 1.05
    YF, YR, ZH = -2.45, 2.15, R
    # ล้อซี่ลวดหลายสี + วงล้อทอง + จานดิสก์ทอง
    wheels = []
    for n, y in (("Wheel_F", YF), ("Wheel_R", YR)):
        wb = B(n)
        wb.bevel, wb.sa = False, 60
        bike_wheel(wb, y, ZH, R, spokes=24, rim="mt_gold", spoke_keys=("spoke_c1", "spoke_c2", "spoke_c3", "spoke_c4"), tire_w=0.11, hub_w=0.42)
        wb.disc_x((0.3 if y < 0 else -0.3, y, ZH), 0.5, 0.04, "mt_gold", n=20)
        wheels.append(wb)
        WHEEL(P, n, 0, y, ZH, R, 0.3, steer=y < 0)

    def stripe(j, i, n=20):
        # ลายข้าง: ล่างดำ แถบขาวกลางข้าง ที่เหลือส้ม
        if j in (0, 1, 2, n - 2, n - 1):
            return "mt_black"
        if j in (5, n - 5):
            return "mt_white"
        return "mt_orange"
    # บังลมหน้า (leg shield) โค้งจากคอรถลงไปพื้นวางเท้า
    body.loft([oval(-1.72, 3.05, 0.6, 0.42), oval(-1.55, 2.5, 0.68, 0.55), oval(-1.3, 1.85, 0.62, 0.48), oval(-1.0, 1.42, 0.44, 0.26),
               oval(-0.6, 1.3, 0.36, 0.18), oval(-0.25, 1.32, 0.36, 0.2)], "mt_orange",
              lambda j, i: "mt_black" if i >= 3 or j in (0, 1, 2, 18, 19) else ("mt_white" if j in (5, 15) and i == 1 else "mt_orange"))
    # ตัวถังใต้เบาะยาวไปถึงท้ายแหลมยกสูง
    body.loft([oval(-0.35, 1.7, 0.46, 0.5), oval(0.3, 2.0, 0.55, 0.55), oval(1.1, 2.25, 0.53, 0.47), oval(1.9, 2.5, 0.43, 0.34),
               oval(2.6, 2.75, 0.27, 0.22), oval(3.15, 2.95, 0.07, 0.07)], "mt_orange", stripe)
    # เบาะยาวต่ำ (ตอนคนซ้อนสูงขึ้นนิดหน่อย)
    body.loft([oval(-0.4, 2.62, 0.3, 0.1, n=10), oval(-0.05, 2.78, 0.43, 0.2, n=10), oval(0.9, 2.84, 0.46, 0.2, n=10),
               oval(1.6, 2.95, 0.4, 0.19, n=10), oval(2.3, 3.02, 0.28, 0.14, n=10), oval(2.6, 3.0, 0.12, 0.07, n=10)], "saddle")
    # เครื่องยนต์แนวนอนใต้พื้น + ฝาสูบเอียงไปหน้า
    body.disc_x((0.0, 0.25, 0.95), 0.48, 0.72, "steel", n=14, key2="engine")
    body.beam((0, -0.15, 1.0), (0, -0.75, 1.15), 0.5, 0.45, "steel")
    for k in range(4):  # ครีบระบายความร้อน
        body.beam((0, -0.3 - k * 0.12, 0.98), (0, -0.3 - k * 0.12 - 0.05, 1.36), 0.62, 0.04, "steel")
    # ท่อไอเสียสีไทเทเนียมม่วง (เส้นเล็กลง) ปลายท่อเฉียงขึ้น
    body.tube([(-0.12, -0.75, 0.95), (-0.3, -0.6, 0.55), (-0.42, 0.2, 0.5), (-0.48, 0.95, 0.68)], 0.075, "mt_purple", n=8)
    body.cone((-0.48, 0.9, 0.66), (-0.55, 2.55, 1.2), 0.17, 0.15, "mt_purple", n=12)
    body.cone((-0.55, 2.55, 1.2), (-0.56, 2.7, 1.25), 0.1, 0.1, "chrome", n=10)
    # สวิงอาร์มทอง + โช้คหลังสปริงแดง + พักเท้า
    for sx in (0.3, -0.3):
        body.beam((sx * 0.7, 0.55, 1.0), (sx, YR, ZH), 0.1, 0.16, "mt_gold")
        body.cone((sx * 1.05, YR - 0.25, ZH + 0.12), (sx * 1.05, 1.55, 2.3), 0.11, 0.11, "mt_red", n=8)
        body.beam((sx * 1.2, 0.35, 0.95), (sx * 2.0, 0.35, 0.95), 0.12, 0.12, "black")
    # ไฟท้าย + ป้ายทะเบียนห้อยใต้ท้าย + บังโคลนหลังสั้น
    body.boxc(0, 3.02, 2.9, 0.22, 0.16, 0.12, "lens_red")
    LIGHT(P, "tail", 0, 3.12, 2.9, 0.22, 0.12)
    body.beam((0, 2.75, 2.55), (0, 2.95, 2.05), 0.12, 0.08, "black")
    PLATE(P, 0, 3.0, 1.9, False, w=0.9, h=0.5, text="1กข 999", prov="ราชบุรี")
    fender(body, YR, ZH, R + 0.1, 0.3, "mt_black", 70, 125, th=0.05, n=5)
    # หน้ากากไฟหน้า + แฮนด์ + ตะเกียบหน้าทอง (Handlebar หมุนเลี้ยวได้)
    hb = B(P + "_Handlebar")
    hb.bw, hb.sa = 0.01, 50
    for sx in (0.27, -0.27):
        hb.tube([(sx, -1.9, 3.35), (sx, -2.2, 2.1), (sx, YF, ZH)], [0.1, 0.09, 0.075], "mt_gold", n=8)
    hb.loft([oval(-2.62, 3.42, 0.22, 0.18), oval(-2.45, 3.48, 0.5, 0.36), oval(-2.15, 3.58, 0.62, 0.45), oval(-1.85, 3.66, 0.56, 0.4),
             oval(-1.6, 3.72, 0.38, 0.28)], "mt_orange",
            lambda j, i: "mt_black" if 8 <= j <= 12 else ("mt_white" if j in (5, 15) else "mt_orange"))
    hb.ellipsoid((0, -2.5, 3.4), (0.36, 0.14, 0.2), "lens_white", nu=12, nv=6)
    LIGHT(P, "head", 0, -2.66, 3.4, 0.5, 0.28)
    for sx in (1, -1):
        hb.ellipsoid((sx * 0.5, -2.3, 3.32), (0.1, 0.12, 0.07), "lens_amber", nu=8, nv=4)
    hz = 3.92
    hb.tube([(-0.95, -1.5, hz + 0.05), (-0.4, -1.7, hz), (0.4, -1.7, hz), (0.95, -1.5, hz + 0.05)], 0.055, "mt_black", n=6)
    for sx in (1, -1):
        hb.tube([(sx * 0.85, -1.53, hz + 0.05), (sx * 1.15, -1.43, hz + 0.08)], 0.085, "rubber", n=8)
        hb.tube([(sx * 0.5, -1.72, hz + 0.05), (sx * 0.62, -1.8, hz + 0.55)], 0.03, "mt_black", n=5)
        hb.ellipsoid((sx * 0.66, -1.82, hz + 0.62), (0.16, 0.05, 0.1), "mt_black", nu=8, nv=4)
    fender(hb, YF, ZH, R + 0.1, 0.3, "mt_orange", 60, 125, th=0.05, n=6)
    SEAT(P, "DriverSeat", "VehicleSeat", 0, 0.45, 3.02, 1.8, 1.4, t=1.2)
    SEAT(P, "PassengerSeat", "Seat", 0, 1.85, 3.14, 1.7, 1.1, t=1.2)
    COL(P, -0.45, 0.45, -2.2, 2.6, 1.1, 2.6)
    PX(P, "mt_orange", -0.65, 0.65, -1.75, -1.0, 1.4, 3.4)
    PX(P, "mt_black", -0.36, 0.36, -1.0, -0.25, 1.12, 1.5)
    PX(P, "mt_orange", -0.55, 0.55, -0.35, 1.9, 1.3, 2.6)
    PX(P, "mt_orange", -0.4, 0.4, 1.9, 3.15, 2.2, 2.9)
    PX(P, "saddle", -0.45, 0.45, -0.4, 2.45, 2.6, 3.1)
    PX(P, "steel", -0.36, 0.36, -0.25, 0.75, 0.5, 1.4)
    PX(P, "mt_purple", -0.65, -0.4, 0.9, 2.7, 0.5, 1.3, rx=-1, th=0.3)
    PX(P, "mt_orange", -0.6, 0.6, -2.6, -1.6, 3.05, 4.05)
    PX(P, "mt_gold", -0.3, 0.3, -2.45, -1.95, ZH, 3.3, rx=-1, th=0.18)
    PX(P, "mt_black", -1.0, 1.0, -1.75, -1.6, hz - 0.06, hz + 0.08)
    return P, [body, hb] + wheels


# ---------------------------------------------------------------- 7) กระบะซิ่งติดตู้ลำโพง (รถแห่)
def make_sound_truck():
    P = "ThaiSoundTruck"
    body, glass, horns = B(P), B(P + "_Glass"), B(P + "_Horns")
    leds = [B(f"{P}_LED{i + 1}_Neon") for i in range(5)]  # วงไฟแยกตามสี (MeshPart Neon มีได้สีเดียว)
    for lb in leds:
        lb.bevel = False
    Rw, Ww, TR = 1.55, 1.25, 3.1
    YF, YR = -6.7, 5.9
    W = 3.95
    zs, zf, zb, zr = 1.2, 1.9, 4.55, 8.55
    # ---- เปลือกตัวรถต่อเนื่อง ทรง D-Max รุ่นใหม่ (มน ฝากระโปรงดำ กระจกหน้าเอียงมาก)
    inner = B(P + "_Interior")
    glass.no_recalc = inner.no_recalc = True
    glass.bevel = inner.bevel = False
    y0s, y1s = -11.0, 1.6

    def Wf(y):
        return W - 0.45 * ease((y0s + 1.2 - y) / 1.2) ** 1.3

    def zbf_(y):
        z = zs - 0.2 + 0.35 * ease((y0s + 0.6 - y) / 0.6)
        d = abs(y - YF)
        if d < 1.85:
            z = max(z, Rw + math.sqrt(1.85 ** 2 - d * d) * 0.98)
        return z

    def hood_top(y):
        return 3.95 + 0.55 * ease((y - y0s) / 7.4) ** 0.7 if y < -3.6 else zb

    def zroof_(y):
        if -3.6 < y < -0.8:
            return zb + (zr - zb) * ease((y + 3.6) / 2.8) ** 0.7
        return zr if y >= -0.8 else 0.0

    car_shell(body, glass, inner, y0s, y1s, Wf, zbf_, hood_top, zroof_, (-3.6, -0.8, 1.7, 1.8), "st_blue", "black_gloss",
              lower_key="st_sticker", seams=(-3.4, 1.35), tumble=0.7, crown=0.16, step=0.3)
    shell_interior(body, -3.6, y1s, W, zs, zf, 4.4)
    glass.box(-2.8, 2.8, y1s - 0.04, y1s + 0.05, 5.3, 8.0, "glass")  # กระจกหลังห้องคนขับ
    # กระจังหน้าดำ ไฟหน้าตาเรียว ไฟตัดหมอก กันชนแต่งสปอยเลอร์ล่าง
    body.box(-2.2, 2.2, -11.2, -10.95, 2.25, 3.55, "grille")
    for zz in (2.3, 3.5):  # กรอบกระจังโครเมียมบน-ล่าง
        body.box(-2.3, 2.3, -11.3, -11.15, zz - 0.07, zz + 0.07, "chrome")
    body.box(-1.6, 1.6, -11.28, -11.18, 2.75, 3.0, "chrome")
    for (yy, sx) in ((YF, 1), (YF, -1), (YR, 1), (YR, -1)):  # ซุ้มล้อโป่งสีดำ
        fx = sx * (W + 0.12)
        for k in range(9):
            a0_, a1_ = math.pi * k / 9, math.pi * (k + 1) / 9
            body.beam((fx, yy - 1.85 * math.cos(a0_), Rw + 1.85 * math.sin(a0_)), (fx, yy - 1.85 * math.cos(a1_), Rw + 1.85 * math.sin(a1_)), 0.3, 0.32, "black_gloss")
    for sx in (1, -1):
        body.hexa([(sx * 2.25, -11.22, 2.95), (sx * 3.65, -10.95, 3.15), (sx * 3.65, -10.85, 3.15), (sx * 2.25, -11.05, 2.95),
                   (sx * 2.25, -11.22, 3.6), (sx * 3.65, -10.95, 3.55), (sx * 3.65, -10.85, 3.55), (sx * 2.25, -11.05, 3.6)], "lens_white")
        LIGHT(P, "head", sx * 2.95, -11.18, 3.28, 1.3, 0.45)
        body.boxc(sx * 2.9, -11.3, 1.75, 0.6, 0.12, 0.35, "lens_white")
    body.box(-4.0, 4.0, -11.45, -10.9, 0.8, 2.25, "st_blue", keys={"front": "st_sticker"})
    body.box(-3.9, 3.9, -11.6, -11.3, 0.7, 0.85, "black_gloss")
    for sx in (1, -1):  # สติกเกอร์ลายไทยข้างประตู + กระจกมองข้าง
        mirror_side(body, sx * (W + 0.55), -3.15, 5.4, key="st_blue")
    bench(body, -3.5, 3.5, -0.85, 1.2, 3.45, "seat_vinyl", back_h=2.8, back_tilt=0.3)
    steering(body, -1.7, -2.2, 4.95)
    SEAT(P, "DriverSeat", "VehicleSeat", -1.7, 0.15, 3.45, 2.2, 1.9)
    SEAT(P, "PassengerSeat", "Seat", 1.65, 0.15, 3.45, 2.2, 1.9)
    # กระบะ
    yb0, yb1, zbf = 1.85, 10.6, 3.6
    body.box(-3.6, 3.6, yb0, yb1, zbf - 0.4, zbf, "black", keys={"top": "floor_tread"})
    for sx in (1, -1):
        x0, x1 = (3.6, 3.95) if sx > 0 else (-3.95, -3.6)
        for y0, y1, z0 in ((yb0, YR - 2.05, 1.2), (YR + 2.05, yb1, 1.2), (YR - 2.05, YR + 2.05, 3.35)):
            body.box(x0, x1, y0, y1, z0, 5.3, "st_sticker", keys={"top": "st_blue", "left" if sx > 0 else "right": "st_blue"})
        body.box(min(sx * 3.1, sx * 3.97), max(sx * 3.1, sx * 3.97), yb1 - 0.02, yb1 + 0.12, 3.6, 5.0, "lens_red")
        LIGHT(P, "tail", sx * 3.5, yb1 + 0.14, 4.3, 0.8, 1.3)
    body.box(-3.6, 3.6, yb1 - 0.3, yb1, 1.4, 5.1, "st_blue", keys={"back": "st_sticker"})
    body.box(-4.0, 4.0, yb1, yb1 + 0.5, 1.0, 1.9, "black_gloss", keys={"top": "floor_tread"})
    PLATE(P, 0, yb1 + 0.53, 1.45, False, w=1.7, h=0.85, text="ฆท 123", prov="ขอนแก่น")
    PLATE(P, 0, -11.48, 1.5, True, w=1.7, h=0.85, text="ฆท 123", prov="ขอนแก่น")
    # ตู้ลำโพง (ครึ่งหน้าของกระบะ) ลำโพงหันออกข้างทั้งสองฝั่งและด้านหลัง เหลือพื้นยืนท้ายกระบะ
    ry0, ry1, rz0, rz1 = 2.0, 8.0, zbf, 12.2  # ตู้ยาวเกือบเต็มกระบะ เหลือพื้นยืนท้าย ~2.3 x 7.2
    body.box(-3.55, 3.55, ry0, ry1, rz0, rz1, "speaker_box")
    rows = [(rz0 + 0.25, 2.6, 2), (rz0 + 3.0, 1.75, 3), (rz0 + 4.9, 1.3, 4), (rz0 + 6.35, 1.3, 4)]
    nled = 0
    led_cols = [(255, 40, 60), (40, 255, 120), (255, 150, 30), (60, 140, 255), (255, 60, 220)]
    for sx in (1, -1):
        xf = sx * 3.56
        for z0, size, n in rows:
            span = (ry1 - ry0) - 0.3
            step = span / n
            for i in range(n):
                yc = ry0 + 0.15 + step * (i + 0.5)
                sz_ = min(size, step - 0.15)
                zc = z0 + sz_ / 2
                body.box(min(xf, xf + sx * 0.05), max(xf, xf + sx * 0.05), yc - sz_ / 2, yc + sz_ / 2, zc - sz_ / 2, zc + sz_ / 2, "speaker")
                leds[nled % 5].torus((xf + sx * 0.09, yc, zc), "x", sz_ / 2 - 0.06, 0.07, "led", nu=16, nv=4)
                rig(P)["speakers"].append(dict(c=r_pt((xf + sx * 0.06, yc, zc)), d=round(sz_, 3), ax="x", ci=nled % 5))
                nled += 1
    for z0, size, n in rows:
        span = 7.1 - 0.3
        step = span / (n + 1)
        for i in range(n + 1):
            xc = -3.55 + 0.15 + step * (i + 0.5)
            sz_ = min(size, step - 0.15)
            zc = z0 + sz_ / 2
            body.box(xc - sz_ / 2, xc + sz_ / 2, ry1, ry1 + 0.05, zc - sz_ / 2, zc + sz_ / 2, "speaker")
            leds[nled % 5].torus((xc, ry1 + 0.09, zc), "y", sz_ / 2 - 0.06, 0.07, "led", nu=16, nv=4)
            rig(P)["speakers"].append(dict(c=r_pt((xc, ry1 + 0.06, zc)), d=round(sz_, 3), ax="z", ci=nled % 5))
            nled += 1
    # แถบ LED รอบขอบตู้
    for sx, ci in ((1, 2), (-1, 0)):
        leds[ci].box(min(sx * 3.55, sx * 3.68), max(sx * 3.55, sx * 3.68), ry0, ry1, rz1 - 0.12, rz1, "led")
        leds[ci + 1].box(min(sx * 3.55, sx * 3.68), max(sx * 3.55, sx * 3.68), ry0, ry0 + 0.12, rz0, rz1, "led")
        leds[ci + 1].box(min(sx * 3.55, sx * 3.68), max(sx * 3.55, sx * 3.68), ry1 - 0.12, ry1, rz0, rz1, "led")
        rig(P)["ledbars"].append(dict(c=r_pt((sx * 3.62, (ry0 + ry1) / 2, rz1 - 0.06)), s=[0.13, 0.12, ry1 - ry0], ci=ci))
        for yy in (ry0 + 0.06, ry1 - 0.06):
            rig(P)["ledbars"].append(dict(c=r_pt((sx * 3.62, yy, (rz0 + rz1) / 2)), s=[0.13, rz1 - rz0, 0.12], ci=ci + 1))
    leds[4].box(-3.55, 3.55, ry1, ry1 + 0.13, rz1 - 0.12, rz1, "led")
    rig(P)["ledbars"].append(dict(c=r_pt((0, ry1 + 0.065, rz1 - 0.06)), s=[7.1, 0.12, 0.13], ci=4))
    # ป้ายไฟ "SOUND WARS" บนตู้
    body.box(-3.0, 3.0, ry0 + 0.6, ry0 + 0.9, rz1, rz1 + 1.1, "black_gloss")
    rig(P)["signs"].append(dict(c=r_pt((0, ry0 + 0.58, rz1 + 0.55)), s=[5.8, 0.95, 0.04], front=1, t="SOUND WARS"))
    # ลำโพงฮอร์นเรียงแถวบนขอบหน้าตู้ หันไปข้างหน้าเหนือหลังคาหัวรถ (ตามภาพ) + ข้างละ 3 ตัว
    horns.box(-3.4, 3.4, ry0 + 0.3, ry0 + 0.5, rz1, rz1 + 0.35, "black")
    for k in range(8):
        xx = -3.15 + k * 0.9
        horns.boxc(xx, ry0 + 0.75, rz1 + 0.62, 0.42, 0.5, 0.42, "black")
        horns.cone((xx, ry0 + 0.5, rz1 + 0.62), (xx, ry0 - 1.5, rz1 + 0.78), 0.16, 0.42, "horn", n=12)
    for sx in (1, -1):
        for yy in (4.0, 5.6, 7.2):
            horns.boxc(sx * 2.6, yy, rz1 + 0.55, 0.5, 0.42, 0.42, "black")
            horns.cone((sx * 2.8, yy, rz1 + 0.55), (sx * 4.3, yy, rz1 + 0.7), 0.16, 0.48, "horn", n=12)
    # ล้อแม็กดำ
    wheels = []
    for n, x, y in (("Wheel_FL", TR, YF), ("Wheel_FR", -TR, YF), ("Wheel_RL", TR, YR), ("Wheel_RR", -TR, YR)):
        wb = B(n)
        car_wheel(wb, x, y, Rw, Rw, Ww, rim="black_gloss")
        sg = 1 if x > 0 else -1
        for j in range(6):  # ก้านแม็ก
            a = 2 * math.pi * j / 6
            wb.beam((x + sg * (Ww / 2 + 0.06), y + 0.25 * math.cos(a), Rw + 0.25 * math.sin(a)), (x + sg * (Ww / 2 + 0.02), y + 0.98 * math.cos(a), Rw + 0.98 * math.sin(a)), 0.22, 0.08, "black_gloss", side=(0, -math.sin(a), math.cos(a)))
        wb.torus((x + sg * (Ww / 2 + 0.03), y, Rw), "x", 1.02, 0.05, "chrome", nu=20, nv=4)
        wheels.append(wb)
        WHEEL(P, n, x, y, Rw, Rw, Ww, steer=y < 0)
    rig(P)["led_colors"] = led_cols
    COL(P, -3.95, 3.95, -11.45, -3.6, 0.9, 4.5)
    COL(P, -3.95, 3.95, -3.6, 1.6, 1.2, 1.9)
    COL(P, -3.7, 3.7, -3.6, -2.6, 1.9, 4.6)
    COL(P, -3.5, 3.5, -3.6, -2.9, 4.6, 8.2)
    COL(P, -3.5, 3.5, -0.8, 1.6, 8.25, 8.55)
    COL(P, -3.95, 3.95, 1.35, 1.9, 1.9, 8.55)
    COL(P, -3.6, 3.6, yb0, yb1, 3.2, zbf, friction=0.8)
    COL(P, 3.6, 3.95, yb0, yb1, 1.2, 5.3, mirror=True)
    COL(P, -3.6, 3.6, yb1 - 0.3, yb1, 1.4, 5.1)
    COL(P, -4.0, 4.0, yb1, yb1 + 0.5, 1.0, 1.9, friction=0.8)
    COL(P, -3.6, 3.6, ry0, ry1 + 0.1, rz0, rz1, friction=0.8)
    COL(P, -3.6, 3.6, -3.6, yb1, 0.6, 1.2, friction=0)  # กันตัวละครมุดใต้ท้องรถ
    PX(P, "st_blue", -3.95, 3.95, -11.25, -3.6, 0.9, 4.5)
    PX(P, "grille", -2.2, 2.2, -11.2, -10.95, 2.25, 3.55)
    PX(P, "st_blue", -4.0, 4.0, -11.45, -10.9, 0.8, 2.25)
    PX(P, "st_blue", -3.95, 3.95, -3.6, 1.6, 1.2, 1.9)
    PX(P, "st_blue", 3.73, 3.95, -3.6, 1.6, 1.9, 4.55, mirror=True)
    PX(P, "interior", -3.7, 3.7, -3.6, -2.6, 3.5, 4.6)
    PX(P, "st_blue", -3.5, 3.5, -0.8, 1.6, 8.3, 8.55)
    PX(P, "st_blue", -3.95, 3.95, 1.35, 1.6, 1.9, 8.55)
    PX(P, "glass", -3.4, 3.4, -3.6, -0.8, 4.6, 8.3, rx=-1, th=0.1)
    PX(P, "st_blue", 3.45, 3.75, -3.6, -3.3, 4.55, 8.4, mirror=True)
    PX(P, "seat_vinyl", -3.5, 3.5, -0.85, 1.2, 2.95, 3.45)
    PX(P, "seat_vinyl", -3.5, 3.5, 0.8, 1.2, 3.45, 6.2)
    PX(P, "floor_tread", -3.6, 3.6, yb0, yb1, 3.2, zbf)
    PX(P, "st_blue", 3.6, 3.95, yb0, yb1, 3.35, 5.3, mirror=True)
    PX(P, "st_blue", 3.6, 3.95, yb0, YR - 2.05, 1.2, 3.35, mirror=True)
    PX(P, "st_blue", 3.6, 3.95, YR + 2.05, yb1, 1.2, 3.35, mirror=True)
    PX(P, "st_blue", -3.6, 3.6, yb1 - 0.3, yb1, 1.4, 5.1)
    PX(P, "black_gloss", -4.0, 4.0, yb1, yb1 + 0.5, 1.0, 1.9)
    PX(P, "speaker_box", -3.55, 3.55, ry0, ry1, rz0, rz1)
    PX(P, "horn", -3.4, 3.4, ry0 - 1.5, ry0 + 0.5, rz1 + 0.3, rz1 + 1.0)
    PX(P, "black_gloss", -3.0, 3.0, ry0 + 0.6, ry0 + 0.9, rz1, rz1 + 1.1)
    for i, lb in enumerate(leds):  # สีของแต่ละวง (ตรงกับ led_cols) ให้ภาพตัวอย่าง/texture เห็นหลายสี
        lb.k = ["led%d" % (i + 1)] * len(lb.k)
    return P, [body, glass, inner, horns] + leds + wheels


# ---------------------------------------------------------------- 8) รถแห่ 6 ล้อหัวแดงทรง Hino ตู้สูงยื่นคร่อมหลังคาหัว
def make_parade_truck():
    P = "ThaiParadeTruck"
    body, glass, wins = B(P), B(P + "_Glass"), B(P + "_Windows")
    W = 5.0
    Rw, Ww = 1.9, 1.3
    YF, YR1, YR2 = -12.6, 6.4, 10.2
    # ---- หัวเก๋ง (cab-over): ห้องโดยสาร 2 ที่นั่ง พื้นสูง 4.2 มีบันไดขึ้นข้างประตู
    cy0, cy1 = -16.3, -9.0
    zs, zf, zb, zr = 3.0, 4.2, 6.7, 11.2
    # เปลือกหัวเก๋งต่อเนื่อง (หน้าตั้ง กระจกหน้าใหญ่เกือบตั้งฉาก)
    cabin_in = B(P + "_Interior")
    glass.no_recalc = cabin_in.no_recalc = True
    glass.bevel = cabin_in.bevel = False
    y0s = -16.65

    def Wf(y):
        return W - 0.35 * ease((y0s + 0.7 - y) / 0.7)

    def zbf_(y):
        z = 1.3 + 0.3 * ease((y0s + 0.5 - y) / 0.5)
        d = abs(y - YF)
        if d < 2.25:
            z = max(z, Rw + math.sqrt(2.25 ** 2 - d * d))
        return z

    def zroof_(y):
        if y < y0s + 0.75:
            return zb + (zr - zb) * ease((y - y0s) / 0.75) ** 0.6
        return zr

    car_shell(body, glass, cabin_in, y0s, cy1, Wf, zbf_, lambda y: zb, zroof_, (y0s, y0s + 0.75, cy1 + 0.1, cy1 + 0.2), "pt_red", "pt_red",
              seams=(-14.6, -9.5), tumble=0.35, crown=0.08, boxy=0.6, step=0.3)
    shell_interior(body, cy0, cy1, W, zs, zf, 6.6)
    body.box(-W + 0.2, W - 0.2, cy1 - 0.25, cy1, zf, zr, "interior", keys={"back": "pt_red"})  # ผนังหลังห้องคนขับ
    bench(body, -W + 0.4, W - 0.4, -12.6, -10.6, 6.0, "seat_vinyl", back_h=2.8, back_tilt=0.3)
    steering(body, -2.4, -14.3, 7.3, R=0.85, tilt=40)
    SEAT(P, "DriverSeat", "VehicleSeat", -2.4, -11.6, 6.0, 2.4, 1.9)
    SEAT(P, "PassengerSeat", "Seat", 2.4, -11.6, 6.0, 2.4, 1.9)
    # หน้ารถ: กระจังโครเมียม ไฟหน้าเฉียง กันชนแดงคาดขาว บังโคลนล้อหน้า
    body.box(-2.6, 2.6, -16.72, -16.6, 3.6, 6.2, "grille")
    for zz in (4.1, 4.9, 5.7):
        body.box(-2.7, 2.7, -16.8, -16.7, zz - 0.09, zz + 0.09, "chrome")
    body.boxc(0, -16.82, 4.9, 1.0, 0.08, 0.6, "chrome")
    for sx in (1, -1):
        body.hexa([(sx * 2.8, -16.75, 3.3), (sx * 4.8, -16.55, 3.5), (sx * 4.8, -16.4, 3.5), (sx * 2.8, -16.6, 3.3),
                   (sx * 2.8, -16.75, 4.2), (sx * 4.8, -16.55, 4.5), (sx * 4.8, -16.4, 4.5), (sx * 2.8, -16.6, 4.2)], "lens_white")
        LIGHT(P, "head", sx * 3.8, -16.8, 3.9, 1.8, 0.7)
        body.boxc(sx * 4.3, -16.8, 2.2, 0.6, 0.1, 0.35, "lens_amber")
        body.box(min(sx * (W - 0.1), sx * (W + 0.1)), max(sx * (W - 0.1), sx * (W + 0.1)), YF - 2.4, YF + 2.4, zs - 0.1, zs + 0.15, "black")  # คิ้วซุ้มล้อ
        # บันไดขึ้นห้องคนขับ 2 ขั้น
        for zz, xo in ((1.5, 0.5), (2.85, 0.2)):
            body.box(min(sx * (W - 0.6), sx * (W + xo)), max(sx * (W - 0.6), sx * (W + xo)), -11.3, -9.6, zz - 0.15, zz, "floor_tread")
            COL(P, min(sx * (W - 0.6), sx * (W + xo)), max(sx * (W - 0.6), sx * (W + xo)), -11.3, -9.6, zz - 0.3, zz, friction=0.8)
        mirror_side(body, sx * (W + 0.8), -15.6, 7.8, key="black", arm=0.6)
    body.box(-W - 0.05, W + 0.05, -17.1, -16.5, 1.0, 2.6, "pt_red", keys={"front": "pt_stripe"})
    body.box(-W + 0.4, W - 0.4, -16.6, -12.0, 0.9, 3.0, "black")  # ใต้ห้องเครื่อง
    PLATE(P, 0, -17.13, 1.75, True, w=1.8, h=0.9, text="70-4512", prov="ขอนแก่น")
    # ---- แชสซี + ถังน้ำมัน
    body.box(-3.2, 3.2, -9.0, 14.0, 1.4, 2.9, "black")
    body.boxc(-4.4, 0.5, 2.3, 1.4, 3.0, 1.5, "steel")
    # ---- ตู้รถแห่ (ผนังบาง เดินเข้าไปข้างในได้) พื้น 3.8 เพดาน 18.6 + ชั้นลอยเหนือหัวเก๋ง
    by0, by1, bz0, bf, bc, bt = -8.7, 13.6, 2.9, 3.8, 18.6, 19.1
    ly0, lf = -16.0, 12.4  # ชั้นลอยเริ่มที่หน้า overhang, พื้นชั้นลอยสูง 12.4
    t = 0.3
    body.box(-W, W, by0, by1, bz0, bf, "pt_red", keys={"top": "floor_wood", "bottom": "black"})
    for sx in (1, -1):
        x0, x1 = (W - t, W) if sx > 0 else (-W, -W + t)
        inner = "left" if sx > 0 else "right"
        body.box(x0, x1, by0, by1, bz0, bt, "pt_graphic", keys={inner: "interior_wall", "top": "pt_red"})  # ผนังข้างตู้ส่วนหลัง
        body.box(x0, x1, ly0, by0, zr + 0.3, bt, "pt_graphic", keys={inner: "interior_wall", "top": "pt_red", "bottom": "black"})  # ผนังข้าง overhang
        # หน้าต่างกระจกดำบานใหญ่ 4 บาน + กรอบดำ (ชิ้นแยก _Windows) ตามภาพ
        for i in range(4):
            ya = by0 + 1.4 + i * 5.0
            wins.box(min(sx * (W + 0.02), sx * (W + 0.08)), max(sx * (W + 0.02), sx * (W + 0.08)), ya, ya + 4.6, 9.4, 16.9, "glass_dark")
            wins.box(min(sx * (W + 0.01), sx * (W + 0.1)), max(sx * (W + 0.01), sx * (W + 0.1)), ya + 4.6, ya + 5.0, 9.2, 17.1, "black")
        wins.box(min(sx * (W + 0.01), sx * (W + 0.1)), max(sx * (W + 0.01), sx * (W + 0.1)), by0 + 1.0, by0 + 21.4, 16.9, 17.2, "black")
        wins.box(min(sx * (W + 0.01), sx * (W + 0.1)), max(sx * (W + 0.01), sx * (W + 0.1)), by0 + 1.0, by0 + 21.4, 9.1, 9.4, "black")
        # โลโก้วงทอง
        body.box(min(sx * (W + 0.02), sx * (W + 0.1)), max(sx * (W + 0.02), sx * (W + 0.1)), 5.5, 11.5, 6.6, 8.7, "pt_logo")
    # หลังคา + เพดาน
    body.box(-W, W, ly0, by1, bc, bt, "pt_red", keys={"bottom": "interior_wall"})
    # ด้านหน้า overhang: ระแนงช่องลำโพงเฉียง (หน้าเอนไปข้างหน้าด้านบน)
    body.hexa([(-W, -15.0, zr + 0.3), (W, -15.0, zr + 0.3), (W, -14.7, zr + 0.3), (-W, -14.7, zr + 0.3),
               (-W, -16.6, bt), (W, -16.6, bt), (W, -16.3, bt), (-W, -16.3, bt)], "pt_red", keys={"front": "pt_vent", "back": "interior_wall"})
    for i in range(6):
        z = zr + 1.0 + i * 1.15
        yy = -15.0 - (z - zr - 0.3) / (bt - zr - 0.3) * 1.6
        body.beam((-W + 0.4, yy - 0.12, z), (W - 0.4, yy - 0.12, z), 0.22, 0.25, "chrome", side=(0, 0, 1))
    # ผนังล่างของ overhang เหนือหลังคาหัว (ปิดช่อง) = พื้นชั้นลอย
    body.box(-W + t, W - t, ly0 + 0.3, -6.0, zr + 0.3, lf, "pt_red", keys={"top": "floor_wood"})
    # ผนังหน้าตู้ส่วนล่าง (หลังห้องคนขับ)
    body.box(-W, W, by0, by0 + t, bf, zr + 0.3, "pt_red", keys={"back": "interior_wall"})
    # ผนังหลัง + ช่องประตูท้าย 5 x 8.4 (บานประตูเปิดพับข้าง)
    for sx in (1, -1):
        body.box(min(sx * 2.6, sx * W), max(sx * 2.6, sx * W), by1 - t, by1, bf, bt, "pt_graphic", keys={"front": "interior_wall"})
        # บานประตูเปิดกางออก 90°
        body.box(min(sx * W, sx * (W + 0.15)), max(sx * W, sx * (W + 0.15)), by1, by1 + 2.6, bf + 0.1, 12.0, "pt_red", keys={"left" if sx > 0 else "right": "pt_stripe"})
        body.box(min(sx * 3.4, sx * 4.8), max(sx * 3.4, sx * 4.8), by1 + 0.02, by1 + 0.14, 1.6, 2.8, "lens_red")
        LIGHT(P, "tail", sx * 4.1, by1 + 0.16, 2.2, 1.4, 1.0)
    body.box(-2.6, 2.6, by1 - t, by1, 12.2, bt, "pt_red", keys={"front": "interior_wall"})
    PLATE(P, -3.2, by1 + 0.17, 3.2, False, w=1.8, h=0.9, text="70-4512", prov="ขอนแก่น")
    # บันไดพับท้ายตู้ 3 ขั้น (สูงขั้นละ 0.95) ต่อถึงพื้นตู้
    for i in range(3):
        z = 0.95 * (i + 1)
        y0 = by1 + (2 - i) * 0.8
        body.box(-2.4, 2.4, y0, y0 + 0.8, z - 0.2, z, "floor_tread")
        COL(P, -2.4, 2.4, y0, y0 + 0.8, 0.0, z, friction=0.8)
    for sx in (1, -1):
        body.beam((sx * 2.45, by1, bf), (sx * 2.45, by1 + 2.4, 0.2), 0.12, 0.25, "steel")
    # บันไดขึ้นชั้นลอย ชิดผนังซ้าย (x +1.6..+4.7) ขั้นละ 0.8 ทอดจากหลังไปหน้า
    nst = int(math.ceil((lf - bf) / 0.8))
    rise = (lf - bf) / nst
    run = 0.85
    sy0 = -6.0 + nst * run
    for i in range(nst):
        z = bf + rise * (i + 1)
        ya = sy0 - (i + 1) * run
        body.box(1.6, W - t, ya, ya + run, z - 0.25, z, "floor_wood", keys={"front": "pt_red"})
        COL(P, 1.6, W - t, ya, ya + run, bf, z, friction=0.8)
    body.beam((1.5, sy0, bf + 3.2), (1.5, -6.0, lf + 3.2), 0.12, 0.12, "chrome")  # ราวจับบันได
    # ราวกันตกขอบชั้นลอย
    body.box(-W + t, 1.5, -6.15, -5.95, lf + 2.8, lf + 3.0, "chrome")
    for x in (-4.2, -2.4, -0.6, 1.2):
        body.box(x - 0.07, x + 0.07, -6.12, -5.98, lf, lf + 2.9, "chrome")
    # ข้างในตู้: เบาะโซฟายาวชิดผนังขวา + ไฟเพดาน LED
    body.box(-W + t, -W + t + 1.8, -2.0, 9.0, bf, bf + 1.6, "seat_vinyl")
    body.box(-W + t, -W + t + 0.5, -2.0, 9.0, bf + 1.6, bf + 3.6, "seat_vinyl")
    for y in (-3.0, 2.0, 7.0, 11.5):
        body.box(-2.0, 2.0, y - 0.2, y + 0.2, bc - 0.1, bc, "lens_white")
    # ล้อ: หน้าเดี่ยว หลังคู่ 2 เพลา อัลลอยเงิน
    wheels = []
    for n, x, y, w in (("Wheel_FL", 4.0, YF, Ww), ("Wheel_FR", -4.0, YF, Ww), ("Wheel_RL1", 3.7, YR1, 2.6), ("Wheel_RR1", -3.7, YR1, 2.6),
                       ("Wheel_RL2", 3.7, YR2, 2.6), ("Wheel_RR2", -3.7, YR2, 2.6)):
        wb = B(n)
        if w > 2:
            car_wheel(wb, x - 0.65, y, Rw, Rw, 1.25, rim="bk_silver", lug=False)
            car_wheel(wb, x + 0.65, y, Rw, Rw, 1.25, rim="bk_silver")
        else:
            car_wheel(wb, x, y, Rw, Rw, w, rim="bk_silver")
        wheels.append(wb)
        WHEEL(P, n, x, y, Rw, Rw, w, steer=y < 0)
    # ---- กล่องชน
    COL(P, -W, W, -17.1, cy0, 1.0, zb)                      # หน้ารถ
    COL(P, -W, W, cy0, cy1, zs, zf, friction=0.8)            # พื้นห้องคนขับ
    COL(P, -W + 0.2, W - 0.2, cy0, cy0 + 1.0, zf, zb + 0.15)  # คอนโซล
    COL(P, -W, W, cy0, cy0 + 0.3, zb, zr)                    # กระจกหน้า
    COL(P, -W, W, cy1 - 0.3, cy1, zf, zr)                    # ผนังหลังห้องคนขับ
    COL(P, -W, W, -14.7, cy1, zr, lf, friction=0.8)          # หลังคาหัว + พื้นชั้นลอย
    COL(P, -W, W, -9.0, -6.0, zr, lf, friction=0.8)
    COL(P, -W, W, by0, by1, bz0, bf, friction=0.8)           # พื้นตู้
    COL(P, W - t, W, ly0, by1, bf, bt, mirror=True)          # ผนังข้าง
    COL(P, -W, W, ly0, by1, bc, bt)                          # หลังคา
    COL(P, -W, W, -16.6, -14.7, zr + 0.3, bt)                # หน้า overhang
    COL(P, 2.6, W, by1 - t, by1, bf, bt, mirror=True)        # ผนังหลังสองข้างประตู
    COL(P, -2.6, 2.6, by1 - t, by1, 12.2, bt)                # เหนือประตู
    COL(P, -W + t, 1.5, -6.15, -5.95, lf, lf + 3.0)          # ราวกันตกชั้นลอย
    COL(P, -3.4, 3.4, -9.0, by1, 1.0, bz0, friction=0)       # กันมุดใต้ท้องรถ
    # ---- proxy
    PX(P, "pt_red", -W, W, -17.1, cy0, 1.0, zb)
    PX(P, "grille", -2.6, 2.6, -16.75, -16.6, 3.6, 6.2)
    PX(P, "pt_red", -W, W, cy0, cy1, zs, zf)
    PX(P, "pt_red", W - 0.22, W, cy0, cy1, zf, zb, mirror=True)
    PX(P, "pt_red", W - 0.3, W, cy0, cy0 + 0.5, zb, zr, mirror=True)
    PX(P, "glass", -W + 0.3, W - 0.3, cy0, cy0 + 0.6, zb, zr, rx=-1, th=0.1)
    PX(P, "pt_red", -W, W, cy0 + 0.6, cy1, zr - 0.25, zr + 0.3)
    PX(P, "pt_red", -W, W, cy1 - 0.25, cy1, zf, zr)
    PX(P, "seat_vinyl", -W + 0.4, W - 0.4, -12.6, -10.6, 5.5, 6.0)
    PX(P, "seat_vinyl", -W + 0.4, W - 0.4, -10.9, -10.5, 6.0, 8.8)
    PX(P, "pt_red", -W - 0.05, W + 0.05, -17.1, -16.5, 1.0, 2.6)
    PX(P, "black", -3.2, 3.2, -9.0, 14.0, 1.4, 2.9)
    PX(P, "floor_wood", -W, W, by0, by1, bz0, bf)
    PX(P, "pt_red", W - t, W, ly0, by1, bf, bt, mirror=True)
    PX(P, "pt_red", W - t, W, by0, by1, bz0, bf, mirror=True)
    PX(P, "glass_dark", W, W + 0.08, by0 + 1.4, by0 + 21.0, 9.4, 16.9, mirror=True)
    PX(P, "pt_stripe", W, W + 0.06, by0 + 1.0, by1 - 1.0, 4.6, 5.0, mirror=True)
    PX(P, "pt_stripe", W, W + 0.06, by0 + 1.0, by1 - 1.0, 16.6, 17.0, mirror=True)
    PX(P, "pt_logo", W, W + 0.1, 5.5, 11.5, 6.6, 8.7, mirror=True)
    PX(P, "pt_red", -W, W, ly0, by1, bc, bt)
    PX(P, "pt_vent", -W, W, -16.6, -14.7, zr + 0.3, bt, rx=1, th=0.3)
    PX(P, "pt_red", -W + t, W - t, ly0 + 0.3, -6.0, zr + 0.3, lf)
    PX(P, "pt_red", 2.6, W, by1 - t, by1, bf, bt, mirror=True)
    PX(P, "pt_red", -2.6, 2.6, by1 - t, by1, 12.2, bt)
    PX(P, "pt_red", W, W + 0.15, by1, by1 + 2.6, bf + 0.1, 12.0, mirror=True)
    for i in range(nst):
        z = bf + rise * (i + 1)
        ya = sy0 - (i + 1) * run
        PX(P, "floor_wood", 1.6, W - t, ya, ya + run, z - 0.25, z)
    PX(P, "chrome", -W + t, 1.5, -6.15, -5.95, lf + 2.8, lf + 3.0)
    PX(P, "seat_vinyl", -W + t, -W + t + 1.8, -2.0, 9.0, bf, bf + 1.6)
    for i in range(3):
        z = 0.95 * (i + 1)
        y0 = by1 + (2 - i) * 0.8
        PX(P, "floor_tread", -2.4, 2.4, y0, y0 + 0.8, z - 0.2, z)
    return P, [body, glass, cabin_in, wins] + wheels


# ---------------------------------------------------------------- textures
def vnoise(n, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells + 1, cells + 1))
    x = np.linspace(0, cells, n, endpoint=False)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    a = g[i][:, i]
    b = g[i][:, i + 1]
    c = g[i + 1][:, i]
    d = g[i + 1][:, i + 1]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def paint(key, n, seed):
    """คืน (rgb[n,n,3], height[n,n], rough[n,n], metal[n,n]) แถวแรก = บนสุด (v=1)"""
    spec = PAL[key]
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    v = 1 - yy
    n1 = vnoise(n, 6, seed)
    n2 = vnoise(n, 24, seed + 7)
    n3 = vnoise(n, 64, seed + 13)
    shade = 1 + 0.08 * (n1 - 0.5) + 0.05 * (n2 - 0.5) + 0.03 * (n3 - 0.5)
    h = 0.08 * n2 + 0.05 * n3
    rough = np.full((n, n), spec["r"]) + 0.06 * (n2 - 0.5)
    metal = np.full((n, n), float(spec["m"]))
    col = np.ones((n, n, 3)) * base
    p = spec["p"]
    rust_c = np.array([0.40, 0.22, 0.12])
    if p in ("rustpaint", "rustpaint_top"):
        # สีลอก: ด่างซีด + รองพื้นเทา + สนิมขึ้นตามขอบล่าง
        fade = vnoise(n, 5, seed + 1)
        col = col * (shade * (0.85 + 0.3 * fade))[..., None]
        k = 0.66 if p == "rustpaint" else 0.6
        peel = np.clip((vnoise(n, 9, seed + 3) * 0.7 + vnoise(n, 30, seed + 4) * 0.3 - k) * 7, 0, 1)
        primer = np.clip((vnoise(n, 12, seed + 5) - 0.74) * 5, 0, 1) * (1 - peel) * 0.6
        rust = np.clip(peel, 0, 1)
        col = col * (1 - primer[..., None]) + np.array([0.36, 0.33, 0.3]) * primer[..., None]
        col = col * (1 - rust[..., None]) + rust[..., None] * rust_c * (0.7 + 0.5 * n3)[..., None]
        scratch = (np.abs(np.sin((xx * 3 + yy * 0.4 + n2 * 0.3) * 90)) > 0.995).astype(float) * (n1 > 0.5)
        col = col * (1 - 0.25 * scratch[..., None]) + 0.3 * scratch[..., None] * np.array([0.6, 0.55, 0.5])
        rough = rough + 0.2 * rust
        metal = metal * (1 - rust)
        h = 0.4 * peel + 0.1 * n3
    elif p in ("rust", "rust_light"):
        pits = vnoise(n, 40, seed + 2)
        mix = np.clip((vnoise(n, 7, seed + 3) - (0.4 if p == "rust" else 0.55)) * 3, 0, 1)
        col = col * (shade * (0.8 + 0.35 * pits))[..., None]
        col = col * (1 - mix[..., None] * 0.6) + rust_c * mix[..., None] * 0.6
        h = 0.5 * pits
    elif p == "grime":
        col = col * (shade * (0.75 + 0.4 * n2))[..., None]
    elif p == "metallic":
        sp = np.random.default_rng(seed).random((n, n))
        # ไม่ไล่สีตามแนวตั้งต่อหน้า (ไม่งั้นแผ่นตัวถังที่ต่อกันเป็นแถบลาย)
        col = col * (shade + 0.04 * (sp - 0.5))[..., None]
        h = np.zeros((n, n))  # สีรถผิวเรียบ ไม่มี bump (ไม่งั้นฝากระโปรงดูเป็นคลื่น)
    elif p == "anodized":
        col = col * (0.75 + 0.5 * np.abs(np.sin(xx * math.pi)))[..., None]
    elif p == "chrome":
        g = 0.55 + 0.45 * np.clip((v - 0.45) * 3, -1, 1)
        g = np.where(np.abs(v - 0.45) < 0.04, 0.25, g)
        col = col * g[..., None] * shade[..., None]
    elif p == "tread":
        gy = (yy * 10) % 1.0
        groove = ((gy < 0.18) | (np.abs(xx - 0.5) < 0.04)).astype(float)
        col = col * (1 - 0.45 * groove)[..., None]
        h = 1 - groove
    elif p == "treadplate":
        gx, gy = (xx * 8) % 1.0, (yy * 8) % 1.0
        ridge = (np.abs((gx - 0.5) * 0.4 + (gy - 0.5)) < 0.08) & (np.abs(gx - 0.5) < 0.35)
        col = col * (shade * (1 + 0.25 * ridge))[..., None]
        h = ridge.astype(float)
        col = col * (1 - 0.3 * np.clip((vnoise(n, 6, seed) - 0.5) * 3, 0, 1))[..., None]
    elif p in ("canvas", "carpet"):
        w = 0.5 + 0.5 * np.sin(xx * 2 * math.pi * 48) * np.sin(yy * 2 * math.pi * 48)
        col = col * (shade * (0.92 + 0.12 * w))[..., None]
        h = 0.3 * w
    elif p == "vinyl":
        seam = (np.abs(xx - 0.5) < 0.01) | (yy % 0.33 < 0.01)
        col = col * (shade * (1 - 0.35 * seam))[..., None]
        h = 0.2 * n2 - 0.4 * seam
    elif p == "grille":
        slat = ((v * 7) % 1.0) < 0.55
        col = col * np.where(slat, 1.25, 0.35)[..., None]
        h = slat.astype(float)
    elif p == "lamp":
        r2 = (xx - 0.5) ** 2 + (yy - 0.5) ** 2
        col = col * (0.75 + 0.45 * np.exp(-r2 * 12))[..., None]
        cell = ((xx * 10) % 1.0 < 0.08) | ((yy * 6) % 1.0 < 0.08)
        col = col * (1 - 0.15 * cell)[..., None]
    elif p == "plate":
        border = ((xx < 0.04) | (xx > 0.96) | (yy < 0.07) | (yy > 0.93)).astype(float)
        col = col * (1 - border[..., None]) + 0.08 * border[..., None]
    elif p == "sign":
        border = ((xx < 0.06) | (xx > 0.94) | (yy < 0.12) | (yy > 0.88)).astype(float)
        col = col * (1 - border[..., None]) + np.array([0.7, 0.1, 0.1]) * border[..., None]
    elif p == "basket":
        gx, gy = (xx * 9) % 1.0, (yy * 7) % 1.0
        wire = ((gx < 0.22) | (gy < 0.22)).astype(float)
        col = col * (0.35 + 1.0 * wire)[..., None]
        h = wire
    elif p == "speaker":
        r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 2
        surround = (r > 0.82) & (r < 0.95)
        cone = 0.25 + 0.35 * np.clip(r, 0, 0.82) + 0.05 * np.sin(r * 60)
        cap = r < 0.22
        g = np.where(cap, 0.45, cone)
        g = np.where(surround, 0.12, g)
        g = np.where(r >= 0.95, 0.05, g)
        col = np.ones((n, n, 3)) * g[..., None] * np.array([0.9, 0.9, 1.0])
        h = np.where(surround, 1.0, 0.4 * np.clip(1 - r, 0, 1))
        rough = np.where(cap, 0.25, 0.6)
    elif p == "F_parade":
        # ข้างตู้รถแห่: พื้นแดง แถบเทาเฉียง เส้นขาวคู่ ขอบล่างเทาเข้ม (เหมือนภาพ 16)
        col = col * (shade + 0.08 * (v - 0.5))[..., None]
        s1 = xx * 0.9 - v * 0.55
        grey = (np.abs(s1 - 0.12) < 0.07) | (np.abs(s1 - 0.5) < 0.05)
        white = (np.abs(s1 - 0.21) < 0.012) | (np.abs(s1 - 0.235) < 0.008) | (np.abs(s1 - 0.57) < 0.01)
        s2 = xx * 0.7 + v * 0.8
        dark = (np.abs(s2 - 1.15) < 0.05) & (v < 0.55)
        col = np.where(grey[..., None], np.array([0.55, 0.56, 0.6]) * (0.9 + 0.2 * n2[..., None]), col)
        col = np.where(dark[..., None], np.array([0.25, 0.25, 0.28]), col)
        col = np.where(white[..., None], np.array([0.95, 0.95, 0.95]), col)
        band = v < 0.08
        col = np.where(band[..., None], np.array([0.3, 0.3, 0.33]), col)
        h = 0.2 * (grey | white)
        metal = np.where(grey, 0.6, metal)
    elif p == "logo":
        # โลโก้ชื่อวงสีทองแบบตัวอักษรเอียง (ลายเส้นนามธรรม) บนพื้นดำ
        col = np.ones((n, n, 3)) * np.array([0.08, 0.08, 0.09])
        strokes = (np.sin((xx * 9 + v * 3) * math.pi) > 0.55) & (v > 0.25) & (v < 0.75)
        under = (np.abs(v - 0.15) < 0.04) & (xx > 0.1) & (xx < 0.9)
        g = strokes | under
        col = np.where(g[..., None], base * (0.85 + 0.3 * n2[..., None]), col)
        metal = np.where(g, 0.9, 0.1)
        h = g.astype(float)
    elif p == "vent":
        slat = ((v * 7) % 1.0) < 0.5
        col = np.where(slat[..., None], base * 1.2, np.array([0.05, 0.05, 0.05]))
        h = slat.astype(float)
    elif p == "F_sticker":
        # ลายสติกเกอร์รถแห่: เปลวคลื่นหลายสี + กนกบนพื้นน้ำเงิน
        col = col * (shade + 0.1 * (v - 0.5))[..., None]
        cols = np.array([(250, 60, 140), (60, 230, 220), (250, 200, 40), (240, 110, 30), (150, 70, 230), (250, 250, 250)]) / 255.0
        for i in range(6):
            ph = i * 0.9
            yc = 0.18 + 0.12 * i + 0.06 * np.sin(xx * 2 * math.pi * (2 + i % 3) + ph) + 0.03 * np.sin(xx * 31 + i)
            band = np.abs(v - yc) < (0.018 + 0.012 * (i % 2))
            col = np.where(band[..., None], cols[i] * (0.85 + 0.3 * n2[..., None]), col)
        f = np.sin(xx * 40 + 4 * np.sin(yy * 21)) * np.sin(yy * 38 + 4 * np.sin(xx * 17))
        kranok = (f > 0.72) & (v < 0.25)
        col = np.where(kranok[..., None], np.array([0.95, 0.75, 0.2]), col)
        h = 0.3 * kranok
    else:
        col = col * shade[..., None]
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), np.clip(metal, 0, 1)


def build_atlas(prop, keys):
    N = 1024
    C = 128
    col = np.zeros((N, N, 3))
    hgt = np.zeros((N, N))
    rgh = np.ones((N, N)) * 0.8
    met = np.zeros((N, N))
    layout = {}
    feat = [k for k in keys if PAL[k]["p"].startswith("F_")]
    assert len(feat) <= 1, (prop, feat)
    free = [(i, j) for j in range(8) for i in range(8) if not (feat and i < 4 and j < 4)]
    assert len(keys) - len(feat) <= len(free), (prop, len(keys))
    ci = 0
    for k in keys:
        if PAL[k]["p"].startswith("F_"):
            x0, y0, w = 0, 0, 512
        else:
            i, j = free[ci]
            ci += 1
            x0, y0, w = i * C, j * C, C
        c, h, r, m = paint(k, w, 1000 + KEYS.index(k) * 17)
        col[y0:y0 + w, x0:x0 + w] = c
        hgt[y0:y0 + w, x0:x0 + w] = h
        rgh[y0:y0 + w, x0:x0 + w] = r
        met[y0:y0 + w, x0:x0 + w] = m
        layout[k] = (x0, y0, w)
    # หม่นลงเล็กน้อยให้เข้ากับฉากกลางคืน (ความอิ่มสี -10%, ความสว่าง -5%)
    g = col.mean(-1, keepdims=True)
    col = (g + (col - g) * 0.9) * 0.95
    gy, gx = np.gradient(hgt)
    nx, ny = -gx * 6.0, gy * 6.0
    nz = np.ones_like(nx)
    ln = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
    nrm = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    files = {}
    for suffix, arr, nonc in (("Color", col, False), ("Normal", nrm, True), ("Roughness", rgh, True), ("Metalness", met, True)):
        if arr.ndim == 2:
            arr = np.stack([arr] * 3, -1)
        rgba = np.concatenate([np.clip(arr, 0, 1), np.ones((N, N, 1))], -1)
        rgba = np.flipud(rgba)
        name = f"{prop}_{suffix}"
        img = bpy.data.images.get(name) or bpy.data.images.new(name, N, N, alpha=False)
        img.pixels.foreach_set(rgba.astype(np.float32).ravel())
        path = os.path.join(ROOT, name + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        try:
            img.save()
        except RuntimeError:
            img.save_render(path)
        if nonc:
            img.colorspace_settings.name = "Non-Color"
        files[suffix] = img
    return layout, files


def face_uv(bm, face, layout, uvl, keyname, world=False):
    x0, y0, w = layout[keyname]
    m = 3 if w <= 128 else 6
    n = face.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    pts = []
    for l in face.loops:
        p = l.vert.co
        if ax == 0:
            uv = (p.y if n.x > 0 else -p.y, p.z)
        elif ax == 1:
            uv = (-p.x if n.y > 0 else p.x, p.z)
        else:
            uv = (p.x, p.y if n.z > 0 else -p.y)
        pts.append(uv)
    if w > 128 and PAL[keyname]["p"] == "F_sticker":  # ลายสติกเกอร์รถแห่: ใช้พิกัดจริงให้ลายต่อเนื่องข้ามหน้า
        sc = 1.0 / 7.0
        su = [u * sc for u, _ in pts]
        off = math.floor(min(su))
        span = max(max(su) - off, 1.0)
        for l, (u, v), uu in zip(face.loops, pts, su):
            s = (uu - off) / span
            U = (x0 + m + s * (w - 2 * m)) / 1024.0
            V = (1024 - y0 - w + m + min(max((v - 0.8) / 3.2, 0.0), 1.0) * (w - 2 * m)) / 1024.0
            l[uvl].uv = (U, V)
        return
    if world:  # เปลือกรถ (หน้าเล็กจำนวนมาก): ใช้พิกัดจริง 6 studs ต่อ 1 รอบลาย ลายจึงต่อเนื่อง ไม่ยืดเป็นแถบ
        sc = 1.0 / 6.0
        su = [u * sc for u, _ in pts]
        sv = [v * sc for _, v in pts]
        ou, ov = math.floor(min(su)), math.floor(min(sv))
        pu, pv = max(max(su) - ou, 1.0), max(max(sv) - ov, 1.0)
        for l, uu, vv in zip(face.loops, su, sv):
            U = (x0 + m + (uu - ou) / pu * (w - 2 * m)) / 1024.0
            V = (1024 - y0 - w + m + (vv - ov) / pv * (w - 2 * m)) / 1024.0
            l[uvl].uv = (U, V)
        return
    us = [u for u, _ in pts]
    vs = [v for _, v in pts]
    u0, u1, v0, v1 = min(us), max(us), min(vs), max(vs)
    du, dv = max(u1 - u0, 1e-6), max(v1 - v0, 1e-6)
    N = 1024.0
    for l, (u, v) in zip(face.loops, pts):
        s = (u - u0) / du
        t = (v - v0) / dv
        U = (x0 + m + s * (w - 2 * m)) / N
        V = (N - y0 - w + m + t * (w - 2 * m)) / N
        l[uvl].uv = (U, V)


def make_material(prop, files):
    mat = bpy.data.materials.get(prop + "_Mat") or bpy.data.materials.new(prop + "_Mat")
    mat.use_nodes = True
    mat.use_backface_culling = True  # เหมือน Roblox (MeshPart ไม่วาดด้านหลัง) ผิวด้านในห้องโดยสารจึงไม่ทะลุออกมาด้านนอก
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexImage")
    tc.image = files["Color"]
    nt.links.new(tc.outputs[0], bsdf.inputs["Base Color"])
    tr = nt.nodes.new("ShaderNodeTexImage")
    tr.image = files["Roughness"]
    nt.links.new(tr.outputs[0], bsdf.inputs["Roughness"])
    tm = nt.nodes.new("ShaderNodeTexImage")
    tm.image = files["Metalness"]
    nt.links.new(tm.outputs[0], bsdf.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = files["Normal"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    nt.nodes.active = tc
    return mat


def eval_tris(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    m = ev.to_mesh()
    m.calc_loop_triangles()
    n = len(m.loop_triangles)
    ev.to_mesh_clear()
    return n


def finish_surface(ob, b):
    """มุมมน + smooth shading: Bevel (จำกัดตามมุม) → Weighted Normal ผิวเรียบแต่ขอบยังคม ถ้าเกิน 10k tris ลดเหลือ 1 segment หรือตัด bevel"""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(b.sa))
    if b.bevel:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width = b.bw
        bv.segments = 2
        bv.limit_method = "ANGLE"
        bv.angle_limit = math.radians(30)
        bv.harden_normals = True
        bv.miter_outer = "MITER_ARC"
        wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
        wn.keep_sharp = True
        if eval_tris(ob) > 10000:
            bv.segments = 1
        if eval_tris(ob) > 10000:
            ob.modifiers.remove(bv)


def realize(prop, builders):
    keys = []
    for b in builders:
        for k in b.k:
            if k not in keys:
                keys.append(k)
    layout, files = build_atlas(prop, keys)
    mat = make_material(prop, files)
    coll = bpy.data.collections.get(prop)
    if coll:
        for o in list(coll.objects):
            bpy.data.objects.remove(o)
    else:
        coll = bpy.data.collections.new(prop)
        bpy.context.scene.collection.children.link(coll)
    objs = []
    for b in builders:
        if not b.v:
            continue
        me = bpy.data.meshes.new(b.name)
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in b.v]
        fk = []
        for f, k in zip(b.f, b.k):
            try:
                bf = bm.faces.new([vs[i] for i in f])
                fk.append((bf, k))
            except ValueError:
                pass
        if not getattr(b, "no_recalc", False):  # กระจก/ผิวด้านในกำหนดทิศเอง
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uvl = bm.loops.layers.uv.new("UVMap")
        for bf, k in fk:
            face_uv(bm, bf, layout, uvl, k, getattr(b, "worlduv", False))
        bmesh.ops.scale(bm, vec=(S,) * 3, verts=bm.verts)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(b.name, me)
        coll.objects.link(ob)
        finish_surface(ob, b)
        tris = eval_tris(ob)
        log(f"  {b.name}: {tris} tris")
        if tris > 10000:
            log(f"  !!! {b.name} เกิน 10,000 tris")
        objs.append(ob)
        mn = [min(v[i] for v in b.v) for i in range(3)]
        mx = [max(v[i] for v in b.v) for i in range(3)]
        c, sz = r_box(mn[0], mx[0], mn[1], mx[1], mn[2], mx[2])
        OBJ_BBOX.setdefault(prop, {})[b.name] = dict(c=c, s=sz)
    return coll, objs


def export(prop, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT, prop + ".fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)


def frame_cam(objs, d, lens=40, dist=1.05):
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    c = (mn + mx) / 2
    size = (mx - mn).length
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.lens = lens
    cam.location = c + Vector(d).normalized() * size * dist
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


def render_setup(res=900):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.display.shading.show_cavity = True
    scn.display.shading.show_shadows = True
    scn.render.resolution_x = res
    scn.render.resolution_y = res
    scn.render.film_transparent = False


def ref_human(x, y):
    """หุ่นเทียบขนาดตัวละคร R15 (สูง 5.2 studs) ใส่เฉพาะภาพตัวอย่าง ไม่ export"""
    b = B("RefHuman")
    b.boxc(x, y, 1.0, 0.9, 0.9, 2.0, "black")
    b.boxc(x, y, 3.1, 2.0, 1.0, 2.2, "black")
    b.ellipsoid((x, y, 4.7), (0.6, 0.6, 0.55), "black", nu=10, nv=6)
    return b


def preview(prop, objs, human_xy=None):
    extra = []
    if human_xy:
        hb = ref_human(*human_xy)
        me = bpy.data.meshes.new("RefHuman")
        me.from_pydata([tuple(v * S for v in p) for p in hb.v], [], hb.f)
        ob = bpy.data.objects.new("RefHuman", me)
        bpy.context.scene.collection.objects.link(ob)
        extra.append(ob)
    for o in bpy.context.view_layer.objects:
        o.hide_render = o not in objs and o not in extra
    render_setup()
    frame_cam(objs, (-0.75, -1.25, 0.55))
    bpy.context.scene.render.filepath = os.path.join(PREV, prop + ".png")
    bpy.ops.render.render(write_still=True)
    frame_cam(objs, (1.0, 0.0, 0.08), dist=1.0)
    bpy.context.scene.render.filepath = os.path.join(PREV, prop + "_side.png")
    bpy.ops.render.render(write_still=True)
    for ob in extra:
        bpy.data.objects.remove(ob)


HUMAN_AT = {
    "ThaiPickupOld": (5.6, -1.0), "ThaiSedanSoluna": (5.4, -1.0), "ThaiBicycleRed": (2.2, 0.0), "ThaiBicycleBlue": (2.2, 0.0),
    "ThaiTukTuk": (4.0, 0.5), "ThaiRacingMoto": (2.2, 0.0), "ThaiSoundTruck": (5.8, -1.0), "ThaiParadeTruck": (7.2, -10.5),
}


# ย่อ/ขยายทั้งคัน (mesh + ข้อมูล rig) ให้สัดส่วนเข้ากับตัวละคร: จักรยานเบาะสูง ~3.3, มอเตอร์ไซค์เบาะ ~2.75 เท่า CustomerBike
VEH_SCALE = {"ThaiBicycleRed": 0.85, "ThaiBicycleBlue": 0.85, "ThaiRacingMoto": 0.9}


def scale_vehicle(prop, builders, k):
    for b in builders:
        b.v = [v * k for v in b.v]
    r = RIG[prop]
    for lst in r.values():
        if not isinstance(lst, list):
            continue
        for d in lst:
            if not isinstance(d, dict):
                continue
            for f in ("c", "s"):
                if f in d:
                    d[f] = [round(x * k, 3) for x in d[f]]
            for f in ("r", "w"):
                if f in d:
                    d[f] = round(d[f] * k, 3)


def main():
    os.makedirs(PREV, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    makers = [make_pickup, make_sedan, make_red_bike, make_blue_bike, make_tuktuk, make_moto, make_sound_truck, make_parade_truck]
    only = [s.strip() for s in ONLY.split(",") if s.strip()]
    for mk in makers:
        prop, builders = mk()
        if prop in VEH_SCALE:
            scale_vehicle(prop, builders, VEH_SCALE[prop])
        if only and prop not in only:
            continue
        log(prop)
        coll, objs = realize(prop, builders)
        export(prop, objs)
        preview(prop, objs, HUMAN_AT.get(prop))
        for o in objs:  # ชื่อ Wheel_FL ฯลฯ ซ้ำกันข้ามคัน: เติมชื่อคันหลัง export แล้ว คันถัดไปจะได้ชื่อสะอาด (ไม่มี .001)
            o.name = prop + ":" + o.name
            o.data.name = o.name
    path = os.path.join(ROOT, "ThaiVehicles_Rig.json")
    old = {}
    if only and os.path.exists(path):
        old = json.load(open(path, encoding="utf-8"))
    for prop, r in RIG.items():
        if only and prop not in only:
            continue
        r["bbox"] = OBJ_BBOX.get(prop, {})
        r["pal"] = {k: list(PAL[k]["c"]) + [PAL[k]["m"]] for k in sorted({p["k"] for p in r["proxy"]})}
        old[prop] = r
    json.dump(old, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for o in bpy.data.objects:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "thai_vehicles.blend"))


try:
    main()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(os.path.join(os.environ.get("VEH_LOG_DIR", ROOT), "thai_vehicles_build.log"), "w", encoding="utf-8").write("\n".join(LOG))
