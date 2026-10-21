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
