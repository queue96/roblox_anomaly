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
    "A": dict(dl=34, dr=16, hz=5, sz=-6, cz=-4, hy=8, hz_=10,
              R=(40, -6, 6, 62, -70, "wong"), L=(-20, 45, 110, 70, 15, "wong")),     # hand in front of the chest, palm out, forearm clear of the sabai (found by a grid search)
    # ตั้งวง high in front with the right hand, จีบ low at the left hip, weight centred, deeper
    "C": dict(dl=28, dr=28, hz=0, sz=0, cz=-2, hy=-6, hz_=-6,
              R=(44, 38, 72, 52, -20, "wong"), L=(-22, 22, 58, 28, 10, "jeeb")),
}
def _mirror(d):
    m = dict(d, dl=d["dr"], dr=d["dl"], hz=-d["hz"], sz=-d["sz"], cz=-d["cz"], hy=-d["hy"], hz_=-d["hz_"], R=d["L"], L=d["R"])
    return m
DANCE["B"] = _mirror(DANCE["A"]); DANCE["D"] = _mirror(DANCE["C"])
DANCE_SEQ = ["A", "C", "B", "D"]

def dancer_pose(P, d, s, br=0.0, tw=0.0):
    P.rot("thigh.L", d["dl"]*0.6, 0, 5); P.rot("thigh.R", d["dr"]*0.6, 0, 5)
    P.rot("shin.L", -d["dl"]); P.rot("shin.R", -d["dr"]); P.rot("foot.L", d["dl"]*0.42); P.rot("foot.R", d["dr"]*0.42)
    P.lift("hips", -hip_drop(min(d["dl"], d["dr"]), s))
    P.rot("hips", 0, 0, d["hz"]); P.rot("spine", -4 + 0.6*br, 0, d["sz"]); P.rot("chest", -4 + 0.8*br, 0, d["cz"])
    P.rot("neck", 2, d["hy"]*0.4, d["hz_"]*0.5); P.rot("head", 4 + 4*tw, d["hy"] + 12*tw, d["hz_"] - 8*tw)
    for sd in ("L", "R"):
        r_, f_, b_, w_, t_, h_ = d[sd]
        arm(P, sd, raise_=r_, fwd=f_, bend=b_, wrist=w_, twist=t_); hand(P, sd, h_)

def _blend(a, b, u):
    out = {}
    for k in a:
        if k in ("L", "R"):
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
    d = dict(dl=12, dr=12, hz=1.5*math.sin(ph), sz=-1.5*math.sin(ph), cz=0, hy=6*math.sin(ph), hz_=8*math.sin(ph + 0.6),
             R=(-16, 40, 72, 34, -10, "wong"), L=(-18, 38, 76, 30, 10, "jeeb"))
    dancer_pose(P, d, s, br=br)

NEW_CLIPS = {"pillion_hug": (c_pillion_hug, 120), "pillion_look": (c_pillion_look, 180), "tani_peek": (c_tani_peek, 150),
             "coffin_walk": (c_coffin_walk, 60), "dancer_dance": (c_dancer_dance, 360), "dancer_idle": (c_dancer_idle, 150)}
FIXED_TEMPO = {"dancer_dance", "pillion_hug", "pillion_look"}

def make_clips(char, clips, headless=False):
    """only the ghost's own clips stay in the file (the 40 human clips are dropped)"""
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
    body.data.materials[0] = bpy.data.materials[g["skin"]]
    if g["hair"]:              # behind the arms, then over the clothes
        tuck_hair(s); fit_hair()
    if g.get("headless"):
        neck_stump(body, rig, s); blood_skin(body, rig, char, s)
    if g.get("face") == "porcelain": porcelain_face(body, rig, char, s)
    make_clips(char, g["clips"], g.get("headless", False))
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
    props = [o for o in cloth if any(o.name.endswith(k) for k in PROP)] + [o for o in bpy.data.objects if o.name == "NeckStump"]
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
    objs = AN["bound_meshes"](rig) + [o for o in bpy.data.objects if o.name == "NeckStump"]
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
    lines = []
    for name in names or GHOSTS:
        build(name)
        rows = check(name); lines.append(report(name, rows))
        cut_body(name); sheet(name); export(name)
        bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    open(os.path.join(GH, "check_report.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    return "\n".join(lines)

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
    tiles.append(shot(fc, Vector((0, -1, 0.05)).normalized(), 0.42, 560))
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
