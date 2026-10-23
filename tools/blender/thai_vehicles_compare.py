# ภาพเทียบรถไทยกับภาพอ้างอิง: เรนเดอร์ EEVEE จากมุมเดียวกับภาพ ref (ใช้ thai_vehicles.blend ที่ thai_vehicles.py บันทึกไว้)
# รัน:  blender-launcher.exe --background assets/models/thai_vehicles.blend --python tools/blender/thai_vehicles_compare.py
# ผลลัพธ์: assets/models/previews/<ชื่อ>_ref.png (ต่อภาพคู่กับ ref ด้วย PIL ภายนอก)
import bpy, math, os
from mathutils import Vector

ROOT = r"C:\Aunival\pump-lot-anomaly\assets\models"
PREV = os.path.join(ROOT, "previews")
# ทิศกล้องจากกลางรถ (แกน Blender: หน้ารถ -Y, ซ้ายรถ +X) ให้ตรงกับมุมของภาพอ้างอิง 9-16
VIEWS = {
    "ThaiPickupOld": ((-1.0, -0.12, 0.12), 34),
    "ThaiSedanSoluna": ((-0.75, -0.95, 0.32), 40),
    "ThaiBicycleRed": ((-1.0, -0.05, 0.12), 40),
    "ThaiBicycleBlue": ((-1.0, -0.05, 0.08), 40),
    "ThaiTukTuk": ((0.55, -1.0, 0.28), 38),
    "ThaiRacingMoto": ((-1.0, -0.1, 0.12), 40),
    "ThaiSoundTruck": ((-0.85, -0.7, 0.25), 38),
    "ThaiParadeTruck": ((0.8, -0.75, 0.22), 36),
}


def setup_scene():
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE"
    scn.render.resolution_x = 900
    scn.render.resolution_y = 640
    scn.render.film_transparent = False
    try:
        scn.view_settings.view_transform = "AgX"
    except TypeError:
        pass
    w = bpy.data.worlds.get("CmpWorld") or bpy.data.worlds.new("CmpWorld")
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.55, 0.62, 0.72, 1)
    bg.inputs[1].default_value = 0.9
    scn.world = w
    sun = bpy.data.objects.get("CmpSun")
    if not sun:
        sun = bpy.data.objects.new("CmpSun", bpy.data.lights.new("CmpSun", "SUN"))
        scn.collection.objects.link(sun)
    sun.data.energy = 3.5
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    # พื้นปูนเทาให้มีเงา
    g = bpy.data.objects.get("CmpGround")
    if not g:
        me = bpy.data.meshes.new("CmpGround")
        me.from_pydata([(-60, -60, 0), (60, -60, 0), (60, 60, 0), (-60, 60, 0)], [], [(0, 1, 2, 3)])
        g = bpy.data.objects.new("CmpGround", me)
        scn.collection.objects.link(g)
        mat = bpy.data.materials.new("CmpGroundMat")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.4, 0.37, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
        me.materials.append(mat)
    return scn


def main():
    scn = setup_scene()
    cam = bpy.data.objects.get("CmpCam") or bpy.data.objects.new("CmpCam", bpy.data.cameras.new("CmpCam"))
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    scn.camera = cam
    for prop, (d, lens) in VIEWS.items():
        coll = bpy.data.collections.get(prop)
        if not coll:
            continue
        objs = [o for o in coll.objects if o.type == "MESH"]
        for o in bpy.data.objects:
            if o.type == "MESH" and o.name != "CmpGround":
                o.hide_render = o not in objs
        mn = Vector((1e9, 1e9, 1e9))
        mx = -mn
        for o in objs:
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                mn = Vector(map(min, mn, w))
                mx = Vector(map(max, mx, w))
        c = (mn + mx) / 2
        size = (mx - mn).length
        cam.data.lens = lens
        cam.location = c + Vector(d).normalized() * size * 1.25
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(PREV, prop + "_ref.png")
        bpy.ops.render.render(write_still=True)


main()
