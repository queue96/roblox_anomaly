# Turn the adult-frame child build (already skinned) into child proportions by moving
# mesh vertices and rest bones with the same function, so weights stay valid:
#   1. head enlarged around the neck (big head, ~5.5 heads tall)
#   2. legs shortened (crotch lower relative to height)
#   3. whole figure scaled to TARGET_H
import bpy
from mathutils import Vector

HEAD_SCALE = 1.40
HEAD_PIVOT = Vector((0.0, 0.010, 1.52))
HEAD_BLEND = (1.52, 1.60)     # neck below stays, head above fully scaled
HEAD_DROP = 0.035             # pull the big head down = short neck
CROTCH = 0.875
LEG_K = 0.86                  # leg length factor
TARGET_H = 1.15

def _sm(a, b, x):
    t = max(0.0, min(1.0, (x - a)/(b - a))); return t*t*(3 - 2*t)

def remap(p, scale=1.0):
    p = Vector(p)
    t = _sm(HEAD_BLEND[0], HEAD_BLEND[1], p.z)
    q = HEAD_PIVOT + (p - HEAD_PIVOT)*(1 + (HEAD_SCALE - 1)*t) if t > 0 else p.copy()
    q.z -= HEAD_DROP*_sm(1.50, 1.56, p.z)
    if q.z < CROTCH: q.z *= LEG_K
    else: q.z -= CROTCH*(1 - LEG_K)
    return q*scale

body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
top = max(remap(v.co).z for v in body.data.vertices)
SCALE = TARGET_H/top
for v in body.data.vertices:
    v.co = remap(v.co, SCALE)
body.data.update()

for o in bpy.context.view_layer.objects: o.select_set(False)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = rig.data.edit_bones
orig = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in eb}
for b in eb: b.use_connect = False          # move ends independently
for b in eb:
    h, t, roll = orig[b.name]
    b.head = remap(h, SCALE); b.tail = remap(t, SCALE); b.roll = roll
for b in eb:
    if b.parent and (b.head - b.parent.tail).length < 1e-4: b.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
print("child height", round(TARGET_H, 3), "scale", round(SCALE, 3))
