-- DevCommand.luau — Lobby: move the Anomalies leaderboard in front of the wooden pole (pole hides behind the taller board) (2026-11-24)
return {
	id = "lobby_lb_front_of_pole_20261124_1",
	placeId = 70980777393906,
	run = function()
		local lb = workspace.TempleLobby.LeaderboardAnomalies :: Model
		local cf = lb:GetBoundingBox()
		lb:PivotTo(lb:GetPivot() + Vector3.new(55.5 - cf.X, 0, 0))
		local nc, size = lb:GetBoundingBox()
		local pole = workspace.TempleLobby.SpookyDecor:FindFirstChild("WoodenPole", true) :: BasePart
		-- ระยะจากหน้าเสา (ฝั่งลาน) ถึงหลังป้าย: เสา MeshPart วัดจากจุดยอดจริงไม่ได้ ใช้ raycast จากลานเข้าหาเสาที่ความสูงกลางเสา
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { pole }
		local hit = workspace:Raycast(Vector3.new(40, pole.Position.Y, pole.Position.Z), Vector3.new(30, 0, 0), params)
		print("DEVCMD|LB", tostring(nc.Position), "boardBackX", nc.X + 1, "poleFrontX", hit and hit.Position.X or "nohit", "boardTop", nc.Y + size.Y / 2, "poleTop", pole.Position.Y + pole.Size.Y / 2)
		local cam = workspace.CurrentCamera
		cam.CFrame = CFrame.lookAt(Vector3.new(20, 8, 32.5), nc.Position)
	end,
}
