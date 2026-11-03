# กระหัง (Krahang) — ผีชายผอมดำ ใช้กระด้งสองใบเป็นปีก สากตำข้าวเป็นขาที่สาม — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\krahang.py -Out C:\tmp\krahang.txt
# ลองท่า/รูปทรงเร็วๆ: ตั้ง env KRAHANG_QUICK=<โฟลเดอร์> (ข้าม bake/export ใช้ texture เดิม เขียนภาพตัวอย่างลงโฟลเดอร์นั้น)
#   KRAHANG_CHECK=<ทุกกี่เฟรม> = สร้างท่าแล้วตรวจชนอย่างเดียว (clip_check: ทุกชิ้นต้องไม่จมเข้ากันเกิน 6 มม. ทุกเฟรม)
# ต้นแบบ: ตัวชายผอม assets/models/human_base/human_base_thin.blend (rig 52 กระดูก + weight + joint limits เดิม)
#   Body        ผิวเดิม ปรับให้ซี่โครงบานและท้องตอบ ผิวคล้ำแห้งเหี่ยว ซี่โครง เส้นเอ็น หน้าแยกเขี้ยว บาดแผล (วาดลง texture)
#   Hair        ผมดำยาวยุ่ง ปลิวไปด้านหลัง (สร้างด้วย Build/Head ของ human_base/build_hair.py) ผูกกับ head
#   Cloth       ผ้าขาวม้าแดงนุ่งสั้น ผูกปมที่สะเอวซ้าย มีชายผ้า 2 ชาย ชายผ้าหน้า-หลังร่นขึ้นพ้นสาก
#               weight ตามผิวใต้ผ้า (hips/spine/thigh) + ชายหน้า-หลังผูก sak, relax_cloth() ดันจุดที่จมผิวในท่าต่างๆ ออก
#   Kradong.L/R กระด้งไม้ไผ่สาน มัดติดหลังท่อนแขนล่างด้วยหวาย 2 เส้น (มือว่าง) ผูกกับกระดูกเสริม kradong.L/R (ลูกของ forearm.L/R)
#   Sak         สากตำข้าวอันใหญ่ยาว 1.8 ม. นั่งคร่อมตรงกลาง (เอวสากอยู่ใต้เป้า) ผูกกับกระดูกเสริม sak (ลูกของ hips)
#               ในท่าบิน สากอยู่ระนาบ (หมุน sak สวนกับการโน้มตัว ไม่เกิน 36°) ตอนหมอบสากเอียงตามตัว
# rig = HumanRig เดิม + kradong.L, kradong.R, sak (R-HX) · weight ไม่เกิน 4 กระดูกต่อจุด
# ท่า (30 fps): FlapFly, Glide (วนลูป), LandOnRoof (ครั้งเดียว จบท่าหมอบ), PeekOverEdge (วนลูป)
# texture ชุดเดียว 1024 ใช้ร่วมทุกชิ้น (atlas): bake ตำแหน่ง/normal ของผิวทุก texel แล้ววาดด้วย numpy ในพิกัด 3 มิติ
# ผลลัพธ์: assets/models/Krahang.fbx + Krahang_Color/_Normal/_Roughness/_Metalness.png
#          assets/models/roblox/krahang/Krahang_<ท่า>.fbx, assets/models/krahang.blend
#          previews/Krahang.png (3/4), Krahang_front.png, Krahang_side.png, Krahang_rest.png, Krahang_face.png,
#          Krahang_anims.png (3/4), Krahang_anims_front.png, Krahang_anims_side.png
import bpy, bmesh, math, os, sys, random, traceback
import numpy as np
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
M = os.path.join(REPO, "assets", "models")
HB = os.path.join(M, "human_base")
PREV = os.path.join(M, "previews")
CLIP_DIR = os.path.join(M, "roblox", "krahang")
NAME = "Krahang"
BAKE = 2048               # bake / paint size; saved textures are averaged down to TEX
TEX = 1024
STUDS_PER_M = 3.5         # same as the human pipeline (man 1.80 m = 6.3 studs)
R = math.radians
LOG = []
QUICK = os.environ.get("KRAHANG_QUICK", "")   # folder: quick pose check only (see main)

def log(*a):
    s = " ".join(str(x) for x in a); LOG.append(s); print(s)

def load_ns(fn):
    ns = {"__name__": "lib_" + os.path.basename(fn)}
    exec(compile(open(os.path.join(HB, fn), encoding="utf-8").read(), fn, "exec"), ns)
    return ns

HAIR = load_ns("build_hair.py")
AN = load_ns("build_anims.py")

def sstep(a, b, x):
    t = np.clip((x - a)/(b - a), 0.0, 1.0); return t*t*(3 - 2*t)

# ---------------------------------------------------------------- base body
def open_base():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HB, "human_base_thin.blend"))
    for o in list(bpy.data.objects):
        if o.name not in ("Body", "HumanRig"):
            bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions): bpy.data.actions.remove(a)
    for c in list(bpy.data.collections):
        if not c.objects: bpy.data.collections.remove(c)
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    rig.animation_data_clear() if rig.animation_data else None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.context.view_layer.update()
    return rig, body

def bone_w(ob, v, names):
    gi = {ob.vertex_groups[n].index for n in names if n in ob.vertex_groups}
    return sum(g.weight for g in v.groups if g.group in gi)

def gaunt(body):
    """flared ribcage over a sunken belly: what makes the starved torso read from a distance"""
    mw = body.matrix_world; inv = mw.inverted()
    for v in body.data.vertices:
        p = mw @ v.co
        torso = bone_w(body, v, ("chest", "spine", "hips"))
        if torso < 0.5: continue
        rib = math.exp(-((p.z - 1.26)/0.07)**2)*torso
        if p.y < 0.05:
            p.x *= 1 + 0.035*rib; p.y = p.y*(1 + 0.04*rib)
        belly = math.exp(-((p.z - 1.06)/0.06)**2)*torso*min(max(-p.y/0.05, 0.0), 1.0)
        p.y += 0.020*belly; p.x *= 1 - 0.05*belly
        v.co = inv @ p
    body.data.update()

# ---------------------------------------------------------------- hair: wild, long, streaming back
def build_hair(body, rig):
    H = HAIR; h = H["Head"](body, rig); s = h.s
    b = H["Build"](h, ["HairBlack"]); rnd = random.Random(7)
    front = lambda th: math.exp(-(math.degrees(math.atan2(math.sin(th), math.cos(th)))/48.0)**2)
    # the shell is only a thin dark base on the scalp (a thick one read as a cap); the volume is all in the locks
    base = H["sym"]([(0, -0.04), (60, -0.03), (100, -0.05), (180, -0.16)])   # ear level: clear of raised arms
    thin = lambda th, ph: max(0.004, 0.008 + 0.006*H["noise"].noise(h.dir(th, ph)*7.0))
    b.shell(H["GHOST_AZ"], True, H["POLE"], H["GHOST_LINE"], thin,
            hem=lambda th: base(th) + (0.6 - base(th))*front(th),
            flare=lambda th: H["sym"]([(0, 0.01), (90, 0.03), (180, 0.03)])(th)*(1 - front(th)),
            tip=0.008, rows=8, drop_rows=4, clear=0.008, jitter=0.10, jitter_f=13.0)
    back = -h.F
    # messy top: flat clumps rooted all over the crown that lie back along the scalp, lift off it and split apart,
    # a few flyaways stand up; the hairline gets short tufts brushed up and back
    n = 0
    while n < 70:
        th = rnd.uniform(-math.pi, math.pi); ph = rnd.uniform(R(28), R(88))
        if abs(th) < R(50) and ph < R(40): continue
        root = h.on(th, ph, 0.004); d = h.dir(th, ph)
        w = back - d*back.dot(d) + h.L*rnd.uniform(-0.5, 0.5)
        if w.length < 1e-3: w = -h.F
        w.normalize()
        fly = rnd.random() < 0.18
        L = rnd.uniform(0.10, 0.20)*s if not fly else rnd.uniform(0.06, 0.11)*s
        lift = rnd.uniform(0.004, 0.022)*s if not fly else rnd.uniform(0.03, 0.06)*s
        side = w.cross(d).normalized(); ph0 = rnd.uniform(0, 6.3); amp = rnd.uniform(0.004, 0.012)*s
        pts = []; k = 6
        for i in range(k + 1):
            t = i/k; p = root + w*L*t + side*amp*math.sin(ph0 + t*5.0)*t
            q = h.C + (p - h.C).normalized()*(h.scalp((p - h.C).normalized()) + 0.004*s)   # follow the round of the skull
            p = q + (q - h.C).normalized()*lift*t**1.6 + Vector((0, 0, -0.04*L*t*t))
            pts.append(h.push(p, 0.004) if i else p)
        r0 = rnd.uniform(0.010, 0.017)*s*(0.6 if fly else 1.0)
        b.tube(pts, [r0*(1 - 0.8*(i/k)**1.2) if i < k else 0.0 for i in range(k + 1)], sides=4, flat=0.35)
        n += 1
    n = 0
    while n < 52:                                      # long locks blown back (down-back at rest = straight back in flight)
        th = rnd.uniform(-math.pi, math.pi); ph = rnd.uniform(R(-25), R(70))
        if abs(th) < R(60) and ph < R(55): continue      # keep the face clear
        d = h.dir(th, ph); dh = Vector((d.x, d.y, 0)); root = h.on(th, ph, 0.012)
        w = back*1.0 + dh*rnd.uniform(0.05, 0.35) + Vector((0, 0, rnd.uniform(-0.55, -0.15)))   # narrow: clear of raised arms
        w.normalize(); side = w.cross(Vector((0, 0, 1))).normalized()
        L = rnd.uniform(0.22, 0.46)*s; pts = []; k = 7
        ph0 = rnd.uniform(0, 6.3); amp = rnd.uniform(0.015, 0.04)
        for i in range(k + 1):
            t = i/k
            p = root + w*L*t + side*amp*math.sin(ph0 + t*6.0)*t + Vector((0, 0, amp*math.cos(ph0 + t*4.0)*t - 0.30*L*t*t))
            pts.append(h.push(p, 0.012) if i else p)
        r0 = rnd.uniform(0.018, 0.030)*s
        b.tube(pts, [r0*(1 - 0.75*(i/k)**1.3) if i < k else 0.0 for i in range(k + 1)], sides=5, flat=0.45)
        n += 1
    for dth in range(-46, 47, 8):                       # hairline tufts swept up and back off the forehead
        th = R(dth + rnd.uniform(-3, 3)); ph = H["GHOST_LINE"](th) + R(rnd.uniform(2, 8))
        pts = [h.on(th, ph, 0.003)]
        for i in range(1, 5):
            t = i/4; p = h.on(th + R(rnd.uniform(-5, 5))*t, ph + R(30)*t, 0.006 + 0.014*t*t)
            pts.append(p)
        b.tube(pts, [0.010*s, 0.009*s, 0.007*s, 0.004*s, 0.0], sides=4, flat=0.4)
    ob = b.finish("Hair", rig)
    return ob, h

# ---------------------------------------------------------------- generic mesh helpers
def new_obj(name, bm, rig, groups):
    """groups: callable(world point) -> {bone: weight}"""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.parent = rig; ob.matrix_parent_inverse = rig.matrix_world.inverted()
    vg = {}
    for v in me.vertices:
        for bn, w in groups(v.co).items():
            if w <= 1e-4: continue
            if bn not in vg: vg[bn] = ob.vertex_groups.new(name=bn)
            vg[bn].add([v.index], w, 'REPLACE')
    ob.modifiers.new("Armature", 'ARMATURE').object = rig
    return ob

def smooth_weights(ob, it):
    """average each vertex's weights with its edge neighbours `it` times (no hard steps where the cloth crosses from the
    hips onto a thigh), then keep the 4 strongest"""
    me = ob.data; n = len(me.vertices); names = [g.name for g in ob.vertex_groups]
    W = np.zeros((n, len(names)), np.float32)
    for v in me.vertices:
        for g in v.groups: W[v.index, g.group] = g.weight
    nb = [[] for _ in range(n)]
    for e in me.edges: a, b = e.vertices; nb[a].append(b); nb[b].append(a)
    for _ in range(it):
        W = np.array([(W[i]*2 + W[nb[i]].sum(0))/(2 + len(nb[i])) if nb[i] else W[i] for i in range(n)], np.float32)
    for i in range(n):
        row = W[i].copy(); row[np.argsort(row)[:-4]] = 0; row /= max(row.sum(), 1e-6)
        for gi, gname_ in enumerate(names):
            if row[gi] > 1e-4: ob.vertex_groups[gname_].add([i], float(row[gi]), 'REPLACE')
            else: ob.vertex_groups[gname_].remove([i])

def lathe(bm, frame, prof, n):
    """surface of revolution about local +Z of `frame` (4x4); prof = [(r, z)], r == 0 closes with a pole"""
    rings = []
    for r, z in prof:
        if r < 1e-6: rings.append([bm.verts.new(frame @ Vector((0, 0, z)))]); continue
        rings.append([bm.verts.new(frame @ Vector((r*math.cos(2*math.pi*i/n), r*math.sin(2*math.pi*i/n), z))) for i in range(n)])
    for A, B in zip(rings, rings[1:]):
        if len(A) == 1: [bm.faces.new((A[0], B[(i + 1) % n], B[i])) for i in range(n)]
        elif len(B) == 1: [bm.faces.new((A[i], A[(i + 1) % n], B[0])) for i in range(n)]
        else: [bm.faces.new((A[i], A[(i + 1) % n], B[(i + 1) % n], B[i])) for i in range(n)]

def slab(bm, grid, closed, t):
    """thin cloth: grid[j][i] points (rows j, columns i), thickness t, closed in i if `closed`"""
    J, I = len(grid), len(grid[0])
    def nrm(j, i):
        a = grid[j][(i + 1) % I if closed else min(i + 1, I - 1)] - grid[j][(i - 1) % I if closed else max(i - 1, 0)]
        b = grid[min(j + 1, J - 1)][i] - grid[max(j - 1, 0)][i]
        return a.cross(b).normalized()
    top = [[bm.verts.new(grid[j][i] + nrm(j, i)*t/2) for i in range(I)] for j in range(J)]
    bot = [[bm.verts.new(grid[j][i] - nrm(j, i)*t/2) for i in range(I)] for j in range(J)]
    ni = I if closed else I - 1
    for j in range(J - 1):
        for i in range(ni):
            i2 = (i + 1) % I
            bm.faces.new((top[j][i], top[j][i2], top[j + 1][i2], top[j + 1][i]))
            bm.faces.new((bot[j][i], bot[j + 1][i], bot[j + 1][i2], bot[j][i2]))
    for j in (0, J - 1):
        for i in range(ni):
            i2 = (i + 1) % I; bm.faces.new((top[j][i], bot[j][i], bot[j][i2], top[j][i2]))
    if not closed:
        for i in (0, I - 1):
            for j in range(J - 1): bm.faces.new((top[j][i], top[j + 1][i], bot[j + 1][i], bot[j][i]))

# ---------------------------------------------------------------- pha khao ma loincloth
SK_TOP, SK_N, SK_AZ = 1.00, 12, 36
CROTCH = [0.82]
def skirt_bottom(a):                    # a: azimuth from the front (-Y) towards the character's left (+X)
    """short at the sides, hitched up front and back over the pestle he sits on"""
    side = 0.72 + 0.012*math.sin(3*a + 0.7)
    return side + (CROTCH[0] + 0.045 - side)*math.cos(a)**8      # centre hitched up clear of the pestle

def hull_radius(bvh, zs, az, yc=0.01):
    """outer wrap of the body at each azimuth (at its own height zs[i]); rays come in from outside"""
    out = []
    for z, a in zip(zs, az):
        c = Vector((0, yc, z)); d = Vector((math.sin(a), -math.cos(a), 0))
        hit = bvh.ray_cast(c + d*0.26, -d, 0.26)[0]    # start inside the reach of the hands
        out.append((hit - c).length if hit is not None and (hit - c).dot(d) > 0.005 else None)
    n = len(out)
    if all(r is None for r in out): return [0.15]*n
    for i in range(n):                  # gaps (between the legs): bridge across like a wrapped cloth
        if out[i] is None:
            j = 1
            while out[(i - j) % n] is None: j += 1
            k = 1
            while out[(i + k) % n] is None: k += 1
            out[i] = (out[(i - j) % n]*k + out[(i + k) % n]*j)/(j + k)
    for _ in range(6):                  # convex-ish: cloth spans hollows
        out = [max(out[i], 0.985*(out[i - 1] + out[(i + 1) % n])/2) for i in range(n)]
    return out

def build_cloth(body, rig):
    bm_b = bmesh.new(); bm_b.from_mesh(body.data); bm_b.transform(body.matrix_world)
    bvh = BVHTree.FromBMesh(bm_b); bm_b.free()
    az = [2*math.pi*i/SK_AZ for i in range(SK_AZ)]; rnd = random.Random(3)
    grid, prev = [], None
    for j in range(SK_N):
        f = j/(SK_N - 1); row = []
        zs = [SK_TOP + (skirt_bottom(a) - SK_TOP)*f for a in az]
        rr = hull_radius(bvh, zs, az)
        rr =[max(r, prev[i]) if prev else r for i, r in enumerate(rr)]; prev = rr
        for i, a in enumerate(az):
            fold = 0.007*f*math.sin(5*a + 1.3) + 0.004*f*math.sin(11*a + 0.4)
            r = rr[i] + 0.012 + 0.030*f*f + fold
            row.append(Vector((math.sin(a)*r, 0.01 - math.cos(a)*r, zs[i])))
        grid.append(row)
    bm = bmesh.new(); slab(bm, grid, True, 0.007)

    def on_skirt(a, z, out=0.0):
        f = (SK_TOP - z)/(SK_TOP - skirt_bottom(a)); f = min(max(f, 0), 1)
        i = int(round(a/(2*math.pi)*SK_AZ)) % SK_AZ; j = min(int(round(f*(SK_N - 1))), SK_N - 1)
        p = grid[j][i]; d = Vector((p.x, p.y - 0.01, 0)).normalized()
        return Vector((p.x, p.y, z)) + d*out, d
    # knot at the left hip, front
    ka = R(62); kp, kd = on_skirt(ka, 0.965, 0.022)
    sph = bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=7, radius=1.0)
    for v in sph["verts"]:
        c = v.co.copy(); n = 1 + 0.18*math.sin(3*c.x + 2*c.z) + 0.1*math.sin(5*c.y)
        v.co = kp + Vector((c.x*0.034, c.y*0.026, c.z*0.030))*n
    # two tails from the knot: one hangs down the front of the thigh, one flicks out to the side-back
    for (a0, a1, z1, w0, w1, wave) in ((R(58), R(40), 0.60, 0.075, 0.06, 0.02), (R(72), R(100), 0.68, 0.06, 0.045, 0.03)):
        rows = []; K = 9
        for k in range(K + 1):
            t = k/K; a = a0 + (a1 - a0)*t; z = 0.955 + (z1 - 0.955)*t
            c, d = on_skirt(a, max(z, 0.72), 0.018 + 0.03*t*t)
            c.z = z; side = Vector((0, 0, 1)).cross(d).normalized()
            c += d*wave*math.sin(t*7 + a0*3)*t
            w = w0 + (w1 - w0)*t; tw = 0.5*t
            down = Vector((0, 0, 1))
            u = (side*math.cos(tw) + d*math.sin(tw))*w/2
            rows.append([c - u, c, c + u])
        slab(bm, rows, False, 0.006)

    # weights: blended from the nearest skin (hips / spine / thighs) so the cloth bends exactly like the body under it;
    # the front centre, which hangs over the pestle, is partly bound to `sak` so it rides on the pestle and doesn't
    # get cut by it when the hips pitch
    keep = ("hips", "spine", "thigh.L", "thigh.R")
    gname = {g.index: g.name for g in body.vertex_groups}; mw = body.matrix_world
    vw = [{gname[g.group]: g.weight for g in v.groups if gname.get(g.group) in keep} for v in body.data.vertices]
    bvs = [mw @ v.co for v in body.data.vertices]; bfs = [tuple(p.vertices) for p in body.data.polygons]
    btree = BVHTree.FromPolygons(bvs, bfs)
    def skin_w(p):
        """weights of the skin at its nearest surface point (inverse-distance over that face's corners)"""
        loc, _, fi, _ = btree.find_nearest(p); acc = {}
        for i in bfs[fi]:
            w = 1.0/max((bvs[i] - loc).length, 0.002); tot = sum(vw[i].values())
            for bn, x in vw[i].items():
                if tot > 0: acc[bn] = acc.get(bn, 0.0) + w*x/tot
        tot = sum(acc.values()) or 1.0
        return {bn: x/tot for bn, x in acc.items()}
    def groups(p):
        acc = skin_w(p)
        sk = 0.75*sstep(0.10, 0.03, abs(p.x))*sstep(0.97, 0.86, p.z)*sstep(0.02, 0.06, abs(p.y - 0.01))
        acc = {bn: x*(1 - sk) for bn, x in acc.items()}
        if sk > 0: acc["sak"] = sk
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]; tot = sum(x for _, x in top)
        return {bn: x/tot for bn, x in top}
    ob = new_obj("Cloth", bm, rig, groups)
    smooth_weights(ob, 3)
    return ob

# ---------------------------------------------------------------- kradong (winnowing basket) and sak (pestle)
KR_R = 0.36
KR_PROF = [(0.0, 0.006), (0.10, 0.010), (0.20, 0.018), (0.28, 0.029), (0.335, 0.041), (0.350, 0.055), (0.366, 0.063),
           (0.381, 0.053), (0.384, 0.036), (0.372, 0.024), (0.350, 0.022), (0.33, 0.031), (0.28, 0.022),
           (0.20, 0.011), (0.10, 0.003), (0.0, 0.0)]
KR_ON, KR_BACK = 0.17, 0.042          # basket centre: along the forearm from the elbow / behind the arm
KR_STRAPS = (0.22, 0.80)               # strap positions along the forearm (x its length)
# sak: a big rice pestle ridden astride like a broom, seat in the middle (thin waist, slim shaft between the thighs),
#      heavy rounded ends
SAK_L = 1.80
SAK_PROF = [(0.0, -0.500), (0.045, -0.497), (0.068, -0.485), (0.078, -0.44), (0.077, -0.34), (0.052, -0.22),
            (0.038, -0.11), (0.034, 0.0), (0.038, 0.11), (0.052, 0.22), (0.074, 0.34), (0.076, 0.43),
            (0.068, 0.48), (0.046, 0.496), (0.0, 0.500)]
SAK_SEAT_R = 0.034
SAK_A = Vector((0.0, -0.02, 0.76))     # middle of the pestle (= its pivot), under the front of the crotch where the groin
                                       # meets it; height set by seat_pestle()
SAK_DIR = Vector((0.0, -1.0, 0.0))     # local +Z of the pestle = towards the front
FRAMES = {}

def seat_pestle(body):
    """put the pestle's waist right under the crotch"""
    mw = body.matrix_world
    z = min((mw @ v.co).z for v in body.data.vertices
            if abs((mw @ v.co).x) < 0.025 and abs((mw @ v.co).y) < 0.06 and 0.6 < (mw @ v.co).z < 1.0)
    SAK_A.z = z - SAK_SEAT_R - 0.022           # just under the crotch: the groin skin swings round it when the thighs lift
    return z

def forearm(rig, side):
    b = rig.data.bones["forearm." + side]; e = b.head_local.copy()
    return e, (b.tail_local - e).normalized(), b.length

def kradong_frame(rig, side):
    """basket strapped on the back of the forearm: convex side against the arm, centre a little past mid-forearm"""
    e, arm, L = forearm(rig, side)
    c = e + arm*KR_ON + Vector((0, KR_BACK, 0))
    Z = Vector((0, 1, 0)); X = arm; Y = Z.cross(X).normalized(); X = Y.cross(Z)
    m = Matrix((X, Y, Z)).transposed().to_4x4(); m.translation = c
    return m, e

def torus(bm, c, axis, R_, r, nu=12, nv=5):
    axis = axis.normalized(); u = axis.orthogonal().normalized(); v = axis.cross(u)
    rings = []
    for i in range(nu):
        a = 2*math.pi*i/nu; d = u*math.cos(a) + v*math.sin(a)
        rings.append([bm.verts.new(c + d*(R_ + r*math.cos(2*math.pi*j/nv)) + axis*r*math.sin(2*math.pi*j/nv)) for j in range(nv)])
    for i in range(nu):
        A, B = rings[i], rings[(i + 1) % nu]
        for j in range(nv): bm.faces.new((A[j], A[(j + 1) % nv], B[(j + 1) % nv], B[j]))

def sak_frame():
    Z = SAK_DIR.normalized(); X = Vector((1, 0, 0)); Y = Z.cross(X)
    m = Matrix((X, Y, Z)).transposed().to_4x4(); m.translation = SAK_A
    return m

def build_props(rig):
    out = {}
    for side in ("L", "R"):
        m, e = kradong_frame(rig, side); FRAMES["Kradong." + side] = m
        bm = bmesh.new(); lathe(bm, m, KR_PROF, 32)
        _, arm, L = forearm(rig, side)
        for k in KR_STRAPS:                                     # two rattan straps tie the basket to the forearm
            torus(bm, e + arm*L*k + Vector((0, 0.004, 0)), arm, 0.040, 0.006)
        out[side] = new_obj("Kradong." + side, bm, rig, lambda p, s=side: {"kradong." + s: 1.0})
    m = sak_frame(); FRAMES["Sak"] = m
    bm = bmesh.new(); lathe(bm, m, [(r, z*SAK_L) for r, z in SAK_PROF], 14)
    out["Sak"] = new_obj("Sak", bm, rig, lambda p: {"sak": 1.0})
    return out

def add_bones(rig):
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.selected_objects: o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    for side in ("L", "R"):                                    # along the forearm: twisting it feathers the basket
        e, arm, L = forearm(rig, side)
        b = eb.new("kradong." + side); b.head = e + arm*0.02; b.tail = e + arm*KR_ON
        b.parent = eb["forearm." + side]; b.use_connect = False; b.align_roll(Vector((0, -1, 0)))
    b = eb.new("sak"); b.head = SAK_A; b.tail = SAK_A + SAK_DIR*0.5    # from the seat towards the front end
    b.parent = eb["hips"]; b.use_connect = False; b.align_roll(Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    for n in ("kradong.L", "kradong.R", "sak"): rig.data.bones[n].use_deform = True

# ---------------------------------------------------------------- atlas UVs
BOX = {"Body": (0.0, 0.0, 0.75, 0.75), "Hair": (0.0, 0.75, 0.375, 1.0), "Cloth": (0.375, 0.75, 0.75, 1.0),
       "Kradong.L": (0.75, 0.75, 1.0, 1.0), "Kradong.R": (0.75, 0.5, 1.0, 0.75), "Sak": (0.75, 0.0, 1.0, 0.5)}
PAD = 0.006

def atlas_uv(ob):
    u0, v0, u1, v1 = BOX[ob.name]; u0 += PAD; v0 += PAD; u1 -= PAD; v1 -= PAD
    me = ob.data
    if ob.name != "Body":
        for o in bpy.context.selected_objects: o.select_set(False)
        bpy.context.view_layer.objects.active = ob; ob.select_set(True)
        while me.uv_layers: me.uv_layers.remove(me.uv_layers[0])
        me.uv_layers.new(name="UVMap")
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=R(60), island_margin=0.01, scale_to_bounds=True)
        bpy.ops.object.mode_set(mode='OBJECT')
    uv = me.uv_layers[0]; uv.name = "UVMap"
    a = np.empty(len(uv.data)*2, np.float32); uv.data.foreach_get("uv", a); a = a.reshape(-1, 2)
    a[:, 0] = u0 + np.clip(a[:, 0], 0, 1)*(u1 - u0); a[:, 1] = v0 + np.clip(a[:, 1], 0, 1)*(v1 - v0)
    uv.data.foreach_set("uv", a.ravel())

# ---------------------------------------------------------------- bake geometry into texel maps
OBJ_ID = {"Body": 1, "Hair": 2, "Cloth": 3, "Kradong.L": 4, "Kradong.R": 5, "Sak": 6}

def set_engine(sc, names):
    for n in names:
        try: sc.render.engine = n; return n
        except TypeError: pass

def bake_maps(objs, rig):
    sc = bpy.context.scene; set_engine(sc, ["CYCLES"])
    sc.cycles.device = 'CPU'; sc.cycles.samples = 1
    rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
    mat = bpy.data.materials.new("_Bake"); mat.use_nodes = True; nt = mat.node_tree; nt.nodes.clear()
    outn = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    geo = nt.nodes.new("ShaderNodeNewGeometry"); oi = nt.nodes.new("ShaderNodeObjectInfo")
    img = nt.nodes.new("ShaderNodeTexImage"); nt.links.new(em.outputs[0], outn.inputs["Surface"])
    saved = {}
    for o in objs:
        saved[o.name] = [s.material for s in o.material_slots]
        o.data.materials.clear(); o.data.materials.append(mat); o.pass_index = OBJ_ID[o.name]
    for o in bpy.context.selected_objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    res = {}
    for key, sock in (("pos", geo.outputs["Position"]), ("nrm", geo.outputs["Normal"]), ("id", oi.outputs["Object Index"])):
        im = bpy.data.images.new("_b_" + key, BAKE, BAKE, float_buffer=True); im.colorspace_settings.name = "Non-Color"
        img.image = im; nt.nodes.active = img
        for l in list(nt.links):
            if l.to_node == em: nt.links.remove(l)
        nt.links.new(sock, em.inputs["Color"])
        bpy.ops.object.bake(type='EMIT', margin=16, margin_type='EXTEND', use_clear=True)
        a = np.empty(BAKE*BAKE*4, np.float32); im.pixels.foreach_get(a)
        res[key] = a.reshape(BAKE*BAKE, 4)[:, :3].copy(); bpy.data.images.remove(im)
    for o in objs:
        o.data.materials.clear()
        for m in saved[o.name]: o.data.materials.append(m)
    bpy.data.materials.remove(mat)
    res["id"] = np.rint(res["id"][:, 0]).astype(np.int32)
    return res

# ---------------------------------------------------------------- procedural paint (numpy, 3D)
def _hash(ix, iy, iz, seed):
    h = (ix*73856093) ^ (iy*19349663) ^ (iz*83492791) ^ (seed*2654435761 & 0x7FFFFFFF)
    h = (h ^ (h >> 13))*1274126177; h = h ^ (h >> 16)
    return (h & 0xFFFF).astype(np.float32)/65535.0

def vnoise(P, f, seed=0):
    Q = P*np.asarray(f, np.float32); i = np.floor(Q).astype(np.int64); t = Q - i; t = t*t*(3 - 2*t)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (t[:, 0] if dx else 1 - t[:, 0])*(t[:, 1] if dy else 1 - t[:, 1])*(t[:, 2] if dz else 1 - t[:, 2])
                out = out + w*_hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out

def fbm(P, f, oct=4, seed=0):
    a, tot, s = 0.0, 0.0, 1.0
    for o in range(oct):
        a = a + s*vnoise(P, np.asarray(f, np.float32)*(2**o), seed + o); tot += s; s *= 0.5
    return a/tot

def lines(P, f, w, seed=0):
    """thin branching lines (veins, cracks): 1 on the line"""
    n = vnoise(P, f, seed) + 0.5*vnoise(P, np.asarray(f)*2.1, seed + 9)
    return 1 - sstep(0.0, w, np.abs(n - 0.75))

def ell(X, Z, cx, cz, rx, rz):
    return np.sqrt(((X - cx)/rx)**2 + ((Z - cz)/rz)**2)

def seg_dist(X, Z, a, b):
    ax, az = a; bx, bz = b; dx, dz = bx - ax, bz - az
    t = np.clip(((X - ax)*dx + (Z - az)*dz)/(dx*dx + dz*dz), 0, 1)
    return np.hypot(X - ax - t*dx, Z - az - t*dz), t

def mix(c, col, w):
    w = np.clip(w, 0, 1)[:, None]; return c*(1 - w) + np.asarray(col, np.float32)/255.0*w

def face_marks(body, head):
    """eye / nose / mouth heights off the nose piece (same rules as build_skin.landmarks)"""
    bm = bmesh.new(); bm.from_mesh(body.data); bm.transform(body.matrix_world); bm.verts.ensure_lookup_table()
    seen, isl = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        st, grp = [v], []; seen.add(v.index)
        while st:
            x = st.pop(); grp.append(x)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
        isl.append(grp)
    isl.sort(key=len)
    small = [g for g in isl[:-1] if len(g) < 200]
    nose = min(small, key=lambda g: sum(v.co.y for v in g)/len(g))
    top = max(v.co.z for v in nose); base = min(v.co.z for v in nose); tip = min(nose, key=lambda v: v.co.y).co.copy()
    skin = isl[-1]
    chin = min(v.co.z for v in skin if v.co.y < tip.y + 0.07 and abs(v.co.x) < 0.02 and v.co.z > head.C.z - 0.2)
    bm.free()
    eye = top - 0.22*(top - base); mouth = base - 0.40*(base - chin)
    return dict(eye=eye, base=base, top=top, tip=tip, chin=chin, mouth=mouth)

def paint_body(P, N, rig, fm, hd):
    n = len(P); X, Y, Z = P[:, 0], P[:, 1], P[:, 2]; s = hd.s
    big = fbm(P, (3, 3, 3), 3, 1); mid = fbm(P, (14, 14, 14), 3, 2); fine = vnoise(P, (90, 90, 90), 3)
    # dark, dry, grey-brown skin with a sick green cast; blotchy, darker towards hands and feet
    c = np.empty((n, 3), np.float32); c[:] = np.array([60, 46, 35], np.float32)/255
    c = mix(c, (40, 38, 30), sstep(0.45, 0.75, big))
    c = mix(c, (80, 64, 48), sstep(0.55, 0.80, mid)*0.5)
    c = mix(c, (24, 20, 17), sstep(0.55, 0.15, Z)*0.6 + sstep(0.6, 0.85, mid)*0.3)
    rough = 0.74 + 0.12*mid; H = (fine - 0.5)*0.25 + (mid - 0.5)*0.4
    # withered skin: crackle of dry fissures (fainter on the face), veins over the limbs and neck
    C = hd.C; dh = np.linalg.norm(P - np.asarray(C, np.float32), axis=1)
    onface = sstep(0.13*s, 0.09*s, dh)*(Y < C.y - 0.02)
    cr = lines(P, (75, 75, 75), 0.02, 11)*(1 - 0.7*onface)
    c = mix(c, (20, 16, 14), cr*0.55); H -= cr*0.5
    limb = np.clip(sstep(0.17, 0.30, np.abs(X)) + sstep(0.75, 0.40, Z) + sstep(1.42, 1.55, Z)*sstep(-1, 0, -np.abs(Y - 0.0))*0.0, 0, 1)
    vein = lines(P, (9, 9, 4), 0.03, 21)*limb
    c = mix(c, (52, 50, 62), vein*0.7); H += vein*0.9
    # ribcage: ribs slope down to the sides, deep shadow between them; sternum ridge; sunken belly
    ribz = 1.115
    reg = sstep(ribz, ribz + 0.03, Z)*sstep(1.40, 1.33, Z)*sstep(0.19, 0.13, np.abs(X))*sstep(0.10, 0.02, Y)
    ph = (Z + 0.55*np.abs(X) - ribz)/0.031
    rib = 0.5 + 0.5*np.cos(2*np.pi*ph); rib = rib**3
    gap = (1 - rib)*reg*sstep(0.006, 0.03, np.abs(X))
    c = mix(c, (22, 20, 18), gap*0.85); c = mix(c, (104, 96, 80), rib*reg*0.55)
    H += (rib*1.6 - 0.8)*reg
    stern = np.exp(-(X/0.010)**2)*sstep(1.18, 1.24, Z)*sstep(1.42, 1.36, Z)*(Y < 0)
    H += stern*0.6; c = mix(c, (96, 88, 74), stern*0.4)
    belly = sstep(1.13, 1.08, Z)*sstep(0.92, 0.98, Z)*sstep(0.0, -0.05, Y)
    c = mix(c, (26, 24, 21), belly*0.55*sstep(0.16, 0.0, np.abs(X))); H -= belly*0.5
    navel = np.exp(-((X/0.007)**2 + ((Z - 1.0)/0.009)**2))*(Y < 0); c = mix(c, (15, 12, 10), navel); H -= navel*1.5
    # collarbones and the hollows above them, neck cords
    for sx in (1, -1):
        d, t = seg_dist(X, Z, (0.025*sx, 1.425), (0.165*sx, 1.448))
        cl = np.exp(-(d/0.008)**2)*(Y < 0.02); H += cl*1.2; c = mix(c, (102, 94, 80), cl*0.5)
        hol = np.exp(-(((X - 0.09*sx)/0.04)**2 + ((Z - 1.465)/0.012)**2))*(Y < 0.0); H -= hol; c = mix(c, (25, 22, 20), hol*0.6)
        d, t = seg_dist(X, Z, (0.045*sx, fm["chin"] - 0.01), (0.015*sx, 1.44))
        cord = np.exp(-(d/0.007)**2)*(Y < 0.03); H += cord*1.0; c = mix(c, (86, 80, 68), cord*0.35)
    # spine bumps and shoulder blades
    back = (Y > 0.03)
    vert = np.exp(-(X/0.009)**2)*(0.5 + 0.5*np.cos(2*np.pi*(Z - 1.0)/0.028))*sstep(0.95, 1.0, Z)*sstep(1.50, 1.44, Z)*back
    H += vert*0.9; c = mix(c, (96, 88, 74), vert*0.4)
    for sx in (1, -1):
        bl = ell(X, Z, 0.085*sx, 1.33, 0.05, 0.075); edge = np.exp(-((bl - 1)/0.12)**2)*back
        H += edge*0.6 - (bl < 1)*back*0.15; c = mix(c, (24, 22, 19), edge*0.35)
    # knuckles, elbows and knees darker and wrinkled; long dirty claws
    bs = rig.data.bones
    for side in ("L", "R"):
        for j, rad in (("forearm." + side, 0.04), ("shin." + side, 0.05)):
            q = np.asarray(bs[j].head_local, np.float32); d = np.linalg.norm(P - q, axis=1)
            k = sstep(rad, 0.0, d); c = mix(c, (30, 27, 23), k*0.6); H += (lines(P, (60, 60, 60), 0.05, 31)*k)*0.8
        for f in ("index", "middle", "ring", "pinky", "thumb"):
            tip = np.asarray(bs[f"{f}_03.{side}"].tail_local, np.float32)
            d = np.linalg.norm(P - tip, axis=1); nail = sstep(0.016, 0.009, d)
            c = mix(c, (92, 80, 50), nail*0.95); c = mix(c, (35, 28, 18), nail*sstep(0.010, 0.004, d)); rough = rough*(1 - nail*0.4)
            H += nail*0.5
            for k in ("01", "02"):
                q = np.asarray(bs[f"{f}_{k}.{side}"].head_local, np.float32); dk = np.linalg.norm(P - q, axis=1)
                kn = sstep(0.011, 0.0, dk); c = mix(c, (28, 25, 22), kn*0.5); H += kn*0.4
        toe = np.asarray(bs["toe." + side].tail_local, np.float32); dt = np.linalg.norm(P - toe, axis=1)
        c = mix(c, (60, 52, 36), sstep(0.03, 0.012, dt)*0.6)
    sole = sstep(0.025, 0.006, Z); c = mix(c, (20, 18, 15), sole*0.8)
    # ---- wounds (painted in 3D, so none is cut by a UV seam): raw strap burns under the basket ties, scrapes on the
    # inner thighs and knees from gripping the pestle, gashes on the ribs, back and face, scattered open sores
    rag = fbm(P, (60, 60, 60), 3, 120)                            # ragged edges
    m = np.zeros(n, np.float32)
    for side in ("L", "R"):
        e, arm, L = forearm(rig, side); e = np.asarray(e, np.float32); ax_ = np.asarray(arm, np.float32)
        t = (P - e) @ ax_; rad = np.linalg.norm(P - e - t[:, None]*ax_, axis=1)
        for k in KR_STRAPS:
            band = sstep(0.020, 0.008, np.abs(t - L*k) + (rag - 0.5)*0.012)*(rad < 0.06)*(t > 0)
            m = np.maximum(m, band)
        b = bs["thigh." + side]; h0 = np.asarray(b.head_local, np.float32); h1 = np.asarray(b.tail_local, np.float32)
        tl = np.clip((P - h0) @ (h1 - h0)/np.dot(h1 - h0, h1 - h0), 0, 1); off = P - (h0 + tl[:, None]*(h1 - h0))
        sg = 1.0 if side == "L" else -1.0
        inner = sstep(0.1, 0.6, -sg*off[:, 0]/np.maximum(np.linalg.norm(off, axis=1), 1e-6))
        streak = vnoise(P, (140, 140, 9), 121 if side == "L" else 122)          # long scrapes running down the thigh
        scr = sstep(0.62, 0.78, streak)*inner*sstep(0.25, 0.4, tl)*sstep(1.0, 0.85, tl)*sstep(0.45, 0.6, fbm(P, (12, 12, 6), 2, 123))
        m = np.maximum(m, scr*0.9)
        kn = np.asarray(bs["shin." + side].head_local, np.float32); dk = np.linalg.norm((P - kn)*np.array([1, 1, 0.8], np.float32), axis=1)
        knee = sstep(0.040, 0.020, dk + (rag - 0.5)*0.02)*(Y < kn[1] - 0.01)
        m = np.maximum(m, knee*sstep(0.35, 0.55, vnoise(P, (90, 90, 90), 124)))
    gash = []
    for a_, b_, w_, msk in (((0.055, 1.255), (0.150, 1.185), 0.006, Y < -0.02),            # across the left ribs
                            ((-0.070, 1.300), (-0.125, 1.215), 0.004, Y < -0.02),          # short cut, right ribs
                            ((-0.095, 1.400), (0.010, 1.200), 0.0035, Y > 0.03),           # three claw rakes down the back
                            ((-0.070, 1.415), (0.035, 1.215), 0.0035, Y > 0.03),
                            ((-0.045, 1.425), (0.060, 1.235), 0.0030, Y > 0.03)):
        d, t = seg_dist(X, Z, a_, b_); w = w_*np.maximum(np.sin(np.pi*np.clip(t, 0.02, 0.98)), 0)**0.5
        gash.append(sstep(w*1.6, w*0.4, d + (rag - 0.5)*0.004)*msk*(dh > 0.18*s))
    E0 = fm["eye"]; MZ0 = fm["mouth"]; frn = (Y < C.y - 0.02)*(dh < 0.16*s)
    d, t = seg_dist(X, Z, (0.030*s, E0 - 0.022*s), (0.058*s, MZ0 - 0.002*s))                # down the left cheek
    gash.append(sstep(0.0034*s, 0.0008*s, d + (rag - 0.5)*0.002*s)*np.maximum(np.sin(np.pi*np.clip(t, 0, 1)), 0)**0.4*frn)
    d, t = seg_dist(X, Z, (-0.020*s, E0 + 0.050*s), (-0.050*s, E0 + 0.020*s))               # split over the right brow
    gash.append(sstep(0.0026*s, 0.0006*s, d + (rag - 0.5)*0.002*s)*np.maximum(np.sin(np.pi*np.clip(t, 0, 1)), 0)**0.4*frn)
    for g in gash: m = np.maximum(m, np.nan_to_num(g))           # sin(pi) is -9e-8 in float32: ** of it is NaN
    sore = fbm(P, (20, 20, 20), 3, 125)*(1 - onface)                 # a few open sores (shoulders, shins, belly)
    m = np.maximum(m, sstep(0.76, 0.84, sore + (rag - 0.5)*0.08))
    core = sstep(0.55, 0.80, m); rim = sstep(0.15, 0.45, m)*(1 - core)
    scab = sstep(0.55, 0.70, vnoise(P, (220, 220, 220), 126))*core
    smear = sstep(0.0, 0.6, m)*sstep(0.45, 0.8, fbm(P, (40, 40, 15), 2, 127))   # dried blood run out past the edge
    c = mix(c, (40, 12, 9), smear*0.6)
    c = mix(c, (52, 14, 10), rim*0.85); H += rim*0.35
    c = mix(c, (118, 20, 15), core); c = mix(c, (150, 46, 36), core*sstep(0.6, 0.9, fine)*0.6)
    c = mix(c, (56, 22, 14), scab); H += -core*1.3 + scab*1.0
    rough = np.where(core > 0.4, 0.28, rough); rough = np.where(scab > 0.4, 0.85, rough)
    # ---- head: scalp under the hair is dark; snarling face
    head = dh < 0.16*s
    E, MZ = fm["eye"], fm["mouth"]
    scalp = head & ((Z > E + 0.075*s) | ((Y > C.y + 0.02) & (Z > MZ)))
    c = mix(c, (16, 15, 14), scalp*0.9)
    fr = head & (Y < C.y - 0.02) & (np.abs(X) < 0.085*s)
    ax = np.abs(X); w = fr.astype(np.float32)
    # deep sockets, brow ridge pulled down hard toward the nose (angry), frown lines, wrinkled forehead
    ex = 0.031*s
    sock = sstep(1.25, 0.45, ell(ax, Z, ex, E - 0.001, 0.022*s, 0.015*s))*w
    c = mix(c, (14, 11, 10), sock*0.9); H -= sock*1.2
    under = sstep(1.0, 0.0, ell(ax, Z, ex + 0.004*s, E - 0.016*s, 0.02*s, 0.008*s))*w
    c = mix(c, (24, 18, 18), under*0.6); H -= under*0.4
    lid = E + 0.0045*s + 0.24*(ax - ex)                      # upper lid slants down toward the nose
    eye = (ell(ax, Z, ex, E, 0.0115*s, 0.0062*s) < 1) & (Z < lid) & fr
    c = mix(c, (196, 182, 126), eye*1.0)
    vein_e = lines(P, (900, 900, 900), 0.08, 41)*eye; c = mix(c, (150, 30, 24), vein_e*0.7 + eye*sstep(0.55, 1.0, ell(ax, Z, ex, E, 0.0115*s, 0.0062*s))*0.6)
    iris = (ell(ax, Z, ex - 0.0015*s, E - 0.0005*s, 0.0042*s, 0.0042*s) < 1) & eye
    c = mix(c, (170, 70, 18), iris*1.0)
    pupil = (ell(ax, Z, ex - 0.0015*s, E - 0.0005*s, 0.0016*s, 0.0024*s) < 1) & eye
    c = mix(c, (6, 4, 3), pupil*1.0)
    lidl = np.exp(-((Z - lid)/(0.0012*s))**2)*(ell(ax, Z, ex, E, 0.014*s, 0.010*s) < 1)*w
    c = mix(c, (10, 8, 8), lidl*0.9)
    rough = np.where(eye, 0.25, rough)
    bd, bt = seg_dist(ax, Z, (0.008*s, E + 0.0085*s), (0.056*s, E + 0.026*s))
    brow = sstep(0.0065*s, 0.0035*s, bd)*w
    hairy = lines(P, (500, 500, 2000), 0.25, 51)
    c = mix(c, (12, 11, 10), brow*(0.65 + 0.35*hairy)); H += brow*1.3
    d, t = seg_dist(ax, Z, (0.0045*s, E + 0.006*s), (0.006*s, E + 0.024*s))
    g = np.exp(-(d/(0.0008*s))**2)*w; c = mix(c, (22, 17, 15), g*0.7); H -= g*1.2
    for k in range(4):
        zz = E + (0.040 + 0.010*k)*s + 0.004*s*np.sin(X*90/s + k)
        g = np.exp(-((Z - zz)/(0.0013*s))**2)*sstep(0.05*s, 0.02*s, ax)*w; c = mix(c, (24, 20, 18), g*0.6); H -= g*0.9
    for k in range(3):                                         # snarl creases over the bridge of the nose
        zz = E - (0.006 + 0.0055*k)*s
        g = np.exp(-((Z - zz)/(0.0011*s))**2)*sstep(0.013*s, 0.004*s, ax)*w; c = mix(c, (22, 18, 16), g*0.8); H -= g
    nos = (ell(ax, Z, 0.0085*s, fm["base"] + 0.002*s, 0.0045*s, 0.0028*s) < 1) & fr
    c = mix(c, (8, 5, 5), nos*1.0); H -= nos*1.0
    # nasolabial folds driven deep by the snarl, hollow cheeks
    d, t = seg_dist(ax, Z, (0.015*s, fm["base"] + 0.003*s), (0.031*s, MZ - 0.004*s))
    nl = np.exp(-(d/(0.0035*s))**2)*w*np.sin(np.pi*np.clip(t*0.9 + 0.1, 0, 1))
    c = mix(c, (18, 13, 11), nl*0.7); H -= nl*1.4
    ch = sstep(1.0, 0.0, ell(ax, Z, 0.050*s, MZ + 0.012*s, 0.020*s, 0.026*s))*w
    c = mix(c, (24, 22, 19), ch*0.6); H -= ch*0.6
    # snarling mouth: lips pulled back, upper and lower teeth with long canines, dark gums and throat
    mx, mz = 0.027*s, 0.0105*s
    mo = ell(X, Z, 0, MZ, mx, mz)
    sq = np.abs(X)/mx                                          # corners pulled up and back
    mo = ell(X, Z - 0.004*s*sq**2, 0, MZ, mx, mz*(1 - 0.35*sq**4))
    mouth = (mo < 1) & fr
    lip = np.exp(-((mo - 1.0)/0.16)**2)*w
    c = mix(c, (38, 22, 22), lip*0.9); H += lip*0.5
    c = mix(c, (8, 3, 3), mouth*1.0); H = np.where(mouth, -1.5, H); rough = np.where(mouth, 0.3, rough)
    zc = Z - 0.004*s*sq**2
    upper = mouth & (zc > MZ + 0.0015*s) & (zc < MZ + 0.0085*s)
    lower = mouth & (zc < MZ - 0.0020*s) & (zc > MZ - 0.0085*s)
    tw = 0.0047*s; col = np.abs(np.mod(X + tw/2, tw) - tw/2)
    teeth = (upper | lower) & (col > 0.0006*s)
    for sx in (1, -1):                                         # canines reach past the gap
        fang = mouth & (np.abs(X - 0.0145*s*sx) < 0.0022*s) & (zc > MZ - 0.0045*s) & (zc < MZ + 0.0085*s)
        fang &= (zc - (MZ - 0.0045*s)) > np.abs(X - 0.0145*s*sx)*1.4
        teeth |= fang
    c = mix(c, (176, 160, 104), teeth*1.0); c = mix(c, (110, 90, 52), teeth*sstep(MZ + 0.006*s, MZ + 0.009*s, zc)*0.6)
    H = np.where(teeth, -0.4, H); rough = np.where(teeth, 0.35, rough)
    gum = mouth & (zc >= MZ + 0.0085*s); c = mix(c, (92, 24, 22), gum*1.0)
    # temples: purple veins
    tv = lines(P, (110, 110, 110), 0.05, 61)*sstep(0.05*s, 0.07*s, ax)*head*sstep(E - 0.02*s, E + 0.02*s, Z)*(Y < C.y + 0.03)
    c = mix(c, (50, 40, 62), tv*0.8); H += tv*0.6
    return c, np.clip(rough, 0.05, 1.0), H

def paint_hair(P):
    n = len(P); f1 = vnoise(P, (160, 160, 60), 71); f2 = fbm(P, (25, 25, 25), 3, 72)
    c = np.empty((n, 3), np.float32); c[:] = np.array([16, 15, 14], np.float32)/255
    c = mix(c, (34, 31, 30), sstep(0.6, 0.95, f1)*0.6); c = mix(c, (5, 5, 5), sstep(0.5, 0.2, f2)*0.7)
    return c, 0.78 + 0.12*f2, (f1 - 0.5)*0.8

def paint_cloth(P):
    n = len(P); X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
    a = np.arctan2(X, -(Y - 0.01))*0.16
    # pha khao ma: red plaid (wider dark-red and thin darker bands both ways), faded, dirty and frayed
    c = np.empty((n, 3), np.float32); c[:] = np.array([128, 24, 22], np.float32)/255
    for coord, off in ((a, 0.0), (Z, 0.013)):
        ph = np.mod(coord + off, 0.06)/0.06
        c = mix(c, (86, 14, 14), ((ph > 0.08) & (ph < 0.30)).astype(np.float32)*0.55)
        c = mix(c, (40, 8, 10), ((ph > 0.62) & (ph < 0.66)).astype(np.float32)*0.7)
        c = mix(c, (150, 110, 70), ((ph > 0.74) & (ph < 0.76)).astype(np.float32)*0.35)
    dirt = fbm(P, (8, 8, 8), 4, 81); c = mix(c, (38, 26, 20), sstep(0.5, 0.75, dirt)*0.7)
    c = mix(c, (30, 22, 18), sstep(0.78, 0.66, Z)*0.5)
    weave = 0.5 + 0.25*np.sin(X*1400) + 0.25*np.sin(Z*1400)
    return c, 0.86 + 0.1*dirt, (weave - 0.5)*0.4 + (dirt - 0.5)*0.4

def paint_kradong(P, m):
    inv = np.asarray(m.inverted(), np.float32)
    q = P @ inv[:3, :3].T + inv[:3, 3]; x, y, z = q[:, 0], q[:, 1], q[:, 2]; r = np.hypot(x, y)
    n = len(P); w = 0.011
    i = np.floor(x/w).astype(np.int64); j = np.floor(y/w).astype(np.int64)
    over = np.mod(i + j, 4) < 2                                   # 2/2 twill
    fx = np.mod(x, w)/w; fy = np.mod(y, w)/w
    across = np.where(over, fy, fx)                               # position across the strip on top
    idx = np.where(over, j, i)
    tone = _hash(idx, np.where(over, 1, 2), idx*0 + 3, 91)
    c = np.empty((n, 3), np.float32); c[:] = np.array([156, 124, 76], np.float32)/255
    c = mix(c, (118, 88, 50), tone*0.7)
    edge = sstep(0.30, 0.0, np.minimum(across, 1 - across))
    c = mix(c, (52, 38, 22), edge*0.8)
    along = np.where(over, x, y); fib = vnoise(np.stack([along*3, across, tone], 1), (60, 8, 1), 92)
    c = mix(c, (176, 146, 96), sstep(0.65, 0.95, fib)*0.4)
    H = (1 - edge)*0.8 - 0.4 + (fib - 0.5)*0.3
    # rattan-bound rim, diagonal wraps
    rim = sstep(0.330, 0.342, r)
    ang = np.arctan2(y, x); rw = np.mod(ang*KR_R/0.012 + z/0.012*1.0, 1.0)
    band = 0.5 + 0.5*np.cos(2*np.pi*rw)
    c = mix(c, (74, 50, 28), rim); c = mix(c, (40, 26, 14), rim*(1 - band)*0.8); H = H*(1 - rim) + rim*(band - 0.5)*1.4
    strap = sstep(-0.001, -0.004, z)                              # rattan straps round the forearm
    sb = 0.5 + 0.5*np.cos(2*np.pi*np.mod(x/0.006, 1.0))
    c = mix(c, (66, 44, 24), strap); c = mix(c, (30, 20, 10), strap*(1 - sb)*0.7); H = H*(1 - strap) + strap*(sb - 0.5)
    # soot, mould and grime: these have been flown through many nights
    g = fbm(P, (6, 6, 6), 4, 93); c = mix(c, (34, 30, 22), sstep(0.45, 0.8, g)*0.75)
    c = mix(c, (60, 66, 40), sstep(0.72, 0.85, fbm(P, (20, 20, 20), 2, 94))*0.35)
    return c, 0.78 + 0.12*g, H

def paint_sak(P, m):
    inv = np.asarray(m.inverted(), np.float32)
    q = P @ inv[:3, :3].T + inv[:3, 3]; t = q[:, 2]/SAK_L + 0.5
    ang = np.arctan2(q[:, 1], q[:, 0])
    n = len(P); u = np.stack([np.cos(ang)*0.04, np.sin(ang)*0.04, q[:, 2]], 1)
    warp = fbm(u, (40, 40, 3), 3, 101)
    grain = 0.5 + 0.5*np.sin((ang*10 + warp*9)*2.0)
    c = np.empty((n, 3), np.float32); c[:] = np.array([96, 64, 40], np.float32)/255
    c = mix(c, (60, 38, 22), grain*0.6)
    worn = np.exp(-((t - 0.5)/0.14)**2)                          # polished dark waist where he sits and grips
    c = mix(c, (44, 28, 18), worn*0.5)
    end = sstep(0.93, 1.0, t) + sstep(0.04, 0.0, t)                # pounding end: pale, split, crushed fibres
    # dry checks: hairline splits running with the grain, in clusters, more towards the ends, few on the worn waist
    patch = sstep(0.45, 0.70, fbm(u, (30, 30, 2.5), 2, 104))*(1 - 0.8*worn) + end*0.6
    cr = lines(u, (150, 150, 7), 0.018, 102)*np.clip(patch, 0, 1)
    cr = np.maximum(cr, lines(u, (280, 280, 16), 0.014, 105)*0.6*np.clip(patch - 0.2, 0, 1))
    r = np.hypot(q[:, 0], q[:, 1])                                  # end grain: short radial splits out from the heart
    rad = lines(np.stack([np.cos(ang)*0.04, np.sin(ang)*0.04, r*0.4], 1), (420, 420, 30), 0.02, 106)
    cap = sstep(0.975, 0.99, t) + sstep(0.025, 0.01, t)
    cr = np.maximum(cr, rad*cap*0.9)
    pore = sstep(0.82, 0.92, vnoise(u, (900, 900, 120), 107))*0.5
    c = mix(c, (120, 100, 72), end*0.6); c = mix(c, (30, 20, 12), cr*0.75); c = mix(c, (40, 26, 16), pore*0.5)
    g = fbm(P, (7, 7, 7), 3, 103); c = mix(c, (30, 24, 18), sstep(0.5, 0.8, g)*0.5)
    rough = 0.62 - worn*0.2 + end*0.2
    return c, rough, (grain - 0.5)*0.6 - cr*0.5 - pore*0.2

def paint(maps, rig, body, hd, fm):
    pos, nrm, ids = maps["pos"], maps["nrm"], maps["id"]
    S = BAKE*BAKE
    col = np.zeros((S, 3), np.float32); col[:] = 0.2
    rough = np.full(S, 0.7, np.float32); hgt = np.zeros(S, np.float32)
    for oid, fn in ((1, lambda P, N: paint_body(P, N, rig, fm, hd)), (2, lambda P, N: paint_hair(P)),
                    (3, lambda P, N: paint_cloth(P)), (4, lambda P, N: paint_kradong(P, FRAMES["Kradong.L"])),
                    (5, lambda P, N: paint_kradong(P, FRAMES["Kradong.R"])), (6, lambda P, N: paint_sak(P, FRAMES["Sak"]))):
        sel = np.nonzero(ids == oid)[0]
        if not len(sel): log("no texels for", oid); continue
        c, r, h = fn(pos[sel].astype(np.float32), nrm[sel].astype(np.float32))
        col[sel] = c; rough[sel] = r; hgt[sel] = h
        log("painted", oid, len(sel))
    return col, rough, hgt

def down(a, k=BAKE//TEX):
    sh = a.shape; a = a.reshape(TEX, k, TEX, k, -1).mean(axis=(1, 3)); return a.reshape(TEX*TEX, *sh[1:])

def save_png(arr, path, chans=3, colorspace="sRGB"):
    n = int(math.sqrt(len(arr))); px = np.ones((len(arr), 4), np.float32)
    px[:, :chans] = arr.reshape(len(arr), -1)[:, :chans] if arr.ndim > 1 else arr[:, None]
    if chans == 1: px[:, 1] = px[:, 0]; px[:, 2] = px[:, 0]
    im = bpy.data.images.new("_save", n, n); im.colorspace_settings.name = colorspace
    im.pixels.foreach_set(np.clip(px, 0, 1).ravel()); im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    bpy.data.images.remove(im)

def bake_normal(objs, hgt):
    """tangent-space normal map from the painted height, baked by Cycles through a Bump node (OpenGL, +Y up)"""
    sc = bpy.context.scene; sc.cycles.samples = 4
    him = bpy.data.images.new("_height", BAKE, BAKE, float_buffer=True); him.colorspace_settings.name = "Non-Color"
    px = np.ones((BAKE*BAKE, 4), np.float32); px[:, 0] = px[:, 1] = px[:, 2] = hgt; him.pixels.foreach_set(px.ravel())
    out = bpy.data.images.new("_nrm", BAKE, BAKE, float_buffer=True); out.colorspace_settings.name = "Non-Color"
    mat = bpy.data.materials.new("_BakeN"); mat.use_nodes = True; nt = mat.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    ht = nt.nodes.new("ShaderNodeTexImage"); ht.image = him; ht.interpolation = 'Cubic'
    bump = nt.nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = 0.0025
    nt.links.new(ht.outputs["Color"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    nt.links.new(b.outputs[0], o.inputs["Surface"])
    tgt = nt.nodes.new("ShaderNodeTexImage"); tgt.image = out; nt.nodes.active = tgt
    saved = {}
    for ob in objs:
        saved[ob.name] = [s.material for s in ob.material_slots]; ob.data.materials.clear(); ob.data.materials.append(mat)
    for ob in bpy.context.selected_objects: ob.select_set(False)
    for ob in objs: ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT', margin=16, margin_type='EXTEND', use_clear=True)
    a = np.empty(BAKE*BAKE*4, np.float32); out.pixels.foreach_get(a); a = a.reshape(-1, 4)[:, :3]
    for ob in objs:
        ob.data.materials.clear()
        for m in saved[ob.name]: ob.data.materials.append(m)
    for im in (him, out): bpy.data.images.remove(im)
    bpy.data.materials.remove(mat)
    v = down(a*2 - 1); v /= np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-6)
    return v*0.5 + 0.5

def make_material(objs):
    mat = bpy.data.materials.get(NAME) or bpy.data.materials.new(NAME); mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0], o.inputs["Surface"])
    def tex(suffix, cs):
        n = nt.nodes.new("ShaderNodeTexImage")
        p = os.path.join(M, f"{NAME}_{suffix}.png")
        im = bpy.data.images.get(os.path.basename(p))
        if im: bpy.data.images.remove(im)
        n.image = bpy.data.images.load(p); n.image.colorspace_settings.name = cs; return n
    nt.links.new(tex("Color", "sRGB").outputs["Color"], b.inputs["Base Color"])
    nt.links.new(tex("Roughness", "Non-Color").outputs["Color"], b.inputs["Roughness"])
    nt.links.new(tex("Metalness", "Non-Color").outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = "UVMap"
    nt.links.new(tex("Normal", "Non-Color").outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs[0], b.inputs["Normal"])
    for ob in objs:
        ob.data.materials.clear(); ob.data.materials.append(mat)
    for m in list(bpy.data.materials):
        if m.users == 0 or (m.use_fake_user and m.name != NAME): m.use_fake_user = False
    return mat

# ---------------------------------------------------------------- animation
def wrot(P, rig, bone, W):
    """rotation W (3x3, armature rest space, about the bone's head) -> pose-local euler, no joint-limit clamp"""
    B = rig.data.bones[bone].matrix_local.to_3x3()
    P.frame[bone] = ("rot", list((B.inverted() @ W @ B).to_euler('XYZ')))

def rx(d): return Matrix.Rotation(R(d), 3, 'X')
def ry(d): return Matrix.Rotation(R(d), 3, 'Y')
def rz(d): return Matrix.Rotation(R(d), 3, 'Z')

def claw(P, k=1.0):
    """hands are free (the baskets are strapped to the forearms): bony fingers hooked like claws"""
    for f in AN["FINGERS"]: P.both(f, -20*k if f.endswith("_01") else -38*k)
    P.both("thumb_01", -10*k); P.both("thumb_02", -20*k); P.both("thumb_03", -25*k)

def flight_body(P, rig, pitch, bob, roll=0.0, yaw=0.0):
    wrot(P, rig, "hips", rz(yaw) @ ry(roll) @ rx(pitch)); P.lift("hips", bob)

def ride(P, rig, pitch, tilt=6.0):
    """the pestle stays level under him (nose up `tilt`) whatever the body pitch; it is bound to the hips"""
    wrot(P, rig, "sak", rx(-pitch - tilt))

SHIN_RIDE, FOOT_RIDE, TOE_RIDE = -125.0, -6.0, -6.0

def shins(P, a):
    """knee bend past the base rig's -95 joint limit (P.rot clamps to the limit it read; add_anims widens the constraint)"""
    for sd in ("L", "R"): P.frame["shin." + sd] = ("rot", [R(a), 0.0, 0.0])

RIDE_SPREAD = 8.0

def straddle(P, pitch, fwd=70.0, kick=0.0, spread=RIDE_SPREAD):
    """gripping the pestle: thighs `fwd` degrees forward of hanging straight down (in the world), knees just wide of the
    pestle's sides; shins folded up back like a jockey's; feet left almost neutral (bent hard, the ankle weights turn
    the foot into a boot). A thigh lifted this far is spread by Y (about the rest bone's long axis, which now stands
    upright): Z would only twist it about its own length"""
    P.rot("thigh.L", pitch + fwd + kick, -spread, 0); P.rot("thigh.R", pitch + fwd - kick, spread, 0)
    shins(P, SHIN_RIDE); P.both("foot", FOOT_RIDE); P.both("toe", TOE_RIDE)

def wing(P, rig, side, raise_, fwd, bend, feather, swing=0.0):
    sg = 1 if side == "L" else -1
    P.rot("upper_arm." + side, raise_, 0, fwd); P.rot("forearm." + side, 0, 0, -bend)
    P.rot("hand." + side, -10, 0, 0)
    P.frame["kradong." + side] = ("rot", [R(swing), R(feather*sg), 0.0])

def head_up(P, k=1.0, turn=0.0, tilt=0.0):
    P.rot("neck", -26*k, turn*0.4, tilt*0.5); P.rot("head", -30*k, turn*0.6, tilt*0.5)

def flap_phase(t, down=0.38):
    """0 = top of the stroke, 0.5 = bottom; the down-stroke is quicker than the recovery"""
    return t/down*0.5 if t < down else 0.5 + (t - down)/(1 - down)*0.5

def c_flapfly(P, rig, t):
    s = flap_phase(t); c = math.cos(2*math.pi*s)                  # +1 top, -1 bottom
    up = max(0.0, math.sin(2*math.pi*(s - 0.5)))                  # recovery (basket feathered)
    pitch = 30 + 3*c
    flight_body(P, rig, pitch, -0.04*math.cos(2*math.pi*(s - 0.15)) + 0.02)
    P.rot("spine", -4 - 3*c); P.rot("chest", -3 - 3*c)
    head_up(P, 0.45 + 0.1*c)
    for side in ("L", "R"):
        wing(P, rig, side, 40 + 32*c, -16 + 6*c, 12 + 30*up, 70*up, swing=0)   # top low and forward: baskets clear the head and hair
    P.both("shoulder", 10 + 10*c, 0, 0)
    claw(P)
    straddle(P, pitch, 70, kick=4*c)
    ride(P, rig, pitch, 6 + 3*math.cos(2*math.pi*(s - 0.25)))

def c_glide(P, rig, t):
    a = 2*math.pi*t; pitch = 34 + 2*math.sin(a)
    flight_body(P, rig, pitch, 0.02*math.sin(a), 7*math.sin(a + 0.6), 3*math.sin(a))
    P.rot("spine", -6); P.rot("chest", -4)
    head_up(P, 0.5, turn=8*math.sin(a + 1.5), tilt=-4*math.sin(a))
    for side, k in (("L", 1), ("R", -1)):
        wing(P, rig, side, 50 + 5*math.sin(a)*k, -14, 12, 12 + 4*math.sin(a + 0.4)*k)
    P.both("shoulder", 14, 0, 0)
    claw(P)
    straddle(P, pitch, 66, kick=3*math.sin(a))
    ride(P, rig, pitch, 4 + 2*math.sin(a + 1.0))

def crouch(P, rig, lean=20.0):
    flight_body(P, rig, lean, 0.0)
    P.both("thigh", 98, 0, 18); P.both("shin", -95); P.both("foot", 22); P.both("toe", 30)

def perch_drop(rig, P, fn):
    """how far the crouched pose must sink so the feet rest on the roof: pose it, measure the toes"""
    fn(P, rig, 0.0); P.key(1)
    bpy.context.scene.frame_set(1); bpy.context.view_layer.update()
    pb = rig.pose.bones; mw = rig.matrix_world
    z = min((mw @ pb[n].tail).z for n in ("toe.L", "toe.R", "foot.L", "foot.R"))
    return z - 0.02

CROUCH_DROP = [0.0]
SEAT_REL = 36.0        # most the pestle may turn against the hips (nose up): more and it drives into the crotch / belly,
                       # so perched (body leaning far over) it follows the lean and its back end hangs just over the roof
def perch_tilt(lean):
    return SEAT_REL - lean

def c_perch(P, rig, t, lean=24.0):
    crouch(P, rig, lean); P.lift("hips", -CROUCH_DROP[0])
    P.rot("spine", 12); P.rot("chest", 8); head_up(P, 0.7)
    for side in ("L", "R"):                                       # wings folded: baskets edge-on at the sides
        wing(P, rig, side, 8, 28, 40, 80, swing=10)
    claw(P)
    ride(P, rig, lean, perch_tilt(lean))

def c_land(P, rig, t):
    k = AN["sm"](0.0, 0.75, t); hop = math.sin(min(t/0.75, 1)*math.pi)*0.08
    lean = 34*(1 - k) + 24*k
    wrot(P, rig, "hips", rx(lean)); P.lift("hips", (0.55*(1 - k) - CROUCH_DROP[0]*k) + hop*(1 - k))
    P.rot("spine", -6*(1 - k) + 12*k); P.rot("chest", -4*(1 - k) + 8*k); head_up(P, 0.5*(1 - k) + 0.7*k)
    flap = math.cos(2*math.pi*min(t/0.55, 1)*1.5)*(1 - k)          # a last braking beat of the baskets
    for side in ("L", "R"):
        wing(P, rig, side, (40 + 32*flap)*(1 - k) + 8*k, -16*(1 - k) + 28*k, 12*(1 - k) + 40*k, 12*(1 - k) + 80*k, swing=10*k)
    P.both("shoulder", 14*(1 - k), 0, 0)
    claw(P)
    P.rot("thigh.L", (lean + 66)*(1 - k) + 98*k, -RIDE_SPREAD*(1 - k), 18*k)
    P.rot("thigh.R", (lean + 66)*(1 - k) + 98*k, RIDE_SPREAD*(1 - k), 18*k)
    shins(P, SHIN_RIDE*(1 - k) - 95*k); P.both("foot", FOOT_RIDE*(1 - k) + 22*k); P.both("toe", TOE_RIDE*(1 - k) + 30*k)
    ride(P, rig, lean, 4*(1 - k) + perch_tilt(lean)*k)

def c_peek(P, rig, t):
    a = 2*math.pi*t; lean = 50 + 4*math.sin(a)
    crouch(P, rig, lean); P.lift("hips", -CROUCH_DROP[0] - 0.03)
    P.rot("spine", 24 + 3*math.sin(a)); P.rot("chest", 20)
    jerk = math.exp(-((t - 0.62)/0.03)**2)                        # one sudden twitch of the head per loop
    P.rot("neck", 30, 6*math.sin(a), 8*math.sin(a + 0.5) + 8*jerk); P.rot("head", 28, 9*math.sin(a), 10*jerk)
    for side, k in (("L", 1), ("R", -1)):                         # claws hooked on the roof edge, baskets forward
        wing(P, rig, side, 30 - 12*(k < 0), -32 - 5*math.sin(a)*k, 50, 85, swing=-28)   # right one lower: the head and hair lean that way
    claw(P, 1.4)
    ride(P, rig, lean, perch_tilt(lean))

CLIPS = {"FlapFly": (c_flapfly, 30, False), "Glide": (c_glide, 90, False),
         "LandOnRoof": (c_land, 45, True), "PeekOverEdge": (c_peek, 120, False)}

def add_anims(rig):
    for sd in ("L", "R"):                       # riding folds the knee past the base rig's -95 (the constraint clamps keys too)
        c = next(c for c in rig.pose.bones["shin." + sd].constraints if c.type == 'LIMIT_ROTATION'); c.min_x = R(SHIN_RIDE - 5)
    P = AN["Poser"](rig)
    if not rig.animation_data: rig.animation_data_create()
    tmp = bpy.data.actions.new("_tmp"); rig.animation_data.action = tmp
    CROUCH_DROP[0] = 0.0
    CROUCH_DROP[0] = perch_drop(rig, P, lambda P, rig, t: c_perch(P, rig, t))
    bpy.data.actions.remove(tmp); log("crouch drop", round(CROUCH_DROP[0], 3))
    made = {}
    for name, (fn, n, once) in CLIPS.items():
        act = bpy.data.actions.new(name); act.use_fake_user = True; rig.animation_data.action = act
        for f in range(n + 1):
            fn(P, rig, f/n if once else (f % n)/n); P.key(f + 1)
        act.frame_range = (1, n + 1)
        try: act.use_cyclic = not once
        except AttributeError: pass
        made[name] = n
    rig.animation_data.action = bpy.data.actions["FlapFly"]
    sc = bpy.context.scene; sc.render.fps = 30; sc.frame_start, sc.frame_end = 1, made["FlapFly"] + 1
    return made

# ---------------------------------------------------------------- export
def fbx(path, **kw):
    bpy.ops.export_scene.fbx(filepath=path, global_scale=STUDS_PER_M, apply_scale_options='FBX_SCALE_NONE',
                             axis_forward='-Z', axis_up='Y', bake_space_transform=False, add_leaf_bones=False,
                             primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True, **kw)

def export_all(rig, objs):
    os.makedirs(CLIP_DIR, exist_ok=True)
    for o in bpy.context.selected_objects: o.select_set(False)
    for o in objs + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action; rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    rig.data.pose_position = 'REST'
    fbx(os.path.join(M, NAME + ".fbx"), use_selection=True, object_types={'ARMATURE', 'MESH'}, mesh_smooth_type='FACE',
        path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    rig.data.pose_position = 'POSE'
    for name in CLIPS:
        for o in bpy.context.selected_objects: o.select_set(False)
        rig.select_set(True); bpy.context.view_layer.objects.active = rig
        a = bpy.data.actions[name]; rig.animation_data.action = a
        f0, f1 = (int(x) for x in a.frame_range); sc = bpy.context.scene; sc.frame_start, sc.frame_end = f0, f1
        fbx(os.path.join(CLIP_DIR, f"{NAME}_{name}.fbx"), use_selection=True, object_types={'ARMATURE'}, bake_anim=True,
            bake_anim_use_all_bones=True, bake_anim_use_nla_strips=False, bake_anim_use_all_actions=False,
            bake_anim_force_startend_keying=True, bake_anim_step=1.0, bake_anim_simplify_factor=0.0)
    rig.animation_data.action = act

def check(rig, objs):
    dg = bpy.context.evaluated_depsgraph_get(); tot = 0
    for o in objs:
        me = o.data; tris = sum(len(p.vertices) - 2 for p in me.polygons); tot += tris
        mx = max((sum(1 for g in v.groups if g.weight > 0) for v in me.vertices), default=0)
        log(f"{o.name}: {tris} tris, {len(me.vertices)} verts, max bones/vertex {mx}")
    zs = [(o.matrix_world @ v.co).z for o in objs for v in o.data.vertices]
    body = bpy.data.objects["Body"]; bz = [v.co.z for v in body.data.vertices]
    log(f"total {tot} tris; body height {max(bz) - min(bz):.3f} m = {(max(bz) - min(bz))*STUDS_PER_M:.2f} studs; "
        f"rest bounds z {min(zs):.2f}..{max(zs):.2f} m")

ARM = ("shoulder", "upper_arm", "forearm", "hand", "thumb", "index", "middle", "ring", "pinky")
def relax_cloth(rig, passes=6, step=3):
    """skinning shrinks the hip crease when the thighs lift ~96 deg, and the cloth over it sinks into the skin. Sample all
    clips, find how deep each cloth vertex goes into the body, and push it out by that much (+6 mm) in the rest shape,
    away from the hips' axis, smoothed over 3 cm so the cloth stays a smooth surface; repeated, as a push can
    move a neighbour in"""
    from mathutils.kdtree import KDTree
    cloth = bpy.data.objects["Cloth"]; me = cloth.data; sc = bpy.context.scene; n = len(me.vertices)
    kd = KDTree(n)
    for v in me.vertices: kd.insert(v.co, v.index)
    kd.balance()
    nbr = [kd.find_range(v.co, 0.03) for v in me.vertices]
    for it in range(passes):
        parts = _Parts(); need = np.zeros(n, np.float32)
        for name in CLIPS:
            a = bpy.data.actions[name]; rig.animation_data.action = a; f0, f1 = (int(x) for x in a.frame_range)
            for f in range(f0, f1 + 1, step):
                sc.frame_set(f); parts.frame(bpy.context.evaluated_depsgraph_get())
                C, B = parts.tree("Cloth"), parts.tree("Body"); pairs = C.overlap(B)
                vs = parts.v["Cloth"]
                for vi in {x for i, _ in pairs for x in parts.faces["Cloth"][i]}:
                    p = vs[vi]
                    if parts.inside(B, p): need[vi] = max(need[vi], B.find_nearest(p)[3] + 0.006)
        w = int(need.argmax()); log(f"relax cloth pass {it + 1}: {int((need > 0).sum())} vertices in the skin, deepest "
                                     f"{need.max()*1000:.0f} mm (vertex {w} at rest {tuple(round(x, 3) for x in me.vertices[w].co)})")
        if need.max() <= 0.0: break
        push = np.array([max(need[j]*(1 - d/0.03) for _, j, d in nbr[i]) for i in range(n)], np.float32)
        for v in me.vertices:
            if push[v.index] <= 0: continue
            d = Vector((v.co.x, v.co.y - 0.01, 0.0))
            if d.length > 1e-6: v.co += d.normalized()*float(push[v.index])
        me.update()
    rig.animation_data.action = bpy.data.actions["FlapFly"]

CLIP_TOL = 0.006       # deeper than this (m) counts as passing through; skin resting on skin / cloth / wood is fine

class _Parts:
    """face subsets of each mesh, by the main bone of their vertices (topology is fixed, only positions change)"""
    def __init__(self):
        ob = bpy.data.objects; self.objs = {n: ob[n] for n in OBJ_ID}; self.faces = {}; self.pidx = {}
        body = ob["Body"]; grp = {g.index: g.name for g in body.vertex_groups}
        mb = []
        for v in body.data.vertices:
            g = max(v.groups, key=lambda g: g.weight, default=None); mb.append(grp.get(g.group, "") if g else "")
        def body_part(k, test):
            sel = [p for p in body.data.polygons if all(test(mb[i]) for i in p.vertices)]
            self.faces[k] = [tuple(p.vertices) for p in sel]; self.pidx[k] = {p.index for p in sel}
        def bone_in(prefixes, side=None):
            return lambda n: any(n.partition(".")[0].startswith(x) for x in prefixes) and (side is None or n.partition(".")[2] == side)
        for sd in ("L", "R"):
            body_part("arm." + sd, bone_in(ARM, sd))
            body_part("leg." + sd, bone_in(("thigh",), sd))
            body_part("lowleg." + sd, bone_in(("shin", "foot", "toe"), sd))
            body_part("body-arm." + sd, lambda n, sd=sd: not bone_in(ARM, sd)(n))
        body_part("trunk", bone_in(("hips", "spine", "chest", "neck", "head")))
        body_part("torso", bone_in(("hips", "spine", "chest")))         # under the hair: head and neck excluded
        for n, o in self.objs.items():
            self.faces[n] = [tuple(p.vertices) for p in o.data.polygons]; self.pidx[n] = None   # None = all faces
        self.owner = {k: ("Body" if k not in self.objs else k) for k in self.faces}

    def frame(self, dg):
        self.v = {}
        for n, o in self.objs.items():
            e = o.evaluated_get(dg); me = e.to_mesh(); mw = e.matrix_world
            self.v[n] = [mw @ x.co for x in me.vertices]; e.to_mesh_clear()
        self.bvh = {}

    def tree(self, k):
        if k not in self.bvh:
            if k.startswith("~"):                                    # the body without part k[1:]
                drop = self.pidx[k[1:]]; body = self.objs["Body"].data
                faces = [tuple(p.vertices) for p in body.polygons if p.index not in drop]
                self.bvh[k] = BVHTree.FromPolygons(self.v["Body"], faces); self.cidx = getattr(self, "cidx", {})
                self.cidx[k] = [p.index for p in body.polygons if p.index not in drop]
            else:
                self.bvh[k] = BVHTree.FromPolygons(self.v[self.owner[k]], self.faces[k]) if self.faces[k] else None
        return self.bvh[k]

    @staticmethod
    def inside(T, p):
        """ray parity against a closed mesh"""
        votes = 0
        for d in (Vector((0.137, 0.291, 0.947)), Vector((0.83, -0.41, 0.38)), Vector((-0.52, -0.62, -0.58))):
            d = d.normalized(); o = p.copy(); n = 0
            for _ in range(64):
                hit = T.ray_cast(o, d, 5.0)[0]
                if hit is None: break
                n += 1; o = hit + d*1e-5
            votes += n % 2
        return votes >= 2

    def depth(self, a, b):
        """deepest vertex of either part inside the other's whole (closed) mesh, measured to the nearest surface,
        counted only when that surface belongs to the part itself (m); only near faces that actually intersect"""
        A, B = self.tree(a), self.tree(b); self.at = None
        if A is None or B is None: return 0.0
        pairs = A.overlap(B)
        if not pairs: return 0.0
        d = 0.0
        for part, other, idx in ((a, b, {i for i, _ in pairs}), (b, a, {j for _, j in pairs})):
            vs = self.v[self.owner[part]]; own = self.pidx[other]
            same = self.owner[part] == self.owner[other]                # both on the body: test against the body minus part
            full = self.tree("~" + part if same else self.owner[other])
            for vi in {x for fi in idx for x in self.faces[part][fi]}:
                p = vs[vi]
                if not self.inside(full, p): continue
                loc, nrm, fi, dist = full.find_nearest(p)
                if same and loc is not None: fi = self.cidx["~" + part][fi]
                if loc is not None and (own is None or fi in own) and dist > d: d = dist; self.at = (part, vi, p.copy())
        return d

PAIRS = [("arm.L", "trunk"), ("arm.R", "trunk"), ("arm.L", "leg.L"), ("arm.L", "leg.R"), ("arm.R", "leg.L"), ("arm.R", "leg.R"),
         ("arm.L", "Sak"), ("arm.R", "Sak"), ("arm.L", "Cloth"), ("arm.R", "Cloth"),
         ("Kradong.L", "body-arm.L"), ("Kradong.R", "body-arm.R"), ("Kradong.L", "Kradong.R"), ("Kradong.L", "Sak"),
         ("Kradong.R", "Sak"), ("Kradong.L", "Hair"), ("Kradong.R", "Hair"), ("Kradong.L", "Cloth"), ("Kradong.R", "Cloth"),
         ("leg.L", "leg.R"), ("leg.L", "lowleg.L"), ("leg.R", "lowleg.R"), ("leg.L", "lowleg.R"), ("leg.R", "lowleg.L"), ("leg.L", "Sak"), ("leg.R", "Sak"),
         ("lowleg.L", "Sak"), ("lowleg.R", "Sak"), ("leg.L", "Cloth"), ("leg.R", "Cloth"), ("lowleg.L", "Cloth"),
         ("lowleg.R", "Cloth"), ("Cloth", "trunk"), ("Sak", "trunk"), ("Hair", "torso"), ("Hair", "arm.L"), ("Hair", "arm.R"), ("Cloth", "Sak")]

def clip_check(rig, step=1):
    """every frame of every clip: how deep each pair of parts passes into each other (vertex inside the other mesh).
    The basket against its own forearm and the hair against the head and neck don't count (strapped / rooted there)."""
    sc = bpy.context.scene; parts = _Parts(); worst = {}
    for name in CLIPS:
        a = bpy.data.actions[name]; rig.animation_data.action = a; f0, f1 = (int(x) for x in a.frame_range)
        mx = {}
        for f in range(f0, f1 + 1, step):
            sc.frame_set(f); parts.frame(bpy.context.evaluated_depsgraph_get())
            for pa in PAIRS:
                d = parts.depth(*pa)
                if d > mx.get(pa, (0, 0))[0]: mx[pa] = (d, f, parts.at)
        over = {pa: v for pa, v in mx.items() if v[0] > CLIP_TOL}
        log(f"clip check {name} ({f1 - f0 + 1} frames): " + ("clean" if not over else f"{len(over)} pairs pass through"))
        for pa, (d, f, at) in sorted(mx.items(), key=lambda kv: -kv[1][0]):
            if d > 0.002: log(f"    {pa[0]} x {pa[1]}: {d*1000:.0f} mm at f{f}" + ("  <-- THROUGH" if d > CLIP_TOL else "")
                              + (f"  (vertex {at[1]} of {at[0]} at {tuple(round(x, 3) for x in at[2])})" if at else ""))
        worst[name] = over
    return worst

# ---------------------------------------------------------------- previews
def preview_scene():
    sc = bpy.context.scene
    eng = set_engine(sc, ["BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"]); log("preview engine", eng)
    try: sc.eevee.taa_render_samples = 64
    except AttributeError: pass
    sc.render.film_transparent = False
    w = sc.world or bpy.data.worlds.new("World"); sc.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.045, 0.055, 0.075, 1); bg.inputs[1].default_value = 1.0
    for o in list(bpy.data.objects):
        if o.type in ('LIGHT', 'CAMERA'): bpy.data.objects.remove(o, do_unlink=True)
    def light(name, kind, loc, energy, color, size=1.0):
        l = bpy.data.lights.new(name, kind); l.energy = energy; l.color = color
        if kind == 'AREA': l.size = size
        o = bpy.data.objects.new(name, l); sc.collection.objects.link(o); o.location = loc
        o.rotation_euler = (-Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); return o
    light("_key", 'AREA', (-2.5, -3.0, 3.2), 900, (0.85, 0.9, 1.0), 2.0)
    light("_fill", 'AREA', (3.0, -2.0, 1.2), 250, (1.0, 0.85, 0.7), 2.5)
    light("_rim", 'AREA', (0.5, 3.5, 2.8), 700, (0.6, 0.8, 1.0), 2.0)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    try: sc.view_settings.view_transform = 'AgX'
    except TypeError: pass
    return cam

def eval_bounds(objs):
    dg = bpy.context.evaluated_depsgraph_get(); pts = []
    for o in objs:
        e = o.evaluated_get(dg); me = e.to_mesh()
        pts += [e.matrix_world @ v.co for v in me.vertices]; e.to_mesh_clear()
    return pts

def render_view(cam, objs, az, el, path, res=(1000, 1000), pts=None):
    sc = bpy.context.scene; pts = pts or eval_bounds(objs)
    a, e = R(az), R(el)
    d = Vector((math.sin(a)*math.cos(e), -math.cos(a)*math.cos(e), math.sin(e)))   # az 0 = in front of the character
    rot = (-d).to_track_quat('-Z', 'Y'); M3 = rot.to_matrix()
    right, up = M3.col[0], M3.col[1]
    xs = [p.dot(right) for p in pts]; ys = [p.dot(up) for p in pts]
    cx, cy = (min(xs) + max(xs))/2, (min(ys) + max(ys))/2
    span = max(max(xs) - min(xs), (max(ys) - min(ys))*res[0]/res[1])*1.08
    ctr = sum(pts, Vector())/len(pts); depth = ctr.dot(d)
    cam.location = right*cx + up*cy + d*(depth + 6.0); cam.rotation_euler = rot.to_euler()
    cam.data.ortho_scale = span; cam.data.clip_end = 30
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def previews(rig, objs):
    cam = preview_scene(); os.makedirs(PREV, exist_ok=True); sc = bpy.context.scene
    rig.data.pose_position = 'POSE'
    rig.animation_data.action = bpy.data.actions["FlapFly"]; sc.frame_set(9); bpy.context.view_layer.update()
    pts = eval_bounds(objs)
    render_view(cam, objs, 35, 12, os.path.join(PREV, NAME + ".png"), pts=pts)
    render_view(cam, objs, 0, 4, os.path.join(PREV, NAME + "_front.png"), pts=pts)
    render_view(cam, objs, 90, 2, os.path.join(PREV, NAME + "_side.png"), pts=pts)
    rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
    render_view(cam, objs, 0, 0, os.path.join(PREV, NAME + "_rest.png"), res=(1000, 1000))
    render_view(cam, [bpy.data.objects["Body"], bpy.data.objects["Hair"]], 0, 0, os.path.join(PREV, NAME + "_face.png"),
                res=(600, 600), pts=[p for p in eval_bounds([bpy.data.objects["Body"]]) if p.z > 1.55])
    rig.data.pose_position = 'POSE'
    # clip sheets: rows = clips (top to bottom FlapFly, Glide, LandOnRoof, PeekOverEdge), 5 moments each; 3/4, front, side
    for suffix, az, el in (("_anims", 20, 12), ("_anims_front", 0, 4), ("_anims_side", 90, 2)):
        tiles = []
        for name in CLIPS:
            a = bpy.data.actions[name]; rig.animation_data.action = a; f0, f1 = (int(x) for x in a.frame_range)
            row = []
            for k in range(5):
                sc.frame_set(int(f0 + (f1 - f0)*k/5 if name != "LandOnRoof" else f0 + (f1 - f0)*k/4)); bpy.context.view_layer.update()
                tmp = os.path.join(PREV, "_t.png"); render_view(cam, objs, az, el, tmp, res=(300, 300))
                im = bpy.data.images.load(tmp); arr = np.empty(300*300*4, np.float32); im.pixels.foreach_get(arr)
                row.append(arr.reshape(300, 300, 4)); bpy.data.images.remove(im); os.remove(tmp)
            tiles.append(np.concatenate(row, 1))
        sheet = np.concatenate(tiles[::-1], 0)
        img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
        img.filepath_raw = os.path.join(PREV, NAME + suffix + ".png"); img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    rig.animation_data.action = bpy.data.actions["FlapFly"]

# ---------------------------------------------------------------- main
def main():
    rig, body = open_base()
    gaunt(body)
    CROTCH[0] = seat_pestle(body); log("crotch", round(CROTCH[0], 3), "pestle seat", tuple(round(x, 3) for x in SAK_A))
    hair, hd = build_hair(body, rig)
    cloth = build_cloth(body, rig)
    add_bones(rig)
    props = build_props(rig)
    objs = [body, hair, cloth, props["L"], props["R"], props["Sak"]]
    for o in objs:
        if o.name in ("Kradong.L", "Kradong.R", "Sak", "Cloth", "Hair"): o.hide_render = False; o.hide_set(False)
    hair.name = "Hair"
    fm = face_marks(body, hd); log("face", {k: (round(v, 3) if isinstance(v, float) else v) for k, v in fm.items()}, "s", round(hd.s, 3))
    for o in objs: atlas_uv(o)
    if os.environ.get("KRAHANG_CHECK"):         # clipping numbers only (step = the env value, in frames)
        rig.data.pose_position = 'POSE'; add_anims(rig); relax_cloth(rig); clip_check(rig, int(os.environ["KRAHANG_CHECK"])); return
    if QUICK:                                   # pose / shape check: old textures, no export, previews to QUICK
        global PREV; PREV = QUICK; make_material(objs); rig.data.pose_position = 'POSE'
        add_anims(rig); relax_cloth(rig); check(rig, objs); clip_check(rig); previews(rig, objs); return
    maps = bake_maps(objs, rig)
    col, rough, hgt = paint(maps, rig, body, hd, fm)
    save_png(down(col), os.path.join(M, NAME + "_Color.png"))
    save_png(down(rough[:, None]), os.path.join(M, NAME + "_Roughness.png"), 1, "Non-Color")
    save_png(np.zeros((TEX*TEX, 1), np.float32), os.path.join(M, NAME + "_Metalness.png"), 1, "Non-Color")
    nrm = bake_normal(objs, hgt)
    save_png(nrm, os.path.join(M, NAME + "_Normal.png"), 3, "Non-Color")
    log("normal map spread", float(np.std(nrm[:, 0])), float(np.std(nrm[:, 1])))
    make_material(objs)
    rig.data.pose_position = 'POSE'
    lim = AN["limit_weights"](); log("weights trimmed", lim)
    made = add_anims(rig); log("clips", made)
    relax_cloth(rig)
    check(rig, objs)
    clip_check(rig)
    export_all(rig, objs)
    previews(rig, objs)
    for o in list(bpy.data.objects):
        if o.name.startswith("_"): bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(M, "krahang.blend"), relative_remap=True)

if __name__ == "__main__":
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.environ.get("TEMP", HERE), "krahang.txt")
    try:
        main(); LOG.append("DONE")
    except Exception:
        LOG.append("ERROR\n" + traceback.format_exc())
    finally:
        open(out, "w", encoding="utf-8").write("\n".join(LOG)); open(out + ".done", "w").write("x")
