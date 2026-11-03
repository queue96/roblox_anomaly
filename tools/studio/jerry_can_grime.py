# ภาพคราบเก่าของแกลลอนน้ำมัน (แปะเป็น Decal บนแกลลอนที่ server/CoreLoop buildCan ประกอบจากชิ้นส่วน)
# รัน: python tools/studio/jerry_can_grime.py  -> assets/models/jerry_can_grime/*.png (พื้นหลังโปร่งใส 512x512)
#   side.png   ข้างตัว: ดินเกาะก้น คราบไหลจางๆ ขอบบนหมอง รอยมือ
#   front.png  หน้า/หลัง: เหมือน side + คราบน้ำมันเก่าไหลจากไหล่ลงมา
#   top.png    บนไหล่: ฝุ่นจับหนา ขอบเข้ม
# อัปโหลดแล้วใส่ ID ใน CAN_GRIME ของ CoreLoop (แก้ภาพ = อัปโหลดทับ ID เดิม)
import os, random
from PIL import Image, ImageChops, ImageDraw, ImageFilter

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "jerry_can_grime")
os.makedirs(OUT, exist_ok=True)


def noise(seed, scales=(8, 24, 64), weights=(0.5, 0.3, 0.2)):
    """ภาพเทาเมฆๆ 0..255 (หลาย octave)"""
    rnd = random.Random(seed)
    acc = None
    for s, w in zip(scales, weights):
        small = Image.new("L", (s, s))
        small.putdata([rnd.randint(0, 255) for _ in range(s * s)])
        big = small.resize((N, N), Image.BICUBIC).point(lambda v, w=w: int(v * w))
        acc = big if acc is None else ImageChops.add(acc, big)
    return acc


def ramp(fn):
    """mask จากฟังก์ชันของ y (0 = บน, 1 = ล่าง) -> 0..255"""
    col = Image.new("L", (1, N))
    col.putdata([max(0, min(255, int(fn(y / (N - 1)) * 255))) for y in range(N)])
    return col.resize((N, N))


def layer(color, alpha):
    img = Image.new("RGBA", (N, N), color + (0,))
    img.putalpha(alpha)
    return img


def mul(a, b):
    return ImageChops.multiply(a, b)


def threshold(img, lo, hi):
    """ยืด contrast: <lo = 0, >hi = 255"""
    return img.point(lambda v: 0 if v <= lo else 255 if v >= hi else int((v - lo) * 255 / (hi - lo)))


def base_grime(seed):
    n1, n2 = noise(seed), noise(seed + 7, (16, 48, 128), (0.5, 0.3, 0.2))
    canvas = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    # ดินเกาะก้น: หนาสุดที่ขอบล่าง ขอบบนของคราบเป็นคลื่นตาม noise
    bottom = mul(ramp(lambda t: max(0.0, (t - 0.62) / 0.38) ** 0.8), threshold(n1, 60, 170))
    bottom = ImageChops.lighter(bottom, ramp(lambda t: max(0.0, (t - 0.84) / 0.16) ** 1.5 * 0.8))
    canvas = Image.alpha_composite(canvas, layer((92, 74, 52), bottom.point(lambda v: int(v * 0.85))))
    # คราบไหลจางๆ แนวตั้ง (น้ำฝน/ฝุ่นละลาย)
    rnd = random.Random(seed)
    streak = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(streak)
    for _ in range(14):
        x = rnd.randint(10, N - 10)
        w = rnd.randint(3, 12)
        y0 = rnd.randint(0, 120)
        y1 = y0 + rnd.randint(80, 320)
        d.rectangle([x, y0, x + w, y1], fill=rnd.randint(30, 70))
    streak = streak.filter(ImageFilter.GaussianBlur(4))
    canvas = Image.alpha_composite(canvas, layer((110, 100, 84), mul(streak, threshold(n2, 40, 200))))
    # ขอบบนหมอง + ฝุ่นทั่วตัวบางๆ
    top = mul(ramp(lambda t: max(0.0, 1 - t / 0.12) * 0.55), n2)
    canvas = Image.alpha_composite(canvas, layer((80, 76, 68), top))
    haze = threshold(n2, 120, 255).point(lambda v: int(v * 0.25))
    canvas = Image.alpha_composite(canvas, layer((120, 112, 96), haze))
    # รอยมือ/รอยถลอกเป็นดวงๆ
    smudge = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(smudge)
    for _ in range(6):
        cx, cy = rnd.randint(40, N - 40), rnd.randint(60, N - 160)
        rx, ry = rnd.randint(14, 34), rnd.randint(10, 26)
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rnd.randint(40, 80))
    smudge = smudge.filter(ImageFilter.GaussianBlur(8))
    canvas = Image.alpha_composite(canvas, layer((70, 62, 50), mul(smudge, threshold(n1, 50, 200))))
    return canvas


def oil_drips(seed):
    rnd = random.Random(seed)
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    # คราบที่ขอบบน (น้ำมันล้นตอนเท) เป็นก้อนไม่เรียบ แล้วไหลลงเป็นทาง เรียวลงแล้วปลายเป็นหยด
    for _ in range(14):
        cx = rnd.randint(90, N - 110)
        d.ellipse([cx - rnd.randint(20, 50), -20, cx + rnd.randint(20, 50), rnd.randint(14, 34)], fill=rnd.randint(80, 130))
    for _ in range(7):
        x = rnd.randint(100, N - 120)
        w = rnd.randint(5, 14)
        L = rnd.randint(70, 280)
        a = rnd.randint(90, 140)
        d.polygon([(x - w / 2, 0), (x + w / 2, 0), (x + w * 0.3, L), (x - w * 0.3, L)], fill=a)
        r = w * 0.45
        d.ellipse([x - r, L - r, x + r, L + r * 1.4], fill=a + 20)
    m = m.filter(ImageFilter.GaussianBlur(3))
    n = noise(seed + 3, (24, 64, 160), (0.4, 0.35, 0.25))
    m = mul(m, threshold(n, 0, 110))
    return layer((126, 84, 44), m)


def top_dust(seed):
    n1, n2 = noise(seed), noise(seed + 5, (16, 48, 128), (0.5, 0.3, 0.2))
    edge = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(edge)
    for i in range(40):  # ขอบเข้มกว่ากลาง
        d.rectangle([i, i, N - 1 - i, N - 1 - i], outline=int(200 - i * 3))
    edge = edge.filter(ImageFilter.GaussianBlur(10))
    dust = ImageChops.lighter(threshold(n1, 70, 210).point(lambda v: int(v * 0.75)), edge)
    canvas = layer((96, 90, 78), dust)
    specks = threshold(n2, 170, 230).point(lambda v: int(v * 0.6))
    return Image.alpha_composite(canvas, layer((58, 50, 40), specks))


side = base_grime(11)
side.save(os.path.join(OUT, "side.png"))
front = Image.alpha_composite(base_grime(23), oil_drips(5))
front.save(os.path.join(OUT, "front.png"))
top_dust(31).save(os.path.join(OUT, "top.png"))
print("saved", os.path.abspath(OUT))
