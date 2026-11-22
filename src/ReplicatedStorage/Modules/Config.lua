--!strict
--==============================================================================
-- SeedRush :: Config
-- Все игровые числа: зоны, боссы, семена, прокачка, магазин.
-- Карта соответствует reference_map.rbxl: 3 базы на z≈-17, дорожка вдоль +Z,
-- 7 цветных секций-локаций, арка в конце.
--==============================================================================

local Config = {}

Config.StartMoney = 50
Config.AutosaveInterval = 120

Config.BaseWalkSpeed = 16
Config.SpeedPerPoint = 0.06      -- WalkSpeed = 16 + Speed * 0.06 + бонус следа
Config.MaxWalkSpeed = 60

Config.SafeZoneZ = 40            -- z < 40: базовая зелёная зона, боссы сюда не ходят
Config.TrackCenterX = -51.9      -- центр дорожки по X
Config.CatchRadius = 7           -- дистанция поимки боссом
Config.SeedRespawn = 12          -- сек. до появления нового семени
Config.BossGiveUpTime = 90       -- сек. погони, потом босс возвращается

-- Локации вдоль дорожки (по нарастанию сложности) ---------------------------
-- Z — центр секции из карты-референса.
Config.Zones = {
	[1] = {
		Name = "Лужайка", Z = 151.9,
		Color = Color3.new(0.97, 0.97, 0.97),
		ReqStrength = 0, Income = 1, GrowTime = 15,
		BossSpeed = 10, BossScale = 1.0, BossName = "Сонный Колобок",
	},
	[2] = {
		Name = "Зелёный лес", Z = 257.5,
		Color = Color3.new(0, 0.8, 0),
		ReqStrength = 30, Income = 3, GrowTime = 30,
		BossSpeed = 12, BossScale = 1.25, BossName = "Зелёный Гром",
	},
	[3] = {
		Name = "Ледяная пещера", Z = 362.5,
		Color = Color3.new(0, 0.85, 0.9),
		ReqStrength = 90, Income = 8, GrowTime = 60,
		BossSpeed = 14, BossScale = 1.5, BossName = "Ледяной Краб",
	},
	[4] = {
		Name = "Теневые руины", Z = 467.8,
		Color = Color3.new(0.55, 0, 0.6),
		ReqStrength = 220, Income = 20, GrowTime = 120,
		BossSpeed = 16, BossScale = 1.8, BossName = "Теневой Голем",
	},
	[5] = {
		Name = "Золотые пески", Z = 573.4,
		Color = Color3.new(0.95, 0.85, 0),
		ReqStrength = 500, Income = 45, GrowTime = 240,
		BossSpeed = 18, BossScale = 2.2, BossName = "Золотой Лев",
	},
	[6] = {
		Name = "Алый разлом", Z = 678.4,
		Color = Color3.new(0.85, 0, 0),
		ReqStrength = 1100, Income = 100, GrowTime = 480,
		BossSpeed = 20, BossScale = 2.6, BossName = "Алый Демон",
	},
	[7] = {
		Name = "Трон Титана", Z = 783.9,
		Color = Color3.new(0.11, 0.16, 0.21),
		ReqStrength = 2500, Income = 250, GrowTime = 900,
		BossSpeed = 22, BossScale = 3.2, BossName = "ТИТАН",
	},
}

-- Прокачка -------------------------------------------------------------------
Config.MaxTier = 10
-- Стоимость улучшения дорожки/тренажёра с tier -> tier+1
function Config.UpgradeCost(tier: number): number
	return 120 * tier * tier
end
-- Очки скорости в секунду на дорожке данного тира
function Config.SpeedRate(tier: number): number
	return 0.5 * tier
end
-- Сила за один подъём гантели данного тира
function Config.StrengthPerRep(tier: number): number
	return tier
end
Config.RepCooldown = 0.6

-- Следы (trails) ---------------------------------------------------------------
Config.Trails = {
	[1] = { Name = "Огненный след", Cost = 300, Bonus = 4, Color = Color3.fromRGB(255, 100, 20) },
	[2] = { Name = "Грозовой след", Cost = 1500, Bonus = 8, Color = Color3.fromRGB(80, 160, 255) },
	[3] = { Name = "Радужный след", Cost = 6000, Bonus = 14, Color = Color3.fromRGB(255, 80, 200) },
}

-- Базы (центры пола из карты-референса) ---------------------------------------
Config.Bases = {
	[1] = { Center = Vector3.new(-131.4, 5.5, -16.9) },
	[2] = { Center = Vector3.new(-60.8, 5.5, -16.9) },
	[3] = { Center = Vector3.new(8.1, 5.5, -16.9) },
}
Config.PlotCount = 4

return Config
