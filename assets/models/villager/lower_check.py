# Renders the lower-body variants in the game's poses (Workbench, parts in colour).
#   blender -b --factory-startup --python lower_check.py -- <out_dir> [male|female]
# Rows: Body's own lower (short / bare legs) · Lower_wide · Lower_skirt (walk = walk_skirt, what the game plays for skirts)
# Columns: walk, ride_moto (3/4 and front), drive_car, sit, pull_start (bending)
import bpy, os, sys, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)); MODELS = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0]; os.makedirs(OUT, exist_ok=True)
CHAR = "female" if "female" in argv[1:] else "male"
OLD = {"male": "human_base", "female": "human_female"}[CHAR]
COL = [(0.93, 0.66, 0.48), (0.33, 0.50, 0.80), (0.38, 0.66, 0.42)]
SHOTS = [("walk", 0.3, (0.7, -0.7, 0.10)), ("ride_moto", 0.3, (0.7, -0.7, 0.10)), ("ride_moto", 0.3, (0.0, -1.0, 0.25)),
         ("drive_car", 0.3, (0.75, -0.65, 0.10)), ("sit", 0.5, (0.9, -0.4, 0.10)), ("pull_start", 0.5, (1.0, -0.15, 0.06))]
log = []

def fcurves(act):
    if hasattr(act, "fcurves"): return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []): out.extend(cb.fcurves)
    return out

def set_action(rig, act, frac):
    quat = any(fc.data_path.endswith("rotation_quaternion") for fc in fcurves(act))
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION" if quat else "XYZ"
        pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
        for c in pb.constraints: c.mute = True
    if not rig.animation_data: rig.animation_data_create()
    rig.animation_data.action = act
    try: rig.animation_data.action_slot = act.slots[0]
    except Exception: pass
    f0, f1 = act.frame_range
    bpy.context.scene.frame_set(int(f0 + frac*(f1 - f0))); bpy.context.view_layer.update()

def flat(name, rgb):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); return m

def bbox(objs):
    dg = bpy.context.evaluated_depsgraph_get(); ps = []
    for o in objs:
        e = o.evaluated_get(dg); me = e.to_mesh(); ps += [e.matrix_world @ v.co for v in me.vertices]; e.to_mesh_clear()
    lo = Vector([min(p[i] for p in ps) for i in range(3)]); hi = Vector([max(p[i] for p in ps) for i in range(3)])
    return lo, hi

def render(cam, tgt, d, ortho, res=(300, 420)):
    sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = res
    d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
    p = os.path.join(OUT, f"_t_{CHAR}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr

try:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
    ns = {"__name__": "lower", "__file__": os.path.join(HERE, "build_lower.py")}
    sys.argv = [sys.argv[0], "--", CHAR]
    exec(compile(open(ns["__file__"], encoding="utf-8").read(), ns["__file__"], "exec"), ns)
    log.append(ns["LOWER_REPORT"])
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    wide = bpy.data.objects["Lower_wide"]; skirt = bpy.data.objects["Lower_skirt"]
    for o in bpy.data.objects:
        if o.type == 'MESH' and o not in (body, wide, skirt): o.hide_render = True
    # body without its lower part, for the variant rows
    top = body.copy(); top.data = body.data.copy(); bpy.context.scene.collection.objects.link(top)
    import bmesh
    bm = bmesh.new(); bm.from_mesh(top.data); lay = bm.faces.layers.int.get("part")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[lay] == 2], context='FACES'); bm.to_mesh(top.data); bm.free()
    for ob in (body, top):
        ob.data.materials.clear()
        for c in COL: ob.data.materials.append(flat("P", c))
        pa = ob.data.attributes["part"].data
        for p in ob.data.polygons: p.material_index = pa[p.index].value
    for ob in (wide, skirt):
        ob.data.materials.clear(); ob.data.materials.append(flat("L", COL[2]))
    with bpy.data.libraries.load(os.path.join(MODELS, "mocap", "out", OLD + "_mocap.blend")) as (src, dst):
        dst.actions = sorted({s[0] for s in SHOTS} | {"walk_skirt"})
    acts = {a.name: a for a in dst.actions if a}
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_shadows = False
    w = bpy.data.worlds.new("W"); sc.world = w; w.color = (0.42, 0.43, 0.45)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    rows = []
    for label, shown in (("shorts", (body,)), ("wide", (top, wide)), ("skirt", (top, skirt))):
        for o in (body, top, wide, skirt): o.hide_render = o not in shown
        tiles = []
        for name, frac, d in SHOTS:
            if label == "skirt" and name == "walk": name = "walk_skirt"
            set_action(rig, acts[name], frac)
            lo, hi = bbox(shown); c = (lo + hi)*0.5
            tiles.append(render(cam, c, d, max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y)*1.1))
        rows.append(np.concatenate(tiles, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.join(OUT, f"lower_{CHAR}.png"); img.file_format = 'PNG'; img.save()
    log.append("ok")
except Exception:
    import traceback; log.append(traceback.format_exc())
open(os.path.join(OUT, f"lower_{CHAR}_report.txt"), "w", encoding="utf-8").write("\n".join(log))
