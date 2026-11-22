--!strict
--==============================================================================
-- LunarBase :: BaseService
-- 6 участков, конвейеры, ИНТЕРАКТИВНАЯ обработка камней (очистка + опиливание),
-- работники-роботы, терминал, кнопки покупок, строительство, магазин-косметика.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = {}
local ctx

local rng = Random.new()
local function rng01(): number
	return rng:NextNumber()
end

type Stone = {
	Part: BasePart,
	Dirt: BasePart?,
	Prompt: ProximityPrompt?,
	Stage: number, -- 0=едет, 1=ждёт очистки, 2=ждёт опиливания, 3=готов
	Paused: boolean,
	WaitT: number,
	Progress: number,
	ClaimedBy: Player?,
	WorkerBusy: boolean,
	OrigSize: Vector3,
}

type Conveyor = {
	Model: Model,
	Belt: BasePart,
	RollerA: BasePart,
	RollerB: BasePart,
	Beam: BasePart,
	LaserZ: number,
	WorkZ: number,
	SpawnZ: number,
	X: number,
	Stones: { Stone },
	SpawnT: number,
}

type Worker = {
	Model: Model,
	Arm: BasePart,
	Home: CFrame,
	BusyStone: Stone?,
	WorkT: number,
	SparkT: number,
}

type BaseState = {
	Index: number,
	Center: Vector3,
	Folder: Folder,
	Owner: Player?,
	Conveyors: { Conveyor },
	Workers: { Worker },
	TerminalLabel: TextLabel?,
	CollectPad: BasePart?,
	ButtonPad: BasePart?,
	LaserMult: number,
	SpeedMult: number,
	Drills: number,
	Structures: { Instance },
}

local bases: { BaseState } = {}
local playerBase: { [Player]: BaseState } = {}

local function notify(player: Player, text: string, colorName: string?)
	ctx.Remotes.Notify:FireClient(player, text, colorName or "info")
end

-- ============================ СТРОИТЕЛЬСТВО УЧАСТКА ============================

local function buildPlot(index: number, center: Vector3): BaseState
	local B = ctx.Build
	local folder = Instance.new("Folder")
	folder.Name = "Base_" .. index
	folder.Parent = workspace

	local S = ctx.Config.PlotSize
	B.Part(folder, {
		Size = Vector3.new(S, 1, S),
		CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(96, 98, 108),
		Material = Enum.Material.Pavement,
		Name = "Pad",
	})
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

	-- табличка СНАРУЖИ территории, у передней границы, текст наружу
	local signPos = CFrame.new(center + Vector3.new(-14, 5, S / 2 + 6)) * CFrame.Angles(0, math.pi, 0)
	local signBoard = B.Part(folder, {
		Size = Vector3.new(10, 3, 0.5),
		CFrame = signPos,
		Color = Color3.fromRGB(35, 38, 48),
		Name = "OwnerSign",
	})
	B.Neon(folder, {
		Size = Vector3.new(10.4, 0.3, 0.6),
		CFrame = signPos * CFrame.new(0, 1.65, 0),
		Color = Color3.fromRGB(255, 210, 80),
		CanCollide = false,
	})
	for _, sx in ipairs({ -4, 4 }) do
		B.Part(folder, {
			Size = Vector3.new(0.5, 5, 0.5),
			CFrame = signPos * CFrame.new(sx, -3.6, 0),
			Color = Color3.fromRGB(70, 72, 80),
		})
	end
	B.SignText(signBoard, "СВОБОДНО", Color3.fromRGB(255, 220, 100))

	local st: BaseState = {
		Index = index,
		Center = center,
		Folder = folder,
		Owner = nil,
		Conveyors = {},
		Workers = {},
		TerminalLabel = nil,
		CollectPad = nil,
		ButtonPad = nil,
		LaserMult = 1,
		SpeedMult = 1,
		Drills = 0,
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

-- ============================ КОНВЕЙЕР ============================

local function buildConveyor(st: BaseState, convIndex: number)
	local xOff = ctx.Config.ConveyorX[convIndex]
	if not xOff then
		warn("[BaseService] Нет позиции для конвейера " .. convIndex)
		return
	end
	local B = ctx.Build
	local c = st.Center
	local L = ctx.Config.ConveyorLength
	local z0 = c.Z - L / 2 + 5
	local zMid = c.Z

	local m = Instance.new("Model")
	m.Name = "Conveyor" .. convIndex

	local belt = B.Part(m, {
		Size = Vector3.new(3, 0.5, L),
		CFrame = CFrame.new(c.X + xOff, 2, zMid),
		Color = Color3.fromRGB(45, 48, 55),
		Material = Enum.Material.DiamondPlate,
		Name = "Belt",
	})
	for _, sx in ipairs({ -1.9, 1.9 }) do
		B.Part(m, {
			Size = Vector3.new(0.5, 1.2, L),
			CFrame = CFrame.new(c.X + xOff + sx, 2.4, zMid),
			Color = Color3.fromRGB(150, 155, 165),
			Material = Enum.Material.DiamondPlate,
		})
	end
	for i = 0, 4 do
		local lz = z0 + i * (L / 4)
		for _, sx in ipairs({ -1.6, 1.6 }) do
			B.Part(m, {
				Size = Vector3.new(0.6, 2, 0.6),
				CFrame = CFrame.new(c.X + xOff + sx, 1, lz),
				Color = Color3.fromRGB(110, 115, 125),
				Material = Enum.Material.Metal,
			})
		end
	end
	local rollerA = B.Part(m, {
		Size = Vector3.new(0.9, 3.2, 3.2),
		CFrame = CFrame.new(c.X + xOff, 2, z0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 185, 195),
		Shape = Enum.PartType.Cylinder,
		Name = "RollerA",
	})
	rollerA.Material = Enum.Material.Metal
	local rollerB = B.Part(m, {
		Size = Vector3.new(0.9, 3.2, 3.2),
		CFrame = CFrame.new(c.X + xOff, 2, z0 + L) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(180, 185, 195),
		Shape = Enum.PartType.Cylinder,
		Name = "RollerB",
	})
	rollerB.Material = Enum.Material.Metal

	-- рабочая площадка посередине (камень останавливается здесь)
	local workZ = z0 + L * 0.45
	local padMark = B.Neon(m, {
		Size = Vector3.new(3.4, 0.15, 2),
		CFrame = CFrame.new(c.X + xOff, 2.35, workZ),
		Color = Color3.fromRGB(255, 210, 80),
		CanCollide = false,
		Name = "WorkPad",
	})
	B.Billboard(padMark, "🔧 Обработка", Color3.fromRGB(255, 220, 120), 4)

	-- лазерная установка в конце
	local laserZ = z0 + L - 4
	for _, sx in ipairs({ -2.4, 2.4 }) do
		B.Part(m, {
			Size = Vector3.new(0.8, 7, 0.8),
			CFrame = CFrame.new(c.X + xOff + sx, 4.5, laserZ),
			Color = Color3.fromRGB(60, 64, 75),
			Material = Enum.Material.Metal,
		})
	end
	B.Part(m, {
		Size = Vector3.new(5.6, 1.4, 2),
		CFrame = CFrame.new(c.X + xOff, 8.4, laserZ),
		Color = Color3.fromRGB(60, 64, 75),
		Material = Enum.Material.Metal,
		Name = "LaserHead",
	})
	local emitter = B.Neon(m, {
		Size = Vector3.new(1, 0.8, 1),
		CFrame = CFrame.new(c.X + xOff, 7.5, laserZ),
		Color = Color3.fromRGB(255, 70, 70),
		Name = "Emitter",
	})
	local beam = B.Neon(m, {
		Size = Vector3.new(0.35, 5, 0.35),
		CFrame = CFrame.new(c.X + xOff, 5, laserZ),
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
		WorkZ = workZ,
		SpawnZ = z0 + 2,
		X = c.X + xOff,
		Stones = {},
		SpawnT = 0,
	}
	table.insert(st.Conveyors, conv)
	print("[BaseService] Построен конвейер #" .. convIndex .. " на базе " .. st.Index)
end

-- ============================ ТЕРМИНАЛ ============================

local function buildTerminal(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Terminal"

	-- консоль (машина для денег)
	B.Part(m, {
		Size = Vector3.new(4, 3, 2),
		CFrame = CFrame.new(c.X + 34, 2.5, c.Z + 2),
		Color = Color3.fromRGB(50, 54, 66),
		Material = Enum.Material.DiamondPlate,
	})
	local screen = B.Part(m, {
		Size = Vector3.new(3.4, 2, 0.3),
		CFrame = CFrame.new(c.X + 34, 5, c.Z + 2) * CFrame.Angles(math.rad(-15), 0, 0),
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
	B.Part(m, {
		Size = Vector3.new(2, 1, 2),
		CFrame = CFrame.new(c.X + 34, 1, c.Z + 2),
		Color = Color3.fromRGB(70, 74, 86),
		Material = Enum.Material.Metal,
	})
	B.Billboard(screen, "ТЕРМИНАЛ", Color3.fromRGB(150, 200, 255), 3.5)

	-- площадка сбора — ОТДЕЛЬНЫЙ объект, в стороне от консоли
	local pad = B.Neon(m, {
		Size = Vector3.new(6, 0.4, 6),
		CFrame = CFrame.new(c.X + 34, 1.2, c.Z + 28) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 255, 140),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "CollectPad",
	})
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

-- ============================ КАМНИ: СПАВН И ИНТЕРАКТИВ ============================

local function spawnStone(st: BaseState, conv: Conveyor)
	if #conv.Stones >= 14 then return end
	local B = ctx.Build
	local s = rng01() * 0.7 + 0.9
	local part = B.Part(conv.Model, {
		Size = Vector3.new(s, s * 0.8, s),
		CFrame = CFrame.new(conv.X + (rng01() - 0.5), 3, conv.SpawnZ) * CFrame.Angles(rng01() * 3, rng01() * 3, 0),
		Color = Color3.fromRGB(105 + math.floor(rng01() * 25), 105 + math.floor(rng01() * 25), 112),
		Material = Enum.Material.Slate,
		Name = "Stone",
		CanCollide = false,
	})
	-- слой лунной грязи (чуть больше камня)
	local dirt = B.Part(conv.Model, {
		Size = part.Size + Vector3.new(0.22, 0.22, 0.22),
		CFrame = part.CFrame,
		Color = Color3.fromRGB(70, 62, 52),
		Material = Enum.Material.Ground,
		Transparency = 0.15,
		Name = "Dirt",
		CanCollide = false,
	})
	dirt.CanQuery = false -- мышь и клики проходят сквозь грязь к камню

	-- промпт обработки (E) — включается, когда камень остановился
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Обработать"
	pp.ObjectText = "Лунный камень"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = ctx.Config.WorkDistance
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = part

	local stone: Stone = {
		Part = part,
		Dirt = dirt,
		Prompt = pp,
		Stage = 0,
		Paused = false,
		WaitT = 0,
		Progress = 0,
		ClaimedBy = nil,
		WorkerBusy = false,
		OrigSize = part.Size,
	}

	pp.Triggered:Connect(function(player)
		BaseService.TryStartWork(st, stone, player)
	end)

	table.insert(conv.Stones, stone)
end

function BaseService.TryStartWork(st: BaseState, stone: Stone, player: Player)
	if st.Owner ~= player then return end
	if not stone.Paused or stone.Stage < 1 or stone.Stage > 2 then return end
	if stone.WorkerBusy then
		notify(player, "Робот уже обрабатывает этот камень", "info")
		return
	end
	if stone.ClaimedBy and stone.ClaimedBy ~= player then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (root.Position - stone.Part.Position).Magnitude > ctx.Config.WorkDistance then return end
	stone.ClaimedBy = player
	stone.Progress = 0
	ctx.Remotes.WorkBegin:FireClient(player, stone.Part, stone.Stage)
end

-- тик работы от клиента
local function onWorkTick(player: Player, stonePart: BasePart, dt: number)
	if typeof(dt) ~= "number" or dt <= 0 or dt > 1 then return end
	for _, st in ipairs(bases) do
		if st.Owner ~= player then continue end
		for _, conv in ipairs(st.Conveyors) do
			for _, stone in ipairs(conv.Stones) do
				if stone.Part == stonePart and stone.ClaimedBy == player and stone.Paused then
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if not root or (root.Position - stone.Part.Position).Magnitude > ctx.Config.WorkDistance + 6 then
						stone.ClaimedBy = nil
						ctx.Remotes.WorkStage:FireClient(player, stone.Part, 0)
						return
					end
					stone.Progress += dt
					local need = if stone.Stage == 1 then ctx.Config.CleanTime else ctx.Config.SawTime
					local frac = math.clamp(stone.Progress / need, 0, 1)
					if stone.Stage == 1 and stone.Dirt then
						stone.Dirt.Transparency = 0.15 + frac * 0.85
					elseif stone.Stage == 2 then
						stone.Part.Size = stone.OrigSize * (1 - 0.18 * frac)
					end
					if frac >= 1 then
						BaseService.CompleteStage(st, stone, player)
					end
					return
				end
			end
		end
	end
end

function BaseService.CompleteStage(st: BaseState, stone: Stone, player: Player?)
	if stone.Stage == 1 then
		-- очистка завершена
		if stone.Dirt then
			stone.Dirt:Destroy()
			stone.Dirt = nil
		end
		stone.Part.Color = Color3.fromRGB(160, 160, 170)
		stone.Stage = 2
		stone.Progress = 0
		if player then
			ctx.Remotes.WorkStage:FireClient(player, stone.Part, 2)
			notify(player, "Чисто! Теперь опили камень", "info")
		end
	elseif stone.Stage == 2 then
		-- опиливание завершено: камень превращается в самоцвет
		stone.Stage = 3
		stone.Progress = 0
		stone.Paused = false
		stone.ClaimedBy = nil
		stone.WorkerBusy = false
		if stone.Prompt then
			stone.Prompt.Enabled = false
		end
		stone.Part.Material = Enum.Material.SmoothPlastic
		stone.Part.Color = Color3.fromRGB(140, 220, 255)
		stone.Part.Size = stone.OrigSize * 0.8
		ctx.Build.Sparkles(stone.Part, Color3.fromRGB(140, 220, 255))
		if player then
			ctx.Remotes.WorkStage:FireClient(player, stone.Part, 3)
			notify(player, "💎 Самоцвет готов! x" .. ctx.Config.ProcessedMult .. " к цене", "success")
		end
	end
end

-- ============================ РАБОТНИКИ-РОБОТЫ ============================

local function buildWorker(st: BaseState)
	local B = ctx.Build
	local idx = #st.Workers + 1
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Worker" .. idx

	-- робот: торс, голова, руки, ноги
	local torso = B.Part(m, {
		Size = Vector3.new(1.8, 2.2, 1.2),
		CFrame = CFrame.new(c.X, 3.2, c.Z),
		Color = Color3.fromRGB(200, 120, 40),
		Material = Enum.Material.Metal,
		Name = "Torso",
	})
	B.Part(m, {
		Size = Vector3.new(1.3, 1, 1.1),
		CFrame = torso.CFrame * CFrame.new(0, 1.7, 0),
		Color = Color3.fromRGB(170, 100, 35),
		Material = Enum.Material.Metal,
		Name = "Head",
	})
	B.Neon(m, {
		Size = Vector3.new(0.9, 0.3, 0.2),
		CFrame = torso.CFrame * CFrame.new(0, 1.75, -0.58),
		Color = Color3.fromRGB(120, 220, 255),
		Name = "Eyes",
	})
	local arm = B.Part(m, {
		Size = Vector3.new(0.5, 1.8, 0.5),
		CFrame = torso.CFrame * CFrame.new(-1.2, -0.2, 0),
		Color = Color3.fromRGB(150, 90, 30),
		Material = Enum.Material.Metal,
		Name = "Arm",
	})
	B.Part(m, {
		Size = Vector3.new(0.5, 1.8, 0.5),
		CFrame = torso.CFrame * CFrame.new(1.2, -0.2, 0),
		Color = Color3.fromRGB(150, 90, 30),
		Material = Enum.Material.Metal,
	})
	B.Part(m, {
		Size = Vector3.new(0.6, 1.4, 0.6),
		CFrame = torso.CFrame * CFrame.new(-0.5, -1.8, 0),
		Color = Color3.fromRGB(90, 92, 100),
		Material = Enum.Material.Metal,
	})
	B.Part(m, {
		Size = Vector3.new(0.6, 1.4, 0.6),
		CFrame = torso.CFrame * CFrame.new(0.5, -1.8, 0),
		Color = Color3.fromRGB(90, 92, 100),
		Material = Enum.Material.Metal,
	})
	-- антенна
	B.Neon(m, {
		Size = Vector3.new(0.15, 0.8, 0.15),
		CFrame = torso.CFrame * CFrame.new(0, 2.6, 0),
		Color = Color3.fromRGB(255, 80, 80),
	})

	m.PrimaryPart = torso
	local homeCF = CFrame.new(c.X, 3.2, c.Z)
	m.Parent = st.Folder
	table.insert(st.Structures, m)

	local worker: Worker = {
		Model = m,
		Arm = arm,
		Home = homeCF,
		BusyStone = nil,
		WorkT = 0,
		SparkT = 0,
	}
	table.insert(st.Workers, worker)
	BaseService.PlaceWorkerAtConveyor(st, worker, idx)
	B.Billboard(torso, "🤖 Работник " .. idx, Color3.fromRGB(255, 190, 100), 2.5)
end

function BaseService.PlaceWorkerAtConveyor(st: BaseState, worker: Worker, idx: number)
	local nConv = math.max(#st.Conveyors, 1)
	local convIdx = ((idx - 1) % nConv) + 1
	local conv = st.Conveyors[convIdx]
	if conv then
		worker.Home = CFrame.new(conv.X - 4.5, 3.2, conv.WorkZ)
		worker.Model:PivotTo(worker.Home)
	end
end

-- ============================ ПОСТРОЙКИ (улучшения) ============================

local function buildLights(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Lights"
	for _, p in ipairs({ Vector3.new(-48, 0, -48), Vector3.new(48, 0, -48), Vector3.new(-48, 0, 48), Vector3.new(48, 0, 48) }) do
		B.Part(m, {
			Size = Vector3.new(0.7, 9, 0.7),
			CFrame = CFrame.new(c + p + Vector3.new(0, 5.5, 0)),
			Color = Color3.fromRGB(60, 62, 72),
			Material = Enum.Material.Metal,
		})
		local lampHead = B.Neon(m, {
			Size = Vector3.new(1.6, 0.8, 1.6),
			CFrame = CFrame.new(c + p + Vector3.new(0, 10.2, 0)),
			Color = Color3.fromRGB(255, 240, 180),
		})
		B.Light(lampHead, Color3.fromRGB(255, 240, 190), 30, 1.6)
	end
	m.Parent = st.Folder
	table.insert(st.Structures, m)
end

local function buildWalls(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Walls"
	local S = ctx.Config.PlotSize / 2
	local wallC = Color3.fromRGB(130, 134, 146)
	-- задняя и боковые стены (передняя — с воротами)
	B.Part(m, { Size = Vector3.new(S * 2, 7, 1.5), CFrame = CFrame.new(c + Vector3.new(0, 4, -S)), Color = wallC, Material = Enum.Material.Concrete })
	B.Part(m, { Size = Vector3.new(1.5, 7, S * 2), CFrame = CFrame.new(c + Vector3.new(-S, 4, 0)), Color = wallC, Material = Enum.Material.Concrete })
	B.Part(m, { Size = Vector3.new(1.5, 7, S * 2), CFrame = CFrame.new(c + Vector3.new(S, 4, 0)), Color = wallC, Material = Enum.Material.Concrete })
	-- ворота спереди
	B.Part(m, { Size = Vector3.new(S - 10, 7, 1.5), CFrame = CFrame.new(c + Vector3.new(-(S + 10) / 2, 4, S)), Color = wallC, Material = Enum.Material.Concrete })
	B.Part(m, { Size = Vector3.new(S - 10, 7, 1.5), CFrame = CFrame.new(c + Vector3.new((S + 10) / 2, 4, S)), Color = wallC, Material = Enum.Material.Concrete })
	B.Part(m, { Size = Vector3.new(20, 2, 1.5), CFrame = CFrame.new(c + Vector3.new(0, 8, S)), Color = wallC, Material = Enum.Material.Concrete })
	-- неоновый кант по верху стен
	for _, d in ipairs({
		{ Vector3.new(0, 7.7, -S), Vector3.new(S * 2, 0.4, 1.7) },
		{ Vector3.new(-S, 7.7, 0), Vector3.new(1.7, 0.4, S * 2) },
		{ Vector3.new(S, 7.7, 0), Vector3.new(1.7, 0.4, S * 2) },
	}) do
		B.Neon(m, { Size = d[2], CFrame = CFrame.new(c + d[1]), Color = Color3.fromRGB(90, 160, 255), CanCollide = false })
	end
	m.Parent = st.Folder
	table.insert(st.Structures, m)
end

local function buildExpand(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local S2 = ctx.Config.PlotSizeExpanded
	-- новая большая плита поверх старой
	B.Part(st.Folder, {
		Size = Vector3.new(S2, 0.8, S2),
		CFrame = CFrame.new(c + Vector3.new(0, 1.1, 0)),
		Color = Color3.fromRGB(110, 112, 122),
		Material = Enum.Material.Concrete,
		Name = "PadExpanded",
	})
	-- внешняя рамка
	for _, d in ipairs({
		{ Vector3.new(0, 0, S2 / 2), Vector3.new(S2, 0.4, 0.6) },
		{ Vector3.new(0, 0, -S2 / 2), Vector3.new(S2, 0.4, 0.6) },
		{ Vector3.new(S2 / 2, 0, 0), Vector3.new(0.6, 0.4, S2) },
		{ Vector3.new(-S2 / 2, 0, 0), Vector3.new(0.6, 0.4, S2) },
	}) do
		B.Neon(st.Folder, {
			Size = d[2],
			CFrame = CFrame.new(c + d[1] + Vector3.new(0, 1.6, 0)),
			Color = Color3.fromRGB(90, 160, 255),
			CanCollide = false,
			Name = "TerritoryFrame",
		})
	end
end

local function buildDrill(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "Drill"
	-- вышка
	for _, sx in ipairs({ -2, 2 }) do
		for _, sz in ipairs({ -2, 2 }) do
			B.Part(m, {
				Size = Vector3.new(0.6, 14, 0.6),
				CFrame = CFrame.new(c + Vector3.new(-30 + sx, 8, -45 + sz)),
				Color = Color3.fromRGB(150, 120, 50),
				Material = Enum.Material.Metal,
			})
		end
	end
	B.Part(m, { Size = Vector3.new(6, 1.5, 6), CFrame = CFrame.new(c + Vector3.new(-30, 15, -45)), Color = Color3.fromRGB(170, 140, 60), Material = Enum.Material.Metal })
	-- бур (вращается в цикле)
	local bit = B.Part(m, {
		Size = Vector3.new(6, 1.6, 1.6),
		CFrame = CFrame.new(c + Vector3.new(-30, 6, -45)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 124, 134),
		Shape = Enum.PartType.Cylinder,
		Name = "DrillBit",
	})
	bit.Material = Enum.Material.DiamondPlate
	B.Neon(m, { Size = Vector3.new(6.2, 0.3, 6.2), CFrame = CFrame.new(c + Vector3.new(-30, 15.9, -45)), Color = Color3.fromRGB(255, 200, 80), CanCollide = false })
	B.Billboard(bit, "⛏️ Бур +" .. ctx.Config.DrillIncome .. "💰/с", Color3.fromRGB(255, 220, 120), 5)
	m.Parent = st.Folder
	table.insert(st.Structures, m)
	st.Drills += 1
end

local function buildHabitat(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "habitat"
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
	m.Parent = st.Folder
	table.insert(st.Structures, m)
end

local function buildLab(st: BaseState)
	local B = ctx.Build
	local c = st.Center
	local m = Instance.new("Model")
	m.Name = "lab"
	B.Part(m, { Size = Vector3.new(10, 16, 10), CFrame = CFrame.new(c.X + 28, 9, c.Z - 28), Color = Color3.fromRGB(180, 185, 195), Material = Enum.Material.Metal })
	B.Neon(m, { Size = Vector3.new(10.4, 1, 10.4), CFrame = CFrame.new(c.X + 28, 17.5, c.Z - 28), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
	local dish = B.Part(m, {
		Size = Vector3.new(6, 0.8, 6),
		CFrame = CFrame.new(c.X + 28, 20, c.Z - 28) * CFrame.Angles(math.rad(30), 0, math.rad(90)),
		Color = Color3.fromRGB(220, 224, 232),
		Shape = Enum.PartType.Cylinder,
	})
	B.Sparkles(dish, Color3.fromRGB(140, 220, 255))
	m.Parent = st.Folder
	table.insert(st.Structures, m)
end

-- ============================ УЛУЧШЕНИЯ ============================

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
	if st.ButtonPad then
		st.ButtonPad:Destroy()
		st.ButtonPad = nil
	end
	local u = nextUpgrade(st)
	if not u then return end

	local c = st.Center
	local pad = B.Neon(st.Folder, {
		Size = Vector3.new(7, 0.6, 7),
		CFrame = CFrame.new(c.X - 34, 1.3, c.Z + 30) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 200, 60),
		Shape = Enum.PartType.Cylinder,
		CanCollide = false,
		Name = "BuyButton",
	})
	B.Billboard(pad, string.format("%s\n%d 💰", u.Name, u.Cost), Color3.fromRGB(255, 220, 100), 3)
	st.ButtonPad = pad

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
	print("[BaseService] " .. owner.Name .. " купил " .. u.Id)
	BaseService.ApplyUpgrade(st, u)
	refreshButton(st)
	ctx.Services.DataService.PushState(owner)
	notify(owner, "✅ " .. u.Name .. " — построено!", "success")
end

function BaseService.ApplyUpgrade(st: BaseState, u: any)
	if u.Kind == "conveyor" then
		buildConveyor(st, #st.Conveyors + 1)
		-- переставить работников на актуальные конвейеры
		for i, w in ipairs(st.Workers) do
			BaseService.PlaceWorkerAtConveyor(st, w, i)
		end
	elseif u.Kind == "laser" then
		st.LaserMult = u.Mult
		for _, conv in ipairs(st.Conveyors) do
			conv.Beam.Size = Vector3.new(0.35 + st.LaserMult * 0.15, 5, 0.35 + st.LaserMult * 0.15)
			conv.Beam.Color = Color3.fromRGB(255, math.max(20, 90 - st.LaserMult * 15), 60)
		end
	elseif u.Kind == "speed" then
		st.SpeedMult = u.Mult
	elseif u.Kind == "lights" then
		buildLights(st)
	elseif u.Kind == "walls" then
		buildWalls(st)
	elseif u.Kind == "expand" then
		buildExpand(st)
	elseif u.Kind == "drill" then
		buildDrill(st)
	elseif u.Kind == "worker" then
		buildWorker(st)
	elseif u.Kind == "building" then
		if u.Id == "habitat" then
			buildHabitat(st)
		elseif u.Id == "lab" then
			buildLab(st)
		end
	end
end

-- ============================ МАГАЗИН (косметика) ============================

local function applyShopItem(st: BaseState, itemId: string)
	local B = ctx.Build
	local item = nil
	for _, it in ipairs(ctx.Config.ShopItems) do
		if it.Id == itemId then
			item = it
			break
		end
	end
	if not item then return end
	if item.Id == "flag" then
		local c = st.Center
		local m = Instance.new("Model")
		m.Name = "Flag"
		B.Part(m, { Size = Vector3.new(0.4, 14, 0.4), CFrame = CFrame.new(c + Vector3.new(50, 8, 50)), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.Metal })
		B.Part(m, { Size = Vector3.new(5, 3, 0.2), CFrame = CFrame.new(c + Vector3.new(52.6, 13.5, 50)), Color = item.Color, Material = Enum.Material.SmoothPlastic })
		B.Neon(m, { Size = Vector3.new(0.6, 0.6, 0.6), CFrame = CFrame.new(c + Vector3.new(50, 15.3, 50)), Color = item.Color, Shape = Enum.PartType.Ball })
		m.Parent = st.Folder
		table.insert(st.Structures, m)
	else
		-- перекраска рамки территории
		for _, d in ipairs(st.Folder:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "TerritoryFrame" then
				d.Color = item.Color
			end
		end
	end
end

local function onBuyShopItem(player: Player, itemId: string)
	local st = playerBase[player]
	if not st then return end
	local data = ctx.Services.DataService.Get(player)
	if not data then return end
	local item = nil
	for _, it in ipairs(ctx.Config.ShopItems) do
		if it.Id == itemId then
			item = it
			break
		end
	end
	if not item then return end
	if data.ShopItems[item.Id] then
		notify(player, "Уже куплено!", "error")
		return
	end
	if not ctx.Services.DataService.TrySpend(player, item.Cost) then
		notify(player, "Не хватает кредитов! Нужно " .. item.Cost .. "💰", "error")
		return
	end
	data.ShopItems[item.Id] = true
	applyShopItem(st, item.Id)
	ctx.Services.DataService.PushState(player)
	notify(player, "🛍️ «" .. item.Name .. "» применено!", "success")
end

-- ============================ ПРОИЗВОДСТВЕННЫЙ ЦИКЛ ============================

local function processStone(st: BaseState, conv: Conveyor, stone: Stone)
	local owner = st.Owner
	local idx = table.find(conv.Stones, stone)
	if idx then
		table.remove(conv.Stones, idx)
	end
	local beam = conv.Beam
	local origTrans = beam.Transparency
	beam.Transparency = 0
	task.delay(0.15, function()
		if beam.Parent then
			beam.Transparency = origTrans
		end
	end)
	local a = Instance.new("Attachment")
	a.WorldPosition = stone.Part.Position
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxassetid://258128463"
	local processed = stone.Stage == 3
	pe.Color = ColorSequence.new(if processed then Color3.fromRGB(140, 220, 255) else Color3.fromRGB(255, 120, 120))
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
	pe:Emit(if processed then 24 else 12)
	task.delay(1, function()
		a:Destroy()
	end)

	if owner then
		local value = ctx.Config.StoneValue * st.LaserMult
		if processed then
			value *= ctx.Config.ProcessedMult
		end
		ctx.Services.DataService.AddTerminal(owner, value)
		updateTerminalLabel(st)
	end
	if stone.Dirt then
		stone.Dirt:Destroy()
	end
	stone.Part:Destroy()
end

local function updateWorkers(st: BaseState, dt: number)
	for i, worker in ipairs(st.Workers) do
		local busy = worker.BusyStone
		if busy then
			-- камень исчез или уехал?
			if not busy.Part.Parent or not busy.Paused then
				worker.BusyStone = nil
				worker.WorkT = 0
			else
				worker.WorkT += dt
				worker.SparkT += dt
				-- анимация руки и подъезд к камню
				local targetCF = CFrame.new(busy.Part.Position + Vector3.new(-2.5, 0.2, 0))
				worker.Model:PivotTo(worker.Model:GetPivot():Lerp(targetCF, math.min(dt * 3, 1)))
				worker.Arm.CFrame = worker.Arm.CFrame * CFrame.Angles(dt * 6, 0, 0)
				if worker.SparkT >= 0.5 then
					worker.SparkT = 0
					local a = Instance.new("Attachment")
					a.WorldPosition = busy.Part.Position
					local pe = Instance.new("ParticleEmitter")
					pe.Texture = "rbxassetid://258128463"
					pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
					pe.Size = NumberSequence.new(0.5)
					pe.Lifetime = NumberRange.new(0.2, 0.4)
					pe.Speed = NumberRange.new(3, 5)
					pe.Rate = 0
					pe.Parent = a
					a.Parent = workspace.Terrain
					pe:Emit(6)
					task.delay(0.8, function()
						a:Destroy()
					end)
				end
				if worker.WorkT >= ctx.Config.WorkerTime then
					-- робот доводит камень до самоцвета
					if busy.Stage == 1 then
						BaseService.CompleteStage(st, busy, nil)
					end
					BaseService.CompleteStage(st, busy, nil)
					worker.BusyStone = nil
					worker.WorkT = 0
				end
			end
		else
			-- ищем камень на своём конвейере
			local nConv = math.max(#st.Conveyors, 1)
			local conv = st.Conveyors[((i - 1) % nConv) + 1]
			if conv then
				for _, stone in ipairs(conv.Stones) do
					if stone.Paused and stone.Stage >= 1 and stone.Stage <= 2 and not stone.ClaimedBy and not stone.WorkerBusy then
						stone.WorkerBusy = true
						worker.BusyStone = stone
						worker.WorkT = 0
						break
					end
				end
			end
			if not worker.BusyStone then
				-- вернуться на место
				worker.Model:PivotTo(worker.Model:GetPivot():Lerp(worker.Home, math.min(dt * 2, 1)))
			end
		end
	end
end

local function productionLoop()
	local pushT = 0
	RunService.Heartbeat:Connect(function(dt)
		pushT += dt
		local doPush = pushT >= 3
		if doPush then
			pushT = 0
		end
		for _, st in ipairs(bases) do
			local owner = st.Owner
			if not owner then continue end
			local data = ctx.Services.DataService.Get(owner)
			-- пассивный доход буров
			if data and st.Drills > 0 then
				ctx.Services.DataService.AddTerminal(owner, ctx.Config.DrillIncome * st.Drills * dt)
			end
			for _, conv in ipairs(st.Conveyors) do
				-- спавн
				conv.SpawnT += dt
				if conv.SpawnT >= ctx.Config.SpawnInterval / st.SpeedMult then
					conv.SpawnT = 0
					spawnStone(st, conv)
				end
				-- движение камней с дистанцией
				local speed = ctx.Config.BeltSpeed * st.SpeedMult
				for i = #conv.Stones, 1, -1 do
					local stone = conv.Stones[i]
					if not stone.Part.Parent then
						table.remove(conv.Stones, i)
					elseif stone.Paused then
						stone.WaitT += dt
						-- проверка: игрок, взявший камень, ещё рядом?
						if stone.ClaimedBy then
							local char = stone.ClaimedBy.Character
							local root = char and char:FindFirstChild("HumanoidRootPart")
							if not root or (root.Position - stone.Part.Position).Magnitude > ctx.Config.WorkDistance + 6 then
								ctx.Remotes.WorkStage:FireClient(stone.ClaimedBy, stone.Part, 0)
								stone.ClaimedBy = nil
								stone.Progress = 0
							end
						end
						if stone.WaitT >= ctx.Config.StoneWaitTimeout and not stone.ClaimedBy and not stone.WorkerBusy then
							-- устал ждать: едет дальше сырым
							stone.Paused = false
							if stone.Prompt then
								stone.Prompt.Enabled = false
							end
						end
					else
						local myZ = stone.Part.Position.Z
						local blocked = false
						for _, other in ipairs(conv.Stones) do
							if other ~= stone and other.Part.Parent then
								local dz = other.Part.Position.Z - myZ
								if dz > 0 and dz < 2.6 then
									blocked = true
									break
								end
							end
						end
						if not blocked then
							local newZ = myZ + speed * dt
							if newZ >= conv.LaserZ then
								processStone(st, conv, stone)
							elseif newZ >= conv.WorkZ and stone.Stage == 0 then
								-- стоп на рабочей площадке
								stone.Paused = true
								stone.Stage = 1
								stone.WaitT = 0
								if stone.Prompt then
									stone.Prompt.Enabled = true
								end
								stone.Part.CFrame = CFrame.new(stone.Part.Position.X, 3, conv.WorkZ) * (stone.Part.CFrame - stone.Part.CFrame.Position)
								if stone.Dirt then
									stone.Dirt.CFrame = stone.Part.CFrame
								end
							else
								stone.Part.CFrame = CFrame.new(stone.Part.Position.X, 3, newZ) * (stone.Part.CFrame - stone.Part.CFrame.Position)
								if stone.Dirt then
									stone.Dirt.CFrame = stone.Part.CFrame
								end
							end
						end
					end
				end
				-- вращение роликов
				local rot = CFrame.Angles(speed * dt * 1.2, 0, 0)
				conv.RollerA.CFrame = conv.RollerA.CFrame * rot
				conv.RollerB.CFrame = conv.RollerB.CFrame * rot
			end
			updateWorkers(st, dt)
			if doPush then
				updateTerminalLabel(st)
				ctx.Services.DataService.PushState(owner)
			end
		end
	end)
end

-- ============================ СБОР ДЕНЕГ ============================

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

-- ============================ ФИЗИЧЕСКИЙ МАГАЗИН НА ЛУНЕ ============================

local function buildMoonShop()
	local B = ctx.Build
	local m = Instance.new("Model")
	m.Name = "MoonShop"
	local pos = Vector3.new(0, 0, 0)

	B.Part(m, { Size = Vector3.new(20, 1, 16), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color = Color3.fromRGB(90, 94, 110), Material = Enum.Material.Metal })
	for _, sx in ipairs({ -9.5, 9.5 }) do
		B.Part(m, { Size = Vector3.new(1, 9, 16), CFrame = CFrame.new(pos + Vector3.new(sx, 5, 0)), Color = Color3.fromRGB(120, 126, 145), Material = Enum.Material.Metal })
	end
	B.Part(m, { Size = Vector3.new(20, 9, 1), CFrame = CFrame.new(pos + Vector3.new(0, 5, 7.5)), Color = Color3.fromRGB(120, 126, 145), Material = Enum.Material.Metal })
	B.Part(m, { Size = Vector3.new(22, 1.5, 18), CFrame = CFrame.new(pos + Vector3.new(0, 10, 0)), Color = Color3.fromRGB(70, 74, 90), Material = Enum.Material.Metal })
	B.Neon(m, { Size = Vector3.new(22.4, 0.4, 18.4), CFrame = CFrame.new(pos + Vector3.new(0, 10.9, 0)), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
	-- торговый терминал
	local term = B.Part(m, { Size = Vector3.new(3, 4.5, 2), CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 3)), Color = Color3.fromRGB(45, 50, 66), Material = Enum.Material.Metal, Name = "ShopTerminal" })
	local scr = B.Neon(m, { Size = Vector3.new(2.4, 1.8, 0.2), CFrame = term.CFrame * CFrame.new(0, 0.8, -1.05), Color = Color3.fromRGB(140, 220, 255), CanCollide = false })
	B.SignText(scr, "🛒", Color3.new(1, 1, 1))
	local signBoard = B.Part(m, { Size = Vector3.new(12, 2.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 8, 7.8)) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(30, 34, 46), CanCollide = false })
	B.SignText(signBoard, "🛒 ЛУННЫЙ МАГАЗИН", Color3.fromRGB(140, 220, 255))
	for i = 1, 3 do
		local it = B.Neon(m, {
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(pos + Vector3.new(-6 + i * 4.5, 2, 5)),
			Color = Color3.fromRGB(120 + i * 40, 180, 255 - i * 30),
			Shape = Enum.PartType.Ball,
			CanCollide = false,
		})
		B.Sparkles(it)
	end
	B.Light(term, Color3.fromRGB(140, 220, 255), 20, 1.5)

	local pp = B.Prompt(term, "Торговать", "Лунный магазин")
	pp.Triggered:Connect(function(player)
		ctx.Remotes.OpenShop:FireClient(player)
	end)

	m.Parent = workspace
end

-- ============================ ИГРОКИ ============================

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

local function buildBaseFor(st: BaseState, player: Player)
	local data = ctx.Services.DataService.Get(player)
	if not data then return end
	recomputeMultipliers(st, data)
	buildConveyor(st, 1)
	buildTerminal(st)
	for _, u in ipairs(ctx.Config.Upgrades) do
		if data.Purchases[u.Id] and u.Kind ~= "laser" and u.Kind ~= "speed" then
			BaseService.ApplyUpgrade(st, u)
		end
	end
	if st.LaserMult > 1 then
		for _, conv in ipairs(st.Conveyors) do
			conv.Beam.Size = Vector3.new(0.35 + st.LaserMult * 0.15, 5, 0.35 + st.LaserMult * 0.15)
		end
	end
	-- косметика
	for itemId in pairs(data.ShopItems) do
		applyShopItem(st, itemId)
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
	st.Workers = {}
	st.TerminalLabel = nil
	st.CollectPad = nil
	if st.ButtonPad then
		st.ButtonPad:Destroy()
		st.ButtonPad = nil
	end
	st.LaserMult = 1
	st.SpeedMult = 1
	st.Drills = 0
end

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

-- ============================ ЖИЗНЕННЫЙ ЦИКЛ ============================

local function onWorkAbort(player: Player, stonePart: BasePart)
	local st = playerBase[player]
	if not st then return end
	for _, conv in ipairs(st.Conveyors) do
		for _, stone in ipairs(conv.Stones) do
			if stone.Part == stonePart and stone.ClaimedBy == player then
				stone.ClaimedBy = nil
				stone.Progress = 0
				return
			end
		end
	end
end

local function onTeleportHome(player: Player)
	local st = playerBase[player]
	if not st then return end
	local spawn = st.Folder:FindFirstChild("Spawn")
	local char = player.Character
	if spawn and char then
		char:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	end
end

function BaseService.Init(c)
	ctx = c
	ctx.Remotes.WorkTick.OnServerEvent:Connect(onWorkTick)
	ctx.Remotes.WorkAbort.OnServerEvent:Connect(onWorkAbort)
	ctx.Remotes.TeleportHome.OnServerEvent:Connect(onTeleportHome)
	ctx.Remotes.BuyShopItem.OnServerEvent:Connect(onBuyShopItem)
end

function BaseService.Start()
	for i, pos in ipairs(ctx.Config.Plots) do
		table.insert(bases, buildPlot(i, pos))
	end
	buildMoonShop()

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
