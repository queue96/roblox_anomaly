# คู่มือทำงานต่อ: ท่าทาง การถือของ การนำเข้า Roblox และระบบในเกม (สำหรับ AI ที่มารับช่วงต่อ)

อ่านคู่กับ:
- `HUMAN_PIPELINE_GUIDE.md`: วิธีปั้นตัว ผม ผิว ชุด การรัน Blender และตัวตรวจ
- `HUMAN_MODELS.md`: ตัวเลข ตาราง รายการทรงผม/ชุด/ท่า

ไฟล์นี้เน้นสิ่งที่ทำหลังจากตัวละครพร้อมแล้ว คือ ท่าทาง → การถือของ → ส่งเข้า Roblox → ระบบฝั่งเกม พร้อมปัญหาที่เคยเจอและวิธีแก้

---

## 1. แผนที่ไฟล์

| ส่วน | ไฟล์ |
|---|---|
| ท่าทางทั้งหมด (Blender) | `assets/models/human_base/build_anims.py` |
| หามือจับของจริง (grasp) | `assets/models/human_base/grasp_search.py` |
| สร้าง KeyframeSequence ใน Studio | `tools/studio/HumanAnimImport.luau` (วางเป็น ModuleScript ใน `ServerStorage.HumanAnimImport`) |
| ID ท่าที่ publish แล้ว | `src/shared/HumanAnimIds.luau` |
| ชิ้นผิวที่ชุดปิด | `src/shared/HumanSkinParts.luau` (สร้างอัตโนมัติ ห้ามแก้มือ) |
| NPC มนุษย์ (แต่งตัว เล่นท่า นั่งรถ IK) | `src/server/HumanNPC.luau` |
| คนเดิน ร่ม แกลลอน | `src/server/Pedestrian.luau` |
| ตัวผู้เล่น (StarterCharacter, ชุด, ผ้าคาดเอว) | `src/server/PlayerVillager.server.luau` |
| ท่าของผู้เล่น + มุมมองบุคคลที่หนึ่ง | `src/character/Animate.client.luau` (StarterCharacterScripts) |
| หันหัว เอนตัว แขนถือไฟฉาย จุดจับของ | `src/shared/HeadTurn.luau` |
| หัว/แขนของผู้เล่นคนอื่น | `src/client/HeadTurnOthers.client.luau` |
| ไฟฉายในมือ (มุมบุคคลที่หนึ่ง) | `src/client/HUDController.client.luau` (`FLASHLIGHT_GRIP_BACK`) |
| คนขับรถ (เป้า IK มือ/เท้า) | `src/server/CoreLoop.luau` → `humanizeDriver` |
| กลุ่มการชน ผู้เล่น/NPC | `src/server/CollisionGroups.luau` |

---

## 2. การทำท่า (`build_anims.py`)

### 2.1 โครงของท่า
- ท่าคือฟังก์ชัน `c_<ชื่อ>(P, t, st, s)` แล้วใส่ใน `CLIPS` (ชื่อ → (ฟังก์ชัน, จำนวนเฟรม))
  - `t` = 0..1 รอบลูป, `st` = นิสัยตัวละคร, `s` = ขนาดตัว
- เครื่องมือในท่า:
  - `P.rot(bone, x, y, z)`: องศา เขียนตามด้านซ้ายเสมอ กระดูก `.R` กลับแกนให้เอง และจำกัดตาม joint limit
  - `arm(P, side, raise_, fwd, bend, wrist, twist, dev)`: แขนทั้งแขน
  - `hand(P, side, shape, k, th)`: รูปมือ (`relax`, `fist`, `point`, `jeeb`, `wong`, `wai`, และมือจับของจาก `GRIPS`)
  - `seated(P, thigh, shin, spread, lean)`: ท่านั่ง (ใช้กับคนขับรถ)
- ท่าที่ขยับแค่ตัวบน (ถือของ พนมมือ) ใส่ใน `UPPER_ONLY`: export เฉพาะกระดูกที่ขยับ → ในเกมเล่นซ้อนท่าเดิน/ยืนด้วย priority `Action`
- **`KEEP_TRACKS`**: กระดูกที่ต้อง key ไว้แม้อยู่ท่าพัก (มุม 0)
  - เช่นนิ้วตรงของท่าพนมมือ หรือนิ้วและข้อมือของมือที่ถือของ
  - ถ้าไม่ใส่ กระดูกที่อยู่ท่าพักจะหลุดจากคลิป ท่ายืน/เดินที่เล่นอยู่ข้างใต้จะงอนิ้วทับ (นิ้วทะลุของ)

### 2.2 หาท่าด้วยการ sweep (อย่าเดาค่าด้วยมือ)
ท่าที่ต้องการผลลัพธ์ชัดเจน (ฝ่ามือแนบกัน, รูกำมือตั้งตรง, มืออยู่หน้าอก) ให้เขียนสคริปต์ sweep ค่า แล้วให้คะแนนจากตำแหน่งกระดูก:
1. โหลด `build_anims.py` ใน namespace แยก เปิด `human_base.blend` แล้วสร้าง `Poser`
2. วนค่า (เช่น raise/fwd/bend/wrist/twist/dev) แล้วตั้งท่าด้วย `arm()` / `hand()` นำ `P.frame` ไปใส่ `rotation_euler`
3. วัดจากตำแหน่งกระดูก (`rig.matrix_world @ pose_bone.head`)
4. **ใช้แกนของตัวละครที่คำนวณจากกระดูก อย่าใช้แกน X/Y/Z ของ Blender ตรงๆ**
   - `UP = head - hips`, `FWD = foot.tail - foot.head` (ตัดส่วน UP ออก), `OUT = ไหล่ - สะโพก` (ตัด UP/FWD ออก)
   - เคยพลาด: สมมติว่า Z คือขึ้น แต่ rig นี้ไม่ใช่ ผลที่ได้กลับทาง
5. เรียงคะแนน แล้ว render ตัวที่ดีที่สุดก่อนใส่ในท่าจริง
6. หลังใส่ท่าแล้ว รันตัวตรวจแขนขาทะลุกัน (`test_self_intersection.check`)
   - ยอมให้ "มือแนบมือ" ทับกันได้ ~1.5–4.5 ซม. (ฝ่ามือกดกัน) แต่ต้องดูภาพประกอบเสมอ

### 2.3 อบท่าและ export ข้อมูลท่า
```python
A = {"__name__": "x"}; exec(open(HB + "/build_anims.py", encoding="utf-8").read(), A)
A["anims_all"]()                                   # อบทุกท่าลงทุกไฟล์ .blend
bpy.ops.wm.open_mainfile(filepath=HB + "/human_base.blend")
A["export_clip_data"]("male", M + "/roblox/human_base/human_base_anims.json")
# เลือกเฉพาะท่าที่แก้ไปให้ Studio: {"rest": d["rest"], "clips": {ชื่อ: d["clips"][ชื่อ]}, "upper": [ชื่อที่เป็น UPPER_ONLY]}
```
- `export_clip_data` บางทีเจอ `OSError: [Errno 22]` (Windows ล็อกไฟล์) → ลองซ้ำ 2–10 ครั้ง ห่างกัน ~1.5 วิ
- ไม่ต้อง export FBX ใหม่ถ้าแก้แค่ท่า (FBX ต้องใช้เมื่อแก้รูปร่าง/ชุด/ผม แล้วนำเข้าแม่แบบใหม่)

---

## 3. ส่งท่าเข้า Roblox Studio

1. เปิด http server ชั่วคราวในโฟลเดอร์ที่มี json (`python -m http.server 8766 --bind 127.0.0.1`)
2. ใน Studio (Edit mode) เปิด `HttpService.HttpEnabled` ชั่วคราว → `GetAsync` json → ปิดคืน
3. สร้างท่า:
   ```lua
   local H = require(game.ServerStorage.HumanAnimImport:Clone())
   local kfs = H.build(game.ServerStorage.HumanTemplates.human_base, data.rest, data.clips.pray, "pray")
   kfs.Priority = Enum.AnimationPriority.Action   -- ท่าซ้อน (UPPER_ONLY); ท่าหลักใช้ Core
   kfs.Parent = game.ServerStorage.HumanAnims.human_base   -- ลบอันเก่าชื่อเดียวกันก่อน
   ```
4. **ดูท่าก่อน publish** (ไม่ต้อง Play): clone แม่แบบไปวางใน workspace → `HumanNPC.Dress(m, {outfit=...})` (clone โมดูลไปวางใต้ ServerScriptService ก่อน require) → `H.pose(m, data.rest, clip, 1)` → screen_capture
   - texture บางทีโหลดช้า (เห็นเป็นสีเทา): รอ 5 วิแล้วถ่ายใหม่
5. ให้เจ้าของ **Save to Roblox ทับ ID เดิม** (คลิกขวาที่ KeyframeSequence) ถ้าได้ ID ใหม่ให้แก้ `HumanAnimIds.luau`
   - ใน Play จะยังใช้ท่าเก่าจนกว่าจะ publish
6. แม่แบบตัวละครใหม่ (นำเข้า FBX): 3D Importer Scale 0.01, Rig Custom, Anchored → ใส่ `Animator` ใต้ `AnimationController` → ผม `Hair_*` ตั้งสีเอง (36,34,32) → ย้ายเข้า `ServerStorage.HumanTemplates`

---

## 4. ให้มือถือของได้จริง (ไม่ทะลุ ไม่แปะ)

**ลำดับที่เจ้าของต้องการ: แบมือ → วางของบนฝ่ามือ → งอนิ้วจนแตะของ** อย่าออกแบบรูปมือก่อนแล้วค่อยหาที่วางของ (เคยทำแล้วนิ้วทะลุหรือดูแปะ)

1. วัดรัศมีส่วนที่มือจับของจริงในเกม
   - Raycast ใส่ mesh ใน Studio (ตั้ง `CollisionFidelity = PreciseConvexDecomposition` ชั่วคราว) ยิงเข้าหาแกนทีละระยะ
   - ไฟฉาย: หัว 0.25 แต่ส่วนด้ามจับ 0.155 studs / ด้ามร่ม 0.088 studs
2. รัน `grasp_search.py` (แก้ `OBJECTS`) ได้:
   - `angles`: องศานิ้วทุกข้อ → ใส่ `GRIPS` ใน `build_anims.py` ใช้ผ่าน `hand(P, side, "grip_<ชื่อ>")`
   - `center`: จุดกลางของในกรอบมือ (studs) → `GRIP_CENTER` ใน `HeadTurn.luau`
   - ภาพ 3 มุมให้ตรวจด้วยตา
3. **กรอบมือ (ใช้ตำแหน่งกระดูกเท่านั้น):** O = `hand`, X = `pinky_01 → index_01` (แนวของ), Y = ไปทาง `middle_01` (ตั้งฉาก X), Z = X×Y
   - ห้ามใช้แกนของ Bone ใน Roblox: 3D Importer วางแกนกระดูกต่างจาก Blender ได้
   - `HeadTurn.grip(char, side)` คืน (จุดกลาง, แนวของ) ในโลก
4. วางของในเกมที่จุดนั้นตามแนวนั้น
   - ไฟฉาย: `CFrame.lookAt(center + axis*0.3, ...)` (มือจับท้ายกระบอก หัวไฟอยู่หน้ามือ) จับจากด้านบน ใช้ `-axis` (หัวไฟโผล่ทางนิ้วก้อย)
   - ร่ม (NPC เป็นชิ้น anchored ไม่ขยับตามกระดูก): วัดจุดจับ + แนวด้ามใน Studio ด้วย `H.pose` + `HeadTurn.grip` แล้วใส่เป็นค่าคงที่ (`Pedestrian.HUMAN_RIGHT_HAND`, `HUMAN_UMBRELLA_UP`) และให้ด้ามชี้ตามแนวรูกำมือ (`AddUmbrella(..., exact=true)`)
5. ถ้าแนวรูกำมือในท่าชี้ผิด (ร่มเอนไปหาหน้า) ให้ sweep ท่าแขน ไม่ใช่หมุนของให้ทะลุนิ้ว
   - ร่ม: แขนท่อนล่างแนวนอนหมุนเข้า (raise −30, fwd 10, bend 60, twist −30) → รูกำมือตั้งตรง
   - ข้อมือของ rig ถูกจำกัด (joint limit) จึงบิดมือไปหามุมแปลกๆ ไม่ได้

### แขนถือไฟฉายของผู้เล่น (`HeadTurn.luau`)
- **จับจากด้านบน:** มือคว่ำบนกระบอก แขนท่อนล่างพาดหน้าอก หัวไฟโผล่ทางนิ้วก้อย ข้อมือเกือบตรง
  - เคยทำแบบ "แขนท่อนล่างชี้หน้า + รูกำมือชี้หน้า" ข้อมือต้องบิด ~90° ดูเหมือนมือหัก
- **วิธีจัดแขน:** กำหนดตำแหน่งมือ `HAND_POS` (กรอบ HumanoidRootPart) + ทิศแขนท่อนล่าง (`FORE_ACROSS`, `FORE_DROP`)
  - ข้อศอก = มือ − ทิศแขนท่อนล่าง × ความยาว
  - หัวไหล่หมุนแขนท่อนบนชี้ข้อศอก → แขนท่อนล่างชี้ตามทิศ + บิดคว่ำมือ → ข้อมือปรับนิดเดียว
  - การเล็งแค่ทิศจากหัวไหล่ (shortest arc อย่างเดียว) ทำให้มือตกไปอยู่ระดับเอวหรือแขนกางออกข้าง
- เงย/ก้ม/หันหัว: หมุนตำแหน่งมือรอบหัวไหล่ตามสายตา

---

## 5. ระบบฝั่งเกม

### 5.1 NPC (`HumanNPC.luau`)
- `Build(opts)` → clone แม่แบบ + `Dress` (สุ่มชุด/ผม ลบชิ้นที่ไม่ใช้ ลบผิวที่ชุดปิด)
  - opts: `outfit`, `hair`, `teen`, `umbrella`, `noHelmet`, `noHat` (ไม่ใส่หมวกทุกชนิด: งอบ/หมวกกันน็อก ใช้กับคนขับรถยนต์)
- `Play` เปลี่ยนท่าโดยรอท่าใหม่โหลดเสร็จก่อน (ไม่อย่างนั้นเห็นท่า T/A แวบ)
- `Hold(m, clip, on)` ท่าซ้อน (ถือร่ม/แกลลอน)
- `SeatIn(vehicle, hip, clip, opts, targets)` ใส่คนขับ + IKControl มือ/เท้า
  - **เป้า IK ของเท้าต้องเลือกข้างจากตำแหน่งจริง (`lp.X > 0` = ขวา) ไม่ใช่ชื่อชิ้น**: คนขับแบบเก่าตั้งชื่อเท้ากลับข้าง ขาเคยไขว้ทะลุตัวรถ
  - มอไซค์: เข่ากางออกข้าง (pole ไปทางข้าง) เท้าบนที่พักเท้าหลังบังลม สะโพกยก/ถอยนิด
- Attachment ของ IK ต้อง parent ก่อนตั้ง `WorldPosition` (ตั้งก่อน = เพี้ยนไป 100+ studs)

### 5.2 ตัวผู้เล่น
- `PlayerVillager` สร้าง `StarterPlayer.StarterCharacter` จากแม่แบบตอนเซิร์ฟเวอร์เริ่ม
  - HumanoidRootPart ใหม่ระดับสะโพก 2×2×2 (หนาพอให้กล้องไม่ทะลุกำแพง) เชื่อมทุกชิ้นด้วย WeldConstraint
  - `HipHeight = HIP - 1 + 0.36` (วัดจริง: สูตรเปล่าตัวจม 0.36)
  - ชุดม่อฮ่อมทุกคน ผ้าคาดเอวย้อมสีด้วย `SurfaceAppearance.Color` ไม่ซ้ำกันในห้อง
- `Animate.client.luau` (Rojo map ใน `default.project.json` → StarterCharacterScripts.Animate)
  - ท่าหลัก idle/walk/fall/sit + ท่าซ้อน hold_flashlight, pray
  - หันตัวอยู่กับที่: เล่น walk น้ำหนัก 0.4 ซ้อน idle (ก้าวสั้น ไม่ลื่นเหมือนจานหมุน)
  - หัน 45° แรกหันแค่หัว (HeadTurn) ตัวหมุนตามเมื่อเกิน (ปิด AutoRotate แล้วหมุนเอง)
  - มุมบุคคลที่หนึ่ง:
    - ซ่อนหัว/ผม/หมวกของตัวเอง (`LocalTransparencyModifier` มีผลแค่จอตัวเอง คนอื่นเห็นปกติ)
    - กล้องห่างหัวเกิน 2.5 studs (จอตาย) → แสดงครบ
    - ของใน Tool ซ่อนบนจอตัวเอง (HUD วาดไฟฉายในมือแทน)
  - ล้มตาย (HRP anchored): ยกเลิกท่าซ้อน และท่ายืนหยุดค้างเฟรมแรก (นอนนิ่ง)
  - ตำแหน่งตา: attribute `EyeOffset` (AmbienceController บวกเข้า CameraOffset) คำนวณตามกระดูกหัวที่หัน/เอน
- `HeadTurn.apply(char, yaw, pitch, aim)` เรียกทุกเฟรมใน `PreSimulation` (หลัง Animator เขียน Transform)
  - กระดูกที่ท่าไม่ได้แตะ ค่าที่เราเขียนจะค้าง → จำค่าฐานไว้ แล้วคืนฐานก่อนหมุนใหม่ทุกเฟรม
  - คนอื่นเห็นผ่าน remote `HeadTurn` → attribute `HeadYaw`/`HeadPitch` → `HeadTurnOthers`

### 5.3 อื่นๆ ที่เกี่ยวกับตัวละคร
- ตาย: `CoreLoop.collapse` → `UnequipTools` + นอนคว่ำ (−85°) ยึดตัว / `killOne`, `reviveOne` (admin) / `standUp`
- ชน: `CollisionGroups.Set(model, PLAYERS|NPC)` ผู้เล่นเดินทะลุลูกค้า/รถ/ขาจรได้ ทุกที่ที่เสก NPC ต้องเรียก
- ล้อรถ: `wheelsOf` หาทั้งชื่อแบบเก่า (`FrontWheel`...) และทุกชิ้นใน Model `Wheels` ทุกชั้น หมุนตามระยะ/รัศมีของแต่ละวง

---

## 5.5 ท่าอารมณ์ หน้าตา และท่าที่เล่นจากข้อมูล (ไม่ต้องอัปโหลด animation)

API อยู่ที่ `src/shared/HumanEmotes.luau` เรียกจาก server (ทุกคนเห็น) หรือ client ก็ได้:

```lua
local HumanEmotes = require(ReplicatedStorage.Shared.HumanEmotes)
HumanEmotes.Play(npc, "laugh")        -- วนจนสั่งหยุด / Play(npc, "sad", 4) = 4 วิแล้วหยุดเอง
HumanEmotes.Stop(npc)                 -- คืนท่าเดิม 0.3 วิ
HumanEmotes.SetFace(npc, "cry")       -- ค้างหน้านี้ / SetFace(npc, nil) = หน้าปกติ
HumanEmotes.SetWalkLegs(npc, speed)   -- ขา+สะโพกเดิน ส่วนบนเต้นต่อ (0 = เต้นเต็มตัว)
```

| ท่า (`EMOTES`) | | หน้า (`FACES`) | |
|---|---|---|---|
| `laugh` | หัวเราะ (คู่หน้า `squint`) | `blink` | หลับตา (ใช้กะพริบตาอัตโนมัติ) |
| `cheer` | ดีใจ ชูกำปั้น กระโดดเบาๆ | `squint` | ตาหรี่ ยิ้มเห็นฟัน |
| `startle` | ตกใจ (เล่นครั้งเดียวแล้วค้าง) | `dead` | ตาย ตาลอยสีเทา หน้าซีด |
| `sad` | เสียใจ ปาดน้ำตา (คู่ `cry`) | `cry` | ร้องไห้ น้ำตาไหล ปากเบ้ |
| `angry` | โกรธ เขย่ากำปั้น กระทืบเท้า (คู่ `angry`) | `ghost` | ผีหลอก ตาถลน ปากอ้าดำ (ผิวผีทั้งตัว) |
| | | `ghost_cry` | ผีร้องไห้ ตาแดงช้ำ น้ำตาเลือดไหลยาว ปากเบ้คร่ำครวญ (ผิวผีทั้งตัว) |
| `hurt_lying` | นอนเจ็บจากอุบัติเหตุ (คู่ `injured`) | `angry` | โกรธ คิ้วขมวด เห็นฟัน |
| `dead_lying` | นอนตาย (คู่ `dead`) | `injured` | หัวแตก เลือดไหล ตาช้ำ + เลือดที่แขนซ้าย |

- **ทำไมไม่อัปโหลด:** ท่าเหล่านี้เล่นด้วย `client/HumanEmotesRunner` ที่เขียน `Bone.Transform` ทับท่าของ Animator (แบบเดียวกับ HeadTurn) จากข้อมูล `src/shared/HumanClipData.luau`
- **แก้/เพิ่มท่า:** แก้ `c_<ชื่อ>` ใน `build_anims.py` (ใส่ชื่อใน `EMOTES`, ท่าเล่นครั้งเดียวใส่ `ONCE`) → bake + `export_clip_data` → `python tools/blender/clips_to_luau.py <anims.json>`
  - ตัวแปลงใช้ท่าพักของกระดูก Roblox ใน `tools/studio/human_base_rbx_rest.json` (นำเข้า rig ใหม่ต้องวัดใหม่ด้วย `HumanAnimImport.restFrames`)
  - `SUBSETS` ใน `clips_to_luau.py` = คลิปที่เอาแค่บางกระดูก: `walk` (สะโพก+ขา สำหรับคนเต้นตามขบวน), `carry_gallon_r` (แขนขวาถือแกลลอน)
- **ท่านอน:** หมุนกระดูก `root` −90° (หงาย) — RootPart ของ NPC ยังตั้งอยู่ ตัวที่เห็นนอนบนพื้นตรงจุดที่ยืน
- **หน้าตา:** `build_skin.py` `FACES` + `make_face_textures` วาด texture ผิวทั้งแผ่นต่อ 1 หน้า → `human_base/faces/human_base_face_<หน้า>_Color.png` (+ `faces_preview.png`)
  - รัน: `faces_char("male")` (ดู `--faces` ท้ายไฟล์)
  - ในเกมสลับ `SurfaceAppearance` ของ BodyHead/Body/Skin_* เป็นชุดใน `src/shared/HumanFaceSets.model.json` (Rojo) ทำในแต่ละเครื่องตาม attribute เดียวกัน
  - ภาพอัปโหลดแล้ว (2026-11-03) ID อยู่ใน `human_base/faces/face_ids.json` และ model.json — วาดหน้าใหม่ต้องอัปโหลดใหม่แล้วแก้ทั้งสองที่
  - ภาพในเครื่อง (`rbxasset://`) ใช้กับ SurfaceAppearance ใน Roblox ไม่ได้ (ผิวเป็นสีเทา) runner จึงสลับเฉพาะชุดที่ติด attribute `Uploaded = true` (สคริปต์ในเกมอ่าน `ColorMap` ไม่ได้)
  - คืนหน้าปกติด้วยชุด `normal` (ผิวมาตรฐาน human_base) ใน model.json เดียวกัน: สคริปต์ในเกม Clone ผิวเดิมของ NPC ไม่ได้ (ได้ nil) และย้ายตัวเดิมกลับแล้วไม่ติด
    ⚠️ NPC ที่ server เปลี่ยนผิวเป็นแบบอื่น (เช่นผิวผี) ถ้าตั้งหน้าแล้วคืน จะกลับเป็นผิวมาตรฐาน — ตัวแบบนั้นอย่าใช้ SetFace หรือใช้หน้า `ghost`
- **กะพริบตา:** ทุกตัวที่หน้าปกติ (NPC จาก HumanNPC ติด tag `HumanEmote` + ตัวผู้เล่น) กะพริบเองทุก 2–6 วิ เฉพาะตัวที่อยู่ใกล้กล้อง 60 studs; ปิดด้วย attribute `NoBlink`
- **ถือของมือขวา + ไฟฉายมือซ้ายพร้อมกัน:** ItemSlots / HUDController ย้าย Tool เข้า/ออก Character เอง (ไม่ใช้ `EquipTool` ที่เก็บของอื่นทั้งหมด); ขนมตาลบนใบตอง = ท่า `hold_tray_r` (มือขวาแบหงาย), แกลลอน = `carry_gallon_r` (ทั้งสองเล่นจาก runner)

## 6. ทดสอบใน Studio ผ่าน MCP (เคล็ดลับ)

- **Rojo เขียนเข้า Studio ไม่ได้ระหว่าง Play:** ถ้าแก้ไฟล์ตอนที่ Play อยู่ สคริปต์ใน Studio อาจค้างครึ่งเดียว (เคยเกิดกับ CoreLoop: มีโค้ดใหม่แต่ไม่มีค่าคงที่ → error)
  - วิธีแก้: หยุด Play แล้วเทียบ Source ทุกสคริปต์กับไฟล์ (เสิร์ฟ `src/` ผ่าน http) เขียนทับตัวที่ไม่ตรง
  - เช็กทุกครั้งก่อน Play ว่าบรรทัดล่าสุดที่แก้อยู่ใน Studio แล้ว
- `StarterCharacterScripts` ยังไม่ถูก Rojo sync จนกว่าจะ restart `rojo serve` → ใส่ `Animate` เองผ่าน http แล้ว
- require ModuleScript จาก MCP ได้ **instance แยก** ของโมดูล (เช่น `Power`) ไม่ใช่ตัวที่เกมใช้อยู่ → สั่งงานผ่าน `ServerStorage.DevDecision:Fire(...)` หรือ remote `Admin` แทน
  - คำสั่ง DevDecision: `open`, `spawn`, `car`, `walker`, `party`, `lose`, `kill:<UserId>`, `revive:<UserId>`, `fuel`, `powercut` ...
  - ผีคันถัดไป: `DevDecision:SetAttribute("ForceAnomaly", "Anomaly_Headless")`
- คัทซีนหลายคน (ไม่ต้องเปิดหลาย client): แผง admin (F2) > คัทซีน เลือกจำนวนคน 1–6 แล้วกดเล่นคัทซีน / ชนะทันที
  - หรือจาก MCP: `ServerStorage.DevDecision:SetAttribute("CutsceneDummies", n)` แล้ว `Fire("intro")` / `Fire("win")` (ใช้ครั้งเดียวแล้วล้าง) หรือ remote `Admin` ส่ง `"intro@5"` / `"win@5"`
  - หุ่น = โคลนตัวผู้เล่นจริง (`CutsceneDummyN` ใน Workspace) นั่ง/ลงรถ/เดินผ่านโค้ด Cutscene.luau เดียวกัน เฉพาะ Studio; ผู้เล่นจริงกดข้าม = จบคัทซีน ลบหุ่น
  - ข้ามคัทซีนจาก MCP: client `Remotes.Cutscene:FireServer("skip")`
  - ดูมุมใกล้ระหว่างคัทซีน: client `BindToRenderStep` priority สูงกว่า `Last` ตั้งกล้องเอง (อย่าลืม Unbind) / ซ่อน ScreenGui ชั่วคราวถ้าหน้าสรุปผลบัง
- ProximityPrompt กดจากสคริปต์ไม่ติด (`InputHoldBegin`) → ใช้ `user_keyboard_input` กด E จริง และยืนห่าง < 9 studs หันหน้าเข้า
- `VirtualInputManager` ใช้จาก MCP ไม่ได้ → ทดสอบจังหวะกดแม่นๆ ไม่ได้ ตรวจตรรกะแทนแล้วให้เจ้าของลองเล่น
- screen_capture ใน Play: ส่งตำแหน่งกล้องมักไม่ตรง → ตั้ง `CameraType = Scriptable` แล้วล็อก CFrame ด้วย RenderStepped เอง แล้วถ่ายแบบไม่ส่งตำแหน่ง
  - ถ้าปลด render step ของ Animate (`VillagerBodyVisible`) Roblox จะซ่อนตัวเอง ต้องตั้ง LocalTransparencyModifier = 0 เอง
- เจ้าของอาจกด Play ทดสอบเองพร้อมกัน: ถ้า Edit ใช้ไม่ได้ / Play หยุดเอง อย่ากด start/stop แย่ง ให้ถามก่อน

---

## 7. บทเรียนจากปัญหาที่เคยเจอ

| อาการ | สาเหตุ | วิธีแก้ |
|---|---|---|
| พนมมือเป็นสามเหลี่ยม / ห่างกัน | ค่าแขนเดาด้วยมือ | sweep ให้ข้อมือ+ปลายนิ้วกลางอยู่กึ่งกลาง ฝ่ามือขนานกัน, รูปมือ `wai` นิ้วตรงชิด นิ้วโป้งแนบกัน |
| นิ้วของท่าพนมมืองอตอนเดิน | นิ้วตรง = ท่าพัก หลุดจากคลิป | `KEEP_TRACKS` |
| มือทะลุร่ม/ไฟฉาย หรือดูแปะ | ใช้ `fist` ปิดสุด / วางของตามแนวแขนท่อนล่าง | grasp search + วางของตามกรอบมือ |
| มือหายในมุมบุคคลที่หนึ่ง | ท่าถือเล่นแค่ 0.55 (นิ้วไม่ถึง) + กระบอกบังมือ | เล่นเต็ม 1.0, จับจากด้านบน |
| ข้อมือเหมือนหัก | บังคับรูกำมือชี้หน้าด้วยข้อมืออย่างเดียว | จับจากด้านบน แขนพาดหน้าอก |
| ไฟฉายสองอัน / ลอยค้าง | Animate บังคับโชว์ทุกชิ้นรวม Tool | ซ่อนชิ้นใน Tool บนจอตัวเอง; ตอนตาย `UnequipTools` |
| ไฟฉายไม่มีแสง | `Tool.Equipped` ไม่เกิดกับตัวที่ไม่มี RightHand | ดู Parent ของ tool แทน Equipped, weld Handle เอง (`VillagerGrip`) |
| คนอื่นเห็นไฟฉายตกพื้น | ไม่มี RightGrip weld | weld กับ HRP + client ขยับ C0 ตามกระดูกมือ |
| ขาคนขับมอไซค์ไขว้ทะลุรถ | เลือกเป้าเท้าจากชื่อชิ้น (ชื่อกลับข้าง) | เลือกตามตำแหน่ง |
| คนขับรถยนต์ใส่หมวกชนหลังคา | — | `noHat` |
| ล้อรถไทยไม่หมุน | `wheelsOf` หาแต่ชื่อแบบเก่า | หา Model `Wheels` ทุกชั้น |
| ท่าก้าวเล่นตอนล้มตาย | การหมุนตัวตอนล้มนับเป็นหันตัว | เช็ก anchored ก่อน |
| จอตายไม่ขึ้น | `WaitForChild("PlayerModule")` ไม่มีกำหนด (เกมนี้ไม่มี) | timeout 1 วิ |
| UI จางที่มุมจอ | ขอบมืด DisplayOrder เท่า HUD สร้างทีหลังเลยทับ | ขอบมืด DisplayOrder −1 |
| หัวข้อหน้าโหลดโดนปุ่ม Roblox บัง | IgnoreGuiInset แล้ววางที่ y 42 | วางใต้ `GuiService:GetGuiInset().Y` (หมายเหตุ: `AbsolutePosition` ไม่นับแถบนี้) |
| หน้าโหลดค้าง | error ในโค้ดเพลงหยุด thread หน้าโหลด | แยกงานเสียงเป็น `task.spawn` |
| เพลงถัดไปไม่เล่น | `Play()` ใน `Ended` ทันทีหลังเปลี่ยน SoundId | รอ `IsLoaded` ก่อน |
| เสียงใหม่ไม่ดัง | เกมไม่มีสิทธิ์ใช้ asset ("User is not authorized") | เจ้าของกด "Click to share access" ใน Output |
| กดตรงจังหวะแล้วไม่ผ่าน (มินิเกม) | เทียบตำแหน่งตอนกด เข็มวิ่งเร็ว + latency | ใช้มุมที่แสดงบนจอ / ย้อนดูตำแหน่ง 0.15 วิ + เผื่อขอบ |
| python replace ไม่ติด | ไฟล์ .luau บางไฟล์เป็น CRLF / tab ไม่ตรง | ใช้ Edit tool หรือ normalize ก่อน; พิมพ์ภาษาไทยต้องตั้ง `PYTHONIOENCODING=utf-8` |
| path ใน Python มี `\b` `\r` | escape ใน string | ใช้ `/` หรือ raw string |

---

## 8. ข้อตกลงกับเจ้าของ (ล่าสุด)

- คุยเป็นภาษาไทย, ส่งภาพให้ดูทุกครั้ง (ไฟล์ในเครื่อง ห้าม Artifact)
- commit/push เมื่อเจ้าของสั่ง "commit + push" เท่านั้น ตอนนี้ทำบน `main` ลบ `.preview` (ภาพตัวอย่าง) ก่อน commit
- ท่าเต้นต้องสุภาพ, ระวังการวางตำแหน่งชายหญิง, ท่ายืนขาห้ามขยับ, กล้องห้ามทะลุโมเดล, UI ธีมเดียวกับ HUD (ฟอนต์ SpecialElite) ไม่มี emoji
- เสียงใหม่ที่เจ้าของให้มา: ความดัง 50% ถ้าไม่ได้บอกอย่างอื่น
- ท่าใหม่: build ใน Studio แล้วให้เจ้าของ publish ทับ ID เดิม
- **แก้ของที่อัปโหลดแล้ว (ท่า model ภาพ) ต้องอัปทับ ID เดิมเสมอ ห้ามอัปเป็น asset ใหม่ (รกคลังของเจ้าของ)** — เครื่องมือ `upload_image` ของ Studio MCP สร้าง asset ใหม่ทุกครั้ง ใช้ได้เฉพาะของใหม่จริงๆ ถ้าเป็นภาพเดิมที่แก้ ให้แจ้งเจ้าของก่อน
  ID ที่มีอยู่: `src/shared/HumanAnimIds.luau`, `human_base/faces/face_ids.json`, `src/shared/HumanFaceSets.model.json`
