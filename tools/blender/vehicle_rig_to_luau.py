# แปลง assets/models/ThaiVehicles_Rig.json (จาก thai_vehicles.py) เป็น src/shared/ThaiVehicleRigs.luau
# รัน: python tools/blender/vehicle_rig_to_luau.py   (ห้ามแก้ไฟล์ .luau ด้วยมือ ให้แก้ที่ thai_vehicles.py แล้วรันใหม่)
# พิกัดทั้งหมดเป็น studs ในเฟรมของรถ: origin = พื้นใต้กึ่งกลางรถ, หน้ารถ -Z, ขวา +X (เหมือน CustomerBike)
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
J = json.load(open(os.path.join(ROOT, "assets", "models", "ThaiVehicles_Rig.json"), encoding="utf-8"))
IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def num(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def lua(v, ind):
    pad = "\t" * ind
    if isinstance(v, dict):
        if not v:
            return "{}"
        items = []
        for k, x in v.items():
            key = k if IDENT.match(k) else '["%s"]' % k
            items.append("%s\t%s = %s," % (pad, key, lua(x, ind + 1)))
        return "{\n" + "\n".join(items) + "\n" + pad + "}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(lua(x, ind) for x in v) + " }"
        return "{\n" + "\n".join("%s\t%s," % (pad, lua(x, ind + 1)) for x in v) + "\n" + pad + "}"
    if isinstance(v, str):
        return '"%s"' % v.replace('"', '\\"')
    return num(v)


out = [
    "-- สร้างอัตโนมัติจาก tools/blender/vehicle_rig_to_luau.py (ข้อมูลจาก thai_vehicles.py) ห้ามแก้ด้วยมือ",
    "-- studs ในเฟรมรถ: origin = พื้นใต้กึ่งกลางรถ, หน้า -Z, ขวา +X",
    "-- seats {n, t, c, s} | wheels {n, c, r, w, st} | skids {c, r} | lights {t = head/tail, c, s, rd} | cols {c, s, f?}",
    "-- proxy {c, s, k, sh, rx, n} (ชิ้นแทน mesh) | plates/signs (SurfaceGui) | bbox ของแต่ละ object ใน FBX | pal[k] = {r, g, b, metal}",
    "return " + lua(J, 0),
    "",
]
open(os.path.join(ROOT, "src", "shared", "ThaiVehicleRigs.luau"), "w", encoding="utf-8", newline="\n").write("\n".join(out))
print("ok", len(J))
