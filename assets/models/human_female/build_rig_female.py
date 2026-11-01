import bpy, bmesh, math
from mathutils import Vector

ARM_DEG = 42
SHO = (0.158, 1.40)
SCALE = 0.93
LEG_X = (0.098, 0.090, 0.091, 0.092)

for n in ("HumanRig", "_fs", "_fn", "_fh", "_ff", "_fp"):
    o = bpy.data.objects.get(n)
    if o: bpy.data.objects.remove(o, do_unlink=True)

arm = bpy.data.armatures.new("HumanRig"); rig = bpy.data.objects.new("HumanRig", arm)
bpy.context.collection.objects.link(rig)
for o in bpy.context.selected_objects: o.select_set(False)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); eb = arm.edit_bones
def B(n, h, t, p=None, c=False, dfm=True):
    b = eb.new(n); b.head = Vector(h)*SCALE; b.tail = Vector(t)*SCALE; b.use_deform = dfm
    if p: b.parent = eb[p]; b.use_connect = c
    return b
B("root", (0, 0, 0), (0, 0.3, 0), dfm=False)
B("hips", (0, 0, 0.88), (0, 0, 1.05), "root")
B("spine", (0, 0, 1.05), (0, 0, 1.22), "hips", True)
B("chest", (0, 0, 1.22), (0, 0.008, 1.45), "spine", True)
B("neck", (0, 0.008, 1.45), (0, 0.012, 1.575), "chest", True)
B("head", (0, 0.012, 1.575), (0, 0.012, 1.83), "neck", True)
d0 = math.radians(ARM_DEG)
for s, sx in (("L", 1), ("R", -1)):
    X = lambda p: Vector((p[0]*sx, p[1], p[2]))
    d = Vector((math.cos(d0)*sx, 0, -math.sin(d0))); u = Vector((math.sin(d0)*sx, 0, math.cos(d0))); v = Vector((0, 1, 0))
    S = Vector((SHO[0]*sx, 0, SHO[1])); E = S + d*0.285; W = S + d*0.55; Kn = W + d*0.088
    B(f"shoulder.{s}", X((0.03, 0.0, 1.43)), S, "chest")
    B(f"upper_arm.{s}", S, E, f"shoulder.{s}", True)
    B(f"forearm.{s}", E, W, f"upper_arm.{s}", True)
    B(f"hand.{s}", W, Kn, f"forearm.{s}", True)
    lens = (0.068, 0.076, 0.070, 0.055); spread = (-0.10, -0.03, 0.04, 0.11)
    for i, fn in enumerate(("index", "middle", "ring", "pinky")):
        c = Kn + v*(-0.039 + 0.0195*i + 0.00975); par = f"hand.{s}"; conn = False
        for sgi, fr in enumerate((0.42, 0.33, 0.25)):
            fd = (d - u*(0.12*(sgi+1)) + v*spread[i]).normalized()
            nc = c + fd*(lens[i]*fr)
            if sgi == 2: nc = nc + fd*0.006
            nm = f"{fn}_{sgi+1:02d}.{s}"; B(nm, c, nc, par, conn); par = nm; conn = True; c = nc
    td = (d*0.6 - v*0.6 - u*0.45).normalized()
    tb = W + d*0.03 + v*(-0.032)
    pts = [tb - td*0.01, tb + td*0.024, tb + td*0.048, tb + td*0.074]
    par = f"hand.{s}"
    for k in range(3):
        nm = f"thumb_{k+1:02d}.{s}"; B(nm, pts[k], pts[k+1], par, k > 0); par = nm
    tx, kx, cx_, ax = LEG_X
    B(f"thigh.{s}", X((tx, 0, 0.87)), X((kx, -0.015, 0.495)), "hips")
    B(f"shin.{s}", X((kx, -0.015, 0.495)), X((ax, 0.004, 0.10)), f"thigh.{s}", True)
    B(f"foot.{s}", X((ax, 0.004, 0.10)), X((ax, -0.115, 0.025)), f"shin.{s}", True)
    B(f"toe.{s}", X((ax, -0.115, 0.025)), X((ax, -0.20, 0.02)), f"foot.{s}", True)
bpy.ops.armature.select_all(action='SELECT'); bpy.ops.armature.calculate_roll(type='GLOBAL_NEG_Y')
bpy.ops.armature.select_all(action='DESELECT')
armset = ("shoulder", "upper_arm", "forearm", "hand", "index", "middle", "ring", "pinky", "thumb")
for b in eb:
    if b.name.split(".")[0].split("_0")[0] in armset: b.select = b.select_head = b.select_tail = True
bpy.ops.armature.calculate_roll(type='GLOBAL_POS_Z')
bpy.ops.object.mode_set(mode='OBJECT'); rig.show_in_front = True

# ---- skin body ----
body = bpy.data.objects["Body"]
for o in bpy.context.selected_objects: o.select_set(False)
body.select_set(True); rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
me = body.data
# head region (incl. nose/ears) rigid to head
names = {g.index: g.name for g in body.vertex_groups}
hg = body.vertex_groups["head"]
for vt in me.vertices:
    zc = vt.co/SCALE
    if zc.z > 1.60 or (zc.z > 1.57 and zc.y < -0.03):
        for g in list(vt.groups):
            if names[g.group] != "head": body.vertex_groups[names[g.group]].remove([vt.index])
        hg.add([vt.index], 1.0, 'REPLACE')
# smooth weights around shoulders and hips
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
nbr = {vt.index: [e.other_vert(vt).index for e in vt.link_edges] for vt in bm.verts}; bm.free()
G = len(body.vertex_groups)
Wt = [[0.0]*G for _ in me.vertices]
for vt in me.vertices:
    for g in vt.groups: Wt[vt.index][g.group] = g.weight
reg = set()
for sx in (1, -1):
    for c, rad in (((SHO[0]*sx, 0, SHO[1]), 0.11), ((LEG_X[0]*sx, 0, 0.84), 0.09)):
        reg |= {vt.index for vt in me.vertices if (vt.co/SCALE - Vector(c)).length < rad}
for it in range(6):
    NW = {}
    for i in reg:
        ns = nbr[i] + [i]
        NW[i] = [sum(Wt[j][g] for j in ns)/len(ns) for g in range(G)]
    for i, w in NW.items():
        sm = sum(w) or 1; Wt[i] = [x/sm for x in w]
for i in reg:
    for g in range(G):
        if Wt[i][g] > 0.01: body.vertex_groups[g].add([i], Wt[i][g], 'REPLACE')
        else: body.vertex_groups[g].remove([i])
# shoulder cap: blend upper_arm -> shoulder along the arm axis so the deltoid rolls down with the arm
def smooth01(a, b, x):
    t = max(0.0, min(1.0, (x - a)/(b - a))); return t*t*(3 - 2*t)
for s, sx in (("L", 1), ("R", -1)):
    ua = body.vertex_groups[f"upper_arm.{s}"]; sh = body.vertex_groups[f"shoulder.{s}"]
    Sw = Vector((SHO[0]*sx, 0, SHO[1]))*SCALE
    dw = Vector((math.cos(d0)*sx, 0, -math.sin(d0)))
    for vt in me.vertices:
        p = vt.co
        if p.x*sx < 0.075*SCALE: continue
        t = (p - Sw).dot(dw)
        if t < -0.07 or t > 0.12: continue
        radial = ((p - Sw) - dw*t).length
        if radial > 0.10: continue
        w = smooth01(-0.05, 0.08, t)
        # keep influence of other bones (chest/neck) only on the torso side
        for g in list(vt.groups):
            if body.vertex_groups[g.group].name not in (f"upper_arm.{s}", f"shoulder.{s}"):
                body.vertex_groups[g.group].remove([vt.index])
        ua.add([vt.index], w, 'REPLACE'); sh.add([vt.index], 1.0 - w, 'REPLACE')
# knees/elbows: smooth weights across the joint + dual-quaternion deform so creases keep volume
for m in body.modifiers:
    if m.type == 'ARMATURE': m.use_deform_preserve_volume = True
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
nbr = {vt.index: [e.other_vert(vt).index for e in vt.link_edges] for vt in bm.verts}; bm.free()
G = len(body.vertex_groups)
Wt = [[0.0]*G for _ in me.vertices]
for vt in me.vertices:
    for g in vt.groups: Wt[vt.index][g.group] = g.weight
reg = set()
for s_ in "LR":
    for bn in (f"shin.{s_}", f"forearm.{s_}"):
        c = rig.data.bones[bn].head_local
        reg |= {vt.index for vt in me.vertices if (vt.co - c).length < 0.07}
for it in range(4):
    NW = {i: [sum(Wt[j][g] for j in nbr[i] + [i])/(len(nbr[i]) + 1) for g in range(G)] for i in reg}
    for i, w in NW.items():
        sm = sum(w) or 1; Wt[i] = [x/sm for x in w]
for i in reg:
    for g in range(G):
        if Wt[i][g] > 0.01: body.vertex_groups[g].add([i], Wt[i][g], 'REPLACE')
        else: body.vertex_groups[g].remove([i])
# glutes: keep the buttock mass on the pelvis so it doesn't swing forward with the thigh when sitting
_S = globals().get("SCALE", 1.0)
def _sm(a, b, x):
    t = max(0.0, min(1.0, (x - a)/(b - a))); return t*t*(3 - 2*t)
hipg = body.vertex_groups["hips"]
for vt in me.vertices:
    p = vt.co/_S
    if abs(p.x) > 0.22 or p.z < 0.66 or p.z > 0.97 or p.y < -0.01: continue
    side = "L" if p.x > 0 else "R"
    tg = body.vertex_groups[f"thigh.{side}"]
    try: wt = tg.weight(vt.index)
    except RuntimeError: continue
    f = _sm(0.68, 0.84, p.z) * _sm(-0.01, 0.05, p.y) * 0.85
    if f <= 0: continue
    move = wt*f
    tg.add([vt.index], wt - move, 'REPLACE')
    try: wh = hipg.weight(vt.index)
    except RuntimeError: wh = 0.0
    hipg.add([vt.index], wh + move, 'REPLACE')
print("bones", len(arm.bones), "unweighted", sum(1 for vt in me.vertices if sum(g.weight for g in vt.groups) < 1e-4))

# ---- hair rigid to head (only if a Hair object exists) ----
hair = bpy.data.objects.get("Hair")
if hair:
    for m in list(hair.modifiers): hair.modifiers.remove(m)
    if "head" not in hair.vertex_groups:
        hair.vertex_groups.new(name="head").add(range(len(hair.data.vertices)), 1.0, 'REPLACE')
    hair.parent = rig; hair.modifiers.new("Armature", 'ARMATURE').object = rig
