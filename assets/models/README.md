# Props ที่ปั้นด้วย Blender MCP (ตาม docs/blender_prop_prompts.md)

ไฟล์ต้นฉบับ Blender: `pump_props.blend` (มี Collection แยกตามชื่อ prop + `ConceptLayout` สำหรับภาพเทียบ concept)
ภาพตัวอย่างทุกชิ้น: `previews/<ชื่อ prop>.png`  ภาพเทียบ concept กลางคืน: `previews/ConceptCompare.png`

ทุก prop มี `<ชื่อ>.fbx` + texture 1024 ชุดเดียว: `_Color.png`, `_Normal.png`, `_Roughness.png`, `_Metalness.png`
หน่วยเป็นเมตร (1 stud = 0.28 m), export: Selected, Apply Transform, Forward -Z, Up Y; ด้านหน้าของ prop หันไปทาง -Y ใน Blender

| Prop | Object ที่แยกไว้ (pivot) |
|---|---|
| GasPump | GasPump, GlassTube, FuelLiquid (ก้นกระบอก), HandCrank (แกนหมุน), Nozzle (ด้ามจับ) |
| AirCompressor | AirCompressor, PressureGauge_Needle (กลางหน้าปัด), ReliefValve (แกนวาล์ว) |
| TireStack | TireStack_4, TireLeaning, TireWithRim |
| ShackSigns | MainSignBoard (material `SignFace`), NeonSignFrame (material `NeonFace` สำหรับ SurfaceGui) |
| ShackPorchKit | PorchDeck, PorchSteps, WoodenPillar |
| CorrugatedPanels | TinWallPanel, TinWallPanel_Bent, TinWallPanel_Torn, TinRoofPanel, ShutterDoor (ขอบบน), RejectRope (จุดผูกด้านบน) |
| ShackLight | ShackLight (จุดยึดด้านบน), ShackLight_Neon |
| FuelDrum | FuelDrum (น้ำเงิน), FuelDrum_Red |
| ToolsOnGround | Wrench, TireIron, TireLever, PatchKitTin, BucketWater (ไม่เกิน 1,500 tris ต่อชิ้น) |
| TvAntennaAndPoles | TvAntenna, WoodenPole, WoodenPole_Neon, ConcretePole |
| SpiritHouseOnStilts | SpiritHouseOnStilts, Incense1-3, Incense1-3_Neon |
| ShackInteriorProps | CounterTable, MoneyTin(+_Lid), CutoutSwitch(+_Lever บานพับ), OldMirror(+_Glass), OwnerPhoto(+_Image), WallCalendar(+_Page), IceBox(+_Lid บานพับ, เปิดอยู่ 105°), SodaCrate, CompendiumBook |
| Generator | Generator, PullStartHandle, Generator_Neon |
| TinOuthouse | TinOuthouse, TinOuthouse_Door (บานพับ), TinOuthouse_Latch, DragonJar, WaterDipper |
| SacredBanyanProps | SacredThaiRibbons (วงใน Ø6 studs), BrokenOfferings, OldMarbleBenchSet |
| RoadsideProps | KilometerMilestone (material `MilestoneFace`), DistantRiceHut |
| ShackShelf | ShackShelf (ชั้นไม้ 4 ชั้น มีขวด กระป๋อง โหล ปี๊บน้ำมัน กล่อง รวมเป็นชิ้นเดียว) |
| ShackSeats | WoodenStool, WoodenBench |
| WelcomeSign | WelcomeSign (ป้ายไม้สีเข้ม "เชิญแวะ" ป้ายเปล่า หน้าป้ายเป็น material `WelcomeFace` สำหรับ SurfaceGui มีลวดแขวน) |
| WoodPlankWalls | WoodPlankWallPanel, WoodPlankWallPanel_Broken (ขนาด 6 x 10 เท่ากับ TinWallPanel) |
| HangingCoils | HangingHoseCoil, HangingTire (origin อยู่ที่ตะขอแขวน) |
| PowerLines | PowerLine_40, PowerLine_60 (4 เส้น ระยะตามคานเสาคอนกรีต), PowerLine_Wood_30 (ตามคานเสาไม้), ServiceDrop (สายเส้นเดียวจากเสาลงเพิง ยาว 18 ตก 9 studs) — origin อยู่กลางคานต้นทาง สายวิ่งไปทาง +Y |
| SacredBanyanTree | BanyanTrunk (ลำต้นเอนและคด โคนบาน เอวคอด บวมตรงจุดแยก เส้นรากเล็กใหญ่บิดเกลียว แตกเป็น 3 ลำย่อยขนาดต่างกัน), BanyanRoots, BanyanLimbs, BanyanTwigs, BanyanAerialRoots (รากห้อยเส้นเล็ก + รากที่ถึงพื้น 4 จุด เป็นรากเส้นเล็ก 1–2 เส้นบิดพันกัน), SacredThaiRibbons — **มีเฉพาะกิ่งก้าน ไม่มีใบ** (ใบทำใน Studio ดูหัวข้อด้านล่าง) |
| CustomerBike | CustomerBike, FrontWheel/RearWheel (ดุมล้อ), Handlebar (คอ), Headlight_Neon, Taillight_Neon, LicensePlate, empty Seat_Driver/Seat_Passenger |
| Saleng | เหมือน CustomerBike + SidecarWheel, OldCoffin, OldCoffin_Lid (ในไฟล์ FBX ชื่อไม่มี .001) |

ทุก object ไม่เกิน 10,000 triangles (CustomerBike รวม 5,946 / Saleng รวมไม่นับโลง 7,258)

## แก้แล้ว (รอบ 2)
1. ศาลพระภูมิ: ขยายตัวศาล (แท่นรอง ตัวเรือน หลังคา พวงมาลัย) 1.4 เท่า ขนาดแท่นและเสา 6 studs คงเดิม ย้ายของไหว้ไปวางแถวหน้าระเบียง และวางกระถางธูปบนแท่นรอง
2. ตู้ปั๊ม: ลดความสูงตัวตู้ลง 0.4 studs (กระบอกแก้วยังสูง 2.8 ตามสเปก จึงดูสูงเด่นกว่าตู้) ป้ายหน้าตู้ขยายเป็น 1.95 x 2.3 studs ความสูงรวมเหลือประมาณ 7.6 studs
3. สนิม: ปรับสีให้ออกน้ำตาลหม่นขึ้น และเพิ่มคราบน้ำมันเข้มที่ขอบล่างของทุกชิ้นที่มีโคลน (bake texture ใหม่ทุก prop)
4. CorrugatedPanels: เพิ่ม `TinWallPanel_Bent` (ปลายบนงอออก บิดเล็กน้อย) และ `TinWallPanel_Torn` (มุมบนฉีกเป็นรอยหยัก ขอบล่างผุ) ในฉากเทียบ concept ใช้สลับกันและเอียงคนละนิด
5. เถียงนา: เพิ่มแถบหญ้าคาห้อยตามชายคาทั้งสองด้าน (เพิ่มเติมจากหลังคาที่เป็นรูโหว่)

## รอบ 3
- GasPump: ย้ายเสา 4 ต้นเข้าด้านในให้ต่อกับวงแหวนใต้ฝาและฐานล่าง
- CustomerBike / Saleng: ปั้นตัวรถใหม่ทั้งคันตามสัดส่วน Honda C70 (ยาว ~6.5 studs, ระยะล้อ 4.2, ล้อ Ø2.06, เบาะสูง ~2.75)
  โครงต่อกันเป็นชิ้นเดียวตั้งแต่คอรถ ท่อนหลังแบบเหล็กปั๊ม ตัวถังท้าย ไปจนถึงบังโคลนหลัง, บังลมหน้าเป็นเปลือกแคบตาม concept (กว้าง 1.2 → 0.72 studs) ผนังข้างตรงไปด้านหลัง มีขอบยางดำและรูวงรีด้านข้าง, หน้ากากไฟหน้าสีครีม, บังโคลนหน้าคลุมช่วงบนค่อนไปทางหลังของล้อ
  ส่วน Handlebar (คอ) รวมโช้คหน้า บังโคลนหน้า แฮนด์ กระจก และตะกร้า; ล้อพ่วงข้างของ Saleng มีขาจับทั้งสองข้าง

## รอบ 4 — ของจาก concept ที่ไม่อยู่ในไฟล์ prompt
เพิ่ม ShackShelf, ShackSeats, WelcomeSign, WoodPlankWalls, HangingCoils, PowerLines และ SacredBanyanTree (ต้นไทรพร้อมผ้าสามสี)
ส่วนนาข้าว แอ่งน้ำ หญ้า ควันธูป ต้นกล้วย และหุ่นไล่กา มีอยู่แล้วใน Studio / MapBuilder จึงไม่ได้ปั้น

## จุดที่ยังต่างจาก concept (ยังไม่ได้แก้)
6. โอ่งมังกร: ลายมังกรนูนยังเป็นเพียงเส้นพัน → ถ้าต้องการรายละเอียดควรใช้ normal map จากภาพลายมังกรจริง

## ใบต้นไทร (ทำใน Roblox Studio)
โมเดล `SacredBanyanTree.fbx` มีแค่ลำต้น กิ่ง ราก และผ้า ส่วนใบให้ทำใน Studio:
- **พุ่มใบ:** วาง Part/MeshPart เป็นกลุ่มใบตามจุดใน `SacredBanyanTree_LeafAnchors.json` (58 จุด มีตำแหน่ง x, y, z เป็น studs แกนแบบ Roblox เทียบกับฐานลำต้น และ `radius` ขนาดกลุ่มใบ) ใช้ MaterialVariant ใบไม้ หรือ foliage จาก Toolbox
- **ทางเลือก leaf card:** `SacredBanyanTree_LeafCard.png` คือภาพกลุ่มใบไทรพื้นหลังโปร่งใส ใช้ทำแผ่นใบไขว้ (SurfaceAppearance ColorMap + `AlphaMode = Transparency`)
- **ใบร่วง/บรรยากาศ:** ใช้ ParticleEmitter (ใช้ทำพุ่มใบทั้งพุ่มไม่ได้ จะดูเหมือนหิมะและกินเครื่อง)

## สลับเข้าฉากใน Studio แล้ว
- ฟังก์ชัน `MapBuilder.SwapGasPumpModel()` และ `MapBuilder.SwapImportedProps()` ใน `src/shared/MapBuilder.luau` (รันแล้ว ระบบจะข้ามถ้ารันซ้ำ เพราะมี attribute `ImportedPropsSwapped` ที่ Workspace)
- ต้นแบบที่นำเข้าอยู่ `ServerStorage.ImportedProps` ของเดิมทุกชิ้นอยู่ `ServerStorage.ArchivedPlaceholders` (ไม่ได้ลบ)
- ชื่อที่สคริปต์ใช้คงไว้: `InteractiveProps.ShutterDoor` (+OpenY/ClosedY), `RejectRope` (+RejectCustomerPrompt), `DirtRoad.NeonLightPart` (+FlickerLight), `SpiritHouse.Incense1-3`
- ไม่ได้วาง: `CustomerBike`, `Saleng` (ยังอยู่ใน `Workspace.NewModels` ที่จุด 0,0,0), `NeonSignFrame` (เอาออกเพราะสว่างเกินไม่หลอน), `PowerLine_60`, `PowerLine_Wood_30`, `ServiceDrop`

## ใบต้นไทร (ทำแล้วใน Studio)
- `MapBuilder.AddBanyanLeaves()` / `RebuildBanyanLeaves()` วางพุ่มใบแบบแผ่นใบไขว้ (Decal รูป `SacredBanyanTree_LeafCard.png` = `rbxassetid://71802157290225`) ตามจุดใน `SacredBanyanTree_LeafAnchors.json` (58 จุดหลัก + พุ่มย่อยจุดละ 2 = 174 พุ่ม)
- ใบอยู่ใน `MapEnvironment.SacredBanyanZone.SacredBanyanTree.BanyanLeaves` ไม่มี collision ปรับสีด้วยค่า `BANYAN_LEAF_TINT`
- `MapBuilder.HideBanyanShadowBehindTree()` ย้ายเงาคนแอบไปชิดลำต้นฝั่งที่มองไม่เห็นจากถนน

## ชุดโมเดลเพิ่ม (สไตล์ไทยบ้าน) — ยังไม่ได้นำเข้า Studio
| ไฟล์ | Object (pivot) | หมายเหตุ |
|---|---|---|
| MarbleTableSet.fbx | MarbleTable, MarbleBench1-4 | หินขัด (terrazzo) ฝังเศษหินอ่อนชมพู-ขาว ม้านั่งโค้ง 4 ตัว ตาม ref |
| KilometerPost.fbx | KilometerPost | หลักกิโลกรมทางหลวง สีขาวบนฐานปูนเทกลม หน้าตัวเลขเป็น material `KmFace` (ด้านหน้า + ด้านขวา) ใส่ SurfaceGui |
| DragonJar.fbx | DragonJar, DragonJar_Water | โอ่งราชบุรีทรงอวบ เคลือบน้ำตาล เส้นเหลืองบน-ล่าง ไม่มีลายมังกรตามที่ขอ |
| Scarecrow.fbx | Scarecrow, Scarecrow_EyeL_Neon, Scarecrow_EyeR_Neon | ผ้ากระสอบขาด หัวกระสอบเย็บปาก หมวกฟางเยิน เสาเอียง ตาเป็นจุดแดงเล็กในเบ้ามืด (Neon สำหรับ anomaly) ไม่มีกา |
| SquatToilet.fbx | SquatToilet, SquatToilet_Water | ส้วมนั่งยองเซรามิกน้ำเงินชิ้นเดียว ปีกเหยียบลายเพชร บนแผ่นปูน 3.4×3.4 (พอดีห้องน้ำสังกะสี) พร้อมอ่างน้ำปูน (ไม่มีขัน) |
| HandLights.fbx | Flashlight (+Flashlight_Neon เลนส์), StormLantern (+StormLantern_Glass, StormLantern_Neon เปลวไฟ) | ไฟฉายถ่าน 2 ก้อนตัวแดงหัวโครเมียม (นอนตามแกน +Y), ตะเกียงพายุสนิมแดงพร้อมโป๊ะแก้วและหูหิ้ว |

### วางเข้าฉากแล้ว (`MapBuilder.SwapThaiProps()`)
- MarbleTableSet แทน `SacredBanyanZone.OldMarbleBenchSet` (ป้ายชื่อย้ายตาม)
- KilometerPost แทน `DirtRoad.KilometerMilestone` (คงชื่อเดิม)
- DragonJar แทนโอ่งเดิมหน้าห้องน้ำ (ขันยกขึ้นลอยบนน้ำ) · SquatToilet วางในห้องน้ำสังกะสี
- Scarecrow แทน mesh `ScareCrow` ใน `AnomalyProps.Scarecrow` (Model/Part ป้ายชื่อ/ParticleEmitter เดิมคงไว้, ตาเป็น Neon แดง)
- StormLantern วางบนโต๊ะร้าน ยังไม่จุด (`StormLantern_Neon.Transparency = 1`, ตั้งเป็น 0 เพื่อจุดใน event)
- Flashlight เชื่อม (WeldConstraint) กับ `StarterPack.FrogFlashlight.Handle` ชิ้นเดิมซ่อนไว้ SpotLight/สคริปต์เดิมไม่แตะ

## ชุดพืชไทย — ยังไม่ได้นำเข้า Studio
| ไฟล์ | Object | หมายเหตุ |
|---|---|---|
| BananaClump.fbx | BananaClump, BananaClump_B, BananaClump_Base | กอกล้วย 6 ต้น สูง 2.5–9.5 studs ใบใหญ่ฉีกเป็นริ้ว ลำต้นมีกาบแห้งลอก โคนมีเนินดิน หน่ออ่อน กาบแห้งร่วง |
| BananaBunch.fbx | BananaBunch | เครือกล้วย 8 หวี origin ที่จุดต่อกับยอดลำต้น (เอาไปติดกับยอดกล้วยบางกอ) |
| ThaiGrasses.fbx | LemongrassClump, WildGrassClump, RiceSeedling, RicePaddyPatch | กอตะไคร้ (โคนเป็นต้นแดงๆ ไม่ใช่ก้อน), กอหญ้าดอกฟู, ต้นข้าวเพิ่งดำ 1 กอ และแถว 3 กอระยะ 1.1 stud สำหรับ copy เรียงในนา |
| MangoTree.fbx | MangoTrunk, MangoTwigs | ต้นมะม่วงใหญ่ (กิ่งก้าน) สูงราว 22 studs พุ่มกว้าง 24 · ใบเป็นแผ่นใบไขว้: `MapBuilder.AddMangoLeaves(model)` ใช้รูป `MangoTree_LeafCard.png` (`rbxassetid://126910157062464`) ตามจุด `MangoTree_LeafAnchors.json` |
| BananaBlossom.fbx | BananaBlossom | หัวปลีกล้วยตาม ref: กาบซ้อนเป็นชั้น 9 ชั้นสีม่วงหม่น กาบนอกเผยอ 1 กาบ (ด้านในแดง) ก้านเขียว origin ที่ปลายก้านด้านบน (ติดใต้เครือกล้วยหรือห้อยจากยอดต้น) |

### วางพืชเข้าฉากแล้ว (`MapBuilder.SwapThaiPlants()`) — แทนของเดิมเท่านั้น
- ต้นกล้วย 26 ต้นใน `BananaGrove` → BananaClump ขนาดตามความสูงเดิม (ชื่อเดิม), ทุก 3 กอห้อยเครือกล้วย + หัวปลี
- กอข้าว `RiceGrass_*` ทั้งหมด (RiceField, BackRiceField, Left/RightRiceField ทั้งใน MapEnvironment และ NewModels รวม 316 จุด) → แถวต้นข้าวเพิ่งดำ 3 กอ
- กอหญ้าริมถนน 22 กอ → WildGrassClump ขนาดตามของเดิม
- ยังไม่ได้วาง: MangoTree, LemongrassClump (ไม่มีของเดิมให้แทน) ต้นแบบอยู่ใน `ServerStorage.ImportedProps`
- เพิ่มเติม: นารอบนอก 6 แปลง (372 จุด) → แถวต้นข้าว · OuterTreeLine.BorderGrass 76 กอ → สลับหญ้าดอกฟู/ตะไคร้ · BorderTree 152 ต้น → ทุก 6 ต้นเป็นมะม่วง 1 (ใบเบา) + กอกล้วย 1 ที่เหลือคงเดิม
- `MapBuilder.AddBundClumps()` กอตะไคร้/หญ้าตามคันนา 168 กอ (เฉพาะ 4 แปลงในเขตเล่น)
- `MapBuilder.AddMountainTrees()` ต้นมะม่วงใบเบาบนภูเขาด้านข้าง 45 ต้น
- ลมพัดหญ้า: `src/client/GrassWind.client.luau` แกว่ง Model ที่มี tag `WindSway` ไปทิศเดียวกัน (มีคลื่นลมวิ่งผ่าน) และเอนหลบเมื่อตัวละครเดินชน ปรับทิศ/แรงที่ค่าคงที่ต้นไฟล์ · ติด tag ด้วย `MapBuilder.TagWindPlants()`
- ต้นข้าวเต็มแปลง: `RiceTile.fbx` (16 กอ 6.4×6.4 studs) + `MapBuilder.FillRicePaddies()` ปูแล้ว 213 แผ่นใน 4 แปลงเขตเล่น (`<แปลง>.RiceTiles`)

## Phase 2 — รถลูกค้าแม่แบบ (`MapBuilder.BuildVehicleTemplates()`)
`ServerStorage.VehicleTemplates` มี `CustomerBike` และ `Saleng` (ตาม phases.html)
- `Chassis` = PrimaryPart (ล่องหน, pivot ที่พื้นใต้รถ) สั่ง `PivotTo()` เลื่อนทั้งคัน · ทุกชิ้น Anchored, CanCollide ปิด
- `Headlight` (+SpotLight `HeadlightBeam`), `Taillight`
- `LicensePlate`: SurfaceGui `NormalPlate` (1กข 4512 ราชบุรี) / `GhostPlate` (4444 ป่าช้า CEMETERY, Enabled=false)
- `WheelHairAnomaly` ผมพันล้อหลัง (ซ่อน)
- `DriverNPC`: `Torso`, `Head` (`FaceNormal` + `CreepyFace` ซ่อน), `LeftArm`, `RightArm`, `Legs` (Model เดียว ซ่อนทั้งท่อนล่างได้)
- `GhostPassenger` ผีไร้หัวชุดไทยซ้อนท้าย (ซ่อน)
- ชิ้นที่ซ่อนทุกชิ้นมี attribute `ShowTransparency` = ค่าความโปร่งใสตอนแสดง (ใช้ในเฟส 4)
- `MapBuilder.RebuildVehicleRiders()` สร้างคนขับ/ผีใหม่โดยไม่แตะชิ้นอื่น

## ชุดวัดไทยชนบท (สำหรับ Lobby) — ยังไม่ได้นำเข้า Studio
ปั้นด้วยสคริปต์ `tools/blender/thai_temple.py` (ไม่ได้อยู่ใน `pump_props.blend` แต่อยู่ใน `thai_temple.blend`) ทุกไฟล์มี texture atlas 1024 ชุดละ 4 ไฟล์
ภาพรวม: `previews/ThaiTemple_Sheet.png` · ตอนกลางคืนจัดวางแบบ Lobby: `previews/ThaiTemple_Night_*.png`
กล่องชน + ขอบเขตแต่ละชิ้น (studs, แกน Blender): `ThaiTemple_Colliders.json`

| ไฟล์ | Object | หมายเหตุ |
|---|---|---|
| TempleGate.fbx | TempleGate, TempleGate_Buddha, TempleNameSign, TempleNameSign_Plaque | ซุ้มจั่วหน้าบันน้ำเงินขอบแดงลายทอง ช่อฟ้า ใบระกา หางหงส์ พระในซุ้มจระนำทั้ง 2 ด้าน ช่องประตู 14×17 studs · ป้ายชื่อวัดเป็นกำแพงปูนแยกชิ้น แผ่นป้ายเปล่า (SurfaceGui) |
| TempleFence.fbx | FenceSegment (12), FenceSegment_Half (6), FencePost | กำแพงปูนชมพูหม่น ลายฝักเพกาทอง หัวเสาลูกแก้วทอง origin = เสาต้นทาง กำแพงยาวไป +X และมีเสาที่ปลาย |
| BoneStupa.fbx | BoneStupa_A, BoneStupa_B, BoneStupa_C | ธาตุสีขาวทรงเหลี่ยมซ้อนชั้น (A สูง 13.8, C ย่อ 0.72 สีเก่า) / ทรงระฆัง (B) มีกรอบรูปผู้ตายสีซีเปียด้านหน้า |
| Meru.fbx | Meru_Base, Meru_Hall, Meru_Roof, Meru_Chimney | ฐานสูง 5.2 บันได 7 ขั้นมีราว หลังคาแดงซ้อน 2 ชั้น หน้าบันทอง ห้องเผาประตูเหล็ก ปล่องไฟสูง 56 |
| Ubosot.fbx | Ubosot_Base, _Walls, _Columns, _Roof, _KaewWall | หลังคาส้ม/แดงซ้อน 3 ตับ ขอบเขียว ปีกนกข้าง ช่อฟ้า 4 ตัว หน้าบันทอง เสาขาว ซุ้มหน้าต่างทอง ประตูเปิดเดินเข้าได้ · กำแพงแก้ว + ใบเสมา 8 ทิศ |
| Kuti.fbx | Kuti_Stilts, Kuti_House, Kuti_Roof | เรือนไม้ใต้ถุนสูง 10.2 ระเบียงลูกกรงไม้ บันไดไม้ 12 ขั้น หลังคากระเบื้องน้ำตาล กาแลหน้า-หลัง |
| Sala.fbx | Sala_Base, Sala_Columns, Sala_Roof | ศาลาโล่ง 46×35 หลังคาสังกะสีเขียวปั้นหยา+จั่ว หน้าจั่วขาวบานเกล็ด เสาไม้แดงโคนขาว แท่นตั้งพระด้านหลัง |
| BuddhaTrio.fbx | BuddhaTrio_Base, BuddhaTrio_Plaques, Buddha_Center, Buddha_Left, Buddha_Right | พระปางมารวิชัยสีทอง (กลางสูง ~5, ข้าง 0.74 เท่า) บนฐานชุกชีลายกระจก กลีบบัวทอง แผ่นชื่อพระสีแดง 3 แผ่น (SurfaceGui) |
| DonationBoard.fbx | DonationBoard, DonationBoard_Board, DonationBoard_Face | ป้ายบริจาคแบบป้ายวัด เสาไม้แดงสูง 26 คานยาว 31 แผ่นป้ายไม้ 24×19.5 ห้อยโซ่ ขอบล่างสูงจากพื้น 2.5 หน้าป้ายเปล่าทั้ง 2 ด้าน (SurfaceGui ทำ dashboard) |
| DonationBox.fbx | DonationBox_Stand, DonationBox, DonationBox_Door, DonationBox_Glass | ตู้ไม้สักเสากลึงเกลียว ขาลูกบิด บานกระจก กลอนทองเหลือง มีธนบัตร/เหรียญข้างใน ช่องหยอดเงินบนหลังตู้ ตั้งบนแท่นกลึง สูงรวม 7.8 · Glass ตั้ง Transparency ใน Studio |
| ShopCart.fbx | ShopCart, ShopCart_Goods, ShopCart_Canopy, ShopCart_Sign | รถเข็นขายทุกอย่าง 16×8 สูง 13 ล้อจักรยาน 2 ล้อ ชั้นขั้นบันได 4 ชั้น ขวด/โหล/ซองขนม ตะกร้า ของห้อย ผ้าใบลายทางน้ำเงิน-เหลือง-แดง-ขาว ป้ายหน้าเปล่า |

ขยายจากขนาดตอนปั้น: Ubosot ×1.3, Meru ×1.15 (เสาสูงขึ้น 3), Kuti ×1.5 (ประตู/บันไดกว้างขึ้น), Sala ×1.15 (เสาห่าง 9) เพื่อให้ 4 คนเดินสวนกันได้ — ประตูโบสถ์ 9.4×11.4, ประตูกุฏิ 8.1×10.5
ทุก object ไม่เกิน 10,000 triangles (พระองค์ละ ~7,400 / TempleGate_Buddha 2 องค์รวม ~8,100)
วางฉาก: `MapBuilder.BuildTempleLobby()` (ดู GEMINI.md หัวข้อ 🛕) — ยังไม่ได้รัน

## รถและจักรยานสไตล์ไทย 8 คัน (`tools/blender/thai_vehicles.py`)
ไฟล์ต้นฉบับ: `thai_vehicles.blend` · ภาพตัวอย่าง: `previews/<ชื่อ>.png` + `_side.png` (หุ่นสีขาว = ตัวละคร R15 สูง 5.2 studs ไม่ได้ export)
ข้อมูลที่นั่ง/ล้อ/ไฟ/กล่องชน: `ThaiVehicles_Rig.json` → `python tools/blender/vehicle_rig_to_luau.py` → `src/shared/ThaiVehicleRigs.luau`
แกน: หน้ารถหัน -Y ใน Blender, ด้านซ้ายรถ = +X (พวงมาลัยขวาอยู่ฝั่ง -X), origin = พื้นใต้กึ่งกลางรถ

| ไฟล์ | Object | หมายเหตุ |
|---|---|---|
| ThaiPickupOld.fbx | ThaiPickupOld, ThaiPickupOld_Glass, ThaiPickupOld_Interior, Wheel_FL/FR/RL/RR | กระบะ Hero ยุค 90 สีน้ำตาลแดงลอก สนิม แถบซีดข้างรถ ล้อกระทะสนิม คอกเหล็ก ฝากระโปรงปิด ยาว 21.6 · กระบะยืนได้ 4 คน |
| ThaiSedanSoluna.fbx | ThaiSedanSoluna, _Glass, _Interior, Wheel_* | เก๋งบรอนซ์ทอง ฝาครอบล้อเงิน 4 ประตู 4 ที่นั่ง ป้ายทะเบียนไทย (SurfaceGui ใน Studio) |
| ThaiBicycleRed.fbx | ThaiBicycleRed, ThaiBicycleRed_Handlebar, Wheel_F/R | เฟรมมิกซ์สีแดง บังโคลนโครเมียมสั้น ตะแกรงหลัง อานสปริง ไฟหน้าไดนาโม (ย่อ 0.85) |
| ThaiBicycleBlue.fbx | ThaiBicycleBlue, _Handlebar, Wheel_F/R | สีน้ำเงินสติกเกอร์เหลือง ตะกร้าหน้า เบาะซ้อนท้าย ขาตั้ง บังโซ่ (ย่อ 0.85) |
| ThaiTukTuk.fbx | ThaiTukTuk, _Glass, _Handlebar, Wheel_F/RL/RR | ตัวรถน้ำเงิน-แดง หลังคาผ้าใบดำ ป้าย TAXI เสาโครเมียม เบาะหลัง 2 ที่ |
| ThaiRacingMoto.fbx | ThaiRacingMoto, _Handlebar, Wheel_F/R | เวฟซิ่งส้มดำลายขาว ล้อซี่ลวด 4 สี วงล้อ/จานทอง ท่อม่วง โช้คแดง (ย่อ 0.9) |
| ThaiSoundTruck.fbx | ThaiSoundTruck, _Glass, _Interior, _Horns, _LED1–5_Neon, Wheel_* | กระบะเตี้ยสีน้ำเงินสติกเกอร์ลาย แม็กดำ ตู้ลำโพงในกระบะ (ลำโพงหันข้างทั้ง 2 ฝั่ง + หลัง) วงไฟ LED แยก 5 สี ฮอร์น 15 ตัว |

| ThaiParadeTruck.fbx | ThaiParadeTruck, _Glass, _Interior, _Windows, Wheel_FL/FR, Wheel_RL1/RR1/RL2/RR2 (ล้อคู่) | รถแห่ 6 ล้อหัว Hino แดง ตู้สูง 19 คร่อมหลังคาหัว หน้าตู้ระแนงเฉียง ข้างตู้ลายเฉียงแดง/เทา/ขาว หน้าต่างดำ 5 บาน โลโก้ทอง ประตูท้ายเปิด บันไดพับ ชั้นลอย + บันไดในตู้ ล้ออัลลอยเงิน ยาว 33.4 |

เก๋ง/กระบะ/รถแห่: ตัวถังเป็นเปลือกโค้งต่อเนื่อง (`car_shell`) กระจก `_Glass` ทำ 2 ด้าน · ภาพเทียบรูปอ้างอิง: `previews/ThaiVehicles_RefCompare.png` (`<ชื่อ>_RefPair.png`)
ทุก object ไม่เกิน 10,000 triangles · ใน Studio: `MapBuilder.BuildThaiVehicleTemplates()` (ดู GEMINI.md หัวข้อ 🚗)

## ร่มกาง (`tools/blender/umbrella.py`)
ไฟล์ต้นฉบับ: `umbrella.blend` · ภาพตัวอย่าง: `previews/Umbrella.png`, `Umbrella_below.png` (มุมใต้ร่ม), `Umbrella_Sheet.png`

| ไฟล์ | Object | หมายเหตุ |
|---|---|---|
| Umbrella.fbx | Umbrella_Canopy, Umbrella_Frame, Umbrella_Handle | ร่มกาง 8 ซี่ กว้าง 6 studs (ใหญ่กว่าร่ม Part เดิม 4.6 ใน `Pedestrian.AddUmbrella` ให้เงาคลุมตัวละคร) ยอดผ้าสูง 5.1 จาก origin · origin = จุดมือจับ (กลางด้ามไม้ตรง) ก้านตั้งขึ้น +Z ของ Blender (+Y ใน Studio) · ผ้าทำ 2 ด้าน ขอบเป็นลอนระหว่างซี่ · ผ้าสีเทาอ่อน ให้ย้อมสีใน Studio ด้วย `SurfaceAppearance.Color` (สีร่มใน `UMBRELLA_COLORS`) · ใต้ร่มมีซี่ ซี่ค้ำ รันเนอร์ ด้ามไม้ตะขอ J · รวม 4,706 tris ทุกชิ้นไม่ต้องมี collision |

## ศาลพระภูมิ v2 + มือผี + ขนมบนใบตอง + กระถางธูป + แกลลอน — นำเข้า Studio แล้ว (2026-11-03)

นำเข้าด้วย Import 3D: **Scale Unit = CM, Scale Factor = 1** (ไฟล์เก็บเป็นซม. 1 stud = 28 ซม.), Set Pivot to Scene Origin, Merge Meshes ปิด, Anchored
- `Workspace.SpiritHouse.SpiritHouseOnStilts` = ศาล v2 (วางที่ origin เดิมของศาล v1, ศาล v1 เก็บที่ `ServerStorage.ArchivedPlaceholders.SpiritHouseOnStilts_v1`)
  มี Attachment `HandHole` (ช่องประตู) + `OfferingSpot` (ที่วางขนม ฝั่งซ้ายของแท่นยื่น) ให้ `server/ShrineHand`
- `Workspace.SpiritHouse.IncensePot` บนแท่นยื่นฝั่งขวา, ธูป `Incense1-3` (+`_Neon` ไฟ/ควัน, `_Ash` ขี้เถ้าเทา) ปักเรียงห่าง 0.16 studs
- ต้นแบบใน `ServerStorage.ImportedProps`: `GhostHand` (rig 17 กระดูก: `server/ShrineHand` หมุนนิ้วกำขนมเองผ่าน Bone.CFrame), `LeafSweets`, `JerryCan` (`server/JerryCan` ใช้แทนแกลลอนประกอบ), `SpiritHouseOnStilts_v2`, `IncensePot`

### ไฟล์ต้นฉบับ (`tools/blender/spirit_house_v2.py`, `incense_pot.py`, `jerry_can.py`)
ไฟล์ต้นฉบับ: `spirit_house_v2.blend` (สำเนาจาก `pump_props.blend` เหลือเฉพาะ 3 ชุดนี้ + collection `V2_Layout` จัดวางมือผีเอื้อมคว้าขันไว้ดู) · ภาพ: `previews/SpiritHouseOnStilts_v2.png` (+`_side`, `_scene` = มือผีเอื้อมออกจากประตูไปที่ขัน, `_front`), `GhostHand.png`, `LeafSweets.png`
แกนใน Studio หลัง import: หน้า prop = -Z, ขวา = +X (= -X ของ Blender), บน = +Y

| ไฟล์ | Object (pivot) | ขนาด studs (X × Y × Z) | หมายเหตุ |
|---|---|---|---|
| SpiritHouseOnStilts_v2.fbx | SpiritHouseOnStilts (ชื่อเดิม) | 3.62 × 11.23 × 7.44 | ตัวศาลขนาดเท่าเดิม (0.86 × 1.40 × 0.74 ม.) · หมุนฐาน (เสา แท่น ราว บันได) -90° ให้บันไดและช่องที่ไม่มีราวอยู่หน้าศาล · ต่อแท่นยื่นหน้า 0.55 ม. กว้างเท่าแท่น (1.0 ม.) มีเสาค้ำเพิ่ม 2 ต้น ไม่มีราวด้านหน้า · **ไม่มีกระถางธูป/ธูป** (ใช้ของเดิมที่มีอยู่ใน Roblox) เว้นที่วางไว้บนแท่นยื่นฝั่งขวา (+X Studio) ที่ (-1.01, 0.73, -0.88) studs จากกลางกรอบ · ที่วางขนมฝั่งซ้าย · ประตูหน้าศาล 0.30 × 0.35 ม. ระดับพื้นตัวเรือน ข้างในเป็นโพรงมืดลึก 0.28 ม. (มองไม่ทะลุ) เสาคู่ในขยับออก พวงมาลัยยกเป็นซุ้มเหนือประตู · ใช้ texture ชุดเดิม `SpiritHouseOnStilts_*.png` (เพิ่มจุดสีมืด 8 px ในที่ว่างของ atlas ไว้ให้โพรง) · 3,034 tris |
| GhostHand.fbx | GhostHand (origin = ปลายแขนด้านในศาล ตรงแขนเสื้อขาด) | 0.54 × 0.99 × 3.39 | มือผีผอมแห้ง + แขนท่อนล่าง มือชี้ไป -Z ท่าแบครึ่งกำ · แขนกับฝ่ามือเป็นผิวเดียวต่อเนื่อง (ไม่มีรอยต่อข้อมือ) ผิวโค้งเรียบ (Subdivision 1 ระดับ) **ฝ่ามือใหญ่** (กว้าง/ยาว x1.6 หนา x2) สันกระดูกแขน ข้อกระดูกนูนที่โคนนิ้ว ข้อนิ้วปูดช่วงกลางคอด เล็บยาวเหลืองสกปรก · ผิวเทาอมเขียวซีดด่างละเอียด เส้นเลือดจางสีม่วงอมน้ำเงินใต้ผิว · ปลายแขนคล้ำหายเข้าแขนเสื้อขาดสีดำ · จุดกำ (กลางระหว่างปลายนิ้วโป้งกับนิ้วกลาง) อยู่ที่ (-0.15, -0.53, -3.17) studs จาก origin · **มี rig** `GhostHandRig` 17 กระดูก (Forearm → Hand → Index/Middle/Ring/Pinky/Thumb 1-3) ผิวผูกน้ำหนักตามระยะ + action `Grab` 30fps: เฟรม 1 ท่าปกติ → 12 แบนิ้วเตรียมคว้า → 22 กำรอบชิ้นขนม → 40 ค้าง (ภาพ `GhostHand_open.png`, `GhostHand_grab.png`, `_grab_side`) · ~8,900 tris |
| IncensePot.fbx | IncensePot (origin = กลางก้นกระถาง) | 0.54 × 0.48 × 0.54 | กระถางธูปแยกชิ้น ใช้กับศาล v2 (ศาลไม่มีกระถางในตัวแล้ว) · เซรามิกเคลือบแดงเลือดหมูหม่น คาดแถบทอง ปากบานทอง ขาเตี้ย 3 ขา · ในกระถางเป็นทรายขี้เถ้าอย่างเดียว (ไม่มีก้านธูปเก่า ใช้ธูป 3 ดอกเท่านั้น) มีกองขี้เถ้าเล็ก 3 จุดบอกตำแหน่งปักธูป · ธูป 3 ดอกเรียงแถวขวางหน้าศาล (แกน X) ที่ x = -0.16, 0, +0.16 studs บานออก -9°/0°/+9° ให้นับจำนวนได้ทันทีเมื่อมองจากหน้าศาล · ผิวทรายสูง 0.29 studs จากก้น: ปักธูป 3 ดอกเดิมของเกม (Incense1-3 + _Neon ที่มีไฟ แสง และควัน) ให้โคนจมตรงนี้ · สคริปต์ `tools/blender/incense_pot.py` · 1,528 tris |
| LeafSweets.fbx | LeafTray (ใบตองรองทรงเรือ ปลายแหลม), OpenWrap (ใบห่อที่แกะคลี่), SweetCake (ขนมตาลชิ้นที่แกะแล้ว + มะพร้าวขูด), Wrapped (ห่อที่ยังไม่แกะ 3 ห่อ) — origin เดียวกัน = กลางใต้ใบตอง | 1.50 × 0.79 × 0.46 studs (X×Y×Z) | ขนมตาลบนใบตอง ไม่มีขัน/จาน · ในเกม: จุดหยิบในร้าน = ครบทุกชิ้น, ชิ้นที่ถือ (มือแบหงาย) / ถวายศาล = ไม่มี Wrapped · มือผีหยิบไปแค่ SweetCake ใบตองอยู่ที่เดิม · รวม 452 tris |
| JerryCan.fbx | JerryCan (ตัวแกลลอน + หูหิ้ว + ฝา ชิ้นเดียว), JerryCanFuel (เปลือกน้ำมัน) — origin เดียวกัน = กลางคานหูหิ้ว (จุดที่มือกำ) | 0.61 × 1.25 × 0.90 | ทรงเดียวกับในเกม (`server/JerryCan`): ตัวถังมุมมน ไหล่ลาดหน้า-หลังลงจรดขอบ หูหิ้วห่วงกลม ฝาเกลียว ขีดปริมาตรด้านข้าง · คราบเก่าวาดลง texture `JerryCan_Color.png` จากภาพชุดเดียวกับในเกม (`jerry_can_grime/`) · JerryCanFuel = เปลือกบางครอบตัวถังใต้ระดับน้ำมัน (~2/3) ในเกมตั้งชมพูแดงโปร่งแสง 0.45 ตอนมีน้ำมัน ซ่อนตอนเปล่า · สคริปต์ `tools/blender/jerry_can.py` · ในเกมตอนนี้ยังใช้แกลลอนที่ `server/JerryCan` ประกอบจากชิ้นส่วน · 1,888 + 220 tris |

## ผีเปรต `Pret` (ยังไม่ได้นำเข้า Studio)

สคริปต์ `tools/blender/pret.py` (Blender headless ผ่าน `run_headless.ps1`, `$env:PRET_STAGE = "shape"` = ภาพเร็ว, `"check"` = ตรวจการทะลุแล้วหยุด) สร้างตัวจาก `human_base/human_base_thin.blend` (HumanRig 52 กระดูก + weight + joint limits + UV เดิม แบบเดียวกับกระหัง) แล้วเซฟเป็น `pret.blend`
ภาพ: `previews/Pret.png` (3/4), `_front`, `_side`, `_rest` (A-pose), `_face` (หน้าใกล้), `_scale` (เทียบตัวมนุษย์ 1.80 ม.), `_clips_front` / `_clips_side` (แถวบนลงล่าง = Idle, TallSlowWalk, Shriek ท่าละ 6 จังหวะ)

| ไฟล์ | Object (กระดูกที่ผูก) | หมายเหตุ |
|---|---|---|
| Pret.fbx | Body, Eyes (`head`), Tongue (`Tongue1-6`), Hair (`head` → `neck`), Cloth (`hips` + `thigh.L/R`) + `HumanRig` | เปรตสูงเท่าต้นตาล **4.0 ม. = 14 studs** (1 ม. = 3.5 studs เหมือนตัวมนุษย์) · ยืดตัวคนตามกระดูก: ขา x3 (ข้อสะโพกอยู่ที่ 2.47 ม. = 62% ของความสูง ขายาว 2.47 ม. ต่อลำตัว+หัว 1.53 ม.) ลำตัว x1.6 คอ x2.4 แขน x3.3 นิ้ว x2.6 หัวเล็ก x1.4 · **หนังหุ้มกระดูก:** subdivide 1 ระดับ ซี่โครงบาน ท้องตอบลึก เอวคอด แขนขาคอดกลางท่อน ปุ่มเข่า ศอก ข้อเท้านูน ร่องซี่โครง (หน้าและหลัง) ไหปลาร้า กระดูกอก สันเชิงกราน กระดูกสันหลัง สะบัก วาดลง texture + normal · ผิวคล้ำน้ำตาลเทาแบบศพตากแดด (โทนเดียวกับกระหัง) แตกระแหง ด่างเน่า เส้นเลือดม่วง ข้อนิ้วปูด เล็บยาวเหลือง · **บาดแผล:** แผลเปื่อยทั่วตัว สะเก็ด หนังแตกแดงรอบปุ่มกระดูก แผลแตกลึกตรงหน้าแข้ง เข่า ศอก ซี่โครง ไหปลาร้า หลัง (เนื้อแดงเปียก ขอบเลือดแห้งดำ ช้ำรอบ เลือดแห้งไหลเป็นทาง) รอยข่วนเล็บ 3 เส้นที่ต้นขา แขน อก แผลที่หน้าผาก แก้ม มุมปาก (วาดในพิกัด 3 มิติ แผลไม่ขาดตามรอยตัด UV) · ลูกตาโปนกลมโต ตาขาวเหลือง เส้นเลือดแดง รูม่านตาเท่ารูเข็ม เบ้าตาดำ ขอบตาแดง ปากอ้ากลมเห็นฟันห่าง · ลิ้นยาวแดงคล้ำจากปากห้อยถึงท้อง · ผมบางมาก: เส้นผมเรียวห่างๆ ~95 เส้น ร่วงเป็นหย่อม เห็นหนังหัวคล้ำ ยาวสุดแค่ต้นคอ หน้าโล่ง · ผ้าขาวม้านุ่งจงกระเบนแบบเดียวกับกระหัง: ผืนเดียวพันแนบสะโพก ข้างสั้น 28% ของต้นขา หน้า-หลังร่นขึ้นถึงเป้า ปมที่สะโพกซ้าย ชายผ้า 2 ชาย · ลายตารางแดงอิฐซีดจนเกือบน้ำตาล ด่างแดดเผา คราบดิน คราบเลือดแห้ง ชายผ้าเปื้อนโคลน ขอบลุ่ยขาดแหว่ง · texture ชุดเดียว 1024 ใช้ร่วมทุกชิ้น `Pret_Color/_Normal/_Roughness/_Metalness.png` · รวม 17,964 tris (Body 9,092, Hair 4,370, Cloth 2,776, Tongue 1,150, Eyes 576) · weight ไม่เกิน 4 กระดูกต่อจุด |
| Pret_Idle.fbx / Pret_TallSlowWalk.fbx / Pret_Shriek.fbx | rig อย่างเดียวพร้อมท่า 30 fps | `Idle` (121 เฟรม วนลูป หลังค่อม คอยื่น หายใจ นิ้วยาวขยับเป็นคลื่น หัวกระตุกหันขวับ 1 ครั้ง), `TallSlowWalk` (97 เฟรม วนลูป ก้าวยาวช้า ~1.3 ม. ต่อก้าว แขนยาวแกว่งตามหลังขา), `Shriek` (91 เฟรม ครั้งเดียว ย่อตัว → แหงนหน้ากรีดร้อง กางแขน นิ้วกางแอ่นสั่น ลิ้นสะบัดไปข้างหน้า → คืนท่ายืน) |

rig = HumanRig 52 กระดูกเดิม (ยาวขึ้นแต่ทิศเดิม ท่าของตัวมนุษย์ใช้ได้) + `Tongue1`–`Tongue6` (ต่อจาก `head`) · ทุกเฟรมคำนวณลิ้นให้ห้อยดิ่งตามแรงโน้มถ่วงก่อนลงคีย์ (หัวก้มเงยแล้วลิ้นไม่ฟาดเข้าอก)
ผ้าขาวม้าทุกจุดใช้น้ำหนักผสมจากผิวที่อยู่ใต้ผ้า (hips / spine / ต้นขา 6 จุดใกล้สุด) ผ้างอตามตัวพอดี ขายาวก้าวแล้วไม่ทะลุ · ผมช่วงล่างผูกกับ `neck`
**ตรวจการทะลุทุกเฟรมทุกท่า** (`check_clips`, เกิน 4 มม. นับว่าทะลุ): แขน/นิ้วกับลำตัวและขา, ขากับขาอีกข้าง, ลิ้นกับตัวและแขน, ผมกับคอ บ่า ลำตัว, ผิวขา/สะโพกโผล่นอกผ้า → ทั้ง 3 ท่า ไม่ทะลุ

**ยังเหลือ:** ยังไม่ได้นำเข้า Roblox Studio · ยังไม่มีกระดูกกราม (ตอนกรีดร้องปากไม่อ้ากว้างขึ้น)

## ผีกระหัง `Krahang` (ยังไม่ได้นำเข้า Studio)

สคริปต์ `tools/blender/krahang.py` (Blender headless ผ่าน `run_headless.ps1`) สร้างตัวจาก `human_base/human_base_thin.blend` (rig + weight + joint limits เดิม) แล้วเซฟเป็น `krahang.blend`
ภาพ: `previews/Krahang.png` (3/4 ท่าบิน), `_front`, `_side`, `_rest` (ท่า A-pose), `_face`, `_anims` (มุม 3/4) + `_anims_front`, `_anims_side` (แถวบนลงล่าง = FlapFly, Glide, LandOnRoof, PeekOverEdge, แถวละ 5 จังหวะ)

| ไฟล์ | Object (กระดูกที่ผูก) | หมายเหตุ |
|---|---|---|
| Krahang.fbx | Body, Hair (`head`), Cloth (`hips`/`spine`/`thigh` ตามผิวใต้ผ้า + `sak` ที่ชายหน้า-หลัง), Kradong.L / Kradong.R (`kradong.L/R`), Sak (`sak`) + `HumanRig` | ชายผอมโซ ผิวคล้ำแห้ง ซี่โครงบาน ท้องตอบ หน้าแยกเขี้ยว ตาเหลืองแดง · **บาดแผล** (วาดลง Color/Normal/Roughness ในพิกัด 3 มิติ แผลจึงไม่ขาดตามรอยต่อ UV): แผลถลอกเนื้อแดงรอบท่อนแขนใต้หวายมัดกระด้ง รอยครูดยาวที่ต้นขาด้านในกับหัวเข่าจากการหนีบสาก แผลฉีกพาดซี่โครงซ้าย รอยกรีดสั้นซี่โครงขวา รอยข่วน 3 เส้นกลางหลัง แผลยาวที่แก้มซ้ายกับคิ้วขวา แผลเปื่อยกระจาย (ไหล่ หน้าแข้ง ท้อง) · แผลมีเนื้อแดงเปียกตรงกลาง ขอบเลือดแห้งคล้ำ สะเก็ดนูน และคราบเลือดแห้งเลอะออกนอกแผล ผมดำยาวยุ่งปลิวไปด้านหลัง (ด้านบนเป็นปอยผมแบนแยกกันชี้ไปหลัง มีเส้นชี้ฟู ไรผมหน้าผากปัดขึ้น ข้างใต้มีแค่แผ่นบางๆ แนบหนังหัว) นุ่งผ้าขาวม้าแดงสั้น ผูกปมที่สะเอวซ้าย ชายหน้า-หลังตรงกลางถกสูงพ้นสาก · **นั่งคร่อมกลางสากตำข้าวอันใหญ่** (ยาว 1.8 ม. เอวสากอยู่ใต้เป้าพอดี ช่วงระหว่างต้นขาเรียวลง ปลายทั้งสองข้างหนา) ตอนขี่ต้นขายกแนบไปตามสาก เข่ากางพ้นข้างสากเล็กน้อย เข่าพับเก็บขึ้นไปใต้สาก เท้าเกือบตรง · ลายไม้แตกบนสากเป็นรอยเส้นผมเล็กตามเสี้ยน เกาะเป็นกลุ่ม ปลายสากมีรอยแตกรัศมี · **กระด้งมัดติดหลังท่อนแขนล่าง** ด้วยหวาย 2 เส้น มือว่าง · สูง 1.80 ม. = 6.3 studs (1 ม. = 3.5 studs เหมือนตัวมนุษย์) · texture ชุดเดียว 1024 ใช้ร่วมทุกชิ้น `Krahang_Color/_Normal/_Roughness/_Metalness.png` · รวม 15,486 tris (ชิ้นใหญ่สุด Hair 8,516) · weight ไม่เกิน 4 กระดูกต่อจุด |
| roblox/krahang/Krahang_<ท่า>.fbx | rig อย่างเดียวพร้อมท่า 30 fps | `FlapFly` (30 เฟรม วนลูป กระพือ 1 ครั้ง ลงเร็วขึ้นช้า ตอนยกกระด้งบิดตะแคง), `Glide` (90 เฟรม วนลูป ร่อน เอียงตัวช้าๆ), `LandOnRoof` (45 เฟรม ครั้งเดียว จบท่าหมอบ สากเอียงตามตัว ปลายหลังลอยเหนือหลังคาเล็กน้อย), `PeekOverEdge` (120 เฟรม วนลูป หมอบชะโงกหน้าลง หัวกระตุก 1 ครั้ง) |

rig = HumanRig 52 กระดูกเดิม + `kradong.L`, `kradong.R` (ลูกของ `forearm.L/R` แกนตามท่อนแขน หมุนแกน Y = บิดกระด้ง) และ `sak` (ลูกของ `hips` หัวกระดูกอยู่กลางสาก ชี้ไปปลายหน้า)
ในท่าบิน ตัวโน้มไปหน้า 30° และหมุน `sak` สวนกลับให้สากอยู่ระนาบ · สากหมุนสวนสะโพกได้ไม่เกิน 36° (`SEAT_REL`) มากกว่านี้ปลายสากจะเข้าเป้า/ท้อง ท่าหมอบจึงให้สากเอียงตามตัว · หัวกระดูก `sak` อยู่ใต้เป้าด้านหน้า (y = -0.02) ตรงที่ขาหนีบชนสาก
ขยาย joint limit ของ `shin.L/R` ใน rig นี้เป็น -130° (rig เดิม -95°) ให้พับเข่าได้ (constraint บีบค่าตอน evaluate ด้วย ไม่ใช่แค่ตอนตั้งท่า) · ต้นขาที่ยกไปหน้าเกือบ 90° ต้องกางด้วยแกน Y ของ `thigh` (แกน Z แค่บิดขารอบตัวเอง)
ผ้าขาวม้า: weight ของแต่ละจุดเอามาจากผิวที่ใกล้ที่สุด (เฉลี่ยมุมของหน้าผิวนั้น) แล้วเกลี่ย 3 รอบ ไม่เกิน 4 กระดูก · ชายหน้า-หลังตรงกลางผูก `sak` 75% ให้ขี่ไปกับสาก · `relax_cloth()` ไล่ทุกท่า (ทุก 3 เฟรม) หาจุดที่ผ้าจมเข้าผิว (ข้อพับสะโพกยุบตอนยกขา) แล้วดันจุดนั้นออกในท่ายืนเท่าที่จม + 6 มม. เกลี่ยรัศมี 3 ซม. ทำ 6 รอบ
ตรวจท่าชนด้วย `clip_check()` **ทุกเฟรมของทั้ง 4 ท่า** วัดว่าจุดของชิ้นหนึ่งจมเข้าในอีกชิ้นลึกเท่าไร (ยิง ray นับจำนวนครั้งที่ตัดผิว กับ mesh ทั้งชิ้นที่ปิดสนิท นับเฉพาะเมื่อผิวที่ใกล้สุดเป็นของชิ้นที่ตรวจ) เกิน 6 มม. ถือว่าทะลุ: แขน×ลำตัว/ขา/สาก/ผ้า, กระด้ง×ตัว/หัว/กระด้งอีกใบ/สาก/ผม/ผ้า, ขา×ขา/สาก/ผ้า, ผ้า×ลำตัว/สาก, สาก×ลำตัว, ผม×ลำตัว/แขน (กระด้งกับแขนของมันเอง และผมกับหัว/คอ ไม่นับ) · ผลล่าสุด: ทุกท่าผ่าน ลึกสุดที่เหลือ 4 มม. (ขาแตะสากตอนหมอบ) ผ้า 3 มม.
ลองท่า/รูปทรงเร็วๆ: ตั้ง `KRAHANG_QUICK=<โฟลเดอร์>` ก่อนรัน จะข้าม bake/export ใช้ texture เดิม และเขียนภาพตัวอย่างลงโฟลเดอร์นั้น · `KRAHANG_CHECK=<ทุกกี่เฟรม>` = สร้างท่า ตรวจชนอย่างเดียว

**ยังเหลือ:** ยังไม่ได้นำเข้า Roblox Studio · ท่า PeekOverEdge ก้มหัวลงแล้วปอยผมยาวชี้ขึ้นฟ้า (ผมผูกกับ `head` อย่างเดียว ไม่ห้อยตามแรงโน้มถ่วง)

## กระสือ (Krasue) — ผีตัวเต็ม มี rig — ยังไม่ได้นำเข้า Studio
สคริปต์ `tools/blender/krasue.py` (รันด้วย `tools/blender/run_headless.ps1`) · ไฟล์ต้นฉบับ `krasue.blend`
ภาพ: `previews/Krasue.png` (3/4), `Krasue_front.png`, `Krasue_side.png`, `Krasue_face.png` (หน้าใกล้) — หน้าตรงกับหน้าใกล้เรนเดอร์ EEVEE แสงกลางวัน (Workbench+cavity ทำจมูกที่เป็นชิ้นแยกของ human ดูเป็นกรวยสีเข้ม ทั้งที่ material/UV/ผิวเดียวกับหน้า), `Krasue_lunge.png` (เฟรม 15 ของ Lunge), `Krasue_night.png` (EEVEE กลางคืน อวัยวะ/ตาเรืองแสง), `Krasue_anim_sheet.png` / `_side.png` (เฟรมสำคัญของทุกท่า แถวละท่า: Float, Lunge, Sniff, HairWhip)
**หัว ผม และหน้า ใช้ของ human model** (ไม่ได้ปั้นเอง): หัว+คอของ `human_female` (mesh + UV เดิม) ตัดตรงน้ำหนัก head+neck ≥ 0.5 ตัดหูทิ้ง (ผมคลุมอยู่แล้ว โผล่ทะลุผม) จมูกของ human กดให้ยื่นน้อยลง 60% และแคบลงเหลือ 80% (`NOSE_FLAT`, `NOSE_W` เดิมเป็นกรวยแหลมดูหลุดจากหน้า) ย่อขยายให้หัวสูงเท่าหัวเดิม แล้วปิดตอคอด้วยขอบขาดรุ่งริ่ง + เนื้อแดงเว้าเข้า
ผิวหน้าวาดด้วย `build_skin.paint_head` สีหน้า `FACES["krasue"]` (ผีซีด เบ้าตาคล้ำ คิ้วขมวด ปากอ้าเห็นฟัน น้ำตาเลือด) + วาดทับ: ตาแดง เลือดรอบปาก/มุมปาก ไหลเป็นทางลงคางถึงคอ คอล่างชุ่มเลือดทั้งรอบ · เลนส์ตาแดงแปะบนตาที่วาดไว้ เขี้ยวบน 2 ล่าง 2 ที่ขอบปากที่อ้า (หาตำแหน่งบนผิวด้วยการยิงจากแกนหัว)
ผมสร้างด้วย `Head`/`Build` ของ `build_hair` (`krasue_hair` ใน krasue.py) **ยาวประบ่า** (ผู้ใช้ไม่เอาผมยาวถึงอก) แหวกกลาง: หนังหัวเป็น shell บางๆ แค่ถึงแนวผม (แนวผมโค้งลงคลุมมุมหน้าผาก บางแนบหนังหัว ร่องแสกกลาง) + **ปอยผมแบนเรียวแยกเป็นเส้น 43 ปอย** (ปอยหน้า 4 คู่จากข้างแสกตกคลุมขมับ/ข้างแก้ม, ข้าง+หลัง 2 ชั้นเหลื่อมกัน) ยาวไม่เท่ากัน ปลายเรียวแหลม มีช่องระหว่างปอย
`ghost_long` เดิมเป็น shell ผืนเดียว ใช้แล้วดูเป็นผ้าคลุมหัว/ฮู้ด จึงไม่ใช้ · ตอนสร้างผมใส่เสาทรงกระบอกต่อคอลงไปชั่วคราว ไม่งั้นผมถูกดันออกเป็นกระโจม
ใต้คอเป็นหลอดลม (วงกระดูกอ่อน) เส้นเลือดใหญ่ ปอด 2 ข้าง หัวใจ ก้อนลำไส้เล็กขด ลำไส้ใหญ่โค้งครอบ ห่วงไส้ 2 ห่วง และไส้เส้นหลักห้อยลงล่าง (ปั้นเองทั้งหมด เลื่อนตามตอคอใหม่)
origin ทุกชิ้น = กลางหัว (อวัยวะห้อยลงไป ~2.3 studs) · ขนาดรวม 1.28 × 3.00 × 0.96 studs (X × Y × Z) · หน้า = -Z ใน Studio
texture ชุดเดียว `Krasue_Color/_Normal/_Roughness/_Metalness.png` (1024 atlas) ใช้กับทุกชิ้น: ครึ่งบน = หัว+คอ (UV ทรงกระบอกของ human ตรงๆ v 0.505–0.995) ครึ่งล่าง = ผม ตา อวัยวะ เขี้ยว เนื้อตอคอ

| Object | material | tris | หมายเหตุ |
|---|---|---|---|
| Krasue | Krasue_Mat | 612 | หัว คอ ตอคอขาด เขี้ยว (ผูก Head 100%) |
| Krasue_Hair | Krasue_Mat | 9,736 | หนังหัว + ปอยผม 43 ปอย ประบ่า เหนือคางผูก Head 100% ช่วงที่ห้อยใต้คางผูก Hair_L/R/B (≤4 กระดูกต่อจุด) |
| Krasue_Eyes | Krasue_EyesMat | 576 | เลนส์ตา 2 ข้าง แยกชิ้นไว้ให้ตั้ง Neon / ใส่แสงแดงให้เห็นตอนมืด |
| Krasue_Organs | Krasue_OrgansMat | 10,658 | หลอดลม เส้นเลือด ปอด หัวใจ ไส้ทั้งหมด — แยกชิ้นให้เกมทำเรืองแสง (Neon / PointLight สีส้ม-เขียวตามตำนาน หรือแดงตามภาพอ้างอิง) |

**Rig `KrasueRig` 16 กระดูก** (root = Head ตำแหน่งจากกระดูก `head` ของ HumanRig): `Head` → `Hair_L1-2`, `Hair_R1-2`, `Hair_B1-2` (ผม ซ้าย/ขวา/หลัง ข้อละ 2 หมุนที่ระดับคาง), `Windpipe` → `Heart`, `Gut1` (ก้อนไส้) → `Gut2..Gut7` (ไส้ห้อย chain 6 ข้อ)
**ท่า** (30 fps) แยกไฟล์ละท่า mesh + rig ชุดเดียวกัน:
- `Krasue.fbx` = `Float` 61 เฟรม วนซ้ำ: ลอยขึ้นลง ±0.07 studs หัวโยก ผมกับไส้แกว่งแบบหน่วงไล่ข้อ หัวใจเต้น 2 ครั้ง/รอบ
- `Krasue_Lunge.fbx` = `Lunge` 41 เฟรม: ถอยตั้งท่า (9) → พุ่งหัวไปหน้า ~2 studs (15) → ค้าง (23) → กลับที่เดิม (41) ผมสะบัดไปหลัง ไส้ลากตามและยืด (เลื่อนกระดูกไส้ตามแนวยาว)
- `Krasue_Sniff.fbx` = `Sniff` 49 เฟรม: ก้มดม สูดถี่ๆ · `Krasue_HairWhip.fbx` = `HairWhip` 31 เฟรม: สะบัดหน้าซ้ายขวา ผมเหวี่ยงตาม
- `Krasue_Anims.json` = ค่าทุกเฟรมของทุกท่า (quaternion + location ของแต่ละกระดูก ใน local space ของ Blender) ไว้ทำตัวแปลงแบบ `clips_to_luau.py` ถ้าจะเล่นท่าเองผ่าน Bone.Transform โดยไม่อัปโหลด
- `GlowPulse` เป็น VFX ในเกม (ปรับความสว่างของ Krasue_Organs) ไม่มีในไฟล์
- Roblox animation ไม่รองรับ scale ของกระดูก หัวใจเต้นจึงทำด้วยการหมุน/เลื่อนเล็กน้อย

**ตรวจท่าไม่ให้ทะลุกัน:** `tools/blender/krasue_check_anim.py` (เปิด `krasue.blend`) นับคู่สามเหลี่ยมที่ทะลุกันทุกเฟรมของทุกท่า เทียบกับท่าพัก: ผม-หัว, ผม-อวัยวะ, หัว-อวัยวะ, อวัยวะต่างก้อน (ไส้-ปอด-หัวใจ) แล้ววาดภาพ `Krasue_anim_sheet*.png`
ผลล่าสุด: ผมไม่ทะลุหน้า/คอ/อวัยวะเลยทุกท่า (เพิ่มจากท่าพัก 0 รวม HairWhip) · อวัยวะเพิ่มจากท่าพักไม่เกิน 5 คู่สามเหลี่ยมต่อคู่ก้อน เป็นแค่ผิวเฉียดตรงรอยต่อ (หลอดลมซ้าย-ขวาที่ง่าม, เส้นเลือดกับเอออร์ตา, ห่วงไส้/ไส้ห้อยที่โผล่จากก้อนไส้, หัวใจเฉียดก้อนไส้) จากเดิมสูงสุด 50–230
แก้ไว้: ผมเหนือคางผูก Head 100% กระดูกผมหมุนที่ระดับคาง มุมแกว่งผม x0.5 (`HAIR_AMP`) และ HairWhip อีก x0.6 · Lunge หัวใจกับก้อนไส้ไม่หมุนแยก (ทั้งก้อนแกว่งตาม Windpipe) · Float หัวใจเต้นไปหน้าและแกว่งไปกับก้อนไส้ ไส้ห้อยแกว่งน้อยลง · Sniff หัวใจก้มตามก้อนไส้ · HairWhip อวัยวะหมุนตามหัว (Windpipe สวน 0.15 แทน 0.4) ลำไส้ใหญ่เหวี่ยงน้อยลง ปอยผมข้าง/หลังที่ยาวสุดสั้นลงไม่ให้กวาดโดนยอดปอดตอนหันหน้า

**ส่วนที่ผีตัวอื่นใช้ซ้ำได้** (ใน `krasue.py` ส่ง `char` / `face` ของตัวเอง): `paint_ghost_head` (หน้า paint_head + ตาแดง + เลือดรอบปากไหลลงคาง, `neck_soak` = คอชุ่มเลือดสำหรับหัวขาด), `face_caster` (พิกัดหน้า → จุดบนผิว), `ghost_eyes` (เลนส์ตา), `ghost_fangs` (เขี้ยว) · ตอนรันตั้ง env `KRASUE_FACES=1` จะสร้างสีหน้าผี `ghost` / `ghost_cry` ของ `human_female` ลง `human_female/faces/` ด้วย

## ผีปอบ (Phi Pop) — ดัดแปลงจากโมเดลคน มี rig — ยังไม่ได้นำเข้า Studio
สคริปต์ `tools/blender/pop.py` (รันด้วย `tools/blender/run_headless.ps1`, ~6 นาที) · ไฟล์ต้นฉบับ `pop.blend` (มีแค่ 4 ท่าของปอบ ท่าคนอยู่ใน `human_female.blend` เหมือนเดิม)
ภาพ: `previews/Pop.png` (3/4), `Pop_front.png`, `Pop_side.png`, `Pop_face.png` (หน้าใกล้) · ท่า: `Pop_<ท่า>.png` (แถวบน = หน้า, แถวล่าง = ข้างซ้าย, 8 เฟรมทั่วท่า), `Pop_LickLips_face.png`, `Pop_PossessedSnap_face.png` (หน้าใกล้ หน้าตรง / 3/4)
ผู้หญิงชาวบ้านที่ถูกปอบสิง ทำจาก `human_female` (rig `HumanRig` และ UV เดิม ไม่ได้ปั้นตัวใหม่) สูง 1.68 ม. = 5.9 studs · origin = ระหว่างเท้าที่พื้น หน้า = -Z ใน Studio
- **ผิว:** หนังเหี่ยวแบบ `_Withered` (`build_skin.paint_head/paint_body`) วาดใหม่ทั้ง atlas เป็น `Pop_Color/_Normal/_Roughness.png` (1024, UV เดียวกับ human_female)
- **หน้า = ปากแบบกระสือ:** สีหน้า `FACES["pop"]` ค่าเดียวกับ `FACES["krasue"]` (ตาเบิก 1.25 คิ้วขมวด -1.2 ปากอ้า 2.4 เห็นฟัน) + ยิ้มแสยะ 0.6 ตั้งใน `pop.py` (ไม่ได้แก้ `build_skin.py` กันชนกับ branch กระสือ) แล้ววาดทับ: ปากอ้ากว้างดำแดง ฟันบนล่างเปื้อนเลือด ริมฝีปากแห้งแตก เลือดเลอะรอบปาก ไหลจากริมฝีปากล่างเป็นทางลงคาง 2 ทางยาวถึงคอ คางชุ่มเลือด คอหน้าชุ่มเลือด ตาแดงก่ำ ขอบตาแดง (ขนาดปากใน `pop.py`: `MW`, `GAP`, `GRIN`)
- **ผม:** `ghost_messy` สร้างใหม่ด้วย `build_hair.py` แต่แหวกกลาง (`GHOST_GAP = (0, 30)`) ให้เห็นทั้งหน้า ตัดปอยที่ห้อยบังปากออก และ**ย่อชายผมให้อยู่เหนือบ่า 8 ซม.** (ส่วนที่ยาวกว่าบีบขึ้น) เพราะผมผูกกับหัว 100% ถ้ายาวถึงบ่าจะทะลุบ่าตอนคอเอียง/หมุน 180°
- **ชุด (ชั่วคราว):** `blouse_sin` ของคน (เสื้อแขนกระบอกเขียวหยก + ซิ่นม่วง + รองเท้าแตะ) texture ก๊อปมาเป็น `Pop_blouse_sin_*`, `Pop_sin_purple_*`, `Pop_sandal_brown_*` **รอชุดผีจาก session ghost-outfits** แล้วเปลี่ยน `OUTFIT` ใน `pop.py` รันใหม่
- **ผิวใต้ชุดถูกตัดทิ้ง** (แบบเดียวกับที่ Roblox ทิ้งชิ้น `Skin_xx` ของคน): ผิวใต้เสื้อ (`hidden_faces` ของ build_clothes) + ขาที่อยู่ในซิ่นสูงกว่าชายซิ่น 10 ซม. → ตัวไม่มีทางทะลุชุด เหลือผิว 886 จาก 1,178 faces

| Object | material | tris | หมายเหตุ |
|---|---|---|---|
| Pop | PopSkin (`Pop_*`) | 1,734 | ผิวที่ชุดไม่ปิด: หัว คอ มือ ข้อเท้า เท้า |
| Pop_Hair | HairBlack | 2,368 | ผูก `head` 100% |
| Pop_Eyes | PopParts (`Pop_Parts_*`) | 316 | เลนส์ตาแดงทรงรีโค้งตามหน้า ลอยจากผิว 0.4 มม. ผูก `head` · แยกชิ้นให้ตั้ง Neon / ใส่แสงแดงตอนมืดได้ |
| Pop_Fangs | PopParts | 356 | เขี้ยวบน 2 ล่าง 2 ตรงมุมปาก ทรงครึ่งกรวยหลังแบนวางบนผิว (ลอย 0.4 มม.) ผูก `head` |
| Pop_Tongue | PopParts | 296 | ลิ้นยาว 4 ซม. ผูก `tongue_01-03` |
| Pop_Blouse / Pop_Sin / Pop_Sandals | ของชุด | 792 / 3,200 / 272 | ชุดชั่วคราว |

**Rig** = `HumanRig` เดิมทุกกระดูก + `tongue_01 → tongue_02 → tongue_03` ต่อจาก `head` (ท่าคนเดิมเล่นกับตัวนี้ได้ ลิ้นอยู่ที่พักเอง) · ขีดจำกัดบิดคอ `neck` / `head` แกน Y เปิดเป็น ±85° (คนปกติ ±40 / ±50) ให้หันคอ 180°
ลิ้นตอนพัก (และทุกท่ายกเว้น LickLips) ซ่อนทั้งเส้นอยู่ในหัวหลังช่องปากที่วาด ปลายลึก 4 มม. มองไม่เห็นจากข้างนอก · LickLips เลื่อน `tongue_01` ออกตามแนวลิ้น (location Y) ให้ข้อ `tongue_02` อยู่พ้นผิวปาก แล้วงอ/ส่าย `tongue_02-03` · ลิ้นผ่านผิวได้เฉพาะในช่องปากที่วาด (ตรวจทุกเฟรม) ไม่ผ่านริมฝีปาก
**ท่า** (30 fps อยู่กับที่) แยกไฟล์ละท่า armature อย่างเดียว แบบเดียวกับท่าคน (`Pop.fbx` = โมเดลท่า rest):
- `Pop_TwitchWalk.fbx` = `TwitchWalk` 48 เฟรม วนซ้ำ: ก้าวสั้นแบบใส่ซิ่น (`walk_skirt`) ตัวงุ้ม คอเอียงไปทางไหล่ขวา กระตุก 3 ครั้ง/รอบ (หัวสะบัด, ไหล่ขวายก+มือขวาจิกเกร็ง, หัวสะบัดกลับ) มือจิกงอ
- `Pop_LickLips.fbx` = `LickLips` 96 เฟรม วนซ้ำ: ยืนงุ้ม ยื่นคาง หัวเอียง ลิ้นเลื่อนออก (เฟรม 4-16) วนเลียรอบริมฝีปาก 1¼ รอบ แล้วหดกลับ (79-91) · มุมงอ/ส่ายของลิ้นถูกลดลงทีละเฟรมจนห่างผิวหน้าและเขี้ยว ≥ 1.4 มม. (ลด 4-15% ใน 16 เฟรม)
- `Pop_KnockShutter.fbx` = `KnockShutter` 60 เฟรม วนซ้ำ: ยื่นแขนไปข้างหน้า มือซ้ายแบแปะแผง กำปั้นขวาเคาะรัว 5 ครั้ง + 3 ครั้ง/รอบ หัวเอียงฟัง · **แผงสังกะสีต้องอยู่ห่างหน้า origin 0.555 ม. = 1.94 studs** (ระนาบที่กำปั้นถึง ฝ่ามือซ้ายอยู่ 0.545 ม.)
- `Pop_PossessedSnap.fbx` = `PossessedSnap` 72 เฟรม **เล่นครั้งเดียวค้างท่าสุดท้าย**: ยืนนิ่ง กระตุกเล็ก (เฟรม 10) แล้วหักคอหันขวับ 180° ในเฟรม 22-27 เลยไปนิดแล้วสั่นค้าง · บิดกระจาย: spine 11%, chest 14%, neck 36%, head 39% (ตัวบนหันตาม ~45° หัวหันหลังพอดี) · ในเกมหันหลังให้ผู้เล่นก่อนเล่นท่านี้
- `Pop_Anims.json` = ค่าทุกเฟรม (รูปแบบเดียวกับ `export_clip_data` ของคน) ไว้ทำตัวแปลงแบบ `clips_to_luau.py`

**ตรวจไม่ให้ทะลุ** (`pop.py` `check_all`, ผลเขียนลง log ทุกครั้งที่รัน): ทุกเฟรมของทุกท่า ตอนนี้ **0 เฟรมที่มีส่วนไหนทะลุ** ทั้ง 4 ท่า
- ผิวกับผิว (แขน/มือ/หัว/ลำตัว): แบบ `test_self_intersection.py` ยุบเข้ากันที่ข้อต่อได้ไม่เกิน 1.5 ซม.
- ต่างชิ้น: มือกับเสื้อ/ซิ่น/ผม/หัว/คอ, แขนเสื้อกับตัวเสื้อ/ซิ่น, ผมกับคอ/ลำตัว/เสื้อ/มือ, คอกับคอเสื้อ, ขา/เท้า/รองเท้ากับซิ่น: จุดที่อยู่นอกชิ้นอื่นตอน rest แล้วเข้าไป (หรืออยู่ใต้ผ้าแล้วโผล่ออก) เกิน 4 มม. นับว่าทะลุ
- ลิ้นกับเขี้ยว/ผม/ตา ต้องห่าง ≥ 0.8 มม. และลิ้นตัดผิวได้แค่ในช่องปาก
- ผม เขี้ยว ตา ผูก `head` 100% เคลื่อนไปกับหน้าทั้งก้อน จึงไม่มีทางทะลุกันเอง (วางห่างผิว 0.4 มม. ตอนสร้าง)
