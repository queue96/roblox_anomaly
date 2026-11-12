# Kuman Thong (กุมารทอง) on the Villager v2 body (user 2026-11-13: the jumpscare showed the old child face/body).
#   "D:\blender-5.2.4\blender.exe" -b --python assets/models/villager/build_kuman_v2.py
#
# There is no v2 child body, so this script makes one from villager_male:
#   1. paint the textures on the male body (same UVs as every v2 body) with build_ghosts_v2 / build_skin helpers:
#      child face, the whole skin turned to shrine gold leaf, red chong kraben trousers to mid-shin, gold belt,
#      crossed gold chains (สังวาล), armlets, bracelets and anklets — all painted, no cloth meshes
#   2. bend the male mesh onto the OLD child skeleton (human_child HumanRig, 52 bones, same names / A-pose):
#      every vertex = skin-weighted blend of per-bone maps (male bone -> child bone: along-bone length ratio,
#      cross-section ratio measured from the old male body vs the old child body around that bone)
#   3. swap the rig for the child rig (so old Kuman clips + the mocap kuman_scream fit), refit the old juk topknot
#   4. export assets/models/KumanV2/upload/ghost_kuman_v2.fbx + textures, previews in assets/models/KumanV2/
import bpy, bmesh, os, sys, math, shutil, re, time, traceback
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MODELS = os.path.dirname(HERE)
KDIR = os.path.join(MODELS, "KumanV2")
TEX = os.path.join(KDIR, "textures")
UP = os.path.join(KDIR, "upload")
for d in (KDIR, TEX, UP):
    os.makedirs(d, exist_ok=True)

import build_ghosts_v2 as G
from export_ghosts_v2 import split_body, push_outside_v2

sk = G.sk
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print("KUMAN|", *a)

GOLD = np.array((0.83, 0.62, 0.22))
GOLD_HI = np.array((0.95, 0.80, 0.42))
GOLD_DARK = np.array((0.36, 0.24, 0.08))
RED = np.array((0.62, 0.07, 0.06))

# ---------------------------------------------------------------- 1. measure old bodies (cross-section ratio per bone)
def bone_radii(blend):
    bpy.ops.wm.open_mainfile(filepath=blend)
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    mw = body.matrix_world; rw = rig.matrix_world
    names = [g.name for g in body.vertex_groups]
    acc = {}
    for v in body.data.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        if not best or best.weight < 0.8: continue
        bn = names[best.group]
        if bn not in rig.data.bones: continue
        b = rig.data.bones[bn]
        H = rw @ b.head_local; T = rw @ b.tail_local; A = (T - H)
        if A.length < 1e-6: continue
        A.normalize(); p = mw @ v.co; d = p - H
        r = (d - A*d.dot(A)).length
        s, n = acc.get(bn, (0.0, 0))
        acc[bn] = (s + r, n + 1)
    joints = {b.name: (rw @ b.head_local, rw @ b.tail_local) for b in rig.data.bones}
    return {k: s/n for k, (s, n) in acc.items() if n >= 3}, joints

def cross_ratios():
    rm, _ = bone_radii(os.path.join(MODELS, "human_base", "human_base.blend"))
    rc, cj = bone_radii(os.path.join(MODELS, "human_child", "human_child.blend"))
    ratio = {}
    for bn in rc:
        if bn in rm and rm[bn] > 1e-4:
            ratio[bn] = float(np.clip(rc[bn]/rm[bn], 0.45, 1.1))
    L("cross ratios:", {k: round(v, 2) for k, v in sorted(ratio.items()) if "_0" not in k})
    return ratio, cj

# ---------------------------------------------------------------- 2. paint on the male body
def goldify(col, mask, keep_features=False, ref=None, below=None):
    lum = col.mean(-1)
    ref = ref if ref is not None else float(np.median(lum[mask]))
    k = np.clip(lum/ref, 0.55, 1.25)
    g = GOLD*k[..., None]
    g = sk["mix"](g, GOLD_DARK, sk["sstep"](0.85, 0.6, k)*0.6)
    out = np.where(mask[..., None], g, col)
    met = np.where(mask, 1.0, 0.0)
    if keep_features:
        r, gg, b = col[..., 0], col[..., 1], col[..., 2]
        dark = mask & ((lum < 0.55*ref) | ((lum < 0.75*ref) & (r < gg*1.6) & (gg < 0.6*ref)))   # eyes, brows, lash line -> black paint
        # child skin itself is r/g 1.26: lips are r/g ~1.6, brows are darker brown blended into the skin
        lip = mask & (r > gg*1.42) & (r > b*1.42) & ~dark
        if below is not None:
            lip = lip & below
            brow = mask & ~below & (lum < 0.88*ref) & (r > gg*1.28)
            dark = dark | brow
        out = np.where(dark[..., None], np.array((0.03, 0.025, 0.02)), out)
        out = np.where(lip[..., None], RED, out)
        white = mask & (lum > 1.35*ref) & (np.abs(r - b) < 0.12)  # eye whites stay a dull ivory
        out = np.where(white[..., None], np.array((0.82, 0.80, 0.72)), out)
        met = np.where(dark | lip | white, 0.0, met)
    return out, met, ref

def leaf_wear(col, met, rough, P, mask, seed):
    x, y, z = P[..., 0], P[..., 1], P[..., 2]
    hi = sk["sstep"](0.6, 0.85, sk["fbm"](x*25, y*25, z*25, oct=2, seed=seed))
    col = sk["mix"](col, GOLD_HI, 0.25*hi*mask)
    flake = (sk["fbm"](x*60, y*60, z*60, oct=2, seed=seed + 1) > 0.80) & mask
    col = sk["mix"](col, np.array((0.30, 0.20, 0.12)), flake*0.45*(met > 0.5))
    met = np.where(flake & (met > 0.5), 0.1, met)
    rough = np.where(mask, np.where(met > 0.5, 0.36, rough), rough)
    rough = np.where(flake, 0.7, rough)
    return col, met, rough

def save_full(base, ras, col, hgt, rough, met):
    m = ras["mask"]
    col, _ = sk["dilate"](col, m, 8); hgt, _ = sk["dilate"](hgt, m, 8)
    rough, _ = sk["dilate"](rough, m, 8); met, _ = sk["dilate"](met, m, 8)
    pp, _ = sk["dilate"](ras["ppm"], m, 8); pp = np.maximum(pp, 1.0)
    nrm = sk["normal_from_height"](hgt, pp, pp)
    sk["save_png"](np.clip(col, 0, 1), base + "_Color.png", False)
    sk["save_png"](np.clip(nrm, 0, 1), base + "_Normal.png", True)
    sk["save_png"](np.clip(rough, 0, 1), base + "_Roughness.png", True)
    sk["save_png"](np.clip(met, 0, 1), base + "_Metalness.png", True)
    L("saved", os.path.basename(base))

def paint_kuman():
    sc, body, rig, fr, meta, ras_up, VAR = G.prepare_char("male")
    # head: child face, then gold leaf with black painted eyes/brows and red lips (shrine figure)
    hc, hn, hr = G.head_textures("child", False, meta)
    lum = hc.mean(-1); hmask = np.ones(lum.shape, bool)
    N = sk["N"]; rows = N//2 + np.arange(hc.shape[0])*(N//2)//hc.shape[0]
    hrow = meta["h0"] + ((rows + 0.5)/N - sk["HV0"])/(sk["HV1"] - sk["HV0"])*(meta["h1"] - meta["h0"])
    mouth_zone = np.repeat((hrow < (meta["eye_h"] + meta["mouth_h"])/2)[:, None], hc.shape[1], 1)
    L("head rows", hc.shape, "eye_h", round(meta["eye_h"], 3), "mouth_h", round(meta["mouth_h"], 3), "zone rows", int(mouth_zone[:, 0].sum()))
    gc, gm, ref = goldify(hc, hmask, keep_features=True, below=mouth_zone)
    n2 = gc.shape[0]
    Yg, Xg = np.mgrid[0:n2, 0:gc.shape[1]]
    Pfake = np.stack([Xg/n2, Yg/n2, np.zeros(Xg.shape)], -1)
    gc, gm, hr = leaf_wear(gc, gm, hr, Pfake*0.4, hmask, 170)
    base = os.path.join(TEX, "g_kuman_head")
    sk["save_png"](np.clip(gc, 0, 1), base + "_Color.png", False)
    sk["save_png"](np.clip(hn, 0, 1), base + "_Normal.png", True)
    sk["save_png"](np.clip(hr, 0, 1), base + "_Roughness.png", True)
    sk["save_png"](np.clip(gm, 0, 1), base + "_Metalness.png", True)
    L("saved g_kuman_head")

    # upper: bare gold chest + crossed chains, armlets, bracelets
    r = ras_up; P = r["P"]; m = r["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    col, hgt, rough = sk["paint_body"](r, meta, "child", False)
    col, met, _ = goldify(col, m)
    col, met, rough = leaf_wear(col, met, rough, P, m, 171)
    bn = np.array(r["names"] + ["-"])[r["bone"]]
    arm = np.array([b.startswith(("upper_arm", "forearm")) for b in bn.ravel()]).reshape(bn.shape)
    jew = np.zeros(m.shape, bool)
    # สังวาล: two chains from each shoulder crossing on the chest and on the back
    for sx in (1, -1):
        t = np.clip((1.47*sc - z)/(0.40*sc), 0, 1)
        xc = sx*(0.13 - 0.26*t)*sc
        on = m & ~arm & (z > 1.07*sc) & (z < 1.47*sc) & (np.abs(x - xc) < 0.010*sc)
        bead = on & (np.sin(z/sc*520) > 0.2)
        jew |= on
        hgt += 0.0012*on + 0.0008*bead
    cx = m & ~arm & (np.hypot(x, z - 1.27*sc) < 0.026*sc) & (y < 0)          # ทับทรวง where they cross
    jew |= cx; hgt += 0.002*cx
    for side, sx in (("L", 1), ("R", -1)):
        S = fr.joints["upper_arm." + side][0]; W = fr.joints["hand." + side][0]; d = W - S
        ta = ((P - S) @ d)/float(d @ d)
        this = arm & (np.sign(x) == sx)
        band = this & (((ta > 0.30) & (ta < 0.36)) | ((ta > 0.88) & (ta < 0.96)))
        jew |= band; hgt += 0.0015*band
    col = np.where(jew[..., None], GOLD_HI*0.95, col)
    col = np.where(cx[..., None], np.array((0.70, 0.08, 0.10)), col)              # red stone in the clasp
    met = np.where(jew & ~cx, 1.0, met); rough = np.where(jew, 0.25, rough)
    save_full(os.path.join(TEX, "g_kuman_upper"), r, col, hgt, rough, met)

    # lower (wide trousers mesh): red chong kraben to mid-shin, gold belt, gold skin below, anklets
    v = VAR["wide"]; r = v["ras"]; P = r["P"]; m = r["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    col, hgt, rough = sk["paint_body"](r, meta, "child", False)
    col, met, _ = goldify(col, m)
    col, met, rough = leaf_wear(col, met, rough, P, m, 172)
    hem = HEM_Z*sc
    pants = m & (z > hem)
    fold = 0.84 + 0.22*sk["fbm"](np.arctan2(x - np.sign(x)*0.10*sc, y)*3, z*6, oct=3, seed=33)   # soft vertical folds
    cloth = RED*fold[..., None]*(1 + 0.10*(sk["fbm"](x*30, y*30, z*30, oct=3, seed=31) - 0.5))[..., None]
    col = np.where(pants[..., None], cloth, col)
    met = np.where(pants, 0.0, met); rough = np.where(pants, 0.82, rough)
    hemband = pants & (z < hem + 0.02*sc)
    col = np.where(hemband[..., None], col*0.72, col); hgt += 0.0008*hemband
    belt = m & (z > 0.995*sc)
    col = np.where(belt[..., None], GOLD_HI*0.95, col); met = np.where(belt, 1.0, met); rough = np.where(belt, 0.25, rough)
    hgt += 0.0016*belt
    ank = m & (z > 0.105*sc) & (z < 0.135*sc)
    col = np.where(ank[..., None], GOLD_HI, col); met = np.where(ank, 1.0, met); rough = np.where(ank, 0.22, rough)
    hgt += 0.0016*ank
    save_full(os.path.join(TEX, "g_kuman_lower"), r, col, hgt, rough, met)

# ---------------------------------------------------------------- 3. bend onto the child skeleton
def bend(ob, male_rig, child_j, ratio):
    rw = male_rig.matrix_world; mw = ob.matrix_world; mwi = mw.inverted()
    maps = {}
    for b in male_rig.data.bones:
        if b.name not in child_j: continue
        Hm = rw @ b.head_local; Tm = rw @ b.tail_local
        Hc, Tc = child_j[b.name]
        dm = Tm - Hm; dc = Tc - Hc
        if dm.length < 1e-6 or dc.length < 1e-6:
            maps[b.name] = (Hm, Hc, Matrix.Identity(3), 1.0, 1.0); continue
        Mb = (rw.to_3x3() @ b.matrix_local.to_3x3()).normalized()      # columns: x, y(along bone), z
        R = dm.normalized().rotation_difference(dc.normalized()).to_matrix()
        sa = dc.length/dm.length
        cr = ratio.get(b.name)
        if b.name in ("head",):
            cr = sa                                                      # the head keeps its shape, just smaller
        if cr is None:
            cr = sa
        maps[b.name] = (Hm, Hc, R @ Mb, sa, cr, Mb)
    names = [g.name for g in ob.vertex_groups]
    moved = 0
    for v in ob.data.vertices:
        p = mw @ v.co; acc = Vector(); wt = 0.0
        for g in v.groups:
            if g.weight <= 1e-4: continue
            mp = maps.get(names[g.group])
            if not mp or len(mp) < 6: continue
            Hm, Hc, RM, sa, cr, Mb = mp
            loc = Mb.transposed() @ (p - Hm)
            loc = Vector((loc.x*cr, loc.y*sa, loc.z*cr))
            acc += (Hc + RM @ loc)*g.weight; wt += g.weight
        if wt > 0:
            v.co = mwi @ (acc/wt); moved += 1
    ob.data.update()
    L("bent", ob.name, moved, "/", len(ob.data.vertices))

HEM_Z = 0.36            # male-scale height of the chong hem (same number as the painted hem)
def tighten_calves(ob, rig):
    rw = rig.matrix_world; mw = ob.matrix_world; mwi = mw.inverted()
    axes = {}
    for side in ("L", "R"):
        b = rig.data.bones["shin." + side]; axes[side] = (rw @ b.head_local, (rw @ b.tail_local - rw @ b.head_local).normalized())
    body = bpy.data.objects["Body"]
    tb = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    n = 0
    for v in ob.data.vertices:
        p = mw @ v.co
        side = "L" if p.x > 0 else "R"; H, A = axes[side]
        d = p - H; ax = A*d.dot(A); rad = d - ax
        if p.z < HEM_Z - 0.005:
            # onto the bare leg surface just outside the body skin
            loc, nrm, _, dist = tb.find_nearest(p, 0.2)
            if loc is not None:
                p2 = loc + nrm*0.002
                k = min(1.0, (HEM_Z - 0.005 - p.z)/0.03)
                v.co = mwi @ p.lerp(p2, k); n += 1
        elif p.z < 0.80:
            # chong kraben: puffy over the knee and thigh, gathered again at the hem
            t = min(1.0, (p.z - HEM_Z)/0.10)
            v.co = mwi @ (H + ax + rad*(1.0 + 0.16*t*min(1.0, (0.80 - p.z)/0.15)))
    ob.data.update()
    L("calves tightened", n)

HEAD_GROW = 1.18        # child head is bigger for its body than the bent adult head
def grow_head(ob, rig):
    names = [g.name for g in ob.vertex_groups]; mw = ob.matrix_world; mwi = mw.inverted()
    C = rig.matrix_world @ rig.data.bones["head"].head_local
    for v in ob.data.vertices:
        w = sum(g.weight for g in v.groups if names[g.group] == "head")
        if w <= 0: continue
        p = mw @ v.co
        v.co = mwi @ (p + (p - C)*(HEAD_GROW - 1)*w)
    ob.data.update()

def head_box(ob, rig_names_head="head"):
    names = [g.name for g in ob.vertex_groups]; mw = ob.matrix_world; pts = []
    for v in ob.data.vertices:
        for g in v.groups:
            if names[g.group] == rig_names_head and g.weight > 0.99:
                pts.append(mw @ v.co); break
    a = np.array([tuple(p) for p in pts]); return a.min(0), a.max(0)

def tex_material(name, base):
    m = bpy.data.materials.get(name)
    if m: bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def t(sfx, nc):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(os.path.join(TEX, base + sfx + ".png"), check_existing=True)
        if nc: n.image.colorspace_settings.name = "Non-Color"
        return n
    nt.links.new(t("_Color", False).outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t("_Roughness", True).outputs["Color"], b.inputs["Roughness"])
    nt.links.new(t("_Metalness", True).outputs["Color"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t("_Normal", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def build_model(ratio, child_j):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_male.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    keep = {"Body", "HumanRig", "Lower_wide"}
    for o in list(bpy.data.objects):
        if o.name not in keep and o.type in ("MESH", "CURVE", "EMPTY"):
            bpy.data.objects.remove(o, do_unlink=True)
    wide = bpy.data.objects["Lower_wide"]
    tighten_calves(wide, rig)
    for ob in (body, wide):
        bend(ob, rig, child_j, ratio)
    # swap in the old child rig (same 52 bone names, A-pose; the clips are authored on it)
    with bpy.data.libraries.load(os.path.join(MODELS, "human_child", "human_child.blend"), link=False) as (src, dst):
        dst.objects = ["HumanRig"]
    crig = dst.objects[0]; bpy.context.scene.collection.objects.link(crig)
    bpy.data.objects.remove(rig, do_unlink=True)
    crig.name = "HumanRig"; crig.data.name = "HumanRig"
    if crig.animation_data: crig.animation_data.action = None
    grow_head(body, crig)
    for ob in (body, wide):
        ob.parent = crig
        for md in ob.modifiers:
            if md.type == 'ARMATURE': md.object = crig
    # old juk topknot (with its shaved-scalp shell) refit from the old child head box to the new head box
    with bpy.data.libraries.load(os.path.join(MODELS, "human_ghosts", "ghost_kuman_thong.blend"), link=False) as (src, dst):
        dst.objects = ["Hair_juk", "Body"]
    hair, oldbody = dst.objects
    bpy.context.scene.collection.objects.link(hair); bpy.context.scene.collection.objects.link(oldbody)
    o0, o1 = head_box(oldbody); n0, n1 = head_box(body)
    s = (n1 - n0)/np.maximum(o1 - o0, 1e-6)
    hm = hair.matrix_world; hmi = hm.inverted()
    oc = (o0 + o1)/2; ncen = (n0 + n1)/2
    for v in hair.data.vertices:
        p = np.array(tuple(hm @ v.co)); q = ncen + (p - oc)*s
        v.co = hmi @ Vector(tuple(q))
    bpy.data.objects.remove(oldbody, do_unlink=True)
    for md in hair.modifiers:
        if md.type == 'ARMATURE': md.object = crig
    hair.parent = crig
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    L("hair scale", [round(float(a), 3) for a in s], "pushed", push_outside_v2(hair, [t_body], clear=0.003))
    pieces = split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    bpy.data.objects.remove(bpy.data.objects["BodyLower"], do_unlink=True)
    wide.name = "LowerWide"; wide.data.name = "LowerWide"
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.name != "Hair_juk":
            o.data.materials.clear()
    for name, base in (("BodyHead", "g_kuman_head"), ("BodyUpper", "g_kuman_upper"), ("LowerWide", "g_kuman_lower")):
        ob = bpy.data.objects[name]; ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for v in o.data.vertices:
                gs = sorted([(g.group, g.weight) for g in v.groups if g.weight > 1e-4], key=lambda x: -x[1])
                for g, _ in gs[4:]: o.vertex_groups[g].remove([v.index])
    zs = [ (o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == 'MESH' for v in o.data.vertices ]
    L("height m", round(min(zs), 3), round(max(zs), 3))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(KDIR, "kuman_v2.blend"))
    return crig

# ---------------------------------------------------------------- 4. export + preview
def export_fbx(rig):
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(UP, "ghost_kuman_v2.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=3.5,
        apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
        add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
        mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False)
    data = open(path, "rb").read(); n = 0
    for fn in sorted(set(x.decode("latin1") for x in re.findall(rb"[\w\-]+\.png", data))):
        for d in (TEX, os.path.dirname(path)):
            src = os.path.join(d, fn)
            if os.path.exists(src) and d != UP:
                shutil.copyfile(src, os.path.join(UP, fn)); n += 1; break
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
    L("exported", path, "pngs", n, "meshes", [o.name for o in meshes])

def preview(rig):
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try: sc.render.engine = eng; break
        except TypeError: pass
    sc.view_settings.view_transform = 'Standard'
    w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.20, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    for n, rot, e in (("_key", (55, 0, -30), 3.0), ("_fill", (70, 0, 55), 1.2), ("_back", (60, 0, 170), 1.0)):
        l = bpy.data.objects.new(n, bpy.data.lights.new(n, 'SUN')); l.data.energy = e
        l.rotation_euler = tuple(math.radians(v) for v in rot); sc.collection.objects.link(l)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    imgs = []
    def shot(tgt, d, ortho, res):
        sc.render.resolution_x, sc.render.resolution_y = res
        d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
        p = os.path.join(KDIR, "_tmp.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr
    H = 1.32
    imgs.append(shot((0, 0, H*0.5), (0.0, -1, 0.05), H*1.08, (300, 420)))
    imgs.append(shot((0, 0, H*0.5), (0.7, -0.7, 0.06), H*1.08, (300, 420)))
    imgs.append(shot((0, 0, H*0.5), (0.0, 1, 0.05), H*1.08, (300, 420)))
    hz = float(max((rig.matrix_world @ rig.data.bones["head"].tail_local).z, 0.9)) - 0.06
    imgs.append(shot((0, 0, hz), (0.25, -1, 0.05), 0.36, (300, 420)))
    sheet = np.concatenate(imgs, 1)
    img = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = os.path.join(KDIR, "kuman_v2_preview.png"); img.file_format = 'PNG'; img.save()
    L("preview", img.filepath_raw)

if __name__ == "__main__":
    try:
        ratio, child_j = cross_ratios()
        child_j = {k: (Vector(a), Vector(b)) for k, (a, b) in child_j.items()}
        paint_kuman()
        rig = build_model(ratio, child_j)
        export_fbx(rig)
        preview(rig)
        L("DONE")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(KDIR, "build_report.txt"), "w", encoding="utf-8").write("\n".join(log))
