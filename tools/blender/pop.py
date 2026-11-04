# ผีปอบ (Phi Pop) — ผีสิงร่างผู้หญิงชาวบ้าน ดัดแปลงจากโมเดลคน human_female (rig HumanRig + UV เดิม)
# ผิวหนังเหี่ยว (_Withered) + ผม ghost_messy + ชุดไทยเก่าของผีแม่ม่าย (ghost_widow จาก build_clothes.py)
# หน้า: ปากแบบกระสือ = อ้ากว้าง เห็นฟันบนล่าง เขี้ยวบน 2 ล่าง 2 (ชิ้นแยก) เลือดรอบปากไหลลงคางถึงคอ ตาแดงก่ำ (ชิ้นเลนส์แยก ทำ Neon ได้)
# ลิ้น (ชิ้นแยก + กระดูก tongue_01..03 ต่อจาก head) สำหรับท่า LickLips: ตอนพักซ่อนอยู่หลังช่องปากที่วาด ออกทางช่องปากเท่านั้น
#
# รัน (Blender 5.x, ไม่เปิดหน้าต่าง):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\pop.py -Out C:\tmp\pop.txt -TimeoutSec 3000
#   ส่วนที่ทำ: เปิด human_female.blend -> ทาสีผิว/หน้า -> ตัดผิวที่ชุดปิด -> เขี้ยว ตา ลิ้น -> 4 ท่า -> ตรวจทะลุทุกเฟรม
#   -> assets/models/pop.blend, Pop.fbx, Pop_<ท่า>.fbx, Pop_Anims.json, Pop_*.png, previews/Pop*.png
# ไม่แก้ไฟล์ใน human_base/ (exec อ่านอย่างเดียว ใน namespace แยก แล้วเปลี่ยน M ให้ชี้ worktree นี้)
import bpy, bmesh, math, os, sys, json, shutil, traceback
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
M = os.path.join(ROOT, "assets", "models")
HB = os.path.join(M, "human_base")
PREV = os.path.join(M, "previews")
CHAR = "female"
OUTFIT = "ghost_widow"         # ชุดไทยเก่าของผีแม่ม่าย (GDD ข้อ 30): เสื้อแขนกระบอกครามดำซีด + ซิ่นแดงคล้ำเก่า เท้าเปล่า
HAIR = "ghost_messy"
FPS = 30
LOG = []
def log(*a): LOG.append(" ".join(str(x) for x in a))

def load(name):
    src = open(os.path.join(HB, name), encoding="utf-8").read()
    old = 'M = r"C:\\Aunival\\pump-lot-anomaly\\assets\\models"'
    assert old in src, name
    src = src.replace(old, f"M = r\"{M}\"")
    ns = {"__name__": "pop_" + name[:-3]}
    exec(compile(src, name, "exec"), ns)
    return ns

SK = load("build_skin.py")
AN = load("build_anims.py")
HR = load("build_hair.py")
HR["GHOST_GAP"] = (0, 30)      # ปอบ: แหวกกลาง เห็นทั้งหน้า (ผมคนแหวกหน้าตาซ้าย)
sstep, mix, fbm, ridge, vnoise = SK["sstep"], SK["mix"], SK["fbm"], SK["ridge"], SK["vnoise"]
N = SK["N"]

# สีหน้า "pop" ต่อจากชุด FACES ของ build_skin (ค่าเดียวกับกระสือ: ตาเบิก คิ้วขมวด ปากอ้า 2.4 เห็นฟัน) + ยิ้มแสยะ
SK["FACES"]["pop"] = dict(ghost=True, open=1.25, brow=-1.2, mouth_open=2.4, smile=0.6, teeth=True)
# ปากที่วาดทับ (หน่วย = ขนาดหัว s): ครึ่งความกว้าง, ช่องอ้ากลางปาก, มุมปากยกขึ้น (แสยะ)
MW, GAP, GRIN = 0.026, 0.024, 0.0040
BLOOD = np.array((0.40, 0.02, 0.02)); BLOOD_DRY = np.array((0.19, 0.02, 0.02))
TOOTH = np.array((0.80, 0.74, 0.58))

# ---------------------------------------------------------------- face / skin painting
def head_canvas(meta):
    HV0, HV1 = SK["HV0"], SK["HV1"]
    rows = np.arange(N//2, N); cols = np.arange(N)
    v = (rows + 0.5)/N; u = (cols + 0.5)/N
    hh = meta["h0"] + (v - HV0)/(HV1 - HV0)*(meta["h1"] - meta["h0"])
    az = SK["unwarp"]((u - 0.5)*2*math.pi)
    X, Y = np.meshgrid(az*meta["RF"], hh)
    return SK["Canvas"](X, Y)

def mouth(meta):
    s = meta["s"]; return dict(my=meta["mouth_h"], w=MW*s, gap=GAP*s, grin=GRIN*s, s=s)

def mouth_bounds(X, m):
    """upper / lower edge of the open mouth at canvas x (works on arrays and floats)"""
    xm = np.clip(np.abs(X)/m["w"], 0, 1.5)
    lift = m["grin"]*np.clip(xm, 0, 1)**2
    k = np.clip(1 - xm**2, 0, None)
    up = m["my"] + lift + m["gap"]*0.50*k**0.55
    lo = m["my"] + lift - m["gap"]*0.50*k**0.80
    return xm, up, lo

def eye_geo(meta):
    s = meta["s"]; es = s*SK["LOOK"][CHAR]["eye"]; op = SK["FACES"]["pop"]["open"]
    a, bu, bl = 0.0155*es, 0.0062*es*op, 0.0044*es*op
    return dict(ex=0.032*s, ey=meta["eye_h"], a=a, bu=bu, bl=bl, ir=0.0055*es, s=s)

def paint_pop_head(meta):
    col, hgt, rough, pp = SK["paint_head"](meta, CHAR, "withered", "pop")
    cv = head_canvas(meta); X, Y = cv.X, cv.Y; s = meta["s"]
    m = mouth(meta); my = m["my"]
    # ---- red eyes (เลือดคั่งทั้งลูก): over the withered milky eye
    e = eye_geo(meta)
    for sx in (1, -1):
        cx = sx*e["ex"]; dx = (X - cx)/e["a"]
        up = e["ey"] + e["bu"]*np.clip(1 - dx**2, 0, None)**0.8
        lo = e["ey"] - e["bl"]*np.clip(1 - dx**2, 0, None)**0.9
        inside = (np.abs(dx) < 1) & (Y < up) & (Y > lo)
        soft = np.clip(np.minimum(up - Y, Y - lo)/(0.0006*s), 0, 1)*inside
        col = mix(col, (0.42, 0.03, 0.03), 0.85*cv.ell(cx, e["ey"], e["a"]*1.5, 0.012*s, 1.0)*(1 - soft))  # raw red rims
        col = mix(col, (0.55, 0.05, 0.04), soft)
        veins = ridge(X*900, Y*900, seed=5, sharp=12)*soft
        col = mix(col, (0.22, 0.01, 0.01), 0.8*veins)
        icx, icy = cx, e["ey"] + 0.0004*s
        iris = cv.ell(icx, icy, e["ir"], e["ir"], 0.2)*soft
        col = mix(col, (0.90, 0.12, 0.04), iris)
        col = mix(col, (0.02, 0.0, 0.0), cv.ell(icx, icy, e["ir"]*0.32, e["ir"]*0.32, 0.2)*soft)
        rough = np.where(inside, 0.10, rough)
    # ---- blood smeared round the mouth (under the lips)
    xm, up, lo = mouth_bounds(X, m)
    brk = sstep(0.35, 0.65, fbm(X/s*90, Y/s*90, oct=3, seed=81))
    smear = cv.ell(0, my + 0.3*m["grin"], m["w"]*1.40, m["gap"]*1.15, 0.8)
    col = mix(col, BLOOD_DRY, 0.80*smear*(0.5 + 0.5*brk))
    rough = np.where(smear*brk > 0.4, 0.22, rough)
    # ---- drips: from the lower lip over the chin, the long ones down the neck to the bottom of the head region
    chin = meta["chin_h"]; h0 = meta["h0"]
    rnd = np.random.RandomState(12)
    for i, (fx, end) in enumerate(((-0.62, chin - 0.010*s), (-0.30, h0 + 0.006*s), (-0.06, h0 + 0.004*s),
                                   (0.16, chin - 0.03*s), (0.38, h0 + 0.010*s), (0.66, chin + 0.004*s))):
        x0 = fx*m["w"]; y0 = float(mouth_bounds(np.array(x0), m)[2]) - 0.002*s
        n = max(4, int((y0 - end)/(0.006*s)))
        pts = []
        for k in range(n + 1):
            t = k/n
            pts.append((x0 + 0.0035*s*math.sin(t*7 + i*1.3) + 0.002*s*rnd.uniform(-1, 1)*t, y0 + (end - y0)*t, 1.0 - 0.45*t))
        wid = (0.0030 if end < chin else 0.0024)*s
        st = cv.seg(pts, wid)
        col = mix(col, BLOOD, 0.95*st); rough = np.where(st > 0.35, 0.12, rough); hgt += 0.00018*st
        col = mix(col, BLOOD, 0.9*cv.ell(pts[-1][0], pts[-1][1], wid*1.1, wid*1.5, 0.4))          # drop at the end
    col = mix(col, BLOOD, 0.75*cv.ell(0, chin + 0.006*s, m["w"]*0.75, 0.010*s, 0.9)*(0.6 + 0.4*brk))   # chin soaked
    neck = sstep(chin - 0.03*s, chin - 0.07*s, Y)*sstep(0.05*s, 0.025*s, np.abs(X))*(0.45 + 0.55*brk)
    col = mix(col, BLOOD_DRY, 0.75*neck); rough = np.where(neck > 0.4, 0.25, rough)                 # lower neck soaked
    # ---- lips: shrunken, dark, cracked, wet with blood
    lt_up = 0.0034*s*np.clip(1 - xm**2, 0, None)**0.5 + 0.0007*s
    lt_lo = 0.0046*s*np.clip(1 - xm**2, 0, None)**0.6 + 0.0007*s
    lip_up = (xm < 1.07) & (Y >= up) & (Y < up + lt_up)
    lip_lo = (xm < 1.07) & (Y <= lo) & (Y > lo - lt_lo)
    lipc = np.array((0.26, 0.06, 0.05))*(0.8 + 0.4*fbm(X/s*400, Y/s*120, oct=2, seed=83))[..., None]
    col = np.where((lip_up | lip_lo)[..., None], lipc, col)
    cr = ridge(X/s*1400, Y/s*500, seed=13, sharp=18)*(lip_up | lip_lo)
    col = mix(col, (0.08, 0.01, 0.01), 0.7*cr)
    hgt += 0.0003*lip_lo - 0.0003*cr
    rough = np.where(lip_up | lip_lo, 0.18, rough)
    # ---- inside: black-red mouth, gums, two rows of teeth (stained), bigger teeth where the fang pieces sit
    inside = (xm < 1) & (Y < up) & (Y > lo)
    col = np.where(inside[..., None], np.array((0.035, 0.008, 0.008)), col)
    gum_u = inside & (Y > up - 0.0016*s); gum_l = inside & (Y < lo + 0.0013*s)
    col = mix(col, (0.32, 0.05, 0.06), 0.95*(gum_u | gum_l))
    tw = 0.0034*s
    k = np.floor(X/tw + 0.5); tx = X/tw - k
    shade = (0.55 + 0.45*np.clip(1 - xm**2, 0, 1))[..., None]                           # darker towards the corners
    stain = sstep(0.4, 0.7, fbm(X/s*300, Y/s*300, oct=2, seed=85))[..., None]
    for row, top, h_ in (("u", up - 0.0013*s, 0.0052*s), ("l", lo + 0.0011*s, 0.0038*s)):
        hh = h_*(1 - 0.5*xm**2)*(1 - 0.35*(2*tx)**4)
        if row == "u": tooth = inside & (Y < top) & (Y > top - hh) & (np.abs(tx) < 0.43)
        else:          tooth = inside & (Y > top) & (Y < top + hh) & (np.abs(tx) < 0.43)
        tc = TOOTH*shade*(1 - 0.45*stain) + BLOOD*0.45*stain
        col = np.where(tooth[..., None], tc, col)
        rough = np.where(tooth, 0.25, rough)
        hgt += 0.0002*tooth
    # blood running down the front teeth from the gums
    run = inside & (sstep(0.62, 0.70, ridge(X/s*120, Y/s*25, seed=87, sharp=8)) > 0.5)
    col = mix(col, BLOOD, 0.8*run)
    return col, hgt, rough, pp

def paint_pop_body(ras, meta):
    col, hgt, rough = SK["paint_body"](ras, meta, CHAR, "withered")
    # blood carried on down the front of the neck below the head region (shows above the collar)
    P, Nn, mask = ras["P"], ras["N"], ras["mask"]; fr = ras["fr"]; s = meta["s"]
    names = ras["names"]; bn = np.array(names + ["-"])[ras["bone"]]
    nJ = fr.joints["neck"][0]
    x, z = P[..., 0] - nJ[0], P[..., 2]
    front = np.clip(-Nn[..., 1]*1.5, 0, 1)
    near = np.isin(bn, ["neck", "chest"])*mask*front
    st = np.zeros(mask.shape)
    for fx, ln in ((-0.30, 0.10), (-0.06, 0.14), (0.38, 0.08)):
        cx = fx*MW*s
        d = np.abs(x - cx - 0.003*s*np.sin(z*400))
        st = np.maximum(st, np.exp(-(d/(0.0028*s))**2)*sstep(nJ[2] - ln, nJ[2] - ln + 0.02, z))
    st *= near
    col = mix(col, BLOOD, 0.9*st); rough = np.where(st > 0.35, 0.12, rough)
    return col, hgt, rough

def make_textures(body, uv, meta):
    ras = SK["rasterise"](body, uv)
    hc, hh, hr, hp = paint_pop_head(meta)
    bc, bh, br = paint_pop_body(ras, meta)
    dil = SK["dilate"]
    bc, _ = dil(bc, ras["mask"]); bh, _ = dil(bh, ras["mask"]); br, _ = dil(br, ras["mask"])
    bp, _ = dil(ras["ppm"], ras["mask"]); bp = np.maximum(bp, 1.0)
    col = np.concatenate([bc, hc], 0); hgt = np.concatenate([bh, hh], 0); rgh = np.concatenate([br, hr], 0)
    nrm = SK["normal_from_height"](hgt, np.concatenate([bp, hp[0]], 0), np.concatenate([bp, hp[1]], 0))
    nrm[N//2 - 1:N//2 + 1] = (0.5, 0.5, 1.0)
    base = os.path.join(M, "Pop")
    SK["save_png"](col, base + "_Color.png", False); SK["save_png"](nrm, base + "_Normal.png", True)
    SK["save_png"](rgh, base + "_Roughness.png", True)
    return base

def make_parts_textures():
    """256 atlas for the small pieces: fang (u 0-.5, v .5-1, root -> tip up), tongue (u .5-1, v .5-1, base -> tip up),
    eye lens (u 0-.5, v 0-.5, disc)"""
    n = 256; yy, xx = (np.mgrid[0:n, 0:n] + 0.5)/n
    col = np.zeros((n, n, 3)); hgt = np.zeros((n, n)); rough = np.full((n, n), 0.4)
    fang = (xx < 0.5) & (yy >= 0.5); t = (yy - 0.5)*2
    fc = TOOTH*(0.85 + 0.25*t)[..., None]
    fc = fc*(1 - 0.5*(1 - t)[..., None]**3) + BLOOD*(0.5*(1 - t)**3)[..., None]                   # bloody at the gum
    col = np.where(fang[..., None], fc, col); rough = np.where(fang, 0.22, rough)
    tong = (xx >= 0.5) & (yy >= 0.5); tu = (xx - 0.75)*4
    tc = np.array((0.42, 0.07, 0.09))*(0.8 + 0.3*vnoise(xx*60, yy*60, seed=3))[..., None]
    tc = mix(tc, (0.22, 0.02, 0.04), np.exp(-(tu/0.12)**2))                                         # centre groove
    tc = mix(tc, BLOOD, 0.5*sstep(0.6, 0.8, fbm(xx*20, yy*20, oct=2, seed=4)))
    col = np.where(tong[..., None], tc, col); rough = np.where(tong, 0.15, rough)
    hgt += np.where(tong, 0.4*vnoise(xx*90, yy*90, seed=5) - 0.6*np.exp(-(tu/0.12)**2), 0)
    eye = (xx < 0.5) & (yy < 0.5); r = np.hypot(xx - 0.25, yy - 0.25)/0.25
    ec = np.array((0.55, 0.04, 0.03))*np.ones((n, n, 1))
    ec = mix(ec, (0.22, 0.01, 0.01), 0.8*ridge(xx*40, yy*40, seed=6, sharp=12)*sstep(0.4, 0.9, r))
    ec = mix(ec, (0.95, 0.14, 0.05), sstep(0.40, 0.34, r)); ec = mix(ec, (0.03, 0.0, 0.0), sstep(0.14, 0.10, r))
    col = np.where(eye[..., None], ec, col); rough = np.where(eye, 0.08, rough)
    nrm = SK["normal_from_height"](hgt*0.002, 256*20, 256*20)
    base = os.path.join(M, "Pop_Parts")
    SK["save_png"](col, base + "_Color.png", False); SK["save_png"](nrm, base + "_Normal.png", True)
    SK["save_png"](rough, base + "_Roughness.png", True)
    return base

# ---------------------------------------------------------------- helpers
def hidden_faces(me, outfit_faces, keep=1):
    """copy of build_clothes.hidden_faces (that file is being changed in another branch): body faces under the
    shell pieces of the outfit, minus `keep` rings along the openings"""
    vf = [[] for _ in me.vertices]
    for p in me.polygons:
        for v in p.vertices: vf[v].append(p.index)
    fs = set(f for lst in outfit_faces.values() for f in lst)
    for _ in range(keep):
        cnt = {}
        for fi in fs:
            vs = list(me.polygons[fi].vertices)
            for k in range(len(vs)):
                e = (min(vs[k], vs[(k + 1) % len(vs)]), max(vs[k], vs[(k + 1) % len(vs)])); cnt[e] = cnt.get(e, 0) + 1
        edge_v = {v for e, c in cnt.items() if c == 1 for v in e}
        fs -= {f for v in edge_v for f in vf[v]}
    return fs

def delete_faces(ob, faces):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in faces], context='FACES')
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bm.to_mesh(ob.data); bm.free(); ob.data.update()

def world_tree(ob, deps=None):
    if deps is None:
        me = ob.data; mw = ob.matrix_world
        return BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    ev = ob.evaluated_get(deps); me = ev.to_mesh(); mw = ob.matrix_world
    t = BVHTree.FromPolygons([mw @ v.co for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
    ev.to_mesh_clear(); return t

def bind(ob, rig, groups):
    """groups: {bone: [(vertex index, weight)]}"""
    for b, lst in groups.items():
        g = ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b)
        for vi, w in lst: g.add([vi], w, 'REPLACE')
    md = ob.modifiers.new("Armature", 'ARMATURE'); md.object = rig
    ob.parent = rig

def mesh_from(name, verts, faces, uvs=None, mat=None):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], faces); me.update()
    if uvs is not None:
        lay = me.uv_layers.new(name="UVMap")
        for p in me.polygons:
            for li, vi in zip(p.loop_indices, p.vertices): lay.data[li].uv = uvs[vi]
    if mat: me.materials.append(mat)
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    return ob

class Face:
    """canvas (x = azimuth * RF, y = height on the head axis) <-> points on the rest Body surface"""
    def __init__(self, body, rig, meta):
        self.fr = SK["Frame"](body, rig); self.meta = meta
        self.tree = world_tree(body)
    def at(self, x, y):
        fr = self.fr; az = x/self.meta["RF"]
        d = (fr.F*math.cos(az) + fr.L*math.sin(az)).normalized()
        o = fr.C + fr.U*y + d*0.3*fr.s
        loc, nrm, _, _ = self.tree.ray_cast(o, -d, 0.6*fr.s)
        if loc is None: raise RuntimeError(f"no surface at {x:.4f},{y:.4f}")
        if nrm.dot(d) < 0: nrm = -nrm
        return Vector(loc), nrm.normalized()

def pieces_mat(name, base):
    m = SK["skin_material"](name, base)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if "Subsurface Weight" in bsdf.inputs: bsdf.inputs["Subsurface Weight"].default_value = 0.0
    return m

# ---------------------------------------------------------------- pieces: fangs, eye lenses, tongue
def fang_mesh(face, root_xy, tip_xy, width, thick, mat):
    """half-cone lying on the skin: flat back 0.4 mm off the surface, round front; points from root to tip"""
    s = face.meta["s"]; RINGS, SEG = 6, 6
    V, UV, F = [], [], []
    for k in range(RINGS + 1):
        t = k/RINGS
        x = root_xy[0] + (tip_xy[0] - root_xy[0])*t; y = root_xy[1] + (tip_xy[1] - root_xy[1])*t
        p, n = face.at(x, y)
        p2, _ = face.at(root_xy[0] + (tip_xy[0] - root_xy[0])*min(t + 0.05, 1.0) - (0 if t < 1 else (tip_xy[0] - root_xy[0])*0.05),
                        root_xy[1] + (tip_xy[1] - root_xy[1])*min(t + 0.05, 1.0) - (0 if t < 1 else (tip_xy[1] - root_xy[1])*0.05))
        along = (p2 - p) if t < 1 else (p - p2)
        along = (along - n*along.dot(n)).normalized(); side = along.cross(n).normalized()
        r = width*(1 - t)**0.85 + 0.00015*s; h = thick*(1 - t)**0.7 + 0.0001*s
        base = p + n*0.0004*s
        for j in range(SEG + 1):
            a = math.pi*j/SEG
            V.append(base + side*(r*math.cos(a)) + n*(h*math.sin(a)))
            UV.append((0.05 + 0.40*j/SEG, 0.5 + 0.48*t))
    for k in range(RINGS):
        for j in range(SEG):
            a = k*(SEG + 1) + j; b = a + SEG + 1
            F.append((a, a + 1, b + 1, b))
    # flat back: a strip from the first to the last point of each ring (closes the half-cone)
    for k in range(RINGS):
        a = k*(SEG + 1); b = a + SEG + 1
        F.append((a + SEG, a, b, b + SEG))
    F.append(tuple(range(SEG, -1, -1)))                                    # root cap
    return V, UV, F

def build_fangs(face, rig, mat):
    s = face.meta["s"]; m = mouth(face.meta)
    V, UV, F = [], [], []
    for sx in (1, -1):
        for kind in ("up", "lo"):
            fx = (0.60 if kind == "up" else 0.46)*m["w"]*sx
            _, up, lo = mouth_bounds(np.array(fx), m); up, lo = float(up), float(lo)
            if kind == "up": root, tip = (fx, up - 0.0006*s), (fx - sx*0.0012*s, up - 0.58*(up - lo))
            else:            root, tip = (fx, lo + 0.0006*s), (fx - sx*0.0010*s, lo + 0.46*(up - lo))
            v, uv, f = fang_mesh(face, root, tip, 0.0022*s, 0.0016*s, mat)
            o = len(V); V += v; UV += uv; F += [tuple(i + o for i in p) for p in f]
    ob = mesh_from("Pop_Fangs", V, F, UV, mat)
    bind(ob, rig, {"head": [(i, 1.0) for i in range(len(V))]})
    return ob

def build_eyes(face, rig, mat):
    e = eye_geo(face.meta); s = e["s"]
    V, UV, F = [], [], []
    RR, SEG = 4, 16
    for sx in (1, -1):
        cx = sx*e["ex"]; cy = e["ey"] + (e["bu"] - e["bl"])*0.5; ry = (e["bu"] + e["bl"])*0.5*0.92; rx = e["a"]*0.92
        o = len(V)
        p, n = face.at(cx, cy); V.append(p + n*0.0011*s); UV.append((0.25, 0.25))
        for r in range(1, RR + 1):
            for j in range(SEG):
                a = 2*math.pi*j/SEG; f = r/RR
                p, n = face.at(cx + rx*f*math.cos(a), cy + ry*f*math.sin(a))
                V.append(p + n*(0.0004*s + 0.0007*s*(1 - f*f))); UV.append((0.25 + 0.24*f*math.cos(a)*sx, 0.25 + 0.24*f*math.sin(a)))
        for j in range(SEG): F.append((o, o + 1 + j, o + 1 + (j + 1) % SEG))
        for r in range(RR - 1):
            a0 = o + 1 + r*SEG; a1 = a0 + SEG
            for j in range(SEG): F.append((a0 + j, a1 + j, a1 + (j + 1) % SEG, a0 + (j + 1) % SEG))
        # thin rim down to the skin so the lens is a closed shell
        last = o + 1 + (RR - 1)*SEG; ob0 = len(V)
        for j in range(SEG):
            p = V[last + j]; _, n = face.at(cx + rx*math.cos(2*math.pi*j/SEG), cy + ry*math.sin(2*math.pi*j/SEG))
            V.append(p - n*0.0002*s); UV.append(UV[last + j])
        for j in range(SEG): F.append((last + j, ob0 + j, ob0 + (j + 1) % SEG, last + (j + 1) % SEG))
        F.append(tuple(ob0 + j for j in range(SEG - 1, -1, -1)))
    ob = mesh_from("Pop_Eyes", V, F, UV, mat)
    bind(ob, rig, {"head": [(i, 1.0) for i in range(len(V))]})
    return ob

TONGUE = dict(L=(0.022, 0.012, 0.010), width=0.0135, thick=0.0050, tilt=18, out=0.028)
def tongue_frame(face):
    """mouth opening centre on the skin, outward direction d of the tongue (tilted down), lateral axis"""
    m = mouth(face.meta); _, up, lo = mouth_bounds(np.array(0.0), m)
    yc = float(up + lo)*0.5 - 0.1*m["gap"]
    p0, n0 = face.at(0.0, yc)
    U = face.fr.U; upt = (U - n0*U.dot(n0)).normalized()
    t = math.radians(TONGUE["tilt"]); d = (n0*math.cos(t) - upt*math.sin(t)).normalized()
    lat = upt.cross(n0).normalized()
    return p0, n0, d, lat, yc

def add_tongue_bones(rig, face):
    s = face.meta["s"]; p0, n0, d, lat, _ = tongue_frame(face)
    L = [l*s for l in TONGUE["L"]]
    tip = p0 - d*0.004*s                     # rest: the whole tongue behind the skin, tip 4 mm in
    start = tip - d*sum(L)
    bpy.context.view_layer.objects.active = rig
    for o in bpy.context.view_layer.objects: o.select_set(o == rig)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones; mw_inv = rig.matrix_world.inverted()
    prev = eb["head"]; h = start; names = []
    for i, l in enumerate(L):
        b = eb.new(f"tongue_0{i + 1}"); b.head = mw_inv @ h; b.tail = mw_inv @ (h + d*l)
        b.align_roll(mw_inv.to_3x3() @ d.cross(lat))         # local Z = up: +X curls the tip up, Z swings it sideways
        b.parent = prev; b.use_connect = i > 0; b.use_deform = True
        prev = b; h = h + d*l; names.append(b.name)
    bpy.ops.object.mode_set(mode='OBJECT')
    return names, start, d, lat, L

def build_tongue(face, rig, mat, start, d, lat, L):
    s = face.meta["s"]; up = d.cross(lat).normalized()       # thickness direction (roughly up)
    total = sum(L); RINGS, SEG = 14, 10
    V, UV, F, W = [], [], [], []
    for k in range(RINGS + 1):
        t = k/RINGS; z = total*t
        w = TONGUE["width"]*s*0.5*(1 - 0.25*t)*(math.sqrt(max(0.0, 1 - ((t - 0.86)/0.14)**2)) if t > 0.86 else 1.0) + 0.0003*s
        th = TONGUE["thick"]*s*0.5*(1 - 0.45*t) + 0.0002*s
        c = start + d*z
        for j in range(SEG):
            a = 2*math.pi*j/SEG
            ca, sa = math.cos(a), math.sin(a)
            flat = th*sa*(0.75 if sa > 0 else 1.0)            # flatter on top, a little groove in the middle
            V.append(c + lat*(w*ca) + up*(flat - (0.0006*s if sa > 0.7 else 0)))
            UV.append((0.5 + 0.25 + 0.24*ca, 0.5 + 0.48*t))
        # weights: which bone segment (soft over the joints)
        b0 = L[0]; b1 = L[0] + L[1]
        def soft(x, e, wd=0.003*s): return 0.5 + 0.5*max(-1.0, min(1.0, (x - e)/wd))
        a1 = soft(z, b0); a2 = soft(z, b1)
        W.append(((1 - a1), a1*(1 - a2), a2))
    for k in range(RINGS):
        for j in range(SEG):
            a = k*SEG + j; b = k*SEG + (j + 1) % SEG
            F.append((a, b, b + SEG, a + SEG))
    F.append(tuple(range(SEG - 1, -1, -1))); F.append(tuple(RINGS*SEG + j for j in range(SEG)))
    ob = mesh_from("Pop_Tongue", V, F, UV, mat)
    g = {"tongue_01": [], "tongue_02": [], "tongue_03": []}
    for k in range(RINGS + 1):
        for j in range(SEG):
            for bi, bn in enumerate(("tongue_01", "tongue_02", "tongue_03")):
                if W[k][bi] > 1e-3: g[bn].append((k*SEG + j, W[k][bi]))
    bind(ob, rig, g)
    return ob

# ---------------------------------------------------------------- model
def keep_only(objs):
    for o in list(bpy.data.objects):
        if o.type in ('MESH',) and o not in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o, do_unlink=True)

def trim_face_strands(hair, face):
    """the messy hair's strands that hang over the mouth / chin are taken off (the mouth is the point of this ghost)"""
    me = hair.data; fr = face.fr; m = mouth(face.meta); s = face.meta["s"]
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    seen, kill = set(), []
    co = np.array([tuple(hair.matrix_world @ v.co) for v in bm.verts])
    az, h, f = fr.local(co)
    for v in bm.verts:
        if v.index in seen: continue
        st, grp = [v], []; seen.add(v.index)
        while st:
            x = st.pop(); grp.append(x.index)
            for e in x.link_edges:
                y = e.other_vert(x)
                if y.index not in seen: seen.add(y.index); st.append(y)
        g = np.array(grp)
        over = (np.abs(az[g]*face.meta["RF"]) < m["w"]*1.6) & (h[g] < face.meta["base_h"] + 0.004*s) & (f[g] > 0)
        if len(g) < 0.5*len(bm.verts) and over.any(): kill += grp
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in kill], context='VERTS')
    bm.to_mesh(me); bm.free()
    return len(kill)

def shorten_hair(hair, cloth):
    """the messy hair ends above the shoulders (blouse shoulder top + 8 cm; what hangs lower is squeezed up to 25 %),
    so tilting the head or turning it right round never puts hair through the shoulders"""
    bl = next(o for o in cloth if o.name == "Cloth_" + OUTFIT)
    top = max((bl.matrix_world @ v.co).z for v in bl.data.vertices if 0.09 < abs((bl.matrix_world @ v.co).x) < 0.15)
    zc = top + 0.08; inv = hair.matrix_world.inverted()
    for v in hair.data.vertices:
        w = hair.matrix_world @ v.co
        if w.z < zc: w.z = zc - (zc - w.z)*0.25; v.co = inv @ w
    hair.data.update()
    return zc

def relink_images(objs):
    """every texture of the kept pieces copied next to the FBX as Pop_<piece>_<map>.png (so assets/models has all of them)"""
    done = {}
    for o in objs:
        for mat in o.data.materials:
            if not mat or not mat.use_nodes: continue
            for n in mat.node_tree.nodes:
                if n.type != 'TEX_IMAGE' or not n.image: continue
                src = bpy.path.abspath(n.image.filepath)
                if os.path.dirname(os.path.abspath(src)) == os.path.abspath(M): continue
                if src not in done:
                    stem = os.path.splitext(os.path.basename(src))[0]
                    for pre in ("human_female_",): stem = stem.replace(pre, "")
                    dst = os.path.join(M, "Pop_" + stem + ".png")
                    shutil.copyfile(src, dst); done[src] = dst
                n.image.filepath = done[src]; n.image.reload()
    return done

def build_model():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_female", "human_female.blend"))
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    d = json.load(open(os.path.join(M, "human_female", "human_female_uv.json")))
    assert d["loops"] == len(body.data.loops)
    uv = np.array(d["uv"]).reshape(-1, 2); SK["set_uv"](body.data, uv)
    meta = {k: np.float64(v) if isinstance(v, float) else v for k, v in d.items() if k != "uv"}
    face = Face(body, rig, meta)
    log("s", round(float(meta["s"]), 3), "RF", round(float(meta["RF"]), 4), "mouth_h", round(float(meta["mouth_h"]), 4))
    # head weight where the pieces sit
    fr = face.fr; hw = fr.w[:, fr.gi["head"]]
    az, h, f = fr.local(fr.co)
    near = (np.abs(az*meta["RF"]) < 0.04) & (np.abs(h - meta["mouth_h"]) < 0.02) & (f > 0)
    log("head weight at the mouth: min", round(float(hw[near].min()), 3))
    base = make_textures(body, uv, meta); pbase = make_parts_textures()
    skin = SK["skin_material"]("PopSkin", base)
    parts = pieces_mat("PopParts", pbase)
    body.data.materials.clear(); body.data.materials.append(skin)
    # outfit + hair, everything else out
    cloth = [o for o in bpy.data.objects if o.name == "Cloth_" + OUTFIT or o.name.startswith("Cloth_" + OUTFIT + "_")]
    hair = HR["add_hair"](CHAR, [HAIR])[HAIR]                  # rebuilt with the centre parting
    for o in cloth + [hair]: o.hide_set(False); o.hide_viewport = False; o.hide_render = False
    keep_only([body, hair] + cloth)
    log("strand verts cut off the face:", trim_face_strands(hair, face))
    log("hair hem lifted to", round(shorten_hair(hair, cloth), 3))
    # pieces
    names, start, dvec, lat, L = add_tongue_bones(rig, face)
    fangs = build_fangs(face, rig, parts); eyes = build_eyes(face, rig, parts)
    tongue = build_tongue(face, rig, parts, start, dvec, lat, L)
    # skin the outfit hides: shell pieces (as Roblox drops them for humans) + legs inside the sin
    cj = json.load(open(os.path.join(M, "human_female", "human_female_clothes.json")))["outfits"][OUTFIT]
    hid = hidden_faces(body.data, cj)
    sin = next((o for o in cloth if o.name.endswith("_sin")), None)
    if sin:
        st = world_tree(sin); hem = min((sin.matrix_world @ v.co).z for v in sin.data.vertices)
        top = max((sin.matrix_world @ v.co).z for v in sin.data.vertices)
        inside = []
        for v in body.data.vertices:
            p = body.matrix_world @ v.co
            loc, nrm, _, dist = st.find_nearest(p, 0.3)
            inside.append(loc is not None and (p - loc).dot(nrm) < -0.004 and hem + 0.10 < p.z < top - 0.03)
        for pl in body.data.polygons:
            if all(inside[i] for i in pl.vertices): hid.add(pl.index)
    log("skin faces hidden by the outfit:", len(hid), "of", len(body.data.polygons))
    delete_faces(body, sorted(hid))
    # names
    body.name = "Pop"; hair.name = "Pop_Hair"
    for o in cloth:
        o.name = "Pop_" + (o.name[len("Cloth_" + OUTFIT) + 1:].capitalize() if o.name != "Cloth_" + OUTFIT else "Blouse")
    objs = [body, hair, fangs, eyes, tongue] + cloth
    log("images copied:", len(relink_images(objs)))
    # neck / head may twist past the human limits (PossessedSnap)
    for bn_, yl in (("neck", 85), ("head", 85)):
        for c in rig.pose.bones[bn_].constraints:
            if c.type == 'LIMIT_ROTATION': c.min_y, c.max_y = math.radians(-yl), math.radians(yl)
    AN["limit_weights"]()
    for o in objs: log(f"  {o.name:16s} verts {len(o.data.vertices):5d} tris {sum(len(p.vertices) - 2 for p in o.data.polygons):5d}")
    return dict(body=body, rig=rig, hair=hair, cloth=cloth, fangs=fangs, eyes=eyes, tongue=tongue, face=face, meta=meta, objs=objs)

# ---------------------------------------------------------------- stills
def setup_render(res=(600, 600)):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.film_transparent = False
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = w
    w.use_nodes = True; bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.42, 0.43, 0.45, 1); bg.inputs[1].default_value = 0.7
    for n in ("_key", "_fill", "_cam"):
        o = bpy.data.objects.get(n)
        if o: bpy.data.objects.remove(o, do_unlink=True)
    def light(name, rot, energy):
        l = bpy.data.objects.new(name, bpy.data.lights.new(name, 'SUN')); l.data.energy = energy
        l.rotation_euler = rot; sc.collection.objects.link(l)
    light("_key", (math.radians(55), 0, math.radians(-35)), 3.5)
    light("_fill", (math.radians(70), 0, math.radians(60)), 1.2)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    return cam

def shoot(cam, target, direction, dist, path, lens=50, ortho=None):
    sc = bpy.context.scene
    d = Vector(direction).normalized(); tgt = Vector(target)
    cam.location = tgt + d*dist; cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if ortho: cam.data.type = 'ORTHO'; cam.data.ortho_scale = ortho
    else: cam.data.type = 'PERSP'; cam.data.lens = lens
    sc.render.filepath = path; bpy.ops.render.render(write_still=True)

def stills(ctx, tag=""):
    os.makedirs(PREV, exist_ok=True)
    cam = setup_render()
    fr = ctx["face"].fr; C = fr.C
    rig = ctx["rig"]
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.context.view_layer.update()
    mid = Vector((0, 0, 0.85))
    shoot(cam, C - fr.U*0.01, (0, -1, 0.02), 0.55, os.path.join(PREV, f"Pop_face{tag}.png"), lens=85)
    shoot(cam, mid, (0.65, -1, 0.15), 2.9, os.path.join(PREV, f"Pop{tag}.png"), lens=50)
    shoot(cam, mid, (0, -1, 0.05), 2.9, os.path.join(PREV, f"Pop_front{tag}.png"), lens=50)
    shoot(cam, mid, (1, 0, 0.05), 2.9, os.path.join(PREV, f"Pop_side{tag}.png"), lens=50)


# ---------------------------------------------------------------- animation (30 fps, in place, HumanRig + tongue bones)
# Values follow build_anims.py: degrees, left-side convention (.R mirrored), clamped to the joint limits
# (neck / head twist opened to +-85 for PossessedSnap). Tongue: tongue_01 slides out along the tongue (location Y),
# tongue_02 / 03 curl (+X up) and swing (Z) at the mouth opening; how far is cut back per frame until it clears the skin.
sm = AN["sm"]
def pulse(t, t0, up=0.025, down=0.10):
    """twitch: snaps in fast, eases back"""
    return sm(t0, t0 + up, t) - sm(t0 + up + 0.02, t0 + up + 0.02 + down, t)

def claw(P, side, k=1.0, spasm=0.0):
    sd = "." + side
    for f in ("index", "middle", "ring", "pinky"):
        P.rot(f"{f}_01{sd}", (-28 - 25*spasm)*k); P.rot(f"{f}_02{sd}", (-50 - 30*spasm)*k); P.rot(f"{f}_03{sd}", (-38 - 20*spasm)*k)
    P.rot("thumb_01" + sd, -20*k, 0, -15*k); P.rot("thumb_02" + sd, -25*k); P.rot("thumb_03" + sd, -20*k)

def stand(P):
    P.both("thigh", 2, 0, 2); P.both("shin", -4); P.both("foot", 2)

TONGUE_OUT = {"k": 0.0}
def tongue(P, out, curl=0.0, sweep=0.0, curl2=None):
    """out 0..1 (slid out of the mouth), curl / sweep degrees, scaled by TONGUE_OUT['k'] (clearance solver)"""
    k = TONGUE_OUT["k"]; T = TONGUE["out"]*S_HEAD
    P.frame["tongue_01@loc"] = ("loc", Vector((0, T*out, 0)))
    P.rot("tongue_01", 0, 0, 0)
    P.rot("tongue_02", curl*k, 0, sweep*k); P.rot("tongue_03", (curl if curl2 is None else curl2)*k, 0, sweep*0.6*k)

def c_twitch_walk(P, t, st, s):
    """เดินคอเอียงกระตุก: small steps (the sin), hunched, head hanging over the right shoulder; three jerks a loop
    (head, shoulder + clawing right hand, head back the other way)"""
    AN["gait"](P, t, st, s, False, short=0.38)
    ph = 2*math.pi*t
    j1, j2, j3 = pulse(t, 0.18), pulse(t, 0.50, down=0.14), pulse(t, 0.76)
    P.rot("spine", 9 + 4*j2, -4*math.sin(ph), 3); P.rot("chest", 7, -5*math.sin(ph) + 8*j2, 2)
    P.rot("neck", 8 + 4*j1, -12*j1 + 8*j3, 9 + 2*j1 - 8*j3)
    P.rot("head", 6 - 10*j1, 4*math.sin(ph) - 20*j1 + 16*j3, 11 + 3*j1 - 8*j3)
    P.rot("shoulder.R", 3 + 9*j2); P.rot("shoulder.L", -3)
    sw = 9*math.sin(ph)
    AN["arms_down"](P, st, swing_l=-sw*0.6, swing_r=sw*0.4 + 10*j2, bend_l=8, bend_r=28 + 30*j2, out=6)
    P.rot("hand.R", -15 + 30*j2); P.rot("hand.L", -20)
    claw(P, "L", 0.7); claw(P, "R", 1.0, spasm=j2)
    tongue(P, 0.0)

def c_lick_lips(P, t, st, s):
    """เลียปาก: hunched, chin pushed forward, head tilted; the tongue slides out, runs round the lips, back in"""
    ph = 2*math.pi*t
    P.rot("spine", 10, 0, 0.8*math.sin(ph)); P.rot("chest", 8 + 1.0*math.sin(ph*2))
    P.rot("neck", 18, 3*math.sin(ph), 8); P.rot("head", -12, 6*math.sin(ph + 0.6), 12 + 3*math.sin(ph))
    P.both("shoulder", 8)
    AN["arms_down"](P, st, swing_l=4, swing_r=4, bend_l=30 + 4*math.sin(ph), bend_r=34 + 4*math.sin(ph + 1), out=8)
    P.both("hand", -25)
    claw(P, "L", 0.9, spasm=0.5 + 0.5*math.sin(ph*3)); claw(P, "R", 0.9, spasm=0.5 + 0.5*math.sin(ph*3 + 2))
    stand(P)
    out = sm(0.04, 0.16, t) - sm(0.82, 0.94, t)
    u = min(max((t - 0.14)/(0.82 - 0.14), 0.0), 1.0)
    phi = math.pi/2 + 2*math.pi*1.25*u                                    # one and a quarter times round the lips
    w = sm(0.0, 0.08, u)*(1 - sm(0.92, 1.0, u))
    tongue(P, out, curl=w*(55*math.cos(phi) + 25), sweep=w*55*math.sin(phi), curl2=w*(70*math.cos(phi) + 35))

KNOCKS = [0.04, 0.10, 0.16, 0.22, 0.28, 0.52, 0.58, 0.64]               # two rattling bursts a loop
KNOCK_L = {"fwd": 66.0}
KNOCK_R = {"fwd": 62.0}
def c_knock_shutter(P, t, st, s):
    """เคาะแผงรัว: leaning on the zinc shutter, left palm flat on it, right fist hammering, head turned to listen"""
    ph = 2*math.pi*t
    hit = max(math.exp(-((t - k)/0.018)**2) for k in KNOCKS)
    P.rot("spine", 8, 4, 1); P.rot("chest", 6 + 2*hit, 4, 0)
    P.rot("neck", 6, -14, 10); P.rot("head", 4, -18 + 2*math.sin(ph), 12)
    P.both("shoulder", 4); P.rot("shoulder.R", 4 + 5*hit)
    AN["arm"](P, "L", raise_=18, fwd=KNOCK_L["fwd"], bend=8, wrist=60)
    AN["hand"](P, "L", "wong")
    AN["arm"](P, "R", raise_=24 + 3*hit, fwd=KNOCK_R["fwd"] + 6*hit, bend=62 - 34*hit, wrist=-6)
    AN["hand"](P, "R", "fist")
    P.rot("thigh.L", 6, 0, 2); P.rot("shin.L", -10); P.rot("foot.L", 4)
    P.rot("thigh.R", -4, 0, 3); P.rot("shin.R", -6); P.rot("foot.R", 6)
    tongue(P, 0.0)

def c_possessed_snap(P, t, st, s):
    """คอหักหันขวับ 180: stands slack, one small twitch, then the head snaps round to look behind (180 deg, past the
    shoulders) with a little overshoot and tremor, and holds"""
    a = sm(0.30, 0.36, t); over = sm(0.355, 0.38, t) - sm(0.38, 0.48, t)
    trem = 2.5*math.sin(t*150)*sm(0.36, 0.42, t)*(1 - 0.6*sm(0.5, 1.0, t))
    pre = pulse(t, 0.12)
    tw = 180*a + 10*over + trem
    P.rot("spine", 6, 0.11*tw, 0); P.rot("chest", 5, 0.14*tw, 0)
    P.rot("neck", 6 + 6*pre - 4*a, 0.36*tw, 6*pre + 4*a)
    P.rot("head", 8 - 10*pre + 4*a, 0.39*tw, 10*a - 8*pre)
    P.both("shoulder", 2 + 12*over)
    AN["arms_down"](P, st, swing_l=2, swing_r=2, bend_l=10 + 20*over, bend_r=12 + 20*over, out=8)
    claw(P, "L", 0.6 + 0.4*a, spasm=over); claw(P, "R", 0.6 + 0.4*a, spasm=over)
    stand(P)
    tongue(P, 0.0)

POP_CLIPS = {   # name: (fn, frames, plays once)
    "TwitchWalk": (c_twitch_walk, 48, False),
    "LickLips": (c_lick_lips, 96, False),
    "KnockShutter": (c_knock_shutter, 60, False),
    "PossessedSnap": (c_possessed_snap, 72, True),
}

def pose_now(P):
    """apply P.frame to the rig without keying (P.key does the same and clears it)"""
    for p in P.pb: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    for k, (kind, v) in P.frame.items():
        if kind == "rot": P.pb[k].rotation_euler = v
        else: P.pb[k.split("@")[0]].location = v
    bpy.context.view_layer.update()

def posed_verts(ob):
    dg = bpy.context.evaluated_depsgraph_get(); ev = ob.evaluated_get(dg); me = ev.to_mesh()
    mw = ob.matrix_world; co = [mw @ v.co for v in me.vertices]; ev.to_mesh_clear(); return co

class HeadSpace:
    """posed point -> rest point for anything that rides the head bone rigidly (face, fangs)"""
    def __init__(self, ctx):
        self.rig = ctx["rig"]; self.face = ctx["face"]; self.m = mouth(ctx["meta"])
        self.body_tree = world_tree(ctx["body"]); self.fang_tree = world_tree(ctx["fangs"])
    def to_rest(self):
        pb = self.rig.pose.bones["head"]; mw = self.rig.matrix_world
        return (mw @ pb.matrix @ pb.bone.matrix_local.inverted() @ mw.inverted()).inverted()
    def in_opening(self, p, margin):
        az, h, _ = self.face.fr.local(np.array([tuple(p)]))
        x = float(az[0])*self.face.meta["RF"]; y = float(h[0])
        xm, up, lo = mouth_bounds(np.array(x), self.m)
        return float(xm) < 0.97 and float(lo) + margin < y < float(up) - margin
    def tongue_clear(self, verts, need):
        """smallest gap (m) between the tongue and the face / fangs outside the mouth opening"""
        R = self.to_rest(); worst = float("inf"); s = self.face.meta["s"]
        for p in verts:
            q = R @ p
            loc, nrm, _, dist = self.body_tree.find_nearest(q, 0.05)
            if loc is not None:
                sd = dist if (q - loc).dot(nrm) >= 0 else -dist
                if sd < -0.003*s: pass                                      # deep inside: hidden behind the opening
                elif not self.in_opening(q if sd >= 0 else loc, 0.0012*s): worst = min(worst, sd)
            loc, nrm, _, dist = self.fang_tree.find_nearest(q, 0.02)
            if loc is not None: worst = min(worst, dist)
        return worst

def add_pop_anims(ctx, only=None):
    rig = ctx["rig"]; st = AN["STYLE"][CHAR]
    s = (rig.data.bones["head"].tail_local.z - rig.data.bones["hips"].head_local.z)/(1.818 - 0.880)
    P = AN["Poser"](rig); P.raise_max = st.get("raise_max", AN["RAISE_MAX"])
    if not rig.animation_data: rig.animation_data_create()
    for a in list(bpy.data.actions):                                         # the human clips stay in human_female.blend
        if only is None or a.name in only: bpy.data.actions.remove(a)
    hs = HeadSpace(ctx); tongue_ob = ctx["tongue"]; need = 0.0015*ctx["meta"]["s"]
    made = {}; cuts = {}
    for name, (fn, frames, once) in POP_CLIPS.items():
        if only is not None and name not in only: continue
        act = bpy.data.actions.new(name); act.use_fake_user = True
        rig.animation_data.action = act
        for f in range(frames + 1):
            t = f/frames if once else (f % frames)/frames
            TONGUE_OUT["k"] = 1.0
            fn(P, t, st, s)
            if name == "LickLips":
                pose_now(P)
                if hs.tongue_clear(posed_verts(tongue_ob), need) < need:         # cut the curl / swing back until it clears
                    lo_, hi_ = 0.0, 1.0
                    for _ in range(9):
                        TONGUE_OUT["k"] = (lo_ + hi_)/2; fn(P, t, st, s); pose_now(P)
                        if hs.tongue_clear(posed_verts(tongue_ob), need) >= need: lo_ = TONGUE_OUT["k"]
                        else: hi_ = TONGUE_OUT["k"]
                    TONGUE_OUT["k"] = lo_; fn(P, t, st, s)
                    cuts[f] = round(lo_, 2)
            P.key(f + 1)
            rig.pose.bones["tongue_01"].keyframe_insert("location", frame=f + 1, group="tongue_01")
        act.frame_range = (1, frames + 1)
        try: act.use_cyclic = not once
        except AttributeError: pass
        made[name] = frames
    log("tongue swing cut back (frame: factor):", cuts)
    rig.animation_data.action = act
    bpy.context.scene.render.fps = FPS
    return made, s

def fit_knock(ctx):
    """how far forward the right fist and the left palm reach in KnockShutter (world y, front = -y)"""
    rig = ctx["rig"]; body = ctx["body"]
    vg = {g.index: g.name for g in body.vertex_groups}
    def side_verts(side):
        out = []
        for v in body.data.vertices:
            g = max(v.groups, key=lambda g: g.weight, default=None)
            if g and (vg[g.group] == "hand." + side or vg[g.group].endswith("_03." + side) or vg[g.group].endswith("_02." + side)): out.append(v.index)
        return out
    L, Rv = side_verts("L"), side_verts("R")
    act = bpy.data.actions["KnockShutter"]; rig.animation_data.action = act
    def front(ids):
        best = 9
        for f in range(1, int(act.frame_range[1]) + 1):
            bpy.context.scene.frame_set(f); co = posed_verts(body)
            best = min(best, min(co[i].y for i in ids))
        return best
    return front(Rv), front(L)

# ---------------------------------------------------------------- no part through another part: every frame of every clip
def region_of(bone):
    base, _, sd = bone.partition(".")
    if base in ("hips", "spine", "chest", "root"): return "torso"
    if base == "head": return "head"
    if base == "neck": return "neck"
    if base.startswith("tongue"): return "tongue"
    if base == "shoulder": return None
    if base == "upper_arm": return "uarm." + sd
    if base == "forearm": return "farm." + sd
    if base == "hand" or base.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb"): return "hand." + sd
    if base == "thigh": return "thigh." + sd
    if base == "shin": return "shin." + sd
    if base in ("foot", "toe"): return "foot." + sd
    return None

def vregions(ob):
    gn = {g.index: g.name for g in ob.vertex_groups}; out = []
    for v in ob.data.vertices:
        b = max(v.groups, key=lambda g: g.weight, default=None)
        out.append(region_of(gn[b.group]) if b and b.weight > 0.8 else None)
    return out

BODY_PAIRS = [("uarm.L", "torso"), ("uarm.R", "torso"), ("farm.L", "torso"), ("farm.R", "torso"), ("hand.L", "torso"),
              ("hand.R", "torso"), ("hand.L", "head"), ("hand.R", "head"), ("farm.L", "head"), ("farm.R", "head"),
              ("hand.L", "neck"), ("hand.R", "neck"),
              ("hand.L", "hand.R"), ("farm.L", "farm.R"), ("foot.L", "foot.R"), ("shin.L", "shin.R"),
              ("hand.L", "thigh.L"), ("hand.R", "thigh.R"), ("head", "torso"), ("farm.L", "uarm.L"), ("farm.R", "uarm.R"),
              ("hand.L", "uarm.L"), ("hand.R", "uarm.R"), ("hand.L", "farm.R"), ("hand.R", "farm.L")]

class Checker:
    """A's vertices against B's surface. Skin against skin (same mesh, region pieces): squashing at a joint up to
    TOL_SAME is how the human rigs are made (test_self_intersection.py), more counts. Different meshes: a vertex that
    was outside B at rest and goes in, or was inside (under the cloth) and comes out, by more than TOL_X; B's open
    edges don't count (a hand next to the cuff of its own sleeve)."""
    TOL_SAME, TOL_X = 0.015, 0.004
    def __init__(self, ctx):
        self.ctx = ctx; o = {k: ctx[k] for k in ("body", "hair", "fangs", "eyes", "tongue")}
        for c in ctx["cloth"]: o[c.name[4:].lower()] = c
        self.ob = o; self.reg = {k: vregions(v) for k, v in o.items()}
        self.reg["hair"] = ["hair"]*len(o["hair"].data.vertices)
        arms = ["uarm.L", "uarm.R", "farm.L", "farm.R"]; hands = ["hand.L", "hand.R"]
        # (A object, A regions or None = all, B object, B region or None = whole mesh)
        X = []
        for a in hands: X += [("body", [a], "blouse", None), ("body", [a], "sin", None), ("hair", None, "body", a)]
        X += [("blouse", ["farm.L", "hand.L"], "blouse", "torso"), ("blouse", ["farm.R", "hand.R"], "blouse", "torso"),
              ("blouse", arms, "sin", None), ("blouse", ["farm.L"], "blouse", "farm.R"),
              ("hair", None, "body", "neck"), ("hair", None, "body", "torso"), ("hair", None, "blouse", None),
              ("body", ["head"], "blouse", None), ("body", ["shin.L", "shin.R", "foot.L", "foot.R"], "sin", None),
              ("sandals", None, "sin", None), ("sin", None, "body", "shin.L"), ("sin", None, "body", "shin.R"),
              ("body", ["head"], "body", "torso")]
        # hair, fangs and eye lenses ride the head bone 100 %: they cannot move against each other or the face
        # (the pieces sit 0.4 mm off the skin). The tongue against them: plain gap, see GAP
        self.GAP = [("tongue", "fangs"), ("tongue", "hair"), ("tongue", "eyes")]
        self.X = [x for x in X if x[0] in o and x[2] in o]
        self.rest = {}; self._bd = {}
    def boundary(self, k):
        if k not in self._bd:
            me = self.ob[k].data; cnt = {}
            for p in me.polygons:
                for e in p.edge_keys: cnt[e] = cnt.get(e, 0) + 1
            self._bd[k] = {p.index for p in me.polygons if any(cnt[e] == 1 for e in p.edge_keys)}
        return self._bd[k]
    def trees(self, co):
        T = {}
        for k, ob in self.ob.items():
            polys = [tuple(p.vertices) for p in ob.data.polygons]
            T[(k, None)] = (BVHTree.FromPolygons(co[k], polys), list(range(len(polys))))
            byr = {}
            for i, p in enumerate(ob.data.polygons):
                rs = {self.reg[k][v] for v in p.vertices}
                if len(rs) == 1 and None not in rs: byr.setdefault(rs.pop(), []).append(i)
            for r, fs in byr.items():
                T[(k, r)] = (BVHTree.FromPolygons(co[k], [polys[i] for i in fs]), fs)
        return T
    def sample(self):
        bpy.context.view_layer.update()
        co = {k: posed_verts(ob) for k, ob in self.ob.items()}
        return co, self.trees(co)
    @staticmethod
    def signed(T, key, p, R=0.06):
        tr, fs = T[key]; loc, nrm, idx, dist = tr.find_nearest(p, R)
        if loc is None: return None, None
        return (dist if (p - loc).dot(nrm) >= 0 else -dist), fs[idx]
    def set_rest(self):
        rig = self.ctx["rig"]; act = rig.animation_data.action; rig.animation_data.action = None
        for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
        co, T = self.sample()
        for xi, (a, ar, b, br) in enumerate(self.X):
            if (b, br) not in T: continue
            for i, r in enumerate(self.reg[a]):
                if ar is not None and r not in ar: continue
                self.rest[(xi, i)] = self.signed(T, (b, br), co[a][i])[0]
        rig.animation_data.action = act
    def check(self):
        co, T = self.sample(); hits = []
        reg = self.reg["body"]
        for ra, rb in BODY_PAIRS:                                             # skin against skin
            if ("body", ra) not in T or ("body", rb) not in T: continue
            worst = 0.0
            for r1, r2 in ((ra, rb), (rb, ra)):
                tr = T[("body", r2)][0]
                for i, r in enumerate(reg):
                    if r != r1: continue
                    loc, nrm, _, dist = tr.find_nearest(co["body"][i], 0.06)
                    if loc is not None and (co["body"][i] - loc).dot(nrm) < 0: worst = max(worst, dist)
            if worst > self.TOL_SAME: hits.append(f"body {ra}x{rb} {worst*100:.1f}cm")
        for xi, (a, ar, b, br) in enumerate(self.X):
            if (b, br) not in T: continue
            bd = self.boundary(b); worst = 0.0
            for i, r in enumerate(self.reg[a]):
                if ar is not None and r not in ar: continue
                sd, f = self.signed(T, (b, br), co[a][i])
                if sd is None or f in bd: continue
                s0 = self.rest.get((xi, i))
                if s0 is not None and s0 < 0:
                    if sd > self.TOL_X: worst = max(worst, sd)                # came out from under
                elif sd < -self.TOL_X: worst = max(worst, -sd)                # went in
            if worst > 0: hits.append(f"{a}{'' if ar is None else ar}>{b}{'' if br is None else '.' + br} {worst*100:.1f}cm")
        for a, b in self.GAP:                                                # thin pieces: plain distance, no inside / outside
            tr = T[(b, None)][0]; g = 1.0
            for p in co[a]:
                r = tr.find_nearest(p, 0.01)
                if r[0] is not None: g = min(g, r[3])
            if g < 0.0008: hits.append(f"{a}~{b} gap {g*1000:.1f}mm")
        return hits

def tongue_crossings(ctx, hs):
    """the tongue may only pass through the skin inside the painted mouth opening"""
    co = posed_verts(ctx["tongue"]); R = hs.to_rest(); s = ctx["meta"]["s"]
    bad = 0
    for e in ctx["tongue"].data.edges:
        a, b = R @ co[e.vertices[0]], R @ co[e.vertices[1]]
        d = b - a; L = d.length
        if L < 1e-9: continue
        loc, _, _, _ = hs.body_tree.ray_cast(a, d/L, L)
        if loc is not None and not hs.in_opening(loc, 0.0004*s): bad += 1
    return bad

def check_all(ctx):
    ck = Checker(ctx); ck.set_rest(); hs = HeadSpace(ctx)
    rig = ctx["rig"]; out = {}
    act = rig.animation_data.action; rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    rest_hits = ck.check(); log("rest pose:", "OK" if not rest_hits else rest_hits)
    for clip in POP_CLIPS:
        act = bpy.data.actions[clip]; rig.animation_data.action = act
        f0, f1 = (int(x) for x in act.frame_range); bad = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            h = ck.check()
            tc = tongue_crossings(ctx, hs)
            if tc: h.append(f"tongue crosses the skin outside the mouth x{tc}")
            if h: bad.append((f, h))
        out[clip] = bad
        log(f"clip {clip} frames {f0}-{f1}: {len(bad)} frame(s) with something through something")
        for f, h in bad[:14]: log(f"   {f}: " + "; ".join(h))
    return out

# ---------------------------------------------------------------- contact sheets (front + side, keyframes) and export
def render_arr(path):
    bpy.context.scene.render.filepath = path; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(path); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4); bpy.data.images.remove(im); os.remove(path); return arr

def contact_sheet(ctx, clip, path, n=8, close=False, frames=None):
    """top row front, bottom row side (from the character's left)"""
    sc = bpy.context.scene; rig = ctx["rig"]; act = bpy.data.actions[clip]; rig.animation_data.action = act
    cam = setup_render((240, 380) if not close else (280, 280))
    f0, f1 = (int(x) for x in act.frame_range)
    frames = frames or sorted({int(round(f0 + (f1 - f0)*k/(n - 1))) for k in range(n)})
    rows = []
    for view in (((0, -1, 0.04), (1, 0, 0.04)) if not close else ((0, -1, 0.04), (0.8, -1, 0.1))):
        row = []
        for f in frames:
            sc.frame_set(f)
            if close:
                pb = rig.pose.bones["head"]; mw = rig.matrix_world
                tgt = mw @ (pb.head + (pb.tail - pb.head)*0.35)
                cam.data.type = 'ORTHO'; cam.data.ortho_scale = 0.36
            else:
                tgt = Vector((0, 0, 0.86)); cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.0
            d = Vector(view).normalized(); cam.location = tgt + d*3; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
            row.append(render_arr(path[:-4] + "_t.png"))
        rows.append(np.concatenate(row, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    log(f"sheet {os.path.basename(path)} frames {frames}")
    return frames

def export(ctx):
    rig = ctx["rig"]; objs = ctx["objs"]
    for o in bpy.data.objects: o.select_set(False)
    for o in objs + [rig]: o.hide_set(False); o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    act = rig.animation_data.action; rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    AN["fbx"](os.path.join(M, "Pop.fbx"), use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=AN["STUDS_PER_M"],
              apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
              add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
              mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    for clip in POP_CLIPS: AN["export_clip"](os.path.join(M, f"Pop_{clip}.fbx"), clip)
    AN["CLIPS"] = {c: None for c in POP_CLIPS}; AN["KEEP_TRACKS"] = {}
    AN["export_clip_data"](CHAR, os.path.join(M, "Pop_Anims.json"))
    rig.animation_data.action = act

def main():
    global S_HEAD
    args = sys.argv[sys.argv.index("--") + 2:] if "--" in sys.argv else []
    ctx = build_model(); S_HEAD = float(ctx["meta"]["s"])
    stills(ctx)
    made, s = add_pop_anims(ctx); log("clips:", made)
    best = None
    for rf in (28, 34, 40, 46, 52):                                          # the fist hits where the left palm rests
        KNOCK_R["fwd"] = rf; add_pop_anims(ctx, only={"KnockShutter"}); plane, lpl = fit_knock(ctx)
        log(f"   right fwd {rf}: fist {plane:.3f} palm {lpl:.3f}")
        if best is None or abs(lpl - plane) < best[0]: best = (abs(lpl - plane), rf)
    KNOCK_R["fwd"] = best[1]; add_pop_anims(ctx, only={"KnockShutter"}); plane, lpl = fit_knock(ctx)
    log(f"KnockShutter: fist reaches y = {plane:.3f} m (the shutter, in front of the root), left palm {lpl:.3f}, right arm fwd {KNOCK_R['fwd']:.1f}")
    check_all(ctx)
    if "nosheets" not in args:
        for clip in POP_CLIPS:
            contact_sheet(ctx, clip, os.path.join(PREV, f"Pop_{clip}.png"))
        contact_sheet(ctx, "LickLips", os.path.join(PREV, "Pop_LickLips_face.png"), close=True,
                      frames=[1, 10, 20, 32, 44, 56, 68, 80, 90])
        contact_sheet(ctx, "PossessedSnap", os.path.join(PREV, "Pop_PossessedSnap_face.png"), close=True,
                      frames=[1, 20, 23, 25, 27, 30, 40, 73])
    export(ctx)
    ctx["rig"].animation_data.action = bpy.data.actions["TwitchWalk"]
    for n in ("_key", "_fill", "_cam"):
        o = bpy.data.objects.get(n)
        if o: bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(M, "pop.blend"), relative_remap=True)

S_HEAD = 1.0
if __name__ == "__main__":
    OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(M, "pop_log.txt")
    try:
        main()
    except Exception:
        LOG.append(traceback.format_exc())
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG)); open(OUT + ".done", "w").write("x")
