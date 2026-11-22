--!strict
--==============================================================================
-- LunarBase :: BaseService
-- 6 участков, выдача баз, конвейеры с движущимися камнями, лазер-переработчик,
-- терминал сбора денег, кнопки покупок на полу.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = {}
local ctx

type Conveyor = {
	Model: Model,
	Belt: BasePart,
	RollerA: BasePart,
	RollerB: BasePart,
	Beam: BasePart,
	LaserZ: number,
	SpawnZ: number,
	X: number,
	Stones: { BasePart },
	SpawnT: number,
}

type BaseState = {
	Index: number,
	Center: Vector3,
	Folder: Folder,
	Owner: Player?,
	Conveyors: { Conveyor },
	TerminalLabel: TextLabel?,
	CollectPad: BasePart?,
	ButtonPad: BasePart?,
	ButtonLabel: BillboardGui?,
	LaserMult: number,
	SpeedMult: number,
	Structures: { Instance },
}

local bases: { BaseState } = {}
local playerBase: { [Player]: BaseState } = {}

local function notify(player: Player, text: string, colorName: string?)
	ctx.Remotes.Notify:FireClient(player, text, colorName or "info")
end

-- Строительство участка ---------------------------------------------------------
local function buildPlot(index: number, center: Vector3): BaseState
	local B = ctx.Build
	local folder = Instance.new("Folder")
	folder.Name = "Base_" .. index
	folder.Parent = workspace

	local S = ctx.Config.PlotSize
	-- площадка
	B.Part(folder, {
		Size = Vector3.new(S, 1, S),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(96, 98, 108),
		Material = Enum.Material.Concrete,
		Name = "Pad",
	})
	-- неоновая рамка территории
	local frameC = Color3.fromRGB(90, 160, 255)
	for _, d in ipairs({
		{ Vector3.new(0, 0, S / 2), Vector3.new(S, 0.4, 0.6) },
		{ Vector3.new(0, 0, -S / 2), Vector3.new(S, 0.4, 0.6) },
		{ Vector3.new(S / 2, 0, 0), Vector3.new(0.6, 0.4, S) },
		{ Vector3.new(-S / 2, 0, 0), Vector3.new(0.6, 0.4, S) },
	}) do
		B.Neon(folder, {
			Size = d[2],
			CFrame = CFrame.new(center + d[1] + Vector3.new(0, 1.2, 0)),
			Color = frameC,
			CanCollide = false,
			Name = "TerritoryFrame",
		})
	end
	-- спавн
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 1.5, 46))
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Name = "Spawn"
	spawn.Parent = folder

	-- табличка с именем владельца
	local signPost = B.Part(folder, {
		Size = Vector3.new(0.8, 9, 0.8),
		CFrame = CFrame.new(center + Vector3.new(-10, 5.5, 50)),
		Color = Color3.fromRGB(70, 72, 80),
		Name = "SignPost",
	})
	local signBoard = B.Part(folder, {
		Size = Vector3.new(12, 4, 0.6),
		CFrame = CFrame.new(center + Vector3.new(-10, 11, 50)),
		Color = Color3.fromRGB(35, 38, 48),
		Name = "OwnerSign",
	})
	B.Neon(folder, {
		Size = Vector3.new(12.4, 0.4, 0.7),
		CFrame = signBoard.CFrame * CFrame.new(0, 2.2, 0),
		Color = Color3.fromRGB(255, 210, 80),
		CanCollide = false,
	})
	B.SignText(signBoard, "СВОБОДНО", Color3.fromRGB(255, 220, 100))
	signPost.Name = "SignPost"

	local st: BaseState = {
		Index = index,
		Center = center,
		Folder = folder,
		Owner = nil,
		Conveyors = {},
		TerminalLabel = nil,
		CollectPad = nil,
		ButtonPad = nil,
		ButtonLabel = nil,
		LaserMult = 1,
		SpeedMult = 1,
		Structures = {},
	}
	return st
end

local function setOwnerSign(st: BaseState, text: string)
	local sign = st.Folder:FindFirstChild("OwnerSign")
	local sg = sign and sign:FindFirstChildOfClass("SurfaceGui")
	local label = sg and sg:FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = text
	end
end

-- Конвейер ----------------------------------------------------------------------
local function buildConveyor(st: BaseState, convIndex: number)
	local B = ctx.Build
	local x = ctx.Config.ConveyorX[convIndex]
	local c = st.Center
	local L = ctx.Config.ConveyorLength
	local z0 = c.Z - L / 2 + 5
	local zMid = c.Z

	local m = Instance.new("Model")
	m.Name = "Conveyor" .. convIndex

	-- лента
	local belt = B.Part(m, {
		Size = Vector3.new(3, 0.5, L),
		CFrame = CFrame.new(c.X + x, 2, zMid),
		Color = Color3.fromRGB(45, 48, 55),
		Material = Enum.Material.Metal,
		Name = "Belt",
	})
	-- боковые рельсы
	for _, sx in ipairs({ -1.9, 1.9 }) do
		B.Part(m, {
			Size = Vector3.new(0.5, 1.2, L),
			CFrame = CFrame.new(c.X + x + sx, 2.4, zMid),
			Color = Color3.fromRGB(150, 155, 165),
			Material = Enum.Material.Metal,
		})
	end
	-- ножки
	for i = 0, 4 do
		local lz = z0 + i * (L / 4)
		for _, sx in ipairs({ -1.6, 1.6 }) do
			B.Part(m, {
				Size = Vector3.new(0.6, 2, 0.6),
				CFrame = CFrame.new(c.X + x + sx, 1, lz),
				Color = Color3.fromRGB(110, 115, 125),
				Material = Enum.Material.Metal,
			})
		end
	end
	-- ролики на концах
	local rollerA = B.Part(m, {
		Size = Vector3.new(0.9, 3.2, 3.2),
		CFrame = CFrame.new(c.X + x, 2, z0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 185, 195),
		Shape = Enum.PartType.Cylinder,
		Name = "RollerA",
	})
	rollerA.Material = Enum.Material.Metal
	local rollerB = B.Part(m, {
		Size = Vector3.new(0.9, 3.2, 3.2),
		CFrame = CFrame.new(c.X + x, 2, z0 + L) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 185, 195),
		Shape = Enum.PartType.Cylinder,
		Name = "RollerB",
	})
	rollerB.Material = Enum.Material.Metal

	-- лазерная установка в конце
	local laserZ = z0 + L - 4
	for _, sx in ipairs({ -2.4, 2.4 }) do
		B.Part(m, {
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(c.X + x + sx, 4.5, laserZ),
			Color = Color3.fromRGB(60, 64, 75),
			Material = Enum.Material.Metal,
		})
	end
	B.Part(m, {
		Size = Vector3.new(5.6, 1.4, 2),
		CFrame = CFrame.new(c.X + x, 8.4, laserZ),
		Color = Color3.fromRGB(60, 64, 75),
		Material = Enum.Material.Metal,
		Name = "LaserHead",
	})
	local emitter = B.Neon(m, {
		Size = Vector3.new(1, 0.8, 1),
		CFrame = CFrame.new(c.X + x, 7.5, laserZ),
		Color = Color3.fromRGB(255, 70, 70),
		Name = "Emitter",
	})
	local beam = B.Neon(m, {
		Size = Vector3.new(0.35, 5, 0.35),
		CFrame = CFrame.new(c.X + x, 5, laserZ),
		Color = Color3.fromRGB(255, 60, 60),
		Transparency = 0.35,
		CanCollide = false,
		Name = "Beam",
	})
	B.Light(emitter, Color3.fromRGB(255, 80, 80), 12, 1.5)
	B.Sparkles(emitter, Color3.fromRGB(255, 120, 120))

	m.Parent = st.Folder
	table.insert(st.Structures, m)

	local conv: Conveyor = {
		Model = m,
		Belt = belt,
		RollerA = rollerA,
		RollerB = rollerB,
		Beam = beam,
		LaserZ = laserZ,
		SpawnZ = z0 + 2,
		X = c.X + x,
		Stones = {},
		SpawnT = 0,
	}
	table.insert(st.Conveyors, conv)
end

-- Камень на ленте -------------------------------------------------------------------
local function spawnStone(st: BaseState, conv: Conveyor)
	if #conv.Stones >= 18 then return end
	local B = ctx.Build
	local s = rng01() * 0.7 + 0.9
	local stone = B.Part(conv.Model, {
		Size = Vector3.new(s, s * 0.8, s),
		CFrame = CFrame.new(conv.X + (rng01() - 0.5), 3, conv.SpawnZ) * CFrame.Angles(rng01() * 3, rng01() * 3, 0),
		Color = Color3.fromRGB(105 + math.floor(rng01() * 25), 105 + math.floor(rng01() * 25), 112),
		Material = Enum.Material.Slate,
		Name = "Stone",
		CanCollide = false,
	})
	table.insert(conv.Stones, stone)
end

local rng = Random.new()
function rng01(): number
	return rng:NextNumber()
end

-- Терминал ---------------------------------------------------------------------------
local function buildTerminal(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Terminal"

	-- консоль
	B.Part(m, {
		Size = Vector3.new(4, 3, 2),
		CFrame = CFrame.new(c.X + 34, 2.5, c.Z + 10),
		Color = Color3.fromRGB(50, 54, 66),
		Material = Enum.Material.Metal,
	})
	-- экран
	local screen = B.Part(m, {
		Size = Vector3.new(3.4, 2, 0.3),
		CFrame = CFrame.new(c.X + 34, 5, c.Z + 10) * CFrame.Angles(math.rad(-15), 0, 0),
		Color = Color3.fromRGB(20, 26, 34),
		Name = "Screen",
	})
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "💰 0"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(120, 255, 160)
	label.Parent = sg
	sg.Parent = screen
	st.TerminalLabel = label
	-- ножка-пьедестал
	B.Part(m, {
		Size = Vector3.new(2, 1, 2),
		CFrame = CFrame.new(c.X + 34, 1, c.Z + 10),
		Color = Color3.fromRGB(70, 74, 86),
		Material = Enum.Material.Metal,
	})
	-- площадка сбора
	local pad = B.Neon(m, {
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(c.X + 34, 1.2, c.Z + 18),
		Color = Color3.fromRGB(90, 255, 140),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "CollectPad",
	})
	pad.CFrame = pad.CFrame * CFrame.Angles(0, 0, math.rad(90))
	B.Billboard(pad, "ЗАБРАТЬ КРЕДИТЫ", Color3.fromRGB(120, 255, 160), 3)
	st.CollectPad = pad

	m.Parent = st.Folder
	table.insert(st.Structures, m)
end

local function updateTerminalLabel(st: BaseState)
	local owner = st.Owner
	if not owner or not st.TerminalLabel then return end
	local data = ctx.Services.DataService.Get(owner)
	if data then
		st.TerminalLabel.Text = "💰 " .. tostring(math.floor(data.Terminal))
	end
end

-- Кнопка покупки ----------------------------------------------------------------------
local function nextUpgrade(st: BaseState)
	local owner = st.Owner
	if not owner then return nil end
	local data = ctx.Services.DataService.Get(owner)
	if not data then return nil end
	for _, u in ipairs(ctx.Config.Upgrades) do
		if not data.Purchases[u.Id] then
			return u
		end
	end
	return nil
end

local function refreshButton(st: BaseState)
	local B = ctx.Build
	-- удалить старую
	if st.ButtonPad then
		st.ButtonPad:Destroy()
		st.ButtonPad = nil
		st.ButtonLabel = nil
	end
	local u = nextUpgrade(st)
	if not u then return end

	local c = st.Center
	local pad = B.Neon(st.Folder, {
		Size = Vector3.new(7, 0.6, 7),
		CFrame = CFrame.new(c.X - 34, 1.3, c.Z + 30),
		Color = Color3.fromRGB(255, 200, 60),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "BuyButton",
	})
	pad.CFrame = pad.CFrame * CFrame.Angles(0, 0, math.rad(90))
	local bb = B.Billboard(pad, string.format("%s\n%d 💰", u.Name, u.Cost), Color3.fromRGB(255, 220, 100), 3)
	st.ButtonPad = pad
	st.ButtonLabel = bb

	local debounce = false
	pad.Touched:Connect(function(hit)
		if debounce then return end
		local owner = st.Owner
		if not owner then return end
		local char = owner.Character
		if not char or not hit:IsDescendantOf(char) then return end
		debounce = true
		task.delay(0.5, function()
			debounce = false
		end)
		BaseService.TryBuy(st)
	end)
end

function BaseService.TryBuy(st: BaseState)
	local owner = st.Owner
	if not owner then return end
	local data = ctx.Services.DataService.Get(owner)
	if not data then return end
	local u = nextUpgrade(st)
	if not u then return end
	if not ctx.Services.DataService.TrySpend(owner, u.Cost) then
		notify(owner, "Не хватает кредитов! Нужно " .. u.Cost .. "💰", "error")
		return
	end
	data.Purchases[u.Id] = true
	BaseService.ApplyUpgrade(st, u)
	refreshButton(st)
	ctx.Services.DataService.PushState(owner)
	notify(owner, "✅ " .. u.Name .. " — построено!", "success")
end

-- Применение улучшения -----------------------------------------------------------------
function BaseService.ApplyUpgrade(st: BaseState, u: any)
	if u.Kind == "conveyor" then
		buildConveyor(st, #st.Conveyors + 1)
	elseif u.Kind == "laser" then
		st.LaserMult = u.Mult
		-- визуал: мощнее луч на всех линиях
		for _, conv in ipairs(st.Conveyors) do
			conv.Beam.Size = Vector3.new(0.35 + st.LaserMult * 0.15, 5, 0.35 + st.LaserMult * 0.15)
			conv.Beam.Color = Color3.fromRGB(255, math.max(20, 90 - st.LaserMult * 15), 60)
		end
	elseif u.Kind == "speed" then
		st.SpeedMult = u.Mult
	elseif u.Kind == "building" then
		local B = ctx.Build
		local c = st.Center
		local m = Instance.new("Model")
		m.Name = u.Id
		if u.Id == "habitat" then
			-- купол
			local dome = B.Part(m, {
				Size = Vector3.new(18, 18, 18),
				CFrame = CFrame.new(c.X - 30, 4, c.Z - 25),
				Color = Color3.fromRGB(200, 205, 215),
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Metal,
			})
			B.Part(m, { Size = Vector3.new(4, 5, 1), CFrame = dome.CFrame * CFrame.new(0, -3, 8.5), Color = Color3.fromRGB(70, 74, 86) })
			B.Neon(m, { Size = Vector3.new(2.5, 2.5, 0.5), CFrame = dome.CFrame * CFrame.new(5, 1, 7.5), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
			B.Neon(m, { Size = Vector3.new(2.5, 2.5, 0.5), CFrame = dome.CFrame * CFrame.new(-5, 1, 7.5), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
		elseif u.Id == "lab" then
			-- лаборатория: башня + антенна
			B.Part(m, { Size = Vector3.new(10, 16, 10), CFrame = CFrame.new(c.X + 28, 9, c.Z - 28), Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.Metal })
			B.Neon(m, { Size = Vector3.new(10.4, 1, 10.4), CFrame = CFrame.new(c.X + 28, 17.5, c.Z - 28), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
			local dish = B.Part(m, {
				Size = Vector3.new(6, 0.8, 6),
				CFrame = CFrame.new(c.X + 28, 20, c.Z - 28) * CFrame.Angles(math.rad(30), 0, 0),
				Color = Color3.fromRGB(220, 224, 232),
				Shape = Enum.PartType.Cylinder,
			})
			dish.CFrame = dish.CFrame * CFrame.Angles(0, 0, math.rad(90))
			B.Sparkles(dish, Color3.fromRGB(140, 220, 255))
		end
		m.Parent = st.Folder
		table.insert(st.Structures, m)
	end
end

-- Пересчёт множителей из купленных ------------------------------------------------------
local function recomputeMultipliers(st: BaseState, data: any)
	st.LaserMult = 1
	st.SpeedMult = 1
	for _, u in ipairs(ctx.Config.Upgrades) do
		if data.Purchases[u.Id] then
			if u.Kind == "laser" then
				st.LaserMult = u.Mult
			elseif u.Kind == "speed" then
				st.SpeedMult = u.Mult
			end
		end
	end
end

-- Построить всё производство владельца ---------------------------------------------------
local function buildBaseFor(st: BaseState, player: Player)
	local data = ctx.Services.DataService.Get(player)
	if not data then return end
	recomputeMultipliers(st, data)
	-- стартовый конвейер всегда
	buildConveyor(st, 1)
	buildTerminal(st)
	-- восстановить купленное
	for _, u in ipairs(ctx.Config.Upgrades) do
		if data.Purchases[u.Id] and u.Kind ~= "laser" and u.Kind ~= "speed" then
			BaseService.ApplyUpgrade(st, u)
		end
	end
	-- применить визуал лазера
	if st.LaserMult > 1 then
		for _, conv in ipairs(st.Conveyors) do
			conv.Beam.Size = Vector3.new(0.35 + st.LaserMult * 0.15, 5, 0.35 + st.LaserMult * 0.15)
		end
	end
	updateTerminalLabel(st)
	refreshButton(st)
end

local function clearBase(st: BaseState)
	for _, s in ipairs(st.Structures) do
		s:Destroy()
	end
	st.Structures = {}
	st.Conveyors = {}
	st.TerminalLabel = nil
	st.CollectPad = nil
	if st.ButtonPad then
		st.ButtonPad:Destroy()
		st.ButtonPad = nil
	end
	st.LaserMult = 1
	st.SpeedMult = 1
end

-- Производственный цикл ---------------------------------------------------------------------
local function processStone(st: BaseState, conv: Conveyor, stone: BasePart)
	local owner = st.Owner
	local idx = table.find(conv.Stones, stone)
	if idx then
		table.remove(conv.Stones, idx)
	end
	-- эффект переработки
	local beam = conv.Beam
	local origTrans = beam.Transparency
	beam.Transparency = 0
	task.delay(0.15, function()
		if beam.Parent then
			beam.Transparency = origTrans
		end
	end)
	local a = Instance.new("Attachment")
	a.WorldPosition = stone.Position
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://258128463"
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 120, 120))
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(4, 8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 0
	pe.Parent = a
	a.Parent = workspace.Terrain
	pe:Emit(12)
	task.delay(1, function()
		a:Destroy()
	end)

	if owner then
		local value = ctx.Config.StoneValue * st.LaserMult
		ctx.Services.DataService.AddTerminal(owner, value)
		updateTerminalLabel(st)
		ctx.Services.DataService.PushState(owner)
	end
	stone:Destroy()
end

local function productionLoop()
	RunService.Heartbeat:Connect(function(dt)
		for _, st in ipairs(bases) do
			if st.Owner then
				for _, conv in ipairs(st.Conveyors) do
					-- спавн камней
					conv.SpawnT += dt
					local interval = ctx.Config.SpawnInterval / st.SpeedMult
					if conv.SpawnT >= interval then
						conv.SpawnT = 0
						spawnStone(st, conv)
					end
					-- движение камней
					local speed = ctx.Config.BeltSpeed * st.SpeedMult
					for i = #conv.Stones, 1, -1 do
						local stone = conv.Stones[i]
						if not stone.Parent then
							table.remove(conv.Stones, i)
						else
							local newZ = stone.Position.Z + speed * dt
							if newZ >= conv.LaserZ then
								processStone(st, conv, stone)
							else
								stone.CFrame = CFrame.new(stone.Position.X, stone.Position.Y, newZ) * (stone.CFrame - stone.CFrame.Position)
							end
						end
					end
					-- вращение роликов
					local rot = CFrame.Angles(speed * dt * 1.2, 0, 0)
					conv.RollerA.CFrame = conv.RollerA.CFrame * rot
					conv.RollerB.CFrame = conv.RollerB.CFrame * rot
				end
			end
		end
	end)
end

-- Сбор денег с терминала ---------------------------------------------------------------------
local function watchCollectPads()
	RunService.Heartbeat:Connect(function()
		for _, st in ipairs(bases) do
			local owner = st.Owner
			local pad = st.CollectPad
			if owner and pad then
				local char = owner.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and (root.Position - pad.Position).Magnitude < 6 then
					local data = ctx.Services.DataService.Get(owner)
					if data and data.Terminal >= 1 then
						local amount = math.floor(data.Terminal)
						data.Terminal = 0
						ctx.Services.DataService.AddMoney(owner, amount)
						updateTerminalLabel(st)
						ctx.Services.DataService.PushState(owner)
						notify(owner, "+" .. amount .. " 💰 кредитов!", "success")
						-- эффект сбора
						ctx.Build.Sparkles(pad, Color3.fromRGB(120, 255, 160))
						task.delay(1, function()
							local sp = pad:FindFirstChildOfClass("Sparkles")
							if sp then sp:Destroy() end
						end)
					end
				end
			end
		end
	end)
end

-- Выдача участков ------------------------------------------------------------------------------
local function getFreeBase(): BaseState?
	for _, st in ipairs(bases) do
		if not st.Owner then
			return st
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local st = getFreeBase()
	if not st then
		player:Kick("Все участки заняты (6/6)!")
		return
	end
	st.Owner = player
	playerBase[player] = st
	setOwnerSign(st, player.DisplayName)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		local spawn = st.Folder:FindFirstChild("Spawn")
		if spawn and player.Character then
			player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
		end
	end)

	task.defer(function()
		local t0 = os.clock()
		while not ctx.Services.DataService.Get(player) and os.clock() - t0 < 10 do
			task.wait(0.2)
		end
		buildBaseFor(st, player)
	end)
end

local function onPlayerRemoving(player: Player)
	local st = playerBase[player]
	if st then
		clearBase(st)
		st.Owner = nil
		playerBase[player] = nil
		setOwnerSign(st, "СВОБОДНО")
	end
end

-- Жизненный цикл ---------------------------------------------------------------------------------
function BaseService.Init(c)
	ctx = c
end

function BaseService.Start()
	for i, pos in ipairs(ctx.Config.Plots) do
		table.insert(bases, buildPlot(i, pos))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end

	productionLoop()
	watchCollectPads()
	print("[BaseService] Участков построено: " .. #bases)
end

return BaseService
