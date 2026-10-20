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
}

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
