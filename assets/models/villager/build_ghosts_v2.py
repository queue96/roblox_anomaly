# Villager v2 Ghosts: ALL clothing (shirts, chest wraps, sabai sashes, dancer bodice/collar/armlets/belt, burial shroud, pha sin)
# is painted directly onto BodyUpper / LowerSkirt / LowerWide so ZERO cloth-body clipping can ever happen!
# Only essential rigid props/hair remain separate (Hair_*, Crown, Fingernail cuffs, Prop_Baby, Prop_TaKhonMask, Prop_JawTie, NeckStump, Pop_Eyes/Fangs/Tongue).
import bpy, bmesh, os, sys, math, shutil, re, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
OLD = os.path.join(MODELS, "human_base")
GH = os.path.join(MODELS, "human_ghosts")
TEX = os.path.join(HERE, "textures")
OUT = os.path.join(HERE, "design")
UP = os.path.join(HERE, "upload")
os.makedirs(TEX, exist_ok=True); os.makedirs(OUT, exist_ok=True); os.makedirs(UP, exist_ok=True)

RES = 1024
STUDS_PER_M = 3.5
TILE = 0.32
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

def load_skin_ns():
    path = os.path.join(OLD, "build_skin.py")
    ns = {"__name__": "lib", "__file__": path}
    src = open(path, encoding="utf-8").read()
    src = src.replace(
        "col = mix(col, skin*0.35 if not ghost else (0.15, 0.12, 0.14), cv.ell(sx*0.0075*s, bh + 0.0035*s, 0.0045*s, 0.0025*s, 0.5)*(Y > bh - 0.0005))",
        "pass # no nostril dots on 3D nose"
    )
    src = src.replace(
        "(np.abs(X) > 0.03*s)",
        "sstep(0.028*s, 0.048*s, np.abs(X))"
    )
    exec(compile(src, path, "exec"), ns)
    ns["M"] = MODELS
    ns["GORE"] = False
    ns["N"] = 2 * RES
    return ns

sk = load_skin_ns()

def faces_of(me, k):
    a = me.attributes["part"].data
    return [p.index for p in me.polygons if a[p.index].value == k]

def face_landmarks(char, sc, fr, h0, h1):
    dz = 0.012 if char == "male" else 0.0
    nose = [(0, -0.097, 1.703), (0, -0.108, 1.668), (0, -0.116, 1.648), (0, -0.104, 1.636), (0, -0.090, 1.660)]
    for sx in (1, -1): nose += [(0.012*sx, -0.099, 1.668), (0.018*sx, -0.098, 1.640)]
    nose = np.array([(x*sc, y*sc, (z - dz)*sc) for x, y, z in nose])
    naz, nh, nfw = fr.local(nose)
    top_h, base_h = float(nh.max()), float(nh.min()); tip_h = float(nh[np.argmax(nfw)])
    az, h, fw = fr.local(fr.co)
    hw = fr.w[:, fr.gi["head"]] > 0.99
    front = hw & (np.abs(az) < math.radians(12))
    RF = float(np.median(fw[front & (np.abs(h - (top_h + tip_h)/2) < 0.03*fr.s)]))
    chin_h = float(h[front].min())
    return dict(h0=h0, h1=h1, s=fr.s, RF=RF, top_h=top_h, tip_h=tip_h, base_h=base_h, chin_h=chin_h,
                eye_h=top_h - 0.22*(top_h - tip_h), mouth_h=base_h - 0.40*(base_h - chin_h), wing_x=float(np.abs(naz).max()*RF))

class ObjFrame:
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

def down2x(a):
    return a.reshape(a.shape[0], a.shape[1]//2, 2, *a.shape[2:]).mean(2)

def face_form(col, hgt, meta, porcelain=False):
    n2 = sk["N"]; rows = np.arange(n2//2, n2); cols = np.arange(n2)
    v = (rows + 0.5)/n2; u = (cols + 0.5)/n2
    hh_ = meta["h0"] + (v - sk["HV0"])/(sk["HV1"] - sk["HV0"])*(meta["h1"] - meta["h0"])
    az = sk["unwarp"]((u - 0.5)*2*math.pi)
    X, Y = np.meshgrid(az*meta["RF"], hh_)
    cv = sk["Canvas"](X, Y); ss = sk["sstep"]; mix = sk["mix"]; s = meta["s"]
    eye, mouth = meta["eye_h"], meta["mouth_h"]
    for sx in (1, -1):
        col = col*(1 - 0.06*cv.ell(sx*0.031*s, eye + 0.011*s, 0.020*s, 0.008*s, 1.0))[..., None]
        col = col*(1 - 0.05*cv.ell(sx*0.014*s, eye - 0.004*s, 0.006*s, 0.008*s, 1.0))[..., None]
    col = col*(1 - 0.08*cv.ell(0, mouth - 0.013*s, 0.013*s, 0.0045*s, 1.0))[..., None]
    hgt = hgt + 0.0012*s*cv.ell(0, mouth - 0.024*s, 0.018*s, 0.010*s, 1.0)
    if porcelain:
        pale = np.array((0.82, 0.82, 0.81))
        col = col*0.45 + pale*0.55
        ex, es = 0.032*s, s*1.06
        face = (np.abs(az[None, :]) < math.radians(85)) & (Y > meta["chin_h"] - 0.01*s) & (Y < meta["top_h"] + 0.05*s)
        lum = col.mean(-1)
        stain = face & (lum < 0.35) & (Y < eye - 0.006*s) & (np.abs(X) > 0.010*s) & (np.hypot(X/0.024, (Y - mouth)/0.012) > 1.3)
        col = mix(col, pale*0.97, stain*0.95)
        e = np.hypot((np.abs(X) - ex)/(0.0155*es), (Y - eye)/(0.0062*es))
        col = mix(col, (0.94, 0.94, 0.92), face*ss(1.05, 0.85, e))
        col = mix(col, (0.28, 0.28, 0.32), face*(np.abs(e - 1.0) < 0.12)*0.8)
        rnd = np.random.RandomState(21); segs = []
        for sx in (1, -1):
            for k in range(7):
                ang = math.radians(rnd.uniform(-160, -20)) if k < 6 else math.radians(rnd.uniform(-10, 10))
                x0 = sx*(ex + math.cos(ang)*0.0165*es); y0 = eye + math.sin(ang)*0.0068*es; n = rnd.randint(7, 12)
                def walk(x, y, a_, n, w):
                    for _ in range(n):
                        a_ += rnd.uniform(-0.5, 0.5); a_ += (-math.pi/2 - a_)*0.15 if k < 6 else 0.0; L_ = rnd.uniform(0.005, 0.009)*s
                        x2, y2 = x + sx*math.cos(a_)*L_, y + math.sin(a_)*L_
                        segs.append((x, y, x2, y2, w)); x, y = x2, y2
                        if rnd.rand() < 0.25 and w > 0.0006*s: walk(x, y, a_ + rnd.choice((-0.9, 0.9)), max(1, n//2), w*0.6)
                        w *= 0.85
                walk(x0, y0, ang, n, 0.0013*s)
        dist = np.full(X.shape, 9.0)
        box = face & (Y < eye + 0.05*s) & (Y > eye - 0.11*s) & (np.abs(X) < 0.09*s)
        Xb, Yb = X[box], Y[box]; db = np.full(Xb.shape, 9.0)
        for x0, y0, x1, y1, w in segs:
            dx, dy = x1 - x0, y1 - y0; ll = dx*dx + dy*dy or 1e-12
            tt = np.clip(((Xb - x0)*dx + (Yb - y0)*dy)/ll, 0, 1)
            dd = np.hypot(Xb - x0 - tt*dx, Yb - y0 - tt*dy)/w
            m_ = dd < db; db[m_] = dd[m_]
        dist[box] = db
        col = mix(col, (0.32, 0.38, 0.52), face*ss(3.5, 1.2, dist)*0.55)
        col = mix(col, (0.05, 0.07, 0.15), face*ss(1.0, 0.5, dist))
        lip = np.hypot(X/(0.022*s), np.where(Y > mouth, (Y - mouth)/(0.0065*s), (mouth - Y)/(0.0075*s)))
        col = mix(col, (0.36, 0.04, 0.06), face*ss(1.05, 0.85, lip))
        col = mix(col, (0.18, 0.02, 0.03), face*(np.abs(Y - mouth) < 0.0009*s)*(lip < 1.0))
    return col, hgt

def head_textures(look, ghost_mode, meta, face_override=None, porcelain=False):
    hc, hh, hr, hp = sk["paint_head"](meta, look, ghost_mode, face=face_override)
    hc, hh = face_form(hc, hh, meta, porcelain=porcelain)
    nrm = sk["normal_from_height"](hh, hp[0], hp[1])
    hc, hr, nrm = down2x(hc), down2x(hr), down2x(nrm)
    n3 = nrm*2 - 1; n3 /= np.linalg.norm(n3, axis=-1, keepdims=True); nrm = n3*0.5 + 0.5
    return hc, nrm, hr

_tiles = {}
def tile_img(name):
    if name not in _tiles:
        im = bpy.data.images.load(os.path.join(MODELS, "clothes_tex", name + "_Color.png"), check_existing=False)
        a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        _tiles[name] = a.reshape(im.size[1], im.size[0], 4)[..., :3].copy(); bpy.data.images.remove(im)
    return _tiles[name]

def fabric(col, P, spec, sel, seed):
    c = np.array(spec["color"]); x, y, z = P[..., 0], P[..., 1], P[..., 2]
    tone = 1 + 0.12*(sk["fbm"](x*30, y*30, z*30, oct=3, seed=seed) - 0.5) + 0.04*(sk["fbm"](x*260, y*260, z*260, oct=2, seed=seed + 1) - 0.5)
    dirt = sk["sstep"](0.52, 0.78, sk["fbm"](x*18, y*18, z*18, oct=3, seed=seed + 5))
    cloth = c*tone[..., None]*(1 - 0.22*dirt[..., None])
    return np.where(sel[..., None], cloth, col)

def paint_shirt(ras, col, hgt, rough, spec, sc):
    P, bn = ras["P"], np.array(ras["names"] + ["-"])[ras["bone"]]
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
        col = np.where(cuff[..., None], col*0.80, col)
    zn = 1.510*sc
    front = (y < 0)
    depth = 0.018*sc*np.clip(1 - (x/(0.07*sc))**2, 0, 1)
    opening = shirt & front & (z > zn - depth) & ~arm
    trim = shirt & front & ~arm & (z > zn - depth - 0.012*sc) & ~opening & (depth > 0.004*sc)
    shirt &= ~opening
    col = fabric(col, P, spec, shirt, 11)
    col = np.where(trim[..., None], col*0.85, col)
    if spec.get("buttons"):
        placket = shirt & front & (np.abs(x) < 0.007*sc) & (z < zn - depth.max()*0.6) & (z > 1.07*sc)
        col = np.where(placket[..., None], col*0.86, col)
        for k in range(6):
            bz = (1.44 - 0.07*k)*sc
            dot = shirt & front & (np.hypot(x, z - bz) < 0.0055*sc)
            col = np.where(dot[..., None], np.array((0.55, 0.53, 0.50)), col)
            hgt += 0.0004*dot
    hem = shirt & (z < 1.080*sc) & ~arm
    col = np.where(hem[..., None], col*0.85, col)
    rough = np.where(shirt, 0.88, rough)
    return col, hgt, rough

def paint_sabai_upper(ras, col, hgt, rough, wrap_color, sabai_tile, sc, over_blouse=False):
    """Paint chest wrap (ผ้าแถบ) + diagonal sabai sash (สไบเฉียงพาดบ่าซ้ายลงเอวขวา) directly onto BodyUpper"""
    P, bn = ras["P"], np.array(ras["names"] + ["-"])[ras["bone"]]
    x, y, z = P[..., 0], P[..., 1], P[..., 2]; m = ras["mask"]
    arm = np.array([b.startswith(("upper_arm", "forearm", "hand", "index", "middle", "ring", "pinky", "thumb")) for b in bn.ravel()]).reshape(bn.shape)
    torso = m & ~arm
    # 1. Chest wrap (ผ้าแถบคาดอก) if not over a blouse
    if wrap_color is not None:
        z_lo = (1.16 + 0.010*np.sin(x*35))*sc
        z_hi = (1.335 - 0.012*(y > 0))*sc
        wrap = torso & (z >= z_lo) & (z <= z_hi)
        col = fabric(col, P, dict(color=wrap_color), wrap, 71)
        border = wrap & ((z < z_lo + 0.012*sc) | (z > z_hi - 0.012*sc))
        col = np.where(border[..., None], col*0.78, col)
        hgt += 0.0007*wrap + 0.0004*border
        rough = np.where(wrap, 0.88, rough)
    # 2. Diagonal sabai sash (พาดบ่าซ้าย x > 0 ลงไปเอวขวา x < 0 ทั้งด้านหน้าและเฉียงหลัง)
    img = tile_img(sabai_tile); H, W = img.shape[:2]
    # Centerline x_c(z) from right hip (-0.085*sc at z=1.06*sc) to left shoulder (+0.095*sc at z=1.47*sc)
    t_z = np.clip((z - 1.06*sc)/(0.41*sc), 0.0, 1.0)
    xc = (-0.085 + 0.180*t_z)*sc
    half_w = (0.068 - 0.010*t_z)*sc
    # Front diagonal sash + left shoulder cap + back drape down left side (x > 0.02*sc)
    sabai_front = torso & (y <= 0.02*sc) & (np.abs(x - xc) <= half_w) & (z >= 1.06*sc)
    sabai_back = torso & (y > 0.0) & (x >= 0.015*sc) & (x <= 0.135*sc) & (z >= 1.06*sc)
    sabai = sabai_front | sabai_back
    u = ((x - (xc - half_w))/(2*half_w)).clip(0, 0.999)
    v = ((z - 1.06*sc)/TILE) % 1.0
    scol = img[(v*H).astype(int).clip(0, H - 1), (u*W).astype(int).clip(0, W - 1)]
    pleat = 0.92 + 0.12*np.sin((x - xc)*260)
    scol = scol * pleat[..., None]
    edge = sabai & ((np.abs(np.abs(x - xc) - half_w) < 0.009*sc) & (y <= 0.02*sc))
    col = np.where(sabai[..., None], scol, col)
    col = np.where(edge[..., None], col*0.80, col)
    hgt += 0.0012*sabai + 0.0005*edge
    rough = np.where(sabai, 0.85, rough)
    # Dark soot ring at neck base (so ghost_headless NeckStump blends in nicely)
    soot = torso & (z > 1.39*sc)
    col = np.where(soot[..., None], col*(0.55 + 0.45*np.clip((1.435*sc - z)/(0.045*sc), 0, 1))[..., None], col)
    return col, hgt, rough

def paint_dancer_upper(ras, col, hgt, rough, sc):
    """Paint classical Thai dancer costume onto BodyUpper: green brocade bodice, red/gold sleeves, red/gold sabai,
    gold collar (กรองคอ), pendant (ทับทรวง), gold armlets (ทองต้นแขน), and gold bracelets (กำไลข้อมือ)"""
    P, bn = ras["P"], np.array(ras["names"] + ["-"])[ras["bone"]]
    fr = ras["fr"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]; m = ras["mask"]
    hand = np.array([b.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")) for b in bn.ravel()]).reshape(bn.shape)
    arm = np.array([b.startswith(("upper_arm", "forearm")) for b in bn.ravel()]).reshape(bn.shape)
    torso = m & ~arm & ~hand
    gold = np.array((0.82, 0.66, 0.22))
    dark_gold = np.array((0.55, 0.42, 0.12))
    green = np.array((0.12, 0.28, 0.20))
    red_cloth = np.array((0.52, 0.10, 0.12))

    # 1. Green gold-brocade bodice on torso (below neck z = 1.435*sc)
    bodice = torso & (z < 1.435*sc)
    diamond = (np.sin((x + z)*160) * np.sin((x - z)*160)) > 0.35
    bcol = np.where(diamond[..., None], green*0.85 + gold*0.28, green)
    col = np.where(bodice[..., None], bcol, col)
    hgt += 0.0006*bodice + 0.0004*(bodice & diamond)
    rough = np.where(bodice, 0.65, rough)

    # 2. Short red sleeves + gold cuff bands + gold armlets + gold wrist bracelets on arms
    for side, sx in (("L", 1), ("R", -1)):
        S = fr.joints["upper_arm." + side][0]; W = fr.joints["hand." + side][0]; d = W - S
        ta = ((P - S) @ d)/float(d @ d)
        this = arm & (np.sign(x) == sx)
        slv = this & (ta <= 0.32)
        cuff = this & (ta > 0.27) & (ta <= 0.33)
        armlet = this & (ta > 0.34) & (ta <= 0.41)
        bracelet = this & (ta > 0.84) & (ta <= 0.96)
        col = np.where(slv[..., None], red_cloth, col)
        col = np.where((cuff | armlet | bracelet)[..., None], gold, col)
        hgt += 0.0007*slv + 0.0012*(cuff | armlet | bracelet)
        rough = np.where(cuff | armlet | bracelet, 0.32, rough)

    # 3. Red sabai with gold border across left shoulder
    t_z = np.clip((z - 1.06*sc)/(0.41*sc), 0.0, 1.0)
    xc = (-0.075 + 0.165*t_z)*sc
    half_w = 0.062*sc
    sabai = (torso & (y <= 0.01*sc) & (np.abs(x - xc) <= half_w) & (z >= 1.06*sc) & (z <= 1.43*sc)) | (torso & (y > 0) & (x > 0.02*sc) & (x < 0.13*sc) & (z <= 1.43*sc))
    s_edge = sabai & (y <= 0.01*sc) & (np.abs(np.abs(x - xc) - half_w) < 0.010*sc)
    col = np.where(sabai[..., None], red_cloth*(0.92 + 0.12*np.sin((x - xc)*240))[..., None], col)
    col = np.where(s_edge[..., None], gold, col)
    hgt += 0.0012*sabai + 0.0006*s_edge

    # 4. Gold collar (กรองคอ) around neck/upper chest + pendant (ทับทรวง) at chest center + gold waist belt
    r_neck = np.hypot(x, z - 1.42*sc)
    collar = torso & (z > 1.32*sc) & (z < 1.42*sc) & (r_neck < 0.125*sc)
    collar_rim = collar & ((z < 1.335*sc) | (z > 1.405*sc))
    pendant = torso & (y < 0) & (np.abs(x)*1.3 + np.abs(z - 1.29*sc) < 0.042*sc)
    belt = torso & (z < 1.115*sc)
    col = np.where((collar | pendant | belt)[..., None], gold, col)
    col = np.where(collar_rim[..., None], dark_gold, col)
    hgt += 0.0014*(collar | belt) + 0.0018*pendant
    rough = np.where(collar | pendant | belt, 0.30, rough)
    return col, hgt, rough

def paint_shroud_upper(ras, col, hgt, rough, sc):
    """Paint diagonal burial shroud bands (ผ้าห่อศพ) + wrist cord (สายสิญจน์มัดตราสัง) onto male BodyUpper"""
    P, bn = ras["P"], np.array(ras["names"] + ["-"])[ras["bone"]]
    fr = ras["fr"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]; m = ras["mask"]
    hand = np.array([b.startswith(("hand", "index", "middle", "ring", "pinky", "thumb")) for b in bn.ravel()]).reshape(bn.shape)
    arm = np.array([b.startswith(("upper_arm", "forearm")) for b in bn.ravel()]).reshape(bn.shape)
    shroud = m & ~hand
    # Criss-cross diagonal cloth bandage strips + yellowish-brown corpse stains
    b1 = np.sin((z*42 + x*18)/sc); b2 = np.sin((z*42 - x*18)/sc)
    wraps = 0.88 + 0.08*np.maximum(b1, b2)
    stain = sk["sstep"](0.48, 0.76, sk["fbm"](x*16, y*16, z*16, oct=3, seed=91))
    base_c = np.array((0.76, 0.73, 0.64))*wraps[..., None]*(1 - 0.28*stain[..., None])
    col = np.where(shroud[..., None], base_c, col)
    hgt += 0.0008*shroud*np.maximum(b1, b2)
    rough = np.where(shroud, 0.90, rough)
    # Wrist cords (สายสิญจน์มัดข้อมือ)
    for side, sx in (("L", 1), ("R", -1)):
        S = fr.joints["upper_arm." + side][0]; W = fr.joints["hand." + side][0]; d = W - S
        ta = ((P - S) @ d)/float(d @ d)
        cord = arm & (np.sign(x) == sx) & (ta > 0.88) & (ta <= 0.98)
        col = np.where(cord[..., None], np.array((0.88, 0.86, 0.78)), col)
        hgt += 0.0014*cord
    return col, hgt, rough

def paint_shroud_lower(ras, col, hgt, rough, tube, sc):
    """Paint burial shroud on male LowerSkirt tube + ankle cord (สายสิญจน์มัดข้อเท้า)"""
    P, m = ras["P"], ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    shroud = m & (tube | (z > 0.09*sc))
    b1 = np.sin((z*42 + x*18)/sc); b2 = np.sin((z*42 - x*18)/sc)
    wraps = 0.88 + 0.08*np.maximum(b1, b2)
    stain = sk["sstep"](0.48, 0.76, sk["fbm"](x*16, y*16, z*16, oct=3, seed=93))
    base_c = np.array((0.76, 0.73, 0.64))*wraps[..., None]*(1 - 0.30*stain[..., None])
    col = np.where(shroud[..., None], base_c, col)
    cord = m & (z > 0.11*sc) & (z < 0.17*sc)
    col = np.where(cord[..., None], np.array((0.88, 0.86, 0.78)), col)
    hgt += 0.0008*shroud*np.maximum(b1, b2) + 0.0015*cord
    rough = np.where(shroud, 0.90, rough)
    return col, hgt, rough

def paint_lower(ras, col, hgt, rough, pants, shoe, char, sc):
    P, m = ras["P"], ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    if pants:
        hem = pants["hem"]*sc
        tr = m & (z > hem)
        col = fabric(col, P, pants, tr, 21)
        band = tr & (z > 1.025*sc); col = np.where(band[..., None], col*0.80, col)
        hemband = tr & (z < hem + 0.018*sc); col = np.where(hemband[..., None], col*0.75, col)
        rough = np.where(tr, 0.9, rough)
    if shoe:
        c = np.array(shoe[1])
        fx = 0.098*sc if char == "male" else 0.092*sc
        lx = np.abs(x) - fx
        sole = m & (z < 0.016*sc)
        col = np.where(sole[..., None], c, col)
        strap = np.zeros(m.shape, bool)
        for ox in (-0.036*sc, 0.036*sc):
            a = np.array([-0.010*sc, -0.165*sc]); b = np.array([ox, -0.085*sc])
            q = np.stack([lx, y], -1); ab = b - a
            t = np.clip(((q - a) @ ab)/float(ab @ ab), 0, 1)
            dist = np.linalg.norm(q - (a + t[..., None]*ab), axis=-1)
            strap |= m & (z < 0.09*sc) & (dist < 0.0055*sc) & (y < -0.05*sc)
        col = np.where(strap[..., None], c*1.1, col); hgt += 0.0005*strap
        rough = np.where(sole | strap, 0.6, rough)
    return col, hgt, rough

def paint_skirt(ras, col, hgt, rough, tile_name, tube, top_z, hem_z, sc, gold_belt=False):
    P, m = ras["P"], ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    on = m & tube
    img = tile_img(tile_name); H, W = img.shape[:2]
    u = ((np.arctan2(x, -y)*0.17*sc)/TILE) % 1.0
    v = np.clip((z - hem_z)/(top_z - hem_z), 0, 0.999)
    c = img[(v*H).astype(int).clip(0, H - 1), (u*W).astype(int).clip(0, W - 1)]
    c = c*(1 + 0.06*(sk["fbm"](x*40, y*40, z*40, oct=2, seed=41) - 0.5))[..., None]
    band = on & (z > top_z - 0.038*sc)
    if gold_belt:
        gold = np.array((0.82, 0.66, 0.22))
        buckle = band & (y < 0) & (np.abs(x) < 0.032*sc)
        c = np.where(band[..., None], gold, c)
        c = np.where(buckle[..., None], gold*1.12, c)
        hgt = hgt + 0.0012*band + 0.0008*buckle
    else:
        c = np.where(band[..., None], c*0.85, c)
        hgt = hgt + 0.0004*band
    col = np.where(on[..., None], c, col); rough = np.where(on, 0.35 if gold_belt else 0.88, rough)
    return col, hgt, rough

def save_set(base, col, nrm, rough):
    sk["save_png"](np.clip(col, 0, 1), base + "_Color.png", False)
    sk["save_png"](np.clip(nrm, 0, 1), base + "_Normal.png", True)
    sk["save_png"](np.clip(rough, 0, 1), base + "_Roughness.png", True)
    L("saved texture set:", os.path.basename(base))

def prepare_char(char):
    sc = 1.0 if char == "male" else 0.93
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{char}.blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; me = body.data
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    fr = sk["Frame"](body, rig)
    parts = [faces_of(me, k) for k in range(3)]
    uv = np.zeros((len(me.loops), 2)); me.uv_layers.active.data.foreach_get("uv", uv.ravel())
    hv = sorted({v for fi in parts[0] for v in me.polygons[fi].vertices})
    _, h, _ = fr.local(fr.co)
    h0, h1 = float(h[hv].min()), float(h[hv].max())
    meta = face_landmarks(char, sc, fr, h0, h1)
    ras_up = rasterise(body, fr, uv, parts[1])
    VAR = {}
    for vname in ("wide", "skirt"):
        ob = bpy.data.objects.get("Lower_" + vname)
        if not ob: continue
        vm = ob.data; vfr = ObjFrame(ob, fr)
        vuv = np.zeros((len(vm.loops), 2)); vm.uv_layers.active.data.foreach_get("uv", vuv.ravel())
        tub = vm.attributes["tube"].data if "tube" in vm.attributes else None
        tube_f = [p.index for p in vm.polygons if tub is not None and tub[p.index].value == 1]; ts = set(tube_f)
        top_z = float(vfr.co[:, 2].max())
        hem_z = float(min(vfr.co[v][2] for f in tube_f for v in vm.polygons[f].vertices)) if tube_f else 0.0
        r = rasterise(ob, vfr, vuv, [p.index for p in vm.polygons])
        tube_mask = np.isin(r["face"], np.array(sorted(ts) or [-2]))
        VAR[vname] = dict(ob=ob, ras=r, tube=tube_mask, top=top_z, hem=hem_z)
    return sc, body, rig, fr, meta, ras_up, VAR

def finish_body_tex(base, r, col, hgt, rough):
    m = r["mask"]
    col, _ = sk["dilate"](col, m, 8); hgt, _ = sk["dilate"](hgt, m, 8); rough, _ = sk["dilate"](rough, m, 8)
    pp, _ = sk["dilate"](r["ppm"], m, 8); pp = np.maximum(pp, 1.0)
    nrm = sk["normal_from_height"](hgt, pp, pp)
    save_set(base, col, nrm, rough)

def paint_all_ghost_textures():
    # ---- MALE GHOST TEXTURES (6 sets: 2 heads, 2 uppers, 2 lowers) ----
    sc, body, rig, fr, meta, ras_up, VAR = prepare_char("male")
    if not os.path.exists(os.path.join(TEX, "g_male_withered_head_Color.png")):
        hc, hn, hr = head_textures("male", True, meta)
        save_set(os.path.join(TEX, "g_male_ghost_head"), hc, hn, hr)
        hc, hn, hr = head_textures("elder_male", "withered", meta)
        save_set(os.path.join(TEX, "g_male_withered_head"), hc, hn, hr)
    if not os.path.exists(os.path.join(TEX, "g_funeral_m_lower_Color.png")):
        col, hgt, rough = sk["paint_body"](ras_up, meta, "male", True)
        col, hgt, rough = paint_shirt(ras_up, col, hgt, rough, dict(color=(0.76, 0.74, 0.68), sleeve=0.97, buttons=True), sc)
        finish_body_tex(os.path.join(TEX, "g_funeral_m_upper"), ras_up, col, hgt, rough)
        rw = VAR["wide"]["ras"]
        col, hgt, rough = sk["paint_body"](rw, meta, "male", True)
        col, hgt, rough = paint_lower(rw, col, hgt, rough, dict(color=(0.74, 0.72, 0.66), hem=0.105), None, "male", sc)
        finish_body_tex(os.path.join(TEX, "g_funeral_m_lower"), rw, col, hgt, rough)
    # Shroud upper & lower painted directly onto BodyUpper & LowerSkirt!
    col, hgt, rough = sk["paint_body"](ras_up, meta, "elder_male", "withered")
    col, hgt, rough = paint_shroud_upper(ras_up, col, hgt, rough, sc)
    finish_body_tex(os.path.join(TEX, "g_shroud_upper"), ras_up, col, hgt, rough)
    rs_m = VAR["skirt"]["ras"]
    col, hgt, rough = sk["paint_body"](rs_m, meta, "elder_male", "withered")
    col, hgt, rough = paint_shroud_lower(rs_m, col, hgt, rough, VAR["skirt"]["tube"], sc)
    finish_body_tex(os.path.join(TEX, "g_shroud_lower"), rs_m, col, hgt, rough)

    # ---- FEMALE GHOST TEXTURES (16 sets: 4 heads, 6 uppers, 6 lowers) ----
    sc, body, rig, fr, meta, ras_up, VAR = prepare_char("female")
    # Paint the 5 new painted-cloth uppers:
    # 1. g_tani_upper (green chest wrap + green sabai painted on BodyUpper)
    col, hgt, rough = sk["paint_body"](ras_up, meta, "female", True)
    col, hgt, rough = paint_sabai_upper(ras_up, col, hgt, rough, (0.14, 0.25, 0.16), "ghost_sabai_green", sc)
    finish_body_tex(os.path.join(TEX, "g_tani_upper"), ras_up, col, hgt, rough)
    # 2. g_thai_upper (dark crimson chest wrap + cream sabai painted on BodyUpper — for ghost_mirror & ghost_headless)
    col, hgt, rough = sk["paint_body"](ras_up, meta, "female", True)
    col, hgt, rough = paint_sabai_upper(ras_up, col, hgt, rough, (0.32, 0.12, 0.12), "ghost_sabai_cream", sc)
    finish_body_tex(os.path.join(TEX, "g_thai_upper"), ras_up, col, hgt, rough)
    # 3. g_nak_upper (dark purple chest wrap + muted purple sabai painted on BodyUpper — for ghost_mae_nak)
    col, hgt, rough = sk["paint_body"](ras_up, meta, "female", True)
    col, hgt, rough = paint_sabai_upper(ras_up, col, hgt, rough, (0.20, 0.13, 0.22), "ghost_sabai_nak", sc)
    finish_body_tex(os.path.join(TEX, "g_nak_upper"), ras_up, col, hgt, rough)
    # 4. g_funeral_f_upper (dirty white blouse + white sabai painted on BodyUpper)
    col, hgt, rough = sk["paint_body"](ras_up, meta, "female", True)
    col, hgt, rough = paint_shirt(ras_up, col, hgt, rough, dict(color=(0.78, 0.76, 0.70), sleeve=0.97, buttons=True), sc)
    col, hgt, rough = paint_sabai_upper(ras_up, col, hgt, rough, None, "ghost_sabai_white", sc, over_blouse=True)
    finish_body_tex(os.path.join(TEX, "g_funeral_f_upper"), ras_up, col, hgt, rough)
    # 5. g_dancer_upper (classical Thai dancer bodice + sabai + gold collar + pendant + armlets + bracelets painted on BodyUpper)
    col, hgt, rough = sk["paint_body"](ras_up, meta, "female", True)
    col = col*0.45 + np.array((0.82, 0.82, 0.81))*0.55
    col, hgt, rough = paint_dancer_upper(ras_up, col, hgt, rough, sc)
    finish_body_tex(os.path.join(TEX, "g_dancer_upper"), ras_up, col, hgt, rough)
    # Update g_dancer_lower with painted gold belt & buckle
    vv = VAR["skirt"]; rs = vv["ras"]
    col, hgt, rough = sk["paint_body"](rs, meta, "female", True)
    col = col*0.45 + np.array((0.82, 0.82, 0.81))*0.55
    col, hgt, rough = paint_skirt(rs, col, hgt, rough, "ghost_brocade_sin", vv["tube"], vv["top"], vv["hem"], sc, gold_belt=True)
    finish_body_tex(os.path.join(TEX, "g_dancer_lower"), rs, col, hgt, rough)

if __name__ == "__main__":
    try:
        paint_all_ghost_textures()
        L("ALL PAINTED GHOST TEXTURES OK")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(OUT, "ghosts_v2_paint_report.txt"), "w", encoding="utf-8").write("\n".join(log))
