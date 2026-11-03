# Skin textures for the low-poly humans: UV layout, painted face, wrinkles (normal map), ghost variant.
# One texture set per character, shared by its thin / fat / pregnant bodies (same topology, same UVs).
#
#   exec(open(r"...\human_base\build_skin.py", encoding="utf-8").read())
#   skin_all()          # per character: unwrap the normal body, paint textures, apply to all its .blend files
#   add_skin("female")  # current scene: UVs from human_female_uv.json + Skin / SkinGhost / SkinWithered materials
#   withered_char("female")  # only the _Withered set, on the stored UVs (skin_all re-unwraps: the UVs can shift)
#   preview_all()       # renders skin_previews/<char>.png (face front / 3-4 / side / hand, human + ghost)
#
# Files per character (next to its .blend): <name>_Color/_Normal/_Roughness.png, <name>_Ghost_*.png (pale ghost)
# and <name>_Withered_*.png (dried, cracked, leathery ghost skin; material SkinWithered)
# (1024, Roblox SurfaceAppearance: ColorMap / NormalMap (OpenGL, +Y up) / RoughnessMap), <name>_uv.json.
#
# UV layout (v up):
#   top half      head + neck, cylinder around the head bone: u = azimuth (face at u = 0.5, seam at the back of the head),
#                 v = height along the head axis. Face features are painted straight into this (azimuth, height) space.
#   bottom-left   torso, arms, legs (smart project)
#   bottom-right  hands and feet (smart project, more pixels for knuckles and nails)
# Wrinkles are a height map (metres) turned into a tangent-space normal map with the texel density of each spot.
import bpy, bmesh, math, os, glob, json
import numpy as np
from mathutils import Vector

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
DIRS = {"human_base": "male", "human_female": "female", "human_child": "child",
        "human_elder_male": "elder_male", "human_elder_female": "elder_female"}
NAMES = {v: k for k, v in DIRS.items()}
N = 1024
HV0, HV1 = 0.505, 0.995                     # head region rows (v)
BODY_BOX = (0.005, 0.005, 0.495, 0.495)     # u0, v0, u1, v1
HAND_BOX = (0.505, 0.005, 0.995, 0.495)
K_FACE = 0.6                                # head u warp: face gets (1 + K) times the texels of a plain cylinder
def warp(a): return a + K_FACE*np.sin(a)
def unwarp(t):
    a = np.array(t, dtype=np.float64)
    for _ in range(8): a = a - (a + K_FACE*np.sin(a) - t)/(1 + K_FACE*np.cos(a))
    return a
HANDS = ("hand", "index", "middle", "ring", "pinky", "thumb", "foot", "toe")

# per character look: skin (sRGB), brow colour, how old the skin is (0 child .. 1 elder), eye size, lip tint
LOOK = {
    "male":         dict(skin=(0.76, 0.57, 0.44), brow=(0.09, 0.07, 0.06), age=0.30, eye=1.00, lip=(0.62, 0.40, 0.36), brow_w=1.25),
    "female":       dict(skin=(0.85, 0.67, 0.55), brow=(0.12, 0.09, 0.08), age=0.20, eye=1.06, lip=(0.72, 0.38, 0.38), brow_w=0.85, lash=1.5),
    "child":        dict(skin=(0.86, 0.68, 0.56), brow=(0.13, 0.10, 0.08), age=0.00, eye=1.12, lip=(0.76, 0.48, 0.45), brow_w=0.80, blush=1.4),
    "elder_male":   dict(skin=(0.71, 0.53, 0.41), brow=(0.60, 0.58, 0.55), age=1.00, eye=0.94, lip=(0.58, 0.40, 0.38), brow_w=1.45),
    "elder_female": dict(skin=(0.78, 0.60, 0.49), brow=(0.46, 0.44, 0.42), age=0.90, eye=0.96, lip=(0.64, 0.42, 0.42), brow_w=0.85, lash=1.2),
}
GHOST_SKIN = (0.70, 0.73, 0.70)
WITHERED_SKIN = (0.47, 0.44, 0.40)          # ghost="withered": dried, leathery grey-brown (mummified)

def blend_files(char=None):
    fs = sorted(glob.glob(os.path.join(M, "human_*", "human_*.blend")))
    return [f for f in fs if char is None or DIRS[os.path.basename(os.path.dirname(f))] == char]

def char_dir(char): return os.path.join(M, NAMES[char])

# ---------------------------------------------------------------- noise (numpy, deterministic)
_P = np.random.RandomState(7).permutation(256); _P = np.concatenate([_P, _P])
def _fade(t): return t*t*t*(t*(t*6 - 15) + 10)
def vnoise(*co, seed=0):
    """value noise in 2 or 3 dims, 0..1, arrays of any shape"""
    co = [np.asarray(c, dtype=np.float64) + seed*17.31*(i + 1) for i, c in enumerate(co)]
    fl = [np.floor(c).astype(np.int64) for c in co]; fr = [_fade(c - f) for c, f in zip(co, fl)]
    def h(*ix):
        a = np.zeros_like(ix[0])
        for v in ix: a = _P[(a + v) & 255]
        return a/255.0
    if len(co) == 2:
        x, y = fl; u, v = fr
        a = h(x, y)*(1-u) + h(x+1, y)*u; b = h(x, y+1)*(1-u) + h(x+1, y+1)*u
        return a*(1-v) + b*v
    x, y, z = fl; u, v, w = fr
    def lay(zz):
        a = h(x, y, zz)*(1-u) + h(x+1, y, zz)*u; b = h(x, y+1, zz)*(1-u) + h(x+1, y+1, zz)*u
        return a*(1-v) + b*v
    return lay(z)*(1-w) + lay(z+1)*w

def fbm(*co, oct=4, seed=0):
    s, a, t = 0.0, 0.5, 0.0
    for o in range(oct):
        s = s + a*vnoise(*[c*(2**o) for c in co], seed=seed + o); t += a; a *= 0.5
    return s/t

def ridge(*co, seed=0, sharp=10.0):
    """thin branching lines (veins): 1 on the line, 0 away"""
    n = fbm(*co, oct=3, seed=seed)
    return np.exp(-(((n - 0.5)*sharp)**2))

def sstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0, 1); return t*t*(3 - 2*t)

# ---------------------------------------------------------------- head frame + landmarks
class Frame:
    def __init__(self, body, rig):
        me = body.data; mw = body.matrix_world
        self.gi = {g.name: g.index for g in body.vertex_groups}
        self.w = np.zeros((len(me.vertices), len(body.vertex_groups)), dtype=np.float32)
        for v in me.vertices:
            for g in v.groups: self.w[v.index, g.group] = g.weight
        self.co = np.array([tuple(mw @ v.co) for v in me.vertices])
        self.nrm = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in me.vertices])
        hw = self.w[:, self.gi["head"]]
        pts = self.co[hw > 0.99]
        lo, hi = pts.min(0), pts.max(0)
        self.C = Vector((lo + hi)/2)
        hb = rig.data.bones["head"]; rw = rig.matrix_world
        self.U = (rw @ hb.tail_local - rw @ hb.head_local).normalized()
        F = Vector((0, -1, 0)); self.F = (F - self.U*F.dot(self.U)).normalized()
        self.L = self.U.cross(self.F).normalized()
        self.s = (hi[2] - lo[2])/0.235
        self.joints = {b.name: (np.array(rw @ b.head_local), np.array((rw @ b.tail_local) - (rw @ b.head_local)))
                       for b in rig.data.bones}

    def local(self, p):
        """(azimuth rad, height m, forward m) of world points [n,3]"""
        d = np.asarray(p) - np.array(self.C)
        f = d @ np.array(self.F); l = d @ np.array(self.L); u = d @ np.array(self.U)
        return np.arctan2(l, f), u, f

def islands(me):
    bm = bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen: continue
        st, grp = [f], []; seen.add(f.index)
        while st:
            x = st.pop(); grp.append(x.index)
            for e in x.edges:
                for y in e.link_faces:
                    if y.index not in seen: seen.add(y.index); st.append(y)
        out.append(grp)
    bm.free(); return out

def landmarks(fr, me):
    """face points in head (X = azimuth * face radius, Y = height) metres, measured off the nose piece"""
    isl = sorted(islands(me), key=len)
    vs = set()
    for grp in isl[:-1]:
        for fi in grp: vs.update(me.polygons[fi].vertices)
    vs = np.array(sorted(vs))
    az, h, fw = fr.local(fr.co[vs])
    nose = vs[np.abs(az) < math.radians(25)]            # ears sit at the sides
    naz, nh, nfw = fr.local(fr.co[nose])
    top_h, base_h = nh.max(), nh.min()
    tip_h = nh[np.argmax(nfw)]
    # face radius: skin at eye height straight in front of the head centre
    az_all, h_all, fw_all = fr.local(fr.co)
    hw = fr.w[:, fr.gi["head"]] > 0.99
    front = hw & (np.abs(az_all) < math.radians(12))
    skin_front = front & ~np.isin(np.arange(len(fr.co)), vs)
    RF = float(np.median(fw_all[skin_front & (np.abs(h_all - (top_h + tip_h)/2) < 0.03*fr.s)]))
    chin_h = float(h_all[skin_front].min())
    wing_x = float(np.abs(naz).max()*RF)
    eye_h = top_h - 0.22*(top_h - tip_h)
    mouth_h = base_h - 0.40*(base_h - chin_h)
    return dict(RF=RF, top_h=float(top_h), tip_h=float(tip_h), base_h=float(base_h), chin_h=chin_h,
                eye_h=float(eye_h), mouth_h=float(mouth_h), wing_x=wing_x, s=fr.s)

# ---------------------------------------------------------------- UV unwrap
def unwrap(body, rig):
    """returns (per-loop uv list, meta) for the body in the current scene"""
    me = body.data; fr = Frame(body, rig)
    hn = fr.w[:, fr.gi["head"]] + fr.w[:, fr.gi["neck"]]
    head_f = [p.index for p in me.polygons if all(hn[v] >= 0.5 for v in p.vertices)]
    hs = set(head_f)
    names = [g.name for g in body.vertex_groups]
    dom = fr.w.argmax(1)
    hand_f = [p.index for p in me.polygons if p.index not in hs and
              sum(names[dom[v]].startswith(HANDS) for v in p.vertices)*2 > len(p.vertices)]
    hset = set(hand_f)
    body_f = [p.index for p in me.polygons if p.index not in hs and p.index not in hset]
    uv = np.zeros((len(me.loops), 2))

    def smart(faces, box):
        bpy.context.view_layer.objects.active = body
        for o in bpy.context.view_layer.objects: o.select_set(o == body)
        if not me.uv_layers: me.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_mode(type='FACE')
        bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
        fs = set(faces)
        for p in me.polygons: p.select = p.index in fs
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012, area_weight=0.0,
                                 correct_aspect=True, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode='OBJECT')
        lay = me.uv_layers.active.data
        u0, v0, u1, v1 = box
        for fi in faces:
            for li in me.polygons[fi].loop_indices:
                a, b = lay[li].uv; uv[li] = (u0 + a*(u1 - u0), v0 + b*(v1 - v0))

    smart(body_f, BODY_BOX); smart(hand_f, HAND_BOX)
    # head: cylinder about the head axis
    hv = sorted({v for fi in head_f for v in me.polygons[fi].vertices})
    az, h, _ = fr.local(fr.co)
    h0, h1 = float(h[hv].min()), float(h[hv].max())
    for fi in head_f:
        p = me.polygons[fi]; li = list(p.loop_indices); vv = list(p.vertices)
        cen = fr.co[vv].mean(0); caz, _, _ = fr.local(cen[None]); caz = float(caz[0])
        us = []
        for v in vv:
            a = float(az[v])
            d = fr.co[v] - np.array(fr.C); rad = math.hypot(float(d @ np.array(fr.F)), float(d @ np.array(fr.L)))
            if rad < 0.01*fr.s: a = caz                         # crown pole: take the face's azimuth
            a = caz + math.atan2(math.sin(a - caz), math.cos(a - caz))   # unwrap around the face centre (seam at the back)
            us.append(0.5 + float(warp(a))/(2*math.pi))
        for l, v, u in zip(li, vv, us):
            uv[l] = (u, HV0 + (h[v] - h0)/(h1 - h0)*(HV1 - HV0))
    lm = landmarks(fr, me)
    meta = dict(h0=h0, h1=h1, loops=len(me.loops), head=len(head_f), hand=len(hand_f), body=len(body_f), **lm)
    return uv, meta

def set_uv(me, uv):
    while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
    lay = me.uv_layers.new(name="UVMap")
    lay.data.foreach_set("uv", np.asarray(uv, dtype=np.float32).ravel())

# ---------------------------------------------------------------- rasterise the body / hand regions
def rasterise(body, uv):
    """per texel (only bottom half): world position, normal, texels per metre, dominant bone; mask"""
    me = body.data; me.calc_loop_triangles()
    fr = Frame(body, bpy.data.objects["HumanRig"])
    dom = fr.w.argmax(1)
    Hh = N//2
    P = np.zeros((Hh, N, 3)); Nn = np.zeros((Hh, N, 3)); ppm = np.zeros((Hh, N)); bone = np.full((Hh, N), -1, np.int32)
    for t in me.loop_triangles:
        L = list(t.loops); V = list(t.vertices)
        q = np.array([uv[l] for l in L])*N - 0.5
        if q[:, 1].min() > Hh: continue
        x0, y0 = np.floor(q.min(0)).astype(int); x1, y1 = np.ceil(q.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, N - 1), min(y1, Hh - 1)
        if x1 < x0 or y1 < y0: continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = q
        den = (by - cy)*(ax - cx) + (cx - bx)*(ay - cy)
        if abs(den) < 1e-12: continue
        l0 = ((by - cy)*(X - cx) + (cx - bx)*(Y - cy))/den
        l1 = ((cy - ay)*(X - cx) + (ax - cx)*(Y - cy))/den
        l2 = 1 - l0 - l1
        ins = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not ins.any(): continue
        p3 = fr.co[V]; n3 = fr.nrm[V]
        lam = np.stack([l0, l1, l2], -1)[ins]
        yy, xx = Y[ins], X[ins]
        P[yy, xx] = lam @ p3; Nn[yy, xx] = lam @ n3
        a3 = np.linalg.norm(np.cross(p3[1] - p3[0], p3[2] - p3[0]))/2
        a2 = abs(den)/2
        ppm[yy, xx] = math.sqrt(a2/max(a3, 1e-12))
        bone[yy, xx] = dom[np.array(V)[lam.argmax(1)]]
    mask = bone >= 0
    Nn /= np.maximum(np.linalg.norm(Nn, axis=-1, keepdims=True), 1e-9)
    return dict(P=P, N=Nn, ppm=ppm, bone=bone, mask=mask, fr=fr, names=[g.name for g in body.vertex_groups])

def dilate(a, mask, n=6):
    """grow island colours into the gutters so filtering at seams doesn't pull in black"""
    a = a.copy(); m = mask.copy()
    for _ in range(n):
        acc = np.zeros_like(a); cnt = np.zeros(m.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1); sa = np.roll(np.roll(a, dy, 0), dx, 1)
            acc[sm & ~m] += sa[sm & ~m]; cnt[sm & ~m] += 1
        new = (cnt > 0) & ~m
        a[new] = acc[new]/(cnt[new][..., None] if a.ndim == 3 else cnt[new]); m |= new
    return a, m

# ---------------------------------------------------------------- painting helpers (head space, metres)
class Canvas:
    def __init__(self, X, Y):
        self.X, self.Y = X, Y
    def ell(self, cx, cy, rx, ry, soft=0.35):
        d = np.sqrt(((self.X - cx)/rx)**2 + ((self.Y - cy)/ry)**2)
        return 1 - sstep(1 - soft, 1.0, d)
    def seg(self, pts, w):
        """soft line along a polyline, 0..1; pts = [(x, y, k)], k (0..1) tapers strength and width (w = half width, m)"""
        out = np.zeros(self.X.shape)
        for (ax, ay, ak), (bx, by, bk) in zip(pts, pts[1:]):
            x0, x1 = min(ax, bx) - 3*w, max(ax, bx) + 3*w; y0, y1 = min(ay, by) - 3*w, max(ay, by) + 3*w
            box = (self.X > x0) & (self.X < x1) & (self.Y > y0) & (self.Y < y1)
            if not box.any(): continue
            X, Y = self.X[box], self.Y[box]
            dx, dy = bx - ax, by - ay; ll = dx*dx + dy*dy + 1e-12
            t = np.clip(((X - ax)*dx + (Y - ay)*dy)/ll, 0, 1)
            d = np.hypot(X - (ax + t*dx), Y - (ay + t*dy))
            k = ak + (bk - ak)*t
            out[box] = np.maximum(out[box], k*np.exp(-(d/(w*np.maximum(k, 0.25)))**2))
        return out

def curve(f, x0, x1, n=12, w=lambda t: 1.0):
    return [(x0 + (x1 - x0)*i/(n - 1), f(x0 + (x1 - x0)*i/(n - 1)), w(i/(n - 1))) for i in range(n)]

def taper(t): return math.sin(math.pi*min(max(t, 0), 1))**0.7

def mix(col, c, a):
    a = np.clip(a, 0, 1)[..., None]
    return col*(1 - a) + np.asarray(c)*a

# ---------------------------------------------------------------- withered ghost skin (shared by head and body)
def wither(col, hgt, rough, skin, x, y, z=None, k=1.0):
    """leathery dried skin over everything: crinkle folds, fine crackle, dark split cracks, rot blotches, wet sores.
    x, y(, z) in metres divided by the head scale (head: 2D face space; body: 3D surface points)"""
    def co(fx, fy, fz=None):
        return (x*fx, y*fy) if z is None else (x*fx, y*fy, z*(fz if fz is not None else fx))
    # coarse folds: mostly across (sagging), with a second set running down; height in metres
    f1 = ridge(*co(70, 210, 70), seed=61, sharp=14)
    f2 = ridge(*co(190, 60, 190), seed=62, sharp=14)
    dirn = sstep(0.4, 0.6, fbm(*co(9, 9), oct=2, seed=60))           # patches where folds run across / down
    folds = f1*(1 - dirn) + f2*dirn
    hgt = hgt - 0.0008*k*folds
    col = mix(col, skin*0.58, 0.50*folds)
    fine = ridge(*co(520, 520), seed=63, sharp=11)                  # crêpe-paper crackle between the folds
    hgt = hgt - 0.00028*k*fine
    col = mix(col, skin*0.72, 0.28*fine)
    # rot blotches: dark brown, bruised purple, olive-grey
    m = fbm(*co(26, 26), oct=4, seed=66)
    col = mix(col, (0.24, 0.18, 0.15), 0.60*sstep(0.56, 0.74, m))
    col = mix(col, (0.30, 0.22, 0.30), 0.35*sstep(0.62, 0.78, fbm(*co(18, 18), oct=3, seed=68)))
    col = mix(col, (0.44, 0.46, 0.40), 0.25*sstep(0.40, 0.24, m))
    col = mix(col, skin*1.20, 0.25*sstep(0.66, 0.80, fbm(*co(140, 140), oct=2, seed=69)))   # dry flaky spots
    # split cracks through the dried skin, dark red-brown inside
    cr = ridge(*co(300, 300), seed=64, sharp=34)*sstep(0.48, 0.62, fbm(*co(30, 30), oct=2, seed=65))
    col = mix(col, (0.20, 0.06, 0.05), 0.85*cr)
    hgt = hgt - 0.0007*k*cr
    rough = np.where(cr > 0.4, 0.45, rough)
    # open sores: raw red centre, dark rim, wet
    so = fbm(*co(30, 30), oct=3, seed=67)
    rim = sstep(0.78, 0.82, so); core = sstep(0.83, 0.87, so)
    col = mix(col, (0.16, 0.08, 0.06), 0.7*rim)
    col = mix(col, (0.45, 0.07, 0.05), 0.9*core)
    hgt = hgt - 0.0010*k*core + 0.0003*k*(rim - core)
    rough = np.where(core > 0.4, 0.25, rough)
    return col, hgt, rough

# ---------------------------------------------------------------- face painting
# expressions (สีหน้า) for shared/HumanEmotes.SetFace: one whole skin atlas per face (make_face_textures)
#   open: eye opening (0 closed .. 1 normal .. >1 wide), brow: + inner ends up (sad) / - down (angry),
#   smile: + corners up / - down, mouth_open, teeth, tears, dull (dead eyes), pale, blood_head, bruise, blood_arm,
#   ghost: the whole ghost skin (sunken eyes, veins) + scream
FACES = {
    "blink":   dict(open=0.0),
    "squint":  dict(open=0.28, smile=1.0, mouth_open=0.6, teeth=True),
    "dead":    dict(open=0.42, dull=True, mouth_open=0.3, pale=0.35, smile=-0.2),
    "cry":     dict(open=0.32, brow=1.7, smile=-1.5, mouth_open=1.3, teeth=True, tears=True),
    "ghost":   dict(ghost=True, open=1.5, mouth_open=3.0, scream=True),
    "ghost_cry": dict(ghost=True, open=0.5, brow=1.9, smile=-1.6, mouth_open=1.7, tears=True, blood_tears=True),
    "angry":   dict(open=0.72, brow=-1.3, smile=-0.6, mouth_open=0.35, teeth=True),
    "injured": dict(open=0.62, brow=0.6, smile=-0.5, blood_head=True, bruise=True, blood_arm=True),
}

def paint_head(meta, char, ghost, face=None):
    f = FACES.get(face, {}) if face else {}
    lk = LOOK[char]; s = meta["s"]; RF = meta["RF"]; age = lk["age"]
    withered = ghost == "withered"
    if withered: age = 1.2                                            # every old-age wrinkle, a bit deeper
    rows = np.arange(N//2, N); cols = np.arange(N)
    v = (rows + 0.5)/N; u = (cols + 0.5)/N
    hh = meta["h0"] + (v - HV0)/(HV1 - HV0)*(meta["h1"] - meta["h0"])
    az = unwarp((u - 0.5)*2*math.pi)
    X, Y = np.meshgrid(az*RF, hh)
    cv = Canvas(X, Y)
    skin = np.array(WITHERED_SKIN if withered else GHOST_SKIN if ghost else lk["skin"])
    if f.get("pale"): skin = skin*(1 - f["pale"]) + np.array((0.70, 0.72, 0.70))*f["pale"]
    col = np.ones(X.shape + (3,))*skin
    hgt = np.zeros(X.shape); rough = np.full(X.shape, 0.62 if not ghost else 0.85 if withered else 0.72)
    # soft skin variation
    n1 = fbm(X*60, Y*60, oct=4, seed=3) - 0.5
    col *= (1 + 0.06*n1)[..., None]
    hgt += 0.00004*(fbm(X*900, Y*900, oct=2, seed=4) - 0.5)          # pores
    ey, my, bh, th, tip = meta["eye_h"], meta["mouth_h"], meta["base_h"], meta["top_h"], meta["tip_h"]
    es = s*lk["eye"]
    ex = 0.032*s                                                     # eye centres at +-ex
    a, bu, bl = 0.0155*es, 0.0062*es, 0.0044*es                      # eye half width, upper / lower lid height
    op = f.get("open", 1.0)
    bu, bl = bu*op, (bl*min(op*1.15, 1.0) if op < 1 else bl*op)        # expression: lids closing / wide
    brow_y = ey + 0.019*s
    mw = 0.022*s                                                     # half mouth width
    # cheeks / shading
    blush = lk.get("blush", 1.0)
    for sx in (1, -1):
        if not ghost:
            col = mix(col, skin*np.array((1.05, 0.80, 0.76)), 0.22*blush*cv.ell(sx*0.045*s, tip - 0.004*s, 0.022*s, 0.016*s, 1.0))
        col = mix(col, skin*0.86, 0.35*cv.ell(sx*ex, ey + 0.004*s, 0.024*s, 0.016*s, 1.0))   # eye socket
    # shadow band just under the jaw (fades out again before the head / body border so the colours meet)
    cb = meta["chin_h"]
    col *= (1 - (0.10 if not ghost else 0.18)*sstep(cb, cb - 0.012*s, Y)*(1 - sstep(cb - 0.03*s, cb - 0.06*s, Y)))[..., None]
    # ---------------- wrinkles (height, metres; grooves are negative)
    def groove(pts, w, depth): return -depth*cv.seg(pts, w)
    W = 0.0007*s
    if age > 0.05:
        k = age
        # nasolabial folds: from the nose wing down past the mouth corner
        for sx in (1, -1):
            wx = meta["wing_x"] + 0.004*s
            pts = curve(lambda yy: sx*(wx + 0.012*s*((bh - yy)/(bh - my + 1e-6))**1.3), bh + 0.002*s, my - 0.005*s*k, 10,
                        lambda t: taper(t*0.85 + 0.15))
            pts = [(x, y, w) for y, x, w in pts]                     # curve() ran along y here
            hgt += groove(pts, W*(1.2 + 1.2*k), 0.0007*(0.4 + k))
            col = mix(col, skin*0.82, 0.15*k*cv.seg(pts, 0.003*s))
    if age > 0.15:
        k = age
        # forehead lines
        nl = 2 if k < 0.6 else 4
        for i in range(nl):
            y0 = brow_y + (0.016 + 0.009*i)*s
            pts = curve(lambda xx, y0=y0, i=i: y0 + 0.002*s*math.sin(xx/(0.02*s) + i) - 0.004*s*(xx/(0.05*s))**2,
                        -0.048*s, 0.048*s, 16, lambda t: taper(t))
            hgt += groove(pts, W*(0.9 + 0.5*k), 0.0005*k)
    if age > 0.5:
        k = age
        for sx in (1, -1):
            ox, oy = sx*(ex + a*1.05), ey + 0.001*s
            for j, ang in enumerate((-30, -8, 15)):                     # crow's feet
                r = math.radians(ang); L = (0.010 + 0.002*j)*s
                pts = [(ox, oy, 0.3), (ox + sx*L*0.5*math.cos(r), oy + L*0.5*math.sin(r), 1.0), (ox + sx*L*math.cos(r), oy + L*math.sin(r), 0.0)]
                hgt += groove(pts, W*0.8, 0.0005*k)
            # bags under the eyes
            pts = curve(lambda xx: ey - bl - 0.006*s + 0.004*s*((xx - sx*ex)/(a*1.2))**2, sx*ex - a*1.0, sx*ex + a*1.1, 10, taper)
            hgt += groove(pts, W*1.2, 0.0006*k)
            col = mix(col, skin*0.78, 0.30*k*cv.ell(sx*ex, ey - bl - 0.004*s, a*1.1, 0.004*s, 1.0))
            # marionette lines (mouth corner down to the jaw)
            pts = [(sx*(mw + 0.002*s), my - 0.001*s, 0.2), (sx*(mw + 0.004*s), my - 0.010*s, 1.0), (sx*(mw + 0.003*s), my - 0.020*s, 0.0)]
            hgt += groove(pts, W*1.1, 0.0006*k)
        # frown lines between the brows
        for sx in (1, -1):
            hgt += groove([(sx*0.005*s, brow_y - 0.003*s, 0.0), (sx*0.006*s, brow_y + 0.004*s, 1.0), (sx*0.004*s, brow_y + 0.011*s, 0.0)], W, 0.0005*k)
        # lip lines
        for i in range(-4, 5):
            if i == 0: continue
            x = i*0.0048*s
            hgt += groove([(x, my + 0.0005*s, 0.0), (x*1.05, my + 0.006*s, 1.0), (x*1.1, my + 0.010*s, 0.0)], W*0.5, 0.00025*k)
        # neck: horizontal rings + two cords
        nb = meta["chin_h"] - 0.012*s
        for i in range(4):
            yy = nb - (0.013 + 0.011*i)*s
            pts = curve(lambda xx, yy=yy, i=i: yy + 0.002*s*math.sin(xx/(0.012*s) + i*1.7), -0.10*s, 0.10*s, 20, taper)
            hgt += groove(pts, W*1.3, 0.0007*k)
        for sx in (1, -1):   # neck cords
            hgt += 0.0004*k*cv.seg([(sx*0.012*s, nb, 0.0), (sx*0.016*s, nb - 0.025*s, 1.0), (sx*0.022*s, nb - 0.06*s, 0.0)], 0.005*s)
        # age spots
        spots = sstep(0.72, 0.76, fbm(X*420, Y*420, oct=2, seed=11))*cv.ell(0, ey, 0.09*s, 0.06*s, 1.0)
        col = mix(col, skin*np.array((0.78, 0.66, 0.56)), 0.35*k*spots)
    if withered:   # leathery skin first, so the eyes and mouth stay readable on top of it
        col, hgt, rough = wither(col, hgt, rough, skin, X/s, Y/s, None, 1.0)
    # ---------------- eyes
    for sx in (1, -1):
        cx = sx*ex
        dx = (X - cx)/a
        tilt = 0.0012*s*sx*(X - cx)/a                                 # outer corner slightly higher
        up = ey + bu*np.clip(1 - dx**2, 0, None)**0.8 + tilt*sx
        lo = ey - bl*np.clip(1 - dx**2, 0, None)**0.9 + tilt*sx*0.5
        inside = (np.abs(dx) < 1) & (Y < up) & (Y > lo)
        soft = np.clip(np.minimum(up - Y, Y - lo)/(0.0006*s), 0, 1)*inside
        sclera = np.array((0.80, 0.76, 0.70)) if not ghost else np.array((0.86, 0.84, 0.74))
        col = mix(col, sclera, soft)
        ir = 0.0055*es
        if ghost and f.get("scream"):
            icx, icy, ir = cx, ey + 0.0004*s, ir*0.45                     # wide staring eyes, pin-point pupils
            irc = (0.30, 0.28, 0.24)
            veins = ridge(X*900, Y*900, seed=5, sharp=14)*soft*sstep(0.25, 1.0, np.abs(dx))
            col = mix(col, (0.55, 0.12, 0.10), 0.9*veins)
        elif ghost:
            icx, icy, ir = cx + sx*0.0005*s, ey + bu*0.9, ir*0.85        # rolled up under the upper lid
            irc = (0.62, 0.60, 0.52)
            # bloodshot
            veins = ridge(X*900, Y*900, seed=5, sharp=14)*soft*sstep(0.25, 1.0, np.abs(dx))
            col = mix(col, (0.55, 0.12, 0.10), 0.8*veins)
            if withered: icx, icy, ir, irc = cx, ey + 0.0006*s, ir*1.15, (0.80, 0.80, 0.72)   # milky cataract
        elif f.get("dull"):
            icx, icy, irc = cx, ey + 0.0012*s, (0.36, 0.33, 0.30)             # dead: grey, wide pupil, no shine
        else:
            icx, icy, irc = cx, ey + 0.0006*s, (0.20, 0.12, 0.07)
        iris = cv.ell(icx, icy, ir, ir, 0.15)*soft
        ring = np.hypot(X - icx, Y - icy)/ir
        col = mix(col, np.array(irc)*(0.75 + 0.35*ring[..., None].clip(0, 1)), iris)
        pr = 0.62 if f.get("dull") else (0.45 if not ghost else 0.25)
        col = mix(col, (0.02, 0.02, 0.02) if not withered else (0.48, 0.48, 0.43), cv.ell(icx, icy, ir*pr, ir*pr, 0.2)*soft)
        if not ghost and not f.get("dull"):
            col = mix(col, (0.95, 0.95, 0.95), 0.9*cv.ell(icx + sx*0.25*ir - 0.2*ir, icy + 0.35*ir, 0.18*ir, 0.18*ir, 0.4)*soft)  # catchlight
        rough = np.where(inside, 0.12, rough)
        # lash line on the upper lid, thin lower lid line, lid crease above
        lash = lk.get("lash", 1.0)
        d_up = np.abs(Y - up); d_lo = np.abs(Y - lo)
        on = np.abs(dx) < 1.12
        col = mix(col, (0.05, 0.03, 0.03), on*np.exp(-(d_up/(0.0007*s*lash))**2)*0.95)
        wing = cv.seg([(cx + sx*a*0.85, ey + bu*0.25, 1.0), (cx + sx*a*(1.15 + 0.15*lash), ey + bu*0.55, 0.1)], 0.0007*s*lash)
        col = mix(col, (0.05, 0.03, 0.03), wing*0.8)
        col = mix(col, skin*0.55, on*np.exp(-(d_lo/(0.0005*s))**2)*0.6)
        crease = ey + bu*np.clip(1 - (dx*0.9)**2, 0, None)**0.8 + 0.0035*s*(1 + 0.6*age)
        col = mix(col, skin*0.72, (np.abs(dx) < 0.95)*np.exp(-((Y - crease)/(0.0007*s))**2)*0.55)
        hgt += -0.0004*(np.abs(dx) < 0.95)*np.exp(-((Y - crease)/(0.0008*s))**2)
        hgt += 0.0003*inside                                      # eyeball bulges a little past the lids
        # eyebrows: band along an arc, broken into hair strokes
        bw = lk["brow_w"]
        bx0, bx1 = cx - sx*a*0.95, cx + sx*a*1.25
        btilt = f.get("brow", 0.0)*0.0065*s                         # expression: inner end up (+) / down (-)
        def brow_y_at(xx): t = (xx - bx0)/(bx1 - bx0); return brow_y + 0.0035*s*math.sin(math.pi*min(max(t, 0), 1)*0.9) - 0.0025*s*max(t - 0.75, 0)*4 + btilt*(1 - min(max(t, 0), 1))
        pts = [(bx0 + (bx1 - bx0)*i/11, brow_y_at(bx0 + (bx1 - bx0)*i/11), 0.4 + 0.6*math.sin(math.pi*(0.15 + 0.85*i/11))**0.5) for i in range(12)]
        band = cv.seg(pts, 0.0028*s*bw)
        strokes = 0.55 + 0.45*np.sin((X*sx*0.6 + Y)/(0.00055*s)*1.0 + 3*fbm(X*400, Y*400, oct=2, seed=9))
        bcol = np.array(lk["brow"]) if not ghost else np.array((0.10, 0.10, 0.10))
        col = mix(col, bcol, np.clip(band*1.4, 0, 1)*strokes*(0.95 if not ghost else 0.5))
        hgt += 0.00012*band*strokes
        bt = f.get("blood_tears")    # ghost_cry: dark red rims, blood running down to the jaw
        if f.get("tears"):   # cry: red rims, wet streaks down the cheeks
            rim = np.array((0.42, 0.06, 0.08)) if bt else skin*np.array((1.12, 0.70, 0.68))
            col = mix(col, rim, (0.8 if bt else 0.65)*cv.ell(cx, ey, a*1.45, 0.011*s, 1.0)*(1 - soft))
            # squeezed-shut wrinkles at the outer corner
            for k in (-1, 0, 1):
                pts = [(cx + sx*a*1.05, ey + k*0.0025*s, 1.0), (cx + sx*a*1.45, ey + k*0.0045*s, 0.2)]
                col = mix(col, skin*0.72, 0.6*cv.seg(pts, 0.0006*s))
            for j, off in enumerate((-0.45, 0.05, 0.5)):
                x0 = cx + off*a
                nstep = 18 if bt else 12
                pts = [(x0 + 0.0016*s*math.sin(i*0.9 + j), ey - bl - 0.0006*s - i*0.0052*s, 1.0 - 0.7*i/(nstep - 1)) for i in range(nstep)]
                wet = cv.seg(pts, (0.0019 if bt else 0.0016)*s)
                tear = (0.40, 0.02, 0.03) if bt else (0.86, 0.92, 1.0)
                col = mix(col, skin*0.80, 0.35*cv.seg(pts, 0.0028*s))           # wet track darkens the skin
                col = mix(col, tear, 0.9*wet); rough = np.where(wet > 0.3, 0.08, rough)
                drop = pts[-1]
                col = mix(col, tear if bt else (0.90, 0.95, 1.0), 0.9*cv.ell(drop[0], drop[1], 0.0022*s, 0.0028*s, 0.4))
        if f.get("bruise") and sx < 0:   # injured: purple bruise round one eye
            col = mix(col, (0.38, 0.20, 0.34), 0.75*cv.ell(cx, ey, a*1.6, 0.012*s, 1.0)*(1 - soft))
        if ghost:   # dark sunken sockets, black streaks running down from the eyes
            k = 1.6 if withered else 1.0                                  # withered: skull-deep sockets
            col = mix(col, (0.18, 0.16, 0.20) if not withered else (0.10, 0.07, 0.06), 0.55*k*cv.ell(cx, ey, a*1.6*k**0.5, 0.013*s*k**0.5, 1.0)*(1 - soft))
            hgt += -0.0012*k*cv.ell(cx, ey, a*1.7*k**0.5, 0.014*s*k**0.5, 1.0)*(1 - soft)
            for j, off in enumerate((-0.35, 0.1, 0.45)):
                x0 = cx + off*a
                pts = [(x0 + 0.0015*s*math.sin(i*1.3 + j), ey - bl - 0.001*s - i*0.006*s, 1.0 - i/7) for i in range(8)]
                col = mix(col, (0.05, 0.04, 0.05), 0.75*cv.seg(pts, 0.0011*s))
    if f.get("tears") and not f.get("blood_tears"):   # cry: red nose tip
        col = mix(col, skin*np.array((1.15, 0.72, 0.70)), 0.6*cv.ell(0, bh + 0.006*s, 0.012*s, 0.008*s, 1.0))
    # ---------------- nose: nostrils, darker under the tip
    for sx in (1, -1):
        col = mix(col, skin*0.35 if not ghost else (0.15, 0.12, 0.14), cv.ell(sx*0.0075*s, bh + 0.0035*s, 0.0045*s, 0.0025*s, 0.5)*(Y > bh - 0.0005))
    # ---------------- mouth
    lipc = np.array(lk["lip"]) if not ghost else np.array((0.24, 0.15, 0.14) if withered else (0.34, 0.30, 0.36))
    mo = f.get("mouth_open", 0.0); smile = f.get("smile", 0.0)
    if withered: mo = max(mo, 0.8)                                    # shrunken lips pulled back off the teeth
    mw = mw*(0.72 if f.get("scream") else 1.0 + 0.12*max(smile, 0.0))
    xm = np.clip(np.abs(X)/mw, 0, 1.2)
    myx = my + smile*0.007*s*np.clip(xm, 0, 1)**2                     # expression: corners up / down
    gap = mo*0.006*s*np.clip(1 - xm**2, 0, None)**0.5                  # open mouth: lips apart
    bow = 0.0012*s*np.exp(-((X/(0.004*s))**2))                      # cupid's bow dip
    up_lip = myx + gap/2 + 0.0055*s*np.clip(1 - xm**2, 0, None)**0.6 - bow
    lo_lip = myx - gap/2 - 0.0075*s*np.clip(1 - xm**2, 0, None)**0.7
    in_up = (xm < 1) & (Y > myx + gap/2) & (Y < up_lip); in_lo = (xm < 1) & (Y < myx - gap/2) & (Y > lo_lip)
    lips = np.clip(np.minimum(np.abs(Y - myx) - gap/2 + 0.0004*s, np.minimum(np.abs(up_lip - Y), np.abs(Y - lo_lip)))/(0.0012*s), 0, 1)
    col = mix(col, lipc*0.92, in_up*lips*0.85)
    col = mix(col, lipc, in_lo*lips*0.85)
    col = mix(col, lipc*0.45 if not ghost else (0.12, 0.08, 0.10), (xm < 1.05)*np.exp(-((Y - myx)/(0.0006*s))**2)*0.9)
    if mo > 0:   # dark inside, teeth along the top
        inside_m = (xm < 1) & (np.abs(Y - myx) < gap/2)
        col = mix(col, (0.10, 0.04, 0.04) if not ghost else (0.02, 0.01, 0.01), inside_m*0.95)
        if withered:   # long brown-yellow teeth, both rows, dark gaps between them
            gaps = 0.5 + 0.5*np.cos(X/(0.0021*s)*math.pi)
            col = mix(col, np.array((0.60, 0.52, 0.34))*(0.75 + 0.25*gaps[..., None]), inside_m*(np.abs(Y - myx) > gap*0.08)*np.clip(gaps*3, 0, 1)*0.95)
        elif f.get("teeth"):
            col = mix(col, (0.86, 0.83, 0.74), inside_m*(Y > myx + gap/2 - 0.0016*s)*0.95)
    hgt += 0.0004*(in_lo*np.clip((Y - lo_lip)/(0.004*s), 0, 1)) + 0.0002*in_up - 0.0004*(xm < 1.05)*np.exp(-((Y - myx)/(0.0006*s))**2)
    rough = np.where(in_up | in_lo, 0.42, rough)
    if ghost:   # cracked lips, veins on temples / neck / cheeks
        cracks = ridge(X*1400, Y*500, seed=13, sharp=18)*(in_up | in_lo)
        col = mix(col, (0.20, 0.10, 0.12), 0.7*cracks); hgt -= 0.0003*cracks
        vv = ridge(X*150, Y*150, seed=21, sharp=40)*sstep(0.45, 0.6, fbm(X*30, Y*30, oct=2, seed=22))
        temple = sstep(0.035*s, 0.055*s, np.abs(X))*(1 - sstep(0.075*s, 0.10*s, np.abs(X)))*cv.ell(0, ey + 0.01*s, 1.0, 0.035*s, 1.0)
        where = np.clip(temple + sstep(meta["chin_h"], meta["chin_h"] - 0.03*s, Y), 0, 1)
        col = mix(col, (0.32, 0.30, 0.45), 0.55*vv*where); hgt += 0.0004*vv*where
        col *= (1 - 0.18*cv.ell(0, my + 0.01*s, 0.07*s, 0.03*s, 1.0)*(np.abs(X) > 0.03*s))[..., None]   # hollow cheeks
    if withered:   # skin dried onto the skull (crinkle / cracks / sores painted before the eyes, see above)
        for sx in (1, -1):
            temple = cv.ell(sx*0.060*s, ey + 0.012*s, 0.016*s, 0.024*s, 1.0)            # sunken temples
            cheek = cv.ell(sx*0.042*s, my + 0.014*s, 0.017*s, 0.020*s, 1.0)             # cheeks sucked in under the bone
            bone = cv.ell(sx*0.046*s, ey - 0.016*s, 0.024*s, 0.0055*s, 1.0)             # cheekbone shows through
            hgt += -0.0018*(temple + cheek) + 0.0009*bone
            col *= (1 - 0.30*temple - 0.35*cheek)[..., None]
            col = mix(col, skin*1.18, 0.35*bone)
        jaw = sstep(meta["chin_h"] + 0.004*s, meta["chin_h"] - 0.004*s, Y)*sstep(meta["chin_h"] - 0.02*s, meta["chin_h"] - 0.008*s, Y)
        hgt += 0.0006*jaw; col = mix(col, skin*1.1, 0.25*jaw)                            # sharp jaw line
        for sx in (1, -1):                                                               # neck tendons stand out
            cord = cv.seg([(sx*0.014*s, meta["chin_h"] - 0.01*s, 0.3), (sx*0.020*s, meta["chin_h"] - 0.05*s, 1.0), (sx*0.026*s, meta["chin_h"] - 0.10*s, 0.4)], 0.004*s)
            hgt += 0.0012*cord; col = mix(col, skin*1.12, 0.3*cord)
            col = mix(col, skin*0.6, 0.4*cv.seg([(sx*0.006*s, meta["chin_h"] - 0.01*s, 0.3), (sx*0.010*s, meta["chin_h"] - 0.07*s, 1.0)], 0.004*s))
    if f.get("blood_head"):   # injured: split forehead at the hairline, blood running down the temple and cheek
        gx, gy = 0.028*s, brow_y + 0.032*s
        gash = cv.seg([(gx - 0.012*s, gy + 0.004*s, 0.6), (gx, gy, 1.0), (gx + 0.010*s, gy + 0.006*s, 0.5)], 0.0016*s)
        col = mix(col, (0.30, 0.02, 0.02), 0.95*gash)
        col = mix(col, (0.55, 0.06, 0.05), 0.55*cv.ell(gx, gy, 0.018*s, 0.008*s, 1.0))
        for j, (ox, ln) in enumerate(((-0.006, 0.07), (0.003, 0.10), (0.011, 0.05))):
            x0 = gx + ox*s
            pts = [(x0 + 0.002*s*math.sin(i*0.8 + j), gy - i*ln*s/9, 1.0 - 0.6*i/9) for i in range(10)]
            col = mix(col, (0.45, 0.03, 0.03), 0.85*cv.seg(pts, 0.0013*s))
    ppm_y = np.full(X.shape, N*(HV1 - HV0)/(meta["h1"] - meta["h0"]))              # texels per metre
    ppm_x = np.broadcast_to(N*(1 + K_FACE*np.cos(az))/(2*math.pi*RF), X.shape)
    return col, hgt, rough, (ppm_x, ppm_y)

# ---------------------------------------------------------------- body / hand painting
def paint_body(ras, meta, char, ghost, face=None):
    lk = LOOK[char]; age = lk["age"]; fr = ras["fr"]; names = ras["names"]
    withered = ghost == "withered"
    if withered: age = 1.2
    P, Nn, mask, bone = ras["P"], ras["N"], ras["mask"], ras["bone"]
    skin = np.array(WITHERED_SKIN if withered else GHOST_SKIN if ghost else lk["skin"])
    sh = mask.shape
    col = np.ones(sh + (3,))*skin; hgt = np.zeros(sh); rough = np.full(sh, 0.62 if not ghost else 0.85 if withered else 0.72)
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    col *= (1 + 0.07*(fbm(x*25, y*25, z*25, oct=4, seed=2) - 0.5))[..., None]
    hgt += 0.00004*(fbm(x*700, y*700, z*700, oct=2, seed=6) - 0.5)
    bn = np.array(names + ["-"])[bone]
    s = meta["s"]
    def near_joint(jname, child=None):
        J, A = fr.joints[jname]; A = A/np.linalg.norm(A)
        d = P - J; ax = d @ A; rad = np.linalg.norm(d - ax[..., None]*A, axis=-1)
        return ax, rad, A
    # dorsal direction of each hand: across the knuckles x finger direction, pointing up/out
    dorsal = {}
    for side in ("L", "R"):
        hJ, hA = fr.joints["hand." + side]
        across = fr.joints["index_01." + side][0] - fr.joints["pinky_01." + side][0]
        dors = np.cross(hA, across); dors /= np.linalg.norm(dors)
        sgn = 1 if side == "L" else -1
        if dors[0]*sgn + dors[2] < 0: dors = -dors
        dorsal[side] = dors
        nd = Nn @ dors
        handish = np.isin(bn, [f"{f}_0{i}.{side}" for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3)] + ["hand." + side])
        for f in ("index", "middle", "ring", "pinky", "thumb"):
            for i in (1, 2, 3):
                ax, rad, A = near_joint(f"{f}_0{i}.{side}")
                fw = 0.011*s
                near = handish & (rad < fw*1.6) & (np.abs(ax) < 0.012*s)
                if i == 1:            # knuckle: soft bump + a few rings
                    k = near*np.exp(-(ax/(0.006*s))**2)*np.clip(nd, 0, 1)
                    hgt += 0.0006*k
                    col = mix(col, skin*np.array((0.92, 0.82, 0.78)), 0.35*k)
                else:                 # finger joints: creases on top, one line underneath
                    env = near*np.exp(-(ax/(0.0035*s*(1 + 0.4*age)))**2)
                    lines = 0.5 + 0.5*np.cos(ax/(0.0011*s)*math.pi)
                    hgt -= 0.0004*(0.4 + 0.8*age)*env*lines*np.clip(nd, 0, 1)
                    hgt -= 0.0005*near*np.exp(-(ax/(0.0006*s))**2)*np.clip(-nd, 0, 1)
                    col = mix(col, skin*0.85, 0.25*env*np.clip(nd, 0, 1))
                if i == 3:            # nail on the last segment
                    ax3, rad3, A3 = near_joint(f"{f}_03.{side}")
                    J3, Av = fr.joints[f"{f}_03.{side}"]; ln = np.linalg.norm(Av)
                    on = handish & (bn == f"{f}_03.{side}") & (ax3 > 0.40*ln) & (ax3 < 1.05*ln) & (nd > 0.55)
                    if withered:   # long, thick, yellow-brown nails, ridged, dirt under the tip
                        on = handish & (bn == f"{f}_03.{side}") & (ax3 > 0.25*ln) & (nd > 0.35)
                        col = mix(col, np.array((0.36, 0.29, 0.16))*(0.8 + 0.3*np.sin(rad3/(0.0012*s))[..., None]), on*0.95)
                        col = mix(col, (0.08, 0.06, 0.04), on*sstep(0.85*ln, 1.0*ln, ax3))
                    else:
                        col = mix(col, skin*np.array((1.08, 0.96, 0.94)) if not ghost else (0.42, 0.40, 0.38), on*0.85)
                    hgt += 0.00025*on; rough = np.where(on, 0.30, rough)
        # wrist creases (palm side)
        ax, rad, _ = near_joint("hand." + side)
        env = np.isin(bn, ["hand." + side, "forearm." + side])*np.exp(-((ax + 0.004*s)/(0.004*s))**2)*np.clip(-nd, 0, 1)
        hgt -= 0.0005*env*(0.5 + 0.5*np.cos(ax/(0.0022*s)*math.pi))
        # back of the hand: veins and fine crosshatch for the old, veins for ghosts
        back = np.isin(bn, ["hand." + side, "forearm." + side])*np.clip(nd*1.5, 0, 1)
        if age > 0.5 or ghost:
            vv = ridge(x*70, y*70, z*25, seed=31 + (side == "R"), sharp=30)*back
            hgt += 0.0007*vv*(age if not ghost else 1.0)
            col = mix(col, (0.40, 0.40, 0.55) if ghost else skin*np.array((0.85, 0.85, 0.95)), (0.5 if ghost else 0.25)*vv)
        if age > 0.5:
            cross = (np.abs(np.sin((x + z)*2200)) * np.abs(np.sin((x - z)*1900 + y*900)))
            hgt -= 0.00012*age*cross*np.isin(bn, ["hand." + side])
            spots = sstep(0.72, 0.76, fbm(x*500, y*500, z*500, oct=2, seed=41))*back
            col = mix(col, skin*np.array((0.78, 0.66, 0.56)), 0.35*age*spots)
        # elbow (back) and knee (front) folds
        ax, rad, _ = near_joint("forearm." + side)
        e = (rad < 0.06*s)*np.exp(-(ax/(0.018*s))**2)*np.clip(Nn @ np.array((0, 1, 0.3)), 0, 1)
        hgt -= 0.0006*(0.2 + age)*e*(0.5 + 0.5*np.cos(ax/(0.0045*s)*math.pi))
        col = mix(col, skin*0.88, 0.3*e)
        ax, rad, _ = near_joint("shin." + side)
        kk = (rad < 0.08*s)*np.exp(-((ax - 0.01*s)/(0.020*s))**2)*np.clip(Nn @ np.array((0, -1, 0)), 0, 1)
        hgt -= 0.0005*(0.2 + age)*kk*(0.5 + 0.5*np.cos(ax/(0.006*s)*math.pi))
        col = mix(col, skin*0.90, 0.25*kk)
        # toe tips: nails, sole lighter
        ft = bn == "toe." + side
        tJ, tA = fr.joints["toe." + side]
        tax = (P - tJ) @ (tA/np.linalg.norm(tA))
        nail = ft & (Nn[..., 2] > 0.5) & (tax > np.linalg.norm(tA)*0.55)
        col = mix(col, skin*np.array((1.06, 0.95, 0.92)) if not ghost else (0.42, 0.40, 0.38), nail*0.7)
    sole = np.isin(bn, ["foot.L", "foot.R", "toe.L", "toe.R"])*np.clip(-Nn[..., 2], 0, 1)
    col = mix(col, skin*np.array((1.06, 0.98, 0.95)), 0.5*sole)
    if face and FACES.get(face, {}).get("blood_arm"):   # injured: grazes and blood down the left arm
        arm_ = np.isin(bn, ["forearm.L", "upper_arm.L", "hand.L"])
        graze = sstep(0.52, 0.62, fbm(x*45, y*45, z*45, oct=3, seed=71))*arm_
        col = mix(col, (0.50, 0.05, 0.04), 0.85*graze)
        drip = sstep(0.75, 0.80, ridge(x*18, y*60, z*18, seed=73, sharp=20))*arm_
        col = mix(col, (0.40, 0.03, 0.03), 0.7*drip)
    if ghost:   # veins over the arms, chest, neck; dirty grey-green mottling
        vv = ridge(x*22, y*22, z*22, seed=51, sharp=55)*sstep(0.62, 0.70, fbm(x*6, y*6, z*6, oct=2, seed=53))
        col = mix(col, (0.36, 0.34, 0.48), 0.35*vv); hgt += 0.0003*vv
        col = mix(col, (0.45, 0.48, 0.42), 0.12*fbm(x*8, y*8, z*8, oct=3, seed=52))
    if withered:   # dried skin; ribs and sternum showing, knuckles and tendons on the back of the hands
        col, hgt, rough = wither(col, hgt, rough, skin, x/s, y/s, z/s, 1.0)
        torso = np.isin(bn, ["chest", "spine"])*mask
        front = np.clip(0.6 - Nn[..., 1], 0, 1)                             # front and sides (front faces -Y)
        cJ = fr.joints["chest"][0]
        ribz = (z - cJ[2])/s
        rib = 0.5 + 0.5*np.cos((ribz/0.034 - 0.15*(np.abs(x - cJ[0])/s)/0.034)*2*math.pi)   # ribs slope down to the sides
        rib = sstep(0.55, 0.95, rib)*torso*front*sstep(0.010, 0.022, np.abs(x - cJ[0])/s)
        hgt += -0.0016*rib; col = mix(col, (0.18, 0.13, 0.11), 0.45*rib)
        stern = torso*front*np.exp(-((x - cJ[0])/(0.006*s))**2)
        hgt += -0.0010*stern; col = mix(col, skin*0.6, 0.35*stern)
        for side in ("L", "R"):   # tendons fanning from the wrist to each knuckle
            hJ, hA = fr.joints["hand." + side]
            for f in ("index", "middle", "ring", "pinky"):
                K, _ = fr.joints[f"{f}_01.{side}"]
                d = K - hJ; ll = float(d @ d) + 1e-12
                t = np.clip(((P - hJ) @ d)/ll, 0, 1)
                dist = np.linalg.norm(P - (hJ + t[..., None]*d), axis=-1)
                ten = np.isin(bn, ["hand." + side])*np.exp(-(dist/(0.0028*s))**2)*np.clip(Nn @ dorsal[side], 0, 1)
                hgt += 0.0008*ten; col = mix(col, skin*1.15, 0.3*ten)
    return col, hgt, rough

# ---------------------------------------------------------------- textures
def normal_from_height(hgt, ppm_x, ppm_y, strength=1.0):
    gy, gx = np.gradient(hgt)
    nx, ny = -gx*ppm_x*strength, -gy*ppm_y*strength
    ln = np.sqrt(nx**2 + ny**2 + 1)
    return np.stack([nx/ln, ny/ln, 1/ln], -1)*0.5 + 0.5

def save_png(arr, path, noncolor):
    if arr.ndim == 2: arr = np.stack([arr]*3, -1)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones(arr.shape[:2] + (1,))], -1).astype(np.float32)
    name = os.path.splitext(os.path.basename(path))[0]
    img = bpy.data.images.get(name)
    if img: bpy.data.images.remove(img)
    img = bpy.data.images.new(name, arr.shape[1], arr.shape[0], alpha=False)
    if noncolor: img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.ravel()); img.filepath_raw = path; img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)

def make_textures(char, uv, meta, body, variants=(False, True, "withered")):
    ras = rasterise(body, uv)
    out = {}
    for ghost in variants:
        hc, hh, hr, hp = paint_head(meta, char, ghost)
        bc, bh, br = paint_body(ras, meta, char, ghost)
        bc, _ = dilate(bc, ras["mask"]); bh, _ = dilate(bh, ras["mask"]); br, _ = dilate(br, ras["mask"])
        bp, _ = dilate(ras["ppm"], ras["mask"])
        col = np.concatenate([bc, hc], 0); hgt = np.concatenate([bh, hh], 0)
        bp = np.maximum(bp, 1.0)
        rgh = np.concatenate([br, hr], 0)
        nrm = normal_from_height(hgt, np.concatenate([bp, hp[0]], 0), np.concatenate([bp, hp[1]], 0))
        nrm[N//2 - 1:N//2 + 1] = (0.5, 0.5, 1.0)                     # no gradient across the head / body border
        base = os.path.join(char_dir(char), NAMES[char] + ("_Withered" if ghost == "withered" else "_Ghost" if ghost else ""))
        save_png(col, base + "_Color.png", False); save_png(nrm, base + "_Normal.png", True); save_png(rgh, base + "_Roughness.png", True)
        out[ghost] = base
    return out

def make_face_textures(char, uv, meta, body, out_dir=None, faces=None):
    """one Color atlas per expression (FACES) -> <char dir>/faces/<name>_face_<face>_Color.png (normal / roughness:
    use the plain set, or the _Ghost set for "ghost"). Also writes faces_preview.png: the face of each, side by side"""
    out_dir = out_dir or os.path.join(char_dir(char), "faces"); os.makedirs(out_dir, exist_ok=True)
    ras = rasterise(body, uv)
    bodies = {}
    tiles = []
    for face in (faces or list(FACES)):
        f = FACES[face]; gh = bool(f.get("ghost"))
        key = (gh, bool(f.get("blood_arm")))
        if key not in bodies:
            bc, _, _ = paint_body(ras, meta, char, gh, face if f.get("blood_arm") else None)
            bc, _ = dilate(bc, ras["mask"]); bodies[key] = bc
        hc, _, _, _ = paint_head(meta, char, gh, face)
        col = np.concatenate([bodies[key], hc], 0)
        save_png(col, os.path.join(out_dir, f"{NAMES[char]}_face_{face}_Color.png"), False)
        H = hc.shape[0]; c0 = N//2                                   # preview: front of the head, brow to chin
        tiles.append(hc[int(H*0.30):int(H*0.80), c0 - N//10:c0 + N//10])
    save_png(np.concatenate(tiles, 1), os.path.join(out_dir, "faces_preview.png"), False)
    return out_dir

def faces_char(char):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(char), NAMES[char] + ".blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    uv, meta = unwrap(body, rig)
    return make_face_textures(char, uv, meta, body)

# ---------------------------------------------------------------- materials
def skin_material(name, base):
    m = bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes.get("Principled BSDF")
    def tex(suffix, noncolor, loc):
        path = base + suffix + ".png"
        img = bpy.data.images.load(path, check_existing=True)
        img.reload()
        if noncolor: img.colorspace_settings.name = "Non-Color"
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img; n.location = loc; return n
    c = tex("_Color", False, (-500, 300)); nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    r = tex("_Roughness", True, (-500, 0)); nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    n = tex("_Normal", True, (-700, -300)); nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
    nt.links.new(n.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.08
    m.diffuse_color = (*LOOK.get(name, {}).get("skin", (0.8, 0.62, 0.5)), 1)
    return m

def add_skin(char):
    """UVs + Skin (shown) and SkinGhost (spare, fake user) materials on the Body in the current scene"""
    body = bpy.data.objects["Body"]
    d = json.load(open(os.path.join(char_dir(char), NAMES[char] + "_uv.json")))
    if d["loops"] != len(body.data.loops): raise RuntimeError(f"{char}: UV file is for {d['loops']} loops, body has {len(body.data.loops)}")
    set_uv(body.data, np.array(d["uv"]).reshape(-1, 2))
    base = os.path.join(char_dir(char), NAMES[char])
    sk = skin_material("Skin", base); gh = skin_material("SkinGhost", base + "_Ghost"); gh.use_fake_user = True
    wi = skin_material("SkinWithered", base + "_Withered"); wi.use_fake_user = True
    body.data.materials.clear(); body.data.materials.append(sk)

def skin_char(char, save=True):
    files = blend_files(char)
    normal = os.path.join(char_dir(char), NAMES[char] + ".blend")
    bpy.ops.wm.open_mainfile(filepath=normal)
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    uv, meta = unwrap(body, rig)
    json.dump(dict(meta, uv=[round(float(a), 5) for a in uv.ravel()]), open(os.path.join(char_dir(char), NAMES[char] + "_uv.json"), "w"))
    set_uv(body.data, uv)
    make_textures(char, uv, meta, body)
    if save:
        bpy.context.preferences.filepaths.save_version = 0
        for f in files:
            bpy.ops.wm.open_mainfile(filepath=f); add_skin(char)
            bpy.ops.wm.save_mainfile(relative_remap=True)
    return meta

def withered_char(char, save=True):
    """only the _Withered set, painted on the UVs stored in <name>_uv.json (no re-unwrap, so the plain / ghost
    textures and anything exported with them stay valid); adds SkinWithered to every .blend of the character"""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(char), NAMES[char] + ".blend"))
    body = bpy.data.objects["Body"]
    d = json.load(open(os.path.join(char_dir(char), NAMES[char] + "_uv.json")))
    if d["loops"] != len(body.data.loops): raise RuntimeError(f"{char}: UV file is for {d['loops']} loops, body has {len(body.data.loops)}")
    uv = np.array(d["uv"]).reshape(-1, 2)
    set_uv(body.data, uv)
    meta = {k: np.float64(v) if isinstance(v, float) else v for k, v in d.items() if k != "uv"}   # as unwrap() gives them
    make_textures(char, uv, meta, body, variants=("withered",))
    if save:
        bpy.context.preferences.filepaths.save_version = 0
        for f in blend_files(char):
            bpy.ops.wm.open_mainfile(filepath=f); add_skin(char)
            bpy.ops.wm.save_mainfile(relative_remap=True)

def skin_all(save=True):
    return {c: skin_char(c, save) for c in DIRS.values()}

# ---------------------------------------------------------------- preview (EEVEE): rows human / ghost, columns face front, 3-4, side, hand
def preview(char, out, hair=False):
    sc = bpy.context.scene; body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    fr = Frame(body, rig); s = fr.s
    for o in sc.objects:
        if o.name.startswith("Hair_"): o.hide_render = not hair or o.hide_get()
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.render.resolution_x = sc.render.resolution_y = 420; sc.render.film_transparent = False
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = w
    w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.26, 0.28, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    temps = []
    def light(name, typ, rot, energy):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, typ)); l.data.energy = energy
        l.rotation_euler = rot; sc.collection.objects.link(l); temps.append(l); return l
    light("_key", 'SUN', (math.radians(55), 0, math.radians(-35)), 3.5)
    light("_fill", 'SUN', (math.radians(70), 0, math.radians(60)), 1.0)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); temps.append(cam)
    sc.camera = cam; cam.data.lens = 85
    C = np.array(fr.C)
    hJ = fr.joints["hand.L"][0] + fr.joints["hand.L"][1]*0.9
    shots = [(C, (0, -1, 0.05), 0.55*s), (C, (0.7, -0.7, 0.05), 0.55*s), (C, (1, 0, 0.05), 0.55*s), (hJ, (1, 0.2, 0.8), 0.45*s)]
    tiles = []
    for mname in ("Skin", "SkinGhost", "SkinWithered"):
        body.data.materials[0] = bpy.data.materials[mname]
        row = []
        for c_, d_, dist in shots:
            d_ = Vector(d_).normalized(); tgt = Vector(c_)
            cam.location = tgt + d_*dist*2.2
            cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
            tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
            row.append(a.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
        tiles.append(np.concatenate(row, 1))
    body.data.materials[0] = bpy.data.materials["Skin"]
    sheet = np.concatenate(tiles[::-1], 0)
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    for o in temps: bpy.data.objects.remove(o, do_unlink=True)

def preview_all(chars=None, out_dir=os.path.join(M, "skin_previews")):
    os.makedirs(out_dir, exist_ok=True)
    for c in chars or DIRS.values():
        bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(c), NAMES[c] + ".blend"))
        if "SkinWithered" not in bpy.data.materials: add_skin(c)
        preview(c, os.path.join(out_dir, NAMES[c] + ".png"))

if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    chars = [a for a in argv if a in LOOK] or None
    if "--save" in argv:
        for c in chars or DIRS.values(): skin_char(c)
    if "--preview" in argv: preview_all(chars)
    if "--faces" in argv:
        for c in chars or ["male"]: faces_char(c)
