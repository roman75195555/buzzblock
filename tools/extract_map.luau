local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local place = roblox.deserializePlace(fs.readFile("reference_map.rbxl"))
local ws = place:FindFirstChildOfClass("Workspace")

-- Собираем статичную карту в одну модель
local map = roblox.Instance.new("Model")
map.Name = "Map"

local keepTop = {
	["Baseplate"] = true,
	["base"] = true,
	["ArchOfAugustus"] = true,
	["Dumbell 2 l"] = true,
	["Dumbell 3 l"] = true,
}

local moved = 0
for _, child in ws:GetChildren() do
	local keep = (keepTop[child.Name] or child:IsA("BasePart")) and child.ClassName ~= "Terrain"
	if keep and child.Name ~= "Camera" then
		child.Parent = map
		moved += 1
	end
end
print("moved to Map: " .. moved)

fs.writeFile("assets/Map.rbxm", roblox.serializeModel({ map }))

-- Гантель-инструмент из StarterPack
local sp = place:FindFirstChildOfClass("StarterPack")
local tool = sp and sp:FindFirstChildOfClass("Tool")
if tool then
	tool.Name = "Dumbbell"
	fs.writeFile("assets/DumbbellTool.rbxm", roblox.serializeModel({ tool }))
	print("tool saved")
else
	print("TOOL NOT FOUND")
end

print("done")
