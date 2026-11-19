# Render 4 square (1:1, 1024x1024) Game Icons from our actual 3D models in the Somtum Anomaly icon style
import bpy, os, math
from mathutils import Vector, Euler

ROOT = r"c:\xampp\htdocs\roblox_anomaly\assets\models"
OUT_DIR = r"c:\xampp\htdocs\roblox_anomaly\assets\thumbnails\raw"
os.makedirs(OUT_DIR, exist_ok=True)

TEX_INDEX = {}
for dirpath, _, filenames in os.walk(ROOT):
    for fn in filenames:
        if fn.lower().endswith((".png", ".jpg", ".jpeg")):
            TEX_INDEX.setdefault(fn.lower(), os.path.join(dirpath, fn))


def append_collection_objects(blend_rel, obj_names, target_coll, offset=(0, 0, 0), rot_z_deg=0.0, scale=1.0):
    path = os.path.join(ROOT, blend_rel)
    if not os.path.exists(path):
        print("WARN missing:", path)
        return []
    with bpy.data.libraries.load(path, link=False) as (data_from, data_to):
        avail = set(data_from.objects)
        to_load = [n for n in obj_names if n in avail]
        data_to.objects = to_load

    loaded = []
    parent_empty = bpy.data.objects.new("Grp_" + os.path.basename(blend_rel), None)
    target_coll.objects.link(parent_empty)

    for obj in data_to.objects:
        if obj is None:
            continue
        target_coll.objects.link(obj)
        loaded.append(obj)

    for obj in loaded:
        if obj.parent not in loaded:
            obj.parent = parent_empty

    parent_empty.location = Vector(offset)
    parent_empty.rotation_euler = Euler((0, 0, math.radians(rot_z_deg)))
    parent_empty.scale = (scale, scale, scale)

    for img in bpy.data.images:
        if img.filepath:
            raw_p = bpy.path.abspath(img.filepath)
            if not os.path.exists(raw_p):
                base = os.path.basename(raw_p.replace("\\", "/")).lower()
                if base in TEX_INDEX:
                    img.filepath = TEX_INDEX[base]
                    img.reload()
    return loaded


def add_light(coll, kind, loc, color, energy, size=0.35, target=None, spot_size_deg=70, spot_blend=0.5):
    ld = bpy.data.lights.new(kind + "_L", kind)
    ld.color = color
    ld.energy = energy
    if kind in ("POINT", "SPOT", "AREA"):
        ld.shadow_soft_size = size
    if kind == "SPOT":
        ld.spot_size = math.radians(spot_size_deg)
        ld.spot_blend = spot_blend
    obj = bpy.data.objects.new(kind, ld)
    obj.location = Vector(loc)
    if target is not None:
        direction = Vector(target) - obj.location
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    coll.objects.link(obj)
    return obj


def make_glowing_eyes(mesh_obj, r=0.013, offset_y=-0.095, offset_z=1.52, sep_x=0.032, parent_arm=None):
    """Create glowing white eyes on characters that don't have separate Eye meshes (or boost existing ones)"""
    em = bpy.data.materials.new("IconEyeGlow")
    em.use_nodes = True
    bs = em.node_tree.nodes.get("Principled BSDF")
    if bs:
        bs.inputs["Base Color"].default_value = (1.0, 0.98, 0.95, 1.0)
        if "Emission Color" in bs.inputs:
            bs.inputs["Emission Color"].default_value = (1.0, 0.95, 0.9, 1.0)
            bs.inputs["Emission Strength"].default_value = 16.0
    eyes = []
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=16, ring_count=12)
        e = bpy.context.active_object
        e.name = "IconGlowEye"
        e.data.materials.append(em)
        if parent_arm:
            hb = parent_arm.data.bones.get("head")
            if hb:
                head_world = parent_arm.matrix_world @ hb.head_local
                e.location = head_world + Vector((sx * sep_x, offset_y, 0.085))
        else:
            e.location = Vector((sx * sep_x, offset_y, offset_z))
        eyes.append(e)
    return eyes


# Open base scene: pump_props.blend
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "pump_props.blend"))
scn = bpy.context.scene

concept = bpy.data.collections.get("ConceptLayout")
for c in bpy.data.collections:
    c.hide_render = (c != concept)

HIDE_OLD = {
    "CounterTable.001", "ShackShelf.001",
    "GasPump.001", "GlassTube.001", "FuelLiquid.001", "HandCrank.001", "Nozzle.001",
    "Comp_Moon", "Comp_NeonLight", "Comp_PoleLamp", "Comp_Incense", "Comp_PumpGlow",
    "Light", "PK_Sun",
}
for o in bpy.data.objects:
    if o.name in HIDE_OLD or o.type == "LIGHT":
        o.hide_render = True
        o.hide_viewport = True

stage = bpy.data.collections.new("IconStage")
scn.collection.children.link(stage)

# Base shack props for blurred background context
append_collection_objects(
    "ShackInteriorV2/shack_interior_v2.blend",
    ["CounterTable", "CounterTable_Clutter", "MoneyTin", "MoneyTin_Lid", "IceBox", "IceBox_Lid", "SodaCrate"],
    stage,
    offset=(0.56, 2.24, 0.22),
)
append_collection_objects(
    "RadioV2/radio_v2.blend",
    ["Radio", "RadioAntenna", "RadioDial", "RadioDialNeedle"],
    stage,
    offset=(-0.55, 2.15, 1.29),
    rot_z_deg=15.0,
)
append_collection_objects(
    "ShackShelfV2/shack_shelf_v2.blend",
    ["ShackShelf", "ShelfGoods_Lower", "ShelfGoods_Upper"],
    stage,
    offset=(-1.12, 3.42, 0.22),
)
p1_objs = append_collection_objects(
    "GasPumpV3/gas_pump_v3.blend",
    ["GasPump", "GlassTube", "FuelLiquid", "HandCrank", "Nozzle"],
    stage,
    offset=(-2.95, -2.85, 0.0),
)
for o in p1_objs:
    if "FuelLiquid" in o.name and o.data and o.data.materials:
        mat = o.data.materials[0].copy()
        o.data.materials[0] = mat
        if mat.use_nodes:
            for n in mat.node_tree.nodes:
                if n.type == "BSDF_PRINCIPLED":
                    n.inputs["Base Color"].default_value = (0.85, 0.35, 0.08, 1.0)

cg = bpy.data.objects.get("Comp_Ground")
if cg and cg.data and cg.data.materials:
    gm = cg.data.materials[0]
    if gm.use_nodes:
        for n in gm.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = (0.03, 0.025, 0.02, 1.0)
                n.inputs["Roughness"].default_value = 0.92

world = bpy.data.worlds.new("IconWorld")
scn.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
w_out = nt.nodes.new("ShaderNodeOutputWorld")
w_bg = nt.nodes.new("ShaderNodeBackground")
w_bg.inputs[0].default_value = (0.003, 0.001, 0.002, 1.0)
w_bg.inputs[1].default_value = 0.05
nt.links.new(w_bg.outputs[0], w_out.inputs["Surface"])

scn.render.engine = "CYCLES"
scn.cycles.samples = 56
scn.cycles.use_denoising = True
try:
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "CUDA"
    prefs.get_devices()
    for d in prefs.devices:
        d.use = True
    scn.cycles.device = "GPU"
except Exception:
    pass

# Square 1:1 resolution (1024x1024)
scn.render.resolution_x = 1024
scn.render.resolution_y = 1024
scn.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
try:
    scn.view_settings.look = "AgX - High Contrast"
except Exception:
    pass

cam_data = bpy.data.cameras.new("IconCam")
cam_data.dof.use_dof = True
cam_obj = bpy.data.objects.new("IconCam", cam_data)
stage.objects.link(cam_obj)
scn.camera = cam_obj


def clear_dynamic(objs):
    for o in objs:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            pass


def render_icon(filename, cam_loc, cam_target, lens, fstop, focus_dist, exposure, roll_deg=0.0):
    scn.view_settings.exposure = exposure
    cam_obj.location = Vector(cam_loc)
    cam_data.lens = lens
    cam_data.dof.aperture_fstop = fstop
    cam_data.dof.focus_distance = focus_dist
    direction = Vector(cam_target) - cam_obj.location
    quat = direction.to_track_quat("-Z", "Y")
    eul = quat.to_euler()
    eul.rotate_axis("Z", math.radians(roll_deg))
    cam_obj.rotation_euler = eul
    out_path = os.path.join(OUT_DIR, filename)
    scn.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print("RENDERED ICON:", out_path)


# ==============================================================================
# ICON 1: Ghost Dancer Portrait (Exact match to Somtum Anomaly's 1:1 Icon:
# Thai traditional crown/dress, tilted head, warm gold/red rim light)
# ==============================================================================
dyn = []
gd = append_collection_objects(
    "human_ghosts/ghost_dancer.blend",
    [
        "HumanRig", "Body", "Cloth_ghost_dancer", "Cloth_ghost_dancer_sin",
        "Cloth_ghost_dancer_sabai", "Cloth_ghost_dancer_crown", "Cloth_ghost_dancer_flowers",
        "Cloth_ghost_dancer_collar", "Cloth_ghost_dancer_armlets", "Cloth_ghost_dancer_bracelets",
        "Cloth_ghost_dancer_pendant", "Cloth_ghost_dancer_belt",
    ],
    stage,
    offset=(-0.5, -1.5, 0.0),
    rot_z_deg=0.0,
    scale=1.0,
)
for o in gd:
    if o.type == "ARMATURE":
        # Slight eerie head tilt + raised dancing hand like the Somtum Anomaly icon
        hb = o.pose.bones.get("head")
        if hb:
            hb.rotation_mode = "XYZ"
            hb.rotation_euler = (0.05, 0.16, -0.08)
        ua = o.pose.bones.get("upper_arm.R")
        fa = o.pose.bones.get("forearm.R")
        hd = o.pose.bones.get("hand.R")
        if ua and fa and hd:
            ua.rotation_mode = "XYZ"
            fa.rotation_mode = "XYZ"
            hd.rotation_mode = "XYZ"
            ua.rotation_euler = (0.55, 0.25, -0.65)
            fa.rotation_euler = (1.35, -0.3, 0.4)
            hd.rotation_euler = (-0.4, 0.0, 0.3)

dyn.extend(gd)
# Dramatic warm red-amber key light + crimson rim light + soft fill on face & crown
dyn.append(add_light(stage, "SPOT", (-1.15, -2.65, 1.85), (1.0, 0.32, 0.22), 42.0, size=0.35, target=(-0.5, -1.5, 1.48), spot_size_deg=55))
dyn.append(add_light(stage, "POINT", (0.25, -2.15, 1.65), (1.0, 0.08, 0.10), 18.0, size=0.25))
dyn.append(add_light(stage, "POINT", (-0.5, -0.7, 1.85), (1.0, 0.12, 0.08), 35.0, size=0.3))
dyn.append(add_light(stage, "POINT", (0.5, 1.8, 2.4), (1.0, 0.55, 0.25), 22.0, size=0.4))

render_icon(
    "icon1_dancer.png",
    cam_loc=(-0.48, -2.62, 1.47),
    cam_target=(-0.50, -1.50, 1.49),
    lens=48,
    fstop=1.6,
    focus_dist=1.12,
    exposure=0.75,
    roll_deg=-2.5,
)
clear_dynamic(dyn)

# ==============================================================================
# ICON 2: Phi Ta Khon Mask Rider / Ghost Portrait with gas pump glowing behind
# ==============================================================================
dyn = []
tk = append_collection_objects(
    "human_ghosts/ghost_ta_khon.blend",
    ["HumanRig", "Body"],
    stage,
    offset=(-1.95, -3.55, 0.0),
    rot_z_deg=12.0,
    scale=1.0,
)
# Load all mesh objects from ghost_ta_khon.blend
with bpy.data.libraries.load(os.path.join(ROOT, "human_ghosts/ghost_ta_khon.blend"), link=False) as (df, dt):
    all_tk = [n for n in df.objects if n not in ("Light", "Camera", "HumanRig", "Body")]
clear_dynamic(tk)
tk = append_collection_objects(
    "human_ghosts/ghost_ta_khon.blend",
    ["HumanRig", "Body"] + all_tk,
    stage,
    offset=(-2.15, -3.65, 0.0),
    rot_z_deg=10.0,
    scale=1.0,
)
for o in tk:
    if o.type == "ARMATURE":
        hb = o.pose.bones.get("head")
        if hb:
            hb.rotation_mode = "XYZ"
            hb.rotation_euler = (0.04, -0.14, 0.06)
dyn.extend(tk)
dyn.append(add_light(stage, "SPOT", (-1.45, -4.85, 1.95), (1.0, 0.35, 0.20), 55.0, size=0.35, target=(-2.15, -3.65, 1.55), spot_size_deg=60))
dyn.append(add_light(stage, "POINT", (-2.95, -4.25, 1.65), (1.0, 0.06, 0.08), 28.0, size=0.25))
dyn.append(add_light(stage, "POINT", (-2.75, -2.85, 1.45), (1.0, 0.45, 0.15), 24.0, size=0.3))

render_icon(
    "icon2_takhon.png",
    cam_loc=(-1.95, -4.92, 1.52),
    cam_target=(-2.22, -3.65, 1.54),
    lens=45,
    fstop=1.6,
    focus_dist=1.28,
    exposure=0.75,
    roll_deg=2.0,
)
clear_dynamic(dyn)

# ==============================================================================
# ICON 3: Pop Ghost Close-up Portrait with glowing white eyes & fangs in front of the shack counter
# ==============================================================================
dyn = []
gp = append_collection_objects(
    "pop.blend",
    ["HumanRig", "Pop", "Pop_Blouse", "Pop_Sin", "Pop_Hair", "Pop_Eyes", "Pop_Fangs", "Pop_Tongue"],
    stage,
    offset=(-0.35, -1.25, 0.0),
    rot_z_deg=-6.0,
    scale=1.0,
)
for o in gp:
    if o.name == "Pop_Eyes" and o.data and o.data.materials:
        em = bpy.data.materials.new("IconPopEyes")
        em.use_nodes = True
        bs = em.node_tree.nodes.get("Principled BSDF")
        if bs:
            bs.inputs["Base Color"].default_value = (1.0, 0.96, 0.92, 1.0)
            if "Emission Color" in bs.inputs:
                bs.inputs["Emission Color"].default_value = (1.0, 0.92, 0.85, 1.0)
                bs.inputs["Emission Strength"].default_value = 18.0
        o.data.materials[0] = em
    elif o.type == "ARMATURE":
        hb = o.pose.bones.get("head")
        if hb:
            hb.rotation_mode = "XYZ"
            hb.rotation_euler = (0.12, 0.14, -0.05)

dyn.extend(gp)
dyn.append(add_light(stage, "SPOT", (-0.95, -2.35, 1.78), (1.0, 0.25, 0.16), 38.0, size=0.3, target=(-0.35, -1.25, 1.42), spot_size_deg=55))
dyn.append(add_light(stage, "POINT", (0.35, -1.85, 1.55), (0.95, 0.06, 0.08), 16.0, size=0.25))
dyn.append(add_light(stage, "POINT", (0.4, 1.6, 2.3), (1.0, 0.55, 0.25), 25.0, size=0.4))

render_icon(
    "icon3_pop.png",
    cam_loc=(-0.32, -2.28, 1.42),
    cam_target=(-0.36, -1.25, 1.41),
    lens=48,
    fstop=1.6,
    focus_dist=1.04,
    exposure=0.72,
    roll_deg=-3.0,
)
clear_dynamic(dyn)

# ==============================================================================
# ICON 4: Vintage Glass-Tube Hand-Crank Barrel Pump (GasPumpV3) Hero Icon with Ghost lurking behind
# ==============================================================================
dyn = []
g_bg = append_collection_objects(
    "pop.blend",
    ["HumanRig", "Pop", "Pop_Blouse", "Pop_Sin", "Pop_Hair", "Pop_Eyes"],
    stage,
    offset=(-1.95, -1.15, 0.0),
    rot_z_deg=-15.0,
    scale=1.05,
)
for o in g_bg:
    if o.name == "Pop_Eyes" and o.data and o.data.materials:
        em = bpy.data.materials.new("IconBgEyes")
        em.use_nodes = True
        bs = em.node_tree.nodes.get("Principled BSDF")
        if bs:
            bs.inputs["Base Color"].default_value = (1.0, 0.2, 0.15, 1.0)
            if "Emission Color" in bs.inputs:
                bs.inputs["Emission Color"].default_value = (1.0, 0.25, 0.15, 1.0)
                bs.inputs["Emission Strength"].default_value = 22.0
        o.data.materials[0] = em
dyn.extend(g_bg)

dyn.append(add_light(stage, "SPOT", (-3.85, -4.15, 2.05), (1.0, 0.42, 0.16), 55.0, size=0.3, target=(-2.95, -2.85, 1.25), spot_size_deg=60))
dyn.append(add_light(stage, "POINT", (-2.25, -3.45, 1.45), (1.0, 0.15, 0.08), 18.0, size=0.25))
dyn.append(add_light(stage, "POINT", (-1.85, -1.55, 1.65), (1.0, 0.08, 0.08), 14.0, size=0.3))
dyn.append(add_light(stage, "POINT", (0.4, 1.6, 2.3), (1.0, 0.52, 0.24), 24.0, size=0.4))

render_icon(
    "icon4_pump.png",
    cam_loc=(-3.42, -4.35, 1.28),
    cam_target=(-2.35, -1.5, 1.26),
    lens=38,
    fstop=1.8,
    focus_dist=1.55,
    exposure=0.78,
)
clear_dynamic(dyn)
print("ALL 4 ICONS DONE")
