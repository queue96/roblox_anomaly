# Saleng v2 — ซาเล้งขนโลง: หน้ารถ = มอไซค์ลูกค้ารุ่นใหม่ (customer_bike_v2.py) + กระบะไม้พ่วงข้างซ้าย + ล้อที่ 3 (ผู้ใช้ 2026-11-08 "ทำซาเล้ง")
# รัน: blender -b --factory-startup --python tools/blender/saleng_v2.py
# ผลลัพธ์: assets/models/SalengV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้เรขาคณิตมอไซค์จาก customer_bike_v2.py ตรงๆ (exec เฉพาะช่วงค่าคงที่ / วัสดุ / ชิ้นส่วน) สีตัวรถอบเป็นแดงเลือดหมูสีเดียว (ไม่สุ่ม)
# ตำแหน่งตามแม่แบบ Saleng เดิม (Roblox): ล้อหน้า/หลังเหมือนมอไซค์ · ล้อพ่วง (-3.20, 1.03, 3.20) · โลงเดิม OldCoffin (-2.40, 2.79, 2.20) ยาว 6.1 กว้าง 2.1 ก้นโลง 2.205
#   -> พื้นกระบะไม้บนสุด 2.20 (Blender x 1.15..3.65, y -1.15..5.55) ล้อพ่วงอยู่ใต้พื้น (บนสุดล้อ 2.06)
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "SalengV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.TEX = int(os.environ.get("VEH_TEX", "1024"))
V.SAMPLES = int(os.environ.get("VEH_SAMPLES", "16"))
NO_BAKE = os.environ.get("VEH_NOBAKE") == "1"
S = V.S


def log(*a):
    print("SL|", *a)


# ---------------------------------------------------------------- ดึงส่วนปั้นของมอไซค์มาใช้
bike_src = open(os.path.join(HERE, "customer_bike_v2.py"), encoding="utf-8").read()


def between(a, b):
    i = bike_src.index(a)
    return bike_src[i:bike_src.index(b, i)]


ns = {k: getattr(V, k) for k in dir(V) if not k.startswith("__")}
ns.update({"math": math, "Vector": Vector, "Matrix": Matrix, "bpy": bpy, "os": os, "make_mat": V.make_mat})
exec(between("FRONT_Y, REAR_Y, AXLE_Z, TIRE_R", "def log"), ns)
V.FRONT_Y, V.AXLE_Z, V.TREAD_N = ns["FRONT_Y"], ns["AXLE_Z"], 34.0
exec(between("# สีตัวรถ: อบเป็นสีเทาอ่อน", "# ---------------------------------------------------------------- ประกอบชิ้น -> object"), ns)
# ซาเล้ง: สีเดียว แดงเลือดหมูซีด (อบลงภาพเลย ไม่ย้อมในเกม)
L = V.L
V.make_mat("paint", L((124, 26, 26)), 0.4, 0.0, dirt=0.5, wear=0.5, bump=0.04, bump_scale=120, stripe=(1.98, 2.06, L((190, 186, 176))), coat=0.35)
V.make_mat("paint_fender", L((124, 26, 26)), 0.44, 0.0, dirt=0.75, wear=0.5, bump=0.05, bump_scale=120)
exec(between("# ================================================================ ล้อ", "# ---------------------------------------------------------------- สร้าง object ทั้งหมด"), ns)
P = V.PARTS
P["Saleng"] = P.pop("CustomerBike") + P.pop("BodyPaint")
P["Handlebar"] = P["Handlebar"] + P.pop("HandlebarPaint")

# ---------------------------------------------------------------- วัสดุกระบะ
V.make_mat("wood", L((112, 84, 58)), 0.75, 0.0, dirt=0.6, wear=0.2, bump=0.4, bump_scale=8)
V.make_mat("wood_dark", L((70, 50, 36)), 0.8, 0.0, dirt=0.7, bump=0.35, bump_scale=8)
V.make_mat("frame_rust", L((60, 44, 34)), 0.6, 0.5, dirt=0.6, rust=0.7)
G, tube, box, lathe_axis, put = V.G, V.tube, V.box, V.lathe_axis, V.put
SL = "Saleng"
X0, X1, Y0, Y1, BED = 1.15, 3.65, -1.15, 5.55, 2.20
# พื้นกระดานไม้ (แผ่นตามยาว เว้นร่อง)
n = 7
for k in range(n):
    w = (X1 - X0) / n
    x = X0 + w * (k + 0.5)
    put(SL, box((x, (Y0 + Y1) / 2, BED - 0.05), (w - 0.035, Y1 - Y0, 0.10)), "wood", 0, bevel=0.015)
# คานรองใต้พื้น + โครงเหล็ก
for y in (Y0 + 0.3, 1.2, 3.2, Y1 - 0.3):
    put(SL, box(((X0 + X1) / 2, y, BED - 0.16), (X1 - X0, 0.18, 0.13)), "wood_dark", 0, bevel=0.02)
for x in (X0 + 0.12, X1 - 0.12):
    put(SL, tube([(x, Y0, BED - 0.25), (x, Y1, BED - 0.25)], 0.05, 8), "frame_rust", 0)
# ขอบกั้นเตี้ยๆ รอบกระบะ (ไม้) + เสามุม
for (xa, xb, ya, yb) in ((X0, X1, Y0, Y0 + 0.08), (X0, X1, Y1 - 0.08, Y1), (X1 - 0.08, X1, Y0, Y1)):
    put(SL, box(((xa + xb) / 2, (ya + yb) / 2, BED + 0.17), (xb - xa, yb - ya, 0.34)), "wood_dark", 0, bevel=0.015)
put(SL, box((X0 + 0.04, (Y0 + Y1) / 2, BED + 0.08), (0.08, Y1 - Y0, 0.16)), "wood_dark", 0, bevel=0.015)
for (x, y) in ((X0 + 0.05, Y0 + 0.05), (X1 - 0.05, Y0 + 0.05), (X0 + 0.05, Y1 - 0.05), (X1 - 0.05, Y1 - 0.05)):
    put(SL, box((x, y, BED + 0.22), (0.1, 0.1, 0.44)), "frame_rust", 0, bevel=0.01)
# แขนต่อกับตัวมอไซค์ (เหล็ก): ใต้พื้นกลาง + หน้า + ท้าย
for (pa, pb) in (((0.30, 0.10, 1.15), (X0 + 0.12, 0.10, BED - 0.25)), ((0.35, 1.95, 1.25), (X0 + 0.12, 1.95, BED - 0.25)), ((0.24, 2.45, 2.20), (X0 + 0.12, 2.6, BED - 0.25))):
    put(SL, tube([pa, pb], 0.055, 8), "frame_rust", 0)
# ล้อพ่วง: แกน + บังโคลนเหล็กเหนือล้อ (ใต้พื้น)
WX, WY = 3.20, 3.20
put(SL, tube([(X0 + 0.12, WY, BED - 0.25), (WX + 0.25, WY, 1.03 + 0.2), (WX + 0.25, WY, 1.03)], 0.05, 8), "frame_rust", 0)
put(SL, tube([(WX - 0.25, WY, BED - 0.25), (WX - 0.25, WY, 1.03)], 0.05, 8), "frame_rust", 0)
put(SL, tube([(WX - 0.3, WY, 1.03), (WX + 0.32, WY, 1.03)], 0.05, 8), "frame_rust", 0)
# ล้อที่ 3 = ล้อหลังมอไซค์ ย้ายไปข้างกระบะ
def moved(g, dx, dy):
    m = G()
    m.v = [(x + dx, y + dy, z) for x, y, z in g.v]
    m.f = list(g.f)
    return m


P["SidecarWheel"] = [(moved(g, WX, WY - ns["REAR_Y"]), mat, sd, sm, bv) for (g, mat, sd, sm, bv) in P["RearWheel"]]

# ---------------------------------------------------------------- object + bake + export
ORDER = ["Saleng", "Handlebar", "FrontWheel", "RearWheel", "SidecarWheel", "Headlight_Neon", "Taillight_Neon", "LicensePlateFrame"]
OBJ = {nm: V.build_object(nm) for nm in ORDER}
pfo = OBJ["LicensePlateFrame"]
piv = Vector((0, 3.36, 1.62)) * S
pfo.data.transform(Matrix.Translation(piv) @ Matrix.Rotation(math.radians(8), 4, "X") @ Matrix.Translation(-piv))
for nm, ob in OBJ.items():
    cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
    c = (mn + mx) / 2
    log(f"BBOX {nm} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({mx.x - mn.x:.3f},{mx.z - mn.z:.3f},{mx.y - mn.y:.3f})")

BAKED = {"Saleng": "SalengV2", "Handlebar": "SalengV2_Handlebar", "FrontWheel": "SalengV2_Wheel", "LicensePlateFrame": "SalengV2_Plate"}
if not NO_BAKE:
    done = {}
    for nm, stem in BAKED.items():
        ob = OBJ[nm]
        V.uv_unwrap(ob)
        log("baking", nm)
        done[nm] = V.final_material(stem, V.bake(ob, stem))
    # ล้อหลัง/ล้อพ่วง = ล้อหน้าเป๊ะ (mesh เดียวกัน): ก๊อป UV ของล้อหน้าตรงๆ (unwrap ใหม่ได้ผังไม่ตรงภาพ ลายล้อพ่วงเพี้ยน)
    src_uv = OBJ["FrontWheel"].data.uv_layers.active.data
    for nm in ("RearWheel", "SidecarWheel"):
        me = OBJ[nm].data
        uvl = me.uv_layers.active or me.uv_layers.new(name="UVMap")
        assert len(uvl.data) == len(src_uv), (nm, len(uvl.data), len(src_uv))
        for i in range(len(src_uv)):
            uvl.data[i].uv = src_uv[i].uv
    for nm, mat in list(done.items()) + [("RearWheel", done["FrontWheel"]), ("SidecarWheel", done["FrontWheel"])]:
        ob = OBJ[nm]
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0
    for nm, col in (("Headlight_Neon", (1.0, 0.88, 0.62)), ("Taillight_Neon", (0.8, 0.03, 0.03))):
        ob = OBJ[nm]
        ob.data.materials.clear()
        ob.data.materials.append(V.neon_material(nm + "_Mat", col))

bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ["Saleng"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "SalengV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "SalengV2.fbx"))


# ---------------------------------------------------------------- ภาพตัวอย่าง (+ โลงศพแทนชิ้นเดิมในเกม เฉพาะในภาพ)
def preview():
    scn = bpy.context.scene
    cof = V.G()
    cof.merge(V.box((2.40, 2.20, 2.79), (2.1, 6.1, 1.17)))
    cof.merge(V.box((2.40, 2.20, 3.66), (2.17, 6.16, 0.61)))
    me = bpy.data.meshes.new("Coffin")
    me.from_pydata([tuple(Vector(p) * S) for p in cof.v], [], cof.f)
    co = bpy.data.objects.new("Coffin", me)
    cm = bpy.data.materials.new("C")
    cm.use_nodes = True
    cm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.08, 0.05, 1)
    me.materials.append(cm)
    scn.collection.objects.link(co)
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
    gm = bpy.data.materials.new("G")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.25, 0.2, 0.15, 1)
    gp.materials.append(gm)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    tgt = Vector((1.2, 1.0, 2.0)) * S

    def shot(fn, d, dist=3.6, lens=50):
        cam.data.lens = lens
        cam.location = tgt + Vector(d).normalized() * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    shot("SalengV2.png", (1.0, -1.2, 0.6))
    shot("SalengV2_rear.png", (0.6, 1.3, 0.55))
    shot("SalengV2_side.png", (-1.0, 0.0, 0.12))


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "saleng_v2.blend"))
log("done")
