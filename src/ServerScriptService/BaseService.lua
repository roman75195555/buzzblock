--!strict
--==============================================================================
-- SeedRush :: BaseService
-- Выдача баз (как в референсе), таблички, беговая дорожка, гантеля (сила),
-- грядки с семенами. Все объекты строятся поверх карты reference_map.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = {}
local ctx

local bases: { Model } = {}            -- модели баз из карты
local owners: { [Model]: Player } = {} -- base -> player
local playerBase: { [Player]: Model } = {}
local treadmillPads: { [Model]: BasePart } = {} -- base -> pad
local plotParts: { [Model]: { BasePart } } = {} -- base -> {soil parts}
local plotViews: { [Model]: { Model? } } = {}   -- base -> {plant models}

-- Вспомогательное --------------------------------------------------------------
local function notify(player: Player, text: string, colorName: string?)
	ctx.Remotes.Notify:FireClient(player, text, colorName or "info")
end

local function getData(player: Player)
	return ctx.Services.DataService.Get(player)
end

local function updateWalkSpeed(player: Player)
	local data = getData(player)
	if not data then return end
	local Config = ctx.Config
	local trailBonus = 0
	for idStr in pairs(data.Trails) do
		local t = Config.Trails[tonumber(idStr)]
		if t and t.Bonus > trailBonus then
			trailBonus = t.Bonus
		end
	end
	local ws = Config.BaseWalkSpeed + data.Speed * Config.SpeedPerPoint + trailBonus
	ws = math.min(ws, Config.MaxWalkSpeed)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = ws
	end
end
BaseService.UpdateWalkSpeed = updateWalkSpeed

-- Постройка объектов базы -------------------------------------------------------
local function buildSign(base: Model, spawn: SpawnLocation)
	local B = ctx.Build
	local signPart = B.Part(base, {
		Size = Vector3.new(8, 3, 0.5),
		CFrame = spawn.CFrame * CFrame.new(0, 4, -8) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(40, 40, 48),
		Name = "PlayerNameSign",
	})
	B.Neon(base, {
		Size = Vector3.new(8.4, 0.4, 0.6),
		CFrame = signPart.CFrame * CFrame.new(0, 1.7, 0),
		Color = Color3.fromRGB(255, 210, 60),
	})
	B.Neon(base, {
		Size = Vector3.new(8.4, 0.4, 0.6),
		CFrame = signPart.CFrame * CFrame.new(0, -1.7, 0),
		Color = Color3.fromRGB(255, 210, 60),
	})
	-- столбики
	B.Part(base, {
		Size = Vector3.new(0.5, 4, 0.5),
		CFrame = signPart.CFrame * CFrame.new(-3.5, -3.5, 0),
		Color = Color3.fromRGB(70, 70, 80),
	})
	B.Part(base, {
		Size = Vector3.new(0.5, 4, 0.5),
		CFrame = signPart.CFrame * CFrame.new(3.5, -3.5, 0),
		Color = Color3.fromRGB(70, 70, 80),
	})
	B.SignText(signPart, "СВОБОДНО", Color3.fromRGB(255, 220, 80), nil, Enum.NormalId.Front)
	return signPart
end

local function setSign(base: Model, text: string)
	local sign = base:FindFirstChild("PlayerNameSign")
	local sg = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = sg and sg:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

local function buildTreadmill(base: Model, center: Vector3)
	local B = ctx.Build
	local pos = center + Vector3.new(-13, 0, 2)
	-- рама
	B.Part(base, { Size = Vector3.new(9, 0.8, 16), CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(45, 45, 55), Name = "TreadmillFrame" })
	-- лента
	local belt = B.Part(base, {
		Size = Vector3.new(7, 0.4, 14),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.SmoothPlastic,
		Name = "TreadmillBelt",
	})
	-- поручни
	for _, sx in ipairs({ -4.2, 4.2 }) do
		B.Part(base, { Size = Vector3.new(0.5, 2.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(sx, 2.2, -6.5)), Color = Color3.fromRGB(60, 60, 70) })
	end
	B.Part(base, { Size = Vector3.new(9, 0.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 3.4, -6.5)), Color = Color3.fromRGB(60, 60, 70) })
	-- панель
	local panel = B.Part(base, { Size = Vector3.new(6, 2, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 4.6, -6.5)) * CFrame.Angles(math.rad(-15), 0, 0), Color = Color3.fromRGB(30, 30, 38) })
	B.SignText(panel, "БЕГ + СКОРОСТЬ", Color3.fromRGB(90, 220, 255))
	-- неоновые стрелки на ленте
	for i = -1, 1 do
		local arrow = B.Wedge(base, {
			Size = Vector3.new(2, 0.2, 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.25, i * 4)) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(140, 230, 255),
			Name = "Arrow",
		})
		arrow.Material = Enum.Material.Neon
	end
	treadmillPads[base] = belt
end

local function buildDumbbellRack(base: Model, center: Vector3)
	local B = ctx.Build
	local pos = center + Vector3.new(13, 0, 2)
	-- помост
	B.Part(base, { Size = Vector3.new(10, 0.8, 10), CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(120, 60, 40), Material = Enum.Material.Wood, Name = "GymFloor" })
	-- большая декоративная гантеля
	local bar = B.Part(base, {
		Size = Vector3.new(0.8, 0.8, 7),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0)),
		Color = Color3.fromRGB(160, 160, 170),
		Shape = Enum.PartType.Cylinder,
		Name = "Bar",
	})
	bar.CFrame = bar.CFrame * CFrame.Angles(math.rad(90), 0, 0)
	for _, sz in ipairs({ -3.2, 3.2 }) do
		local w = B.Part(base, {
			Size = Vector3.new(1.6, 3.4, 3.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.2, sz)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 50, 50),
			Shape = Enum.PartType.Cylinder,
		})
		w.Material = Enum.Material.Metal
	end
	local sign = B.Part(base, { Size = Vector3.new(6, 1.6, 0.4), CFrame = CFrame.new(pos + Vector3.new(0, 5.4, -4.6)), Color = Color3.fromRGB(30, 30, 38) })
	B.SignText(sign, "ГАНТЕЛЯ = СИЛА (клик)", Color3.fromRGB(255, 130, 130))
end

local function buildPlots(base: Model, center: Vector3)
	local B = ctx.Build
	plotParts[base] = {}
	plotViews[base] = {}
	local startX = center.X - 9
	local startZ = center.Z - 22
	for i = 1, ctx.Config.PlotCount do
		local ox = startX + ((i - 1) % 2) * 18
		local oz = startZ + math.floor((i - 1) / 2) * 14
		-- грядка
		local soil = B.Part(base, {
			Size = Vector3.new(8, 1, 8),
			CFrame = CFrame.new(ox, center.Y + 0.5, oz),
			Color = Color3.fromRGB(96, 62, 32),
			Material = Enum.Material.Ground,
			Name = "Plot" .. i,
		})
		-- рамка
		for _, d in ipairs({ Vector3.new(4.4, 0, 0), Vector3.new(-4.4, 0, 0), Vector3.new(0, 0, 4.4), Vector3.new(0, 0, -4.4) }) do
			local horiz = math.abs(d.X) > 0
			B.Part(base, {
				Size = horiz and Vector3.new(0.8, 0.8, 8.8) or Vector3.new(8.8, 0.8, 0.8),
				CFrame = CFrame.new(ox + d.X, center.Y + 0.4, oz + d.Z),
				Color = Color3.fromRGB(140, 95, 50),
				Material = Enum.Material.Wood,
			})
		end
		table.insert(plotParts[base], soil)
		plotViews[base][i] = nil
	end
end

-- Растения ----------------------------------------------------------------------
local function clearPlantView(base: Model, slot: number)
	local v = plotViews[base] and plotViews[base][slot]
	if v then
		v:Destroy()
		plotViews[base][slot] = nil
	end
end

local function updatePlantView(base: Model, slot: number)
	local player = owners[base]
	if not player then return end
	local data = getData(player)
	if not data then return end
	clearPlantView(base, slot)
	local plot = data.Plots[tostring(slot)]
	if not plot then return end

	local B = ctx.Build
	local Config = ctx.Config
	local zone = Config.Zones[plot.Zone]
	if not zone then return end
	local soil = plotParts[base][slot]
	local p = soil.Position
	local growth = math.clamp((os.time() - plot.PlantedAt) / zone.GrowTime, 0, 1)

	local m = Instance.new("Model")
	m.Name = "Plant"
	local h = 1 + growth * 5
	-- стебель
	B.Part(m, {
		Size = Vector3.new(0.6, h, 0.6),
		CFrame = CFrame.new(p + Vector3.new(0, 0.5 + h / 2, 0)),
		Color = Color3.fromRGB(60, 160, 60),
	})
	-- бутон/цветок
	local bloom = B.Part(m, {
		Size = Vector3.new(1.4 + growth * 2, 1.4 + growth * 2, 1.4 + growth * 2),
		CFrame = CFrame.new(p + Vector3.new(0, 1 + h, 0)),
		Color = zone.Color,
		Shape = Enum.PartType.Ball,
		Material = growth >= 1 and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})
	if growth >= 1 then
		B.Sparkles(bloom, zone.Color)
		B.Billboard(bloom, string.format("%s · %d💰/с", zone.Name, zone.Income), Color3.fromRGB(255, 230, 120), 2.5)
	else
		B.Billboard(bloom, string.format("Растёт… %d%%", math.floor(growth * 100)), Color3.new(1, 1, 1), 2.5)
	end
	m.Parent = base
	plotViews[base][slot] = m
end

local function refreshAllPlants()
	for base in pairs(bases) do
		for slot = 1, ctx.Config.PlotCount do
			updatePlantView(base, slot)
		end
	end
end

local function bestSeed(data): number?
	local best: number? = nil
	for idStr, count in pairs(data.Seeds) do
		if count > 0 then
			local id = tonumber(idStr)
			if id and (not best or id > best) then
				best = id
			end
		end
	end
	return best
end

local function setupPlotPrompts()
	for base in pairs(bases) do
		for slot, soil in ipairs(plotParts[base]) do
			local pp = ctx.Build.Prompt(soil, "Посадить", "Грядка " .. slot)
			pp.Triggered:Connect(function(player)
				if owners[base] ~= player then
					notify(player, "Это чужая база!", "error")
					return
				end
				local data = getData(player)
				if not data then return end
				local key = tostring(slot)
				local plot = data.Plots[key]
				if plot then
					-- убрать растение (семя не возвращается)
					data.Plots[key] = nil
					clearPlantView(base, slot)
					ctx.Services.DataService.PushState(player)
					notify(player, "Растение убрано", "info")
					return
				end
				local seed = bestSeed(data)
				if not seed then
					notify(player, "Нет семян! Укради их у боссов на дорожке.", "error")
					return
				end
				data.Seeds[tostring(seed)] -= 1
				data.Plots[key] = { Zone = seed, PlantedAt = os.time() }
				updatePlantView(base, slot)
				ctx.Services.DataService.PushState(player)
				local zone = ctx.Config.Zones[seed]
				notify(player, "Посажено: " .. zone.Name .. " (доход " .. zone.Income .. "💰/с)", "success")
			end)
		end
	end
end

-- Выдача баз ---------------------------------------------------------------------
local function getFreeBase(): Model?
	for _, base in ipairs(bases) do
		if not owners[base] then
			return base
		end
	end
	return nil
end

local function giveDumbbell(player: Player)
	local toolName = "Dumbbell"
	local function give(container: Instance)
		if not container:FindFirstChild(toolName) then
			local template = game:GetService("StarterPack"):FindFirstChild(toolName)
			if template then
				template:Clone().Parent = container
			end
		end
	end
	give(player:WaitForChild("Backpack"))
	local char = player.Character
	if char then give(char) end
end

local function onPlayerAdded(player: Player)
	local base = getFreeBase()
	if not base then
		player:Kick("Все базы заняты!")
		return
	end
	owners[base] = player
	playerBase[player] = base
	print(player.Name .. " получил " .. base.Name)
	setSign(base, player.DisplayName)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		local spawn = base:FindFirstChild("SpawnLocation", true)
		if spawn and player.Character then
			player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
		end
		updateWalkSpeed(player)
	end)

	-- восстановить растения этого игрока на его базе
	task.defer(function()
		local t0 = os.clock()
		while not getData(player) and os.clock() - t0 < 10 do
			task.wait(0.2)
		end
		for slot = 1, ctx.Config.PlotCount do
			updatePlantView(base, slot)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local base = playerBase[player]
	if base then
		owners[base] = nil
		playerBase[player] = nil
		setSign(base, "СВОБОДНО")
		for slot = 1, ctx.Config.PlotCount do
			clearPlantView(base, slot)
		end
	end
end

-- Гантеля: +сила за подъём -------------------------------------------------------
local lastRep: { [Player]: number } = {}

local function hookDumbbell(player: Player, tool: Tool)
	if tool.Name ~= "Dumbbell" then return end
	tool.Activated:Connect(function()
		local data = getData(player)
		if not data then return end
		local now = os.clock()
		if now - (lastRep[player] or 0) < ctx.Config.RepCooldown then return end
		lastRep[player] = now
		local gain = ctx.Config.StrengthPerRep(data.TrainerTier)
		data.Strength += gain
		ctx.Services.DataService.PushState(player)
	end)
end

local function watchTools(player: Player)
	local function scan(container: Instance)
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("Tool") then
				hookDumbbell(player, c)
			end
		end
		container.ChildAdded:Connect(function(c)
			if c:IsA("Tool") then
				hookDumbbell(player, c)
			end
		end)
	end
	scan(player:WaitForChild("Backpack"))
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		scan(char)
	end)
end

-- Жизненный цикл ------------------------------------------------------------------
function BaseService.Init(c)
	ctx = c
end

function BaseService.Start()
	-- найти базы в карте
	local map = workspace:WaitForChild("Map")
	local baseFolder = map:WaitForChild("base")
	local names = { "база 1", "база 2", "база 3" }
	for i, n in ipairs(names) do
		local b = baseFolder:WaitForChild(n)
		table.insert(bases, b)
		local spawn = b:FindFirstChild("SpawnLocation", true)
		if spawn then
			buildSign(b, spawn)
		end
		local center = ctx.Config.Bases[i].Center
		buildTreadmill(b, center)
		buildDumbbellRack(b, center)
		buildPlots(b, center)
	end
	setupPlotPrompts()

	-- гантеля остаётся в StarterPack: выдаётся автоматически при каждом возрождении

	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(player)
		task.defer(function()
			task.wait(1.5)
			giveDumbbell(player)
			watchTools(player)
			updateWalkSpeed(player)
		end)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			onPlayerAdded(p)
			task.wait(1.5)
			giveDumbbell(p)
			watchTools(p)
			updateWalkSpeed(p)
		end)
	end

	-- тик: беговая дорожка + обновление растений
	local plantTimer = 0
	RunService.Heartbeat:Connect(function(dt)
		for player, base in pairs(playerBase) do
			local pad = treadmillPads[base]
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if pad and root then
				local d = root.Position - pad.Position
				if math.abs(d.X) < 5 and math.abs(d.Z) < 8 and math.abs(d.Y) < 5 then
					local data = getData(player)
					if data then
						data.Speed += ctx.Config.SpeedRate(data.TreadmillTier) * dt
						if math.floor(data.Speed) ~= math.floor(data.Speed - ctx.Config.SpeedRate(data.TreadmillTier) * dt) then
							updateWalkSpeed(player)
						end
					end
				end
			end
		end
		plantTimer += dt
		if plantTimer >= 5 then
			plantTimer = 0
			refreshAllPlants()
			for _, p in ipairs(Players:GetPlayers()) do
				ctx.Services.DataService.PushState(p)
			end
		end
	end)
end

return BaseService
