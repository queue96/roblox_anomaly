#!/usr/bin/env python3
"""
tools/audio/generate_road_events_audio.py
สร้างชุดไฟล์เสียงสำหรับขบวนขาจรบนถนน (Road Events):
1. เด็กแว้น (Racers):
   - sfx_racer_moto_rev_cut.wav       : เสียงมอเตอร์ไซค์ซิ่งเบิ้ลเครื่องตัด (บรื้นนน-ปั๊บๆๆ!) นุ่มแน่นไม่แสบหู
   - sfx_racer_wheelie_pass.wav       : เสียงยกล้อซิ่งผ่านหน้าร้าน (Doppler Pan ซ้าย->ขวา)
2. เพลงแดนซ์รถเครื่องเสียง / สาวโคโยตี้ (Party Sound Truck):
   - music_thai_dance_1_sai_yor.wav   : เพลงแดนซ์สายย่อสามช่า EDM กระบะตู้ทึบ (เบสแน่นตึ้บๆ + เมโลดี้โจ๊ะๆ 136 BPM)
   - music_thai_dance_2_morlam_edm.wav: เพลงแดนซ์หมอลำซิ่งรีมิกซ์ (พิณซิ่ง + เบสแดนซ์งานวัด)
3. เพลงรถแห่ & ขบวนแห่งานบวช (Parade Truck):
   - music_parade_1_rothe_isan.wav    : เพลงรถแห่อีสานสด (พิณซิ่ง + แคน + เบสเดิน + กลองสามช่า)
   - music_parade_2_klongyao_brass.wav: เพลงกลองยาวแตรวงงานบวช (กลองยาวตุ้มๆ เถิดเทิง + แตรวงสามช่า)
"""

import math
import os
import random
import sys
import wave
from array import array

SR = 44100
TWO_PI = 2.0 * math.pi
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets",
    "sounds",
)


def make_buf(dur: float) -> array:
    return array("f", [0.0]) * int(SR * dur)


def lowpass_1pole(buf: array, cutoff_hz: float) -> array:
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


def midi_to_hz(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69.0) / 12.0))


def save_wav(filename: str, left: array, right: array = None, max_peak: float = 0.74, lp_cutoff: float = 2800.0):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, filename)
    left = lowpass_1pole(left, lp_cutoff)
    if right is not None:
        right = lowpass_1pole(right, lp_cutoff)
    n = len(left)
    fade = min(int(SR * 0.03), n // 12)
    peak = max(1e-6, max(abs(x) for x in left))
    if right is not None:
        peak = max(peak, max(abs(x) for x in right))
    scale = max_peak / max(peak, 0.05)

    with wave.open(path, "wb") as wf:
        ch = 2 if right is not None else 1
        wf.setnchannels(ch)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        pcm = array("h")
        for i in range(n):
            env = 1.0
            if i < fade:
                env = i / float(fade)
            elif i > n - fade:
                env = (n - i) / float(fade)
            vl = math.tanh(left[i] * scale * env) * 0.94
            pcm.append(int(max(-32767, min(32767, vl * 32767.0))))
            if right is not None:
                vr = math.tanh(right[i] * scale * env) * 0.94
                pcm.append(int(max(-32767, min(32767, vr * 32767.0))))
        wf.writeframes(pcm.tobytes())
    print(f"  [OK] {filename} ({n/SR:.1f}s)")


# ==============================================================================
# 1. เสียงเด็กแว้น (เบิ้ลเครื่องตัด + ยกล้อซิ่งผ่านหน้าร้าน)
# ==============================================================================
def gen_racer_bikes():
    # 1.1 เบิ้ลเครื่องตัด (Rev-limiter cut: บรื้นนน-ปั๊บๆๆๆ-บรื้นนน! 4.0s loop)
    dur = 4.0
    buf = make_buf(dur)
    phase = 0.0
    for i in range(len(buf)):
        t = i / float(SR)
        # Throttle pattern: 2 aggressive throttle blips + rev-limiter bounce
        cycle = t % 2.0
        if cycle < 0.45:
            rpm_f = 85.0 + 160.0 * (cycle / 0.45)
            cut = 1.0
        elif cycle < 0.95:
            rpm_f = 245.0
            # Rev limiter ignition cut (18 Hz stutter)
            cut = 1.0 if math.sin(TWO_PI * 18.0 * t) > -0.2 else 0.15
        elif cycle < 1.35:
            rpm_f = 245.0 - 140.0 * ((cycle - 0.95) / 0.40)
            cut = 1.0
        else:
            rpm_f = 95.0 + 90.0 * math.sin( math.pi * (cycle - 1.35) / 0.65)
            cut = 1.0

        phase += TWO_PI * rpm_f / float(SR)
        # 4-stroke open pipe harmonics (warm, punchy low-mid, rolled off highs)
        exhaust = (
            math.sin(phase * 0.5) * 0.50
            + math.sin(phase) * 0.65
            + math.sin(phase * 1.5 + 0.4) * 0.30
            + math.sin(phase * 2.0) * 0.25
        )
        buf[i] = math.tanh(exhaust * 1.6) * 0.65 * cut

    save_wav("sfx_racer_moto_rev_cut.wav", buf, max_peak=0.68, lp_cutoff=1750.0)

    # 1.2 เสียงยกล้อซิ่งผ่านหน้าร้าน (Doppler fly-by stereo 3.2s)
    dur2 = 3.2
    left = make_buf(dur2)
    right = make_buf(dur2)
    phase2 = 0.0
    for i in range(len(left)):
        t = i / float(SR)
        u = (t - 1.5) / 1.5  # -1.0 (approaching left) -> 0.0 (center) -> +1.0 (receding right)
        # Doppler pitch shift
        doppler = 1.0 - 0.18 * math.tanh(u * 2.5)
        f_eng = 225.0 * doppler
        phase2 += TWO_PI * f_eng / float(SR)
        dist_env = 1.0 / (1.0 + 3.2 * (u * u))
        pan = math.tanh(u * 1.8) * 0.85
        lg = math.cos((pan + 1.0) * math.pi * 0.25) * dist_env
        rg = math.sin((pan + 1.0) * math.pi * 0.25) * dist_env
        sig = math.tanh(
            (math.sin(phase2 * 0.5) * 0.5 + math.sin(phase2) * 0.7 + math.sin(phase2 * 2.0) * 0.3) * 1.5
        ) * 0.7
        left[i] = sig * lg
        right[i] = sig * rg

    save_wav("sfx_racer_wheelie_pass.wav", left, right, max_peak=0.68, lp_cutoff=1850.0)


# ==============================================================================
# Helpers สำหรับกลองสามช่า / เบสสายย่อ / พิณซิ่ง / แตรวง
# ==============================================================================
def add_kick(buf: array, t0: float, amp: float = 0.75):
    i0 = int(t0 * SR)
    dur = 0.22
    for i in range(int(dur * SR)):
        if i0 + i >= len(buf):
            break
        dt = i / float(SR)
        # Pitch drops from 135Hz -> 52Hz (tight punchy Samcha / Sai-Yor bass kick)
        f = 52.0 + 85.0 * math.exp(-dt * 28.0)
        env = math.exp(-dt * 11.0)
        buf[i0 + i] += math.sin(TWO_PI * f * dt) * amp * env


def add_snare_samcha(buf: array, t0: float, amp: float = 0.42, rng: random.Random = None):
    i0 = int(t0 * SR)
    dur = 0.14
    r = rng or random.Random(int(t0 * 1000))
    for i in range(int(dur * SR)):
        if i0 + i >= len(buf):
            break
        dt = i / float(SR)
        body = math.sin(TWO_PI * 195.0 * dt) * math.exp(-dt * 22.0) * 0.65
        snap = r.uniform(-1.0, 1.0) * math.exp(-dt * 26.0) * 0.45
        buf[i0 + i] += (body + snap) * amp


def add_klong_yao_hit(buf: array, t0: float, pitch_hz: float = 165.0, amp: float = 0.55):
    """เสียงกลองยาว/กลองทอมรถแห่ (ตุ้ม-เท่ง-ตุ้ม กังวานหนังกลอง)"""
    i0 = int(t0 * SR)
    dur = 0.28
    for i in range(int(dur * SR)):
        if i0 + i >= len(buf):
            break
        dt = i / float(SR)
        f = pitch_hz * (1.0 + 0.12 * math.exp(-dt * 20.0))
        env = math.exp(-dt * 9.5) * min(1.0, dt / 0.005)
        tone = math.sin(TWO_PI * f * dt) * 0.72 + math.sin(TWO_PI * f * 1.58 * dt) * 0.28
        buf[i0 + i] += tone * amp * env


def add_sub_bass_note(buf: array, t0: float, dur: float, midi_n: float, amp: float = 0.52):
    i0 = int(t0 * SR)
    f = midi_to_hz(midi_n)
    for i in range(int(dur * SR)):
        if i0 + i >= len(buf):
            break
        dt = i / float(SR)
        env = math.exp(-dt * 4.5) * min(1.0, dt / 0.01)
        tone = math.sin(TWO_PI * f * dt) * 0.75 + math.sin(TWO_PI * f * 2.0 * dt) * 0.25
        buf[i0 + i] += math.tanh(tone * 1.4) * amp * env


def add_lead_note(buf: array, t0: float, dur: float, midi_n: float, amp: float = 0.36, style: str = "synth"):
    """เมโลดี้ซินธ์สายย่อ / พิณซิ่งรถแห่ / แตรวงงานบวช"""
    i0 = int(t0 * SR)
    f = midi_to_hz(midi_n)
    phase = 0.0
    for i in range(int(dur * SR)):
        if i0 + i >= len(buf):
            break
        dt = i / float(SR)
        if style == "phin":
            env = math.exp(-dt * 4.2) * min(1.0, dt / 0.006)
            vib = math.sin(TWO_PI * 6.0 * dt) * 0.15
        elif style == "brass":
            env = min(1.0, dt / 0.03) * max(0.0, min(1.0, (dur - dt) / 0.05))
            vib = math.sin(TWO_PI * 5.0 * dt) * 0.10
        else:  # dance bounce synth
            env = math.exp(-dt * 6.0) * min(1.0, dt / 0.008)
            vib = 0.0

        f_inst = f * (2.0 ** (vib / 12.0))
        phase += TWO_PI * f_inst / float(SR)
        tone = (
            math.sin(phase) * 0.60
            + math.sin(phase * 2.0 + 0.3) * 0.28
            + math.sin(phase * 3.0 + 0.7) * 0.12
        )
        buf[i0 + i] += tone * amp * env


# ==============================================================================
# 2. เพลงแดนซ์รถซิ่งเครื่องเสียง (Party Sound Truck - 2 เพลง)
# ==============================================================================
def gen_dance_truck_music():
    # ------------------------------------------------------------------
    # เพลงแดนซ์ที่ 1: "สายย่อสามช่ากระบะซิ่ง" (136 BPM, 32 บีต = 14.12 วินาที Loop เป๊ะ)
    # ------------------------------------------------------------------
    bpm1 = 136.0
    spb1 = 60.0 / bpm1
    dur1 = 32 * spb1
    b1 = make_buf(dur1)
    rng1 = random.Random(801)

    # 32 beats of four-on-the-floor kick + Samcha offbeat bounce bass + snappy snare
    bass_roots = [38, 38, 41, 43]  # D2, D2, F2, G2 (8 beats each)
    for beat in range(32):
        tb = beat * spb1
        root = bass_roots[(beat // 8) % 4]
        add_kick(b1, tb, 0.72)
        # Offbeat Sai-Yor bouncy bass (จังหวะตึ้บ-ตึ๋ง-ตึ้บ-ตึ๋ง)
        add_sub_bass_note(b1, tb + spb1 * 0.5, spb1 * 0.45, root + 12, 0.48)
        if beat % 2 == 1:
            add_snare_samcha(b1, tb, 0.38, rng1)
        # Samcha syncopated tom fill every 4th beat
        if beat % 4 == 3:
            add_klong_yao_hit(b1, tb + spb1 * 0.75, 190.0, 0.34)

    # Catchy Thai Sai-Yor synth hook (D minor pentatonic: D5=74, F5=77, G5=79, A5=81, C5=72)
    hook1 = [
        (0.0, 0.5, 74), (0.5, 0.5, 74), (1.0, 0.5, 77), (1.5, 0.5, 79),
        (2.0, 0.75, 81), (2.75, 0.75, 79), (3.5, 0.5, 77),
        (4.0, 0.5, 74), (4.5, 0.5, 72), (5.0, 0.5, 69), (5.5, 0.5, 72),
        (6.0, 1.0, 74), (7.0, 1.0, 74),
    ]
    for bar_group in range(4):
        offset_b = bar_group * 8
        for nb, nd, note in hook1:
            # Keep melody in warm mid octave (note - 12) so it's never shrill
            add_lead_note(b1, (offset_b + nb) * spb1, nd * spb1 * 0.9, note - 12, 0.38, style="synth")

    save_wav("music_thai_dance_1_sai_yor.wav", b1, max_peak=0.72, lp_cutoff=2350.0)

    # ------------------------------------------------------------------
    # เพลงแดนซ์ที่ 2: "หมอลำซิ่ง EDM รถเครื่องเสียง" (140 BPM, 32 บีต = 13.71 วินาที Loop เป๊ะ)
    # ------------------------------------------------------------------
    bpm2 = 140.0
    spb2 = 60.0 / bpm2
    dur2 = 32 * spb2
    b2 = make_buf(dur2)
    rng2 = random.Random(802)

    for beat in range(32):
        tb = beat * spb2
        add_kick(b2, tb, 0.70)
        add_sub_bass_note(b2, tb + spb2 * 0.5, spb2 * 0.45, 45 if (beat // 8) % 2 == 0 else 43, 0.46)
        if beat % 2 == 1:
            add_snare_samcha(b2, tb, 0.36, rng2)

    # Fast Isan Phin Sing riff in A minor pentatonic (A3=57, C4=60, D4=62, E4=64, G4=67, A4=69)
    phin_riff = [
        (0.0, 0.5, 69), (0.5, 0.25, 67), (0.75, 0.25, 64),
        (1.0, 0.5, 62), (1.5, 0.5, 64),
        (2.0, 0.5, 60), (2.5, 0.25, 62), (2.75, 0.25, 60),
        (3.0, 0.5, 57), (3.5, 0.5, 60),
    ]
    for rep in range(8):
        off = rep * 4
        for nb, nd, note in phin_riff:
            add_lead_note(b2, (off + nb) * spb2, nd * spb2 * 0.95, note, 0.40, style="phin")

    save_wav("music_thai_dance_2_morlam_edm.wav", b2, max_peak=0.72, lp_cutoff=2400.0)


# ==============================================================================
# 3. เพลงรถแห่อีสาน & เพลงกลองยาวแตรวงงานบวช (Parade Truck - 2 เพลง)
# ==============================================================================
def gen_parade_music():
    # ------------------------------------------------------------------
    # เพลงรถแห่ที่ 1: "รถแห่อีสานสามช่าสด" (126 BPM, 32 บีต = 15.24 วินาที Loop เป๊ะ)
    # ------------------------------------------------------------------
    bpm1 = 126.0
    spb1 = 60.0 / bpm1
    dur1 = 32 * spb1
    p1 = make_buf(dur1)
    rng1 = random.Random(901)

    # จังหวะกลองสามช่ารถแห่แท้ๆ: ตุ้ม.. ตุ้ม-ต๊ะ ตุ้ม-ตุ้ม-ต๊ะ!
    for bar in range(8):
        t_bar = bar * 4 * spb1
        # Kick & Walking Bass
        for b in range(4):
            tb = t_bar + b * spb1
            add_kick(p1, tb, 0.62)
            if b in (1, 3):
                add_snare_samcha(p1, tb, 0.36, rng1)
        # Samcha Klong Yao / Tom groove ("ตุ้ม-เท่ง-ตุ้ม")
        add_klong_yao_hit(p1, t_bar + 0.0 * spb1, 145.0, 0.48)
        add_klong_yao_hit(p1, t_bar + 0.75 * spb1, 185.0, 0.42)
        add_klong_yao_hit(p1, t_bar + 1.5 * spb1, 150.0, 0.48)
        add_klong_yao_hit(p1, t_bar + 2.5 * spb1, 195.0, 0.40)
        add_klong_yao_hit(p1, t_bar + 3.0 * spb1, 160.0, 0.46)
        add_klong_yao_hit(p1, t_bar + 3.5 * spb1, 210.0, 0.44)

        # Walking electric bass (E minor pentatonic: E2=40, G2=43, A2=45, B2=47, D3=50)
        for b, bn in enumerate([40, 43, 45, 47] if bar % 2 == 0 else [45, 47, 50, 43]):
            add_sub_bass_note(p1, t_bar + b * spb1, spb1 * 0.85, bn, 0.48)

    # ลายพิณรถแห่ + แคน/ออร์แกนรับส่ง
    rothe_mel = [
        (0.0, 0.75, 64), (0.75, 0.75, 67), (1.5, 0.5, 69),
        (2.0, 0.5, 71), (2.5, 0.5, 69), (3.0, 1.0, 67),
        (4.0, 0.75, 64), (4.75, 0.75, 62), (5.5, 0.5, 59),
        (6.0, 1.0, 62), (7.0, 1.0, 64),
    ]
    for cycle in range(4):
        off = cycle * 8
        for nb, nd, note in rothe_mel:
            add_lead_note(p1, (off + nb) * spb1, nd * spb1 * 0.9, note, 0.38, style="phin")
            add_lead_note(p1, (off + nb) * spb1, nd * spb1 * 0.85, note - 12, 0.22, style="brass")

    save_wav("music_parade_1_rothe_isan.wav", p1, max_peak=0.72, lp_cutoff=2300.0)

    # ------------------------------------------------------------------
    # เพลงรถแห่ที่ 2: "กลองยาวแตรวงงานบวช (เถิดเทิงสามช่า)" (120 BPM, 32 บีต = 16.0 วินาที Loop เป๊ะ)
    # ------------------------------------------------------------------
    bpm2 = 120.0
    spb2 = 60.0 / bpm2
    dur2 = 32 * spb2
    p2 = make_buf(dur2)
    rng2 = random.Random(902)

    for bar in range(8):
        t_bar = bar * 4 * spb2
        # กลองยาวเถิดเทิง: บึ้ม-ติง-บึ้ม-เท่ง-ป๊ะ-เท่ง-ป๊ะ!
        hits = [
            (0.0, 130.0, 0.58),
            (0.5, 195.0, 0.42),
            (1.0, 135.0, 0.55),
            (1.75, 215.0, 0.45),
            (2.25, 180.0, 0.48),
            (2.75, 220.0, 0.44),
            (3.25, 140.0, 0.55),
            (3.75, 200.0, 0.46),
        ]
        for hb, hf, ha in hits:
            add_klong_yao_hit(p2, t_bar + hb * spb2, hf, ha)
        add_sub_bass_note(p2, t_bar, spb2 * 1.8, 41, 0.45)          # F2 tuba
        add_sub_bass_note(p2, t_bar + 2 * spb2, spb2 * 1.8, 48, 0.42)  # C3 tuba
        add_snare_samcha(p2, t_bar + 1 * spb2, 0.30, rng2)
        add_snare_samcha(p2, t_bar + 3 * spb2, 0.30, rng2)

    # ทำนองแตรวงงานบวชไทย (F major pentatonic: F4=65, G4=67, A4=69, C5=72, D5=74)
    brass_mel = [
        (0.0, 0.75, 65), (0.75, 0.75, 67), (1.5, 0.5, 69),
        (2.0, 1.0, 72), (3.0, 1.0, 69),
        (4.0, 0.75, 72), (4.75, 0.75, 74), (5.5, 0.5, 72),
        (6.0, 0.75, 69), (6.75, 0.5, 67), (7.25, 0.75, 65),
    ]
    for cycle in range(4):
        off = cycle * 8
        for nb, nd, note in brass_mel:
            # Ensemble brass (root + sixth harmony)
            add_lead_note(p2, (off + nb) * spb2, nd * spb2 * 0.88, note - 12, 0.38, style="brass")
            add_lead_note(p2, (off + nb) * spb2, nd * spb2 * 0.88, note - 3, 0.24, style="brass")

    save_wav("music_parade_2_klongyao_brass.wav", p2, max_peak=0.72, lp_cutoff=2200.0)


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("🎉 กำลังสร้างชุดเสียงขาจรบนถนน: เด็กแว้น + เพลงแดนซ์รถเครื่องเสียง + เพลงรถแห่งานบวช...")
    gen_racer_bikes()
    gen_dance_truck_music()
    gen_parade_music()
    print(f"✅ สร้างไฟล์เสียงขาจรบนถนนครบ 6 ไฟล์ที่: {OUT_DIR}")


if __name__ == "__main__":
    main()
