local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local place = roblox.deserializePlace(fs.readFile("SeedRush.rbxlx"))
local ws = place:FindFirstChildOfClass("Workspace")
local map = ws and ws:FindFirstChild("Map")
print("Map: " .. tostring(map ~= nil))
if map then
	local base = map:FindFirstChild("base")
	print("base folder: " .. tostring(base ~= nil))
	if base then
		for _, b in base:GetChildren() do
			print("  " .. b.Name)
		end
	end
	print("ArchOfAugustus: " .. tostring(map:FindFirstChild("ArchOfAugustus") ~= nil))
end
local sp = place:FindFirstChildOfClass("StarterPack")
local tool = sp and sp:FindFirstChild("Dumbbell")
print("Dumbbell tool: " .. tostring(tool ~= nil))
local sss = place:FindFirstChildOfClass("ServerScriptService")
print("ServerScriptService children:")
for _, c in sss:GetChildren() do
	print("  " .. c.ClassName .. " " .. c.Name)
end
