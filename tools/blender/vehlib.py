# vehlib.py — ชุดเครื่องมือปั้นรถ (เรขาคณิต / วัสดุ procedural / bake ลงภาพ) แยกจาก customer_bike_v2.py (2026-11-08)
# ใช้ใน Blender: import vehlib as V; ตั้ง V.S, V.UP (โฟลเดอร์ upload), V.TEX, V.SAMPLES, V.FRONT_Y/V.AXLE_Z (ดุมล้อสำหรับดอกยาง) ก่อนเรียก
#   V.make_mat(...) -> V.put(obj, G, mat, subdiv) -> V.build_object(name) -> V.uv_unwrap / V.bake / V.final_material
# หน่วย = studs (คูณ S ตอนสร้าง mesh) แกน Blender: หน้ารถ -Y, ซ้าย +X, origin = พื้นใต้กึ่งกลางรถ (Roblox: X = -bx, Y = bz, Z = by)
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

S = 0.28
UP = "."
TEX = 1024
SAMPLES = 16
FRONT_Y, AXLE_Z = 0.0, 0.0
TREAD_N = 34.0
scn = bpy.context.scene


def log(*a):
    print("VEH|", *a)


# ---------------------------------------------------------------- เรขาคณิต (คืน verts, faces ใน studs)
class G:
    def __init__(s):
        s.v, s.f = [], []

    def add(s, verts, faces):
        o = len(s.v)
        s.v += [tuple(p) for p in verts]
        s.f += [tuple(i + o for i in f) for f in faces]
        return s

    def merge(s, g):
        return s.add(g.v, g.f)


def sup(c, s_, p):  # superellipse
    return math.copysign(abs(c) ** (2.0 / p), c)


def ring_y(cx, y, cz, hx, hz, n=20, p=2.0, flat_bottom=None):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x = cx + hx * sup(math.cos(a), 0, p)
        z = cz + hz * sup(math.sin(a), 0, p)
        if flat_bottom is not None:
            z = max(z, flat_bottom)
        pts.append((x, y, z))
    return pts


def ring_z(cx, cy, z, hx, hy, n=20, p=2.0):
    return [(cx + hx * sup(math.cos(2 * math.pi * i / n), 0, p), cy + hy * sup(math.sin(2 * math.pi * i / n), 0, p), z) for i in range(n)]


def loft(rings, cap=True):
    g = G()
    n = len(rings[0])
    for r in rings:
        g.v += [tuple(p) for p in r]
    for j in range(len(rings) - 1):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            g.f.append((a, b, b + n, a + n))
    if cap:
        # ปิดหัว/ท้ายด้วยจุดกลาง (fan) ให้ subdivision มนสวย
        for j, rev in ((0, True), (len(rings) - 1, False)):
            c = [sum(p[k] for p in rings[j]) / n for k in range(3)]
            ci = len(g.v)
            g.v.append(tuple(c))
            for i in range(n):
                a, b = j * n + i, j * n + (i + 1) % n
                g.f.append((b, a, ci) if rev else (a, b, ci))
    return g


def frames(pts):
    """parallel transport frames ตามเส้นทาง"""
    P = [Vector(p) for p in pts]
    T = []
    for i in range(len(P)):
        d = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)])
        T.append(d.normalized() if d.length > 1e-9 else Vector((0, 0, 1)))
    up = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    N = [T[0].cross(up).normalized()]
    for i in range(1, len(P)):
        v = T[i - 1].cross(T[i])
        n = N[-1]
        if v.length > 1e-9:
            ang = math.acos(max(-1, min(1, T[i - 1].dot(T[i]))))
            n = Matrix.Rotation(ang, 3, v.normalized()) @ n
        N.append(n.normalized())
    B = [t.cross(n).normalized() for t, n in zip(T, N)]
    return P, T, N, B


def tube(pts, r, n=10, cap=True):
    P, T, N, B = frames(pts)
    rs = r if isinstance(r, (list, tuple)) else [r] * len(P)
    rings = []
    for p, nn, bb, rr in zip(P, N, B, rs):
        rings.append([tuple(p + (nn * math.cos(2 * math.pi * i / n) + bb * math.sin(2 * math.pi * i / n)) * rr) for i in range(n)])
    return loft(rings, cap)


def lathe_x(cy, cz, prof, n=32, x0=0.0):
    """หมุนรอบแกน X (ล้อ / ดุม): prof = [(dx, r)] เรียงจากด้านหนึ่งไปอีกด้าน"""
    g = G()
    for dx, r in prof:
        for i in range(n):
            a = 2 * math.pi * i / n
            g.v.append((x0 + dx, cy + r * math.cos(a), cz + r * math.sin(a)))
    for j in range(len(prof) - 1):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            g.f.append((a, b, b + n, a + n))
    return g


def lathe_axis(c, axis, prof, n=24):
    """หมุนรอบแกนใดก็ได้: prof = [(t, r)] t = ระยะตามแกน"""
    axis = Vector(axis).normalized()
    up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(up).normalized()
    w = axis.cross(u).normalized()
    g = G()
    c = Vector(c)
    for t, r in prof:
        for i in range(n):
            a = 2 * math.pi * i / n
            g.v.append(tuple(c + axis * t + (u * math.cos(a) + w * math.sin(a)) * r))
    for j in range(len(prof) - 1):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            g.f.append((a, b, b + n, a + n))
    return g


def box(c, s_):
    cx, cy, cz = c
    hx, hy, hz = s_[0] / 2, s_[1] / 2, s_[2] / 2
    v = [(cx + x * hx, cy + y * hy, cz + z * hz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return G().add(v, f)


def helix(c0, c1, R, turns, r, n=6, steps_per_turn=14):
    a = Vector(c0)
    b = Vector(c1)
    ax = (b - a)
    L = ax.length
    ax.normalize()
    up = Vector((1, 0, 0)) if abs(ax.x) < 0.9 else Vector((0, 1, 0))
    u = ax.cross(up).normalized()
    w = ax.cross(u).normalized()
    pts = []
    N = int(turns * steps_per_turn)
    for i in range(N + 1):
        t = i / N
        ang = 2 * math.pi * turns * t
        pts.append(tuple(a + ax * (L * t) + (u * math.cos(ang) + w * math.sin(ang)) * R))
    return tube(pts, r, n)


def mirror_x(g):
    m = G()
    m.v = [(-x, y, z) for x, y, z in g.v]
    m.f = [tuple(reversed(f)) for f in g.f]
    return m


def both(g):
    return G().merge(g).merge(mirror_x(g))


def arc(c, R, a0, a1, n, plane="yz", x=0.0):
    pts = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        pts.append((x, c[0] + R * math.cos(a), c[1] + R * math.sin(a)))
    return pts


# ---------------------------------------------------------------- วัสดุ (procedural แล้ว bake ลงภาพ)
MATS = {}


def node(nt, t, **kw):
    n = nt.nodes.new(t)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def make_mat(name, base, rough, metal=0.0, dirt=0.35, wear=0.0, bump=0.0, bump_scale=60.0, kind="noise", rust=0.0, stripe=None, coat=0.0):
    """base = สี linear, dirt = คราบฝุ่นตามซอก (AO) + ท่อนล่าง, wear = ขอบถลอก (pointiness), bump = ผิวขรุขระ
    kind: noise / pleat (เบาะจีบ) / tread (ดอกยาง) · stripe = (z0, z1, color) แถบสีข้างตัวรถ"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = node(nt, "ShaderNodeOutputMaterial")
    bs = node(nt, "ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], out.inputs[0])
    geo = node(nt, "ShaderNodeNewGeometry")
    tc = node(nt, "ShaderNodeTexCoord")
    # สีพื้น + จุดด่างเล็กน้อย
    nz = node(nt, "ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 9.0
    nz.inputs["Detail"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    col = node(nt, "ShaderNodeMix")
    col.data_type = "RGBA"
    col.inputs["A"].default_value = (*base, 1)
    col.inputs["B"].default_value = (base[0] * 0.78, base[1] * 0.78, base[2] * 0.78, 1)
    nt.links.new(nz.outputs["Fac"], col.inputs["Factor"])
    cur = col.outputs["Result"]
    if stripe:
        z0, z1, sc = stripe
        sep = node(nt, "ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs[0])
        m0 = node(nt, "ShaderNodeMath", operation="GREATER_THAN")
        m0.inputs[1].default_value = z0 * S
        nt.links.new(sep.outputs["Z"], m0.inputs[0])
        m1 = node(nt, "ShaderNodeMath", operation="LESS_THAN")
        m1.inputs[1].default_value = z1 * S
        nt.links.new(sep.outputs["Z"], m1.inputs[0])
        mm = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        nt.links.new(m0.outputs[0], mm.inputs[0])
        nt.links.new(m1.outputs[0], mm.inputs[1])
        st = node(nt, "ShaderNodeMix")
        st.data_type = "RGBA"
        st.inputs["B"].default_value = (*sc, 1)
        nt.links.new(cur, st.inputs["A"])
        nt.links.new(mm.outputs[0], st.inputs["Factor"])
        cur = st.outputs["Result"]
    rough_out = None
    if rust > 0:
        rn = node(nt, "ShaderNodeTexNoise")
        rn.inputs["Scale"].default_value = 14.0
        rn.inputs["Detail"].default_value = 10.0
        rn.inputs["Roughness"].default_value = 0.7
        nt.links.new(tc.outputs["Object"], rn.inputs["Vector"])
        rr = node(nt, "ShaderNodeMapRange")
        rr.inputs["From Min"].default_value = 0.62 - rust * 0.12
        rr.inputs["From Max"].default_value = 0.70 - rust * 0.12
        nt.links.new(rn.outputs["Fac"], rr.inputs["Value"])
        rc = node(nt, "ShaderNodeMix")
        rc.data_type = "RGBA"
        rc.inputs["B"].default_value = (0.16, 0.06, 0.025, 1)
        nt.links.new(cur, rc.inputs["A"])
        nt.links.new(rr.outputs["Result"], rc.inputs["Factor"])
        cur = rc.outputs["Result"]
        rough_out = rr.outputs["Result"]
    if wear > 0:
        pr = node(nt, "ShaderNodeMapRange")
        pr.inputs["From Min"].default_value = 0.52
        pr.inputs["From Max"].default_value = 0.62
        nt.links.new(geo.outputs["Pointiness"], pr.inputs["Value"])
        wn = node(nt, "ShaderNodeTexNoise")
        wn.inputs["Scale"].default_value = 40.0
        nt.links.new(tc.outputs["Object"], wn.inputs["Vector"])
        wm = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        nt.links.new(pr.outputs["Result"], wm.inputs[0])
        nt.links.new(wn.outputs["Fac"], wm.inputs[1])
        wm2 = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        wm2.inputs[1].default_value = wear * 2.0
        nt.links.new(wm.outputs[0], wm2.inputs[0])
        wc = node(nt, "ShaderNodeMix")
        wc.data_type = "RGBA"
        wc.clamp_factor = True
        wc.inputs["B"].default_value = (0.32, 0.31, 0.30, 1)
        nt.links.new(cur, wc.inputs["A"])
        nt.links.new(wm2.outputs[0], wc.inputs["Factor"])
        cur = wc.outputs["Result"]
    if dirt > 0:
        ao = node(nt, "ShaderNodeAmbientOcclusion")
        ao.inputs["Distance"].default_value = 0.35 * S
        ao.samples = 16
        aor = node(nt, "ShaderNodeMapRange")
        aor.inputs["From Min"].default_value = 0.25
        aor.inputs["From Max"].default_value = 1.0
        aor.inputs["To Min"].default_value = 1.0
        aor.inputs["To Max"].default_value = 0.0
        nt.links.new(ao.outputs["AO"], aor.inputs["Value"])
        # ท่อนล่างเปื้อนฝุ่นดินลูกรังมากกว่า
        sep2 = node(nt, "ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep2.inputs[0])
        low = node(nt, "ShaderNodeMapRange")
        low.inputs["From Min"].default_value = 1.6 * S
        low.inputs["From Max"].default_value = 0.2 * S
        nt.links.new(sep2.outputs["Z"], low.inputs["Value"])
        dn = node(nt, "ShaderNodeTexNoise")
        dn.inputs["Scale"].default_value = 18.0
        dn.inputs["Detail"].default_value = 8.0
        nt.links.new(tc.outputs["Object"], dn.inputs["Vector"])
        add = node(nt, "ShaderNodeMath", operation="ADD")
        nt.links.new(aor.outputs["Result"], add.inputs[0])
        nt.links.new(low.outputs["Result"], add.inputs[1])
        mul = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        nt.links.new(add.outputs[0], mul.inputs[0])
        nt.links.new(dn.outputs["Fac"], mul.inputs[1])
        mul2 = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        mul2.inputs[1].default_value = dirt * 1.4
        mul2.use_clamp = True
        nt.links.new(mul.outputs[0], mul2.inputs[0])
        dc = node(nt, "ShaderNodeMix")
        dc.data_type = "RGBA"
        dc.clamp_factor = True
        dc.inputs["B"].default_value = (0.20, 0.13, 0.08, 1)
        nt.links.new(cur, dc.inputs["A"])
        nt.links.new(mul2.outputs[0], dc.inputs["Factor"])
        cur = dc.outputs["Result"]
        dr = node(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
        dr.inputs[1].default_value = 0.45
        dr.inputs[2].default_value = rough
        dr.use_clamp = True
        nt.links.new(mul2.outputs[0], dr.inputs[0])
        rough_out = dr.outputs[0] if rough_out is None else rough_out
    nt.links.new(cur, bs.inputs["Base Color"])
    if rough_out is not None and rust > 0:
        rm = node(nt, "ShaderNodeMapRange")
        rm.inputs["To Min"].default_value = rough
        rm.inputs["To Max"].default_value = 0.9
        nt.links.new(rough_out, rm.inputs["Value"])
        nt.links.new(rm.outputs["Result"], bs.inputs["Roughness"])
    elif rough_out is not None:
        nt.links.new(rough_out, bs.inputs["Roughness"])
    else:
        bs.inputs["Roughness"].default_value = rough
    mv = node(nt, "ShaderNodeValue")
    mv.name = "MetalValue"
    mv.outputs[0].default_value = metal
    if rust > 0:
        mmx = node(nt, "ShaderNodeMath", operation="MULTIPLY")
        inv = node(nt, "ShaderNodeMath", operation="SUBTRACT")
        inv.inputs[0].default_value = 1.0
        nt.links.new(rough_out if rough_out is not None else mv.outputs[0], inv.inputs[1])
        nt.links.new(mv.outputs[0], mmx.inputs[0])
        nt.links.new(inv.outputs[0], mmx.inputs[1])
        metal_out = mmx.outputs[0]
    else:
        metal_out = mv.outputs[0]
    nt.links.new(metal_out, bs.inputs["Metallic"])
    m["metal_socket"] = 1
    # bump
    if bump > 0:
        if kind == "pleat":
            tx = node(nt, "ShaderNodeTexWave")
            tx.wave_type = "BANDS"
            tx.bands_direction = "Y"
            tx.inputs["Scale"].default_value = 16.0  # จีบห่าง ~6 ซม.
            tx.inputs["Distortion"].default_value = 0.0
            nt.links.new(tc.outputs["Object"], tx.inputs["Vector"])
            hgt = tx.outputs["Fac"]
        elif kind == "tread":
            # ดอกยางเฉียงรอบล้อ: มุมรอบแกน X
            # มุมรอบดุมล้อหน้า (ล้อหลังใช้ภาพเดียวกับล้อหน้า) ไม่ใช่รอบ origin ของรถ
            hubv = node(nt, "ShaderNodeVectorMath", operation="SUBTRACT")
            hubv.inputs[1].default_value = (0.0, FRONT_Y * S, AXLE_Z * S)
            nt.links.new(tc.outputs["Object"], hubv.inputs[0])
            sep3 = node(nt, "ShaderNodeSeparateXYZ")
            nt.links.new(hubv.outputs[0], sep3.inputs[0])
            at = node(nt, "ShaderNodeMath", operation="ARCTAN2")
            nt.links.new(sep3.outputs["Z"], at.inputs[0])
            nt.links.new(sep3.outputs["Y"], at.inputs[1])
            ax = node(nt, "ShaderNodeMath", operation="MULTIPLY")
            ax.inputs[1].default_value = TREAD_N  # ดอกยางรอบวง (มอไซค์ 34, รถยนต์ละเอียดกว่า)
            nt.links.new(at.outputs[0], ax.inputs[0])
            xs = node(nt, "ShaderNodeMath", operation="MULTIPLY")
            xs.inputs[1].default_value = 1.0 / (0.06 * S)
            nt.links.new(sep3.outputs["X"], xs.inputs[0])
            ab = node(nt, "ShaderNodeMath", operation="ABSOLUTE")
            nt.links.new(xs.outputs[0], ab.inputs[0])
            ad = node(nt, "ShaderNodeMath", operation="ADD")
            nt.links.new(ax.outputs[0], ad.inputs[0])
            nt.links.new(ab.outputs[0], ad.inputs[1])
            sn = node(nt, "ShaderNodeMath", operation="SINE")
            nt.links.new(ad.outputs[0], sn.inputs[0])
            hgt = sn.outputs[0]  # ไล่ระดับนุ่ม (ขั้นบันไดแบบเดิม bump แบนเกือบทั้งผืน)
        else:
            tx = node(nt, "ShaderNodeTexNoise")
            tx.inputs["Scale"].default_value = bump_scale
            tx.inputs["Detail"].default_value = 4.0
            nt.links.new(tc.outputs["Object"], tx.inputs["Vector"])
            hgt = tx.outputs["Fac"]
        bp = node(nt, "ShaderNodeBump")
        bp.inputs["Strength"].default_value = bump
        bp.inputs["Distance"].default_value = 0.16 * S  # (0.02 อบออกมาแทบแบน: ดอกยาง/จีบเบาะไม่ขึ้น)
        nt.links.new(hgt, bp.inputs["Height"])
        nt.links.new(bp.outputs["Normal"], bs.inputs["Normal"])
    if coat > 0:
        bs.inputs["Coat Weight"].default_value = coat
    MATS[name] = m
    return m


def L(c):  # sRGB -> linear
    return tuple(((x / 255) / 12.92) if x / 255 <= 0.04045 else (((x / 255) + 0.055) / 1.055) ** 2.4 for x in c)


# ---------------------------------------------------------------- ประกอบชิ้น -> object
PARTS = {}  # ชื่อ object -> [(G, mat, subdiv, smooth_angle, bevel)]


def put(obj, g, mat, subdiv=0, smooth=40, bevel=0.0):
    PARTS.setdefault(obj, []).append((g, mat, subdiv, smooth, bevel))


def build_object(name):
    pieces = PARTS[name]
    objs = []
    for idx, (g, mat, subdiv, smooth, bevel) in enumerate(pieces):
        me = bpy.data.meshes.new(f"{name}_{idx}")
        bm = bmesh.new()
        vs = [bm.verts.new(Vector(p) * S) for p in g.v]
        for f in g.f:
            try:
                bm.faces.new([vs[i] for i in f])
            except ValueError:
                pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(MATS[mat])
        ob = bpy.data.objects.new(f"{name}_{idx}", me)
        bpy.context.scene.collection.objects.link(ob)
        if subdiv:
            md = ob.modifiers.new("Sub", "SUBSURF")
            md.levels = subdiv
            md.render_levels = subdiv
        if bevel:
            bv = ob.modifiers.new("Bev", "BEVEL")
            bv.width = bevel * S
            bv.segments = 2
            bv.limit_method = "ANGLE"
            bv.angle_limit = math.radians(35)
        dg = bpy.context.evaluated_depsgraph_get()
        nm = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear()
        old = ob.data
        ob.data = nm
        bpy.data.meshes.remove(old)
        for p in ob.data.polygons:
            p.use_smooth = True
        ob["smooth"] = smooth
        objs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    wn = ob.modifiers.new("WN", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    dg = bpy.context.evaluated_depsgraph_get()
    nm = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.clear()
    old = ob.data
    ob.data = nm
    bpy.data.meshes.remove(old)
    ob.data.name = name
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    log(f"{name}: {tris} tris")
    return ob


def uv_unwrap(ob, margin=0.004):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(ob, stem):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = SAMPLES
    scn.render.bake.margin = 6
    imgs = {}
    for ch, cs in (("Color", "sRGB"), ("Roughness", "Non-Color"), ("Metalness", "Non-Color"), ("Normal", "Non-Color")):
        im = bpy.data.images.new(f"{stem}_{ch}", TEX, TEX, alpha=False, float_buffer=False)
        im.colorspace_settings.name = cs
        imgs[ch] = im
    mats = [s.material for s in ob.material_slots]

    def target(ch):
        for m in mats:
            nt = m.node_tree
            n = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
            n.name = "BakeTarget"
            n.image = imgs[ch]
            nt.nodes.active = n
            for nn in nt.nodes:
                nn.select = False
            n.select = True

    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

    def emit_bake(ch, socket):
        """ค่าในช่องนี้ของ Principled -> emission ชั่วคราว แล้ว bake EMIT
        (สีพื้นต้องใช้วิธีนี้: bake DIFFUSE ของโลหะได้สีดำ เพราะโลหะไม่มี diffuse)"""
        saved = []
        for m in mats:
            nt = m.node_tree
            bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            inp = bs.inputs[socket]
            src = inp.links[0].from_socket if inp.links else None
            em = nt.nodes.new("ShaderNodeEmission")
            out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
            old = out.inputs[0].links[0].from_socket
            if src:
                nt.links.new(src, em.inputs["Color"])
            else:
                v = inp.default_value
                em.inputs["Color"].default_value = (v[0], v[1], v[2], 1) if hasattr(v, "__len__") else (v, v, v, 1)
            nt.links.new(em.outputs[0], out.inputs[0])
            saved.append((nt, out, old, em))
        target(ch)
        bpy.ops.object.bake(type="EMIT", use_clear=True)
        for nt, out, old, em in saved:
            nt.links.new(old, out.inputs[0])
            nt.nodes.remove(em)

    emit_bake("Color", "Base Color")
    emit_bake("Roughness", "Roughness")
    emit_bake("Metalness", "Metallic")
    target("Normal")
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", use_clear=True)
    for ch, im in imgs.items():
        im.filepath_raw = os.path.join(UP, f"{stem}_{ch}.png")
        im.file_format = "PNG"
        im.save()
    return imgs


def final_material(stem, imgs):
    m = bpy.data.materials.new(stem + "_Mat")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = node(nt, "ShaderNodeOutputMaterial")
    bs = node(nt, "ShaderNodeBsdfPrincipled")
    nt.links.new(bs.outputs[0], out.inputs[0])
    for ch, sock in (("Color", "Base Color"), ("Roughness", "Roughness"), ("Metalness", "Metallic")):
        t = node(nt, "ShaderNodeTexImage")
        t.image = imgs[ch]
        nt.links.new(t.outputs[0], bs.inputs[sock])
    t = node(nt, "ShaderNodeTexImage")
    t.image = imgs["Normal"]
    nm = node(nt, "ShaderNodeNormalMap")
    nt.links.new(t.outputs[0], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], bs.inputs["Normal"])
    return m


def neon_material(name, col):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*col, 1)
    bs.inputs["Emission Color"].default_value = (*col, 1)
    bs.inputs["Emission Strength"].default_value = 3.0
    return m
