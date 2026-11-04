# Ghosts made from the human models (GHOST_MODELS.md 3.2): per ghost one rigged file with only its body, skin, outfit,
# hair and its own clips, checked frame by frame for clipping, exported for Roblox like the humans.
#
#   exec(open(r"...\human_base\build_ghosts.py", encoding="utf-8").read())
#   build("ghost_tani")      # human_ghosts/ghost_tani.blend: Body + Cloth_* + Hair_* (+ props) on HumanRig, clips
#   report = check("ghost_tani")   # current scene: clipping per clip (skin through cloth, body through body, hair, cloth, props)
#   sheet("ghost_tani")      # human_ghosts/previews/ghost_tani_<clip>.png: 6 moments x front / side / back per clip
#   export("ghost_tani")     # roblox/human_ghosts/ghost_tani/ghost_tani.fbx (model) + ghost_tani_<clip>.fbx (clips)
#   all_ghosts()             # every ghost: build, check, cut, sheet, export; writes human_ghosts/check_report.txt
#   coffin()                 # roblox/human_ghosts/Coffin.fbx: the coffin the funeral ghosts carry (prop)
#
# The Body is kept whole until the export: then the skin under the outfit is cut out (build_clothes.hidden_faces,
# the same faces Roblox drops for the humans) and the headless ghost loses its head (a neck stump closes the cut).
import bpy, bmesh, math, os, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
HB = os.path.join(M, "human_base")
GH = os.path.join(M, "human_ghosts")
RBX = os.path.join(M, "roblox", "human_ghosts")

def _load(fn):
    """the sibling build scripts, pointed at this M (so a copy of the repo builds into itself)"""
    src = open(os.path.join(HB, fn), encoding="utf-8").read()
    src = src.replace('M = r"C:\\Aunival\\pump-lot-anomaly\\assets\\models"', 'M = r"%s"' % M)
    ns = {"__name__": fn[:-3]}; exec(src, ns); return ns
CL = _load("build_clothes.py"); HA = _load("build_hair.py"); AN = _load("build_anims.py")
AN["_clothes"] = lambda: CL
sm = AN["sm"]; arm = AN["arm"]; hand = AN["hand"]; arms_down = AN["arms_down"]; legs_bounce = AN["legs_bounce"]
hip_drop = AN["hip_drop"]; gait = AN["gait"]; FINGERS = AN["FINGERS"]

# ---------------------------------------------------------------- the ghosts
# hair: a different style for each (GHOST_MODELS.md 3.2); skin: material on the Body; seated: the skirt is weighted
# for sitting (its front follows the thighs from the waist down, so the lap doesn't cut through it)
GHOSTS = {
    "ghost_headless": dict(char="female", outfit="ghost_headless", hair=None, skin="SkinGhost", headless=True, seated=True,
                           clips=["pillion_hug"]),                                   # 1: ผู้หญิงชุดไทยไร้หัว ซ้อนท้าย
    "ghost_mirror": dict(char="female", outfit="ghost_thai", hair="ghost_long", skin="SkinGhost", seated=True,
                         clips=["pillion_hug", "pillion_look"]),                     # 11: ผีผู้หญิงในกระจกมองข้าง
    "ghost_tani": dict(char="female", outfit="ghost_tani", hair="ghost_floor", skin="SkinGhost",
                       clips=["ghost_idle", "tani_peek"]),                           # 17: นางตานี
    "ghost_funeral_man": dict(char="male", outfit="ghost_white_m", hair="side_part", skin="SkinWithered",
                              clips=["coffin_walk", "ghost_glide"]),                 # 29: ขบวนแห่ศพ
    "ghost_funeral_woman": dict(char="female", outfit="ghost_white_f", hair="ghost_messy", skin="SkinGhost",
                                clips=["coffin_walk", "ghost_glide"]),
    "ghost_funeral_elder_woman": dict(char="elder_female", outfit="ghost_white_f", hair="bun_grey", skin="SkinWithered",
                                      clips=["coffin_walk", "ghost_glide"]),
    "ghost_funeral_elder_man": dict(char="elder_male", outfit="ghost_white_m", hair="bald_grey", skin="SkinGhost",
                                    clips=["coffin_walk", "ghost_glide"]),
    "ghost_dancer": dict(char="female", outfit="ghost_dancer", hair=None, skin="SkinGhost", face="porcelain",
                         clips=["dancer_dance", "dancer_idle"]),                     # ผีนางรำ (ref: art_refs/body/ghost_dancer_ref.jpg)
    # props: rigid pieces of the ghost on one bone (PROPS); allow: body-part pairs that touch by design (palms pressed together)
    "ghost_shroud": dict(char="male", outfit="ghost_shroud", hair=None, skin="SkinWithered", props=["jaw_tie"],
                         allow=[("hand.L", "hand.R")], clips=["shroud_idle", "shroud_glide"]),     # 29: ศพห่อผ้าขาว ตราสัง
    "ghost_child": dict(char="child", outfit="ghost_child", hair="child_short", skin="SkinGhost",
                        clips=["ghost_idle", "ghost_glide"]),                        # ผีเด็ก
    "ghost_mae_nak": dict(char="female", outfit="ghost_nak", hair="ghost_long", skin="SkinGhost", props=["baby"],
                          stretch=("forearm.R", "hand.R"), clips=["nak_cradle", "nak_reach"]),    # แม่นาค: อุ้มลูก / แขนยืด
    "ghost_kuman_thong": dict(char="child", outfit="ghost_kuman", hair="juk", skin="SkinGold",
                              clips=["kuman_sit", "kuman_giggle", "run"]),           # กุมารทอง
    "ghost_ta_khon": dict(char="male", outfit="mohom", hair=None, skin="Skin", props=["ta_khon_mask"],
                          clips=["ride_moto", "mask_tilt"]),                         # 8: คนขับใส่หน้ากากผีตาโขน เลือดซึมจากตา
}

# ---------------------------------------------------------------- clips (build_anims.py conventions: left-side degrees)
def pillion(P, t, st, s, look=0.0, headless=False):
    """ซ้อนท้ายมอเตอร์ไซค์แบบนั่งข้าง (side-saddle, legs to her left, the way women in a pha sin ride): hips turned to
    the left, chest turned back to the front, both arms round the driver's waist, breathing and swaying with the bike"""
    ph = 2*math.pi*t; br = math.sin(ph*2); sw = math.sin(ph)
    P.rot("hips", 0, 62, 0)
    P.both("thigh", 84, 0, 2, zr=-2); P.rot("thigh.L", 84, 0, 4); P.rot("thigh.R", 82, 0, -4)
    P.both("shin", -82); P.both("foot", 6)
    P.rot("spine", 8 + 0.8*br, -34, 1.5*sw); P.rot("chest", 6 + 1.0*br, -24, 1.0*sw)
    for sd in ("L", "R"):
        arm(P, sd, raise_=2, fwd=74 + 1.0*br, bend=58 - 1.5*br, wrist=-6, twist=-10)
        hand(P, sd, "relax", 0.6)
    P.both("shoulder", 2 + 0.6*br)
    if not headless:        # cheek resting towards the driver's back; `look` turns the head slowly to the mirror
        P.rot("neck", 8 - 10*look, -10*look, 6*(1 - look)); P.rot("head", 8 - 14*look, -38*look, 8*(1 - look) + 2*sw)

def c_pillion_hug(P, t, st, s): pillion(P, t, st, s, headless=P.headless)
def c_pillion_look(P, t, st, s):
    """the mirror ghost: holding on, then the head turns slowly to the right mirror, holds, and turns back"""
    look = sm(0.25, 0.45, t)*(1 - sm(0.80, 0.97, t))
    pillion(P, t, st, s, look=look)

def c_tani_peek(P, t, st, s):
    """นางตานี: floating behind the banana clump, leans out to her right, raises the right arm and points at the
    driver, holds it, then draws back in"""
    ph = 2*math.pi*t
    lean = sm(0.10, 0.32, t)*(1 - sm(0.82, 0.98, t)); point = sm(0.38, 0.52, t)*(1 - sm(0.74, 0.86, t))
    P.lift("root", 0.07*s + 0.02*s*math.sin(ph))
    P.rot("hips", 2, 0, 3*lean)
    P.rot("spine", 6, -6*lean, 14*lean); P.rot("chest", 4, -6*lean, 12*lean)
    P.rot("neck", 8, -8*lean, 10*lean); P.rot("head", 6 + 4*point, -10*lean - 6*point, 8*lean)
    arms_down(P, st, swing_l=4, swing_r=4, bend_l=8, bend_r=8, out=8)
    P.rot("upper_arm.L", -28, 0, -6)
    arm(P, "R", raise_=-30 + 92*point, fwd=8 + 62*point, bend=10 - 6*point, wrist=-6*point)
    hand(P, "R", "point" if point > 0.3 else "relax")
    for sd in ("L", "R"):
        P.rot("thigh." + sd, 3, 0, 1); P.rot("shin." + sd, -8); P.rot("foot." + sd, -38); P.rot("toe." + sd, -20)

COFFIN_ARM = dict(raise_=58, fwd=40, bend=128, wrist=-22, twist=-8)
def c_coffin_walk(P, t, st, s):
    """แบกโลง: slow short steps (a pha sin / long trousers), the right hand up holding the coffin pole on the right
    shoulder, the shoulder raised under it, head bowed, the left arm hanging with little swing"""
    gait(P, t, st, s, False, short=0.34)
    ph = 2*math.pi*t
    arm(P, "R", **COFFIN_ARM); hand(P, "R", "fist")
    P.rot("shoulder.R", 8); P.rot("shoulder.L", -2)
    lo = math.degrees(P.lim.get("upper_arm.L", (math.radians(-35),)*6)[0]) + 3
    P.rot("upper_arm.L", lo + 4, 0, -6*math.sin(ph)); P.rot("forearm.L", 0, 0, -10)
    P.rot("spine", 4 + st["lean"]*0.6, -2*math.sin(ph), -3); P.rot("chest", 2, -2*math.sin(ph), -2)
    P.rot("neck", 10); P.rot("head", 12, 2*math.sin(ph), 4)

# ผีนางรำ: classical Thai dance poses (ref: art_refs/body/ghost_dancer_ref.jpg). Arms: (raise, fwd, bend, wrist, twist, hand);
# wrist + = bent back, so the flat palm faces out with the fingers up (ตั้งมือ); fingers bend back a little (wong)
DANCE = {
    # the reference: weight on the right leg, left knee bent forward, right arm straight out to the side (ตั้งมือ),
    # left hand in front of the chest palm out, head tilted to the extended arm
    # legs (thigh fwd, thigh out, shin, foot): weight on the right leg in a deep plie, the left foot forward, heel down,
    # toes up; foot = -(thigh + shin) keeps a sole flat, more lifts the toes
    "A": dict(LR=(30, 10, -56, 26), LL=(28, 4, -14, 12), drop=56, hz=5, sz=-6, cz=-4, hy=8, hz_=10,
              R=(40, -6, 6, 62, -70, "wong"), L=(-20, 45, 110, 70, 15, "wong")),     # hand in front of the chest, palm out, forearm clear of the sabai (found by a grid search)
    # ตั้งวง high in front with the right hand, จีบ low at the left hip, weight centred, deeper
    "C": dict(LR=(26, 10, -46, 20), LL=(26, 10, -46, 20), drop=46, hz=0, sz=0, cz=-2, hy=-6, hz_=-6,
              R=(44, 38, 72, 52, -20, "wong"), L=(-22, 22, 58, 28, 10, "jeeb")),
}
def _mirror(d):
    m = dict(d, LL=d["LR"], LR=d["LL"], hz=-d["hz"], sz=-d["sz"], cz=-d["cz"], hy=-d["hy"], hz_=-d["hz_"], R=d["L"], L=d["R"])
    return m
DANCE["B"] = _mirror(DANCE["A"]); DANCE["D"] = _mirror(DANCE["C"])
DANCE_SEQ = ["A", "C", "B", "D"]

def dancer_pose(P, d, s, br=0.0, tw=0.0):
    for sd in ("L", "R"):
        tx, tz, sh, ft = d["L" + sd]
        P.rot("thigh." + sd, tx, 0, tz); P.rot("shin." + sd, sh); P.rot("foot." + sd, ft)
    P.lift("hips", -hip_drop(d["drop"], s)*0.85)
    P.rot("hips", 0, 0, d["hz"]); P.rot("spine", -4 + 0.6*br, 0, d["sz"]); P.rot("chest", -4 + 0.8*br, 0, d["cz"])
    P.rot("neck", 2, d["hy"]*0.4, d["hz_"]*0.5); P.rot("head", 4 + 4*tw, d["hy"] + 12*tw, d["hz_"] - 8*tw)
    for sd in ("L", "R"):
        r_, f_, b_, w_, t_, h_ = d[sd]
        arm(P, sd, raise_=r_, fwd=f_, bend=b_, wrist=w_, twist=t_); hand(P, sd, h_)

def _blend(a, b, u):
    out = {}
    for k in a:
        if k in ("LL", "LR"):
            out[k] = tuple(x + (y - x)*u for x, y in zip(a[k], b[k]))
        elif k in ("L", "R"):
            out[k] = tuple(x + (y - x)*u for x, y in zip(a[k][:5], b[k][:5])) + ((a[k][5] if u < 0.5 else b[k][5]),)
        else: out[k] = a[k] + (b[k] - a[k])*u
    return out

def c_dancer_dance(P, t, st, s):
    """รำ ช้าๆ ชวนขนลุก: holds each classical pose, then flows slowly to the next (A the reference pose, C ตั้งวง/จีบ,
    B and D the same mirrored); the head jerks a little now and then against the calm body"""
    n = len(DANCE_SEQ); q = t*n; i = int(q) % n; u = q - int(q)
    a, b_ = DANCE[DANCE_SEQ[i]], DANCE[DANCE_SEQ[(i + 1) % n]]
    d = _blend(a, b_, sm(0.45, 1.0, u))                     # hold, then move
    tw = sum(sm(c, c + 0.012, t) - sm(c + 0.03, c + 0.08, t) for c in (0.17, 0.52, 0.81))
    dancer_pose(P, d, s, br=math.sin(2*math.pi*t*4), tw=tw)

def c_dancer_idle(P, t, st, s):
    """waiting: knees soft, hands together in front of the waist (one จีบ, one ตั้งวง low), breathing, the head
    tilting slowly from side to side"""
    ph = 2*math.pi*t; br = math.sin(ph*2)
    d = dict(LR=(30, 10, -54 - 2*br, 25 + br), LL=(28, 4, -14, 12), drop=54 + 2*br,          # the reference stance, breathing
             hz=4 + 1.5*math.sin(ph), sz=-5 - 1.5*math.sin(ph), cz=-3, hy=6*math.sin(ph), hz_=8*math.sin(ph + 0.6),
             R=(-16, 40, 72, 34, -10, "wong"), L=(-18, 38, 76, 30, 10, "jeeb"))
    dancer_pose(P, d, s, br=br)

def shroud_body(P, t, s, glide):
    """ศพลุก: floating upright and stiff like a body laid out, hands pressed together on the chest (wai, as the corpse
    is tied with ตราสัง), head bowed, the whole body swaying slowly as one piece; toes hang down"""
    ph = 2*math.pi*t
    P.lift("root", 0.10*s + 0.03*s*math.sin(ph))
    P.rot("hips", 2 + 3*glide, 4*math.sin(ph)*glide, 2.5*math.sin(ph))
    P.rot("spine", 3 + 3*glide, 0, 1.0*math.sin(ph + 0.4)); P.rot("chest", 2, 0, 0.6*math.sin(ph + 0.7))
    twitch = sm(0.62, 0.64, t) - sm(0.68, 0.80, t)
    P.rot("neck", 10, 0, 3*math.sin(ph)); P.rot("head", 14 + 4*twitch, 10*twitch, 4*math.sin(ph + 0.9) - 8*twitch)
    for sd in ("L", "R"):
        arm(P, sd, **AN["PRAY_ARM"]); hand(P, sd, "wai")
    for sd, off in (("L", 0.0), ("R", 0.0)):
        P.rot("thigh." + sd, 2 + 3*math.sin(ph + off)*glide, 0, 0); P.rot("shin." + sd, -4)
        P.rot("foot." + sd, -40); P.rot("toe." + sd, -15)

def c_shroud_idle(P, t, st, s): shroud_body(P, t, s, 0.0)
def c_shroud_glide(P, t, st, s): shroud_body(P, t, s, 1.0)

# แม่นาค: the left arm holds the swaddled baby across the belly (angles found by cradle_search: forearm level across the
# front, clear of the sabai and the belly); the baby (prop) rides the chest bone, so the arm and it keep together
NAK_CRADLE = dict(raise_=-24, fwd=46, bend=100, wrist=-6, twist=26)
NAK_STRETCH = 0.42            # metres (x s) the forearm and the hand each slide out along the arm at full reach
def nak_body(P, t, s, rock=1.0):
    ph = 2*math.pi*t
    P.lift("root", 0.04*s + 0.015*s*math.sin(ph*2))
    P.rot("hips", 2, 0, 3.5*rock*math.sin(ph)); P.rot("spine", 6, 0, -2.0*rock*math.sin(ph)); P.rot("chest", 4)
    arm(P, "L", **NAK_CRADLE); hand(P, "L", "relax", 0.7)
    for sd in ("L", "R"):
        P.rot("thigh." + sd, 2, 0, 1); P.rot("shin." + sd, -6); P.rot("foot." + sd, -34); P.rot("toe." + sd, -16)

def c_nak_cradle(P, t, st, s):
    """กล่อมลูก: floating low, rocking the baby from side to side, head bowed over it, the right arm hanging, swaying"""
    ph = 2*math.pi*t
    nak_body(P, t, s)
    P.rot("neck", 16, -6, 4*math.sin(ph)); P.rot("head", 18, -10 + 4*math.sin(ph + 0.6), 6*math.sin(ph))
    lo = math.degrees(P.lim.get("upper_arm.R", (math.radians(-35),)*6)[0]) + 3
    P.rot("upper_arm.R", lo + 8, 0, -5 - 4*math.sin(ph - 0.9)); P.rot("forearm.R", 0, 0, -14)
    hand(P, "R", "relax")

def c_nak_reach(P, t, st, s):
    """แขนยืด: still holding the baby, she looks up, raises the right arm straight forward and it stretches out to
    about twice its length (forearm and hand slide out along the arm), the fingers clawing, holds, then draws back"""
    ph = 2*math.pi*t
    up = sm(0.08, 0.26, t)*(1 - sm(0.84, 0.98, t)); out = sm(0.24, 0.50, t)*(1 - sm(0.72, 0.90, t))
    nak_body(P, t, s, rock=1 - up)
    P.rot("neck", 16 - 18*up, -6*(1 - up), 0); P.rot("head", 18 - 26*up, -10*(1 - up) + 4*up*math.sin(ph*3), 0)
    lo = math.degrees(P.lim.get("upper_arm.R", (math.radians(-35),)*6)[0]) + 3
    arm(P, "R", raise_=(lo + 8)*(1 - up) + 40*up, fwd=8 + 72*up, bend=14*(1 - up) + 2*up, wrist=-10*up)
    hand(P, "R", "claw" if out > 0.3 else "relax")
    if out > 0.3:                  # clawing: fingers curled at the tips, spread
        for f, sp in (("index", -8), ("middle", -2), ("ring", 4), ("pinky", 10)):
            P.rot(f"{f}_01.R", -20, 0, sp); P.rot(f"{f}_02.R", -45); P.rot(f"{f}_03.R", -40)
    d = NAK_STRETCH*s*out
    P.frame["forearm.R@loc"] = ("loc", Vector((0, d, 0))); P.frame["hand.R@loc"] = ("loc", Vector((0, d, 0)))

def c_kuman_sit(P, t, st, s):
    """กุมารทองบนหิ้ง: sitting on the shelf edge, legs hanging, hands on the knees, still as a statue; then the head
    turns by itself to look at the player, holds, and turns back (StatueHeadTurn)"""
    look = sm(0.30, 0.42, t)*(1 - sm(0.80, 0.92, t))
    P.both("thigh", 88, 0, 6); P.both("shin", -86); P.both("foot", 4)
    P.rot("spine", 2); P.rot("chest", 1)
    P.rot("neck", 2, 16*look, 0); P.rot("head", -4*look, 24*look, 3*look)
    for sd in ("L", "R"):
        arm(P, sd, raise_=-24, fwd=44, bend=40, wrist=-6); hand(P, sd, "relax", 0.8)

def c_kuman_giggle(P, t, st, s):
    """หัวเราะคิกคัก: standing, hands on the belly, shoulders bobbing in quick giggles, head tilting, little bounces"""
    ph = 2*math.pi*t; gg = abs(math.sin(ph*5))*(0.6 + 0.4*math.sin(ph))
    P.rot("spine", 4 + 2*gg); P.rot("chest", 3 + 2*gg); P.both("shoulder", 4*gg)
    P.rot("neck", 4, 0, 6*math.sin(ph)); P.rot("head", 6 - 6*gg, 10*math.sin(ph), 10*math.sin(ph))
    for sd in ("L", "R"):
        arm(P, sd, raise_=-26, fwd=30, bend=58 + 6*gg, wrist=4); hand(P, sd, "relax")
    legs_bounce(P, 6*gg); P.lift("hips", -hip_drop(6*gg, s))

def c_mask_tilt(P, t, st, s):
    """คนขับใส่หน้ากากผีตาโขน: riding, the masked head turns slowly to the player at the side, tilts over, holds
    the stare, then jerks back to the road"""
    AN["c_ride_moto"](P, t, st, s)
    look = sm(0.15, 0.40, t)*(1 - sm(0.82, 0.86, t))
    P.rot("neck", -6 + 4*look, 18*look, 6*look); P.rot("head", -6 + 6*look, 30*look, 18*look)

NEW_CLIPS = {"pillion_hug": (c_pillion_hug, 120), "pillion_look": (c_pillion_look, 180), "tani_peek": (c_tani_peek, 150),
             "coffin_walk": (c_coffin_walk, 60), "dancer_dance": (c_dancer_dance, 360), "dancer_idle": (c_dancer_idle, 150),
             "shroud_idle": (c_shroud_idle, 150), "shroud_glide": (c_shroud_glide, 90), "nak_cradle": (c_nak_cradle, 150),
             "nak_reach": (c_nak_reach, 150), "kuman_sit": (c_kuman_sit, 180), "kuman_giggle": (c_kuman_giggle, 90),
             "mask_tilt": (c_mask_tilt, 150)}
FIXED_TEMPO = {"dancer_dance", "pillion_hug", "pillion_look"}

def make_clips(char, clips, headless=False, stretch=()):
    """only the ghost's own clips stay in the file (the 40 human clips are dropped); `stretch`: bones that also get
    location keys (they slide out along their parent: แม่นาค's arm), in every clip so the others hold them at rest"""
    rig = bpy.data.objects["HumanRig"]; st = AN["STYLE"][char]
    s = (rig.data.bones["head"].tail_local.z - rig.data.bones["hips"].head_local.z)/(1.818 - 0.880)
    for a in list(bpy.data.actions): bpy.data.actions.remove(a)
    P = AN["Poser"](rig); P.raise_max = st.get("raise_max", AN["RAISE_MAX"]); P.headless = headless
    if not rig.animation_data: rig.animation_data_create()
    made = {}
    for name in clips:
        fn, frames = NEW_CLIPS.get(name) or AN["CLIPS"][name]
        act = bpy.data.actions.new(name); act.use_fake_user = True; rig.animation_data.action = act
        n = max(8, round(frames*(1.0 if name in FIXED_TEMPO or name in AN["FIXED_TEMPO"] else st["slow"])))
        for f in range(n + 1):
            fn(P, (f % n)/n, st, s); P.key(f + 1)
            for bn in stretch: rig.pose.bones[bn].keyframe_insert("location", frame=f + 1, group=bn)
        act.frame_range = (1, n + 1)
        try: act.use_cyclic = True
        except AttributeError: pass
        made[name] = n
    rig.animation_data.action = bpy.data.actions[clips[0]]
    sc = bpy.context.scene; sc.render.fps = AN["FPS"]; sc.frame_start, sc.frame_end = 1, made[clips[0]] + 1
    return made

# ---------------------------------------------------------------- hair outside the clothes
def outer_cloth(deps=None):
    """verts / faces of every cloth piece's outside: faces turned away from the nearest skin (a skirt's or strip's
    inner wall faces the body and is left out), in world space for the current frame"""
    body = bpy.data.objects["Body"]
    deps = deps or bpy.context.evaluated_depsgraph_get()
    bm = body.evaluated_get(deps).to_mesh(); mw = body.matrix_world
    bt = BVHTree.FromPolygons([mw @ v.co for v in bm.vertices], [list(p.vertices) for p in bm.polygons])
    body.evaluated_get(deps).to_mesh_clear()
    V, Fs = [], []
    for o in bpy.data.objects:
        if not o.name.startswith("Cloth_") or o.hide_render: continue
        me = o.evaluated_get(deps).to_mesh(); w = o.matrix_world; base = len(V)
        vs = [w @ v.co for v in me.vertices]; V += vs
        for p in me.polygons:
            c = sum((vs[i] for i in p.vertices), Vector())/len(p.vertices)
            n = (w.to_3x3() @ p.normal).normalized()
            loc = bt.find_nearest(c)[0]
            if loc is None or (c - loc).dot(n) > 0: Fs.append([base + i for i in p.vertices])
        o.evaluated_get(deps).to_mesh_clear()
    return V, Fs

def fit_hair(clear=0.022, arms_down=False, swing=0.0):
    """long hair lies over the clothes: every hair vertex below the skull that is inside or too close to the outside of
    a cloth piece (or the skin) is pushed out along that surface's normal. At rest; bind_to_body keeps it there."""
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    for p in rig.pose.bones: p.rotation_mode = 'XYZ'; p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    if rig.animation_data: rig.animation_data.action = None
    if arms_down:                       # arms hanging by the sides as in the ghost clips (hair doesn't follow the arms)
        P_ = AN["Poser"](rig); P_.raise_max = 70; arms_down_(P_, swing)
        for k, (kind, v) in P_.frame.items():
            if kind == "rot": rig.pose.bones[k].rotation_euler = v
    bpy.context.view_layer.update()
    V, Fs = outer_cloth()
    cb = BVHTree.FromPolygons(V, Fs) if Fs else None
    gi = body.vertex_groups["head"].index; me = body.data
    hw = lambda v: next((g.weight for g in v.groups if g.group == gi), 0.0)
    keep = [p for p in me.polygons if sum(hw(me.vertices[i]) for i in p.vertices)/len(p.vertices) < 0.5]
    deps = bpy.context.evaluated_depsgraph_get(); em = body.evaluated_get(deps).to_mesh()
    bb = BVHTree.FromPolygons([body.matrix_world @ v.co for v in em.vertices], [list(p.vertices) for p in keep])
    body.evaluated_get(deps).to_mesh_clear()
    moved = 0; zn = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    for o in bpy.data.objects:
        if not o.name.startswith("Hair_") or o.hide_render: continue
        w = o.matrix_world; wi = w.inverted(); disp = {}
        for v in o.data.vertices:
            p = w @ v.co; p0 = p.copy()
            if p.z > zn: continue                              # on the skull
            for tree, c in ((bb, clear*0.8), (cb, clear)):
                if tree is None: continue
                loc, n, _, d = tree.find_nearest(p, 0.08)
                if loc is None: continue
                side = (p - loc).dot(n)
                if side < c: p = p + n*(c - side)
            if (p - p0).length > 1e-5: disp[v.index] = wi.to_3x3() @ (p - p0); moved += 1
        # spread each push over the neighbouring hair (a soft bulge, not single spikes the cloth pokes out between)
        nb = [[] for _ in o.data.vertices]
        for e in o.data.edges: a_, c_ = e.vertices; nb[a_].append(c_); nb[c_].append(a_)
        for _ in range(4):
            new = dict(disp)
            for i, dv in disp.items():
                for j in nb[i]:
                    sp = dv*0.6
                    if j not in new or new[j].length < sp.length: new[j] = sp
            disp = new
        for i, dv in disp.items(): o.data.vertices[i].co += dv
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    return moved

def tuck_hair(s):
    """long hair hangs behind the arms: below the shoulders, hair out at the sides where the arms hang (|x| past the
    side of the chest) is moved back behind the arms, so the arms swing and reach in front of the curtain, not
    through it. Hair over the back and down the front of the chest is left where it is."""
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]; mw = rig.matrix_world
    xs = abs((mw @ rig.data.bones["upper_arm.L"].head_local).x)
    zs = (mw @ rig.data.bones["upper_arm.L"].head_local).z
    zc = (mw @ rig.data.bones["chest"].head_local).z
    zh = (mw @ rig.data.bones["hips"].head_local).z
    bv = np.array([tuple(body.matrix_world @ v.co) for v in body.data.vertices])
    yb = float(bv[(bv[:, 2] > zc) & (bv[:, 2] < zs) & (np.abs(bv[:, 0]) < xs*0.6), 1].max())     # back of the chest
    moved = 0
    for o in bpy.data.objects:
        if not o.name.startswith("Hair_") or o.hide_render: continue
        w = o.matrix_world; wi = w.inverted()
        for v in o.data.vertices:
            p = w @ v.co
            k = sm(xs - 0.09*s, xs - 0.03*s, abs(p.x))*sm(zs + 0.02*s, zs - 0.06*s, p.z)*sm(zh - 0.12*s, zh + 0.06*s, p.z)   # where the arms hang
            if k <= 0: continue
            y = yb + 0.035*s
            if p.y < y: p.y = p.y + (y - p.y)*k; v.co = wi @ p; moved += 1
    return moved

def arms_down_(P, swing=0.0):
    lo = math.degrees(P.lim.get("upper_arm.L", (math.radians(-35),)*6)[0]) + 3
    P.rot("upper_arm.L", lo + 6, 0, -swing); P.rot("upper_arm.R", lo + 6, 0, -swing)
    P.rot("forearm.L", 0, 0, -8); P.rot("forearm.R", 0, 0, -8)

# ---------------------------------------------------------------- headless: neck stump + blood on the skin
def head_faces(body):
    gi = body.vertex_groups["head"].index; me = body.data
    hw = lambda vi: next((g.weight for g in me.vertices[vi].groups if g.group == gi), 0.0)
    return {p.index for p in me.polygons if sum(hw(v) for v in p.vertices)/len(p.vertices) > 0.5}

def neck_stump(body, rig, s):
    """the cut: flesh, the white neck bone at the back, the dark windpipe at the front; a domed cap over the hole the
    head leaves, its rim on the Body's cut edge (same weights), bound to `neck`. Its own small texture."""
    me = body.data; hf = head_faces(body)
    cnt = {}
    for p in me.polygons:
        if p.index in hf: continue
        vs = list(p.vertices)
        for k in range(len(vs)):
            e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)]))); cnt[e] = cnt.get(e, 0) + 1
    nbr = {}
    for p in me.polygons:
        if p.index not in hf: continue
        vs = list(p.vertices)
        for k in range(len(vs)):
            e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)])))
            if e in cnt and cnt[e] == 1: nbr.setdefault(e[0], []).append(e[1]); nbr.setdefault(e[1], []).append(e[0])
    # the longest loop of edges between head and neck
    seen, loops = set(), []
    for v0 in nbr:
        if v0 in seen: continue
        loop = [v0]; seen.add(v0); prev, cur = None, v0
        while True:
            nx = [n for n in nbr[cur] if n != prev and n not in seen]
            if not nx: break
            prev, cur = cur, nx[0]; loop.append(cur); seen.add(cur)
        loops.append(loop)
    loop = max(loops, key=len)
    mw = body.matrix_world; P = [mw @ me.vertices[i].co for i in loop]
    nb = rig.data.bones["neck"]; U = (rig.matrix_world.to_3x3() @ (nb.tail_local - nb.head_local)).normalized()
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); L = U.cross(F)
    c = sum(P, Vector())/len(P)
    R_ = max(((p - c) - U*(p - c).dot(U)).length for p in P)
    def uv(p):
        d = p - c; return (0.5 + 0.48*d.dot(L)/R_, 0.5 + 0.48*d.dot(F)/R_)
    msh = CL["Mesh"]()
    def bw(vi):
        g = {body.vertex_groups[x.group].name: x.weight for x in me.vertices[vi].groups if x.weight > 0}
        tot = sum(g.values()) or 1; return {k: w/tot for k, w in g.items()}
    rim = [msh.vert(p, bw(i)) for p, i in zip(P, loop)]
    mid = [msh.vert(c + (p - c)*0.62 + U*0.006*s, {"neck": 1.0}) for p in P]
    cen = msh.vert(c + U*0.010*s, {"neck": 1.0})
    n = len(P)
    # wind the cap so it faces up (away from the neck)
    a, b_ = P[0] - c, P[1] - c; flip = a.cross(b_).dot(U) < 0
    for k in range(n):
        k2 = (k + 1) % n
        q = [rim[k], rim[k2], mid[k2], mid[k]]; quv = [uv(P[k]), uv(P[k2]), uv(c + (P[k2] - c)*0.62), uv(c + (P[k] - c)*0.62)]
        if flip: q, quv = q[::-1], quv[::-1]
        msh.face(q, quv)
        t = [mid[k], mid[k2], cen]; tuv = [uv(c + (P[k] - c)*0.62), uv(c + (P[k2] - c)*0.62), (0.5, 0.5)]
        if flip: t, tuv = t[::-1], tuv[::-1]
        msh.face(t, tuv)
    # texture: polar layout, front (-Y) = v < 0.5
    N_ = 256; xx = (np.arange(N_) + 0.5)/N_; X, Y = np.meshgrid(xx, xx)
    dx, dy = (X - 0.5)/0.48, (Y - 0.5)/0.48; r = np.hypot(dx, dy)
    nz = CL["fbm"](X*12, Y*12, oct=3, seed=120)
    col = np.ones((N_, N_, 3))*np.array((0.50, 0.08, 0.08))*(0.7 + 0.5*nz)[..., None]
    col = CL["mix"](col, (0.25, 0.02, 0.03), CL["sstep"](0.75, 0.95, r))                       # dark clotted rim
    col = CL["mix"](col, (0.62, 0.18, 0.16), (CL["fbm"](X*30, Y*30, oct=2, seed=121) > 0.62)*(r < 0.8)*0.6)   # muscle fibres
    bone = np.hypot(dx, dy - 0.34) < 0.17                                                     # neck vertebra at the back
    col = CL["mix"](col, (0.86, 0.82, 0.70), bone); col = CL["mix"](col, (0.55, 0.35, 0.25), np.hypot(dx, dy - 0.34) < 0.07)
    pipe = np.abs(np.hypot(dx, dy + 0.42) - 0.12) < 0.04                                      # windpipe ring, dark inside
    col = CL["mix"](col, (0.80, 0.62, 0.58), pipe); col = CL["mix"](col, (0.05, 0.01, 0.01), np.hypot(dx, dy + 0.42) < 0.085)
    hgt = 0.0006*bone - 0.0008*(np.hypot(dx, dy + 0.42) < 0.085) + 0.0003*nz
    os.makedirs(GH, exist_ok=True); base = os.path.join(GH, "neck_stump")
    CL["save_png"](col, base + "_Color.png", False); CL["save_png"](CL["normal_from_height"](hgt, 900, 900), base + "_Normal.png", True)
    CL["save_png"](np.clip(0.25 + 0.4*bone + 0.1*nz, 0, 1), base + "_Roughness.png", True)
    mat = CL["tex_material"]("NeckStump", base)
    ob = msh.to_object("NeckStump", rig, mat, fix_normals=False)
    return ob

def blood_skin(body, rig, char, s):
    """a copy of the ghost skin with blood from the cut neck: soaked round the neck, runs down the chest, shoulders and
    back in streaks (the part above the outfit; the cloth has its own, build_clothes ghost_shell neck)"""
    mat = bpy.data.materials["SkinGhost"]; nm = mat.copy(); nm.name = "SkinGhostHeadless"
    b = CL["Body"](body, rig); uvl = np.zeros((len(body.data.loops), 2)); body.data.uv_layers.active.data.foreach_get("uv", uvl.ravel())
    Pw, Nn, Fi = CL["raster_body"](b, uvl); x, y, z = Pw[..., 0], Pw[..., 1], Pw[..., 2]
    hf = head_faces(body)
    cut_z = min((body.matrix_world @ body.data.vertices[i].co).z for f in hf for i in body.data.polygons[f].vertices)
    run = cut_z - z
    cols = CL["fbm"](x/s*26 + 0.5*CL["fbm"](z/s*8, x/s*2, oct=2, seed=131), np.zeros_like(x), oct=2, seed=130)
    L = (0.06 + 0.26*CL["fbm"](x/s*9 + 3.0*(y > 0), np.zeros_like(x), oct=2, seed=132))*s
    stream = CL["sstep"](0.56, 0.62, cols)*CL["sstep"](L, L - 0.04*s, run)*(run > -0.01*s)
    soak = CL["sstep"](0.05*s, 0.0, run + 0.04*s*CL["fbm"](x*30, y*30, oct=2, seed=133))*(run > -0.02*s)
    wet = np.clip(stream + soak, 0, 1)*(Fi >= 0)
    imgs = {}
    for nd in nm.node_tree.nodes:
        if nd.type == 'TEX_IMAGE' and nd.image:
            imgs[nd.image.name] = nd
    out = os.path.join(GH, "ghost_headless_Skin")
    for nd in list(imgs.values()):
        im = nd.image; fp = bpy.path.abspath(im.filepath)
        arr = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(arr)
        a = arr.reshape(im.size[1], im.size[0], 4)[..., :3].astype(np.float64)
        if a.shape[:2] != wet.shape:
            continue
        if fp.endswith("_Color.png"):
            tone = CL["fbm"](x*40, y*40, z*40, oct=2, seed=134)
            a = CL["mix"](a, CL["BLOOD_OLD"], wet*0.9); a = CL["mix"](a, CL["BLOOD"], wet*CL["sstep"](0.4, 0.7, tone)*0.7); suf = "_Color"
        elif fp.endswith("_Roughness.png"): a = a*(1 - 0.5*wet[..., None]); suf = "_Roughness"
        else: continue
        CL["save_png"](a, out + suf + ".png", suf != "_Color")
        ni = bpy.data.images.load(out + suf + ".png"); ni.colorspace_settings.name = im.colorspace_settings.name; nd.image = ni
    body.data.materials[0] = nm

def porcelain_face(body, rig, char, s):
    """ผีนางรำ: the ghost skin paled to grey-white, the eyes blank white (no iris), dark blue-black cracks running from
    the eyes down the cheeks like broken porcelain, the dark streaks of the ghost skin taken off, dark red lips"""
    mat = bpy.data.materials["SkinGhost"]; nm = mat.copy(); nm.name = "SkinGhostPorcelain"
    meta = json.load(open(os.path.join(CL["char_dir"](char), CL["NAMES"][char] + "_uv.json")))
    b = CL["Body"](body, rig); uvl = np.zeros((len(body.data.loops), 2)); body.data.uv_layers.active.data.foreach_get("uv", uvl.ravel())
    Pw, Nn, Fi = CL["raster_body"](b, uvl)
    hw = b.w[:, b.names.index("head")]; hv = b.co[hw > 0.99]; C = (hv.min(0) + hv.max(0))/2
    hb = rig.data.bones["head"]; rw = rig.matrix_world
    U = np.array((rw @ hb.tail_local - rw @ hb.head_local).normalized()); F = np.array((0, -1, 0)) - U*(-U[1]); F /= np.linalg.norm(F)
    L = np.cross(U, F)
    d = Pw - C; f = d @ F; l = d @ L; h = d @ U; az = np.arctan2(l, f)
    RF = meta["RF"]; X = az*RF; Y = h; ey, my = meta["eye_h"], meta["mouth_h"]; sm_ = CL["sstep"]; mix = CL["mix"]
    face = (Fi >= 0) & (np.abs(az) < math.radians(85)) & (h > meta["chin_h"] - 0.01*s) & (h < meta["top_h"] + 0.05*s)
    nd = next(n for n in nm.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image and bpy.path.abspath(n.image.filepath).endswith("_Color.png"))
    im = nd.image; a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    col = a.reshape(im.size[1], im.size[0], 4)[..., :3].astype(np.float64)
    lum = col.mean(-1)
    pale = np.array((0.80, 0.80, 0.79))
    col = col*0.5 + pale*0.5                                                     # pale grey-white all over
    ex, es = 0.032*s, s*1.06
    stain = face*(lum < 0.30)*(Y < ey - 0.006*s)*(np.abs(X) > 0.010*s)*(np.hypot(X/0.024, (Y - my)/0.012) > 1.3)
    col = mix(col, pale*0.97, stain*0.95)                                        # the old black streaks under the eyes go
    # blank white eyes with a thin grey lid line
    e = np.hypot((np.abs(X) - ex)/(0.0155*es), (Y - ey)/(0.0062*es))
    col = mix(col, (0.93, 0.93, 0.91), face*sm_(1.05, 0.85, e)); col = mix(col, (0.30, 0.30, 0.32), face*(np.abs(e - 1.0) < 0.12)*0.8)
    # cracks: random walks from round each eye, mostly down the cheek, branching; a dark core with a blue halo
    rnd = np.random.RandomState(21); segs = []
    for sx in (1, -1):
        for k in range(7):
            ang = math.radians(rnd.uniform(-160, -20)) if k < 6 else math.radians(rnd.uniform(-10, 10))
            x0 = sx*(ex + math.cos(ang)*0.0165*es); y0 = ey + math.sin(ang)*0.0068*es; n = rnd.randint(7, 12)
            def walk(x, y, a_, n, w):
                for _ in range(n):
                    a_ += rnd.uniform(-0.5, 0.5); a_ += (-math.pi/2 - a_)*0.15 if k < 6 else 0.0; L_ = rnd.uniform(0.005, 0.009)*s
                    x2, y2 = x + sx*math.cos(a_)*L_, y + math.sin(a_)*L_
                    segs.append((x, y, x2, y2, w)); x, y = x2, y2
                    if rnd.rand() < 0.25 and w > 0.0006*s: walk(x, y, a_ + rnd.choice((-0.9, 0.9)), max(1, n//2), w*0.6)
                    w *= 0.85
            walk(x0, y0, ang, n, 0.0013*s)
    dist = np.full(X.shape, 9.0); wid = np.full(X.shape, 0.001)
    box = face & (Y < ey + 0.05*s) & (Y > ey - 0.11*s) & (np.abs(X) < 0.09*s)
    Xb, Yb = X[box], Y[box]; db = np.full(Xb.shape, 9.0); wb = np.full(Xb.shape, 0.001)
    for x0, y0, x1, y1, w in segs:
        dx, dy = x1 - x0, y1 - y0; ll = dx*dx + dy*dy or 1e-12
        tt = np.clip(((Xb - x0)*dx + (Yb - y0)*dy)/ll, 0, 1)
        dd = np.hypot(Xb - x0 - tt*dx, Yb - y0 - tt*dy)/w
        m_ = dd < db; db[m_] = dd[m_]; wb[m_] = w
    dist[box] = db
    col = mix(col, (0.32, 0.38, 0.52), face*sm_(3.5, 1.2, dist)*0.55)
    col = mix(col, (0.05, 0.07, 0.15), face*sm_(1.0, 0.5, dist))
    # dark red lips
    lip = np.hypot(X/(0.022*s), np.where(Y > my, (Y - my)/(0.0065*s), (my - Y)/(0.0075*s)))
    col = mix(col, (0.36, 0.04, 0.06), face*sm_(1.05, 0.85, lip)); col = mix(col, (0.18, 0.02, 0.03), face*(np.abs(Y - my) < 0.0009*s)*(lip < 1.0))
    out = os.path.join(GH, "ghost_dancer_Skin_Color.png"); CL["save_png"](col, out, False)
    ni = bpy.data.images.load(out); nd.image = ni
    body.data.materials[0] = nm

# ---------------------------------------------------------------- props (rigid pieces on one bone) and the gold skin
def head_frame(body, rig):
    """the head frame of build_skin / porcelain_face: C = centre of the head's bounding box, U = up the head bone,
    F = forward (-Y) square to U, L = U x F (the character's left)"""
    b = CL["Body"](body, rig)
    hv = b.co[b.w[:, b.names.index("head")] > 0.99]; C = (hv.min(0) + hv.max(0))/2
    hb = rig.data.bones["head"]; rw = rig.matrix_world
    U = np.array((rw @ hb.tail_local - rw @ hb.head_local).normalized())
    F = np.array((0, -1.0, 0)) - U*(-U[1]); F /= np.linalg.norm(F); L = np.cross(U, F)
    return b, Vector(C), Vector(U), Vector(F), Vector(L), hv

def uv_meta(char):
    d = json.load(open(os.path.join(CL["char_dir"](char), CL["NAMES"][char] + "_uv.json")))
    return {k: v for k, v in d.items() if k != "uv"}

def _face(msh, ids, uvs, out):
    """a face wound so its normal points along `out`"""
    P_ = [msh.v[i] for i in ids]; n = (P_[1] - P_[0]).cross(P_[2] - P_[0])
    if n.dot(out) < 0: ids, uvs = list(ids)[::-1], list(uvs)[::-1]
    msh.face(ids, uvs)

def _grid_faces(msh, rows, uvs, out_fn, wrap=False):
    """quads between rows of vertex ids (rows[i][j]); uvs[i][j] per corner; out_fn(i, j) = outward direction"""
    for i in range(len(rows) - 1):
        n = len(rows[i]) - (0 if wrap else 1)
        for j in range(n):
            j2 = (j + 1) % len(rows[i])
            _face(msh, [rows[i][j], rows[i + 1][j], rows[i + 1][j2], rows[i][j2]],
                  [uvs[i][j], uvs[i + 1][j], uvs[i + 1][j + 1 if wrap else j2], uvs[i][j + 1 if wrap else j2]], out_fn(i, j))

def jaw_tie(body, rig, char, s):
    """ผ้าผูกคาง of a laid-out body: a white cloth band from the top of the head, down in front of the ears and
    under the chin, bound to the head. Its loop tilts forward at the bottom so it passes under the jaw, not the neck."""
    b, C, U, F, L, hv = head_frame(body, rig); s = b.s
    c0 = C + F*0.042*s - U*0.010*s                                   # in front of the ears
    n = 48; w = 0.044*s; th = 0.0035*s
    dirs, rad = [], []
    for k in range(n):
        ph = 2*math.pi*k/n
        tilt = math.radians(16 + 22*(1 - math.cos(ph))/2)                  # 16 deg back at the top, 38 forward under the chin
        up = U*math.cos(tilt) - F*math.sin(tilt)
        d = (up*math.cos(ph) + L*math.sin(ph)).normalized(); dirs.append(d)
        best = 0.0
        for off in np.linspace(-w*0.6, w*0.6, 7):                        # over the width of the band
            nrm_ = L.cross(up).normalized(); o = c0 + nrm_*off
            hit = b.bvh.ray_cast(o, d, 0.4*s)                               # leaving the head from inside
            if hit[0] is not None: best = max(best, (hit[0] - o).dot(d))
            if abs(math.sin(ph)) > 0.5:                                    # the sides: clear of the ears too
                hit = b.bvh.ray_cast(o + d*0.16*s, -d, 0.16*s)
                if hit[0] is not None: best = max(best, (hit[0] - o).dot(d))
        rad.append(best + (0.008 + 0.006*(1 - math.cos(ph))/2)*s)
    rad = [max(rad[k], (rad[k - 1] + rad[(k + 1) % n])/2) for k in range(n)]
    P = [c0 + d*r for d, r in zip(dirs, rad)]
    msh = CL["Mesh"](); W = {"head": 1.0}; rows = [[], [], [], []]; acc = [0.0]
    for k in range(n): acc.append(acc[-1] + (P[(k + 1) % n] - P[k]).length)
    for k in range(n):
        T = (P[(k + 1) % n] - P[k - 1]).normalized(); Nb = T.cross(dirs[k]).normalized()
        for r_, (o, din) in enumerate(((Nb*(-w/2), 0), (Nb*(w/2), 0), (Nb*(w/2), th), (Nb*(-w/2), th))):
            rows[r_].append(msh.vert(P[k] + o - dirs[k]*din, W))
    def uv(r_, k): return (acc[k]/CL["TILE"], 1.0 if r_ in (1, 2) else 0.0)
    for k in range(n):
        k2 = (k + 1) % n; kk = k + 1; out = dirs[k]
        _face(msh, [rows[0][k], rows[1][k], rows[1][k2], rows[0][k2]], [uv(0, k), uv(1, k), uv(1, kk), uv(0, kk)], out)
        _face(msh, [rows[3][k], rows[2][k], rows[2][k2], rows[3][k2]], [uv(0, k), uv(1, k), uv(1, kk), uv(0, kk)], -out)
        Nb = (P[k2] - P[k - 1]).cross(dirs[k]).normalized()
        _face(msh, [rows[1][k], rows[2][k], rows[2][k2], rows[1][k2]], [uv(1, k)]*2 + [uv(1, kk)]*2, Nb)
        _face(msh, [rows[0][k], rows[3][k], rows[3][k2], rows[0][k2]], [uv(0, k)]*2 + [uv(0, kk)]*2, -Nb)
    pat = "ghost_sabai_white"
    mat = CL["tex_material"]("Cloth_" + pat, os.path.join(CL["TEX"], pat))
    return msh.to_object("Prop_JawTie", rig, mat, fix_normals=False)

def _posed_trees(objs, deps):
    out = []
    for o in objs:
        V, F_, _ = _mesh(o, deps); out.append(BVHTree.FromPolygons(V, F_))
    return out

def baby(body, rig, char, s, clip="nak_cradle"):
    """แม่นาค's baby: a swaddled bundle lying on her left forearm (at frame 1 of `clip`), pushed forward / up until it is
    1.2 cm clear of her arm, body, clothes and hair; bound to the chest bone (the cradling arm moves with the chest)"""
    sc = bpy.context.scene; mw = rig.matrix_world; pb = rig.pose.bones
    rig.animation_data.action = bpy.data.actions[clip]; sc.frame_set(1); bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    e = mw @ pb["forearm.L"].head; wr = mw @ pb["hand.L"].head
    ax = (e - wr).normalized()                                       # the head end lies towards the elbow
    side = ax.cross(Vector((0, 0, 1))).normalized(); upv = side.cross(ax).normalized()
    if upv.z < 0: upv = -upv; side = -side
    A, R1, R2 = 0.19*s, 0.080*s, 0.070*s
    nr, ns_ = 14, 16
    def shape(c):
        pts = []
        for i in range(nr + 1):
            th = math.pi*i/nr; rr = math.sin(th)
            for j in range(ns_):
                ph = 2*math.pi*j/ns_
                pts.append(c + ax*A*math.cos(th) + (side*R1*math.cos(ph) + upv*R2*math.sin(ph))*rr*(1 + 0.06*math.cos(2*th)))
        return pts
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and not o.hide_render and (o.name == "Body" or o.name.startswith(("Cloth_", "Hair_")))]
    trees = _posed_trees(objs, deps)
    c = (e + wr)/2 + upv*(0.035*s + R2 + 0.012*s)
    for it in range(80):
        worst = 9.0
        for p in shape(c):
            for tr in trees:
                loc, nrm, _, d = tr.find_nearest(p, 0.05)
                if loc is None: continue
                d = d if (p - loc).dot(nrm) > 0 else -d
                worst = min(worst, d)
        if worst > 0.012*s: break
        c = c + Vector((0, -0.005*s, 0.0015*s))                       # forward (away from the body), a little up
    # build at the posed place, then move into the rest pose of the chest bone
    Mp = mw @ pb["chest"].matrix; Mr = mw @ rig.data.bones["chest"].matrix_local; T = Mr @ Mp.inverted()
    msh = CL["Mesh"](); W = {"chest": 1.0}; pts = shape(c)
    ids = [[msh.vert(T @ pts[i*ns_ + j], W) for j in range(ns_)] for i in range(nr + 1)]
    cc = T @ c
    for i in range(nr):
        for j in range(ns_):
            j2 = (j + 1) % ns_
            q = [ids[i][j], ids[i + 1][j], ids[i + 1][j2], ids[i][j2]]
            quv = [(j/ns_, i/nr), (j/ns_, (i + 1)/nr), ((j + 1)/ns_, (i + 1)/nr), ((j + 1)/ns_, i/nr)]
            ctr = sum((msh.v[x] for x in q), Vector())/4
            _face(msh, q, quv, ctr - cc)
    # texture: u round the bundle (0.25 = up), v from the head end (0) to the feet (1)
    N_ = 256; xx = (np.arange(N_) + 0.5)/N_; X, Y = np.meshgrid(xx, xx)
    wrapb = ((Y*5 + X*1.0) % 1.0)
    col = np.ones((N_, N_, 3))*np.array((0.74, 0.68, 0.56))*(0.86 + 0.14*wrapb)[..., None]
    col = CL["mix"](col, (0.45, 0.40, 0.32), CL["sstep"](0.06, 0.0, wrapb)*0.7)
    col = CL["mix"](col, CL["DIRT"], 0.45*CL["sstep"](0.55, 0.8, CL["fbm"](X*6, Y*6, oct=3, seed=150, period=6)))
    col = CL["mix"](col, (0.25, 0.20, 0.14), 0.7*CL["sstep"](0.72, 0.76, CL["fbm"](X*5, Y*5, oct=3, seed=151, period=5)))   # dark old stains (no blood)
    fx, fy = (X - 0.25)/0.10, (Y - 0.10)/0.075; face = np.hypot(fx, fy)            # the little face, looking up
    col = CL["mix"](col, (0.10, 0.08, 0.07), CL["sstep"](1.35, 1.1, face))           # hood shadow
    col = CL["mix"](col, (0.56, 0.60, 0.62), CL["sstep"](1.05, 0.9, face))           # grey-blue dead skin
    for sx in (-1, 1):
        col = CL["mix"](col, (0.12, 0.10, 0.12), (np.abs(fy + 0.15) < 0.10)*(np.abs(fx - sx*0.38) < 0.22))   # closed eyes
    col = CL["mix"](col, (0.25, 0.10, 0.12), np.hypot(fx/0.25, (fy - 0.45)/0.10) < 1)  # mouth
    hgt = 0.0006*wrapb - 0.0004*(face < 1.0)
    base = os.path.join(GH, "nak_baby"); os.makedirs(GH, exist_ok=True)
    CL["save_png"](col, base + "_Color.png", False); CL["save_png"](CL["normal_from_height"](hgt, 700, 700, wrap=True), base + "_Normal.png", True)
    CL["save_png"](np.clip(0.85 - 0.2*(face < 1), 0, 1), base + "_Roughness.png", True)
    ob = msh.to_object("Prop_Baby", rig, CL["tex_material"]("NakBaby", base), fix_normals=False)
    sc.frame_set(1)
    return ob

def ta_khon_mask(body, rig, char, s):
    """หน้ากากผีตาโขน (ref: art_refs/ghosts/phi_ta_khon): a painted face plate over the whole face, pointed below the
    chin, with a long curved nose, the หวด (rice-steamer basket) flaring up on top, patchwork cloth round the back of
    the head; black soot and rust stains running down from the eye holes (no blood: Roblox moderation). Bound to
    `head`; texture ta_khon_mask_*."""
    b, C, U, F, L, hv = head_frame(body, rig); s = b.s; meta = uv_meta(char)
    hcrown = float(max((Vector(p) - C).dot(U) for p in hv))
    chin, ey, my = meta["chin_h"], meta["eye_h"], meta["mouth_h"]
    Hmin, Hcap = chin - 0.13*s, hcrown - 0.03*s
    def hbot(a):
        aa = abs(a); r40, r110 = math.radians(40), math.radians(110)
        if aa < r40: return chin - 0.13*s*(1 - aa/r40)
        if aa < r110: return chin + 0.040*s*CL["sst"](r40, r110, aa)
        return chin + 0.040*s + 0.015*s*CL["sst"](r110, math.pi, aa)
    def dir_(a): return F*math.cos(a) + L*math.sin(a)
    hs = np.linspace(chin, hcrown + 0.02*s, 44)
    nA, nV = 48, 26; A = np.linspace(-math.pi, math.pi, nA + 1)[:-1]
    prof = {}
    for a in A:                                      # outermost skin (ears included) along each direction and height,
        d = dir_(a); rs = []                         # over the width of the column (an ear can sit between two)
        for h in hs:
            o = C + U*h; best = 0.0
            for da in (-0.07, -0.035, 0.0, 0.035, 0.07):
                d_ = dir_(a + da); hit = b.bvh.ray_cast(o + d_*0.3*s, -d_, 0.3*s)
                if hit[0] is not None: best = max(best, (hit[0] - o).dot(d))
            rs.append(best)
        prof[a] = np.array(rs)
    def r_at(a, h):
        rs = prof[a]; k = hs >= min(h, hs[-1]) - 1e-9
        k &= hs <= max(h, chin) + 0.03*s
        base_ = float(rs[k].max()) if k.any() else float(rs.max())
        return base_ + 0.022*s + 0.016*s*CL["sst"](chin, chin - 0.13*s, h)*max(0.0, math.cos(a))   # the point leans out
    R = np.array([[r_at(a, hbot(a) + (Hcap - hbot(a))*j/(nV - 1)) for a in A] for j in range(nV)])
    R = np.maximum(R, (np.roll(R, 1, 1) + np.roll(R, -1, 1))/2)      # no dents between the columns
    msh = CL["Mesh"](); W = {"head": 1.0}; INNER = (0.75, 0.955)
    def hj(i, j): return hbot(A[i]) + (Hcap - hbot(A[i]))*j/(nV - 1)
    outer = [[msh.vert(C + U*hj(i, j) + dir_(A[i])*R[j, i], W) for i in range(nA)] for j in range(nV)]
    inner = [[msh.vert(C + U*hj(i, j) + dir_(A[i])*(R[j, i] - 0.006*s), W) for i in range(nA)] for j in range(nV)]
    VM = 0.64
    def uvo(j, i): return ((A[i % nA] + (2*math.pi if i == nA else 0))/(2*math.pi) + 0.5, VM*(hj(i % nA, j) - Hmin)/(Hcap - Hmin))
    uvO = [[uvo(j, i) for i in range(nA + 1)] for j in range(nV)]; uvI = [[INNER]*(nA + 1) for _ in range(nV)]
    _grid_faces(msh, outer, uvO, lambda j, i: dir_(A[i]), wrap=True)
    _grid_faces(msh, inner, uvI, lambda j, i: -dir_(A[i]), wrap=True)
    for i in range(nA):                                               # rim along the bottom edge
        i2 = (i + 1) % nA
        _face(msh, [outer[0][i], outer[0][i2], inner[0][i2], inner[0][i]], [uvO[0][i], uvO[0][i + 1], INNER, INNER], -U)
    # the top closed under the basket: a dome over the crown, each ring clear of the skull at its height
    prev, prev_r = outer[-1], R[-1]
    for hk in np.linspace(Hcap, hcrown + 0.020*s, 5)[1:]:
        rr = []
        for i, a in enumerate(A):
            k = hs >= hk - 0.004*s; r0 = (float(prof[a][k].max()) if k.any() else 0.0) + 0.022*s
            rr.append(min(max(r0, 0.25*prev_r[i]), prev_r[i]))
        ring = [msh.vert(C + U*hk + dir_(A[i])*rr[i], W) for i in range(nA)]
        for i in range(nA):
            i2 = (i + 1) % nA
            _face(msh, [prev[i], prev[i2], ring[i2], ring[i]], [INNER]*4, U + dir_(A[i])*0.3)
        prev, prev_r = ring, np.array(rr)
    ctop = msh.vert(C + U*(hcrown + 0.026*s), W)
    for i in range(nA):
        _face(msh, [prev[i], prev[(i + 1) % nA], ctop], [INNER]*3, U)
    # หวด: flaring basket on top, a lathe round the head axis, walls with a rim at the top
    rb = float(R[-1].max()) + 0.004*s; z0 = Hcap - 0.012*s
    bprof = [(rb, 0.0), (rb + 0.012*s, 0.05*s), (0.130*s, 0.11*s), (0.180*s, 0.17*s), (0.225*s, 0.225*s), (0.245*s, 0.245*s)]
    nb_ = 40; Bo, Bi = [], []
    for r_, z_ in bprof:
        Bo.append([msh.vert(C + U*(z0 + z_) + dir_(2*math.pi*k/nb_)*r_, W) for k in range(nb_)])
        Bi.append([msh.vert(C + U*(z0 + z_ + 0.002*s) + dir_(2*math.pi*k/nb_)*(r_ - 0.007*s), W) for k in range(nb_)])
    uvB = [[(k/nb_, 0.66 + 0.24*q/(len(bprof) - 1)) for k in range(nb_ + 1)] for q in range(len(bprof))]
    def bout(q, k):
        a = 2*math.pi*k/nb_; dr = bprof[min(q + 1, len(bprof) - 1)][0] - bprof[q][0]; dz = bprof[min(q + 1, len(bprof) - 1)][1] - bprof[q][1]
        return dir_(a)*dz - U*dr if (dr or dz) else dir_(a)
    _grid_faces(msh, Bo, uvB, bout, wrap=True)
    _grid_faces(msh, Bi, [[INNER]*(nb_ + 1) for _ in bprof], lambda q, k: -bout(q, k), wrap=True)
    for k in range(nb_):
        k2 = (k + 1) % nb_
        _face(msh, [Bo[-1][k], Bo[-1][k2], Bi[-1][k2], Bi[-1][k]], [uvB[-1][k], uvB[-1][k + 1], INNER, INNER], U)
        _face(msh, [Bo[0][k], Bo[0][k2], Bi[0][k2], Bi[0][k]], [INNER]*4, -U)
    # the long nose: from the bridge, down and out, the end curling forward
    j0 = int(round((meta["tip_h"] + 0.010*s - hbot(0.0))/(Hcap - hbot(0.0))*(nV - 1)))
    i0 = int(np.argmin(np.abs(A)))
    nb0 = C + U*hj(i0, j0) + F*(R[j0, i0] + 0.004*s)             # the base ring stands on the plate, clear of the nose
    npts = [nb0 + F*(0.022*s*t + 0.030*s*t*t + 0.020*s*CL["sst"](0.7, 1.0, t)) - U*(0.19*s*t) for t in np.linspace(0, 1, 11)]
    nrad = [0.017*s*(1 - t)**0.7 + 0.0035*s for t in np.linspace(0, 1, 11)]
    nk = 8; NR = []
    for q, p in enumerate(npts):
        T = (npts[min(q + 1, 10)] - npts[max(q - 1, 0)]).normalized(); n1 = L; n2 = T.cross(L).normalized()
        NR.append([msh.vert(p + (n1*math.cos(2*math.pi*k/nk) + n2*math.sin(2*math.pi*k/nk))*nrad[q]*(1.0 if k % 4 else 1.0), W) for k in range(nk)])
    uvN = [[(0.5*k/nk, 0.92 + 0.06*q/10) for k in range(nk + 1)] for q in range(11)]
    _grid_faces(msh, NR, uvN, lambda q, k: (msh.v[NR[q][k]] - npts[q]), wrap=True)
    tipv = msh.vert(npts[-1] + (npts[-1] - npts[-2]).normalized()*0.004*s, W)
    for k in range(nk): _face(msh, [NR[-1][k], NR[-1][(k + 1) % nk], tipv], [uvN[-1][k], uvN[-1][k + 1], (0.25, 0.985)], npts[-1] - npts[-2])
    # ---- texture
    N_ = 1024; xx = (np.arange(N_) + 0.5)/N_; Uu, Vv = np.meshgrid(xx, xx)
    mix, sst_, fbm = CL["mix"], CL["sstep"], CL["fbm"]
    col = np.zeros((N_, N_, 3)); hgt = np.zeros((N_, N_)); rgh = np.full((N_, N_), 0.6)
    GOLD = (0.78, 0.60, 0.24); RED = (0.66, 0.08, 0.06); BLK = (0.03, 0.025, 0.02)
    # helmet: a round the head (0 = front), h up the head axis
    a = (Uu - 0.5)*2*math.pi; h = Hmin + Vv/VM*(Hcap - Hmin); hel = Vv <= VM + 0.004
    RFm = float(np.median(R[nV//2, np.abs(A) < 0.6])); X = a*RFm; Y = h; aa = np.abs(a)
    hb_ = np.vectorize(hbot)(a)
    c = np.ones((N_, N_, 3))*np.array((0.87, 0.84, 0.75))*(0.90 + 0.12*fbm(X*40, Y*40, oct=3, seed=160))[..., None]
    # patchwork cloth round the back of the head
    back = aa > math.radians(104)
    band = np.floor((Y - Hmin)/(0.032*s) + 0.25*np.sin(a*3)).astype(int) % 6
    pal = np.array([(0.62, 0.09, 0.08), (0.80, 0.66, 0.12), (0.84, 0.82, 0.76), (0.12, 0.20, 0.50), (0.16, 0.42, 0.20), (0.06, 0.06, 0.07)])
    pc = pal[band]*(0.80 + 0.15*fbm(X*30, Y*30, oct=2, seed=161))[..., None]
    pc = mix(pc, (0.92, 0.90, 0.85), (np.abs(((Y - Hmin)/(0.032*s) + 0.25*np.sin(a*3)) % 1.0 - 0.02) < 0.03)*(np.sin(X*900) > 0))   # stitches
    c = np.where(back[..., None], pc, c)
    c = mix(c, GOLD, (np.abs(aa - math.radians(104)) < 0.035)*0.95); c = mix(c, BLK, (np.abs(aa - math.radians(104)) < 0.008))
    # eye holes, slanted up at the outer corners, black rimmed, red round them
    ex, ey_m = 0.036*s, ey + 0.004*s
    E = np.hypot((np.abs(X) - ex)/(0.020*s), (Y - ey_m - 0.30*(np.abs(X) - ex))/(0.0085*s))
    c = mix(c, RED, (E < 1.75)*(aa < 1.3)); c = mix(c, BLK, (E < 1.30)*(aa < 1.3)); c = mix(c, (0.01, 0.01, 0.01), (E < 1.0)*(aa < 1.3))
    hgt -= 0.0010*(E < 1.0)*(aa < 1.3)
    # flame brows over the eyes, gold edged
    xf = np.abs(X) - ex; zf = Y - (ey_m + 0.010*s)
    hf = 0.058*s*np.clip(1 - (xf/(0.032*s))**2, 0, 1)*(0.45 + 0.55*np.abs(np.cos(xf/(0.0085*s)*math.pi)))
    fl_o = (zf > -0.004*s)*(zf < hf + 0.004*s)*(np.abs(xf) < 0.034*s)*(aa < 1.3)
    fl = (zf > 0)*(zf < hf)*(np.abs(xf) < 0.031*s)*(aa < 1.3)
    c = mix(c, GOLD, fl_o*(E > 1.75)); c = mix(c, RED, fl*(E > 1.75))
    # the grin: red mouth from cheek to cheek, white fangs top and bottom, black lips, gold round it
    yu = my + 0.012*s + 5.0*X**2/s; yl = my - 0.042*s + 3.5*X**2/s; inm = (np.abs(X) < 0.088*s)*(aa < 1.3)
    mouth = inm*(Y < yu)*(Y > yl)
    c = mix(c, GOLD, inm*(Y < yu + 0.009*s)*(Y > yl - 0.009*s)); c = mix(c, BLK, inm*(Y < yu + 0.003*s)*(Y > yl - 0.003*s))
    c = mix(c, (0.30, 0.02, 0.02), mouth); c = mix(c, RED, mouth*(Y > (yu + yl)/2 - 0.006*s)*(Y < (yu + yl)/2 + 0.006*s))
    pt = 0.011*s; tri = 1 - np.abs(2*((X/pt) % 1.0) - 1)
    fang_u = np.exp(-((np.abs(X) - 0.034*s)/(0.006*s))**2); fang_l = np.exp(-((np.abs(X) - 0.058*s)/(0.006*s))**2)
    tu = mouth*(Y > yu - 0.011*s*tri - 0.022*s*fang_u); tl = mouth*(Y < yl + 0.009*s*tri + 0.018*s*fang_l)
    c = mix(c, (0.95, 0.93, 0.86), tu | tl); hgt += 0.0004*(tu | tl)
    # gold scroll curls on the cheeks and the forehead
    for cx, cy, rr in ((0.075*s, ey - 0.035*s, 0.022), (0.0, ey + 0.075*s, 0.020), (0.055*s, chin - 0.04*s, 0.020)):
        dd = np.hypot(np.abs(X) - cx, Y - cy)
        cur = (dd < rr*s)*(np.abs(np.sin(dd/(0.005*s)*math.pi + np.arctan2(Y - cy, np.abs(X) - cx))) < 0.25)*(aa < 1.3)
        c = mix(c, GOLD, cur*(E > 1.75)*~fl_o*~(inm*(Y < yu + 0.009*s)*(Y > yl - 0.009*s)))
    # gold and black border along the lower edge
    edg = (Y - hb_) < 0.009*s
    c = mix(c, GOLD, edg*~back); c = mix(c, BLK, ((Y - hb_) < 0.003*s)*~back)
    # age: dirt, cracked paint, chips showing the grey wood under it
    cr = np.abs(fbm(X*55, Y*55, oct=3, seed=162) - 0.5) < 0.008
    c = mix(c, (0.20, 0.17, 0.12), cr*0.7*~back); hgt -= 0.0003*cr
    chip = sst_(0.70, 0.73, fbm(X*30, Y*30, oct=3, seed=163))*~back
    c = mix(c, (0.45, 0.40, 0.32), chip*0.85); hgt -= 0.0002*chip
    c = mix(c, CL["DIRT"], 0.35*sst_(0.55, 0.80, fbm(X*9, Y*9, oct=3, seed=164)))
    # stains from the eyes: black soot / rust soaked round the lower rim, running down the face (no red blood: moderation)
    rnd = np.random.RandomState(8); wet = np.zeros((N_, N_))
    for sx in (-1, 1):
        wet = np.maximum(wet, (E > 0.95)*(E < 2.1)*(Y < ey_m)*(np.abs(X - sx*ex) < 0.024*s)*(aa < 1.3)*0.9)
        for k in range(5):
            x0 = sx*(ex + rnd.uniform(-0.016, 0.016)*s); y0 = ey_m - 0.006*s; Lk = rnd.uniform(0.05, 0.16)*s; ph0 = rnd.uniform(0, 6)
            xk = x0 + 0.004*s*np.sin((y0 - Y)/(0.018*s) + ph0)
            wk = 0.0028*s*(1 - 0.45*np.clip((y0 - Y)/Lk, 0, 1))
            st = (np.abs(X - xk) < wk)*(Y < y0)*(Y > y0 - Lk)*(aa < 1.3)
            drop = np.hypot(X - (x0 + 0.004*s*math.sin(Lk/(0.018*s) + ph0)), Y - (y0 - Lk)) < 0.0045*s
            wet = np.maximum(wet, np.maximum(st, drop*(aa < 1.3)).astype(float))
    tone = fbm(X*60, Y*60, oct=2, seed=165)
    c = mix(c, (0.05, 0.04, 0.04), wet*0.9); c = mix(c, (0.26, 0.16, 0.09), wet*sst_(0.45, 0.70, tone)*0.6)   # black, rusty in places
    rgh = rgh + 0.1*wet; hgt += 0.0001*wet
    rgh = np.where(back, 0.85, rgh)
    col = np.where(hel[..., None], c, col)
    # basket: red over woven bamboo, a gold band of scrolls round the middle, gold rim
    bk = (Vv > 0.655)*(Vv < 0.905); th_ = Uu*2*math.pi; q = (Vv - 0.66)/0.24
    wv = np.sin(th_*90)*np.sin(q*60); cb = np.ones((N_, N_, 3))*np.array(RED)*(0.85 + 0.1*wv)[..., None]
    orn, mo = CL["brocade"](Uu*28, q*5, GOLD, np.array(RED))
    cb = np.where(((q > 0.35)*(q < 0.75))[..., None], orn, cb)
    cb = mix(cb, BLK, (np.abs(q - 0.35) < 0.012) | (np.abs(q - 0.75) < 0.012)); cb = mix(cb, GOLD, q > 0.93)
    cb = mix(cb, CL["DIRT"], 0.30*sst_(0.55, 0.8, fbm(Uu*20, q*6, oct=3, seed=166, period=20)))
    col = np.where(bk[..., None], cb, col); hgt += 0.00025*wv*bk; rgh = np.where(bk, 0.75, rgh)
    # nose: red with gold rings, a gold tip
    nz = (Vv > 0.915)*(Vv < 0.985)*(Uu < 0.505); qn = (Vv - 0.92)/0.06
    cn = np.ones((N_, N_, 3))*np.array(RED); cn = mix(cn, GOLD, (np.sin(qn*50) > 0.6) | (qn > 0.88))
    col = np.where(nz[..., None], cn, col)
    ins = ~(hel | bk | nz)
    col = np.where(ins[..., None], np.array((0.17, 0.11, 0.07))*(0.85 + 0.15*np.sin(Uu*800)*np.sin(Vv*800))[..., None], col)
    base = os.path.join(GH, "ta_khon_mask"); os.makedirs(GH, exist_ok=True)
    CL["save_png"](col, base + "_Color.png", False); CL["save_png"](CL["normal_from_height"](hgt, 1400, 1400), base + "_Normal.png", True)
    CL["save_png"](np.clip(rgh, 0.2, 1.0), base + "_Roughness.png", True)
    return msh.to_object("Prop_TaKhonMask", rig, CL["tex_material"]("TaKhonMask", base), fix_normals=False)

PROPS = {"jaw_tie": jaw_tie, "baby": baby, "ta_khon_mask": ta_khon_mask}

def mask_fbx(path=os.path.join(RBX, "PhiTaKhonMask.fbx")):
    """the mask on its own (current scene: ghost_ta_khon), origin = the head bone's head at rest, to put on any driver:
    weld it to BodyHead at the head bone"""
    ob = bpy.data.objects["Prop_TaKhonMask"]; rig = bpy.data.objects["HumanRig"]
    hp = rig.matrix_world @ rig.data.bones["head"].head_local
    me = ob.data.copy(); me.transform(Matrix.Translation(-hp) @ ob.matrix_world)
    st = bpy.data.objects.new("PhiTaKhonMask", me); bpy.context.scene.collection.objects.link(st)
    bpy.ops.object.select_all(action='DESELECT'); st.select_set(True); bpy.context.view_layer.objects.active = st
    AN["fbx"](path, use_selection=True, object_types={'MESH'}, global_scale=AN["STUDS_PER_M"], apply_scale_options='FBX_SCALE_NONE',
              axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False)
    bpy.data.objects.remove(st, do_unlink=True)
    return path, tuple(round(x, 4) for x in hp)

def gold_skin(body, rig, char, s):
    """กุมารทอง: the child's skin turned to the gold leaf of a shrine figure (the shading of the plain skin kept,
    grime in the creases), black painted eyes and brows, red lips; a metalness map (gold = 1)"""
    mat = bpy.data.materials["Skin"]; nm = mat.copy(); nm.name = "SkinGold"
    meta = uv_meta(char)
    b = CL["Body"](body, rig); uvl = np.zeros((len(body.data.loops), 2)); body.data.uv_layers.active.data.foreach_get("uv", uvl.ravel())
    Pw, Nn, Fi = CL["raster_body"](b, uvl)
    hw = b.w[:, b.names.index("head")]; hv = b.co[hw > 0.99]; C = (hv.min(0) + hv.max(0))/2
    hb = rig.data.bones["head"]; rw = rig.matrix_world
    U = np.array((rw @ hb.tail_local - rw @ hb.head_local).normalized()); F = np.array((0, -1, 0)) - U*(-U[1]); F /= np.linalg.norm(F)
    L = np.cross(U, F)
    d = Pw - C; az = np.arctan2(d @ L, d @ F); X = az*meta["RF"]; Y = d @ U
    ey, my = meta["eye_h"], meta["mouth_h"]; mix, sm_ = CL["mix"], CL["sstep"]
    face = (Fi >= 0) & (np.abs(az) < math.radians(85)) & (Y > meta["chin_h"] - 0.01*s) & (Y < meta["top_h"] + 0.05*s)
    nodes = {bpy.path.abspath(n.image.filepath)[-14:]: n for n in nm.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image}
    cn = next(n for k, n in nodes.items() if k.endswith("_Color.png")); rn = next(n for k, n in nodes.items() if k.endswith("_Roughness.png"))
    im = cn.image; a_ = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a_)
    col = a_.reshape(im.size[1], im.size[0], 4)[..., :3].astype(np.float64)
    lum = col.mean(-1); ref = float(np.median(lum[Fi >= 0]))
    k = np.clip(lum/ref, 0.55, 1.25)
    gold = np.array((0.83, 0.62, 0.22))*k[..., None]
    gold = mix(gold, (0.36, 0.24, 0.08), sm_(0.85, 0.6, k)*0.6)                    # grime in the creases
    gold = mix(gold, (0.95, 0.80, 0.42), 0.25*sm_(0.6, 0.85, CL["fbm"](Pw[..., 0]*25, Pw[..., 1]*25, Pw[..., 2]*25, oct=2, seed=170)))
    flake = CL["fbm"](Pw[..., 0]*60, Pw[..., 1]*60, Pw[..., 2]*60, oct=2, seed=171) > 0.80             # gold leaf worn off
    gold = mix(gold, (0.30, 0.20, 0.12), flake*0.45)
    ex, es = 0.032*s, s*1.06
    e = np.hypot((np.abs(X) - ex)/(0.0150*es), (Y - ey)/(0.0068*es))
    brow = (np.abs(Y - (ey + 0.022*s) - 0.15*(np.abs(X) - ex)) < 0.0022*s)*(np.abs(np.abs(X) - ex) < 0.018*s)
    lip = np.hypot(X/(0.016*s), np.where(Y > my, (Y - my)/(0.005*s), (my - Y)/(0.006*s)))
    paint = face*((e < 1.0) | brow | (lip < 1.0))
    gold = mix(gold, (0.02, 0.02, 0.02), face*((e < 1.0) | brow)); gold = mix(gold, (0.85, 0.85, 0.80), face*(np.hypot((np.abs(X) - ex + 0.004*s)/(0.003*s), (Y - ey - 0.002*s)/(0.003*s)) < 1))
    gold = mix(gold, (0.62, 0.05, 0.05), face*(lip < 1.0))
    gold = np.where((Fi >= 0)[..., None], gold, col)
    out = os.path.join(GH, "ghost_kuman_thong_Skin")
    CL["save_png"](gold, out + "_Color.png", False); cn.image = bpy.data.images.load(out + "_Color.png")
    r = np.clip(0.38 + 0.25*flake + 0.25*paint, 0, 1); CL["save_png"](r, out + "_Roughness.png", True)
    ri = bpy.data.images.load(out + "_Roughness.png"); ri.colorspace_settings.name = "Non-Color"; rn.image = ri
    met = np.where(Fi >= 0, 1.0 - 0.9*flake - paint, 0.0); CL["save_png"](np.clip(met, 0, 1), out + "_Metalness.png", True)
    mi = bpy.data.images.load(out + "_Metalness.png"); mi.colorspace_settings.name = "Non-Color"
    mn = nm.node_tree.nodes.new("ShaderNodeTexImage"); mn.image = mi; mn.location = (-500, -150)
    nm.node_tree.links.new(mn.outputs["Color"], nm.node_tree.nodes["Principled BSDF"].inputs["Metallic"])
    body.data.materials[0] = nm

# ---------------------------------------------------------------- building one ghost
def build(name, save=True):
    g = GHOSTS[name]; char = g["char"]
    bpy.ops.wm.open_mainfile(filepath=os.path.join(CL["char_dir"](char), CL["NAMES"][char] + ".blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.context.view_layer.update()
    s = (rig.data.bones["head"].tail_local.z - rig.data.bones["hips"].head_local.z)/(1.818 - 0.880)
    CL["clear_clothes"]()
    if g["hair"]:
        hob = HA["add_hair"](char, [g["hair"]])[g["hair"]]
        zh = (rig.matrix_world @ rig.data.bones["head"].head_local).z
        if g["hair"] not in HA["BODY_BOUND"] and min((hob.matrix_world @ v.co).z for v in hob.data.vertices) < zh - 0.04:
            HA["bind_to_body"](hob, rig)        # shoulder-length hair (messy) follows the shoulders, not just the head
    else: HA["clear_hair"]()
    if g.get("seated"):                       # the skirt weighted for sitting (only in this ghost's file)
        CL["OUTFITS"][g["outfit"]] = [sp[:5] + (dict(sp[5], seated=True),) if sp[0] == "tube" else sp for sp in CL["OUTFITS"][g["outfit"]]]
    made = CL["add_clothes"](char, [g["outfit"]], keep_others=True)
    for o in made[g["outfit"]]: o.hide_render = False; o.hide_set(False)
    for o in bpy.data.objects:
        if o.name.startswith("Hair_"): o.hide_render = False; o.hide_set(False)
    CL["limit_cloth_weights"](made[g["outfit"]])
    body.data.materials[0] = bpy.data.materials["Skin" if g["skin"] == "SkinGold" else g["skin"]]
    if g["hair"]:              # behind the arms, then over the clothes
        tuck_hair(s); fit_hair()
    if g.get("headless"):
        neck_stump(body, rig, s); blood_skin(body, rig, char, s)
    if g.get("face") == "porcelain": porcelain_face(body, rig, char, s)
    if g["skin"] == "SkinGold": gold_skin(body, rig, char, s)
    if g.get("stretch"):            # a connected bone ignores its location: unhook the sliding ones (rest pose unchanged)
        bpy.context.view_layer.objects.active = rig; bpy.ops.object.mode_set(mode='EDIT')
        for bn in g["stretch"]: rig.data.edit_bones[bn].use_connect = False
        bpy.ops.object.mode_set(mode='OBJECT')
    make_clips(char, g["clips"], g.get("headless", False), g.get("stretch", ()))
    for p in g.get("props", []): PROPS[p](body, rig, char, s)
    AN["limit_weights"]()

    if save:
        os.makedirs(GH, exist_ok=True)
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(GH, name + ".blend"), relative_remap=True)
        bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    return made

def cut_body(name):
    """skin under the outfit (and the head of the headless ghost) cut out of the Body, as the game shows it"""
    g = GHOSTS[name]; body = bpy.data.objects["Body"]; me = body.data
    faces = json.load(open(os.path.join(CL["char_dir"](g["char"]), CL["NAMES"][g["char"]] + "_clothes.json")))["outfits"]
    gone = set(CL["hidden_faces"](me, {g["outfit"]: faces[g["outfit"]]})[g["outfit"]])
    if g.get("headless"): gone |= head_faces(body)
    # keep the smooth shading: the corner normals of the whole body, put back after the cut (as build_anims.split_skin)
    key = lambda co, c: (round(co.x, 5), round(co.y, 5), round(co.z, 5), round(c.x, 5), round(c.y, 5), round(c.z, 5))
    nrm = {key(me.vertices[me.loops[li].vertex_index].co, p.center): me.corner_normals[li].vector.copy()
           for p in me.polygons for li in p.loop_indices}
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index in gone], context='FACES'); bm.to_mesh(me); bm.free()
    me.normals_split_custom_set([nrm[key(me.vertices[me.loops[li].vertex_index].co, p.center)] for p in me.polygons for li in p.loop_indices])
    return len(gone)

# ---------------------------------------------------------------- clipping check
REG_PAIRS = [("uarm.L", "torso"), ("uarm.R", "torso"), ("farm.L", "torso"), ("farm.R", "torso"), ("hand.L", "torso"), ("hand.R", "torso"),
             ("hand.L", "head"), ("hand.R", "head"), ("farm.L", "head"), ("farm.R", "head"), ("uarm.R", "head"), ("uarm.L", "head"),
             ("hand.L", "thigh.L"), ("hand.R", "thigh.R"), ("farm.L", "thigh.L"), ("farm.R", "thigh.R"), ("hand.L", "hand.R"),
             ("farm.L", "farm.R"), ("thigh.L", "thigh.R"), ("shin.L", "shin.R"), ("foot.L", "foot.R"), ("head", "torso")]
def _region(bone):
    base, _, sd = bone.partition(".")
    if base in ("hips", "spine", "chest"): return "torso"
    if base in ("neck", "head"): return "head"
    if base == "upper_arm": return "uarm." + sd
    if base == "forearm": return "farm." + sd
    if base == "hand" or base.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb"): return "hand." + sd
    if base in ("thigh", "shin", "foot"): return base + "." + sd
    return None

def _mesh(o, deps):
    me = o.evaluated_get(deps).to_mesh(); w = o.matrix_world
    V = [w @ v.co for v in me.vertices]; F = [list(p.vertices) for p in me.polygons]
    N = [(w.to_3x3() @ v.normal).normalized() for v in me.vertices]
    o.evaluated_get(deps).to_mesh_clear(); return V, F, N

def _behind(pts, tree, maxd=0.06, faces=None, tol=0.0):
    """deepest point behind a closed surface (nearest face, normal pointing out); with `faces` (tree face -> label)
    also the labels of the faces the points went through deeper than tol"""
    worst, n, lab = 0.0, 0, {}
    for p in pts:
        loc, nrm, fi, d = tree.find_nearest(p, maxd)
        if loc is not None and (p - loc).dot(nrm) < 0:
            n += 1; worst = max(worst, d)
            if faces is not None and d > tol:
                k = faces[fi] if fi is not None and fi < len(faces) else "?"; lab[k] = max(lab.get(k, 0.0), d)
    return (worst, n, lab) if faces is not None else (worst, n)

RAYS = [Vector((0.31, 0.52, 0.80)).normalized(), Vector((-0.62, 0.21, -0.75)).normalized(), Vector((0.70, -0.66, 0.27)).normalized()]
def _inside(pts, tree, faces, tol):
    """points inside a closed surface (the first face each of 3 rays meets is seen from behind, 2 of 3 agree),
    deeper than tol: {label of the nearest face: depth}"""
    lab = {}
    for p in pts:
        loc, nrm, fi, d = tree.find_nearest(p, 0.10)
        if loc is None or d <= tol or (p - loc).dot(nrm) > 0: continue
        votes = 0
        for r in RAYS:
            h = tree.ray_cast(p + r*1e-4, r, 2.0)
            if h[0] is not None and h[1].dot(r) > 0: votes += 1
        if votes >= 2:
            k = faces[fi] if fi is not None else "?"; lab[k] = max(lab.get(k, 0.0), d)
    return lab

def check(name, step=3, tol_body=0.015, tol=0.008):
    """per clip: frames with clipping, worst depth (cm) and where. Kinds:
    skin   covered skin outside every cloth piece (a ray out along the skin normal meets no cloth; skin Roblox cuts away
           under the outfit is not counted) | body  one body part deeper than 1.5 cm in another (arm in chest, ...)
    hair   hair inside the skin or behind the outside of a cloth piece | cloth  a piece pushed into the skin
           (thighs through a skirt) or two pieces cutting through each other | prop  crown, nails, wings, tail, stump
           cutting into the body, the hair or the clothes (a nail on its own hand excepted)"""
    g = GHOSTS[name]; rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]; sc = bpy.context.scene
    allow = set(g.get("allow", ()))
    me = body.data; gname = {x.index: x.name for x in body.vertex_groups}
    vreg = []
    for v in me.vertices:
        bst = max(v.groups, key=lambda x: x.weight, default=None)
        vreg.append(_region(gname[bst.group]) if bst and bst.weight > 0.75 else None)
    freg = {}
    for p in me.polygons:
        rs = {vreg[i] for i in p.vertices}
        if len(rs) == 1 and None not in rs: freg[p.index] = rs.pop()
    # covered skin (rest): under the shells minus their edge ring and minus the faces cut away; trunk/legs inside a skirt
    for p_ in rig.pose.bones: p_.rotation_euler = (0, 0, 0); p_.location = (0, 0, 0)
    keep_act = rig.animation_data.action; rig.animation_data.action = None; bpy.context.view_layer.update()
    b = CL["Body"](body, rig)
    faces = json.load(open(os.path.join(CL["char_dir"](g["char"]), CL["NAMES"][g["char"]] + "_clothes.json")))["outfits"]
    hid = set(CL["hidden_faces"](me, {g["outfit"]: faces[g["outfit"]]})[g["outfit"]])
    if g.get("headless"): hid |= head_faces(body)
    shown = {v for p in me.polygons if p.index not in hid for v in p.vertices}
    cov = set()
    for sp in CL["OUTFITS"][g["outfit"]]:
        if sp[0] == "shell":
            fs = faces[g["outfit"]][sp[1]]; cnt = {}
            for fi in fs:
                vs = list(me.polygons[fi].vertices)
                for k in range(len(vs)):
                    e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)]))); cnt[e] = cnt.get(e, 0) + 1
            edge = {v for e, c in cnt.items() if c == 1 for v in e}
            cov |= {v for fi in fs for v in me.polygons[fi].vertices if v not in edge}
        elif sp[0] == "tube" and not sp[5].get("band"):
            ob = bpy.data.objects.get(f"Cloth_{g['outfit']}_{sp[1]}")
            zs = [(ob.matrix_world @ v.co).z for v in ob.data.vertices]; z0, z1 = max(zs), min(zs)
            cov |= {i for i in range(len(me.vertices)) if b.reg[i] in ("torso", "leg.L", "leg.R") and z1 + 0.06*b.s < b.co[i][2] < z0 - 0.02*b.s}
    cov = sorted(cov & shown)
    cloth = [o for o in bpy.data.objects if o.name.startswith("Cloth_") and not o.hide_render]
    PROP = ("_crown", "_flowers", "_buckle")
    props = [o for o in cloth if any(o.name.endswith(k) for k in PROP)] + [o for o in bpy.data.objects if o.name == "NeckStump" or o.name.startswith("Prop_")]
    soft = [o for o in cloth if o not in props]
    hair = [o for o in bpy.data.objects if o.name.startswith("Hair_") and not o.hide_render]
    # hair below the skull only (the scalp layer may touch the head), cloth verts that aren't a shell's turned-in hem
    zn = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    hair_low = {o.name: [v.index for v in o.data.vertices if (o.matrix_world @ v.co).z < zn] for o in hair}
    rows = []
    for clip in ["rest"] + g["clips"]:
        if clip == "rest":            # the outfit as built (no clip): what is wrong here is the outfit, not the animation
            rig.animation_data.action = None
            for p_ in rig.pose.bones: p_.rotation_euler = (0, 0, 0); p_.location = (0, 0, 0)
            f0 = f1 = sc.frame_current
        else:
            act = bpy.data.actions[clip]; rig.animation_data.action = act
            f0, f1 = (int(x) for x in act.frame_range)
        stats = {}
        def add(kind, where, depth):
            k = stats.setdefault(kind, dict(frames=set(), worst=0.0, where={}))
            k["frames"].add(f); k["worst"] = max(k["worst"], depth); k["where"][where] = max(k["where"].get(where, 0.0), depth)
        frames = list(range(f0, f1 + 1, step))
        for f in frames:
            sc.frame_set(f); bpy.context.view_layer.update(); deps = bpy.context.evaluated_depsgraph_get()
            BV, BF, BN = _mesh(body, deps)
            # the whole skin (a surface with the covered faces cut out has holes: nearest-face tests go wrong through them)
            btree = BVHTree.FromPolygons(BV, BF); blab = [freg.get(i) or b.reg[BF[i][0]] for i in range(len(BF))]
            # skin through cloth
            if cov and soft:
                CV, CF = [], []
                for o in soft:
                    V, F_, _ = _mesh(o, deps); base = len(CV); CV += V; CF += [[base + i for i in fc] for fc in F_]
                ct = BVHTree.FromPolygons(CV, CF)
                hem = min((v.z for o in soft if "_sin" in o.name for v in _mesh(o, deps)[0]), default=None)
                bad = {}
                for i in cov:
                    p, n = BV[i], BN[i]
                    if n.z < -0.3: continue
                    if ct.ray_cast(p + n*0.001, n, 0.5)[0] is None:
                        if hem is not None and n.z < 0 and p.z + n.z*0.5 < hem: continue
                        bad[b.reg[i]] = bad.get(b.reg[i], 0) + 1
                if sum(bad.values()) >= 2:
                    for r_, k_ in bad.items(): add("skin", f"{r_} out", k_)
            # body part through body part
            polys = {}
            for i, fc in enumerate(BF):
                r = freg.get(i)
                if r and i not in hid: polys.setdefault(r, []).append(fc)
            trees = {r: BVHTree.FromPolygons(BV, ps) for r, ps in polys.items()}
            rv = {r: {i for p in ps for i in p} for r, ps in polys.items()}
            for a, c in REG_PAIRS:
                if (a, c) in allow or (c, a) in allow: continue
                if a in trees and c in trees and trees[a].overlap(trees[c]):
                    d = max(_behind([BV[i] for i in rv[a]], trees[c])[0], _behind([BV[i] for i in rv[c]], trees[a])[0])
                    if d > tol_body: add("body", f"{a}x{c}", d*100)
            # hair
            VO, FO = outer_cloth(deps); otree = BVHTree.FromPolygons(VO, FO) if FO else None
            for o in hair:
                V, _, _ = _mesh(o, deps); pts = [V[i] for i in hair_low[o.name]]
                if not pts: continue
                for r_, dd in _inside(pts, btree, blab, tol).items(): add("hair", f"hair in {r_}", dd*100)
                if otree:
                    worst = 0.0
                    for q in pts:
                        loc, nrm, _, d = otree.find_nearest(q, 0.04)
                        if loc is None or d <= tol or (q - loc).dot(nrm) >= 0: continue
                        if otree.ray_cast(q + nrm*1e-4, nrm, 0.05)[0] is not None: worst = max(worst, d)
                    if worst > tol: add("hair", "hair under cloth", worst*100)
            # cloth pushed into the skin; cloth through cloth
            meshes = {o.name: _mesh(o, deps) for o in soft + props}
            ctrees = {k: BVHTree.FromPolygons(*m[:2]) for k, m in meshes.items()}
            for o in soft:
                V, F_, _ = meshes[o.name]
                for r_, dd in _inside(V, btree, blab, tol*1.25).items(): add("cloth", f"{o.name[6:]} in {r_}", dd*100)
            shells = {o.name for o in soft if not any(o.name.endswith("_" + sp[1]) for sp in CL["OUTFITS"][g["outfit"]] if sp[0] != "shell")}
            for i, a in enumerate(soft):
                for c in soft[i + 1:]:
                    if a.name in shells and c.name in shells: continue     # shirt meets trousers edge to edge (seam)
                    ov = ctrees[a.name].overlap(ctrees[c.name])
                    if len(ov) > 6:
                        Va, Fa = meshes[a.name][:2]; wh = {}
                        for ia, _ in ov:
                            fi = btree.find_nearest(Va[Fa[ia][0]])[2]; r_ = blab[fi] if fi is not None else "?"; wh[r_] = wh.get(r_, 0) + 1
                        top = max(wh, key=wh.get)
                        add("cloth", f"{a.name[6:]}x{c.name[6:]} at {top}", len(ov))
            # props
            for o in props:
                tp = ctrees[o.name]
                own = ()
                for r, tr in trees.items():
                    if r in own or (o.name == "NeckStump" and r == "head"): continue
                    if o.name.endswith("_crown") and r == "head": continue
                    k = len(tp.overlap(tr))
                    if k > 2: add("prop", f"{o.name[6:]}x{r}", k)
                for h in hair:
                    if o.name.startswith("Prop_"):
                        d, n = _behind(_mesh(h, deps)[0], tp, 0.03)
                        if n > 4: add("prop", f"hair through {o.name[5:]}", n)
                    if o.name.endswith("_crown"):
                        d, n = _behind(_mesh(h, deps)[0], tp, 0.03)
                        if n > 4: add("prop", "hair through crown", n)
                for c in soft:
                    k = len(tp.overlap(ctrees[c.name]))
                    if k > 4: add("prop", f"{o.name[6:]}x{c.name[6:]}", k)
        for kind, k in stats.items():
            rows.append((clip, kind, len(k["frames"]), len(frames), round(k["worst"], 1),
                         dict(sorted(((w, round(v, 1)) for w, v in k["where"].items()), key=lambda t: -t[1])[:4])))
        if not stats: rows.append((clip, "ok", 0, len(frames), 0, {}))
    rig.animation_data.action = keep_act
    return rows

def report(name, rows):
    return "\n".join(f"{name:26s} {clip:13s} {kind:6s} {n:3d}/{tot:<3d} frames  worst {w:6.1f}  {where}" for clip, kind, n, tot, w, where in rows)

# ---------------------------------------------------------------- contact sheet
def sheet(name, out_dir=os.path.join(GH, "previews"), size=(220, 360), n=6):
    """rows = clips; per clip 3 strips (front, side, back) of n moments (Workbench, textures shown)"""
    os.makedirs(out_dir, exist_ok=True)
    sc = bpy.context.scene; rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    sc.render.engine = 'BLENDER_WORKBENCH'; sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = False
    sc.view_settings.view_transform = 'Standard'
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]; H = max(zs) - min(zs) + 0.5
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = H*1.05
    sc.render.resolution_x, sc.render.resolution_y = size
    tgt = Vector((0, 0, min(zs) + H*0.47))
    out = []
    cof = coffin_mesh() if "coffin_walk" in GHOSTS[name]["clips"] else None
    for clip in GHOSTS[name]["clips"]:
        act = bpy.data.actions[clip]; rig.animation_data.action = act
        f0, f1 = (int(x) for x in act.frame_range)
        rows = []
        for view in (0, 90, 180):
            row = []
            for k in range(n):
                sc.frame_set(int(f0 + (f1 - f0)*k/n))
                if cof is not None:
                    cof.hide_render = clip != "coffin_walk"
                    cof.matrix_world = Matrix.Translation(fist_R())
                a = math.radians(view); d = Vector((math.sin(a), -math.cos(a), 0))
                cam.location = tgt + d*5; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
                tmp = os.path.join(out_dir, "_t.png"); sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
                im = bpy.data.images.load(tmp); a_ = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a_)
                row.append(a_.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
            rows.append(np.concatenate(row, 1))
        img_ = np.concatenate(rows[::-1], 0)
        p = os.path.join(out_dir, f"{name}_{clip}.png")
        im = bpy.data.images.new("_sheet", img_.shape[1], img_.shape[0]); im.pixels.foreach_set(img_.ravel())
        im.filepath_raw = p; im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im); out.append(p)
    bpy.data.objects.remove(cam, do_unlink=True)
    if cof is not None: bpy.data.objects.remove(cof, do_unlink=True)
    return out

# ---------------------------------------------------------------- export
def export(name):
    """model (Body cut as in game + outfit + hair + props on the rig, in studs, textures copied next to it) and one FBX
    per clip (armature only), the same settings as build_anims.export_model / export_clip"""
    d = os.path.join(RBX, name); os.makedirs(d, exist_ok=True)
    rig = bpy.data.objects["HumanRig"]
    objs = AN["bound_meshes"](rig) + [o for o in bpy.data.objects if o.name == "NeckStump" or o.name.startswith("Prop_")]
    objs = list(dict.fromkeys(objs))
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs + [rig]: o.hide_viewport = False; o.hide_set(False); o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action if rig.animation_data else None
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    AN["fbx"](os.path.join(d, name + ".fbx"), use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=AN["STUDS_PER_M"],
              apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
              add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
              mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    for clip in GHOSTS[name]["clips"]:
        AN["export_clip"](os.path.join(d, f"{name}_{clip}.fbx"), clip)
    if rig.animation_data: rig.animation_data.action = act
    return d

# ---------------------------------------------------------------- the coffin (prop for the funeral ghosts)
def coffin_mesh():
    """โลงศพ: white lacquered box with a peaked lid and faded gold trim on two carrying poles (คานหาม). Origin = the middle
    of the right-hand pole, where the bearer's right fist holds it (coffin_walk); the box lies to the -X side of it."""
    msh = CL["Mesh"](); Lb, Wb, Hb = 2.0, 0.62, 0.50
    x0 = -0.14 - Wb                                         # box inboard of the pole
    def box(x0, x1, y0, y1, z0, z1, peak=0.0):
        vs = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        ids = [msh.vert(v, {}) for v in vs]
        if peak: ids += [msh.vert(((x0 + x1)/2, y0, z1 + peak), {}), msh.vert(((x0 + x1)/2, y1, z1 + peak), {})]
        def q(a, uvs): msh.face([ids[i] for i in a], uvs)
        U = lambda a, b_: (a/CL["TILE"], b_/CL["TILE"])
        q([0, 3, 2, 1], [U(0, 0), U(0, y1 - y0), U(x1 - x0, y1 - y0), U(x1 - x0, 0)])
        q([0, 1, 5, 4], [U(0, 0), U(x1 - x0, 0), U(x1 - x0, z1 - z0), U(0, z1 - z0)])
        q([2, 3, 7, 6], [U(0, 0), U(x1 - x0, 0), U(x1 - x0, z1 - z0), U(0, z1 - z0)])
        if peak:
            q([1, 2, 6, 5], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, z1 - z0), U(0, z1 - z0)])
            q([3, 0, 4, 7], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, z1 - z0), U(0, z1 - z0)])
            q([4, 5, 8], [U(0, 0), U(x1 - x0, 0), U((x1 - x0)/2, peak)]); q([6, 7, 9], [U(0, 0), U(x1 - x0, 0), U((x1 - x0)/2, peak)])
            q([5, 6, 9, 8], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, 0.4), U(0, 0.4)]); q([7, 4, 8, 9], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, 0.4), U(0, 0.4)])
        else:
            q([1, 2, 6, 5], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, z1 - z0), U(0, z1 - z0)])
            q([3, 0, 4, 7], [U(0, 0), U(y1 - y0, 0), U(y1 - y0, z1 - z0), U(0, z1 - z0)]); q([4, 5, 6, 7], [U(0, 0), U(x1 - x0, 0), U(x1 - x0, y1 - y0), U(0, y1 - y0)])
    box(x0, x0 + Wb, -Lb/2, Lb/2, 0.05, 0.05 + Hb, peak=0.10)                     # the coffin on the frame
    pm = len(msh.f)
    for xp in (0.0, x0 - 0.14 + 0.0):                                              # two poles, 3 m, under the box edges
        box(xp - 0.03, xp + 0.03, -1.5, 1.5, -0.03, 0.03)
    box(x0 - 0.14, 0.0, -0.8, -0.74, 0.0, 0.05); box(x0 - 0.14, 0.0, 0.74, 0.8, 0.0, 0.05)   # cross bars
    # textures: lacquer with gold border bands + grime (box), dark wood (poles)
    P = CL["PATTERNS"]
    def lac(X, Y):
        c = np.ones(X.shape + (3,))*np.array((0.86, 0.85, 0.80))
        c = CL["mix"](c, (0.66, 0.52, 0.22), (np.abs(((Y/CL["TILE"]) % 1) - 0.5) < 0.05) | (np.abs(((X/CL["TILE"]) % 1) - 0.5) < 0.02))
        c, r, h = CL["ghost_cloth"](c, X, (Y/CL["TILE"]) % 1, 140, "band", 1.2, 0.2, 0.45)
        return c, r, h
    def wood(X, Y):
        c = np.ones(X.shape + (3,))*np.array((0.30, 0.20, 0.12))*(0.8 + 0.2*np.sin(X*900 + 3*np.sin(Y*40)))[..., None]
        return c, 0.7, 0.0
    P["coffin_lacquer"] = (lac, "metric", False); P["coffin_wood"] = (wood, "metric", False)
    keep = dict(P); P.clear(); P.update({k: keep[k] for k in ("coffin_lacquer", "coffin_wood")})
    CL["make_patterns"](); P.clear(); P.update(keep)
    os.makedirs(RBX, exist_ok=True)
    me = bpy.data.meshes.new("Coffin"); me.from_pydata([tuple(v) for v in msh.v], [], msh.f)
    lay = me.uv_layers.new(name="UVMap"); lay.data.foreach_set("uv", np.array([u for fu in msh.uv for u in fu], np.float32).ravel())
    me.materials.append(CL["tex_material"]("Coffin", os.path.join(CL["TEX"], "coffin_lacquer")))
    me.materials.append(CL["tex_material"]("CoffinPole", os.path.join(CL["TEX"], "coffin_wood")))
    for i, p in enumerate(me.polygons): p.material_index = 0 if i < pm else 1
    ob = bpy.data.objects.new("Coffin", me); bpy.context.scene.collection.objects.link(ob)
    return ob

def coffin():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ob = coffin_mesh(); bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    AN["fbx"](os.path.join(RBX, "Coffin.fbx"), use_selection=True, object_types={'MESH'}, global_scale=AN["STUDS_PER_M"],
              apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE', path_mode='COPY')
    return ob

def fist_R():
    """world position of the right fist (between the wrist and the middle knuckle)"""
    rig = bpy.data.objects["HumanRig"]; pb = rig.pose.bones; mw = rig.matrix_world
    return (mw @ pb["hand.R"].head).lerp(mw @ pb["middle_01.R"].head, 0.75)

def all_ghosts(names=None):
    """build, check, cut, sheet, export each ghost; check_report.txt keeps the lines of the ghosts not rebuilt"""
    names = list(names or GHOSTS); new = {}
    for name in names:
        build(name)
        rows = check(name); new[name] = report(name, rows)
        cut_body(name); sheet(name); export(name)
        bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    fp = os.path.join(GH, "check_report.txt"); old = {}
    if os.path.exists(fp):
        for ln in open(fp, encoding="utf-8").read().splitlines():
            if ln.strip(): old.setdefault(ln.split()[0], []).append(ln)
    out = []
    for name in GHOSTS:
        if name in new: out.append(new[name])
        elif name in old: out += old[name]
    open(fp, "w", encoding="utf-8").write("\n".join(out) + "\n")
    return "\n".join(new[n] for n in names)

def compare(name, ref, out, clip="dancer_dance", frame=None):
    """[reference | front | 3/4 | face] side by side, EEVEE, at the reference pose (frame 1 of the dance = pose A)"""
    sc = bpy.context.scene; rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.11, 0.13, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    temps = []
    for nm_, rot, e in (("_key", (55, 0, -35), 3.0), ("_fill", (70, 0, 60), 1.0), ("_rim", (60, 0, 170), 1.5)):
        l = bpy.data.objects.new(nm_, bpy.data.lights.new(nm_, 'SUN')); l.data.energy = e
        l.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(l); temps.append(l)
    rig.animation_data.action = bpy.data.actions[clip]; sc.frame_set(frame or 1); bpy.context.view_layer.update()
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]; H = max(zs) - min(zs) + 0.55
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam; temps.append(cam)
    cam.data.type = 'ORTHO'
    Hh = 760; tiles = []
    def shot(tgt, d, scale, wpx):
        cam.data.ortho_scale = scale; sc.render.resolution_x, sc.render.resolution_y = wpx, Hh
        cam.location = tgt + d*5; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp); a_ = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a_)
        r_ = a_.reshape(im.size[1], im.size[0], 4); bpy.data.images.remove(im); os.remove(tmp); return r_
    tgt = Vector((0, 0, min(zs) + H*0.47))
    tiles.append(shot(tgt, Vector((0, -1, 0)), H*1.02, 540))
    tiles.append(shot(tgt, Vector((0.64, -0.77, 0)).normalized(), H*1.02, 540))
    hd = rig.matrix_world @ rig.pose.bones["head"].tail
    head = rig.matrix_world @ rig.pose.bones["head"].head; fc = head.lerp(hd, 0.45)
    for o in temps:
        if o.name == "_rim": o.hide_render = True                 # no hard back light on the face (it cut the nose piece into a wedge)
    cam.data.type = 'PERSP'; cam.data.lens = 85
    def shot_p(tgt, d, dist, wpx):
        sc.render.resolution_x, sc.render.resolution_y = wpx, Hh
        cam.location = tgt + d*dist; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp); a_ = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a_)
        r_ = a_.reshape(im.size[1], im.size[0], 4); bpy.data.images.remove(im); os.remove(tmp); return r_
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.26, 0.28, 1)
    tiles.append(shot_p(fc, Vector((0.25, -1, 0.08)).normalized(), 1.25, 560))
    rim = bpy.data.images.load(ref); ra = np.empty(rim.size[0]*rim.size[1]*4, np.float32); rim.pixels.foreach_get(ra)
    ra = ra.reshape(rim.size[1], rim.size[0], 4); k = Hh/ra.shape[0]
    yy = np.minimum((np.arange(Hh)/k).astype(int), ra.shape[0] - 1); xx = np.minimum((np.arange(int(ra.shape[1]*k))/k).astype(int), ra.shape[1] - 1)
    tiles.insert(0, ra[yy][:, xx]); bpy.data.images.remove(rim)
    sheet_ = np.concatenate(tiles, 1)
    im = bpy.data.images.new("_cmp", sheet_.shape[1], sheet_.shape[0]); im.pixels.foreach_set(sheet_.ravel())
    im.filepath_raw = out; im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im)
    for o in temps: bpy.data.objects.remove(o, do_unlink=True)

def closeup(name, clip, frame, bone, scale, out, views=(0, 90, 180, 270), size=360):
    """close look at one spot (bone head) at one frame, four sides (Workbench, textures)"""
    sc = bpy.context.scene; rig = bpy.data.objects["HumanRig"]
    sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
    if clip == "rest":
        rig.animation_data.action = None
        for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    else:
        rig.animation_data.action = bpy.data.actions[clip]; sc.frame_set(frame)
    bpy.context.view_layer.update()
    tgt = rig.matrix_world @ rig.pose.bones[bone].head
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = scale; sc.render.resolution_x = sc.render.resolution_y = size
    tiles = []
    for v in views:
        a = math.radians(v); d = Vector((math.sin(a), -math.cos(a), 0.15)).normalized()
        cam.location = tgt + d*4; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp); a_ = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a_)
        tiles.append(a_.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
    img_ = np.concatenate(tiles, 1)
    im = bpy.data.images.new("_c", img_.shape[1], img_.shape[0]); im.pixels.foreach_set(img_.ravel())
    im.filepath_raw = out; im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im)
    bpy.data.objects.remove(cam, do_unlink=True)
