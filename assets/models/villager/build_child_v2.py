# Villager v2 child (เด็ก) — replaces the old v1 human_child (one Body + layered Cloth_* meshes) for living NPCs.
#   "D:\blender-5.2.4\blender.exe" -b --python assets/models/villager/build_child_v2.py            (paint + build + preview)
# user 2026-11-15: "งั้นทำ 1 เลย" (child first, ghost child after)
#
# Same idea as build_kuman_v2.py (there is no v2 child body, so it is made from villager_male):
#   1. paint every outfit on the MALE body (same UVs as every v2 body) — clothes painted over the skin, no cloth meshes.
#      Colour PNGs are RGBA like paint.py: alpha 1 = skin (tinted in game by SurfaceAppearance.Color, TintMask), 0 = cloth.
#   2. bend Body + Lower_skirt onto the OLD child skeleton (human_child HumanRig: 52 bones, A-pose, 1.27 m) with
#      build_kuman_v2.bend, so the child walk / run / idle clips and the vehicle seat poses keep fitting
#   3. refit the old child hairs (child_short / ko / pia / klae) from the old child head onto the new head
#   4. previews in assets/models/ChildV2/ (outfit lineup + faces). Export to Studio comes after the owner approves the look.
# Parts (like villager_male): BodyHead, BodyUpper, BodyLower (bare legs, for shorts), LowerSkirt (pha sin to mid-shin), Hair_*
import bpy, bmesh, os, sys, math, traceback
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
MODELS = os.path.dirname(HERE)
CDIR = os.path.join(MODELS, "ChildV2")
TEX = os.path.join(CDIR, "textures")
for d in (CDIR, TEX):
    os.makedirs(d, exist_ok=True)

import build_ghosts_v2 as G
import build_kuman_v2 as K
from export_ghosts_v2 import split_body, push_outside_v2

sk = G.sk
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print("CHILD|", *a)

SKIN_BASE = (0.90, 0.73, 0.61)        # paint.py: lightest tone, the game tints it darker
sk["LOOK"]["child"] = dict(sk["LOOK"]["child"], skin=SKIN_BASE, eye=1.30, brow_w=0.62, brow=(0.20, 0.15, 0.12))
# hair: (name, source blend, its body for the head box) — old child cuts + the v2 adult cuts shrunk onto the child head
HAIR_SRC = {
    "child_short": ("human_child/human_child.blend", "Body"),
    "ko": ("human_child/human_child.blend", "Body"),
    "student": ("villager/villager_male.blend", "Body"),
    "bob": ("villager/villager_female.blend", "Body"),
    "ponytail_bow": ("villager/villager_female.blend", "Body"),
}
HAIRS = tuple(HAIR_SRC)

# ---------------------------------------------------------------- outfits (heights in male-body metres: knee ~0.50, waist ~1.02)
# shirt: sleeve 0 shoulder .. 0.52 elbow .. 1 wrist (0 = sleeveless) · lower: "body" = shorts on the bare legs / "skirt" = pha sin
# shoe: ("flip", colour) or ("school", shoe colour, sock colour)
OUTFITS = [
    dict(name="c_mohom", hair="child_short", tint=(0.84, 0.73, 0.64),
         shirt=dict(color=(0.12, 0.15, 0.30), sleeve=0.30, buttons=True), lower="body",
         pants=dict(color=(0.08, 0.09, 0.15), hem=0.60), shoe=("flip", (0.15, 0.25, 0.55))),
    dict(name="c_school", hair="ko", tint=(0.95, 0.89, 0.83),
         shirt=dict(color=(0.90, 0.90, 0.87), sleeve=0.30, buttons=True, pocket=True), lower="body",
         pants=dict(color=(0.06, 0.09, 0.22), hem=0.60), shoe=("school", (0.05, 0.05, 0.05), (0.90, 0.90, 0.88))),
    dict(name="c_tee", hair="child_short", tint=(0.72, 0.60, 0.52),
         shirt=dict(color=(0.62, 0.16, 0.12), sleeve=0.26), lower="body",
         pants=dict(color=(0.42, 0.37, 0.26), hem=0.58), shoe=("flip", (0.55, 0.10, 0.08))),
    dict(name="c_singlet", hair="ko", tint=(0.84, 0.73, 0.64),
         shirt=dict(color=(0.86, 0.85, 0.80), sleeve=0.0, singlet=True), lower="body",
         pants=dict(color=(0.07, 0.07, 0.08), hem=0.62), shoe=("flip", (0.08, 0.08, 0.08))),
    dict(name="c_girl_sin", hair="ponytail_bow", tint=(0.95, 0.89, 0.83),
         shirt=dict(color=(0.86, 0.62, 0.66), sleeve=0.30, buttons=True), lower="skirt",
         skirt="sin_tinjok", shoe=("flip", (0.80, 0.40, 0.55))),
    dict(name="c_girl_tee", hair="bob", tint=(0.84, 0.73, 0.64),
         shirt=dict(color=(0.86, 0.72, 0.22), sleeve=0.26), lower="skirt",
         skirt="sin_purple", shoe=("flip", (0.38, 0.22, 0.12))),
]

# ---------------------------------------------------------------- painting helpers
def fabric(col, P, spec, sel, seed):
    """paint.py fabric (clean, living people) — build_ghosts_v2's adds grave dirt"""
    c = np.array(spec["color"]); x, y, z = P[..., 0], P[..., 1], P[..., 2]
    tone = 1 + 0.10*(sk["fbm"](x*30, y*30, z*30, oct=3, seed=seed) - 0.5) + 0.035*(sk["fbm"](x*260, y*260, z*260, oct=2, seed=seed + 1) - 0.5)
    dust = sk["sstep"](0.60, 0.80, sk["fbm"](x*16, y*16, z*16, oct=3, seed=seed + 5))       # kids: a little play dust
    cloth = c*tone[..., None]*(1 - 0.08*dust[..., None])
    return np.where(sel[..., None], cloth, col)
G.fabric = fabric

def skin_alpha(col0, col, mask):
    """1 where the pixel is still the painted skin (tinted in game), 0 where clothes / shoes were painted over it"""
    same = np.all(np.abs(col - col0) < 1e-6, -1)
    return np.where(mask & ~same, 0.0, 1.0)

def paint_singlet(ras, col, hgt, rough, spec):
    """white sleeveless vest: torso only, deep round neck and arm holes (shoulder straps stay on the torso)"""
    P = ras["P"]; m = ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    bn = np.array(ras["names"] + ["-"])[ras["bone"]]
    limb = np.array([b.startswith(("upper_arm", "forearm", "hand", "index", "middle", "ring", "pinky", "thumb")) for b in bn.ravel()]).reshape(bn.shape)
    # scoop neck front + back, arm holes; between them the two straps run over the shoulders up to the neck seam
    neck = ((y < 0) & (z > 1.36) & (np.abs(x) < 0.075)) | ((y >= 0) & (z > 1.42) & (np.abs(x) < 0.065))
    hole = (np.abs(x) > 0.118) & (z > 1.27)
    on = m & ~limb & ~neck & ~hole
    col = fabric(col, P, spec, on, 15)
    rib = on & (np.sin(x*900) > 0.6)
    col = np.where(rib[..., None], col*0.96, col)
    edge = on & ((((y < 0) & (z > 1.345)) | ((y >= 0) & (z > 1.405))) & (np.abs(x) < 0.085) | ((np.abs(x) > 0.105) & (z > 1.26)))
    col = np.where(edge[..., None], col*0.9, col)
    rough = np.where(on, 0.9, rough)
    return col, hgt, rough

def paint_shoes(ras, col, hgt, rough, shoe):
    P = ras["P"]; m = ras["mask"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
    if shoe[0] == "flip":
        return G.paint_lower(ras, col, hgt, rough, None, shoe, "male", 1.0)
    c, sock = np.array(shoe[1]), np.array(shoe[2])
    s = m & (z < 0.100)
    col = np.where(s[..., None], c*(1 + 0.08*(sk["fbm"](x*90, y*90, z*90, oct=2, seed=51) - 0.5))[..., None], col)
    sole = s & (z < 0.022); col = np.where(sole[..., None], c*0.6, col)
    so = m & (z >= 0.100) & (z < 0.165)
    col = np.where(so[..., None], sock*(1 - 0.05*sk["fbm"](x*60, y*60, z*60, oct=2, seed=52))[..., None], col)
    top = so & (z > 0.150); col = np.where(top[..., None], col*0.9, col)
    rough = np.where(s, 0.35, np.where(so, 0.9, rough)); hgt += 0.0005*sole
    return col, hgt, rough

def finish(base, r, col, hgt, rough, alpha):
    m = r["mask"]
    col, _ = sk["dilate"](col, m, 8); hgt, _ = sk["dilate"](hgt, m, 8); rough, _ = sk["dilate"](rough, m, 8); alpha, _ = sk["dilate"](alpha, m, 8)
    pp, _ = sk["dilate"](r["ppm"], m, 8); pp = np.maximum(pp, 1.0)
    nrm = sk["normal_from_height"](hgt, pp, pp)
    save_rgba(col, alpha, base + "_Color.png")
    sk["save_png"](np.clip(nrm, 0, 1), base + "_Normal.png", True)
    sk["save_png"](np.clip(rough, 0, 1), base + "_Roughness.png", True)

def save_rgba(rgb, a, path):
    img = bpy.data.images.new("_s", rgb.shape[1], rgb.shape[0], alpha=True)
    px = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)[..., None]], -1).astype(np.float32)
    img.pixels.foreach_set(px.ravel()); img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)

_face_form = G.face_form
def child_face_form(col, hgt, meta, porcelain=False):
    """the child head has almost no modelled nose (childify_head): paint a small button-nose hint instead"""
    col, hgt = _face_form(col, hgt, meta, porcelain=porcelain)
    n2 = sk["N"]; rows = np.arange(n2//2, n2); cols = np.arange(n2)
    v = (rows + 0.5)/n2; u = (cols + 0.5)/n2
    hh_ = meta["h0"] + (v - sk["HV0"])/(sk["HV1"] - sk["HV0"])*(meta["h1"] - meta["h0"])
    az = sk["unwarp"]((u - 0.5)*2*math.pi)
    X, Y = np.meshgrid(az*meta["RF"], hh_)
    cv = sk["Canvas"](X, Y); s = meta["s"]; bh = meta["base_h"]
    col = col*(1 - 0.07*cv.ell(0, bh - 0.001*s, 0.011*s, 0.004*s, 1.0))[..., None]          # soft shadow under the nose
    col = col*(1 + 0.04*cv.ell(0, bh + 0.008*s, 0.006*s, 0.007*s, 1.0))[..., None]          # tip highlight
    for sx in (1, -1):
        col = col*(1 - 0.45*cv.ell(sx*0.0055*s, bh + 0.002*s, 0.0028*s, 0.0016*s, 0.6))[..., None]   # nostrils
    hgt = hgt + 0.0008*s*cv.ell(0, bh + 0.007*s, 0.007*s, 0.009*s, 1.0)
    return col, hgt
G.face_form = child_face_form

def paint_all():
    sc, body, rig, fr, meta, ras_up, VAR = G.prepare_char("male")
    me = body.data
    uv = np.zeros((len(me.loops), 2)); me.uv_layers.active.data.foreach_get("uv", uv.ravel())
    ras_lo = G.rasterise(body, fr, uv, G.faces_of(me, 2))
    # head: child face, eye whites / teeth keep their colour (alpha 0) like paint.py head_textures
    hc, hn, hr = G.head_textures("child", False, meta)
    mx, mn = hc.max(-1), hc.min(-1); sat = (mx - mn)/np.maximum(mx, 1e-4)
    ha = np.where((sat < 0.20) & (mx > 0.62), 0.0, 1.0)
    base = os.path.join(TEX, "c_child_head")
    save_rgba(hc, ha, base + "_Color.png"); sk["save_png"](hn, base + "_Normal.png", True); sk["save_png"](hr, base + "_Roughness.png", True)
    L("painted head")
    for o in OUTFITS:
        r = ras_up
        col, hgt, rough = sk["paint_body"](r, meta, "child", False); col0 = col.copy()
        if o["shirt"].get("singlet"):
            col, hgt, rough = paint_singlet(r, col, hgt, rough, o["shirt"])
        else:
            col, hgt, rough = G.paint_shirt(r, col, hgt, rough, o["shirt"], 1.0)
            if o["shirt"].get("pocket"):
                P = r["P"]; x, y, z = P[..., 0], P[..., 1], P[..., 2]
                inside = r["mask"] & (y < 0) & (x > 0.035) & (x < 0.095) & (z > 1.29) & (z < 1.37)
                edge = inside & ((x - 0.035 < 0.004) | (0.095 - x < 0.004) | (z - 1.29 < 0.004) | (1.37 - z < 0.006))
                col = np.where(edge[..., None], col*0.8, col); hgt -= 0.0003*edge
        finish(os.path.join(TEX, o["name"] + "_upper"), r, col, hgt, rough, skin_alpha(col0, col, r["mask"]))
        if o["lower"] == "skirt":
            vv = VAR["skirt"]; r = vv["ras"]
            col, hgt, rough = sk["paint_body"](r, meta, "child", False); col0 = col.copy()
            col, hgt, rough = G.paint_skirt(r, col, hgt, rough, o["skirt"], vv["tube"], vv["top"], vv["hem"], 1.0)
        else:
            r = ras_lo
            col, hgt, rough = sk["paint_body"](r, meta, "child", False); col0 = col.copy()
            col, hgt, rough = G.paint_lower(r, col, hgt, rough, o["pants"], None, "male", 1.0)
        col, hgt, rough = paint_shoes(r, col, hgt, rough, o["shoe"])
        finish(os.path.join(TEX, o["name"] + "_lower"), r, col, hgt, rough, skin_alpha(col0, col, r["mask"]))
        L("painted", o["name"])

# ---------------------------------------------------------------- build the child model
SEAM_Z, EYE_Z = 1.510, 1.684      # male body: neck seam ring / eye line (face_landmarks nose numbers, male dz)
def childify_head(body):
    """male head -> child head shape BEFORE bending (male metres): shorter lower face + neck, small nose, round cheeks,
    a slightly bigger cranium. The neck seam ring (shared with BodyUpper) does not move."""
    me = body.data; pa = me.attributes["part"].data
    seam = set()
    for p in me.polygons:
        if pa[p.index].value != 0:
            seam.update(p.vertices)
    head = set(v for p in me.polygons if pa[p.index].value == 0 for v in p.vertices) - seam
    K1, CRAN = 0.80, 1.05
    e2 = SEAM_Z + (EYE_Z - SEAM_Z)*K1
    nose = [i for i in head if abs(me.vertices[i].co.x) < 0.022 and 1.618 < me.vertices[i].co.z < 1.698
            and me.vertices[i].co.y < -0.099]
    for i in head:
        v = me.vertices[i]; x, y, z = v.co
        w = math.exp(-((x/0.030)**2 + ((z - 1.650)/0.040)**2))                     # nose: small button nose
        if y < -0.101:                                                             # face plane ~-0.101, nose tip -0.122
            y = y + (-0.101 - y)*0.70*w
        if 1.565 < z < EYE_Z:                                                      # round cheeks, full jaw
            x = x*(1 + 0.09*math.sin(math.pi*(z - 1.565)/(EYE_Z - 1.565)))
        if y < 0 and 1.55 < z < EYE_Z + 0.01:                                      # flatter, rounder face front (adult face is V-shaped)
            k = math.sin(math.pi*min(1.0, (z - 1.55)/(EYE_Z + 0.01 - 1.55)))
            y = y*(1 - 0.10*k*math.exp(-(x/0.045)**2))
        if z < EYE_Z:
            z = SEAM_Z + (z - SEAM_Z)*K1
        else:
            z = e2 + (z - EYE_Z)*CRAN
            x *= 1 + (CRAN - 1)*min(1.0, (z - e2)/0.06); y = y*(1 + (CRAN - 1)*min(1.0, (z - e2)/0.06))
        v.co = (x, y, z)
    # pulling the nose in leaves its side walls as a box: relax the nose patch into a soft small bump
    nb = {i: set() for i in nose}
    ns = set(nose)
    for e in me.edges:
        a, b = e.vertices
        if a in ns: nb[a].add(b)
        if b in ns: nb[b].add(a)
    for _ in range(6):
        new = {}
        for i in nose:
            if nb[i]:
                avg = sum((me.vertices[j].co for j in nb[i]), Vector())/len(nb[i])
                new[i] = me.vertices[i].co.lerp(avg, 0.5)
        for i, c in new.items():
            me.vertices[i].co = c
    me.update()
    L("childified head verts", len(head), "nose relaxed", len(nose))

def build_model(ratio, child_j):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_male.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    own = {"Hair_" + h for h, (blend, _) in HAIR_SRC.items() if blend == "villager/villager_male.blend"}   # this file: can't be a library
    keep = {"Body", "HumanRig", "Lower_skirt"} | own
    for o in list(bpy.data.objects):
        if o.name not in keep and o.type in ("MESH", "CURVE", "EMPTY"):
            bpy.data.objects.remove(o, do_unlink=True)
    male_box = K.head_box(body)
    skirt = bpy.data.objects["Lower_skirt"]
    childify_head(body)
    for ob in (body, skirt):
        K.bend(ob, rig, child_j, ratio)
    with bpy.data.libraries.load(os.path.join(MODELS, "human_child", "human_child.blend"), link=False) as (src, dst):
        dst.objects = ["HumanRig"]
    crig = dst.objects[0]; bpy.context.scene.collection.objects.link(crig)
    bpy.data.objects.remove(rig, do_unlink=True)
    crig.name = "HumanRig"; crig.data.name = "HumanRig"
    if crig.animation_data: crig.animation_data.action = None
    K.grow_head(body, crig)
    for ob in (body, skirt):
        ob.parent = crig
        for md in ob.modifiers:
            if md.type == 'ARMATURE': md.object = crig
    # hairs: each one's own source head box -> the new child head box (pushed just outside the new head)
    n0, n1 = K.head_box(body); ncen = (n0 + n1)/2
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    black = None
    boxes = {"villager/villager_male.blend": male_box}
    for h, (blend, bname) in HAIR_SRC.items():
        path = os.path.join(MODELS, blend)
        if blend not in boxes:
            with bpy.data.libraries.load(path, link=False) as (src, dst):
                dst.objects = [bname]
            ob = dst.objects[0]; bpy.context.scene.collection.objects.link(ob)
            boxes[blend] = K.head_box(ob); bpy.data.objects.remove(ob, do_unlink=True)
        o0, o1 = boxes[blend]; oc = (o0 + o1)/2
        s = (n1 - n0)/np.maximum(o1 - o0, 1e-6)
        if "Hair_" + h in own:
            hair = bpy.data.objects["Hair_" + h]
        else:
            with bpy.data.libraries.load(path, link=False) as (src, dst):
                dst.objects = ["Hair_" + h]
            hair = dst.objects[0]; bpy.context.scene.collection.objects.link(hair)
        hair.name = "Hair_" + h; hair.data.name = "Hair_" + h
        hm = hair.matrix_world; hmi = hm.inverted()
        for v in hair.data.vertices:
            p = np.array(tuple(hm @ v.co)); q = ncen + (p - oc)*s
            v.co = hmi @ Vector(tuple(q))
        for md in hair.modifiers:
            if md.type == 'ARMATURE': md.object = crig
        hair.parent = crig
        if h == "ko":       # shaved head + topknot: one black material (the old grey scalp shell read as grey hair)
            black = black or next((m for m in hair.data.materials if m and m.name.startswith("HairBlack")), None)
            hair.data.materials.clear(); hair.data.materials.append(black)
            for p in hair.data.polygons: p.material_index = 0
        L(hair.name, "scale", [round(float(a), 3) for a in s], "pushed", push_outside_v2(hair, [t_body], clear=0.003))
    # the male mesh carries custom normals of the ADULT face (big nose, long jaw): drop them so shading follows the child shape
    # (split_body then copies these fresh smooth normals to all 3 parts, so the neck / waist seams stay seamless)
    for ob in (body, skirt):
        bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    skirt.name = "LowerSkirt"; skirt.data.name = "LowerSkirt"
    for o in bpy.data.objects:
        if o.type == 'MESH':
            for v in o.data.vertices:
                gs = sorted([(g.group, g.weight) for g in v.groups if g.weight > 1e-4], key=lambda x: -x[1])
                for g, _ in gs[4:]: o.vertex_groups[g].remove([v.index])
    zs = [(o.matrix_world @ v.co).z for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith("Hair") for v in o.data.vertices]
    L("height m", round(min(zs), 3), round(max(zs), 3), "tris", {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.type == 'MESH'})
    return crig

# ---------------------------------------------------------------- preview (TintMask applied like the game)
def tinted_material(name, base, tint):
    im = bpy.data.images.load(base + "_Color.png", check_existing=False)
    a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a); a = a.reshape(im.size[1], im.size[0], 4)
    rgb = a[..., :3]*(1 - a[..., 3:4] + a[..., 3:4]*np.array(tint))
    out = bpy.data.images.new(name + "_t", im.size[0], im.size[1]); bpy.data.images.remove(im)
    px = np.concatenate([rgb, np.ones(a.shape[:2] + (1,))], -1).astype(np.float32); out.pixels.foreach_set(px.ravel())
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = out; nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeTexImage"); r.image = bpy.data.images.load(base + "_Roughness.png", check_existing=True); r.image.colorspace_settings.name = "Non-Color"
    nt.links.new(r.outputs["Color"], b.inputs["Roughness"])
    n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(base + "_Normal.png", check_existing=True); n.image.colorspace_settings.name = "Non-Color"
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(n.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def set_mat(ob, m):
    ob.data.materials.clear(); ob.data.materials.append(m)
    for p in ob.data.polygons: p.material_index = 0

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
    def shot(tgt, d, ortho, res):
        sc.render.resolution_x, sc.render.resolution_y = res
        d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
        p = os.path.join(CDIR, "_tmp.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr
    def save(arr, name):
        img = bpy.data.images.new("s", arr.shape[1], arr.shape[0]); img.pixels.foreach_set(arr.ravel())
        img.filepath_raw = os.path.join(CDIR, name); img.file_format = 'PNG'; img.save(); L("preview", img.filepath_raw)
    H = 1.30
    hz = float((rig.matrix_world @ rig.data.bones["head"].head_local).z) + 0.09
    cols, faces = [], []
    for o in OUTFITS:
        head = tinted_material("h_" + o["name"], os.path.join(TEX, "c_child_head"), o["tint"])
        up = tinted_material("u_" + o["name"], os.path.join(TEX, o["name"] + "_upper"), o["tint"])
        lo = tinted_material("l_" + o["name"], os.path.join(TEX, o["name"] + "_lower"), o["tint"])
        set_mat(bpy.data.objects["BodyHead"], head); set_mat(bpy.data.objects["BodyUpper"], up)
        lower = "LowerSkirt" if o["lower"] == "skirt" else "BodyLower"
        for n in ("BodyLower", "LowerSkirt"):
            bpy.data.objects[n].hide_render = n != lower
        set_mat(bpy.data.objects[lower], lo)
        for h in HAIRS:
            bpy.data.objects["Hair_" + h].hide_render = h != o["hair"]
        cols.append(np.concatenate([shot((0, 0, H*0.5), (0.45, -0.9, 0.06), H*1.08, (300, 440)),
                                    shot((0, 0, H*0.5), (-0.35, 1, 0.05), H*1.08, (300, 440))], 0))
        faces.append(shot((0, 0, hz), (0.3, -1, 0.04), 0.34, (300, 300)))
    save(np.concatenate(cols, 1), "child_v2_lineup.png")
    save(np.concatenate(faces, 1), "child_v2_faces.png")

if __name__ == "__main__":
    try:
        ratio, child_j = K.cross_ratios()
        child_j = {k: (Vector(a), Vector(b)) for k, (a, b) in child_j.items()}
        if "--no-paint" not in sys.argv:
            paint_all()
        rig = build_model(ratio, child_j)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(CDIR, "villager_child.blend"))
        preview(rig)
        L("DONE")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(CDIR, "build_report.txt"), "w", encoding="utf-8").write("\n".join(log + K.log))
