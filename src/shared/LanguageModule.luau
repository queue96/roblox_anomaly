-- LanguageModule.luau
-- ระบบเก็บข้อความ 2 ภาษา (TH / EN) สำหรับคำพูดลูกค้าและชื่อผีในเกม "ปั๊มหลอดท้ายทุ่ง"

local LanguageModule = {}

LanguageModule.Dialogues = {
	Normal_Uncle = {
		th = "ไอ้หนู เติมเบนซินหลอดนึง 100 บาท ลุงจะรีบไปวิดน้ำเข้านา!",
		en = "Kid, fill up one glass cylinder for 100 Baht. I need to pump water into my rice field!",
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
}

-- ข้อความหน้าจอ (HUD)
LanguageModule.UI = {
	Money = { th = "เงินในกระป๋อง", en = "Money Tin" },
	Incense = { th = "ธูปศาลพระภูมิ", en = "Shrine Incense" },
	Win = { th = "ครบ 500฿ แล้ว! ปิดร้านกลับบ้านได้ รอดไปอีกคืน", en = "500 Baht reached! You survived the night." },
	Lose = { th = "ธูปดับหมดแล้ว... ศาลพระภูมิคุ้มครองไม่ไหวอีกต่อไป", en = "All the incense is out... the shrine can no longer protect you." },
	Jumpscare = { th = "คุณเติมน้ำมันให้ผี!", en = "You fueled a ghost!" },
	NewNight = { th = "คืนใหม่เริ่มแล้ว... ระวังลูกค้าแปลกๆ", en = "A new night begins... beware of strange customers." },
}

function LanguageModule.GetUI(key: string, localeId: string?): string
	local entry = LanguageModule.UI[key]
	if not entry then
		return key
	end
	if localeId and string.find(string.lower(localeId), "th") then
		return entry.th
	end
	return entry.en
end

function LanguageModule.GetText(key: string, localeId: string?): string
	local entry = LanguageModule.Dialogues[key]
	if not entry then
		return key
	end
	if localeId and string.find(string.lower(localeId), "th") then
		return entry.th
	end
	return entry.en
end

return LanguageModule
