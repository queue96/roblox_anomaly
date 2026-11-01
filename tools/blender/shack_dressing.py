# ตกแต่งเพิงร้าน (ไม่แตะโครงสร้างเดิม): โปสเตอร์โฆษณาเก่า/ปฏิทิน/ผ้ายันต์/ป้ายกระดาษลัง (Decal) + คราบสนิมไหล + แผงน้ำมันขวด
# ภาพตั้งต้นวาดด้วย tools/posters/make_posters.ps1 (GDI+ วางสระ/วรรณยุกต์ไทยถูก) แล้วสคริปต์นี้ทำให้เก่า: ซีด เหลือง คราบน้ำ ขาดขอบ สนิมรูตะปู
# รัน:  D:\blender-5.2.4\blender.exe --background --factory-startup --python tools/blender/shack_dressing.py
# ผลลัพธ์: assets/textures/shack/*.png, assets/models/FuelBottleRack.fbx, assets/textures/shack/previews/*.png
# แผงน้ำมันขวดไม่มีภาพพื้นผิว ใช้วัสดุ Roblox (WoodPlanks / Glass) ตั้งใน MapBuilder.AddShackDressing
import bpy, math, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "ground_materials.py"), encoding="utf-8").read()
exec(compile(src[: src.rindex("\nmain()")], "ground_materials.py", "exec"))  # ใช้ noise / save_png / plane ร่วมกัน

OUT = os.path.join(ROOT, "assets", "textures", "shack")
RAW = os.path.join(OUT, "raw")
PREV = os.path.join(OUT, "previews")
os.makedirs(PREV, exist_ok=True)


def log(*a):
    print("[shack]", *a, flush=True)


def load_raw(name):
    im = bpy.data.images.load(os.path.join(RAW, name + ".png"))
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    return a.reshape(h, w, 4)[..., :3].astype(float)


def edge_mask(h, w, rng, tear=True, fray=0.012):
    """ขอบกระดาษขาดหยักๆ + มุมขาดหาย 1 มุม (alpha 0..1)"""
    v = (np.arange(h) + 0.5) / h
    u = (np.arange(w) + 0.5) / w
    U, V = np.meshgrid(u, v)
    n1 = fbm(h, w, 24, 3, rng)
    d = np.minimum(np.minimum(U, 1 - U), np.minimum(V, 1 - V))
    m = smooth(0.0, 0.004, d - fray * (0.4 + n1))
    if tear:
        cu, cv = rng.choice([0.0, 1.0]), rng.choice([0.0, 1.0])
        k = rng.uniform(0.12, 0.22)
        corner = np.abs(U - cu) + np.abs(V - cv) * (w / h)
        m *= smooth(0.0, 0.01, corner - k * (0.85 + 0.3 * n1))
    return m


def age_poster(name, seed, paper=(0.86, 0.79, 0.62), fade=0.3, tear=True, holes=True, cloth=False):
    rng = np.random.default_rng(seed)
    col = load_raw(name)
    h, w, _ = col.shape
    # ซีดแดด + กระดาษเหลือง
    grey = col.mean(axis=-1, keepdims=True)
    col = lerp(col, np.repeat(grey, 3, axis=-1), 0.3)
    col = lerp(col, np.array(paper), fade)
    # คราบน้ำเป็นวง + ฝุ่นเกาะครึ่งล่าง + คราบดำตามขอบ
    stain = fbm(h, w, 5, 4, rng)
    blot = smooth(0.55, 0.7, stain)
    ring = smooth(0.52, 0.56, stain) - smooth(0.56, 0.6, stain)
    col = col * (1 - 0.18 * blot[..., None]) * (1 - 0.1 * ring[..., None]) + rgb(70, 50, 30) * (0.08 * blot)[..., None]
    v = ((np.arange(h) + 0.5) / h)[:, None]  # แถว 0 = ล่างสุด (แบบ bpy)
    col *= (0.82 + 0.18 * smooth(0.0, 0.5, v))[..., None]
    grain = fbm(h, w, 160, 2, rng)
    col *= (0.92 + 0.12 * grain)[..., None]
    if cloth:
        weave = (np.sin(np.arange(w)[None, :] * 1.7) * np.sin(np.arange(h)[:, None] * 1.7)) * 0.03
        col += weave[..., None]
    else:
        # รอยพับ 1 แนวตั้ง 1 แนวนอน
        u = (np.arange(w) + 0.5) / w
        fx, fy = rng.uniform(0.4, 0.6), rng.uniform(0.35, 0.65)
        crease = np.exp(-((u[None, :] - fx) * w / 2.0) ** 2) + np.exp(-((v - fy) * h / 2.0) ** 2)
        col *= (1 - 0.12 * np.clip(crease, 0, 1))[..., None]
    # รูตะปูมุมบนมีสนิมซึม
    if holes:
        U, V = np.meshgrid((np.arange(w) + 0.5) / w, (np.arange(h) + 0.5) / h)
        for cx in (0.07, 0.93):
            r = np.hypot((U - cx) * w, (V - 0.95) * h)
            rust = np.exp(-(r / 22) ** 2) * 0.8 + np.exp(-(r / 6) ** 2)
            drip = np.exp(-((U - cx) * w / 4) ** 2) * smooth(0.95, 0.75, V) * smooth(0.55, 0.9, V) * 0.5
            amt = np.clip(rust + drip, 0, 1)
            col = lerp(col, rgb(110, 52, 24), amt * 0.7)
            col = lerp(col, rgb(20, 14, 10), np.clip(np.exp(-(r / 3.5) ** 2), 0, 1))
    alpha = edge_mask(h, w, rng, tear=tear, fray=0.02 if cloth else 0.012)
    save_png(name, np.concatenate([np.clip(col, 0, 1), alpha[..., None]], axis=-1))


def rust_streaks(name, seed, count):
    """คราบสนิมไหลจากหัวตะปูบนแผ่นสังกะสี (โปร่งใส แปะทับแผ่นเดิม) 512x1024"""
    rng = np.random.default_rng(seed)
    w, h = 512, 1024
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(u, v)
    streaky = fbm(h, w, 48, 3, rng, fy=3)  # ลายไหลแนวตั้ง
    blotch = fbm(h, w, 8, 4, rng)
    amt = np.zeros((h, w))
    for _ in range(count):
        x0 = rng.uniform(0.06, 0.94)
        top = rng.choice([0.96, 0.62, 0.3]) - rng.uniform(0, 0.03)  # แนวตะปู 3 แถว (บน/กลาง/ล่าง)
        length = rng.uniform(0.15, 0.55)
        width = rng.uniform(0.008, 0.022)
        t = np.clip((top - V) / length, 0, 1)
        below = (V <= top).astype(float)
        spread = width * (1 + 0.9 * t)
        lateral = np.exp(-((U - x0 - 0.003 * np.sin(V * 23)) / spread) ** 2)
        s = lateral * (1 - t) ** 1.4 * below * (0.6 + 0.6 * streaky)
        head = np.exp(-(np.hypot((U - x0) * w, (V - top) * h) / 7) ** 2)
        amt = np.maximum(amt, np.clip(s + head, 0, 1))
    # สนิมเป็นปื้นตามขอบล่าง (น้ำกระเด็นขึ้นมาจากดิน)
    amt = np.maximum(amt, smooth(0.16, 0.0, V) * smooth(0.4, 0.7, blotch) * 0.8)
    col = lerp(rgb(150, 74, 32), rgb(84, 40, 20), smooth(0.3, 0.9, amt))
    col *= (0.85 + 0.3 * streaky)[..., None]
    save_png(name, np.concatenate([col, np.clip(amt * 0.85, 0, 0.9)[..., None]], axis=-1))


# ---------------------------------------------------------------- แผงน้ำมันขวด (หน่วย studs, origin = กลางฐาน, ด้านหน้า = -Y)
def cube(name, loc, size, objs):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    objs.append(ob)
    return ob


def cyl(name, loc, r, d, objs, verts=14):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=d, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    objs.append(ob)
    return ob


def cone(name, loc, r1, r2, d, objs, verts=14):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    objs.append(ob)
    return ob


def join(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    ob.data.name = name
    bpy.ops.object.shade_smooth()
    return ob


def build_rack(rng):
    W, D, H = 3.2, 1.0, 3.6
    shelves = (0.45, 1.55, 2.65)
    rack = []
    lean = 0.04
    for sx in (-1, 1):
        for sy in (-1, 1):
            cube("Post", (sx * (W / 2 - 0.08), sy * (D / 2 - 0.08), H / 2), (0.14, 0.14, H), rack)
    for z in shelves:
        for i in range(3):  # แต่ละชั้นเป็นไม้ 3 แผ่น เว้นร่อง
            cube("Plank", (0, -D / 2 + 0.17 + i * 0.33, z), (W - 0.05, 0.3, 0.07), rack)
        cube("Lip", (0, -D / 2 + 0.03, z + 0.08), (W - 0.1, 0.04, 0.12), rack)  # ขอบกันขวดตก
    cube("BackRail", (0, D / 2 - 0.06, H - 0.3), (W - 0.1, 0.06, 0.18), rack)
    cube("BackRail2", (0, D / 2 - 0.06, 1.1), (W - 0.1, 0.06, 0.14), rack)
    rack_ob = join("Rack", rack)
    rack_ob.rotation_euler = (-lean, 0, 0)  # แผงไม้เก่าเอนไปข้างหลังนิดๆ

    glass, red, green, caps = [], [], [], []
    for z in shelves:
        for i in range(7):
            if rng.random() < 0.2:
                continue  # ช่องที่ขายไปแล้ว
            x = -1.35 + i * 0.45 + rng.uniform(-0.04, 0.04)
            y = -0.12 + rng.uniform(-0.05, 0.05)  # ขวดชิดด้านหน้า (ไว้เช็กทิศหลังนำเข้า)
            base = z + 0.035
            cyl("Body", (x, y, base + 0.36), 0.16, 0.72, glass)
            cone("Shoulder", (x, y, base + 0.8), 0.16, 0.065, 0.16, glass)
            cyl("Neck", (x, y, base + 0.98), 0.06, 0.22, glass, 10)
            level = rng.uniform(0.38, 0.66)
            target = green if rng.random() < 0.25 else red
            cyl("Fuel", (x, y, base + 0.02 + level / 2), 0.145, level, target)
            cyl("Cap", (x, y, base + 1.11), 0.07, 0.06, caps, 10)
            if rng.random() < 0.4:  # จุกผ้า/ถุงพลาสติกมัดหนังยาง
                bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.09, location=(x, y, base + 1.15))
                ob = bpy.context.active_object
                ob.scale = (1, 1, 0.6)
                caps.append(ob)
    parts = [rack_ob, join("Glass", glass), join("FuelRed", red), join("Caps", caps)]
    if green:
        parts.append(join("FuelGreen", green))
    return parts


def export_rack():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = build_rack(np.random.default_rng(5))
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    os.makedirs(os.path.join(ROOT, "assets", "models", "FuelBottleRack"), exist_ok=True)
    path = os.path.join(ROOT, "assets", "models", "FuelBottleRack", "FuelBottleRack.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y")
    log("saved", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------- ภาพตัวอย่าง: ผนังสังกะสี + โปสเตอร์ + สนิม + แผงน้ำมันขวด
def flat_mat(name, color, rough=0.6, metal=0.0, alpha=1.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        b.inputs["Transmission Weight"].default_value = 1.0
    return m


def decal_on_wall(name, file, loc, w, h, rot_y=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=loc, rotation=(math.radians(90), rot_y, 0))
    ob = bpy.context.active_object
    ob.scale = (w, h, 1)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(OUT, file + ".png"))
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = 0.85
    ob.data.materials.append(mat)


def render_preview():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 64
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 1280, 720
    sc.view_settings.view_transform = "AgX"
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.025, 0.035, 1)
    # ผนังสังกะสีลอน (ลอนด้วย displace แบบง่าย) + พื้นดิน
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0.6, 5), rotation=(math.radians(90), 0, 0))
    wall = bpy.context.active_object
    wall.scale = (16, 10, 1)
    wall.data.materials.append(flat_mat("Tin", (0.32, 0.33, 0.3), rough=0.5, metal=0.7))
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, -6, 0))
    bpy.context.active_object.data.materials.append(flat_mat("Dirt", (0.22, 0.13, 0.08), rough=0.95))
    decal_on_wall("Rust", "RustStreaks_A", (-4.5, 0.58, 5), 6, 10)
    decal_on_wall("Rust2", "RustStreaks_B", (3.5, 0.58, 5), 6, 10)
    decal_on_wall("P1", "Poster_Fertilizer", (-5, 0.55, 5.8), 2.4, 3.6)
    decal_on_wall("P2", "Poster_Energy", (-2.2, 0.55, 6.0), 2.4, 3.6)
    decal_on_wall("P3", "Calendar", (0.6, 0.55, 6.3), 2.0, 3.0)
    decal_on_wall("P4", "Poster_Oil", (3.4, 0.55, 5.7), 2.4, 3.6)
    decal_on_wall("P5", "Yantra", (6.0, 0.55, 6.6), 1.8, 1.8)
    for p in build_rack(np.random.default_rng(5)):
        p.location.x += -1.5
        p.location.y += -1.2
        mats = {
            "Rack": flat_mat("Wood", (0.25, 0.16, 0.09), rough=0.85),
            "Glass": flat_mat("Glass", (0.85, 0.9, 0.88), rough=0.05, alpha=0.2),
            "FuelRed": flat_mat("Red", (0.55, 0.05, 0.03), rough=0.1),
            "FuelGreen": flat_mat("Green", (0.2, 0.45, 0.05), rough=0.1),
            "Caps": flat_mat("Cap", (0.6, 0.55, 0.45), rough=0.7),
        }
        p.data.materials.append(mats[p.name])
    decal_on_wall("Sign", "FuelSign", (-1.5, -1.75, 3.9), 2.6, 1.3)
    bpy.ops.object.light_add(type="POINT", location=(1.5, -5, 8))
    lt = bpy.context.active_object
    lt.data.energy = 3000
    lt.data.color = (1.0, 0.84, 0.6)
    bpy.ops.object.camera_add(location=(0.5, -13, 4.5))
    cam = bpy.context.active_object
    tgt = bpy.data.objects.new("T", None)
    sc.collection.objects.link(tgt)
    tgt.location = (0.3, 0, 4.2)
    con = cam.constraints.new("TRACK_TO")
    con.target = tgt
    con.track_axis = "TRACK_NEGATIVE_Z"
    con.up_axis = "UP_Y"
    cam.data.lens = 32
    sc.camera = cam
    sc.render.filepath = os.path.join(PREV, "ShackDressing.png")
    bpy.ops.render.render(write_still=True)
    log("preview ShackDressing.png")


def main_shack():
    age_poster("Poster_Fertilizer", 1)
    age_poster("Poster_Energy", 2)
    age_poster("Poster_Oil", 3)
    age_poster("Calendar", 4, paper=(0.9, 0.86, 0.74), fade=0.18)
    age_poster("Yantra", 5, paper=(0.82, 0.74, 0.56), fade=0.2, tear=False, holes=False, cloth=True)
    age_poster("FuelSign", 6, paper=(0.6, 0.46, 0.3), fade=0.1, tear=False, holes=False)
    rust_streaks("RustStreaks_A", 11, 9)
    rust_streaks("RustStreaks_B", 12, 6)
    export_rack()
    render_preview()
    log("DONE")


main_shack()
