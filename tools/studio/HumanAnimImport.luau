--!strict
-- Builds Roblox KeyframeSequences for the low-poly humans from the clip data that
-- assets/models/human_base/build_anims.py writes (export_clip_data -> roblox/<name>/<name>_anims.json).
--
-- Why not just copy the Blender numbers into Bone.Transform: Roblox's 3D Importer can give a bone different
-- local axes than Blender had (it did for the arms; the legs happened to match). So every rotation goes
-- Blender bone axes -> Blender armature space -> Roblox rig space -> the Roblox bone's own axes:
--   T = Rrbx^-1 * C * (B * q * B^-1) * C^-1 * Rrbx
-- B = bone rest orientation in Blender armature space, Rrbx = the Roblox bone's rest orientation relative to the
-- RootPart, C = the rotation from Blender armature space to the RootPart, found from the hips/head/thigh
-- positions in both rigs.
--
-- Use (Studio edit mode, e.g. through the MCP or the command bar), put this in ServerStorage as a ModuleScript:
--   local H = require(game.ServerStorage.HumanAnimImport:Clone())
--   local kfs = H.build(workspace.human_base, data.rest, data.clips.walk, "walk")   -- data = the json as a table
--   kfs.Parent = game.ServerStorage.HumanAnims.human_base
local H = {}

local function bonesOf(model: Model): { [string]: Bone }
	local t = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Bone") then t[d.Name] = d end
	end
	return t
end

-- rest frames of every bone relative to the RootPart (all Transforms cleared while measuring)
function H.restFrames(model: Model): { [string]: CFrame }
	local root = model:FindFirstChild("RootPart") :: BasePart
	local bones = bonesOf(model)
	local saved = {}
	for n, b in pairs(bones) do saved[n] = b.Transform; b.Transform = CFrame.new() end
	local out = {}
	for n, b in pairs(bones) do out[n] = root.CFrame:ToObjectSpace(b.WorldCFrame) end
	for n, b in pairs(bones) do b.Transform = saved[n] end
	return out
end

local function frameFrom(origin: Vector3, up: Vector3, side: Vector3): CFrame
	local y = up.Unit
	local x = (side - y * side:Dot(y)).Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(Vector3.zero, x, y, z)
end

-- rotation taking Blender armature directions to RootPart directions
function H.armatureToRig(rest: { [string]: { number } }, rbx: { [string]: CFrame }): CFrame
	local function bp(n: string) local r = rest[n]; return Vector3.new(r[5], r[6], r[7]) end
	local fb = frameFrom(Vector3.zero, bp("head") - bp("hips"), bp("thigh.L") - bp("thigh.R"))
	local fr = frameFrom(Vector3.zero, rbx["head"].Position - rbx["hips"].Position, rbx["thigh.L"].Position - rbx["thigh.R"].Position)
	return fr * fb:Inverse()
end

local function quat(q: { number }): CFrame
	return CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
end

-- Blender key (qx, qy, qz, qw, tx, ty, tz in the Blender bone's axes) -> Roblox Bone.Transform
function H.convert(key: { number }, restQ: { number }, C: CFrame, R: CFrame): CFrame
	local B = quat(restQ)
	local q = quat(key)
	local rotArm = B * q * B:Inverse()
	local Rr = R.Rotation
	local rot = Rr:Inverse() * C * rotArm * C:Inverse() * Rr
	local t = (C * B):VectorToWorldSpace(Vector3.new(key[5], key[6], key[7]))
	local tl = Rr:VectorToObjectSpace(t)
	return CFrame.new(tl) * rot
end

-- one clip -> KeyframeSequence (Pose tree follows the bone tree under the RootPart)
function H.build(model: Model, rest: { [string]: { number } }, clip: any, name: string): KeyframeSequence
	local rbx = H.restFrames(model)
	local C = H.armatureToRig(rest, rbx)
	local bones = bonesOf(model)
	local root = model:FindFirstChild("RootPart") :: BasePart
	-- bones that need a Pose: the moving ones and every ancestor up to the RootPart
	local need: { [string]: boolean } = {}
	for n in pairs(clip.tracks) do
		local b: Instance? = bones[n]
		while b and b:IsA("Bone") do need[b.Name] = true; b = b.Parent end
	end
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = name
	kfs.Loop = true
	kfs.Priority = Enum.AnimationPriority.Core
	for i, time in ipairs(clip.times) do
		local kf = Instance.new("Keyframe")
		kf.Time = time
		local rootPose = Instance.new("Pose")
		rootPose.Name = root.Name
		rootPose.Weight = 0
		rootPose.Parent = kf
		local function add(parentPose: Pose, inst: Instance)
			for _, c in ipairs(inst:GetChildren()) do
				if c:IsA("Bone") and need[c.Name] then
					local p = Instance.new("Pose")
					p.Name = c.Name
					p.EasingStyle = Enum.PoseEasingStyle.Linear
					local tr = clip.tracks[c.Name]
					if tr then
						p.CFrame = H.convert(tr[i], rest[c.Name], C, rbx[c.Name])
					else
						p.Weight = 0
					end
					p.Parent = parentPose
					add(p, c)
				end
			end
		end
		add(rootPose, root)
		kf.Parent = kfs
	end
	return kfs
end

-- set the bones straight to one key of a clip (to check a pose without playing)
function H.pose(model: Model, rest: { [string]: { number } }, clip: any, i: number)
	local rbx = H.restFrames(model)
	local C = H.armatureToRig(rest, rbx)
	for n, b in pairs(bonesOf(model)) do
		local tr = clip.tracks[n]
		b.Transform = if tr then H.convert(tr[i], rest[n], C, rbx[n]) else CFrame.new()
	end
end

return H
