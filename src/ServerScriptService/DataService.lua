--!strict
--==============================================================================
-- BuzzBlocks :: DataService
-- Профили игроков: DataStore, автосохранение, сохранение при выходе.
--==============================================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataService = {}
local ctx
local store

local STORE_NAME = "BuzzBlocks_v1"
local profiles: { [Player]: any } = {}

-- Шаблон нового профиля -------------------------------------------------------
local function defaultData(Config)
	return {
		Money = Config.StartMoney,
		-- Купленные детали: category -> { tier = true }. Тир 1 выдаётся сразу.
		OwnedParts = {
			Hull = { [1] = true }, Engine = { [1] = true }, Propeller = { [1] = true },
			Tank = { [1] = true }, Wheel = { [1] = true },
		},
		-- Выбранные детали для сборки
		Equipped = { Hull = 1, Engine = 1, Propeller = 1, Tank = 1, Wheel = 1 },
		-- Семена: animalId -> количество
		Seeds = {},
		-- Грядки: slotIndex -> { Seed = animalId, PlantedAt = os.time(), BeeCollected = bool }
		Plants = {},
		-- Пчёлы: { { Animal = id, Mutation = id, Scale = n, Income = n, Name = s } }
		Bees = {},
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

-- Загрузка --------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	-- leaderstats
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
			-- мягкий мердж: новые поля из шаблона не теряются
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

	-- клиент запрашивает состояние после загрузки UI
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
	-- автосохранение
	while true do
		task.wait(ctx.Config.AutosaveInterval)
		for _, p in ipairs(Players:GetPlayers()) do
			DataService.Save(p)
		end
	end
end

return DataService
