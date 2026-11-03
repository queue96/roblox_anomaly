# กระสือ (Krasue) — หัวผู้หญิงลอย ผมยาวดำ หน้าซีด ตาแดง ปากเลือด เขี้ยว + หลอดลม ปอด หัวใจ ไส้ห้อย — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\krasue.py -Out C:\tmp\krasue.txt
# ผลลัพธ์ (assets/models/):
#   Krasue.fbx           mesh 4 ชิ้น + rig KrasueRig + ท่า Float (วนซ้ำ)
#   Krasue_Lunge.fbx / Krasue_Sniff.fbx / Krasue_HairWhip.fbx   mesh + rig ชุดเดียวกัน ท่าละไฟล์ (ไว้ import ท่าใน Studio)
#   Krasue_Color/_Normal/_Roughness/_Metalness.png  texture 1024 ชุดเดียวใช้ทุกชิ้น
#   Krasue_Anims.json    ค่าท่าทุกเฟรม (quaternion + location ของแต่ละกระดูก ใน local space ของ Blender)
#   krasue.blend, previews/Krasue*.png
# ชิ้น mesh (origin เดียวกัน = กลางหัว):
#   Krasue         หัว คอ (ตอคอขาด) เขี้ยว — ผิวซีด เบ้าตาคล้ำ ปากอ้าเลือดไหลลงคาง
#   Krasue_Hair    หนังหัว + ปอยผมยาว 34 ปอย ตกรอบหน้าลงถึงระดับปอด
#   Krasue_Eyes    ลูกตาแดงก่ำ 2 ข้าง (แยกไว้ให้เกมตั้ง Neon / เรืองแสงได้)
#   Krasue_Organs  หลอดลม เส้นเลือด ปอด หัวใจ ก้อนไส้ ลำไส้ใหญ่ ไส้ห้อย — material แยก (Krasue_OrgansMat) ให้เกมทำเรืองแสง
# หน่วยเมตร (1 stud = 0.28 m) สูงรวม ~3 studs · หน้าหันไป -Y ใน Blender (= -Z/LookVector ใน Studio)
import bpy, bmesh, math, os, sys, json, random, traceback
import numpy as np
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")
PREV = os.path.join(ROOT, "previews")
NAME = "Krasue"
K = 0.28   # เมตรต่อ stud
N = 1024   # ขนาด texture
MG = 2     # ขอบกันสีเลอะ (px) ของแต่ละช่องใน atlas
FPS = 30
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(s)
    print(s)


def sm(e0, e1, x):
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def vnoise(n, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells + 1, cells + 1))
    x = np.linspace(0, cells, n, endpoint=False)
    i = x.astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    a, b, c, d = g[i][:, i], g[i][:, i + 1], g[i + 1][:, i], g[i + 1][:, i + 1]
    fx, fy = f[None, :], f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# ---------------------------------------------------------------- atlas: ช่องของแต่ละผิว (x0, y0, w, h) px จากมุมบนซ้าย
REG = {
    "face": (0, 0, 512, 512),       # หัว (หน้ากินพื้นที่ครึ่งหนึ่งของแนวนอน)
    "hair": (512, 0, 512, 512),     # ปอยผม
    "lung": (0, 512, 256, 256),
    "heart": (256, 512, 256, 256),
    "neck": (512, 512, 256, 256),
    "eye": (768, 512, 256, 256),
    "gut": (0, 768, 256, 256),      # ลำไส้เล็ก
    "trachea": (256, 768, 128, 128),
    "flesh": (384, 768, 128, 128),  # เนื้อตอคอขาด
    "vessel": (256, 896, 128, 128),
    "colon": (384, 896, 128, 128),  # ลำไส้ใหญ่
    "fang": (512, 768, 128, 128),
    "scalp": (640, 768, 128, 128),
}


def ruv(reg, s, t):
    """(s, t) ในช่อง reg -> UV ของ atlas (t = 1 คือขอบบนของช่อง)"""
    x0, y0, w, h = REG[reg]
    return ((x0 + MG + s * (w - 2 * MG)) / N, 1.0 - (y0 + MG + (1.0 - t) * (h - 2 * MG)) / N)


# ---------------------------------------------------------------- รูปทรงหัว
RX, RY, RZ = 0.083, 0.098, 0.122   # รัศมีกะโหลก (กว้าง ลึก สูง) กลางหัว = origin
# (cx, cy, cz, sx, sy, sz, ความนูน, สะท้อนซ้ายขวา) — นูน/บุ๋มตามแนวรัศมีจากกลางหัว
FEAT = [
    (0.031, -0.090, 0.012, 0.016, 0.03, 0.012, -0.011, True),     # เบ้าตาลึก
    (0.032, -0.092, 0.031, 0.020, 0.03, 0.0065, 0.004, True),     # สันคิ้ว
    (0.0, -0.100, -0.005, 0.0085, 0.04, 0.026, 0.014, False),     # สันจมูก
    (0.0, -0.104, -0.036, 0.011, 0.04, 0.011, 0.012, False),      # ปลายจมูก
    (0.011, -0.097, -0.042, 0.007, 0.03, 0.006, 0.005, True),     # ปีกจมูก
    (0.055, -0.070, -0.012, 0.016, 0.03, 0.014, 0.006, True),     # โหนกแก้ม
    (0.048, -0.075, -0.050, 0.015, 0.03, 0.018, -0.007, True),    # แก้มตอบ
    (0.0, -0.090, -0.076, 0.019, 0.04, 0.010, -0.011, False),     # ปากอ้า (บุ๋มลึก)
    (0.0, -0.093, -0.062, 0.021, 0.04, 0.0045, 0.0035, False),    # ริมฝีปากบน
    (0.0, -0.088, -0.091, 0.018, 0.04, 0.005, 0.004, False),      # ริมฝีปากล่าง
    (0.0, -0.072, -0.112, 0.015, 0.04, 0.012, 0.005, False),      # คาง
    (0.083, 0.0, 0.0, 0.006, 0.016, 0.024, 0.012, True),          # หู (ผมคลุม)
]


def head_xyz(a, ph):
    """a = มุมรอบแกนตั้ง (0 = หน้า -Y, บวกไป +X), ph = มุมจากกลางกระหม่อม -> จุดบนผิวหัว (numpy)"""
    a = np.asarray(a, float)
    ph = np.asarray(ph, float)
    sp = np.sin(ph)
    x = RX * sp * np.sin(a)
    y = -RY * sp * np.cos(a)
    z = RZ * np.cos(ph)
    low = sm(-0.01, -0.12, z)                      # กราม/คางเรียวลง
    x = x * (1 - 0.25 * low)
    y = np.where(y > 0, y * (1 - 0.35 * low), y * (1 - 0.12 * low))
    front = np.clip(np.cos(a), 0, 1) ** 2
    y = y - 0.032 * sm(-0.03, -0.115, z) * front   # หน้าช่วงล่างยื่นออก (ไม่ให้คางหลบเป็นไข่)
    d = np.zeros_like(x)
    for cx, cy, cz, sx, sy, sz, amp, mir in FEAT:
        for sg in ((1, -1) if mir else (1,)):
            d = d + amp * np.exp(-(((x - sg * cx) / sx) ** 2 + ((y - cy) / sy) ** 2 + ((z - cz) / sz) ** 2))
    ln = np.sqrt(x * x + y * y + (z + 0.01) ** 2) + 1e-9
    return x + d * x / ln, y + d * y / ln, z + d * (z + 0.01) / ln


def a_of(u):   # u -1..1 -> มุม (ถี่ตรงหน้า)
    u = np.asarray(u, float)
    return math.pi * (0.45 * u + 0.55 * u ** 3)


def ph_of(v):  # v 0..1 -> มุมจากกระหม่อม (ถี่ช่วงตา-ปาก)
    v = np.asarray(v, float)
    return math.pi * (v + 0.1 * np.sin(2 * math.pi * v))


_A, _P = np.meshgrid(np.linspace(-1.3, 1.3, 420), np.linspace(0.4, math.pi - 0.05, 420))
_HX, _HY, _HZ = head_xyz(_A, _P)


def surf_front(x, z):
    """จุดบนผิวหน้า (ฝั่ง -Y) ที่ใกล้ (x, z) ที่สุด"""
    d = (_HX - x) ** 2 + (_HZ - z) ** 2 + (_HY > 0) * 1.0
    k = np.unravel_index(np.argmin(d), d.shape)
    return Vector((float(_HX[k]), float(_HY[k]), float(_HZ[k])))


# ---------------------------------------------------------------- mesh builder (ใส่ UV ต่อ loop + น้ำหนักกระดูกต่อจุด)
class Part:
    def __init__(s, name):
        s.name = name
        s.co, s.w, s.f, s.uv = [], [], [], []

    def vert(s, p, w):
        s.co.append(Vector(p))
        s.w.append(w)
        return len(s.co) - 1

    def face(s, idx, uvs):
        oi, ou = [], []
        n = len(idx)
        for k in range(n):
            if idx[k] == idx[(k - 1) % n]:
                continue
            oi.append(idx[k])
            ou.append(uvs[k])
        if len(set(oi)) >= 3:
            s.f.append(oi)
            s.uv.append(ou)

    def grid(s, P, UV, wfn, close_u=False):
        """P[แถว][คอลัมน์]; แถวที่ทุกจุดเท่ากัน (ขั้ว) รวมเป็นจุดเดียว; close_u = คอลัมน์สุดท้ายคือคอลัมน์แรก (UV แยก)"""
        idx = []
        for row in P:
            if all((q - row[0]).length < 1e-7 for q in row):
                vi = s.vert(row[0], wfn(row[0]))
                idx.append([vi] * len(row))
                continue
            r = [s.vert(q, wfn(q)) for q in (row[:-1] if close_u else row)]
            if close_u:
                r.append(r[0])
            idx.append(r)
        f0 = len(s.f)
        for i in range(len(P) - 1):
            for j in range(len(P[0]) - 1):
                s.face([idx[i][j], idx[i][j + 1], idx[i + 1][j + 1], idx[i + 1][j]],
                       [UV[i][j], UV[i][j + 1], UV[i + 1][j + 1], UV[i + 1][j]])
        return f0

    def orient(s, f0, center):
        """กลับด้านหน้าทั้งกลุ่มถ้าส่วนใหญ่หันเข้าหา center"""
        c0 = Vector(center)
        tot = 0.0
        for fi in range(f0, len(s.f)):
            vs = [s.co[i] for i in s.f[fi]]
            c = sum(vs, Vector()) / len(vs)
            nrm = Vector()
            for k in range(len(vs)):
                nrm += vs[k].cross(vs[(k + 1) % len(vs)])
            tot += nrm.dot(c - c0)
        if tot < 0:
            for fi in range(f0, len(s.f)):
                s.f[fi].reverse()
                s.uv[fi].reverse()

    def tube(s, pts, radii, reg, wfn, n=8, ups=None, flat=1.0, chunk=None, cap0=True, cap1=True, rmod=None):
        """ท่อตามเส้น pts; ups = ทิศแกนแบน (ถ้าไม่ให้ใช้ parallel transport); flat = สัดส่วนความหนาตามแกน ups;
        chunk = ความยาว (ม.) ต่อ 1 รอบ texture ตามแนวท่อ (ไม่ให้ = ยืดทั้งเส้น); rmod(L, th) = ตัวคูณรัศมี"""
        pts = [Vector(p) for p in pts]
        L = [0.0]
        for p0, p1 in zip(pts, pts[1:]):
            L.append(L[-1] + (p1 - p0).length)
        tot = max(L[-1], 1e-6)
        rings, prev = [], None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
            if ups is not None:
                nn = Vector(ups[i])
                nn = (nn - t * nn.dot(t)).normalized()
            elif prev is None:
                up = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 0, 1))
                nn = t.cross(up).normalized()
            else:
                nn = (prev - t * prev.dot(t)).normalized()
            prev = nn
            bb = t.cross(nn).normalized()
            ring = []
            for j in range(n):
                th = 2 * math.pi * j / n
                r = radii[i] * (rmod(L[i], th) if rmod else 1.0)
                q = p + nn * (math.cos(th) * r * flat) + bb * (math.sin(th) * r)
                ring.append(s.vert(q, wfn(q)))
            ring.append(ring[0])
            rings.append(ring)
        for i in range(len(pts) - 1):
            if chunk:
                base = math.floor(L[i] / chunk + 1e-9) * chunk
                t0, t1 = (L[i] - base) / chunk, min((L[i + 1] - base) / chunk, 1.0)
            else:
                t0, t1 = L[i] / tot, L[i + 1] / tot
            for j in range(n):
                s0, s1 = j / n, (j + 1) / n
                s.face([rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]],
                       [ruv(reg, s0, t0), ruv(reg, s1, t0), ruv(reg, s1, t1), ruv(reg, s0, t1)])

        def cuv(j):
            th = 2 * math.pi * j / n
            return ruv(reg, 0.5 + 0.4 * math.cos(th), 0.5 + 0.4 * math.sin(th))

        if cap0:
            c = s.vert(pts[0], wfn(pts[0]))
            for j in range(n):
                s.face([c, rings[0][j + 1], rings[0][j]], [ruv(reg, 0.5, 0.5), cuv(j + 1), cuv(j)])
        if cap1:
            c = s.vert(pts[-1], wfn(pts[-1]))
            for j in range(n):
                s.face([c, rings[-1][j], rings[-1][j + 1]], [ruv(reg, 0.5, 0.5), cuv(j), cuv(j + 1)])
        return L

    def ellip(s, center, radii, reg, wfn, nu=24, nv=14, rot=None, shape=None):
        """ทรงรี (ขั้วบน-ล่างตามแกน Z ก่อนหมุน) UV: s รอบตัว (หน้า -Y = 0.5), t จากบน"""
        R = rot or Matrix.Identity(3)
        c0 = Vector(center)
        P, UV = [], []
        for i in range(nv + 1):
            ph = math.pi * i / nv
            row, urow = [], []
            for j in range(nu + 1):
                a = 2 * math.pi * j / nu - math.pi
                d = Vector((math.sin(ph) * math.sin(a), -math.sin(ph) * math.cos(a), math.cos(ph)))
                loc = Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2]))
                if shape:
                    loc = shape(loc, d)
                row.append(c0 + R @ loc)
                urow.append(ruv(reg, j / nu, 1 - i / nv))
            P.append(row)
            UV.append(urow)
        f0 = s.grid(P, UV, wfn, close_u=True)
        s.orient(f0, c0)


def catmull(ctrl, sub=6):
    P = [Vector(c) for c in ctrl]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(sub):
            t = k / sub
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2].copy())
    return out


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def norm4(d):
    """เหลือไม่เกิน 4 กระดูกต่อจุด (ข้อจำกัด Roblox) แล้วรวมให้เป็น 1"""
    items = sorted(((w, n) for n, w in d.items() if w > 1e-4), reverse=True)[:4]
    tot = sum(w for w, _ in items) or 1.0
    return {n: w / tot for w, n in items}


# ---------------------------------------------------------------- ไส้ห้อย (เส้นหลัก) + กระดูก
GUT_C = Vector((0.0, -0.004, -0.468))   # กลางก้อนไส้
TAIL = catmull([(0.012, 0.004, -0.500), (0.024, -0.004, -0.545), (0.004, -0.010, -0.588), (-0.016, -0.002, -0.630),
                (-0.004, 0.008, -0.672), (0.014, 0.002, -0.705), (0.006, -0.006, -0.728)], sub=7)


def tail_points(nb):
    L = [0.0]
    for p0, p1 in zip(TAIL, TAIL[1:]):
        L.append(L[-1] + (p1 - p0).length)
    out = []
    for k in range(nb + 1):
        target = L[-1] * k / nb
        i = max(j for j in range(len(L)) if L[j] <= target + 1e-9)
        if i >= len(TAIL) - 1:
            out.append(TAIL[-1].copy())
        else:
            f = (target - L[i]) / max(L[i + 1] - L[i], 1e-9)
            out.append(TAIL[i].lerp(TAIL[i + 1], f))
    return out


_tp = tail_points(6)
FWD = (0, -1, 0)   # แกน Z ของกระดูกหันไปหน้า
BONES = [  # ชื่อ, head, tail, parent
    ("Head", (0, 0.0, -0.13), (0, 0.0, 0.11), None),
    ("Hair_L1", (0.088, 0.0, 0.0), (0.100, 0.005, -0.14), "Head"),
    ("Hair_L2", (0.100, 0.005, -0.14), (0.115, 0.010, -0.34), "Hair_L1"),
    ("Hair_R1", (-0.088, 0.0, 0.0), (-0.100, 0.005, -0.14), "Head"),
    ("Hair_R2", (-0.100, 0.005, -0.14), (-0.115, 0.010, -0.34), "Hair_R1"),
    ("Hair_B1", (0.0, 0.100, 0.0), (0.0, 0.115, -0.14), "Head"),
    ("Hair_B2", (0.0, 0.115, -0.14), (0.0, 0.130, -0.38), "Hair_B1"),
    ("Windpipe", (0, -0.010, -0.17), (0, -0.005, -0.30), "Head"),
    ("Heart", (0.012, -0.048, -0.355), (0.012, -0.048, -0.45), "Windpipe"),
    ("Gut1", (0.0, 0.0, -0.415), tuple(_tp[0]), "Windpipe"),
] + [(f"Gut{k + 2}", tuple(_tp[k]), tuple(_tp[k + 1]), f"Gut{k + 1}") for k in range(6)]
SEG = {b[0]: (Vector(b[1]), Vector(b[2])) for b in BONES}
GUTS = [f"Gut{k}" for k in range(1, 8)]


def W(name):
    return lambda p: {name: 1.0}


def w_hair(p):
    az = math.atan2(p.x, -p.y)
    side = "L" if az >= 0 else "R"
    wb = float(sm(math.pi / 2, math.pi, abs(az)))
    wh = float(sm(-0.04, 0.03, p.z))     # รากผมติดหัว
    u = float(sm(-0.06, -0.22, p.z))     # ช่วงล่างเป็นของกระดูกข้อ 2 (ผสมยาวๆ ไม่หักเป็นมุม)
    d = {"Head": wh}
    for c, wc in ((side, 1 - wb), ("B", wb)):
        if wc > 0:
            d[f"Hair_{c}1"] = wc * (1 - wh) * (1 - u)
            d[f"Hair_{c}2"] = wc * (1 - wh) * u
    return d


def w_neckpipe(p):
    hw = float(sm(-0.20, -0.16, p.z))
    return {"Head": hw, "Windpipe": 1 - hw}


def w_vessel(p):
    hw = float(sm(-0.20, -0.16, p.z))
    cw = float(sm(-0.29, -0.325, p.z))
    return {"Head": hw * (1 - cw), "Windpipe": (1 - hw) * (1 - cw), "Heart": cw}


def w_guts(p):
    ds = sorted((seg_dist(p, *SEG[n]), n) for n in GUTS)
    best = ds[0][0]
    pick = [(d, n) for d, n in ds if d <= best * 1.35 + 0.004][:3]
    ws = [1.0 / (d + 0.003) ** 4 for d, _ in pick]
    tot = sum(ws)
    return {n: w / tot for w, (_, n) in zip(ws, pick)}


# ================================================================ 1. หัว คอ เขี้ยว
STREAKS = [(-0.016, 0.0030, -0.135), (-0.007, 0.0045, -0.165), (0.003, 0.0035, -0.118), (0.011, 0.0050, -0.172), (0.018, 0.0028, -0.126)]
NECK = dict(cy=0.012, rx=0.037, ry=0.039, z0=-0.045, z1=-0.183)


def build_head():
    m = Part("Krasue")
    NU, NV = 64, 44
    us = [-1 + 2 * j / NU for j in range(NU + 1)]
    vs = [i / NV for i in range(NV + 1)]
    AA, PP = np.meshgrid(a_of(us), ph_of(vs))
    X, Y, Z = head_xyz(AA, PP)
    P = [[Vector((X[i, j], Y[i, j], Z[i, j])) for j in range(NU + 1)] for i in range(NV + 1)]
    UV = [[ruv("face", (us[j] + 1) / 2, 1 - vs[i]) for j in range(NU + 1)] for i in range(NV + 1)]
    m.orient(m.grid(P, UV, W("Head"), close_u=True), (0, 0, 0))
    # คอ: ท่อรีจากในหัวลงไปถึงตอคอขาด (ขอบหนังขาดรุ่งริ่ง) แล้วพับเข้าเป็นเนื้อแดงข้างใน
    nc = 20
    rng = random.Random(4)
    jag = [rng.random() for _ in range(nc)]
    jag = [(jag[j] + 0.5 * jag[(j + 1) % nc] + 0.5 * jag[j - 1]) / 2 for j in range(nc)]
    zs = [NECK["z0"] + (NECK["z1"] - NECK["z0"]) * k / 6 for k in range(7)]
    rows, urows = [], []
    for k, z in enumerate(zs):
        grow = 1 + 0.06 * (k / 6) ** 2
        row, ur = [], []
        for j in range(nc + 1):
            th = 2 * math.pi * j / nc - math.pi
            zz = z - (0.010 * jag[j % nc] if k == 6 else 0.0)
            row.append(Vector((NECK["rx"] * grow * math.sin(th), NECK["cy"] - NECK["ry"] * grow * math.cos(th), zz)))
            ur.append(ruv("neck", j / nc, 1 - k / 6))
        rows.append(row)
        urows.append(ur)
    c = Vector((0, NECK["cy"], -0.11))
    m.orient(m.grid(rows, urows, W("Head"), close_u=True), c)
    rim = rows[-1]
    inner = [Vector((q.x * 0.78, NECK["cy"] + (q.y - NECK["cy"]) * 0.78, NECK["z1"] + 0.006)) for q in rim]
    ctr = [Vector((0, NECK["cy"] + 0.004, NECK["z1"] + 0.012))] * (nc + 1)
    fl = [[ruv("flesh", 0.5 + rr * math.cos(2 * math.pi * j / nc), 0.5 + rr * math.sin(2 * math.pi * j / nc)) for j in range(nc + 1)]
          for rr in (0.48, 0.32, 0.0)]
    m.orient(m.grid([rim, inner, ctr], fl, W("Head"), close_u=True), c)
    # เขี้ยว: บน 2 ซี่ยาว ล่าง 2 ซี่สั้น
    for sg in (1, -1):
        for x, z, dz, r0 in ((0.0115, -0.067, -0.017, 0.0034), (0.0085, -0.0875, 0.009, 0.0024)):
            b0 = surf_front(sg * x, z) + Vector((0, -0.001, 0))
            tip = b0 + Vector((0, 0.002, dz))
            pts = [b0.lerp(tip, k / 4) + Vector((0, -0.0012 * math.sin(math.pi * k / 4), 0)) for k in range(5)]
            m.tube(pts, [r0 * (1 - 0.92 * k / 4) for k in range(5)], "fang", W("Head"), n=6)
    return m


def build_eyes():
    m = Part("Krasue_Eyes")
    centers = []
    for sg in (1, -1):
        c = surf_front(sg * 0.031, 0.011) + Vector((0, 0.0075, 0))
        centers.append(c)
        m.ellip(c, (0.0125, 0.0125, 0.0125), "eye", W("Head"), nu=16, nv=10)
    return m, centers


# ================================================================ 2. ผม
def rho(a):
    return 1.0 / math.sqrt((math.sin(a) / RX) ** 2 + (math.cos(a) / RY) ** 2)


def build_hair():
    m = Part("Krasue_Hair")
    # หนังหัว: เปลือกครอบกะโหลก แนวผมหน้าผากสูง แสกกลาง ด้านหลังลงถึงท้ายทอย
    NA, NI = 48, 9
    P, UV = [], []
    for i in range(NI + 1):
        row, ur = [], []
        for j in range(NA + 1):
            a = 2 * math.pi * j / NA - math.pi
            phm = 0.62 + (1.9 - 0.62) * float(sm(0.5, 2.6, abs(a)))
            ph = phm * i / NI
            off = 0.006 - 0.003 * math.exp(-(a / 0.06) ** 2) * (ph < 1.0)
            row.append(Vector(((RX + off) * math.sin(ph) * math.sin(a), -(RY + off) * math.sin(ph) * math.cos(a), (RZ + off) * math.cos(ph))))
            ur.append(ruv("scalp", j / NA, 1 - i / NI))
        P.append(row)
        UV.append(ur)
    m.orient(m.grid(P, UV, W("Head"), close_u=True), (0, 0, 0))
    # ปอยผม: (มุมราก, ph ราก, มุมปลาย, z ปลาย, กว้าง, ชั้น)
    locks = []
    rng = random.Random(11)
    for sg in (1, -1):
        for a0, ph0, a1, ze, w in ((0.10, 0.30, 0.95, -0.27, 0.030), (0.24, 0.42, 1.08, -0.31, 0.032), (0.40, 0.52, 1.22, -0.29, 0.034)):
            locks.append((sg * a0, ph0, sg * a1, ze, w, 0))
        for k in range(14):
            a0 = 0.75 + k * (math.pi - 0.75) / 13.5
            a1 = max(a0 + 0.04 * (rng.random() - 0.5), 1.3)
            ze = -0.29 - 0.08 * (a0 / math.pi) - 0.035 * rng.random()
            locks.append((sg * a0, 0.55 + 0.3 * rng.random(), sg * a1, ze, 0.034, k % 2))
    for li, (a0, ph0, a1, ze, wd, layer) in enumerate(locks):
        off = 0.011 + 0.007 * layer
        NA_, NB_ = 5, 11
        pts, ups, wid = [], [], []
        for k in range(NA_ + NB_ + 1):
            u = k / (NA_ + NB_)
            if k <= NA_:
                f = k / NA_
                ph = ph0 + (math.pi / 2 - ph0) * f
                a = a0 + (a1 - a0) * float(sm(0.0, 1.0, f))
                o = 0.001 + (off - 0.001) * float(sm(0.0, 0.6, f))   # รากผมจมใต้หนังหัว ไม่โผล่เป็นหนาม
                p = Vector(((RX + o) * math.sin(ph) * math.sin(a), -(RY + o) * math.sin(ph) * math.cos(a), (RZ + o) * math.cos(ph)))
            else:
                f = (k - NA_) / NB_
                z = ze * f
                a = a1 + 0.035 * math.sin(f * 5 + li) + (0.12 * math.copysign(1, a1) if abs(a1) < 1.3 else 0) * f * f
                fl = 0.075 * (-z)
                p = Vector(((RX + off + fl) * math.sin(a), -(RY + off + fl) * math.cos(a), z))
            pts.append(p)
            ups.append(Vector((p.x / (RX + off) ** 2, p.y / (RY + off) ** 2, max(p.z, 0) / (RZ + off) ** 2)))
            wid.append(wd * (0.6 + 0.6 * float(sm(0, 0.25, u)) - 0.85 * float(sm(0.72, 1.0, u))) / 2)
        m.tube(pts, wid, "hair", w_hair, n=6, ups=ups, flat=0.2)
    log(f"  hair locks: {len(locks)}")
    return m


# ================================================================ 3. อวัยวะ
def lung_shape(sg):
    def f(loc, d):
        top = float(sm(0.2, 1.0, d.z))
        sc = 1 - 0.45 * top
        x, y, z = loc.x * sc, loc.y * sc, loc.z
        if x * sg < 0:
            x *= 0.6                               # ด้านในแบนชิดหัวใจ
        if z < -0.06:
            z = -0.06 + (z + 0.06) * 0.6           # ฐานปอดแบน
        g = -0.005 * math.exp(-((d.z + 0.6 * d.x * sg - 0.05) / 0.08) ** 2) * (1.0 if x * sg > 0 else 0.3)   # ร่องแบ่งกลีบ
        lump = 0.0025 * math.sin(d.x * 13 + sg) * math.sin(d.y * 11) * math.sin(d.z * 9)
        v = Vector((x, y, z))
        return v + v.normalized() * (g + lump)
    return f


def heart_shape(loc, d):
    sc = 0.55 + 0.45 * float(sm(-1.0, 0.3, d.z))   # ปลายหัวใจแหลม
    v = Vector((loc.x * sc, loc.y * sc, loc.z * (0.92 if d.z > 0.5 else 1.0)))
    g = -0.003 * math.exp(-((d.x - 0.15) / 0.12) ** 2) * (1.0 if d.y < 0 else 0.0)
    return v + v.normalized() * g


def build_organs():
    m = Part("Krasue_Organs")
    # หลอดลม (วงกระดูกอ่อนนูนทุก 1.2 ซม.) แตกเป็นหลอดลมซ้ายขวาเข้าปอด
    tr = [Vector((0, -0.008 + 0.004 * k / 44, -0.160 - 0.135 * k / 44)) for k in range(45)]
    m.tube(tr, [0.0115] * 45, "trachea", w_neckpipe, n=10, chunk=0.048,
           rmod=lambda L, th: 1 + 0.10 * max(0.0, math.sin(L * 2 * math.pi / 0.012)), cap0=False)
    for sg in (1, -1):
        br = catmull([(0, -0.004, -0.290), (sg * 0.028, -0.002, -0.305), (sg * 0.050, 0.0, -0.318)], sub=4)
        m.tube(br, [0.0085 - 0.0015 * k / (len(br) - 1) for k in range(len(br))], "trachea", W("Windpipe"), n=8, chunk=0.048)
    # เส้นเลือดใหญ่จากตอคอลงไปหัวใจ
    for sg in (1, -1):
        vs = catmull([(sg * 0.020, 0.0, -0.168), (sg * 0.026, -0.012, -0.220), (sg * 0.018, -0.030, -0.280), (sg * 0.008, -0.040, -0.330)], sub=6)
        m.tube(vs, [0.0055] * len(vs), "vessel", w_vessel, n=8, chunk=0.06)
    ao = catmull([(0.008, -0.045, -0.365), (0.004, -0.040, -0.325), (0.0, -0.018, -0.308), (0.0, 0.010, -0.330), (0.0, 0.016, -0.400)], sub=6)
    m.tube(ao, [0.010] * len(ao), "vessel", lambda p: {"Heart": float(sm(-0.03, -0.045, p.y)) if p.y > -0.03 else 1.0,
                                                    "Windpipe": 1 - (float(sm(-0.03, -0.045, p.y)) if p.y > -0.03 else 1.0)}, n=10, chunk=0.06)
    # ปอดซ้ายขวา
    for sg in (1, -1):
        m.ellip((sg * 0.064, 0.006, -0.335), (0.047, 0.044, 0.088), "lung", W("Windpipe"), nu=24, nv=16, shape=lung_shape(sg))
    # หัวใจ (ปลายชี้ลงซ้าย-หน้า)
    rot = Matrix.Rotation(math.radians(-20), 3, "Y") @ Matrix.Rotation(math.radians(-15), 3, "X")
    m.ellip((0.012, -0.048, -0.402), (0.036, 0.032, 0.048), "heart", W("Heart"), nu=20, nv=14, rot=rot, shape=heart_shape)
    # ก้อนลำไส้เล็กขดกันแน่น (Lissajous ในทรงรี)
    GE = (0.068, 0.050, 0.048)
    gp = []
    M_ = 230
    for k in range(M_ + 1):
        t = 2 * math.pi * k / M_
        x, y, z = math.sin(3 * t + 0.4), math.sin(2 * t + 1.3), math.sin(5 * t + 0.2)
        x2, y2, z2 = x * x, y * y, z * z
        xs = x * math.sqrt(max(0.0, 1 - y2 / 2 - z2 / 2 + y2 * z2 / 3))
        ys = y * math.sqrt(max(0.0, 1 - z2 / 2 - x2 / 2 + z2 * x2 / 3))
        zs = z * math.sqrt(max(0.0, 1 - x2 / 2 - y2 / 2 + x2 * y2 / 3))
        gp.append(GUT_C + Vector((xs * GE[0], ys * GE[1], zs * GE[2])))
    m.tube(gp, [0.019] * len(gp), "gut", W("Gut1"), n=8, chunk=0.12, cap0=False, cap1=False)
    # ลำไส้ใหญ่โค้งครอบก้อนไส้ด้านหน้า (เป็นปล้องๆ)
    cp = []
    for k in range(41):
        th = math.radians(200 - 220 * k / 40)
        cp.append(Vector((0.088 * math.cos(th), -0.022 + 0.012 * math.sin(2 * th), GUT_C.z + 0.062 * math.sin(th))))
    cp += [Vector((0.075, -0.012, -0.515)), Vector((0.062, -0.006, -0.535))]
    m.tube(cp, [0.019] * len(cp), "colon", W("Gut1"), n=10, chunk=0.10,
           rmod=lambda L, th: 1 + 0.16 * abs(math.sin(L * math.pi / 0.028)))
    # ห่วงไส้ห้อยสองข้าง
    for sg in (1, -1):
        lp = catmull([(sg * 0.050, -0.010, -0.490), (sg * 0.065, -0.020, -0.540), (sg * 0.060, -0.025, -0.585), (sg * 0.045, -0.020, -0.595),
                      (sg * 0.030, -0.012, -0.560), (sg * 0.028, -0.005, -0.505)], sub=6)
        m.tube(lp, [0.0135] * len(lp), "gut", w_guts, n=8, chunk=0.12)
    # ไส้เส้นหลักห้อยลงล่าง (โซ่กระดูก Gut2..Gut7) ปลายขาดรุ่งริ่ง
    rad = [0.015 - 0.004 * k / (len(TAIL) - 1) for k in range(len(TAIL))]
    m.tube(TAIL, rad, "gut", w_guts, n=10, chunk=0.12, rmod=lambda L, th: 1 + 0.08 * math.sin(L * 2 * math.pi / 0.03))
    return m


ORG_S = 0.82      # ย่ออวัยวะรอบตอคอ ให้หัวเด่นกว่า (ตามภาพอ้างอิง)
ORG_C = Vector((0, 0, -0.165))
ORG_BONES = {"Windpipe", "Heart"} | set(GUTS)
TARGET_H = 3.0 * K  # สูงรวม 3 studs


def rescale(parts, organs):
    """ย่ออวัยวะรอบตอคอ แล้วขยายทั้งตัว (mesh + กระดูก) ให้สูงรวม TARGET_H; คืนตัวคูณรวม"""
    global BONES, SEG
    org = lambda p: ORG_C + (Vector(p) - ORG_C) * ORG_S
    organs.co = [org(p) for p in organs.co]
    BONES = [(n, tuple(org(h)) if n in ORG_BONES else h, tuple(org(t)) if n in ORG_BONES else t, par) for n, h, t, par in BONES]
    zs = [p.z for pt in parts for p in pt.co]
    G = TARGET_H / (max(zs) - min(zs))
    for pt in parts:
        pt.co = [p * G for p in pt.co]
    BONES = [(n, tuple(Vector(h) * G), tuple(Vector(t) * G), par) for n, h, t, par in BONES]
    SEG = {b[0]: (Vector(b[1]), Vector(b[2])) for b in BONES}
    return G


# ================================================================ 4. texture
def region_st(reg):
    x0, y0, w, h = REG[reg]
    s = np.clip((np.arange(w) + 0.5 - MG) / (w - 2 * MG), 0, 1)
    t = 1 - np.clip((np.arange(h) + 0.5 - MG) / (h - 2 * MG), 0, 1)
    S, T = np.meshgrid(s, t)
    return S, T, w


def mix(c, m_, colr):
    return c * (1 - m_[..., None]) + np.array(colr, float) * m_[..., None]


def skin_base(n, seed):
    n1, n2 = vnoise(n, 8, seed), vnoise(n, 32, seed + 1)
    col = np.array([0.80, 0.81, 0.78]) * (0.9 + 0.12 * n1 + 0.06 * n2)[..., None]
    blot = sm(0.55, 0.8, vnoise(n, 14, seed + 2))
    col = mix(col, 0.25 * blot, (0.55, 0.60, 0.62))
    return col, n2


def blood_streaks(x, z, front, zmax):
    b = np.zeros_like(x)
    for x0, w, ze in STREAKS:
        xc = x0 + 0.0015 * np.sin(z * 260 + x0 * 400)
        b = b + np.exp(-((x - xc) / w) ** 2) * (z < zmax) * (z > ze) * front
        b = b + np.exp(-(((x - x0) ** 2 + ((z - ze) / 1.4) ** 2) / (1.5 * w) ** 2)) * front
    return np.clip(b, 0, 1)


def paint_face():
    S, T, n = region_st("face")
    a, ph = a_of(2 * S - 1), ph_of(1 - T)
    x, y, z = head_xyz(a, ph)
    col, n2 = skin_base(n, 11)
    n3 = vnoise(n, 90, 13)
    fr = (y < -0.02).astype(float)
    col = col * (1 - 0.25 * sm(0.3, -0.6, np.cos(a)))[..., None]     # หลังหัวหม่นลง (ผมคลุม)
    col = col * (1 - 0.18 * sm(-0.09, -0.122, z))[..., None]
    h = 0.15 * n2 + 0.08 * n3
    r = 0.55 + 0.1 * n2
    eyes = np.zeros_like(x)
    rim = np.zeros_like(x)
    for sg in (1, -1):
        eyes += np.exp(-(((x - sg * 0.031) / 0.021) ** 2 + ((z - 0.009) / 0.016) ** 2))
        dd = np.sqrt((x - sg * 0.031) ** 2 + ((z - 0.010) / 0.8) ** 2)
        rim += np.exp(-((dd - 0.0135) / 0.0025) ** 2)
    col = mix(col, 0.88 * np.clip(eyes, 0, 1) ** 1.3 * fr, (0.16, 0.06, 0.09))      # เบ้าตาคล้ำม่วง
    col = mix(col, 0.6 * np.clip(rim, 0, 1) * fr, (0.45, 0.03, 0.05))              # ขอบตาแดง
    for sg in (1, -1):                                                              # คิ้วบาง ปลายในกดต่ำ (หน้าดุ)
        dx = (x - sg * 0.033) / 0.019
        zb = 0.031 + 0.004 * (1 - dx ** 2) + 0.005 * ((np.abs(x) - 0.033) / 0.019)
        col = mix(col, 0.85 * np.exp(-((z - zb) / 0.0024) ** 2) * np.exp(-dx ** 4) * fr, (0.05, 0.04, 0.04))
    # เส้นเลือดดำคล้ำที่ขมับและใต้คาง
    vein = (np.abs(vnoise(n, 18, 21) - 0.5) < 0.012) * (((np.abs(x) > 0.045) & (z > -0.02)) | (z < -0.095))
    col = mix(col, 0.3 * vein, (0.36, 0.40, 0.52))
    # ปาก: ข้างในดำแดง ฟันเหลือง ริมฝีปากคล้ำ
    q = (x / 0.0205) ** 2 + ((z + 0.0765) / 0.0125) ** 2
    mouth = (q < 1) * fr
    lips = ((q >= 1) & (q < 2.1)) * fr
    col = mix(col, 0.85 * lips, (0.30, 0.03, 0.05))
    col = mix(col, mouth, (0.08, 0.0, 0.01))
    teeth = mouth * (((z > -0.0765 + 0.0125 * 0.45) | (z < -0.0765 - 0.0125 * 0.55)) & (np.sin(x * 2 * math.pi / 0.0052) > -0.5))
    col = mix(col, teeth, (0.78, 0.72, 0.58))
    h = h - 0.5 * mouth + 0.2 * lips
    r = np.where(mouth > 0, 0.3, np.where(lips > 0, 0.35, r))
    # เลือด: มุมปาก ริมฝีปากล่าง ไหลเป็นทางลงคางถึงคอ + น้ำตาเลือด
    blood = blood_streaks(x, z, fr, -0.084)
    blood = blood + 0.75 * np.exp(-((x / 0.02) ** 2 + ((z + 0.1) / 0.012) ** 2)) * fr
    for sg in (1, -1):
        blood = blood + np.exp(-(((x - sg * 0.021) / 0.006) ** 2 + ((z + 0.08) / 0.008) ** 2)) * fr
        xc = sg * (0.029 + 0.002 * np.sin(z * 200))
        blood = blood + 0.7 * np.exp(-((x - xc) / 0.0016) ** 2) * (z < 0.0) * (z > -0.05 + 0.01 * sg) * fr
    blood = np.clip(blood, 0, 1) * (1 - mouth)
    col = mix(col, blood, (0.32, 0.0, 0.02))
    r = r * (1 - blood) + 0.12 * blood
    h = h + 0.25 * blood
    return col, h, r


def paint_neck():
    S, T, n = region_st("neck")
    th = (S - 0.5) * 2 * math.pi
    x = NECK["rx"] * np.sin(th)
    z = NECK["z0"] + (1 - T) * (NECK["z1"] - NECK["z0"])
    fr = (np.cos(th) > 0.2).astype(float)
    col, n2 = skin_base(n, 31)
    col = col * (0.9 - 0.2 * sm(0.3, -0.6, np.cos(th)))[..., None]
    blood = blood_streaks(x, z, fr, -0.06)
    soak = sm(0.30, 0.02, T + 0.15 * (vnoise(n, 10, 33) - 0.5))
    drip = (np.sin(S * 2 * math.pi * 9 + 1.3) > 0.85) * sm(0.45, 0.1, T)
    blood = np.clip(blood + soak + drip, 0, 1)
    col = mix(col, blood, (0.30, 0.0, 0.02))
    return col, 0.15 * n2 + 0.2 * blood, 0.55 * (1 - blood) + 0.14 * blood


def paint_hair(reg, seed):
    S, T, n = region_st(reg)
    lo1, lo2 = vnoise(n, 5, seed), vnoise(n, 7, seed + 1)
    strand = 0.5 * (0.5 + 0.5 * np.sin(S * 2 * math.pi * 19 + 2.0 * lo1)) + 0.5 * (0.5 + 0.5 * np.sin(S * 2 * math.pi * 47 + 3.0 * lo2))
    col = np.array([0.018, 0.018, 0.022]) + np.array([0.05, 0.05, 0.06]) * (strand ** 2)[..., None]
    hl = np.exp(-((T - 0.7 - 0.05 * np.sin(S * 12)) / 0.06) ** 2) * strand
    col = col + np.array([0.06, 0.06, 0.075]) * hl[..., None]
    return col, strand, 0.38 + 0.2 * (1 - strand)


def paint_organ(reg, base, dark, seed, rough=0.18):
    S, T, n = region_st(reg)
    n1, n2, n3 = vnoise(n, 6, seed), vnoise(n, 28, seed + 1), vnoise(n, 70, seed + 2)
    col = np.array(base) * (0.75 + 0.35 * n2 + 0.15 * n1)[..., None]
    veins = ((np.abs(vnoise(n, 10, seed + 3) - 0.5) < 0.018) | (np.abs(vnoise(n, 22, seed + 4) - 0.5) < 0.01)).astype(float)
    col = mix(col, 0.75 * veins, dark)
    spots = sm(0.72, 0.85, n3)
    col = mix(col, 0.5 * spots, dark)
    return S, T, n, n1, col, 0.4 * n2 + 0.3 * n3 + 0.4 * veins, rough + 0.12 * n2


def paint_all():
    col = np.zeros((N, N, 3))
    hgt = np.zeros((N, N))
    rgh = np.full((N, N), 0.6)

    def put(reg, c, h, r):
        x0, y0, w, hh = REG[reg]
        col[y0:y0 + hh, x0:x0 + w] = np.clip(c, 0, 1)
        hgt[y0:y0 + hh, x0:x0 + w] = h
        rgh[y0:y0 + hh, x0:x0 + w] = np.clip(r, 0.04, 1)

    put("face", *paint_face())
    put("neck", *paint_neck())
    put("hair", *paint_hair("hair", 41))
    put("scalp", *paint_hair("scalp", 43))
    _, _, _, _, c, h, r = paint_organ("lung", (0.55, 0.04, 0.06), (0.25, 0.0, 0.03), 51)
    put("lung", c, h, r)
    S, T, n, n1, c, h, r = paint_organ("heart", (0.42, 0.02, 0.04), (0.22, 0.0, 0.05), 61)
    fat = sm(0.7, 0.85, T + 0.15 * (n1 - 0.5))
    c = mix(c, 0.85 * fat, (0.82, 0.62, 0.30))
    cor = (np.abs(np.sin(S * 2 * math.pi * 3 + 1.5 * np.sin(T * 7))) < 0.07) * (T < 0.8)
    c = mix(c, 0.8 * cor, (0.22, 0.0, 0.06))
    put("heart", c, h + 0.4 * cor, r)
    S, T, n, n1, c, h, r = paint_organ("gut", (0.58, 0.10, 0.11), (0.35, 0.03, 0.10), 71, 0.2)
    folds = 0.5 + 0.5 * np.sin(T * 2 * math.pi * 10)
    c = c * (0.82 + 0.25 * folds)[..., None]
    mes = (np.abs(S - 0.25 - 0.02 * np.sin(T * 40)) < 0.015).astype(float)
    c = mix(c, mes, (0.40, 0.03, 0.12))
    put("gut", c, h + 0.4 * folds + 0.3 * mes, r)
    S, T, n, n1, c, h, r = paint_organ("colon", (0.50, 0.12, 0.14), (0.30, 0.04, 0.08), 81, 0.25)
    band = sm(0.0, 0.06, 0.04 - np.abs(S - 0.5))
    c = mix(c, 0.6 * band, (0.75, 0.55, 0.50))
    put("colon", c, h + 0.3 * band, r)
    S, T, n, n1, c, h, r = paint_organ("trachea", (0.55, 0.08, 0.10), (0.30, 0.0, 0.04), 91, 0.3)
    cart = sm(-0.2, 0.3, np.sin(T * 2 * math.pi * 4))
    c = mix(c, 0.8 * cart, (0.78, 0.48, 0.46))
    put("trachea", c, h + cart, r)
    S, T, n, n1, c, h, r = paint_organ("flesh", (0.48, 0.03, 0.05), (0.12, 0.0, 0.02), 101)
    c = mix(c, sm(0.8, 0.9, vnoise(n, 30, 105)), (0.80, 0.50, 0.45))
    put("flesh", c, h, r)
    _, _, _, _, c, h, r = paint_organ("vessel", (0.34, 0.02, 0.07), (0.18, 0.0, 0.05), 111, 0.2)
    put("vessel", c, h, r)
    S, T, n = region_st("fang")
    c = np.array([0.86, 0.82, 0.68]) * (0.8 + 0.2 * (1 - T))[..., None]
    c = mix(c, 0.75 * sm(0.55, 0.9, T), (0.40, 0.0, 0.02))
    put("fang", c, np.zeros_like(T), 0.3 + 0 * T)
    # ลูกตา: ตาขาวแดงก่ำเส้นเลือดเต็ม ม่านตาแดงสด รูม่านตาดำเล็ก
    S, T, n = region_st("eye")
    a, ph = (S - 0.5) * 2 * math.pi, (1 - T) * math.pi
    ca = np.sin(ph) * np.cos(a)
    c = np.ones((n, n, 3)) * np.array([0.62, 0.12, 0.12])
    c = mix(c, 0.8 * (np.abs(vnoise(n, 12, 121) - 0.5) < 0.02), (0.30, 0.0, 0.03))
    c = mix(c, sm(0.80, 0.93, ca), (1.0, 0.18, 0.08))
    c = mix(c, sm(0.93, 0.975, ca), (1.0, 0.55, 0.30))
    c = mix(c, sm(0.988, 0.993, ca), (0.03, 0.0, 0.0))
    put("eye", c, np.zeros_like(T), 0.08 + 0 * T)

    gy, gx = np.gradient(hgt)
    nx, ny = -gx * 6.0, gy * 6.0
    ln = np.sqrt(nx ** 2 + ny ** 2 + 1)
    nrm = np.stack([nx / ln, ny / ln, 1 / ln], -1) * 0.5 + 0.5
    files = {}
    for suffix, arr, nonc in (("Color", col, False), ("Normal", nrm, True), ("Roughness", rgh, True), ("Metalness", np.zeros((N, N)), True)):
        if arr.ndim == 2:
            arr = np.stack([arr] * 3, -1)
        rgba = np.flipud(np.concatenate([np.clip(arr, 0, 1), np.ones((N, N, 1))], -1))
        nm = f"{NAME}_{suffix}"
        img = bpy.data.images.get(nm) or bpy.data.images.new(nm, N, N, alpha=False)
        img.pixels.foreach_set(rgba.astype(np.float32).ravel())
        path = os.path.join(ROOT, nm + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        try:
            img.save()
        except RuntimeError:
            img.save_render(path)
        if nonc:
            img.colorspace_settings.name = "Non-Color"
        files[suffix] = img
    return files


def make_material(name, files, emit=0.0):
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    mat.use_backface_culling = True
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
    if emit > 0:  # เฉพาะภาพตัวอย่างกลางคืน (FBX ไม่พก emission ไป Roblox)
        nt.links.new(tc.outputs[0], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    nt.nodes.active = tc
    return mat


# ================================================================ 5. รวมเป็น object + rig
def realize(part, mat, coll):
    me = bpy.data.meshes.new(part.name)
    me.from_pydata([tuple(v) for v in part.co], [], part.f)
    uvl = me.uv_layers.new(name="UVMap")
    uvl.data.foreach_set("uv", np.array([c for f in part.uv for uv in f for c in uv], dtype=np.float32))
    me.validate()
    me.update()
    me.materials.append(mat)
    me.shade_smooth()
    ob = bpy.data.objects.new(part.name, me)
    coll.objects.link(ob)
    groups = {}
    for vi, w in enumerate(part.w):
        for bn, val in norm4(w).items():
            if bn not in groups:
                groups[bn] = ob.vertex_groups.new(name=bn)
            groups[bn].add([vi], val, "REPLACE")
    return ob


def eval_tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def build_rig(coll, objs):
    ad = bpy.data.armatures.new("KrasueRig")
    arm = bpy.data.objects.new("KrasueRig", ad)
    coll.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.view_layer.objects:
        o.select_set(o is arm)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, hd, tl, parent in BONES:
        b = ad.edit_bones.new(name)
        b.head, b.tail = Vector(hd), Vector(tl)
        b.align_roll(Vector(FWD))
        if parent:
            b.parent = ad.edit_bones[parent]
            b.use_connect = (Vector(SEG[parent][1]) - Vector(hd)).length < 1e-5
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in objs:
        md = o.modifiers.new("Armature", "ARMATURE")
        md.object = arm
        o.parent = arm
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


# ================================================================ 6. ท่า
CLIPS = {}  # ชื่อ -> จำนวนเฟรม


def set_action(arm, name):
    act = bpy.data.actions.get(name) or bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    try:
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
    except AttributeError:
        pass
    return act


def keyer(arm):
    X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

    def key(bn, frame, rx=0.0, ry=0.0, rz=0.0, loc=(0, 0, 0)):
        """rx/ry/rz = องศารอบแกนโลก X (+ = ห้อยแกว่งไปหลัง / หัวก้ม), Y (แกว่งข้าง), Z (หันซ้ายขวา); loc = เลื่อนตามแกนโลก (ม.)"""
        pb = arm.pose.bones[bn]
        Ri = pb.bone.matrix_local.to_3x3().inverted()
        q = Quaternion(Ri @ Z, math.radians(rz)) @ Quaternion(Ri @ Y, math.radians(ry)) @ Quaternion(Ri @ X, math.radians(rx))
        pb.rotation_quaternion = q
        pb.location = Ri @ Vector(loc)
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
    return key


def bone_dir(bn):
    h, t = SEG[bn]
    return (t - h).normalized()


def make_anims(arm):
    key = keyer(arm)
    names = [b[0] for b in BONES]
    hair = [n for n in names if n.startswith("Hair")]

    # ---- Float: ลอยขึ้นลงช้าๆ หัวโยก ผมกับไส้แกว่งตามแบบหน่วง (วนซ้ำ 60 เฟรม = 2 วินาที)
    set_action(arm, "Float")
    P = 60
    w = 2 * math.pi / P
    for f in range(0, P + 1, 2):
        roll = 2.5 * math.sin(2 * w * f)
        key("Head", 1 + f, rx=3 * math.sin(w * f - 0.6), ry=roll, rz=4 * math.sin(w * f + 1.0),
            loc=(0.004 * math.sin(w * f + 0.7), 0, 0.018 * math.sin(w * f)))
        for hn in hair:
            lvl = int(hn[-1])
            sg = 1 if "_L" in hn else -1 if "_R" in hn else 0
            key(hn, 1 + f, rx=(4 if lvl == 1 else 6) * math.sin(w * f - 1.4 - 0.6 * (lvl - 1)),
                ry=-0.6 * roll + 2.5 * sg * math.sin(w * f - 0.9 - 0.5 * lvl))
        key("Windpipe", 1 + f, rx=4 * math.sin(w * f - 1.0), ry=3 * math.sin(w * f - 0.5))
        ph = f % 30
        beat = math.exp(-((ph - 3) ** 2) / 3) + 0.6 * math.exp(-((ph - 8) ** 2) / 3)
        key("Heart", 1 + f, rx=5 * beat, loc=(0, -0.004 * beat, 0))
        for k in range(1, 8):
            A = 2 + 1.2 * k
            key(f"Gut{k}", 1 + f, rx=A * math.sin(w * f - 1.2 - 0.5 * k), ry=0.7 * A * math.sin(w * f + 0.8 - 0.55 * k))
    CLIPS["Float"] = P + 1

    # ---- Lunge: ถอยตั้งท่า -> พุ่งหัวไปหน้า ~2 studs ผมสะบัดไปหลัง ไส้ลากตามและยืดออก -> กลับที่เดิม
    set_action(arm, "Lunge")
    for f, loc, rx in ((1, (0, 0, 0), 0), (9, (0, 0.07, 0.03), -16), (15, (0, -0.56, -0.05), 22), (23, (0, -0.52, -0.04), 14), (41, (0, 0, 0), 0)):
        key("Head", f, rx=rx, loc=loc)
    for f, a1, a2 in ((1, 0, 0), (9, -12, -14), (15, 40, 30), (23, 22, 28), (31, -6, -10), (41, 0, 0)):
        for hn in hair:
            key(hn, f, rx=a1 if hn.endswith("1") else a2)
    for f, a in ((1, 0), (9, -10), (15, 18), (23, 24), (31, -8), (41, 0)):
        key("Windpipe", f, rx=a)
    for f, a in ((1, 0), (15, 8), (23, 12), (31, -5), (41, 0)):
        key("Heart", f, rx=a)
    for f, a in ((1, 0), (9, -8), (15, 16), (23, 26), (31, -10), (41, 0)):
        key("Gut1", f, rx=a)
    for k in range(2, 8):
        d = bone_dir(f"Gut{k}")
        for f, a, st in ((1, 0, 0), (9, -6, 0), (15, 10 + 2 * k, 0.008), (23, 12 + 3 * k, 0.010), (31, -8 - k, 0.002), (37, 3, 0), (41, 0, 0)):
            key(f"Gut{k}", f, rx=a, loc=tuple(d * st))
    CLIPS["Lunge"] = 41

    # ---- Sniff: ก้มหน้าลงดม สูดถี่ๆ ผมตกไปหน้า อวัยวะยังห้อยตรง
    set_action(arm, "Sniff")
    for f, a, loc in ((1, 0, (0, 0, 0)), (14, 26, (0, -0.06, -0.05)), (18, 29, None), (20, 25, None), (22, 30, None), (24, 26, None),
                      (26, 31, None), (28, 26, None), (36, 26, None), (49, 0, (0, 0, 0))):
        loc = loc or (0, -0.06, -0.05)
        key("Head", f, rx=a, loc=loc)
        for hn in hair:
            key(hn, f, rx=-(0.55 if hn.endswith("1") else 0.25) * a)
        key("Windpipe", f, rx=-0.7 * a)
        key("Gut1", f, rx=-0.15 * a)
    CLIPS["Sniff"] = 49

    # ---- HairWhip: สะบัดหน้าซ้ายขวาแรงๆ ผมเหวี่ยงตามช้ากว่าหัว
    set_action(arm, "HairWhip")
    for f, a in ((1, 0), (7, -22), (13, 34), (20, -8), (31, 0)):
        key("Head", f, rz=a)
        key("Windpipe", f, rz=-0.4 * a)
    for f, a in ((1, 0), (7, 14), (13, -26), (19, 12), (26, -4), (31, 0)):
        for hn in hair:
            if hn.endswith("1"):
                key(hn, f, ry=a)
    for f, a in ((1, 0), (9, 18), (15, -32), (21, 16), (28, -5), (31, 0)):
        for hn in hair:
            if hn.endswith("2"):
                key(hn, f, ry=a)
    for f, a in ((1, 0), (10, 8), (17, -12), (25, 5), (31, 0)):
        key("Gut1", f, ry=a)
    CLIPS["HairWhip"] = 31


def export_clip(arm, objs, clip, path):
    set_action(arm, clip)
    scn = bpy.context.scene
    scn.frame_start, scn.frame_end = 1, CLIPS[clip]
    scn.render.fps = FPS
    for o in bpy.context.view_layer.objects:
        o.select_set(o in objs or o is arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=False, object_types={"MESH", "ARMATURE"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=False,
                             add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
                             bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
                             bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0)


def export_anim_json(arm, path):
    out = {"fps": FPS, "space": "Blender pose-bone local (matrix_basis): quaternion wxyz + location m",
           "bones": {b[0]: {"head": list(b[1]), "tail": list(b[2]), "parent": b[3]} for b in BONES}, "clips": {}}
    for clip, nf in CLIPS.items():
        set_action(arm, clip)
        keys = {b[0]: [] for b in BONES}
        for f in range(1, nf + 1):
            bpy.context.scene.frame_set(f)
            for pb in arm.pose.bones:
                q, l = pb.rotation_quaternion, pb.location
                keys[pb.name].append([round(v, 5) for v in (q.w, q.x, q.y, q.z, l.x, l.y, l.z)])
        out["clips"][clip] = {"frames": nf, "loop": clip == "Float", "keys": keys}
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, separators=(",", ":"))


# ================================================================ 7. ภาพตัวอย่าง
def world_bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9, 1e9, 1e9))
    mx = -mn
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
        ev.to_mesh_clear()
    return mn, mx


def cam_at(objs, d, scale=1.12):
    mn, mx = world_bbox(objs)
    c = (mn + mx) / 2
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        bpy.context.scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(mx - mn) * scale
    cam.data.clip_end = 20
    cam.location = c + Vector(d).normalized() * 3.0
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def workbench(res=900):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.display.shading.show_cavity = True
    scn.display.shading.show_shadows = False
    scn.render.resolution_x = scn.render.resolution_y = res
    scn.render.film_transparent = False
    if not scn.world:
        scn.world = bpy.data.worlds.new("PrevWorld")
    scn.world.color = (0.32, 0.32, 0.34)


def night_render(objs, path):
    """ภาพกลางคืน (EEVEE): ไส้/ตาเรืองแสง แสงจันทร์อ่อน ไฟแดงจากอวัยวะส่องหน้าจากด้านล่าง"""
    scn = bpy.context.scene
    try:
        scn.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    w = bpy.data.worlds.new("NightWorld")
    scn.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.006, 0.008, 0.016, 1)
    lights = []
    for nm, typ, loc, energy, color in (("Moon", "AREA", (-0.6, -1.4, 1.2), 25, (0.55, 0.65, 1.0)),
                                        ("GutGlow", "POINT", (0.0, -0.13, -0.42), 6, (1.0, 0.22, 0.12)),
                                        ("Rim", "AREA", (0.9, 1.2, 0.6), 12, (0.5, 0.6, 1.0))):
        ld = bpy.data.lights.new(nm, typ)
        ld.energy = energy
        ld.color = color
        if typ == "AREA":
            ld.size = 1.0
        lo = bpy.data.objects.new(nm, ld)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, -0.25)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(lo)
        lights.append(lo)
    try:
        scn.eevee.taa_render_samples = 48
    except AttributeError:
        pass
    cam_at(objs, (-0.55, -1.25, 0.2), scale=1.1)
    render(path)
    for lo in lights:
        bpy.data.objects.remove(lo)


# ================================================================ main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(PREV, exist_ok=True)
    coll = bpy.data.collections.new(NAME)
    bpy.context.scene.collection.children.link(coll)

    log("build meshes")
    head = build_head()
    eyes, eye_c = build_eyes()
    hair = build_hair()
    organs = build_organs()
    G = rescale([head, eyes, hair, organs], organs)
    log(f"  organs x{ORG_S} around neck stump, whole model x{G:.3f} -> {TARGET_H / K:.1f} studs tall")
    log("paint textures")
    files = paint_all()
    mat = make_material(NAME + "_Mat", files)
    mat_eye = make_material(NAME + "_EyesMat", files)
    mat_org = make_material(NAME + "_OrgansMat", files)
    objs = [realize(head, mat, coll), realize(hair, mat, coll), realize(eyes, mat_eye, coll), realize(organs, mat_org, coll)]
    for o in objs:
        t = eval_tris(o)
        mx = max((len(v.groups) for v in o.data.vertices), default=0)
        log(f"  {o.name}: {t} tris, {len(o.data.vertices)} verts, max influences {mx}, groups {[g.name for g in o.vertex_groups]}")
        if t > 20000:
            log(f"  !!! {o.name} เกิน 20,000 tris")
    mn, mx = world_bbox(objs)
    sz = mx - mn
    log(f"  bbox m min=({mn.x:.3f},{mn.y:.3f},{mn.z:.3f}) max=({mx.x:.3f},{mx.y:.3f},{mx.z:.3f})")
    log(f"  size studs (Roblox X,Y,Z) = {sz.x / K:.2f} x {sz.z / K:.2f} x {sz.y / K:.2f}")
    log(f"  eye centres (Blender m): {[tuple(round(c_ * G, 4) for c_ in c) for c in eye_c]}")

    arm = build_rig(coll, objs)
    log(f"  rig KrasueRig: {len(BONES)} bones {[b[0] for b in BONES]}")
    make_anims(arm)
    log(f"  clips {CLIPS} @ {FPS} fps")

    export_clip(arm, objs, "Float", os.path.join(ROOT, NAME + ".fbx"))
    for clip in ("Lunge", "Sniff", "HairWhip"):
        export_clip(arm, objs, clip, os.path.join(ROOT, f"{NAME}_{clip}.fbx"))
    export_anim_json(arm, os.path.join(ROOT, NAME + "_Anims.json"))
    log("  exported FBX + json")

    # ภาพตัวอย่าง: ท่าพัก (ไม่มี action) หน้า ข้าง 3/4 + ท่า Lunge + กลางคืน
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    workbench()
    for nm, d in (("Krasue", (-0.75, -1.25, 0.45)), ("Krasue_front", (0, -1, 0.06)), ("Krasue_side", (1, 0, 0.05))):
        cam_at(objs, d)
        render(os.path.join(PREV, nm + ".png"))
    cam_at(objs, (0, -1, 0.0), scale=1.0)
    cam = bpy.context.scene.camera
    cam.data.ortho_scale = 0.32 * G
    cam.location = Vector((0, -3.0, -0.01))
    render(os.path.join(PREV, "Krasue_face.png"))
    set_action(arm, "Lunge")
    bpy.context.scene.frame_set(15)
    bpy.context.view_layer.update()
    cam_at(objs, (1, -0.35, 0.12))
    render(os.path.join(PREV, "Krasue_lunge.png"))
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    try:
        mat_org.node_tree.links.new(next(n for n in mat_org.node_tree.nodes if n.type == "TEX_IMAGE" and n.image == files["Color"]).outputs[0],
                                    next(n for n in mat_org.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Emission Color"])
        next(n for n in mat_org.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Emission Strength"].default_value = 1.2
        mat_eye.node_tree.links.new(next(n for n in mat_eye.node_tree.nodes if n.type == "TEX_IMAGE" and n.image == files["Color"]).outputs[0],
                                    next(n for n in mat_eye.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Emission Color"])
        next(n for n in mat_eye.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Emission Strength"].default_value = 3.0
        night_render(objs, os.path.join(PREV, "Krasue_night.png"))
        log("  night preview ok")
    except Exception:
        log("  night preview failed\n" + traceback.format_exc())
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "krasue.blend"))
    log("saved krasue.blend")


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "krasue_build.log")
try:
    main()
    LOG.append("DONE")
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
    open(OUT + ".done", "w").write("x")
