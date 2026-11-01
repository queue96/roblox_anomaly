# Hairstyles for the low-poly humans, built from the head they sit on.
# Every style is measured off the character's own scalp (rays from the head centre),
# so the same numbers fit child / adult / elder heads and thin / fat faces.
#
#   exec(open(r"...\human_base\build_hair.py", encoding="utf-8").read())
#   add_hair("female")            # current scene: adds Hair_<style> objects bound to the head bone
#   hair_all()                    # opens all 16 .blend files, adds hair, saves
#   preview_all()                 # renders hair_previews/<char>.png (front, 3/4, side, back per style)
#
# Shapes:
#   shell(...)  a cap that follows the scalp out to a hairline, optionally hanging straight down
#               (gravity) to a hem height, then folds back underneath and tucks into the scalp
#   tube(...)   tapered tube along points (ponytail, locks, mustache, bands)
#   ball(...)   squashed sphere (bun, bow lobe, braid bead)
# Angles: th = azimuth around the head (0 = face, +90 = character's left, 180 = back of head),
#         ph = elevation from the head centre (+90 = crown). Lengths are x head size (s = 1 for the adult man).
import bpy, bmesh, math, os, glob
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
DIRS = {"human_base": "male", "human_female": "female", "human_child": "child",
        "human_elder_male": "elder_male", "human_elder_female": "elder_female"}
R = math.radians

COLORS = {
    "HairBlack": (0.018, 0.016, 0.015), "HairGrey": (0.42, 0.41, 0.40), "HairWhite": (0.80, 0.79, 0.76),
    "HairScalp": (0.30, 0.31, 0.33), "HairGold": (0.85, 0.62, 0.16), "RibbonWhite": (0.92, 0.92, 0.90),
}

def mat(name):
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name); c = COLORS[name]
        m.diffuse_color = (*c, 1.0); m.roughness = 0.6 if name.startswith("Hair") else 0.5
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*c, 1.0); bsdf.inputs["Roughness"].default_value = m.roughness
    return m

def key(x, pts):
    """smooth piecewise curve through (x, value) pairs"""
    if x <= pts[0][0]: return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x <= x1:
            f = (x - x0)/(x1 - x0); f = f*f*(3 - 2*f)
            return y0 + (y1 - y0)*f
    return pts[-1][1]

def sym(pts):
    """key on |azimuth| in degrees (left/right mirror)"""
    return lambda th: key(abs(math.degrees(math.atan2(math.sin(th), math.cos(th)))), pts)

# ---------- head frame ----------
class Head:
    def __init__(self, body, rig):
        bm = bmesh.new(); bm.from_mesh(body.data); bm.transform(body.matrix_world)
        bm.faces.ensure_lookup_table()
        seen, isl = set(), []
        for f in bm.faces:
            if f.index in seen: continue
            st, grp = [f], set(); seen.add(f.index)
            while st:
                x = st.pop(); grp.add(x.index)
                for e in x.edges:
                    for y in e.link_faces:
                        if y.index not in seen: seen.add(y.index); st.append(y)
            isl.append(grp)
        skin = max(isl, key=len)
        sk = bm.copy(); sk.faces.ensure_lookup_table()
        bmesh.ops.delete(sk, geom=[f for f in sk.faces if f.index not in skin], context='FACES')
        self.skin = BVHTree.FromBMesh(sk); self.all = BVHTree.FromBMesh(bm)
        dl = bm.verts.layers.deform.active; gi = body.vertex_groups["head"].index
        skin_v = {v for i in skin for v in bm.faces[i].verts}
        pts = [v.co.copy() for v in skin_v if v[dl].get(gi, 0.0) > 0.99]
        lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
        self.C = (lo + hi)/2
        hb = rig.data.bones["head"]; mw = rig.matrix_world
        self.U = (mw @ hb.tail_local - mw @ hb.head_local).normalized()
        F = Vector((0, -1, 0)); self.F = (F - self.U*F.dot(self.U)).normalized()
        self.L = self.U.cross(self.F).normalized()          # +X, the character's left
        self.s = (hi.z - lo.z)/0.235
        sk.free(); bm.free()
        # outward normals? (scripts recalc them, but don't trust it)
        loc, nrm, _, _ = self.all.find_nearest(self.C + self.U)
        self.flip = -1.0 if (self.C + self.U - loc).dot(nrm) < 0 else 1.0
        self.top = self.scalp(self.U)

    def dir(self, th, ph):
        hz = self.F*math.cos(th) + self.L*math.sin(th)
        return (hz*math.cos(ph) + self.U*math.sin(ph)).normalized()

    def horiz(self, th):
        d = self.F*math.cos(th) + self.L*math.sin(th); d.z = 0
        return d.normalized()

    def scalp(self, d):
        hit = self.skin.ray_cast(self.C, d, 1.0)[0]
        return (hit - self.C).length if hit else 0.08*self.s

    def on(self, th, ph, off=0.0):
        d = self.dir(th, ph); return self.C + d*(self.scalp(d) + off*self.s)

    def push(self, p, clear=0.003):
        loc, nrm, _, _ = self.all.find_nearest(p)
        if loc is None: return p
        nrm = nrm*self.flip; side = (p - loc).dot(nrm)
        return p + nrm*(clear - side) if side < clear else p

# ---------- primitives (all write into one bmesh, faces tagged with material slot) ----------
class Build:
    def __init__(self, head, mats):
        self.h = head; self.bm = bmesh.new(); self.mats = mats

    def _tag(self, before, m):
        for f in self.bm.faces:
            if f not in before: f.material_index = m

    def shell(self, thetas, closed, ph_top, ph_bot, thick, hem=None, flare=0.0, tip=None, rows=7, drop_rows=4, m=0, tuck=0.006, clear=0.004, jitter=0.0):
        """cap over the scalp; hem(th) = height (x s, relative to head centre) the hair hangs down to, None = no drop"""
        h, s = self.h, self.h.s; before = set(self.bm.faces); cols = []
        for th in thetas:
            pt, pb = ph_top(th), ph_bot(th)
            out = []
            for i in range(rows + 1):
                ph = pt + (pb - pt)*i/rows
                d = h.dir(th, ph); out.append(h.push(h.C + d*(h.scalp(d) + thick(th, ph)*s), 0.002))
            P0 = out[-1]; t0 = max(thick(th, pb), 0.004)*s; hz = h.horiz(th)
            z_hem = h.C.z + (hem(th) + jitter*noise.noise(Vector((math.cos(th), math.sin(th), 0))*3.0))*s if hem else P0.z
            L = max(P0.z - z_hem, 0.004*s)
            fl = flare(th) if callable(flare) else flare
            tt = (tip(th) if callable(tip) else tip) if tip is not None else thick(th, pb)
            tt = max(tt, 0.004)*s
            drop = []
            for k in range(1, drop_rows + 1):
                f = k/drop_rows
                drop.append(P0 + Vector((0, 0, -L*f)) + hz*fl*s*math.sin(f*math.pi/2))
            drop = [h.push(p, clear*s) for p in drop]
            for _ in range(3):                              # relax + re-push: no zigzag where it rests on the body
                drop = [drop[k] if k in (0, drop_rows - 1) else (drop[k - 1] + drop[k]*2 + drop[k + 1])/4 for k in range(drop_rows)]
                drop = [h.push(p, clear*s) for p in drop]
            inner = []
            for k in range(drop_rows, -1, -1):
                p = drop[k - 1] if k else P0
                w = t0 + (tt - t0)*(k/drop_rows)
                inner.append(h.push(p - hz*w, clear*s*0.7))
            d = h.dir(th, pb); inner.append(h.C + d*(h.scalp(d) - tuck))
            cols.append([self.bm.verts.new(p) for p in out + drop + inner])
        n = len(cols)
        for j in range(n if closed else n - 1):
            a, b = cols[j], cols[(j + 1) % n]
            for i in range(len(a) - 1):
                self.bm.faces.new((a[i], b[i], b[i + 1], a[i + 1]))
        self._tag(before, m)

    def tube(self, pts, radii, sides=8, m=0, closed=False, flat=1.0):
        before = set(self.bm.faces)
        n = len(pts); t0 = (pts[1] - pts[0]).normalized()
        nv = (Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0)))
        nv = (nv - t0*nv.dot(t0)).normalized()
        rings = []
        for i, p in enumerate(pts):
            a = pts[(i - 1) % n] if (closed or i) else pts[0]; b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[-1]
            t = (b - a).normalized(); nv = (nv - t*nv.dot(t)).normalized(); bv = t.cross(nv)
            r = radii[i]
            if r < 1e-5: rings.append([self.bm.verts.new(p)]); continue
            rings.append([self.bm.verts.new(p + (nv*math.cos(a_)*flat + bv*math.sin(a_))*r)
                          for a_ in (2*math.pi*k/sides for k in range(sides))])
        def bridge(A, B):
            if len(A) == 1 and len(B) == 1: return
            if len(A) == 1:
                for k in range(sides): self.bm.faces.new((A[0], B[k], B[(k + 1) % sides]))
            elif len(B) == 1:
                for k in range(sides): self.bm.faces.new((A[k], A[(k + 1) % sides], B[0]))
            else:
                for k in range(sides): self.bm.faces.new((A[k], A[(k + 1) % sides], B[(k + 1) % sides], B[k]))
        for i in range(n if closed else n - 1): bridge(rings[i], rings[(i + 1) % n])
        if not closed:
            for ring in (rings[0], rings[-1]):
                if len(ring) > 2: self.bm.faces.new(ring)
        self._tag(before, m)

    def ball(self, c, r, m=0, scale=(1, 1, 1), rot=Matrix.Identity(3), seg=(10, 6), lumpy=0.0):
        before = set(self.bm.faces)
        mx = Matrix.Translation(c) @ rot.to_4x4() @ Matrix.Diagonal((*scale, 1))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg[0], v_segments=seg[1], radius=r, matrix=mx)
        if lumpy:
            for v in res["verts"]:
                v.co += (v.co - c).normalized()*r*lumpy*noise.noise(v.co*60)
        self._tag(before, m)

    def ring(self, c, axis, r, thick, m=0, sides=12):
        axis = axis.normalized(); a = axis.orthogonal().normalized(); b = axis.cross(a)
        pts = [c + (a*math.cos(t) + b*math.sin(t))*r for t in (2*math.pi*k/sides for k in range(sides))]
        self.tube(pts, [thick]*sides, sides=6, m=m, closed=True)

    def finish(self, name, rig):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        for p in me.polygons: p.use_smooth = True
        for mn in self.mats: me.materials.append(mat(mn))
        ob = bpy.data.objects.new(name, me)
        coll = bpy.data.collections.get("Hair") or bpy.data.collections.new("Hair")
        if coll.name not in bpy.context.scene.collection.children: bpy.context.scene.collection.children.link(coll)
        coll.objects.link(ob)
        ob.parent = rig; ob.matrix_parent_inverse = rig.matrix_world.inverted()
        ob.vertex_groups.new(name="head").add(range(len(me.vertices)), 1.0, 'REPLACE')
        ob.modifiers.new("Armature", 'ARMATURE').object = rig
        return ob

AZ = [R(a) for a in range(0, 360, 15)]                       # closed loop around the head
def arc(a0, a1, step=15):                                   # open band, degrees
    n = max(2, round(abs(a1 - a0)/step)); return [R(a0 + (a1 - a0)*k/n) for k in range(n + 1)]
POLE = lambda th: R(90)

# hairlines (degrees on |azimuth|): forehead, temple, sideburn in front of the ear, over the ear, behind it, nape
HAIRLINE = sym([(0, R(42)), (35, R(36)), (60, R(14)), (75, R(2)), (95, R(14)), (120, R(-6)), (150, R(-26)), (180, R(-34))])
HAIRLINE_HIGH = sym([(0, R(44)), (35, R(38)), (60, R(20)), (75, R(10)), (95, R(20)), (120, R(2)), (150, R(-18)), (180, R(-26))])

def fade(top, side, lo=R(18), hi=R(52)):
    """thickness: `side` low on the head, `top` on the crown (short men's cuts)"""
    return lambda th, ph: side + (top - side)*key(ph, [(lo, 0.0), (hi, 1.0)])

# ---------- styles ----------
def st_student(b):                                          # ทรงนักเรียน: short top, clipped sides
    b.shell(AZ, True, POLE, HAIRLINE, fade(0.014, 0.006))

def st_rong_song_sung(b):                                   # รองทรงสูง: volume on top, sides almost shaved, small quiff
    t = fade(0.024, 0.006, R(30), R(58))
    b.shell(AZ, True, POLE, HAIRLINE_HIGH, lambda th, ph: t(th, ph) + 0.008*key(abs(math.cos(th/2)), [(0.85, 0), (1, 1)])*key(ph, [(R(30), 0), (R(50), 1)]))

def st_side_part(b):                                        # รองทรงต่ำ / ปัดข้าง: parting on the left, swept volume to the right
    t = fade(0.024, 0.007, R(10), R(45))
    def th_(th, ph):
        part = math.exp(-((math.degrees(th) - 38) / 14)**2) if 0 < math.degrees(th) < 90 else 0.0
        sweep = 0.006*key(-math.sin(th), [(0, 0), (1, 1)])
        return t(th, ph)*(1 - 0.6*part*key(ph, [(R(25), 0), (R(45), 1)])) + sweep*key(ph, [(R(20), 0), (R(45), 1)])
    b.shell(AZ, True, POLE, HAIRLINE, th_, hem=sym([(0, 0.06), (30, 1)]), flare=0.004, rows=8, drop_rows=2)

def st_bob(b):                                              # ผมบ็อบ: centre part, chin-length straight hem, covers the ears
    b.shell(AZ, True, POLE, sym([(0, R(44)), (30, R(38)), (60, R(26)), (100, R(10)), (140, R(-10)), (180, R(-20))]),
            fade(0.018, 0.012, R(0), R(60)), hem=sym([(0, 1.0), (38, 1.0), (62, -0.075), (180, -0.085)]),
            flare=sym([(0, 0.0), (60, 0.010), (120, 0.016), (180, 0.012)]), tip=0.010, drop_rows=5)

def st_ponytail_bow(b):                                     # หางม้าผูกโบว์ขาว
    h, s = b.h, b.h.s
    b.shell(AZ, True, POLE, HAIRLINE, fade(0.011, 0.007, R(0), R(60)))
    tie = h.on(R(180), R(8), 0.012)
    back = -h.F; down = Vector((0, 0, -1))
    pts = [tie + back*0.004*s, tie + back*0.030*s + down*0.020*s, tie + back*0.045*s + down*0.090*s,
           tie + back*0.040*s + down*0.170*s, tie + back*0.028*s + down*0.250*s, tie + back*0.018*s + down*0.300*s]
    b.tube(pts, [0.024*s, 0.030*s, 0.030*s, 0.024*s, 0.014*s, 0.0], sides=10)
    b.ring(tie + back*0.010*s, back, 0.022*s, 0.005*s, m=1)
    bc = tie + back*0.022*s + h.U*0.012*s
    for sx in (1, -1):                                      # two lobes, two tails
        lobe = bc + h.L*sx*0.042*s + h.U*0.010*s
        b.ball(lobe, 0.030*s, m=1, scale=(1.4, 0.45, 0.9), rot=Matrix.Rotation(R(-15)*sx, 3, back))
        b.tube([bc, bc + h.L*sx*0.020*s + down*0.045*s, bc + h.L*sx*0.030*s + down*0.085*s], [0.012*s, 0.011*s, 0.010*s], sides=4, m=1, flat=0.3)
    b.ball(bc, 0.014*s, m=1, scale=(1, 0.8, 1))

def _shaved(b):                                             # child: shaved scalp shows grey under the topknot styles
    b.shell(AZ, True, POLE, HAIRLINE, lambda th, ph: 0.008, m=2)

def st_juk(b):                                              # ผมจุก: bun on the crown with a gold band
    h, s = b.h, b.h.s; _shaved(b)
    top = h.C + h.U*h.top
    b.ball(top + h.U*0.042*s, 0.046*s, scale=(1, 1, 0.85), seg=(12, 8))
    b.tube([top - h.U*0.004*s, top + h.U*0.016*s], [0.030*s, 0.034*s], sides=12)
    b.ring(top + h.U*0.012*s, h.U, 0.034*s, 0.007*s, m=1)

def st_klae(b):                                             # ผมแกละ: a tied lock on the left side that swings out and curls
    h, s = b.h, b.h.s; _shaved(b)
    root = h.on(R(105), R(40), 0.0); out = h.horiz(R(105))
    b.ball(root + out*0.010*s, 0.016*s)
    b.ring(root + out*0.020*s, out, 0.012*s, 0.004*s, m=1)
    up = h.U
    pts = [root + out*0.020*s, root + out*0.040*s + up*0.012*s, root + out*0.062*s + up*0.004*s,
           root + out*0.072*s - up*0.030*s, root + out*0.062*s - up*0.062*s, root + out*0.040*s - up*0.072*s]
    b.tube(pts, [0.012*s, 0.016*s, 0.017*s, 0.014*s, 0.009*s, 0.0], sides=8)

def st_pia(b):                                              # ผมเปีย: braid of beads from the crown, out the back
    h, s = b.h, b.h.s; _shaved(b)
    root = h.on(R(180), R(60), 0.0); back = -h.F
    b.ball(root, 0.017*s)
    for k in range(8):
        f = (k + 1)/8
        c = root + back*(0.020 + 0.090*f)*s + h.U*(0.040*math.sin(f*math.pi*0.9) - 0.02*f)*s
        b.ball(c, (0.015 - 0.006*f)*s, scale=(1, 1.2, 1), seg=(8, 5))
    b.ring(root + back*0.012*s, back + h.U*0.3, 0.012*s, 0.004*s, m=1)

def st_ko(b):                                               # ผมโก๊ะ: forelock tied with a gold band, flicks up and back
    h, s = b.h, b.h.s; _shaved(b)
    root = h.on(0, R(62), 0.0); up = h.U; back = -h.F
    b.ring(root + up*0.012*s, up + back*0.2, 0.014*s, 0.005*s, m=1)
    pts = [root, root + up*0.030*s, root + up*0.055*s + back*0.015*s, root + up*0.060*s + back*0.045*s,
           root + up*0.045*s + back*0.070*s, root + up*0.025*s + back*0.075*s]
    b.tube(pts, [0.016*s, 0.016*s, 0.018*s, 0.015*s, 0.009*s, 0.0], sides=8)

def st_child_short(b):                                      # modern short cut, little fringe
    b.shell(AZ, True, POLE, sym([(0, R(40)), (35, R(34)), (62, R(8)), (72, R(-4)), (82, R(14)), (100, R(16)), (118, R(-10)), (180, R(-34))]),
            fade(0.016, 0.008, R(0), R(50)), hem=sym([(0, 0.05), (30, 1)]), flare=0.006, drop_rows=2)

def st_curly_grey(b):                                       # หญิงชรา: grey, curly, shoulder-length, lots of volume
    h = b.h
    lump = lambda th, ph: 0.018*noise.noise(h.dir(th, ph)*9.0)
    b.shell(AZ, True, POLE, sym([(0, R(40)), (30, R(34)), (60, R(20)), (100, R(6)), (180, R(-15))]),
            lambda th, ph: 0.030 + lump(th, ph), hem=sym([(0, 1.0), (40, 0.04), (75, -0.08), (180, -0.13)]),
            flare=sym([(0, 0.0), (60, 0.030), (180, 0.025)]), tip=0.028, rows=8, drop_rows=5, jitter=0.03)

def st_bun_grey(b):                                         # หญิงชรา: combed back into a low bun
    h, s = b.h, b.h.s
    b.shell(AZ, True, POLE, HAIRLINE, fade(0.010, 0.008, R(0), R(60)))
    c = h.on(R(180), R(5), 0.030)
    b.ball(c, 0.036*s, scale=(1.15, 0.85, 1.0), seg=(12, 8), lumpy=0.15)

def st_long_white_beard(b):                                 # ชายชรา: long white hair, full beard, mustache, bushy brows
    h, s = b.h, b.h.s
    b.shell(AZ, True, POLE, sym([(0, R(46)), (35, R(36)), (62, R(14)), (100, R(10)), (180, R(-20))]),
            lambda th, ph: 0.014 + 0.006*noise.noise(h.dir(th, ph)*7.0),
            hem=sym([(0, 1.0), (45, 1.0), (75, -0.15), (180, -0.20)]), flare=sym([(0, 0), (70, 0.012), (180, 0.02)]),
            tip=0.010, rows=8, drop_rows=6)
    # beard: band over the lower face from sideburn to sideburn, hanging onto the chest
    b.shell(arc(-105, 105), False, sym([(0, R(-26)), (25, R(-22)), (55, R(-8)), (85, R(2)), (105, R(6))]),
            sym([(0, R(-70)), (60, R(-60)), (105, R(-35))]),
            lambda th, ph: 0.016*key(abs(th), [(R(80), 1), (R(105), 0.2)]) + 0.004*noise.noise(h.dir(th, ph)*8.0),
            hem=sym([(0, -0.30), (30, -0.26), (60, -0.16), (90, -0.08), (105, -0.04)]),
            flare=sym([(0, 0.020), (60, 0.012), (105, 0.0)]), tip=0.012, rows=5, drop_rows=5)
    for sx in (1, -1):                                      # mustache drooping into the beard
        pts = [h.on(R(4)*sx, R(-13), 0.008), h.on(R(18)*sx, R(-14), 0.010), h.on(R(30)*sx, R(-22), 0.010), h.on(R(34)*sx, R(-34), 0.010)]
        b.tube(pts, [0.008*s, 0.010*s, 0.008*s, 0.0], sides=6)
        pts = [h.on(R(9)*sx, R(23), 0.008), h.on(R(22)*sx, R(25), 0.010), h.on(R(36)*sx, R(21), 0.008)]
        b.tube(pts, [0.006*s, 0.007*s, 0.0], sides=5, flat=0.6)

def st_bald_grey(b):                                        # ชายชรา: bald crown, short grey horseshoe
    b.shell(arc(55, 305), False, sym([(55, R(10)), (90, R(30)), (180, R(36))]), HAIRLINE,
            lambda th, ph: 0.009*key(abs(math.degrees(math.atan2(math.sin(th), math.cos(th)))), [(55, 0.2), (75, 1.0)]))

def st_ghost_long(b):                                       # ผีผมยาว: straight hair to the chest, hanging over the face
    b.shell(AZ, True, POLE, sym([(0, R(44)), (35, R(36)), (70, R(10)), (180, R(-20))]),
            fade(0.016, 0.012, R(0), R(60)), hem=sym([(0, -0.42), (40, -0.48), (90, -0.58), (180, -0.66)]),
            flare=sym([(0, 0.035), (90, 0.03), (180, 0.02)]), tip=0.012, rows=8, drop_rows=18, clear=0.014, jitter=0.04)

STYLES = {
    "student": (st_student, ["HairBlack"]), "rong_song_sung": (st_rong_song_sung, ["HairBlack"]),
    "side_part": (st_side_part, ["HairBlack"]), "bob": (st_bob, ["HairBlack"]),
    "ponytail_bow": (st_ponytail_bow, ["HairBlack", "RibbonWhite"]),
    "juk": (st_juk, ["HairBlack", "HairGold", "HairScalp"]), "klae": (st_klae, ["HairBlack", "HairGold", "HairScalp"]),
    "pia": (st_pia, ["HairBlack", "HairGold", "HairScalp"]), "ko": (st_ko, ["HairBlack", "HairGold", "HairScalp"]),
    "child_short": (st_child_short, ["HairBlack"]),
    "curly_grey": (st_curly_grey, ["HairGrey"]), "bun_grey": (st_bun_grey, ["HairGrey"]),
    "long_white_beard": (st_long_white_beard, ["HairWhite"]), "bald_grey": (st_bald_grey, ["HairGrey"]),
    "ghost_long": (st_ghost_long, ["HairBlack"]), "ghost_long_white": (st_ghost_long, ["HairWhite"]),
}
# first style = the one left visible
CHAR_STYLES = {
    "male": ["student", "rong_song_sung", "side_part"],
    "female": ["bob", "ponytail_bow", "ghost_long"],
    "child": ["juk", "klae", "pia", "ko", "child_short"],
    "elder_male": ["long_white_beard", "bald_grey"],
    "elder_female": ["curly_grey", "bun_grey", "ghost_long_white"],
}

def clear_hair():
    for o in list(bpy.data.objects):
        if o.name.startswith("Hair"): me = o.data; bpy.data.objects.remove(o, do_unlink=True); bpy.data.meshes.remove(me)
    c = bpy.data.collections.get("Hair")
    if c: bpy.data.collections.remove(c)

def add_hair(char, styles=None):
    """build every style for `char` in the current scene; returns {style: object}"""
    clear_hair()
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    poses = [tuple(b.rotation_euler) for b in rig.pose.bones]
    for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    h = Head(body, rig); made = {}
    for i, name in enumerate(styles or CHAR_STYLES[char]):
        fn, mats = STYLES[name]; b = Build(h, mats); fn(b)
        ob = b.finish("Hair_" + name, rig); made[name] = ob
        ob.hide_render = i > 0; ob.hide_set(i > 0)
    for pb, r in zip(rig.pose.bones, poses): pb.rotation_euler = r
    print(char, {k: len(o.data.polygons) for k, o in made.items()})
    return made

def blend_files():
    return sorted(f for f in glob.glob(os.path.join(M, "human_*", "human_*.blend")))

def char_of(path):
    return DIRS[os.path.basename(os.path.dirname(path))]

def hair_all():
    bpy.context.preferences.filepaths.save_version = 0       # don't touch the committed .blend1 backups
    for f in blend_files():
        bpy.ops.wm.open_mainfile(filepath=f)
        add_hair(char_of(f)); bpy.ops.wm.save_mainfile()

# ---------- preview sheet: rows = styles, columns = front / 3-4 / side / back ----------
def preview(char, out):
    import numpy as np
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    h = Head(body, rig); s = h.s; sc = bpy.context.scene
    hair = sorted((o for o in bpy.data.objects if o.name.startswith("Hair_")), key=lambda o: CHAR_STYLES[char].index(o.name[5:]))
    skin = bpy.data.materials.new("_skin"); skin.diffuse_color = (0.78, 0.60, 0.48, 1)
    for o in sc.objects: o.hide_render = True
    views, W, H, PX = [0, -40, -90, 180], 0.55*s, 0.62*s, 230
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = len(views)*W
    cam.location = ((len(views) - 1)*W/2 + h.C.x, h.C.y - 3, h.C.z - 0.11*s); cam.rotation_euler = (R(90), 0, 0); sc.camera = cam
    sc.render.engine = 'BLENDER_WORKBENCH'; sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_cavity = True; sh.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = PX*len(views), int(PX*H/W), 100
    rows = []
    for ho in hair:
        temps = []
        for c_, ang in enumerate(views):
            mx = Matrix.Translation((c_*W + h.C.x, h.C.y, 0)) @ Matrix.Rotation(R(ang), 4, 'Z') @ Matrix.Translation((-h.C.x, -h.C.y, 0))
            bo = bpy.data.objects.new("_body", body.data.copy()); bo.data.materials.clear(); bo.data.materials.append(skin)
            hc = bpy.data.objects.new("_hair", ho.data)
            for o in (bo, hc): o.matrix_world = mx; sc.collection.objects.link(o); temps.append(o)
        tmp = out[:-4] + "_row.png"; sc.render.filepath = tmp; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(tmp); a = np.empty(im.size[0]*im.size[1]*4, dtype=np.float32); im.pixels.foreach_get(a)
        rows.append(a.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
        for o in temps: bpy.data.objects.remove(o, do_unlink=True)
    sheet = np.concatenate(rows[::-1], axis=0)              # image rows run bottom-up
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0], alpha=True)
    img.pixels.foreach_set(sheet.ravel()); img.filepath_raw = out; img.file_format = 'PNG'; img.save()

def preview_all(chars=None, out_dir=os.path.join(M, "hair_previews")):
    os.makedirs(out_dir, exist_ok=True)
    for f in blend_files():
        name = os.path.splitext(os.path.basename(f))[0]
        if chars and name not in chars: continue
        bpy.ops.wm.open_mainfile(filepath=f)
        if not any(o.name.startswith("Hair_") for o in bpy.data.objects): add_hair(char_of(f))
        preview(char_of(f), os.path.join(out_dir, name + ".png"))

if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--save" in argv: hair_all()
    if "--preview" in argv: preview_all([a for a in argv if a.startswith("human_")] or None)
