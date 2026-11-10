# Villager v2 rig check: (1) bones equal to the old rig, (2) the existing clips (mocap + old) played on the new
# body vs the old body, counted with the old self-intersection checker, (3) pose renders.
#   blender -b --factory-startup --python rig_check.py -- <out_dir> [female]     (save the .blend with build_rig.py --save)
# Opens assets/models/mocap/out/<old>_mocap.blend (old body + rig + every clip), never saves over it.
import bpy, os, sys, math, io, contextlib, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)); MODELS = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0]; os.makedirs(OUT, exist_ok=True)
CHAR = "female" if "female" in argv[1:] else "male"
OLD = {"male": "human_base", "female": "human_female"}[CHAR]
CLIPS = ["idle", "idle_look", "walk", "ride_moto", "drive_car", "drive_tuktuk", "talk", "wave", "shrug", "nod_yes",
         "pull_start", "pull_rope", "pray", "carry_gallon", "fuel_pump", "pump_air", "hold_umbrella", "sit", "walk_skirt"]
POSES = [("walk", 0.30), ("ride_moto", 0.30), ("drive_car", 0.30), ("pull_start", 0.50), ("pray", 0.50), ("wave", 0.35)]
COL = [(0.93, 0.66, 0.48), (0.33, 0.50, 0.80), (0.38, 0.66, 0.42)]
BG = (0.42, 0.43, 0.45)
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

def fcurves(act):
    if hasattr(act, "fcurves"): return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []): out.extend(cb.fcurves)
    return out

def set_action(rig, act, frame):
    quat = any(fc.data_path.endswith("rotation_quaternion") for fc in fcurves(act))
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION" if quat else "XYZ"
        pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    if not rig.animation_data: rig.animation_data_create()
    rig.animation_data.action = act
    if hasattr(rig.animation_data, "action_slot") and getattr(act, "slots", None):
        try: rig.animation_data.action_slot = act.slots[0]
        except Exception: pass
    bpy.context.scene.frame_set(frame); bpy.context.view_layer.update()

def mute(rig):
    for pb in rig.pose.bones:          # Roblox has no joint limits: check what the game will show
        for c in pb.constraints: c.mute = True

def checker():
    src = open(os.path.join(MODELS, "human_base", "test_self_intersection.py"), encoding="utf-8").read().split("POSES = {")[0]
    ns = {"__name__": "chk"}
    with contextlib.redirect_stdout(io.StringIO()): exec(src, ns)
    return ns["check"]

def run_clips(rig, tag):
    check = checker(); res = {}
    for name in CLIPS:
        act = bpy.data.actions.get(name)
        if not act: continue
        f0, f1 = (int(x) for x in act.frame_range)
        bad, worst = 0, []
        for f in range(f0, f1 + 1, 2):
            set_action(rig, act, f)
            with contextlib.redirect_stdout(io.StringIO()): h = check(name)
            if h: bad += 1; worst.extend(h)
        deep = max((float(w.split(":")[1][:-2]) for w in worst), default=0.0)
        res[name] = (bad, len(range(f0, f1 + 1, 2)), sorted(set(w.split(":")[0] for w in worst)), deep)
    L(f"[{tag}] clip: frames with body parts passing through each other (> 1.5 cm) / frames checked")
    for n, (b, t, w, dp) in res.items(): L(f"   {n:14s} {b:3d}/{t:3d}  " + (f"deepest {dp:.1f} cm  " if b else "") + " ".join(w))
    return res

def bone_table(arm):
    return {b.name: (b.head_local.copy(), b.tail_local.copy(), b.matrix_local.copy()) for b in arm.bones}

def flat(name, rgb):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); return m

def render(cam, tgt, d, ortho, res=(300, 420)):
    sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = res
    d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
    p = os.path.join(OUT, "_t.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr

def bbox(ob):
    dg = bpy.context.evaluated_depsgraph_get(); e = ob.evaluated_get(dg); me = e.to_mesh()
    ps = [e.matrix_world @ v.co for v in me.vertices]; e.to_mesh_clear()
    lo = Vector([min(p[i] for p in ps) for i in range(3)]); hi = Vector([max(p[i] for p in ps) for i in range(3)])
    return lo, hi

try:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODELS, "mocap", "out", OLD + "_mocap.blend"))
    old_rig = bpy.data.objects["HumanRig"]; mute(old_rig)
    old_bones = bone_table(old_rig.data)
    for o in bpy.data.objects:                      # check the old body alone (no clothes / hair)
        if o.type == 'MESH' and o.name != "Body": o.hide_set(True)
    old_res = run_clips(old_rig, f"old {OLD}")
    for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
    ns = {"__name__": "villager", "CHAR": CHAR, "__file__": os.path.join(HERE, "build_rig.py")}
    sys.argv = [sys.argv[0], "--", CHAR]          # never --save here: this scene carries the whole mocap file
    with contextlib.redirect_stdout(io.StringIO()):
        exec(compile(open(ns["__file__"], encoding="utf-8").read(), ns["__file__"], "exec"), ns)
    L(str(ns["RIG_REPORT"]))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]; mute(rig)
    new_bones = bone_table(rig.data)
    dpos = max(max((a[0] - b[0]).length, (a[1] - b[1]).length) for a, b in ((new_bones[k], old_bones[k]) for k in old_bones))
    drot = max(max(abs(x - y) for r1, r2 in zip(new_bones[k][2], old_bones[k][2]) for x, y in zip(r1, r2)) for k in old_bones)
    L(f"bones: {len(new_bones)} new / {len(old_bones)} old, same names: {set(new_bones) == set(old_bones)}, "
      f"max head/tail difference {dpos*1000:.2f} mm, max rest matrix difference {drot:.5f}")
    new_res = run_clips(rig, f"new villager {CHAR}")
    # ---- pose renders: 3/4 front row + side row
    me = body.data; me.materials.clear()
    for c in COL: me.materials.append(flat("P", c))
    part = me.attributes["part"].data
    for p in me.polygons: p.material_index = part[p.index].value
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_shadows = False
    w = bpy.data.worlds.new("W"); sc.world = w; w.color = BG
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    rows = []
    for d in ((0.7, -0.7, 0.12), (1.0, 0.0, 0.05)):
        tiles = []
        for name, frac in POSES:
            act = bpy.data.actions[name]; f0, f1 = act.frame_range
            set_action(rig, act, int(f0 + frac*(f1 - f0)))
            lo, hi = bbox(body); c = (lo + hi)*0.5
            tiles.append(render(cam, c, d, max(hi.z - lo.z, hi.x - lo.x, hi.y - lo.y)*1.1))
        rows.append(np.concatenate(tiles, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.join(OUT, f"rig_{CHAR}_poses.png"); img.file_format = 'PNG'; img.save()
    L("ok")
except Exception:
    L(traceback.format_exc())
open(os.path.join(OUT, f"rig_{CHAR}_report.txt"), "w", encoding="utf-8").write("\n".join(log))
