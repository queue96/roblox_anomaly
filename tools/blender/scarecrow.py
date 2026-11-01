# หุ่นไล่กาไทยกลางนา (แทนหุ่น Toolbox เดิม) — สร้างด้วย Blender แบบ headless ด้วยตัวช่วยปั้นจาก thai_vehicles.py
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/scarecrow.py
# ผลลัพธ์: assets/models/ScarecrowThai.fbx + ScarecrowThai_Color/_Normal/_Roughness/_Metalness.png, previews/ScarecrowThai*.png
# ชิ้น: ScarecrowThai (ตัวหุ่นทั้งหมด) + ScarecrowThai_EyeL_Neon / _EyeR_Neon (ตากระดุม — AnomalyManager หาชิ้นชื่อมี "Eye" แล้วเปลี่ยนเป็นแดง)
# หน่วย studs, origin = โคนเสา (ปักดินตอนวาง), หน้าหุ่นหันไป -Y
# เสาไผ่ + ไม้คานไผ่มัดเชือก, เสื้อม่อฮ่อมสีครามซีดขาดรุ่ย, ผ้าขาวม้าคาดเอว, หัวกระสอบป่านเย็บปาก, งอบสาน, ฟางทะลักแขนเสื้อ/คอ, ถุงพลาสติกผูกปลายแขน
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))

ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")  # thai_vehicles.py ชี้ไปเครื่องเดิม
PREV = os.path.join(ROOT, "previews")

PAL.update({
    "sc_bamboo": dict(c=(150, 124, 80), r=0.7, m=0, p="sc_bamboo"),
    "sc_rope": dict(c=(132, 108, 70), r=0.95, m=0, p="sc_straw"),
    "sc_indigo": dict(c=(46, 56, 82), r=0.92, m=0, p="sc_indigo"),
    "sc_plaid": dict(c=(150, 46, 40), r=0.9, m=0, p="sc_plaid"),
    "sc_burlap": dict(c=(146, 120, 84), r=0.95, m=0, p="sc_burlap"),
    "sc_thread": dict(c=(34, 26, 22), r=0.8, m=0, p="plain"),
    "sc_straw": dict(c=(176, 148, 82), r=0.9, m=0, p="sc_straw"),
    "sc_ngob": dict(c=(160, 132, 88), r=0.85, m=0, p="sc_ngob"),
    "sc_eye": dict(c=(24, 20, 18), r=0.35, m=0, p="plain"),
    "sc_bag": dict(c=(214, 210, 200), r=0.45, m=0, p="sc_bag"),
    "sc_bag_red": dict(c=(170, 36, 32), r=0.45, m=0, p="sc_bag"),
})
KEYS[:] = list(PAL.keys())

_paint = paint


def paint(key, n, seed):
    """ลายผ้า/ฟาง/ไผ่ของหุ่นไล่กา (ที่เหลือใช้ลายเดิมของ thai_vehicles.py)"""
    spec = PAL[key]
    p = spec["p"]
    if not p.startswith("sc_"):
        return _paint(key, n, seed)
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    n1 = vnoise(n, 5, seed)
    n2 = vnoise(n, 18, seed + 7)
    n3 = vnoise(n, 48, seed + 13)
    rough = np.full((n, n), spec["r"]) + 0.05 * (n2 - 0.5)
    metal = np.zeros((n, n))
    if p == "sc_straw":
        # เส้นฟางเรียงตามยาว สีเหลืองซีดสลับน้ำตาล
        fib = np.abs(np.sin((xx * 26 + n2 * 1.5) * math.pi))
        fib2 = np.abs(np.sin((xx * 61 + n3 * 2.0) * math.pi))
        k = 0.55 + 0.35 * fib + 0.2 * fib2 + 0.15 * (n1 - 0.5)
        col = base * k[..., None]
        col = col * (1 - 0.35 * np.clip((n2 - 0.6) * 4, 0, 1))[..., None]  # ฟางเน่าดำเป็นหย่อม
        h = 0.5 * fib + 0.3 * fib2
    elif p == "sc_burlap":
        # ป่านกระสอบ: เส้นยืน-เส้นพุ่งหยาบ + คราบดินคราบฝน
        wx = np.abs(np.sin(xx * 34 * math.pi))
        wy = np.abs(np.sin(yy * 34 * math.pi))
        weave = np.where((np.floor(xx * 34) + np.floor(yy * 34)) % 2 == 0, wx, wy)
        col = base * (0.72 + 0.4 * weave + 0.1 * (n3 - 0.5))[..., None]
        stain = np.clip((n1 - 0.55) * 3, 0, 1)
        col = col * (1 - 0.4 * stain)[..., None] + np.array([0.18, 0.12, 0.08]) * (0.25 * stain)[..., None]
        h = 0.6 * weave
    elif p == "sc_indigo":
        # ม่อฮ่อมสีครามซีดแดด: ด่างจางเป็นปื้น ขอบเปื่อยสีอ่อน คราบโคลน
        fade = np.clip((n1 - 0.35) * 1.6, 0, 1)
        col = base * (1 - fade[..., None]) + np.array([0.42, 0.46, 0.52]) * fade[..., None]
        weave = np.abs(np.sin(xx * 70 * math.pi)) * np.abs(np.sin(yy * 70 * math.pi))
        col = col * (0.88 + 0.18 * weave + 0.1 * (n3 - 0.5))[..., None]
        mud = np.clip((n2 - 0.68) * 4, 0, 1)
        col = col * (1 - mud[..., None]) + np.array([0.24, 0.17, 0.11]) * mud[..., None]
        h = 0.3 * weave
    elif p == "sc_plaid":
        # ผ้าขาวม้าตาหมากรุก แดง/ขาวหม่น/ฟ้าคราม
        cx = np.floor(xx * 6) % 3
        cy = np.floor(yy * 6) % 3
        pal = np.array([[0.58, 0.18, 0.16], [0.72, 0.68, 0.6], [0.2, 0.32, 0.5]])
        a = pal[cx.astype(int)]
        b = pal[cy.astype(int)]
        col = (a + b) / 2
        thin = (np.abs(np.sin(xx * 12 * math.pi)) < 0.08) | (np.abs(np.sin(yy * 12 * math.pi)) < 0.08)
        col = np.where(thin[..., None], col * 0.6, col)
        col = col * (0.8 + 0.25 * n2)[..., None] * 0.85  # ซีดและเปื้อน
        h = 0.2 * n3
    elif p == "sc_ngob":
        # งอบใบลานสานลายขัด (แถบทแยง)
        d1 = np.abs(np.sin((xx + yy) * 22 * math.pi))
        d2 = np.abs(np.sin((xx - yy) * 22 * math.pi))
        weave = np.where((np.floor((xx + yy) * 22) + np.floor((xx - yy) * 22)) % 2 == 0, d1, d2)
        col = base * (0.7 + 0.4 * weave + 0.12 * (n2 - 0.5))[..., None]
        col = col * (1 - 0.3 * np.clip((n1 - 0.6) * 3, 0, 1))[..., None]  # ราดำ
        h = 0.6 * weave
    elif p == "sc_bamboo":
        # ผิวไผ่แห้ง: เสี้ยนตามยาว + ด่างเขียวหม่น
        grain = np.abs(np.sin((xx * 40 + n2 * 2) * math.pi))
        col = base * (0.8 + 0.25 * grain + 0.15 * (n1 - 0.5))[..., None]
        moss = np.clip((n1 - 0.62) * 3, 0, 1)
        col = col * (1 - 0.4 * moss[..., None]) + np.array([0.3, 0.34, 0.2]) * (0.4 * moss)[..., None]
        h = 0.3 * grain
    else:  # sc_bag ถุงพลาสติกยับ
        crinkle = np.abs(np.sin((xx * 9 + n2 * 3) * math.pi)) * np.abs(np.sin((yy * 7 + n3 * 3) * math.pi))
        col = base * (0.8 + 0.3 * crinkle)[..., None]
        col = col * (1 - 0.3 * np.clip((n1 - 0.55) * 3, 0, 1))[..., None]
        h = 0.4 * crinkle
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), metal


# ---------------------------------------------------------------- ปั้น
rng = np.random.default_rng(77)
ZBAR = 5.0  # ไม้คานแขน
ZHEAD = 6.15


def bamboo(b, p0, p1, r, nodes):
    """ลำไผ่: ทรงกระบอก + ข้อปล้องนูนเป็นช่วงๆ"""
    p0, p1 = Vector(p0), Vector(p1)
    b.cone(tuple(p0), tuple(p1), r, r * 0.92, "sc_bamboo", n=10)
    for k in range(1, nodes + 1):
        t = k / (nodes + 1)
        c = p0.lerp(p1, t)
        d = (p1 - p0).normalized()
        b.cone(tuple(c - d * 0.05), tuple(c + d * 0.05), r * 1.13, r * 1.13, "sc_bamboo", n=10)


def straw_tuft(b, c, out, count, length, spread, droop):
    """กอฟางทะลักออกจากปลายแขน/คอ: เส้นฟางแบนๆ พุ่งออกแล้วห้อยลง"""
    c, out = Vector(c), Vector(out).normalized()
    side = out.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(out).normalized()
    for _ in range(count):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, spread)
        s = c + (side * math.cos(a) + up * math.sin(a)) * r
        L = length * rng.uniform(0.6, 1.2)
        e = s + out * L + (side * math.cos(a) + up * math.sin(a)) * L * 0.35 - Vector((0, 0, droop * L * rng.uniform(0.5, 1.2)))
        b.beam(tuple(s), tuple(e), rng.uniform(0.04, 0.07), 0.015, "sc_straw", side=tuple(up))


def tatter(b, ring, z0, key, count, lmin, lmax, outward=0.08):
    """ชายผ้าขาดเป็นริ้วห้อยลงรอบวง ring(t)->(x,y)"""
    for i in range(count):
        t = (i + rng.uniform(-0.3, 0.3)) / count
        x, y = ring(t)
        L = rng.uniform(lmin, lmax)
        w = rng.uniform(0.14, 0.26)
        nx, ny = x, y
        ln = math.hypot(nx, ny) or 1
        top = (x, y, z0)
        bot = (x + nx / ln * outward + rng.uniform(-0.05, 0.05), y + ny / ln * outward, z0 - L)
        b.beam(top, bot, w, 0.02, key, side=(-ny / ln, nx / ln, 0))


def make_scarecrow():
    P = "ScarecrowThai"
    body = B(P)
    body.bevel = False
    body.sa = 60
    eyeL, eyeR = B(P + "_EyeL_Neon"), B(P + "_EyeR_Neon")
    for e in (eyeL, eyeR):
        e.bevel = False

    # เสาไผ่ปักดิน + ไม้คานแขน มัดเชือกไขว้
    bamboo(body, (0, 0, 0), (0, 0, ZHEAD - 0.3), 0.15, 4)
    bamboo(body, (-2.7, 0.02, ZBAR), (2.7, -0.02, ZBAR + 0.06), 0.11, 4)
    for k in range(4):
        body.torus((0, 0, ZBAR - 0.12 + k * 0.08), "z", 0.19, 0.03, "sc_rope", nu=12, nv=4)
    body.beam((-0.22, -0.18, ZBAR + 0.2), (0.22, -0.18, ZBAR - 0.2), 0.05, 0.04, "sc_rope", side=(0, 1, 0))
    body.beam((0.22, -0.18, ZBAR + 0.2), (-0.22, -0.18, ZBAR - 0.2), 0.05, 0.04, "sc_rope", side=(0, 1, 0))

    # ลำตัวยัดฟาง (เสื้อม่อฮ่อม) ทรงรีพองไม่เท่ากัน
    body.ellipsoid((0, 0, 4.25), (0.86, 0.52, 1.2), "sc_indigo", nu=16, nv=10)
    body.ellipsoid((0.15, -0.12, 4.6), (0.6, 0.4, 0.6), "sc_indigo", nu=12, nv=7)  # ฟางยัดไม่เรียบ หน้าอกนูนเบี้ยว
    # ปกเสื้อ + กระดุมหลุด 1 เม็ด
    body.torus((0, 0, 5.32), "z", 0.36, 0.08, "sc_indigo", nu=14, nv=5)
    for k, z in enumerate((4.95, 4.55, 4.15)):
        if k != 1:
            body.ellipsoid((0.02, -0.53, z), (0.05, 0.02, 0.05), "sc_thread", nu=8, nv=4)
    # แขนเสื้อคล้องไม้คาน ห้อยย้วยกลางแขน
    for sx in (-1, 1):
        pts = [(sx * 0.6, 0, 4.92), (sx * 1.3, 0, 4.82), (sx * 1.9, 0, 4.9), (sx * 2.35, 0, 4.98)]
        body.tube(pts, [0.42, 0.36, 0.34, 0.3], "sc_indigo", n=10)
        # ปลายแขนขาดรุ่ย + ฟางทะลัก
        tatter(body, lambda t, sx=sx: (sx * 2.38, 0.3 * math.cos(2 * math.pi * t)), 4.85, "sc_indigo", 6, 0.25, 0.55, outward=0.0)
        straw_tuft(body, (sx * 2.45, 0, 4.95), (sx, 0, -0.3), 22, 0.55, 0.22, 0.6)
        # ถุงพลาสติกผูกปลายไม้คาน (ไล่นก) ปลิวเป็นริ้ว
        for j in range(3):
            key = "sc_bag_red" if j == 1 else "sc_bag"
            top = (sx * (2.62 - j * 0.04), rng.uniform(-0.05, 0.05), ZBAR - 0.05)
            bot = (sx * (2.75 + j * 0.1), rng.uniform(-0.25, 0.25), ZBAR - rng.uniform(0.9, 1.5))
            body.beam(top, bot, rng.uniform(0.12, 0.2), 0.01, key, side=(0, 1, 0))
    # ชายเสื้อขาดรุ่ยรอบตัว
    tatter(body, lambda t: (0.82 * math.cos(2 * math.pi * t), 0.5 * math.sin(2 * math.pi * t)), 3.2, "sc_indigo", 14, 0.3, 0.85)
    straw_tuft(body, (0, 0, 3.15), (0, 0, -1), 26, 0.6, 0.5, 0.1)  # ฟางห้อยใต้ชายเสื้อ

    # ผ้าขาวม้าคาดเอว (วงรีตามลำตัว) + ปมผูกด้านหน้าและชายผ้าห้อย
    with body.xf(Matrix.Translation((0, 0, 3.62)) @ Matrix.Scale(0.64, 4, (0, 1, 0))):
        body.torus((0, 0, 0), "z", 0.86, 0.11, "sc_plaid", nu=20, nv=5)
    body.ellipsoid((0.25, -0.55, 3.62), (0.16, 0.1, 0.13), "sc_plaid", nu=10, nv=6)
    body.beam((0.22, -0.58, 3.55), (0.32, -0.62, 2.85), 0.24, 0.03, "sc_plaid", side=(1, 0, 0))
    body.beam((0.32, -0.56, 3.55), (0.55, -0.55, 3.0), 0.2, 0.03, "sc_plaid", side=(1, 0, 0))

    # หัวกระสอบป่าน มัดคอด้วยเชือก ฟางโผล่ใต้เชือก จุกกระสอบรวบบนหัว
    body.ellipsoid((0, 0, ZHEAD), (0.62, 0.58, 0.72), "sc_burlap", nu=16, nv=10)
    body.ellipsoid((0.05, 0.02, ZHEAD + 0.72), (0.2, 0.18, 0.18), "sc_burlap", nu=10, nv=6)
    body.torus((0, 0, 5.55), "z", 0.33, 0.05, "sc_rope", nu=14, nv=4)
    straw_tuft(body, (0, 0, 5.48), (0, 0, -1), 18, 0.35, 0.3, 0.2)
    # ปากเย็บด้ายดำ (ตะเข็บไขว้) โค้งยิ้มนิดๆ บนหน้ากระสอบ (-Y)
    for k in range(7):
        x = -0.3 + k * 0.1
        z = ZHEAD - 0.28 + 0.06 * (x / 0.3) ** 2
        y = -0.58 * math.sqrt(max(0.0, 1 - (x / 0.62) ** 2 - ((z - ZHEAD) / 0.72) ** 2)) - 0.01
        body.beam((x - 0.04, y, z - 0.06), (x + 0.04, y, z + 0.06), 0.025, 0.02, "sc_thread", side=(0, 1, 0))
        body.beam((x - 0.04, y, z + 0.06), (x + 0.04, y, z - 0.06), 0.025, 0.02, "sc_thread", side=(0, 1, 0))
    body.beam((-0.33, -0.48, ZHEAD - 0.27), (0.33, -0.48, ZHEAD - 0.27), 0.02, 0.02, "sc_thread", side=(0, 0, 1))
    # รอยปะกระสอบข้างแก้ม
    body.beam((0.38, -0.42, ZHEAD + 0.05), (0.5, -0.24, ZHEAD + 0.05), 0.26, 0.02, "sc_burlap", side=(0, 0, 1))
    # ตากระดุม 2 เม็ด (ชิ้นแยก ให้ Studio ทำเป็น Neon เรืองแดงตอนเป็นผี) ข้างหนึ่งเย็บเบี้ยว
    eyeL.ellipsoid((-0.22, -0.56, ZHEAD + 0.08), (0.12, 0.05, 0.12), "sc_eye", nu=12, nv=6)
    eyeR.ellipsoid((0.24, -0.555, ZHEAD + 0.03), (0.105, 0.05, 0.105), "sc_eye", nu=12, nv=6)
    for ex, ez in ((-0.22, ZHEAD + 0.08), (0.24, ZHEAD + 0.03)):
        body.beam((ex - 0.06, -0.61, ez), (ex + 0.06, -0.61, ez), 0.02, 0.02, "sc_thread", side=(0, 0, 1))

    # งอบสานเอียงนิดๆ (ทรงกรวยปีกกว้าง + โครงรองหัวด้านใน)
    tilt = Matrix.Translation((0, 0, ZHEAD + 0.42)) @ Matrix.Rotation(math.radians(-11), 4, "X") @ Matrix.Rotation(math.radians(6), 4, "Y")
    with body.xf(tilt):
        prof = [(0.0, 0.72), (0.18, 0.62), (0.5, 0.36), (0.85, 0.12), (1.12, 0.0), (1.2, -0.04)]
        body.lathe(0, 0, prof, 24, "sc_ngob")
        under = [(1.18, -0.07), (0.85, 0.07), (0.5, 0.3), (0.18, 0.55), (0.0, 0.65)]
        body.lathe(0, 0, under, 24, "sc_ngob")
        body.torus((0, 0, 0.12), "z", 0.48, 0.05, "sc_bamboo", nu=14, nv=4)
        # ปีกงอบแหว่ง 1 จุด: เส้นสานหลุดห้อย
        for k in range(4):
            a = math.radians(200 + k * 6)
            body.beam((1.12 * math.cos(a), 1.12 * math.sin(a), 0.0), (1.3 * math.cos(a), 1.3 * math.sin(a), -0.25 - k * 0.05), 0.05, 0.01, "sc_ngob", side=(0, 0, 1))
    return P, [body, eyeL, eyeR]


def main_scarecrow():
    os.makedirs(PREV, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prop, builders = make_scarecrow()
    log(prop)
    coll, objs = realize(prop, builders)
    export(prop, objs)
    preview(prop, objs, (2.2, 0.0))
    frame_cam(objs, (0.15, -1.0, 0.25), dist=0.75)
    bpy.context.scene.render.filepath = os.path.join(PREV, prop + "_face.png")
    bpy.ops.render.render(write_still=True)
    for o in objs:
        mn = [min((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
        mx = [max((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
        c = [(a + b) / 2 / S for a, b in zip(mn, mx)]
        log("CENTER %s %.4f %.4f %.4f" % (o.name, c[0], c[1], c[2]))


try:
    main_scarecrow()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    print("\n".join(LOG))
