# ภาพตัวอย่างชุดวัดตอนกลางคืน จัดวางเหมือน MapBuilder.BuildTempleLobby() (ไม่เซฟทับไฟล์ .blend)
# รัน: blender-launcher.exe --background assets/models/thai_temple.blend --python tools/blender/thai_temple_preview.py
import bpy, math, os
from mathutils import Vector, Euler

S = 0.28
PREV = r"C:\Aunival\pump-lot-anomaly\assets\models\previews"
UNITS = {
    "TempleGate": ["TempleGate", "TempleGate_Buddha"],
    "TempleNameSign": ["TempleNameSign", "TempleNameSign_Plaque"],
    "FenceSegment": ["FenceSegment"],
    "FenceSegment_Half": ["FenceSegment_Half"],
    "BoneStupa_A": ["BoneStupa_A"], "BoneStupa_B": ["BoneStupa_B"], "BoneStupa_C": ["BoneStupa_C"],
    "Meru": ["Meru_Base", "Meru_Hall", "Meru_Roof", "Meru_Chimney"],
    "Ubosot": ["Ubosot_Base", "Ubosot_Walls", "Ubosot_Columns", "Ubosot_Roof", "Ubosot_KaewWall"],
    "Kuti": ["Kuti_Stilts", "Kuti_House", "Kuti_Roof"],
    "Sala": ["Sala_Base", "Sala_Columns", "Sala_Roof"],
    "BuddhaTrio": ["BuddhaTrio_Base", "BuddhaTrio_Plaques", "Buddha_Center", "Buddha_Left", "Buddha_Right"],
    "DonationBoard": ["DonationBoard", "DonationBoard_Board", "DonationBoard_Face"],
    "DonationBox": ["DonationBox_Stand", "DonationBox", "DonationBox_Door", "DonationBox_Glass"],
    "ShopCart": ["ShopCart", "ShopCart_Goods", "ShopCart_Canopy", "ShopCart_Sign"],
}
scn = bpy.context.scene
coll = bpy.data.collections.new("LobbyPreview")
scn.collection.children.link(coll)
for c in bpy.data.collections:
    if c is not coll:
        c.hide_render = True


def place(unit, x, z, yaw=0.0, y=0.0, scale=1.0):
    """x, y, z = ตำแหน่งแบบ Roblox (studs) yaw = องศารอบแกนตั้ง"""
    for n in UNITS[unit]:
        src = bpy.data.objects[n]
        o = src.copy()
        coll.objects.link(o)
        o.location = Vector((x * S, -z * S, y * S))
        o.rotation_euler = Euler((0, 0, math.radians(yaw)))
        o.scale = (scale, scale, scale)


FRONT, BACK, X = 62, -70, 81
place("TempleGate", 0, FRONT)
place("TempleNameSign", 24, FRONT + 5)


def run(x, z, yaw, length):
    d = 0
    a = math.radians(yaw)
    while length - d >= 6:
        unit = "FenceSegment" if length - d >= 12 else "FenceSegment_Half"
        place(unit, x + d * math.cos(a), z - d * math.sin(a), yaw)
        d += 12 if unit == "FenceSegment" else 6


run(9, FRONT, 0, X - 9)
run(X, FRONT, 90, FRONT - BACK)
run(X, BACK, 180, 2 * X)
run(-X, BACK, -90, FRONT - BACK)
run(-X, FRONT, 0, X - 9)
place("Ubosot", 0, -12)
place("BuddhaTrio", 0, -27.6, 0, 2.86, 1.2)
place("Sala", -55, 25, 90)
place("BuddhaTrio", -55 - 10.81, 25, 90, 2.99, 1.4)
place("Kuti", 66, 40, -90)
place("Kuti", 66, 8, -90)
place("Meru", -55, -45)
place("DonationBoard", -24, 50, 180)
place("DonationBox", -8.5, 28, 90)
place("ShopCart", 22, 44, -90)
import random
random.seed(907)
kinds = ["BoneStupa_A", "BoneStupa_B", "BoneStupa_C"]
i = 0
for r in range(3):
    for c in range(4):
        i += 1
        place(kinds[(i * 7 + random.randint(0, 2)) % 3], -38 + c * 6.5 + (r % 2) * 2, -62 + r * 7, random.choice((-4, 0, 4)))
for r in range(2):
    for c in range(4):
        i += 1
        place(kinds[(i * 7 + random.randint(0, 2)) % 3], 28 + c * 6.5, -63 + r * 7, random.choice((-4, 0, 4)))

# พื้น
bpy.ops.mesh.primitive_plane_add(size=1)
g = bpy.context.active_object
g.scale = (200 * S, 176 * S, 1)
g.location = (0, 2 * S, 0)
gm = bpy.data.materials.new("Ground")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.045, 0.038, 0.03, 1)
gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
g.data.materials.append(gm)
for c in list(g.users_collection):
    c.objects.unlink(g)
coll.objects.link(g)

# แสงกลางคืน: ท้องฟ้าน้ำเงินมืด จันทร์สีฟ้า หมอกบางๆ ไฟเทียนในโบสถ์ ไฟแดงที่เตาเผา
world = bpy.data.worlds.new("Night")
scn.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.012, 0.018, 0.04, 1)
bg.inputs[1].default_value = 1.0
vol = world.node_tree.nodes.new("ShaderNodeVolumePrincipled")
vol.inputs["Color"].default_value = (0.42, 0.48, 0.56, 1)
vol.inputs["Density"].default_value = 0.012
world.node_tree.links.new(vol.outputs[0], world.node_tree.nodes["World Output"].inputs["Volume"])


def light(kind, loc, color, energy, size=0.5, rot=None):
    ld = bpy.data.lights.new(kind + "L", kind)
    ld.color = color
    ld.energy = energy
    if kind == "SUN":
        ld.angle = math.radians(2)
    else:
        ld.shadow_soft_size = size
    o = bpy.data.objects.new(kind, ld)
    o.location = loc
    if rot:
        o.rotation_euler = rot
    coll.objects.link(o)


light("SUN", (0, 0, 30), (0.62, 0.72, 1.0), 0.45, rot=Euler((math.radians(50), 0, math.radians(-140))))
light("POINT", (0, 20 * S, 9 * S), (1.0, 0.62, 0.3), 260, 0.3)
light("POINT", (-55 * S, 42.4 * S, 7.5 * S), (1.0, 0.27, 0.15), 120, 0.3)
light("POINT", (0, -(FRONT - 3) * S, 15 * S), (0.75, 0.82, 1.0), 300, 0.5)
light("POINT", (64 * S, -40 * S, 15 * S), (1.0, 0.68, 0.38), 60, 0.3)
light("POINT", (-58.5 * S, -25 * S, 11 * S), (0.78, 0.84, 1.0), 120, 0.5)
light("POINT", (21 * S, -44 * S, 10.5 * S), (1.0, 0.84, 0.6), 90, 0.3)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
coll.objects.link(cam)
scn.camera = cam
scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scn.render.resolution_x = 1600
scn.render.resolution_y = 900
try:
    scn.eevee.taa_render_samples = 48
    scn.eevee.use_shadows = True
    scn.eevee.volumetric_end = 120
except Exception:
    pass
scn.view_settings.view_transform = "AgX" if "AgX" in [v.identifier for v in bpy.types.ColorManagedViewSettings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
scn.view_settings.exposure = 1.6


ONLY_SHOTS = [x for x in os.environ.get("TEMPLE_SHOTS", "").split(",") if x]


def shot(name, loc, target, lens=28, exposure=1.6):
    if ONLY_SHOTS and name not in ONLY_SHOTS:
        return
    scn.view_settings.exposure = exposure
    cam.location = Vector(loc) * S
    cam.data.lens = lens
    cam.rotation_euler = (Vector(target) * S - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(PREV, name + ".png")
    bpy.ops.render.render(write_still=True)


# จุดกล้องเป็นแกน Blender ในหน่วย studs (x, y = -Z ของ Roblox, z = สูง)
shot("ThaiTemple_Night_Overview", (70, -150, 70), (0, 0, 5), 26, 3.4)
shot("ThaiTemple_Night_Gate", (14, -100, 7), (0, -40, 14), 24)
shot("ThaiTemple_Night_Ubosot", (10, -46, 6), (0, 10, 11), 22)
shot("ThaiTemple_Night_Meru", (-20, 20, 8), (-50, 48, 14), 26)
shot("ThaiTemple_Night_Sala", (-15, -40, 7), (-55, -25, 6), 28)
shot("ThaiTemple_Night_LobbyProps", (6, -60, 9), (-6, -40, 8), 18, 2.0)
shot("ThaiTemple_Night_Kuti", (22, -12, 8), (62, -40, 13), 26)
open(os.path.join(PREV, "_night_done.txt"), "w").write("ok")
