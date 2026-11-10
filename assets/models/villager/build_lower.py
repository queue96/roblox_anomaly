# Villager v2: lower-body variants that REPLACE the lower part (never layered over legs, so nothing can poke through).
#   blender -b --factory-startup --python build_lower.py -- [male|female] [--save] [--render <out_dir>]
# Opens villager_<char>.blend (rigged Body). Adds, bound to HumanRig with the same vertex groups:
#   Lower_wide   wide long trousers: the legs themselves pushed out from the leg bones (more towards the hem)
#   Lower_skirt  sin (women) / sarong (men): a tube from the waist ring down to the hem, with NO legs inside;
#                only the shins + shoes below the hem are kept. Weights: hips at the waist easing into the legs at
#                the hem, each side following its own leg, the front / back blending from one leg to the other
# The default "short / bare legs" lower is the Body's own lower part (part 2).
# Both reuse the Body's waist ring exactly (same places, same weights), so they meet the upper part without a gap.
import bpy, bmesh, os, sys, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CHAR = "female" if "female" in argv else "male"
SC = {"male": 1.0, "female": 0.93}[CHAR]
HEM = {"male": 0.20, "female": 0.15}[CHAR]          # skirt hem height (m, male scale): sarong mid-shin, sin to the ankle
LEG_BONES = ("thigh", "shin")
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

def part_faces(me, k):
    a = me.attributes["part"].data
    return [p.index for p in me.polygons if a[p.index].value == k]

def waist_ring(me):
    a = me.attributes["part"].data
    up, lo = set(), set()
    for p in me.polygons:
        (lo if a[p.index].value == 2 else up if a[p.index].value == 1 else set()).update(p.vertices)
    ring = sorted(up & lo, key=lambda i: math.atan2(me.vertices[i].co.x, -me.vertices[i].co.y))
    return ring

def weights_of(ob):
    names = [g.name for g in ob.vertex_groups]
    W = np.zeros((len(ob.data.vertices), len(names)), np.float32)
    for v in ob.data.vertices:
        for g in v.groups: W[v.index, g.group] = g.weight
    return names, W

def new_object(name, bm, names, W, rig):
    me = bpy.data.meshes.new(name); bm.to_mesh(me)
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    vg = [ob.vertex_groups.new(name=n) for n in names]
    for i in range(len(me.vertices)):
        ws = [(g, w) for g, w in enumerate(W[i]) if w > 1e-4]
        ws = sorted(ws, key=lambda t: -t[1])[:4]; tot = sum(w for _, w in ws) or 1.0     # Roblox: at most 4 bones
        for g, w in ws: vg[g].add([i], w/tot, 'REPLACE')
    ob.parent = rig
    m = ob.modifiers.new("Armature", 'ARMATURE'); m.object = rig; m.use_deform_preserve_volume = True
    return ob

def sub_bmesh(me, faces):
    """bmesh with only these faces; returns (bm, original vertex index per new vertex)"""
    bm = bmesh.new(); vmap = {}; order = []
    for fi in faces:
        for v in me.polygons[fi].vertices:
            if v not in vmap: vmap[v] = bm.verts.new(me.vertices[v].co); order.append(v)
    for fi in faces: bm.faces.new([vmap[v] for v in me.polygons[fi].vertices])
    return bm, order, vmap

def build_wide(body, rig):
    me = body.data; names, W = weights_of(body)
    faces = part_faces(me, 2)
    bm, order, vmap = sub_bmesh(me, faces)
    waist = set(waist_ring(me)); zw = max(me.vertices[i].co.z for i in waist)
    inv = rig.matrix_world
    seg = {}
    for sd in ("L", "R"):
        seg[sd] = (inv @ rig.data.bones["thigh." + sd].head_local, inv @ rig.data.bones["shin." + sd].tail_local)
    crotch, ankle, shoe_top = 0.87*SC, 0.17*SC, 0.125*SC
    gi = {n: i for i, n in enumerate(names)}
    for nv, oi in zip(bm.verts, order):
        if oi in waist: continue
        p = nv.co
        if p.z < shoe_top: continue                                      # shoes stay as they are
        sd = "L" if p.x > 0 else "R"
        a, b = seg[sd]; ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab)/ab.length_squared))
        r = p - (a + ab*t); r.z = 0
        if r.length < 1e-6: continue
        h = max(0.0, min(1.0, (crotch - p.z)/(crotch - ankle)))           # 0 at the crotch .. 1 at the ankle
        top = max(0.0, min(1.0, (zw - p.z)/(zw - 0.95*SC)))               # 0 on the waist ring .. 1 at the hips
        ramp = top*top*(3 - 2*top)
        nv.co = p + r.normalized()*(0.007 + 0.030*h**1.3)*ramp*SC
    Wn = W[order]
    return new_object("Lower_wide", bm, names, Wn, rig)

def build_skirt(body, rig):
    me = body.data; names, W = weights_of(body); gi = {n: i for i, n in enumerate(names)}
    lower = part_faces(me, 2)
    lv = sorted({v for f in lower for v in me.polygons[f].vertices})
    P = np.array([tuple(me.vertices[i].co) for i in lv])
    ring = waist_ring(me); zw = float(np.mean([me.vertices[i].co.z for i in ring]))
    ang = [math.atan2(me.vertices[i].co.x, -me.vertices[i].co.y) for i in ring]
    dirs = np.array([(math.sin(a), -math.cos(a)) for a in ang])
    hem = HEM*SC; crotch = 0.875*SC
    zs = [zw - 0.03*SC, zw - 0.06*SC, 0.975*SC, 0.95*SC, 0.915*SC, crotch, 0.82*SC, 0.76*SC, 0.68*SC, 0.60*SC,
          0.52*SC, 0.44*SC, 0.36*SC, 0.28*SC]
    zs = [z for z in zs if hem + 0.02*SC < z < zw - 0.01*SC] + [hem]
    rings, prev = [], None
    for z in zs:
        win = 0.035*SC                                                   # leg rings are 5-10 cm apart: widen until it has points
        sl = P[np.abs(P[:, 2] - z) < win]
        while len(sl) < 8:
            win *= 1.5; sl = P[np.abs(P[:, 2] - z) < win]
        sup = (sl[:, :2] @ dirs.T).max(0)                               # convex outline of the hips / both legs
        clear = (0.010 + 0.012*min(1.0, max(0.0, (zw - z)/(zw - crotch))))*SC
        rad = sup + clear
        if prev is not None and z < crotch: rad = np.maximum(rad, prev)  # below the crotch the cloth falls straight
        prev = rad
        rings.append((z, rad))
    bm = bmesh.new(); TUBE = bm.faces.layers.int.new("tube")     # 1 = the cloth tube (+ hem lip), 0 = shins / shoes
    Wrows = []
    top = [bm.verts.new(me.vertices[i].co) for i in ring]
    Wrows += [W[i] for i in ring]
    def tube_w(x, z):
        t = max(0.0, min(1.0, (zw - z)/(zw - hem))); leg = t**1.1
        sl = 0.5 + 0.5*max(-1.0, min(1.0, x/(0.10*SC)))                # 1 = left leg .. 0 = right leg
        sl = sl*sl*(3 - 2*sl)
        sh = 0.85*max(0.0, min(1.0, (0.50*SC - z)/(0.50*SC - hem)))      # below the knee part goes to the shin
        w = np.zeros(len(names), np.float32)
        w[gi["hips"]] = 1 - leg
        for sd, f in (("L", sl), ("R", 1 - sl)):
            w[gi["thigh." + sd]] += leg*f*(1 - sh); w[gi["shin." + sd]] += leg*f*sh
        return w
    prev_ring = top
    for z, rad in rings:
        cur = []
        for k in range(len(ring)):
            x, y = dirs[k]*rad[k]
            cur.append(bm.verts.new((x, y, z))); Wrows.append(tube_w(x, z))
        for k in range(len(ring)):
            k2 = (k + 1) % len(ring)
            bm.faces.new((prev_ring[k], prev_ring[k2], cur[k2], cur[k]))[TUBE] = 1
        prev_ring = cur
    lip = []                                                            # hem folded back up inside: the cloth has a thickness
    for k, v in enumerate(prev_ring):
        p = v.co; lip.append(bm.verts.new((p.x*0.94, p.y*0.94, p.z + 0.014*SC))); Wrows.append(tube_w(p.x, p.z))
    for k in range(len(ring)):
        k2 = (k + 1) % len(ring)
        bm.faces.new((prev_ring[k2], prev_ring[k], lip[k], lip[k2]))[TUBE] = 1
    # shins + shoes under the hem (copied from the body with their weights)
    keep = [f for f in lower if all(me.vertices[v].co.z < hem + 0.07*SC for v in me.polygons[f].vertices)]
    vmap = {}
    for f in keep:
        for v in me.polygons[f].vertices:
            if v not in vmap: vmap[v] = bm.verts.new(me.vertices[v].co); Wrows.append(W[v])
        bm.faces.new([vmap[v] for v in me.polygons[f].vertices])
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces])
    ob = new_object("Lower_skirt", bm, names, np.array(Wrows), rig)
    L("skirt rings", len(rings), "hem", round(hem, 3), "shin/shoe faces", len(keep), "max radius", round(float(max(r.max() for _, r in rings)), 3))
    return ob

try:
    if bpy.data.filepath == "" or not bpy.data.filepath.endswith(f"villager_{CHAR}.blend"):
        bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
    for n in ("Lower_wide", "Lower_skirt"):
        o = bpy.data.objects.get(n)
        if o: bpy.data.objects.remove(o, do_unlink=True)
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    wide = build_wide(body, rig); skirt = build_skirt(body, rig)
    for o in (wide, skirt):
        L(o.name, "faces", len(o.data.polygons), "verts", len(o.data.vertices),
          "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
    wr = waist_ring(body.data)
    L("waist ring verts", len(wr))
    if "--save" in argv:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_mainfile()
        L("saved", bpy.data.filepath)
except Exception:
    L(traceback.format_exc())
LOWER_REPORT = "\n".join(log)
