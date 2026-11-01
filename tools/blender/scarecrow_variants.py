# หุ่นไล่กา 3 แบบให้เลือก (สมจริง + หลอนกว่าเดิม) render แสงกลางคืนเทียบกัน
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/scarecrow_variants.py [-- A|B|C]
#   ไม่ใส่ตัวเลือก = render ทั้ง 3 แบบเป็นภาพเทียบ assets/models/previews/ScarecrowVariants.png (ไม่ export)
#   ใส่ A/B/C = export แบบนั้นเป็น assets/models/ScarecrowThai.fbx + พื้นผิว (ชื่อชิ้นเดิม: ScarecrowThai, _EyeL_Neon, _EyeR_Neon)
# A ผีผมยาว: หัวกระสอบคอเอียง ผมดำยาวปิดหน้า เสื้อขาวมอซอยาวถึงแข้ง คราบเลือดแห้ง นิ้วกิ่งไม้
# B หัวหม้อดิน: หม้อดินร้าววาดหน้าด้วยปูนขาวตาโปน ผ้าแดงผูกคอ งอบ ม่อฮ่อม อีกาเกาะแขน
# C ร่างผอมสูง: เสื้อคลุมยาวถึงเข่า แขนยาวนิ้วกรงเล็บ ตากระดุมข้างเดียวอีกข้างเป็นรูขาด งอบกดต่ำ อีกาบนคาน
import bpy, math, os, sys
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "scarecrow.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main_scarecrow()")], "scarecrow.py", "exec"))

MODELS = ROOT
VAR_DIR = os.path.join(os.environ.get("TEMP", MODELS), "scarecrow_variants")
os.makedirs(VAR_DIR, exist_ok=True)

PAL.update({
    "sc_white": dict(c=(188, 180, 160), r=0.95, m=0, p="sc_indigo_white"),
    "sc_hair": dict(c=(16, 14, 13), r=0.55, m=0, p="sc_hair"),
    "sc_blood": dict(c=(62, 16, 12), r=0.6, m=0, p="sc_burlap"),
    "sc_clay": dict(c=(132, 74, 48), r=0.85, m=0, p="sc_clay"),
    "sc_lime": dict(c=(214, 208, 192), r=0.9, m=0, p="sc_burlap"),
    "sc_redcloth": dict(c=(128, 22, 20), r=0.9, m=0, p="sc_indigo_white"),
    "sc_coat": dict(c=(58, 46, 36), r=0.95, m=0, p="sc_indigo_white"),
    "sc_twig": dict(c=(70, 54, 40), r=0.85, m=0, p="sc_bamboo"),
    "sc_crow": dict(c=(18, 18, 20), r=0.5, m=0, p="sc_hair"),
    "sc_beak": dict(c=(40, 36, 30), r=0.4, m=0, p="plain"),
    "sc_hole": dict(c=(6, 5, 5), r=1.0, m=0, p="plain"),
})
KEYS[:] = list(PAL.keys())

_paint_sc = paint


def paint(key, n, seed):
    p = PAL[key]["p"]
    if p not in ("sc_indigo_white", "sc_hair", "sc_clay"):
        return _paint_sc(key, n, seed)
    spec = PAL[key]
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    n1 = vnoise(n, 5, seed)
    n2 = vnoise(n, 18, seed + 7)
    n3 = vnoise(n, 48, seed + 13)
    rough = np.full((n, n), spec["r"]) + 0.05 * (n2 - 0.5)
    metal = np.zeros((n, n))
    if p == "sc_indigo_white":
        # ผ้าเก่าเปื่อย: คราบเหลือง/คราบดิน/รอยไหม้แดดเป็นปื้น + เนื้อผ้าทอ
        weave = np.abs(np.sin(xx * 70 * math.pi)) * np.abs(np.sin(yy * 70 * math.pi))
        col = base * (0.85 + 0.2 * weave + 0.12 * (n3 - 0.5))[..., None]
        grime = np.clip((n1 - 0.45) * 2, 0, 1)
        col = col * (1 - 0.45 * grime[..., None]) + np.array([0.3, 0.22, 0.12]) * (0.3 * grime)[..., None]
        drip = np.clip((np.abs(np.sin(xx * 9 * math.pi + n2 * 3)) - 0.85) * 6, 0, 1) * np.clip((n2 - 0.4) * 3, 0, 1)
        col = col * (1 - 0.4 * drip[..., None])  # คราบน้ำไหลเป็นทางแนวดิ่ง
        h = 0.3 * weave + 0.2 * grime
    elif p == "sc_hair":
        strand = np.abs(np.sin((xx * 90 + n2 * 4) * math.pi))
        col = base * (0.6 + 0.8 * strand)[..., None]
        h = 0.5 * strand
        rough = rough - 0.15 * strand
    else:  # sc_clay หม้อดินเผา: ด่างไฟ คราบเขม่า รอยร้าว
        soot = np.clip((n1 - 0.5) * 2.5, 0, 1)
        col = base * (0.8 + 0.3 * n2)[..., None]
        col = col * (1 - 0.6 * soot[..., None])
        crack = (np.abs(np.sin((xx * 3 + n2 * 1.2) * math.pi * 4)) < 0.03).astype(float)
        col = col * (1 - 0.7 * crack[..., None])
        h = 0.3 * n3 - 0.6 * crack
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), metal


# ---------------------------------------------------------------- ตัวช่วย
def lumpy(b, start, amt, freq=1.3, seed=0):
    """ทำให้ผิวผ้ายับ/ย้วยไม่เรียบ: เลื่อนจุดตั้งแต่ index start ด้วย noise เชิงพื้นที่ (ย้วยลงตามแรงโน้มถ่วงมากกว่า)"""
    r = np.random.default_rng(seed)
    ph = r.uniform(0, 6.28, 6)
    for i in range(start, len(b.v)):
        p = b.v[i]
        nx = math.sin(p.x * freq * 2.1 + ph[0]) * math.cos(p.z * freq * 1.7 + ph[1])
        ny = math.sin(p.y * freq * 2.3 + ph[2]) * math.cos(p.x * freq * 1.3 + ph[3])
        nz = math.sin(p.z * freq * 2.9 + ph[4]) * math.cos(p.y * freq * 1.9 + ph[5])
        b.v[i] = p + Vector((nx * amt, ny * amt, -abs(nz) * amt * 1.4))


def draped_sleeve(b, sx, z_bar, x0, x1, r, key, hang):
    """แขนเสื้อพาดไม้คาน: ผ้าห้อยใต้ไม้ (ไม่ใช่ท่อกลมแข็ง) ปลายแขนขาดรุ่ยยาว"""
    start = len(b.v)
    pts = []
    for k in range(6):
        t = k / 5
        x = sx * (x0 + (x1 - x0) * t)
        pts.append((x, 0, z_bar - r * 0.55 - hang * math.sin(math.pi * t) * 0.6))
    b.tube(pts, [r * (1.0 - 0.15 * k / 5) for k in range(6)], key, n=10)
    lumpy(b, start, 0.06, 3.0, seed=int(sx * 7 + 9))
    tatter(b, lambda t, sx=sx: (sx * (x1 + 0.02), r * 0.9 * math.cos(2 * math.pi * t)), z_bar - r * 0.6, key, 8, 0.4, 1.1, outward=0.0)


def twig_hand(b, c, out, length, count=5, curl=0.35):
    """นิ้วกิ่งไม้ยื่นออกจากปลายแขน งอเป็นกรงเล็บ"""
    c, out = Vector(c), Vector(out).normalized()
    side = out.cross(Vector((0, 0, 1))).normalized()
    for i in range(count):
        a = (i - (count - 1) / 2) * 0.32
        d = (out * math.cos(a) + side * math.sin(a)).normalized()
        L = length * rng.uniform(0.75, 1.15)
        p1 = c + d * L * 0.5 - Vector((0, 0, 0.1))
        p2 = c + d * L * 0.9 - Vector((0, 0, L * curl))
        p3 = p2 + d * 0.12 - Vector((0, 0, 0.18)) - out * 0.05
        b.tube([tuple(c), tuple(p1), tuple(p2), tuple(p3)], [0.05, 0.04, 0.03, 0.012], "sc_twig", n=6, cap=True)


def crow(b, c, yaw, scale=1.0):
    """อีกาเกาะ (ตัว หัว จะงอยปาก หาง ขา)"""
    M = Matrix.Translation(c) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(scale, 4)
    with b.xf(M):
        b.ellipsoid((0, 0, 0.22), (0.15, 0.28, 0.17), "sc_crow", nu=10, nv=6)
        b.ellipsoid((0, -0.26, 0.38), (0.1, 0.11, 0.1), "sc_crow", nu=8, nv=5)
        b.cone((0, -0.34, 0.37), (0, -0.52, 0.34), 0.04, 0.0, "sc_beak", n=6)
        b.beam((0, 0.2, 0.22), (0, 0.55, 0.05), 0.2, 0.03, "sc_crow", side=(1, 0, 0))
        for sx in (-1, 1):
            b.beam((sx * 0.12, -0.05, 0.3), (sx * 0.16, 0.3, 0.12), 0.18, 0.025, "sc_crow", side=(0, 0, 1))
            b.tube([(sx * 0.05, -0.02, 0.08), (sx * 0.05, -0.04, -0.04)], 0.015, "sc_beak", n=4)


def burlap_head(b, c, r, tilt, key="sc_burlap"):
    with b.xf(Matrix.Translation(c) @ tilt):
        start = len(b.v)
        b.ellipsoid((0, 0, 0), r, key, nu=16, nv=10)
        lumpy(b, start, 0.05, 4.0, seed=3)
        b.ellipsoid((0.04, 0.02, r[2] * 0.95), (0.18, 0.16, 0.17), key, nu=10, nv=6)


# ---------------------------------------------------------------- A ผีผมยาว
def variant_A():
    P = "ScarecrowThai"
    body = B(P)
    body.bevel, body.sa = False, 60
    eyeL, eyeR = B(P + "_EyeL_Neon"), B(P + "_EyeR_Neon")
    ZB, ZH = 5.0, 6.05
    bamboo(body, (0, 0, 0), (0, 0, ZH - 0.4), 0.15, 4)
    bamboo(body, (-2.6, 0.02, ZB), (2.6, -0.02, ZB + 0.05), 0.11, 4)
    for k in range(4):
        body.torus((0, 0, ZB - 0.12 + k * 0.08), "z", 0.19, 0.03, "sc_rope", nu=12, nv=4)
    # เสื้อขาวยาวถึงแข้ง ทรงย้วยห้อย (lathe ไม่กลมเป๊ะ) ชายขาดรุ่ยยาว
    start = len(body.v)
    with body.xf(Matrix.Scale(0.72, 4, (0, 1, 0))):
        body.lathe(0, 0, [(0.42, 5.25), (0.78, 4.95), (0.8, 4.3), (0.72, 3.6), (0.8, 2.8), (0.95, 2.0), (1.05, 1.5)], 16, "sc_white")
    lumpy(body, start, 0.09, 2.2, seed=11)
    tatter(body, lambda t: (1.0 * math.cos(2 * math.pi * t), 0.72 * math.sin(2 * math.pi * t)), 1.55, "sc_white", 22, 0.3, 1.0)
    for sx in (-1, 1):
        draped_sleeve(body, sx, ZB, 0.55, 2.3, 0.38, "sc_white", 0.25)
        twig_hand(body, (sx * 2.3, 0, ZB - 0.5), (sx, 0, -0.9), 0.75)
    # คราบเลือดแห้งไหลจากคอลงอก
    for k in range(5):
        x = rng.uniform(-0.3, 0.3)
        body.beam((x, -0.6, 5.0), (x + rng.uniform(-0.05, 0.05), -0.6 + 0.02 * k, 5.0 - rng.uniform(0.6, 1.6)), rng.uniform(0.06, 0.16), 0.02, "sc_blood", side=(1, 0, 0))
    body.ellipsoid((0.05, -0.58, 4.85), (0.35, 0.03, 0.22), "sc_blood", nu=10, nv=5)
    # หัวกระสอบเอียงคอพับลงข้างหนึ่ง ผมยาวดำห้อยปิดหน้า เห็นตากระดุมข้างเดียวลอดผม
    tilt = Matrix.Rotation(math.radians(24), 4, "Y") @ Matrix.Rotation(math.radians(14), 4, "X")
    hc = Vector((0.18, -0.05, ZH))
    burlap_head(body, hc, (0.6, 0.56, 0.7), tilt)
    body.torus((0.05, 0, 5.45), "z", 0.3, 0.05, "sc_rope", nu=14, nv=4)
    for i in range(46):
        a = rng.uniform(-math.pi, math.pi)
        if -1.9 < a < -1.2 and rng.random() < 0.6:
            continue  # ช่องว่างในผมตรงตาข้างซ้าย
        root = hc + tilt @ Vector((0.5 * math.cos(a), 0.48 * math.sin(a), 0.45))
        L = rng.uniform(1.6, 3.0)
        drop = Vector((math.cos(a) * 0.25, math.sin(a) * 0.25 - 0.12, -L))
        mid = root + drop * 0.45 + Vector((rng.uniform(-0.1, 0.1), -0.1, 0))
        body.tube([tuple(root), tuple(mid), tuple(root + drop)], [0.045, 0.035, 0.008], "sc_hair", n=5)
    e = hc + tilt @ Vector((-0.24, -0.56, 0.05))
    eyeL.ellipsoid(tuple(e), (0.1, 0.045, 0.1), "sc_eye", nu=12, nv=6)
    e2 = hc + tilt @ Vector((0.22, -0.56, 0.02))
    eyeR.ellipsoid(tuple(e2), (0.09, 0.045, 0.09), "sc_eye", nu=12, nv=6)
    return P, [body, eyeL, eyeR]


# ---------------------------------------------------------------- B หัวหม้อดิน
def variant_B():
    P = "ScarecrowThai"
    body = B(P)
    body.bevel, body.sa = False, 60
    eyeL, eyeR = B(P + "_EyeL_Neon"), B(P + "_EyeR_Neon")
    ZB, ZH = 5.0, 6.05
    bamboo(body, (0, 0, 0), (0, 0, ZH - 0.2), 0.15, 4)
    bamboo(body, (-2.7, 0.02, ZB), (2.7, -0.02, ZB + 0.06), 0.11, 4)
    for k in range(4):
        body.torus((0, 0, ZB - 0.12 + k * 0.08), "z", 0.19, 0.03, "sc_rope", nu=12, nv=4)
    start = len(body.v)
    with body.xf(Matrix.Scale(0.66, 4, (0, 1, 0))):
        body.lathe(0, 0, [(0.4, 5.3), (0.8, 5.0), (0.84, 4.3), (0.74, 3.7), (0.8, 3.2)], 16, "sc_indigo")
    lumpy(body, start, 0.08, 2.5, seed=5)
    tatter(body, lambda t: (0.8 * math.cos(2 * math.pi * t), 0.53 * math.sin(2 * math.pi * t)), 3.25, "sc_indigo", 16, 0.35, 0.95)
    straw_tuft(body, (0, 0, 3.2), (0, 0, -1), 26, 0.7, 0.5, 0.1)
    with body.xf(Matrix.Translation((0, 0, 3.62)) @ Matrix.Scale(0.64, 4, (0, 1, 0))):
        body.torus((0, 0, 0), "z", 0.84, 0.11, "sc_plaid", nu=20, nv=5)
    for sx in (-1, 1):
        draped_sleeve(body, sx, ZB, 0.55, 2.4, 0.36, "sc_indigo", 0.2)
        straw_tuft(body, (sx * 2.45, 0, ZB - 0.25), (sx, 0, -0.6), 22, 0.6, 0.22, 0.7)
    # หม้อดินคว่ำเป็นหัว (ร้าว บิ่นขอบ) วาดหน้าด้วยปูนขาว: ตาโปนกลมโต ปากยิ้มกว้างฟันซี่ๆ
    tilt = Matrix.Rotation(math.radians(-8), 4, "Y") @ Matrix.Rotation(math.radians(6), 4, "X")
    hc = Vector((0, 0, ZH))
    with body.xf(Matrix.Translation(hc) @ tilt):
        body.lathe(0, 0, [(0.25, -0.62), (0.5, -0.5), (0.68, -0.15), (0.66, 0.2), (0.5, 0.5), (0.3, 0.62), (0.32, 0.72), (0.0, 0.73)], 18, "sc_clay")
        for ex in (-0.26, 0.26):
            body.ellipsoid((ex, -0.6, 0.12), (0.2, 0.04, 0.22), "sc_lime", nu=12, nv=6)
        for k in range(9):
            x = -0.36 + k * 0.09
            z = -0.22 - 0.08 * math.cos(x / 0.36 * math.pi / 2)
            body.beam((x, -0.66, z + 0.07), (x + 0.01, -0.66, z - 0.07), 0.05, 0.02, "sc_lime", side=(1, 0, 0))
        body.beam((-0.4, -0.65, -0.2), (0.4, -0.65, -0.2), 0.04, 0.02, "sc_lime", side=(0, 0, 1))
        body.beam((0.1, -0.62, 0.55), (0.28, -0.6, 0.1), 0.02, 0.03, "sc_hole", side=(1, 0, 0))  # รอยร้าวหม้อ
    for ex, sz in ((-0.26, 0.085), (0.26, 0.075)):
        e = hc + tilt @ Vector((ex + 0.03, -0.65, 0.1))
        (eyeL if ex < 0 else eyeR).ellipsoid(tuple(e), (sz, 0.04, sz), "sc_eye", nu=12, nv=6)
    # ผ้าแดง (ผ้ายันต์) ผูกคอ ชายผ้าปลิว
    body.torus((0, 0, 5.38), "z", 0.36, 0.08, "sc_redcloth", nu=14, nv=5)
    body.beam((0.2, -0.3, 5.35), (0.55, -0.45, 4.6), 0.22, 0.02, "sc_redcloth", side=(1, 0, 0))
    body.beam((0.3, -0.25, 5.35), (0.75, -0.3, 4.75), 0.18, 0.02, "sc_redcloth", side=(1, 0, 0))
    # งอบ
    hat = Matrix.Translation((0, 0, ZH + 0.62)) @ Matrix.Rotation(math.radians(-6), 4, "X")
    with body.xf(hat):
        body.lathe(0, 0, [(0.0, 0.62), (0.18, 0.52), (0.5, 0.28), (0.85, 0.08), (1.12, -0.04), (1.18, -0.08)], 24, "sc_ngob")
        body.lathe(0, 0, [(1.16, -0.1), (0.85, 0.04), (0.5, 0.24), (0.18, 0.46), (0.0, 0.56)], 24, "sc_ngob")
    crow(body, (1.75, 0.0, ZB + 0.08), math.radians(-70), 1.0)
    return P, [body, eyeL, eyeR]


# ---------------------------------------------------------------- C ร่างผอมสูง
def variant_C():
    P = "ScarecrowThai"
    body = B(P)
    body.bevel, body.sa = False, 60
    eyeL, eyeR = B(P + "_EyeL_Neon"), B(P + "_EyeR_Neon")
    ZB, ZH = 6.3, 7.45
    bamboo(body, (0, 0, 0), (0, 0, ZH - 0.4), 0.14, 5)
    bamboo(body, (-2.9, 0.02, ZB), (2.9, -0.02, ZB + 0.04), 0.1, 5)
    for k in range(4):
        body.torus((0, 0, ZB - 0.12 + k * 0.08), "z", 0.18, 0.03, "sc_rope", nu=12, nv=4)
    # เสื้อคลุมยาวผอม ไหล่ห่อ ชายยาวถึงเข่า ขาดเป็นริ้ว
    start = len(body.v)
    with body.xf(Matrix.Scale(0.62, 4, (0, 1, 0))):
        body.lathe(0, 0, [(0.35, 6.6), (0.66, 6.35), (0.6, 5.6), (0.5, 4.6), (0.55, 3.6), (0.7, 2.6), (0.82, 2.0)], 16, "sc_coat")
    lumpy(body, start, 0.08, 2.0, seed=21)
    tatter(body, lambda t: (0.82 * math.cos(2 * math.pi * t), 0.5 * math.sin(2 * math.pi * t)), 2.05, "sc_coat", 20, 0.4, 1.2)
    for sx in (-1, 1):
        draped_sleeve(body, sx, ZB, 0.5, 2.5, 0.32, "sc_coat", 0.15)
        twig_hand(body, (sx * 2.55, 0, ZB - 0.4), (sx, 0, -0.5), 1.25, count=5, curl=0.55)
    # เชือกพันคอเป็นบ่วง ห้อยปลาย
    body.torus((0, 0, 6.72), "z", 0.27, 0.05, "sc_rope", nu=14, nv=4)
    body.tube([(0.2, -0.2, 6.7), (0.3, -0.35, 6.2), (0.25, -0.38, 5.7)], 0.04, "sc_rope", n=5)
    # หัวกระสอบยาวรี ตากระดุมข้างเดียว อีกข้างเป็นรูขาดดำ ปากเย็บแนวตั้งยาว
    tilt = Matrix.Rotation(math.radians(-10), 4, "Y") @ Matrix.Rotation(math.radians(10), 4, "X")
    hc = Vector((0, 0, ZH))
    burlap_head(body, hc, (0.5, 0.5, 0.78), tilt)
    with body.xf(Matrix.Translation(hc) @ tilt):
        body.ellipsoid((0.2, -0.47, 0.12), (0.12, 0.03, 0.15), "sc_hole", nu=10, nv=5)
        for k in range(6):
            x = -0.2 + k * 0.08
            body.beam((x, -0.5, -0.12), (x, -0.5, -0.42), 0.025, 0.02, "sc_thread", side=(1, 0, 0))
        body.beam((-0.24, -0.5, -0.27), (0.24, -0.5, -0.27), 0.02, 0.02, "sc_thread", side=(0, 0, 1))
    e = hc + tilt @ Vector((-0.2, -0.5, 0.12))
    eyeL.ellipsoid(tuple(e), (0.1, 0.045, 0.1), "sc_eye", nu=12, nv=6)
    e2 = hc + tilt @ Vector((0.2, -0.46, 0.12))  # ตาขวาเป็นแค่ด้ายห้อยในรูขาด (เล็กมาก เรืองแดงลึกๆ ตอนเป็นผี)
    eyeR.ellipsoid(tuple(e2), (0.05, 0.03, 0.05), "sc_eye", nu=10, nv=5)
    # งอบกดต่ำปิดครึ่งหน้า
    hat = Matrix.Translation((0, 0, ZH + 0.38)) @ Matrix.Rotation(math.radians(-16), 4, "X")
    with body.xf(hat):
        body.lathe(0, 0, [(0.0, 0.66), (0.18, 0.56), (0.5, 0.3), (0.9, 0.08), (1.2, -0.06), (1.26, -0.1)], 24, "sc_ngob")
        body.lathe(0, 0, [(1.24, -0.12), (0.9, 0.04), (0.5, 0.26), (0.18, 0.5), (0.0, 0.6)], 24, "sc_ngob")
    crow(body, (-1.6, 0.0, ZB + 0.06), math.radians(60), 1.0)
    crow(body, (2.2, 0.05, ZB + 0.06), math.radians(-110), 0.85)
    return P, [body, eyeL, eyeR]


VARIANTS = {"A": variant_A, "B": variant_B, "C": variant_C}


# ---------------------------------------------------------------- ภาพกลางคืน (Cycles)
def night_render(objs, path):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 900
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
    w = bpy.data.worlds.new("Night")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.016, 0.026, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    for o in list(bpy.context.scene.objects):
        if o.type in ("LIGHT", "CAMERA") or o.name.startswith("Ground"):
            bpy.data.objects.remove(o)
    bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, 0))
    g = bpy.context.active_object
    g.name = "Ground"
    gm = bpy.data.materials.new("Mud")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.04, 0.03, 1)
    g.data.materials.append(gm)
    # ไฟส้มจากร้านไกลๆ ด้านหน้าซ้าย + แสงจันทร์ฟ้าหม่นด้านหลัง (rim)
    bpy.ops.object.light_add(type="POINT", location=(-1.2, -3.2, 1.3))
    k = bpy.context.active_object
    k.data.energy = 220
    k.data.color = (1.0, 0.72, 0.45)
    k.data.shadow_soft_size = 0.2
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(-60), 0, math.radians(200)))
    m = bpy.context.active_object
    m.data.energy = 0.6
    m.data.color = (0.55, 0.65, 0.9)
    frame_cam(objs, (0.25, -1.0, 0.12), lens=45, dist=1.0)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def build(letter):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prop, builders = VARIANTS[letter]()
    coll, objs = realize(prop, builders)
    return prop, objs


def main_variants():
    global ROOT
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if args:
        letter = args[0].upper()
        ROOT = MODELS
        prop, objs = build(letter)
        export(prop, objs)
        night_render(objs, os.path.join(PREV, "ScarecrowThai_night.png"))
        log("EXPORTED variant", letter)
        return
    ROOT = VAR_DIR  # ภาพพื้นผิวของตัวเลือกไม่ต้องลง assets
    tiles = []
    for letter in ("A", "B", "C"):
        prop, objs = build(letter)
        p = os.path.join(VAR_DIR, f"variant_{letter}.png")
        night_render(objs, p)
        im = bpy.data.images.load(p)
        w, h = im.size
        a = np.empty(w * h * 4, dtype=np.float32)
        im.pixels.foreach_get(a)
        tiles.append(a.reshape(h, w, 4))
        log("rendered", letter)
    sheet = np.concatenate([np.pad(t, ((0, 0), (6, 6), (0, 0)), constant_values=1.0) for t in tiles], axis=1)
    h, w, _ = sheet.shape
    out = bpy.data.images.new("ScarecrowVariants", w, h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = os.path.join(PREV, "ScarecrowVariants.png")
    out.file_format = "PNG"
    out.save()
    log("sheet", out.filepath_raw)


try:
    main_variants()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    print("\n".join(LOG))
