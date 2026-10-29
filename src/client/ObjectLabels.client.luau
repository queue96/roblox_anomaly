-- ObjectLabels.client.luau
-- ตัดป้ายชื่อลอยเหนืออุปกรณ์ (BillboardGui "ZoneLabel") ออกทั้งหมดตามดีไซน์เกม

local Workspace = game:GetService("Workspace")

for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("BillboardGui") and d.Name == "ZoneLabel" then
		d:Destroy()
	end
end

Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("BillboardGui") and d.Name == "ZoneLabel" then
		d:Destroy()
	end
end)
