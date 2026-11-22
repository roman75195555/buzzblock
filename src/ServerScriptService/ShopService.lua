--!strict
--==============================================================================
-- SeedRush :: ShopService
-- Покупки: улучшение беговой дорожки, тренажёра силы, следы (trails).
-- Вся проверка и списание — на сервере.
--==============================================================================

local Players = game:GetService("Players")

local ShopService = {}
local ctx

local function notify(player: Player, text: string, colorName: string?)
	ctx.Remotes.Notify:FireClient(player, text, colorName or "info")
end

-- Применить визуальный след к персонажу
local function applyTrail(player: Player, trailId: number)
	local Config = ctx.Config
	local t = Config.Trails[trailId]
	if not t then return end
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local old = char:FindFirstChild("PlayerTrail")
	if old then old:Destroy() end
	for _, a in ipairs(root:GetChildren()) do
		if a:IsA("Attachment") and (a.Name == "TrailA0" or a.Name == "TrailA1") then
			a:Destroy()
		end
	end

	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "PlayerTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(t.Color)
	trail.Lifetime = 0.6
	trail.MinLength = 0.1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = char
end

local function bestOwnedTrail(data): number?
	local best: number? = nil
	for idStr in pairs(data.Trails) do
		local id = tonumber(idStr)
		if id and (not best or id > best) then
			best = id
		end
	end
	return best
end

local function onBuy(player: Player, kind: string)
	local Data = ctx.Services.DataService
	local data = Data.Get(player)
	if not data then return end
	local Config = ctx.Config

	if kind == "treadmill" then
		local tier = data.TreadmillTier
		if tier >= Config.MaxTier then
			notify(player, "Дорожка уже максимального уровня!", "error")
			return
		end
		local cost = Config.UpgradeCost(tier)
		if not Data.TrySpend(player, cost) then
			notify(player, "Не хватает монет! Нужно " .. cost .. "💰", "error")
			return
		end
		data.TreadmillTier = tier + 1
		notify(player, "Дорожка улучшена до " .. data.TreadmillTier .. " ур.!", "success")

	elseif kind == "trainer" then
		local tier = data.TrainerTier
		if tier >= Config.MaxTier then
			notify(player, "Тренажёр уже максимального уровня!", "error")
			return
		end
		local cost = Config.UpgradeCost(tier)
		if not Data.TrySpend(player, cost) then
			notify(player, "Не хватает монет! Нужно " .. cost .. "💰", "error")
			return
		end
		data.TrainerTier = tier + 1
		notify(player, "Тренажёр улучшен до " .. data.TrainerTier .. " ур.!", "success")

	elseif string.sub(kind, 1, 6) == "trail:" then
		local id = tonumber(string.sub(kind, 7))
		local t = id and Config.Trails[id]
		if not t then return end
		if data.Trails[tostring(id)] then
			notify(player, "Этот след уже куплен!", "error")
			return
		end
		if not Data.TrySpend(player, t.Cost) then
			notify(player, "Не хватает монет! Нужно " .. t.Cost .. "💰", "error")
			return
		end
		data.Trails[tostring(id)] = true
		applyTrail(player, id)
		ctx.Services.BaseService.UpdateWalkSpeed(player)
		notify(player, "Куплен «" .. t.Name .. "»! +" .. t.Bonus .. " к скорости", "success")
	end

	Data.PushState(player)
end

function ShopService.Init(c)
	ctx = c
	ctx.Remotes.BuyUpgrade.OnServerEvent:Connect(onBuy)
end

function ShopService.Start()
	-- след после возрождения
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			local data = ctx.Services.DataService.Get(player)
			if data then
				local best = bestOwnedTrail(data)
				if best then
					applyTrail(player, best)
				end
			end
		end)
	end)
end

return ShopService
