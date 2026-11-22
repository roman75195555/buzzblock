--!strict
--==============================================================================
-- SeedRush :: BaseService
-- Выдача баз, таблички (подвешены, компактные), исходные неоновые площадки
-- для яиц, беговая дорожка и тренажёр ВНЕ базы, физический магазин.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = {}
local ctx

local bases: { Model } = {}
local owners: { [Model]: Player } = {}
local playerBase: { [Player]: Model } = {}
local treadmillPads: { [Model]: BasePart } = {}
local eggPads: { [Model]: { BasePart } } = {}     -- исходные неоновые площадки
local padPrompts: { [Model]: { ProximityPrompt } } = {}
local padViews: { [Model]: { Model? } } = {}

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

-- Компактная подвесная табличка ---------------------------------------------------
local function buildSign(base: Model, spawn: SpawnLocation)
	local B = ctx.Build
	local signPos = spawn.CFrame * CFrame.new(0, 9, -2) * CFrame.Angles(0, math.pi, 0)
	local signPart = B.Part(base, {
		Size = Vector3.new(6, 1.8, 0.4),
		CFrame = signPos,
		Color = Color3.fromRGB(40, 40, 48),
		Name = "PlayerNameSign",
		CanCollide = false,
	})
	-- неоновая рамка
	B.Neon(base, {
		Size = Vector3.new(6.3, 0.25, 0.45),
		CFrame = signPos * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(255, 210, 60),
		CanCollide = false,
	})
	B.Neon(base, {
		Size = Vector3.new(6.3, 0.25, 0.45),
		CFrame = signPos * CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(255, 210, 60),
		CanCollide = false,
	})
	-- подвесы вверх (к «потолку» визуально)
	for _, sx in ipairs({ -2.5, 2.5 }) do
		B.Part(base, {
			Size = Vector3.new(0.25, 5, 0.25),
			CFrame = signPos * CFrame.new(sx, 3.4, 0),
			Color = Color3.fromRGB(70, 70, 80),
			CanCollide = false,
		})
	end
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

-- Беговая дорожка — ВНЕ базы, перед ней ------------------------------------------
local function buildTreadmill(base: Model, center: Vector3)
	local B = ctx.Build
	local pos = Vector3.new(center.X - 14, 4.8, center.Z + 52)
	B.Part(base, { Size = Vector3.new(9, 0.8, 16), CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(45, 45, 55), Name = "TreadmillFrame" })
	local belt = B.Part(base, {
		Size = Vector3.new(7, 0.4, 14),
		CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)),
		Color = Color3.fromRGB(90, 200, 255),
		Material = Enum.Material.SmoothPlastic,
		Name = "TreadmillBelt",
	})
	for _, sx in ipairs({ -4.2, 4.2 }) do
		B.Part(base, { Size = Vector3.new(0.5, 2.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(sx, 2.2, -6.5)), Color = Color3.fromRGB(60, 60, 70) })
	end
	B.Part(base, { Size = Vector3.new(9, 0.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 3.4, -6.5)), Color = Color3.fromRGB(60, 60, 70) })
	-- компактная панель
	local panel = B.Part(base, { Size = Vector3.new(5, 1.4, 0.3), CFrame = CFrame.new(pos + Vector3.new(0, 4.4, -6.5)) * CFrame.Angles(math.rad(-15), 0, 0), Color = Color3.fromRGB(30, 30, 38), CanCollide = false })
	B.SignText(panel, "🏃 +СКОРОСТЬ", Color3.fromRGB(90, 220, 255))
	B.Billboard(belt, "Встань на ленту: качается ⚡скорость", Color3.fromRGB(140, 230, 255), 5)
	for i = -1, 1 do
		local arrow = B.Wedge(base, {
			Size = Vector3.new(2, 0.2, 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 1.25, i * 4)) * CFrame.Angles(0, math.pi, 0),
			Color = Color3.fromRGB(140, 230, 255),
			Name = "Arrow",
			CanCollide = false,
		})
		arrow.Material = Enum.Material.Neon
	end
	treadmillPads[base] = belt
end

-- Тренажёр силы — ВНЕ базы, перед ней ---------------------------------------------
local function buildGym(base: Model, center: Vector3)
	local B = ctx.Build
	local pos = Vector3.new(center.X + 14, 4.8, center.Z + 52)
	B.Part(base, { Size = Vector3.new(10, 0.8, 10), CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)), Color = Color3.fromRGB(120, 60, 40), Material = Enum.Material.Wood, Name = "GymFloor" })
	local bar = B.Part(base, {
		Size = Vector3.new(0.8, 0.8, 7),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
		Color = Color3.fromRGB(160, 160, 170),
		Shape = Enum.PartType.Cylinder,
		Name = "Bar",
	})
	for _, sz in ipairs({ -3.2, 3.2 }) do
		local w = B.Part(base, {
			Size = Vector3.new(1.6, 3.4, 3.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 2.2, sz)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(200, 50, 50),
			Shape = Enum.PartType.Cylinder,
		})
		w.Material = Enum.Material.Metal
	end
	B.Billboard(bar, "🏋️ Возьми гантелю и кликай: +💪 сила", Color3.fromRGB(255, 150, 150), 4)
end

-- Исходные неоновые площадки базы = места для яиц -----------------------------------
local function findEggPads(base: Model): { BasePart }
	local pads: { BasePart } = {}
	for _, d in ipairs(base:GetDescendants()) do
		if d:IsA("UnionOperation") then
			local s = d.Size
			if math.abs(s.X - 9) < 1.5 and math.abs(s.Z - 9.6) < 1.5 and d.Position.Y < 10 then
				table.insert(pads, d)
			end
		end
	end
	-- стабильный порядок: по Z (от входа), затем по X
	table.sort(pads, function(a, b)
		if math.abs(a.Position.Z - b.Position.Z) > 1 then
			return a.Position.Z > b.Position.Z
		end
		return a.Position.X < b.Position.X
	end)
	return pads
end

-- Яйцо / существо на площадке ----------------------------------------------------------
local function clearPadView(base: Model, slot: number)
	local v = padViews[base] and padViews[base][slot]
	if v then
		v:Destroy()
		padViews[base][slot] = nil
	end
end

local function updatePadView(base: Model, slot: number)
	local player = owners[base]
	if not player then return end
	local data = getData(player)
	if not data then return end
	clearPadView(base, slot)
	local plot = data.Plots[tostring(slot)]
	if not plot then return end

	local B = ctx.Build
	local Config = ctx.Config
	local zone = Config.Zones[plot.Zone]
	if not zone then return end
	local pad = eggPads[base][slot]
	local p = pad.Position + Vector3.new(0, 1.3, 0) -- поверх красного поддона
	local growth = math.clamp((os.time() - plot.PlantedAt) / zone.GrowTime, 0, 1)

	local m = Instance.new("Model")
	m.Name = "PadEgg"
	if growth < 1 then
		-- яйцо инкубируется
		local size = 1 + growth * 0.8
		local egg = B.Part(m, {
			Size = Vector3.new(size, size * 1.25, size),
			CFrame = CFrame.new(p + Vector3.new(0, size * 0.7, 0)),
			Color = zone.Color,
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		B.Billboard(egg, string.format("🥚 %d%%", math.floor(growth * 100)), Color3.new(1, 1, 1), 2.2)
	else
		-- вылупилось существо, приносит доход
		local body = B.Part(m, {
			Size = Vector3.new(2.2, 2, 2.2),
			CFrame = CFrame.new(p + Vector3.new(0, 1.6, 0)),
			Color = zone.Color,
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		-- глаза
		for _, ex in ipairs({ -0.5, 0.5 }) do
			B.Neon(m, {
				Size = Vector3.new(0.35, 0.35, 0.2),
				CFrame = body.CFrame * CFrame.new(ex, 0.3, -1.05),
				Color = Color3.new(1, 1, 1),
				CanCollide = false,
			})
		end
		-- ножки
		for _, ex in ipairs({ -0.6, 0.6 }) do
			B.Part(m, {
				Size = Vector3.new(0.5, 0.8, 0.5),
				CFrame = body.CFrame * CFrame.new(ex, -1.2, 0),
				Color = zone.Color:Lerp(Color3.new(0, 0, 0), 0.2),
				CanCollide = false,
			})
		end
		B.Sparkles(body, zone.Color)
		B.Billboard(body, string.format("%s · %d💰/с", zone.Name, zone.Income), Color3.fromRGB(255, 230, 120), 2.4)
	end
	m.Parent = base
	padViews[base][slot] = m
end

local function refreshAllPads()
	for base in pairs(bases) do
		if padViews[base] then
			for slot = 1, #eggPads[base] do
				updatePadView(base, slot)
			end
		end
	end
end

local function refreshPrompts()
	for base, prompts in pairs(padPrompts) do
		local player = owners[base]
		local data = player and getData(player)
		for slot, pp in ipairs(prompts) do
			local plot = data and data.Plots[tostring(slot)]
			if plot then
				local zone = ctx.Config.Zones[plot.Zone]
				local grown = zone and (os.time() - plot.PlantedAt >= zone.GrowTime)
				pp.ActionText = if grown then "Убрать" else "Инкубация…"
				pp.Enabled = grown == true
			else
				pp.ActionText = "Поставить яйцо"
				pp.Enabled = true
			end
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

local function setupPadPrompts()
	for base in pairs(bases) do
		padPrompts[base] = {}
		for slot, pad in ipairs(eggPads[base]) do
			local pp = ctx.Build.Prompt(pad, "Поставить яйцо", "Гнездо " .. slot)
			table.insert(padPrompts[base], pp)
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
					local zone = ctx.Config.Zones[plot.Zone]
					if zone and os.time() - plot.PlantedAt >= zone.GrowTime then
						data.Plots[key] = nil
						clearPadView(base, slot)
						ctx.Services.DataService.PushState(player)
						notify(player, "Место освобождено", "info")
					end
					return
				end
				local seed = bestSeed(data)
				if not seed then
					notify(player, "Нет яиц! Укради их у боссов на дорожке.", "error")
					return
				end
				data.Seeds[tostring(seed)] -= 1
				data.Plots[key] = { Zone = seed, PlantedAt = os.time() }
				updatePadView(base, slot)
				ctx.Services.DataService.PushState(player)
				local zone = ctx.Config.Zones[seed]
				notify(player, "🥚 Яйцо «" .. zone.Name .. "» установлено! Скоро вылупится.", "success")
			end)
		end
	end
	refreshPrompts()
end

-- Физический магазин ---------------------------------------------------------------
local function buildShop()
	local B = ctx.Build
	local m = Instance.new("Model")
	m.Name = "Shop"
	local pos = Vector3.new(-45, 4.8, 60)

	-- пол и стены
	B.Part(m, { Size = Vector3.new(22, 1, 18), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(150, 95, 50), Material = Enum.Material.Wood })
	B.Part(m, { Size = Vector3.new(22, 10, 1), CFrame = CFrame.new(pos + Vector3.new(0, 5.5, 8.5)), Color = Color3.fromRGB(200, 140, 70), Material = Enum.Material.Wood })
	for _, sx in ipairs({ -10.5, 10.5 }) do
		B.Part(m, { Size = Vector3.new(1, 10, 18), CFrame = CFrame.new(pos + Vector3.new(sx, 5.5, 0)), Color = Color3.fromRGB(200, 140, 70), Material = Enum.Material.Wood })
	end
	-- крыша
	B.Wedge(m, { Size = Vector3.new(24, 4, 20), CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0)), Color = Color3.fromRGB(180, 60, 50), Material = Enum.Material.RoofShingles })
	-- прилавок
	B.Part(m, { Size = Vector3.new(14, 3, 2.5), CFrame = CFrame.new(pos + Vector3.new(0, 2, 4)), Color = Color3.fromRGB(120, 70, 35), Material = Enum.Material.Wood, Name = "Counter" })
	B.Neon(m, { Size = Vector3.new(14, 0.3, 2.7), CFrame = CFrame.new(pos + Vector3.new(0, 3.6, 4)), Color = Color3.fromRGB(255, 200, 80), CanCollide = false })
	-- вывеска
	local signBoard = B.Part(m, { Size = Vector3.new(10, 2.4, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 9, 8.2)), Color = Color3.fromRGB(40, 30, 20), CanCollide = false })
	B.SignText(signBoard, "🛒 МАГАЗИН", Color3.fromRGB(255, 200, 80))
	-- продавец (блочный NPC)
	local sellerPos = pos + Vector3.new(0, 1, 6)
	local body = B.Part(m, { Size = Vector3.new(2.4, 3, 1.6), CFrame = CFrame.new(sellerPos + Vector3.new(0, 2.6, 0)), Color = Color3.fromRGB(90, 140, 220), Name = "Seller" })
	B.Part(m, { Size = Vector3.new(1.8, 1.6, 1.6), CFrame = body.CFrame * CFrame.new(0, 2.4, 0), Color = Color3.fromRGB(255, 210, 170) })
	for _, ex in ipairs({ -0.45, 0.45 }) do
		B.Neon(m, { Size = Vector3.new(0.3, 0.3, 0.15), CFrame = body.CFrame * CFrame.new(ex, 2.6, -0.85), Color = Color3.fromRGB(30, 30, 30), CanCollide = false })
	end
	-- колпак торговца
	B.Wedge(m, { Size = Vector3.new(2, 1, 2), CFrame = body.CFrame * CFrame.new(0, 3.6, 0), Color = Color3.fromRGB(200, 60, 50) })
	B.Billboard(body, "Торговец", Color3.fromRGB(255, 220, 120), 4)

	-- витрина с предметами
	for i, dx in ipairs({ -5, 0, 5 }) do
		local item = B.Neon(m, {
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(pos + Vector3.new(dx, 4.4, 4)),
			Color = Color3.fromRGB(120 + i * 40, 200, 255 - i * 40),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		B.Sparkles(item)
	end

	-- промпт открытия магазина
	local pp = B.Prompt(body, "Торговать", "Магазин")
	pp.Triggered:Connect(function(player)
		ctx.Remotes.OpenShop:FireClient(player)
	end)

	m.Parent = workspace
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

	task.defer(function()
		local t0 = os.clock()
		while not getData(player) and os.clock() - t0 < 10 do
			task.wait(0.2)
		end
		for slot = 1, #eggPads[base] do
			updatePadView(base, slot)
		end
		refreshPrompts()
	end)
end

local function onPlayerRemoving(player: Player)
	local base = playerBase[player]
	if base then
		owners[base] = nil
		playerBase[player] = nil
		setSign(base, "СВОБОДНО")
		for slot = 1, #eggPads[base] do
			clearPadView(base, slot)
		end
		refreshPrompts()
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
		buildGym(b, center)
		eggPads[b] = findEggPads(b)
		padViews[b] = {}
		print("[BaseService] " .. n .. ": площадок для яиц = " .. #eggPads[b])
	end
	setupPadPrompts()
	buildShop()

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

	-- тик: беговая дорожка + обновление яиц
	local viewTimer = 0
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
						local rate = ctx.Config.SpeedRate(data.TreadmillTier)
						local before = math.floor(data.Speed)
						data.Speed += rate * dt
						if math.floor(data.Speed) ~= before then
							updateWalkSpeed(player)
							ctx.Services.DataService.PushState(player)
						end
					end
				end
			end
		end
		viewTimer += dt
		if viewTimer >= 5 then
			viewTimer = 0
			refreshAllPads()
			refreshPrompts()
			for _, p in ipairs(Players:GetPlayers()) do
				ctx.Services.DataService.PushState(p)
			end
		end
	end)
end

return BaseService
