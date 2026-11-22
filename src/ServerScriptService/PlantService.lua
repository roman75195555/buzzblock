--!strict
--==============================================================================
-- BuzzBlocks :: PlantService
-- Грядки: посадка семян (серверная валидация), 4 стадии роста,
-- цветение, сбор пчелы с цветка.
--==============================================================================

local Players = game:GetService("Players")

local PlantService = {}
local ctx

-- player -> { [slotIndex] = { Model, Stage, Prompt } }
local planted: { [Player]: any } = {}

-- Модель растения по стадии --------------------------------------------------------
local function clearPlantModel(slotPart: BasePart)
	local old = slotPart:FindFirstChild("Plant")
	if old then old:Destroy() end
end

local function buildPlantModel(slotPart: BasePart, animal, stage: number)
	clearPlantModel(slotPart)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	local flowerColor = pal[animal.SeedColor] or pal.Pink

	local m = Instance.new("Model")
	m.Name = "Plant"
	local base = slotPart.CFrame * CFrame.new(0, slotPart.Size.Y / 2, 0)

	-- стебель
	local stemH = ({ 1.2, 2.6, 4, 5 })[stage]
	Build.Part(m, { Size = Vector3.new(0.5, stemH, 0.5), CFrame = base * CFrame.new(0, stemH / 2, 0), Color = pal.Seaweed })
	-- листья
	if stage >= 2 then
		for sgn = -1, 1, 2 do
			Build.Wedge(m, { Size = Vector3.new(1.4, 0.5, 0.7), CFrame = base * CFrame.new(sgn * 0.8, stemH * 0.45, 0) * CFrame.Angles(0, sgn > 0 and math.rad(180) or 0, math.rad(-20)), Color = pal.Grass })
		end
	end

	if stage == 3 then
		-- бутон
		Build.Part(m, { Size = Vector3.new(1.6, 1.8, 1.6), CFrame = base * CFrame.new(0, stemH + 0.9, 0), Color = flowerColor, Shape = Enum.PartType.Ball })
	elseif stage >= 4 then
		-- раскрывшийся цветок
		local centerCF = base * CFrame.new(0, stemH + 1, 0)
		Build.Neon(m, { Size = Vector3.new(1.5, 1.5, 1.5), CFrame = centerCF, Color = pal.Yellow, Shape = Enum.PartType.Ball })
		for i = 0, 5 do
			local a = math.rad(i * 60)
			Build.Part(m, {
				Size = Vector3.new(1.2, 0.5, 2.2),
				CFrame = centerCF * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.7) * CFrame.Angles(math.rad(-15), 0, 0),
				Color = flowerColor,
			})
		end
		local glow = Build.Neon(m, { Size = Vector3.new(0.7, 0.7, 0.7), CFrame = centerCF * CFrame.new(0, 1.2, 0), Color = flowerColor, Shape = Enum.PartType.Ball })
		Build.Light(glow, flowerColor, 12, 0.9)
		Build.Sparkles(glow, flowerColor)
	end

	m.Parent = slotPart
	return m
end

-- Промпт сбора пчелы ---------------------------------------------------------------
local function ensureCollectPrompt(player: Player, slotPart: BasePart, slotIndex: number)
	local old = slotPart:FindFirstChildWhichIsA("ProximityPrompt")
	if old then old:Destroy() end
	local pp = ctx.Build.Prompt(slotPart, "Собрать пчелу 🐝", "Цветок")
	pp.Triggered:Connect(function(plr)
		if plr ~= player then return end
		onCollectBee(player, slotIndex)
	end)
end

-- Восстановление после загрузки ------------------------------------------------------
function PlantService.OnBaseReady(player: Player, base)
	planted[player] = {}
	local d = ctx.Services.DataService.Get(player)
	if not d then return end

	for idx, slotPart in pairs(base.FieldSlots) do
		local plant = d.Plants[tostring(idx)] or d.Plants[idx]
		if plant then
			local animal = ctx.Config.GetAnimal(plant.Seed)
			if animal then
				local stage = PlantService.StageOf(plant, animal)
				local model = buildPlantModel(slotPart, animal, stage)
				planted[player][idx] = { Model = model, Stage = stage }
				if stage >= 4 and not plant.BeeCollected then
					ensureCollectPrompt(player, slotPart, idx)
				end
			end
		else
			-- промпт посадки на пустую грядку
			local pp = ctx.Build.Prompt(slotPart, "Посадить", "Грядка " .. idx)
			pp:SetAttribute("SlotPrompt", idx)
			pp.Triggered:Connect(function(plr)
				if plr ~= player then return end
				local dd = ctx.Services.DataService.Get(player)
				if not dd then return end
				if (dd.Plants[tostring(idx)] or dd.Plants[idx]) then return end
				-- просим клиента показать выбор семени
				ctx.Remotes.Folder.OpenSeeds:FireClient(player, idx)
			end)
		end
	end
end

function PlantService.StageOf(plant, animal): number
	local progress = (os.time() - plant.PlantedAt) / animal.GrowTime
	if progress >= 1 then return 4 end
	if progress >= 0.6 then return 3 end
	if progress >= 0.3 then return 2 end
	return 1
end

-- Посадка ----------------------------------------------------------------------------
local function onPlantSeed(player: Player, slotIndex: any, animalId: any)
	if type(slotIndex) ~= "number" or type(animalId) ~= "string" then return end
	slotIndex = math.floor(slotIndex)
	if slotIndex < 1 or slotIndex > ctx.Config.SlotCount then return end

	local d = ctx.Services.DataService.Get(player)
	local base = ctx.Services.BaseService.GetBase(player)
	if not d or not base then return end

	local animal = ctx.Config.GetAnimal(animalId)
	if not animal then return end
	if (d.Seeds[animalId] or 0) <= 0 then
		ctx.Remotes.Notify:FireClient(player, "Нет такого семени!", "Red")
		return
	end
	if d.Plants[tostring(slotIndex)] or d.Plants[slotIndex] then
		ctx.Remotes.Notify:FireClient(player, "Грядка занята!", "Red")
		return
	end

	-- проверка расстояния
	local slotPart = base.FieldSlots[slotIndex]
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not slotPart or not hrp or (hrp.Position - slotPart.Position).Magnitude > 25 then
		ctx.Remotes.Notify:FireClient(player, "Подойди к грядке!", "Red")
		return
	end

	d.Seeds[animalId] -= 1
	d.Plants[tostring(slotIndex)] = {
		Seed = animalId,
		PlantedAt = os.time(),
		BeeCollected = false,
	}

	-- убрать промпт посадки, построить росток
	local pp = slotPart:FindFirstChildWhichIsA("ProximityPrompt")
	if pp then pp:Destroy() end
	local model = buildPlantModel(slotPart, animal, 1)
	planted[player] = planted[player] or {}
	planted[player][slotIndex] = { Model = model, Stage = 1 }

	ctx.Remotes.Notify:FireClient(player, "🌱 Посажено: " .. animal.Name .. "!", "Green")
	ctx.Services.DataService.PushState(player)
end

-- Сбор пчелы ---------------------------------------------------------------------------
function onCollectBee(player: Player, slotIndex: number)
	local d = ctx.Services.DataService.Get(player)
	local base = ctx.Services.BaseService.GetBase(player)
	if not d or not base then return end
	local plant = d.Plants[tostring(slotIndex)] or d.Plants[slotIndex]
	if not plant then return end

	local animal = ctx.Config.GetAnimal(plant.Seed)
	if not animal then return end

	if os.time() - plant.PlantedAt < animal.GrowTime then
		ctx.Remotes.Notify:FireClient(player, "Цветок ещё растёт!", "Red")
		return
	end
	if plant.BeeCollected then return end
	if #d.Bees >= ctx.Config.MaxBees then
		ctx.Remotes.Notify:FireClient(player, "Улей полон (" .. ctx.Config.MaxBees .. " пчёл)!", "Red")
		return
	end

	-- рождаем пчелу
	local Config = ctx.Config
	local mutation = Config.RollMutation()
	local scale = Config.BeeScaleMin + math.random() * (Config.BeeScaleMax - Config.BeeScaleMin)
	local income = Config.BeeIncome(animal, mutation.Id, scale)
	local bee = {
		Animal = animal.Id,
		Mutation = mutation.Id,
		Scale = math.round(scale * 100) / 100,
		Income = income,
		Name = (mutation.Name ~= "" and (mutation.Name .. " ") or "") .. Config.RarityNames[animal.Rarity] .. " пчела",
	}
	table.insert(d.Bees, bee)
	plant.BeeCollected = true

	-- убрать промпт с цветка
	local slotPart = base.FieldSlots[slotIndex]
	if slotPart then
		local pp = slotPart:FindFirstChildWhichIsA("ProximityPrompt")
		if pp then pp:Destroy() end
	end

	ctx.Services.BeeService.SpawnBee(player, bee)
	ctx.Remotes.Notify:FireClient(player, "🐝 " .. bee.Name .. " (+" .. income .. "/с)!", "Yellow")
	ctx.Services.DataService.PushState(player)
end

-- Цикл роста ------------------------------------------------------------------------------
local function growthTick()
	for player, slots in pairs(planted) do
		local d = ctx.Services.DataService.Get(player)
		local base = ctx.Services.BaseService.GetBase(player)
		if not d or not base then continue end
		for idx, rec in pairs(slots) do
			local plant = d.Plants[tostring(idx)] or d.Plants[idx]
			if not plant then
				slots[idx] = nil
				continue
			end
			local animal = ctx.Config.GetAnimal(plant.Seed)
			if not animal then continue end
			local stage = PlantService.StageOf(plant, animal)
			if stage ~= rec.Stage then
				local slotPart = base.FieldSlots[idx]
				if slotPart then
					rec.Model = buildPlantModel(slotPart, animal, stage)
					rec.Stage = stage
					if stage >= 4 and not plant.BeeCollected then
						ensureCollectPrompt(player, slotPart, idx)
					end
				end
			end
		end
	end
end

function PlantService.Init(c)
	ctx = c
	-- remote выбора семени (сервер просит клиента показать список)
	local openSeeds = Instance.new("RemoteEvent")
	openSeeds.Name = "OpenSeeds"
	openSeeds.Parent = ctx.Remotes.Folder

	ctx.Remotes.PlantSeed.OnServerEvent:Connect(onPlantSeed)
	ctx.Remotes.CollectBee.OnServerEvent:Connect(function(player, slotIndex)
		if type(slotIndex) == "number" then
			onCollectBee(player, math.floor(slotIndex))
		end
	end)
end

function PlantService.Start()
	-- если база появилась до старта сервиса (редкий случай) — подхватить
	for _, player in ipairs(Players:GetPlayers()) do
		local base = ctx.Services.BaseService.GetBase(player)
		if base and not planted[player] then
			PlantService.OnBaseReady(player, base)
		end
	end
	while true do
		task.wait(2)
		growthTick()
	end
end

return PlantService
