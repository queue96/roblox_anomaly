# ท่า mocap ที่ต้อง publish ทับ ID เดิม (2026-11-08)

ใน Studio: `ServerStorage.HumanAnimsMocap.<ตัวละคร>.<ท่า>` คลิกขวา → Save to Roblox → เลือก **Overwrite** asset ID ตามตาราง

คนขับรถมีแค่ human_base (ตัวอื่นไม่มีท่านั่ง) -> ทับ 13 ท่า

| ตัวละคร | ท่า | ID เดิม (ทับอันนี้) |
|---|---|---|
| human_base | idle | 103800868829848 |
| human_base | walk | 132822592476604 |
| human_base | ride_moto | 132408927006595 |
| human_base | drive_car | 129503151043569 |
| human_base | drive_tuktuk | 134908139865752 |
| human_female | idle | 129369161172079 |
| human_female | walk | 103773582554712 |
| human_child | idle | 77739143578548 |
| human_child | walk | 77258023396732 |
| human_elder_male | idle | 132619334853140 |
| human_elder_male | walk | 133206909891901 |
| human_elder_female | idle | 138025499029648 |
| human_elder_female | walk | 83871222558672 |

ท่าใหม่ (ยังไม่มี ID: publish เป็น asset ใหม่แล้วส่ง ID มา ทำทีหลังได้):
`idle_weight` `idle_look` `idle_bored` `idle_old` (คนแก่) `talk` `talk_2` `wave` `shrug` `nod_yes` `shake_no`
