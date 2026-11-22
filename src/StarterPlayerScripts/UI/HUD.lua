--!strict
--==============================================================================
-- BuzzBlocks :: HUD (клиент)
-- Монеты, семена, пчёлы, кнопки, тосты, выбор семени, топливо, кнопки всплытия.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local HUD = {}

local COLORS = {
	Green  = Color3.fromRGB(90, 220, 100),
	Red    = Color3.fromRGB(255, 100, 100),
	Yellow = Color3.fromRGB(255, 220, 90),
	White  = Color3.fromRGB(255, 255, 255),
}

local function corner(inst: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
	return c
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number?)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.FredokaOne
	l.TextSize = textSize or 20
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 20
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeTransparency = 0.6
	b.AutoButtonColor = true
	corner(b)
	b.Parent = parent
	return b
end

function HUD.Init(deps)
	local remotes = deps.Remotes
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuzzHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	-- Верхняя панель -------------------------------------------------------------
	local top = Instance.new("Frame")
	top.Size = UDim2.new(0, 430, 0, 52)
	top.Position = UDim2.new(0, 12, 0, 12)
	top.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	top.BackgroundTransparency = 0.25
	corner(top)
	top.Parent = gui

	local moneyLabel = label(top, "🪙 0", UDim2.new(0.4, 0, 1, 0), UDim2.new(0, 14, 0, 0), 26)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	local seedsLabel = label(top, "🌱 0", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.42, 0, 0, 0), 26)
	local beesLabel = label(top, "🐝 0", UDim2.new(0.28, 0, 1, 0), UDim2.new(0.72, 0, 0, 0), 26)

	-- Кнопки справа --------------------------------------------------------------
	local shopBtn = button(gui, "🛒 Магазин", UDim2.new(0, 170, 0, 56), UDim2.new(1, -186, 0, 12), Color3.fromRGB(245, 150, 50))
	local buildBtn = button(gui, "🔧 Верфь", UDim2.new(0, 170, 0, 56), UDim2.new(1, -186, 0, 76), Color3.fromRGB(66, 140, 235))
	shopBtn.MouseButton1Click:Connect(function() deps.OnShopButton() end)
	buildBtn.MouseButton1Click:Connect(function() deps.OnBuildButton() end)

	-- Тост ------------------------------------------------------------------------
	local toast = label(gui, "", UDim2.new(0, 520, 0, 46), UDim2.new(0.5, -260, 1, -140), 22)
	toast.BackgroundTransparency = 0.25
	toast.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	corner(toast)
	toast.Visible = false
	local toastToken = 0
	local function showToast(text: string, colorName: string?)
		toast.Text = text
		toast.TextColor3 = COLORS[colorName or "White"] or COLORS.White
		toast.Visible = true
		toastToken += 1
		local my = toastToken
		task.delay(3, function()
			if toastToken == my then toast.Visible = false end
		end)
	end

	-- Топливо ----------------------------------------------------------------------
	local fuelFrame = Instance.new("Frame")
	fuelFrame.Size = UDim2.new(0, 320, 0, 34)
	fuelFrame.Position = UDim2.new(0.5, -160, 1, -80)
	fuelFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	fuelFrame.BackgroundTransparency = 0.25
	corner(fuelFrame)
	fuelFrame.Visible = false
	fuelFrame.Parent = gui
	local fuelBar = Instance.new("Frame")
	fuelBar.Size = UDim2.new(1, -8, 1, -8)
	fuelBar.Position = UDim2.new(0, 4, 0, 4)
	fuelBar.BackgroundColor3 = Color3.fromRGB(90, 210, 230)
	corner(fuelBar, 7)
	fuelBar.Parent = fuelFrame
	local fuelText = label(fuelFrame, "⛽", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), 18)
	fuelText.ZIndex = 3
	fuelText.BackgroundTransparency = 1
	-- подсказка управления лодкой
	local driveHint = label(gui, "R — вверх · F — вниз · Space — выйти", UDim2.new(0, 340, 0, 24), UDim2.new(0.5, -170, 1, -46), 16)
	driveHint.Visible = false

	-- Кнопки всплытия/погружения ------------------------------------------------------
	local upBtn = button(gui, "▲", UDim2.new(0, 70, 0, 70), UDim2.new(1, -96, 1, -240), Color3.fromRGB(90, 210, 230))
	local downBtn = button(gui, "▼", UDim2.new(0, 70, 0, 70), UDim2.new(1, -96, 1, -160), Color3.fromRGB(24, 70, 140))
	upBtn.Visible = false
	downBtn.Visible = false
	upBtn.TextSize = 30
	downBtn.TextSize = 30

	local subControl = remotes:WaitForChild("SubControl")
	local function bindHold(btn: GuiButton, value: number)
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				subControl:FireServer(value)
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				subControl:FireServer(0)
			end
		end)
	end
	bindHold(upBtn, 1)
	bindHold(downBtn, -1)

	-- Выбор семени ----------------------------------------------------------------------
	local seedFrame = Instance.new("Frame")
	seedFrame.Size = UDim2.new(0, 380, 0, 420)
	seedFrame.Position = UDim2.new(0.5, -190, 0.5, -210)
	seedFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	seedFrame.BackgroundTransparency = 0.05
	corner(seedFrame, 14)
	seedFrame.Visible = false
	seedFrame.Parent = gui
	label(seedFrame, "🌱 Выбери семя", UDim2.new(1, 0, 0, 46), UDim2.new(0, 0, 0, 6), 26)
	local seedList = Instance.new("ScrollingFrame")
	seedList.Size = UDim2.new(1, -24, 1, -70)
	seedList.Position = UDim2.new(0, 12, 0, 56)
	seedList.BackgroundTransparency = 1
	seedList.ScrollBarThickness = 6
	seedList.CanvasSize = UDim2.new(0, 0, 0, 0)
	seedList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	seedList.Parent = seedFrame
	local seedLayout = Instance.new("UIListLayout")
	seedLayout.Padding = UDim.new(0, 8)
	seedLayout.Parent = seedList
	local seedClose = button(seedFrame, "✖", UDim2.new(0, 36, 0, 36), UDim2.new(1, -42, 0, 6), Color3.fromRGB(226, 66, 64))
	seedClose.MouseButton1Click:Connect(function() seedFrame.Visible = false end)

	local currentSlot: number? = nil
	local function showSeedPicker(state, slotIndex: number)
		currentSlot = slotIndex
		for _, ch in ipairs(seedList:GetChildren()) do
			if ch:IsA("GuiButton") then ch:Destroy() end
		end
		local hasAny = false
		for _, animal in ipairs(Config.Animals) do
			local count = state.Seeds[animal.Id] or 0
			if count > 0 then
				hasAny = true
				local b = button(seedList, "", UDim2.new(1, -6, 0, 56), UDim2.new(0, 0, 0, 0), Config.RarityColors[animal.Rarity])
				b.Text = string.format("%s  ×%d   (+%d/с)", animal.Name, count, animal.Income)
				b.TextColor3 = Color3.fromRGB(25, 25, 30)
				b.TextStrokeTransparency = 1
				b.MouseButton1Click:Connect(function()
					remotes.PlantSeed:FireServer(currentSlot, animal.Id)
					seedFrame.Visible = false
				end)
			end
		end
		if not hasAny then
			showToast("Нет семян! Сходи в подводный мир 🌊", "Yellow")
			return
		end
		seedFrame.Visible = true
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	-- API ----------------------------------------------------------------------------
	local api = {}

	function api.Toast(text: string, colorName: string?)
		showToast(text, colorName)
	end

	function api.UpdateState(state)
		local seedCount = 0
		for _, n in pairs(state.Seeds) do seedCount += n end
		seedsLabel.Text = "🌱 " .. seedCount
		beesLabel.Text = "🐝 " .. #state.Bees
	end

	function api.SetMoney(n: number)
		moneyLabel.Text = "🪙 " .. tostring(n)
	end

	function api.ShowSeedPicker(state, slotIndex: number)
		showSeedPicker(state, slotIndex)
	end

	function api.SetDriving(driving: boolean)
		fuelFrame.Visible = driving
		upBtn.Visible = driving
		downBtn.Visible = driving
		driveHint.Visible = driving
	end

	function api.UpdateFuel(fuel: number, maxFuel: number)
		local frac = maxFuel > 0 and math.clamp(fuel / maxFuel, 0, 1) or 0
		fuelBar.Size = UDim2.new(frac, -8 * frac, 1, -8)
		fuelBar.BackgroundColor3 = frac > 0.3 and Color3.fromRGB(90, 210, 230) or Color3.fromRGB(255, 100, 100)
		fuelText.Text = string.format("⛽ %d / %d", fuel, maxFuel)
	end

	return api
end

return HUD
