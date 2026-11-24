# ต้นมะม่วง Lobby v2 — ใบรวมเป็น mesh + วงห้องเป็นชิ้นเดียว (ผู้ใช้ 2026-11-24 "ทำให้เบาสุด")
# รัน: blender -b --factory-startup --python tools/blender/mango_v2.py
# ผลลัพธ์: assets/models/MangoV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + ข้อมูลใบเดิม
#
# ของเดิม: ใบ 1 แผ่น = Part + Decal 2 อัน (ลาน 688 แผ่น/ต้น, ป่าหลังหมอก 112 แผ่น/ต้น)
# ของใหม่: แผ่นเดิมทุกแผ่น ตำแหน่ง/ขนาด/ทิศเท่าเดิม รวมเป็น mesh: MangoCanopy_1..4 (ต้นในลาน แบ่งตามทิศ) และ MangoFar (ป่า)
#   ภาพใบเดิม ย้อมสีเท่า Decal เดิม (150,170,140) ลงในภาพเลย (MeshPart ย้อม TextureID ไม่ได้)
#   normal ของใบชี้ออกจากกลางพุ่ม (พุ่มดูกลม) ทั้งสองหน้าใช้ค่าเดียวกัน
# RoomRing = วงไฟนีออนของห้อง (เดิม 36 ชิ้นต่อวง) รัศมี 10 หน้าตัด 0.5 x 0.12
# แกน: ข้อมูลใบเป็น Roblox studs (Y ขึ้น) เทียบกลาง MangoTrunk -> Blender = (-X, Z, Y) x 0.28
import bpy, math, os, sys
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "MangoV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
S = 0.28
TINT = (150 / 255, 170 / 255, 140 / 255)
TEX = 512
SECTORS = 4


def log(*a):
    print("MG|", *a)


def R2B(p):
    return Vector((-p[0], p[2], p[1]))


cards = {"NEAR": [], "FAR": []}
for line in open(os.path.join(OUT, "mango_cards.txt"), encoding="utf-8"):
    w = line.split()
    if len(w) == 14 and w[0] == "MCARD":
        v = [float(x) for x in w[2:]]
        c, size, r, u = Vector(v[0:3]), Vector(v[3:6]), Vector(v[6:9]), Vector(v[9:12])
        z = r.cross(u)
        if size.z <= min(size.x, size.y):  # แผ่นตั้ง
            ax, ay, cw, ch, flat = r, u, size.x, size.y, False
        else:  # แผ่นนอน
            ax, ay, cw, ch, flat = r, z, size.x, size.z, True
        cards[w[1]].append((c, ax.normalized(), ay.normalized(), cw, ch, flat))
log({k: len(v) for k, v in cards.items()})

# ---------------------------------------------------------------- ภาพใบ ย้อมสี + ย่อ
src = bpy.data.images.load(os.path.join(ROOT, "MangoTree_LeafCard.png"))
src.scale(TEX, TEX)
px = list(src.pixels)


def s2l(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def l2s(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


tl = [s2l(c) for c in TINT]
# สีของพิกเซลโปร่ง = สีใบเฉลี่ย (ขอบใบไม่มีคราบดำตอนย่อภาพ)
sumc, n = [0, 0, 0], 0
for i in range(0, len(px), 4):
    if px[i + 3] > 0.5:
        for k in range(3):
            sumc[k] += px[i + k]
        n += 1
avg = [c / max(1, n) for c in sumc]
for i in range(0, len(px), 4):
    for k in range(3):
        c = px[i + k] if px[i + 3] > 0.02 else avg[k]
        px[i + k] = l2s(s2l(c) * tl[k])
out_png = os.path.join(UP, "MangoV2_Leaf_Color.png")
img = bpy.data.images.new("MangoV2_Leaf_Color", TEX, TEX, alpha=True)
img.alpha_mode = "STRAIGHT"
img.pixels = px
img.filepath_raw = out_png
img.file_format = "PNG"
img.save()
log("texture", out_png)
leaf = bpy.data.images.load(out_png)
lm = bpy.data.materials.new("MangoV2_Leaf_Mat")
lm.use_nodes = True
nt = lm.node_tree
bs = nt.nodes["Principled BSDF"]
tx = nt.nodes.new("ShaderNodeTexImage")
tx.image = leaf
nt.links.new(tx.outputs["Color"], bs.inputs["Base Color"])
nt.links.new(tx.outputs["Alpha"], bs.inputs["Alpha"])
bs.inputs["Roughness"].default_value = 0.75

OBJ = {}
scn = bpy.context.scene


def build(name, data):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p * S) for p in data["v"]], [], data["f"])
    me.update()
    uvl = me.uv_layers.new(name="UVMap")
    normals = [None] * len(me.loops)
    for poly, uvs, nb in zip(me.polygons, data["uv"], data["n"]):
        poly.use_smooth = True
        for li, uv in zip(poly.loop_indices, uvs):
            uvl.data[li].uv = uv
            normals[li] = tuple(nb)
    me.normals_split_custom_set(normals)
    me.materials.append(lm)
    ob = bpy.data.objects.new(name, me)
    scn.collection.objects.link(ob)
    OBJ[name] = ob
    log(f"{name}: {len(me.polygons) * 2} tris")


def canopy(kind, names):
    lst = cards[kind]
    cen = sum((c for c, *_ in lst), Vector()) / len(lst)
    log(f"CENTROID {kind} {cen.x:.4f} {cen.y:.4f} {cen.z:.4f}")
    low = cen - Vector((0, 3, 0))
    secs = [{"v": [], "f": [], "uv": [], "n": []} for _ in names]
    for (c, ax, ay, w, h, flat) in lst:
        pts = [c - ax * w / 2 - ay * h / 2, c + ax * w / 2 - ay * h / 2, c + ax * w / 2 + ay * h / 2, c - ax * w / 2 + ay * h / 2]
        uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
        ang = math.atan2(c.z - cen.z, c.x - cen.x)
        sd = secs[int(((ang + math.pi) / (2 * math.pi)) * len(names)) % len(names)]
        fn = ax.cross(ay).normalized()
        outw = (c - low).normalized()
        if fn.dot(outw) < 0:
            fn = -fn
        nb = R2B((fn * 0.3 + outw * 0.7).normalized()).normalized()
        for side in ((1,) if False else (0, 1)):
            o = len(sd["v"])
            sd["v"] += [R2B(p) for p in pts]
            sd["f"].append((o, o + 1, o + 2, o + 3) if side == 0 else (o + 3, o + 2, o + 1, o))
            sd["uv"].append(uvs if side == 0 else list(reversed(uvs)))
            sd["n"].append(nb)
    for nm, sd in zip(names, secs):
        build(nm, sd)


canopy("NEAR", [f"MangoCanopy_{i + 1}" for i in range(SECTORS)])
canopy("FAR", ["MangoFar"])

# ---------------------------------------------------------------- วงไฟห้อง
SEG, R, W, H = 72, 10.0, 0.5, 0.12
v, f = [], []
for k in range(SEG):
    a = k / SEG * 2 * math.pi
    for (rr, y) in ((R - W / 2, -H / 2), (R + W / 2, -H / 2), (R + W / 2, H / 2), (R - W / 2, H / 2)):
        v.append((math.cos(a) * rr * S, math.sin(a) * rr * S, y * S))
for k in range(SEG):
    a, b = k * 4, ((k + 1) % SEG) * 4
    for j in range(4):
        j2 = (j + 1) % 4
        f.append((a + j, b + j, b + j2, a + j2))
me = bpy.data.meshes.new("RoomRing")
me.from_pydata(v, [], f)
me.update()
import bmesh  # noqa: E402

bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(me)
bm.free()
me.uv_layers.new(name="UVMap")
rm = bpy.data.materials.new("RoomRing_Mat")
me.materials.append(rm)
ob = bpy.data.objects.new("RoomRing", me)
scn.collection.objects.link(ob)
OBJ["RoomRing"] = ob
log(f"RoomRing: {len(me.polygons) * 2} tris")

for nm, ob in OBJ.items():
    cs = [vv.co for vv in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c, sz = (mn + mx) / 2, mx - mn
    log(f"BBOX {nm} center_rbx=({-c.x:.4f}, {c.z:.4f}, {c.y:.4f}) size_rbx=({sz.x:.4f}, {sz.z:.4f}, {sz.y:.4f})")

bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ["MangoCanopy_1"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "MangoV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="OFF", use_custom_props=False, path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx ok")

# ---------------------------------------------------------------- ภาพตัวอย่าง: ต้นในลาน (ซ้าย) / ต้นป่า (ขวา) / วงห้อง (หน้า)
OBJ["MangoFar"].location = (9, 0, 0)
OBJ["RoomRing"].location = (4.5, -7, -5 * S)
rm.use_nodes = True
e = rm.node_tree.nodes["Principled BSDF"]
e.inputs["Emission Color"].default_value = (1, 0.1, 0.05, 1)
e.inputs["Emission Strength"].default_value = 2
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scn.collection.objects.link(sun)
world = bpy.data.worlds.new("W")
scn.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.3, 0.35, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scn.collection.objects.link(cam)
scn.camera = cam
cam.location = (4.5, -26, 4)
cam.rotation_euler = (math.radians(84), 0, 0)
scn.render.resolution_x, scn.render.resolution_y = 1100, 700
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scn.render.engine = eng
        break
    except TypeError:
        pass
scn.render.filepath = os.path.join(OUT, "MangoV2.png")
bpy.ops.render.render(write_still=True)
log("preview ok")
