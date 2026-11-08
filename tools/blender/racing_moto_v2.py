# ThaiRacingMoto v2 — มอไซค์แต่งเด็กแว้น / รถพี่ชายในคัทซีนเปิด (ผู้ใช้ 2026-11-08 "โมเดลรถแต่งที่เด็กแว้นขี่ ที่เรานั่งมาตอนแรก")
# รัน: blender -b --factory-startup --python tools/blender/racing_moto_v2.py
# ผลลัพธ์: assets/models/RacingMotoV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# = มอไซค์ลูกค้ารุ่นใหม่ (customer_bike_v2.py exec เฉพาะช่วงค่าคงที่/วัสดุ/ชิ้นส่วน) ย่อ 0.917 (ล้อ r 0.945 เท่าแม่แบบเดิม) แล้วแต่งซิ่ง:
#   สีส้มคาดขาว · ขอบล้อทอง ซี่ลวดสีรุ้ง · หม้อพักสีม่วงไทเท · ถอดตะกร้าหน้า/ตะแกรงหลัง
# ตำแหน่งในเกม (Roblox, ย่อจากมอไซค์ลูกค้าแล้ว) — MapBuilder.SwapRacingMotoV2 ย้ายชิ้นเกมเพลย์ของแม่แบบมาตรงนี้:
#   ล้อ (0, 0.945, ±1.926) · ไฟหน้า (0, 3.08, -1.49) · ไฟท้าย (0, 2.08, 2.81) · ป้าย (0, 1.49, 3.08) · เบาะซ้อนบน 2.39 ที่ z 1.60
#   คนขับ (CoreLoop.humanizeDriver เมื่อ RacingVersion = 2): สะโพก (0, 2.66, 0.69) มือ สะโพก + (±0.87, 0.67, -1.65) เท้า สะโพก + (±0.64, -1.63, -0.32)
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "RacingMotoV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = int(os.environ.get("VEH_TEX", "1024"))
V.SAMPLES = int(os.environ.get("VEH_SAMPLES", "16"))
NO_BAKE = os.environ.get("VEH_NOBAKE") == "1"
S = V.S
K = 0.945 / 1.03  # ย่อทั้งคัน


def log(*a):
    print("RM|", *a)


bike_src = open(os.path.join(HERE, "customer_bike_v2.py"), encoding="utf-8").read()


def between(a, b):
    i = bike_src.index(a)
    return bike_src[i:bike_src.index(b, i)]


ns = {k: getattr(V, k) for k in dir(V) if not k.startswith("__")}
ns.update({"math": math, "Vector": Vector, "Matrix": Matrix, "bpy": bpy, "os": os, "make_mat": V.make_mat})
exec(between("FRONT_Y, REAR_Y, AXLE_Z, TIRE_R", "def log"), ns)
# ดอกยาง / ซี่ลวดสีรุ้ง วัดมุมรอบดุมล้อหน้า "หลังย่อ" (bake ทำหลังย่อแล้ว)
V.FRONT_Y, V.AXLE_Z, V.TREAD_N = ns["FRONT_Y"] * K, ns["AXLE_Z"] * K, 34.0
exec(between("# สีตัวรถ: อบเป็นสีเทาอ่อน", "# ---------------------------------------------------------------- ประกอบชิ้น -> object"), ns)
L = V.L
V.make_mat("paint", L((232, 92, 20)), 0.3, 0.0, dirt=0.35, wear=0.35, bump=0.03, bump_scale=120, stripe=(1.98, 2.06, L((245, 245, 240))), coat=0.7)
V.make_mat("paint_fender", L((232, 92, 20)), 0.32, 0.0, dirt=0.5, wear=0.35, bump=0.04, bump_scale=120)
V.make_mat("rim_gold", L((214, 168, 58)), 0.22, 1.0, dirt=0.3)
V.make_mat("pipe_purple", L((112, 52, 168)), 0.2, 1.0, dirt=0.3)
V.make_mat("lens_white", L((236, 232, 220)), 0.12, 0.0, dirt=0.2)
V.make_mat("lens_red", L((170, 20, 18)), 0.15, 0.0, dirt=0.2)


def rainbow_mat(name):
    """ซี่ลวดสีรุ้ง: สีไล่ตามมุมรอบดุมล้อ (โลหะเงา)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bs = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], out.inputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sub = nt.nodes.new("ShaderNodeVectorMath")
    sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = (0.0, V.FRONT_Y * S, V.AXLE_Z * S)
    nt.links.new(tc.outputs["Object"], sub.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(sub.outputs[0], sep.inputs[0])
    at = nt.nodes.new("ShaderNodeMath")
    at.operation = "ARCTAN2"
    nt.links.new(sep.outputs["Z"], at.inputs[0])
    nt.links.new(sep.outputs["Y"], at.inputs[1])
    h = nt.nodes.new("ShaderNodeMath")
    h.operation = "MULTIPLY_ADD"
    h.inputs[1].default_value = 1.0 / (2 * math.pi)
    h.inputs[2].default_value = 0.5
    nt.links.new(at.outputs[0], h.inputs[0])
    hsv = nt.nodes.new("ShaderNodeCombineColor")
    hsv.mode = "HSV"
    hsv.inputs[1].default_value = 0.85
    hsv.inputs[2].default_value = 0.85
    nt.links.new(h.outputs[0], hsv.inputs[0])
    nt.links.new(hsv.outputs[0], bs.inputs["Base Color"])
    bs.inputs["Metallic"].default_value = 0.85
    bs.inputs["Roughness"].default_value = 0.25
    V.MATS[name] = m
    return m


rainbow_mat("spoke_rainbow")
exec(between("# ================================================================ ล้อ", "# ---------------------------------------------------------------- สร้าง object ทั้งหมด"), ns)
P = V.PARTS


def center(g):
    n = len(g.v)
    return [sum(p[i] for p in g.v) / n for i in range(3)]


def minz(g):
    return min(p[2] for p in g.v)


# ถอดตะกร้าหน้า + ตะแกรงหลัง (ชิ้นตามตำแหน่ง/วัสดุ) · หม้อพักเป็นสีม่วง
body = []
for (g, mat, sd, sm, bv) in P.pop("CustomerBike") + P.pop("BodyPaint") + P.pop("LicensePlateFrame"):
    cx, cy, cz = center(g)
    if mat == "steel_black" and cy < -1.7 and cz > 2.0:
        continue  # ตะกร้า + ขายึด
    if mat == "chrome" and cy > 1.3 and minz(g) > 2.1:
        continue  # ตะแกรงหลัง
    if mat == "steel_black" and cx < -0.3 and cz < 1.2:
        mat = "pipe_purple"
    body.append((g, mat, sd, sm, bv))
for (g, mat, sd, sm, bv) in P.pop("Taillight_Neon"):
    body.append((g, "lens_red", sd, sm, bv))
front = P.pop("Handlebar") + P.pop("HandlebarPaint")
for (g, mat, sd, sm, bv) in P.pop("Headlight_Neon"):
    front.append((g, "lens_white", sd, sm, bv))
P["RaceBody"] = body
P["RaceFront"] = front
# ล้อ: ขอบล้อทอง ซี่ลวดสีรุ้ง (ลำดับชิ้นใน wheel(): ยาง, ขอบล้อ, ดุม, ดรัม, ซี่ลวด, แกน)
wheel = P.pop("FrontWheel")
P.pop("RearWheel")
wheel = [(g, ("rim_gold" if i == 1 else "spoke_rainbow" if i == 4 else mat), sd, sm, bv) for i, (g, mat, sd, sm, bv) in enumerate(wheel)]
P["RaceWheel"] = wheel
# ย่อทั้งคันรอบ origin (พื้นใต้กึ่งกลาง)
for nm in list(P.keys()):
    out = []
    for (g, mat, sd, sm, bv) in P[nm]:
        h = V.G()
        h.v = [(x * K, y * K, z * K) for x, y, z in g.v]
        h.f = list(g.f)
        out.append((h, mat, sd, sm, bv * K if bv else bv))
    P[nm] = out
# กรอบป้ายเอียง 8° (เหมือนมอไซค์ลูกค้า) ทำใน mesh: ชิ้นกรอบป้ายอยู่ใน RaceBody แล้ว (ไม่เอียง) — ป้ายในเกมใช้ชิ้นป้ายเดิมของแม่แบบ

ORDER = ["RaceBody", "RaceFront", "RaceWheel"]
OBJ = {nm: V.build_object(nm) for nm in ORDER}
for nm, ob in OBJ.items():
    cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c = (mn + mx) / 2
    sz = mx - mn
    log(f"BBOX {nm} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({sz.x:.3f},{sz.z:.3f},{sz.y:.3f})")

BAKED = {"RaceBody": "RacingMotoV2_Body", "RaceFront": "RacingMotoV2_Front", "RaceWheel": "RacingMotoV2_Wheel"}
if not NO_BAKE:
    for nm, stem in BAKED.items():
        ob = OBJ[nm]
        V.uv_unwrap(ob)
        log("baking", nm)
        mat = V.final_material(stem, V.bake(ob, stem))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0

bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ["RaceBody"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "RacingMotoV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "RacingMotoV2.fbx"))


def preview():
    scn = bpy.context.scene
    wob = OBJ["RaceWheel"]
    c = wob.copy()
    c.data = wob.data
    scn.collection.objects.link(c)
    c.matrix_world = Matrix.Translation(Vector((0, (ns["REAR_Y"] - ns["FRONT_Y"]) * K, 0)) * S)
    rider = []
    path = os.path.join(ROOT, "human_base", "human_base.blend")
    if os.path.exists(path):
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_wan_denim") or n == "Hair_student"]
            dst.actions = [n for n in src.actions if n == "ride_moto"]
        rider = [o for o in dst.objects if o]
        for o in rider:
            scn.collection.objects.link(o)
        rig = next((o for o in rider if o.type == "ARMATURE"), None)
        if rig and dst.actions:
            rig.animation_data_create()
            rig.animation_data.action = dst.actions[0]
            scn.frame_set(1)
            rig.location = Vector((0, 0.69, 2.66)) * S - rig.data.bones["hips"].head_local
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1200, 800
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-6, -6, 0), (6, -6, 0), (6, 6, 0), (-6, 6, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gmat = bpy.data.materials.new("G")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.2, 0.15, 1)
    gp.materials.append(gmat)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((0, 0.0, 1.9)) * S

    def shot(fn, d, dist=2.9, lens=50, show_rider=False):
        for o in rider:
            o.hide_render = not show_rider
        cam.data.lens = lens
        cam.location = tgt + Vector(d).normalized() * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    shot("RacingMotoV2.png", (-0.9, -1.2, 0.5))
    shot("RacingMotoV2_side.png", (1.0, 0.0, 0.08), dist=3.0)
    shot("RacingMotoV2_rear.png", (0.7, 1.3, 0.45))
    if rider:
        shot("RacingMotoV2_rider_side.png", (1.0, 0.0, 0.08), dist=3.4, show_rider=True)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "racing_moto_v2.blend"))
log("done")
