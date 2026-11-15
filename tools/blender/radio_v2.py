# Radio v2 — วิทยุทรานซิสเตอร์บนเคาน์เตอร์เพิง (แทนวิทยุ Toolbox ที่เป็น Part 40 ชิ้น) ผู้ใช้ 2026-11-15 "เริ่มปั้นวิทยุก่อนเลย"
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/radio_v2.py
# ผลลัพธ์: assets/models/RadioV2/upload/ (FBX + texture) · ชั้นนอก: ภาพตัวอย่าง + .blend
# ใช้ vehlib.py + proplib.py · แกน Blender: หน้าวิทยุ -Y, +X = ขวามือคนยืนดูด้านหน้า (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
#
# หน้าตา: วิทยุกระเป๋าหิ้วยุค 70-80 แบบที่บ้านชนบทไทยเปิดฟังลูกทุ่ง ตัวหุ้มหนังเทียมดำ หน้าอะลูมิเนียม
#   หน้าปัดสเกลยาวเต็มหน้า (FM / AM) ลำโพงซี่โครเมียม ปุ่มหมุน 2 ปุ่ม ปุ่มเปียโนเลือกคลื่น มือหิ้วโครเมียม เสาอากาศยืด
#   ถ่านไฟฉายก้อนใหญ่ 4 ก้อนมัดหนังยางแดงไว้หลังเครื่อง (ฝาถ่านหาย) + สติกเกอร์ยันต์ซีดบนฝา
#
# ชื่อชิ้น (ดู MapBuilder.SwapRadioV2):
#   Radio            ตัวเครื่อง + ปุ่ม + มือหิ้ว + ถ่าน (ชิ้นใหญ่สุด AnomalyManager เอา TuneRadioPrompt + เสียงมาติดที่นี่ · ชิ้นเดียวที่ชน)
#   RadioDial        แผ่นสเกลหน้าปัด (แยกไว้ให้เกมทำไฟหน้าปัดสว่าง/กะพริบ)
#   RadioDialNeedle  เข็มหน้าปัดแดง (แยกไว้เลื่อนซ้ายขวาตอนเปลี่ยนสถานี) ไม่มี texture: เกมตั้งสีแดงเอง
#   RadioAntenna     เสาอากาศยืด (แยกไว้ให้เอียง/สั่นได้) ไม่มี texture: เกมตั้งเป็นโลหะเงินเอง
# ขนาดเทียบของเดิม: กว้าง 2.20 สูง 1.68 (รวมมือหิ้ว) ลึก 0.51
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "RadioV2")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, put, L = V.G, V.box, V.put, V.L
ZUP, XAX, YAX, FRONT = (0, 0, 1), (1, 0, 0), (0, 1, 0), (0, -1, 0)

MAIN, DIAL, NEEDLE, ANT = "Radio", "RadioDial", "RadioDialNeedle", "RadioAntenna"

W, D = 2.20, 0.56                 # กว้าง / ลึกตัวเครื่อง
FOOT = 0.05                       # ยางรองขา
HB = 1.30                         # สูงตัวเครื่อง (ไม่รวมขา)
CZ = FOOT + HB / 2                # กึ่งกลางตัวเครื่อง
TOP = FOOT + HB
YF = -D / 2                       # ผิวหน้าหนังหุ้ม
YP = YF - 0.018                   # ผิวหน้าแผงอะลูมิเนียม
DIAL_Z0, DIAL_Z1 = 1.00, 1.24     # ช่องหน้าปัด
DIAL_X = 0.96
GR_X0, GR_X1, GR_Z0, GR_Z1 = -0.98, 0.22, 0.14, 0.90   # ลำโพง
NEEDLE_X = -0.18                  # ตำแหน่งเข็ม (ประมาณ FM 96)
ANT_BASE = Vector((0.95, 0.19, TOP))

# ---------------------------------------------------------------- วัสดุ
V.make_mat("Leather", L((34, 30, 28)), 0.58, dirt=0.35, wear=0.45, bump=0.4, bump_scale=260)
V.make_mat("BrushedAlu", L((178, 176, 168)), 0.38, metal=0.85, dirt=0.45, wear=0.1, bump=0.08, bump_scale=400)
V.make_mat("Chrome", L((210, 210, 214)), 0.18, metal=1.0, dirt=0.3)
V.make_mat("BlackPlastic", L((22, 21, 21)), 0.45, dirt=0.3, wear=0.3)
V.make_mat("GrilleCloth", L((40, 33, 28)), 0.85, dirt=0.25, bump=0.5, bump_scale=600)
V.make_mat("Rubber", L((24, 23, 22)), 0.85, dirt=0.3)
V.make_mat("DarkSteel", L((55, 55, 58)), 0.5, metal=0.6, dirt=0.4, rust=0.15)
P.flat("CreamKey", L((226, 218, 196)), rough=0.4, dirt=0.35)
P.flat("DialCream", L((236, 226, 196)), rough=0.35, dirt=0.25)
P.flat("Ink", L((28, 24, 22)), rough=0.5, dirt=0.0)
P.flat("RedInk", L((178, 34, 28)), rough=0.5, dirt=0.0)
P.flat("BlueInk", L((40, 70, 140)), rough=0.5, dirt=0.0)
P.flat("NeedleRed", L((200, 30, 24)), rough=0.4, dirt=0.0)
P.flat("CellBlack", L((30, 30, 32)), rough=0.35, dirt=0.3)
P.flat("CellRed", L((176, 36, 30)), rough=0.35, dirt=0.3)
P.flat("CellSilver", L((190, 190, 192)), rough=0.25, metal=1.0, dirt=0.2)
P.flat("RubberBand", L((190, 52, 40)), rough=0.7, dirt=0.15)
P.flat("Sticker", L((214, 182, 92)), rough=0.8, dirt=0.45, noise=0.12)
P.flat("Wire", L((150, 30, 26)), rough=0.5, dirt=0.2)
P.flat("LampRed", L((150, 20, 16)), rough=0.2, dirt=0.0)


def rrect(cx, cz, hx, hz, y, p=7.0, n=40):
    """ขอบสี่เหลี่ยมมุมมน (superellipse) บนระนาบ XZ ที่ระยะ y"""
    return V.ring_y(cx, y, cz, hx, hz, n=n, p=p)


def text_g(s, cx, cz, size, y, depth=0.006):
    """ตัวอักษร (ฟอนต์ในตัว Blender) วางบนระนาบ XZ หันหน้า -Y กึ่งกลางที่ (cx, cz) ปิดหนา depth"""
    cu = bpy.data.curves.new("T", "FONT")
    cu.body = s
    cu.size = size
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.extrude = depth / 2
    cu.resolution_u = 3
    ob = bpy.data.objects.new("T", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    g = G()
    g.v = [(cx + v.co.x, y - v.co.z, cz + v.co.y) for v in me.vertices]
    g.f = [tuple(p.vertices) for p in me.polygons]
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bpy.data.meshes.remove(me)
    return g


def closed_loop(pts):
    return list(pts) + [pts[0], pts[1]]


# ---------------------------------------------------------------- ตัวเครื่อง (หนังเทียมหุ้ม มุมมน)
# หน้าตัวเครื่องไม่ปิด (แผงอะลูมิเนียมบังอยู่) ปิดเฉพาะด้านหลัง: ไม่เปลือง texture กับหน้าที่มองไม่เห็น
rings = [rrect(0, CZ, W / 2 - 0.09, HB / 2 - 0.09, YF + 0.02),
         rrect(0, CZ, W / 2 - 0.03, HB / 2 - 0.03, YF),
         rrect(0, CZ, W / 2, HB / 2, YF + 0.03),
         rrect(0, CZ, W / 2, HB / 2, -YF - 0.03),
         rrect(0, CZ, W / 2 - 0.03, HB / 2 - 0.03, -YF),
         rrect(0, CZ, 0.0, 0.0, -YF)]
put(MAIN, V.loft(rings, cap=False), "Leather")
# ขอบโครเมียมรอบหน้าเครื่อง
put(MAIN, V.tube(closed_loop(rrect(0, CZ, W / 2 - 0.035, HB / 2 - 0.035, YF - 0.004)), 0.022, n=6, cap=False), "Chrome")
# รอยตะเข็บหนังรอบข้าง (เส้นนูนบางๆ ห่างขอบหน้า/หลัง)
for y in (YF + 0.07, -YF - 0.07):
    put(MAIN, V.tube(closed_loop(rrect(0, CZ, W / 2 + 0.004, HB / 2 + 0.004, y)), 0.006, n=4, cap=False), "BlackPlastic")

# แผงหน้าอะลูมิเนียม (หนาเล็กน้อย ยื่นจากหนัง)
put(MAIN, V.loft([rrect(0, CZ, W / 2 - 0.07, HB / 2 - 0.07, YF + 0.01, p=9), rrect(0, CZ, W / 2 - 0.07, HB / 2 - 0.07, YP, p=9),
                  rrect(0, CZ, 0.0, 0.0, YP, p=9)], cap=False), "BrushedAlu")

# ---------------------------------------------------------------- ช่องหน้าปัด (กรอบโครเมียม + ร่องลึก แผ่นสเกลแยกชิ้น)
dz = (DIAL_Z0 + DIAL_Z1) / 2
put(MAIN, box((0, YP - 0.004, dz), (2 * DIAL_X + 0.06, 0.012, DIAL_Z1 - DIAL_Z0 + 0.06)), "Chrome", bevel=0.01)
put(MAIN, box((0, YP - 0.006, dz), (2 * DIAL_X, 0.01, DIAL_Z1 - DIAL_Z0)), "BlackPlastic")    # ร่องดำหลังสเกล

# ---------------------------------------------------------------- ลำโพง: ผ้าดำ + ซี่โครเมียมแนวนอน + กรอบ
gx, gz = (GR_X0 + GR_X1) / 2, (GR_Z0 + GR_Z1) / 2
gw, gh = GR_X1 - GR_X0, GR_Z1 - GR_Z0
put(MAIN, box((gx, YP - 0.004, gz), (gw - 0.05, 0.01, gh - 0.05)), "GrilleCloth")
put(MAIN, V.tube(closed_loop(rrect(gx, gz, gw / 2, gh / 2, YP - 0.012, p=10, n=36)), 0.016, n=6, cap=False), "Chrome")
NB = 11
for i in range(NB):
    z = GR_Z0 + 0.05 + i * (gh - 0.1) / (NB - 1)
    put(MAIN, P.cyl((GR_X0 + 0.03, YP - 0.03, z), XAX, 0.014, gw - 0.06, n=6), "Chrome")
put(MAIN, box((gx - 0.18, YP - 0.04, gz), (0.03, 0.02, gh - 0.04)), "Chrome")     # คานตั้งกลางลำโพง
# ป้ายชื่อเล็กมุมลำโพง (ไม่มียี่ห้อจริง: แผ่นเปล่าดำขอบเงิน + ตัวอักษร "SOLID STATE")
put(MAIN, box((GR_X0 + 0.2, YP - 0.045, GR_Z0 + 0.09), (0.3, 0.012, 0.075)), "BlackPlastic", bevel=0.005)
put(MAIN, text_g("SOLID STATE", GR_X0 + 0.2, GR_Z0 + 0.09, 0.034, YP - 0.052), "Chrome")

# ---------------------------------------------------------------- ฝั่งปุ่ม (ขวา)
KX0 = 0.32
# ปุ่มหมุน 2 ปุ่ม: VOLUME (เล็ก) / TUNING (ใหญ่) พลาสติกดำมีร่อง + ฝาโครเมียม
for (kx, kz, kr, lab) in ((0.50, 0.68, 0.12, "VOLUME"), (0.82, 0.68, 0.145, "TUNING")):
    c = Vector((kx, YP, kz))
    put(MAIN, P.ring_band(c, FRONT, 0.0, kr + 0.03, 0.0, 0.012, n=28), "Chrome")              # แหวนรองปุ่ม
    put(MAIN, V.lathe_axis(c, FRONT, [(0.0, kr), (0.1, kr), (0.12, kr - 0.02), (0.13, 0.0)], n=28), "BlackPlastic")
    for i in range(20):                                                                       # ร่องกันลื่นรอบปุ่ม
        a = 2 * math.pi * i / 20
        put(MAIN, P.box_rot((kx + math.cos(a) * kr, YP - 0.055, kz + math.sin(a) * kr), (0.022, 0.09, 0.022), "Y", -math.degrees(a)), "BlackPlastic")
    put(MAIN, P.cyl(c + Vector((0, -0.125, 0)), FRONT, kr * 0.62, 0.012, n=24), "Chrome")
    put(MAIN, box((kx, YP - 0.14, kz + kr * 0.35), (0.018, 0.006, kr * 0.4)), "Ink")          # ขีดบอกตำแหน่ง
    put(MAIN, text_g(lab, kx, kz - kr - 0.07, 0.042, YP - 0.004), "Ink")
# ปุ่มเปียโนเลือกคลื่น 4 ปุ่ม (ปุ่มที่ 2 กดลงค้าง)
for i, lab in enumerate(("OFF", "FM", "MW", "SW")):
    x = KX0 + 0.08 + i * 0.165
    pressed = (i == 1)
    put(MAIN, box((x, YP - (0.025 if pressed else 0.05), 0.33), (0.13, 0.05 if pressed else 0.1, 0.1)), "CreamKey" if i else "BlackPlastic", bevel=0.012)
    put(MAIN, text_g(lab, x, 0.2, 0.036, YP - 0.004), "Ink")
put(MAIN, box((KX0 + 0.33, YP - 0.008, 0.33), (0.7, 0.012, 0.14)), "BlackPlastic")             # ร่องรองปุ่มเปียโน
# ไฟสัญญาณ (TUNE) เลนส์แดงเล็ก
put(MAIN, P.dome(Vector((0.98 - 0.06, YP, 0.94)), FRONT, 0.028, 0.02), "LampRed")
put(MAIN, P.ring_band(Vector((0.98 - 0.06, YP, 0.94)), FRONT, 0.026, 0.038, 0.0, 0.01, n=16), "Chrome")

# ---------------------------------------------------------------- มือหิ้ว (โครเมียม พับตั้ง + กริปหนังดำ)
for sx in (-1, 1):
    put(MAIN, box((sx * 0.86, 0.0, TOP + 0.03), (0.14, 0.2, 0.06)), "Chrome", bevel=0.015)     # ขายึดบนฝา
    put(MAIN, P.cyl((sx * 0.86 - 0.05, 0.0, TOP + 0.08), XAX, 0.035, 0.1, n=12), "Chrome")    # หมุดหมุน
hp = P.spline([(-0.86, 0.0, TOP + 0.06), (-0.86, 0.0, TOP + 0.2), (-0.8, 0.0, TOP + 0.31), (-0.68, 0.0, TOP + 0.35),
               (0.68, 0.0, TOP + 0.35), (0.8, 0.0, TOP + 0.31), (0.86, 0.0, TOP + 0.2), (0.86, 0.0, TOP + 0.06)], per=6)
put(MAIN, V.tube(hp, 0.03, n=8), "Chrome")
put(MAIN, V.lathe_axis((-0.48, 0.0, TOP + 0.35), XAX, [(0.0, 0.0), (0.0, 0.05), (0.04, 0.065), (0.92, 0.065), (0.96, 0.05), (0.96, 0.0)], n=14), "Leather")

# ---------------------------------------------------------------- ฝาบน: ฐานเสาอากาศ + สติกเกอร์ยันต์ซีด + รูน็อต
put(MAIN, P.cyl(ANT_BASE, ZUP, 0.06, 0.05, n=14), "Chrome")
put(MAIN, P.box_rot((-0.35, -0.05, TOP + 0.003), (0.42, 0.32, 0.006), "Z", -7), "Sticker")
for (x, y) in ((-0.42, -0.08), (-0.3, -0.02), (-0.36, 0.04)):                                 # ลายยันต์ (ขีดแดงจางๆ)
    put(MAIN, P.box_rot((x, y, TOP + 0.007), (0.2, 0.012, 0.004), "Z", -7 + (x * 40)), "RedInk")
for x in (-0.7, 0.4):
    put(MAIN, P.cyl((x, 0.18, TOP), ZUP, 0.025, 0.008, n=8), "DarkSteel")

# ---------------------------------------------------------------- หลังเครื่อง: ช่องถ่าน (ฝาหาย) + ถ่านใหญ่ 4 ก้อนมัดหนังยาง + ช่องระบาย
YB = -YF
put(MAIN, box((0.35, YB + 0.004, CZ - 0.1), (1.1, 0.01, 0.7)), "BlackPlastic")               # ช่องถ่านที่ไม่มีฝา
for i in range(6):                                                                         # ช่องระบายความร้อน
    put(MAIN, box((-0.65, YB + 0.006, CZ + 0.3 - i * 0.1), (0.5, 0.01, 0.035)), "BlackPlastic")
put(MAIN, box((-0.65, YB + 0.003, CZ - 0.35), (0.22, 0.008, 0.12)), "DarkSteel")              # เต้าเสียบไฟบ้าน (DC IN)
CELL_R, CELL_L = 0.1, 0.4
cells = []
for row, cz in enumerate((CZ - 0.32, CZ - 0.32 + 2 * CELL_R + 0.005)):
    for col, cx in enumerate((0.12, 0.58)):
        flip = (row + col) % 2 == 1
        c = Vector((cx - CELL_L / 2, YB + CELL_R + 0.012, cz + CELL_R))
        put(MAIN, P.cyl(c, XAX, CELL_R, CELL_L, n=18), "CellBlack")
        band_x = cx + (CELL_L / 2 - 0.1 if flip else -CELL_L / 2)
        put(MAIN, P.cyl(Vector((band_x, c.y, c.z)), XAX, CELL_R + 0.003, 0.1, n=18, cap=False), "CellRed")
        tip = cx + (CELL_L / 2 if not flip else -CELL_L / 2)
        put(MAIN, P.cyl(Vector((tip, c.y, c.z)), (1 if not flip else -1, 0, 0), 0.035, 0.02, n=10), "CellSilver")
        cells.append(c)
# หนังยางแดง 2 เส้นรัดถ่านทั้ง 2 แถว (วงปิด: อ้อมหลังถ่าน แล้วสอดเข้าช่องถ่านที่ไม่มีฝา)
for bx in (0.24, 0.66):
    y0, y1 = YB - 0.01, YB + 2 * CELL_R + 0.03
    z0, z1 = CZ - 0.32 - 0.012, CZ - 0.32 + 4 * CELL_R + 0.017
    loop = [(bx, y0, z0 + 0.02), (bx, (y0 + y1) / 2, z0), (bx, y1 - 0.03, z0 + 0.01), (bx, y1, z0 + 0.06), (bx, y1 + 0.005, (z0 + z1) / 2),
            (bx, y1, z1 - 0.06), (bx, y1 - 0.03, z1 - 0.01), (bx, (y0 + y1) / 2, z1), (bx, y0, z1 - 0.02)]
    pts = P.spline(loop + [loop[0]], per=4)
    put(MAIN, V.tube(pts[:-1] + [pts[0], pts[1]], 0.013, n=5, cap=False), "RubberBand")
# สายไฟแดงจากขั้วถ่านเข้าช่องถ่าน (ต่อพ่วงเอง)
put(MAIN, V.tube(P.spline([(0.58 + CELL_L / 2 + 0.02, YB + CELL_R + 0.012, CZ - 0.32 + CELL_R), (0.86, YB + 0.12, CZ - 0.12),
                            (0.84, YB + 0.04, CZ + 0.12), (0.72, YB + 0.0, CZ + 0.18)], per=6), 0.012, n=5), "Wire")

# ยางรองขา 4 มุม
for sx in (-1, 1):
    for sy in (-1, 1):
        put(MAIN, P.cyl((sx * (W / 2 - 0.2), sy * (D / 2 - 0.1), 0.0), ZUP, 0.07, FOOT + 0.01, n=12), "Rubber")

# ---------------------------------------------------------------- แผ่นสเกลหน้าปัด (แยกชิ้น)
YD = YP - 0.012
put(DIAL, box((0, YD, dz), (2 * DIAL_X - 0.02, 0.008, DIAL_Z1 - DIAL_Z0 - 0.02)), "DialCream")
SX0, SX1 = -0.78, 0.86                 # ช่วงสเกล (ซ้ายมีชื่อคลื่น)
ROWS = (("FM", DIAL_Z1 - 0.055, ("88", "92", "96", "100", "104", "108"), "RedInk"),
        ("AM", DIAL_Z0 + 0.075, ("53", "60", "70", "80", "100", "120", "140", "160"), "BlueInk"))
for name, z, nums, col in ROWS:
    put(DIAL, text_g(name, -0.88, z, 0.05, YD - 0.006), col)
    put(DIAL, box(((SX0 + SX1) / 2, YD - 0.005, z - 0.045), (SX1 - SX0, 0.004, 0.008)), col)     # เส้นแถบสี
    n = len(nums)
    for i, s in enumerate(nums):
        x = SX0 + (SX1 - SX0) * i / (n - 1)
        put(DIAL, text_g(s, x, z, 0.042, YD - 0.006), "Ink")
    for k in range((n - 1) * 4 + 1):                                                       # ขีดสเกลย่อย
        x = SX0 + (SX1 - SX0) * k / ((n - 1) * 4)
        tall = k % 4 == 0
        put(DIAL, box((x, YD - 0.005, z - 0.045 + (0.015 if tall else 0.01)), (0.008, 0.004, 0.03 if tall else 0.018)), "Ink")
put(DIAL, text_g("MHz", SX1 + 0.05, ROWS[0][1] - 0.04, 0.026, YD - 0.006), "Ink")
put(DIAL, text_g("kHz", SX1 + 0.05, ROWS[1][1] - 0.04, 0.026, YD - 0.006), "Ink")

# ---------------------------------------------------------------- เข็มหน้าปัด (แยกชิ้น ไม่มี texture)
put(NEEDLE, box((NEEDLE_X, YD - 0.012, dz), (0.016, 0.008, DIAL_Z1 - DIAL_Z0 - 0.03)), "NeedleRed")

# ---------------------------------------------------------------- เสาอากาศยืด 5 ท่อน (แยกชิ้น ไม่มี texture) เอียงไปซ้าย-หลัง
adir = Vector((-0.42, 0.22, 1.0)).normalized()
put(ANT, P.cyl(ANT_BASE + Vector((0, 0, 0.04)), ZUP, 0.045, 0.06, n=12), "Chrome")             # ข้อพับ
p0 = ANT_BASE + Vector((0, 0, 0.09))
put(ANT, P.dome(p0, (0, 0, -1), 0.045, 0.03), "Chrome")
seg_r = (0.03, 0.025, 0.021, 0.017, 0.013)
seg_l = (0.42, 0.42, 0.40, 0.38, 0.36)
cur = p0
for r, ln in zip(seg_r, seg_l):
    put(ANT, P.cyl(cur, adir, r, ln, n=8), "Chrome")
    put(ANT, P.ring_band(cur, adir, r - 0.002, r + 0.006, ln - 0.03, ln, n=8), "Chrome")
    cur = cur + adir * (ln - 0.03)
put(ANT, V.lathe_axis(cur + adir * 0.03, adir, [(0.0, 0.0), (0.0, 0.02), (0.015, 0.03), (0.04, 0.025), (0.055, 0.0)], n=10), "Chrome")

# ---------------------------------------------------------------- UV: ให้ด้านหน้า (ที่ผู้เล่นเห็น) ได้พื้นที่ texture มากกว่าด้านอื่น
FRONT_BOOST = 2.4
_unwrap = V.uv_unwrap


def uv_front_boost(ob, margin=0.004):
    _unwrap(ob, margin)
    if ob.name != MAIN:
        return
    import bmesh
    from bpy_extras import bmesh_utils
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv = bm.loops.layers.uv.active
    n_boost = 0
    for isl in bmesh_utils.bmesh_linked_uv_islands(bm, uv):
        area = sum(f.calc_area() for f in isl)
        if area <= 0:
            continue
        ny = sum(f.normal.y * f.calc_area() for f in isl) / area
        zc = sum(f.calc_center_median().z * f.calc_area() for f in isl) / area / V.S
        if ny < -0.5 and zc < TOP:
            loops = [lp for f in isl for lp in f.loops]
            c = sum((lp[uv].uv for lp in loops), Vector((0, 0))) / len(loops)
            for lp in loops:
                lp[uv].uv = c + (lp[uv].uv - c) * FRONT_BOOST
            n_boost += 1
    bm.to_mesh(ob.data)
    bm.free()
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    bpy.ops.object.mode_set(mode="OBJECT")
    P.log(f"uv front boost x{FRONT_BOOST} on {n_boost} islands")


V.uv_unwrap = uv_front_boost

# ---------------------------------------------------------------- object + bake + export
ORDER = [MAIN, DIAL, NEEDLE, ANT]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"NEEDLE_RANGE_rbx x=({-SX0:.3f}..{-SX1:.3f}) dial_z={dz:.3f} ANT_BASE_rbx=({-ANT_BASE.x:.3f},{ANT_BASE.z:.3f},{ANT_BASE.y:.3f})")
if not NO_BAKE:
    P.bake_all(OBJ, {MAIN: "RadioV2_Body", DIAL: "RadioV2_Dial"}, {MAIN: 1024, DIAL: 512})
P.export_fbx(OBJ, os.path.join(UP, "RadioV2.fbx"), MAIN)


def preview():
    cam, sun, world = P.stage()
    tgt = (0, 0, 0.8)
    P.shot(cam, os.path.join(OUT, "RadioV2.png"), tgt, (-0.55, -1.0, 0.45), 7.5)
    P.shot(cam, os.path.join(OUT, "RadioV2_front.png"), tgt, (0.0, -1.0, 0.12), 6.8)
    P.shot(cam, os.path.join(OUT, "RadioV2_back.png"), tgt, (0.6, 1.0, 0.4), 7.5)
    P.shot(cam, os.path.join(OUT, "RadioV2_dial.png"), (0.1, 0, 0.75), (-0.15, -1.0, 0.25), 3.6)
    P.shot(cam, os.path.join(OUT, "RadioV2_top.png"), (0, 0, 1.3), (0.0, -0.35, 1.0), 5.5)
    # ไฟหน้าปัด (เฉพาะภาพตัวอย่างกลางคืน: ให้เห็นว่าเกมทำหน้าปัดเรืองได้)
    dm = OBJ[DIAL].data.materials[0]
    nt = dm.node_tree
    bs = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    col = next((n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name.endswith("_Color")), None)
    if bs and col:
        tint = nt.nodes.new("ShaderNodeMix")
        tint.data_type = "RGBA"
        tint.blend_type = "MULTIPLY"
        tint.inputs["Factor"].default_value = 1.0
        tint.inputs["B"].default_value = (1.0, 0.72, 0.38, 1)
        nt.links.new(col.outputs[0], tint.inputs["A"])
        nt.links.new(tint.outputs["Result"], bs.inputs["Emission Color"])
        bs.inputs["Emission Strength"].default_value = 1.0
    P.night(world, sun, (-1.5, -4.0, 6.0), energy=25)
    P.shot(cam, os.path.join(OUT, "RadioV2_night.png"), tgt, (-0.5, -1.0, 0.35), 7.5)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "radio_v2.blend"))
P.log("done")
