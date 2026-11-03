# แกลลอนน้ำมันพลาสติกขาวขุ่นเก่า (ทรงเดียวกับในเกม server/JerryCan.luau) — Blender headless
# รัน (PowerShell):
#   powershell -ExecutionPolicy Bypass -File tools\blender\run_headless.ps1 -Script tools\blender\jerry_can.py -Out C:\tmp\jc.txt
# ผลลัพธ์: assets/models/JerryCan.fbx + JerryCan_Color.png, previews/JerryCan.png (+_side, _full)
#   JerryCan      ตัวถังมุมมน + ไหล่ลาดหน้า-หลังลงจรดขอบ + หูหิ้วห่วงกลม + ฝาเกลียว ชิ้นเดียว มีคราบเก่าวาดลงผิว
#                 (ภาพคราบชุดเดียวกับในเกม assets/models/jerry_can_grime/*.png วางแบบเดียวกัน: ชิดก้น)
#   JerryCanFuel  เปลือกบางครอบตัวถังใต้ระดับน้ำมัน (~2/3) ในเกมตั้งชมพูแดงโปร่งแสง 0.45 ตอนมีน้ำมัน / ซ่อนตอนเปล่า
#   origin ทั้งสองชิ้น = กลางคานหูหิ้ว (จุดที่มือกำ) แกลลอนห้อยลงจากจุดนี้ · หน้า (ฝา) = -Y
# ขนาดเท่าในเกม (studs x 0.28 = เมตร): กว้าง 0.6 สูงตัวถัง 0.85 ไหล่ 0.2 ยาวหน้า-หลัง 0.9
import bpy, bmesh, math, os, sys, traceback
import numpy as np
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "thai_vehicles.py"), encoding="utf-8").read()
exec(compile(src[:src.index("\ntry:\n    main()")], "thai_vehicles.py", "exec"))

K = 0.28  # เมตรต่อ stud
W, H, D = 0.6 * K, 0.85 * K, 0.9 * K
SH, R = 0.2 * K, 0.12 * K
SZ0 = 0.13 * K            # ไหล่เรียบ |y| < SZ0 แล้วลาดลงถึงขอบหน้า-หลัง
FUEL = 0.66               # ระดับน้ำมัน (สัดส่วนความสูงตัวถัง)
GRIP = Vector((0, 0.15 * K, H / 2 + 0.79 * K))  # กลางคานหูหิ้ว (ตัวถังเริ่มที่ z = 0)
GR = 0.035 * K            # รัศมีเนื้อหูหิ้ว
GS = 0.11 * K             # ครึ่งช่วงเสาหูหิ้ว
CAP_Y = -0.08 * K
BASE = np.array([226, 220, 198]) / 255.0
GRIME = os.path.join(ROOT, "jerry_can_grime")
SIDE_V, FRONT_V = 1.3 * K, 1.2 * K  # ความสูงภาพคราบ 1 แผ่น (เท่าในเกม)
CS = 6  # จำนวนช่วงต่อมุมโค้ง


def rrect(z, w, d, r):
    """วงสี่เหลี่ยมมุมมนที่ความสูง z จำนวนจุดคงที่ 4*(CS+1)"""
    r = max(min(r, w / 2 - 1e-5, d / 2 - 1e-5), 1e-5)
    pts = []
    for cx, cy, a0 in ((w / 2 - r, -d / 2 + r, -90), (w / 2 - r, d / 2 - r, 0), (-w / 2 + r, d / 2 - r, 90), (-w / 2 + r, -d / 2 + r, 180)):
        for i in range(CS + 1):
            a = math.radians(a0 + 90 * i / CS)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a), z))
    return pts


def loft(bm, rings, cap_bottom=True, cap_top=True):
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vs, vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(vs[0])))
    if cap_top:
        bm.faces.new(vs[-1])


def body_rings(grow=0.0, z0=0.0, z1=None, with_shoulder=True):
    g = grow
    w, d, r = W + 2 * g, D + 2 * g, R + g
    c = 0.006  # มนขอบก้น
    rings = [rrect(z0, w - 2 * c, d - 2 * c, r - c), rrect(z0 + c, w - 0.6 * c, d - 0.6 * c, r), rrect(z0 + c * 2.5, w, d, r)]
    if z1 is None:
        for t in (0.25, 0.5, 0.75, 1.0):
            rings.append(rrect(H * t, w, d, r))
    else:
        rings.append(rrect(z1, w, d, r))
    if with_shoulder:
        # ไหล่: ยาวหน้า-หลังหดจาก D ลงเหลือ 2*SZ0 (ลาดตรง) มุมยังมนแล้วค่อยๆ เล็กลง ด้านข้างตรง
        steps = 6
        for i in range(1, steps + 1):
            t = i / steps
            dd = d - (d - 2 * SZ0) * t
            rr = r * (1 - 0.55 * t)
            ww = w - 0.004 * t * t
            rings.append(rrect(H + SH * t, ww, dd, rr))
        rings.append(rrect(H + SH + 0.0025, w - 0.01, 2 * SZ0 - 0.01, R * 0.35))
    return rings


def handle_path():
    """หูหิ้วห่วงกลม: เสาหน้าขึ้น -> โค้ง -> คาน -> โค้ง -> เสาหลังลง (ระนาบ YZ ที่ x = 0)"""
    y0, y1 = GRIP.y - GS, GRIP.y + GS
    zb, zt = H + 0.06 * K, GRIP.z
    rc = 0.05 * K
    pts = []
    for i in range(5):
        pts.append(Vector((0, y0, zb + (zt - rc - zb) * i / 4)))
    for i in range(1, 7):
        a = math.radians(180 - 90 * i / 6)
        pts.append(Vector((0, y0 + rc + rc * math.cos(a), zt - rc + rc * math.sin(a))))
    for i in range(1, 4):
        pts.append(Vector((0, y0 + rc + (y1 - y0 - 2 * rc) * i / 4, zt)))
    for i in range(0, 7):
        a = math.radians(90 - 90 * i / 6)
        pts.append(Vector((0, y1 - rc + rc * math.cos(a), zt - rc + rc * math.sin(a))))
    for i in range(1, 5):
        pts.append(Vector((0, y1, zt - rc - (zt - rc - zb) * i / 4)))
    return pts


def sweep(bm, pts, radius, n=12):
    rings = []
    for k, p in enumerate(pts):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        a = Vector((1, 0, 0))
        b = t.cross(a).normalized()
        rings.append([p + (a * math.cos(2 * math.pi * i / n) + b * math.sin(2 * math.pi * i / n)) * radius for i in range(n)])
    loft(bm, rings)


def lathe_z(bm, cx, cy, prof, n=20):
    rings = [[(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n), z) for i in range(n)] for r, z in prof]
    loft(bm, rings)


# ---------------------------------------------------------------- texture (atlas 1024)
N = 1024
REG = {
    "px": (0, 0, 512, 512), "nx": (512, 0, 512, 512),
    "ny": (0, 512, 256, 512), "py": (256, 512, 256, 512),
    "top": (512, 512, 256, 512), "plain": (768, 512, 256, 256), "grimy": (768, 768, 256, 256),
}
ZMAX = H + SH + 0.003
# ขอบเขตโลกของแต่ละช่อง (a0, a1, b0, b1): a = แนวนอนของภาพ, b = แนวตั้ง (ล่าง->บน)
WORLD = {
    "px": (-D / 2, D / 2, 0, ZMAX), "nx": (-D / 2, D / 2, 0, ZMAX),
    "ny": (-W / 2, W / 2, 0, ZMAX), "py": (-W / 2, W / 2, 0, ZMAX),
    "top": (-W / 2, W / 2, -D / 2, D / 2),
}


def load_png(path):
    img = bpy.data.images.load(path, check_existing=True)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return np.flipud(a)  # แถวแรก = บนสุดของภาพ


def sample(img, u, v):
    h, w = img.shape[:2]
    x = (np.mod(u, 1.0) * (w - 1)).astype(int)
    y = (np.clip(v, 0.0, 1.0) * (h - 1)).astype(int)
    return img[y, x]


def paint_atlas():
    col = np.zeros((N, N, 3))
    side, front, top = (load_png(os.path.join(GRIME, f + ".png")) for f in ("side", "front", "top"))
    for key, (x0, y0, w, h) in REG.items():
        yy, xx = np.mgrid[0:h, 0:w]
        s = (xx + 0.5) / w
        t = 1 - (yy + 0.5) / h
        base = np.ones((h, w, 3)) * BASE
        if key in ("px", "nx", "ny", "py"):
            a0, a1, b0, b1 = WORLD[key]
            z = b0 + t * (b1 - b0)
            img, tile = (front, FRONT_V) if key == "ny" else (side, SIDE_V)
            px = sample(img, s, (tile - z) / tile)  # ชิดขอบล่างภาพกับก้น
            a = px[..., 3:4]
            base = base * (1 - a) + px[..., :3] * a
        elif key == "top":
            px = sample(top, s, 1 - t)
            a = px[..., 3:4] * 0.55
            base = base * (1 - a) + px[..., :3] * a
        elif key == "grimy":  # หูหิ้ว/ฝา: มือจับจนหมอง
            base = base * 0.86 + np.array([96, 78, 56]) / 255.0 * 0.14
        col[y0:y0 + h, x0:x0 + w] = base
    rgba = np.concatenate([np.clip(col, 0, 1), np.ones((N, N, 1))], -1)
    rgba = np.flipud(rgba)
    name = "JerryCan_Color"
    img = bpy.data.images.get(name) or bpy.data.images.new(name, N, N, alpha=False)
    img.pixels.foreach_set(rgba.astype(np.float32).ravel())
    path = os.path.join(ROOT, name + ".png")
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    return img


def uv_region(n, hint):
    if hint:
        return hint
    if n.z > 0.45:
        return "top"
    ax = max(range(3), key=lambda i: abs(n[i]))
    if ax == 0:
        return "px" if n.x > 0 else "nx"
    if ax == 1:
        return "ny" if n.y < 0 else "py"
    return "px"  # ก้น


def assign_uv(bm, hint=None):
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        key = uv_region(f.normal, hint)
        x0, y0, w, h = REG[key]
        for l in f.loops:
            p = l.vert.co
            if key in WORLD:
                a0, a1, b0, b1 = WORLD[key]
                if key == "px":
                    a, b = -p.y, p.z  # มองจาก +X: ซ้าย = +Y (หลัง)
                elif key == "nx":
                    a, b = p.y, p.z
                elif key == "ny":
                    a, b = p.x, p.z
                elif key == "py":
                    a, b = -p.x, p.z
                else:
                    a, b = p.x, p.y
                s = min(max((a - a0) / (a1 - a0), 0), 1)
                t = min(max((b - b0) / (b1 - b0), 0), 1)
            else:
                s = t = 0.5
            l[uvl].uv = ((x0 + 2 + s * (w - 4)) / N, (N - y0 - h + 2 + t * (h - 4)) / N)


def make_mat(name, img=None, color=(1, 1, 1, 1), alpha=1.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Alpha"].default_value = alpha
    if img:
        tc = nt.nodes.new("ShaderNodeTexImage")
        tc.image = img
        nt.links.new(tc.outputs[0], bsdf.inputs["Base Color"])
        nt.nodes.active = tc
    if alpha < 1:
        for attr, val in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
            try:
                setattr(mat, attr, val)
            except Exception:
                pass
    mat.diffuse_color = (color[0], color[1], color[2], alpha)
    return mat


def mesh_obj(name, bm, mat, smooth_angle=40):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.translate(bm, vec=-GRIP, verts=bm.verts)  # origin = กลางคานหูหิ้ว
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    return ob


def build():
    img = paint_atlas()
    mat = make_mat("JerryCan_Mat", img)
    # ตัวถัง + ไหล่ + ขีดปริมาตร (UV ตามทิศผิว)
    bm = bmesh.new()
    loft(bm, body_rings())
    for i in range(4):  # ขีดบอกปริมาตรนูนด้านข้าง (+X)
        z = H / 2 - 0.25 * K + i * 0.16 * K
        r = bmesh.ops.create_cube(bm, size=1.0)
        for v in r["verts"]:
            v.co = Vector((W / 2 + v.co.x * 0.006, -0.2 * K + v.co.y * 0.12 * K, z + v.co.z * 0.015 * K))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    assign_uv(bm)
    # หูหิ้ว + คอ + ฝาเกลียว (สีหมองมือจับ)
    bm2 = bmesh.new()
    sweep(bm2, handle_path(), GR)
    lathe_z(bm2, 0, CAP_Y, [(0.0, H + SH - 0.004), (0.055 * K, H + SH - 0.004), (0.055 * K, H + SH + 0.05 * K), (0.0, H + SH + 0.05 * K)], 16)
    cap = [(0.0, H + SH + 0.04 * K)]
    for i in range(9):  # ฝามีร่องเกลียว
        z = H + SH + 0.04 * K + 0.11 * K * i / 8
        cap.append((0.075 * K if i % 2 == 0 else 0.07 * K, z))
    cap += [(0.07 * K, H + SH + 0.16 * K), (0.0, H + SH + 0.16 * K)]
    lathe_z(bm2, 0, CAP_Y, cap, 20)
    bmesh.ops.recalc_face_normals(bm2, faces=bm2.faces)
    bm2.normal_update()
    assign_uv(bm2, "grimy")
    me2 = bpy.data.meshes.new("tmp")
    bm2.to_mesh(me2)
    bm2.free()
    bm.from_mesh(me2)
    bpy.data.meshes.remove(me2)
    can = mesh_obj("JerryCan", bm, mat)
    # เปลือกน้ำมัน (ใต้ระดับน้ำมัน โตกว่าตัวถังนิด)
    fm = make_mat("JerryCanFuel_Mat", None, (228 / 255, 112 / 255, 98 / 255, 1), 0.55)
    bmf = bmesh.new()
    loft(bmf, body_rings(grow=0.0017, z0=-0.001, z1=H * FUEL, with_shoulder=False))
    fuel = mesh_obj("JerryCanFuel", bmf, fm)
    return [can, fuel]


def previews(objs):
    scn = bpy.context.scene
    can, fuel = objs
    eng_ok = False
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scn.render.engine = eng
            eng_ok = True
            break
        except Exception:
            pass
    if eng_ok:
        world = bpy.data.worlds.get("PrevWorld") or bpy.data.worlds.new("PrevWorld")
        world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (0.32, 0.33, 0.35, 1)
        bg.inputs[1].default_value = 0.9
        scn.world = world
        sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", "SUN"))
        scn.collection.objects.link(sun)
        sun.data.energy = 3.0
        sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    else:
        render_setup()
    scn.render.resolution_x = scn.render.resolution_y = 900
    shots = [("JerryCan", (-0.75, -1.25, 0.55), False), ("JerryCan_side", (1.0, 0.15, 0.25), False), ("JerryCan_full", (-0.9, -1.1, 0.45), True)]
    for name, d, full in shots:
        fuel.hide_render = not full
        frame_cam([can], d, dist=1.15)
        scn.render.filepath = os.path.join(PREV, name + ".png")
        bpy.ops.render.render(write_still=True)
    fuel.hide_render = False
    log(f"preview engine: {scn.render.engine}")


OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(ROOT, "jerry_can_build.log")
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(PREV, exist_ok=True)
    objs = build()
    export("JerryCan", objs)
    for o in objs:
        log(f"  {o.name}: {eval_tris(o)} tris")
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for c in objs[0].bound_box:
        w = objs[0].matrix_world @ Vector(c)
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    size = mx - mn
    log(f"JerryCan size studs (X,Y-up,Z)=({size.x / K:.2f}, {size.z / K:.2f}, {size.y / K:.2f}) origin = handle grip; bottom at {mn.z / K:.2f} studs")
    previews(objs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "jerry_can.blend"))
    LOG.append("DONE")
except Exception:
    LOG.append("ERROR\n" + traceback.format_exc())
finally:
    open(OUT, "w", encoding="utf-8").write("\n".join(LOG))
    open(OUT + ".done", "w").write("x")
