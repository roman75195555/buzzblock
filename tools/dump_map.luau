-- Lune-скрипт: выгрузка структуры .rbxl в текст
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("reference_map.rbxl"))

local out = {}
local function add(s)
	table.insert(out, s)
end

local function fmtV3(v)
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function tryProp(inst, prop)
	local ok, val = pcall(function()
		return inst[prop]
	end)
	if ok then
		return val
	end
	return nil
end

local function dump(inst, depth)
	local info = string.rep("  ", depth) .. inst.ClassName .. '  "' .. inst.Name .. '"'
	local size = tryProp(inst, "Size")
	local cf = tryProp(inst, "CFrame")
	if size and cf then
		info = info .. "  size=" .. fmtV3(size) .. "  pos=" .. fmtV3(cf.Position)
		local color = tryProp(inst, "Color")
		local mat = tryProp(inst, "Material")
		if color then
			info = info .. "  color=" .. tostring(color)
		end
		if mat then
			info = info .. "  mat=" .. tostring(mat)
		end
		local shape = tryProp(inst, "Shape")
		if shape then
			info = info .. "  shape=" .. tostring(shape)
		end
	end
	add(info)
	for _, child in ipairs(inst:GetChildren()) do
		dump(child, depth + 1)
	end
end

for _, child in ipairs(game:GetChildren()) do
	dump(child, 0)
end

fs.writeFile("map_dump.txt", table.concat(out, "\n"))
print("Instances dumped:", #out)
