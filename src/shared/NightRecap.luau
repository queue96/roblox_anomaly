--!strict
-- NightRecap.luau (ReplicatedStorage.Shared) — สรุปคืนนี้: เวลาที่เฝ้าร้าน + ผีลูกค้าทุกตัว (ผู้ใช้ 2026-11-08)
--   ใช้ทั้งหน้าสรุปผลตอนชนะ (client/CutsceneController) และจอตาย (client/DeathScreen)
--   ข้อมูลจาก server/CoreLoop.Recap(): { time = วินาที, ghosts = { { key, result, t } }, team, target }
--   ผีที่เติมให้ / ปล่อยไป: บอก "จุดสังเกต" (คำใบ้จากสมุดผี) คืนหน้าจะได้จับได้
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LanguageModule = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LanguageModule")) :: any

local NightRecap = {}

export type Style = {
	font: Font,
	text: Color3,
	dim: Color3,
	good: Color3,
	bad: Color3,
	line: Color3,
	size: number?, -- ขนาดตัวอักษรชื่อผี
	maxHeight: number?, -- รายการยาวเกินนี้ = เลื่อนดู
}

local function fill(s: string, vars: { [string]: any }): string
	return (string.gsub(s, "{(%w+)}", function(k)
		local v = vars[k]
		return if v ~= nil then tostring(v) else "{" .. k .. "}"
	end))
end

function NightRecap.FormatTime(seconds: number?, lang: string): string
	local sec = math.max(0, math.floor(seconds or 0))
	return fill(LanguageModule.GetUI("RecapTime", lang), { m = sec // 60, s = sec % 60 })
end

local RESULT_KEY = { caught = "RecapCaught", fooled = "RecapFooled", gone = "RecapGone" }

local function text(parent: Instance, t: string, size: number, color: Color3, font: Font, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = t
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, size + 6)
	for k, v in pairs(props or {}) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- รายการผีคืนนี้ (หัวข้อ + แถวละตัว เรียงตามเวลา) คืน Frame ที่กว้างเต็ม parent สูงตามเนื้อหา (ไม่เกิน maxHeight แล้วเลื่อนดูได้)
function NightRecap.Build(parent: Instance, recap: { [string]: any }?, lang: string, style: Style, order: number?): Frame
	local size = style.size or 16
	local root = Instance.new("Frame")
	root.Name = "NightRecap"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.LayoutOrder = order or 0
	root.Parent = parent
	local rl = Instance.new("UIListLayout")
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Padding = UDim.new(0, 4)
	rl.Parent = root

	text(root, LanguageModule.GetUI("RecapGhosts", lang), size - 2, style.dim, style.font, { LayoutOrder = 1 })
	local ghosts = (recap and recap.ghosts) or {}
	if #ghosts == 0 then
		text(root, LanguageModule.GetUI("RecapNoGhosts", lang), size - 1, style.text, style.font, { LayoutOrder = 2 })
		return root
	end

	local sf = Instance.new("ScrollingFrame")
	sf.LayoutOrder = 2
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 4
	sf.ScrollBarImageColor3 = style.line
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.CanvasSize = UDim2.new()
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Size = UDim2.new(1, 0, 0, 40)
	sf.Parent = root
	local ll = Instance.new("UIListLayout")
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding = UDim.new(0, 6)
	ll.Parent = sf
	local maxH = style.maxHeight or 180
	local function fit()
		sf.Size = UDim2.new(1, 0, 0, math.min(ll.AbsoluteContentSize.Y, maxH))
	end
	ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)

	for i, g in ipairs(ghosts) do
		local key = tostring(g.key)
		local title, tell = LanguageModule.GetBook(key, lang)
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Parent = sf
		local rowList = Instance.new("UIListLayout")
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Padding = UDim.new(0, 1)
		rowList.Parent = row

		local top = Instance.new("Frame")
		top.LayoutOrder = 1
		top.BackgroundTransparency = 1
		top.Size = UDim2.new(1, 0, 0, size + 6)
		top.Parent = row
		local good = g.result == "caught"
		local at = fill(LanguageModule.GetUI("RecapAt", lang), { m = math.floor((tonumber(g.t) or 0) / 60) + 1 })
		text(top, at, size - 3, style.dim, style.font, { Size = UDim2.new(0.2, 0, 1, 0) })
		text(top, title, size, style.text, style.font, { Size = UDim2.new(0.56, 0, 1, 0), Position = UDim2.fromScale(0.2, 0), TextTruncate = Enum.TextTruncate.AtEnd })
		text(top, LanguageModule.GetUI(RESULT_KEY[g.result] or "RecapGone", lang), size - 1, if good then style.good else style.bad, style.font, {
			Size = UDim2.new(0.24, 0, 1, 0),
			Position = UDim2.fromScale(0.76, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		-- พลาด / ปล่อยไป: บอกจุดสังเกต
		if not good and tell ~= "" then
			-- เยื้องให้ตรงกับชื่อผี (ช่องเวลา 20% ทางซ้าย)
			local holder = Instance.new("Frame")
			holder.LayoutOrder = 2
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.new(1, 0, 0, 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y
			holder.Parent = row
			text(holder, LanguageModule.GetUI("RecapTell", lang) .. tell, size - 3, style.dim, style.font, {
				Position = UDim2.fromScale(0.2, 0),
				Size = UDim2.new(0.8, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextWrapped = true,
			})
		end
	end
	task.defer(fit)
	return root
end

return NightRecap
