# Joint rotation limits for HumanRig (male and female share the same bone axes).
# Axis meaning (pose bone local space, XYZ euler), measured on the rig:
#   spine/chest/neck/head : +X bend forward, Y twist, +Z lean to character's right
#   shoulder.L            : +X shrug up,  +Z back           (R: Z mirrored)
#   upper_arm.L           : +X raise arm, -Z swing forward  (R: Z mirrored)
#   forearm.L             : -Z bend elbow (flexion), Y twist (R: Z mirrored)
#   hand                  : +X wrist extension, Z side deviation
#   fingers               : -X curl
#   thigh.L               : +X leg forward, +Z leg out (R: Z mirrored)
#   shin                  : -X bend knee
#   foot / toe            : +X toes up
import bpy, math

RIG = "HumanRig"
# name: (x_min, x_max, y_min, y_max, z_min, z_max) in degrees, for the LEFT side / centre bones
LIMITS = {
    "spine":      (-25, 28, -25, 25, -12, 12),
    "chest":      (-20, 22, -25, 25,  -4,  4),
    "neck":       (-30, 35, -40, 40, -25, 25),
    "head":       (-35, 30, -50, 50, -25, 25),
    "shoulder":   (-10, 25,   0,  0, -15, 15),
    "upper_arm":  (-35, 120, -70, 70, -90, 45),
    "forearm":    (0, 0,    -80, 80, -120, 0),
    "hand":       (-70, 60, -10, 10, -25, 25),
    "thumb_01":   (-50, 30, -20, 20, -40, 40),
    "thumb_02":   (-60, 10,   0,  0, -10, 10),
    "thumb_03":   (-70, 10,   0,  0,   0,  0),
    "finger_01":  (-85, 10,   0,  0, -15, 15),
    "finger_02":  (-100, 0,   0,  0,   0,  0),
    "finger_03":  (-70, 0,    0,  0,   0,  0),
    "thigh":      (-30, 100, -40, 40,   0, 45),
    "shin":       (-95, 0,  -10, 10,   0,  0),
    "foot":       (-45, 25, -15, 15, -20, 20),
    "toe":        (-30, 50,   0,  0,   0,  0),
}
# per-character tweaks: set LIMIT_OVERRIDES = {"spine": (...)} before exec-ing this file
LIMITS.update(globals().get("LIMIT_OVERRIDES", {}))
MIRROR_Z = {"shoulder", "upper_arm", "forearm", "hand", "thigh", "foot",
            "thumb_01", "thumb_02", "thumb_03", "finger_01", "finger_02", "finger_03"}

def key_for(name):
    base, _, side = name.partition(".")
    for f in ("index", "middle", "ring", "pinky"):
        if base.startswith(f + "_"):
            return "finger_" + base.split("_")[1], side
    return base, side

rig = bpy.data.objects[RIG]
n = 0
for pb in rig.pose.bones:
    key, side = key_for(pb.name)
    if key not in LIMITS: continue
    x0, x1, y0, y1, z0, z1 = LIMITS[key]
    if side == "R" and key in MIRROR_Z:
        z0, z1 = -z1, -z0
    for c in [c for c in pb.constraints if c.type == 'LIMIT_ROTATION']:
        pb.constraints.remove(c)
    pb.rotation_mode = 'XYZ'
    c = pb.constraints.new('LIMIT_ROTATION')
    c.name = "JointLimit"
    c.owner_space = 'LOCAL'
    c.use_transform_limit = True       # clamp values in the UI / while posing
    c.use_limit_x = c.use_limit_y = c.use_limit_z = True
    c.min_x, c.max_x = math.radians(x0), math.radians(x1)
    c.min_y, c.max_y = math.radians(y0), math.radians(y1)
    c.min_z, c.max_z = math.radians(z0), math.radians(z1)
    n += 1
print("limited bones", n)
