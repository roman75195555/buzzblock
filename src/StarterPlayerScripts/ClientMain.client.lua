--!strict
--==============================================================================
-- LunarBase :: ClientMain
-- Точка входа клиента: HUD.
--==============================================================================

local StarterPlayerScripts = script.Parent

local ctx = {}

local HUD = require(StarterPlayerScripts:WaitForChild("UI"):WaitForChild("HUD"))
HUD.Init(ctx)

print("[LunarBase] Клиент запущен")
