# กอกล้วยสมจริง (แทน BananaClump เดิม ขนาด/ชื่อชิ้นเท่าเดิม) — ใบฉีกเป็นริ้วตามเส้นใบ, ใบแห้งพับห้อยรอบต้น, กาบลำต้นซ้อนชั้นลอกแห้ง, หน่อเล็กรอบโคน
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/banana.py [-- export]
#   ไม่ใส่ = ภาพตัวอย่าง   ·   export = FBX + พื้นผิว   (ทุกไฟล์อยู่ใน assets/models/BananaClumpNew/ ภาพตัวอย่างใน previews/ ข้างใน)
# ชิ้น (ชื่อเดิมให้ MapBuilder ย้อมสี/ลมใช้ต่อได้): BananaClump (ใบสด) · BananaClump_B (ใบแก่/ใบแห้ง) · BananaClump_Base (ลำต้น หน่อ เศษใบโคน)
# หน่วย studs, origin = พื้นกลางกอ, ยอดลำต้นหลักที่ BANANA_TOP (-0.2, 9.4, 0.38 ในแกน Roblox) ให้เครือกล้วยเดิมห้อยได้ตรงที่
import bpy, math, os, sys
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))
src2 = open(os.path.join(HERE, "scarecrow_variants.py"), encoding="utf-8").read()
# ใช้ night_render / lumpy / frame_cam จากชุดหุ่นไล่กา (ไม่รัน main ของไฟล์นั้น)
exec(compile(src2[src2.index("# ---------------------------------------------------------------- ตัวช่วย"):src2.index("# ---------------------------------------------------------------- A ผีผมยาว")], "scarecrow_variants.py", "exec"))
exec(compile(src2[src2.index("# ---------------------------------------------------------------- ภาพกลางคืน (Cycles)"):src2.index("def build(letter):")], "scarecrow_variants.py", "exec"))

MODELS = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")
ROOT = os.path.join(MODELS, "BananaClumpNew")  # 1 โมเดล = 1 โฟลเดอร์ (FBX + พื้นผิว + previews)
PREV = os.path.join(ROOT, "previews")
os.makedirs(PREV, exist_ok=True)
TMP = os.path.join(os.environ.get("TEMP", MODELS), "banana_preview")
os.makedirs(TMP, exist_ok=True)

PAL.update({
    "bn_leaf": dict(c=(70, 112, 44), r=0.55, m=0, p="bn_leaf"),
    "bn_leaf_old": dict(c=(96, 112, 46), r=0.6, m=0, p="bn_leaf_old"),
    "bn_dead": dict(c=(112, 84, 52), r=0.85, m=0, p="bn_dead"),
    "bn_rib": dict(c=(150, 160, 96), r=0.5, m=0, p="bn_leaf"),
    "bn_stem": dict(c=(96, 110, 58), r=0.6, m=0, p="bn_stem"),
    "bn_sheath": dict(c=(118, 90, 58), r=0.85, m=0, p="bn_dead"),
    "bn_soil": dict(c=(70, 52, 38), r=0.95, m=0, p="bn_dead"),
})
KEYS[:] = list(PAL.keys())
_paint0 = paint


def paint(key, n, seed):
    spec = PAL[key]
    p = spec["p"]
    if not p.startswith("bn_"):
        return _paint0(key, n, seed)
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    n1 = vnoise(n, 5, seed)
    n2 = vnoise(n, 18, seed + 7)
    n3 = vnoise(n, 48, seed + 13)
    rough = np.full((n, n), spec["r"]) + 0.05 * (n2 - 0.5)
    metal = np.zeros((n, n))
    veins = np.abs(np.sin((yy * 40 + n2 * 0.6) * math.pi))
    if p in ("bn_leaf", "bn_leaf_old"):
        col = base * (0.86 + 0.18 * veins + 0.12 * (n3 - 0.5))[..., None]
        # ใบแก่: ขอบเหลือง/จุดสนิมใบ (โรคใบจุด) เป็นปื้น
        k = 0.35 if p == "bn_leaf" else 0.8
        yellow = np.clip((n1 - 0.55) * 3, 0, 1) * k
        col = col * (1 - yellow[..., None]) + np.array([0.55, 0.5, 0.2]) * yellow[..., None]
        spots = np.clip((n3 - 0.72) * 6, 0, 1) * k
        col = col * (1 - 0.6 * spots[..., None]) + np.array([0.25, 0.16, 0.08]) * (0.6 * spots)[..., None]
        h = 0.25 * veins
    elif p == "bn_dead":
        # ใบ/กาบแห้งสีน้ำตาลฟาง เส้นใยตามยาว ด่างคล้ำ
        col = base * (0.75 + 0.3 * veins + 0.2 * (n2 - 0.5))[..., None]
        col = col * (1 - 0.35 * np.clip((n1 - 0.5) * 2.5, 0, 1))[..., None]
        h = 0.4 * veins
    else:  # bn_stem ลำต้นเขียวหม่นมีลายด่างดำ-ม่วงแบบกล้วยน้ำว้า
        blot = np.clip((n2 - 0.58) * 4, 0, 1)
        col = base * (0.85 + 0.2 * np.abs(np.sin(xx * 30 * math.pi)) + 0.1 * (n3 - 0.5))[..., None]
        col = col * (1 - 0.55 * blot[..., None]) + np.array([0.16, 0.1, 0.12]) * (0.55 * blot)[..., None]
        h = 0.2 * blot
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), metal


rng = np.random.default_rng(31)
TOP = Vector((-0.2, -0.38, 9.4))  # ยอดลำต้นหลัก (แกน Blender: Roblox x, -z, y)


def stem(b, base, top, r0, r1, layers=3):
    """ลำต้นเทียม: กาบซ้อนเป็นชั้น โคนบาน ยอดเรียว + กาบแห้งลอกห้อยลงบางกาบ"""
    base, top = Vector(base), Vector(top)
    H = (top - base).length
    for L in range(layers):
        z0 = H * (0.12 * L)
        prof = [(r0 * 1.15 - L * 0.03, z0), (r0 - L * 0.05, z0 + H * 0.12), (r1 * 1.1 - L * 0.04, H * (0.92 - 0.05 * L)), (r1 * 0.9, H * (0.95 - 0.05 * L))]
        start = len(b.v)
        b.lathe(base.x, base.y, prof, 12, "bn_stem", z0=base.z)
        lumpy(b, start, 0.03, 4.0, seed=L + int(r0 * 10))
    # กาบแห้งลอกออกห้อย
    for k in range(int(3 + r0 * 3)):
        a = rng.uniform(0, 2 * math.pi)
        z = base.z + rng.uniform(0.15, 0.7) * H
        p0 = Vector((base.x + math.cos(a) * r0 * 0.95, base.y + math.sin(a) * r0 * 0.95, z))
        p1 = p0 + Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, -rng.uniform(0.8, 1.8)))
        b.beam(tuple(p0), tuple(p1), rng.uniform(0.18, 0.32), 0.03, "bn_sheath", side=(-math.sin(a), math.cos(a), 0))


def leaf(b, root, yaw, length, width, droop, key, shred=0.6, rib_key="bn_rib"):
    """ใบกล้วย: ก้านใบโค้งออกแล้วตกลง ใบแบ่งเป็นริ้ว (ฉีกตามเส้นใบ) ซ้าย/ขวา ปลายลู่ลง"""
    root = Vector(root)
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0))
    N = 16
    pts = []
    for i in range(N + 1):
        t = i / N
        horiz = length * t
        rise = length * (0.95 * t - droop * t * t)
        pts.append(root + d * horiz + Vector((0, 0, rise)))
    pet = [root + (pts[1] - root) * k for k in (0.0, 0.5, 1.0)]
    b.tube([tuple(p) for p in pts[:N // 2 + 1]], [0.07 + 0.03 * (1 - i / (N // 2)) for i in range(N // 2 + 1)], rib_key, n=6)
    # ริ้วใบ: แต่ละซีกตัดเป็นช่วงๆ ตามตำแหน่งที่ฉีก เว้นร่องเล็กๆ ขอบนอกลู่ลง
    for sgn in (-1, 1):
        cuts = [4]
        i = 4
        while i < N:
            step = int(rng.integers(1, 3)) if rng.random() < shred else int(rng.integers(3, 6))
            i = min(N, i + step)
            cuts.append(i)
        for a_, b_ in zip(cuts[:-1], cuts[1:]):
            gap = 0.025 if rng.random() < shred else 0.0
            for j in range(a_, b_):
                t0, t1 = j / N, (j + 1) / N
                w0 = width * math.sin(math.pi * min(0.98, max(0.08, t0))) ** 0.7
                w1 = width * math.sin(math.pi * min(0.98, max(0.08, t1))) ** 0.7
                p0, p1 = pts[j], pts[j + 1]
                if j == b_ - 1 and gap:
                    p1 = p1 - (p1 - p0) * 0.25
                sag = 0.18 * width
                o0 = p0 + side * sgn * w0 - Vector((0, 0, sag * (0.4 + t0)))
                o1 = p1 + side * sgn * w1 - Vector((0, 0, sag * (0.4 + t1)))
                # ริ้วปลายบางริ้วห้อยหลุดลงมา
                if rng.random() < shred * 0.15 and t0 > 0.4:
                    o1 = o1 - Vector((0, 0, rng.uniform(0.3, 0.8)))
                q = [b._v(tuple(p0)), b._v(tuple(p1)), b._v(tuple(o1)), b._v(tuple(o0))]
                b.face(q if sgn > 0 else q[::-1], key)
                b.face(q[::-1] if sgn > 0 else q, key)  # สองหน้า


def dead_leaf(b, root, yaw, length):
    """ใบแห้งหักพับห้อยแนบลำต้น"""
    root = Vector(root)
    d = Vector((math.cos(yaw), math.sin(yaw), 0))
    side = Vector((-math.sin(yaw), math.cos(yaw), 0))
    knee = root + d * 0.8 + Vector((0, 0, 0.3))
    tip = knee + d * 0.5 - Vector((0, 0, length))
    b.tube([tuple(root), tuple(knee), tuple(tip)], [0.07, 0.06, 0.03], "bn_dead", n=5)
    for k in range(6):
        t0, t1 = k / 6, (k + 1) / 6
        a0 = knee.lerp(tip, t0)
        a1 = knee.lerp(tip, t1)
        w = 0.3 * math.sin(math.pi * (t0 + 0.08)) + 0.06
        for sgn in (-1, 1):
            o0 = a0 + side * sgn * w * 0.6 + d * 0.15
            o1 = a1 + side * sgn * w * 0.5 + d * 0.15
            q = [b._v(tuple(a0)), b._v(tuple(a1)), b._v(tuple(o1)), b._v(tuple(o0))]
            b.face(q, "bn_dead")
            b.face(q[::-1], "bn_dead")


def make_banana():
    P = "BananaClumpNew"
    A, Bl, Ba = B("BananaClump"), B("BananaClump_B"), B("BananaClump_Base")
    for x in (A, Bl, Ba):
        x.bevel, x.sa = False, 50
    # ลำต้นหลัก + ต้นรอง + หน่อ
    stems = [((0.0, 0.0, 0.0), TOP, 0.75, 0.42, 1.0), ((1.9, 1.2, 0.0), (2.2, 1.5, 6.4), 0.55, 0.32, 0.7), ((-1.7, 1.1, 0.0), (-1.9, 1.3, 3.2), 0.38, 0.22, 0.45), ((0.6, -1.8, 0.0), (0.7, -2.0, 1.6), 0.25, 0.14, 0.25)]
    for base, top, r0, r1, s in stems:
        stem(Ba, base, top, r0, r1, layers=3 if s > 0.6 else 2)
    # เศษใบแห้งกองโคนกอ + ดินพูน
    Ba.lathe(0, 0, [(2.6, 0.0), (1.8, 0.18), (0.9, 0.3), (0.0, 0.32)], 16, "bn_soil")
    for _ in range(10):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.8, 2.4)
        p0 = (math.cos(a) * r, math.sin(a) * r, 0.2)
        p1 = (math.cos(a) * (r + 1.2), math.sin(a) * (r + 1.2), 0.08)
        Ba.beam(p0, p1, rng.uniform(0.4, 0.7), 0.02, "bn_dead", side=(-math.sin(a), math.cos(a), 0))
    # มงกุฎใบต้นหลัก: ใบสดชูขึ้น (A) + ใบแก่ล่างตกลง (B) + ใบแห้งพับห้อย (B)
    crowns = [(TOP, 1.0), (Vector((2.2, 1.5, 6.4)), 0.7), (Vector((-1.9, 1.3, 3.2)), 0.45), (Vector((0.7, -2.0, 1.6)), 0.28)]
    for ci, (top, s) in enumerate(crowns):
        n_fresh = 6 if ci == 0 else (5 if ci == 1 else 3)
        for k in range(n_fresh):
            yaw = 2 * math.pi * k / n_fresh + rng.uniform(-0.3, 0.3) + ci
            L = s * rng.uniform(5.6, 7.0)
            leaf(A, top + Vector((0, 0, rng.uniform(-0.2, 0.3) * s)), yaw, L, s * rng.uniform(1.5, 1.85), rng.uniform(0.75, 0.95), "bn_leaf", shred=rng.uniform(0.15, 0.4))
        if s >= 0.45:
            for k in range(3 if ci == 0 else 2):
                yaw = rng.uniform(0, 2 * math.pi)
                leaf(Bl, top - Vector((0, 0, 0.5 * s)), yaw, s * rng.uniform(4.8, 6.0), s * 1.5, rng.uniform(1.4, 1.7), "bn_leaf_old", shred=0.55)
            for k in range(4 if ci == 0 else 2):
                yaw = rng.uniform(0, 2 * math.pi)
                dead_leaf(Bl, top - Vector((0, 0, 0.6 * s)) + Vector((math.cos(yaw), math.sin(yaw), 0)) * 0.3 * s, yaw, s * rng.uniform(2.5, 4.0))
    return P, [A, Bl, Ba]


def day_render(objs, path):
    sc = bpy.context.scene
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.85, 1)
    for o in list(sc.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(-35)))
    bpy.context.active_object.data.energy = 3.5
    frame_cam(objs, (0.4, -1.0, 0.2), lens=40, dist=1.15)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main_banana():
    global ROOT
    export_mode = "export" in sys.argv
    ROOT = os.path.join(MODELS, "BananaClumpNew") if export_mode else TMP
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prop, builders = make_banana()
    coll, objs = realize(prop, builders)
    if export_mode:
        export(prop, objs)
        for o in objs:
            mn = [min((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
            mx = [max((o.matrix_world @ v.co)[i] for v in o.data.vertices) for i in range(3)]
            log("CENTER %s %.4f %.4f %.4f SIZE %.4f %.4f %.4f" % (o.name, *[(a + b) / 2 for a, b in zip(mn, mx)], *[b - a for a, b in zip(mn, mx)]))
    night_render(objs, os.path.join(PREV, "BananaClumpNew_night.png"))
    day_render(objs, os.path.join(PREV, "BananaClumpNew_day.png"))


try:
    main_banana()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    print("\n".join(LOG))
