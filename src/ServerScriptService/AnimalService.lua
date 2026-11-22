--!strict
--==============================================================================
-- BuzzBlocks :: AnimalService (подводные зоны)
-- 7 локаций по прямой вдоль +X: чем дальше, тем ценнее. В каждой зоне спит
-- свой монстр, вокруг разбросаны яйца. Украл яйцо — монстр просыпается
-- и гонится за подлодкой, нанося урон. Портал = спасение.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimalService = {}
local ctx
local zonesFolder: Folder
local zones = {}

-- Тематика зон -----------------------------------------------------------------
local ZoneThemes = {
	Clownfish = { Name = "🐠 Коралловый сад",   Decor = "coral",   Light = "Coral1"  },
	Turtle    = { Name = "🐢 Лес водорослей",   Decor = "kelp",    Light = "Seaweed" },
	Stingray  = { Name = "🛕 Затонувшие руины", Decor = "ruins",   Light = "Sand"    },
	Octopus   = { Name = "🐙 Розовые гроты",    Decor = "grotto",  Light = "Pink"    },
	Shark     = { Name = "🦈 Тёмный риф",       Decor = "rocks",   Light = "Stone"   },
	Whale     = { Name = "🐋 Ледяные чертоги",  Decor = "crystal", Light = "Cyan"    },
	Kraken    = { Name = "🦑 Логово Кракена",   Decor = "lava",    Light = "Red"     },
}

local MonsterKinds = {
	Clownfish = "fish", Shark = "fish", Whale = "fish",
	Turtle = "shell", Stingray = "wings",
	Octopus = "tentacles", Kraken = "tentacles",
}

-- Монстр зоны: крупное блочное существо, растёт с номером зоны --------------------
local function buildMonster(cfg, index: number)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	local s = 1.6 + index * 0.5                    -- зона 1: ~2.1, зона 7: ~4.6
	local color = pal[cfg.SeedColor] or pal.Red
	local kind = MonsterKinds[cfg.Id] or "fish"

	local m = Instance.new("Model")
	m.Name = "Boss_" .. cfg.Id

	local body = Build.Part(m, {
		Size = Vector3.new(4.6, 3.8, 3.8) * s, CFrame = CFrame.new(0, 0, 0),
		Color = color, Shape = Enum.PartType.Ball, Name = "Root",
	})
	-- морда: челюсть
	Build.Wedge(m, { Size = Vector3.new(2.2, 1.6, 3) * s, CFrame = CFrame.new(2.6 * s, -0.9 * s, 0) * CFrame.Angles(0, math.rad(90), 0), Color = pal.StoneDark })
	-- светящиеся красные глаза
	for sz = -1, 1, 2 do
		local eye = Build.Neon(m, { Size = Vector3.new(0.7, 0.7, 0.7) * s, CFrame = CFrame.new(2.2 * s, 0.7 * s, sz * 1.1 * s), Color = pal.Red, Shape = Enum.PartType.Ball })
		Build.Light(eye, pal.Red, 16, 1.5)
	end
	-- шипы на спине
	for i = 0, 3 do
		Build.Wedge(m, {
			Size = Vector3.new(1, 1.6, 1) * s,
			CFrame = CFrame.new((0.8 - i * 1.1) * s, 1.9 * s, 0) * CFrame.Angles(0, 0, math.rad(-12)),
			Color = pal.Black,
		})
	end

	if kind == "fish" then
		local tail = Build.Wedge(m, { Size = Vector3.new(2.4, 3, 0.7) * s, CFrame = CFrame.new(-3.2 * s, 0, 0) * CFrame.Angles(0, math.rad(180), 0), Color = color })
		tail:SetAttribute("Wiggle", 0.55)
		for sz = -1, 1, 2 do
			Build.Wedge(m, { Size = Vector3.new(1.6, 1, 0.4) * s, CFrame = CFrame.new(0.6 * s, -0.9 * s, sz * 2.1 * s) * CFrame.Angles(math.rad(90), 0, 0), Color = color })
		end
	elseif kind == "shell" then
		Build.Part(m, { Size = Vector3.new(5, 2, 4.4) * s, CFrame = CFrame.new(-0.4 * s, 0.9 * s, 0), Color = pal.Earth, Shape = Enum.PartType.Ball })
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local f = Build.Wedge(m, { Size = Vector3.new(1.8, 0.7, 1.3) * s, CFrame = CFrame.new(sx * 1.8 * s, -1.5 * s, sz * 2.4 * s), Color = pal.Seaweed })
				f:SetAttribute("Wiggle", 0.25)
			end
		end
	elseif kind == "wings" then
		for sz = -1, 1, 2 do
			local w = Build.Wedge(m, { Size = Vector3.new(3.4, 0.7, 3) * s, CFrame = CFrame.new(0, 0, sz * 2.8 * s) * CFrame.Angles(0, sz * math.rad(90), 0), Color = color })
			w:SetAttribute("Wiggle", sz * 0.3)
		end
		local tail = Build.Part(m, { Size = Vector3.new(4, 0.4, 0.4) * s, CFrame = CFrame.new(-4 * s, 0, 0), Color = pal.StoneDark })
		tail:SetAttribute("Wiggle", 0.45)
	elseif kind == "tentacles" then
		for i = 0, 7 do
			local a = math.rad(i * 45)
			local t = Build.Part(m, {
				Size = Vector3.new(1, 4.5, 1) * s,
				CFrame = CFrame.new(0, -1 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.7 * s, -2 * s, 0) * CFrame.Angles(0, 0, math.rad(25)),
				Color = color,
			})
			t:SetAttribute("Wiggle", 0.25 + (i % 4) * 0.08)
		end
	end

	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	m.PrimaryPart = body
	return m, body
end

-- Яйцо ---------------------------------------------------------------------------
local function buildEgg(parent: Instance, cf: CFrame, color: Color3, zoneIndex: number)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	local m = Instance.new("Model")
	m.Name = "Egg"
	-- пьедестал
	Build.Part(m, { Size = Vector3.new(3, 1.4, 3), CFrame = cf * CFrame.new(0, 0.7, 0), Color = pal.StoneDark, Material = Enum.Material.Slate })
	-- яйцо
	local egg = Build.Neon(m, {
		Size = Vector3.new(1.7, 2.2, 1.7), CFrame = cf * CFrame.new(0, 2.5, 0),
		Color = color, Shape = Enum.PartType.Ball, Name = "EggOrb",
	})
	Build.Sparkles(egg, color)
	if zoneIndex >= 4 then
		Build.Light(egg, color, 14, 1.2)
	end
	Build.Billboard(egg, "🥚 Яйцо", color, 2.6, 16)
	m.PrimaryPart = egg
	m.Parent = parent
	return m, egg
end

-- Декор зон ------------------------------------------------------------------------
local function decorateZone(parent: Instance, center: Vector3, theme, cfg)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	local rng = Random.new(cfg.Id:len() * 977 + 13)
	local floorY = ctx.Config.OceanFloor + 3
	local r = ctx.Config.ZoneRadius

	local function randPos(radius: number): CFrame
		local a = rng:NextNumber(0, math.pi * 2)
		local rr = rng:NextNumber(10, radius)
		return CFrame.new(center.X + math.cos(a) * rr, floorY, center.Z + math.sin(a) * rr)
	end

	if theme.Decor == "coral" then
		for i = 1, 10 do
			local cf = randPos(r)
			local c = ({ pal.Coral1, pal.Coral2, pal.Coral4 })[rng:NextInteger(1, 3)]
			local trunk = Build.Part(parent, { Size = Vector3.new(1.6, 6, 1.6), CFrame = cf * CFrame.new(0, 3, 0), Color = c })
			Build.Neon(parent, { Size = Vector3.new(2, 2, 2), CFrame = trunk.CFrame * CFrame.new(0, 3.6, 0), Color = c, Shape = Enum.PartType.Ball })
		end
	elseif theme.Decor == "kelp" then
		for i = 1, 14 do
			local cf = randPos(r)
			local h = rng:NextNumber(10, 22)
			for seg = 1, math.floor(h / 4) do
				Build.Part(parent, {
					Size = Vector3.new(1.2, 4.3, 1.2),
					CFrame = cf * CFrame.new(math.sin(seg) * 0.5, (seg - 0.5) * 4, 0),
					Color = if seg % 2 == 0 then pal.Seaweed else pal.GrassDark,
				})
			end
		end
	elseif theme.Decor == "ruins" then
		for i = 1, 6 do
			local cf = randPos(r)
			-- колонна (целая или сломанная)
			local h = rng:NextInteger(2, 5)
			for seg = 1, h do
				Build.Part(parent, { Size = Vector3.new(2.6, 3, 2.6), CFrame = cf * CFrame.new(0, (seg - 0.5) * 3, 0), Color = pal.Sand, Material = Enum.Material.Limestone })
			end
			Build.Part(parent, { Size = Vector3.new(3.4, 1, 3.4), CFrame = cf * CFrame.new(0, h * 3 + 0.5, 0), Color = pal.SandDeep, Material = Enum.Material.Limestone })
		end
		-- плита с рунами
		local slab = Build.Part(parent, { Size = Vector3.new(8, 1, 8), CFrame = randPos(r * 0.6) * CFrame.new(0, 0.5, 0), Color = pal.SandDeep, Material = Enum.Material.Limestone })
		Build.SignText(slab, "𓂀 РУИНЫ", pal.StoneDark, nil, Enum.NormalId.Top)
	elseif theme.Decor == "grotto" then
		for i = 1, 8 do
			local cf = randPos(r)
			Build.Part(parent, { Size = Vector3.new(5, 4 + rng:NextNumber(0, 6), 5), CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = pal.Pink, Material = Enum.Material.Slate })
		end
		for i = 1, 5 do
			local g = Build.Neon(parent, { Size = Vector3.new(1.4, 1.4, 1.4), CFrame = randPos(r) * CFrame.new(0, 1, 0), Color = pal.Purple, Shape = Enum.PartType.Ball })
			Build.Light(g, pal.Purple, 12, 1)
		end
	elseif theme.Decor == "rocks" then
		for i = 1, 9 do
			local cf = randPos(r)
			Build.Part(parent, {
				Size = Vector3.new(4 + rng:NextNumber(0, 6), 4 + rng:NextNumber(0, 8), 4 + rng:NextNumber(0, 6)),
				CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				Color = pal.StoneDark, Material = Enum.Material.Slate,
			})
		end
		-- обломки корабля
		for i = 1, 5 do
			Build.Part(parent, {
				Size = Vector3.new(6, 0.8, 2), CFrame = randPos(r) * CFrame.new(0, 1, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), math.rad(rng:NextInteger(-15, 15))),
				Color = pal.WoodDark,
			})
		end
	elseif theme.Decor == "crystal" then
		for i = 1, 10 do
			local cf = randPos(r)
			local c = Build.Neon(parent, {
				Size = Vector3.new(1.6, 4 + rng:NextNumber(0, 5), 1.6),
				CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(rng:NextInteger(-12, 12)), 0, math.rad(rng:NextInteger(-12, 12))),
				Color = pal.Cyan,
			})
			if i % 3 == 0 then Build.Light(c, pal.Cyan, 14, 1.1) end
		end
	elseif theme.Decor == "lava" then
		for i = 1, 9 do
			local cf = randPos(r)
			Build.Part(parent, {
				Size = Vector3.new(4 + rng:NextNumber(0, 5), 3 + rng:NextNumber(0, 6), 4 + rng:NextNumber(0, 5)),
				CFrame = cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				Color = pal.Black, Material = Enum.Material.Basalt,
			})
			local vent = Build.Neon(parent, { Size = Vector3.new(1.6, 0.8, 1.6), CFrame = cf * CFrame.new(0, 4.6, 0), Color = pal.Red, Shape = Enum.PartType.Ball })
			Build.Light(vent, pal.Red, 16, 1.4)
			if i % 3 == 0 then Build.Bubbles(vent, 4, 0.8, Color3.fromRGB(255, 140, 90)) end
		end
	end
end

-- Врата зоны с названием --------------------------------------------------------------
local function buildGate(parent: Instance, center: Vector3, theme, color: Color3)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	-- врата смотрят на -X (откуда приплывают)
	local gateCF = CFrame.new(center.X - ctx.Config.ZoneRadius - 8, center.Y, center.Z)
	local m = Instance.new("Model")
	m.Name = "ZoneGate"
	for sy = -1, 1, 2 do
		Build.Part(m, { Size = Vector3.new(3, 22, 3), CFrame = gateCF * CFrame.new(0, 0, sy * 12), Color = pal.StoneDark, Material = Enum.Material.Slate })
	end
	local beam = Build.Part(m, { Size = Vector3.new(3, 3.4, 27), CFrame = gateCF * CFrame.new(0, 12, 0), Color = color })
	Build.SignText(beam, theme.Name, pal.Black, nil, Enum.NormalId.Left)
	for sz = -1, 1, 2 do
		local lamp = Build.Neon(m, { Size = Vector3.new(1.6, 1.6, 1.6), CFrame = gateCF * CFrame.new(0, 9, sz * 12), Color = color, Shape = Enum.PartType.Ball })
		Build.Light(lamp, color, 20, 1.5)
	end
	m.Parent = parent
	return m
end

-- Строительство одной зоны ---------------------------------------------------------------
local function buildZone(index: number, cfg)
	local Config = ctx.Config
	local pal = Config.Palette
	local theme = ZoneThemes[cfg.Id]

	local center = Vector3.new(Config.ZoneStart + (index - 1) * Config.ZoneSpacing, cfg.Depth, 0)

	local zoneModel = Instance.new("Model")
	zoneModel.Name = "Zone" .. index .. "_" .. cfg.Id

	buildGate(zoneModel, center, theme, pal[theme.Light] or pal.Cyan)
	decorateZone(zoneModel, center, theme, cfg)

	-- монстр спит в центре зоны
	local monsterModel, root = buildMonster(cfg, index)
	monsterModel.Parent = zoneModel
	local homeCF = CFrame.new(center) * CFrame.Angles(0, math.rad(180), 0) -- смотрит на врата
	root.CFrame = homeCF

	local label = ctx.Build.Billboard(root, "💤 " .. cfg.Name .. " спит…", pal.White, 6 * (1.6 + index * 0.5), 24)

	-- яйца вокруг монстра
	local eggs = {}
	for e = 1, Config.EggsPerZone do
		local a = (e / Config.EggsPerZone) * math.pi * 2 + math.rad(index * 17)
		local rr = 16 + (e % 3) * 8
		local eggCF = CFrame.new(center.X + math.cos(a) * rr, Config.OceanFloor + 3, center.Z + math.sin(a) * rr)
		local eggModel, eggOrb = buildEgg(zoneModel, eggCF, pal[cfg.SeedColor] or pal.Yellow, index)
		local pp = ctx.Build.Prompt(eggOrb, "Взять яйцо 🥚", cfg.Name .. " · " .. Config.RarityNames[cfg.Rarity])
		pp.MaxActivationDistance = 16
		table.insert(eggs, { Model = eggModel, Orb = eggOrb, Prompt = pp, Active = true, CF = eggCF })
	end

	-- смещения частей монстра для анимации
	local parts = {}
	for _, d in ipairs(monsterModel:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			table.insert(parts, { Part = d, Offset = root.CFrame:ToObjectSpace(d.CFrame), Wiggle = d:GetAttribute("Wiggle") or 0 })
		end
	end

	local zone = {
		Index = index,
		Cfg = cfg,
		Theme = theme,
		Center = center,
		HomeCF = homeCF,
		Monster = monsterModel,
		Root = root,
		Parts = parts,
		Label = label:FindFirstChildWhichIsA("TextLabel"),
		Eggs = eggs,
		State = "sleeping",      -- sleeping | chasing | returning
		Target = nil,            -- Player, укравший яйцо
		Pos = center,
		Yaw = math.rad(180),
		Phase = math.random() * 10,
		AttackCd = 0,
	}

	-- обработка кражи яиц
	for _, egg in ipairs(eggs) do
		egg.Prompt.Triggered:Connect(function(player)
			onEggTaken(zone, egg, player)
		end)
	end

	zoneModel.Parent = zonesFolder
	table.insert(zones, zone)
end

-- Кража яйца ---------------------------------------------------------------------------------
function onEggTaken(zone, egg, player: Player)
	local Config = ctx.Config
	if not egg.Active then
		ctx.Remotes.Notify:FireClient(player, "Яйцо ещё не созрело!", "Red")
		return
	end
	local d = ctx.Services.DataService.Get(player)
	if not d then return end
	if not ctx.Services.SubmarineService.IsDriving(player) then
		ctx.Remotes.Notify:FireClient(player, "До яиц можно добраться только на подлодке! 🚢", "Red")
		return
	end

	-- выдаём семя
	egg.Active = false
	egg.Orb.Transparency = 1
	egg.Prompt.Enabled = false
	local spark = egg.Orb:FindFirstChildWhichIsA("Sparkles")
	if spark then spark.Enabled = false end
	d.Seeds[zone.Cfg.Id] = (d.Seeds[zone.Cfg.Id] or 0) + 1
	ctx.Remotes.Notify:FireClient(player, "🥚 Яйцо: " .. zone.Cfg.Name .. "! УХОДИ — оно проснулось!", "Yellow")
	ctx.Services.DataService.PushState(player)

	-- будим монстра: цель — этот игрок
	zone.State = "chasing"
	zone.Target = player
	if zone.Label then
		zone.Label.Text = "💢 " .. zone.Cfg.Name .. " в ярости!"
		zone.Label.TextColor3 = ctx.Config.Palette.Red
	end

	-- возрождение яйца
	task.delay(Config.EggRespawn, function()
		if egg.Model.Parent then
			egg.Active = true
			egg.Orb.Transparency = 0
			egg.Prompt.Enabled = true
			local sp = egg.Orb:FindFirstChildWhichIsA("Sparkles")
			if sp then sp.Enabled = true end
		end
	end)
end

-- Успокоить монстра ---------------------------------------------------------------------------
local function calmDown(zone)
	zone.State = "returning"
	zone.Target = nil
	if zone.Label then
		zone.Label.Text = "💤 " .. zone.Cfg.Name .. " спит…"
		zone.Label.TextColor3 = Color3.new(1, 1, 1)
	end
end

-- ИИ монстров -------------------------------------------------------------------------------------
local function aiTick(dt: number)
	local Config = ctx.Config
	local t = os.clock()

	for _, zone in ipairs(zones) do
		if not zone.Monster.Parent then continue end
		local cfg = zone.Cfg

		if zone.State == "chasing" then
			local player = zone.Target
			local sub = player and ctx.Services.SubmarineService.GetSub(player)
			local validTarget = sub and sub.Model.Parent and player.Character ~= nil

			-- цель ушла/умерла или слишком далеко — возвращаемся
			if not validTarget or (sub.Root.Position - zone.Center).Magnitude > Config.MonsterLeash then
				calmDown(zone)
			else
				-- погоня
				local speed = Config.MonsterBaseSpeed + (zone.Index - 1) * Config.MonsterSpeedPerZone
				local toSub = sub.Root.Position - zone.Pos
				local dist = toSub.Magnitude
				if dist > 1 then
					local dir = toSub.Unit
					zone.Pos += dir * speed * dt
					local targetYaw = math.atan2(-dir.Z, dir.X)
					local dy = (targetYaw - zone.Yaw + math.pi) % (math.pi * 2) - math.pi
					zone.Yaw += dy * math.min(1, dt * 3)
				end

				-- атака
				zone.AttackCd -= dt
				if dist < Config.MonsterAttackRange and zone.AttackCd <= 0 then
					zone.AttackCd = Config.MonsterAttackCooldown
					local damage = Config.MonsterBaseDamage + (zone.Index - 1) * Config.MonsterDamagePerZone
					local hp = (sub.Model:GetAttribute("HP") or 100) - damage
					sub.Model:SetAttribute("HP", hp)
					if hp <= 0 then
						ctx.Remotes.Notify:FireClient(player, "💥 " .. cfg.Name .. " разбил твою подлодку!", "Red")
						ctx.Services.SubmarineService.DestroySub(player)
						calmDown(zone)
					else
						ctx.Remotes.Notify:FireClient(player, "💢 Удар! Прочность: " .. hp, "Red")
					end
				end
			end

		elseif zone.State == "returning" then
			local toHome = zone.Center - zone.Pos
			if toHome.Magnitude < 4 then
				zone.State = "sleeping"
				zone.Pos = zone.Center
				zone.Yaw = math.rad(180)
			else
				local dir = toHome.Unit
				zone.Pos += dir * 14 * dt
				local targetYaw = math.atan2(-dir.Z, dir.X)
				local dy = (targetYaw - zone.Yaw + math.pi) % (math.pi * 2) - math.pi
				zone.Yaw += dy * math.min(1, dt * 2)
			end
		end

		-- анимация: покачивание + виляние частей (спящий монстр «дышит»)
		local bobAmp = if zone.State == "sleeping" then 1.2 else 0.4
		local bob = math.sin(t * (zone.State == "sleeping" and 0.9 or 2.2) + zone.Phase) * bobAmp
		local rootCF = CFrame.new(zone.Pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, zone.Yaw, 0)
		zone.Root.CFrame = rootCF
		for _, p in ipairs(zone.Parts) do
			local wig = 0
			if p.Wiggle ~= 0 then
				wig = math.sin(t * (zone.State == "chasing" and 9 or 4) + zone.Phase) * p.Wiggle
			end
			p.Part.CFrame = rootCF * CFrame.Angles(0, wig, 0) * p.Offset
		end
	end
end

function AnimalService.Init(c)
	ctx = c
end

function AnimalService.Start()
	zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "UnderwaterZones"
	zonesFolder.Parent = workspace

	for i, cfg in ipairs(ctx.Config.Animals) do
		buildZone(i, cfg)
	end

	RunService.Heartbeat:Connect(aiTick)
	print("[BuzzBlocks] Подводные зоны построены: " .. #zones)
end

return AnimalService
