# เปรต (Pret) ผีตัวสูงผอมเท่าต้นตาล — ตัวละครมี rig + 3 ท่า สำหรับนำเข้า Roblox — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\pret.py -Out C:\tmp\pret.txt -TimeoutSec 2400
#   ตั้ง $env:PRET_STAGE = "shape" ก่อนรัน = ปั้นรูปทรงแล้ว render ภาพสีเทาเร็วๆ อย่างเดียว (ไม่ bake ไม่ rig ไม่ export)
# ผลลัพธ์: assets/models/Pret.fbx (mesh + rig ท่ายืนตั้งต้น) + Pret_Idle.fbx / Pret_TallSlowWalk.fbx / Pret_Shriek.fbx (ท่าละไฟล์)
#          Pret_Color/_Normal/_Roughness/_Metalness.png (atlas 1024 ใช้ร่วมกันทุกชิ้น), assets/models/pret.blend
#          previews/Pret_front.png, Pret_side.png, Pret.png (3/4), Pret_scale.png, Pret_walk.png, Pret_shriek.png, Pret_rest.png
# วิธีปั้น: กายวิภาคเป็น metaball (กระดูก ซี่โครง ข้อปูด เบ้าตาเป็นลูกบอลลบ) → mesh ละเอียด (HI) → decimate เหลือ ~15k tris (LO)
#          ลายผิว (ผิวแห้งแตกระแหง เงาในร่องซี่โครง เบ้าตาดำ เล็บ) เป็น node procedural แล้ว bake จาก HI ลง LO ด้วย Cycles
# หน่วยเมตร (1 stud = 0.28 m) สูง 3.92 m = 14 studs · หน้าตัวละครหันไป -Y, ซ้ายของตัวละคร = +X, origin = พื้นใต้กลางเท้า
import bpy, bmesh, math, os, sys, time, traceback
import numpy as np
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
ROOT = os.path.join(REPO, "assets", "models")
PREV = os.path.join(ROOT, "previews")
NAME = "Pret"
STUD = 0.28
HEIGHT = 14 * STUD          # สูงรวมผม 14 studs
TEX = 1024
STAGE = os.environ.get("PRET_STAGE", "full")
FPS = 30
LOG = []
T0 = time.time()


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(f"[{time.time() - T0:6.1f}s] {s}")
    print(s)


def v3(x, y, z):
    return Vector((x, y, z))


def lin(c):
    """สี sRGB 0-255 -> linear (ค่าที่ bake ลงภาพ sRGB แล้วได้สีนี้ตรงๆ)"""
    def f(u):
        u /= 255.0
        return u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
    return tuple(f(x) for x in c)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def sstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ================================================================ 1. กายวิภาค (metaball)
# Blender metaball: field = stiffness * (1 - d²/R²)³ รวมทุกชิ้น ผิวอยู่ที่ field = threshold
# ลูกเดี่ยวผิวอยู่ที่ d = R * K_MB จึงกำหนดรัศมีที่อยากเห็นจริง (r) แล้วตั้ง R = r / K_MB
K_MB = math.sqrt(1.0 - (0.6 / 2.0) ** (1.0 / 3.0))
J = {}      # จุดข้อต่อ (ใช้วางกระดูก) — ถูกคูณ scale รวมทีหลัง
DIRS = {}   # ทิศ (ไม่คูณ scale)
TIPS = []   # ปลายเล็บมือ/เท้า (mask สีเล็บ)


class Meta:
    def __init__(self, name, res):
        self.mb = bpy.data.metaballs.new(name)
        self.mb.resolution = res
        self.mb.render_resolution = res
        self.mb.threshold = 0.6
        self.ob = bpy.data.objects.new(name, self.mb)
        bpy.context.scene.collection.objects.link(self.ob)
        self.count = 0
        self.th = 1.0   # ตัวคูณความหนาของส่วนที่กำลังปั้น

    def _el(self, typ, p, r, neg):
        e = self.mb.elements.new(type=typ)
        e.co = Vector(p)
        e.radius = r * self.th / K_MB
        e.stiffness = 2.0
        e.use_negative = neg
        self.count += 1
        return e

    def ball(self, p, r, neg=False):
        return self._el("BALL", p, r, neg)

    def cap(self, a, b, r, neg=False):
        a, b = Vector(a), Vector(b)
        e = self._el("CAPSULE", (a + b) / 2, r, neg)
        d = b - a
        e.size_x = max(d.length / 2, 1e-4)
        if d.length > 1e-6:
            e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())
        return e

    def chain(self, pts, r0, r1=None):
        r1 = r0 if r1 is None else r1
        for i in range(len(pts) - 1):
            t = i / max(1, len(pts) - 2)
            self.cap(pts[i], pts[i + 1], r0 + (r1 - r0) * t)

    def ell(self, p, sx, sy, sz, rot=None, neg=False):
        m = max(sx, sy, sz)
        e = self._el("ELLIPSOID", p, m, neg)
        e.size_x, e.size_y, e.size_z = sx / m, sy / m, sz / m
        if rot is not None:
            e.rotation = rot
        return e


# ---- ซี่โครง: หน้าตัดวงรีที่ความสูง z (ครึ่งกว้าง a, ครึ่งลึก b, กลางที่ y = RC_Y)
RZ0, RZ1, RC_Y = 2.42, 3.12, 0.02


def rib_a(z):
    t = (z - RZ0) / (RZ1 - RZ0)
    return 0.185 - 0.17 * (t - 0.42) ** 2


def rib_b(z):
    t = min(max((z - RZ0) / (RZ1 - RZ0), 0.0), 1.0)
    return 0.112 + 0.022 * math.sin(math.pi * t)


HEAD_C = v3(0.0, -0.06, 3.64)               # กลางหัว
CRANIUM = (HEAD_C + v3(0, 0.025, 0.06), (0.112, 0.13, 0.12))  # กะโหลก (กลาง, ครึ่งแกน)
EYE_R = 0.025


def build_body(M):
    H = HEAD_C
    # ---------------- ขา
    for s, side in ((1, "Left"), (-1, "Right")):
        x = s * 0.15
        hip, knee, ank = v3(x, 0.0, 1.86), v3(x, 0.0, 0.98), v3(x, 0.0, 0.10)
        J[side + "Hip"], J[side + "Knee"], J[side + "Ankle"] = hip, knee, ank
        M.cap(hip + v3(s * 0.01, 0, 0), knee + v3(0, 0, 0.05), 0.034)            # กระดูกต้นขา
        M.cap(hip + v3(s * 0.005, 0.0, -0.06), hip + v3(0, 0.005, -0.42), 0.05)   # เนื้อต้นขาที่เหลือ
        M.cap(hip + v3(0, 0.01, -0.40), knee + v3(0, 0.012, 0.16), 0.036)
        M.ball(hip + v3(s * 0.052, 0.005, 0.03), 0.04)                            # ปุ่มสะโพก
        M.ball(knee + v3(0, -0.04, 0.0), 0.038)                                   # สะบ้า
        M.ball(knee + v3(s * 0.03, 0.0, -0.01), 0.041)
        M.ball(knee + v3(-s * 0.028, 0.0, -0.01), 0.039)
        M.ball(knee + v3(0, 0.018, -0.055), 0.038)                                # หัวกระดูกหน้าแข้ง
        M.cap(knee + v3(0, 0, -0.06), ank + v3(0, 0, 0.04), 0.028)               # กระดูกหน้าแข้ง
        M.cap(knee + v3(0, -0.022, -0.08), ank + v3(0, -0.012, 0.09), 0.017)      # สันหน้าแข้ง
        M.cap(knee + v3(0, 0.03, -0.12), knee + v3(0, 0.024, -0.48), 0.034)       # น่องลีบ
        M.ball(ank + v3(s * 0.031, 0.0, 0.0), 0.023)                              # ตาตุ่ม
        M.ball(ank + v3(-s * 0.029, 0.005, 0.01), 0.023)
        M.cap(ank, ank + v3(0, 0.05, -0.05), 0.032)
        M.ball(v3(x, 0.055, 0.045), 0.044)                                         # ส้นเท้า
        M.ell(v3(x + s * 0.004, -0.07, 0.045), 0.048, 0.10, 0.026)                 # หลังเท้า
        ball_c = None
        for o in (-2, -1, 0, 1, 2):                                                # o=-2 = นิ้วโป้ง (ด้านใน)
            base = v3(x + s * o * 0.015, -0.02, 0.072)
            mt = v3(x + s * o * 0.023, -0.17, 0.03)
            tip = mt + v3(s * o * 0.006, -0.10 + abs(o) * 0.013, -0.012)
            r = 0.017 if o == -2 else 0.012
            M.cap(base, mt, 0.014)
            M.ball(mt, r + 0.002)
            M.cap(mt, tip, r)
            claw = tip + v3(0, -0.022, -0.007)
            M.cap(tip, claw, 0.006)
            TIPS.append((claw, 0.026))
            if o == 0:
                ball_c = mt
        J[side + "Ball"] = v3(x, ball_c.y, 0.035)
        J[side + "ToeTip"] = v3(x, -0.30, 0.03)

    # ---------------- เชิงกราน + ท้องแฟบ
    M.ell(v3(0, 0.015, 1.96), 0.165, 0.10, 0.11)
    for s in (1, -1):
        M.ball(v3(s * 0.15, -0.005, 2.06), 0.044)          # สันกระดูกเชิงกราน
        M.ball(v3(s * 0.115, -0.07, 2.02), 0.025)          # ปุ่มหน้าเชิงกราน
        M.ell(v3(s * 0.07, 0.075, 1.89), 0.065, 0.05, 0.08)  # ก้นลีบ
        M.cap(v3(s * 0.15, 0.0, 1.86), v3(s * 0.06, 0.0, 1.95), 0.058)
    M.cap(v3(0, 0.035, 2.0), v3(0, 0.03, 2.5), 0.082)       # แกนลำตัว
    M.ell(v3(0, -0.01, 2.2), 0.10, 0.072, 0.12)            # ท้องแฟบ (ถอยหลังกว่าซี่โครง)
    M.ell(v3(0, 0.05, 2.2), 0.11, 0.06, 0.15)              # กล้ามหลัง
    J["Pelvis"] = v3(0, 0.02, 1.95)

    # ---------------- กระดูกสันหลังนูน
    def back_y(z):
        if z < 2.4:
            return 0.104
        if z < 3.12:
            return RC_Y + rib_b(z) - 0.005
        return 0.12 - (z - 3.12) * 0.8
    z = 1.93
    while z < 3.27:
        M.ball(v3(0, back_y(z), z), 0.016)
        z += 0.042

    # ---------------- ซี่โครง
    for zz in np.linspace(2.46, 3.1, 8):
        M.ell(v3(0, RC_Y, zz), rib_a(zz) - 0.028, rib_b(zz) - 0.028, 0.075)
    for s in (1, -1):
        for i in range(10):
            zb = 3.07 - i * 0.066
            drop = 0.11
            phi_end = math.pi - 0.16 if i < 6 else math.pi - 0.30 - 0.22 * (i - 6)
            pts = []
            for k in range(13):
                phi = phi_end * k / 12
                zz = zb - drop * (1 - math.cos(phi)) / 2
                pts.append(v3(s * rib_a(zz) * math.sin(phi), RC_Y + rib_b(zz) * math.cos(phi), zz))
            M.chain(pts, 0.0125, 0.0105)
    M.cap(v3(0, RC_Y - rib_b(3.06) - 0.004, 3.1), v3(0, RC_Y - rib_b(2.74) - 0.004, 2.72), 0.02)  # กระดูกอก

    # ---------------- ไหล่ ไหปลาร้า สะบัก คอ
    for s in (1, -1):
        M.cap(v3(s * 0.08, 0.02, 3.12), v3(s * 0.30, 0.01, 3.12), 0.044)
        M.cap(v3(s * 0.04, 0.05, 3.27), v3(s * 0.27, 0.04, 3.17), 0.03)            # บ่า
        M.cap(v3(s * 0.02, -0.095, 3.16), v3(s * 0.30, -0.015, 3.19), 0.016)       # ไหปลาร้า
        M.ball(v3(s * 0.33, 0.01, 3.17), 0.031)
        M.ell(v3(s * 0.345, 0.005, 3.09), 0.043, 0.05, 0.08)                       # ไหล่ลีบ
        M.ell(v3(s * 0.13, RC_Y + rib_b(2.95) + 0.006, 2.95), 0.075, 0.018, 0.10)  # สะบัก
        M.cap(v3(s * 0.06, 0.17, 3.04), v3(s * 0.28, 0.08, 3.13), 0.011)
        M.cap(v3(s * 0.048, 0.0, 3.49), v3(s * 0.024, -0.085, 3.17), 0.012)        # เอ็นคอ
    M.cap(v3(0, 0.04, 3.12), v3(0, -0.02, 3.5), 0.036)
    M.cap(v3(0, 0.07, 3.18), v3(0, 0.02, 3.5), 0.028)
    M.ball(v3(0, -0.068, 3.32), 0.015)                                              # ลูกกระเดือก
    M.cap(v3(0, -0.055, 3.2), v3(0, -0.06, 3.4), 0.016)
    J["NeckBase"] = v3(0, 0.025, 3.15)
    J["NeckTop"] = v3(0, -0.02, 3.48)

    # ---------------- หัวกะโหลก
    cc, (sx, sy, sz) = CRANIUM
    M.ell(cc, sx, sy, sz)
    M.ell(H + v3(0, -0.045, -0.03), 0.085, 0.075, 0.09)            # ใบหน้า
    M.cap(H + v3(-0.075, -0.112, 0.035), H + v3(0.075, -0.112, 0.035), 0.02)  # สันคิ้ว
    for s in (1, -1):
        M.ball(H + v3(s * 0.074, -0.09, -0.022), 0.025)             # โหนกแก้ม
        M.cap(H + v3(s * 0.074, -0.09, -0.022), H + v3(s * 0.105, -0.02, -0.02), 0.013)
        M.cap(H + v3(s * 0.075, -0.01, -0.07), H + v3(s * 0.033, -0.115, -0.128), 0.017)  # กราม
        M.ball(H + v3(s * 0.077, -0.008, -0.072), 0.019)
        M.ell(H + v3(s * 0.113, 0.0, -0.005), 0.013, 0.028, 0.055)   # หู
    M.ball(H + v3(0, -0.125, -0.135), 0.023)                        # คาง
    M.cap(H + v3(0, -0.128, 0.02), H + v3(0, -0.148, -0.035), 0.011)  # สันจมูก
    M.cap(H + v3(-0.027, -0.132, -0.072), H + v3(0.027, -0.132, -0.072), 0.008)   # ริมฝีปากเหี่ยว
    M.cap(H + v3(-0.024, -0.13, -0.104), H + v3(0.024, -0.13, -0.104), 0.008)
    # ลูกบอลลบ: เบ้าตาลึก ขมับตอบ แก้มตอบ รูจมูก ปาก
    for s in (1, -1):
        M.ball(H + v3(s * 0.044, -0.128, 0.0), 0.04, neg=True)
        M.ball(H + v3(s * 0.126, -0.04, 0.025), 0.034, neg=True)
        M.ball(H + v3(s * 0.068, -0.122, -0.075), 0.027, neg=True)
        J[("EyeL" if s > 0 else "EyeR")] = H + v3(s * 0.044, -0.11, 0.0)
    M.ball(H + v3(0, -0.162, -0.05), 0.016, neg=True)
    M.ball(H + v3(0, -0.148, -0.088), 0.019, neg=True)
    J["Mouth"] = H + v3(0, -0.13, -0.088)
    J["JawPivot"] = H + v3(0, -0.005, -0.045)
    J["Chin"] = H + v3(0, -0.13, -0.14)
    J["HeadTop"] = v3(0, H.y + 0.01, cc.z + sz)

    # ---------------- แขน มือ นิ้วยาว
    for s, side in ((1, "Left"), (-1, "Right")):
        sh = v3(s * 0.335, 0.01, 3.11)
        du = v3(s * math.sin(math.radians(16)), -0.05, -math.cos(math.radians(16))).normalized()
        el = sh + du * 0.95
        df = v3(s * math.sin(math.radians(12)), -0.13, -math.cos(math.radians(12))).normalized()
        wr = el + df * 0.93
        J[side + "ClavIn"] = v3(s * 0.04, 0.0, 3.14)
        J[side + "Shoulder"], J[side + "Elbow"], J[side + "Wrist"] = sh, el, wr
        M.ball(sh, 0.034)
        M.cap(sh, el, 0.026)                                     # ต้นแขน
        M.cap(sh + du * 0.08, sh + du * 0.55, 0.033)
        M.ball(el + v3(0, 0.022, 0.01), 0.031)                   # ศอก
        M.ball(el + v3(s * 0.025, 0, 0), 0.027)
        M.ball(el + v3(-s * 0.022, 0, 0), 0.026)
        M.cap(el + v3(s * 0.012, -0.005, -0.02), wr + v3(s * 0.014, -0.008, 0), 0.018)  # กระดูกแขนท่อนล่าง 2 ชิ้น
        M.cap(el + v3(-s * 0.01, 0.015, -0.02), wr + v3(-s * 0.012, 0.01, 0), 0.016)
        M.cap(el + df * 0.06, el + df * 0.4, 0.027)
        M.ball(wr + v3(s * 0.02, 0, 0), 0.018)
        M.ball(wr + v3(-s * 0.02, 0.005, 0), 0.017)
        d = df
        w = (v3(0, 1, 0) - d * d.y).normalized()                  # ขวางฝ่ามือ (ชี้ไปหลัง)
        n = d.cross(w).normalized()
        if n.x * s > 0:
            n = -n                                                # ฝ่ามือหันเข้าหาลำตัว
        DIRS[side + "PalmN"] = n
        rot = Matrix((w, d, w.cross(d))).transposed().to_quaternion()
        M.ell(wr + d * 0.09, 0.046, 0.085, 0.016, rot=rot)        # ฝ่ามือแบน
        for k, (fname, o) in enumerate((("Index", -1.5), ("Middle", -0.5), ("Ring", 0.5), ("Pinky", 1.5))):
            kb = wr + d * 0.02 + w * o * 0.011
            kn = wr + d * 0.17 + w * o * 0.03 - d * abs(o + 0.5) * 0.006
            M.cap(kb, kn, 0.011)
            M.ball(kn, 0.0145)
            L = (0.26, 0.29, 0.27, 0.21)[k]
            fd = (d + w * o * 0.07 + n * 0.10).normalized()
            j1 = kn + fd * L * 0.55
            fd2 = (fd + n * 0.22 + w * o * 0.03).normalized()
            tip = j1 + fd2 * L * 0.45
            M.cap(kn, j1, 0.0102)
            M.ball(j1, 0.0122)
            M.cap(j1, tip, 0.0086)
            claw = tip + (fd2 + n * 0.3).normalized() * 0.03
            M.cap(tip, claw, 0.0052)
            TIPS.append((claw, 0.034))
            J[f"{side}{fname}1"], J[f"{side}{fname}2"], J[f"{side}{fname}Tip"] = kn, j1, claw
            if fname == "Middle":
                J[side + "Knuckle"] = kn
        tb = wr + d * 0.035 - w * 0.032 + n * 0.012
        td = (d * 0.75 - w * 0.45 + n * 0.35).normalized()
        t1 = tb + td * 0.10
        td2 = (td + n * 0.2).normalized()
        t2 = t1 + td2 * 0.10
        M.cap(tb, t1, 0.013)
        M.ball(t1, 0.0135)
        M.cap(t1, t2, 0.0102)
        claw = t2 + td2 * 0.028
        M.cap(t2, claw, 0.0055)
        TIPS.append((claw, 0.032))
        J[side + "Thumb1"], J[side + "Thumb2"], J[side + "ThumbTip"] = tb, t1, claw


# ================================================================ 2. ชิ้นแยก: ลิ้น ตา ผม ผ้า
class Geo:
    def __init__(self):
        self.V, self.F, self.UV = [], [], []

    def tube(self, path, rad, sides, tip=True, root_cap=False, n0=None):
        n = len(path)
        T = [(path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized() for i in range(n)]
        N = Vector(n0) if n0 is not None else T[0].orthogonal()
        N = (N - T[0] * N.dot(T[0])).normalized()
        base = len(self.V)
        acc = [0.0]
        for i in range(1, n):
            acc.append(acc[-1] + (path[i] - path[i - 1]).length)
        circ = 2 * math.pi * sum(max(r) for r in rad) / n
        for i in range(n):
            if i:
                N = (N - T[i] * N.dot(T[i])).normalized()
            B = T[i].cross(N)
            rx, ry = rad[i]
            for k in range(sides):
                a = 2 * math.pi * k / sides
                self.V.append(path[i] + N * (rx * math.cos(a)) + B * (ry * math.sin(a)))
        for i in range(n - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                self.F.append((base + i * sides + k, base + i * sides + k2, base + (i + 1) * sides + k2, base + (i + 1) * sides + k))
                u0, u1 = circ * k / sides, circ * (k + 1) / sides
                self.UV.append(((u0, acc[i]), (u1, acc[i]), (u1, acc[i + 1]), (u0, acc[i + 1])))
        if tip:
            ti = len(self.V)
            self.V.append(path[-1] + T[-1] * (sum(rad[-1]) * 0.5))
            last = base + (n - 1) * sides
            for k in range(sides):
                k2 = (k + 1) % sides
                self.F.append((last + k, last + k2, ti))
                u0, u1 = circ * k / sides, circ * (k + 1) / sides
                self.UV.append(((u0, acc[-1]), (u1, acc[-1]), ((u0 + u1) / 2, acc[-1] + 0.01)))
        if root_cap:
            ci = len(self.V)
            self.V.append(path[0] - T[0] * 0.002)
            for k in range(sides):
                k2 = (k + 1) % sides
                self.F.append((base + k2, base + k, ci))
                u0, u1 = circ * k / sides, circ * (k + 1) / sides
                self.UV.append(((u1, 0.0), (u0, 0.0), ((u0 + u1) / 2, -0.01)))

    def sphere(self, r, nu=18, nv=12):
        base = len(self.V)
        self.V.append(v3(0, 0, -r))
        for j in range(1, nv):
            th = math.pi * j / nv - math.pi / 2
            for i in range(nu):
                ph = 2 * math.pi * i / nu
                self.V.append(v3(r * math.cos(th) * math.cos(ph), r * math.cos(th) * math.sin(ph), r * math.sin(th)))
        top = len(self.V)
        self.V.append(v3(0, 0, r))
        C = 2 * math.pi * r

        def uv(i, j):
            return (C * i / nu, math.pi * r * j / nv)
        for i in range(nu):
            i2 = (i + 1) % nu
            self.F.append((base, base + 1 + i2, base + 1 + i))
            self.UV.append((uv(i + 0.5, 0), uv(i + 1, 1), uv(i, 1)))
        for j in range(nv - 2):
            r0 = base + 1 + j * nu
            r1 = r0 + nu
            for i in range(nu):
                i2 = (i + 1) % nu
                self.F.append((r0 + i, r0 + i2, r1 + i2, r1 + i))
                self.UV.append((uv(i, j + 1), uv(i + 1, j + 1), uv(i + 1, j + 2), uv(i, j + 2)))
        rl = base + 1 + (nv - 2) * nu
        for i in range(nu):
            i2 = (i + 1) % nu
            self.F.append((rl + i, rl + i2, top))
            self.UV.append((uv(i, nv - 1), uv(i + 1, nv - 1), uv(i + 0.5, nv)))

    def grid(self, P, cols, rows, wrap=False):
        """P(i, j) -> (Vector, (u, v)) ; i = คอลัมน์ 0..cols, j = แถว 0..rows"""
        base = len(self.V)
        nc = cols if wrap else cols + 1
        uvs = {}
        for j in range(rows + 1):
            for i in range(nc):
                p, uv = P(i, j)
                self.V.append(p)
                uvs[(i, j)] = uv
        for j in range(rows):
            for i in range(cols):
                i2 = (i + 1) % nc if wrap else i + 1
                self.F.append((base + j * nc + i, base + (j + 1) * nc + i, base + (j + 1) * nc + i2, base + j * nc + i2))
                uv_i2 = P(i + 1, j)[1] if wrap and i2 == 0 else uvs[(i2, j)]
                uv_i2b = P(i + 1, j + 1)[1] if wrap and i2 == 0 else uvs[(i2, j + 1)]
                self.UV.append((uvs[(i, j)], uvs[(i, j + 1)], uv_i2b, uv_i2))

    def obj(self, name, loc=None):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.V], [], [tuple(f) for f in self.F])
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", [c for f in self.UV for uv in f for c in uv])
        me.update()
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        if loc is not None:
            ob.location = loc
        return ob


def catmull(pts, n):
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    segs = len(pts) - 1
    for k in range(n):
        t = k / (n - 1) * segs
        i = min(int(t), segs - 1)
        u = t - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    return out


def build_tongue():
    """ลิ้นยาวแดงคล้ำห้อยจากปากลงถึงเอว (ลอยหน้าอก ~10 ซม.)"""
    m = J["Mouth"]
    ctrl = [m + v3(0, 0.03, 0.0), m + v3(0, -0.03, -0.005), m + v3(0, -0.075, -0.04), v3(0.006, -0.235, 3.42),
            v3(-0.01, -0.25, 3.18), v3(0.012, -0.252, 2.92), v3(-0.006, -0.245, 2.64), v3(0.008, -0.232, 2.36), v3(0.0, -0.215, 2.26)]
    path = catmull(ctrl, 44)
    rad = []
    for i, p in enumerate(path):
        s = i / (len(path) - 1)
        wid = 0.031 * (1 - 0.3 * s)
        th = 0.0105 * (1 - 0.25 * s)
        if s < 0.08:
            k = 0.55 + 0.45 * s / 0.08
            wid *= k
            th *= k
        if s > 0.9:
            k = math.sqrt(max(0.05, 1 - ((s - 0.9) / 0.1) ** 2))
            wid *= k
            th *= max(0.5, k)
        rad.append((wid, th))
    g = Geo()
    g.tube(path, rad, 12, tip=True, root_cap=True, n0=(1, 0, 0))
    # จุดแบ่งกระดูกลิ้น 6 ท่อน
    acc = [0.0]
    for i in range(1, len(path)):
        acc.append(acc[-1] + (path[i] - path[i - 1]).length)
    marks = (0.0, 0.1, 0.25, 0.42, 0.6, 0.79, 1.0)
    for k, f in enumerate(marks):
        target = f * acc[-1]
        i = min(range(len(acc)), key=lambda q: abs(acc[q] - target))
        J[f"Tongue{k}"] = path[i].copy()
    return g.obj(NAME + "_Tongue")


def build_eyes():
    obs = []
    for nm in ("EyeL", "EyeR"):
        g = Geo()
        g.sphere(EYE_R, 18, 12)
        obs.append(g.obj(NAME + "_" + nm, loc=J[nm].copy()))
    return obs


def build_hair():
    """ผมกระเซิงบางๆ เป็นกระจุกเส้นเรียว มีหนังหัวโผล่ ยาวไม่เกินบ่า"""
    rng = np.random.default_rng(11)
    cc, (ax, ay, az) = CRANIUM
    g = Geo()
    n = 0
    while n < 78:
        d = Vector(rng.normal(size=3)).normalized()
        if d.z < -0.15 or (d.y < -0.3 and d.z < 0.6) or (d.y < 0.1 and d.z < 0.05 and abs(d.x) < 0.9):
            continue
        root = cc + v3(d.x * ax, d.y * ay, d.z * az) * 0.94
        out = v3(d.x / ax, d.y / ay, d.z / az).normalized()
        L = rng.uniform(0.16, 0.42) if d.y > -0.1 else rng.uniform(0.08, 0.2)
        steps = 8
        p = root.copy()
        path = [p.copy()]
        wob = Vector(rng.normal(size=3)) * 0.35
        for k in range(1, steps + 1):
            f = k / steps
            dirv = (out * (0.9 * (1 - f) + 0.15) + v3(0, 0.05, -1) * (0.25 + 0.9 * f) + wob * (0.5 + f) + Vector(rng.normal(size=3)) * 0.25).normalized()
            p = p + dirv * (L / steps)
            q = p - cc
            e = (q.x / (ax * 1.08)) ** 2 + (q.y / (ay * 1.08)) ** 2 + (q.z / (az * 1.08)) ** 2
            if e < 1.0:
                p = cc + q / math.sqrt(e)
            path.append(p.copy())
        r0 = rng.uniform(0.007, 0.012)
        rad = [(r0 * (1 - 0.82 * (i / steps)) * 1.35, r0 * (1 - 0.82 * (i / steps)) * 0.75) for i in range(steps + 1)]
        g.tube(path, rad, 5, tip=True, n0=out)
        n += 1
    return g.obj(NAME + "_Hair")


CLOTH_TOP = 2.07


def build_cloth():
    """ผ้าขาดๆ พันสะโพก: แถบคาดเอวต่อเนื่อง + ชายผ้าขาดเป็นริ้ว 14 ริ้ว (ริ้วซ้าย/ขวาตามขาแต่ละข้าง ไม่ทะลุขาตอนก้าว)"""
    rng = np.random.default_rng(5)
    cy = 0.012

    def ring(theta, z):
        dz = max(0.0, 2.0 - z)
        rx, ry = 0.24 + dz * 0.17, 0.152 + dz * 0.15
        fold = 1 + 0.03 * math.sin(theta * 14 + 1.3) + 0.018 * math.sin(theta * 5)
        return v3(rx * fold * math.cos(theta), cy + ry * fold * math.sin(theta), z)

    g = Geo()
    C = 72
    zs = [CLOTH_TOP - k * 0.04 for k in range(6)]   # 2.07 -> 1.87
    g.grid(lambda i, j: (ring(2 * math.pi * i / C, zs[j]) + v3(0, 0, 0.004 * math.sin(i * 1.7)), (0.2 * 2 * math.pi * i / C, zs[0] - zs[j])), C, 5, wrap=True)
    NS = 14
    for k in range(NS):
        a0 = -math.pi / 2 + 2 * math.pi * k / NS + 0.025
        a1 = -math.pi / 2 + 2 * math.pi * (k + 1) / NS - 0.025
        mid = (a0 + a1) / 2
        hem = 1.49 + 0.13 * abs(math.sin(mid)) + rng.uniform(-0.05, 0.05)
        rows, cols = 9, 4
        jag = [rng.uniform(-0.06, 0.03) for _ in range(cols + 1)]
        top = 1.91

        def P(i, j, a0=a0, a1=a1, hem=hem, jag=jag, top=top):
            f = j / rows
            shrink = 0.16 * f * f
            a = a0 + (a1 - a0) * (shrink + (1 - 2 * shrink) * i / cols)
            z = top + (hem - top) * f + (jag[i] * f ** 3)
            p = ring(a, z) * 0.985 + v3(0, cy * 0.015, 0)
            return p, (0.2 * a, top - z)
        g.grid(P, cols, rows)
    ob = g.obj(NAME + "_Cloth")
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.009
    sol.offset = 0.0
    apply_mods(ob)
    return ob


# ================================================================ 3. ตัวช่วย mesh
def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    me.name = ob.name
    bpy.data.meshes.remove(old)


def tris(ob):
    me = ob.data
    me.calc_loop_triangles()
    return len(me.loop_triangles)


def coords(ob):
    a = np.empty(len(ob.data.vertices) * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)


def bbox(objs, world=True):
    mn, mx = np.full(3, 1e9), np.full(3, -1e9)
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        a = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", a)
        a = a.reshape(-1, 3)
        M = np.array(o.matrix_world)
        a = a @ M[:3, :3].T + M[:3, 3]
        ev.to_mesh_clear()
        mn, mx = np.minimum(mn, a.min(0)), np.maximum(mx, a.max(0))
    return mn, mx


def scale_all(objs, k):
    for o in objs:
        a = coords(o) * k
        o.data.vertices.foreach_set("co", a.ravel())
        o.data.update()
        o.location = o.location * k
    for key in J:
        J[key] = J[key] * k
    for i, (p, r) in enumerate(TIPS):
        TIPS[i] = (p * k, r * k)


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


# ================================================================ 4. วัสดุ procedural + bake
class G:
    def __init__(self, mat):
        mat.use_nodes = True
        self.t = mat.node_tree
        self.t.nodes.clear()
        self.out = self.node("ShaderNodeOutputMaterial")

    def node(self, typ, ins=(), **props):
        n = self.t.nodes.new(typ)
        for k, v in props.items():
            setattr(n, k, v)
        for k, v in ins:
            self.set(n.inputs[k], v)
        return n

    def set(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.t.links.new(v, sock)
        elif isinstance(v, bpy.types.Node):
            self.t.links.new(v.outputs[0], sock)
        else:
            sock.default_value = v

    def math(self, op, a, b=0.0):
        return self.node("ShaderNodeMath", [(0, a), (1, b)], operation=op).outputs[0]

    def vm(self, op, a, b):
        return self.node("ShaderNodeVectorMath", [(0, a), (1, b)], operation=op).outputs[0]

    def vs(self, a, f):
        return self.node("ShaderNodeVectorMath", [(0, a), (3, f)], operation="SCALE").outputs[0]

    def lerp(self, a, b, f):
        return self.vm("ADD", a, self.vs(self.vm("SUBTRACT", b, a), f))

    def ss(self, x, e0, e1):
        return self.node("ShaderNodeMapRange", [(0, x), (1, e0), (2, e1), (3, 0.0), (4, 1.0)], interpolation_type="SMOOTHSTEP", clamp=True).outputs[0]

    def noise(self, vec, scale, detail=4.0):
        return self.node("ShaderNodeTexNoise", [("Vector", vec), ("Scale", scale), ("Detail", detail)])

    def edge(self, vec, scale):
        return self.node("ShaderNodeTexVoronoi", [("Vector", vec), ("Scale", scale)], feature="DISTANCE_TO_EDGE").outputs["Distance"]

    def ao(self, dist, local):
        return self.node("ShaderNodeAmbientOcclusion", [("Distance", dist)], samples=16, only_local=local).outputs["AO"]

    def finish(self, col, rough, height, bump):
        """ต่อ Emission (สำหรับ bake สี/roughness) + Principled พร้อม bump (สำหรับ bake normal)"""
        self.col, self.rough = col, rough
        self.emis = self.node("ShaderNodeEmission", [("Strength", 1.0)])
        self.bsdf = self.node("ShaderNodeBsdfPrincipled", [("Base Color", (0.5, 0.5, 0.5, 1.0))])
        if height is not None:
            b = self.node("ShaderNodeBump", [("Strength", bump), ("Distance", 0.002), ("Height", height)])
            self.t.links.new(b.outputs[0], self.bsdf.inputs["Normal"])

    def mode(self, m):
        for l in list(self.out.inputs[0].links):
            self.t.links.remove(l)
        for l in list(self.emis.inputs["Color"].links):
            self.t.links.remove(l)
        if m == "Normal":
            self.t.links.new(self.bsdf.outputs[0], self.out.inputs[0])
        else:
            self.set(self.emis.inputs["Color"], self.col if m == "Color" else self.node("ShaderNodeCombineXYZ", [(0, self.rough), (1, self.rough), (2, self.rough)]).outputs[0])
            self.t.links.new(self.emis.outputs[0], self.out.inputs[0])


SKIN = (96, 86, 72)          # เทาอมน้ำตาล แห้งเหี่ยว
SKIN_DARK = (58, 50, 42)
SKIN_SICK = (82, 84, 66)     # ด่างเทาอมเขียวเน่า
SKIN_BONE = (138, 128, 108)  # ฝุ่นซีดบนปุ่มกระดูก
SPOT = (44, 34, 30)
CRACK = (24, 18, 15)
NAIL = (92, 74, 40)
SOCKET = (8, 5, 5)
MOUTH = (30, 6, 8)


def skin_graph(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    n_lo = g.noise(co, 2.2, 3).outputs["Fac"]
    n_mid = g.noise(co, 8.0, 5).outputs["Fac"]
    n_hi = g.noise(co, 45.0, 3).outputs["Fac"]
    warp = g.vm("ADD", co, g.vs(g.vm("SUBTRACT", g.noise(co, 5.0, 2).outputs["Color"], (0.5, 0.5, 0.5)), 0.05))
    c1 = g.math("SUBTRACT", 1.0, g.ss(g.edge(warp, 15.0), 0.0, 0.035))
    c2 = g.math("SUBTRACT", 1.0, g.ss(g.edge(warp, 52.0), 0.0, 0.05))
    crack = g.math("MAXIMUM", c1, g.math("MULTIPLY", c2, 0.55))
    col = g.lerp(lin(SKIN_DARK), lin(SKIN), g.ss(n_lo, 0.3, 0.7))
    col = g.lerp(col, lin(SKIN_SICK), g.math("MULTIPLY", g.ss(n_mid, 0.55, 0.72), 0.55))
    pt = g.node("ShaderNodeNewGeometry").outputs["Pointiness"]
    col = g.lerp(col, lin(SKIN_BONE), g.math("MULTIPLY", g.ss(pt, 0.5, 0.58), 0.75))
    col = g.lerp(col, lin(SPOT), g.math("MULTIPLY", g.ss(n_hi, 0.6, 0.68), 0.6))
    col = g.lerp(col, lin(CRACK), g.math("MULTIPLY", crack, 0.85))
    col = g.vs(col, g.math("ADD", 0.1, g.math("MULTIPLY", g.ss(g.ao(0.07, True), 0.15, 1.0), 0.9)))
    sep = g.node("ShaderNodeSeparateXYZ", [(0, g.node("ShaderNodeAttribute", attribute_name="Masks").outputs["Color"])])
    nail, sock, mouth = sep.outputs[0], sep.outputs[1], sep.outputs[2]
    col = g.lerp(col, lin(NAIL), g.math("MULTIPLY", nail, 0.9))
    col = g.lerp(col, lin(SOCKET), sock)
    col = g.lerp(col, lin(MOUTH), mouth)
    rough = g.math("ADD", 0.8, g.math("MULTIPLY", crack, 0.15))
    rough = g.math("SUBTRACT", rough, g.math("MULTIPLY", nail, 0.4))
    rough = g.math("SUBTRACT", rough, g.math("MULTIPLY", sock, 0.5))
    rough = g.math("SUBTRACT", rough, g.math("MULTIPLY", mouth, 0.5))
    rough = g.math("ADD", rough, g.math("MULTIPLY", g.math("SUBTRACT", n_mid, 0.5), 0.1))
    height = g.math("SUBTRACT", g.math("ADD", g.math("MULTIPLY", n_mid, 0.4), g.math("MULTIPLY", n_hi, 0.2)), g.math("MULTIPLY", crack, 0.9))
    g.finish(col, rough, height, 0.6)


def tongue_graph(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    n1 = g.noise(co, 14.0, 4).outputs["Fac"]
    n2 = g.noise(co, 140.0, 2).outputs["Fac"]
    vein = g.math("SUBTRACT", 1.0, g.ss(g.edge(co, 22.0), 0.0, 0.03))
    col = g.lerp(lin((86, 16, 20)), lin((138, 40, 44)), g.ss(n1, 0.35, 0.7))
    col = g.lerp(col, lin((40, 8, 12)), g.math("MULTIPLY", vein, 0.7))
    col = g.lerp(col, lin((150, 70, 62)), g.math("MULTIPLY", g.ss(n2, 0.6, 0.75), 0.35))
    col = g.vs(col, g.math("ADD", 0.25, g.math("MULTIPLY", g.ao(0.05, False), 0.75)))
    rough = g.math("ADD", 0.22, g.math("MULTIPLY", n2, 0.2))
    height = g.math("ADD", g.math("MULTIPLY", n2, 0.6), g.math("MULTIPLY", vein, -0.4))
    g.finish(col, rough, height, 0.5)


def eye_graph(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    f = g.node("ShaderNodeVectorMath", [(0, g.node("ShaderNodeVectorMath", [(0, co)], operation="NORMALIZE").outputs[0]), (1, (0.0, -1.0, 0.0))], operation="DOT_PRODUCT").outputs["Value"]
    vein = g.math("SUBTRACT", 1.0, g.ss(g.edge(co, 260.0), 0.0, 0.06))
    col = g.lerp(lin((150, 52, 40)), lin((196, 180, 136)), g.ss(f, 0.2, 0.8))
    col = g.lerp(col, lin((120, 24, 22)), g.math("MULTIPLY", vein, g.math("SUBTRACT", 1.0, g.ss(f, 0.6, 0.9))))
    col = g.lerp(col, lin((112, 110, 92)), g.ss(f, 0.955, 0.965))      # ม่านตาขุ่น
    col = g.lerp(col, lin((6, 4, 4)), g.ss(f, 0.986, 0.99))             # รูม่านตาเล็กเท่ารูเข็ม
    rough = g.math("ADD", 0.08, g.math("MULTIPLY", vein, 0.1))
    g.finish(col, rough, None, 0.0)


def hair_graph(g):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    n1 = g.noise(co, 30.0, 3).outputs["Fac"]
    col = g.lerp(lin((20, 18, 17)), lin((62, 56, 48)), g.ss(n1, 0.45, 0.8))
    col = g.vs(col, g.math("ADD", 0.3, g.math("MULTIPLY", g.ao(0.04, False), 0.7)))
    rough = g.math("ADD", 0.55, g.math("MULTIPLY", n1, 0.2))
    g.finish(col, rough, g.noise(co, 200.0, 2).outputs["Fac"], 0.3)


def cloth_graph(g, k):
    co = g.node("ShaderNodeTexCoord").outputs["Object"]
    z = g.node("ShaderNodeSeparateXYZ", [(0, co)]).outputs[2]
    n1 = g.noise(co, 6.0, 4).outputs["Fac"]
    n2 = g.noise(co, 30.0, 3).outputs["Fac"]
    weave = g.noise(co, 420.0, 1).outputs["Fac"]
    col = g.lerp(lin((132, 86, 90)), lin((158, 112, 112)), g.ss(n1, 0.35, 0.65))     # ชมพูซีดเก่า
    col = g.lerp(col, lin((84, 64, 52)), g.math("MULTIPLY", g.ss(n2, 0.5, 0.75), 0.6))  # คราบดิน
    col = g.lerp(col, lin((52, 40, 34)), g.math("MULTIPLY", g.ss(z, 1.78 * k, 1.5 * k), 0.75))  # ชายผ้าเปื้อนโคลน
    col = g.vs(col, g.math("ADD", 0.2, g.math("MULTIPLY", g.ss(g.ao(0.06, False), 0.1, 1.0), 0.8)))
    col = g.vs(col, g.math("ADD", 0.9, g.math("MULTIPLY", weave, 0.2)))
    rough = g.math("ADD", 0.88, g.math("MULTIPLY", weave, 0.1))
    g.finish(col, rough, g.math("ADD", weave, g.math("MULTIPLY", n2, 0.5)), 0.35)


def set_masks(hi):
    P = coords(hi)
    nail = np.zeros(len(P))
    for p, r in TIPS:
        d = np.linalg.norm(P - np.array(p), axis=1)
        nail = np.maximum(nail, 1 - smoothstep(r * 0.55, r, d))
    sock = np.zeros(len(P))
    for e in ("EyeL", "EyeR"):
        d = np.linalg.norm(P - np.array(J[e]), axis=1)
        sock = np.maximum(sock, 1 - smoothstep(EYE_R * 1.45, EYE_R * 2.3, d))
    d = np.linalg.norm(P - np.array(J["Mouth"]), axis=1)
    mouth = 1 - smoothstep(0.02, 0.034, d)
    a = np.stack([nail, sock, mouth, np.ones(len(P))], 1).astype(np.float32)
    at = hi.data.color_attributes.new("Masks", "FLOAT_COLOR", "POINT")
    at.data.foreach_set("color", a.ravel())


def uv_layout(body, parts, density):
    objs = [body] + parts
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    # ตัว: smart project · ชิ้นแยกมี UV ของตัวเองแล้ว (หน่วยเมตร)
    select_only([body])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(62), island_margin=0.0, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    select_only(objs, body)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in parts:  # ความละเอียดต่อชิ้น เทียบกับตัว (ตา x2.2 ให้รูม่านตาคม, ผมครึ่งเดียว)
        k = density.get(o.name, 1.0)
        uv = np.empty(len(o.data.loops) * 2)
        o.data.uv_layers[0].data.foreach_get("uv", uv)
        o.data.uv_layers[0].data.foreach_set("uv", uv * k)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_textures(hi, body, parts):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 24
    scn.render.bake.margin = 3
    imgs = {}
    for k, fill, nc in (("Color", (0.1, 0.08, 0.07, 1), False), ("Roughness", (0.85, 0.85, 0.85, 1), True), ("Normal", (0.5, 0.5, 1.0, 1), True)):
        im = bpy.data.images.new(f"{NAME}_{k}", TEX, TEX, alpha=False)
        if nc:
            im.colorspace_settings.name = "Non-Color"
        im.generated_color = fill
        imgs[k] = im
    graphs, targets = [], []

    def mk(obj, fn, *args):
        mat = bpy.data.materials.new(obj.name + "_Bake")
        g = G(mat)
        fn(g, *args)
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        graphs.append(g)
        return g
    mk(hi, skin_graph)
    gm = {"Tongue": tongue_graph, "EyeL": eye_graph, "EyeR": eye_graph, "Hair": hair_graph}
    for o in parts:
        key = o.name.split("_", 1)[1]
        g = mk(o, cloth_graph, HEIGHT / 3.92) if key == "Cloth" else mk(o, gm[key])
        tn = g.node("ShaderNodeTexImage")
        g.t.nodes.active = tn
        targets.append(tn)
    lo_mat = bpy.data.materials.new(NAME + "_BakeTarget")
    lo_mat.use_nodes = True
    tn = lo_mat.node_tree.nodes.new("ShaderNodeTexImage")
    lo_mat.node_tree.nodes.active = tn
    targets.append(tn)
    body.data.materials.clear()
    body.data.materials.append(lo_mat)
    files = {}
    for m, btype in (("Color", "EMIT"), ("Roughness", "EMIT"), ("Normal", "NORMAL")):
        for g in graphs:
            g.mode(m)
        for t in targets:
            t.image = imgs[m]
        scn.cycles.samples = 24 if m == "Color" else 4
        t1 = time.time()
        select_only(parts)
        bpy.ops.object.bake(type=btype, use_clear=False, margin=3, normal_space="TANGENT")
        select_only([hi, body], body)
        bpy.ops.object.bake(type=btype, use_selected_to_active=True, cage_extrusion=0.012, max_ray_distance=0.06,
                            use_clear=False, margin=3, normal_space="TANGENT")
        path = os.path.join(ROOT, f"{NAME}_{m}.png")
        im = imgs[m]
        im.filepath_raw = path
        im.file_format = "PNG"
        im.save()
        files[m] = path
        log(f"  bake {m}: {time.time() - t1:.0f}s -> {os.path.basename(path)}")
    met = bpy.data.images.new(f"{NAME}_Metalness", TEX, TEX, alpha=False)
    met.colorspace_settings.name = "Non-Color"
    met.generated_color = (0, 0, 0, 1)
    met.filepath_raw = os.path.join(ROOT, f"{NAME}_Metalness.png")
    met.file_format = "PNG"
    met.save()
    files["Metalness"] = met.filepath_raw
    return files


def final_material(files):
    mat = bpy.data.materials.new(NAME + "_Mat")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])

    def tex(key, nc):
        im = bpy.data.images.load(files[key], check_existing=False)
        if nc:
            im.colorspace_settings.name = "Non-Color"
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = im
        return n
    tc = tex("Color", False)
    nt.links.new(tc.outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(tex("Roughness", True).outputs[0], bsdf.inputs["Roughness"])
    nt.links.new(tex("Metalness", True).outputs[0], bsdf.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex("Normal", True).outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
    nt.nodes.active = tc
    return mat


# ================================================================ 5. rig
BONES = []  # (name, head, tail, parent, up, radius, deform)


def bone_specs():
    BONES.clear()

    def add(n, h, t, p, up, r, deform=True):
        BONES.append((n, Vector(h), Vector(t), p, Vector(up), r, deform))
    k = HEIGHT / 3.92
    add("Root", (0, 0, 0), (0, 0, 0.3 * k), None, (0, -1, 0), 1, False)
    add("Hips", J["Pelvis"], v3(0, 0.03, 2.22) * k, "Root", (0, -1, 0), 0.17 * k)
    add("Spine", v3(0, 0.03, 2.22) * k, v3(0, 0.03, 2.55) * k, "Hips", (0, -1, 0), 0.11 * k)
    add("Chest", v3(0, 0.03, 2.55) * k, J["NeckBase"], "Spine", (0, -1, 0), 0.16 * k)
    add("Neck", J["NeckBase"], J["NeckTop"], "Chest", (0, -1, 0), 0.045 * k)
    add("Head", J["NeckTop"], J["HeadTop"], "Neck", (0, -1, 0), 0.11 * k)
    add("Jaw", J["JawPivot"], J["Chin"], "Head", (0, 0, -1), 0.05 * k)
    prev = "Jaw"
    for i in range(1, 7):
        add(f"Tongue{i}", J[f"Tongue{i - 1}"], J[f"Tongue{i}"], prev, (0, -1, 0), 0.03 * k)
        prev = f"Tongue{i}"
    for side in ("Left", "Right"):
        n = DIRS[side + "PalmN"]
        add(side + "Clavicle", J[side + "ClavIn"], J[side + "Shoulder"], "Chest", (0, 0, 1), 0.05 * k)
        add(side + "UpperArm", J[side + "Shoulder"], J[side + "Elbow"], side + "Clavicle", (0, -1, 0), 0.04 * k)
        add(side + "LowerArm", J[side + "Elbow"], J[side + "Wrist"], side + "UpperArm", (0, -1, 0), 0.034 * k)
        add(side + "Hand", J[side + "Wrist"], J[side + "Knuckle"], side + "LowerArm", n, 0.035 * k)
        for f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
            add(f"{side}{f}1", J[f"{side}{f}1"], J[f"{side}{f}2"], side + "Hand", n, 0.015 * k)
            add(f"{side}{f}2", J[f"{side}{f}2"], J[f"{side}{f}Tip"], f"{side}{f}1", n, 0.012 * k)
        add(side + "UpperLeg", J[side + "Hip"], J[side + "Knee"], "Hips", (0, -1, 0), 0.055 * k)
        add(side + "LowerLeg", J[side + "Knee"], J[side + "Ankle"], side + "UpperLeg", (0, -1, 0), 0.042 * k)
        add(side + "Foot", J[side + "Ankle"], J[side + "Ball"], side + "LowerLeg", (0, 0, 1), 0.045 * k)
        add(side + "Toe", J[side + "Ball"], J[side + "ToeTip"], side + "Foot", (0, 0, 1), 0.025 * k)


def build_armature():
    data = bpy.data.armatures.new(NAME + "Rig")
    arm = bpy.data.objects.new(NAME + "Rig", data)
    bpy.context.scene.collection.objects.link(arm)
    select_only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    for n, h, t, p, up, r, deform in BONES:
        b = eb.new(n)
        b.head, b.tail = h, t
        b.align_roll(up)
        b.use_deform = deform
        if p:
            b.parent = eb[p]
            b.use_connect = (eb[p].tail - h).length < 1e-5
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def seg_dist(P, a, b):
    a, b = np.array(a), np.array(b)
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def auto_weights(P, names):
    """น้ำหนักตามระยะถึงกระดูก (หารด้วยความหนาเนื้อของกระดูกนั้น) ผสมเฉพาะกับกระดูกพ่อ/ลูก ไม่เกิน 4 ชิ้น"""
    spec = {b[0]: b for b in BONES}
    D = np.stack([seg_dist(P, spec[n][1], spec[n][2]) / spec[n][5] for n in names], 1)
    near = D.argmin(1)
    W = np.zeros_like(D)
    for i, n in enumerate(names):
        cand = [i] + [j for j, m in enumerate(names) if spec[m][3] == n or spec[n][3] == m]
        mask = near == i
        if not mask.any():
            continue
        sub = D[mask][:, cand]
        w = np.exp(-(sub - sub.min(1, keepdims=True)) / 0.2)
        w[sub - sub.min(1, keepdims=True) > 0.7] = 0
        Wm = np.zeros((mask.sum(), len(names)))
        Wm[:, cand] = w
        W[mask] = Wm
    return W


def assign(ob, names, W):
    order = np.argsort(-W, 1)[:, :4]
    groups = {n: ob.vertex_groups.get(n) or ob.vertex_groups.new(name=n) for n in names}
    for v in range(len(W)):
        idx = [j for j in order[v] if W[v, j] > 1e-3]
        tot = sum(W[v, j] for j in idx)
        for j in idx:
            groups[names[j]].add([v], float(W[v, j] / tot), "REPLACE")


def skin(arm, body, tongue, hair, cloth, eyes):
    k = HEIGHT / 3.92
    names = [b[0] for b in BONES if b[6] and not b[0].startswith("Tongue") and b[0] != "Jaw"]
    P = coords(body)
    W = auto_weights(P, names)
    # กราม: ส่วนหน้าล่างของหัวใต้ระดับปาก
    jaw = smoothstep(J["Mouth"].z + 0.01 * k, J["Mouth"].z - 0.022 * k, P[:, 2]) * smoothstep(J["JawPivot"].y + 0.02 * k, J["JawPivot"].y - 0.04 * k, P[:, 1])
    jaw *= smoothstep(J["NeckTop"].z - 0.01 * k, J["NeckTop"].z + 0.03 * k, P[:, 2]) * (np.abs(P[:, 0]) < 0.11 * k)
    hi = names.index("Head")
    names2 = names + ["Jaw"]
    W2 = np.zeros((len(P), len(names2)))
    W2[:, :len(names)] = W
    W2[:, -1] = W[:, hi] * jaw
    W2[:, hi] = W[:, hi] * (1 - jaw)
    assign(body, names2, W2)
    tn = [f"Tongue{i}" for i in range(1, 7)]
    assign(tongue, tn, auto_weights(coords(tongue), tn))
    for o in [hair] + eyes:
        g = o.vertex_groups.new(name="Head")
        g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
    # ผ้า: ริ้วผ้าข้างซ้าย/ขวาตามต้นขาข้างนั้น มากขึ้นเรื่อยๆ ไปทางชาย
    C = coords(cloth)
    t = smoothstep(1.92 * k, 1.55 * k, C[:, 2])
    side = np.clip(np.abs(C[:, 0]) / (0.09 * k), 0.35, 1.0)
    wl = t * side * (C[:, 0] > 0) * 0.85
    wr = t * side * (C[:, 0] <= 0) * 0.85
    assign(cloth, ["Hips", "LeftUpperLeg", "RightUpperLeg"], np.stack([1 - wl - wr, wl, wr], 1))
    for o in (body, tongue, hair, cloth, *eyes):
        o.parent = arm
        m = o.modifiers.new("Armature", "ARMATURE")
        m.object = arm
    W_all = W2
    return int((W_all > 1e-3).sum(1).max()), int(((W_all > 1e-3).sum(1) == 0).sum())


# ================================================================ 6. ท่า (FK + IK ขาแบบวิเคราะห์)
def qx(d):
    return Quaternion((1, 0, 0), math.radians(d))


def qy(d):
    return Quaternion((0, 1, 0), math.radians(d))


def qz(d):
    return Quaternion((0, 0, 1), math.radians(d))


FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


class Poser:
    def __init__(self, arm):
        self.arm = arm
        self.rest = {b.name: b.matrix_local.to_quaternion() for b in arm.data.bones}
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}
        self.order = [b.name for b in arm.data.bones]  # พ่อมาก่อนลูกเสมอ
        self.last = {}
        k = HEIGHT / 3.92
        self.k = k
        self.L1 = (J["LeftKnee"] - J["LeftHip"]).length
        self.L2 = (J["LeftAnkle"] - J["LeftKnee"]).length
        self.ball_rel = J["LeftAnkle"] - J["LeftBall"]

    def leg(self, P, side, hips_loc, ankle, pitch=0.0):
        hip = J[side + "Hip"] + hips_loc
        dy, dz = ankle.y - hip.y, ankle.z - hip.z
        d = min(math.hypot(dy, dz), (self.L1 + self.L2) * 0.9995)
        phi = math.atan2(dy, -dz)
        beta = math.acos(max(-1, min(1, (self.L1 ** 2 + d * d - self.L2 ** 2) / (2 * self.L1 * d))))
        gam = math.acos(max(-1, min(1, (self.L2 ** 2 + d * d - self.L1 ** 2) / (2 * self.L2 * d))))
        a1, ash = phi - beta, phi + gam
        P[side + "UpperLeg"] = Quaternion((1, 0, 0), a1)
        P[side + "LowerLeg"] = Quaternion((1, 0, 0), ash - a1)
        P[side + "Foot"] = Quaternion((1, 0, 0), math.radians(pitch) - ash)

    def ankle_from_ball(self, ball, pitch):
        r = self.ball_rel
        a = math.radians(pitch)
        return ball + v3(r.x, r.y * math.cos(a) - r.z * math.sin(a), r.y * math.sin(a) + r.z * math.cos(a))

    def key(self, frame, P, PL, hips_loc):
        for n in self.order:
            pb = self.arm.pose.bones[n]
            if n in PL:
                q = PL[n].copy()
            else:
                r = self.rest[n]
                q = r.inverted() @ P.get(n, Quaternion()) @ r
            if n in self.last:
                q.make_compatible(self.last[n])
            self.last[n] = q.copy()
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=frame, group=n)
        hb = self.arm.pose.bones["Hips"]
        hb.location = self.rest["Hips"].inverted() @ hips_loc
        hb.keyframe_insert("location", frame=frame, group="Hips")

    def delta(self, P, name):
        chain = []
        n = name
        while n:
            chain.append(n)
            n = self.parent[n]
        D = Quaternion()
        for n in reversed(chain):
            D = D @ P.get(n, Quaternion())
        return D


def base_pose(P, PL, t, curl=18.0, arms_in=9.0, stoop=1.0):
    """ท่ายืนพื้นฐาน: หลังค่อม คอยื่น เงยหน้า แขนห้อยแนบลำตัว ศอกงอนิด นิ้วงอนิด"""
    P["Spine"] = qx(6 * stoop)
    P["Chest"] = qx(5 * stoop)
    P["Neck"] = qx(14 * stoop)
    P["Head"] = qx(-16 * stoop)
    for side, s in (("Left", 1), ("Right", -1)):
        P[side + "UpperArm"] = qx(-3) @ qy(s * arms_in)
        P[side + "LowerArm"] = qx(-12)
        P[side + "Hand"] = qx(-6)
        for i, f in enumerate(FINGERS):
            c = curl * (0.6 if f == "Thumb" else 1.0)
            PL[f"{side}{f}1"] = qx(c)
            PL[f"{side}{f}2"] = qx(c * 1.2)


def tongue_pose(ps, P, sway_side, sway_fb, comp=0.85):
    D = ps.delta(P, "Jaw")
    P["Tongue1"] = Quaternion().slerp(D.inverted(), comp) @ qy(sway_side[0]) @ qx(sway_fb[0])
    for i in range(2, 7):
        P[f"Tongue{i}"] = qy(sway_side[i - 1]) @ qx(sway_fb[i - 1])


def pose_idle(ps, t):
    P, PL = {}, {}
    k = ps.k
    base_pose(P, PL, t)
    tau = 2 * math.pi
    breath = math.sin(tau * 2 * t)
    P["Chest"] = P["Chest"] @ qx(-1.5 * breath)
    P["Spine"] = P["Spine"] @ qz(2 * math.sin(tau * t))
    # หัวเอียงช้าๆ แล้วกระตุกหันขวับครั้งหนึ่ง (เฟรม ~66-80)
    tw = sstep(0.55, 0.575, t) * (1 - sstep(0.6, 0.7, t))
    P["Head"] = P["Head"] @ qy(6 * math.sin(tau * t + 1.0)) @ qz(16 * tw) @ qx(-6 * tw)
    P["Jaw"] = qx(3 + 4 * tw * abs(math.sin(tau * 12 * t)))
    for side, s, ph in (("Left", 1, 0.0), ("Right", -1, 1.7)):
        P[side + "UpperArm"] = qx(-3 + 2 * math.sin(tau * t + ph)) @ qy(s * 9)
        for i, f in enumerate(FINGERS):
            c = 18 + 12 * math.sin(tau * t * 2 + i * 0.7 + ph)   # นิ้วยาวขยับเป็นคลื่นช้าๆ
            PL[f"{side}{f}1"] = qx(c * (0.6 if f == "Thumb" else 1.0))
            PL[f"{side}{f}2"] = qx(c * 1.3)
    hips = v3(0.015 * k * math.sin(tau * t), 0, -0.045 * k + 0.006 * k * breath)
    P["Hips"] = qy(-1.2 * math.sin(tau * t))
    tongue_pose(ps, P, [2.5 * math.sin(tau * t - i * 0.5) + 6 * tw * math.sin(tau * 6 * t - i) for i in range(6)],
                [1.5 * math.sin(tau * 2 * t - i * 0.4) for i in range(6)])
    for side in ("Left", "Right"):
        ps.leg(P, side, hips, J[side + "Ankle"])
    return P, PL, hips


WALK_STRIDE = 0.9   # เมตร ต่อก้าว (เท้าไถลหลัง 0.9 m ระหว่างยืน) รอบละ 3.2 วิ = เดินช้ามาก ~0.56 m/s = 2.0 studs/s
WALK_FRAMES = 96


def pose_walk(ps, t):
    P, PL = {}, {}
    k = ps.k
    base_pose(P, PL, t, curl=22, arms_in=8, stoop=1.4)
    tau = 2 * math.pi
    S = WALK_STRIDE * k
    SF = 0.62
    hips = v3(0.03 * k * math.sin(tau * t), 0.0, (-0.115 - 0.03 * math.cos(2 * tau * t)) * k)
    yaw = 6 * math.sin(tau * t)
    P["Hips"] = qz(yaw) @ qy(3 * math.sin(tau * t))
    for side, ph in (("Left", 0.0), ("Right", 0.5)):
        p = (t + ph) % 1.0
        x0 = J[side + "Ball"]
        if p < SF:
            u = p / SF
            pitch = 28 * sstep(0.72, 1.0, u)
            ball = v3(x0.x, -S / 2 + S * u + x0.y, x0.z)
            ank = ps.ankle_from_ball(ball, pitch)
            ps.leg(P, side, hips, ank, pitch)
            P[side + "Toe"] = qx(-pitch)
        else:
            u = (p - SF) / (1 - SF)
            e = sstep(0.0, 1.0, u)
            pitch = 28 * (1 - sstep(0.0, 0.45, u)) - 12 * math.sin(math.pi * min(1, u * 1.3)) * (1 - u)
            ank = v3(J[side + "Ankle"].x, S / 2 - S * e + J[side + "Ankle"].y, J[side + "Ankle"].z + 0.2 * k * math.sin(math.pi * u))
            if u < 0.25:   # ต่อจากท่าเขย่งปลายเท้าให้ข้อเท้าไม่กระโดด
                a0 = ps.ankle_from_ball(v3(x0.x, S / 2 + x0.y, x0.z), 28)
                ank = a0.lerp(ank, sstep(0.0, 0.25, u))
            ps.leg(P, side, hips, ank, pitch)
            P[side + "Toe"] = qx(-8 * math.sin(math.pi * u))
    P["Spine"] = P["Spine"] @ qz(-yaw * 0.5)
    P["Chest"] = P["Chest"] @ qz(-yaw * 0.9) @ qx(1.5 * math.sin(2 * tau * t))
    P["Head"] = P["Head"] @ qx(3 * math.sin(2 * tau * t + 0.6)) @ qz(yaw * 0.8 + 4 * math.sin(tau * t * 0.5))
    P["Jaw"] = qx(5)
    for side, s, ph in (("Left", 1, 0.0), ("Right", -1, 0.5)):
        sw = 16 * math.cos(tau * (t + ph - 0.1))          # แขนยาวแกว่งช้ากว่าขา (ห้อยถ่วง)
        P[side + "UpperArm"] = qx(sw) @ qy(s * 8)
        P[side + "LowerArm"] = qx(-14 - 10 * (0.5 + 0.5 * math.sin(tau * (t + ph))))
        P[side + "Hand"] = qx(-8 + 8 * math.cos(tau * (t + ph - 0.25)))
    tongue_pose(ps, P, [4 * math.sin(tau * t - i * 0.55) for i in range(6)],
                [3 * math.sin(2 * tau * t - 0.8 - i * 0.5) for i in range(6)])
    return P, PL, hips


SHRIEK_FRAMES = 90


def pose_shriek(ps, t):
    P, PL = {}, {}
    k = ps.k
    f = t * SHRIEK_FRAMES
    base_pose(P, PL, t)
    a = sstep(0, 10, f) * (1 - sstep(10, 16, f))                    # ย่อตัวเตรียม
    s = sstep(12, 21, f) * (1 - sstep(62, 84, f))                   # กรีดร้อง
    tau = 2 * math.pi

    def tr(seed, amp):  # สั่นเทิ้ม
        return amp * s * (math.sin(f * 2.9 + seed) * 0.6 + math.sin(f * 5.3 + seed * 2.1) * 0.4)
    P["Spine"] = P["Spine"] @ qx(-7 * s + 5 * a)
    P["Chest"] = P["Chest"] @ qx(-12 * s + 6 * a + tr(1, 2.0)) @ qz(tr(2, 1.5))
    P["Neck"] = P["Neck"] @ qx(-16 * s + 8 * a)
    P["Head"] = P["Head"] @ qx(-34 * s + 12 * a + tr(3, 3.5)) @ qy(tr(4, 4))
    P["Jaw"] = qx(3 + 30 * s + tr(5, 4))
    for side, sg in (("Left", 1), ("Right", -1)):
        P[side + "Clavicle"] = qy(-sg * 10 * s)
        P[side + "UpperArm"] = qx(-28 * s - 6 * a + tr(6 + sg, 3)) @ qy(sg * (9 + 6 * a - 46 * s))
        P[side + "LowerArm"] = qx(-12 - 38 * s + tr(8 + sg, 4))
        P[side + "Hand"] = qx(-6 + 26 * s)
        for i, fn in enumerate(FINGERS):
            c = 18 + 14 * a - 34 * s + tr(10 + i, 6)                 # นิ้วกางแอ่นสุด
            PL[f"{side}{fn}1"] = qx(c * (0.6 if fn == "Thumb" else 1.0)) @ Quaternion((0, 0, 1), math.radians(sg * (i - 2) * 7 * s))
            PL[f"{side}{fn}2"] = qx(c * 1.1)
    hips = v3(0, 0.02 * k * s, (-0.045 - 0.06 * a - 0.03 * s) * k)
    tongue_pose(ps, P, [s * 10 * math.sin(f * 0.9 - i * 0.8) + 2 * math.sin(tau * t - i * 0.5) for i in range(6)],
                [s * 7 * math.sin(f * 0.7 - i * 0.6) for i in range(6)], comp=0.7)
    for side in ("Left", "Right"):
        ps.leg(P, side, hips, J[side + "Ankle"])
    return P, PL, hips


def make_action(arm, ps, name, frames, fn, loop):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if not arm.animation_data:
        arm.animation_data_create()
    arm.animation_data.action = act
    ps.last.clear()
    for fr in range(1, frames + 2 if loop else frames + 1):
        t = (fr - 1) / frames
        P, PL, hips = fn(ps, t)
        ps.key(fr, P, PL, hips)
    log(f"  action {name}: {frames + 1 if loop else frames} frames @{FPS}fps{' loop' if loop else ''}")
    return act


# ================================================================ 7. export + ภาพตัวอย่าง
def export_fbx(path, objs, arm, anim):
    select_only(objs + [arm], arm)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=False, object_types={"MESH", "ARMATURE"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=False,
                             add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
                             use_armature_deform_only=False, bake_anim=anim, bake_anim_use_all_actions=False,
                             bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True, bake_anim_simplify_factor=0.0)


def render_setup(res, bg=0.42, mode="TEXTURE"):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    sh = scn.display.shading
    sh.light = "STUDIO"
    sh.color_type = mode
    if mode == "SINGLE":
        sh.single_color = (0.55, 0.5, 0.45)
    sh.show_cavity = True
    sh.cavity_type = "BOTH"
    sh.show_shadows = True
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    if not scn.world:
        scn.world = bpy.data.worlds.new("World")
    scn.world.color = (bg, bg, bg)
    scn.view_settings.view_transform = "Standard"


def shoot(path, objs, d, ortho=True, res=(800, 1200), margin=1.08):
    mn, mx = bbox(objs)
    c = Vector((mn + mx) / 2)
    size = Vector(mx - mn)
    cam = bpy.data.objects.get("PrevCam")
    if not cam:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        bpy.context.scene.collection.objects.link(cam)
    d = Vector(d).normalized()
    aspect = res[0] / res[1]
    horiz = abs(d.y) * size.x + abs(d.x) * size.y
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = max(size.z, horiz / aspect) * margin
        cam.location = c + d * 20
        cam.data.clip_end = 100
    else:
        cam.data.type = "PERSP"
        cam.data.lens = 50
        cam.data.sensor_fit = "AUTO"
        fov = 2 * math.atan(18 / 50)
        rad = max(size.z, horiz / aspect) * 0.5 * margin
        cam.location = c + d * (rad / math.tan(fov / 2) + max(size.x, size.y) * 0.5)
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    scn = bpy.context.scene
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def ref_human(x):
    """หุ่นเทียบขนาดตัวละคร R15 (สูง 5.2 studs) เฉพาะภาพตัวอย่าง"""
    s = STUD
    g = Geo()
    me = bpy.data.meshes.new("RefHuman")
    bm = bmesh.new()
    for (cx, cz, w, h) in ((0.5, 1.0, 0.9, 2.0), (-0.5, 1.0, 0.9, 2.0), (0, 3.1, 2.0, 2.2), (1.5, 3.1, 0.9, 2.0), (-1.5, 3.1, 0.9, 2.0)):
        r = bmesh.ops.create_cube(bm, size=1.0)
        for v in r["verts"]:
            v.co = Vector((x + (cx + v.co.x * w) * s, v.co.y * 1.0 * s, (cz + v.co.z * h) * s))
    r = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.6 * s)
    for v in r["verts"]:
        v.co += Vector((x, 0, 4.7 * s))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("RefHuman", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.color = (0.15, 0.25, 0.45, 1)
    return ob


def renders(objs, arm, acts, mode="TEXTURE"):
    os.makedirs(PREV, exist_ok=True)
    render_setup((800, 1200), mode=mode)
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    if arm:
        arm.animation_data.action = acts["Idle"]
        bpy.context.scene.frame_set(1)
    shoot(os.path.join(PREV, NAME + "_front.png"), objs, (0, -1, 0.02))
    shoot(os.path.join(PREV, NAME + "_side.png"), objs, (1, 0, 0.02))
    shoot(os.path.join(PREV, NAME + ".png"), objs, (-0.75, -1.25, 0.35), ortho=False)
    if not arm:
        return
    shoot_face(objs)
    # ขนาดเทียบคน R15
    rh = ref_human(1.25)
    rh.hide_render = False
    shoot(os.path.join(PREV, NAME + "_scale.png"), objs + [rh], (0, -1, 0.02), res=(1000, 1100))
    bpy.data.objects.remove(rh)
    # ท่า
    arm.animation_data.action = acts["TallSlowWalk"]
    bpy.context.scene.frame_set(13)
    shoot(os.path.join(PREV, NAME + "_walk.png"), objs, (1, -0.35, 0.05), ortho=False)
    arm.animation_data.action = acts["Shriek"]
    bpy.context.scene.frame_set(40)
    shoot(os.path.join(PREV, NAME + "_shriek.png"), objs, (-0.6, -1.25, 0.15), ortho=False)
    arm.data.pose_position = "REST"
    shoot(os.path.join(PREV, NAME + "_rest.png"), objs, (0, -1, 0.02), res=(1000, 1100))
    arm.data.pose_position = "POSE"
    arm.animation_data.action = acts["Idle"]
    bpy.context.scene.frame_set(1)


def shoot_face(objs):
    """ภาพหน้าใกล้ (กรอบเฉพาะหัว)"""
    cam = bpy.data.objects.get("PrevCam")
    arm = objs[0].parent
    hb = arm.pose.bones["Head"]
    hc = arm.matrix_world @ ((hb.head + hb.tail) / 2)
    fwd = (arm.matrix_world.to_3x3() @ hb.matrix.to_3x3() @ Vector((0, 0, 1))).normalized()
    cam.data.type = "PERSP"
    cam.data.lens = 50
    d = (fwd + Vector((-0.25, 0, 0.05))).normalized()
    cam.location = hc + d * 1.25 * (HEIGHT / 3.92)
    cam.rotation_euler = (hc - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn = bpy.context.scene
    scn.render.resolution_x, scn.render.resolution_y = (900, 900)
    scn.render.filepath = os.path.join(PREV, NAME + "_face.png")
    bpy.ops.render.render(write_still=True)


# ================================================================ main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    M = Meta(NAME + "Meta", 0.0055)
    build_body(M)
    log(f"metaball elements: {M.count}")
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(M.ob.evaluated_get(dg))
    hi = bpy.data.objects.new(NAME + "_HI", me)
    scn.collection.objects.link(hi)
    bpy.data.objects.remove(M.ob)
    log(f"HI mesh: {len(me.vertices)} verts, {tris(hi)} tris")
    tongue = build_tongue()
    eyes = build_eyes()
    hair = build_hair()
    cloth = build_cloth()
    parts = [tongue, *eyes, hair, cloth]
    mn, mx = bbox([hi] + parts)
    k = HEIGHT / mx[2]
    scale_all([hi] + parts, k)
    log(f"scale x{k:.4f} -> height {HEIGHT:.3f} m ({HEIGHT / STUD:.1f} studs)")
    me.shade_smooth()
    for o in parts:
        o.data.shade_smooth()

    if STAGE == "shape":
        renders([hi] + parts, None, None, mode="SINGLE")
        return

    # LO: decimate
    lo = bpy.data.objects.new(NAME + "_Body", hi.data.copy())
    scn.collection.objects.link(lo)
    for a in list(lo.data.color_attributes):
        lo.data.color_attributes.remove(a)
    dec = lo.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 14500 / tris(hi)
    apply_mods(lo)
    lo.data.shade_smooth()
    log(f"LO body: {tris(lo)} tris")
    set_masks(hi)
    uv_layout(lo, parts, {NAME + "_EyeL": 2.2, NAME + "_EyeR": 2.2, NAME + "_Hair": 0.5, NAME + "_Tongue": 1.2, NAME + "_Cloth": 0.8})
    files = bake_textures(hi, lo, parts)
    mat = final_material(files)
    for o in [lo] + parts:
        o.data.materials.clear()
        o.data.materials.append(mat)
    bpy.data.objects.remove(hi)

    # rig
    bone_specs()
    arm = build_armature()
    maxinf, zero = skin(arm, lo, tongue, hair, cloth, eyes)
    log(f"rig: {len(BONES)} bones; body max influences {maxinf}, unweighted verts {zero}")
    # ตาเข้า mesh ตัว (ชิ้นน้อยลง)
    select_only([lo] + eyes, lo)
    bpy.ops.object.join()
    body = lo
    objs = [body, tongue, hair, cloth]
    for o in objs:
        n = max((sum(1 for g in v.groups if g.weight > 1e-4) for v in o.data.vertices), default=0)
        log(f"  {o.name}: {tris(o)} tris, max influences {n}")
    ps = Poser(arm)
    acts = {
        "Idle": make_action(arm, ps, "Idle", 120, pose_idle, True),
        "TallSlowWalk": make_action(arm, ps, "TallSlowWalk", WALK_FRAMES, pose_walk, True),
        "Shriek": make_action(arm, ps, "Shriek", SHRIEK_FRAMES, pose_shriek, False),
    }
    # export
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    export_fbx(os.path.join(ROOT, NAME + ".fbx"), objs, arm, False)
    for nm, act in acts.items():
        arm.animation_data.action = act
        fr = act.frame_range
        scn.frame_start, scn.frame_end = int(fr[0]), int(fr[1])
        export_fbx(os.path.join(ROOT, f"{NAME}_{nm}.fbx"), objs, arm, True)
    scn.frame_start, scn.frame_end = 1, 120
    mn, mx = bbox(objs)
    size = (mx - mn) / STUD
    log(f"bbox studs X={size[0]:.2f} Y(up)={size[2]:.2f} Z={size[1]:.2f}; total tris {sum(tris(o) for o in objs)}")
    renders(objs, arm, acts)
    arm.animation_data.action = acts["Idle"]
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "pret.blend"))
    log("done")


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "pret_build.log")
try:
    main()
except Exception:
    LOG.append(traceback.format_exc())
open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
open(OUT + ".done", "w").write("x")
