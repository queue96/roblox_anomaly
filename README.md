# ⛽ ปั๊มหลอด & เพิงปะยางท้ายทุ่ง (The Rural Tire & Gas Shack)
**Roblox Co-op Horror Anomaly Game (1–4 Players)**

![Map Overview Concept](assets/map_overview.jpg)

## 📌 ภาพรวมโปรเจกต์ (Project Summary)
- **แนวเกม:** Co-op Anomaly Observation / Job Simulator Horror (1–4 คน)
- **บรรยากาศ:** เพิงสังกะสีปั๊มน้ำมันหลอดแก้วและร้านปะยางริมถนนดินลูกรัง กลางทุ่งนาและดงกล้วยตานี
- **เป้าหมายการชนะ (Win Quota):** ให้บริการรถชาวบ้านจนเก็บเงินในกระป๋องครบ **500 บาท** (คันละ +100฿ / ปิดร้านหนีผีได้โบนัส +50฿)
- **พลังชีวิตทีม:** ธูปที่ศาลพระภูมิ **3 ดอก** (เผลอเติมน้ำมันให้ผี ธูปดับทีละ 1 ดอก ครบ 3 ดอก = Game Over)
- **การรองรับภาษา:** 2 ภาษา ไทย / อังกฤษ (`TH` / `EN` Localization)

---

## 📂 ไฟล์สำคัญในโปรเจกต์นี้
1. **[GEMINI.md](GEMINI.md)** — คู่มือส่งมอบงานสำหรับ AI (AI Context & Handoff Guide) อธิบายโครงสร้างโค้ด โฟลเดอร์ใน `Workspace`/`ServerStorage` และกฎการแก้ไขฉากแบบไม่ทำลายตำแหน่งที่จัดวางไว้
2. **[GDD.md](GDD.md)** — เอกสาร Game Design Document ฉบับเต็ม (กติกาการเล่น, แผนผังแมพโคกดินกลางทุ่งนา 4 ด้าน, จุดวางของเผื่ออัปเดต 6 จุด, และคลังไอเดียผี 30 รูปแบบ แบ่งเป็น 3 Tiers)
3. **[src/shared/MapBuilder.luau](src/shared/MapBuilder.luau)** — โมดูลสร้างฉาก ระบบจัดการโมเดลจาก Toolbox และฟังก์ชันอัปเดตเฉพาะจุด (`PaintTerrainRoad`, `AddSacredBanyanZone`, `AddSideRiceFields`, `SplitSideRiceFields`, `BuildCompactPerimeter`)
4. **[src/server/GameManager.server.luau](src/server/GameManager.server.luau)** — สคริปต์ควบคุมเกมฝั่ง Server (ระบบสลับแสงกลางคืนอัตโนมัติเมื่อกด Play, ไฟนีออนกะพริบ, เชือกดึงแผงสังกะสี `ShutterDoor`)
5. **[src/shared/LanguageModule.luau](src/shared/LanguageModule.luau)** & **[src/client/HUDController.client.luau](src/client/HUDController.client.luau)** — ระบบ 2 ภาษา (`TH`/`EN`) และหน้าจอ HUD แสดงเงิน `500฿` + ธูป 3 ดอก
6. **[src/client/AmbienceController.client.luau](src/client/AmbienceController.client.luau)** — บรรยากาศกลางคืนฝั่ง Client: เสียงจิ้งหรีดเหงาๆ ที่บางช่วงเงียบลงเอง + หมอกหนาวสีฟ้าซีดและหมอกเรี่ยพื้น
8. **[src/server/CoreLoop.luau](src/server/CoreLoop.luau)** — Phase 3 ลูปหลัก: รถลูกค้าขี่มาจอด, ล็อกปุ่ม 3 วิ, เติมน้ำมัน (กดค้าง 3 วิ) / ดึงแผงปิดร้าน (0.5 วิ), เงิน 500฿, ธูป 3 ดอก, ชนะ/แพ้ ค่าปรับเกมอยู่ใน `CONFIG` · ทดสอบได้ด้วย `ServerStorage.DevDecision:Fire("fuel" | "reject")`
9. **[src/server/AnomalyManager.luau](src/server/AnomalyManager.luau)** — Phase 4 ผี 10 ตัว (Headless, Cemetery 4444, WheelHair, NeckTwist, CreepySmile, Krasue, MonkRadio, Tani, Scarecrow, BloodFuel) แต่ละตัวมี apply/reset, `ResetAnomalies()` ตอนรถขี่ออก, หมาหอนในทุ่ง · บังคับผีตัวถัดไปด้วย `ServerStorage.DevDecision:SetAttribute("ForceAnomaly", "Anomaly_Krasue")` (หรือ `"Normal"`)
10. **[src/server/Flashlight.server.luau](src/server/Flashlight.server.luau)** — ไฟฉายกบ (StarterPack.FrogFlashlight) คลิกเปิด/ปิด SpotLight ฝั่ง Server
11. **[src/server/PlayerSettings.server.luau](src/server/PlayerSettings.server.luau)** — การตั้งค่าผู้เล่น (ภาษา ไทย/อังกฤษ, เสียงเพลง, เสียงเอฟเฟกต์, ซ่อน HUD, ซ่อนป้ายชื่อวัตถุ) เป็น Attribute บน Player จำไว้ใน DataStore · เข้าครั้งแรกจากประเทศไทย = ไทย นอกนั้น = อังกฤษ
12. **[src/client/SettingsController.client.luau](src/client/SettingsController.client.luau)** — ปุ่ม "ตั้งค่า" มุมขวาบน + หน้าต่างตั้งค่า (ปิดด้วย X) · แบ่งเสียงเป็น SoundGroup Music / SFX
13. **[src/client/ObjectLabels.client.luau](src/client/ObjectLabels.client.luau)** — ป้ายลอยตามวัตถุ (ZoneLabel) ฝั่ง Client: ชื่อสั้นตามภาษา ไม่มีพื้นหลัง เห็นเมื่อเข้าใกล้ ป้ายผีซ่อนตลอด
14. **[src/client/HUDController.client.luau](src/client/HUDController.client.luau)** — HUD สไตล์ชนบทหลอน: เงิน/ธูปขวาล่าง, ปุ่มคีย์แนวตั้ง, กล่องคำพูดลูกค้าแสดงชื่อ, แถบตอบราคา (ทุกคนเห็นเหมือนกัน ใครตอบก่อนได้ก่อน), แถบประกาศ · บทสนทนา (ทัก -> ถามราคา -> จ่ายเงิน/โวยวาย) และการเปิดร้านก่อนเริ่มคืนอยู่ใน CoreLoop · ทดสอบด้วย `DevDecision:Fire("open")` / `Fire("reply:100")`
15. **[src/server/Weather.luau](src/server/Weather.luau)** + **[src/client/WeatherController.client.luau](src/client/WeatherController.client.luau)** — ฝนตกเป็นช่วงๆ (เม็ดฝน เสียงฝน พื้นเปียก แอ่งน้ำ ฟ้าแลบ) ลูกค้ามาน้อยลง มีคนแวะหลบฝนชวนคุย · `DevDecision:Fire("rain" | "clear")`
16. **[src/server/Pedestrian.luau](src/server/Pedestrian.luau)** — ลูกค้าเดินเท้า (แกลลอน / เข็นจักรยาน / หลบฝน / ขบวนแห่) ท่าเดิน ท่าเต้น ร่มจาก `ServerStorage.ImportedProps.Umbrella` (Blender: tools/blender/umbrella.py)
17. **[src/client/JumpscareController.client.luau](src/client/JumpscareController.client.luau)** — ผีโผล่เต็มจอตอนเติมให้ผี เสียง/สีจอ/เอฟเฟกต์ตามชนิดผี · **[src/client/DeathScreen.client.luau](src/client/DeathScreen.client.luau)** — ธูปดับหมด ล้มนอนตาย จอแดง ถามเริ่มใหม่ (ใครกดก่อนได้ก่อน)
18. **CoreLoop (ลูกค้า + ขาจร)** — คิวลูกค้าเป็นระลอกแล้วพัก, เติมช้าลูกค้าไม่พอใจ, ทักทายตอบ, รถไทย (กระบะ/เก๋ง = ดีเซลตู้ 2, ตุ๊กตุ๊ก, จักรยานเติมลม) เติมผิดตู้ลูกค้าท้วง, ขาจรช่วงพัก (เด็กแว้น / รถซิ่งเปิดเพลง + สาวโคโยตี้ + วัยรุ่น / รถแห่งานบวช), ไล่ผีแล้ววิ่งตามโดนล้มตึง · `DevDecision:Fire("car" | "tuktuk" | "bicycle" | "walker" | "shelter" | "racer" | "party" | "parade" | "spawn" | "lose" | "restart")`
19. **รถไทย 8 คัน** — [src/shared/ThaiVehicleRigs.luau](src/shared/ThaiVehicleRigs.luau) + `MapBuilder.BuildThaiVehicleTemplates()` (CoreLoop สร้างให้เองตอนเริ่มถ้ายังไม่มี) · ขับเองได้ด้วย [src/server/ThaiVehicleDrive.server.luau](src/server/ThaiVehicleDrive.server.luau) · Blender: tools/blender/thai_vehicles.py
7. **[index.html](index.html)** & **[phases.html](phases.html)** — แดชบอร์ดจำลองการเล่นและเช็กลิสต์ติดตามความคืบหน้าทั้ง 5 เฟส

---

## 💻 วิธีสลับทำงานหรือให้ AI ตัวอื่นทำต่อ
เมื่อต้องการคุยงานต่อกับ AI ตัวใหม่ ให้พิมพ์คำสั่งนี้ในแชท:
> **"ช่วยอ่านไฟล์ `@[GEMINI.md]`, `@[GDD.md]` และ `@[src/shared/MapBuilder.luau]` ในโฟลเดอร์นี้ เรากำลังพัฒนาเกม Roblox ปั๊มหลอดท้ายทุ่ง ตอนนี้ Phase 1 (ปั้นฉาก), Phase 2 (รถแม่แบบใน ServerStorage.VehicleTemplates) Phase 3 (Core Loop ใน src/server/CoreLoop.luau) Phase 4 (ผี 10 ตัวใน src/server/AnomalyManager.luau + ไฟฉาย) เสร็จแล้ว และ Phase 5 ทำ HUD + ระบบภาษาแล้ว (เหลือสมุดสะสมผี + Publish) พร้อมระบบเพิ่มเติม: ฝนตก, ลูกค้าเดิน/รถไทย, ขาจร, ผีหลอกเต็มจอ, จอตาย, ตั้งค่า กำลังจะทำต่อในส่วน..."**