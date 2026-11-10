# Villager v2 body: one skin made of lofted rings, split into 3 parts that share their seam rings.
#   blender -b --factory-startup --python build_body.py -- [male|female]
#   or exec() with CHAR = "male" / "female" set in the namespace
#
# Parts (face attribute "part"): 0 head (neck base ring and up) · 1 upper (waist ring .. neck base, arms, hands)
#                                2 lower (waist ring and down, legs, shoe-shaped feet)
# Seams: the rings tagged "waist" and "neck" — every lower / upper / head variant must reuse them.
# Rest pose and joint places match the old rigs (human_base/build_rig.py, human_female/build_rig_female.py):
# A-pose arms 42 deg, same shoulder / hip / knee / ankle places, so the 52-bone rig and the mocap retarget still fit.
# Face is smooth (painted later), feet have no toes (everyone wears painted shoes), ears are a smooth lump.
# Numbers are written at male scale; the female body is built at these numbers and then scaled by SCALE (0.93),
# exactly like the old female.
import bpy, bmesh, math, sys
from mathutils import Vector

if "CHAR" not in globals():
    _a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    CHAR = "female" if "female" in _a else "male"

N = 24                 # torso / head ring
NA = 12                # arm ring
NL = N // 2 + 2        # leg ring (half the pelvis ring + the crotch point)
ARM_DEG = 42

def zf(a, b=0.0): return lambda ph: a*math.sin(ph)**2 + b*max(0.0, -math.cos(ph))
def cosz(a): return lambda ph: a*math.cos(ph)
CROTCHZ = lambda ph: -0.040*math.cos(ph)**2
def bust(c0, c1, c2, c3):
    """forward push of the bust by angle from the front (0, 22.5, 45, 67.5 deg; 0 at 90), both sides"""
    pts = ((0.0, c0), (22.5, c1), (45.0, c2), (67.5, c3), (90.0, 0.0))
    def f(ph):
        a = abs(math.degrees(math.atan2(math.sin(ph), math.cos(ph))))
        if a >= 90: return 0.0
        for (a0, v0), (a1, v1) in zip(pts, pts[1:]):
            if a <= a1: return v0 + (v1 - v0)*(a - a0)/(a1 - a0)
        return 0.0
    return f

# head above the eyes: the same for both
HEAD_TOP = [
    (1.742, 0.077, 0.098, 0.097, 0.0,   2.15, None, None, ""),
    (1.760, 0.072, 0.090, 0.090, 0.0,   2.05, None, None, ""),
    (1.778, 0.063, 0.077, 0.079, 0.0,   2.0,  None, None, ""),
    (1.792, 0.052, 0.063, 0.067, 0.0,   2.0,  None, None, ""),
    (1.802, 0.036, 0.044, 0.047, 0.003, 2.0,  None, None, ""),
    (1.807, 0.018, 0.022, 0.024, 0.004, 2.0,  None, None, ""),
]
#            z      half-w  front  back   cy     n     z offset      y offset (bust)  tag
MALE_RINGS = [
    (0.875, 0.150, 0.095, 0.110, 0.0,   2.0,  CROTCHZ,     None, ""),        # crotch
    (0.915, 0.151, 0.096, 0.124, 0.0,   2.1,  None,        None, ""),        # low hips / glutes
    (0.950, 0.148, 0.096, 0.132, 0.0,   2.2,  None,        None, ""),        # hips
    (1.005, 0.138, 0.093, 0.110, 0.0,   2.2,  None,        None, ""),        # belly
    (1.060, 0.130, 0.092, 0.088, 0.0,   2.2,  None,        None, "waist"),
    (1.110, 0.139, 0.098, 0.090, 0.0,   2.2,  None,        None, ""),
    (1.160, 0.150, 0.106, 0.095, 0.0,   2.2,  None,        None, ""),        # lower ribs
    (1.205, 0.163, 0.113, 0.100, 0.0,   2.25, None,        None, ""),
    (1.250, 0.175, 0.120, 0.104, 0.0,   2.3,  None,        None, ""),        # chest
    (1.310, 0.176, 0.124, 0.106, 0.0,   2.3,  None,        None, "sock"),    # shoulder socket rows ...
    (1.345, 0.178, 0.122, 0.105, 0.0,   2.3,  zf(0.006),   None, "sock"),
    (1.378, 0.178, 0.116, 0.103, 0.0,   2.3,  zf(0.014),   None, "sock"),
    (1.415, 0.172, 0.106, 0.099, 0.0,   2.3,  zf(0.024),   None, "sock"),
    (1.452, 0.160, 0.094, 0.092, 0.005, 2.2,  zf(0.033),   None, "sock"),    # ... shoulder top
    (1.480, 0.120, 0.074, 0.078, 0.010, 2.2,  zf(0.024, 0.015), None, ""),   # trapezius
    (1.497, 0.086, 0.062, 0.066, 0.012, 2.1,  zf(0.023, 0.020), None, ""),
    (1.510, 0.064, 0.057, 0.056, 0.014, 2.0,  zf(0.020, 0.025), None, "neck"),   # neck base
    (1.532, 0.059, 0.055, 0.050, 0.015, 2.0,  cosz(-0.010), None, ""),
    (1.553, 0.056, 0.054, 0.044, 0.015, 2.0,  cosz(-0.020), None, ""),       # neck top
    (1.585, 0.060, 0.080, 0.072, 0.0,   2.3,  cosz(-0.012), None, ""),       # under the jaw
    (1.606, 0.068, 0.095, 0.084, 0.0,   2.4,  cosz(-0.006), None, ""),       # jaw
    (1.640, 0.074, 0.101, 0.088, 0.0,   2.3,  None,        None, ""),        # mouth
    (1.660, 0.077, 0.101, 0.093, 0.0,   2.25, None,        None, ""),
    (1.680, 0.078, 0.100, 0.097, 0.0,   2.2,  None,        None, ""),        # eyes
    (1.700, 0.079, 0.101, 0.099, 0.0,   2.2,  None,        None, ""),
    (1.720, 0.079, 0.102, 0.100, 0.0,   2.2,  None,        None, ""),        # brow
] + HEAD_TOP
# village woman: wide hips, narrow waist, soft bust, sloping shoulders with no trapezius hump, longer slim neck
FEMALE_RINGS = [
    (0.875, 0.165, 0.098, 0.125, 0.0,   2.0,  CROTCHZ,     None, ""),
    (0.915, 0.174, 0.099, 0.140, 0.0,   2.1,  None,        None, ""),
    (0.950, 0.178, 0.100, 0.150, 0.0,   2.2,  None,        None, ""),        # hips / glutes
    (1.010, 0.148, 0.093, 0.114, 0.0,   2.2,  None,        None, ""),
    (1.070, 0.118, 0.085, 0.078, 0.0,   2.2,  None,        None, "waist"),
    (1.115, 0.124, 0.090, 0.083, 0.0,   2.2,  None,        None, ""),
    (1.160, 0.132, 0.095, 0.088, 0.0,   2.2,  None,        None, ""),        # lower ribs
    (1.220, 0.145, 0.103, 0.091, 0.0,   2.3,  None,        bust(0.0, 0.004, 0.004, 0.0), ""),       # under-bust crease
    (1.250, 0.149, 0.105, 0.092, 0.0,   2.3,  None,        bust(-0.008, -0.022, -0.022, -0.008), ""),
    (1.280, 0.152, 0.107, 0.093, 0.0,   2.3,  None,        bust(-0.024, -0.052, -0.052, -0.028), ""),
    (1.310, 0.155, 0.108, 0.094, 0.0,   2.3,  None,        bust(-0.026, -0.060, -0.060, -0.032), "sock"),
    (1.332, 0.157, 0.107, 0.094, 0.0,   2.3,  zf(0.004),   bust(-0.020, -0.048, -0.048, -0.024), "sock"),
    (1.355, 0.158, 0.104, 0.093, 0.0,   2.3,  zf(0.008),   bust(-0.014, -0.036, -0.036, -0.016), "sock"),
    (1.404, 0.153, 0.095, 0.090, 0.0,   2.3,  zf(0.018),   bust(-0.002, -0.008, -0.008, 0.0), "sock"),
    (1.452, 0.138, 0.083, 0.083, 0.005, 2.2,  zf(0.014),   None, "sock"),
    (1.480, 0.100, 0.066, 0.068, 0.010, 2.2,  zf(0.010, 0.010), None, ""),
    (1.497, 0.076, 0.058, 0.060, 0.012, 2.1,  zf(0.014, 0.012), None, ""),
    (1.510, 0.055, 0.050, 0.050, 0.014, 2.0,  zf(0.012, 0.015), None, "neck"),
    (1.532, 0.052, 0.049, 0.045, 0.015, 2.0,  cosz(-0.010), None, ""),
    (1.553, 0.049, 0.048, 0.040, 0.015, 2.0,  cosz(-0.020), None, ""),
    (1.585, 0.054, 0.074, 0.068, 0.0,   2.3,  cosz(-0.012), None, ""),
    (1.606, 0.062, 0.088, 0.082, 0.0,   2.3,  cosz(-0.006), None, ""),
    (1.640, 0.070, 0.098, 0.088, 0.0,   2.2,  None,        None, ""),
    (1.660, 0.073, 0.098, 0.093, 0.0,   2.2,  None,        None, ""),
    (1.680, 0.075, 0.098, 0.097, 0.0,   2.2,  None,        None, ""),
    (1.700, 0.076, 0.100, 0.099, 0.0,   2.2,  None,        None, ""),
    (1.720, 0.077, 0.101, 0.100, 0.0,   2.2,  None,        None, ""),
] + HEAD_TOP

SHOE = [(0.066, 0.026, 0.050), (0.052, 0.035, 0.088), (0.030, 0.040, 0.112), (-0.030, 0.042, 0.116),
        (-0.075, 0.046, 0.088), (-0.125, 0.051, 0.062), (-0.172, 0.048, 0.050), (-0.207, 0.032, 0.036)]

CFG = {
    "male": dict(rings=MALE_RINGS, scale=1.0, head_dz=0.012, sho=(0.176, 1.40),
                 legs=[(0.090, 0.000, 0.76, 0.095, 0.098), (0.094, -0.008, 0.66, 0.088, 0.088), (0.097, -0.010, 0.56, 0.068, 0.070),
                       (0.098, -0.015, 0.495, 0.052, 0.056), (0.098, -0.006, 0.44, 0.054, 0.058), (0.096, 0.018, 0.37, 0.061, 0.068),
                       (0.097, 0.012, 0.31, 0.054, 0.060), (0.098, 0.008, 0.25, 0.046, 0.049), (0.098, 0.004, 0.17, 0.037, 0.041)],
                 foot_x=0.098, shoe=(1.0, 1.0, 1.0),
                 arm0=((0.188, 1.395), 0.072, 0.060), arm1=((0.228, 1.383), 0.070, 0.062),
                 arm=[(0.12, 0.060, 0.058), (0.19, 0.054, 0.052), (0.27, 0.042, 0.041), (0.30, 0.041, 0.042),
                      (0.36, 0.049, 0.046), (0.41, 0.044, 0.041), (0.46, 0.036, 0.034), (0.50, 0.031, 0.033), (0.545, 0.026, 0.032)],
                 hand=[(0.012, 0.021, 0.034), (0.048, 0.017, 0.043), (0.092, 0.014, 0.044)],
                 lens=(0.072, 0.080, 0.074, 0.058), finger=((0.42, 0.0095, 0.0085), (0.33, 0.0085, 0.0075), (0.25, 0.007, 0.0062)),
                 thumb=((0.024, 0.0125), (0.048, 0.0105), (0.068, 0.0085))),
    # thighs set wider apart (LEG_X of the old female), slim soft arms (no deltoid / biceps), smaller hands and feet
    "female": dict(rings=FEMALE_RINGS, scale=0.93, head_dz=0.0, sho=(0.158, 1.40),
                   legs=[(0.098, 0.000, 0.76, 0.090, 0.104), (0.096, -0.008, 0.66, 0.080, 0.092), (0.092, -0.010, 0.56, 0.064, 0.066),
                         (0.090, -0.015, 0.495, 0.048, 0.052), (0.090, -0.006, 0.44, 0.049, 0.053), (0.091, 0.016, 0.37, 0.055, 0.061),
                         (0.0915, 0.012, 0.31, 0.049, 0.054), (0.092, 0.008, 0.25, 0.041, 0.044), (0.092, 0.004, 0.17, 0.033, 0.037)],
                   foot_x=0.092, shoe=(0.93, 0.92, 0.94),
                   arm0=((0.170, 1.392), 0.054, 0.049), arm1=((0.206, 1.380), 0.049, 0.047),
                   arm=[(0.12, 0.042, 0.042), (0.19, 0.039, 0.039), (0.27, 0.034, 0.034), (0.30, 0.033, 0.034),
                        (0.36, 0.034, 0.033), (0.41, 0.031, 0.030), (0.46, 0.028, 0.027), (0.50, 0.0254, 0.0266), (0.545, 0.022, 0.026)],
                   hand=[(0.012, 0.019, 0.031), (0.046, 0.015, 0.039), (0.088, 0.0125, 0.039)],
                   lens=(0.068, 0.076, 0.070, 0.055), finger=((0.42, 0.0086, 0.0076), (0.33, 0.0077, 0.0067), (0.25, 0.0063, 0.0056)),
                   thumb=((0.022, 0.0112), (0.045, 0.0094), (0.064, 0.0076))),
}
C = CFG[CHAR]
RINGS = C["rings"]; SHO = C["sho"]

bm = bmesh.new()
PART = bm.faces.layers.int.new("part")
cur = [1]
def V(p): return bm.verts.new(Vector(p))
def face(vs):
    try: f = bm.faces.new(vs)
    except ValueError: return None
    f[PART] = cur[0]; return f
def quad(a, b, c, d): return face((a, b, c, d))
def loft(r1, r2, skip=()):
    n = len(r1); out = {}
    for i in range(n):
        if i in skip: continue
        out[i] = quad(r1[i], r1[(i + 1) % n], r2[(i + 1) % n], r2[i])
    return out
def bridge(A, B, mid=None):
    """join two closed loops of equal size, picking the rotation / direction with the shortest edges"""
    n = len(A); assert len(B) == n, (len(A), len(B))
    best = None
    for rev in (False, True):
        BB = list(reversed(B)) if rev else B
        for o in range(n):
            s = sum((A[i].co - BB[(i + o) % n].co).length for i in range(n))
            if best is None or s < best[0]: best = (s, [BB[(i + o) % n] for i in range(n)])
    B = best[1]
    if mid:
        t, push = mid
        M = [V(A[i].co.lerp(B[i].co, t) + push) for i in range(n)]
        loft(A, M); loft(M, B)
    else:
        loft(A, B)

# ---------------------------------------------------------------- torso + neck + head (rings of N)
def sring(z, w, f, b, cy=0.0, n=2.0, zfun=None, yfun=None):
    r = []
    for k in range(N):
        ph = 2*math.pi*k/N; s = math.sin(ph); c = math.cos(ph)
        x = w*math.copysign(abs(s)**(2/n), s)
        y = cy - (f if c > 0 else b)*math.copysign(abs(c)**(2/n), c) + (yfun(ph) if yfun else 0)
        r.append(V((x, y, z + (zfun(ph) if zfun else 0))))
    return r

SEAM_WAIST = next(i for i, r in enumerate(RINGS) if r[8] == "waist")
SEAM_NECK = next(i for i, r in enumerate(RINGS) if r[8] == "neck")
SOCKET = [i for i, r in enumerate(RINGS) if r[8] == "sock"]          # 5 rows of the shoulder socket
assert len(SOCKET) == 5
SOCK_COLS = (5, 6, 7)                     # +x side (k = 6 is the side); mirrored for -x
EAR_GAPS = [i for i, r in enumerate(RINGS) if 1.635 <= r[0] < 1.685]  # 3 gaps: mouth .. eye level
def part_of_gap(i): return 2 if i < SEAM_WAIST else 1 if i < SEAM_NECK else 0

T = [sring(*r[:8]) for r in RINGS]
skip_r = {SOCK_COLS[0], SOCK_COLS[1], N - SOCK_COLS[2], N - SOCK_COLS[1]}   # quads inside the two sockets
HEADF = {}
for i in range(len(T) - 1):
    cur[0] = part_of_gap(i)
    fs = loft(T[i], T[i + 1], skip=skip_r if i in SOCKET and i + 1 in SOCKET else ())
    if cur[0] == 0: HEADF.update({(i, k): f for k, f in fs.items()})
cur[0] = 0
top = V((0, 0.004, 1.809))
for k in range(N): face((T[-1][k], T[-1][(k + 1) % N], top))

# ---------------------------------------------------------------- legs + shoe-shaped feet
cur[0] = 2
crotch = V((0, 0.005, 0.815))
d0 = math.radians(ARM_DEG)
for sx in (1, -1):
    X = lambda p: (p[0]*sx, p[1], p[2])
    def ering(cx, cy, z, rx, ry):
        return [V(X((cx + rx*math.cos(2*math.pi*k/NL), cy + ry*math.sin(2*math.pi*k/NL), z))) for k in range(NL)]
    LR = [ering(*r) for r in C["legs"]]
    half = list(range(0, N // 2 + 1)) if sx == 1 else [0] + list(range(N - 1, N // 2 - 1, -1))
    loopT = [T[0][k] for k in half] + [crotch]
    bridge(loopT, LR[0], mid=(0.5, Vector((0.004*sx, 0, 0))))
    for a, b in zip(LR, LR[1:]): loft(a, b)
    # shoe: rings across the foot (perpendicular to Y): 7 top points inner -> outer, then 7 bottom points back
    TOPK = (0.78, 0.93, 1.0, 1.0, 1.0, 0.93, 0.78)
    ky, kw, kt = C["shoe"]
    def fring(y, hw, top, cx=C["foot_x"]):
        y, hw, top = y*ky, hw*kw, top*kt
        xs = [cx - hw + 2*hw*j/6 for j in range(7)]
        xs[0] += 0.08*hw; xs[6] -= 0.08*hw                     # top corners rounded in
        tr = [V(X((xs[j], y, top*TOPK[j]))) for j in range(7)]
        br = [V(X((cx - hw + 2*hw*j/6, y, 0.0 if 0 < j < 6 else 0.009))) for j in range(6, -1, -1)]
        return tr + br
    FR = [fring(*s) for s in SHOE]       # heel cap, heel, ankle back / front (socket), instep, ball, toe box, tip
    for i, (a, b) in enumerate(zip(FR, FR[1:])):
        loft(a, b, skip=range(6) if i == 2 else ())
    for r in (FR[0], FR[-1]):            # caps (heel, toe)
        for j in range(6): quad(r[j], r[j + 1], r[12 - j], r[13 - j])
    sock = [FR[2][j] for j in range(7)] + [FR[3][j] for j in range(6, -1, -1)]
    bridge(LR[-1], sock)

# ---------------------------------------------------------------- arms + hands
cur[0] = 1
for sx in (1, -1):
    d = Vector((math.cos(d0)*sx, 0, -math.sin(d0))); u = Vector((math.sin(d0)*sx, 0, math.cos(d0))); v = Vector((0, 1, 0))
    S = Vector((SHO[0]*sx, 0, SHO[1]))
    def ring_at(c, ang, ru, rv):
        a = math.radians(ang); uu = Vector((math.sin(a)*sx, 0, math.cos(a)))
        return [V(c + v*(math.cos(math.radians(165 - 30*k))*rv) + uu*(math.sin(math.radians(165 - 30*k))*ru)) for k in range(NA)]
    def aring(t, ru, rv): return ring_at(S + d*t, ARM_DEG, ru, rv)
    (x0, z0), ru0, rv0 = C["arm0"]; (x1, z1), ru1, rv1 = C["arm1"]
    AR = [ring_at(Vector((x0*sx, 0.0, z0)), 10, ru0, rv0), ring_at(Vector((x1*sx, 0.0, z1)), 28, ru1, rv1)] + \
         [aring(*a) for a in C["arm"]]
    cols = SOCK_COLS if sx == 1 else tuple(N - c for c in SOCK_COLS)
    rows = SOCKET
    c0, c1, c2 = cols
    sk = ([T[rows[0]][c] for c in (c0, c1, c2)] + [T[r][c2] for r in rows[1:]] +
          [T[rows[-1]][c] for c in (c1, c0)] + [T[r][c0] for r in reversed(rows[1:-1])])
    bridge(sk, AR[0])
    for a, b in zip(AR, AR[1:]): loft(a, b)
    # hand: 12-point rings = 5 on the back, 1 on the outer side, 5 on the palm, 1 on the thumb side
    W = S + d*0.55
    def hring(t, th, hw):
        c = W + d*t
        tr = [V(c + v*(-hw + hw*j/2) + u*(th*(1.0 if j in (1, 2, 3) else 0.65))) for j in range(5)]
        br = [V(c + v*(-hw + hw*j/2) - u*(th*(1.0 if j in (1, 2, 3) else 0.65))) for j in range(4, -1, -1)]
        return tr + [V(c + v*hw*1.06)] + br + [V(c - v*hw*1.06)]
    HR = [hring(*h) for h in C["hand"]]
    bridge(AR[-1], HR[0])
    loft(HR[0], HR[1], skip=(11,))       # thumb socket on the -v side
    loft(HR[1], HR[2])
    K = HR[2]; lens = C["lens"]; spread = (-0.10, -0.03, 0.04, 0.11)
    for i in range(4):
        base = [K[i], K[i + 1], K[9 - i], K[10 - i]]
        c = sum((b.co for b in base), Vector())/4
        prev = base; L = lens[i]
        for sgi, (fr, hw, th) in enumerate(C["finger"]):
            fd = (d - u*(0.12*(sgi + 1)) + v*spread[i]).normalized()
            fu = (u - fd*u.dot(fd)).normalized(); fv = fd.cross(fu); fv = fv if fv.dot(v) > 0 else -fv
            c = c + fd*(L*fr)
            ring = [V(c - fv*hw + fu*th), V(c + fv*hw + fu*th), V(c + fv*hw - fu*th), V(c - fv*hw - fu*th)]
            loft(prev, ring); prev = ring
        quad(*prev)
    face((K[4], K[5], K[6])); face((K[10], K[11], K[0]))     # the two side corners between the finger roots
    base = [HR[0][11], HR[0][0], HR[1][0], HR[1][11]]
    c = sum((b.co for b in base), Vector())/4
    td = (d*0.6 - v*0.6 - u*0.45).normalized()
    tu = (u - td*u.dot(td)).normalized(); tv = td.cross(tu)
    prev = base
    for dist, hw in C["thumb"]:
        cc = c + td*dist
        ring = [V(cc - tv*hw + tu*hw*0.85), V(cc + tv*hw + tu*hw*0.85), V(cc + tv*hw - tu*hw*0.85), V(cc - tv*hw - tu*hw*0.85)]
        bridge(prev, ring); prev = ring
    quad(*prev)

# ---------------------------------------------------------------- ears: a smooth lump pulled out of the head
# EARS = False (set before exec) builds the head without ears: build_accessories.py fits short hair on that,
# otherwise the scalp rays hit the ears and the hair bulges out over them
cur[0] = 0
for sx in ((1, -1) if globals().get("EARS", True) else ()):
    k = 6 if sx == 1 else N - 7
    region = [HEADF[(i, k)] for i in EAR_GAPS if (i, k) in HEADF]
    ext = bmesh.ops.extrude_face_region(bm, geom=region)
    bmesh.ops.delete(bm, geom=region, context='FACES_ONLY')   # the op keeps the original faces inside the ear
    nv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    zs = sorted({round(v_.co.z, 4) for v_ in nv}); z0, z1 = zs[0], zs[-1]
    ys = [v_.co.y for v_ in nv]; ymid = (min(ys) + max(ys))/2
    for v_ in nv:
        h = (v_.co.z - z0)/max(z1 - z0, 1e-6)            # 0 lobe .. 1 top of the ear
        back = v_.co.y > ymid
        prof = 0.55 + 0.45*math.sin(math.pi*min(h*1.15, 1.0))   # round rim: widest above the middle, no point on top
        out = (0.016 if back else 0.006)*prof              # back rim flares out, the lobe stays close
        v_.co.x += out*sx
        v_.co.y += 0.003 + 0.003*h + (0.003 if back else 0.0)   # leans back a little
        v_.co.z += 0.002*(h - 0.5)
    for f in ext["geom"]:
        if isinstance(f, bmesh.types.BMFace): f[PART] = 0
# ---------------------------------------------------------------- nose: pulled out of the 2 x 3 front quads (mouth .. eye level)
# grid of the pulled cap: rows 0..3 = z 1.64 / 1.66 / 1.68 / 1.70 (base, tip, mid bridge, bridge top),
# columns -1 / 0 / +1 = the two sides and the middle. (forward m, sideways scale) per row: middle, sides
NOSE = {0: ((0.010, 1.0), (0.004, 0.62)),   # under the tip / wings
        1: ((0.021, 1.0), (0.007, 0.60)),   # tip / wings
        2: ((0.013, 1.0), (0.003, 0.38)),   # bridge
        3: ((0.002, 1.0), (0.000, 1.00))}   # bridge top, between the eyes: no pinch (pinching made a dark notch)
NOSE_K = {"male": 1.0, "female": 0.88}[CHAR]
region = [HEADF[(i, k)] for i in EAR_GAPS for k in (N - 1, 0) if (i, k) in HEADF]
ext = bmesh.ops.extrude_face_region(bm, geom=region)
bmesh.ops.delete(bm, geom=region, context='FACES_ONLY')
nv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
zl = sorted({round(v_.co.z, 3) for v_ in nv})
for v_ in nv:
    row = min(range(len(zl)), key=lambda j: abs(zl[j] - v_.co.z))
    mid = abs(v_.co.x) < 1e-4
    fwd, sc = NOSE[row][0 if mid else 1]
    v_.co.y -= fwd*NOSE_K
    v_.co.x *= sc
for f in ext["geom"]:
    if isinstance(f, bmesh.types.BMFace): f[PART] = 0

loose = [e for e in bm.edges if not e.link_faces]           # inner edges left by the FACES_ONLY deletes
if loose: bmesh.ops.delete(bm, geom=loose, context='EDGES')

if C["head_dz"]:
    for vt in bm.verts:
        if vt.co.z > 1.572: vt.co.z -= C["head_dz"]
if C["scale"] != 1.0:
    for vt in bm.verts: vt.co *= C["scale"]
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new("Body"); bm.to_mesh(me)
nonman = sum(1 for e in bm.edges if not e.is_manifold)
bm.free()
for p in me.polygons: p.use_smooth = True
ob = bpy.data.objects.new("Body", me); bpy.context.collection.objects.link(ob)
part = me.attributes["part"].data
tris = [0, 0, 0]
for p in me.polygons: tris[part[p.index].value] += len(p.vertices) - 2
REPORT = dict(char=CHAR, faces=len(me.polygons), verts=len(me.vertices), nonmanifold=nonman, height=round(max(v.co.z for v in me.vertices), 3),
              tris_head=tris[0], tris_upper=tris[1], tris_lower=tris[2])
print("villager body", REPORT)
