# Wider weight smoothing around both armpits of a skinned Body + HumanRig, so the front of
# the armpit doesn't get pulled two ways (chest vs. upper arm) and collapse into a hole
# when the arms are lowered. Shared by every character and body type.
import bpy, bmesh
from mathutils import Vector

RAD = globals().get("ARMPIT_RAD", 0.09)
ITER = globals().get("ARMPIT_ITER", 8)

body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; me = body.data
h = max(v.co.z for v in me.vertices)
rad = RAD*h/1.8
reg = set()
for s in "LR":
    c = rig.data.bones[f"upper_arm.{s}"].head_local - Vector((0, 0, 0.035*h/1.8))
    reg |= {v.index for v in me.vertices if (v.co - c).length < rad}
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
nbr = {v.index: [e.other_vert(v).index for e in v.link_edges] for v in bm.verts}; bm.free()
G = len(body.vertex_groups)
W = [[0.0]*G for _ in me.vertices]
for v in me.vertices:
    for g in v.groups: W[v.index][g.group] = g.weight
for _ in range(ITER):
    NW = {i: [sum(W[j][g] for j in nbr[i] + [i])/(len(nbr[i]) + 1) for g in range(G)] for i in reg}
    for i, w in NW.items():
        sm = sum(w) or 1; W[i] = [x/sm for x in w]
for i in reg:
    for g in range(G):
        if W[i][g] > 0.01: body.vertex_groups[g].add([i], W[i][g], 'REPLACE')
        else: body.vertex_groups[g].remove([i])
print("armpit verts", len(reg))
