--!strict
--==============================================================================
-- SeedRush :: DataService
-- Профили игроков: DataStore, автосохранение, сохранение при выходе.
--==============================================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataService = {}
local ctx
local store

local STORE_NAME = "SeedRush_v1"
local profiles: { [Player]: any } = {}

-- Шаблон нового профиля -------------------------------------------------------
local function defaultData(Config)
	return {
		Money = Config.StartMoney,
		Speed = 0,          -- очки скорости (влияют на WalkSpeed)
		Strength = 0,       -- сила (гейт кражи семян)
		TreadmillTier = 1,  -- тир беговой дорожки
		TrainerTier = 1,    -- тир тренажёра силы
		Trails = {},        -- trailId -> true
		Seeds = {},         -- zoneId(string) -> количество
		Plots = {},         -- slotIndex(string) -> { Zone = n, PlantedAt = os.time() }
	}
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

-- API ------------------------------------------------------------------------
function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not data then return end
	if not store then return end -- Studio без API-доступа
	local ok, err = pcall(function()
		store:SetAsync(key(player), data)
	end)
	if not ok then
		warn("[DataService] Ошибка сохранения " .. player.Name .. ": " .. tostring(err))
	end
end

local function pushState(player: Player)
	local data = profiles[player]
	if data then
		ctx.Remotes.StateChanged:FireClient(player, data)
	end
end
DataService.PushState = pushState

function DataService.AddMoney(player: Player, amount: number)
	local data = profiles[player]
	if not data then return end
	data.Money = math.max(0, math.round(data.Money + amount))
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Монеты")
	if coins then coins.Value = data.Money end
end

function DataService.TrySpend(player: Player, amount: number): boolean
	local data = profiles[player]
	if not data then return false end
	if data.Money < amount then return false end
	DataService.AddMoney(player, -amount)
	return true
end

-- Загрузка --------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Монеты"
	coins.Value = 0
	coins.Parent = ls
	ls.Parent = player

	local data = defaultData(ctx.Config)
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(key(player))
		end)
		if ok and type(result) == "table" then
			for k, v in pairs(defaultData(ctx.Config)) do
				if result[k] == nil then result[k] = v end
			end
			data = result
		elseif not ok then
			warn("[DataService] Ошибка загрузки " .. player.Name .. ": " .. tostring(result))
		end
	end
	profiles[player] = data
	coins.Value = data.Money

	task.defer(function()
		task.wait(1)
		pushState(player)
	end)
end

local function onPlayerRemoving(player: Player)
	DataService.Save(player)
	profiles[player] = nil
end

-- Жизненный цикл ---------------------------------------------------------------
function DataService.Init(c)
	ctx = c
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = s
	else
		warn("[DataService] DataStore недоступен (Studio без API?). Прогресс не сохраняется.")
	end

	ctx.Remotes.GetState.OnServerInvoke = function(player: Player)
		local t0 = os.clock()
		while not profiles[player] and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		return profiles[player]
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(1)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			DataService.Save(p)
		end
	end)
end

function DataService.Start()
	while true do
		task.wait(ctx.Config.AutosaveInterval)
		for _, p in ipairs(Players:GetPlayers()) do
			DataService.Save(p)
		end
	end
end

return DataService
