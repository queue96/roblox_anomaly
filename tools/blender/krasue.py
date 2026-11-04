# กระสือ (Krasue) — หัวผู้หญิงลอย ผมยาวดำ หน้าซีด ตาแดง ปากเลือด เขี้ยว + หลอดลม ปอด หัวใจ ไส้ห้อย — Blender headless
# GORE = False (ค่าตั้งต้น ด้านล่าง): แบบปลอดภัยสำหรับ Roblox ไม่มีเลือด อวัยวะสีเทาม่วงหม่น ตอคอดำปิด (True = แบบเดิม)
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\krasue.py -Out C:\tmp\krasue.txt
# ผลลัพธ์ (assets/models/):
#   Krasue.fbx           mesh 4 ชิ้น + rig KrasueRig + ท่า Float (วนซ้ำ)
#   Krasue_Lunge.fbx / Krasue_Sniff.fbx / Krasue_HairWhip.fbx   mesh + rig ชุดเดียวกัน ท่าละไฟล์ (ไว้ import ท่าใน Studio)
#   Krasue_Color/_Normal/_Roughness/_Metalness.png  texture 1024 ชุดเดียวใช้ทุกชิ้น
#   Krasue_Anims.json    ค่าท่าทุกเฟรม (quaternion + location ของแต่ละกระดูก ใน local space ของ Blender)
#   krasue.blend, previews/Krasue*.png
#   KRASUE_FACES=1 (env) = สร้างสีหน้าผี ghost / ghost_cry ของ human_female ลง human_female/faces/ ด้วย
# ชิ้น mesh (origin เดียวกัน = กลางหัว):
#   Krasue         หัว + คอของ human_female (mesh + UV เดิม) ตอคอขาด เขี้ยว — ผิววาดด้วย build_skin.paint_head หน้า "krasue"
#                  (ผีซีด เบ้าตาคล้ำ น้ำตาเลือด ปากอ้า) + เลือดรอบปากไหลลงคางถึงคอ
#   Krasue_Hair    หนังหัว + ปอยผมแยกเส้น 43 ปอย (Head/Build ของ build_hair) ยาวประบ่า แหวกกลาง (krasue_hair, HAIR_HEM, HAIR_LINE)
#   Krasue_Eyes    เลนส์ตาแดงก่ำ 2 ข้างแปะบนตาที่วาดไว้ (แยกไว้ให้เกมตั้ง Neon / เรืองแสงได้)
#   Krasue_Organs  หลอดลม เส้นเลือด ปอด หัวใจ ก้อนไส้ ลำไส้ใหญ่ ไส้ห้อย — material แยก (Krasue_OrgansMat) ให้เกมทำเรืองแสง
# หน่วยเมตร (1 stud = 0.28 m) สูงรวม ~3 studs · หน้าหันไป -Y ใน Blender (= -Z/LookVector ใน Studio)
import bpy, bmesh, math, os, sys, json, random, traceback
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")
PREV = os.path.join(ROOT, "previews")
NAME = "Krasue"
K = 0.28   # เมตรต่อ stud
N = 1024   # ขนาด texture
MG = 2     # ขอบกันสีเลอะ (px) ของแต่ละช่องใน atlas
FPS = 30
# GORE = False: Roblox-safe Krasue (moderation flagged blood): no blood round the mouth or running down to the neck,
# black tears, fangs without blood, a closed dark (charred) neck stump, and the organs dull grey-purple / brown and
# matte instead of raw red meat (they stay a separate material, so the in-game glow still works). The red eyes stay.
# build_skin.GORE follows this. True rebuilds the original bloody look.
GORE = False
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
    # ครึ่งบน (แถว 0-511) = หัว + คอ ใช้ UV ทรงกระบอกของ human model ตรงๆ (v 0.505-0.995) วาดด้วย build_skin.paint_head
    "lung": (0, 512, 256, 256),
    "heart": (256, 512, 256, 256),
    "hair": (512, 512, 256, 256),   # ผม (UV ทรงกระบอกรอบหัว)
    "eye": (768, 512, 256, 256),
    "gut": (0, 768, 256, 256),      # ลำไส้เล็ก
    "trachea": (256, 768, 128, 128),
    "flesh": (384, 768, 128, 128),  # เนื้อตอคอขาด
    "vessel": (256, 896, 128, 128),
    "colon": (384, 896, 128, 128),  # ลำไส้ใหญ่
    "fang": (512, 768, 128, 128),
}


def ruv(reg, s, t):
    """(s, t) ในช่อง reg -> UV ของ atlas (t = 1 คือขอบบนของช่อง)"""
    x0, y0, w, h = REG[reg]
    return ((x0 + MG + s * (w - 2 * MG)) / N, 1.0 - (y0 + MG + (1.0 - t) * (h - 2 * MG)) / N)


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
    # ผมเป็นเปลือกครอบหัว: เหนือคางติดหัว 100% (ไม่งั้นแกว่งแล้วหนังหัวโผล่/ผมทะลุหน้า) แกว่งได้แค่ช่วงที่ห้อยใต้คาง
    wh = float(sm(HAIR_P - 0.05, HAIR_P + 0.03, p.z))
    u = float(sm(HAIR_P - 0.02, 0.25 * HAIR_P + 0.75 * HAIR_ZB, p.z))   # ช่วงล่างเป็นของกระดูกข้อ 2 (ผสมยาวๆ ไม่หักเป็นมุม)
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


# ================================================================ 1. หัว คอ ผม ตา เขี้ยว — จาก human_female
# ใช้หัว+คอของ human_female (mesh + UV + ผิววาดด้วย build_skin หน้า "krasue") และผมผีของ build_hair (_ghost ยาวประบ่า)
# แล้วย่อขยายให้หัวสูงเท่าหัวที่ปั้นเองเดิม (HEAD_H) อวัยวะ กระดูก และท่าเดิมจึงใช้ค่าเดิมได้
HUMAN_DIR = os.path.join(ROOT, "human_female")
HUMAN_BASE = os.path.join(ROOT, "human_base")
HEAD_H = 0.244                              # ความสูงกะโหลก (หน่วยของสคริปต์นี้ก่อน rescale)
STUMP_OLD = Vector((0.0, 0.012, -0.183))    # กลางตอคอของหัวเดิม ที่อวัยวะวางไว้ใต้
HAIR_HEM = [(0, -0.20), (40, -0.21), (90, -0.23), (180, -0.26)]   # ปลายผม (x ขนาดหัว จากกลางหัว): ยาวประบ่า (ghost_long ยาวถึงอก ผู้ใช้ว่ายาวเกิน)
HAIR_LINE = [(0, 42), (10, 34), (25, 22), (45, 12), (70, 6), (100, 6), (180, -20)]   # แนวผม (องศา: มุมรอบหัว -> มุมเงย) ลงมาคลุมมุมหน้าผาก
NOSE_W = 0.8                                # ความกว้างจมูกเทียบเดิม
NOSE_FLAT = 0.6                             # กดจมูกของ human ที่ยื่นเกินผิวหน้าลงเท่านี้ (0 = เดิม)
ORG_D = Vector()                            # เลื่อนอวัยวะ + กระดูกอวัยวะไปใต้ตอคอใหม่ (ตั้งใน build_human)
HAIR_P = -0.10                              # จุดหมุนกระดูกผม (ระดับคาง หน่วยก่อน rescale)
HAIR_AMP = 0.5                              # ตัวคูณมุมแกว่งผมในทุกท่า (ผมสั้นประบ่า แกว่งน้อยกว่าผมยาวเดิม)
HAIR_ZB = -0.40                             # ปลายผมล่างสุด (ตั้งใน build_human) ใช้แบ่งน้ำหนักกระดูกผมข้อ 1/2


def load_ns(path):
    """exec สคริปต์ของ human model ใน namespace แยก ให้อ่าน/เขียนไฟล์ใน assets/models ของ checkout นี้"""
    ns = {"__name__": "krasue_lib", "__file__": path}
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), ns)
    ns["M"] = ROOT
    ns["GORE"] = GORE
    return ns


CHAR, FACE = "female", "krasue"           # ตัวคนที่ใช้หัว + สีหน้าใน build_skin.FACES


# ---- ส่วนหน้าผีที่ใช้ซ้ำได้ (ผีตัวอื่นที่ใช้หัว human: เรียกด้วย char/face ของตัวเอง; sk = namespace ของ build_skin)
def paint_ghost_head(sk, meta, char=CHAR, face=FACE, red_eyes=True, blood=None, neck_soak=None):
    """ผิวหัว (ครึ่งบนของ atlas, แถวล่างขึ้นบนแบบ build_skin): paint_head(face) + ตาแดง + เลือดรอบปากไหลลงคางถึงคอ
    (neck_soak = คอล่างชุ่มเลือดทั้งรอบ สำหรับหัวขาด) คืน (สี, ความสูง, roughness, normal)
    พิกัด Canvas: X = มุมรอบหัว * RF, Y = ความสูงตามแกนหัว (ม. ของ human)"""
    blood = GORE if blood is None else blood
    neck_soak = GORE if neck_soak is None else neck_soak
    hc, hh, hr, (ppx, ppy) = sk["paint_head"](meta, char, True, face)
    f = sk["FACES"][face]
    rows, cols = np.arange(N // 2, N), np.arange(N)
    v, u = (rows + 0.5) / N, (cols + 0.5) / N
    X, Y = np.meshgrid(sk["unwarp"]((u - 0.5) * 2 * math.pi) * meta["RF"],
                       meta["h0"] + (v - sk["HV0"]) / (sk["HV1"] - sk["HV0"]) * (meta["h1"] - meta["h0"]))
    cv, mx, sst = sk["Canvas"](X, Y), sk["mix"], sk["sstep"]
    s, ey, my, cb, h0 = meta["s"], meta["eye_h"], meta["mouth_h"], meta["chin_h"], meta["h0"]
    es = s * sk["LOOK"][char]["eye"]
    ex, a = 0.032 * s, 0.0155 * es
    bu, bl = 0.0062 * es * f["open"], 0.0044 * es * f["open"]
    mw, gap = 0.022 * s, f["mouth_open"] * 0.006 * s
    # ตาแดงก่ำ (ใต้เลนส์ตา ghost_eyes อีกชั้น เผื่อมุมที่เลนส์บัง)
    for sx in ((1, -1) if red_eyes else ()):
        eye = cv.ell(sx * ex, ey + (bu - bl) / 2, a, (bu + bl) / 2, 0.3)
        hc = mx(hc, (0.50, 0.04, 0.05), 0.85 * eye)
        hc = mx(hc, (0.95, 0.16, 0.08), cv.ell(sx * ex, ey + 0.0006 * s, 0.0042 * s, 0.0042 * s, 0.3) * eye)
    # เลือด: รอบปาก มุมปาก ทางไหลจากริมฝีปากล่างลงคางถึงคอ คอล่างชุ่มเลือดทั้งรอบ
    bd = 0.8 * cv.ell(0, my - 0.003 * s, mw * 1.25, 0.013 * s, 1.0)
    for sx in (1, -1):
        bd = np.maximum(bd, cv.ell(sx * mw, my - 0.002 * s, 0.006 * s, 0.009 * s, 0.6))
    for x0, w, ye in ((-0.017, 0.0030, h0 + 0.03 * s), (-0.008, 0.0045, h0 - 0.01), (0.002, 0.0035, cb - 0.012 * s),
                      (0.010, 0.0050, h0 - 0.01), (0.019, 0.0028, cb - 0.035 * s), (-0.024, 0.0025, cb + 0.004 * s)):
        y0 = my - gap / 2 - 0.004 * s
        pts = [(x0 * s + 0.0016 * s * math.sin(i * 1.1 + x0 * 300), y0 + (ye - y0) * i / 13, 1.0 - 0.3 * i / 13) for i in range(14)]
        bd = np.maximum(bd, cv.seg(pts, w * s))
        bd = np.maximum(bd, 0.9 * cv.ell(pts[-1][0], ye, w * s * 1.4, w * s * 2.2, 0.5))
    bd = np.maximum(bd, 0.85 * cv.ell(0, cb + 0.004 * s, 0.024 * s, 0.013 * s, 0.9))              # คางเปื้อนเป็นแผ่น
    bd = np.maximum(bd, 0.55 * cv.ell(0, cb - 0.045 * s, 0.028 * s, 0.050 * s, 1.0))              # ไหลเป็นแผ่นลงคอหน้า
    if neck_soak:
        bd = np.maximum(bd, sst(h0 + 0.055 * s, h0 + 0.012 * s, Y + 0.020 * s * (sk["fbm"](X * 45, Y * 45, oct=3, seed=81) - 0.5)))
    bd = np.clip(bd, 0, 1) * (1.0 if blood else 0.0)
    bd = bd * ~((np.abs(X) < mw) & (np.abs(Y - my) < gap / 2))                                   # ในปากยังดำ เห็นฟัน
    hc = mx(hc, (0.30, 0.0, 0.02), 0.92 * bd)
    hc = mx(hc, (0.45, 0.02, 0.03), 0.5 * bd * sk["fbm"](X * 300, Y * 300, oct=2, seed=82))       # เลือดสดเป็นจุด
    hr = hr * (1 - bd) + 0.12 * bd
    hh = hh + 0.00025 * bd
    return hc, hh, hr, sk["normal_from_height"](hh, ppx, ppy)


def face_caster(fr, verts, faces, meta):
    """surf(X, Y) -> (จุด, normal ออกนอก) บนผิวหัว ตรงพิกัด Canvas ของ build_skin (ยิงจากแกนหัวออกไป) — พิกัด world ของ human"""
    bvh = BVHTree.FromPolygons(verts, faces)

    def surf(x, y):
        az = x / meta["RF"]
        dn = fr.F * math.cos(az) + fr.L * math.sin(az)
        loc, nrm, _, _ = bvh.ray_cast(fr.C + fr.U * y, dn, 1.0)
        nrm = nrm.normalized()
        return loc, (nrm if nrm.dot(dn) > 0 else -nrm)
    return surf


def ghost_eyes(part, surf, fr, T, KS, sk, meta, char=CHAR, face=FACE, reg="eye", wfn=None):
    """เลนส์ตาทรงรีแบนโค้งตามหน้า 2 ข้าง ทับตาที่ paint_head วาด (ขนาดตาม LOOK[char]["eye"] และ FACES[face]["open"])
    T = world ของ human -> พิกัดของโมเดล, KS = ตัวคูณขนาด; คืนจุดกลางตา"""
    s, f = meta["s"], sk["FACES"][face]
    es = s * sk["LOOK"][char]["eye"]
    a, bu, bl = 0.0155 * es, 0.0062 * es * f.get("open", 1.0), 0.0044 * es * f.get("open", 1.0)
    th, out = 0.0028, []
    for sg in (1, -1):
        loc, nn = surf(sg * 0.032 * s, meta["eye_h"] + (bu - bl) / 2)
        xa = fr.U.cross(nn).normalized()
        rot = Matrix((xa, -nn, xa.cross(-nn).normalized())).transposed()
        c = T(loc + nn * (th * 0.45))
        out.append(c)
        bend = meta["RF"] * KS
        part.ellip(c, (a * 1.02 * KS, th * KS, (bu + bl) / 2 * 1.05 * KS), reg, wfn or W("Head"), nu=16, nv=10, rot=rot,
                   shape=lambda lo, dd, b=bend: lo + Vector((0, lo.x ** 2 / (2 * b), 0)))   # โค้งตามหน้า
    return out


def ghost_fangs(part, surf, fr, T, KS, sk, meta, face=FACE, reg="fang", wfn=None, upper=(0.55, 0.0115, 0.0030), lower=(0.42, 0.0065, 0.0022)):
    """เขี้ยวบน 2 ซี่ยาว ล่าง 2 ซี่สั้น ที่ขอบปากอ้าของ paint_head (FACES[face]["mouth_open"])
    upper/lower = (ตำแหน่ง x เทียบครึ่งความกว้างปาก, ยาว ม., รัศมีโคน ม.) ของ human; lower=None = ไม่มีเขี้ยวล่าง"""
    s = meta["s"]
    mw, gap = 0.022 * s, sk["FACES"][face].get("mouth_open", 0.0) * 0.006 * s
    for sg in (1, -1):
        for spec, yb, dirn in ((upper, meta["mouth_h"] + gap / 2 + 0.0008, -1), (lower, meta["mouth_h"] - gap / 2 - 0.0008, 1)):
            if not spec:
                continue
            xf, ln, r0 = spec
            loc, nn = surf(sg * xf * mw, yb)
            b0 = loc - nn * 0.0006
            tip = b0 + fr.U * (dirn * ln) + nn * 0.0012
            pts = [T(b0.lerp(tip, k / 4) + nn * 0.0012 * math.sin(math.pi * k / 4)) for k in range(5)]
            part.tube(pts, [r0 * KS * (1 - 0.92 * k / 4) for k in range(5)], reg, wfn or W("Head"), n=6)


def krasue_hair(b, hr):
    """ผมกระสือ ยาวประบ่า แหวกกลาง สร้างด้วย Head/Build ของ build_hair:
    1) หนังหัวเป็น shell บางๆ แค่ถึงแนวผม (แนวผมโค้งลงคลุมมุมหน้าผาก บางแนบหนังหัวตรงแนวผม ร่องแสกกลาง)
    2) ปอยผมแบนเรียวแยกเป็นเส้นๆ HAIR_LOCKS ปอย: รากใกล้กระหม่อม/แสก ไล่ตามหนังหัวลงมาแล้วตกตรงถึงประบ่า
       ยาวไม่เท่ากัน ปลายเรียวแหลม มีช่องระหว่างปอย (ไม่เป็นผ้าคลุมทึบแบบ shell ผืนเดียว)"""
    R, key, sym = math.radians, hr["key"], hr["sym"]
    h, s = b.h, b.h.s
    line = sym([(az, R(el)) for az, el in HAIR_LINE])
    base = sym(HAIR_HEM)

    def deg(th):
        return abs(math.degrees(math.atan2(math.sin(th), math.cos(th))))

    def thick(th, ph):
        t = 0.006 + 0.006 * key(ph, [(R(0), 0.4), (R(60), 1.0)])
        edge = key(ph - line(th), [(0.0, 0.25), (R(14), 1.0)]) if deg(th) < 70 else 1.0      # บางที่แนวผมหน้า
        part = 1 - 0.75 * math.exp(-(deg(th) / 5) ** 2) * key(ph, [(R(30), 0), (R(48), 1)])  # ร่องแสกกลาง
        return t * edge * part

    b.shell(hr["GHOST_AZ"], True, hr["POLE"], line, thick, rows=10, tuck=0.004)
    rnd = random.Random(23)
    U = h.U

    def ribbon(pts, wid):
        """ปอยแบน: หน้าตัดรีกว้างตามแนวรอบหัว บางตามแนวรัศมี ปลายสุดเป็นจุดเดียว (เรียวแหลม)"""
        before = set(b.bm.faces)
        rings = []
        for p, w in zip(pts, wid):
            rad = p - h.C
            rad.z = 0
            rad = rad.normalized() if rad.length > 1e-6 else h.F
            side = U.cross(rad).normalized()
            if w < 1e-5:
                rings.append([b.bm.verts.new(p)])
                continue
            rings.append([b.bm.verts.new(p + side * math.cos(a) * w + rad * math.sin(a) * w * 0.32)
                          for a in (2 * math.pi * k / 6 for k in range(6))])
        for A, B in zip(rings, rings[1:]):
            if len(B) == 1:
                for k in range(6):
                    b.bm.faces.new((A[k], A[(k + 1) % 6], B[0]))
            else:
                for k in range(6):
                    b.bm.faces.new((A[k], A[(k + 1) % 6], B[(k + 1) % 6], B[k]))
        b.bm.faces.new(rings[0])
        b._tag(before, 0)

    def lock(th0, th1, ph0, off, wd, extra):
        """รากที่ (th0, ph0) ไล่ตามหนังหัวลงถึงข้างหัว (ph 0) พร้อมเลื่อนมุมไป th1 แล้วตกตรงถึงประบ่า"""
        pts = []
        for k in range(8):
            f = k / 7
            pts.append(h.on(th0 + (th1 - th0) * float(sm(0, 1, f)), ph0 * (1 - f), off * (0.05 + 0.95 * float(sm(0, 0.5, f)))))   # รากจมในหนังหัว
        top = pts[-1]
        hz = h.horiz(th1)
        zb = h.C.z + (base(th1) + extra) * s
        nd = 9
        for k in range(1, nd + 1):
            f = k / nd
            p = Vector((top.x, top.y, top.z + (zb - top.z) * f)) + hz * (0.012 * s * f) \
                + U.cross(hz) * (0.004 * s * math.sin(f * 4 + th1 * 7))
            pts.append(h.push(p, 0.008 * s, hz))
        n = len(pts)
        wid = [wd * s * ((0.55 + 0.45 * float(sm(0, 0.3, i / (n - 1)))) * (1 - float(sm(0.65, 1.0, i / (n - 1))))) for i in range(n)]
        wid[-1] = 0.0
        ribbon(pts, wid)

    nl = 0
    for sg in (1, -1):
        # ปอยหน้า: รากข้างแสก ตกคลุมขมับ/ข้างแก้ม (ไม่บังหน้า)
        for th0, th1, ph0, off in ((8, 46, 74, 0.013), (12, 54, 70, 0.017), (16, 62, 66, 0.013), (20, 70, 62, 0.019)):
            lock(R(sg * th0), R(sg * th1), R(ph0), off, 0.030, rnd.uniform(-0.02, 0.03))
            nl += 1
        # ข้าง + หลัง 2 ชั้น (ชั้นนอกเหลื่อมครึ่งช่อง ปิดช่องของชั้นใน)
        for layer, (off, wd) in enumerate(((0.012, 0.034), (0.020, 0.030))):
            for a in range(78 + 6 * layer, 181, 12):
                if sg < 0 and a >= 180:
                    continue
                th = R(sg * (a + rnd.uniform(-3, 3)))
                lock(th, th, R(78 + rnd.uniform(-6, 4)), off, wd * rnd.uniform(0.85, 1.15), rnd.uniform(-0.025, 0.035))   # ปลายยาวไม่เท่ากัน (ไม่ยาวจนกวาดโดนปอดตอน HairWhip)
                nl += 1
    log(f"  hair: scalp cap + {nl} locks")


def build_human():
    global ORG_D, HAIR_ZB, BONES, SEG
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HUMAN_DIR, "human_female.blend"))
    sk = load_ns(os.path.join(HUMAN_BASE, "build_skin.py"))
    hr = load_ns(os.path.join(HUMAN_BASE, "build_hair.py"))
    body, rig = bpy.data.objects["Body"], bpy.data.objects["HumanRig"]
    d = json.load(open(os.path.join(HUMAN_DIR, "human_female_uv.json"), encoding="utf-8"))
    uv = np.array(d["uv"]).reshape(-1, 2)          # UV ชุดเดียวกับ texture ของ human_female (ไม่ unwrap ใหม่)
    meta = {k: np.float64(v) if isinstance(v, float) else v for k, v in d.items() if k != "uv"}   # เหมือน withered_char
    sk["set_uv"](body.data, uv)
    if os.environ.get("KRASUE_FACES"):              # สีหน้าผี ghost / ghost_cry ของตัวหญิง (ร่างเต็ม ก่อนตัดหัว)
        log("  female faces ->", sk["make_face_textures"]("female", uv, meta, body, faces=["ghost", "ghost_cry"]))
    fr = sk["Frame"](body, rig)
    C, KS = fr.C.copy(), HEAD_H / (0.235 * fr.s)
    T = lambda p: (Vector(p) - C) * KS
    log(f"  human_female head: centre {tuple(round(c, 3) for c in C)}, scale x{KS:.3f}")
    # เหลือหัว + คอ (เกณฑ์เดียวกับ unwrap: น้ำหนัก head + neck >= 0.5) ก่อนสร้างผม ผมจะตกตรงไม่พาดบ่า
    me = body.data
    hn = fr.w[:, fr.gi["head"]] + fr.w[:, fr.gi["neck"]]
    keep = {p.index for p in me.polygons if all(hn[v] >= 0.5 for v in p.vertices)
            and all(uv[li][1] >= sk["HV0"] - 1e-3 for li in p.loop_indices)}
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    # หู (ชิ้นแยกข้างหัว) โผล่ทะลุผมที่ตกตรง ผมคลุมหูอยู่แล้วจึงตัดทิ้ง เหลือจมูก
    ears = set()
    for isl in sk["islands"](me):
        cx_ = sum((body.matrix_world @ me.vertices[v].co for fi in isl for v in me.polygons[fi].vertices), Vector()).x / sum(len(me.polygons[fi].vertices) for fi in isl)
        if abs(cx_ - C.x) > 0.04 * fr.s:
            ears |= set(isl)
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in ears], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    log(f"  removed ears: {len(ears)} faces")
    # จมูก (ชิ้นแยกของ human) โด่งเป็นกรวยแหลม ดูหลุดจากหน้าตอนมองใกล้: กดส่วนที่ยื่นเกินผิวหน้าลงครึ่งหนึ่ง
    isl = sorted(sk["islands"](me), key=len)
    nose = {v for fi in (f for g in isl[:-1] for f in g) for v in me.polygons[fi].vertices}
    mwi = body.matrix_world.inverted()
    for vi in nose:
        p = body.matrix_world @ me.vertices[vi].co
        fw = (p - C).dot(fr.F)
        if fw > meta["RF"]:
            p = p - fr.F * (fw - meta["RF"]) * NOSE_FLAT
        p = p - fr.L * ((p - C).dot(fr.L) * (1 - NOSE_W))                        # แคบลง ไม่เป็นสามเหลี่ยมกว้าง
        me.vertices[vi].co = mwi @ p
    me.update()
    log(f"  nose: {len(nose)} verts pressed x{1 - NOSE_FLAT:.2f}")
    for o in list(bpy.data.objects):
        if o.name.startswith("Cloth_"):
            bpy.data.objects.remove(o, do_unlink=True)
    # ใต้ตอคอไม่มีตัวให้ผมพักแล้ว build_hair จะดันผมออกเป็นกระโจม: ใส่เสาทรงกระบอกต่อคอลงไปชั่วคราวให้ผมตกตรงรอบเสา
    nf0 = len(me.polygons)
    zlo = min(v.co.z for v in me.vertices)
    ring = [v.co for v in me.vertices if v.co.z < zlo + 0.02]
    cx = sum((p for p in ring), Vector()) / len(ring)
    rad = sum(math.hypot(p.x - cx.x, p.y - cx.y) for p in ring) / len(ring)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=rad * 0.9, radius2=rad * 0.9, depth=0.8,
                          matrix=Matrix.Translation((cx.x, cx.y, zlo + 0.01 - 0.4)))
    bm.to_mesh(me)
    bm.free()
    me.update()
    hr["STYLES"]["krasue"] = (lambda b: krasue_hair(b, hr), ["HairBlack"])
    hair_ob = hr["add_hair"]("female", ["krasue"])["krasue"]
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index >= nf0], context="FACES")
    bm.to_mesh(me)
    bm.free()
    me.update()
    bpy.context.view_layer.update()

    # ---- หัว: mesh + UV ของ human (ผูก Head 100%)
    wv = [body.matrix_world @ v.co for v in me.vertices]
    head = Part("Krasue")
    for p in wv:
        head.vert(T(p), {"Head": 1.0})
    lay = me.uv_layers.active.data
    for p in me.polygons:
        head.face(list(p.vertices), [tuple(lay[li].uv) for li in p.loop_indices])
    # ตอคอขาด: ขอบล่างสุดของคอ ขาดรุ่งริ่ง แล้วปิดด้วยเนื้อแดงเว้าเข้า
    cnt = {}
    for p in me.polygons:
        for ek in p.edge_keys:
            cnt[ek] = cnt.get(ek, 0) + 1
    nb = {}
    for (i, j), c in cnt.items():
        if c == 1:
            nb.setdefault(i, []).append(j)
            nb.setdefault(j, []).append(i)
    loops, seen = [], set()
    for v0 in nb:
        if v0 in seen:
            continue
        lp, prev, cur = [v0], None, v0
        seen.add(v0)
        while True:
            nxt = [x for x in nb[cur] if x != prev and x not in seen]
            if not nxt:
                break
            prev, cur = cur, nxt[0]
            lp.append(cur)
            seen.add(cur)
        loops.append(lp)
    rim = min(loops, key=lambda lp: sum(head.co[i].z for i in lp) / len(lp))
    ctr = sum((head.co[i] for i in rim), Vector()) / len(rim)
    rng = random.Random(4)
    jag = [rng.random() for _ in rim]
    for k, i in enumerate(rim):
        head.co[i] = head.co[i] - Vector((0, 0, 0.010 * (jag[k] + 0.5 * jag[k - 1]) / 1.5))
    ORG_D = ctr - STUMP_OLD
    f0 = len(head.f)
    n = len(rim)
    angs = [math.atan2(head.co[i].x - ctr.x, -(head.co[i].y - ctr.y)) for i in rim]
    inner = [head.vert(Vector((ctr.x + (head.co[i].x - ctr.x) * 0.78, ctr.y + (head.co[i].y - ctr.y) * 0.78, ctr.z + 0.006)), {"Head": 1.0})
             for i in rim]
    cc = head.vert(ctr + Vector((0, 0.004, 0.012)), {"Head": 1.0})
    fuv = lambda rr, an: ruv("flesh", 0.5 + rr * math.cos(an), 0.5 + rr * math.sin(an))
    for k in range(n):
        k1 = (k + 1) % n
        head.face([rim[k], rim[k1], inner[k1], inner[k]], [fuv(0.48, angs[k]), fuv(0.48, angs[k1]), fuv(0.32, angs[k1]), fuv(0.32, angs[k])])
        head.face([inner[k], inner[k1], cc], [fuv(0.32, angs[k]), fuv(0.32, angs[k1]), fuv(0.0, 0.0)])
    head.orient(f0, ctr + Vector((0, 0, 0.05)))
    log(f"  head+neck {len(me.polygons)} faces, stump rim {n} verts, centre {tuple(round(c, 3) for c in ctr)}")

    # ---- ตา + เขี้ยว: ยิงจากแกนหัวออกไปหาผิวตรงพิกัดที่ build_skin วาดตา/ปากไว้
    surf = face_caster(fr, wv, [list(p.vertices) for p in me.polygons], meta)
    eyes = Part("Krasue_Eyes")
    eye_c = ghost_eyes(eyes, surf, fr, T, KS, sk, meta)
    ghost_fangs(head, surf, fr, T, KS, sk, meta)

    # ---- ผม: UV ทรงกระบอกรอบหัวลงช่อง hair, น้ำหนัก Head + Hair_L/R/B (w_hair)
    hp = [T(hair_ob.matrix_world @ v.co) for v in hair_ob.data.vertices]
    HAIR_ZB = min(p.z for p in hp)
    zt = max(p.z for p in hp)
    hair = Part("Krasue_Hair")
    for p in hp:
        hair.vert(p, w_hair(p))
    for poly in hair_ob.data.polygons:
        vs = list(poly.vertices)
        cen = sum((hp[i] for i in vs), Vector()) / len(vs)
        ac = math.atan2(cen.x, -cen.y)
        uvs = []
        for i in vs:
            az = math.atan2(hp[i].x, -hp[i].y)
            az = ac + math.atan2(math.sin(az - ac), math.cos(az - ac))     # ตะเข็บอยู่หลังหัว
            uvs.append(ruv("hair", min(max(0.5 + az / (2 * math.pi), 0.0), 1.0), (hp[i].z - HAIR_ZB) / (zt - HAIR_ZB)))
        hair.face(vs, uvs)

    # ---- กระดูก: Head จากกระดูก head ของ HumanRig, ผมจากขนาดผมจริง
    hb = rig.data.bones["head"]
    mid = [p for p in hp if abs(p.z - HAIR_P) < 0.03]
    sx, by = max(abs(p.x) for p in mid), max(p.y for p in mid)
    nb_ = {"Head": (T(rig.matrix_world @ hb.head_local), T(rig.matrix_world @ hb.tail_local))}
    for nm, sg in (("L", 1), ("R", -1)):
        nb_[f"Hair_{nm}1"] = (Vector((sg * sx, 0, HAIR_P)), Vector((sg * sx * 1.03, 0.005, (HAIR_P + HAIR_ZB) / 2)))
        nb_[f"Hair_{nm}2"] = (nb_[f"Hair_{nm}1"][1], Vector((sg * sx * 1.06, 0.01, HAIR_ZB)))
    nb_["Hair_B1"] = (Vector((0, by, HAIR_P)), Vector((0, by * 1.03, (HAIR_P + HAIR_ZB) / 2)))
    nb_["Hair_B2"] = (nb_["Hair_B1"][1], Vector((0, by * 1.06, HAIR_ZB)))
    BONES = [(nm, tuple(nb_[nm][0]), tuple(nb_[nm][1]), par) if nm in nb_ else (nm, hd, tl, par) for nm, hd, tl, par in BONES]
    SEG = {b[0]: (Vector(b[1]), Vector(b[2])) for b in BONES}
    log(f"  hair (ghost ประบ่า): {len(hair_ob.data.polygons)} faces, bottom z {HAIR_ZB:.3f}, organs moved {tuple(round(c, 3) for c in ORG_D)}")
    return head, eyes, hair, eye_c, paint_ghost_head(sk, meta)


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
    org = lambda p: ORG_C + (Vector(p) - ORG_C) * ORG_S + ORG_D
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


def paint_hair(reg, seed):
    S, T, n = region_st(reg)
    lo1, lo2 = vnoise(n, 5, seed), vnoise(n, 7, seed + 1)
    strand = 0.5 * (0.5 + 0.5 * np.sin(S * 2 * math.pi * 19 + 2.0 * lo1)) + 0.5 * (0.5 + 0.5 * np.sin(S * 2 * math.pi * 47 + 3.0 * lo2))
    col = np.array([0.018, 0.018, 0.022]) + np.array([0.05, 0.05, 0.06]) * (strand ** 2)[..., None]
    hl = np.exp(-((T - 0.7 - 0.05 * np.sin(S * 12)) / 0.06) ** 2) * strand
    col = col + np.array([0.06, 0.06, 0.075]) * hl[..., None]
    return col, strand, 0.38 + 0.2 * (1 - strand)


def dull(c):
    """GORE False: organ colour desaturated and darkened towards a dead grey-purple / brown (not raw meat)"""
    c = np.asarray(c, float)
    if GORE:
        return c
    g = c @ np.array((0.2126, 0.7152, 0.0722)) if c.ndim else float(c)
    out = (np.asarray(g)[..., None] * 1.7) * np.array((0.95, 0.86, 0.96)) * 0.88 + c * 0.12
    return np.clip(out, 0.0, 0.48)


def paint_organ(reg, base, dark, seed, rough=0.18):
    if not GORE:
        base, dark, rough = dull(base), dull(dark), rough + 0.4     # dry and matte, not wet
    S, T, n = region_st(reg)
    n1, n2, n3 = vnoise(n, 6, seed), vnoise(n, 28, seed + 1), vnoise(n, 70, seed + 2)
    col = np.array(base) * (0.75 + 0.35 * n2 + 0.15 * n1)[..., None]
    veins = ((np.abs(vnoise(n, 10, seed + 3) - 0.5) < 0.018) | (np.abs(vnoise(n, 22, seed + 4) - 0.5) < 0.01)).astype(float)
    col = mix(col, 0.75 * veins, dark)
    spots = sm(0.72, 0.85, n3)
    col = mix(col, 0.5 * spots, dark)
    return S, T, n, n1, col, 0.4 * n2 + 0.3 * n3 + 0.4 * veins, rough + 0.12 * n2


def paint_all(head):
    """head = (สี, ความสูง, roughness, normal) ของครึ่งบน จาก paint_ghost_head (แถวล่างขึ้นบน)"""
    col = np.zeros((N, N, 3))
    hgt = np.zeros((N, N))
    rgh = np.full((N, N), 0.6)

    def put(reg, c, h, r):
        x0, y0, w, hh = REG[reg]
        col[y0:y0 + hh, x0:x0 + w] = np.clip(c, 0, 1)
        hgt[y0:y0 + hh, x0:x0 + w] = h
        rgh[y0:y0 + hh, x0:x0 + w] = np.clip(r, 0.04, 1)

    hc, _, hr, hn = head
    col[:N // 2] = np.clip(np.flipud(hc), 0, 1)
    rgh[:N // 2] = np.clip(np.flipud(hr), 0.04, 1)
    put("hair", *paint_hair("hair", 41))
    _, _, _, _, c, h, r = paint_organ("lung", (0.55, 0.04, 0.06), (0.25, 0.0, 0.03), 51)
    put("lung", c, h, r)
    S, T, n, n1, c, h, r = paint_organ("heart", (0.42, 0.02, 0.04), (0.22, 0.0, 0.05), 61)
    fat = sm(0.7, 0.85, T + 0.15 * (n1 - 0.5))
    c = mix(c, 0.85 * fat, dull((0.82, 0.62, 0.30)))
    cor = (np.abs(np.sin(S * 2 * math.pi * 3 + 1.5 * np.sin(T * 7))) < 0.07) * (T < 0.8)
    c = mix(c, 0.8 * cor, dull((0.22, 0.0, 0.06)))
    put("heart", c, h + 0.4 * cor, r)
    S, T, n, n1, c, h, r = paint_organ("gut", (0.58, 0.10, 0.11), (0.35, 0.03, 0.10), 71, 0.2)
    folds = 0.5 + 0.5 * np.sin(T * 2 * math.pi * 10)
    c = c * (0.82 + 0.25 * folds)[..., None]
    mes = (np.abs(S - 0.25 - 0.02 * np.sin(T * 40)) < 0.015).astype(float)
    c = mix(c, mes, dull((0.40, 0.03, 0.12)))
    put("gut", c, h + 0.4 * folds + 0.3 * mes, r)
    S, T, n, n1, c, h, r = paint_organ("colon", (0.50, 0.12, 0.14), (0.30, 0.04, 0.08), 81, 0.25)
    band = sm(0.0, 0.06, 0.04 - np.abs(S - 0.5))
    c = mix(c, 0.6 * band, dull((0.75, 0.55, 0.50)))
    put("colon", c, h + 0.3 * band, r)
    S, T, n, n1, c, h, r = paint_organ("trachea", (0.55, 0.08, 0.10), (0.30, 0.0, 0.04), 91, 0.3)
    cart = sm(-0.2, 0.3, np.sin(T * 2 * math.pi * 4))
    c = mix(c, 0.8 * cart, dull((0.78, 0.48, 0.46)))
    put("trachea", c, h + cart, r)
    S, T, n, n1, c, h, r = paint_organ("flesh", (0.48, 0.03, 0.05), (0.12, 0.0, 0.02), 101)
    c = mix(c, sm(0.8, 0.9, vnoise(n, 30, 105)), (0.80, 0.50, 0.45))
    if not GORE:   # closed stump: charred black-grey with flaky ash, matte (no red flesh, no bone)
        c = np.array([0.07, 0.065, 0.065]) * (0.75 + 0.6 * n1)[..., None]
        c = mix(c, 0.55 * sm(0.62, 0.78, vnoise(n, 30, 105)), (0.27, 0.26, 0.25))
        r = 0.85 + 0 * r
    put("flesh", c, h, r)
    _, _, _, _, c, h, r = paint_organ("vessel", (0.34, 0.02, 0.07), (0.18, 0.0, 0.05), 111, 0.2)
    put("vessel", c, h, r)
    S, T, n = region_st("fang")
    c = np.array([0.86, 0.82, 0.68]) * (0.8 + 0.2 * (1 - T))[..., None]
    c = mix(c, 0.75 * sm(0.55, 0.9, T), (0.40, 0.0, 0.02) if GORE else (0.34, 0.26, 0.14))   # safe: old stain, not blood
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
    nrm[:N // 2] = np.flipud(hn)                  # หัว: normal map ของ build_skin (ความหนาแน่น texel จริงของหัว)
    nrm[N // 2 - 1:N // 2 + 1] = (0.5, 0.5, 1.0)
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

    def hkey(hn, f, rx=0.0, ry=0.0):
        key(hn, f, rx=rx * HAIR_AMP, ry=ry * HAIR_AMP)

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
            hkey(hn, 1 + f, rx=(4 if lvl == 1 else 6) * math.sin(w * f - 1.4 - 0.6 * (lvl - 1)),
                ry=-0.6 * roll + 2.5 * sg * math.sin(w * f - 0.9 - 0.5 * lvl))
        key("Windpipe", 1 + f, rx=4 * math.sin(w * f - 1.0), ry=3 * math.sin(w * f - 0.5))
        ph = f % 30
        beat = math.exp(-((ph - 3) ** 2) / 3) + 0.6 * math.exp(-((ph - 8) ** 2) / 3)
        key("Heart", 1 + f, rx=1.9 * math.sin(w * f - 1.7) - 2.5 * beat, loc=(0, -0.004 * beat, 0))   # แกว่งไปกับก้อนไส้ (Gut1)     # ปลายหัวใจเต้นไปหน้า ไม่ตีเข้าก้อนไส้ข้างหลัง
        for k in range(1, 8):
            A = 1.2 + 0.7 * k             # ไส้แกว่งน้อยลง ไม่พับทะลุกันเอง/ทะลุปอด
            key(f"Gut{k}", 1 + f, rx=A * math.sin(w * f - 1.2 - 0.5 * k), ry=0.7 * A * math.sin(w * f + 0.8 - 0.55 * k))
    CLIPS["Float"] = P + 1

    # ---- Lunge: ถอยตั้งท่า -> พุ่งหัวไปหน้า ~2 studs ผมสะบัดไปหลัง ไส้ลากตามและยืดออก -> กลับที่เดิม
    set_action(arm, "Lunge")
    for f, loc, rx in ((1, (0, 0, 0), 0), (9, (0, 0.07, 0.03), -16), (15, (0, -0.56, -0.05), 22), (23, (0, -0.52, -0.04), 14), (41, (0, 0, 0), 0)):
        key("Head", f, rx=rx, loc=loc)
    for f, a1, a2 in ((1, 0, 0), (9, -12, -14), (15, 40, 30), (23, 22, 28), (31, -6, -10), (41, 0, 0)):
        for hn in hair:
            hkey(hn, f, rx=a1 if hn.endswith("1") else a2)
    for f, a in ((1, 0), (9, -10), (15, 18), (23, 24), (31, -8), (41, 0)):
        key("Windpipe", f, rx=a)
    for f in (1, 41):   # หัวใจ + ก้อนไส้ไม่หมุนแยกจากหลอดลม (หมุนคนละจุดหมุนแล้วหัวใจจมเข้าก้อนไส้) ทั้งก้อนแกว่งตาม Windpipe
        key("Heart", f)
        key("Gut1", f)
    for k in range(2, 8):
        d = bone_dir(f"Gut{k}")
        for f, a, st in ((1, 0, 0), (9, -4, 0), (15, 6 + 1.2 * k, 0.008), (23, 7 + 1.8 * k, 0.010), (31, -5 - 0.6 * k, 0.002), (37, 2, 0), (41, 0, 0)):
            key(f"Gut{k}", f, rx=a, loc=tuple(d * st))
    CLIPS["Lunge"] = 41

    # ---- Sniff: ก้มหน้าลงดม สูดถี่ๆ ผมตกไปหน้า อวัยวะยังห้อยตรง
    set_action(arm, "Sniff")
    for f, a, loc in ((1, 0, (0, 0, 0)), (14, 26, (0, -0.06, -0.05)), (18, 29, None), (20, 25, None), (22, 30, None), (24, 26, None),
                      (26, 31, None), (28, 26, None), (36, 26, None), (49, 0, (0, 0, 0))):
        loc = loc or (0, -0.06, -0.05)
        key("Head", f, rx=a, loc=loc)
        for hn in hair:
            hkey(hn, f, rx=-(0.55 if hn.endswith("1") else 0.25) * a)
        key("Windpipe", f, rx=-0.7 * a)
        key("Gut1", f, rx=-0.15 * a)
        key("Heart", f, rx=-0.15 * a)
    CLIPS["Sniff"] = 49

    # ---- HairWhip: สะบัดหน้าซ้ายขวาแรงๆ ผมเหวี่ยงตามช้ากว่าหัว
    set_action(arm, "HairWhip")
    for f, a in ((1, 0), (7, -22), (13, 34), (20, -8), (31, 0)):
        key("Head", f, rz=a)
        key("Windpipe", f, rz=-0.15 * a)    # อวัยวะหมุนตามหัวเกือบทั้งหมด ผมไม่กวาดเข้าปอด
    for f, a in ((1, 0), (7, 14), (13, -26), (19, 12), (26, -4), (31, 0)):
        for hn in hair:
            if hn.endswith("1"):
                hkey(hn, f, ry=0.6 * a)
    for f, a in ((1, 0), (9, 18), (15, -32), (21, 16), (28, -5), (31, 0)):
        for hn in hair:
            if hn.endswith("2"):
                hkey(hn, f, ry=0.6 * a)
    for f, a in ((1, 0), (10, 4), (17, -5), (25, 2), (31, 0)):   # ลำไส้ใหญ่ไม่เหวี่ยงเข้าปอด
        key("Gut1", f, ry=a)
        key("Heart", f, ry=a)
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


def day_render(path):
    """EEVEE แสงกลางวัน (เหมือน build_skin.preview / ภาพหน้าของผีตัวอื่น) ใช้ normal map + PBR ใกล้เคียงในเกม"""
    scn = bpy.context.scene
    try:
        scn.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scn.render.engine = "BLENDER_EEVEE_NEXT"
    vt, old_world = scn.view_settings.view_transform, scn.world
    scn.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.get("DayWorld") or bpy.data.worlds.new("DayWorld")
    scn.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.25, 0.26, 0.28, 1)
    bg.inputs[1].default_value = 0.6
    lights = []
    for nm, rot, energy in (("Key", (math.radians(55), 0, math.radians(-35)), 3.5), ("Fill", (math.radians(70), 0, math.radians(60)), 1.0)):
        lo = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
        lo.data.energy = energy
        lo.rotation_euler = rot
        scn.collection.objects.link(lo)
        lights.append(lo)
    render(path)
    for lo in lights:
        bpy.data.objects.remove(lo)
    scn.view_settings.view_transform = vt
    scn.world = old_world


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
    log("head + hair from human_female")
    head, eyes, hair, eye_c, head_tex = build_human()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(PREV, exist_ok=True)
    coll = bpy.data.collections.new(NAME)
    bpy.context.scene.collection.children.link(coll)

    log("build organs")
    organs = build_organs()
    G = rescale([head, eyes, hair, organs], organs)
    log(f"  organs x{ORG_S} around neck stump, whole model x{G:.3f} -> {TARGET_H / K:.1f} studs tall")
    log("paint textures")
    files = paint_all(head_tex)
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
        (day_render if nm == "Krasue_front" else render)(os.path.join(PREV, nm + ".png"))   # หน้าตรง: EEVEE เหมือนภาพหน้าใกล้
        workbench()
    cam_at(objs, (0, -1, 0.0), scale=1.0)
    cam = bpy.context.scene.camera
    cam.data.ortho_scale = 0.32 * G
    cam.location = Vector((0, -3.0, -0.01))
    day_render(os.path.join(PREV, "Krasue_face.png"))   # หน้าใกล้: EEVEE แสงกลางวันแบบ build_skin.preview (Workbench+cavity ทำจมูกแยกชิ้นเป็นเหลี่ยมคม)
    workbench()
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
