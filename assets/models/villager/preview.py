# Review renders of the villager body (Workbench): parts in colour + wireframe, close-ups, next to the old body.
#   blender -b --factory-startup --python preview.py -- <out_dir>
# Writes <out_dir>/body_v1_overview.png, body_v1_closeups.png, report.txt. Nothing is saved into .blend files.
import bpy, sys, os, math, traceback
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.dirname(HERE)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(HERE, "design"); os.makedirs(OUT, exist_ok=True)
CHAR = "female" if "female" in argv[1:] else "male"
OLD = {"male": "human_base", "female": "human_female"}[CHAR]
BG = (0.42, 0.43, 0.45)
COL = [(0.93, 0.66, 0.48), (0.33, 0.50, 0.80), (0.38, 0.66, 0.42)]     # head / upper / lower
log = []

def flat(name, rgb):
    m = bpy.data.materials.new(name); m.diffuse_color = (*rgb, 1); return m

def wire_copy(ob):
    w = ob.copy(); w.data = ob.data.copy(); bpy.context.scene.collection.objects.link(w)
    w.data.materials.clear(); w.data.materials.append(flat("W", (0.04, 0.04, 0.05)))
    m = w.modifiers.new("wf", 'WIREFRAME'); m.thickness = 0.0014; m.use_replace = True; m.use_even_offset = False
    return w

def render(cam, tgt, d, ortho, res):
    sc = bpy.context.scene; sc.render.resolution_x, sc.render.resolution_y = res
    d = Vector(d).normalized(); cam.location = Vector(tgt) + d*6
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler(); cam.data.ortho_scale = ortho
    p = os.path.join(OUT, "_t.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(p); a = np.empty(im.size[0]*im.size[1]*4, np.float32); im.pixels.foreach_get(a)
    arr = a.reshape(im.size[1], im.size[0], 4).copy(); bpy.data.images.remove(im); os.remove(p); return arr

def save(arr, path):
    img = bpy.data.images.new("s", arr.shape[1], arr.shape[0]); img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = path; img.file_format = 'PNG'; img.save(); bpy.data.images.remove(img)

def pad(arr, h):
    if arr.shape[0] >= h: return arr
    p = np.ones((h - arr.shape[0], arr.shape[1], 4), np.float32); p[..., :3] = BG
    return np.concatenate([p, arr], 0)

try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ns = {"__name__": "villager_body", "__file__": os.path.join(HERE, "build_body.py"), "CHAR": CHAR}
    exec(compile(open(ns["__file__"], encoding="utf-8").read(), ns["__file__"], "exec"), ns)
    log.append(str(ns["REPORT"]))
    body = bpy.data.objects["Body"]; me = body.data
    for c in COL: me.materials.append(flat("P", c))
    part = me.attributes["part"].data
    for p in me.polygons: p.material_index = part[p.index].value
    wf = wire_copy(body)
    # old body for comparison (rest shape, grey), placed to the right
    with bpy.data.libraries.load(os.path.join(MODELS, OLD, OLD + ".blend")) as (src, dst):
        dst.objects = ["Body"]
    old = dst.objects[0]; old.name = "OldBody"; bpy.context.scene.collection.objects.link(old)
    for m in list(old.modifiers): old.modifiers.remove(m)
    old.parent = None; old.matrix_world = __import__("mathutils").Matrix.Translation((0, 0, 0))
    old.data = old.data.copy(); old.data.materials.clear(); old.data.materials.append(flat("Old", (0.70, 0.70, 0.70)))
    oldw = wire_copy(old)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading; sh.light = 'STUDIO'; sh.color_type = 'MATERIAL'; sh.show_shadows = False
    w = bpy.data.worlds.new("W"); sc.world = w; w.color = BG
    cam = bpy.data.objects.new("_cam", bpy.data.cameras.new("_cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.type = 'ORTHO'
    def show(objs):
        for o in (body, wf, old, oldw): o.hide_render = o not in objs
    H = max(v.co.z for v in me.vertices) + 0.02
    tiles = []
    show((body, wf))
    for d in ((0, -1, 0), (1, 0, 0), (0, 1, 0), (0.7, -0.7, 0.15)):
        tiles.append(render(cam, (0, 0, H*0.5), d, H*1.06, (330, 560)))
    show((old, oldw))
    for d in ((0, -1, 0), (1, 0, 0)):
        tiles.append(render(cam, (0, 0, H*0.5), d, H*1.06, (330, 560)))
    save(np.concatenate(tiles, 1), os.path.join(OUT, f"body_v1_{CHAR}_overview.png"))
    # close-ups: head (new front / side / 3-4, old front), hand, shoe
    show((body, wf))
    hc = Vector((0, 0.0, H - 0.17*ns["C"]["scale"]))
    cl = [render(cam, hc, d, 0.40, (330, 330)) for d in ((0, -1, 0), (1, 0, 0), (0.7, -0.7, 0.1))]
    show((old, oldw)); cl.append(render(cam, hc, (0, -1, 0), 0.40, (330, 330)))
    show((body, wf))
    sc_ = ns["C"]["scale"]; d0 = math.radians(42)
    W = (Vector((ns["SHO"][0], 0, ns["SHO"][1])) + Vector((math.cos(d0), 0, -math.sin(d0)))*0.60)*sc_
    cl.append(render(cam, W, (0.25, -0.15, 1.0), 0.24, (330, 330)))
    cl.append(render(cam, Vector((ns["C"]["foot_x"], -0.07, 0.07))*sc_, (1, -0.35, 0.25), 0.36, (330, 330)))
    save(np.concatenate(cl, 1), os.path.join(OUT, f"body_v1_{CHAR}_closeups.png"))
    log.append("ok")
except Exception:
    log.append(traceback.format_exc())
open(os.path.join(OUT, "report.txt"), "w", encoding="utf-8").write("\n".join(log))
print("\n".join(log))
