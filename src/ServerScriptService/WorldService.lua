--!strict
--==============================================================================
-- BuzzBlocks :: WorldService
-- Строит карту: океан, остров-хаб с магазином, острова под базы, порталы,
-- подводный мир с кораллами, пещерами, водорослями, светом и пузырями.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local WorldService = {}
local ctx
local worldFolder: Folder

WorldService.PlotCF = {}          -- CFrame островов под базы (индекс 1..PlotCount)
WorldService.HubCF = CFrame.new(0, 2, 0)
WorldService.DockCF = CFrame.new(0, -44, 0) -- подводный док
WorldService.PortalSurface = nil  -- кольцо-портал на поверхности
WorldService.PortalUnder = nil    -- кольцо-портал под водой

-- Хелперы ---------------------------------------------------------------------
local function cyl(parent, cf: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material?)
	return ctx.Build.Part(parent, {
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)),
		Color = color, Material = material or Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
	})
end

local function island(parent: Instance, pos: Vector3, radius: number)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	-- слои острова
	cyl(parent, CFrame.new(pos + Vector3.new(0, -6, 0)), 12, radius * 2.15, pal.Sand)
	cyl(parent, CFrame.new(pos + Vector3.new(0, 0.5, 0)), 3, radius * 2.0, pal.Earth)
	local top = cyl(parent, CFrame.new(pos + Vector3.new(0, 1.6, 0)), 2.4, radius * 1.92, pal.Grass)
	-- песчаный пляж-кольцо
	cyl(parent, CFrame.new(pos + Vector3.new(0, 1.2, 0)), 2.6, radius * 2.1, pal.Sand)
	top.Name = "IslandTop"
	return top
end

-- Коралл ----------------------------------------------------------------------
local function coral(parent: Instance, cf: CFrame, color: Color3, scale: number)
	local P = ctx.Build
	local m = Instance.new("Model")
	m.Name = "Coral"
	local trunkH = 5 * scale
	P.Part(m, { Size = Vector3.new(1.4 * scale, trunkH, 1.4 * scale), CFrame = cf * CFrame.new(0, trunkH / 2, 0), Color = color })
	local branches = math.random(2, 4)
	for i = 1, branches do
		local ang = math.rad(math.random(0, 359))
		local tilt = math.rad(30 + math.random(0, 25))
		local bh = trunkH * (0.5 + math.random() * 0.4)
		local b = P.Part(m, {
			Size = Vector3.new(1 * scale, bh, 1 * scale),
			CFrame = cf * CFrame.new(0, trunkH * 0.7, 0)
				* CFrame.Angles(0, ang, 0) * CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, bh / 2, 0),
			Color = color,
		})
		-- светящийся кончик
		P.Neon(m, {
			Size = Vector3.new(1.3 * scale, 1.3 * scale, 1.3 * scale),
			CFrame = b.CFrame * CFrame.new(0, bh / 2, 0),
			Color = color, Shape = Enum.PartType.Ball,
		})
	end
	m.Parent = parent
	return m
end

-- Водоросль -------------------------------------------------------------------
local function seaweed(parent: Instance, cf: CFrame, height: number)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "Seaweed"
	local segs = math.clamp(math.floor(height / 4), 2, 6)
	local offset = Vector3.zero
	for i = 1, segs do
		offset += Vector3.new(math.random(-10, 10) / 25, 0, math.random(-10, 10) / 25)
		P.Part(m, {
			Size = Vector3.new(1.1, 4.4, 1.1),
			CFrame = cf * CFrame.new(offset.X, (i - 0.5) * 4, offset.Z) * CFrame.Angles(0, 0, math.rad(math.random(-8, 8))),
			Color = if i % 2 == 0 then pal.Seaweed else pal.GrassDark,
		})
	end
	m.Parent = parent
	return m
end

-- Камень ----------------------------------------------------------------------
local function rock(parent: Instance, cf: CFrame, scale: number)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "Rock"
	for i = 1, math.random(2, 3) do
		P.Part(m, {
			Size = Vector3.new(4 + math.random() * 5, 3 + math.random() * 4, 4 + math.random() * 5) * scale,
			CFrame = cf * CFrame.new(math.random(-3, 3) * scale, 1.5 * scale, math.random(-3, 3) * scale)
				* CFrame.Angles(0, math.rad(math.random(0, 90)), 0),
			Color = if i == 1 then pal.StoneDark else pal.Stone,
			Material = Enum.Material.Slate,
		})
	end
	m.Parent = parent
	return m
end

-- Пещера-арка с кристаллами ----------------------------------------------------
local function cave(parent: Instance, cf: CFrame)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "Cave"
	-- колонны
	for side = -1, 1, 2 do
		for i = 1, 3 do
			P.Part(m, {
				Size = Vector3.new(6 - i, 6, 6 - i),
				CFrame = cf * CFrame.new(side * (12 + i * 0.6), (i - 0.5) * 6, 0),
				Color = pal.StoneDark, Material = Enum.Material.Slate,
			})
		end
	end
	-- свод
	for i = 1, 4 do
		P.Part(m, {
			Size = Vector3.new(30 - i * 2, 5, 8 - i),
			CFrame = cf * CFrame.new(0, 18 + (i - 0.5) * 5, 0),
			Color = pal.StoneDark, Material = Enum.Material.Slate,
		})
	end
	-- кристаллы внутри
	for i = 1, 4 do
		local c = P.Neon(m, {
			Size = Vector3.new(1.6, 4 + math.random() * 3, 1.6),
			CFrame = cf * CFrame.new(math.random(-8, 8), 2, math.random(-2, 2))
				* CFrame.Angles(math.rad(math.random(-15, 15)), 0, math.rad(math.random(-15, 15))),
			Color = ctx.Config.Palette.Cyan,
		})
		P.Light(c, ctx.Config.Palette.Cyan, 14, 1)
	end
	m.Parent = parent
	return m
end

-- Портальное кольцо -------------------------------------------------------------
local function portalRing(parent: Instance, cf: CFrame, radius: number, color: Color3, name: string): Model
	local P = ctx.Build
	local m = Instance.new("Model")
	m.Name = name
	local segments = 14
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		P.Neon(m, {
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = cf * CFrame.new(pos) * CFrame.Angles(0, 0, a),
			Color = color, Shape = Enum.PartType.Ball, CanCollide = false,
		})
	end
	-- зона срабатывания
	local zone = P.Part(m, {
		Size = Vector3.new(radius * 1.7, radius * 1.7, 6),
		CFrame = cf, Transparency = 1, CanCollide = false, Name = "PortalZone",
	})
	zone.Anchored = true
	local center = P.Neon(m, {
		Size = Vector3.new(2, 2, 2), CFrame = cf, Color = color,
		Shape = Enum.PartType.Ball, CanCollide = false, Name = "PortalCore",
	})
	P.Light(center, color, 30, 2)
	ctx.Build.Sparkles(center, color)
	ctx.Build.Billboard(center, name == "PortalSurface" and "🌊 Нырнуть" or "⬆ На поверхность", color, radius + 4)
	m.PrimaryPart = zone
	m.Parent = parent
	return m
end

-- Магазин -----------------------------------------------------------------------
local function buildShop(parent: Instance, cf: CFrame)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "Shop"

	-- пол и стены
	P.Part(m, { Size = Vector3.new(28, 1.4, 22), CFrame = cf * CFrame.new(0, 0.7, 0), Color = pal.WoodDark })
	P.Part(m, { Size = Vector3.new(28, 12, 1.6), CFrame = cf * CFrame.new(0, 6, -10.2), Color = pal.Wood })      -- задняя
	P.Part(m, { Size = Vector3.new(1.6, 12, 22), CFrame = cf * CFrame.new(-13.2, 6, 0), Color = pal.Wood })      -- левая
	P.Part(m, { Size = Vector3.new(1.6, 12, 22), CFrame = cf * CFrame.new(13.2, 6, 0), Color = pal.Wood })       -- правая
	-- угловые балки
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			P.Part(m, { Size = Vector3.new(2.2, 13, 2.2), CFrame = cf * CFrame.new(sx * 13.2, 6.5, sz * 10.2), Color = pal.WoodDark })
		end
	end
	-- крыша (два ската из клиньев)
	P.Wedge(m, { Size = Vector3.new(30, 7, 12), CFrame = cf * CFrame.new(0, 15.5, -5.5), Color = pal.Red })
	P.Wedge(m, { Size = Vector3.new(30, 7, 12), CFrame = cf * CFrame.new(0, 15.5, 5.5) * CFrame.Angles(0, math.rad(180), 0), Color = pal.Red })
	P.Part(m, { Size = Vector3.new(30, 1.4, 2.4), CFrame = cf * CFrame.new(0, 19.4, 0), Color = pal.WoodDark })

	-- прилавок
	P.Part(m, { Size = Vector3.new(16, 3.4, 3), CFrame = cf * CFrame.new(0, 2.4, -4), Color = pal.WoodDark })
	P.Part(m, { Size = Vector3.new(17, 0.8, 3.6), CFrame = cf * CFrame.new(0, 4.4, -4), Color = pal.Wood })
	-- витрина: мини-винт и шестерёнка
	local gear = P.Part(m, { Size = Vector3.new(0.8, 3, 3), CFrame = cf * CFrame.new(-4, 6.4, -4) * CFrame.Angles(0, 0, math.rad(90)), Color = pal.Yellow, Shape = Enum.PartType.Cylinder })
	ctx.Build.Sparkles(gear)
	P.Part(m, { Size = Vector3.new(3, 0.8, 1.2), CFrame = cf * CFrame.new(4, 5.6, -4), Color = pal.Stone })
	P.Part(m, { Size = Vector3.new(1.2, 0.8, 3), CFrame = cf * CFrame.new(4, 5.6, -4), Color = pal.Stone })

	-- вывеска
	local sign = P.Part(m, { Size = Vector3.new(14, 4, 0.8), CFrame = cf * CFrame.new(0, 13.5, 11.2), Color = pal.Yellow })
	ctx.Build.Billboard(sign, "🛒 МАГАЗИН", pal.Black, 0.5, 30)
	-- фонари
	for sx = -1, 1, 2 do
		local lamp = P.Neon(m, { Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(sx * 12, 11, 10.5), Color = pal.Yellow, Shape = Enum.PartType.Ball })
		P.Light(lamp, pal.Yellow, 18, 1.4)
	end

	-- промпт открытия магазина
	local promptPart = P.Part(m, { Size = Vector3.new(10, 1, 6), CFrame = cf * CFrame.new(0, 1.6, 6), Transparency = 1, CanCollide = false, Name = "ShopZone" })
	local pp = ctx.Build.Prompt(promptPart, "Открыть", "Магазин деталей")
	pp.Triggered:Connect(function(player)
		ctx.Remotes.OpenShop:FireClient(player)
	end)

	m.PrimaryPart = sign
	m.Parent = parent
	return m
end

-- Статуя пчелы на хабе -----------------------------------------------------------
local function beeStatue(parent: Instance, cf: CFrame)
	local P = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "BeeStatue"
	-- постамент
	P.Part(m, { Size = Vector3.new(14, 2, 14), CFrame = cf * CFrame.new(0, 1, 0), Color = pal.Stone })
	P.Part(m, { Size = Vector3.new(11, 2, 11), CFrame = cf * CFrame.new(0, 3, 0), Color = pal.StoneDark })
	local base = cf * CFrame.new(0, 8, 0)
	-- тело
	P.Part(m, { Size = Vector3.new(6, 5, 9), CFrame = base, Color = pal.BeeYellow, Shape = Enum.PartType.Ball })
	P.Part(m, { Size = Vector3.new(6.2, 5.2, 2), CFrame = base * CFrame.new(0, 0, -1), Color = pal.Black })
	P.Part(m, { Size = Vector3.new(6.2, 5.2, 2), CFrame = base * CFrame.new(0, 0, 2), Color = pal.Black })
	-- голова
	P.Part(m, { Size = Vector3.new(4, 4, 4), CFrame = base * CFrame.new(0, 1, 5.6), Color = pal.BeeYellow, Shape = Enum.PartType.Ball })
	-- глаза
	for sx = -1, 1, 2 do
		P.Neon(m, { Size = Vector3.new(0.9, 0.9, 0.9), CFrame = base * CFrame.new(sx * 1.1, 1.6, 7.4), Color = pal.Black, Shape = Enum.PartType.Ball })
	end
	-- крылья
	for sx = -1, 1, 2 do
		P.Part(m, {
			Size = Vector3.new(0.4, 4.5, 6), CFrame = base * CFrame.new(sx * 2.4, 4.6, -0.5) * CFrame.Angles(0, 0, sx * math.rad(35)),
			Color = pal.White, Transparency = 0.35, Material = Enum.Material.Glass,
		})
	end
	-- жало
	P.Wedge(m, { Size = Vector3.new(2, 2, 3), CFrame = base * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.rad(-90), 0), Color = pal.Black })
	local crown = P.Neon(m, { Size = Vector3.new(2.4, 1.6, 2.4), CFrame = base * CFrame.new(0, 6.6, 0), Color = pal.Yellow, Shape = Enum.PartType.Cylinder })
	P.Light(crown, pal.Yellow, 20, 1.5)
	ctx.Build.Billboard(crown, "🐝 BuzzBlocks", pal.Yellow, 5, 34)
	m.PrimaryPart = crown
	m.Parent = parent
	return m
end

-- Постройка мира ------------------------------------------------------------------
local function buildWorld()
	local Config = ctx.Config
	local Build = ctx.Build
	local pal = Config.Palette

	worldFolder = Instance.new("Folder")
	worldFolder.Name = "BuzzWorld"

	-- Вода ----------------------------------------------------------------------
	Build.Part(worldFolder, {
		Size = Vector3.new(1600, 2, 1600),
		CFrame = CFrame.new(0, Config.SeaLevel - 1, 0),
		Color = Color3.fromRGB(40, 130, 200), Material = Enum.Material.Glass,
		Transparency = 0.35, CanCollide = false, Name = "Sea",
	})
	-- Дно океана
	Build.Part(worldFolder, {
		Size = Vector3.new(1600, 6, 1600),
		CFrame = CFrame.new(0, Config.OceanFloor - 3, 0),
		Color = pal.Sand, Material = Enum.Material.Sand, Name = "OceanFloor",
	})
	-- глубокий пояс
	cyl(worldFolder, CFrame.new(0, Config.OceanFloor + 0.6, 0), 1.2, 700, pal.SandDeep, Enum.Material.Sand)

	-- Хаб -----------------------------------------------------------------------
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	island(hub, Vector3.new(0, 0, 0), 42)
	-- плаза с LEGO-studs
	local plaza = cyl(hub, CFrame.new(0, 2.9, 0), 0.9, 56, pal.Stone)
	Build.Studs(hub, CFrame.new(0, 3.35, 0), Vector3.new(52, 0.1, 52), pal.StoneDark, 4)
	beeStatue(hub, CFrame.new(0, 3.2, 0))
	buildShop(hub, CFrame.new(0, 3.2, -26))
	-- деревья по краю хаба
	for i = 1, 5 do
		local a = math.rad(40 + i * 55)
		Build.Tree(hub, CFrame.new(math.cos(a) * 34, 2.8, math.sin(a) * 34), 0.9)
	end
	hub.Parent = worldFolder

	-- Точка появления
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 3.9, 12)
	spawn.Color = pal.GrassDark
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = worldFolder

	-- Острова под базы --------------------------------------------------------------
	for i = 1, Config.PlotCount do
		local angle = (i - 1) / Config.PlotCount * math.pi * 2 + math.rad(22.5)
		local pos = Vector3.new(math.cos(angle) * Config.BaseRadius, 0, math.sin(angle) * Config.BaseRadius)
		local isl = Instance.new("Model")
		isl.Name = "PlotIsland" .. i
		island(isl, pos, 30)
		Build.Tree(isl, CFrame.new(pos + Vector3.new(-18, 2.8, -14)), 0.7)
		isl.Parent = worldFolder
		-- CFrame острова: смотрит на центр карты
		WorldService.PlotCF[i] = CFrame.lookAt(pos + Vector3.new(0, 2.8, 0), Vector3.new(0, 2.8, 0))
	end

	-- Порталы ------------------------------------------------------------------------
	WorldService.PortalSurface = portalRing(worldFolder, CFrame.new(58, 4, 0) * CFrame.Angles(0, math.rad(90), 0), 10, pal.Cyan, "PortalSurface")
	WorldService.PortalUnder = portalRing(worldFolder, CFrame.new(0, -44, 26), 10, pal.Orange, "PortalUnder")

	-- Подводный док ----------------------------------------------------------------------
	local dock = Instance.new("Model")
	dock.Name = "UnderwaterDock"
	Build.Part(dock, { Size = Vector3.new(34, 2, 34), CFrame = CFrame.new(0, -48, 0), Color = pal.StoneDark, Material = Enum.Material.Slate })
	Build.Studs(dock, CFrame.new(0, -46.9, 0), Vector3.new(30, 0.1, 30), pal.Stone, 4)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local pillar = Build.Part(dock, {
				Size = Vector3.new(2, 12, 2),
				CFrame = CFrame.new(sx * 15, -42, sz * 15),
				Color = pal.WoodDark,
			})
			local lamp = Build.Neon(dock, { Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(sx * 15, -35.5, sz * 15), Color = pal.Cyan, Shape = Enum.PartType.Ball })
			Build.Light(lamp, pal.Cyan, 24, 1.6)
			pillar.Name = "DockPillar"
		end
	end
	dock.Parent = worldFolder

	-- Подводные декорации ---------------------------------------------------------------
	local decor = Instance.new("Folder")
	decor.Name = "UnderwaterDecor"
	local coralColors = { pal.Coral1, pal.Coral2, pal.Coral3, pal.Coral4 }
	local rng = Random.new(12345)

	for i = 1, 90 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 330)
		local pos = Vector3.new(math.cos(a) * r, Config.OceanFloor + 3, math.sin(a) * r)
		coral(decor, CFrame.new(pos), coralColors[rng:NextInteger(1, #coralColors)], rng:NextNumber(0.7, 2.2))
	end
	for i = 1, 70 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(35, 320)
		local pos = Vector3.new(math.cos(a) * r, Config.OceanFloor + 3, math.sin(a) * r)
		seaweed(decor, CFrame.new(pos), rng:NextNumber(8, 24))
	end
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(50, 300)
		local pos = Vector3.new(math.cos(a) * r, Config.OceanFloor + 2, math.sin(a) * r)
		rock(decor, CFrame.new(pos), rng:NextNumber(0.8, 2.4))
	end
	for i = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(80, 260)
		local pos = Vector3.new(math.cos(a) * r, Config.OceanFloor + 2, math.sin(a) * r)
		cave(decor, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	end
	-- гейзеры с пузырями
	for i = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(40, 310)
		local vent = Build.Part(decor, {
			Size = Vector3.new(3, 2, 3),
			CFrame = CFrame.new(math.cos(a) * r, Config.OceanFloor + 4, math.sin(a) * r),
			Color = pal.StoneDark, Material = Enum.Material.Slate,
		})
		Build.Bubbles(vent, 3, 0.9)
	end
	-- жемчужины
	for i = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(50, 280)
		local pearl = Build.Neon(decor, {
			Size = Vector3.new(1.8, 1.8, 1.8),
			CFrame = CFrame.new(math.cos(a) * r, Config.OceanFloor + 4.4, math.sin(a) * r),
			Color = pal.Pink, Shape = Enum.PartType.Ball,
		})
		Build.Sparkles(pearl, pal.Pink)
		Build.Light(pearl, pal.Pink, 10, 0.8)
	end
	decor.Parent = worldFolder

	worldFolder.Parent = workspace
end

-- Телепорт-площадки хаб <-> база (создаются BaseService для конкретного игрока) -----
function WorldService.MakeTeleporter(fromCF: CFrame, toCF: CFrame, color: Color3, label: string, parent: Instance)
	local Build = ctx.Build
	local pad = Build.Neon(parent, {
		Size = Vector3.new(6, 0.6, 6), CFrame = fromCF, Color = color,
		CanCollide = false, Name = "TelePad_" .. label,
	})
	local ring = Build.Part(parent, {
		Size = Vector3.new(7.4, 0.3, 7.4), CFrame = fromCF * CFrame.new(0, -0.35, 0),
		Color = ctx.Config.Palette.StoneDark, CanCollide = false,
	})
	Build.Billboard(pad, label, color, 3)
	ring.Name = "TelePadRing"
	local debounce = {}
	pad.Touched:Connect(function(hit)
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp or debounce[player] then return end
		debounce[player] = true
		hrp.CFrame = toCF * CFrame.new(0, 4, 0)
		task.delay(1.5, function() debounce[player] = nil end)
	end)
	return pad
end

-- Страховка: упал за карту — вернуть на хаб ---------------------------------------
local function startFallGuard()
	RunService.Heartbeat:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < ctx.Config.OceanFloor - 20 then
				hrp.CFrame = WorldService.HubCF * CFrame.new(0, 6, 0)
			end
		end
	end)
end

function WorldService.Init(c)
	ctx = c
end

function WorldService.Start()
	buildWorld()
	startFallGuard()
	print("[BuzzBlocks] Мир построен.")
end

return WorldService
