#!/usr/bin/env python3
import json
import os
import sys
import wave
import webbrowser

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, BASE)
from tools.audio.generate_dialogues import DIALOGUE_JOBS, REACTION_JOBS


def get_dur(rel_path: str) -> float:
    p = os.path.join(BASE, rel_path.replace("/", os.sep))
    if not os.path.exists(p):
        return 0.0
    try:
        with wave.open(p, "rb") as wf:
            return round(wf.getnframes() / float(wf.getframerate()), 1)
    except Exception:
        return 0.0


def main():
    chants = [
        {"key": "chant_thai_1_kusala_normal", "title": "บทที่ 1: กุสลา ธัมมา (สวดปกติ)", "desc": "สำเนียงอีสาน สวดเนิบๆ สำรวม คลีนไร้เสียงวืด", "path": "assets/sounds/chant_thai_1_kusala_normal.wav", "tag": "สวดปกติ"},
        {"key": "chant_thai_1_kusala_scared", "title": "บทที่ 1: กุสลา ธัมมา (เจอผี - สวดเร็ว!)", "desc": "โทนเสียงเดียวกัน แต่สวดรัวเร็ว ลนลาน กลัวผี!", "path": "assets/sounds/chant_thai_1_kusala_scared.wav", "tag": "เจอผี!"},
        {"key": "chant_thai_2_anicca_normal", "title": "บทที่ 2: อนิจจา วะตะ สังขารา (สวดปกติ)", "desc": "สำเนียงอีสาน สวดเนิบๆ สำรวม คลีนไร้เสียงวืด", "path": "assets/sounds/chant_thai_2_anicca_normal.wav", "tag": "สวดปกติ"},
        {"key": "chant_thai_2_anicca_scared", "title": "บทที่ 2: อนิจจา วะตะ สังขารา (เจอผี - สวดเร็ว!)", "desc": "โทนเสียงเดียวกัน แต่สวดรัวเร็ว ลนลาน กลัวผี!", "path": "assets/sounds/chant_thai_2_anicca_scared.wav", "tag": "เจอผี!"},
        {"key": "chant_thai_3_phra_malai_normal", "title": "บทที่ 3: สัพเพ สัตตา แผ่เมตตา (สวดปกติ)", "desc": "สำเนียงอีสาน สวดเนิบๆ สำรวม คลีนไร้เสียงวืด", "path": "assets/sounds/chant_thai_3_phra_malai_normal.wav", "tag": "สวดปกติ"},
        {"key": "chant_thai_3_phra_malai_scared", "title": "บทที่ 3: สัพเพ สัตตา แผ่เมตตา (เจอผี - สวดเร็ว!)", "desc": "โทนเสียงเดียวกัน แต่สวดรัวเร็ว ลนลาน กลัวผี!", "path": "assets/sounds/chant_thai_3_phra_malai_scared.wav", "tag": "เจอผี!"},
        {"key": "chant_thai_4_namo_tassa_normal", "title": "บทที่ 4: นะโม ตัสสะ 3 จบ (สวดปกติ)", "desc": "สำเนียงอีสาน สวดเนิบๆ สำรวม คลีนไร้เสียงวืด", "path": "assets/sounds/chant_thai_4_namo_tassa_normal.wav", "tag": "สวดปกติ"},
        {"key": "chant_thai_4_namo_tassa_scared", "title": "บทที่ 4: นะโม ตัสสะ 3 จบ (เจอผี - สวดเร็ว!)", "desc": "โทนเสียงเดียวกัน แต่สวดรัวเร็ว ลนลาน กลัวผี!", "path": "assets/sounds/chant_thai_4_namo_tassa_scared.wav", "tag": "เจอผี!"},
    ]

    road = [
        {"key": "sfx_racer_moto_rev_cut", "title": "🏍️ เด็กแว้นเบิ้ลท่อสูตรตัดรอบ", "desc": "เสียงเบิ้ลเครื่องตัดรอบ ปัง-ปัง! (ตัดแหลมไม่แสบหู)", "path": "assets/sounds/sfx_racer_moto_rev_cut.wav", "tag": "เด็กแว้น"},
        {"key": "sfx_racer_wheelie_pass", "title": "🏍️ เด็กแว้นยกล้อซิ่งผ่านหน้าร้าน", "desc": "เสียงยกล้อพุ่งผ่านหน้าร้าน (Doppler Fly-by)", "path": "assets/sounds/sfx_racer_wheelie_pass.wav", "tag": "เด็กแว้น"},
        {"key": "music_thai_dance_1_sai_yor", "title": "💃 เพลงแดนซ์ 1: สายย่อสามช่าโจ๊ะๆ", "desc": "เบสแน่นตึ๊บๆ จังหวะสามช่าสายย่อรถเครื่องเสียง", "path": "assets/sounds/music_thai_dance_1_sai_yor.wav", "tag": "เพลงแดนซ์"},
        {"key": "music_thai_dance_2_morlam_edm", "title": "💃 เพลงแดนซ์ 2: หมอลำซิ่ง EDM", "desc": "ลายพิณอีสานซิ่ง + เบส EDM รถกระบะเครื่องเสียง", "path": "assets/sounds/music_thai_dance_2_morlam_edm.wav", "tag": "เพลงแดนซ์"},
        {"key": "music_parade_1_rothe_isan", "title": "🎺 เพลงรถแห่ 1: รถแห่อีสานสามช่างานบวช", "desc": "พิณ + แคน + เบสเดิน + เสียงโห่ฮิ้วหน้าขบวน", "path": "assets/sounds/music_parade_1_rothe_isan.wav", "tag": "เพลงรถแห่"},
        {"key": "music_parade_2_klongyao_brass", "title": "🥁 เพลงรถแห่ 2: แตรวงกลองยาวแห่นาค", "desc": "กลองยาว ฉิ่ง ฉับ แตรวงงานบวชท้ายทุ่ง", "path": "assets/sounds/music_parade_2_klongyao_brass.wav", "tag": "เพลงรถแห่"},
    ]

    radio_haunt = [
        {"key": "radio_lukthung_1_lamnam_thung_mued", "title": "📻 วิทยุลูกทุ่ง 1: ลำนำทุ่งมืด", "desc": "ลูกทุ่งวินเทจเหงาๆ ผ่านลำโพงวิทยุ AM", "path": "assets/sounds/radio_lukthung_1_lamnam_thung_mued.wav", "tag": "วิทยุลูกทุ่ง"},
        {"key": "radio_lukthung_2_khlui_sao_tai_sai", "title": "📻 วิทยุลูกทุ่ง 2: ขลุ่ยเศร้าใต้ต้นไทร", "desc": "เสียงขลุ่ยไทยโหยหวนช้าๆ ยามดึก", "path": "assets/sounds/radio_lukthung_2_khlui_sao_tai_sai.wav", "tag": "วิทยุลูกทุ่ง"},
        {"key": "radio_lukthung_3_winyan_rak_nak_leng", "title": "📻 วิทยุลูกทุ่ง 3: วิญญาณรักท้ายทุ่ง", "desc": "ลูกคอเอื้อนเทปยานหลอนๆ", "path": "assets/sounds/radio_lukthung_3_winyan_rak_nak_leng.wav", "tag": "วิทยุลูกทุ่ง"},
        {"key": "radio_lukthung_4_klom_khuen_duean_dap", "title": "📻 วิทยุลูกทุ่ง 4: กล่อมคืนเดือนดับ", "desc": "ดนตรีลูกทุ่งโบราณวังเวง", "path": "assets/sounds/radio_lukthung_4_klom_khuen_duean_dap.wav", "tag": "วิทยุลูกทุ่ง"},
        {"key": "radio_lukthung_5_am_detuned_ghost", "title": "📻 วิทยุลูกทุ่ง 5: คลื่นแทรกวิญญาณ", "desc": "คลื่นวิทยุเพี้ยนกลางดึก", "path": "assets/sounds/radio_lukthung_5_am_detuned_ghost.wav", "tag": "วิทยุลูกทุ่ง"},
        {"key": "haunt_breath_neck_left", "title": "👻 หายใจรดต้นคอ (ข้างซ้าย)", "desc": "เสียงลมหายใจอุ่นๆ ชิดซอกคอซ้าย", "path": "assets/sounds/haunt_breath_neck_left.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_breath_neck_right", "title": "👻 หายใจรดต้นคอ (ข้างขวา)", "desc": "เสียงลมหายใจกระชั้นชิดซอกคอขวา", "path": "assets/sounds/haunt_breath_neck_right.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_breath_behind_slow", "title": "👻 หายใจช้าๆ ข้างหลังคอ", "desc": "เสียงถอนหายใจลึกๆ ชิดท้ายทอย", "path": "assets/sounds/haunt_breath_behind_slow.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_walk_dirt_circle", "title": "👣 เสียงเดินบนดินรอบร้าน (ช้าๆ)", "desc": "ฝีเท้าย่ำดินลูกรังและใบไม้แห้งวนรอบเพิง", "path": "assets/sounds/haunt_walk_dirt_circle.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_walk_dirt_hurry", "title": "👣 เสียงวิ่งย่ำดินเข้ามาหา!", "desc": "ฝีเท้าเร่งจังหวะวิ่งย่ำดินเข้ามาใกล้", "path": "assets/sounds/haunt_walk_dirt_hurry.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_walk_shop_wood_1", "title": "🪵 เสียงเดินบนพื้นไม้ในร้าน 1", "desc": "เสียงย่ำไม้กระดานเก่าในเพิงเอี๊ยดอ๊าด", "path": "assets/sounds/haunt_walk_shop_wood_1.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_walk_shop_wood_2", "title": "🪵 เสียงเดินในร้าน 2", "desc": "เสียงเดินลากเท้าไปมาในร้าน", "path": "assets/sounds/haunt_walk_shop_wood_2.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_roof_tin_steps", "title": "🏚️ เสียงเดินบนหลังคาสังกะสี", "desc": "เสียงย่ำสังกะสีเหนือหัวตึงๆ", "path": "assets/sounds/haunt_roof_tin_steps.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_climb_tree_1", "title": "🌳 เสียงปีนขึ้นต้นไม้ 1 (ตะกายเปลือกไม้)", "desc": "เสียงเล็บ/มือตะกายเปลือกไม้และกิ่งไม้สั่น", "path": "assets/sounds/haunt_climb_tree_1.wav", "tag": "เสียงหลอก 3D"},
        {"key": "haunt_climb_tree_2", "title": "🌳 เสียงปีนขึ้นต้นไม้ 2 (ดงกล้วย/ต้นไทร)", "desc": "เสียงไต่ขึ้นต้นไม้และใบไม้สวบสาบ", "path": "assets/sounds/haunt_climb_tree_2.wav", "tag": "เสียงหลอก 3D"},
        {"key": "sfx_pump_crank_loop", "title": "⛽ หมุนมือหมุนปั๊มหลอด", "desc": "เสียงเฟืองปั๊มหลอดมือหมุนทุ้มๆ", "path": "assets/sounds/sfx_pump_crank_loop.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_fuel_glug_loop", "title": "⛽ น้ำมันไหลลงหลอดแก้ว", "desc": "เสียงน้ำมันไหลอึกๆ นุ่มๆ", "path": "assets/sounds/sfx_fuel_glug_loop.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_shutter_close_slam", "title": "🚧 ดึงแผงสังกะสีปิดร้าน!", "desc": "เสียงกระแทกปิดแผงสังกะสีหน้าร้าน", "path": "assets/sounds/sfx_shutter_close_slam.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_shutter_open_pull", "title": "🚧 ดึงเชือกเปิดแผงสังกะสี", "desc": "เสียงรอกเชือกดึงแผงสังกะสีขึ้น", "path": "assets/sounds/sfx_shutter_open_pull.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_coin_tin_drop_1", "title": "🪙 เงินหล่นใส่กระป๋อง 1", "desc": "เสียงเหรียญ/เงินลงกระป๋องสังกะสี", "path": "assets/sounds/sfx_coin_tin_drop_1.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_coin_tin_drop_2", "title": "🪙 เงินหล่นใส่กระป๋อง 2", "desc": "เสียงเหรียญกระทบกระป๋องสังกะสี", "path": "assets/sounds/sfx_coin_tin_drop_2.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_incense_extinguish", "title": "🕯️ ธูปดับ 1 ดอก", "desc": "เสียงฟู่ทุ้มลึกตอนธูปที่ศาลพระภูมิดับ", "path": "assets/sounds/sfx_incense_extinguish.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_moto_approach_idle", "title": "🛵 มอเตอร์ไซค์ชาวบ้านเดินเบา", "desc": "เสียงเครื่องมอเตอร์ไซค์ 4 จังหวะเดินเบาทุ้มๆ", "path": "assets/sounds/sfx_moto_approach_idle.wav", "tag": "SFX ในปั๊ม"},
        {"key": "sfx_pickup_diesel_idle", "title": "🛻 รถกระบะดีเซลเดินเบา", "desc": "เสียงเครื่องดีเซลเก่าเดินเบาหน้าปั๊ม", "path": "assets/sounds/sfx_pickup_diesel_idle.wav", "tag": "SFX ในปั๊ม"},
    ]

    reactions = []
    for k, text, prof, _shiv, _ro, _po in REACTION_JOBS:
        p = f"assets/sounds/reactions/{k}.wav"
        reactions.append({"key": k, "title": k, "desc": f'"{text}"', "path": p, "tag": prof})

    dialogues = []
    for k, text, prof in DIALOGUE_JOBS:
        p = f"assets/sounds/dialogues/{k}.wav"
        dialogues.append({"key": k, "title": k, "desc": f'"{text}"', "path": p, "tag": prof})

    for lst in (chants, road, radio_haunt, reactions, dialogues):
        for item in lst:
            item["dur"] = get_dur(item["path"])

    data_json = json.dumps({
        "chants": chants,
        "reactions": reactions,
        "road": road,
        "radio_haunt": radio_haunt,
        "dialogues": dialogues,
    }, ensure_ascii=False)

    html = """<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<title>🎧 Soundboard ทดลองฟังเสียง - ปั๊มหลอดท้ายทุ่ง</title>
<style>
  :root {
    --bg: #0f0e0c;
    --card: #1b1916;
    --card-hover: #26231e;
    --border: #38332b;
    --text: #ece4d0;
    --muted: #a59c88;
    --accent: #e67832;
    --danger: #cd241c;
    --green: #68b85e;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px;
    background: var(--bg); color: var(--text);
    font-family: 'Segoe UI', Tahoma, sans-serif;
  }
  h1 { margin: 0 0 6px 0; font-size: 26px; color: var(--accent); }
  .sub { color: var(--muted); margin-bottom: 20px; font-size: 14px; }
  .tabs {
    display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 18px;
    border-bottom: 1px solid var(--border); padding-bottom: 12px;
  }
  .tab-btn {
    background: var(--card); color: var(--text);
    border: 1px solid var(--border); border-radius: 8px;
    padding: 10px 16px; cursor: pointer; font-size: 15px; font-weight: 600;
    transition: 0.15s;
  }
  .tab-btn:hover { background: var(--card-hover); }
  .tab-btn.active { background: var(--accent); color: #111; border-color: var(--accent); }
  .toolbar {
    display: flex; gap: 12px; align-items: center; flex-wrap: wrap;
    margin-bottom: 16px; background: #151310; padding: 12px 16px;
    border-radius: 10px; border: 1px solid var(--border);
  }
  .search-input, .filter-select {
    background: #0c0b09; color: var(--text); border: 1px solid var(--border);
    padding: 8px 12px; border-radius: 6px; font-size: 14px;
  }
  .search-input { min-width: 260px; }
  .stop-btn {
    background: var(--danger); color: #fff; border: none;
    padding: 8px 16px; border-radius: 6px; cursor: pointer; font-weight: 600;
  }
  .now-playing {
    margin-left: auto; color: var(--green); font-size: 14px; font-weight: 600;
  }
  .grid {
    display: grid; grid-template-columns: repeat(auto-fill, minmax(310px, 1fr));
    gap: 12px;
  }
  .card {
    background: var(--card); border: 1px solid var(--border);
    border-radius: 10px; padding: 14px; display: flex; flex-direction: column;
    justify-content: space-between; gap: 10px; transition: 0.15s; cursor: pointer;
  }
  .card:hover { background: var(--card-hover); border-color: var(--accent); }
  .card.playing { border-color: var(--green); box-shadow: 0 0 0 2px rgba(104,184,94,0.35); }
  .card-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
  .card-title { font-weight: 700; font-size: 15px; color: var(--text); word-break: break-word; }
  .badge {
    font-size: 11px; padding: 3px 8px; border-radius: 99px;
    background: #2d2820; color: var(--accent); white-space: nowrap; font-weight: 600;
  }
  .card-desc { font-size: 14px; color: var(--muted); line-height: 1.4; }
  .card-foot { display: flex; justify-content: space-between; align-items: center; font-size: 12px; color: var(--muted); }
  .play-pill {
    background: #2b261f; color: var(--text); padding: 5px 12px;
    border-radius: 6px; font-weight: 600; font-size: 13px;
  }
  .card.playing .play-pill { background: var(--green); color: #000; }
</style>
</head>
<body>
  <h1>🎧 Soundboard ทดลองฟังเสียงทั้งหมด (223 ไฟล์) — ปั๊มหลอดท้ายทุ่ง</h1>
  <div class="sub">คลิกที่การ์ดใบไหนก็ได้เพื่อฟังเสียงทันที • ตัดเสียงแหลมแสบหูออกทั้งหมด • บทพูดและบทสวดมนต์ไร้เสียงวืดคั่นวรรค 100%</div>

  <div class="tabs">
    <button class="tab-btn active" onclick="switchTab('chants', this)">🙏 บทสวดมนต์อีสาน (ปกติ vs เจอผี) [8]</button>
    <button class="tab-btn" onclick="switchTab('reactions', this)">😱 เสียงอุทาน เฮ้ย! / ห๊า?! / หนาวสั่น / หวาดกลัว [22]</button>
    <button class="tab-btn" onclick="switchTab('road', this)">🏍️ เด็กแว้น + เพลงแดนซ์ + เพลงรถแห่ [6]</button>
    <button class="tab-btn" onclick="switchTab('radio_haunt', this)">📻 วิทยุลูกทุ่ง + เสียงหลอก 3D + SFX [24]</button>
    <button class="tab-btn" onclick="switchTab('dialogues', this)">🎙️ เสียงพากย์บทสนทนาตัวละคร ชาย-หญิง [163]</button>
  </div>

  <div class="toolbar">
    <input type="text" id="searchBox" class="search-input" placeholder="🔍 ค้นหาคำพูด หรือชื่อไฟล์..." oninput="render()">
    <select id="tagFilter" class="filter-select" onchange="render()">
      <option value="ALL">👤 ตัวละคร / หมวดหมู่ทั้งหมด</option>
    </select>
    <button class="stop-btn" onclick="stopAudio()">⏹ หยุดเล่นเสียง</button>
    <div id="nowPlaying" class="now-playing">พร้อมเล่นเสียง</div>
  </div>

  <div id="grid" class="grid"></div>

<script>
const DATA = __DATA_JSON__;
let currentTab = 'chants';
let currentAudio = null;
let currentKey = null;

const PROFILE_LABELS = {
  'Sommai': 'ลุงสมหมาย (ชายสูงวัย)',
  'Boonmee': 'พี่บุญมี (ชายวัยกลางคน)',
  'Ton': 'น้องต้น (หนุ่มวัยรุ่น)',
  'Daeng': 'พี่แดง (ชาย)',
  'Racer': 'เด็กแว้น (หนุ่มซิ่ง)',
  'Player_M': 'ผู้เล่นชาย (Player_M)',
  'Ghost_M': 'ผีผู้ชาย (Ghost_M)',
  'Chaem': 'ป้าแช่ม (หญิงวัยกลางคน)',
  'Prik': 'ยายปริก (หญิงชรา)',
  'Noi': 'น้าน้อย (หญิง)',
  'Coyote': 'สาวโคโยตี้ (หญิงสาว)',
  'Player_F': 'ผู้เล่นหญิง (Player_F)',
  'Ghost_F': 'ผีผู้หญิง (Ghost_F)',
};

function switchTab(tab, btn) {
  currentTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  populateFilter();
  render();
}

function populateFilter() {
  const sel = document.getElementById('tagFilter');
  const items = DATA[currentTab] || [];
  const tags = [...new Set(items.map(x => x.tag))];
  sel.innerHTML = '<option value="ALL">👤 ตัวละคร / หมวดหมู่ทั้งหมด</option>';
  tags.forEach(t => {
    const label = PROFILE_LABELS[t] || t;
    const opt = document.createElement('option');
    opt.value = t;
    opt.textContent = label;
    sel.appendChild(opt);
  });
}

function stopAudio() {
  if (currentAudio) {
    currentAudio.pause();
    currentAudio.currentTime = 0;
    currentAudio = null;
  }
  currentKey = null;
  document.getElementById('nowPlaying').textContent = 'หยุดเล่นแล้ว';
  render();
}

function playItem(path, key, title) {
  if (currentAudio) {
    currentAudio.pause();
  }
  if (currentKey === key) {
    stopAudio();
    return;
  }
  currentKey = key;
  currentAudio = new Audio(path + '?t=' + Date.now());
  document.getElementById('nowPlaying').textContent = '🔊 กำลังเล่น: ' + title;
  currentAudio.onended = () => {
    currentKey = null;
    document.getElementById('nowPlaying').textContent = 'เล่นจบแล้ว';
    render();
  };
  currentAudio.play();
  render();
}

function render() {
  const grid = document.getElementById('grid');
  const q = document.getElementById('searchBox').value.trim().toLowerCase();
  const tf = document.getElementById('tagFilter').value;
  const items = (DATA[currentTab] || []).filter(item => {
    if (tf !== 'ALL' && item.tag !== tf) return false;
    if (q && !(item.title.toLowerCase().includes(q) || item.desc.toLowerCase().includes(q) || item.tag.toLowerCase().includes(q))) return false;
    return true;
  });

  grid.innerHTML = items.map(item => {
    const isPlaying = currentKey === item.key;
    const badgeText = PROFILE_LABELS[item.tag] || item.tag;
    const safeTitle = item.title.replace(/'/g, "");
    return `
      <div class="card ${isPlaying ? 'playing' : ''}" onclick="playItem('${item.path}', '${item.key}', '${safeTitle}')">
        <div>
          <div class="card-top">
            <div class="card-title">${item.title}</div>
            <span class="badge">${badgeText}</span>
          </div>
          <div class="card-desc" style="margin-top:8px;">${item.desc}</div>
        </div>
        <div class="card-foot">
          <span>⏱ ${item.dur} วินาที</span>
          <span class="play-pill">${isPlaying ? '⏹ กำลังเล่น...' : '▶ คลิกเพื่อฟัง'}</span>
        </div>
      </div>
    `;
  }).join('');
}

populateFilter();
render();
</script>
</body>
</html>
""".replace("__DATA_JSON__", data_json)

    out_file = os.path.join(BASE, "soundboard.html")
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(html)
    print("Created:", out_file)
    webbrowser.open("file:///" + out_file.replace(os.sep, "/"))


if __name__ == "__main__":
    main()
