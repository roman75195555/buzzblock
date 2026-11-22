--!strict
--==============================================================================
-- BuzzBlocks :: BeeService
-- Пчёлы: блочная модель, полёт вокруг базы, машущие крылья, подпись дохода.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BeeService = {}
local ctx

-- player -> { rec }
local bees: { [Player]: any } = {}

-- Модель пчелы (строится носом вдоль +X, s — масштаб) --------------------------------
local function buildBeeModel(bee)
	local Build = ctx.Build
	local pal = ctx.Config.Palette
	local s = bee.Scale or 1
	local bodyColor = ctx.Config.MutationColors[bee.Mutation] or pal.BeeYellow

	local m = Instance.new("Model")
	m.Name = "Bee"

	local body = Build.Part(m, {
		Size = Vector3.new(1.8, 1.5, 1.5) * s,
		CFrame = CFrame.new(0, 0, 0),
		Color = bodyColor, Shape = Enum.PartType.Ball, Name = "Root", CanCollide = false,
	})
	-- полоски
	Build.Part(m, { Size = Vector3.new(0.4, 1.55, 1.55) * s, CFrame = CFrame.new(-0.3 * s, 0, 0), Color = pal.Black, CanCollide = false })
	Build.Part(m, { Size = Vector3.new(0.4, 1.55, 1.55) * s, CFrame = CFrame.new(0.45 * s, 0, 0), Color = pal.Black, CanCollide = false })
	-- голова
	Build.Part(m, { Size = Vector3.new(0.9, 0.9, 0.9) * s, CFrame = CFrame.new(1.15 * s, 0.15 * s, 0), Color = pal.Black, Shape = Enum.PartType.Ball, CanCollide = false })
	-- глаза
	for sz = -1, 1, 2 do
		Build.Neon(m, { Size = Vector3.new(0.25, 0.25, 0.25) * s, CFrame = CFrame.new(1.55 * s, 0.3 * s, sz * 0.28 * s), Color = pal.Cyan, Shape = Enum.PartType.Ball, CanCollide = false })
	end
	-- усики
	for sz = -1, 1, 2 do
		Build.Part(m, { Size = Vector3.new(0.1, 0.7, 0.1) * s, CFrame = CFrame.new(1.2 * s, 0.85 * s, sz * 0.25 * s) * CFrame.Angles(0, 0, math.rad(-25)), Color = pal.Black, CanCollide = false })
	end
	-- жало
	Build.Wedge(m, { Size = Vector3.new(0.5, 0.5, 0.5) * s, CFrame = CFrame.new(-1.1 * s, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = pal.Black, CanCollide = false })
	-- крылья
	for sz = -1, 1, 2 do
		local wing = Build.Part(m, {
			Size = Vector3.new(1.1, 0.12, 0.9) * s,
			CFrame = CFrame.new(0, 0.85 * s, sz * 0.7 * s) * CFrame.Angles(0, 0, math.rad(10)),
			Color = pal.White, Transparency = 0.4, Material = Enum.Material.Glass,
			CanCollide = false, Name = if sz < 0 then "WingL" else "WingR",
		})
		wing:SetAttribute("Side", sz)
	end
	-- ореол мутации
	if bee.Mutation and bee.Mutation ~= "None" then
		local halo = Build.Neon(m, { Size = Vector3.new(2.2, 0.25, 2.2) * s, CFrame = CFrame.new(0, -1 * s, 0), Color = bodyColor, Shape = Enum.PartType.Cylinder, CanCollide = false })
		halo.CFrame = halo.CFrame * CFrame.Angles(0, 0, math.rad(90))
		Build.Sparkles(body, bodyColor)
		Build.Light(body, bodyColor, 10, 0.8)
	end

	-- подпись
	local rarityColor = pal.Yellow
	local animal = ctx.Config.GetAnimal(bee.Animal)
	if animal then rarityColor = ctx.Config.RarityColors[animal.Rarity] end
	Build.Billboard(body, "🐝 +" .. tostring(bee.Income) .. "/с", rarityColor, 2.4 * s, 16)

	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	m.PrimaryPart = body
	return m, body
end

-- Спавн пчелы у базы -------------------------------------------------------------------
function BeeService.SpawnBee(player: Player, bee)
	local base = ctx.Services.BaseService.GetBase(player)
	if not base then return end
	local model, root = buildBeeModel(bee)
	model.Parent = workspace

	bees[player] = bees[player] or {}
	local rec = {
		Model = model,
		Root = root,
		Bee = bee,
		Center = base.PlotCF.Position + Vector3.new(6, 0, 0),
		Pos = base.PlotCF.Position + Vector3.new(math.random(-10, 10), 8, math.random(-10, 10)),
		Target = base.PlotCF.Position + Vector3.new(math.random(-14, 14), 7 + math.random(0, 7), math.random(-14, 14)),
		Phase = math.random() * 10,
	}
	-- смещения частей относительно корня
	rec.Parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			table.insert(rec.Parts, { Part = d, Offset = root.CFrame:ToObjectSpace(d.CFrame), Side = d:GetAttribute("Side") })
		end
	end
	table.insert(bees[player], rec)
end

-- Восстановление пчёл после захода -------------------------------------------------------
function BeeService.OnBaseReady(player: Player, _base)
	local d = ctx.Services.DataService.Get(player)
	if not d then return end
	for _, bee in ipairs(d.Bees) do
		BeeService.SpawnBee(player, bee)
	end
end

-- Полёт -------------------------------------------------------------------------------------
local function flyTick(dt: number)
	local t = os.clock()
	for player, list in pairs(bees) do
		if not player.Parent then
			-- игрок вышел — убрать его пчёл из мира
			for _, rec in ipairs(list) do
				if rec.Model then rec.Model:Destroy() end
			end
			bees[player] = nil
			continue
		end
		for _, rec in ipairs(list) do
			if not rec.Model.Parent then continue end
			local toTarget = rec.Target - rec.Pos
			if toTarget.Magnitude < 2.5 then
				rec.Target = rec.Center + Vector3.new(math.random(-16, 16), 6 + math.random(0, 9), math.random(-16, 16))
				toTarget = rec.Target - rec.Pos
			end
			rec.Pos += toTarget.Unit * 7 * dt
			local hover = math.sin(t * 3 + rec.Phase) * 0.35
			local yaw = math.atan2(-toTarget.Z, toTarget.X)
			local rootCF = CFrame.new(rec.Pos + Vector3.new(0, hover, 0)) * CFrame.Angles(0, yaw, 0)
			rec.Root.CFrame = rootCF

			-- крылья машут
			local flap = math.sin(t * 30 + rec.Phase) * 0.9
			for _, p in ipairs(rec.Parts) do
				if p.Side then
					p.Part.CFrame = rootCF * CFrame.new(0, 0.6 * (rec.Bee.Scale or 1), p.Side * 0.3) * CFrame.Angles(p.Side * flap, 0, 0) * p.Offset
				else
					p.Part.CFrame = rootCF * p.Offset
				end
			end
		end
	end
end

function BeeService.Init(c)
	ctx = c
end

function BeeService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local list = bees[player]
		if list then
			for _, rec in ipairs(list) do
				if rec.Model then rec.Model:Destroy() end
			end
			bees[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(flyTick)
end

return BeeService
