--!strict
--==============================================================================
-- BuzzBlocks :: EconomyService
-- Покупки деталей (серверная валидация) и пассивный доход от растений и пчёл.
--==============================================================================

local Players = game:GetService("Players")

local EconomyService = {}
local ctx

local function data(player: Player)
	return ctx.Services.DataService.Get(player)
end

-- Покупка детали ---------------------------------------------------------------
local function onBuyPart(player: Player, category: any, tier: any)
	if type(category) ~= "string" or type(tier) ~= "number" then return end
	local Config = ctx.Config
	local part = Config.GetPart(category, tier)
	local d = data(player)
	if not part or not d then return end

	local owned = d.OwnedParts[category]
	if not owned then return end
	if owned[tier] then
		ctx.Remotes.Notify:FireClient(player, "Уже куплено!", "Red")
		return
	end
	-- уровни открываются по порядку
	if tier > 1 and not owned[tier - 1] then
		ctx.Remotes.Notify:FireClient(player, "Сначала купи предыдущий уровень!", "Red")
		return
	end
	if d.Money < part.Cost then
		ctx.Remotes.Notify:FireClient(player, "Не хватает монет! Нужно " .. part.Cost, "Red")
		return
	end

	ctx.Services.DataService.AddMoney(player, -part.Cost)
	owned[tier] = true
	d.Equipped[category] = tier -- новая деталь сразу ставится
	ctx.Remotes.Notify:FireClient(player, "Куплено: " .. part.Name .. "!", "Green")
	ctx.Services.DataService.PushState(player)
end

-- Выбор детали для сборки ------------------------------------------------------
local function onEquipPart(player: Player, category: any, tier: any)
	if type(category) ~= "string" or type(tier) ~= "number" then return end
	local d = data(player)
	if not d then return end
	local owned = d.OwnedParts[category]
	if not owned or not owned[tier] then return end
	if not ctx.Config.GetPart(category, tier) then return end
	d.Equipped[category] = tier
	ctx.Services.DataService.PushState(player)
end

-- Пассивный доход ----------------------------------------------------------------
local function incomeTick()
	local Config = ctx.Config
	for _, player in ipairs(Players:GetPlayers()) do
		local d = data(player)
		if not d then continue end

		local sum = 0
		-- растения: выросшее растение даёт Income монет/сек
		for _, plant in pairs(d.Plants) do
			local animal = Config.GetAnimal(plant.Seed)
			if animal then
				local age = os.time() - plant.PlantedAt
				if age >= animal.GrowTime then
					sum += animal.Income
				end
			end
		end
		-- пчёлы
		for _, bee in ipairs(d.Bees) do
			sum += bee.Income or 1
		end

		if sum > 0 then
			ctx.Services.DataService.AddMoney(player, sum)
		end
	end
end

function EconomyService.Init(c)
	ctx = c
	ctx.Remotes.BuyPart.OnServerEvent:Connect(onBuyPart)
	ctx.Remotes.EquipPart.OnServerEvent:Connect(onEquipPart)
end

function EconomyService.Start()
	while true do
		task.wait(1)
		incomeTick()
	end
end

return EconomyService
