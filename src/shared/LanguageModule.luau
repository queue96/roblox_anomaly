-- LanguageModule.luau
-- ระบบเก็บข้อความหลายภาษาสำหรับคำพูดลูกค้า ชื่อผี และหน้าจอในเกม "ปั๊มหลอดท้ายทุ่ง"
--   ภาษาที่รองรับ: LanguageModule.Langs (th ไทย · en อังกฤษ · id อินโดนีเซีย · pt โปรตุเกส-บราซิล · es สเปน) ผู้ใช้ 2026-11-23
--   แต่ละข้อความ = { th = "...", en = "...", id = "...", pt = "...", es = "..." } ภาษาไหนยังไม่แปล = ใช้ภาษาอังกฤษแทน (Pick)
--   เพิ่มภาษาใหม่: ใส่รหัสใน Langs + ชื่อใน LangNames + ประเทศใน COUNTRY_LANG แล้วเติมคำแปลในแต่ละข้อความ

local LanguageModule = {}

-- รหัสภาษา (เรียงตามปุ่มเลือกภาษา) + ชื่อภาษาในภาษานั้นเอง (ปุ่มไม่ต้องแปล)
LanguageModule.Langs = { "th", "en", "id", "pt", "es" }
LanguageModule.LangNames = { th = "ไทย", en = "English", id = "Indonesia", pt = "Português", es = "Español" }
local SUPPORTED: { [string]: boolean } = {}
for _, l in ipairs(LanguageModule.Langs) do
	SUPPORTED[l] = true
end

LanguageModule.Dialogues = {
	Normal_Uncle = {
		th = "ไอ้หนู เติมเบนซินให้หลอดนึง ลุงจะรีบไปวิดน้ำเข้านา!",
		en = "Kid, fill up one cylinder for me. I need to pump water into my rice field!", es = "Muchacho, llénale un cilindro al tío. ¡Tengo que ir a bombear agua al arrozal!", pt = "Garoto, enche um cilindro pro tio. Preciso correr pra bombear água pro arrozal!", id = "Nak, isi satu tabung bensin buat Paman. Paman mau buru-buru pompa air ke sawah!",
	},
	Anomaly_Headless = {
		th = "พี่ชาย เติมน้ำมันให้เต็มหลอดเลยครับ ทำไมวันนี้รถผมมันหนักๆ ชอบกล...",
		en = "Bro, fill it to the top. Why does my bike feel so heavy tonight...", es = "Hermano, llénalo hasta arriba. ¿Por qué mi moto se siente tan pesada esta noche...?", pt = "Mano, enche até o topo. Por que minha moto tá tão pesada hoje...", id = "Bang, isi penuh ya. Kenapa motorku rasanya berat banget malam ini...",
	},
	Anomaly_Cemetery = {
		th = "เติมน้ำมันให้หน่อยจ้ะ... ทางข้างหน้ามืดเหลือเกิน...",
		en = "Please give me some fuel... the road ahead to the cemetery is so dark...", es = "Por favor, un poco de gasolina... el camino al cementerio está tan oscuro...", pt = "Por favor, um pouco de gasolina... a estrada até o cemitério tá tão escura...", id = "Tolong isi bensin... jalan ke kuburan di depan gelap sekali...",
	},
	Anomaly_Cremate = {
		th = "ขอน้ำมันเต็มหลอด... จะเอาไปราดเผาศพตัวเองที่เมรุหน่อยจ้ะ ฮ่าๆๆ",
		en = "Fill it up... I need gasoline to cremate my own corpse tonight! Hahaha!", es = "Llénalo... ¡necesito gasolina para cremar mi propio cadáver esta noche! ¡Jajaja!", pt = "Enche o tanque... preciso de gasolina pra cremar meu próprio cadáver hoje! Hahaha!", id = "Isi penuh... aku butuh bensin buat membakar mayatku sendiri malam ini! Hahaha!",
	},
	-- ลูกค้าปกติเพิ่ม (Phase 3)
	Normal_Aunt = {
		th = "เติมให้ป้าหน่อยลูก ป้าจะรีบไปตลาดเช้า",
		en = "Fill it up for auntie, dear. I'm heading to the morning market.", es = "Llénaselo a la tía, cariño. Voy al mercado de la mañana.", pt = "Enche pra tia, querido. Vou pra feira da manhã.", id = "Isi penuh buat Bibi ya, Nak. Bibi mau ke pasar pagi.",
	},
	Normal_Student = {
		th = "พี่ครับ เติมหลอดนึงครับ เดี๋ยวแม่ด่าว่ากลับดึก",
		en = "One cylinder please. My mom will scold me for coming home late.", es = "Un cilindro, por favor. Mi mamá me va a regañar si llego tarde.", pt = "Um cilindro, por favor. Minha mãe vai brigar se eu chegar tarde.", id = "Satu tabung ya. Nanti ibu marah kalau aku pulang telat.",
	},
	Normal_Farmer = {
		th = "เติมเต็มหลอดเลย พรุ่งนี้ต้องเอารถไปไถนาแต่เช้า",
		en = "Fill it up. I have to take the tiller to the field at dawn.", es = "Llénalo. Al amanecer tengo que llevar el motocultor al campo.", pt = "Enche o tanque. Tenho que levar o motocultivador pro campo de madrugada.", id = "Isi penuh. Subuh nanti aku harus bawa traktor tangan ke sawah.",
	},
	Anomaly_WheelHair = {
		th = "เติมน้ำมันให้หน่อย... ล้อมันหนักๆ เหมือนมีใครดึงไว้...",
		en = "Some fuel please... my wheels feel heavy, like someone is pulling them...", es = "Un poco de gasolina... mis ruedas se sienten pesadas, como si alguien las jalara...", pt = "Um pouco de gasolina... minhas rodas tão pesadas, como se alguém tivesse puxando...", id = "Isi bensin dong... rodaku rasanya berat, kayak ada yang menarik...",
	},
	-- ผีเพิ่ม (Phase 4: AnomalyManager)
	Anomaly_NeckTwist = {
		th = "เติมหลอดนึง... ข้างหลังผมมีอะไรเหรอ ทำไมมองไม่เห็นทางเลย...",
		en = "One cylinder... is something behind me? I can't see the road at all...", es = "Un cilindro... ¿hay algo detrás de mí? No veo nada del camino...", pt = "Um cilindro... tem alguma coisa atrás de mim? Não consigo ver a estrada...", id = "Satu tabung... ada sesuatu di belakangku? Aku sama sekali nggak bisa lihat jalan...",
	},
	Anomaly_CreepySmile = {
		th = "เติมน้ำมันให้หน่อยสิ... ยิ้มให้หน่อยก็ได้นะ หึหึหึ",
		en = "Fill it up for me... and give me a smile, won't you? Heh heh heh.", es = "Llénamelo... y regálame una sonrisa, ¿sí? Je je je.", pt = "Enche pra mim... e me dá um sorriso, vai? He he he.", id = "Isi penuh buatku... dan senyum dong, ya? He he he.",
	},
	Anomaly_MonkRadio = {
		th = "เติมหลอดนึงครับ... วิทยุร้านนี้เปิดเพลงเพราะดีนะ...",
		en = "One cylinder please... nice song on your radio tonight...", es = "Un cilindro, por favor... qué bonita canción en tu radio esta noche...", pt = "Um cilindro, por favor... que música bonita no seu rádio hoje...", id = "Satu tabung ya... lagu di radiomu malam ini enak...",
	},
	Anomaly_Tani = {
		th = "เติมน้ำมันให้หน่อย... ผู้หญิงตรงกอกล้วยนั่นเขารอใครอยู่เหรอ...",
		en = "Some fuel please... who is that woman waiting by the banana grove...", es = "Un poco de gasolina... ¿quién es esa mujer que espera junto al platanal...?", pt = "Um pouco de gasolina... quem é aquela mulher esperando perto do bananal...", id = "Isi bensin ya... perempuan yang menunggu di dekat kebun pisang itu siapa...",
	},
	Anomaly_Scarecrow = {
		th = "เติมเต็มหลอดเลย... หุ่นไล่กาตัวนั้นมันเดินตามผมมาตั้งแต่หัวทุ่ง...",
		en = "Fill it up... that scarecrow has been following me since the edge of the field...", es = "Llénalo... ese espantapájaros me viene siguiendo desde la orilla del campo...", pt = "Enche o tanque... aquele espantalho tá me seguindo desde a beira do campo...", id = "Isi penuh... orang-orangan sawah itu mengikutiku sejak ujung sawah...",
	},
	Anomaly_BloodFuel = {
		th = "เติมน้ำมันสีแดงๆ นั่นให้หน่อย... หอมดีจัง...",
		en = "Fill me up with that red stuff... it smells so good...", es = "Lléname con esa cosa roja... huele tan bien...", pt = "Me enche com esse negócio vermelho... o cheiro é tão bom...", id = "Isi aku dengan cairan merah itu... baunya enak sekali...",
	},

	-- ---------------- บทสนทนาลูกค้า (Phase 4+) ใส่ {amount} = จำนวนเงิน
	-- ทักทาย (ผีที่ปลอมตัวมาก็ใช้คำทักของคนที่มันปลอม)
	Greet_Uncle = { th = "เออ หลาน ยังไม่ปิดร้านอีกเหรอ ดึกแล้วนะ", en = "Evening, kid. Still open this late?", es = "Buenas noches, muchacho. ¿Todavía abierto a esta hora?", pt = "Boa noite, garoto. Ainda aberto a essa hora?", id = "Malam, Nak. Masih buka jam segini?" },
	Greet_Aunt = { th = "สวัสดีจ้ะลูก คืนนี้หนาวจังเลยนะ", en = "Hello, dear. Chilly night, isn't it?", es = "Hola, cariño. Qué noche tan fría, ¿no?", pt = "Olá, querido. Noite fria, né?", id = "Halo, Nak. Malamnya dingin, ya?" },
	Greet_Student = { th = "สวัสดีครับพี่ ยังเปิดอยู่ใช่ไหมครับ", en = "Hi! You're still open, right?", es = "¡Hola! Todavía están abiertos, ¿verdad?", pt = "Oi! Vocês ainda tão abertos, né?", id = "Hai! Masih buka, kan?" },
	Greet_Farmer = { th = "ไง น้อง ขอแวะเติมหน่อยนะ", en = "Hey there. Mind if I fill up?", es = "Hola. ¿Puedo cargar gasolina?", pt = "E aí. Posso abastecer?", id = "Halo. Boleh isi bensin?" },
	-- ถามราคา -> ผู้เล่นตอบ (ใครตอบก่อนได้ก่อน)
	AskPrice = { th = "คืนนี้หลอดละเท่าไหร่ล่ะ?", en = "How much for a cylinder tonight?", es = "¿Cuánto cuesta un cilindro esta noche?", pt = "Quanto tá o cilindro hoje?", id = "Malam ini berapa satu tabung?" },
	AskPriceDiesel = { th = "ดีเซลเต็มถังคืนนี้เท่าไหร่ล่ะ?", en = "How much for a full tank of diesel tonight?", es = "¿Cuánto cuesta el tanque lleno de diésel esta noche?", pt = "Quanto tá o tanque cheio de diesel hoje?", id = "Malam ini berapa isi penuh solar?" },
	AskPriceAir = { th = "เติมลมกี่บาทจ๊ะ?", en = "How much to pump up a tire?", es = "¿Cuánto por inflar una llanta?", pt = "Quanto é pra encher um pneu?", id = "Berapa buat pompa ban?" },
	-- รถยนต์ (ดีเซล ตู้ 2) / ตุ๊กตุ๊ก / จักรยานยางแบน
	Car_Order_1 = { th = "เติมดีเซลหน่อย พรุ่งนี้ต้องขับเข้าเมืองแต่เช้า", en = "Diesel, please. I'm driving into town early tomorrow.", es = "Diésel, por favor. Mañana temprano voy a la ciudad.", pt = "Diesel, por favor. Vou pra cidade cedinho amanhã.", id = "Solar, ya. Besok pagi-pagi aku mau ke kota." },
	Car_Order_2 = { th = "ขอดีเซลเต็มถัง ขนผักไปส่งตลาดไทอีกรอบ", en = "Fill her up with diesel. One more vegetable run to the market.", es = "Llénalo de diésel. Un viaje más de verduras al mercado.", pt = "Completa com diesel. Mais uma viagem de verdura pra feira.", id = "Isi penuh solar. Sekali lagi antar sayur ke pasar." },
	Car_Order_3 = { th = "เติมดีเซลให้หน่อย ปั๊มใหญ่ในเมืองปิดหมดแล้ว", en = "Diesel, please. All the big stations in town are closed.", es = "Diésel, por favor. Todas las gasolineras grandes de la ciudad están cerradas.", pt = "Diesel, por favor. Os postos grandes da cidade tão todos fechados.", id = "Solar, ya. Pom bensin besar di kota tutup semua." },
	TukTuk_Order_1 = { th = "เติมหลอดนึง พรุ่งนี้ต้องวิ่งรับนักท่องเที่ยวแต่เช้า", en = "One cylinder. I'm picking up tourists first thing tomorrow.", es = "Un cilindro. Mañana temprano recojo turistas.", pt = "Um cilindro. Vou buscar turistas logo cedo amanhã.", id = "Satu tabung. Besok pagi aku jemput turis." },
	TukTuk_Order_2 = { th = "เติมเบนซินหลอดนึง ตุ๊กตุ๊กคันนี้กินน้ำมันจริงๆ", en = "One cylinder of petrol. This tuk-tuk drinks fuel like water.", es = "Un cilindro de gasolina. Este tuk-tuk se bebe la gasolina como agua.", pt = "Um cilindro de gasolina. Esse tuk-tuk bebe gasolina que nem água.", id = "Satu tabung bensin. Tuk-tuk ini minum bensin kayak minum air." },
	Bicycle_Order_1 = { th = "ยางแบนกลางทาง ขอเติมลมหน่อยนะ เข็นมาตั้งไกล", en = "Got a flat on the way. Could you pump it up? I pushed it all the way here.", es = "Se me ponchó en el camino. ¿Me la inflas? La vine empujando hasta aquí.", pt = "Furou no caminho. Dá pra encher? Empurrei até aqui.", id = "Bannya kempes di jalan. Bisa tolong dipompa? Aku dorong sampai sini." },
	Bicycle_Order_2 = { th = "ขอเติมลมยางจักรยานหน่อย พรุ่งนี้ต้องปั่นไปโรงเรียน", en = "Can I get some air in my tire? I ride to school tomorrow.", es = "¿Me pones aire en la llanta? Mañana voy en bici a la escuela.", pt = "Pode colocar ar no meu pneu? Amanhã vou de bicicleta pra escola.", id = "Boleh isi angin ban? Besok aku naik sepeda ke sekolah." },
	-- เติมผิดตู้
	Wrong_NeedDiesel = { th = "เดี๋ยวๆ! รถผมใช้ดีเซลนะ ตู้นั้นมันเบนซิน!", en = "Wait! My car takes diesel, that's the petrol pump!", es = "¡Espera! Mi carro es de diésel, ¡esa es la bomba de gasolina!", pt = "Espera! Meu carro é a diesel, essa é a bomba de gasolina!", id = "Tunggu! Mobilku pakai solar, itu pompa bensin!" },
	Wrong_NeedPetrol = { th = "นั่นมันดีเซล! รถฉันใช้เบนซินนะ", en = "That's diesel! I need petrol from the petrol pump.", es = "¡Eso es diésel! Necesito gasolina de la bomba de gasolina.", pt = "Isso é diesel! Eu preciso de gasolina da bomba de gasolina.", id = "Itu solar! Aku butuh bensin dari pompa bensin." },
	Wrong_NeedAir = { th = "ไม่ได้มาเติมน้ำมัน มาเติมลมยางจ้ะ!", en = "I'm not here for fuel, I just need air in my tire!", es = "¡No vine por gasolina, solo necesito aire en la llanta!", pt = "Não vim por gasolina, só preciso de ar no pneu!", id = "Aku nggak beli bensin, cuma mau isi angin ban!" },
	Wrong_NeedFuel = { th = "ลมยางยังดีอยู่ เติมน้ำมันให้หน่อยสิ", en = "My tires are fine. I need fuel.", es = "Mis llantas están bien. Necesito gasolina.", pt = "Meus pneus tão bons. Preciso de gasolina.", id = "Banku baik-baik saja. Aku butuh bensin." },
	-- ลูกค้าพูดตอนแผงร้านเปิด / ปิดต่อหน้า
	Shutter_Open_1 = { th = "นึกว่าจะไม่ขายซะแล้ว", en = "Thought you weren't selling anymore.", es = "Pensé que ya no estabas vendiendo.", pt = "Achei que você não tava mais vendendo.", id = "Kirain sudah nggak jualan." },
	Shutter_Open_2 = { th = "ตกใจหมด นึกว่าแผงหล่นใส่", en = "You scared me, thought the shutter was falling on me.", es = "Qué susto, pensé que la cortina se me venía encima.", pt = "Que susto, achei que o portão ia cair em mim.", id = "Kaget aku, kirain pintu sengnya jatuh menimpaku." },
	Shutter_Open_3 = { th = "ฮ่าๆ แผงมันฝืดเหรอช่าง?", en = "Haha, is the shutter stuck?", es = "Jaja, ¿se atoró la cortina?", pt = "Haha, o portão emperrou?", id = "Haha, pintu sengnya macet, ya?" },
	Shutter_Closed_1 = { th = "เอ้า ปิดทำไม?", en = "Hey, why'd you close?", es = "Oye, ¿por qué cerraste?", pt = "Ei, por que fechou?", id = "Hei, kok ditutup?" },
	Shutter_Closed_2 = { th = "ฮัลโหล มีใครอยู่ไหม?", en = "Hello? Anyone there?", es = "¿Hola? ¿Hay alguien?", pt = "Alô? Tem alguém aí?", id = "Halo? Ada orang?" },
	Shutter_Closed_3 = { th = "เฮ้ย ปิดแผงทำไมเนี่ย?", en = "Hey, why close the shutter?", es = "Oye, ¿por qué bajas la cortina?", pt = "Ei, por que fechar o portão?", id = "Hei, kenapa pintu sengnya ditutup?" },
	-- ขาจรบนถนน (ไม่ได้มาใช้บริการ)
	Party_Line = { th = "ไปไหนกันจ๊ะคืนนี้ งานวัดบ้านโน้นยังไม่เลิกเลย ไปด้วยกันไหม!", en = "Where you headed tonight? The temple fair's still going, come along!", es = "¿A dónde vas esta noche? La feria del templo sigue, ¡vente con nosotros!", pt = "Pra onde você vai hoje? A festa do templo ainda tá rolando, vem com a gente!", id = "Mau ke mana malam ini? Pasar malam di kuil masih ramai, ayo ikut!" },
	Teen_Line = { th = "จัดไปพี่! เปิดดังๆ อีก!", en = "Let's go! Turn it up!", es = "¡Vamos! ¡Súbele al volumen!", pt = "Bora! Aumenta o som!", id = "Ayo! Kencangkan musiknya!" },
	Coyote_Line = { th = "หวัดดีจ้า แค่แวะทักเฉยๆ นะ ไม่ได้มาเติมน้ำมันหรอก", en = "Hi there! Just saying hello, we're not here for fuel.", es = "¡Hola! Solo pasamos a saludar, no venimos por gasolina.", pt = "Oi! Só passando pra dar oi, não viemos abastecer.", id = "Hai! Cuma mau menyapa, kami nggak beli bensin." },
	Parade_Invite = { th = "พรุ่งนี้บวชลูกชาย! แวะไปงานนะ มีข้าวต้มเลี้ยงทั้งคืนเลย!", en = "My son's ordination is tomorrow! Drop by, there's rice soup all night!", es = "¡Mañana es la ordenación de mi hijo! Date una vuelta, ¡hay sopa de arroz toda la noche!", pt = "Amanhã é a ordenação do meu filho! Aparece lá, tem sopa de arroz a noite toda!", id = "Besok anakku ditahbiskan jadi biksu! Mampir ya, ada bubur nasi semalaman!" },
	Parade_Cheer = { th = "โห่... ฮิ้ว!! โห่... ฮิ้ว!!", en = "Hooo... hiew!! Hooo... hiew!!", es = "¡Juuu... jiu!! ¡Juuu... jiu!!", pt = "Huuu... hiu!! Huuu... hiu!!", id = "Huuu... hiu!! Huuu... hiu!!" },
	Wrong_GiveUp = { th = "ทำผิดอยู่ได้... ไม่เอาแล้ว ไปปั๊มอื่นดีกว่า", en = "You keep getting it wrong... forget it, I'll go elsewhere.", es = "Te equivocas una y otra vez... olvídalo, voy a otro lado.", pt = "Você só erra... deixa pra lá, vou em outro lugar.", id = "Salah terus... sudahlah, aku cari tempat lain." },
	PlayerQuote = { th = "หลอดละ {amount} บาท", en = "{amount} baht a cylinder.", es = "{amount} baht el cilindro.", pt = "{amount} baht o cilindro.", id = "{amount} baht satu tabung." },
	-- ลูกค้ารับราคา
	Price_Cheap = { th = "โห {amount} บาทเองเหรอ ใจดีจริงๆ", en = "Only {amount} baht? That's kind of you.", es = "¿Solo {amount} baht? Qué amable.", pt = "Só {amount} baht? Que gentil.", id = "Cuma {amount} baht? Baik sekali." },
	Price_Normal = { th = "{amount} บาท ราคาเดิม โอเคเลย", en = "{amount} baht, same as usual. Okay.", es = "{amount} baht, como siempre. Va.", pt = "{amount} baht, como sempre. Beleza.", id = "{amount} baht, seperti biasa. Oke." },
	Price_ExpensiveOk = { th = "{amount}... แพงขึ้นอีกแล้วนะ เอาก็เอา", en = "{amount}? Pricier again... fine.", es = "¿{amount}? Subió otra vez... ni modo.", pt = "{amount}? Subiu de novo... tá bom.", id = "{amount}? Naik lagi... ya sudah." },
	Price_ExpensiveNo = { th = "{amount} บาท! แพงไป ไม่เติมดีกว่า", en = "{amount} baht?! Too much. I'll pass.", es = "¡¿{amount} baht?! Demasiado caro. Paso.", pt = "{amount} baht?! Caro demais. Vou passar.", id = "{amount} baht?! Kemahalan. Nggak jadi." },
	Price_Silent = { th = "ไม่ตอบเลย... งั้น {amount} บาทเหมือนเดิมนะ", en = "No answer... {amount} baht as usual, then.", es = "Nadie contesta... {amount} baht como siempre, entonces.", pt = "Nenhuma resposta... {amount} baht como sempre, então.", id = "Nggak dijawab... {amount} baht seperti biasa saja, ya." },
	-- จ่ายเงิน / ขอบคุณ
	Pay_1 = { th = "นี่ {amount} บาทนะ ขอบใจมาก", en = "Here's {amount} baht. Thanks a lot.", es = "Aquí tienes {amount} baht. Muchas gracias.", pt = "Aqui, {amount} baht. Muito obrigado.", id = "Ini {amount} baht. Terima kasih banyak." },
	Pay_2 = { th = "เอ้า {amount} บาท ไม่ต้องทอนนะ", en = "Here, {amount} baht. Keep the change.", es = "Toma, {amount} baht. Quédate con el cambio.", pt = "Toma, {amount} baht. Pode ficar com o troco.", id = "Ini, {amount} baht. Ambil saja kembaliannya." },
	Pay_3 = { th = "ขอบใจจ้ะ นี่ {amount} บาท พรุ่งนี้มาใหม่นะ", en = "Thank you. {amount} baht. See you tomorrow.", es = "Gracias. {amount} baht. Nos vemos mañana.", pt = "Obrigado. {amount} baht. Até amanhã.", id = "Terima kasih. {amount} baht. Sampai besok." },
	-- โดนปิดร้านใส่ (ลูกค้าปกติ)
	Rejected_1 = { th = "อ้าว! ปิดร้านใส่ทำไมเนี่ย!", en = "Hey! Why'd you shut the shop on me?!", es = "¡Oye! ¡¿Por qué me cerraste la tienda en la cara?!", pt = "Ei! Por que fechou a loja na minha cara?!", id = "Hei! Kenapa tokonya ditutup di depanku?!" },
	Rejected_2 = { th = "ไม่ขายก็ไม่ขาย... ไม่ต้องทำแบบนี้ก็ได้", en = "Fine, don't sell then... no need for that.", es = "Bueno, no vendas entonces... no era para tanto.", pt = "Tá, não vende então... não precisava disso.", id = "Ya sudah, nggak usah jual... nggak perlu begitu." },
	-- ไม่มีใครมาเติมให้
	NoOne_1 = { th = "มีใครอยู่ไหม... เงียบจัง ไปปั๊มอื่นละกัน", en = "Anyone here?... So quiet. I'll go elsewhere.", es = "¿Hay alguien?... Qué silencio. Voy a otro lado.", pt = "Tem alguém aqui?... Tão quieto. Vou em outro lugar.", id = "Ada orang?... Sepi sekali. Aku cari tempat lain." },
	NoOne_2 = { th = "ร้านเปิดแต่ไม่มีคน... แปลกจริง", en = "The shop's open but nobody's here... strange.", es = "La tienda está abierta pero no hay nadie... qué raro.", pt = "A loja tá aberta mas não tem ninguém... estranho.", id = "Tokonya buka tapi nggak ada orang... aneh." },
	-- ผี
	Ghost_Price = { th = "เท่าไหร่ก็ได้... เงินไม่สำคัญหรอก...", en = "Any price... money doesn't matter anymore...", es = "El precio que sea... el dinero ya no importa...", pt = "Qualquer preço... dinheiro não importa mais...", id = "Berapa saja... uang sudah tidak ada artinya lagi..." },
	Ghost_Pay = { th = "ขอบใจ... นี่เงิน... {amount} บาท... หึหึ", en = "Thank you... here's... {amount} baht... heh heh.", es = "Gracias... aquí tienes... {amount} baht... je je.", pt = "Obrigado... aqui... {amount} baht... he he.", id = "Terima kasih... ini... {amount} baht... he he." },
	Ghost_Chased = { th = "ตามมาทำไม... อยากไปด้วยกันเหรอ!!", en = "Why are you following me... want to come along?!", es = "¿Por qué me sigues...? ¡¿Quieres venir conmigo?!", pt = "Por que você tá me seguindo... quer vir junto?!", id = "Kenapa kamu mengikutiku... mau ikut denganku?!" },
	Ghost_Rejected = { th = "แก... รู้ได้ยังไง...", en = "You... how did you know...", es = "Tú... ¿cómo lo supiste...?", pt = "Você... como você sabia...", id = "Kamu... bagaimana kamu tahu..." },
	Ghost_NoOne = { th = "ไม่มีใครอยู่... งั้นเดี๋ยวกลับมาใหม่นะ...", en = "No one here... I'll come back later...", es = "No hay nadie... volveré más tarde...", pt = "Ninguém aqui... eu volto depois...", id = "Tidak ada orang... nanti aku kembali lagi..." },
	Ghost_Wait = { th = "ไม่ต้องรีบ... ข้ารอได้... รอได้นานเลย...", en = "No rush... I can wait... I can wait a long time...", es = "Sin prisa... puedo esperar... puedo esperar mucho tiempo...", pt = "Sem pressa... eu posso esperar... posso esperar muito tempo...", id = "Tidak usah buru-buru... aku bisa menunggu... menunggu lama sekali..." },
	Ghost_Wait2 = { th = "รอมานานแล้ว... นานกว่าที่เจ้าคิด...", en = "I've waited so long... longer than you think...", es = "He esperado tanto tiempo... más de lo que imaginas...", pt = "Esperei tanto tempo... mais do que você imagina...", id = "Aku sudah menunggu lama sekali... lebih lama dari yang kamu kira..." },
	-- ผู้เล่นทักทาย
	PlayerHello = { th = "สวัสดี รับอะไรดี", en = "Hi, what can I get you?", es = "Hola, ¿qué te sirvo?", pt = "Oi, o que vai ser?", id = "Hai, mau isi apa?" },
	PlayerGreetBoth = { th = "สวัสดีทั้งสองคนเลย", en = "Evening, you two!", es = "¡Buenas noches a los dos!", pt = "Boa noite, vocês dois!", id = "Malam, kalian berdua!" },
	-- "ฉันมาคนเดียว" (ทักทั้งสองคน)
	Alone_Normal = { th = "สองคน? ฉันมาคนเดียวนะ ง่วงแล้วมั้งเรา", en = "You two? I came alone. You must be sleepy.", es = "¿A los dos? Vine solo. Debes tener sueño.", pt = "Nós dois? Eu vim sozinho. Você deve tá com sono.", id = "Berdua? Aku datang sendiri. Kamu pasti ngantuk." },
	Alone_Ghost = { th = "พูดอะไรน่ะ... ฉันมาคนเดียวนะ... ทำไมหลังมันหนักๆ", en = "What are you talking about... I came alone... why does my back feel heavy...", es = "¿De qué hablas...? Vine solo... ¿por qué siento la espalda tan pesada...?", pt = "Do que você tá falando... eu vim sozinho... por que minhas costas tão tão pesadas...", id = "Ngomong apa kamu... aku datang sendiri... kenapa punggungku terasa berat..." },
	Alone_Creepy = { th = "คนเดียว... ตอนนี้ยังคนเดียว... หึ", en = "Alone... for now, alone... heh.", es = "Solo... por ahora, solo... je.", pt = "Sozinho... por enquanto, sozinho... he.", id = "Sendiri... untuk sekarang, sendiri... he." },
	Passenger_Whisper = { th = "ชู่ว... อย่าบอกเขานะ...", en = "Shh... don't tell him...", es = "Shh... no le digas...", pt = "Shh... não conta pra ele...", id = "Ssst... jangan bilang dia..." },
	-- รอนาน / เติมช้า
	Greet_Waited = { th = "รอตั้งนานแน่ะ... คืนนี้คนเยอะจังนะ", en = "Took forever... busy night, huh?", es = "Cuánto tardaste... ¿noche ocupada?", pt = "Demorou, hein... noite movimentada?", id = "Lama banget... ramai ya malam ini?" },
	Impatient_1 = { th = "เร็วๆ หน่อยได้ไหม รีบอยู่นะ", en = "Could you hurry up? I'm in a rush.", es = "¿Puedes apurarte? Tengo prisa.", pt = "Dá pra ser mais rápido? Tô com pressa.", id = "Bisa lebih cepat? Aku buru-buru." },
	Impatient_2 = { th = "ยังไม่เติมอีกเหรอ ยืนรอนานแล้วนะ", en = "Still not filling? I've been waiting a while.", es = "¿Todavía no lo llenas? Llevo rato esperando.", pt = "Ainda não encheu? Já tô esperando faz tempo.", id = "Belum diisi juga? Aku sudah menunggu dari tadi." },
	Impatient_3 = { th = "นี่จะเติมหรือไม่เติม! จะไปละนะ!", en = "Are you filling it or not?! I'm about to leave!", es = "¡¿Lo vas a llenar o no?! ¡Ya me voy!", pt = "Vai encher ou não?! Já tô indo embora!", id = "Mau diisi atau nggak?! Aku mau pergi nih!" },
	Pay_Slow = { th = "ช้าจริงๆ... ให้ {amount} บาทพอนะ", en = "So slow... {amount} baht is all you get.", es = "Qué lento... {amount} baht y ya.", pt = "Que demora... {amount} baht e olhe lá.", id = "Lambat sekali... {amount} baht saja, cukup." },

	-- ---------------- คนเดินมาซื้อน้ำมันใส่แกลลอน (บอกว่าจะเอาไปเติมอะไร)
	Walker_Order_1 = { th = "ขอซื้อใส่แกลลอนหน่อย รถไถจอดเสียอยู่ปากทาง น้ำมันหมดพอดี", en = "Fill this jug for me? My tractor ran dry at the end of the lane.", es = "¿Me llenas este bidón? Mi tractor se quedó seco al final del camino.", pt = "Enche esse galão pra mim? Meu trator secou no fim da estradinha.", id = "Tolong isi jeriken ini? Traktorku kehabisan bensin di ujung jalan." },
	Walker_Order_2 = { th = "เติมใส่แกลลอนให้หน่อย จะเอาไปเติมเครื่องสูบน้ำเข้านา", en = "Fill the jug, please. It's for the water pump in my field.", es = "Llena el bidón, por favor. Es para la bomba de agua de mi campo.", pt = "Enche o galão, por favor. É pra bomba d'água do meu campo.", id = "Isi jeriken ini, ya. Buat pompa air di sawahku." },
	Walker_Order_3 = { th = "ขอหลอดนึงใส่แกลลอน มอไซค์ลูกชายน้ำมันหมดกลางทาง", en = "One cylinder in the jug. My son's bike ran out on the road.", es = "Un cilindro en el bidón. La moto de mi hijo se quedó en el camino.", pt = "Um cilindro no galão. A moto do meu filho parou na estrada.", id = "Satu tabung ke jeriken. Motor anakku mogok di jalan." },
	Walker_Order_4 = { th = "เติมใส่แกลลอนหน่อย พรุ่งนี้จะตัดหญ้าหน้าบ้านแต่เช้า", en = "Fill the jug, please. I'm mowing the yard first thing tomorrow.", es = "Llena el bidón, por favor. Mañana temprano voy a cortar el pasto.", pt = "Enche o galão, por favor. Vou cortar a grama do quintal amanhã cedo.", id = "Isi jeriken ini, ya. Besok pagi aku mau potong rumput halaman." },
	Walker_Order_Rain_1 = { th = "ฝนตกไฟดับทั้งหมู่บ้านเลย ขอซื้อไปเติมเครื่องปั่นไฟหน่อย", en = "The rain knocked out power in the whole village. I need fuel for the generator.", es = "La lluvia dejó sin luz a todo el pueblo. Necesito gasolina para el generador.", pt = "A chuva derrubou a luz da vila inteira. Preciso de gasolina pro gerador.", id = "Hujan bikin listrik satu desa padam. Aku butuh bensin buat genset." },
	Walker_Order_Rain_2 = { th = "รถจอดเสียอยู่ข้างทาง ฝนก็ตก ขอแกลลอนนึงไปเติมหน่อยนะ", en = "My car stalled down the road in this rain. One jug, please.", es = "Mi carro se apagó en el camino con esta lluvia. Un bidón, por favor.", pt = "Meu carro morreu na estrada com essa chuva. Um galão, por favor.", id = "Mobilku mogok di jalan gara-gara hujan. Satu jeriken, ya." },
	Anomaly_NoUmbrella = { th = "ฝนตกเหรอ... ไม่เห็นรู้สึกอะไรเลย... เติมให้หน่อยสิ", en = "Is it raining?... I can't feel a thing... fill it for me.", es = "¿Está lloviendo?... no siento nada... llénamelo.", pt = "Tá chovendo?... não sinto nada... enche pra mim.", id = "Hujan ya?... aku tidak merasakan apa-apa... isi untukku." },

	-- ---------------- ฝนตก
	RainTalk_1 = { th = "ฝนตกหนักจริงๆ เปียกไปหมดเลย", en = "This rain is something else. I'm soaked.", es = "Qué lluvia tan fuerte. Estoy empapado.", pt = "Que chuva, hein. Tô encharcado.", id = "Hujannya parah. Aku basah kuyup." },
	RainTalk_2 = { th = "ถนนลื่นมากเลยคืนนี้ เกือบล้มแน่ะ", en = "The road's so slippery tonight. Nearly took a fall.", es = "El camino está muy resbaloso esta noche. Casi me caigo.", pt = "A estrada tá muito escorregadia hoje. Quase levei um tombo.", id = "Jalannya licin sekali malam ini. Hampir jatuh tadi." },
	RainTalk_3 = { th = "ฟ้าร้องทีไร ไฟในหมู่บ้านดับทุกที", en = "Every time it thunders, the village loses power.", es = "Cada vez que truena, el pueblo se queda sin luz.", pt = "Toda vez que troveja, a vila fica sem luz.", id = "Tiap kali ada petir, listrik desa langsung padam." },
	Ghost_RainTalk = { th = "ฝนเหรอ... ไม่เห็นรู้สึกเลย...", en = "Rain?... I don't feel any rain...", es = "¿Lluvia?... no siento ninguna lluvia...", pt = "Chuva?... não sinto chuva nenhuma...", id = "Hujan?... aku tidak merasakan hujan..." },

	-- ---------------- คนแวะหลบฝน
	Shelter_Ask = { th = "ขอหลบฝนตรงนี้หน่อยนะ ไม่ซื้ออะไรหรอก เดี๋ยวฝนหยุดก็ไป", en = "Mind if I wait out the rain here? I won't buy anything, I'll leave when it stops.", es = "¿Puedo esperar aquí a que pase la lluvia? No voy a comprar nada, me voy cuando pare.", pt = "Posso esperar a chuva passar aqui? Não vou comprar nada, vou embora quando parar.", id = "Boleh numpang berteduh di sini? Aku nggak beli apa-apa, nanti pergi kalau hujan reda." },
	ShelterGhost_Ask = { th = "ขอยืนตรงนี้ด้วยคนนะ... ฝนแบบนี้ไม่รู้จะไปไหน...", en = "May I stand here too?... nowhere to go in rain like this...", es = "¿Puedo quedarme aquí también?... no hay a dónde ir con esta lluvia...", pt = "Posso ficar aqui também?... não tem pra onde ir com uma chuva dessas...", id = "Boleh aku berdiri di sini juga?... tidak ada tempat lain saat hujan begini..." },
	ShelterTalk_1 = { th = "ฝนแบบนี้ลูกค้าคงไม่ค่อยมาหรอกนะ", en = "Not many customers in weather like this, I bet.", es = "Seguro no vienen muchos clientes con este clima.", pt = "Aposto que não aparece muito cliente com esse tempo.", id = "Pasti sepi pembeli kalau cuacanya begini." },
	ShelterTalk_2 = { th = "รู้ไหม ตรงหัวโค้งนั่นเมื่อก่อนเคยเป็นป่าช้าเก่า", en = "You know that bend up there used to be an old graveyard?", es = "¿Sabías que esa curva de allá era un cementerio viejo?", pt = "Sabia que aquela curva ali era um cemitério antigo?", id = "Tahu nggak, tikungan di depan itu dulu kuburan tua?" },
	ShelterTalk_3 = { th = "เถียงนากลางทุ่งนั่น คนแถวนี้ไม่มีใครกล้าเข้าไปตอนกลางคืนหรอก", en = "That hut in the field... nobody around here goes near it at night.", es = "Esa choza en el campo... nadie de aquí se acerca de noche.", pt = "Aquela cabana no campo... ninguém daqui chega perto dela de noite.", id = "Gubuk di tengah sawah itu... orang sini nggak ada yang berani mendekat malam-malam." },
	ShelterTalk_4 = { th = "ร้านนี้เปิดดึกทุกคืนเลยเหรอ ไม่กลัวเหรอ", en = "You stay open this late every night? Aren't you scared?", es = "¿Abres tan tarde todas las noches? ¿No te da miedo?", pt = "Você fica aberto até tarde assim toda noite? Não dá medo?", id = "Kamu buka selarut ini tiap malam? Nggak takut?" },
	ShelterTalk_5 = { th = "ถ้าเห็นใครมาเติมน้ำมันแต่ตัวไม่เปียกฝนเลยนะ... อย่าเติมให้ล่ะ", en = "If someone comes for fuel and isn't wet from the rain... don't serve them.", es = "Si alguien viene por gasolina y no está mojado por la lluvia... no lo atiendas.", pt = "Se alguém vier abastecer e não tiver molhado da chuva... não atende.", id = "Kalau ada yang datang beli bensin tapi nggak basah kena hujan... jangan dilayani." },
	ShelterGhostTalk_1 = { th = "ฉันรอรถอยู่... รอมาหลายปีแล้ว...", en = "I'm waiting for a ride... I've been waiting for years...", es = "Estoy esperando que me recojan... llevo años esperando...", pt = "Tô esperando uma carona... faz anos que eu espero...", id = "Aku menunggu jemputan... sudah bertahun-tahun aku menunggu..." },
	ShelterGhostTalk_2 = { th = "คืนนั้นก็ฝนตกแบบนี้แหละ... ถนนลื่นมาก...", en = "It rained just like this that night... the road was so slippery...", es = "Llovía así esa noche... el camino estaba tan resbaloso...", pt = "Chovia assim naquela noite... a estrada tava tão escorregadia...", id = "Malam itu juga hujan seperti ini... jalannya licin sekali..." },
	ShelterGhostTalk_3 = { th = "เธอเห็นฉันด้วยเหรอ... ไม่ค่อยมีใครเห็นหรอกนะ...", en = "You can see me?... not many people can...", es = "¿Puedes verme?... no mucha gente puede...", pt = "Você consegue me ver?... pouca gente consegue...", id = "Kamu bisa melihatku?... tidak banyak orang yang bisa..." },
	Shelter_Leave = { th = "ฝนหยุดแล้ว ขอบใจนะที่ให้หลบ", en = "Rain's stopped. Thanks for letting me stay.", es = "Ya paró la lluvia. Gracias por dejarme quedar.", pt = "A chuva parou. Valeu por me deixar ficar.", id = "Hujannya sudah reda. Terima kasih sudah boleh berteduh." },
	ShelterGhost_Leave = { th = "ฝนหยุดแล้ว... ฉันต้องไปแล้วล่ะ...", en = "The rain stopped... I have to go now...", es = "La lluvia paró... ya me tengo que ir...", pt = "A chuva parou... agora eu preciso ir...", id = "Hujannya sudah reda... aku harus pergi sekarang..." },

	-- ---------------- คนหลบฝนคุยกับลูกค้า
	Shelter_ToCustomer_1 = { th = "ฝนหนักนะ ขับดีๆ ล่ะ ถนนลื่น", en = "Heavy rain. Ride carefully, the road's slick.", es = "Llueve fuerte. Maneja con cuidado, el camino está resbaloso.", pt = "Chuva forte. Vai com cuidado, a estrada tá lisa.", id = "Hujannya deras. Hati-hati di jalan, licin." },
	Shelter_ToCustomer_2 = { th = "อ้าว มาเติมน้ำมันตอนฝนตกแบบนี้เลยเหรอ", en = "Oh, out for fuel in this downpour?", es = "Vaya, ¿saliste por gasolina con este aguacero?", pt = "Ué, saindo pra abastecer nesse temporal?", id = "Wah, cari bensin di tengah hujan deras begini?" },
	Chat_Reply_1 = { th = "ขอบใจนะ ต้องรีบกลับบ้านก่อนน้ำท่วมทาง", en = "Thanks. Need to get home before the road floods.", es = "Gracias. Tengo que llegar a casa antes de que se inunde el camino.", pt = "Valeu. Preciso chegar em casa antes da estrada alagar.", id = "Terima kasih. Harus pulang sebelum jalannya banjir." },
	Chat_Reply_2 = { th = "นั่นสิ ถ้าน้ำมันไม่หมดก็ไม่ออกมาหรอก", en = "Right? Wouldn't be out if I hadn't run dry.", es = "¿Verdad? Si no se me hubiera acabado, ni salía.", pt = "Né? Se a gasolina não tivesse acabado eu nem saía.", id = "Iya, kan? Kalau bensinnya nggak habis, aku nggak bakal keluar." },
	Ghost_ShortReply = { th = "...", en = "...", es = "...", pt = "...", id = "..." },
	Shelter_NoticeDry = { th = "เอ๊ะ... ฝนตกขนาดนี้ ทำไมตัวเขาไม่เปียกเลยล่ะ...", en = "Huh... in rain like this, how are they not wet at all...", es = "Eh... con esta lluvia, ¿cómo es que no está nada mojado...?", pt = "Ué... numa chuva dessas, como não tá nem um pouco molhado...", id = "Lho... hujan begini, kok dia sama sekali nggak basah..." },
	Ghost_DryReply = { th = "เปียก?... ไม่เคยเปียกหรอก...", en = "Wet?... I never get wet...", es = "¿Mojado?... yo nunca me mojo...", pt = "Molhado?... eu nunca me molho...", id = "Basah?... aku tidak pernah basah..." },
	ShelterGhost_ToCustomer = { th = "รีบกลับบ้านนะ... ก่อนจะเป็นเหมือนฉัน...", en = "Hurry home... before you end up like me...", es = "Vete rápido a casa... antes de que termines como yo...", pt = "Corre pra casa... antes que você acabe igual a mim...", id = "Cepat pulang... sebelum kamu jadi seperti aku..." },
	Chat_WhoTalking = { th = "หือ? เมื่อกี้ใครพูดน่ะ... ไม่เห็นมีใครยืนอยู่เลย", en = "Huh? Who said that?... there's nobody standing there.", es = "¿Eh? ¿Quién dijo eso?... no hay nadie parado ahí.", pt = "Hã? Quem falou isso?... não tem ninguém ali.", id = "Hah? Siapa yang ngomong?... nggak ada orang berdiri di situ." },

	-- ---------------- คันหลังในคิวแซว
	Queue_Chime = { th = "รีบๆ หน่อยนะ รอคิวอยู่ข้างหลังเนี่ย", en = "Hurry it up, I'm waiting back here.", es = "Apúrate, estoy esperando aquí atrás.", pt = "Anda logo, tô esperando aqui atrás.", id = "Cepat dong, aku menunggu di belakang." },
	Queue_ChimeGhost = { th = "ไม่ต้องรีบ... ข้ารอได้...", en = "No hurry... I can wait...", es = "Sin prisa... puedo esperar...", pt = "Sem pressa... eu posso esperar...", id = "Tidak usah buru-buru... aku bisa menunggu..." },

	-- ---------------- ลูกค้าเห็นคนพนมมือ (Prayer, 2026-10-28)
	Pray_Ask_1 = { th = "อ้าว พนมมือทำไมน่ะ?", en = "Huh? Why are your hands pressed together?", es = "¿Eh? ¿Por qué tienes las manos juntas?", pt = "Hã? Por que você tá com as mãos juntas?", id = "Hah? Kenapa tanganmu dirapatkan begitu?" },
	Pray_Ask_2 = { th = "สวดมนต์อยู่เหรอ? ดึกป่านนี้แล้ว", en = "Are you praying? At this hour?", es = "¿Estás rezando? ¿A esta hora?", pt = "Você tá rezando? A essa hora?", id = "Kamu lagi berdoa? Jam segini?" },
	Pray_Ask_3 = { th = "ขออะไรอยู่ล่ะนั่น?", en = "What are you praying for?", es = "¿Por qué estás rezando?", pt = "Tá rezando pelo quê?", id = "Kamu berdoa untuk apa?" },
	Pray_Ask_4 = { th = "เห็นอะไรเข้าเหรอ ถึงได้ยืนพนมมือแบบนั้น?", en = "Did you see something? Why are you praying like that?", es = "¿Viste algo? ¿Por qué rezas así?", pt = "Você viu alguma coisa? Por que tá rezando assim?", id = "Kamu lihat sesuatu? Kenapa berdoa begitu?" },
	Pray_After_1 = { th = "ดีๆ ไหว้ไว้ก่อน แถวนี้มันเฮี้ยนจริง", en = "Good idea. This place really is haunted.", es = "Buena idea. Este lugar sí que está embrujado.", pt = "Boa ideia. Esse lugar é mal-assombrado mesmo.", id = "Ide bagus. Tempat ini memang angker." },
	Pray_After_2 = { th = "ฮ่าๆ ขอเผื่อกันด้วยนะ", en = "Haha, say one for me too.", es = "Jaja, reza una por mí también.", pt = "Haha, reza uma por mim também.", id = "Haha, doakan aku juga, ya." },
	Pray_Ghost_1 = { th = "...หยุดสวดเดี๋ยวนี้", en = "...Stop praying. Now.", es = "...Deja de rezar. Ahora.", pt = "...Para de rezar. Agora.", id = "...Berhenti berdoa. Sekarang." },
	Pray_Ghost_2 = { th = "สวดไปก็ไม่ช่วยอะไรหรอก...", en = "Praying won't help you...", es = "Rezar no te va a salvar...", pt = "Rezar não vai te salvar...", id = "Berdoa tidak akan menolongmu..." },
	Pray_Ghost_3 = { th = "เอามือลงเถอะ... มองข้าตรงๆ สิ", en = "Put your hands down... look at me properly.", es = "Baja las manos... mírame bien.", pt = "Abaixa essas mãos... olha direito pra mim.", id = "Turunkan tanganmu... lihat aku baik-baik." },
	Pray_GhostAfter_1 = { th = "...ข้าได้ยินนะ ทุกคำเลย", en = "...I heard that. Every word.", es = "...Lo escuché. Cada palabra.", pt = "...Eu ouvi. Cada palavra.", id = "...Aku dengar. Setiap katanya." },
	Pray_GhostAfter_2 = { th = "เสียงสวดมันแสบหู... แสบหูเหลือเกิน", en = "That chanting burns... it burns my ears.", es = "Esa oración quema... me quema los oídos.", pt = "Essa reza queima... queima meus ouvidos.", id = "Doa itu membakar... membakar telingaku." },
	-- สวดตอนร้านว่าง แล้วมีอะไรตอบรับ
	Pray_Summon_1 = { th = "...ใครเรียก...", en = "...who called me...", es = "...¿quién me llamó...?", pt = "...quem me chamou...", id = "...siapa yang memanggilku..." },
	Pray_Summon_2 = { th = "...ได้ยินแล้ว... กำลังไป...", en = "...I heard you... I'm coming...", es = "...te escuché... ya voy...", pt = "...eu te ouvi... tô chegando...", id = "...aku dengar kamu... aku datang..." },
	Pray_Summon_3 = { th = "...สวดให้ข้าเหรอ...", en = "...are you praying for me...", es = "...¿estás rezando por mí...?", pt = "...você tá rezando por mim...", id = "...kamu berdoa untukku..." },
	-- คัทซีนเปิดคืน / จบคืน (พี่ชายเจ้าของร้าน)
	Intro_Brother_1 = { th = "คืนนี้เฝ้าร้านให้พี่หน่อยนะ พี่มีธุระในเมือง", en = "Mind the shop for me tonight, okay? I've got business in town.", es = "Cuida la tienda por mí esta noche, ¿va? Tengo asuntos en la ciudad.", pt = "Cuida da loja pra mim hoje, beleza? Tenho uns assuntos na cidade.", id = "Jaga toko malam ini ya? Aku ada urusan di kota." },
	Intro_Brother_2 = { th = "เปิดร้านให้แล้วนะ อย่าลืมเอาขนมไปถวายศาลพระภูมิล่ะ", en = "Shop's open. Don't forget to offer sweets at the spirit house.", es = "La tienda ya abrió. No olvides ofrecer dulces en la casa de los espíritus.", pt = "A loja tá aberta. Não esquece de oferecer doces na casa dos espíritos.", id = "Tokonya sudah buka. Jangan lupa taruh kue di rumah arwah." },
	Intro_Brother_3 = { th = "ใครมาดึกๆ ดูให้ดีก่อนเติมนะ... ไปละ", en = "If anyone shows up late, take a good look before you fill them up... I'm off.", es = "Si llega alguien tarde, fíjate bien antes de llenarle el tanque... me voy.", pt = "Se aparecer alguém tarde, olha bem antes de abastecer... fui.", id = "Kalau ada yang datang larut malam, perhatikan baik-baik sebelum diisi... aku pergi dulu." },
	Outro_Brother_1 = { th = "เมื่อคืนเป็นไงบ้าง เฝ้าไหวไหม?", en = "So how was last night? Hold up alright?", es = "¿Y qué tal anoche? ¿Aguantaste bien?", pt = "E aí, como foi ontem à noite? Aguentou firme?", id = "Jadi, semalam gimana? Aman?" },
	Outro_Brother_2 = { th = "ฮ่าๆ ขึ้นรถ ไปกินข้าวต้มกัน", en = "Haha, hop on. Let's go get some rice soup.", es = "Jaja, súbete. Vamos por una sopa de arroz.", pt = "Haha, sobe aí. Vamos tomar uma sopa de arroz.", id = "Haha, ayo naik. Kita makan bubur nasi." },
	-- ไม่ได้ถวายขนมศาล: ศาลไม่คุ้มครอง
}

-- ชื่อลูกค้า (แสดงบนหัวกล่องคำพูด จะได้จำกันได้ ผีก็ปลอมใช้ชื่อเดียวกัน)
LanguageModule.Names = {
	Name_Sommai = { th = "ลุงสมหมาย", en = "Uncle Sommai", es = "Tío Sommai", pt = "Tio Sommai", id = "Paman Sommai" },
	Name_Chaem = { th = "ป้าแช่ม", en = "Auntie Chaem", es = "Tía Chaem", pt = "Tia Chaem", id = "Bibi Chaem" },
	Name_Ton = { th = "น้องต้น", en = "Ton", es = "Ton", pt = "Ton", id = "Ton" },
	Name_Boonmee = { th = "พี่บุญมี", en = "Boonmee", es = "Boonmee", pt = "Boonmee", id = "Boonmee" },
	-- คนแวะหลบฝน
	Name_Prik = { th = "ยายปริก", en = "Grandma Prik", es = "Abuela Prik", pt = "Vovó Prik", id = "Nenek Prik" },
	Name_Daeng = { th = "พี่แดง", en = "Daeng", es = "Daeng", pt = "Daeng", id = "Daeng" },
	Name_Noi = { th = "น้าน้อย", en = "Auntie Noi", es = "Tía Noi", pt = "Tia Noi", id = "Bibi Noi" },
	-- ขาจร
	Name_PartyDriver = { th = "คนขับรถซิ่ง", en = "Party truck driver", es = "Chofer del camión de fiesta", pt = "Motorista do caminhão de festa", id = "Sopir truk pesta" },
	Name_Teen = { th = "วัยรุ่น", en = "Teen", es = "Adolescente", pt = "Adolescente", id = "Remaja" },
	Name_Coyote = { th = "สาวโคโยตี้", en = "Coyote girl", es = "Bailarina coyote", pt = "Dançarina coyote", id = "Gadis koyote" },
	Name_ParadeHost = { th = "เจ้าภาพงานบวช", en = "Ordination host", es = "Anfitrión de la ordenación", pt = "Anfitrião da ordenação", id = "Tuan rumah penahbisan" },
	Name_ParadeCrowd = { th = "ขบวนแห่", en = "Parade crowd", es = "Comitiva", pt = "Cortejo", id = "Rombongan arak-arakan" },
	Name_Brother = { th = "พี่ชาย", en = "Big Brother", es = "Hermano", pt = "Irmão", id = "Abang" },
}

function LanguageModule.GetName(key: string, localeId: string?): string
	local entry = LanguageModule.Names[key]
	if not entry then
		return key
	end
	return LanguageModule.Pick(entry, localeId)
end

-- ข้อความหน้าจอ (HUD)
LanguageModule.UI = {
	Money = { th = "เงินในกระป๋อง", en = "Money Tin", es = "Lata de Dinero", pt = "Lata de Dinheiro", id = "Kaleng Uang" },
	BoardTitle = { th = "ยอดวันนี้", en = "Tonight", es = "Esta Noche", pt = "Hoje", id = "Malam Ini" }, -- หัวกระดานชนวนยอดเงิน (MapBuilder.AddMoneyChalkboard / HUDController)
	Incense = { th = "ธูปศาลพระภูมิ", en = "Shrine Incense", es = "Incienso del Santuario", pt = "Incenso do Santuário", id = "Dupa Rumah Arwah" },
	Win = { th = "เก็บเงินครบโควตาแล้ว! ปิดร้านกลับบ้านได้ รอดไปอีกคืน", en = "Quota reached! You survived the night.", es = "¡Meta alcanzada! Sobreviviste a la noche.", pt = "Meta batida! Você sobreviveu à noite.", id = "Target tercapai! Kamu selamat malam ini." },
	Lose = { th = "ธูปดับหมดแล้ว... ศาลพระภูมิคุ้มครองไม่ไหวอีกต่อไป", en = "All the incense is out... the shrine can no longer protect you.", es = "Todo el incienso se apagó... la casa de los espíritus ya no puede protegerte.", pt = "Todo o incenso apagou... a casa dos espíritos não consegue mais te proteger.", id = "Semua dupa sudah padam... rumah arwah tak sanggup melindungimu lagi." },
	Jumpscare = { th = "คุณเติมน้ำมันให้ผี!", en = "You fueled a ghost!", es = "¡Le cargaste gasolina a un fantasma!", pt = "Você abasteceu um fantasma!", id = "Kamu mengisi bensin untuk hantu!" },
	JumpscareChased = { th = "อย่าตามผีไป!", en = "Never follow a ghost!", es = "¡Nunca sigas a un fantasma!", pt = "Nunca siga um fantasma!", id = "Jangan pernah mengikuti hantu!" },
	NewNight = { th = "คืนใหม่เริ่มแล้ว... ระวังลูกค้าแปลกๆ", en = "A new night begins... beware of strange customers.", es = "Empieza una nueva noche... cuidado con los clientes raros.", pt = "Uma nova noite começa... cuidado com clientes estranhos.", id = "Malam baru dimulai... waspadai pembeli yang aneh." },
	-- ปุ่ม ProximityPrompt (Client เปลี่ยนข้อความเองตามภาษาของผู้เล่น)
	FillUp = { th = "เติมเบนซิน", en = "Fill Petrol", es = "Cargar Gasolina", pt = "Abastecer Gasolina", id = "Isi Bensin" },
	GasPump = { th = "ตู้ปั๊มเบนซิน", en = "Petrol Pump", es = "Bomba de Gasolina", pt = "Bomba de Gasolina", id = "Pompa Bensin" },
	CloseShop = { th = "ปิดร้าน", en = "Close Shop", es = "Cerrar Tienda", pt = "Fechar Loja", id = "Tutup Toko" },
	ShutterRope = { th = "เชือกแผงสังกะสี", en = "Shutter Rope", es = "Cuerda de la Cortina", pt = "Corda do Portão", id = "Tali Pintu Seng" },
	-- ปุ่มสลับภาษา (แสดงภาษาที่ใช้อยู่)
	LangButton = { th = "ไทย", en = "EN", es = "ES", pt = "PT", id = "ID" },
	-- หน้าตั้งค่า
	Settings = { th = "ตั้งค่า", en = "Settings", es = "Ajustes", pt = "Configurações", id = "Pengaturan" },
	Language = { th = "ภาษา", en = "Language", es = "Idioma", pt = "Idioma", id = "Bahasa" },
	LangThai = { th = "ไทย", en = "ไทย", es = "ไทย", pt = "ไทย", id = "ไทย" },
	LangEnglish = { th = "English", en = "English", es = "English", pt = "English", id = "English" },
	MusicVolume = { th = "เสียงเพลง", en = "Music", es = "Música", pt = "Música", id = "Musik" },
	SfxVolume = { th = "เสียงเอฟเฟกต์", en = "Sound Effects", es = "Efectos de Sonido", pt = "Efeitos Sonoros", id = "Efek Suara" },
	ShowHUD = { th = "แสดงเงิน / ธูป / ปุ่ม", en = "Show money / incense / keys", es = "Mostrar dinero / incienso / teclas", pt = "Mostrar dinheiro / incenso / teclas", id = "Tampilkan uang / dupa / tombol" },
	ShowLabels = { th = "แสดงป้ายชื่อวัตถุ", en = "Show object labels", es = "Mostrar nombres de objetos", pt = "Mostrar nomes dos objetos", id = "Tampilkan nama benda" },
	On = { th = "เปิด", en = "On", es = "Sí", pt = "Ligado", id = "Nyala" },
	FlashHand = { th = "มือถือไฟฉาย", en = "Flashlight hand", es = "Mano de la linterna", pt = "Mão da lanterna", id = "Tangan senter" },
	HandRight = { th = "ขวา", en = "Right", es = "Derecha", pt = "Direita", id = "Kanan" },
	HandLeft = { th = "ซ้าย", en = "Left", es = "Izquierda", pt = "Esquerda", id = "Kiri" },
	Off = { th = "ปิด", en = "Off", es = "No", pt = "Desligado", id = "Mati" },
	Close = { th = "ปิด", en = "Close", es = "Cerrar", pt = "Fechar", id = "Tutup" },
	-- กล่องคำพูด + แถบปุ่มคีย์ล่างจอ
	Customer = { th = "ลูกค้า", en = "Customer", es = "Cliente", pt = "Cliente", id = "Pembeli" },
	KeyClick = { th = "คลิก", en = "Click", es = "Clic", pt = "Clique", id = "Klik" },
	HintFlashlight = { th = "เปิด/ปิดไฟฉาย", en = "Flashlight", es = "Linterna", pt = "Lanterna", id = "Senter" },
	HintHold = { th = "กดค้าง เติมน้ำมัน / เติมลม / ปิดร้าน", en = "Hold: Fuel / Air / Close Shop", es = "Mantener: Gasolina / Aire / Cerrar Tienda", pt = "Segurar: Gasolina / Ar / Fechar Loja", id = "Tahan: Bensin / Angin / Tutup Toko" },
	-- พนมมือ (PrayerController) + ปลดล็อกเมาส์ + ไฟฉาย
	HintPray = { th = "พนมมือ (เห็นผี)", en = "Pray (see ghosts)", es = "Rezar (ver fantasmas)", pt = "Rezar (ver fantasmas)", id = "Berdoa (lihat hantu)" },
	HintUnlockMouse = { th = "ปลดล็อกเมาส์", en = "Unlock Mouse", es = "Liberar Mouse", pt = "Soltar Mouse", id = "Lepas Mouse" },
	HintLockMouse = { th = "ล็อกเมาส์", en = "Lock Mouse", es = "Bloquear Mouse", pt = "Travar Mouse", id = "Kunci Mouse" },
	FlashlightSlot = { th = "ไฟฉาย", en = "Flashlight", es = "Linterna", pt = "Lanterna", id = "Senter" },
	PrayChanting = { th = "กำลังสวด", en = "Chanting", es = "Rezando", pt = "Rezando", id = "Berdoa" },
	WhisperSpeaker = { th = "เสียงกระซิบ... (ไม่ใช่ลูกค้า)", en = "A whisper... (not a customer)", es = "Un susurro... (no es un cliente)", pt = "Um sussurro... (não é cliente)", id = "Bisikan... (bukan pembeli)" },
	PraySightOpen = { th = "กำลังสวด", en = "Chanting", es = "Rezando", pt = "Rezando", id = "Berdoa" },
	-- ตอบราคา (ใครตอบก่อนได้ก่อน)
	ReplyTitle = { th = "ตอบลูกค้า (ใครตอบก่อนได้ก่อน)", en = "Reply (first answer counts)", es = "Responder (cuenta la primera respuesta)", pt = "Responder (vale a primeira resposta)", id = "Jawab (jawaban pertama yang dihitung)" },
	Reply_80 = { th = "80 บาท", en = "80 Baht", es = "80 Baht", pt = "80 Baht", id = "80 Baht" },
	Reply_100 = { th = "100 บาท", en = "100 Baht", es = "100 Baht", pt = "100 Baht", id = "100 Baht" },
	Reply_120 = { th = "120 บาท", en = "120 Baht", es = "120 Baht", pt = "120 Baht", id = "120 Baht" },
	Reply_250 = { th = "250 บาท", en = "250 Baht", es = "250 Baht", pt = "250 Baht", id = "250 Baht" },
	Reply_300 = { th = "300 บาท", en = "300 Baht", es = "300 Baht", pt = "300 Baht", id = "300 Baht" },
	Reply_350 = { th = "350 บาท", en = "350 Baht", es = "350 Baht", pt = "350 Baht", id = "350 Baht" },
	Reply_10 = { th = "10 บาท", en = "10 Baht", es = "10 Baht", pt = "10 Baht", id = "10 Baht" },
	Reply_20 = { th = "20 บาท", en = "20 Baht", es = "20 Baht", pt = "20 Baht", id = "20 Baht" },
	Reply_30 = { th = "30 บาท", en = "30 Baht", es = "30 Baht", pt = "30 Baht", id = "30 Baht" },
	FillDiesel = { th = "เติมดีเซล", en = "Fill Diesel", es = "Cargar Diésel", pt = "Abastecer Diesel", id = "Isi Solar" },
	DieselPump = { th = "ตู้ปั๊มดีเซล", en = "Diesel Pump", es = "Bomba de Diésel", pt = "Bomba de Diesel", id = "Pompa Solar" },
	PumpAir = { th = "เติมลม", en = "Pump Air", es = "Inflar Llanta", pt = "Encher Pneu", id = "Pompa Angin" },
	AirCompressorName = { th = "ถังลม", en = "Air Compressor", es = "Compresor de Aire", pt = "Compressor de Ar", id = "Kompresor Angin" },
	-- เครื่องปั่นไฟ / วิทยุ (ชื่อจุดทุกจุด = ชื่อประเภทของ ไม่ใช่ชื่อเล่น; ปุ่ม = กริยา + ของ)
	StartGenerator = { th = "สตาร์ทเครื่อง", en = "Start Generator", es = "Arrancar Generador", pt = "Ligar Gerador", id = "Nyalakan Genset" },
	GeneratorName = { th = "เครื่องปั่นไฟ", en = "Generator", es = "Generador", pt = "Gerador", id = "Genset" },
	RadioOn = { th = "เปิดวิทยุ", en = "Turn On Radio", es = "Encender Radio", pt = "Ligar Rádio", id = "Nyalakan Radio" },
	RadioOff = { th = "ปิดวิทยุ", en = "Turn Off Radio", es = "Apagar Radio", pt = "Desligar Rádio", id = "Matikan Radio" },
	RadioName = { th = "วิทยุ", en = "Radio", es = "Radio", pt = "Rádio", id = "Radio" },
	Reply_Hello = { th = "สวัสดี รับอะไรดี", en = "Hi, what can I get you?", es = "Hola, ¿qué te sirvo?", pt = "Oi, o que vai ser?", id = "Hai, mau isi apa?" },
	Reply_GreetBoth = { th = "สวัสดีทั้งสองคน", en = "Evening, you two", es = "Buenas noches a los dos", pt = "Boa noite, vocês dois", id = "Malam, kalian berdua" },
	-- เปิดร้านก่อนเริ่มคืน
	OpenShop = { th = "เปิดร้าน", en = "Open Shop", es = "Abrir Tienda", pt = "Abrir Loja", id = "Buka Toko" },
	-- สมุดบันทึกผี
	BookButton = { th = "สมุดผี", en = "Ghost Book", es = "Libro de Fantasmas", pt = "Livro de Fantasmas", id = "Buku Hantu" },
	BookTitle = { th = "สมุดบันทึกผีไทย", en = "Thai Ghost Journal", es = "Diario de Fantasmas Tailandeses", pt = "Diário de Fantasmas Tailandeses", id = "Catatan Hantu Thailand" },
	BookCount = { th = "เจอแล้ว {n} / {total}", en = "Found {n} / {total}", es = "Encontrados {n} / {total}", pt = "Encontrados {n} / {total}", id = "Ditemukan {n} / {total}" },
	BookLockedName = { th = "???", en = "???", es = "???", pt = "???", id = "???" },
	BookLockedHint = { th = "ยังไม่เคยรอดจากผีตัวนี้", en = "You have not survived this one yet.", es = "Todavía no has sobrevivido a este.", pt = "Você ainda não sobreviveu a este.", id = "Kamu belum pernah selamat dari yang satu ini." },
	BookSurvived = { th = "รอดมาแล้ว {n} ครั้ง", en = "Survived {n} times", es = "Sobreviviste {n} veces", pt = "Sobreviveu {n} vezes", id = "Selamat {n} kali" },
	BookNew = { th = "บันทึกผีใหม่ลงสมุด", en = "New journal entry", es = "Nueva entrada en el diario", pt = "Nova anotação no diário", id = "Catatan baru di buku" },
	Controls = { th = "ปุ่มควบคุม", en = "Controls", es = "Controles", pt = "Controles", id = "Kontrol" },
	ControlsOpen = { th = "ดู ▸", en = "View ▸", es = "Ver ▸", pt = "Ver ▸", id = "Lihat ▸" },
	ControlsBack = { th = "กลับ", en = "Back", es = "Volver", pt = "Voltar", id = "Kembali" },
	GiveUp = { th = "ยอมแพ้", en = "Give up", es = "Rendirse", pt = "Desistir", id = "Menyerah" },
	GiveUpBtn = { th = "ออกจากเกม", en = "Leave game", es = "Salir del juego", pt = "Sair do jogo", id = "Keluar game" },
	GiveUpConfirm = { th = "แน่ใจ? แตะอีกครั้ง", en = "Sure? Tap again", es = "¿Seguro? Toca otra vez", pt = "Certeza? Toque de novo", id = "Yakin? Tekan lagi" },
	BookDetails = { th = "ลักษณะ", en = "Details", es = "Detalles", pt = "Detalhes", id = "Detail" },
	BookNotFound = { th = "ยังไม่พบ", en = "Not found yet", es = "Aún no encontrado", pt = "Ainda não encontrado", id = "Belum ditemukan" },
	BookBack = { th = "กลับ", en = "Back", es = "Volver", pt = "Voltar", id = "Kembali" },
	BookTraits = { th = "ลักษณะและวิธีสังเกต", en = "What to look for", es = "Cómo reconocerlo", pt = "Como reconhecer", id = "Ciri-cirinya" },
	-- จอตาย (แพ้)
	AskRestart = { th = "เริ่มคืนใหม่ไหม?", en = "Start a new night?", es = "¿Empezar una nueva noche?", pt = "Começar uma nova noite?", id = "Mulai malam baru?" },
	Restart = { th = "เริ่มใหม่", en = "Restart", es = "Reiniciar", pt = "Recomeçar", id = "Ulangi" },
	Quit = { th = "กลับ Lobby", en = "Back to Lobby", es = "Volver al Lobby", pt = "Voltar ao Lobby", id = "Kembali ke Lobby" },
	GoingToLobby = { th = "กำลังกลับวัด...", en = "Heading back to the temple...", es = "Volviendo al templo...", pt = "Voltando ao templo...", id = "Kembali ke kuil..." },
	ScareWarnTitle = { th = "คำเตือน", en = "WARNING", es = "ADVERTENCIA", pt = "AVISO", id = "PERINGATAN" },
	ScareWarnBody = { th = "เกมนี้มีฉากผีหลอกและเสียงดังกะทันหัน (จั้มสแกร์)", en = "This game contains jump scares and sudden loud sounds.", es = "Este juego contiene sustos repentinos y sonidos fuertes inesperados.", pt = "Este jogo contém sustos repentinos e sons altos inesperados.", id = "Game ini berisi jump scare dan suara keras yang tiba-tiba." },
	RestartBy = { th = "{name} เลือกเริ่มใหม่...", en = "{name} chose to restart...", es = "{name} eligió reiniciar...", pt = "{name} escolheu recomeçar...", id = "{name} memilih mengulang..." },
	WaitOpen = { th = "ไฟดับ... กด [F] เปิดไฟฉาย ดึงเชือกเปิดแผงร้าน แล้วไปสตาร์ทเครื่องปั่นไฟ", en = "The power's out... press [F] for the flashlight, pull the shutter rope, then go start the generator.", es = "Se fue la luz... presiona [F] para la linterna, jala la cuerda de la cortina y ve a arrancar el generador.", pt = "A luz acabou... aperte [F] para a lanterna, puxe a corda do portão e vá ligar o gerador.", id = "Listrik padam... tekan [F] untuk senter, tarik tali pintu seng, lalu nyalakan genset." },
	-- มินิเกมเติมน้ำมัน / เติมลม
	MG_FuelTitle = { th = "สูบเบนซิน", en = "Hand-Crank Petrol", es = "Gasolina con Manivela", pt = "Gasolina na Manivela", id = "Pompa Engkol Bensin" },
	MG_DieselTitle = { th = "สูบดีเซล", en = "Hand-Crank Diesel", es = "Diésel con Manivela", pt = "Diesel na Manivela", id = "Pompa Engkol Solar" },
	MG_FuelHint = { th = "กด [Space] หรือ [คลิกซ้าย] ค้างเพื่อสูบ\nปล่อยให้ระดับน้ำมันตรงขีดสีทอง", en = "Hold [Space] or [Click] to pump\nRelease inside the gold zone", es = "Mantén [Space] o [Click] para bombear\nSuelta en la zona dorada", pt = "Segure [Space] ou [Click] para bombear\nSolte na faixa dourada", id = "Tahan [Space] atau [Click] untuk memompa\nLepas di zona emas" },
	MG_FuelBtn = { th = "กดค้างเพื่อสูบ [Space]", en = "Hold to Pump [Space]", es = "Mantén para Bombear [Space]", pt = "Segure para Bombear [Space]", id = "Tahan untuk Memompa [Space]" },
	MG_FuelOverflow = { th = "ล้นโหล! สูบใหม่อีกครั้ง", en = "Overflow! Try again", es = "¡Se derramó! Inténtalo otra vez", pt = "Transbordou! Tente de novo", id = "Tumpah! Coba lagi" },
	MG_FuelShort = { th = "ยังไม่ถึงขีด! กดค้างต่อ", en = "Not at the mark yet!", es = "¡Todavía no llega a la marca!", pt = "Ainda não chegou na marca!", id = "Belum sampai batas!" },
	MG_AirTitle = { th = "อัดลมยาง", en = "Inflate Tire", es = "Inflar Llanta", pt = "Encher Pneu", id = "Pompa Ban" },
	MG_AirHint = { th = "กด [Space] หรือ [คลิกซ้าย] ตอนเข็มตรงขีดสีทอง", en = "Press [Space] or [Click] on the gold zone", es = "Presiona [Space] o [Click] en la zona dorada", pt = "Aperte [Space] ou [Click] na faixa dourada", id = "Tekan [Space] atau [Click] di zona emas" },
	MG_AirBtn = { th = "อัดลม! [Space]", en = "Pump Air! [Space]", es = "¡Bombear Aire! [Space]", pt = "Bombear Ar! [Space]", id = "Pompa Angin! [Space]" },
	-- มือถือ (จอสัมผัส ไม่มีคีย์บอร์ด): แตะแทน Space / คลิก
	MG_FuelHint_Touch = { th = "แตะค้างเพื่อสูบ\nปล่อยให้ระดับน้ำมันตรงขีดสีทอง", en = "Tap and hold to pump\nRelease inside the gold zone", es = "Toca y mantén para bombear\nSuelta en la zona dorada", pt = "Toque e segure para bombear\nSolte na faixa dourada", id = "Sentuh dan tahan untuk memompa\nLepas di zona emas" },
	MG_FuelBtn_Touch = { th = "แตะค้างเพื่อสูบ [Tap]", en = "Hold to Pump [Tap]", es = "Mantén para Bombear [Toca]", pt = "Segure para Bombear [Toque]", id = "Tahan untuk Memompa [Sentuh]" },
	MG_AirHint_Touch = { th = "แตะตอนเข็มตรงขีดสีทอง", en = "Tap on the gold zone", es = "Toca en la zona dorada", pt = "Toque na faixa dourada", id = "Sentuh di zona emas" },
	MG_AirBtn_Touch = { th = "อัดลม! [Tap]", en = "Pump Air! [Tap]", es = "¡Bombear Aire! [Toca]", pt = "Bombear Ar! [Toque]", id = "Pompa Angin! [Sentuh]" },
	-- ข้อความอื่นที่บอกปุ่มคีย์บอร์ด: มือถือใช้ฉบับ _Touch อัตโนมัติ (LanguageModule.TouchMode, ตั้งจาก Shared.DeviceInput)
	--   ปุ่มโต้ตอบ (ProximityPrompt) บนมือถือขึ้นเป็นปุ่มให้แตะ / พนมมือ = ปุ่ม "สวด" / ไฟฉาย ขนม แกลลอน = แตะช่องด้านล่าง
	MG_CancelHint_Touch = { th = "แตะ ✕ เพื่อปิด", en = "Tap ✕ to close", es = "Toca ✕ para cerrar", pt = "Toque em ✕ para fechar", id = "Sentuh ✕ untuk menutup" },
	SkipCutscene_Touch = { th = "แตะ ข้าม เพื่อโหวตข้าม", en = "Tap Skip to vote", es = "Toca Saltar para votar", pt = "Toque em Pular para votar", id = "Sentuh Lewati untuk memilih" },
	WaitOpen_Touch = { th = "ไฟดับ... แตะช่องไฟฉาย ดึงเชือกเปิดแผงร้าน แล้วไปสตาร์ทเครื่องปั่นไฟ", en = "The power's out... tap the flashlight slot, pull the shutter rope, then go start the generator.", es = "Se fue la luz... toca el espacio de la linterna, jala la cuerda de la cortina y ve a arrancar el generador.", pt = "A luz acabou... toque no slot da lanterna, puxe a corda do portão e vá ligar o gerador.", id = "Listrik padam... sentuh slot senter, tarik tali pintu seng, lalu nyalakan genset." },
	Tut_Hide_Touch = { th = "แตะ ซ่อน เพื่อย่อ · แตะป้ายเล็กเพื่อเปิดกลับ", en = "Tap Hide to tuck away · tap the tab to bring it back", es = "Toca Ocultar para guardar · toca la pestaña para volver a abrir", pt = "Toque em Ocultar para guardar · toque na aba para trazer de volta", id = "Sentuh Sembunyikan untuk menyimpan · sentuh tab untuk membuka lagi" },
	Tut_Skip = { th = "ข้าม", en = "Skip", es = "Saltar", pt = "Pular", id = "Lewati" },
	Tut_HideBtn = { th = "ซ่อน", en = "Hide", es = "Ocultar", pt = "Ocultar", id = "Sembunyikan" },
	ShowTutorial = { th = "สอนเล่น", en = "Tutorial tips", es = "Consejos del tutorial", pt = "Dicas do tutorial", id = "Tips tutorial" },
	-- ของที่ต้องทำเรืองแสง + ป้ายลอยบนของ (client/TaskGlow) ผู้ใช้ 2026-11-23
	ShowTaskGlow = { th = "ไฮไลต์งานที่ต้องทำ", en = "Highlight pending jobs", es = "Resaltar tareas pendientes", pt = "Destacar tarefas pendentes", id = "Sorot tugas yang belum selesai" },
	-- ข้อความที่เดิมเขียนสดในสคริปต์ (ย้ายมาที่นี่ตอนรองรับหลายภาษา 2026-11-23)
	DeathTitle = { th = "คืนนี้... คุณไม่รอด", en = "YOU DID NOT SURVIVE", es = "NO SOBREVIVISTE", pt = "VOCÊ NÃO SOBREVIVEU", id = "KAMU TIDAK SELAMAT" }, -- DeathScreen
	KickGoodbye = { th = "ขอบคุณที่มาเฝ้าปั๊มหลอดท้ายทุ่ง... แล้วพบกันใหม่คืนหน้า", en = "Thanks for minding the roadside pump... see you next night.", es = "Gracias por cuidar la gasolinera del camino... nos vemos la próxima noche.", pt = "Valeu por cuidar do posto na beira da estrada... até a próxima noite.", id = "Terima kasih sudah menjaga pom bensin pinggir jalan... sampai jumpa malam berikutnya." }, -- CoreLoop.kickGoodbye
	JoinFromLobby = { th = "เข้าเกมได้จากวัด (Lobby) เท่านั้น", en = "Please join from the temple Lobby.", es = "Entra desde el Lobby del templo.", pt = "Entre pelo Lobby do templo.", id = "Silakan masuk dari Lobby kuil." }, -- MatchGuard
	LangConfirm = { th = "ยืนยัน", en = "Confirm", es = "Confirmar", pt = "Confirmar", id = "Konfirmasi" }, -- หน้าเลือกภาษาครั้งแรก (LobbyIntro)
	IntroTap = { th = "แตะหน้าจอเพื่อเริ่ม", en = "Tap to continue", es = "Toca para continuar", pt = "Toque para continuar", id = "Sentuh untuk lanjut" }, -- LobbyIntro
	IntroClick = { th = "คลิกหรือกดปุ่มใดก็ได้เพื่อเริ่ม", en = "Click or press any key to continue", es = "Haz clic o presiona cualquier tecla para continuar", pt = "Clique ou aperte qualquer tecla para continuar", id = "Klik atau tekan tombol apa saja untuk lanjut" }, -- LobbyIntro
	TombDied = { th = "มรณะ", en = "DIED", es = "FALLECIDO", pt = "FALECIDO", id = "WAFAT" }, -- ป้ายป่าช้าบนรถผี (AnomalyManager)
	TombNoName = { th = "ไม่ทราบชื่อ", en = "Name unknown", es = "Nombre desconocido", pt = "Nome desconhecido", id = "Nama tidak diketahui" },
	GenStarting = { th = "เครื่องปั่นไฟ - กำลังสตาร์ท...", en = "Generator - starting...", id = "Genset - sedang dinyalakan...", pt = "Gerador - ligando...", es = "Generador - arrancando..." }, -- มินิเกมปั่นไฟ
	GenRunning = { th = "เครื่องติดแล้ว - ไฟกลับมาแล้ว", en = "Generator running - lights are back", id = "Genset menyala - lampu kembali", pt = "Gerador ligado - as luzes voltaram", es = "Generador en marcha - volvió la luz" },
	GenShocked = { th = "โดนไฟช็อต! กลับไปกดที่เครื่องปั่นไฟเพื่อทำต่อ", en = "Shocked! Go back and press the generator to keep going", id = "Kesetrum! Kembali dan tekan genset untuk lanjut", pt = "Levou um choque! Volte e aperte o gerador para continuar", es = "¡Te dio la corriente! Vuelve y presiona el generador para seguir" },
	GenGreat = { th = "เยี่ยม!", en = "Great!", id = "Mantap!", pt = "Ótimo!", es = "¡Genial!" },
	GenGood = { th = "ดี", en = "Good", id = "Bagus", pt = "Bom", es = "Bien" },
	GenKeyTap = { th = "แตะ", en = "Tap", id = "Sentuh", pt = "Toque", es = "Toca" },
	PrayButton = { th = "สวด", en = "Pray", id = "Doa", pt = "Rezar", es = "Rezar" }, -- ปุ่มสวดบนมือถือ
	-- ร้านค้า Robux (server/RobuxShop) · \u{E002} = ไอคอน Robux (ต้องมี \u เสมอ ไม่งั้นขึ้นเป็นข้อความ {E002})
	BuyElephant = { th = "ซื้อ \u{E002}49", en = "Buy \u{E002}49", id = "Beli \u{E002}49", pt = "Comprar \u{E002}49", es = "Comprar \u{E002}49" },
	ElephantPick = { th = "หยิบไฟฉายตราช้าง", en = "Take the Elephant Flashlight", id = "Ambil Senter Cap Gajah", pt = "Pegar a Lanterna Elefante", es = "Tomar la Linterna Elefante" },
	ElephantReturn = { th = "กลับไปใช้ไฟฉายกบ", en = "Switch back to the frog flashlight", id = "Kembali pakai senter katak", pt = "Voltar para a lanterna de sapo", es = "Volver a la linterna de rana" },
	Shop_ElephantPicked = { th = "หยิบไฟฉายตราช้างแล้ว ส่องไกล สว่าง ถ่านไม่หมด", en = "You took the Elephant Flashlight: longer, brighter, endless battery", id = "Kamu mengambil Senter Cap Gajah: lebih jauh, lebih terang, baterai tak habis", pt = "Você pegou a Lanterna Elefante: mais longe, mais forte, bateria infinita", es = "Tomaste la Linterna Elefante: más lejos, más brillante, batería infinita" },
	Shop_ElephantReturned = { th = "วางไฟฉายตราช้างไว้ที่เคาน์เตอร์ กลับไปใช้ไฟฉายกบแล้ว", en = "You put the Elephant Flashlight back and switched to the frog flashlight", id = "Kamu menaruh Senter Cap Gajah dan kembali pakai senter katak", pt = "Você devolveu a Lanterna Elefante e voltou para a lanterna de sapo", es = "Dejaste la Linterna Elefante y volviste a la linterna de rana" },
	ElephantName = { th = "ไฟฉายตราช้าง", en = "Elephant Flashlight", id = "Senter Cap Gajah", pt = "Lanterna Elefante", es = "Linterna Elefante" },
	ElephantSign = { th = "ไฟฉายตราช้าง\nส่องไกล สว่างกว่า ถ่านไม่มีวันหมด\nได้ตลอดไป · \u{E002}49", en = "Elephant Flashlight\nLonger, brighter beam. Battery never runs out\nYours forever · \u{E002}49", id = "Senter Cap Gajah\nLebih jauh, lebih terang. Baterai tak pernah habis\nMilikmu selamanya · \u{E002}49", pt = "Lanterna Elefante\nFeixe mais longo e forte. A bateria nunca acaba\nSua para sempre · \u{E002}49", es = "Linterna Elefante\nHaz más largo y brillante. La batería nunca se acaba\nTuya para siempre · \u{E002}49" },
	FastPrayName = { th = "สวดมนต์ไว", en = "Fast Prayer", id = "Doa Cepat", pt = "Oração Rápida", es = "Oración Rápida" },
	FastPraySign = { th = "สวดมนต์ไว\nสวดมนต์เร็วขึ้น\nได้ตลอดไป · \u{E002}49", en = "Fast Prayer\nPray faster\nYours forever · \u{E002}49", id = "Doa Cepat\nBerdoa lebih cepat\nMilikmu selamanya · \u{E002}49", pt = "Oração Rápida\nReze mais rápido\nSua para sempre · \u{E002}49", es = "Oración Rápida\nReza más rápido\nTuya para siempre · \u{E002}49" },
	SandalsName = { th = "รองเท้าแตะติดปีก", en = "Winged Sandals", id = "Sandal Bersayap", pt = "Chinelo Alado", es = "Sandalias Aladas" },
	SandalsSign = { th = "รองเท้าแตะติดปีก\nเดินเร็วขึ้น\nได้ตลอดไป · \u{E002}49", en = "Winged Sandals\nWalk faster\nYours forever · \u{E002}49", id = "Sandal Bersayap\nJalan lebih cepat\nMilikmu selamanya · \u{E002}49", pt = "Chinelo Alado\nAnde mais rápido\nSeu para sempre · \u{E002}49", es = "Sandalias Aladas\nCamina más rápido\nTuyas para siempre · \u{E002}49" },
	PassStallTitle = { th = "ของวิเศษ · ซื้อครั้งเดียวใช้ได้ทุกคืน", en = "Lucky Charms · Buy once, use every night", id = "Barang Ajaib · Beli sekali, pakai tiap malam", pt = "Amuletos · Compre uma vez, use toda noite", es = "Amuletos · Compra una vez, úsalo cada noche" },
	-- เมนู SHOP ซ้ายจอใน Lobby (lobby/client/ShopMenu) + ตู้ร่วมทำบุญ Robux (lobby/server/TempleMerit) ผู้ใช้ 2026-11-23
	Shop_OwnedShort = { th = "มีแล้ว ✓", en = "Owned ✓", id = "Sudah punya ✓", pt = "Já tem ✓", es = "Ya lo tienes ✓" },
	ShopTitle = { th = "ร้านค้า", en = "Shop", id = "Toko", pt = "Loja", es = "Tienda" },
	ShopTabPasses = { th = "เกมพาส", en = "Game Passes", id = "Game Pass", pt = "Passes", es = "Pases" },
	ShopTabDonate = { th = "ทำบุญ", en = "Donate", id = "Donasi", pt = "Doar", es = "Donar" },
	BigRoomDesc = { th = "เปิดห้องได้ถึง 6 คน", en = "Host rooms for up to 6 players", id = "Buat room hingga 6 pemain", pt = "Crie salas de até 6 jogadores", es = "Crea salas de hasta 6 jugadores" },
	ElephantDesc = { th = "ส่องไกล สว่างกว่า ถ่านไม่มีวันหมด", en = "Longer, brighter beam. Battery never runs out", id = "Lebih jauh, lebih terang. Baterai tak pernah habis", pt = "Feixe mais longo e forte. A bateria nunca acaba", es = "Haz más largo y brillante. La batería nunca se acaba" },
	FastPrayDesc = { th = "สวดมนต์เร็วขึ้น", en = "Pray faster", id = "Berdoa lebih cepat", pt = "Reze mais rápido", es = "Reza más rápido" },
	SandalsDesc = { th = "เดินเร็วขึ้น", en = "Walk faster", id = "Jalan lebih cepat", pt = "Ande mais rápido", es = "Camina más rápido" },
	GhostBookDesc = { th = "เรียกผีได้เอง: ลูกค้าผี ผีฉาก ผีใหญ่", en = "Summon ghosts yourself: customers, scenery, big ghosts", id = "Panggil hantu sendiri: pelanggan, pemandangan, hantu besar", pt = "Invoque fantasmas: clientes, cenário, fantasmas grandes", es = "Invoca fantasmas: clientes, escenario, fantasmas grandes" },
	DonateHead = { th = "ร่วมทำบุญกับวัด", en = "Donate to the temple", id = "Berdonasi ke kuil", pt = "Doe ao templo", es = "Dona al templo" },
	DonateDesc = { th = "ทุกยอดช่วยให้เราทำเกมต่อ · ชื่อคุณจะขึ้นป้ายผู้ร่วมทำบุญสูงสุด", en = "Every donation helps us keep making the game · Your name goes on the Top Donors board", id = "Setiap donasi membantu kami terus membuat game · Namamu masuk papan Donatur Teratas", pt = "Cada doação nos ajuda a continuar o jogo · Seu nome vai para o quadro Maiores Doadores", es = "Cada donación nos ayuda a seguir con el juego · Tu nombre aparece en el tablero Mayores Donantes" },
	Donate_Thanks = { th = "ขอบคุณที่ร่วมทำบุญ สาธุ 🙏", en = "Thank you for your donation 🙏", id = "Terima kasih atas donasimu 🙏", pt = "Obrigado pela sua doação 🙏", es = "¡Gracias por tu donación! 🙏" },
	DonatePrompt = { th = "ร่วมทำบุญ", en = "Donate", id = "Berdonasi", pt = "Doar", es = "Donar" },
	DonateBoxName = { th = "ตู้ร่วมทำบุญ", en = "Donation box", id = "Kotak donasi", pt = "Caixa de doações", es = "Caja de donaciones" },
	Shop_FastPrayGot = { th = "ได้สวดมนต์ไวแล้ว! พนมมือเปิดตาทิพย์เร็วขึ้น", en = "You got Fast Prayer! Your spirit sight opens faster", id = "Kamu dapat Doa Cepat! Mata batin terbuka lebih cepat", pt = "Você ganhou Oração Rápida! A visão espiritual abre mais rápido", es = "¡Tienes Oración Rápida! La vista espiritual se abre más rápido" },
	Shop_SandalsGot = { th = "ได้รองเท้าแตะติดปีกแล้ว! เดินเร็วขึ้น", en = "You got the Winged Sandals! You walk faster", id = "Kamu dapat Sandal Bersayap! Jalan lebih cepat", pt = "Você ganhou o Chinelo Alado! Ande mais rápido", es = "¡Tienes las Sandalias Aladas! Camina más rápido" },
	Shop_Owned = { th = "คุณมีของชิ้นนี้แล้ว ใช้ได้ทุกคืน", en = "You already own this. It works every night", id = "Kamu sudah punya ini. Berlaku tiap malam", pt = "Você já tem isto. Funciona toda noite", es = "Ya tienes esto. Funciona cada noche" },
	-- สมุดหมอผี (Game Pass 149: client/GhostBook + server/GhostBook)
	BigRoomName = { th = "ห้องใหญ่", en = "Big Room", id = "Room Besar", pt = "Sala Grande", es = "Sala Grande" }, -- Game Pass 99: ห้องได้ถึง 6 คน
	BigRoomNeedPass = { th = "วงนี้ต้องมี Game Pass ห้องใหญ่ ถึงจะสร้างห้องได้ (เพื่อนเข้าร่วมฟรี)", en = "You need the Big Room pass to host here (friends join free)", id = "Perlu pass Room Besar untuk membuat room di sini (teman gabung gratis)", pt = "Você precisa do passe Sala Grande para criar aqui (amigos entram grátis)", es = "Necesitas el pase Sala Grande para crear aquí (los amigos entran gratis)" }, -- lobby/server/LobbyServer: เดินเข้าวงทองโดยไม่มี Pass
	Shop_BigRoomGot = { th = "ได้ห้องใหญ่แล้ว! เปิดห้องได้ถึง 6 คน", en = "You got the Big Room! Host rooms for up to 6 players", id = "Kamu dapat Room Besar! Buat room hingga 6 pemain", pt = "Você ganhou a Sala Grande! Crie salas de até 6 jogadores", es = "¡Tienes la Sala Grande! Crea salas de hasta 6 jugadores" },
	ShamanTitle = { th = "หมอผี", en = "Shaman", id = "Dukun", pt = "Xamã", es = "Chamán" }, -- ป้ายทองเหนือหัวคนที่มีสมุดหมอผี
	GhostBookName = { th = "สมุดหมอผี", en = "Shaman's Ghost Book", id = "Buku Dukun Hantu", pt = "Livro do Xamã", es = "Libro del Chamán" },
	BuyGhostBook = { th = "ซื้อ \u{E002}499", en = "Buy \u{E002}499", id = "Beli \u{E002}499", pt = "Comprar \u{E002}499", es = "Comprar \u{E002}499" },
	GhostBookSign = { th = "สมุดหมอผี\nเรียกผีได้เอง: ลูกค้าผี ผีฉาก ผีใหญ่\nได้ตลอดไป · \u{E002}499", en = "Shaman's Ghost Book\nSummon ghosts yourself: customers, scenery, big ghosts\nYours forever · \u{E002}499", id = "Buku Dukun Hantu\nPanggil hantu sendiri: pelanggan, pemandangan, hantu besar\nMilikmu selamanya · \u{E002}499", pt = "Livro do Xamã\nInvoque fantasmas: clientes, cenário, fantasmas grandes\nSeu para sempre · \u{E002}499", es = "Libro del Chamán\nInvoca fantasmas: clientes, escenario, fantasmas grandes\nTuyo para siempre · \u{E002}499" },
	GBook_Hint = { th = "เรียกได้ 1 ครั้งทุก 60 วิ · ผีที่เรียกไม่ได้เงินและไม่นับสถิติ", en = "One summon every 60 s · Summoned ghosts give no money and don't count in stats", id = "Satu panggilan tiap 60 dtk · Hantu panggilan tidak memberi uang dan tidak dihitung", pt = "Uma invocação a cada 60 s · Fantasmas invocados não dão dinheiro nem contam nas estatísticas", es = "Una invocación cada 60 s · Los fantasmas invocados no dan dinero ni cuentan en las estadísticas" },
	GBook_Customer = { th = "ลูกค้าผี (มาเป็นคันถัดไป)", en = "Ghost customers (comes next)", id = "Pelanggan hantu (datang berikutnya)", pt = "Clientes fantasmas (vem a seguir)", es = "Clientes fantasma (llega el siguiente)" },
	GBook_Big = { th = "ผีใหญ่บุกประชิด", en = "Big ghost raid", id = "Serbuan hantu besar", pt = "Ataque de fantasma grande", es = "Ataque de fantasma grande" },
	GBook_Linger = { th = "ผีวนรอบร้าน (ปิดแผงให้เอง)", en = "Lurkers around the shop (closes the shutter)", id = "Hantu di sekitar toko (menutup rolling door)", pt = "Assombração na loja (fecha a cortina)", es = "Fantasmas alrededor de la tienda (cierra la cortina)" },
	GBook_Scenery = { th = "ผีฉาก (เห็นคนเดียว)", en = "Scenery ghosts (only you see them)", id = "Hantu pemandangan (hanya kamu yang lihat)", pt = "Fantasmas do cenário (só você vê)", es = "Fantasmas del escenario (solo tú los ves)" },
	GB_Tani = { th = "ตานีหลังกอกล้วย", en = "Nang Tani by the bananas", id = "Nang Tani di pohon pisang", pt = "Nang Tani nas bananeiras", es = "Nang Tani en el platanal" },
	GB_Scarecrow = { th = "หุ่นไล่กาใกล้ร้าน", en = "Scarecrow near the shop", id = "Orang-orangan sawah dekat toko", pt = "Espantalho perto da loja", es = "Espantapájaros cerca de la tienda" },
	GB_Shadow = { th = "เงาหลังต้นไทร", en = "Shadow behind the banyan", id = "Bayangan di balik beringin", pt = "Sombra atrás da figueira", es = "Sombra tras el árbol sagrado" },
	GB_HutShadow = { th = "เงากระท่อมปลายนา", en = "Shadow at the field hut", id = "Bayangan di gubuk sawah", pt = "Sombra na cabana do campo", es = "Sombra en la choza del campo" },
	GB_Dancer = { th = "นางรำโคนต้นไทร", en = "Dancer under the banyan", id = "Penari di bawah beringin", pt = "Dançarina sob a figueira", es = "Bailarina bajo el árbol sagrado" },
	GB_ShadowRun = { th = "เงาดำวิ่งตัดถนน", en = "Shadow running across the road", id = "Bayangan berlari menyeberang jalan", pt = "Sombra cruzando a estrada", es = "Sombra cruzando la carretera" },
	GB_Kuman = { th = "กุมารทองข้างศาล", en = "Kuman Thong by the shrine", id = "Kuman Thong di dekat kuil", pt = "Kuman Thong perto do santuário", es = "Kuman Thong junto al santuario" },
	GB_ScarecrowClose = { th = "หุ่นไล่กาดักข้างหลัง", en = "Scarecrow right behind you", id = "Orang-orangan sawah di belakangmu", pt = "Espantalho bem atrás de você", es = "Espantapájaros justo detrás de ti" },
	GB_knock = { th = "ปอบเคาะแผง", en = "Phi Pop knocking", id = "Phi Pop mengetuk", pt = "Phi Pop batendo", es = "Phi Pop tocando" },
	GB_circle = { th = "กุมารวิ่งรอบร้าน", en = "Kuman running around", id = "Kuman berlari keliling", pt = "Kuman correndo em volta", es = "Kuman corriendo alrededor" },
	GB_roof = { th = "ผีบนหลังคา", en = "Ghost on the roof", id = "Hantu di atap", pt = "Fantasma no telhado", es = "Fantasma en el techo" },
	GBook_Summoned = { th = "{name} เปิดสมุดหมอผี... มีบางอย่างกำลังมา", en = "{name} opened the Ghost Book... something is coming", id = "{name} membuka Buku Dukun Hantu... sesuatu akan datang", pt = "{name} abriu o Livro do Xamã... algo está vindo", es = "{name} abrió el Libro del Chamán... algo se acerca" },
	GBook_Cooldown = { th = "สมุดยังร้อนอยู่ รออีก {sec} วิ", en = "The book is still warm. Wait {sec} s", id = "Bukunya masih panas. Tunggu {sec} dtk", pt = "O livro ainda está quente. Espere {sec} s", es = "El libro sigue caliente. Espera {sec} s" },
	GBook_NotNow = { th = "ตอนนี้เรียกผีนี้ไม่ได้ (ร้านยังไม่เปิด เกมจบแล้ว หรือมีผีใหญ่อยู่)", en = "Can't summon this right now (shop closed, night over, or a big ghost is here)", id = "Tidak bisa memanggil sekarang (toko tutup, malam selesai, atau ada hantu besar)", pt = "Não dá para invocar agora (loja fechada, noite acabou ou há um fantasma grande)", es = "No puedes invocarlo ahora (tienda cerrada, noche terminada o hay un fantasma grande)" },
	Shop_GhostBookGot = { th = "ได้สมุดหมอผีแล้ว! กดปุ่มสมุดหมอผีมุมขวาบนในแมพปั๊ม", en = "You got the Shaman's Ghost Book! Tap its button at the top right in the gas shack", id = "Kamu dapat Buku Dukun Hantu! Tekan tombolnya di kanan atas di pom bensin", pt = "Você ganhou o Livro do Xamã! Toque no botão no canto superior direito no posto", es = "¡Tienes el Libro del Chamán! Toca su botón arriba a la derecha en la gasolinera" },
	BuyPrank = { th = "แกล้งทุกคน \u{E002}19", en = "Scare everyone \u{E002}19", id = "Kagetkan semua \u{E002}19", pt = "Assustar todos \u{E002}19", es = "Asustar a todos \u{E002}19" },
	GhostPosterName = { th = "ป้ายผี", en = "Ghost Poster", id = "Poster Hantu", pt = "Cartaz do Fantasma", es = "Cartel del Fantasma" },
	PosterTop = { th = "ทำให้ทุกคนตกใจ!", en = "SCARE EVERYONE!", id = "KAGETKAN SEMUA!", pt = "ASSUSTE TODOS!", es = "¡ASUSTA A TODOS!" },
	PosterBottom = { th = "\u{E002}19 · ผีจะโผล่หลอกทุกคนในห้อง", en = "\u{E002}19 · A ghost jumps out at everyone in the room", id = "\u{E002}19 · Hantu muncul mengagetkan semua orang di room", pt = "\u{E002}19 · Um fantasma assusta todo mundo na sala", es = "\u{E002}19 · Un fantasma asusta a todos en la sala" },
	BuyIncense = { th = "ต่อธูป 1 ดอก \u{E002}19", en = "Relight 1 incense \u{E002}19", id = "Nyalakan 1 dupa \u{E002}19", pt = "Reacender 1 incenso \u{E002}19", es = "Reencender 1 incienso \u{E002}19" },
	IncensePotName = { th = "กระถางธูป", en = "Incense Pot", id = "Tempat Dupa", pt = "Incensário", es = "Incensario" },
	Shop_ElephantGot = { th = "ได้ไฟฉายตราช้างแล้ว! ส่องไกล สว่าง ถ่านไม่หมด", en = "You got the Elephant Flashlight! Longer, brighter, endless battery", id = "Kamu dapat Senter Cap Gajah! Lebih jauh, lebih terang, baterai tak habis", pt = "Você ganhou a Lanterna Elefante! Mais longe, mais forte, bateria infinita", es = "¡Tienes la Linterna Elefante! Más lejos, más brillante, batería infinita" },
	Shop_PrankBy = { th = "{name} ซื้อป้ายผีหลอกทุกคน!", en = "{name} bought the ghost poster to scare everyone!", id = "{name} membeli poster hantu untuk mengagetkan semua!", pt = "{name} comprou o cartaz para assustar todo mundo!", es = "¡{name} compró el cartel para asustar a todos!" },
	Shop_PrankDone = { th = "หลอกสำเร็จ! เพื่อนทุกคนในห้องโดนผีหลอก", en = "Gotcha! Everyone else in the room got scared", id = "Berhasil! Semua orang di room kaget", pt = "Pegadinha feita! Todo mundo na sala levou um susto", es = "¡Lo lograste! Todos en la sala se asustaron" },
	Shop_PrankAlone = { th = "ยังไม่มีเพื่อนในห้องให้หลอก", en = "No one else is in the room to scare", id = "Belum ada teman di room untuk dikagetkan", pt = "Não há ninguém na sala para assustar", es = "No hay nadie más en la sala para asustar" },
	Shop_IncenseBy = { th = "{name} ต่อธูปให้ศาล 1 ดอก", en = "{name} relit 1 incense stick at the shrine", id = "{name} menyalakan 1 dupa di kuil", pt = "{name} reacendeu 1 incenso no santuário", es = "{name} reencendió 1 incienso en el santuario" },
	Shop_IncenseQueued = { th = "ธูปยังครบอยู่ จะจุดให้ทันทีเมื่อมีดอกดับ", en = "All incense is lit; yours will light as soon as one goes out", id = "Semua dupa menyala; dupamu akan menyala begitu ada yang padam", pt = "Todos os incensos estão acesos; o seu acende assim que um apagar", es = "Todo el incienso está encendido; el tuyo se encenderá en cuanto uno se apague" },
	Task_Generator = { th = "สตาร์ทเครื่องปั่นไฟ", en = "Start the generator", es = "Arranca el generador", pt = "Ligue o gerador", id = "Nyalakan genset" },
	Task_TakeCan = { th = "หยิบแกลลอน", en = "Take the jerry can", es = "Toma el bidón", pt = "Pegue o galão", id = "Ambil jeriken" },
	Task_FillCan = { th = "ตักน้ำมันจากถัง", en = "Fill it at a drum", es = "Llénalo en un barril", pt = "Encha no tambor", id = "Isi di drum" },
	Task_Pour = { th = "เทใส่ตู้ปั๊ม", en = "Pour into the pump", es = "Viértelo en la bomba", pt = "Despeje na bomba", id = "Tuang ke pompa" },
	Task_TakeSweets = { th = "หยิบขนม", en = "Take the sweets", es = "Toma los dulces", pt = "Pegue os doces", id = "Ambil kue" },
	Task_Offer = { th = "ถวายศาลพระภูมิ", en = "Offer at the spirit house", es = "Ofrécelos en la casa de los espíritus", pt = "Ofereça na casa dos espíritos", id = "Persembahkan di rumah arwah" },
	Tut_Flashlight_Touch = { th = "ไฟดับมืดตื้อ... แตะช่องไฟฉายด้านล่างก่อน", en = "It's pitch dark... tap the flashlight slot below first.", es = "Oscuridad total... primero toca el espacio de la linterna abajo.", pt = "Escuridão total... toque primeiro no slot da lanterna lá embaixo.", id = "Gelap gulita... sentuh slot senter di bawah dulu." },
	Tut_OpenShop_Touch = { th = "เดินไปที่เชือกหลังโต๊ะ แล้วแตะปุ่มที่ขึ้นมาเพื่อดึงเปิดแผงร้าน", en = "Go to the rope behind the counter and tap the button that appears to raise the shutter.", es = "Ve a la cuerda detrás del mostrador y toca el botón que aparece para subir la cortina.", pt = "Vá até a corda atrás do balcão e toque no botão que aparecer para levantar o portão.", id = "Pergi ke tali di belakang meja, lalu sentuh tombol yang muncul untuk menaikkan pintu seng." },
	Tut_Generator_Touch = { th = "ไฟร้านยังดับ: ไปที่เครื่องปั่นไฟข้างร้าน แตะปุ่มที่ขึ้นมา แล้วแตะตามจังหวะจนเครื่องติด", en = "Still no power: go to the generator beside the shop, tap the button that appears, and tap in rhythm until it starts.", es = "Sigue sin luz: ve al generador al lado de la tienda, toca el botón que aparece y toca al ritmo hasta que arranque.", pt = "Ainda sem luz: vá até o gerador ao lado da loja, toque no botão que aparecer e toque no ritmo até ele pegar.", id = "Listrik masih padam: pergi ke genset di samping toko, sentuh tombol yang muncul, lalu sentuh mengikuti irama sampai menyala." },
	Tut_TakeCan_Touch = { th = "ตู้ยังไม่มีน้ำมัน: หยิบแกลลอนมุมหลังร้าน (แตะปุ่มที่ขึ้นมา)", en = "The pumps are empty: take the jerry can in the back corner of the shop (tap the button that appears).", es = "Las bombas están vacías: toma el bidón en la esquina del fondo de la tienda (toca el botón que aparece).", pt = "As bombas estão vazias: pegue o galão no canto dos fundos da loja (toque no botão que aparecer).", id = "Pompa kosong: ambil jeriken di pojok belakang toko (sentuh tombol yang muncul)." },
	Tut_FillCan_Touch = { th = "ไปที่ถังน้ำมันหลังร้าน แตะปุ่มค้างไว้เพื่อตักน้ำมันใส่แกลลอน (ถังไหนก็ได้ เทได้ทั้งตู้ซ้ายและขวา)", en = "Go to the fuel drums behind the shop and hold the button to fill the can (any drum works for either pump).", es = "Ve a los barriles de combustible detrás de la tienda y mantén el botón para llenar el bidón (cualquier barril sirve para ambas bombas).", pt = "Vá até os tambores de combustível atrás da loja e segure o botão para encher o galão (qualquer tambor serve para as duas bombas).", id = "Pergi ke drum bensin di belakang toko dan tahan tombolnya untuk mengisi jeriken (drum mana pun bisa untuk kedua pompa)." },
	Tut_Pour_Touch = { th = "กลับมาที่ตู้น้ำมันหน้าร้าน แตะปุ่มค้างไว้เพื่อเทน้ำมันใส่ตู้ (ตู้หมดเมื่อไหร่ทำแบบนี้อีก)", en = "Back at the pumps, hold the button to pour the fuel in (repeat whenever a pump runs dry).", es = "De vuelta en las bombas, mantén el botón para verter el combustible (repite cada vez que una bomba se vacíe).", pt = "De volta às bombas, segure o botão para despejar o combustível (repita sempre que uma bomba secar).", id = "Kembali ke pompa, tahan tombolnya untuk menuang bensin (ulangi setiap kali pompa kosong)." },
	Tut_Offer_Touch = { th = "หยิบขนมไทยที่ถาดบนเคาน์เตอร์ ไปที่ศาลพระภูมิ แตะปุ่มค้างไว้เพื่อถวาย (ดูเวลาคุ้มครองมุมขวาบน)", en = "Take the Thai sweets from the tray on the counter, go to the spirit house and hold the button to offer them (protection timer is top-right).", es = "Toma los dulces tailandeses de la bandeja del mostrador, ve a la casa de los espíritus y mantén el botón para ofrecerlos (el tiempo de protección está arriba a la derecha).", pt = "Pegue os doces tailandeses na bandeja do balcão, vá até a casa dos espíritos e segure o botão para oferecê-los (o tempo de proteção fica no canto superior direito).", id = "Ambil kue Thailand dari nampan di meja, pergi ke rumah arwah dan tahan tombolnya untuk mempersembahkan (waktu perlindungan ada di kanan atas)." },
	Tut_Ghosts_Touch = { th = "ลูกค้ามาแล้วแตะปุ่ม สวด ค้างไว้เพื่อพนมมือดูผี ถ้าเป็นผีห้ามเติม! ดึงเชือกปิดแผงร้านแล้วอยู่ในร้าน · ยอดเงินดูที่กระดานชนวนบนเคาน์เตอร์", en = "When customers arrive, hold the Pray button to see ghosts. If it's a ghost, DON'T serve — pull the rope to close the shutter and stay inside. Your takings are chalked on the little slate on the counter.", es = "Cuando lleguen clientes, mantén el botón Rezar para ver fantasmas. Si es un fantasma, NO lo atiendas — jala la cuerda para cerrar la cortina y quédate adentro. Tus ganancias se anotan con gis en la pizarrita del mostrador.", pt = "Quando chegarem clientes, segure o botão Rezar para ver fantasmas. Se for um fantasma, NÃO atenda — puxe a corda para fechar o portão e fique lá dentro. O que você ganha fica anotado a giz na lousinha do balcão.", id = "Saat pembeli datang, tahan tombol Berdoa untuk melihat hantu. Kalau itu hantu, JANGAN dilayani — tarik tali untuk menutup pintu seng dan tetap di dalam. Pendapatanmu ditulis kapur di papan kecil di meja." },
	MG_AirMiss = { th = "ผิดจังหวะ! รอเข็มวิ่งกลับ", en = "Missed! Wait for needle", es = "¡Fallaste! Espera la aguja", pt = "Errou! Espere o ponteiro", id = "Meleset! Tunggu jarumnya" },
	MG_Success = { th = "สำเร็จ!", en = "Complete!", es = "¡Listo!", pt = "Pronto!", id = "Selesai!" },
	MG_CancelHint = { th = "[X] ปิด", en = "[X] Close", es = "[X] Cerrar", pt = "[X] Fechar", id = "[X] Tutup" },
	-- คัทซีน
	SkipCutscene = { th = "กด [Enter] เพื่อโหวตข้าม", en = "Press [Enter] to vote skip", es = "Presiona [Enter] para votar saltar", pt = "Aperte [Enter] para votar em pular", id = "Tekan [Enter] untuk memilih lewati" },
	SkipVoted = { th = "รอคนอื่น {n}/{total}", en = "Waiting {n}/{total}", es = "Esperando {n}/{total}", pt = "Esperando {n}/{total}", id = "Menunggu {n}/{total}" },
	SkipVotes = { th = "โหวตข้ามแล้ว {n}/{total} คน (ข้ามเมื่อครบทุกคน)", en = "Skip votes {n}/{total} (skips when everyone votes)", es = "Votos para saltar {n}/{total} (se salta cuando todos votan)", pt = "Votos para pular {n}/{total} (pula quando todos votarem)", id = "Suara lewati {n}/{total} (dilewati kalau semua memilih)" },
	SkipBtn = { th = "ข้าม ▶▶", en = "Skip ▶▶", es = "Saltar ▶▶", pt = "Pular ▶▶", id = "Lewati ▶▶" },
	-- น้ำมันในตู้ + ถังน้ำมัน
	FuelEmpty = { th = "น้ำมันในตู้หมด! หยิบแกลลอนในร้าน ไปตักจากถังหลังร้าน แล้วมาเทใส่ตู้", en = "The pump is empty! Grab the jerry can in the shop, fill it at the drum behind the shop, then pour it into the pump.", es = "¡La bomba está vacía! Toma el bidón en la tienda, llénalo en el barril detrás de la tienda y viértelo en la bomba.", pt = "A bomba está vazia! Pegue o galão na loja, encha no tambor atrás da loja e despeje na bomba.", id = "Pompa kosong! Ambil jeriken di toko, isi di drum belakang toko, lalu tuang ke pompa." },
	FuelLow = { th = "น้ำมันในตู้ใกล้หมดแล้ว", en = "The pump is running low", es = "A la bomba le queda poco combustible", pt = "A bomba está quase vazia", id = "Bensin di pompa hampir habis" },
	CanSlot = { th = "แกลลอน", en = "Jerry can", es = "Bidón", pt = "Galão", id = "Jeriken" },
	CanEmpty = { th = "(ว่าง)", en = "(empty)", es = "(vacío)", pt = "(vazio)", id = "(kosong)" },
	CanFull = { th = "(เต็ม)", en = "(full)", es = "(lleno)", pt = "(cheio)", id = "(penuh)" },
	TakeCan = { th = "หยิบแกลลอน", en = "Take", es = "Tomar", pt = "Pegar", id = "Ambil" },
	CanName = { th = "แกลลอนน้ำมัน", en = "Jerry Can", es = "Bidón", pt = "Galão", id = "Jeriken" },
	FillCan = { th = "ตักน้ำมันใส่แกลลอน", en = "Fill Can", es = "Llenar Bidón", pt = "Encher Galão", id = "Isi Jeriken" },
	DrumName = { th = "ถังน้ำมัน", en = "Fuel Drum", es = "Barril de Combustible", pt = "Tambor de Combustível", id = "Drum Bensin" },
	PourPetrol = { th = "เทน้ำมันใส่ตู้", en = "Pour Fuel", es = "Verter Gasolina", pt = "Despejar Gasolina", id = "Tuang Bensin" },
	PourDiesel = { th = "เทดีเซลใส่ตู้", en = "Pour Diesel", es = "Verter Diésel", pt = "Despejar Diesel", id = "Tuang Solar" },
	FillRack = { th = "เติมน้ำมันขวด", en = "Fill Bottles", es = "Llenar Botellas", pt = "Encher Garrafas", id = "Isi Botol" },
	-- สอนเล่นทีละขั้น (TutorialController)
	Tut_Title = { th = "วิธีเฝ้าร้าน", en = "How to mind the shop", es = "Cómo cuidar la tienda", pt = "Como cuidar da loja", id = "Cara menjaga toko" },
	Tut_Hide = { th = "[H] ย่อ/เปิด · กด [V] ปลดเมาส์แล้วคลิก ข้าม หรือ ซ่อน", en = "[H] hide/show · press [V] to free the mouse, then click Skip or Hide", es = "[H] ocultar/mostrar · presiona [V] para liberar el mouse y haz clic en Saltar u Ocultar", pt = "[H] ocultar/mostrar · aperte [V] para soltar o mouse e clique em Pular ou Ocultar", id = "[H] sembunyikan/tampilkan · tekan [V] untuk melepas mouse, lalu klik Lewati atau Sembunyikan" },
	Tut_Flashlight = { th = "ไฟดับมืดตื้อ... กด [F] เปิดไฟฉายก่อน", en = "It's pitch dark... press [F] to turn on your flashlight.", es = "Oscuridad total... presiona [F] para encender la linterna.", pt = "Escuridão total... aperte [F] para ligar a lanterna.", id = "Gelap gulita... tekan [F] untuk menyalakan senter." },
	Tut_OpenShop = { th = "เดินไปที่เชือกหลังโต๊ะ แล้วกด [E] ดึงเปิดแผงร้าน", en = "Go to the rope behind the counter and press [E] to raise the shutter.", es = "Ve a la cuerda detrás del mostrador y presiona [E] para subir la cortina.", pt = "Vá até a corda atrás do balcão e aperte [E] para levantar o portão.", id = "Pergi ke tali di belakang meja dan tekan [E] untuk menaikkan pintu seng." },
	Tut_Generator = { th = "ไฟร้านยังดับ: ไปที่เครื่องปั่นไฟข้างร้าน กด [E] แล้วกดตามจังหวะจนเครื่องติด", en = "Still no power: go to the generator beside the shop, press [E], and follow the rhythm until it starts.", es = "Sigue sin luz: ve al generador al lado de la tienda, presiona [E] y sigue el ritmo hasta que arranque.", pt = "Ainda sem luz: vá até o gerador ao lado da loja, aperte [E] e siga o ritmo até ele pegar.", id = "Listrik masih padam: pergi ke genset di samping toko, tekan [E], lalu ikuti iramanya sampai menyala." },
	Tut_TakeCan = { th = "ตู้ยังไม่มีน้ำมัน: หยิบแกลลอนมุมหลังร้าน กด [E]", en = "The pumps are empty: take the jerry can in the back corner of the shop with [E].", es = "Las bombas están vacías: toma el bidón en la esquina del fondo de la tienda con [E].", pt = "As bombas estão vazias: pegue o galão no canto dos fundos da loja com [E].", id = "Pompa kosong: ambil jeriken di pojok belakang toko dengan [E]." },
	Tut_FillCan = { th = "ไปที่ถังน้ำมันหลังร้าน กด [E] ค้างตักน้ำมันใส่แกลลอน (ถังไหนก็ได้ เทได้ทั้งตู้ซ้ายและขวา)", en = "Go to the fuel drums behind the shop and hold [E] to fill the can (any drum works for either pump).", es = "Ve a los barriles de combustible detrás de la tienda y mantén [E] para llenar el bidón (cualquier barril sirve para ambas bombas).", pt = "Vá até os tambores de combustível atrás da loja e segure [E] para encher o galão (qualquer tambor serve para as duas bombas).", id = "Pergi ke drum bensin di belakang toko dan tahan [E] untuk mengisi jeriken (drum mana pun bisa untuk kedua pompa)." },
	Tut_Pour = { th = "กลับมาที่ตู้น้ำมันหน้าร้าน กด [E] ค้างเทน้ำมันใส่ตู้ (ตู้หมดเมื่อไหร่ทำแบบนี้อีก)", en = "Back at the pumps, hold [E] to pour the fuel in (repeat whenever a pump runs dry).", es = "De vuelta en las bombas, mantén [E] para verter el combustible (repite cada vez que una bomba se vacíe).", pt = "De volta às bombas, segure [E] para despejar o combustível (repita sempre que uma bomba secar).", id = "Kembali ke pompa, tahan [E] untuk menuang bensin (ulangi setiap kali pompa kosong)." },
	Tut_Offer = { th = "หยิบขนมไทยที่ถาดบนเคาน์เตอร์ [E] ไปที่ศาลพระภูมิ กด [E] ค้างถวาย (ดูเวลาคุ้มครองมุมขวาบน)", en = "Take the Thai sweets from the tray on the counter [E], go to the spirit house and hold [E] to offer them (protection timer is top-right).", es = "Toma los dulces tailandeses de la bandeja del mostrador [E], ve a la casa de los espíritus y mantén [E] para ofrecerlos (el tiempo de protección está arriba a la derecha).", pt = "Pegue os doces tailandeses na bandeja do balcão [E], vá até a casa dos espíritos e segure [E] para oferecê-los (o tempo de proteção fica no canto superior direito).", id = "Ambil kue Thailand dari nampan di meja [E], pergi ke rumah arwah dan tahan [E] untuk mempersembahkan (waktu perlindungan ada di kanan atas)." },
	Tut_Ghosts = { th = "ลูกค้ามาแล้วกด [G] ค้างพนมมือดูผี ถ้าเป็นผีห้ามเติม! ดึงเชือกปิดแผงร้านแล้วอยู่ในร้าน · ยอดเงินดูที่กระดานชนวนบนเคาน์เตอร์", en = "When customers arrive, hold [G] to pray and see ghosts. If it's a ghost, DON'T serve — pull the rope to close the shutter and stay inside. Your takings are chalked on the little slate on the counter.", es = "Cuando lleguen clientes, mantén [G] para rezar y ver fantasmas. Si es un fantasma, NO lo atiendas — jala la cuerda para cerrar la cortina y quédate adentro. Tus ganancias se anotan con gis en la pizarrita del mostrador.", pt = "Quando chegarem clientes, segure [G] para rezar e ver fantasmas. Se for um fantasma, NÃO atenda — puxe a corda para fechar o portão e fique lá dentro. O que você ganha fica anotado a giz na lousinha do balcão.", id = "Saat pembeli datang, tahan [G] untuk berdoa dan melihat hantu. Kalau itu hantu, JANGAN dilayani — tarik tali untuk menutup pintu seng dan tetap di dalam. Pendapatanmu ditulis kapur di papan kecil di meja." },
	RackName = { th = "แผงน้ำมันขวด", en = "Bottle Rack", es = "Estante de Botellas", pt = "Prateleira de Garrafas", id = "Rak Botol" },
	StartRefuel = { th = "ตู้กับแผงยังไม่มีน้ำมัน! หยิบแกลลอนในร้าน ไปตักที่ถังหลังร้านมาเติมก่อนลูกค้ามา", en = "The pumps and bottle rack are empty! Grab the jerry can, fill it at the drum behind the shop, and refuel before customers arrive.", es = "¡Las bombas y el estante de botellas están vacíos! Toma el bidón, llénalo en el barril detrás de la tienda y carga combustible antes de que lleguen los clientes.", pt = "As bombas e a prateleira de garrafas estão vazias! Pegue o galão, encha no tambor atrás da loja e abasteça antes dos clientes chegarem.", id = "Pompa dan rak botol kosong! Ambil jeriken, isi di drum belakang toko, lalu isi pompa sebelum pembeli datang." },
	NeedCan = { th = "ต้องถือแกลลอนเปล่าก่อน", en = "You need an empty jerry can", es = "Necesitas un bidón vacío", pt = "Você precisa de um galão vazio", id = "Kamu butuh jeriken kosong" },
	WrongCanPetrol = { th = "ตู้หลอดแดงใช้น้ำมันจากถังแดงเท่านั้น", en = "The red pump only takes fuel from the red drum", es = "La bomba roja solo acepta combustible del barril rojo", pt = "A bomba vermelha só aceita combustível do tambor vermelho", id = "Pompa merah hanya menerima bensin dari drum merah" },
	WrongCanDiesel = { th = "ตู้ดีเซลเขียวใช้น้ำมันจากถังน้ำเงินเท่านั้น", en = "The green diesel pump only takes fuel from the blue drum", es = "La bomba verde de diésel solo acepta combustible del barril azul", pt = "A bomba verde de diesel só aceita combustível do tambor azul", id = "Pompa solar hijau hanya menerima bensin dari drum biru" },
	-- ขนมถวายศาล
	DessertSlot = { th = "ขนมไทย", en = "Thai sweets", es = "Dulces tailandeses", pt = "Doces tailandeses", id = "Kue Thailand" },
	TakeDessert = { th = "หยิบขนม", en = "Take sweets", es = "Tomar dulces", pt = "Pegar doces", id = "Ambil kue" },
	DessertTray = { th = "ถาดขนมไทย", en = "Sweets tray", es = "Bandeja de dulces", pt = "Bandeja de doces", id = "Nampan kue" },
	OfferDessert = { th = "ถวายขนม", en = "Offer sweets", es = "Ofrecer dulces", pt = "Oferecer doces", id = "Persembahkan kue" },
	SpiritHouseName = { th = "ศาลพระภูมิ", en = "Spirit House", es = "Casa de los Espíritus", pt = "Casa dos Espíritos", id = "Rumah Arwah" },
	ShrineHungry = { th = "ศาลพระภูมิยังไม่ได้รับของถวาย... รีบเอาขนมไปถวายก่อนจะมีเรื่อง", en = "The spirit house has no offering... bring sweets before something happens.", es = "La casa de los espíritus no tiene ofrenda... lleva dulces antes de que pase algo.", pt = "A casa dos espíritos está sem oferenda... leve doces antes que algo aconteça.", id = "Rumah arwah tidak punya sesaji... bawa kue sebelum sesuatu terjadi." },
	ShrineCursed = { th = "ศาลไม่คุ้มครองแล้ว... เอาขนมไปถวายเดี๋ยวนี้!", en = "The shrine no longer protects you... offer sweets now!", es = "El santuario ya no te protege... ¡ofrece dulces ahora!", pt = "O santuário não te protege mais... ofereça doces agora!", id = "Rumah arwah tidak melindungimu lagi... persembahkan kue sekarang!" },
	PrepOver = { th = "หมดเวลาเตรียมร้าน ลูกค้าเริ่มมาแล้ว!", en = "Prep time is over - customers are coming!", es = "Se acabó el tiempo de preparación - ¡ya vienen los clientes!", pt = "O tempo de preparo acabou - os clientes estão chegando!", id = "Waktu persiapan habis - pembeli mulai datang!" },
	ShrineTimer = { th = "ศาลคุ้มครองอีก", en = "Shrine protects for", es = "El santuario protege por", pt = "O santuário protege por", id = "Rumah arwah melindungi selama" },
	ShrineTimerSoon = { th = "ใกล้หมด! ไปถวายขนม", en = "Running out! Offer sweets", es = "¡Se acaba! Ofrece dulces", pt = "Acabando! Ofereça doces", id = "Hampir habis! Persembahkan kue" },
	-- ช่วงเตรียมร้านก่อนลูกค้ามา (client/ItemSlots)
	PrepTitle = { th = "เตรียมร้าน ลูกค้ามาใน", en = "Get ready - customers in", es = "Prepárate - clientes en", pt = "Prepare-se - clientes chegam em", id = "Bersiap - pembeli datang dalam" },
	PrepOffer = { th = "ถวายขนมศาล", en = "Offer sweets", es = "Ofrecer dulces", pt = "Oferecer doces", id = "Persembahkan kue" },
	PrepPower = { th = "ติดเครื่องปั่นไฟ", en = "Start generator", es = "Arrancar generador", pt = "Ligar gerador", id = "Nyalakan genset" },
	PrepFuel = { th = "เติมน้ำมันตู้", en = "Refuel pumps", es = "Cargar las bombas", pt = "Abastecer bombas", id = "Isi pompa" },
	ShrineTimerCursed = { th = "ศาลไม่คุ้มครอง! ถวายขนม", en = "Unprotected! Offer sweets", es = "¡Sin protección! Ofrece dulces", pt = "Sem proteção! Ofereça doces", id = "Tidak terlindungi! Persembahkan kue" },
	ShrineOffered = { th = "ถวายขนมแล้ว ศาลคุ้มครองไปอีกพัก", en = "Sweets offered. The shrine will protect you for a while.", es = "Dulces ofrecidos. El santuario te protegerá por un rato.", pt = "Doces oferecidos. O santuário vai te proteger por um tempo.", id = "Kue sudah dipersembahkan. Rumah arwah akan melindungimu untuk sementara." },
	-- สรุปผลจบคืน
	SummaryTitle = { th = "รอดมาได้อีกคืน", en = "You Survived the Night", es = "Sobreviviste a la Noche", pt = "Você Sobreviveu à Noite", id = "Kamu Selamat Malam Ini" },
	SummaryTeam = { th = "เงินในกระป๋องทั้งร้าน", en = "Total in the money tin", es = "Total en la lata de dinero", pt = "Total na lata de dinheiro", id = "Total di kaleng uang" },
	SummaryAnomalies = { th = "สิ่งผิดปกติที่เจอทั้งคืน", en = "Anomalies encountered", es = "Anomalías encontradas", pt = "Anomalias encontradas", id = "Kejanggalan yang ditemui" },
	SummaryCaught = { th = "ไล่ผีได้", en = "Ghosts turned away", es = "Fantasmas rechazados", pt = "Fantasmas recusados", id = "Hantu yang ditolak" },
	SummaryFooled = { th = "เติมให้ผีไป", en = "Ghosts served by mistake", es = "Fantasmas atendidos por error", pt = "Fantasmas atendidos por engano", id = "Hantu yang terlanjur dilayani" },
	SummaryOfferings = { th = "ถวายขนมศาล", en = "Shrine offerings", es = "Ofrendas al santuario", pt = "Oferendas ao santuário", id = "Sesaji rumah arwah" },
	SummaryPlayer = { th = "ผู้เล่น", en = "Player", es = "Jugador", pt = "Jogador", id = "Pemain" },
	SummaryFills = { th = "เติม (ครั้ง)", en = "Fills", es = "Cargas", pt = "Abastecimentos", id = "Isi" },
	SummaryEarned = { th = "ทำเงิน", en = "Earned", es = "Ganado", pt = "Ganhou", id = "Pendapatan" },
	SummaryGhosts = { th = "ไล่ผี", en = "Ghosts", es = "Fantasmas", pt = "Fantasmas", id = "Hantu" },
	SummaryWage = { th = "ค่าเฝ้าร้าน", en = "Wage", es = "Paga", pt = "Pagamento", id = "Upah" },
	SummaryNext = { th = "เฝ้าต่ออีกคืน", en = "Another night", es = "Otra noche", pt = "Mais uma noite", id = "Malam berikutnya" },
	SummaryWait = { th = "รอเพื่อนกด... ({n})", en = "Waiting for others... ({n})", es = "Esperando a los demás... ({n})", pt = "Esperando os outros... ({n})", id = "Menunggu yang lain... ({n})" },
	-- ผีทุกตัวคืนนี้ + เวลาที่เฝ้าร้าน (shared/NightRecap: หน้าสรุปผล + จอตาย)
	SummaryTime = { th = "เวลาที่เฝ้าร้าน", en = "Time on shift", es = "Tiempo de turno", pt = "Tempo de turno", id = "Lama jaga" },
	RecapTime = { th = "{m} นาที {s} วินาที", en = "{m}m {s}s", es = "{m}min {s}s", pt = "{m}min {s}s", id = "{m}m {s}d" },
	RecapGhosts = { th = "ผีที่มาคืนนี้", en = "Tonight's ghosts", es = "Fantasmas de esta noche", pt = "Fantasmas desta noite", id = "Hantu malam ini" },
	RecapNoGhosts = { th = "คืนนี้ไม่มีผีมาที่ร้าน", en = "No ghosts came to the shop tonight", es = "Ningún fantasma vino a la tienda esta noche", pt = "Nenhum fantasma veio à loja hoje", id = "Tidak ada hantu yang datang ke toko malam ini" },
	RecapAt = { th = "นาทีที่ {m}", en = "min {m}", es = "min {m}", pt = "min {m}", id = "menit {m}" },
	RecapCaught = { th = "ไล่ทัน", en = "Turned away", es = "Rechazado", pt = "Recusado", id = "Ditolak" },
	RecapFooled = { th = "เติมให้ผี", en = "Served", es = "Atendido", pt = "Atendido", id = "Dilayani" },
	RecapGone = { th = "ปล่อยไป", en = "Let go", es = "Dejado ir", pt = "Deixado ir", id = "Dibiarkan" },
	RecapTell = { th = "จุดสังเกต: ", en = "The sign: ", es = "La señal: ", pt = "O sinal: ", id = "Tandanya: " },
	DeathSurvived = { th = "รอดมาได้ {t} · เงิน {money} / {target} บาท", en = "Survived {t} · {money} / {target} Baht", es = "Sobreviviste {t} · {money} / {target} Baht", pt = "Sobreviveu {t} · {money} / {target} Baht", id = "Selamat {t} · {money} / {target} Baht" },
	Baht = { th = "บาท", en = "฿", es = "฿", pt = "฿", id = "฿" },
	Times = { th = "ครั้ง", en = "x", es = "x", pt = "x", id = "x" },
	Units = { th = "ตัว", en = "", es = "", pt = "", id = "" },
	-- สะพานไฟ / นั่งยอง / ผีใหญ่บุกประชิด (server/BigEvents)
	BreakerOff = { th = "สับสะพานไฟลง (ดับไฟร้าน)", en = "Kill the lights", es = "Apagar las luces", pt = "Apagar as luzes", id = "Matikan lampu" },
	BreakerOn = { th = "สับสะพานไฟขึ้น (เปิดไฟ)", en = "Lights on", es = "Encender las luces", pt = "Acender as luzes", id = "Nyalakan lampu" },
	BreakerName = { th = "สะพานไฟ", en = "Breaker Switch", es = "Interruptor", pt = "Disjuntor", id = "Saklar Listrik" },
	Crouch = { th = "นั่งยอง", en = "Crouch", es = "Agacharse", pt = "Agachar", id = "Jongkok" },
	Big_Krasue_Warn = { th = "แสงไฟผีลอยมาจากเถียงนา... ปิดแผงร้าน แล้วสับสะพานไฟดับไฟร้าน!", en = "A ghost light drifts in from the rice hut... close the shutter and kill the lights at the breaker!", es = "Una luz fantasma flota desde la choza del arrozal... ¡cierra la cortina y apaga las luces en el interruptor!", pt = "Uma luz fantasma vem flutuando da cabana do arrozal... feche o portão e apague as luzes no disjuntor!", id = "Cahaya hantu melayang dari gubuk sawah... tutup pintu seng dan matikan lampu di saklar!" },
	Big_Pret_Warn = { th = "เสียงหวีดยาวมาจากถนน... เปรตกำลังมา ปิดแผงร้าน แล้วดับไฟร้าน", en = "A long shriek from the road... a Pret is coming. Close the shutter and kill the shop lights.", es = "Un largo chillido desde el camino... viene un Pret. Cierra la cortina y apaga las luces de la tienda.", pt = "Um grito longo vem da estrada... um Pret está chegando. Feche o portão e apague as luzes da loja.", id = "Jeritan panjang dari arah jalan... Pret datang. Tutup pintu seng dan matikan lampu toko." },
	Big_Funeral_Warn = { th = "ขบวนแห่ศพไร้เสียงกำลังมา... ปิดแผงร้าน แล้วดับไฟ รอให้ผ่านไป", en = "A silent funeral procession approaches... close the shutter, kill the lights and let it pass.", es = "Se acerca un cortejo fúnebre silencioso... cierra la cortina, apaga las luces y déjalo pasar.", pt = "Um cortejo fúnebre silencioso se aproxima... feche o portão, apague as luzes e deixe passar.", id = "Arak-arakan jenazah yang sunyi mendekat... tutup pintu seng, matikan lampu, dan biarkan lewat." },
	Big_Pop_Warn = { th = "มีใครเดินกระตุกมาทางร้าน... ปิดแผงร้าน แล้วดับไฟร้าน", en = "Something twitches its way toward the shop... close the shutter and kill the lights.", es = "Algo se acerca a la tienda dando tirones... cierra la cortina y apaga las luces.", pt = "Algo vem se contorcendo em direção à loja... feche o portão e apague as luzes.", id = "Sesuatu bergerak tersentak-sentak ke arah toko... tutup pintu seng dan matikan lampu." },
	Big_Danger = { th = "มันมาถึงแล้ว... อยู่เงียบๆ ในร้าน", en = "It's here... stay quiet inside.", es = "Ya está aquí... quédate callado adentro.", pt = "Está aqui... fique quieto lá dentro.", id = "Dia sudah di sini... diam di dalam." },
	Big_Pass = { th = "มันผ่านไปแล้ว... สับสะพานไฟขึ้น แล้วเปิดแผงร้านได้", en = "It's gone... turn the lights back on and open the shutter.", es = "Ya se fue... vuelve a encender las luces y abre la cortina.", pt = "Foi embora... acenda as luzes de novo e abra o portão.", id = "Dia sudah pergi... nyalakan lampu lagi dan buka pintu seng." },
	Big_Fail_Lights = { th = "ไฟร้านยังเปิดอยู่... มันเห็นเราแล้ว", en = "The shop lights were on... it saw us.", es = "Las luces de la tienda estaban encendidas... nos vio.", pt = "As luzes da loja estavam acesas... ele nos viu.", id = "Lampu toko menyala... dia melihat kita." },
	Big_Fail_Shutter = { th = "แผงร้านยังเปิดอยู่... มันเห็นเราแล้ว", en = "The shutter was open... it saw us.", es = "La cortina estaba abierta... nos vio.", pt = "O portão estava aberto... ele nos viu.", id = "Pintu seng terbuka... dia melihat kita." },
	Big_Fail_Move = { th = "คุณขยับ... มันเห็นคุณแล้ว", en = "You moved... it saw you.", es = "Te moviste... te vio.", pt = "Você se mexeu... ele te viu.", id = "Kamu bergerak... dia melihatmu." },
	Big_Fail_Crouch = { th = "คุณไม่ได้นั่งยอง... มันเห็นคุณแล้ว", en = "You weren't crouching... it saw you.", es = "No estabas agachado... te vio.", pt = "Você não estava agachado... ele te viu.", id = "Kamu tidak jongkok... dia melihatmu." },
	Big_Fail_Flashlight = { th = "ไฟฉายของคุณยังเปิดอยู่... มันเห็นคุณแล้ว", en = "Your flashlight was on... it saw you.", es = "Tu linterna estaba encendida... te vio.", pt = "Sua lanterna estava ligada... ele te viu.", id = "Sentermu menyala... dia melihatmu." },

	-- ป้ายกฎการเฝ้าร้านข้างฝาในเพิง (แทนกระจกเงา ผู้ใช้ 2026-11-15: MapBuilder.SwapMirrorForRules + client/ShopRulesSign)
	-- ทุกข้อบอกใบ้กลไกจริงในเกม (ห้ามใส่กฎที่เกมไม่มี ผู้เล่นจะทำตามแล้วงง)
	ShopRules_Title = { th = "กฎการเฝ้าร้านหลังเที่ยงคืน", en = "RULES AFTER MIDNIGHT", es = "REGLAS DESPUÉS DE MEDIANOCHE", pt = "REGRAS DEPOIS DA MEIA-NOITE", id = "ATURAN SETELAH TENGAH MALAM" },
	ShopRules_Sub = { th = "อ่านให้จำ ก่อนเข็มนาฬิกาจะชี้เลขสิบสอง", en = "Learn them by heart before the clock strikes twelve.", es = "Apréndelas de memoria antes de que el reloj dé las doce.", pt = "Decore antes do relógio bater doze.", id = "Hafalkan sebelum jam berdentang dua belas kali." },
	ShopRules_1 = {
		th = "๑. ก่อนเติมน้ำมันทุกครั้ง ให้พนมมือสวดขอเจ้าที่เจ้าทางก่อน สิ่งที่ตาเปล่ามองไม่เห็น บทสวดจะเผยให้เห็นเอง",
		en = "1. Before every fill-up, press your palms together and pray to the spirits of this land. What your eyes cannot see, the prayer will show you.", es = "1. Antes de cada carga, junta las palmas y reza a los espíritus de esta tierra. Lo que tus ojos no ven, la oración te lo mostrará.", pt = "1. Antes de cada abastecimento, junte as palmas e reze aos espíritos desta terra. O que seus olhos não veem, a reza vai te mostrar.", id = "1. Sebelum setiap pengisian, rapatkan telapak tangan dan berdoalah kepada roh penjaga tanah ini. Apa yang tak terlihat matamu, doa akan memperlihatkannya.",
	},
	ShopRules_2 = {
		th = "๒. ถ้าคนที่มาเติม... ไม่ใช่คน ห้ามเติมให้เด็ดขาด เข้ามาในร้านแล้วดึงเชือกลดแผงลง อย่าทิ้งใครไว้ข้างนอก",
		en = "2. If the one at the pump... is not a person, do not serve it. Get inside and pull the rope to drop the shutter. Leave no one outside.", es = "2. Si quien está en la bomba... no es una persona, no lo atiendas. Entra y jala la cuerda para bajar la cortina. No dejes a nadie afuera.", pt = "2. Se quem está na bomba... não for uma pessoa, não atenda. Entre e puxe a corda para baixar o portão. Não deixe ninguém do lado de fora.", id = "2. Jika yang berdiri di pompa... bukan manusia, jangan dilayani. Masuk dan tarik tali untuk menurunkan pintu seng. Jangan tinggalkan siapa pun di luar.",
	},
	ShopRules_3 = {
		th = "๓. ถ้าเห็นอะไรยืนอยู่ในดงกล้วย ใต้ต้นไทร หรือกลางทุ่ง ให้ทำเป็นมองไม่เห็น อย่าจ้องมัน ถ้ามันรู้ว่าเราเห็น... มันจะมาหาเรา",
		en = "3. If something stands in the banana grove, under the banyan, or out in the fields, pretend you do not see it. Do not stare. Once it knows you have seen it... it comes for you.", es = "3. Si algo está parado en el platanal, bajo el árbol sagrado o allá en los campos, finge que no lo ves. No lo mires fijamente. En cuanto sepa que lo viste... vendrá por ti.", pt = "3. Se algo estiver parado no bananal, debaixo da figueira-dos-pagodes ou lá nos campos, finja que não vê. Não encare. Quando ele souber que você viu... ele vem atrás de você.", id = "3. Jika ada sesuatu berdiri di kebun pisang, di bawah pohon beringin, atau di tengah sawah, pura-pura tidak melihatnya. Jangan menatap. Begitu dia tahu kamu melihatnya... dia akan datang menghampirimu.",
	},
	ShopRules_4 = {
		th = "๔. ถวายขนมศาลพระภูมิอย่าให้ขาด แล้วคอยดูธูปบนศาลไว้ เติมให้สิ่งที่ไม่ใช่คนครั้งหนึ่ง ธูปดับไปดอกหนึ่ง ดับครบสามดอกเมื่อไหร่ ก็ไม่มีใครคุ้มครองเราอีกแล้ว",
		en = "4. Keep sweets on the spirit house, and watch its incense. Each time you serve something that is not human, one stick goes out. When all three are out, nothing protects you anymore.", es = "4. Mantén dulces en la casa de los espíritus y vigila su incienso. Cada vez que atiendes algo que no es humano, se apaga una varita. Cuando las tres se apaguen, ya nada te protege.", pt = "4. Mantenha doces na casa dos espíritos e cuide do incenso. Cada vez que você atende algo que não é humano, um palito apaga. Quando os três apagarem, nada mais te protege.", id = "4. Selalu taruh kue di rumah arwah, dan perhatikan dupanya. Setiap kali kamu melayani sesuatu yang bukan manusia, satu batang padam. Jika ketiganya padam, tak ada lagi yang melindungimu.",
	},
	ShopRules_5 = {
		th = "๕. ถ้าจิ้งหรีดเงียบกริบไปทั้งทุ่ง แปลว่าบางสิ่งที่ไม่ควรมีอยู่ กำลังมา ลดแผงร้าน สับสะพานไฟลง ปิดไฟฉาย แล้วอยู่นิ่งๆ อย่าขยับ จนกว่ามันจะผ่านไป",
		en = "5. If every cricket in the field falls silent, something that should not exist is coming. Drop the shutter, cut the power at the switch, turn off your flashlight, and stay still until it passes.", es = "5. Si todos los grillos del campo se quedan callados, algo que no debería existir se acerca. Baja la cortina, corta la luz en el interruptor, apaga tu linterna y quédate quieto hasta que pase.", pt = "5. Se todos os grilos do campo ficarem em silêncio, algo que não deveria existir está chegando. Baixe o portão, desligue a energia no disjuntor, apague a lanterna e fique parado até passar.", id = "5. Jika semua jangkrik di sawah mendadak diam, sesuatu yang seharusnya tidak ada sedang datang. Turunkan pintu seng, putus listrik di saklar, matikan sentermu, dan diam sampai dia lewat.",
	},
	ShopRules_Footer = { th = "อยู่ให้ถึงเช้า แล้วพี่จะมารับ", en = "Make it to morning. I'll come get you.", es = "Aguanta hasta la mañana. Yo vengo por ti.", pt = "Aguente até de manhã. Eu venho te buscar.", id = "Bertahanlah sampai pagi. Nanti Abang jemput." },
}

-- ป้ายชื่อที่ลอยตามวัตถุในฉาก (ObjectLabels.client) ชื่อสั้น สุภาพ ไม่อธิบาย
LanguageModule.Labels = {
	GasPump = { th = "ตู้ปั๊มเบนซิน", en = "Petrol Pump", es = "Bomba de Gasolina", pt = "Bomba de Gasolina", id = "Pompa Bensin" },
	DieselPump = { th = "ตู้ปั๊มดีเซล", en = "Diesel Pump", es = "Bomba de Diésel", pt = "Bomba de Diesel", id = "Pompa Solar" },
	Radio = { th = "วิทยุ", en = "Radio", es = "Radio", pt = "Rádio", id = "Radio" },
	CutoutSwitch = { th = "สะพานไฟ", en = "Breaker Switch", es = "Interruptor", pt = "Disjuntor", id = "Saklar Listrik" },
	RejectRope = { th = "เชือกแผงสังกะสี", en = "Shutter Rope", es = "Cuerda de la Cortina", pt = "Corda do Portão", id = "Tali Pintu Seng" },
	MoneyTin = { th = "กระป๋องเก็บเงิน", en = "Money Tin", es = "Lata de Dinero", pt = "Lata de Dinheiro", id = "Kaleng Uang" },
	Generator = { th = "เครื่องปั่นไฟ", en = "Generator", es = "Generador", pt = "Gerador", id = "Genset" },
	AirCompressor = { th = "ถังลม", en = "Air Compressor", es = "Compresor de Aire", pt = "Compressor de Ar", id = "Kompresor Angin" },
	SpiritHouse = { th = "ศาลพระภูมิ", en = "Spirit House", es = "Casa de los Espíritus", pt = "Casa dos Espíritos", id = "Rumah Arwah" },
	KilometerMilestone = { th = "หลักกิโลเมตรที่ 67", en = "Kilometer 67", es = "Kilómetro 67", pt = "Quilômetro 67", id = "Kilometer 67" },
	DistantRiceHut = { th = "เถียงนา", en = "Field Hut", es = "Choza del Campo", pt = "Cabana do Campo", id = "Gubuk Sawah" },
	MarbleBench = { th = "ม้าหินอ่อน", en = "Marble Bench", es = "Banca de Mármol", pt = "Banco de Mármore", id = "Bangku Marmer" },
	BanyanTree = { th = "ต้นไทร", en = "Banyan Tree", es = "Árbol Sagrado", pt = "Figueira-dos-pagodes", id = "Pohon Beringin" },
	IceBox = { th = "ถังน้ำแข็ง", en = "Ice Box", es = "Hielera", pt = "Caixa de Gelo", id = "Kotak Es" },
	Outhouse = { th = "ห้องน้ำ", en = "Outhouse", es = "Letrina", pt = "Casinha", id = "Kakus" },
	Mirror = { th = "กระจก", en = "Mirror", es = "Espejo", pt = "Espelho", id = "Cermin" },
	OwnerPhoto = { th = "รูปเจ้าของร้าน", en = "Owner's Photo", es = "Foto del Dueño", pt = "Foto do Dono", id = "Foto Pemilik" },
	Scarecrow = { th = "หุ่นไล่กา", en = "Scarecrow", es = "Espantapájaros", pt = "Espantalho", id = "Orang-orangan Sawah" },
}

function LanguageModule.GetLabel(key: string, localeId: string?): string
	local entry = LanguageModule.Labels[key]
	if not entry then
		return ""
	end
	return LanguageModule.Pick(entry, localeId)
end

-- สมุดบันทึกผีไทย (Phase 5 ข้อ 2): ชื่อ + คำใบ้วิธีสังเกต เรียงตาม BookOrder
LanguageModule.BookOrder = {
	"Anomaly_Headless",
	"Anomaly_Cemetery",
	"Anomaly_NeckTwist",
	"Anomaly_TaKhon",
	"Anomaly_MirrorGhost",
	-- "Anomaly_GhostWalkIn" ตัดผีเดินมาซื้อทั้งร่างแล้ว (2026-11-16)
	"Outage_Shrouds",
	"Big_Krasue",
	"Big_Pret",
	-- "Big_Funeral" ตัดขบวนแห่ศพแล้ว (2026-11-16)
	-- "Big_Pop" ตัดปอบเคาะแผงแล้ว (2026-11-21)
	"Anomaly_MonkRadio",
	"Anomaly_BloodFuel",
	"Anomaly_BurnedCorpse",
	"Anomaly_ShoulderChild",
	"Anomaly_ShroudPickup",
	"Anomaly_BackFeet",
	-- "Anomaly_NoUmbrella" ตัดระบบฝนตกแล้ว (2026-11-16)
}
LanguageModule.Book = {
	Anomaly_Headless = {
		th = { "ผีหัวขาดซ้อนท้าย", "มีคนซ้อนท้ายแต่ไม่มีหัว คนขับไม่รู้ตัวเลย ลองทักว่า \"ทั้งสองคน\" ดู" },
		en = { "Headless Pillion Rider", "Someone rides pillion with no head. The driver has no idea. Try greeting \"you two\"." }, es = { "Pasajero Sin Cabeza", "Alguien va de pasajero sin cabeza. El conductor no tiene idea. Intenta saludar a 'los dos'." }, pt = { "Garupa Sem Cabeça", "Alguém vai na garupa sem cabeça. O motorista não faz ideia. Tente cumprimentar 'vocês dois'." }, id = { "Penumpang Tanpa Kepala", "Seseorang dibonceng tanpa kepala. Pengendaranya tidak sadar. Coba sapa 'kalian berdua'." },
	},
	Anomaly_Cemetery = {
		th = { "ป้ายมรณะ", "คนขับดูปกติทุกอย่าง แต่พอพนมมือ ป้ายทะเบียนกลายเป็นป้ายหน้าศพ เขียนชื่อของเขาเองกับคำว่ามรณะวันนี้" },
		en = { "Death Plate", "The rider looks perfectly normal. Pray, and the licence plate becomes a funeral name board with their own name and today's date of death." }, es = { "Placa de la Muerte", "El conductor se ve completamente normal. Reza, y la placa se vuelve un letrero funerario con su propio nombre y la fecha de muerte de hoy." }, pt = { "Placa da Morte", "O motoqueiro parece totalmente normal. Reze, e a placa vira uma placa de funeral com o nome dele e a data de morte de hoje." }, id = { "Plat Kematian", "Pengendaranya terlihat normal. Berdoalah, dan plat nomornya berubah jadi papan nama duka berisi namanya sendiri dan tanggal kematian hari ini." },
	},
	Anomaly_WheelHair = {
		th = { "ผมพันล้อ", "เส้นผมยาวสีดำพันล้อแน่น ลูกค้าบ่นว่าล้อหนักเหมือนมีใครดึง" },
		en = { "Hair in the Wheels", "Long black hair wound tight around the wheels. The rider says something is pulling them." }, es = { "Cabello en las Ruedas", "Cabello negro y largo enredado con fuerza en las ruedas. El conductor dice que algo lo jala." }, pt = { "Cabelo nas Rodas", "Cabelos pretos e compridos enrolados com força nas rodas. O motoqueiro diz que algo está puxando." }, id = { "Rambut di Roda", "Rambut hitam panjang melilit kencang di roda. Pengendaranya bilang ada yang menarik." },
	},
	Anomaly_NeckTwist = {
		th = { "คอหัก 180 องศา", "หัวคนขับหันกลับหลัง แต่ยังพูดคุยเหมือนปกติ" },
		en = { "Twisted Neck", "The driver's head faces backward, yet they talk as if nothing is wrong." }, es = { "Cuello Torcido", "La cabeza del conductor mira hacia atrás, pero habla como si nada pasara." }, pt = { "Pescoço Torcido", "A cabeça do motorista está virada para trás, mas ele fala como se nada estivesse errado." }, id = { "Leher Terpuntir", "Kepala pengemudinya menghadap ke belakang, tapi dia bicara seolah tidak ada apa-apa." },
	},
	Anomaly_CreepySmile = {
		th = { "ยิ้มฉีกถึงหู", "ตาโปน ยิ้มกว้างผิดธรรมชาติ แล้วขอให้คุณยิ้มตอบ" },
		en = { "Ear-to-Ear Grin", "Bulging eyes and an unnatural grin that asks you to smile back." }, es = { "Sonrisa de Oreja a Oreja", "Ojos saltones y una sonrisa nada natural que te pide que sonrías de vuelta." }, pt = { "Sorriso de Orelha a Orelha", "Olhos esbugalhados e um sorriso nada natural que pede para você sorrir de volta." }, id = { "Senyum Lebar", "Mata melotot dan senyum tak wajar yang memintamu balas tersenyum." },
	},
	Anomaly_TaKhon = {
		th = { "หน้ากากผีตาโขน", "คนขับใส่หน้ากากผีตาโขนรูตาดำกลวง เอียงหน้ากากมามองคุณ แล้วสะบัดกลับ" },
		en = { "Phi Ta Khon Mask", "The rider wears a Phi Ta Khon mask with hollow black eyes. It tilts toward you, then snaps back." }, es = { "Máscara de Phi Ta Khon", "El conductor lleva una máscara de Phi Ta Khon con ojos negros y huecos. Se inclina hacia ti y vuelve de golpe." }, pt = { "Máscara de Phi Ta Khon", "O motoqueiro usa uma máscara de Phi Ta Khon com olhos pretos vazios. Ela se inclina na sua direção e volta de repente." }, id = { "Topeng Phi Ta Khon", "Pengendaranya memakai topeng Phi Ta Khon bermata hitam kosong. Topengnya miring ke arahmu, lalu menyentak kembali." },
	},
	Anomaly_MirrorGhost = {
		th = { "ผีในกระจกมองข้าง", "ผู้หญิงผมยาวนั่งซ้อนท้าย ค่อยๆ หันไปมองกระจกมองข้าง คนขับไม่เคยรู้ว่ามีเธออยู่" },
		en = { "Ghost in the Side Mirror", "A long-haired woman rides pillion and slowly turns to the side mirror. The rider never knew she was there." }, es = { "Fantasma en el Retrovisor", "Una mujer de cabello largo va de pasajera y gira despacio hacia el espejo retrovisor. El conductor nunca supo que estaba ahí." }, pt = { "Fantasma no Retrovisor", "Uma mulher de cabelo comprido vai na garupa e se vira devagar para o retrovisor. O motoqueiro nunca soube que ela estava ali." }, id = { "Hantu di Spion", "Seorang wanita berambut panjang dibonceng dan perlahan menoleh ke kaca spion. Pengendaranya tidak pernah tahu dia ada di sana." },
	},
	Anomaly_GhostWalkIn = {
		th = { "ผีเดินมาซื้อเอง", "ไม่แปลงร่างเลย เดินมาทั้งร่างผีแล้วสั่งน้ำมันเหมือนคนปกติ อย่าเติมให้" },
		en = { "Undisguised Customer", "It doesn't even bother to hide. A ghost walks up and orders fuel like anyone else. Don't serve it." }, es = { "Cliente Sin Disfraz", "Ni siquiera se molesta en esconderse. Un fantasma llega y pide combustible como cualquiera. No lo atiendas." }, pt = { "Cliente Sem Disfarce", "Nem se dá ao trabalho de se esconder. Um fantasma chega e pede combustível como qualquer um. Não atenda." }, id = { "Pembeli Tanpa Penyamaran", "Dia bahkan tidak repot bersembunyi. Hantu berjalan mendekat dan memesan bensin seperti orang lain. Jangan dilayani." },
	},
	Outage_Shrouds = {
		th = { "ทุ่งศพห่อผ้า", "ไฟดับแล้วพนมมือ จะเห็นศพห่อผ้าขาวยืนนิ่งอยู่เต็มทุ่งรอบร้าน" },
		en = { "Field of Shrouds", "Pray during a blackout and you'll see shrouded corpses standing all over the fields around the shop." }, es = { "Campo de Mortajas", "Reza durante un apagón y verás cadáveres amortajados de pie por todos los campos alrededor de la tienda." }, pt = { "Campo de Mortalhas", "Reze durante um apagão e você verá cadáveres amortalhados de pé por todos os campos em volta da loja." }, id = { "Sawah Penuh Pocong", "Berdoalah saat listrik padam dan kamu akan melihat mayat berkafan berdiri di seluruh sawah sekitar toko." },
	},
	Big_Krasue = {
		th = { "แสงไฟผีกระสือ", "ดวงไฟส้มลอยจากเถียงนามาบินวนรอบเพิง ปิดแผงร้านแล้วดับไฟ รอจนมันลอยกลับไป" },
		en = { "Krasue Light", "An orange light floats from the rice hut and circles the shed. Close the shutter and kill the lights until it drifts away." }, es = { "Luz de Krasue", "Una luz naranja flota desde la choza del arrozal y rodea la tienda. Cierra la cortina y apaga las luces hasta que se aleje." }, pt = { "Luz da Krasue", "Uma luz laranja flutua da cabana do arrozal e circula a loja. Feche o portão e apague as luzes até ela ir embora." }, id = { "Cahaya Krasue", "Cahaya jingga melayang dari gubuk sawah dan berputar mengelilingi toko. Tutup pintu seng dan matikan lampu sampai cahayanya menjauh." },
	},
	Big_Pret = {
		th = { "เปรตเดินผ่าน", "เงาขายาวสูงเท่าต้นตาลเดินผ่านหน้าร้าน ปิดแผงร้านแล้วดับไฟ รอจนมันเดินพ้นไป" },
		en = { "Passing Pret", "A shadow as tall as a palm tree walks past the shop. Close the shutter and kill the lights until it is gone." }, es = { "Pret de Paso", "Una sombra alta como una palmera pasa junto a la tienda. Cierra la cortina y apaga las luces hasta que se vaya." }, pt = { "Pret de Passagem", "Uma sombra alta como uma palmeira passa pela loja. Feche o portão e apague as luzes até ela sumir." }, id = { "Pret yang Lewat", "Bayangan setinggi pohon lontar berjalan melewati toko. Tutup pintu seng dan matikan lampu sampai dia pergi." },
	},
	Big_Funeral = {
		th = { "ขบวนแห่ศพไร้เสียง", "คนชุดขาวลอยผ่านถนนดินในหมอก ปิดแผงร้าน แล้วดับไฟ รอจนขบวนผ่านไป" },
		en = { "Silent Funeral Procession", "White-clad mourners glide down the dirt road. Close the shutter and kill the lights until they pass." }, es = { "Cortejo Fúnebre Silencioso", "Dolientes vestidos de blanco se deslizan por el camino de tierra. Cierra la cortina y apaga las luces hasta que pasen." }, pt = { "Cortejo Fúnebre Silencioso", "Enlutados vestidos de branco deslizam pela estrada de terra. Feche o portão e apague as luzes até eles passarem." }, id = { "Arak-arakan Jenazah yang Sunyi", "Pelayat berpakaian putih melayang di jalan tanah. Tutup pintu seng dan matikan lampu sampai mereka lewat." },
	},
	Big_Pop = {
		th = { "ปอบเคาะแผง", "ผีปอบมาเคาะแผงสังกะสีหน้าร้าน ปิดแผงแล้วดับไฟ รอจนมันเดินจากไป" },
		en = { "Phi Pop at the Shutter", "A Phi Pop knocks on the tin shutter. Close it and kill the lights until it leaves." }, es = { "Phi Pop en la Cortina", "Un Phi Pop golpea la cortina de lámina. Ciérrala y apaga las luces hasta que se vaya." }, pt = { "Phi Pop no Portão", "Um Phi Pop bate no portão de zinco. Feche e apague as luzes até ele ir embora." }, id = { "Phi Pop di Pintu Seng", "Phi Pop mengetuk pintu seng. Tutup pintunya dan matikan lampu sampai dia pergi." },
	},
	Anomaly_MonkRadio = {
		th = { "วิทยุสวดศพ", "วิทยุในร้านเปลี่ยนเป็นเพลงงานศพเอง แต่ลูกค้ากลับชมว่าเพลงเพราะ" },
		en = { "Funeral Radio", "The shop radio starts playing funeral music by itself, yet the customer praises the song." }, es = { "Radio Fúnebre", "La radio de la tienda empieza a tocar música de funeral sola, y aun así el cliente elogia la canción." }, pt = { "Rádio Fúnebre", "O rádio da loja começa a tocar música de funeral sozinho, e mesmo assim o cliente elogia a música." }, id = { "Radio Duka", "Radio toko tiba-tiba memutar musik pemakaman sendiri, tapi pembelinya malah memuji lagunya." },
	},
	Anomaly_Tani = {
		th = { "ผีตานี", "ผู้หญิงยืนรออยู่หลังกอกล้วย ลูกค้าถามว่าเธอรอใครอยู่" },
		en = { "Phi Tani", "A woman waits behind the banana grove. The customer asks who she is waiting for." }, es = { "Phi Tani", "Una mujer espera detrás del platanal. El cliente pregunta a quién está esperando." }, pt = { "Phi Tani", "Uma mulher espera atrás do bananal. O cliente pergunta por quem ela está esperando." }, id = { "Phi Tani", "Seorang wanita menunggu di balik kebun pisang. Pembelinya bertanya dia menunggu siapa." },
	},
	Anomaly_Scarecrow = {
		th = { "หุ่นไล่กาเดินได้", "หุ่นไล่กาย้ายมายืนใกล้ร้าน ตาแดงเรือง ลูกค้าบอกว่ามันเดินตามมา" },
		en = { "Wandering Scarecrow", "The scarecrow now stands near the shop, eyes glowing red. The customer says it followed them." }, es = { "Espantapájaros Errante", "El espantapájaros ahora está cerca de la tienda, con los ojos rojos brillando. El cliente dice que lo siguió." }, pt = { "Espantalho Andarilho", "O espantalho agora está perto da loja, com olhos vermelhos brilhando. O cliente diz que ele o seguiu." }, id = { "Orang-orangan Sawah Berkeliaran", "Orang-orangan sawah kini berdiri dekat toko dengan mata menyala merah. Pembelinya bilang benda itu mengikutinya." },
	},
	Anomaly_BloodFuel = {
		th = { "น้ำมันเลือด", "น้ำมันในหลอดแก้วกลายเป็นสีเลือด ลูกค้าบอกว่าหอมดี" },
		en = { "Blood Fuel", "The fuel in the glass turns blood red. The customer says it smells good." }, es = { "Gasolina de Sangre", "La gasolina del cilindro de vidrio se vuelve rojo sangre. El cliente dice que huele bien." }, pt = { "Gasolina de Sangue", "A gasolina no vidro fica vermelho-sangue. O cliente diz que o cheiro é bom." }, id = { "Bensin Darah", "Bensin di tabung kaca berubah merah darah. Pembelinya bilang baunya enak." },
	},
	Anomaly_BurnedCorpse = {
		th = { "ศพไฟคลอกมาซื้อน้ำมัน", "มองตาเปล่าเป็นชาวบ้านปกติ แต่พอพนมมือเห็นร่างจริงไหม้เกรียมเป็นตอตะโก มีควันดำลอยกรุ่น" },
		en = { "Charred Corpse", "Looks like an ordinary villager to the naked eye, but prayer reveals a scorched, smoking corpse." }, es = { "Cadáver Calcinado", "A simple vista parece un aldeano común, pero la oración revela un cadáver quemado que todavía echa humo." }, pt = { "Cadáver Carbonizado", "A olho nu parece um morador comum, mas a reza revela um cadáver queimado ainda soltando fumaça." }, id = { "Mayat Hangus", "Dengan mata telanjang terlihat seperti warga biasa, tapi doa memperlihatkan mayat hangus yang masih berasap." },
	},
	Anomaly_ShoulderChild = {
		th = { "ผีเด็กขี่คอ", "ลูกค้าดูเหมือนมาคนเดียว แต่พอพนมมือเงยดูที่บ่าจะเห็นผีเด็กตัวซีดขี่คอเกาะหัวจ้องลงมา" },
		en = { "Child on the Shoulders", "The customer seems alone, but praying reveals a pale ghost child straddling their neck and staring down." }, es = { "Niño en los Hombros", "El cliente parece estar solo, pero la oración revela a un niño fantasma pálido montado en su cuello, mirando hacia abajo." }, pt = { "Criança nos Ombros", "O cliente parece estar sozinho, mas a reza revela uma criança fantasma pálida montada no pescoço dele, olhando para baixo." }, id = { "Anak di Pundak", "Pembelinya tampak sendirian, tapi doa memperlihatkan hantu anak pucat duduk di lehernya sambil menatap ke bawah." },
	},
	Anomaly_ShroudPickup = {
		th = { "ศพห่อผ้าท้ายกระบะ", "คนขับกระบะดูปกติทุกอย่าง แต่พอพนมมือแล้วเดินไปดูท้ายรถ จะเห็นศพห่อผ้าขาวยืนอยู่ในคอก หันหน้ามองตาม" },
		en = { "Shroud in the Truck Bed", "The pickup driver looks perfectly normal. Pray and walk round to the back: a shrouded corpse stands in the bed, its head turning to follow you." }, es = { "Mortaja en la Caja", "El conductor de la camioneta se ve normal. Reza y rodéala hasta atrás: un cadáver amortajado está de pie en la caja, girando la cabeza para seguirte." }, pt = { "Mortalha na Caçamba", "O motorista da caminhonete parece normal. Reze e dê a volta até a traseira: um cadáver amortalhado está de pé na caçamba, virando a cabeça para te seguir." }, id = { "Pocong di Bak Truk", "Sopir pikapnya terlihat normal. Berdoalah dan berjalan ke belakang: mayat berkafan berdiri di bak truk, kepalanya menoleh mengikutimu." },
	},
	Anomaly_BackFeet = {
		th = { "ผีเท้ากลับหลัง", "คนเดินมาซื้อน้ำมันดูเหมือนชาวบ้านทั่วไป แต่พอพนมมือแล้วก้มดูเท้า ปลายเท้าสองข้างชี้ไปข้างหลัง" },
		en = { "Backward Feet", "The walk-in customer looks like any villager. Pray and look down: both feet point backwards." }, es = { "Pies al Revés", "El cliente que llega a pie parece cualquier aldeano. Reza y mira hacia abajo: los dos pies apuntan hacia atrás." }, pt = { "Pés ao Contrário", "O cliente que chega a pé parece um morador qualquer. Reze e olhe para baixo: os dois pés apontam para trás." }, id = { "Kaki Terbalik", "Pembeli yang datang jalan kaki terlihat seperti warga biasa. Berdoalah dan lihat ke bawah: kedua kakinya menghadap ke belakang." },
	},
	Anomaly_NoUmbrella = {
		th = { "คนตัวแห้งกลางฝน", "เดินฝ่าฝนหนักมาโดยไม่กางร่ม แต่ตัวแห้งสนิท" },
		en = { "Dry in the Rain", "Walks in through the downpour without an umbrella, yet completely dry." }, es = { "Seco Bajo la Lluvia", "Llega caminando bajo el aguacero sin paraguas, pero completamente seco." }, pt = { "Seco na Chuva", "Chega a pé no meio do temporal sem guarda-chuva, mas completamente seco." }, id = { "Kering di Tengah Hujan", "Berjalan menembus hujan deras tanpa payung, tapi tubuhnya kering sama sekali." },
	},
}

-- คืน (ชื่อ, คำอธิบาย) ของผีในสมุด
function LanguageModule.GetBook(key: string, localeId: string?): (string, string)
	local entry = LanguageModule.Book[key]
	if not entry then
		return key, ""
	end
	local t = LanguageModule.Pick(entry, localeId)
	return t[1], t[2]
end

-- รหัสภาษา / LocaleId ("th", "pt-br", "es-mx", "id-id" ...) -> รหัสที่รองรับ (ภาษาอื่น / nil = "en")
function LanguageModule.Normalize(lang: string?): string
	local l = if lang then string.sub(string.lower(lang), 1, 2) else ""
	return if SUPPORTED[l] then l else "en"
end

-- เลือกข้อความตามภาษา: ภาษานั้นยังไม่แปล = อังกฤษ (ไม่มีอังกฤษ = ไทย) · entry เป็นอะไรก็ได้ (string / table คู่ชื่อ+คำอธิบาย)
function LanguageModule.Pick(entry: { [string]: any }, localeId: string?): any
	local v = entry[LanguageModule.Normalize(localeId)]
	if v == nil then
		v = entry.en
	end
	if v == nil then
		v = entry.th
	end
	return v
end

-- ข้อความเขียนสดในสคริปต์ (ไม่อยู่ในตาราง): LanguageModule.Tr(lang, "ไทย", "English", { id = "...", pt = "...", es = "..." })
function LanguageModule.Tr(localeId: string?, th: string, en: string, more: { [string]: string }?): string
	local l = LanguageModule.Normalize(localeId)
	if l == "th" then
		return th
	end
	if more and more[l] then
		return more[l]
	end
	return en
end

-- ประเทศของผู้เล่น (LocalizationService:GetCountryRegionForPlayerAsync) -> ภาษาเริ่มต้น
local COUNTRY_LANG: { [string]: string } = {
	TH = "th",
	ID = "id",
	BR = "pt", PT = "pt", AO = "pt", MZ = "pt",
	ES = "es", MX = "es", AR = "es", CO = "es", CL = "es", PE = "es", VE = "es", EC = "es", GT = "es", CU = "es",
	BO = "es", DO = "es", HN = "es", PY = "es", SV = "es", NI = "es", CR = "es", PA = "es", UY = "es", PR = "es",
}
function LanguageModule.FromCountry(region: string?): string?
	return if region then COUNTRY_LANG[string.upper(region)] else nil
end

-- มือถือ: ตั้งเป็น true จากฝั่ง Client (Shared.DeviceInput) -> GetUI ใช้ฉบับ "<key>_Touch" ถ้ามี
LanguageModule.TouchMode = false

function LanguageModule.GetUI(key: string, localeId: string?): string
	local entry = LanguageModule.UI[key]
	if LanguageModule.TouchMode and string.sub(key, -6) ~= "_Touch" then
		entry = LanguageModule.UI[key .. "_Touch"] or entry
	end
	if not entry then
		return key
	end
	return LanguageModule.Pick(entry, localeId)
end

-- vars = { amount = 100 } แทนที่ {amount} ในประโยค
function LanguageModule.GetText(key: string, localeId: string?, vars: { [string]: any }?): string
	local entry = LanguageModule.Dialogues[key]
	if not entry then
		return key
	end
	local s = LanguageModule.Pick(entry, localeId)
	if vars then
		s = string.gsub(s, "{(%w+)}", function(k)
			local v = vars[k]
			return if v ~= nil then tostring(v) else nil
		end)
	end
	return s
end


-- ฝั่ง Client: เครื่องจอสัมผัส (ไม่มีคีย์บอร์ด หรือจอเตี้ยแบบมือถือ) ใช้ข้อความแบบ "แตะ" แทนปุ่มคีย์
--   (จอเตี้ย < 500 ครอบเครื่องจำลองมือถือใน Studio ที่รายงานว่ามีคีย์บอร์ด / โน้ตบุ๊กจอสัมผัสจอสูงกว่านี้)
do
	local RunService = game:GetService("RunService")
	if RunService:IsClient() then
		local UserInputService = game:GetService("UserInputService")
		local cam = workspace.CurrentCamera
		LanguageModule.TouchMode = UserInputService.TouchEnabled
			and (not UserInputService.KeyboardEnabled or (cam ~= nil and cam.ViewportSize.Y < 500))
	end
end

return LanguageModule
