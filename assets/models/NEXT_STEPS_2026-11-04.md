# สถานะงาน + สิ่งที่ต้องทำต่อ (2026-11-04)

ตรวจจาก Studio place 114125276809667 ("ความผิดปกติของปั๊ม") ตอนเขียนไฟล์นี้

## 1. ทำเสร็จแล้ว

### คัทซีนรถตอนหลายคน (`src/server/Cutscene.luau`, `src/client/CutsceneController.client.luau`)
- ที่นั่ง:
  - นับเบาะผู้โดยสารทุกตัว: เก๋ง 3 คนใช้เบาะหลังแล้ว เดิมไปนั่งบนฝาท้าย
  - นั่งเรียงจากหน้าไปหลัง ไม่มีใครนั่งซ้อนกัน
  - ท้ายกระบะมีม้านั่งไม้สองข้างนั่งหันหน้าเข้าหากัน ขาไม่ทะลุพื้นกระบะแล้ว
- ลงรถ:
  - ทีละคน ห่างกัน 0.3 วิ ยืนพ้นตัวรถจริง
  - จุดยืนเช็กว่าไม่ชนตู้ปั๊ม เสาไฟ หรือฐานตู้ (ใช้รูปทรงชนจริง)
- เดินเข้าร้าน / เดินมาหารถ (ฉากจบ):
  - แต่ละคนได้จุดยืนว่างของตัวเอง
  - จัดลำดับให้ไม่มีใครเดินทะลุคนที่ยืนรออยู่
  - จุดเริ่มหลังร้านในฉากจบไม่ไปยืนบนกอกล้วยแล้ว
- กล้อง:
  - ตัวผู้เล่นคนอื่นหรือชิ้นรถที่บังภาพจางลงเฉพาะเครื่องนั้น
  - มุมที่เคยไปอยู่ในตัวกระบะ/ห้องคนขับจะหลบไปมุมอื่น
  - ช็อตคุยกับคนขับและช็อตกว้างถอยหรือยกกล้องตามขนาดรถ
- ท่า T: พี่ชายเล่นท่ายืนตั้งแต่โผล่ (เดิมยืนท่า T ตอนลงรถ ~1.3 วิ)
- ทดสอบแล้ว (ด้วยหุ่น):
  - เปิดคืน 1 / 3 / 5 คน และฉากจบ 5 คน
  - มอไซค์ ตุ๊กตุ๊ก เก๋ง กระบะ
  - ไม่มีที่นั่งซ้อน ไม่มีคนยืนในตัวรถ ไม่มีท่า T บนจอ

### แผง admin (F2 > คัทซีน)
- เลือกจำนวนคน "จริง" / 1–6 แล้วกด "เล่นคัทซีนเปิดคืน" หรือ "ชนะทันที"
  - เกมเติมหุ่นทดสอบให้ครบจำนวน
  - เฉพาะ Studio
- วิธีใช้จาก MCP อยู่ใน `HUMAN_ANIMATION_GUIDE.md` หัวข้อ 6

### โมเดลที่นำเข้าแล้ว (อยู่ใน Studio)
- `ServerStorage.HumanTemplates`: human_base, human_female, human_child, human_elder_male, human_elder_female
  - ของเก่าเก็บไว้ที่ `HumanTemplatesOld`
- `ServerStorage.GhostTemplates`: 16 ตัว (Krahang, Krasue, Pret, ghost_* 13 ตัว)
- KeyframeSequence ที่สร้างแล้วแต่ **ยังไม่ publish**:
  - `HumanAnims.<4 คนใหม่>` คนละ 16 ท่า = 64
  - `GhostAnims.<15 ผี>` = 33 ท่า
- ท่า human_base publish แล้ว (ID อยู่ใน `src/shared/HumanAnimIds.luau`)

## 2. สิ่งที่คุณต้องทำ (ใน Studio)

1. **Pop** (ยายป๊อปชุดแม่หม้าย): ตอนนี้อยู่ที่ `Workspace.Pop` นำเข้าให้เสร็จ (Scale 0.01, Rig Custom, Anchored) แล้วบอก AI ย้ายเข้า GhostTemplates
2. **โลงศพ**: นำเข้า `assets/models/roblox/human_ghosts/Coffin.fbx` (Scale 0.01, Anchored) ยังไม่มีใน Studio
3. **Publish ท่า** (Animation Editor > Save to Roblox) แล้วจด ID ส่งให้ AI:
   - `ServerStorage.HumanAnims` คน 4 ตัวใหม่: 64 ท่า
   - `ServerStorage.GhostAnims`: 33 ท่า
   - Krasue (Float, Lunge, Sniff, HairWhip) และ Pop (TwitchWalk, LickLips, KnockShutter, PossessedSnap)
     - สองตัวนี้ยังไม่มี KeyframeSequence (rig/ไฟล์ท่าคนละแบบ)
     - ต้องนำเข้าท่าจาก FBX ใน Animation Editor ก่อน
   - สิทธิ์: experience เป็นของ queue966 แต่ Studio ล็อกอิน Aunival_Games ท่าที่ publish ต้องแชร์สิทธิ์ให้ experience (หรือย้ายไป Group) ไม่งั้นในเกมจริงท่าไม่เล่น
4. ห้ามใช้เลือดหรือแผลในภาพ/texture ก่อนอัปโหลด (Pret เคยโดนเตือน 2026-11-04)
5. **Ctrl+S** บันทึก place (หรือ Publish)
6. ทดสอบคัทซีนกับผู้เล่นจริง 2 คนอย่างน้อยครั้งหนึ่ง (Test > Clients and Servers)
   - หุ่นเดินด้วย Server ส่วนผู้เล่นจริงเดินด้วย Client

## 3. สิ่งที่ AI ทำต่อหลังคุณทำเสร็จ

1. ใส่ AnimationId ที่ได้ลง:
   - `src/shared/HumanAnimIds.luau` (คน 4 ตัวใหม่)
   - `src/shared/GhostAnimIds.luau` (ตอนนี้ว่างทุกตัว: ผียืนท่า rest pose ซึ่งดูเหมือนท่า T)
2. ย้าย `Workspace.Pop` เข้า `ServerStorage.GhostTemplates` ตรวจกระดูก/ชุด แล้วลบตัวที่ค้างใน Workspace
3. ใส่โลงศพในขบวนแห่ศพ ให้ผีชุดขาวแบก (origin โลง = กำปั้นขวาคนแบก)
4. ต่อผีเข้าเกมผ่าน `src/server/GhostNPC.luau` + `AnomalyManager.luau`
   - session หลักทำค้างไว้ ยังไม่ commit
5. ให้คนเดินถนน/ลูกค้าสุ่มใช้คน 4 แบบใหม่ (หญิง เด็ก ชายชรา หญิงชรา) ใน `HumanNPC`
   - คนขับรถลูกค้ายังเป็น NPC แบบเก่า -> เปลี่ยนเป็น `HumanNPC.SeatIn`
6. ทดสอบใน Play ทุกตัว (ท่าเล่น ไม่มีท่า T ขาไม่ทะลุรถ) แล้วลบ `HumanTemplatesOld` เมื่อแน่ใจ
7. งานเล็กที่ค้าง:
   - คนขับรถพี่ชายไม่มีท่า ~0.5 วิตอนรถโผล่ (จอยังดำ แก้ใน CoreLoop)
   - ตัวผู้เล่นไม่มีท่า ~0.1 วิตอนสลับท่านั่ง/ยืน (Animate.client)
