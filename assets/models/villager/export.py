# Villager v2 -> Roblox FBX (first Studio test): one file per character in assets/models/villager/upload/
#   blender -b --factory-startup --python export.py -- [male|female]
# Pieces (MeshParts after import), all bound to the same 52-bone HumanRig:
#   BodyHead / BodyUpper / BodyLower   the Body cut along its seam rings (part attribute), whole-body normals kept
#                                      so no shading seam shows where they meet
#   LowerWide / LowerSkirt              the other lower bodies (swap with BodyLower)
#   Hair_<style>, Hat_ngob, Sash_pakama the accessories (swap / add)
# Each piece carries ONE test character's textures (TEST below), and EXTRA adds carrier cards for the remaining
# painted outfits/heads so one FBX import uploads every SurfaceAppearance needed in game.
import bpy, bmesh, os, sys, json, time, traceback
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)); TEX = os.path.join(HERE, "textures"); UP = os.path.join(HERE, "upload")
os.makedirs(UP, exist_ok=True)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CHAR = "female" if "female" in argv else "male"
STUDS_PER_M = 3.5
TEST = {"male": dict(BodyHead="male_male_head", BodyUpper="m_farmer_upper", BodyLower="m_farmer_lower",
                     LowerWide="m_redshirt_lower", LowerSkirt="m_elder_lower"),
        "female": dict(BodyHead="female_female_head", BodyUpper="f_blouse_upper", BodyLower="f_indigo_lower",
                       LowerWide="f_tee_lower", LowerSkirt="f_blouse_lower")}[CHAR]
EXTRA = [("Tex_male_elder_head", "male_elder_male_head"),
         ("Tex_m_redshirt_upper", "m_redshirt_upper"),
         ("Tex_m_teen_upper", "m_teen_upper"),
         ("Tex_m_teen_lower", "m_teen_lower"),
         ("Tex_m_elder_upper", "m_elder_upper"),
         ("Tex_female_elder_head", "female_elder_female_head"),
         ("Tex_f_indigo_upper", "f_indigo_upper"),
         ("Tex_f_tee_upper", "f_tee_upper"),
         ("Tex_f_elder_upper", "f_elder_upper"),
         ("Tex_f_elder_lower", "f_elder_lower")]
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

def tex_material(name, base):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def t(sfx, nc):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(os.path.join(TEX, base + sfx + ".png"), check_existing=True)
        if nc: n.image.colorspace_settings.name = "Non-Color"
        return n
    nt.links.new(t("_Color", False).outputs["Color"], b.inputs["Base Color"])      # alpha left unconnected: it is the tint mask
    nt.links.new(t("_Roughness", True).outputs["Color"], b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t("_Normal", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def split_body(body):
    """BodyHead / BodyUpper / BodyLower with the whole body's corner normals"""
    me = body.data; pa = me.attributes["part"].data
    def key(co, c): return (round(co.x, 5), round(co.y, 5), round(co.z, 5), round(c.x, 5), round(c.y, 5), round(c.z, 5))
    nrm = {}
    for p in me.polygons:
        for li in p.loop_indices: nrm[key(me.vertices[me.loops[li].vertex_index].co, p.center)] = me.corner_normals[li].vector.copy()
    pieces = []
    for k, name in enumerate(("BodyHead", "BodyUpper", "BodyLower")):
        ob = body.copy(); ob.data = me.copy(); ob.name = name; ob.data.name = name
        for c in body.users_collection: c.objects.link(ob)
        bm = bmesh.new(); bm.from_mesh(ob.data); lay = bm.faces.layers.int.get("part")
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[lay] != k], context='FACES'); bm.to_mesh(ob.data); bm.free()
        pm = ob.data
        pm.normals_split_custom_set([nrm[key(pm.vertices[pm.loops[li].vertex_index].co, p.center)] for p in pm.polygons for li in p.loop_indices])
        pieces.append(ob)
    return pieces

def fbx(path, **kw):
    for attempt in range(6):
        try: return bpy.ops.export_scene.fbx(filepath=path, **kw)
        except RuntimeError as e:
            if ("Errno 22" not in str(e) and "Errno 13" not in str(e)) or attempt == 5: raise
            time.sleep(1.5*(attempt + 1))

try:
    if "textures" in argv or "heads" in argv:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        items = [("Tex_male_head", "male_male_head"),
                 ("Tex_male_elder_head", "male_elder_male_head"),
                 ("Tex_female_head", "female_female_head"),
                 ("Tex_female_elder_head", "female_elder_female_head")] if "heads" in argv else EXTRA
        cards = []
        for idx, (cname, base) in enumerate(items):
            me = bpy.data.meshes.new(cname)
            x0 = idx * 0.15
            me.from_pydata([(x0, 0, 0), (x0 + 0.1, 0, 0), (x0 + 0.1, 0, 0.1)], [], [(0, 1, 2)])
            lay = me.uv_layers.new(name="UVMap")
            for li, uv in enumerate(((0, 0), (1, 0), (1, 1))): lay.data[li].uv = uv
            me.materials.append(tex_material(cname, base))
            ob = bpy.data.objects.new(cname, me); bpy.context.scene.collection.objects.link(ob)
            ob.select_set(True); cards.append(ob)
        bpy.context.view_layer.objects.active = cards[0]
        fname = "villager_heads.fbx" if "heads" in argv else "villager_textures.fbx"
        path = os.path.join(UP, fname)
        fbx(path, use_selection=True, object_types={'MESH'}, global_scale=STUDS_PER_M,
            apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
            mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False)
        import shutil, re
        data = open(path, "rb").read()
        for n in sorted(set(m.decode("latin1") for m in re.findall(rb"[\w\-]+\.png", data))):
            src = os.path.join(TEX, n)
            if os.path.exists(src): shutil.copyfile(src, os.path.join(UP, n))
        shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
        L("exported", path, len(cards), "cards")
        sys.exit(0)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    for o in list(bpy.data.objects):
        if o.name.startswith("_"): bpy.data.objects.remove(o, do_unlink=True)
    pieces = split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    ren = {"Lower_wide": "LowerWide", "Lower_skirt": "LowerSkirt"}
    for a, b in ren.items():
        if a in bpy.data.objects: bpy.data.objects[a].name = b
    for name, base in TEST.items():
        ob = bpy.data.objects[name]; ob.data.materials.clear(); ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
    for o in meshes: o.hide_viewport = False; o.hide_set(False); o.hide_render = False
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(UP, f"villager_{CHAR}.fbx")
    fbx(path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=STUDS_PER_M,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
        mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    L("exported", path)
    # the FBX names its textures without a folder: put the PNGs right next to it (where the 3D Importer looks)
    import shutil, re
    data = open(path, "rb").read()
    for n in sorted(set(m.decode("latin1") for m in re.findall(rb"[\w\-]+\.png", data))):
        src = os.path.join(TEX, n) if os.path.exists(os.path.join(TEX, n)) else os.path.join(os.path.dirname(HERE), "clothes_tex", n)
        shutil.copyfile(src, os.path.join(UP, n))
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
    for o in sorted(meshes, key=lambda o: o.name):
        L(f"  {o.name:22s} tris {sum(len(p.vertices) - 2 for p in o.data.polygons):5d}  material {o.data.materials[0].name if o.data.materials else '-'}")
    # ---- check: import it back into an empty scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arm = [o for o in bpy.data.objects if o.type == 'ARMATURE']; ms = [o for o in bpy.data.objects if o.type == 'MESH']
    zs = [(o.matrix_world @ v.co).z for o in ms if o.name.startswith("Body") for v in o.data.vertices]
    maxinf = max(len([g for g in v.groups if g.weight > 1e-4]) for o in ms for v in o.data.vertices)
    imgs = sorted({i.name for i in bpy.data.images})
    L(f"re-import: {len(ms)} meshes, armatures {len(arm)}, bones {len(arm[0].data.bones) if arm else 0}, "
      f"body height {max(zs) - min(zs):.2f} (scene units; x0.01 in the 3D Importer = studs), max bones per vertex {maxinf}")
    L("textures referenced:", len(imgs))
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)      # the check import unpacks a .fbm folder: not needed
    L("files in upload/:", len(os.listdir(UP)))
except Exception:
    L(traceback.format_exc())
open(os.path.join(HERE, f"export_{CHAR}_report.txt"), "w", encoding="utf-8").write("\n".join(log))
