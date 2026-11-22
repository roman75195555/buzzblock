--!strict
--==============================================================================
-- LunarBase :: ClientMain
-- HUD + мини-игра обработки камня на весь экран (E у камня → чистим мышкой).
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterPlayerScripts = script.Parent
local HUD = require(StarterPlayerScripts:WaitForChild("UI"):WaitForChild("HUD"))

local ctx = {}
HUD.Init(ctx)

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("LunarRemotes")

local CLEAN_TIME = 1.5
local SAW_TIME = 2
local DIRT_COLS = 8
local DIRT_ROWS = 6

-- Состояние мини-игры --------------------------------------------------------------
local mg: any = nil -- {Frame, Viewport, Stone(Clone), DirtCells{}, Stage, Progress, Acc, StoneRef, Angle}

local function closeMinigame(abort: boolean)
	if not mg then return end
	if abort and mg.StoneRef then
		remotes.WorkAbort:FireServer(mg.StoneRef)
	end
	mg.Frame:Destroy()
	mg = nil
end

local function clearDirt(frac: number)
	local total = #mg.DirtCells
	local toHide = math.floor(frac * total)
	for i = 1, toHide do
		mg.DirtCells[i].Visible = false
	end
end

local function openMinigame(stone: BasePart, stage: number)
	closeMinigame(false)

	local frame = Instance.new("Frame")
	frame.Name = "StoneMinigame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Active = true
	frame.Parent = gui

	-- заголовок
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0.08, 0)
	title.BackgroundTransparency = 1
	title.Text = "🧹 ОЧИСТКА КАМНЯ"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextStrokeTransparency = 0.6
	title.Parent = frame

	-- подсказка
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.Position = UDim2.new(0, 0, 0.16, 0)
	hint.BackgroundTransparency = 1
	hint.Text = "Води мышкой по камню, чтобы смыть лунную пыль!"
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 20
	hint.TextColor3 = Color3.fromRGB(200, 205, 220)
	hint.Parent = frame

	-- вьюпорт с камнем
	local vp = Instance.new("ViewportFrame")
	vp.Size = UDim2.new(0, 420, 0, 420)
	vp.Position = UDim2.new(0.5, -210, 0.5, -210)
	vp.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	vp.BackgroundTransparency = 0.3
	vp.Parent = frame
	local vpc = Instance.new("UICorner")
	vpc.CornerRadius = UDim.new(0, 20)
	vpc.Parent = vp

	local world = Instance.new("WorldModel")
	world.Parent = vp
	local clone = stone:Clone()
	clone.Anchored = true
	clone.CFrame = CFrame.new(0, 0, 0)
	clone.Parent = world
	-- подставка
	local stand = Instance.new("Part")
	stand.Size = Vector3.new(4, 0.5, 4)
	stand.CFrame = CFrame.new(0, -1.6, 0)
	stand.Color = Color3.fromRGB(50, 54, 66)
	stand.Material = Enum.Material.Metal
	stand.Anchored = true
	stand.Parent = world

	local cam = Instance.new("Camera")
	cam.CFrame = CFrame.new(Vector3.new(0, 2.2, 4.5), Vector3.new(0, -0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam

	-- сетка грязи поверх камня
	local dirtContainer = Instance.new("Frame")
	dirtContainer.Size = UDim2.fromScale(1, 1)
	dirtContainer.BackgroundTransparency = 1
	dirtContainer.Parent = vp
	local cells = {}
	local cw = 420 / DIRT_COLS
	local ch = 420 / DIRT_ROWS
	for r = 0, DIRT_ROWS - 1 do
		for col = 0, DIRT_COLS - 1 do
			local cell = Instance.new("Frame")
			cell.Size = UDim2.new(0, cw - 2, 0, ch - 2)
			cell.Position = UDim2.new(0, col * cw + 1, 0, r * ch + 1)
			cell.BackgroundColor3 = Color3.fromRGB(70, 62, 52)
			cell.BackgroundTransparency = 0.35
			cell.BorderSizePixel = 0
			cell.Parent = dirtContainer
			table.insert(cells, cell)
		end
	end

	-- прогресс-бар
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(0, 420, 0, 22)
	barBg.Position = UDim2.new(0.5, -210, 0.5, 230)
	barBg.BackgroundColor3 = Color3.fromRGB(40, 44, 56)
	barBg.BorderSizePixel = 0
	barBg.Parent = frame
	local bbc = Instance.new("UICorner")
	bbc.CornerRadius = UDim.new(0, 11)
	bbc.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(140, 220, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fcc = Instance.new("UICorner")
	fcc.CornerRadius = UDim.new(0, 11)
	fcc.Parent = fill

	-- кнопка выхода
	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 120, 0, 44)
	close.Position = UDim2.new(1, -140, 0, 20)
	close.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	close.Text = "✕ Выйти"
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = frame
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		closeMinigame(true)
	end)

	mg = {
		Frame = frame,
		Viewport = vp,
		Clone = clone,
		DirtCells = cells,
		Stage = stage,
		Progress = 0,
		Acc = 0,
		StoneRef = stone,
		Title = title,
		Hint = hint,
		Fill = fill,
	}
	-- если начали со 2-го этапа — грязи уже нет
	if stage == 2 then
		clearDirt(1)
		title.Text = "⚙️ ОПИЛИВАНИЕ"
		hint.Text = "Води мышкой по камню, чтобы отшлифовать его!"
	end
end

-- Серверные события --------------------------------------------------------------------
remotes.WorkBegin.OnClientEvent:Connect(function(stone: BasePart, stage: number)
	openMinigame(stone, stage)
end)

remotes.WorkStage.OnClientEvent:Connect(function(stone: BasePart, stage: number)
	if mg and mg.StoneRef == stone then
		if stage == 0 or stage == 3 then
			closeMinigame(false)
		elseif stage == 2 then
			mg.Stage = 2
			mg.Progress = 0
			mg.Acc = 0
			clearDirt(1)
			mg.Clone.Color = Color3.fromRGB(160, 160, 170)
			mg.Title.Text = "⚙️ ОПИЛИВАНИЕ"
			mg.Hint.Text = "Води мышкой по камню, чтобы отшлифовать его!"
			mg.Fill.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
		end
	end
end)

-- Цикл мини-игры -------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not mg then return end
	if not mg.StoneRef.Parent then
		closeMinigame(false)
		return
	end
	-- вращение камня
	mg.Clone.CFrame = mg.Clone.CFrame * CFrame.Angles(0, dt * 0.8, 0)

	-- мышь над вьюпортом?
	local pos = UserInputService:GetMouseLocation()
	local vpPos = mg.Viewport.AbsolutePosition
	local vpSize = mg.Viewport.AbsoluteSize
	local inside = pos.X >= vpPos.X and pos.X <= vpPos.X + vpSize.X
		and pos.Y >= vpPos.Y and pos.Y <= vpPos.Y + vpSize.Y

	if inside then
		mg.Progress += dt
		mg.Acc += dt
		if mg.Acc >= 0.12 then
			remotes.WorkTick:FireServer(mg.StoneRef, mg.Acc)
			mg.Acc = 0
		end
	end
	local need = if mg.Stage == 1 then CLEAN_TIME else SAW_TIME
	local frac = math.clamp(mg.Progress / need, 0, 1)
	mg.Fill.Size = UDim2.new(frac, 0, 1, 0)
	if mg.Stage == 1 then
		clearDirt(frac)
	end
end)

print("[LunarBase] Клиент запущен")
