# Shadow ghost behind the banyan (เงาหลังต้นไทร, ghost_shadow) on the Villager v2 male body — user 2026-11-15 "แก้เลย"
#   "D:\blender-5.2.4\blender.exe" -b --factory-startup --python assets/models/villager/build_shadow_v2.py
# The old one (AnomalyProps.BanyanShadowAnomaly) was a black box + ball + 2 eye cubes: no bones, could only tilt as a block.
# This one is a rigged person-shaped silhouette (same 52-bone HumanRig as the villagers, so mocap clips like tani_peek play
# on it): the v2 male body, no clothes / face / hair — flat matte black in game (MeshPart colour, no textures to upload) —
# plus two small pale eyes bound to the head bone (Eyes, Neon in game).
# Output: assets/models/ShadowGhostV2/upload/ghost_shadow.fbx · preview + .blend in assets/models/ShadowGhostV2/
import bpy, bmesh, os, sys, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MODELS = os.path.dirname(HERE)
SDIR = os.path.join(MODELS, "ShadowGhostV2"); UP = os.path.join(SDIR, "upload")
for d in (SDIR, UP):
    os.makedirs(d, exist_ok=True)
from export_ghosts_v2 import split_body

log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print("SHADOW|", *a)

EYE_Z, EYE_X, EYE_Y = 1.686, 0.031, -0.097      # male body eye line (build_child_v2 / face_landmarks numbers)

def flat_mat(name, col, rough=0.9, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*col, 1); b.inputs["Emission Strength"].default_value = emit
    return m

def build():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_male.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    for o in list(bpy.data.objects):
        if o.name not in ("Body", "HumanRig") and o.type in ("MESH", "CURVE", "EMPTY", "LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)
    split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    black = flat_mat("ShadowBlack", (0.004, 0.004, 0.005), rough=0.95)
    for n in ("BodyHead", "BodyUpper", "BodyLower"):
        ob = bpy.data.objects[n]; ob.data.materials.clear(); ob.data.materials.append(black)
        for p in ob.data.polygons: p.material_index = 0
    # eyes: two flat glowing almonds just in front of the eye line, weighted 100% to the head bone
    bm = bmesh.new()
    for sx in (1, -1):
        r = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
        for v in r["verts"]:
            v.co = Vector((sx*EYE_X + v.co.x*0.0105, EYE_Y - 0.004 + v.co.y*0.003, EYE_Z + v.co.z*0.0055))
    me = bpy.data.meshes.new("Eyes"); bm.to_mesh(me); bm.free()
    eyes = bpy.data.objects.new("Eyes", me); bpy.context.scene.collection.objects.link(eyes)
    eyes.data.materials.append(flat_mat("ShadowEye", (0.92, 0.94, 0.86), rough=0.3, emit=3.0))
    vg = eyes.vertex_groups.new(name="head"); vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
    eyes.parent = rig
    md = eyes.modifiers.new("Armature", "ARMATURE"); md.object = rig
    for p in me.polygons: p.use_smooth = True
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    L("tris", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SDIR, "ghost_shadow.blend"))
    for f in os.listdir(UP):
        os.remove(os.path.join(UP, f))
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(UP, "ghost_shadow.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=3.5,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
        mesh_smooth_type='FACE', path_mode='STRIP', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    L("exported", path, "meshes", sorted(o.name for o in meshes))
    return rig

def preview(rig):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.06, 0.08, 1)
    l = bpy.data.objects.new("_moon", bpy.data.lights.new("_moon", 'SUN')); l.data.energy = 0.6; l.data.color = (0.7, 0.8, 1.0)
    l.rotation_euler = (math.radians(60), 0, math.radians(-40)); sc.collection.objects.link(l)
    # a tree trunk to peek from (preview only)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.42, depth=3.2, location=(0.42, 0.25, 1.6))
    trunk = bpy.context.active_object; trunk.data.materials.append(flat_mat("_bark", (0.06, 0.05, 0.04), rough=1))
    # pose: lean out to the left of the trunk, head tilted (roughly what tani_peek does in game)
    for bn, rot in (("spine", (0, -8, 10)), ("chest", (0, -6, 12)), ("neck", (8, 0, 10)), ("head", (6, 12, 18)),
                    ("upper_arm.R", (0, 0, -30)), ("forearm.R", (0, 0, -20))):
        pb = rig.pose.bones.get(bn)
        if pb:
            pb.rotation_mode = "XYZ"; pb.rotation_euler = tuple(math.radians(v) for v in rot)
    bpy.context.view_layer.update()
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    imgs = []
    for tgt, d, lens, res in (((0.1, 0, 1.0), (0.15, -1, 0.05), 35, (420, 560)), ((-0.05, 0, 1.68), (0.15, -1, 0.02), 85, (420, 560))):
        sc.render.resolution_x, sc.render.resolution_y = res
        cam.data.lens = lens
        t = Vector(tgt); dist = 4.2 if lens == 35 else 1.2
        cam.location = t + Vector(d).normalized()*dist
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        p = os.path.join(SDIR, "_tmp.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        imgs.append(a.reshape(im.size[1], im.size[0], 4).copy()); bpy.data.images.remove(im); os.remove(p)
    sheet = np.concatenate(imgs, 1)
    img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.join(SDIR, "ghost_shadow_preview.png"); img.file_format = 'PNG'; img.save()
    L("preview", img.filepath_raw)

if __name__ == "__main__":
    try:
        rig = build()
        preview(rig)
        L("DONE")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(SDIR, "build_report.txt"), "w", encoding="utf-8").write("\n".join(log))
