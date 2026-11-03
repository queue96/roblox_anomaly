# ศาลพระภูมิ v2 + มือผี + ขันลงหิน — สร้างด้วย Blender แบบ headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\spirit_house_v2.py `
#       -Blend assets\models\pump_props.blend -Out C:\tmp\sh_v2.txt
# อ่านจาก pump_props.blend (ไม่เขียนทับ) แล้วบันทึกเป็น assets/models/spirit_house_v2.blend (เหลือเฉพาะ 3 prop นี้)
# ผลลัพธ์:
#   SpiritHouseOnStilts_v2.fbx  ฐาน (เสา แท่น ราว บันได) หมุน -90° ให้บันได/ช่องราวอยู่หน้าศาล (-Y),
#                               ต่อแท่นยื่นด้านหน้า 0.55 ม. (+เสาค้ำ 2 ต้น) เว้นที่วางกระถางธูป (ใช้กระถาง+ธูปเดิมใน Roblox
#                               ไม่ปั้นใหม่) กับที่วางขนม,
#                               เจาะช่องประตูหน้าศาล 0.30 x 0.35 ม. ข้างในเป็นโพรงมืด (ตัวศาลขนาดเท่าเดิม)
#                               texture ชุดเดิม SpiritHouseOnStilts_*.png (UV เดิม + ระบายจุดสีมืดในที่ว่างของ atlas)
#   GhostHand.fbx               มือผีผอมแห้ง + แขนท่อนล่าง ท่าเอื้อมจะคว้า origin = ปลายแขนด้านในศาล มือชี้ -Y
#   LeafSweets.fbx              ขนมตาลบนใบตอง ไม่มีขัน (LeafTray, OpenWrap, SweetCake, Wrapped) origin = กลางใต้ใบตอง
#   previews/SpiritHouseOnStilts_v2.png (+_side, _scene = ศาล+ขัน+มือผีเอื้อม), previews/GhostHand.png, previews/KhanBowl.png
# หน่วยเมตร (1 stud = 0.28 m) ใช้ตัวช่วย B / atlas / export / preview จาก thai_vehicles.py โดยตั้ง S = 1
import bpy, bmesh, math, os, sys, traceback
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))
S = 1.0  # ปั้นเป็นเมตรตรง ๆ (realize() คูณด้วย S)
SRC_BLEND = os.path.join(ROOT, "pump_props.blend")
V2_BLEND = os.path.join(ROOT, "spirit_house_v2.blend")
SH = "SpiritHouseOnStilts"

# ---------------------------------------------------------------- palette ใหม่
PAL.update({
    "F_skin": dict(c=(150, 162, 140), r=0.6, m=0, p="F_skin"),       # ผิวซีดเทาอมเขียว + เส้นเลือดดำ (512px)
    "skin_dark": dict(c=(66, 72, 64), r=0.75, m=0, p="skin_dark"),   # ผิวคล้ำจางหายเข้าแขนเสื้อ
    "rag": dict(c=(34, 30, 28), r=0.95, m=0, p="rag"),               # แขนเสื้อขาดสีดำหม่น
    "nail": dict(c=(126, 104, 60), r=0.45, m=0, p="nail"),           # เล็บยาวเหลืองสกปรก
    "bronze": dict(c=(184, 142, 74), r=0.45, m=0.8, p="bronze"),      # ทองเหลือง/สำริดหม่น
    "bronze_ring": dict(c=(196, 152, 80), r=0.4, m=0.85, p="bronze_ring"),
    "bronze_band": dict(c=(188, 146, 76), r=0.45, m=0.8, p="bronze_band"),  # ลายกลีบบัวสลัก
    "bronze_in": dict(c=(150, 114, 62), r=0.5, m=0.75, p="bronze"),
    "kc_layers": dict(c=(70, 150, 80), r=0.35, m=0, p="kc_layers"),  # ขนมชั้น เขียว/ครีม
    "kc_top": dict(c=(64, 150, 76), r=0.3, m=0, p="glossy"),
    "thongyod": dict(c=(236, 168, 28), r=0.3, m=0, p="glossy"),      # ทองหยอด
    "luk_pink": dict(c=(236, 120, 150), r=0.25, m=0, p="glossy"),    # ลูกชุบ
    "luk_orange": dict(c=(242, 140, 40), r=0.25, m=0, p="glossy"),
    "luk_green": dict(c=(126, 176, 64), r=0.25, m=0, p="glossy"),
    "luk_red": dict(c=(214, 52, 50), r=0.25, m=0, p="glossy"),
    "leaf": dict(c=(56, 110, 40), r=0.5, m=0, p="plain"),
    "banana_leaf": dict(c=(74, 138, 46), r=0.4, m=0, p="bleaf"),   # ใบตองรองขัน
    "cream": dict(c=(234, 224, 192), r=0.8, m=0, p="grain"),         # ฐานข้าวเหนียว/มะพร้าวครีม
    "kt_wrap": dict(c=(96, 152, 58), r=0.4, m=0, p="bleaf"),         # ใบตองห่อขนมตาล (สดกว่าใบรองขันนิด)
    "kt_wrap_dark": dict(c=(70, 124, 44), r=0.45, m=0, p="bleaf"),
    "khanom_tan": dict(c=(244, 168, 44), r=0.75, m=0, p="grain"),    # เนื้อขนมตาลเหลืองส้ม ฟู
    "coconut": dict(c=(246, 243, 232), r=0.9, m=0, p="grain"),       # มะพร้าวขูดโรยหน้า
    "pin": dict(c=(200, 176, 128), r=0.8, m=0, p="plain"),           # ไม้กลัดใบตอง
})
KEYS[:] = list(PAL.keys())

_paint_orig = paint
_face_uv_orig = face_uv


def paint(key, n, seed):
    spec = PAL[key]
    p = spec["p"]
    if p not in ("F_skin", "skin_dark", "rag", "nail", "bronze", "bronze_ring", "bronze_band", "kc_layers", "glossy", "grain", "bleaf"):
        return _paint_orig(key, n, seed)
    base = np.array(spec["c"], dtype=float) / 255.0
    yy, xx = np.mgrid[0:n, 0:n] / n
    v = 1 - yy
    n1, n2, n3 = vnoise(n, 5, seed), vnoise(n, 18, seed + 7), vnoise(n, 56, seed + 13)
    col = np.ones((n, n, 3)) * base * (1 + 0.1 * (n1 - 0.5) + 0.06 * (n2 - 0.5))[..., None]
    h = 0.05 * n3
    rough = np.full((n, n), spec["r"]) + 0.05 * (n2 - 0.5)
    metal = np.full((n, n), float(spec["m"]))
    if p == "F_skin":
        col = np.ones((n, n, 3)) * base * (1 + 0.05 * (vnoise(n, 30, seed + 2) - 0.5))[..., None]
        blot = np.clip((vnoise(n, 22, seed + 3) - 0.55) * 3.5, 0, 1)
        col = col * (1 - 0.25 * blot[..., None]) + 0.25 * blot[..., None] * np.array([0.40, 0.44, 0.36])
        # เส้นเลือดใต้ผิว: เส้นบางจางสีม่วงอมน้ำเงิน (เดิมเส้นหนาดำ + ลายขวาง = ดูเป็นลายไม้)
        vein = np.zeros((n, n))
        for cells, wdt, k in ((5, 0.010, 0.8), (11, 0.007, 0.5), (23, 0.005, 0.3)):
            r_ = np.abs(vnoise(n, cells, seed + 20 + cells) - 0.5)
            vein = np.maximum(vein, np.clip(1 - r_ / wdt, 0, 1) * k)
        vein = vein * np.clip(vnoise(n, 3, seed + 40) * 1.6, 0, 1)  # เส้นเลือดขาดเป็นช่วงๆ ไม่ต่อเป็นตาข่าย
        vc = np.array([0.26, 0.24, 0.36])
        col = col * (1 - 0.45 * vein[..., None]) + 0.45 * vein[..., None] * vc
        # ผิวด่างซีด/ช้ำ + รูขุมขนจุดเล็ก
        # ด่างละเอียด (ลายถี่: แต่ละหน้า map ภาพแยกกัน ลายหยาบจะเห็นเป็นปื้นสี่เหลี่ยมต่อกัน)
        pale = np.clip((vnoise(n, 26, seed + 31) - 0.45) * 2.0, 0, 1)
        col = col * (1 - 0.12 * pale[..., None]) + 0.12 * pale[..., None] * np.array([0.78, 0.80, 0.74])
        bruise = np.clip((vnoise(n, 18, seed + 33) - 0.62) * 3.0, 0, 1)
        col = col * (1 - 0.2 * bruise[..., None]) + 0.2 * bruise[..., None] * np.array([0.34, 0.30, 0.36])
        pores = np.clip((vnoise(n, 120, seed + 35) - 0.8) * 4, 0, 1)
        col = col * (1 - 0.08 * pores[..., None])
        grime = np.clip((vnoise(n, 20, seed + 5) - 0.6) * 2.5, 0, 1)
        col = col * (1 - 0.2 * grime[..., None])
        h = 0.12 * vein + 0.05 * n3 + 0.04 * pores
        rough = rough + 0.15 * grime
    elif p == "skin_dark":
        col = col * (0.6 + 0.6 * n2)[..., None]
        h = 0.2 * n3
    elif p == "rag":
        w = 0.5 + 0.5 * np.sin(xx * 2 * math.pi * 40) * np.sin(yy * 2 * math.pi * 40)
        stain = np.clip((vnoise(n, 7, seed + 2) - 0.5) * 3, 0, 1)
        col = col * (0.75 + 0.35 * n2 + 0.1 * w)[..., None] * (1 - 0.4 * stain[..., None])
        h = 0.3 * w + 0.2 * n2
    elif p == "nail":
        streak = 0.5 + 0.5 * np.sin(xx * 2 * math.pi * 7 + n2 * 4)
        dirt = np.clip((n1 - 0.45) * 3, 0, 1)
        col = col * (0.8 + 0.25 * streak)[..., None]
        col = col * (1 - 0.6 * dirt[..., None]) + 0.6 * dirt[..., None] * np.array([0.22, 0.16, 0.09])
        h = 0.3 * streak
    elif p in ("bronze", "bronze_ring", "bronze_band"):
        tarn = np.clip((vnoise(n, 6, seed + 1) - 0.5) * 2.0, 0, 1)
        col = col * (1 - 0.4 * tarn[..., None]) + 0.4 * tarn[..., None] * np.array([0.30, 0.22, 0.12])
        pat = np.clip((vnoise(n, 30, seed + 4) - 0.84) * 6, 0, 1)
        col = col * (1 - 0.6 * pat[..., None]) + 0.6 * pat[..., None] * np.array([0.30, 0.40, 0.30])
        metal = metal * (1 - 0.5 * tarn) * (1 - pat)
        rough = rough + 0.2 * tarn + 0.3 * pat
        scratch = (np.abs(np.sin((xx * 3 + yy * 0.5 + n2 * 0.3) * 70)) > 0.996).astype(float)
        col = col * (1 + 0.25 * scratch[..., None])
        h = 0.15 * tarn + 0.1 * n3
        if p == "bronze_ring":
            g = (np.abs(((v * 3) % 1.0) - 0.5) < 0.12).astype(float)
            col = col * (1 - 0.45 * g[..., None])
            h = h - 0.5 * g
        if p == "bronze_band":  # กลีบบัว 1 กลีบต่อ 1 ช่องรอบขัน
            d = ((xx - 0.5) / 0.38) ** 2 + ((v - 0.1) / 0.8) ** 2
            line = (np.abs(d - 1) < 0.09) | (np.abs(d - 0.45) < 0.06)
            col = col * (1 - 0.55 * line[..., None])
            h = h - 0.6 * line
    elif p == "kc_layers":
        layer = (np.floor(v * 5) % 2).astype(bool)
        col = np.where(layer[..., None], np.array([0.90, 0.86, 0.72]), base)[..., :] * (0.95 + 0.1 * n2[..., None])
        h = 0.1 * n3
    elif p == "glossy":
        col = col * (0.9 + 0.2 * n1)[..., None]
        sp = np.clip((n3 - 0.7) * 4, 0, 1)
        col = col + 0.15 * sp[..., None]
    elif p == "bleaf":  # เส้นใบขนานแบบใบตอง + ด่างเขียวอ่อน/เข้ม
        vein = 0.5 + 0.5 * np.sin(xx * 2 * math.pi * 26 + n2 * 1.5)
        col = col * (0.85 + 0.2 * vein + 0.15 * (n1 - 0.5))[..., None]
        mid = np.abs(xx - 0.5) < 0.02
        col = np.where(mid[..., None], col * 1.25 + 0.04, col)
        h = 0.25 * vein
    elif p == "grain":
        g = np.random.default_rng(seed).random((n, n))
        col = col * (0.9 + 0.15 * g)[..., None]
        h = 0.4 * g
    return np.clip(col, 0, 1), h, np.clip(rough, 0.04, 1), np.clip(metal, 0, 1)


def face_uv(bm, face, layout, uvl, keyname, world=False):
    """เหมือนของเดิม แต่ world เป็นตัวเลขได้ = จำนวนรอบลายต่อ 1 เมตร (ลายผิวต่อเนื่องข้ามหน้าเล็ก ๆ)"""
    if world is True or not world:
        return _face_uv_orig(bm, face, layout, uvl, keyname, world)
    sc = float(world)
    x0, y0, w = layout[keyname]
    m = 3 if w <= 128 else 6
    n = face.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    pts = []
    for l in face.loops:
        p = l.vert.co
        if ax == 0:
            pts.append((p.y if n.x > 0 else -p.y, p.z))
        elif ax == 1:
            pts.append((-p.x if n.y > 0 else p.x, p.z))
        else:
            pts.append((p.x, p.y if n.z > 0 else -p.y))
    su = [u * sc for u, _ in pts]
    sv = [v * sc for _, v in pts]
    ou, ov = math.floor(min(su)), math.floor(min(sv))
    pu, pv = max(max(su) - ou, 1.0), max(max(sv) - ov, 1.0)
    for l, uu, vv in zip(face.loops, su, sv):
        l[uvl].uv = ((x0 + m + (uu - ou) / pu * (w - 2 * m)) / 1024.0, (1024 - y0 - w + m + (vv - ov) / pv * (w - 2 * m)) / 1024.0)


def to_rbx(p):
    """Blender (x, y, z) -> แกน Roblox (หน้า prop = -Z, ขวา +X) เป็น studs"""
    return (-p[0] / 0.28, p[2] / 0.28, p[1] / 0.28)


def fmt(p):
    return "(%.2f, %.2f, %.2f)" % tuple(p)


def size_rbx(mn, mx):
    return fmt(((mx[0] - mn[0]) / 0.28, (mx[2] - mn[2]) / 0.28, (mx[1] - mn[1]) / 0.28))


def bbox_objs(objs):
    mn = Vector((1e9,) * 3)
    mx = -mn
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w))
            mx = Vector(map(max, mx, w))
    return mn, mx


# ================================================================ 1. ศาลพระภูมิ v2
LEDGE_D = 0.55     # แท่นยื่นหน้า (เมตร) ลึกพอวางขัน ~0.5 ม. กับกระถางธูปคู่กัน
DOOR_W, DOOR_H = 0.30, 0.35
NICHE_BACK_Y = 0.15
POT_XY = (0.28, None)   # กระถางธูปฝั่ง +X ของแท่นยื่น (ฝั่งขวามือของคนที่ยืนดูหน้าศาล)
BOWL_X = -0.17          # จุดวางขันฝั่ง -X
INFO = {}


def islands(bm):
    seen = set()
    out = []
    for v in bm.verts:
        if v.index in seen:
            continue
        st, comp = [v], []
        seen.add(v.index)
        while st:
            x = st.pop()
            comp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    st.append(y)
        out.append(comp)
    return out


def vb(vs):
    return (Vector([min(v.co[i] for v in vs) for i in range(3)]), Vector([max(v.co[i] for v in vs) for i in range(3)]))


def vc(vs):
    a, b = vb(vs)
    return (a + b) / 2


def faces_of(vs):
    return list({f for v in vs for f in v.link_faces})


def geom_of(vs):
    fs = faces_of(vs)
    es = list({e for v in vs for e in v.link_edges})
    return list(vs) + es + fs


def find_dark_block(uv_boxes):
    """หาช่อง 8x8 px ที่ไม่มี UV ใช้งานใน atlas ของศาล แล้วระบายเป็นสีมืด (Color เกือบดำ, Normal เรียบ, Roughness สูง)"""
    imgs = {s: bpy.data.images[f"{SH}_{s}"] for s in ("Color", "Normal", "Roughness", "Metalness")}
    W, H = imgs["Color"].size
    col = np.array(imgs["Color"].pixels[:], dtype=np.float32).reshape(H, W, 4)
    lum = col[..., :3].mean(-1)
    used = np.zeros((H, W), bool)
    for u0, u1, v0, v1 in uv_boxes:
        used[max(0, int(v0 * H) - 3):int(v1 * H) + 4, max(0, int(u0 * W) - 3):int(u1 * W) + 4] = True
    k = 8
    cand = []
    for r in range(8, H - 16, k):
        for c in range(8, W - 16, k):
            if not used[r:r + k, c:c + k].any():
                cand.append((float(lum[r:r + k, c:c + k].max()), r, c))
    cand.sort()
    prev = [x for x in cand if 0.008 < x[0] < 0.025]  # ช่องที่เคยระบายไว้จากการรันครั้งก่อน (ใช้ช่องเดิม)
    _, r, c = (prev or cand)[0]
    vals = {"Color": (0.018, 0.014, 0.012), "Normal": (0.5, 0.5, 1.0), "Roughness": (0.95,) * 3, "Metalness": (0.0,) * 3}
    for s, img in imgs.items():
        px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
        px[r:r + k, c:c + k, :3] = vals[s]
        img.pixels.foreach_set(px.ravel())
        img.save()
    log(f"  dark patch painted at px row {r} col {c} (unused by any UV) in all 4 {SH}_*.png")
    return [((c + 2) / W, (r + 2) / H), ((c + 6) / W, (r + 2) / H), ((c + 6) / W, (r + 6) / H), ((c + 2) / W, (r + 6) / H)]


def build_shrine_v2():
    ob = bpy.data.objects[SH]
    me = ob.data
    log(f"{SH}: custom normals={getattr(me, 'has_custom_normals', '?')}, tris before={eval_tris(ob)}")
    bm = bmesh.new()
    bm.from_mesh(me)
    uvl = bm.loops.layers.uv.active
    I = islands(bm)
    assert len(I) == 100, len(I)

    def chk(i, c, tol=0.012):
        cc = vc(I[i])
        assert (cc - Vector(c)).length < tol, (i, tuple(cc), c)

    for i, c in ((0, (-0.362, -0.36, 0.84)), (3, (0.364, 0.365, 0.84)), (7, (0.001, -0.0015, 1.709)), (14, (0, -0.476, 1.8985)),
                 (22, (0, 0.0825, 2.1575)), (23, (0, -0.1385, 2.089)), (25, (-0.1295, -0.1815, 2.167)), (26, (0.1295, -0.1815, 2.167)),
                 (28, (0, -0.1815, 2.422)), (62, (-0.002, -0.2075, 2.1925)), (64, (0, -0.266, 1.947)), (89, (0.7635, -0.1265, 0.925))):
        chk(i, c)
    house_ids = [i for i in range(20, 63) if i != 23]
    hb0 = vb([v for i in house_ids for v in I[i]])
    uv_boxes = []
    for f in bm.faces:
        us = [l[uvl].uv for l in f.loops]
        uv_boxes.append((min(u.x for u in us), max(u.x for u in us), min(u.y for u in us), max(u.y for u in us)))
    dark_uv = find_dark_block(uv_boxes)

    base_ids = list(range(0, 20)) + list(range(89, 100))
    ladder_ids = list(range(89, 100))
    # (a) หมุนฐานทั้งชุด -90° รอบแกนตั้ง: ด้าน +X เดิม (บันได/ช่องราว) มาอยู่ด้านหน้า -Y ตรงกับหน้าศาล
    bmesh.ops.rotate(bm, verts=[v for i in base_ids for v in I[i]], cent=(0, 0, 0), matrix=Matrix.Rotation(-math.pi / 2, 3, "Z"))
    # (b) แท่นยื่นหน้า: ก๊อปแผ่นพื้นเดิม ตัดเหลือ 0.55 ม. (UV ตัดตามจริง ลายไม้ไม่ยืด) แล้วเลื่อนไปหน้า
    dup = bmesh.ops.duplicate(bm, geom=geom_of(I[7]))
    dverts = [g for g in dup["geom"] if isinstance(g, bmesh.types.BMVert)]
    cut = bmesh.ops.bisect_plane(bm, geom=list(dup["geom"]), dist=1e-6, plane_co=(0, LEDGE_D - 0.505, 0), plane_no=(0, 1, 0), clear_outer=True)
    lverts = [v for v in dverts if v.is_valid] + [g for g in cut["geom_cut"] if isinstance(g, bmesh.types.BMVert) and g not in dverts]
    lverts = list(set(lverts))
    bmesh.ops.translate(bm, verts=lverts, vec=(0, -LEDGE_D, 0))
    lb = vb(lverts)
    # เสาค้ำแท่นยื่น 2 ต้น (ก๊อปเสาหน้าเดิม)
    front_stilts = [i for i in range(4) if vc(I[i]).y < 0]
    for i in front_stilts:
        d2 = bmesh.ops.duplicate(bm, geom=geom_of(I[i]))
        bmesh.ops.translate(bm, verts=[g for g in d2["geom"] if isinstance(g, bmesh.types.BMVert)], vec=(0, -(LEDGE_D + 0.03), 0))
    # บันไดเลื่อนไปพาดขอบหน้าแท่นยื่น
    bmesh.ops.translate(bm, verts=[v for i in ladder_ids for v in I[i]], vec=(0, -(LEDGE_D - 0.003), 0))
    deck_top = lb[1].z
    deck_y = (lb[0].y + (-0.505)) / 2  # กลางส่วนที่ยื่นออกมาจากแท่นเดิม
    # (c) เสาหน้าศาลคู่ใน ขยับออกให้ช่องประตูกว้าง 0.30 ม. ไม่ถูกบัง
    bmesh.ops.translate(bm, verts=I[25], vec=(-0.05, 0, 0))
    bmesh.ops.translate(bm, verts=I[26], vec=(0.05, 0, 0))
    # พวงมาลัยหน้าศาล: ยกขึ้นเป็นซุ้มตื้น ๆ เหนือประตู (ไม่บังช่องที่มือผีเอื้อมออกมา)
    for v in I[62]:
        v.co.z = 2.354 - (2.354 - v.co.z) * 0.35 + 0.03
    # กระถางธูป + ธูป: ไม่ปั้น ใช้ของเดิมที่มีอยู่ใน Roblox (ลบออกจากโมเดล) — เว้นที่บนแท่นยื่นไว้ให้วาง (log ตำแหน่ง)
    pot_hz = vb(I[64])[1].z - vb(I[64])[0].z
    pot_to = Vector((POT_XY[0], deck_y, deck_top))
    bmesh.ops.delete(bm, geom=list(set(I[63] + I[64])), context="VERTS")
    for n in ("Incense1", "Incense2", "Incense3", "Incense1_Neon", "Incense2_Neon", "Incense3_Neon"):
        o_ = bpy.data.objects.get(n)
        if o_:
            bpy.data.objects.remove(o_)
    # ช่องประตูในผนังหน้าตัวเรือน (isl22 = กล่องลบมุม หน้าตรง normal -Y)
    front = [f for f in faces_of(I[22]) if f.normal.y < -0.99]
    assert len(front) == 1
    f = front[0]
    smooth = f.smooth
    cs = [(l.vert, l.vert.co.copy(), l[uvl].uv.copy()) for l in f.loops]
    x0, x1 = min(c[1].x for c in cs), max(c[1].x for c in cs)
    z0, z1 = min(c[1].z for c in cs), max(c[1].z for c in cs)
    yF = sum(c[1].y for c in cs) / 4

    def corner(sx, sz):
        return min(cs, key=lambda c: (c[1].x - (x1 if sx else x0)) ** 2 + (c[1].z - (z1 if sz else z0)) ** 2)

    c00, c10, c11, c01 = corner(0, 0), corner(1, 0), corner(1, 1), corner(0, 1)

    def uv_at(x, z):
        s, t = (x - x0) / (x1 - x0), (z - z0) / (z1 - z0)
        return c00[2] * (1 - s) * (1 - t) + c10[2] * s * (1 - t) + c11[2] * s * t + c01[2] * (1 - s) * t

    hx0, hx1 = -DOOR_W / 2, DOOR_W / 2
    hz0 = z0 + 0.003
    hz1 = hz0 + DOOR_H
    assert hz1 < z1 - 0.05
    bmesh.ops.delete(bm, geom=[f], context="FACES_ONLY")
    h = [bm.verts.new((hx0, yF, hz0)), bm.verts.new((hx1, yF, hz0)), bm.verts.new((hx1, yF, hz1)), bm.verts.new((hx0, yF, hz1))]
    bk = [bm.verts.new((hx0, NICHE_BACK_Y, hz0)), bm.verts.new((hx1, NICHE_BACK_Y, hz0)), bm.verts.new((hx1, NICHE_BACK_Y, hz1)), bm.verts.new((hx0, NICHE_BACK_Y, hz1))]
    o = [c00[0], c10[0], c11[0], c01[0]]
    frame_faces = [[o[0], o[1], h[1], h[0]], [o[1], o[2], h[2], h[1]], [o[2], o[3], h[3], h[2]], [o[3], o[0], h[0], h[3]]]
    for q in frame_faces:
        nf = bm.faces.new(q)
        nf.smooth = smooth
        nf.normal_update()
        if nf.normal.y > 0:
            nf.normal_flip()
        for l in nf.loops:
            l[uvl].uv = uv_at(l.vert.co.x, l.vert.co.z)
    ncen = Vector((0, (yF + NICHE_BACK_Y) / 2, (hz0 + hz1) / 2))
    niche_faces = [[h[0], h[1], bk[1], bk[0]], [h[3], bk[3], bk[2], h[2]], [h[0], bk[0], bk[3], h[3]], [h[1], h[2], bk[2], bk[1]], [bk[0], bk[1], bk[2], bk[3]]]
    for q in niche_faces:
        nf = bm.faces.new(q)
        nf.smooth = False
        nf.normal_update()
        if nf.normal.dot(ncen - nf.calc_center_median()) < 0:
            nf.normal_flip()
        for l, uv in zip(nf.loops, dark_uv):
            l[uvl].uv = uv
    # ทับหลังเหนือประตู (ก๊อปคานทองเดิม ย่อลง)
    d3 = bmesh.ops.duplicate(bm, geom=geom_of(I[28]))
    lv = [g for g in d3["geom"] if isinstance(g, bmesh.types.BMVert)]
    a, b = vb(lv)
    cc = (a + b) / 2
    sx, sy, sz = (DOOR_W + 0.05) / (b.x - a.x), 0.028 / (b.y - a.y), 0.03 / (b.z - a.z)
    newc = Vector((0, yF - 0.014, hz1 + 0.017))
    for v in lv:
        d = v.co - cc
        v.co = newc + Vector((d.x * sx, d.y * sy, d.z * sz))
    # ลบแผ่นประตูทึบเดิม
    bmesh.ops.delete(bm, geom=list(I[23]), context="VERTS")
    hb1 = vb([v for i in house_ids for v in I[i]] + lv)
    bm.to_mesh(me)
    bm.free()
    me.update()

    mn, mx = bbox_objs([ob])
    cen = (mn + mx) / 2
    door_c = Vector((0, yF, (hz0 + hz1) / 2))
    ledge_c = Vector(((lb[0].x + lb[1].x) / 2, deck_y, deck_top))
    pot_c = Vector((pot_to.x, pot_to.y, deck_top + pot_hz / 2))
    bowl_c = Vector((BOWL_X, deck_y, deck_top))
    INFO.update(door=door_c, door_bottom=hz0, bowl=bowl_c, deck_top=deck_top, deck_y=deck_y)
    rel = lambda p: fmt(to_rbx(p - cen))
    log(f"{SH} v2 tris={eval_tris(ob)}  bbox m min={fmt(mn)} max={fmt(mx)} -> size studs (X,Y,Z)={size_rbx(mn, mx)}")
    log(f"  bbox centre (Blender m) {fmt(cen)}")
    log(f"  ledge (front deck) Blender y {lb[0].y:.3f}..-0.505 x {lb[0].x:.3f}..{lb[1].x:.3f} top z {deck_top:.3f}; depth {(-0.505 - lb[0].y):.3f} m")
    log(f"  ledge top centre rel studs {rel(ledge_c)}")
    log(f"  incense pot spot (วางกระถางธูปเดิมของ Roblox ตรงนี้) rel studs {rel(pot_c)}  (Blender {fmt(pot_c)})")
    log(f"  offering bowl spot (ledge surface) rel studs {rel(bowl_c)}  (Blender {fmt(bowl_c)})")
    log(f"  opening centre rel studs {rel(door_c)}  (Blender {fmt(door_c)}), facing Roblox -Z; size {DOOR_W}x{DOOR_H} m, niche depth {NICHE_BACK_Y - yF:.3f} m, bottom z {hz0:.3f}")
    log(f"  house part bbox before {fmt(hb0[1] - hb0[0])} after {fmt(hb1[1] - hb1[0])} (m)")
    mat = ob.data.materials[0]
    for nd in mat.node_tree.nodes:
        if nd.type == "TEX_IMAGE" and nd.image and nd.image.name.endswith("_Color"):
            mat.node_tree.nodes.active = nd
    return [ob]


# ================================================================ 2. มือผี
def etube(b, pts, rx, rz, ups, keys, n=10, caps=(True, True)):
    """ท่อหน้าตัดวงรี (rx ตามแกนข้าง, rz ตามแกน up) ตามจุด pts; ups = ทิศหลังมือของแต่ละจุด"""
    pts = [Vector(p) for p in pts]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        t.normalize()
        up = Vector(ups[i])
        sd = t.cross(up).normalized()
        up = sd.cross(t).normalized()
        rings.append([b._v(p + sd * math.cos(2 * math.pi * j / n) * rx[i] + up * math.sin(2 * math.pi * j / n) * rz[i]) for j in range(n)])
    for i, (a, c) in enumerate(zip(rings[:-1], rings[1:])):
        for j in range(n):
            k = (j + 1) % n
            b.face([a[j], a[k], c[k], c[j]], keys[min(i, len(keys) - 1)])
    if caps[0]:
        b.face(list(reversed(rings[0])), keys[0])
    if caps[1]:
        b.face(rings[-1], keys[-1])
    return rings


PALM = 1.6   # ฝ่ามือใหญ่ขึ้น (กว้าง/ยาว) ให้ดูเป็นมือผีชัดๆ เวลาเอื้อมออกจากศาล
PALM_T = 2.0  # ความหนาฝ่ามือ (เดิมบางจนมองเห็นแต่นิ้ว)
FING = 1.18  # นิ้วยาวและอวบขึ้นตาม (น้อยกว่าฝ่ามือ)
WRIST_Y, KN_Y = -0.68, -0.68 - 0.11 * PALM


HAND_RIG = {}  # ชื่อนิ้ว -> {"pts": [โคน, ข้อ1, ข้อ2, ปลาย], "ups": [...]} ใช้สร้างกระดูก (rig_ghost_hand)


def finger(b, base, fwd, up, lens, curls, rs, n=8, nail_len=0.045, flare=True, name=None):
    """นิ้วกระดูก 3 ข้อ งอ curls (องศา) ตามข้อ + เล็บยาวงุ้ม คืนตำแหน่งปลายนิ้ว"""
    f, u = Vector(fwd).normalized(), Vector(up).normalized()
    pts, ups = [Vector(base)], [u.copy()]
    for L, ang in zip(lens, curls):
        sd = f.cross(u).normalized()
        R = Matrix.Rotation(-math.radians(ang), 3, sd)
        f, u = R @ f, R @ u
        p0 = pts[-1]
        for k in (1, 2, 3):
            pts.append(p0 + f * L * k / 3)
            ups.append(u.copy())
    # ข้อนิ้วปูด (กระดูก) ช่วงกลางข้อคอด ปลายนิ้วเรียวแหลม
    r = [rs[0] * 1.15, rs[0] * 0.66, rs[0] * 0.64, rs[0] * 1.02, rs[1] * 0.66, rs[1] * 0.64, rs[1] * 0.98, rs[2] * 0.68, rs[2] * 0.6, rs[2] * 0.34]
    # โคนนิ้วบานออกฝังเข้าไปในฝ่ามือ (เนื้อระหว่างนิ้ว): ฝ่ามือไล่เรียวเข้าหานิ้ว ไม่ใช่นิ้วเสียบปลายฝ่ามือ
    f0 = (pts[1] - pts[0]).normalized()
    if flare:  # บานด้านข้าง (เนื้อระหว่างนิ้ว) ความหนาเท่าปลายฝ่ามือที่เรียวลงมา
        pre = [pts[0] - f0 * 0.034, pts[0] - f0 * 0.018, pts[0] - f0 * 0.006]
        pre_rx = [rs[0] * 2.0, rs[0] * 1.65, rs[0] * 1.3]
        pre_rz = [rs[0] * 0.95, rs[0] * 0.92, rs[0] * 0.9]
        pre = [q - u * rs[0] * 0.25 for q in pre]  # ค่อนลงด้านฝ่ามือ ไม่นูนเหนือหลังมือ
    else:
        pre, pre_rx, pre_rz = [], [], []
    etube(b, pre + pts, pre_rx + [x * 1.1 for x in r], pre_rz + [x * 0.9 for x in r], [ups[0]] * len(pre) + ups, ["F_skin"], n=n)
    # เล็บ: เริ่มกลางข้อปลาย ยื่นเลยปลายนิ้วแล้วงุ้มลง
    sd = f.cross(u).normalized()
    npts = [pts[7] + ups[7] * r[7] * 0.85, pts[8] + ups[8] * r[8] * 0.85, pts[9] + ups[9] * 0.002 + f * 0.003]
    nups = [ups[7], ups[8], ups[9]]
    fe, ue = f.copy(), u.copy()
    for k in range(3):
        R = Matrix.Rotation(-math.radians(13), 3, sd)
        fe, ue = R @ fe, R @ ue
        npts.append(npts[-1] + fe * nail_len / 3)
        nups.append(ue.copy())
    wd = [0.0105, 0.011, 0.0105, 0.008, 0.005, 0.0016]
    th = [0.0018, 0.0024, 0.0026, 0.0024, 0.002, 0.0012]
    etube(b, npts, [w / 2 * rs[2] / 0.0068 for w in wd], [t / 2 for t in th], nups, ["nail"], n=6)
    if name:
        HAND_RIG[name] = {"pts": [pts[0].copy(), pts[3].copy(), pts[6].copy(), pts[9].copy()], "ups": [ups[1].copy(), ups[4].copy(), ups[7].copy()]}
    return pts[9], npts[-1]


def make_ghost_hand():
    b = B("GhostHand")
    b.bevel = False
    b.sa = 180  # เรียบทั้งชิ้น (เดิม 70° เห็นเหลี่ยมท่อ = ดูเป็นไม้กลึง) + Subdivision ตอน export
    b.worlduv = 4.0  # 0.25 ม. ต่อ 1 รอบลายผิว
    rng = np.random.default_rng(7)
    # แขนท่อนล่าง (ผอม เห็นกระดูกข้อมือ) จาก origin ไปข้อมือ
    ys = [0.0, -0.05, -0.1, -0.14, -0.21, -0.3, -0.39, -0.48, -0.55, -0.6, -0.64, WRIST_Y]
    # ผอมแห้งเห็นกระดูก: กล้ามแขนลีบ ช่วงข้อมือคอด แล้วบานออกเป็นฝ่ามือ ไม่เป็นท่อกลมเท่ากันทั้งท่อน
    rxs = [0.038, 0.039, 0.038, 0.036, 0.033, 0.030, 0.027, 0.0245, 0.023, 0.025, 0.031, 0.050 * PALM / 2]
    rzs = [0.030, 0.031, 0.030, 0.027, 0.024, 0.021, 0.019, 0.017, 0.016, 0.017, 0.019, 0.024 * PALM_T / 2]
    pts = [(0.003 * math.sin(i * 1.7), y, 0.004 * math.sin(i * 0.9) - 0.004 * (i / len(ys)) ** 2) for i, y in enumerate(ys)]
    keys = ["skin_dark", "skin_dark", "skin_dark"] + ["F_skin"] * 9
    # (แขน + ฝ่ามือเป็นท่อเดียวกัน สร้างหลังคำนวณฝ่ามือด้านล่าง: ไม่มีรอยต่อตรงข้อมือ)
    # สันกระดูกแขน (ulna) นูนตามยาวด้านหลังแขน + เอ็นใต้ผิว
    b.tube([(-0.012, -0.30, 0.016), (-0.016, -0.48, 0.014), (-0.019, WRIST_Y + 0.02, 0.011)], [0.006, 0.0065, 0.007], "F_skin", n=8)
    b.tube([(0.010, -0.40, 0.013), (0.012, -0.55, 0.012), (0.014, WRIST_Y + 0.01, 0.010)], [0.004, 0.0042, 0.0045], "F_skin", n=8)
    # ปุ่มกระดูกข้อมือ (ulna) ด้าน -X
    b.ellipsoid((-0.021, WRIST_Y + 0.035, 0.006), (0.008, 0.012, 0.008), "F_skin", nu=8, nv=5)
    # ฝ่ามือ: งุ้มลงจากข้อมือ (ข้อมือหักลง ~12°)
    droop = math.radians(12)
    pdir = Vector((0, -math.cos(droop), -math.sin(droop)))
    U = pdir.cross(Vector((1, 0, 0))).normalized()
    if U.z < 0:
        U = -U
    W = Vector((0, WRIST_Y + 0.008, -0.004))
    L = KN_Y - WRIST_Y
    psec = [0.0, 0.2, 0.45, 0.7, 0.9, 1.0]
    pw = [w * PALM for w in (0.050, 0.058, 0.066, 0.072, 0.074, 0.068)]
    pt = [t * PALM_T for t in (0.024, 0.026, 0.026, 0.022, 0.016, 0.011)]  # ปลายฝ่ามือเรียวบางลงจนใกล้ความหนานิ้ว
    ppts = [W + pdir * (-L) * s for s in psec]
    # ท่อเดียว: แขน (ถึงก่อนข้อมือ) -> ฝ่ามือ
    etube(b, [Vector(q) for q in pts[:-1]] + ppts, rxs[:-1] + [w / 2 for w in pw], rzs[:-1] + [t / 2 for t in pt],
          [(0, 0, 1)] * (len(pts) - 1) + [U] * len(ppts), keys[:-1] + ["F_skin"] * len(ppts), n=14)
    K = W + pdir * (-L)
    HAND_RIG["_hand"] = {"wrist": W.copy(), "knuckle": K.copy(), "up": U.copy()}
    # กระดูกฝ่ามือนูนที่หลังมือ (เส้นเอ็น)
    side = Vector((1, 0, 0))
    for xo in (0.022 * PALM, 0.008 * PALM, -0.008 * PALM, -0.022 * PALM):
        # เอ็นหลังมือ: ไล่จมลงตามฝ่ามือที่เรียวบางตรงปลาย (ไม่โผล่เป็นตุ่มที่โคนนิ้ว)
        b.tube([W + side * xo * 0.6 + U * 0.007 * PALM - pdir * 0.01, W + side * xo * 0.85 + U * 0.0085 * PALM + pdir * (-L * 0.55),
                K + side * xo + U * 0.0035 * PALM - pdir * 0.012], [0.0026 * PALM, 0.0032 * PALM, 0.0022 * PALM], "F_skin", n=6)
    tips = {}
    fdata = [  # ชื่อ, x ที่ข้อนิ้ว, มุมกาง, ความยาว 3 ข้อ, มุมงอ 3 ข้อ, รัศมีข้อ
        ("index", 0.025, 8, (0.072, 0.047, 0.033), (16, 34, 24), (0.0092, 0.0080, 0.0068)),
        ("middle", 0.008, 2, (0.080, 0.052, 0.035), (20, 40, 28), (0.0096, 0.0083, 0.0070)),
        ("ring", -0.009, -4, (0.074, 0.049, 0.033), (25, 45, 30), (0.0090, 0.0078, 0.0066)),
        ("pinky", -0.025, -11, (0.058, 0.039, 0.029), (31, 50, 32), (0.0078, 0.0068, 0.0058)),
    ]
    for name, xo, fan, lens, curls, rs in fdata:
        xo, lens, rs = xo * PALM, tuple(v * FING for v in lens), tuple(v * FING for v in rs)
        base = K + side * xo - pdir * (0.014 + (0.0 if name in ("index", "middle") else 0.004 if name == "ring" else 0.01))  # โคนนิ้วฝังในฝ่ามือ
        fw = Matrix.Rotation(math.radians(fan), 3, U) @ pdir
        tip, ntip = finger(b, base, fw, U, lens, curls, rs, n=8, name=name)
        tips[name] = tip
    # นิ้วโป้ง: ออกจากข้างฝ่ามือฝั่ง +X งอเข้าหานิ้วอื่น (ท่ากำลังจะคว้า)
    tb = W + pdir * (-L * 0.42) + side * 0.03 * PALM + U * -0.004
    tf = Vector((0.55, -0.62, -0.5)).normalized()
    tu = Vector((0.6, 0.1, 0.8))
    tu = (tu - tf * tu.dot(tf)).normalized()
    # งอเข้าด้านใน (ไปทาง -X) แทนการงอลงอย่างเดียว: หมุนแกน up ให้ฝ่านิ้วหันเข้าหานิ้วอื่น
    tu = Matrix.Rotation(math.radians(-35), 3, tf) @ tu
    tip, _ = finger(b, tb, tf, tu, tuple(v * FING for v in (0.05, 0.042, 0.032)), (8, 22, 24), tuple(v * FING for v in (0.0115, 0.0098, 0.0080)), n=8, nail_len=0.04 * FING, flare=False, name="thumb")
    tips["thumb"] = tip
    # แขนเสื้อขาดรุ่งริ่ง (ปลายแขนด้านในศาล)
    n = 14
    rim = [(-0.125 - 0.05 * rng.random() - (0.02 if j % 3 == 0 else 0)) for j in range(n)]
    flare = [0.003 + 0.008 * rng.random() for j in range(n)]

    def ring(fn):
        return [b._v(fn(j, 2 * math.pi * j / n)) for j in range(n)]

    rs_ = [
        ring(lambda j, a: (0.054 * math.cos(a), 0.012, 0.046 * math.sin(a))),
        ring(lambda j, a: (0.056 * math.cos(a), -0.06, 0.048 * math.sin(a) - 0.002)),
        ring(lambda j, a: ((0.056 + flare[j]) * math.cos(a), rim[j], (0.048 + flare[j]) * math.sin(a) - 0.006)),
        ring(lambda j, a: ((0.050 + flare[j]) * math.cos(a), rim[j] + 0.004, (0.042 + flare[j]) * math.sin(a) - 0.006)),
        ring(lambda j, a: (0.049 * math.cos(a), -0.06, 0.041 * math.sin(a) - 0.002)),
        ring(lambda j, a: (0.048 * math.cos(a), 0.012, 0.040 * math.sin(a))),
    ]
    for i in range(len(rs_)):
        a, c = rs_[i], rs_[(i + 1) % len(rs_)]
        for j in range(n):
            k = (j + 1) % n
            b.face([a[j], a[k], c[k], c[j]], "rag")
    # เศษผ้าห้อย 3 ชิ้น
    for ang, ln in ((-100, 0.07), (-60, 0.05), (-140, 0.055)):
        a = math.radians(ang)
        p0 = Vector((0.054 * math.cos(a), -0.14, 0.046 * math.sin(a)))
        p1 = p0 + Vector((0.004, -0.03, -ln))
        b.beam(p0, p1, 0.028, 0.0025, "rag", side=(math.cos(a + math.pi / 2), 0, math.sin(a + math.pi / 2)))
    grip = (tips["thumb"] + tips["middle"]) / 2
    return b, grip, tips



# ---------------------------------------------------------------- กระดูกมือผี + ท่ากำขนม
GRAB = {  # องศางอเพิ่มต่อข้อ ตอนกำ (ข้อโคน, ข้อกลาง, ข้อปลาย) / ตอนแบเตรียมคว้า (ติดลบ = เหยียด)
    "index": ((24, 28, 18), (-14, -16, -10)),  # กำรอบชิ้นขนม (อุ้งมือ) ไม่ใช่กำหมัดแน่น
    "middle": ((26, 30, 20), (-14, -18, -12)),
    "ring": ((27, 30, 20), (-12, -16, -10)),
    "pinky": ((28, 30, 18), (-10, -14, -10)),
    "thumb": ((22, 26, 18), (-16, -10, -8)),
}
GRAB_FRAMES = {"rest": 1, "open": 12, "closed": 22, "hold": 40}


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (p - (a + ab * t)).length


def rig_ghost_hand(ob):
    """Armature "GhostHandRig" (Forearm -> Hand -> นิ้วละ 3 ข้อ) ผูกผิวด้วยน้ำหนักตามระยะใกล้กระดูก
    แล้วทำ action "Grab": rest -> แบนิ้วเตรียมคว้า -> กำ -> ค้าง"""
    h = HAND_RIG["_hand"]
    arm_data = bpy.data.armatures.new("GhostHandRig")
    arm = bpy.data.objects.new("GhostHandRig", arm_data)
    for c in ob.users_collection:
        c.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    segs = {}

    def bone(name, head, tail, up, parent=None):
        b = eb.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(Vector(up))
        if parent:
            b.parent = eb[parent]
            b.use_connect = (segs[parent][1] - Vector(head)).length < 1e-4
        segs[name] = (Vector(head), Vector(tail))

    bone("Forearm", (0, 0, 0), h["wrist"], (0, 0, 1))
    bone("Hand", h["wrist"], h["knuckle"], h["up"], "Forearm")
    for fname in ("index", "middle", "ring", "pinky", "thumb"):
        d = HAND_RIG[fname]
        pts, ups = d["pts"], d["ups"]
        prev = "Hand"
        for k in range(3):
            nm = f"{fname.capitalize()}{k + 1}"
            bone(nm, pts[k], pts[k + 1], ups[k], prev)
            prev = nm
    bpy.ops.object.mode_set(mode="OBJECT")
    # น้ำหนักผิว: ใกล้กระดูกไหนมากสุดเป็นของกระดูกนั้น ผสมนุ่มๆ ตรงข้อต่อ
    me = ob.data
    groups = {n: ob.vertex_groups.new(name=n) for n in segs}
    names = list(segs)
    for v in me.vertices:
        p = ob.matrix_world @ v.co
        ds = sorted((seg_dist(p, *segs[n]), n) for n in names)
        best = ds[0][0]
        pick = [(d_, n) for d_, n in ds if d_ <= best * 1.35 + 0.002][:3]
        ws = [1.0 / (d_ + 0.002) ** 4 for d_, _ in pick]
        tot = sum(ws)
        for w, (_, n) in zip(ws, pick):
            groups[n].add([v.index], w / tot, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    while ob.modifiers[0] != mod:  # ก่อน Subsurf
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    ob.parent = arm
    # ---- action Grab
    arm.animation_data_create()
    act = bpy.data.actions.new("Grab")
    arm.animation_data.action = act
    pb = arm.pose.bones
    for b_ in pb:
        b_.rotation_mode = "XYZ"

    def tip_world(fname):
        return arm.matrix_world @ pb[f"{fname.capitalize()}3"].tail

    # ทิศงอ: หมุนรอบแกน X ของกระดูก ด้านไหนปลายนิ้วเข้าหากลางฝ่ามือ
    sign = {}
    palm_c = (h["wrist"] + h["knuckle"]) / 2 - h["up"] * 0.04
    for fname in GRAB:
        bpy.context.view_layer.update()
        base = tip_world(fname)
        for k in (1, 2, 3):
            pb[f"{fname.capitalize()}{k}"].rotation_euler = (math.radians(20), 0, 0)
        bpy.context.view_layer.update()
        moved = tip_world(fname)
        sign[fname] = 1 if (moved - palm_c).length < (base - palm_c).length else -1
        for k in (1, 2, 3):
            pb[f"{fname.capitalize()}{k}"].rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()

    def key(frame, mode):
        for fname, (closed, opened) in GRAB.items():
            angs = (0, 0, 0) if mode == "rest" else opened if mode == "open" else closed
            for k in range(3):
                b_ = pb[f"{fname.capitalize()}{k + 1}"]
                b_.rotation_euler = (math.radians(angs[k] * sign[fname]), 0, 0)
                b_.keyframe_insert("rotation_euler", frame=frame)
        hb_ = pb["Hand"]
        hb_.rotation_euler = (math.radians({"rest": 0, "open": -6, "closed": 10}[mode] * sign["middle"]), 0, 0)
        hb_.keyframe_insert("rotation_euler", frame=frame)

    for mode, fr in GRAB_FRAMES.items():
        key(fr, "closed" if mode == "hold" else mode)
    scn = bpy.context.scene
    scn.frame_start, scn.frame_end = 1, GRAB_FRAMES["hold"]
    scn.render.fps = 30
    scn.frame_set(1)
    log(f"  rig: {len(segs)} bones, curl sign {sign}, action Grab frames {GRAB_FRAMES} @30fps")
    return arm


# ================================================================ 3. ขันลงหิน + ขนม
Z_GRIP = 0.065  # กลางก้าน (จุดกำ) จากพื้น


def lathe_k(b, prof, n, cap_key):
    rings = []
    for r, z, _ in prof:
        z -= Z_GRIP
        if r < 1e-4:
            rings.append([b._v((0, 0, z))] * n)
        else:
            rings.append([b._v((r * math.cos(2 * math.pi * j / n), r * math.sin(2 * math.pi * j / n), z)) for j in range(n)])
    for i, (a, c) in enumerate(zip(rings[:-1], rings[1:])):
        for j in range(n):
            k = (j + 1) % n
            b.face([a[j], a[k], c[k], c[j]], prof[i][2])
    if prof[0][0] > 1e-4:
        b.face(list(reversed(rings[0])), cap_key)


BOWL_PROF = [
    (0.072, 0.000, "bronze"), (0.076, 0.006, "bronze"), (0.072, 0.014, "bronze"), (0.052, 0.022, "bronze"),
    (0.032, 0.032, "bronze"), (0.023, 0.046, "bronze"), (0.020, 0.065, "bronze"), (0.022, 0.084, "bronze_ring"),
    (0.031, 0.094, "bronze_ring"), (0.025, 0.104, "bronze"), (0.046, 0.117, "bronze"), (0.088, 0.127, "bronze"),
    (0.128, 0.150, "bronze_band"), (0.152, 0.172, "bronze"), (0.161, 0.186, "bronze_ring"), (0.164, 0.193, "bronze"),
    (0.160, 0.198, "bronze_in"), (0.151, 0.192, "bronze_in"), (0.138, 0.172, "bronze_in"), (0.105, 0.150, "bronze_in"),
    (0.060, 0.138, "bronze_in"), (0.0, 0.134, None),
]


LEAF_T = 0.0025   # ความหนาแผ่นใบตอง (ม.)


def leaf_sheet(b, cx, cy, z0, length, width, key, yaw=0.0):
    """แผ่นใบตองแบน ปลายแหลมสองด้าน (ทรงเรือ) หนา LEAF_T วางราบที่ระดับ z0 (ผิวล่าง)"""
    N = 16
    outline = []
    for k in range(N + 1):  # ขอบบน: จากปลายซ้ายไปปลายขวา
        t = k / N
        x = (t - 0.5) * length
        half = width / 2 * math.sin(math.pi * t) ** 0.6
        outline.append((x, half))
    pts = outline + [(x, -h) for x, h in reversed(outline[1:-1])]
    M = Matrix.Translation((cx, cy, z0)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
    with b.xf(M):
        top = [b._v((x, y, LEAF_T)) for x, y in pts]
        bot = [b._v((x, y, 0.0)) for x, y in pts]
        c_t, c_b = b._v((0, 0, LEAF_T)), b._v((0, 0, 0))
        n = len(pts)
        for a in range(n):
            c = (a + 1) % n
            b.face([c_t, top[a], top[c]], key)
            b.face([c_b, bot[c], bot[a]], key)
            b.face([top[a], bot[a], bot[c], top[c]], key)


def make_leaf_sweets():
    """ขนมตาลบนใบตอง (ไม่มีขัน/จาน) — origin = กลางใต้แผ่นใบตอง
    LeafTray  แผ่นใบตองรอง (ทรงเรือ ปลายแหลม)
    OpenWrap  ใบตองห่อที่แกะคลี่ออก (มือผีไม่หยิบ)
    SweetCake ขนมตาลก้อนกลมที่แกะแล้ว + มะพร้าวขูด (ชิ้นที่ถือ/ถวาย มือผีหยิบไปชิ้นนี้)
    Wrapped   ห่อขนมตาลที่ยังไม่แกะ 3 ห่อ (วางที่จุดหยิบเท่านั้น เกมไม่เอาติดมือไป)"""
    tray = B("LeafTray"); tray.bevel = False; tray.sa = 40
    leaf_sheet(tray, 0, 0, 0.0, 0.42, 0.22, "banana_leaf")
    tray.tube([(-0.2, 0, LEAF_T + 0.0005), (0.2, 0, LEAF_T + 0.0005)], [0.0025, 0.0025], "kt_wrap_dark", n=4)  # เส้นกลางใบ
    opn = B("OpenWrap"); opn.bevel = False; opn.sa = 40
    cake = B("SweetCake"); cake.bevel = False; cake.sa = 50
    wr = B("Wrapped"); wr.bevel = False; wr.sa = 50
    z = LEAF_T
    # ห่อที่แกะแล้วด้านหน้า (ฝั่ง -Y = หน้า): ใบห่อคลี่ + ปีกยกสองข้าง
    ox, oy, yaw = 0.0, -0.035, 25
    with opn.xf(Matrix.Translation((ox, oy, z)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")):
        opn.box(-0.05, 0.05, -0.032, 0.032, 0.0, 0.0025, "kt_wrap")
        for sg in (-1, 1):
            with opn.xf(Matrix.Translation((sg * 0.05, 0, 0.0)) @ Matrix.Rotation(math.radians(-28 * sg), 4, "Y")):
                opn.box(0.0 if sg > 0 else -0.032, 0.032 if sg > 0 else 0.0, -0.032, 0.032, 0.0, 0.0025, "kt_wrap_dark")
    with cake.xf(Matrix.Translation((ox, oy, z + 0.0025)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")):
        R = 0.03  # ขนมตาลก้อนกลม (ทรงกลมอย่างเดียว)
        cake.ellipsoid((0, 0, R), (R, R, R), "khanom_tan", nu=14, nv=9)
        rng = np.random.default_rng(7)
        for _ in range(8):  # มะพร้าวขูดโรยบนหัว
            x, y = rng.uniform(-0.011, 0.011), rng.uniform(-0.011, 0.011)
            a = rng.uniform(0, math.pi)
            dx, dy = 0.007 * math.cos(a), 0.007 * math.sin(a)
            zz = R + math.sqrt(max(0.0, R * R - x * x - y * y)) - 0.001 + rng.uniform(0, 0.002)
            cake.tube([(x - dx, y - dy, zz), (x + dx, y + dy, zz + 0.002)], [0.0016, 0.0013], "coconut", n=3)
    # ห่อที่ยังไม่แกะ 3 ห่อ ตั้งเรียงด้านหลัง (ฝั่ง +Y)
    for k, (x, y, yw) in enumerate(((-0.07, 0.045, -10), (0.0, 0.052, 0), (0.07, 0.045, 10))):
        w, d, h, roof = 0.052, 0.042, 0.075 + 0.006 * (k == 1), 0.045
        key, rk = ("kt_wrap", "kt_wrap_dark") if k != 1 else ("kt_wrap_dark", "kt_wrap")
        with wr.xf(Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(yw), 4, "Z")):
            hw, hd = w / 2, d / 2
            bot = [wr._v((xx, yy, 0)) for xx, yy in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))]
            top = [wr._v((xx * 0.92, yy * 0.8, h)) for xx, yy in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd))]
            for a in range(4):
                c = (a + 1) % 4
                wr.face([bot[a], bot[c], top[c], top[a]], key)
            r0, r1 = wr._v((-hw * 0.95, 0, h + roof)), wr._v((hw * 0.95, 0, h + roof))
            wr.face([top[0], top[1], r1, r0], rk)
            wr.face([top[2], top[3], r0, r1], rk)
            wr.face([top[1], top[2], r1], key)
            wr.face([top[3], top[0], r0], key)
            wr.face(list(reversed(bot)), key)
            wr.tube([(-hw * 1.25, 0, h + roof * 0.45), (hw * 1.25, 0, h + roof * 0.45)], [0.0022, 0.0022], "pin", n=4)
    return [tray, opn, cake, wr]


def make_leaf():
    """ใบตองรองก้นขัน (KhanLeaf) แนบผิวด้านในขัน แล้วแตกเป็นปลายแหลม 6 แฉกพับออกพ้นขอบขัน
    ผิวบนชั้นเดียวตรงก้นขัน (ด้านล่างมองไม่เห็น) ส่วนที่พ้นขอบทำ 2 ด้าน"""
    lf = B("KhanLeaf")
    lf.bevel = False
    lf.sa = 40
    lf.no_recalc = True  # กำหนดทิศหน้าเอง (ผิวเปิด)
    inner = [(0.0, 0.134), (0.06, 0.138), (0.105, 0.150), (0.138, 0.172), (0.151, 0.192), (0.160, 0.198)]
    ri, zi = [a for a, _ in inner], [b for _, b in inner]

    def zsurf(r):
        if r <= 0.160:
            return float(np.interp(r, ri, zi)) + 0.003 - Z_GRIP
        return 0.201 - 0.75 * (r - 0.160) - Z_GRIP  # พับลงนอกขอบขัน

    NA, TIPS = 36, 6
    ts = [0.35, 0.62, 0.82, 0.93, 1.0]

    def ext(a):
        return 0.150 + 0.062 * abs(math.cos(TIPS * a / 2)) ** 3

    C = lf._v((0, 0, zsurf(0)))
    top = []
    for t in ts:
        row = []
        for j in range(NA):
            a = 2 * math.pi * j / NA
            r = t * ext(a)
            row.append(lf._v((r * math.cos(a), r * math.sin(a), zsurf(r))))
        top.append(row)
    for j in range(NA):
        k = (j + 1) % NA
        lf.face([C, top[0][j], top[0][k]], "banana_leaf")
        for i in range(len(ts) - 1):
            lf.face([top[i][j], top[i + 1][j], top[i + 1][k], top[i][k]], "banana_leaf")
    # ด้านล่าง (หนา 2.5 มม.) เฉพาะ 2 แถวนอกที่ยื่นพ้นผิวขัน
    bot = [[lf._v((lf.v[v].x, lf.v[v].y, lf.v[v].z - 0.0025)) for v in row] for row in top[-3:]]
    for j in range(NA):
        k = (j + 1) % NA
        for i in range(len(bot) - 1):
            lf.face([bot[i][k], bot[i + 1][k], bot[i + 1][j], bot[i][j]], "banana_leaf")
        lf.face([top[-1][k], top[-1][j], bot[-1][j], bot[-1][k]], "banana_leaf")
    return lf


# ================================================================ main
def main():
    os.makedirs(PREV, exist_ok=True)
    if os.path.normcase(os.path.abspath(bpy.data.filepath)) != os.path.normcase(SRC_BLEND):
        bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)
    # เก็บเฉพาะ collection ศาลพระภูมิ (ไฟล์ v2 แยกจาก pump_props.blend)
    keep = bpy.data.collections[SH]
    for c in list(bpy.data.collections):
        if c is keep:
            continue
        for o in list(c.objects):
            if keep not in o.users_collection:
                bpy.data.objects.remove(o)
        bpy.data.collections.remove(c)
    for o in list(bpy.context.scene.collection.objects):
        if keep not in o.users_collection:
            bpy.data.objects.remove(o)
    bpy.data.orphans_purge(do_recursive=True)
    if keep.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(keep)
    keep.hide_render = False  # ใน pump_props.blend ซ่อน collection นี้ไว้ตอน render
    bpy.context.view_layer.layer_collection.children[keep.name].hide_viewport = False

    # ---- ศาล
    sh_objs = build_shrine_v2()
    bpy.ops.object.select_all(action="DESELECT")
    for o in sh_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = sh_objs[0]
    bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT, SH + "_v2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
    preview(SH + "_v2", sh_objs)

    # ---- มือผี
    hb, grip, tips = make_ghost_hand()
    log("GhostHand")
    _, hand_objs = realize("GhostHand", [hb])
    for o in hand_objs:  # ผิวโค้งมนแบบเนื้อ ไม่เป็นท่อเหลี่ยม (export ใช้ modifier)
        ss = o.modifiers.new("Subsurf", "SUBSURF")
        ss.levels = ss.render_levels = 1
        ss.uv_smooth = "PRESERVE_BOUNDARIES"
    hand_arm = rig_ghost_hand(hand_objs[0])
    bpy.ops.object.select_all(action="DESELECT")
    for o in hand_objs + [hand_arm]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = hand_arm
    bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT, "GhostHand.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=False, object_types={"MESH", "ARMATURE"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True,
                             add_leaf_bones=False, primary_bone_axis="Y", secondary_bone_axis="X", armature_nodetype="NULL",
                             bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False, bake_anim_simplify_factor=0.0)
    mn, mx = bbox_objs(hand_objs)
    log(f"  GhostHand tris={sum(eval_tris(o) for o in hand_objs)} bbox m min={fmt(mn)} max={fmt(mx)} size studs (X,Y,Z)={size_rbx(mn, mx)}")
    log(f"  grip point (between thumb and middle tips) Blender {fmt(grip)} -> Roblox studs from origin {fmt(to_rbx(grip))}")
    log("  tips " + ", ".join(f"{k}={fmt(v)}" for k, v in tips.items()))
    preview("GhostHand", hand_objs)
    for fr, name, d, dist in ((GRAB_FRAMES["open"], "GhostHand_open", (-0.75, -1.25, 0.55), 1.05),
                              (GRAB_FRAMES["closed"], "GhostHand_grab", (-0.75, -1.25, 0.55), 1.05),
                              (GRAB_FRAMES["closed"], "GhostHand_grab_side", (1.0, 0.0, 0.08), 1.0)):
        bpy.context.scene.frame_set(fr)
        bpy.context.view_layer.update()
        frame_cam(hand_objs, d, dist=dist)
        bpy.context.scene.render.filepath = os.path.join(PREV, name + ".png")
        bpy.ops.render.render(write_still=True)
    bpy.context.scene.frame_set(1)

    # ---- ขนมตาลบนใบตอง (ไม่มีขัน)
    log("LeafSweets (LeafTray, OpenWrap, SweetCake, Wrapped)")
    _, khan_objs = realize("LeafSweets", make_leaf_sweets())
    export("LeafSweets", khan_objs)
    mn, mx = bbox_objs(khan_objs)
    log(f"  LeafSweets tris={sum(eval_tris(o) for o in khan_objs)} ({', '.join(f'{o.name}={eval_tris(o)}' for o in khan_objs)}) "
        f"bbox m min={fmt(mn)} max={fmt(mx)} size studs (X,Y,Z)={size_rbx(mn, mx)}; origin = leaf bottom centre")
    preview("LeafSweets", khan_objs)

    # ---- ภาพรวม: ขันบนแท่นยื่น + มือผีเอื้อมออกจากช่องประตู (เฉพาะภาพตัวอย่าง เก็บไว้ใน collection V2_Layout)
    lay = bpy.data.collections.new("V2_Layout")
    bpy.context.scene.collection.children.link(lay)
    extra = []
    bowl_spot = INFO["bowl"]
    for o in khan_objs:
        c = o.copy()
        c.name = "Layout_" + o.name
        c.location = bowl_spot.copy()
        lay.objects.link(c)
        extra.append(c)
    door = INFO["door"]
    target = bowl_spot + Vector((0, -0.035, 0.03))  # ชิ้นขนมตาลที่แกะแล้ว
    target += (Vector((door.x, door.y, 0)) - Vector((bowl_spot.x, bowl_spot.y, 0))).normalized() * 0.14
    hc = hand_objs[0].copy()
    hc.name = "Layout_GhostHand"
    hc.parent = None
    for m_ in list(hc.modifiers):
        if m_.type == "ARMATURE":
            hc.modifiers.remove(m_)
    hc.rotation_mode = "QUATERNION"
    exit_pt = Vector((0, door.y, INFO["door_bottom"] + 0.12))
    d = (target - exit_pt).normalized()
    q = Vector((0, -1, 0)).rotation_difference(d)
    hc.rotation_quaternion = q
    hc.location = target - q @ grip
    lay.objects.link(hc)
    extra.append(hc)
    log(f"  layout: hand origin at {fmt(hc.location)} (door plane y={door.y:.3f}), target {fmt(target)}")
    for o in bpy.data.objects:  # view_layer.objects ยังไม่รวมชิ้นที่เพิ่ง link
        o.hide_render = o not in sh_objs and o not in extra
    render_setup()
    frame_cam([sh_objs[0]], (-0.75, -1.25, 0.55))
    # ซูมเข้าส่วนบน (ตัวศาล + แท่นยื่น)
    cam = bpy.context.scene.camera
    focus = Vector((0, INFO["deck_y"] * 0.6, INFO["deck_top"] + 0.25))
    cam.location = focus + Vector((-0.75, -1.25, 0.55)).normalized() * 2.2
    cam.rotation_euler = (focus - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(PREV, SH + "_v2_scene.png")
    bpy.ops.render.render(write_still=True)
    cam.location = focus + Vector((0.0, -1.0, 0.18)).normalized() * 2.0
    cam.rotation_euler = (focus - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = os.path.join(PREV, SH + "_v2_front.png")
    bpy.ops.render.render(write_still=True)
    for o in bpy.data.objects:
        o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=V2_BLEND)
    log("saved " + V2_BLEND)


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "spirit_house_v2_build.log")
try:
    main()
    LOG.append("DONE")
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
    open(OUT + ".done", "w").write("x")
