local luau = require("@lune/luau")
local fs = require("@lune/fs")
local process = require("@lune/process")

local files = {
	"src/ReplicatedStorage/Modules/BuildUtil.lua",
	"src/ReplicatedStorage/Modules/Config.lua",
	"src/ServerScriptService/Main.server.lua",
	"src/ServerScriptService/DataService.lua",
	"src/ServerScriptService/EconomyService.lua",
	"src/ServerScriptService/BaseService.lua",
	"src/ServerScriptService/BossService.lua",
	"src/ServerScriptService/ShopService.lua",
	"src/StarterPlayerScripts/ClientMain.client.lua",
	"src/StarterPlayerScripts/UI/HUD.lua",
	"src/StarterPlayerScripts/UI/ShopUI.lua",
}

local failed = 0
for _, f in ipairs(files) do
	local src = fs.readFile(f)
	local ok, err = pcall(function()
		return luau.load(src, { debugName = f })
	end)
	if ok then
		print("OK   " .. f)
	else
		failed += 1
		print("FAIL " .. f .. ": " .. tostring(err))
	end
end

if failed > 0 then
	process.exit(1)
end
print("ALL OK")
