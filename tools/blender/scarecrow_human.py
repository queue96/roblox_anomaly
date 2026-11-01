# หุ่นไล่กาทรงคนจริง (ตามภาพอ้างอิงของผู้พัฒนา): เสื้อเชิ้ตลายสก๊อตสีน้ำเงิน กางเกงยีนส์ซีด หมวกฟางปีกกว้าง ฟางทะลักปลายแขน/คอ/ขากางเกง
# ผมฟางห้อยใต้หมวก หน้ากระสอบเย็บตากระดุม (ชิ้นตาแยก ให้ผีเปลี่ยนเป็นแดงเรือง) ไม้คานแผ่นไม้ เสาไม้กลมปักดิน
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/scarecrow_human.py [-- export]
#   ไม่ใส่ = render ภาพตัวอย่างกลางวัน/กลางคืน (previews/ScarecrowHuman_day.png, _night.png)
#   export = assets/models/ScarecrowThai/ScarecrowThai.fbx + พื้นผิว (ชื่อชิ้นเดิม ScarecrowThai / _EyeL_Neon / _EyeR_Neon ใช้กับ MapBuilder.SwapScarecrowThai ได้เลย)
import bpy, math, os, sys
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "scarecrow_variants.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main_variants()")], "scarecrow_variants.py", "exec"))

PAL.update({
    "hm_flannel": dict(c=(34, 58, 108), r=0.92, m=0, p="hm_flannel"),
    "hm_denim": dict(c=(108, 128, 152), r=0.9, m=0, p="hm_denim"),
    "hm_wood": dict(c=(104, 80, 56), r=0.85, m=0, p="hm_wood"),
    "hm_hat": dict(c=(170, 140, 92), r=0.85, m=0, p="sc_ngob"),
    "hm_band": dict(c=(46, 34, 28), r=0.7, m=0, p="plain"),
    "hm_button": dict(c=(210, 204, 190), r=0.4, m=0, p="plain"),
})
KEYS[:] = list(PAL.keys())

_paint_v = paint


def paint(key, n, seed):
    p = PAL[key]["p"]
    if not p.startswith("hm_"):
        return _paint_v(key, n, seed)
    spec = PAL[key]
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    n1 = vnoise(n, 5, seed)
    n2 = vnoise(n, 18, seed + 7)
    n3 = vnoise(n, 48, seed + 13)
    rough = np.full((n, n), spec["r"]) + 0.05 * (n2 - 0.5)
    metal = np.zeros((n, n))
    if p == "hm_flannel":
        # ผ้าสก๊อตฟลาเนล: แถบน้ำเงินกว้าง + แถบกรมท่า + เส้นขาวบาง ทั้งแนวตั้งแนวนอน (ทับกันเข้มขึ้น) 12 ช่องต่อรอบลาย
        def bands(t):
            f = (t * 12) % 1.0
            dark = ((f > 0.0) & (f < 0.42)).astype(float)
            white = ((f > 0.62) & (f < 0.68)).astype(float)
            return dark, white
        dx, wx = bands(xx)
        dy, wy = bands(yy)
        light = np.array([0.36, 0.5, 0.74])
        navy = np.array([0.08, 0.12, 0.26])
        col = light * np.ones((n, n, 1))
        cover = np.clip(dx + dy, 0, 2) / 2
        col = col * (1 - cover[..., None] * 0.75) + navy * (cover * 0.75)[..., None]
        col = np.where(((wx + wy) > 0)[..., None], col * 0.4 + np.array([0.82, 0.82, 0.8]) * 0.6, col)
        twill = np.abs(np.sin((xx + yy) * 90 * math.pi))
        col = col * (0.96 + 0.05 * twill)[..., None]
        # ซีดแดด + คราบดินฝุ่น
        fade = np.clip((n1 - 0.4) * 1.5, 0, 1)
        col = col * (1 - 0.3 * fade[..., None]) + np.array([0.5, 0.48, 0.44]) * (0.3 * fade)[..., None]
        dirt = np.clip((n2 - 0.65) * 4, 0, 1)
        col = col * (1 - dirt[..., None] * 0.5) + np.array([0.25, 0.18, 0.11]) * (0.5 * dirt)[..., None]
        h = 0.03 * twill + 0.05 * n3
    elif p == "hm_denim":
        # ยีนส์ซีด: ลายทแยงทวิล + ด่างฟอกขาว + เข่าขาดเปื้อนดิน
        twill = np.abs(np.sin((xx * 1.0 + yy * 0.6) * 120 * math.pi))
        col = base * (0.93 + 0.08 * twill)[..., None]
        bleach = np.clip((n1 - 0.45) * 2.0, 0, 1)
        col = col * (1 - 0.35 * bleach[..., None]) + np.array([0.7, 0.74, 0.78]) * (0.35 * bleach)[..., None]
        mud = np.clip((n2 - 0.62) * 3.5, 0, 1) * np.clip(1.2 - yy * 1.5, 0, 1)
        col = col * (1 - mud[..., None] * 0.6) + np.array([0.22, 0.16, 0.1]) * (0.6 * mud)[..., None]
        h = 0.08 * twill
    else:  # hm_wood ไม้เก่าแตกลายงา
        grain = np.abs(np.sin((xx * 3 + n2 * 0.8) * 14 * math.pi))
        col = base * (0.75 + 0.3 * grain + 0.15 * (n3 - 0.5))[..., None]
        crack = (np.abs(np.sin((xx * 3 + n1 * 0.6) * 5 * math.pi)) < 0.025).astype(float)
        col = col * (1 - 0.6 * crack[..., None])
        grey = np.clip((n1 - 0.5) * 2, 0, 1)
        col = col * (1 - 0.4 * grey[..., None]) + np.array([0.42, 0.4, 0.37]) * (0.4 * grey)[..., None]
        h = 0.4 * grain - 0.5 * crack
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), metal


def stuffed(b, prof, sy, key, seed, amt=0.07, freq=2.4):
    """ส่วนตัวที่ยัดฟาง: lathe รีตามแกน y แล้วทำผิวยับย้วยไม่เรียบ"""
    start = len(b.v)
    with b.xf(Matrix.Scale(sy, 4, (0, 1, 0))):
        b.lathe(0, 0, prof, 18, key)
    lumpy(b, start, amt, freq, seed=seed)


def make_human_scarecrow():
    P = "ScarecrowThai"
    body = B(P)
    body.bevel, body.sa = False, 55
    body.worlduv = True  # ลายผ้าต่อเนื่องตามพิกัดจริง (ไม่เป็นสี่เหลี่ยมเรียงต่อกันทีละหน้า)
    eyeL, eyeR = B(P + "_EyeL_Neon"), B(P + "_EyeR_Neon")
    ZB, ZH = 5.15, 6.2

    # เสาไม้กลมปักดิน + ไม้คานแผ่นไม้ตอกตะปู (ด้านหลังตัวหุ่น)
    body.cone((0, 0.32, 0), (0, 0.32, ZH + 0.5), 0.17, 0.15, "hm_wood", n=10)
    body.beam((-2.9, 0.34, ZB + 0.08), (2.9, 0.34, ZB + 0.12), 0.12, 0.24, "hm_wood", side=(0, 1, 0))
    for k in range(3):
        body.torus((0, 0.32, ZB - 0.15 + k * 0.09), "z", 0.2, 0.03, "sc_rope", nu=12, nv=4)

    # ลำตัว: ไหล่กว้าง อกพอง เอวคอด สะโพก (ยัดฟางไม่เรียบ) เสื้อเชิ้ตลายสก๊อตน้ำเงิน
    stuffed(body, [(0.3, 5.5), (0.62, 5.42), (0.95, 5.18), (0.92, 4.8), (0.86, 4.3), (0.74, 3.8), (0.78, 3.45), (0.8, 3.3)], 0.58, "hm_flannel", 31)
    # ปกเสื้อ 2 ฝั่ง + กระดุมหน้า + กระเป๋าอก
    for sx in (-1, 1):
        body.beam((sx * 0.08, -0.36, 5.42), (sx * 0.38, -0.46, 5.12), 0.3, 0.03, "hm_flannel", side=(0, 0, 1))
    for z in (5.15, 4.7, 4.25, 3.8):
        body.ellipsoid((0.02, -0.53, z), (0.04, 0.015, 0.04), "hm_button", nu=8, nv=4)
    body.boxc(-0.38, -0.53, 4.75, 0.36, 0.04, 0.38, "hm_flannel")
    body.beam((-0.56, -0.56, 4.94), (-0.2, -0.56, 4.94), 0.06, 0.02, "hm_flannel", side=(0, 0, 1))

    # แขนเสื้อพาดคาน: ข้อศอกย้วย ผ้ายับ ปลายแขนฟางทะลักเป็นมือ
    for sx in (-1, 1):
        start = len(body.v)
        pts = [(sx * 0.75, 0, 5.0), (sx * 1.3, 0.05, 4.92), (sx * 1.85, 0.1, 4.85), (sx * 2.35, 0.12, 4.9), (sx * 2.65, 0.12, 4.92)]
        body.tube(pts, [0.36, 0.33, 0.31, 0.3, 0.29], "hm_flannel", n=12)
        lumpy(body, start, 0.05, 3.5, seed=int(5 + sx))
        body.torus((sx * 2.6, 0.12, 4.92), "x", 0.3, 0.04, "sc_rope", nu=12, nv=4)  # มัดข้อมือ
        straw_tuft(body, (sx * 2.68, 0.12, 4.92), (sx, 0, -0.25), 30, 0.65, 0.22, 0.45)

    # เข็มขัดเชือก
    with body.xf(Matrix.Translation((0, 0, 3.42)) @ Matrix.Scale(0.6, 4, (0, 1, 0))):
        body.torus((0, 0, 0), "z", 0.8, 0.05, "sc_rope", nu=20, nv=4)

    # กางเกงยีนส์: ขาห้อยลงงอเข่านิดๆ (ยัดฟาง) ปลายขาพับ ฟางทะลักออก
    for sx in (-1, 1):
        start = len(body.v)
        pts = [(sx * 0.36, 0, 3.35), (sx * 0.4, -0.04, 2.5), (sx * 0.42, -0.12, 1.75), (sx * 0.44, -0.02, 1.05)]
        body.tube(pts, [0.42, 0.36, 0.33, 0.31], "hm_denim", n=12)
        lumpy(body, start, 0.05, 3.0, seed=int(17 + sx))
        body.torus((sx * 0.44, -0.02, 1.08), "z", 0.31, 0.06, "hm_denim", nu=12, nv=4)
        straw_tuft(body, (sx * 0.44, -0.02, 1.0), (0, 0, -1), 22, 0.45, 0.25, 0.1)
    # สะโพกกางเกง (ต่อลำตัวกับขา)
    stuffed(body, [(0.8, 3.38), (0.82, 3.1), (0.6, 2.85)], 0.6, "hm_denim", 41, amt=0.04)
    # รอยปะเข่า
    body.boxc(0.42, -0.42, 1.9, 0.34, 0.04, 0.3, "hm_flannel")

    # คอ: ฟางทะลักใต้ปกเสื้อ + เชือกมัดคอกระสอบ
    straw_tuft(body, (0, 0, 5.45), (0, 0, 1), 18, 0.3, 0.25, -0.3)
    body.torus((0, 0, 5.6), "z", 0.27, 0.045, "sc_rope", nu=14, nv=4)

    # หัวกระสอบ (เอียงก้มลงนิดๆ) หน้าเย็บ: ตากระดุมเล็ก ปากเย็บด้ายบางๆ
    tilt = Matrix.Rotation(math.radians(12), 4, "X") @ Matrix.Rotation(math.radians(-7), 4, "Y")
    hc = Vector((0, -0.02, ZH))
    burlap_head(body, hc, (0.52, 0.5, 0.62), tilt)
    with body.xf(Matrix.Translation(hc) @ tilt):
        for k in range(6):
            x = -0.2 + k * 0.08
            body.beam((x - 0.03, -0.5, -0.2), (x + 0.03, -0.5, -0.24), 0.02, 0.015, "sc_thread", side=(0, 1, 0))
        body.beam((-0.22, -0.48, -0.22), (0.22, -0.48, -0.22), 0.015, 0.015, "sc_thread", side=(0, 0, 1))
        body.beam((0.05, -0.5, 0.0), (0.0, -0.5, -0.1), 0.015, 0.015, "sc_thread", side=(0, 1, 0))  # จมูกเย็บ
    for ex, sz in ((-0.17, 0.07), (0.17, 0.06)):
        e = hc + tilt @ Vector((ex, -0.5, 0.12))
        (eyeL if ex < 0 else eyeR).ellipsoid(tuple(e), (sz, 0.03, sz), "sc_eye", nu=12, nv=6)

    # ผมฟางห้อยใต้หมวกรอบหัว (ยาวถึงไหล่ด้านหลัง/ข้าง หน้าสั้นเป็นหน้าม้า)
    for i in range(70):
        a = 2 * math.pi * i / 70 + rng.uniform(-0.04, 0.04)
        front = -math.sin(a)  # 1 = ด้านหน้า (-Y)
        root = hc + tilt @ Vector((0.5 * math.cos(a), 0.48 * math.sin(a), 0.32))
        L = 0.35 if front > 0.6 else rng.uniform(0.7, 1.3)
        out = Vector((math.cos(a), math.sin(a), 0)) * 0.12
        tip = root + out + Vector((rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), -L))
        body.beam(tuple(root), tuple(tip), rng.uniform(0.04, 0.07), 0.012, "sc_straw", side=(math.cos(a), math.sin(a), 0))

    # หมวกฟางปีกกว้าง (ทรงเฟดอร่า ยอดบุ๋ม แถบผ้าคาด ปีกงอนขึ้นข้างๆ) เอียงตามหัว
    hat = Matrix.Translation(hc + Vector((0, 0.0, 0.42))) @ tilt
    with body.xf(hat):
        crown = [(0.0, 0.52), (0.2, 0.55), (0.4, 0.5), (0.5, 0.35), (0.52, 0.1), (0.53, 0.0)]
        body.lathe(0, 0, crown, 20, "hm_hat")
        body.lathe(0, 0, [(0.54, 0.02), (0.54, 0.13)], 20, "hm_band")
        start = len(body.v)
        brim = []
        for j in range(24):
            a = 2 * math.pi * j / 24
            up = 0.1 * abs(math.cos(a)) ** 2  # ปีกงอนขึ้นด้านข้าง
            brim.append((a, up))
        ring_in = [body._v((0.52 * math.cos(a), 0.52 * math.sin(a), 0.0)) for a, _ in brim]
        ring_out = [body._v((1.05 * math.cos(a), 1.05 * math.sin(a), u - 0.05)) for a, u in brim]
        ring_out2 = [body._v((1.05 * math.cos(a), 1.05 * math.sin(a), u - 0.09)) for a, u in brim]
        ring_in2 = [body._v((0.52 * math.cos(a), 0.52 * math.sin(a), -0.04)) for a, _ in brim]
        for j in range(24):
            k = (j + 1) % 24
            body.face([ring_in[j], ring_in[k], ring_out[k], ring_out[j]], "hm_hat")
            body.face([ring_out[j], ring_out[k], ring_out2[k], ring_out2[j]], "hm_hat")
            body.face([ring_out2[j], ring_out2[k], ring_in2[k], ring_in2[j]], "hm_hat")
        lumpy(body, start, 0.03, 5.0, seed=9)
        # ปีกหมวกขาดแหว่ง เส้นฟางหลุดห้อย
        for k in range(5):
            a = math.radians(230 + k * 5)
            body.beam((1.02 * math.cos(a), 1.02 * math.sin(a), -0.04), (1.18 * math.cos(a), 1.18 * math.sin(a), -0.3 - 0.04 * k), 0.04, 0.01, "hm_hat", side=(0, 0, 1))
    return P, [body, eyeL, eyeR]


def day_render(objs, path):
    sc = bpy.context.scene
    w = sc.world
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.6, 0.85, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    for o in list(sc.objects):
        if o.type == "LIGHT":
            bpy.data.objects.remove(o)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(55), 0, math.radians(-35)))
    bpy.context.active_object.data.energy = 3.5
    frame_cam(objs, (0.3, -1.0, 0.1), lens=45, dist=1.0)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main_human():
    global ROOT
    export_mode = "export" in sys.argv
    ROOT = os.path.join(MODELS, "ScarecrowThai") if export_mode else VAR_DIR  # 1 โมเดล = 1 โฟลเดอร์
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prop, builders = make_human_scarecrow()
    coll, objs = realize(prop, builders)
    if export_mode:
        export(prop, objs)
        log("EXPORTED human scarecrow")
    prev = os.path.join(MODELS, "ScarecrowThai", "previews")
    os.makedirs(prev, exist_ok=True)
    night_render(objs, os.path.join(prev, "ScarecrowHuman_night.png"))
    day_render(objs, os.path.join(prev, "ScarecrowHuman_day.png"))


try:
    main_human()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    print("\n".join(LOG))
