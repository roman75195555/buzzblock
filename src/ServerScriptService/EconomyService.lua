--!strict
--==============================================================================
-- SeedRush :: EconomyService
-- Пассивный доход от выращенных растений на грядках.
--==============================================================================

local Players = game:GetService("Players")

local EconomyService = {}
local ctx

-- Доход игрока в секунду со всех взрослых растений
function EconomyService.IncomePerSecond(player: Player): number
	local data = ctx.Services.DataService.Get(player)
	if not data then return 0 end
	local Config = ctx.Config
	local total = 0
	local now = os.time()
	for _, plot in pairs(data.Plots) do
		local zone = Config.Zones[plot.Zone]
		if zone and now - plot.PlantedAt >= zone.GrowTime then
			total += zone.Income
		end
	end
	return total
end

function EconomyService.Start()
	while true do
		task.wait(2)
		for _, player in ipairs(Players:GetPlayers()) do
			local income = EconomyService.IncomePerSecond(player)
			if income > 0 then
				ctx.Services.DataService.AddMoney(player, income * 2)
				ctx.Services.DataService.PushState(player)
			end
		end
	end
end

function EconomyService.Init(c)
	ctx = c
end

return EconomyService
