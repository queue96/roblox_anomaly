# Villager v2: the old 52-bone HumanRig on the new body + skin weights, the same steps the old characters used.
#   blender -b --factory-startup --python build_rig.py -- [male|female] [--save]
#   or exec() with CHAR set (expects bpy.data.objects["Body"] from build_body.py, builds it if missing)
#
# The bones come from the old rig scripts unchanged (human_base/build_rig.py, human_female/build_rig_female.py):
# same names, places and rolls, so clips made for the old characters (and their Roblox animation ids) fit.
# Steps: rig + automatic weights (+ the rig script's own head / shoulder / knee / glute fixes)
#        -> armpit_weights.py -> smooth_junctions.py -> add_joint_limits.py -> at most 4 bones per vertex (Roblox)
import bpy, os, sys

HERE = os.path.dirname(os.path.abspath(globals().get("__file__") or os.path.join(os.getcwd(), "build_rig.py")))
MODELS = os.path.dirname(HERE)
OLD = os.path.join(MODELS, "human_base")
_a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if "CHAR" not in globals():
    CHAR = "female" if "female" in _a else "male"
RIG_SCRIPT = {"male": os.path.join(OLD, "build_rig.py"),
              "female": os.path.join(MODELS, "human_female", "build_rig_female.py")}[CHAR]

def run(path, extra=None):
    ns = {"__name__": "__villager__", "__file__": path, "CHAR": CHAR}
    if extra: ns.update(extra)
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), ns)
    return ns

def limit_weights(ob, n=4):
    names = {g.index: g for g in ob.vertex_groups}; cut = 0
    for v in ob.data.vertices:
        gs = sorted(((g.group, g.weight) for g in v.groups if g.weight > 0), key=lambda t: -t[1])
        if len(gs) <= n and abs(sum(w for _, w in gs) - 1) < 1e-4: continue
        keep = gs[:n]; tot = sum(w for _, w in keep) or 1.0
        for gi, _ in gs[n:]: names[gi].remove([v.index]); cut += 1
        for gi, w in keep: names[gi].add([v.index], w/tot, 'REPLACE')
    return cut

if "Body" not in bpy.data.objects:
    for o in list(bpy.data.objects):           # factory scene: default cube / light / camera must not end up in the file
        bpy.data.objects.remove(o, do_unlink=True)
    run(os.path.join(HERE, "build_body.py"))
run(RIG_SCRIPT)
run(os.path.join(OLD, "armpit_weights.py"), {"ARMPIT_RAD": 0.09, "ARMPIT_ITER": 8})
run(os.path.join(OLD, "smooth_junctions.py"))
run(os.path.join(OLD, "add_joint_limits.py"), {"LIMIT_OVERRIDES": {}})
body = bpy.data.objects["Body"]; rig = bpy.data.objects["HumanRig"]
cut = limit_weights(body)
unweighted = sum(1 for v in body.data.vertices if sum(g.weight for g in v.groups) < 1e-4)
maxinf = max(len([g for g in v.groups if g.weight > 0]) for v in body.data.vertices)
RIG_REPORT = dict(char=CHAR, bones=len(rig.data.bones), unweighted=unweighted, max_influences=maxinf, cut_to_4=cut)
print("villager rig", RIG_REPORT)
if "--save" in _a:
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, f"villager_{CHAR}.blend"))
