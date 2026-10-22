# ชุดวัดไทยชนบท (สำหรับ Lobby) — สร้างด้วย Blender แบบ headless
# รัน:  blender-launcher.exe --background --factory-startup --python tools/blender/thai_temple.py
# ผลลัพธ์: assets/models/<Prop>.fbx + <Prop>_Color/_Normal/_Roughness/_Metalness.png,
#          assets/models/previews/<Prop>.png, assets/models/thai_temple.blend,
#          assets/models/ThaiTemple_Colliders.json (กล่องชนแบบ Part ให้ MapBuilder สร้าง)
# หน่วยตอนปั้นเป็น studs แล้วคูณ 0.28 ตอนสร้าง mesh (1 stud = 0.28 m) ด้านหน้าหันไป -Y
import bpy, bmesh, math, os, json, sys
import numpy as np
from mathutils import Vector, Matrix
from contextlib import contextmanager

S = 0.28
ROOT = r"C:\Aunival\pump-lot-anomaly\assets\models"
PREV = os.path.join(ROOT, "previews")
ONLY = os.environ.get("TEMPLE_ONLY", "")  # คั่นด้วย , เพื่อสร้างเฉพาะบาง prop
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s)


# ---------------------------------------------------------------- palette
# c = สี sRGB, r = roughness, m = metalness, p = ลาย
PAL = {
    "plaster_white": dict(c=(214, 210, 198), r=0.85, m=0, p="plaster"),
    "plaster_old": dict(c=(178, 172, 158), r=0.9, m=0, p="plaster"),
    "plaster_cream": dict(c=(206, 186, 150), r=0.85, m=0, p="plaster"),
    "plaster_pink": dict(c=(218, 172, 158), r=0.85, m=0, p="plaster"),
    "plaster_pinkband": dict(c=(198, 146, 132), r=0.85, m=0, p="plaster"),
    "plaster_red": dict(c=(146, 66, 56), r=0.85, m=0, p="plaster"),
    "plaster_beige": dict(c=(184, 164, 134), r=0.9, m=0, p="plaster"),
    "plaster_dark": dict(c=(112, 104, 96), r=0.9, m=0, p="plaster"),
    "gold": dict(c=(196, 150, 64), r=0.38, m=0.8, p="gold"),
    "gold_dark": dict(c=(150, 108, 46), r=0.5, m=0.7, p="gold"),
    "red_panel": dict(c=(136, 30, 28), r=0.6, m=0, p="plain"),
    "blue_panel": dict(c=(38, 58, 116), r=0.6, m=0, p="plain"),
    "roof_orange": dict(c=(186, 88, 40), r=0.6, m=0, p="tiles"),
    "roof_red": dict(c=(146, 44, 34), r=0.6, m=0, p="tiles"),
    "roof_brown": dict(c=(132, 70, 46), r=0.75, m=0, p="tiles"),
    "trim_green": dict(c=(42, 108, 70), r=0.6, m=0, p="plain"),
    "tin_green": dict(c=(48, 104, 70), r=0.55, m=0.35, p="corrugated"),
    "wood": dict(c=(134, 92, 60), r=0.8, m=0, p="grain"),
    "wood_dark": dict(c=(96, 66, 46), r=0.85, m=0, p="grain"),
    "wood_plank": dict(c=(128, 86, 54), r=0.85, m=0, p="planks"),
    "wood_red": dict(c=(112, 40, 30), r=0.7, m=0, p="grain"),
    "concrete": dict(c=(128, 126, 120), r=0.95, m=0, p="plaster"),
    "floor_tile": dict(c=(118, 62, 46), r=0.5, m=0, p="checker"),
    "floor_white": dict(c=(186, 182, 172), r=0.55, m=0, p="checker"),
    "iron_dark": dict(c=(46, 42, 40), r=0.6, m=0.6, p="plain"),
    "window_dark": dict(c=(22, 20, 19), r=0.9, m=0, p="plain"),
    "photo": dict(c=(150, 128, 100), r=0.3, m=0, p="photo"),
    "sign_dark": dict(c=(46, 34, 30), r=0.6, m=0, p="plaque"),
    "plaque_red": dict(c=(110, 26, 22), r=0.5, m=0, p="plaque"),
    "mosaic": dict(c=(60, 80, 120), r=0.25, m=0.3, p="mosaic"),
    "louver_white": dict(c=(200, 196, 186), r=0.8, m=0, p="louver"),
    "tile_green_panel": dict(c=(96, 122, 108), r=0.4, m=0, p="checker"),
    "buddha_gold": dict(c=(204, 152, 58), r=0.32, m=0.85, p="gold"),
    # ภาพใหญ่ 512x512 (feature) มุมซ้ายบนของ atlas
    "ped_gate": dict(c=(38, 58, 116), r=0.5, m=0.3, p="F_ped_gate"),
    "ped_gold": dict(c=(196, 150, 64), r=0.4, m=0.7, p="F_ped_gold"),
    "mosaic_front": dict(c=(60, 80, 120), r=0.25, m=0.4, p="F_mosaic"),
    # ของใน lobby: ป้ายบริจาค ตู้บริจาค รถเข็นขายของ
    "wood_teak": dict(c=(170, 116, 62), r=0.55, m=0, p="grain"),
    "sign_wood": dict(c=(70, 44, 30), r=0.6, m=0, p="grain"),
    "glass": dict(c=(170, 190, 200), r=0.05, m=0.1, p="plain"),
    "brass": dict(c=(200, 160, 80), r=0.3, m=0.9, p="gold"),
    "banknote": dict(c=(96, 140, 96), r=0.8, m=0, p="plain"),
    "banknote_red": dict(c=(170, 70, 64), r=0.8, m=0, p="plain"),
    "chain": dict(c=(150, 150, 150), r=0.4, m=0.9, p="plain"),
    "tire": dict(c=(30, 30, 30), r=0.9, m=0, p="plain"),
    "canopy": dict(c=(60, 90, 160), r=0.8, m=0, p="stripes"),
    "sign_white": dict(c=(220, 220, 214), r=0.6, m=0, p="plain"),
    "frame_blue": dict(c=(40, 70, 140), r=0.5, m=0.2, p="plain"),
    "snack_red": dict(c=(200, 50, 40), r=0.4, m=0, p="plain"),
    "snack_yellow": dict(c=(230, 190, 50), r=0.4, m=0, p="plain"),
    "snack_green": dict(c=(70, 160, 80), r=0.4, m=0, p="plain"),
    "snack_blue": dict(c=(60, 120, 200), r=0.4, m=0, p="plain"),
    "toy_pink": dict(c=(230, 130, 170), r=0.6, m=0, p="plain"),
    "bottle_clear": dict(c=(190, 210, 210), r=0.1, m=0, p="plain"),
    "basket": dict(c=(176, 136, 80), r=0.9, m=0, p="checker"),
    "price_green": dict(c=(120, 200, 90), r=0.6, m=0, p="plain"),
}
KEYS = list(PAL.keys())


# ---------------------------------------------------------------- geometry builder (studs)
class B:
    def __init__(s, name):
        s.name = name
        s.scale = SCALE_NOW
        s.v = []
        s.f = []
        s.k = []
        s.M = Matrix.Identity(4)
        s.smooth = False

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
        F = {
            "bottom": (3, 2, 1, 0),
            "top": (4, 5, 6, 7),
            "front": (0, 1, 5, 4),
            "right": (1, 2, 6, 5),
            "back": (2, 3, 7, 6),
            "left": (3, 0, 4, 7),
        }
        for n, q in F.items():
            if n in skip:
                continue
            s.face([i[j] for j in q], keys.get(n, key))

    def box(s, x0, x1, y0, y1, z0, z1, key, keys=None, skip=()):
        s.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], key, keys, skip)

    def boxc(s, cx, cy, cz, sx, sy, sz, key, keys=None, skip=()):
        s.box(cx - sx / 2, cx + sx / 2, cy - sy / 2, cy + sy / 2, cz - sz / 2, cz + sz / 2, key, keys, skip)

    def frustum(s, cx, cy, z0, z1, sx0, sy0, sx1, sy1, key, keys=None, skip=()):
        a, b, c, d = sx0 / 2, sy0 / 2, sx1 / 2, sy1 / 2
        s.hexa([(cx - a, cy - b, z0), (cx + a, cy - b, z0), (cx + a, cy + b, z0), (cx - a, cy + b, z0),
                (cx - c, cy - d, z1), (cx + c, cy - d, z1), (cx + c, cy + d, z1), (cx - c, cy + d, z1)], key, keys, skip)

    def lathe(s, cx, cy, prof, n, key, z0=0.0, sq=False):
        rings = []
        for r, z in prof:
            if r < 1e-4:
                rings.append([s._v((cx, cy, z0 + z))] * n)
            else:
                ring = []
                for j in range(n):
                    a = 2 * math.pi * j / n + (math.pi / 4 if sq else 0)
                    rr = r * (1.4142 if sq else 1)
                    ring.append(s._v((cx + rr * math.cos(a), cy + rr * math.sin(a), z0 + z)))
                rings.append(ring)
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(n):
                k = (j + 1) % n
                s.face([a[j], a[k], b[k], b[j]], key)
        if prof[0][0] > 1e-4:
            s.face(list(reversed(rings[0])), key)
        if prof[-1][0] > 1e-4:
            s.face(rings[-1], key)

    def ellipsoid(s, c, r, key, nu=14, nv=9):
        rings = []
        for i in range(nv + 1):
            t = math.pi * i / nv
            z, rr = -math.cos(t), math.sin(t)
            if rr < 1e-4:
                rings.append([s._v((c[0], c[1], c[2] + r[2] * z))] * nu)
            else:
                rings.append([s._v((c[0] + r[0] * rr * math.cos(2 * math.pi * j / nu),
                                    c[1] + r[1] * rr * math.sin(2 * math.pi * j / nu),
                                    c[2] + r[2] * z)) for j in range(nu)])
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(nu):
                k = (j + 1) % nu
                s.face([a[j], a[k], b[k], b[j]], key)

    def tube(s, pts, radii, key, n=6, cap=True):
        pts = [Vector(p) for p in pts]
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
                up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                nn = t.cross(up).normalized()
            else:
                nn = (prev_n - t * prev_n.dot(t)).normalized()
            prev_n = nn
            bb = t.cross(nn).normalized()
            r = radii[i]
            if r < 1e-4:
                rings.append([s._v(p)] * n)
            else:
                rings.append([s._v(p + (nn * math.cos(2 * math.pi * j / n) + bb * math.sin(2 * math.pi * j / n)) * r) for j in range(n)])
        for a, b in zip(rings[:-1], rings[1:]):
            for j in range(n):
                k = (j + 1) % n
                s.face([a[j], a[k], b[k], b[j]], key)
        if cap:
            if radii[0] > 1e-4:
                s.face(list(reversed(rings[0])), key)
            if radii[-1] > 1e-4:
                s.face(rings[-1], key)

    def beam(s, p0, p1, w, h, key, side=(0, 1, 0)):
        """กล่องยาวจาก p0 ไป p1 กว้าง w (ตามแกน side) สูง h (ตั้งฉาก)"""
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0).normalized()
        sd = Vector(side)
        sd = (sd - d * sd.dot(d)).normalized()
        up = d.cross(sd).normalized()
        if up.z < 0:
            up = -up
        a, b = sd * (w / 2), up * (h / 2)
        P = [p0 - a - b, p1 - a - b, p1 + a - b, p0 + a - b, p0 - a + b, p1 - a + b, p1 + a + b, p0 + a + b]
        s.hexa([tuple(p) for p in P], key)

    def prism_xz(s, poly, y0, y1, key, cap_key=None):
        """polygon ในระนาบ XZ ยืดตามแกน Y"""
        cap_key = cap_key or key
        a = [s._v((x, y0, z)) for x, z in poly]
        b = [s._v((x, y1, z)) for x, z in poly]
        n = len(poly)
        s.face(a, cap_key)
        s.face(list(reversed(b)), cap_key)
        for j in range(n):
            k = (j + 1) % n
            s.face([a[j], a[k], b[k], b[j]], key)

    def prism_yz(s, poly, x0, x1, key, cap_key=None):
        cap_key = cap_key or key
        a = [s._v((x0, y, z)) for y, z in poly]
        b = [s._v((x1, y, z)) for y, z in poly]
        n = len(poly)
        s.face(a, cap_key)
        s.face(list(reversed(b)), cap_key)
        for j in range(n):
            k = (j + 1) % n
            s.face([a[j], a[k], b[k], b[j]], key)

    def add_mesh_data(s, verts, faces, key):
        base = len(s.v)
        for v in verts:
            s.v.append(s.M @ Vector(v))
        for f in faces:
            s.face([base + i for i in f], key)


# ---------------------------------------------------------------- reusable ornaments
def lotus_bud(b, cx, cy, z0, r, h, key="gold", n=10):
    b.lathe(cx, cy, [(r * 0.55, 0), (r * 0.7, h * 0.08), (r, h * 0.3), (r * 0.85, h * 0.55), (r * 0.45, h * 0.8), (0, h)], n, key, z0)


def ball_finial(b, cx, cy, z0, r, key="gold"):
    b.lathe(cx, cy, [(r * 0.5, 0), (r * 0.3, r * 0.4), (r * 0.75, r * 0.7), (r, r * 1.3), (r * 0.75, r * 1.9), (r * 0.15, r * 2.3), (0, r * 3.2)], 10, key, z0)


def chofa(b, x, y, z, o, sc=1.0, key="gold"):
    """ช่อฟ้า: ปลายโค้งขึ้นและงอนออกด้านนอก (o = ทิศ Y ด้านนอก)"""
    P = [(x, y, z), (x, y + o * 0.3 * sc, z + 1.2 * sc), (x, y + o * 0.8 * sc, z + 2.0 * sc),
         (x, y + o * 1.4 * sc, z + 2.3 * sc), (x, y + o * 1.9 * sc, z + 2.1 * sc), (x, y + o * 2.2 * sc, z + 1.7 * sc)]
    b.tube(P, [0.36 * sc, 0.3 * sc, 0.24 * sc, 0.18 * sc, 0.1 * sc, 0.02], key, 6)


def hanghong(b, x, y, z, side, o, sc=1.0, key="gold"):
    """หางหงส์ที่ปลายป้านลม ม้วนขึ้น"""
    P = [(x, y, z), (x + side * 0.6 * sc, y + o * 0.15 * sc, z + 0.2 * sc), (x + side * 0.95 * sc, y + o * 0.3 * sc, z + 0.8 * sc),
         (x + side * 0.7 * sc, y + o * 0.4 * sc, z + 1.4 * sc), (x + side * 0.3 * sc, y + o * 0.45 * sc, z + 1.4 * sc)]
    b.tube(P, [0.28 * sc, 0.24 * sc, 0.18 * sc, 0.12 * sc, 0.03], key, 6)


def gable_slabs(b, y0, y1, xe, ze, zr, th, key, under="wood_dark", edge=None):
    edge = edge or key
    for sd in (-1, 1):
        e0, r0, r1, e1 = (sd * xe, y0, ze), (0, y0, zr), (0, y1, zr), (sd * xe, y1, ze)
        P = [(p[0], p[1], p[2] - th) for p in (e0, r0, r1, e1)] + [e0, r0, r1, e1]
        b.hexa(P, edge, {"top": key, "bottom": under})


def skirt_slabs(b, y0, y1, xi, zi, xo, zo, th, key, under="wood_dark", edge=None):
    edge = edge or key
    for sd in (-1, 1):
        a0, a1, b1, b0 = (sd * xi, y0, zi), (sd * xi, y1, zi), (sd * xo, y1, zo), (sd * xo, y0, zo)
        P = [(p[0], p[1], p[2] - th) for p in (b0, a0, a1, b1)] + [b0, a0, a1, b1]
        b.hexa(P, edge, {"top": key, "bottom": under})


def gable_end(b, y, xe, ze, zr, o, ped_key, sc=1.0, ped_depth=0.5, teeth=True, chofa_on=True, gold="gold"):
    """หน้าบัน + ป้านลมใบระกา + ช่อฟ้า + หางหงส์ ที่ระนาบ y (o = ทิศด้านนอก)"""
    inset = 0.25
    tri = [(-xe + inset * 2, ze), (xe - inset * 2, ze), (0, zr - inset * 1.5)]
    b.prism_xz(tri, y - o * ped_depth, y, "gold_dark", ped_key)
    # คานใต้หน้าบัน
    b.box(-xe + 0.3, xe - 0.3, min(y, y + o * 0.35), max(y, y + o * 0.35), ze - 0.7, ze, gold)
    for sd in (-1, 1):
        p0 = Vector((sd * (xe + 0.35), y + o * 0.15, ze - 0.25))
        p1 = Vector((0, y + o * 0.15, zr + 0.35))
        b.beam(p0, p1, 0.55 * sc + 0.1, 0.8 * sc, gold)
        if teeth:
            d = (p1 - p0)
            L = d.length
            d.normalize()
            perp = Vector((-d.z, 0, d.x))  # ตั้งฉากกับแนวป้านลม ชี้ขึ้น
            if perp.z < 0:
                perp = -perp
            step = 0.75 * sc
            cnt = int(L / step) - 1
            for i in range(1, cnt):
                c = p0 + d * (i * step) + perp * (0.38 * sc)
                tip = c + perp * (0.55 * sc) - d * (0.25 * sc)
                poly = [(c.x - d.x * 0.22 * sc, c.z - d.z * 0.22 * sc), (c.x + d.x * 0.22 * sc, c.z + d.z * 0.22 * sc), (tip.x, tip.z)]
                b.prism_xz(poly, y + o * 0.05, y + o * 0.27, gold)
        hanghong(b, sd * (xe + 0.4), y + o * 0.15, ze - 0.3, sd, o, sc * 1.0, gold)
    if chofa_on:
        chofa(b, 0, y + o * 0.15, zr + 0.5, o, sc * 1.15, gold)


def balusters(b, x0, y0, x1, y1, z0, z1, thick, key, rail_key=None, step=0.9, bal=0.32, skip_bottom=False):
    """รั้วลูกกรง: ราวล่าง ราวบน และลูกกรงสี่เหลี่ยม ตามแนว (x0,y0)->(x1,y1) แนวแกนเดียว"""
    rail_key = rail_key or key
    horiz = abs(x1 - x0) > abs(y1 - y0)
    if horiz:
        xa, xb = min(x0, x1), max(x0, x1)
        b.box(xa, xb, y0 - thick / 2, y0 + thick / 2, z0, z0 + 0.5, rail_key)
        b.box(xa, xb, y0 - thick / 2 - 0.08, y0 + thick / 2 + 0.08, z1 - 0.45, z1, rail_key)
        n = max(1, int((xb - xa) / step))
        for i in range(n):
            x = xa + (i + 0.5) * (xb - xa) / n
            b.box(x - bal / 2, x + bal / 2, y0 - bal / 2, y0 + bal / 2, z0 + 0.5, z1 - 0.45, key, skip=("top", "bottom"))
    else:
        ya, yb = min(y0, y1), max(y0, y1)
        b.box(x0 - thick / 2, x0 + thick / 2, ya, yb, z0, z0 + 0.5, rail_key)
        b.box(x0 - thick / 2 - 0.08, x0 + thick / 2 + 0.08, ya, yb, z1 - 0.45, z1, rail_key)
        n = max(1, int((yb - ya) / step))
        for i in range(n):
            y = ya + (i + 0.5) * (yb - ya) / n
            b.box(x0 - bal / 2, x0 + bal / 2, y - bal / 2, y + bal / 2, z0 + 0.5, z1 - 0.45, key, skip=("top", "bottom"))


# ---------------------------------------------------------------- Buddha (ปางมารวิชัย)
def buddha_body(scale=1.0, target=6500):
    """ปั้นจาก primitive แล้ว voxel remesh ให้เป็นเนื้อเดียว คืนค่า (verts, faces) หน่วย studs"""
    b = B("tmp")
    g = "buddha_gold"
    b.ellipsoid((0, 0.05, 0.42), (1.55, 0.95, 0.42), g)           # ตัก/ขาขัดสมาธิ
    b.tube([(-1.35, -0.5, 0.32), (0, -0.62, 0.36), (1.35, -0.5, 0.32)], [0.3, 0.34, 0.3], g, 10)  # หน้าแข้ง
    b.ellipsoid((-0.75, -0.75, 0.3), (0.32, 0.22, 0.12), g)       # ฝ่าเท้าขวาหงาย
    b.ellipsoid((0, 0.08, 1.15), (0.62, 0.42, 0.55), g)           # ท้อง
    b.ellipsoid((0, 0.1, 1.72), (0.76, 0.43, 0.58), g)            # อก
    for sd in (-1, 1):
        b.ellipsoid((sd * 0.7, 0.12, 2.1), (0.3, 0.3, 0.28), g)   # ไหล่
    b.tube([(0, 0.12, 2.2), (0, 0.1, 2.5)], [0.23, 0.21], g, 10)  # คอ
    b.ellipsoid((0, 0.06, 2.8), (0.37, 0.4, 0.46), g)             # ศีรษะ
    b.ellipsoid((0, 0.1, 3.22), (0.25, 0.25, 0.22), g)            # อุษณีษะ
    for sd in (-1, 1):
        b.boxc(sd * 0.38, 0.12, 2.62, 0.09, 0.16, 0.55, g)        # ติ่งหูยาว
    # แขนขวา (−X) วางบนเข่า นิ้วชี้ลงดิน
    b.tube([(-0.78, 0.12, 2.08), (-0.98, 0.0, 1.55), (-1.02, -0.12, 1.25)], [0.2, 0.18, 0.17], g, 10)
    b.tube([(-1.02, -0.12, 1.25), (-1.05, -0.5, 0.95), (-1.05, -0.78, 0.7), (-1.05, -0.92, 0.42)], [0.17, 0.15, 0.14, 0.12], g, 10)
    # แขนซ้าย (+X) วางมือหงายบนตัก
    b.tube([(0.78, 0.12, 2.08), (0.95, 0.02, 1.55), (0.9, -0.12, 1.2)], [0.2, 0.18, 0.17], g, 10)
    b.tube([(0.9, -0.12, 1.2), (0.55, -0.35, 0.95), (0.18, -0.42, 0.88)], [0.17, 0.15, 0.13], g, 10)
    b.ellipsoid((0.1, -0.42, 0.86), (0.28, 0.2, 0.08), g)         # ฝ่ามือในตัก
    mesh = bpy.data.meshes.new("tmp_buddha")
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in b.v]
    for f in b.f:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    ob = bpy.data.objects.new("tmp_buddha", mesh)
    bpy.context.scene.collection.objects.link(ob)
    rm = ob.modifiers.new("rm", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = 0.045
    sm = ob.modifiers.new("sm", "CORRECTIVE_SMOOTH")
    sm.iterations = 6
    sm.smooth_type = "SIMPLE"
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    ob.evaluated_get(dg).to_mesh_clear()
    dec = ob.modifiers.new("dec", "DECIMATE")
    dec.ratio = min(1.0, target / max(1, tris))
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = ev.to_mesh()
    verts = [tuple(v.co * scale) for v in me.vertices]
    faces = [tuple(p.vertices) for p in me.polygons]
    ev.to_mesh_clear()
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(mesh)
    return verts, faces


def buddha(b, cx, cy, z0, scale, target=6500):
    """พระพุทธรูปพร้อมฐานบัว + เปลวรัศมี (z0 = พื้นฐานบัว)"""
    verts, faces = buddha_body(scale, target)
    seat_h = 0.55 * scale
    with b.xf(Matrix.Translation((cx, cy, z0 + seat_h))):
        b.add_mesh_data(verts, faces, "buddha_gold")
        lotus_bud(b, 0, 0.1 * scale, 3.38 * scale, 0.14 * scale, 1.2 * scale, "buddha_gold", 8)  # เปลวรัศมี
    # ฐานบัวคว่ำบัวหงาย
    b.lathe(cx, cy, [(1.45 * scale, 0), (1.62 * scale, 0.12 * scale), (1.5 * scale, 0.22 * scale), (1.3 * scale, 0.3 * scale),
                     (1.5 * scale, 0.42 * scale), (1.68 * scale, seat_h), (0.01, seat_h)], 16, "gold", z0)
    for i in range(16):
        a = 2 * math.pi * (i + 0.5) / 16
        r = 1.62 * scale
        b.ellipsoid((cx + r * math.cos(a), cy + r * 0.62 * math.sin(a), z0 + 0.42 * scale), (0.2 * scale, 0.2 * scale, 0.16 * scale), "gold", 6, 4)
    b.smooth = True


# ---------------------------------------------------------------- props
COLLIDERS = {}
# ขยายทั้งหลังให้ผู้เล่น 4 คนเดินสวนกันได้สบาย (ประตู ≥ 8 กว้าง, ≥ 10 สูง, ช่องเสา ≥ 8, เพดาน ≥ 12)
PROP_SCALE = {"Ubosot": 1.3, "Meru": 1.15, "Kuti": 1.5, "Sala": 1.15}
SCALE_NOW = 1.0
OBJ_BBOX = {}


def col(prop, x0, x1, y0, y1, z0, z1, name="Col"):
    x0, x1, y0, y1, z0, z1 = (v * SCALE_NOW for v in (x0, x1, y0, y1, z0, z1))
    COLLIDERS.setdefault(prop, []).append(dict(n=name, mn=[x0, y0, z0], mx=[x1, y1, z1]))


def make_gate():
    P = "TempleGate"
    g = B("TempleGate")
    W = 7.0  # ครึ่งความกว้างช่องประตู
    for sd in (-1, 1):
        x = sd * (W + 1.25)
        g.boxc(x, 0, 0.6, 3.2, 3.2, 1.2, "plaster_cream")
        g.box(x - 1.25, x + 1.25, -1.25, 1.25, 1.2, 16.0, "gold")
        for o in (-1, 1):  # แผงแดงฝังในเสา
            g.box(x - 0.7, x + 0.7, o * 1.25 - 0.06, o * 1.25 + 0.06, 2.4, 14.8, "red_panel")
            for zz in (4.0, 8.0, 12.0):
                g.boxc(x, o * 1.32, zz, 0.9, 0.12, 0.9, "gold")
        g.boxc(x, 0, 16.55, 3.3, 3.3, 1.1, "gold")
        col(P, x - 1.6, x + 1.6, -1.6, 1.6, 0, 17.1)
    g.box(-10.2, 10.2, -1.6, 1.6, 17.1, 19.5, "gold")
    for o in (-1, 1):
        g.box(-6.5, 6.5, o * 1.6 - 0.07, o * 1.6 + 0.07, 17.5, 19.1, "blue_panel")
    # เปลวไฟประดับปลายคาน
    for sd in (-1, 1):
        for o in (-1, 1):
            hanghong(g, sd * 10.2, o * 1.0, 18.0, sd, 0, 1.5, "red_panel")
    # หน้าบันทรงจั่ว
    xe, ze, zr = 10.8, 19.5, 30.5
    tri = [(-xe, ze), (xe, ze), (0, zr)]
    g.prism_xz(tri, -0.65, 0.65, "gold_dark", "ped_gate")
    for o in (-1, 1):
        y = o * 0.65
        for sd in (-1, 1):
            p0 = Vector((sd * (xe + 0.5), y + o * 0.2, ze - 0.2))
            p1 = Vector((0, y + o * 0.2, zr + 0.5))
            g.beam(p0, p1, 0.5, 1.0, "gold")
            hanghong(g, sd * (xe + 0.6), y + o * 0.2, ze - 0.2, sd, o, 1.3, "gold")
            d = (p1 - p0)
            L = d.length
            d.normalize()
            perp = Vector((-d.z, 0, d.x))
            if perp.z < 0:
                perp = -perp
            for i in range(1, int(L / 1.0) - 1):
                c = p0 + d * (i * 1.0) + perp * 0.45
                tip = c + perp * 0.7 - d * 0.3
                g.prism_xz([(c.x - d.x * 0.3, c.z - d.z * 0.3), (c.x + d.x * 0.3, c.z + d.z * 0.3), (tip.x, tip.z)], y + o * 0.1, y + o * 0.32, "gold")
        chofa(g, 0, y + o * 0.2, zr + 0.6, o, 1.3, "gold")
        # ซุ้มจระนำรอบพระ (กรอบโค้งทอง)
        arch = []
        for i in range(13):
            a = math.pi * i / 12
            arch.append((math.cos(a) * 2.3, 21.6 + math.sin(a) * 3.2 + 2.2 * math.sin(a) ** 6))
        g.tube([(p[0], y + o * 0.08, p[1]) for p in arch], [0.18] * len(arch), "gold", 6)
        g.box(-2.6, 2.6, min(y, y + o * 0.8), max(y, y + o * 0.8), 20.6, 21.0, "gold")  # หิ้งรองพระ
    bud = B("TempleGate_Buddha")
    for o in (-1, 1):
        buddha(bud, 0, o * 1.05, 21.0, 0.62, 3200)
    # ป้ายชื่อวัด (กำแพงปูน + หัวเสาทอง) + แผ่นป้าย
    sg = B("TempleNameSign")
    sg.box(-7.5, 7.5, -0.7, 0.7, 0, 0.6, "plaster_dark")
    sg.box(-7.2, 7.2, -0.6, 0.6, 0.6, 4.6, "plaster_cream")
    sg.box(-7.5, 7.5, -0.75, 0.75, 4.6, 5.0, "plaster_cream")
    for x in (-7.2, 0.0, 7.2):
        sg.boxc(x, 0, 2.9, 1.2, 1.5, 5.8, "plaster_cream")
        sg.boxc(x, 0, 5.95, 1.5, 1.7, 0.35, "gold")
        lotus_bud(sg, x, 0, 6.1, 0.45, 1.5)
    for xa, xb in ((-6.5, -0.7), (0.7, 6.5)):
        sg.box(xa - 0.12, xb + 0.12, -0.72, -0.6, 1.0, 4.2, "gold")
    col("TempleNameSign", -7.5, 7.5, -0.8, 0.8, 0, 5.0)
    plq = B("TempleNameSign_Plaque")
    plq.box(-6.5, -0.7, -0.82, -0.72, 1.15, 4.05, "sign_dark")
    plq.box(0.7, 6.5, -0.82, -0.72, 1.15, 4.05, "sign_dark")
    return P, [g, bud, sg, plq]


def fence_segment(name, L):
    f = B(name)
    # กำแพงจาก x=0.8 ถึง L-0.8 เสาอยู่ที่ x = L
    f.box(0.75, L - 0.75, -0.65, 0.65, 0, 0.6, "plaster_dark")
    f.box(0.8, L - 0.8, -0.5, 0.5, 0.6, 3.3, "plaster_pink")
    f.box(0.8, L - 0.8, -0.55, 0.55, 3.3, 4.0, "plaster_pinkband")
    f.box(0.75, L - 0.75, -0.68, 0.68, 4.0, 4.35, "plaster_pink")
    # ช่องลึกแบ่งแผง
    n = max(1, round((L - 1.6) / 3.0))
    for i in range(1, n):
        x = 0.8 + i * (L - 1.6) / n
        for o in (-1, 1):
            f.box(x - 0.18, x + 0.18, o * 0.5 - 0.05, o * 0.5 + 0.05, 0.6, 3.3, "plaster_pinkband")
    # ลายฝักเพกาทองตามแนวคาดบน
    k = int((L - 1.6) / 0.6)
    for i in range(k):
        x = 0.8 + (i + 0.5) * (L - 1.6) / k
        for o in (-1, 1):
            f.prism_xz([(x - 0.2, 3.95), (x + 0.2, 3.95), (x + 0.05, 3.35), (x, 3.15), (x - 0.05, 3.35)], o * 0.55, o * 0.62, "gold")
    for i in range(int(L / 1.2)):
        x = 0.8 + (i + 0.5) * (L - 1.6) / int(L / 1.2)
        f.lathe(x, 0, [(0.16, 0), (0.2, 0.15), (0.1, 0.45), (0, 0.75)], 6, "gold", 4.35)
    return f


def fence_post(f, x):
    f.box(x - 0.85, x + 0.85, -0.85, 0.85, 0, 0.6, "plaster_dark")
    f.box(x - 0.75, x + 0.75, -0.75, 0.75, 0.6, 5.0, "plaster_pink")
    f.box(x - 0.82, x + 0.82, -0.82, 0.82, 4.2, 4.5, "gold")
    f.box(x - 0.95, x + 0.95, -0.95, 0.95, 5.0, 5.4, "plaster_pink")
    f.box(x - 0.7, x + 0.7, -0.7, 0.7, 5.4, 5.7, "plaster_pinkband")
    ball_finial(f, x, 0, 5.7, 0.5)


def make_fence():
    P = "TempleFence"
    seg = fence_segment("FenceSegment", 12.0)
    fence_post(seg, 12.0)
    half = fence_segment("FenceSegment_Half", 6.0)
    fence_post(half, 6.0)
    post = B("FencePost")
    fence_post(post, 0.0)
    col("FenceSegment", 0.8, 11.2, -0.6, 0.6, 0, 4.4, "Wall")
    col("FenceSegment", 11.15, 12.85, -0.85, 0.85, 0, 5.4, "Post")
    col("FenceSegment_Half", 0.8, 5.2, -0.6, 0.6, 0, 4.4, "Wall")
    col("FenceSegment_Half", 5.15, 6.85, -0.85, 0.85, 0, 5.4, "Post")
    col("FencePost", -0.85, 0.85, -0.85, 0.85, 0, 5.4, "Post")
    return P, [seg, half, post]


def stupa_square(name, k=1.0, white="plaster_white"):
    s = B(name)
    z = 0.0
    tiers = [(4.6, 0.9), (3.9, 0.7), (3.3, 0.6)]
    for w, h in tiers:
        w *= k
        h *= k
        s.boxc(0, 0, z + h / 2, w, w, h, white)
        s.box(-w / 2 - 0.04, w / 2 + 0.04, -w / 2 - 0.04, w / 2 + 0.04, z + h - 0.14 * k, z + h - 0.02, "gold")
        z += h
    bw, bh = 2.7 * k, 3.6 * k
    s.boxc(0, 0, z + bh / 2, bw, bw, bh, white)
    # ช่องใส่รูปผู้ตายด้านหน้า + ลายทองด้านอื่น
    s.box(-0.72 * k, 0.72 * k, -bw / 2 - 0.12, -bw / 2 + 0.02, z + 1.0 * k, z + 2.9 * k, "gold")
    s.box(-0.55 * k, 0.55 * k, -bw / 2 - 0.16, -bw / 2 - 0.1, z + 1.2 * k, z + 2.7 * k, "photo")
    for ang in (90, 180, 270):
        with s.xf(Matrix.Rotation(math.radians(ang), 4, "Z")):
            s.box(-0.6 * k, 0.6 * k, -bw / 2 - 0.08, -bw / 2 + 0.02, z + 0.8 * k, z + 2.9 * k, "gold_dark")
            s.prism_xz([(-0.6 * k, z + 2.9 * k), (0.6 * k, z + 2.9 * k), (0, z + 3.4 * k)], -bw / 2 - 0.08, -bw / 2 + 0.02, "gold")
    s.prism_xz([(-0.72 * k, z + 2.9 * k), (0.72 * k, z + 2.9 * k), (0, z + 3.45 * k)], -bw / 2 - 0.12, -bw / 2 + 0.02, "gold")
    for sx in (-1, 1):  # เสามุมเรือนธาตุ
        for sy in (-1, 1):
            s.boxc(sx * (bw / 2), sy * (bw / 2), z + bh / 2, 0.35 * k, 0.35 * k, bh, white)
    z += bh
    s.boxc(0, 0, z + 0.25 * k, 3.3 * k, 3.3 * k, 0.5 * k, white)
    s.box(-1.68 * k, 1.68 * k, -1.68 * k, 1.68 * k, z + 0.36 * k, z + 0.48 * k, "gold")
    z += 0.5 * k
    s.frustum(0, 0, z, z + 0.7 * k, 3.0 * k, 3.0 * k, 2.1 * k, 2.1 * k, white)
    z += 0.7 * k
    s.boxc(0, 0, z + 0.8 * k, 2.0 * k, 2.0 * k, 1.6 * k, white)
    for ang in (0, 90, 180, 270):
        with s.xf(Matrix.Rotation(math.radians(ang), 4, "Z")):
            s.prism_xz([(-0.45 * k, z + 0.2 * k), (0.45 * k, z + 0.2 * k), (0.45 * k, z + 1.0 * k), (0, z + 1.45 * k), (-0.45 * k, z + 1.0 * k)], -1.0 * k - 0.06, -1.0 * k + 0.02, "gold")
    z += 1.6 * k
    s.boxc(0, 0, z + 0.2 * k, 2.4 * k, 2.4 * k, 0.4 * k, white)
    z += 0.4 * k
    prof = [(1.05, 0), (1.0, 0.3), (0.85, 0.6), (0.7, 0.75), (0.62, 0.95), (0.7, 1.05), (0.5, 1.2), (0.55, 1.35), (0.42, 1.5),
            (0.46, 1.65), (0.33, 1.8), (0.25, 2.4), (0.18, 3.0), (0.1, 3.6)]
    s.lathe(0, 0, [(r * k, h * k) for r, h in prof], 8, white, z, sq=True)
    for zz in (0.75, 1.05, 1.35, 1.65):
        s.lathe(0, 0, [(0.68 * k * (1 - zz * 0.22), 0), (0.72 * k * (1 - zz * 0.22), 0.05 * k), (0.68 * k * (1 - zz * 0.22), 0.1 * k)], 8, "gold", z + zz * k - 0.05 * k, sq=True)
    z += 3.6 * k
    s.lathe(0, 0, [(0.12 * k, 0), (0.16 * k, 0.2 * k), (0.08 * k, 0.6 * k), (0, 1.2 * k)], 8, "gold", z)
    return s


def stupa_round(name, k=1.0, white="plaster_old"):
    s = B(name)
    s.boxc(0, 0, 0.45 * k, 4.0 * k, 4.0 * k, 0.9 * k, white)
    s.box(-2.04 * k, 2.04 * k, -2.04 * k, 2.04 * k, 0.75 * k, 0.88 * k, "gold")
    s.boxc(0, 0, 1.2 * k, 3.3 * k, 3.3 * k, 0.6 * k, white)
    s.boxc(0, 0, 2.9 * k, 2.4 * k, 2.4 * k, 2.8 * k, white)
    s.box(-0.6 * k, 0.6 * k, -1.32 * k, -1.18 * k, 2.0 * k, 3.8 * k, "gold")
    s.box(-0.45 * k, 0.45 * k, -1.36 * k, -1.3 * k, 2.2 * k, 3.6 * k, "photo")
    s.boxc(0, 0, 4.5 * k, 2.9 * k, 2.9 * k, 0.4 * k, white)
    prof = [(1.25, 0), (1.35, 0.15), (1.2, 0.3), (1.35, 0.45), (1.3, 0.9), (1.1, 1.5), (0.7, 2.0), (0.45, 2.15), (0.5, 2.3), (0.35, 2.45),
            (0.38, 2.6), (0.26, 2.75), (0.18, 3.6), (0.1, 4.2)]
    s.lathe(0, 0, [(r * k, h * k) for r, h in prof], 14, white, 4.7 * k)
    s.lathe(0, 0, [(1.37 * k, 0), (1.4 * k, 0.07 * k), (1.37 * k, 0.14 * k)], 14, "gold", 4.7 * k + 0.4 * k)
    s.lathe(0, 0, [(0.12 * k, 0), (0.15 * k, 0.2 * k), (0.07 * k, 0.6 * k), (0, 1.1 * k)], 8, "gold", 4.7 * k + 4.2 * k)
    return s


def make_stupas():
    P = "BoneStupa"
    a = stupa_square("BoneStupa_A", 1.0, "plaster_white")
    b = stupa_round("BoneStupa_B", 1.0, "plaster_old")
    c = stupa_square("BoneStupa_C", 0.72, "plaster_old")
    col("BoneStupa_A", -2.3, 2.3, -2.3, 2.3, 0, 6.0)
    col("BoneStupa_B", -2.0, 2.0, -2.0, 2.0, 0, 5.0)
    col("BoneStupa_C", -1.66, 1.66, -1.66, 1.66, 0, 4.3)
    return P, [a, b, c]


def stairs(b, x0, x1, y_top, z_top, n, run, key, o=-1, prop=None, cname="Step"):
    """บันได n ขั้นลงทาง o (−1 = −Y) จากขอบ y_top ที่ระดับพื้น z_top"""
    rise = z_top / (n + 1)
    for i in range(n):
        top = z_top - rise * (i + 1)
        ya, yb = sorted((y_top + o * run * i, y_top + o * run * (i + 1)))
        b.box(x0, x1, ya, yb, 0, top, key, skip=("bottom",))
        if prop:
            col(prop, x0, x1, ya, yb, 0, top, cname)
    return y_top + o * run * n


def make_meru():
    P = "Meru"
    base = B("Meru_Base")
    base.box(-11.5, 11.5, -9.5, 9.5, 0, 0.6, "plaster_dark")
    base.box(-11, 11, -9, 9, 0.6, 4.5, "plaster_cream", {"top": "floor_tile"})
    base.box(-11.3, 11.3, -9.3, 9.3, 4.1, 4.5, "plaster_cream", {"top": "floor_tile"})
    for xa, xb in ((-10.2, -6.2), (6.2, 10.2)):  # แผงกระเบื้องหน้าฐาน
        base.box(xa, xb, -9.12, -9.0, 1.1, 3.6, "tile_green_panel")
    col(P, -11.3, 11.3, -9.3, 9.3, 0, 4.5, "Base")
    yb = stairs(base, -4, 4, -9.0, 4.5, 7, 1.0, "plaster_white", prop=P)
    for sd in (-1, 1):  # ราวบันไดลาดเอียง
        x0, x1 = sd * 4.0, sd * 4.8
        xa, xb = min(x0, x1), max(x0, x1)
        base.hexa([(xa, yb, 0), (xb, yb, 0), (xb, -9.0, 0), (xa, -9.0, 0),
                   (xa, yb, 1.3), (xb, yb, 1.3), (xb, -9.0, 5.8), (xa, -9.0, 5.8)], "plaster_red")
        base.boxc(sd * 4.4, yb + 0.4, 0.9, 1.0, 1.0, 1.8, "plaster_red")
        ball_finial(base, sd * 4.4, yb + 0.4, 1.8, 0.3)
    hall = B("Meru_Hall")
    for x in (-9.6, -4.6, 4.6, 9.6):
        for y in (-7.6, 7.6):
            hall.boxc(x, y, 10.0, 1.1, 1.1, 11.0, "plaster_white")
            hall.boxc(x, y, 15.2, 1.4, 1.4, 0.6, "gold")
            col(P, x - 0.55, x + 0.55, y - 0.55, y + 0.55, 4.5, 15.5, "Column")
    for x in (-9.6, 9.6):
        hall.boxc(x, 0, 10.0, 1.1, 1.1, 11.0, "plaster_white")
        hall.boxc(x, 0, 15.2, 1.4, 1.4, 0.6, "gold")
        for ya, yb2 in ((-7.0, -0.6), (0.6, 7.0)):
            balusters(hall, x, ya, x, yb2, 4.5, 6.8, 0.5, "plaster_red", "plaster_pink")
        col(P, x - 0.4, x + 0.4, -7.6, 7.6, 4.5, 6.8, "Rail")
    hall.box(-10.2, 10.2, -8.0, -7.2, 15.0, 15.6, "gold_dark")
    hall.box(-10.2, 10.2, 7.2, 8.0, 15.0, 15.6, "gold_dark")
    # ห้องเผา
    hall.box(-3.5, 3.5, -1.0, 6.4, 4.5, 10.4, "plaster_cream")
    hall.box(-3.8, 3.8, -1.3, 6.7, 10.4, 10.9, "plaster_cream")
    hall.box(-1.6, 1.6, -1.12, -0.98, 5.0, 8.4, "iron_dark")
    hall.box(-2.1, 2.1, -1.2, -1.0, 8.4, 8.8, "gold")
    for sd in (-1, 1):
        hall.box(min(sd * 1.6, sd * 2.1), max(sd * 1.6, sd * 2.1), -1.2, -1.0, 5.0, 8.8, "gold")
        hall.box(sd * 2.6 - 0.5, sd * 2.6 + 0.5, -1.06, -0.98, 5.0, 9.8, "tile_green_panel")
    hall.prism_xz([(-2.1, 8.8), (2.1, 8.8), (0, 10.2)], -1.2, -1.0, "gold")
    col(P, -3.8, 3.8, -1.3, 6.7, 4.5, 10.9, "Chamber")
    roof = B("Meru_Roof")
    gable_slabs(roof, -9.6, 9.6, 10.6, 12.6, 19.6, 0.45, "roof_red", "wood_dark", "roof_red")
    skirt_slabs(roof, -9.6, 9.6, 10.4, 12.75, 12.7, 10.9, 0.4, "roof_red", "wood_dark")
    gable_slabs(roof, -11.4, -9.6, 10.1, 12.3, 18.4, 0.45, "roof_red", "wood_dark", "roof_red")
    for sd in (-1, 1):
        roof.box(sd * 12.7 - 0.2, sd * 12.7 + 0.2, -9.6, 9.6, 10.6, 11.0, "trim_green")
    roof.box(-0.35, 0.35, -11.4, 9.6, 18.3, 19.9, "roof_red")
    gable_end(roof, -11.4, 10.1, 12.3, 18.4, -1, "ped_gold", 1.0)
    gable_end(roof, -9.6, 10.6, 12.6, 19.6, -1, "ped_gold", 1.0, teeth=True)
    gable_end(roof, 9.6, 10.6, 12.6, 19.6, 1, "ped_gold", 1.0)
    roof.v = [v + Vector((0, 0, 3.0)) for v in roof.v]  # ยกหลังคาตามเสาที่สูงขึ้น
    chim = B("Meru_Chimney")
    chim.frustum(0, 6.6, 4.5, 47.0, 4.6, 4.6, 2.6, 2.6, "plaster_beige")
    for zz in (20.5, 30.0, 39.5):
        t = (zz - 4.5) / 42.5
        w = 4.6 + (2.6 - 4.6) * t + 0.3
        chim.boxc(0, 6.6, zz, w, w, 0.5, "plaster_dark")
    chim.frustum(0, 6.6, 47.0, 48.2, 2.7, 2.7, 3.4, 3.4, "plaster_beige")
    chim.box(-1.75, 1.75, 4.85, 8.35, 48.2, 49.0, "plaster_dark")
    col(P, -2.3, 2.3, 4.3, 8.9, 4.5, 30.0, "Chimney")
    return P, [base, hall, roof, chim]


def window_frame(b, axis_x, sd, y, z0, z1, w=2.6):
    """หน้าต่างซุ้มทองบนผนังข้าง (ผนังอยู่ที่ x = sd*axis_x)"""
    x = sd * axis_x
    o = sd
    b.box(min(x, x + o * 0.16), max(x, x + o * 0.16), y - w / 2, y + w / 2, z0, z1, "wood_red")
    b.box(min(x, x + o * 0.3), max(x, x + o * 0.3), y - w / 2 - 0.45, y - w / 2, z0 - 0.3, z1, "gold")
    b.box(min(x, x + o * 0.3), max(x, x + o * 0.3), y + w / 2, y + w / 2 + 0.45, z0 - 0.3, z1, "gold")
    b.box(min(x, x + o * 0.34), max(x, x + o * 0.34), y - w / 2 - 0.6, y + w / 2 + 0.6, z0 - 0.5, z0 - 0.15, "gold")
    b.prism_yz([(y - w / 2 - 0.6, z1), (y + w / 2 + 0.6, z1), (y + 0.25, z1 + 2.0), (y, z1 + 2.6), (y - 0.25, z1 + 2.0)],
               min(x, x + o * 0.3), max(x, x + o * 0.3), "gold")
    b.box(min(x, x + o * 0.22), max(x, x + o * 0.22), y - 0.06, y + 0.06, z0, z1, "gold")


def make_ubosot():
    P = "Ubosot"
    base = B("Ubosot_Base")
    base.box(-12.8, 12.8, -22.3, 17.8, 0, 0.5, "plaster_dark")
    base.box(-12.5, 12.5, -22, 17.5, 0.5, 2.2, "plaster_white", {"top": "floor_tile"})
    for x in range(-11, 12, 2):  # ลูกกรงลวดลายฐาน
        base.box(x - 0.3, x + 0.3, -22.08, -22.0, 0.8, 1.9, "plaster_old")
    col(P, -12.5, 12.5, -22, 17.5, 0, 2.2, "Base")
    stairs(base, -4.0, 4.0, -22.0, 2.2, 3, 0.85, "plaster_white", prop=P)
    walls = B("Ubosot_Walls")
    wz0, wz1 = 2.2, 14.2
    walls.box(-8, -3.6, -13, -12, wz0, wz1, "plaster_white")
    walls.box(3.6, 8, -13, -12, wz0, wz1, "plaster_white")
    walls.box(-3.6, 3.6, -13, -12, 11.0, wz1, "plaster_white")
    walls.box(-8, 8, 14, 15, wz0, wz1, "plaster_white")
    walls.box(-8, -7, -12, 14, wz0, wz1, "plaster_white")
    walls.box(7, 8, -12, 14, wz0, wz1, "plaster_white")
    walls.box(-8.3, 8.3, -13.3, 15.3, wz1 - 0.6, wz1, "gold_dark")
    for sd in (-1, 1):  # ซุ้มหน้าต่าง
        for y in (-8.0, -2.0, 4.0, 10.0):
            window_frame(walls, 8.0, sd, y, 5.4, 10.0)
    # ซุ้มประตู + บานเปิด
    walls.box(-4.2, -3.6, -13.35, -12.95, 2.2, 11.0, "gold")
    walls.box(3.6, 4.2, -13.35, -12.95, 2.2, 11.0, "gold")
    walls.box(-4.2, 4.2, -13.35, -12.95, 11.0, 11.6, "gold")
    walls.prism_xz([(-4.5, 11.6), (4.5, 11.6), (0.4, 13.2), (0, 13.9), (-0.4, 13.2)], -13.4, -12.95, "gold")
    for sd in (-1, 1):
        x0, x1 = sorted((sd * 3.6, sd * 6.9))
        walls.box(x0, x1, -11.95, -11.75, 2.2, 11.0, "wood_red")
        walls.box(x0 + 0.35, x1 - 0.35, -11.78, -11.7, 3.0, 10.2, "gold_dark")
    col(P, -8, -3.6, -13, -12, wz0, wz1, "Wall")
    col(P, 3.6, 8, -13, -12, wz0, wz1, "Wall")
    col(P, -3.6, 3.6, -13, -12, 11.0, wz1, "Wall")
    col(P, -8, 8, 14, 15, wz0, wz1, "Wall")
    col(P, -8, -7, -12, 14, wz0, wz1, "Wall")
    col(P, 7, 8, -12, 14, wz0, wz1, "Wall")
    cols = B("Ubosot_Columns")
    for x in (-8.0, -4.6, 4.6, 8.0):
        cols.boxc(x, -19.8, 7.6, 1.2, 1.2, 10.8, "plaster_white")
        cols.boxc(x, -19.8, 2.6, 1.5, 1.5, 0.8, "plaster_white")
        lotus_bud(cols, x, -19.8, 12.6, 0.95, 1.1, "gold")
        col(P, x - 0.6, x + 0.6, -20.4, -19.2, 2.2, 13.0, "Column")
    for sd in (-1, 1):
        for y in (-10.0, -2.5, 5.0, 12.5):
            cols.boxc(sd * 10.6, y, 7.0, 1.0, 1.0, 9.6, "plaster_white")
            cols.boxc(sd * 10.6, y, 2.6, 1.3, 1.3, 0.8, "plaster_white")
            lotus_bud(cols, sd * 10.6, y, 11.4, 0.8, 0.9, "gold")
            col(P, sd * 10.6 - 0.5, sd * 10.6 + 0.5, y - 0.5, y + 0.5, 2.2, 11.8, "Column")
        cols.box(sd * 10.6 - 0.45, sd * 10.6 + 0.45, -10.5, 14.5, 11.6, 12.1, "gold_dark")
    roof = B("Ubosot_Roof")
    gable_slabs(roof, -13.5, 16.0, 9.0, 14.2, 23.5, 0.5, "roof_orange", "wood_dark", "trim_green")
    skirt_slabs(roof, -13.5, 16.0, 8.8, 14.4, 11.9, 11.9, 0.45, "roof_orange", "wood_dark", "trim_green")
    gable_slabs(roof, -17.2, -13.5, 8.6, 13.8, 22.2, 0.5, "roof_red", "wood_dark", "trim_green")
    gable_slabs(roof, -21.2, -17.2, 8.2, 13.2, 20.8, 0.5, "roof_orange", "wood_dark", "trim_green")
    for sd in (-1, 1):
        roof.box(sd * 12.0 - 0.22, sd * 12.0 + 0.22, -13.5, 16.0, 11.4, 11.95, "trim_green")
        for (y0, y1, xe, ze, zr) in ((-13.5, 16.0, 9.0, 14.2, 23.5), (-17.2, -13.5, 8.6, 13.8, 22.2), (-21.2, -17.2, 8.2, 13.2, 20.8)):
            # แถบขอบเขียวตามแนวชายคาและกลางหลังคา
            roof.box(sd * xe - 0.2, sd * xe + 0.2, y0, y1, ze - 0.45, ze + 0.05, "trim_green")
            mx, mz = sd * xe * 0.55, ze + (zr - ze) * 0.45
            roof.beam((mx, y0, mz + 0.02), (mx, y1, mz + 0.02), 0.5, 0.1, "trim_green", side=(sd, 0, 0))
    roof.box(-0.35, 0.35, -21.2, 16.0, 20.6, 23.9, "trim_green", {"top": "gold_dark"})
    gable_end(roof, -21.2, 8.2, 13.2, 20.8, -1, "ped_gold", 1.0)
    gable_end(roof, -17.2, 8.6, 13.8, 22.2, -1, "ped_gold", 1.0)
    gable_end(roof, -13.5, 9.0, 14.2, 23.5, -1, "ped_gold", 1.0)
    gable_end(roof, 16.0, 9.0, 14.2, 23.5, 1, "ped_gold", 1.0)
    # กำแพงแก้ว
    kw = B("Ubosot_KaewWall")
    X, Y0, Y1, G = 15.5, -27.5, 21.0, 4.5
    segs = [((-X, Y0), (-G, Y0)), ((G, Y0), (X, Y0)), ((-X, Y1), (X, Y1)), ((-X, Y0), (-X, Y1)), ((X, Y0), (X, Y1))]
    for (x0, y0), (x1, y1) in segs:
        balusters(kw, x0, y0, x1, y1, 0, 2.6, 0.8, "plaster_white", "plaster_white", 0.85, 0.3)
        col(P, min(x0, x1) - 0.4, max(x0, x1) + 0.4, min(y0, y1) - 0.4, max(y0, y1) + 0.4, 0, 2.6, "Wall")
    posts = [(-X, Y0), (X, Y0), (-X, Y1), (X, Y1), (-G, Y0), (G, Y0)]
    for x in (-7.5, 0, 7.5):
        posts.append((x, Y1))
    for y in (-15.0, -3.0, 9.0):
        posts += [(-X, y), (X, y)]
    for x in (-10.0,):
        posts += [(x, Y0), (-x, Y0)]
    for (x, y) in posts:
        kw.boxc(x, y, 1.7, 1.3, 1.3, 3.4, "plaster_white")
        kw.boxc(x, y, 3.5, 1.5, 1.5, 0.25, "gold_dark")
        lotus_bud(kw, x, y, 3.6, 0.5, 1.3, "gold")
    # ใบเสมา 8 ทิศ บนแท่น
    for (x, y) in ((-X - 2.6, Y0 - 2.6), (X + 2.6, Y0 - 2.6), (-X - 2.6, Y1 + 2.6), (X + 2.6, Y1 + 2.6),
                   (0, Y0 - 3.4), (0, Y1 + 2.6), (-X - 2.6, (Y0 + Y1) / 2), (X + 2.6, (Y0 + Y1) / 2)):
        kw.boxc(x, y, 0.6, 1.8, 1.8, 1.2, "plaster_white")
        kw.boxc(x, y, 1.45, 1.3, 1.3, 0.5, "plaster_red")
        kw.prism_xz([(x - 0.5, 1.7), (x + 0.5, 1.7), (x + 0.55, 2.8), (x, 3.6), (x - 0.55, 2.8)], y - 0.15, y + 0.15, "plaster_white")
    return P, [base, walls, cols, roof, kw]


def make_kuti():
    P = "Kuti"
    st = B("Kuti_Stilts")
    FZ = 6.8
    for x in (-7.6, -2.5, 2.5, 7.6):
        for y in (-8.4, -3.0, 1.5, 5.8):
            top = 14.8 if (y == -8.4 and abs(x) > 7) else FZ - 0.8
            st.boxc(x, y, 0.2, 1.5, 1.5, 0.4, "concrete")
            st.box(x - 0.45, x + 0.45, y - 0.45, y + 0.45, 0.4, top, "wood_dark")
            col(P, x - 0.45, x + 0.45, y - 0.45, y + 0.45, 0, top, "Post")
    st.box(-8.3, 8.3, -9.0, 6.4, FZ - 0.8, FZ - 0.3, "wood_dark")
    st.box(-8.2, 8.2, -8.9, 6.3, FZ - 0.3, FZ, "wood_plank")
    col(P, -8.3, 8.3, -9.0, 6.4, FZ - 0.8, FZ, "Floor")
    # บันไดไม้ลงด้านหน้าขวา
    n, rise, run = 12, FZ / 12, 1.0
    for i in range(n):
        z = FZ - rise * (i + 1)
        y0 = -9.0 - run * (i + 1)
        st.box(2.3, 7.5, y0, y0 + run + 0.05, z + rise - 0.25, z + rise, "wood")
        col(P, 2.3, 7.5, y0, y0 + run, 0, z + rise, "Step")
    for x in (2.2, 7.6):
        st.beam((x, -9.0, FZ + 0.1), (x, -9.0 - run * n, 0.1), 0.25, 0.7, "wood_dark", side=(1, 0, 0))
        st.beam((x, -9.0, FZ + 2.8), (x, -9.0 - run * (n - 1), 2.8), 0.2, 0.25, "wood", side=(1, 0, 0))
        st.box(x - 0.15, x + 0.15, -9.0 - run * (n - 1) - 0.15, -9.0 - run * (n - 1) + 0.15, 0, 3.0, "wood_dark")
    house = B("Kuti_House")
    WZ = 14.8
    house.box(-8, -2.7, -3.2, -2.8, FZ, WZ, "wood_plank")
    house.box(2.7, 8, -3.2, -2.8, FZ, WZ, "wood_plank")
    house.box(-2.7, 2.7, -3.2, -2.8, FZ + 7.0, WZ, "wood_plank")
    house.box(-8, 8, 5.6, 6.0, FZ, WZ, "wood_plank")
    house.box(-8, -7.6, -2.8, 5.6, FZ, WZ, "wood_plank")
    house.box(7.6, 8, -2.8, 5.6, FZ, WZ, "wood_plank")
    house.box(-2.5, 2.5, 5.45, 5.55, FZ, FZ + 6.9, "window_dark")  # ช่องประตูมืดเข้าห้องในที่ผนังหลัง
    for xa in (-5.6, 5.6):  # หน้าต่างบานเปิด
        house.box(xa - 1.2, xa + 1.2, -3.3, -3.18, FZ + 2.6, FZ + 5.4, "window_dark")
        house.box(xa - 1.45, xa + 1.45, -3.36, -3.2, FZ + 2.4, FZ + 2.6, "wood_dark")
        house.box(xa - 1.45, xa + 1.45, -3.36, -3.2, FZ + 5.4, FZ + 5.6, "wood_dark")
        for sd in (-1, 1):
            house.box(xa + sd * 1.2 + (0 if sd > 0 else -1.2), xa + sd * 1.2 + (1.2 if sd > 0 else 0), -3.5, -3.36, FZ + 2.6, FZ + 5.4, "wood_plank")
    for sd in (-1, 1):
        for y in (0.0, 3.4):
            house.box(min(sd * 8, sd * 8.12), max(sd * 8, sd * 8.12), y - 1.0, y + 1.0, FZ + 2.6, FZ + 5.2, "window_dark")
    for (x0, x1) in ((-8, -2.7), (2.7, 8)):
        col(P, x0, x1, -3.2, -2.8, FZ, WZ, "Wall")
    col(P, -2.7, 2.7, -3.2, -2.8, FZ + 7.0, WZ, "Wall")
    col(P, -8, 8, 5.6, 6.0, FZ, WZ, "Wall")
    col(P, -8, -7.6, -2.8, 5.6, FZ, WZ, "Wall")
    col(P, 7.6, 8, -2.8, 5.6, FZ, WZ, "Wall")
    # ระเบียงลูกกรงไม้
    RZ = FZ + 2.8
    for (x0, x1) in ((-8.1, 2.1), (7.7, 8.1)):
        house.box(x0, x1, -8.95, -8.75, FZ, FZ + 0.25, "wood")
        house.box(x0, x1, -8.95, -8.7, RZ - 0.3, RZ, "wood")
        for i in range(int((x1 - x0) / 0.55)):
            x = x0 + 0.27 + i * 0.55
            house.box(x - 0.1, x + 0.1, -8.9, -8.8, FZ + 0.25, RZ - 0.3, "wood", skip=("top", "bottom"))
    col(P, -8.1, 2.1, -9.0, -8.7, FZ, RZ, "Rail")
    for sd in (-1, 1):
        x = sd * 8.0
        house.box(x - 0.13, x + 0.13, -8.9, -3.2, RZ - 0.3, RZ, "wood")
        house.box(x - 0.1, x + 0.1, -8.9, -3.2, FZ, FZ + 0.25, "wood")
        for i in range(int(5.7 / 0.55)):
            y = -8.6 + i * 0.55
            house.box(x - 0.05, x + 0.05, y - 0.1, y + 0.1, FZ + 0.25, RZ - 0.3, "wood", skip=("top", "bottom"))
        col(P, x - 0.15, x + 0.15, -8.9, -3.2, FZ, RZ, "Rail")
    roof = B("Kuti_Roof")
    gable_slabs(roof, -9.4, 6.8, 9.3, 13.6, 20.4, 0.4, "roof_brown", "wood_dark", "wood_dark")
    for y, o in ((-9.2, -1), (6.6, 1)):
        roof.prism_xz([(-8.4, 13.9), (8.4, 13.9), (0, 19.9)], min(y, y - o * 0.25), max(y, y - o * 0.25), "wood_plank")
        roof.box(-8.6, 8.6, min(y, y + o * 0.2), max(y, y + o * 0.2), 13.6, 14.0, "wood_dark")
        for sd in (-1, 1):  # ป้านลมต่อเลยยอดเป็นกาแล
            p0 = Vector((sd * 9.6, y + o * 0.3, 13.3))
            p1 = Vector((0, y + o * 0.3, 20.6))
            d = (p1 - p0).normalized()
            roof.beam(p0, p1 + d * 2.6, 0.3, 0.75, "wood_dark")
    roof.box(-0.3, 0.3, -9.4, 6.8, 20.1, 20.7, "roof_brown")
    roof.v = [v + Vector((0, 0, WZ - 13.9)) for v in roof.v]
    return P, [st, house, roof]


def make_sala():
    P = "Sala"
    base = B("Sala_Base")
    base.box(-20.3, 20.3, -15.3, 15.3, 0, 0.4, "plaster_dark")
    base.box(-20, 20, -15, 15, 0.4, 1.6, "plaster_white", {"top": "floor_white"})
    col(P, -20, 20, -15, 15, 0, 1.6, "Floor")
    stairs(base, -7, 7, -15.0, 1.6, 2, 0.9, "plaster_white", prop=P)
    base.box(-9, 9, 6.2, 12.6, 1.6, 2.6, "plaster_white", {"top": "floor_tile"})  # แท่นตั้งพระ
    col(P, -9, 9, 6.2, 12.6, 1.6, 2.6, "Dais")
    cols = B("Sala_Columns")
    pos = [(x, y) for x in (-18, -9, 0, 9, 18) for y in (-13, 13)] + [(sd * 18, y) for sd in (-1, 1) for y in (-4.3, 4.3)]
    pos += [(sd * 12, y) for sd in (-1, 1) for y in (-4.5, 4.5)]
    for (x, y) in pos:
        top = 15.5 if abs(x) == 12 and abs(y) < 10 else 13.4
        cols.boxc(x, y, 2.8, 1.5, 1.5, 2.4, "plaster_white")
        cols.box(x - 0.5, x + 0.5, y - 0.5, y + 0.5, 4.0, top, "wood_red")
        col(P, x - 0.75, x + 0.75, y - 0.75, y + 0.75, 1.6, top, "Column")
    for y in (-13, 13):
        cols.box(-18.6, 18.6, y - 0.4, y + 0.4, 12.8, 13.5, "wood_red")
    for x in (-18, 18):
        cols.box(x - 0.4, x + 0.4, -13.4, 13.4, 12.8, 13.5, "wood_red")
    for x in (-12, 12):
        cols.box(x - 0.4, x + 0.4, -11.0, 11.0, 14.9, 15.6, "wood_red")
    roof = B("Sala_Roof")
    # ชายคาปั้นหยารอบ 4 ด้าน
    ri, ro = (12.2, 10.6, 13.1), (21.5, 15.6, 10.4)
    th = 0.35
    corners_i = [(-ri[0], -ri[1]), (ri[0], -ri[1]), (ri[0], ri[1]), (-ri[0], ri[1])]
    corners_o = [(-ro[0], -ro[1]), (ro[0], -ro[1]), (ro[0], ro[1]), (-ro[0], ro[1])]
    for i in range(4):
        j = (i + 1) % 4
        a, bb_, c, d = corners_o[i], corners_o[j], corners_i[j], corners_i[i]
        top = [(a[0], a[1], ro[2]), (bb_[0], bb_[1], ro[2]), (c[0], c[1], ri[2]), (d[0], d[1], ri[2])]
        P8 = [(p[0], p[1], p[2] - th) for p in top] + top
        roof.hexa(P8, "wood_red", {"top": "tin_green", "bottom": "wood_dark"})
    for i in range(4):  # ตะเข้สัน
        roof.beam((corners_o[i][0], corners_o[i][1], ro[2] + 0.1), (corners_i[i][0], corners_i[i][1], ri[2] + 0.1), 0.35, 0.3, "wood_red")
    gable_slabs(roof, -11.6, 11.6, 13.0, 12.9, 20.5, 0.35, "tin_green", "wood_dark", "wood_red")
    roof.box(-0.3, 0.3, -11.6, 11.6, 20.3, 20.8, "wood_red")
    for y, o in ((-10.6, -1), (10.6, 1)):
        roof.prism_xz([(-12.4, 13.1), (12.4, 13.1), (0, 20.2)], min(y, y + o * 0.3), max(y, y + o * 0.3), "plaster_white", "louver_white")
        for sd in (-1, 1):
            roof.beam((sd * 13.2, y + o * 1.0, 12.7), (0, y + o * 1.0, 20.9), 0.35, 0.6, "wood_red")
    roof.v = [v + Vector((0, 0, 2.5)) for v in roof.v]
    return P, [base, cols, roof]



def make_donation_board():
    """ป้ายบริจาคสูง แผ่นป้ายยาวห้อยโซ่จากคาน (หน้าป้ายเปล่าไว้ทำ dashboard ด้วย SurfaceGui)"""
    P = "DonationBoard"
    f = B("DonationBoard")
    for sd in (-1, 1):
        x = sd * 13.6
        f.box(x - 1.0, x + 1.0, -1.0, 1.0, 0, 0.8, "concrete")
        f.box(x - 0.65, x + 0.65, -0.65, 0.65, 0.8, 26.0, "wood_red")
        f.box(x - 0.8, x + 0.8, -0.8, 0.8, 26.0, 26.3, "wood_red")
        col(P, x - 1.0, x + 1.0, -1.0, 1.0, 0, 26.3, "Post")
    f.box(-15.6, 15.6, -0.6, 0.6, 24.6, 25.8, "wood_red")
    for sd in (-1, 1):  # ค้ำยันมุม + ห่วงแขวนโซ่
        f.beam((sd * 12.95, 0, 22.4), (sd * 10.6, 0, 24.7), 0.5, 0.5, "wood_red", side=(0, 1, 0))
        f.lathe(sd * 9.0, 0, [(0.3, 0), (0.3, 0.25)], 8, "iron_dark", 24.35)
    board = B("DonationBoard_Board")
    board.box(-12.0, 12.0, -0.3, 0.3, 2.5, 22.0, "sign_wood")
    for (xa, xb, za, zb) in ((-12.2, 12.2, 21.7, 22.2), (-12.2, 12.2, 2.3, 2.8), (-12.2, -11.7, 2.3, 22.2), (11.7, 12.2, 2.3, 22.2)):
        board.box(xa, xb, -0.4, 0.4, za, zb, "wood_teak")
    for sd in (-1, 1):  # โซ่
        x = sd * 9.0
        z = 22.2
        i = 0
        while z < 24.3:
            if i % 2 == 0:
                board.box(x - 0.18, x + 0.18, -0.05, 0.05, z, z + 0.42, "chain")
            else:
                board.box(x - 0.05, x + 0.05, -0.18, 0.18, z, z + 0.42, "chain")
            z += 0.34
            i += 1
        board.lathe(x, 0, [(0.12, 0), (0.12, 0.3)], 6, "chain", 21.95)
    face = B("DonationBoard_Face")
    face.box(-11.6, 11.6, -0.36, -0.32, 2.9, 21.6, "sign_dark")
    face.box(-11.6, 11.6, 0.32, 0.36, 2.9, 21.6, "sign_dark")
    return P, [f, board, face]


def turned(b, x, y, z0, h, r, key, n=8, bumps=None):
    """เสากลึงเกลียว/ลูกมะหวด"""
    k = bumps or max(3, int(h / (r * 2.2)))
    prof = []
    for i in range(k * 4 + 1):
        t = i / (k * 4)
        prof.append((r * (0.72 + 0.28 * abs(math.sin(t * k * math.pi))), t * h))
    b.lathe(x, y, prof, n, key, z0)


def make_donation_box():
    """ตู้บริจาคไม้สักหน้าบานกระจก เสากลึง 2 ข้าง ขาลูกบิด ตั้งบนแท่นกลึง"""
    P = "DonationBox"
    st = B("DonationBox_Stand")
    st.lathe(0, 0, [(1.4, 0), (1.4, 0.25), (1.1, 0.4), (0.55, 0.6), (0.45, 1.0)], 12, "wood_teak")
    turned(st, 0, 0, 1.0, 2.0, 0.5, "wood_teak", 12, 3)
    st.box(-1.7, 1.7, -1.4, 1.4, 3.0, 3.35, "wood_teak")
    col(P, -1.7, 1.7, -1.4, 1.4, 0, 3.35, "Stand")
    cb = B("DonationBox")
    for sx in (-1, 1):  # ขาลูกบิด
        for sy in (-1, 1):
            cb.ellipsoid((sx * 1.0, sy * 0.7, 3.62), (0.3, 0.3, 0.27), "wood_teak", 8, 6)
    cb.box(-1.45, 1.45, -1.15, 1.15, 3.85, 4.2, "wood_teak")
    cb.box(-1.3, 1.3, -1.0, 1.0, 4.2, 7.4, "wood_teak", skip=("front",))
    cb.box(-1.15, 1.15, 0.85, 0.9, 4.25, 7.35, "wood_dark")  # ผนังในด้านหลัง
    cb.box(-1.5, 1.5, -1.2, 1.2, 7.4, 7.75, "wood_teak")
    cb.box(-0.6, 0.6, -0.15, 0.15, 7.74, 7.78, "window_dark")  # ช่องหยอดเงิน
    for sx in (-1, 1):  # เสากลึงหน้าตู้
        turned(cb, sx * 1.15, -1.05, 4.2, 3.2, 0.2, "wood_teak", 8, 9)
    for (k, x, y, z) in (("banknote", -0.4, 0.2, 4.2), ("banknote_red", 0.3, 0.1, 4.2), ("banknote", 0.0, -0.2, 4.32),
                         ("banknote_red", -0.5, -0.3, 4.44), ("banknote", 0.5, 0.4, 4.32)):
        cb.box(x - 0.55, x + 0.55, y - 0.28, y + 0.28, z, z + 0.12, k)
    for i in range(7):  # เหรียญ
        a = i * 0.9
        cb.lathe(0.6 * math.cos(a) - 0.1, 0.35 * math.sin(a), [(0.13, 0), (0.13, 0.05)], 8, "brass", 4.2 + (i % 3) * 0.05)
    col(P, -1.5, 1.5, -1.2, 1.2, 3.35, 7.75, "Cabinet")
    door = B("DonationBox_Door")
    door.box(-0.95, -0.65, -1.12, -1.0, 4.35, 7.25, "wood_teak")
    door.box(0.65, 0.95, -1.12, -1.0, 4.35, 7.25, "wood_teak")
    door.box(-0.65, 0.65, -1.12, -1.0, 4.35, 4.65, "wood_teak")
    door.box(-0.65, 0.65, -1.12, -1.0, 6.95, 7.25, "wood_teak")
    door.box(0.7, 0.9, -1.22, -1.12, 5.6, 6.0, "brass")  # กลอนทองเหลือง
    glass = B("DonationBox_Glass")
    glass.box(-0.68, 0.68, -1.08, -1.04, 4.62, 6.98, "glass")
    return P, [st, cb, door, glass]


def make_shop_cart():
    """รถเข็นขายทุกอย่าง: ชั้นวางขั้นบันได ของเต็มชั้น ผ้าใบลายทาง ป้ายหน้า (หน้าป้ายเปล่า)"""
    import random
    P = "ShopCart"
    rng = random.Random(77)
    cart = B("ShopCart")
    for sy in (-1, 1):  # ล้อจักรยาน
        y = sy * 2.75
        with cart.xf(Matrix.Translation((0, y, 1.7)) @ Matrix.Rotation(math.radians(90), 4, "X")):
            cart.lathe(0, 0, [(1.7, -0.15), (1.7, 0.15), (1.45, 0.15), (1.45, -0.15)], 20, "tire")
            cart.lathe(0, 0, [(0.2, -0.25), (0.2, 0.25)], 8, "iron_dark")
            for k in range(8):
                a = k * math.pi / 8
                cart.beam((-1.45 * math.cos(a), -1.45 * math.sin(a), 0), (1.45 * math.cos(a), 1.45 * math.sin(a), 0), 0.05, 0.05, "chain", side=(0, 0, 1))
    cart.box(-0.2, 0.2, -2.9, 2.9, 1.55, 1.85, "iron_dark")
    for sx in (-1, 1):
        for sy in (-1, 1):
            cart.box(sx * 5.8 - 0.2, sx * 5.8 + 0.2, sy * 2.2 - 0.2, sy * 2.2 + 0.2, 0, 3.0, "wood_dark")
    for sy in (-1, 1):  # มือจับ
        cart.beam((6.2, sy * 1.8, 3.0), (8.0, sy * 1.8, 3.6), 0.25, 0.25, "iron_dark", side=(0, 1, 0))
    cart.box(7.9, 8.1, -1.9, 1.9, 3.5, 3.75, "iron_dark")
    cart.box(-6.3, 6.3, -2.6, 2.6, 2.6, 3.0, "wood")
    cart.box(-6.3, 6.3, 2.1, 2.5, 3.0, 9.8, "wood_plank")
    col(P, -6.3, 6.3, -2.6, 2.6, 0, 9.8, "Cart")
    goods = B("ShopCart_Goods")
    snacks = ["snack_red", "snack_yellow", "snack_green", "snack_blue", "toy_pink"]
    for i in range(4):  # ชั้นวางขั้นบันได 4 ชั้น
        y0 = -2.5 + i * 1.05
        z = 3.0 + i * 1.4
        cart.box(-6.1, 6.1, y0, 2.1, z - 0.2, z, "wood")
        if i:
            cart.box(-6.1, 6.1, y0 - 0.05, y0 + 0.05, z - 1.4, z - 0.2, "wood_dark")
        for x in range(-5, 6, 2):  # ป้ายราคาเขียว
            goods.box(x - 0.3, x + 0.3, y0 - 0.06, y0 - 0.02, z - 0.18, z + 0.08, "price_green")
        x = -5.8
        while x < 5.6:
            kind = rng.random()
            yc = y0 + 0.5
            if kind < 0.35:  # ขวด
                k = rng.choice(["bottle_clear", "snack_blue", "snack_green", "bottle_clear"])
                h = rng.uniform(0.8, 1.2)
                goods.lathe(x + 0.18, yc, [(0.17, 0), (0.17, h * 0.65), (0.07, h * 0.85), (0.07, h)], 6, k, z)
                x += 0.42
            elif kind < 0.6:  # โหล
                goods.lathe(x + 0.3, yc, [(0.28, 0), (0.3, 0.5), (0.22, 0.62)], 8, rng.choice(snacks), z)
                x += 0.66
            else:  # กล่อง/ซองขนม
                w = rng.uniform(0.4, 0.8)
                h = rng.uniform(0.5, 1.15)
                goods.box(x, x + w, yc - 0.3, yc + 0.25, z, z + h, rng.choice(snacks))
                x += w + 0.06
    for x in (-5.0, -2.6, 2.6, 5.0):  # ตะกร้าหน้าฐาน
        goods.box(x - 1.0, x + 1.0, -3.2, -2.4, 1.6, 2.6, "basket", skip=("top",))
        for j in range(4):
            goods.ellipsoid((x - 0.6 + j * 0.4, -2.8, 2.6), (0.22, 0.22, 0.2), rng.choice(["snack_red", "snack_yellow", "toy_pink"]), 6, 4)
    for sx in (-1, 1):  # ของห้อยข้าง + ตุ๊กตาห้อยหน้า
        for j in range(5):
            z = 11.2 - j * 1.2
            yo = (j % 2) * 0.8
            goods.box(sx * 6.5 - 0.3, sx * 6.5 + 0.3, -2.0 + yo, -1.3 + yo, z - 0.9, z, rng.choice(snacks))
            goods.box(sx * 6.5 - 0.02, sx * 6.5 + 0.02, -1.7 + yo, -1.6 + yo, z, z + 0.3, "chain")
        for j in range(3):
            goods.ellipsoid((sx * (3.0 + j * 1.2), -3.2, 10.6 - (j % 2) * 0.4), (0.38, 0.32, 0.42), rng.choice(["toy_pink", "snack_blue", "snack_yellow"]), 8, 6)
    can = B("ShopCart_Canopy")
    for sx in (-1, 1):
        for sy in (-1, 1):
            can.box(sx * 6.2 - 0.12, sx * 6.2 + 0.12, sy * 2.4 - 0.12, sy * 2.4 + 0.12, 3.0, 12.6, "iron_dark")
    can.hexa([(-7.4, -3.8, 12.4), (7.4, -3.8, 12.4), (7.4, 3.3, 13.0), (-7.4, 3.3, 13.0),
              (-7.4, -3.8, 12.6), (7.4, -3.8, 12.6), (7.4, 3.3, 13.2), (-7.4, 3.3, 13.2)], "canopy")
    can.box(-7.4, 7.4, -3.9, -3.8, 11.6, 12.6, "canopy")
    for sx in (-1, 1):
        can.box(min(sx * 7.4, sx * 7.5), max(sx * 7.4, sx * 7.5), -3.8, 3.3, 11.8, 12.6, "canopy")
    can.box(-4.8, 4.8, -2.75, -2.55, 10.0, 11.5, "frame_blue")
    sign = B("ShopCart_Sign")
    sign.box(-4.6, 4.6, -2.8, -2.75, 10.15, 11.35, "sign_white")
    return P, [cart, goods, can, sign]


def make_buddha_trio():
    P = "BuddhaTrio"
    base = B("BuddhaTrio_Base")
    base.box(-6.4, 6.4, -2.1, 2.1, 0, 0.5, "gold")
    base.box(-6.0, 6.0, -1.7, 1.7, 0.5, 2.6, "mosaic", {"front": "mosaic_front"})
    base.box(-6.4, 6.4, -2.1, 2.1, 2.6, 3.1, "gold")
    for i in range(28):  # กลีบบัวขอบบน
        x = -6.2 + (i + 0.5) * 12.4 / 28
        base.prism_xz([(x - 0.22, 2.6), (x + 0.22, 2.6), (x, 2.15)], -2.12, -1.95, "gold")
    for x in (-4.2, 0.0, 4.2):
        base.box(x - 1.45, x + 1.45, -1.82, -1.72, 0.75, 1.95, "gold")
    col(P, -6.4, 6.4, -2.1, 2.1, 0, 3.1, "Base")
    plq = B("BuddhaTrio_Plaques")
    for x in (-4.2, 0.0, 4.2):
        plq.box(x - 1.25, x + 1.25, -1.9, -1.82, 0.85, 1.85, "plaque_red")
    c = B("Buddha_Center")
    buddha(c, 0, 0.1, 3.1, 1.0)
    l = B("Buddha_Left")
    buddha(l, -4.2, 0.25, 3.1, 0.74)
    r = B("Buddha_Right")
    buddha(r, 4.2, 0.25, 3.1, 0.74)
    return P, [base, plq, c, l, r]


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
    shade = 1 + 0.10 * (n1 - 0.5) + 0.06 * (n2 - 0.5) + 0.04 * (n3 - 0.5)
    h = 0.15 * n2 + 0.1 * n3
    rough = np.full((n, n), spec["r"]) + 0.08 * (n2 - 0.5)
    metal = np.full((n, n), float(spec["m"]))
    col = np.ones((n, n, 3)) * base
    p = spec["p"]
    if p == "plaster":
        stain = np.clip((vnoise(n, 5, seed + 3) - 0.55) * 2.5, 0, 1)
        streak = vnoise(n, 40, seed + 5)[0:1, :].repeat(n, 0) * np.clip(1 - v * 1.3, 0, 1)
        shade *= 1 - 0.18 * stain - 0.12 * streak - 0.16 * np.exp(-v * 7)
        col = col * shade[..., None]
        col = col * (1 - 0.1 * np.exp(-v * 5))[..., None] + np.array([0.04, 0.05, 0.02]) * np.exp(-v * 6)[..., None]
    elif p == "gold":
        shade = 1 + 0.22 * (n1 - 0.5) + 0.12 * (n2 - 0.5)
        tarn = np.clip((vnoise(n, 8, seed + 9) - 0.6) * 3, 0, 1)
        col = col * shade[..., None] * (1 - 0.35 * tarn)[..., None]
        rough = rough + 0.25 * tarn
        metal = metal - 0.3 * tarn
    elif p == "tiles":
        rows = 7
        r = (v * rows) % 1.0
        ridx = np.floor(v * rows)
        cidx = np.floor(xx * 9 + 0.5 * (ridx % 2))
        tile_rand = (np.sin(ridx * 12.9898 + cidx * 78.233) * 43758.5453) % 1.0
        groove = np.clip(1 - r / 0.18, 0, 1)
        shade = shade * (0.88 + 0.2 * tile_rand) * (1 - 0.35 * groove)
        shade *= 1 - 0.25 * np.clip((vnoise(n, 4, seed + 2) - 0.55) * 3, 0, 1)  # คราบตะไคร่
        col = col * shade[..., None]
        h = r * 0.8 + 0.1 * n3
    elif p == "corrugated":
        s = np.sin(xx * 2 * math.pi * 12)
        shade = shade * (1 + 0.1 * s)
        rust = np.clip((vnoise(n, 7, seed + 4) - 0.62) * 3, 0, 1)
        col = col * shade[..., None] * (1 - rust[..., None]) + np.array([0.42, 0.24, 0.13]) * rust[..., None]
        h = 0.5 * s
        metal = metal * (1 - rust)
    elif p in ("grain", "planks"):
        gn = vnoise(n, 40, seed + 1)
        g2 = vnoise(n, 48, seed + 11)
        grain = np.sin((yy * 60 + gn * 6 + g2 * 3) * math.pi)
        shade = shade * (1 + 0.07 * grain)
        if p == "planks":
            r = (v * 6) % 1.0
            groove = (r < 0.06).astype(float)
            pidx = np.floor(v * 6)
            shade = shade * (0.9 + 0.15 * ((np.sin(pidx * 91.7) * 999) % 1.0)) * (1 - 0.5 * groove)
            h = (1 - groove) * 0.6 + 0.05 * grain
        else:
            h = 0.05 * grain
        col = col * shade[..., None]
    elif p == "checker":
        t = 8
        gx = (xx * t) % 1.0
        gy = (yy * t) % 1.0
        grout = ((gx < 0.06) | (gy < 0.06)).astype(float)
        chk = ((np.floor(xx * t) + np.floor(yy * t)) % 2)
        shade = shade * (1 - 0.08 * chk) * (1 - 0.35 * grout)
        col = col * shade[..., None]
        h = (1 - grout) * 0.4
    elif p == "mosaic":
        col, h = mosaic(n, seed, 14, 14)
        rough = np.where(h > 0.3, 0.2, 0.6)
        metal = np.where(h > 0.3, 0.35, 0.6)
    elif p == "photo":
        dx = (xx - 0.5) / 0.28
        dy = (yy - 0.42) / 0.36
        face = np.clip(1 - (dx ** 2 + dy ** 2), 0, 1) ** 0.5
        body = np.clip(1 - ((xx - 0.5) / 0.42) ** 2 - ((yy - 1.0) / 0.25) ** 2, 0, 1) * 0.5
        eyes = np.exp(-(((xx - 0.4) / 0.05) ** 2 + ((yy - 0.38) / 0.035) ** 2)) + np.exp(-(((xx - 0.6) / 0.05) ** 2 + ((yy - 0.38) / 0.035) ** 2))
        g = 0.2 + 0.5 * face + 0.12 * body - 0.4 * eyes * face
        g = g * shade
        border = ((xx < 0.06) | (xx > 0.94) | (yy < 0.05) | (yy > 0.95)).astype(float)
        g = g * (1 - border) + 0.75 * border
        col = np.stack([g * 0.95, g * 0.82, g * 0.62], -1)
    elif p == "plaque":
        border = ((xx < 0.08) | (xx > 0.92) | (yy < 0.12) | (yy > 0.88)).astype(float)
        col = col * shade[..., None] * (1 - border[..., None]) + np.array([0.7, 0.53, 0.22]) * border[..., None]
        metal = metal + 0.7 * border
        h = border * 0.6
    elif p == "stripes":
        cols = np.array([(40, 80, 170), (235, 195, 50), (200, 50, 40), (225, 225, 220)]) / 255.0
        col = cols[(np.floor(xx * 8).astype(int)) % 4] * shade[..., None]
    elif p == "louver":
        r = (v * 9) % 1.0
        col = col * (shade * (0.75 + 0.35 * r))[..., None]
        h = r
    elif p == "F_ped_gate":
        col, h, rough, metal = pediment(n, seed, gate=True)
    elif p == "F_ped_gold":
        col, h, rough, metal = pediment(n, seed, gate=False)
    elif p == "F_mosaic":
        col, h = mosaic(n, seed, 72, 14)
        rough = np.where(h > 0.3, 0.2, 0.5)
        metal = np.where(h > 0.3, 0.3, 0.7)
    else:
        col = col * shade[..., None]
    return np.clip(col, 0, 1), h, np.clip(rough, 0.05, 1), np.clip(metal, 0, 1)


def mosaic(n, seed, tx, ty):
    rng = np.random.default_rng(seed)
    pal = np.array([(40, 70, 150), (38, 60, 130), (150, 36, 34), (40, 120, 80), (200, 160, 70), (170, 175, 185), (60, 100, 170)]) / 255.0
    ids = rng.integers(0, len(pal), (ty, tx))
    yy, xx = np.mgrid[0:n, 0:n] / n
    ix = np.minimum((xx * tx).astype(int), tx - 1)
    iy = np.minimum((yy * ty).astype(int), ty - 1)
    col = pal[ids[iy, ix]]
    gx, gy = (xx * tx) % 1.0, (yy * ty) % 1.0
    grout = ((gx < 0.14) | (gy < 0.14)).astype(float)
    sp = vnoise(n, 32, seed + 3)
    col = col * (0.75 + 0.5 * sp)[..., None]
    col = col * (1 - grout[..., None]) + np.array([0.62, 0.48, 0.2]) * grout[..., None]
    return col, (1 - grout) * 0.5


def pediment(n, seed, gate):
    yy, xx = np.mgrid[0:n, 0:n] / n
    t = yy  # 0 = ยอดจั่ว 1 = ฐาน
    d = 0.5 * t - np.abs(xx - 0.5)
    f = np.sin(xx * 46 + 3.2 * np.sin(yy * 23)) * np.sin(yy * 46 + 3.2 * np.sin(xx * 27))
    swirl = np.clip((f - (0.3 if gate else -0.15)) * 6, 0, 1)
    gold = np.array([0.78, 0.6, 0.26])
    if gate:
        bg = np.ones((n, n, 3)) * np.array([0.15, 0.23, 0.46])
        band = (d < 0.07).astype(float)
        bg = bg * (1 - band[..., None]) + np.array([0.55, 0.12, 0.1]) * band[..., None]
        line = ((d > 0.07) & (d < 0.09)).astype(float)
        # ซุ้มจระนำตรงกลาง
        ax, ay = (xx - 0.5) / 0.16, (yy - 0.62) / 0.28
        niche = (ax ** 2 + np.minimum(ay, 0) ** 2 < 1) & (yy < 0.9) & (yy > 0.34)
        bg = np.where(niche[..., None], np.array([0.1, 0.12, 0.25]), bg)
        g = np.clip(swirl * (1 - band) * (~niche) + line, 0, 1)
    else:
        bg = np.ones((n, n, 3)) * np.array([0.5, 0.1, 0.08])
        line = ((d > 0.0) & (d < 0.035)).astype(float)
        g = np.clip(swirl + line, 0, 1)
        # รูปเทพพนมกลางหน้าบัน (เงารูปทรง)
        ax, ay = (xx - 0.5) / 0.1, (yy - 0.6) / 0.22
        fig = np.clip(1.2 - (ax ** 2 + ay ** 2), 0, 1)
        g = np.clip(g + fig, 0, 1)
    sh = 1 + 0.2 * (vnoise(n, 10, seed) - 0.5)
    col = bg * (1 - g[..., None]) + gold * g[..., None]
    col = col * sh[..., None]
    h = g * 0.8
    rough = 0.6 - 0.3 * g
    metal = 0.75 * g
    return col, h, rough, metal


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
    free = []
    for j in range(8):
        for i in range(8):
            if feat and i < 4 and j < 4:
                continue
            free.append((i, j))
    ci = 0
    for idx, k in enumerate(keys):
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
    # หม่นลงให้เข้ากับกลางคืน: ลดความอิ่มสี 18% และความสว่าง 10%
    g = col.mean(-1, keepdims=True)
    col = (g + (col - g) * 0.82) * 0.9
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


def face_uv(bm, face, layout, uvl, keyname, box=None):
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
    if box:  # วัตถุผิวโค้ง (พระพุทธรูป): ฉายด้านหน้าทั้งชิ้น ไม่ให้ลายซ้ำทุกสามเหลี่ยม
        pts = [(l.vert.co.x, l.vert.co.z) for l in face.loops]
        u0, u1, v0, v1 = box
    else:
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
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uvl = bm.loops.layers.uv.new("UVMap")
        box = None
        if b.smooth:
            box = (min(v.co.x for v in bm.verts), max(v.co.x for v in bm.verts), min(v.co.z for v in bm.verts), max(v.co.z for v in bm.verts))
        for bf, k in fk:
            face_uv(bm, bf, layout, uvl, k, box if k == "buddha_gold" else None)
            bf.smooth = b.smooth
        bmesh.ops.scale(bm, vec=(S * b.scale,) * 3, verts=bm.verts)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(mat)
        ob = bpy.data.objects.new(b.name, me)
        coll.objects.link(ob)
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        log(f"  {b.name}: {tris} tris")
        if tris > 10000:
            log(f"  !!! {b.name} เกิน 10,000 tris")
        objs.append(ob)
        if b.v:
            OBJ_BBOX[b.name] = [[round(min(v[i] for v in b.v) * b.scale, 4) for i in range(3)], [round(max(v[i] for v in b.v) * b.scale, 4) for i in range(3)]]
    return coll, objs


def export(prop, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT, prop + ".fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)


def preview(prop, objs):
    scn = bpy.context.scene
    for o in bpy.context.view_layer.objects:
        o.hide_render = o not in objs
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for o in objs:
        for v in o.data.vertices:
            mn = Vector(map(min, mn, v.co))
            mx = Vector(map(max, mx, v.co))
    c = (mn + mx) / 2
    size = (mx - mn).length
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        scn.collection.objects.link(cam)
    cam.data.lens = 40
    d = Vector((-0.75, -1.25, 0.55)).normalized()
    cam.location = c + d * size * 1.05
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.camera = cam
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.display.shading.show_cavity = True
    scn.display.shading.show_shadows = True
    scn.render.resolution_x = 900
    scn.render.resolution_y = 900
    scn.render.film_transparent = False
    scn.render.filepath = os.path.join(PREV, prop + ".png")
    bpy.ops.render.render(write_still=True)
    cam.hide_render = False


def main():
    os.makedirs(PREV, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    makers = [make_gate, make_fence, make_stupas, make_meru, make_ubosot, make_kuti, make_sala, make_buddha_trio,
              make_donation_board, make_donation_box, make_shop_cart]
    only = [s.strip() for s in ONLY.split(",") if s.strip()]
    allobjs = {}
    for mk in makers:
        global SCALE_NOW
        SCALE_NOW = PROP_SCALE.get(mk.__name__.replace("make_", "").capitalize(), 1.0)
        prop, builders = mk()
        SCALE_NOW = 1.0
        if only and prop not in only:
            continue
        log(prop)
        coll, objs = realize(prop, builders)
        export(prop, objs)
        preview(prop, objs)
        allobjs[prop] = objs
    # ข้อมูลกล่องชน (studs, แกนแบบ Blender: X ขวา, Y หลัง, Z บน, origin = ฐานของ prop)
    cpath = os.path.join(ROOT, "ThaiTemple_Colliders.json")
    old = {}
    if only and os.path.exists(cpath):
        old = json.load(open(cpath, encoding="utf-8"))
    old.update(COLLIDERS)
    old.setdefault("_bbox", {}).update(OBJ_BBOX)
    json.dump(old, open(cpath, "w", encoding="utf-8"), indent=1)
    for o in bpy.context.view_layer.objects:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "thai_temple.blend"))


try:
    main()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(os.path.join(os.environ.get("TEMPLE_LOG_DIR", ROOT), "thai_temple_build.log"), "w", encoding="utf-8").write("\n".join(LOG))
