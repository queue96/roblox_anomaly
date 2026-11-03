# ตรวจท่ากระสือว่าทะลุกันไหม + ภาพรวมเฟรมสำคัญของทุกท่า — Blender headless (เปิด krasue.blend ที่ krasue.py สร้าง)
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\krasue_check_anim.py -Out C:\tmp\krasue_check.txt
# ทุกเฟรมของทุกท่า: นับคู่สามเหลี่ยมที่ทะลุกัน (BVH overlap) ระหว่างชิ้น/ก้อน เทียบกับท่าพัก
#   hair-head = ผมทะลุหน้า/คอ, hair-organs = ผมทะลุอวัยวะ, head-organs = หลอดลม/เส้นเลือดทะลุผิวคอนอกตอคอ,
#   organs = ก้อนอวัยวะต่างก้อนทะลุกัน (ไส้กับปอด/หัวใจ ไส้ห้อยพับทะลุกันเอง)
#   ค่าที่เกินท่าพัก (+n) = ท่านั้นทำให้ทะลุเพิ่ม
# ภาพ: previews/Krasue_anim_sheet.png แถวละท่า คอลัมน์ = เฟรมสำคัญ (มุม 3/4 หน้า) + Krasue_anim_sheet_side.png (มุมข้าง)
import bpy, bmesh, os, sys, traceback
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "models")
PREV = os.path.join(ROOT, "previews")
KEYS = {"Float": [1, 16, 31, 46], "Lunge": [1, 9, 15, 23, 31], "Sniff": [1, 14, 22, 36, 49], "HairWhip": [1, 7, 13, 20, 26]}
LOG = []


def log(*a):
    LOG.append(" ".join(str(x) for x in a))


def islands(bm):
    bm.faces.ensure_lookup_table()
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        st, grp = [f], []
        seen.add(f.index)
        while st:
            x = st.pop()
            grp.append(x)
            for e in x.edges:
                for y in e.link_faces:
                    if y.index not in seen:
                        seen.add(y.index)
                        st.append(y)
        out.append(grp)
    return out


def evaluated(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    bm.from_object(ob, dg)
    bm.transform(ob.matrix_world)
    return bm


def bvh_of(bm, faces=None):
    if faces is None:
        return BVHTree.FromBMesh(bm)
    vs = sorted({v.index for f in faces for v in f.verts})
    remap = {v: i for i, v in enumerate(vs)}
    bm.verts.ensure_lookup_table()
    return BVHTree.FromPolygons([bm.verts[v].co.copy() for v in vs], [[remap[v.index] for v in f.verts] for f in faces])


def measure(objs, org_isl):
    hb, hd, og = evaluated(objs["Krasue_Hair"]), evaluated(objs["Krasue"]), evaluated(objs["Krasue_Organs"])
    th, td, to = bvh_of(hb), bvh_of(hd), bvh_of(og)
    og.faces.ensure_lookup_table()
    parts = [bvh_of(og, [og.faces[i] for i in isl]) for isl in org_isl]
    r = {"hair-head": len(th.overlap(td)), "hair-organs": len(th.overlap(to)), "head-organs": len(td.overlap(to))}
    pairs = {}
    for i in range(len(parts)):
        for j in range(i + 1, len(parts)):
            k = len(parts[i].overlap(parts[j]))
            if k:
                pairs[(i, j)] = k
    r["organs"] = sum(pairs.values())
    r["_pairs"] = pairs
    for b in (hb, hd, og):
        b.free()
    return r


def set_clip(arm, name):
    arm.animation_data.action = bpy.data.actions[name]
    try:
        if len(bpy.data.actions[name].slots):
            arm.animation_data.action_slot = bpy.data.actions[name].slots[0]
    except AttributeError:
        pass


def rest(arm):
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def sheet(arm, objs, d, path, px=330):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.display.shading.show_cavity = True
    scn.render.resolution_x = scn.render.resolution_y = px
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.1
    c = Vector((0, -0.2, -0.32))
    cam.location = c + Vector(d).normalized() * 3
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    rows = []
    ncol = max(len(v) for v in KEYS.values())
    for clip, frames in KEYS.items():
        set_clip(arm, clip)
        row = []
        for f in frames + [None] * (ncol - len(frames)):
            if f is None:
                row.append(np.full((px, px, 4), (0.2, 0.2, 0.2, 1), np.float32))
                continue
            scn.frame_set(f)
            tmp = path[:-4] + "_t.png"
            scn.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp)
            a = np.empty(px * px * 4, np.float32)
            im.pixels.foreach_get(a)
            row.append(a.reshape(px, px, 4))
            bpy.data.images.remove(im)
            os.remove(tmp)
        rows.append(np.concatenate(row, 1))
    sh = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("_sheet", sh.shape[1], sh.shape[0])
    img.pixels.foreach_set(sh.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.objects.remove(cam)


def main():
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "krasue.blend"))
    objs = {o.name: o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("Krasue")}
    arm = bpy.data.objects["KrasueRig"]
    for o in objs.values():
        o.hide_render = False
    og = evaluated(objs["Krasue_Organs"])
    org_isl = [[f.index for f in isl] for isl in islands(og)]
    og.free()
    rest(arm)
    base = measure(objs, org_isl)
    log(f"organ pieces {len(org_isl)}; rest pose overlaps { {k: v for k, v in base.items() if k != '_pairs'} }")
    og = evaluated(objs["Krasue_Organs"])
    og.faces.ensure_lookup_table()
    for i, isl in enumerate(org_isl):   # ก้อนที่ i: จำนวนหน้า + จุดกลาง (ไว้ดูว่าเป็นอวัยวะไหน)
        c = sum((og.faces[f].calc_center_median() for f in isl), Vector()) / len(isl)
        log(f"   piece {i}: {len(isl)} faces at ({c.x:.3f}, {c.y:.3f}, {c.z:.3f})")
    og.free()
    worst = {}
    for clip in KEYS:
        set_clip(arm, clip)
        act = bpy.data.actions[clip]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        bad = []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            r = measure(objs, org_isl)
            extra = {k: r[k] - base[k] for k in r if k != "_pairs" and r[k] - base[k] > 0}
            if extra.get("organs"):
                extra["pairs"] = {f"{i}-{j}": n - base["_pairs"].get((i, j), 0) for (i, j), n in r["_pairs"].items()
                                  if n - base["_pairs"].get((i, j), 0) > 0}
            if extra:
                bad.append((f, extra))
            for k in base:
                if k == "_pairs":
                    continue
                worst[(clip, k)] = max(worst.get((clip, k), 0), r[k] - base[k])
        log(f"{clip} frames {f0}-{f1}: {len(bad)} frames with extra overlaps")
        for f, e in bad:
            log(f"   f{f}: {e}")
    log("worst extra per clip: " + (", ".join(f"{c}/{k}={v}" for (c, k), v in worst.items() if v > 0) or "none"))
    sheet(arm, objs, (-0.55, -1.25, 0.25), os.path.join(PREV, "Krasue_anim_sheet.png"))
    sheet(arm, objs, (1, 0, 0.1), os.path.join(PREV, "Krasue_anim_sheet_side.png"))
    log("sheets saved")


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "krasue_check.log")
try:
    main()
    LOG.append("DONE")
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
    open(OUT + ".done", "w").write("x")
