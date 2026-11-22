--!strict
--==============================================================================
-- LunarBase :: HUD
-- Кредиты/терминал, панель базы (Развитие / Работники / Магазин),
-- прогресс-бар обработки камня, тосты.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local HUD = {}
local ctx

local state: any = nil
local refs: any = {}
local panelOpen = false
local activeTab = "Развитие"

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

local function refreshTop()
	if not state then return end
	refs.Money.Text = fmt(state.Money)
	refs.Terminal.Text = fmt(state.Terminal)
end

-- ============================ ПАНЕЛЬ ============================

local function rebuildPanel()
	if not panelOpen or not refs.PanelList then return end
	for _, ch in ipairs(refs.PanelList:GetChildren()) do
		if ch:IsA("Frame") then
			ch:Destroy()
		end
	end
	if not state then return end

	local function row(order: number, title: string, desc: string, right: string, rightColor: Color3, onClick: (() -> ())?)
		local f = Instance.new("Frame")
		f.Size = UDim2.new(1, -12, 0, 56)
		f.BackgroundColor3 = Color3.fromRGB(28, 31, 42)
		f.BorderSizePixel = 0
		f.LayoutOrder = order
		f.Parent = refs.PanelList
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = f
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, -140, 0, 26)
		t.Position = UDim2.new(0, 10, 0, 4)
		t.BackgroundTransparency = 1
		t.Text = title
		t.Font = Enum.Font.FredokaOne
		t.TextSize = 16
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Parent = f
		local d = Instance.new("TextLabel")
		d.Size = UDim2.new(1, -140, 0, 20)
		d.Position = UDim2.new(0, 10, 0, 30)
		d.BackgroundTransparency = 1
		d.Text = desc
		d.Font = Enum.Font.Gotham
		d.TextSize = 13
		d.TextColor3 = Color3.fromRGB(165, 170, 185)
		d.TextXAlignment = Enum.TextXAlignment.Left
		d.Parent = f
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0, 110, 0, 36)
		btn.Position = UDim2.new(1, -118, 0.5, -18)
		btn.BackgroundColor3 = rightColor
		btn.Text = right
		btn.Font = Enum.Font.FredokaOne
		btn.TextSize = 15
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.AutoButtonColor = onClick ~= nil
		btn.Parent = f
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = btn
		if onClick then
			btn.MouseButton1Click:Connect(onClick)
		end
	end

	if activeTab == "Развитие" then
		local nextFound = false
		for i, u in ipairs(Config.Upgrades) do
			local owned = state.Purchases[u.Id] == true
			if owned then
				row(i, "✅ " .. u.Name, u.Desc, "КУПЛЕНО", Color3.fromRGB(60, 64, 76), nil)
			elseif not nextFound then
				nextFound = true
				row(i, "👉 " .. u.Name, u.Desc .. " — купи кнопкой на базе", fmt(u.Cost) .. " 💰", Color3.fromRGB(255, 180, 50), nil)
			else
				row(i, "🔒 " .. u.Name, u.Desc, fmt(u.Cost) .. " 💰", Color3.fromRGB(60, 64, 76), nil)
			end
		end
	elseif activeTab == "Работники" then
		local count = 0
		for _, u in ipairs(Config.Upgrades) do
			if u.Kind == "worker" and state.Purchases[u.Id] then
				count += 1
				row(count, "🤖 Работник " .. count, "Обрабатывает камни за " .. Config.WorkerTime .. " сек", "АКТИВЕН", Color3.fromRGB(90, 180, 255), nil)
			end
		end
		if count == 0 then
			row(1, "Работников нет", "Купи первого робота во вкладке «Развитие»", "—", Color3.fromRGB(60, 64, 76), nil)
		end
	elseif activeTab == "Магазин" then
		for i, item in ipairs(Config.ShopItems) do
			local owned = state.ShopItems[item.Id] == true
			if owned then
				row(i, "🛍️ " .. item.Name, "Косметика базы", "КУПЛЕНО", Color3.fromRGB(60, 64, 76), nil)
			else
				local can = state.Money >= item.Cost
				row(i, "🛍️ " .. item.Name, "Косметика базы", fmt(item.Cost) .. " 💰", if can then Color3.fromRGB(255, 170, 60) else Color3.fromRGB(60, 64, 76), function()
					refs.Remotes.BuyShopItem:FireServer(item.Id)
				end)
			end
		end
	end
end

local function switchTab(tab: string)
	activeTab = tab
	for name, btn in pairs(refs.Tabs) do
		btn.BackgroundColor3 = if name == tab then Color3.fromRGB(80, 130, 220) else Color3.fromRGB(40, 44, 58)
	end
	rebuildPanel()
end

local function togglePanel(force: boolean?)
	panelOpen = if force ~= nil then force else not panelOpen
	refs.Panel.Visible = panelOpen
	if panelOpen then
		rebuildPanel()
	end
end
HUD.TogglePanel = togglePanel

-- ============================ ПРОГРЕСС-БАР ============================

function HUD.SetProgress(frac: number, text: string)
	refs.ProgressFrame.Visible = true
	refs.ProgressFill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
	refs.ProgressLabel.Text = text
end

function HUD.HideProgress()
	refs.ProgressFrame.Visible = false
end

-- ============================ ТОСТЫ ============================

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

-- ============================ INIT ============================

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

	-- кнопка панели
	local panelBtn = Instance.new("TextButton")
	panelBtn.Size = UDim2.new(0, 130, 0, 44)
	panelBtn.Position = UDim2.new(1, -142, 0, 10)
	panelBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 220)
	panelBtn.Text = "📋 БАЗА"
	panelBtn.Font = Enum.Font.FredokaOne
	panelBtn.TextSize = 19
	panelBtn.TextColor3 = Color3.new(1, 1, 1)
	panelBtn.Parent = screen
	local pbc = Instance.new("UICorner")
	pbc.CornerRadius = UDim.new(0, 10)
	pbc.Parent = panelBtn
	panelBtn.MouseButton1Click:Connect(function()
		togglePanel()
	end)

	-- панель
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 440, 0, 420)
	panel.Position = UDim2.new(0.5, -220, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	panel.BackgroundTransparency = 0.04
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screen
	refs.Panel = panel
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent = panel

	-- вкладки
	local tabsBar = Instance.new("Frame")
	tabsBar.Size = UDim2.new(1, -16, 0, 40)
	tabsBar.Position = UDim2.new(0, 8, 0, 8)
	tabsBar.BackgroundTransparency = 1
	tabsBar.Parent = panel
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.Parent = tabsBar
	refs.Tabs = {}
	for i, name in ipairs({ "Развитие", "Работники", "Магазин" }) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 130, 1, 0)
		b.LayoutOrder = i
		b.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
		b.Text = name
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 16
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = tabsBar
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent = b
		b.MouseButton1Click:Connect(function()
			switchTab(name)
		end)
		refs.Tabs[name] = b
	end

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -8, 1, -60)
	scroll.Position = UDim2.new(0, 4, 0, 54)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local sl = Instance.new("UIListLayout")
	sl.Padding = UDim.new(0, 6)
	sl.SortOrder = Enum.SortOrder.LayoutOrder
	sl.Parent = scroll
	refs.PanelList = scroll

	-- прогресс-бар обработки
	local pf = Instance.new("Frame")
	pf.Size = UDim2.new(0, 320, 0, 54)
	pf.Position = UDim2.new(0.5, -160, 1, -120)
	pf.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	pf.BackgroundTransparency = 0.1
	pf.Visible = false
	pf.Parent = screen
	local pfc = Instance.new("UICorner")
	pfc.CornerRadius = UDim.new(0, 10)
	pfc.Parent = pf
	refs.ProgressFrame = pf
	local plabel = Instance.new("TextLabel")
	plabel.Size = UDim2.new(1, 0, 0, 22)
	plabel.BackgroundTransparency = 1
	plabel.Text = "Очистка…"
	plabel.Font = Enum.Font.FredokaOne
	plabel.TextSize = 15
	plabel.TextColor3 = Color3.new(1, 1, 1)
	plabel.Parent = pf
	refs.ProgressLabel = plabel
	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 14)
	barBg.Position = UDim2.new(0, 10, 0, 30)
	barBg.BackgroundColor3 = Color3.fromRGB(50, 54, 66)
	barBg.BorderSizePixel = 0
	barBg.Parent = pf
	local bbgc = Instance.new("UICorner")
	bbgc.CornerRadius = UDim.new(0, 7)
	bbgc.Parent = barBg
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(140, 220, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 7)
	fc.Parent = fill
	refs.ProgressFill = fill

	-- тосты
	local toasts = Instance.new("Frame")
	toasts.Size = UDim2.new(0, 420, 0, 300)
	toasts.Position = UDim2.new(0.5, -210, 0.2, 0)
	toasts.BackgroundTransparency = 1
	toasts.Parent = screen
	local ttl = Instance.new("UIListLayout")
	ttl.Padding = UDim.new(0, 6)
	ttl.Parent = toasts
	refs.Toasts = toasts

	-- remotes
	local remotes = ReplicatedStorage:WaitForChild("LunarRemotes")
	refs.Remotes = remotes
	remotes.StateChanged.OnClientEvent:Connect(function(data)
		state = data
		refreshTop()
		rebuildPanel()
	end)
	remotes.Notify.OnClientEvent:Connect(toast)
	remotes.OpenShop.OnClientEvent:Connect(function()
		switchTab("Магазин")
		togglePanel(true)
	end)

	task.spawn(function()
		state = remotes.GetState:InvokeServer()
		refreshTop()
	end)

	switchTab("Развитие")
end

return HUD
