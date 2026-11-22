--!strict
--==============================================================================
-- BuzzBlocks :: BaseService
-- Выдаёт игроку остров-базу: поле с грядками, стапель, домик, причал
-- (подлодка спавнится у воды), табличка, телепорты на хаб и обратно.
--==============================================================================

local Players = game:GetService("Players")

local BaseService = {}
local ctx

local bases: { [Player]: any } = {}
local usedPlots: { [number]: Player } = {}

function BaseService.GetBase(player: Player)
	return bases[player]
end

-- Строительство базы -------------------------------------------------------------
local function buildBase(player: Player, plotIndex: number)
	local Build = ctx.Build
	local Config = ctx.Config
	local pal = Config.Palette
	local World = ctx.Services.WorldService

	local plotCF = World.PlotCF[plotIndex]
	local base = Instance.new("Model")
	base.Name = "Base_" .. player.Name

	local function L(x: number, y: number, z: number): CFrame
		return plotCF * CFrame.new(x, y, z)
	end

	-- Стапель (площадка сборки подлодки) ----------------------------------------
	local padCF = L(0, 0.6, -19)
	Build.Part(base, { Size = Vector3.new(26, 1.4, 26), CFrame = padCF, Color = pal.StoneDark, Material = Enum.Material.Slate })
	Build.Studs(base, padCF * CFrame.new(0, 0.75, 0), Vector3.new(24, 0.1, 24), pal.Stone, 3)
	for i = -1, 1, 2 do
		Build.Neon(base, { Size = Vector3.new(22, 0.2, 0.8), CFrame = padCF * CFrame.new(0, 0.8, i * 10), Color = pal.Yellow })
	end
	-- стрела крана (декор)
	local craneBase = Build.Part(base, { Size = Vector3.new(2.4, 14, 2.4), CFrame = L(-11, 7, -19), Color = pal.Orange })
	Build.Part(base, { Size = Vector3.new(12, 1.8, 1.8), CFrame = L(-6, 13.5, -19), Color = pal.Orange })
	local hook = Build.Neon(base, { Size = Vector3.new(1.2, 1.2, 1.2), CFrame = L(-1, 10, -19), Color = pal.Yellow, Shape = Enum.PartType.Ball })
	Build.Part(base, { Size = Vector3.new(0.3, 4, 0.3), CFrame = L(-1, 12, -19), Color = pal.Black })
	craneBase.Name = "Crane"
	local pp = Build.Prompt(hook, "Открыть", "Верфь (сборка подлодки)")
	pp.Triggered:Connect(function(plr)
		if plr == player then
			ctx.Remotes.OpenBuild:FireClient(player)
		end
	end)

	-- Причал: от стапеля в воду, подлодка спавнится у понтона ----------------------
	for z = -34, -58, 4 do
		Build.Part(base, { Size = Vector3.new(6, 0.8, 4.2), CFrame = L(0, 3.0, z), Color = pal.Wood })
		-- сваи
		if z % 8 == 0 then
			for sx = -1, 1, 2 do
				Build.Part(base, { Size = Vector3.new(0.9, 9, 0.9), CFrame = L(sx * 2.6, -1.5, z), Color = pal.WoodDark })
			end
		end
	end
	-- понтон на воде
	Build.Part(base, { Size = Vector3.new(10, 1.2, 10), CFrame = L(0, 1.2, -64), Color = pal.WoodDark })
	Build.Studs(base, L(0, 1.9, -64), Vector3.new(9, 0.1, 9), pal.Wood, 3)
	for sx = -1, 1, 2 do
		local lamp = Build.Neon(base, { Size = Vector3.new(1, 1, 1), CFrame = L(sx * 4.2, 3.4, -64), Color = pal.Yellow, Shape = Enum.PartType.Ball })
		Build.Part(base, { Size = Vector3.new(0.5, 2.6, 0.5), CFrame = L(sx * 4.2, 2.2, -64), Color = pal.Black })
		Build.Light(lamp, pal.Yellow, 14, 1.2)
	end
	-- указатель на причале
	local dockSign = Build.Part(base, { Size = Vector3.new(7, 3, 0.6), CFrame = L(-3.4, 5.6, -40) * CFrame.Angles(0, math.rad(180), 0), Color = pal.Cyan })
	Build.SignText(dockSign, "⚓ Твоя подлодка", pal.Black)

	-- Поле: 6 грядок 2x3 ------------------------------------------------------------
	local field = Instance.new("Folder")
	field.Name = "Field"
	field.Parent = base
	local slotParts = {}
	local idx = 0
	for row = 0, 2 do
		for col = 0, 1 do
			idx += 1
			local sx = 9 + col * 9
			local sz = -6 + row * 9
			Build.Part(field, { Size = Vector3.new(8.4, 1.6, 8.4), CFrame = L(sx, 0.8, sz), Color = pal.WoodDark })
			local soil = Build.Part(field, {
				Size = Vector3.new(7.2, 1.8, 7.2), CFrame = L(sx, 1.0, sz),
				Color = pal.Soil, Material = Enum.Material.Ground, Name = "SoilSlot" .. idx,
			})
			soil:SetAttribute("SlotIndex", idx)
			soil:SetAttribute("Owner", player.UserId)
			slotParts[idx] = soil
		end
	end

	-- Забор вокруг поля ---------------------------------------------------------------
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = base
	local fx0, fx1, fz0, fz1 = 4, 22, -11, 19
	for x = fx0, fx1, 6 do
		for _, z in ipairs({ fz0, fz1 }) do
			Build.Part(fence, { Size = Vector3.new(1, 3, 1), CFrame = L(x, 1.5, z), Color = pal.Wood })
		end
	end
	for z = fz0, fz1, 6 do
		for _, x in ipairs({ fx0, fx1 }) do
			Build.Part(fence, { Size = Vector3.new(1, 3, 1), CFrame = L(x, 1.5, z), Color = pal.Wood })
		end
	end
	Build.Part(fence, { Size = Vector3.new(fx1 - fx0 + 1, 0.6, 0.6), CFrame = L((fx0 + fx1) / 2, 2.6, fz0), Color = pal.Wood })
	Build.Part(fence, { Size = Vector3.new(fx1 - fx0 + 1, 0.6, 0.6), CFrame = L((fx0 + fx1) / 2, 2.6, fz1), Color = pal.Wood })
	Build.Part(fence, { Size = Vector3.new(0.6, 0.6, fz1 - fz0 + 1), CFrame = L(fx0, 2.6, (fz0 + fz1) / 2), Color = pal.Wood })
	Build.Part(fence, { Size = Vector3.new(0.6, 0.6, fz1 - fz0 + 1), CFrame = L(fx1, 2.6, (fz0 + fz1) / 2), Color = pal.Wood })

	-- Домик -----------------------------------------------------------------------------
	local hx, hz = -15, 0
	Build.Part(base, { Size = Vector3.new(14, 1.2, 12), CFrame = L(hx, 0.6, hz), Color = pal.StoneDark })
	Build.Part(base, { Size = Vector3.new(14, 7, 1.4), CFrame = L(hx, 4, hz - 5.3), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(1.4, 7, 12), CFrame = L(hx - 6.3, 4, hz), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(1.4, 7, 12), CFrame = L(hx + 6.3, 4, hz), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(4.5, 7, 1.4), CFrame = L(hx - 4.75, 4, hz + 5.3), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(4.5, 7, 1.4), CFrame = L(hx + 4.75, 4, hz + 5.3), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(5, 2.5, 1.4), CFrame = L(hx, 6.25, hz + 5.3), Color = pal.Wood })
	Build.Part(base, { Size = Vector3.new(3.4, 4.4, 0.8), CFrame = L(hx, 2.8, hz + 5.3), Color = pal.WoodDark })
	for sx = -1, 1, 2 do
		Build.Neon(base, { Size = Vector3.new(2.2, 2.2, 0.6), CFrame = L(hx + sx * 4.5, 4.2, hz + 5.6), Color = pal.Cyan, Transparency = 0.3 })
	end
	Build.Wedge(base, { Size = Vector3.new(15.5, 5.5, 7), CFrame = L(hx, 10.2, hz - 3), Color = pal.Red })
	Build.Wedge(base, { Size = Vector3.new(15.5, 5.5, 7), CFrame = L(hx, 10.2, hz + 3) * CFrame.Angles(0, math.rad(180), 0), Color = pal.Red })
	Build.Part(base, { Size = Vector3.new(1.8, 4, 1.8), CFrame = L(hx - 4, 12.5, hz - 2), Color = pal.StoneDark })
	local honey = Build.Neon(base, { Size = Vector3.new(1.6, 1.6, 0.6), CFrame = L(hx, 8.2, hz + 5.8), Color = pal.Yellow, Shape = Enum.PartType.Ball })
	Build.Light(honey, pal.Yellow, 12, 1)

	-- Табличка (фиксированная надпись) ------------------------------------------------------
	Build.Part(base, { Size = Vector3.new(0.8, 6, 0.8), CFrame = L(0, 3, 20), Color = pal.WoodDark })
	local board = Build.Part(base, { Size = Vector3.new(10, 3.4, 0.8), CFrame = L(0, 7, 20), Color = pal.Yellow })
	Build.SignText(board, "🏡 База " .. player.DisplayName, pal.Black)

	-- Фонари ----------------------------------------------------------------------------------
	for _, pos in ipairs({ Vector3.new(-6, 0, 14), Vector3.new(20, 0, 22) }) do
		Build.Part(base, { Size = Vector3.new(0.9, 6.5, 0.9), CFrame = L(pos.X, 3.25, pos.Z), Color = pal.Black })
		local lamp = Build.Neon(base, { Size = Vector3.new(1.5, 1.5, 1.5), CFrame = L(pos.X, 6.9, pos.Z), Color = pal.Yellow, Shape = Enum.PartType.Ball })
		Build.Light(lamp, pal.Yellow, 20, 1.3)
	end

	-- Декоративные цветы ----------------------------------------------------------------------
	local rng = Random.new(player.UserId)
	local flowerColors = { pal.Red, pal.Pink, pal.Purple, pal.Orange, pal.Cyan }
	for i = 1, 10 do
		local fx = rng:NextNumber(-34, -2)
		local fz = rng:NextNumber(8, 32)
		Build.Part(base, { Size = Vector3.new(0.4, 1.6, 0.4), CFrame = L(fx, 0.8, fz), Color = pal.Seaweed })
		Build.Part(base, { Size = Vector3.new(1.3, 0.8, 1.3), CFrame = L(fx, 1.9, fz), Color = flowerColors[rng:NextInteger(1, #flowerColors)], Shape = Enum.PartType.Ball })
	end

	-- Телепорт на хаб ----------------------------------------------------------------------------
	World.MakeTeleporter(
		L(0, 0.6, 25),
		World.HubCF * CFrame.new(0, 3.5, 18),
		pal.Grass, "🏠 На хаб", base
	)

	base.Parent = workspace

	return {
		Model = base,
		PlotIndex = plotIndex,
		PlotCF = plotCF,
		PadCF = L(8, -2.2, -60),      -- точка появления подлодки: у понтона, в воде
		FieldSlots = slotParts,
	}
end

-- Управление жизненным циклом -------------------------------------------------------
local function assignPlot(player: Player): number?
	for i = 1, ctx.Config.PlotCount do
		if not usedPlots[i] then
			usedPlots[i] = player
			return i
		end
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local t0 = os.clock()
	while not ctx.Services.DataService.IsLoaded(player) and os.clock() - t0 < 15 do
		task.wait(0.1)
	end
	local plot = assignPlot(player)
	if not plot then
		ctx.Remotes.Notify:FireClient(player, "Нет свободных баз — сервер полон!", "Red")
		return
	end
	local base = buildBase(player, plot)
	bases[player] = base

	task.defer(function()
		local ps = ctx.Services.PlantService
		if ps and ps.OnBaseReady then ps.OnBaseReady(player, base) end
		local bs = ctx.Services.BeeService
		if bs and bs.OnBaseReady then bs.OnBaseReady(player, base) end
	end)
end

local function onPlayerRemoving(player: Player)
	local base = bases[player]
	if base then
		local ss = ctx.Services.SubmarineService
		if ss and ss.RemoveSub then ss.RemoveSub(player) end
		base.Model:Destroy()
		usedPlots[base.PlotIndex] = nil
		bases[player] = nil
	end
end

function BaseService.Init(c)
	ctx = c
end

function BaseService.Start()
	local World = ctx.Services.WorldService
	local pal = ctx.Config.Palette

	-- Телепорты с хаба на каждый остров (прибытие — В СТОРОНЕ от обратной площадки)
	local padColors = { pal.Red, pal.Orange, pal.Yellow, pal.Grass, pal.Cyan, pal.Blue, pal.Purple, pal.Pink }
	for i = 1, ctx.Config.PlotCount do
		local plotCF = World.PlotCF[i]
		local dir = (Vector3.new(plotCF.Position.X, 0, plotCF.Position.Z)).Unit
		local padPos = dir * 36
		World.MakeTeleporter(
			CFrame.new(padPos + Vector3.new(0, 3.4, 0)),
			plotCF * CFrame.new(0, 3.5, 14),
			padColors[((i - 1) % #padColors) + 1],
			"🏡 База " .. i,
			workspace
		)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
end

return BaseService
