--!strict
--==============================================================================
-- LunarBase :: Main
-- Точка входа сервера: remotes, загрузка и запуск сервисов.
--==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local remotes = Instance.new("Folder")
remotes.Name = "LunarRemotes"

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
	GetState     = remoteFunction("GetState"),
	Notify       = remoteEvent("Notify"),
	StateChanged = remoteEvent("StateChanged"),
	WorkBegin    = remoteEvent("WorkBegin"),    -- сервер -> клиент: начать обработку (stone)
	WorkStage    = remoteEvent("WorkStage"),    -- сервер -> клиент: (stone, stage) 0=стоп/аборт
	WorkTick     = remoteEvent("WorkTick"),     -- клиент -> сервер: (stone, dt)
	OpenShop     = remoteEvent("OpenShop"),     -- сервер -> клиент: открыть магазин
	BuyShopItem  = remoteEvent("BuyShopItem"),  -- клиент -> сервер: (itemId)
	Folder       = remotes,
}
remotes.Parent = ReplicatedStorage

local ctx = {
	Config = require(Modules.Config),
	Build = require(Modules.BuildUtil),
	Remotes = Remotes,
	Services = {},
}

local serviceOrder = {
	"DataService",
	"WorldService",
	"BaseService",
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

print("[LunarBase] Сервер запущен. Сервисов: " .. #serviceOrder)
