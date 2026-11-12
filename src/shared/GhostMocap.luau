--!strict
-- GhostMocap.luau — does a ghost clip come from GhostClipData (client/GhostAnimRunner writes its bones)?
-- Same key rule as GhostAnimRunner: Pop's clips are stored as "Pop_<clip>", every other clip by its own name.
-- Callers skip the old Animator track for these clips so the bones are not animated twice (Performance 2026-11-12).
local Data = require(script.Parent:WaitForChild("GhostClipData")) :: any

local GhostMocap = {}

function GhostMocap.Has(ghostName: string?, clip: string): boolean
	if ghostName == "Pop" and Data["Pop_" .. clip] ~= nil then
		return true
	end
	return Data[clip] ~= nil
end

return GhostMocap
