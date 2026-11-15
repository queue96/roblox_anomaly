# Ghost child (ผีเด็ก ghost_child) on the Villager v2 child body — user 2026-11-15 "ทำผีเด็กเลย"
#   "D:\blender-5.2.4\blender.exe" -b --python assets/models/villager/build_ghost_child_v2.py      (needs ChildV2/villager_child.blend)
# The old ghost_child was the v1 child (Body + Cloth_ghost_child meshes). This one is the child v2 (build_child_v2.py: round
# child head, old child skeleton so ghost_idle / ghost_glide still fit) with ghost textures painted on it (spec in GHOST_MODELS.md):
#   pale ghost skin + ghost face, white short-sleeve school shirt and navy shorts caked in mud with torn holes, bare muddy feet.
# Output: assets/models/GhostChildV2/upload/ghost_child_v2.fbx (+ textures) · previews in assets/models/GhostChildV2/
import bpy, os, sys, math, re, shutil, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MODELS = os.path.dirname(HERE)
GDIR = os.path.join(MODELS, "GhostChildV2")
TEX = os.path.join(GDIR, "textures"); UP = os.path.join(GDIR, "upload")
for d in (GDIR, TEX, UP):
    os.makedirs(d, exist_ok=True)

import build_ghosts_v2 as G
GRAVE_FABRIC = G.fabric                  # build_child_v2 swaps in the clean living-people fabric: keep the grave-dirty one
import build_child_v2 as C               # child look (eye size, brows, skin), painted button nose
G.fabric = GRAVE_FABRIC
sk = G.sk
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print("GCHILD|", *a)

MUD = np.array((0.24, 0.17, 0.11)); MUD_WET = np.array((0.13, 0.10, 0.07))

def mud(col, rough, P, mask, amount, seed):
    """caked mud: thick at the bottom, splashes higher up (heights in male-body metres)"""
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    n = sk["fbm"](x*14, y*14, z*14, oct=4, seed=seed)
    up = np.clip((0.40 - z)/0.38, 0, 1)                                    # more mud near the feet, splashes above
    m = mask & (n + 0.32*up*amount > 0.80)
    wet = m & (sk["fbm"](x*40, y*40, z*40, oct=2, seed=seed + 3) > 0.55)
    col = np.where(m[..., None], sk["mix"](col, MUD, 0.85), col)
    col = np.where(wet[..., None], sk["mix"](col, MUD_WET, 0.7), col)
    rough = np.where(m, 0.95, np.where(wet, 0.45, rough))
    return col, rough

def holes(col, hgt, col_skin, P, cloth, seed, k=0.83):
    """torn holes in the cloth: skin shows through with a frayed dark edge"""
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    n = sk["fbm"](x*22, y*22, z*22, oct=3, seed=seed)
    hole = cloth & (n > k)
    edge = cloth & (n > k - 0.04) & ~hole
    col = np.where(hole[..., None], col_skin*0.85, col)
    col = np.where(edge[..., None], col*0.55, col)
    hgt = hgt - 0.0006*hole
    return col, hgt

def paint():
    sc, body, rig, fr, meta, ras_up, VAR = G.prepare_char("male")
    me = body.data
    uv = np.zeros((len(me.loops), 2)); me.uv_layers.active.data.foreach_get("uv", uv.ravel())
    ras_lo = G.rasterise(body, fr, uv, G.faces_of(me, 2))
    hc, hn, hr = G.head_textures("child", True, meta)
    # sunken dark rings round the eyes + mud smear on one cheek
    G.save_set(os.path.join(TEX, "g_child_head"), hc, hn, hr)
    # upper: white short-sleeve shirt, buttons, pocket, grave dirt + mud + holes
    r = ras_up
    col, hgt, rough = sk["paint_body"](r, meta, "child", True); col_skin = col.copy()
    col, hgt, rough = G.paint_shirt(r, col, hgt, rough, dict(color=(0.80, 0.79, 0.74), sleeve=0.30, buttons=True), 1.0)
    cloth = r["mask"] & np.any(np.abs(col - col_skin) > 1e-6, -1)
    col, hgt = holes(col, hgt, col_skin, r["P"], cloth, 61)
    col, rough = mud(col, rough, r["P"], r["mask"], 0.6, 62)
    G.finish_body_tex(os.path.join(TEX, "g_child_upper"), r, col, hgt, rough)
    # lower: navy shorts above the knee, bare muddy legs and feet
    r = ras_lo
    col, hgt, rough = sk["paint_body"](r, meta, "child", True); col_skin = col.copy()
    col, hgt, rough = G.paint_lower(r, col, hgt, rough, dict(color=(0.07, 0.09, 0.20), hem=0.60), None, "male", 1.0)
    cloth = r["mask"] & np.any(np.abs(col - col_skin) > 1e-6, -1)
    col, hgt = holes(col, hgt, col_skin, r["P"], cloth, 63, k=0.86)
    col, rough = mud(col, rough, r["P"], r["mask"], 1.0, 64)
    G.finish_body_tex(os.path.join(TEX, "g_child_lower"), r, col, hgt, rough)
    L("painted")

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

def build_and_export():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(MODELS, "ChildV2", "villager_child.blend"))
    rig = bpy.data.objects["HumanRig"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    keep = {"HumanRig", "BodyHead", "BodyUpper", "BodyLower", "Hair_child_short"}
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for name, base in (("BodyHead", "g_child_head"), ("BodyUpper", "g_child_upper"), ("BodyLower", "g_child_lower")):
        ob = bpy.data.objects[name]; ob.data.materials.clear(); ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    for o in meshes: o.hide_viewport = False; o.hide_set(False); o.hide_render = False
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(GDIR, "ghost_child_v2.blend"))
    for f in os.listdir(UP):
        os.remove(os.path.join(UP, f))
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(UP, "ghost_child_v2.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=3.5,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
        mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    data = open(path, "rb").read(); n = 0
    for fn in sorted(set(x.decode("latin1") for x in re.findall(rb"[\w\-]+\.png", data))):
        src = os.path.join(TEX, fn)
        if os.path.exists(src):
            shutil.copyfile(src, os.path.join(UP, fn)); n += 1
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
    L("exported", path, "pngs", n, "meshes", sorted(o.name for o in meshes))
    return rig

def preview(rig):
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
    hair = bpy.data.objects["Hair_child_short"]
    hm = bpy.data.materials.new("_hair"); hm.use_nodes = True; hm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.012, 0.010, 0.009, 1)
    hair.data.materials.clear(); hair.data.materials.append(hm)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    def shot(tgt, d, ortho, res):
        sc.render.resolution_x, sc.render.resolution_y = res
        d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
        p = os.path.join(GDIR, "_tmp.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr
    H = 1.30
    hz = float((rig.matrix_world @ rig.data.bones["head"].head_local).z) + 0.09
    imgs = [shot((0, 0, H*0.5), d, H*1.08, (330, 480)) for d in ((0.0, -1, 0.05), (0.6, -0.8, 0.06), (0.0, 1, 0.05))]
    face = shot((0, 0, hz), (0.2, -1, 0.04), 0.34, (480, 480))[::-1][:480][::-1]
    face = np.concatenate([face, np.ones((480, 0, 4), np.float32)], 1)
    pad = np.ones((480, 480, 4), np.float32); pad[..., :3] = (0.16, 0.17, 0.20); pad[:, :, :] = face
    sheet = np.concatenate(imgs + [pad[:480, :, :]], 1)[:480]
    img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.join(GDIR, "ghost_child_v2_preview.png"); img.file_format = 'PNG'; img.save()
    L("preview", img.filepath_raw)

if __name__ == "__main__":
    try:
        if "--no-paint" not in sys.argv:
            paint()
        rig = build_and_export()
        preview(rig)
        L("DONE")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(GDIR, "build_report.txt"), "w", encoding="utf-8").write("\n".join(log))
