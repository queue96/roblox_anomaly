# ร่มกาง (ลูกค้าเดินกางร่มตอนฝนตก / คนขับรถกางร่ม) — สร้างด้วย Blender แบบ headless
# รัน:  blender-launcher.exe --background --factory-startup --python tools/blender/umbrella.py
# ผลลัพธ์: assets/models/Umbrella.fbx + Umbrella_Color/_Normal/_Roughness/_Metalness.png, previews/Umbrella.png + _below.png, umbrella.blend
# ใช้ตัวช่วยปั้นจาก thai_vehicles.py (B builder, texture atlas, export) หน่วย studs, origin = จุดมือจับ (กลางด้ามตรง)
# ผ้าร่มสีเทาอ่อน (Umbrella_Canopy แยกชิ้น) ให้ Studio ย้อมสีได้ด้วย SurfaceAppearance.Color ตามสีร่มใน Pedestrian.luau
import bpy, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))

PAL.update({
    "umb_fabric": dict(c=(214, 212, 206), r=0.75, m=0, p="canvas"),
    "umb_under": dict(c=(150, 148, 144), r=0.85, m=0, p="canvas"),
    "umb_metal": dict(c=(70, 72, 76), r=0.35, m=0.85, p="plain"),
    "umb_wood": dict(c=(96, 60, 36), r=0.45, m=0, p="grain"),
    "umb_tip": dict(c=(28, 28, 30), r=0.4, m=0.2, p="plain"),
})
KEYS[:] = list(PAL.keys())

R = 3.0  # รัศมีร่ม (กว้าง 6 studs ใหญ่กว่าร่ม Part เดิม 4.6 ให้เงาบังตัวละครได้มิด)
ZT = 5.1  # ยอดผ้าร่มสูงจากมือจับ
NRIB = 8


def dome(r):
    """ความสูงผ้าร่มที่รัศมี r (โค้งโดม ขอบงุ้มลง)"""
    t = r / R
    return ZT - 1.35 * t ** 1.7 - 0.15 * max(0.0, t - 0.85) / 0.15


def canopy_point(r, a):
    """ผ้าระหว่างซี่ร่มตึงน้อยกว่าแนวซี่: หดเข้าและยุบลงเล็กน้อย (ขอบเป็นลอนแบบร่มจริง)"""
    seg = 2 * math.pi / NRIB
    u = ((a % seg) / seg)  # 0..1 ระหว่างซี่
    slack = math.sin(math.pi * u)  # 0 ที่ซี่ 1 กลางช่อง
    t = r / R
    rr = r * (1 - 0.07 * slack * t ** 1.5)
    z = dome(r) - 0.06 * slack * t
    return (rr * math.cos(a), rr * math.sin(a), z)


def make_umbrella():
    P = "Umbrella"
    canopy, frame, handle = B(P + "_Canopy"), B(P + "_Frame"), B(P + "_Handle")
    canopy.no_recalc = True
    canopy.bevel = False
    frame.bevel, frame.sa = False, 60  # ซี่ร่มเส้นเล็ก ไม่ต้องลบมุม (ประหยัด tris)
    handle.bw, handle.sa = 0.006, 60
    # ผ้าร่ม 8 ช่อง ทำ 2 ด้าน (บน = สีผ้า, ล่าง = เงาผ้าเข้มกว่า)
    NR, NA = 9, NRIB * 6
    rings = [[canopy_point(R * k / NR, 2 * math.pi * i / NA) for i in range(NA)] for k in range(1, NR + 1)]
    top = canopy._v((0, 0, ZT + 0.02))
    vt = [[canopy._v(p) for p in ring] for ring in rings]
    for i in range(NA):
        j = (i + 1) % NA
        canopy.face([top, vt[0][i], vt[0][j]], "umb_fabric")
        for k in range(NR - 1):
            canopy.face([vt[k][i], vt[k][j], vt[k + 1][j], vt[k + 1][i]][::-1], "umb_fabric")
    bot = canopy._v((0, 0, ZT - 0.02))
    vb = [[canopy._v((x, y, z - 0.015)) for x, y, z in ring] for ring in rings]
    for i in range(NA):
        j = (i + 1) % NA
        canopy.face([bot, vb[0][j], vb[0][i]], "umb_under")
        for k in range(NR - 1):
            canopy.face([vb[k][i], vb[k][j], vb[k + 1][j], vb[k + 1][i]], "umb_under")
    # ขอบผ้า (แถบหนาเล็กน้อยให้เห็นขอบจากด้านข้าง)
    for i in range(NA):
        j = (i + 1) % NA
        canopy.face([vt[-1][i], vt[-1][j], vb[-1][j], vb[-1][i]][::-1], "umb_under")
    # ซี่ร่มใต้ผ้า + ปลายซี่ + ซี่ค้ำ + รันเนอร์
    ZR = 3.5  # รันเนอร์ (ตัวเลื่อนกางร่ม) บนก้าน
    for n in range(NRIB):
        a = 2 * math.pi * n / NRIB
        pts = []
        for k in range(0, 11):
            r = R * 0.98 * k / 10
            x, y, z = canopy_point(r, a)
            pts.append((x, y, z - 0.07))
        frame.tube(pts, 0.028, "umb_metal", n=6)
        tip = canopy_point(R * 0.99, a)
        frame.ellipsoid((tip[0], tip[1], tip[2] - 0.05), (0.06, 0.06, 0.06), "umb_tip", nu=8, nv=4)
        mid = canopy_point(R * 0.45, a)
        frame.tube([(0.07 * math.cos(a), 0.07 * math.sin(a), ZR), (mid[0], mid[1], mid[2] - 0.08)], 0.022, "umb_metal", n=6)
    frame.lathe(0, 0, [(0.09, ZR - 0.18), (0.11, ZR - 0.1), (0.11, ZR + 0.1), (0.08, ZR + 0.18)], 12, "umb_tip")
    # ก้านร่ม + ปลายแหลมบนยอด + ฝาครอบยอด
    frame.lathe(0, 0, [(0.045, 0.35), (0.045, ZT - 0.05)], 10, "umb_metal")
    frame.lathe(0, 0, [(0.13, ZT - 0.02), (0.1, ZT + 0.08), (0.05, ZT + 0.14), (0.04, ZT + 0.45), (0.0, ZT + 0.55)], 12, "umb_tip")
    frame.lathe(0, 0, [(0.07, ZT - 0.2), (0.06, ZT - 0.08)], 10, "umb_tip")
    # ด้ามไม้ทรงตะขอ J (จุดมือจับ = origin)
    hk = [(0, 0, 0.45), (0, 0, -0.45)]
    for k in range(1, 10):
        t = math.pi * k / 9
        hk.append((0, 0.32 - 0.32 * math.cos(t), -0.45 - 0.32 * math.sin(t)))
    hk.append((0, 0.66, -0.38))
    handle.tube(hk, [0.11] * (len(hk) - 1) + [0.1], "umb_wood", n=10)
    handle.lathe(0, 0, [(0.07, 0.42), (0.09, 0.5)], 10, "umb_metal")
    return P, [canopy, frame, handle]


def main_umbrella():
    os.makedirs(PREV, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    prop, builders = make_umbrella()
    log(prop)
    coll, objs = realize(prop, builders)
    export(prop, objs)
    preview(prop, objs, None)
    # มุมใต้ร่ม (เห็นซี่และซี่ค้ำ)
    frame_cam(objs, (0.9, -0.6, -0.35), dist=1.0)
    bpy.context.scene.render.filepath = os.path.join(PREV, prop + "_below.png")
    bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "umbrella.blend"))


try:
    main_umbrella()
    LOG.append("DONE")
except Exception:
    import traceback
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(os.path.join(os.environ.get("VEH_LOG_DIR", ROOT), "umbrella_build.log"), "w", encoding="utf-8").write("\n".join(LOG))
