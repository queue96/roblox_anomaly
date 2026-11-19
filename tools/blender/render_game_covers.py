# Render 4 in-engine style 16:9 cover thumbnails matching the Somtum Anomaly aesthetic
# using our actual Blender 3D models (pump_props, ShackInteriorV2, ShackShelfV2, GasPumpV3, RadioV2, spirit_house_v2, ghosts).
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
                if "TEX_INDEX" in globals() and base in TEX_INDEX:
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


# Open base scene: pump_props.blend
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "pump_props.blend"))
scn = bpy.context.scene

# Hide everything except ConceptLayout
concept = bpy.data.collections.get("ConceptLayout")
for c in bpy.data.collections:
    c.hide_render = (c != concept)

# Hide old v1 props AND ALL default bright Sun/Daylight lamps in pump_props.blend
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

stage = bpy.data.collections.new("ThumbnailStage")
scn.collection.children.link(stage)

# 1. Append ShackInteriorV2 at CounterTable.001 position (0.56, 2.24, 0.22)
append_collection_objects(
    "ShackInteriorV2/shack_interior_v2.blend",
    ["CounterTable", "CounterTable_Clutter", "MoneyTin", "MoneyTin_Lid", "IceBox", "IceBox_Lid", "SodaCrate"],
    stage,
    offset=(0.56, 2.24, 0.22),
    rot_z_deg=0.0,
)

# 2. Append RadioV2 on the counter table left side
append_collection_objects(
    "RadioV2/radio_v2.blend",
    ["Radio", "RadioAntenna", "RadioDial", "RadioDialNeedle"],
    stage,
    offset=(-0.55, 2.15, 1.29),
    rot_z_deg=15.0,
)

# 3. Append LeafSweets + GhostHand on the counter table / spirit house
append_collection_objects(
    "spirit_house_v2.blend",
    ["LeafTray", "OpenWrap", "SweetCake", "Wrapped"],
    stage,
    offset=(0.25, 2.02, 1.29),
    rot_z_deg=-10.0,
    scale=1.35,
)

# 4. Append ShackShelfV2 at back wall (-1.12, 3.47, 0.22)
append_collection_objects(
    "ShackShelfV2/shack_shelf_v2.blend",
    ["ShackShelf", "ShelfGoods_Lower", "ShelfGoods_Upper"],
    stage,
    offset=(-1.12, 3.42, 0.22),
    rot_z_deg=0.0,
)

# 5. Append GasPumpV3 (Petrol + Diesel pair) in front of the shack
p1_objs = append_collection_objects(
    "GasPumpV3/gas_pump_v3.blend",
    ["GasPump", "GlassTube", "FuelLiquid", "HandCrank", "Nozzle"],
    stage,
    offset=(-2.95, -2.85, 0.0),
    rot_z_deg=0.0,
)
p2_objs = append_collection_objects(
    "GasPumpV3/gas_pump_v3.blend",
    ["GasPump", "GlassTube", "FuelLiquid", "HandCrank", "Nozzle"],
    stage,
    offset=(-1.70, -2.85, 0.0),
    rot_z_deg=0.0,
)

# Tint FuelLiquid in pump 1 (Petrol amber-orange) and pump 2 (Diesel green)
for idx, grp in enumerate([p1_objs, p2_objs]):
    for o in grp:
        if "FuelLiquid" in o.name and o.data and o.data.materials:
            mat = o.data.materials[0].copy()
            o.data.materials[0] = mat
            if mat.use_nodes:
                for n in mat.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        n.inputs["Base Color"].default_value = (0.85, 0.42, 0.12, 1.0) if idx == 0 else (0.28, 0.78, 0.32, 1.0)

# 6. Append JerryCan on the porch near the counter
append_collection_objects(
    "jerry_can.blend",
    ["JerryCan", "JerryCanFuel"],
    stage,
    offset=(2.35, 1.45, 0.22),
    rot_z_deg=-35.0,
)

# Remap all old C:\Aunival\pump-lot-anomaly paths to c:\xampp\htdocs\roblox_anomaly
TEX_INDEX = {}
for dirpath, _, filenames in os.walk(ROOT):
    for fn in filenames:
        if fn.lower().endswith((".png", ".jpg", ".jpeg")):
            TEX_INDEX.setdefault(fn.lower(), os.path.join(dirpath, fn))

remapped = 0
for img in bpy.data.images:
    if img.filepath:
        raw_p = bpy.path.abspath(img.filepath)
        if not os.path.exists(raw_p):
            base = os.path.basename(raw_p.replace("\\", "/")).lower()
            if base in TEX_INDEX:
                img.filepath = TEX_INDEX[base]
                img.reload()
                remapped += 1
print("REMAPPED TEXTURES:", remapped)

# Make Comp_Ground dark muddy dirt instead of beige
cg = bpy.data.objects.get("Comp_Ground")
if cg and cg.data and cg.data.materials:
    gm = cg.data.materials[0]
    if gm.use_nodes:
        for n in gm.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Base Color"].default_value = (0.04, 0.032, 0.025, 1.0)
                n.inputs["Roughness"].default_value = 0.92

# Dark pitch-black horror world
world = bpy.data.worlds.new("ThumbWorld")
scn.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
w_out = nt.nodes.new("ShaderNodeOutputWorld")
w_bg = nt.nodes.new("ShaderNodeBackground")
w_bg.inputs[0].default_value = (0.003, 0.002, 0.003, 1.0)
w_bg.inputs[1].default_value = 0.08
nt.links.new(w_bg.outputs[0], w_out.inputs["Surface"])

# Configure Render Engine (Cycles with Denoising & Depth of Field for realistic glass/metal/rim light)
scn.render.engine = "CYCLES"
scn.cycles.samples = 48
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

scn.render.resolution_x = 1920
scn.render.resolution_y = 1080
scn.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
try:
    scn.view_settings.look = "AgX - High Contrast"
except Exception:
    pass

cam_data = bpy.data.cameras.new("ThumbCam")
cam_data.dof.use_dof = True
cam_obj = bpy.data.objects.new("ThumbCam", cam_data)
stage.objects.link(cam_obj)
scn.camera = cam_obj


def clear_dynamic(objs):
    for o in objs:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            pass


def render_shot(filename, cam_loc, cam_target, lens, fstop, focus_dist, exposure, roll_deg=0.0):
    only = os.environ.get("ONLY_SHOT")
    if only and only not in filename:
        return
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
    print("RENDERED:", out_path)


# ==============================================================================
# SHOT 1: High-angle CCTV / Corner view looking down at the Counter Table & Ghost standing outside
# (Matches Somtum Anomaly Image 2 & 3 - Ghost facing camera with glowing eyes)
# ==============================================================================
dyn = []
# Load Pop ghost facing toward the high-angle CCTV camera (+X, -Y)
g1 = append_collection_objects(
    "pop.blend",
    ["HumanRig", "Pop", "Pop_Blouse", "Pop_Sin", "Pop_Hair", "Pop_Eyes", "Pop_Fangs", "Pop_Tongue"],
    stage,
    offset=(-0.75, 0.45, 0.05),
    rot_z_deg=68.0,
    scale=1.1,
)
# Make Pop_Eyes emit bright eerie white-red glow & tilt head up toward the CCTV camera
for o in g1:
    if o.name == "Pop_Eyes" and o.data and o.data.materials:
        em = bpy.data.materials.new("PopEyeGlow")
        em.use_nodes = True
        bs = em.node_tree.nodes.get("Principled BSDF")
        if bs:
            bs.inputs["Base Color"].default_value = (1.0, 0.9, 0.85, 1.0)
            if "Emission Color" in bs.inputs:
                bs.inputs["Emission Color"].default_value = (1.0, 0.85, 0.75, 1.0)
                bs.inputs["Emission Strength"].default_value = 12.0
        o.data.materials[0] = em
    elif o.type == "ARMATURE":
        for bname, pitch in [("neck", -0.35), ("head", -0.45)]:
            pb = o.pose.bones.get(bname)
            if pb:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = (pitch, 0.0, -0.18)

dyn.extend(g1)
# Red-orange eerie overhead lamp + dim warm counter bounce + eerie highlight on ghost face
dyn.append(add_light(stage, "SPOT", (1.6, 1.8, 3.3), (1.0, 0.24, 0.14), 65.0, size=0.4, target=(0.1, 1.5, 1.0), spot_size_deg=95))
dyn.append(add_light(stage, "POINT", (0.25, 0.15, 1.95), (1.0, 0.22, 0.14), 22.0, size=0.25))
dyn.append(add_light(stage, "POINT", (0.7, 2.6, 2.2), (1.0, 0.55, 0.28), 10.0, size=0.35))

render_shot(
    "shot1_cctv_counter.png",
    cam_loc=(2.35, 0.35, 2.85),
    cam_target=(-0.15, 1.55, 1.05),
    lens=24,
    fstop=2.8,
    focus_dist=2.6,
    exposure=0.5,
    roll_deg=-4.0,
)
clear_dynamic(dyn)

# ==============================================================================
# SHOT 2: Close-up Shallow DOF on Counter Props (Transistor Radio, Money Tin, Leaf Sweets) with Shelf behind
# (Matches Somtum Anomaly Image 1 & 6 - Glass case close-up)
# ==============================================================================
dyn = []
# Warm moody tungsten light on the counter items, red rim in the background shelf
dyn.append(add_light(stage, "SPOT", (0.2, 0.7, 2.25), (1.0, 0.58, 0.28), 35.0, size=0.25, target=(0.1, 2.1, 1.28), spot_size_deg=65))
dyn.append(add_light(stage, "POINT", (-1.1, 2.9, 1.8), (0.95, 0.18, 0.12), 16.0, size=0.4))
dyn.append(add_light(stage, "POINT", (1.2, 1.8, 1.55), (1.0, 0.72, 0.42), 8.0, size=0.2))

render_shot(
    "shot2_counter_closeup.png",
    cam_loc=(0.55, 0.82, 1.48),
    cam_target=(-0.05, 2.18, 1.28),
    lens=42,
    fstop=1.4,
    focus_dist=1.42,
    exposure=0.85,
)
clear_dynamic(dyn)

# ==============================================================================
# SHOT 3: Back of Ghost Dancer / Phi Tani silhouette with dramatic Crimson Red Rim Light looking at the Shack
# (Matches Somtum Anomaly Image 4 - Back of ghost with red glow)
# ==============================================================================
dyn = []
gd = append_collection_objects(
    "human_ghosts/ghost_dancer.blend",
    [
        "HumanRig", "Body", "Cloth_ghost_dancer", "Cloth_ghost_dancer_sin",
        "Cloth_ghost_dancer_sabai", "Cloth_ghost_dancer_crown", "Cloth_ghost_dancer_flowers",
        "Cloth_ghost_dancer_collar", "Cloth_ghost_dancer_armlets", "Cloth_ghost_dancer_bracelets",
    ],
    stage,
    offset=(-0.45, -4.65, 0.0),
    rot_z_deg=172.0,
    scale=1.0,
)
dyn.extend(gd)
# Strong crimson red rim light from the front-left of the ghost (hitting her side/back from camera view)
dyn.append(add_light(stage, "SPOT", (-1.55, -3.55, 1.85), (1.0, 0.04, 0.06), 140.0, size=0.25, target=(-0.45, -4.65, 1.35), spot_size_deg=60))
dyn.append(add_light(stage, "POINT", (0.45, -3.85, 1.65), (0.9, 0.08, 0.12), 22.0, size=0.3))
# Warm dim light inside the shack behind her
dyn.append(add_light(stage, "POINT", (0.5, 1.8, 2.5), (1.0, 0.52, 0.24), 28.0, size=0.4))
dyn.append(add_light(stage, "POINT", (-2.3, -2.5, 1.8), (1.0, 0.15, 0.1), 18.0, size=0.3))

render_shot(
    "shot3_ghost_back_red.png",
    cam_loc=(-0.38, -5.85, 1.38),
    cam_target=(-0.45, -2.0, 1.42),
    lens=38,
    fstop=1.8,
    focus_dist=1.22,
    exposure=0.75,
)
clear_dynamic(dyn)

# ==============================================================================
# SHOT 4: Close-up on the Hand-Crank Glass-Tube Barrel Fuel Pumps (GasPumpV3) glowing in the dark
# with the Shack Counter & Spirit House softly blurred in the background
# (Matches Somtum Anomaly Image 5 - Charcoal grill close-up with stall behind)
# ==============================================================================
dyn = []
# Warm fiery amber-red glow on the barrel pumps & glass tubes, dim eerie red in the shack behind
dyn.append(add_light(stage, "SPOT", (-3.6, -4.2, 2.1), (1.0, 0.38, 0.14), 55.0, size=0.3, target=(-2.4, -2.85, 1.15), spot_size_deg=65))
dyn.append(add_light(stage, "POINT", (-2.35, -3.25, 1.55), (1.0, 0.22, 0.08), 16.0, size=0.2))
dyn.append(add_light(stage, "POINT", (0.5, 1.5, 2.5), (1.0, 0.55, 0.28), 32.0, size=0.4))
dyn.append(add_light(stage, "POINT", (-8.8, -1.8, 2.2), (1.0, 0.1, 0.08), 25.0, size=0.3))

render_shot(
    "shot4_fuelpumps_closeup.png",
    cam_loc=(-3.55, -4.55, 1.35),
    cam_target=(-1.2, -0.5, 1.32),
    lens=36,
    fstop=1.6,
    focus_dist=1.85,
    exposure=0.8,
)
clear_dynamic(dyn)
print("ALL 4 SHOTS DONE")
