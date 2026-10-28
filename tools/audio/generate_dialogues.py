#!/usr/bin/env python3
"""
tools/audio/generate_dialogues.py
สร้างชุดไฟล์เสียงพากย์บทสนทนา (Voice Dialogues) + เสียงอุทาน/หนาวสั่น/หวาดกลัว (Vocal Reactions)
ของเกม "ปั๊มหลอดท้ายทุ่ง"

กฎสำคัญตามที่ผู้ใช้ต้องการ:
1. **ไม่มีเสียงวืดๆ ระหว่างวรรคคำ 100%** (ไม่แทรกคลื่นลมสังเคราะห์ ไม่ตัดประโยคเป็นชิ้นย่อยแล้วยัด noise คั่น)
2. **แต่ละตัวละครและเพศมีโทนเสียงต่างกันชัดเจนและเป็นธรรมชาติ** (ใช้ Clean Formant Resampling + Warm Chest EQ):
   - ลุงสมหมาย (Sommai - ชายสูงวัย), พี่บุญมี (Boonmee - ชายวัยกลางคน), น้องต้น (Ton - หนุ่มวัยรุ่น)
   - ป้าแช่ม (Chaem - หญิงวัยกลางคน), ยายปริก (Prik - หญิงชรา), พี่แดง (Daeng), น้าน้อย (Noi)
   - ขาจร: เด็กแว้น (Racer), สาวโคโยตี้ (Coyote)
   - ผู้เล่นชาย (Player_M) & ผู้เล่นหญิง (Player_F) แยกโทนเสียงชาย-หญิงชัดเจน
3. **เพิ่มเสียงอุทานที่ไม่ใช่ประโยคยาว & เสียงอารมณ์ความรู้สึก (ทั้งชาย _M และหญิง _F)**:
   - เสียงตกใจ/สงสัย: "เฮ้ย!", "ห๊า?!", "อ้าว!", "เอ๊ะ...", "หือ?"
   - เสียงหนาวสั่น (ปากสั่น อือออ... บรื๋อ หนาวๆ)
   - เสียงหวาดกลัว/ผวา (เฮือก! / อ๊าก! / ช่วยด้วย!)
"""

import asyncio
import math
import os
import sys
import wave
from array import array

import edge_tts
import miniaudio

SR = 44100
TWO_PI = 2.0 * math.pi
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOUNDS_DIR = os.path.join(BASE_DIR, "assets", "sounds")
DIALOGUES_DIR = os.path.join(SOUNDS_DIR, "dialogues")
REACTIONS_DIR = os.path.join(SOUNDS_DIR, "reactions")

VOICE_M = "th-TH-NiwatNeural"
VOICE_F = "th-TH-PremwadeeNeural"

# ==============================================================================
# 1. โปรไฟล์เสียงของแต่ละตัวละคร (Clean Natural Timbre - ไร้เสียงวืดสังเคราะห์)
# ==============================================================================
PROFILES = {
    "Sommai": {      # ลุงสมหมาย (ชายสูงวัย ~60 ปี เสียงทุ้มลึก อบอุ่น ไม่ยืดเวลา)
        "voice": VOICE_M, "tts_rate": "+10%", "tts_pitch": "-6Hz",
        "resample": 1.0, "chest_boost": 0.28, "lp": 4400.0,
    },
    "Boonmee": {     # พี่บุญมี (ชาวนาชายวัยกลางคน ~40 ปี เสียงผู้ชายไทยบ้าน)
        "voice": VOICE_M, "tts_rate": "+12%", "tts_pitch": "-2Hz",
        "resample": 1.0, "chest_boost": 0.20, "lp": 4600.0,
    },
    "Ton": {         # น้องต้น (หนุ่มวัยรุ่น/นักศึกษา ~19 ปี พูดไวขึ้น เสียงหนุ่ม)
        "voice": VOICE_M, "tts_rate": "+16%", "tts_pitch": "+4Hz",
        "resample": 1.0, "chest_boost": 0.08, "lp": 4800.0,
    },
    "Chaem": {       # ป้าแช่ม (หญิงวัยกลางคน ~50 ปี เสียงป้าใจดี)
        "voice": VOICE_F, "tts_rate": "+10%", "tts_pitch": "-4Hz",
        "resample": 1.0, "chest_boost": 0.20, "lp": 4500.0,
    },
    "Prik": {        # ยายปริก (หญิงสูงวัย ~68 ปี แวะหลบฝน ไม่ยืดเวลา)
        "voice": VOICE_F, "tts_rate": "+8%", "tts_pitch": "-7Hz",
        "resample": 1.0, "chest_boost": 0.26, "lp": 4300.0,
    },
    "Daeng": {       # พี่แดง (ชายแวะหลบฝน ~35 ปี)
        "voice": VOICE_M, "tts_rate": "+12%", "tts_pitch": "+0Hz",
        "resample": 1.0, "chest_boost": 0.16, "lp": 4600.0,
    },
    "Noi": {         # น้าน้อย (หญิงแวะหลบฝน ~35 ปี)
        "voice": VOICE_F, "tts_rate": "+12%", "tts_pitch": "+1Hz",
        "resample": 1.0, "chest_boost": 0.12, "lp": 4700.0,
    },
    "Racer": {       # เด็กแว้น (หนุ่มวัยรุ่นคึกคะนอง)
        "voice": VOICE_M, "tts_rate": "+22%", "tts_pitch": "+5Hz",
        "resample": 1.0, "chest_boost": 0.08, "lp": 4800.0,
    },
    "Coyote": {      # สาวโคโยตี้ (หญิงสาววัยรุ่น)
        "voice": VOICE_F, "tts_rate": "+16%", "tts_pitch": "+4Hz",
        "resample": 1.0, "chest_boost": 0.08, "lp": 4800.0,
    },
    "Player_M": {    # ผู้เล่นชาย
        "voice": VOICE_M, "tts_rate": "+14%", "tts_pitch": "+1Hz",
        "resample": 1.0, "chest_boost": 0.16, "lp": 4700.0,
    },
    "Player_F": {    # ผู้เล่นหญิง
        "voice": VOICE_F, "tts_rate": "+14%", "tts_pitch": "+2Hz",
        "resample": 1.0, "chest_boost": 0.10, "lp": 4750.0,
    },
    "Ghost_M": {     # ผีผู้ชาย (ทุ้มเย็น ชัดเจน ไม่ยืดเสียง)
        "voice": VOICE_M, "tts_rate": "+6%", "tts_pitch": "-8Hz",
        "resample": 1.0, "chest_boost": 0.28, "lp": 4200.0,
    },
    "Ghost_F": {     # ผีผู้หญิง (เย็นยะเยือก ชัดเจน ไม่ยืดเสียง)
        "voice": VOICE_F, "tts_rate": "+6%", "tts_pitch": "-7Hz",
        "resample": 1.0, "chest_boost": 0.22, "lp": 4300.0,
    },
}


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


def shape_character_voice(buf: array, profile_name: str, shiver: bool = False) -> array:
    """
    ปรับโทนเสียงตามตัวละครแบบคลีน 100% (ไม่ทำ Time-Stretch / ไม่แกว่ง Tremolo ยืดเสียง)
    """
    prof = PROFILES[profile_name]
    work = buf
    n = len(work)

    # Warm chest EQ (110 - 360 Hz) so voice sounds full-bodied and natural
    chest = lowpass_1pole(highpass_1pole(work, 110.0), 360.0)
    c_gain = prof.get("chest_boost", 0.16)

    out = array("f", [0.0]) * n
    for i in range(n):
        v = work[i] + chest[i] * c_gain
        out[i] = math.tanh(v * 1.08)

    return lowpass_1pole(highpass_1pole(out, 90.0), prof.get("lp", 4600.0))


def save_wav(path: str, buf: array, max_peak: float = 0.78):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = len(buf)
    fade = min(int(SR * 0.018), max(1, n // 15))
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


SEM = asyncio.Semaphore(4)


async def synth_clean_line(text: str, profile_name: str, shiver: bool = False, rate_override: str = None, pitch_override: str = None) -> array:
    prof = PROFILES[profile_name]
    rate_str = rate_override or prof["tts_rate"]
    pitch_str = pitch_override or prof["tts_pitch"]

    out = None
    async with SEM:
        for attempt in range(6):
            try:
                q_text = text if attempt < 2 else text.replace("?!", "").replace("!", "").replace("?", "").strip()
                q_rate = rate_str if attempt < 3 else "+0%"
                q_pitch = pitch_str if attempt < 3 else "+0Hz"
                comm = edge_tts.Communicate(text=q_text, voice=prof["voice"], rate=q_rate, pitch=q_pitch)
                mp3_bytes = bytearray()
                async for chunk in comm.stream():
                    if chunk["type"] == "audio":
                        mp3_bytes.extend(chunk["data"])
                if len(mp3_bytes) > 200:
                    decoded = miniaudio.decode(
                        bytes(mp3_bytes),
                        output_format=miniaudio.SampleFormat.SIGNED16,
                        nchannels=1,
                        sample_rate=SR,
                    )
                    out = array("f", [s / 32768.0 for s in decoded.samples])
                    await asyncio.sleep(0.03)
                    break
            except Exception:
                await asyncio.sleep(0.4 * (attempt + 1))

    if out is None or len(out) == 0:
        out = array("f", [0.0]) * int(0.8 * SR)

    # Trim leading/trailing silence cleanly
    s_i, e_i = 0, len(out)
    while s_i < e_i and abs(out[s_i]) < 0.006:
        s_i += 1
    while e_i > s_i and abs(out[e_i - 1]) < 0.006:
        e_i -= 1
    pad = int(0.015 * SR)
    s_i = max(0, s_i - pad)
    e_i = min(len(out), e_i + pad)
    trimmed = out[s_i:e_i]

    return shape_character_voice(trimmed, profile_name, shiver=shiver)


# ==============================================================================
# 2. เสียงอุทานสั้นๆ / เสียงหนาวสั่น / เสียงหวาดกลัวผวา (Reactions - ชาย & หญิง)
# ==============================================================================
REACTION_JOBS = [
    # --- เสียงอุทานตกใจ "เฮ้ย!" ---
    ("React_Startle_Huh_M1", "เฮ้ย!", "Player_M", False, "+22%", "+5Hz"),
    ("React_Startle_Huh_M2", "เฮ้ย! อีหยังวะ!", "Boonmee", False, "+22%", "+4Hz"),
    ("React_Startle_Huh_F1", "เฮ้ย!", "Player_F", False, "+22%", "+5Hz"),
    ("React_Startle_Huh_F2", "ว้าย! ตกใจเบิดเลย!", "Chaem", False, "+20%", "+4Hz"),

    # --- เสียงอุทานสงสัย/ไม่เชื่อสายตา "ห๊า?!" / "เอ๊ะ?" / "หือ?" ---
    ("React_Question_Haa_M1", "ห๊า?!", "Player_M", False, "+18%", "+6Hz"),
    ("React_Question_Haa_M2", "ห๊า แม่นติ?", "Ton", False, "+18%", "+5Hz"),
    ("React_Question_Haa_F1", "ห๊า?!", "Player_F", False, "+18%", "+6Hz"),
    ("React_Question_Haa_F2", "ห๊า อีหยังเกาะ?", "Noi", False, "+18%", "+5Hz"),
    ("React_Confused_Hmm_M", "หือ? เอ๊ะ?", "Player_M", False, "+16%", "+3Hz"),
    ("React_Confused_Hmm_F", "หือ? เอ๊ะ?", "Player_F", False, "+16%", "+3Hz"),
    ("React_Shock_Aow_M", "อ้าว! เฮ้ย!", "Sommai", False, "+18%", "+3Hz"),
    ("React_Shock_Aow_F", "อ้าว! ตายแล้ว!", "Chaem", False, "+18%", "+4Hz"),

    # --- เสียงหนาวสั่น (กระชับ ชัดเจน ไม่ยืดเสียง) ---
    ("React_Cold_Shiver_M1", "บรื๋อ! หนาวคักแท้!", "Player_M", False, "+14%", "+2Hz"),
    ("React_Cold_Shiver_M2", "ฮึ่ย! หนาวสั่นไปเบิดแล้ว!", "Ton", False, "+16%", "+3Hz"),
    ("React_Cold_Shiver_F1", "บรื๋อ! หนาวสั่นเลย!", "Player_F", False, "+14%", "+2Hz"),
    ("React_Cold_Shiver_F2", "ฮึ่ย! ลมหนาวพัดมาขนลุกเลย!", "Noi", False, "+16%", "+3Hz"),

    # --- เสียงหวาดกลัว / ผวา (กระชับ รัวเร็ว ไม่ยืดเสียง) ---
    ("React_Fear_Panic_M1", "เฮ้ย! อย่าเข้ามาเด้อ! ออกไป!", "Player_M", False, "+24%", "+5Hz"),
    ("React_Fear_Panic_M2", "โอ๊ย! ข่อยย่านแล้ว! ซอยข่อยแน!", "Ton", False, "+26%", "+6Hz"),
    ("React_Fear_Panic_F1", "เฮ้ย! อย่าเข้ามาใกล้ข่อยเด้อ! ออกไป!", "Player_F", False, "+24%", "+5Hz"),
    ("React_Fear_Panic_F2", "ว้าย! ซอยแนจ้า ข่อยย่านแล้ว!", "Player_F", False, "+26%", "+6Hz"),
    ("React_Fear_Tremble_M", "เฮ้ย อีหยังอยู่ข้างหลังวะนั่น!", "Player_M", False, "+18%", "+4Hz"),
    ("React_Fear_Tremble_F", "เอ๊ะ อีหยังยืนอยู่ข้างหลังน่ะ!", "Player_F", False, "+18%", "+4Hz"),
]

# ==============================================================================
# 3. บทสนทนาทั้งหมดในเกม (Clean, Natural, No Whoosh Noise Between Clauses)
# ==============================================================================
DIALOGUE_JOBS = [
    # --- ลูกค้าประจำ 4 คน (ทักทาย & สั่งน้ำมัน) ---
    ("Greet_Uncle", "เออ หลาน ยังบ่ปิดร้านอีกติ ดึกแล้วเด้นี่", "Sommai"),
    ("Normal_Uncle", "บักหำ เติมเบนซินให้ลุงหลอดนึงแน ลุงสิฟ้าวไปวิดน้ำเข้านา!", "Sommai"),

    ("Greet_Aunt", "สวัสดีจ้ะลูก คืนนี้คือหนาวคักแท้น้อ", "Chaem"),
    ("Normal_Aunt", "เติมให้ป้าแนลูก ป้าสิฟ้าวไปตลาดแต่เซ้า", "Chaem"),

    ("Greet_Student", "สวัสดีครับอ้าย ร้านยังเปิดอยู่แม่นบ่ครับ", "Ton"),
    ("Normal_Student", "อ้ายครับ เติมหลอดนึงเด้อครับ เดี๋ยวอีแม่ด่าว่ากลับบ้านดึก", "Ton"),

    ("Greet_Farmer", "ว่าจั่งได๋น้อง ขอแวะเติมน้ำมันแนเด้อ", "Boonmee"),
    ("Normal_Farmer", "เติมเต็มหลอดเลยน้อง มื้ออื่นต้องเอารถไปไถนาแต่เซ้า", "Boonmee"),

    # --- ประโยคผีแต่ละแบบ (แยกชาย/หญิงตามตัวผี) ---
    ("Anomaly_Headless", "อ้าย เติมน้ำมันให้เต็มหลอดเลยครับ เป็นหยังมื้อนี้รถข่อยมันคือหนักๆ ชอบกล", "Ghost_M"),
    ("Anomaly_Cemetery", "เติมน้ำมันให้แนจ้ะ ทางข้างหน้า มันมืดคักอีหลี", "Ghost_F"),
    ("Anomaly_Cremate", "ขอน้ำมันเต็มหลอดแนจ้ะ สิเอาไปราดเผาศพเจ้าของอยู่เมรุ ฮ่าๆๆ", "Ghost_F"),
    ("Anomaly_WheelHair", "เติมน้ำมันให้แน ล้อรถมันคือหนักๆ คือจั่งมีคนดึงไว้เลย", "Ghost_F"),
    ("Anomaly_NeckTwist", "เติมหลอดนึงครับ ข้างหลังข่อยมีหยังเกาะอยู่ติ เป็นหยังคือแนมบ่เห็นทางเลย", "Ghost_M"),
    ("Anomaly_CreepySmile", "เติมน้ำมันให้แนติล่ะ ยิ้มให้กันแนกะได้เด้อ หึหึหึ", "Ghost_M"),
    ("Anomaly_Krasue", "ขอน้ำมันแนจ้ะหล่า คืนนี้ ป้าหิวแฮงอีหลี", "Ghost_F"),
    ("Anomaly_MonkRadio", "เติมหลอดนึงครับ วิทยุร้านนี้ เปิดเพลงม่วนดีเนาะ", "Ghost_M"),
    ("Anomaly_Tani", "เติมน้ำมันให้แน ผู้สาวที่ยืนอยู่กอกล้วยพุ่น เพิ่นถ่าไผอยู่น้อ", "Ghost_M"),
    ("Anomaly_Scarecrow", "เติมเต็มหลอดเลย หุ่นไล่กาโตนั้น มันย่างตามข่อยมาแต่หัวทุ่งพุ่น", "Ghost_M"),
    ("Anomaly_BloodFuel", "เติมน้ำมันสีแดงๆ นั่นให้แน คือหอมคักแท้", "Ghost_F"),
    ("Anomaly_NoUmbrella", "ฝนตกติ บ่เห็นฮู้สึกหยังเลย เติมให้แนติล่ะ", "Ghost_F"),

    # --- สั่งดีเซล / ตุ๊กตุ๊ก / จักรยาน / คนเดินถือแกลลอน ---
    ("Car_Order_1", "เติมดีเซลให้แน มื้ออื่นต้องขับเข้าเมืองแต่เซ้า", "Boonmee"),
    ("Car_Order_2", "ขอดีเซลเต็มถังเลยเด้อ สิขนผักไปส่งตลาดอีกรอบ", "Sommai"),
    ("Car_Order_3", "เติมดีเซลให้แน ปั๊มใหญ่ในเมืองเพิ่นปิดเบิดแล้ว", "Daeng"),
    ("TukTuk_Order_1", "เติมหลอดนึงเด้อ มื้ออื่นต้องแล่นรับแขกแต่เซ้า", "Sommai"),
    ("TukTuk_Order_2", "เติมเบนซินหลอดนึง ตุ๊กตุ๊กคันนี้กินน้ำมันคักอีหลี", "Boonmee"),
    ("Bicycle_Order_1", "ยางแบนกลางทาง ขอเติมลมแนเด้อ จูงมาตั้งไกล", "Ton"),
    ("Bicycle_Order_2", "ขอเติมลมยางจักรยานแนจ้ะ มื้ออื่นต้องปั่นไปโรงเรียน", "Noi"),
    ("Walker_Order_1", "ขอซื้อใส่แกลลอนแนเด้อ รถไถจอดเพอยู่ปากทาง น้ำมันเบิดพอดี", "Boonmee"),
    ("Walker_Order_2", "เติมใส่แกลลอนให้แน สิเอาไปเติมเครื่องสูบน้ำเข้านา", "Sommai"),
    ("Walker_Order_3", "ขอหลอดนึงใส่แกลลอนแนจ้ะ มอไซค์ลูกชายน้ำมันเบิดกลางทาง", "Chaem"),
    ("Walker_Order_4", "เติมใส่แกลลอนแนครับ มื้ออื่นสิตัดหญ้าหน้าบ้านแต่เซ้า", "Ton"),
    ("Walker_Order_Rain_1", "ฝนตกไฟดับเบิดหมู่บ้านเลย ขอซื้อไปเติมเครื่องปั่นไฟแนเด้อ", "Boonmee"),
    ("Walker_Order_Rain_2", "รถจอดเสียอยู่ข้างทาง ฝนกะตก ขอแกลลอนนึงไปเติมแนจ้ะ", "Chaem"),

    # --- ถามราคา / ตอบรับราคา / จ่ายเงิน / ท้วงเติมผิดตู้ (แยกเสียงชาย _M และหญิง _F ให้ครบ!) ---
    ("AskPrice_M", "คืนนี้หลอดละจักบาทล่ะน้อง?", "Boonmee"),
    ("AskPrice_F", "คืนนี้หลอดละจักบาทล่ะลูก?", "Chaem"),
    ("AskPriceDiesel_M", "ดีเซลเต็มถังคืนนี้จักบาทล่ะ?", "Sommai"),
    ("AskPriceDiesel_F", "ดีเซลเต็มถังคืนนี้จักบาทล่ะจ้ะ?", "Chaem"),
    ("AskPriceAir_M", "เติมลมจักบาทครับอ้าย?", "Ton"),
    ("AskPriceAir_F", "เติมลมจักบาทจ้ะหล่า?", "Noi"),

    ("Price_Cheap_M", "ป๊าด ราคานี้เองติ ใจดีคักแท้!", "Boonmee"),
    ("Price_Cheap_F", "โห ราคานี้เองติลูก ใจดีอีหลีจ้ะ", "Chaem"),
    ("Price_Normal_M", "เออ ราคาเก่า โอเคเลยน้อง", "Boonmee"),
    ("Price_Normal_F", "ราคาเก่าเนาะ โอเคเลยจ้ะ", "Chaem"),
    ("Price_ExpensiveOk_M", "แพงขึ้นอีกแล้วติ เอ้า เอากะเอา", "Sommai"),
    ("Price_ExpensiveOk_F", "คือแพงขึ้นอีกล่ะ เอ้า เติมกะเติมจ้ะ", "Chaem"),
    ("Price_ExpensiveNo_M", "ห๊า! แพงโพด! บ่เติมดอก ไปปั๊มอื่นดีกว่า", "Boonmee"),
    ("Price_ExpensiveNo_F", "ว้าย แพงโพดจ้ะ! บ่เติมดีกว่าเนาะ", "Chaem"),
    ("Price_Silent_M", "เอ้า คือบ่ปากบ่เว้าล่ะ ซั้นเอาราคาเก่าเด้อ", "Sommai"),
    ("Price_Silent_F", "เอ๊ะ คือเงียบแท้ ซั้นเอาราคาเก่าเด้อจ้ะ", "Chaem"),

    ("Pay_1_M", "อ่ะ นี่เงินเด้อ ขอบใจหลายๆ", "Boonmee"),
    ("Pay_1_F", "นี่เงินจ้ะลูก ขอบใจหลายๆ เด้อ", "Chaem"),
    ("Pay_2_M", "เอ้า นี่เงิน บ่ต้องทอนเด้อหลาน", "Sommai"),
    ("Pay_2_F", "เอ้า นี่จ้ะ บ่ต้องทอนเด้อลูก", "Chaem"),
    ("Pay_3_M", "ขอบใจหลายครับ มื้ออื่นแวะมาใหม่เด้อ", "Ton"),
    ("Pay_3_F", "ขอบใจจ้ะ มื้ออื่นมาอุดหนุนใหม่เด้อ", "Noi"),
    ("Pay_Slow_M", "เฮ็ดซ่าคัก เอาท่อนี้พอนะ", "Sommai"),
    ("Pay_Slow_F", "ซ่าอีหลี เอาท่อนี้พอจ้ะ", "Chaem"),

    ("Wrong_NeedDiesel_M", "เฮ้ย เดี๋ยวๆ! รถข่อยใส่ดีเซลเด้อ ตู้นั้นมันเบนซินหลอด!", "Boonmee"),
    ("Wrong_NeedDiesel_F", "ว้าย เดี๋ยวๆ จ้ะ! รถป้าใส่ดีเซลเด้อลูก!", "Chaem"),
    ("Wrong_NeedPetrol_M", "เฮ้ย อันนั้นมันดีเซล! รถข่อยใส่เบนซินหลอดเด้อ", "Sommai"),
    ("Wrong_NeedPetrol_F", "เอ๊ะ อันนั้นมันดีเซลจ้ะ! รถฉันใส่เบนซินหลอดเด้อ", "Chaem"),
    ("Wrong_NeedAir_M", "อ้าว บ่ได้มาเติมน้ำมัน มาเติมลมยางเด้อครับ!", "Ton"),
    ("Wrong_NeedAir_F", "อ้าว บ่ได้มาเติมน้ำมันจ้ะ มาเติมลมยางซื่อๆ!", "Noi"),
    ("Wrong_NeedFuel_M", "ห๊า ลมยางยังดีอยู่ เติมน้ำมันให้แนติล่ะ", "Boonmee"),
    ("Wrong_NeedFuel_F", "เอ๊ะ ลมยางยังเต็มอยู่จ้ะ มาเติมน้ำมันเด้อ", "Chaem"),
    ("Wrong_GiveUp_M", "โธ่ เฮ็ดผิดอยู่นั่นล่ะ บ่เอาแล้ว ไปปั๊มอื่นดีกว่า!", "Sommai"),
    ("Wrong_GiveUp_F", "โอ๊ย เติมผิดอยู่นั่นล่ะ บ่เอาแล้วจ้ะ ไปดีกว่า", "Chaem"),

    # --- โดนปิดร้านใส่ / รอนาน / ทักสองคน ---
    ("Rejected_1_M", "เฮ้ย อ้าว! คือดึงสังกะสีปิดร้านใส่กันจั่งซี้ล่ะ!", "Boonmee"),
    ("Rejected_1_F", "ว้าย อ้าว! ปิดร้านใส่ป้าเฮ็ดหยังล่ะลูก!", "Chaem"),
    ("Rejected_2_M", "เอ้า บ่ขายกะบอกดีๆ ติล่ะ บ่เห็นต้องปิดใส่กันเลย", "Sommai"),
    ("Rejected_2_F", "อ้าว บ่ขายกะบ่ขายจ้ะ บ่ต้องปิดใส่กันปานนั้นกะได้", "Chaem"),
    ("Impatient_1_M", "ฟ้าวๆ แนได้บ่ ข่อยฟ้าวอยู่เด้อ", "Boonmee"),
    ("Impatient_1_F", "ฟ้าวเติมแนจ้ะลูก ป้าฟ้าวไปเด้อ", "Chaem"),
    ("Impatient_2_M", "เอ้า ยังบ่เติมอีกติ ยืนถ่าโดนแล้วเด้นี่", "Sommai"),
    ("Impatient_2_F", "คือยังบ่เติมอีกล่ะจ้ะ ถ่าโดนแล้วเด้อ", "Chaem"),
    ("Impatient_3_M", "เฮ้ย สิเติมบ่เติมหนิ! สิหนีแล้วเด้อ!", "Boonmee"),
    ("Impatient_3_F", "นี่ ตกลงสิเติมบ่จ้ะหนิ! สิไปแล้วเด้อ!", "Chaem"),
    ("Greet_Waited_M", "โอย ถ่าตั้งโดนแน่ะ คืนนี้คนหลายคักเนาะ", "Boonmee"),
    ("Greet_Waited_F", "โอย ถ่าคิวตั้งโดนจ้ะ คืนนี้ลูกค้าหลายเนาะ", "Chaem"),

    ("Alone_Normal_M", "ห๊า? สองคนหยังล่ะ ข่อยมาผู้เดียวเด้อ ง่วงแล้วบ้อเฮา", "Boonmee"),
    ("Alone_Normal_F", "ห๊า? สองคนไผล่ะลูก ป้ามาผู้เดียวเด้อ ตาฝาดแล้วบ้อ", "Chaem"),
    ("Alone_Ghost_M", "เฮ้ย เว้าหยังน่ะ ข่อยมาผู้เดียวเด้อ แต่เป็นหยังหลังมันคือเย็นๆ วะ", "Ton"),
    ("Alone_Ghost_F", "ว้าย เว้าหยังจ้ะลูก ป้ามาผู้เดียวเด้อ คือฮู้สึกหนักๆ หลังชอบกล", "Chaem"),
    ("Alone_Creepy_M", "ผู้เดียว ตอนนี้ยังผู้เดียวอยู่ หึหึ", "Ghost_M"),
    ("Alone_Creepy_F", "มาผู้เดียวจ้ะ เดี๋ยวอีกจักหน่อย กะได้ไปนำกันสองคนแล้ว", "Ghost_F"),
    ("Passenger_Whisper", "ชู่ว อย่าไปบอกลาวเด้อ เงียบๆ ไว้", "Ghost_F"),

    # --- ผีตอบราคา / ผีโดนไล่ / ผีตาม ---
    ("Ghost_Price_M", "จักบาทกะเอาโลด เงินทองมันบ่สำคัญแล้ว", "Ghost_M"),
    ("Ghost_Price_F", "ท่อใด๋กะได้จ้ะ เงินมันเอาไปนำบ่ได้ดอก", "Ghost_F"),
    ("Ghost_Pay_M", "ขอบใจ นี่เงิน เก็บไว้ดีๆ เด้อ หึหึ", "Ghost_M"),
    ("Ghost_Pay_F", "ขอบใจจ้ะ นี่เงิน เบิ่งดีๆ เด้อว่าเงินหรือใบไม้", "Ghost_F"),
    ("Ghost_Rejected_M", "เฮ้ย มึงฮู้ได้จั่งได๋วะ", "Ghost_M"),
    ("Ghost_Rejected_F", "หือ ฮู้ได้จั่งได๋ ว่าบ่แม่นคน", "Ghost_F"),
    ("Ghost_Chased", "แล่นตามมาเฮ็ดหยัง อยากไปอยู่ป่าช้านำกันติ!!", "Ghost_F"),
    ("Ghost_Wait", "บ่ต้องฟ้าว ข่อยถ่าได้ ถ่ามาหลายปีแล้ว", "Ghost_F"),
    ("Ghost_Wait2", "ถ่ามาโดนแล้ว โดนกว่าที่เจ้าคิดอีก", "Ghost_M"),
    ("NoOne_1_M", "เอ้า มีไผอยู่บ่นี่ คือเงียบแท้ ไปปั๊มอื่นละกัน", "Boonmee"),
    ("NoOne_1_F", "เอ๊ะ มีไผอยู่บ่จ้ะ เงียบคัก ไปปั๊มอื่นดีกว่า", "Chaem"),
    ("NoOne_2_M", "ร้านเปิดคือบ่มีคนอยู่วะ แปลกอีหลี", "Sommai"),
    ("NoOne_2_F", "ร้านเปิดแต่บ่มีคนเลย แปลกแท้ล่ะ", "Noi"),
    ("Ghost_NoOne", "บ่มีไผอยู่ ซั้นเดี๋ยวแวะกลับมาหาใหม่เด้อ", "Ghost_F"),

    # --- ฝนตก & คนแวะหลบฝน & ขาจรบนถนน ---
    ("RainTalk_1_M", "บรื๋อ ฝนตกแฮงอีหลี เปียกเบิดโตเลย", "Boonmee"),
    ("RainTalk_1_F", "อูย ฝนตกหนักคักจ้ะ เปียกไปเบิดเลย", "Chaem"),
    ("RainTalk_2_M", "ถนนมื่นคักคืนนี้ เกือบล้มแน่ะ", "Ton"),
    ("RainTalk_2_F", "ทางมื่นแฮงจ้ะคืนนี้ เกือบรถล้มแน่ะ", "Noi"),
    ("RainTalk_3_M", "ฟ้าร้องบาดใด๋ ไฟในหมู่บ้านดับสุเทื่อเลย", "Sommai"),
    ("RainTalk_3_F", "ฟ้าร้องทีไร ไฟดับเบิดบ้านทุกทีเลยจ้ะ", "Chaem"),
    ("Ghost_RainTalk", "ฝนติ บ่เห็นฮู้สึกว่าเปียกเลย", "Ghost_F"),

    ("Shelter_Ask_F", "ขอหลบฝนนำแนเด้อหล่า บ่ได้ซื้อหยังดอก เดี๋ยวฝนเซากะเมือแล้ว", "Prik"),
    ("Shelter_Ask_M", "ขอพึ่งชายคาหลบฝนแนเด้อครับ ฝนตกแฮงคัก", "Daeng"),
    ("ShelterGhost_Ask", "ขอยืนหลบฝนนำแนเด้อ ฝนตกจั่งซี้ บ่ฮู้สิไปไสเลย", "Ghost_F"),
    ("ShelterTalk_1", "ฝนตกแฮงปานนี้ ลูกค้าคือสิบ่ค่อยมีดอกเนาะ", "Prik"),
    ("ShelterTalk_2", "ฮู้บ่หล่า หม่องทางโค้งข้างหน้านั่น ตะกี้เคยเป็นป่าช้าเก่าเด้อ", "Prik"),
    ("ShelterTalk_3", "เถียงนากลางทุ่งพุ่นน่ะ คนแถวนี้บ่มีไผกล้าย่างไปยามมื้อคืนดอก", "Daeng"),
    ("ShelterTalk_4", "ร้านนี้เปิดดึกสุคืนเลยติ บ่ย่านผีแนบ้อ", "Noi"),
    ("ShelterTalk_5", "คันเห็นไผมาเติมน้ำมันยามฝนตก แต่โตแห้งสนิทบ่เปียกฝนเลยน่ะ อย่าไปเติมให้เขาเด้อหล่า", "Prik"),
    ("ShelterGhostTalk_1", "ฉันถ่ารถอยู่ ถ่ามาหลายปีแล้ว บ่มีไผรับเลย", "Ghost_F"),
    ("ShelterGhostTalk_2", "คืนนั้นกะฝนตกแฮงจั่งซี้ล่ะ ถนนมื่นคัก", "Ghost_F"),
    ("ShelterGhostTalk_3", "หือ เจ้าแนมเห็นฉันนำติ บ่ค่อยมีไผเห็นฉันดอกเด้อ", "Ghost_F"),
    ("Shelter_Leave", "เอ้า ฝนเซาแล้ว ขอบใจหลายเด้อที่ให้หลบฝน", "Prik"),
    ("ShelterGhost_Leave", "ฝนเซาแล้ว ฉันต้องไปแล้วล่ะเด้อ", "Ghost_F"),

    ("Shelter_ToCustomer_1", "ฝนตกแฮงเด้อ ขับดีๆ ล่ะ ถนนมันมื่น", "Prik"),
    ("Shelter_ToCustomer_2", "อ้าว มาเติมน้ำมันยามฝนตกแฮงจั่งซี้เลยติ", "Daeng"),
    ("Chat_Reply_1_M", "ขอบใจเด้อ ต้องฟ้าวเมือบ้านก่อนน้ำท่วมทาง", "Boonmee"),
    ("Chat_Reply_1_F", "ขอบใจจ้ะ ต้องฟ้าวกลับบ้านก่อนน้ำท่วมทาง", "Chaem"),
    ("Chat_Reply_2_M", "แม่นแล้ว คันน้ำมันบ่เบิดกะบ่ออกมาดอก", "Sommai"),
    ("Chat_Reply_2_F", "นั่นติล่ะจ้ะ คันน้ำมันบ่เบิดกะบ่ออกมาดอก", "Chaem"),
    ("Shelter_NoticeDry", "เอ๊ะ ฝนตกแฮงปานนี้ เป็นหยังโตลาวคือบ่เปียกเลยล่ะ", "Prik"),
    ("Ghost_DryReply", "เปียกติ บ่เคยเปียกฝนดอก", "Ghost_F"),
    ("ShelterGhost_ToCustomer", "ฟ้าวกลับบ้านเด้อ ก่อนสิเป็นคือจั่งฉัน", "Ghost_F"),
    ("Chat_WhoTalking_M", "ห๊า? เมื่อกี้ไผเว้าน่ะ บ่เห็นมีไผยืนอยู่เลย!", "Boonmee"),
    ("Chat_WhoTalking_F", "ว้าย! เมื่อกี้เสียงไผเว้าน่ะ บ่เห็นมีคนยืนอยู่เลย!", "Chaem"),
    ("Queue_Chime_M", "เฮ้ย ฟ้าวๆ แนเด้อ ถ่าคิวอยู่ข้างหลังนี่!", "Boonmee"),
    ("Queue_Chime_F", "ฟ้าวๆ แนจ้ะ ต่อคิวถ่าอยู่ข้างหลังเด้อ", "Chaem"),
    ("Queue_ChimeGhost", "บ่ต้องฟ้าว ข่อยถ่าได้", "Ghost_M"),

    ("Racer_Shout_1", "เฮ้ย ปั๊มผีแม่นบ่นี่ ฮ่าๆๆ เปิดดึกคักแท้!", "Racer"),
    ("Racer_Shout_2", "เฮ้ย เบิ่งนี่เด้อ! ยกล้อผ่านหน้าร้านเลยโว้ย!", "Racer"),
    ("Party_Line", "ไปไสกันจ๊ะคืนนี้ งานวัดบ้านพุ่นยังบ่เลิกเลย ไปนำกันบ่!", "Daeng"),
    ("Teen_Line", "จัดไปเลยอ้าย! เปิดเพลงดังๆ อีก!", "Racer"),
    ("Coyote_Line", "สวัสดีจ้า แวะมาทักทายซื่อๆ เด้อ บ่ได้มาเติมน้ำมันดอกจ้า", "Coyote"),
    ("Parade_Invite", "มื้ออื่นบวชลูกชายเด้อ! แวะไปกินข้าวต้มนำกันเด้อพี่น้อง!", "Sommai"),
    ("Parade_Cheer", "โห่ ฮิ้ววว! โห่ ฮิ้ววว!", "Racer"),

    # --- เสียงผู้เล่นพูดตอบลูกค้า (แยกผู้เล่นชาย _M และผู้เล่นหญิง _F คนละโทน!) ---
    ("PlayerHello_M", "สวัสดีครับ รับหยังดีครับผม", "Player_M"),
    ("PlayerHello_F", "สวัสดีจ้า รับหยังดีจ๊ะ", "Player_F"),
    ("PlayerGreetBoth_M", "สวัสดีครับผม มาสองคนดึกๆ เลยเนาะครับ", "Player_M"),
    ("PlayerGreetBoth_F", "สวัสดีจ้า มาด้วยกันสองคนเลยเนาะจ๊ะ", "Player_F"),
    ("PlayerQuote_80_M", "หลอดละแปดสิบบาทครับผม", "Player_M"),
    ("PlayerQuote_80_F", "หลอดละแปดสิบบาทจ้ะ", "Player_F"),
    ("PlayerQuote_100_M", "หลอดละร้อยบาทครับ", "Player_M"),
    ("PlayerQuote_100_F", "หลอดละร้อยบาทจ้า", "Player_F"),
    ("PlayerQuote_120_M", "คืนนี้หลอดละร้อยยี่สิบบาทครับ", "Player_M"),
    ("PlayerQuote_120_F", "คืนนี้หลอดละร้อยยี่สิบบาทจ้ะ", "Player_F"),
    ("PlayerQuote_250_M", "ดีเซลสองร้อยห้าสิบบาทครับ", "Player_M"),
    ("PlayerQuote_250_F", "ดีเซลสองร้อยห้าสิบบาทจ้า", "Player_F"),
    ("PlayerQuote_300_M", "ดีเซลเต็มถังสามร้อยบาทครับ", "Player_M"),
    ("PlayerQuote_300_F", "ดีเซลเต็มถังสามร้อยบาทจ้า", "Player_F"),
    ("PlayerQuote_350_M", "ดีเซลสามร้อยห้าสิบบาทครับผม", "Player_M"),
    ("PlayerQuote_350_F", "ดีเซลสามร้อยห้าสิบบาทจ้ะ", "Player_F"),
    ("PlayerQuote_10_M", "เติมลมสิบบาทครับ", "Player_M"),
    ("PlayerQuote_10_F", "เติมลมสิบบาทจ้า", "Player_F"),
    ("PlayerQuote_20_M", "เติมลมยี่สิบบาทครับผม", "Player_M"),
    ("PlayerQuote_20_F", "เติมลมยี่สิบบาทจ้ะ", "Player_F"),
    ("PlayerQuote_30_M", "เติมลมสามสิบบาทครับ", "Player_M"),
    ("PlayerQuote_30_F", "เติมลมสามสิบบาทจ้า", "Player_F"),

    # --- ลูกค้าทักคนพนมมือ & ผู้เล่นตอบ & เสียงกระซิบเรียกผี (Pray_*) ---
    ("Pray_Ask_1_M", "อ้าว พนมมือเฮ็ดหยังน่ะ?", "Boonmee"),
    ("Pray_Ask_1_F", "อ้าว พนมมือเฮ็ดหยังจ้ะลูก?", "Chaem"),
    ("Pray_Ask_2_M", "สวดมนต์อยู่ติ ดึกป่านนี้แล้วเด้", "Sommai"),
    ("Pray_Ask_2_F", "สวดมนต์อยู่ติลูก ดึกป่านนี้แล้ว", "Chaem"),
    ("Pray_Ask_3_M", "ขอหยังอยู่ล่ะนั่น?", "Boonmee"),
    ("Pray_Ask_3_F", "ขอหยังอยู่ล่ะจ้ะนั่น?", "Chaem"),
    ("Pray_Ask_4_M", "เห็นหยังเข้าติ ถึงได้ยืนพนมมือจั่งซั้น?", "Sommai"),
    ("Pray_Ask_4_F", "เห็นหยังเข้าติลูก ถึงได้ยืนพนมมือจั่งซั้น?", "Chaem"),
    ("Pray_Reply_1_M", "ขอให้คืนนี้ขายดีๆ แนครับ", "Player_M"),
    ("Pray_Reply_1_F", "ขอให้คืนนี้ขายดีๆ แนจ้ะ", "Player_F"),
    ("Pray_Reply_2_M", "ขอให้คืนนี้อย่าพ้อแนวแปลกๆ เลยครับ", "Player_M"),
    ("Pray_Reply_2_F", "ขอให้คืนนี้อย่าพ้อแนวแปลกๆ เลยจ้ะ", "Player_F"),
    ("Pray_Reply_3_M", "ไหว้เจ้าที่ไว้ก่อนครับ เดี๋ยวเพิ่นเคียด", "Player_M"),
    ("Pray_Reply_3_F", "ไหว้เจ้าที่ไว้ก่อนจ้ะ เดี๋ยวเพิ่นเคียด", "Player_F"),
    ("Pray_Reply_4_M", "นะโม ตัสสะ... เอ่อ บ่มีหยังดอกครับ", "Player_M"),
    ("Pray_Reply_4_F", "นะโม ตัสสะ... เอ่อ บ่มีหยังดอกจ้ะ", "Player_F"),
    ("Pray_After_1_M", "ดีๆ ไหว้ไว้ก่อน แถวนี้มันเฮี้ยนอีหลี", "Sommai"),
    ("Pray_After_1_F", "ดีแล้วลูก ไหว้ไว้ก่อน แถวนี้มันเฮี้ยนอีหลีจ้ะ", "Chaem"),
    ("Pray_After_2_M", "ฮ่าๆ ขอเผื่อข่อยนำเด้อ", "Boonmee"),
    ("Pray_After_2_F", "ฮ่าๆ ขอเผื่อป้านำเด้อลูก", "Chaem"),
    ("Pray_Ghost_1_M", "เซาสวดเดี๋ยวนี้...", "Ghost_M"),
    ("Pray_Ghost_1_F", "เซาสวดเดี๋ยวนี้...", "Ghost_F"),
    ("Pray_Ghost_2_M", "สวดไปกะบ่ซอยหยังดอก...", "Ghost_M"),
    ("Pray_Ghost_2_F", "สวดไปกะบ่ซอยหยังดอก...", "Ghost_F"),
    ("Pray_Ghost_3_M", "เอามือลงเถาะ... แนมเบิ่งข่อยดีๆ นี่", "Ghost_M"),
    ("Pray_Ghost_3_F", "เอามือลงเถาะ... แนมเบิ่งฉันดีๆ นี่", "Ghost_F"),
    ("Pray_GhostAfter_1_M", "ข่อยได้ยินเด้อ... สุคำเลย", "Ghost_M"),
    ("Pray_GhostAfter_1_F", "ฉันได้ยินเด้อ... สุคำเลย", "Ghost_F"),
    ("Pray_GhostAfter_2_M", "เสียงสวดมันแสบหู... แสบหูคักอีหลี", "Ghost_M"),
    ("Pray_GhostAfter_2_F", "เสียงสวดมันแสบหู... แสบหูคักอีหลี", "Ghost_F"),
    ("Pray_Summon_1", "ไผเอิ้นหาข่อย...", "Ghost_F"),
    ("Pray_Summon_2", "ได้ยินแล้ว... กำลังไปหา...", "Ghost_F"),
    ("Pray_Summon_3", "สวดให้ข่อยติ...", "Ghost_F"),
]


async def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(DIALOGUES_DIR, exist_ok=True)
    os.makedirs(REACTIONS_DIR, exist_ok=True)

    print(f"😱 กำลังสร้างเสียงอุทาน (เฮ้ย! / ห๊า?! / หนาวสั่น / หวาดกลัว) ชาย-หญิง {len(REACTION_JOBS)} ไฟล์...")
    batch_size = 8
    for b_start in range(0, len(REACTION_JOBS), batch_size):
        batch = REACTION_JOBS[b_start : b_start + batch_size]
        tasks = [
            synth_clean_line(text, prof, shiver=shiv, rate_override=ro, pitch_override=po)
            for (_k, text, prof, shiv, ro, po) in batch
        ]
        results = await asyncio.gather(*tasks)
        for (key, _text, prof, _shiv, _ro, _po), pcm in zip(batch, results):
            out_path = os.path.join(REACTIONS_DIR, f"{key}.wav")
            save_wav(out_path, pcm)
            print(f"  [OK] reactions/{key}.wav ({len(pcm)/SR:.2f}s | {prof})")

    print(f"🎙️ กำลังสร้างไฟล์เสียงพากย์บทสนทนาคลีนๆ (ไร้เสียงวืดคั่นวรรค) จำนวน {len(DIALOGUE_JOBS)} ไฟล์...")
    for b_start in range(0, len(DIALOGUE_JOBS), batch_size):
        batch = DIALOGUE_JOBS[b_start : b_start + batch_size]
        tasks = [synth_clean_line(text, prof) for (_k, text, prof) in batch]
        results = await asyncio.gather(*tasks)
        for (key, _text, prof), pcm in zip(batch, results):
            out_path = os.path.join(DIALOGUES_DIR, f"{key}.wav")
            save_wav(out_path, pcm)
            print(f"  [OK] dialogues/{key}.wav ({len(pcm)/SR:.2f}s | {prof})")

    print(f"✅ สร้างไฟล์เสียงทั้งหมดเสร็จสมบูรณ์! (ไร้เสียงวืด 100%)")


if __name__ == "__main__":
    asyncio.run(main())
