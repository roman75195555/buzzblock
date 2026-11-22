--!strict
--==============================================================================
-- SeedRush :: ClientMain
-- Точка входа клиента: HUD + магазин.
--==============================================================================

local Players = game:GetService("Players")
local StarterPlayerScripts = script.Parent

local ctx = { State = nil }

local HUD = require(StarterPlayerScripts:WaitForChild("UI"):WaitForChild("HUD"))
local ShopUI = require(StarterPlayerScripts:WaitForChild("UI"):WaitForChild("ShopUI"))

HUD.Init(ctx)
ShopUI.Init(ctx)

-- кнопка магазина из HUD
task.defer(function()
	task.wait(1)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local hud = gui:FindFirstChild("RushHUD")
	local btn = hud and hud:FindFirstChildWhichIsA("TextButton", true)
	if btn then
		btn.MouseButton1Click:Connect(function()
			ShopUI.Toggle()
		end)
	end
end)

print("[SeedRush] Клиент запущен")
