# ต่อภาพเทียบ: ภาพอ้างอิง (ซ้าย) กับเรนเดอร์จาก thai_vehicles_compare.py (ขวา) → previews/ThaiVehicles_RefCompare.png + <ชื่อ>_RefPair.png
# รัน: python tools/blender/compare_sheet.py <โฟลเดอร์ภาพ ref ที่มี 9.png-16.png>
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREV = os.path.join(ROOT, "assets", "models", "previews")
REF = sys.argv[1]
PAIRS = [("9", "ThaiPickupOld"), ("10", "ThaiSedanSoluna"), ("11", "ThaiBicycleRed"), ("12", "ThaiBicycleBlue"),
         ("13", "ThaiTukTuk"), ("14", "ThaiRacingMoto"), ("15", "ThaiSoundTruck"), ("16", "ThaiParadeTruck")]
H = 420
rows = []
for r, n in PAIRS:
    a = Image.open(os.path.join(REF, r + ".png")).convert("RGB")
    b = Image.open(os.path.join(PREV, n + "_ref.png")).convert("RGB")
    a = a.resize((int(a.width * H / a.height), H))
    b = b.resize((int(b.width * H / b.height), H))
    row = Image.new("RGB", (a.width + b.width + 10, H), (30, 30, 30))
    row.paste(a, (0, 0))
    row.paste(b, (a.width + 10, 0))
    row.save(os.path.join(PREV, n + "_RefPair.png"))
    rows.append(row)
Wd = max(r.width for r in rows)
sheet = Image.new("RGB", (Wd, sum(r.height + 10 for r in rows)), (30, 30, 30))
y = 0
for r in rows:
    sheet.paste(r, (0, y))
    y += r.height + 10
sheet.save(os.path.join(PREV, "ThaiVehicles_RefCompare.png"))
print("ok", sheet.size)
