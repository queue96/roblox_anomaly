import bpy, math, sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0]
ACTION = argv[1] if len(argv) > 1 else "Lunge"
FRAC = float(argv[2]) if len(argv) > 2 else 0.6

scn = bpy.context.scene
rig = bpy.data.objects["KrasueRig"]
mesh = bpy.data.objects["Krasue"]
# mute rig constraints (exported clips ignore them; previews must too)
for pb in rig.pose.bones:
    for c in pb.constraints:
        c.mute = True
act = bpy.data.actions.get(ACTION)
if act:
    rig.animation_data_create()
    rig.animation_data.action = act
    try:
        slot = act.slots[0]
        rig.animation_data.action_slot = slot
    except Exception:
        pass
    f0, f1 = act.frame_range
    scn.frame_set(int(f0 + (f1 - f0) * FRAC))
bpy.context.view_layer.update()

head = None
for name in ("Head", "head", "Neck"):
    if name in rig.pose.bones:
        head = rig.pose.bones[name]
        break
hpos = rig.matrix_world @ (head.head + (head.tail - head.head) * 0.5) if head else Vector((0, -0.05, -0.02))
print("HEADPOS", tuple(round(x, 3) for x in hpos), "bones", [b.name for b in rig.pose.bones][:20])

# dark world
w = scn.world or bpy.data.worlds.new("W")
scn.world = w
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.025, 0.002, 0.002, 1)
bg.inputs[1].default_value = 1.0
for o in list(bpy.data.objects):
    if o.type == "LIGHT":
        bpy.data.objects.remove(o, do_unlink=True)


def light(kind, loc, color, energy, size=0.2):
    ld = bpy.data.lights.new(kind, kind)
    ld.color = color
    ld.energy = energy
    ld.shadow_soft_size = size
    o = bpy.data.objects.new(kind, ld)
    o.location = Vector(loc)
    d = hpos - o.location
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(o)
    return o


# under-light (flashlight from below), red rim behind, faint cold fill
light("SPOT", hpos + Vector((0.05, -0.55, -0.35)), (0.70, 0.86, 1.0), 13.0, 0.05).data.spot_size = math.radians(55)
light("POINT", hpos + Vector((0.25, 0.35, 0.15)), (1.0, 0.12, 0.05), 14.0)
light("POINT", hpos + Vector((-0.35, 0.3, 0.05)), (0.9, 0.1, 0.05), 10.0)
light("POINT", hpos + Vector((-0.3, -0.4, 0.25)), (0.35, 0.45, 0.6), 2.0)

cam = bpy.data.objects["cam"]
cam.location = hpos + Vector((0.10, -1.55, -0.16))
cam.rotation_euler = (hpos + Vector((0, 0, -0.11)) - cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.lens = 95
cam.constraints.clear()
cam.parent = None
cam.data.type = "PERSP"
scn.camera = cam

scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x = 768
scn.render.resolution_y = 1024
scn.render.resolution_percentage = 100
scn.render.film_transparent = False
scn.view_settings.view_transform = "AgX"
try:
    scn.view_settings.look = "AgX - High Contrast"
except Exception:
    pass
scn.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("WROTE", OUT)
