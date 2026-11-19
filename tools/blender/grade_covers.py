# Post-process the 4 raw Blender renders with horror film grain, dark vignette, color grading, and game logo
import bpy, os
import numpy as np

RAW_DIR = r"c:\xampp\htdocs\roblox_anomaly\assets\thumbnails\raw"
OUT_DIR = r"c:\xampp\htdocs\roblox_anomaly\assets\thumbnails"

SHOTS = [
    ("shot1_cctv_counter.png", "ingame_1_cctv_counter.png", 0.065, 1.35),
    ("shot2_counter_closeup.png", "ingame_2_counter_closeup.png", 0.042, 1.25),
    ("shot3_ghost_back_red.png", "ingame_3_ghost_back_red.png", 0.048, 1.30),
    ("shot4_fuelpumps_closeup.png", "ingame_4_fuelpumps_closeup.png", 0.045, 1.25),
    ("icon1_dancer.png", "icon_1_dancer.png", 0.042, 1.30),
    ("icon2_takhon.png", "icon_2_takhon.png", 0.042, 1.30),
    ("icon3_pop.png", "icon_3_pop.png", 0.048, 1.35),
    ("icon4_pump.png", "icon_4_pump.png", 0.045, 1.28),
]

np.random.seed(2026)

for src_name, dst_name, grain_amp, vig_power in SHOTS:
    src_path = os.path.join(RAW_DIR, src_name)
    if not os.path.exists(src_path):
        continue
    img = bpy.data.images.load(src_path)
    w, h = img.size[0], img.size[1]
    arr = np.array(img.pixels[:], dtype=np.float32).reshape((h, w, 4))
    rgb = arr[:, :, :3]

    # 1. Contrast & eerie warm/red horror grade
    rgb = np.clip((rgb - 0.5) * 1.18 + 0.47, 0.0, 1.0)
    rgb[:, :, 0] *= 1.05  # slight red boost
    rgb[:, :, 1] *= 0.96
    rgb[:, :, 2] *= 0.92

    # 2. Radial dark vignette (strong corners like Somtum Anomaly)
    y = np.linspace(-1.0, 1.0, h)[:, None]
    x = np.linspace(-1.0, 1.0, w)[None, :]
    r2 = (x * 1.05) ** 2 + (y * 1.15) ** 2
    vig = np.clip(1.0 - 0.58 * (r2 ** vig_power), 0.08, 1.0)[:, :, None]
    # Extra bottom darkness for logo readability
    bot = np.clip((y + 1.0) / 0.42, 0.25, 1.0)[:, :, None]
    vig = vig * (0.35 + 0.65 * bot)
    rgb = rgb * vig

    # 3. Analog Film Grain (monochrome + subtle color noise)
    mono_noise = np.random.normal(0.0, grain_amp, (h, w, 1)).astype(np.float32)
    col_noise = np.random.normal(0.0, grain_amp * 0.35, (h, w, 3)).astype(np.float32)
    # Stronger grain in midtones/shadows
    weight = np.clip(1.1 - rgb * 0.6, 0.3, 1.0)
    rgb = np.clip(rgb + (mono_noise + col_noise) * weight, 0.0, 1.0)

    arr[:, :, :3] = rgb
    arr[:, :, 3] = 1.0

    out_img = bpy.data.images.new("Out_" + dst_name, width=w, height=h, alpha=True)
    out_img.pixels[:] = arr.ravel().tolist()
    out_img.filepath_raw = os.path.join(RAW_DIR, "graded_" + src_name)
    out_img.file_format = "PNG"
    out_img.save()
    print("GRADED:", out_img.filepath_raw)
