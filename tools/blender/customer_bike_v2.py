# CustomerBike v2 — มอไซค์ครอบครัวไทย (ทรงรถเกียร์ใต้เบาะยอดนิยม ไม่มีโลโก้ยี่ห้อ) ปั้นใหม่ทั้งคัน (ผู้ใช้ 2026-11-08 "ขอแบบดีๆ")
# รัน: blender -b --factory-startup --python tools/blender/customer_bike_v2.py
# ผลลัพธ์: assets/models/CustomerBikeV2/upload/ (FBX + texture 4 ช่องต่อชิ้น = ไฟล์ที่ต้อง Import) · ชั้นนอก: ภาพตัวอย่าง + .blend
#
# หน่วยตอนปั้น = studs (คูณ S = 0.28 ตอนสร้าง mesh เหมือน thai_vehicles.py) แกน Blender: หน้ารถ -Y, ซ้ายของรถ +X, origin = พื้นใต้กึ่งกลางรถ
#   (Roblox: X = -bx, Y = bz, Z = by)
# ตำแหน่งที่ต้องตรงกับเกม (ใช้ใน MapBuilder.SwapCustomerBikeV2 ด้วย อย่าแก้ข้างเดียว):
#   ล้อหน้า/หลัง ดุมที่ y = -2.10 / +2.10, z = 1.03, รัศมียาง 1.03 (เท่ารุ่นเดิม: ผมพันล้อ / ผีซ้อนท้ายยังตรง)
#   สะโพกคนขับ (0, 0.75, 2.88) · แฮนด์ (±0.95, -1.05, 3.63) · ที่พักเท้า (±0.72, 0.35, 0.92) · เบาะบนสุด ~2.60
#   (รุ่นเดิม: สะโพก z 3.07 แฮนด์ห่างไปหน้า 2.56 = แขนเอื้อมไม่ถึง ต้องโน้ม 18-24°)
#   ป้ายทะเบียน (0, 3.36, 1.62) เอียง 8° · ไฟท้าย (0, 3.06, 2.26) · ไฟหน้า (0, -1.62, 3.36)
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

S = 0.28
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "CustomerBikeV2")
UP = os.path.join(OUT, "upload")  # เฉพาะไฟล์ที่ผู้ใช้ต้อง Import: FBX + texture (ภาพตัวอย่าง / .blend อยู่ชั้นนอก)
os.makedirs(UP, exist_ok=True)
TEX = int(os.environ.get("BIKE_TEX", "1024"))
SAMPLES = int(os.environ.get("BIKE_SAMPLES", "24"))
NO_BAKE = os.environ.get("BIKE_NOBAKE") == "1"

FRONT_Y, REAR_Y, AXLE_Z, TIRE_R = -2.10, 2.10, 1.03, 1.03
HIP = Vector((0, 0.75, 2.88))
GRIP_X, GRIP_Y, GRIP_Z = 0.95, -1.05, 3.63
HEAD_TOP = Vector((0, -1.08, 3.25))  # คอรถ (บนสุดของแกนคอ)


def log(*a):
    print("BIKE|", *a)


# ---------------------------------------------------------------- เริ่มฉากเปล่า
bpy.ops.wm.read_factory_settings(use_empty=True)
scn = bpy.context.scene


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
            ax.inputs[1].default_value = 34.0
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


# สีตัวรถ: อบเป็นสีเทาอ่อนเกือบขาว แล้วเกมสุ่มสีย้อมทับ (SurfaceAppearance.Color, shared/VehiclePaint) แถบข้าง = ขาวกว่าพื้น -> ออกมาเป็นสีเดียวกันแต่อ่อนกว่า
make_mat("paint", L((226, 226, 226)), 0.38, 0.0, dirt=0.45, wear=0.55, bump=0.04, bump_scale=120, stripe=(1.98, 2.06, L((255, 255, 255))), coat=0.4)
make_mat("paint_fender", L((226, 226, 226)), 0.42, 0.0, dirt=0.75, wear=0.5, bump=0.05, bump_scale=120)
make_mat("plastic_black", L((22, 21, 20)), 0.55, 0.0, dirt=0.55, wear=0.2, bump=0.08, bump_scale=200)
make_mat("plastic_grey", L((70, 70, 72)), 0.5, 0.0, dirt=0.5, wear=0.2, bump=0.06, bump_scale=200)
make_mat("seat", L((24, 20, 18)), 0.48, 0.0, dirt=0.3, wear=0.25, bump=0.35, kind="pleat")
make_mat("chrome", L((205, 205, 210)), 0.14, 1.0, dirt=0.35, rust=0.35)
make_mat("steel_black", L((30, 30, 32)), 0.45, 0.6, dirt=0.6, rust=0.25)
make_mat("alu", L((150, 150, 146)), 0.42, 0.85, dirt=0.75, bump=0.06, bump_scale=300)
make_mat("rubber", L((20, 20, 20)), 0.86, 0.0, dirt=0.22, bump=0.5, kind="tread")
make_mat("rubber_plain", L((24, 24, 24)), 0.8, 0.0, dirt=0.4, bump=0.1, bump_scale=300)
make_mat("amber", L((235, 128, 30)), 0.2, 0.0, dirt=0.25)
make_mat("redlens", L((150, 20, 18)), 0.2, 0.0, dirt=0.25)
make_mat("glass_dark", L((18, 20, 24)), 0.12, 0.0, dirt=0.2)
make_mat("mirror", L((180, 186, 190)), 0.05, 1.0, dirt=0.15)
make_mat("plate_black", L((28, 28, 28)), 0.6, 0.0, dirt=0.4)
make_mat("neon_white", L((255, 240, 205)), 0.2, 0.0, dirt=0.0)
make_mat("neon_red", L((200, 20, 20)), 0.2, 0.0, dirt=0.0)


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
        scn.collection.objects.link(ob)
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


# ================================================================ ล้อ
def wheel(y):
    W = "FrontWheel" if y < 0 else "RearWheel"
    c = (y, AXLE_Z)
    n = 56
    # ยาง: หน้าตัดกลม ดอกยางที่หน้ายาง (bump) แก้มยางนูน
    prof = []
    tw = 0.17
    for k in range(15):
        t = -1 + 2 * k / 14
        a = t * math.pi * 0.62
        r = 0.86 + 0.17 * math.cos(a)
        dx = tw * math.sin(a) * 1.12
        prof.append((dx, min(TIRE_R, r)))
    prof = [(0.12, 0.745)] + prof + [(-0.12, 0.745)]
    g = lathe_x(c[0], c[1], list(reversed(prof)), n)
    put(W, g, "rubber", 0, 50)
    # ขอบล้อเหล็กชุบ (ร่องตรงกลาง)
    rim = [(-0.13, 0.735), (-0.13, 0.78), (-0.1, 0.79), (-0.07, 0.75), (0.07, 0.75), (0.1, 0.79), (0.13, 0.78), (0.13, 0.735), (0.05, 0.70), (-0.05, 0.70), (-0.13, 0.735)]
    put(W, lathe_x(c[0], c[1], rim, n), "chrome", 0, 50)
    # ดุมล้อ (ดรัมเบรก) อะลูมิเนียม + ฝาดรัมดำด้านเบรก
    hub = [(-0.24, 0.05), (-0.24, 0.13), (-0.2, 0.15), (-0.16, 0.26), (-0.12, 0.30), (0.06, 0.30), (0.1, 0.33), (0.2, 0.33), (0.23, 0.29), (0.24, 0.12), (0.24, 0.05)]
    put(W, lathe_x(c[0], c[1], hub, 28), "alu", 0, 45)
    put(W, lathe_x(c[0], c[1], [(0.245, 0.0), (0.245, 0.26), (0.26, 0.24), (0.26, 0.0)], 28), "steel_black", 0, 45)
    # ซี่ลวด 36 ซี่ ไขว้กัน
    sp = G()
    for i in range(36):
        side = 1 if i % 2 == 0 else -1
        a_h = 2 * math.pi * i / 36
        a_r = a_h + (0.5 if (i // 2) % 2 == 0 else -0.5)
        h = (side * 0.15, c[0] + 0.22 * math.cos(a_h), c[1] + 0.22 * math.sin(a_h))
        r = (side * 0.035, c[0] + 0.71 * math.cos(a_r), c[1] + 0.71 * math.sin(a_r))
        sp.merge(tube([h, r], 0.016, 4, cap=False))
    put(W, sp, "chrome", 0, 60)
    # แกนล้อ + น็อต
    put(W, lathe_x(c[0], c[1], [(-0.32, 0.0), (-0.32, 0.05), (0.32, 0.05), (0.32, 0.0)], 10), "steel_black", 0, 40)


wheel(FRONT_Y)
wheel(REAR_Y)


# ================================================================ ตัวรถ (CustomerBike)
B_ = "CustomerBike"
# ตัวถังท้าย (ฝาข้าง + ท้ายเรียว) ใต้เบาะ
rear_sections = [
    (-0.10, 0.36, 1.52, 2.20, 3.2),
    (0.25, 0.47, 1.42, 2.36, 3.2),
    (0.80, 0.52, 1.46, 2.42, 3.2),
    (1.35, 0.50, 1.70, 2.43, 3.0),
    (1.80, 0.45, 2.06, 2.42, 2.8),
    (2.35, 0.38, 2.10, 2.40, 2.6),
    (2.80, 0.27, 2.12, 2.37, 2.4),
    (3.02, 0.15, 2.16, 2.33, 2.2),
    (3.10, 0.05, 2.20, 2.29, 2.0),
]
put("BodyPaint", loft([ring_y(0, y, (z0 + z1) / 2, hx, (z1 - z0) / 2, 24, p) for y, hx, z0, z1, p in rear_sections]), "paint", 1, 50)
# เบาะ (จีบตามขวาง) นั่งได้ 2 คน
seat_sections = [
    (0.00, 0.30, 2.34, 2.50, 2.6),
    (0.20, 0.40, 2.34, 2.58, 3.0),
    (0.70, 0.45, 2.36, 2.62, 3.4),
    (1.30, 0.46, 2.38, 2.61, 3.4),
    (1.90, 0.44, 2.40, 2.62, 3.2),
    (2.40, 0.38, 2.40, 2.60, 3.0),
    (2.62, 0.26, 2.40, 2.55, 2.6),
]
put(B_, loft([ring_y(0, y, (z0 + z1) / 2, hx, (z1 - z0) / 2, 24, p) for y, hx, z0, z1, p in seat_sections]), "seat", 1, 50)
# ขอบยางเบาะ (แถบชุบล่างเบาะ)
put(B_, loft([ring_y(0, y, 2.355, hx + 0.01, 0.025, 24, 3.4) for y, hx, z0, z1, p in seat_sections[1:-1]], cap=False), "plastic_black", 0, 50)
# ช่วงพื้นต่ำกลางรถ (ก้าวข้ามได้) + ครอบตัวถังกลาง
floor_sections = [
    (-1.00, 0.27, 1.30, 1.80, 2.4),
    (-0.70, 0.29, 1.28, 1.60, 2.6),
    (-0.35, 0.30, 1.28, 1.50, 2.8),
    (-0.05, 0.36, 1.32, 1.78, 3.0),
    (0.15, 0.42, 1.38, 2.05, 3.0),
]
put(B_, loft([ring_y(0, y, (z0 + z1) / 2, hx, (z1 - z0) / 2, 20, p) for y, hx, z0, z1, p in floor_sections]), "plastic_black", 1, 50)
# บังลมหน้า (หน้ากากหน้ารถ ทรงจมูก) รอบคอรถ
front_rings = [
    (1.26, -0.98, 0.38, 0.27, 2.4),
    (1.62, -1.10, 0.44, 0.31, 2.6),
    (2.05, -1.22, 0.45, 0.32, 2.8),
    (2.45, -1.30, 0.40, 0.30, 2.8),
    (2.78, -1.32, 0.31, 0.26, 2.6),
    (2.98, -1.28, 0.21, 0.21, 2.3),
    (3.10, -1.22, 0.12, 0.14, 2.0),
]
put("BodyPaint", loft([ring_z(0, cy, z, hx, hy, 24, p) for z, cy, hx, hy, p in front_rings]), "paint", 1, 50)
# บังลมด้านใน (สีดำ เว้าหลบเข่า) หลังหน้ากาก
inner = [
    (1.32, -0.80, 0.34, 0.06, 2.4),
    (1.85, -0.88, 0.41, 0.07, 2.6),
    (2.35, -0.98, 0.38, 0.07, 2.6),
    (2.75, -1.05, 0.28, 0.07, 2.4),
    (2.98, -1.08, 0.17, 0.06, 2.2),
]
put(B_, loft([ring_z(0, cy, z, hx, hy, 20, p) for z, cy, hx, hy, p in inner]), "plastic_black", 1, 50)
# ไฟเลี้ยวหน้า (ส้ม) ข้างหน้ากาก
for sx in (1, -1):
    tl = lathe_axis((sx * 0.31, -1.55, 2.62), (sx * 0.5, -0.86, 0), [(0, 0.0), (0.0, 0.09), (0.05, 0.11), (0.12, 0.10), (0.15, 0.06), (0.16, 0.0)], 16)
    put(B_, tl, "amber", 0, 50)
    # ไฟเลี้ยวหลัง
    tr = lathe_axis((sx * 0.27, 2.93, 2.30), (sx * 0.4, 0.9, 0.0), [(0, 0.0), (0.0, 0.06), (0.04, 0.075), (0.09, 0.065), (0.11, 0.0)], 14)
    put(B_, tr, "amber", 0, 50)
# ตัวเรือนไฟท้าย (ดำ) รอบเลนส์
put(B_, lathe_axis((0, 3.03, 2.27), (0, 1, 0), [(-0.05, 0.0), (-0.05, 0.16), (0.02, 0.17), (0.03, 0.0)], 20), "plastic_black", 0, 50)

# บังโคลนหลังด้านใน (ดำ) ครอบล้อหลังใต้ตัวถัง
fd = []
for k in range(15):
    a = math.radians(20 + 120 * k / 14)  # จากหลังบน -> หน้าบน (รอบล้อหลัง)
    r = 1.15
    fd.append(ring_y(0, 0, 0, 0.2, 0.03, 12, 2.0))
rings = []
for k in range(15):
    a = math.radians(48 + 84 * k / 14)
    cy, cz = REAR_Y + 1.13 * math.cos(a), AXLE_Z + 1.13 * math.sin(a)
    nrm = Vector((0, math.cos(a), math.sin(a)))
    tan = Vector((0, -math.sin(a), math.cos(a)))
    rg = []
    for i in range(12):
        t = 2 * math.pi * i / 12
        off = Vector((0.21 * sup(math.cos(t), 0, 3.0), 0, 0)) + nrm * 0.035 * sup(math.sin(t), 0, 3.0)
        rg.append(tuple(Vector((0, cy, cz)) + off))
    rings.append(rg)
put(B_, loft(rings), "plastic_black", 0, 50)
# บังโคลนท้าย + ขาป้ายทะเบียน (ห้อยหลังล้อ)
mud = [((0, 2.85, 2.12)), (0, 3.12, 1.98), (0, 3.28, 1.78), (0, 3.34, 1.55), (0, 3.33, 1.36)]
rings = []
P, T, N, Bv = frames(mud)
for p, t, n_, b in zip(P, T, N, Bv):
    side = Vector((1, 0, 0))
    up = t.cross(side).normalized()
    rings.append([tuple(p + side * 0.24 * sup(math.cos(2 * math.pi * i / 12), 0, 3.0) + up * 0.03 * sup(math.sin(2 * math.pi * i / 12), 0, 3.0)) for i in range(12)])
put(B_, loft(rings), "plastic_black", 1, 50)

# เครื่องยนต์: ห้องข้อเหวี่ยงอะลูมิเนียม + เสื้อสูบนอนชี้หน้า ครีบระบายความร้อน
put(B_, box((0, 0.18, 0.92), (0.58, 0.95, 0.66)), "alu", 2, 40)
cyl = [(0, 0.27), (0.04, 0.27)]
for k in range(7):
    t0 = 0.06 + k * 0.075
    cyl += [(t0, 0.25), (t0 + 0.005, 0.33), (t0 + 0.035, 0.33), (t0 + 0.04, 0.25)]
cyl += [(0.62, 0.25), (0.66, 0.22), (0.7, 0.0)]
put(B_, lathe_axis((0, -0.25, 1.0), (0, -1, -0.12), cyl, 20), "alu", 0, 35)
# ฝาครอบแม่เหล็ก (ซ้าย) + ฝาครัช (ขวา)
put(B_, lathe_axis((0.30, 0.25, 0.88), (1, 0, 0), [(0, 0.34), (0.06, 0.34), (0.10, 0.30), (0.12, 0.2), (0.13, 0.0)], 28), "alu", 0, 40)
put(B_, lathe_axis((-0.30, 0.10, 0.92), (-1, 0, 0), [(0, 0.30), (0.05, 0.30), (0.09, 0.26), (0.11, 0.15), (0.12, 0.0)], 28), "alu", 0, 40)
# คาร์บู + กรองอากาศ (ดำ) บนเครื่อง
put(B_, box((0, -0.18, 1.33), (0.42, 0.35, 0.22)), "plastic_black", 2, 40)
# ท่อไอเสีย: ออกใต้ฝาสูบ วกไปขวา ขึ้นไปหม้อพักท้าย
ex = [(0.0, -0.88, 0.86), (0.0, -0.98, 0.70), (-0.05, -0.92, 0.52), (-0.20, -0.60, 0.46), (-0.32, -0.10, 0.48), (-0.38, 0.50, 0.58), (-0.42, 0.95, 0.74)]
put(B_, tube(ex, 0.065, 12), "steel_black", 0, 60)
muf = [(0, 0.0), (0.0, 0.13), (0.08, 0.17), (1.35, 0.17), (1.48, 0.14), (1.55, 0.09), (1.56, 0.0)]
put(B_, lathe_axis((-0.43, 0.90, 0.75), (0, 1, 0.12), muf, 22), "steel_black", 0, 50)
# แผ่นกันร้อนชุบ (ครึ่งนอกของหม้อพัก)
hs = []
for k in range(12):
    t = k / 11
    y = 1.05 + 0.95 * t
    z = 0.77 + 0.12 * (y - 0.9)
    hs.append([(-0.43 - 0.2 * math.cos(a), y, z + 0.2 * math.sin(a)) for a in [math.radians(-80 + 160 * i / 10) for i in range(11)]])
g = G()
for r in hs:
    g.v += r
for j in range(len(hs) - 1):
    for i in range(10):
        a, b = j * 11 + i, j * 11 + i + 1
        g.f.append((a, a + 11, b + 11, b))
put(B_, g, "chrome", 0, 50)
# ปลายท่อ
put(B_, lathe_axis((-0.43, 2.44, 0.94), (0, 1, 0.12), [(0, 0.06), (0.12, 0.06), (0.12, 0.045), (0.0, 0.045)], 14), "chrome", 0, 50)

# สวิงอาร์ม (เหล็กดำ) + บังโซ่ปิดทึบ (ซ้าย)
for sx in (1, -1):
    sw = [(sx * 0.20, 0.55, 0.98), (sx * 0.21, 1.3, 1.0), (sx * 0.21, 2.1, 1.03)]
    put(B_, tube(sw, 0.06, 10), "steel_black", 0, 50)
chain = [ring_y(0.26, y, z, 0.045, hz, 14, 2.6) for y, z, hz in [(0.40, 0.98, 0.13), (0.70, 0.99, 0.17), (1.40, 1.01, 0.17), (2.05, 1.03, 0.21), (2.30, 1.03, 0.19)]]
put(B_, loft(chain), "plastic_black", 1, 50)
# โช้คหลังคู่ (สปริงชุบ)
for sx in (1, -1):
    a = Vector((sx * 0.30, 1.98, 1.12))
    b = Vector((sx * 0.30, 1.62, 2.18))
    put(B_, tube([a, a + (b - a) * 0.22], 0.06, 12), "steel_black", 0, 50)
    put(B_, tube([a + (b - a) * 0.7, b], 0.075, 12), "chrome", 0, 50)
    put(B_, helix(a + (b - a) * 0.2, a + (b - a) * 0.78, 0.085, 7, 0.022, 6), "chrome", 0, 60)
    put(B_, tube([a + (b - a) * 0.15, a + (b - a) * 0.85], 0.04, 8), "steel_black", 0, 50)
# ตะแกรงหลัง / มือจับซ้อนท้าย (ชุบ) รอบเบาะท้าย
rack = [(0.44, 1.45, 2.36), (0.47, 2.00, 2.42), (0.44, 2.55, 2.46), (0.34, 2.86, 2.47), (0.0, 2.95, 2.48), (-0.34, 2.86, 2.47), (-0.44, 2.55, 2.46), (-0.47, 2.00, 2.42), (-0.44, 1.45, 2.36)]
put(B_, tube(rack, 0.045, 10), "chrome", 0, 60)
for y in (2.45, 2.70):
    put(B_, tube([(0.42, y, 2.46), (-0.42, y, 2.46)], 0.03, 8), "chrome", 0, 60)
for sx in (1, -1):
    put(B_, tube([(sx * 0.47, 2.0, 2.42), (sx * 0.47, 2.05, 2.15)], 0.035, 8), "chrome", 0, 60)
# ที่พักเท้าคนขับ (ยาง) + แกน
put(B_, tube([(-0.82, 0.35, 0.92), (0.82, 0.35, 0.92)], 0.045, 10), "steel_black", 0, 50)
for sx in (1, -1):
    put(B_, tube([(sx * 0.55, 0.35, 0.92), (sx * 0.86, 0.35, 0.92)], 0.075, 12), "rubber_plain", 0, 50)
    # ที่พักเท้าซ้อนท้าย (พับ)
    put(B_, tube([(sx * 0.30, 1.55, 1.10), (sx * 0.58, 1.58, 1.08)], 0.05, 10), "rubber_plain", 0, 50)
# คันเกียร์ (ซ้าย) + คันสตาร์ท (ขวา) + ขาตั้งข้าง (ซ้าย)
put(B_, tube([(0.36, 0.05, 0.98), (0.48, -0.15, 0.90), (0.55, -0.30, 0.92), (0.62, -0.28, 0.95)], 0.03, 8), "steel_black", 0, 50)
put(B_, tube([(-0.40, 0.45, 1.05), (-0.46, 0.75, 1.18), (-0.50, 0.92, 1.22)], 0.03, 8), "steel_black", 0, 50)
put(B_, tube([(0.24, 0.60, 0.70), (0.34, 1.10, 0.64), (0.36, 1.32, 0.66)], 0.04, 8), "steel_black", 0, 50)  # ขาตั้งข้าง (พับเก็บ)
# แกนตัวถัง (เหล็กดำ) จากคอรถลงใต้พื้น (เห็นช่วงใต้ตัวถัง)
put(B_, tube([(0, -1.10, 2.9), (0, -1.05, 1.6), (0, -0.70, 1.20), (0, 0.10, 1.12)], 0.08, 10), "steel_black", 0, 50)
# ตะกร้าหน้า (ลวดดำ) ติดหน้ากาก
bk = G()
x0, x1, y0, y1, z0, z1 = -0.40, 0.40, -2.42, -1.88, 2.30, 2.84
for k in range(6):  # เส้นนอน
    z = z0 + (z1 - z0) * k / 5
    loop = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), (x0, y0, z)]
    bk.merge(tube(loop, 0.014, 4, cap=False))
for k in range(9):
    x = x0 + (x1 - x0) * k / 8
    for yy in (y0, y1):
        bk.merge(tube([(x, yy, z0), (x, yy, z1)], 0.012, 4, cap=False))
for k in range(6):
    y = y0 + (y1 - y0) * k / 5
    for xx in (x0, x1):
        bk.merge(tube([(xx, y, z0), (xx, y, z1)], 0.012, 4, cap=False))
for k in range(5):  # พื้นตะกร้า
    y = y0 + (y1 - y0) * k / 4
    bk.merge(tube([(x0, y, z0), (x1, y, z0)], 0.012, 4, cap=False))
bk.merge(tube([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1)], 0.03, 6, cap=False))
bk.merge(tube([(0.25, y1, 2.45), (0.25, -1.62, 2.40)], 0.025, 6))
bk.merge(tube([(-0.25, y1, 2.45), (-0.25, -1.62, 2.40)], 0.025, 6))
put(B_, bk, "steel_black", 0, 70)

# ================================================================ คอ/แฮนด์ (Handlebar): โช้คหน้า บังโคลนหน้า ฝาครอบแฮนด์ กระจก
H_ = "Handlebar"
axis = (HEAD_TOP - Vector((0, FRONT_Y, AXLE_Z))).normalized()
for sx in (1, -1):
    base = Vector((sx * 0.23, FRONT_Y, AXLE_Z))
    put(H_, tube([base - axis * 0.06, base + axis * 1.05], 0.072, 14), "chrome", 0, 50)
    put(H_, tube([base + axis * 1.0, base + axis * 2.05], 0.092, 14), "steel_black", 0, 50)
    # ขาจับล้อ
    put(H_, tube([base + Vector((0, 0.02, -0.04)), base + Vector((0, 0.10, 0.08))], 0.05, 8), "alu", 0, 50)
# ปลอกคอ (สีตัวรถ) เชื่อมหน้ากากขึ้นไปถึงฝาครอบแฮนด์ ไม่ให้แฮนด์ดูลอย
ck0 = Vector((0, FRONT_Y, AXLE_Z)) + axis * 2.05
ck1 = Vector((0, -1.16, 3.44))
put("HandlebarPaint", tube([ck0, ck0 + (ck1 - ck0) * 0.5, ck1], [0.16, 0.15, 0.17], 16), "paint", 1, 50)
# แผงคอล่าง/บน
for t in (1.95, 2.2):
    c = Vector((0, FRONT_Y, AXLE_Z)) + axis * t
    put(H_, box(tuple(c), (0.6, 0.2, 0.09)), "steel_black", 2, 40)
# บังโคลนหน้า (สีตัวรถ) ครอบครึ่งบนล้อ
rings = []
for k in range(17):
    a = math.radians(28 + 118 * k / 16)  # หน้า (เหนือแนวนอน 28°) -> หลังบน
    cy, cz = FRONT_Y - 1.13 * math.cos(a), AXLE_Z + 1.13 * math.sin(a)
    nrm = Vector((0, -math.cos(a), math.sin(a)))
    rg = []
    for i in range(12):
        t = 2 * math.pi * i / 12
        off = Vector((0.20 * sup(math.cos(t), 0, 3.0), 0, 0)) + nrm * 0.03 * sup(math.sin(t), 0, 3.0)
        rg.append(tuple(Vector((0, cy, cz)) + off))
    rings.append(rg)
put("HandlebarPaint", loft(rings), "paint_fender", 1, 50)
# ฝาครอบแฮนด์ (ครอบบน) + เรือนไฟหน้า
cover = [ring_y(0, 0, 0, 1, 1, 4)]  # placeholder
cov_rings = []
for k in range(9):
    x = -0.56 + 1.12 * k / 8
    w = 1 - (abs(x) / 0.56) ** 2.2
    cy = -1.20 - 0.10 * w
    hy, hz = 0.18 + 0.12 * w, 0.10 + 0.07 * w
    cz = 3.42 + 0.03 * w
    rg = []
    for i in range(20):
        a = 2 * math.pi * i / 20
        rg.append((x, cy + hy * sup(math.cos(a), 0, 2.6), cz + hz * sup(math.sin(a), 0, 2.6)))
    cov_rings.append(rg)
put("HandlebarPaint", loft(cov_rings), "paint", 1, 50)
# เรือนไฟหน้า (ยื่นไปหน้า) — เลนส์เป็นชิ้น Headlight_Neon แยก
hl = [ring_y(0, y, 3.36, hx, hz, 24, 2.4) for y, hx, hz in [(-1.30, 0.33, 0.21), (-1.48, 0.31, 0.20), (-1.58, 0.29, 0.19), (-1.61, 0.275, 0.18)]]
put("HandlebarPaint", loft(hl, cap=False), "paint", 1, 50)
put(H_, loft([ring_y(0, y, 3.36, hx, hz, 24, 2.4) for y, hx, hz in [(-1.605, 0.28, 0.185), (-1.585, 0.25, 0.16)]], cap=False), "chrome", 0, 50)
# หน้าปัดไมล์ (บนฝาครอบ หันหาคนขับ)
put(H_, lathe_axis((0, -1.05, 3.55), (0, 0.55, 0.83), [(0, 0.0), (0.0, 0.17), (0.03, 0.18), (0.05, 0.16), (0.055, 0.0)], 24), "glass_dark", 0, 50)
put(H_, lathe_axis((0, -1.05, 3.55), (0, 0.55, 0.83), [(0.0, 0.18), (0.035, 0.19), (0.04, 0.175)], 24), "chrome", 0, 50)
# แฮนด์ + ปลอกแฮนด์ยาง + สวิตช์ + มือเบรก
for sx in (1, -1):
    bar = [(sx * 0.45, -1.16, 3.48), (sx * 0.62, -1.10, 3.56), (sx * 0.80, -1.06, 3.62), (sx * 1.12, -1.04, 3.64)]
    put(H_, tube(bar, 0.045, 10), "chrome", 0, 50)
    put(H_, tube([(sx * 0.78, -1.05, 3.63), (sx * 1.10, -1.04, 3.64)], 0.075, 14), "rubber_plain", 0, 50)
    put(H_, tube([(sx * 1.10, -1.04, 3.64), (sx * 1.14, -1.04, 3.64)], 0.06, 12), "chrome", 0, 50)
    put(H_, box((sx * 0.70, -1.07, 3.60), (0.13, 0.16, 0.13)), "plastic_black", 2, 40)
    lev = [(sx * 0.70, -1.14, 3.62), (sx * 0.82, -1.24, 3.62), (sx * 1.00, -1.25, 3.60), (sx * 1.08, -1.22, 3.60)]
    put(H_, tube(lev, 0.022, 8), "alu", 0, 50)
    # กระจกมองข้าง: ก้านชุบ + หัวกลมหันหลัง
    stem = [(sx * 0.55, -1.12, 3.58), (sx * 0.64, -1.08, 3.78), (sx * 0.76, -1.03, 3.94), (sx * 0.84, -1.01, 4.00)]
    put(H_, tube(stem, 0.022, 8), "chrome", 0, 50)
    mh = lathe_axis((sx * 0.88, -0.98, 4.08), (0, 1, 0.05), [(-0.06, 0.0), (-0.06, 0.12), (-0.03, 0.17), (0.02, 0.17), (0.03, 0.0)], 22)
    put(H_, mh, "steel_black", 0, 50)
    put(H_, lathe_axis((sx * 0.88, -0.98 + 0.031, 4.08 + 0.0015), (0, 1, 0.05), [(0.0, 0.0), (0.0, 0.155)], 22), "mirror", 0, 50)

# ================================================================ ไฟหน้า / ไฟท้าย / กรอบป้าย (ชิ้นแยกตามโครงเดิม)
put("Headlight_Neon", loft([ring_y(0, y, 3.36, hx, hz, 24, 2.4) for y, hx, hz in [(-1.59, 0.255, 0.165), (-1.63, 0.22, 0.14), (-1.645, 0.12, 0.08)]], cap=True), "neon_white", 1, 50)
put("Taillight_Neon", loft([ring_y(0, y, 2.27, hx, hz, 20, 2.2) for y, hx, hz in [(3.03, 0.15, 0.07), (3.07, 0.14, 0.065), (3.09, 0.08, 0.04)]], cap=True), "neon_red", 1, 50)
pf = G()
# แผ่นรองหลังป้าย (ป้าย SurfaceGui อยู่ที่ y 3.36: แผ่นนี้ต้องอยู่หลังป้าย ไม่งั้นทับหน้าป้ายเป็นสีดำ)
pf.merge(box((0, 3.29, 1.62), (0.92, 0.04, 0.52)))
pf.merge(tube([(-0.46, 3.26, 1.88), (0.46, 3.26, 1.88)], 0.025, 6))
put("LicensePlateFrame", pf, "plate_black", 0, 40)


# ---------------------------------------------------------------- สร้าง object ทั้งหมด
ORDER = ["CustomerBike", "BodyPaint", "Handlebar", "HandlebarPaint", "FrontWheel", "RearWheel", "Headlight_Neon", "Taillight_Neon", "LicensePlateFrame"]
OBJ = {n: build_object(n) for n in ORDER}
# เอียงกรอบป้าย 8° (เหมือนป้ายเดิม)
pfo = OBJ["LicensePlateFrame"]
piv = Vector((0, 3.36, 1.62)) * S
pfo.data.transform(Matrix.Translation(piv) @ Matrix.Rotation(math.radians(8), 4, "X") @ Matrix.Translation(-piv))


# ---------------------------------------------------------------- UV + bake ลงภาพ (Cycles)
BAKED = {"CustomerBike": "CustomerBikeV2", "BodyPaint": "CustomerBikeV2_Paint", "Handlebar": "CustomerBikeV2_Handlebar", "HandlebarPaint": "CustomerBikeV2_HandlebarPaint", "FrontWheel": "CustomerBikeV2_Wheel", "LicensePlateFrame": "CustomerBikeV2_Plate"}


def uv_unwrap(ob, margin=0.004):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(ob, stem):
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


if not NO_BAKE:
    done = {}
    for name, stem in BAKED.items():
        ob = OBJ[name]
        uv_unwrap(ob)
        log("baking", name)
        imgs = bake(ob, stem)
        done[name] = final_material(stem, imgs)
    # ล้อหลัง = ล้อหน้า (รูปเดียวกัน UV เดียวกัน)
    rw = OBJ["RearWheel"]
    uv_unwrap(rw)
    for name, mat in list(done.items()) + [("RearWheel", done["FrontWheel"])]:
        ob = OBJ[name]
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        for p in ob.data.polygons:
            p.material_index = 0
    for name, col in (("Headlight_Neon", (1.0, 0.88, 0.62)), ("Taillight_Neon", (0.8, 0.03, 0.03))):
        ob = OBJ[name]
        ob.data.materials.clear()
        ob.data.materials.append(neon_material(name + "_Mat", col))

# ---------------------------------------------------------------- export FBX
bpy.ops.object.select_all(action="DESELECT")
for o in OBJ.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = OBJ["CustomerBike"]
bpy.ops.export_scene.fbx(filepath=os.path.join(UP, "CustomerBikeV2.fbx"), use_selection=True, apply_scale_options="FBX_SCALE_NONE",
                         axis_forward="-Z", axis_up="Y", bake_space_transform=True, object_types={"MESH"},
                         mesh_smooth_type="FACE", path_mode="STRIP", embed_textures=False, use_mesh_modifiers=True)
log("fbx", os.path.join(UP, "CustomerBikeV2.fbx"))


# ---------------------------------------------------------------- ภาพตัวอย่าง (EEVEE กลางวันนวล + กลางคืนไฟหน้า) + คนนั่งเทียบ
def add_rider():
    """ชาวบ้าน human_base ท่า ride_moto วางสะโพกที่ HIP (ภาพตัวอย่างเท่านั้น ไม่ export)"""
    path = os.path.join(ROOT, "human_base", "human_base.blend")
    if not os.path.exists(path):
        return []
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in ("HumanRig", "Body") or n.startswith("Cloth_mohom") or n == "Hair_student"]
        dst.actions = [n for n in src.actions if n == "ride_moto"]
    objs = [o for o in dst.objects if o]
    for o in objs:
        scn.collection.objects.link(o)
    rig = next((o for o in objs if o.type == "ARMATURE"), None)
    if rig and dst.actions:
        rig.animation_data_create()
        rig.animation_data.action = dst.actions[0]
        scn.frame_set(1)
        hips = rig.data.bones["hips"].head_local
        k = S * 3.5 / 3.5  # human blend: เมตร (3.5 studs/m) ≈ S
        rig.scale = (1 / (3.5 * S),) * 3 if False else (1, 1, 1)
        rig.location = Vector((0, HIP.y * S, HIP.z * S)) - hips * 1.0
    return objs


def preview():
    rider = add_rider()
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = 1200, 800
    w = bpy.data.worlds.new("W")
    scn.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.44, 0.47, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scn.collection.objects.link(sun)
    fl = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fl.data.energy = 300
    fl.data.size = 3
    fl.location = (2.0, -2.5, 1.6)
    fl.rotation_euler = (math.radians(60), 0, math.radians(40))
    scn.collection.objects.link(fl)
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
    tgt = Vector((0, 0.0, 2.05)) * S

    def shot(fn, d, lens=55, dist=2.6, show_rider=False):
        for o in rider:
            o.hide_render = not show_rider
        cam.data.lens = lens
        cam.location = tgt + Vector(d).normalized() * dist
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(OUT, fn)
        bpy.ops.render.render(write_still=True)

    tints = []
    for nm in ("BodyPaint", "HandlebarPaint"):
        ob = OBJ.get(nm)
        if ob and ob.data.materials and ob.data.materials[0].use_nodes:
            nt = ob.data.materials[0].node_tree
            bs = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
            if bs.inputs["Base Color"].links:
                src = bs.inputs["Base Color"].links[0].from_socket
                mx = nt.nodes.new("ShaderNodeMix")
                mx.data_type = "RGBA"
                mx.blend_type = "MULTIPLY"
                mx.inputs["Factor"].default_value = 1.0
                nt.links.new(src, mx.inputs["A"])
                nt.links.new(mx.outputs["Result"], bs.inputs["Base Color"])
                tints.append(mx)

    def tint(c):
        for mx in tints:
            mx.inputs["B"].default_value = (*L(c), 1)

    tint((128, 24, 26))
    shot("CustomerBikeV2.png", (-0.9, -1.2, 0.5), dist=3.1)
    shot("CustomerBikeV2_side.png", (1.0, 0.0, 0.08), lens=50, dist=3.2)
    shot("CustomerBikeV2_rear.png", (0.7, 1.3, 0.45), dist=3.1)
    shot("CustomerBikeV2_detail.png", (-0.6, -0.5, 0.25), lens=70, dist=1.6)
    for nm, c in (("blue", (28, 52, 120)), ("black", (30, 30, 32)), ("bronze", (128, 118, 100)), ("green", (72, 86, 50)), ("white", (200, 196, 184)), ("orange", (168, 78, 38))):
        tint(c)
        scn.render.resolution_x, scn.render.resolution_y = 600, 400
        shot(f"CustomerBikeV2_color_{nm}.png", (-0.9, -1.2, 0.5), dist=3.1)
    scn.render.resolution_x, scn.render.resolution_y = 1200, 800
    tint((128, 24, 26))
    if rider:
        shot("CustomerBikeV2_rider_side.png", (1.0, 0.0, 0.08), lens=50, dist=3.2, show_rider=True)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "customer_bike_v2.blend"))
log("done")
