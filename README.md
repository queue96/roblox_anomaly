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
6. **[index.html](index.html)** & **[phases.html](phases.html)** — แดชบอร์ดจำลองการเล่นและเช็กลิสต์ติดตามความคืบหน้าทั้ง 5 เฟส

---

## 💻 วิธีสลับทำงานหรือให้ AI ตัวอื่นทำต่อ
เมื่อต้องการคุยงานต่อกับ AI ตัวใหม่ ให้พิมพ์คำสั่งนี้ในแชท:
> **"ช่วยอ่านไฟล์ `@[GEMINI.md]`, `@[GDD.md]` และ `@[src/shared/MapBuilder.luau]` ในโฟลเดอร์นี้ เรากำลังพัฒนาเกม Roblox ปั๊มหลอดท้ายทุ่ง ตอนนี้ปั้นฉาก Phase 1 เสร็จแล้ว กำลังจะทำต่อในส่วน..."**