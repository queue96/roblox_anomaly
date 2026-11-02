# Skin showing through clothes, for every outfit x every animation clip of a character.
# For each body vertex an outfit is meant to cover, a ray goes out along the (posed) skin normal: if it meets
# none of the outfit's pieces, that bit of skin is outside the cloth, i.e. poking through.
#
#   exec(open(r"...\human_base\check_clothes.py", encoding="utf-8").read())
#   rows = check_char("female")          # current scene must be that character's .blend (clothes + clips in it)
#   report(rows)                         # text table: outfit, clip, frames with skin out, worst frame (vertices)
#
# Covered = the body faces under a shell piece (minus its hem edge), the trunk and legs between the waist and
# 6 cm above the hem of a skirt, the head inside a helmet. Bands, sashes, scarves and jewellery cover nothing.
# Skin that Roblox hides under the outfit (build_clothes.hidden_faces) is left out: it can't show.
import bpy, math, os, json
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

_HB = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:\Aunival\pump-lot-anomaly\assets\models\human_base"
_CL = {"__name__": "check_clothes"}
exec(open(os.path.join(r"C:\Aunival\pump-lot-anomaly\assets\models\human_base", "build_clothes.py"), encoding="utf-8").read(), _CL)

def covered(char, outfit, body, rig, b, faces):
    me = body.data; out = set()
    for sp in _CL["OUTFITS"][outfit]:
        kind = sp[0]
        if kind == "shell":
            fs = faces[outfit][sp[1]]; fset = set(fs)
            cnt = {}
            for fi in fs:
                vs = list(me.polygons[fi].vertices)
                for k in range(len(vs)):
                    e = tuple(sorted((vs[k], vs[(k + 1) % len(vs)]))); cnt[e] = cnt.get(e, 0) + 1
            edge = {v for e, c in cnt.items() if c == 1 for v in e}
            for fi in fs: out.update(v for v in me.polygons[fi].vertices if v not in edge)
        elif kind == "tube" and not sp[5].get("band"):
            ob = bpy.data.objects.get(f"Cloth_{outfit}_{sp[1]}")
            if not ob: continue
            zs = [v.co.z for v in ob.data.vertices]; z0, z1 = max(zs), min(zs)
            for i in range(len(me.vertices)):
                # the last 6 cm above the hem is only seen from under the skirt (the hem lifts a little in a step)
                if b.reg[i] in ("torso", "leg.L", "leg.R") and z1 + 0.06*b.s < b.co[i][2] < z0 - 0.02*b.s: out.add(i)
        elif kind == "helmet" and sp[1] == "helmet":
            zc = b.J["head"][0][2] + 0.06*b.s                    # skip the jaw: the helmet is open underneath
            out.update(i for i in range(len(me.vertices)) if b.reg[i] == "head" and b.co[i][2] > zc)
    # skin cut out under the outfit in Roblox (build_clothes.hidden_faces) can't show: only check what stays
    hid = set(_CL["hidden_faces"](me, {outfit: faces[outfit]})[outfit])
    shown = {v for p in me.polygons if p.index not in hid for v in p.vertices}
    return sorted(out & shown)

def outfit_objects(outfit):
    return [o for o in bpy.data.objects if o.name == f"Cloth_{outfit}" or o.name.startswith(f"Cloth_{outfit}_")]

def exposed(body, objs, idx, deps):
    """indices (from idx) whose skin is outside every piece in objs, in the current frame"""
    verts, polys = [], []
    for o in objs:
        me = o.evaluated_get(deps).to_mesh(); mw = o.matrix_world; base = len(verts)
        verts += [mw @ v.co for v in me.vertices]; polys += [[base + i for i in p.vertices] for p in me.polygons]
        o.evaluated_get(deps).to_mesh_clear()
    bvh = BVHTree.FromPolygons(verts, polys)
    # lowest edge of any skirt in this frame: a ray that drops below it left through the open hem, not through cloth
    hem = None
    for o in objs:
        if any(k in o.name for k in ("_sin", "_sarong")):
            me = o.evaluated_get(deps).to_mesh(); z = min((o.matrix_world @ v.co).z for v in me.vertices)
            o.evaluated_get(deps).to_mesh_clear(); hem = z if hem is None else min(hem, z)
    be = body.evaluated_get(deps); bm = be.to_mesh(); mw = body.matrix_world; nm = mw.to_3x3()
    bad = []
    for i in idx:
        v = bm.vertices[i]; p = mw @ v.co; n = (nm @ v.normal).normalized()
        if n.z < -0.3: continue                          # points down out of a skirt's open hem (or a sleeve end)
        if bvh.ray_cast(p + n*0.001, n, 0.5)[0] is None:
            if hem is not None and n.z < 0 and p.z + n.z*0.5 < hem: continue      # out through the hem opening
            bad.append(i)
    be.to_mesh_clear()
    return bad

def check_char(char, clips=None, step=3, outfits=None):
    body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]; sc = bpy.context.scene
    keep_act = rig.animation_data.action if rig.animation_data else None
    if rig.animation_data: rig.animation_data.action = None
    for p in rig.pose.bones: p.rotation_euler = (0, 0, 0); p.location = (0, 0, 0)
    bpy.context.view_layer.update()
    b = _CL["Body"](body, rig)
    faces = json.load(open(os.path.join(_CL["char_dir"](char), _CL["NAMES"][char] + "_clothes.json")))["outfits"]
    clips = clips or [a.name for a in bpy.data.actions if a.use_fake_user]
    rows = []
    for outfit in outfits or _CL["CHAR_OUTFITS"][char]:
        idx = covered(char, outfit, body, rig, b, faces); objs = outfit_objects(outfit)
        if not idx or not objs: continue
        long_skirt = any(sp[0] == "tube" and not sp[5].get("band") for sp in _CL["OUTFITS"][outfit])
        for clip in clips:
            # long skirts walk and run with the *_skirt clips; everyone else with the normal ones
            if long_skirt and clip in ("walk", "run"): continue
            if not long_skirt and clip.endswith("_skirt"): continue
            rig.animation_data.action = bpy.data.actions[clip]
            f0, f1 = (int(x) for x in bpy.data.actions[clip].frame_range)
            worst, nbad, where = 0, 0, {}
            for f in range(f0, f1 + 1, step):
                sc.frame_set(f); deps = bpy.context.evaluated_depsgraph_get()
                bad = exposed(body, objs, idx, deps)
                if len(bad) >= 2:
                    nbad += 1
                    for i in bad: where[b.reg[i]] = where.get(b.reg[i], 0) + 1
                if len(bad) > worst: worst = len(bad)
            rows.append((outfit, clip, nbad, len(range(f0, f1 + 1, step)), worst, dict(sorted(where.items(), key=lambda t: -t[1])[:3])))
    rig.animation_data.action = keep_act
    return rows

def report(rows, only_bad=True):
    lines = []
    for outfit, clip, nbad, n, worst, where in rows:
        if only_bad and nbad == 0: continue
        lines.append(f"{outfit:14s} {clip:13s} {nbad:3d}/{n:<3d} frames  worst {worst:3d} verts  {where}")
    return "\n".join(lines) or "no skin through cloth"
