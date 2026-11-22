--!strict
--==============================================================================
-- LunarBase :: HUD
-- Верхняя панель: кредиты и сумма на терминале. Тосты.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HUD = {}
local ctx

local state: any = nil
local refs: any = {}

local function fmt(n: number): string
	n = math.floor(n)
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

local function chip(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 170, 0, 46)
	f.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.LayoutOrder = order
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = 2
	s.Parent = f

	local iconL = Instance.new("TextLabel")
	iconL.Size = UDim2.new(0, 38, 1, 0)
	iconL.Position = UDim2.new(0, 6, 0, 0)
	iconL.BackgroundTransparency = 1
	iconL.Text = icon
	iconL.TextSize = 24
	iconL.Font = Enum.Font.FredokaOne
	iconL.TextColor3 = color
	iconL.Parent = f

	local value = Instance.new("TextLabel")
	value.Size = UDim2.new(1, -48, 1, 0)
	value.Position = UDim2.new(0, 46, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "0"
	value.Font = Enum.Font.FredokaOne
	value.TextSize = 22
	value.TextColor3 = Color3.new(1, 1, 1)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = f
	return value
end

local function refresh()
	if not state then return end
	refs.Money.Text = fmt(state.Money)
	refs.Terminal.Text = fmt(state.Terminal)
end

local function toast(text: string, colorName: string)
	local colors = {
		info = Color3.fromRGB(120, 180, 255),
		success = Color3.fromRGB(120, 255, 160),
		error = Color3.fromRGB(255, 110, 110),
	}
	local color = colors[colorName] or colors.info

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(0, 420, 0, 44)
	t.BackgroundColor3 = Color3.fromRGB(15, 17, 24)
	t.BackgroundTransparency = 0.08
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
	screen.Name = "LunarHUD"
	screen.ResetOnSpawn = false
	screen.Parent = gui

	local top = Instance.new("Frame")
	top.Size = UDim2.new(0, 360, 0, 46)
	top.Position = UDim2.new(0.5, -180, 0, 10)
	top.BackgroundTransparency = 1
	top.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = top

	refs.Money = chip(top, 1, "💰", Color3.fromRGB(255, 210, 70))
	refs.Terminal = chip(top, 2, "🖥️", Color3.fromRGB(120, 255, 160))

	-- подсказка
	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 460, 0, 24)
	hint.Position = UDim2.new(0.5, -230, 0, 62)
	hint.BackgroundTransparency = 1
	hint.Text = "Камни → лазер → терминал. Встань на зелёную площадку, чтобы забрать кредиты!"
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(190, 195, 210)
	hint.TextStrokeTransparency = 0.7
	hint.Parent = screen
	task.delay(12, function()
		hint:Destroy()
	end)

	local toasts = Instance.new("Frame")
	toasts.Size = UDim2.new(0, 420, 0, 300)
	toasts.Position = UDim2.new(0.5, -210, 0.2, 0)
	toasts.BackgroundTransparency = 1
	toasts.Parent = screen
	local tl = Instance.new("UIListLayout")
	tl.Padding = UDim.new(0, 6)
	tl.Parent = toasts
	refs.Toasts = toasts

	local remotes = ReplicatedStorage:WaitForChild("LunarRemotes")
	remotes.StateChanged.OnClientEvent:Connect(function(data)
		state = data
		refresh()
	end)
	remotes.Notify.OnClientEvent:Connect(toast)

	task.spawn(function()
		state = remotes.GetState:InvokeServer()
		refresh()
	end)
end

return HUD
