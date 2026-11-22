--!strict
--==============================================================================
-- LunarBase :: WorldService
-- Лунная поверхность: грунт, кратеры, камни, Земля на небе, пыль, освещение.
--==============================================================================

local WorldService = {}
local ctx

local rng = Random.new(1337)

-- Проверка: не попадает ли точка на участок игрока
local function nearPlot(x: number, z: number, radius: number): boolean
	for _, c in ipairs(ctx.Config.Plots) do
		if math.abs(x - c.X) < radius and math.abs(z - c.Z) < radius then
			return true
		end
	end
	return false
end

-- Кратер: тёмное дно + кольцевой вал --------------------------------------------
local function buildCrater(parent: Instance, x: number, z: number, r: number)
	local B = ctx.Build
	-- дно
	local floor = B.Part(parent, {
		Size = Vector3.new(r * 2, 0.4, r * 2),
		CFrame = CFrame.new(x, 0.15, z),
		Color = Color3.fromRGB(78, 78, 84),
		Shape = Enum.PartType.Cylinder,
		Name = "CraterFloor",
	})
	floor.CFrame = floor.CFrame * CFrame.Angles(0, 0, math.rad(90))
	floor.Material = Enum.Material.Slate
	-- вал из блоков по кругу
	local segments = math.max(8, math.floor(r * 0.9))
	for i = 0, segments - 1 do
		local ang = (i / segments) * math.pi * 2
		local rr = r * (1 + rng:NextNumber(-0.06, 0.06))
		local h = rng:NextNumber(1.2, 3.2)
		local w = (2 * math.pi * r / segments) * 1.2
		B.Part(parent, {
			Size = Vector3.new(w, h, w * 0.8),
			CFrame = CFrame.new(x + math.cos(ang) * rr, h / 2 - 0.3, z + math.sin(ang) * rr) * CFrame.Angles(0, -ang, 0),
			Color = Color3.fromRGB(112, 112, 118),
			Material = Enum.Material.Slate,
			Name = "CraterRim",
		})
	end
end

-- Камень на поверхности ------------------------------------------------------------
local function buildRock(parent: Instance, x: number, z: number)
	local B = ctx.Build
	local s = rng:NextNumber(1, 4.5)
	local main = B.Part(parent, {
		Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.2)),
		CFrame = CFrame.new(x, s * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		Color = Color3.fromRGB(100 + rng:NextInteger(-12, 12), 100 + rng:NextInteger(-12, 12), 106 + rng:NextInteger(-10, 10)),
		Material = Enum.Material.Slate,
		Name = "MoonRock",
	})
	if rng:NextNumber() < 0.5 then
		B.Part(parent, {
			Size = Vector3.new(s * 0.5, s * 0.4, s * 0.5),
			CFrame = main.CFrame * CFrame.new(s * 0.4, s * 0.3, s * 0.2),
			Color = main.Color,
			Material = Enum.Material.Slate,
		})
	end
end

-- Земля на небе ----------------------------------------------------------------------
local function buildEarth(parent: Instance)
	local B = ctx.Build
	local m = Instance.new("Model")
	m.Name = "Earth"
	local center = Vector3.new(450, 420, -700)
	local R = 90

	local globe = B.Part(m, {
		Size = Vector3.new(R * 2, R * 2, R * 2),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(60, 120, 220),
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.SmoothPlastic,
		Name = "Globe",
	})
	-- материки
	for i = 1, 14 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local patch = B.Part(m, {
			Size = Vector3.new(rng:NextNumber(20, 45), rng:NextNumber(15, 35), rng:NextNumber(10, 20)),
			CFrame = CFrame.new(center + dir * R * 0.92, dir) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
			Color = Color3.fromRGB(60, 160, 80),
			Name = "Continent",
		})
		patch.Material = Enum.Material.SmoothPlastic
	end
	-- облака
	for i = 1, 10 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local cloud = B.Part(m, {
			Size = Vector3.new(rng:NextNumber(25, 50), rng:NextNumber(8, 14), rng:NextNumber(20, 40)),
			CFrame = CFrame.new(center + dir * R * 1.02, dir),
			Color = Color3.new(1, 1, 1),
			Transparency = 0.35,
			Name = "Cloud",
		})
		cloud.Material = Enum.Material.SmoothPlastic
	end
	-- полярные шапки
	for _, dy in ipairs({ -0.92, 0.92 }) do
		B.Part(m, {
			Size = Vector3.new(40, 16, 40),
			CFrame = CFrame.new(center + Vector3.new(0, dy * R, 0)),
			Color = Color3.new(1, 1, 1),
			Shape = Enum.PartType.Ball,
		})
	end
	-- свечение
	B.Light(globe, Color3.fromRGB(120, 160, 255), R * 4, 1.2)
	m.Parent = parent
end

-- Пыль в воздухе ----------------------------------------------------------------------
local function buildDust(parent: Instance)
	local emitter_part = Instance.new("Part")
	emitter_part.Name = "DustEmitter"
	emitter_part.Size = Vector3.new(600, 1, 600)
	emitter_part.CFrame = CFrame.new(0, 4, 0)
	emitter_part.Transparency = 1
	emitter_part.Anchored = true
	emitter_part.CanCollide = false
	emitter_part.Parent = parent

	local a = Instance.new("Attachment")
	a.Parent = emitter_part
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://258128463"
	pe.Color = ColorSequence.new(Color3.fromRGB(180, 180, 190))
	pe.Size = NumberSequence.new(0.4)
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(8, 14)
	pe.Rate = 24
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = a
end

-- Жизненный цикл ----------------------------------------------------------------------
function WorldService.Init(c)
	ctx = c
end

function WorldService.Start()
	local B = ctx.Build
	local world = Instance.new("Folder")
	world.Name = "MoonWorld"
	world.Parent = workspace

	-- лунная поверхность
	local ground = B.Part(world, {
		Size = Vector3.new(1400, 4, 1400),
		CFrame = CFrame.new(0, -2, 0),
		Color = Color3.fromRGB(128, 128, 134),
		Material = Enum.Material.Slate,
		Name = "MoonGround",
	})
	ground.Locked = true

	-- лёгкие холмы вдали от участков
	for i = 1, 40 do
		local x = rng:NextNumber(-650, 650)
		local z = rng:NextNumber(-650, 650)
		if not nearPlot(x, z, 110) then
			local s = rng:NextNumber(20, 60)
			B.Wedge(world, {
				Size = Vector3.new(s, s * rng:NextNumber(0.15, 0.3), s),
				CFrame = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
				Color = Color3.fromRGB(118, 118, 124),
				Material = Enum.Material.Slate,
				Name = "Hill",
			})
		end
	end

	-- кратеры
	for i = 1, 16 do
		local x = rng:NextNumber(-620, 620)
		local z = rng:NextNumber(-620, 620)
		if not nearPlot(x, z, 120) then
			buildCrater(world, x, z, rng:NextNumber(8, 26))
		end
	end

	-- камни
	for i = 1, 130 do
		local x = rng:NextNumber(-680, 680)
		local z = rng:NextNumber(-680, 680)
		if not nearPlot(x, z, 70) then
			buildRock(world, x, z)
		end
	end

	buildEarth(world)
	buildDust(world)

	print("[WorldService] Лунный мир построен")
end

return WorldService
