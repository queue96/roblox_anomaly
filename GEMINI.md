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

### ⚠️ กฎเหล็กสำคัญมากสำหรับ AI (ห้ามละเมิดเด็ดขาด!)
1. **ห้ามสั่ง `MapBuilder.Build()` ทับฉากโดยไม่จำเป็น:** ผู้พัฒนาได้ลากจัดวางตำแหน่งวัตถุใน Roblox Studio ด้วยมือไว้แล้ว ใน `GameManager.server.luau` จึงเช็ก `if not Workspace:FindFirstChild("MapEnvironment") then MapBuilder.Build() end` เสมอ หากต้องการแก้ไขหรือเพิ่มโซนในฉาก **ต้องเขียนเป็นฟังก์ชันย่อยแยกต่างหากใน `MapBuilder.luau`** (เช่น `PaintTerrainRoad()`, `AddSacredBanyanZone()`, `AddSideRiceFields()`, `SplitSideRiceFields()`, `BuildCompactPerimeter()`) ที่แก้ไขเฉพาะจุดโดยไม่แตะต้องของเดิม!
2. **การใช้ Command Bar ใน Roblox Studio:** เวลาให้ผู้พัฒนารันคำสั่งในช่อง Command Bar ต้องเติม `:Clone()` เสมอ เช่น `require(game.ReplicatedStorage.Shared.MapBuilder:Clone()).BuildCompactPerimeter()` เพื่อป้องกัน Roblox Studio แคช `ModuleScript` ตัวเก่าไว้ในหน่วยความจำ!
3. **ค่าหมอก/สีของ Atmosphere ตอนเล่นถูก Client กำหนดอีกรอบ:** ถ้าจะแก้หมอกตอนเล่น ให้แก้ใน `AmbienceController.client.luau` ไม่ใช่แก้ใน `MapBuilder.SetNightLighting()` เพราะค่าใน `SetNightLighting()` จะถูก Client ปรับทับหลังจากนั้นประมาณ 1 วินาที
