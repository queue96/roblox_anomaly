# Animation clips for HumanRig, made by script per character (so stride, speed and posture fit each body),
# plus the Roblox export (weights limited to 4 bones, FBX in studs).
#
#   exec(open(r"...\human_base\build_anims.py", encoding="utf-8").read())
#   add_anims("female")      # current scene: actions idle / walk / run / ghost_idle / ghost_glide on HumanRig
#   limit_weights()          # current scene: every mesh bound to HumanRig keeps its 4 strongest bones (Roblox limit)
#   anims_all()              # all 16 .blend files: limit weights + clips, saved
#   export_all()             # roblox/<character>/<file>.fbx (model) + <character>_<clip>.fbx (animation, armature only)
#   preview_all()            # anim_previews/<character>.png (rows = clips, columns = 6 moments; front + side)
#
# Bone axes (pose bone local, XYZ euler, see add_joint_limits.py). Values below are written for the LEFT side;
# for .R bones in MIRROR_Z the Z angle is flipped, so "z < 0" always means arm forward / elbow bent.
#   spine/chest/neck/head +X bend forward, Y twist, +Z lean right | upper_arm +X raise, -Z forward | forearm -Z bend
#   hand +X extend | fingers -X curl | thigh +X forward, +Z out | shin -X bend knee | foot / toe +X toes up
# Clips loop (last frame = first), stay in place (the Humanoid moves the character in Roblox) at 30 fps.
import bpy, math, os, glob
from mathutils import Vector

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
DIRS = {"human_base": "male", "human_female": "female", "human_child": "child",
        "human_elder_male": "elder_male", "human_elder_female": "elder_female"}
NAMES = {v: k for k, v in DIRS.items()}
FPS = 30
STUDS_PER_M = 3.5            # 1 m = 3.5 studs: the man is 6.3 studs tall (the old part NPCs are about 6.5)
MIRROR_Z = {"shoulder", "upper_arm", "forearm", "hand", "thigh", "foot",
            "thumb_01", "thumb_02", "thumb_03", "index_01", "index_02", "index_03", "middle_01", "middle_02", "middle_03",
            "ring_01", "ring_02", "ring_03", "pinky_01", "pinky_02", "pinky_03"}
FINGERS = [f"{f}_0{i}" for f in ("index", "middle", "ring", "pinky") for i in (1, 2, 3)]

# how each character moves: stride and arm swing (x adult man), cycle length (x), forward lean (deg), hip sway (x)
STYLE = {
    "male":         dict(stride=1.00, arm=1.00, slow=1.00, lean=0, sway=1.0, bounce=1.0),
    "female":       dict(stride=0.90, arm=0.80, slow=0.95, lean=0, sway=1.8, bounce=0.9),
    "child":        dict(stride=1.05, arm=1.20, slow=0.80, lean=0, sway=1.0, bounce=1.3),
    "elder_male":   dict(stride=0.65, arm=0.50, slow=1.35, lean=6, sway=1.2, bounce=0.6),
    "elder_female": dict(stride=0.60, arm=0.45, slow=1.40, lean=5, sway=1.5, bounce=0.5),
}

def blend_files(char=None):
    fs = sorted(glob.glob(os.path.join(M, "human_*", "human_*.blend")))
    return [f for f in fs if char is None or DIRS[os.path.basename(os.path.dirname(f))] == char]
def char_of(path): return DIRS[os.path.basename(os.path.dirname(path))]
def sm(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0); return t*t*(3 - 2*t)

# ---------------------------------------------------------------- weights: Roblox skins with at most 4 bones per vertex
def bound_meshes(rig):
    return [o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]

def limit_weights(n=4):
    rig = bpy.data.objects["HumanRig"]; out = {}
    for ob in bound_meshes(rig):
        names = {g.index: g for g in ob.vertex_groups}; cut = 0
        for v in ob.data.vertices:
            gs = sorted(((g.group, g.weight) for g in v.groups if g.weight > 0), key=lambda t: -t[1])
            if len(gs) <= n and abs(sum(w for _, w in gs) - 1) < 1e-4: continue
            keep = gs[:n]; tot = sum(w for _, w in keep) or 1.0
            for gi, _ in gs[n:]: names[gi].remove([v.index]); cut += 1
            for gi, w in keep: names[gi].add([v.index], w/tot, 'REPLACE')
        out[ob.name] = cut
    return out

# ---------------------------------------------------------------- posing helpers
class Poser:
    def __init__(self, rig):
        self.rig = rig; self.pb = rig.pose.bones
        self.lim = {}
        for p in self.pb:
            p.rotation_mode = 'XYZ'
            c = next((c for c in p.constraints if c.type == 'LIMIT_ROTATION'), None)
            if c: self.lim[p.name] = (c.min_x, c.max_x, c.min_y, c.max_y, c.min_z, c.max_z)
        # pose-space vector for "up" (world +Z) on the root and hips bones, to move the body up / down
        self.up = {n: self.rig.data.bones[n].matrix_local.to_3x3().inverted() @ Vector((0, 0, 1)) for n in ("root", "hips")}
        self.frame = {}

    def rot(self, name, x=0.0, y=0.0, z=0.0):
        """degrees, left-side convention; .R bones in MIRROR_Z get z flipped; clamped to the joint limits"""
        base, _, side = name.partition(".")
        if side == "R" and base in MIRROR_Z: z = -z
        v = [math.radians(a) for a in (x, y, z)]
        if name in self.lim:
            l = self.lim[name]; v = [min(max(v[i], l[2*i]), l[2*i + 1]) for i in range(3)]
        self.frame[name] = ("rot", v)

    def both(self, base, x=0.0, y=0.0, z=0.0, xr=None, yr=None, zr=None):
        self.rot(base + ".L", x, y, z)
        self.rot(base + ".R", x if xr is None else xr, y if yr is None else yr, z if zr is None else zr)

    def lift(self, bone, dz):
        self.frame[bone + "@loc"] = ("loc", self.up[bone]*dz)

    def key(self, f):
        for p in self.pb:
            p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
        for k, (kind, v) in self.frame.items():
            if kind == "rot": self.pb[k].rotation_euler = v
            else: self.pb[k.split("@")[0]].location = v
        for p in self.pb:
            p.keyframe_insert("rotation_euler", frame=f, group=p.name)
            if p.name in ("root", "hips"): p.keyframe_insert("location", frame=f, group=p.name)
        self.frame = {}

# arms hang by the sides from the A-pose rest (the rig rests with arms 42 deg down from horizontal)
def arms_down(P, st, swing_l=0.0, swing_r=0.0, bend_l=12.0, bend_r=12.0, out=0.0):
    lo = math.degrees(P.lim.get("upper_arm.L", (math.radians(-35),) * 6)[0]) + 3
    P.rot("upper_arm.L", lo + out, 0, -swing_l); P.rot("upper_arm.R", lo + out, 0, -swing_r)
    P.rot("forearm.L", 0, 0, -bend_l); P.rot("forearm.R", 0, 0, -bend_r)
    P.both("hand", -6, 0, 0)
    for f in FINGERS: P.both(f, -14 if f.endswith("_01") else -18)
    P.both("thumb_01", -8); P.both("thumb_02", -10)

# ---------------------------------------------------------------- clips: fn(P, t (0..1 round the loop), st, s)
def c_idle(P, t, st, s):
    ph = 2*math.pi*t
    br = math.sin(ph*2)                                     # two breaths per loop
    P.rot("hips", 0, 0, 1.5*math.sin(ph)); P.lift("hips", -0.004*s*(1 + math.sin(ph)))
    P.rot("spine", st["lean"]*0.6 + 0.8*br, 0, -1.0*math.sin(ph)); P.rot("chest", st["lean"]*0.4 + 1.2*br)
    P.rot("neck", 2 + 0.5*br, 4*math.sin(ph + 1.0)); P.rot("head", -2 + st["lean"]*0.5, 6*math.sin(ph + 1.0), 1.5*math.sin(ph))
    P.both("shoulder", 1.0*br)
    arms_down(P, st, swing_l=2*math.sin(ph), swing_r=2*math.sin(ph + 0.6), bend_l=10 + 2*br, bend_r=10 + 2*br)
    P.rot("thigh.L", 2 + 1.5*math.sin(ph), 0, 2); P.rot("thigh.R", 2 - 1.5*math.sin(ph), 0, 2)
    P.both("shin", -3 - 1.5*(1 + math.sin(ph))/2, xr=-3 - 1.5*(1 - math.sin(ph))/2)
    P.both("foot", 1)

def gait(P, t, st, s, run):
    ph = 2*math.pi*t
    S = st["stride"]*(1.6 if run else 1.0); A = st["arm"]*(1.6 if run else 1.0)
    for side, off in (("L", 0.0), ("R", math.pi)):
        p = ph + off
        swing = math.cos(p) > 0                                    # thigh moving forward
        th = (24 if not run else 34)*S*math.sin(p) + (3 if not run else 10)
        knee = -(6 + (48 if not run else 85)*S*max(0.0, math.cos(p))**1.5)
        if run: knee -= 20*max(0.0, -math.cos(p))                  # stance knee soaks the landing
        else:   knee -= 8*max(0.0, math.sin(p))*max(0.0, -math.cos(p))
        foot = 10*math.sin(p + 0.5) - (8 if run else 3)*max(0.0, -math.sin(p))
        P.rot("thigh." + side, th, 0, 2); P.rot("shin." + side, knee); P.rot("foot." + side, foot)
        P.rot("toe." + side, -10*max(0.0, -math.sin(p + 0.4)) + 12*max(0.0, -math.cos(p))*(math.sin(p) < 0))
    bob = (0.022 if not run else 0.035)*s*st["bounce"]
    P.lift("hips", -bob*(math.sin(ph)**2) + (0.0 if not run else -0.03*s))
    lean = st["lean"] + (3 if not run else 12)
    P.rot("hips", 0, 7*S*math.sin(ph), 2.5*st["sway"]*math.sin(ph))
    P.rot("spine", lean*0.6, -4*math.sin(ph), -1.5*st["sway"]*math.sin(ph)); P.rot("chest", lean*0.4, -6*math.sin(ph))
    P.rot("neck", -lean*0.3, 2*math.sin(ph)); P.rot("head", -lean*0.3 + 2, 3*math.sin(ph))
    sw = (20 if not run else 38)*A*math.sin(ph)
    arms_down(P, st, swing_l=-sw, swing_r=sw, bend_l=(14 if not run else 80) + 10*max(0, -math.sin(ph)),
              bend_r=(14 if not run else 80) + 10*max(0, math.sin(ph)), out=(0 if not run else 6))

def c_walk(P, t, st, s): gait(P, t, st, s, False)
def c_run(P, t, st, s): gait(P, t, st, s, True)

def ghost_body(P, t, st, s, glide):
    """floating, hunched, head lolling to one side, arms hanging dead, toes pointing down"""
    ph = 2*math.pi*t
    P.lift("root", 0.07*s + 0.025*s*math.sin(ph))
    P.rot("hips", 4, 6*math.sin(ph)*glide, 1.5*math.sin(ph))
    P.rot("spine", 10 + 4*glide, 0, 2*math.sin(ph + 0.5)); P.rot("chest", 8 + 2*glide, 4*math.sin(ph + 0.8))
    twitch = sm(0.70, 0.72, t) - sm(0.76, 0.84, t)              # a sudden jerk of the head once a loop
    P.rot("neck", 14, 3*math.sin(ph), 10 + 4*math.sin(ph*0.5))
    P.rot("head", 16 + 6*twitch, 8*math.sin(ph + 1.2) + 18*twitch, 16 + 5*math.sin(ph) - 14*twitch)
    P.both("shoulder", -8 + 2*math.sin(ph))
    lag = math.sin(ph - 0.9)
    arms_down(P, st, swing_l=6 + 5*lag*(1 + glide), swing_r=6 + 5*math.sin(ph - 1.4)*(1 + glide), bend_l=6, bend_r=8, out=10)
    P.both("hand", -18 - 4*lag)
    for f in FINGERS: P.both(f, -30 - 8*math.sin(ph + 0.3))
    for side, off in (("L", 0.0), ("R", 2.1)):
        P.rot("thigh." + side, 3 + 4*math.sin(ph + off)*glide, 0, 1)
        P.rot("shin." + side, -8 - 6*max(0.0, math.sin(ph + off))*glide)
        P.rot("foot." + side, -38); P.rot("toe." + side, -20)

def c_ghost_idle(P, t, st, s): ghost_body(P, t, st, s, 0.0)
def c_ghost_glide(P, t, st, s): ghost_body(P, t, st, s, 1.0)

CLIPS = {   # name: (fn, frames for the adult man)
    "idle": (c_idle, 96),
    "walk": (c_walk, 34),
    "run": (c_run, 20),
    "ghost_idle": (c_ghost_idle, 120),
    "ghost_glide": (c_ghost_glide, 72),
}

def add_anims(char):
    rig = bpy.data.objects["HumanRig"]; st = STYLE[char]
    s = (rig.data.bones["head"].tail_local.z - rig.data.bones["hips"].head_local.z)/(1.818 - 0.880)
    P = Poser(rig)
    if not rig.animation_data: rig.animation_data_create()
    made = {}
    for name, (fn, frames) in CLIPS.items():
        old = bpy.data.actions.get(name)
        if old: bpy.data.actions.remove(old)
        act = bpy.data.actions.new(name); act.use_fake_user = True
        rig.animation_data.action = act
        n = max(8, round(frames*(st["slow"] if name != "idle" else 1.0)))
        for f in range(n + 1):
            fn(P, (f % n)/n, st, s); P.key(f + 1)
        act.frame_range = (1, n + 1)
        try: act.use_cyclic = True
        except AttributeError: pass
        made[name] = n
    rig.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, made["idle"] + 1
    return made

def anims_all():
    bpy.context.preferences.filepaths.save_version = 0
    out = {}
    for f in blend_files():
        bpy.ops.wm.open_mainfile(filepath=f)
        cut = limit_weights(); made = add_anims(char_of(f))
        out[os.path.basename(f)] = (sum(cut.values()), made)
        bpy.ops.wm.save_mainfile()
    return out

# ---------------------------------------------------------------- Roblox export
def export_model(path):
    """Body + every hair style + every outfit + the rig, in studs; hidden pieces come along (switch them in Roblox)"""
    rig = bpy.data.objects["HumanRig"]
    objs = bound_meshes(rig)
    keep = {o: (o.hide_get(), o.hide_viewport) for o in objs}
    for o in objs: o.hide_viewport = False; o.hide_set(False)
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action if rig.animation_data else None
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=STUDS_PER_M,
                             apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
                             add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
                             mesh_smooth_type='FACE', path_mode='STRIP', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    if rig.animation_data: rig.animation_data.action = act
    for o, (h, hv) in keep.items(): o.hide_viewport = hv; o.hide_set(h)

def export_clip(path, clip):
    rig = bpy.data.objects["HumanRig"]
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    act = bpy.data.actions[clip]; rig.animation_data.action = act
    f0, f1 = (int(x) for x in act.frame_range)
    sc = bpy.context.scene; sc.frame_start, sc.frame_end = f0, f1          # the exporter bakes the scene range
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE'}, global_scale=STUDS_PER_M,
                             apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
                             add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
                             bake_anim=True, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
                             bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True, bake_anim_step=1.0,
                             bake_anim_simplify_factor=0.0)

def export_all(out_dir=os.path.join(M, "roblox")):
    done = []
    for f in blend_files():
        char = char_of(f); name = os.path.splitext(os.path.basename(f))[0]
        d = os.path.join(out_dir, NAMES[char]); os.makedirs(d, exist_ok=True)
        bpy.ops.wm.open_mainfile(filepath=f)
        export_model(os.path.join(d, name + ".fbx")); done.append(name)
        if name == NAMES[char]:                                       # clips once per character (from the normal body)
            for clip in CLIPS: export_clip(os.path.join(d, f"{name}_{clip}.fbx"), clip)
    return done

# ---------------------------------------------------------------- preview: rows = clips, 6 moments each, front and side
def preview(char, out):
    import numpy as np
    sc = bpy.context.scene; rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    zs = [v.co.z for v in body.data.vertices]; H = max(zs) - min(zs)
    sc.render.engine = 'BLENDER_WORKBENCH'; sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_cavity = True
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = H*1.25
    sc.render.resolution_x, sc.render.resolution_y = 170, 260
    tgt = Vector((0, 0, min(zs) + H*0.52))
    rows = []
    for clip in CLIPS:
        act = bpy.data.actions[clip]; rig.animation_data.action = act
        f0, f1 = (int(x) for x in act.frame_range)
        row = []
        for view in (0, 90):
            for k in range(6):
                sc.frame_set(int(f0 + (f1 - f0)*k/6))
                a = math.radians(view); d = Vector((math.sin(a), -math.cos(a), 0))
                cam.location = tgt + d*4; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
                tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
                im = bpy.data.images.load(tmp); arr = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(arr)
                row.append(arr.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
        rows.append(np.concatenate(row, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    bpy.data.objects.remove(cam, do_unlink=True); rig.animation_data.action = bpy.data.actions["idle"]

def preview_all(chars=None, out_dir=os.path.join(M, "anim_previews")):
    os.makedirs(out_dir, exist_ok=True)
    for c in chars or DIRS.values():
        bpy.ops.wm.open_mainfile(filepath=os.path.join(M, NAMES[c], NAMES[c] + ".blend"))
        if "walk" not in bpy.data.actions: add_anims(c)
        preview(c, os.path.join(out_dir, NAMES[c] + ".png"))

if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--save" in argv: anims_all()
    if "--export" in argv: export_all()
    if "--preview" in argv: preview_all([a for a in argv if a in STYLE] or None)
