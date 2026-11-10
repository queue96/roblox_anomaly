# Villager v2: UVs for the 3 parts (one 1024 texture each) + painted test characters.
#   blender -b --factory-startup --python paint.py -- <render_out_dir> [male|female] [--save]
#
# UV (one UV map; the 3 parts each fill 0..1 of their own texture — they are separate MeshParts in Roblox)
#   head  (part 0): cylinder around the head bone, face in the middle, seam at the back of the head — the same mapping as
#                   the old skin (human_base/build_skin.py unwrap) so its face painter (paint_head) is reused as is
#   upper (part 1): torso + arms smart-projected into v 0.26..1, hands into v 0..0.25 (more texels for nails/knuckles)
#   lower (part 2): hips + legs into v 0.21..1, feet / shoes into v 0..0.20
# Painting: skin, face, wrinkles, knuckles, nails = the old painters (paint_head / paint_body) on these UVs,
#           clothes = painted over the skin here (shirt, trousers, shoes), see PRESETS.
# Colour textures are RGBA: alpha 1 = skin (tinted in game by SurfaceAppearance.Color in TintMask mode), 0 = cloth / eyes.
# Skin is painted in one light tone (SKIN_BASE); every skin colour in game = this x the tint (renders here do the same).
# Output: textures/<preset>_<part>_Color.png (RGBA), _Normal.png, _Roughness.png · with --save the UVs go into villager_<char>.blend
import bpy, bmesh, os, sys, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)); MODELS = os.path.dirname(HERE); OLD = os.path.join(MODELS, "human_base")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(HERE, "design"); os.makedirs(OUT, exist_ok=True)
CHAR = "female" if "female" in argv[1:] else "male"
TEX = os.path.join(HERE, "textures"); os.makedirs(TEX, exist_ok=True)
SC = {"male": 1.0, "female": 0.93}[CHAR]
RES = 1024
SKIN_BASE = (0.90, 0.73, 0.61)           # lightest tone; tints only darken
PART_NAMES = ("head", "upper", "lower")
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

# ---------------------------------------------------------------- test characters
# hem = height (m, male scale) where trousers end; sleeve = 0 shoulder .. 0.52 elbow .. 1 wrist
# lower = "body" (the Body's own legs, default) / "wide" (Lower_wide) / "skirt" (Lower_skirt + skirt=dict(tile, mode))
#   skirt tiles from assets/models/clothes_tex: mode "sin" = v runs hem -> waist (the decorated foot of the sin stays at
#   the hem), "plaid" = tiles every 0.32 m both ways
PRESETS = {
    "male": [
        dict(name="m_farmer", look="male", tint=(0.84, 0.73, 0.64), hair="student",
             shirt=dict(color=(0.13, 0.16, 0.30), sleeve=0.62, neck="round", buttons=True, pocket=True),
             pants=dict(color=(0.09, 0.10, 0.17), hem=0.33), shoe=("sandal", (0.15, 0.25, 0.55))),
        dict(name="m_redshirt", look="male", tint=(0.95, 0.89, 0.83), hair="side_part",
             shirt=dict(color=(0.55, 0.08, 0.07), sleeve=0.97, neck="v", trim=(0.04, 0.04, 0.04)),
             lower="wide", pants=dict(color=(0.05, 0.05, 0.06), hem=0.105), shoe=("sneaker", (0.06, 0.06, 0.06), (0.85, 0.85, 0.83))),
        dict(name="m_teen", look="male", tint=(0.72, 0.60, 0.52), hair="rong_song_sung",
             shirt=dict(color=(0.42, 0.43, 0.45), sleeve=0.30, neck="round"),
             pants=dict(color=(0.16, 0.25, 0.42), hem=0.105, denim=True), shoe=("sneaker", (0.88, 0.88, 0.86), (0.95, 0.95, 0.93))),
        dict(name="m_elder", look="elder_male", tint=(0.82, 0.70, 0.60), hair="bald_grey",
             shirt=dict(color=(0.86, 0.85, 0.80), sleeve=0.97, neck="round", buttons=True, pocket=True),
             lower="skirt", skirt=dict(tile="plaid_red", mode="plaid"), pants=None, shoe=("sandal", (0.08, 0.08, 0.08))),
    ],
    "female": [
        dict(name="f_blouse", look="female", tint=(0.95, 0.89, 0.83), hair="bob",
             shirt=dict(color=(0.22, 0.55, 0.48), sleeve=0.97, neck="round", buttons=True),
             lower="skirt", skirt=dict(tile="sin_purple", mode="sin"), pants=None, shoe=("sandal", (0.38, 0.22, 0.12))),
        dict(name="f_indigo", look="female", tint=(0.84, 0.73, 0.64), hair="ponytail_bow",
             shirt=dict(color=(0.12, 0.15, 0.32), sleeve=0.62, neck="round"),
             pants=dict(color=(0.16, 0.25, 0.42), hem=0.105, denim=True), shoe=("sneaker", (0.88, 0.88, 0.86), (0.95, 0.95, 0.93))),
        dict(name="f_tee", look="female", tint=(0.72, 0.60, 0.52), hair="bob",
             shirt=dict(color=(0.07, 0.07, 0.08), sleeve=0.30, neck="round"),
             lower="wide", pants=dict(color=(0.74, 0.46, 0.55), hem=0.105), shoe=("sandal", (0.80, 0.40, 0.55))),
        dict(name="f_elder", look="elder_female", tint=(0.86, 0.75, 0.66), hair="bun_grey",
             shirt=dict(color=(0.86, 0.80, 0.66), sleeve=0.97, neck="round", buttons=True),
             lower="skirt", skirt=dict(tile="sin_ikat", mode="sin"), pants=None, shoe=("sandal", (0.08, 0.08, 0.08))),
    ],
}[CHAR]

def load_ns(path, extra=None):
    ns = {"__name__": "lib", "__file__": path}
    if extra: ns.update(extra)
    src = open(path, encoding="utf-8").read().replace("col = mix(col, skin*0.35 if not ghost", "pass # no nostril dots: col = mix(col, skin*0.35 if not ghost"); exec(compile(src, path, "exec"), ns)
    ns["M"] = MODELS
    return ns

# ---------------------------------------------------------------- UVs
def faces_of(me, k):
    a = me.attributes["part"].data
    return [p.index for p in me.polygons if a[p.index].value == k]

def smart(body, faces, box, uv):
    me = body.data
    bpy.context.view_layer.objects.active = body
    for o in bpy.context.view_layer.objects: o.select_set(o == body)
    if not me.uv_layers: me.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_mode(type='FACE')
    bpy.ops.mesh.select_all(action='DESELECT'); bpy.ops.object.mode_set(mode='OBJECT')
    fs = set(faces)
    for p in me.polygons: p.select = p.index in fs
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.010, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    lay = me.uv_layers.active.data
    u0, v0, u1, v1 = box
    for fi in faces:
        for li in me.polygons[fi].loop_indices:
            a, b = lay[li].uv; uv[li] = (u0 + a*(u1 - u0), v0 + b*(v1 - v0))

def head_uv(sk, fr, me, faces, uv):
    """old cylinder mapping (u = warped azimuth, face at 0.5) with v stretched over the whole texture"""
    hv = sorted({v for fi in faces for v in me.polygons[fi].vertices})
    az, h, _ = fr.local(fr.co)
    h0, h1 = float(h[hv].min()), float(h[hv].max())
    for fi in faces:
        p = me.polygons[fi]; vv = list(p.vertices)
        cen = fr.co[vv].mean(0); caz = float(fr.local(cen[None])[0][0])
        for l, v in zip(p.loop_indices, vv):
            a = float(az[v]); d = fr.co[v] - np.array(fr.C)
            if math.hypot(float(d @ np.array(fr.F)), float(d @ np.array(fr.L))) < 0.01*fr.s: a = caz
            a = caz + math.atan2(math.sin(a - caz), math.cos(a - caz))
            t = (h[v] - h0)/(h1 - h0)
            uv[l] = (0.5 + float(sk["warp"](a))/(2*math.pi), 2*(sk["HV0"] + t*(sk["HV1"] - sk["HV0"])) - 1)
    return h0, h1

def face_landmarks(fr, h0, h1):
    """the old landmarks() measured the nose piece; the new head is smooth, so use where the old nose was"""
    dz = 0.012 if CHAR == "male" else 0.0
    nose = [(0, -0.097, 1.703), (0, -0.108, 1.668), (0, -0.116, 1.648), (0, -0.104, 1.636), (0, -0.090, 1.660)]
    for sx in (1, -1): nose += [(0.012*sx, -0.099, 1.668), (0.018*sx, -0.098, 1.640)]
    nose = np.array([(x*SC, y*SC, (z - dz)*SC) for x, y, z in nose])
    naz, nh, nfw = fr.local(nose)
    top_h, base_h = float(nh.max()), float(nh.min()); tip_h = float(nh[np.argmax(nfw)])
    az, h, fw = fr.local(fr.co)
    hw = fr.w[:, fr.gi["head"]] > 0.99
    front = hw & (np.abs(az) < math.radians(12))
    RF = float(np.median(fw[front & (np.abs(h - (top_h + tip_h)/2) < 0.03*fr.s)]))
    chin_h = float(h[front].min())
    return dict(h0=h0, h1=h1, s=fr.s, RF=RF, top_h=top_h, tip_h=tip_h, base_h=base_h, chin_h=chin_h,
                eye_h=top_h - 0.22*(top_h - tip_h), mouth_h=base_h - 0.40*(base_h - chin_h), wing_x=float(np.abs(naz).max()*RF))

# ---------------------------------------------------------------- rasterise one part into its own texture
class ObjFrame:
    """what rasterise / paint_body need from build_skin.Frame, for a lower variant object (joints from the Body)"""
    def __init__(self, ob, fr):
        me = ob.data; mw = ob.matrix_world
        self.gi = {g.name: g.index for g in ob.vertex_groups}; self.joints = fr.joints
        self.w = np.zeros((len(me.vertices), len(ob.vertex_groups)), np.float32)
        for v in me.vertices:
            for g in v.groups: self.w[v.index, g.group] = g.weight
        self.co = np.array([tuple(mw @ v.co) for v in me.vertices])
        self.nrm = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in me.vertices])

def rasterise(body, fr, uv, faces):
    me = body.data; me.calc_loop_triangles()
    dom = fr.w.argmax(1); fs = set(faces); n = RES
    P = np.zeros((n, n, 3)); Nn = np.zeros((n, n, 3)); ppm = np.zeros((n, n)); bone = np.full((n, n), -1, np.int32)
    fidx = np.full((n, n), -1, np.int32)
    for t in me.loop_triangles:
        if t.polygon_index not in fs: continue
        V = list(t.vertices); q = np.array([uv[l] for l in t.loops])*n - 0.5
        x0, y0 = np.floor(q.min(0)).astype(int); x1, y1 = np.ceil(q.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, n - 1), min(y1, n - 1)
        if x1 < x0 or y1 < y0: continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = q
        den = (by - cy)*(ax - cx) + (cx - bx)*(ay - cy)
        if abs(den) < 1e-12: continue
        l0 = ((by - cy)*(X - cx) + (cx - bx)*(Y - cy))/den; l1 = ((cy - ay)*(X - cx) + (ax - cx)*(Y - cy))/den; l2 = 1 - l0 - l1
        ins = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)
        if not ins.any(): continue
        p3 = fr.co[V]; n3 = fr.nrm[V]; lam = np.stack([l0, l1, l2], -1)[ins]; yy, xx = Y[ins], X[ins]
        P[yy, xx] = lam @ p3; Nn[yy, xx] = lam @ n3
        a3 = np.linalg.norm(np.cross(p3[1] - p3[0], p3[2] - p3[0]))/2
        ppm[yy, xx] = math.sqrt((abs(den)/2)/max(a3, 1e-12))
        bone[yy, xx] = dom[np.array(V)[lam.argmax(1)]]; fidx[yy, xx] = t.polygon_index
    Nn /= np.maximum(np.linalg.norm(Nn, axis=-1, keepdims=True), 1e-9)
    return dict(P=P, N=Nn, ppm=ppm, bone=bone, mask=bone >= 0, fr=fr, names=list(fr.gi.keys()), face=fidx)

# ---------------------------------------------------------------- clothes painted over the skin
def soft(x, w): return np.clip(0.5 + x/max(w, 1e-6), 0, 1)

def fabric(col, P, spec, sel, seed):
    c = np.array(spec["color"]); x, y, z = P[..., 0], P[..., 1], P[..., 2]
    tone = 1 + 0.10*(sk["fbm"](x*30, y*30, z*30, oct=3, seed=seed) - 0.5) + 0.035*(sk["fbm"](x*260, y*260, z*260, oct=2, seed=seed + 1) - 0.5)
    cloth = c*tone[..., None]
    if spec.get("denim"):
        tw = 0.5 + 0.5*np.sin((x + y + z)*1400.0)
        cloth = cloth*(0.92 + 0.10*tw)[..., None] + 0.05*sk["fbm"](x*90, y*90, z*90, oct=2, seed=seed + 2)[..., None]
    return np.where(sel[..., None], cloth, col)

def paint_shirt(ras, col, hgt, rough, alpha, spec):
    P, Nn, bn = ras["P"], ras["N"], np.array(ras["names"] + ["-"])[ras["bone"]]
    fr = ras["fr"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]; m = ras["mask"]
    hand = np.array([b.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")) for b in bn.ravel()]).reshape(bn.shape)
    arm = np.array([b.startswith(("upper_arm", "forearm")) for b in bn.ravel()]).reshape(bn.shape)
    shirt = m & ~hand
    for side, sx in (("L", 1), ("R", -1)):
        S = fr.joints["upper_arm." + side][0]; W = fr.joints["hand." + side][0]; d = W - S
        ta = ((P - S) @ d)/float(d @ d)
        this = arm & (np.sign(x) == sx)
        shirt &= ~(this & (ta > spec["sleeve"]))
        cuff = this & (np.abs(ta - spec["sleeve"]) < 0.025) & (ta <= spec["sleeve"])
        col = np.where(cuff[..., None], col*0.82, col)
    zn = 1.510*SC                                                   # neck seam (front)
    front = (y < 0)
    if spec.get("neck") == "v":
        depth = 0.10*SC*np.clip(1 - np.abs(x)/(0.065*SC), 0, 1)
    else:
        depth = 0.018*SC*np.clip(1 - (x/(0.07*SC))**2, 0, 1)
    opening = shirt & front & (z > zn - depth) & ~arm
    trim = shirt & front & ~arm & (z > zn - depth - 0.012*SC) & ~opening & (depth > 0.004*SC)
    shirt &= ~opening
    col = fabric(col, P, spec, shirt, 11)
    if spec.get("trim") is not None: col = np.where(trim[..., None], np.array(spec["trim"]), col)
    else: col = np.where(trim[..., None], col*0.85, col)
    if spec.get("buttons"):
        placket = shirt & front & (np.abs(x) < 0.007*SC) & (z < zn - depth.max()*0.6) & (z > 1.07*SC)
        col = np.where(placket[..., None], col*0.86, col)
        for k in range(6):
            bz = (1.44 - 0.07*k)*SC
            dot = shirt & front & (np.hypot(x, z - bz) < 0.0055*SC)
            col = np.where(dot[..., None], np.array((0.88, 0.86, 0.80)) if np.mean(spec["color"]) < 0.5 else np.array((0.55, 0.53, 0.50)), col)
            hgt += 0.0004*dot
    if spec.get("pocket"):
        px0, px1, pz0, pz1 = 0.035*SC, 0.095*SC, 1.29*SC, 1.37*SC
        inside = shirt & front & (x > px0) & (x < px1) & (z > pz0) & (z < pz1)
        edge = inside & ((x - px0 < 0.004) | (px1 - x < 0.004) | (z - pz0 < 0.004) | (pz1 - z < 0.006))
        col = np.where(edge[..., None], col*0.75, col); hgt -= 0.0003*edge
    hem = shirt & (z < 1.080*SC) & ~arm
    col = np.where(hem[..., None], col*0.88, col)
    rough = np.where(shirt, 0.88, rough); alpha = np.where(shirt, 0.0, alpha)
    return col, hgt, rough, alpha

def paint_lower(ras, col, hgt, rough, alpha, pants, shoe):
    P, m = ras["P"], ras["mask"]; Nn = ras["N"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    hem = pants["hem"]*SC if pants else 9.0
    tr = m & (z > hem) & (ras["only"] if "only" in ras else True)
    if pants: col = fabric(col, P, pants, tr, 21)
    band = tr & (z > 1.025*SC); col = np.where(band[..., None], col*0.80, col)
    hemband = tr & (z < hem + 0.018*SC); col = np.where(hemband[..., None], col*0.82, col)
    fly = tr & (y < 0) & (np.abs(x) < 0.006*SC) & (z > 0.86*SC) & (z < 1.0*SC); col = np.where(fly[..., None], col*0.78, col)
    if pants and pants.get("denim"):   # thin orange stitch down the outer side of each leg
        fr = ras["fr"]
        for side, sx in (("L", 1), ("R", -1)):
            A = fr.joints["thigh." + side][0]; B = fr.joints["shin." + side][0] + fr.joints["shin." + side][1]
            ab = B - A; t = np.clip(((P - A) @ ab)/float(ab @ ab), 0, 1)
            d = P - (A + t[..., None]*ab)
            seam = tr & (np.sign(x) == sx) & (d[..., 0]*sx > 0.02*SC) & (np.abs(d[..., 1]) < 0.0022*SC) & (z < 0.86*SC)
            col = np.where(seam[..., None], np.array((0.62, 0.42, 0.18)), col)
    rough = np.where(tr, 0.9, rough); alpha = np.where(tr, 0.0, alpha)
    kind = shoe[0]; c = np.array(shoe[1])
    fx = 0.098*SC if CHAR == "male" else 0.092*SC
    lx = np.abs(x) - fx                                               # across the foot: - inner, + outer
    if kind == "sneaker":
        s = m & (z < 0.105*SC)
        col = np.where(s[..., None], c*(1 + 0.06*(sk["fbm"](x*120, y*120, z*120, oct=2, seed=31) - 0.5))[..., None], col)
        sole = s & (z < 0.024*SC); col = np.where(sole[..., None], np.array(shoe[2]), col)
        lace = s & (Nn[..., 2] > 0.45) & (np.abs(lx) < 0.016*SC) & (y > -0.13*SC) & (y < -0.035*SC)
        stripes = lace & (np.sin(y/SC*420) > 0.2)
        col = np.where(lace[..., None], c*0.7, col); col = np.where(stripes[..., None], np.array(shoe[2]), col)
        rough = np.where(s, 0.7, rough); alpha = np.where(s, 0.0, alpha)
    else:  # flip-flops: sole + V strap, bare foot on top
        sole = m & (z < 0.016*SC)
        col = np.where(sole[..., None], c, col)
        tip = np.array([0.0, -0.165*SC])                              # the toe-post between big and 2nd toe (inner side)
        strap = np.zeros(m.shape, bool)
        for ox in (-0.036*SC, 0.036*SC):
            a = np.array([-0.010*SC, -0.165*SC]); b = np.array([ox, -0.085*SC])
            q = np.stack([lx, y], -1); ab = b - a
            t = np.clip(((q - a) @ ab)/float(ab @ ab), 0, 1)
            dist = np.linalg.norm(q - (a + t[..., None]*ab), axis=-1)
            strap |= m & (z < 0.09*SC) & (dist < 0.0055*SC) & (y < -0.05*SC)
        col = np.where(strap[..., None], c*1.1, col); hgt += 0.0005*strap
        rough = np.where(sole | strap, 0.6, rough); alpha = np.where(sole | strap, 0.0, alpha)
    return col, hgt, rough, alpha

TILE = 0.32
_tiles = {}
def tile_img(name):
    if name not in _tiles:
        im = bpy.data.images.load(os.path.join(MODELS, "clothes_tex", name + "_Color.png"), check_existing=False)
        a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        _tiles[name] = a.reshape(im.size[1], im.size[0], 4)[..., :3].copy(); bpy.data.images.remove(im)
    return _tiles[name]

def paint_skirt(ras, col, hgt, rough, alpha, spec, tube, top_z, hem_z):
    """the cloth tube: a woven tile wrapped round the body (u = arc length); sin: v from the hem to the waist"""
    P, m = ras["P"], ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    on = m & tube
    img = tile_img(spec["tile"]); H, W = img.shape[:2]
    u = ((np.arctan2(x, -y)*0.17*SC)/TILE) % 1.0
    v = np.clip((z - hem_z)/(top_z - hem_z), 0, 0.999) if spec["mode"] == "sin" else ((z - hem_z)/TILE) % 1.0
    c = img[(v*H).astype(int).clip(0, H - 1), (u*W).astype(int).clip(0, W - 1)]
    c = c*(1 + 0.06*(sk["fbm"](x*40, y*40, z*40, oct=2, seed=41) - 0.5))[..., None]
    band = on & (z > top_z - 0.035*SC); c = np.where(band[..., None], c*0.85, c)      # rolled / tucked waist
    col = np.where(on[..., None], c, col); rough = np.where(on, 0.88, rough); alpha = np.where(on, 0.0, alpha)
    hgt = hgt + 0.0004*band
    return col, hgt, rough, alpha

# ---------------------------------------------------------------- files
def save_rgba(rgb, a, path):
    img = bpy.data.images.new("_s", rgb.shape[1], rgb.shape[0], alpha=True)
    px = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)[..., None]], -1).astype(np.float32)
    img.pixels.foreach_set(px.ravel()); img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)

def down2x(a):   # (H, 2W, ...) -> (H, W, ...)
    return a.reshape(a.shape[0], a.shape[1]//2, 2, *a.shape[2:]).mean(2)

FAKE_NOSE = False
def face_form(col, hgt, meta):
    """the nose is modelled now (build_body.py NOSE): only paint its shadows (under it, wing creases) plus a little
    eye-socket / lip / chin shading. FAKE_NOSE = True also paints the bridge / tip and raises a nose in the height map
    (what the smooth head used before the nose was modelled)"""
    n2 = sk["N"]; rows = np.arange(n2//2, n2); cols = np.arange(n2)
    v = (rows + 0.5)/n2; u = (cols + 0.5)/n2
    hh_ = meta["h0"] + (v - sk["HV0"])/(sk["HV1"] - sk["HV0"])*(meta["h1"] - meta["h0"])
    az = sk["unwarp"]((u - 0.5)*2*math.pi)
    X, Y = np.meshgrid(az*meta["RF"], hh_)
    cv = sk["Canvas"](X, Y); ss = sk["sstep"]; s = meta["s"]
    top, tip, base, eye, mouth = meta["top_h"], meta["tip_h"], meta["base_h"], meta["eye_h"], meta["mouth_h"]
    # nose: 0 at the bridge top, highest at the tip, gone just under the base; wider towards the wings
    if FAKE_NOSE:
        t = np.clip((top - Y)/(top - tip), 0, 1.25)
        rise = ss(0.0, 1.0, t)*ss(base - 0.010*s, base + 0.002*s, Y)
        w = (0.0065 + 0.0055*np.clip(t, 0, 1))*s
        hgt = hgt + 0.0055*s*rise*np.exp(-(X/w)**2)
        side = rise*np.clip(np.exp(-((np.abs(X) - 1.25*w)/(0.55*w))**2), 0, 1)*ss(top - 0.004*s, top - 0.016*s, Y)
        col = col*(1 - 0.10*side)[..., None]
        col = col*(1 + 0.05*rise*np.exp(-(X/(0.0035*s))**2)*ss(top - 0.006*s, tip, Y))[..., None]      # bridge highlight
        col = col*(1 + 0.05*cv.ell(0, tip + 0.005*s, 0.0055*s, 0.007*s, 1.0))[..., None]                 # tip highlight
    pass # under the nose   # under the nose (the modelled nose casts its own)
    for sx in (1, -1):
        pass # wing creases   # wing creases
        col = col*(1 - 0.06*cv.ell(sx*0.031*s, eye + 0.011*s, 0.020*s, 0.008*s, 1.0))[..., None]               # socket under the brow
        col = col*(1 - 0.05*cv.ell(sx*0.014*s, eye - 0.004*s, 0.006*s, 0.008*s, 1.0))[..., None]               # inner eye corner
    col = col*(1 - 0.08*cv.ell(0, mouth - 0.013*s, 0.013*s, 0.0045*s, 1.0))[..., None]                       # under the lower lip
    hgt = hgt + 0.0012*s*cv.ell(0, mouth - 0.024*s, 0.018*s, 0.010*s, 1.0)                                # chin
    return col, hgt

def head_textures(look, meta):
    """paint_head at N = 2048 gives the head canvas 1024 rows x 2048 columns (old top half, twice as tall);
    halve the columns -> 1024 x 1024 head texture whose v covers only the head"""
    hc, hh, hr, hp = sk["paint_head"](meta, look, False)
    hc, hh = face_form(hc, hh, meta)
    nrm = sk["normal_from_height"](hh, hp[0], hp[1])
    hc, hr, nrm = down2x(hc), down2x(hr), down2x(nrm)
    n3 = nrm*2 - 1; n3 /= np.linalg.norm(n3, axis=-1, keepdims=True); nrm = n3*0.5 + 0.5
    mx, mn = hc.max(-1), hc.min(-1); sat = (mx - mn)/np.maximum(mx, 1e-4)
    alpha = np.where((sat < 0.20) & (mx > 0.62), 0.0, 1.0)            # eye whites / teeth keep their colour
    return hc, nrm, hr, alpha

def tinted(rgb, a, tint):
    return rgb*(1 - a[..., None] + a[..., None]*np.array(tint))

# ---------------------------------------------------------------- render
def material(name, color_path, normal_path, rough_path):
    m = bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def tex(p, nc):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(p, check_existing=False)
        if nc: n.image.colorspace_settings.name = "Non-Color"
        return n
    nt.links.new(tex(color_path, False).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex(rough_path, True).outputs["Color"], b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tex(normal_path, True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def setup_render():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.26, 0.28, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    for n, rot, e in (("_key", (55, 0, -35), 3.2), ("_fill", (70, 0, 60), 1.1), ("_back", (60, 0, 170), 1.2)):
        l = bpy.data.objects.new(n, bpy.data.lights.new(n, 'SUN')); l.data.energy = e
        l.rotation_euler = tuple(math.radians(v) for v in rot); sc.collection.objects.link(l)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    return cam

def shot(cam, tgt, d, ortho, res):
    sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = res
    d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
    p = os.path.join(OUT, f"_t_{CHAR}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr

def save_sheet(arr, path):
    img = bpy.data.images.new("s", arr.shape[1], arr.shape[0]); img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)

def pose_idle(rig):
    old = {"male": "human_base", "female": "human_female"}[CHAR]
    with bpy.data.libraries.load(os.path.join(MODELS, "mocap", "out", old + "_mocap.blend")) as (src, dst):
        dst.actions = ["idle"]
    act = dst.actions[0]
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        for c in pb.constraints: c.mute = True
    if not rig.animation_data: rig.animation_data_create()
    rig.animation_data.action = act
    try: rig.animation_data.action_slot = act.slots[0]
    except Exception: pass
    bpy.context.scene.frame_set(int(act.frame_range[0] + 20)); bpy.context.view_layer.update()
    return act

def rest(rig):
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()

try:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; me = body.data
    rest(rig)
    sk = load_ns(os.path.join(OLD, "build_skin.py")); sk["N"] = 2 * RES
    for k in ("male", "female", "elder_male", "elder_female"): sk["LOOK"][k] = dict(sk["LOOK"][k], skin=SKIN_BASE)
    fr = sk["Frame"](body, rig)
    parts = [faces_of(me, k) for k in range(3)]
    uv = np.zeros((len(me.loops), 2))
    h0, h1 = head_uv(sk, fr, me, parts[0], uv)
    names = [g.name for g in body.vertex_groups]; dom = fr.w.argmax(1)
    def dominated(f, pre): return sum(names[dom[v]].startswith(pre) for v in me.polygons[f].vertices)*2 > len(me.polygons[f].vertices)
    HANDS = ("hand", "index", "middle", "ring", "pinky", "thumb")
    up_hand = [f for f in parts[1] if dominated(f, HANDS)]; uh = set(up_hand)
    smart(body, [f for f in parts[1] if f not in uh], (0.005, 0.26, 0.995, 0.995), uv); smart(body, up_hand, (0.005, 0.005, 0.995, 0.25), uv)
    feet = [f for f in parts[2] if all(fr.co[v][2] < 0.12*SC for v in me.polygons[f].vertices)]; fs_ = set(feet)
    smart(body, [f for f in parts[2] if f not in fs_], (0.005, 0.21, 0.995, 0.995), uv); smart(body, feet, (0.005, 0.005, 0.995, 0.20), uv)
    sk["set_uv"](me, uv)
    meta = face_landmarks(fr, h0, h1)
    # lower variants (build_lower.py): own UVs (legs v 0.21..1, shoes v 0..0.20; skirt tube = cylinder, v hem -> waist)
    if '--heads-only' in argv:
        for look in {pr['look'] for pr in PRESETS}:
            hc, hn, hr, ha = head_textures(look, meta)
            base = os.path.join(TEX, f'{CHAR}_{look}_head')
            save_rgba(hc, ha, base + '_Color.png'); sk['save_png'](hn, base + '_Normal.png', True); sk['save_png'](hr, base + '_Roughness.png', True)
            L('painted head', base)
        sys.exit(0)
    VAR = {}
    for vname in ("wide", "skirt"):
        ob = bpy.data.objects.get("Lower_" + vname)
        if not ob: continue
        vm = ob.data; vfr = ObjFrame(ob, fr); vuv = np.zeros((len(vm.loops), 2))
        tub = vm.attributes["tube"].data if "tube" in vm.attributes else None
        tube_f = [p.index for p in vm.polygons if tub is not None and tub[p.index].value == 1]; ts = set(tube_f)
        rest_f = [p.index for p in vm.polygons if p.index not in ts]
        top_z = float(vfr.co[:, 2].max())
        hem_z = float(min(vfr.co[v][2] for f in tube_f for v in vm.polygons[f].vertices)) if tube_f else 0.0
        if tube_f:
            for fi in tube_f:
                p = vm.polygons[fi]; cen = vfr.co[list(p.vertices)].mean(0); ca = math.atan2(cen[0], -cen[1])
                for l, v in zip(p.loop_indices, p.vertices):
                    a = math.atan2(vfr.co[v][0], -vfr.co[v][1]); a = ca + math.atan2(math.sin(a - ca), math.cos(a - ca))
                    vuv[l] = (0.5 + a/(2*math.pi), 0.21 + 0.785*min(1.0, max(0.0, (vfr.co[v][2] - hem_z)/(top_z - hem_z))))
            smart(ob, rest_f, (0.005, 0.005, 0.995, 0.20), vuv)
        else:
            vfeet = [f for f in rest_f if all(vfr.co[v][2] < 0.12*SC for v in vm.polygons[f].vertices)]; vf_ = set(vfeet)
            smart(ob, [f for f in rest_f if f not in vf_], (0.005, 0.21, 0.995, 0.995), vuv); smart(ob, vfeet, (0.005, 0.005, 0.995, 0.20), vuv)
        sk["set_uv"](vm, vuv)
        r = rasterise(ob, vfr, vuv, [p.index for p in vm.polygons])
        tube_mask = np.isin(r["face"], np.array(sorted(ts) or [-2]))
        VAR[vname] = dict(ob=ob, ras=r, tube=tube_mask, top=top_z, hem=hem_z)
        L("variant", vname, "faces", len(vm.polygons), "tube faces", len(tube_f), "texels used", f"{r['mask'].mean()*100:.0f}%")
    L("faces per part", [len(p) for p in parts], "hands", len(up_hand), "feet", len(feet), "head meta", {k: round(v, 3) for k, v in meta.items()})
    ras = [None, rasterise(body, fr, uv, parts[1]), rasterise(body, fr, uv, parts[2])]
    heads = {}
    files = {}
    for pr in PRESETS:
        look = pr["look"]
        if look not in heads:
            heads[look] = head_textures(look, meta)
            hc, hn, hr, ha = heads[look]
            base = os.path.join(TEX, f"{CHAR}_{look}_head")
            save_rgba(hc, ha, base + "_Color.png"); sk["save_png"](hn, base + "_Normal.png", True); sk["save_png"](hr, base + "_Roughness.png", True)
        out = {0: os.path.join(TEX, f"{CHAR}_{look}_head")}
        for k in (1, 2):
            low = pr.get("lower", "body")
            r = ras[k] if (k == 1 or low == "body") else VAR[low]["ras"]
            col, hgt, rough = sk["paint_body"](r, meta, look, False)
            alpha = np.ones(col.shape[:2])
            if k == 1: col, hgt, rough, alpha = paint_shirt(r, col, hgt, rough, alpha, pr["shirt"])
            else:
                col, hgt, rough, alpha = paint_lower(r, col, hgt, rough, alpha, pr["pants"], pr["shoe"])
                if low == "skirt":
                    vv = VAR["skirt"]; col, hgt, rough, alpha = paint_skirt(r, col, hgt, rough, alpha, pr["skirt"], vv["tube"], vv["top"], vv["hem"])
            m = r["mask"]
            col, _ = sk["dilate"](col, m, 8); hgt, _ = sk["dilate"](hgt, m, 8); rough, _ = sk["dilate"](rough, m, 8); alpha, _ = sk["dilate"](alpha, m, 8)
            pp, _ = sk["dilate"](r["ppm"], m, 8); pp = np.maximum(pp, 1.0)
            nrm = sk["normal_from_height"](hgt, pp, pp)
            base = os.path.join(TEX, f"{pr['name']}_{PART_NAMES[k]}")
            save_rgba(col, alpha, base + "_Color.png"); sk["save_png"](nrm, base + "_Normal.png", True); sk["save_png"](rough, base + "_Roughness.png", True)
            out[k] = base
            if pr is PRESETS[0]: L(PART_NAMES[k], "texels used", f"{m.mean()*100:.0f}%", "skin texels", f"{(alpha*m).sum()/max(m.sum(),1)*100:.0f}%")
        files[pr["name"]] = out
        L("painted", pr["name"])
    if "--save" in argv:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_mainfile()
    # ---- renders: per character 3/4 front, back, face; tint applied like TintMask
    hair_ns = load_ns(os.path.join(OLD, "build_hair.py"))
    cam = setup_render()
    btop = body.copy(); btop.data = body.data.copy(); bpy.context.scene.collection.objects.link(btop); btop.name = "_BodyTop"
    bm_ = bmesh.new(); bm_.from_mesh(btop.data); lay = bm_.faces.layers.int.get("part")
    bmesh.ops.delete(bm_, geom=[f for f in bm_.faces if f[lay] == 2], context='FACES'); bm_.to_mesh(btop.data); bm_.free()
    rows = [[], []]; faces = []
    for pr in PRESETS:
        rest(rig)
        hair_ns["add_hair"](pr["look"], [pr["hair"]])
        mats = []
        for k in range(3):
            base = files[pr["name"]][k]
            im = bpy.data.images.load(base + "_Color.png", check_existing=False); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
            a = a.reshape(im.size[1], im.size[0], 4); bpy.data.images.remove(im)
            tp = os.path.join(OUT, f"_tint_{CHAR}_{k}.png"); save_rgba(tinted(a[..., :3], a[..., 3], pr["tint"]), np.ones(a.shape[:2]), tp)
            mats.append(material(f"V_{k}", tp, base + "_Normal.png", base + "_Roughness.png"))
        low = pr.get("lower", "body")
        shown = [body] if low == "body" else [btop, VAR[low]["ob"]]
        for o in [body, btop] + [v["ob"] for v in VAR.values()]: o.hide_render = o not in shown
        for ob_ in (body, btop):
            ob_.data.materials.clear()
            for mm in mats: ob_.data.materials.append(mm)
            pa = ob_.data.attributes["part"].data
            for p in ob_.data.polygons: p.material_index = pa[p.index].value
        for v in VAR.values():
            v["ob"].data.materials.clear(); v["ob"].data.materials.append(mats[2])
        pose_idle(rig)
        H = 1.82*SC
        full = [shot(cam, (0, 0, H*0.5), d, H*1.06, (340, 600)) for d in ((0.45, -0.9, 0.08), (-0.3, 1, 0.05))]
        hb = rig.pose.bones["head"]; hc = rig.matrix_world @ ((hb.head + hb.tail)*0.5)
        face = shot(cam, hc + Vector((0, 0, -0.03*SC)), (0.25, -1, 0.04), 0.34*SC, (340, 340))
        pad = np.ones((260, 340, 4), np.float32); pad[..., :3] = (0.25, 0.26, 0.28)
        rows[0].append(np.concatenate(full, 1)); rows[1].append(np.concatenate([pad, face], 0))
        faces.append(np.concatenate([shot(cam, hc + Vector((0, 0, -0.03*SC)), d, 0.30*SC, (460, 460)) for d in ((0, -1, 0.03), (0.65, -0.76, 0.03))], 0))
    sheet = np.concatenate([np.concatenate([a, b], 1) for a, b in zip(rows[0], rows[1])], 1)
    save_sheet(sheet, os.path.join(OUT, f"paint_{CHAR}_lineup.png"))
    save_sheet(np.concatenate(faces, 1), os.path.join(OUT, f"paint_{CHAR}_faces.png"))
    # texture layout of the first character (head / upper / lower colour, alpha shown as a checker in the cloth)
    tiles = []
    for k in range(3):
        im = bpy.data.images.load(files[PRESETS[0]["name"]][k] + "_Color.png"); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        a = a.reshape(im.size[1], im.size[0], 4)[::2, ::2].copy(); bpy.data.images.remove(im)
        a[..., 3] = 1; tiles.append(a)
    save_sheet(np.concatenate(tiles, 1), os.path.join(OUT, f"paint_{CHAR}_textures.png"))
    L("ok")
except Exception:
    L(traceback.format_exc())
open(os.path.join(OUT, f"paint_{CHAR}_report.txt"), "w", encoding="utf-8").write("\n".join(log))
