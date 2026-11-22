--!strict
--==============================================================================
-- BuzzBlocks :: AnimalService
-- Подводные жители: блочные модели, процедурное плавание, виляние хвостом,
-- кража семян (нужно быть в подлодке), восстановление семян.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AnimalService = {}
local ctx
local animalsFolder: Folder
local animals = {}

-- Модели животных (строятся «носом» вдоль +X, s — масштаб) -------------------------
-- Возвращают: model, root

local function recordParts(model: Model, root: BasePart)
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			table.insert(parts, {
				Part = d,
				Offset = root.CFrame:ToObjectSpace(d.CFrame),
				Wiggle = d:GetAttribute("Wiggle") or 0,
			})
		end
	end
	return parts
end

local builders = {}

function builders.Clownfish(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(3, 2, 1.6) * s, CFrame = CFrame.new(0, 0, 0), Color = pal.Orange, Name = "Root" })
	Build.Part(m, { Size = Vector3.new(0.7, 2.1, 1.7) * s, CFrame = CFrame.new(0.6 * s, 0, 0), Color = pal.White })
	local tail = Build.Wedge(m, { Size = Vector3.new(1.6, 1.8, 0.5) * s, CFrame = CFrame.new(-2.2 * s, 0, 0) * CFrame.Angles(0, math.rad(180), 0), Color = pal.Orange })
	tail:SetAttribute("Wiggle", 0.5)
	Build.Wedge(m, { Size = Vector3.new(1, 0.8, 0.3) * s, CFrame = CFrame.new(0, 1.3 * s, 0), Color = pal.Orange })
	Build.Neon(m, { Size = Vector3.new(0.4, 0.4, 0.4) * s, CFrame = CFrame.new(1.2 * s, 0.4 * s, 0.6 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	Build.Neon(m, { Size = Vector3.new(0.4, 0.4, 0.4) * s, CFrame = CFrame.new(1.2 * s, 0.4 * s, -0.6 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	return m, body
end

function builders.Turtle(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(3.6, 1.8, 3) * s, CFrame = CFrame.new(0, 0.4 * s, 0), Color = pal.Seaweed, Shape = Enum.PartType.Ball, Name = "Root" })
	Build.Part(m, { Size = Vector3.new(3, 0.9, 2.4) * s, CFrame = CFrame.new(0, -0.5 * s, 0), Color = pal.Sand })
	Build.Part(m, { Size = Vector3.new(1.1, 1, 1.1) * s, CFrame = CFrame.new(2.2 * s, 0.2 * s, 0), Color = pal.GrassDark })
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			local f = Build.Wedge(m, { Size = Vector3.new(1.4, 0.5, 1) * s, CFrame = CFrame.new(sx * 1.3 * s, -0.6 * s, sz * 1.8 * s) * CFrame.Angles(0, sz * math.rad(20), 0), Color = pal.GrassDark })
			f:SetAttribute("Wiggle", 0.25)
		end
	end
	return m, body
end

function builders.Stingray(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(3.2, 0.7, 2.6) * s, CFrame = CFrame.new(0, 0, 0), Color = pal.Purple, Name = "Root" })
	local lw = Build.Wedge(m, { Size = Vector3.new(2.6, 0.6, 2.2) * s, CFrame = CFrame.new(0, 0, 2.2 * s) * CFrame.Angles(0, math.rad(-90), 0), Color = pal.Purple })
	local rw = Build.Wedge(m, { Size = Vector3.new(2.6, 0.6, 2.2) * s, CFrame = CFrame.new(0, 0, -2.2 * s) * CFrame.Angles(0, math.rad(90), 0), Color = pal.Purple })
	lw:SetAttribute("Wiggle", 0.3)
	rw:SetAttribute("Wiggle", -0.3)
	local tail = Build.Part(m, { Size = Vector3.new(3, 0.3, 0.3) * s, CFrame = CFrame.new(-3 * s, 0, 0), Color = pal.StoneDark })
	tail:SetAttribute("Wiggle", 0.4)
	Build.Neon(m, { Size = Vector3.new(0.4, 0.4, 0.4) * s, CFrame = CFrame.new(1.2 * s, 0.4 * s, 0.6 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	Build.Neon(m, { Size = Vector3.new(0.4, 0.4, 0.4) * s, CFrame = CFrame.new(1.2 * s, 0.4 * s, -0.6 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	return m, body
end

function builders.Octopus(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(2.6, 2.6, 2.6) * s, CFrame = CFrame.new(0, 1.2 * s, 0), Color = pal.Pink, Shape = Enum.PartType.Ball, Name = "Root" })
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local t = Build.Part(m, {
			Size = Vector3.new(0.7, 2.8, 0.7) * s,
			CFrame = CFrame.new(0, -0.4 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0.9 * s, -1 * s, 0) * CFrame.Angles(0, 0, math.rad(20)),
			Color = pal.Pink,
		})
		t:SetAttribute("Wiggle", 0.2 + (i % 3) * 0.1)
	end
	Build.Neon(m, { Size = Vector3.new(0.5, 0.5, 0.5) * s, CFrame = CFrame.new(1.2 * s, 1.4 * s, 0.6 * s), Color = pal.White, Shape = Enum.PartType.Ball })
	Build.Neon(m, { Size = Vector3.new(0.5, 0.5, 0.5) * s, CFrame = CFrame.new(1.2 * s, 1.4 * s, -0.6 * s), Color = pal.White, Shape = Enum.PartType.Ball })
	return m, body
end

function builders.Shark(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(5.5, 2, 2.2) * s, CFrame = CFrame.new(0, 0, 0), Color = pal.Stone, Name = "Root" })
	Build.Wedge(m, { Size = Vector3.new(2, 1.8, 2) * s, CFrame = CFrame.new(3.6 * s, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Color = pal.Stone })
	Build.Part(m, { Size = Vector3.new(4.5, 0.8, 2) * s, CFrame = CFrame.new(0, -0.9 * s, 0), Color = pal.White })
	local tail = Build.Wedge(m, { Size = Vector3.new(2.4, 2.6, 0.5) * s, CFrame = CFrame.new(-3.8 * s, 0.4 * s, 0) * CFrame.Angles(0, math.rad(180), 0), Color = pal.Stone })
	tail:SetAttribute("Wiggle", 0.6)
	Build.Wedge(m, { Size = Vector3.new(1.4, 1.6, 0.4) * s, CFrame = CFrame.new(0.3 * s, 1.7 * s, 0), Color = pal.Stone })
	for sz = -1, 1, 2 do
		Build.Wedge(m, { Size = Vector3.new(1.4, 0.9, 0.4) * s, CFrame = CFrame.new(0.8 * s, -0.7 * s, sz * 1.4 * s) * CFrame.Angles(math.rad(90), 0, 0), Color = pal.Stone })
		Build.Neon(m, { Size = Vector3.new(0.4, 0.4, 0.4) * s, CFrame = CFrame.new(2.6 * s, 0.5 * s, sz * 0.9 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	end
	return m, body
end

function builders.Whale(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(7, 3.4, 3.6) * s, CFrame = CFrame.new(0, 0, 0), Color = pal.Blue, Name = "Root" })
	Build.Part(m, { Size = Vector3.new(6, 1.4, 3.2) * s, CFrame = CFrame.new(0.3 * s, -1.4 * s, 0), Color = pal.White })
	local flukeL = Build.Wedge(m, { Size = Vector3.new(1.8, 0.6, 2) * s, CFrame = CFrame.new(-4.2 * s, 0.3 * s, 1.2 * s) * CFrame.Angles(0, math.rad(-30), 0), Color = pal.Blue })
	local flukeR = Build.Wedge(m, { Size = Vector3.new(1.8, 0.6, 2) * s, CFrame = CFrame.new(-4.2 * s, 0.3 * s, -1.2 * s) * CFrame.Angles(0, math.rad(30), 0), Color = pal.Blue })
	flukeL:SetAttribute("Wiggle", 0.35)
	flukeR:SetAttribute("Wiggle", 0.35)
	for sz = -1, 1, 2 do
		Build.Wedge(m, { Size = Vector3.new(1.8, 0.8, 0.5) * s, CFrame = CFrame.new(1.4 * s, -1.2 * s, sz * 2 * s) * CFrame.Angles(math.rad(90), 0, 0), Color = pal.Blue })
		Build.Neon(m, { Size = Vector3.new(0.45, 0.45, 0.45) * s, CFrame = CFrame.new(3.2 * s, 0.6 * s, sz * 1.2 * s), Color = pal.Black, Shape = Enum.PartType.Ball })
	end
	-- фонтанчик
	local spout = Build.Part(m, { Size = Vector3.new(0.8, 0.4, 0.8) * s, CFrame = CFrame.new(2.4 * s, 1.9 * s, 0), Color = pal.DeepBlue })
	Build.Bubbles(spout, 2, 0.8)
	return m, body
end

function builders.Kraken(Build, pal, s)
	local m = Instance.new("Model")
	local body = Build.Part(m, { Size = Vector3.new(3.2, 3.6, 3.2) * s, CFrame = CFrame.new(0, 1.4 * s, 0), Color = pal.Red, Shape = Enum.PartType.Ball, Name = "Root" })
	-- корона из шипов
	for i = 0, 4 do
		local a = math.rad(i * 72)
		Build.Wedge(m, { Size = Vector3.new(1, 1.6, 1) * s, CFrame = CFrame.new(0, 3.2 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.4 * s, 0.4 * s, 0), Color = pal.Red })
	end
	-- щупальца
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local t = Build.Part(m, {
			Size = Vector3.new(1, 4.5, 1) * s,
			CFrame = CFrame.new(0, -0.6 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.new(1.5 * s, -1.6 * s, 0) * CFrame.Angles(0, 0, math.rad(28)),
			Color = pal.Red,
		})
		t:SetAttribute("Wiggle", 0.25 + (i % 4) * 0.08)
	end
	-- светящиеся глаза
	for sz = -1, 1, 2 do
		local eye = Build.Neon(m, { Size = Vector3.new(0.9, 0.9, 0.9) * s, CFrame = CFrame.new(1.5 * s, 1.8 * s, sz * 0.9 * s), Color = pal.Yellow, Shape = Enum.PartType.Ball })
		Build.Light(eye, pal.Yellow, 18, 1.4)
	end
	return m, body
end

-- Спавн --------------------------------------------------------------------------
local function pickWeightedAnimal()
	local Config = ctx.Config
	local total = 0
	for _, a in ipairs(Config.Animals) do total += a.Weight end
	local roll = math.random() * total
	for _, a in ipairs(Config.Animals) do
		roll -= a.Weight
		if roll <= 0 then return a end
	end
	return Config.Animals[1]
end

local function randomOceanPoint(depth: number): Vector3
	local a = math.random() * math.pi * 2
	local r = 50 + math.random() * 240
	local y = math.clamp(depth + math.random(-8, 8), ctx.Config.OceanFloor + 8, -10)
	return Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

local function setSeedVisible(rec, visible: boolean)
	rec.SeedOrb.Transparency = visible and 0 or 1
	local spark = rec.SeedOrb:FindFirstChildWhichIsA("Sparkles")
	if spark then spark.Enabled = visible end
end

local function spawnAnimal()
	local Config = ctx.Config
	local Build = ctx.Build
	local cfg = pickWeightedAnimal()
	local builder = builders[cfg.Id]
	if not builder then return end

	local model, root = builder(Build, Config.Palette, cfg.Scale)
	model.Name = "Animal_" .. cfg.Id

	-- семя на спине (светящийся орб)
	local orb = Build.Neon(model, {
		Size = Vector3.new(1, 1, 1) * cfg.Scale,
		CFrame = root.CFrame * CFrame.new(0, 2.4 * cfg.Scale, 0),
		Color = Config.Palette[cfg.SeedColor] or Config.Palette.Yellow,
		Shape = Enum.PartType.Ball, CanCollide = false, Name = "SeedOrb",
	})
	Build.Sparkles(orb, Config.Palette[cfg.SeedColor])

	-- коллизии выкл, всё заякорено (анимация CFrame-ами)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.Anchored = true
		end
	end

	-- подпись
	local rarityColor = Config.RarityColors[cfg.Rarity]
	Build.Billboard(root, cfg.Name, rarityColor, 4.5 * cfg.Scale)

	-- промпт кражи семени
	local pp = Build.Prompt(root, "Забрать семя 🌱", cfg.Name .. " · " .. Config.RarityNames[cfg.Rarity])
	pp.MaxActivationDistance = 16

	local rec = {
		Cfg = cfg,
		Model = model,
		Root = root,
		Parts = recordParts(model, root),
		Pos = randomOceanPoint(cfg.Depth),
		Target = randomOceanPoint(cfg.Depth),
		Phase = math.random() * 10,
		HasSeed = true,
		SeedOrb = orb,
		Yaw = 0,
	}

	pp.Triggered:Connect(function(player)
		local d = ctx.Services.DataService.Get(player)
		if not d then return end
		if not rec.HasSeed then
			ctx.Remotes.Notify:FireClient(player, "У " .. cfg.Name .. " пока нет семени!", "Red")
			return
		end
		if not ctx.Services.SubmarineService.IsDriving(player) then
			ctx.Remotes.Notify:FireClient(player, "Красть семена можно только из подлодки! 🚢", "Red")
			return
		end
		rec.HasSeed = false
		setSeedVisible(rec, false)
		d.Seeds[cfg.Id] = (d.Seeds[cfg.Id] or 0) + 1
		ctx.Remotes.Notify:FireClient(player, "🌱 Семя: " .. cfg.Name .. "!", "Green")
		ctx.Services.DataService.PushState(player)
		task.delay(Config.AnimalRespawnSeed, function()
			if rec.Model.Parent then
				rec.HasSeed = true
				setSeedVisible(rec, true)
			end
		end)
	end)

	model.PrimaryPart = root
	model.Parent = animalsFolder
	table.insert(animals, rec)
end

-- Анимация плавания ------------------------------------------------------------------
local function swimTick(dt: number)
	local t = os.clock()
	for _, rec in ipairs(animals) do
		if not rec.Model.Parent then continue end
		local cfg = rec.Cfg

		-- цель достигнута — выбрать новую
		local toTarget = rec.Target - rec.Pos
		if toTarget.Magnitude < 8 then
			rec.Target = randomOceanPoint(cfg.Depth)
			toTarget = rec.Target - rec.Pos
		end

		-- движение
		local dir = toTarget.Unit
		rec.Pos += dir * cfg.Speed * dt

		-- плавный разворот (модель смотрит носом +X)
		local targetYaw = math.atan2(-dir.Z, dir.X)
		local dy = targetYaw - rec.Yaw
		dy = (dy + math.pi) % (math.pi * 2) - math.pi
		rec.Yaw += dy * math.min(1, dt * 2.5)

		-- покачивание
		local bob = math.sin(t * 1.6 + rec.Phase) * 1.4
		local rootCF = CFrame.new(rec.Pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, rec.Yaw, 0)
		rec.Root.CFrame = rootCF

		-- части тела + виляние
		for _, p in ipairs(rec.Parts) do
			local wig = 0
			if p.Wiggle ~= 0 then
				wig = math.sin(t * 6 + rec.Phase) * p.Wiggle
			end
			p.Part.CFrame = rootCF * CFrame.Angles(0, wig, 0) * p.Offset
		end
	end
end

function AnimalService.Init(c)
	ctx = c
end

function AnimalService.Start()
	animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "OceanAnimals"
	animalsFolder.Parent = workspace

	for _ = 1, ctx.Config.AnimalCount do
		spawnAnimal()
	end

	RunService.Heartbeat:Connect(swimTick)
	print("[BuzzBlocks] Животные заспавнены: " .. #animals)
end

return AnimalService
