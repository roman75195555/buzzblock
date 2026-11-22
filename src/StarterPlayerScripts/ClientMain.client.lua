--!strict
--==============================================================================
-- LunarBase :: ClientMain
-- HUD + интерактивная обработка камня: води мышкой по камню.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterPlayerScripts = script.Parent
local HUD = require(StarterPlayerScripts:WaitForChild("UI"):WaitForChild("HUD"))

local ctx = {}
HUD.Init(ctx)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("LunarRemotes")

-- Работа над камнем ------------------------------------------------------------
local activeStone: BasePart? = nil
local activeStage = 0
local progress = 0
local acc = 0

local STAGE_NAMES = {
	[1] = "🧹 Очистка",
	[2] = "⚙️ Опиливание",
}

local function stopWork()
	activeStone = nil
	activeStage = 0
	progress = 0
	acc = 0
	HUD.HideProgress()
end

remotes.WorkBegin.OnClientEvent:Connect(function(stone: BasePart, stage: number)
	activeStone = stone
	activeStage = stage
	progress = 0
	acc = 0
end)

remotes.WorkStage.OnClientEvent:Connect(function(stone: BasePart, stage: number)
	if activeStone == stone then
		if stage == 0 or stage == 3 then
			stopWork()
		else
			activeStage = stage
			progress = 0
			acc = 0
		end
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not activeStone or not activeStone.Parent then
		if activeStone then
			stopWork()
		end
		return
	end
	-- водим мышкой по камню: прогресс только когда курсор на камне
	local hovering = mouse.Target == activeStone
	if hovering then
		progress += dt
		acc += dt
		if acc >= 0.12 then
			remotes.WorkTick:FireServer(activeStone, acc)
			acc = 0
		end
	end
	local need = if activeStage == 1 then 1.5 else 2
	local name = STAGE_NAMES[activeStage] or "Обработка"
	HUD.SetProgress(math.clamp(progress / need, 0, 1), string.format("%s %d%%", name, math.floor(math.clamp(progress / need, 0, 1) * 100)))
end)

print("[LunarBase] Клиент запущен")
