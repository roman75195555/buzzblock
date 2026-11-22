local roblox = require("@lune/roblox")
local fs = require("@lune/fs")

local place = roblox.deserializePlace(fs.readFile("reference_map.rbxl"))

local out = {}
local function walk(inst, path)
	local p = path .. "/" .. inst.Name
	local ok, src = pcall(function()
		return inst.Source
	end)
	if ok and src and #src > 0 then
		table.insert(out, "===== " .. p .. " (" .. inst.ClassName .. ") =====")
		table.insert(out, src)
		table.insert(out, "")
	end
	for _, child in inst:GetChildren() do
		walk(child, p)
	end
end

for _, child in place:GetChildren() do
	walk(child, "")
end

fs.writeFile("reference_scripts.txt", table.concat(out, "\n"))
print("done, blocks: " .. #out)
