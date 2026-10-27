-- LanguageModule.luau
-- ระบบเก็บข้อความ 2 ภาษา (TH / EN) สำหรับคำพูดลูกค้าและชื่อผีในเกม "ปั๊มหลอดท้ายทุ่ง"

local LanguageModule = {}

LanguageModule.Dialogues = {
	Normal_Uncle = {
		th = "ไอ้หนู เติมเบนซินให้หลอดนึง ลุงจะรีบไปวิดน้ำเข้านา!",
		en = "Kid, fill up one cylinder for me. I need to pump water into my rice field!",
	},
	Anomaly_Headless = {
		th = "พี่ชาย เติมน้ำมันให้เต็มหลอดเลยครับ ทำไมวันนี้รถผมมันหนักๆ ชอบกล...",
		en = "Bro, fill it to the top. Why does my bike feel so heavy tonight...",
	},
	Anomaly_Cemetery = {
		th = "เติมน้ำมันให้หน่อยจ้ะ... ทางข้างหน้ามืดเหลือเกิน...",
		en = "Please give me some fuel... the road ahead to the cemetery is so dark...",
	},
	Anomaly_Cremate = {
		th = "ขอน้ำมันเต็มหลอด... จะเอาไปราดเผาศพตัวเองที่เมรุหน่อยจ้ะ ฮ่าๆๆ",
		en = "Fill it up... I need gasoline to cremate my own corpse tonight! Hahaha!",
	},
	-- ลูกค้าปกติเพิ่ม (Phase 3)
	Normal_Aunt = {
		th = "เติมให้ป้าหน่อยลูก ป้าจะรีบไปตลาดเช้า",
		en = "Fill it up for auntie, dear. I'm heading to the morning market.",
	},
	Normal_Student = {
		th = "พี่ครับ เติมหลอดนึงครับ เดี๋ยวแม่ด่าว่ากลับดึก",
		en = "One cylinder please. My mom will scold me for coming home late.",
	},
	Normal_Farmer = {
		th = "เติมเต็มหลอดเลย พรุ่งนี้ต้องเอารถไปไถนาแต่เช้า",
		en = "Fill it up. I have to take the tiller to the field at dawn.",
	},
	Anomaly_WheelHair = {
		th = "เติมน้ำมันให้หน่อย... ล้อมันหนักๆ เหมือนมีใครดึงไว้...",
		en = "Some fuel please... my wheels feel heavy, like someone is pulling them...",
	},
	-- ผีเพิ่ม (Phase 4: AnomalyManager)
	Anomaly_NeckTwist = {
		th = "เติมหลอดนึง... ข้างหลังผมมีอะไรเหรอ ทำไมมองไม่เห็นทางเลย...",
		en = "One cylinder... is something behind me? I can't see the road at all...",
	},
	Anomaly_CreepySmile = {
		th = "เติมน้ำมันให้หน่อยสิ... ยิ้มให้หน่อยก็ได้นะ หึหึหึ",
		en = "Fill it up for me... and give me a smile, won't you? Heh heh heh.",
	},
	Anomaly_Krasue = {
		th = "ขอน้ำมันหน่อยจ้ะ... คืนนี้ป้าหิวเหลือเกิน...",
		en = "Some fuel, dear... auntie is so very hungry tonight...",
	},
	Anomaly_MonkRadio = {
		th = "เติมหลอดนึงครับ... วิทยุร้านนี้เปิดเพลงเพราะดีนะ...",
		en = "One cylinder please... nice song on your radio tonight...",
	},
	Anomaly_Tani = {
		th = "เติมน้ำมันให้หน่อย... ผู้หญิงตรงกอกล้วยนั่นเขารอใครอยู่เหรอ...",
		en = "Some fuel please... who is that woman waiting by the banana grove...",
	},
	Anomaly_Scarecrow = {
		th = "เติมเต็มหลอดเลย... หุ่นไล่กาตัวนั้นมันเดินตามผมมาตั้งแต่หัวทุ่ง...",
		en = "Fill it up... that scarecrow has been following me since the edge of the field...",
	},
	Anomaly_BloodFuel = {
		th = "เติมน้ำมันสีแดงๆ นั่นให้หน่อย... หอมดีจัง...",
		en = "Fill me up with that red stuff... it smells so good...",
	},

	-- ---------------- บทสนทนาลูกค้า (Phase 4+) ใส่ {amount} = จำนวนเงิน
	-- ทักทาย (ผีที่ปลอมตัวมาก็ใช้คำทักของคนที่มันปลอม)
	Greet_Uncle = { th = "เออ หลาน ยังไม่ปิดร้านอีกเหรอ ดึกแล้วนะ", en = "Evening, kid. Still open this late?" },
	Greet_Aunt = { th = "สวัสดีจ้ะลูก คืนนี้หนาวจังเลยนะ", en = "Hello, dear. Chilly night, isn't it?" },
	Greet_Student = { th = "สวัสดีครับพี่ ยังเปิดอยู่ใช่ไหมครับ", en = "Hi! You're still open, right?" },
	Greet_Farmer = { th = "ไง น้อง ขอแวะเติมหน่อยนะ", en = "Hey there. Mind if I fill up?" },
	-- ถามราคา -> ผู้เล่นตอบ (ใครตอบก่อนได้ก่อน)
	AskPrice = { th = "คืนนี้หลอดละเท่าไหร่ล่ะ?", en = "How much for a cylinder tonight?" },
	AskPriceDiesel = { th = "ดีเซลเต็มถังคืนนี้เท่าไหร่ล่ะ?", en = "How much for a full tank of diesel tonight?" },
	AskPriceAir = { th = "เติมลมกี่บาทจ๊ะ?", en = "How much to pump up a tire?" },
	-- รถยนต์ (ดีเซล ตู้ 2) / ตุ๊กตุ๊ก / จักรยานยางแบน
	Car_Order_1 = { th = "เติมดีเซลหน่อย พรุ่งนี้ต้องขับเข้าเมืองแต่เช้า", en = "Diesel, please. I'm driving into town early tomorrow." },
	Car_Order_2 = { th = "ขอดีเซลเต็มถัง ขนผักไปส่งตลาดไทอีกรอบ", en = "Fill her up with diesel. One more vegetable run to the market." },
	Car_Order_3 = { th = "เติมดีเซลให้หน่อย ปั๊มใหญ่ในเมืองปิดหมดแล้ว", en = "Diesel, please. All the big stations in town are closed." },
	TukTuk_Order_1 = { th = "เติมหลอดนึง พรุ่งนี้ต้องวิ่งรับนักท่องเที่ยวแต่เช้า", en = "One cylinder. I'm picking up tourists first thing tomorrow." },
	TukTuk_Order_2 = { th = "เติมเบนซินหลอดนึง ตุ๊กตุ๊กคันนี้กินน้ำมันจริงๆ", en = "One cylinder of petrol. This tuk-tuk drinks fuel like water." },
	Bicycle_Order_1 = { th = "ยางแบนกลางทาง ขอเติมลมหน่อยนะ เข็นมาตั้งไกล", en = "Got a flat on the way. Could you pump it up? I pushed it all the way here." },
	Bicycle_Order_2 = { th = "ขอเติมลมยางจักรยานหน่อย พรุ่งนี้ต้องปั่นไปโรงเรียน", en = "Can I get some air in my tire? I ride to school tomorrow." },
	-- เติมผิดตู้
	Wrong_NeedDiesel = { th = "เดี๋ยวๆ! รถผมใช้ดีเซลนะ ตู้นั้นมันน้ำมันหลอด!", en = "Wait! My car takes diesel, that's the petrol pump!" },
	Wrong_NeedPetrol = { th = "นั่นมันดีเซล! รถฉันใช้เบนซินหลอดนะ", en = "That's diesel! I need petrol from the glass pump." },
	Wrong_NeedAir = { th = "ไม่ได้มาเติมน้ำมัน มาเติมลมยางจ้ะ!", en = "I'm not here for fuel, I just need air in my tire!" },
	Wrong_NeedFuel = { th = "ลมยางยังดีอยู่ เติมน้ำมันให้หน่อยสิ", en = "My tires are fine. I need fuel." },
	-- ขาจรบนถนน (ไม่ได้มาใช้บริการ)
	Racer_Shout_1 = { th = "ปั๊มผีปะเนี่ย 555 เปิดดึกจัง!", en = "Is this a ghost pump? Haha, open so late!" },
	Racer_Shout_2 = { th = "เฮ้ย ดูนี่! ยกล้อผ่านหน้าร้านโว้ย!", en = "Hey, watch this! Wheelie past the shop!" },
	Party_Line = { th = "ไปไหนกันจ๊ะคืนนี้ งานวัดบ้านโน้นยังไม่เลิกเลย ไปด้วยกันไหม!", en = "Where you headed tonight? The temple fair's still going, come along!" },
	Teen_Line = { th = "จัดไปพี่! เปิดดังๆ อีก!", en = "Let's go! Turn it up!" },
	Coyote_Line = { th = "หวัดดีจ้า แค่แวะทักเฉยๆ นะ ไม่ได้มาเติมน้ำมันหรอก", en = "Hi there! Just saying hello, we're not here for fuel." },
	Parade_Invite = { th = "พรุ่งนี้บวชลูกชาย! แวะไปงานนะ มีข้าวต้มเลี้ยงทั้งคืนเลย!", en = "My son's ordination is tomorrow! Drop by, there's rice soup all night!" },
	Parade_Cheer = { th = "โห่... ฮิ้ว!! โห่... ฮิ้ว!!", en = "Hooo... hiew!! Hooo... hiew!!" },
	Wrong_GiveUp = { th = "ทำผิดอยู่ได้... ไม่เอาแล้ว ไปปั๊มอื่นดีกว่า", en = "You keep getting it wrong... forget it, I'll go elsewhere." },
	PlayerQuote = { th = "หลอดละ {amount} บาท", en = "{amount} baht a cylinder." },
	-- ลูกค้ารับราคา
	Price_Cheap = { th = "โห {amount} บาทเองเหรอ ใจดีจริงๆ", en = "Only {amount} baht? That's kind of you." },
	Price_Normal = { th = "{amount} บาท ราคาเดิม โอเคเลย", en = "{amount} baht, same as usual. Okay." },
	Price_ExpensiveOk = { th = "{amount}... แพงขึ้นอีกแล้วนะ เอาก็เอา", en = "{amount}? Pricier again... fine." },
	Price_ExpensiveNo = { th = "{amount} บาท! แพงไป ไม่เติมดีกว่า", en = "{amount} baht?! Too much. I'll pass." },
	Price_Silent = { th = "ไม่ตอบเลย... งั้น {amount} บาทเหมือนเดิมนะ", en = "No answer... {amount} baht as usual, then." },
	-- จ่ายเงิน / ขอบคุณ
	Pay_1 = { th = "นี่ {amount} บาทนะ ขอบใจมาก", en = "Here's {amount} baht. Thanks a lot." },
	Pay_2 = { th = "เอ้า {amount} บาท ไม่ต้องทอนนะ", en = "Here, {amount} baht. Keep the change." },
	Pay_3 = { th = "ขอบใจจ้ะ นี่ {amount} บาท พรุ่งนี้มาใหม่นะ", en = "Thank you. {amount} baht. See you tomorrow." },
	-- โดนปิดร้านใส่ (ลูกค้าปกติ)
	Rejected_1 = { th = "อ้าว! ปิดร้านใส่ทำไมเนี่ย!", en = "Hey! Why'd you shut the shop on me?!" },
	Rejected_2 = { th = "ไม่ขายก็ไม่ขาย... ไม่ต้องทำแบบนี้ก็ได้", en = "Fine, don't sell then... no need for that." },
	-- ไม่มีใครมาเติมให้
	NoOne_1 = { th = "มีใครอยู่ไหม... เงียบจัง ไปปั๊มอื่นละกัน", en = "Anyone here?... So quiet. I'll go elsewhere." },
	NoOne_2 = { th = "ร้านเปิดแต่ไม่มีคน... แปลกจริง", en = "The shop's open but nobody's here... strange." },
	-- ผี
	Ghost_Price = { th = "เท่าไหร่ก็ได้... เงินไม่สำคัญหรอก...", en = "Any price... money doesn't matter anymore..." },
	Ghost_Pay = { th = "ขอบใจ... นี่เงิน... {amount} บาท... หึหึ", en = "Thank you... here's... {amount} baht... heh heh." },
	Ghost_Chased = { th = "ตามมาทำไม... อยากไปด้วยกันเหรอ!!", en = "Why are you following me... want to come along?!" },
	Ghost_Rejected = { th = "แก... รู้ได้ยังไง...", en = "You... how did you know..." },
	Ghost_NoOne = { th = "ไม่มีใครอยู่... งั้นเดี๋ยวกลับมาใหม่นะ...", en = "No one here... I'll come back later..." },
	Ghost_Wait = { th = "ไม่ต้องรีบ... ข้ารอได้... รอได้นานเลย...", en = "No rush... I can wait... I can wait a long time..." },
	Ghost_Wait2 = { th = "รอมานานแล้ว... นานกว่าที่เจ้าคิด...", en = "I've waited so long... longer than you think..." },
	-- ผู้เล่นทักทาย
	PlayerHello = { th = "สวัสดี รับอะไรดี", en = "Hi, what can I get you?" },
	PlayerGreetBoth = { th = "สวัสดีทั้งสองคนเลย", en = "Evening, you two!" },
	-- "ฉันมาคนเดียว" (ทักทั้งสองคน)
	Alone_Normal = { th = "สองคน? ฉันมาคนเดียวนะ ง่วงแล้วมั้งเรา", en = "You two? I came alone. You must be sleepy." },
	Alone_Ghost = { th = "พูดอะไรน่ะ... ฉันมาคนเดียวนะ... ทำไมหลังมันหนักๆ", en = "What are you talking about... I came alone... why does my back feel heavy..." },
	Alone_Creepy = { th = "คนเดียว... ตอนนี้ยังคนเดียว... หึ", en = "Alone... for now, alone... heh." },
	Passenger_Whisper = { th = "ชู่ว... อย่าบอกเขานะ...", en = "Shh... don't tell him..." },
	-- รอนาน / เติมช้า
	Greet_Waited = { th = "รอตั้งนานแน่ะ... คืนนี้คนเยอะจังนะ", en = "Took forever... busy night, huh?" },
	Impatient_1 = { th = "เร็วๆ หน่อยได้ไหม รีบอยู่นะ", en = "Could you hurry up? I'm in a rush." },
	Impatient_2 = { th = "ยังไม่เติมอีกเหรอ ยืนรอนานแล้วนะ", en = "Still not filling? I've been waiting a while." },
	Impatient_3 = { th = "นี่จะเติมหรือไม่เติม! จะไปละนะ!", en = "Are you filling it or not?! I'm about to leave!" },
	Pay_Slow = { th = "ช้าจริงๆ... ให้ {amount} บาทพอนะ", en = "So slow... {amount} baht is all you get." },

	-- ---------------- คนเดินมาซื้อน้ำมันใส่แกลลอน (บอกว่าจะเอาไปเติมอะไร)
	Walker_Order_1 = { th = "ขอซื้อใส่แกลลอนหน่อย รถไถจอดเสียอยู่ปากทาง น้ำมันหมดพอดี", en = "Fill this jug for me? My tractor ran dry at the end of the lane." },
	Walker_Order_2 = { th = "เติมใส่แกลลอนให้หน่อย จะเอาไปเติมเครื่องสูบน้ำเข้านา", en = "Fill the jug, please. It's for the water pump in my field." },
	Walker_Order_3 = { th = "ขอหลอดนึงใส่แกลลอน มอไซค์ลูกชายน้ำมันหมดกลางทาง", en = "One cylinder in the jug. My son's bike ran out on the road." },
	Walker_Order_4 = { th = "เติมใส่แกลลอนหน่อย พรุ่งนี้จะตัดหญ้าหน้าบ้านแต่เช้า", en = "Fill the jug, please. I'm mowing the yard first thing tomorrow." },
	Walker_Order_Rain_1 = { th = "ฝนตกไฟดับทั้งหมู่บ้านเลย ขอซื้อไปเติมเครื่องปั่นไฟหน่อย", en = "The rain knocked out power in the whole village. I need fuel for the generator." },
	Walker_Order_Rain_2 = { th = "รถจอดเสียอยู่ข้างทาง ฝนก็ตก ขอแกลลอนนึงไปเติมหน่อยนะ", en = "My car stalled down the road in this rain. One jug, please." },
	Anomaly_NoUmbrella = { th = "ฝนตกเหรอ... ไม่เห็นรู้สึกอะไรเลย... เติมให้หน่อยสิ", en = "Is it raining?... I can't feel a thing... fill it for me." },

	-- ---------------- ฝนตก
	RainTalk_1 = { th = "ฝนตกหนักจริงๆ เปียกไปหมดเลย", en = "This rain is something else. I'm soaked." },
	RainTalk_2 = { th = "ถนนลื่นมากเลยคืนนี้ เกือบล้มแน่ะ", en = "The road's so slippery tonight. Nearly took a fall." },
	RainTalk_3 = { th = "ฟ้าร้องทีไร ไฟในหมู่บ้านดับทุกที", en = "Every time it thunders, the village loses power." },
	Ghost_RainTalk = { th = "ฝนเหรอ... ไม่เห็นรู้สึกเลย...", en = "Rain?... I don't feel any rain..." },

	-- ---------------- คนแวะหลบฝน
	Shelter_Ask = { th = "ขอหลบฝนตรงนี้หน่อยนะ ไม่ซื้ออะไรหรอก เดี๋ยวฝนหยุดก็ไป", en = "Mind if I wait out the rain here? I won't buy anything, I'll leave when it stops." },
	ShelterGhost_Ask = { th = "ขอยืนตรงนี้ด้วยคนนะ... ฝนแบบนี้ไม่รู้จะไปไหน...", en = "May I stand here too?... nowhere to go in rain like this..." },
	ShelterTalk_1 = { th = "ฝนแบบนี้ลูกค้าคงไม่ค่อยมาหรอกนะ", en = "Not many customers in weather like this, I bet." },
	ShelterTalk_2 = { th = "รู้ไหม ตรงหัวโค้งนั่นเมื่อก่อนเคยเป็นป่าช้าเก่า", en = "You know that bend up there used to be an old graveyard?" },
	ShelterTalk_3 = { th = "เถียงนากลางทุ่งนั่น คนแถวนี้ไม่มีใครกล้าเข้าไปตอนกลางคืนหรอก", en = "That hut in the field... nobody around here goes near it at night." },
	ShelterTalk_4 = { th = "ร้านนี้เปิดดึกทุกคืนเลยเหรอ ไม่กลัวเหรอ", en = "You stay open this late every night? Aren't you scared?" },
	ShelterTalk_5 = { th = "ถ้าเห็นใครมาเติมน้ำมันแต่ตัวไม่เปียกฝนเลยนะ... อย่าเติมให้ล่ะ", en = "If someone comes for fuel and isn't wet from the rain... don't serve them." },
	ShelterGhostTalk_1 = { th = "ฉันรอรถอยู่... รอมาหลายปีแล้ว...", en = "I'm waiting for a ride... I've been waiting for years..." },
	ShelterGhostTalk_2 = { th = "คืนนั้นก็ฝนตกแบบนี้แหละ... ถนนลื่นมาก...", en = "It rained just like this that night... the road was so slippery..." },
	ShelterGhostTalk_3 = { th = "เธอเห็นฉันด้วยเหรอ... ไม่ค่อยมีใครเห็นหรอกนะ...", en = "You can see me?... not many people can..." },
	Shelter_Leave = { th = "ฝนหยุดแล้ว ขอบใจนะที่ให้หลบ", en = "Rain's stopped. Thanks for letting me stay." },
	ShelterGhost_Leave = { th = "ฝนหยุดแล้ว... ฉันต้องไปแล้วล่ะ...", en = "The rain stopped... I have to go now..." },

	-- ---------------- คนหลบฝนคุยกับลูกค้า
	Shelter_ToCustomer_1 = { th = "ฝนหนักนะ ขับดีๆ ล่ะ ถนนลื่น", en = "Heavy rain. Ride carefully, the road's slick." },
	Shelter_ToCustomer_2 = { th = "อ้าว มาเติมน้ำมันตอนฝนตกแบบนี้เลยเหรอ", en = "Oh, out for fuel in this downpour?" },
	Chat_Reply_1 = { th = "ขอบใจนะ ต้องรีบกลับบ้านก่อนน้ำท่วมทาง", en = "Thanks. Need to get home before the road floods." },
	Chat_Reply_2 = { th = "นั่นสิ ถ้าน้ำมันไม่หมดก็ไม่ออกมาหรอก", en = "Right? Wouldn't be out if I hadn't run dry." },
	Ghost_ShortReply = { th = "...", en = "..." },
	Shelter_NoticeDry = { th = "เอ๊ะ... ฝนตกขนาดนี้ ทำไมตัวเขาไม่เปียกเลยล่ะ...", en = "Huh... in rain like this, how are they not wet at all..." },
	Ghost_DryReply = { th = "เปียก?... ไม่เคยเปียกหรอก...", en = "Wet?... I never get wet..." },
	ShelterGhost_ToCustomer = { th = "รีบกลับบ้านนะ... ก่อนจะเป็นเหมือนฉัน...", en = "Hurry home... before you end up like me..." },
	Chat_WhoTalking = { th = "หือ? เมื่อกี้ใครพูดน่ะ... ไม่เห็นมีใครยืนอยู่เลย", en = "Huh? Who said that?... there's nobody standing there." },

	-- ---------------- คันหลังในคิวแซว
	Queue_Chime = { th = "รีบๆ หน่อยนะ รอคิวอยู่ข้างหลังเนี่ย", en = "Hurry it up, I'm waiting back here." },
	Queue_ChimeGhost = { th = "ไม่ต้องรีบ... ข้ารอได้...", en = "No hurry... I can wait..." },

	-- ---------------- ลูกค้าเห็นคนพนมมือ (Prayer, 2026-10-28)
	Pray_Ask_1 = { th = "อ้าว พนมมือทำไมน่ะ?", en = "Huh? Why are your hands pressed together?" },
	Pray_Ask_2 = { th = "สวดมนต์อยู่เหรอ? ดึกป่านนี้แล้ว", en = "Are you praying? At this hour?" },
	Pray_Ask_3 = { th = "ขออะไรอยู่ล่ะนั่น?", en = "What are you praying for?" },
	Pray_Ask_4 = { th = "เห็นอะไรเข้าเหรอ ถึงได้ยืนพนมมือแบบนั้น?", en = "Did you see something? Why are you praying like that?" },
	Pray_Reply_1 = { th = "ขอให้คืนนี้ขายดีๆ หน่อย", en = "Just praying for good sales tonight." },
	Pray_Reply_2 = { th = "ขอให้คืนนี้ไม่เจออะไรแปลกๆ", en = "Praying nothing weird shows up tonight." },
	Pray_Reply_3 = { th = "ไหว้เจ้าที่ไว้ก่อน เดี๋ยวท่านงอน", en = "Paying respect to the land spirit. Don't want to upset it." },
	Pray_Reply_4 = { th = "นะโม ตัสสะ... เอ่อ เปล่าๆ ไม่มีอะไร", en = "Namo tassa... uh, nothing, never mind." },
	Pray_After_1 = { th = "ดีๆ ไหว้ไว้ก่อน แถวนี้มันเฮี้ยนจริง", en = "Good idea. This place really is haunted." },
	Pray_After_2 = { th = "ฮ่าๆ ขอเผื่อกันด้วยนะ", en = "Haha, say one for me too." },
	Pray_Ghost_1 = { th = "...หยุดสวดเดี๋ยวนี้", en = "...Stop praying. Now." },
	Pray_Ghost_2 = { th = "สวดไปก็ไม่ช่วยอะไรหรอก...", en = "Praying won't help you..." },
	Pray_Ghost_3 = { th = "เอามือลงเถอะ... มองข้าตรงๆ สิ", en = "Put your hands down... look at me properly." },
	Pray_GhostAfter_1 = { th = "...ข้าได้ยินนะ ทุกคำเลย", en = "...I heard that. Every word." },
	Pray_GhostAfter_2 = { th = "เสียงสวดมันแสบหู... แสบหูเหลือเกิน", en = "That chanting burns... it burns my ears." },
	-- สวดตอนร้านว่าง แล้วมีอะไรตอบรับ
	Pray_Summon_1 = { th = "...ใครเรียก...", en = "...who called me..." },
	Pray_Summon_2 = { th = "...ได้ยินแล้ว... กำลังไป...", en = "...I heard you... I'm coming..." },
	Pray_Summon_3 = { th = "...สวดให้ข้าเหรอ...", en = "...are you praying for me..." },
}

-- ชื่อลูกค้า (แสดงบนหัวกล่องคำพูด จะได้จำกันได้ ผีก็ปลอมใช้ชื่อเดียวกัน)
LanguageModule.Names = {
	Name_Sommai = { th = "ลุงสมหมาย", en = "Uncle Sommai" },
	Name_Chaem = { th = "ป้าแช่ม", en = "Auntie Chaem" },
	Name_Ton = { th = "น้องต้น", en = "Ton" },
	Name_Boonmee = { th = "พี่บุญมี", en = "Boonmee" },
	-- คนแวะหลบฝน
	Name_Prik = { th = "ยายปริก", en = "Grandma Prik" },
	Name_Daeng = { th = "พี่แดง", en = "Daeng" },
	Name_Noi = { th = "น้าน้อย", en = "Auntie Noi" },
	-- ขาจร
	Name_Racer = { th = "เด็กแว้น", en = "Racer kid" },
	Name_PartyDriver = { th = "คนขับรถซิ่ง", en = "Party truck driver" },
	Name_Teen = { th = "วัยรุ่น", en = "Teen" },
	Name_Coyote = { th = "สาวโคโยตี้", en = "Coyote girl" },
	Name_ParadeHost = { th = "เจ้าภาพงานบวช", en = "Ordination host" },
	Name_ParadeCrowd = { th = "ขบวนแห่", en = "Parade crowd" },
}

function LanguageModule.GetName(key: string, localeId: string?): string
	local entry = LanguageModule.Names[key]
	if not entry then
		return key
	end
	return if LanguageModule.Normalize(localeId) == "th" then entry.th else entry.en
end

-- ข้อความหน้าจอ (HUD)
LanguageModule.UI = {
	Money = { th = "เงินในกระป๋อง", en = "Money Tin" },
	Incense = { th = "ธูปศาลพระภูมิ", en = "Shrine Incense" },
	Win = { th = "เก็บเงินครบโควตาแล้ว! ปิดร้านกลับบ้านได้ รอดไปอีกคืน", en = "Quota reached! You survived the night." },
	Lose = { th = "ธูปดับหมดแล้ว... ศาลพระภูมิคุ้มครองไม่ไหวอีกต่อไป", en = "All the incense is out... the shrine can no longer protect you." },
	Jumpscare = { th = "คุณเติมน้ำมันให้ผี!", en = "You fueled a ghost!" },
	JumpscareChased = { th = "อย่าตามผีไป!", en = "Never follow a ghost!" },
	NewNight = { th = "คืนใหม่เริ่มแล้ว... ระวังลูกค้าแปลกๆ", en = "A new night begins... beware of strange customers." },
	-- ปุ่ม ProximityPrompt (Client เปลี่ยนข้อความเองตามภาษาของผู้เล่น)
	FillUp = { th = "เติมน้ำมัน", en = "Fill Up" },
	GasPump = { th = "ตู้ปั๊มหลอด", en = "Gas Pump" },
	CloseShop = { th = "ปิดร้าน!", en = "Close Shop!" },
	ShutterRope = { th = "เชือกแผงสังกะสี", en = "Shutter Rope" },
	-- ปุ่มสลับภาษา (แสดงภาษาที่ใช้อยู่)
	LangButton = { th = "🌐 ไทย", en = "🌐 EN" },
	-- หน้าตั้งค่า
	Settings = { th = "ตั้งค่า", en = "Settings" },
	Language = { th = "ภาษา", en = "Language" },
	LangThai = { th = "ไทย", en = "ไทย" },
	LangEnglish = { th = "English", en = "English" },
	MusicVolume = { th = "เสียงเพลง", en = "Music" },
	SfxVolume = { th = "เสียงเอฟเฟกต์", en = "Sound Effects" },
	ShowHUD = { th = "แสดงเงิน / ธูป / ปุ่ม", en = "Show money / incense / keys" },
	ShowLabels = { th = "แสดงป้ายชื่อวัตถุ", en = "Show object labels" },
	On = { th = "เปิด", en = "On" },
	Off = { th = "ปิด", en = "Off" },
	Close = { th = "ปิด", en = "Close" },
	-- กล่องคำพูด + แถบปุ่มคีย์ล่างจอ
	Customer = { th = "ลูกค้า", en = "Customer" },
	KeyClick = { th = "คลิก", en = "Click" },
	HintFlashlight = { th = "เปิด/ปิดไฟฉาย", en = "Flashlight" },
	HintHold = { th = "กดค้าง เติมน้ำมัน / เติมลม / ปิดร้าน", en = "Hold: Fuel / Air / Close Shop" },
	-- พนมมือ (PrayerController)
	HintPray = { th = "กดค้าง พนมมือ (เห็นผี)", en = "Hold: Pray (see ghosts)" },
	PrayChanting = { th = "🙏 นะโม ตัสสะ ภะคะวะโต...", en = "🙏 Namo tassa bhagavato..." },
	WhisperSpeaker = { th = "เสียงกระซิบ... (ไม่ใช่ลูกค้า)", en = "A whisper... (not a customer)" },
	PraySightOpen = { th = "👁 ตาทิพย์เปิดแล้ว — มองหาสิ่งผิดปกติ", en = "👁 Spirit sight open — look for anything wrong" },
	-- ตอบราคา (ใครตอบก่อนได้ก่อน)
	ReplyTitle = { th = "ตอบลูกค้า (ใครตอบก่อนได้ก่อน)", en = "Reply (first answer counts)" },
	Reply_80 = { th = "80 บาท", en = "80 Baht" },
	Reply_100 = { th = "100 บาท", en = "100 Baht" },
	Reply_120 = { th = "120 บาท", en = "120 Baht" },
	Reply_250 = { th = "250 บาท", en = "250 Baht" },
	Reply_300 = { th = "300 บาท", en = "300 Baht" },
	Reply_350 = { th = "350 บาท", en = "350 Baht" },
	Reply_10 = { th = "10 บาท", en = "10 Baht" },
	Reply_20 = { th = "20 บาท", en = "20 Baht" },
	Reply_30 = { th = "30 บาท", en = "30 Baht" },
	FillDiesel = { th = "เติมดีเซล", en = "Fill Diesel" },
	DieselPump = { th = "ตู้ดีเซล", en = "Diesel Pump" },
	PumpAir = { th = "เติมลม", en = "Pump Air" },
	AirCompressorName = { th = "ถังลม", en = "Air Compressor" },
	Reply_Hello = { th = "สวัสดี รับอะไรดี", en = "Hi, what can I get you?" },
	Reply_GreetBoth = { th = "สวัสดีทั้งสองคน", en = "Evening, you two" },
	-- เปิดร้านก่อนเริ่มคืน
	OpenShop = { th = "เปิดร้าน", en = "Open Shop" },
	-- สมุดบันทึกผี
	BookButton = { th = "สมุดผี", en = "Ghost Book" },
	BookTitle = { th = "สมุดบันทึกผีไทย", en = "Thai Ghost Journal" },
	BookCount = { th = "เจอแล้ว {n} / {total}", en = "Found {n} / {total}" },
	BookLockedName = { th = "???", en = "???" },
	BookLockedHint = { th = "ยังไม่เคยรอดจากผีตัวนี้", en = "You have not survived this one yet." },
	BookSurvived = { th = "รอดมาแล้ว {n} ครั้ง", en = "Survived {n} times" },
	BookNew = { th = "บันทึกผีใหม่ลงสมุด", en = "New journal entry" },
	-- จอตาย (แพ้)
	AskRestart = { th = "เริ่มคืนใหม่ไหม?", en = "Start a new night?" },
	Restart = { th = "เริ่มใหม่", en = "Restart" },
	Quit = { th = "🏯 กลับ Lobby", en = "🏯 Back to Lobby" },
	GoingToLobby = { th = "กำลังกลับวัด...", en = "Heading back to the temple..." },
	RestartBy = { th = "{name} เลือกเริ่มใหม่...", en = "{name} chose to restart..." },
	WaitOpen = { th = "ร้านยังปิดอยู่... ไปดึงเชือกเปิดแผงสังกะสีเพื่อเริ่มคืนนี้", en = "The shop is closed... pull the shutter rope to begin the night." },
}

-- ป้ายชื่อที่ลอยตามวัตถุในฉาก (ObjectLabels.client) ชื่อสั้น สุภาพ ไม่อธิบาย
LanguageModule.Labels = {
	GasPump = { th = "ตู้ปั๊มน้ำมัน", en = "Gas Pump" },
	DieselPump = { th = "ตู้ดีเซล", en = "Diesel Pump" },
	Radio = { th = "วิทยุ", en = "Radio" },
	CutoutSwitch = { th = "สะพานไฟ", en = "Breaker Switch" },
	RejectRope = { th = "เชือกแผงปิดร้าน", en = "Shutter Rope" },
	MoneyTin = { th = "กระป๋องเก็บเงิน", en = "Money Tin" },
	Generator = { th = "เครื่องปั่นไฟ", en = "Generator" },
	AirCompressor = { th = "ถังลม", en = "Air Compressor" },
	SpiritHouse = { th = "ศาลพระภูมิ", en = "Spirit House" },
	KilometerMilestone = { th = "หลักกิโลเมตรที่ 4", en = "Kilometer 4" },
	DistantRiceHut = { th = "เถียงนา", en = "Field Hut" },
	MarbleBench = { th = "ม้าหินอ่อน", en = "Marble Bench" },
	BanyanTree = { th = "ต้นไทร", en = "Banyan Tree" },
	IceBox = { th = "ถังน้ำแข็ง", en = "Ice Box" },
	Outhouse = { th = "ห้องน้ำ", en = "Outhouse" },
	Mirror = { th = "กระจก", en = "Mirror" },
	OwnerPhoto = { th = "รูปเจ้าของร้าน", en = "Owner's Photo" },
	Scarecrow = { th = "หุ่นไล่กา", en = "Scarecrow" },
}

function LanguageModule.GetLabel(key: string, localeId: string?): string
	local entry = LanguageModule.Labels[key]
	if not entry then
		return ""
	end
	return if LanguageModule.Normalize(localeId) == "th" then entry.th else entry.en
end

-- สมุดบันทึกผีไทย (Phase 5 ข้อ 2): ชื่อ + คำใบ้วิธีสังเกต เรียงตาม BookOrder
LanguageModule.BookOrder = {
	"Anomaly_Headless",
	"Anomaly_Cemetery",
	"Anomaly_WheelHair",
	"Anomaly_NeckTwist",
	"Anomaly_CreepySmile",
	"Anomaly_Krasue",
	"Anomaly_MonkRadio",
	"Anomaly_Tani",
	"Anomaly_Scarecrow",
	"Anomaly_BloodFuel",
	"Anomaly_NoUmbrella",
}
LanguageModule.Book = {
	Anomaly_Headless = {
		th = { "ผีหัวขาดซ้อนท้าย", "มีคนซ้อนท้ายแต่ไม่มีหัว คนขับไม่รู้ตัวเลย ลองทักว่า \"ทั้งสองคน\" ดู" },
		en = { "Headless Pillion Rider", "Someone rides pillion with no head. The driver has no idea. Try greeting \"you two\"." },
	},
	Anomaly_Cemetery = {
		th = { "ป้ายทะเบียนป่าช้า", "ป้ายทะเบียน 4444 จดทะเบียนจากป่าช้า ส่องไฟฉายดูป้ายก่อนเติม" },
		en = { "Cemetery Plate", "Plate 4444, registered to the cemetery. Check the plate with your flashlight." },
	},
	Anomaly_WheelHair = {
		th = { "ผมพันล้อ", "เส้นผมยาวสีดำพันล้อแน่น ลูกค้าบ่นว่าล้อหนักเหมือนมีใครดึง" },
		en = { "Hair in the Wheels", "Long black hair wound tight around the wheels. The rider says something is pulling them." },
	},
	Anomaly_NeckTwist = {
		th = { "คอหัก 180 องศา", "หัวคนขับหันกลับหลัง แต่ยังพูดคุยเหมือนปกติ" },
		en = { "Twisted Neck", "The driver's head faces backward, yet they talk as if nothing is wrong." },
	},
	Anomaly_CreepySmile = {
		th = { "ยิ้มฉีกถึงหู", "ตาโปน ยิ้มกว้างผิดธรรมชาติ แล้วขอให้คุณยิ้มตอบ" },
		en = { "Ear-to-Ear Grin", "Bulging eyes and an unnatural grin that asks you to smile back." },
	},
	Anomaly_Krasue = {
		th = { "กระสือ", "ไม่มีขา มีไส้ห้อยเรืองแสงอยู่ใต้ตัว และหิวเสมอ" },
		en = { "Krasue", "No legs, glowing entrails hanging beneath, and always hungry." },
	},
	Anomaly_MonkRadio = {
		th = { "วิทยุสวดศพ", "วิทยุในร้านเปลี่ยนเป็นเสียงพระสวดเอง แต่ลูกค้ากลับชมว่าเพลงเพราะ" },
		en = { "Funeral Radio", "The shop radio switches to funeral chanting by itself, yet the customer praises the song." },
	},
	Anomaly_Tani = {
		th = { "ผีตานี", "ผู้หญิงยืนรออยู่หลังกอกล้วย ลูกค้าถามว่าเธอรอใครอยู่" },
		en = { "Phi Tani", "A woman waits behind the banana grove. The customer asks who she is waiting for." },
	},
	Anomaly_Scarecrow = {
		th = { "หุ่นไล่กาเดินได้", "หุ่นไล่กาย้ายมายืนใกล้ร้าน ตาแดงเรือง ลูกค้าบอกว่ามันเดินตามมา" },
		en = { "Wandering Scarecrow", "The scarecrow now stands near the shop, eyes glowing red. The customer says it followed them." },
	},
	Anomaly_BloodFuel = {
		th = { "น้ำมันเลือด", "น้ำมันในหลอดแก้วกลายเป็นสีเลือด ลูกค้าบอกว่าหอมดี" },
		en = { "Blood Fuel", "The fuel in the glass turns blood red. The customer says it smells good." },
	},
	Anomaly_NoUmbrella = {
		th = { "คนตัวแห้งกลางฝน", "เดินฝ่าฝนหนักมาโดยไม่กางร่ม แต่ตัวแห้งสนิท" },
		en = { "Dry in the Rain", "Walks in through the downpour without an umbrella, yet completely dry." },
	},
}

-- คืน (ชื่อ, คำอธิบาย) ของผีในสมุด
function LanguageModule.GetBook(key: string, localeId: string?): (string, string)
	local entry = LanguageModule.Book[key]
	if not entry then
		return key, ""
	end
	local t = if LanguageModule.Normalize(localeId) == "th" then entry.th else entry.en
	return t[1], t[2]
end

-- ภาษาที่รองรับมีแค่ "th" กับ "en" (ค่าอื่น / nil = "en")
function LanguageModule.Normalize(lang: string?): string
	if lang and string.sub(string.lower(lang), 1, 2) == "th" then
		return "th"
	end
	return "en"
end

function LanguageModule.GetUI(key: string, localeId: string?): string
	local entry = LanguageModule.UI[key]
	if not entry then
		return key
	end
	if LanguageModule.Normalize(localeId) == "th" then
		return entry.th
	end
	return entry.en
end

-- vars = { amount = 100 } แทนที่ {amount} ในประโยค
function LanguageModule.GetText(key: string, localeId: string?, vars: { [string]: any }?): string
	local entry = LanguageModule.Dialogues[key]
	if not entry then
		return key
	end
	local s = if LanguageModule.Normalize(localeId) == "th" then entry.th else entry.en
	if vars then
		s = string.gsub(s, "{(%w+)}", function(k)
			local v = vars[k]
			return if v ~= nil then tostring(v) else nil
		end)
	end
	return s
end

return LanguageModule
