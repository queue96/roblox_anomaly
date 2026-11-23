# Shop Icons — รูปไอคอนสินค้าทุกชิ้นสำหรับแนบใน Creator Hub (Game Pass / Developer Product) ผู้ใช้ 2026-11-23
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/shop_icons.py
# ผลลัพธ์: assets/models/ShopIcons/upload/*.png (512 x 512) — ฉากมืด ไฟสปอตส่องของกลางเวที ขอบฟ้าเย็น (โทนเกมสยอง)
#   ใช้โมเดลที่ export แล้ว (FBX + texture ที่ bake แล้ว) ไม่ปั้นใหม่ ยกเว้นห้องใหญ่ (วงทอง + คน 6 คน) / ธูป / เหรียญ
#   ของในเกม Game Pass: ไฟฉายตราช้าง สวดมนต์ไว รองเท้าแตะติดปีก สมุดหมอผี ห้องใหญ่
#            Developer Product: ป้ายผีแกล้งทุกคน ต่อธูป ร่วมทำบุญ 10 / 50 / 100 / 500
#   กฎ (CLAUDE.md): ไม่มีเลือด / อวัยวะ / โลโก้จริง (ไม่ใช้โลโก้ Robux) · ป้ายผีใช้รูปเดียวกับที่ผ่านการตรวจแล้ว (100252335354240)
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(MODELS, "ShopIcons", "upload")
os.makedirs(OUT, exist_ok=True)
ONLY = os.environ.get("ICON_ONLY", "")  # ชื่อไฟล์เดียว (ไว้ลองทีละรูป)
RES = 512

bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x = scn.render.resolution_y = RES
scn.render.film_transparent = False
scn.view_settings.view_transform = "AgX"
scn.view_settings.look = "AgX - Medium High Contrast"
try:
    scn.eevee.use_shadows = True
except Exception:
    pass


def log(*a):
    print("ICON|", *a)


# ---------------------------------------------------------------- วัสดุ
def tex_mat(name, folder, stem):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    for ch, sock, cs in (("Color", "Base Color", "sRGB"), ("Roughness", "Roughness", "Non-Color"), ("Metalness", "Metallic", "Non-Color")):
        p = os.path.join(folder, f"{stem}_{ch}.png")
        if os.path.exists(p):
            t = nt.nodes.new("ShaderNodeTexImage")
            t.image = bpy.data.images.load(p, check_existing=True)
            t.image.colorspace_settings.name = cs
            nt.links.new(t.outputs[0], bs.inputs[sock])
    p = os.path.join(folder, f"{stem}_Normal.png")
    if os.path.exists(p):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(p, check_existing=True)
        t.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs[0], nm.inputs["Color"])
        nt.links.new(nm.outputs[0], bs.inputs["Normal"])
    return m


def flat_mat(name, col, rough=0.5, metal=0.0, emit=None, strength=0.0, alpha=1.0, trans=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*col, 1)
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    if emit:
        bs.inputs["Emission Color"].default_value = (*emit, 1)
        bs.inputs["Emission Strength"].default_value = strength
    if trans:
        bs.inputs["Transmission Weight"].default_value = trans
    if alpha < 1:
        bs.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    return m


def assign(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def import_fbx(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    return [o for o in new if o.name in bpy.data.objects and o.type == "MESH"]


def group_bbox(obs):
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def to_origin(obs, rot_z=0.0, scale=1.0):
    """ย้ายกลุ่มให้กึ่งกลางอยู่ที่ x=y=0 ก้นอยู่ที่ z=0 (หมุน/ย่อขยายรอบกึ่งกลางก่อน)"""
    root = bpy.data.objects.new("Root", None)
    scn.collection.objects.link(root)
    mn, mx = group_bbox(obs)
    c = (mn + mx) / 2
    root.location = (c.x, c.y, mn.z)
    for o in obs:
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = mw
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, math.radians(rot_z))
    root.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    # ชดเชยหลังหมุน
    mn, mx = group_bbox(obs)
    root.location = (-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z)
    bpy.context.view_layer.update()
    return root


# ---------------------------------------------------------------- เวที (ใช้ร่วมทุกรูป)
world = bpy.data.worlds.new("W")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.006, 0.005, 0.007, 1)

floor_mat = flat_mat("Floor", (0.05, 0.035, 0.03), rough=0.85)
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
floor = bpy.context.active_object
assign(floor, floor_mat)
# ฉากหลังโค้ง (ไม่เห็นขอบพื้น)
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=14, depth=30, location=(0, 0, 0))
cyc = bpy.context.active_object
assign(cyc, flat_mat("Back", (0.03, 0.025, 0.03), rough=0.9))
for p in cyc.data.polygons:
    p.flip()


def light(kind, loc, energy, color, size=1.0, target=(0, 0, 0.3), spot=None):
    ld = bpy.data.lights.new(kind + str(len(bpy.data.lights)), kind)
    ld.energy = energy
    ld.color = color
    if kind in ("AREA",):
        ld.size = size
    if kind == "SPOT":
        ld.spot_size = math.radians(spot or 40)
        ld.spot_blend = 0.6
        ld.shadow_soft_size = size
    ob = bpy.data.objects.new(ld.name, ld)
    scn.collection.objects.link(ob)
    ob.location = loc
    d = Vector(target) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scn.collection.objects.link(cam)
scn.camera = cam
cam.data.lens = 60

LIGHTS = []


def stage(radius, tint=(1.0, 0.78, 0.52), rim=(0.45, 0.6, 1.0), key_mul=1.0):
    for o in LIGHTS:
        bpy.data.objects.remove(o)
    LIGHTS.clear()
    r = max(radius, 0.05)
    LIGHTS.append(light("SPOT", (r * 1.2, -r * 2.2, r * 4.0), 900 * r * r * key_mul, tint, size=r * 0.6, target=(0, 0, r * 0.4), spot=46))
    LIGHTS.append(light("AREA", (-r * 3.0, r * 2.5, r * 2.2), 260 * r * r, rim, size=r * 2.0, target=(0, 0, r * 0.5)))
    LIGHTS.append(light("AREA", (-r * 2.5, -r * 3.0, r * 1.0), 45 * r * r, (0.9, 0.85, 0.8), size=r * 3.0, target=(0, 0, r * 0.4)))


def frame(obs, d=(0.55, -1.0, 0.62), fill=0.68, lift=0.0):
    """ตั้งกล้องให้ของเต็มเฟรมประมาณ fill (ไอคอน Game Pass ถูกตัดเป็นวงกลม: เว้นขอบไว้)"""
    mn, mx = group_bbox(obs)
    c = (mn + mx) / 2 + Vector((0, 0, lift))
    rad = (mx - mn).length / 2
    fov = 2 * math.atan(18 / cam.data.lens)
    dist = rad / math.tan(fov / 2) / fill
    cam.location = c + Vector(d).normalized() * dist
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    return rad


def shoot(name):
    p = os.path.join(OUT, name + ".png")
    scn.render.filepath = p
    bpy.ops.render.render(write_still=True)
    log("png", p)


def show_only(obs):
    keep = set(obs) | {floor, cyc, cam} | set(LIGHTS)
    for o in scn.objects:
        if o.type in ("MESH", "FONT", "CURVE"):
            o.hide_render = o not in keep


def want(name):
    return not ONLY or ONLY == name


ALL = {}

# ---------------------------------------------------------------- 1) ไฟฉายตราช้าง (เปิดไฟ)
EF = os.path.join(MODELS, "ElephantFlashlight", "upload")
obs = import_fbx(os.path.join(EF, "ElephantFlashlight.fbx"))
for o in obs:
    if o.name.startswith("ElephantLens"):
        assign(o, flat_mat("Lens", (1.0, 0.92, 0.7), rough=0.1, emit=(1.0, 0.9, 0.62), strength=14))
    elif o.name.startswith("ElephantSidePanel"):
        assign(o, flat_mat("Panel", (0.95, 0.97, 1.0), emit=(0.95, 0.97, 1.0), strength=6))
    else:
        assign(o, tex_mat("EF", EF, "ElephantFlashlight_Body"))
ALL["Pass_ElephantFlashlight"] = (to_origin(obs, rot_z=-38, scale=1.0), obs)

# ---------------------------------------------------------------- 2-4) ของบนแผง Lobby
PS = os.path.join(MODELS, "PassStallItems", "upload")
obs = import_fbx(os.path.join(PS, "PassStallItems.fbx"))
for o in obs:
    for stem in ("PassGhostBook", "PassSandals", "PassPrayerBeads"):
        if o.name.startswith(stem):
            assign(o, tex_mat(stem, PS, stem))
            o["stem"] = stem
for stem, key, rz in (("PassGhostBook", "Pass_GhostBook", 18), ("PassSandals", "Pass_WingedSandals", 0), ("PassPrayerBeads", "Pass_FastPrayer", 10)):
    grp = [o for o in obs if o.get("stem") == stem]
    extra = []
    if stem == "PassPrayerBeads":  # ธูปปักในถ้วย + ปลายแดง
        mn, mx = group_bbox(grp)
    ALL[key] = (to_origin(grp, rot_z=rz), grp)

# ธูป 1 ดอกในถ้วยของประคำ (ถ้วยอยู่หลังขวาของเบาะ)
def incense_stick(loc, h, lit=True, tilt=(0, 0), r=0.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=(loc[0], loc[1], loc[2] + h / 2))
    st = bpy.context.active_object
    st.rotation_euler = (math.radians(tilt[0]), math.radians(tilt[1]), 0)
    assign(st, flat_mat("Stick", (0.55, 0.16, 0.1), rough=0.7))
    out = [st]
    top = st.matrix_world @ Vector((0, 0, h / 2))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=r * 1.5, location=top)
    tip = bpy.context.active_object
    assign(tip, flat_mat("Ember", (1.0, 0.35, 0.08), emit=(1.0, 0.32, 0.06), strength=40 if lit else 0))
    out.append(tip)
    return out

root_b, grp_b = ALL["Pass_FastPrayer"]
mn, mx = group_bbox(grp_b)
cup = Vector((mn.x + (mx.x - mn.x) * 0.80, mn.y + (mx.y - mn.y) * 0.75, mx.z * 0.6))
ALL["Pass_FastPrayer"] = (root_b, grp_b + incense_stick(cup, 0.24, tilt=(-8, 6)))

# ---------------------------------------------------------------- 5) ห้องใหญ่: วงทอง + คน 6 คน + แสงทองขึ้นจากพื้น
big = []
gold = flat_mat("Gold", (1.0, 0.62, 0.15), rough=0.3, metal=1.0, emit=(1.0, 0.55, 0.12), strength=2.2)
bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.035, major_segments=96, minor_segments=12, location=(0, 0, 0.035))
ring = bpy.context.active_object
assign(ring, gold)
big.append(ring)
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=0.9, location=(0, 0, 0.45), end_fill_type="NOTHING")
beam = bpy.context.active_object
bm = flat_mat("Beam", (1.0, 0.75, 0.3), emit=(1.0, 0.72, 0.28), strength=1.5, alpha=0.07)
assign(beam, bm)
beam.hide_render = True  # แผ่นแสงทึบเกินในไอคอน: ใช้วงทองเรืองแทน
body_m = flat_mat("Figure", (0.82, 0.8, 0.78), rough=0.6)
for i in range(6):
    a = 2 * math.pi * i / 6 + 0.3
    x, y = math.cos(a) * 0.55, math.sin(a) * 0.55
    for (sx, sy, sz, z) in ((0.26, 0.15, 0.28, 0.43), (0.12, 0.14, 0.29, 0.145), (0.2, 0.2, 0.2, 0.68)):
        for off in ((-0.065, 0), (0.065, 0)) if sz == 0.29 else ((0, 0),):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(x + off[0] * math.cos(a + math.pi / 2), y + off[0] * math.sin(a + math.pi / 2), z))
            c = bpy.context.active_object
            c.scale = (sx, sy, sz)
            c.rotation_euler = (0, 0, a + math.pi / 2)
            bpy.ops.object.modifier_add(type="BEVEL")
            c.modifiers[-1].width = 0.012
            c.modifiers[-1].segments = 2
            assign(c, body_m)
            big.append(c)
ALL["Pass_BigRoom"] = (None, big)

# ---------------------------------------------------------------- 6) ป้ายผีแกล้งทุกคน (รูปเดียวกับที่ผ่านการตรวจแล้ว) บนผนังไม้
poster_png = os.path.join(MODELS, "GhostPoster", "upload", "GhostPoster.png")
pm = bpy.data.materials.new("Poster")
pm.use_nodes = True
nt = pm.node_tree
bs = nt.nodes["Principled BSDF"]
t = nt.nodes.new("ShaderNodeTexImage")
t.image = bpy.data.images.load(poster_png)
nt.links.new(t.outputs["Color"], bs.inputs["Base Color"])
nt.links.new(t.outputs["Alpha"], bs.inputs["Alpha"])
bs.inputs["Roughness"].default_value = 0.8
try:
    pm.surface_render_method = "DITHERED"
except Exception:
    pass
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0.6))
poster = bpy.context.active_object
poster.scale = (0.75, 1.0, 1)
poster.rotation_euler = (math.radians(90), 0, math.radians(4))
assign(poster, pm)
bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.03, 0.6))
wall = bpy.context.active_object
wall.scale = (4.0, 0.04, 3.0)
assign(wall, flat_mat("Plank", (0.16, 0.11, 0.075), rough=0.85))
ALL["Product_GhostPrank"] = (None, [poster, wall])
PRANK_FRAME = [poster]

# ---------------------------------------------------------------- 7) ต่อธูป: กระถางธูป + ธูป 3 ดอก (ดอกกลางเพิ่งจุด)
obs = import_fbx(os.path.join(MODELS, "IncensePot.fbx"))
for o in obs:
    assign(o, tex_mat("Pot", MODELS, "IncensePot"))
root_p = to_origin(obs, rot_z=0)
mn, mx = group_bbox(obs)
h = mx.z - mn.z
w = mx.x - mn.x
sticks = []
for i, (dx, lit, tilt) in enumerate(((-0.16, True, (0, -7)), (0.0, True, (0, 0)), (0.16, False, (0, 7)))):
    sticks += incense_stick((dx * w * 0.7, 0, h * 0.75), w * 1.1, lit=lit, tilt=tilt, r=w * 0.012)
# เปลวไฟเล็กบนดอกกลาง
bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=w * 0.025, depth=w * 0.09, location=(0, 0, h * 0.75 + w * 1.1 + w * 0.06))
flame = bpy.context.active_object
assign(flame, flat_mat("Flame", (1.0, 0.75, 0.3), emit=(1.0, 0.62, 0.2), strength=60))
ALL["Product_IncenseRelight"] = (root_p, obs + sticks + [flame])

# ---------------------------------------------------------------- 8) ร่วมทำบุญ: ตู้บริจาค + เหรียญทอง + ตัวเลขยอด
obs = import_fbx(os.path.join(MODELS, "DonationBox.fbx"))
for o in obs:
    if "Glass" in o.name:
        assign(o, flat_mat("Glass", (0.85, 0.9, 0.92), rough=0.05, alpha=0.25))
    else:
        assign(o, tex_mat("DB", MODELS, "DonationBox"))
root_d = to_origin(obs, rot_z=-25)
mn, mx = group_bbox(obs)
H = mx.z - mn.z
coin_m = flat_mat("Coin", (1.0, 0.76, 0.3), rough=0.25, metal=1.0)
coins = []
for i, (x, y, z, rx) in enumerate(((0.32, -0.36, 0, 0), (0.42, -0.26, 0.0, 0), (0.37, -0.31, 1, 0), (-0.38, -0.34, 0, 0), (0.25, -0.5, 0, 70))):
    r = H * 0.055
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=r * 0.25, location=(x * H, y * H, r * 0.125 + z * r * 0.26 + (r if rx else 0)))
    c = bpy.context.active_object
    c.rotation_euler = (math.radians(rx), 0, 0)
    assign(c, coin_m)
    coins.append(c)
for c in coins:
    bpy.data.objects.remove(c)
DON = obs

# ---------------------------------------------------------------- render
for name, (root, obs) in ALL.items():
    if not want(name):
        continue
    show_only(obs)
    if name == "Pass_BigRoom":
        rad = frame(obs, d=(0.0, -1.0, 0.8), fill=0.95)
        stage(rad, tint=(1.0, 0.86, 0.6))
    elif name == "Product_GhostPrank":
        rad = frame(PRANK_FRAME, d=(0.12, -1.0, 0.08), fill=0.92)
        stage(rad, tint=(0.75, 0.95, 0.85), rim=(0.5, 0.3, 0.35), key_mul=0.8)
    elif name == "Pass_ElephantFlashlight":
        rad = frame(obs, fill=0.95)
        stage(rad, key_mul=0.8)
    elif name == "Product_IncenseRelight":
        rad = frame(obs, d=(0.4, -1.0, 0.4), fill=0.92)
        stage(rad, key_mul=0.7)
    else:
        rad = frame(obs, d=(0.5, -1.0, 0.55), fill=1.0)
        stage(rad)
    shoot(name)

font_m = flat_mat("NumGold", (1.0, 0.78, 0.32), rough=0.25, metal=1.0, emit=(1.0, 0.7, 0.25), strength=0.6)
for amount in (10, 50, 100, 500):
    name = f"Product_Donate{amount}"
    if not want(name):
        continue
    bpy.ops.object.text_add(location=(0, -H * 0.62, 0.02))
    tx = bpy.context.active_object
    tx.data.body = str(amount)
    tx.data.align_x = "CENTER"
    tx.data.extrude = H * 0.03
    tx.data.bevel_depth = H * 0.008
    tx.data.size = H * (0.5 if amount < 100 else 0.42)
    tx.data.extrude = H * 0.045
    tx.rotation_euler = (math.radians(90), 0, math.radians(19))
    tx.location = (H * 0.1, -H * 0.45, H * 0.02)
    assign(tx, font_m)
    show_only(DON + [tx])
    rad = frame(DON + [tx], d=(0.35, -1.0, 0.3), fill=0.98)
    stage(rad, key_mul=0.9)
    shoot(name)
    bpy.data.objects.remove(tx)
log("done")
