# Pose HumanRig into extreme poses (joint limits clamp them) and report faces of
# different body parts that intersect each other. Run after add_joint_limits.py.
import bpy, math
from mathutils.bvhtree import BVHTree

rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
pb = rig.pose.bones
gname = {g.index: g.name for g in body.vertex_groups}

def region_of(bone):
    base, _, s = bone.partition(".")
    if base in ("hips", "spine", "chest"): return "torso"
    if base in ("neck", "head"): return "head"
    if base in ("shoulder",): return None
    if base == "upper_arm": return "uarm." + s
    if base in ("forearm",): return "farm." + s
    if base == "hand" or base.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb"): return "hand." + s
    if base == "thigh": return "thigh." + s
    if base in ("shin",): return "shin." + s
    if base in ("foot", "toe"): return "foot." + s
    return None

me = body.data
vreg = []
for v in me.vertices:
    best = max(v.groups, key=lambda g: g.weight, default=None)
    vreg.append(region_of(gname[best.group]) if best and best.weight > 0.8 else None)
freg = {}
for p in me.polygons:
    rs = {vreg[i] for i in p.vertices}
    if len(rs) == 1 and None not in rs: freg[p.index] = rs.pop()

PAIRS = [("uarm.L", "torso"), ("uarm.R", "torso"), ("farm.L", "torso"), ("farm.R", "torso"),
         ("hand.L", "torso"), ("hand.R", "torso"), ("hand.L", "head"), ("hand.R", "head"),
         ("farm.L", "head"), ("farm.R", "head"),
         ("hand.L", "thigh.L"), ("hand.R", "thigh.R"), ("farm.L", "thigh.L"), ("farm.R", "thigh.R"),
         ("thigh.L", "thigh.R"), ("shin.L", "shin.R"), ("foot.L", "foot.R"), ("shin.L", "thigh.R"), ("shin.R", "thigh.L"),
         ("thigh.L", "torso"), ("thigh.R", "torso"), ("shin.L", "thigh.L"), ("shin.R", "thigh.R"),
         ("head", "torso"), ("farm.L", "uarm.L"), ("farm.R", "uarm.R"),
         ("hand.L", "hand.R"), ("farm.L", "farm.R")]

TOL = 0.015   # skin may squash into skin up to 1.5 cm; deeper counts as passing through

def check(label):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    em = body.evaluated_get(dg).to_mesh()
    verts = [body.matrix_world @ v.co for v in em.vertices]
    polys = {}
    for p in em.polygons:
        r = freg.get(p.index)
        if r: polys.setdefault(r, []).append(list(p.vertices))
    trees = {r: BVHTree.FromPolygons(verts, ps) for r, ps in polys.items()}
    rverts = {r: {i for p in ps for i in p} for r, ps in polys.items()}
    def depth(a, b):
        # deepest vertex of region a that sits behind the surface of region b
        worst = 0.0
        for i in rverts[a]:
            hitb = trees[b].find_nearest(verts[i], 0.06)
            if hitb[0] is None: continue
            loc, nrm, _, dist = hitb
            if (verts[i] - loc).dot(nrm) < 0: worst = max(worst, dist)
        return worst
    hits = []
    for a, b in PAIRS:
        if a in trees and b in trees and trees[a].overlap(trees[b]):
            dmax = max(depth(a, b), depth(b, a))
            if dmax > TOL: hits.append(f"{a}x{b}:{dmax*100:.1f}cm")
    body.evaluated_get(dg).to_mesh_clear()
    print(f"{label:28s}", "OK" if not hits else " ".join(hits))
    return hits

def reset():
    for b in pb:
        b.rotation_mode = 'XYZ'; b.rotation_euler = (0, 0, 0)

def R(name, x=0, y=0, z=0, mirror=True):
    pb[name].rotation_euler = [math.radians(a) for a in (x, y, z)]
    if mirror and name.endswith(".L"):
        zz = -z if name.split(".")[0] in ("shoulder", "upper_arm", "forearm", "hand", "thigh", "foot") \
             or name.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb") else z
        pb[name[:-2] + ".R"].rotation_euler = [math.radians(a) for a in (x, -y, zz)]

POSES = {
    "rest":              lambda: None,
    "arms down":         lambda: (R("upper_arm.L", x=-90),),
    "arms down+back":    lambda: (R("upper_arm.L", x=-90, z=60),),
    "arms down+fwd":     lambda: (R("upper_arm.L", x=-90, z=-60),),
    "arms up":           lambda: (R("upper_arm.L", x=150),),
    "elbow full bend":   lambda: (R("upper_arm.L", x=-90), R("forearm.L", z=-170)),
    "hug self":          lambda: (R("upper_arm.L", x=-20, z=-100), R("forearm.L", z=-170)),
    "hand to face":      lambda: (R("upper_arm.L", x=-30, z=-90), R("forearm.L", z=-170), R("hand.L", x=-80)),
    "arms twist":        lambda: (R("upper_arm.L", x=-90, y=90), R("forearm.L", y=90)),
    "side bend + arm":   lambda: (R("spine", z=-30, mirror=False), R("chest", z=-20, mirror=False), R("upper_arm.L", x=-90)),
    "bend fwd + arms":   lambda: (R("spine", x=40, mirror=False), R("chest", x=40, mirror=False), R("upper_arm.L", x=-90, z=-60)),
    "legs crossed":      lambda: (R("thigh.L", z=-40),),
    "legs spread":       lambda: (R("thigh.L", z=60),),
    "crouch":            lambda: (R("thigh.L", x=120), R("shin.L", x=-150), R("foot.L", x=30)),
    "kneel L":           lambda: (R("thigh.L", x=0, mirror=False), R("shin.L", x=-150, mirror=False)),
    "high kick L":       lambda: (R("thigh.L", x=120, mirror=False),),
    "leg back L":        lambda: (R("thigh.L", x=-40, mirror=False), R("shin.L", x=-150, mirror=False)),
    "fist":              lambda: [R(f"{f}_{k:02d}.L", x=-120) for f in ("index", "middle", "ring", "pinky") for k in (1, 2, 3)] + [R(f"thumb_{k:02d}.L", x=-80) for k in (1, 2, 3)],
    "chin to chest":     lambda: (R("neck", x=40, mirror=False), R("head", x=40, mirror=False)),
    "look up":           lambda: (R("neck", x=-40, mirror=False), R("head", x=-40, mirror=False)),
    "turn head":         lambda: (R("neck", y=50, mirror=False), R("head", y=60, mirror=False)),
}
fails = {}
for name, fn in POSES.items():
    reset(); fn()
    h = check(name)
    if h: fails[name] = h
reset(); bpy.context.view_layer.update()
print("FAILED POSES:", len(fails))
