# Elderly male: shared joint limits, but the head sits far forward (hunched), so the arm
# can't swing as far across the chest before the hand reaches the face.
LIMIT_OVERRIDES = {"upper_arm": (-35, 120, -70, 70, -75, 45)}
exec(open(r"C:\Aunival\pump-lot-anomaly\assets\models\human_base\add_joint_limits.py", encoding="utf-8").read())
