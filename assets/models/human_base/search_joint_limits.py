# For each joint motion, sweep the angle until two body regions intersect and
# report the largest safe angle. Uses region/check helpers from test_self_intersection.py.
import bpy, math
exec(open(r"C:\Aunival\pump-lot-anomaly\assets\models\human_base\test_self_intersection.py", encoding="utf-8").read().split("POSES = {")[0])

def mute(on):
    for b in pb:
        for c in b.constraints:
            if c.type == 'LIMIT_ROTATION': c.mute = on

def hit(pairs):
    global PAIRS
    keep = PAIRS; PAIRS = pairs
    import io, contextlib
    with contextlib.redirect_stdout(io.StringIO()):
        h = check("")
    PAIRS = keep
    return bool(h)

def sweep(label, base, bone, axis, sign, pairs, step=5, top=180, mirror=True):
    reset(); base()
    rot0 = list(pb[bone].rotation_euler)
    last = 0
    for a in range(step, top + 1, step):
        e = list(rot0); e[axis] = rot0[axis] + math.radians(a*sign)
        pb[bone].rotation_euler = e
        if mirror and bone.endswith(".L"):
            o = pb[bone[:-2] + ".R"]; e2 = list(o.rotation_euler)
            flip = -1 if axis == 2 and bone.split(".")[0].split("_")[0] in ("shoulder", "upper_arm", "forearm", "hand", "thigh", "foot", "index", "middle", "ring", "pinky", "thumb") else 1
            if axis == 1: flip = -1
            e2[axis] = e[axis]*flip if axis != 0 else e[axis]
            o.rotation_euler = e2
        if hit(pairs): break
        last = a
    res = max(0, last - 5)
    print(f"{label:34s} safe {sign*res:+4d} deg  (first hit {'none' if last == top else sign*(last+step)})")
    return sign*res

mute(True)
L = lambda *n: [(a, b) for a, b in n]
r = {}
r["knee flex"] = sweep("knee flex (shin -X)", lambda: None, "shin.L", 0, -1, L(("shin.L", "thigh.L"), ("foot.L", "thigh.L")))
r["elbow flex"] = sweep("elbow flex (forearm -Z)", lambda: None, "forearm.L", 2, -1, L(("farm.L", "uarm.L"), ("hand.L", "uarm.L")))
r["elbow flex arm down"] = sweep("elbow flex, arm down", lambda: R("upper_arm.L", x=-40), "forearm.L", 2, -1,
                                 L(("farm.L", "uarm.L"), ("hand.L", "uarm.L"), ("hand.L", "torso"), ("farm.L", "torso"), ("hand.L", "head")))
r["arm down"] = sweep("arm down (upper_arm -X)", lambda: None, "upper_arm.L", 0, -1,
                      L(("uarm.L", "torso"), ("farm.L", "torso"), ("hand.L", "torso"), ("hand.L", "thigh.L"), ("farm.L", "thigh.L")))
r["arm fwd at down"] = sweep("arm forward, arm down", lambda: R("upper_arm.L", x=-40), "upper_arm.L", 2, -1,
                             L(("hand.L", "hand.R"), ("farm.L", "farm.R"), ("hand.L", "thigh.L"), ("hand.L", "thigh.R"), ("farm.L", "torso"), ("hand.L", "torso")))
r["arm fwd level"] = sweep("arm forward, arm level", lambda: None, "upper_arm.L", 2, -1,
                           L(("hand.L", "hand.R"), ("farm.L", "farm.R"), ("farm.L", "torso"), ("uarm.L", "torso")))
r["arm back at down"] = sweep("arm back, arm down", lambda: R("upper_arm.L", x=-40), "upper_arm.L", 2, +1,
                              L(("uarm.L", "torso"), ("farm.L", "torso"), ("hand.L", "torso"), ("hand.L", "hand.R")))
r["thigh adduct"] = sweep("thigh adduction (-Z)", lambda: None, "thigh.L", 2, -1,
                          L(("thigh.L", "thigh.R"), ("shin.L", "shin.R"), ("foot.L", "foot.R"), ("shin.L", "thigh.R")))
r["thigh flex"] = sweep("thigh flex (+X)", lambda: None, "thigh.L", 0, +1, L(("thigh.L", "torso"), ("shin.L", "torso"), ("thigh.L", "thigh.R")), mirror=False)
r["thigh flex knee bent"] = sweep("thigh flex, knee bent 90", lambda: R("shin.L", x=-90, mirror=False), "thigh.L", 0, +1,
                                  L(("thigh.L", "torso"), ("shin.L", "torso"), ("foot.L", "torso"), ("shin.L", "thigh.R"), ("foot.L", "thigh.R")), mirror=False)
r["thigh extend"] = sweep("thigh extend (-X)", lambda: None, "thigh.L", 0, -1, L(("thigh.L", "torso"),), mirror=False)
r["neck+head fwd"] = sweep("head forward (head +X)", lambda: R("neck", x=35, mirror=False), "head", 0, +1, L(("head", "torso"),), mirror=False)
r["neck+head back"] = sweep("head back (head -X)", lambda: R("neck", x=-30, mirror=False), "head", 0, -1, L(("head", "torso"),), mirror=False)
r["spine side w arm"] = sweep("spine side bend, arm down", lambda: R("upper_arm.L", x=-40), "spine", 2, -1,
                              L(("hand.L", "thigh.L"), ("farm.L", "thigh.L"), ("uarm.L", "torso"), ("farm.L", "torso"), ("hand.L", "torso")), mirror=False)
r["spine fwd w arm"] = sweep("spine bend fwd, arm down", lambda: R("upper_arm.L", x=-40), "spine", 0, +1,
                             L(("hand.L", "thigh.L"), ("farm.L", "thigh.L"), ("hand.R", "thigh.R"), ("hand.L", "torso")), mirror=False)
mute(False); reset(); bpy.context.view_layer.update()
print("RESULT", r)
