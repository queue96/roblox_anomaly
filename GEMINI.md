---
trigger: always_on
---
# Project Memory & Context: ปั๊มหลอด & เพิงปะยางท้ายทุ่ง (The Rural Tire & Gas Shack)

คุณกำลังช่วยผู้พัฒนาสร้างเกม **Roblox แนว Co-op Horror Anomaly (รองรับผู้เล่น 1–4 คน)** ชื่อโปรเจกต์ **"ปั๊มหลอดท้ายทุ่ง (Midnight Rural Gas & Tire)"**

## 1. คอนเซ็ปต์หลักที่ตกลงกันไว้แล้ว
- **บรรยากาศ:** ชนบทไทยมืดๆ ที่ความเจริญเข้าไม่ค่อยถึง (ถนนดินลูกรัง, ทุ่งนามืด, หุ่นไล่กา, ดงกล้วยตานี, เพิงสังกะสีไม้ไผ่, ตู้ปั๊มน้ำมันหลอดแก้วมือหมุน, ถังปั๊มลมปะยาง)
- **เงื่อนไขการชนะ (Win Condition - Quota System):** ให้บริการรถชาวบ้านที่แวะมาตอนดึกจนเก็บเงินในกระป๋องครบ **500 บาท** (คนปกติเติมน้ำมันได้ +100฿ / ปิดร้านหนีผีได้โบนัส +50฿)
- **พลังชีวิตทีม:** ใช้ **ธูป 3 ดอกที่ศาลพระภูมิข้างเพิง** แทนหลอดเลือด HP (ถ้าเผลอเติมน้ำมันให้ผี ธูปจะดับทีละ 1 ดอก พร้อมโดนหักเงิน -100฿ ถ้าดับครบ 3 ดอก = Game Over)
- **โทนของเกม:** หลอนบรรยากาศชนบทไทยแท้ 70% + ตลก/มีมโบ๊ะบ๊ะเวลาเล่นกับเพื่อน 30%
- **การรองรับภาษา:** รองรับ 2 ภาษา (**ไทย TH / อังกฤษ EN**) ทั้งป้ายในฉาก, คำพูดลูกค้า (`LanguageModule.luau`), และ `AutoLocalize`

## 2. โครงสร้างการรับมือ Anomaly 3 ระดับ (เพื่ออัปเดตระยะยาวบนแมพเดิม)
- **Tier 1 (V1.0 - 22 แบบ):** ความผิดปกติที่คนขับ/คนซ้อน/ตัวรถ/วิทยุ/ดงกล้วย/ของในเพิง -> **วิธีแก้:** ห้ามเติมน้ำมัน ให้วิ่งไปดึงเชือกปิดแผงสังกะสีหน้าร้าน (`ShutterDoor`)
- **Tier 2 (Update 1.1 - 4 แบบ):** ผีป่วนอุปกรณ์ (เครื่องปั่นไฟดับ, ถังลมคลั่ง, ห้องน้ำสังกะสีเปิดเอง, วิทยุกรีดร้อง) -> **วิธีแก้:** แบ่งเพื่อนเดินถือไฟฉายไปกดซ่อมที่จุดเกิดเหตุ
- **Tier 3 (Update 1.2 - 4 แบบ):** บอสอาถรรพ์บุกประชิด (ผีกระสือลอยมาจากนา, เปรตเดินผ่านถนน, ขบวนแห่ศพ) -> **วิธีแก้:** สับคัตเอาต์ดับไฟในเพิง (`CutoutSwitch`) + ก้มหมอบห้ามขยับ 5 วินาที
- **5+1 จุดวางของเผื่ออัปเดตในแมพ (Prop Hooks ที่วางไว้ตั้งแต่วันแรก):** 🪞 กระจกเงาบานเก่า (`OldMirror`), 🖼️ รูปขาวดำตาเจ้าของอู่ & ปฏิทิน (`OwnerPhoto`), ⚡ สวิตช์คัตเอาต์ไฟ (`CutoutSwitch`), 🧊 ถังแช่น้ำแข็ง (`IceBox`), 🚪 ห้องน้ำสังกะสีท้ายดงกล้วย (`TinOuthouse`), และ 🌳 ต้นไทรใหญ่พันผ้าสามสี (`SacredBanyanTree` / `SacredThaiRibbons` / `BanyanShadowAnomaly`)

## 3. ลำดับเฟสการพัฒนา (เริ่มจากปั้น Map ก่อน -> ค่อยใส่โค้ด)
ดูรายละเอียดทั้งหมดได้ในไฟล์ `GDD.md`, `index.html`, และ `phases.html` ในโฟลเดอร์นี้:
1. **Phase 1 (เสร็จสมบูรณ์ ✅):** ปั้น Map โคกดินกลางทุ่งนาล้อม 4 ด้าน, ถนนดินดำระบายสีลงบน `Terrain`, ดงกล้วยตานี, ศาลพระภูมิ, โซนต้นไทรใหญ่พันผ้าสามสี, แนวต้นไม้ชายทุ่ง 2 ชั้น + กำแพงล่องหน และระบบสลับแสง `DayDevLighting` (ตอนจัดฉาก) / `NightLighting` (ตอนกด Play)
2. **Phase 2 (กำลังจะเริ่มถัดไป ⏳):** เตรียมโมเดลรถแม่แบบ (`CustomerBike`) และซ่อนชิ้นส่วนผี (`Transparency = 1`) ไว้ใน `ServerStorage.VehicleTemplates`
3. **Phase 3:** เขียนโค้ด Core Loop (`GameManager.server.luau` & `LanguageModule.luau`) สั่งรถวิ่งมาจอด เติมน้ำมัน ดึงแผงปิดร้าน นับเงิน 500฿ และธูป 3 ดอก
4. **Phase 4:** เขียนโค้ดสุ่มผี (`AnomalyManager.luau`), ไฟฉายกบ (`FrogFlashlight`), และระบบ Jumpscare
5. **Phase 5:** ทำหน้าจอ HUD, สมุดสะสมผีไทย 30 แบบ (`Collection Book`), เปิด `AutoLocalize` และทดสอบ Co-op 1–4 คน

---

## 4. สถาปัตยกรรมโค้ดปัจจุบัน & กฎเหล็กสำหรับ AI ที่มารับงานต่อ (AI Handoff Guide)

### 📂 โครงสร้างไฟล์โค้ด (Rojo Sync บนพอร์ต `localhost:34872`)
- `default.project.json` & `start_rojo.bat`: ตั้งค่า Rojo ซิงค์โฟลเดอร์ `src/` เข้ากับ `RuralGasShack.rbxl`
- **แยก Rojo 2 place (เพิ่มเมื่อ 2026-10-28):** experience มี 2 place — **Lobby** (Start Place, PlaceId `70980777393906`) และ **Pump Lot** (แมพเกม, PlaceId `114125276809667`)
  - เกม → `default.project.json` + `start_rojo.bat` พอร์ต `34872` → กด Connect ในหน้าต่าง **Pump Lot** เท่านั้น (`blockedPlaceIds` กันไม่ให้ Connect เข้า Lobby)
  - Lobby → `lobby.project.json` + `start_rojo_lobby.bat` พอร์ต `34873` (`servePort`) → กด Connect ในหน้าต่าง **Lobby** และเปลี่ยน Port ในปลั๊กอินเป็น 34873 (`servePlaceIds` ยอมเฉพาะ Lobby)
  - **ClaudeDevBridge (plugin ใน `tools/studio/`, `.bat` ติดตั้งให้):** AI แก้ `src/lobby/dev/DevCommand.luau` (return `{ id, placeId, run }`) → Rojo sync เข้า `ServerStorage.DevCommand` → plugin รัน `run()` ใน Edit mode ครั้งเดียวต่อ `id` ใหม่ (เปลี่ยน id ทุกครั้ง) แล้ว print `DEVCMD|...` ให้อ่านจาก `%LOCALAPPDATA%\Roblox\logs\*Studio*_last.log` — ผู้ใช้ไม่ต้องรันคำสั่งใน Command Bar เอง
  - วัด Lobby: `BuildTempleLobby(Vector3.zero, true, 2)` = รั้ว 324 × 264 studs (พื้น 400 × 352), โบสถ์ชิดหลัง, ลานปูนโล่งกลางวัด (`TemplePlaza`) ไว้รวมตัวผู้เล่น + `LobbySpawn` กลางลาน, กุฏิย่อ 2/3 (ขนาดจริง), ทิศโมเดลที่ 3D Importer หมุนมาถูกวัดจากโบสถ์แล้วหมุนกลับอัตโนมัติ (`getTempleImportFix`, ชุดนี้ถูกหมุน 180°)
  - บรรยากาศหลอนใน `TempleLobby.SpookyDecor`: งานสวดอภิธรรมในศาลา (โลง รูป เทียน พวงหรีด 7 พวง), ธงขาวหน้าเมรุ, ต้นไทรพันผ้าสามสี + ศาลพระภูมิ + ของเซ่นแตก มุมหลังขวา, ดงกล้วยตานี 12 กอมุมหน้า, เสาไฟไม้ 6 ต้นรอบลาน, โอ่งมังกรหน้ากุฏิ, หญ้ารก 70 กอ, เงาผู้หญิงชุดขาวใต้ต้นไทร (tag `Apparition` จางหายเมื่อเข้าใกล้ 45 studs) — `LobbyServer` ตั้งแสงกลางคืนซีดเย็น (`LobbyGrade`), `LobbyClient` เล่นเสียงจิ้งหรีด/ลม และกะพริบไฟ tag `FlickerLamp`
  - โค้ด Lobby อยู่ `src/lobby/server` → `ServerScriptService.Server`, `src/lobby/client` → `StarterPlayerScripts.Client`, และดึง `src/shared/LanguageModule.luau` + `src/shared/MapBuilder.luau` (ไว้รัน `BuildTempleLobby()` จัดฉากวัด) ไป `ReplicatedStorage.Shared` (ตั้งชื่อโฟลเดอร์ตรงกับของเกม เพื่อให้ Rojo ลบสคริปต์เกมรุ่นเก่าที่ค้างใน Lobby ออกเองตอน Connect)
- `src/shared/MapBuilder.luau`: โมดูลสร้างและตกแต่งฉากทั้งหมด พร้อมระบบแยกส่วน (Modular Non-Destructive Functions)
- `src/shared/LanguageModule.luau`: ตารางข้อความ 2 ภาษา (`TH` / `EN`) สำหรับป้าย, บทพูดลูกค้า, และ UI
- `src/server/GameManager.server.luau`: สคริปต์หลักฝั่ง Server (ตั้งค่าแสงกลางคืนตอนกด Play, ระบบไฟนีออนเสาไม้กะพริบ, ระบบดึงเชือก `RejectRope` ปิดแผงสังกะสี `ShutterDoor`)
- `src/client/HUDController.client.luau`: สคริปต์ฝั่ง Client แสดง HUD ยอดเงิน `฿0 / ฿500` และสถานะธูป 3 ดอก `🕯️🕯️🕯️`
- `src/client/GrassWind.client.luau`: ระบบลมฝั่ง Client (หญ้า, ตะไคร้, ต้นข้าว, ต้นกล้วย และต้นไม้เอนตามลม และใบต้นไทร/ต้นมะม่วงไหว) — รายละเอียดดูหัวข้อ 🌬️ ด้านล่าง
- `src/client/AmbienceController.client.luau`: บรรยากาศกลางคืนฝั่ง Client (เสียงจิ้งหรีดเหงาๆ + หมอกหนาวน่ากลัว) — รายละเอียดดูหัวข้อ 🌙 ด้านล่าง

### 🌙 ระบบบรรยากาศกลางคืน (`AmbienceController.client.luau`, เพิ่มเมื่อ 2026-10-22)
ทำฝั่ง Client ทั้งหมด (เสียง/หมอกเป็นของเฉพาะผู้เล่นแต่ละคน) สคริปต์จะรอจน Server สั่ง `SetNightLighting()` ให้ `Lighting.ClockTime` เป็นตอนกลางคืนก่อน แล้วค่อยปรับค่าทับ
- **หมอกหนาว:**
  - ปรับ `Lighting.RuralAtmosphere` ให้เป็นสีเทาอมฟ้าซีด (`Color 100,114,128`, `Decay 40,52,66`, `Density ~0.52`, `Haze 2.6`, `Glare 0`) และให้ `Density` ค่อยๆ หนาขึ้น/บางลงระหว่าง 0.44–0.58 ทุก 10–18 วินาที เหมือนมีหมอกลอยผ่าน
  - `Lighting.ColdNightGrade` (`ColorCorrectionEffect`) ทำให้ภาพโทนเย็นและสีซีด (`TintColor 205,220,240`, `Saturation -0.35`)
  - หมอกเรี่ยพื้น: Part ล่องหน `GroundMistEmitter` (กว้าง 120×120, อยู่ที่ระดับ `Y = 2.5`) อยู่ใต้ `Workspace.CurrentCamera` และย้ายตามกล้องทุกเฟรม มี `ParticleEmitter` ใช้ texture `smoke_main.dds`
  - ⚠️ คืนนี้มืดมาก ถ้าให้แสงในฉากคุมหมอกทั้งหมด (`LightInfluence = 1`) จะมองไม่เห็นหมอกเลย จึงตั้ง `LightInfluence = 0.25` + `Brightness = 0.6`
- **เสียงจิ้งหรีดเหงาๆ** (ทุกเสียงอยู่ใน `SoundService.Ambience` (`SoundGroup`) ที่ตัดเสียงทุ้มออก `LowGain -30` เพื่อลบเสียงรถไกลๆ ในไฟล์ต้นฉบับ + reverb กว้างๆ):
  - `CricketBed` (2D, `rbxassetid://9112764023`) จิ้งหรีดรอบตัวผู้เล่น เปิดเบาๆ
  - `EerieAir` (2D, `rbxassetid://9114244841`) เสียงลมหวิวเบามาก (volume 0.07) อยู่ใต้เสียงจิ้งหรีด
  - `GroveCrickets` (3D ที่ดงกล้วย `30,3,30`, `rbxassetid://9112764040`) และ `FieldCrickets` (3D ที่ทุ่งนาฝั่งตรงข้ามถนน `-20,3,-55`) ยิ่งเดินเข้าใกล้ยิ่งดัง
  - กลไกความเหงา: ทุก 45–110 วินาที จิ้งหรีดทุกตัวจะเงียบลงภายใน 2.5 วินาที (เหมือนมีอะไรเดินผ่าน) เงียบอยู่ 5–10 วินาที แล้วค่อยๆ ร้องกลับมาภายใน 8 วินาที
  - เสียงทั้งหมดเป็นของฟรีจาก Creator Store (ProSoundEffects)
- ทดสอบแล้วด้วยการรันโค้ดในโหมด Play ฝั่ง Client: เสียงโหลดและเล่นครบทั้ง 3 ไฟล์ และมองเห็นหมอกฟ้าคลุมแนวต้นไม้ไกลๆ
- 💡 ต่อยอด Phase 4: Anomaly ที่อยากให้จิ้งหรีดเงียบก่อนผีโผล่ ให้เรียก Tween เปลี่ยน `Volume` ของ Sound ใน `SoundService.Ambience` (ตอนนี้ยังไม่มี RemoteEvent สั่งจาก Server)

### 🌬️ ระบบลม (`src/client/GrassWind.client.luau` + `MapBuilder.TagWindPlants()`, ขยายเมื่อ 2026-10-23)
ทุกอย่างเอนไปทิศลมเดียวกัน (`WIND_DIR`) และมีคลื่นลมวิ่งผ่านทุ่ง ขยับเฉพาะฝั่ง Client ส่วนใน Edit mode ทุกอย่างนิ่ง
- **tag `WindSway`:** ทั้งต้นเอนจากโคน (จุดหมุน = ก้น bounding box) ใช้ได้ทั้ง `Model` และ `BasePart`
  - attribute ที่ตั้งได้: `SwayAmp` (แรงเอน, default 1), `SwaySpeed` (ความเร็ว, default 1), `SwayPush = false` (ไม่เอนหลบเวลาคนเดินชน)
  - กอหญ้า `WildGrassClump` (amp 1) / กอตะไคร้ `LemongrassClump` (amp 0.7): เอนหลบเวลาคนเดินชน
  - แผ่นต้นข้าว `RiceTiles/RiceTile` (213 แผ่น, amp 0.5, speed 1.15, ไม่เอนหลบคน) — แผ่นกว้าง 6 studs ถ้าเอนเกินนี้ขอบแผ่นจะลอยพ้นน้ำ
  - ต้นกล้วย `BananaTree_*` (amp 0.45, speed 0.75) และต้นไม้ชายทุ่ง `BorderTree_*` ที่ไม่มีใบมะม่วง (amp 0.3, speed 0.6, ไม่เอนหลบคน)
- **tag `LeafFlutter`:** ติดที่ Model ใบไม้ `BanyanLeaves` (ต้นไทร ~700 ใบ) และ `MangoLeaves` (ต้นมะม่วงบนภูเขา + `BorderTree` ที่เป็นมะม่วง ~110 ใบ/ต้น) ลำต้นนิ่ง แต่ใบไหวทีละใบคนละจังหวะ และยอดพุ่มโยกตามลม ย้ายใบทั้งหมดทีเดียวด้วย `Workspace:BulkMoveTo`
- **ประสิทธิภาพ (วัดแล้ว):** ขยับเฉพาะใบในพุ่มที่ห่างกล้องไม่เกิน 75 studs ที่ 12Hz ส่วนหญ้า/ข้าว/ต้นไม้ขยับในระยะ 110 studs ที่ 30Hz → FPS ลดจากตอนปิดสคริปต์ไม่ถึง 1 (41.7 เทียบกับ 42.8)
  - ⚠️ ห้ามติด `WindSway` ให้ Model ที่มีใบไม้หลายร้อยแผ่น เพราะ `PivotTo` ต้นมะม่วงชายทุ่ง 71 ต้นใช้เวลา 10ms ต่อเฟรม และจะขยับซ้อนกับ `LeafFlutter` ด้วย (`TagWindPlants` จะลบ tag นี้ออกให้เองถ้ามี `MangoLeaves`)
- tag ถูกบันทึกในไฟล์ place (รันใน Edit mode) **ถ้าสร้าง/วางต้นข้าว ต้นไม้ หรือใบไม้ใหม่ ต้องรันอีกครั้ง:** `require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).TagWindPlants()` (รันซ้ำได้)

### 🛕 ชุดวัดไทยชนบท สำหรับฉาก Lobby (เพิ่มเมื่อ 2026-10-23, **เตรียมโมเดลไว้ ยังไม่ได้วางในฉาก**)
ผู้พัฒนาจะเอาไปทำ Lobby แยกจากแมพปั๊ม **ห้ามวางวัดในเขตเล่นของแมพนี้**
- **ปั้นด้วยสคริปต์:** `tools/blender/thai_temple.py` (รัน Blender แบบ headless) → `assets/models/<ชื่อ>.fbx` + texture 1024 ชุดละ 4 ไฟล์, ไฟล์ต้นฉบับ `assets/models/thai_temple.blend`, ภาพตัวอย่าง `assets/models/previews/<ชื่อ>.png`, `ThaiTemple_Sheet.png` (รวม 8 ชิ้น) และ `ThaiTemple_Night_*.png` (จัดวางแบบ Lobby ตอนกลางคืน จาก `tools/blender/thai_temple_preview.py`)
- **8 ไฟล์:** `TempleGate` (ซุ้มประตู + พระในหน้าบัน + ป้ายชื่อวัด `TempleNameSign`/`_Plaque`), `TempleFence` (`FenceSegment` 12 studs, `FenceSegment_Half`, `FencePost`), `BoneStupa` (`_A`/`_B`/`_C` มีช่องรูปผู้ตาย), `Meru` (ปล่องไฟสูง 56 studs), `Ubosot` (+กำแพงแก้ว ใบเสมา ประตูเปิด เดินเข้าได้), `Kuti` (เรือนไม้ยกใต้ถุน กาแล), `Sala` (หลังคาสังกะสีเขียว), `BuddhaTrio` (ปางมารวิชัย 3 องค์บนฐานชุกชีลายกระจก)
- **ของใน Lobby (เพิ่ม 3 ไฟล์):** `DonationBoard` (ป้ายบริจาคเสาสูง 26 studs แผ่นป้าย 24 × 19.5 ห้อยโซ่ลงมาเกือบถึงพื้น (ขอบล่างสูง 2.5) หน้าป้ายเปล่า `DonationBoard_Face` 2 ด้าน ไว้ใส่ SurfaceGui ทำ dashboard ผู้บริจาค), `DonationBox` (ตู้บริจาคไม้สักหน้าบานกระจกบนแท่นกลึง สูง 7.8 มี `_Door`/`_Glass` แยก ช่องหยอดเงินด้านบน — จุดกดโดเนท), `ShopCart` (รถเข็นขายทุกอย่าง ผ้าใบลายทาง ของเต็ม 4 ชั้น ป้ายหน้า `ShopCart_Sign` — ใช้เป็นร้านค้า) · วางใน `BuildTempleLobby()` ที่ (-24, 50) / (-8.5, 28) / (22, 44)
- สีหม่นลง 18% และมืดลง 10% จากภาพอ้างอิง ป้ายทุกแผ่นเปล่า (ข้อความใส่ทาง SurfaceGui)
- **ขนาด (ให้ผู้เล่น 4 คนเดินสวนกันได้):** ช่องประตูวัด 14 × 17 studs, ประตูโบสถ์ 9.4 × 11.4 (ในโบสถ์กว้าง 18 เพดาน 15.6), ประตูกุฏิ 8.1 × 10.5 (เพดาน 12, ระเบียงลึก 8.4), เมรุใต้คาน 12 ช่องเสากลาง 9.3, ศาลาช่องเสา ≥ 8.2 ใต้คาน 12.9, บันไดทุกจุดสูงขั้นละ ≤ 0.8 studs · ขยายด้วย `PROP_SCALE` ในสคริปต์ (โบสถ์ 1.3, เมรุ 1.15, กุฏิ 1.5, ศาลา 1.15) · ลายทอง/ใบระกา/ลูกแก้วเป็น mesh ที่ปิด collision ทั้งหมด ชนเฉพาะกล่อง `Colliders`
- **วางฉาก (ยังไม่ได้รัน):** นำเข้า FBX ทั้ง 11 ไฟล์ด้วย 3D Importer แล้วรัน `require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildTempleLobby()` → ย้ายต้นแบบไป `ServerStorage.ImportedProps.ThaiTemple` และสร้าง `Workspace.TempleLobby` ที่ `(0, 0, 600)` (ส่ง `origin` อื่นได้, `rebuild = true` จะย้ายชุดเดิมไป `ArchivedPlaceholders` ก่อน) มีรั้วรอบ 162×132 studs (กุฏิ 2 หลังที่ z = 40 และ 8 ฝั่ง +X), ต้นมะม่วง 5 ต้น (ติด `LeafFlutter` ผ่าน `TagWindPlants()` อัตโนมัติ) และไฟสลัว 6 ดวง
- mesh ทุกชิ้น `CanCollide = false` แล้วสร้างกล่องชนล่องหน (`Colliders`) จากตาราง `TEMPLE_UNITS` ใน `MapBuilder.luau` — ตารางนี้สร้างจาก `tools/blender/temple_units_to_luau.py` ถ้าปั้นใหม่ให้รันสคริปต์นี้แล้วแทนตารางเดิม อย่าแก้มือ

### 🚗 รถและจักรยานสไตล์ไทย 8 คัน (เพิ่มเมื่อ 2026-10-23, แม่แบบอยู่ `ServerStorage.VehicleTemplates`)
`ThaiPickupOld` (กระบะ Hero เก่าโทรม คอกเหล็ก ฝากระโปรงปิด), `ThaiSedanSoluna` (เก๋งบรอนซ์ทอง 4 ที่นั่ง), `ThaiBicycleRed` (จักรยานแม่บ้านแดง ตะแกรงหลัง), `ThaiBicycleBlue` (ตะกร้าหน้า เบาะซ้อน), `ThaiTukTuk` (ป้าย TAXI คนขับ 1 + ผู้โดยสาร 2), `ThaiRacingMoto` (เวฟซิ่งส้มดำ ล้อซี่ลวดหลายสี ซ้อนท้ายได้), `ThaiSoundTruck` (กระบะรถแห่ ตู้ลำโพงไฟนีออน 5 สี + ฮอร์นบนตู้), `ThaiParadeTruck` (รถแห่ 6 ล้อหัวแดงทรง Hino ตู้สูงคร่อมหลังคาหัว เดินเข้าตู้ได้: ประตูท้าย + บันไดพับ 3 ขั้น, ในตู้เพดานสูง 14.8 กว้าง 9.4 ยาว 22, ชั้นลอยเหนือหัวเก๋ง (สูงโล่ง 6.2) ขึ้นด้วยบันไดในตู้ขั้นละ 0.78, โซฟายาว, เบาะหน้า 2 ที่)
- **ปั้นด้วยสคริปต์:** `tools/blender/thai_vehicles.py` (headless เหมือนชุดวัด) → `assets/models/<ชื่อ>.fbx` + texture 4 ไฟล์, `thai_vehicles.blend`, ภาพตัวอย่าง `previews/<ชื่อ>.png` / `_side.png` (มีหุ่นเทียบขนาด R15) และ `ThaiVehicles_Rig.json` (ที่นั่ง ล้อ ไฟ กล่องชน ชิ้น proxy)
  - แล้วรัน `python tools/blender/vehicle_rig_to_luau.py` → `src/shared/ThaiVehicleRigs.luau` (**ห้ามแก้มือ**) แก้ขนาด/ที่นั่งที่ `thai_vehicles.py` เท่านั้น
  - ขนาดใหญ่กว่าของจริง ~1.3 เท่าให้ตัวละคร R15 (สูง 5.65) นั่งได้: หัวห่างหลังคา กระบะ 1.2 / เก๋ง 0.8 / ตุ๊กตุ๊ก 1.4–1.8 / รถแห่ 1.5 studs · กระจกข้างสีชาเข้มเต็มบาน (mesh ไม่มี collision เดินผ่านประตูได้) · บังโคลนจักรยาน/มอเตอร์ไซค์แบบสั้น
  - ความสมจริง: เก๋ง / กระบะเก่า / กระบะรถแห่ / หัวเก๋งรถแห่ 6 ล้อ ปั้นด้วย `car_shell()` = เปลือกตัวถังชิ้นเดียวต่อเนื่องจากหน้าตัด 16 จุดเรียงตามแนวยาว (ซุ้มล้อโค้ง ขอบกระจก กระจกข้างเอียงเข้า หลังคาโค้ง ร่องประตู) กระจกแยกเป็น `<ชื่อ>_Glass` 2 ด้าน และผิวด้านในห้องโดยสาร `<ชื่อ>_Interior` (มองจากในรถไม่ทะลุ) · ชิ้นอื่นมี Bevel + Weighted Normal และหน้าตัดกลม 20 จุด · material เปิด backface culling เหมือน Roblox · ภาพเทียบกับรูปอ้างอิง: รัน `blender-launcher.exe --background assets/models/thai_vehicles.blend --python tools/blender/thai_vehicles_compare.py` แล้ว `python tools/blender/compare_sheet.py <โฟลเดอร์รูป 9.png-16.png>` → `previews/ThaiVehicles_RefCompare.png`
- **สร้างแม่แบบใน Studio:** `require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildThaiVehicleTemplates()` (รันซ้ำได้ ของเดิมย้ายไป `ArchivedPlaceholders.ThaiVehicles` เก็บไว้รุ่นเดียว ไม่แตะ `CustomerBike`/`Saleng`)
  - ⚠️ **สถานะ 2026-10-23: ลบแม่แบบรถไทยทั้ง 8 คันออกจาก Studio แล้ว (ผู้พัฒนาจะ Import เอง)** → File → Import 3D ไฟล์ `assets/models/Thai*.fbx` ทั้ง 8 ไฟล์ (โมเดลจะไปอยู่ใน Workspace) แล้วรันคำสั่งด้านบน (ถ้ายังไม่ได้นำเข้า ฟังก์ชันจะสร้างชิ้น Part แทนใน `Body.Proxy`) ฟังก์ชันจะหาโมเดลที่ชื่อตรงกัน จัดตำแหน่ง/ทิศ/ขนาดเองจากตำแหน่งล้อ ใช้ mesh แทน proxy และย้ายต้นฉบับไป `ServerStorage.ImportedProps.ThaiVehicles`
- **โครงสร้างแม่แบบ** (pivot = พื้นใต้กึ่งกลางรถ หน้ารถ -Z เหมือน `CustomerBike`, ทุกชิ้น anchored):
  - `Chassis` (PrimaryPart, ล่องหน) · `Body` (mesh หรือ proxy ทุกชิ้น `CanCollide = false`) · `Wheels/Wheel_*` (ต่อ `Motor6D` ชื่อ `Axle`) · `Colliders` (กล่องล่องหนที่ชนจริง + `Skid*` ลูกบอลลื่นที่ล้อ) · `DriverSeat` (`VehicleSeat`) + `PassengerSeat`/`RearSeat*` (`Seat`) · `Lights` (`Headlight*` มี `SpotLight` / `Taillight*`) · `LicensePlate*` (ป้ายทะเบียนไทย SurfaceGui) · `RoofSign*` (TAXI / SOUND WARS)
  - attribute: `VehicleKind`, `MaxSpeed`, `TurnRate`, `LightsOn`, `PlayerDrivable`, `LedColors` (รถแห่) · ชิ้นไฟลำโพงมี tag `VehicleLED` + `LedIndex`
- **ให้ผู้เล่นขับ:** `MapBuilder.SpawnThaiVehicle(name, cframe)` (ปลด anchored + tag `PlayerVehicle`) หรือ `MapBuilder.ParkThaiVehicles(origin)` วางครบ 8 คันใน `Workspace.ThaiVehicleShowcase` (ไว้ทดสอบ ยังไม่ได้วางในฉาก)
  - `src/server/ThaiVehicleDrive.server.luau` คุมเฉพาะรถที่มี tag `PlayerVehicle`: กด **F** ขึ้นนั่ง (หรือเดินชนเบาะ), **W/S** เร่ง/ถอย, **A/D** เลี้ยว, **L** เปิด/ปิดไฟหน้า, **Space** ลง · ขับแบบ arcade (`LinearVelocity` + `AlignOrientation` เอียงตามพื้นไม่เกิน 22° ไม่พลิกคว่ำ) ล้อหมุน/ล้อหน้าเลี้ยว ไฟ LED รถแห่ไล่สีตอนมีคนขับ
  - รถลูกค้าของ `CoreLoop` (Clone แม่แบบแล้ว `PivotTo`) ไม่ถูกสคริปต์นี้แตะ — ตอนนี้ `CoreLoop.pickTemplate()` ยังสุ่มแค่ `CustomerBike`/`Saleng` และรถไทยยังไม่มีคนขับ NPC / ชิ้นส่วนผีซ่อน
- **ทดสอบแล้วใน Play mode กับแม่แบบรุ่นก่อนปั้นเปลือกใหม่ (2026-10-23, ตัวละคร R15) — ต้องทดสอบซ้ำหลัง Import FBX ชุดใหม่:** นั่งได้ครบ 16 ที่นั่ง, ปุ่ม F ใช้ได้ทุกที่นั่ง (เดินชนเบาะแล้วนั่งเองได้ 12/16), ขับ W/A ได้ทุกแบบที่ลอง (กระบะ จักรยาน มอเตอร์ไซค์ ตุ๊กตุ๊ก), ปีนท้ายกระบะ/รถแห่ขึ้นไปยืนบนพื้นกระบะได้ (มีกล่องกันมุดใต้ท้องรถ), ปุ่ม L สลับไฟหน้าได้ (กันกดเบิ้ล) · รถแห่ 6 ล้อ: นั่งหน้า 2 ที่ (หัวห่างหลังคา 1.8), เดินขึ้นบันไดท้ายเข้าตู้ได้โดยไม่ต้องกระโดด, ขึ้นชั้นลอยได้, ขับ/เลี้ยวได้

### 🗺️ โครงสร้างฉากใน `Workspace` และคลังโมเดลใน `ServerStorage`
1. **`Workspace.MapEnvironment`:**
   - `ShackStructure`: เพิงสังกะสีไม้ไผ่ตรงกลาง (`X = 0, Z = 18`) พร้อมโต๊ะไม้, วิทยุทรานซิสเตอร์, และ Prop Hooks ทั้ง 5 จุด
   - `BananaGrove`: ดงกล้วยตานี 26 ต้น (ผสมต้นแม่/ต้นกลาง/ต้นเล็กจาก `ServerStorage.ToolboxBananaTemplates`) อยู่ฝั่งซ้ายของเพิง (`+X`)
   - `SacredBanyanZone`: โซนต้นไทรใหญ่โบราณพันผ้าสามสี (`SacredBanyanTree`, `SacredThaiRibbons`), ตุ๊กตาม้าลายแตก/นางรำ (`BrokenOfferings`), และชุดโต๊ะม้าหินอ่อนเก่า (`OldMarbleBenchSet`) อยู่ฝั่งขวาหลังศาลพระภูมิ (`-X`)
   - `DirtRoad`: ถนนดินดำชื้นระบายสีลงบน `Workspace.Terrain` โดยตรง (`Enum.Material.Ground` + ร่องล้อ `Enum.Material.Mud`), เสาไฟไม้กะพริบ (`WoodenPole`, `NeonLightPart`), หลักกิโลเมตรที่ 4 (`KilometerMilestone`), และแอ่งน้ำขัง (`MudPuddle_1..3`)
   - **ทุ่งนาล้อม 4 ด้าน (แยกเป็น 4 `Model` อิสระ ห้ามยุบรวมกัน):**
     - `RiceField`: ทุ่งนาฝั่งตรงข้ามถนน (`-Z`) พร้อม `PaddyWater`, กอข้าว `Tall Grass`, หุ่นไล่กา (`Scarecrow`), และเถียงนาร้าง (`DistantRiceHut`)
     - `LeftRiceField`: ทุ่งนาขนาบฝั่งซ้าย (`+X` ถัดจากดงกล้วย) พร้อม `PaddyWater_Left` และกอข้าว
     - `RightRiceField`: ทุ่งนาขนาบฝั่งขวา (`-X` ถัดจากต้นไทร) พร้อม `PaddyWater_Right` และกอข้าว
     - `BackRiceField`: ทุ่งนาด้านหลังเพิงร้าน (`+Z`) พร้อม `PaddyWater_Back` และกอข้าว
   - `OuterTreeLine`: แนวต้นกล้วยและพุ่มไม้ทึบชายทุ่ง 2 ชั้น (`BorderTree_*`, `BorderBush_*`) รอบขอบนอกสุด + แผ่นต่อถนนเส้นขอบฟ้า (`RoadHorizonExt_Left/Right`) เพื่อบังไม่ให้เห็นจุดตกโลก
   - `InvisibleWalls`: กำแพงล่องหน 4 ด้าน (`InvisibleWall_Front/Back/Left/Right`) กั้นผู้เล่นไว้ด้านในก่อนถึงแนวต้นไม้ขอบแมพ
2. **`Workspace.InteractiveProps`:** `GasPump`, `AirCompressor`, `MoneyTin`, `RejectRope`, `ShutterDoor`, `Generator`, `CutoutSwitch`
3. **`Workspace.SpiritHouse`:** ศาลพระภูมิไม้สักเก่าพร้อมธูปเรืองแสง 3 ดอก (`Incense1`, `Incense2`, `Incense3`)
4. **`Workspace.AnomalyProps`:** เก็บชิ้นส่วนผีและ Anomaly รอสั่งเปิดใช้งาน (`GhostTani`, `PhiTaKhonMask`, `KrasueLight`, `BanyanShadowAnomaly` เงาคนแอบหลังต้นไทร)
5. **`Workspace.VehicleWaypoints`:** `SpawnPoint` -> `StopPoint` -> `ExitPoint`
6. **`ServerStorage` (คลังแม่แบบที่คัดแยกจาก Toolbox แล้ว):**
   - `ToolboxBananaTemplates` (ต้นกล้วย 6 แบบ), `ToolboxGrassTemplates` (กอหญ้าพุ่มฟู `Tall Grass` 2 แบบ), `ToolboxRadioTemplates`, `ToolboxScarecrowTemplates`, และ `ArchivedToolboxSpiritHouse`
   - `VehicleTemplates`: `CustomerBike`, `Saleng` + รถไทย 8 คัน (ดูหัวข้อ 🚗)

### ⚠️ กฎเหล็กสำคัญมากสำหรับ AI (ห้ามละเมิดเด็ดขาด!)
1. **ห้ามสั่ง `MapBuilder.Build()` ทับฉากโดยไม่จำเป็น:** ผู้พัฒนาได้ลากจัดวางตำแหน่งวัตถุใน Roblox Studio ด้วยมือไว้แล้ว ใน `GameManager.server.luau` จึงเช็ก `if not Workspace:FindFirstChild("MapEnvironment") then MapBuilder.Build() end` เสมอ หากต้องการแก้ไขหรือเพิ่มโซนในฉาก **ต้องเขียนเป็นฟังก์ชันย่อยแยกต่างหากใน `MapBuilder.luau`** (เช่น `PaintTerrainRoad()`, `AddSacredBanyanZone()`, `AddSideRiceFields()`, `SplitSideRiceFields()`, `BuildCompactPerimeter()`) ที่แก้ไขเฉพาะจุดโดยไม่แตะต้องของเดิม!
2. **การใช้ Command Bar ใน Roblox Studio:** เวลาให้ผู้พัฒนารันคำสั่งในช่อง Command Bar ต้องเติม `:Clone()` เสมอ เช่น `require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildCompactPerimeter()` เพื่อป้องกัน Roblox Studio แคช `ModuleScript` ตัวเก่าไว้ในหน่วยความจำ!
3. **ค่าหมอก/สีของ Atmosphere ตอนเล่นถูก Client กำหนดอีกรอบ:** ถ้าจะแก้หมอกตอนเล่น ให้แก้ใน `AmbienceController.client.luau` ไม่ใช่แก้ใน `MapBuilder.SetNightLighting()` เพราะค่าใน `SetNightLighting()` จะถูก Client ปรับทับหลังจากนั้นประมาณ 1 วินาที
