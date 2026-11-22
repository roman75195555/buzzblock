--!strict
--==============================================================================
-- BuzzBlocks :: ShopUI (клиент)
-- Магазин деталей: вкладки категорий, карточки товаров, покупка.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local ShopUI = {}

local function corner(inst: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
	return c
end

local function statText(category: string, part): string
	if category == "Hull" then return "Прочность: " .. part.HP end
	if category == "Engine" then return "Скорость: " .. part.Speed end
	if category == "Propeller" then return "Ускорение: ×" .. part.Boost end
	if category == "Tank" then return "Топливо: " .. part.Fuel end
	if category == "Wheel" then return "Поворот: ×" .. part.Turn end
	return ""
end

function ShopUI.Init(deps)
	local remotes = deps.Remotes

	local gui = Instance.new("ScreenGui")
	gui.Name = "BuzzShop"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 640, 0, 470)
	frame.Position = UDim2.new(0.5, -320, 0.5, -235)
	frame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	corner(frame, 16)
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 50)
	title.Position = UDim2.new(0, 16, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "🛒 Магазин деталей"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 30
	title.TextColor3 = Color3.fromRGB(255, 210, 60)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(0, 44, 0, 44)
	close.Position = UDim2.new(1, -52, 0, 6)
	close.BackgroundColor3 = Color3.fromRGB(226, 66, 64)
	close.Text = "✖"
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 22
	close.TextColor3 = Color3.new(1, 1, 1)
	corner(close)
	close.Parent = frame
	close.MouseButton1Click:Connect(function() gui.Enabled = false end)

	-- Вкладки ----------------------------------------------------------------------
	local tabs = Instance.new("Frame")
	tabs.Size = UDim2.new(1, -32, 0, 44)
	tabs.Position = UDim2.new(0, 16, 0, 56)
	tabs.BackgroundTransparency = 1
	tabs.Parent = frame
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabs

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -32, 1, -116)
	list.Position = UDim2.new(0, 16, 0, 108)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.Parent = list

	local currentCategory = "Hull"
	local currentState = nil

	local function refresh()
		if not currentState then return end
		for _, ch in ipairs(list:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		for _, tabBtn in ipairs(tabs:GetChildren()) do
			if tabBtn:IsA("TextButton") then
				local sel = tabBtn:GetAttribute("Category") == currentCategory
				tabBtn.BackgroundColor3 = sel and Color3.fromRGB(255, 210, 60) or Color3.fromRGB(60, 66, 80)
				tabBtn.TextColor3 = sel and Color3.fromRGB(30, 30, 35) or Color3.new(1, 1, 1)
			end
		end

		local parts = Config.Parts[currentCategory]
		local owned = currentState.OwnedParts[currentCategory] or {}
		for _, part in ipairs(parts) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -6, 0, 74)
			card.BackgroundColor3 = Color3.fromRGB(45, 52, 66)
			corner(card, 12)
			card.Parent = list

			local isOwned = owned[part.Tier] == true
			local prevOwned = part.Tier == 1 or owned[part.Tier - 1] == true
			local affordable = currentState.Money >= part.Cost

			local dot = Instance.new("Frame")
			dot.Size = UDim2.new(0, 52, 0, 52)
			dot.Position = UDim2.new(0, 12, 0.5, -26)
			dot.BackgroundColor3 = isOwned and Color3.fromRGB(90, 220, 100) or Color3.fromRGB(90, 96, 112)
			corner(dot, 26)
			dot.Parent = card
			local tierLbl = Instance.new("TextLabel")
			tierLbl.Size = UDim2.new(1, 0, 1, 0)
			tierLbl.BackgroundTransparency = 1
			tierLbl.Text = "T" .. part.Tier
			tierLbl.Font = Enum.Font.FredokaOne
			tierLbl.TextSize = 24
			tierLbl.TextColor3 = Color3.fromRGB(30, 30, 35)
			tierLbl.Parent = dot

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, -240, 0, 34)
			nameLbl.Position = UDim2.new(0, 76, 0, 6)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = part.Name
			nameLbl.Font = Enum.Font.FredokaOne
			nameLbl.TextSize = 21
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Parent = card

			local statLbl = Instance.new("TextLabel")
			statLbl.Size = UDim2.new(1, -240, 0, 26)
			statLbl.Position = UDim2.new(0, 76, 0, 40)
			statLbl.BackgroundTransparency = 1
			statLbl.Text = statText(currentCategory, part)
			statLbl.Font = Enum.Font.Gotham
			statLbl.TextSize = 16
			statLbl.TextColor3 = Color3.fromRGB(170, 180, 195)
			statLbl.TextXAlignment = Enum.TextXAlignment.Left
			statLbl.Parent = card

			local buyBtn = Instance.new("TextButton")
			buyBtn.Size = UDim2.new(0, 140, 0, 48)
			buyBtn.Position = UDim2.new(1, -152, 0.5, -24)
			buyBtn.Font = Enum.Font.FredokaOne
			buyBtn.TextSize = 20
			corner(buyBtn)
			buyBtn.Parent = card

			if isOwned then
				buyBtn.Text = "✔ Куплено"
				buyBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 80)
				buyBtn.TextColor3 = Color3.new(1, 1, 1)
				buyBtn.AutoButtonColor = false
			elseif not prevOwned then
				buyBtn.Text = "🔒 T" .. (part.Tier - 1)
				buyBtn.BackgroundColor3 = Color3.fromRGB(80, 84, 94)
				buyBtn.TextColor3 = Color3.fromRGB(170, 174, 184)
				buyBtn.AutoButtonColor = false
			else
				buyBtn.Text = "🪙 " .. part.Cost
				buyBtn.BackgroundColor3 = affordable and Color3.fromRGB(245, 150, 50) or Color3.fromRGB(150, 90, 50)
				buyBtn.TextColor3 = Color3.new(1, 1, 1)
				buyBtn.MouseButton1Click:Connect(function()
					remotes.BuyPart:FireServer(currentCategory, part.Tier)
				end)
			end
		end
	end

	for _, category in ipairs(Config.PartCategories) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 116, 1, 0)
		b.Text = Config.CategoryNames[category]
		b.Font = Enum.Font.FredokaOne
		b.TextSize = 17
		b:SetAttribute("Category", category)
		corner(b)
		b.Parent = tabs
		b.MouseButton1Click:Connect(function()
			currentCategory = category
			refresh()
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local api = {}
	function api.Open(state)
		currentState = state
		gui.Enabled = true
		refresh()
	end
	function api.Refresh(state)
		currentState = state
		if gui.Enabled then refresh() end
	end
	function api.IsOpen()
		return gui.Enabled
	end
	return api
end

return ShopUI
