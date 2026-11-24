# ลบหน้าซ้ำของต้นไม้ (ผู้ใช้ 2026-11-24): mesh เดิมปั้นแผ่นใบสองหน้าทับกัน -> เหลือหน้าเดียว ใช้ MeshPart.DoubleSided แทน
# รูปทรง จุด UV normal เดิมทุกอย่าง (ไม่ Decimate) ใช้ SurfaceAppearance เดิม
# รัน: blender -b --factory-startup --python tools/blender/veg_dedupe.py
# ผลลัพธ์: assets/models/VegDedupe/upload/VegDedupe.fbx (ชื่อชิ้น DD_<ชื่อเดิม>)
import bpy, bmesh, os
from mathutils import Vector
from mathutils.kdtree import KDTree

bpy.ops.wm.read_factory_settings(use_empty=True)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
UP = os.path.join(ROOT, "VegDedupe", "upload")
os.makedirs(UP, exist_ok=True)
S = 0.28
FILES = {
    "BananaClump.fbx": ["BananaClump", "BananaClump_B", "BananaClump_Base"],
    "ThaiGrasses.fbx": ["WildGrassClump", "LemongrassClump"],
    "BananaBunch.fbx": ["BananaBunch"],
    "BananaBlossom.fbx": ["BananaBlossom"],
    "RiceTile.fbx": ["RiceTile"],
}


def log(*a):
    print("DD|", *a)


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
plain = bpy.data.materials.new("VegDedupe_Mat")
out = []
for f, names in FILES.items():
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, f))
    for o in [x for x in bpy.data.objects if x not in before]:
        n = o.name.split(".")[0]
        if o.type == "MESH" and n in names:
            me = o.data.copy()
            me.transform(o.matrix_world)
            t0, b0 = tris(me), bbox(me)
            bm = bmesh.new()
            bm.from_mesh(me)
            # จุดที่ตำแหน่งเดียวกัน (ห่างไม่เกิน 0.02 มม.) นับเป็นจุดเดียว ใช้เทียบอย่างเดียว ไม่เชื่อม mesh
            kd = KDTree(len(bm.verts))
            bm.verts.ensure_lookup_table()
            for i, v in enumerate(bm.verts):
                kd.insert(v.co, i)
            kd.balance()
            rep = [min(h[1] for h in kd.find_range(v.co, 2e-5)) for v in bm.verts]
            idx = {v: rep[i] for i, v in enumerate(bm.verts)}
            best = {}
            kill = []
            for fc in bm.faces:
                key = tuple(sorted(idx[v] for v in fc.verts))
                if len(set(key)) < 3:  # หน้าที่ยุบเป็นเส้น มองไม่เห็น
                    kill.append(fc)
                    continue
                if key in best:
                    # เก็บหน้าที่หันขึ้น
                    old = best[key]
                    if fc.normal.z > old.normal.z:
                        kill.append(old)
                        best[key] = fc
                    else:
                        kill.append(fc)
                else:
                    best[key] = fc
            bmesh.ops.delete(bm, geom=kill, context="FACES")
            bm.to_mesh(me)
            bm.free()
            t1, b1 = tris(me), bbox(me)
            log(f"{n}: {t0} -> {t1} ({100 * t1 // max(1, t0)}%) bbox shift {(b1[0] - b0[0]).length:.5f} size {(b1[1] - b0[1]).length:.5f}")
            if t1 < t0 * 0.9:
                me.name = "DD_" + n
                me.materials.clear()
                me.materials.append(plain)
                ob = bpy.data.objects.new("DD_" + n, me)
                scn.collection.objects.link(ob)
                out.append(ob)
                c, s = b1
                log(f"LUA {n} = {{ c = Vector3.new({c.x:.4f}, {c.y:.4f}, {c.z:.4f}), s = Vector3.new({s.x:.4f}, {s.y:.4f}, {s.z:.4f}) }},")
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
for o in out:
    o.select_set(True)
bpy.context.view_layer.objects.active = out[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "VegDedupe.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="OFF", use_custom_props=False, path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx ok", [o.name for o in out])
