# Thai village outfits for the low-poly humans (refs: art_refs/costume).
# Every piece is built from the body it sits on, so the same recipe fits child / adult / elder and thin / fat / pregnant.
#
#   exec(open(r"...\human_base\build_clothes.py", encoding="utf-8").read())
#   clothes_all()          # per character: pick the faces, paint textures, then build and save every outfit in all its .blend files
#   add_clothes("female")  # current scene: Cloth_<outfit>* objects bound to the rig (needs <name>_clothes.json from clothes_all)
#   add_outfits("female", ["ghost_tani"])   # new outfits only: faces added to the json, textures painted, built into every
#                                           # .blend of the character; the outfits already there are left exactly as they are
#   preview_all()          # renders clothes_previews/<char>.png (rows = outfits; front, 3-4, side, back)
#   preview_ghosts()       # clothes_previews/ghost_<char>.png: the ghost_* outfits only, on the SkinGhost skin
#
# Three ways to make a piece:
#   shell   faces of the body pushed out along their normals (shirts, trousers, chong kraben, chest wrap, boots).
#           Keeps the body's UVs and weights, so it bends exactly like the skin; one texture per outfit painted in body UV space.
#           The faces of each piece are chosen once on the normal body and stored in <name>_clothes.json (same faces on every body type).
#   tube    a skirt fitted around hips and legs: per height, the convex outline of the body + clearance, hanging straight down
#           (pha sin, sarong, waist sash, gold belt). Weights from the nearest skin, eased towards the hips lower down.
#   strip   a cloth band laid along a path over the body (sabai, scarf, sash tails, shoulder cloth, gold chains).
#   sweep   a stiff tapered lens / horn along a path (belt buckle)
#   crown / flowers   the dancer's chada crown (lathe round the head, covering it to the nape) and the flowers at her temples
# Patterned cloth (plaid, ikat, stripes, straw, gold) uses shared tiling textures in clothes_tex/: u (and v for 'metric' patterns)
# is in metres / TILE so the weave keeps its size on any body.
import bpy, bmesh, math, os, glob, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
TEX = os.path.join(M, "clothes_tex")
DIRS = {"human_base": "male", "human_female": "female", "human_child": "child",
        "human_elder_male": "elder_male", "human_elder_female": "elder_female"}
NAMES = {v: k for k, v in DIRS.items()}
N = 1024
TILE = 0.32                       # metres per texture repeat for patterned cloth

def char_dir(char): return os.path.join(M, NAMES[char])
def blend_files(char=None):
    fs = sorted(glob.glob(os.path.join(M, "human_*", "human_*.blend")))
    return [f for f in fs if char is None or DIRS[os.path.basename(os.path.dirname(f))] == char]

def sstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0, 1); return t*t*(3 - 2*t)
def sst(a, b, x):
    t = min(max((x - a)/(b - a), 0.0), 1.0); return t*t*(3 - 2*t)

# ---------------------------------------------------------------- body: regions, limb parameters, landmarks
REG = {"torso": ("hips", "spine", "chest", "shoulder.L", "shoulder.R"), "neck": ("neck",), "head": ("head",)}
for sd in "LR":
    REG["arm." + sd] = ("upper_arm." + sd, "forearm." + sd)
    REG["hand." + sd] = ("hand." + sd,) + tuple(f"{f}_0{i}.{sd}" for f in ("index", "middle", "ring", "pinky", "thumb") for i in (1, 2, 3))
    REG["leg." + sd] = ("thigh." + sd, "shin." + sd)
    REG["foot." + sd] = ("foot." + sd, "toe." + sd)

class Body:
    def __init__(self, body, rig):
        self.ob, self.rig = body, rig
        me = body.data; mw = body.matrix_world
        self.names = [g.name for g in body.vertex_groups]
        nv = len(me.vertices)
        self.w = np.zeros((nv, len(self.names)), np.float32)
        for v in me.vertices:
            for g in v.groups: self.w[v.index, g.group] = g.weight
        self.co = np.array([tuple(mw @ v.co) for v in me.vertices])
        self.nrm = np.array([tuple((mw.to_3x3() @ v.normal).normalized()) for v in me.vertices])
        rw = rig.matrix_world
        self.J = {b.name: (np.array(rw @ b.head_local), np.array(rw @ b.tail_local)) for b in rig.data.bones}
        # region per vertex: the body part holding most of its weight
        keys = list(REG); sums = np.zeros((nv, len(keys)))
        for i, n in enumerate(self.names):
            for k, key in enumerate(keys):
                if n in REG[key]: sums[:, k] += self.w[:, i]
        self.keys = keys; self.reg = np.array(keys)[sums.argmax(1)]
        # limb parameters: 0..1 upper arm / thigh, 1..2 forearm / shin, 2..3 hand / foot
        self.ap = np.zeros(nv); self.lp = np.zeros(nv)
        for sd in "LR":
            chain = [self.J["upper_arm." + sd][0], self.J["forearm." + sd][0], self.J["hand." + sd][0], self.J["hand." + sd][1]]
            m = np.isin(self.reg, ["arm." + sd, "hand." + sd]); self.ap[m] = self.chain_param(self.co[m], chain)
            chain = [self.J["thigh." + sd][0], self.J["shin." + sd][0], self.J["foot." + sd][0], self.J["toe." + sd][1]]
            m = np.isin(self.reg, ["leg." + sd, "foot." + sd]); self.lp[m] = self.chain_param(self.co[m], chain)
        # torso height parameter: 0 hips joint, 1 waist (spine), 2 chest joint, 3 neck joint
        zs = [self.J[b][0][2] for b in ("hips", "spine", "chest", "neck")]
        self.tz = np.interp(self.co[:, 2], zs, [0, 1, 2, 3], left=None, right=None)
        lo = self.co[:, 2] < zs[0]; self.tz[lo] = (self.co[lo, 2] - zs[0])/(zs[1] - zs[0])
        hi = self.co[:, 2] > zs[3]; self.tz[hi] = 3 + (self.co[hi, 2] - zs[3])/(zs[3] - zs[2])
        self.s = (self.J["head"][1][2] - self.J["hips"][0][2])/(1.818 - 0.880)     # 1 for the adult man
        # trunk rings (crotch .. crown). Cuts across the trunk follow a ring, so hems and necklines are clean lines
        # even where the rings tilt up over the shoulders. Ring tz = height of its front/back centre.
        self.ring = np.full(nv, -1); k = 0
        while 16*(k + 1) <= nv:
            r = self.co[16*k:16*k + 16]
            if not (abs(r[0, 0]) < 2e-3 and abs(r[8, 0]) < 2e-3 and r[0, 1] < r[8, 1] and r[4, 0] > 0 > r[12, 0]): break
            if k and r[:, 2].mean() < self.co[16*(k - 1):16*k, 2].mean(): break
            self.ring[16*k:16*k + 16] = k; k += 1
        self.nT = k
        self.ring_tz = [float(self.tz[16*i:16*i + 16][[0, 8]].mean()) for i in range(k)]
        hn = self.w[:, self.names.index("neck")] + self.w[:, self.names.index("head")]
        self.collar = next((i for i in range(k) if hn[16*i:16*i + 16].mean() > 0.5), k)   # first ring that belongs to the neck (only used on the normal body)
        self.foot_z = self.co[:, 2].min()
        # BVH of the whole skin and of the trunk only (arms out of the way of rays aimed at the torso)
        bm = bmesh.new(); bm.from_mesh(me); bm.transform(mw); bm.faces.ensure_lookup_table()
        self.bvh = BVHTree.FromBMesh(bm)
        trunk = set(np.where(np.isin(self.reg, ["torso", "neck"]))[0])
        tb = bm.copy(); tb.faces.ensure_lookup_table()
        bmesh.ops.delete(tb, geom=[f for f in tb.faces if not all(v.index in trunk for v in f.verts)], context='FACES')
        self.trunk = BVHTree.FromBMesh(tb); tb.free(); bm.free()
        self.nbr = [[] for _ in range(nv)]
        for e in me.edges:
            a_, c_ = e.vertices; self.nbr[a_].append(c_); self.nbr[c_].append(a_)
        ua = [i for i, n in enumerate(self.names) if n.startswith("upper_arm")]
        self.armw = self.w[:, ua].sum(1) if ua else np.zeros(nv)                # how much each vertex follows an upper arm
        self.kd = KDTree(nv)
        for i, p in enumerate(self.co): self.kd.insert(p, i)
        self.kd.balance()

    @staticmethod
    def chain_param(P, chain):
        best = np.full(len(P), 1e9); par = np.zeros(len(P))
        for i in range(len(chain) - 1):
            a, b = chain[i], chain[i + 1]; d = b - a; L2 = d @ d
            t = np.clip(((P - a) @ d)/L2, 0, 1); dist = np.linalg.norm(P - (a + t[:, None]*d), axis=1)
            k = dist < best; best[k] = dist[k]; par[k] = i + t[k]
        return par

    def z(self, tz):
        zs = [self.J[b][0][2] for b in ("hips", "spine", "chest", "neck")]
        return float(np.interp(tz, [0, 1, 2, 3], zs))

    def face_attr(self, p):
        vs = list(p.vertices)
        regs = list(self.reg[vs]); reg = max(set(regs), key=regs.count)
        tz = float(self.tz[vs].mean())
        rg = self.ring[vs]
        if (rg >= 0).all():                      # a trunk face between two rings: it sits at its lower ring
            lo = int(rg.min()); tz = self.ring_tz[lo]
            reg = "neck" if lo >= self.collar else "torso"
        return reg, tz, float(self.ap[vs].mean()), float(self.lp[vs].mean())

    def push(self, p, clear, trunk=False):
        bvh = self.trunk if trunk else self.bvh
        loc, nrm, _, _ = bvh.find_nearest(p)
        if loc is None: return p, Vector((0, 0, 1))
        side = (p - loc).dot(nrm)
        if side < clear: p = p + nrm*(clear - side)
        return p, nrm

    def surf(self, origin, direction, trunk=True):
        hit = (self.trunk if trunk else self.bvh).ray_cast(Vector(origin), Vector(direction).normalized(), 5.0)
        return hit[0], hit[1]

# ---------------------------------------------------------------- outfits
# piece specs:
#   ("shell", piece, test(reg, tz, ap, lp), offset(reg, tz, ap, lp) in m (x body scale), fabric)
#   ("tube", name, top_tz, bottom (("tz", t) | ("lp", t) | ("floor", m)), pattern, kw)
#   ("strip", name, path_fn, width, pattern, kw)
#   ("ring", name, joint, t, pattern, kw)        bracelets / anklets
#   ("hat", name, pattern)
def arm(reg): return reg.startswith("arm")
def leg(reg): return reg.startswith("leg")
def foot(reg): return reg.startswith("foot")
def torso(reg): return reg == "torso"

# Room for the skin under the cloth (m, x body scale): where a joint bends, skin and cloth skinned to the same bones
# don't move the same way, and a shell close to the skin lets it through. The skin under a shell is hidden in Roblox
# (hidden_faces) except a ring along its openings, so the room is only given near the openings (cuffs, hems, collar)
# and the cloth hugs the body everywhere else. With the room all over, the men looked like american-football players.
ROOM = 1.0              # near the openings only (EDGE_RINGS of the shell's edge): the skin still shows there
EDGE_RINGS = 3          # vertex rings from a shell's open edge that get ROOM, fading out over the last one
ARMPIT_SIDE = 0.03      # torso skin that partly follows the upper arm, at armw >= 1/ARMPIT_RAMP
ARMPIT_RAMP = 3.0
ARMPIT = 0.025          # the armpit itself (trunk-ring vertices held by the arm)
SLEEVE_ROOT = 0.010     # top of the sleeve, fading out by mid upper arm
CHEST_EASE = 0.006      # upper chest
ELBOW = 0.020           # inside of the elbow of long sleeves
HIP = 0.020             # hip crease and seat (thigh lifting) / knee of long trousers
CROTCH = 0.012
# the armpit room on the arm (ARMPIT and SLEEVE_ROOT) is cut where the skin faces up: the top / outside of the
# shoulder keeps less of it, so the shoulder doesn't stick out
ARMPIT_MODE = "up"
ARMPIT_UP = (0.2, 0.7)
ARMPIT_IN = (-0.4, 0.7)
ARMPIT_TOP = 0.3        # share of the cut room the top of the shoulder still keeps

def top(sleeve, hem=1.05, loose=0.006, hang=0.010):
    """shirt: trunk from `hem` (tz) up to the neck, sleeves to arm parameter `sleeve` (1 = elbow, 2 = wrist)"""
    test = lambda r, tz, ap, lp: ((torso(r) or leg(r)) and hem <= tz) or (arm(r) and ap < sleeve)   # front of the hip can be "leg"
    def off(r, tz, ap, lp, room=ROOM):
        o = loose
        if torso(r): o += hang*(1 - sst(hem, hem + 0.45, tz))        # hangs out a little at the hem
        if arm(r): o += 0.006*sst(sleeve - 0.5, sleeve, ap)*(sleeve < 1.8)   # short sleeves open out
        if arm(r) and sleeve > 1.1: o += room*ELBOW*math.exp(-((ap - 1.0)/0.30)**2)   # elbow: the inside folds through when it bends
        if torso(r): o += room*CHEST_EASE*sst(1.9, 2.4, tz)*(1 - sst(2.9, 3.1, tz))
        return o
    return test, off

def bottom(length, top_tz=1.05, loose=0.007, flare=0.0, puff=0.0, wide=0.0):
    """trousers: trunk below `top_tz` and legs to leg parameter `length` (1 = knee, 2 = ankle); `wide` = baggy legs"""
    test = lambda r, tz, ap, lp: (torso(r) and tz < top_tz) or (leg(r) and lp < length)
    def off(r, tz, ap, lp, room=ROOM):
        o = loose
        if leg(r):
            o += flare*sst(length - 0.6, length, lp)
            o += puff*math.sin(math.pi*min(lp/length, 1.0))**0.8
            o += wide*sst(0.15, 1.3, lp)
            o += room*HIP*(1 - sst(0.0, 0.60, lp))       # hip crease and seat: room for the thigh lifting (running)
            if length > 1.3: o += room*HIP*math.exp(-((lp - 1.0)/0.25)**2)   # knee of long trousers
        elif torso(r):
            o += room*0.008*(1 - sst(0.3, 0.9, tz))
            o += puff*0.45*sst(top_tz, top_tz - 0.6, tz)
        return o
    return test, off

def chest_wrap(lo=1.80, hi=2.40):
    """ผ้าแถบ: a band round the chest only (under a sabai)"""
    off = lambda r, tz, ap, lp, room=0: 0.004
    off.no_room = True                    # no armpit / opening room: it would bulge out under the sabai
    return lambda r, tz, ap, lp: torso(r) and lo <= tz < hi, off

def boots(top_lp=1.55):
    return (lambda r, tz, ap, lp: (leg(r) and lp >= top_lp) or foot(r),
            lambda r, tz, ap, lp, room=0: 0.006 + 0.008*sst(top_lp + 0.25, top_lp, lp)*leg(r) + 0.010*math.exp(-((lp - 2.0)/0.25)**2))   # roomy ankle

# --- strip paths, in body landmarks (functions of Body -> list of world points)
def _front(b, x, z, trunk=True): return b.surf((x, -2, z), (0, 1, 0), trunk)[0]
def _back(b, x, z, trunk=True): return b.surf((x, 2, z), (0, -1, 0), trunk)[0]
def _side(b, sx, y, z): return b.surf((sx*2, y, z), (-sx, 0, 0), True)[0]
def _top(b, x, y): return b.surf((x, y, 3), (0, 0, -1), True)[0]
def _lerp(a, b, t): return a + (b - a)*t

def path_sabai(b, side_tz=2.15):
    """over the left shoulder, across the chest, under the right arm (at side_tz), round the back; then a tail down the back"""
    sh = b.J["shoulder.L"]; x_sh = sh[0][0]*0.5 + sh[1][0]*0.5
    zc = b.z(side_tz)
    pts = [_top(b, x_sh, 0.0)]
    zt = pts[0].z
    for t in np.linspace(0.12, 1.0, 7):          # front diagonal
        pts.append(_front(b, _lerp(x_sh, -0.10*b.s, t), _lerp(zt, zc, t)))
    pts.append(_side(b, -1, 0.0, zc))
    for t in np.linspace(1.0, 0.12, 7):          # back diagonal
        pts.append(_back(b, _lerp(x_sh, -0.10*b.s, t), _lerp(zt, zc, t)))
    pts.append(pts[0].copy())
    tail = [pts[0].copy()] + [_back(b, x_sh + 0.01, z) for z in np.linspace(zt - 0.06*b.s, b.z(1.45), 6)]   # ends above the skirt
    return [pts, tail]

def path_scarf(b):
    """round the back of the neck, over both shoulders, both ends hanging down the front"""
    zn = b.J["neck"][0][2]; xs = 0.085*b.s
    out = []
    left = [_front(b, xs, z) for z in np.linspace(b.z(1.2), b.z(2.4), 6)] + [_top(b, xs*0.9, b.J["neck"][0][1])]
    back = [_back(b, xs*0.5, zn + 0.01), _back(b, 0, zn + 0.015), _back(b, -xs*0.5, zn + 0.01)]
    right = [_top(b, -xs*0.9, b.J["neck"][0][1])] + [_front(b, -xs, z) for z in np.linspace(b.z(2.4), b.z(1.3), 6)]
    out.append(left + back + right)
    return out

def path_shoulder_cloth(b):
    """a folded cloth over the left shoulder, hanging to mid-chest in front and behind"""
    sh = b.J["shoulder.L"]; x = sh[0][0]*0.35 + sh[1][0]*0.65
    zb = b.z(2.0)
    return [[_front(b, x, z) for z in np.linspace(zb, b.z(2.75), 4)] + [_top(b, x, 0.0)] + [_back(b, x, z) for z in np.linspace(b.z(2.75), zb, 4)]]

def path_sash_tails(b):
    """two loose ends from a knot at the front-left of the waist"""
    zk = b.z(0.95); x = 0.06*b.s
    t1 = [_front(b, x, zk, False) + Vector((0, -0.01, 0))] + [_front(b, x - 0.015*b.s + 0.004*i*b.s, z, False) for i, z in enumerate(np.linspace(zk - 0.05*b.s, b.z(-0.9), 6))]
    t2 = [_front(b, x + 0.01, zk, False) + Vector((0, -0.01, 0))] + [_front(b, x + 0.03*b.s + 0.006*i*b.s, z, False) for i, z in enumerate(np.linspace(zk - 0.05*b.s, b.z(-0.55), 5))]
    return [t1, t2]

def path_chains(b):
    """สังวาล: two gold chains crossing on the chest, shoulder to opposite hip"""
    out = []
    for sx in (1, -1):
        sh = b.J["shoulder.L" if sx > 0 else "shoulder.R"]; x = sh[0][0]*0.4 + sh[1][0]*0.6
        top_p = _top(b, x, 0.0)
        f = [top_p] + [_front(b, _lerp(x, -sx*0.06*b.s, t), _lerp(top_p.z - 0.02*b.s, b.z(1.0), t)) for t in np.linspace(0.05, 1.0, 9)]
        bk = [_back(b, _lerp(x, -sx*0.06*b.s, t), _lerp(top_p.z - 0.02*b.s, b.z(1.0), t)) for t in np.linspace(1.0, 0.05, 9)] + [top_p]
        out += [f, bk]
    return out

def path_epaulets(b):
    """ทองต้นแขน on the shoulders: a short gold crescent over each shoulder, from the back of it onto the front"""
    out = []
    for sd, sx in (("L", 1), ("R", -1)):
        sh = b.J["shoulder." + sd]
        for f in (0.90, 0.82, 0.74, 0.66):                   # out on the shoulder, as far as the shoulder top reaches
            x = sh[0][0]*(1 - f) + sh[1][0]*f; top_p = _top(b, x, 0.0)
            if top_p is not None: break
        pts = [_back(b, x, top_p.z - 0.05*b.s), top_p]
        pts += [_front(b, x - sx*0.02*b.s*t, top_p.z - 0.10*b.s*t) for t in (0.4, 0.8, 1.0)]
        out.append(pts)
    return out

def path_collar(b):
    """กรองคอ: a gold band round the base of the neck, lying on the shoulders and the top of the chest and back"""
    nj = b.J["neck"][0]; nv = b.co[b.reg == "neck"]
    rn = float(np.percentile(np.hypot(nv[:, 0] - nj[0], nv[:, 1] - nj[1]), 90)) + 0.035*b.s     # just outside the neck
    out = []
    for a in np.linspace(0, 2*math.pi, 41):
        x, y = nj[0] + math.sin(a)*rn, nj[1] - math.cos(a)*rn*0.95
        hit = _top(b, x, y)                                       # straight down onto the shoulders / chest / back
        if hit is None or hit.z < nj[2] - 0.09*b.s:              # in front the ray can miss the chest: go in from the front
            d = Vector((math.sin(a), -math.cos(a), 0.0)); o = Vector((nj[0], nj[1], nj[2] - 0.05*b.s))
            hit = b.surf(o + d*0.3*b.s, -d, True)[0]
        if hit is not None: out.append(hit)
    return [out]

def path_sabai_low(b):
    """path_sabai going round the right side below the armpit (over a blouse with sleeves: clear of the sleeve)"""
    return path_sabai(b, side_tz=1.85)

def path_sabai_long(b):
    """สไบห้อยยาว: path_sabai, its tail hanging free behind the hips down to the floor"""
    loop, tail = path_sabai(b, side_tz=1.85)          # down to the right side of the waist, clear of the armpit and sleeve
    sh = b.J["shoulder.L"]; x_sh = sh[0][0]*0.5 + sh[1][0]*0.5
    hips = b.co[(b.reg == "torso") & (b.tz < 0.6)]
    yb = float(hips[:, 1].max()) + 0.045*b.s                      # behind the seat
    zw = b.z(1.0)
    pw = next((q for q in (_back(b, x_sh + 0.01 - dx*b.s, zw) for dx in (0.0, 0.03, 0.06)) if q is not None), None)
    tail = tail[:-2] + ([pw + Vector((0, 0.02*b.s, 0))] if pw is not None else [])
    tail += [Vector((x_sh*0.9, yb, z)) for z in np.linspace(b.z(0.3), b.foot_z + 0.02*b.s, 6)]
    return [loop, tail]

def _horn(pts, r0, r1, flat, n0, w):
    n = len(pts); return dict(pts=pts, radii=[r0 + (r1 - r0)*(i/(n - 1))**0.8 for i in range(n)], flat=flat, n0=n0, w=w)

def path_pendant(b):
    """ทับทรวง: a big gold pendant on the chest below the collar (a flat lens, longer than wide)"""
    s = b.s; zc = b.z(2.45)
    c = _front(b, 0.0, zc, True) or _front(b, 0.0, zc, False)
    pts = [c + Vector((0, 0.004*s*(abs(t))**2, t*s)) for t in np.linspace(0.055, -0.055, 9)]
    hn = _horn(pts, 0, 0, 0.20, Vector((0, -1, 0)), {"chest": 1.0})
    hn["radii"] = [0.042*s*math.sin(math.pi*(0.06 + 0.88*i/8))**0.6 for i in range(9)]
    return [hn]

def path_buckle(b):
    """ปั้นเหน่ง: a big oval buckle on the front of the belt (a flat lens across, thick in the middle)"""
    s = b.s; z = b.z(1.32)
    c = _front(b, 0.0, z, True) or _front(b, 0.0, z, False)
    pts = [c + Vector((x*s, 0.004*s*(abs(x)/0.05)**2, 0)) for x in np.linspace(-0.05, 0.05, 9)]
    hn = _horn(pts, 0, 0, 0.22, Vector((0, -1, 0)), {"hips": 0.5, "spine": 0.5})
    hn["radii"] = [0.034*s*math.sin(math.pi*(0.06 + 0.88*i/8))**0.6 for i in range(9)]
    return [hn]

# footwear: villagers wear flip-flops (sandal), teens and the better dressed sneakers (shoe), field work boots
OUTFITS = {
    # ---- men (refs: ม่อฮ่อม + ขาก๊วย + ผ้าขาวม้า, ชาวนา, โสร่ง, เสื้อแดงคอปก)
    "mohom": [("shell", "shirt", *top(1.25, hem=0.95), "indigo"), ("shell", "shorts", *bottom(1.12, top_tz=0.95, flare=0.020), "indigo_dark"),
              ("tube", "sash", 0.85, ("tz", 1.20), "plaid_pink", dict(clear=0.012, band=True)),
              ("strip", "sash_tails", path_sash_tails, 0.075, "plaid_pink", dict(clear=0.02)),
              ("sandal", "sandals", "sandal_blue")],
    "farmer": [("shell", "shirt", *top(1.98, hem=0.95), "indigo_pocket"), ("shell", "jeans", *bottom(1.56, top_tz=0.95, loose=0.008), "denim"),
               ("shell", "boots", *boots(1.55), "rubber"),
               ("tube", "sash", 0.85, ("tz", 1.20), "plaid_pink", dict(clear=0.012, band=True)),
               ("strip", "sash_tails", path_sash_tails, 0.075, "plaid_pink", dict(clear=0.02)),
               ("hat", "ngob", "straw")],
    "sarong": [("tube", "sarong", 0.70, ("lp", 2.0), "plaid_red", dict(clear=0.024, roll=True)),
               ("strip", "shoulder_cloth", path_shoulder_cloth, 0.12, "red_cloth", dict(clear=0.004, thick=0.004)),
               ("sandal", "sandals", "sandal_black")],
    "red_shirt": [("shell", "shirt", *top(1.98, hem=0.40, loose=0.006, hang=0.008), "red_knit"),
                  ("shell", "trousers", *bottom(1.97, top_tz=0.40, loose=0.008, flare=0.006), "black_cotton"),
                  ("shoe", "shoes", "skate_black")],
    "wan_baggy": [("shell", "shirt", *top(1.15, hem=0.40, loose=0.006, hang=0.008), "grey_shirt"),
                  ("shell", "pants", *bottom(2.0, top_tz=0.40, loose=0.010, wide=0.035, flare=0.015), "black_baggy"),
                  ("shoe", "shoes", "vans_checker")],
    "wan_flannel": [("shell", "shirt", *top(1.97, hem=0.40, loose=0.006, hang=0.008), "flannel_tee"),
                    ("shell", "pants", *bottom(2.0, top_tz=0.40, loose=0.010, wide=0.035, flare=0.015), "black_baggy"),
                    ("shoe", "shoes", "skate_black")],
    "wan_denim": [("shell", "jacket", *top(1.97, hem=0.55, loose=0.006, hang=0.008), "denim_jacket"),
                  ("shell", "jeans", *bottom(1.98, top_tz=0.55, loose=0.008), "jeans_ripped"), ("shoe", "shoes", "vans_checker"),
                  ("helmet", "helmet", "helmet_white"), ("helmet", "visor", "visor_black")],
    "wan_camo": [("shell", "tee", *top(1.2, hem=0.40, loose=0.006, hang=0.008), "black_tee"),
                 ("shell", "pants", *bottom(1.98, top_tz=0.40, loose=0.012, wide=0.025), "camo"),
                 ("shoe", "shoes", "skate_black"),
                 ("helmet", "helmet", "helmet_white"), ("helmet", "visor", "visor_black")],
    # ---- women (refs: เสื้อแขนกระบอก + ผ้าซิ่น, เสื้อครามพาดผ้า, เสื้อขาว + สไบ + ซิ่นตีนจก, ผ้าแถบ + โจงกระเบน)
    "blouse_sin": [("shell", "blouse", *top(1.97, hem=0.35, loose=0.004, hang=0.006), "jade_blouse"),
                   ("tube", "sin", 1.30, ("lp", 1.62), "sin_purple", dict(clear=0.024)),
                   ("sandal", "sandals", "sandal_brown")],
    "indigo_scarf": [("shell", "shirt", *top(1.97, hem=0.35, loose=0.005, hang=0.008), "indigo"),
                     ("tube", "sin", 1.30, ("lp", 1.92), "sin_ikat", dict(clear=0.024)),
                     ("strip", "scarf", path_scarf, 0.10, "scarf_stripe", dict(clear=0.012)),
                     ("sandal", "sandals", "sandal_blue")],
    "sabai": [("shell", "blouse", *top(1.97, hem=0.35, loose=0.004, hang=0.006), "white_blouse"),
              ("tube", "sin", 1.30, ("lp", 1.92), "sin_tinjok", dict(clear=0.024)),
              ("strip", "sabai", path_sabai, 0.12, "sabai_red", dict(clear=0.012)),
              ("sandal", "sandals", "sandal_red")],
    "chest_wrap": [("shell", "wrap", lambda r, tz, ap, lp: torso(r) and 1.80 <= tz < 2.35, lambda r, tz, ap, lp, room=0: 0.004, "red_satin"),
                   ("shell", "chong", *bottom(1.30, top_tz=0.92, loose=0.008, puff=0.030), "maroon"),
                   ("tube", "belt", 0.88, ("tz", 1.12), "gold", dict(clear=0.010, band=True)),
                   ("sandal", "sandals", "sandal_red")],
    "wan_band_tee": [("shell", "tee", *top(1.2, hem=0.40, loose=0.006, hang=0.006), "band_tee"),
                     ("shell", "jeans", *bottom(2.0, top_tz=0.40, loose=0.006, flare=0.004), "black_jeans"),
                     ("shoe", "shoes", "skate_black")],
    "wan_crop": [("shell", "tee", *top(1.12, hem=1.55, loose=0.004, hang=0.0), "cocoa_tee"),
                 ("shell", "pants", *bottom(2.0, top_tz=1.0, loose=0.008, wide=0.030, flare=0.010), "pink_dots"),
                 ("sandal", "slides", "sandal_pink", dict(slide=True))],
    "wan_plaid": [("shell", "shirt", *top(1.97, hem=0.35, loose=0.009, hang=0.012), "green_plaid"),
                  ("shell", "jeans", *bottom(2.0, top_tz=0.35, loose=0.006, flare=0.004), "black_jeans"),
                  ("shoe", "shoes", "skate_black")],
    # ---- child (refs: โจงกระเบนแดง + สังวาล + กำไล, ม่อฮ่อมเด็ก)
    "wan_girl": [("shell", "shirt", *top(1.97, hem=1.06, loose=0.006, hang=0.008), "lightblue_open"),
                 ("shell", "jeans", *bottom(2.0, top_tz=1.06, loose=0.010, wide=0.030, flare=0.012), "jeans_belt"),
                 ("shoe", "shoes", "skate_black")],
    "chong_gold": [("shell", "chong", *bottom(1.25, top_tz=0.92, loose=0.008, puff=0.026), "red_chong"),
                   ("tube", "belt", 0.86, ("tz", 1.10), "gold", dict(clear=0.010, band=True)),
                   ("strip", "chains", path_chains, 0.012, "gold", dict(clear=0.006, thick=0.006)),
                   ("ring", "bracelets", "hand", 0.0, "gold", {}), ("ring", "anklets", "foot", 0.0, "gold", {}),
                   ("sandal", "sandals", "sandal_red")],
    "mohom_child": [("shell", "shirt", *top(1.2, hem=0.95), "indigo"), ("shell", "shorts", *bottom(0.85, top_tz=0.95, flare=0.014), "indigo_dark"),
                    ("sandal", "sandals", "sandal_blue")],
    # ---- ghosts (GHOST_MODELS.md): pale, dull cloth with dirt, old blood and torn holes, ragged skirt hems, barefoot
    "ghost_thai": [("shell", "wrap", *chest_wrap(), "ghost_cream_wrap"),          # ผีในกระจก (11): สไบครีม + ซิ่นแดงขอบทอง
                   ("tube", "sin", 1.30, ("lp", 1.92), "ghost_sin_red", dict(clear=0.024, ragged=0.05)),
                   ("strip", "sabai", path_sabai, 0.13, "ghost_sabai_cream", dict(clear=0.020, over=True, cols=4))],
    "ghost_headless": [("shell", "wrap", *chest_wrap(), "ghost_cream_wrap_blood"),  # ผีไร้หัว (1): ชุดเดียวกัน + เลือดไหลจากคอ
                       ("tube", "sin", 1.30, ("lp", 1.92), "ghost_sin_red", dict(clear=0.024, ragged=0.05)),
                       ("strip", "sabai", path_sabai, 0.13, "ghost_sabai_cream_blood", dict(clear=0.020, span=True, over=True, cols=4))],
    "ghost_tani": [("shell", "wrap", *chest_wrap(), "ghost_green_wrap"),           # นางตานี (17): สไบเขียว + ซิ่นเขียว
                   ("tube", "sin", 1.30, ("lp", 1.98), "ghost_sin_green", dict(clear=0.024, ragged=0.06)),
                   ("strip", "sabai", path_sabai, 0.13, "ghost_sabai_green", dict(clear=0.020, over=True, cols=4))],
    "ghost_white_f": [("shell", "blouse", *top(1.97, hem=0.35, loose=0.004, hang=0.006), "ghost_white_blouse"),   # ขบวนแห่ศพ (29): ชุดขาวชีพราหมณ์
                      ("tube", "sin", 1.30, ("lp", 1.98), "ghost_sin_white", dict(clear=0.024, ragged=0.06)),
                      ("strip", "sabai", path_sabai_low, 0.13, "ghost_sabai_white", dict(clear=0.020, over=True, cols=4))],
    "ghost_white_m": [("shell", "shirt", *top(1.97, hem=0.40, loose=0.006, hang=0.010), "ghost_white_shirt"),     # ขบวนแห่ศพ (29): เสื้อขาวแขนยาว + กางเกงขาว
                      ("shell", "trousers", *bottom(1.97, top_tz=0.40, loose=0.010, wide=0.020, flare=0.010), "ghost_white_trousers")],
    # ผีนางรำ (ref: art_refs/body/ghost_dancer_ref.jpg): ชฎา + ดอกไม้ทัดหู + อุบะ, เสื้อผ้ายกแขนสั้นขลิบทอง, กรองคอทอง,
    # สไบแดงพาดบ่าซ้ายห้อยยาวถึงพื้นด้านหลัง, ผ้านุ่งยกยาวถึงข้อเท้ามีชายพกจีบด้านหน้า, เข็มขัดทองหัวใหญ่ (ปั้นเหน่ง), กำไล, ทองต้นแขน
    "ghost_dancer": [("shell", "blouse", *top(0.62, hem=0.95, loose=0.005, hang=0.004), "ghost_brocade_top"),
                     ("tube", "sin", 1.30, ("lp", 1.95), "ghost_brocade_sin", dict(clear=0.026, span=True, ragged=0.012)),
                     ("tube", "belt", 1.22, ("tz", 1.42), "ghost_dancer_gold", dict(clear=0.040, band=True)),
                     ("sweep", "buckle", path_buckle, "ghost_dancer_gold", dict(over=True, clear=0.006)),
                     ("strip", "collar", path_collar, 0.040, "ghost_dancer_gold", dict(clear=0.012, thick=0.004, over=True)),
                     ("strip", "sabai", path_sabai_long, 0.16, "ghost_sabai_red", dict(clear=0.032, over=True, tail_hang=True, cols=5)),
                     ("sweep", "pendant", path_pendant, "ghost_dancer_gold", dict(over=True, clear=0.006)),
                     ("ring", "bracelets", "hand", 0.0, "ghost_dancer_gold", dict(tr=0.009, room=0.007)),
                     ("ring", "armlets", "upper_arm", 0.72, "ghost_dancer_gold", dict(tr=0.006, room=0.008)),
                     ("ring", "cuffs", "forearm", 0.72, "ghost_dancer_gold", dict(tr=0.008, room=0.006)),     # wide gold cuffs: three
                     ("ring", "cuffs2", "forearm", 0.82, "ghost_dancer_gold", dict(tr=0.008, room=0.004)),    # rings stacked up the wrist
                     ("crown", "crown", "ghost_dancer_gold", dict(slim=True)),
                     ("flowers", "flowers", "ghost_flower", {})],
}
CHAR_OUTFITS = {
    "male": ["mohom", "farmer", "sarong", "red_shirt", "wan_baggy", "wan_flannel", "wan_denim", "wan_camo", "ghost_white_m"],
    "female": ["blouse_sin", "indigo_scarf", "sabai", "chest_wrap", "wan_girl", "wan_band_tee", "wan_crop", "wan_plaid",
               "ghost_thai", "ghost_headless", "ghost_tani", "ghost_white_f", "ghost_dancer"],
    "child": ["chong_gold", "mohom_child"],
    "elder_male": ["mohom", "sarong", "farmer", "ghost_white_m"],
    "elder_female": ["blouse_sin", "sabai", "indigo_scarf", "ghost_white_f"],
}
GHOST_OUTFITS = [o for o in OUTFITS if o.startswith("ghost_")]
# elders wear their colours a little faded (the ghosts' white gone yellow)
CHAR_FABRIC = {("elder_female", "jade_blouse"): "cream_blouse",
               ("elder_male", "ghost_white_shirt"): "ghost_yellowed_shirt", ("elder_female", "ghost_white_blouse"): "ghost_yellowed_blouse"}

# ---------------------------------------------------------------- fabrics painted in body-UV space (shell pieces)
FABRIC = {
    "indigo":        dict(c=(0.11, 0.17, 0.33), weave=1.0, buttons="mohom"),
    "indigo_pocket": dict(c=(0.11, 0.17, 0.33), weave=1.0, buttons="mohom", pocket=True),
    "indigo_dark":   dict(c=(0.08, 0.13, 0.27), weave=1.0, folds=1.0),
    "denim":         dict(c=(0.20, 0.28, 0.42), weave=1.6, folds=0.8, seams=True, fade=True),
    "rubber":        dict(c=(0.04, 0.04, 0.045), weave=0.0, rough=0.35),
    "red_knit":      dict(c=(0.62, 0.05, 0.07), weave=0.8, vneck=(0.05, 0.05, 0.05), logo=True),
    "black_cotton":  dict(c=(0.04, 0.04, 0.05), weave=0.8, folds=1.0),
    "jade_blouse":   dict(c=(0.30, 0.56, 0.48), weave=0.6, buttons="blouse"),      # jade green: a pink one read as bare skin
    "cream_blouse":  dict(c=(0.90, 0.84, 0.72), weave=0.6, buttons="blouse"),
    "white_blouse":  dict(c=(0.93, 0.92, 0.88), weave=0.6, buttons="blouse"),
    "red_satin":     dict(c=(0.58, 0.06, 0.12), weave=0.3, rough=0.35),
    "maroon":        dict(c=(0.36, 0.10, 0.12), weave=0.5, folds=2.0, rough=0.45),
    "red_chong":     dict(c=(0.75, 0.06, 0.06), weave=0.5, folds=2.0, rough=0.45),
    # street
    "grey_shirt":    dict(c=(0.36, 0.38, 0.40), weave=0.8, buttons="mohom", pocket=True, collar=True, folds=0.6),
    "flannel_tee":   dict(c=(0.10, 0.10, 0.11), weave=0.8, flannel=True, tee=((0.92, 0.92, 0.90), "red"), collar=True, folds=0.5),
    "black_baggy":   dict(c=(0.05, 0.05, 0.06), weave=0.9, folds=2.2),
    "denim_jacket":  dict(c=(0.14, 0.17, 0.27), weave=1.6, buttons="metal", jacket=True, collar=True, folds=0.6),
    "jeans_ripped":  dict(c=(0.10, 0.12, 0.20), weave=1.6, folds=0.8, seams=True, fade=True, rips=True),
    "black_tee":     dict(c=(0.06, 0.06, 0.07), weave=0.7, graphic="yellow", folds=0.6),
    "camo":          dict(c=(0.33, 0.36, 0.22), weave=1.0, camo=True, folds=1.6, pockets=True),
    "lightblue_open": dict(c=(0.62, 0.72, 0.88), weave=0.7, open=(0.05, 0.05, 0.06), collar=True, folds=0.5),
    "jeans_belt":    dict(c=(0.09, 0.10, 0.16), weave=1.6, folds=1.8, seams=True, belt=True),
    # teen girls at the rod-hae (ref: Screenshot 2026-11-02 143249)
    "band_tee":      dict(c=(0.05, 0.05, 0.06), weave=0.7, band=True, folds=0.6),
    "black_jeans":   dict(c=(0.06, 0.06, 0.07), weave=1.6, folds=1.0, seams=True),
    "cocoa_tee":     dict(c=(0.30, 0.21, 0.18), weave=0.7, folds=0.3),        # darker than the skin, so it reads as a shirt
    "pink_dots":     dict(c=(0.80, 0.56, 0.63), weave=0.6, dots=(0.55, 0.34, 0.42), folds=1.8),
    "green_plaid":   dict(c=(0.16, 0.34, 0.24), weave=0.8, buttons="mohom", collar=True, folds=0.8,
                          plaid=[(0.30, (0.13, 0.30, 0.21)), (0.10, (0.88, 0.90, 0.86)), (0.25, (0.30, 0.52, 0.38)), (0.10, (0.88, 0.90, 0.86)), (0.25, (0.06, 0.14, 0.10))]),
    # ghosts: `ghost` = how far gone the cloth is (see ghost_shell): pale / dirt / blood / holes, neck = blood run down from a cut neck
    "ghost_cream_wrap":       dict(c=(0.80, 0.74, 0.60), weave=0.6, folds=0.6, rough=0.85, ghost=dict(pale=0.30, dirt=1.0, blood=0.5, holes=0.6)),
    "ghost_cream_wrap_blood": dict(c=(0.80, 0.74, 0.60), weave=0.6, folds=0.6, rough=0.85, ghost=dict(pale=0.30, dirt=1.0, blood=0.6, holes=0.6, neck=True)),
    "ghost_green_wrap":       dict(c=(0.12, 0.30, 0.17), weave=0.6, folds=0.6, rough=0.85, ghost=dict(pale=0.35, dirt=1.0, blood=0.3, holes=0.6)),
    "ghost_white_blouse":     dict(c=(0.86, 0.86, 0.82), weave=0.6, buttons="blouse", folds=0.5, ghost=dict(pale=0.2, dirt=1.0, blood=0.35, holes=0.8)),
    "ghost_yellowed_blouse":  dict(c=(0.82, 0.78, 0.64), weave=0.6, buttons="blouse", folds=0.5, ghost=dict(pale=0.2, dirt=1.2, blood=0.35, holes=0.9)),
    "ghost_white_shirt":      dict(c=(0.86, 0.86, 0.83), weave=0.7, buttons="blouse", folds=0.6, ghost=dict(pale=0.2, dirt=1.0, blood=0.35, holes=0.8)),
    "ghost_yellowed_shirt":   dict(c=(0.82, 0.78, 0.65), weave=0.7, buttons="blouse", folds=0.6, ghost=dict(pale=0.2, dirt=1.2, blood=0.35, holes=0.9)),
    "ghost_white_trousers":   dict(c=(0.84, 0.84, 0.80), weave=0.7, folds=1.6, ghost=dict(pale=0.2, dirt=1.6, blood=0.25, holes=0.8)),
    # green brocade body, red yoke over the shoulders and red sleeves (ref: art_refs/body/ghost_dancer_ref_colors.png)
    "ghost_brocade_top":      dict(c=(0.07, 0.27, 0.15), yoke=(0.55, 0.06, 0.08), weave=0.5, rough=0.6, brocade=True, folds=0.3,
                                   ghost=dict(pale=0.22, dirt=0.30, blood=0.0, holes=0.0, fray=0.0, gold_edges=True)),
}

# ---------------------------------------------------------------- noise
_P = np.random.RandomState(9).permutation(256); _P = np.concatenate([_P, _P])
def _fade(t): return t*t*t*(t*(t*6 - 15) + 10)
def vnoise(*co, seed=0, period=None):
    co = [np.asarray(c, dtype=np.float64) + seed*13.7*(i + 1)*(period is None) for i, c in enumerate(co)]
    fl = [np.floor(c).astype(np.int64) for c in co]; fr = [_fade(c - f) for c, f in zip(co, fl)]
    wrap = (lambda a: a % period) if period else (lambda a: a)
    def h(*ix):
        a = np.full_like(ix[0], seed % 256)
        for v in ix: a = _P[(a + wrap(v)) & 255]
        return a/255.0
    if len(co) == 2:
        x, y = fl; u, v = fr
        return (h(x, y)*(1-u) + h(x+1, y)*u)*(1-v) + (h(x, y+1)*(1-u) + h(x+1, y+1)*u)*v
    x, y, z = fl; u, v, w = fr
    def lay(zz): return (h(x, y, zz)*(1-u) + h(x+1, y, zz)*u)*(1-v) + (h(x, y+1, zz)*(1-u) + h(x+1, y+1, zz)*u)*v
    return lay(z)*(1-w) + lay(z+1)*w

def fbm(*co, oct=3, seed=0, period=None):
    s, a, t = 0.0, 0.5, 0.0
    for o in range(oct):
        s = s + a*vnoise(*[c*(2**o) for c in co], seed=seed + o, period=period*(2**o) if period else None); t += a; a *= 0.5
    return s/t

# ---------------------------------------------------------------- image helpers
def save_png(arr, path, noncolor):
    if arr.ndim == 2: arr = np.stack([arr]*3, -1)
    rgba = np.concatenate([np.clip(arr, 0, 1), np.ones(arr.shape[:2] + (1,))], -1).astype(np.float32)
    name = "_tmp_save"
    img = bpy.data.images.new(name, arr.shape[1], arr.shape[0], alpha=False)
    if noncolor: img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.ravel()); img.filepath_raw = path; img.file_format = 'PNG'
    for attempt in range(6):        # Windows sometimes refuses a file that was just read / written (scanner, indexer)
        try: img.save(); break
        except RuntimeError:
            if attempt == 5: raise
            import time; time.sleep(1.0 + attempt)
    bpy.data.images.remove(img)

def normal_from_height(hgt, ppm_x, ppm_y, wrap=False):
    if wrap:
        gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1))/2; gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0))/2
    else:
        gy, gx = np.gradient(hgt)
    nx, ny = -gx*ppm_x, -gy*ppm_y
    ln = np.sqrt(nx**2 + ny**2 + 1)
    return np.stack([nx/ln, ny/ln, 1/ln], -1)*0.5 + 0.5

def mix(col, c, a):
    a = np.clip(a, 0, 1)[..., None]; return col*(1 - a) + np.asarray(c)*a

# ---------------------------------------------------------------- tiling pattern textures (shared)
# X: metres across the tile (periodic over TILE). Y: metres (metric) or 0..1 bottom->top (norm, skirts: 0 = hem; strips: across the band)
PATTERNS = {}
def pattern(name, mode, metal=False):
    def deco(fn): PATTERNS[name] = (fn, mode, metal); return fn
    return deco

def stripes(x, period, bands):
    """bands = [(fraction, colour)], repeating every `period` metres"""
    f = (x % period)/period; out = np.zeros(x.shape + (3,)); acc = 0.0
    for fr, c in bands:
        m = (f >= acc) & (f < acc + fr); out[m] = c; acc += fr
    return out

def weave(X, Y, s=1.0):
    return 0.5 + 0.5*np.sin(X*2*math.pi/0.0016)*np.sin(Y*2*math.pi/0.0016)*s

def plaid(X, Y, bands, P=0.08):
    a = stripes(X, P, bands); b = stripes(Y, P, bands)
    tw = (np.sin((X + Y)*2*math.pi/0.0032) > 0)[..., None]                    # twill: warp or weft on top
    return np.where(tw, a, b)*0.85 + (a + b)*0.075

@pattern("plaid_red", "metric")
def _plaid_red(X, Y):       # ผ้าขาวม้า: red with purple / green bars, thin yellow + black lines
    B = [(0.30, (0.62, 0.06, 0.10)), (0.04, (0.05, 0.04, 0.05)), (0.16, (0.30, 0.10, 0.36)), (0.03, (0.85, 0.70, 0.15)),
         (0.20, (0.62, 0.06, 0.10)), (0.12, (0.07, 0.25, 0.14)), (0.03, (0.05, 0.04, 0.05)), (0.12, (0.62, 0.06, 0.10))]
    return plaid(X, Y, B), 0.75, -0.0002*fbm(X/TILE*8, Y/TILE*8, period=8)
@pattern("plaid_pink", "metric")
def _plaid_pink(X, Y):      # ผ้าขาวม้าคาดเอว: pink / white / purple
    B = [(0.35, (0.86, 0.52, 0.58)), (0.10, (0.95, 0.92, 0.90)), (0.20, (0.55, 0.30, 0.55)), (0.05, (0.95, 0.92, 0.90)), (0.30, (0.86, 0.52, 0.58))]
    return plaid(X, Y, B, 0.064), 0.75, 0.0
@pattern("red_cloth", "metric")
def _red_cloth(X, Y):
    return np.ones(X.shape + (3,))*np.array((0.70, 0.08, 0.10))*(0.92 + 0.08*weave(X, Y))[..., None], 0.7, 0.0
@pattern("sin_purple", "norm")
def _sin_purple(X, Y):      # ผ้าซิ่นม่วง: fine horizontal stripes, a darker band at the hem
    c = np.ones(X.shape + (3,))*np.array((0.36, 0.17, 0.42))
    c = mix(c, (0.25, 0.10, 0.30), (np.sin(Y*2*math.pi*90) > 0.6)*0.8)
    c = mix(c, (0.20, 0.07, 0.24), Y < 0.16)
    c = mix(c, (0.60, 0.38, 0.62), (np.abs(Y - 0.16) < 0.006))
    return c*(0.92 + 0.08*weave(X, Y*0.75))[..., None], 0.7, -0.00025*vfolds(X)
@pattern("sin_ikat", "norm")
def _sin_ikat(X, Y):        # มัดหมี่: purple / indigo diamonds blurred sideways, dark hem
    c = np.ones(X.shape + (3,))*np.array((0.30, 0.18, 0.42))
    P = TILE/6; u = (X % P)/P - 0.5; v = ((Y*0.75/P) % 1) - 0.5
    j = 0.04*np.sin(Y*700)                                                    # ikat bleed
    d = np.abs(u + j) + np.abs(v)
    c = mix(c, (0.12, 0.10, 0.28), sstep(0.30, 0.26, d)*(1 - sstep(0.12, 0.08, d)))
    c = mix(c, (0.75, 0.60, 0.80), sstep(0.07, 0.04, d))
    c = mix(c, (0.15, 0.08, 0.20), Y < 0.10)
    return c, 0.72, -0.00025*vfolds(X)
@pattern("sin_tinjok", "norm")
def _sin_tinjok(X, Y):      # ซิ่นตีนจก: deep purple body with small motifs, red hem band with zigzags and diamonds
    c = np.ones(X.shape + (3,))*np.array((0.28, 0.12, 0.30))
    P = TILE/8; u = (X % P)/P - 0.5; v = ((Y*0.75/P) % 1) - 0.5
    c = mix(c, (0.62, 0.42, 0.20), sstep(0.16, 0.12, np.abs(u) + np.abs(v))*(Y > 0.2))
    hem = (Y < 0.2)
    c = mix(c, (0.62, 0.08, 0.10), hem)
    zz = np.abs(((X/(TILE/16)) % 1) - 0.5)*0.08
    c = mix(c, (0.85, 0.66, 0.22), hem*(np.abs(Y - 0.15 - zz) < 0.008))
    c = mix(c, (0.85, 0.66, 0.22), hem*(np.abs(Y - 0.05 + zz) < 0.008))
    c = mix(c, (0.10, 0.25, 0.20), hem*sstep(0.22, 0.17, np.abs(u) + np.abs((Y - 0.10)/0.08*0.5))*(Y > 0.07)*(Y < 0.13))
    return c, 0.7, -0.00025*vfolds(X)
@pattern("sabai_red", "norm")
def _sabai_red(X, Y):       # สไบ: red, gold diamond lattice, gold borders
    c = np.ones(X.shape + (3,))*np.array((0.58, 0.07, 0.10))
    P = TILE/10; u = (X % P)/P - 0.5; v = Y*4 % 1 - 0.5
    c = mix(c, (0.80, 0.58, 0.20), (np.abs(np.abs(u) + np.abs(v) - 0.32) < 0.06)*(Y > 0.12)*(Y < 0.88))
    c = mix(c, (0.80, 0.58, 0.20), (Y < 0.08) | (Y > 0.92))
    c = mix(c, (0.35, 0.05, 0.08), (np.abs(Y - 0.10) < 0.01) | (np.abs(Y - 0.90) < 0.01))
    return c, 0.6, 0.0
@pattern("scarf_stripe", "norm")
def _scarf_stripe(X, Y):    # ผ้าพาดบ่า: lengthwise stripes, orange / pink / green / red
    B = [(0.14, (0.85, 0.40, 0.12)), (0.08, (0.85, 0.30, 0.45)), (0.10, (0.20, 0.45, 0.25)), (0.12, (0.75, 0.10, 0.14)),
         (0.06, (0.90, 0.75, 0.30)), (0.14, (0.85, 0.40, 0.12)), (0.10, (0.20, 0.45, 0.25)), (0.12, (0.85, 0.30, 0.45)), (0.14, (0.75, 0.10, 0.14))]
    return stripes(Y, 1.0, B)*(0.9 + 0.1*weave(X, Y*0.1))[..., None], 0.75, 0.0
@pattern("straw", "metric")
def _straw(X, Y):           # งอบ: woven bamboo / palm
    a = np.sin(X*2*math.pi/0.0128); b = np.sin(Y*2*math.pi/0.0128)
    over = ((np.floor(X/0.0064) + np.floor(Y/0.0064)) % 2) > 0
    h = np.where(over, a, b)*0.5 + 0.5
    c = np.ones(X.shape + (3,))*np.array((0.78, 0.64, 0.38))*(0.8 + 0.25*h)[..., None]
    return c, 0.8, 0.0005*h
@pattern("vans_checker", "norm")
def _vans_checker(X, Y):    # red / white checkerboard slip-on, white sole with a red line
    chk = ((np.floor(X/(TILE/24)) + np.floor(Y*8)) % 2) > 0
    c = np.where(chk[..., None], np.array((0.72, 0.08, 0.10)), np.array((0.93, 0.93, 0.91)))
    c = mix(c, (0.94, 0.93, 0.90), Y < 0.22); c = mix(c, (0.72, 0.08, 0.10), np.abs(Y - 0.16) < 0.012)
    return c, 0.6, 0.0004*(Y < 0.22)*(np.sin(X*900) > 0)
@pattern("skate_black", "norm")
def _skate_black(X, Y):     # black skate shoe, white wave stripe, white sole
    c = np.ones(X.shape + (3,))*np.array((0.06, 0.06, 0.07))
    c = mix(c, (0.92, 0.92, 0.90), np.abs(Y - 0.48 - 0.08*np.sin(X*2*math.pi/(TILE/4))) < 0.035)
    c = mix(c, (0.93, 0.92, 0.89), Y < 0.22)
    return c, 0.55, 0.0004*(Y < 0.22)*(np.sin(X*900) > 0)
def _sandal(strap, sole=(0.93, 0.92, 0.88)):
    """flip-flops (UV v: 0-0.5 top of the sole, 0.5-0.6 its edge, 0.6-1 the strap)"""
    def fn(X, Y):
        c = np.ones(X.shape + (3,))*np.array(sole)
        c = mix(c, np.array(sole)*0.82, (Y < 0.5)*(np.sin(X*700)*np.sin(Y*400) > 0.6))     # worn foot print texture
        c = mix(c, strap, (Y >= 0.52)*(Y < 0.56))                                             # coloured line round the sole edge
        c = mix(c, strap, Y >= 0.6)
        return c, 0.8, 0.0003*(Y < 0.5)*(np.sin(X*700) > 0)
    return fn
pattern("sandal_blue", "norm")(_sandal((0.10, 0.30, 0.70)))     # รองเท้าแตะช้างดาว: white sole, blue strap
pattern("sandal_red", "norm")(_sandal((0.72, 0.12, 0.10)))
pattern("sandal_black", "norm")(_sandal((0.08, 0.08, 0.09), sole=(0.16, 0.15, 0.15)))
pattern("sandal_pink", "norm")(_sandal((0.90, 0.62, 0.66), sole=(0.92, 0.70, 0.72)))   # pink slides (all one colour)
pattern("sandal_brown", "norm")(_sandal((0.36, 0.22, 0.12), sole=(0.30, 0.20, 0.13)))

@pattern("helmet_white", "norm")
def _helmet_white(X, Y):    # glossy white, twin black stripes over the crown, red side flash, black rubber trim, vents
    A = X/TILE*360 - 180; E = H_EL[0] + Y*(H_EL[-1] - H_EL[0]); aa = np.abs(A)
    c = np.ones(X.shape + (3,))*np.array((0.93, 0.93, 0.91))
    back = 180 - aa
    stripe = ((np.abs(aa - 7) < 3.5) | (np.abs(back - 7) < 3.5)) & (E > np.where(aa < 64, 19, -60))
    c = mix(c, (0.05, 0.05, 0.06), stripe)
    flash = (aa > 70) & (aa < 150) & (E > -40 + (aa - 70)*0.25) & (E < -18 + (aa - 70)*0.25)
    c = mix(c, (0.75, 0.08, 0.10), flash)
    c = mix(c, (0.25, 0.25, 0.27), np.hypot(aa - 68, E - 2) < 5.5)                       # visor pivot
    c = mix(c, (0.10, 0.10, 0.11), np.hypot(aa - 68, E - 2) < 2.5)
    vent = (aa < 14) & (E > -46) & (E < -36) & (np.sin(A*0.9) > 0.2)                      # chin vents
    vent |= (aa < 10) & (E > 44) & (E < 56) & (np.abs(aa - 5) < 2.5)                       # crown vents
    c = mix(c, (0.08, 0.08, 0.09), vent)
    bot = -70 + 26*sstep(25, 80, aa) - 14*sstep(110, 170, aa)
    c = mix(c, (0.04, 0.04, 0.05), E < bot + 5)                                            # rubber trim
    rough = 0.22
    return c, rough, -0.0004*vent
@pattern("visor_black", "norm")
def _visor_black(X, Y):     # smoked visor, a little lighter at the top edge
    c = np.ones(X.shape + (3,))*np.array((0.03, 0.03, 0.04))
    c = mix(c, (0.20, 0.22, 0.26), sstep(0.62, 0.70, Y)*0.6)
    return c, 0.05, 0.0
@pattern("gold", "metric", metal=True)
def _gold(X, Y):            # gold belt / chains / bangles: hammered with a square motif
    P = TILE/16; u = (X % P)/P - 0.5; v = (Y % P)/P - 0.5
    m = np.maximum(np.abs(u), np.abs(v))
    c = np.ones(X.shape + (3,))*np.array((0.86, 0.64, 0.22))
    c = mix(c, (0.60, 0.40, 0.10), (np.abs(m - 0.42) < 0.05))
    return c, 0.3, 0.0003*sstep(0.45, 0.30, m)

# --- ghost cloth: the pattern washed out, then dirt, water marks, old blood and frayed edges on top.
# Noise is periodic across the tile (u), so the cloth still tiles; `span` patterns don't tile (u = 0..1 along the
# whole strip, see build_strip) and may place things along it (blood from the neck at the shoulder end).
BLOOD = (0.30, 0.025, 0.03); BLOOD_OLD = (0.20, 0.06, 0.04); DIRT = (0.30, 0.24, 0.16)
def ghost_cloth(c, X, Y, seed, kind, dirt=1.0, blood=0.4, rough=0.8, pale=1.0, fray=1.0):
    """kind "skirt": Y 0 = hem (dirt, fraying and mud rise from it); "band": Y 0..1 across a strip (both edges fray)"""
    u = X/TILE; Q = 6
    n = lambda k, s_, o=3: fbm(u*k, Y*k*(1.0 if kind == "skirt" else 0.35), oct=o, seed=s_, period=k)
    g = c.mean(-1, keepdims=True)
    c = (c*(1 - 0.38*pale) + g*0.38*pale)*(1 - 0.20*pale) + 0.035*pale      # pale and dull
    c = c*(0.88 + 0.14*n(Q, seed))[..., None]                             # uneven fading
    edge = Y if kind == "skirt" else np.minimum(Y, 1 - Y)
    low = sstep(0.45, 0.0, Y) if kind == "skirt" else sstep(0.4, 0.0, edge)*0.5
    d = n(Q, seed + 1)
    c = mix(c, DIRT, dirt*(0.30*sstep(0.56, 0.80, d) + 0.6*low*sstep(0.30, 0.65, d)))
    c = mix(c, np.array(DIRT)*0.45, dirt*low**2*0.7)                      # mud caked at the hem
    tide = np.abs(n(Q//2, seed + 2, 2) - 0.5) < 0.012                      # dried water marks
    c = mix(c, c*0.72, tide*0.6)
    bl = n(4, seed + 3)
    spot = sstep(0.70, 0.74, bl)*blood
    c = mix(c, BLOOD_OLD, spot*0.85); c = mix(c, np.array(BLOOD_OLD)*0.6, spot*sstep(0.80, 0.74, bl)*0.6)   # darker rims
    fr = edge < (0.035 + 0.04*n(24, seed + 4, 2))*fray                    # frayed, torn edge
    threads = (np.sin(X*2*math.pi/0.003) > 0.3) & (edge < 0.06)
    c = mix(c, np.array(DIRT)*0.35, fr*0.9); c = mix(c, c*0.6, threads*0.4)
    r = np.full(X.shape, rough) + 0.1*low - 0.35*spot
    h = -0.0003*fr - 0.0001*tide
    return c, np.clip(r, 0.2, 1.0), h

def neck_blood(c, r, X, Y):
    """span strips (sabai) of the headless ghost: blood soaked in at the shoulder ends, fading out in blotches"""
    u = X/TILE
    k = np.exp(-u/0.22) + np.exp(-(1 - u)/0.10)                            # both ends of the loop sit on the shoulder
    blot = fbm(u*14, Y*3, oct=3, seed=61); run = fbm(Y*10, u*3, oct=2, seed=63)
    wet = np.clip(k*(0.65 + 0.9*(blot - 0.5) + 0.5*(run - 0.5)) - 0.30, 0, 1)
    c = mix(c, BLOOD_OLD, sstep(0.02, 0.15, wet)*0.88); c = mix(c, BLOOD, sstep(0.25, 0.55, wet)*0.7)
    return c, r - 0.4*sstep(0.25, 0.55, wet)

def _ghost_sin(base, hem, line, seed, dirt=1.0, blood=0.4, stripe=None):
    def fn(X, Y):
        c = np.ones(X.shape + (3,))*np.array(base)
        if stripe: c = mix(c, stripe, (np.sin(Y*2*math.pi*70) > 0.55)*0.7)
        c = mix(c, hem, Y < 0.15)                                            # hem band (ตีนซิ่น)
        P = TILE/10; zz = np.abs(((X/P) % 1) - 0.5)*0.06
        c = mix(c, line, (np.abs(Y - 0.13 + zz) < 0.006) | (np.abs(Y - 0.03 - zz) < 0.006) | (np.abs(Y - 0.16) < 0.004))
        c = mix(c, line, (Y > 0.965) & (Y < 0.985))                          # thin line at the waist
        c = c*(0.92 + 0.08*weave(X, Y*0.75))[..., None]
        c, r, h = ghost_cloth(c, X, Y, seed, "skirt", dirt, blood, 0.75)
        return c, r, h - 0.00025*vfolds(X)
    return fn
def _ghost_sabai(base, border, line, seed, blood=0.4, neck=False, lattice=True):
    def fn(X, Y):
        c = np.ones(X.shape + (3,))*np.array(base)
        P = TILE/10; u = (X % P)/P - 0.5; v = Y*4 % 1 - 0.5
        if lattice: c = mix(c, line, (np.abs(np.abs(u) + np.abs(v) - 0.32) < 0.05)*(Y > 0.14)*(Y < 0.86)*0.5)
        c = mix(c, border, (Y < 0.10) | (Y > 0.90))
        c = mix(c, line, (np.abs(Y - 0.12) < 0.008) | (np.abs(Y - 0.88) < 0.008))
        c, r, h = ghost_cloth(c, X, Y, seed, "band", 0.8, blood, 0.65)
        if neck: c, r = neck_blood(c, r, X, Y)
        return c, r, h
    return fn
GOLD_DULL = (0.62, 0.48, 0.20)
pattern("ghost_sin_red", "norm")(_ghost_sin((0.50, 0.07, 0.08), GOLD_DULL, (0.80, 0.62, 0.26), 70, stripe=(0.40, 0.05, 0.06)))   # ซิ่นแดงขอบทอง
pattern("ghost_sabai_cream", "norm")(_ghost_sabai((0.84, 0.78, 0.62), GOLD_DULL, (0.70, 0.55, 0.25), 71))       # สไบครีมขอบทอง
pattern("ghost_sabai_cream_blood", "norm")(_ghost_sabai((0.84, 0.78, 0.62), GOLD_DULL, (0.70, 0.55, 0.25), 72, blood=0.6, neck=True))
pattern("ghost_sin_green", "norm")(_ghost_sin((0.11, 0.30, 0.17), (0.06, 0.18, 0.10), (0.45, 0.55, 0.25), 73, stripe=(0.08, 0.24, 0.13)))  # นางตานี
pattern("ghost_sabai_green", "norm")(_ghost_sabai((0.20, 0.42, 0.24), (0.08, 0.22, 0.12), (0.50, 0.58, 0.28), 74))
pattern("ghost_sin_white", "norm")(_ghost_sin((0.86, 0.86, 0.82), (0.80, 0.80, 0.76), (0.70, 0.70, 0.66), 75, dirt=1.0, blood=0.25))  # ชุดขาว
pattern("ghost_sabai_white", "norm")(_ghost_sabai((0.88, 0.88, 0.84), (0.82, 0.82, 0.78), (0.74, 0.74, 0.70), 76, blood=0.25, lattice=False))

def brocade(u, v, gold, base):
    """ผ้ายก motif on (u, v) in cell units: a diamond with a four-petal flower, a dot between, gold on the base"""
    cu = u % 1.0 - 0.5; cvv = v % 1.0 - 0.5
    d = np.abs(cu) + np.abs(cvv)
    petal = (np.hypot(np.abs(cu) - 0.13, cvv) < 0.08) | (np.hypot(cu, np.abs(cvv) - 0.13) < 0.08)
    m = (np.abs(d - 0.40) < 0.045) | (d < 0.06) | petal
    m |= np.hypot(np.abs(cu) - 0.5, np.abs(cvv) - 0.5) < 0.07                          # dot on the corners
    c = np.ones(u.shape + (3,))*np.array(base)
    return mix(c, gold, m*0.9), m

GOLD_OLD = (0.58, 0.45, 0.22)
@pattern("ghost_dancer_gold", "metric", metal=True)
def _ghost_dancer_gold(X, Y):     # tarnished gold of the crown, collar, belt and bangles: engraved scrolls, red glass, dust in the grooves
    u = X/TILE; P = TILE/12
    c = np.ones(X.shape + (3,))*np.array(GOLD_OLD)
    orn, scroll = brocade(X/(P*0.5), Y/(P*0.5), (0.80, 0.66, 0.34), (0.40, 0.30, 0.15))      # small flower-and-diamond ornament
    c = mix(c, orn, 0.85)
    gx = (X % P)/P - 0.5; gy = (Y % P)/P - 0.5; gem = np.hypot(gx, gy) < 0.08
    c = mix(c, (0.40, 0.05, 0.06), gem)
    lost = gem*(fbm(np.floor(X/P)*0.7, np.floor(Y/P)*0.7, oct=1, seed=95) > 0.66)        # glass fallen out
    c = mix(c, (0.10, 0.08, 0.05), lost)
    tar = fbm(u*6, Y/TILE*6, oct=3, seed=96, period=6)
    c = mix(c, (0.22, 0.19, 0.13), sstep(0.60, 0.78, tar)*0.6)                          # dull, dusty patches
    c = (c*0.8 + c.mean(-1, keepdims=True)*0.2)*0.95                                    # muted, not shiny
    r = 0.50 + 0.25*sstep(0.6, 0.78, tar) + 0.2*gem
    return c, r, -0.0003*scroll + 0.0004*gem*~lost - 0.0004*lost

@pattern("ghost_brocade_sin", "norm")
def _ghost_brocade_sin(X, Y):     # ผ้านุ่งยก (span: u 0..1 round the waist, 0 = front): maroon brocade, gold hem, pleated front panel
    u = X/TILE
    c, m = brocade(u*30, Y*28, GOLD_OLD, (0.62, 0.13, 0.32))            # pink-red (ผ้ายกสีชมพูบานเย็น)
    c = mix(c, GOLD_OLD, (Y < 0.07)*0.75); c = mix(c, (0.20, 0.05, 0.05), (np.abs(Y - 0.075) < 0.006))
    c = mix(c, GOLD_OLD, (Y > 0.965)*0.7)
    fd = np.minimum(u, 1 - u)                                                       # distance round from the front
    panel = fd < 0.055
    pleat = np.sin(fd/0.0105*2*math.pi)                                             # ชายพก: folded pleats down the front
    pc, _ = brocade(u*60, Y*40, GOLD_OLD, (0.70, 0.20, 0.38))
    c = np.where(panel[..., None], pc*(0.82 + 0.18*pleat)[..., None], c)
    c = mix(c, GOLD_OLD, np.abs(fd - 0.055) < 0.004)
    c = c*(0.92 + 0.08*weave(X, Y*0.75))[..., None]
    c, r, h = ghost_cloth(c, X, Y, 79, "skirt", 0.45, 0.08, 0.7, pale=0.45)
    return c, r, h + 0.0005*pleat*panel - 0.0002*m
@pattern("ghost_sabai_red", "norm")
def _ghost_sabai_red(X, Y):       # สไบนางรำ: red with a narrow gold border, dusty
    c = np.ones(X.shape + (3,))*np.array((0.55, 0.06, 0.09))           # red like the sleeves
    c = mix(c, GOLD_OLD, (Y < 0.06) | (Y > 0.94)); c = mix(c, (0.40, 0.08, 0.09), (np.abs(Y - 0.5) < 0.30)*(np.sin(X*2*math.pi/0.01) > 0.7)*0.4)
    c = c*(0.92 + 0.08*weave(X, Y*0.75))[..., None]
    c, r, h = ghost_cloth(c, X, Y, 80, "band", 0.35, 0.05, 0.6, pale=0.45, fray=0.25)
    fold = np.sin(Y*2*math.pi*3.0 + 0.6*np.sin(X/TILE*2*math.pi*2))              # soft folds along the sash
    c = c*(0.86 + 0.14*fold)[..., None]
    return c, r, h + 0.0012*fold
@pattern("ghost_flower", "norm")
def _ghost_flower(X, Y):          # ดอกไม้ทัดหู / อุบะ: wilted red petals, dark centres, a little green
    u = X/TILE
    c = np.ones(X.shape + (3,))*np.array((0.45, 0.05, 0.07))
    c = c*(0.7 + 0.5*fbm(u*12, Y*6, oct=3, seed=110, period=12))[..., None]
    c = mix(c, (0.15, 0.03, 0.03), Y < 0.18); c = mix(c, (0.22, 0.30, 0.14), Y > 0.88)
    return c, 0.7, 0.0

def vfolds(X):
    """soft vertical drape folds (periodic over the tile)"""
    return fbm(X/TILE*6, np.zeros_like(X), oct=2, seed=4, period=6) - 0.5

def make_patterns(size=512):
    os.makedirs(TEX, exist_ok=True)
    x = (np.arange(size) + 0.5)/size
    X, Yn = np.meshgrid(x*TILE, x)
    for name, (fn, mode, metal) in PATTERNS.items():
        Y = Yn*TILE if mode == "metric" else Yn
        col, rough, hgt = fn(X, Y)
        hgt = np.broadcast_to(hgt, X.shape)
        ppm = size/TILE
        nrm = normal_from_height(hgt, ppm, ppm if mode == "metric" else size/0.8, wrap=True)
        base = os.path.join(TEX, name)
        save_png(col, base + "_Color.png", False); save_png(nrm, base + "_Normal.png", True)
        save_png(np.full(X.shape, rough), base + "_Roughness.png", True)
        if metal: save_png(np.full(X.shape, 1.0), base + "_Metalness.png", True)

# ---------------------------------------------------------------- choosing the shell faces (normal body, stored in json)
def pick_faces(b, char):
    """{outfit: {piece: [face indices]}} - each face goes to the first shell piece that wants it"""
    me = b.ob.data; attrs = [b.face_attr(p) for p in me.polygons]
    out = {}
    for name in CHAR_OUTFITS[char]:
        taken = set(); out[name] = {}
        for spec in OUTFITS[name]:
            if spec[0] != "shell": continue
            _, piece, test, off, fab = spec
            fs = [i for i, a in enumerate(attrs) if i not in taken and a[0] != "head" and test(*a)]
            taken.update(fs); out[name][piece] = fs
    return out

# ---------------------------------------------------------------- skin hidden under each outfit
# Skin and cloth are skinned to the same bones but a cloth shell is pushed out along the normals, so when a joint
# bends they don't move the same way and the skin pokes through unless the cloth stands well off (which made the
# men look like american-football players). Instead the skin a shirt / trousers cover is cut out of the body in
# Roblox for that outfit (build_anims.export_model splits the Body by these sets), and the cloth can sit thin.
# HIDE_KEEP rings of faces along every opening of the cloth stay, so a look into a sleeve / collar still meets skin.
HIDE_KEEP = 1

def hidden_faces(me, outfit_faces, keep=HIDE_KEEP):
    """{outfit: sorted body faces under its shell pieces, minus `keep` rings along the openings}"""
    vf = [[] for _ in me.vertices]
    for p in me.polygons:
        for v in p.vertices: vf[v].append(p.index)
    out = {}
    for name, pieces in outfit_faces.items():
        fs = set(f for lst in pieces.values() for f in lst)
        for _ in range(keep):
            cnt = {}
            for fi in fs:
                vs = list(me.polygons[fi].vertices)
                for k in range(len(vs)):
                    e = (min(vs[k], vs[(k + 1) % len(vs)]), max(vs[k], vs[(k + 1) % len(vs)])); cnt[e] = cnt.get(e, 0) + 1
            edge_v = {v for e, c in cnt.items() if c == 1 for v in e}
            fs -= {f for v in edge_v for f in vf[v]}
        out[name] = sorted(fs)
    return out

# ---------------------------------------------------------------- shell texture (per character, body UV space)
def raster_body(b, uv):
    """texel -> world position, normal, face index over the whole UV square"""
    me = b.ob.data; me.calc_loop_triangles()
    P = np.zeros((N, N, 3)); Nn = np.zeros((N, N, 3)); F = np.full((N, N), -1, np.int32)
    for t in me.loop_triangles:
        q = np.array([uv[l] for l in t.loops])*N - 0.5
        x0, y0 = np.maximum(np.floor(q.min(0)).astype(int), 0); x1, y1 = np.minimum(np.ceil(q.max(0)).astype(int), N - 1)
        if x1 < x0 or y1 < y0: continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = q
        den = (by - cy)*(ax - cx) + (cx - bx)*(ay - cy)
        if abs(den) < 1e-12: continue
        l0 = ((by - cy)*(X - cx) + (cx - bx)*(Y - cy))/den; l1 = ((cy - ay)*(X - cx) + (ax - cx)*(Y - cy))/den; l2 = 1 - l0 - l1
        ins = (l0 >= -0.03) & (l1 >= -0.03) & (l2 >= -0.03)
        if not ins.any(): continue
        V = list(t.vertices); lam = np.stack([l0, l1, l2], -1)[ins]
        P[Y[ins], X[ins]] = lam @ b.co[V]; Nn[Y[ins], X[ins]] = lam @ b.nrm[V]; F[Y[ins], X[ins]] = t.polygon_index
    return P, Nn, F

def dilate(a, mask, n=8):
    a = a.copy(); m = mask.copy()
    for _ in range(n):
        acc = np.zeros_like(a); cnt = np.zeros(m.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(np.roll(m, dy, 0), dx, 1); sa = np.roll(np.roll(a, dy, 0), dx, 1)
            new = sm & ~m; acc[new] += sa[new]; cnt[new] += 1
        new = (cnt > 0) & ~m
        a[new] = acc[new]/(cnt[new][..., None] if a.ndim == 3 else cnt[new]); m |= new
    return a, m

def paint_shell(b, ras, faces, char, outfit):
    """Color / Normal / Roughness for one outfit's shell pieces"""
    P, Nn, F = ras; s = b.s
    col = np.zeros((N, N, 3)); hgt = np.zeros((N, N)); rgh = np.full((N, N), 0.8); mask = np.zeros((N, N), bool)
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    piece_of = np.full(len(b.ob.data.polygons) + 1, -1)
    specs = [sp for sp in OUTFITS[outfit] if sp[0] == "shell"]
    for k, sp in enumerate(specs): piece_of[faces[sp[1]]] = k
    pk = piece_of[F]
    front = Nn[..., 1] < -0.35
    zc = b.z(2.0); zn = b.J["neck"][0][2]
    freg = np.array([b.face_attr(p_)[0] for p_ in b.ob.data.polygons] + ["-"])[F]     # body part under each texel
    trunk = freg == "torso"
    for k, sp in enumerate(specs):
        fab = FABRIC[CHAR_FABRIC.get((char, sp[4]), sp[4])]; m = pk == k
        if not m.any(): continue
        mask |= m
        c = np.ones((N, N, 3))*np.array(fab["c"])
        c *= (0.93 + 0.07*fbm(x*30, y*30, z*30, seed=k))[..., None]
        h = 0.00005*fab["weave"]*np.sin(x*3900)*np.sin(z*3900) + 0.00004*fab["weave"]*np.sin((y + z)*4100)
        if fab.get("folds"):
            h += 0.0006*fab["folds"]*(fbm(x*25, y*25, z*4, seed=20 + k) - 0.5)
            c *= (1 - 0.10*fab["folds"]*(fbm(x*25, y*25, z*4, seed=20 + k) - 0.5))[..., None]
        if fab.get("fade"):
            c = mix(c, np.array(fab["c"])*1.35, 0.35*fbm(x*12, y*12, z*12, seed=7)*front)
        if fab.get("seams"):
            for sd in (1, -1):
                hx = b.J["thigh.L" if sd > 0 else "thigh.R"][0][0]
                seam = (Nn[..., 0]*sd > 0.6) & (np.abs(Nn[..., 1]) < 0.035) & (x*sd > 0)
                c = mix(c, (0.75, 0.55, 0.25), seam*0.6); h -= 0.0002*seam
        if fab.get("flannel") or fab.get("plaid"):      # check: black / white / grey flannel, or the listed bands
            B = fab.get("plaid") or [(0.42, (0.06, 0.06, 0.07)), (0.08, (0.85, 0.85, 0.83)), (0.20, (0.40, 0.40, 0.42)), (0.08, (0.85, 0.85, 0.83)), (0.22, (0.06, 0.06, 0.07))]
            c = 0.5*(stripes(x + 0.6*y, 0.07, B) + stripes(z, 0.07, B))*(0.93 + 0.07*fbm(x*30, y*30, z*30, seed=k))[..., None]
        if fab.get("dots"):         # small all-over dots (pyjama-style pants)
            d = np.hypot(((x + y)*90) % 1.0 - 0.5, (z*90) % 1.0 - 0.5)
            c = mix(c, fab["dots"], sstep(0.22, 0.16, d))
        if fab.get("band"):         # band-tee print: a framed picture with a title above, faded
            g = front & trunk
            box = g & (np.abs(x) < 0.07*s) & (z > zc - 0.10*s) & (z < zc + 0.03*s)
            pic = fbm(x*40, z*40, seed=50)
            c = mix(c, np.stack([0.75*pic, 0.45*pic, 0.35*pic + 0.1], -1), box*0.85)
            title = g & (np.abs(x) < 0.08*s) & (np.abs(z - zc - 0.05*s) < 0.012*s) & (np.sin(x*900) > -0.2)
            c = mix(c, (0.88, 0.86, 0.80), title)
        if fab.get("camo"):
            for cc, sd, th in (((0.38, 0.29, 0.18), 31, 0.52), ((0.15, 0.21, 0.12), 32, 0.55), ((0.62, 0.56, 0.40), 33, 0.60), ((0.07, 0.07, 0.06), 34, 0.62)):
                c = mix(c, cc, sstep(th, th + 0.02, fbm(x*9, y*9, z*5, seed=sd)))
        if fab.get("pockets"):      # cargo pockets on the outside of the thighs
            for sd in ("L", "R"):
                J, T = b.J["thigh." + sd]; zm = J[2] + (T[2] - J[2])*0.55; sx = 1 if sd == "L" else -1
                pk_ = (Nn[..., 0]*sx > 0.6) & (np.abs(z - zm) < 0.06*s) & (np.abs(y) < 0.05*s) & (freg == "leg." + sd)
                ed = pk_ & ((np.abs(z - zm) > 0.054*s) | (np.abs(y) > 0.045*s) | (np.abs(z - zm - 0.035*s) < 0.003*s))
                c = mix(c, c*0.7, ed); h += 0.0006*pk_ - 0.0004*ed
        if fab.get("rips"):         # torn knees: white threads over the skin
            for sd in ("L", "R"):
                J = b.J["shin." + sd][0]
                knee = (Nn[..., 1] < -0.3) & (((x - J[0])/(0.045*s))**2 + ((z - J[2] - 0.01*s)/(0.035*s))**2 < 1) & np.isin(freg, ["leg." + sd])
                hole = knee & (fbm(x*90, z*45, seed=40) > 0.48)
                c = mix(c, (0.80, 0.62, 0.50), hole*0.85)
                c = mix(c, (0.88, 0.88, 0.86), hole*(np.sin(z*2600) > 0.2)*0.9)
                c = mix(c, (0.75, 0.78, 0.85), knee*~hole*0.5); h -= 0.0004*hole
        tee = fab.get("tee"); opn = fab.get("open")
        if tee or opn:              # open shirt: something else shows down the front
            w_o = 0.055*s
            inside = front & trunk & (np.abs(x) < w_o) & (z < zn - 0.01)
            ic = np.array(tee[0]) if tee else np.array(opn)
            c = mix(c, ic, inside)
            edge = front & trunk & (np.abs(np.abs(x) - w_o) < 0.004*s) & (z < zn)
            c = mix(c, np.array(fab["c"])*0.6 + 0.05, edge); h += 0.0005*edge
            for i in range(6):
                d = np.hypot(x - w_o - 0.008*s, z - (zn - 0.05*s - i*0.07*s))
                c = mix(c, (0.85, 0.85, 0.85), front*sstep(0.005*s, 0.0035*s, d))
            if tee and tee[1] == "red":       # print on the tee
                g = np.hypot(x, z - zc - 0.01*s)
                c = mix(c, (0.75, 0.10, 0.12), inside*sstep(0.032*s, 0.028*s, g))
                c = mix(c, (0.08, 0.08, 0.08), inside*(np.abs(z - zc + 0.04*s) < 0.006*s))
        if fab.get("graphic"):
            g = front & trunk
            ring_ = np.abs(np.hypot(x, z - zc - 0.02*s) - 0.045*s) < 0.006*s
            c = mix(c, (0.85, 0.70, 0.10), g*ring_)
            c = mix(c, (0.85, 0.70, 0.10), g*(np.abs(z - zc - 0.02*s) < 0.008*s)*(np.abs(x) < 0.03*s))
            c = mix(c, (0.90, 0.90, 0.88), g*(np.abs(z - zc + 0.05*s) < 0.005*s)*(np.abs(x) < 0.06*s))
        if fab.get("jacket"):       # chest pocket flaps, yoke seam in light thread
            for sx in (1, -1):
                fl = front & (np.abs(x - sx*0.07*s) < 0.032*s) & (np.abs(z - zc - 0.05*s) < 0.014*s)
                c = mix(c, c*0.75, fl & (np.abs(z - zc - 0.05*s) > 0.010*s)); h += 0.0005*fl
            yk = trunk & (np.abs(z - zc - 0.085*s) < 0.0025*s)
            c = mix(c, (0.70, 0.55, 0.30), yk*0.8)
        if fab.get("belt"):
            zt = b.z(1.06)
            bl = trunk & (z > zt - 0.038*s) & (z < zt - 0.006*s)
            c = mix(c, (0.04, 0.03, 0.03), bl); h += 0.0006*bl
            bk = bl & front & (np.abs(x) < 0.028*s)
            c = mix(c, (0.75, 0.75, 0.72), bk)
        if fab.get("collar"):
            nj = b.J["neck"][0]
            cl = (z > zn - 0.03*s) & (np.hypot(x - nj[0], y - nj[1]) < 0.085*s) & trunk
            c = mix(c, np.array(fab["c"])*0.82, cl*0.6); h += 0.0004*cl
        btn = fab.get("buttons")
        if btn:
            yy = z
            plk = front & (np.abs(x) < 0.006*s) & (yy < zn - 0.01)
            c = mix(c, np.array(fab["c"])*0.75, plk*np.exp(-((np.abs(x) - 0.006*s)/(0.0012*s))**2))
            step = 0.075*s if btn == "mohom" else 0.06*s
            for i in range(8):
                bz = zn - 0.035*s - i*step
                if bz < b.z(1.05): break
                d = np.hypot(x, yy - bz)
                col_b = (0.85, 0.82, 0.75) if btn == "blouse" else (0.72, 0.64, 0.42) if btn == "metal" else (0.10, 0.10, 0.12)
                c = mix(c, col_b, front*sstep(0.0055*s, 0.004*s, d)); h += 0.00035*front*sstep(0.0055*s, 0.003*s, d)
            # round neck band
            nb = (np.abs(z - (zn - 0.004)) < 0.010*s)
            c = mix(c, np.array(fab["c"])*0.8, nb*0.5); h += 0.0003*nb
        if fab.get("pocket"):
            pkt = front & (x > 0.035*s) & (x < 0.105*s) & (z > zc - 0.02*s) & (z < zc + 0.06*s)
            edge = pkt & ((x < 0.039*s) | (x > 0.101*s) | (z < zc - 0.016*s) | (z > zc + 0.056*s))
            c = mix(c, np.array(fab["c"])*0.8, edge); h += 0.00035*pkt - 0.0003*edge
        if fab.get("vneck"):
            vz = zn - 0.012 - 0.09*s*np.maximum(0, 1 - np.abs(x)/(0.07*s))
            vb = front & (z > vz - 0.004*s) & (z < vz + 0.022*s) & (np.abs(x) < 0.08*s)
            c = mix(c, fab["vneck"], vb)
        if fab.get("logo"):
            lg = front & (np.abs(x - 0.07*s) < 0.012*s) & (np.abs(z - zc - 0.02*s) < 0.003*s)
            c = mix(c, (0.95, 0.95, 0.95), lg)
        if fab.get("brocade"):      # ผ้ายก: the gold motif laid out in world space (x on front / back, y on the sides)
            P_ = 0.026*s; uu = np.where(np.abs(Nn[..., 1]) >= np.abs(Nn[..., 0]), x, y + 0.37*s)
            c, bm_ = brocade(uu/P_, z/P_, GOLD_OLD, np.array(fab["c"]))
            if fab.get("yoke"):     # red yoke round the shoulders and down the sleeves, dotted with gold
                zy = b.z(2.62) - 0.03*s*np.cos(np.arctan2(x, -y)*2)
                yk = (freg != "torso") | (z > zy)
                cy_ = np.ones((N, N, 3))*np.array(fab["yoke"])
                dots = np.hypot((uu/(0.6*P_)) % 1 - 0.5, (z/(0.6*P_)) % 1 - 0.5) < 0.16
                cy_ = mix(cy_, GOLD_OLD, dots*0.85)
                c = np.where(yk[..., None], cy_, c)
                c = mix(c, GOLD_OLD, (freg == "torso")*(np.abs(z - zy) < 0.005*s)); bm_ = bm_ | (yk & dots)
            h = h - 0.0002*bm_
        r = np.full((N, N), fab.get("rough", 0.8))
        if fab.get("ghost"):
            c, h, r = ghost_shell(b, ras, freg, m, c, h, r, fab["ghost"], k)
        col[m] = c[m]; hgt[m] = h[m]; rgh[m] = r[m]
    # one texture per piece (shell_tex_base), the rest of the image filled with that piece's own colours: Roblox
    # shrinks / mipmaps textures, and with shirt and trousers in one image the red shirt bled onto black trousers
    # where their UV islands sit side by side
    for k, sp in enumerate(specs):
        mk = pk == k
        if not mk.any(): continue
        c_, full = dilate(col, mk); h_, _ = dilate(hgt, mk); r_, _ = dilate(rgh, mk)
        c_ = fill_all(c_, full); h_ = fill_all(h_, full); r_ = fill_all(r_, full)
        # texel density: from the body's own UV (roughly 1 px ~ 1 mm on the trunk at 1024)
        nrm = normal_from_height(h_, 1100.0, 1100.0)
        base = shell_tex_base(char, outfit, k, sp[1])
        save_png(c_, base + "_Color.png", False); save_png(nrm, base + "_Normal.png", True); save_png(r_, base + "_Roughness.png", True)

def ghost_shell(b, ras, freg, m, c, h, r, g, k):
    """ghost look of a shell piece (texels m), in world space: washed out, dirt rising from the ground, water marks,
    old blood, torn holes, frayed dark hems / cuffs / top edge; g["neck"]: blood run down from a cut neck over
    the top of the piece, front and back"""
    P, Nn, F = ras; s = b.s; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    gr = c.mean(-1, keepdims=True); pale = g.get("pale", 0.3)
    c = (c*(1 - pale) + gr*pale)*0.84 + 0.03
    c = c*(0.88 + 0.14*fbm(x*7, y*7, z*7, seed=80 + k))[..., None]
    low = sstep(b.foot_z + 0.75*s, b.foot_z + 0.05*s, z)                    # dirt splashed up from the ground
    d = fbm(x*14, y*14, z*14, seed=81 + k)
    dirt = g.get("dirt", 1.0)*(0.28*sstep(0.56, 0.80, d) + 0.6*low*sstep(0.35, 0.65, d))
    c = mix(c, DIRT, dirt); r = r + 0.1*dirt
    tide = np.abs(fbm(x*5, y*5, z*5, oct=2, seed=82 + k) - 0.5) < 0.010
    c = mix(c, c*0.72, tide*0.6)
    bl = fbm(x*7, y*7, z*7, seed=83 + k)
    spot = sstep(0.70, 0.74, bl)*g.get("blood", 0.4)
    c = mix(c, BLOOD_OLD, spot*0.85); c = mix(c, np.array(BLOOD_OLD)*0.6, spot*sstep(0.80, 0.74, bl)*0.6); r = r - 0.35*spot
    # how close each texel is to the piece's open edges: top / bottom of it on the trunk, end of sleeve / trouser leg
    edge = np.full((N, N), 9.0)
    tr = m & (freg == "torso")
    if tr.any():
        zt = z[tr]; legs = (m & np.char.startswith(freg.astype(str), "leg")).any()     # trousers: the bottom of the trunk part is the crotch, not a hem
        edge = np.minimum(edge, np.where(tr, np.minimum(9.0 if legs else z - zt.min(), zt.max() - z)/s, 9.0))
    for sd in "LR":
        for reg, chain in ((f"arm.{sd}", ("upper_arm", "forearm", "hand")), (f"leg.{sd}", ("thigh", "shin", "foot"))):
            lm = m & (freg == reg)
            if not lm.any(): continue
            J = [b.J[f"{n_}.{sd}"][0] for n_ in chain] + [b.J[f"{chain[2]}.{sd}"][1]]
            t = np.zeros((N, N)); t[lm] = Body.chain_param(P[lm], J)
            seg = np.linalg.norm(J[1] - J[0])/s                                  # ~0.27 m per unit of the limb parameter
            edge = np.minimum(edge, np.where(lm, (t[lm].max() - t)*seg, 9.0))
    fr = (edge < 0.010 + 0.016*fbm(x*90, y*90, z*90, oct=2, seed=84 + k))*(g.get("fray", 1.0) > 0)
    c = mix(c, np.array(DIRT)*0.5, sstep(0.05, 0.0, edge)*0.5)              # grime along the hems
    c = mix(c, np.array(DIRT)*0.3, fr*0.85); h = h - 0.0004*fr
    # torn holes: a few patches, ragged outline, dark inside, light threads at the rim
    patch = sstep(0.64, 0.70, fbm(x*5, y*5, z*5, oct=2, seed=85 + k))*g.get("holes", 0.6)
    hn = fbm(x*60, y*60, z*40, oct=3, seed=86 + k)
    hole = (hn > 0.76 - 0.06*patch)*(patch > 0.3)
    rim = (hn > 0.71 - 0.06*patch)*(patch > 0.3)*~hole
    c = mix(c, (0.05, 0.04, 0.04), hole); c = mix(c, (0.70, 0.66, 0.56), rim*0.55); h = h - 0.0005*hole
    if g.get("gold_edges"):     # gold trim along the neckline, the cuffs and the hem (worn: dusty, broken in places)
        tr_ = (edge < 0.016)*(fbm(x*40, y*40, z*40, oct=2, seed=92) < 0.75)
        c = mix(c, np.array(GOLD_OLD)*0.9, tr_*0.9); h = h + 0.0003*tr_
    if g.get("neck"):           # blood run down from the neck: soaked in under the top edge, a few runs below, a drop at each end
        top = m & (freg == "torso"); zt = z[top].max() if top.any() else b.J["neck"][0][2]
        near = sstep(0.13*s, 0.06*s, np.abs(x))
        cols = fbm(x/s*30 + 0.6*fbm(z/s*9, x/s*2, oct=2, seed=91), np.zeros_like(x), oct=2, seed=87)    # runs wander a little
        L = (0.03 + 0.10*fbm(x/s*11, np.zeros_like(x), oct=2, seed=88))*s
        run = zt - z
        stream = sstep(0.60, 0.65, cols)*sstep(L, L - 0.03*s, run)*near           # thinning out towards the end
        drop = sstep(0.62, 0.66, cols)*(np.abs(run - L) < 0.008*s)*near
        soak = (run < (0.006 + 0.03*fbm(x*25, y*25, oct=3, seed=89))*s)*sstep(0.11*s, 0.04*s, np.abs(x))
        wet = np.clip(stream + drop + soak, 0, 1)*m
        tone = fbm(x*40, y*40, z*40, oct=2, seed=90)
        c = mix(c, BLOOD_OLD, wet*0.9); c = mix(c, BLOOD, wet*sstep(0.4, 0.7, tone)*0.7)
        r = r - 0.4*wet; h = h + 0.0002*wet
    return c, h, np.clip(r, 0.2, 1.0)

def shell_tex_base(char, outfit, k, piece):
    """texture files of shell piece k of an outfit: the first keeps the outfit's name, the others add the piece"""
    return os.path.join(char_dir(char), f"{NAMES[char]}_{outfit}" + ("" if k == 0 else "_" + piece))

def fill_all(a, m):
    """every texel outside m gets the average of the nearest texels inside (pull-push over a 2x pyramid)"""
    if m.all() or not m.any(): return a
    h, w = m.shape
    if h < 2 or w < 2:
        return np.where(m[..., None] if a.ndim == 3 else m, a, a[m].mean(0))
    mw = m.astype(np.float64)[:h//2*2, :w//2*2].reshape(h//2, 2, w//2, 2)
    ac = a[:h//2*2, :w//2*2]
    if a.ndim == 3:
        ac = ac.reshape(h//2, 2, w//2, 2, a.shape[2]); num = (ac*mw[..., None]).sum((1, 3)); den = mw.sum((1, 3))
        a2 = np.where(den[..., None] > 0, num/np.maximum(den, 1e-9)[..., None], 0.0)
    else:
        ac = ac.reshape(h//2, 2, w//2, 2); num = (ac*mw).sum((1, 3)); den = mw.sum((1, 3))
        a2 = np.where(den > 0, num/np.maximum(den, 1e-9), 0.0)
    a2 = fill_all(a2, den > 0)
    up = np.repeat(np.repeat(a2, 2, 0), 2, 1)
    if up.shape[0] < h: up = np.concatenate([up, up[-1:]], 0)
    if up.shape[1] < w: up = np.concatenate([up, up[:, -1:]], 1)
    return np.where(m[..., None] if a.ndim == 3 else m, a, up)

# ---------------------------------------------------------------- geometry builders
class Mesh:
    def __init__(self):
        self.v, self.f, self.uv, self.w = [], [], [], []      # verts, faces (index lists), per-face-corner uvs, per-vertex {group: w}
        self.src = []                                         # body vertex each one came from (-1: none)
    def vert(self, p, w, src=-1):
        self.v.append(Vector(p)); self.w.append(w); self.src.append(src); return len(self.v) - 1
    def face(self, idx, uvs):
        self.f.append(list(idx)); self.uv.append([tuple(u) for u in uvs])

    def to_object(self, name, rig, mat, fix_normals=True):
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(p) for p in self.v], [], self.f)
        lay = me.uv_layers.new(name="UVMap")
        flat = [u for fu in self.uv for u in fu]
        lay.data.foreach_set("uv", np.array(flat, np.float32).ravel())
        me.validate();
        for p in me.polygons: p.use_smooth = True
        ob = bpy.data.objects.new(name, me)
        coll = bpy.data.collections.get("Clothes") or bpy.data.collections.new("Clothes")
        if coll.name not in bpy.context.scene.collection.children: bpy.context.scene.collection.children.link(coll)
        coll.objects.link(ob)
        groups = {}
        for i, w in enumerate(self.w):
            for g, x in w.items():
                if x <= 1e-4: continue
                vg = groups.get(g) or ob.vertex_groups.new(name=g); groups[g] = vg
                vg.add([i], float(x), 'REPLACE')
        ob.parent = rig
        mo = ob.modifiers.new("Armature", 'ARMATURE'); mo.object = rig
        me.materials.append(mat)
        if fix_normals:   # closed pieces only; shells keep the body's winding (outward)
            bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
        return ob

def vweights(b, i, limit=4):
    row = b.w[i]; idx = np.argsort(row)[::-1][:limit]
    tot = row[idx].sum() or 1.0
    return {b.names[j]: float(row[j]/tot) for j in idx if row[j] > 0}

def build_shell(b, spec, faces):
    """body faces pushed out by the piece's offset, with a turned-in hem on every open edge"""
    _, piece, test, off, fab = spec
    me = b.ob.data; uvl = me.uv_layers.active.data; s = b.s
    msh = Mesh(); vmap = {}
    # rings from the open edge: the skin under the rest is hidden in Roblox, so only these need room for it
    cnt = {}
    for fi in faces:
        vs = list(me.polygons[fi].vertices)
        for k in range(len(vs)):
            e = (min(vs[k], vs[(k + 1) % len(vs)]), max(vs[k], vs[(k + 1) % len(vs)])); cnt[e] = cnt.get(e, 0) + 1
    mine = {v for fi in faces for v in me.polygons[fi].vertices}
    ring = {v: 0 for e, c in cnt.items() if c == 1 for v in e}; front = list(ring)
    while front:
        nxt = []
        for v in front:
            for w_ in b.nbr[v]:
                if w_ in mine and w_ not in ring: ring[w_] = ring[v] + 1; nxt.append(w_)
        front = nxt
    def out_v(vi):
        if vi not in vmap:
            room = 0.0 if getattr(off, "no_room", False) else ROOM*(1 - sst(EDGE_RINGS - 1, EDGE_RINGS, ring.get(vi, 99)))
            o = off(b.reg[vi], b.tz[vi], b.ap[vi], b.lp[vi], room=room)*s
            nx, _, nz = b.nrm[vi]                           # shells only reach the arm as sleeves
            inward = -(nx if b.co[vi][0] > 0 else -nx) - nz
            keep = sst(ARMPIT_IN[0], ARMPIT_IN[1], inward) if ARMPIT_MODE == "inward" else 1 - sst(ARMPIT_UP[0], ARMPIT_UP[1], nz)
            arm_in = ARMPIT_TOP + (1 - ARMPIT_TOP)*keep
            if b.reg[vi].startswith("arm"):
                o += room*SLEEVE_ROOT*s*(1 - sst(0.0, 0.6, b.ap[vi]))*arm_in
            if b.reg[vi] == "torso":
                # skin on the side of the chest is partly skinned to the arm; when the arm goes up it bulges out
                # past a shell at the usual distance, so the cloth stands off further where the arm pulls the skin
                # (all round: cutting it on the top of the shoulder lets the skin through when running)
                o += room*ARMPIT_SIDE*s*min(1.0, b.armw[vi]*ARMPIT_RAMP)
            elif b.reg[vi].startswith("arm") and (b.ring[vi] >= 0 or b.ap[vi] < 0.15):
                o += room*ARMPIT*s*arm_in                            # the armpit itself (trunk-ring vertices held by the arm)
            if b.reg[vi] == "torso" and b.tz[vi] < 0:
                o += room*CROTCH*s                                   # crotch: room for the thighs lifting
            vmap[vi] = msh.vert(Vector(b.co[vi]) + Vector(b.nrm[vi])*o, vweights(b, vi), vi)
        return vmap[vi]
    edges = {}
    for fi in faces:
        p = me.polygons[fi]; vs = list(p.vertices); li = list(p.loop_indices)
        msh.face([out_v(v) for v in vs], [uvl[l].uv for l in li])
        for k in range(len(vs)):
            a, c = vs[k], vs[(k + 1) % len(vs)]
            key = (min(a, c), max(a, c))
            edges.setdefault(key, []).append((a, c, uvl[li[k]].uv.copy(), uvl[li[(k + 1) % len(vs)]].uv.copy()))
    inner = {}
    for key, lst in edges.items():
        if len(lst) != 1: continue
        a, c, ua, uc = lst[0]
        for vi in (a, c):
            if vi not in inner: inner[vi] = msh.vert(Vector(b.co[vi]) + Vector(b.nrm[vi])*0.0015*s, vweights(b, vi))
        msh.face([vmap[c], vmap[a], inner[a], inner[c]], [uc, ua, ua, uc])
    return msh

def surface_samples(verts, faces, n=4):
    """points spread over every face (a barycentric grid), so a tube measured on them can't cut between vertices"""
    V = np.asarray(verts, dtype=np.float64); out = []
    g = [(i/n, j/n) for i in range(n + 1) for j in range(n + 1 - i)]
    W = np.array([(1 - a - c, a, c) for a, c in g])
    for f in faces:
        for k in range(1, len(f) - 1):
            out.append(W @ V[[f[0], f[k], f[k + 1]]])
    return np.concatenate(out) if out else np.zeros((0, 3))

def build_tube(b, spec, under=None):
    """skirt: per height ring, the convex outline of the trunk + legs, hanging straight; optional rolled waist"""
    _, name, top_tz, bot, pat, kw = spec
    s = b.s; clear = kw.get("clear", 0.01)*s
    z0 = b.z(top_tz)
    if bot[0] == "tz": z1 = b.z(bot[1]); z0, z1 = max(z0, z1), min(z0, z1)
    elif bot[0] == "lp":
        th = b.J["thigh.L"]; sh = b.J["shin.L"]; ft = b.J["foot.L"]
        pts = [th[0], sh[0], ft[0], ft[0]]; t = bot[1]; i = min(int(t), 2)
        z1 = float(pts[i][2] + (pts[i + 1][2] - pts[i][2])*(t - i))
    else: z1 = b.foot_z + bot[1]
    z1 = max(z1, b.foot_z + 0.015)
    band = kw.get("band", False)
    if band: zs = np.linspace(z0, z1, 4)
    else:      # close rows at the waist (stays snug), wider further down
        zs = list(np.arange(z0, max(z0 - 0.10*s, z1), -0.02*s)); zt = zs[-1] - 0.02*s
        zs += list(np.linspace(zt, z1, max(2, int((zt - z1)/(0.05*s)) + 1))) if zt > z1 + 0.01*s else [z1]
        zs = np.array(zs)
    rows = len(zs)
    seg = 40
    cy = float(b.J["hips"][0][1])
    th = np.linspace(0, 2*math.pi, seg + 1)
    dirs = np.stack([np.sin(th), -np.cos(th)], 1)            # th = 0 is the front (-Y)
    # what the tube has to clear: the skin of trunk and legs, then any shirt / trousers on them (points over every face)
    me = b.ob.data; keep = {"torso", "leg.L", "leg.R", "foot.L", "foot.R"}
    if not hasattr(b, "_skin_pts"):
        fs = [list(p.vertices) for p in me.polygons if b.face_attr(p)[0] in keep]
        b._skin_pts = surface_samples(b.co, fs)
    pts = [(b._skin_pts, clear)]
    if under is not None and len(under[0]): pts.append((surface_samples(*under), clear*0.6))
    R = np.zeros((rows, seg + 1)); prev = None
    for i, zz in enumerate(zs):
        # each ring covers everything up to its neighbour rings, so the straight panel between two rings can't cut in
        hi = zs[i - 1] if i else zz + 0.004*s; lo = zs[i + 1] if i + 1 < rows else zz - 0.004*s
        r = np.zeros(seg + 1)
        for P, cl in pts:
            m = (P[:, 2] <= hi) & (P[:, 2] >= lo)
            if m.any(): r = np.maximum(r, ((P[m, :2] - np.array([0, cy])) @ dirs.T).max(0) + cl)
        if prev is not None and not band:
            r = np.maximum(r, prev*(0.985 if bot[0] != "tz" else 1.0))     # hangs: never tucks back in under the hips
        # smooth round the ring
        rr = np.concatenate([r[-4:-1], r, r[1:4]])
        r = np.maximum(r, np.convolve(rr, np.ones(5)/5, 'same')[3:-3]); r[-1] = r[0]    # smoothing never cuts into the body
        R[i] = r; prev = r
    if kw.get("seated"):   # sitting: the seat and the backs of the thighs swell out behind
        dn_ = (z0 - zs)/max(z0 - z1, 1e-6)
        R += 0.070*s*sstep(0.05, 0.40, dn_)[:, None]*np.maximum(0.0, -np.cos(th))[None, :]**0.7
        R += 0.025*s*sstep(0.05, 0.40, dn_)[:, None]                           # and round the lap
    if not band:   # a little extra room low at the back, where the back leg's calf and heel swing in a stride
        dn_ = (z0 - zs)/max(z0 - z1, 1e-6)
        R += 0.016*s*(dn_**2)[:, None]*np.maximum(0.0, -np.cos(th))[None, :]
        R += 0.018*s*(dn_**4)[:, None]                          # and a slight flare at the hem all round
    msh = Mesh(); ids = np.zeros((rows, seg + 1), int); idi = np.zeros((rows, seg + 1), int)
    mode = PATTERNS[pat][1]
    arc = np.zeros((rows, seg + 1))
    for i in range(rows):
        p = np.stack([np.sin(th)*R[i], -np.cos(th)*R[i]], 1)
        arc[i, 1:] = np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))
    hips_w = {"hips": 1.0}
    lift = np.zeros(seg + 1)
    if kw.get("ragged") and rows > 2:      # torn hem: the last row in uneven teeth, mostly torn up, a few rags hanging lower
        rs = np.random.RandomState(len(name)*7 + 3); room_up = (zs[-2] - zs[-1])*0.8
        t_ = rs.rand(seg)**1.5*np.where(np.arange(seg) % 2, 1.0, 0.35)
        lift[:seg] = np.minimum(kw["ragged"]*s*t_, room_up)
        hang = rs.rand(seg) < 0.12
        lift[:seg][hang] = -np.minimum(0.4*kw["ragged"]*s, zs[-1] - b.foot_z - 0.012)
        lift[seg] = lift[0]
    for i, zz in enumerate(zs):
        dn = (z0 - zz)/max(z0 - z1, 1e-6)
        for j in range(seg + 1):
            zj = zz + (lift[j] if i == rows - 1 else 0.0)
            p = Vector((math.sin(th[j])*R[i, j], cy - math.cos(th[j])*R[i, j], zj))
            _, vi, _ = b.kd.find(p); w = vweights(b, vi)
            if band: ww = w
            else:
                # a skirt follows the legs lower down: outside each leg it is that thigh (and shin near the hem),
                # across the front and back it blends evenly from one leg to the other, so the cloth stretches
                # between the legs as one smooth panel instead of the knees pushing through it
                k = 0.90*sst(0.0, 0.35, dn) + 0.10*sst(0.6, 1.0, dn); lx = abs(float(b.J["thigh.L"][0][0]))
                wl = 0.5 + 0.5*max(-1.0, min(1.0, p.x/lx))
                ks = 0.85*sst(0.40, 1.0, dn)                        # share of that leg given to the shin
                skirt = {"hips": 1 - k, "thigh.L": k*wl*(1 - ks), "thigh.R": k*(1 - wl)*(1 - ks),
                         "shin.L": k*wl*ks, "shin.R": k*(1 - wl)*ks}
                if kw.get("seated"):    # sitting: the front of the skirt goes with the thighs right from the waist (the lap)
                    fr = max(0.0, math.cos(th[j])); ks = 0.95*sst(0.0, 0.18 + 0.17*(1 - fr), dn)   # the back too: it goes under the thighs
                    if ks > k:
                        skirt = {"hips": 1 - ks, "thigh.L": ks*wl, "thigh.R": ks*(1 - wl)}
                e = sst(0.0, 0.25, dn)                              # waist: like the skin under it
                ww = {g: w.get(g, 0)*(1 - e) + skirt.get(g, 0)*e for g in set(w) | set(skirt)}
            ids[i, j] = msh.vert(p, ww)
            pin = Vector((math.sin(th[j])*(R[i, j] - 0.004*s), cy - math.cos(th[j])*(R[i, j] - 0.004*s), zj))
            idi[i, j] = msh.vert(pin, ww)
    def uvof(i, j):
        u = arc[i, j]/arc[i, -1] if kw.get("span") else arc[i, j]/TILE   # span: 0..1 round (front at 0), the pattern doesn't tile
        v = (z0 - zs[i])/TILE if mode == "metric" else (zs[i] - z1)/max(z0 - z1, 1e-6)
        return (u, -v if mode == "metric" else v)
    for i in range(rows - 1):
        for j in range(seg):
            msh.face([ids[i, j], ids[i + 1, j], ids[i + 1, j + 1], ids[i, j + 1]], [uvof(i, j), uvof(i + 1, j), uvof(i + 1, j + 1), uvof(i, j + 1)])
            msh.face([idi[i, j + 1], idi[i + 1, j + 1], idi[i + 1, j], idi[i, j]], [uvof(i, j + 1), uvof(i + 1, j + 1), uvof(i + 1, j), uvof(i, j)])
    for i in (0, rows - 1):                                         # hems: outer to inner
        for j in range(seg):
            a, c = (ids[i, j], ids[i, j + 1]); ai, ci = (idi[i, j], idi[i, j + 1])
            fl = [a, c, ci, ai] if i == 0 else [c, a, ai, ci]
            msh.face(fl, [uvof(i, j), uvof(i, j + 1), uvof(i, j + 1), uvof(i, j)])
    if kw.get("roll"):                                              # rolled waist of a sarong: a fat ring at the top
        rr = 0.012*s; rid = []
        for j in range(seg + 1):
            ring = []
            for k in range(6):
                a = 2*math.pi*k/6; rad = R[0, j] + rr*(1 + math.cos(a))*0.8
                ring.append(msh.vert((math.sin(th[j])*rad, cy - math.cos(th[j])*rad, z0 - 0.012*s + rr*math.sin(a)), msh.w[ids[0, j]]))
            rid.append(ring)
        for j in range(seg):
            for k in range(6):
                k2 = (k + 1) % 6
                msh.face([rid[j][k], rid[j + 1][k], rid[j + 1][k2], rid[j][k2]], [uvof(0, j), uvof(0, j + 1), (uvof(0, j + 1)[0], k2/6*0.1), (uvof(0, j)[0], k2/6*0.1)])
    return msh

def resample(pts, step):
    pts = [Vector(p) for p in pts if p is not None]
    out = [pts[0]]
    for a, c in zip(pts, pts[1:]):
        L = (c - a).length; n = max(1, int(L/step))
        for k in range(1, n + 1): out.append(a.lerp(c, k/n))
    # smooth
    for _ in range(3):
        out = [out[0]] + [(out[i - 1] + out[i]*2 + out[i + 1])/4 for i in range(1, len(out) - 1)] + [out[-1]]
    return out

def outermost(tree, o, d, reach):
    """the last surface a ray from o along d crosses within reach (the outside of the top layer)"""
    far, t0 = None, 0.0
    for _ in range(8):
        h = tree.ray_cast(o + d*(t0 + 1e-4), d, reach - t0)
        if h[0] is None: break
        t0 = (h[0] - o).dot(d); far = h[0]
    return far

def build_strip(b, spec, under=None):
    _, name, path_fn, width, pat, kw = spec
    s = b.s; w = width*s; clear = kw.get("clear", 0.01)*s; thick = kw.get("thick", 0.003)*s
    msh = Mesh()
    ubvh = BVHTree.FromPolygons(*under) if kw.get("over") and under is not None and len(under[1]) else None
    def push(p, c):
        p, n = b.push(p, c)
        if ubvh is not None:          # over=True: lie over every piece built before it (shirt, skirt, sabai ...)
            far = outermost(ubvh, p - n*0.05, n, 0.15)
            if far is not None and (p - far).dot(n) < c: p = far + n*c
            loc, nrm, _, _ = ubvh.find_nearest(p)
            if loc is not None:
                side = (p - loc).dot(nrm)
                if side < c: p = p + nrm*(c - side)
        return p, n
    for path in path_fn(b):
        pts = resample(path, 0.015*s)
        if len(pts) < 2: continue
        L, ring = 0.0, []
        prev_a = None
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
            p, n = push(p, clear + thick)
            a = t.cross(n).normalized()
            if prev_a is not None and a.dot(prev_a) < 0: a = -a
            prev_a = a
            if i: L += (pts[i] - pts[i - 1]).length
            row = []
            for f in np.linspace(-0.5, 0.5, kw.get("cols", 2)):     # cols > 2: vertices across a wide band, so it lies over steps
                e, en = push(p + a*w*f, clear + thick)
                _, vi, _ = b.kd.find(e); wt = vweights(b, vi)
                if kw.get("tail_hang") and e.z < b.z(1.2):     # the long tail hangs free from the hips, clear of the legs
                    kh = sst(b.z(1.2), b.z(0.5), e.z)
                    wt = {g_: x_*(1 - kh) for g_, x_ in wt.items() if not g_.startswith(("thigh", "shin", "foot"))}
                    wt["hips"] = wt.get("hips", 0.0) + kh
                    tot_ = sum(wt.values()); wt = {g_: x_/tot_ for g_, x_ in wt.items()}
                row.append((msh.vert(e, wt), msh.vert(e - en*thick, wt)))
            ring.append((row, L))
        span = TILE/max(L, 1e-6) if kw.get("span") else 1.0      # span: u 0..1 over the whole strip (pattern doesn't tile)
        ring = [(row, LL*span) for row, LL in ring]
        for i in range(len(ring) - 1):
            (r0, L0), (r1, L1) = ring[i], ring[i + 1]
            u0, u1 = L0/TILE, L1/TILE
            nc = len(r0)
            for k in range(nc - 1):
                va, vb = k/(nc - 1), (k + 1)/(nc - 1)
                (a0o, a0i), (b0o, b0i) = r0[k], r0[k + 1]; (a1o, a1i), (b1o, b1i) = r1[k], r1[k + 1]
                msh.face([a0o, b0o, b1o, a1o], [(u0, va), (u0, vb), (u1, vb), (u1, va)])
                msh.face([a1i, b1i, b0i, a0i], [(u1, va), (u1, vb), (u0, vb), (u0, va)])
            (a0o, a0i), (a1o, a1i) = r0[0], r1[0]; (b0o, b0i), (b1o, b1i) = r0[-1], r1[-1]
            msh.face([a0i, a0o, a1o, a1i], [(u0, 0), (u0, 0.02), (u1, 0.02), (u1, 0)])
            msh.face([b1i, b1o, b0o, b0i], [(u1, 1), (u1, 0.98), (u0, 0.98), (u0, 1)])
        for (row, LL), flip in ((ring[0], False), (ring[-1], True)):
            u = LL/TILE
            for k in range(len(row) - 1):
                (ao, ai), (bo, bi) = row[k], row[k + 1]
                q = [ao, ai, bi, bo]; msh.face(q[::-1] if flip else q, [(u, 0)]*4)
    return msh

def build_ring(b, spec):
    """bangles / anklets: a ring round the wrist or ankle joint, both sides"""
    _, name, joint, t, pat, kw = spec
    s = b.s; msh = Mesh()
    for sd in "LR":
        h, tl = b.J[f"{joint}.{sd}"]; ax = Vector(tl - h).normalized(); c = Vector(h) + Vector(tl - h)*t
        if joint == "foot": c = Vector(h) + Vector((0, 0, 0.012*s)); ax = Vector((0, 0, 1))
        u = ax.orthogonal().normalized(); v = ax.cross(u)
        # radius: skin distance round the joint + a little
        rad = 0.0
        for k in range(12):
            a = 2*math.pi*k/12; d = u*math.cos(a) + v*math.sin(a)
            hit = b.bvh.ray_cast(c + d*0.2, -d, 0.2)[0]
            if hit: rad = max(rad, (hit - c).length)
        rad += (0.004 + kw.get("room", 0.0))*s; tr = kw.get("tr", 0.0035)*s
        _, vi, _ = b.kd.find(c); wt = vweights(b, vi)
        idx = [[msh.vert(c + (u*math.cos(a) + v*math.sin(a))*(rad + tr*math.cos(bb)) + ax*tr*math.sin(bb), wt)
                for bb in np.linspace(0, 2*math.pi, 7)[:-1]] for a in np.linspace(0, 2*math.pi, 17)[:-1]]
        for i in range(16):
            for k in range(6):
                i2, k2 = (i + 1) % 16, (k + 1) % 6
                msh.face([idx[i][k], idx[i2][k], idx[i2][k2], idx[i][k2]], [(i/16, k/6), ((i + 1)/16, k/6), ((i + 1)/16, (k + 1)/6), (i/16, (k + 1)/6)])
    return msh

def build_hat(b, spec):
    """งอบ: a wide shallow cone on a head band, bound to the head"""
    s = b.s; msh = Mesh()
    hb = b.rig.data.bones["head"]; rw = b.rig.matrix_world
    U = (rw @ hb.tail_local - rw @ hb.head_local).normalized()
    hv = b.co[b.reg == "head"]
    top = Vector(hv[np.argmax(hv @ np.array(U))]); C = Vector(hv.mean(0))
    base = top - U*0.045*s                                # sits on the hair, crown inside the cone
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); L = U.cross(F)
    prof = [(0.0, 0.11), (0.06, 0.085), (0.14, 0.04), (0.24, 0.0), (0.26, -0.006)]   # (radius, height) x s: apex to brim
    seg = 32; W = {"head": 1.0}
    rows_o, rows_i = [], []
    for r_, h_ in prof:
        ro, ri = [], []
        for j in range(seg + 1):
            a = 2*math.pi*j/seg; d = F*math.cos(a) + L*math.sin(a)
            p = base + d*r_*s + U*h_*s
            ro.append(msh.vert(p, W)); ri.append(msh.vert(p - U*0.004*s, W))
        rows_o.append(ro); rows_i.append(ri)
    def uvp(i, j): r_ = prof[i][0]*s; a = 2*math.pi*j/seg; return (r_*math.cos(a)/TILE, r_*math.sin(a)/TILE)
    for i in range(len(prof) - 1):
        for j in range(seg):
            msh.face([rows_o[i][j], rows_o[i + 1][j], rows_o[i + 1][j + 1], rows_o[i][j + 1]], [uvp(i, j), uvp(i + 1, j), uvp(i + 1, j + 1), uvp(i, j + 1)])
            msh.face([rows_i[i][j + 1], rows_i[i + 1][j + 1], rows_i[i + 1][j], rows_i[i][j]], [uvp(i, j + 1), uvp(i + 1, j + 1), uvp(i + 1, j), uvp(i, j)])
    k = len(prof) - 1
    for j in range(seg):
        msh.face([rows_o[k][j], rows_i[k][j], rows_i[k][j + 1], rows_o[k][j + 1]], [uvp(k, j)]*2 + [uvp(k, j + 1)]*2)
    return msh

def build_shoe(b, spec):
    """sneakers: convex hull of each foot (+ ankle), pushed out a little, flat sole; UV round the foot x height"""
    s = b.s; msh = Mesh()
    for sd in "LR":
        idx = np.where((b.reg == "foot." + sd) | ((b.reg == "leg." + sd) & (b.lp >= 1.88)))[0]
        bm = bmesh.new()
        for i in idx: bm.verts.new(Vector(b.co[i]))
        res = bmesh.ops.convex_hull(bm, input=bm.verts)
        bmesh.ops.delete(bm, geom=list({g for g in res["geom_interior"] + res["geom_unused"] if isinstance(g, bmesh.types.BMVert)}), context="VERTS")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.normal_update()
        z0 = min(v.co.z for v in bm.verts); z1 = max(v.co.z for v in bm.verts)
        cen = sum((v.co for v in bm.verts), Vector())/len(bm.verts)
        ids = {}
        for v in bm.verts:
            p_ = v.co + v.normal*0.008*s
            if p_.z < z0 + 0.004: p_.z = z0 - 0.004*s                 # flat sole, a touch under the foot
            _, vi, _ = b.kd.find(v.co); ids[v.index] = msh.vert(p_, vweights(b, vi))
        rad = sum(((v.co - cen).xy.length for v in bm.verts), 0.0)/len(bm.verts)
        for f in bm.faces:
            ang = [math.atan2(v.co.y - cen.y, v.co.x - cen.x) for v in f.verts]
            a0 = ang[0]; ang = [a0 + math.atan2(math.sin(a - a0), math.cos(a - a0)) for a in ang]
            msh.face([ids[v.index] for v in f.verts], [(a*rad/TILE, (v.co.z - z0)/(z1 - z0)) for a, v in zip(ang, f.verts)])
        bm.free()
    return msh

def _hull2d(P):
    P = sorted(set(map(tuple, P)))
    def half(pts):
        h = []
        for p in pts:
            while len(h) >= 2 and (h[-1][0] - h[-2][0])*(p[1] - h[-2][1]) - (h[-1][1] - h[-2][1])*(p[0] - h[-2][0]) <= 0: h.pop()
            h.append(p)
        return h
    lo, hi = half(P), half(P[::-1])
    return lo[:-1] + hi[:-1]           # counter-clockwise

def build_sandal(b, spec):
    """flip-flops: a flat sole under each foot (outline of the sole, about 1 cm thick) and a V-shaped thong strap
    from between the big and second toe to both sides of the foot"""
    s = b.s; msh = Mesh(); th = 0.011*s; rim = 0.007*s
    for sd in "LR":
        sx = 1 if sd == "L" else -1
        idx = np.where(b.reg == "foot." + sd)[0]; P = b.co[idx]; z0 = float(P[:, 2].min())
        low = P[P[:, 2] < z0 + 0.025*s]
        hull = _hull2d(np.round(low[:, :2], 5))
        c2 = np.mean(hull, 0)
        ring = []
        for x, y in hull:
            d = np.array((x, y)) - c2; d = d/(np.linalg.norm(d) or 1)
            ring.append((x + d[0]*rim, y + d[1]*rim))
        def wt(x, y):
            _, vi, _ = b.kd.find((x, y, z0 + 0.01*s)); return vweights(b, vi)
        top = [msh.vert((x, y, z0 - 0.001*s), wt(x, y)) for x, y in ring]
        bot = [msh.vert((x, y, z0 - th), wt(x, y)) for x, y in ring]
        n = len(ring); per = sum(math.dist(ring[i], ring[(i + 1) % n]) for i in range(n))
        ymin, ymax = min(y for _, y in ring), max(y for _, y in ring)
        uv_top = [(x - c2[0], 0.02 + 0.46*(y - ymin)/(ymax - ymin)) for x, y in ring]
        msh.face(top, uv_top); msh.face(bot[::-1], uv_top[::-1])
        L = 0.0
        for i in range(n):
            j = (i + 1) % n; L2 = L + math.dist(ring[i], ring[j])
            msh.face([top[j], top[i], bot[i], bot[j]], [(L2, 0.58), (L, 0.58), (L, 0.50), (L2, 0.50)]); L = L2
        # thong strap: post between the big and second toe, two straps over the foot to its sides
        xs = P[:, 0]; inner = xs.min() if sx > 0 else xs.max(); outer = xs.max() if sx > 0 else xs.min()
        ytoe = float(P[:, 1].min()); yheel = float(P[:, 1].max()); flen = yheel - ytoe
        gap = Vector((inner + (outer - inner)*0.30, ytoe + 0.22*flen, z0 + 0.004*s))
        post = b.surf((gap.x, gap.y, z0 + 0.3*s), (0, 0, -1), False)[0]
        ymid = ytoe + 0.48*flen
        paths = []
        slide = len(spec) > 3 and spec[3].get("slide")
        if slide:           # slides: one wide band over the instep instead of the thong
            yb = ytoe + 0.36*flen
            pts = [Vector((inner - rim*0.6*sx, yb, z0 + 0.004*s))]
            for f in (0.15, 0.5, 0.85):
                xx = inner + (outer - inner)*f; pts.append(b.surf((xx, yb, z0 + 0.3*s), (0, 0, -1), False)[0])
            pts.append(Vector((outer + rim*0.6*sx, yb, z0 + 0.004*s)))
            paths.append(pts)
        for xe in (() if slide else (inner, outer)):
            pts = [post]
            for t in (0.3, 0.6):
                q = gap.lerp(Vector((xe, ymid, z0)), t)
                pts.append(b.surf((q.x, q.y, z0 + 0.3*s), (0, 0, -1), False)[0])
            pts.append(Vector((xe + (rim*0.6 if xe == outer else -rim*0.6)*sx, ymid, z0 + 0.004*s)))
            paths.append(pts)
        st = build_strip(b, ("strip", "strap", lambda b_: paths, 0.05 if slide else 0.016, "", dict(clear=0.003, thick=0.005)))
        off = len(msh.v)
        msh.v += st.v; msh.w += st.w; msh.src += st.src
        msh.f += [[i + off for i in f] for f in st.f]
        msh.uv += [[(u, 0.62 + 0.36*min(max(v, 0.0), 1.0)) for u, v in fu] for fu in st.uv]
    return msh

# full-face helmet layout (degrees): azimuth a (0 = face, +90 = left), elevation e round the head centre
H_EL = [-72, -64, -56, -48, -40, -32, -24, -16, -8, 0, 8, 16, 24, 32, 42, 52, 62, 72, 81, 89]
def h_bottom(a):     # lower edge: chin bar low in front, up under the jaw, down again over the nape
    a = abs(a); return -70 + 26*sst(25, 80, a) - 14*sst(110, 170, a)
def h_visor_top(a): return 18                                 # straight top edge (along a row of the grid)
def h_visor(a, e): return abs(a) < 64 and -20 < e < h_visor_top(abs(a))

def build_helmet(b, spec):
    """full-face motorbike helmet over the head and hair: rounded shell, chin bar sticking out in front,
    wide wrap-round visor (separate piece), lower edge rising under the jaw"""
    part = spec[1]; s = b.s; msh = Mesh(); W = {"head": 1.0}
    hb = b.rig.data.bones["head"]; rw = b.rig.matrix_world
    U = (rw @ hb.tail_local - rw @ hb.head_local).normalized()
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); L = U.cross(F)
    hv = b.co[b.reg == "head"]; C = Vector((hv.min(0) + hv.max(0))/2) + U*0.010*s
    d = hv - np.array(C)
    rl = float(np.abs(d @ np.array(L)).max()) + 0.050*s
    rf = float((d @ np.array(F)).max()) + 0.030*s; rb = float((-d @ np.array(F)).max()) + 0.050*s
    ru = float((d @ np.array(U)).max()) + 0.045*s
    def pt(a, e, off=0.0):
        ar, er = math.radians(a), math.radians(e)
        f, l, u = math.cos(ar)*math.cos(er), math.sin(ar)*math.cos(er), math.sin(er)
        rF = rf if f > 0 else rb
        p_ = Vector((f*(rF + off), l*(rl + off), u*(ru + off)))
        # chin bar: the lower front pushes forward and squares off
        chin = sst(-6, -34, e)*max(0.0, math.cos(ar))**1.5
        p_.x += 0.030*s*chin; p_.z -= 0.010*s*chin
        # cheeks fuller just behind the chin bar, crown a little flatter
        p_.y *= 1 + 0.06*sst(-10, -45, e)*abs(math.sin(ar))
        if e > 50: p_.z *= 0.97
        return C + F*p_.x + L*p_.y + U*p_.z
    n = 36; step = 360/n
    az = lambda i: -180 + i*step
    EL = H_EL
    def want(a, e):
        if e < h_bottom(a): return False
        return (not h_visor(a, e)) if part == "helmet" else h_visor(a, e)
    off = 0.0 if part == "helmet" else 0.006*s
    cells = {(i, j) for i in range(n) for j in range(len(EL) - 1) if want(az(i + 0.5), (EL[j] + EL[j + 1])/2)}
    ids = {}
    def v(i, j, inner):
        k = (i % n, j, inner)
        if k not in ids:
            bulge = 0.004*s if part == "visor" else 0.0
            ids[k] = msh.vert(pt(az(i), EL[j], off + bulge - (0.007*s if inner else 0)), W)
        return ids[k]
    uv = lambda i, j: ((az(i) + 180)/360, (EL[j] - EL[0])/(EL[-1] - EL[0]))    # whole helmet on one texture
    for i, j in cells:
        q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
        msh.face([v(a_, c, False) for a_, c in q], [uv(a_, c) for a_, c in q])
        msh.face([v(a_, c, True) for a_, c in q[::-1]], [uv(a_, c) for a_, c in q[::-1]])
        for (a0, c0), (a1, c1), nb in (((i, j), (i + 1, j), (i, j - 1)), ((i + 1, j), (i + 1, j + 1), ((i + 1) % n, j)),
                                       ((i + 1, j + 1), (i, j + 1), (i, j + 1)), ((i, j + 1), (i, j), ((i - 1) % n, j))):
            if nb in cells: continue                      # open edge: close it with a rim (helmet edge / visor edge)
            msh.face([v(a1, c1, False), v(a0, c0, False), v(a0, c0, True), v(a1, c1, True)], [uv(a1, c1), uv(a0, c0), uv(a0, c0), uv(a1, c1)])
    return msh

def build_sweep(b, spec, under=None):
    """stiff tapered lenses / horns: an elliptic section (`flat` = thickness / width, thin across n0) along each path;
    kw over: the whole piece moved out along n0 until it clears the skin and every piece built before it"""
    _, name, path_fn, pat, kw = spec
    msh = Mesh(); sides = 10
    tree = BVHTree.FromPolygons(*under) if kw.get("over") and under is not None and len(under[1]) else None
    for hn in path_fn(b):
        pts = [Vector(p) for p in hn["pts"]]; n = len(pts); rings = []; L = 0.0
        if kw.get("over"):
            d = -hn["n0"].normalized() if hn["n0"].dot(Vector((0, -1, 0))) < 0 else hn["n0"].normalized()
            back = max(r*hn["flat"] for r in hn["radii"]) + kw.get("clear", 0.006)*b.s
            need = -1e9
            for i_, p in enumerate(pts):
                t_ = (pts[min(i_ + 1, n - 1)] - pts[max(i_ - 1, 0)]).normalized(); sd_ = t_.cross(d).normalized()
                for q in (p, p + sd_*hn["radii"][i_], p - sd_*hn["radii"][i_]):      # across the whole width
                    for tr in ([b.bvh] + ([tree] if tree else [])):
                        far = outermost(tr, q - d*0.25, d, 0.5)
                        if far is not None: need = max(need, (far - q).dot(d) + back)
            if need > 0: pts = [p + d*need for p in pts]
        for i, p in enumerate(pts):
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
            nn = (hn["n0"] - t*hn["n0"].dot(t)).normalized(); side = t.cross(nn)
            if i: L += (pts[i] - pts[i - 1]).length
            r = hn["radii"][i]
            rings.append(([msh.vert(p + side*r*math.cos(a) + nn*r*hn["flat"]*math.sin(a), hn["w"])
                           for a in np.linspace(0, 2*math.pi, sides + 1)[:-1]], L))
        for i in range(n - 1):
            (r0, L0), (r1, L1) = rings[i], rings[i + 1]
            for k in range(sides):
                k2 = (k + 1) % sides
                msh.face([r0[k], r0[k2], r1[k2], r1[k]], [(L0/TILE, k/sides*0.1), (L0/TILE, (k + 1)/sides*0.1), (L1/TILE, (k + 1)/sides*0.1), (L1/TILE, k/sides*0.1)])
        c0 = msh.vert(pts[0] - (pts[1] - pts[0]).normalized()*0.002, hn["w"])
        for k in range(sides): msh.face([rings[0][0][(k + 1) % sides], rings[0][0][k], c0], [(0, 0)]*3)
    return msh

def _chada():
    """ชฎา profile (scale of the band ellipse, height x s above the band): band, a short dome, seven stepped rings
    getting smaller, then a thin spike"""
    pr = [(1.00, 0.0), (1.03, 0.008), (1.03, 0.026), (0.99, 0.034), (0.93, 0.060), (0.78, 0.092)]
    for i in range(7):
        h = 0.100 + i*0.020; k = 0.62*(1 - i/7.5)
        pr += [(k, h), (k + 0.08, h + 0.004), (k + 0.08, h + 0.009), (k*0.88, h + 0.014)]
    pr += [(0.07, 0.245), (0.045, 0.28), (0.022, 0.32), (0.008, 0.35), (0.0, 0.37)]
    return pr
CHADA = _chada()
def crown_frame(b):
    """head frame for the crown: centre, up / forward / left, band ellipse radii, height of the band (x s from the
    centre) and the head + hair points to keep inside"""
    s = b.s; hb = b.rig.data.bones["head"]; rw = b.rig.matrix_world
    U = (rw @ hb.tail_local - rw @ hb.head_local).normalized()
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); L = U.cross(F)
    pts = [Vector(p) for p in b.co[b.reg == "head"]]
    for o in bpy.data.objects:
        if o.name.startswith("Hair_") and not o.hide_render:
            pts += [o.matrix_world @ v.co for v in o.data.vertices]
    P = np.array([tuple(p) for p in pts]); hv = b.co[b.reg == "head"]
    C = Vector(((hv.min(0) + hv.max(0))/2).tolist())
    f_, l_, u_ = (P - np.array(C)) @ np.array(F), (P - np.array(C)) @ np.array(L), (P - np.array(C)) @ np.array(U)
    top = float(((hv - np.array(C)) @ np.array(U)).max()); base = top - 0.068*s       # band high on the forehead
    band = (u_ > base - 0.01*s) & (u_ < base + 0.03*s)
    rF = float(np.abs(f_[band]).max()) + 0.004*s; rL = float(np.abs(l_[band]).max()) + 0.004*s
    return dict(U=U, F=F, L=L, C=C, f=f_, l=l_, u=u_, base=base, rF=rF, rL=rL)

def build_crown(b, spec):
    """ชฎา: a band low on the forehead, tiers of rings stepping in to a tall spike; at the back and sides the band comes
    down over the skull to the nape, so no hair shows. Every ring stays outside the head and the hair shown in the file."""
    s = b.s; msh = Mesh(); W = {"head": 1.0}; k_ = crown_frame(b)
    U, F, L, C, f_, l_, u_, base, rF, rL = (k_[n] for n in ("U", "F", "L", "C", "f", "l", "u", "base", "rF", "rL"))
    def need(h, a):          # scale of the band ellipse that holds the head / hair at height h (x s above the band), azimuth a
        m = (np.abs(u_ - (base + h*s)) < 0.012*s)
        if not m.any(): return 0.0
        return float(np.sqrt((f_[m]/rF)**2 + (l_[m]/rL)**2).max()) + 0.025     # hugging the head
    drop = lambda a: 0.06*(1 - math.cos(a))/2                # how far the band comes down: 0 at the forehead, 6 cm at the nape
    seg = 36; rows_o, rows_i, rows_pt = [], [], []
    for kk, hh in CHADA:
        ro, ri, rp = [], [], []
        for j in range(seg + 1):
            a = 2*math.pi*j/seg
            h2 = hh - drop(a)*(1 - sst(0.0, 0.08, hh))
            k2 = max(kk, need(h2, a)) if kk > 0 else 0.0
            d = F*math.cos(a)*rF + L*math.sin(a)*rL
            p = C + U*(base + h2*s) + d*k2
            ro.append(msh.vert(p, W)); ri.append(msh.vert(p - (d.normalized()*0.004*s if k2 > 0 else U*0.004*s), W)); rp.append(tuple(p))
        rows_o.append(ro); rows_i.append(ri); rows_pt.append(rp)
    def uvp(i, j): return (2*math.pi*j/seg*(rF + rL)/2/TILE, -CHADA[i][1]*s/TILE)
    for i in range(len(CHADA) - 1):
        for j in range(seg):
            msh.face([rows_o[i][j], rows_o[i][j + 1], rows_o[i + 1][j + 1], rows_o[i + 1][j]], [uvp(i, j), uvp(i, j + 1), uvp(i + 1, j + 1), uvp(i + 1, j)])
            msh.face([rows_i[i][j], rows_i[i + 1][j], rows_i[i + 1][j + 1], rows_i[i][j + 1]], [uvp(i, j), uvp(i + 1, j), uvp(i + 1, j + 1), uvp(i, j + 1)])
    for j in range(seg):                # bottom rim of the band
        msh.face([rows_o[0][j + 1], rows_o[0][j], rows_i[0][j], rows_i[0][j + 1]], [uvp(0, j + 1), uvp(0, j), uvp(0, j), uvp(0, j + 1)])
    # กระจัง: a ring of pointed gold leaves standing up round the top of the band, leaning out a little
    ib = 2; nl = 24
    for j in range(nl):
        a0, a1 = 2*math.pi*(j + 0.1)/nl, 2*math.pi*(j + 0.9)/nl; am = (a0 + a1)/2
        def ring_pt(a, row=ib):
            jj = a/(2*math.pi)*seg; j0 = int(jj) % seg; f = jj - int(jj)
            return Vector(rows_pt[row][j0]).lerp(Vector(rows_pt[row][(j0 + 1) % seg]), f)
        p0, p1 = ring_pt(a0), ring_pt(a1); pm = ring_pt(am)
        out = (pm - (C + U*U.dot(pm - C))).normalized()
        tip = pm + U*0.030*s + out*0.008*s; th_ = out*0.0025*s
        v = [msh.vert(q, W) for q in (p0 + th_, p1 + th_, tip + th_, p0 - th_, p1 - th_, tip - th_)]
        msh.face([v[0], v[1], v[2]], [(0, 0), (0.05, 0), (0.025, 0.1)]); msh.face([v[5], v[4], v[3]], [(0.025, 0.1), (0.05, 0), (0, 0)])
        msh.face([v[3], v[0], v[2], v[5]], [(0, 0)]*4); msh.face([v[1], v[4], v[5], v[2]], [(0, 0)]*4)
    return msh

def _ball(msh, c, r, w, seg=8, rings=5, v0=0.0, v1=1.0, flat=None):
    """sphere; flat = (axis, factor): squashed along axis (a petal)"""
    ids = []
    for i in range(rings + 1):
        th = math.pi*i/rings; row = []
        for j in range(seg + 1):
            ph = 2*math.pi*j/seg
            d = Vector((math.sin(th)*math.cos(ph), math.sin(th)*math.sin(ph), math.cos(th)))
            if flat: d = d - flat[0]*d.dot(flat[0])*(1 - flat[1])
            row.append(msh.vert(c + d*r, w))
        ids.append(row)
    for i in range(rings):
        for j in range(seg):
            uv = lambda ii, jj: (jj/seg*0.1, v0 + (v1 - v0)*(1 - ii/rings))
            msh.face([ids[i][j], ids[i + 1][j], ids[i + 1][j + 1], ids[i][j + 1]], [uv(i, j), uv(i + 1, j), uv(i + 1, j + 1), uv(i, j + 1)])

def build_flowers(b, spec):
    """ดอกไม้ทัดหู + อุบะ: a cluster of red flowers on each temple, on the crown's band, and three short strings of
    flower buds hanging beside the ear, kept off the head and the crown"""
    s = b.s; msh = Mesh(); W = {"head": 1.0}; k_ = crown_frame(b)
    U, F, L, C, rF, rL, base = (k_[n] for n in ("U", "F", "L", "C", "rF", "rL", "base"))
    head = BVHTree.FromPolygons([tuple(p) for p in b.co], [list(p.vertices) for p in b.ob.data.polygons])
    rnd = np.random.RandomState(5)
    for sx in (1, -1):
        a = sx*math.radians(72); d = (F*math.cos(a)*rF + L*math.sin(a)*rL)
        c0 = C + U*(base - 0.005*s) + d*1.12 + d.normalized()*0.012*s
        out_ = d.normalized(); t1 = out_.cross(U).normalized(); t2 = out_.cross(t1)
        for k in range(3 if sx > 0 else 1):  # flowers: each a dark centre and six petals round it; one big rose on the right
            off = (t1*rnd.uniform(-1, 1) + t2*rnd.uniform(-1, 1))*0.012*s if sx > 0 else Vector()
            cc = c0 + off + out_*0.006*s; pr_ = (0.009 + 0.002*rnd.rand())*s if sx > 0 else 0.016*s
            _ball(msh, cc, pr_*0.55, W, seg=6, rings=4, v0=0.0, v1=0.15)
            for j in range(6):
                a_ = 2*math.pi*j/6 + rnd.rand()
                _ball(msh, cc + (t1*math.cos(a_) + t2*math.sin(a_))*pr_*1.0 - out_*0.002*s, pr_*0.75, W, seg=6, rings=4, v0=0.25, v1=0.85,
                      flat=(out_, 0.30))
        for t in range(3):          # อุบะ: buds hanging down beside the ear, a little out from the cheek
            st = c0 + L*sx*0.0 + F*(t - 1)*0.012*s - U*0.012*s
            for k in range(5):
                p = st - U*(0.013*k)*s
                loc = head.find_nearest(p)[0]
                if loc is not None and (p - loc).length < 0.022*s: p = loc + (p - loc).normalized()*0.022*s
                _ball(msh, p, (0.0055 - 0.0006*k)*s, W, seg=6, rings=4, v0=0.0, v1=0.6)
    return msh

# ---------------------------------------------------------------- materials# ---------------------------------------------------------------- materials
def tex_material(name, base, metal=False):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes.get("Principled BSDF")
    def tex(suffix, noncolor, loc):
        img = bpy.data.images.load(base + suffix + ".png", check_existing=True); img.reload()
        if noncolor: img.colorspace_settings.name = "Non-Color"
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img; n.location = loc; return n
    c = tex("_Color", False, (-500, 300)); nt.links.new(c.outputs["Color"], bsdf.inputs["Base Color"])
    r = tex("_Roughness", True, (-500, 0)); nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    n = tex("_Normal", True, (-700, -300)); nm = nt.nodes.new("ShaderNodeNormalMap"); nm.location = (-300, -300)
    nt.links.new(n.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if metal: bsdf.inputs["Metallic"].default_value = 1.0
    return m

# ---------------------------------------------------------------- per-character pipeline
def clear_clothes():
    for o in list(bpy.data.objects):
        if o.name.startswith("Cloth_"): me = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.meshes.remove(me)
    c = bpy.data.collections.get("Clothes")
    if c: bpy.data.collections.remove(c)
    for m in list(bpy.data.materials):
        if m.name.startswith("Cloth_") and m.users == 0: bpy.data.materials.remove(m)

def fix_armpit_weights(body, b):
    """trunk-ring vertices held 100% by an upper arm (the armpit apex on some bodies) get the average weights of
    themselves and their neighbours: skinned to the arm alone they fold out of every shirt when the arm goes up"""
    fixed = 0
    for vi in range(len(b.co)):
        if b.ring[vi] < 0 or not b.reg[vi].startswith("arm") or b.armw[vi] < 0.98: continue
        acc = {}
        for nb in [vi] + b.nbr[vi]:
            for g, x in vweights(b, nb).items(): acc[g] = acc.get(g, 0) + x
        top = sorted(acc.items(), key=lambda t: -t[1])[:4]; tot = sum(x for _, x in top)
        for g in body.vertex_groups: g.remove([vi])
        for g, x in top:
            body.vertex_groups[g].add([vi], x/tot, 'REPLACE'); b.w[vi, b.names.index(g)] = x/tot
        for gi in range(b.w.shape[1]):
            if b.names[gi] not in dict(top): b.w[vi, gi] = 0.0
        b.armw[vi] = sum(x/tot for g, x in top if g.startswith("upper_arm")); fixed += 1
    return fixed

def add_clothes(char, outfits=None, keep_others=False):
    """build every outfit of `char` (or just `outfits`) on the Body in the current scene; the character's first outfit
    shown, the rest hidden. keep_others: only the listed outfits are rebuilt, the other Cloth_ objects stay as they are"""
    if keep_others:
        for o in list(bpy.data.objects):
            if any(o.name == f"Cloth_{n}" or o.name.startswith(f"Cloth_{n}_") for n in outfits):
                me = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.meshes.remove(me)
    else:
        clear_clothes()
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    poses = [tuple(pb.rotation_euler) for pb in rig.pose.bones]
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    faces = json.load(open(os.path.join(char_dir(char), NAMES[char] + "_clothes.json")))
    if faces["polys"] != len(body.data.polygons): raise RuntimeError(f"{char}: clothes file is for {faces['polys']} faces")
    b = Body(body, rig); made = {}
    fix_armpit_weights(body, b)
    for oi, name in enumerate(outfits or CHAR_OUTFITS[char]):
        objs = []
        shell = Mesh(); shell_specs = [sp for sp in OUTFITS[name] if sp[0] == "shell"]
        parts = []
        for sp in shell_specs:
            part = build_shell(b, sp, faces["outfits"][name][sp[1]]); parts.append((sp, part))
            off = len(shell.v)
            shell.v += part.v; shell.w += part.w; shell.uv += part.uv; shell.src += part.src; shell.f += [[i + off for i in f] for f in part.f]
        # what a skirt / sash has to go over: shirt and trousers on the trunk and legs (not the sleeves held out to the side)
        ok = [sv >= 0 and b.reg[sv] in ("torso", "leg.L", "leg.R") for sv in shell.src]
        under = ([tuple(v) for v in shell.v], [f for f in shell.f if all(ok[i] for i in f)])
        under_all = ([tuple(v) for v in shell.v], shell.f)                     # strips laid over everything (sleeves too)
        for k, (sp, part) in enumerate(parts):      # one object per piece, each with its own texture (see paint_shell)
            if not part.f: continue
            suffix = "" if k == 0 else "_" + sp[1]
            mat = tex_material(f"Cloth_{char}_{name}{suffix}", shell_tex_base(char, name, k, sp[1]))
            objs.append(part.to_object(f"Cloth_{name}{suffix}", rig, mat, fix_normals=False))
        def outside(msh):     # faces of a built piece that face away from the skin (not a skirt's / strip's inner wall)
            keep = []
            for f in msh.f:
                P_ = [msh.v[i] for i in f]; c = sum(P_, Vector())/len(P_)
                n = (P_[1] - P_[0]).cross(P_[2] - P_[0])
                loc = b.bvh.find_nearest(c)[0]
                if loc is not None and n.length > 1e-12 and (c - loc).dot(n) > 0: keep.append(f)
            return keep
        for sp in OUTFITS[name]:
            kind = sp[0]
            if kind == "shell": continue
            pat = sp[4] if kind in ("tube", "strip", "ring") else sp[3] if kind == "sweep" else sp[2]   # hat / helmet / shoe / crown: (kind, name, pattern)
            msh = build_tube(b, sp, under) if kind == "tube" else build_strip(b, sp, under_all) if kind == "strip" else \
                  build_sweep(b, sp, under_all) if kind == "sweep" else                   {"ring": build_ring, "hat": build_hat, "helmet": build_helmet, "shoe": build_shoe, "sandal": build_sandal,
                   "crown": build_crown, "flowers": build_flowers}[kind](b, sp)
            mat = tex_material(f"Cloth_{pat}", os.path.join(TEX, pat), PATTERNS[pat][2])
            if kind in ("tube", "strip", "sweep"):
                base_ = len(under_all[0])
                under_all = (under_all[0] + [tuple(v) for v in msh.v], under_all[1] + [[base_ + i for i in f] for f in outside(msh)])
            ob = msh.to_object(f"Cloth_{name}_{sp[1]}", rig, mat)
            if kind in ("hat", "helmet", "crown", "flowers"):
                for vg in list(ob.vertex_groups): ob.vertex_groups.remove(vg)
                g = ob.vertex_groups.new(name="head"); g.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
            objs.append(ob)
        for ob in objs:
            hide = name != CHAR_OUTFITS[char][0]; ob.hide_render = hide; ob.hide_set(hide)
        made[name] = objs
    for pb, r in zip(rig.pose.bones, poses): pb.rotation_euler = r
    print(char, {k: sum(len(o.data.polygons) for o in v) for k, v in made.items()})
    return made

def clothes_char(char, save=True):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(char), NAMES[char] + ".blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    b = Body(body, rig)
    faces = pick_faces(b, char)
    json.dump(dict(polys=len(body.data.polygons), outfits=faces), open(os.path.join(char_dir(char), NAMES[char] + "_clothes.json"), "w"))
    uv = np.zeros((len(body.data.loops), 2)); body.data.uv_layers.active.data.foreach_get("uv", uv.ravel())
    ras = raster_body(b, uv)
    for name in CHAR_OUTFITS[char]:
        if any(sp[0] == "shell" for sp in OUTFITS[name]): paint_shell(b, ras, faces[name], char, name)
    if save:
        bpy.context.preferences.filepaths.save_version = 0
        for f in blend_files(char):
            bpy.ops.wm.open_mainfile(filepath=f); add_clothes(char); bpy.ops.wm.save_mainfile()

def limit_cloth_weights(objs, n=4):
    """Roblox skins with at most 4 bones per vertex (skirt / panel weights can mix 5)"""
    for ob in objs:
        names = {g.index: g for g in ob.vertex_groups}
        for v in ob.data.vertices:
            gs = sorted(((g.group, g.weight) for g in v.groups if g.weight > 0), key=lambda t: -t[1])
            if len(gs) <= n and abs(sum(w for _, w in gs) - 1) < 1e-4: continue
            keep = gs[:n]; tot = sum(w for _, w in keep) or 1.0
            for gi, _ in gs[n:]: names[gi].remove([v.index])
            for gi, w in keep: names[gi].add([v.index], w/tot, 'REPLACE')

def fix_image_paths():
    """images whose file isn't there (an absolute path into another copy of the repo) pointed at this M"""
    for im in bpy.data.images:
        fp = os.path.normpath(bpy.path.abspath(im.filepath)) if im.filepath else ""
        if not fp or os.path.exists(fp): continue
        key = "\\assets\\models\\"
        k = fp.replace("/", "\\").lower().rfind(key)
        if k >= 0:
            new = os.path.join(M, fp[k + len(key):])
            if os.path.exists(new): im.filepath = new; im.reload()

def add_outfits(char, outfits, save=True):
    """add outfits to a character without touching the ones it has: their faces go into <name>_clothes.json next to
    the stored ones (kept as they are), only their textures are painted, and in every .blend of the character only
    their Cloth_ objects are (re)built. Texture paths are saved relative, so the files work from any checkout."""
    bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(char), NAMES[char] + ".blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    b = Body(body, rig); faces = pick_faces(b, char)
    jf = os.path.join(char_dir(char), NAMES[char] + "_clothes.json"); old = json.load(open(jf))
    if old["polys"] != len(body.data.polygons): raise RuntimeError(f"{char}: clothes file is for {old['polys']} faces")
    out = {k: (faces[k] if k in outfits else old["outfits"][k]) for k in CHAR_OUTFITS[char] if k in outfits or k in old["outfits"]}
    json.dump(dict(polys=old["polys"], outfits=out), open(jf, "w"))
    uv = np.zeros((len(body.data.loops), 2)); body.data.uv_layers.active.data.foreach_get("uv", uv.ravel())
    ras = raster_body(b, uv)
    for name in outfits:
        if any(sp[0] == "shell" for sp in OUTFITS[name]): paint_shell(b, ras, faces[name], char, name)
    if not save: return
    bpy.context.preferences.filepaths.save_version = 0
    for f in blend_files(char):
        bpy.ops.wm.open_mainfile(filepath=f); fix_image_paths()
        made = add_clothes(char, outfits, keep_others=True)
        limit_cloth_weights([o for v in made.values() for o in v])
        bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()

def clothes_all(save=True):
    make_patterns()
    for c in DIRS.values(): clothes_char(c, save)

# ---------------------------------------------------------------- preview: rows = outfits, columns front / 3-4 / side / back
def preview(char, out, outfits=None, skin=None, hair=None):
    """outfits: rows to render (default all of the character); skin: Body material for the shot (e.g. "SkinGhost");
    hair: the Hair_<style> to show instead of the one shown in the file"""
    sc = bpy.context.scene; body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    keep_mat = body.data.materials[0]
    if skin and skin in bpy.data.materials: body.data.materials[0] = bpy.data.materials[skin]
    keep_hair = {o: o.hide_render for o in bpy.data.objects if o.name.startswith("Hair_")}
    if hair and ("Hair_" + hair) in bpy.data.objects:
        for o in keep_hair: o.hide_render = o.name != "Hair_" + hair
    b = Body(body, rig); s = b.s
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = w
    w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.26, 0.28, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    temps = []
    for nm, rot, e in (("_key", (55, 0, -35), 3.5), ("_fill", (70, 0, 60), 1.2), ("_rim", (60, 0, 170), 1.5)):
        l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, 'SUN')); l.data.energy = e
        l.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(l); temps.append(l)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); temps.append(cam)
    sc.camera = cam; cam.data.type = 'ORTHO'
    H = float(b.co[:, 2].max() - b.foot_z) + 0.12*s
    cam.data.ortho_scale = H*1.05; sc.render.resolution_x = 300; sc.render.resolution_y = 520
    tgt = Vector((0, 0, b.foot_z + H/2 - 0.03*s))
    hair = [o for o in bpy.data.objects if o.name.startswith("Hair_")]
    shown = [o for o in hair if not o.hide_render]
    rows = []
    for name in outfits or CHAR_OUTFITS[char]:
        for o in bpy.data.objects:
            if o.name.startswith("Cloth_"):
                vis = o.name == f"Cloth_{name}" or o.name.startswith(f"Cloth_{name}_")
                o.hide_render = not vis
        row = []
        for ang in (0, 40, 90, 180):
            a = math.radians(ang); d = Vector((math.sin(a), -math.cos(a), 0.0))
            cam.location = tgt + d*3; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
            tmp = out[:-4] + "_t.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp); arr = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(arr)
            row.append(arr.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
        rows.append(np.concatenate(row, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = out; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    for o in temps: bpy.data.objects.remove(o, do_unlink=True)
    body.data.materials[0] = keep_mat
    for o, h in keep_hair.items(): o.hide_render = h

GHOST_HAIR = {"female": "ghost_long", "elder_female": "ghost_long_white"}
def preview_ghosts(out_dir=os.path.join(M, "clothes_previews")):
    """clothes_previews/ghost_<char>.png: only the ghost outfits, on the SkinGhost skin with ghost hair"""
    for c in DIRS.values():
        rows = [o for o in CHAR_OUTFITS[c] if o in GHOST_OUTFITS]
        if not rows: continue
        bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(c), NAMES[c] + ".blend"))
        if not any(o.name.startswith("Cloth_") for o in bpy.data.objects): add_clothes(c)
        preview(c, os.path.join(out_dir, "ghost_" + NAMES[c] + ".png"), rows, "SkinGhost", GHOST_HAIR.get(c))

def preview_all(chars=None, out_dir=os.path.join(M, "clothes_previews")):
    os.makedirs(out_dir, exist_ok=True)
    for c in chars or DIRS.values():
        bpy.ops.wm.open_mainfile(filepath=os.path.join(char_dir(c), NAMES[c] + ".blend"))
        if not any(o.name.startswith("Cloth_") for o in bpy.data.objects): add_clothes(c)
        preview(c, os.path.join(out_dir, NAMES[c] + ".png"))

if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    chars = [a for a in argv if a in CHAR_OUTFITS] or None
    if "--save" in argv:
        make_patterns()
        for c in chars or DIRS.values(): clothes_char(c)
    if "--preview" in argv: preview_all(chars)
    if "--preview-ghosts" in argv: preview_ghosts()
