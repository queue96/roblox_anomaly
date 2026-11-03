# กระถางธูปศาลพระภูมิ (ปั้นใหม่แยกชิ้น ใช้คู่กับศาล v2 ที่ไม่มีกระถางแล้ว) — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\incense_pot.py -Out C:\tmp\pot.txt
# ผลลัพธ์: assets/models/IncensePot.fbx + IncensePot_Color/_Normal/_Roughness/_Metalness.png, previews/IncensePot.png (+_side)
#   IncensePot  กระถางเซรามิกเคลือบแดงเลือดหมูเก่า คาดแถบทองลอก ปากบาน ขาเตี้ย 3 ขา
#               ในกระถางเป็นทรายขี้เถ้าอย่างเดียว (ไม่มีก้านธูปเก่า: ใช้ธูปแค่ 3 ดอก) — ธูป 3 ดอกที่ติดไฟ/มีควันในเกมเป็นชิ้นเดิม
#               (Workspace.SpiritHouse.Incense1-3 + _Neon) ปักลงทรายตรงกลาง ไม่ได้อยู่ในไฟล์นี้
#   origin = กลางก้นกระถาง (วางบนแท่นได้เลย) · ผิวทรายสูง SAND_Z จากก้น (ปักธูปให้โคนจมลงตรงนี้)
# หน่วยเมตร (1 stud = 0.28 m) ใช้ตัวช่วย B / atlas / export / preview จาก thai_vehicles.py โดยตั้ง S = 1
import bpy, math, os, sys, traceback
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))
S = 1.0

PAL.update({
    "ip_glaze": dict(c=(122, 30, 24), r=0.3, m=0, p="grime"),         # เคลือบแดงเลือดหมู หม่นเขม่า
    "ip_gold": dict(c=(176, 132, 52), r=0.35, m=0.7, p="rust_light"),  # แถบทองลอก
    "ip_clay": dict(c=(96, 70, 52), r=0.8, m=0, p="grime"),           # เนื้อดินไม่เคลือบ (ก้น/ขา/ขอบใน)
    "ip_sand": dict(c=(132, 124, 112), r=0.95, m=0, p="grime"),        # ทรายปนขี้เถ้าธูป
})
KEYS[:] = list(PAL.keys())

R_BODY, H = 0.072, 0.095   # รัศมีป่องสุด, ความสูงถึงปาก
SAND_Z = 0.082
# ธูป 3 ดอก: (x จากกลาง ตามแนวซ้าย-ขวาของหน้าศาล, มุมเอียงออก องศา) ห่างกัน 0.045 ม. = 0.16 studs
STICKS = ((-0.045, -9), (0.0, 0), (0.045, 9))
STICK_R = 0.0035  # รัศมีก้านธูป (ม.) = หนา 0.025 studs (ธูปในเกมเดิม 0.036 studs)


def incense_pot():
    b = B("IncensePot")
    b.bevel = False
    b.sa = 50
    n = 28
    # ขา 3 ขา (เนื้อดิน)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 6
        cx, cy = 0.045 * math.cos(a), 0.045 * math.sin(a)
        b.lathe(cx, cy, [(0.0, 0.0), (0.011, 0.0), (0.013, 0.012), (0.0, 0.012)], 10, "ip_clay")
    # ก้น (ดิน) -> ตัวป่อง (เคลือบแดง) -> แถบทอง -> คอ -> ปากบาน (ทอง)
    b.lathe(0, 0, [(0.0, 0.010), (0.040, 0.010), (0.052, 0.016)], n, "ip_clay")
    b.lathe(0, 0, [(0.052, 0.016), (0.064, 0.026), (R_BODY, 0.042), (0.071, 0.052)], n, "ip_glaze")
    b.lathe(0, 0, [(0.071, 0.052), (0.0705, 0.056), (0.0700, 0.060)], n, "ip_gold")
    b.lathe(0, 0, [(0.0700, 0.060), (0.066, 0.072), (0.064, 0.082), (0.067, 0.089)], n, "ip_glaze")
    b.lathe(0, 0, [(0.067, 0.089), (0.074, 0.093), (0.075, H), (0.071, H + 0.002), (0.066, H - 0.004)], n, "ip_gold")
    # ผนังในถึงผิวทราย (ดิน) + ผิวทรายนูนกลางนิด
    b.lathe(0, 0, [(0.066, H - 0.004), (0.064, SAND_Z)], n, "ip_clay")
    b.lathe(0, 0, [(0.064, SAND_Z), (0.045, SAND_Z + 0.002), (0.02, SAND_Z + 0.004), (0.0, SAND_Z + 0.0045)], n, "ip_sand")
    # กองขี้เถ้าเล็กๆ ตรงโคนธูปแต่ละดอก: บอกตำแหน่งธูป 3 ดอก (ดอกที่ดับแล้วก็ยังเห็นว่าเคยมี 3)
    for dx, _ in STICKS:
        b.lathe(dx, 0, [(0.0, SAND_Z + 0.001), (0.011, SAND_Z + 0.002), (0.006, SAND_Z + 0.007), (0.0, SAND_Z + 0.009)], 12, "ip_sand")
    return b


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "incense_pot_build.log")
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(PREV, exist_ok=True)
    _, objs = realize("IncensePot", [incense_pot()])
    export("IncensePot", objs)
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    size = mx - mn
    log(f"IncensePot tris={sum(eval_tris(o) for o in objs)} size studs (X,Y-up,Z)=({size.x / 0.28:.2f}, {size.z / 0.28:.2f}, {size.y / 0.28:.2f}) "
        f"origin = bottom centre; sand surface at {SAND_Z / 0.28:.2f} studs")
    # ภาพตัวอย่างเท่านั้น (ไม่ export): ธูป 3 ดอกเรียงแถวหน้ากระดานขวางหน้าศาล ห่างกันชัด บานออกนิดๆ
    # ให้นับได้ทันทีว่ามีกี่ดอก (ธูป = จำนวนชีวิตในเกม) — ตำแหน่ง/ขนาดนี้ใช้ตอนปักธูปจริงในเกม (STICKS)
    extra = []
    L = 0.65 * 0.28
    for k, (dx, tilt) in enumerate(STICKS):
        a = math.radians(tilt)
        base = Vector((dx, 0.0, SAND_Z - 0.008))
        top = base + Vector((math.sin(a) * L, 0.0, math.cos(a) * L))
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=STICK_R, depth=L, location=(base + top) / 2)
        st = bpy.context.active_object
        st.rotation_euler = (0, a, 0)
        m = bpy.data.materials.new(f"Stick{k}")
        m.diffuse_color = (0.6, 0.12, 0.1, 1)
        st.data.materials.append(m)
        # ปลายธูป: ช่วงไฟแดงส้มสั้นๆ (โตกว่าก้านนิดเดียว) + ขี้เถ้าเทาค้างปลาย เรียวลง
        d = Vector((math.sin(a), 0.0, math.cos(a)))
        def seg(c0, length, r, color, name):
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r[0], radius2=r[1], depth=length, location=c0 + d * length / 2)
            o = bpy.context.active_object
            o.rotation_euler = (0, a, 0)
            mm = bpy.data.materials.new(name)
            mm.diffuse_color = color
            o.data.materials.append(mm)
            return o
        ember = seg(top, 0.006, (STICK_R * 1.15, STICK_R * 1.1), (1.0, 0.38, 0.08, 1), f"Ember{k}")
        ash = seg(top + d * 0.006, 0.014, (STICK_R * 1.05, STICK_R * 0.55), (0.55, 0.54, 0.52, 1), f"Ash{k}")
        extra += [st, ember, ash]
    preview("IncensePot", objs + extra)
    for o in extra:
        bpy.data.objects.remove(o)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "incense_pot.blend"))
    LOG.append("DONE")
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
    open(OUT + ".done", "w").write("x")
