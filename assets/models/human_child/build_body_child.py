import bpy, bmesh, math
from mathutils import Vector

for n in ("Body", "_fh", "_ff", "_fs", "_fp"):
    o = bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o, do_unlink=True)

bm = bmesh.new()
V = lambda p: bm.verts.new(Vector(p))
def quad(a, b, c, d): bm.faces.new((a, b, c, d))
def loft(r1, r2, skip=()):
    n = len(r1)
    for i in range(n):
        if i in skip: continue
        quad(r1[i], r1[(i+1) % n], r2[(i+1) % n], r2[i])
def bridge(A, B, mid=None):
    # mid: (blend, push_vector) adds an in-between ring for a softer joint
    n = len(A); best = None
    for rev in (False, True):
        BB = list(reversed(B)) if rev else B
        for o in range(n):
            s = sum((A[i].co - BB[(i+o) % n].co).length for i in range(n))
            if best is None or s < best[0]: best = (s, [BB[(i+o) % n] for i in range(n)])
    B = best[1]
    if mid:
        t, push = mid
        M = [V(A[i].co.lerp(B[i].co, t) + push) for i in range(n)]
        loft(A, M); loft(M, B)
    else:
        loft(A, B)

# ---------- torso + neck + head : rings of 16 ----------
def sring(z, w, f, b, cy=0.0, n=2.0, zfun=None, dent=None):
    r = []
    for k in range(16):
        ph = 2*math.pi*k/16; s = math.sin(ph); c = math.cos(ph)
        x = w*math.copysign(abs(s)**(2/n), s)
        y = cy - (f if c > 0 else b)*math.copysign(abs(c)**(2/n), c)
        zz = z + (zfun(ph) if zfun else 0)
        if dent and k in dent: y += dent[k]
        r.append(V((x, y, zz)))
    return r

ARM_DEG = 42
HEAD_DZ = 0.012
SCALE = 1.0       # child: final size comes from child_remap.py
ARM_K = 0.92      # shorter arms
SHO = (0.150, 1.39)
LEG_X = (0.090, 0.088, 0.089, 0.090)   # thigh top, knee, calf, ankle/foot x
T = []
T.append(sring(0.875, 0.145, 0.100, 0.105, zfun=lambda ph: -0.040*math.cos(ph)**2))  # 0 crotch
T.append(sring(0.95, 0.148, 0.108, 0.112, n=2.2))        # 1 hips
T.append(sring(1.07, 0.142, 0.128, 0.086, n=2.2))        # 2 belly (no waist)
T.append(sring(1.16, 0.145, 0.119, 0.088, n=2.2))        # 3 lower ribs
T.append(sring(1.22, 0.146, 0.104, 0.090, n=2.2))        # 4
T.append(sring(1.25, 0.147, 0.102, 0.090, n=2.2))        # 4a
T.append(sring(1.28, 0.148, 0.101, 0.090, n=2.2))        # 4b
SOCK0 = len(T)
T.append(sring(1.31, 0.150, 0.100, 0.090, n=2.2))        # 5 armpit (socket bottom)
T.append(sring(1.355, 0.152, 0.097, 0.088, n=2.2, zfun=lambda ph, a=0.008, b=0.0: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))       # 5b socket
T.append(sring(1.404, 0.148, 0.090, 0.085, n=2.2, zfun=lambda ph, a=0.016, b=0.0: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))       # 5c socket
T.append(sring(1.452, 0.135, 0.080, 0.080, cy=0.005, n=2.1, zfun=lambda ph, a=0.020, b=0.0: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))  # 6 shoulder top
T.append(sring(1.480, 0.095, 0.065, 0.066, cy=0.010, n=2.1, zfun=lambda ph, a=0.012, b=0.008: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))  # 7 trapezius
T.append(sring(1.497, 0.070, 0.056, 0.058, cy=0.012, n=2.0, zfun=lambda ph, a=0.010, b=0.010: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))  # 7b
T.append(sring(1.510, 0.059, 0.053, 0.053, cy=0.014, zfun=lambda ph, a=0.010, b=0.012: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))))    # 8 neck base
T.append(sring(1.553, 0.056, 0.053, 0.046, cy=0.015, zfun=lambda ph: -0.020*math.cos(ph)))    # 9 neck top
T.append(sring(1.585, 0.053, 0.068, 0.071, cy=0.0, n=2.2, zfun=lambda ph: -0.012*math.cos(ph)))   # 10 under jaw
T.append(sring(1.606, 0.061, 0.080, 0.086, n=2.2, zfun=lambda ph: -0.006*math.cos(ph)))       # 11 jaw (small)
T.append(sring(1.640, 0.074, 0.090, 0.098, n=2.1))       # 12 mouth / cheeks
T.append(sring(1.680, 0.089, 0.096, 0.109, n=2.1, dent={1: 0.008, 15: 0.008}))  # 13 eyes
T.append(sring(1.720, 0.094, 0.103, 0.114, n=2.1))       # 14 brow
T.append(sring(1.760, 0.095, 0.105, 0.113))              # 15 big forehead
T.append(sring(1.792, 0.078, 0.088, 0.095))              # 16 crown
T.append(sring(1.806, 0.046, 0.054, 0.058))              # 17 crown cap
top = V((0, 0.005, 1.816))
for i in range(len(T)-1):
    loft(T[i], T[i+1], skip={3, 4, 11, 12} if i in (SOCK0, SOCK0+1, SOCK0+2) else ())
for k in range(16): bm.faces.new((T[-1][k], T[-1][(k+1) % 16], top))
crotch = V((0, 0.005, 0.815))

d0 = math.radians(ARM_DEG)
for sx in (1, -1):
    X = lambda p: (p[0]*sx, p[1], p[2])
    # ---------- leg ----------
    def ering(cx, cy, z, rx, ry):
        return [V(X((cx + rx*math.cos(2*math.pi*k/10), cy + ry*math.sin(2*math.pi*k/10), z))) for k in range(10)]
    tx, kx, cx_, ax = LEG_X
    LR = [ering(tx, 0.0, 0.76, 0.092, 0.101),
          ering((tx+kx)/2, -0.006, 0.66, 0.084, 0.090),
          ering(kx, -0.008, 0.56, 0.069, 0.074),
          ering(kx, -0.012, 0.495, 0.063, 0.065),
          ering(kx, -0.006, 0.44, 0.062, 0.065),
          ering(cx_, 0.010, 0.37, 0.063, 0.067),
          ering(ax, 0.006, 0.25, 0.053, 0.056),
          ering(ax, 0.004, 0.15, 0.043, 0.047)]
    loopT = [T[0][k] for k in range(0, 9)] + [crotch] if sx == 1 else [T[0][0]] + [T[0][k] for k in range(15, 7, -1)] + [crotch]
    bridge(loopT, LR[0], mid=(0.5, Vector((0.004*sx, 0, 0))))
    for a, b in zip(LR, LR[1:]): loft(a, b)
    # ---------- foot (rings perpendicular to Y) ----------
    def fring(y, hw, top, bot=0.0, cx=LEG_X[3], fr=(0, 0.2, 0.4, 0.6, 0.8, 1.0)):
        # 12-vert ring: top row j=0..5 (inner->outer), bottom row reversed
        tr = [V(X((cx - hw + 2*hw*f, y, bot + top*(1.0 if 0 < j < 5 else 0.82)))) for j, f in enumerate(fr)]
        br = [V(X((cx - hw + 2*hw*f, y, bot + (0.0 if 0 < j < 5 else 0.006)))) for j, f in reversed(list(enumerate(fr)))]
        return tr + br
    TOEFR = (0, 0.30, 0.50, 0.68, 0.85, 1.0)
    FR = [fring(0.054, 0.025, 0.058),
          fring(0.030, 0.033, 0.100),
          fring(-0.026, 0.037, 0.106),
          fring(-0.068, 0.042, 0.080),
          fring(-0.112, 0.046, 0.056),
          fring(-0.146, 0.046, 0.038, fr=TOEFR)]
    for i, (a, b) in enumerate(zip(FR, FR[1:])):
        loft(a, b, skip=(0, 1, 2, 3) if i == 1 else ())
    r0 = FR[0]
    for j in range(5): quad(r0[j], r0[j+1], r0[10-j], r0[11-j])
    sock = [FR[1][j] for j in range(5)] + [FR[2][j] for j in range(4, -1, -1)]
    bridge(LR[-1], sock)
    # toes: one per front quad of the last ring (j=0 big toe, inner side)
    K = FR[-1]; XS = Vector((sx, 0, 0)); ZU = Vector((0, 0, 1))
    toe_len = (0.042, 0.034, 0.030, 0.026, 0.022)
    toe_out = (0.00, 0.03, 0.07, 0.11, 0.16)
    for j in range(5):
        base = [K[j], K[j+1], K[10-j], K[11-j]]
        c = sum((b.co for b in base), Vector())/4
        hw0 = abs(K[j+1].co.x - K[j].co.x)/2
        th0 = (K[j].co.z + K[j+1].co.z)/2 * 0.5
        td = Vector((toe_out[j]*sx, -1.0, 0.0)).normalized()
        prev = base
        for k, (fr_, sc) in enumerate(((0.55, 0.97), (1.0, 0.82))):
            hw = hw0*sc*0.97; th = max(th0*sc, 0.007)
            cc = c + td*(toe_len[j]*fr_); cc.z = th + 0.001
            ring = [V(cc - XS*hw + ZU*th), V(cc + XS*hw + ZU*th), V(cc + XS*hw - ZU*th*0.9), V(cc - XS*hw - ZU*th*0.9)]
            loft(prev, ring); prev = ring
        quad(*prev)
    # ---------- arm ----------
    d = Vector((math.cos(d0)*sx, 0, -math.sin(d0))); u = Vector((math.sin(d0)*sx, 0, math.cos(d0))); v = Vector((0, 1, 0))
    S = Vector((SHO[0]*sx, 0, SHO[1]))
    def ring_at(c, ang, ru, rv):
        a = math.radians(ang)
        uu = Vector((math.sin(a)*sx, 0, math.cos(a)))
        out = []
        for k in range(10):
            th = math.radians(162 - 36*k)
            out.append(V(c + v*(math.cos(th)*rv) + uu*(math.sin(th)*ru)))
        return out
    def aring(t, ru, rv): return ring_at(S + d*t*ARM_K, ARM_DEG, ru, rv)
    # shoulder: arm leaves the socket nearly horizontal, deltoid caps over, then bends down
    AR = [ring_at(Vector(((SHO[0]+0.012)*sx, 0.0, SHO[1]-0.008)), 10, 0.061, 0.055),
          ring_at(Vector(((SHO[0]+0.045)*sx, 0.0, SHO[1]-0.020)), 28, 0.057, 0.053),
          aring(0.12, 0.056, 0.055), aring(0.19, 0.052, 0.051),
          aring(0.27, 0.046, 0.045), aring(0.30, 0.044, 0.045), aring(0.36, 0.045, 0.044),
          aring(0.46, 0.039, 0.037), aring(0.545, 0.029, 0.032)]
    if sx == 1: ks = (3, 4, 5)
    else:       ks = (13, 12, 11)
    a_, b_, c_ = ks
    s0 = SOCK0
    sk = [T[s0][a_], T[s0][b_], T[s0][c_], T[s0+1][c_], T[s0+2][c_], T[s0+3][c_], T[s0+3][b_], T[s0+3][a_], T[s0+2][a_], T[s0+1][a_]]
    bridge(sk, AR[0])
    for a, b in zip(AR, AR[1:]): loft(a, b)
    # ---------- hand ----------
    W = S + d*0.55*ARM_K
    def hring(t, th, hw):
        c = W + d*t
        tr = [V(c + v*(-hw + hw*j/2) + u*(th*(1.0 if j in (1, 2, 3) else 0.65))) for j in range(5)]
        br = [V(c + v*(-hw + hw*j/2) - u*(th*(1.0 if j in (1, 2, 3) else 0.65))) for j in range(4, -1, -1)]
        return tr + br
    HR = [hring(0.012, 0.021, 0.032), hring(0.046, 0.017, 0.039), hring(0.084, 0.0145, 0.039)]
    loft(AR[-1], HR[0])
    loft(HR[0], HR[1], skip=(9,))   # thumb socket
    loft(HR[1], HR[2])
    K = HR[2]; lens = (0.056, 0.063, 0.058, 0.046); spread = (-0.10, -0.03, 0.04, 0.11)
    for i in range(4):
        base = [K[i], K[i+1], K[8-i], K[9-i]]
        c = sum((b.co for b in base), Vector())/4
        prev = base; L = lens[i]
        for sgi, (fr, hw, th) in enumerate(((0.42, 0.0092, 0.0085), (0.33, 0.0084, 0.0077), (0.25, 0.0072, 0.0066))):
            fd = (d - u*(0.12*(sgi+1)) + v*spread[i]).normalized()
            fu = (u - fd*u.dot(fd)).normalized(); fv = fd.cross(fu); fv = fv if fv.dot(v) > 0 else -fv
            c = c + fd*(L*fr)
            ring = [V(c - fv*hw + fu*th), V(c + fv*hw + fu*th), V(c + fv*hw - fu*th), V(c - fv*hw - fu*th)]
            loft(prev, ring); prev = ring
        quad(*prev)
    base = [HR[0][9], HR[0][0], HR[1][0], HR[1][9]]
    c = sum((b.co for b in base), Vector())/4
    td = (d*0.6 - v*0.6 - u*0.45).normalized()
    tu = (u - td*u.dot(td)).normalized(); tv = td.cross(tu)
    prev = base
    for dist, hw in ((0.022, 0.0112), (0.045, 0.0094), (0.064, 0.0076)):
        cc = c + td*dist
        ring = [V(cc - tv*hw + tu*hw*0.85), V(cc + tv*hw + tu*hw*0.85), V(cc + tv*hw - tu*hw*0.85), V(cc - tv*hw - tu*hw*0.85)]
        bridge(prev, ring); prev = ring
    quad(*prev)

# nose & ears (closed pieces)
nt = V((0, -0.097, 1.703)); rg = V((0, -0.101, 1.668)); tp = V((0, -0.110, 1.650)); cl = V((0, -0.101, 1.640)); nb = V((0, -0.090, 1.660))
for sx in (1, -1):
    sd = V((0.011*sx, -0.096, 1.668)); al = V((0.016*sx, -0.095, 1.643))
    for f in ((nt, sd, rg), (rg, sd, tp), (sd, al, tp), (al, cl, tp), (al, nb, cl), (nt, nb, sd), (sd, nb, al)): bm.faces.new(f)
EAR = ((0.000, 0.037), (0.019, 0.031), (0.026, 0.006), (0.018, -0.022), (0.003, -0.037), (-0.009, -0.026), (-0.012, 0.020))
for sx in (1, -1):
    cy_, cz_ = 0.016, 1.668
    O = []; I = []; Bk = []
    for dy, dz in EAR:
        flare = 0.025*max(0.0, min(1.0, (dy + 0.012)/0.038))
        O.append(V((sx*(0.074 + flare), cy_ + dy, cz_ + dz)))
        I.append(V((sx*(0.071 + flare*0.8), cy_ + dy*0.55 + 0.002, cz_ + dz*0.6)))
        Bk.append(V((sx*0.066, cy_ + dy, cz_ + dz)))
    C_ = V((sx*0.068, cy_ + 0.004, cz_ - 0.002))
    n = len(EAR)
    for j in range(n):
        k = (j + 1) % n
        bm.faces.new((O[j], O[k], I[k], I[j]))
        bm.faces.new((I[j], I[k], C_))
        bm.faces.new((Bk[j], Bk[k], O[k], O[j]))
    bm.faces.new(list(reversed(Bk)))

for vt in bm.verts:
    if vt.co.z > 1.572: vt.co.z -= HEAD_DZ
for vt in bm.verts: vt.co *= SCALE
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("Body"); bm.to_mesh(me); bm.free()
for p in me.polygons: p.use_smooth = True
ob = bpy.data.objects.new("Body", me); bpy.context.collection.objects.link(ob)
bm2 = bmesh.new(); bm2.from_mesh(me)
print("faces", len(me.polygons), "non-manifold", sum(1 for e in bm2.edges if not e.is_manifold))
bm2.free()
