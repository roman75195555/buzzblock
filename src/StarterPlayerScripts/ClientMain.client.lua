--!strict
--==============================================================================
-- BuzzBlocks :: ClientMain
-- Координатор клиента: состояние профиля, UI, подводные эффекты,
-- управление подлодкой (клавиатура + сенсор), индикатор топлива.
--==============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("BuzzRemotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))

-- Состояние профиля ---------------------------------------------------------------
local state = nil

-- Подводные эффекты ------------------------------------------------------------------
local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Parent = Lighting
end
local surfaceAtmo = {
	Density = atmosphere.Density,
	Offset = atmosphere.Offset,
	Color = atmosphere.Color,
	Decay = atmosphere.Decay,
	Glare = atmosphere.Glare,
	Haze = atmosphere.Haze,
}
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "BuzzWaterCC"
cc.Enabled = false
cc.TintColor = Color3.fromRGB(90, 160, 220)
cc.Saturation = -0.15
cc.Parent = Lighting

local SURFACE_FOG = { Start = 400, End = 1500, Color = Color3.fromRGB(170, 210, 230) }
local UNDER_FOG = { Start = 10, End = 220, Color = Color3.fromRGB(15, 60, 110) }
local underwater = false

local function setUnderwater(on: boolean)
	if underwater == on then return end
	underwater = on
	if on then
		Lighting.FogStart = UNDER_FOG.Start
		Lighting.FogEnd = UNDER_FOG.End
		Lighting.FogColor = UNDER_FOG.Color
		atmosphere.Density = 0.6
		atmosphere.Haze = 6
		cc.Enabled = true
	else
		Lighting.FogStart = SURFACE_FOG.Start
		Lighting.FogEnd = SURFACE_FOG.End
		Lighting.FogColor = SURFACE_FOG.Color
		atmosphere.Density = surfaceAtmo.Density
		atmosphere.Haze = surfaceAtmo.Haze
		cc.Enabled = false
	end
end

-- UI -----------------------------------------------------------------------------------
local uiFolder = script.Parent:WaitForChild("UI")

local hudApi, shopApi, buildApi

local deps = {
	Remotes = remotes,
	OnShopButton = function()
		if state then shopApi.Open(state) end
	end,
	OnBuildButton = function()
		if state then buildApi.Open(state) end
	end,
}

hudApi = require(uiFolder:WaitForChild("HUD")).Init(deps)
shopApi = require(uiFolder:WaitForChild("ShopUI")).Init(deps)
buildApi = require(uiFolder:WaitForChild("BuildUI")).Init(deps)

-- Remotes -------------------------------------------------------------------------------
local function applyState(newState)
	state = newState
	hudApi.UpdateState(newState)
	shopApi.Refresh(newState)
	buildApi.Refresh(newState)
end

remotes.StateChanged.OnClientEvent:Connect(applyState)
remotes.Notify.OnClientEvent:Connect(function(text, colorName)
	hudApi.Toast(text, colorName)
end)
remotes.OpenShop.OnClientEvent:Connect(function()
	if state then shopApi.Open(state) end
end)
remotes.OpenBuild.OnClientEvent:Connect(function()
	if state then buildApi.Open(state) end
end)
remotes:WaitForChild("OpenSeeds").OnClientEvent:Connect(function(slotIndex)
	if state then hudApi.ShowSeedPicker(state, slotIndex) end
end)

-- Первичная загрузка состояния
task.spawn(function()
	local ok, result = pcall(function()
		return remotes.GetState:InvokeServer()
	end)
	if ok and result then
		applyState(result)
	end
end)

-- Деньги из leaderstats ----------------------------------------------------------------------
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 20)
	local coins = ls and ls:WaitForChild("Монеты", 20)
	if coins then
		hudApi.SetMoney(coins.Value)
		coins.Changed:Connect(function(v)
			hudApi.SetMoney(v)
		end)
	end
end)

-- Управление подлодкой ------------------------------------------------------------------------
local subControl = remotes:WaitForChild("SubControl")
local driving = false
local currentSub: Model? = nil

local function getOwnSubModel(seatPart: BasePart?): Model?
	if not seatPart then return nil end
	local model = seatPart:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function updateDriving()
	local char = player.Character
	local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local sub = getOwnSubModel(seat)
	local isDriving = sub ~= nil
	if isDriving ~= driving then
		driving = isDriving
		currentSub = sub
		hudApi.SetDriving(driving)
	end
end

-- Space/Shift — всплытие/погружение (перехватываем, чтобы не выпрыгнуть из кресла)
local function bindVertical()
	ContextActionService:BindAction("BuzzSubUp", function(_action, inputState)
		if not driving then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			subControl:FireServer(1)
		elseif inputState == Enum.UserInputState.End then
			subControl:FireServer(0)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)
	ContextActionService:BindAction("BuzzSubDown", function(_action, inputState)
		if not driving then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			subControl:FireServer(-1)
		elseif inputState == Enum.UserInputState.End then
			subControl:FireServer(0)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
end
bindVertical()

-- Цикл: глубина (эффекты) + топливо + статус вождения -------------------------------------------
local fuelTimer = 0
RunService.Heartbeat:Connect(function(dt)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		setUnderwater(hrp.Position.Y < -6)
	end

	updateDriving()

	if driving and currentSub then
		fuelTimer += dt
		if fuelTimer >= 0.25 then
			fuelTimer = 0
			local fuel = currentSub:GetAttribute("Fuel") or 0
			local maxFuel = currentSub:GetAttribute("MaxFuel") or 1
			hudApi.UpdateFuel(fuel, maxFuel)
		end
	end
end)

print("[BuzzBlocks] Клиент запущен.")
