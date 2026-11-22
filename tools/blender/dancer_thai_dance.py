# Thai classical dance loop for the ghost dancer v2 (Hy3D DancerV2 on the old HumanRig) -> replaces "dancer_dance" in
# src/shared/GhostClipData.luau (client/GhostAnimRunner plays it; no Roblox animation upload).
#
#   blender.exe --background --factory-startup --python dancer_thai_dance.py [-- preview]
#
# Old dancer_dance = Mixamo Bellydancing hips + scripted arms: reads as swaying, not Thai dance (user 2026-11-22).
# This one is posed from Thai dance basics, slow and sustained, 18 s loop:
#   A  ตั้งวงบน left  + จีบส่งหลัง right, head tilts away from the high arm, weight on the right leg
#   C  ตั้งวงหน้า both arms (curved, hands up, palms out) at chest height, deeper ย่อ
#   B  mirror of A
#   D  จีบหน้า both hands at the waist, body rises a little, head bows
#   each pose is held ~1.3 s (still, ghostly) then flows to the next over ~3.2 s
# Knees stay bent (ย่อ) the whole time; the legs are inside the skirt, so only small knee/hip moves.
# Fingers are not rigged on v2 (the hand moves as one piece): wrists carry the ตั้งวง (bent back) / จีบ (palm up) shapes.
#
# Poses are set by world directions (Blender: the dancer faces -Y, her left is +X, up +Z) and converted with the Studio
# rest frames of GhostModels.ghost_dancer (tools/studio/dancer_v2_rbx_rest.json) the same way as clips_to_luau.py.

import bpy, os, sys, math, json
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
M = os.path.join(ROOT, "assets", "models")
BLEND = os.path.join(M, "DancerV2", "DancerV2_rigged.blend")
PREV = os.path.join(M, "DancerV2", "previews")
REST_RBX = os.path.join(ROOT, "tools", "studio", "dancer_v2_rbx_rest.json")
LUAU = os.path.join(ROOT, "src", "shared", "GhostClipData.luau")
CLIP = "dancer_dance"
FPS = 30
STUDS_PER_M = 3.5
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def log(*a):
    print("[dance]", *a, flush=True)


bpy.ops.wm.open_mainfile(filepath=BLEND)
rig = bpy.data.objects["HumanRig"]
body = bpy.data.objects["Body"]
pbs = rig.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"


def V(x, y, z):
    return Vector((x, y, z)).normalized()


def mirror(v: Vector) -> Vector:
    return Vector((-v.x, v.y, v.z))


# palm normal of each hand in its bone's local frame: the local X/Z axis that faces forward (-Y) in the rest A-pose
def palm_axis(name):
    m3 = rig.data.bones[name].matrix_local.to_3x3()
    best = None
    for ax, v in (("X", m3.col[0]), ("-X", -m3.col[0]), ("Z", m3.col[2]), ("-Z", -m3.col[2])):
        d = v.dot(Vector((0, -1, 0)))
        if best is None or d > best[0]:
            best = (d, ax)
    vec = {"X": Vector((1, 0, 0)), "-X": Vector((-1, 0, 0)), "Z": Vector((0, 0, 1)), "-Z": Vector((0, 0, -1))}[best[1]]
    log(f"palm axis {name}: {best[1]} (dot {best[0]:.2f})")
    return vec


PALM = {s: palm_axis(f"hand.{s}") for s in "LR"}


def reset():
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def aim(name, direction: Vector, normal: Vector | None = None, local_normal: Vector | None = None):
    """turn pose bone so its Y axis points along direction (armature space); optionally twist so local_normal faces normal"""
    pb = pbs[name]
    m = pb.matrix.copy()
    r = m.to_3x3()
    y = r.col[1].normalized()
    r = y.rotation_difference(direction.normalized()).to_matrix() @ r
    if normal is not None and local_normal is not None:
        yy = r.col[1].normalized()
        cur = (r @ local_normal)
        cur = (cur - yy * cur.dot(yy)).normalized()
        want = (normal - yy * normal.dot(yy)).normalized()
        ang = math.atan2(cur.cross(want).dot(yy), cur.dot(want))
        r = Quaternion(yy, ang).to_matrix() @ r
    pb.matrix = Matrix.Translation(m.to_translation()) @ r.to_4x4()
    bpy.context.view_layer.update()


def turn(name, axis: Vector, deg: float):
    """rotate a pose bone in armature space about axis (through its head)"""
    pb = pbs[name]
    m = pb.matrix.copy()
    r = Quaternion(axis.normalized(), math.radians(deg)).to_matrix() @ m.to_3x3()
    pb.matrix = Matrix.Translation(m.to_translation()) @ r.to_4x4()
    bpy.context.view_layer.update()


FWD, UP, LEFT = Vector((0, -1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))

# arm shapes, left side (right = mirrored); palm normal given as a world direction
ARM = {
    # ตั้งวงบน: arm up at the side in a curve, hand above head height, wrist bent back, fingers up, palm out
    "wong_bon": dict(up=V(0.70, -0.10, 0.70), fore=V(0.05, -0.15, 0.99), hand=V(0.20, 0.10, 0.97), palm=V(0.95, -0.10, -0.20)),
    # ตั้งวงหน้า: elbow low at the side, forearm up and forward, wrist bent back hard (fingers up/back), palm forward
    "wong_na": dict(up=V(0.45, -0.35, -0.82), fore=V(-0.12, -0.50, 0.86), hand=V(0.05, 0.30, 0.95), palm=V(0.10, -0.95, 0.25)),
    # จีบส่งหลัง: arm down and back, palm up behind the hip
    "jeeb_lang": dict(up=V(0.30, 0.35, -0.89), fore=V(0.25, 0.65, -0.72), hand=V(0.10, 0.85, -0.52), palm=V(0.0, 0.3, 0.95)),
    # จีบหน้า: hand at the waist in front, palm up
    "jeeb_na": dict(up=V(0.28, -0.20, -0.94), fore=V(-0.30, -0.93, 0.10), hand=V(-0.35, -0.93, -0.05), palm=V(0.0, 0.0, 1.0)),
}


def pose_arm(side, shape):
    a = ARM[shape]
    f = (lambda v: v) if side == "L" else mirror
    aim(f"upper_arm.{side}", f(a["up"]))
    aim(f"forearm.{side}", f(a["fore"]))
    aim(f"hand.{side}", f(a["hand"]), f(a["palm"]), PALM[side])


def pose_body(sink, shift, chest_roll, head_tilt, head_yaw, head_pitch):
    """sink = metres the hips drop (knees bend), shift = sideways weight (+ = toward her left)"""
    hips = pbs["hips"]
    hips.location = Vector((0, 0, 0))
    bpy.context.view_layer.update()
    # hips bone local Y points up: move in armature space via matrix
    m = hips.matrix.copy()
    hips.matrix = Matrix.Translation(Vector((shift, 0, -sink))) @ m
    bpy.context.view_layer.update()
    turn("hips", FWD, -shift * 60)               # pelvis tips with the weight shift
    turn("chest", FWD, chest_roll)
    # knees: bend so the feet stay near the floor (legs hidden in the skirt; keep it simple and symmetric-ish)
    bend = math.degrees(math.acos(max(-1.0, min(1.0, 1 - sink / 0.22)))) if sink > 0 else 0.0
    for s, sg in (("L", 1), ("R", -1)):
        extra = 0 if shift == 0 else 5 * (1 if sg * shift < 0 else -1)   # the leg taking the weight bends a little more
        b = max(0.0, bend + extra)
        # about +X a positive angle swings a downward bone backward (+Y): knees forward = negative on the thigh
        turn(f"thigh.{s}", LEFT, -b)
        turn(f"shin.{s}", LEFT, 2 * b)
        turn(f"foot.{s}", LEFT, -b)
    turn("neck", FWD, head_tilt * 0.4)
    turn("head", FWD, head_tilt * 0.6)
    turn("head", UP, head_yaw)
    turn("head", LEFT, head_pitch)


POSES = {
    #      left arm     right arm    sink  shift  chestRoll headTilt headYaw headPitch
    "A": ("wong_bon", "jeeb_lang", 0.06, -0.03, 5, -14, -10, -4),
    "C": ("wong_na", "wong_na", 0.09, 0.0, 0, 0, 0, 6),
    "B": ("jeeb_lang", "wong_bon", 0.06, 0.03, -5, 14, 10, -4),
    "D": ("jeeb_na", "jeeb_na", 0.04, 0.0, 0, 0, 0, -12),
}


def set_pose(key):
    l, r, sink, shift, croll, tilt, yaw, pitch = POSES[key]
    reset()
    pose_body(sink, shift, croll, tilt, yaw, pitch)
    pose_arm("L", l)
    pose_arm("R", r)


act = bpy.data.actions.get(CLIP)
if act:
    bpy.data.actions.remove(act)
if not rig.animation_data:
    rig.animation_data_create()
act = bpy.data.actions.new(CLIP)
rig.animation_data.action = act
HOLD, MOVE = 40, 95                                 # frames: still in the pose, then flow to the next
ORDER = ["A", "C", "B", "D"]
keys = []
f = 1
for k in ORDER:
    keys += [(f, k), (f + HOLD, k)]
    f += HOLD + MOVE
keys.append((f, ORDER[0]))                           # loop end = first pose again
END = f
for frame, k in keys:
    set_pose(k)
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
# smooth, sustained motion: new keys are Bezier + auto-clamped handles (holds stay flat) by default
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, END
log("keys", [(fr, k) for fr, k in keys], "length", (END - 1) / FPS, "s")

# ---------------------------------------------------------------- previews of each pose (and a mid-flow frame)
if True:
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 520, 700
    for o in list(scn.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o)
    w = bpy.data.worlds.new("w"); scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.33, 0.33, 0.36, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.5
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = 2.4
    cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
    ctr = Vector((0, 0, 1.0))
    os.makedirs(PREV, exist_ok=True)
    shots = [(keys[2 * i][0], k) for i, k in enumerate(ORDER)] + [(keys[1][0] + MOVE // 2, "AtoC")]
    for fr, k in shots:
        scn.frame_set(fr)
        for vname, ang in (("front", 15), ("side", 75)):
            a = math.radians(ang)
            cam.location = ctr + Vector((math.sin(a), -math.cos(a), 0.08)) * 10
            cam.rotation_euler = (math.radians(90 - 4.6), 0, a)
            scn.render.filepath = os.path.join(PREV, f"thai_dance_{k}_{vname}.png")
            bpy.ops.render.render(write_still=True)
    log("previews written")

# ---------------------------------------------------------------- export -> GhostClipData.luau
cl_ns = {"__file__": os.path.join(HERE, "clips_to_luau.py"), "__name__": "cl"}
exec(compile(open(os.path.join(HERE, "clips_to_luau.py"), encoding="utf-8").read(), "clips_to_luau.py", "exec"), cl_ns)
mm, mT, mv, sub, frame_of, qmat, mquat = (cl_ns[n] for n in ("mm", "mT", "mv", "sub", "frame", "qmat", "mquat"))

rest_all = {}
for bn in rig.data.bones:
    q = bn.matrix_local.to_quaternion()
    h = bn.head_local
    rest_all[bn.name] = [q.x, q.y, q.z, q.w, h.x, h.y, h.z]
rbx = json.load(open(REST_RBX))
R = {n: [v[3:6], v[6:9], v[9:12]] for n, v in rbx.items()}
P = {n: v[0:3] for n, v in rbx.items()}
bp = {n: v[4:7] for n, v in rest_all.items()}
C = mm(frame_of(sub(P["head"], P["hips"]), sub(P["thigh.L"], P["thigh.R"])),
       mT(frame_of(sub(bp["head"], bp["hips"]), sub(bp["thigh.L"], bp["thigh.R"]))))


def convert(key, rq, Rr):
    B = qmat(*rq[:4])
    rot = mm(mm(mm(mT(Rr), C), mm(mm(B, qmat(*key[:4])), mT(B))), mm(mT(C), Rr))
    t = mv(mT(Rr), mv(mm(C, B), key[4:7]))
    return [round(float(v), 3) for v in t] + [round(float(v), 4) for v in mquat(rot)]


scn = bpy.context.scene
frames = list(range(1, END + 1, 2))
if frames[-1] != END:
    frames.append(END)
tracks = {}
for fr in frames:
    scn.frame_set(fr)
    for pb in pbs:
        mb = pb.matrix_basis
        q = mb.to_quaternion()
        t = mb.to_translation() * STUDS_PER_M
        tracks.setdefault(pb.name, []).append([q.x, q.y, q.z, q.w, t.x, t.y, t.z])
lines = [f'\t["{CLIP}"] = {{ length = {(END - 1) / FPS:.4f}, once = false,',
         "\t\t-- Thai classical dance loop for ghost dancer v2: tools/blender/dancer_thai_dance.py (2026-11-22)",
         "\t\ttimes = { " + ", ".join(f"{(fr - 1) / FPS:g}" for fr in frames) + " },",
         "\t\ttracks = {"]
nb = 0
for bone, ks in tracks.items():
    if bone not in R:
        continue
    moving = any(abs(a - b) > 1e-4 for k in ks for a, b in zip(k, ks[0])) or any(abs(v) > 1e-4 for v in ks[0][:3] + ks[0][4:])
    if not moving:
        continue
    cks = [convert([k[0], k[1], k[2], k[3], k[4], k[5], k[6]], rest_all[bone], R[bone]) for k in ks]
    if all(c == cks[0] for c in cks):
        cks = cks[:1]
    lines.append(f'\t\t\t["{bone}"] = {{ ' + ", ".join("{" + ", ".join(f"{v:g}" for v in c) + "}" for c in cks) + " },")
    nb += 1
lines += ["\t\t},", "\t},"]

src = open(LUAU, encoding="utf-8").read().split("\n")
start = next(i for i, l in enumerate(src) if l.startswith(f'\t["{CLIP}"] = {{'))
end = start + 1
while not src[end] == "\t},":
    end += 1
src[start:end + 1] = lines
open(LUAU, "w", encoding="utf-8", newline="\n").write("\n".join(src))
log(f"wrote {CLIP}: {len(frames)} keys, {nb} bones -> {LUAU}")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(M, "DancerV2", "DancerV2_dance.blend"), compress=True)
log("done")
