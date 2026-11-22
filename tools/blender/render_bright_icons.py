# Render 4 dramatic, readable night-horror 1:1 (1024x1024) Game Icons from our actual in-game 3D models
import bpy, os, math
import numpy as np
from mathutils import Vector, Euler

ROOT = r"c:\xampp\htdocs\roblox_anomaly\assets\models"
RAW_DIR = r"c:\xampp\htdocs\roblox_anomaly\assets\thumbnails\raw"
os.makedirs(RAW_DIR, exist_ok=True)

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

stage = bpy.data.collections.new("IconStageV3")
scn.collection.children.link(stage)

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
                    n.inputs["Base Color"].default_value = (0.95, 0.35, 0.08, 1.0)
                    if "Emission Color" in n.inputs:
                        n.inputs["Emission Color"].default_value = (1.0, 0.32, 0.06, 1.0)
                        n.inputs["Emission Strength"].default_value = 0.85

# Dark night world (keeps night atmosphere true to the game!)
world = bpy.data.worlds.new("IconWorldV3")
scn.world = world
world.use_nodes = True
nt = world.node_tree
nt.nodes.clear()
w_out = nt.nodes.new("ShaderNodeOutputWorld")
w_bg = nt.nodes.new("ShaderNodeBackground")
w_bg.inputs[0].default_value = (0.008, 0.005, 0.008, 1.0)
w_bg.inputs[1].default_value = 0.12
nt.links.new(w_bg.outputs[0], w_out.inputs["Surface"])

scn.render.engine = "CYCLES"
scn.cycles.samples = 64
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

scn.render.resolution_x = 1024
scn.render.resolution_y = 1024
scn.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
try:
    scn.view_settings.look = "AgX - High Contrast"
except Exception:
    pass

cam_data = bpy.data.cameras.new("IconCamV3")
cam_data.dof.use_dof = True
cam_obj = bpy.data.objects.new("IconCamV3", cam_data)
stage.objects.link(cam_obj)
scn.camera = cam_obj


def clear_dynamic(objs):
    for o in objs:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            pass


def grade_and_save(raw_name, out_name):
    src_path = os.path.join(RAW_DIR, raw_name)
    img = bpy.data.images.load(src_path)
    w, h = img.size[0], img.size[1]
    arr = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
    rgb = arr[:, :, :3]

    # Balanced night-horror grade: lift subject clarity without washing out the dark atmosphere
    rgb = np.clip(rgb, 0.0, 1.0) ** 0.88
    rgb = np.clip((rgb - 0.38) * 1.15 + 0.42, 0.0, 1.0)
    rgb[:, :, 0] *= 1.04
    rgb[:, :, 1] *= 0.98
    rgb[:, :, 2] *= 0.95

    # Soft vignette (0.32 strength instead of 0.58 so the subject and background stay clearly readable!)
    y = np.linspace(-1.0, 1.0, h)[:, None]
    x = np.linspace(-1.0, 1.0, w)[None, :]
    r2 = (x * 1.0) ** 2 + (y * 1.05) ** 2
    vig = np.clip(1.0 - 0.30 * (r2 ** 1.3), 0.30, 1.0)[:, :, None]
    bot = np.clip((y + 1.0) / 0.38, 0.25, 1.0)[:, :, None]
    vig = vig * (0.35 + 0.65 * bot)
    rgb = rgb * vig

    # Fine film grain (0.022 instead of 0.048 so small mobile icons stay sharp)
    np.random.seed(2026)
    mono_noise = np.random.normal(0.0, 0.020, (h, w, 1)).astype(np.float32)
    weight = np.clip(1.0 - rgb * 0.5, 0.3, 0.9)
    rgb = np.clip(rgb + mono_noise * weight, 0.0, 1.0)

    arr[:, :, :3] = rgb
    arr[:, :, 3] = 1.0
    out_img = bpy.data.images.new("GradedV3_" + out_name, width=w, height=h, alpha=True)
    out_img.pixels[:] = arr.ravel().tolist()
    out_img.filepath_raw = os.path.join(RAW_DIR, out_name)
    out_img.file_format = "PNG"
    out_img.save()
    print("GRADED V3:", out_img.filepath_raw)


# 1) First, re-grade the existing 4 raw icons (icon1..4) with our new brighter, clearer night-horror grade!
for old_raw, new_gr in [
    ("icon1_dancer.png", "v3_graded_icon1_dancer.png"),
    ("icon2_takhon.png", "v3_graded_icon2_takhon.png"),
    ("icon3_pop.png", "v3_graded_icon3_pop.png"),
    ("icon4_pump.png", "v3_graded_icon4_pump.png"),
]:
    if os.path.exists(os.path.join(RAW_DIR, old_raw)):
        grade_and_save(old_raw, new_gr)


def render_icon(filename, graded_name, cam_loc, cam_target, lens, fstop, focus_dist, exposure, roll_deg=0.0):
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
    out_path = os.path.join(RAW_DIR, filename)
    scn.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    grade_and_save(filename, graded_name)


# ==============================================================================
# NEW ICON 5: Pop Ghost Close-Up + Glowing Barrel Gas Pump Behind (Combines the best of Icon 3 & Icon 4!)
# ==============================================================================
dyn = []
gp = append_collection_objects(
    "pop.blend",
    ["HumanRig", "Pop", "Pop_Blouse", "Pop_Sin", "Pop_Hair", "Pop_Eyes", "Pop_Fangs", "Pop_Tongue"],
    stage,
    offset=(-2.08, -3.55, 0.0),
    rot_z_deg=6.0,
    scale=1.0,
)
for o in gp:
    if o.name == "Pop_Eyes" and o.data and o.data.materials:
        em = bpy.data.materials.new("IconPopEyesV3")
        em.use_nodes = True
        bs = em.node_tree.nodes.get("Principled BSDF")
        if bs:
            bs.inputs["Base Color"].default_value = (1.0, 0.98, 0.92, 1.0)
            if "Emission Color" in bs.inputs:
                bs.inputs["Emission Color"].default_value = (1.0, 0.92, 0.82, 1.0)
                bs.inputs["Emission Strength"].default_value = 24.0
        o.data.materials[0] = em
    elif o.type == "ARMATURE":
        hb = o.pose.bones.get("head")
        if hb:
            hb.rotation_mode = "XYZ"
            hb.rotation_euler = (0.10, 0.14, -0.05)

dyn.extend(gp)
# Dramatic warm red-orange key on Pop face + crisp crimson/amber rim light + glowing gas pump on left
dyn.append(add_light(stage, "SPOT", (-1.45, -4.65, 1.82), (1.0, 0.36, 0.20), 68.0, size=0.32, target=(-2.08, -3.55, 1.42), spot_size_deg=55))
dyn.append(add_light(stage, "POINT", (-1.55, -3.05, 1.65), (1.0, 0.12, 0.14), 32.0, size=0.25))
dyn.append(add_light(stage, "POINT", (-2.95, -3.10, 1.45), (1.0, 0.48, 0.16), 38.0, size=0.3))
dyn.append(add_light(stage, "POINT", (0.4, 1.6, 2.3), (1.0, 0.55, 0.25), 35.0, size=0.4))

render_icon(
    "v3_raw_pop_pump.png",
    "v3_graded_pop_pump.png",
    cam_loc=(-1.92, -4.65, 1.42),
    cam_target=(-2.22, -3.55, 1.40),
    lens=45,
    fstop=1.8,
    focus_dist=1.14,
    exposure=0.88,
    roll_deg=-2.5,
)
clear_dynamic(dyn)

# ==============================================================================
# NEW ICON 6: KrasueV2 Floating Head & Organs + Glowing Barrel Gas Pump Behind (Dark Night Horror)
# ==============================================================================
dyn = []
kr = append_collection_objects(
    "KrasueV2/KrasueV2_rigged.blend",
    ["KrasueRig", "Krasue"],
    stage,
    offset=(-2.12, -3.55, 1.46),
    rot_z_deg=10.0,
    scale=0.95,
)
dyn.extend(kr)
dyn.append(add_light(stage, "SPOT", (-1.40, -4.75, 1.80), (1.0, 0.38, 0.22), 62.0, size=0.32, target=(-2.12, -3.55, 1.42), spot_size_deg=58))
dyn.append(add_light(stage, "POINT", (-2.12, -3.65, 1.05), (1.0, 0.12, 0.10), 34.0, size=0.25))
dyn.append(add_light(stage, "POINT", (-2.95, -3.10, 1.45), (1.0, 0.48, 0.16), 38.0, size=0.3))
dyn.append(add_light(stage, "POINT", (0.4, 1.6, 2.3), (1.0, 0.55, 0.25), 35.0, size=0.4))

render_icon(
    "v3_raw_krasue_pump.png",
    "v3_graded_krasue_pump.png",
    cam_loc=(-1.95, -4.82, 1.42),
    cam_target=(-2.24, -3.55, 1.37),
    lens=44,
    fstop=1.8,
    focus_dist=1.30,
    exposure=0.85,
    roll_deg=-2.0,
)
clear_dynamic(dyn)
print("ALL V3 ICONS DONE")
