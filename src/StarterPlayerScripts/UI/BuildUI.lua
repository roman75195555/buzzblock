--!strict
--==============================================================================
-- BuzzBlocks :: BuildUI (клиент)
-- Верфь: выбор купленных деталей по категориям и сборка подлодки.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local BuildUI = {}

local function corner(inst: GuiObject, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = inst
	return c
end

function BuildUI.Init(deps)
	local remotes = deps.Remotes

	local gui = Instance.new("ScreenGui")
	gui.Name = "BuzzBuild"
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 520, 0, 500)
	frame.Position = UDim2.new(0.5, -260, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	corner(frame, 16)
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 50)
	title.Position = UDim2.new(0, 16, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "🔧 Верфь — сборка подлодки"
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 26
	title.TextColor3 = Color3.fromRGB(90, 210, 230)
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

	local rowsFrame = Instance.new("Frame")
	rowsFrame.Size = UDim2.new(1, -32, 1, -140)
	rowsFrame.Position = UDim2.new(0, 16, 0, 60)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = frame
	local rowsLayout = Instance.new("UIListLayout")
	rowsLayout.Padding = UDim.new(0, 8)
	rowsLayout.Parent = rowsFrame

	local buildBtn = Instance.new("TextButton")
	buildBtn.Size = UDim2.new(1, -32, 0, 60)
	buildBtn.Position = UDim2.new(0, 16, 1, -72)
	buildBtn.BackgroundColor3 = Color3.fromRGB(90, 220, 100)
	buildBtn.Text = "🔨 Собрать подлодку!"
	buildBtn.Font = Enum.Font.FredokaOne
	buildBtn.TextSize = 26
	buildBtn.TextColor3 = Color3.fromRGB(20, 40, 25)
	corner(buildBtn, 14)
	buildBtn.Parent = frame
	buildBtn.MouseButton1Click:Connect(function()
		remotes.BuildSub:FireServer()
		gui.Enabled = false
	end)

	local currentState = nil
	local rows = {}

	for _, category in ipairs(Config.PartCategories) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(45, 52, 66)
		corner(row, 12)
		row.Parent = rowsFrame

		local catLbl = Instance.new("TextLabel")
		catLbl.Size = UDim2.new(0, 150, 1, 0)
		catLbl.Position = UDim2.new(0, 12, 0, 0)
		catLbl.BackgroundTransparency = 1
		catLbl.Text = Config.CategoryNames[category]
		catLbl.Font = Enum.Font.FredokaOne
		catLbl.TextSize = 19
		catLbl.TextColor3 = Color3.fromRGB(255, 210, 60)
		catLbl.TextXAlignment = Enum.TextXAlignment.Left
		catLbl.Parent = row

		local partLbl = Instance.new("TextLabel")
		partLbl.Size = UDim2.new(1, -260, 1, 0)
		partLbl.Position = UDim2.new(0, 160, 0, 0)
		partLbl.BackgroundTransparency = 1
		partLbl.Text = "—"
		partLbl.Font = Enum.Font.GothamBold
		partLbl.TextSize = 17
		partLbl.TextColor3 = Color3.new(1, 1, 1)
		partLbl.Parent = row

		local function navBtn(text: string, xOff: number, delta: number)
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(0, 44, 0, 44)
			b.Position = UDim2.new(1, xOff, 0.5, -22)
			b.BackgroundColor3 = Color3.fromRGB(66, 140, 235)
			b.Text = text
			b.Font = Enum.Font.FredokaOne
			b.TextSize = 22
			b.TextColor3 = Color3.new(1, 1, 1)
			corner(b)
			b.Parent = row
			b.MouseButton1Click:Connect(function()
				local state = currentState
				if not state then return end
				local owned = state.OwnedParts[category] or {}
				local cur = state.Equipped[category] or 1
				-- собрать отсортированные купленные тиры
				local tiers = {}
				for t in pairs(owned) do table.insert(tiers, tonumber(t) or t) end
				table.sort(tiers)
				if #tiers == 0 then return end
				local idx = table.find(tiers, cur) or 1
				idx = ((idx - 1 + delta) % #tiers) + 1
				remotes.EquipPart:FireServer(category, tiers[idx])
			end)
			return b
		end
		navBtn("◀", -100, -1)
		navBtn("▶", -52, 1)

		rows[category] = partLbl
	end

	local function refresh()
		if not currentState then return end
		for category, lbl in pairs(rows) do
			local tier = currentState.Equipped[category] or 1
			local part = Config.GetPart(category, tier)
			lbl.Text = part and (part.Name .. "  (T" .. tier .. ")") or "—"
		end
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
	return api
end

return BuildUI
