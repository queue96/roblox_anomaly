# Pregnancy shape for an already skinned adult female Body + HumanRig.
# The abdomen expands as a smooth, rounded volume in front and across both flanks,
# while keeping limbs and the rest of the torso at the normal female proportions.
import bpy
from mathutils import Vector

body = bpy.data.objects["Body"]
rig = bpy.data.objects["HumanRig"]
me = body.data
bones = {b.name: b for b in rig.data.bones if b.use_deform}
gname = {g.index: g.name for g in body.vertex_groups}
height = max(v.co.z for v in me.vertices)

s = height / 1.8
zc = bones["hips"].head_local.z - 0.02*s
zr = bones["chest"].head_local.z
span = zr - zc
cy = bones["spine"].head_local.y
torso = {"hips", "spine", "chest"}
mask = {}

for v in me.vertices:
    wt = sum(g.weight for g in v.groups if gname[g.group] in torso)
    dy = v.co.y - cy
    if wt <= 0.05 or dy >= 0:
        continue
    rad = Vector((v.co.x, dy, 0)).length
    if rad < 1e-6:
        continue
    u = (v.co.z - zc) / span
    # A high, gently tapered oval: rounded pregnancy belly, not a low hanging fold.
    p = 2.718**(-((u - 0.52) / 0.32)**2)
    front = (-dy / rad)**0.70
    side = (abs(v.co.x) / rad)**0.75
    # Blend the front and flank pushes continuously.  Giving the side rings a little
    # forward carry removes the boxy transition between the profile and front views.
    v.co.y -= 0.18*s*p*(0.38 + 0.62*front)*wt
    v.co.x += 0.095*s*p*side*wt*(1 if v.co.x >= 0 else -1)
    mask[v.index] = min(1.0, 3.6*p*max(front, 0.65*side)*wt)

# Pregnancy also makes the breasts fuller.  Two overlapping smooth lobes keep a
# natural central separation rather than looking like a single raised chest plate.
chest_z = bones["chest"].head_local.z
neck_z = bones["neck"].head_local.z
breast_z = chest_z + 0.60*(neck_z - chest_z)
breast_x = 0.078*s
for v in me.vertices:
    wt = sum(g.weight for g in v.groups if gname[g.group] in {"spine", "chest"})
    dy = v.co.y - cy
    if wt <= 0.05 or dy >= 0:
        continue
    front = max(0.0, -dy / max(Vector((v.co.x, dy, 0)).length, 1e-6))
    lobe = 0.0
    for sx in (-1, 1):
        dx = (v.co.x - sx*breast_x) / (0.072*s)
        dz = (v.co.z - breast_z) / (0.090*s)
        lobe = max(lobe, 2.718**(-(dx*dx + dz*dz)))
    if lobe <= 0.01:
        continue
    v.co.y -= 0.100*s*lobe*front*wt
    v.co.x += 0.012*s*lobe*wt*(1 if v.co.x >= 0 else -1)
    mask[v.index] = max(mask.get(v.index, 0.0), min(1.0, 2.8*lobe*wt))

# Taubin smooth the full added volume, including both sides, without shrinking it.
nb = {v.index: [] for v in me.vertices}
for e in me.edges:
    a, b = e.vertices
    nb[a].append(b)
    nb[b].append(a)
co = {i: me.vertices[i].co.copy() for i in nb}
for _ in range(20):
    for f in (0.5, -0.53):
        new = {}
        for i, m in mask.items():
            avg = sum((co[j] for j in nb[i]), Vector()) / len(nb[i])
            new[i] = co[i] + (avg - co[i])*f*m
        co.update(new)
for i in mask:
    me.vertices[i].co = co[i]

print(f"pregnancy belly and bust verts {len(mask)}")
