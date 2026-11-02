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
    "male":         dict(energy=1.00, stride=1.00, arm=1.00, slow=1.00, lean=0, sway=1.0, bounce=1.0),
    "female":       dict(energy=0.90, stride=0.90, arm=0.80, slow=0.95, lean=0, sway=1.8, bounce=0.9),
    "child":        dict(energy=1.10, stride=1.05, arm=1.20, slow=0.80, lean=0, sway=1.0, bounce=1.3),
    "elder_male":   dict(energy=0.55, stride=0.65, arm=0.50, slow=1.35, lean=6, sway=1.2, bounce=0.6),
    "elder_female": dict(energy=0.50, raise_max=55, stride=0.60, arm=0.45, slow=1.40, lean=5, sway=1.5, bounce=0.5),
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

def gait(P, t, st, s, run, short=1.0):
    """walk / run cycle; short < 1 = small steps (a long tight skirt)"""
    ph = 2*math.pi*t
    S = st["stride"]*(1.45 if run else 1.0)*short; A = st["arm"]*(1.6 if run else 1.0)
    for side, off in (("L", 0.0), ("R", math.pi)):
        p = ph + off
        swing = math.cos(p) > 0                                    # thigh moving forward
        th = (24 if not run else 34)*S*math.sin(p) + (3 if not run else 10)
        knee = -(6 + (48 if not run else 78)*S*max(0.0, math.cos(p))**1.5)*(1 if short == 1.0 else 0.8)
        if run: knee -= 20*max(0.0, -math.cos(p))                  # stance knee soaks the landing
        else:   knee -= 8*max(0.0, math.sin(p))*max(0.0, -math.cos(p))
        foot = 10*math.sin(p + 0.5) - (8 if run else 3)*max(0.0, -math.sin(p))
        P.rot("thigh." + side, th, 0, 5 if (run and short < 1.0) else 2)   # short running steps: legs a little apart so the thighs don't rub
        P.rot("shin." + side, knee); P.rot("foot." + side, foot)
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
# long pha sin / sarong: small quick steps, the knees stay inside the cloth
def c_walk_skirt(P, t, st, s): gait(P, t, st, s, False, short=0.38)
def c_run_skirt(P, t, st, s): gait(P, t, st, s, True, short=0.30)

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


# ---------------------------------------------------------------- hands
def hand(P, side, shape, k=1.0):
    """finger poses (left-side convention): relax, fist, rock (index + pinky up), point, jeeb (Thai dance:
    thumb and index tips together, the other fingers fanned and bent back), wong (flat, fingers bent back)"""
    sd = "." + side
    def fing(name, a, b_, c): P.rot(f"{name}_01{sd}", a*k); P.rot(f"{name}_02{sd}", b_*k); P.rot(f"{name}_03{sd}", c*k)
    if shape == "fist":
        for f in ("index", "middle", "ring", "pinky"): fing(f, -80, -95, -65)
        P.rot("thumb_01" + sd, -30*k, 0, -20*k); P.rot("thumb_02" + sd, -50*k); P.rot("thumb_03" + sd, -40*k)
    elif shape == "rock":
        fing("index", 0, 0, 0); fing("pinky", 0, 0, 0)
        fing("middle", -80, -95, -65); fing("ring", -80, -95, -65)
        P.rot("thumb_01" + sd, -35*k, 0, -25*k); P.rot("thumb_02" + sd, -50*k); P.rot("thumb_03" + sd, -40*k)
    elif shape == "point":
        fing("index", 0, 0, 0)
        for f in ("middle", "ring", "pinky"): fing(f, -80, -95, -65)
        P.rot("thumb_01" + sd, -30*k, 0, -20*k); P.rot("thumb_02" + sd, -40*k)
    elif shape == "jeeb":
        fing("index", -45, -55, -35)
        for f, sp in (("middle", -6), ("ring", 0), ("pinky", 6)):
            P.rot(f"{f}_01{sd}", 8*k, 0, sp*k); P.rot(f"{f}_02{sd}", 0); P.rot(f"{f}_03{sd}", 0)
        P.rot("thumb_01" + sd, -40*k, 10*k, -30*k); P.rot("thumb_02" + sd, -30*k); P.rot("thumb_03" + sd, -20*k)
    elif shape == "wong":
        for f in ("index", "middle", "ring", "pinky"): fing(f, 10, 0, 0)
        P.rot("thumb_01" + sd, -15*k, 0, -10*k); P.rot("thumb_02" + sd, -10*k)
    else:   # relax
        for f in ("index", "middle", "ring", "pinky"): fing(f, -14, -18, -14)
        P.rot("thumb_01" + sd, -8); P.rot("thumb_02" + sd, -10)

# arms go no higher than this above the A-pose rest: past ~75 deg the side of the chest (skinned partly to the
# arm) bulges out through shirts - linear skinning, the same in Roblox
RAISE_MAX = 70

def arm(P, side, raise_, fwd, bend, wrist=0.0, twist=0.0, dev=0.0):
    """one arm, degrees: raise_ (+ up from the A-pose rest), fwd (+ forward), elbow bend (+ bent), wrist (+ bent back)"""
    raise_ = min(raise_, P.raise_max)
    P.rot("upper_arm." + side, raise_, twist, -fwd); P.rot("forearm." + side, 0, 0, -bend); P.rot("hand." + side, wrist, 0, dev)

def legs_bounce(P, depth, side_shift=0.0, e=1.0):
    """knees dip by `depth` deg, feet stay planted; side_shift (deg) moves the hips over one foot"""
    P.both("thigh", depth*0.55, 0, 2, zr=2); P.both("shin", -depth); P.both("foot", depth*0.45)
    P.rot("thigh.L", depth*0.55, 0, 2 + side_shift); P.rot("thigh.R", depth*0.55, 0, 2 - side_shift)

def beat(t, n, sharp=2.0):
    """0..1 pulse per beat (n beats per loop), 1 on the beat, falling off"""
    ph = (t*n) % 1.0
    return math.exp(-sharp*ph*4) if ph < 0.5 else math.exp(-sharp*(1 - ph)*4)*0.3

# ---------------------------------------------------------------- dances (tempo fixed: they keep the music's beat)
def c_ramwong(P, t, st, s):
    """รำวง: small steps in place on the beat, one hand ตั้งวง high and one จีบ low, swapping every 4 beats"""
    e = st["energy"]; ph = 2*math.pi*t
    half = (t*2) % 1.0; sw = 1 if t < 0.5 else -1                 # which hand is high
    mix_ = sm(0.0, 0.12, half)*(1 - sm(0.88, 1.0, half))            # swap the hands smoothly
    step = math.sin(ph*4)                                           # 8 beats: a step per beat
    dip = 6 + 6*abs(step)*e
    P.lift("hips", -0.012*s*abs(step)*e)
    for side, sgn in (("L", 1), ("R", -1)):
        lift_ = max(0.0, step*sgn)
        P.rot("thigh." + side, dip*0.5 + 14*lift_*e, 0, 3); P.rot("shin." + side, -dip - 22*lift_*e); P.rot("foot." + side, dip*0.4 + 6*lift_)
    P.rot("hips", 0, 6*math.sin(ph*2), 2*step)
    P.rot("spine", 3, -5*math.sin(ph*2), -3*step); P.rot("chest", 2, -4*math.sin(ph*2), -2*step)
    P.rot("neck", 2, 0, 4*step); P.rot("head", 4, 8*math.sin(ph*2 + 0.5), 5*step)
    for side, hi in (("L", sw > 0), ("R", sw < 0)):
        h = mix_ if hi else 0.0                                      # 1 = high ตั้งวง, 0 = low จีบ
        arm(P, side, raise_=-20 + 85*h, fwd=40 - 35*h, bend=80 + 15*h, wrist=35 + 15*h)
        hand(P, side, "wong" if h > 0.5 else "jeeb")
    P.both("shoulder", 3)

def c_wan_rock(P, t, st, s):
    """🤘 up on the right, head-banging on the beat, knees bouncing, left hand loose"""
    e = st["energy"]; b = beat(t, 8)
    legs_bounce(P, 8 + 10*b*e, 3*math.sin(2*math.pi*t*2))
    P.lift("hips", -0.015*s*b*e)
    P.rot("spine", -4 + 6*b*e, 6*math.sin(2*math.pi*t*2)); P.rot("chest", -3 + 5*b*e)
    P.rot("neck", 4 + 14*b*e); P.rot("head", 6 + 16*b*e, 0, 4*math.sin(2*math.pi*t*2))
    pump = math.sin(2*math.pi*t*8)
    arm(P, "R", raise_=64 + 8*pump*e, fwd=20, bend=55 - 15*pump*e, wrist=10); hand(P, "R", "rock")
    arm(P, "L", raise_=-25, fwd=10 + 6*b, bend=30 + 15*b, wrist=-10); hand(P, "L", "relax")
    P.both("shoulder", 4*b*e)

def c_wan_bounce(P, t, st, s):
    """knee bounce with alternate shoulder shimmy, arms swinging loose across the body"""
    e = st["energy"]; b = beat(t, 8, 1.5); alt = math.sin(2*math.pi*t*4)
    legs_bounce(P, 10 + 12*b*e, 4*alt)
    P.lift("hips", -0.02*s*b*e)
    P.rot("hips", 0, 10*alt*e, 3*alt)
    P.rot("spine", 4, -8*alt*e, -3*alt); P.rot("chest", 3, -6*alt*e)
    P.rot("shoulder.L", 10*max(0.0, alt)*e); P.rot("shoulder.R", 10*max(0.0, -alt)*e)
    P.rot("neck", 4*b); P.rot("head", 6*b, 10*alt, 0)
    arm(P, "L", raise_=-15, fwd=25 + 25*alt*e, bend=50 + 20*b, wrist=-10); hand(P, "L", "fist", 0.6)
    arm(P, "R", raise_=-15, fwd=25 - 25*alt*e, bend=50 + 20*b, wrist=-10); hand(P, "R", "fist", 0.6)

def c_wan_point(P, t, st, s):
    """step-touch side to side, pointing forward and up with the hand on the stepping side"""
    e = st["energy"]; ph = 2*math.pi*t; side = math.sin(ph*2)       # 2 step-touches each way per loop
    b = beat(t, 8)
    legs_bounce(P, 8 + 8*b*e, 7*side*e)
    P.rot("thigh.L", 6 + 6*max(0.0, -side)*e, 0, 2 + 7*side*e + 5*max(0.0, -side)*e)
    P.rot("thigh.R", 6 + 6*max(0.0, side)*e, 0, 2 - 7*side*e + 5*max(0.0, side)*e)
    P.rot("hips", 0, 0, 5*side*e); P.rot("spine", 2, 8*side*e, -4*side*e); P.rot("chest", 2, 6*side*e)
    P.rot("head", 4 + 6*b, -10*side, 4*side)
    for sd, sg in (("L", 1), ("R", -1)):
        on = max(0.0, side*sg)
        arm(P, sd, raise_=-20 + 78*on*e, fwd=30 + 40*on, bend=60 - 45*on, wrist=0); hand(P, sd, "point" if on > 0.3 else "fist", 0.8)

def c_wan_cool(P, t, st, s):
    """arms crossed, leaning back on one leg, nodding to the beat (the refs standing with crossed arms)"""
    e = st["energy"]; b = beat(t, 8, 1.2); ph = 2*math.pi*t
    P.rot("thigh.L", 4, 0, 6); P.rot("shin.L", -4); P.rot("thigh.R", 6 + 2*b, 0, 3); P.rot("shin.R", -9 - 3*b); P.both("foot", 4)
    P.rot("hips", 0, 6, 4 + 1.5*math.sin(ph)); P.lift("hips", -0.005*s*b)
    P.rot("spine", -5, -4, -3); P.rot("chest", -3, -3)
    P.rot("neck", 3 + 6*b*e); P.rot("head", 4 + 8*b*e, 8*math.sin(ph), -4)
    arm(P, "L", raise_=-16, fwd=55, bend=96, wrist=0); hand(P, "L", "relax")      # forearms across the chest, left one on top
    arm(P, "R", raise_=-32, fwd=60, bend=84, wrist=0); hand(P, "R", "relax")
    P.both("shoulder", 3)

def c_wan_hands_up(P, t, st, s):
    """both hands up waving side to side, bouncing"""
    e = st["energy"]; ph = 2*math.pi*t; b = beat(t, 8); wave = math.sin(ph*2)
    legs_bounce(P, 8 + 12*b*e, 4*wave)
    P.lift("hips", -0.018*s*b*e)
    P.rot("hips", 0, 0, 4*wave); P.rot("spine", -3, 0, -6*wave*e); P.rot("chest", -2, 0, -4*wave*e)
    P.rot("head", -4 + 6*b, 0, 8*wave)
    for sd in ("L", "R"):
        arm(P, sd, raise_=RAISE_MAX, fwd=10, bend=18 + 8*b, wrist=10, dev=0)
        hand(P, sd, "wong")
    up = min(RAISE_MAX*min(1.0, 0.7 + e*0.4), P.raise_max)
    P.rot("upper_arm.L", up, 0, -24 - 12*wave*e); P.rot("upper_arm.R", up, 0, -24 + 12*wave*e)   # a bit forward: clear of the armpit fold

def hip_drop(depth, s):
    """how far the hips go down when legs_bounce bends the knees by `depth` deg (feet stay on the ground)"""
    a, b_ = math.radians(depth*0.55), math.radians(depth*0.45)
    return 0.45*s*((1 - math.cos(a)) + (1 - math.cos(b_)))

# The two below are the rod-hae teens' "twerk" and "floor" dances made tame for a Roblox game: body upright, facing
# front, no bending over or thrusting. Place dancers facing the way the parade goes, spaced apart, never backed up
# to or facing another character close by.
def c_wan_hip_shake(P, t, st, s):
    """hip shake (tame twerk): knees soft, hips swaying side to side on every half beat, torso upright,
    one hand up waving and the other on the hip, swapping halfway"""
    e = st["energy"]; ph = 2*math.pi*t; b = beat(t, 8, 1.5)
    shake = math.sin(ph*16)                                          # two hip swings per beat
    legs_bounce(P, 14 + 6*b*e, 5*shake*e)
    P.lift("hips", -hip_drop(14 + 6*b*e, s))
    P.rot("hips", 0, 6*shake*e, 7*shake*e)
    P.rot("spine", 3, -4*shake*e, -5*shake*e); P.rot("chest", 2, -2*shake*e, -2*shake*e)
    P.rot("neck", 2); P.rot("head", 4 + 4*b, 6*math.sin(ph*2), 3*shake)
    sw = 1 if t < 0.5 else -1
    mix_ = sm(0.0, 0.1, (t*2) % 1.0)*(1 - sm(0.9, 1.0, (t*2) % 1.0))
    for sd, hi in (("L", sw > 0), ("R", sw < 0)):
        h = mix_ if hi else 0.0
        wave = math.sin(ph*4)
        arm(P, sd, raise_=-28 + 92*h, fwd=10 + 15*h, bend=95 - 70*h, wrist=10*h + 15*wave*h, dev=-20*(1 - h))
        hand(P, sd, "wong" if h > 0.5 else "relax")
    P.both("shoulder", 3*b)

def c_wan_low_bounce(P, t, st, s):
    """floor dance (tame): sink low over two beats, bounce at the bottom pumping both fists forward, come back up;
    back straight, facing front"""
    e = st["energy"]; b = beat(t, 8, 1.5)
    down = sm(0.0, 0.25, t)*(1 - sm(0.75, 1.0, t))                   # 2 beats down, 4 at the bottom, 2 up
    depth = 12 + (55*min(1.0, e) + 8*b)*down + 6*b*(1 - down)
    legs_bounce(P, depth)
    P.lift("hips", -hip_drop(depth, s))
    P.rot("spine", 6 + 6*down, 0, 0); P.rot("chest", 2)
    P.rot("neck", 2 + 4*b); P.rot("head", 2 + 6*b, 8*math.sin(2*math.pi*t*2))
    pump = math.sin(2*math.pi*t*8)
    for sd, sg in (("L", 1), ("R", -1)):
        arm(P, sd, raise_=-5 + 20*down, fwd=45 + 20*pump*sg*down, bend=70 - 20*pump*sg*down, wrist=0)
        hand(P, sd, "fist", 0.8)

def c_ghost_dance(P, t, st, s):
    """ผีเต้น: floating, jerking from pose to pose on a broken rhythm, limbs out of step, head rolling"""
    stops = [0.0, 0.07, 0.12, 0.25, 0.31, 0.44, 0.5, 0.58, 0.69, 0.75, 0.86, 0.93]
    q = max(x for x in stops if x <= t); nxt = next((x for x in stops if x > q), 1.0)
    u = sm(0.0, 0.35, (t - q)/(nxt - q))                           # snap fast to each pose, then hold
    def pose(k):
        r = [math.sin(k*12.9898 + i*78.233)*43758.5453 % 1.0 for i in range(10)]
        return r
    a, c = pose(stops.index(q)), pose((stops.index(q) + 1) % len(stops))
    v = [a[i] + (c[i] - a[i])*u for i in range(10)]
    P.lift("root", 0.07*s + 0.03*s*math.sin(2*math.pi*t))
    P.rot("spine", 10 + 20*(v[0] - 0.5), 30*(v[1] - 0.5), 20*(v[2] - 0.5)); P.rot("chest", 8, 20*(v[1] - 0.5))
    P.rot("neck", 12 + 20*(v[3] - 0.5), 30*(v[4] - 0.5), 25*(v[5] - 0.5)); P.rot("head", 15 + 25*(v[6] - 0.5), 40*(v[4] - 0.5), 30*(v[5] - 0.5))
    arm(P, "L", raise_=-30 + (RAISE_MAX + 30)*v[7], fwd=60*v[8], bend=80*v[9], wrist=-40); hand(P, "L", "wong")
    arm(P, "R", raise_=-30 + (RAISE_MAX + 30)*v[2], fwd=60*v[0], bend=80*v[3], wrist=-40); hand(P, "R", "wong")
    for sd, k in (("L", v[6]), ("R", v[8])):
        P.rot("thigh." + sd, 4 + 8*(k - 0.3), 0, 4); P.rot("shin." + sd, -8 - 14*k); P.rot("foot." + sd, -38); P.rot("toe." + sd, -20)

CLIPS = {   # name: (fn, frames for the adult man)
    "idle": (c_idle, 96),
    "walk": (c_walk, 34),
    "run": (c_run, 20),
    "walk_skirt": (c_walk_skirt, 28),
    "run_skirt": (c_run_skirt, 18),
    "ghost_idle": (c_ghost_idle, 120),
    "ghost_glide": (c_ghost_glide, 72),
    # dances: 120 bpm (a beat = 15 frames), the same tempo for everyone
    "ramwong": (c_ramwong, 120),
    "wan_rock": (c_wan_rock, 120),
    "wan_bounce": (c_wan_bounce, 120),
    "wan_point": (c_wan_point, 120),
    "wan_cool": (c_wan_cool, 120),
    "wan_hands_up": (c_wan_hands_up, 120),
    "wan_hip_shake": (c_wan_hip_shake, 120),
    "wan_low_bounce": (c_wan_low_bounce, 120),
    "ghost_dance": (c_ghost_dance, 120),
}
FIXED_TEMPO = {"idle", "ramwong", "wan_rock", "wan_bounce", "wan_point", "wan_cool", "wan_hands_up", "wan_hip_shake",
               "wan_low_bounce", "ghost_dance"}

def add_anims(char):
    rig = bpy.data.objects["HumanRig"]; st = STYLE[char]
    s = (rig.data.bones["head"].tail_local.z - rig.data.bones["hips"].head_local.z)/(1.818 - 0.880)
    P = Poser(rig); P.raise_max = st.get("raise_max", RAISE_MAX)     # an old, bent back can't lift the arms as high
    if not rig.animation_data: rig.animation_data_create()
    made = {}
    for name, (fn, frames) in CLIPS.items():
        old = bpy.data.actions.get(name)
        if old: bpy.data.actions.remove(old)
        act = bpy.data.actions.new(name); act.use_fake_user = True
        rig.animation_data.action = act
        n = max(8, round(frames*(st["slow"] if name not in FIXED_TEMPO else 1.0)))
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

def save_retry():
    """save the open .blend, retrying: Windows sometimes holds the old file a moment (scanner, indexer) and Blender
    can't swap the new one in ("Cannot change old file")"""
    import time
    for attempt in range(6):
        try: bpy.ops.wm.save_mainfile(); return
        except RuntimeError:
            if attempt == 5: raise
            time.sleep(1.0 + attempt)

def anims_all():
    bpy.context.preferences.filepaths.save_version = 0
    out = {}
    for f in blend_files():
        bpy.ops.wm.open_mainfile(filepath=f)
        cut = limit_weights(); made = add_anims(char_of(f))
        out[os.path.basename(f)] = (sum(cut.values()), made)
        save_retry()
    return out

# ---------------------------------------------------------------- Roblox export
def fbx(path, **kw):
    """export, retrying: Windows sometimes refuses to open a file that was just written (virus scanner, indexer)"""
    import time
    for attempt in range(6):
        try:
            return bpy.ops.export_scene.fbx(filepath=path, **kw)
        except RuntimeError as e:
            if "Errno 22" not in str(e) and "Errno 13" not in str(e) or attempt == 5: raise
            time.sleep(1.5*(attempt + 1))

def _clothes():
    ns = {"__name__": "clothes"}
    exec(open(os.path.join(M, "human_base", "build_clothes.py"), encoding="utf-8").read(), ns)
    return ns

def split_skin(char):
    """The Body cut into pieces by which outfits cover them (build_clothes.hidden_faces): "Body" = skin no outfit
    hides, Skin_00, Skin_01, ... = skin hidden under the outfits listed for it in the returned map. Roblox drops
    the pieces the chosen outfit covers, so a thin shirt never has skin coming through it.
    The pieces keep the whole body's normals (no shading seam where they meet). Returns (pieces, {piece: outfits})."""
    import json, bmesh
    body = bpy.data.objects["Body"]; me = body.data
    faces = json.load(open(os.path.join(M, NAMES[char], NAMES[char] + "_clothes.json")))["outfits"]
    hid = {o: set(fs) for o, fs in _clothes()["hidden_faces"](me, faces).items()}
    groups = {}
    for p in me.polygons:
        groups.setdefault(tuple(o for o in faces if p.index in hid[o]), []).append(p.index)
    def key(co, c): return (round(co.x, 5), round(co.y, 5), round(co.z, 5), round(c.x, 5), round(c.y, 5), round(c.z, 5))
    nrm = {}
    for p in me.polygons:
        for li in p.loop_indices: nrm[key(me.vertices[me.loops[li].vertex_index].co, p.center)] = me.corner_normals[li].vector.copy()
    body.name = "Body_whole"
    pieces, hides = [], {}
    order = sorted(groups.items(), key=lambda kv: (len(kv[0]) > 0, -len(kv[1])))
    for n, (outfits, fs) in enumerate(order):
        name = "Body" if not outfits else f"Skin_{n - 1:02d}"
        ob = body.copy(); ob.data = me.copy(); ob.name = name; ob.data.name = name
        for c in body.users_collection: c.objects.link(ob)
        bm = bmesh.new(); bm.from_mesh(ob.data); keep = set(fs)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context='FACES')
        bm.to_mesh(ob.data); bm.free()
        pm = ob.data
        pm.normals_split_custom_set([nrm[key(pm.vertices[pm.loops[li].vertex_index].co, p.center)] for p in pm.polygons for li in p.loop_indices])
        pieces.append(ob); hides[name] = list(outfits)
    return pieces, hides

def unsplit_skin(pieces):
    for ob in pieces:
        me = ob.data; bpy.data.objects.remove(ob, do_unlink=True); bpy.data.meshes.remove(me)
    bpy.data.objects["Body_whole"].name = "Body"

def export_model(path):
    """Body + every hair style + every outfit + the rig, in studs; hidden pieces come along (switch them in Roblox).
    path_mode COPY puts the textures next to the FBX, so Roblox's 3D Importer finds them and builds each
    SurfaceAppearance itself (with STRIP it only knew the file names and could not read them).
    The Body goes out cut by split_skin; which piece each outfit hides is written to <file>_skin.json."""
    import json
    rig = bpy.data.objects["HumanRig"]
    pieces, hides = split_skin(char_of(bpy.data.filepath))
    json.dump(hides, open(path[:-4] + "_skin.json", "w"), indent=1)
    objs = [o for o in bound_meshes(rig) if o.name != "Body_whole"]
    keep = {o: (o.hide_get(), o.hide_viewport) for o in objs}
    for o in objs: o.hide_viewport = False; o.hide_set(False)
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action if rig.animation_data else None
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    fbx(path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=STUDS_PER_M,
                             apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
                             add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
                             mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    if rig.animation_data: rig.animation_data.action = act
    for o, (h, hv) in keep.items():
        if o not in pieces: o.hide_viewport = hv; o.hide_set(h)
    unsplit_skin(pieces)

def export_clip(path, clip):
    rig = bpy.data.objects["HumanRig"]
    bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True); bpy.context.view_layer.objects.active = rig
    act = bpy.data.actions[clip]; rig.animation_data.action = act
    f0, f1 = (int(x) for x in act.frame_range)
    sc = bpy.context.scene; sc.frame_start, sc.frame_end = f0, f1          # the exporter bakes the scene range
    fbx(path, use_selection=True, object_types={'ARMATURE'}, global_scale=STUDS_PER_M,
                             apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
                             add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
                             bake_anim=True, bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False,
                             bake_anim_use_all_actions=False, bake_anim_force_startend_keying=True, bake_anim_step=1.0,
                             bake_anim_simplify_factor=0.0)

def export_clip_data(char, path, step=2):
    """every clip of the open file as plain data for Roblox: per key time, each moving bone's local rotation
    (quaternion x, y, z, w, Blender bone axes) and offset in studs, plus the rest pose to convert them with"""
    import json
    rig = bpy.data.objects["HumanRig"]; sc = bpy.context.scene; keep = rig.animation_data.action
    out = {"fps": FPS, "studs_per_m": STUDS_PER_M, "parents": {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}, "clips": {}}
    # rest pose in armature space: orientation (x, y, z, w) and head position in studs. Roblox may give a bone
    # different local axes than Blender (it did for the arms), so the importer side re-expresses every rotation
    # through armature space using these, instead of trusting bone-local axes to match.
    out["rest"] = {}
    for bn in rig.data.bones:
        q = bn.matrix_local.to_quaternion(); h = bn.head_local*STUDS_PER_M
        out["rest"][bn.name] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6), round(h.x, 5), round(h.y, 5), round(h.z, 5)]
    for clip in CLIPS:
        act = bpy.data.actions[clip]; rig.animation_data.action = act
        f0, f1 = (int(x) for x in act.frame_range)
        frames = list(range(f0, f1 + 1, step))
        if frames[-1] != f1: frames.append(f1)
        tracks = {}
        for f in frames:
            sc.frame_set(f)
            for pb in rig.pose.bones:
                m = pb.matrix_basis; q = m.to_quaternion(); t = m.to_translation()*STUDS_PER_M
                tracks.setdefault(pb.name, []).append([round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4),
                                                       round(t.x, 4), round(t.y, 4), round(t.z, 4)])
        moving = {n: k for n, k in tracks.items() if any(abs(a - b) > 1e-4 for r in k for a, b in zip(r, k[0])) or
                  any(abs(v) > 1e-4 for v in k[0][:3] + k[0][4:])}
        out["clips"][clip] = {"length": (f1 - f0)/FPS, "times": [round((f - f0)/FPS, 4) for f in frames], "tracks": moving}
    rig.animation_data.action = keep
    json.dump(out, open(path, "w"), separators=(",", ":"))
    return os.path.getsize(path)

def export_all(out_dir=os.path.join(M, "roblox")):
    done = []
    for f in blend_files():
        char = char_of(f); name = os.path.splitext(os.path.basename(f))[0]
        d = os.path.join(out_dir, NAMES[char]); os.makedirs(d, exist_ok=True)
        bpy.ops.wm.open_mainfile(filepath=f)
        export_model(os.path.join(d, name + ".fbx")); done.append(name)
        if name == NAMES[char]:                                       # clips once per character (from the normal body)
            for clip in CLIPS: export_clip(os.path.join(d, f"{name}_{clip}.fbx"), clip)
    write_skin_luau(out_dir)
    return done

def write_skin_luau(out_dir=os.path.join(M, "roblox")):
    """src/shared/HumanSkinParts.luau: per character, the Skin_ pieces of its Body and the outfits that hide them
    (the same for its fat / thin / pregnant files: same topology, same cut)"""
    import json
    lines = ["--!strict", "-- Generated by assets/models/human_base/build_anims.py (write_skin_luau). Do not edit.",
             "-- Per character: Skin_<n> MeshPart of the imported model -> outfits that cover it (drop the piece when",
             "-- one of these is worn). \"Body\" (skin no outfit covers) is not listed: it always stays.", "return {"]
    for char in DIRS.values():
        f = os.path.join(out_dir, NAMES[char], NAMES[char] + "_skin.json")
        if not os.path.exists(f): continue
        lines.append(f"\t{NAMES[char]} = {{")
        for piece, outfits in json.load(open(f)).items():
            if outfits: lines.append(f"\t\t{piece} = {{ " + ", ".join(f'"{o}"' for o in outfits) + " },")
        lines.append("\t},")
    lines.append("}")
    dst = os.path.join(os.path.dirname(os.path.dirname(M)), "src", "shared", "HumanSkinParts.luau")
    open(dst, "w", newline="\n").write("\n".join(lines) + "\n")

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
