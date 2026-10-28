#!/usr/bin/env python3
"""
tools/audio/generate_sounds.py
สังเคราะห์ชุดไฟล์เสียง (Procedural Audio Synthesis) สำหรับเกม "ปั๊มหลอดท้ายทุ่ง"
ออกแบบพิเศษให้ **ไม่แสบหู (Warm Low-Pass Filtered, Soft-Clipped, No Harsh Highs > 3.2kHz)**

สร้างไฟล์ .wav (44.1kHz, 16-bit Stereo/Mono) ลงในโฟลเดอร์ assets/sounds/ครบทุกหมวด:
1. อุปกรณ์ในปั๊ม & ร้านค้า (Gameplay SFX)
   - sfx_pump_crank_loop.wav      : เสียงหมุนมือหมุนตู้ปั๊มน้ำมันหลอดแก้ว (เฟืองเหล็กเก่า + น้ำมันไหลลงหลอด)
   - sfx_fuel_glug_loop.wav       : เสียงน้ำมันไหลเข้าถังรถ булькаๆ นุ่มๆ
   - sfx_shutter_close_slam.wav   : เสียงดึงเชือกปิดแผงสังกะสีหน้าร้านดังโครม (ทุ้มลึก ไม่บาดหู)
   - sfx_shutter_open_pull.wav    : เสียงดึงรอกเปิดแผงสังกะสีขึ้น
   - sfx_coin_tin_drop_1.wav      : เสียงโยนเหรียญ/แบงก์ลงกระป๋องสังกะสี (แบบที่ 1)
   - sfx_coin_tin_drop_2.wav      : เสียงโยนเหรียญลงกระป๋องสังกะสี (แบบที่ 2)
   - sfx_incense_extinguish.wav   : เสียงธูปดับ (ฟู่เบาๆ + เสียงระฆังวัดทุ้มต่ำสะท้อน)
   - sfx_moto_approach_idle.wav   : เสียงรถมอเตอร์ไซค์ 4 จังหวะเก่าๆ ขี่มาจอดและเดินเบา
   - sfx_pickup_diesel_idle.wav   : เสียงเครื่องรถกระบะดีเซลเก่าเดินเบา

2. เสียงหลอกผู้เล่น (Prank / Haunt 3D & Binaural Sounds - นุ่มลึก ขนลุก ไม่แสบหู)
   - haunt_breath_neck_left.wav   : เสียงหายใจรดต้นคอข้างซ้าย (Binaural ใกล้หูซ้ายมาก)
   - haunt_breath_neck_right.wav  : เสียงหายใจรดต้นคอข้างขวา (Binaural ใกล้หูขวามาก)
   - haunt_breath_behind_slow.wav : เสียงถอนหายใจยาวๆ เย็นๆ ข้างหลังคอ
   - haunt_walk_dirt_circle.wav   : เสียงเดินย่ำดินลูกรัง/ใบไม้แห้งวนรอบร้านช้าๆ (แพนซ้าย->หลัง->ขวา)
   - haunt_walk_dirt_hurry.wav    : เสียงฝีเท้าวิ่งย่ำดินเข้ามาใกล้แล้วหยุดกึก
   - haunt_walk_shop_wood_1.wav   : เสียงเดินไปมาบนพื้นไม้/แคร่ในร้าน (เอี๊ยดอ๊าดช้าๆ)
   - haunt_walk_shop_wood_2.wav   : เสียงก้าวเดินลากเท้าในเพิงสังกะสี
   - haunt_roof_tin_steps.wav     : เสียงอะไรบางอย่างเดินย่ำบนหลังคาสังกะสีเหนือหัว
   - haunt_climb_tree_1.wav       : เสียงตะกายเปลือกไม้/ปีนขึ้นต้นไทรใหญ่ + กิ่งไม้สั่นใบไม้ร่วง
   - haunt_climb_tree_2.wav       : เสียงขูดเปลือกไม้และกระโดดลงจากกิ่งไม้ข้างดงกล้วย

3. เพลงวิทยุทรานซิสเตอร์ AM ลูกทุ่งเหงาๆ หลอนๆ (Eerie Vintage Thai Luk Thung Radio Loops)
   - radio_lukthung_1_lamnam_thung_mued.wav : เพลง "ลำนำทุ่งมืด" (ขลุ่ยเพียงออโหยหวน + พิณโปร่งช้าๆ + คลื่น AM ซ่านุ่มๆ)
   - radio_lukthung_2_khlui_sao_tai_sai.wav : เพลง "ขลุ่ยเศร้าใต้ต้นไทร" (ซอด้วง/ขลุ่ยเอื้อนลูกคอ + เบสลูกทุ่งโบราณ + ฉิ่งช้าๆ)
   - radio_lukthung_3_winyan_rak_nak_leng.wav: เพลง "วิญญาณรักท้ายทุ่ง" (กีตาร์ลูกทุ่งยุค 70s Tremolo เหงาๆ + ออร์แกนวัดหลอนๆ)
   - radio_lukthung_4_klom_khuen_duean_dap.wav: เพลง "กล่อมคืนเดือนดับ" (เพลงกล่อมเด็กชนบทไทยเพี้ยนคลื่นวิทยุ ยืดช้าลงช่วงท้าย)
   - radio_lukthung_5_am_detuned_ghost.wav  : คลื่นวิทยุลูกทุ่งหมุนหาคลื่นกลางดึก (เสียงดนตรีไทยโบราณลอยมาสลับเสียงซ่า低-pass)
"""

import math
import os
import random
import struct
import wave
from array import array

SR = 44100
TWO_PI = 2.0 * math.pi
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "sounds")


def make_buf(duration_sec: float) -> array:
    n = int(SR * duration_sec)
    return array("f", [0.0]) * n


def lowpass_1pole(buf: array, cutoff_hz: float) -> array:
    """One-pole IIR low-pass filter to remove any harsh high frequencies."""
    rc = 1.0 / (TWO_PI * max(20.0, cutoff_hz))
    dt = 1.0 / SR
    alpha = dt / (rc + dt)
    out = array("f", [0.0]) * len(buf)
    y = 0.0
    for i, x in enumerate(buf):
        y = y + alpha * (x - y)
        out[i] = y
    return out


def highpass_1pole(buf: array, cutoff_hz: float) -> array:
    """One-pole IIR high-pass filter to remove DC / excessive sub-bass rumble."""
    rc = 1.0 / (TWO_PI * max(5.0, cutoff_hz))
    dt = 1.0 / SR
    alpha = rc / (rc + dt)
    out = array("f", [0.0]) * len(buf)
    y = 0.0
    prev_x = 0.0
    for i, x in enumerate(buf):
        y = alpha * (y + x - prev_x)
        prev_x = x
        out[i] = y
    return out


def bandpass(buf: array, low_hz: float, high_hz: float) -> array:
    return lowpass_1pole(highpass_1pole(buf, low_hz), high_hz)


def add_reverb(buf: array, decay: float = 0.38, wet: float = 0.28) -> array:
    """Warm Schroeder-style comb + allpass reverb for rural night depth."""
    n = len(buf)
    out = array("f", buf)
    delays = [int(SR * 0.029), int(SR * 0.037), int(SR * 0.043), int(SR * 0.053)]
    wet_buf = array("f", [0.0]) * n
    for d in delays:
        comb = array("f", [0.0]) * n
        g = decay
        lp = 0.0
        for i in range(n):
            x = buf[i]
            prev = comb[i - d] if i >= d else 0.0
            lp = 0.65 * prev + 0.35 * lp  # damped high frequencies in tail
            comb[i] = x + g * lp
            wet_buf[i] += comb[i] * 0.25
    for i in range(n):
        out[i] = buf[i] * (1.0 - wet) + wet_buf[i] * wet
    return out


def soft_save_wav(filename: str, left: array, right: array = None, max_peak: float = 0.72, lp_cutoff: float = 2900.0):
    """
    Applies a final warm low-pass filter, soft-clipping (tanh), fade in/out,
    and saves as 16-bit PCM WAV. Guaranteed non-piercing!
    """
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, filename)

    left = lowpass_1pole(left, lp_cutoff)
    if right is not None:
        right = lowpass_1pole(right, lp_cutoff)

    n = len(left)
    fade = min(int(SR * 0.04), n // 10)

    # Find peak for gentle normalization
    peak = 1e-6
    for i in range(n):
        v = abs(left[i])
        if v > peak:
            peak = v
        if right is not None:
            vr = abs(right[i])
            if vr > peak:
                peak = vr

    scale = max_peak / max(peak, 0.05)

    with wave.open(path, "wb") as wf:
        channels = 2 if right is not None else 1
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(SR)

        pcm = array("h")
        for i in range(n):
            env = 1.0
            if i < fade:
                env = i / float(fade)
            elif i > n - fade:
                env = (n - i) / float(fade)

            vl = math.tanh(left[i] * scale * env) * 0.92
            sl = int(max(-32767, min(32767, vl * 32767.0)))
            pcm.append(sl)

            if right is not None:
                vr = math.tanh(right[i] * scale * env) * 0.92
                sr_val = int(max(-32767, min(32767, vr * 32767.0)))
                pcm.append(sr_val)

        wf.writeframes(pcm.tobytes())
    print(f"  [OK] {filename} ({n / SR:.1f}s, {channels}ch)")


def add_grain(buf: array, t_start: float, dur: float, freq: float, amp: float, decay_rate: float = 12.0):
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    phase = random.random() * TWO_PI
    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        env = math.sin(math.pi * min(1.0, dt / max(0.005, dur))) * math.exp(-dt * decay_rate)
        buf[i] += math.sin(phase + TWO_PI * freq * dt) * amp * env


# ==============================================================================
# 1. GAMEPLAY SFX (ปั๊มหลอด, แผงสังกะสี, กระป๋องเงิน, ธูป, รถ)
# ==============================================================================

def gen_pump_crank():
    """เสียงหมุนมือหมุนตู้ปั๊มน้ำมันหลอดแก้ว + น้ำมันไหลลงหลอด (3.2s loop)"""
    dur = 3.2
    buf = make_buf(dur)
    rng = random.Random(101)
    # 4 crank rotations (0.8s per turn)
    for turn in range(4):
        t0 = turn * 0.8
        # Ratchet clicks (10 soft wooden/iron gear clicks per turn)
        for c in range(10):
            tc = t0 + c * 0.075 + rng.uniform(-0.004, 0.004)
            add_grain(buf, tc, 0.045, 210 + (c % 3) * 35, 0.35, 35.0)
            add_grain(buf, tc, 0.030, 420 + (c % 2) * 50, 0.18, 45.0)
        # Warm low metallic crank groan per turn
        i0 = int(t0 * SR)
        for i in range(i0, min(len(buf), i0 + int(0.65 * SR))):
            dt = (i - i0) / float(SR)
            env = math.sin(math.pi * dt / 0.65)
            f = 115.0 + 22.0 * math.sin(TWO_PI * 1.5 * dt)
            buf[i] += (math.sin(TWO_PI * f * dt) * 0.22 + math.sin(TWO_PI * f * 2.02 * dt) * 0.09) * env

    # Continuous gentle liquid slosh inside glass jar
    liquid = make_buf(dur)
    for i in range(len(liquid)):
        t = i / float(SR)
        bubble_mod = 0.5 + 0.5 * math.sin(TWO_PI * 5.5 * t + math.sin(TWO_PI * 2.1 * t))
        liquid[i] = (rng.uniform(-1, 1) * 0.15) * bubble_mod
    liquid = bandpass(liquid, 250.0, 950.0)
    for i in range(len(buf)):
        buf[i] += liquid[i]

    soft_save_wav("sfx_pump_crank_loop.wav", buf, max_peak=0.65, lp_cutoff=2200.0)


def gen_fuel_glug():
    """เสียงน้ำมันไหลเข้าถังรถ บุ๋งๆ นุ่มๆ (2.5s loop)"""
    dur = 2.5
    buf = make_buf(dur)
    rng = random.Random(102)
    t = 0.05
    while t < dur - 0.12:
        f_base = rng.uniform(260.0, 440.0)
        i0 = int(t * SR)
        g_dur = rng.uniform(0.07, 0.12)
        for i in range(i0, min(len(buf), i0 + int(g_dur * SR))):
            dt = (i - i0) / float(SR)
            # Pitch rises slightly as air bubble escapes
            f = f_base * (1.0 + 0.45 * (dt / g_dur))
            env = math.sin(math.pi * (dt / g_dur))
            buf[i] += math.sin(TWO_PI * f * dt) * 0.45 * env
        t += rng.uniform(0.08, 0.14)
    buf = add_reverb(buf, decay=0.25, wet=0.2)
    soft_save_wav("sfx_fuel_glug_loop.wav", buf, max_peak=0.60, lp_cutoff=1800.0)


def gen_shutter_sounds():
    """เสียงดึงเชือกปิดแผงสังกะสีหน้าร้าน (โครมทุ้มๆ) และเสียงเปิดแผงสังกะสี"""
    # 1. Close slam (1.4s)
    dur = 1.4
    buf = make_buf(dur)
    rng = random.Random(103)
    # Rope pulley slide (0.0 -> 0.42s)
    for i in range(int(0.42 * SR)):
        t = i / float(SR)
        env = t / 0.42
        buf[i] += rng.uniform(-1, 1) * 0.25 * env
        buf[i] += math.sin(TWO_PI * (140 + 90 * t) * t) * 0.2 * env
    buf = lowpass_1pole(buf, 1200.0)

    # Heavy corrugated tin + wood frame impact at 0.42s + 2 small bounces
    impacts = [(0.42, 1.0), (0.64, 0.42), (0.79, 0.18)]
    for t_imp, amp in impacts:
        # Low wood thud + warm tin wobble modes
        modes = [68.0, 112.0, 178.0, 245.0, 330.0, 465.0]
        for m_idx, mf in enumerate(modes):
            add_grain(buf, t_imp, 0.45, mf, amp * (0.45 / (1 + m_idx * 0.4)), decay_rate=6.5 + m_idx * 2.0)

    buf = add_reverb(buf, decay=0.35, wet=0.25)
    soft_save_wav("sfx_shutter_close_slam.wav", buf, max_peak=0.72, lp_cutoff=1900.0)

    # 2. Open pull (1.1s)
    buf_open = make_buf(1.1)
    for i in range(int(0.85 * SR)):
        t = i / float(SR)
        env = math.sin(math.pi * t / 0.85)
        wobble = math.sin(TWO_PI * 7.5 * t) * 18.0
        buf_open[i] += math.sin(TWO_PI * (155.0 + wobble) * t) * 0.25 * env
        buf_open[i] += rng.uniform(-1, 1) * 0.12 * env
    add_grain(buf_open, 0.82, 0.22, 135.0, 0.4, decay_rate=12.0)
    add_grain(buf_open, 0.82, 0.18, 260.0, 0.25, decay_rate=16.0)
    soft_save_wav("sfx_shutter_open_pull.wav", buf_open, max_peak=0.60, lp_cutoff=1600.0)


def gen_coin_tin_and_incense():
    """เสียงเหรียญลงกระป๋องสังกะสี (ไม่แหลม) และเสียงธูปดับ"""
    for variant, seed in [(1, 201), (2, 202)]:
        rng = random.Random(seed)
        buf = make_buf(0.9)
        hits = [0.04, 0.13, 0.21, 0.27] if variant == 1 else [0.05, 0.16, 0.24]
        for idx, th in enumerate(hits):
            amp = 0.5 / (1.0 + idx * 0.45)
            # Warm tin body resonance + soft coin clink (capped under 1800Hz)
            add_grain(buf, th, 0.18, 380.0 + rng.uniform(-25, 25), amp * 0.7, 16.0)
            add_grain(buf, th, 0.14, 740.0 + rng.uniform(-40, 40), amp * 0.6, 22.0)
            add_grain(buf, th, 0.09, 1280.0 + rng.uniform(-60, 60), amp * 0.4, 30.0)
        buf = add_reverb(buf, decay=0.25, wet=0.2)
        soft_save_wav(f"sfx_coin_tin_drop_{variant}.wav", buf, max_peak=0.58, lp_cutoff=2100.0)

    # Incense extinguish: soft ash hiss + deep ominous temple bell toll
    dur = 2.4
    buf = make_buf(dur)
    rng = random.Random(205)
    # Soft hiss (0.0 -> 0.5s)
    hiss = make_buf(dur)
    for i in range(int(0.55 * SR)):
        t = i / float(SR)
        env = math.sin(math.pi * t / 0.55) * math.exp(-t * 4.0)
        hiss[i] = rng.uniform(-1, 1) * 0.35 * env
    hiss = bandpass(hiss, 300.0, 1400.0)
    # Deep ominous bronze gong/bell (146.8 Hz D3 + 220 Hz A3 + 293.6 Hz D4)
    for i in range(len(buf)):
        t = i / float(SR)
        env = math.exp(-t * 1.8) * min(1.0, t / 0.03)
        bell = (
            math.sin(TWO_PI * 146.8 * t) * 0.45
            + math.sin(TWO_PI * 220.0 * t + 0.3 * math.sin(TWO_PI * 3.2 * t)) * 0.28
            + math.sin(TWO_PI * 293.6 * t) * 0.15
            + math.sin(TWO_PI * 415.3 * t) * 0.08 * math.exp(-t * 3.5)
        )
        buf[i] = hiss[i] + bell * env
    buf = add_reverb(buf, decay=0.5, wet=0.35)
    soft_save_wav("sfx_incense_extinguish.wav", buf, max_peak=0.68, lp_cutoff=1800.0)


def gen_vehicle_idles():
    """เสียงรถมอเตอร์ไซค์ชาวบ้าน และ รถกระบะดีเซลเก่าเดินเบา"""
    # 1. Old 4-stroke rural motorcycle idle loop (3.0s)
    dur = 3.0
    buf = make_buf(dur)
    rng = random.Random(301)
    # ~13.5 firing strokes per second (warm low pop-pop-pop)
    t = 0.0
    while t < dur:
        add_grain(buf, t, 0.055, 78.0 + rng.uniform(-4, 4), 0.55, 28.0)
        add_grain(buf, t, 0.040, 156.0 + rng.uniform(-8, 8), 0.32, 35.0)
        add_grain(buf, t + 0.012, 0.025, 310.0, 0.14, 45.0)
        t += 0.074 + rng.uniform(-0.002, 0.002)
    soft_save_wav("sfx_moto_approach_idle.wav", buf, max_peak=0.62, lp_cutoff=1400.0)

    # 2. Old diesel pickup idle loop (3.0s)
    buf_d = make_buf(dur)
    t = 0.0
    while t < dur:
        add_grain(buf_d, t, 0.048, 62.0 + rng.uniform(-2, 2), 0.55, 25.0)
        add_grain(buf_d, t, 0.035, 124.0 + rng.uniform(-5, 5), 0.35, 32.0)
        add_grain(buf_d, t + 0.008, 0.022, 420.0 + rng.uniform(-15, 15), 0.20, 50.0)  # soft diesel knock
        t += 0.052 + rng.uniform(-0.0015, 0.0015)
    soft_save_wav("sfx_pickup_diesel_idle.wav", buf_d, max_peak=0.62, lp_cutoff=1500.0)


# ==============================================================================
# 2. HAUNT / PRANK SOUNDS (เสียงหลอกผู้เล่น: หายใจรดต้นคอ, เดินบนดินรอบร้าน, เดินในร้าน, ปีนต้นไม้)
# ==============================================================================

def synth_breath_cycle(rng: random.Random, dur: float, pitch_scale: float = 1.0) -> array:
    """สร้างเสียงลมหายใจเข้า-ออกลึกๆ นุ่มๆ เหมือนคนยืนชิดหลังคอ (Formant-filtered warm air)"""
    raw = make_buf(dur)
    in_end = dur * 0.42
    pause_end = dur * 0.50
    for i in range(len(raw)):
        t = i / float(SR)
        if t < in_end:
            # Inhale
            u = t / in_end
            env = math.sin(math.pi * u) ** 1.4 * 0.65
            voicing = math.sin(TWO_PI * 135.0 * pitch_scale * t) * 0.08 * env
        elif t < pause_end:
            env = 0.0
            voicing = 0.0
        else:
            # Exhale (warmer, heavier right on the neck)
            u = (t - pause_end) / (dur - pause_end)
            env = (math.sin(math.pi * u) ** 1.1) * math.exp(-u * 0.8) * 0.95
            f_sigh = (165.0 - 35.0 * u) * pitch_scale
            voicing = (
                math.sin(TWO_PI * f_sigh * t) * 0.16
                + math.sin(TWO_PI * f_sigh * 2.0 * t) * 0.07
            ) * env
        noise = rng.uniform(-1.0, 1.0) * env
        raw[i] = noise + voicing

    # Warm throat/mouth formants (250Hz - 1150Hz, zero piercing sibilance)
    chest = bandpass(raw, 140.0, 480.0)
    throat = bandpass(raw, 450.0, 1150.0)
    out = make_buf(dur)
    for i in range(len(out)):
        out[i] = chest[i] * 0.65 + throat[i] * 0.45
    return out


def gen_breathing_neck():
    """เสียงหายใจใกล้ๆ คอ 3 แบบ (ซ้ายชิดคอ, ขวาชิดคอ, ถอนหายใจข้างหลัง)"""
    rng = random.Random(401)
    # 1. Left neck (2 breaths, 4.6s)
    b1 = synth_breath_cycle(rng, 2.2, 0.96)
    b2 = synth_breath_cycle(rng, 2.4, 0.92)
    mono = b1 + b2
    left = array("f", [x * 1.0 for x in mono])
    # Right ear gets delayed, darker signal (head shadow binaural effect)
    right_raw = array("f", [0.0] * 28 + [x * 0.26 for x in mono[:-28]])
    right = lowpass_1pole(right_raw, 650.0)
    soft_save_wav("haunt_breath_neck_left.wav", left, right, max_peak=0.62, lp_cutoff=1350.0)

    # 2. Right neck (2 breaths, 4.6s)
    b3 = synth_breath_cycle(rng, 2.3, 1.02)
    b4 = synth_breath_cycle(rng, 2.3, 0.95)
    mono_r = b3 + b4
    right2 = array("f", [x * 1.0 for x in mono_r])
    left2_raw = array("f", [0.0] * 28 + [x * 0.26 for x in mono_r[:-28]])
    left2 = lowpass_1pole(left2_raw, 650.0)
    soft_save_wav("haunt_breath_neck_right.wav", left2, right2, max_peak=0.62, lp_cutoff=1350.0)

    # 3. Slow cold sigh right behind neck (centered binaural, 3.8s)
    sigh = synth_breath_cycle(rng, 3.8, 0.85)
    sigh = add_reverb(sigh, decay=0.35, wet=0.22)
    soft_save_wav("haunt_breath_behind_slow.wav", sigh, sigh, max_peak=0.60, lp_cutoff=1250.0)


def add_dirt_step(left: array, right: array, t_step: float, pan: float, amp: float, rng: random.Random):
    """
    1 ก้าวเดินย่ำดินลูกรังและใบไม้แห้ง (pan: -1.0 ซ้ายสุด .. +1.0 ขวาสุด)
    ประกอบด้วย: ส้นเท้าลงดินทุ้มๆ + เม็ดกรวด/ใบไม้แห้งกรอบแกรบแบบนุ่มๆ
    """
    l_gain = math.cos((pan + 1.0) * math.pi * 0.25) * amp
    r_gain = math.sin((pan + 1.0) * math.pi * 0.25) * amp

    i0 = int(t_step * SR)
    dur = 0.26
    n = int(dur * SR)
    step_buf = make_buf(dur)

    # Heel thud (low earth resonance 85-130 Hz)
    f_heel = rng.uniform(82.0, 118.0)
    for i in range(min(n, int(0.11 * SR))):
        dt = i / float(SR)
        env = math.sin(math.pi * dt / 0.11) * math.exp(-dt * 24.0)
        step_buf[i] += math.sin(TWO_PI * f_heel * dt) * 0.65 * env

    # Gravel & dry banana leaf crunch (micro-impulses filtered 280 - 1500 Hz)
    crunch = make_buf(dur)
    for i in range(n):
        dt = i / float(SR)
        # Two-part envelope: heel (0..0.09) + toe roll (0.09..0.24)
        env = (
            math.exp(-((dt - 0.04) / 0.035) ** 2) * 0.8
            + math.exp(-((dt - 0.13) / 0.055) ** 2) * 0.6
        )
        if rng.random() < 0.35:
            crunch[i] = rng.uniform(-1.0, 1.0) * env
    crunch = bandpass(crunch, 260.0, 1450.0)

    for i in range(n):
        idx = i0 + i
        if 0 <= idx < len(left):
            v = step_buf[i] + crunch[i] * 0.85
            left[idx] += v * l_gain
            right[idx] += v * r_gain


def gen_footsteps_dirt():
    """เสียงเดินบนดินรอบร้าน (เดินวนช้าๆ รอบตัว + วิ่งเข้ามาใกล้แล้วหยุดกึก)"""
    # 1. Slow circling footsteps on dirt/leaves around the shop (6.5s)
    dur = 6.5
    left = make_buf(dur)
    right = make_buf(dur)
    rng = random.Random(501)
    t = 0.35
    step_idx = 0
    while t < dur - 0.4:
        # Pan moves smoothly from left (-0.85) -> behind (0.0) -> right (+0.85)
        u = t / dur
        pan = math.sin((u - 0.5) * math.pi * 0.9)
        dist_amp = 0.55 + 0.35 * math.sin(math.pi * u)
        add_dirt_step(left, right, t, pan, dist_amp, rng)
        step_idx += 1
        t += rng.uniform(0.68, 0.82)
    left = add_reverb(left, decay=0.28, wet=0.18)
    right = add_reverb(right, decay=0.28, wet=0.18)
    soft_save_wav("haunt_walk_dirt_circle.wav", left, right, max_peak=0.65, lp_cutoff=1650.0)

    # 2. Hurried steps approaching from the dark road and stopping abruptly behind player (3.8s)
    dur2 = 3.8
    left2 = make_buf(dur2)
    right2 = make_buf(dur2)
    t = 0.25
    step_num = 0
    while t < 2.95:
        u = t / 2.95
        amp = 0.22 + 0.78 * (u ** 1.5)  # gets louder as it approaches!
        pan = 0.25 * math.sin(step_num * 1.1) * (1.0 - u * 0.5)
        add_dirt_step(left2, right2, t, pan, amp, rng)
        step_num += 1
        t += max(0.27, 0.46 - 0.16 * u)
    left2 = add_reverb(left2, decay=0.25, wet=0.16)
    right2 = add_reverb(right2, decay=0.25, wet=0.16)
    soft_save_wav("haunt_walk_dirt_hurry.wav", left2, right2, max_peak=0.68, lp_cutoff=1700.0)


def add_wood_creak(buf: array, t_start: float, dur: float, base_f: float, amp: float, rng: random.Random):
    """เสียงไม้กระดาน/แคร่ไม้ไผ่ลั่นเอี๊ยดอ๊าดแบบอบอุ่น (Slip-stick wood resonance)"""
    i0 = int(t_start * SR)
    n = int(dur * SR)
    for i in range(n):
        idx = i0 + i
        if idx >= len(buf):
            break
        dt = i / float(SR)
        u = dt / dur
        env = math.sin(math.pi * u)
        # Stick-slip pulse rate slows down in the middle of the creak
        pulse_rate = 18.0 + 28.0 * math.sin(math.pi * u)
        stick = math.sin(TWO_PI * pulse_rate * dt)
        f1 = base_f * (1.0 + 0.08 * stick)
        f2 = base_f * 1.92 * (1.0 + 0.06 * stick)
        val = (math.sin(TWO_PI * f1 * dt) * 0.65 + math.sin(TWO_PI * f2 * dt) * 0.35) * (0.55 + 0.45 * stick)
        buf[idx] += val * amp * env


def gen_walk_in_shop_and_roof():
    """เสียงเดินไปมาในร้าน (พื้นไม้กระดาน/แคร่ลั่น + ลากเท้า + เสียงเดินบนหลังคาสังกะสี)"""
    rng = random.Random(601)
    # 1. Pacing back and forth on wooden shack floor (5.5s stereo)
    dur = 5.5
    left = make_buf(dur)
    right = make_buf(dur)
    steps = [
        (0.40, -0.6, 210.0),
        (1.15, -0.2, 245.0),
        (1.95, 0.25, 195.0),
        (2.80, 0.65, 230.0),
        (3.75, 0.20, 260.0),
        (4.55, -0.35, 205.0),
    ]
    for ts, pan, creak_f in steps:
        lg = math.cos((pan + 1.0) * math.pi * 0.25)
        rg = math.sin((pan + 1.0) * math.pi * 0.25)
        temp = make_buf(dur)
        # Hollow wood board thud
        add_grain(temp, ts, 0.16, 95.0 + rng.uniform(-8, 8), 0.55, 18.0)
        add_grain(temp, ts, 0.12, 185.0 + rng.uniform(-12, 12), 0.35, 24.0)
        # Bamboo/plank creak right after weight settles
        add_wood_creak(temp, ts + 0.05, rng.uniform(0.32, 0.48), creak_f, 0.32, rng)
        for i in range(len(temp)):
            left[i] += temp[i] * lg
            right[i] += temp[i] * rg

    left = add_reverb(left, decay=0.32, wet=0.22)
    right = add_reverb(right, decay=0.32, wet=0.22)
    soft_save_wav("haunt_walk_shop_wood_1.wav", left, right, max_peak=0.64, lp_cutoff=1550.0)

    # 2. Dragging barefoot/slipper steps inside shack + bottle/tin rattle (4.5s)
    dur2 = 4.5
    buf2 = make_buf(dur2)
    drag_times = [0.35, 1.35, 2.45, 3.45]
    for td in drag_times:
        add_grain(buf2, td, 0.15, 88.0, 0.50, 20.0)
        # Soft foot drag across dusty wood (0.35s)
        i0 = int((td + 0.08) * SR)
        for i in range(int(0.35 * SR)):
            if i0 + i < len(buf2):
                dt = i / float(SR)
                env = math.sin(math.pi * dt / 0.35)
                buf2[i0 + i] += rng.uniform(-1, 1) * 0.22 * env
        add_wood_creak(buf2, td + 0.12, 0.30, rng.uniform(190.0, 250.0), 0.28, rng)
    buf2 = bandpass(buf2, 65.0, 1350.0)
    buf2 = add_reverb(buf2, decay=0.35, wet=0.25)
    soft_save_wav("haunt_walk_shop_wood_2.wav", buf2, buf2, max_peak=0.62, lp_cutoff=1450.0)

    # 3. Something walking/crawling on the corrugated tin roof overhead (4.8s)
    dur3 = 4.8
    left3 = make_buf(dur3)
    right3 = make_buf(dur3)
    roof_hits = [(0.35, -0.5), (1.05, -0.15), (1.85, 0.25), (2.75, 0.55), (3.65, 0.75)]
    for th, pan in roof_hits:
        lg = math.cos((pan + 1.0) * math.pi * 0.25)
        rg = math.sin((pan + 1.0) * math.pi * 0.25)
        tmp = make_buf(dur3)
        # Corrugated tin dull metallic flexing thud + rafter creak
        for mf, mamp in [(74.0, 0.55), (138.0, 0.40), (215.0, 0.28), (340.0, 0.18)]:
            add_grain(tmp, th, 0.32, mf + rng.uniform(-6, 6), mamp, 9.5)
        add_wood_creak(tmp, th + 0.06, 0.28, 175.0 + rng.uniform(-15, 15), 0.22, rng)
        for i in range(len(tmp)):
            left3[i] += tmp[i] * lg
            right3[i] += tmp[i] * rg
    left3 = add_reverb(left3, decay=0.38, wet=0.26)
    right3 = add_reverb(right3, decay=0.38, wet=0.26)
    soft_save_wav("haunt_roof_tin_steps.wav", left3, right3, max_peak=0.64, lp_cutoff=1400.0)


def gen_tree_climbing():
    """เสียงขึ้นต้นไม้ (ตะกายเปลือกไม้ + กิ่งไม้ลั่น + ใบไม้สั่นกราว) 2 แบบ"""
    rng = random.Random(701)
    for variant, dur in [(1, 5.2), (2, 4.6)]:
        buf = make_buf(dur)
        num_scrambles = 5 if variant == 1 else 4
        for s in range(num_scrambles):
            ts = 0.25 + s * (0.78 if variant == 1 else 0.85) + rng.uniform(-0.04, 0.04)
            # 1. Bark scrape / claw grip on tree trunk (bandpassed textured noise + hollow trunk thump)
            add_grain(buf, ts, 0.14, 105.0 + s * 12.0, 0.48, 18.0)
            i0 = int(ts * SR)
            scrape_dur = rng.uniform(0.22, 0.34)
            for i in range(int(scrape_dur * SR)):
                if i0 + i < len(buf):
                    dt = i / float(SR)
                    env = math.sin(math.pi * dt / scrape_dur)
                    buf[i0 + i] += rng.uniform(-1, 1) * 0.38 * env
            # 2. Branch bend & creak under weight
            if s % 2 == 1:
                add_wood_creak(buf, ts + 0.12, 0.42, 165.0 + rng.uniform(-20, 30), 0.35, rng)
                # Twig snap (warm mid-range pop, not sharp)
                add_grain(buf, ts + 0.22, 0.04, 520.0 + rng.uniform(-50, 50), 0.38, 45.0)

        # 3. Heavy foliage / Banyan & Banana leaf rustle bursts
        leaf_buf = make_buf(dur)
        rustle_times = [0.6, 1.8, 3.1, 4.1] if variant == 1 else [0.5, 1.9, 3.3]
        for tr in rustle_times:
            i0 = int(tr * SR)
            rdur = 0.75
            for i in range(int(rdur * SR)):
                if i0 + i < len(leaf_buf):
                    dt = i / float(SR)
                    flutter = 0.55 + 0.45 * math.sin(TWO_PI * 9.0 * dt)
                    env = math.sin(math.pi * dt / rdur) * flutter
                    leaf_buf[i0 + i] += rng.uniform(-1, 1) * 0.42 * env
        leaf_buf = bandpass(leaf_buf, 320.0, 1550.0)

        for i in range(len(buf)):
            buf[i] += leaf_buf[i]

        buf = bandpass(buf, 75.0, 1650.0)
        buf = add_reverb(buf, decay=0.35, wet=0.24)
        soft_save_wav(f"haunt_climb_tree_{variant}.wav", buf, max_peak=0.64, lp_cutoff=1650.0)


# ==============================================================================
# 3. VINTAGE THAI LUK THUNG RADIO SONGS (เพลงลูกทุ่งเก่าเหงาๆ หลอนๆ สำหรับวิทยุทรานซิสเตอร์)
# ==============================================================================

def midi_to_hz(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def add_khlui_note(
    buf: array,
    t_start: float,
    dur: float,
    midi_note: float,
    amp: float,
    vibrato_hz: float = 4.8,
    vibrato_semi: float = 0.22,
    slide_from_semi: float = 0.0,
    detune_drift: float = 0.0,
):
    """
    สังเคราะห์เสียง 'ขลุ่ยเพียงออ / ซอไทยโบราณ' เอื้อนลูกคอพริ้วๆ นุ่มลึก ไม่แสบหู
    """
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    phase = 0.0
    rng = random.Random(int(t_start * 1000) + int(midi_note))

    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        u = dt / max(0.01, dur)

        # Smooth envelope with gentle breath attack & release
        if dt < 0.09:
            env = math.sin(0.5 * math.pi * (dt / 0.09))
        elif dt > dur - 0.14:
            env = max(0.0, (dur - dt) / 0.14)
        else:
            env = 1.0 - 0.12 * u

        # Thai ornament: initial pitch slide (เอื้อน) + delayed vibrato (ลูกคอ) + tape warble
        slide = slide_from_semi * math.exp(-dt * 9.0)
        vib_env = min(1.0, max(0.0, (dt - 0.12) / 0.25))
        vib = math.sin(TWO_PI * vibrato_hz * dt) * vibrato_semi * vib_env
        tape_wow = math.sin(TWO_PI * 0.65 * (i / float(SR))) * detune_drift

        inst_note = midi_note + slide + vib + tape_wow
        freq = midi_to_hz(inst_note)
        phase += TWO_PI * freq / float(SR)

        # Warm flute/saw harmonics (fundamental + soft 2nd & 3rd) + gentle breath
        tone = (
            math.sin(phase) * 0.72
            + math.sin(phase * 2.0 + 0.4) * 0.19
            + math.sin(phase * 3.0 + 1.1) * 0.07
            + rng.uniform(-1.0, 1.0) * 0.035
        )
        buf[i] += tone * amp * env


def add_phin_pluck(buf: array, t_start: float, dur: float, midi_note: float, amp: float, tremolo: bool = False):
    """เสียงพิณโปร่ง / กีตาร์ลูกทุ่งเก่าๆ ดีดคลอเบาๆ"""
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    freq = midi_to_hz(midi_note)
    phase = 0.0
    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        env = math.exp(-dt * 3.4) * min(1.0, dt / 0.008)
        if tremolo:
            env *= 0.72 + 0.28 * math.sin(TWO_PI * 5.5 * dt)
        # Slightly detuned vintage string
        f_inst = freq * (1.0 + 0.0025 * math.sin(TWO_PI * 0.9 * (i / float(SR))))
        phase += TWO_PI * f_inst / float(SR)
        tone = (
            math.sin(phase) * 0.65
            + math.sin(phase * 2.0) * 0.24 * math.exp(-dt * 5.0)
            + math.sin(phase * 3.0) * 0.11 * math.exp(-dt * 8.0)
        )
        buf[i] += tone * amp * env


def add_lukthung_bass(buf: array, t_start: float, dur: float, midi_note: float, amp: float):
    """เสียงเบสลูกทุ่งยุควินเทจ นุ่มทุ้ม"""
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    freq = midi_to_hz(midi_note)
    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        env = math.exp(-dt * 2.6) * min(1.0, dt / 0.015)
        tone = math.sin(TWO_PI * freq * dt) * 0.75 + math.sin(TWO_PI * freq * 2.0 * dt) * 0.25
        buf[i] += tone * amp * env


def add_vintage_organ_chord(buf: array, t_start: float, dur: float, notes: list, amp: float, eerie_bend: float = 0.08):
    """เสียงออร์แกนลูกทุ่ง/งานวัดเก่าๆ สั่นเทรโมโลหลอนๆ"""
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    freqs = [midi_to_hz(m) for m in notes]
    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        t_abs = i / float(SR)
        env = math.sin(math.pi * min(1.0, dt / dur))
        trem = 0.75 + 0.25 * math.sin(TWO_PI * 5.2 * t_abs)
        wow = 1.0 + 0.004 * math.sin(TWO_PI * 0.55 * t_abs) * eerie_bend * 10.0
        s = 0.0
        for f in freqs:
            fw = f * wow
            s += math.sin(TWO_PI * fw * dt) * 0.6 + math.sin(TWO_PI * fw * 2.0 * dt) * 0.2
        buf[i] += (s / max(1, len(freqs))) * amp * env * trem


def apply_am_radio_vintage(buf: array, static_level: float = 0.035, seed: int = 900) -> array:
    """
    จำลองลำโพงวิทยุทรานซิสเตอร์ AM เก่าๆ ในเพิงปั๊มน้ำมัน:
    - Bandpass 180 Hz - 1950 Hz (อุ่น นุ่ม ไม่บาดหู 100%)
    - เสียงซ่าคลื่นวิทยุเบาๆ + เสียงคลื่นวูบวาบ (AM Fading)
    """
    rng = random.Random(seed)
    n = len(buf)
    reverb_buf = add_reverb(buf, decay=0.45, wet=0.34)
    out = make_buf(n / float(SR))
    crackle = make_buf(n / float(SR))

    for i in range(n):
        t = i / float(SR)
        # Gentle AM atmospheric signal fading
        fade_mod = 0.82 + 0.18 * math.sin(TWO_PI * 0.19 * t + math.sin(TWO_PI * 0.07 * t))
        # Warm 100Hz power hum + soft vinyl/radio hiss
        hum = math.sin(TWO_PI * 100.0 * t) * 0.012
        noise = rng.uniform(-1.0, 1.0) * static_level
        if rng.random() < 0.0008:
            # Occasional soft vinyl/AM crackle pop
            noise += rng.uniform(-0.35, 0.35)
        crackle[i] = noise + hum
        out[i] = math.tanh(reverb_buf[i] * fade_mod * 1.25) * 0.85

    crackle = bandpass(crackle, 220.0, 1500.0)
    for i in range(n):
        out[i] += crackle[i]

    return bandpass(out, 155.0, 1850.0)


def gen_lukthung_radio_tracks():
    """สร้างเพลงวิทยุลูกทุ่งเหงาๆ หลอนๆ 5 แบบ (ความยาวเพลงละ 16 - 20 วินาที Loop ได้เนียน)"""

    # ------------------------------------------------------------------
    # เพลงที่ 1: "ลำนำทุ่งมืด" (ขลุ่ยเพียงออโหยหวน + พิณโปร่งช้าๆ ในคีย์ D Minor Pentatonic)
    # ------------------------------------------------------------------
    dur1 = 16.0
    b1 = make_buf(dur1)
    # Chords: Dm -> Gm -> Dm -> A7 -> Dm (4 bars of 4s)
    chords1 = [
        (0.0, 4.0, 38, [50, 53, 57]),   # Dm
        (4.0, 4.0, 43, [55, 58, 62]),   # Gm
        (8.0, 4.0, 38, [50, 53, 57]),   # Dm
        (12.0, 4.0, 33, [49, 52, 57]),  # A7 -> Dm
    ]
    for t0, bar_len, bass_n, arp in chords1:
        add_lukthung_bass(b1, t0, 1.8, bass_n, 0.36)
        add_lukthung_bass(b1, t0 + 2.0, 1.8, bass_n + 7, 0.28)
        for step, note in enumerate(arp + [arp[1]]):
            add_phin_pluck(b1, t0 + step * 0.95 + 0.2, 1.2, note, 0.22)

    # Mournful Khlui melody (D5=74, C5=72, A4=69, G4=67, F4=65, D4=62, Db4=61 eerie ghost note)
    mel1 = [
        (0.3, 2.2, 69, 0.38, -1.5),
        (2.6, 1.3, 72, 0.34, 0.0),
        (4.1, 2.4, 67, 0.38, 2.0),
        (6.6, 1.3, 65, 0.32, 0.0),
        (8.2, 2.1, 69, 0.36, -2.0),
        (10.4, 1.5, 65, 0.33, 1.0),
        (12.1, 1.6, 61.7, 0.35, 1.5),  # eerie quarter-tone flat bend!
        (13.8, 2.0, 62, 0.38, -0.5),
    ]
    for ts, d, n, a, slide in mel1:
        add_khlui_note(b1, ts, d, n, a, vibrato_hz=4.6, vibrato_semi=0.26, slide_from_semi=slide, detune_drift=0.14)

    b1 = apply_am_radio_vintage(b1, static_level=0.032, seed=901)
    soft_save_wav("radio_lukthung_1_lamnam_thung_mued.wav", b1, max_peak=0.62, lp_cutoff=1850.0)

    # ------------------------------------------------------------------
    # เพลงที่ 2: "ขลุ่ยเศร้าใต้ต้นไทร" (ซอเอื้อนโหยหวน + ออร์แกนวัด + จังหวะลูกทุ่งช้าๆ ในคีย์ E Minor)
    # ------------------------------------------------------------------
    dur2 = 16.0
    b2 = make_buf(dur2)
    chords2 = [
        (0.0, 4.0, 40, [52, 55, 59]),   # Em
        (4.0, 4.0, 36, [48, 52, 55]),   # C
        (8.0, 4.0, 33, [45, 48, 52]),   # Am
        (12.0, 4.0, 35, [47, 51, 54]),  # B7
    ]
    for t0, bar_len, bass_n, chord_notes in chords2:
        add_vintage_organ_chord(b2, t0, bar_len, chord_notes, 0.18, eerie_bend=0.12)
        add_lukthung_bass(b2, t0, 1.8, bass_n, 0.34)
        add_lukthung_bass(b2, t0 + 2.0, 1.8, bass_n, 0.28)
        # Soft muffled woodblock / chap beat
        add_grain(b2, t0 + 1.0, 0.06, 620.0, 0.14, 35.0)
        add_grain(b2, t0 + 3.0, 0.06, 580.0, 0.12, 35.0)

    mel2 = [
        (0.2, 1.8, 71, 0.36, -2.0),
        (2.1, 1.8, 74, 0.35, 0.0),
        (4.1, 2.5, 72, 0.38, 1.5),
        (6.7, 1.2, 67, 0.30, 0.0),
        (8.2, 2.2, 69, 0.37, -1.5),
        (10.5, 1.4, 64, 0.32, 0.0),
        (12.1, 3.6, 63.6, 0.38, 1.2),  # haunting B7 third with ghost detune
    ]
    for ts, d, n, a, slide in mel2:
        add_khlui_note(b2, ts, d, n, a, vibrato_hz=5.1, vibrato_semi=0.30, slide_from_semi=slide, detune_drift=0.18)

    b2 = apply_am_radio_vintage(b2, static_level=0.036, seed=902)
    soft_save_wav("radio_lukthung_2_khlui_sao_tai_sai.wav", b2, max_peak=0.62, lp_cutoff=1800.0)

    # ------------------------------------------------------------------
    # เพลงที่ 3: "วิญญาณรักท้ายทุ่ง" (กีตาร์ลูกทุ่ง Tremolo ยุค 70s เหงาจับใจ + ขลุ่ยต่ำ)
    # ------------------------------------------------------------------
    dur3 = 16.0
    b3 = make_buf(dur3)
    # Slow 6/8 Luk Thung ballad feel in A Minor
    prog3 = [
        (0.0, 33, [57, 60, 64, 60]),   # Am
        (4.0, 38, [62, 65, 69, 65]),   # Dm
        (8.0, 33, [57, 60, 64, 60]),   # Am
        (12.0, 28, [56, 59, 64, 57]),  # E7 -> Am
    ]
    for t0, bass_n, notes in prog3:
        add_lukthung_bass(b3, t0, 2.2, bass_n, 0.36)
        add_lukthung_bass(b3, t0 + 2.0, 1.9, bass_n + 7, 0.26)
        for idx, mn in enumerate(notes):
            add_phin_pluck(b3, t0 + idx * 0.95, 1.6, mn, 0.30, tremolo=True)

    mel3 = [
        (0.5, 3.2, 64, 0.32, -1.0),
        (4.3, 3.3, 65, 0.34, 1.5),
        (8.3, 2.2, 64, 0.32, 0.0),
        (10.6, 1.3, 60, 0.30, 0.0),
        (12.2, 3.4, 57, 0.35, -1.5),
    ]
    for ts, d, n, a, slide in mel3:
        add_khlui_note(b3, ts, d, n, a, vibrato_hz=4.2, vibrato_semi=0.22, slide_from_semi=slide, detune_drift=0.12)

    b3 = apply_am_radio_vintage(b3, static_level=0.030, seed=903)
    soft_save_wav("radio_lukthung_3_winyan_rak_nak_leng.wav", b3, max_peak=0.62, lp_cutoff=1850.0)

    # ------------------------------------------------------------------
    # เพลงที่ 4: "กล่อมคืนเดือนดับ" (เพลงกล่อมเด็กโบราณไทย ระนาดทุ้ม/ขลุ่ย ค่อยๆ ยืดช้าลงเหมือนเทปยาน)
    # ------------------------------------------------------------------
    dur4 = 16.0
    b4 = make_buf(dur4)
    # Traditional Thai lullaby motif ("จันทร์เอ๋ยจันทร์เจ้า") in F minor pentatonic, gradually warping pitch downward
    lullaby_notes = [
        (0.4, 1.6, 65, 0.0),
        (2.1, 1.6, 68, -0.05),
        (3.8, 1.8, 70, -0.10),
        (5.7, 2.1, 68, -0.18),
        (8.0, 1.7, 65, -0.28),
        (9.8, 1.8, 63, -0.42),
        (11.7, 1.9, 60, -0.60),
        (13.7, 2.1, 58, -0.85),  # tape slows down eerily
    ]
    for ts, d, n, warp in lullaby_notes:
        add_phin_pluck(b4, ts, d * 1.1, n - 12 + warp, 0.25, tremolo=False)
        add_khlui_note(b4, ts + 0.08, d, n + warp, 0.36, vibrato_hz=4.0, vibrato_semi=0.32, slide_from_semi=1.0, detune_drift=0.25)

    b4 = apply_am_radio_vintage(b4, static_level=0.042, seed=904)
    soft_save_wav("radio_lukthung_4_klom_khuen_duean_dap.wav", b4, max_peak=0.60, lp_cutoff=1700.0)

    # ------------------------------------------------------------------
    # เพลงที่ 5: "คลื่นผีลูกทุ่งหมุนหาคลื่น" (เสียงหมุนคลื่นวิทยุ AM ตอนดึก เจอเพลงลูกทุ่งสลับเสียงสวดทุ้มๆ)
    # ------------------------------------------------------------------
    dur5 = 16.0
    b5 = make_buf(dur5)
    rng5 = random.Random(905)
    # Background Luk Thung song drifting in and out
    for bar in range(4):
        t0 = bar * 4.0
        add_vintage_organ_chord(b5, t0, 3.8, [50, 53, 56], 0.22, eerie_bend=0.22)  # D diminished eerie chord
        add_khlui_note(b5, t0 + 0.4, 2.8, 62 + (bar % 2) * 3, 0.34, vibrato_hz=5.5, vibrato_semi=0.38, slide_from_semi=-2.0, detune_drift=0.3)

    # Low warm radio tuning sweeps (capped under 1200Hz so it's never shrill)
    for sw_t in [3.2, 7.8, 12.4]:
        i0 = int(sw_t * SR)
        sw_dur = 1.1
        for i in range(int(sw_dur * SR)):
            if i0 + i < len(b5):
                dt = i / float(SR)
                env = math.sin(math.pi * dt / sw_dur)
                f_tune = 320.0 + 280.0 * math.sin(TWO_PI * 1.2 * dt)
                b5[i0 + i] = b5[i0 + i] * (1.0 - 0.6 * env) + (
                    math.sin(TWO_PI * f_tune * dt) * 0.14 + rng5.uniform(-1, 1) * 0.18
                ) * env

    b5 = apply_am_radio_vintage(b5, static_level=0.048, seed=905)
    soft_save_wav("radio_lukthung_5_am_detuned_ghost.wav", b5, max_peak=0.60, lp_cutoff=1650.0)


# ==============================================================================
# 4. THAI MONK CHANTING (เสียงพระสวดมนต์ไทย 3 บท 3 ไฟล์ - ทุ้มกังวาน ไม่แสบหู)
# ==============================================================================
# จำลองเสียงหมู่พระสงฆ์ 4 รูป สวดประสานด้วยคลื่นสายเสียง (Glottal Pulse Harmonics)
# ผ่านช่องปาก/ทรวงอก (Vowel Formants: อา / โอ / อู / อะ / อัง) พร้อมจังหวะเอื้อนสังโยคไทยแท้

VOWEL_FORMANTS = {
    "AA": (680.0, 1150.0),  # สระ อา (ธัมมา, อนิจจา, สังขารา)
    "OO": (430.0, 820.0),   # สระ โอ (ธัมโม, สังโฆ, โลโก)
    "UU": (340.0, 720.0),   # สระ อู / อุ (กุสลา, ทุกขัง)
    "AH": (560.0, 1020.0),  # สระ อะ (วะตะ, ปะกะติ)
    "NG": (290.0, 680.0),   # เสียงขึ้นจมูก อัง / มัง (ธัมมัง, สังฆัง - นุ่มทุ้มกังวาน)
}


def add_monk_choir_syllable(
    buf: array,
    t_start: float,
    dur: float,
    midi_note: float,
    vowel: str = "AA",
    amp: float = 0.42,
    slide_semi: float = 0.0,
    end_drop_semi: float = 0.0,
):
    """
    สังเคราะห์เสียงพระสงฆ์ 4 รูป สวดพยางค์บาลีพร้อมกัน (มีดีเลย์เหลื่อมกันเล็กน้อยเหมือนพระสวดจริงในศาลาวัด)
    """
    f1_target, f2_target = VOWEL_FORMANTS.get(vowel, VOWEL_FORMANTS["AA"])
    base_freq = midi_to_hz(midi_note)

    # พระ 4 รูป (ความถี่เหลื่อมกันเล็กน้อย: รูปนำเสียงทุ้ม + รูปตาม 3 รูป)
    monks = [
        (0.000, 1.000, 4.4, 0.32),
        (0.022, 0.993, 4.9, 0.26),
        (0.038, 1.008, 4.1, 0.24),
        (0.055, 0.501, 3.8, 0.18),  # พระเถระเสียงทุ้มต่ำ (Sub-octave chest resonance)
    ]

    for delay_s, detune_ratio, vib_rate, m_weight in monks:
        i0 = int((t_start + delay_s) * SR)
        n = int(dur * SR)
        end = min(len(buf), i0 + n)
        phase = random.Random(i0 + int(detune_ratio * 1000)).random() * TWO_PI

        for i in range(max(0, i0), end):
            dt = (i - i0) / float(SR)
            u = dt / max(0.01, dur)

            # ซองเสียงพยางค์สวดมนต์ (ขึ้นนุ่ม ค้างสม่ำเสมอ ลงท้ายพยางค์อย่างสำรวม)
            if dt < 0.07:
                env = math.sin(0.5 * math.pi * (dt / 0.07))
            elif dt > dur - 0.14:
                env = max(0.0, (dur - dt) / 0.14)
            else:
                env = 1.0 - 0.08 * u

            # เอื้อนต้นพยางค์ + เอื้อนตกลูกคอท้ายวรรคแบบสวดไทย
            ornament_semi = slide_semi * math.exp(-dt * 10.0)
            if u > 0.72 and end_drop_semi != 0.0:
                ornament_semi += end_drop_semi * ((u - 0.72) / 0.28)
            vib = math.sin(TWO_PI * vib_rate * dt) * 0.10 * min(1.0, dt / 0.25)

            f_inst = base_freq * detune_ratio * (2.0 ** ((ornament_semi + vib) / 12.0))
            phase += TWO_PI * f_inst / float(SR)

            # สร้าง Harmonics ของเส้นเสียงผู้ชาย (8 Harmonics ถ่วงน้ำหนักด้วยกรอง Formant สระ F1, F2)
            voice_sum = 0.0
            for h in range(1, 9):
                fh = f_inst * h
                # Resonance peaks around F1 and F2 + warm chest fundamental
                chest_w = 0.85 if h == 1 else (0.55 if h == 2 else 0.15 / h)
                w1 = math.exp(-0.5 * ((fh - f1_target) / 145.0) ** 2) * 0.95
                w2 = math.exp(-0.5 * ((fh - f2_target) / 210.0) ** 2) * 0.45
                harm_amp = chest_w + w1 + w2
                voice_sum += math.sin(phase * h + h * 0.35) * harm_amp

            buf[i] += voice_sum * (amp * 0.34 * m_weight) * env


def add_temple_bell_strike(buf: array, t_start: float, dur: float, base_f: float, amp: float):
    """เสียงเคาะระฆังสำริด / ขันน้ำมนต์นำบทสวด (ทุ้มนุ่มกังวาน)"""
    i0 = int(t_start * SR)
    n = int(dur * SR)
    end = min(len(buf), i0 + n)
    for i in range(max(0, i0), end):
        dt = (i - i0) / float(SR)
        env = math.exp(-dt * 1.65) * min(1.0, dt / 0.015)
        bell = (
            math.sin(TWO_PI * base_f * dt) * 0.55
            + math.sin(TWO_PI * base_f * 1.504 * dt) * 0.28 * math.exp(-dt * 2.2)
            + math.sin(TWO_PI * base_f * 2.01 * dt) * 0.17 * math.exp(-dt * 3.5)
        )
        buf[i] += bell * amp * env


def gen_thai_monk_chants():
    """
    สร้างไฟล์เสียงสวดมนต์ไทย 3 บท 3 ไฟล์ (.wav)
    1. chant_thai_1_kusala_abhidhamma.wav : บทสวดพระอภิธรรม 7 คัมภีร์ (กุสลา ธัมมา... อะกุสลา ธัมมา...)
    2. chant_thai_2_anicca_bangsukul.wav  : บทสวดบังสุกุลตาย (อนิจจา วะตะ สังขารา อุปปาทะวะยะธัมมิโน...)
    3. chant_thai_3_phra_malai_am_radio.wav: บทสวดพระมาลัย / สวดหน้าไฟคลื่นวิทยุ AM โบราณ
    """

    # ==================================================================
    # บทที่ 1: บทสวดพระอภิธรรม "กุสลา ธัมมา" (18.0 วินาที Loop ได้)
    # จังหวะสังโยคไทย: กุ-สะ-ลา ธัม-มา (เอื้อน) / อะ-กุ-สะ-ลา ธัม-มา / อัพ-พะ-ยา-กะ-ตา ธัม-มา
    # ==================================================================
    dur1 = 18.0
    c1 = make_buf(dur1)
    add_temple_bell_strike(c1, 0.15, 3.8, 146.8, 0.35)  # ระฆัง D3 นำสวด

    # โน้ตหลัก D3 (MIDI 50 = 146.8Hz), F3 (53), G3 (55), C3 (48)
    kusala_phrases = [
        # วรรค 1: กุ-สะ-ลา ธัม-มา...
        (0.5, 0.42, 50, "UU", 0.42, 0.0, 0.0),    # กุ
        (0.95, 0.42, 50, "AH", 0.40, 0.0, 0.0),   # สะ
        (1.40, 1.15, 53, "AA", 0.46, -1.0, 0.0),  # ลา (ขึ้นเสียงตรี)
        (2.65, 0.85, 50, "NG", 0.45, 0.0, 0.0),   # ธัม
        (3.55, 1.95, 50, "AA", 0.48, 1.5, -2.0),  # มา... (เอื้อนลงท้ายวรรค)

        # วรรค 2: อะ-กุ-สะ-ลา ธัม-มา...
        (6.0, 0.38, 50, "AH", 0.40, 0.0, 0.0),    # อะ
        (6.40, 0.38, 50, "UU", 0.42, 0.0, 0.0),   # กุ
        (6.80, 0.40, 50, "AH", 0.40, 0.0, 0.0),   # สะ
        (7.22, 1.10, 53, "AA", 0.46, -1.0, 0.0),  # ลา
        (8.40, 0.85, 50, "NG", 0.45, 0.0, 0.0),   # ธัม
        (9.30, 2.00, 48, "AA", 0.48, 2.0, -1.5),  # มา... (ตกลูกคอต่ำ C3)

        # วรรค 3: อัพ-พะ-ยา-กะ-ตา ธัม-มา...
        (11.8, 0.42, 50, "AH", 0.42, 0.0, 0.0),   # อัพ
        (12.25, 0.38, 50, "AH", 0.40, 0.0, 0.0),  # พะ
        (12.65, 0.65, 53, "AA", 0.44, 0.0, 0.0),  # ยา
        (13.35, 0.38, 53, "AH", 0.40, 0.0, 0.0),  # กะ
        (13.75, 0.95, 55, "AA", 0.46, -1.5, 0.0), # ตา
        (14.80, 0.85, 50, "NG", 0.45, 0.0, 0.0),  # ธัม
        (15.70, 2.05, 50, "AA", 0.48, 1.5, -2.0), # มา...
    ]
    for ts, d, note, vw, amp, sl, drop in kusala_phrases:
        add_monk_choir_syllable(c1, ts, d, note, vw, amp, sl, drop)

    c1 = add_reverb(c1, decay=0.52, wet=0.38)
    c1 = bandpass(c1, 85.0, 1550.0)
    soft_save_wav("chant_thai_1_kusala_abhidhamma.wav", c1, max_peak=0.64, lp_cutoff=1550.0)

    # ==================================================================
    # บทที่ 2: บทสวดบังสุกุลตาย "อนิจจา วะตะ สังขารา" (18.0 วินาที)
    # ลากเสียงช้า วังเวง ขรึมขลัง สะท้อนในศาลาวัดตอนดึก
    # ==================================================================
    dur2 = 18.0
    c2 = make_buf(dur2)
    add_temple_bell_strike(c2, 0.10, 4.2, 130.8, 0.32)  # ระฆัง C3 ทุ้มต่ำ
    add_temple_bell_strike(c2, 9.10, 4.2, 130.8, 0.28)

    # คีย์ C3 (MIDI 48 = 130.8Hz), Eb3 (51), F3 (53), Bb2 (46)
    anicca_phrases = [
        # วรรค 1: อะ-นิจ-จา วะ-ตะ สัง-ขา-รา...
        (0.4, 0.45, 48, "AH", 0.40, 0.0, 0.0),    # อะ
        (0.88, 0.65, 48, "UU", 0.42, 0.0, 0.0),   # นิจ
        (1.56, 1.25, 51, "AA", 0.46, -1.5, 0.0),  # จา
        (2.90, 0.42, 48, "AH", 0.40, 0.0, 0.0),   # วะ
        (3.35, 0.55, 48, "AH", 0.40, 0.0, 0.0),   # ตะ
        (3.95, 0.95, 51, "NG", 0.46, 0.0, 0.0),   # สัง
        (4.95, 1.15, 53, "AA", 0.46, -1.0, 0.0),  # ขา
        (6.15, 2.40, 48, "AA", 0.48, 2.0, -2.0),  # รา...

        # วรรค 2: อุป-ปา-ทะ-วะ-ยะ-ธัม-มิ-โน...
        (9.2, 0.50, 48, "UU", 0.42, 0.0, 0.0),    # อุป
        (9.75, 0.95, 51, "AA", 0.45, 0.0, 0.0),   # ปา
        (10.75, 0.42, 51, "AH", 0.40, 0.0, 0.0),  # ทะ
        (11.20, 0.42, 48, "AH", 0.40, 0.0, 0.0),  # วะ
        (11.65, 0.45, 48, "AH", 0.40, 0.0, 0.0),  # ยะ
        (12.15, 0.95, 51, "NG", 0.46, 0.0, 0.0),  # ธัม
        (13.15, 0.55, 48, "UU", 0.42, 0.0, 0.0),  # มิ
        (13.75, 2.95, 46, "OO", 0.50, 2.0, -1.5), # โน... (ลากเสียง โอ ทุ้มลึกยาว)
    ]
    for ts, d, note, vw, amp, sl, drop in anicca_phrases:
        add_monk_choir_syllable(c2, ts, d, note, vw, amp, sl, drop)

    c2 = add_reverb(c2, decay=0.58, wet=0.42)
    c2 = bandpass(c2, 80.0, 1450.0)
    soft_save_wav("chant_thai_2_anicca_bangsukul.wav", c2, max_peak=0.64, lp_cutoff=1450.0)

    # ==================================================================
    # บทที่ 3: บทสวดพระมาลัย / สวดหน้าไฟผ่านคลื่นวิทยุ AM โบราณ (18.0 วินาที)
    # ทำนองเอื้อนขึ้น-ลงโหยหวน พร้อมเสียงคลื่นวิทยุทรานซิสเตอร์เก่าแทรกเบาๆ (เหมาะกับผีวิทยุ Anomaly_MonkRadio)
    # ==================================================================
    dur3 = 18.0
    c3 = make_buf(dur3)
    add_temple_bell_strike(c3, 0.2, 3.5, 164.8, 0.30)  # E3

    # ทำนองสวดพระมาลัยเอื้อนโหยหวน (E3=52, G3=55, A3=57, B3=59, D3=50)
    malai_phrases = [
        # วรรค 1: เอื้อนโหยหวนขึ้นสูงแล้วตกลูกคอ
        (0.5, 0.55, 52, "OO", 0.42, -1.5, 0.0),
        (1.10, 1.35, 55, "AA", 0.46, -2.0, 1.0),
        (2.50, 0.85, 57, "NG", 0.45, 0.0, 0.0),
        (3.40, 2.20, 55, "OO", 0.48, 2.0, -3.0),

        # วรรค 2: รับลูกคู่ทุ้มต่ำ
        (6.1, 0.60, 52, "AH", 0.40, 0.0, 0.0),
        (6.75, 0.95, 55, "UU", 0.44, -1.5, 0.0),
        (7.75, 1.15, 52, "NG", 0.45, 1.0, 0.0),
        (8.95, 2.35, 50, "AA", 0.48, 2.0, -2.0),

        # วรรค 3: เอื้อนลาท้ายบทพร้อมเทปวิทยุค่อยๆ ยืด
        (11.8, 0.70, 55, "AA", 0.44, -2.0, 0.0),
        (12.55, 1.10, 57, "OO", 0.46, -1.5, 0.0),
        (13.70, 1.15, 52, "NG", 0.45, 2.0, 0.0),
        (14.90, 2.75, 50, "OO", 0.50, 2.0, -2.5),
    ]
    for ts, d, note, vw, amp, sl, drop in malai_phrases:
        add_monk_choir_syllable(c3, ts, d, note, vw, amp, sl, drop)

    c3 = apply_am_radio_vintage(c3, static_level=0.028, seed=955)
    soft_save_wav("chant_thai_3_phra_malai_am_radio.wav", c3, max_peak=0.62, lp_cutoff=1500.0)

    # ==================================================================
    # บทที่ 4: บทตั้งนะโม "นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ" (18.0 วินาที)
    # ทำนองสังโยคพระสงฆ์ไทย: นะ-โม ตัส-สะ (หยุดหายใจ) ภะ-คะ-วะ-โต (หยุด) อะ-ระ-หะ-โต สัม-มา-สัม-พุท-ธัส-สะ...
    # ==================================================================
    dur4 = 18.0
    c4 = make_buf(dur4)
    add_temple_bell_strike(c4, 0.12, 4.0, 146.8, 0.34)  # ระฆัง D3 นำตั้งนะโม

    # โน้ตหลัก D3 (MIDI 50 = 146.8Hz), F3 (53), G3 (55), A3 (57), C3 (48)
    namo_phrases = [
        # วรรค 1: นะ-โม ตัส-สะ...
        (0.45, 0.45, 50, "AH", 0.42, 0.0, 0.0),    # นะ
        (0.95, 1.35, 53, "OO", 0.48, -1.5, 0.0),   # โม (ลากเสียง โม กังวาน)
        (2.40, 0.65, 55, "AH", 0.45, 0.0, 0.0),    # ตัส
        (3.10, 1.55, 50, "AH", 0.46, 1.5, -1.5),   # สะ...

        # วรรค 2: ภะ-คะ-วะ-โต...
        (5.10, 0.40, 50, "AH", 0.40, 0.0, 0.0),    # ภะ
        (5.55, 0.40, 50, "AH", 0.40, 0.0, 0.0),    # คะ
        (6.00, 0.45, 53, "AH", 0.42, 0.0, 0.0),    # วะ
        (6.50, 1.95, 55, "OO", 0.48, -1.5, -1.0),  # โต... (ลากเสียง โอ สูงแล้วเอื้อนลง)

        # วรรค 3: อะ-ระ-หะ-โต...
        (8.90, 0.40, 53, "AH", 0.40, 0.0, 0.0),    # อะ
        (9.35, 0.40, 53, "AH", 0.40, 0.0, 0.0),    # ระ
        (9.80, 0.45, 53, "AH", 0.42, 0.0, 0.0),    # หะ
        (10.30, 1.75, 50, "OO", 0.48, 1.5, -1.5),  # โต...

        # วรรค 4: สัม-มา-สัม-พุท-ธัส-สะ...
        (12.45, 0.75, 53, "NG", 0.45, 0.0, 0.0),   # สัม
        (13.25, 0.85, 55, "AA", 0.46, -1.0, 0.0),  # มา
        (14.15, 0.75, 53, "NG", 0.45, 0.0, 0.0),   # สัม
        (14.95, 0.55, 50, "UU", 0.44, 0.0, 0.0),   # พุท
        (15.55, 0.65, 53, "AH", 0.45, 0.0, 0.0),   # ธัส
        (16.25, 1.55, 48, "AH", 0.50, 2.0, -2.0),  # สะ... (ลงเสียงต่ำ C3 สำรวม)
    ]
    for ts, d, note, vw, amp, sl, drop in namo_phrases:
        add_monk_choir_syllable(c4, ts, d, note, vw, amp, sl, drop)

    c4 = add_reverb(c4, decay=0.55, wet=0.40)
    c4 = bandpass(c4, 85.0, 1500.0)
    soft_save_wav("chant_thai_4_namo_tassa.wav", c4, max_peak=0.64, lp_cutoff=1500.0)


def main():
    import sys
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("🔊 กำลังสังเคราะห์ชุดเสียงประกอบเกม 'ปั๊มหลอดท้ายทุ่ง' (Warm Low-Pass, Non-Piercing)...")
    gen_pump_crank()
    gen_fuel_glug()
    gen_shutter_sounds()
    gen_coin_tin_and_incense()
    gen_vehicle_idles()
    gen_breathing_neck()
    gen_footsteps_dirt()
    gen_walk_in_shop_and_roof()
    gen_tree_climbing()
    gen_lukthung_radio_tracks()
    gen_thai_monk_chants()
    print(f"✅ สร้างไฟล์เสียงทั้งหมดเสร็จสมบูรณ์ที่: {OUT_DIR}")


if __name__ == "__main__":
    main()
