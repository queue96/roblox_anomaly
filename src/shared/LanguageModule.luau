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
	Ghost_Rejected = { th = "แก... รู้ได้ยังไง...", en = "You... how did you know..." },
	Ghost_NoOne = { th = "ไม่มีใครอยู่... งั้นเดี๋ยวกลับมาใหม่นะ...", en = "No one here... I'll come back later..." },
}

-- ชื่อลูกค้า (แสดงบนหัวกล่องคำพูด จะได้จำกันได้ ผีก็ปลอมใช้ชื่อเดียวกัน)
LanguageModule.Names = {
	Name_Sommai = { th = "ลุงสมหมาย", en = "Uncle Sommai" },
	Name_Chaem = { th = "ป้าแช่ม", en = "Auntie Chaem" },
	Name_Ton = { th = "น้องต้น", en = "Ton" },
	Name_Boonmee = { th = "พี่บุญมี", en = "Boonmee" },
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
	Win = { th = "ครบ 500฿ แล้ว! ปิดร้านกลับบ้านได้ รอดไปอีกคืน", en = "500 Baht reached! You survived the night." },
	Lose = { th = "ธูปดับหมดแล้ว... ศาลพระภูมิคุ้มครองไม่ไหวอีกต่อไป", en = "All the incense is out... the shrine can no longer protect you." },
	Jumpscare = { th = "คุณเติมน้ำมันให้ผี!", en = "You fueled a ghost!" },
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
	HintHold = { th = "กดค้าง เติมน้ำมัน / ปิดร้าน", en = "Hold: Fill Up / Close Shop" },
	-- ตอบราคา (ใครตอบก่อนได้ก่อน)
	ReplyTitle = { th = "ตอบลูกค้า (ใครตอบก่อนได้ก่อน)", en = "Reply (first answer counts)" },
	Reply_80 = { th = "80 บาท", en = "80 Baht" },
	Reply_100 = { th = "100 บาท", en = "100 Baht" },
	Reply_120 = { th = "120 บาท", en = "120 Baht" },
	-- เปิดร้านก่อนเริ่มคืน
	OpenShop = { th = "เปิดร้าน", en = "Open Shop" },
	WaitOpen = { th = "ร้านยังปิดอยู่... ไปดึงเชือกเปิดแผงสังกะสีเพื่อเริ่มคืนนี้", en = "The shop is closed... pull the shutter rope to begin the night." },
}

-- ป้ายชื่อที่ลอยตามวัตถุในฉาก (ObjectLabels.client) ชื่อสั้น สุภาพ ไม่อธิบาย
LanguageModule.Labels = {
	GasPump = { th = "ตู้ปั๊มน้ำมัน", en = "Gas Pump" },
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
