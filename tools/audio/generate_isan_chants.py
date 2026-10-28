#!/usr/bin/env python3
"""
tools/audio/generate_isan_chants.py
สร้างชุดไฟล์เสียงสวดมนต์คำพูดชัดๆ สำเนียงไทยบ้านฝั่งอีสาน (โทนเสียงเดียวกัน)
**เวอร์ชันคลีน 100%: ไม่มีเสียงวืดๆ หรือเสียงลมสังเคราะห์คั่นระหว่างวรรคคำ!**
แบ่งเป็น 2 โหมดครบทั้ง 4 บท (รวม 8 ไฟล์ .wav 44.1kHz 16-bit):
  - โหมดสวดปกติ (Normal): จังหวะเนิบๆ สำรวม
  - โหมดสวดเร็วตอนเจอผี (Scared): สวดรัวเร็ว ลนลาน กลัวผี
"""

import asyncio
import math
import os
import shutil
import sys
import wave
from array import array

import edge_tts
import miniaudio

SR = 44100
TWO_PI = 2.0 * math.pi
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "assets",
    "sounds",
)

VOICE = "th-TH-NiwatNeural"

NORMAL_CHANTS = [
    {
        "filename": "chant_thai_1_kusala_normal.wav",
        "segments": [
            ("เอ้า ดึกดื่นค่อนคืนแล้ว ไหว้พระสวดมนต์เอาบุญเด้อพี่น้อง", "+8%", "-2Hz", 0.16),
            ("กุสะลา ธรรมา อะกุสะลา ธรรมา อัพพะยากะตา ธรรมา", "+6%", "-2Hz", 0.16),
            ("กะตะเม ธรรมา กุสะลา ยัสสะมิง สะมะเย กามาวะจะรัง กุสะลัง จิตตัง อุปปันนัง โหติ", "+8%", "-2Hz", 0.16),
            ("กุสะลา ธรรมา อะกุสะลา ธรรมา สาธุเด้อ ให้มีความสุขความเจริญ อยู่ดีมีแฮงเด้อ", "+8%", "-2Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_2_anicca_normal.wav",
        "segments": [
            ("สวดบังสุกุล อุทิศส่วนกุศลให้เจ้ากรรมนายเวรเด้อสู", "+8%", "-2Hz", 0.16),
            ("อะนิจจา วะตะ สังขารา อุปปาทะวะยะธัมมิโน", "+6%", "-2Hz", 0.16),
            ("อุปปัชชิตตะวา นิรุชฌันติ เตสัง วูปะสะโม สุโข", "+6%", "-2Hz", 0.16),
            ("สัพเพ สัตตา มะรันติ จะ มะริงสุ จะ มะริสสะเร สาธุเด้อ", "+8%", "-2Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_3_phra_malai_normal.wav",
        "segments": [
            ("ตั้งใจฟังธรรมะ สวดแผ่เมตตาให้สรรพสัตว์ทั้งหลายเด้อพี่น้อง", "+8%", "-2Hz", 0.16),
            ("สัพเพ สัตตา อะเวรา โหนตุ อัพพะยาปัชฌา โหนตุ", "+6%", "-2Hz", 0.16),
            ("อะนีฆา โหนตุ สุขี อัตตานัง ปะริหะรันตุ", "+6%", "-2Hz", 0.16),
            ("อิทัง สัพพะเทวะตานัง โหตุ สุขิตา โหนตุ สัพเพ เทวา อยู่เย็นเป็นสุขเด้อ", "+8%", "-2Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_4_namo_tassa_normal.wav",
        "segments": [
            ("เอ้า พนมมือขึ้น ตั้งนะโมสามจบพร้อมกันเด้อพี่น้อง", "+8%", "-2Hz", 0.16),
            ("นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ", "+6%", "-2Hz", 0.16),
            ("นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ", "+6%", "-2Hz", 0.16),
            ("นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ สาธุเด้อ", "+8%", "-2Hz", 0.10),
        ],
    },
]

SCARED_CHANTS = [
    {
        "filename": "chant_thai_1_kusala_scared.wav",
        "legacy_alias": "chant_thai_1_kusala_abhidhamma.wav",
        "segments": [
            ("เฮ้ย! ผีอีหลีตั้วนี่! ตั้งสติเด้อบักหำ สวดมนต์เร็วๆ!", "+30%", "+2Hz", 0.08),
            ("กุสะลาธรรมา อะกุสะลาธรรมา อัพพะยากะตาธรรมา! กุสะลาธรรมา อะกุสะลาธรรมา อัพพะยากะตาธรรมา!", "+46%", "+3Hz", 0.08),
            ("กะตะเม ธรรมา กุสะลา! ผีสางนางไม้ อย่ามาหลอกมาหลอนข่อยเด้อ ข่อยย่านแล้ว!", "+40%", "+4Hz", 0.08),
            ("กุสะลาธรรมา อะกุสะลาธรรมา สาธุเด้อหลวงปู่ อย่าให้มันเข้ามาในร้านข่อยเด้อ!", "+38%", "+3Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_2_anicca_scared.wav",
        "legacy_alias": "chant_thai_2_anicca_bangsukul.wav",
        "segments": [
            ("เฮ้ย! เงาดำๆ ย่างมาพุ่นแล้ว สวดบังสุกุลไล่มันเร็วๆ สู!", "+30%", "+2Hz", 0.08),
            ("อะนิจจา วะตะ สังขารา อุปปาทะวะยะธัมมิโน! อุปปัชชิตตะวา นิรุชฌันติ เตสัง วูปะสะโม สุโข!", "+45%", "+3Hz", 0.08),
            ("อะนิจจา วะตะ สังขารา ไปที่ชอบที่ชอบสาเด้อ ข่อยแค่มาเฝ้าปั๊มหลอด บ่ได้เฮ็ดหยังผิดเด้อ!", "+40%", "+4Hz", 0.08),
            ("อุปปัชชิตตะวา นิรุชฌันติ เตสัง วูปะสะโม สุโข ไปผุดไปเกิดสาเด้อ อย่ามาหลอกข่อยเลย!", "+40%", "+3Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_3_phra_malai_scared.wav",
        "legacy_alias": "chant_thai_3_phra_malai_am_radio.wav",
        "segments": [
            ("ห๊า! แม่นผีอีหลีแล้วบาดหนิ! สวดแผ่เมตตาเร็วๆ เด้อพี่น้อง!", "+32%", "+2Hz", 0.08),
            ("สัพเพ สัตตา อะเวรา โหนตุ อัพพะยาปัชฌา โหนตุ อะนีฆา โหนตุ สุขี อัตตานัง ปะริหะรันตุ!", "+46%", "+3Hz", 0.08),
            ("อิทัง สัพพะเทวะตานัง โหตุ สุขิตา โหนตุ สัพเพ เทวา บุญกุศลข่อยยกให้เบิดเลยเด้อ!", "+42%", "+4Hz", 0.08),
            ("สัพเพ สัตตา อะเวรา โหนตุ ต่างคนต่างอยู่เด้อ อย่ามาแล่ลิ้นปลิ้นตาใส่ข่อยเลย ซอยข่อยแน!", "+40%", "+3Hz", 0.10),
        ],
    },
    {
        "filename": "chant_thai_4_namo_tassa_scared.wav",
        "legacy_alias": "chant_thai_4_namo_tassa.wav",
        "segments": [
            ("โอ๊ย ขนคีงลุกเบิดแล้วสูเอ๊ย! พนมมือตั้งนะโมสามจบเร็วๆ เด้อ!", "+32%", "+2Hz", 0.08),
            ("นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ! นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ!", "+48%", "+3Hz", 0.08),
            ("นะโม ตัสสะ ภะคะวะโต อะระหะโต สัมมาสัมพุทธัสสะ! พุทธังกันตัง ธัมมังกันตัง สังฆังกันตัง!", "+48%", "+4Hz", 0.08),
            ("หลวงปู่ทวด หลวงพ่อคูณ ซอยลูกช้างแนเด้อ ผีอย่าเข้ามาใกล้ข่อยเด้อ สาธุ สาธุ!", "+38%", "+3Hz", 0.10),
        ],
    },
]


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


def resample_clean(buf: array, ratio: float) -> array:
    n_in = len(buf)
    if abs(ratio - 1.0) < 1e-4 or n_in < 4:
        return buf
    n_out = int(n_in / ratio)
    out = array("f", [0.0]) * n_out
    for i in range(n_out):
        pos = i * ratio
        idx = int(pos)
        if idx >= n_in - 2:
            break
        frac = pos - idx
        out[i] = buf[idx] * (1.0 - frac) + buf[idx + 1] * frac
    return out


def save_wav(filename: str, buf: array, label: str, max_peak: float = 0.78) -> str:
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, filename)
    # Crisp natural lowpass at 4600Hz so voice is clear, natural, not muffled, and never harsh
    buf = lowpass_1pole(buf, 4600.0)
    n = len(buf)
    fade = min(int(SR * 0.02), max(1, n // 15))
    peak = max(1e-6, max(abs(x) for x in buf))
    scale = max_peak / max(peak, 0.05)

    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        pcm = array("h")
        for i, x in enumerate(buf):
            env = 1.0
            if i < fade:
                env = i / float(fade)
            elif i > n - fade:
                env = (n - i) / float(fade)
            v = math.tanh(x * scale * env) * 0.95
            pcm.append(int(max(-32767, min(32767, v * 32767.0))))
        wf.writeframes(pcm.tobytes())
    print(f"  [OK] {filename} ({n / SR:.1f}s - {label})")
    return path


async def synth_segment_pcm(text: str, rate: str, pitch: str) -> array:
    comm = edge_tts.Communicate(text=text, voice=VOICE, rate=rate, pitch=pitch)
    mp3_bytes = bytearray()
    async for chunk in comm.stream():
        if chunk["type"] == "audio":
            mp3_bytes.extend(chunk["data"])

    decoded = miniaudio.decode(
        bytes(mp3_bytes),
        output_format=miniaudio.SampleFormat.SIGNED16,
        nchannels=1,
        sample_rate=SR,
    )
    out = array("f", [s / 32768.0 for s in decoded.samples])

    # Trim silence cleanly with smooth 15ms micro-fade at edges so there is ZERO click or whoosh between segments
    start_idx = 0
    end_idx = len(out)
    thresh = 0.008
    while start_idx < end_idx and abs(out[start_idx]) < thresh:
        start_idx += 1
    while end_idx > start_idx and abs(out[end_idx - 1]) < thresh:
        end_idx -= 1
    trimmed = out[start_idx:end_idx]
    m_fade = min(int(0.015 * SR), len(trimmed) // 4)
    for i in range(m_fade):
        g = i / float(m_fade)
        trimmed[i] *= g
        trimmed[len(trimmed) - 1 - i] *= g
    return trimmed  # ZERO time-stretching/resampling so audio is never stretched!


async def build_set(chant_list: list, label: str):
    for ch in chant_list:
        full_buf = array("f")
        for text, rate, pitch, pause_s in ch["segments"]:
            seg_pcm = await synth_segment_pcm(text, rate, pitch)
            full_buf.extend(seg_pcm)
            # คั่นด้วยความเงียบสะอาด 100% (ไม่มีเสียงวืดๆ!)
            if pause_s > 0:
                full_buf.extend(array("f", [0.0]) * int(pause_s * SR))

        saved_path = save_wav(ch["filename"], full_buf, label=label)
        if "legacy_alias" in ch:
            alias_path = os.path.join(OUT_DIR, ch["legacy_alias"])
            shutil.copyfile(saved_path, alias_path)


async def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    print("🙏 กำลังสร้างเสียงสวดมนต์คลีนๆ (ไร้เสียงวืดคั่นวรรค 100%) ทั้งโหมดปกติและโหมดเจอผี...")
    await build_set(NORMAL_CHANTS, label="สวดปกติ คลีน ไม่มีเสียงวืด")
    await build_set(SCARED_CHANTS, label="สวดเร็วกลัวผี คลีน ไม่มีเสียงวืด")
    print(f"✅ อัปเดตไฟล์สวดมนต์ทั้ง 8 ไฟล์เรียบร้อยที่: {OUT_DIR}")


if __name__ == "__main__":
    asyncio.run(main())
