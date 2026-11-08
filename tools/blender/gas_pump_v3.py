# GasPump v3 — ปั๊มหลอดบนถังน้ำมัน 200 ลิตร แบบที่เห็นจริงตามบ้านนอก (ผู้ใช้ 2026-11-08 ส่งรูปตัวอย่าง 7 รูป: v2 "ดูใหม่" เกินไป)
#   ถังเหล็กสีซีดสนิมขึ้นวางบนแคร่ไม้ · ท่อขึ้นจากฝาถัง · ปั๊มมือโยกตัวกลมสีแดง (ก้านโยกด้านข้าง) · วาล์วด้ามฟ้า
#   หลอดแก้วมีแถบสเกลสีขาวด้านใน · ฝาแดง · สายยางพลาสติกเหลืองใสห้อยลงมาคล้องขอบถัง · คุมโทนหม่น มืด เก่า แบบเกม
# รัน: D:\blender-5.2.4\blender.exe -b --factory-startup --python tools/blender/gas_pump_v3.py
# ผลลัพธ์: assets/models/GasPumpV3/upload/ (FBX + texture) · ชั้นนอก: ภาพตัวอย่าง + .blend
# แกน Blender: หน้า -Y, +X = ขวามือคนยืนหน้าปั๊ม (Roblox: X = -bx, Y = bz, Z = by) หน่วย studs
# ชื่อชิ้น (เกมใช้ อย่าเปลี่ยน · MapBuilder.SwapGasPumpV3):
#   GasPump (ถัง + แคร่ + ท่อ + ตัวปั๊ม + สายยาง · ชนได้ · PrimaryPart) / GlassTube / FuelLiquid (อบครีมอ่อน ย้อมสีในเกม)
#   HandCrank (ก้านโยก หมุนรอบแกน Y ที่ CRANK_HUB) / Nozzle (ปลายสายคล้องขอบถัง)
import bpy, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
bpy.ops.wm.read_factory_settings(use_empty=True)
import vehlib as V  # noqa: E402
import proplib as P  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))
OUT = os.path.join(ROOT, "GasPumpV3")
UP = os.path.join(OUT, "upload")
os.makedirs(UP, exist_ok=True)
V.UP = UP
V.SAMPLES = int(os.environ.get("PROP_SAMPLES", "16"))
NO_BAKE = os.environ.get("PROP_NOBAKE") == "1"
G, box, lathe, put, L = V.G, V.box, V.lathe_axis, V.put, V.L
ZUP, XAX, YAX = (0, 0, 1), (1, 0, 0), (0, 1, 0)

BODY, GLASS, LIQ, CRANK, NOZ = "GasPump", "GlassTube", "FuelLiquid", "HandCrank", "Nozzle"

PAL = 0.32                          # ผิวบนแคร่ไม้
DR, DH = 1.02, 3.10                 # ถัง 200 ลิตร (Ø ~0.57 ม. สูง ~0.87 ม.)
DTOP = PAL + DH
PIPE = Vector((0.0, 0.0, 0.0))      # ท่อตรงศูนย์หลอด (กลางถัง)
PUMP_Z = 4.25                       # กึ่งกลางตัวปั๊มโยก
CRANK_HUB = Vector((PIPE.x, PIPE.y - 0.25, PUMP_Z))
VALVE_Z = 4.86
GB_Z0, GB_Z1 = 4.98, 5.16           # ฐานรองหลอด
GL_Z0, GL_Z1, GL_R, GL_T = 5.16, 7.00, 0.55, 0.03
LQ_R, LQ_Z0, LQ_Z1 = 0.47, 5.19, 6.62

# ---------------------------------------------------------------- วัสดุ (โทนหม่น เก่า มอมแมม)
P.wood("PalletWood", L((120, 104, 84)), rough=0.9, dirt=0.65, grain_axis="X", grain=1.3, gray=0.55)
P.wood("PalletDark", L((92, 76, 58)), rough=0.9, dirt=0.65, grain_axis="Y", grain=1.3, gray=0.45)
V.make_mat("DrumRed", L((118, 42, 32)), 0.7, metal=0.25, dirt=0.75, wear=0.6, rust=0.38)
V.make_mat("DrumYellow", L((168, 132, 52)), 0.7, metal=0.2, dirt=0.75, wear=0.6, rust=0.32)
V.make_mat("DrumLid", L((96, 44, 34)), 0.55, metal=0.3, dirt=0.8, wear=0.5, rust=0.3)
V.make_mat("OilStain", L((16, 13, 10)), 0.35, dirt=0.0)
V.make_mat("Galv", L((128, 130, 126)), 0.55, metal=0.75, dirt=0.65, wear=0.25, rust=0.2)
V.make_mat("PumpRed", L((140, 36, 28)), 0.6, metal=0.2, dirt=0.65, wear=0.55, rust=0.22)
V.make_mat("CapRed", L((140, 42, 34)), 0.55, metal=0.15, dirt=0.55, wear=0.5, rust=0.12)
V.make_mat("DarkSteel", L((48, 47, 46)), 0.6, metal=0.55, dirt=0.55, wear=0.35, rust=0.3)
V.make_mat("Brass", L((150, 118, 58)), 0.45, metal=0.9, dirt=0.55, wear=0.3)
V.make_mat("ValveBlue", L((50, 96, 150)), 0.5, dirt=0.5, wear=0.4)
V.make_mat("Grip", L((30, 29, 28)), 0.75, dirt=0.4, bump=0.2, bump_scale=80)
P.flat("HoseYellow", L((196, 170, 92)), rough=0.3, dirt=0.45, noise=0.05)
P.flat("ScaleWhite", L((214, 208, 190)), rough=0.5, dirt=0.35)
P.flat("Ink", L((30, 26, 24)), rough=0.6, dirt=0.0)
P.flat("RedInk", L((150, 34, 28)), rough=0.6, dirt=0.0)
P.flat("BottleWhite", L((205, 200, 186)), rough=0.45, dirt=0.55)
P.flat("Glass", L((205, 225, 215)), rough=0.05, dirt=0.0, noise=0.0)
P.flat("Liquid", L((238, 226, 200)), rough=0.12, dirt=0.0, noise=0.008)

# ---------------------------------------------------------------- แคร่ไม้ (พาเลท)
for x in (-1.0, 0.0, 1.0):                                  # ไม้รองใต้ 3 ท่อน
    put(BODY, box((x, 0, 0.12), (0.34, 2.7, 0.24)), "PalletDark", bevel=0.02)
for k in range(6):                                          # ไม้พื้น 6 แผ่น ห่างกันนิดๆ
    y = -1.18 + k * 0.47
    put(BODY, box((0.02 * ((k * 7) % 3 - 1), y, PAL - 0.04), (2.75 - 0.08 * (k % 2), 0.4, 0.08)), "PalletWood", bevel=0.015)
    for x in (-1.0, 0.0, 1.0):
        put(BODY, P.dome((x, y, PAL), ZUP, 0.025, 0.01, n=6), "DarkSteel")

# ---------------------------------------------------------------- ถังน้ำมัน 200 ลิตร (ขอบม้วน + ห่วงคาด 2 วง + แถบสีกลางถัง)
z0 = PAL
H1, H2 = z0 + DH * 0.34, z0 + DH * 0.66                     # ห่วงคาด
put(BODY, lathe((0, 0, 0), ZUP, [(z0, 0.0), (z0, DR - 0.03), (z0 + 0.03, DR + 0.025), (z0 + 0.08, DR + 0.02), (z0 + 0.1, DR), (H1 - 0.05, DR),
                                 (H1 - 0.02, DR + 0.03), (H1 + 0.02, DR + 0.03), (H1 + 0.05, DR)], n=48), "DrumRed")
put(BODY, lathe((0, 0, 0), ZUP, [(H1 + 0.05, DR), (H2 - 0.05, DR)], n=48), "DrumYellow")
put(BODY, lathe((0, 0, 0), ZUP, [(H2 - 0.05, DR), (H2 - 0.02, DR + 0.03), (H2 + 0.02, DR + 0.03), (H2 + 0.05, DR), (DTOP - 0.1, DR), (DTOP - 0.07, DR + 0.025),
                                 (DTOP, DR + 0.028), (DTOP + 0.02, DR + 0.01), (DTOP + 0.01, DR - 0.05), (DTOP - 0.04, DR - 0.06), (DTOP - 0.04, 0.0)], n=48), "DrumRed")
# ฝาถัง: คราบน้ำมันเยิ้ม + จุกเกลียว 2 รู
for (cx, cy, r) in ((0.1, 0.0, 0.62), (-0.35, -0.3, 0.34), (0.45, 0.35, 0.25)):
    put(BODY, P.extrude_z([(cx + math.cos(a) * r * (0.85 + 0.15 * math.sin(a * 3)), cy + math.sin(a) * r * (0.85 + 0.15 * math.cos(a * 2))) for a in
                           [2 * math.pi * i / 14 for i in range(14)]], DTOP - 0.04, DTOP - 0.035), "OilStain")
put(BODY, P.cyl((0.55, 0.42, DTOP - 0.04), ZUP, 0.12, 0.07, n=10), "DarkSteel")              # จุกเล็กปิดไว้
put(BODY, P.cyl((0.55, 0.42, DTOP + 0.03), ZUP, 0.05, 0.04, n=6), "DarkSteel")
# ขวดน้ำมันเครื่อง 2T ขาวเก่าวางบนฝาถัง + กรวยพลาสติก
BT = Vector((-0.5, -0.42, DTOP - 0.04))
put(BODY, box(tuple(BT + Vector((0, 0, 0.32))), (0.3, 0.18, 0.64)), "BottleWhite", bevel=0.05)
put(BODY, P.cyl(BT + Vector((0.06, 0, 0.64)), ZUP, 0.05, 0.08, n=8), "CapRed")
put(BODY, box(tuple(BT + Vector((0, -0.092, 0.34))), (0.2, 0.006, 0.22)), "RedInk")
FN = Vector((0.52, -0.38, DTOP - 0.04))
put(BODY, lathe(FN, ZUP, [(0.0, 0.03), (0.16, 0.035), (0.18, 0.06), (0.36, 0.2), (0.38, 0.21), (0.38, 0.19), (0.2, 0.05)], n=14), "Brass")

# ---------------------------------------------------------------- ท่อ + ปั๊มโยกตัวกลมสีแดง
put(BODY, lathe(PIPE + Vector((0, 0, DTOP - 0.04)), ZUP, [(0, 0.17), (0.05, 0.17), (0.07, 0.11), (0.14, 0.1), (0.16, 0.08)], n=12), "DarkSteel")   # ข้อต่อจุกใหญ่
put(BODY, P.cyl(PIPE + Vector((0, 0, DTOP + 0.1)), ZUP, 0.075, PUMP_Z - 0.32 - DTOP - 0.1, n=12), "Galv")
put(BODY, lathe(PIPE + Vector((0, 0, PUMP_Z - 0.42)), ZUP, [(0, 0.08), (0.02, 0.11), (0.1, 0.11), (0.12, 0.09)], n=10), "Galv")          # ข้อต่อเกลียว
# ตัวเรือนปั๊ม (จานกลมหันหน้า -Y) มีหูบน-ล่างต่อท่อ
PC = PIPE + Vector((0, 0, PUMP_Z))
put(BODY, lathe(PC + Vector((0, 0.13, 0)), (0, -1, 0), [(0.0, 0.0), (0.0, 0.3), (0.02, 0.34), (0.2, 0.34), (0.22, 0.31), (0.26, 0.3), (0.3, 0.22), (0.32, 0.12), (0.33, 0.0)], n=28), "PumpRed")
for i in range(8):
    a = 2 * math.pi * (i + 0.5) / 8
    put(BODY, P.cyl(PC + Vector((math.cos(a) * 0.3, -0.12, math.sin(a) * 0.3)), (0, -1, 0), 0.03, 0.05, n=6), "DarkSteel")
for sz in (1, -1):
    put(BODY, P.cyl(PC + Vector((0, 0, sz * 0.3)), (0, 0, sz), 0.1, 0.12, n=10), "PumpRed")
    put(BODY, P.cyl(PC + Vector((0, 0, sz * 0.42)), (0, 0, sz), 0.085, 0.05, n=8), "DarkSteel")
put(BODY, box(tuple(PC + Vector((0, 0.24, -0.05))), (0.16, 0.12, 0.5)), "PumpRed", bevel=0.02)              # ขายึดท่อด้านหลัง
# ท่อขึ้นไปวาล์ว
put(BODY, P.cyl(PC + Vector((0, 0, 0.47)), ZUP, 0.065, VALVE_Z - PUMP_Z - 0.55, n=12), "Galv")
VC = PIPE + Vector((0, 0, VALVE_Z))
put(BODY, box(tuple(VC), (0.2, 0.2, 0.22)), "Brass", bevel=0.03)
put(BODY, P.cyl(VC, (-1, 0, 0), 0.07, 0.24, n=10), "Brass")                                                 # ทางออกไปสายยาง (ฝั่ง -X)
put(BODY, P.cyl(VC + Vector((-0.24, 0, 0)), (-1, 0, 0), 0.05, 0.12, n=10), "Brass")
for k in range(3):
    put(BODY, P.ring_band(VC + Vector((-0.26 - k * 0.035, 0, 0)), XAX, 0.05, 0.062, 0.0, 0.015, n=10), "Brass")
put(BODY, P.cyl(VC + Vector((0, 0, 0.11)), ZUP, 0.03, 0.08, n=6), "DarkSteel")
put(BODY, P.box_rot(tuple(VC + Vector((0.0, -0.18, 0.2))), (0.07, 0.36, 0.04), "X", 8), "ValveBlue")          # ด้ามวาล์วฟ้า
put(BODY, P.cyl(VC + Vector((0, 0, 0.11)), ZUP, 0.055, VALVE_Z - VALVE_Z + GB_Z0 - VALVE_Z - 0.11, n=12), "Galv")
# ฐานรองหลอด (จานโลหะ) + ปลอกบน + เสาค้ำ 3 ต้น + ฝาแดง
put(BODY, lathe(PIPE * 0 + Vector((0, 0, 0)), ZUP, [(GB_Z0, 0.0), (GB_Z0, 0.22), (GB_Z0 + 0.06, 0.5), (GB_Z0 + 0.09, 0.64), (GB_Z1 - 0.03, 0.66), (GB_Z1, 0.62), (GB_Z1, 0.0)], n=40), "Galv")
# (หลอดอยู่ตรงกลางท่อพอดี: ย้ายท่อให้ตรงศูนย์หลอด)
put(BODY, P.ring_band((0, 0, 0), ZUP, GL_R - 0.01, GL_R + 0.06, GL_Z1 - 0.02, GL_Z1 + 0.07, n=40), "Galv")
for a in (90, 210, 330):
    r = GL_R + 0.045
    put(BODY, P.cyl((math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r, GB_Z1), ZUP, 0.028, GL_Z1 - GB_Z1, n=8), "Galv")
put(BODY, lathe((0, 0, GL_Z1 + 0.07), ZUP, [(0, 0.69), (0.04, 0.7), (0.1, 0.68), (0.13, 0.6), (0.18, 0.4), (0.21, 0.15), (0.22, 0.0)], n=40), "CapRed")
put(BODY, P.ring_band((0, 0, 0), ZUP, 0.64, 0.7, GL_Z1 + 0.05, GL_Z1 + 0.12, n=40), "CapRed")
put(BODY, P.dome((0, 0, GL_Z1 + 0.29), ZUP, 0.07, 0.06, n=10), "DarkSteel")
# แถบสเกลขาวด้านในหลอด (ระหว่างน้ำมันกับแก้ว) ขีดดำทุกลิตร ขีดแดงทุก 5
SA = math.radians(235)
sx, sy = math.cos(SA), math.sin(SA)
put(BODY, P.box_rot((sx * 0.505, sy * 0.505, (LQ_Z0 + GL_Z1) / 2 - 0.05), (0.13, 0.012, GL_Z1 - LQ_Z0 - 0.15), "Z", math.degrees(SA) + 90), "ScaleWhite")
for i in range(11):
    z = LQ_Z0 + 0.05 + (LQ_Z1 - LQ_Z0 - 0.05) * i / 10
    w = 0.09 if i % 5 == 0 else 0.05
    put(BODY, P.box_rot((sx * 0.498, sy * 0.498, z), (w, 0.006, 0.02), "Z", math.degrees(SA) + 90), "RedInk" if i % 5 == 0 else "Ink")

# ---------------------------------------------------------------- สายยางพลาสติกเหลืองใส: ออกวาล์ว ห้อยข้างถัง แล้วขึ้นมาคล้องขอบถังด้านหน้า
NZ_TOP = Vector((-0.78, -0.72, DTOP + 0.16))
hose = P.spline([tuple(VC + Vector((-0.36, 0, 0))), (-0.62, 0.05, VALVE_Z - 0.12), (-1.05, -0.05, 4.1), (-1.26, -0.2, 3.0), (-1.3, -0.45, 1.6),
                 (-1.22, -0.8, 1.05), (-1.05, -1.0, 1.35), (-0.92, -0.92, 2.2), tuple(NZ_TOP + Vector((-0.06, -0.04, -0.62)))], per=8)
put(BODY, V.tube(hose, 0.055, n=10), "HoseYellow")

# ---------------------------------------------------------------- หลอดแก้ว (ผนังสองชั้น)
put(GLASS, lathe((0, 0, 0), ZUP, [(GL_Z0, GL_R - GL_T), (GL_Z0, GL_R), (GL_Z1, GL_R), (GL_Z1, GL_R - GL_T), (GL_Z0 + 0.001, GL_R - GL_T)], n=40), "Glass")

# ---------------------------------------------------------------- น้ำมัน
put(LIQ, lathe((0, 0, 0), ZUP, [(LQ_Z0, 0.0), (LQ_Z0, LQ_R), (LQ_Z1 - 0.02, LQ_R), (LQ_Z1, LQ_R - 0.02), (LQ_Z1, 0.0)], n=32), "Liquid")

# ---------------------------------------------------------------- ก้านโยก (ออกขวามือ เอียงลงนิดๆ) หมุนรอบแกน Y ที่ CRANK_HUB
H = CRANK_HUB
put(CRANK, P.cyl(H + Vector((0, 0.06, 0)), (0, -1, 0), 0.11, 0.1, n=14), "PumpRed")
put(CRANK, P.cyl(H + Vector((0, -0.04, 0)), (0, -1, 0), 0.05, 0.06, n=6), "DarkSteel")
END = H + Vector((1.12, -0.04, -0.34))
put(CRANK, V.tube([tuple(H + Vector((0.05, -0.01, 0))), tuple(H + Vector((0.5, -0.03, -0.1))), tuple(END)], [0.06, 0.045, 0.04], n=10), "PumpRed")
put(CRANK, V.lathe_axis(END + (END - H).normalized() * -0.32, (END - H).normalized(), [(0, 0.045), (0.03, 0.06), (0.3, 0.06), (0.34, 0.045), (0.36, 0.0)], n=12), "Grip")

# ---------------------------------------------------------------- ปลายสาย (ท่อโลหะงอ คล้องขอบถัง)
noz = P.spline([tuple(NZ_TOP + Vector((-0.06, -0.04, -0.66))), tuple(NZ_TOP + Vector((-0.03, -0.02, -0.25))), tuple(NZ_TOP),
                tuple(NZ_TOP + Vector((0.07, 0.07, 0.06))), tuple(NZ_TOP + Vector((0.15, 0.15, -0.08)))], per=5)
put(NOZ, V.tube(noz, [0.065] * 6 + [0.04] * (len(noz) - 6), n=10), "Brass")
put(NOZ, P.ring_band(Vector(noz[0]), (Vector(noz[1]) - Vector(noz[0])).normalized(), 0.05, 0.075, 0.0, 0.08, n=10), "DarkSteel")

# ---------------------------------------------------------------- object + bake + export
ORDER = [BODY, GLASS, LIQ, CRANK, NOZ]
OBJ = P.build(ORDER)
P.log_bbox(OBJ)
P.log(f"CRANK_HUB_rbx=({-CRANK_HUB.x:.3f},{CRANK_HUB.z:.3f},{CRANK_HUB.y:.3f})")
if not NO_BAKE:
    P.bake_all(OBJ, {BODY: "GasPumpV3_Body", LIQ: "GasPumpV3_Liquid", CRANK: "GasPumpV3_Crank", NOZ: "GasPumpV3_Nozzle"},
               {BODY: 1024, LIQ: 256, CRANK: 256, NOZ: 256})
P.export_fbx(OBJ, os.path.join(UP, "GasPumpV3.fbx"), BODY)


def preview():
    gm = OBJ[GLASS].data.materials[0]
    bs = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Alpha"].default_value = 0.3
    bs.inputs["Transmission Weight"].default_value = 0.6
    lm = OBJ[LIQ].data.materials[0]
    lb = next(n for n in lm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    mix = lm.node_tree.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = (0.85, 0.36, 0.06, 1)
    if lb.inputs["Base Color"].links:
        lm.node_tree.links.new(lb.inputs["Base Color"].links[0].from_socket, mix.inputs["A"])
    else:
        mix.inputs["A"].default_value = (1, 1, 1, 1)
    lm.node_tree.links.new(mix.outputs["Result"], lb.inputs["Base Color"])
    cam, sun, world = P.stage()
    P.add_person(ROOT, (2.9, -0.8, 0.0), yaw_deg=-20)
    P.shot(cam, os.path.join(OUT, "GasPumpV3.png"), (0, 0, 3.6), (-0.75, -1.25, 0.35), 15.5)
    P.shot(cam, os.path.join(OUT, "GasPumpV3_front.png"), (0, 0, 3.8), (0.0, -1.0, 0.12), 13.0)
    P.shot(cam, os.path.join(OUT, "GasPumpV3_pump.png"), (0.3, -0.2, 4.8), (0.6, -1.0, 0.2), 6.0)
    P.shot(cam, os.path.join(OUT, "GasPumpV3_side.png"), (0, 0, 3.6), (-1.0, -0.35, 0.2), 13.0)
    P.night(world, sun, (1.5, -5.0, 9.0), energy=90)
    P.shot(cam, os.path.join(OUT, "GasPumpV3_night.png"), (0, 0, 3.6), (-0.6, -1.3, 0.3), 15.0)


preview()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "gas_pump_v3.blend"))
P.log("done")
