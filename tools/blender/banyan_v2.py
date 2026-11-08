# ต้นไทร v2 — ใบไม้รวมเป็น mesh (ผู้ใช้ 2026-11-08: "ต้นไทรมีปัญหา Performance ปั้นให้รายละเอียดมากกว่าเดิมแต่กินทรัพยากรน้อยลง ขนาดเท่าเดิม")
# รัน: blender -b --factory-startup --python tools/blender/banyan_v2.py
# ผลลัพธ์: assets/models/BanyanV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend + ข้อมูลใบเดิม
#
# ของเดิม: ใบ 696 แผ่น = Part 696 ชิ้น + Decal 1,392 อัน (สองหน้า โปร่งแสง) และ GrassWind ขยับทุกแผ่น 12 ครั้ง/วิ ตอนกล้องอยู่ใกล้
# ของใหม่: ใบแต่ละแผ่นเดิมแตกเป็นช่อใบเล็กลง 3 ช่อ (2,088 ช่อ ละเอียดขึ้น พุ่มแน่นขึ้น) รวมเป็น mesh 8 ชิ้นตามทิศรอบต้น (BanyanCanopy_1..8)
#   + รากอากาศห้อยเพิ่ม (BanyanHangingRoots) · normal ของใบชี้ออกจากกลางพุ่ม (พุ่มดูกลมมีมิติ ไม่แบนเป็นแผ่น)
#   ตำแหน่ง/ขนาดพุ่มมาจากใบเดิมในฉากจริง (assets/models/BanyanV2/banyan_cards.txt ส่งออกจาก Studio เทียบจุด origin ของต้น)
#   -> ทรงพุ่มเท่าเดิม ไม่ต้องจัดวางใหม่ · ลำต้น/กิ่ง/รากเดิม (SacredBanyanTree.fbx) ไม่เปลี่ยน
# แกน: ข้อมูลใบเป็น Roblox studs (Y ขึ้น) เทียบ origin ของต้น -> Blender = (-X, Z, Y) x 0.28
import bpy, math, os, sys, random, shutil
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "BanyanV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = 512
V.SAMPLES = 12
S = V.S
SPRIGS = 3          # ช่อใบต่อแผ่นเดิม
SPRIG_SCALE = 0.62  # ขนาดช่อเทียบแผ่นเดิม
SECTORS = 8
rng = random.Random(2026)


def log(*a):
    print("BY|", *a)


def R2B(p):  # Roblox studs -> Blender studs (vehlib คูณ S ตอนสร้าง mesh)
    return Vector((-p[0], p[2], p[1]))


# ---------------------------------------------------------------- ใบเดิม
cards = []
for line in open(os.path.join(OUT, "banyan_cards.txt"), encoding="utf-8"):
    if line.startswith("CARD"):
        v = [float(x) for x in line.split()[1:]]
        c, size, r, u = Vector(v[0:3]), Vector(v[3:6]), Vector(v[6:9]), Vector(v[9:12])
        z = r.cross(u)
        if size.z <= min(size.x, size.y):  # แผ่นตั้ง: ระนาบ right/up
            ax, ay, w, h = r, u, size.x, size.y
        else:  # แผ่นนอน (ยอดพุ่ม): ระนาบ right/look
            ax, ay, w, h = r, z, size.x, size.z
        cards.append((c, ax.normalized(), ay.normalized(), w, h))
log("cards", len(cards))
centroid = sum((c for c, *_ in cards), Vector()) / len(cards)
centroid.y -= 3.0  # จุดกลางพุ่มต่ำลงนิด: ใบล่างชี้ลง ใบบนชี้ขึ้น

# ---------------------------------------------------------------- ช่อใบ -> mesh แยกตามทิศ
sector_data = [{"v": [], "f": [], "uv": [], "n": []} for _ in range(SECTORS)]
for (c, ax, ay, w, h) in cards:
    nrm = ax.cross(ay).normalized()
    outward = (c - centroid).normalized()
    for k in range(SPRIGS):
        # กระจายช่อเล็กในพื้นที่แผ่นเดิม + หนาขึ้นเล็กน้อย
        off = ax * rng.uniform(-0.32, 0.32) * w + ay * rng.uniform(-0.32, 0.32) * h + nrm * rng.uniform(-0.3, 0.3) * min(w, h)
        q = Matrix.Rotation(math.radians(rng.uniform(-28, 28)), 3, Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized())
        a2, b2 = q @ ax, q @ ay
        sw, sh = w * SPRIG_SCALE * rng.uniform(0.85, 1.15), h * SPRIG_SCALE * rng.uniform(0.85, 1.15)
        cc = c + off
        pts = [cc - a2 * sw / 2 - b2 * sh / 2, cc + a2 * sw / 2 - b2 * sh / 2, cc + a2 * sw / 2 + b2 * sh / 2, cc - a2 * sw / 2 + b2 * sh / 2]
        uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        rot = rng.randrange(4)
        uvs = uvs[rot:] + uvs[:rot]
        if rng.random() < 0.5:
            uvs = [(1 - u_, v_) for (u_, v_) in uvs]
        ang = math.atan2(cc.z, cc.x)
        si = int(((ang + math.pi) / (2 * math.pi)) * SECTORS) % SECTORS
        sd = sector_data[si]
        # normal: ผสมทิศหน้าใบกับทิศออกจากกลางพุ่ม (ทั้งสองหน้าใช้ค่าเดียวกัน แสงสม่ำเสมอ)
        fn = a2.cross(b2).normalized()
        if fn.dot(outward) < 0:
            fn = -fn
        nn = (fn * 0.3 + (cc - centroid).normalized() * 0.7).normalized()
        nb = R2B(nn).normalized()
        for side in (0, 1):
            o = len(sd["v"])
            sd["v"] += [R2B(p) for p in pts]
            sd["f"].append((o, o + 1, o + 2, o + 3) if side == 0 else (o + 3, o + 2, o + 1, o))
            sd["uv"].append(uvs if side == 0 else list(reversed(uvs)))
            sd["n"].append(nb)

# ---------------------------------------------------------------- texture ใบ (ใช้ภาพช่อใบเดิม มีช่องโปร่ง)
leaf_png = os.path.join(UP, "BanyanV2_Leaf_Color.png")
shutil.copyfile(os.path.join(ROOT, "SacredBanyanTree_LeafCard.png"), leaf_png)
leaf_img = bpy.data.images.load(leaf_png)
lm = bpy.data.materials.new("BanyanV2_Leaf_Mat")
lm.use_nodes = True
nt = lm.node_tree
bs = nt.nodes["Principled BSDF"]
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = leaf_img
nt.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
nt.links.new(tx.outputs["Alpha"], bs.inputs["Alpha"])
bs.inputs["Roughness"].default_value = 0.7

OBJ = {}
scn = bpy.context.scene
for i, sd in enumerate(sector_data):
    name = f"BanyanCanopy_{i + 1}"
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p * S) for p in sd["v"]], [], sd["f"])
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    for poly, uvs in zip(me.polygons, sd["uv"]):
        for li, uv in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = uv
    loop_normals = [None] * len(me.loops)
    for poly, nb in zip(me.polygons, sd["n"]):
        poly.use_smooth = True
        for li in poly.loop_indices:
            loop_normals[li] = tuple(nb)
    me.normals_split_custom_set(loop_normals)
    me.materials.append(lm)
    ob = bpy.data.objects.new(name, me)
    scn.collection.objects.link(ob)
    OBJ[name] = ob
    log(f"{name}: {len(me.polygons) * 2} tris")

# ---------------------------------------------------------------- รากอากาศห้อยเพิ่ม (จากใต้พุ่มลงมา ไม่ถึงพื้น)
V.make_mat("bark", V.L((78, 62, 48)), 0.85, 0.0, dirt=0.4, bump=0.4, bump_scale=40)
under = [cd for cd in cards if 23.0 < cd[0].y < 31.0 and 6.0 < math.hypot(cd[0].x, cd[0].z) < 16.5]
rng.shuffle(under)
for (c, *_rest) in under[:46]:
    top = Vector((c.x, c.y - 0.8, c.z))
    length = rng.uniform(9.0, 17.0)
    end_y = max(5.5, top.y - length)
    pts = []
    n = 9
    sway = Vector((rng.uniform(-1, 1), 0, rng.uniform(-1, 1))).normalized() * rng.uniform(0.2, 0.7)
    for k in range(n + 1):
        t = k / n
        p = top.lerp(Vector((top.x, end_y, top.z)), t) + sway * math.sin(t * math.pi * rng.uniform(0.6, 1.4)) + Vector((rng.uniform(-0.08, 0.08), 0, rng.uniform(-0.08, 0.08)))
        pts.append(tuple(R2B(p)))
    r0 = rng.uniform(0.07, 0.13)
    V.put("BanyanHangingRoots", V.tube(pts, [r0 * (1 - 0.6 * k / n) for k in range(n + 1)], 5), "bark", 0)
roots = V.build_object("BanyanHangingRoots")
V.uv_unwrap(roots)
log("baking roots")
rm = V.final_material("BanyanV2_Roots", V.bake(roots, "BanyanV2_Roots"))
roots.data.materials.clear()
roots.data.materials.append(rm)
OBJ["BanyanHangingRoots"] = roots

for nm, ob in OBJ.items():
    cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c = (mn + mx) / 2
    sz = mx - mn
    log(f"BBOX {nm} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({sz.x:.3f},{sz.z:.3f},{sz.y:.3f})")

bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ["BanyanCanopy_1"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "BanyanV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="OFF", use_custom_props=False, path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "BanyanV2.fbx"))


# ---------------------------------------------------------------- ภาพตัวอย่าง: ลำต้นเดิม + ใบใหม่
def preview():
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "SacredBanyanTree.fbx"))
    old_tex = bpy.data.images.load(os.path.join(ROOT, "SacredBanyanTree_Color.png"))
    for o in bpy.data.objects:
        if o.type == "MESH" and o.name.startswith(("Banyan", "Sacred")) and not o.name.startswith(("BanyanCanopy", "BanyanHanging")):
            m = bpy.data.materials.new("Old_" + o.name)
            m.use_nodes = True
            t = m.node_tree.nodes.new("ShaderNodeTexImage")
            t.image = old_tex
            m.node_tree.links.new(t.outputs[0], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
            o.data.materials.clear()
            o.data.materials.append(m)
    lm.surface_render_method = "DITHERED"
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1300, 900
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.46, 0.52, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-30, -30, 0), (30, -30, 0), (30, 30, 0), (-30, 30, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gm = bpy.data.materials.new("G")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.18, 0.12, 1)
    gp.materials.append(gm)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((0, 0, 17)) * S

    def shot(fn, d, dist=22.0, lens=40):
        cam.data.lens = lens
        cam.location = tgt + Vector(d).normalized() * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    shot("BanyanV2.png", (-1.0, -1.2, 0.35))
    shot("BanyanV2_side.png", (1.0, 0.2, 0.1))
    shot("BanyanV2_under.png", (0.3, -1.0, -0.05), dist=12.0, lens=24)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "banyan_v2.blend"))
log("done")
