# ต้นไม้ฉากหลัง Lobby แบบเบา (ผู้ใช้ 2026-11-24 "ทำทั้งหมดเลย"): กอกล้วยป่า / ลำต้นมะม่วงป่า / หญ้า
# รัน: blender -b --factory-startup --python tools/blender/lobby_far_veg.py
# ผลลัพธ์: assets/models/LobbyFarVeg/upload/LobbyFarVeg.fbx (ไม่มี texture: ใช้ SurfaceAppearance เดิมของแต่ละชิ้น UV เดิม)
# วิธี: mesh เดิม -> ลบหน้าหลังที่ซ้ำ (เดิมปั้นสองหน้าซ้อนกัน ใช้ MeshPart.DoubleSided แทน) -> Decimate
# แกน: Blender -> Roblox = (-x, z, y) / 0.28 (เหมือนชุดอื่น)
import bpy, bmesh, math, os
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "LobbyFarVeg")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
S = 0.28
# ชื่อเดิม -> (ชื่อใหม่, ไฟล์, สามเหลี่ยมเป้าหมาย)
JOBS = [
    ("BananaClump", "FarBananaClump", "BananaClump.fbx", 620),
    ("BananaClump_B", "FarBananaClump_B", "BananaClump.fbx", 520),
    ("BananaClump_Base", "FarBananaClump_Base", "BananaClump.fbx", 560),
    ("MangoTrunk", "FarMangoTrunk", "MangoTree.fbx", 520),
    ("WildGrassClump", "LiteWildGrass", "ThaiGrasses.fbx", 1300),
    ("LemongrassClump", "LiteLemongrass", "ThaiGrasses.fbx", 800),
]


def log(*a):
    print("FV|", *a)


def bbox(me):
    xs = [v.co for v in me.vertices]
    mn = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
    mx = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
    c, s = (mn + mx) / 2 / S, (mx - mn) / S
    return Vector((-c.x, c.z, c.y)), Vector((s.x, s.z, s.y))


def tris(me):
    me.calc_loop_triangles()
    return len(me.loop_triangles)


scn = bpy.context.scene
objs, originals = {}, {}
for f in sorted({j[2] for j in JOBS}):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, f))
    for o in [x for x in bpy.data.objects if x not in before]:
        job = next((j for j in JOBS if j[2] == f and j[0] == o.name.split(".")[0]), None)
        if o.type != "MESH" or not job:
            if o.type == "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
            continue
        mw = o.matrix_world.copy()
        me = o.data.copy()
        me.transform(mw)
        o2 = bpy.data.objects.new("orig_" + job[0], me)
        scn.collection.objects.link(o2)
        originals[job[0]] = o2
        me2 = me.copy()
        me2.name = job[1]
        n = bpy.data.objects.new(job[1], me2)
        scn.collection.objects.link(n)
        bpy.data.objects.remove(o, do_unlink=True)
        # หน้าซ้ำ (หลัง = หน้ากลับด้าน จุดเดียวกัน) -> เหลือหน้าเดียว
        bm = bmesh.new()
        bm.from_mesh(me2)
        seen, kill = set(), []
        for fc in bm.faces:
            key = tuple(sorted((round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)) for v in fc.verts))
            if key in seen:
                kill.append(fc)
            else:
                seen.add(key)
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        # เชื่อมจุดที่แยกเพราะ normal แต่รักษารอย UV (จุดเดียวกัน ตำแหน่งเดียวกัน)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        # แผ่นใบ (ชิ้นเปิด): ให้หน้าที่เหลือหันขึ้นเสมอ แสงไม่สลับมืด/สว่าง
        done = set()
        for f0 in list(bm.faces):
            if f0 in done:
                continue
            st, comp = [f0], {f0}
            while st:
                x = st.pop()
                for ed in x.edges:
                    for y in ed.link_faces:
                        if y not in comp:
                            comp.add(y)
                            st.append(y)
            done |= comp
            if any(len(ed.link_faces) == 1 for x in comp for ed in x.edges) and job[0].startswith("Banana"):
                bmesh.ops.recalc_face_normals(bm, faces=list(comp))
                if sum((x.normal.z * x.calc_area() for x in comp)) < 0:
                    bmesh.ops.reverse_faces(bm, faces=list(comp))
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.to_mesh(me2)
        bm.free()
        me2.update()
        single = tris(me2)
        mod = n.modifiers.new("dec", "DECIMATE")
        mod.ratio = min(1.0, job[3] / max(1, single))
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        me3 = bpy.data.meshes.new_from_object(n.evaluated_get(dg))
        me3.name = job[1]
        n.modifiers.clear()
        n.data = me3
        for p in me3.polygons:
            p.use_smooth = True
        objs[job[1]] = n
        oc, os_ = bbox(me)
        nc, ns = bbox(me3)
        log(f"{job[0]} {tris(me)} -> single {single} -> {tris(me3)} uv {len(me3.uv_layers)}")
        log(f"LUA [\"{job[0]}\"] = {{ n = \"{job[1]}\", oc = Vector3.new({oc.x:.4f}, {oc.y:.4f}, {oc.z:.4f}), os = Vector3.new({os_.x:.4f}, {os_.y:.4f}, {os_.z:.4f}), nc = Vector3.new({nc.x:.4f}, {nc.y:.4f}, {nc.z:.4f}), ns = Vector3.new({ns.x:.4f}, {ns.y:.4f}, {ns.z:.4f}) }},")

# ---------------------------------------------------------------- ส่งออก (ไม่มีวัสดุ)
plain = bpy.data.materials.new("LobbyFarVeg_Mat")
bpy.ops.object.select_all(action="DESELECT")
keepmats = {}
for nm, o in objs.items():
    keepmats[nm] = [m for m in o.data.materials]
    o.data.materials.clear()
    o.data.materials.append(plain)
    o.select_set(True)
bpy.context.view_layer.objects.active = objs["FarBananaClump"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "LobbyFarVeg.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="OFF", use_custom_props=False, path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx ok")

# ---------------------------------------------------------------- ภาพเทียบ: แถวหลัง = เดิม แถวหน้า = เบา
TEXOF = {"BananaClump.fbx": "BananaClump_Color.png", "MangoTree.fbx": "MangoTree_Color.png", "ThaiGrasses.fbx": "ThaiGrasses_Color.png"}
mats = {}
for f, t in TEXOF.items():
    m = bpy.data.materials.new("P_" + f)
    m.use_nodes = True
    tx = m.node_tree.nodes.new("ShaderNodeTexImage")
    tx.image = bpy.data.images.load(os.path.join(ROOT, t))
    m.node_tree.links.new(tx.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    mats[f] = m
GROUPS = [["BananaClump", "BananaClump_B", "BananaClump_Base"], ["MangoTrunk"], ["WildGrassClump"], ["LemongrassClump"]]
XPOS = [0, 5.5, 9.5, 12.5]
for gi, g in enumerate(GROUPS):
    for old in g:
        job = next(j for j in JOBS if j[0] == old)
        for row, o in enumerate((originals[old], objs[job[1]])):
            o.data.materials.clear()
            o.data.materials.append(mats[job[2]])
            base = originals[g[0]].data if gi else None
            cx = 0
            if gi:
                vs = [v.co for v in originals[old].data.vertices]
                cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
            zz = min(v.co.z for v in originals[old].data.vertices) if gi else 0
            o.location = (XPOS[gi] - cx, 0, (0 if row else 5.0) - zz)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
scn.collection.objects.link(sun)
w = bpy.data.worlds.new("W")
scn.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.6, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 19
scn.collection.objects.link(cam)
scn.camera = cam
cam.location = (6, -40, 4.8)
cam.rotation_euler = (math.radians(90), 0, 0)
scn.render.resolution_x, scn.render.resolution_y = 1400, 850
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        scn.render.engine = eng
        break
    except TypeError:
        pass
scn.render.filepath = os.path.join(OUT, "LobbyFarVeg.png")
bpy.ops.render.render(write_still=True)
log("preview ok")
