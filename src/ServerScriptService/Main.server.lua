--!strict
--==============================================================================
-- BuzzBlocks :: Main
-- Точка входа сервера: создаёт remotes, загружает и запускает сервисы.
--==============================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")

-- Remotes -------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "BuzzRemotes"

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
	GetState     = remoteFunction("GetState"),     -- клиент запрашивает полный профиль
	BuyPart      = remoteEvent("BuyPart"),         -- (category, tier)
	EquipPart    = remoteEvent("EquipPart"),       -- (category, tier)
	BuildSub     = remoteEvent("BuildSub"),        -- собрать подлодку на стапеле
	PlantSeed    = remoteEvent("PlantSeed"),       -- (slotIndex, animalId)
	CollectBee   = remoteEvent("CollectBee"),      -- (slotIndex)
	Notify       = remoteEvent("Notify"),          -- сервер -> клиент: тост (text, colorName)
	StateChanged = remoteEvent("StateChanged"),    -- сервер -> клиент: обновление профиля
	OpenShop     = remoteEvent("OpenShop"),        -- сервер -> клиент: открыть магазин
	OpenBuild    = remoteEvent("OpenBuild"),       -- сервер -> клиент: открыть верфь
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
	"WorldService",
	"BaseService",
	"PlantService",
	"BeeService",
	"SubmarineService",
	"AnimalService",
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

print("[BuzzBlocks] Сервер запущен. Сервисов: " .. #serviceOrder)
