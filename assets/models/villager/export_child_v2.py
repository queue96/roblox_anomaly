# Villager v2 child -> Roblox: two FBX in assets/models/ChildV2/upload/ (run build_child_v2.py first)
#   "D:\blender-5.2.4\blender.exe" -b --factory-startup --python assets/models/villager/export_child_v2.py
#   villager_child.fbx   HumanRig (old child skeleton, 52 bones) + BodyHead / BodyUpper / BodyLower / LowerSkirt / Hair_*
#                        each body piece carries one outfit's textures (TEST) so the template looks right straight after import
#   child_textures.fbx   one small carrier card per remaining texture set, so one import uploads every SurfaceAppearance;
#                        their asset ids then go into src/shared/VillagerTextures.model.json (names = the texture base names)
import bpy, os, re, shutil, sys, traceback

HERE = os.path.dirname(os.path.abspath(__file__))
CDIR = os.path.join(os.path.dirname(HERE), "ChildV2")
TEX = os.path.join(CDIR, "textures"); UP = os.path.join(CDIR, "upload")
os.makedirs(UP, exist_ok=True)
STUDS_PER_M = 3.5
TEST = dict(BodyHead="c_child_head", BodyUpper="c_mohom_upper", BodyLower="c_mohom_lower", LowerSkirt="c_girl_sin_lower")
CARDS = ["c_school_upper", "c_school_lower", "c_tee_upper", "c_tee_lower", "c_singlet_upper", "c_singlet_lower",
         "c_girl_sin_upper", "c_girl_tee_upper", "c_girl_tee_lower"]
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print("CEXP|", *a)

def tex_material(name, base):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def t(sfx, nc):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(os.path.join(TEX, base + sfx + ".png"), check_existing=True)
        if nc: n.image.colorspace_settings.name = "Non-Color"
        return n
    nt.links.new(t("_Color", False).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t("_Roughness", True).outputs["Color"], b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t("_Normal", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def copy_pngs(path):
    data = open(path, "rb").read(); n = 0
    for fn in sorted(set(x.decode("latin1") for x in re.findall(rb"[\w\-]+\.png", data))):
        src = os.path.join(TEX, fn)
        if os.path.exists(src):
            shutil.copyfile(src, os.path.join(UP, fn)); n += 1
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
    return n

try:
    for f in os.listdir(UP):
        os.remove(os.path.join(UP, f))
    # ---- character
    bpy.ops.wm.open_mainfile(filepath=os.path.join(CDIR, "villager_child.blend"))
    rig = bpy.data.objects["HumanRig"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    for o in list(bpy.data.objects):
        if o.type in ("LIGHT", "CAMERA") or o.name.startswith("_"):
            bpy.data.objects.remove(o, do_unlink=True)
    for name, base in TEST.items():
        ob = bpy.data.objects[name]; ob.data.materials.clear(); ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes: o.hide_viewport = False; o.hide_set(False); o.hide_render = False
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(UP, "villager_child.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=STUDS_PER_M,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
        mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    L("exported", path, "pngs", copy_pngs(path), "meshes", sorted(o.name for o in meshes))
    maxinf = max(len([g for g in v.groups if g.weight > 1e-4]) for o in meshes for v in o.data.vertices)
    L("max bones per vertex", maxinf, "tris", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes})
    # ---- texture carrier cards
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cards = []
    for idx, base in enumerate(CARDS):
        cname = "Tex_" + base
        me = bpy.data.meshes.new(cname); x0 = idx*0.15
        me.from_pydata([(x0, 0, 0), (x0 + 0.1, 0, 0), (x0 + 0.1, 0, 0.1)], [], [(0, 1, 2)])
        lay = me.uv_layers.new(name="UVMap")
        for li, uv in enumerate(((0, 0), (1, 0), (1, 1))): lay.data[li].uv = uv
        me.materials.append(tex_material(cname, base))
        ob = bpy.data.objects.new(cname, me); bpy.context.scene.collection.objects.link(ob); ob.select_set(True); cards.append(ob)
    bpy.context.view_layer.objects.active = cards[0]
    path = os.path.join(UP, "child_textures.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, global_scale=STUDS_PER_M,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False)
    L("exported", path, "cards", len(cards), "pngs", copy_pngs(path))
    L("files in upload/", len(os.listdir(UP)))
except Exception:
    L(traceback.format_exc())
open(os.path.join(CDIR, "export_report.txt"), "w", encoding="utf-8").write("\n".join(log))
