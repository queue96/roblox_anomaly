# Check the current pose, or every frame of HumanRig's active action, for body parts
# passing through each other (e.g. both forearms crossing, hands into thighs).
# Usage: run in Blender's Scripting tab with the character file open.
import bpy
exec(open(r"C:\Aunival\pump-lot-anomaly\assets\models\human_base\test_self_intersection.py", encoding="utf-8").read().split("POSES = {")[0])

scene = bpy.context.scene
act = rig.animation_data.action if rig.animation_data else None
if act is None:
    check("current pose")
else:
    f0, f1 = (int(x) for x in act.frame_range)
    keep = scene.frame_current
    bad = []
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        import io, contextlib
        with contextlib.redirect_stdout(io.StringIO()):
            h = check(f"frame {f}")
        if h: bad.append((f, h))
    scene.frame_set(keep)
    print(f"action '{act.name}' frames {f0}-{f1}: {len(bad)} frame(s) with intersections")
    for f, h in bad: print(f"  frame {f}: {' '.join(h)}")
