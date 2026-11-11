# Render preview sheet of the upgraded Villager v2 Ghosts with 100% painted clothes (ZERO Cloth_* torso/skirt meshes!)
import bpy, bmesh, os, sys, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MODELS = os.path.dirname(HERE)
GH = os.path.join(MODELS, "human_ghosts")
TEX = os.path.join(HERE, "textures")
OUT = os.path.join(HERE, "design")
from export_ghosts_v2 import push_outside_v2

def tex_mat(name, folder, base):
    m = bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def t(sfx, nc):
        p = os.path.join(folder, base + sfx + ".png")
        if not os.path.exists(p): return None
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(p, check_existing=True)
        if nc: n.image.colorspace_settings.name = "Non-Color"
        return n
    c = t("_Color", False); r = t("_Roughness", True); nm_t = t("_Normal", True)
    if c: nt.links.new(c.outputs["Color"], b.inputs["Base Color"])
    if r: nt.links.new(r.outputs["Color"], b.inputs["Roughness"])
    if nm_t:
        nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(nm_t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def setup_render():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.20, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    for n, rot, e in (("_key", (55, 0, -30), 3.0), ("_fill", (70, 0, 55), 1.2), ("_back", (60, 0, 170), 1.0)):
        l = bpy.data.objects.new(n, bpy.data.lights.new(n, 'SUN')); l.data.energy = e
        l.rotation_euler = tuple(math.radians(v) for v in rot); sc.collection.objects.link(l)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    return cam

def shot(cam, tgt, d, ortho, res):
    sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = res
    d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
    p = os.path.join(OUT, "_tmp_g.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr

def save_sheet(arr, path):
    img = bpy.data.images.new("s", arr.shape[1], arr.shape[0]); img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)

def render_lineup():
    cols = []
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_female.blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; sk_ob = bpy.data.objects["Lower_skirt"]
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    t_skirt = BVHTree.FromPolygons([sk_ob.matrix_world @ v.co for v in sk_ob.data.vertices], [list(p.vertices) for p in sk_ob.data.polygons])
    zn = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    btop = body.copy(); btop.data = body.data.copy(); bpy.context.scene.collection.objects.link(btop); btop.name = "_BodyTop"
    bm = bmesh.new(); bm.from_mesh(btop.data); lay = bm.faces.layers.int.get("part")
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[lay] == 2], context='FACES'); bm.to_mesh(btop.data); bm.free()
    for o in bpy.data.objects:
        if o.type == 'MESH': o.hide_render = o not in (btop, sk_ob)
    cam = setup_render()
    with bpy.data.libraries.load(os.path.join(MODELS, "mocap", "out", "human_female_mocap.blend")) as (src, dst):
        dst.actions = ["idle"]
    act = dst.actions[0]
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
        for c in pb.constraints: c.mute = True
    if not rig.animation_data: rig.animation_data_create()
    rig.animation_data.action = act
    try: rig.animation_data.action_slot = act.slots[0]
    except Exception: pass
    bpy.context.scene.frame_set(int(act.frame_range[0] + 20)); bpy.context.view_layer.update()
    H = 1.82 * 0.93
    for htex, utex, ltex, prop_blend, prop_objs in (
        ("g_female_ghost_head",    "g_tani_upper",      "g_tani_lower",      "ghost_mirror.blend",        ["Hair_ghost_long"]),
        ("g_female_ghost_head",    "g_thai_upper",      "g_thai_lower",      "ghost_mirror.blend",        ["Hair_ghost_long"]),
        ("g_female_ghost_head",    "g_nak_upper",       "g_nak_lower",       "ghost_mae_nak.blend",       ["Prop_Baby", "Hair_ghost_long"]),
        ("g_female_dancer_head",   "g_dancer_upper",    "g_dancer_lower",    "ghost_dancer.blend",        ["Cloth_ghost_dancer_crown", "Cloth_ghost_dancer_flowers"]),
        ("g_female_withered_head", "g_funeral_f_upper", "g_funeral_f_lower", "ghost_funeral_woman.blend", ["Hair_ghost_messy"]),
        ("g_female_pop_head",      "g_pop_upper",       "g_pop_lower",       None,                        ["Pop_Hair", "Pop_Eyes", "Pop_Fangs", "Pop_Tongue"]),
    ):
        mh = tex_mat("MH", TEX, htex); mu = tex_mat("MU", TEX, utex); ml = tex_mat("ML", TEX, ltex)
        btop.data.materials.clear(); btop.data.materials.append(mh); btop.data.materials.append(mu)
        pa = btop.data.attributes["part"].data
        for p in btop.data.polygons: p.material_index = pa[p.index].value
        sk_ob.data.materials.clear(); sk_ob.data.materials.append(ml)
        temp_objs = []
        bpath = os.path.join(GH, prop_blend) if prop_blend else os.path.join(MODELS, "pop.blend")
        for oname in prop_objs:
            with bpy.data.libraries.load(bpath, link=False) as (src, dst):
                if oname in src.objects: dst.objects = [oname]
            for ob in dst.objects:
                if not ob: continue
                bpy.context.scene.collection.objects.link(ob)
                for m in ob.modifiers:
                    if m.type == 'ARMATURE': m.object = rig
                if oname == "Pop_Eyes":
                    for v in ob.data.vertices: v.co.y -= 0.0115
                elif oname in ("Pop_Fangs", "Pop_Tongue"):
                    for v in ob.data.vertices: v.co.y -= 0.004
                elif oname.startswith(("Hair_", "Pop_Hair")):
                    push_outside_v2(ob, [t_body, t_skirt], clear=0.0040, z_max=zn)
                ob.hide_render = False
                temp_objs.append(ob)
        cols.append(shot(cam, (0, 0, H*0.5), (0.35, -0.94, 0.06), H*1.06, (280, 520)))
        for ob in temp_objs:
            bpy.data.objects.remove(ob, do_unlink=True)
    save_sheet(np.concatenate(cols, 1), os.path.join(OUT, "ghosts_v2_lineup_painted.png"))

if __name__ == "__main__":
    render_lineup()
