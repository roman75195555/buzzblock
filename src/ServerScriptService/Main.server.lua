--!strict
--==============================================================================
-- SeedRush :: Main
-- Точка входа сервера: создаёт remotes, загружает и запускает сервисы.
--==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

-- Remotes -------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "RushRemotes"

local function remoteEvent(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local function remoteFunction(name: string): RemoteFunction
	local r = Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = remotes
	return r
end

local Remotes = {
	GetState     = remoteFunction("GetState"),   -- клиент запрашивает полный профиль
	BuyUpgrade   = remoteEvent("BuyUpgrade"),    -- (kind: "treadmill" | "trainer" | "trail:N")
	Notify       = remoteEvent("Notify"),        -- сервер -> клиент: тост (text, colorName)
	StateChanged = remoteEvent("StateChanged"),  -- сервер -> клиент: обновление профиля
	Folder       = remotes,
}
remotes.Parent = ReplicatedStorage

-- Контекст, общий для всех сервисов ------------------------------------------
local ctx = {
	Config = require(Modules.Config),
	Build = require(Modules.BuildUtil),
	Remotes = Remotes,
	Services = {},
}

local serviceOrder = {
	"DataService",
	"EconomyService",
	"BaseService",
	"BossService",
	"ShopService",
}

for _, name in ipairs(serviceOrder) do
	local mod = ServerScriptService:WaitForChild(name)
	local svc = require(mod)
	ctx.Services[name] = svc
	if svc.Init then
		svc.Init(ctx)
	end
end

for _, name in ipairs(serviceOrder) do
	local svc = ctx.Services[name]
	if svc.Start then
		task.spawn(function()
			svc.Start(ctx)
		end)
	end
end

print("[SeedRush] Сервер запущен. Сервисов: " .. #serviceOrder)
