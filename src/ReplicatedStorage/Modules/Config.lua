--!strict
--==============================================================================
-- LunarBase :: Config
-- Все игровые числа: участки, экономика, обработка камней, улучшения, магазин.
--==============================================================================

local Config = {}

Config.StoreName = "LunarBase_v2"
Config.StartMoney = 0
Config.AutosaveInterval = 120

-- Экономика --------------------------------------------------------------------
Config.StoneValue = 5          -- базовая цена сырого камня
Config.ProcessedMult = 4       -- множитель за обработанный камень
Config.SpawnInterval = 3       -- сек. между камнями на одной линии
Config.BeltSpeed = 8           -- studs/sec движение камня
Config.ConveyorLength = 50     -- длина ленты
Config.DrillIncome = 3         -- кредитов/сек за бур

-- Интерактивная обработка -------------------------------------------------------
Config.CleanTime = 1.5         -- сек. работы мышкой на этапе очистки
Config.SawTime = 2             -- сек. на этапе опиливания
Config.StoneWaitTimeout = 20   -- камень ждёт игрока, потом едет сырым
Config.WorkerTime = 4          -- сек. обработки камня работником
Config.WorkDistance = 16       -- макс. дистанция работы с камнем

-- 6 участков: сетка 3 x 2 -------------------------------------------------------
Config.Plots = {
	[1] = Vector3.new(-200, 0, -150),
	[2] = Vector3.new(0, 0, -150),
	[3] = Vector3.new(200, 0, -150),
	[4] = Vector3.new(-200, 0, 150),
	[5] = Vector3.new(0, 0, 150),
	[6] = Vector3.new(200, 0, 150),
}
Config.PlotSize = 120
Config.PlotSizeExpanded = 170

-- Улучшения (покупаются последовательно кнопками на полу) ------------------------
-- kind: conveyor / laser / speed / walls / lights / expand / drill / worker / building
Config.Upgrades = {
	[1] = { Id = "conv2", Name = "Конвейер №2", Cost = 100, Kind = "conveyor", Desc = "Вторая линия добычи" },
	[2] = { Id = "lights1", Name = "Освещение базы", Cost = 150, Kind = "lights", Desc = "Фонари по периметру" },
	[3] = { Id = "laser2", Name = "Лазер Mk.II", Cost = 250, Kind = "laser", Mult = 2, Desc = "Цена камня x2" },
	[4] = { Id = "walls1", Name = "Стены базы", Cost = 300, Kind = "walls", Desc = "Защитный периметр" },
	[5] = { Id = "speed1", Name = "Ускоритель лент", Cost = 400, Kind = "speed", Mult = 1.5, Desc = "Скорость производства x1.5" },
	[6] = { Id = "worker1", Name = "Работник-робот", Cost = 600, Kind = "worker", Desc = "Обрабатывает камни сам" },
	[7] = { Id = "conv3", Name = "Конвейер №3", Cost = 800, Kind = "conveyor", Desc = "Третья линия добычи" },
	[8] = { Id = "expand1", Name = "Расширение территории", Cost = 1000, Kind = "expand", Desc = "Больше места для базы" },
	[9] = { Id = "drill1", Name = "Лунный бур", Cost = 1500, Kind = "drill", Desc = "+3💰/сек пассивно" },
	[10] = { Id = "worker2", Name = "Работник №2", Cost = 2000, Kind = "worker", Desc = "Второй робот" },
	[11] = { Id = "laser3", Name = "Лазер Mk.III", Cost = 2500, Kind = "laser", Mult = 3, Desc = "Цена камня x3" },
	[12] = { Id = "habitat", Name = "Жилой модуль", Cost = 5000, Kind = "building", Desc = "Купол для экипажа" },
	[13] = { Id = "conv4", Name = "Конвейер №4", Cost = 6000, Kind = "conveyor", Desc = "Четвёртая линия добычи" },
	[14] = { Id = "worker3", Name = "Работник №3", Cost = 8000, Kind = "worker", Desc = "Третий робот" },
	[15] = { Id = "speed2", Name = "Турбо-ленты", Cost = 10000, Kind = "speed", Mult = 2, Desc = "Скорость производства x2" },
	[16] = { Id = "laser4", Name = "Солнечный лазер", Cost = 20000, Kind = "laser", Mult = 5, Desc = "Цена камня x5" },
	[17] = { Id = "lab", Name = "Лаборатория", Cost = 40000, Kind = "building", Desc = "Научный комплекс" },
}

-- Позиции конвейерных линий (смещение по X от центра участка) --------------------
Config.ConveyorX = { -18, -6, 6, 18 }

-- Косметика в физическом магазине -------------------------------------------------
Config.ShopItems = {
	[1] = { Id = "frame_red", Name = "Красная рамка базы", Cost = 500, Color = Color3.fromRGB(255, 80, 80) },
	[2] = { Id = "frame_gold", Name = "Золотая рамка базы", Cost = 800, Color = Color3.fromRGB(255, 200, 60) },
	[3] = { Id = "frame_purple", Name = "Фиолетовая рамка", Cost = 1200, Color = Color3.fromRGB(190, 100, 255) },
	[4] = { Id = "flag", Name = "Флаг на базу", Cost = 300, Color = Color3.fromRGB(255, 120, 40) },
}

return Config
