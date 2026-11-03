# เปรต (Pret) ผีตัวสูงผอมเท่าต้นตาล ขายาวมาก ลิ้นยาวห้อยถึงท้อง — ตัวละครมี rig + 3 ท่า สำหรับนำเข้า Roblox — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\pret.py -Out C:\tmp\pret.txt -TimeoutSec 2400
#   $env:PRET_STAGE = "shape" = ยืดตัว + ผ้า + ลิ้น แล้ว render ภาพเร็วๆ อย่างเดียว (ไม่ paint ไม่ทำท่า ไม่ export)
#   $env:PRET_STAGE = "check" = ทำทุกอย่างจนถึงตรวจการทะลุทุกเฟรม แล้วหยุด (ไม่ export ไม่ render)
# ต้นแบบ: ตัวชายผอม assets/models/human_base/human_base_thin.blend (HumanRig 52 กระดูก + weight + joint limits + UV เดิม) แบบเดียวกับกระหัง
#   ยืดตามกระดูก (ขา x3 ลำตัว x1.6 คอ x2.4 นิ้ว x2.6) ให้สูง 4.0 ม. = 14 studs สะโพกอยู่ ~60% ของความสูง (ขาเด่นสุด)
#   subdivide 1 ระดับ แล้วดัดผิวให้เป็นหนังหุ้มกระดูก: ซี่โครงบาน ท้องตอบ แขนขาคอดกลางท่อน เข่า/ศอก/ข้อเท้าปูดเป็นปุ่มนูนใต้หนัง
#   ลายผิว (ร่องซี่โครง ไหปลาร้า กระดูกสันหลัง ผิวแห้งแตก เส้นเลือด เล็บ หน้า) วาดลง texture ด้วย numpy ในพิกัด 3 มิติ (วิธีเดียวกับกระหัง)
# ชิ้น: Body, Eyes (ลูกตาโปน), Tongue (ลิ้นยาว กระดูก Tongue1-6 ห้อยตามแรงโน้มถ่วงทุกเฟรม), Hair (ผมยุ่งสั้นแค่ต้นคอ),
#       Cloth (ผ้าขาวม้านุ่งจงกระเบนแบบกระหัง: ผืนเดียวพันแนบสะโพก ข้างสั้น หน้า-หลังร่นถึงเป้า ปมที่สะโพกซ้าย ชายผ้า 2 ชาย)
# rig = HumanRig เดิม + Tongue1..Tongue6 (ลูกของ head) · weight ไม่เกิน 4 กระดูกต่อจุด
# ท่า (30 fps): Idle (121 เฟรม วนลูป), TallSlowWalk (97 วนลูป), Shriek (91 ครั้งเดียว) · ตรวจการทะลุทุกเฟรมทุกท่า (check_clips)
# texture ชุดเดียว 1024 ใช้ร่วมทุกชิ้น (atlas)
# ผลลัพธ์: assets/models/Pret.fbx + Pret_Idle.fbx / Pret_TallSlowWalk.fbx / Pret_Shriek.fbx (rig + ท่า)
#          Pret_Color/_Normal/_Roughness/_Metalness.png, assets/models/pret.blend
#          previews/Pret.png (3/4), Pret_front.png, Pret_side.png, Pret_rest.png, Pret_face.png, Pret_scale.png,
#          Pret_clips_front.png / Pret_clips_side.png (แถว = ท่า, 6 จังหวะต่อท่า)
import bpy, bmesh, math, os, sys, random, time, traceback
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
M = os.path.join(REPO, "assets", "models")
HB = os.path.join(M, "human_base")
PREV = os.path.join(M, "previews")
NAME = "Pret"
BAKE = 2048               # bake / paint size; saved textures are averaged down to TEX
TEX = 1024
STUDS_PER_M = 3.5         # เหมือนตัวมนุษย์และกระหัง (ชาย 1.80 ม. = 6.3 studs)
HEIGHT = 4.0              # = 14 studs
STAGE = os.environ.get("PRET_STAGE", "full")
R = math.radians
LOG = []
T0 = time.time()


def log(*a):
    s = " ".join(str(x) for x in a)
    LOG.append(f"[{time.time() - T0:6.1f}s] {s}")
    print(s)


def load_ns(fn):
    ns = {"__name__": "lib_" + os.path.basename(fn)}
    exec(compile(open(os.path.join(HB, fn), encoding="utf-8").read(), fn, "exec"), ns)
    return ns


HAIR = load_ns("build_hair.py")
AN = load_ns("build_anims.py")


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def sm(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ================================================================ 1. ตัวคนผอม -> เปรต
def open_base():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HB, "human_base_thin.blend"))
    for o in list(bpy.data.objects):
        if o.name not in ("Body", "HumanRig"):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    for c in list(bpy.data.collections):
        if not c.objects:
            bpy.data.collections.remove(c)
    rig = bpy.data.objects["HumanRig"]
    body = bpy.data.objects["Body"]
    if rig.animation_data:
        rig.animation_data_clear()
    for p in rig.pose.bones:
        p.rotation_euler = (0, 0, 0)
        p.location = (0, 0, 0)
    bpy.context.view_layer.update()
    return rig, body


# (ตัวคูณความยาวตามกระดูก, ตัวคูณความหนาขวางกระดูก) เทียบกับตัวคนผอมสูง 1.80 ม. ก่อนย่อ/ขยายรวมให้สูง HEIGHT
FACT = {"hips": (1.55, 1.45), "spine": (1.6, 1.22), "chest": (1.6, 1.28), "neck": (2.4, 1.15), "head": (1.4, 1.4),
        "shoulder": (1.5, 1.25), "upper_arm": (3.3, 1.05), "forearm": (3.3, 0.95), "hand": (2.2, 1.35),
        "thigh": (3.0, 1.0), "shin": (2.9, 0.92), "foot": (1.6, 1.45), "toe": (1.6, 1.45)}
FINGER, THUMB = (2.6, 1.15), (2.2, 1.15)
TORSO_K = {}   # ตัวแปลงพิกัดลำตัวของเปรตกลับเป็นพิกัดตัวคน (ใช้ตำแหน่งซี่โครง/ท้อง/ไหปลาร้าชุดเดียวกับกระหัง)


def factor(name):
    base = name.split(".")[0]
    if base.startswith(("index", "middle", "ring", "pinky")):
        return FINGER
    if base.startswith("thumb"):
        return THUMB
    return FACT.get(base, (1.0, 1.0))


def body_weights(ob, names):
    """น้ำหนัก (จำนวนจุด x จำนวนกระดูก) จาก vertex groups"""
    gi = {g.index: g.name for g in ob.vertex_groups}
    col = {n: i for i, n in enumerate(names)}
    W = np.zeros((len(ob.data.vertices), len(names)))
    for v in ob.data.vertices:
        for g in v.groups:
            n = gi.get(g.group)
            if n in col:
                W[v.index, col[n]] = g.weight
    return W


def stretch(rig, body):
    """ยืดตามกระดูก: แต่ละกระดูกมี matrix (ยาว L เท่าตามแกน ขวาง T เท่า) จุดบนผิว = ผลรวมถ่วงน้ำหนักของทุกกระดูก
    ทิศกระดูกไม่เปลี่ยน (roll / joint limits / ท่าของคนใช้ได้เหมือนเดิม) หัวกระดูกลูกตามไปกับ matrix ของพ่อ"""
    bones = rig.data.bones
    names = [b.name for b in bones]
    oh = {b.name: Vector(b.head_local) for b in bones}
    ot = {b.name: Vector(b.tail_local) for b in bones}
    A, nh, nt = {}, {}, {}

    def walk(b):
        L, T = factor(b.name)
        Rb = b.matrix_local.to_3x3()
        A[b.name] = Rb @ Matrix.Diagonal((T, L, T)) @ Rb.transposed()
        p = b.parent
        nh[b.name] = oh[b.name] if p is None else nh[p.name] + A[p.name] @ (oh[b.name] - oh[p.name])
        nt[b.name] = nh[b.name] + A[b.name] @ (ot[b.name] - oh[b.name])
        for c in b.children:
            walk(c)
    for b in bones:
        if b.parent is None:
            walk(b)
    me = body.data
    P = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    W = body_weights(body, names)
    out = P * np.clip(1 - W.sum(1), 0, 1)[:, None]
    for i, n in enumerate(names):
        w = W[:, i]
        if not (w > 0).any():
            continue
        Am = np.array(A[n])
        out += w[:, None] * (np.array(nh[n]) + (P - np.array(oh[n])) @ Am.T)
    z0 = out[:, 2].min()
    u = HEIGHT / (out[:, 2].max() - z0)
    off = np.array((0.0, 0.0, z0))
    out = (out - off) * u
    me.vertices.foreach_set("co", out.ravel())
    me.update()
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in rig.data.edit_bones:
        eb.head = (nh[eb.name] - Vector(off)) * u
        eb.tail = (nt[eb.name] - Vector(off)) * u
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()
    hz = rig.data.bones["thigh.L"].head_local.z
    nz = rig.data.bones["neck"].head_local.z
    TORSO_K.update(z0=rig.data.bones["hips"].head_local.z, kz=(nz - rig.data.bones["hips"].head_local.z) / (1.45 - 0.88),
                   kx=1.27 * u, ky=1.22 * u, u=u)
    log(f"stretch: uniform x{u:.3f}; hip joints {hz:.2f} m = {hz / HEIGHT * 100:.0f}% of height, neck base {nz:.2f} m")


def torso_q(P):
    """พิกัดลำตัวเปรต -> พิกัดตัวคนเทียบเท่า (เกณฑ์ตำแหน่งซี่โครง/ท้องของกระหังใช้ได้ตรงๆ)"""
    k = TORSO_K
    return P[:, 0] / k["kx"], P[:, 1] / k["ky"], 0.88 + (P[:, 2] - k["z0"]) / k["kz"]


def torso_z(zh):
    k = TORSO_K
    return k["z0"] + (zh - 0.88) * k["kz"]


def subdivide(body):
    m = body.modifiers.new("Sub", "SUBSURF")
    m.levels = m.render_levels = 1
    m.uv_smooth = "PRESERVE_BOUNDARIES"
    bpy.context.view_layer.objects.active = body
    for o in bpy.context.selected_objects:
        o.select_set(False)
    body.select_set(True)
    bpy.ops.object.modifier_move_to_index(modifier="Sub", index=0)
    bpy.ops.object.modifier_apply(modifier="Sub")
    log(f"subdivide: {len(body.data.vertices)} verts, {sum(len(p.vertices) - 2 for p in body.data.polygons)} tris")


# ข้อต่อ (หัว, ท้าย) ของกระดูกแขนขา: >1 = ปุ่มกระดูกนูนใต้หนัง, ตรงกลางท่อนคอดเหลือแต่หนังติดกระดูก
LIMB_SHAPE = {"upper_arm": (1.0, 1.13), "forearm": (1.13, 1.04), "thigh": (1.0, 1.16), "shin": (1.16, 1.08)}
LIMB_SHAFT = 0.84


def gaunt(body, rig):
    """หนังหุ้มกระดูก: ซี่โครงบานเหนือท้องตอบลึก แขนขาคอดกลางท่อน ปุ่มเข่า ศอก ข้อเท้านูน"""
    me = body.data
    P = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    names = [b.name for b in rig.data.bones]
    W = body_weights(body, names)
    col = {n: i for i, n in enumerate(names)}
    torso = W[:, col["chest"]] + W[:, col["spine"]] + W[:, col["hips"]]
    X, Y, Z = torso_q(P)
    k = TORSO_K
    rib = np.exp(-((Z - 1.26) / 0.08) ** 2) * sstep(0.5, 0.8, torso)
    P[:, 0] *= 1 + 0.07 * rib
    P[:, 1] = np.where(Y < 0.05, P[:, 1] * (1 + 0.07 * rib), P[:, 1])
    belly = np.exp(-((Z - 1.05) / 0.07) ** 2) * sstep(0.5, 0.8, torso) * np.clip(-Y / 0.05, 0, 1)
    P[:, 1] += 0.055 * k["u"] * belly
    P[:, 0] *= 1 - 0.12 * belly
    side = np.exp(-((Z - 1.05) / 0.08) ** 2) * sstep(0.5, 0.8, torso)             # เอวคอดด้านข้าง
    P[:, 0] *= 1 - 0.08 * side
    sig = 0.075
    for base, (hf, tf) in LIMB_SHAPE.items():
        for s in ("L", "R"):
            n = f"{base}.{s}"
            b = rig.data.bones[n]
            h, t = np.array(b.head_local), np.array(b.tail_local)
            d = t - h
            L = np.linalg.norm(d)
            d /= L
            w = W[:, col[n]]
            sel = w > 0.05
            q = P[sel] - h
            a = np.clip(q @ d, 0, L)
            rad = q - np.outer(q @ d, d)
            f = LIMB_SHAFT + (hf - LIMB_SHAFT) * np.exp(-(a / sig) ** 2) + (tf - LIMB_SHAFT) * np.exp(-((L - a) / sig) ** 2)
            P[sel] += rad * ((f - 1) * w[sel])[:, None]
    me.vertices.foreach_set("co", P.ravel())
    me.update()


# ================================================================ 2. ชิ้นแยก
def new_obj(name, bm, rig, groups):
    """groups: callable(world point, vertex index) -> {bone: weight}"""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    vg = {}
    for v in me.vertices:
        for bn, w in groups(v.co, v.index).items():
            if w <= 1e-4:
                continue
            if bn not in vg:
                vg[bn] = ob.vertex_groups.new(name=bn)
            vg[bn].add([v.index], w, "REPLACE")
    ob.modifiers.new("Armature", "ARMATURE").object = rig
    return ob


def slab(bm, grid, closed, t):
    """ผ้าบาง: grid[j][i] (แถว j, คอลัมน์ i) หนา t, ปิดวงในแนว i ถ้า closed · คืน faces ที่สร้าง"""
    J, I = len(grid), len(grid[0])

    def nrm(j, i):
        a = grid[j][(i + 1) % I if closed else min(i + 1, I - 1)] - grid[j][(i - 1) % I if closed else max(i - 1, 0)]
        b = grid[min(j + 1, J - 1)][i] - grid[max(j - 1, 0)][i]
        return a.cross(b).normalized()
    top = [[bm.verts.new(grid[j][i] + nrm(j, i) * t / 2) for i in range(I)] for j in range(J)]
    bot = [[bm.verts.new(grid[j][i] - nrm(j, i) * t / 2) for i in range(I)] for j in range(J)]
    ni = I if closed else I - 1
    fs = []
    for j in range(J - 1):
        for i in range(ni):
            i2 = (i + 1) % I
            fs.append(bm.faces.new((top[j][i], top[j][i2], top[j + 1][i2], top[j + 1][i])))
            fs.append(bm.faces.new((bot[j][i], bot[j + 1][i], bot[j + 1][i2], bot[j][i2])))
    for j in (0, J - 1):
        for i in range(ni):
            i2 = (i + 1) % I
            fs.append(bm.faces.new((top[j][i], bot[j][i], bot[j][i2], top[j][i2])))
    if not closed:
        for i in (0, I - 1):
            for j in range(J - 1):
                fs.append(bm.faces.new((top[j][i], top[j + 1][i], bot[j + 1][i], bot[j][i])))
    return fs


def catmull(pts, n):
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    segs = len(pts) - 1
    for k in range(n):
        t = k / (n - 1) * segs
        i = min(int(t), segs - 1)
        u = t - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u ** 3))
    return out


def body_bvh(body):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(body.matrix_world)
    t = BVHTree.FromBMesh(bm)
    bm.free()
    return t


def front_y(bvh, x, z, default):
    hit = bvh.ray_cast(Vector((x, -3.0, z)), Vector((0, 1, 0)), 6.0)[0]
    return hit.y if hit is not None else default


# ---------------------------------------------------------------- ผมยุ่งสั้นแค่ต้นคอ (ไม่ลงไปถึงบ่า: หัวเอียงแล้วไม่ทะลุไหล่)
def build_hair(body, rig):
    H = HAIR
    h = H["Head"](body, rig)
    s = h.s
    b = H["Build"](h, ["HairBlack"])
    rnd = random.Random(13)
    sym, noise = H["sym"], H["noise"]
    # ผมบางมาก: ไม่มีแผ่นคลุมหัว มีแต่เส้นผมเรียวห่างๆ ร่วงเป็นหย่อม เห็นหนังหัวคล้ำ เส้นยาวห้อยถึงต้นคอ
    bald = lambda d: noise.noise(d * 2.6 + Vector((3.1, 0.7, 1.9)))
    n, tries = 0, 0
    while n < 95 and tries < 4000:
        tries += 1
        th = rnd.uniform(-math.pi, math.pi)
        ph = rnd.uniform(R(-25), R(85))
        if abs(th) < R(70) and ph < R(48):
            continue                                        # ไม่บังหน้า (ตาโปนกับลิ้นต้องเห็นชัด)
        d = h.dir(th, ph)
        if bald(d) > 0.18:
            continue                                        # หย่อมผมร่วง
        root = h.on(th, ph, 0.0005)
        L = (rnd.uniform(0.10, 0.20) if ph < R(40) else rnd.uniform(0.05, 0.14)) * s
        out = d.copy()
        wob = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3))) * 0.35
        pts, p_ = [root], root.copy()
        K = 6
        for k in range(1, K + 1):
            f = k / K
            dirv = (out * (1.0 - 0.8 * f) + Vector((0, 0.15, -1.0)) * (0.25 + 1.0 * f) + wob * (0.5 + f)).normalized()
            p_ = h.push(p_ + dirv * (L / K), 0.004)
            pts.append(p_.copy())
        r0 = rnd.uniform(0.0022, 0.0034) * s
        b.tube(pts, [r0 * (1 - 0.85 * (k / K)) if k < K else 0.0 for k in range(K + 1)], sides=4)
        n += 1
    ob = b.finish("Hair", rig)
    # ผมช่วงล่างตามคอ ช่วงบนตามหัว: ก้ม เงย เอียงหัวแล้วปลายผมไม่จิ้มเข้าคอ/บ่า
    zt = rig.data.bones["head"].head_local.z
    gh = ob.vertex_groups["head"]
    gn = ob.vertex_groups.new(name="neck")
    for v in ob.data.vertices:
        w = sm(zt - 0.12, zt + 0.03, v.co.z)
        gh.add([v.index], w, "REPLACE")
        if w < 1:
            gn.add([v.index], 1 - w, "REPLACE")
    return ob, h


# ---------------------------------------------------------------- หน้า: ตำแหน่งตา จมูก ปาก (กฎเดียวกับ build_skin.landmarks / กระหัง)
def face_marks(body, head):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.transform(body.matrix_world)
    bm.verts.ensure_lookup_table()
    seen, isl = set(), []
    for v in bm.verts:
        if v.index in seen:
            continue
        st, grp = [v], []
        seen.add(v.index)
        while st:
            x = st.pop()
            grp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen:
                    seen.add(y.index)
                    st.append(y)
        isl.append(grp)
    isl.sort(key=len)
    s = head.s
    small = [g for g in isl[:-1] if len(g) < 1500 and min(v.co.z for v in g) > head.C.z - 0.2 * s]
    nose = min(small, key=lambda g: sum(v.co.y for v in g) / len(g))
    top = max(v.co.z for v in nose)
    base = min(v.co.z for v in nose)
    tip = min(nose, key=lambda v: v.co.y).co.copy()
    skin = isl[-1]
    chin = min(v.co.z for v in skin if v.co.y < tip.y + 0.07 * s and abs(v.co.x) < 0.02 * s and v.co.z > head.C.z - 0.2 * s)
    bm.free()
    eye = top + 0.15 * (top - base)                       # สูงกว่ากระหังเพราะหัวถูกยืด (ตรงกับตาที่วาดไว้ใน UV ของคน)
    mouth = base - 0.40 * (base - chin)
    return dict(eye=eye, base=base, top=top, tip=tip, chin=chin, mouth=mouth)


EYES = []   # (center, radius)


def build_eyes(body, rig, hd, fm, bvh):
    """ลูกตาโปนกลมโต (ตามภาพอ้างอิง) ฝังครึ่งลูกในเบ้า ผูกกับ head"""
    s = hd.s
    bm = bmesh.new()
    r = 0.0145 * s
    for sx in (1, -1):
        x = 0.031 * s * sx
        y = front_y(bvh, x, fm["eye"], hd.C.y - 0.09 * s)
        c = Vector((x, y + 0.42 * r, fm["eye"] + 0.002 * s))
        EYES.append((c, r))
        sph = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
        for v in sph["verts"]:
            v.co += c
    return new_obj("Eyes", bm, rig, lambda p, i: {"head": 1.0})


# ---------------------------------------------------------------- ลิ้นยาวแดงคล้ำห้อยจากปากลงถึงท้อง
TONGUE = {}
TONGUE_MARKS = (0.0, 0.08, 0.24, 0.42, 0.6, 0.79, 1.0)


def build_tongue(body, rig, hd, fm, bvh):
    s = hd.s
    m = Vector((0, front_y(bvh, 0.0, fm["mouth"], hd.C.y - 0.1 * s), fm["mouth"]))
    z_end = torso_z(1.06)                                   # ปลายลิ้นถึงท้องตอบ
    ctrl = [m + Vector((0, 0.025, 0.004)), m + Vector((0, -0.02, -0.004)), m + Vector((0, -0.07, -0.05))]
    zs = np.linspace(m.z - 0.16, z_end, 7)
    for i, z in enumerate(zs):
        y = min(front_y(bvh, 0.0, z, m.y) - 0.095, m.y - 0.1)
        ctrl.append(Vector((0.012 * math.sin(i * 1.7), y, z)))
    path = catmull(ctrl, 48)
    acc = [0.0]
    for i in range(1, len(path)):
        acc.append(acc[-1] + (path[i] - path[i - 1]).length)
    TONGUE.update(path=path, acc=acc, mouth=m)
    bm = bmesh.new()
    rings = []
    n = len(path)
    N = Vector((1, 0, 0))
    sides = 12
    for i, p in enumerate(path):
        T = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        Nn = (N - T * N.dot(T)).normalized()
        B = T.cross(Nn)
        f = i / (n - 1)
        wid, th = 0.034 * (1 - 0.3 * f), 0.011 * (1 - 0.25 * f)
        if f < 0.06:
            k = 0.55 + 0.45 * f / 0.06
            wid, th = wid * k, th * k
        if f > 0.9:
            k = math.sqrt(max(0.05, 1 - ((f - 0.9) / 0.1) ** 2))
            wid, th = wid * k, th * max(0.5, k)
        ring = []
        for kk in range(sides):
            a = 2 * math.pi * kk / sides
            dip = 0.3 * th * math.exp(-(math.cos(a) / 0.35) ** 2) * (math.sin(a) < 0)   # ร่องกลางลิ้นด้านหน้า
            ring.append(bm.verts.new(p + Nn * (wid * math.cos(a)) + B * (th * math.sin(a) + dip)))
        rings.append(ring)
    for A_, B_ in zip(rings, rings[1:]):
        for k in range(sides):
            bm.faces.new((A_[k], A_[(k + 1) % sides], B_[(k + 1) % sides], B_[k]))
    tip = bm.verts.new(path[-1] + (path[-1] - path[-2]).normalized() * 0.006)
    for k in range(sides):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % sides], tip))
    bm.faces.new(rings[0][::-1])
    marks = []
    for fmk in TONGUE_MARKS:
        target = fmk * acc[-1]
        i = min(range(len(acc)), key=lambda q: abs(acc[q] - target))
        marks.append(path[i].copy())
    TONGUE["marks"] = marks
    accn = np.array(acc)
    PP = np.array([tuple(p) for p in path])
    mids = [(TONGUE_MARKS[k] + TONGUE_MARKS[k + 1]) / 2 * acc[-1] for k in range(6)]

    def groups(p, idx):
        i = int(np.argmin(np.linalg.norm(PP - np.array(p), axis=1)))
        sv = accn[i]
        w = {}
        for k in range(6):
            span = (TONGUE_MARKS[k + 1] - TONGUE_MARKS[k]) * acc[-1]
            w[f"Tongue{k + 1}"] = max(0.0, 1 - abs(sv - mids[k]) / span)
        if sv < mids[0]:
            w["Tongue1"] = 1.0
        if sv > mids[-1]:
            w["Tongue6"] = 1.0
        top = sorted(w.items(), key=lambda t: -t[1])[:2]
        tot = sum(v for _, v in top) or 1.0
        return {k: v / tot for k, v in top}
    return bm, groups


def add_tongue_bones(rig):
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    prev = eb["head"]
    mk = TONGUE["marks"]
    for k in range(6):
        b = eb.new(f"Tongue{k + 1}")
        b.head, b.tail = mk[k], mk[k + 1]
        b.parent = prev
        b.use_connect = k > 0
        b.align_roll(Vector((0, -1, 0)))
        prev = b
    bpy.ops.object.mode_set(mode="OBJECT")
    for k in range(6):
        rig.data.bones[f"Tongue{k + 1}"].use_deform = True


# ---------------------------------------------------------------- ผ้าขาวม้านุ่งจงกระเบน (แบบเดียวกับผ้าขาวม้าของกระหัง)
# ผ้าผืนเดียวพันแนบสะโพกตามรูปตัว (ยิง ray หาผิวรอบตัว) ข้างสั้นคลุมต้นขาบน หน้า-หลังร่นขึ้นถึงเป้า (ชายลอดหว่างขาไปเหน็บ)
# ปมที่สะโพกซ้าย ชายผ้า 2 ชายห้อย · น้ำหนักทุกจุดผสมจากผิวที่อยู่ใต้ผ้า (hips / spine / ต้นขา) = ผ้างอตามตัวพอดี ขายาวก้าวแล้วไม่ทะลุ
CLOTH = {}
SK_AZ, SK_N = 48, 12


def kb_bottom(a):
    """ขอบล่างที่มุม a (วัดจากหน้า -Y ไปทางซ้ายตัวละคร +X): ข้างสั้นแค่ 28% ของต้นขา หน้า-หลังร่นถึงเป้า"""
    side = CLOTH["side"] + 0.02 * math.sin(3 * a + 0.7) + 0.012 * math.sin(7 * a + 2.1)
    return side + (CLOTH["crotch"] - 0.02 - side) * math.cos(a) ** 6


def hull_radius(bvh, zs, az, yc, reach):
    """ผิวนอกสุดของตัวที่แต่ละมุม (ยิง ray จากนอกเข้าหาแกน) ช่องหว่างขาเชื่อมข้ามเหมือนผ้าพันขึง"""
    out = []
    for z, a in zip(zs, az):
        c = Vector((0, yc, z))
        d = Vector((math.sin(a), -math.cos(a), 0))
        hit = bvh.ray_cast(c + d * reach, -d, reach)[0]
        out.append((hit - c).length if hit is not None and (hit - c).dot(d) > 0.005 else None)
    n = len(out)
    if all(r is None for r in out):
        return [0.2] * n
    for i in range(n):
        if out[i] is None:
            j = 1
            while out[(i - j) % n] is None:
                j += 1
            k = 1
            while out[(i + k) % n] is None:
                k += 1
            out[i] = (out[(i - j) % n] * k + out[(i + k) % n] * j) / (j + k)
    for _ in range(8):                  # นูนออก: ผ้าขึงข้ามแอ่ง ไม่จมตามร่อง
        out = [max(out[i], 0.985 * (out[i - 1] + out[(i + 1) % n]) / 2) for i in range(n)]
    return out


def build_cloth(body, rig, bvh):
    rnd = random.Random(3)
    me = body.data
    P = np.array([tuple(v.co) for v in me.vertices])
    hz = rig.data.bones["hips"].head_local.z
    mid = P[(np.abs(P[:, 0]) < 0.012) & (P[:, 2] < hz)]
    th = rig.data.bones["thigh.L"]
    top = torso_z(1.0)
    yc = 0.01 * TORSO_K["u"]
    CLOTH.update(top=top, crotch=float(mid[:, 2].min()), side=th.head_local.z - 0.28 * (th.head_local - th.tail_local).length, yc=yc)
    az = [2 * math.pi * i / SK_AZ for i in range(SK_AZ)]
    jag = [rnd.uniform(-0.02, 0.008) for _ in az]                     # ชายผ้าลุ่ยไม่เสมอกัน
    tears = {rnd.randrange(SK_AZ) for _ in range(4)}                  # รอยขาดแหว่ง
    grid, prev = [], None
    for j in range(SK_N):
        f = j / (SK_N - 1)
        zs = [top + (kb_bottom(a) + (jag[i] + (0.045 if i in tears else 0.0)) * (j == SK_N - 1) - top) * f for i, a in enumerate(az)]
        rr = hull_radius(bvh, zs, az, yc, 0.36)
        rr = [max(r, prev[i]) if prev else r for i, r in enumerate(rr)]
        prev = rr
        row = []
        for i, a in enumerate(az):
            fold = 0.011 * f * math.sin(5 * a + 1.3) + 0.006 * f * math.sin(11 * a + 0.4) + 0.004 * math.sin(17 * a + 0.9) * f
            band = 0.009 if j <= 1 else 0.0                              # ขอบเอวม้วนพับ
            r = rr[i] + 0.016 + band + 0.025 * f * f + fold
            row.append(Vector((math.sin(a) * r, yc - math.cos(a) * r, zs[i])))
        grid.append(row)
    bm = bmesh.new()
    skirt = slab(bm, grid, True, 0.008)

    def on_skirt(a, z, out=0.0):
        f = min(max((top - z) / (top - kb_bottom(a)), 0.0), 1.0)
        i = int(round(a / (2 * math.pi) * SK_AZ)) % SK_AZ
        p = grid[min(int(round(f * (SK_N - 1))), SK_N - 1)][i]
        d = Vector((p.x, p.y - yc, 0)).normalized()
        return Vector((p.x, p.y, z)) + d * out, d
    # ปมผ้าที่สะโพกซ้ายค่อนหน้า
    kz = top - 0.06
    kp, kd = on_skirt(R(62), kz, 0.035)
    sph = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    for v in sph["verts"]:
        c = v.co.copy()
        n = 1 + 0.18 * math.sin(3 * c.x + 2 * c.z) + 0.1 * math.sin(5 * c.y)
        v.co = kp + Vector((c.x * 0.055, c.y * 0.042, c.z * 0.048)) * n
    # ชายผ้า 2 ชายจากปม: ชายหนึ่งห้อยหน้าต้นขา อีกชายสะบัดออกไปด้านข้างค่อนหลัง (ปลายลุ่ย)
    for (a0, a1, z1, w0, w1, wave) in ((R(58), R(42), CLOTH["side"] - 0.07, 0.11, 0.09, 0.03),
                                       (R(72), R(100), CLOTH["side"] + 0.03, 0.09, 0.07, 0.04)):
        rows = []
        K = 12
        for k in range(K + 1):
            t = k / K
            a = a0 + (a1 - a0) * t
            z = kz - 0.01 + (z1 - kz + 0.01) * t
            c, d = on_skirt(a, max(z, kb_bottom(a) + 0.01), 0.03 + 0.05 * t * t)
            c.z = z
            sv = Vector((0, 0, 1)).cross(d).normalized()
            c = c + d * wave * math.sin(t * 7 + a0 * 3) * t
            w = w0 + (w1 - w0) * t
            tw = 0.5 * t
            u = (sv * math.cos(tw) + d * math.sin(tw)) * w / 2
            fr = Vector((0, 0, -0.03)) if k == K else Vector()
            rows.append([c - u + fr, c, c + u])
        slab(bm, rows, False, 0.007)
    bm.faces.index_update()
    CLOTH["faces"] = {"waist": sorted(f.index for f in skirt)}
    # น้ำหนัก: ผสมจากผิวใต้ผ้า (4 จุดใกล้สุด ถ่วงตามระยะ) เฉพาะ hips / spine / ต้นขา
    from mathutils.kdtree import KDTree
    keep = ("hips", "spine", "thigh.L", "thigh.R")
    gname = {g.index: g.name for g in body.vertex_groups}
    vw = [{gname[g.group]: g.weight for g in v.groups if gname.get(g.group) in keep} for v in me.vertices]
    kd = KDTree(len(me.vertices))
    for v in me.vertices:
        kd.insert(v.co, v.index)
    kd.balance()

    def groups(p, idx):
        acc = {}
        for co, i_, dist in kd.find_n(p, 6):
            k_ = 1.0 / max(dist, 1e-4) ** 2
            for n_, w_ in vw[i_].items():
                acc[n_] = acc.get(n_, 0.0) + w_ * k_
        if not acc:
            return {"hips": 1.0}
        tot = sum(acc.values())
        return {n_: w_ / tot for n_, w_ in acc.items()}
    ob = new_obj("Cloth", bm, rig, groups)
    log(f"cloth: top {top:.2f} crotch {CLOTH['crotch']:.2f} side hem {CLOTH['side']:.2f}")
    return ob


# ================================================================ 3. atlas UV + paint (วิธีเดียวกับกระหัง)
BOX = {"Body": (0.0, 0.0, 0.75, 0.75), "Hair": (0.0, 0.75, 0.375, 1.0), "Cloth": (0.375, 0.75, 0.75, 1.0),
       "Tongue": (0.75, 0.25, 1.0, 1.0), "Eyes": (0.75, 0.0, 1.0, 0.25)}
PAD = 0.006
OBJ_ID = {"Body": 1, "Hair": 2, "Cloth": 3, "Tongue": 4, "Eyes": 5}


def atlas_uv(ob):
    u0, v0, u1, v1 = BOX[ob.name]
    u0 += PAD
    v0 += PAD
    u1 -= PAD
    v1 -= PAD
    me = ob.data
    if ob.name != "Body":
        for o in bpy.context.selected_objects:
            o.select_set(False)
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        while me.uv_layers:
            me.uv_layers.remove(me.uv_layers[0])
        me.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=R(60), island_margin=0.01, scale_to_bounds=True)
        bpy.ops.object.mode_set(mode="OBJECT")
    uv = me.uv_layers[0]
    uv.name = "UVMap"
    a = np.empty(len(uv.data) * 2, np.float32)
    uv.data.foreach_get("uv", a)
    a = a.reshape(-1, 2)
    a[:, 0] = u0 + np.clip(a[:, 0], 0, 1) * (u1 - u0)
    a[:, 1] = v0 + np.clip(a[:, 1], 0, 1) * (v1 - v0)
    uv.data.foreach_set("uv", a.ravel())


def set_engine(sc, names):
    for n in names:
        try:
            sc.render.engine = n
            return n
        except TypeError:
            pass


def bake_maps(objs, rig):
    sc = bpy.context.scene
    set_engine(sc, ["CYCLES"])
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    mat = bpy.data.materials.new("_Bake")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    outn = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    img = nt.nodes.new("ShaderNodeTexImage")
    nt.links.new(em.outputs[0], outn.inputs["Surface"])
    saved = {}
    for o in objs:
        saved[o.name] = [s.material for s in o.material_slots]
        o.data.materials.clear()
        o.data.materials.append(mat)
        o.pass_index = OBJ_ID[o.name]
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    res = {}
    for key, sock in (("pos", geo.outputs["Position"]), ("nrm", geo.outputs["Normal"]), ("id", oi.outputs["Object Index"])):
        im = bpy.data.images.new("_b_" + key, BAKE, BAKE, float_buffer=True)
        im.colorspace_settings.name = "Non-Color"
        img.image = im
        nt.nodes.active = img
        for l in list(nt.links):
            if l.to_node == em:
                nt.links.remove(l)
        nt.links.new(sock, em.inputs["Color"])
        bpy.ops.object.bake(type="EMIT", margin=16, margin_type="EXTEND", use_clear=True)
        a = np.empty(BAKE * BAKE * 4, np.float32)
        im.pixels.foreach_get(a)
        res[key] = a.reshape(BAKE * BAKE, 4)[:, :3].copy()
        bpy.data.images.remove(im)
    for o in objs:
        o.data.materials.clear()
        for m in saved[o.name]:
            o.data.materials.append(m)
    bpy.data.materials.remove(mat)
    res["id"] = np.rint(res["id"][:, 0]).astype(np.int32)
    return res


def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761 & 0x7FFFFFFF)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(P, f, seed=0):
    Q = P * np.asarray(f, np.float32)
    i = np.floor(Q).astype(np.int64)
    t = Q - i
    t = t * t * (3 - 2 * t)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[:, 0] if dx else 1 - t[:, 0]) * (t[:, 1] if dy else 1 - t[:, 1]) * (t[:, 2] if dz else 1 - t[:, 2])
                out = out + w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(P, f, oct=4, seed=0):
    a, tot, s = 0.0, 0.0, 1.0
    for o in range(oct):
        a = a + s * vnoise(P, np.asarray(f, np.float32) * (2 ** o), seed + o)
        tot += s
        s *= 0.5
    return a / tot


def lines(P, f, w, seed=0):
    """เส้นบางแตกกิ่ง (เส้นเลือด รอยแตก): 1 บนเส้น"""
    n = vnoise(P, f, seed) + 0.5 * vnoise(P, np.asarray(f) * 2.1, seed + 9)
    return 1 - sstep(0.0, w, np.abs(n - 0.75))


def ell(X, Z, cx, cz, rx, rz):
    return np.sqrt(((X - cx) / rx) ** 2 + ((Z - cz) / rz) ** 2)


def seg_dist2(X, Z, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    t = np.clip(((X - ax) * dx + (Z - az) * dz) / (dx * dx + dz * dz), 0, 1)
    return np.hypot(X - ax - t * dx, Z - az - t * dz), t


def mix(c, col, w):
    w = np.clip(w, 0, 1)[:, None]
    return c * (1 - w) + np.asarray(col, np.float32) / 255.0 * w


def paint_body(P, N, rig, fm, hd):
    """ผิวเปรต: คล้ำน้ำตาลเทาแบบศพตากแดด (โทนเดียวกับกระหัง) ด่างคล้ำ ผิวแห้งแตกระแหงลึก เส้นเลือดม่วงดำ
    ลำตัวใช้เกณฑ์ตำแหน่งของกระหัง (แปลงกลับเป็นพิกัดคนด้วย torso_q) แต่ร่องซี่โครงลึกและมืดกว่า"""
    n = len(P)
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    s = hd.s
    u = TORSO_K["u"]
    QX, QY, QZ = torso_q(P)
    big = fbm(P, (2, 2, 2), 3, 1)
    mid = fbm(P, (9, 9, 9), 3, 2)
    fine = vnoise(P, (60, 60, 60), 3)
    c = np.empty((n, 3), np.float32)
    c[:] = np.array([78, 64, 50], np.float32) / 255
    c = mix(c, (58, 50, 40), sstep(0.45, 0.75, big))
    c = mix(c, (98, 84, 66), sstep(0.55, 0.80, mid) * 0.45)
    c = mix(c, (56, 58, 40), sstep(0.62, 0.8, fbm(P, (5, 5, 5), 2, 7)) * 0.45)      # ด่างอมเขียวเน่า
    c = mix(c, (32, 26, 21), sstep(0.9, 0.2, Z) * 0.55 + sstep(0.6, 0.85, mid) * 0.25)  # มือเท้าคล้ำดินโคลน
    rough = 0.78 + 0.12 * mid
    H = (fine - 0.5) * 0.25 + (mid - 0.5) * 0.4
    C = hd.C
    dh = np.linalg.norm(P - np.asarray(C, np.float32), axis=1)
    onface = sstep(0.13 * s, 0.09 * s, dh) * (Y < C.y - 0.02 * s)
    cr = lines(P, (48, 48, 48), 0.025, 11) * (1 - 0.6 * onface)
    c = mix(c, (20, 16, 13), cr * 0.75)
    H -= cr * 0.7
    cr2 = lines(P, (140, 140, 140), 0.04, 12) * (1 - 0.6 * onface)
    c = mix(c, (38, 31, 25), cr2 * 0.4)
    H -= cr2 * 0.3
    limb = np.clip(sstep(0.17, 0.30, np.abs(QX)) + sstep(1.4, 0.9, Z / u), 0, 1)
    vein = lines(P, (6, 6, 2.5), 0.03, 21) * limb
    c = mix(c, (46, 36, 54), vein * 0.6)
    H += vein * 0.9
    # ซี่โครง: ลาดลงด้านข้าง ร่องลึกดำ · ซี่โครงด้านหลัง · กระดูกอก · ขอบชายโครง · ท้องตอบ สะดือ · สันเชิงกราน
    ribz = 1.10
    reg = sstep(ribz, ribz + 0.03, QZ) * sstep(1.41, 1.34, QZ) * sstep(0.2, 0.135, np.abs(QX)) * sstep(0.11, 0.02, QY)
    ph = (QZ + 0.55 * np.abs(QX) - ribz) / 0.031
    rib = (0.5 + 0.5 * np.cos(2 * np.pi * ph)) ** 3
    gap = (1 - rib) * reg * sstep(0.006, 0.03, np.abs(QX))
    c = mix(c, (16, 12, 10), gap * 0.95)
    c = mix(c, (120, 104, 82), rib * reg * 0.55)
    H += (rib * 2.0 - 1.0) * reg
    back = QY > 0.03
    regb = sstep(ribz, ribz + 0.04, QZ) * sstep(1.40, 1.30, QZ) * sstep(0.2, 0.04, np.abs(QX)) * back
    phb = (QZ - 0.25 * np.abs(QX) - ribz) / 0.031
    ribb = (0.5 + 0.5 * np.cos(2 * np.pi * phb)) ** 3
    c = mix(c, (24, 19, 16), (1 - ribb) * regb * 0.6)
    H += (ribb * 1.2 - 0.6) * regb
    stern = np.exp(-(QX / 0.010) ** 2) * sstep(1.18, 1.24, QZ) * sstep(1.42, 1.36, QZ) * (QY < 0)
    H += stern * 0.7
    c = mix(c, (112, 96, 76), stern * 0.4)
    belly = sstep(1.12, 1.07, QZ) * sstep(0.92, 0.98, QZ) * sstep(0.0, -0.05, QY)
    c = mix(c, (28, 22, 18), belly * 0.6 * sstep(0.16, 0.0, np.abs(QX)))
    H -= belly * 0.6
    arch = np.exp(-((QZ - (ribz + 0.02 + 0.55 * np.abs(QX))) / 0.012) ** 2) * sstep(0.16, 0.05, np.abs(QX)) * (QY < 0)
    c = mix(c, (24, 19, 15), arch * 0.6)
    H -= arch * 0.5
    navel = np.exp(-((QX / 0.007) ** 2 + ((QZ - 1.0) / 0.009) ** 2)) * (QY < 0)
    c = mix(c, (30, 24, 20), navel)
    H -= navel * 1.5
    hip = np.exp(-((QZ - (0.98 - 0.25 * np.abs(QX))) / 0.012) ** 2) * sstep(0.06, 0.12, np.abs(QX)) * sstep(0.17, 0.13, np.abs(QX)) * (QY < 0.02)
    H += hip * 0.5
    c = mix(c, (106, 92, 72), hip * 0.3)
    # ไหปลาร้า แอ่งเหนือไหปลาร้า เอ็นคอ กระดูกสันหลัง สะบัก
    for sx in (1, -1):
        d, t = seg_dist2(QX, QZ, (0.025 * sx, 1.425), (0.165 * sx, 1.448))
        cl = np.exp(-(d / 0.008) ** 2) * (QY < 0.02)
        H += cl * 1.3
        c = mix(c, (120, 104, 82), cl * 0.5)
        hol = np.exp(-(((QX - 0.09 * sx) / 0.04) ** 2 + ((QZ - 1.468) / 0.012) ** 2)) * (QY < 0.0)
        H -= hol * 1.2
        c = mix(c, (24, 19, 15), hol * 0.7)
        d, t = seg_dist2(X, Z, (0.045 * sx * s, fm["chin"] - 0.01 * s), (0.016 * sx * TORSO_K["kx"], torso_z(1.44)))
        cord = np.exp(-(d / (0.008 * u)) ** 2) * (Y < 0.03 * u)
        H += cord * 1.0
        c = mix(c, (106, 92, 72), cord * 0.35)
    vert = np.exp(-(QX / 0.009) ** 2) * (0.5 + 0.5 * np.cos(2 * np.pi * (QZ - 1.0) / 0.028)) * sstep(0.95, 1.0, QZ) * sstep(1.50, 1.44, QZ) * back
    H += vert * 1.0
    c = mix(c, (112, 96, 76), vert * 0.4)
    for sx in (1, -1):
        bl = ell(QX, QZ, 0.085 * sx, 1.33, 0.05, 0.075)
        edge = np.exp(-((bl - 1) / 0.12) ** 2) * back
        H += edge * 0.7 - (bl < 1) * back * 0.15
        c = mix(c, (24, 19, 16), edge * 0.35)
    # เข่า ศอก ข้อมือ ข้อเท้า: ปุ่มกระดูกซีด หนังย่นรอบๆ · ข้อนิ้วปูด เล็บยาวเหลืองสกปรก
    bs = rig.data.bones
    for side in ("L", "R"):
        for j, rad in (("forearm." + side, 0.07), ("shin." + side, 0.09), ("hand." + side, 0.05), ("foot." + side, 0.06)):
            q = np.asarray(bs[j].head_local, np.float32)
            d = np.linalg.norm(P - q, axis=1)
            k = sstep(rad, 0.0, d)
            c = mix(c, (112, 96, 76), k * 0.35)
            wr = lines(P, (40, 40, 40), 0.05, 31) * k
            c = mix(c, (32, 26, 21), wr * 0.6)
            H += wr * 0.8
        for f in ("index", "middle", "ring", "pinky", "thumb"):
            tip = np.asarray(bs[f"{f}_03.{side}"].tail_local, np.float32)
            d = np.linalg.norm(P - tip, axis=1)
            nail = sstep(0.034, 0.018, d)
            c = mix(c, (112, 96, 52), nail * 0.95)
            c = mix(c, (40, 32, 18), nail * sstep(0.02, 0.008, d))
            rough = rough * (1 - nail * 0.4)
            H += nail * 0.5
            for kk in ("01", "02", "03"):
                q = np.asarray(bs[f"{f}_{kk}.{side}"].head_local, np.float32)
                dk = np.linalg.norm(P - q, axis=1)
                kn = sstep(0.02, 0.0, dk)
                c = mix(c, (38, 31, 25), kn * 0.5)
                H += kn * 0.5
        toe = np.asarray(bs["toe." + side].tail_local, np.float32)
        dt = np.linalg.norm(P - toe, axis=1)
        c = mix(c, (70, 58, 34), sstep(0.06, 0.02, dt) * 0.7)
    sole = sstep(0.03, 0.006, Z)
    c = mix(c, (20, 16, 13), sole * 0.8)
    # ---- หน้า: เบ้าตาลึกดำรอบลูกตาโปน ขอบตาแดงช้ำ แก้มตอบ ปากอ้ากลมดำ (ลิ้นออกมา) ฟันห่าง
    head = dh < 0.16 * s
    E, MZ = fm["eye"], fm["mouth"]
    scalp = head & ((Z > E + 0.075 * s) | ((Y > C.y + 0.02 * s) & (Z > MZ)))
    c = mix(c, (48, 38, 30), scalp * 0.85)
    fr = head & (Y < C.y - 0.02 * s) & (np.abs(X) < 0.085 * s)
    ax = np.abs(X)
    w = fr.astype(np.float32)
    ex = 0.031 * s
    sock = sstep(1.35, 0.5, ell(ax, Z, ex, E, 0.025 * s, 0.02 * s)) * w
    c = mix(c, (22, 14, 14), sock * 0.95)
    H -= sock * 1.2
    rim = np.exp(-((ell(ax, Z, ex, E, 0.017 * s, 0.017 * s) - 1) / 0.12) ** 2) * w
    c = mix(c, (110, 30, 28), rim * 0.7)
    under = sstep(1.0, 0.0, ell(ax, Z, ex + 0.004 * s, E - 0.022 * s, 0.022 * s, 0.009 * s)) * w
    c = mix(c, (26, 18, 16), under * 0.6)
    H -= under * 0.5
    bd, bt = seg_dist2(ax, Z, (0.01 * s, E + 0.02 * s), (0.056 * s, E + 0.028 * s))
    brow = sstep(0.006 * s, 0.003 * s, bd) * w
    c = mix(c, (16, 13, 11), brow * 0.8)
    H += brow * 1.2
    for k in range(4):
        zz = E + (0.040 + 0.010 * k) * s + 0.004 * s * np.sin(X * 90 / s + k)
        g = np.exp(-((Z - zz) / (0.0013 * s)) ** 2) * sstep(0.05 * s, 0.02 * s, ax) * w
        c = mix(c, (38, 31, 25), g * 0.6)
        H -= g * 0.9
    nos = (ell(ax, Z, 0.0085 * s, fm["base"] + 0.002 * s, 0.0045 * s, 0.003 * s) < 1) & fr
    c = mix(c, (16, 10, 10), nos * 1.0)
    H -= nos * 1.0
    d, t = seg_dist2(ax, Z, (0.015 * s, fm["base"] + 0.003 * s), (0.034 * s, MZ - 0.006 * s))
    nl = np.exp(-(d / (0.0035 * s)) ** 2) * w * np.sin(np.pi * np.clip(t * 0.9 + 0.1, 0, 1))
    c = mix(c, (24, 18, 15), nl * 0.7)
    H -= nl * 1.4
    ch = sstep(1.0, 0.0, ell(ax, Z, 0.052 * s, MZ + 0.014 * s, 0.022 * s, 0.03 * s)) * w
    c = mix(c, (30, 24, 19), ch * 0.7)
    H -= ch * 0.8
    mx, mz = 0.024 * s, 0.017 * s
    mo = ell(X, Z, 0, MZ, mx, mz)
    mouth = (mo < 1) & fr
    lip = np.exp(-((mo - 1.0) / 0.16) ** 2) * w
    c = mix(c, (70, 34, 34), lip * 0.9)
    H += lip * 0.5
    c = mix(c, (10, 3, 3), mouth * 1.0)
    H = np.where(mouth, -1.5, H)
    rough = np.where(mouth, 0.3, rough)
    tw = 0.0062 * s
    colm = np.abs(np.mod(X + tw / 2, tw) - tw / 2)
    teeth = mouth & (Z > MZ + 0.009 * s) & (colm > 0.0012 * s) & (np.abs(X) < 0.018 * s)
    teeth |= mouth & (Z < MZ - 0.011 * s) & (colm > 0.0016 * s) & (np.abs(X) < 0.015 * s)
    c = mix(c, (150, 132, 84), teeth * 1.0)
    H = np.where(teeth, -0.4, H)
    tv = lines(P, (70, 70, 70), 0.05, 61) * sstep(0.05 * s, 0.07 * s, ax) * head * sstep(E - 0.02 * s, E + 0.02 * s, Z) * (Y < C.y + 0.03 * s)
    c = mix(c, (52, 38, 60), tv * 0.8)
    H += tv * 0.6
    c, rough, H = wounds(P, N, rig, fm, hd, c, rough, H)
    return c, np.clip(rough, 0.05, 1.0), H


# ---------------------------------------------------------------- บาดแผล (วาดในพิกัด 3 มิติ = ต่อเนื่องข้ามรอยตัด UV ไม่มีแผลขาดครึ่ง)
FLESH, FLESH_HI, CRUST, DRIP, BRUISE = (120, 16, 18), (176, 52, 46), (40, 10, 8), (66, 14, 12), (44, 28, 30)


def wound_paint(c, rough, H, core, crust, halo, drip, scab=None):
    c = mix(c, BRUISE, halo * 0.45)
    c = mix(c, DRIP, drip * 0.85)
    c = mix(c, CRUST, crust * 0.95)
    c = mix(c, FLESH, core)
    rough = np.where(core > 0.35, 0.16, np.where(crust > 0.5, 0.5, np.where(drip > 0.5, 0.38, rough)))
    H = H - core * 1.4 + crust * 0.45 + drip * 0.12
    if scab is not None:
        c = mix(c, (60, 26, 18), scab * 0.9)
        H = H + scab * 0.5
    return c, rough, H


def gash(P, N, a, b, facing, width, seed, drips=3, depth=0.14):
    """แผลแตกยาวจาก a ไป b บนผิวที่หันไปทาง facing: เนื้อแดงเปียกตรงกลาง สะเก็ดเลือดแห้งดำรอบขอบ ช้ำรอบนอก
    เลือดแห้งไหลเป็นทางลงล่าง · คืน (core, crust, halo, drip)"""
    a, b, o = np.array(a, np.float32), np.array(b, np.float32), np.array(facing, np.float32)
    o /= np.linalg.norm(o)
    near = (np.abs((P - (a + b) / 2) @ o) < depth) & (N @ o > 0.2)
    pp = P - np.outer(P @ o, o)
    pa, pb = a - (a @ o) * o, b - (b @ o) * o
    d = pb - pa
    L2 = max(float(d @ d), 1e-8)
    u = np.clip((pp - pa) @ d / L2, 0, 1)
    dist = np.linalg.norm(pp - (pa + np.outer(u, d)), axis=1)
    rnd = np.random.default_rng(seed)
    wob = 1 + 0.45 * (vnoise(P, (90, 90, 90), seed) - 0.5) * 2
    w = width * np.sin(np.pi * np.clip(u, 0.02, 0.98)) ** 0.6 * wob
    t = dist / np.maximum(w, 1e-5)
    core = sstep(0.6, 0.2, t) * near
    crust = sstep(1.15, 0.7, t) * near * (1 - core)
    halo = sstep(2.4, 1.1, t) * near * (1 - crust - core)
    drip = np.zeros(len(P), np.float32)
    down = np.array((0, 0, -1), np.float32)
    side = np.cross(o, down)
    if np.linalg.norm(side) > 0.3:
        side /= np.linalg.norm(side)
        for k in range(drips):
            q = a + (b - a) * rnd.uniform(0.2, 0.8)
            ln = rnd.uniform(0.04, 0.13)
            dx = (P - q) @ side
            dz = (P - q) @ down
            wid = 0.0035 * (1 + 0.6 * (1 - np.clip(dz / ln, 0, 1)))
            drip = np.maximum(drip, np.exp(-(dx / wid) ** 2) * sstep(-0.004, 0.004, dz) * sstep(ln, ln * 0.7, dz) * near)
    return core, crust, halo, drip


def claws(P, N, a, d, facing, length, seed, n=3, gap=0.022, width=0.0035):
    """รอยข่วนเล็บขนานกัน n เส้น (ตื้น แดงสด ขอบสะเก็ด)"""
    a, d, o = np.array(a, np.float32), np.array(d, np.float32), np.array(facing, np.float32)
    d /= np.linalg.norm(d)
    o /= np.linalg.norm(o)
    sd = np.cross(o, d)
    sd /= np.linalg.norm(sd)
    out = [np.zeros(len(P), np.float32) for _ in range(4)]
    for k in range(n):
        st = a + sd * gap * (k - (n - 1) / 2) + d * 0.01 * math.sin(k * 2.1)
        r = gash(P, N, st, st + d * length * (1 - 0.15 * abs(k - 1)), o, width, seed + k, drips=1 if k == 1 else 0, depth=0.1)
        out = [np.maximum(x, y) for x, y in zip(out, r)]
    return out


def wounds(P, N, rig, fm, hd, c, rough, H):
    """แผลเปิด แผลแตกตรงหนังตึงหุ้มกระดูก (หน้าแข้ง เข่า ศอก ซี่โครง ไหปลาร้า) รอยข่วน สะเก็ด เลือดแห้งไหลเป็นทาง แผลที่หน้า"""
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    s = hd.s
    bs = rig.data.bones
    QX, QY, QZ = torso_q(P)

    def bone_pt(name, a, off=(0, 0, 0)):
        b = bs[name]
        return np.array(b.head_local.lerp(b.tail_local, a)) + np.array(off)
    # แผลเปื่อยกระจายทั่วตัว (แบบ wither() แต่ใหญ่และลึกกว่า) + สะเก็ดแห้ง
    so = fbm(P, (4.5, 4.5, 4.5), 3, 167)
    sore_core = sstep(0.80, 0.84, so)
    sore_rim = sstep(0.75, 0.79, so) * (1 - sore_core)
    scab = sstep(0.74, 0.78, fbm(P, (11, 11, 11), 2, 168)) * sstep(0.5, 0.7, vnoise(P, (60, 60, 60), 169))
    c, rough, H = wound_paint(c, rough, H, sore_core, sore_rim, sstep(0.70, 0.75, so) * (1 - sore_rim - sore_core) * 0.6,
                              np.zeros(len(P), np.float32), scab * (1 - sore_core))
    # หนังแตกเป็นร่องแดงรอบปุ่มกระดูก
    bone_m = np.zeros(len(P), np.float32)
    for side in ("L", "R"):
        for j, rad in (("shin." + side, 0.11), ("forearm." + side, 0.08)):
            bone_m = np.maximum(bone_m, sstep(rad, 0.0, np.linalg.norm(P - np.array(bs[j].head_local), axis=1)))
        sh = bs["shin." + side]
        h, t = np.array(sh.head_local), np.array(sh.tail_local)
        a = np.clip((P - h) @ (t - h) / np.dot(t - h, t - h), 0, 1)
        dd = np.linalg.norm(P - (h + np.outer(a, t - h)), axis=1)
        bone_m = np.maximum(bone_m, sstep(0.07, 0.0, dd) * (N[:, 1] < -0.3) * sstep(0.95, 0.8, a))  # สันหน้าแข้ง
    bone_m = np.maximum(bone_m, sstep(1.12, 1.16, QZ) * sstep(1.40, 1.34, QZ) * sstep(0.2, 0.1, np.abs(QX)) * (QY < 0))
    split = lines(P, (26, 26, 26), 0.03, 171) * bone_m
    c = mix(c, (96, 18, 16), split * 0.9)
    c = mix(c, CRUST, sstep(0.3, 0.6, split) * 0.6)
    H -= split * 0.9
    rough = np.where(split > 0.5, 0.25, rough)
    # แผลแตกลึกตรงหนังตึงหุ้มกระดูก
    G = []
    fwd, back = (0, -1, 0), (0, 1, 0)
    for side, sg, sd in (("L", 1, 0), ("R", -1, 10)):
        G.append(gash(P, N, bone_pt("shin." + side, 0.28 + 0.1 * sg), bone_pt("shin." + side, 0.55 + 0.08 * sg), fwd, 0.012, 201 + sd, 4))
        G.append(gash(P, N, bone_pt("shin." + side, 0.0, (0.03 * sg, 0, 0.02)), bone_pt("shin." + side, 0.0, (-0.03 * sg, 0, -0.03)), fwd, 0.011, 202 + sd, 2))   # เข่าแตก
        G.append(gash(P, N, bone_pt("forearm." + side, 0.0, (0, 0, 0.03)), bone_pt("forearm." + side, 0.12), back, 0.01, 203 + sd, 2))           # ศอก
    G.append(gash(P, N, (0.06 * TORSO_K["kx"], 0, torso_z(1.30)), (0.15 * TORSO_K["kx"], 0, torso_z(1.24)), fwd, 0.011, 211, 3))   # ซี่โครงซ้าย
    G.append(gash(P, N, (-0.05 * TORSO_K["kx"], 0, torso_z(1.20)), (-0.13 * TORSO_K["kx"], 0, torso_z(1.15)), fwd, 0.009, 212, 2))               # ซี่โครงขวา
    G.append(gash(P, N, (-0.04 * TORSO_K["kx"], 0, torso_z(1.433)), (-0.15 * TORSO_K["kx"], 0, torso_z(1.448)), fwd, 0.008, 213, 3))            # ไหปลาร้าขวา
    G.append(gash(P, N, (0.07 * TORSO_K["kx"], 0, torso_z(1.30)), (0.02 * TORSO_K["kx"], 0, torso_z(1.10)), back, 0.012, 214, 3))               # หลัง
    # หน้า: แผลแตกที่แก้มซ้าย หน้าผาก มุมปากขวาฉีก
    E, MZ = fm["eye"], fm["mouth"]
    G.append(gash(P, N, (0.038 * s, 0, E - 0.03 * s), (0.055 * s, 0, MZ + 0.0), fwd, 0.0045 * s, 221, 2, depth=0.12 * s))
    G.append(gash(P, N, (-0.03 * s, 0, E + 0.07 * s), (0.01 * s, 0, E + 0.085 * s), fwd, 0.0035 * s, 222, 1, depth=0.12 * s))
    G.append(gash(P, N, (-0.022 * s, 0, MZ), (-0.04 * s, 0, MZ - 0.012 * s), fwd, 0.003 * s, 223, 2, depth=0.12 * s))
    # รอยข่วนเล็บ: ต้นขาขวาใต้ชายผ้า, แขนท่อนล่างซ้าย, อก
    G.append(claws(P, N, bone_pt("thigh.R", 0.55, (0.0, -0.06, 0)), (0.25, 0, -1), fwd, 0.18, 231))
    G.append(claws(P, N, bone_pt("forearm.L", 0.45), np.array(bs["forearm.L"].tail_local - bs["forearm.L"].head_local), fwd, 0.16, 235, gap=0.016))
    G.append(claws(P, N, (0.02 * TORSO_K["kx"], 0, torso_z(1.40)), (0.6, 0, -1), fwd, 0.2, 239, gap=0.02))
    core, crust, halo, drip = [np.max(np.stack([g[i] for g in G]), 0) for i in range(4)]
    c, rough, H = wound_paint(c, rough, H, core, crust, halo, drip)
    hi = core * sstep(0.6, 0.85, vnoise(P, (220, 220, 220), 240))                     # ประกายเนื้อเปียก
    c = mix(c, FLESH_HI, hi * 0.6)
    return c, rough, H


def paint_hair(P):
    n = len(P)
    f1 = vnoise(P, (100, 100, 40), 71)
    f2 = fbm(P, (16, 16, 16), 3, 72)
    c = np.empty((n, 3), np.float32)
    c[:] = np.array([30, 28, 26], np.float32) / 255
    c = mix(c, (62, 58, 52), sstep(0.6, 0.95, f1) * 0.6)          # ผมแห้งกระด้าง ปลายซีด
    c = mix(c, (10, 9, 9), sstep(0.5, 0.2, f2) * 0.7)
    return c, 0.8 + 0.12 * f2, (f1 - 0.5) * 0.8


def paint_cloth(P):
    """ผ้าขาวม้าเก่า: ลายตารางแดงอิฐซีดจนเกือบน้ำตาล ด่างแดดเผา คราบดิน คราบเลือดเก่าดำคล้ำ ชายผ้าเปื้อนโคลน ขอบลุ่ยดำ ลายทอหยาบ"""
    n = len(P)
    X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    yc = CLOTH["yc"]
    az = np.arctan2(X, -(Y - yc))
    u = az * 0.22                                               # ระยะตามรอบตัว (ม.)
    c = np.empty((n, 3), np.float32)
    c[:] = np.array([84, 40, 30], np.float32) / 255            # แดงอิฐซีดหม่นเกือบน้ำตาล
    for coord, off in ((u, 0.0), (Z, 0.017)):
        ph = np.mod(coord + off, 0.085) / 0.085
        c = mix(c, (54, 24, 19), ((ph > 0.06) & (ph < 0.32)).astype(np.float32) * 0.6)    # แถบตารางกว้างแดงคล้ำ
        c = mix(c, (38, 18, 16), ((ph > 0.60) & (ph < 0.65)).astype(np.float32) * 0.7)    # เส้นเข้ม
        c = mix(c, (118, 98, 72), ((ph > 0.74) & (ph < 0.77)).astype(np.float32) * 0.4) # เส้นด้ายขาวหม่น
    fade = fbm(P, (2.5, 2.5, 2.5), 3, 82)
    c = mix(c, (92, 74, 56), sstep(0.5, 0.75, fade) * 0.5)                              # ซีดแดดเผาเป็นด่าง
    dirt = fbm(P, (7, 7, 7), 4, 83)
    c = mix(c, (44, 32, 24), sstep(0.42, 0.72, dirt) * 0.8)
    blood = sstep(0.7, 0.8, fbm(P, (9, 9, 9), 3, 84)) * sstep(0.4, 0.6, vnoise(P, (30, 30, 30), 85))
    c = mix(c, (46, 12, 10), blood * 0.85)                                                 # คราบเลือดแห้ง
    bot = np.array([kb_bottom(a) for a in az], np.float32)
    f = (CLOTH["top"] - Z) / np.maximum(CLOTH["top"] - bot, 0.05)
    c = mix(c, (44, 32, 24), sstep(0.7, 0.97, f) * (0.5 + 0.4 * dirt))                     # ชายผ้าเปื้อนโคลน
    c = mix(c, (26, 18, 14), sstep(0.95, 1.02, f) * 0.85)                                  # ขอบลุ่ยดำ
    c = mix(c, (40, 28, 22), sstep(0.06, 0.0, f) * 0.5)                                    # ขอบเอวคราบเหงื่อไคล
    weave = 0.5 + 0.25 * np.sin(u * 1300) + 0.25 * np.sin(Z * 1300)
    c *= (0.88 + 0.24 * weave)[:, None]
    fray = lines(P, (120, 120, 120), 0.05, 86) * sstep(0.85, 1.0, f)
    c = mix(c, (24, 16, 12), fray * 0.7)
    return c, 0.86 + 0.1 * dirt - blood * 0.2, (weave - 0.5) * 0.5 + (dirt - 0.5) * 0.4 - fray * 0.4


def paint_tongue(P):
    n = len(P)
    n1 = fbm(P, (14, 14, 14), 3, 91)
    n2 = vnoise(P, (160, 160, 160), 92)
    vein = lines(P, (20, 20, 20), 0.03, 93)
    c = np.empty((n, 3), np.float32)
    c[:] = np.array([96, 18, 22], np.float32) / 255
    c = mix(c, (150, 44, 46), sstep(0.35, 0.7, n1))
    c = mix(c, (44, 8, 12), vein * 0.7)
    c = mix(c, (160, 80, 70), sstep(0.6, 0.75, n2) * 0.35)
    return c, 0.22 + 0.2 * n2, n2 * 0.6 - vein * 0.4


def paint_eyes(P):
    n = len(P)
    c = np.zeros((n, 3), np.float32)
    rough = np.full(n, 0.12, np.float32)
    H = np.zeros(n, np.float32)
    for cen, r in EYES:
        sel = np.linalg.norm(P - np.array(cen), axis=1) < r * 1.5
        if not sel.any():
            continue
        q = P[sel] - np.array(cen)
        q /= np.maximum(np.linalg.norm(q, axis=1, keepdims=True), 1e-6)
        f = -q[:, 1]                                          # 1 = กลางหน้าตา
        cc = np.empty((sel.sum(), 3), np.float32)
        cc[:] = np.array([206, 192, 150], np.float32) / 255  # ตาขาวอมเหลือง
        vein = lines(P[sel], (900, 900, 900), 0.08, 41)
        cc = mix(cc, (150, 30, 24), vein * 0.8 * sstep(0.85, 0.2, f) + sstep(0.4, -0.2, f) * 0.7)
        cc = mix(cc, (120, 116, 96), sstep(0.955, 0.965, f))  # ม่านตาขุ่น
        cc = mix(cc, (8, 5, 5), sstep(0.988, 0.992, f))      # รูม่านตาเล็กเท่ารูเข็ม
        c[sel] = cc
    return c, rough, H


def paint(maps, rig, body, hd, fm):
    pos, nrm, ids = maps["pos"], maps["nrm"], maps["id"]
    S = BAKE * BAKE
    col = np.zeros((S, 3), np.float32)
    col[:] = 0.2
    rough = np.full(S, 0.7, np.float32)
    hgt = np.zeros(S, np.float32)
    for oid, fn in ((1, lambda P, N: paint_body(P, N, rig, fm, hd)), (2, lambda P, N: paint_hair(P)),
                    (3, lambda P, N: paint_cloth(P)), (4, lambda P, N: paint_tongue(P)), (5, lambda P, N: paint_eyes(P))):
        sel = np.nonzero(ids == oid)[0]
        if not len(sel):
            log("no texels for", oid)
            continue
        c, r, h = fn(pos[sel].astype(np.float32), nrm[sel].astype(np.float32))
        col[sel] = c
        rough[sel] = r
        hgt[sel] = h
    return col, rough, hgt


def down(a, k=BAKE // TEX):
    sh = a.shape
    a = a.reshape(TEX, k, TEX, k, -1).mean(axis=(1, 3))
    return a.reshape(TEX * TEX, *sh[1:])


def save_png(arr, path, chans=3, colorspace="sRGB"):
    n = int(math.sqrt(len(arr)))
    px = np.ones((len(arr), 4), np.float32)
    px[:, :chans] = arr.reshape(len(arr), -1)[:, :chans] if arr.ndim > 1 else arr[:, None]
    if chans == 1:
        px[:, 1] = px[:, 0]
        px[:, 2] = px[:, 0]
    im = bpy.data.images.new("_save", n, n)
    im.colorspace_settings.name = colorspace
    im.pixels.foreach_set(np.clip(px, 0, 1).ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)


def bake_normal(objs, hgt):
    """normal map (tangent, OpenGL +Y) จาก height ที่วาด ผ่าน Bump node ใน Cycles"""
    sc = bpy.context.scene
    sc.cycles.samples = 4
    him = bpy.data.images.new("_height", BAKE, BAKE, float_buffer=True)
    him.colorspace_settings.name = "Non-Color"
    px = np.ones((BAKE * BAKE, 4), np.float32)
    px[:, 0] = px[:, 1] = px[:, 2] = hgt
    him.pixels.foreach_set(px.ravel())
    out = bpy.data.images.new("_nrm", BAKE, BAKE, float_buffer=True)
    out.colorspace_settings.name = "Non-Color"
    mat = bpy.data.materials.new("_BakeN")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    ht = nt.nodes.new("ShaderNodeTexImage")
    ht.image = him
    ht.interpolation = "Cubic"
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = 0.004
    nt.links.new(ht.outputs["Color"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    nt.links.new(b.outputs[0], o.inputs["Surface"])
    tgt = nt.nodes.new("ShaderNodeTexImage")
    tgt.image = out
    nt.nodes.active = tgt
    saved = {}
    for ob in objs:
        saved[ob.name] = [s.material for s in ob.material_slots]
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=16, margin_type="EXTEND", use_clear=True)
    a = np.empty(BAKE * BAKE * 4, np.float32)
    out.pixels.foreach_get(a)
    a = a.reshape(-1, 4)[:, :3]
    for ob in objs:
        ob.data.materials.clear()
        for m in saved[ob.name]:
            ob.data.materials.append(m)
    for im in (him, out):
        bpy.data.images.remove(im)
    bpy.data.materials.remove(mat)
    v = down(a * 2 - 1)
    v /= np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-6)
    return v * 0.5 + 0.5


def make_material(objs):
    mat = bpy.data.materials.get(NAME) or bpy.data.materials.new(NAME)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], o.inputs["Surface"])

    def tex(suffix, cs):
        n = nt.nodes.new("ShaderNodeTexImage")
        p = os.path.join(M, f"{NAME}_{suffix}.png")
        im = bpy.data.images.get(os.path.basename(p))
        if im:
            bpy.data.images.remove(im)
        n.image = bpy.data.images.load(p)
        n.image.colorspace_settings.name = cs
        return n
    nt.links.new(tex("Color", "sRGB").outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex("Roughness", "Non-Color").outputs["Color"], b.inputs["Roughness"])
    nt.links.new(tex("Metalness", "Non-Color").outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.uv_map = "UVMap"
    nt.links.new(tex("Normal", "Non-Color").outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs[0], b.inputs["Normal"])
    for ob in objs:
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    for m in list(bpy.data.materials):
        if m.users == 0 or (m.use_fake_user and m.name != NAME):
            m.use_fake_user = False
    return mat


# ================================================================ 4. ท่า (Poser ของตัวมนุษย์ + ลิ้นห้อยตามแรงโน้มถ่วง)
def rotw(ax, d):
    return Matrix.Rotation(R(d), 3, ax)


class PretPoser:
    """ใช้ Poser ของ build_anims (องศา, clamp ตาม joint limits) แล้วแก้ลิ้นทุกเฟรม: ลิ้นห้อยดิ่งตามแรงโน้มถ่วง
    ไม่ว่าหัวจะก้มเงยแค่ไหน (ไม่ฟาดเข้าอก) แกว่งเพิ่มตาม sway (องศา รอบแกนโลก X = หน้า-หลัง, Y = ซ้าย-ขวา)"""

    def __init__(self, rig):
        self.P = AN["Poser"](rig)
        self.rig = rig
        self.sway = [(0.0, 0.0)] * 6
        bs = rig.data.bones
        self.B = {n: bs[n].matrix_local.to_3x3() for n in ["head"] + [f"Tongue{k}" for k in range(1, 7)]}

    def key(self, f):
        P, rig = self.P, self.rig
        for p in P.pb:
            p.rotation_euler = (0, 0, 0)
            p.location = (0, 0, 0)
        for k, (kind, v) in P.frame.items():
            if kind == "rot":
                P.pb[k].rotation_euler = v
            else:
                P.pb[k.split("@")[0]].location = v
        bpy.context.view_layer.update()
        Mh = rig.pose.bones["head"].matrix.to_3x3()
        S_prev = None
        for k in range(1, 7):
            n = f"Tongue{k}"
            fb, sd = self.sway[k - 1]
            S = (S_prev or Matrix.Identity(3)) @ rotw("X", fb) @ rotw("Y", sd)
            Bk = self.B[n]
            if k == 1:
                loc = (self.B["head"].inverted() @ Bk).inverted() @ Mh.inverted() @ S @ Bk
            else:
                loc = Bk.inverted() @ S_prev.inverted() @ S @ Bk
            P.pb[n].rotation_euler = loc.to_euler("XYZ")
            S_prev = S
        for p in P.pb:
            p.keyframe_insert("rotation_euler", frame=f, group=p.name)
            if p.name in ("root", "hips"):
                p.keyframe_insert("location", frame=f, group=p.name)
        P.frame = {}
        self.sway = [(0.0, 0.0)] * 6


FINGERS = AN["FINGERS"]
LEG_LEN = {}


def knees(P, a, spread=3.0):
    """งอเข่าโดยเท้ายังแนบพื้น: ต้นขา +a หน้าแข้ง -2a เท้า +a · คืนระยะที่สะโพกต้องลดลง"""
    P.both("thigh", a, 0, spread)
    P.both("shin", -2 * a)
    P.both("foot", a)
    return LEG_LEN["leg"] * (1 - math.cos(R(a)))


def arms_hang(P, swing_l=0.0, swing_r=0.0, bend_l=10.0, bend_r=10.0, out=0.0):
    """แขนยาวห้อยกางออกจากตัวเล็กน้อย (มือห่างผ้าและต้นขา) ศอกงอนิด"""
    lo = math.degrees(P.lim.get("upper_arm.L", (R(-35),) * 6)[0]) + 3
    P.rot("upper_arm.L", lo + out, 0, -swing_l)
    P.rot("upper_arm.R", lo + out, 0, -swing_r)
    P.rot("forearm.L", 0, 0, -bend_l)
    P.rot("forearm.R", 0, 0, -bend_r)
    P.both("hand", -8, 0, 0)


def claw(P, k=1.0, ph=0.0):
    """นิ้วยาวงองุ้มเป็นกรงเล็บ ขยับเป็นคลื่นช้าๆ"""
    for i, f in enumerate(FINGERS):
        w = math.sin(ph + i * 0.5)
        P.both(f, (-18 - 6 * w) * k if f.endswith("_01") else (-26 - 8 * w) * k)
    P.both("thumb_01", -8 * k)
    P.both("thumb_02", -14 * k)
    P.both("thumb_03", -18 * k)


def hunch(P, k=1.0):
    """หลังค่อม คอยื่น เงยหน้ามองไปข้างหน้า"""
    P.rot("spine", 7 * k)
    P.rot("chest", 7 * k)
    P.rot("neck", 16 * k)
    P.rot("head", -22 * k)
    P.both("shoulder", 2 * k)


def c_idle(pp, t):
    P = pp.P
    a = 2 * math.pi * t
    br = math.sin(2 * a)
    hunch(P)
    tw = sm(0.55, 0.575, t) * (1 - sm(0.6, 0.72, t))              # หัวกระตุกหันขวับครั้งหนึ่งต่อรอบ
    P.rot("spine", 7 + 0.8 * br, 0, 1.5 * math.sin(a))
    P.rot("chest", 7 + 1.2 * br, 2 * math.sin(a + 0.4))
    P.rot("neck", 16, 4 * math.sin(a + 1.0) + 12 * tw, 2 * math.sin(a))
    P.rot("head", -22 - 5 * tw, 6 * math.sin(a + 1.0) + 16 * tw, 2.5 * math.sin(a + 0.7) - 6 * tw)
    arms_hang(P, 3 * math.sin(a), 3 * math.sin(a + 0.8), 10 + 2 * br, 10 + 2 * br)
    claw(P, 1.0, a * 2)
    drop = knees(P, 4 + 1.0 * br)
    P.lift("hips", -drop)
    P.rot("hips", 0, 0, 1.2 * math.sin(a))
    pp.sway = [(1.5 * math.sin(2 * a - i * 0.4), 2.0 * math.sin(a - i * 0.5) + 5 * tw * math.sin(12 * a - i)) for i in range(6)]


WALK_FRAMES = 96


def c_walk(pp, t):
    """เดินช้าก้าวยาว (ขายาวมาก): ต้นขาแกว่ง ±17° เข่างอตอนยกขา ตัวโยกขึ้นลง แขนยาวแกว่งช้ากว่าขา"""
    P = pp.P
    ph = 2 * math.pi * t
    for side, off in (("L", 0.0), ("R", math.pi)):
        p = ph + off
        th = 17 * math.sin(p) + 3
        knee = -(6 + 38 * max(0.0, math.cos(p)) ** 1.5) - 8 * max(0.0, math.sin(p)) * max(0.0, -math.cos(p))
        foot = 9 * math.sin(p + 0.5) - 3 * max(0.0, -math.sin(p))
        P.rot("thigh." + side, th, 0, 3)
        P.rot("shin." + side, knee)
        P.rot("foot." + side, foot)
        P.rot("toe." + side, -10 * max(0.0, -math.sin(p + 0.4)) + 12 * max(0.0, -math.cos(p)) * (math.sin(p) < 0))
    bob = 0.045 * math.sin(ph) ** 2
    P.lift("hips", -bob - 0.03)
    P.rot("hips", 0, 6 * math.sin(ph), 2.5 * math.sin(ph))
    hunch(P, 1.3)
    P.rot("spine", 9, -4 * math.sin(ph), -1.5 * math.sin(ph))
    P.rot("chest", 9, -5 * math.sin(ph))
    P.rot("neck", 20, 2 * math.sin(ph), 0)
    P.rot("head", -28 + 3 * math.sin(2 * ph + 0.6), 3 * math.sin(ph), 0)
    sw = 13 * math.sin(ph - 0.5)                                   # แขนยาวห้อยถ่วง แกว่งตามหลังขา
    arms_hang(P, -sw, sw, 14 + 8 * max(0, -math.sin(ph)), 14 + 8 * max(0, math.sin(ph)), out=1)
    claw(P, 1.1, ph)
    pp.sway = [(3 * math.sin(2 * ph - 0.8 - i * 0.5), 3.5 * math.sin(ph - i * 0.55)) for i in range(6)]


SHRIEK_FRAMES = 90


def c_shriek(pp, t):
    """ย่อตัวเตรียม -> แหงนหน้ากรีดร้อง อกแอ่น กางแขนยาวขึ้น นิ้วกางแอ่นสั่นเทิ้ม ลิ้นสะบัด -> คืนท่ายืน"""
    P = pp.P
    f = t * SHRIEK_FRAMES
    a = sm(0, 10, f) * (1 - sm(10, 16, f))
    s = sm(12, 21, f) * (1 - sm(62, 84, f))

    def tr(seed, amp):
        return amp * s * (math.sin(f * 2.9 + seed) * 0.6 + math.sin(f * 5.3 + seed * 2.1) * 0.4)
    hunch(P)
    P.rot("spine", 7 + 6 * a - 6 * s)
    P.rot("chest", 7 + 6 * a - 14 * s + tr(1, 2.0), 0, tr(2, 1.5))
    P.rot("neck", 16 + 6 * a - 30 * s)
    P.rot("head", -22 + 8 * a - 22 * s + tr(3, 3.5), tr(4, 4))
    P.both("shoulder", 6 - 4 * s)
    lo = math.degrees(P.lim["upper_arm.L"][0]) + 3
    for side, k in (("L", 1), ("R", -1)):
        P.rot("upper_arm." + side, lo * (1 - s) + 50 * s + tr(6 + k, 3), 0, -18 * s - 6 * a)
        P.rot("forearm." + side, 0, 0, -(10 + 20 * a + 25 * s + tr(8 + k, 4)))
        P.rot("hand." + side, -8 + 30 * s)
    for i, fn in enumerate(FINGERS):
        P.both(fn, (-20 - 16 * a) * (1 - s) + (8 if fn.endswith("_01") else 0) * s + tr(10 + i, 6))
    P.both("thumb_01", -8 + 20 * s, 0, 20 * s)
    P.both("thumb_02", -14 * (1 - s))
    drop = knees(P, 4 + 12 * a + 3 * s)
    P.lift("hips", -drop)
    # หมุนบวกรอบแกน X ของโลก = ลิ้นเหวี่ยงไปข้างหลัง (เข้าอก) จึงสะบัดไปข้างหน้าอย่างเดียว
    # หัวแหงนแล้วปากไปอยู่เหนืออก: โคนลิ้นยื่นออกไปข้างหน้าก่อน (-38°) แล้วค่อยงอห้อยลง ไม่ทะลุอก
    pp.sway = [((-38 if i == 0 else 4 + 3 * math.sin(f * 0.7 - i * 0.6)) * s, s * 7 * math.sin(f * 0.9 - i * 0.8) + 2 * math.sin(2 * math.pi * t - i * 0.5)) for i in range(6)]


CLIPS = {"Idle": (c_idle, 120, False), "TallSlowWalk": (c_walk, WALK_FRAMES, False), "Shriek": (c_shriek, SHRIEK_FRAMES, True)}


def add_anims(rig):
    pp = PretPoser(rig)
    th = rig.data.bones["thigh.L"]
    sh = rig.data.bones["shin.L"]
    LEG_LEN["leg"] = (th.tail_local - th.head_local).length + (sh.tail_local - sh.head_local).length
    if not rig.animation_data:
        rig.animation_data_create()
    made = {}
    for name, (fn, n, once) in CLIPS.items():
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        rig.animation_data.action = act
        for f in range(n + 1):
            fn(pp, f / n if once else (f % n) / n)
            pp.key(f + 1)
        act.frame_range = (1, n + 1)
        try:
            act.use_cyclic = not once
        except AttributeError:
            pass
        made[name] = n + 1
    rig.animation_data.action = bpy.data.actions["Idle"]
    sc = bpy.context.scene
    sc.render.fps = 30
    sc.frame_start, sc.frame_end = 1, made["Idle"]
    return made


# ================================================================ 5. ตรวจการทะลุทุกเฟรมทุกท่า
ARM = ("upper_arm", "forearm", "hand", "thumb", "index", "middle", "ring", "pinky")
LEG = ("thigh", "shin", "foot", "toe")


def part_of(bone):
    base, _, side = bone.partition(".")
    if base.startswith(ARM):
        return "arm" + side
    if base in LEG:
        return "leg" + side
    if base == "head":
        return "head"
    return "torso"


def check_setup(rig, body):
    names = [g.name for g in body.vertex_groups]
    W = body_weights(body, names)
    dom = [part_of(names[i]) for i in W.argmax(1)]
    me = body.data
    vpart = np.array(dom)
    fpart = []
    for p in me.polygons:
        parts = [dom[i] for i in p.vertices]
        # หน้าที่แตะหัวนับเป็นหัว (ขอบท้ายทอย/คอ) · เสมอกันเลือกตามลำดับคงที่ (ไม่ขึ้นกับลำดับของ set)
        fpart.append("head" if "head" in parts else max(sorted(set(parts)), key=parts.count))
    # ไม่นับโคนแขนช่วงรักแร้ และโคนขาช่วงขาหนีบ (ผิวต่อกันจริง ไม่ใช่การทะลุ)
    P = np.array([tuple(v.co) for v in me.vertices])
    keep = np.ones(len(P), bool)
    for s in ("L", "R"):
        for bone, part, lim in (("upper_arm." + s, "arm" + s, 0.45), ("thigh." + s, "leg" + s, 0.25)):
            b = rig.data.bones[bone]
            h, t = np.array(b.head_local), np.array(b.tail_local)
            a = ((P - h) @ (t - h)) / np.dot(t - h, t - h)
            keep &= ~((vpart == part) & (a < lim))
    return dict(vpart=vpart, fpart=np.array(fpart), keep=keep)


def eval_mesh(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg)
    me = e.to_mesh()
    V = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    Mw = np.array(e.matrix_world)
    V = V @ Mw[:3, :3].T + Mw[:3, 3]
    F = [tuple(p.vertices) for p in me.polygons]
    e.to_mesh_clear()
    return V, F


def inside(bvh, pts, tol=0.004, reach=0.15):
    """จุดที่จมอยู่ใต้ผิว (ด้านในของ mesh ปิด) ลึกเกิน tol · คืน (จำนวนจุด, ลึกสุด)"""
    n, deep = 0, 0.0
    if bvh is None:
        return 0, 0.0
    for p in pts:
        loc, nrm, idx, dist = bvh.find_nearest(Vector(p), reach)
        if loc is None:
            continue
        d = (Vector(p) - loc).dot(nrm)
        if d < -tol:
            n += 1
            deep = max(deep, -d)
            HITS.append((tuple(np.round(p, 2)), round(-d, 3)))
    return n, deep


HITS = []


def sub_bvh(V, F, sel):
    fs = [F[i] for i in np.nonzero(sel)[0]]
    return BVHTree.FromPolygons([tuple(v) for v in V], fs, all_triangles=False) if fs else None


def cloth_poke(rig, V, vp, CV, CF, cf):
    """ผิวขา/สะโพกที่อยู่ใต้ผ้าแต่โผล่ออกนอกผ้า: ยิง ray จากแกนกระดูก (ที่ขยับตามท่า) ผ่านจุดนั้นออกไป
    ถ้าจุดอยู่ไกลกว่าผ้าชั้นแรกที่ ray ชน = ทะลุ"""
    n, deep = 0, 0.0
    pb = rig.pose.bones
    mw = rig.matrix_world
    for key, bone, parts in (("waist", "hips", ("torso", "legL", "legR")),):
        fl = [CF[i] for i in cf[key]]
        bvh = BVHTree.FromPolygons([tuple(v) for v in CV], fl, all_triangles=False)
        b = pb[bone]
        h, t = np.array(mw @ b.head), np.array(mw @ b.tail)
        cz = CV[np.unique(np.array([i for f in fl for i in f]))]
        z0, z1 = cz[:, 2].min() + 0.02, cz[:, 2].max() - 0.02
        sel = np.isin(vp, parts) & (V[:, 2] > z0) & (V[:, 2] < z1)
        for p in V[sel]:
            if key == "waist":
                c = np.array((h[0], h[1], p[2]))
            else:
                d = t - h
                c = h + np.clip((p - h) @ d / (d @ d), 0, 1) * d
            dv = p - c
            r = np.linalg.norm(dv)
            if r < 1e-4:
                continue
            hit = bvh.ray_cast(Vector(c), Vector(dv / r), r + 0.3)[0]
            if hit is None:
                continue
            rh = (hit - Vector(c)).length
            if r > rh + 0.002:
                n += 1
                deep = max(deep, r - rh)
                POKE.append((key, tuple(np.round(p, 2)), round(r - rh, 3)))
    return n, deep


POKE = []


def check_clips(rig, body, tongue, hair, cloth, CS, made):
    """ทุกเฟรมทุกท่า: แขน/นิ้วทะลุลำตัวหรือขา, ขาทะลุขาอีกข้าง, ลิ้นทะลุตัว/แขน, ผมทะลุบ่า/ลำตัว, ผิวขาโผล่ทะลุผ้า"""
    sc = bpy.context.scene
    report = {}
    acc = np.array(TONGUE["acc"])
    TV = np.array([tuple(v.co) for v in tongue.data.vertices])
    path = np.array([tuple(p) for p in TONGUE["path"]])
    tongue_keep = np.array([acc[int(np.argmin(np.linalg.norm(path - p, axis=1)))] > 0.09 for p in TV])
    fp, vp, keep = CS["fpart"], CS["vpart"], CS["keep"]
    for name in CLIPS:
        rig.animation_data.action = bpy.data.actions[name]
        worst = {}
        for f in range(1, made[name] + 1):
            sc.frame_set(f)
            V, F = eval_mesh(body)
            res = {}
            for s, o in (("L", "R"), ("R", "L")):
                res["arm" + s] = inside(sub_bvh(V, F, (fp != "arm" + s) & (fp != "head")), V[(vp == "arm" + s) & keep])
                res["leg" + s] = inside(sub_bvh(V, F, fp == "leg" + o), V[(vp == "leg" + s) & keep])
            allb = BVHTree.FromPolygons([tuple(v) for v in V], F, all_triangles=False)
            TVp, _ = eval_mesh(tongue)
            res["tongue"] = inside(allb, TVp[tongue_keep], tol=0.002)
            HV, _ = eval_mesh(hair)
            res["hair"] = inside(sub_bvh(V, F, fp != "head"), HV, tol=0.003)
            CV, CF = eval_mesh(cloth)
            res["cloth"] = cloth_poke(rig, V, vp, CV, CF, CLOTH["faces"])
            for k, (n, d) in res.items():
                if n and (k not in worst or n > worst[k][0]):
                    worst[k] = (n, round(d * 1000, 1), f)
        report[name] = worst
        if HITS:
            log(f"    inside hits {name}: " + "; ".join(str(x) for x in HITS[:: max(1, len(HITS) // 8)][:8]))
        HITS.clear()
        if POKE:
            log(f"    cloth pokes {name}: " + "; ".join(str(x) for x in POKE[:: max(1, len(POKE) // 12)][:12]))
        POKE.clear()
        log(f"  clip check {name} ({made[name]} frames): " + (", ".join(f"{k}: {n} verts, deepest {d} mm @f{f}" for k, (n, d, f) in worst.items()) or "no clipping"))
    return report


# ================================================================ 6. export + ภาพตัวอย่าง
def fbx(path, **kw):
    bpy.ops.export_scene.fbx(filepath=path, global_scale=STUDS_PER_M, apply_scale_options="FBX_SCALE_NONE",
                             axis_forward="-Z", axis_up="Y", bake_space_transform=False, add_leaf_bones=False,
                             primary_bone_axis="Y", secondary_bone_axis="X", use_armature_deform_only=True, **kw)


def export_all(rig, objs):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs + [rig]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action
    rig.animation_data.action = None
    for p in rig.pose.bones:
        p.rotation_euler = (0, 0, 0)
        p.location = (0, 0, 0)
    rig.data.pose_position = "REST"
    fbx(os.path.join(M, NAME + ".fbx"), use_selection=True, object_types={"ARMATURE", "MESH"}, mesh_smooth_type="FACE",
        path_mode="STRIP", embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    rig.data.pose_position = "POSE"
    for name in CLIPS:
        for o in bpy.context.selected_objects:
            o.select_set(False)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        a = bpy.data.actions[name]
        rig.animation_data.action = a
        f0, f1 = (int(x) for x in a.frame_range)
        sc = bpy.context.scene
        sc.frame_start, sc.frame_end = f0, f1
        fbx(os.path.join(M, f"{NAME}_{name}.fbx"), use_selection=True, object_types={"ARMATURE"}, bake_anim=True,
            bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
            bake_anim_force_startend_keying=True, bake_anim_step=1.0, bake_anim_simplify_factor=0.0)
    rig.animation_data.action = act


def stats(objs):
    tot = 0
    for o in objs:
        me = o.data
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        tot += tris
        mx = max((sum(1 for g in v.groups if g.weight > 0) for v in me.vertices), default=0)
        log(f"{o.name}: {tris} tris, {len(me.vertices)} verts, max bones/vertex {mx}")
    log(f"total {tot} tris")


def preview_scene():
    sc = bpy.context.scene
    set_engine(sc, ["BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"])
    try:
        sc.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.045, 0.055, 0.075, 1)
    bg.inputs[1].default_value = 1.0
    for o in list(bpy.data.objects):
        if o.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(o, do_unlink=True)

    def light(name, loc, energy, color, size):
        l = bpy.data.lights.new(name, "AREA")
        l.energy = energy
        l.color = color
        l.size = size
        o = bpy.data.objects.new(name, l)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, 2.2)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    light("_key", (-4.5, -6.0, 5.5), 3200, (0.85, 0.9, 1.0), 4.0)
    light("_fill", (6.0, -4.0, 2.4), 900, (1.0, 0.85, 0.7), 5.0)
    light("_rim", (1.0, 7.0, 5.0), 2400, (0.6, 0.8, 1.0), 4.0)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    try:
        sc.view_settings.view_transform = "AgX"
    except TypeError:
        pass
    return cam


def eval_pts(objs):
    return np.concatenate([eval_mesh(o)[0][::5] for o in objs])


def render_view(cam, objs, az, el, path, res=(800, 1200), pts=None, margin=1.06):
    sc = bpy.context.scene
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    pts = eval_pts(objs) if pts is None else pts
    a, e = R(az), R(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    rot = (-d).to_track_quat("-Z", "Y")
    M3 = rot.to_matrix()
    right, up = np.array(M3.col[0]), np.array(M3.col[1])
    xs, ys = pts @ right, pts @ up
    cx, cy = (xs.min() + xs.max()) / 2, (ys.min() + ys.max()) / 2
    w_, h_ = xs.max() - xs.min(), ys.max() - ys.min()
    span = (max(w_, h_ * res[0] / res[1]) if res[0] >= res[1] else max(h_, w_ * res[1] / res[0])) * margin   # ortho_scale = ด้านที่ยาวกว่าของภาพ
    depth = float(pts.mean(0) @ np.array(d))
    cam.location = Vector(right * cx + up * cy) + d * (depth + 10.0)
    cam.rotation_euler = rot.to_euler()
    cam.data.ortho_scale = span
    cam.data.clip_end = 40
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def tile(cam, objs, az, el, res, pts):
    tmp = os.path.join(PREV, "_t.png")
    render_view(cam, objs, az, el, tmp, res=res, pts=pts, margin=1.04)
    im = bpy.data.images.load(tmp)
    arr = np.empty(res[0] * res[1] * 4, np.float32)
    im.pixels.foreach_get(arr)
    bpy.data.images.remove(im)
    os.remove(tmp)
    return arr.reshape(res[1], res[0], 4)


def sheet(tiles, path):
    s = np.concatenate([np.concatenate(r, 1) for r in tiles][::-1], 0)
    img = bpy.data.images.new("_sheet", s.shape[1], s.shape[0])
    img.pixels.foreach_set(s.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def previews(rig, objs, shape_only=False):
    cam = preview_scene()
    os.makedirs(PREV, exist_ok=True)
    sc = bpy.context.scene
    body = objs[0]
    if not shape_only:
        rig.animation_data.action = bpy.data.actions["Idle"]
        sc.frame_set(1)
    pts = eval_pts(objs)
    render_view(cam, objs, 35, 8, os.path.join(PREV, NAME + ".png"), pts=pts)
    render_view(cam, objs, 0, 3, os.path.join(PREV, NAME + "_front.png"), pts=pts)
    render_view(cam, objs, 90, 2, os.path.join(PREV, NAME + "_side.png"), pts=pts)
    hp = eval_pts(objs)
    hp = hp[hp[:, 2] > rig.pose.bones["neck"].tail.z - 0.1]
    render_view(cam, objs, 22, 4, os.path.join(PREV, NAME + "_face.png"), res=(800, 800), pts=hp, margin=1.15)
    if shape_only:
        return
    # เทียบขนาดกับตัวมนุษย์ (human_base 1.80 ม. = 6.3 studs)
    with bpy.data.libraries.load(os.path.join(HB, "human_base.blend")) as (src, dst):
        dst.objects = ["Body"]
    man = dst.objects[0]
    man.name = "_Man"
    sc.collection.objects.link(man)
    man.parent = None
    man.modifiers.clear()
    man.matrix_world = Matrix.Translation((1.1, 0.0, 0.0))
    bpy.context.view_layer.update()
    render_view(cam, objs + [man], 0, 2, os.path.join(PREV, NAME + "_scale.png"), res=(900, 1100))
    bpy.data.objects.remove(man, do_unlink=True)
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    render_view(cam, objs, 0, 0, os.path.join(PREV, NAME + "_rest.png"))
    rig.data.pose_position = "POSE"
    # contact sheet: แถว = ท่า (บนลงล่าง Idle, TallSlowWalk, Shriek), 6 จังหวะต่อท่า, หน้าตรง / ด้านข้าง
    for view, az in (("front", 0), ("side", 90)):
        tiles = []
        for name in CLIPS:
            a = bpy.data.actions[name]
            rig.animation_data.action = a
            f0, f1 = (int(x) for x in a.frame_range)
            row = []
            for k in range(6):
                sc.frame_set(int(round(f0 + (f1 - f0) * k / 5 if CLIPS[name][2] else f0 + (f1 - f0) * k / 6)))
                row.append(tile(cam, objs, az, 2, (300, 460), pts))
            tiles.append(row)
        sheet(tiles, os.path.join(PREV, f"{NAME}_clips_{view}.png"))
    rig.animation_data.action = bpy.data.actions["Idle"]
    sc.frame_set(1)


# ================================================================ main
def main():
    rig, body = open_base()
    stretch(rig, body)
    subdivide(body)
    gaunt(body, rig)
    bvh = body_bvh(body)
    hair, hd = build_hair(body, rig)
    hair.name = "Hair"
    fm = face_marks(body, hd)
    log("face", {k: (round(v, 3) if isinstance(v, float) else tuple(round(x, 3) for x in v)) for k, v in fm.items()}, "s", round(hd.s, 3))
    eyes = build_eyes(body, rig, hd, fm, bvh)
    tbm, tgroups = build_tongue(body, rig, hd, fm, bvh)
    add_tongue_bones(rig)
    tongue = new_obj("Tongue", tbm, rig, tgroups)
    cloth = build_cloth(body, rig, bvh)
    objs = [body, hair, cloth, tongue, eyes]
    for o in objs:
        o.hide_render = False
        o.hide_set(False)
    log("weights trimmed", AN["limit_weights"]())
    if STAGE == "shape":
        previews(rig, objs, shape_only=True)
        return
    for o in objs:
        atlas_uv(o)
    maps = bake_maps(objs, rig)
    col, rough, hgt = paint(maps, rig, body, hd, fm)
    save_png(down(col), os.path.join(M, NAME + "_Color.png"))
    save_png(down(rough[:, None]), os.path.join(M, NAME + "_Roughness.png"), 1, "Non-Color")
    save_png(np.zeros((TEX * TEX, 1), np.float32), os.path.join(M, NAME + "_Metalness.png"), 1, "Non-Color")
    save_png(bake_normal(objs, hgt), os.path.join(M, NAME + "_Normal.png"), 3, "Non-Color")
    make_material(objs)
    rig.data.pose_position = "POSE"
    made = add_anims(rig)
    log("clips", made)
    stats(objs)
    check_clips(rig, body, tongue, hair, cloth, check_setup(rig, body), made)
    if STAGE == "check":
        return
    export_all(rig, objs)
    previews(rig, objs)
    for o in list(bpy.data.objects):
        if o.name.startswith("_"):
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(M, "pret.blend"), relative_remap=True)
    log("done")


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.environ.get("TEMP", HERE), "pret.txt")
try:
    main()
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
open(OUT + ".done", "w").write("x")
