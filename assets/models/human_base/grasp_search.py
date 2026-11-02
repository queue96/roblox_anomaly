# grasp_search.py - find a hand pose that really holds an object (run headless, see HUMAN_ANIMATION_GUIDE.md section 4)
#
# Order the owner asked for: open hand -> lay the object (a cylinder of its real radius) across the palm, pushed in from
# outside until it touches the palm -> each finger's three joints curl together (1 : 1.1 : 0.8); a segment that touches
# freezes its joint and the joints before it, the tip keeps curling -> the thumb is laid along the object, resting on it.
# Writes <out>.json-ish text: per side {angles (left-side convention degrees, ready for build_anims GRIPS),
# center (object centre in studs in the hand frame used by shared/HeadTurn.grip), palm_sign, r} and renders
# grasp_<side>_<0..2>.png next to <out> (0 = down the object axis, 1 = palm side, 2 = back of the hand).
#
# Usage:  powershell -ExecutionPolicy Bypass -File tools/blender/run_headless.ps1 -Script assets/models/human_base/grasp_search.py -Out <temp>/grasp.txt
# Edit OBJECTS below: (side, radius in studs). Flashlight barrel 0.155 (left hand), umbrella handle 0.088 (right hand).
# Then copy "angles" into GRIPS in build_anims.py and "center" into GRIP_CENTER in src/shared/HeadTurn.luau
# (or measure the grip point in Studio for NPC props, e.g. Pedestrian HUMAN_RIGHT_HAND).
import bpy, sys, os, json, math
import numpy as np
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1:][0]
HB = r"C:\Aunival\pump-lot-anomaly\assets\models\human_base"
A = {"__name__": "grasp"}
exec(open(os.path.join(HB, "build_anims.py"), encoding="utf-8").read(), A)
bpy.ops.wm.open_mainfile(filepath=os.path.join(HB, "human_base.blend"))
rig = bpy.data.objects["HumanRig"]
if rig.animation_data: rig.animation_data.action = None
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Body") and any(m.type == "ARMATURE" for m in o.modifiers))
pb = rig.pose.bones; mw = rig.matrix_world
SPM = A["STUDS_PER_M"]
FING = ["index", "middle", "ring", "pinky"]
for p in pb: p.rotation_mode = 'XYZ'

gnames = {g.index: g.name for g in body.vertex_groups}
W = {}   # bone name -> vertex index array (weight > 0.3)
for v in body.data.vertices:
    for g in v.groups:
        n = gnames.get(g.group)
        if n and g.weight > 0.3:
            W.setdefault(n, []).append(v.index)
W = {k: np.array(v) for k, v in W.items()}

def verts(idx):
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg); me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3); me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3)[idx]
    M4 = np.array(ev.matrix_world)
    return co @ M4[:3, :3].T + M4[:3, 3]

def reset():
    for p in pb: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.context.view_layer.update()

def P(n): return np.array(mw @ pb[n].head)

def frame(sd):
    s = "." + sd
    O = P("hand" + s)
    X = P("index_01" + s) - P("pinky_01" + s); X /= np.linalg.norm(X)
    Y = P("middle_01" + s) - O; Y -= X * Y.dot(X); Y /= np.linalg.norm(Y)
    Z = np.cross(X, Y)
    return O, X, Y, Z

def dist_axis(pts, c, ax):
    d = pts - c
    d = d - np.outer(d @ ax, ax)
    return np.linalg.norm(d, axis=1)

PO = A["Poser"](rig)
def setrot(n, e):
    # e: radians in the left-side convention (as hand() writes them): Poser mirrors .R and clamps to the joint limits
    PO.frame = {}
    PO.rot(n, *(math.degrees(x) for x in e))
    kind, v = PO.frame[n]
    pb[n].rotation_euler = v
    PO.frame = {}
    bpy.context.view_layer.update()

def render(sd, c, ax, r, path):
    import mathutils
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=0.3, location=Vector(c.tolist()))
    cyl = bpy.context.active_object
    cyl.rotation_mode = 'QUATERNION'
    cyl.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(ax.tolist()))
    mat = bpy.data.materials.new("cylmat"); mat.diffuse_color = (0.75, 0.2, 0.15, 1); cyl.data.materials.append(mat)
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in (body, cyl) and not o.hide_render: o.hide_render = True
    cam_data = bpy.data.cameras.new("gc"); cam = bpy.data.objects.new("gc", cam_data); sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x = 480; sc.render.resolution_y = 480
    O, X_, Y_, Z_ = frame(sd)
    tgt = Vector(c.tolist())
    # 0: down the object axis (fingers wrapping round it), 1: from the palm side, 2: from the back of the hand
    Nn = Z_ * palm_g[0]
    views = [Vector((X_ * 1.0 + Y_ * 0.05).tolist()), Vector((Nn * 1.0 + X_ * 0.25).tolist()), Vector((-Nn * 1.0 + X_ * 0.25).tolist())]
    for i, v in enumerate(views):
        cam.location = tgt + v.normalized() * 0.42
        cam.rotation_mode = 'QUATERNION'
        cam.rotation_quaternion = (tgt - cam.location).to_track_quat('-Z', 'Y')
        cam_data.lens = 50
        sc.render.filepath = path.replace(".png", f"_{i}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cyl); bpy.data.objects.remove(cam)

palm_g = [1.0]
result = {}
OBJECTS = (("L", 0.155), ("R", 0.088))   # (hand, object radius in studs)
for sd, r_studs in OBJECTS:
    s = "." + sd
    r = r_studs / SPM
    reset()
    O, X, Y, Z = frame(sd)
    # which way is the palm: curling a finger moves its tip toward the palm
    tip0 = np.array(mw @ pb["middle_03" + s].tail)
    setrot("middle_01" + s, (math.radians(-30), 0, 0))
    tip1 = np.array(mw @ pb["middle_03" + s].tail)
    reset()
    palm = 1.0 if (tip1 - tip0).dot(Z) > 0 else -1.0
    N = Z * palm
    # object laid across the palm: axis = X, at 60% of the way wrist -> knuckles, brought in from outside until it touches
    L = np.linalg.norm(P("middle_01" + s) - O)
    handv = verts(W["hand" + s])
    base = O + Y * (0.62 * L)
    c = None
    for k in range(200, -1, -1):
        cc = base + N * (k * 0.0005)
        if dist_axis(handv, cc, X).min() < r:
            c = base + N * ((k + 1) * 0.0005); break
    if c is None: c = base
    # fingers: all three joints curl together (1 : 1.1 : 0.8); a segment that touches the object freezes its joint and
    # the joints before it, the rest keep curling (the tip wraps round) - stop at the last step with nothing inside
    angles = {}
    RATIO = (1.0, 1.1, 0.8)
    for f in FING:
        names = [f"{f}_{j}{s}" for j in ("01", "02", "03")]
        seg = [W.get(n, np.array([], int)) for n in names]
        cur = [0.0, 0.0, 0.0]; frozen = [False, False, False]
        for step in range(60):
            if all(frozen): break
            trial = [cur[i] if frozen[i] else cur[i] - 2.0 * RATIO[i] for i in range(3)]
            if trial[0] < -95 or trial[1] < -105 or trial[2] < -80:
                break
            for i, n in enumerate(names): setrot(n, (math.radians(trial[i]), 0, 0))
            hit = [len(seg[i]) > 0 and dist_axis(verts(seg[i]), c, X).min() < r * 0.98 for i in range(3)]
            if any(hit):
                k = max(i for i in range(3) if hit[i])
                for i in range(k + 1): frozen[i] = True
                # the segment went in: keep the previous angle for the frozen joints, take the step for the free ones
                for i in range(3):
                    if not frozen[i]: cur[i] = trial[i]
            else:
                cur = trial
        for i, n in enumerate(names):
            setrot(n, (math.radians(cur[i]), 0, 0))
            angles[n] = [round(cur[i], 1), 0, 0]
    # thumb: swing thumb_01 round to the far side of the object, then curl 02/03 to contact
    tidx = np.concatenate([W.get(f"thumb_{j}{s}", np.array([], int)) for j in ("01", "02", "03")])
    # thumb lies along the object (pointing the index-finger way), resting on it: try thumb_01 swing x/z with the
    # outer joints a little bent, keep poses with nothing inside, pick the tip closest to the surface pointing along X
    best = None
    for ax_ in range(-60, 41, 10):
        for az in range(-80, 41, 10):
            for bend in (0, -15, -30):
                setrot("thumb_01" + s, (math.radians(ax_), 0, math.radians(az)))
                setrot("thumb_02" + s, (math.radians(bend), 0, 0)); setrot("thumb_03" + s, (math.radians(bend), 0, 0))
                if dist_axis(verts(tidx), c, X).min() < r * 0.98: continue
                tip = np.array(mw @ pb["thumb_03" + s].tail)
                root_ = np.array(mw @ pb["thumb_01" + s].head)
                dt = dist_axis(tip[None], c, X)[0]
                dvec = tip - root_; dvec /= np.linalg.norm(dvec)
                sc = abs(dt - r) / r + 0.6 * (1 - float(dvec.dot(X)))
                if best is None or sc < best[0]: best = (sc, ax_, az, bend)
    _, ax_, az, bend = best
    setrot("thumb_01" + s, (math.radians(ax_), 0, math.radians(az)))
    setrot("thumb_02" + s, (math.radians(bend), 0, 0)); setrot("thumb_03" + s, (math.radians(bend), 0, 0))
    angles["thumb_01" + s] = [ax_, 0, az]; angles["thumb_02" + s] = [bend, 0, 0]; angles["thumb_03" + s] = [bend, 0, 0]
    # object centre in the hand frame (studs) - recompute the frame with the fingers curled (knuckle bones don't move)
    O, X2, Y2, Z2 = frame(sd)
    rel = c - O
    result[sd] = {"angles": angles, "center": [round(float(rel.dot(X2)) * SPM, 4), round(float(rel.dot(Y2)) * SPM, 4), round(float(rel.dot(Z2)) * SPM, 4)],
                  "palm_sign": palm, "r": r_studs}
    palm_g[0] = palm
    render(sd, c, X, r, os.path.join(os.path.dirname(out), f"grasp_{sd}.png"))
    reset()
open(out, "w").write(json.dumps(result, indent=1))
open(out + ".done", "w").write("ok")
