# Ghost poster, aged-paper look (ผู้ใช้ 2026-11-23: ป้ายผีให้น่ากลัวแบบกระดาษเก่าโทนส้มแดง)
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/ghost_poster_aged.py
# อ่าน assets/models/GhostPoster/previews/GhostPoster_krasue.png (เรนเดอร์จาก ghost_poster.py)
# เขียน assets/models/GhostPoster/upload/GhostPoster.png (มีขอบโปร่งใส ขอบกระดาษขาดๆ) + previews/GhostPoster_aged.png
#   ภาพขาวดำ -> ไล่สีสองโทน (น้ำตาลไหม้ -> ส้ม -> เหลืองซีด) · ลายกระดาษ + เม็ดฟิล์ม + คราบ · ขอบมืดไหม้ · ขอบกระดาษขาดไม่เรียบ
import bpy, os
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "GhostPoster"))
SRC = os.path.join(ROOT, "previews", "GhostPoster_krasue.png")
OUT = os.path.join(ROOT, "upload", "GhostPoster.png")
PREVIEW = os.path.join(ROOT, "previews", "GhostPoster_aged.png")
rng = np.random.default_rng(7)

img = bpy.data.images.load(SRC)
W, H = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)  # แถวล่างก่อน (Blender)
rgb = px[:, :, :3]


def blur(a, r):
    """box blur แยกแกน (ทำซ้ำ 2 รอบ ~ gaussian) ด้วย cumulative sum"""
    for _ in range(2):
        for ax in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode="edge"), axis=ax)
            sl_hi = [slice(None)] * a.ndim
            sl_lo = [slice(None)] * a.ndim
            sl_hi[ax] = slice(2 * r + 1, None)
            sl_lo[ax] = slice(None, -(2 * r + 1))
            a = (c[tuple(sl_hi)] - c[tuple(sl_lo)]) / (2 * r + 1)
    return a


def fbm(shape, scales, weights):
    out = np.zeros(shape, dtype=np.float32)
    for s, w in zip(scales, weights):
        n = rng.random(shape).astype(np.float32)
        out += blur(n, s) * w
    out -= out.min()
    return out / max(out.max(), 1e-6)


# 1) ขาวดำ + คอนทราสต์ (เน้นหน้า เงามืดสนิท)
lum = rgb[:, :, 0] * 0.3 + rgb[:, :, 1] * 0.59 + rgb[:, :, 2] * 0.11
lum = np.clip((lum - 0.03) / 0.55, 0, 1) ** 0.8

# 2) ไล่สีสองโทน: มืด = น้ำตาลไหม้ · กลาง = ส้มแดง · สว่าง = เหลืองซีด
stops = np.array([0.0, 0.35, 0.7, 1.0])
cols = np.array([[0.05, 0.02, 0.012], [0.42, 0.11, 0.035], [0.86, 0.40, 0.12], [1.0, 0.86, 0.6]])
tone = np.stack([np.interp(lum, stops, cols[:, i]) for i in range(3)], axis=-1)

# 3) พิมพ์ลงกระดาษเก่า: ส่วนมืดของภาพ = เนื้อกระดาษน้ำตาล (ไม่ดำสนิท) ส่วนสว่าง = หมึกส้มเรือง
paper = fbm((H, W), (40, 12, 3), (0.5, 0.3, 0.2))
stains = fbm((H, W), (90, 30), (0.7, 0.3))
stain = np.clip((stains - 0.55) * 3.0, 0, 1)
grain = rng.normal(0, 0.045, (H, W)).astype(np.float32)
paper_col = np.array([0.36, 0.22, 0.12], dtype=np.float32) * (0.75 + 0.45 * paper)[..., None]
paper_col *= (1.0 - 0.4 * stain)[..., None]
ink = np.clip(lum * 1.15, 0, 1)[..., None]
tone = paper_col * (1.0 - 0.55 * ink) + tone * ink * 1.05
tone += grain[..., None] * 0.5

# 4) ขอบมืดไหม้ (vignette) + แสงส่องจากด้านหลังกลางภาพนิดๆ
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
nx = (xx / W - 0.5) * 2
ny = (yy / H - 0.52) * 2
d = np.sqrt(nx ** 2 * 1.1 + ny ** 2 * 0.85)
burn = np.clip((d - 0.55) / 0.55, 0, 1) ** 1.6
burn = np.clip(burn + (fbm((H, W), (25, 6), (0.7, 0.3)) - 0.5) * 0.35 * (d > 0.5), 0, 1)
tone *= (1.0 - 0.7 * burn)[..., None]
tone *= (1.0 + 0.18 * np.clip(1 - d, 0, 1))[..., None]

# 5) ขอบกระดาษขาดไม่เรียบ (alpha) + มุมขวาบนฉีกหาย
edge = np.minimum.reduce([xx, W - 1 - xx, yy, H - 1 - yy]).astype(np.float32)
rough = fbm((H, W), (8, 2), (0.7, 0.3))
alpha = np.clip((edge - 6 - rough * 22) / 3.0, 0, 1)
corner = (W - 1 - xx) + (yy) * 0.9  # มุมขวาล่างในแถวของ Blender = ขวาบนของภาพ? (แถว 0 = ล่าง)
tear = np.clip((((W - 1 - xx) + (H - 1 - yy)) - 70 - rough * 40) / 4.0, 0, 1)
alpha *= tear
tone = np.clip(tone, 0, 1)

out = np.concatenate([tone, alpha[..., None]], axis=-1).astype(np.float32)
res = bpy.data.images.new("GhostPosterAged", W, H, alpha=True)
res.pixels[:] = out.ravel()
for path in (OUT, PREVIEW):
    res.filepath_raw = path
    res.file_format = "PNG"
    res.save()
    print("POSTER|wrote", path)
