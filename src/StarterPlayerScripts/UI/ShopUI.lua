--!strict
--==============================================================================
-- SeedRush :: ShopUI
-- Магазин: улучшения дорожки, тренажёра силы, следы (+скорость).
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local ShopUI = {}
local ctx
local state: any = nil
local frame: Frame? = nil
local listFrame: Frame? = nil

local function fmt(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function buy(kind: string)
	local remotes = ReplicatedStorage:WaitForChild("RushRemotes")
	remotes.BuyUpgrade:FireServer(kind)
end

local function itemRow(parent: Instance, order: number, title: string, desc: string, btnText: string, btnColor: Color3, kind: string?, enabled: boolean)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -16, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(30, 33, 44)
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = row

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -150, 0, 30)
	t.Position = UDim2.new(0, 12, 0, 4)
	t.BackgroundTransparency = 1
	t.Text = title
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 18
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = row

	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(1, -150, 0, 24)
	d.Position = UDim2.new(0, 12, 0, 34)
	d.BackgroundTransparency = 1
	d.Text = desc
	d.Font = Enum.Font.Gotham
	d.TextSize = 14
	d.TextColor3 = Color3.fromRGB(170, 175, 190)
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 120, 0, 42)
	btn.Position = UDim2.new(1, -130, 0.5, -21)
	btn.BackgroundColor3 = if enabled then btnColor else Color3.fromRGB(70, 72, 80)
	btn.Text = btnText
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 17
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = enabled
	btn.Parent = row
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 10)
	bc.Parent = btn
	if enabled and kind then
		btn.MouseButton1Click:Connect(function()
			buy(kind)
		end)
	end
end

local function rebuild()
	if not listFrame then return end
	for _, ch in ipairs(listFrame:GetChildren()) do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	if not state then return end

	local order = 0
	-- Дорожка
	order += 1
	local tTier = state.TreadmillTier
	if tTier < Config.MaxTier then
		local cost = Config.UpgradeCost(tTier)
		itemRow(listFrame, order,
			string.format("🏃 Беговая дорожка · ур. %d → %d", tTier, tTier + 1),
			string.format("Скорость прокачки: %.1f → %.1f ⚡/с", Config.SpeedRate(tTier), Config.SpeedRate(tTier + 1)),
			fmt(cost) .. " 💰", Color3.fromRGB(70, 160, 255), "treadmill", state.Money >= cost)
	else
		itemRow(listFrame, order, "🏃 Беговая дорожка · МАКС", "Скорость прокачки: " .. Config.SpeedRate(tTier) .. " ⚡/с", "MAX", Color3.fromRGB(70, 72, 80), nil, false)
	end

	-- Тренажёр
	order += 1
	local sTier = state.TrainerTier
	if sTier < Config.MaxTier then
		local cost = Config.UpgradeCost(sTier)
		itemRow(listFrame, order,
			string.format("🏋️ Тренажёр силы · ур. %d → %d", sTier, sTier + 1),
			string.format("Сила за подъём: %d → %d 💪", Config.StrengthPerRep(sTier), Config.StrengthPerRep(sTier + 1)),
			fmt(cost) .. " 💰", Color3.fromRGB(255, 110, 110), "trainer", state.Money >= cost)
	else
		itemRow(listFrame, order, "🏋️ Тренажёр силы · МАКС", "Сила за подъём: " .. Config.StrengthPerRep(sTier) .. " 💪", "MAX", Color3.fromRGB(70, 72, 80), nil, false)
	end

	-- Следы
	for id, trail in ipairs(Config.Trails) do
		order += 1
		local owned = state.Trails[tostring(id)] == true
		if owned then
			itemRow(listFrame, order, "✨ " .. trail.Name, "+" .. trail.Bonus .. " к скорости бега", "КУПЛЕНО", Color3.fromRGB(70, 72, 80), nil, false)
		else
			itemRow(listFrame, order, "✨ " .. trail.Name, "+" .. trail.Bonus .. " к скорости бега", fmt(trail.Cost) .. " 💰", trail.Color, "trail:" .. id, state.Money >= trail.Cost)
		end
	end
end

local function toggle()
	if not frame then return end
	frame.Visible = not frame.Visible
	if frame.Visible then
		rebuild()
	end
end

function ShopUI.Init(c)
	ctx = c
	local player = Players.LocalPlayer
	local gui = player:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "RushShop"
	screen.ResetOnSpawn = false
	screen.Parent = gui

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 460, 0, 400)
	f.Position = UDim2.new(0.5, -230, 0.5, -200)
	f.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = screen
	frame = f
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 14)
	fc.Parent = f

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 44)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🛒 МАГАЗИН"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(255, 190, 60)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = f

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Position = UDim2.new(1, -48, 0, 4)
	close.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	close.Text = "✕"
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = f
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent = close
	close.MouseButton1Click:Connect(toggle)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -60)
	scroll.Position = UDim2.new(0, 8, 0, 52)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = f
	listFrame = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	-- обновления состояния
	local remotes = ReplicatedStorage:WaitForChild("RushRemotes")
	remotes.StateChanged.OnClientEvent:Connect(function(data)
		state = data
		if frame and frame.Visible then
			rebuild()
		end
	end)
	task.spawn(function()
		state = remotes.GetState:InvokeServer()
		rebuild()
	end)
end

ShopUI.Toggle = toggle

return ShopUI
