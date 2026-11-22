# Tani v2 stands and waves slowly at the player, again and again (user 2026-11-22 "ตานีให้ยืนโบกมือเรื่อยๆ ได้ไหม")
# -> new clip "tani_wave" in src/shared/GhostClipData.luau (client/GhostAnimRunner plays it; no Roblox upload).
#
#   blender.exe --background --factory-startup --python tani_wave.py
#
# Body stays at rest (SceneryGhosts locks hips/spine/legs/neck/head with StillBones; the neck turns to the player with
# LookAtCamera). Left arm hangs at her side. Right arm up beside the head, forearm swinging side to side about the elbow,
# palm toward the player: 3 slow waves (0.45 s a swing) then the hand stays up, still, for ~2.4 s; 6 s loop.
# Posed by world directions on TaniV2_rigged.blend (Blender: she faces -Y, her left is +X), converted with the Studio rest
# frames of GhostModels.ghost_tani (tools/studio/tani_v2_rbx_rest.json) like clips_to_luau.py.

import bpy, os, math, json
from mathutils import Vector, Matrix, Quaternion

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
M = os.path.join(ROOT, "assets", "models")
# ตานีตัวที่ใช้ในเกม: v3 ตั้งแต่ 2026-11-22 (v2 = TaniV2 + tani_v2_rbx_rest.json)
VER, REST_NAME = "TaniV3", "tani_v3_rbx_rest.json"
BLEND = os.path.join(M, VER, VER + "_rigged.blend")
PREV = os.path.join(M, VER, "previews")
REST_RBX = os.path.join(ROOT, "tools", "studio", REST_NAME)
LUAU = os.path.join(ROOT, "src", "shared", "GhostClipData.luau")
CLIP = "tani_wave"
FPS = 30
STUDS_PER_M = 3.5


def log(*a):
    print("[wave]", *a, flush=True)


bpy.ops.wm.open_mainfile(filepath=BLEND)
rig = bpy.data.objects["HumanRig"]
pbs = rig.pose.bones
for pb in pbs:
    pb.rotation_mode = "QUATERNION"


def V(x, y, z):
    return Vector((x, y, z)).normalized()


def palm_axis(name):
    m3 = rig.data.bones[name].matrix_local.to_3x3()
    best = None
    for ax, v in (("X", m3.col[0]), ("-X", -m3.col[0]), ("Z", m3.col[2]), ("-Z", -m3.col[2])):
        d = v.dot(Vector((0, -1, 0)))
        if best is None or d > best[0]:
            best = (d, ax)
    log(f"palm axis {name}: {best[1]} (dot {best[0]:.2f})")
    return {"X": Vector((1, 0, 0)), "-X": Vector((-1, 0, 0)), "Z": Vector((0, 0, 1)), "-Z": Vector((0, 0, -1))}[best[1]]


PALM = {s: palm_axis(f"hand.{s}") for s in "LR"}


def reset():
    for pb in pbs:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()


def aim(name, direction, normal=None, local_normal=None):
    pb = pbs[name]
    m = pb.matrix.copy()
    r = m.to_3x3()
    r = r.col[1].normalized().rotation_difference(direction.normalized()).to_matrix() @ r
    if normal is not None and local_normal is not None:
        yy = r.col[1].normalized()
        cur = r @ local_normal
        cur = (cur - yy * cur.dot(yy)).normalized()
        want = (normal - yy * normal.dot(yy)).normalized()
        tw = math.atan2(cur.cross(want).dot(yy), cur.dot(want))
        log(f"  twist {name}: {math.degrees(tw):.0f} deg")
        r = Quaternion(yy, tw).to_matrix() @ r
    pb.matrix = Matrix.Translation(m.to_translation()) @ r.to_4x4()
    bpy.context.view_layer.update()


FWD = Vector((0, -1, 0))


def pose(swing_deg):
    """swing_deg: forearm angle away from straight up, + = toward her right/outward"""
    reset()
    # left arm hangs at her side, palm in
    aim("upper_arm.L", V(0.12, 0.02, -1.0))
    aim("forearm.L", V(0.06, -0.06, -1.0))
    # (ผู้ใช้ 2026-11-22 "แขนมันบิด": บังคับทิศฝ่ามือทำให้ข้อมือบิด 120° -> ไม่บิดมือแล้ว ให้หันตามแขนเอง)
    aim("hand.L", V(0.04, -0.04, -1.0))
    # right arm (her right = -X): upper arm out to the side, a little forward and up, elbow at shoulder height
    aim("upper_arm.R", V(-0.85, -0.30, 0.25))
    up = V(-0.10, -0.20, 0.97)
    fore = Quaternion(FWD, math.radians(swing_deg)) @ up
    aim("forearm.R", fore)
    hand = Quaternion(FWD, math.radians(swing_deg * 1.35)) @ V(-0.05, -0.12, 0.99)   # the hand flops a bit further
    aim("hand.R", hand)


act = bpy.data.actions.get(CLIP)
if act:
    bpy.data.actions.remove(act)
if not rig.animation_data:
    rig.animation_data_create()
act = bpy.data.actions.new(CLIP)
rig.animation_data.action = act
SWING, AMP = 13, 26            # frames per swing (0.43 s), degrees each way
keys = [(1, 0)]
f = 1 + SWING // 2
for i in range(6):             # 3 waves = 6 swings
    keys.append((f, AMP if i % 2 == 0 else -AMP))
    f += SWING
keys.append((f - SWING // 2, 0))
END = 181                      # 6 s loop: the hand rests up and still until the next waves
keys.append((END, 0))
for frame, ang in keys:
    pose(ang)
    for pb in pbs:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, END
log("keys", keys, "length", (END - 1) / FPS, "s")

# previews
scn = bpy.context.scene
scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x, scn.render.resolution_y = 500, 640
for o in list(scn.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
w = bpy.data.worlds.new("w"); scn.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.33, 0.33, 0.36, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.5
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"; cd.ortho_scale = 2.2
cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
os.makedirs(PREV, exist_ok=True)
for fr, tag in ((keys[1][0], "out"), (keys[2][0], "in")):
    scn.frame_set(fr)
    a = math.radians(12)
    cam.location = Vector((0, 0, 0.95)) + Vector((math.sin(a), -math.cos(a), 0.05)) * 10
    cam.rotation_euler = (math.radians(87), 0, a)
    scn.render.filepath = os.path.join(PREV, f"tani_wave_{tag}.png")
    bpy.ops.render.render(write_still=True)

# export -> GhostClipData.luau
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


frames = list(range(1, END + 1, 1))
tracks = {}
for fr in frames:
    scn.frame_set(fr)
    for pb in pbs:
        mb = pb.matrix_basis
        q = mb.to_quaternion()
        t = mb.to_translation() * STUDS_PER_M
        tracks.setdefault(pb.name, []).append([q.x, q.y, q.z, q.w, t.x, t.y, t.z])
lines = [f'\t["{CLIP}"] = {{ length = {(END - 1) / FPS:.4f}, once = false,',
         "\t\t-- Tani v2 slow wave at the player: tools/blender/tani_wave.py (2026-11-22)",
         "\t\ttimes = { " + ", ".join(f"{(fr - 1) / FPS:g}" for fr in frames) + " },",
         "\t\ttracks = {"]
nb = 0
for bone, ks in tracks.items():
    if bone not in R:
        continue
    if not (any(abs(a - b) > 1e-4 for k in ks for a, b in zip(k, ks[0])) or any(abs(v) > 1e-4 for v in ks[0][:3] + ks[0][4:])):
        continue
    cks = [convert(k, rest_all[bone], R[bone]) for k in ks]
    if all(c == cks[0] for c in cks):
        cks = cks[:1]
    lines.append(f'\t\t\t["{bone}"] = {{ ' + ", ".join("{" + ", ".join(f"{v:g}" for v in c) + "}" for c in cks) + " },")
    nb += 1
lines += ["\t\t},", "\t},"]

src = open(LUAU, encoding="utf-8").read().split("\n")
idx = [i for i, l in enumerate(src) if l.startswith(f'\t["{CLIP}"] = {{')]
if idx:
    start = idx[0]
    end = start + 1
    while src[end] != "\t},":
        end += 1
    src[start:end + 1] = lines
else:
    last = max(i for i, l in enumerate(src) if l.strip() == "}")
    src[last:last] = lines
open(LUAU, "w", encoding="utf-8", newline="\n").write("\n".join(src))
log(f"wrote {CLIP}: {len(frames)} keys, {nb} bones")
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(M, VER, VER + "_wave.blend"), compress=True)
log("done")
