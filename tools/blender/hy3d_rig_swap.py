# Put a Hy3D mesh (made by hy3d_to_roblox.py) on the OLD ghost rig, so the animation IDs already in
# shared/GhostAnimIds keep working (same bone names, same bone axes; joints moved to the new body).
#
#   blender.exe --background --factory-startup --python hy3d_rig_swap.py -- pret
#   blender.exe --background --factory-startup --python hy3d_rig_swap.py -- krasue
#
# in : assets/models/pret.blend   (HumanRig + Idle/TallSlowWalk/Shriek)   + PretV2/PretV2.blend   (low mesh, baked textures)
#      assets/models/krasue.blend (KrasueRig + Float/Lunge/Sniff/HairWhip) + KrasueV2/KrasueV2.blend
# out: assets/models/<V2>/upload/<V2>.fbx (rig + mesh, replaces the static one; textures unchanged)
#      assets/models/<V2>/<V2>_rigged.blend, previews/<V2>_pose_<clip>.png
#
# Pret : bones re-placed on the new body (landmarks below, measured on the 4.0 m mesh; y taken from the mesh),
#        fingers / tongue just follow their parent and do not deform (the hand moves as one piece)
# Krasue: the old rig already fits once the head is the same size, so the bones stay; weights are set by hand:
#        hair (dark texels) -> Head / Hair_*, everything else -> Head / Windpipe / Heart / Gut1..7

import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

WHO = sys.argv[sys.argv.index("--") + 1:][0]
M = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models"))
CFG = {
    "pret": dict(old="pret.blend", rig="HumanRig", new="PretV2", part="Body",
                 clips={"Idle": 40, "TallSlowWalk": 30, "Shriek": 45}),
    "krasue": dict(old="krasue.blend", rig="KrasueRig", new="KrasueV2", part="Krasue",
                   clips={"Float": 30, "Lunge": 20, "HairWhip": 13, "Sniff": 25}),
    "dancer": dict(old="human_ghosts/ghost_dancer.blend", rig="HumanRig", new="DancerV2", part="Body",
                   clips={"dancer_dance": 120, "dancer_idle": 60}),
    "tani": dict(old="human_ghosts/ghost_tani.blend", rig="HumanRig", new="TaniV2", part="Body",
                 clips={"ghost_idle": 50, "tani_peek": 70}),
    "kuman": dict(old="KumanV2/kuman_v2.blend", rig="HumanRig", new="KumanV3", part="Body",
                  clips={"run": 6}),
    # ตานี v3 (Hy3D_textured_00013, ผู้ใช้ 2026-11-22): โครงเดิมของตานี ข้อต่อวัดจากตัวใหม่ (VARIANT) แล้วทำทุกอย่างแบบ tani
    "tani3": dict(old="human_ghosts/ghost_tani.blend", rig="HumanRig", new="TaniV3", part="Body",
                  clips={"ghost_idle": 50, "tani_peek": 70}),
}[WHO]
VARIANT = WHO
if WHO == "tani3":
    WHO = "tani"
DRESS = WHO in ("dancer", "tani")   # ขาอยู่ในผ้านุ่ง/ผ้าซิ่นยาว: ใต้สะโพก = ผืนเดียว
NEW = CFG["new"]
ROOT = os.path.join(M, NEW)
UP = os.path.join(ROOT, "upload")
PREV = os.path.join(ROOT, "previews")


def log(*a):
    print("[rig]", *a, flush=True)


bpy.ops.wm.open_mainfile(filepath=os.path.join(M, CFG["old"]))
rig = bpy.data.objects[CFG["rig"]]
for o in list(bpy.data.objects):
    if o.type == "MESH":
        bpy.data.objects.remove(o)
with bpy.data.libraries.load(os.path.join(ROOT, NEW + ".blend")) as (src, dst):
    dst.objects = [NEW]
body = dst.objects[0]
bpy.context.scene.collection.objects.link(body)
body.name = CFG["part"]
body.data.name = CFG["part"]
body.parent = None
body.matrix_world = Matrix.Identity(4)

act0 = rig.animation_data.action if rig.animation_data else None
if rig.animation_data:
    rig.animation_data.action = None
for p in rig.pose.bones:
    p.matrix_basis = Matrix.Identity(4)
rig.data.pose_position = "REST"

me = body.data
co = np.empty(len(me.vertices) * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)


def set_co(a):
    me.vertices.foreach_set("co", a.ravel())
    me.update()


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    return np.linalg.norm(p - (a + t[:, None] * ab), axis=1)


def assign(cand, power=4.0, eps=0.01, smooth=0):
    """weights from distance to bone segments, among the candidate bones per vertex (cand: list of (mask, [bones]));
    smooth = passes of neighbour averaging over the mesh edges (spreads hard seams where two regions touch)"""
    eb = {b.name: (np.array(rig.matrix_world @ b.head_local), np.array(rig.matrix_world @ b.tail_local)) for b in rig.data.bones}
    names_all = sorted({n for e in cand for n in e[1]})
    col = {n: j for j, n in enumerate(names_all)}
    W = np.zeros((len(co), len(names_all)))
    for entry in cand:
        mask, names = entry[0], entry[1]
        idx = np.where(mask)[0]
        if not len(idx):
            continue
        if len(entry) > 2:   # custom weights (e.g. the dancer's skirt by height only)
            w = entry[2](co[idx])
        else:
            D = np.stack([seg_dist(co[idx], *eb[n]) for n in names], 1)
            w = 1.0 / (D + eps) ** power
        w /= np.maximum(w.sum(1, keepdims=True), 1e-9)
        for j, n in enumerate(names):
            W[idx, col[n]] += w[:, j]
    if smooth:
        ed = np.array([e.vertices[:] for e in me.edges])
        deg = np.bincount(ed.ravel(), minlength=len(co)).astype(float)
        for _ in range(smooth):
            acc = np.zeros_like(W)
            np.add.at(acc, ed[:, 0], W[ed[:, 1]])
            np.add.at(acc, ed[:, 1], W[ed[:, 0]])
            W = 0.5 * W + 0.5 * acc / np.maximum(deg, 1)[:, None]
    W[W < 0.01] = 0
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    for n, j in col.items():
        g = body.vertex_groups.get(n) or body.vertex_groups.new(name=n)
        for i in np.where(W[:, j] > 0)[0].tolist():
            g.add([i], float(W[i, j]), "REPLACE")
    log("weighted", {n: int((W[:, j] > 0).sum()) for n, j in col.items()})


# =====================================================================================================  PRET / DANCER (HumanRig)
if WHO in ("pret", "dancer", "tani", "kuman"):
    def ymid(x, z, r=0.09):
        s = co[(np.abs(co[:, 0] - x) < r) & (np.abs(co[:, 2] - z) < r)]
        return float((s[:, 1].min() + s[:, 1].max()) / 2) if len(s) else 0.0

    if WHO == "pret":
        # (x, z) on the 4.0 m body, left side (+x); y comes from the mesh
        J = {
            "hip": (0.0, 2.02), "spine": (0.0, 2.36), "chest": (0.0, 2.72), "neck": (0.0, 3.34), "headb": (0.0, 3.50),
            "top": (0.0, 4.00), "sh_in": (0.04, 3.30), "sh": (0.45, 3.13), "elbow": (0.84, 2.66), "wrist": (1.22, 2.20),
            "knuckle": (1.47, 1.93), "thigh": (0.17, 2.02), "knee": (0.20, 1.13), "ankle": (0.22, 0.17),
        }
        ball = Vector((0.22, -0.12, 0.05))
        toe = Vector((0.22, -0.26, 0.04))
        root_place = (Vector((0, 0, 1.0)), Vector((0, 0.3, 1.0)))
    elif WHO == "kuman":
        # กุมารทอง 1.27 m รวมจุก (หัวโต): วัดจากภาพตัดขวางทั้งตัว ขาแยกกัน (โจงกระเบนสั้นแค่เข่า) = แบบเปรต
        J = {
            "hip": (0.0, 0.50), "spine": (0.0, 0.62), "chest": (0.0, 0.74), "neck": (0.0, 0.98), "headb": (0.0, 1.03),
            "top": (0.0, 1.24), "sh_in": (0.02, 0.86), "sh": (0.17, 0.84), "elbow": (0.29, 0.77), "wrist": (0.40, 0.68),
            "knuckle": (0.44, 0.62), "thigh": (0.07, 0.48), "knee": (0.075, 0.27), "ankle": (0.08, 0.07),
        }
        ball = Vector((0.08, -0.06, 0.02))
        toe = Vector((0.08, -0.10, 0.015))
        root_place = (Vector((0, 0, 0)), Vector((0, 0.2, 0)))
    elif VARIANT == "tani3":
        # ตานี v3 1.72 m: แขนลู่ลงกว่า v2 ผ้าซิ่นสั้นถึงแข้ง (ชาย ~0.19) สไบห้อยยาวด้านหลังถึง ~0.75
        J = {
            "hip": (0.0, 0.818), "spine": (0.0, 0.976), "chest": (0.0, 1.135), "neck": (0.0, 1.349), "headb": (0.0, 1.465),
            "top": (0.0, 1.70), "sh_in": (0.028, 1.33), "sh": (0.19, 1.28), "elbow": (0.30, 1.11), "wrist": (0.40, 0.94),
            "knuckle": (0.43, 0.85), "thigh": (0.091, 0.809), "knee": (0.09, 0.46), "ankle": (0.085, 0.09),
        }
        ball = Vector((0.085, -0.10, 0.024))
        toe = Vector((0.085, -0.15, 0.02))
        root_place = (Vector((0, 0, 0)), Vector((0, 0.28, 0)))
    elif WHO == "tani":
        # นางตานี 1.72 m (หัวถึง ~1.70 = กระดูกตานีเดิม 1.702 พอดี): แขน/มือวัดจากภาพตัดขวาง ลำตัว/ขา = กระดูกเดิม
        J = {
            "hip": (0.0, 0.818), "spine": (0.0, 0.976), "chest": (0.0, 1.135), "neck": (0.0, 1.349), "headb": (0.0, 1.465),
            "top": (0.0, 1.70), "sh_in": (0.028, 1.33), "sh": (0.20, 1.29), "elbow": (0.34, 1.11), "wrist": (0.46, 0.93),
            "knuckle": (0.50, 0.84), "thigh": (0.091, 0.809), "knee": (0.09, 0.46), "ankle": (0.10, 0.093),
        }
        ball = Vector((0.10, -0.10, 0.024))
        toe = Vector((0.10, -0.17, 0.02))
        root_place = (Vector((0, 0, 0)), Vector((0, 0.28, 0)))
    else:
        # นางรำ 2.0 m รวมชฎา (ตัวถึงหัว ~1.75): แขน/มือวัดจากภาพตัดขวาง, ลำตัว/ขา (อยู่ในผ้านุ่ง มองไม่เห็น)
        # = สัดส่วนกระดูกนางรำเดิม (หัวถึง 1.70) x 1.03
        J = {
            "hip": (0.0, 0.84), "spine": (0.0, 1.00), "chest": (0.0, 1.17), "neck": (0.0, 1.40), "headb": (0.0, 1.50),
            "top": (0.0, 1.76), "sh_in": (0.03, 1.36), "sh": (0.25, 1.31), "elbow": (0.43, 1.12), "wrist": (0.57, 0.96),
            "knuckle": (0.63, 0.87), "thigh": (0.094, 0.83), "knee": (0.088, 0.47), "ankle": (0.089, 0.10),
        }
        ball = Vector((0.089, -0.11, 0.024))
        toe = Vector((0.089, -0.19, 0.02))
        root_place = (Vector((0, 0, 0)), Vector((0, 0.28, 0)))
    P = {k: Vector((x, ymid(x, z, 0.06 if DRESS else (0.05 if WHO == "kuman" else 0.09)), z)) for k, (x, z) in J.items()}
    P["top"].y = P["headb"].y
    if WHO == "dancer":
        # ลำตัว/ขาอยู่ในชุด: แกนกลางตัวใช้ y ของคอ ขาอยู่กลางผ้านุ่ง (ไม่ใช่กลางผ้าคลุมที่ยาวไปข้างหลัง)
        for k in ("hip", "spine", "chest", "thigh", "knee", "ankle"):
            P[k].y = P["neck"].y
        ball.y, toe.y = P["ankle"].y - 0.11, P["ankle"].y - 0.19
    elif WHO == "tani":
        # ตานี: ผมยาวคลุมคอ/หลัง = y ที่คอเลื่อนไปข้างหลัง ใช้กลางผ้าซิ่นที่สะโพกเป็นแกนกลางตัวทั้งเส้น (หัวยื่นหน้านิดๆ)
        yc = ymid(0.0, 0.3, 0.08) if VARIANT == "tani3" else ymid(0.0, 0.82, 0.08)   # v3: สไบห้อยหลังช่วงสะโพก ใช้ช่วงแข้ง
        for k in ("hip", "spine", "chest", "neck", "thigh", "knee", "ankle"):
            P[k].y = yc
        P["headb"].y = P["top"].y = yc - 0.02
        ball.y, toe.y = yc - 0.10, yc - 0.17

    def mir(v, side):
        return Vector((v.x if side == "L" else -v.x, v.y, v.z))

    place = {
        "root": root_place,
        "hips": (P["hip"], P["spine"]), "spine": (P["spine"], P["chest"]), "chest": (P["chest"], P["neck"]),
        "neck": (P["neck"], P["headb"]), "head": (P["headb"], P["top"]),
    }
    for s in "LR":
        place[f"shoulder.{s}"] = (mir(P["sh_in"], s), mir(P["sh"], s))
        place[f"upper_arm.{s}"] = (mir(P["sh"], s), mir(P["elbow"], s))
        place[f"forearm.{s}"] = (mir(P["elbow"], s), mir(P["wrist"], s))
        place[f"hand.{s}"] = (mir(P["wrist"], s), mir(P["knuckle"], s))
        place[f"thigh.{s}"] = (mir(P["thigh"], s), mir(P["knee"], s))
        place[f"shin.{s}"] = (mir(P["knee"], s), mir(P["ankle"], s))
        place[f"foot.{s}"] = (mir(P["ankle"], s), mir(ball, s))
        place[f"toe.{s}"] = (mir(ball, s), mir(toe, s))

    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    ebs = rig.data.edit_bones
    old = {b.name: (b.head.copy(), b.tail.copy()) for b in ebs}

    def sim(name):
        """old->new similarity transform of a placed bone (rotation taking old dir to new dir, scale, translation)"""
        (h0, t0), (h1, t1) = old[name], place[name]
        q = (t0 - h0).normalized().rotation_difference((t1 - h1).normalized())
        k = (t1 - h1).length / max((t0 - h0).length, 1e-6)
        return lambda v: h1 + (q @ (v - h0)) * k

    for b in ebs:
        if b.name in place:
            b.head, b.tail = place[b.name]
        else:   # fingers / tongue: follow the nearest placed ancestor
            a = b.parent
            while a and a.name not in place:
                a = a.parent
            f = sim(a.name)
            b.head, b.tail = f(old[b.name][0]), f(old[b.name][1])
            b.use_deform = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, (h, t) in place.items():
        log(f"  {name:12s} {tuple(round(x, 3) for x in h)} -> {tuple(round(x, 3) for x in t)}")

    # weights: arms only take arm bones, legs only leg bones (no torso skin dragged by an arm swing)
    sh = {s: mir(P["sh"], s) for s in "LR"}
    elbow = {s: mir(P["elbow"], s) for s in "LR"}
    x, z = co[:, 0], co[:, 2]
    cand = []
    taken = np.zeros(len(co), bool)
    hand_mask = np.zeros(len(co), bool)
    loose_mask = np.zeros(len(co), bool)
    if WHO in ("pret", "kuman"):
        # เกณฑ์แขน/ขา (เปรต 4 ม. / กุมาร 1.27 ม.)
        ax, az_, d1, dt, crotch = (0.36, 1.2, 0.3, 0.5, 1.86) if WHO == "pret" else (0.14, 0.5, 0.08, 0.12, 0.40)
        for s, sg in (("L", 1), ("R", -1)):
            # arm = close to the shoulder -> elbow -> wrist -> fingertip line (hand segment stretched over the long fingers)
            a, e, w_, k_ = (np.array(mir(P[n], s)) for n in ("sh", "elbow", "wrist", "knuckle"))
            tip = w_ + 3.0 * (k_ - w_)
            arm = (sg * x > ax) & (z > az_) & ((seg_dist(co, a, e) < d1) | (seg_dist(co, e, w_) < d1) | (seg_dist(co, w_, tip) < dt))
            cand.append((arm, [f"shoulder.{s}", f"upper_arm.{s}", f"forearm.{s}", f"hand.{s}", "chest"]))
            taken |= arm
        for s, sg in (("L", 1), ("R", -1)):
            leg = ~taken & (sg * x > 0) & (z < crotch)
            cand.append((leg, [f"thigh.{s}", f"shin.{s}", f"foot.{s}", f"toe.{s}", "hips"]))
            taken |= leg
        cand.append((~taken, ["hips", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R",
                              "thigh.L", "thigh.R"]))
        assign(cand, smooth=2 if WHO == "kuman" else 0)
        if WHO == "kuman":
            # คราบแดงไหลจากสร้อยคอลงอก + หยดแดงตามขา (ดูเหมือนเลือด): หม่นทั้งตัว ยกเว้นโจงกระเบน (ช่วงเอวถึงเข่า)
            # และแขน (กำไล/สายสิญจน์แดงเป็นของตั้งใจ)
            arms = np.zeros(len(co), bool)
            for e_ in cand[:2]:
                arms |= e_[0]
            pants = (z > 0.35) & (z < 0.67) & (np.abs(x) < 0.2)
            hand_mask = ~arms & ~pants
            loose_mask = ~arms & (z < 0.36)
    else:
        # นางรำ: แขนผอม (เกณฑ์ระยะแคบกว่าเปรต) / เท้าที่โผล่ใต้ชาย = กระดูกเท้า
        # ผ้านุ่ง + ผ้าคลุมใต้สะโพก = ผืนเดียว: น้ำหนักตามความสูงอย่างเดียว ขาซ้าย/ขวาเท่ากัน (ผ้าไม่ฉีกแยกตามขา)
        for s, sg in (("L", 1), ("R", -1)):
            a, e, w_, k_ = (np.array(mir(P[n], s)) for n in ("sh", "elbow", "wrist", "knuckle"))
            tip = w_ + 2.6 * (k_ - w_)
            hand = (sg * x > 0.8 * P["wrist"].x) & (z > 0.68) & (seg_dist(co, w_, tip) < 0.13)   # x เกณฑ์ตามข้อมือของตัวนั้น (นางรำ ~0.46, ตานี v3 0.32)
            arm = (sg * x > 0.29) & (z > 0.68) & ((seg_dist(co, a, e) < 0.11) | (seg_dist(co, e, w_) < 0.1) | hand)
            cand.append((arm, [f"shoulder.{s}", f"upper_arm.{s}", f"forearm.{s}", f"hand.{s}", "chest"]))
            taken |= arm
            hand_mask |= hand & (seg_dist(co, w_, tip) < seg_dist(co, e, w_))
        for s, sg in (("L", 1), ("R", -1)):
            an, bl, tp = (np.array(v) for v in (mir(P["ankle"], s), mir(ball, s), mir(toe, s)))
            foot = ~taken & (z < 0.16) & ((seg_dist(co, an, bl) < 0.07) | (seg_dist(co, bl, tp) < 0.06))
            cand.append((foot, [f"foot.{s}", f"toe.{s}", f"shin.{s}"]))
            taken |= foot
        hz, az = P["hip"].z, P["ankle"].z

        def dress_w(pts):
            t = np.clip((hz - pts[:, 2]) / (hz - az), 0, 1)
            wh = (1 - t) ** 1.5
            rest = 1 - wh
            sm = np.clip((t - 0.3) / 0.45, 0, 1)
            sm = sm * sm * (3 - 2 * sm)
            return np.stack([wh, rest * (1 - sm) / 2, rest * (1 - sm) / 2, rest * sm / 2, rest * sm / 2], 1)

        dress = ~taken & (z < hz)
        cand.append((dress, ["hips", "thigh.L", "thigh.R", "shin.L", "shin.R"], dress_w))
        taken |= dress
        cand.append((~taken, ["hips", "spine", "chest", "neck", "head", "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R"]))
        assign(cand, smooth=4)
        log(f"hand verts (red muted on these texels) {int(hand_mask.sum())}")

# =====================================================================================================  KRASUE
else:
    # same head size as the old Krasue: old Head bone runs chin -> crown
    hb = rig.data.bones["Head"]
    chin_old, crown_old = (rig.matrix_world @ hb.head_local).z, (rig.matrix_world @ hb.tail_local).z
    crown, chin = co[:, 2].max(), 0.50 / 0.75 * co[:, 2].max()     # chin measured at z 0.50 of the 0.75 m mesh
    k = (crown_old - chin_old) / (crown - chin)
    co[:] = co * k
    co[:, 2] += chin_old - chin * k
    co[:, 1] += (rig.matrix_world @ hb.head_local).y - (co[co[:, 2] > chin_old, 1].min() + co[co[:, 2] > chin_old, 1].max()) / 2
    set_co(co)
    log(f"scaled x{k:.3f}: z {co[:, 2].min():.3f} .. {co[:, 2].max():.3f}")

    # dark texels = hair
    img = None
    for n in body.active_material.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and n.image.name.endswith("_Color"):
            img = n.image
    W_, H_ = img.size
    px = np.empty(W_ * H_ * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(H_, W_, 4)
    uv = np.empty(len(me.loops) * 2)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    vi = np.empty(len(me.loops), int)
    me.loops.foreach_get("vertex_index", vi)
    lum = px[np.clip((uv[:, 1] * H_).astype(int), 0, H_ - 1), np.clip((uv[:, 0] * W_).astype(int), 0, W_ - 1), :3].mean(1)
    vl = np.zeros(len(co)); vn = np.zeros(len(co))
    np.add.at(vl, vi, lum); np.add.at(vn, vi, 1)
    vl /= np.maximum(vn, 1)
    # dark crevices between the organs are not hair: hair ends above the lungs and hangs outside the neck / organ core
    core = (np.abs(co[:, 0]) < 0.065) & (co[:, 1] < 0.06)
    hair = (vl < 0.09) & (co[:, 2] > -0.30) & ~(core & (co[:, 2] < chin_old))
    log(f"hair verts {hair.sum()} / {len(co)}")
    face = co[:, 2] > chin_old - 0.01
    hair_hang = hair
    assign([
        (hair_hang & (co[:, 2] > -0.06), ["Head"]),
        (hair_hang & (co[:, 2] <= -0.06), ["Head", "Hair_L1", "Hair_L2", "Hair_R1", "Hair_R2", "Hair_B1", "Hair_B2"]),
        (~hair_hang & face, ["Head"]),
        (~hair_hang & ~face, ["Head", "Windpipe", "Heart", "Gut1", "Gut2", "Gut3", "Gut4", "Gut5", "Gut6", "Gut7"]),
    ], power=3.0, smooth=8)

# ----------------------------------------------------------------------------------------------- skin + export
body.parent = rig
body.matrix_parent_inverse = rig.matrix_world.inverted()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig
unweighted = sum(1 for v in me.vertices if not v.groups)
log("unweighted verts:", unweighted)

# นางรำ: ปลายนิ้ว/มือแดงไหลเหมือนเลือด (บัญชีเคยโดนเตือนเรื่องเลือด) -> หม่นเป็นสีผิวเทาซีดเฉพาะ texel ของมือ
# (ชุดแดงไม่แตะ) แล้วเขียนทับ upload/<V2>_Color.png
# ตานี: ไม่มีส่วนไหนควรแดง แต่ใต้รักแร้ (ที่ซ่อนอยู่ตอนท่ากางแขน) มีคราบแดงคล้ำโผล่ตอนยกแขน -> หม่นแดงทั้งตัว
if WHO == "tani" and VARIANT != "tani3":
    hand_mask[:] = True
if VARIANT == "tani3":
    hand_mask = co[:, 2] < 1.45   # ใต้คอลงมา (ดอกไม้ส้มแดงที่ผมไม่แตะ)
if WHO in ("dancer", "tani", "kuman") and hand_mask.any():
    img = None
    for n in body.active_material.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image and n.image.name.endswith("_Color"):
            img = n.image
    Wt, Ht = img.size
    px = np.empty(Wt * Ht * 4, np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(Ht, Wt, 4)
    uvl = me.uv_layers.active.data

    def texmask(vmask):
        """texels covered by faces whose vertices are all in vmask (a little past the edges: bake margin)"""
        out = np.zeros((Ht, Wt), bool)
        for poly in me.polygons:
            if not all(vmask[v] for v in poly.vertices):
                continue
            uv = np.array([uvl[li].uv[:] for li in poly.loop_indices]) * [Wt, Ht]
            x0, y0 = np.floor(uv.min(0)).astype(int) - 2
            x1, y1 = np.ceil(uv.max(0)).astype(int) + 2
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, Wt - 1), min(y1, Ht - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            a, b, c = uv[0], uv[1], uv[2]
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / d
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / d
            out[y0:y1 + 1, x0:x1 + 1] |= (l1 >= -0.08) & (l2 >= -0.08) & (1 - l1 - l2 >= -0.08)
        return out

    mask = texmask(hand_mask)
    rgb = px[..., :3]
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    red = (rgb[..., 0] >= mx - 1e-4) & (rgb[..., 1] - rgb[..., 2] < 0.15)
    m = mask * np.clip((sat - 0.25) / 0.25, 0, 1) * red
    if WHO in ("tani", "kuman"):
        # ทั้งตัว: เฉพาะแดงจริงๆ (แดงนำเขียว/น้ำเงินชัด และไม่มืด) ผมน้ำตาลเข้ม / เงาชุด / ทองเข้ม ห้ามโดน
        lead = rgb[..., 0] - np.maximum(rgb[..., 1], rgb[..., 2])
        m = mask * np.clip((lead - 0.08) / 0.08, 0, 1) * np.clip((rgb[..., 0] - 0.18) / 0.08, 0, 1)
        if VARIANT == "tani3":
            # แดงเข้มจริงๆ เท่านั้น (เขียว/ทอง/ส้มของกำไล-ขอบผ้ารอด): เขียวต่อแดงไม่ถึง 0.55 และน้ำเงินต่อแดงไม่ถึง 0.6
            r_ = np.maximum(rgb[..., 0], 1e-4)
            m = mask * np.clip((0.55 - rgb[..., 1] / r_) / 0.15, 0, 1) * (rgb[..., 2] / r_ < 0.6) * np.clip((rgb[..., 0] - 0.2) / 0.08, 0, 1)
        if loose_mask.any():
            # ขากุมาร (ผิวขาวซีดล้วน): หยดแดงคล้ำเข้มกว่าเกณฑ์ข้างบน ใช้เกณฑ์หลวม
            lm = texmask(loose_mask)
            m = np.maximum(m, lm * np.clip((lead - 0.03) / 0.05, 0, 1) * np.clip((rgb[..., 0] - 0.06) / 0.06, 0, 1))
            mask |= lm
    lum = rgb @ np.array([0.3, 0.5, 0.2], np.float32)
    skin = (0.35 + 0.5 * np.clip(lum / max(float(np.percentile(lum[mask], 90)), 1e-3), 0, 1))[..., None] * np.array([0.78, 0.80, 0.86], np.float32)
    px[..., :3] = rgb * (1 - m[..., None]) + skin * m[..., None]
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = os.path.join(UP, NEW + "_Color.png")
    img.file_format = "PNG"
    img.save()
    log(f"muted red on hands: {float((m > 0.5).sum())} texels")

for o in bpy.context.view_layer.objects:
    o.select_set(o in (rig, body))
bpy.context.view_layer.objects.active = rig
os.makedirs(UP, exist_ok=True)
fbx_path = os.path.join(UP, NEW + ".fbx")
common = dict(filepath=fbx_path, use_selection=True, apply_scale_options="FBX_SCALE_NONE", axis_forward="-Z", axis_up="Y",
              bake_space_transform=False, object_types={"ARMATURE", "MESH"}, mesh_smooth_type="FACE", path_mode="STRIP",
              embed_textures=False, use_mesh_modifiers=False, add_leaf_bones=False, primary_bone_axis="Y",
              secondary_bone_axis="X", bake_anim=False)
if WHO in ("pret", "dancer", "tani", "kuman"):
    bpy.ops.export_scene.fbx(global_scale=3.5, use_armature_deform_only=False, **common)
else:
    bpy.ops.export_scene.fbx(armature_nodetype="NULL", **common)
log("exported", fbx_path)

# ----------------------------------------------------------------------------------------------- pose previews
rig.data.pose_position = "POSE"
scn = bpy.context.scene
for o in list(scn.objects):
    if o.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(o)
scn.render.engine = "BLENDER_EEVEE"
scn.render.resolution_x, scn.render.resolution_y = 600, 800
w = bpy.data.worlds.new("w"); scn.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.33, 0.33, 0.36, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.5
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
sun.data.energy = 3; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cd = bpy.data.cameras.new("cam"); cd.type = "ORTHO"
cam = bpy.data.objects.new("cam", cd); scn.collection.objects.link(cam); scn.camera = cam
os.makedirs(PREV, exist_ok=True)
if not rig.animation_data:
    rig.animation_data_create()
for clip, frame in CFG["clips"].items():
    a = bpy.data.actions.get(clip)
    if not a:
        continue
    rig.animation_data.action = a
    scn.frame_set(frame)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    pts = np.array([ev.matrix_world @ v.co for v in ev.data.vertices])
    # edges stretched far beyond their rest length = a vertex pulled by the wrong bone
    ed = np.array([e.vertices[:] for e in me.edges])
    rest = np.linalg.norm(co[ed[:, 0]] - co[ed[:, 1]], axis=1)
    now = np.linalg.norm(pts[ed[:, 0]] - pts[ed[:, 1]], axis=1)
    span = float(co[:, 2].max() - co[:, 2].min())
    bad = (now > 2.5 * rest) & (now > 0.03 * span)
    log(f"  {clip}: {int(bad.sum())} stretched edges" + (f", worst at {np.round(co[ed[bad][0][0]], 3)}" if bad.any() else ""))
    lo, hi = pts.min(0), pts.max(0)
    ctr = Vector(((lo + hi) / 2).tolist())
    cd.ortho_scale = float(max(hi - lo)) * 1.15
    for vname, ang in (("front", 25), ("side", 90)):
        r = math.radians(ang)
        cam.location = ctr + Vector((math.sin(r), -math.cos(r), 0.15)) * 20
        cam.rotation_euler = (math.radians(90 - math.degrees(math.atan2(0.15, 1))), 0, r)
        scn.render.filepath = os.path.join(PREV, f"{NEW}_pose_{clip}_{vname}.png")
        bpy.ops.render.render(write_still=True)
    log("posed", clip, frame)
rig.animation_data.action = act0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, NEW + "_rigged.blend"), compress=True)
log("done")
