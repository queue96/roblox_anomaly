# Ghost poster, cartoon Krasue (ผู้ใช้ 2026-11-23: ป้ายผีแบบการ์ตูนโทนส้ม ไม่ต้องน่ากลัวสมจริง)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/ghost_poster_cartoon.py
# ต้นฉบับวาด: assets/models/GhostPoster/krasue_cartoon.svg (แก้รูปที่ไฟล์นี้)
#   1) เส้น (stroke) -> ลูกปัดวงกลมต่อกัน (ตัวนำเข้า SVG ของ Blender ไม่เอาเส้น) เขียนเป็น _flat.svg
#   2) นำเข้า SVG -> เรนเดอร์ Workbench สีเรียบตามไฟล์ (มองตรงจากบน กล้อง orthographic)
#   3) ทำให้เป็นกระดาษเก่าเบาๆ: ลายกระดาษ คราบ เม็ดฟิล์ม ขอบมืด ขอบกระดาษขาด
# เขียน assets/models/GhostPoster/upload/GhostPoster.png + previews/GhostPoster_cartoon.png
import bpy, os, re, math, addon_utils
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "GhostPoster"))
SVG = os.path.join(ROOT, "krasue_cartoon.svg")
FLAT = os.path.join(ROOT, "previews", "krasue_cartoon_flat.svg")
RAW = os.path.join(ROOT, "previews", "GhostPoster_cartoon_raw.png")
OUT = os.path.join(ROOT, "upload", "GhostPoster.png")
PREVIEW = os.path.join(ROOT, "previews", "GhostPoster_cartoon.png")
W, H = 768, 1024
rng = np.random.default_rng(11)


# ---------------------------------------------------------------- 1) stroke -> beads
def bez_points(d):
    nums = [float(x) for x in re.findall(r"-?\d+\.?\d*", d)]
    pts = []
    x0, y0 = nums[0], nums[1]
    i = 2
    while i + 5 < len(nums):
        x1, y1, x2, y2, x3, y3 = nums[i:i + 6]
        for k in range(24):
            t = k / 24
            u = 1 - t
            pts.append((u ** 3 * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t ** 3 * x3,
                        u ** 3 * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t ** 3 * y3))
        x0, y0 = x3, y3
        i += 6
    pts.append((x0, y0))
    return pts


def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, by - ay)
        acc += seg
        while acc >= step:
            acc -= step
            f = 1 - acc / seg if seg > 0 else 0
            out.append((ax + (bx - ax) * f, ay + (by - ay) * f))
    return out


src = open(SVG, encoding="utf-8").read()
stroke_re = re.compile(r'<path d="([^"]+)" fill="none" stroke="(#[0-9a-fA-F]{6})" stroke-width="(\d+)"/>')
strokes = stroke_re.findall(src)
flat = stroke_re.sub("", src)
beads = []
for d, col, wid in strokes:
    r = float(wid) / 2
    for x, y in resample(bez_points(d), max(4.0, r * 0.6)):
        beads.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{col}"/>')
# ลูกปัดใส่ก่อนหัวใจ (ตำแหน่งเดิมของเส้น)
marker = '<circle cx="384" cy="700" r="62"'
flat = flat.replace(marker, "\n".join(beads) + "\n  " + marker, 1)
os.makedirs(os.path.dirname(FLAT), exist_ok=True)
open(FLAT, "w", encoding="utf-8").write(flat)
print("POSTER|beads", len(beads))

# ---------------------------------------------------------------- 2) import + render
bpy.ops.wm.read_factory_settings(use_empty=True)
for mod in ("io_curve_svg",):
    try:
        addon_utils.enable(mod, default_set=True)
    except Exception as e:
        print("POSTER|addon", mod, e)
before = set(bpy.data.objects)
bpy.ops.import_curve.svg(filepath=FLAT)
objs = [o for o in bpy.data.objects if o not in before]


def order_key(o):
    m = re.search(r"\.(\d+)$", o.name)
    return int(m.group(1)) if m else 0


objs.sort(key=order_key)
mins = [math.inf, math.inf]
maxs = [-math.inf, -math.inf]
for i, o in enumerate(objs):
    o.location.z += i * 1e-4
    for c in o.bound_box:
        v = o.matrix_world @ __import__("mathutils").Vector(c)
        mins[0], mins[1] = min(mins[0], v.x), min(mins[1], v.y)
        maxs[0], maxs[1] = max(maxs[0], v.x), max(maxs[1], v.y)
print("POSTER|objects", len(objs), "bounds", mins, maxs)

scn = bpy.context.scene
scn.render.engine = "BLENDER_WORKBENCH"
scn.display.shading.light = "FLAT"
scn.display.shading.color_type = "MATERIAL"
scn.render.resolution_x, scn.render.resolution_y = W, H
scn.render.film_transparent = False
scn.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scn.collection.objects.link(cam)
cam.data.type = "ORTHO"
cw, ch = maxs[0] - mins[0], maxs[1] - mins[1]
cam.data.ortho_scale = max(cw, ch)
cam.location = ((mins[0] + maxs[0]) / 2, (mins[1] + maxs[1]) / 2, 10)
cam.rotation_euler = (0, 0, 0)
scn.camera = cam
scn.render.filepath = RAW
bpy.ops.render.render(write_still=True)
print("POSTER|raw", RAW)

# ---------------------------------------------------------------- 3) light aging
img = bpy.data.images.load(RAW)
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
rgb = px[:, :, :3]


def blur(a, r):
    for _ in range(2):
        for ax in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode="edge"), axis=ax)
            hi = [slice(None)] * a.ndim
            lo = [slice(None)] * a.ndim
            hi[ax] = slice(2 * r + 1, None)
            lo[ax] = slice(None, -(2 * r + 1))
            a = (c[tuple(hi)] - c[tuple(lo)]) / (2 * r + 1)
    return a


def fbm(shape, scales, weights):
    out = np.zeros(shape, dtype=np.float32)
    for s, w in zip(scales, weights):
        out += blur(rng.random(shape).astype(np.float32), s) * w
    out -= out.min()
    return out / max(out.max(), 1e-6)


paper = fbm((H, W), (40, 10, 2), (0.5, 0.3, 0.2))
stain = np.clip((fbm((H, W), (90, 30), (0.7, 0.3)) - 0.58) * 3.0, 0, 1)
grain = rng.normal(0, 0.03, (H, W)).astype(np.float32)
tone = rgb * (0.88 + 0.18 * paper)[..., None]
tone *= (1.0 - 0.28 * stain)[..., None]
tone += grain[..., None]
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
d = np.sqrt(((xx / W - 0.5) * 2) ** 2 * 1.1 + ((yy / H - 0.5) * 2) ** 2 * 0.85)
burn = np.clip((d - 0.75) / 0.5, 0, 1) ** 1.5
tone *= (1.0 - 0.6 * burn)[..., None]
edge = np.minimum.reduce([xx, W - 1 - xx, yy, H - 1 - yy]).astype(np.float32)
rough = fbm((H, W), (8, 2), (0.7, 0.3))
alpha = np.clip((edge - 5 - rough * 18) / 3.0, 0, 1)
alpha *= np.clip((((W - 1 - xx) + yy) - 60 - rough * 36) / 4.0, 0, 1)  # มุมขวาบนฉีก (แถว 0 = ล่าง)
out = np.concatenate([np.clip(tone, 0, 1), alpha[..., None]], axis=-1).astype(np.float32)
res = bpy.data.images.new("GhostPosterCartoon", W, H, alpha=True)
res.pixels[:] = out.ravel()
for path in (OUT, PREVIEW):
    res.filepath_raw = path
    res.file_format = "PNG"
    res.save()
    print("POSTER|wrote", path)
