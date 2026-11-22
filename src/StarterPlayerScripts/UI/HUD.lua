--!strict
--==============================================================================
-- SeedRush :: HUD
-- Верхняя панель: монеты, скорость, сила. Семена. Тосты. Кнопка магазина.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local HUD = {}
local ctx

local state: any = nil
local refs: any = {}

local function fmt(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function makeLabel(parent: Instance, text: string, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 20
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.6
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function statChip(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(0, 150, 0, 44)
	chip.BackgroundColor3 = Color3.fromRGB(24, 26, 34)
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	chip.LayoutOrder = order
	chip.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = chip
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = chip

	local iconL = Instance.new("TextLabel")
	iconL.Size = UDim2.new(0, 36, 1, 0)
	iconL.Position = UDim2.new(0, 6, 0, 0)
	iconL.BackgroundTransparency = 1
	iconL.Text = icon
	iconL.TextSize = 24
	iconL.Font = Enum.Font.FredokaOne
	iconL.TextColor3 = color
	iconL.Parent = chip

	local value = makeLabel(chip, "0", UDim2.new(1, -46, 1, 0))
	value.Position = UDim2.new(0, 44, 0, 0)
	value.TextSize = 22
	return value
end

local function refresh()
	if not state then return end
	refs.Money.Text = fmt(state.Money)
	refs.Speed.Text = fmt(state.Speed)
	refs.Strength.Text = fmt(state.Strength)

	-- семена
	local parts = {}
	for idStr, count in pairs(state.Seeds) do
		if count > 0 then
			local z = Config.Zones[tonumber(idStr)]
			if z then
				table.insert(parts, string.format("🥚%s ×%d", z.Name, count))
			end
		end
	end
	refs.Seeds.Text = if #parts > 0 then table.concat(parts, "  ") else "Семян нет — укради у босса!"
end

local function toast(text: string, colorName: string)
	local colors = {
		info = Color3.fromRGB(90, 160, 255),
		success = Color3.fromRGB(90, 220, 120),
		error = Color3.fromRGB(255, 90, 90),
	}
	local color = colors[colorName] or colors.info

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0, 420, 0, 44)
	t.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	t.BackgroundTransparency = 0.1
	t.Text = text
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 18
	t.TextColor3 = color
	t.TextWrapped = true
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = t
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 2
	s.Parent = t
	t.Parent = refs.Toasts

	task.delay(3.5, function()
		t:Destroy()
	end)
end

function HUD.Init(c)
	ctx = c
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "RushHUD"
	screen.ResetOnSpawn = false
	screen.Parent = gui

	-- верхняя панель
	local top = Instance.new("Frame")
	top.Size = UDim2.new(0, 480, 0, 44)
	top.Position = UDim2.new(0.5, -240, 0, 10)
	top.BackgroundTransparency = 1
	top.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = top

	refs.Money = statChip(top, 1, "💰", Color3.fromRGB(255, 210, 70))
	refs.Speed = statChip(top, 2, "⚡", Color3.fromRGB(90, 200, 255))
	refs.Strength = statChip(top, 3, "💪", Color3.fromRGB(255, 110, 110))

	-- семена под панелью
	local seeds = makeLabel(screen, "", UDim2.new(0, 480, 0, 26))
	seeds.Position = UDim2.new(0.5, -240, 0, 58)
	seeds.TextSize = 16
	seeds.TextXAlignment = Enum.TextXAlignment.Center
	refs.Seeds = seeds

	-- кнопка магазина
	local shopBtn = Instance.new("TextButton")
	shopBtn.Size = UDim2.new(0, 150, 0, 48)
	shopBtn.Position = UDim2.new(1, -162, 0, 10)
	shopBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
	shopBtn.Text = "🛒 МАГАЗИН"
	shopBtn.Font = Enum.Font.FredokaOne
	shopBtn.TextSize = 20
	shopBtn.TextColor3 = Color3.fromRGB(40, 25, 5)
	shopBtn.Parent = screen
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 12)
	sc.Parent = shopBtn
	refs.ShopButton = shopBtn

	-- тосты
	local toasts = Instance.new("Frame")
	toasts.Size = UDim2.new(0, 420, 0, 300)
	toasts.Position = UDim2.new(0.5, -210, 0.2, 0)
	toasts.BackgroundTransparency = 1
	toasts.Parent = screen
	local tl = Instance.new("UIListLayout")
	tl.VerticalAlignment = Enum.VerticalAlignment.Top
	tl.Padding = UDim.new(0, 6)
	tl.Parent = toasts
	refs.Toasts = toasts

	-- remotes
	local remotes = ReplicatedStorage:WaitForChild("RushRemotes")
	remotes.StateChanged.OnClientEvent:Connect(function(data)
		state = data
		ctx.State = data
		refresh()
	end)
	remotes.Notify.OnClientEvent:Connect(toast)

	-- первичное состояние
	task.spawn(function()
		local data = remotes.GetState:InvokeServer()
		state = data
		ctx.State = data
		refresh()
	end)
end

function HUD.GetState()
	return state
end

return HUD
