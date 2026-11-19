-- DevCommand.luau — Swap ScarecrowV2 into AnomalyProps.Scarecrow (2026-11-20)
return {
	id = "swap_scarecrow_v2_20261120_5",
	placeId = 114125276809667,
	run = function()
		local RS = game:GetService("ReplicatedStorage")
		local ws = game:GetService("Workspace")
		local okM, MapBuilder = pcall(function()
			return require(RS.Shared.MapBuilder:Clone())
		end)
		print("DEVCMD|REQUIRE_MAPBUILDER", okM, if okM then "OK" else tostring(MapBuilder))
		if not okM then
			return
		end
		local res = MapBuilder.SwapScarecrowV2(nil, Vector3.new(12.16, 0, -45.64))
		print("DEVCMD|SWAP_SCARECROW_V2", res)

		local ap = ws:FindFirstChild("AnomalyProps")
		local sc = ap and ap:FindFirstChild("Scarecrow")
		if sc and sc:IsA("Model") then
			local cf, sz = sc:GetBoundingBox()
			local piv = sc:GetPivot()
			print(("DEVCMD|SCARECROW_NOW bbox=(%.2f,%.2f,%.2f) sz=(%.2f,%.2f,%.2f) piv=(%.2f,%.2f,%.2f) look=(%.2f,%.2f,%.2f) ver=%s"):format(
				cf.Position.X, cf.Position.Y, cf.Position.Z,
				sz.X, sz.Y, sz.Z,
				piv.Position.X, piv.Position.Y, piv.Position.Z,
				piv.LookVector.X, piv.LookVector.Y, piv.LookVector.Z,
				tostring(sc:GetAttribute("ScarecrowVersion"))
			))
			for _, d in ipairs(sc:GetDescendants()) do
				if d:IsA("MeshPart") then
					local sa = d:FindFirstChildOfClass("SurfaceAppearance")
					print(("DEVCMD|   MESH %s meshId=%s texId=%s sz=(%.2f,%.2f,%.2f) meshSz=(%.2f,%.2f,%.2f) sa=%s"):format(
						d.Name, tostring(d.MeshId), tostring(d.TextureID),
						d.Size.X, d.Size.Y, d.Size.Z,
						d.MeshSize.X, d.MeshSize.Y, d.MeshSize.Z,
						if sa then sa.ColorMap else "none"
					))
				end
			end
		end
		pcall(function()
			game:GetService("ChangeHistoryService"):SetWaypoint("SwapScarecrowV2")
		end)
	end,
}
