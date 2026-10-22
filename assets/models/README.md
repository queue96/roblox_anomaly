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
