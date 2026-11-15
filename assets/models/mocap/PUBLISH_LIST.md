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

## เดินนุ่งผ้าซิ่น / โสร่ง mocap (2026-11-15)

`tools/blender/mocap_retarget.py -- --preview walk_skirt` (ท่าเดิน mocap ย่อการก้าวให้สั้นเท่าท่าเดิม ตัวบน/แขนตาม mocap)
สร้างแล้วใน `ServerStorage.HumanAnimsMocap.<ตัวละคร>.walk_skirt` -> Save to Roblox -> **Overwrite** ID เดิม (โค้ดไม่ต้องแก้ ID)

| ตัวละคร | ท่า | ID เดิม (ทับอันนี้) |
|---|---|---|
| human_base | walk_skirt | 137905220707032 |
| human_female | walk_skirt | 92833643435640 |
| human_child | walk_skirt | 120210620976113 |

## รอบ 2 (2026-11-15): วิ่งนุ่งผ้าถุง + ปั่นจักรยาน

`mocap_retarget.py -- --preview run_skirt ride_bicycle` (human_base) / `run_skirt` (human_female, human_child)
สร้างแล้วใน `ServerStorage.HumanAnimsMocap.<ตัวละคร>.<ท่า>` -> Save to Roblox -> **Overwrite** ID เดิม

| ตัวละคร | ท่า | ID เดิม (ทับอันนี้) |
|---|---|---|
| human_base | run_skirt | 128117301146048 |
| human_female | run_skirt | 108147959293862 |
| human_child | run_skirt | 114646258071509 |
| human_base | ride_bicycle | 135362256541891 |

กุมารทอง `kuman_giggle` / `kuman_run` เป็นท่า mocap ใน `src/shared/GhostClipData.luau` (ghost_mocap_retarget.py) ไม่ต้อง publish

> **แก้ (2026-11-15):** ทับ ID เดิมไม่ได้ (ID เก่าเป็นของอีกบัญชี) — publish เป็น asset ใหม่จาก `ServerStorage.PublishSkirtBike`
> (`<ตัวละคร>_<ท่า>_mocap` 7 ตัว) แล้วใส่ ID ใหม่ใน `src/shared/HumanAnimIds.luau` ตาราง 2 ชุดข้างบนจึงเป็นแค่ ID เก่าที่ถูกแทน
