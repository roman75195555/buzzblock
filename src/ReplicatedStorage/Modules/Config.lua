--!strict
--==============================================================================
-- LunarBase :: Config
-- Все игровые числа: участки, экономика, улучшения.
--==============================================================================

local Config = {}

Config.StoreName = "LunarBase_v1"
Config.StartMoney = 0
Config.AutosaveInterval = 120

-- Экономика --------------------------------------------------------------------
Config.StoneValue = 5          -- базовая цена камня
Config.SpawnInterval = 2.5     -- сек. между камнями на одной линии
Config.BeltSpeed = 8           -- studs/sec движение камня
Config.ConveyorLength = 50     -- длина ленты

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

-- Улучшения (покупаются последовательно кнопками на полу) ------------------------
-- kind: conveyor / laser / speed / building
Config.Upgrades = {
	[1] = { Id = "conv2", Name = "Конвейер №2", Cost = 150, Kind = "conveyor", Desc = "Вторая линия добычи" },
	[2] = { Id = "laser2", Name = "Лазер Mk.II", Cost = 400, Kind = "laser", Mult = 2, Desc = "Цена камня x2" },
	[3] = { Id = "speed1", Name = "Ускоритель лент", Cost = 800, Kind = "speed", Mult = 1.5, Desc = "Скорость производства x1.5" },
	[4] = { Id = "conv3", Name = "Конвейер №3", Cost = 1500, Kind = "conveyor", Desc = "Третья линия добычи" },
	[5] = { Id = "laser3", Name = "Лазер Mk.III", Cost = 3000, Kind = "laser", Mult = 3, Desc = "Цена камня x3" },
	[6] = { Id = "habitat", Name = "Жилой модуль", Cost = 5000, Kind = "building", Desc = "Купол для экипажа" },
	[7] = { Id = "speed2", Name = "Турбо-ленты", Cost = 8000, Kind = "speed", Mult = 2, Desc = "Скорость производства x2" },
	[8] = { Id = "conv4", Name = "Конвейер №4", Cost = 15000, Kind = "conveyor", Desc = "Четвёртая линия добычи" },
	[9] = { Id = "laser4", Name = "Солнечный лазер", Cost = 30000, Kind = "laser", Mult = 5, Desc = "Цена камня x5" },
	[10] = { Id = "lab", Name = "Лаборатория", Cost = 50000, Kind = "building", Desc = "Научный комплекс" },
}

-- Позиции конвейерных линий (смещение по X от центра участка) --------------------
Config.ConveyorX = { -18, -6, 6, 18 }

return Config
