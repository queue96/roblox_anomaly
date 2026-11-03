--!strict
-- HumanEmotes.luau (ReplicatedStorage.Shared) — ท่าอารมณ์ + หน้าตา ของตัวละครชาวบ้าน (human_base) ทั้ง NPC และผู้เล่น
--
-- ท่า (ไม่ต้องอัปโหลด animation): ปั้นใน assets/models/human_base/build_anims.py (EMOTES) -> ข้อมูลกระดูก
-- src/shared/HumanClipData.luau (tools/blender/clips_to_luau.py) -> client/HumanEmotesRunner เขียน Bone.Transform
-- ทับท่าที่ Animator เล่นอยู่ (ยืน/เดิน) ทุกเครื่อง เรียกจาก server หรือ client ก็ได้ (server = ทุกคนเห็น)
--
--   HumanEmotes.Play(char, "laugh")            -- หัวเราะ (วนจนสั่งหยุด)
--   HumanEmotes.Play(char, "startle")          -- ตกใจ (เล่นครั้งเดียวแล้วค้างท่าสุดท้าย)
--   HumanEmotes.Play(char, "sad", 4)           -- เล่น 4 วินาทีแล้วหยุดเอง
--   HumanEmotes.Stop(char)                     -- กลับท่าเดิม (ค่อยๆ คืน 0.3 วิ)
--   ชื่อท่า: laugh หัวเราะ, cheer ดีใจ, startle ตกใจ, sad เสียใจ, angry โกรธ,
--            hurt_lying นอนเจ็บจากอุบัติเหตุ, dead_lying นอนตาย (นอนหงายบนพื้นตรงจุดที่ยืน)
--
-- หน้าตา: สลับ SurfaceAppearance ผิว (ภาพหน้าวาดใน build_skin.py FACES) ทุกเครื่องเห็นเหมือนกัน
--   HumanEmotes.SetFace(char, "cry")           -- ค้างหน้านี้ไว้   / SetFace(char, nil) = หน้าปกติ
--   ชื่อหน้า: blink หลับตา, squint ตาหรี่, dead ตาย, cry ร้องไห้, ghost ผีหลอก, ghost_cry ผีร้องไห้ (น้ำตาเลือด),
--            angry โกรธ, injured บาดเจ็บ (หัวแตก + เลือดที่แขน)
--   กะพริบตาอัตโนมัติ: ทุกตัวที่หน้าปกติกะพริบเองทุก 2-6 วิ (ปิดด้วย char:SetAttribute("NoBlink", true))
--   ท่าบางท่าเปลี่ยนหน้าให้เองถ้ายังไม่ได้ตั้งหน้าไว้ (EMOTE_FACE)
--
-- ขาเดินของคนเต้นตามขบวน: model:SetAttribute("WalkLegs", ความเร็ว studs/วิ) = ขา/สะโพกใช้ท่าเดิน ตัว หัว แขนเต้นต่อ
--   (0 หรือ nil = เต้นเต็มตัว) ค่อยๆ ผสมเข้า/ออก ไม่กระตุก — HumanEmotes.SetWalkLegs(model, speed)
local CollectionService = game:GetService("CollectionService")

local HumanEmotes = {}
HumanEmotes.TAG = "HumanEmote" -- client/HumanEmotesRunner เล่นท่าเฉพาะตัวที่ติด tag นี้

HumanEmotes.EMOTES = { "laugh", "cheer", "startle", "sad", "angry", "hurt_lying", "dead_lying" }
HumanEmotes.FACES = { "blink", "squint", "dead", "cry", "ghost", "ghost_cry", "angry", "injured" }
-- ท่าที่มีหน้าตาคู่กัน (ใช้เมื่อยังไม่ได้ SetFace เอง)
HumanEmotes.EMOTE_FACE = {
	laugh = "squint",
	sad = "cry",
	angry = "angry",
	hurt_lying = "injured",
	dead_lying = "dead",
}

local function now(): number
	return workspace:GetServerTimeNow()
end

function HumanEmotes.Play(char: Model, name: string, seconds: number?)
	CollectionService:AddTag(char, HumanEmotes.TAG)
	char:SetAttribute("Emote", name)
	char:SetAttribute("EmoteStart", now())
	char:SetAttribute("EmoteStop", nil)
	if seconds then
		local start = char:GetAttribute("EmoteStart")
		task.delay(seconds, function()
			if char.Parent and char:GetAttribute("EmoteStart") == start then
				HumanEmotes.Stop(char)
			end
		end)
	end
end

function HumanEmotes.Stop(char: Model)
	if char:GetAttribute("Emote") ~= nil then
		char:SetAttribute("EmoteStop", now())
	end
end

function HumanEmotes.Playing(char: Model): string?
	local e = char:GetAttribute("Emote")
	return if type(e) == "string" and char:GetAttribute("EmoteStop") == nil then e else nil
end

function HumanEmotes.SetFace(char: Model, face: string?)
	CollectionService:AddTag(char, HumanEmotes.TAG)
	char:SetAttribute("Face", face)
end

function HumanEmotes.SetWalkLegs(m: Model, speed: number)
	if speed > 0 and not CollectionService:HasTag(m, HumanEmotes.TAG) then
		CollectionService:AddTag(m, HumanEmotes.TAG)
	end
	local cur = m:GetAttribute("WalkLegs")
	-- ปัดค่าไม่ให้ส่ง attribute ทุกเฟรม
	local v = math.floor(speed * 2 + 0.5) / 2
	if cur ~= v then
		m:SetAttribute("WalkLegs", v)
	end
end

return HumanEmotes
