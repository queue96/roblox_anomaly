# Build any character (male/female/child/elder_male/elder_female) in any body type
# (normal/thin/fat, plus female pregnant) from the scripts, then save it next to its scripts.
#   build("male", "fat")    -> assets/models/human_base/human_base_fat.blend
#   build_all()             -> all 15 files (5 characters x normal/thin/fat)
# Pipeline: body -> rig -> armpit weights -> (child remap / elder posture) -> body type -> smooth joints
#           -> joint limits -> self-intersection test -> hair -> skin -> clothes -> anims -> save
import bpy, os

M = r"C:\Aunival\pump-lot-anomaly\assets\models"
BASE = os.path.join(M, "human_base")

CHARS = {
    "male":         dict(dir="human_base", file="human_base", steps=["build_body.py", "build_rig.py"], limits=None),
    "female":       dict(dir="human_female", file="human_female", steps=["build_body_female.py", "build_rig_female.py"], limits=None),
    "child":        dict(dir="human_child", file="human_child", steps=["build_body_child.py", "build_rig_child.py", "child_remap.py"], limits="child_limits.py"),
    "elder_male":   dict(dir="human_elder_male", file="human_elder_male", steps=["build_body_elder_male.py", "build_rig_elder_male.py"],
                         posture=dict(KYPHO=0.085, OVERALL=0.94, FRAME_SCALE=1.0, SHOULDER_FWD=0.03), limits="elder_male_limits.py"),
    "elder_female": dict(dir="human_elder_female", file="human_elder_female", steps=["build_body_elder_female.py", "build_rig_elder_female.py"],
                         posture=dict(KYPHO=0.045, OVERALL=0.94, FRAME_SCALE=0.93), limits="elder_female_limits.py"),
}
# fat bodies collide sooner: tighter knee/elbow/side-bend, arms rest a little further out
FAT_LIMITS = {"shin": (-75, 0, -10, 10, 0, 0), "forearm": (0, 0, -80, 80, -100, 0),
              "spine": (-25, 28, -25, 25, -5, 5), "chest": (-20, 22, -25, 25, -2, 2),
              "thigh": (-12, 90, -40, 40, 0, 45), "upper_arm": (-25, 120, -70, 70, -80, 45)}
TYPE_LIMITS = {(ch, "fat"): FAT_LIMITS for ch in CHARS}
TYPE_LIMITS[("child", "fat")] = dict(FAT_LIMITS, shin=(-65, 0, -10, 10, 0, 0))

# per-character body-type shape tweaks (see body_type.py: TYPE_OVERRIDES, BELLY=(forward, droop))
TYPE_SHAPE = {
    # chubby kid: round tummy that doesn't hang, sturdy legs
    # chest/shoulder widened so the armpit fills in under the chubby arms (no notch above the belly)
    ("child", "fat"): dict(BELLY=(0.70, 0.25), TYPE_OVERRIDES={"thigh": (1.60,)*3, "shin": (1.50,)*3,
                           "chest": (1.12, 1.35, 1.25), "shoulder": (1.25,)*3,
                           "spine": (1.18, 1.40, 1.25), "hips": (1.15, 1.20, 1.35)}),
    # elderly woman: her base calves are thin, so the fat legs get extra on the shins; soft, hanging belly and arms
    ("elder_female", "fat"): dict(BELLY=(0.85, 1.4), ARM_SAG=0.25, TYPE_OVERRIDES={"thigh": (1.45,)*3, "shin": (1.55,)*3}),
    # village woman, thin = slender (slim evenly, no knobby joints or hollow cheeks), not starved like the thin man
    ("female", "thin"): dict(KNOBBY=0.12, GAUNT=0.0, TYPE_OVERRIDES={
        "hips": (0.84, 0.74, 0.80), "spine": (0.80, 0.55, 0.88), "chest": (0.94, 0.92, 0.95), "neck": (0.82,)*3,
        "head": (0.97,)*3, "shoulder": (0.86,)*3, "upper_arm": (0.74,)*3, "forearm": (0.78,)*3,
        "thigh": (0.72,)*3, "shin": (0.76,)*3}),
    # village woman, fat = soft and saggy (no exercise): belly hangs low, flabby upper arms, thighs not muscular
    ("female", "fat"): dict(BELLY=(1.05, 1.6), ARM_SAG=0.30),
}

def run(path, ns):
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), ns)

def clear_scene():
    for o in list(bpy.data.objects):
        if o.type in ('MESH', 'ARMATURE'): bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.armatures):
        for d in list(coll):
            if d.users == 0: coll.remove(d)

def build(char, body_type="normal", save=True, test=True, clear=True):
    c = CHARS[char]; d = os.path.join(M, c["dir"])
    if clear: clear_scene()
    ns = {"__name__": "__variant__"}
    for st in c["steps"]: run(os.path.join(d, st), ns)
    if "posture" in c:
        ns.update(c["posture"]); run(os.path.join(BASE, "elder_posture.py"), ns)
    if body_type == "pregnant":
        if char != "female":
            raise ValueError("The pregnant body type is currently defined only for female.")
        run(os.path.join(BASE, "pregnancy.py"), {"__name__": "__variant__"})
        # Slightly shorter stature keeps the pregnant variant from reading taller than
        # the rest of the lineup. Scale mesh and rest bones together so animation
        # still sees matching body and armature transforms.
        scale = 0.96
        body = bpy.data.objects["Body"]
        rig = bpy.data.objects["HumanRig"]
        for vertex in body.data.vertices:
            vertex.co *= scale
        for obj in bpy.context.selected_objects:
            obj.select_set(False)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        for bone in rig.data.edit_bones:
            bone.head *= scale
            bone.tail *= scale
        bpy.ops.object.mode_set(mode="OBJECT")
    elif body_type != "normal":
        run(os.path.join(BASE, "body_type.py"), dict({"__name__": "__variant__", "BODY_TYPE": body_type},
                                                     **TYPE_SHAPE.get((char, body_type), {})))
    # thicker bodies need the chest/arm weight blend spread over a wider armpit area
    run(os.path.join(BASE, "armpit_weights.py"), {"__name__": "__variant__",
        "ARMPIT_RAD": (0.18 if char == "child" else 0.13) if body_type == "fat" else 0.09, "ARMPIT_ITER": 14 if body_type == "fat" else 8})
    run(os.path.join(BASE, "smooth_junctions.py"), {"__name__": "__variant__"})
    lns = {"__name__": "__variant__"}
    if c["limits"]:
        src = open(os.path.join(d, c["limits"]), encoding="utf-8").read()
        exec(src.split("exec(")[0], lns)            # picks up the character's LIMIT_OVERRIDES
    lns.setdefault("LIMIT_OVERRIDES", {}).update(TYPE_LIMITS.get((char, body_type), {}))
    run(os.path.join(BASE, "add_joint_limits.py"), lns)
    fails = []
    if test:
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            run(os.path.join(BASE, "test_self_intersection.py"), {"__name__": "__variant__"})
        fails = [l.strip() for l in buf.getvalue().splitlines() if "cm" in l]
    for b in bpy.data.objects["HumanRig"].pose.bones: b.rotation_euler = (0, 0, 0)
    hns = {"__name__": "__variant__"}                   # hairstyles fitted to this head (build_hair.py)
    run(os.path.join(BASE, "build_hair.py"), hns); hns["add_hair"](char)
    sns = {"__name__": "__variant__"}                   # UVs + skin textures painted by build_skin.py (skin_all)
    run(os.path.join(BASE, "build_skin.py"), sns); sns["add_skin"](char)
    cns = {"__name__": "__variant__"}                   # outfits from build_clothes.py (faces picked by clothes_all)
    run(os.path.join(BASE, "build_clothes.py"), cns); cns["add_clothes"](char)
    ans = {"__name__": "__variant__"}                   # weights down to 4 bones (Roblox) + animation clips (build_anims.py)
    run(os.path.join(BASE, "build_anims.py"), ans); ans["limit_weights"](); ans["add_anims"](char)
    if save:
        name = c["file"] + ("" if body_type == "normal" else "_" + body_type) + ".blend"
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(d, name))
    print(f"{char:13s} {body_type:6s} failed poses: {len(fails)}" + "".join("\n    " + f for f in fails))
    return fails

def build_all(types=("normal", "thin", "fat"), include_pregnant=True):
    results = {(ch, t): build(ch, t) for ch in CHARS for t in types}
    if include_pregnant:
        results[("female", "pregnant")] = build("female", "pregnant")
    return results
