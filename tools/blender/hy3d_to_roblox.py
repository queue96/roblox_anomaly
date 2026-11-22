# Hunyuan3D (ComfyUI Hy3D) .glb -> Roblox-ready FBX with fewer polygons
#
#   blender.exe --background --factory-startup --python hy3d_to_roblox.py -- <src.glb> <Name> <height_m> <target_tris> [flat|wet] [mute]
#
#   used so far:
#     Hy3D_textured_00010_.glb PretV2   4.0  14000 flat
#     Hy3D_textured_00009_.glb KrasueV2 0.75 12000 wet mute
#
# Steps
#   1. import the glb (one mesh, one 4K base-colour texture), stand it on z=0, scale to <height_m>
#   2. low = decimated copy (collapse) down to <target_tris>, new clean UVs (Smart UV Project)
#   3. Cycles bake high -> low at BAKE px: base colour (via emission, so metallic never bakes black)
#      + tangent-space normal (OpenGL, what Roblox SurfaceAppearance reads), saved at TEX px
#   4. roughness map: "flat" = 0.8 everywhere, "wet" = red/fleshy parts glossy (organs), the rest matte
#      "mute" = saturated blood-red flesh -> dull grey-purple (no gore, project rule GORE = False)
#   5. export assets/models/<Name>/upload/<Name>.fbx + <Name>_Color/_Normal/_Roughness.png
#      previews + .blend go in assets/models/<Name>/
#
# Scale follows pret.py: scene in metres, FBX global_scale 3.5 (1.80 m = 6.3 studs).

import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, NAME, HEIGHT, TARGET = argv[0], argv[1], float(argv[2]), int(argv[3])
ROUGH = argv[4] if len(argv) > 4 else "flat"
MUTE = len(argv) > 5 and argv[5] == "mute"

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", NAME))
UP = os.path.join(ROOT, "upload")
PREV = os.path.join(ROOT, "previews")
for d in (ROOT, UP, PREV):
    os.makedirs(d, exist_ok=True)

BAKE = 2048
TEX = 1024
STUDS_PER_M = 3.5


def log(*a):
    print("[hy3d]", *a, flush=True)


# ---------------------------------------------------------------- 1. import + normalise
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
high = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
for o in list(bpy.context.scene.objects):
    if o is not high and o.type != "MESH":
        bpy.data.objects.remove(o)
high.parent = None
high.name = NAME + "_high"
bpy.context.view_layer.objects.active = high
high.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

me = high.data
co = np.empty(len(me.vertices) * 3, np.float32)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
lo, hi = co.min(0), co.max(0)
s = HEIGHT / (hi[2] - lo[2])
co = (co - np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, lo[2]])) * s
me.vertices.foreach_set("co", co.ravel())
me.update()
# the glb importer splits vertices along UV seams; weld them, or decimation tears the mesh into islands
bm = bmesh.new()
bm.from_mesh(me)
nv = len(bm.verts)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=HEIGHT * 2e-5)
log(f"welded {nv - len(bm.verts)} seam vertices")
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = True
log(f"high: {len(me.polygons)} faces, scaled x{s:.3f} to {HEIGHT} m = {HEIGHT * STUDS_PER_M:.1f} studs")

src_img = None
for n in high.active_material.node_tree.nodes:
    if n.type == "TEX_IMAGE":
        src_img = n.image

# ---------------------------------------------------------------- 2. low poly
low = high.copy()
low.data = high.data.copy()
low.name = NAME
bpy.context.scene.collection.objects.link(low)
dec = low.modifiers.new("dec", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.ratio = TARGET / len(me.polygons)
dec.use_collapse_triangulate = True
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier="dec")

# drop specks the collapse leaves behind (islands under 8 faces)
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
seen, small = set(), []
for f in bm.faces:
    if f.index in seen:
        continue
    island, stack = [], [f]
    seen.add(f.index)
    while stack:
        g = stack.pop()
        island.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    if len(island) < 8:
        small += island
bmesh.ops.delete(bm, geom=small, context="FACES")
bm.to_mesh(low.data)
bm.free()
log(f"low: {len(low.data.polygons)} tris (removed {len(small)} loose faces)")

for uv in list(low.data.uv_layers):
    low.data.uv_layers.remove(uv)
low.data.uv_layers.new(name="UVMap")
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, area_weight=0.0, scale_to_bounds=True)
bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------- 3. bake
scn = bpy.context.scene
scn.render.engine = "CYCLES"
scn.cycles.samples = 4
scn.cycles.device = "CPU"
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA", "HIP"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scn.cycles.device = "GPU"
                break
        except Exception:
            pass
except Exception:
    pass
log("bake device:", scn.cycles.device)

# high material: base colour -> emission
hm = high.active_material
nt = hm.node_tree
out = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
emi = nt.nodes.new("ShaderNodeEmission")
tex = [n for n in nt.nodes if n.type == "TEX_IMAGE"][0]
nt.links.new(tex.outputs[0], emi.inputs[0])
bsdf_link = out.inputs["Surface"].links[0].from_socket


def target_image(name, data):
    img = bpy.data.images.new(name, BAKE, BAKE, alpha=False, float_buffer=data)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    return img


lm = bpy.data.materials.new(NAME)
lm.use_nodes = True
low.data.materials.clear()
low.data.materials.append(lm)
lnt = lm.node_tree
bake_node = lnt.nodes.new("ShaderNodeTexImage")
lnt.nodes.active = bake_node

bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
bk = scn.render.bake
bk.use_selected_to_active = True
bk.use_cage = False
bk.cage_extrusion = HEIGHT * 0.012
bk.max_ray_distance = HEIGHT * 0.03
bk.margin = 16
bk.margin_type = "EXTEND"

col = target_image(NAME + "_Color_bake", False)
bake_node.image = col
nt.links.new(emi.outputs[0], out.inputs["Surface"])
bpy.ops.object.bake(type="EMIT")
log("baked colour")

nrm = target_image(NAME + "_Normal_bake", True)
bake_node.image = nrm
nt.links.new(bsdf_link, out.inputs["Surface"])
bk.normal_space = "TANGENT"
bpy.ops.object.bake(type="NORMAL")
log("baked normal")


def pixels(img):
    a = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(a)
    return a.reshape(img.size[1], img.size[0], 4)


def save(arr, fname, data):
    k = BAKE // TEX
    arr = arr.reshape(TEX, k, TEX, k, 4).mean(axis=(1, 3))
    img = bpy.data.images.new(fname, TEX, TEX, alpha=False, float_buffer=data)
    img.colorspace_settings.name = "Non-Color" if data else "sRGB"
    img.pixels.foreach_set(arr.ravel())
    path = os.path.join(UP, fname + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    log("saved", path)
    return img


c = pixels(col)
n = pixels(nrm)
img_n = save(n, NAME + "_Normal", True)

# roughness (read from the original colours, before any muting)
r = np.full_like(c, 0.8)
r[..., 3] = 1
if ROUGH == "wet":
    lin = c[..., :3]
    red = lin[..., 0] - np.maximum(lin[..., 1], lin[..., 2])
    wet = np.clip((red - 0.04) / 0.12, 0, 1)
    v = 0.8 - 0.45 * wet
    r[..., 0] = r[..., 1] = r[..., 2] = v
img_r = save(r, NAME + "_Roughness", True)

# "mute": no blood-red flesh (Roblox moderation warned this account over a bloody texture, see
# assets/models/GHOST_MODELS.md). Strongly saturated reds -> dull grey-purple, same shading detail.
# Skin (brown, less saturated) and hair (dark) stay as they are.
if MUTE:
    rgb = c[..., :3]
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    reddish = (rgb[..., 0] >= mx - 1e-4) & (rgb[..., 1] - rgb[..., 2] < 0.12)
    m = np.clip((sat - 0.5) / 0.2, 0, 1) * np.clip((mx - 0.08) / 0.1, 0, 1) * reddish
    lum = rgb @ np.array([0.30, 0.50, 0.20], np.float32)
    lum = np.clip(lum / max(np.percentile(lum[m > 0.5], 95), 1e-3) if (m > 0.5).any() else lum, 0, 1)
    tone = 0.12 + 0.42 * lum[..., None]
    muted = tone * np.array([0.92, 0.80, 0.96], np.float32)
    c[..., :3] = rgb * (1 - m[..., None]) + muted * m[..., None]
    log(f"muted {float((m > 0.5).mean()) * 100:.1f}% of the colour map")
img_c = save(c, NAME + "_Color", False)

# low material for preview / fbx
lnt.nodes.remove(bake_node)
bsdf = lnt.nodes["Principled BSDF"]
tc = lnt.nodes.new("ShaderNodeTexImage"); tc.image = img_c
tn = lnt.nodes.new("ShaderNodeTexImage"); tn.image = img_n
tr = lnt.nodes.new("ShaderNodeTexImage"); tr.image = img_r
nm = lnt.nodes.new("ShaderNodeNormalMap")
lnt.links.new(tc.outputs[0], bsdf.inputs["Base Color"])
lnt.links.new(tr.outputs[0], bsdf.inputs["Roughness"])
lnt.links.new(tn.outputs[0], nm.inputs["Color"])
lnt.links.new(nm.outputs[0], bsdf.inputs["Normal"])
bsdf.inputs["Metallic"].default_value = 0.0

# ---------------------------------------------------------------- 5. export
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
fbx_path = os.path.join(UP, NAME + ".fbx")
bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, global_scale=STUDS_PER_M,
                         apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
                         bake_space_transform=False, object_types={"MESH"}, mesh_smooth_type="FACE",
                         path_mode="STRIP", embed_textures=False, use_mesh_modifiers=False)
log("exported", fbx_path, len(low.data.polygons), "tris")

# ---------------------------------------------------------------- previews: high vs low, front/side/back
high.hide_render = True
scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x, scn.render.resolution_y = 700, 900
w = bpy.data.worlds.new("w"); scn.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.33, 0.33, 0.36, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.5
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
scn.collection.objects.link(sun)
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"
dims = low.dimensions
cd.ortho_scale = max(dims) * 1.1
cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
ctr = Vector((0, 0, HEIGHT / 2))
for vname, ang in (("front", 0), ("side", 90), ("back", 180)):
    a = math.radians(ang)
    cam.location = ctr + Vector((math.sin(a), -math.cos(a), 0)) * HEIGHT * 4
    cam.rotation_euler = (math.radians(90), 0, a)
    for which, ob in (("low", low), ("high", high)):
        low.hide_render = ob is not low
        high.hide_render = ob is not high
        scn.render.filepath = os.path.join(PREV, f"{NAME}_{which}_{vname}.png")
        bpy.ops.render.render(write_still=True)
low.hide_render = False
high.hide_render = True

# keep a .blend (low only + baked images packed) next to the upload folder
bpy.data.objects.remove(high)
for img in (img_c, img_n, img_r):
    img.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, NAME + ".blend"), compress=True)
log("done", NAME)
