# mocap_retarget.py — แปลงท่า Mixamo (assets/models/mocap/*.fbx) ลงโครงกระดูก HumanRig 52 ชิ้นของเรา (2026-11-08)
#   ผู้ใช้: "แอนิเมชั่นมันแข็งมากๆ" -> เลือก mocap + ตัวหลัก 2 ตัว + เพ้นต์ + ชั้นชีวิต
# รัน (เปิดไฟล์ตัวละครเป็นไฟล์หลัก ไม่บันทึกทับ):
#   blender -b assets/models/human_base/human_base.blend --python tools/blender/mocap_retarget.py -- [--preview] [clip ...]
# ผลลัพธ์:
#   assets/models/mocap/out/<char>_mocap_anims.json   รูปแบบเดียวกับ build_anims.export_clip_data (rest + clips)
#       -> Studio: tools/studio/HumanAnimImport.luau H.build(model, data.rest, data.clips.<ชื่อ>, "<ชื่อ>") แล้ว publish ทับ ID เดิม
#   assets/models/mocap/out/<char>_mocap.blend        action ทุกท่า (ไว้ดู/แก้ต่อ) · <char>_mocap_preview.png เทียบท่าเดิม
#
# วิธี (ไม่พึ่งแกนกระดูก ใช้ทิศในโลก):
#   1) จับคู่กระดูก Mixamo -> ของเรา (MAP) · Spine1/Spine2 -> spine/chest (Spine ล่างสุดถูกรวมเข้าไป)
#   2) ท่าพักต่างกัน (Mixamo T-pose / ของเรา A-pose แขนลง 42°): แขนขาของเรา "หมุนให้ชี้ทิศเดียวกับท่าพักของ Mixamo" ก่อน
#      แล้วหาค่าคงที่ C = Rs0^-1 * Rt0' ต่อกระดูก
#   3) ทุกเฟรม: ทิศในโลกของกระดูกเรา = ทิศในโลกของกระดูก Mixamo * C -> แปลงเป็น matrix_basis (พ่อก่อนลูก)
#   4) สะโพกเลื่อน (ตำแหน่ง) ย่อตามสัดส่วนความสูงสะโพก · ท่าวนลูป: ช่วงท้ายค่อยๆ ผสมเข้าหาช่วงต้น (ต่อกันไม่กระตุก)
#   5) ท่านั่งรถ (MODE "add"): เอาเฉพาะการขยับลำตัว/คอ/หัว/ไหล่ของ mocap (เทียบเฟรมแรก) บวกทับท่าเดิมของเรา
#      แขนขาคงที่เดิม (ในเกมมือ/เท้าจับแฮนด์/ที่พักเท้าด้วย IK)
import bpy, math, os, sys, json
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
MOCAP = os.path.join(ROOT, "assets", "models", "mocap")
OUTD = os.path.join(MOCAP, "out")
os.makedirs(OUTD, exist_ok=True)
FPS = 30
STUDS_PER_M = 3.5

# ชื่อท่าในเกม -> (ไฟล์ mocap, โหมด, ตัวเลือก)
#   full = ทั้งตัว · add = บวกการขยับของลำตัวทับท่าเดิมใน action ชื่อ base · loop = ผสมท้ายเข้าต้น (เฟรม) · start/end = ตัดช่วง
CLIPS = {
    "idle":         ("Breathing Idle.fbx", "full", dict(loop=40)),
    "idle_weight":  ("Weight Shift.fbx", "full", dict(loop=40)),
    "idle_look":    ("Looking Around.fbx", "full", dict(loop=30)),
    "idle_bored":   ("Bored.fbx", "full", dict(loop=40)),
    "walk":         ("Walking.fbx", "full", dict(loop=0, inplace=True)),
    "ride_moto":    ("Sitting Idle.fbx", "add", dict(base="ride_moto", loop=30, gain=1.0)),
    "drive_car":    ("Driving.fbx", "add", dict(base="drive_car", loop=30, gain=0.8)),
    "drive_tuktuk": ("Sitting Idle.fbx", "add", dict(base="drive_tuktuk", loop=30, gain=0.9)),
    "talk":         ("Talking.fbx", "full", dict(loop=20)),
    "talk_2":       ("Talking (1).fbx", "full", dict(loop=20)),
    "wave":         ("Waving.fbx", "full", dict(loop=20)),
    "shrug":        ("Shrugging.fbx", "full", dict(loop=0)),
    "nod_yes":      ("Head Nod Yes.fbx", "full", dict(loop=0)),
    "shake_no":     ("Shaking Head No.fbx", "full", dict(loop=0)),
}
ELDER_CLIPS = {"idle_old": ("Old Man Idle.fbx", "full", dict(loop=40)),  # ยืนท่าเดิมใช้ Breathing Idle (Old Man Idle ก้มเอามือยันเข่าบ่อยเกิน)
               "walk": ("Old Man Walk.fbx", "full", dict(loop=0, inplace=True))}
FEMALE_CLIPS = {"walk": ("Female Walk.fbx", "full", dict(loop=0, inplace=True))}

MAP = {"hips": "Hips", "spine": "Spine1", "chest": "Spine2", "neck": "Neck", "head": "Head"}
for sd, S in (("L", "Left"), ("R", "Right")):
    MAP.update({f"shoulder.{sd}": f"{S}Shoulder", f"upper_arm.{sd}": f"{S}Arm", f"forearm.{sd}": f"{S}ForeArm", f"hand.{sd}": f"{S}Hand",
                f"thigh.{sd}": f"{S}UpLeg", f"shin.{sd}": f"{S}Leg", f"foot.{sd}": f"{S}Foot", f"toe.{sd}": f"{S}ToeBase"})
    for fg, F in (("thumb", "Thumb"), ("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Pinky")):
        for i in (1, 2, 3):
            MAP[f"{fg}_0{i}.{sd}"] = f"{S}Hand{F}{i}"
TORSO = {"hips", "spine", "chest", "neck", "head"}
# ทิศของกระดูก = จากข้อนี้ไปข้อถัดไป (แกน Y ของกระดูก Mixamo ที่นำเข้าเชื่อไม่ได้)
T_NEXT, S_NEXT = {}, {}
for sd, S in (("L", "Left"), ("R", "Right")):
    T_NEXT.update({f"shoulder.{sd}": f"upper_arm.{sd}", f"upper_arm.{sd}": f"forearm.{sd}", f"forearm.{sd}": f"hand.{sd}", f"hand.{sd}": f"middle_01.{sd}",
                   f"thigh.{sd}": f"shin.{sd}", f"shin.{sd}": f"foot.{sd}", f"foot.{sd}": f"toe.{sd}"})
    S_NEXT.update({f"{S}Shoulder": f"{S}Arm", f"{S}Arm": f"{S}ForeArm", f"{S}ForeArm": f"{S}Hand", f"{S}Hand": f"{S}HandMiddle1",
                   f"{S}UpLeg": f"{S}Leg", f"{S}Leg": f"{S}Foot", f"{S}Foot": f"{S}ToeBase", f"{S}ToeBase": f"{S}Toe_End"})
    for fg, F in (("thumb", "Thumb"), ("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Pinky")):
        for i in (1, 2):
            T_NEXT[f"{fg}_0{i}.{sd}"] = f"{fg}_0{i + 1}.{sd}"
            S_NEXT[f"{S}Hand{F}{i}"] = f"{S}Hand{F}{i + 1}"
        S_NEXT[f"{S}Hand{F}3"] = f"{S}Hand{F}4"
ADD_BONES = ["spine", "chest", "neck", "head", "shoulder.L", "shoulder.R"]   # โหมด add: บวกการขยับเฉพาะกระดูกเหล่านี้


def log(*a):
    print("MOCAP|", *a)


def rot3(m):
    r = m.to_3x3()
    r.normalize()
    return r


def swing(a, b):
    """การหมุนที่พาเวกเตอร์ a ไปชี้ทิศ b (สั้นที่สุด)"""
    a, b = a.normalized(), b.normalized()
    return a.rotation_difference(b).to_matrix()


def bfs(rig):
    out, todo = [], [b for b in rig.data.bones if b.parent is None]
    while todo:
        b = todo.pop(0)
        out.append(b)
        todo.extend(b.children)
    return out


def import_source(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    for o in new:
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    return arm


def retarget(rig, src, mode, opt, base_act=None):
    sc = bpy.context.scene
    act = src.animation_data.action
    f0, f1 = (int(round(x)) for x in act.frame_range)
    f0 = opt.get("start", f0)
    f1 = opt.get("end", f1)
    pre = "mixamorig:"
    sb = src.data.bones
    tb = rig.data.bones
    Ws, Wt = src.matrix_world, rig.matrix_world
    # ---- ท่าพัก (โลก) + หันหน้าทางเดียวกันไหม (ซ้าย-ขวาของสะโพก)
    def s_rest(n):
        return Ws @ sb[pre + n].matrix_local

    def t_rest(n):
        return Wt @ tb[n].matrix_local
    s_lr = (s_rest("LeftUpLeg").translation - s_rest("RightUpLeg").translation)
    t_lr = (t_rest("thigh.L").translation - t_rest("thigh.R").translation)
    G = Matrix.Identity(3)
    if s_lr.dot(t_lr) < 0:
        G = Matrix.Rotation(math.pi, 3, "Z")
        log("source faces the other way: rotating 180 deg")
    # ---- ค่าคงที่ต่อกระดูก
    C = {}
    for tn, sn in MAP.items():
        if tn not in tb or pre + sn not in sb:
            continue
        Rs0 = G @ rot3(s_rest(sn))
        Rt0 = rot3(t_rest(tn))
        if tn not in TORSO:
            # แขนขาของเรา: หมุนให้ชี้ทิศเดียวกับกระดูก Mixamo ตอนท่าพัก (T-pose) ก่อน (ทิศ = ข้อนี้ -> ข้อถัดไป)
            ts = tb[tn]
            tnx = tb.get(T_NEXT.get(tn, ""))
            dir_t = ((Wt @ tnx.head_local) if tnx else (Wt @ ts.tail_local)) - (Wt @ ts.head_local)
            ss = sb[pre + sn]
            snx = sb.get(pre + S_NEXT.get(sn, ""))
            dir_s = G @ (((Ws @ snx.head_local) if snx else (Ws @ ss.tail_local)) - (Ws @ ss.head_local))
            Rt0 = swing(dir_t, dir_s) @ Rt0
        C[tn] = Rs0.inverted() @ Rt0
    hips_ratio = (t_rest("hips").translation.z) / max(1e-4, s_rest("Hips").translation.z)
    hips_s0 = None
    order = [b for b in bfs(rig) if b.name in C]
    frames = list(range(f0, f1 + 1))
    out = {b.name: [] for b in order}  # basis quaternions
    hips_loc = []
    WtR = rot3(Wt).inverted()
    for f in frames:
        sc.frame_set(f)
        pose_rot = {}  # armature-space posed rotation of target bones (this frame)
        for b in order:
            spb = src.pose.bones[pre + MAP[b.name]]
            Rs = G @ rot3(Ws @ spb.matrix)
            A = WtR @ (Rs @ C[b.name])  # armature-space rotation wanted
            rest = rot3(b.matrix_local)
            if b.parent is None:
                basis = rest.inverted() @ A
            else:
                prest = rot3(b.parent.matrix_local)
                ppose = pose_rot.get(b.parent.name, prest)
                rel = prest.inverted() @ rest
                basis = rel.inverted() @ ppose.inverted() @ A
            pose_rot[b.name] = A
            out[b.name].append(basis.to_quaternion())
        # สะโพกเลื่อน (โลก -> armature -> แกนกระดูก hips) ย่อตามความสูงสะโพก
        hp = G @ (Ws @ src.pose.bones[pre + "Hips"].matrix).translation
        if hips_s0 is None:
            hips_s0 = hp.copy()
        d = (hp - hips_s0) * hips_ratio
        if opt.get("inplace"):
            d.x, d.y = 0.0, 0.0
        hips_loc.append(rot3(tb["hips"].matrix_local).inverted() @ (WtR @ d))
    # ---- โหมด add: การขยับของลำตัว (เทียบเฟรมแรก) บวกทับท่าเดิม
    if mode == "add":
        set_mode_for(rig, base_act)
        rig.animation_data.action = base_act
        sc.frame_set(int(base_act.frame_range[0]))
        base = {pb.name: pb.matrix_basis.to_quaternion() for pb in rig.pose.bones}
        gain = opt.get("gain", 1.0)
        res = {}
        for n in ADD_BONES:
            if n not in out:
                continue
            q0 = out[n][0]
            res[n] = []
            for q in out[n]:
                dq = q @ q0.inverted()
                dq = Quaternion().slerp(dq, gain)
                res[n].append(dq @ base[n])
        for n, q in base.items():
            if n not in res:
                res[n] = [q] * len(frames)
        out = res
        hips_loc = [Vector() for _ in frames]
    # ---- วนลูป: ช่วงท้าย K เฟรมผสมเข้าหาช่วงต้น
    K = min(opt.get("loop", 0), len(frames) // 3)
    if K > 0:
        L = len(frames) - K
        for n, qs in out.items():
            new = []
            for i in range(L + 1):
                if i < K:
                    s = i / K
                    s = s * s * (3 - 2 * s)
                    a, b2 = qs[L + i], qs[i]
                    if a.dot(b2) < 0:
                        b2 = -b2
                    new.append(a.slerp(b2, s))
                else:
                    new.append(qs[i])
            out[n] = new
        hl = []
        for i in range(L + 1):
            if i < K:
                s = i / K
                s = s * s * (3 - 2 * s)
                hl.append(hips_loc[L + i].lerp(hips_loc[i], s))
            else:
                hl.append(hips_loc[i])
        hips_loc = hl
    n_frames = len(next(iter(out.values())))
    return out, hips_loc, n_frames


def action_fcurves(act):
    """Blender 5: F-curves อยู่ใต้ layers/strips/channelbags (act.fcurves ไม่มีแล้ว)"""
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for cb in getattr(strip, "channelbags", []):
                out.extend(cb.fcurves)
    return out


def set_mode_for(rig, act):
    """ท่าเดิม (build_anims) key เป็น euler XYZ / ท่า mocap key เป็น quaternion: ตั้งโหมดให้ตรงก่อนอ่านท่า"""
    quat = any(fc.data_path.endswith("rotation_quaternion") for fc in action_fcurves(act))
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION" if quat else "XYZ"


def write_action(rig, name, out, hips_loc, n):
    old = bpy.data.actions.get(name)
    if old:
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    prev = {}
    for i in range(n):
        for pb in rig.pose.bones:
            q = out[pb.name][i] if pb.name in out else Quaternion()
            p = prev.get(pb.name)
            if p is not None and p.dot(q) < 0:
                q = -q
            prev[pb.name] = q
            pb.rotation_quaternion = q
            pb.location = hips_loc[i] if pb.name == "hips" else Vector()
            pb.keyframe_insert("rotation_quaternion", frame=i + 1, group=pb.name)
            if pb.name in ("root", "hips"):
                pb.keyframe_insert("location", frame=i + 1, group=pb.name)
    act.frame_range = (1, n)
    return act


def export_data(rig, names, path, step=2):
    sc = bpy.context.scene
    out = {"fps": FPS, "studs_per_m": STUDS_PER_M, "parents": {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones},
           "rest": {}, "clips": {}}
    for bn in rig.data.bones:
        q = bn.matrix_local.to_quaternion()
        h = bn.head_local * STUDS_PER_M
        out["rest"][bn.name] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6), round(h.x, 5), round(h.y, 5), round(h.z, 5)]
    for clip in names:
        act = bpy.data.actions[clip]
        set_mode_for(rig, act)
        rig.animation_data.action = act
        f0, f1 = (int(x) for x in act.frame_range)
        frames = list(range(f0, f1 + 1, step))
        if frames[-1] != f1:
            frames.append(f1)
        tracks = {}
        for f in frames:
            sc.frame_set(f)
            for pb in rig.pose.bones:
                m = pb.matrix_basis
                q = m.to_quaternion()
                t = m.to_translation() * STUDS_PER_M
                tracks.setdefault(pb.name, []).append([round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4), round(t.x, 4), round(t.y, 4), round(t.z, 4)])
        moving = {n: k for n, k in tracks.items() if any(abs(a - b) > 1e-4 for r in k for a, b in zip(r, k[0])) or any(abs(v) > 1e-4 for v in k[0][:3] + k[0][4:])}
        out["clips"][clip] = {"length": (f1 - f0) / FPS, "times": [round((f - f0) / FPS, 4) for f in frames], "tracks": moving}
    json.dump(out, open(path, "w"), separators=(",", ":"))
    return os.path.getsize(path)


def preview(rig, pairs, path):
    """แถวละท่า: ซ้าย 6 ช่วง = ท่าเดิม (ถ้ามี) / ขวา 6 ช่วง = mocap (มุมเฉียงหน้า)"""
    import numpy as np
    sc = bpy.context.scene
    body = bpy.data.objects.get("Body")
    zs = [(body.matrix_world @ v.co).z for v in body.data.vertices]
    H = max(zs) - min(zs)
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_cavity = True
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = H * 1.25
    sc.render.resolution_x, sc.render.resolution_y = 170, 260
    tgt = Vector((0, 0, min(zs) + H * 0.52))
    a = math.radians(35)
    d = Vector((math.sin(a), -math.cos(a), 0.12)).normalized()
    cam.location = tgt + d * 4
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    rows = []
    blank = None
    for old, new in pairs:
        row = []
        for an in (old, new):
            act = bpy.data.actions.get(an) if an else None
            for k in range(6):
                if act is None:
                    row.append(blank if blank is not None else np.zeros((260, 170, 4), np.float32))
                    continue
                set_mode_for(rig, act)
                rig.animation_data.action = act
                f0, f1 = (int(x) for x in act.frame_range)
                sc.frame_set(int(f0 + (f1 - f0) * k / 6))
                tmp = path[:-4] + "_t.png"
                sc.render.filepath = tmp
                bpy.ops.render.render(write_still=True)
                im = bpy.data.images.load(tmp)
                arr = np.empty(im.size[0] * im.size[1] * 4, np.float32)
                im.pixels.foreach_get(arr)
                row.append(arr.reshape(im.size[1], im.size[0], 4))
                bpy.data.images.remove(im)
                os.remove(tmp)
        rows.append(np.concatenate(row, 1))
    sheet = np.concatenate(rows[::-1], 0)
    img = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0])
    img.pixels.foreach_set(sheet.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    bpy.data.objects.remove(cam, do_unlink=True)
    log("preview", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    want = [a for a in argv if not a.startswith("--")]
    char = os.path.splitext(os.path.basename(bpy.data.filepath))[0]
    rig = bpy.data.objects["HumanRig"]
    if not rig.animation_data:
        rig.animation_data_create()
    bpy.context.scene.render.fps = FPS
    # joint limit ของ rig (LIMIT_ROTATION) ทำไว้ให้ท่าสูตรคณิตศาสตร์: ท่า mocap เป็นท่าคนจริงอยู่แล้ว และ Roblox ไม่มี constraint
    # (ส่งออกใช้ matrix_basis) -> ปิดไว้ ภาพตัวอย่างจะได้ตรงกับในเกม
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True
    clips = dict(CLIPS)
    if "elder" in char:
        clips.update(ELDER_CLIPS)
    if "female" in char and "elder" not in char:
        clips.update(FEMALE_CLIPS)
    names = [n for n in clips if not want or n in want]
    made = []
    for name in names:
        fn, mode, opt = clips[name]
        path = os.path.join(MOCAP, fn)
        if not os.path.exists(path):
            log("missing", fn)
            continue
        base_act = bpy.data.actions.get(opt.get("base", "")) if mode == "add" else None
        if mode == "add" and base_act is None:
            log("no base action", opt.get("base"))
            continue
        # ท่าเดิมของเกมเก็บไว้ชื่อ <name>__old (ไว้เทียบในภาพ) · ท่าใหม่ใช้ชื่อเดิม
        if name in bpy.data.actions and name + "__old" not in bpy.data.actions:
            bpy.data.actions[name].name = name + "__old"
            if base_act is not None and base_act.name == name + "__old":
                pass
        if mode == "add":
            base_act = bpy.data.actions.get(opt["base"] + "__old") or bpy.data.actions.get(opt["base"])
        src = import_source(path)
        out, hl, n = retarget(rig, src, mode, opt, base_act)
        write_action(rig, name, out, hl, n)
        bpy.data.objects.remove(src, do_unlink=True)
        made.append(name)
        log(f"{name}: {fn} {mode} -> {n} frames ({n / FPS:.1f} s)")
    size = export_data(rig, made, os.path.join(OUTD, f"{char}_mocap_anims.json"))
    log("json", os.path.join(OUTD, f"{char}_mocap_anims.json"), size)
    if "--preview" in argv:
        preview(rig, [(n + "__old" if (n + "__old") in bpy.data.actions else None, n) for n in made], os.path.join(OUTD, f"{char}_mocap_preview.png"))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUTD, f"{char}_mocap.blend"), copy=True)
    log("done", made)


main()
