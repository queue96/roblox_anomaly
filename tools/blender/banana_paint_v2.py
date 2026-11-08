# กอกล้วย — ลงสีใหม่ให้สมจริง (ผู้ใช้ 2026-11-08: "รูปลักษณ์โอเคแล้ว ช่วยลงสี/เฉดให้สมจริงกว่านี้")
# รัน: blender -b --factory-startup --python tools/blender/banana_paint_v2.py
# ผลลัพธ์: assets/models/BananaPaintV2/upload/ (FBX + texture = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง เทียบเก่า/ใหม่
#
# ใช้ mesh + UV เดิมทุกจุด (assets/models/BananaClump.fbx = กอกล้วย 28 กอในฉาก) แล้ว bake สีใหม่ลง UV เดิม (ภาพเดียวใช้ร่วม 3 ชิ้น เหมือนเดิม)
#   -> ในเกมแค่เปลี่ยน SurfaceAppearance ของชิ้นเดิม (MapBuilder.RepaintBananaV2) ไม่ต้องวางต้นใหม่
# ชั้นสี (อ่านชนิดผิวจากภาพเดิม: เขียว = ใบสด / น้ำตาล = ใบแห้ง กาบ ลำต้น ดิน):
#   ใบสด: เขียวเข้ม-เขียวอมเหลือง ต่างกันทีละใบ (noise ใหญ่) · ใบยอด (สูง) อ่อนสด ใบล่างเข้ม · ขอบใบแห้งน้ำตาล (pointiness ขอบริ้วใบ)
#         ด่างเหลือง + จุดน้ำตาล (โรคใบจุด) · ด้านใต้ใบ (หันลง) เขียวซีดอมเงิน · คงลายเส้นใบจากภาพเดิม (ความสว่าง)
#   ใบแห้ง/กาบ: ฟาง-น้ำตาลเข้ม ลายเส้นใยเดิม ด่างคล้ำ · ลำต้น: เขียวหม่น ลายด่างม่วงดำ โคนคล้ำชื้น · ดิน: น้ำตาลเข้มชื้น
import bpy, math, os, sys, shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "BananaPaintV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
TEX = 1024
SAMPLES = 16


def log(*a):
    print("BN|", *a)


def L(c):
    return tuple(((x / 255) / 12.92) if x / 255 <= 0.04045 else (((x / 255) + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, "BananaClump.fbx"))
OBJS = [o for o in bpy.data.objects if o.type == "MESH"]
log("objects", [o.name for o in OBJS])
old_col = bpy.data.images.load(os.path.join(ROOT, "BananaClump_Color.png"))
old_nrm = bpy.data.images.load(os.path.join(ROOT, "BananaClump_Normal.png"))
old_nrm.colorspace_settings.name = "Non-Color"

# ขนาดทั้งกอ (สำหรับไล่ความสูง)
zs = [(o.matrix_world @ v.co).z for o in OBJS for v in o.data.vertices]
ZMIN, ZMAX = min(zs), max(zs)


def N(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def mix(nt, a, b, fac, blend="MIX"):
    m = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type=blend, clamp_factor=True)
    nt.links.new(fac, m.inputs["Factor"])
    for sock, src in ((m.inputs["A"], a), (m.inputs["B"], b)):
        if isinstance(src, tuple):
            sock.default_value = src
        else:
            nt.links.new(src, sock)
    return m.outputs["Result"]


def math_(nt, op, a, b=None, clamp=False):
    m = N(nt, "ShaderNodeMath", operation=op, use_clamp=clamp)
    for i, src in enumerate((a, b)):
        if src is None:
            continue
        if isinstance(src, (int, float)):
            m.inputs[i].default_value = src
        else:
            nt.links.new(src, m.inputs[i])
    return m.outputs[0]


def maprange(nt, v, a, b, c=0.0, d=1.0):
    m = N(nt, "ShaderNodeMapRange", clamp=True)
    nt.links.new(v, m.inputs["Value"])
    m.inputs["From Min"].default_value, m.inputs["From Max"].default_value = a, b
    m.inputs["To Min"].default_value, m.inputs["To Max"].default_value = c, d
    return m.outputs["Result"]


def noise(nt, vec, scale, detail=4.0, rough=0.55):
    t = N(nt, "ShaderNodeTexNoise")
    t.inputs["Scale"].default_value = scale
    t.inputs["Detail"].default_value = detail
    t.inputs["Roughness"].default_value = rough
    nt.links.new(vec, t.inputs["Vector"])
    return t.outputs["Fac"]


def build_material():
    m = bpy.data.materials.new("BananaPaintV2")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = N(nt, "ShaderNodeOutputMaterial")
    bs = N(nt, "ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], out.inputs[0])
    uv = N(nt, "ShaderNodeUVMap", uv_map="UVMap")
    tc = N(nt, "ShaderNodeTexCoord")
    geo = N(nt, "ShaderNodeNewGeometry")
    sep = N(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    oc = N(nt, "ShaderNodeTexImage", image=old_col)
    nt.links.new(uv.outputs[0], oc.inputs[0])
    sc = N(nt, "ShaderNodeSeparateColor")
    nt.links.new(oc.outputs["Color"], sc.inputs[0])
    R, Gc, B = sc.outputs[0], sc.outputs[1], sc.outputs[2]
    # ชนิดผิวจากภาพเดิม (วัดต่อหน้า: ทั้ง 3 ชิ้นเป็นกอคนละแบบ สัดส่วนเท่ากัน)
    #   gdom > 0.1 = แผ่นใบ · 0-0.05 = ลำต้นเทียม/ก้านใบ/เส้นกลางใบ (เขียวหม่น) · < 0 = ใบแห้ง กาบ ดิน
    gdom = math_(nt, "SUBTRACT", Gc, math_(nt, "MAXIMUM", R, B))
    leafm = maprange(nt, gdom, 0.06, 0.1)
    # ดิน = มืดมาก / ลำต้น = เขียวหม่น (ภาพเดิม: ลำต้นอยู่ในช่วงน้ำตาลอมเขียว)
    lum = N(nt, "ShaderNodeRGBToBW")
    nt.links.new(oc.outputs["Color"], lum.inputs[0])
    detail = math_(nt, "DIVIDE", lum.outputs[0], 0.28)  # ลายเส้นใบ/เส้นใยเดิม (ความสว่างสัมพัทธ์)
    detail = maprange(nt, detail, 0.4, 1.6, 0.72, 1.18)
    obj = tc.outputs["Object"]
    big = noise(nt, obj, 0.35, 3)       # ทีละใบ/ทีละกอ
    mid = noise(nt, obj, 1.4, 5)
    fine = noise(nt, obj, 6.0, 6)
    h = maprange(nt, sep.outputs["Z"], ZMIN + (ZMAX - ZMIN) * 0.25, ZMAX)  # 0 ล่าง -> 1 ยอด
    # ---------------- ใบสด
    # สีพื้นต่างกันทีละใบ: เขียวเข้มอมน้ำเงิน <-> เขียวกล้วยอมเหลือง
    hue = noise(nt, obj, 0.22, 2)
    c = mix(nt, L((46, 88, 40)), L((82, 126, 40)), maprange(nt, hue, 0.3, 0.7))
    c = mix(nt, c, L((104, 142, 46)), math_(nt, "MULTIPLY", maprange(nt, big, 0.45, 0.75), 0.8))
    # ใบยอด (สูง) อ่อนสดอมเหลือง
    c = mix(nt, c, L((140, 166, 62)), math_(nt, "MULTIPLY", maprange(nt, h, 0.6, 1.0), maprange(nt, mid, 0.3, 0.7), clamp=True))
    # ด่างเหลืองเป็นปื้น + ใบล่างเหลืองมากกว่า
    low = math_(nt, "SUBTRACT", 1.0, h)
    yel = math_(nt, "MULTIPLY", maprange(nt, mid, 0.58, 0.74), math_(nt, "ADD", 0.3, low), clamp=True)
    c = mix(nt, c, L((176, 160, 70)), yel)
    # จุดใบไหม้ (โรคใบจุด) น้ำตาลมีขอบเหลือง
    halo = maprange(nt, fine, 0.64, 0.7)
    c = mix(nt, c, L((168, 150, 66)), math_(nt, "MULTIPLY", halo, 0.6))
    c = mix(nt, c, L((84, 56, 32)), maprange(nt, fine, 0.7, 0.75))
    # ขอบริ้วใบแห้ง (pointiness สูงตรงขอบเปิดของริ้วใบ) + ใบล่างแห้งมากกว่า
    edge = maprange(nt, geo.outputs["Pointiness"], 0.51, 0.57)
    edge = math_(nt, "MULTIPLY", edge, maprange(nt, fine, 0.2, 0.55), clamp=True)
    edge = math_(nt, "MULTIPLY", edge, math_(nt, "ADD", 0.5, low), clamp=True)
    c = mix(nt, c, L((150, 118, 66)), edge)
    # ด้านใต้ใบ (หันลง) เขียวซีดอมเงิน
    nz = N(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], nz.inputs[0])
    under = maprange(nt, nz.outputs["Z"], 0.05, -0.55)
    c = mix(nt, c, L((132, 150, 116)), math_(nt, "MULTIPLY", under, 0.55))
    # คูณลายเส้นใบเดิม (ความสว่างสัมพัทธ์ของภาพเดิม)
    lv =N(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    lv.inputs["Factor"].default_value = 1.0
    nt.links.new(c, lv.inputs["A"])
    dcol = N(nt, "ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(detail, dcol.inputs[i])
    nt.links.new(dcol.outputs[0], lv.inputs["B"])
    leafcol = lv.outputs["Result"]
    # ---------------- ส่วนที่ไม่ใช่แผ่นใบ (วัดจากภาพเดิมต่อหน้า + ความสูง)
    #   ภาพเดิมมืดมาก (lum < 0.15) ช่วงบน = ก้านใบ/เส้นกลางใบ (หน้าเล็กเรียว z สูง) · ช่วงโคน = ดิน
    #   เทาอมเหลือง (gdom -0.06..0) = ลำต้นเทียม · น้ำตาลชัด (gdom < -0.06) = ใบแห้ง/กาบแห้ง
    streak = N(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    streak.inputs["Scale"].default_value = 7.0
    streak.inputs["Distortion"].default_value = 5.0
    nt.links.new(obj, streak.inputs["Vector"])
    sfac = maprange(nt, streak.outputs["Fac"], 0.25, 0.85)
    # ใบแห้ง/กาบแห้ง: ฟาง-น้ำตาล ด่างคล้ำ
    c2 = mix(nt, L((160, 128, 80)), L((96, 70, 44)), maprange(nt, mid, 0.35, 0.7))
    c2 = mix(nt, c2, L((56, 40, 30)), math_(nt, "MULTIPLY", maprange(nt, fine, 0.62, 0.74), 0.6))
    # ลำต้นเทียม: เขียวหม่น-เขียวอมเหลือง ลายตามยาว ด่างม่วงน้ำตาล กาบนอกแห้งเป็นแผ่น (ช่วงล่าง)
    stemc = mix(nt, L((98, 118, 62)), L((138, 146, 82)), sfac)
    stemc = mix(nt, stemc, L((60, 42, 48)), math_(nt, "MULTIPLY", maprange(nt, mid, 0.55, 0.68), 0.85))
    stemc = mix(nt, stemc, L((150, 160, 84)), math_(nt, "MULTIPLY", maprange(nt, h, 0.2, 0.7), 0.6))
    sheath = math_(nt, "MULTIPLY", maprange(nt, big, 0.52, 0.62), math_(nt, "ADD", 0.2, low), clamp=True)
    stemc = mix(nt, stemc, L((134, 104, 66)), sheath)
    stemm = maprange(nt, gdom, -0.075, -0.045)
    c2 = mix(nt, c2, stemc, stemm)
    # ก้านใบ/เส้นกลางใบ: เขียวอมเหลืองสว่าง (ก้านช่วงล่างเข้มขึ้นนิด) ลายเส้นตามยาว
    petc = mix(nt, L((128, 150, 62)), L((168, 176, 84)), sfac)
    petc = mix(nt, L((96, 120, 52)), petc, maprange(nt, h, 0.1, 0.6))
    petc = mix(nt, petc, L((110, 84, 44)), math_(nt, "MULTIPLY", maprange(nt, fine, 0.7, 0.78), 0.5))
    darkm = maprange(nt, lum.outputs[0], 0.17, 0.12)
    groundm = maprange(nt, sep.outputs["Z"], ZMIN + (ZMAX - ZMIN) * 0.05, ZMIN + (ZMAX - ZMIN) * 0.02)
    c2 = mix(nt, c2, petc, math_(nt, "MULTIPLY", darkm, math_(nt, "SUBTRACT", 1.0, groundm), clamp=True))
    # ดินที่โคนกอ: น้ำตาลเข้มชื้น
    c2 = mix(nt, c2, L((46, 34, 26)), groundm)
    base_dark = maprange(nt, sep.outputs["Z"], ZMIN + (ZMAX - ZMIN) * 0.12, ZMIN)
    c2 = mix(nt, c2, L((44, 34, 26)), math_(nt, "MULTIPLY", base_dark, 0.45))
    # ลายเส้นใยเดิม: ส่วนมืด (ก้าน) ไม่คูณ ไม่งั้นดำ
    detail2 = mix(nt, dcol.outputs[0], (1, 1, 1, 1), darkm)
    v2 = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    v2.inputs["Factor"].default_value = 1.0
    nt.links.new(c2, v2.inputs["A"])
    nt.links.new(detail2, v2.inputs["B"])
    other = v2.outputs["Result"]
    final = mix(nt, other, leafcol, leafm)
    # AO: ซอกในกอเข้มลง
    ao = N(nt, "ShaderNodeAmbientOcclusion", samples=16)
    ao.inputs["Distance"].default_value = 0.4
    aof = maprange(nt, ao.outputs["AO"], 0.2, 1.0, 0.72, 1.06)
    aoc = N(nt, "ShaderNodeCombineColor")
    for i in range(3):
        nt.links.new(aof, aoc.inputs[i])
    fm = N(nt, "ShaderNodeMix", data_type="RGBA", blend_type="MULTIPLY", clamp_factor=True)
    fm.inputs["Factor"].default_value = 1.0
    nt.links.new(final, fm.inputs["A"])
    nt.links.new(aoc.outputs[0], fm.inputs["B"])
    nt.links.new(fm.outputs["Result"], bs.inputs["Base Color"])
    # roughness: ใบมันเงานิด (ด้านบน) ใต้ใบ/ใบแห้งด้าน
    rleaf = math_(nt, "ADD", 0.56, math_(nt, "MULTIPLY", under, 0.14))
    rgh = N(nt, "ShaderNodeMix", data_type="FLOAT", clamp_factor=True)
    nt.links.new(leafm, rgh.inputs["Factor"])
    rgh.inputs["A"].default_value = 0.86
    nt.links.new(rleaf, rgh.inputs["B"])
    nt.links.new(rgh.outputs["Result"], bs.inputs["Roughness"])
    bs.inputs["Metallic"].default_value = 0.0
    # normal: normal map เดิม (UV เดิม)
    on = N(nt, "ShaderNodeTexImage", image=old_nrm)
    nt.links.new(uv.outputs[0], on.inputs[0])
    nm = N(nt, "ShaderNodeNormalMap", uv_map="UVMap")
    nt.links.new(on.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bs.inputs["Normal"])
    return m


mat = build_material()
for o in OBJS:
    o.data.materials.clear()
    o.data.materials.append(mat)

# ---------------------------------------------------------------- bake ลงภาพเดียว (UV เดิม ทั้ง 3 ชิ้น)
scn.render.engine = "CYCLES"
scn.cycles.device = "CPU"
scn.cycles.samples = SAMPLES
scn.render.bake.margin = 4
imgs = {}
for ch, cs in (("Color", "sRGB"), ("Roughness", "Non-Color"), ("Metalness", "Non-Color"), ("Normal", "Non-Color")):
    im = bpy.data.images.new(f"BananaPaintV2_{ch}", TEX, TEX, alpha=False)
    im.colorspace_settings.name = cs
    imgs[ch] = im
nt = mat.node_tree
bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
tgt = nt.nodes.new("ShaderNodeTexImage")


def bake_all(ch, typ, socket=None):
    tgt.image = imgs[ch]
    nt.nodes.active = tgt
    em = None
    keep = outn.inputs[0].links[0].from_socket
    if socket:
        em = nt.nodes.new("ShaderNodeEmission")
        inp = bs.inputs[socket]
        if inp.links:
            nt.links.new(inp.links[0].from_socket, em.inputs["Color"])
        else:
            v = inp.default_value
            em.inputs["Color"].default_value = (v, v, v, 1) if not hasattr(v, "__len__") else tuple(v)
        nt.links.new(em.outputs[0], outn.inputs[0])
    for i, o in enumerate(OBJS):
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        if typ == "NORMAL":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=(i == 0))
        else:
            bpy.ops.object.bake(type=typ, use_clear=(i == 0))
    if em:
        nt.links.new(keep, outn.inputs[0])
        nt.nodes.remove(em)
    imgs[ch].filepath_raw = os.path.join(UP, f"BananaPaintV2_{ch}.png")
    imgs[ch].file_format = "PNG"
    imgs[ch].save()
    log("baked", ch)


bake_all("Color", "EMIT", "Base Color")
bake_all("Roughness", "EMIT", "Roughness")
bake_all("Metalness", "EMIT", "Metallic")
bake_all("Normal", "NORMAL")

# วัสดุสุดท้ายใช้ภาพที่อบ (สำหรับ FBX + ภาพตัวอย่าง)
fm = bpy.data.materials.new("BananaPaintV2_Mat")
fm.use_nodes = True
fnt = fm.node_tree
fbs = fnt.nodes["Principled BSDF"]
for ch, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metalness", "Metallic")):
    t = fnt.nodes.new("ShaderNodeTexImage")
    t.image = imgs[ch]
    fnt.links.new(t.outputs[0], fbs.inputs[sock])
t = fnt.nodes.new("ShaderNodeTexImage")
t.image = imgs["Normal"]
nmp = fnt.nodes.new("ShaderNodeNormalMap")
fnt.links.new(t.outputs[0], nmp.inputs["Color"])
fnt.links.new(nmp.outputs[0], fbs.inputs["Normal"])
for o in OBJS:
    o.data.materials.clear()
    o.data.materials.append(fm)
    o.name = o.name.split(".")[0]

bpy.ops.object.select_all(action="DESELECT")
for o in OBJS:
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJS[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "BananaPaintV2.fbx"), use_selection=True, object_types={"MESH"},
                         path_mode="STRIP", embed_textures=False, mesh_smooth_type="FACE")
log("fbx", os.path.join(UP, "BananaPaintV2.fbx"))


# ---------------------------------------------------------------- ภาพตัวอย่าง: เก่า (ซ้าย) / ใหม่ (ขวา)
def preview():
    om = bpy.data.materials.new("Old")
    om.use_nodes = True
    ont = om.node_tree
    t = ont.nodes.new("ShaderNodeTexImage")
    t.image = old_col
    ont.links.new(t.outputs[0], ont.nodes["Principled BSDF"].inputs["Base Color"])
    olds = []
    for o in OBJS:
        c = o.copy()
        c.data = o.data.copy()
        c.data.materials.clear()
        c.data.materials.append(om)
        scn.collection.objects.link(c)
        c.location.x += 5.5
        olds.append(c)
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1400, 820
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.56, 0.62, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(130))
    scn.collection.objects.link(sun)
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-12, -12, 0), (16, -12, 0), (16, 12, 0), (-12, 12, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gm = bpy.data.materials.new("G")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.16, 0.11, 1)
    gp.materials.append(gm)
    scn.collection.objects.link(gob)
    cs = [o.matrix_world @ v.co for o in OBJS + olds for v in o.data.vertices]
    c = sum(cs, Vector()) / len(cs)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens = 35
    cam.location = c + Vector((0.3, -12.5, 1.4))
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(OUT, "BananaPaintV2_compare.png")
    bpy.ops.render.render(write_still=True)
    for o in olds:
        o.hide_render = True
    c2 = sum((o.matrix_world @ v.co for o in OBJS for v in o.data.vertices), Vector()) / sum(len(o.data.vertices) for o in OBJS)
    cam.data.lens = 50
    cam.location = c2 + Vector((-2.8, -4.2, 0.4))
    cam.rotation_euler = (c2 - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(OUT, "BananaPaintV2_close.png")
    bpy.ops.render.render(write_still=True)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "banana_paint_v2.blend"))
log("done")
