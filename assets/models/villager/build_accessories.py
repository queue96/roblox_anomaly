# Villager v2 accessories, kept as separate pieces bound to HumanRig (collection "Accessories" in villager_<char>.blend):
#   Hair_<style>   the old hair builder (human_base/build_hair.py) fitted to the new head, bound to the head bone
#   Hat_ngob       งอบ: wide shallow cone on a head band (bound to head), straw tile
#   Sash_pakama    ผ้าขาวม้าคาดเอว: a band over the waist seam (bound to hips) + knot + two short tails at the front left
#                  (tails ease onto the left thigh so they swing with the leg). Fits the Body, Lower_wide and Lower_skirt.
#   blender -b --factory-startup --python build_accessories.py -- [male|female] [--save] [--render <out_dir>]
# Short hair is fitted on a head built WITHOUT ears (build_body.py EARS = False): the scalp rays would hit the ears
# and push the hair out over them (the old elder's horseshoe stuck out). Hair that covers the ears is fitted on the real head.
import bpy, bmesh, os, sys, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__)); MODELS = os.path.dirname(HERE); OLD = os.path.join(MODELS, "human_base")
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CHAR = "female" if "female" in argv else "male"
SC = {"male": 1.0, "female": 0.93}[CHAR]
TILE = 0.32
# (style, fitted over the ears)
STYLES = {"male": [("student", False), ("rong_song_sung", False), ("side_part", False), ("bald_grey", False), ("long_white_beard", True)],
          "female": [("bob", True), ("ponytail_bow", False), ("curly_grey", True), ("bun_grey", False)]}[CHAR]
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

def run(path, extra=None):
    ns = {"__name__": "acc", "__file__": path}
    if extra: ns.update(extra)
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), ns)
    ns["M"] = MODELS
    return ns

def collection():
    c = bpy.data.collections.get("Accessories") or bpy.data.collections.new("Accessories")
    if c.name not in bpy.context.scene.collection.children: bpy.context.scene.collection.children.link(c)
    return c

def keep(obs):
    c = collection()
    for o in obs:
        for uc in list(o.users_collection): uc.objects.unlink(o)
        c.objects.link(o)

def head_rigid(z, y):     # the same head region build_rig.py makes rigid
    if CHAR == "male": return z > 1.588 or (z > 1.558 and y < -0.03)
    return z/SC > 1.60 or (z/SC > 1.57 and y/SC < -0.03)

def bind(ob, rig, groups):
    """groups: per vertex {bone: weight}"""
    vg = {}
    for i, ws in enumerate(groups):
        for n, w in ws.items():
            if n not in vg: vg[n] = ob.vertex_groups.new(name=n)
            vg[n].add([i], w, 'REPLACE')
    ob.parent = rig
    m = ob.modifiers.new("Armature", 'ARMATURE'); m.object = rig
    return ob

def tile_material(name, tile):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    for n in [n for n in nt.nodes if n.type == 'TEX_IMAGE']: nt.nodes.remove(n)
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(os.path.join(MODELS, "clothes_tex", tile + "_Color.png"), check_existing=True)
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"]); b.inputs["Roughness"].default_value = 0.85
    px = np.empty(4*t.image.size[0]*t.image.size[1], np.float32); t.image.pixels.foreach_get(px)
    m.diffuse_color = (*px.reshape(-1, 4)[:, :3].mean(0), 1)      # Workbench / viewport colour
    return m

def make_mesh(name, verts, faces, uvs, groups, rig, mat):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], faces)
    lay = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        for l, v in zip(p.loop_indices, p.vertices): lay.data[l].uv = uvs[(p.index, v)] if (p.index, v) in uvs else uvs.get(v, (0, 0))
    for p in me.polygons: p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me); collection().objects.link(ob)
    bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    return bind(ob, rig, groups)

# ---------------------------------------------------------------- hair
def build_hair(body, rig):
    hns = run(os.path.join(OLD, "build_hair.py"))
    made = []
    earless = [s for s, ears in STYLES if not ears]; eared = [s for s, ears in STYLES if ears]
    if earless:
        body.name = "_BodyReal"
        run(os.path.join(HERE, "build_body.py"), {"CHAR": CHAR, "EARS": False})
        tmp = bpy.data.objects["Body"]
        g = tmp.vertex_groups.new(name="head")
        g.add([v.index for v in tmp.data.vertices if head_rigid(v.co.z, v.co.y)], 1.0, 'REPLACE')
        obs = hns["add_hair"](CHAR, earless); keep(obs.values()); made += list(obs.values())
        me = tmp.data; bpy.data.objects.remove(tmp, do_unlink=True); bpy.data.meshes.remove(me)
        body.name = "Body"
    if eared:
        for o in made: o.name = "_keep" + o.name          # add_hair() first deletes every object named Hair*
        obs = hns["add_hair"](CHAR, eared); keep(obs.values())
        for o in made: o.name = o.name[len("_keep"):]
        made += list(obs.values())
    for o in made: o.hide_render = True; o.hide_set(True)
    return made

# ---------------------------------------------------------------- งอบ
def build_ngob(body, rig):
    me = body.data
    hv = np.array([tuple(v.co) for v in me.vertices if head_rigid(v.co.z, v.co.y)])
    s = (hv[:, 2].max() - hv[:, 2].min())/0.235
    hb = rig.data.bones["head"]; U = (hb.tail_local - hb.head_local).normalized()
    top = Vector(hv[np.argmax(hv @ np.array(U))]); base = top - U*0.045*s
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); Lr = U.cross(F)
    prof = [(0.0, 0.11), (0.06, 0.085), (0.14, 0.04), (0.24, 0.0), (0.26, -0.006)]
    seg = 32; V, Fc, UV = [], [], {}
    def vid(p): V.append(p); return len(V) - 1
    ro, ri = [], []
    for r_, h_ in prof:
        a_o, a_i = [], []
        for j in range(seg):
            a = 2*math.pi*j/seg; d = F*math.cos(a) + Lr*math.sin(a); p = base + d*r_*s + U*h_*s
            a_o.append(vid(p)); a_i.append(vid(p - U*0.004*s))
            UV[a_o[-1]] = UV[a_i[-1]] = (r_*s*math.cos(a)/TILE, r_*s*math.sin(a)/TILE)
        ro.append(a_o); ri.append(a_i)
    for i in range(len(prof) - 1):
        for j in range(seg):
            j2 = (j + 1) % seg
            Fc.append((ro[i][j], ro[i + 1][j], ro[i + 1][j2], ro[i][j2])); Fc.append((ri[i][j2], ri[i + 1][j2], ri[i + 1][j], ri[i][j]))
    k = len(prof) - 1
    for j in range(seg): Fc.append((ro[k][j], ri[k][j], ri[k][(j + 1) % seg], ro[k][(j + 1) % seg]))
    ob = make_mesh("Hat_ngob", V, Fc, UV, [{"head": 1.0}]*len(V), rig, tile_material("Straw", "straw"))
    ob.hide_render = True; ob.hide_set(True)
    return ob

# ---------------------------------------------------------------- ผ้าขาวม้าคาดเอว
def build_sash(body, rig):
    me = body.data; pa = me.attributes["part"].data
    up, lo = set(), set()
    for p in me.polygons: (lo if pa[p.index].value == 2 else up if pa[p.index].value == 1 else set()).update(p.vertices)
    ring = up & lo; zw = float(np.mean([me.vertices[i].co.z for i in ring]))
    pts = [tuple(v.co) for v in me.vertices]
    for n in ("Lower_wide", "Lower_skirt"):
        o = bpy.data.objects.get(n)
        if o: pts += [tuple(v.co) for v in o.data.vertices]
    P = np.array(pts); z0, z1 = zw - 0.035*SC, zw + 0.025*SC
    sl = P[(P[:, 2] > z0 - 0.02*SC) & (P[:, 2] < z1 + 0.02*SC) & (np.hypot(P[:, 0], P[:, 1]) < 0.30*SC)]   # not the hanging hands
    seg = 32; ang = [2*math.pi*k/seg for k in range(seg)]
    dirs = np.array([(math.sin(a), -math.cos(a)) for a in ang])
    sup = (sl[:, :2] @ dirs.T).max(0) + 0.010*SC
    V, Fc, UV, G = [], [], {}, []
    def vid(p, w): V.append(p); G.append(w); return len(V) - 1
    circ = 0.0
    rows = []
    for z, bulge, inset in ((z0, 0.0, 0.0), (zw - 0.005*SC, 0.005*SC, 0.0), (z1, 0.0, 0.0), (z1, -0.006*SC, 1), (z0, -0.006*SC, 1)):
        r = []
        for k in range(seg):
            x, y = dirs[k]*(sup[k] + bulge); r.append(vid(Vector((x, y, z)), {"hips": 1.0}))
            UV[r[-1]] = (k/seg*2*math.pi*0.17*SC/TILE, (z - z0)/TILE)
        rows.append(r)
    for i in range(len(rows)):                       # closed band: outer bottom -> mid -> top -> inner top -> inner bottom -> outer bottom
        a, b = rows[i], rows[(i + 1) % len(rows)]
        for k in range(seg):
            k2 = (k + 1) % seg; Fc.append((a[k], a[k2], b[k2], b[k]))
    # knot + tails at the front left (character's left = +x)
    ka = math.radians(38); d = Vector((math.sin(ka), -math.cos(ka), 0)); t_ = Vector((math.cos(ka), math.sin(ka), 0))
    kc = Vector((d.x, d.y, 0))*(float(np.interp(ka, ang, sup)) + 0.016*SC) + Vector((0, 0, zw - 0.005*SC))
    def box(c, ax_u, ax_v, ax_w, hu, hv_, hw, wfun):
        idx = []
        for su in (-1, 1):
            for sv in (-1, 1):
                for sw in (-1, 1):
                    p = c + ax_u*hu*su + ax_v*hv_*sv + ax_w*hw*sw
                    idx.append(vid(p, wfun(sv))); UV[idx[-1]] = (((su + 1)*hu)/TILE, ((sv + 1)*hv_)/TILE)
        q = lambda a, b, c_, d_: Fc.append((idx[a], idx[b], idx[c_], idx[d_]))
        q(0, 1, 3, 2); q(4, 6, 7, 5); q(0, 4, 5, 1); q(2, 3, 7, 6); q(0, 2, 6, 4); q(1, 5, 7, 3)
    box(kc, t_, Vector((0, 0, 1)), d, 0.024*SC, 0.022*SC, 0.014*SC, lambda sv: {"hips": 1.0})
    for off, ln in ((-0.012, 0.17), (0.014, 0.13)):  # two tails hanging from the knot
        c = kc + t_*off*SC - Vector((0, 0, ln*SC/2 + 0.018*SC)) + d*0.006*SC
        box(c, t_, Vector((0, 0, 1)), d, 0.026*SC, ln*SC/2, 0.003*SC,
            lambda sv: {"hips": 1.0} if sv > 0 else {"hips": 0.45, "thigh.L": 0.55})
    ob = make_mesh("Sash_pakama", V, Fc, UV, G, rig, tile_material("PlaidPink", "plaid_pink"))
    ob.hide_render = True; ob.hide_set(True)
    L("sash: waist z", round(zw, 3), "band radius", round(float(sup.min()), 3), "-", round(float(sup.max()), 3))
    return ob

# ---------------------------------------------------------------- check renders
def renders(out, body, rig, hair, hat, sash):
    import numpy as np
    sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_shadows = False
    w = bpy.data.worlds.new("W"); sc.world = w; w.color = (0.42, 0.43, 0.45)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    skin = bpy.data.materials.new("_skin"); skin.diffuse_color = (0.80, 0.62, 0.50, 1)
    shirt = bpy.data.materials.new("_shirt"); shirt.diffuse_color = (0.20, 0.24, 0.42, 1)
    body.data.materials.clear(); body.data.materials.append(skin); body.data.materials.append(shirt); body.data.materials.append(shirt)
    pa = body.data.attributes["part"].data
    for p in body.data.polygons: p.material_index = pa[p.index].value
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not body: o.hide_render = True
    def shot(tgt, d, ortho, res):
        sc.render.resolution_x, sc.render.resolution_y = res
        d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
        cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
        p = os.path.join(out, f"_t_{CHAR}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
        arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr
    def save(arr, name):
        img = bpy.data.images.new("s", arr.shape[1], arr.shape[0]); img.pixels.foreach_set(arr.ravel())
        img.filepath_raw = os.path.join(out, name); img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)
    hc = Vector((0, 0.0, 1.66*SC))
    cols = []
    for o in hair + [hat]:
        o.hide_render = False
        cols.append(np.concatenate([shot(hc + Vector((0, 0, 0.02)), d, 0.48*SC, (300, 300)) for d in ((0, 1, 0.1), (1, 0.1, 0.05), (0.7, -0.7, 0.1))], 0))
        o.hide_render = True
    save(np.concatenate(cols, 1), f"acc_{CHAR}_hair.png")
    # sash + ngob in poses
    old = {"male": "human_base", "female": "human_female"}[CHAR]
    poses = [("idle", 0.2), ("walk", 0.3), ("ride_moto", 0.3), ("drive_car", 0.3), ("sit", 0.5), ("pull_start", 0.5)]
    with bpy.data.libraries.load(os.path.join(MODELS, "mocap", "out", old + "_mocap.blend")) as (src, dst):
        dst.actions = [p for p, _ in poses]
    acts = {a.name: a for a in dst.actions if a}
    sash.hide_render = False; hat.hide_render = False; hair[0].hide_render = False
    rows = []
    for d in ((0.75, -0.65, 0.1), (1, 0, 0.05)):
        tiles = []
        for name, frac in poses:
            act = acts[name]
            fcs = list(act.fcurves) if hasattr(act, "fcurves") else [fc for ly in act.layers for st in ly.strips for cb in st.channelbags for fc in cb.fcurves]
            quat = any(fc.data_path.endswith("rotation_quaternion") for fc in fcs)   # old clips are keyed in euler
            for pb in rig.pose.bones:
                pb.rotation_mode = "QUATERNION" if quat else "XYZ"
                pb.rotation_quaternion = (1, 0, 0, 0); pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
                for c in pb.constraints: c.mute = True
            if not rig.animation_data: rig.animation_data_create()
            rig.animation_data.action = act
            try: rig.animation_data.action_slot = act.slots[0]
            except Exception: pass
            f0, f1 = act.frame_range; sc.frame_set(int(f0 + frac*(f1 - f0))); bpy.context.view_layer.update()
            tiles.append(shot(Vector((0, 0, 0.88*SC)), d, 2.1*SC, (300, 460)))
        rows.append(np.concatenate(tiles, 1))
    save(np.concatenate(rows[::-1], 0), f"acc_{CHAR}_poses.png")
    rig.animation_data.action = None

try:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
    for o in list(bpy.data.objects):
        if o.name.startswith(("Hair_", "Hat_", "Sash_")): bpy.data.objects.remove(o, do_unlink=True)
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    hair = build_hair(body, rig); hat = build_ngob(body, rig); sash = build_sash(body, rig)
    for o in hair + [hat, sash]:
        L(o.name, "tris", sum(len(p.vertices) - 2 for p in o.data.polygons), "bones", [g.name for g in o.vertex_groups])
    if "--save" in argv:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_mainfile(); L("saved", bpy.data.filepath)
    if "--render" in argv:
        out = argv[argv.index("--render") + 1]; os.makedirs(out, exist_ok=True)
        renders(out, body, rig, hair, hat, sash); L("renders", out)
except Exception:
    L(traceback.format_exc())
ACC_REPORT = "\n".join(log)
