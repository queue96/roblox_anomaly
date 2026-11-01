# Soften the places where body parts meet, on an already skinned Body + HumanRig:
#   - nape / back of the skull (the occiput shelf used to fold into a sharp crease)
#   - every joint area, found from the skin weights (vertices shared by 2+ bones)
# Taubin smoothing (shrink + inflate) keeps volume; hands, feet, ears and nose are left alone.
# Vertex order is unchanged, so skin weights stay valid.
import bpy, bmesh
from mathutils import Vector

ITER = globals().get("SMOOTH_ITER", 8)
LAM, MU = 0.50, -0.53
SKIP = ("hand", "index", "middle", "ring", "pinky", "thumb", "foot", "toe")

body = bpy.data.objects["Body"]; me = body.data
gname = {g.index: g.name for g in body.vertex_groups}
bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
# small islands (nose, ears) are excluded
seen = set(); comp = {}
for v in bm.verts:
    if v.index in seen: continue
    stack = [v]; ids = []
    while stack:
        x = stack.pop()
        if x.index in seen: continue
        seen.add(x.index); ids.append(x.index)
        stack.extend(e.other_vert(x) for e in x.link_edges)
    for i in ids: comp[i] = len(ids)
nbr = [[e.other_vert(v).index for e in v.link_edges] for v in bm.verts]
bm.free()

mask = []
for v in me.vertices:
    ws = {gname[g.group]: g.weight for g in v.groups if g.weight > 0}
    if comp[v.index] < 100 or any(n.split(".")[0].split("_")[0] in SKIP and w > 0.3 for n, w in ws.items()):
        mask.append(0.0); continue
    top = max(ws.values()) if ws else 1.0
    m = min(1.0, (1.0 - top)*2.0)                       # joints: mixed weights
    if "neck" in ws: m = max(m, 0.9)                     # whole neck incl. where it meets skull/shoulders
    mask.append(m)
# grow the nape mask one ring into the back of the skull
for _ in range(2):
    grown = list(mask)
    for i, v in enumerate(me.vertices):
        if mask[i] == 0 and comp[i] >= 100 and v.co.y > 0.0:
            ns = [mask[j] for j in nbr[i]]
            if ns and max(ns) >= 0.9 and not any(gname[g.group].split(".")[0] in SKIP for g in v.groups):
                grown[i] = 0.6
    mask = grown

co = [v.co.copy() for v in me.vertices]
for it in range(ITER):
    for f in (LAM, MU):
        new = []
        for i, p in enumerate(co):
            if mask[i] <= 0 or not nbr[i]: new.append(p); continue
            avg = sum((co[j] for j in nbr[i]), Vector()) / len(nbr[i])
            new.append(p + (avg - p)*f*mask[i])
        co = new
for v, p in zip(me.vertices, co): v.co = p
me.update()
print("smoothed verts", sum(1 for m in mask if m > 0))
