# build_tani_hair_v2.py — rebuild Tani's / Mae Nak's long ghost hair as TWO single-bone pieces (user 2026-11-16 "ปั้นผมใหม่")
#
# Why: in Roblox the old Hair_ghost_long (one mesh weighted head/neck/chest/spine) does not follow the head at all
#   (Studio test: head bone tilted 60 deg -> the head pokes out of the hair, the hair stays put), so when the ghost
#   bows its head in game it looks bald. Every hair/hat that works in game is weighted to ONE bone
#   (Dancer crown, Pop_Hair, Hair_bun_grey = head only).
# Result:
#   Hair_ghost_top  = scalp + hair down to just below the neck base, 100% head
#   Hair_ghost_back = the long curtain down the back, 100% chest
#   (they overlap OVERLAP m around the cut so no gap opens when the head bows)
# Same source shape and fit as export_ghosts_v2.build_female_fbx (Hair_ghost_long from ghost_mirror.blend pushed
# outside the v2 female body/skirt), same rig and FBX settings -> drops straight into ghost_tani / ghost_mae_nak.
# Output: assets/models/TaniHairV2/upload/tani_hair_v2.fbx + previews in assets/models/TaniHairV2/
import bpy, bmesh, os, sys, math, traceback
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
GH = os.path.join(MODELS, "human_ghosts")
OUTD = os.path.join(MODELS, "TaniHairV2")
UP = os.path.join(OUTD, "upload")
os.makedirs(UP, exist_ok=True)
OVERLAP = 0.035  # m each side of the cut

# reuse the helpers of the ghost export (append_meshes / push_outside_v2 / fbx_export)
eg = {"__file__": os.path.join(HERE, "export_ghosts_v2.py"), "__name__": "eg"}
exec(compile(open(eg["__file__"], encoding="utf-8").read(), "export_ghosts_v2.py", "exec"), eg)
eg["UP"] = UP


def keep_side(ob, z, keep_above):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    mw = ob.matrix_world
    # plane in object space (object has identity transform after append, but be safe)
    co = mw.inverted() @ Vector((0, 0, z))
    no = (mw.inverted().to_3x3() @ Vector((0, 0, 1))).normalized()
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=keep_above, clear_outer=not keep_above)
    bm.to_mesh(ob.data)
    bm.free()


def single_bone(ob, bone):
    ob.vertex_groups.clear()
    g = ob.vertex_groups.new(name=bone)
    g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")


def build():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE, "villager_female.blend"))
    rig = bpy.data.objects["HumanRig"]
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0); pb.location = (0, 0, 0)
    body = bpy.data.objects["Body"]
    sk = bpy.data.objects["Lower_skirt"]
    t_body = BVHTree.FromPolygons([body.matrix_world @ v.co for v in body.data.vertices], [list(p.vertices) for p in body.data.polygons])
    t_skirt = BVHTree.FromPolygons([sk.matrix_world @ v.co for v in sk.data.vertices], [list(p.vertices) for p in sk.data.polygons])
    zn = (rig.matrix_world @ rig.data.bones["head"].head_local).z
    z_neck = (rig.matrix_world @ rig.data.bones["neck"].head_local).z  # base of the neck = where the cut goes

    hair = eg["append_meshes"](os.path.join(GH, "ghost_mirror.blend"), ["Hair_ghost_long"], rig)[0]
    n = eg["push_outside_v2"](hair, [t_body, t_skirt], clear=0.0040, z_max=zn)
    print("TANIHAIR| fitted, pushed verts", n, "head z %.3f neck z %.3f" % (zn, z_neck))

    top = hair.copy(); top.data = hair.data.copy(); top.name = top.data.name = "Hair_ghost_top"
    back = hair.copy(); back.data = hair.data.copy(); back.name = back.data.name = "Hair_ghost_back"
    for o in (top, back):
        bpy.context.scene.collection.objects.link(o)
    bpy.data.objects.remove(hair, do_unlink=True)
    keep_side(top, z_neck - OVERLAP, True)
    keep_side(back, z_neck + OVERLAP, False)
    single_bone(top, "head")
    single_bone(back, "chest")
    for o in (top, back):
        o.data.materials.clear()
        m = bpy.data.materials.get("HairGhost") or bpy.data.materials.new("HairGhost")
        m.diffuse_color = (0.11, 0.10, 0.094, 1)
        o.data.materials.append(m)
        print("TANIHAIR|", o.name, "verts", len(o.data.vertices), "faces", len(o.data.polygons))

    # keep only the rig + the two hair pieces for export (body stays for the preview, hidden from export by selection)
    eg["fbx_export"](os.path.join(UP, "tani_hair_v2.fbx"), rig, [top, back])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTD, "tani_hair_v2.blend"))
    return rig, body, sk, top, back


def preview(rig, body, sk, top, back):
    """Rest / head bowed 30 / head tilted 45 / head turned 50 — the hair must stay on the head in every frame."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.78, 0.8, 1)
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in (body, sk, top, back):
            o.hide_render = True

    def flat(name, rgb):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*rgb, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
        return m
    # preview colours only (render after export): hair near-black like the game, body grey, skirt green
    for o, mat in ((top, flat("_pv_hair", (0.02, 0.02, 0.02))), (back, flat("_pv_hair_b", (0.05, 0.02, 0.02))),
                   (body, flat("_pv_body", (0.55, 0.55, 0.58))), (sk, flat("_pv_skirt", (0.1, 0.25, 0.12)))):
        o.data.materials.clear(); o.data.materials.append(mat)
    for nm, rot, e in (("_key", (55, 0, -35), 3.2), ("_fill", (70, 0, 55), 1.4)):
        l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN")); l.data.energy = e
        l.rotation_euler = [math.radians(a) for a in rot]; sc.collection.objects.link(l)
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = 1.15
    sc.render.resolution_x, sc.render.resolution_y = 260, 300
    tgt = Vector((0, 0, 1.35))
    poses = [("rest", Quaternion()), ("bow", Quaternion((1, 0, 0), math.radians(30))),
             ("tilt", Quaternion((0, 1, 0), math.radians(45))), ("turn", Quaternion((0, 0, 1), math.radians(50)))]
    import numpy as np
    rows = []
    for view in (Vector((0.42, -0.90, 0.08)), Vector((-0.5, 0.86, 0.1))):  # front 3/4, back 3/4
        d = view.normalized()
        cam.location = tgt + d * 4.0; cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        tiles = []
        for name, q in poses:
            hb = rig.pose.bones["head"]; hb.rotation_mode = "QUATERNION"; hb.rotation_quaternion = q
            bpy.context.view_layer.update()
            tmp = os.path.join(OUTD, "_tile.png"); sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp); a = np.empty(im.size[0] * im.size[1] * 4, np.float32); im.pixels.foreach_get(a)
            tiles.append(a.reshape(im.size[1], im.size[0], 4)); bpy.data.images.remove(im); os.remove(tmp)
        rows.append(np.concatenate(tiles, 1))
    sheet = np.concatenate(rows[::-1], 0)
    o = bpy.data.images.new("s", sheet.shape[1], sheet.shape[0]); o.pixels.foreach_set(sheet.ravel())
    o.filepath_raw = os.path.join(OUTD, "tani_hair_v2_preview.png"); o.file_format = "PNG"; o.save()
    print("TANIHAIR| preview written")


if __name__ == "__main__":
    try:
        parts = build()
        preview(*parts)
        print("TANIHAIR| OK")
    except Exception:
        traceback.print_exc()
        print("TANIHAIR| FAILED")
