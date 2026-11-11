# Assemble and export villager_ghost_male.fbx and villager_ghost_female.fbx WITHOUT any Cloth_* body meshes!
# All clothing is painted on BodyUpper / LowerSkirt / LowerWide; only essential rigid props & hair remain.
import bpy, bmesh, os, sys, math, shutil, re, time, traceback
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
GH = os.path.join(MODELS, "human_ghosts")
TEX = os.path.join(HERE, "textures")
OUT = os.path.join(HERE, "design")
UP = os.path.join(HERE, "upload")
STUDS_PER_M = 3.5
log = []
def L(*a): log.append(" ".join(str(x) for x in a)); print(*a)

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
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(t("_Normal", True).outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    return m

def split_body(body):
    me = body.data; pa = me.attributes["part"].data
    def key(co, c): return (round(co.x, 5), round(co.y, 5), round(co.z, 5), round(c.x, 5), round(c.y, 5), round(c.z, 5))
    nrm = {}
    for p in me.polygons:
        for li in p.loop_indices: nrm[key(me.vertices[me.loops[li].vertex_index].co, p.center)] = me.corner_normals[li].vector.copy()
    pieces = []
    for k, name in enumerate(("BodyHead", "BodyUpper", "BodyLower")):
        ob = body.copy(); ob.data = me.copy(); ob.name = name; ob.data.name = name
        for c in body.users_collection: c.objects.link(ob)
        bm = bmesh.new(); bm.from_mesh(ob.data); lay = bm.faces.layers.int.get("part")
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f[lay] != k], context='FACES'); bm.to_mesh(ob.data); bm.free()
        pm = ob.data
        pm.normals_split_custom_set([nrm[key(pm.vertices[pm.loops[li].vertex_index].co, p.center)] for p in pm.polygons for li in p.loop_indices])
        pieces.append(ob)
    return pieces

def append_meshes(blend_path, names, rig):
    out = []
    for n in names:
        with bpy.data.libraries.load(blend_path, link=False) as (src, dst):
            if n in src.objects:
                dst.objects = [n]
        for ob in dst.objects:
            if not ob: continue
            ob.name = n; ob.data.name = n
            bpy.context.scene.collection.objects.link(ob)
            for m in list(ob.modifiers):
                if m.type == 'ARMATURE':
                    m.object = rig
            if not any(m.type == 'ARMATURE' for m in ob.modifiers):
                m = ob.modifiers.new(name="Armature", type='ARMATURE')
                m.object = rig
            for v in ob.data.vertices:
                gs = sorted([(g.group, g.weight) for g in v.groups if g.weight > 1e-4], key=lambda x: -x[1])
                for g, _ in gs[4:]:
                    ob.vertex_groups[g].remove([v.index])
            out.append(ob)
    return out

def push_outside_v2(ob, trees, clear=0.0035, z_max=99.0):
    w = ob.matrix_world; wi = w.inverted(); disp = {}
    for v in ob.data.vertices:
        p = w @ v.co; p0 = p.copy()
        if p.z > z_max: continue
        for tree in trees:
            loc, n, _, d = tree.find_nearest(p, 0.06)
            if loc is None: continue
            side = (p - loc).dot(n)
            if side < clear and side > -0.045:
                p = p + n*(clear - side)
        if (p - p0).length > 1e-5:
            disp[v.index] = wi.to_3x3() @ (p - p0)
    if not disp: return 0
    nb = [[] for _ in ob.data.vertices]
    for e in ob.data.edges:
        a, c = e.vertices; nb[a].append(c); nb[c].append(a)
    for _ in range(3):
        new = dict(disp)
        for i, dv in disp.items():
            for j in nb[i]:
                sp = dv*0.55
                if j not in new or new[j].length < sp.length: new[j] = sp
        disp = new
    for i, dv in disp.items():
        ob.data.vertices[i].co += dv
    ob.data.update()
    return len(disp)

def make_neck_stump_v2(body_upper, rig):
    me = body_upper.data; mw = body_upper.matrix_world
    cnt = {}
    for p in me.polygons:
        vs = list(p.vertices)
        for k in range(len(vs)):
            e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)])))
            cnt[e] = cnt.get(e, 0) + 1
    nbr = {}
    for (a, b), c in cnt.items():
        if c == 1 and (mw @ me.vertices[a].co).z > 1.30 and (mw @ me.vertices[b].co).z > 1.30:
            nbr.setdefault(a, []).append(b); nbr.setdefault(b, []).append(a)
    v0 = next(iter(nbr))
    loop = [v0]; seen = {v0}; cur = v0
    while True:
        nx = [n for n in nbr[cur] if n not in seen]
        if not nx: break
        cur = nx[0]; loop.append(cur); seen.add(cur)
    P = [mw @ me.vertices[i].co for i in loop]
    nb = rig.data.bones["neck"]; U = (rig.matrix_world.to_3x3() @ (nb.tail_local - nb.head_local)).normalized()
    F = Vector((0, -1, 0)); F = (F - U*F.dot(U)).normalized(); L_ = U.cross(F)
    c = sum(P, Vector())/len(P)
    R_ = max(((p - c) - U*(p - c).dot(U)).length for p in P)
    def uv_of(p):
        d = p - c; return (0.5 + 0.48*d.dot(L_)/R_, 0.5 + 0.48*d.dot(F)/R_)
    verts = []; faces = []; uvs = []; weights = []
    def bw(vi):
        g = {body_upper.vertex_groups[x.group].name: x.weight for x in me.vertices[vi].groups if x.weight > 0}
        tot = sum(g.values()) or 1.0
        return {k: w/tot for k, w in g.items()}
    rim = []
    for p, vi in zip(P, loop):
        rim.append(len(verts)); verts.append(p); weights.append(bw(vi))
    mid = []
    for p in P:
        mid.append(len(verts)); verts.append(c + (p - c)*0.62 + U*0.0055); weights.append({"neck": 1.0})
    cen = len(verts); verts.append(c + U*0.009); weights.append({"neck": 1.0})
    n = len(P)
    flip = (P[0] - c).cross(P[1] - c).dot(U) < 0
    for k in range(n):
        k2 = (k + 1) % n
        q = [rim[k], rim[k2], mid[k2], mid[k]]
        quv = [uv_of(P[k]), uv_of(P[k2]), uv_of(c + (P[k2] - c)*0.62), uv_of(c + (P[k] - c)*0.62)]
        if flip: q, quv = q[::-1], quv[::-1]
        faces.append(q); uvs.append(quv)
        t = [mid[k], mid[k2], cen]
        tuv = [uv_of(c + (P[k] - c)*0.62), uv_of(c + (P[k2] - c)*0.62), (0.5, 0.5)]
        if flip: t, tuv = t[::-1], tuv[::-1]
        faces.append(t); uvs.append(tuv)
    nm = bpy.data.meshes.new("NeckStump")
    nm.from_pydata([tuple(v) for v in verts], [], faces)
    lay = nm.uv_layers.new(name="UVMap")
    for p, fuv in zip(nm.polygons, uvs):
        for li, uv in zip(p.loop_indices, fuv): lay.data[li].uv = uv
    for p in nm.polygons: p.use_smooth = True
    ob = bpy.data.objects.new("NeckStump", nm)
    bpy.context.scene.collection.objects.link(ob)
    for b in rig.data.bones: ob.vertex_groups.new(name=b.name)
    for vi, wdict in enumerate(weights):
        for bname, wval in wdict.items():
            ob.vertex_groups[bname].add([vi], wval, 'REPLACE')
    mod = ob.modifiers.new(name="Armature", type='ARMATURE'); mod.object = rig
    return ob

def add_carrier_cards(items, rig):
    cards = []
    for idx, (cname, base) in enumerate(items):
        me = bpy.data.meshes.new(cname)
        x0 = idx * 0.08
        me.from_pydata([(x0, 0, 0), (x0 + 0.05, 0, 0), (x0 + 0.05, 0, 0.05)], [], [(0, 1, 2)])
        lay = me.uv_layers.new(name="UVMap")
        for li, uv in enumerate(((0, 0), (1, 0), (1, 1))): lay.data[li].uv = uv
        me.materials.append(tex_material(cname, base))
        ob = bpy.data.objects.new(cname, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.vertex_groups.new(name="root").add([0, 1, 2], 1.0, 'REPLACE')
        mod = ob.modifiers.new(name="Armature", type='ARMATURE'); mod.object = rig
        cards.append(ob)
    return cards

def fbx_export(path, rig, meshes):
    for o in meshes:
        o.hide_viewport = False; o.hide_set(False); o.hide_render = False
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes + [rig]: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    for attempt in range(5):
        try:
            bpy.ops.export_scene.fbx(
                filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'}, global_scale=STUDS_PER_M,
                apply_scale_options='FBX_SCALE_NONE', axis_forward='-Z', axis_up='Y', bake_space_transform=False,
                add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=True,
                mesh_smooth_type='FACE', path_mode='COPY', embed_textures=False, bake_anim=False, use_mesh_modifiers=False
            )
            break
        except RuntimeError:
            time.sleep(1.5*(attempt + 1))
    data = open(path, "rb").read()
    copied = 0
    for n in sorted(set(m.decode("latin1") for m in re.findall(rb"[\w\-]+\.png", data))):
        src = os.path.join(TEX, n)
        if os.path.exists(src):
            shutil.copyfile(src, os.path.join(UP, n))
            copied += 1
    shutil.rmtree(path[:-4] + ".fbm", ignore_errors=True)
    L("exported", os.path.basename(path), "meshes:", len(meshes), "copied PNGs:", copied)

def build_male_fbx():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_male.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    for o in list(bpy.data.objects):
        if o.name.startswith("_") or o.name in ("Hair_long_white_beard", "Hat_ngob"):
            bpy.data.objects.remove(o, do_unlink=True)
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    pieces = split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    bpy.data.objects["Lower_wide"].name = "LowerWide"
    bpy.data.objects["Lower_skirt"].name = "LowerSkirt"

    # Append ONLY rigid head props (Prop_JawTie, Prop_TaKhonMask) — ZERO Cloth_* meshes!
    jaw = append_meshes(os.path.join(GH, "ghost_shroud.blend"), ["Prop_JawTie"], rig)
    mask = append_meshes(os.path.join(GH, "ghost_ta_khon.blend"), ["Prop_TaKhonMask"], rig)
    for o in jaw:
        push_outside_v2(o, [t_body], clear=0.0035)

    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.materials.clear()
    for name, base in (("BodyHead", "g_male_ghost_head"), ("BodyUpper", "g_funeral_m_upper"),
                       ("LowerWide", "g_funeral_m_lower"), ("LowerSkirt", "g_shroud_lower")):
        ob = bpy.data.objects[name]
        ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    cards = add_carrier_cards([
        ("Tex_g_male_withered_head", "g_male_withered_head"),
        ("Tex_g_shroud_upper",       "g_shroud_upper"),
    ], rig)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
    fbx_export(os.path.join(UP, "villager_ghost_male.fbx"), rig, meshes)

def build_female_fbx():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_female.blend"))
    rig = bpy.data.objects["HumanRig"]; body = bpy.data.objects["Body"]
    if rig.animation_data: rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    for o in list(bpy.data.objects):
        if o.name.startswith("_") or o.name in ("Hat_ngob", "Sash_pakama", "Lower_wide", "Hair_bob", "Hair_ponytail_bow", "Hair_curly_grey"):
            bpy.data.objects.remove(o, do_unlink=True)

    # Add Pop's 3 tongue bones (tongue_01..03) to HumanRig
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode='EDIT')
    eb = rig.data.edit_bones
    dy = -0.004
    t1 = eb.new("tongue_01"); t1.head = Vector((-0.0084, -0.0467 + dy, 1.5191)); t1.tail = Vector((-0.0046, -0.0637 + dy, 1.5084)); t1.parent = eb["head"]
    t2 = eb.new("tongue_02"); t2.head = Vector((-0.0046, -0.0637 + dy, 1.5084)); t2.tail = Vector((-0.0025, -0.0730 + dy, 1.5026)); t2.parent = t1
    t3 = eb.new("tongue_03"); t3.head = Vector((-0.0025, -0.0730 + dy, 1.5026)); t3.tail = Vector((-0.0007, -0.0807 + dy, 1.4978)); t3.parent = t2
    bpy.ops.object.mode_set(mode='OBJECT')

    sk_ob = bpy.data.objects["Lower_skirt"]
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    t_skirt = BVHTree.FromPolygons([sk_ob.matrix_world @ v.co for v in sk_ob.data.vertices], [list(p.vertices) for p in sk_ob.data.polygons])

    pieces = split_body(body)
    bpy.data.objects.remove(body, do_unlink=True)
    bpy.data.objects.remove(bpy.data.objects["BodyLower"], do_unlink=True)
    sk_ob.name = "LowerSkirt"
    body_upper = bpy.data.objects["BodyUpper"]

    # Build NeckStump directly on BodyUpper's 24-vertex neck ring
    stump = make_neck_stump_v2(body_upper, rig)

    # Append original ghost hairs (Hair_ghost_long used for Tani, Mirror, and Mae Nak; Hair_ghost_messy; Pop_Hair) & rigid props
    hairs = []
    hairs += append_meshes(os.path.join(GH, "ghost_mirror.blend"), ["Hair_ghost_long"], rig)
    hairs += append_meshes(os.path.join(GH, "ghost_funeral_woman.blend"), ["Hair_ghost_messy"], rig)
    append_meshes(os.path.join(GH, "ghost_mae_nak.blend"), ["Prop_Baby"], rig)
    append_meshes(os.path.join(GH, "ghost_dancer.blend"), [
        "Cloth_ghost_dancer_crown", "Cloth_ghost_dancer_flowers"
    ], rig)
    append_meshes(os.path.join(MODELS, "pop.blend"), ["Pop_Eyes", "Pop_Fangs", "Pop_Tongue", "Pop_Hair"], rig)
    hairs.append(bpy.data.objects["Pop_Hair"])

    for v in bpy.data.objects["Pop_Eyes"].data.vertices: v.co.y -= 0.0115
    for n in ("Pop_Fangs", "Pop_Tongue"):
        for v in bpy.data.objects[n].data.vertices: v.co.y -= 0.004

    zn = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    for o in hairs:
        n = push_outside_v2(o, [t_body, t_skirt], clear=0.0040, z_max=zn)
        L("female hair fit", o.name, "pushed verts:", n)

    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.materials.clear()
    for name, base in (("BodyHead", "g_female_ghost_head"), ("BodyUpper", "g_tani_upper"), ("LowerSkirt", "g_tani_lower")):
        ob = bpy.data.objects[name]
        ob.data.materials.append(tex_material(name, base))
        for p in ob.data.polygons: p.material_index = 0
    cards = add_carrier_cards([
        ("Tex_g_female_withered_head", "g_female_withered_head"),
        ("Tex_g_female_dancer_head",   "g_female_dancer_head"),
        ("Tex_g_female_pop_head",      "g_female_pop_head"),
        ("Tex_g_thai_upper",           "g_thai_upper"),
        ("Tex_g_nak_upper",            "g_nak_upper"),
        ("Tex_g_funeral_f_upper",      "g_funeral_f_upper"),
        ("Tex_g_dancer_upper",         "g_dancer_upper"),
        ("Tex_g_pop_upper",            "g_pop_upper"),
        ("Tex_g_thai_lower",           "g_thai_lower"),
        ("Tex_g_nak_lower",            "g_nak_lower"),
        ("Tex_g_funeral_f_lower",      "g_funeral_f_lower"),
        ("Tex_g_dancer_lower",         "g_dancer_lower"),
        ("Tex_g_pop_lower",            "g_pop_lower"),
    ], rig)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]
    fbx_export(os.path.join(UP, "villager_ghost_female.fbx"), rig, meshes)

if __name__ == "__main__":
    try:
        # Clean old ghost PNGs from upload/ first
        for fn in os.listdir(UP):
            if fn.startswith("g_") or fn.startswith("villager_ghost_"):
                os.remove(os.path.join(UP, fn))
        build_male_fbx()
        build_female_fbx()
        L("BOTH PAINTED-CLOTH GHOST FBX EXPORTED OK")
    except Exception:
        L(traceback.format_exc())
    open(os.path.join(OUT, "ghosts_v2_export_report.txt"), "w", encoding="utf-8").write("\n".join(log))
