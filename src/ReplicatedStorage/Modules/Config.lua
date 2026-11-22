--!strict
--==============================================================================
-- BuzzBlocks :: Config
-- Вся балансная конфигурация игры: детали подлодки, животные, пчёлы, цены.
--==============================================================================

local Config = {}

-- Общие параметры -----------------------------------------------------------
Config.PlotCount = 8               -- количество баз-островов
Config.StartMoney = 150
Config.AutosaveInterval = 120      -- сек
Config.MaxBees = 12                -- максимум пчёл на игрока
Config.StealCooldown = 18          -- сек до повторной кражи у того же животного
Config.AnimalRespawnSeed = 30      -- сек до восстановления семени у животного
Config.SlotCount = 6               -- грядок на базе
Config.FuelBurnPerSec = 1          -- ед. топлива в секунду при работе мотора
Config.SeaLevel = 0                -- уровень воды
Config.OceanFloor = -110           -- глубина дна
Config.BaseRadius = 170            -- радиус кольца баз от центра

-- Цветовая палитра (LEGO-стиль) --------------------------------------------
Config.Palette = {
	Grass     = Color3.fromRGB(96, 190, 84),
	GrassDark = Color3.fromRGB(72, 158, 66),
	Earth     = Color3.fromRGB(146, 104, 66),
	Soil      = Color3.fromRGB(96, 62, 38),
	Sand      = Color3.fromRGB(235, 214, 158),
	SandDeep  = Color3.fromRGB(204, 178, 116),
	Wood      = Color3.fromRGB(178, 132, 84),
	WoodDark  = Color3.fromRGB(128, 90, 52),
	Stone     = Color3.fromRGB(150, 152, 158),
	StoneDark = Color3.fromRGB(108, 110, 118),
	White     = Color3.fromRGB(245, 245, 245),
	Black     = Color3.fromRGB(35, 35, 40),
	Red       = Color3.fromRGB(226, 66, 64),
	Orange    = Color3.fromRGB(245, 150, 50),
	Yellow    = Color3.fromRGB(250, 210, 60),
	BeeYellow = Color3.fromRGB(255, 200, 40),
	Blue      = Color3.fromRGB(66, 140, 235),
	DeepBlue  = Color3.fromRGB(24, 70, 140),
	Cyan      = Color3.fromRGB(90, 210, 230),
	Pink      = Color3.fromRGB(245, 130, 170),
	Purple    = Color3.fromRGB(150, 90, 200),
	Coral1    = Color3.fromRGB(255, 110, 110),
	Coral2    = Color3.fromRGB(255, 160, 80),
	Coral3    = Color3.fromRGB(200, 110, 230),
	Coral4    = Color3.fromRGB(90, 220, 180),
	Seaweed   = Color3.fromRGB(50, 150, 90),
}

-- Категории деталей подлодки -------------------------------------------------
Config.PartCategories = { "Hull", "Engine", "Propeller", "Tank", "Wheel" }
Config.CategoryNames = {
	Hull      = "Корпус",
	Engine    = "Двигатель",
	Propeller = "Винт",
	Tank      = "Топливный бак",
	Wheel     = "Руль",
}

-- Детали: 4 уровня качества в каждой категории.
Config.Parts = {
	Hull = {
		{ Tier = 1, Name = "Дубовый корпус",      Cost = 0,     HP = 100,  Size = 1.00, Color = "Wood"   },
		{ Tier = 2, Name = "Железный корпус",     Cost = 400,   HP = 220,  Size = 1.05, Color = "Stone"  },
		{ Tier = 3, Name = "Титановый корпус",    Cost = 2500,  HP = 450,  Size = 1.10, Color = "Blue"   },
		{ Tier = 4, Name = "Золотой корпус",      Cost = 12000, HP = 900,  Size = 1.15, Color = "Yellow" },
	},
	Engine = {
		{ Tier = 1, Name = "Паровой мотор",       Cost = 0,     Speed = 26 },
		{ Tier = 2, Name = "Дизельный мотор",     Cost = 600,   Speed = 38 },
		{ Tier = 3, Name = "Турбина",             Cost = 3500,  Speed = 55 },
		{ Tier = 4, Name = "Реактивный реактор",  Cost = 15000, Speed = 80 },
	},
	Propeller = {
		{ Tier = 1, Name = "Деревянный винт",     Cost = 0,     Boost = 1.00 },
		{ Tier = 2, Name = "Стальной винт",       Cost = 350,   Boost = 1.15 },
		{ Tier = 3, Name = "Бронзовый винт",      Cost = 2000,  Boost = 1.35 },
		{ Tier = 4, Name = "Алмазный винт",       Cost = 9000,  Boost = 1.60 },
	},
	Tank = {
		{ Tier = 1, Name = "Канистра",            Cost = 0,     Fuel = 90  },
		{ Tier = 2, Name = "Стальной бак",        Cost = 500,   Fuel = 180 },
		{ Tier = 3, Name = "Двойной бак",         Cost = 3000,  Fuel = 360 },
		{ Tier = 4, Name = "Топливный отсек XL",  Cost = 14000, Fuel = 720 },
	},
	Wheel = {
		{ Tier = 1, Name = "Верёвочный румпель",  Cost = 0,     Turn = 1.00 },
		{ Tier = 2, Name = "Штурвал",             Cost = 300,   Turn = 1.30 },
		{ Tier = 3, Name = "Гидроусилитель",      Cost = 1800,  Turn = 1.65 },
		{ Tier = 4, Name = "Капитанский штурвал", Cost = 8000,  Turn = 2.10 },
	},
}

-- Редкости ------------------------------------------------------------------
Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
Config.RarityNames = {
	Common = "Обычный", Uncommon = "Необычный", Rare = "Редкий",
	Epic = "Эпический", Legendary = "Легендарный", Mythic = "Мифический",
}
Config.RarityMultiplier = { Common = 1, Uncommon = 2, Rare = 4, Epic = 8, Legendary = 20, Mythic = 50 }
Config.RarityColors = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(90, 220, 100),
	Rare      = Color3.fromRGB(80, 150, 255),
	Epic      = Color3.fromRGB(190, 100, 255),
	Legendary = Color3.fromRGB(255, 180, 50),
	Mythic    = Color3.fromRGB(255, 80, 120),
}

-- Морские животные. Income — базовый доход пчелы из его семени.
-- Weight — шанс спавна; GrowTime — время роста растения (сек).
Config.Animals = {
	{ Id = "Clownfish", Name = "Рыба-клоун",  Rarity = "Common",    Weight = 34, Speed = 9,  Scale = 0.9, Income = 1,   GrowTime = 45,  SeedColor = "Orange",  Depth = -35 },
	{ Id = "Turtle",    Name = "Черепаха",    Rarity = "Uncommon",  Weight = 24, Speed = 5,  Scale = 1.2, Income = 3,   GrowTime = 90,  SeedColor = "Seaweed", Depth = -45 },
	{ Id = "Stingray",  Name = "Скат",        Rarity = "Rare",      Weight = 16, Speed = 11, Scale = 1.4, Income = 7,   GrowTime = 150, SeedColor = "Purple",  Depth = -60 },
	{ Id = "Octopus",   Name = "Осьминог",    Rarity = "Rare",      Weight = 11, Speed = 6,  Scale = 1.3, Income = 14,  GrowTime = 240, SeedColor = "Pink",    Depth = -70 },
	{ Id = "Shark",     Name = "Акула",       Rarity = "Epic",      Weight = 8,  Speed = 15, Scale = 2.2, Income = 30,  GrowTime = 360, SeedColor = "Blue",    Depth = -55 },
	{ Id = "Whale",     Name = "Кит",         Rarity = "Legendary", Weight = 5,  Speed = 7,  Scale = 3.6, Income = 70,  GrowTime = 540, SeedColor = "Cyan",    Depth = -40 },
	{ Id = "Kraken",    Name = "Кракен",      Rarity = "Mythic",    Weight = 2,  Speed = 8,  Scale = 4.5, Income = 180, GrowTime = 900, SeedColor = "Red",     Depth = -85 },
}
Config.AnimalCount = 26            -- сколько животных одновременно в океане

-- Мутации пчёл (шанс при рождении) -------------------------------------------
Config.Mutations = {
	{ Id = "None",    Name = "",            Mult = 1,  Chance = 0.84 },
	{ Id = "Gold",    Name = "Золотая",     Mult = 2,  Chance = 0.10 },
	{ Id = "Crystal", Name = "Кристальная", Mult = 4,  Chance = 0.05 },
	{ Id = "Rainbow", Name = "Радужная",    Mult = 10, Chance = 0.01 },
}
Config.MutationColors = {
	None    = Color3.fromRGB(255, 200, 40),
	Gold    = Color3.fromRGB(255, 220, 90),
	Crystal = Color3.fromRGB(170, 235, 255),
	Rainbow = Color3.fromRGB(255, 120, 200),
}

-- Размер пчелы: 0.8–1.5, доход умножается на Scale^2
Config.BeeScaleMin = 0.8
Config.BeeScaleMax = 1.5

-- Вспомогательные функции -----------------------------------------------------
function Config.GetPart(category: string, tier: number)
	local list = Config.Parts[category]
	return list and list[math.clamp(tier, 1, #list)] or nil
end

function Config.GetAnimal(id: string)
	for _, a in ipairs(Config.Animals) do
		if a.Id == id then return a end
	end
	return nil
end

function Config.RollMutation()
	local roll = math.random()
	local acc = 0
	for _, m in ipairs(Config.Mutations) do
		acc += m.Chance
		if roll <= acc then return m end
	end
	return Config.Mutations[1]
end

function Config.BeeIncome(animal, mutationId: string, scale: number): number
	local mult = Config.RarityMultiplier[animal.Rarity] or 1
	local mutMult = 1
	for _, m in ipairs(Config.Mutations) do
		if m.Id == mutationId then mutMult = m.Mult break end
	end
	return math.max(1, math.round(animal.Income * mult * mutMult * scale * scale * 0.2))
end

return Config
