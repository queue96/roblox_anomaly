# proplib.py — ตัวช่วยปั้นของในฉาก (ตู้ปั๊ม / ถังลม / ชั้นวางของ) ต่อยอดจาก vehlib.py (2026-11-08)
# ใช้ใน Blender: import vehlib as V; import proplib as P
#   หน่วย = studs (vehlib คูณ V.S = 0.28 ตอนสร้าง mesh) แกน Blender: หน้าของ -Y, +X = ขวามือคนที่ยืนดูด้านหน้า
#   origin = พื้นใต้กึ่งกลางของ (Roblox: X = -bx, Y = bz, Z = by)
# มีให้: xform / box_rot / extrude_y / spline / dome · วัสดุไม้ (wood) และพลาสติก/กระดาษสีเรียบ (flat)
#        bake_all / export_fbx / log_bbox / preview (EEVEE + คนยืนเทียบขนาด)
import bpy, math, os
from mathutils import Vector, Matrix
import vehlib as V

G = V.G


def log(*a):
    print("PROP|", *a)


# ---------------------------------------------------------------- เรขาคณิต
def xform(g, m):
    """คูณทุกจุดของ G ด้วย Matrix 4x4 (หน่วย studs)"""
    out = G()
    out.v = [tuple(m @ Vector(p)) for p in g.v]
    out.f = list(g.f)
    return out


def rot_at(c, axis, deg):
    c = Vector(c)
    return Matrix.Translation(c) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-c)


def box_rot(c, s_, axis="Z", deg=0.0):
    return xform(V.box(c, s_), rot_at(c, axis, deg))


def extrude_y(poly, y0, y1):
    """รูปปิด 2D [(x, z)] (นูน) ดันหนาตามแกน Y จาก y0 ถึง y1"""
    n = len(poly)
    g = G()
    g.v = [(x, y0, z) for x, z in poly] + [(x, y1, z) for x, z in poly]
    for i in range(n):
        j = (i + 1) % n
        g.f.append((i, j, j + n, i + n))
    cx = sum(p[0] for p in poly) / n
    cz = sum(p[1] for p in poly) / n
    a = len(g.v)
    g.v += [(cx, y0, cz), (cx, y1, cz)]
    for i in range(n):
        j = (i + 1) % n
        g.f.append((j, i, a))
        g.f.append((i + n, j + n, a + 1))
    return g


def extrude_z(poly, z0, z1):
    """รูปปิด 2D [(x, y)] (นูน) ดันหนาตามแกน Z"""
    g = extrude_y([(x, y) for x, y in poly], z0, z1)
    g.v = [(x, z, y) for x, y, z in g.v]
    return g


def spline(pts, per=8):
    """Catmull-Rom ผ่านทุกจุด คืนจุดละเอียด (ไว้ทำสายยาง / ท่อ)"""
    P = [Vector(p) for p in pts]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)))
    out.append(tuple(P[-2]))
    return out


def dome(c, axis, r, h, n=8):
    """หัวหมุด / ปุ่มนูนครึ่งวงรี"""
    prof = [(0.0, r), (h * 0.55, r * 0.8), (h * 0.9, r * 0.4), (h, 0.0)]
    return V.lathe_axis(c, axis, prof, n)


def cyl(c, axis, r, length, n=12, cap=True):
    """ทรงกระบอกปิดหัวท้าย (c = กึ่งกลางฐาน)"""
    prof = [(0.0, 0.0), (0.0, r), (length, r), (length, 0.0)] if cap else [(0.0, r), (length, r)]
    return V.lathe_axis(c, axis, prof, n)


def ring_band(c, axis, r_in, r_out, t0, t1, n=24):
    """ปลอกวงแหวนหนา (ทรงกระบอกกลวง) ตามแกน"""
    prof = [(t0, r_in), (t0, r_out), (t1, r_out), (t1, r_in), (t0, r_in)]
    return V.lathe_axis(c, axis, prof, n)


# ---------------------------------------------------------------- วัสดุเพิ่มเติม (ต่อจาก V.make_mat)
def _bsdf(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = V.node(nt, "ShaderNodeOutputMaterial")
    bs = V.node(nt, "ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], out.inputs[0])
    return m, nt, bs


def _ao_dirt(nt, cur, amount, dist=0.25, col=(0.17, 0.12, 0.08)):
    ao = V.node(nt, "ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = dist * V.S
    ao.samples = 16
    mr = V.node(nt, "ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.3
    mr.inputs["From Max"].default_value = 1.0
    mr.inputs["To Min"].default_value = amount
    mr.inputs["To Max"].default_value = 0.0
    nt.links.new(ao.outputs["AO"], mr.inputs["Value"])
    mx = V.node(nt, "ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.clamp_factor = True
    mx.inputs["B"].default_value = (*col, 1)
    nt.links.new(cur, mx.inputs["A"])
    nt.links.new(mr.outputs["Result"], mx.inputs["Factor"])
    return mx.outputs["Result"], mr.outputs["Result"]


def wood(name, base, rough=0.75, dirt=0.4, grain_axis="X", grain=1.0, bump=0.35, gray=0.0):
    """ไม้กระดาน: ลายเสี้ยนตามแกน grain_axis (เส้นยาวขนานแกนนั้น) + ด่างตามแผ่น + ฝุ่นตามซอก
    gray = ไม้เก่าตากแดดซีดเทา (0..1)"""
    m, nt, bs = _bsdf(name)
    tc = V.node(nt, "ShaderNodeTexCoord")
    # ยืดพิกัดตามแนวเสี้ยน ให้เสี้ยนยาว
    sc = V.node(nt, "ShaderNodeVectorMath", operation="MULTIPLY")
    k = {"X": (0.08, 1.0, 1.0), "Y": (1.0, 0.08, 1.0), "Z": (1.0, 1.0, 0.08)}[grain_axis]
    sc.inputs[1].default_value = k
    nt.links.new(tc.outputs["Object"], sc.inputs[0])
    wv = V.node(nt, "ShaderNodeTexWave")
    wv.wave_type = "RINGS"
    wv.inputs["Scale"].default_value = 18.0 * grain
    wv.inputs["Distortion"].default_value = 6.0
    wv.inputs["Detail"].default_value = 3.0
    wv.inputs["Detail Scale"].default_value = 1.5
    nt.links.new(sc.outputs[0], wv.inputs["Vector"])
    nz = V.node(nt, "ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 6.0
    nz.inputs["Detail"].default_value = 4.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    dark = tuple(c * 0.55 for c in base)
    if gray > 0:
        gq = sum(base) / 3
        base = tuple(c * (1 - gray) + gq * 1.15 * gray for c in base)
        dark = tuple(c * (1 - gray) + gq * 0.7 * gray for c in dark)
    c1 = V.node(nt, "ShaderNodeMix")
    c1.data_type = "RGBA"
    c1.inputs["A"].default_value = (*base, 1)
    c1.inputs["B"].default_value = (*dark, 1)
    nt.links.new(wv.outputs["Fac"], c1.inputs["Factor"])
    c2 = V.node(nt, "ShaderNodeMix")
    c2.data_type = "RGBA"
    c2.inputs["B"].default_value = (*tuple(c * 0.8 for c in base), 1)
    nt.links.new(c1.outputs["Result"], c2.inputs["A"])
    nt.links.new(nz.outputs["Fac"], c2.inputs["Factor"])
    cur, d = _ao_dirt(nt, c2.outputs["Result"], dirt)
    nt.links.new(cur, bs.inputs["Base Color"])
    rr = V.node(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
    rr.inputs[1].default_value = 0.15
    rr.inputs[2].default_value = rough
    rr.use_clamp = True
    nt.links.new(wv.outputs["Fac"], rr.inputs[0])
    nt.links.new(rr.outputs[0], bs.inputs["Roughness"])
    bs.inputs["Metallic"].default_value = 0.0
    bp = V.node(nt, "ShaderNodeBump")
    bp.inputs["Strength"].default_value = bump
    bp.inputs["Distance"].default_value = 0.05 * V.S
    nt.links.new(wv.outputs["Fac"], bp.inputs["Height"])
    nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
    V.MATS[name] = m
    return m


def flat(name, base, rough=0.5, metal=0.0, dirt=0.25, noise=0.06):
    """สีเรียบ (ฉลากกระดาษ / พลาสติก / แก้ว) มีด่างนิดๆ และฝุ่นตามซอก"""
    m, nt, bs = _bsdf(name)
    tc = V.node(nt, "ShaderNodeTexCoord")
    nz = V.node(nt, "ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 25.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    c1 = V.node(nt, "ShaderNodeMix")
    c1.data_type = "RGBA"
    c1.inputs["A"].default_value = (*base, 1)
    c1.inputs["B"].default_value = (*tuple(c * (1 - noise * 3) for c in base), 1)
    nt.links.new(nz.outputs["Fac"], c1.inputs["Factor"])
    cur = c1.outputs["Result"]
    if dirt > 0:
        cur, _ = _ao_dirt(nt, cur, dirt, dist=0.12)
    nt.links.new(cur, bs.inputs["Base Color"])
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metal
    V.MATS[name] = m
    return m


# ---------------------------------------------------------------- object / bake / export
def build(names):
    return {n: V.build_object(n) for n in names}


def log_bbox(objs):
    """ขนาด/กึ่งกลางในพิกัด Roblox (studs) ไว้ใช้ใน MapBuilder"""
    S = V.S
    res = {}
    for n, ob in objs.items():
        cs = [ob.matrix_world @ v.co for v in ob.data.vertices]
        mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs))) / S
        mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs))) / S
        c = (mn + mx) / 2
        sz = mx - mn
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        log(f"BBOX {n} center_rbx=({-c.x:.3f},{c.z:.3f},{c.y:.3f}) size_rbx=({sz.x:.3f},{sz.z:.3f},{sz.y:.3f}) bottom={mn.z:.3f} tris={tris}")
        res[n] = (c, sz, mn, mx)
    return res


def bake_all(objs, stems, sizes=None):
    """stems = {object: ชื่อไฟล์ texture} (object ที่ไม่อยู่ใน stems ไม่ bake) sizes = {object: px}"""
    for name, stem in stems.items():
        ob = objs[name]
        V.TEX = (sizes or {}).get(name, 1024)
        V.uv_unwrap(ob)
        log("baking", name, V.TEX)
        mat = V.final_material(stem, V.bake(ob, stem))
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0


def export_fbx(objs, path, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[active]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                             mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
    log("fbx", path)


def add_person(root, loc_studs, yaw_deg=0.0):
    """คนยืนเทียบขนาด (human_base) ถ้าหาไฟล์เจอ"""
    path = os.path.join(root, "human_base", "human_base.blend")
    if not os.path.exists(path):
        return []
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_red_shirt") or n.startswith("Cloth_") and "pants" in n.lower() or n == "Hair_side_part"]
        acts = [n for n in src.actions if "idle" in n.lower() or "stand" in n.lower()]
        dst.actions = acts[:1]
    obs = [o for o in dst.objects if o]
    grey = bpy.data.materials.new("PersonGrey")
    grey.use_nodes = True
    grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.45, 0.45, 0.47, 1)
    for o in obs:
        bpy.context.scene.collection.objects.link(o)
        if o.type == "MESH":
            o.data.materials.clear()
            o.data.materials.append(grey)
    rig = next((o for o in obs if o.type == "ARMATURE"), None)
    if rig:
        if dst.actions:
            rig.animation_data_create()
            rig.animation_data.action = dst.actions[0]
            bpy.context.scene.frame_set(1)
        rig.location = Vector(loc_studs) * V.S
        rig.rotation_euler = (0, 0, math.radians(yaw_deg))
    return obs


def stage(ground=(0.25, 0.2, 0.15), bg=(0.42, 0.44, 0.47), sun=3.5, size=30):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*bg, 1)
    s = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    s.data.energy = sun
    s.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(s)
    h = size * V.S
    gp = bpy.data.meshes.new("Ground")
    gp.from_pydata([(-h, -h, 0), (h, -h, 0), (h, h, 0), (-h, h, 0)], [], [(0, 1, 2, 3)])
    gob = bpy.data.objects.new("Ground", gp)
    gm = bpy.data.materials.new("Gnd")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*ground, 1)
    gp.materials.append(gm)
    scn.collection.objects.link(gob)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    return cam, s, w


def shot(cam, path, target_studs, d, dist_studs, lens=50, res=(1200, 900)):
    scn = bpy.context.scene
    scn.render.resolution_x, scn.render.resolution_y = res
    cam.data.lens = lens
    t = Vector(target_studs) * V.S
    cam.location = t + Vector(d).normalized() * dist_studs * V.S
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    log("png", path)


def night(world, sun, lamp_studs, energy=60.0, color=(1.0, 0.78, 0.5)):
    """เปลี่ยนเป็นกลางคืน: ฟ้ามืด แดดอ่อน + ไฟหลอดส้มดวงเดียว (เหมือนไฟเพิง)"""
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.012, 0.02, 1)
    sun.data.energy = 0.05
    lp = bpy.data.objects.new("Lamp", bpy.data.lights.new("Lamp", "POINT"))
    lp.data.energy = energy
    lp.data.color = color
    lp.data.shadow_soft_size = 0.05
    lp.location = Vector(lamp_studs) * V.S
    bpy.context.scene.collection.objects.link(lp)
    return lp
