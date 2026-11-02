# Body-type variant for an already skinned Body + HumanRig (any age/sex).
# Every vertex is pushed toward / away from the bones that move it (weighted blend of the
# closest points on those bones), so skin weights stay valid. Set before exec-ing:
#   BODY_TYPE = "thin"  - starved: wasted limbs with knobby joints, sunken belly, scrawny neck
#   BODY_TYPE = "fat"   - obese: pot belly, thick limbs, double chin, legs set wider apart
import bpy, math
from mathutils import Vector
from mathutils.geometry import intersect_point_line

BODY_TYPE = globals().get("BODY_TYPE", "thin")

# bone base name: (side, front, back) radial factors
TABLE = {
    "thin": {
        "hips": (0.74, 0.55, 0.62), "spine": (0.66, 0.25, 0.85), "chest": (0.94, 0.92, 0.95),
        "neck": (0.58, 0.62, 0.62), "head": (0.90, 0.95, 0.98), "shoulder": (0.72, 0.72, 0.72),
        "upper_arm": (0.46,) * 3, "forearm": (0.52,) * 3, "hand": (0.86,) * 3, "finger": (0.85,) * 3,
        "thigh": (0.46,) * 3, "shin": (0.52,) * 3, "foot": (0.90,) * 3, "toe": (0.95,) * 3,
    },
    "fat": {
        # belly front is kept modest here; the hanging belly is added by belly_sag() below
        "hips": (1.22, 1.20, 1.40), "spine": (1.45, 1.40, 1.30), "chest": (1.25, 1.35, 1.20),
        "neck": (1.40, 1.60, 1.40), "head": (1.07, 1.06, 1.03), "shoulder": (1.25,) * 3,
        "upper_arm": (1.55,) * 3, "forearm": (1.32,) * 3, "hand": (1.12,) * 3, "finger": (1.15,) * 3,
        "thigh": (1.40,) * 3, "shin": (1.30,) * 3, "foot": (1.28,) * 3, "toe": (1.12,) * 3,
    },
}[BODY_TYPE]
# per-character tweaks, e.g. TYPE_OVERRIDES = {"shin": (1.5,)*3}; BELLY = (forward, droop) multipliers
for _k, _v in globals().get("TYPE_OVERRIDES", {}).items(): TABLE[_k] = _v
BELLY = globals().get("BELLY", (1.0, 1.0))
# armpit: smoothing radius (x height/1.8) and how much the arm underside stays slim;
# smaller = a defined armpit crease where the arm meets the torso
ARMPIT_R = globals().get("ARMPIT_R", 0.10)
ARM_UNDER = globals().get("ARM_UNDER", 0.45)
APEX_ITER = globals().get("APEX_ITER", 6)   # armpit pocket fill (0 = off)
KNOBBY = globals().get("KNOBBY", 0.55)       # thin: how much knees / elbows keep their size (0 = slim evenly)
GAUNT = globals().get("GAUNT", 0.10)         # thin: hollow cheeks
ARM_SAG = globals().get("ARM_SAG", 0.0)      # fat: soft upper arm hanging under (flab), mid upper arm
LIMB = {"upper_arm", "forearm", "thigh", "shin"}
INNER_DAMP = {"thigh": 0.40, "shin": 0.10}   # 0 = inner side grows like the outer side

def base_of(name):
    b = name.split(".")[0]
    if b.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb"): return "finger"
    return b

body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; me = body.data
bones = {b.name: b for b in rig.data.bones if b.use_deform}
gname = {g.index: g.name for g in body.vertex_groups}
height = max(v.co.z for v in me.vertices)

def factor(bname, off, t):
    side, front, back = TABLE[base_of(bname)]
    n = off.normalized() if off.length > 1e-6 else Vector((0, 0, 0))
    k = side + (front - side)*max(0.0, -n.y) + (back - side)*max(0.0, n.y)
    if base_of(bname) in LIMB:
        # joints stay closer to their size: knobby knees/elbows when thin, dimpled when fat
        # (thin only: a fat knee stays as thick as the leg, or the leg pinches and looks bowed)
        j = max(0.0, 1.0 - min(t, 1.0 - t)/0.18)
        k = k + (1.0 - k)*(KNOBBY if BODY_TYPE == "thin" else 0.10)*j
    if BODY_TYPE == "fat" and base_of(bname) in ("thigh", "shin"):
        # legs grow all round; the inner side a bit less so the thighs meet instead of fusing
        inward = max(0.0, -n.x if bname.endswith(".L") else n.x)
        k = k - (k - 1.0)*INNER_DAMP[base_of(bname)]*inward
    if BODY_TYPE == "fat" and base_of(bname) == "upper_arm":
        # underside of a fat upper arm near the shoulder grows less, so it doesn't dig into the
        # torso and leave a dark fold at the armpit
        under = max(0.0, -n.z)
        a = max(0.0, 1.0 - t/0.45)
        k = k - (k - 1.0)*ARM_UNDER*a*under
        k = k + ARM_SAG*max(0.0, -n.z)*math.sin(math.pi*min(max(t, 0.0), 1.0))
    if BODY_TYPE == "fat" and base_of(bname) == "shin":
        # taper the fat calf down into a slimmer ankle instead of a column ending in a pinch
        a = max(0.0, min(1.0, (t - 0.55)/0.45)); a = a*a*(3 - 2*a)
        k = k*(1 - a) + 1.22*a
    if BODY_TYPE == "thin" and base_of(bname) == "head":
        # hollow cheeks / gaunt jaw
        k = k - GAUNT*max(0.0, 1.0 - t/0.4)
    if BODY_TYPE == "fat" and base_of(bname) == "head":
        # jowls / double chin: lower face widens more than the skull
        lo = max(0.0, 1.0 - t/0.35)
        k = k + 0.22*lo
    return k

new = []
for v in me.vertices:
    acc = Vector((0, 0, 0)); wsum = 0.0
    for g in v.groups:
        b = bones.get(gname[g.group])
        if b is None or g.weight <= 0: continue
        cp, t = intersect_point_line(v.co, b.head_local, b.tail_local)
        t = max(0.0, min(1.0, t)); cp = b.head_local.lerp(b.tail_local, t)
        off = v.co - cp
        acc += (cp + off*factor(b.name, off, t))*g.weight; wsum += g.weight
    new.append(acc/wsum if wsum > 0 else v.co.copy())
for v, p in zip(me.vertices, new): v.co = p

def belly_sag():
    # Obese belly hangs: the mass sits low, fills out to both sides, bulges forward
    # and droops over the groin.  The side fill is kept independent of the forward
    # bulge so a profile and a front view both read as a round, heavy abdomen.
    s = height/1.8
    zc = bones["hips"].head_local.z - 0.03*s          # groin
    zr = bones["chest"].head_local.z                  # bottom of the ribcage
    span = zr - zc
    torso = {"hips", "spine", "chest"}
    cy = bones["spine"].head_local.y                  # torso axis (elders lean forward)
    amt, droop = BELLY
    mask = {}
    for v in me.vertices:
        wt = sum(g.weight for g in v.groups if gname[g.group] in torso)
        dy = v.co.y - cy
        if wt <= 0.05 or dy >= 0: continue
        rad = Vector((v.co.x, dy, 0)).length
        if rad < 1e-6: continue
        front = (-dy/rad)**0.6                        # wide, round front instead of a point
        side = (abs(v.co.x)/rad)**0.7                 # carry the belly mass onto both flanks
        u = (v.co.z - zc)/span
        peak = 0.34
        sig = 0.20 if u < peak else 0.48              # firmer fold below, long slope above
        p = 2.718**(-((u - peak)/sig)**2)
        w = p*front*wt
        v.co.x += 0.12*s*amt*p*side*wt*(1 if v.co.x >= 0 else -1)  # left/right fullness
        v.co.y -= 0.20*s*amt*w                        # forward
        v.co.z -= 0.065*s*amt*droop*w*(1.0 if u > peak - 0.1 else 0.4)   # droop
        # Smooth the flanks too: without including this side expansion in the mask,
        # the extra width follows the low-poly rings and reads as a hard corner.
        mask[v.index] = min(1.0, 3.0*p*max(front, 0.55*side)*wt)
    # Round the whole belly volume off (Taubin: smooth without shrinking).
    nb = {v.index: [] for v in me.vertices}
    for e in me.edges:
        a, b = e.vertices; nb[a].append(b); nb[b].append(a)
    co = {i: me.vertices[i].co.copy() for i in nb}
    for _ in range(12):
        for f in (0.5, -0.53):
            new = {}
            for i, m in mask.items():
                avg = sum((co[j] for j in nb[i]), Vector())/len(nb[i])
                new[i] = co[i] + (avg - co[i])*f*m
            co.update(new)
    for i in mask: me.vertices[i].co = co[i]

def straighten_legs(iters=20):
    # Fat legs: the base mesh has a calf bulge and a narrow knee, which inflated reads as
    # bowed legs. Taubin-smooth the thigh/shin skin so the outline becomes a straight taper.
    nb = {v.index: [] for v in me.vertices}
    for e in me.edges:
        a, b = e.vertices; nb[a].append(b); nb[b].append(a)
    mask = {}
    for v in me.vertices:
        w = sum(g.weight for g in v.groups if base_of(gname[g.group]) in ("thigh", "shin"))
        wf = sum(g.weight for g in v.groups if base_of(gname[g.group]) in ("foot", "toe", "hips", "spine"))
        if w > 0.3 and wf < 0.3: mask[v.index] = min(1.0, w)
    co = {i: me.vertices[i].co.copy() for i in nb}
    for _ in range(iters):
        for f in (0.5, -0.53):
            new = {}
            for i, m in mask.items():
                avg = sum((co[j] for j in nb[i]), Vector())/len(nb[i])
                d = (avg - co[i])*f*m
                d.z *= 0.3                     # keep ring heights, smooth the outline
                new[i] = co[i] + d
            co.update(new)
    for i in mask: me.vertices[i].co = co[i]

def round_armpits(iters=22):
    # The inflated torso side ends in a corner right under the arm socket (a step between
    # chest and armpit). Smooth that patch so torso, armpit and arm flow into each other.
    s = height/1.8
    nb = {v.index: [] for v in me.vertices}
    for e in me.edges:
        a, b = e.vertices; nb[a].append(b); nb[b].append(a)
    mask = {}
    spots = [(bones[f"upper_arm.{sd}"].head_local - Vector((0, 0, 0.05*s)), ARMPIT_R*s) for sd in "LR"]
    spots.append((bones["neck"].head_local, 0.10*s))      # neck base / trapezius crease
    for c, R in spots:
        for v in me.vertices:
            d = (v.co - c).length
            if d < R and nb[v.index]: mask[v.index] = max(mask.get(v.index, 0.0), 1.0 - (d/R)**2)
    # torso side under the arm: let the ribcage flare smoothly into the belly (no shelf)
    arm_w = lambda v: sum(g.weight for g in v.groups if base_of(gname[g.group]) in ("upper_arm", "forearm", "hand", "finger"))
    for sd in "LR":
        c = bones[f"upper_arm.{sd}"].head_local - Vector((0, 0, 0.16*s))
        R = 0.14*s
        for v in me.vertices:
            d = (v.co - c).length
            if d < R and nb[v.index] and arm_w(v) < 0.7 and v.co.x*c.x > 0:
                mask[v.index] = max(mask.get(v.index, 0.0), (1.0 - (d/R)**2)*(1.0 - arm_w(v)))
    co = {i: me.vertices[i].co.copy() for i in nb}
    # armpit apex: a small pocket sits above a lip of torso; plain Laplacian (shrinking on
    # purpose) over that spot fills the pocket and pulls the lip in, so the torso side runs
    # straight down from the armpit
    apex = {}
    for sd in "LR":
        c = bones[f"upper_arm.{sd}"].head_local - Vector((0, 0, 0.13*s))
        R = 0.10*s
        for v in me.vertices:
            d = (v.co - c).length
            if d < R and nb[v.index]: apex[v.index] = 1.0 - (d/R)**2
    for _ in range(APEX_ITER):
        new = {}
        for i, m in apex.items():
            avg = sum((co[j] for j in nb[i]), Vector())/len(nb[i])
            new[i] = co[i] + (avg - co[i])*0.5*m
        co.update(new)
    for _ in range(iters):
        for f in (0.5, -0.53):
            new = {}
            for i, m in mask.items():
                avg = sum((co[j] for j in nb[i]), Vector())/len(nb[i])
                new[i] = co[i] + (avg - co[i])*f*m
            co.update(new)
    for i in set(mask) | set(apex): me.vertices[i].co = co[i]

if BODY_TYPE == "fat":
    belly_sag()
    straighten_legs()
    round_armpits()

# obese people stand with legs further apart: shift each leg chain outward
if BODY_TYPE == "fat":
    dx = 0.022*height/1.8
    leg = {"thigh", "shin", "foot", "toe"}
    for v in me.vertices:
        # side comes from which leg moves the vertex, not from where it sits
        wL = sum(g.weight for g in v.groups if base_of(gname[g.group]) in leg and gname[g.group].endswith(".L"))
        wR = sum(g.weight for g in v.groups if base_of(gname[g.group]) in leg and gname[g.group].endswith(".R"))
        v.co.x += dx*(min(1.0, wL) - min(1.0, wR))
    for o in bpy.context.view_layer.objects: o.select_set(False)
    bpy.context.view_layer.objects.active = rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    ebs = [b for b in rig.data.edit_bones if base_of(b.name) in leg]
    conn = {b.name: b.use_connect for b in ebs}
    for b in ebs: b.use_connect = False     # connected children would drag parents' tails twice
    for b in ebs:
        s = 1 if b.name.endswith(".L") else -1
        b.head.x += s*dx; b.tail.x += s*dx
    for b in ebs: b.use_connect = conn[b.name]
    bpy.ops.object.mode_set(mode='OBJECT')
me.update()
print("body type", BODY_TYPE, "height", round(height, 3))
