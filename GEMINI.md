---
trigger: always_on
---
# Project Memory & Context: ปั๊มหลอด & เพิงปะยางท้ายทุ่ง (The Rural Tire & Gas Shack)

คุณกำลังช่วยผู้พัฒนาสร้างเกม **Roblox แนว Co-op Horror Anomaly (รองรับผู้เล่น 1–4 คน)** ชื่อโปรเจกต์ **"ปั๊มหลอดท้ายทุ่ง (Midnight Rural Gas & Tire)"**

## 1. คอนเซ็ปต์หลักที่ตกลงกันไว้แล้ว
- **บรรยากาศ:** ชนบทไทยมืดๆ ที่ความเจริญเข้าไม่ค่อยถึง (ถนนดินลูกรัง, ทุ่งนามืด, หุ่นไล่กา, ดงกล้วยตานี, เพิงสังกะสีไม้ไผ่, ตู้ปั๊มน้ำมันหลอดแก้วมือหมุน, ถังปั๊มลมปะยาง) และมี **Lobby วัดไทยชนบทตอนกลางคืน** แยกเป็น Start Place ต่างหาก
- **วิธีสังเกตสิ่งผิดปกติ (Core Mechanic - พนมมือสวดมนต์เปิดตาทิพย์):** เปลี่ยนจากการใช้ไฟฉายส่องดูผี มาเป็นการ **กดค้าง `G` (PC) / `Y` (จอย) / ปุ่ม `🙏` (มือถือ) พนมมือสวดมนต์ 1.5 วินาที เพื่อเปิด "ตาทิพย์" (`PrayerSight`)** มองเห็นสิ่งที่ติด tag `GhostOnly` (และซ่อน `NormalOnly`) เฉพาะบนหน้าจอของคนที่พนมมือเท่านั้น! (ขณะพนมมือจะเก็บไฟฉายและเดินไม่ได้ ส่วนไฟฉายกบ `FrogFlashlight` ใช้สำหรับส่องทางในความมืดตามปกติ)
- **เงื่อนไขการชนะ (Win Condition - Quota System):** ให้บริการรถชาวบ้านที่แวะมาตอนดึกจนเก็บเงินในกระป๋องครบ **1,500 บาท** (`CoreLoop.CONFIG.TargetMoney`, เดิม 500 แต่จบเร็วไป ~5 นาที ปรับเมื่อ 2026-10-28) (คนปกติเติมน้ำมันได้ +100฿ / ปิดร้านหนีผีได้โบนัส +50฿)
- **พลังชีวิตทีม:** ใช้ **ธูป 3 ดอกที่ศาลพระภูมิข้างเพิง** แทนหลอดเลือด HP (ถ้าเผลอเติมน้ำมันให้ผี ธูปจะดับทีละ 1 ดอก พร้อมโดนหักเงิน -100฿ ถ้าดับครบ 3 ดอก = Game Over)
- **โทนของเกม:** หลอนบรรยากาศชนบทไทยแท้ 70% + ตลก/มีมโบ๊ะบ๊ะเวลาเล่นกับเพื่อน 30%
- **การรองรับภาษา:** รองรับ 2 ภาษา (**ไทย TH / อังกฤษ EN**) ทั้งป้ายในฉาก, คำพูดลูกค้า (`LanguageModule.luau`), และ `AutoLocalize`

## 2. โครงสร้างการรับมือ Anomaly 3 ระดับ (เพื่ออัปเดตระยะยาวบนแมพเดิม)
- **Tier 1 (V1.0 - 22 แบบ):** ความผิดปกติที่คนขับ/คนซ้อน/ตัวรถ/วิทยุ/ดงกล้วย/ของในเพิง (ตรวจสอบด้วยการพนมมือสวดมนต์เปิดตาทิพย์) -> **วิธีแก้:** ห้ามเติมน้ำมัน ให้วิ่งไปดึงเชือกปิดแผงสังกะสีหน้าร้าน (`ShutterDoor`)
- **Tier 2 (Update 1.1 - 4 แบบ):** ผีป่วนอุปกรณ์ (เครื่องปั่นไฟดับ, ถังลมคลั่ง, ห้องน้ำสังกะสีเปิดเอง, วิทยุกรีดร้อง) -> **วิธีแก้:** แบ่งเพื่อนเดินถือไฟฉายไปกดซ่อมที่จุดเกิดเหตุ
- **Tier 3 (Update 1.2 - 4 แบบ):** บอสอาถรรพ์บุกประชิด (ผีกระสือลอยมาจากนา, เปรตเดินผ่านถนน, ขบวนแห่ศพ) -> **วิธีแก้:** สับคัตเอาต์ดับไฟในเพิง (`CutoutSwitch`) + ก้มหมอบห้ามขยับ 5 วินาที
- **5+1 จุดวางของเผื่ออัปเดตในแมพ (Prop Hooks ที่วางไว้ตั้งแต่วันแรก):** 🪞 กระจกเงาบานเก่า (`OldMirror`), 🖼️ รูปขาวดำตาเจ้าของอู่ & ปฏิทิน (`OwnerPhoto`), ⚡ สวิตช์คัตเอาต์ไฟ (`CutoutSwitch`), 🧊 ถังแช่น้ำแข็ง (`IceBox`), 🚪 ห้องน้ำสังกะสีท้ายดงกล้วย (`TinOuthouse`), และ 🌳 ต้นไทรใหญ่พันผ้าสามสี (`SacredBanyanTree` / `SacredThaiRibbons` / `BanyanShadowAnomaly`)
- **คลังข้อมูลอ้างอิงผีไทย 92 ตัว:** ดูรายละเอียด Rig, Status และ Animation สำหรับปั้นผีเพิ่มได้ใน `art_refs/ghosts/GHOSTS.md`

## 3. สถานะเฟสการพัฒนาปัจจุบัน (อัปเดตล่าสุด 2026-10-29)
ดูรายละเอียดทั้งหมดได้ในไฟล์ `GDD.md`, `README.md`, และ `art_refs/ghosts/GHOSTS.md`:
1. **Phase 1 (เสร็จสมบูรณ์ ✅):** ปั้น Map โคกดินกลางทุ่งนาล้อม 4 ด้าน, ถนนดินดำระบายสีลงบน `Terrain`, ดงกล้วยตานี, ศาลพระภูมิ, โซนต้นไทรใหญ่พันผ้าสามสี, แนวต้นไม้ชายทุ่ง 2 ชั้น + กำแพงล่องหน, ระบบลม (`GrassWind`), บรรยากาศกลางคืน (`AmbienceController`), และ **ฉากวัดไทยชนบทสำหรับ Lobby (`TempleLobby` แยก Place)**
2. **Phase 2 (เสร็จสมบูรณ์ ✅):** โมเดลรถแม่แบบ (`CustomerBike`, `Saleng`) + รถไทย 8 คัน (`ThaiVehicleRigs.luau`) และลูกค้าเดินเท้า (`Pedestrian.luau`) ใน `ServerStorage.VehicleTemplates`
3. **Phase 3 (เสร็จสมบูรณ์ ✅):** โค้ด Core Loop (`CoreLoop.luau` & `LanguageModule.luau`) คิวรถเป็นระลอก, ระบบทักทาย/ถามราคา, เติมน้ำมัน 2 ตู้ (เบนซิน/ดีเซล) + เติมลมจักรยาน, ดึงแผงปิดร้าน, เป้าหมายเงิน `1,500฿`, ธูป 3 ดอก, ระบบฝนตก (`Weather.luau`), และเหตุการณ์ขาจร (แว้น/รถซิ่ง/รถแห่งานบวช)
4. **Phase 4 (เสร็จสมบูรณ์ ✅):** โค้ดสุ่มผี 10 ตัวแรก (`AnomalyManager.luau`), **ระบบพนมมือสวดมนต์เปิดตาทิพย์ (`Prayer.luau` + `PrayerController.client.luau` แทนการส่องไฟฉายดูผี)**, ไฟฉายกบส่องทาง (`FrogFlashlight`), และระบบ Jumpscare (`JumpscareController.client.luau`) + จอตาย (`DeathScreen.client.luau`)
5. **Phase 5 (เสร็จสมบูรณ์ ✅ / กำลังขัดเกลาและขยายผีเพิ่ม ⏳):** หน้าจอ HUD (`HUDController.client.luau`), สมุดสะสมผีไทย (`AnomalyBook.luau` + `BookController.client.luau`), หน้าตั้งค่า (`PlayerSettings` + `SettingsController`), ระบบสร้างห้องในวัด Lobby ส่ง `TeleportData` ข้าม Place, และคลังข้อมูลผีไทย 92 ตัว (`art_refs/ghosts/GHOSTS.md`)

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
  - ป่ารอบวัด (`TempleLobby.Forest` มะม่วง 77 + กล้วย 43 ต้น 2 แนวนอกรั้ว) + `InvisibleWalls` ตามแนวรั้ว (ปิดประตูด้วย), `LobbyServer` ตั้งหมอก (FogStart 35 / FogEnd 230) และล็อกกล้องซูมออกได้ไม่เกิน 22 studs กันเห็นนอกแมพ
  - **โซนสร้างห้อง:** วง `RoomPad` 4 วงหน้าลาน (tag `RoomPad`, attribute `PadIndex`) เดินเข้าวงว่าง = เจ้าของห้อง เลือกผู้เล่น 1–6 + ความยาก (`src/shared/Difficulty.luau`: easy ×1 / normal ×1.5 / hard ×2 / nightmare ×3 เงินรางวัล) คนอื่นเดินเข้าวง = เข้าห้อง, เดินออก = ออก (เจ้าของออก = ปิดห้อง) เจ้าของกด "เริ่มเกม" → `ReserveServer` + `TeleportAsync` ไป Pump Lot พร้อม TeleportData `{ roomId, difficulty, maxPlayers, hostUserId }` (ใน Studio แค่ print) · ไม่กดเริ่มใน 30 วิ / กดยกเลิก / ไม่ตั้งห้องใน 30 วิ = ปิดห้องแล้วดีดกลับ `LobbySpawn` · วงไฟนีออน 6 วง 2 แถวข้างลาน · UI สไตล์เดียวกับหน้าตั้งค่าในเกม · Lobby ใช้ `SettingsController` / `BookController` / `PlayerSettings` / `AnomalyBook` ตัวเดียวกับเกม (DataStore เดียวกัน) — Remote อยู่ `ReplicatedStorage.LobbyRemotes`
  - โค้ด Lobby อยู่ `src/lobby/server` → `ServerScriptService.Server`, `src/lobby/client` → `StarterPlayerScripts.Client`, และดึง `src/shared/LanguageModule.luau` + `src/shared/MapBuilder.luau` (ไว้รัน `BuildTempleLobby()` จัดฉากวัด) ไป `ReplicatedStorage.Shared` (ตั้งชื่อโฟลเดอร์ตรงกับของเกม เพื่อให้ Rojo ลบสคริปต์เกมรุ่นเก่าที่ค้างใน Lobby ออกเองตอน Connect)
- `src/shared/MapBuilder.luau`: โมดูลสร้างและตกแต่งฉากทั้งหมด พร้อมระบบแยกส่วน (Modular Non-Destructive Functions)
- `src/shared/LanguageModule.luau`: ตารางข้อความ 2 ภาษา (`TH` / `EN`) สำหรับป้าย, บทพูดลูกค้า, และ UI
- `src/server/GameManager.server.luau`: สคริปต์หลักฝั่ง Server (ตั้งค่าแสงกลางคืนตอนกด Play, ล็อกมุมมอง First-Person + ปิดการกระโดด + `WalkSpeed = 10`, ระบบไฟนีออนเสาไม้กะพริบ, ระบบดึงเชือก `RejectRope` ปิดแผงสังกะสี `ShutterDoor`, กระจายดงกล้วย `SpreadBananaGrove()`)
- `src/client/HUDController.client.luau`: สคริปต์ฝั่ง Client แสดง HUD ยอดเงิน `฿0 / ฿1500` (ซ่อนสถานะธูปเพื่อให้เดินไปดูที่ศาลพระภูมิเอง), แถบซับไตเติลคำพูดลูกค้าด้านล่างจอ, มินิเกมเติมน้ำมัน/เติมลม (`FuelView` / `AirView`), ช่องถือไฟฉาย `[1] ไฟฉาย`, โมเดลไฟฉาย 3D ล็อกตามมุมกล้อง (`CameraFlashlightViewmodel` + `CameraBeamLight`), และปุ่มสลับเมาส์ `V` / `LeftAlt`
- `src/server/Prayer.luau` + `src/client/PrayerController.client.luau`: ระบบพนมมือ (ดูหัวข้อ 🙏 ด้านล่าง)
- `src/client/GrassWind.client.luau`: ระบบลมฝั่ง Client (หญ้า, ตะไคร้, ต้นข้าว, ต้นกล้วย และต้นไม้เอนตามลม และใบต้นไทร/ต้นมะม่วงไหว) — รายละเอียดดูหัวข้อ 🌬️ ด้านล่าง
- `src/client/AmbienceController.client.luau`: บรรยากาศกลางคืนฝั่ง Client (สูตรแสงและหมอก Atmosphere Blueprint + เสียงจิ้งหรีดเหงาๆ + เสียงฝีเท้าหลอนแยกตามพื้นผิวไม้/ดินโคลน/หญ้า) — รายละเอียดดูหัวข้อ 🌙 ด้านล่าง
- `src/client/WeatherController.client.luau`: ระบบฝนตกฝั่ง Client แบ่งโซนปล่อยเม็ดฝน 4 ด้านรอบนอกเพิง (`RainZone_Front/Left/Right/Back`) คำนวณขอบเขต World-Space ของ `ShackStructure` เพื่อกันฝนตกทะลุหลังคาเพิงสังกะสี

### 🛠️ สรุปการปรับปรุงระบบเกมเพลย์ UI เสียง และบรรยากาศ (อัปเดตล่าสุด 2026-10-29)
1. **มุมมองและการเคลื่อนไหวผู้เล่น (`default.project.json`, `GameManager.server.luau`, `HUDController.client.luau`):**
   - บังคับมุมมองบุคคลที่ 1 (`CameraMode = Enum.CameraMode.LockFirstPerson`) และซ่อนเมาส์ตรงกลางจอเป็นค่าเริ่มต้น กด **`V`** หรือ **`LeftAlt`** เพื่อปลดล็อก/ล็อกเมาส์ชั่วคราว
   - ปิดระบบกระโดด (`HumanoidStateType.Jumping = false`, `JumpPower = 0`, `JumpHeight = 0`) และปรับความเร็วเดินให้ช้าลง (`WalkSpeed = 10`) เพื่อคุมจังหวะเกมสยองขวัญ
2. **ไฟฉายกบ 3D ล็อกตามกล้อง (`HUDController.client.luau`, `Flashlight.server.luau`):**
   - เมื่อถือ `FrogFlashlight` ไฟจะเปิดอัตโนมัติ ซ่อนโมเดลในมือขวาของตัวละคร แล้วสร้าง `CameraFlashlightViewmodel` ล็อกตามมุมกล้องขวา-ล่าง พร้อมไฟส่องทาง `CameraBeamLight` (`Brightness = 2.4, Range = 46, Angle = 60, Shadows = false`) และไฟส่องพื้นใกล้ตัว `CameraCloseLight`
   - ปิดแถบ Backpack มาตรฐานของ Roblox แล้วใช้ช่องสลับไอเทม `[1] ไฟฉาย` ของเกมแทน
3. **มินิเกมเติมน้ำมันและเติมลมยาง (`CoreLoop.luau`, `HUDController.client.luau`, `LanguageModule.luau`):**
   - เปลี่ยนจากการกดค้างที่ตู้ มาเป็นมินิเกมผ่าน `Remotes.ServiceMinigame`:
     - **เติมน้ำมัน (`FuelView`):** กดค้าง `Space` หรือคลิกเมาส์ซ้ายค้างเพื่อปั๊มน้ำมันให้หยุดในแถบเป้าหมายสีทอง แล้วปล่อยเพื่อส่งมอบ
     - **เติมลมยาง (`AirView`):** กด `Space` หรือคลิกเมาส์ซ้ายให้ตรงจังหวะที่เข็มวัดแรงดันวิ่งเข้าโซนสีทองครบ 3 ครั้ง
4. **ระบบคิวลูกค้าและบทสนทนาอัตโนมัติ (`CoreLoop.luau`, `HUDController.client.luau`):**
   - ตัดกล่องตัวเลือกตอบคำถามของผู้เล่น (`DialogueReply`) ออก ให้บทสนทนาไหลต่อเนื่องอัตโนมัติ
   - จำกัดคิวรถลูกค้า `MaxQueue = 1` และปิดการปล่อยรถมาพร้อมกัน 2 คัน เพื่อไม่ให้รถซ้อนหรือผู้เล่นสับสน
   - ปรับแถบคำพูดลูกค้าด้านล่างให้กะทัดรัด (`400 x 58`) และซ่อนข้อความ `"ร้านยังปิดอยู่..."` อัตโนมัติหลัง 5 วินาที
5. **ปรับปรุง HUD, ป้ายชื่อวัตถุ และศาลพระภูมิ (`HUDController.client.luau`, `PrayerController.client.luau`, `ObjectLabels.client.luau`, `BookController.client.luau`, `SettingsController.client.luau`):**
   - เอาแถบแสดงจำนวนธูป `🕯️🕯️🕯️` ออกจาก HUD มุมขวาล่าง เพื่อให้ผู้เล่นต้องเดินไปเช็กธูปที่ `Workspace.SpiritHouse` ด้วยตัวเอง
   - ซ่อนป้ายชื่อวัตถุลอย (`ZoneLabel`) ตอนเริ่มเล่นเป็นค่าเริ่มต้น, เอาปุ่มสมุดผีมุมขวาบนออก, และปรับแต่งปุ่มตั้งค่าใหม่
6. **วิทยุทรานซิสเตอร์ (`AnomalyManager.luau`):**
   - เริ่มเกมมาวิทยุจะปิดอยู่ กดปุ่ม **`R`** เมื่อยืนใกล้โต๊ะเพื่อเปิด/ปิดวิทยุ
   - เพิ่ม `EqualizerSoundEffect` (`LowGain = -20, MidGain = 8, HighGain = -10`) และ `DistortionSoundEffect` (`Level = 0.25`) ให้เสียงเพลงลูกทุ่ง (`RadioMusic`) และเสียงพระสวด (`MonkChant`) แหบพร่าเหมือนลำโพงวิทยุถ่านเก่าๆ พร้อมตั้งระยะได้ยิน 3D (`RollOffMinDistance = 5, RollOffMaxDistance = 35`)
7. **ป้องกันฝนตกทะลุหลังคาเพิง (`WeatherController.client.luau`):**
   - แยกแผ่นปล่อยเม็ดฝนเป็น 4 โซนรอบนอกเพิง (`RainZone_Front`, `RainZone_Left`, `RainZone_Right`, `RainZone_Back`) โดยคำนวณขอบเขต World-Space จริง (`PointToWorldSpace`) ของทุกชิ้นส่วนใน `ShackStructure` บวกระยะชายคา `3.5` studs และตั้งเม็ดฝนให้ตกดิ่งลงตรงๆ (`SpreadAngle = 0`, `Acceleration = 0`)
8. **จัดระเบียบดงกล้วยและเสาไฟหน้าร้าน (`MapBuilder.luau`, `GameManager.server.luau`):**
   - เพิ่ม `MapBuilder.SpreadBananaGrove()` กระจายต้นกล้วย 26 ต้นใน `BananaGrove` ให้เต็มพื้นที่ว่างด้านหลังและด้านข้างเพิง ไม่ให้กระจุกตัวแน่นเกินไป
   - คืนค่าแสงไฟเสาไม้หน้าร้าน (`DirtRoad.NeonLightPart.FlickerLight`, `Brightness = 2.2, Range = 52`) และปิด `CastShadow` ของตัวเสาและหลอดไฟไม่ให้บังแสงตัวเอง
9. **สูตรแสง หมอก และเสียงฝีเท้าหลอนชนบทไทย (`MapBuilder.luau`, `AmbienceController.client.luau`):**
   - ปรับค่า `Lighting` และ `Atmosphere` ให้ตรงกันทั้ง Edit mode และ Play mode ตามสูตร Atmosphere Blueprint (`Ambient = 12,16,22`, `OutdoorAmbient = 18,24,30`, `EnvironmentDiffuseScale = 0.2`, `EnvironmentSpecularScale = 0.25`, `Atmosphere.Color = 18,22,28`, `Decay = 10,12,15`, `Density = 0.42`, `Offset = 0.15`, `Glare = 0.1`, `Haze = 1.5`, และ `ColdNightGrade`: `Saturation = -0.25`, `Contrast = 0.20`, `TintColor = 235,245,235`)
   - เปลี่ยนเสียงเดินพลาสติกเดิมของ Roblox (`Running`) เป็นระบบเสียงฝีเท้าหลอนแยกตามพื้นผิว (`HorrorFootsteps` + `WoodFloorCreak`): เดินในเพิงเป็นเสียงย่ำพื้นไม้กระดานเก่าพร้อมสุ่มเสียงไม้ลั่น *"เอี๊ยดด.."*, เดินลุยโคลน/แอ่งน้ำ/ตอนฝนตกเป็นเสียงย่ำดินชื้นแฉะ, และเดินบนดิน/หญ้าเป็นเสียงย่ำดินลูกรังแห้งทุ้มต่ำ

### 🙏 ระบบพนมมือ (เพิ่มเมื่อ 2026-10-28) — ผีเห็นได้เฉพาะตอนพนมมือ
- **ปุ่ม:** กดค้าง **G** (คีย์บอร์ด) / **Y** (จอย) / ปุ่ม **🙏** บนจอมือถือ (`ContextActionService` ใน `src/client/PrayerController.client.luau`) ปล่อย = เลิก · แถบปุ่มคีย์ขวาล่างมี "G กดค้าง พนมมือ (เห็นผี)" (`HUDController`)
- **Server (`src/server/Prayer.luau`, require จาก `CoreLoop`):** `Remotes.Pray:FireServer(true/false)` → `player:SetAttribute("Praying", true)` + ท่าพนมมือ R15 (หมุน `C0` ของ `RightShoulder`/`LeftShoulder`/`RightElbow`/`LeftElbow` + ก้มคอ `Neck` ฝั่ง Server ทุกคนเห็น, ท่าเดิมจำไว้ใน attribute `RestC0` ของ Motor6D) + ยืนนิ่ง (WalkSpeed/Jump = 0) + เก็บไฟฉาย · `collapse()` (ผีหลอกล้ม/ตาย) เรียก `Prayer.Stop` ก่อนเสมอ · API: `Prayer.Duration(p)`, `StartedAt(p)`, `Praying()`, `PrayingNear(pos, r)`
- **ตาทิพย์ (Client):** พนมมือครบ 1.5 วิ (`SIGHT_DELAY`) → จอโทนเย็นซีด (`Lighting.PrayerSight`) + แถบ "👁 ตาทิพย์เปิดแล้ว" แล้วสลับ "ม่าน" ให้เฉพาะเครื่องตัวเอง:
  - tag **`GhostOnly`** = ของผี เห็นเฉพาะตอนตาทิพย์เปิด · tag **`NormalOnly`** = ของปกติที่ผีบังไว้ หายไปตอนตาทิพย์เปิด
  - attribute บนชิ้นนั้น: `VeilProp` (`Transparency` / `Enabled` / `Volume`), `VeilShow`, `VeilHide`, `VeilFade` (วินาที) · Server เก็บสถานะ "ไม่ได้พนมมือ" เสมอ (ผีล่องหน/เงียบ) Client ทับค่าเอง · Server เอา tag ออก = Client คืนค่าปกติ
  - helper ใน `AnomalyManager.luau`: `ghostOnly(root, showT?, useShowAttr?, fade?)`, `normalOnly(root)`, `unveil(root)`, `apparition(src, name)` (Clone ของในฉากเป็นร่างผีแยกชิ้น — ใช้เมื่อผีต้องย้าย/หมุนของ เพราะ Client ทับ CFrame ของ Server ไม่ได้)
  - ผีแต่ละตัว: คนซ้อนไร้หัว / ผมพันล้อ / หน้ายิ้ม = `GhostOnly` · ป้ายทะเบียน = `NormalPlate` NormalOnly + `GhostPlate` GhostOnly · คอหมุน = Clone หัว `TwistedHead` · กระสือ = ขา NormalOnly + ไส้/แสงแดง GhostOnly · วิทยุสวดศพ = เพลง NormalOnly + เสียงสวด/คลื่นแทรก GhostOnly (คนไม่พนมมือยังได้ยินเพลง) · ผีตานี = GhostOnly ค่อยๆ ปรากฏ 3 วิ · หุ่นไล่กา = Clone `AnomalyProps.ScarecrowApparition` ใกล้ร้าน + ตัวจริงกลางทุ่ง NormalOnly · น้ำมันเลือด = Clone `GasPump.BloodFuel` (`setFuelLevel` เลื่อนระดับตาม) · ไม่กางร่มกลางฝน = ร่ม NormalOnly
  - ⚠️ **ผีตัวใหม่ต้องใช้ helper พวกนี้** ห้ามตั้ง Transparency ให้เห็นตรงๆ ไม่งั้นทุกคนเห็นโดยไม่ต้องพนมมือ · จอผีหลอก (`JumpscareController`) โชว์ร่างจริงเสมอ (อ่าน `VeilShow`/`VeilHide` จากร่าง Clone)
- **ลูกค้าทักคนพนมมือ (`CoreLoop.watchPrayers`):** ระหว่างลูกค้าอยู่ที่ตู้ ถ้ามีคนพนมมือในระยะ 30 studs นาน ≥ 1.2 วิ ลูกค้าทัก (`Pray_Ask_1..4` เช่น "พนมมือทำไมน่ะ?" / "สวดมนต์อยู่เหรอ?" / "ขออะไรอยู่ล่ะนั่น?") → ผู้เล่นตอบ (`Pray_Reply_1..4`) → ลูกค้าพูดต่อ (`Pray_After_*`) · ลูกค้าผี 60% ตอบแบบผี (`Pray_Ghost_*` / `Pray_GhostAfter_*`) ที่เหลือแกล้งทำเป็นคน · สูงสุด 2 ครั้งต่อลูกค้า ไม่พูดทับตอนกำลังตอบราคา/ลูกค้ากำลังพูด (`speechBusyUntil`)
- **สวดตอนร้านว่างเรียกผี (`CoreLoop.prayerSummonLoop`):** ร้านเปิด ไม่มีลูกค้า ไม่มีขาจร พนมมือนาน ≥ 3 วิ → สุ่ม 35% (1 ครั้งต่อการพนมมือ 1 รอบ, คูลดาวน์ทั้งร้าน 60 วิ) เรียกผีตานี / หุ่นไล่กา / วิทยุสวดศพ มาอยู่ 15–22 วิ + เสียงกระซิบ `Pray_Summon_*` + 50% ลูกค้าคนถัดไปเป็นผีแน่นอน (`forceGhostNext`) · ค่าทั้งหมดอยู่ใน `CONFIG.Pray*`
- **จังหวะเกม (ปรับช้าลงพร้อมกัน):** `TargetMoney` 500 → 1500, `FirstWaveDelay` 4–8 → 10–16 วิ, พักระหว่างระลอก single 10–20 → 20–35 / quiet 35–55 → 45–70 / pair 20–35 → 30–45 / rush 30–45 → 40–60 (ฝน shelter 25–40 / single 35–50 / quiet 50–75), `InspectLock` 3 → 4, `DecisionTime` 25 → 35, `ImpatientAfter` 16/24 → 22/32 → ประมาณ 15–20 นาทีต่อคืน (ลูกค้าราว 16 คน)
- **จบเกมแล้วกลับ Lobby (2026-10-28):** แพ้ = ปุ่ม "🏯 กลับ Lobby" ในจอตาย (`DeathScreen`), ชนะ = ปุ่มเดียวกันใต้แถบประกาศ (`HUDController`, ขึ้นจนคืนใหม่เริ่ม — `CONFIG.RestartDelay` เพิ่มเป็น 20 วิ) → `DeathChoice:FireServer("quit")` → `CoreLoop.backToLobby()` เรียก `TeleportService:TeleportAsync(CONFIG.LobbyPlaceId = 70980777393906, { player })` ทีละคน · ใน Studio Teleport ไม่ได้ จึง Kick พร้อมข้อความลาแทน (ทดสอบ Teleport จริงต้อง Publish แล้วเล่นในเกมจริง) · Teleport พลาด (`TeleportInitFailed`) ก็ Kick แทน
- 💡 ต่อยอด: Lobby จะส่ง `difficulty` / `maxPlayers` มาใน TeleportData — ปรับ `TargetMoney` และเงินรางวัลตามความยากได้ที่ `CoreLoop.CONFIG`

### 🌙 ระบบบรรยากาศกลางคืนและเสียงฝีเท้า (`AmbienceController.client.luau`, อัปเดตเมื่อ 2026-10-29)
ทำฝั่ง Client ทั้งหมด (เสียง/หมอกเป็นของเฉพาะผู้เล่นแต่ละคน) สคริปต์จะรอจน Server สั่ง `SetNightLighting()` ให้ `Lighting.ClockTime` เป็นตอนกลางคืนก่อน แล้วตั้งค่าให้ตรงกับ Edit mode ตามสูตร Atmosphere Blueprint:
- **แสงและหมอกยามวิกาล (Atmosphere Blueprint):**
  - `Lighting`: `Ambient = Color3.fromRGB(12, 16, 22)`, `OutdoorAmbient = Color3.fromRGB(18, 24, 30)`, `EnvironmentDiffuseScale = 0.2`, `EnvironmentSpecularScale = 0.25`
  - `Lighting.RuralAtmosphere`: `Color = Color3.fromRGB(18, 22, 28)`, `Decay = Color3.fromRGB(10, 12, 15)`, `Density = 0.42`, `Offset = 0.15`, `Glare = 0.1`, `Haze = 1.5` และให้ `Density` ค่อยๆ หายใจระหว่าง `0.38–0.46` ทุก 10–18 วินาที
  - `Lighting.ColdNightGrade` (`ColorCorrectionEffect`): โทนสีหนังผีไทยยุค 90s (`Saturation = -0.25`, `Contrast = 0.20`, `TintColor = Color3.fromRGB(235, 245, 235)`)
  - หมอกเรี่ยพื้น: Part ล่องหน `GroundMistEmitter` (กว้าง 120×120, อยู่ที่ระดับ `Y = 2.5`) อยู่ใต้ `Workspace.CurrentCamera` และย้ายตามกล้องทุกเฟรม มี `ParticleEmitter` ใช้ texture `smoke_main.dds` (`LightInfluence = 0.25` + `Brightness = 0.6`)
- **เสียงฝีเท้าหลอนแยกตามพื้นผิว (`setupHorrorFootsteps`):**
  - ปิดเสียงเดินพลาสติกมาตรฐานของ Roblox (`Running.Volume = 0`) แล้วสร้าง `HorrorFootsteps` (`EqualizerSoundEffect` + `ReverbSoundEffect`) และ `WoodFloorCreak` บน `HumanoidRootPart`
  - ปรับโทนเสียงและการสะท้อนอัตโนมัติตามพื้นผิวที่เหยียบ: พื้นไม้กระดานในเพิง (พร้อมสุ่มเสียงไม้ลั่น *"เอี๊ยดด.."* ทุก 4–8 ก้าว), ดินโคลน/แอ่งน้ำ/ขณะฝนตก, และดินลูกรัง/หญ้าแห้ง
- **เสียงจิ้งหรีดเหงาๆ** (ทุกเสียงอยู่ใน `SoundService.Ambience` (`SoundGroup`) ที่ตัดเสียงทุ้มออก `LowGain -30` เพื่อลบเสียงรถไกลๆ ในไฟล์ต้นฉบับ + reverb กว้างๆ):
  - `CricketBed` (2D, `rbxassetid://9112764023`) จิ้งหรีดรอบตัวผู้เล่น เปิดเบาๆ
  - `EerieAir` (2D, `rbxassetid://9114244841`) เสียงลมหวิวเบามาก (volume 0.07) อยู่ใต้เสียงจิ้งหรีด
  - `GroveCrickets` (3D ที่ดงกล้วย `30,3,30`, `rbxassetid://9112764040`) และ `FieldCrickets` (3D ที่ทุ่งนาฝั่งตรงข้ามถนน `-20,3,-55`) ยิ่งเดินเข้าใกล้ยิ่งดัง
  - กลไกความเหงา: ทุก 45–110 วินาที จิ้งหรีดทุกตัวจะเงียบลงภายใน 2.5 วินาที (เหมือนมีอะไรเดินผ่าน) เงียบอยู่ 5–10 วินาที แล้วค่อยๆ ร้องกลับมาภายใน 8 วินาที
  - เสียงทั้งหมดเป็นของฟรีจาก Creator Store (ProSoundEffects)

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
