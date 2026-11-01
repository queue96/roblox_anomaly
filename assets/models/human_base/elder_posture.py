# Elderly posture for an already skinned Body + HumanRig: rounded upper back, head pushed
# forward (kept upright), slight stoop, then overall scale. Mesh and rest bones are moved
# with the same function so weights stay valid. Set before exec-ing:
#   FRAME_SCALE  - scale the build was made at (female builds are 0.93), default 1.0
#   KYPHO        - forward shift (m) of the upper back at the neck base, default 0.03
#   OVERALL      - extra uniform scale (height loss), default 1.0
import bpy
from mathutils import Vector

FRAME_SCALE = globals().get("FRAME_SCALE", 1.0)
KYPHO = globals().get("KYPHO", 0.03)
OVERALL = globals().get("OVERALL", 1.0)
Z0, Z1, ZH = 1.15, 1.55, 1.62    # curve starts at mid-back, full at neck base, head translated above ZH

SHOULDER_FWD = globals().get("SHOULDER_FWD", 0.0)   # shoulders/arms rolled forward (m)

def _sm(a, b, x):
    t = max(0.0, min(1.0, (x - a)/(b - a))); return t*t*(3 - 2*t)

def posture(p):
    q = Vector(p)/FRAME_SCALE
    zc = min(max(q.z, Z0), ZH)
    s = ((zc - Z0)/(Z1 - Z0))**2
    # rounded shoulders: everything out past the chest side, from armpit up, moves forward
    rs = _sm(0.07, 0.15, abs(q.x)) * _sm(1.0, 1.30, q.z) * (1.0 - _sm(1.50, 1.56, q.z) * (1.0 - _sm(0.07, 0.15, abs(q.x))))
    q.y -= SHOULDER_FWD*rs
    q.y -= KYPHO*s                  # forward
    q.z -= KYPHO*0.35*s             # stoop lowers the top a little
    return q*FRAME_SCALE*OVERALL

body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
for v in body.data.vertices:
    v.co = posture(v.co)
body.data.update()
for o in bpy.context.view_layer.objects: o.select_set(False)
bpy.context.view_layer.objects.active = rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb = rig.data.edit_bones
orig = {b.name: (b.head.copy(), b.tail.copy(), b.roll) for b in eb}
for b in eb: b.use_connect = False
for b in eb:
    h, t, roll = orig[b.name]
    b.head = posture(h); b.tail = posture(t); b.roll = roll
for b in eb:
    if b.parent and (b.head - b.parent.tail).length < 1e-4: b.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
print("height", round(max(v.co.z for v in body.data.vertices), 3))
