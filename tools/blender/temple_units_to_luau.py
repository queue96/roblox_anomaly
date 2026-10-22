# แปลง assets/models/ThaiTemple_Colliders.json เป็นตาราง Luau (แกน Roblox: X = x, Y = z, Z = -y ของ Blender)
import json, sys
J = json.load(open("assets/models/ThaiTemple_Colliders.json", encoding="utf-8"))
BB = J["_bbox"]
UNITS = [
    ("TempleGate", "TempleGate", ["TempleGate", "TempleGate_Buddha"]),
    ("TempleNameSign", "TempleGate", ["TempleNameSign", "TempleNameSign_Plaque"]),
    ("FenceSegment", "TempleFence", ["FenceSegment"]),
    ("FenceSegment_Half", "TempleFence", ["FenceSegment_Half"]),
    ("FencePost", "TempleFence", ["FencePost"]),
    ("BoneStupa_A", "BoneStupa", ["BoneStupa_A"]),
    ("BoneStupa_B", "BoneStupa", ["BoneStupa_B"]),
    ("BoneStupa_C", "BoneStupa", ["BoneStupa_C"]),
    ("Meru", "Meru", ["Meru_Base", "Meru_Hall", "Meru_Roof", "Meru_Chimney"]),
    ("Ubosot", "Ubosot", ["Ubosot_Base", "Ubosot_Walls", "Ubosot_Columns", "Ubosot_Roof", "Ubosot_KaewWall"]),
    ("Kuti", "Kuti", ["Kuti_Stilts", "Kuti_House", "Kuti_Roof"]),
    ("Sala", "Sala", ["Sala_Base", "Sala_Columns", "Sala_Roof"]),
    ("BuddhaTrio", "BuddhaTrio", ["BuddhaTrio_Base", "BuddhaTrio_Plaques", "Buddha_Center", "Buddha_Left", "Buddha_Right"]),
    ("DonationBoard", "DonationBoard", ["DonationBoard", "DonationBoard_Board", "DonationBoard_Face"]),
    ("DonationBox", "DonationBox", ["DonationBox_Stand", "DonationBox", "DonationBox_Door", "DonationBox_Glass"]),
    ("ShopCart", "ShopCart", ["ShopCart", "ShopCart_Goods", "ShopCart_Canopy", "ShopCart_Sign"]),
]
f = lambda v: ("%.2f" % v).rstrip("0").rstrip(".") if abs(v) > 1e-9 else "0"
def rmin(mn, mx): return (mn[0], mn[2], -mx[1])
def rmax(mn, mx): return (mx[0], mx[2], -mn[1])
out = ["local TEMPLE_UNITS = {"]
for name, file, parts in UNITS:
    mn = [min(BB[p][0][i] for p in parts) for i in range(3)]
    mx = [max(BB[p][1][i] for p in parts) for i in range(3)]
    a, b = rmin(mn, mx), rmax(mn, mx)
    cols = []
    for c in J.get(name, []):
        ca, cb = rmin(c["mn"], c["mx"]), rmax(c["mn"], c["mx"])
        cen = [(ca[i] + cb[i]) / 2 for i in range(3)]
        sz = [cb[i] - ca[i] for i in range(3)]
        cols.append("{ %s, %s, %s, %s, %s, %s }" % tuple(f(x) for x in cen + sz))
    out.append("\t%s = {" % name)
    out.append('\t\tfile = "%s",' % file)
    out.append("\t\tparts = { %s }," % ", ".join('"%s"' % p for p in parts))
    out.append("\t\tbmin = Vector3.new(%s, %s, %s)," % tuple(f(x) for x in a))
    out.append("\t\tbmax = Vector3.new(%s, %s, %s)," % tuple(f(x) for x in b))
    out.append("\t\t-- กล่องชน { cx, cy, cz, sx, sy, sz } เทียบกับ origin ของ prop (ฐานกลาง) หน้าหันไป +Z")
    out.append("\t\tcols = {")
    for i in range(0, len(cols), 3):
        out.append("\t\t\t" + ", ".join(cols[i:i + 3]) + ",")
    out.append("\t\t},")
    out.append("\t},")
out.append("}")
sys.stdout.reconfigure(encoding="utf-8")
print("\n".join(out))
