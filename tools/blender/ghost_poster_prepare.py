# Ghost poster from an AI image (ผู้ใช้ 2026-11-23): ทำขอบขาวรอบกระดาษให้โปร่งใส + ย่อเป็น 768 x 1024 สำหรับอัปโหลด
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/ghost_poster_prepare.py -- <ไฟล์รูป>
#   ตัวเลือก --soften cx cy rx ry (พิกัดรูปต้นฉบับ แถว 0 = บน): เบลอวงรีนั้นให้กลืนเป็นแสงฟุ้ง (ขอบหยักใต้คอที่อาจดูเหมือนคอขาด)
# เขียน assets/models/GhostPoster/upload/GhostPoster.png + previews/GhostPoster_ai_source.(jpg|png) (เก็บต้นฉบับ)
#   กฎ: ห้ามมีเลือด/อวัยวะ/บาดแผลในรูปที่อัปโหลด (CLAUDE.md, GEMINI.md หัวข้อ 0)
import bpy, os, sys, shutil
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
src = args[0]
soften = [float(v) for v in args[args.index("--soften") + 1:args.index("--soften") + 5]] if "--soften" in args else None
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models", "GhostPoster"))
OUT = os.path.join(ROOT, "upload", "GhostPoster.png")
KEEP = os.path.join(ROOT, "previews", "GhostPoster_ai_source" + os.path.splitext(src)[1].lower())
CHECK = os.path.join(ROOT, "previews", "GhostPoster_upload_check.png")
shutil.copyfile(src, KEEP)

img = bpy.data.images.load(src)
w, h = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
rgb = px[:, :, :3]
print("POSTER|source", w, h)


def blur(a, r):
    for _ in range(3):
        for ax in (0, 1):
            pad = [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)]
            c = np.cumsum(np.pad(a, pad, mode="edge"), axis=ax)
            hi = [slice(None)] * a.ndim
            lo = [slice(None)] * a.ndim
            hi[ax] = slice(2 * r + 1, None)
            lo[ax] = slice(None, -(2 * r + 1))
            a = (c[tuple(hi)] - c[tuple(lo)]) / (2 * r + 1)
    return a


if soften:
    cx, cy, rx, ry = soften
    cyb = (h - 1) - cy  # Blender เก็บแถวล่างก่อน
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dd = ((xx - cx) / rx) ** 2 + ((yy - cyb) / ry) ** 2
    m = np.clip((1.0 - dd) / 0.35, 0, 1) ** 1.5
    soft_rgb = blur(rgb.copy(), 14)
    rgb = rgb * (1 - m[..., None]) + soft_rgb * m[..., None]
    print("POSTER|softened", soften)

# พื้นขาวนอกกระดาษ: สว่างมาก + สีจืด และต่อเนื่องจากขอบรูป (ไม่กินจุดขาวบนกระดาษ)
bright = rgb.mean(axis=2)
sat = rgb.max(axis=2) - rgb.min(axis=2)
white = (bright > 0.86) & (sat < 0.12)
region = np.zeros_like(white)
region[0, :] = white[0, :]
region[-1, :] = white[-1, :]
region[:, 0] = white[:, 0]
region[:, -1] = white[:, -1]
for i in range(400):
    grown = region.copy()
    grown[1:, :] |= region[:-1, :]
    grown[:-1, :] |= region[1:, :]
    grown[:, 1:] |= region[:, :-1]
    grown[:, :-1] |= region[:, 1:]
    grown &= white
    if np.array_equal(grown, region):
        print("POSTER|flood iterations", i)
        break
    region = grown
alpha = (~region).astype(np.float32)
# ขอบนุ่ม 1-2 px
soft = alpha.copy()
for sh in ((1, 0), (-1, 0), (0, 1), (0, -1)):
    soft += np.roll(alpha, sh, axis=(0, 1))
alpha = np.minimum(alpha, soft / 5.0 * 1.6)
print("POSTER|transparent px", int(region.sum()), "of", w * h)

out = np.concatenate([rgb, np.clip(alpha, 0, 1)[..., None]], axis=-1).astype(np.float32)
res = bpy.data.images.new("GhostPosterAI", w, h, alpha=True)
res.pixels[:] = out.ravel()
# ย่อเหลือ 768 x 1024 (สัดส่วน 3:4 เท่าป้ายในเกม)
res.scale(768, 1024)
res.filepath_raw = OUT
res.file_format = "PNG"
res.save()
print("POSTER|wrote", OUT)
# ภาพตรวจ: ซ้อนบนพื้นเทาให้เห็นขอบโปร่งใส
chk = np.array(res.pixels[:], dtype=np.float32).reshape(1024, 768, 4)
a = chk[:, :, 3:4]
chk[:, :, :3] = chk[:, :, :3] * a + np.array([0.35, 0.37, 0.4]) * (1 - a)
chk[:, :, 3] = 1
c = bpy.data.images.new("Check", 768, 1024)
c.pixels[:] = chk.ravel()
c.filepath_raw = CHECK
c.file_format = "PNG"
c.save()
print("POSTER|check", CHECK)
