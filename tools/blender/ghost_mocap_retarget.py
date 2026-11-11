# ghost_mocap_retarget.py — Retarget the 5 Mixamo FBX clips (Zombie Walk, Zombie Idle, Running Crawl,
# Zombie Scream, Bellydancing) + Sitting Idle onto our 52-bone HumanRig (+ Pop's 3 tongue bones) for all ghost clips,
# combining organic Mixamo motion with each Thai ghost's signature pose (Thai classical dance hands, baby cradle,
# coffin pole carry, tongue lick, etc.).
#
# Outputs:
#   1) assets/models/mocap/out/ghost_mocap_anims.json (raw Blender rest + clips)
#   2) src/shared/GhostClipData.luau (pre-converted Roblox Bone.Transform CFrame keys for instant playback)
#   3) assets/models/mocap/out/ghost_mocap_preview.png (visual contact sheet on Villager v2 ghosts)

import bpy, math, os, sys, json
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
M = os.path.join(ROOT, "assets", "models")
MOCAP = os.path.join(M, "mocap")
OUTD = os.path.join(MOCAP, "out")
os.makedirs(OUTD, exist_ok=True)

FPS = 30
STUDS_PER_M = 3.5

# Load mocap_retarget helpers
mr_ns = {"__file__": os.path.join(HERE, "mocap_retarget.py"), "__name__": "mr"}
mr_src = open(os.path.join(HERE, "mocap_retarget.py"), encoding="utf-8").read()
mr_src = mr_src.replace("\nmain()", "\n# main()")
mr_src = mr_src.replace('pre = "mixamorig:"', 'pre = next((b.name.split(":")[0] + ":" for b in src.data.bones if ":" in b.name), "mixamorig:")')
exec(compile(mr_src, "mocap_retarget.py", "exec"), mr_ns)

import_source = mr_ns["import_source"]
retarget = mr_ns["retarget"]
write_action = mr_ns["write_action"]
set_mode_for = mr_ns["set_mode_for"]

UPPER_ARM_CHAIN = {
    "L": ["shoulder.L", "upper_arm.L", "forearm.L", "hand.L"] + [f"{fg}_0{i}.L" for fg in ("thumb", "index", "middle", "ring", "pinky") for i in (1, 2, 3)],
    "R": ["shoulder.R", "upper_arm.R", "forearm.R", "hand.R"] + [f"{fg}_0{i}.R" for fg in ("thumb", "index", "middle", "ring", "pinky") for i in (1, 2, 3)],
}
FINGER_BONES = {
    sd: [f"{fg}_0{i}.{sd}" for fg in ("thumb", "index", "middle", "ring", "pinky") for i in (1, 2, 3)]
    for sd in ("L", "R")
}
LEG_BONES = ["thigh.L", "shin.L", "foot.L", "toe.L", "thigh.R", "shin.R", "foot.R", "toe.R"]
TORSO_BONES = ["hips", "spine", "chest", "neck", "head"]


def slerp_q(q1, q2, w):
    if q1.dot(q2) < 0:
        q2 = -q2
    return q1.slerp(q2, w)


def sample_action(rig, act, n_frames):
    """Sample all pose bones' basis quaternion and location across n_frames from an existing action."""
    sc = bpy.context.scene
    set_mode_for(rig, act)
    rig.animation_data.action = act
    f0, f1 = act.frame_range
    quats = {pb.name: [] for pb in rig.pose.bones}
    locs = {pb.name: [] for pb in rig.pose.bones}
    for i in range(n_frames):
        u = i / max(1, n_frames - 1)
        ff = float(f0 + u * (f1 - f0))
        sc.frame_set(int(ff), subframe=ff - int(ff))
        for pb in rig.pose.bones:
            m = pb.matrix_basis
            quats[pb.name].append(m.to_quaternion())
            locs[pb.name].append(m.to_translation())
    return quats, locs


def load_mocap_raw(rig, fbx_name, opt):
    """Import Mixamo FBX, retarget onto rig, remove temporary armature, return (quats, hips_loc, n_frames)."""
    path = os.path.join(MOCAP, fbx_name)
    src = import_source(path)
    out, hl, n = retarget(rig, src, "full", opt, None)
    bpy.data.objects.remove(src, do_unlink=True)
    return out, hl, n


def resample_tracks(quats, hl, target_n):
    """Resample mocap (quats, hl) to target_n frames."""
    src_n = len(hl)
    out_q = {}
    for bn, qs in quats.items():
        new_qs = []
        for i in range(target_n):
            u = (i / max(1, target_n - 1)) * (src_n - 1)
            k0 = int(math.floor(u))
            k1 = min(src_n - 1, k0 + 1)
            a = u - k0
            new_qs.append(slerp_q(qs[k0], qs[k1], a))
        out_q[bn] = new_qs
    new_hl = []
    for i in range(target_n):
        u = (i / max(1, target_n - 1)) * (src_n - 1)
        k0 = int(math.floor(u))
        k1 = min(src_n - 1, k0 + 1)
        a = u - k0
        new_hl.append(hl[k0].lerp(hl[k1], a))
    return out_q, new_hl


def ground_crawl(rig, quats, hips_loc, n, hand_clear=0.01, foot_clear=0.0):
    """Return (hips quats, hips locs) with a world pitch about X and a world Z shift so that, over all frames,
    the lowest fingertip sits hand_clear m above the floor and the lowest toe/foot tip sits foot_clear m above it."""
    M3 = rig.data.bones["hips"].matrix_local.to_3x3()
    Mi = M3.inverted()
    mw = rig.matrix_world
    hand_names = [b for b in FINGER_BONES["L"] + FINGER_BONES["R"] + ["hand.L", "hand.R"] if b in rig.pose.bones]
    foot_names = [b for b in ("foot.L", "foot.R", "toe.L", "toe.R") if b in rig.pose.bones]
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    rig.animation_data.action = None
    rest_floor = min((mw @ rig.data.bones[b].tail_local).z for b in foot_names)

    def lows(theta, dz):
        Rl = (Mi @ Matrix.Rotation(theta, 3, "X") @ M3).to_quaternion()
        off = Mi @ Vector((0, 0, dz))
        hlo, flo = 1e9, 1e9
        for i in range(n):
            for pb in rig.pose.bones:
                q = quats[pb.name][i] if pb.name in quats else Quaternion()
                pb.rotation_quaternion = (Rl @ q) if pb.name == "hips" else q
                pb.location = (hips_loc[i] + off) if pb.name == "hips" else Vector()
            bpy.context.view_layer.update()
            for b in hand_names:
                pb = rig.pose.bones[b]
                hlo = min(hlo, (mw @ pb.tail).z, (mw @ pb.head).z)
            for b in foot_names:
                pb = rig.pose.bones[b]
                flo = min(flo, (mw @ pb.tail).z, (mw @ pb.head).z)
        return hlo - rest_floor, flo - rest_floor

    def solve_dz(theta):
        h, f = lows(theta, 0.0)
        dz = foot_clear - f  # feet decide height; hands are then checked
        return dz, h + dz

    best = None
    for deg in range(-40, 41, 4):
        dz, hand = solve_dz(math.radians(deg))
        err = abs(hand - hand_clear)
        if best is None or err < best[0]:
            best = (err, deg, dz, hand)
    lo, hi = best[1] - 4, best[1] + 4
    for deg10 in range(lo * 10, hi * 10 + 1, 5):
        deg = deg10 / 10
        dz, hand = solve_dz(math.radians(deg))
        err = abs(hand - hand_clear)
        if err < best[0]:
            best = (err, deg, dz, hand)
    _, deg, dz, hand = best
    print(f"GHOST_MOCAP|crawl grounding pitch={deg:.1f}deg dz={dz:.3f}m hand_low={hand:.3f}m (rest floor {rest_floor:.3f})")
    Rl = (Mi @ Matrix.Rotation(math.radians(deg), 3, "X") @ M3).to_quaternion()
    off = Mi @ Vector((0, 0, dz))
    return [Rl @ quats["hips"][i] for i in range(n)], [hips_loc[i] + off for i in range(n)]


def write_custom_action(rig, name, quats, locs, n):
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
            bn = pb.name
            q = quats[bn][i] if bn in quats else Quaternion()
            p = prev.get(bn)
            if p is not None and p.dot(q) < 0:
                q = -q
            prev[bn] = q
            pb.rotation_quaternion = q
            loc = locs[bn][i] if (bn in locs and i < len(locs[bn])) else Vector()
            pb.location = loc
            pb.keyframe_insert("rotation_quaternion", frame=i + 1, group=bn)
            if loc.length > 1e-5 or bn in ("root", "hips", "tongue_01", "forearm.R", "hand.R"):
                pb.keyframe_insert("location", frame=i + 1, group=bn)
    act.frame_range = (1, n)
    return act


def build_all_ghost_clips():
    all_clips = {}
    rest_all = {}

    # ------------------------------------------------------------------
    # PART 1: Pop clips (opened from pop.blend which has tongue_01..03 and procedural Pop actions)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "pop.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True

    for bn in rig.data.bones:
        q = bn.matrix_local.to_quaternion()
        h = bn.head_local * STUDS_PER_M
        rest_all[bn.name] = [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6), round(h.x, 5), round(h.y, 5), round(h.z, 5)]

    zwalk_q, zwalk_hl, zwalk_n = load_mocap_raw(rig, "Zombie Walk.fbx", dict(loop=16, inplace=True))
    zidle_q, zidle_hl, zidle_n = load_mocap_raw(rig, "Zombie Idle.fbx", dict(loop=30, inplace=True))
    zscream_q, zscream_hl, zscream_n = load_mocap_raw(rig, "Zombie Scream.fbx", dict(loop=0, inplace=True))
    zcrawl_q, zcrawl_hl, zcrawl_n = load_mocap_raw(rig, "Running Crawl.fbx", dict(loop=8, inplace=True))

    # 1.1 Pop: TwitchWalk = Zombie Walk mocap + Pop's twitch pulses & clawed fingers
    proc_tw_q, proc_tw_loc = sample_action(rig, bpy.data.actions["TwitchWalk"], zwalk_n)
    tw_q, tw_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in FINGER_BONES["L"] or bn in FINGER_BONES["R"] or bn.startswith("tongue"):
            tw_q[bn] = proc_tw_q[bn]
        elif bn in ("neck", "head"):
            # Blend Zombie Walk neck/head with Pop's sudden neck/head twitches
            tw_q[bn] = [slerp_q(zwalk_q[bn][i], proc_tw_q[bn][i], 0.45) for i in range(zwalk_n)]
        elif bn in LEG_BONES:
            # Slightly damp leg swing to 80% so skirt doesn't clip
            tw_q[bn] = [slerp_q(Quaternion(), zwalk_q[bn][i], 0.80) for i in range(zwalk_n)]
        elif bn in zwalk_q:
            tw_q[bn] = zwalk_q[bn]
        else:
            tw_q[bn] = [Quaternion() for _ in range(zwalk_n)]
    tw_loc["hips"] = [v * 0.75 for v in zwalk_hl]
    write_custom_action(rig, "Pop_TwitchWalk", tw_q, tw_loc, zwalk_n)

    # 1.2 Pop: LickLips = Zombie Idle body/arms + Pop's LickLips head tilt, claws & tongue_01..03 licking
    lick_n = 96
    zi_96_q, zi_96_hl = resample_tracks(zidle_q, zidle_hl, lick_n)
    proc_ll_q, proc_ll_loc = sample_action(rig, bpy.data.actions["LickLips"], lick_n)
    ll_q, ll_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn.startswith("tongue") or bn in FINGER_BONES["L"] or bn in FINGER_BONES["R"]:
            ll_q[bn] = proc_ll_q[bn]
            ll_loc[bn] = proc_ll_loc[bn]
        elif bn in ("neck", "head"):
            # Keep Pop's chin-forward pose so tongue clears mouth, plus 35% Zombie Idle sway
            q0 = zi_96_q[bn][0]
            ll_q[bn] = [slerp_q(Quaternion(), zi_96_q[bn][i] @ q0.inverted(), 0.35) @ proc_ll_q[bn][i] for i in range(lick_n)]
        elif bn in zi_96_q:
            ll_q[bn] = [slerp_q(proc_ll_q[bn][i], zi_96_q[bn][i], 0.75) for i in range(lick_n)]
        else:
            ll_q[bn] = proc_ll_q[bn]
    ll_loc["hips"] = zi_96_hl
    write_custom_action(rig, "Pop_LickLips", ll_q, ll_loc, lick_n)

    # 1.3 Pop: PossessedSnap = Zombie Scream mocap + clawed fingers + tongue thrust + head twist
    proc_ps_q, proc_ps_loc = sample_action(rig, bpy.data.actions["PossessedSnap"], zscream_n)
    proc_ll_scream_q, proc_ll_scream_loc = sample_action(rig, bpy.data.actions["LickLips"], zscream_n)
    ps_q, ps_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn.startswith("tongue"):
            ps_q[bn] = proc_ll_scream_q[bn]
            ps_loc[bn] = proc_ll_scream_loc[bn]
        elif bn in FINGER_BONES["L"] or bn in FINGER_BONES["R"]:
            ps_q[bn] = proc_ps_q[bn]
        elif bn in zscream_q:
            ps_q[bn] = zscream_q[bn]
        else:
            ps_q[bn] = [Quaternion() for _ in range(zscream_n)]
    ps_loc["hips"] = zscream_hl
    write_custom_action(rig, "Pop_PossessedSnap", ps_q, ps_loc, zscream_n)

    # 1.4 Pop: KnockShutter = KnockShutter arms/head + Zombie Idle lower body & spine sway
    knock_n = 60
    zi_60_q, zi_60_hl = resample_tracks(zidle_q, zidle_hl, knock_n)
    proc_ks_q, proc_ks_loc = sample_action(rig, bpy.data.actions["KnockShutter"], knock_n)
    ks_q, ks_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in LEG_BONES or bn == "hips":
            ks_q[bn] = [slerp_q(proc_ks_q[bn][i], zi_60_q[bn][i], 0.75) for i in range(knock_n)]
        elif bn in ("spine", "chest"):
            q0 = zi_60_q[bn][0]
            ks_q[bn] = [slerp_q(Quaternion(), zi_60_q[bn][i] @ q0.inverted(), 0.5) @ proc_ks_q[bn][i] for i in range(knock_n)]
        else:
            ks_q[bn] = proc_ks_q[bn]
    ks_loc["hips"] = [v * 0.6 for v in zi_60_hl]
    write_custom_action(rig, "Pop_KnockShutter", ks_q, ks_loc, knock_n)

    # 1.5 Pop: Crawl = Running Crawl mocap + clawed fingers + grounded hip height
    proc_crawl_q, _ = sample_action(rig, bpy.data.actions["TwitchWalk"], zcrawl_n)
    cr_q, cr_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in FINGER_BONES["L"] or bn in FINGER_BONES["R"]:
            cr_q[bn] = proc_crawl_q[bn]
        elif bn in zcrawl_q:
            cr_q[bn] = zcrawl_q[bn]
        else:
            cr_q[bn] = [Quaternion() for _ in range(zcrawl_n)]
    # Our arms are longer than the Mixamo source's, so a plain hip drop buries the hands. Solve a hip height + body
    # pitch so the lowest fingertip and the lowest toe both just touch the ground over the loop.
    cr_q["hips"], cr_loc["hips"] = ground_crawl(rig, cr_q, zcrawl_hl, zcrawl_n)
    write_custom_action(rig, "Pop_Crawl", cr_q, cr_loc, zcrawl_n)

    pop_actions = ["Pop_TwitchWalk", "Pop_LickLips", "Pop_PossessedSnap", "Pop_KnockShutter", "Pop_Crawl"]
    export_actions_to_dict(rig, pop_actions, all_clips, step=2)

    # ------------------------------------------------------------------
    # PART 2: ghost_dancer (Bellydancing + Thai classical dance arms/hands)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_dancer.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True

    belly_q, belly_hl, belly_n = load_mocap_raw(rig, "Bellydancing.fbx", dict(loop=24, inplace=True))
    zi_d_q, zi_d_hl, zi_d_n = load_mocap_raw(rig, "Zombie Idle.fbx", dict(loop=30, inplace=True))

    # 2.1 dancer_dance: Bellydancing hip/spine/chest/shoulder undulation + Thai classical dance arms/hands (wong/jeeb)
    # Remove any 360-degree turn on hips so she faces forward and her pha sin skirt never twists
    dance_n = 240
    b_240_q, b_240_hl = resample_tracks(belly_q, belly_hl, dance_n)
    proc_dd_q, proc_dd_loc = sample_action(rig, bpy.data.actions["dancer_dance"], dance_n)
    dd_q, dd_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in FINGER_BONES["L"] or bn in FINGER_BONES["R"] or bn in ("hand.L", "hand.R"):
            # Authentic Thai classical wong / jeeb hand & wrist poses
            dd_q[bn] = proc_dd_q[bn]
        elif bn in ("shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"):
            # Thai classical arm positions + 35% additive fluid wave from Bellydancing
            q0 = b_240_q[bn][0]
            dq = [slerp_q(Quaternion(), b_240_q[bn][i] @ q0.inverted(), 0.35) for i in range(dance_n)]
            dd_q[bn] = [dq[i] @ proc_dd_q[bn][i] for i in range(dance_n)]
        elif bn in ("spine", "chest", "neck", "head"):
            # Rich Bellydancing upper-body & waist undulation + ghost_dancer's eerie head twitches
            q0 = b_240_q[bn][0]
            gain = 0.85 if bn in ("spine", "chest") else 0.55
            dq = [slerp_q(Quaternion(), b_240_q[bn][i] @ q0.inverted(), gain) for i in range(dance_n)]
            dd_q[bn] = [dq[i] @ proc_dd_q[bn][i] for i in range(dance_n)]
        elif bn == "hips":
            # Keep pitch & roll sway from Bellydancing, clamp yaw to +-18 deg so she doesn't spin 180 deg backward
            hq = []
            q0 = b_240_q["hips"][0]
            for i in range(dance_n):
                dq_eul = (b_240_q["hips"][i] @ q0.inverted()).to_euler("XYZ")
                dq_eul.y = max(math.radians(-18), min(math.radians(18), dq_eul.y * 0.25))
                hq.append(dq_eul.to_quaternion() @ proc_dd_q["hips"][i])
            dd_q["hips"] = hq
        elif bn in LEG_BONES:
            # Thai classical knee plie + 35% additive rhythm from Bellydancing
            q0 = b_240_q[bn][0]
            dq = [slerp_q(Quaternion(), b_240_q[bn][i] @ q0.inverted(), 0.35) for i in range(dance_n)]
            dd_q[bn] = [dq[i] @ proc_dd_q[bn][i] for i in range(dance_n)]
        else:
            dd_q[bn] = proc_dd_q[bn]
    dd_loc["hips"] = [b_240_hl[i] * 0.5 + proc_dd_loc["hips"][i] * 0.7 for i in range(dance_n)]
    write_custom_action(rig, "dancer_dance", dd_q, dd_loc, dance_n)

    # 2.2 dancer_idle: Zombie Idle subtle body sway + Thai classical waiting arms
    idle_n = 120
    zi_120_q, zi_120_hl = resample_tracks(zi_d_q, zi_d_hl, idle_n)
    proc_di_q, proc_di_loc = sample_action(rig, bpy.data.actions["dancer_idle"], idle_n)
    di_q, di_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in UPPER_ARM_CHAIN["L"] or bn in UPPER_ARM_CHAIN["R"]:
            di_q[bn] = proc_di_q[bn]
        elif bn in zi_120_q:
            di_q[bn] = [slerp_q(proc_di_q[bn][i], zi_120_q[bn][i], 0.65) for i in range(idle_n)]
        else:
            di_q[bn] = proc_di_q[bn]
    di_loc["hips"] = [zi_120_hl[i] * 0.6 + proc_di_loc["hips"][i] * 0.4 for i in range(idle_n)]
    write_custom_action(rig, "dancer_idle", di_q, di_loc, idle_n)

    export_actions_to_dict(rig, ["dancer_dance", "dancer_idle"], all_clips, step=2)

    # ------------------------------------------------------------------
    # PART 3: ghost_tani (ghost_idle, tani_peek)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_tani.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True

    zi_t_q, zi_t_hl, zi_t_n = load_mocap_raw(rig, "Zombie Idle.fbx", dict(loop=30, inplace=True))
    tani_n = 120
    zi_t120_q, zi_t120_hl = resample_tracks(zi_t_q, zi_t_hl, tani_n)
    proc_gi_q, proc_gi_loc = sample_action(rig, bpy.data.actions["ghost_idle"], tani_n)
    gi_q, gi_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in ("foot.L", "foot.R", "toe.L", "toe.R"):
            gi_q[bn] = proc_gi_q[bn]  # hanging floating toes
        elif bn in zi_t120_q:
            gi_q[bn] = [slerp_q(proc_gi_q[bn][i], zi_t120_q[bn][i], 0.75) for i in range(tani_n)]
        else:
            gi_q[bn] = proc_gi_q[bn]
    gi_loc["root"] = proc_gi_loc["root"]
    gi_loc["hips"] = [v * 0.7 for v in zi_t120_hl]
    write_custom_action(rig, "ghost_idle", gi_q, gi_loc, tani_n)

    # tani_peek: Zombie Idle base + leaning out & pointing right arm, kept alive (user 2026-11-12: "still very stiff"):
    # full-strength mocap torso sway, the pointing arm drifts with the mocap arm, a slow head roll and sudden head twitches.
    peek_n = 150
    zi_t150_q, zi_t150_hl = resample_tracks(zi_t_q, zi_t_hl, peek_n)
    proc_tp_q, proc_tp_loc = sample_action(rig, bpy.data.actions["tani_peek"], peek_n)
    print("GHOST_MOCAP|zombie idle native frames", zi_t_n, "-> tani_peek", peek_n)

    def twitch(i, n, at, width=6):
        # 0..1..0 pulse: snaps in over 2 frames, eases back over `width` frames
        d = (i - at) % n
        if d < 2:
            return d / 2
        if d < 2 + width:
            return 1 - (d - 2) / width
        return 0.0

    def head_extra(i):
        t = i / FPS
        roll = math.radians(9) * math.sin(t * 2 * math.pi / 5.0)  # one slow head roll across the loop
        nod = math.radians(4) * math.sin(t * 2 * math.pi / 2.5 + 1.1)
        tw = twitch(i, peek_n, 38) - 0.8 * twitch(i, peek_n, 104)  # two sharp twitches, opposite sides
        return Quaternion((0, 0, 1), roll + math.radians(16) * tw) @ Quaternion((1, 0, 0), nod)

    tp_q, tp_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in UPPER_ARM_CHAIN["R"]:
            if bn in zi_t150_q and bn in ("shoulder.R", "upper_arm.R", "forearm.R", "hand.R"):
                q0 = zi_t150_q[bn][0]
                dq = [slerp_q(Quaternion(), zi_t150_q[bn][i] @ q0.inverted(), 0.4) for i in range(peek_n)]
                tp_q[bn] = [dq[i] @ proc_tp_q[bn][i] for i in range(peek_n)]
            else:
                tp_q[bn] = proc_tp_q[bn]  # pointing fingers
        elif bn in ("spine", "chest", "neck", "head"):
            q0 = zi_t150_q[bn][0]
            dq = [slerp_q(Quaternion(), zi_t150_q[bn][i] @ q0.inverted(), 0.95) for i in range(peek_n)]
            tp_q[bn] = [dq[i] @ proc_tp_q[bn][i] for i in range(peek_n)]
            if bn == "head":
                tp_q[bn] = [head_extra(i) @ tp_q[bn][i] for i in range(peek_n)]
            elif bn == "neck":
                tp_q[bn] = [slerp_q(Quaternion(), head_extra(i), 0.35) @ tp_q[bn][i] for i in range(peek_n)]
        elif bn in ("foot.L", "foot.R", "toe.L", "toe.R"):
            tp_q[bn] = proc_tp_q[bn]
        elif bn in zi_t150_q:
            tp_q[bn] = [slerp_q(proc_tp_q[bn][i], zi_t150_q[bn][i], 0.90) for i in range(peek_n)]
        else:
            tp_q[bn] = proc_tp_q[bn]
    tp_loc["root"] = proc_tp_loc["root"]
    tp_loc["hips"] = [v * 0.9 for v in zi_t150_hl]
    write_custom_action(rig, "tani_peek", tp_q, tp_loc, peek_n)

    # tani_walk: slow dragging Zombie Walk for coming out of the banana grove (was a stiff ghost_idle slide)
    zw_t_q, zw_t_hl, zw_t_n = load_mocap_raw(rig, "Zombie Walk.fbx", dict(loop=16, inplace=True))
    tw2_q, tw2_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in LEG_BONES:
            tw2_q[bn] = [slerp_q(Quaternion(), zw_t_q[bn][i], 0.8) for i in range(zw_t_n)]  # skirt-safe stride
        elif bn in zw_t_q:
            tw2_q[bn] = zw_t_q[bn]
        else:
            tw2_q[bn] = [Quaternion() for _ in range(zw_t_n)]
    tw2_q["head"] = [Quaternion((1, 0, 0), math.radians(10)) @ q for q in tw2_q["head"]]  # chin down, hair over the face
    tw2_loc["hips"] = [v * 0.75 for v in zw_t_hl]
    write_custom_action(rig, "tani_walk", tw2_q, tw2_loc, zw_t_n)

    export_actions_to_dict(rig, ["ghost_idle", "tani_peek", "tani_walk"], all_clips, step=2)

    # ------------------------------------------------------------------
    # PART 4: ghost_mae_nak (nak_cradle, nak_reach)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_mae_nak.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True

    zi_n_q, zi_n_hl, _ = load_mocap_raw(rig, "Zombie Idle.fbx", dict(loop=30, inplace=True))
    nak_n = 150
    zi_n150_q, zi_n150_hl = resample_tracks(zi_n_q, zi_n_hl, nak_n)

    # 4.1 nak_cradle: Left arm holds baby (NAK_CRADLE), torso/head/right-arm/legs sway with Zombie Idle
    proc_nc_q, proc_nc_loc = sample_action(rig, bpy.data.actions["nak_cradle"], nak_n)
    nc_q, nc_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in UPPER_ARM_CHAIN["L"]:
            nc_q[bn] = proc_nc_q[bn]  # holds baby
        elif bn in ("spine", "chest", "neck", "head"):
            q0 = zi_n150_q[bn][0]
            dq = [slerp_q(Quaternion(), zi_n150_q[bn][i] @ q0.inverted(), 0.6) for i in range(nak_n)]
            nc_q[bn] = [dq[i] @ proc_nc_q[bn][i] for i in range(nak_n)]
        elif bn in zi_n150_q:
            nc_q[bn] = [slerp_q(proc_nc_q[bn][i], zi_n150_q[bn][i], 0.70) for i in range(nak_n)]
        else:
            nc_q[bn] = proc_nc_q[bn]
    nc_loc["root"] = proc_nc_loc["root"]
    nc_loc["hips"] = [v * 0.65 for v in zi_n150_hl]
    write_custom_action(rig, "nak_cradle", nc_q, nc_loc, nak_n)

    # 4.2 nak_reach: Left arm holds baby, right arm stretches out (with forearm.R/hand.R location keys), Zombie Idle sway
    proc_nr_q, proc_nr_loc = sample_action(rig, bpy.data.actions["nak_reach"], nak_n)
    nr_q, nr_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in UPPER_ARM_CHAIN["L"] or bn in UPPER_ARM_CHAIN["R"]:
            nr_q[bn] = proc_nr_q[bn]
            nr_loc[bn] = proc_nr_loc[bn]
        elif bn in ("spine", "chest", "neck", "head"):
            q0 = zi_n150_q[bn][0]
            dq = [slerp_q(Quaternion(), zi_n150_q[bn][i] @ q0.inverted(), 0.45) for i in range(nak_n)]
            nr_q[bn] = [dq[i] @ proc_nr_q[bn][i] for i in range(nak_n)]
        elif bn in zi_n150_q:
            nr_q[bn] = [slerp_q(proc_nr_q[bn][i], zi_n150_q[bn][i], 0.65) for i in range(nak_n)]
        else:
            nr_q[bn] = proc_nr_q[bn]
    nr_loc["root"] = proc_nr_loc["root"]
    nr_loc["hips"] = [v * 0.55 for v in zi_n150_hl]
    write_custom_action(rig, "nak_reach", nr_q, nr_loc, nak_n)

    export_actions_to_dict(rig, ["nak_cradle", "nak_reach"], all_clips, step=2)

    # ------------------------------------------------------------------
    # PART 5: Funeral ghosts & Shroud (coffin_walk, ghost_glide, shroud_idle, shroud_glide)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_funeral_man.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True

    zw_f_q, zw_f_hl, zw_f_n = load_mocap_raw(rig, "Zombie Walk.fbx", dict(loop=16, inplace=True))

    # 5.1 coffin_walk: Zombie Walk legs/torso/left-arm + right arm holding coffin pole (COFFIN_ARM)
    proc_cw_q, _ = sample_action(rig, bpy.data.actions["coffin_walk"], zw_f_n)
    cw_q, cw_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in UPPER_ARM_CHAIN["R"]:
            cw_q[bn] = proc_cw_q[bn]  # holds coffin pole
        elif bn in LEG_BONES:
            cw_q[bn] = [slerp_q(proc_cw_q[bn][i], zw_f_q[bn][i], 0.65) for i in range(zw_f_n)]
        elif bn in zw_f_q:
            cw_q[bn] = [slerp_q(proc_cw_q[bn][i], zw_f_q[bn][i], 0.75) for i in range(zw_f_n)]
        else:
            cw_q[bn] = proc_cw_q[bn]
    cw_loc["hips"] = [v * 0.65 for v in zw_f_hl]
    write_custom_action(rig, "coffin_walk", cw_q, cw_loc, zw_f_n)

    # 5.2 ghost_glide: Full Zombie Walk shamble (stride 75% so skirts don't clip)
    gg_q, gg_loc = {}, {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in LEG_BONES:
            gg_q[bn] = [slerp_q(Quaternion(), zw_f_q[bn][i], 0.75) for i in range(zw_f_n)]
        elif bn in zw_f_q:
            gg_q[bn] = zw_f_q[bn]
        else:
            gg_q[bn] = [Quaternion() for _ in range(zw_f_n)]
    gg_loc["hips"] = [v * 0.75 for v in zw_f_hl]
    write_custom_action(rig, "ghost_glide", gg_q, gg_loc, zw_f_n)

    export_actions_to_dict(rig, ["coffin_walk", "ghost_glide"], all_clips, step=2)

    # 5.3 ghost_shroud (shroud_idle, shroud_glide)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_shroud.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True
    zi_s_q, zi_s_hl, _ = load_mocap_raw(rig, "Zombie Idle.fbx", dict(loop=30, inplace=True))
    for cname, n_fr in (("shroud_idle", 120), ("shroud_glide", 90)):
        zi_s_res_q, zi_s_res_hl = resample_tracks(zi_s_q, zi_s_hl, n_fr)
        proc_s_q, proc_s_loc = sample_action(rig, bpy.data.actions[cname], n_fr)
        sq, sloc = {}, {}
        for pb in rig.pose.bones:
            bn = pb.name
            if bn in ("spine", "chest", "neck", "head"):
                q0 = zi_s_res_q[bn][0]
                dq = [slerp_q(Quaternion(), zi_s_res_q[bn][i] @ q0.inverted(), 0.55) for i in range(n_fr)]
                sq[bn] = [dq[i] @ proc_s_q[bn][i] for i in range(n_fr)]
            else:
                sq[bn] = proc_s_q[bn]
        sloc["root"] = proc_s_loc["root"]
        sloc["hips"] = [v * 0.4 for v in zi_s_res_hl]
        write_custom_action(rig, cname, sq, sloc, n_fr)
    export_actions_to_dict(rig, ["shroud_idle", "shroud_glide"], all_clips, step=2)

    # ------------------------------------------------------------------
    # PART 6: Seated motorcycle ghosts (pillion_hug, pillion_look, mask_tilt)
    # ------------------------------------------------------------------
    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_mirror.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True
    sit_q, sit_hl, _ = load_mocap_raw(rig, "Sitting Idle.fbx", dict(loop=30, inplace=True))
    for cname, n_fr in (("pillion_hug", 120), ("pillion_look", 150)):
        sit_res_q, _ = resample_tracks(sit_q, sit_hl, n_fr)
        proc_p_q, proc_p_loc = sample_action(rig, bpy.data.actions[cname], n_fr)
        pq = {}
        for pb in rig.pose.bones:
            bn = pb.name
            if bn in ("spine", "chest", "neck", "head", "shoulder.L", "shoulder.R"):
                q0 = sit_res_q[bn][0]
                dq = [slerp_q(Quaternion(), sit_res_q[bn][i] @ q0.inverted(), 0.85) for i in range(n_fr)]
                pq[bn] = [dq[i] @ proc_p_q[bn][i] for i in range(n_fr)]
            else:
                pq[bn] = proc_p_q[bn]
        write_custom_action(rig, cname, pq, proc_p_loc, n_fr)
    export_actions_to_dict(rig, ["pillion_hug", "pillion_look"], all_clips, step=2)

    bpy.ops.wm.open_mainfile(filepath=os.path.join(M, "human_ghosts", "ghost_ta_khon.blend"))
    rig = bpy.data.objects["HumanRig"]
    for pb in rig.pose.bones:
        for c in pb.constraints:
            c.mute = True
    sit_tk_q, sit_tk_hl, _ = load_mocap_raw(rig, "Sitting Idle.fbx", dict(loop=30, inplace=True))
    sit_tk150_q, _ = resample_tracks(sit_tk_q, sit_tk_hl, 150)
    proc_mt_q, proc_mt_loc = sample_action(rig, bpy.data.actions["mask_tilt"], 150)
    mt_q = {}
    for pb in rig.pose.bones:
        bn = pb.name
        if bn in ("spine", "chest", "neck", "head", "shoulder.L", "shoulder.R"):
            q0 = sit_tk150_q[bn][0]
            dq = [slerp_q(Quaternion(), sit_tk150_q[bn][i] @ q0.inverted(), 0.85) for i in range(150)]
            mt_q[bn] = [dq[i] @ proc_mt_q[bn][i] for i in range(150)]
        else:
            mt_q[bn] = proc_mt_q[bn]
    write_custom_action(rig, "mask_tilt", mt_q, proc_mt_loc, 150)
    export_actions_to_dict(rig, ["mask_tilt"], all_clips, step=2)

    out_json = os.path.join(OUTD, "ghost_mocap_anims.json")
    json.dump({"fps": FPS, "studs_per_m": STUDS_PER_M, "rest": rest_all, "clips": all_clips}, open(out_json, "w"), separators=(",", ":"))
    print("GHOST_MOCAP|wrote json:", out_json, os.path.getsize(out_json), "bytes, clips:", list(all_clips.keys()))
    return rest_all, all_clips


def export_actions_to_dict(rig, names, dst_clips, step=2):
    sc = bpy.context.scene
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
                tracks.setdefault(pb.name, []).append([
                    round(q.x, 4), round(q.y, 4), round(q.z, 4), round(q.w, 4),
                    round(t.x, 4), round(t.y, 4), round(t.z, 4)
                ])
        moving = {
            n: k for n, k in tracks.items()
            if any(abs(a - b) > 1e-4 for r in k for a, b in zip(r, k[0]))
            or any(abs(v) > 1e-4 for v in k[0][:3] + k[0][4:])
        }
        dst_clips[clip] = {
            "length": round((f1 - f0) / FPS, 4),
            "times": [round((f - f0) / FPS, 4) for f in frames],
            "tracks": moving,
        }


def write_ghost_clip_luau(rest_all, all_clips):
    """Convert all_clips into Roblox Bone.Transform CFrame keys in src/shared/GhostClipData.luau."""
    cl_ns = {"__file__": os.path.join(HERE, "clips_to_luau.py"), "__name__": "cl"}
    cl_src = open(os.path.join(HERE, "clips_to_luau.py"), encoding="utf-8").read()
    exec(compile(cl_src, "clips_to_luau.py", "exec"), cl_ns)
    mm, mT, mv, sub, frame, qmat, mquat = cl_ns["mm"], cl_ns["mT"], cl_ns["mv"], cl_ns["sub"], cl_ns["frame"], cl_ns["qmat"], cl_ns["mquat"]

    rbx = json.load(open(os.path.join(ROOT, "tools", "studio", "human_base_rbx_rest.json")))
    # Add Pop's tongue_01..03 rest frames measured from Studio
    rbx.update({
        "tongue_01": [0.0294, 5.31685, -0.17745, 0.79487, -0.57761, 0.18588, -0.18588, -0.5234, -0.83157, 0.57761, 0.62643, -0.5234],
        "tongue_02": [0.0161, 5.2794, -0.23695, 0.78751, -0.58686, 0.18818, -0.18818, -0.51973, -0.83335, 0.58686, 0.62087, -0.51973],
        "tongue_03": [0.00875, 5.2591, -0.2695, 0.77408, -0.60244, 0.19459, -0.19459, -0.51889, -0.8324, 0.60244, 0.60648, -0.51889],
    })
    R = {n: [v[3:6], v[6:9], v[9:12]] for n, v in rbx.items()}
    P = {n: v[0:3] for n, v in rbx.items()}
    bp = {n: v[4:7] for n, v in rest_all.items()}
    C = mm(
        frame(sub(P["head"], P["hips"]), sub(P["thigh.L"], P["thigh.R"])),
        mT(frame(sub(bp["head"], bp["hips"]), sub(bp["thigh.L"], bp["thigh.R"])))
    )

    def convert(key, rq, Rr):
        B = qmat(*rq[:4])
        rot = mm(mm(mm(mT(Rr), C), mm(mm(B, qmat(*key[:4])), mT(B))), mm(mT(C), Rr))
        t = mv(mT(Rr), mv(mm(C, B), key[4:7]))
        return [round(float(v), 3) for v in t] + [round(float(v), 4) for v in mquat(rot)]

    ONCE = {"Pop_PossessedSnap", "nak_reach"}
    lines = [
        "--!strict",
        "-- GENERATED by tools/blender/ghost_mocap_retarget.py - do not edit by hand.",
        "-- Pre-converted Roblox Bone.Transform keys (x, y, z, qx, qy, qz, qw) for Mixamo-retargeted ghost animations.",
        "return {",
    ]
    for name, clip in all_clips.items():
        lines.append(f'\t["{name}"] = {{ length = {clip["length"]:.4f}, once = {"true" if name in ONCE else "false"},')
        lines.append("\t\ttimes = { " + ", ".join(f"{t:g}" for t in clip["times"]) + " },")
        lines.append("\t\ttracks = {")
        for bone, keys in clip["tracks"].items():
            if bone not in R or bone not in rest_all:
                continue
            ks = [convert(k, rest_all[bone], R[bone]) for k in keys]
            if all(k == ks[0] for k in ks):
                ks = ks[:1]
            lines.append(f'\t\t\t["{bone}"] = {{ ' + ", ".join("{" + ", ".join(f"{v:g}" for v in k) + "}" for k in ks) + " },")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    out_luau = os.path.join(ROOT, "src", "shared", "GhostClipData.luau")
    open(out_luau, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("GHOST_MOCAP|wrote Luau:", out_luau, os.path.getsize(out_luau), "bytes")


def write_studio_chunks():
    """Write split part*.txt into assets/models/mocap/out/studio/ghost_mocap/ so Studio can also build KeyframeSequences."""
    src_json = os.path.join(OUTD, "ghost_mocap_anims.json")
    raw = open(src_json, "rb").read().decode("utf-8")
    dst_dir = os.path.join(OUTD, "studio", "ghost_mocap")
    os.makedirs(dst_dir, exist_ok=True)
    for f in os.listdir(dst_dir):
        os.remove(os.path.join(dst_dir, f))
    chunk = 180000
    for i in range(0, len(raw), chunk):
        open(os.path.join(dst_dir, f"part{i // chunk:03d}.txt"), "w", encoding="utf-8", newline="\n").write(raw[i:i + chunk])
    print("GHOST_MOCAP|wrote studio chunks:", (len(raw) + chunk - 1) // chunk)


def render_preview(all_clips):
    """Render a 5-row x 6-column EEVEE preview sheet of the 5 Mixamo-upgraded ghost animations on our ghosts."""
    rows_spec = [
        (os.path.join(M, "pop.blend"), "Pop_TwitchWalk"),
        (os.path.join(M, "pop.blend"), "Pop_LickLips"),
        (os.path.join(M, "pop.blend"), "Pop_PossessedSnap"),
        (os.path.join(M, "pop.blend"), "Pop_Crawl"),
        (os.path.join(M, "human_ghosts", "ghost_dancer.blend"), "dancer_dance"),
        (os.path.join(M, "human_ghosts", "ghost_tani.blend"), "tani_peek"),
        (os.path.join(M, "human_ghosts", "ghost_tani.blend"), "tani_walk"),
        (os.path.join(M, "human_ghosts", "ghost_funeral_man.blend"), "coffin_walk"),
    ]
    rows_img = []
    for blend_path, clip_name in rows_spec:
        bpy.ops.wm.open_mainfile(filepath=blend_path)
        try:
            bpy.ops.file.find_missing_files(directory=M)
        except Exception:
            pass
        rig = bpy.data.objects["HumanRig"]
        for pb in rig.pose.bones:
            for c in pb.constraints:
                c.mute = True
        sc = bpy.context.scene
        for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                sc.render.engine = eng
                break
            except TypeError:
                pass
        sc.view_settings.view_transform = "Standard"
        w = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
        sc.world = w
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.16, 0.17, 0.19, 1)
        bg.inputs[1].default_value = 0.8

        for n in ("_key", "_fill", "_cam"):
            o = bpy.data.objects.get(n)
            if o:
                bpy.data.objects.remove(o, do_unlink=True)
        for nm, rot, e in (("_key", (55, 0, -35), 3.2), ("_fill", (70, 0, 55), 1.4)):
            l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "SUN"))
            l.data.energy = e
            l.rotation_euler = [math.radians(a) for a in rot]
            sc.collection.objects.link(l)

        cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.05
        sc.render.resolution_x, sc.render.resolution_y = 200, 270
        tgt = Vector((0, 0, 0.88))
        d = Vector((0.42, -0.90, 0.08)).normalized()
        cam.location = tgt + d * 4.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()

        clip = all_clips[clip_name]
        tracks = clip["tracks"]
        n_keys = len(clip["times"])
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"

        row_tiles = []
        for k in range(6):
            idx = min(n_keys - 1, int(round(k * (n_keys - 1) / 5)))
            for pb in rig.pose.bones:
                pb.rotation_quaternion = Quaternion()
                pb.location = Vector()
                if pb.name in tracks:
                     key = tracks[pb.name][idx]
                     pb.rotation_quaternion = Quaternion((key[3], key[0], key[1], key[2]))
                     pb.location = Vector((key[4], key[5], key[6])) / STUDS_PER_M
            bpy.context.view_layer.update()
            tmp = os.path.join(OUTD, "_tmp_tile.png")
            sc.render.filepath = tmp
            bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp)
            arr = np.empty(im.size[0] * im.size[1] * 4, np.float32)
            im.pixels.foreach_get(arr)
            row_tiles.append(arr.reshape(im.size[1], im.size[0], 4))
            bpy.data.images.remove(im)
            os.remove(tmp)
        rows_img.append(np.concatenate(row_tiles, 1))

    sheet = np.concatenate(rows_img[::-1], 0)
    out_png = os.path.join(OUTD, "ghost_mocap_preview.png")
    im = bpy.data.images.new("_sheet", sheet.shape[1], sheet.shape[0])
    im.pixels.foreach_set(sheet.ravel())
    im.filepath_raw = out_png
    im.file_format = "PNG"
    im.save()
    bpy.data.images.remove(im)
    print("GHOST_MOCAP|wrote preview:", out_png)


if __name__ == "__main__":
    rest_all, all_clips = build_all_ghost_clips()
    write_ghost_clip_luau(rest_all, all_clips)
    write_studio_chunks()
    render_preview(all_clips)
