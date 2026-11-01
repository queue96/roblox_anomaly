# พื้นหน้าร้าน: ดินลูกรัง (MaterialVariant ของ Terrain.Ground) + ดินโคลนเปียก (Terrain.Mud)
# + Decal คราบน้ำมัน 2 แบบ / รอยล้อ (Texture ต่อกันตามถนน) / แอ่งน้ำ (MeshPart + SurfaceAppearance)
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/ground_materials.py
# ผลลัพธ์: assets/textures/ground/*.png, assets/models/Puddle.fbx, assets/textures/ground/previews/*.png
# ลายทุกแผ่นสร้างด้วย numpy แบบ periodic (ต่อกันได้ไม่มีรอยต่อ) ไม่ใช้ bake
# Normal map เป็นแบบ OpenGL (+Y ขึ้น) ตามที่ Roblox ใช้ · 1 แผ่น = 8 studs (ตั้ง StudsPerTile = 8 ใน MaterialVariant)
import bpy, math, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "textures", "ground")
PREV = os.path.join(OUT, "previews")
MODELS = os.path.join(ROOT, "assets", "models")
os.makedirs(PREV, exist_ok=True)

RES = 1024  # ขนาดสูงสุดที่ MaterialVariant รับได้


def log(*a):
    print("[ground]", *a, flush=True)


# ---------------------------------------------------------------- noise แบบต่อกันได้ (periodic)
def vnoise(h, w, fy, fx, rng):
    """value noise ที่วนซ้ำครบรอบพอดีขอบภาพ (fy, fx = จำนวนช่องต่อแผ่น)"""
    g = rng.random((fy, fx))

    def axis(n, f):
        x = (np.arange(n) + 0.5) / n * f
        i0 = np.floor(x).astype(int)
        t = x - i0
        s = t * t * (3 - 2 * t)
        return i0 % f, (i0 + 1) % f, s

    y0, y1, sy = axis(h, fy)
    x0, x1, sx = axis(w, fx)
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    sx = sx[None, :]
    sy = sy[:, None]
    return (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy


def fbm(h, w, f, octaves, rng, gain=0.5, fy=None):
    fy = fy or f
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        out += vnoise(h, w, fy * 2 ** o, f * 2 ** o, rng) * amp
        tot += amp
        amp *= gain
    return out / tot


def pebbles(res, k, rng, rmin, rmax, density=1.0, wobble=None):
    """หินกรวดกลมๆ แบบ jittered grid (k ช่องต่อแผ่น) คืน (ความสูง 0..1, id ก้อน)"""
    jx = rng.uniform(0.15, 0.85, (k, k))
    jy = rng.uniform(0.15, 0.85, (k, k))
    rad = rng.uniform(rmin, rmax, (k, k)) / k
    alive = rng.random((k, k)) < density
    # ก้อนรีเอียงคนละทาง (หินจริงไม่กลมเป๊ะ)
    ang = rng.uniform(0, math.pi, (k, k))
    asp = rng.uniform(0.55, 1.0, (k, k))
    u = (np.arange(res) + 0.5) / res
    U = u[None, :]
    V = u[:, None]
    cx = np.floor(U * k).astype(int)
    cy = np.floor(V * k).astype(int)
    best = np.zeros((res, res))
    ids = np.full((res, res), -1)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ix = cx + dx
            iy = cy + dy
            wx, wy = ix % k, iy % k
            px = (ix + jx[wy, wx]) / k
            py = (iy + jy[wy, wx]) / k
            ex, ey = U - px, V - py
            a, s = ang[wy, wx], asp[wy, wx]
            ca, sa = np.cos(a), np.sin(a)
            d = np.hypot(ex * ca + ey * sa, (ey * ca - ex * sa) / s)
            if wobble is not None:
                d = d * (0.6 + 0.8 * wobble)
            r = rad[wy, wx]
            hgt = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1)) * alive[wy, wx]
            take = hgt > best
            best = np.where(take, hgt, best)
            ids = np.where(take, wy * k + wx, ids)
    return best, ids


def normal_from_height(hgt, strength):
    """OpenGL normal (แถว 0 = ล่างสุดของภาพแบบ bpy) ความชันคิดแบบวนรอบ ไม่มีรอยต่อ"""
    dx = (np.roll(hgt, -1, axis=1) - np.roll(hgt, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(hgt, -1, axis=0) - np.roll(hgt, 1, axis=0)) * 0.5 * strength
    n = np.stack([-dx, -dy, np.ones_like(hgt)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def blur(a, sigma):
    """Gaussian blur แบบวนรอบ (FFT) ใช้ทำเงาในร่อง (AO) โดยไม่เกิดรอยต่อ"""
    h, w = a.shape
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (math.pi * sigma) ** 2 * (fx * fx + fy * fy))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g))


def lerp(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return a * (1 - t) + b * t


def rgb(*c):
    return np.array(c, dtype=float) / 255.0


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- บันทึก PNG
def save_png(name, arr, data=False):
    """arr: (h, w, 3|4) หรือ (h, w) ค่า 0..1 · data=True = Non-Color (normal/roughness)"""
    if arr.ndim == 2:
        arr = np.repeat(arr[..., None], 3, axis=-1)
    h, w, c = arr.shape
    if c == 3:
        arr = np.concatenate([arr, np.ones((h, w, 1))], axis=-1)
    img = bpy.data.images.new(name, w, h, alpha=True)
    if data:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.clip(arr, 0, 1).astype(np.float32).ravel())
    path = os.path.join(OUT, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    log("saved", os.path.relpath(path, ROOT))
    return img


# ---------------------------------------------------------------- ดินลูกรัง / ดินโคลน
def soil(name, seed, wet, verge=False):
    rng = np.random.default_rng(seed)
    n = RES
    big = fbm(n, n, 3, 4, rng)
    mid = fbm(n, n, 12, 4, rng)
    grain = fbm(n, n, 96, 2, rng)
    wob = fbm(n, n, 64, 2, rng)
    speck = fbm(n, n, 256, 1, rng)
    # หินลูกรัง 3 ขนาด จมดินเห็นแค่หลังก้อน (ล้อรถบดอัด): ก้อนกลางห่างๆ / กรวดเล็กแน่น / เม็ดทรายหยาบ
    p1, id1 = pebbles(n, 18, rng, 0.2, 0.45, density=0.25 if wet else 0.45, wobble=wob)
    p2, id2 = pebbles(n, 60, rng, 0.2, 0.42, density=0.25 if wet else 0.6, wobble=wob)
    p3, id3 = pebbles(n, 150, rng, 0.25, 0.45, density=0.5, wobble=wob)
    cap1 = smooth(0.3, 0.75, p1)
    cap2 = smooth(0.35, 0.8, p2)
    cap3 = smooth(0.4, 0.85, p3)

    # สีดิน: แดงลูกรัง <-> ส้มอิฐ <-> ฝุ่นหม่น (ความต่างน้อย แบบถนนลูกรังจริงที่ฝุ่นคลุม)
    red = rgb(112, 58, 38)
    ochre = rgb(142, 84, 52)
    dust = rgb(132, 104, 82)
    base = lerp(red, ochre, smooth(0.3, 0.7, big))
    base = lerp(base, dust, smooth(0.45, 0.85, mid) * 0.5)
    base *= (0.9 + 0.2 * grain + 0.12 * (speck - 0.5))[..., None]

    # หินแต่ละก้อนสีใกล้ดิน (ก้อนลูกรังคือดินที่จับตัวแข็ง) สว่าง/คล้ำต่างกันนิดหน่อย
    # มีก้อนเหล็กคล้ำ (1 ใน 6) กับก้อนควอตซ์ขุ่น (1 ใน 17) แซมประปราย
    def stone_col(ids, salt):
        t = ((ids * 0.6180339 + salt) % 1.0)[..., None]
        c = base * (0.7 + 0.55 * t)
        iron = ((ids * 7 + salt * 13).astype(int) % 6 == 0)[..., None]
        quartz = ((ids * 11 + salt * 5).astype(int) % 17 == 0)[..., None]
        c = np.where(iron, c * 0.5 + rgb(40, 24, 18) * 0.5, c)
        c = np.where(quartz, c * 0.4 + rgb(150, 136, 118) * 0.6, c)
        return lerp(c, base, 0.3)  # ฝุ่นเกาะผิวหิน

    col = lerp(base, stone_col(id3, 0.3), cap3 * 0.6)
    col = lerp(col, stone_col(id2, 0.6), cap2)
    col = lerp(col, stone_col(id1, 0.9), cap1)

    hgt = big * 0.5 + mid * 0.7 + grain * 0.2 + cap1 * 1.6 + cap2 * 0.9 + cap3 * 0.35
    # เงาในร่องรอบหิน (AO จากความสูง) และหลังหินโดนลมพัดฝุ่นออกเลยสว่างกว่านิด
    ao = np.clip(1 - (blur(hgt, 3) - hgt) * 0.35, 0.8, 1.05)
    col *= ao[..., None]
    rough = 0.94 - 0.05 * grain - 0.12 * np.maximum(cap1, cap2)

    if verge:
        # ไหล่ทาง (แทน Terrain.LeafyGrass): ดินลูกรังผืนเดียวกับถนน มีหญ้าสั้นขึ้นเป็นหย่อม + ใบไม้แห้งร่วง
        # สีดินใต้หญ้าตรงกับถนน รอยต่อระหว่างวัสดุจึงกลืนกัน ไม่ตัดเป็นเส้น
        cover = smooth(0.38, 0.62, fbm(n, n, 4, 4, rng) * 0.7 + mid * 0.3)
        dry = fbm(n, n, 6, 3, rng)
        # ใบหญ้าทีละใบ (มองจากบนลงล่าง ใบล้มเอนไปคนละทิศ) วาดลงภาพแบบวนรอบขอบ
        blade_a = np.zeros((n, n))
        blade_c = np.zeros((n, n, 3))
        blade_h = np.zeros((n, n))
        green, straw = rgb(60, 74, 34), rgb(122, 110, 62)
        roots = rng.random((60000, 2))
        keep = rng.random(60000) < cover[(roots[:, 1] * n).astype(int), (roots[:, 0] * n).astype(int)] * 0.9
        for rx, ry in roots[keep]:
            L = rng.uniform(7, 20)
            a = rng.uniform(0, 2 * math.pi)
            w = rng.uniform(1.0, 1.9)
            x0, y0 = rx * n, ry * n
            dx, dy = math.cos(a) * L, math.sin(a) * L
            pad = int(L + 3)
            ix = np.arange(int(x0) - pad, int(x0) + pad + 1)
            iy = np.arange(int(y0) - pad, int(y0) + pad + 1)
            PX = ix[None, :] + 0.5 - x0
            PY = iy[:, None] + 0.5 - y0
            t = np.clip((PX * dx + PY * dy) / (L * L), 0, 1)
            d = np.hypot(PX - t * dx, PY - t * dy)
            alpha = smooth(0.0, 0.8, w * (1 - 0.7 * t) - d)  # ใบเรียวไปทางปลาย
            if not alpha.any():
                continue
            iyw, ixw = iy % n, ix % n
            dryv = dry[int(y0) % n, int(x0) % n]
            c = lerp(green, straw, smooth(0.3, 0.8, dryv + rng.uniform(-0.2, 0.2))) * rng.uniform(0.75, 1.2)
            shade = (0.6 + 0.5 * t)[..., None]  # โคนใบในเงา ปลายใบโดนแสง
            sub_a = blade_a[np.ix_(iyw, ixw)]
            sub_c = blade_c[np.ix_(iyw, ixw)]
            blade_c[np.ix_(iyw, ixw)] = sub_c * (1 - alpha[..., None]) + c * shade * alpha[..., None]
            blade_a[np.ix_(iyw, ixw)] = np.maximum(sub_a, alpha)
            blade_h[np.ix_(iyw, ixw)] = np.maximum(blade_h[np.ix_(iyw, ixw)], alpha * (0.4 + 0.6 * t))
        # ใต้กอหญ้าดินคล้ำลง (ร่มเงา) แล้วซ้อนใบหญ้า
        col = col * (1 - 0.3 * blur(cover, 6))[..., None]
        col = lerp(col, blade_c, blade_a)
        amt = blade_a
        lv, lid = pebbles(n, 34, rng, 0.25, 0.45, density=0.4, wobble=wob)
        leaf = smooth(0.2, 0.5, lv) * (1 - cover * 0.6)
        leaf_col = lerp(rgb(104, 66, 40), rgb(150, 98, 54), ((lid * 0.6180339) % 1.0))
        col = lerp(col, leaf_col, leaf * 0.8)
        hgt = hgt * (1 - cover * 0.5) + blade_h * 1.6 + leaf * 0.4
        rough = rough * (1 - cover) + 0.86 * cover

    if wet:
        # โคลน: เข้มลง อิ่มน้ำ มีคราบน้ำขัง (ตรงแอ่งต่ำผิวเรียบมัน)
        col = col * 0.55 + rgb(40, 26, 18) * 0.12
        pool = smooth(0.6, 0.68, 1 - big * 0.7 - mid * 0.3)
        col = lerp(col, rgb(34, 24, 18), pool * 0.6)
        hgt = hgt * (1 - pool * 0.85)
        rough = rough * 0.6 - pool * 0.4
    rough = np.clip(rough, 0.04, 1)

    save_png(name + "_Color", col)
    save_png(name + "_Normal", normal_from_height(hgt, 6.0 if not wet else 4.0), data=True)
    save_png(name + "_Roughness", rough, data=True)


# ---------------------------------------------------------------- Decal
def blob_mask(n, rng, radius, rough_amt, splats=0):
    """ก้อนรูปทรงไม่สม่ำเสมอกลางภาพ (0..1) + หยดกระเซ็นรอบๆ"""
    u = (np.arange(n) + 0.5) / n - 0.5
    X, Y = np.meshgrid(u, u)
    ang = np.arctan2(Y, X)
    r = np.hypot(X, Y)
    edge = np.zeros_like(r)
    for k in range(2, 9):
        edge += rng.uniform(-1, 1) * np.cos(k * ang + rng.uniform(0, 6.28)) / k
    edge = radius * (1 + rough_amt * edge)
    detail = fbm(n, n, 16, 3, rng)
    m = smooth(0.0, 0.06, edge - r + (detail - 0.5) * 0.05)
    for _ in range(splats):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(radius * 1.05, 0.46)
        cx, cy = math.cos(a) * d, math.sin(a) * d
        rr = rng.uniform(0.006, 0.02)
        m = np.maximum(m, smooth(0.0, 0.004, rr - np.hypot(X - cx, Y - cy)))
    return m, detail


def oil_stain(name, seed, radius):
    rng = np.random.default_rng(seed)
    n = 512
    m, detail = blob_mask(n, rng, radius, 0.55, splats=14)
    # น้ำมันซึมเก่า: ขอบเข้มกว่ากลาง (คราบน้ำมันแห้งเป็นวง) + ด้านในจาง
    ring = smooth(0.0, 0.25, m) - smooth(0.55, 1.0, m) * 0.6
    soak = fbm(n, n, 6, 4, rng)
    # น้ำมันซึมลงดิน: โปร่ง เห็นเม็ดดินข้างล่าง เข้มเป็นหย่อมๆ ตามที่ซึมลึก ขอบวงเข้มกว่า
    a = np.clip(m * (0.3 + 0.45 * smooth(0.3, 0.8, soak) + 0.1 * detail) + ring * 0.25, 0, 0.8)
    col = lerp(rgb(46, 32, 22), rgb(18, 14, 10), smooth(0.3, 1.0, m) * smooth(0.2, 0.8, soak))
    col = col * (0.85 + 0.3 * detail)[..., None]
    save_png(name, np.concatenate([col, a[..., None]], axis=-1))


def tire_tracks(name, seed):
    """รอยล้อ 1 เส้น (แนวตั้ง ต่อกันได้ตามความยาว) ใช้เป็น Texture บนแผ่นใส"""
    rng = np.random.default_rng(seed)
    h, w = 1024, 256
    v = (np.arange(h) + 0.5) / h
    x = (np.arange(w) + 0.5) / w
    X = x[None, :]
    V = v[:, None]
    lane = smooth(0.0, 0.18, X) * smooth(0.0, 0.18, 1 - X)  # ขอบรอยจางลง
    # ดอกยางเฉียงสลับซ้าย/ขวา (24 ดอกต่อแผ่น)
    side = np.where(X < 0.5, 1.0, -1.0)
    tread = np.sin((V * 24 + side * (X - 0.5) * 1.6) * 2 * math.pi)
    tread = smooth(0.2, 0.7, tread) * smooth(0.06, 0.12, np.abs(X - 0.5))
    wear = fbm(h, w, 2, 4, rng, fy=8)  # ช่วงที่รอยชัด/ลบเลือน (วนครบรอบตามความยาว)
    grit = fbm(h, w, 16, 3, rng, fy=64)  # ดอกยางขาดๆ หายๆ ตามดินร่วน
    a = lane * (0.2 + 0.15 * tread * grit) * smooth(0.3, 0.7, wear)
    col = lerp(rgb(70, 42, 28), rgb(40, 26, 18), tread)
    save_png(name, np.concatenate([col, np.clip(a, 0, 0.75)[..., None]], axis=-1))


def puddle(name, seed):
    rng = np.random.default_rng(seed)
    n = 512
    m, detail = blob_mask(n, rng, 0.36, 0.45)
    ripple = fbm(n, n, 24, 3, rng)
    wet_edge = smooth(0.0, 0.5, m)
    col = lerp(rgb(62, 40, 28), rgb(22, 18, 14), wet_edge)  # ขอบดินเปียก -> น้ำขุ่นกลางแอ่ง
    a = np.clip(smooth(0.0, 0.15, m) * 0.95, 0, 1)
    rough = np.clip(0.55 - 0.5 * smooth(0.2, 0.8, m) + 0.04 * ripple, 0.02, 1)
    hgt = ripple * smooth(0.4, 1.0, m) * 0.6 + (1 - m) * 0.2
    save_png(name + "_Color", np.concatenate([col, a[..., None]], axis=-1))
    save_png(name + "_Normal", normal_from_height(hgt, 3.0), data=True)
    save_png(name + "_Roughness", rough, data=True)


# ---------------------------------------------------------------- Puddle.fbx (แผ่นเรียบ 1x1 studs, UV เต็มแผ่น)
def export_puddle_mesh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    ob = bpy.context.active_object
    ob.name = "Puddle"
    os.makedirs(os.path.join(MODELS, "Puddle"), exist_ok=True)
    path = os.path.join(MODELS, "Puddle", "Puddle.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y")
    log("saved", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------- ภาพตัวอย่าง (Cycles)
def img(name, data=False):
    i = bpy.data.images.load(os.path.join(OUT, name + ".png"), check_existing=True)
    if data:
        i.colorspace_settings.name = "Non-Color"
    return i


def pbr_material(mname, prefix, scale, alpha=False):
    mat = bpy.data.materials.new(mname)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, 1)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    c = nt.nodes.new("ShaderNodeTexImage")
    c.image = img(prefix + "_Color")
    nt.links.new(mp.outputs["Vector"], c.inputs["Vector"])
    nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        nt.links.new(c.outputs["Alpha"], bsdf.inputs["Alpha"])
    if os.path.exists(os.path.join(OUT, prefix + "_Roughness.png")):
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = img(prefix + "_Roughness", True)
        nt.links.new(mp.outputs["Vector"], r.inputs["Vector"])
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
        nm = nt.nodes.new("ShaderNodeTexImage")
        nm.image = img(prefix + "_Normal", True)
        nt.links.new(mp.outputs["Vector"], nm.inputs["Vector"])
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    else:
        bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def decal_material(mname, file):
    mat = bpy.data.materials.new(mname)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    c = nt.nodes.new("ShaderNodeTexImage")
    c.image = img(file)
    nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(c.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.45
    return mat


def plane(name, size, loc, mat, rot=0.0, sy=None):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc, rotation=(0, 0, rot))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (size, sy or size, 1)
    ob.data.materials.append(mat)
    return ob


def render_preview(fname, soil_prefix, night):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.025, 0.035, 1) if night else (0.6, 0.65, 0.75, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6 if night else 1.0

    # 1 stud = 1 หน่วย · พื้น 32x32 studs = 4x4 แผ่น
    plane("Ground", 32, (0, 0, 0), pbr_material("Soil", soil_prefix, 4))
    if soil_prefix == "LateriteDirt":
        oil_a = decal_material("OilA", "OilStain_A")
        oil_b = decal_material("OilB", "OilStain_B")
        plane("Oil1", 5, (-1.5, 3, 0.01), oil_a, 0.4)
        plane("Oil2", 3, (2.2, 5.5, 0.01), oil_b, 1.9)
        tracks = decal_material("Tracks", "TireTracks")
        plane("TrackL", 1.6, (-3.2, 2, 0.008), tracks, 0.05, sy=24)
        plane("TrackR", 1.6, (2.4, 2, 0.008), tracks, 0.05, sy=24)
        plane("Puddle", 6, (4.5, 10, 0.012), pbr_material("Puddle", "Puddle", 1, alpha=True), 0.7)

    if night:
        bpy.ops.object.light_add(type="POINT", location=(3, 9, 9))
        lt = bpy.context.active_object
        lt.data.energy = 2600
        lt.data.color = (1.0, 0.84, 0.6)
        lt.data.shadow_soft_size = 0.3
    else:
        bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(30)))
        bpy.context.active_object.data.energy = 3.5

    bpy.ops.object.camera_add(location=(0, -7, 5.5))
    cam = bpy.context.active_object
    target = bpy.data.objects.new("T", None)
    sc.collection.objects.link(target)
    target.location = (0.5, 6, 0)
    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    cam.data.lens = 28
    sc.camera = cam
    sc.render.filepath = os.path.join(PREV, fname)
    bpy.ops.render.render(write_still=True)
    log("preview", fname)


def render_edge_preview(fname):
    """ถนนลูกรัง (ซ้าย) ต่อกับไหล่ทางหญ้า (ขวา) ดูว่ารอยต่อกลืนกันไหม"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.6, 0.65, 0.75, 1)
    plane("Road", 16, (-8, 8, 0), pbr_material("Road", "LateriteDirt", 2))
    plane("Verge", 16, (8, 8, 0), pbr_material("Verge", "LateriteVerge", 2))
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50), 0, math.radians(30)))
    bpy.context.active_object.data.energy = 3.5
    bpy.ops.object.camera_add(location=(0, -6, 6))
    cam = bpy.context.active_object
    target = bpy.data.objects.new("T", None)
    sc.collection.objects.link(target)
    target.location = (0, 7, 0)
    con = cam.constraints.new("TRACK_TO")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    cam.data.lens = 28
    sc.camera = cam
    sc.render.filepath = os.path.join(PREV, fname)
    bpy.ops.render.render(write_still=True)
    log("preview", fname)


def main():
    import sys
    if "--verge" in sys.argv:
        # ไหล่ทางอย่างเดียว (ภาพชุดอื่นอัปโหลดไปแล้ว ไม่ต้องสร้างซ้ำ)
        soil("LateriteVerge", 17, wet=False, verge=True)
        render_edge_preview("RoadVerge_edge.png")
        log("DONE")
        return
    soil("LateriteDirt", 11, wet=False)
    soil("WetMud", 23, wet=True)
    oil_stain("OilStain_A", 31, 0.3)
    oil_stain("OilStain_B", 37, 0.22)
    tire_tracks("TireTracks", 41)
    puddle("Puddle", 53)
    export_puddle_mesh()
    render_preview("LateriteDirt_night.png", "LateriteDirt", night=True)
    render_preview("LateriteDirt_day.png", "LateriteDirt", night=False)
    render_preview("WetMud_day.png", "WetMud", night=False)
    log("DONE")


main()
