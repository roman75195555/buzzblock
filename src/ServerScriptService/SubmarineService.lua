--!strict
--==============================================================================
-- BuzzBlocks :: SubmarineService
-- Сборка подлодки из купленных деталей, физика движения (VehicleSeat +
-- LinearVelocity + AlignOrientation), вращение винта, топливо, порталы.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SubmarineService = {}
local ctx

local subs: { [Player]: any } = {}

function SubmarineService.GetSub(player: Player)
	return subs[player]
end

function SubmarineService.IsDriving(player: Player): boolean
	local sub = subs[player]
	if not sub or not sub.Model.Parent then return false end
	local occ = sub.Seat.Occupant
	local char = player.Character
	return occ ~= nil and char ~= nil and occ:IsDescendantOf(char)
end

-- Постройка модели подлодки ------------------------------------------------------
local function buildSubModel(player: Player, spawnCF: CFrame)
	local Build = ctx.Build
	local Config = ctx.Config
	local pal = Config.Palette
	local d = ctx.Services.DataService.Get(player)
	local eq = d.Equipped

	local hullPart = Config.GetPart("Hull", eq.Hull)
	local engine = Config.GetPart("Engine", eq.Engine)
	local propeller = Config.GetPart("Propeller", eq.Propeller)
	local tank = Config.GetPart("Tank", eq.Tank)
	local wheel = Config.GetPart("Wheel", eq.Wheel)

	local s = hullPart.Size
	local hullColor = pal[hullPart.Color] or pal.Blue

	local model = Instance.new("Model")
	model.Name = "Sub_" .. player.Name

	local function P(opts)
		opts.Anchored = false
		return Build.Part(model, opts)
	end

	-- Корпус
	local root = P({
		Size = Vector3.new(12 * s, 4.5, 6.5 * s),
		CFrame = spawnCF * CFrame.new(0, 4, 0),
		Color = hullColor, Name = "Root",
	})
	-- нос
	P({
		Size = Vector3.new(4, 3.6, 5.4 * s),
		CFrame = root.CFrame * CFrame.new(7.2 * s, 0, 0),
		Color = hullColor, Shape = Enum.PartType.Ball, Name = "Nose",
	})
	-- корма
	Build.Wedge(model, {
		Size = Vector3.new(3.5, 4.5, 6.5 * s),
		CFrame = root.CFrame * CFrame.new(-7.7 * s, 0, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Color = hullColor, Anchored = false, Name = "Tail",
	})
	-- рубка (кабина)
	P({
		Size = Vector3.new(4.5, 2.6, 3.6),
		CFrame = root.CFrame * CFrame.new(1.5 * s, 3.4, 0),
		Color = pal.Cyan, Material = Enum.Material.Glass, Transparency = 0.35, Name = "Cabin",
	})
	-- перископ
	P({
		Size = Vector3.new(0.7, 2.6, 0.7),
		CFrame = root.CFrame * CFrame.new(1.5 * s, 5.8, 0),
		Color = pal.Black, Name = "Periscope",
	})
	P({
		Size = Vector3.new(1.6, 0.7, 0.7),
		CFrame = root.CFrame * CFrame.new(1.5 * s + 0.5, 7, 0),
		Color = pal.Black, Name = "PeriscopeTop",
	})
	-- балластные цистерны по бортам
	for sz = -1, 1, 2 do
		local tankP = P({
			Size = Vector3.new(9 * s, 2.2, 2.2),
			CFrame = root.CFrame * CFrame.new(-0.5, -1.4, sz * (3.2 * s + 0.8)),
			Color = pal.Yellow, Shape = Enum.PartType.Cylinder, Name = "Ballast",
		})
		tankP.CFrame = tankP.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
	-- килевой и верхний стабилизаторы
	Build.Wedge(model, {
		Size = Vector3.new(3, 2.4, 1),
		CFrame = root.CFrame * CFrame.new(-5.5 * s, 3.2, 0),
		Color = pal.Red, Anchored = false, Name = "TopFin",
	})
	Build.Wedge(model, {
		Size = Vector3.new(3, 2.4, 1),
		CFrame = root.CFrame * CFrame.new(-5.5 * s, -3.2, 0) * CFrame.Angles(math.rad(180), 0, 0),
		Color = pal.Red, Anchored = false, Name = "BottomFin",
	})
	-- фары
	for sz = -1, 1, 2 do
		local lamp = Build.Neon(model, {
			Size = Vector3.new(1, 1, 1),
			CFrame = root.CFrame * CFrame.new(8.8 * s, 0.4, sz * 1.8),
			Color = pal.White, Shape = Enum.PartType.Ball, Anchored = false, Name = "Headlight",
		})
		Build.Light(lamp, pal.White, 30, 2)
	end

	-- Сиденье пилота
	local seat = Instance.new("VehicleSeat")
	seat.Size = Vector3.new(2.6, 1, 2.6)
	seat.CFrame = root.CFrame * CFrame.new(1.5 * s, 2.8, 0)
	seat.Color = pal.Black
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Anchored = false
	seat.Name = "PilotSeat"
	seat.Parent = model

	-- Винт: ступица + лопасти на шарнире
	local spinner = P({
		Size = Vector3.new(1.2, 1.2, 1.2),
		CFrame = root.CFrame * CFrame.new(-9.9 * s, 0, 0),
		Color = pal.StoneDark, Shape = Enum.PartType.Cylinder, Name = "PropSpinner",
	})
	spinner.CFrame = spinner.CFrame * CFrame.Angles(0, 0, math.rad(90))
	for i = 0, 2 do
		local ang = math.rad(i * 120)
		local blade = Build.Wedge(model, {
			Size = Vector3.new(0.4, 3.4, 1.6),
			CFrame = spinner.CFrame * CFrame.Angles(ang, 0, 0) * CFrame.new(-0.3, 1.8, 0),
			Color = pal.Orange, Anchored = false, Name = "Blade",
		})
		-- лопасти крутятся вместе со ступицей
		local bw = Instance.new("WeldConstraint")
		bw.Part0 = spinner
		bw.Part1 = blade
		bw.Parent = spinner
	end

	-- Шарнир винта (ось X — продольная)
	local a0 = Instance.new("Attachment")
	a0.CFrame = CFrame.new(-9.2 * s, 0, 0)
	a0.Axis = Vector3.new(-1, 0, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Axis = Vector3.new(-1, 0, 0)
	a1.Parent = spinner
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.MotorMaxTorque = 1e6
	hinge.AngularVelocity = 0
	hinge.Parent = root

	-- Сварка всего к корню (ступицу и лопасти винта не свариваем — они на шарнире)
	Build.WeldTo(root, model, { PropSpinner = true, Blade = true })

	-- Привод
	local driveAtt = Instance.new("Attachment")
	driveAtt.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = driveAtt
	lv.VectorVelocity = Vector3.zero
	lv.MaxForce = 1e7
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = driveAtt
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = 1e7
	ao.Responsiveness = 25
	ao.CFrame = CFrame.new(root.Position)
	ao.Parent = root

	-- Пузыри за винтом
	Build.Bubbles(spinner, 8, 0.7)

	-- Атрибуты
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("MaxFuel", tank.Fuel)
	model:SetAttribute("Fuel", tank.Fuel)
	model:SetAttribute("MaxHP", hullPart.HP)
	model:SetAttribute("HP", hullPart.HP)
	model.PrimaryPart = root
	model.Parent = workspace

	return {
		Model = model, Root = root, Seat = seat, Hinge = hinge, LV = lv, AO = ao,
		Fuel = tank.Fuel, MaxFuel = tank.Fuel,
		Speed = engine.Speed * propeller.Boost,
		Turn = wheel.Turn,
		Vertical = 0,
		Yaw = math.atan2(-spawnCF.LookVector.Z, spawnCF.LookVector.X),
	}
end

-- Удаление ----------------------------------------------------------------------
function SubmarineService.RemoveSub(player: Player)
	local sub = subs[player]
	if sub and sub.Model then
		sub.Model:Destroy()
	end
	subs[player] = nil
end

-- Разрушение подлодки монстром: убираем лодку, игрока возвращаем на базу ---------
function SubmarineService.DestroySub(player: Player)
	SubmarineService.RemoveSub(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local base = ctx.Services.BaseService.GetBase(player)
	if hrp and base then
		hrp.CFrame = base.PadCF * CFrame.new(0, 6, 0)
	end
end

-- Управление -------------------------------------------------------------------
local function onBuildSub(player: Player)
	local d = ctx.Services.DataService.Get(player)
	local base = ctx.Services.BaseService.GetBase(player)
	if not d or not base then
		ctx.Remotes.Notify:FireClient(player, "Подожди загрузку базы!", "Red")
		return
	end
	-- валидация владения всеми деталями
	for category, tier in pairs(d.Equipped) do
		local owned = d.OwnedParts[category]
		if not owned or not owned[tier] then
			ctx.Remotes.Notify:FireClient(player, "Не все детали куплены!", "Red")
			return
		end
	end
	-- игрок должен быть рядом со стапелем
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - base.PadCF.Position).Magnitude > 50 then
		ctx.Remotes.Notify:FireClient(player, "Подойди к стапелю на своей базе!", "Red")
		return
	end

	SubmarineService.RemoveSub(player)
	local sub = buildSubModel(player, base.PadCF)
	subs[player] = sub

	-- сеть: владелец физики — пилот
	sub.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = sub.Seat.Occupant
		if occ then
			local plr = Players:GetPlayerFromCharacter(occ.Parent)
			if plr then
				pcall(function()
					sub.Root:SetNetworkOwner(plr)
				end)
			end
		end
	end)

	ctx.Remotes.Notify:FireClient(player, "🚢 Подлодка готова! Садись и в портал!", "Green")
	ctx.Services.DataService.PushState(player)
end

-- Порталы ----------------------------------------------------------------------
local portalCooldown: { [Instance]: number } = {}

local function portalTeleport(model: Model, destCF: CFrame)
	local now = os.clock()
	if portalCooldown[model] and now - portalCooldown[model] < 3 then return end
	portalCooldown[model] = now
	model:PivotTo(destCF * CFrame.new(0, 3, 0))
	local root = model.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function hookPortal(zone: BasePart, getDest: (Player) -> CFrame?)
	zone.Touched:Connect(function(hit)
		-- подлодка?
		local model = hit:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("OwnerUserId") then
			local player = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId"))
			if player then
				local dest = getDest(player)
				if dest then portalTeleport(model, dest) end
			end
			return
		end
		-- пеший игрок?
		local char = hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if player then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local dest = getDest(player)
			if hrp and dest then
				local now = os.clock()
				if portalCooldown[char] and now - portalCooldown[char] < 3 then return end
				portalCooldown[char] = now
				hrp.CFrame = dest * CFrame.new(0, 4, 0)
			end
		end
	end)
end

-- Игровой цикл -------------------------------------------------------------------
local function physicsTick(dt: number)
	local Config = ctx.Config
	for player, sub in pairs(subs) do
		if not sub.Model.Parent then
			subs[player] = nil
			continue
		end
		local throttle = sub.Seat.ThrottleFloat
		local steer = sub.Seat.SteerFloat
		local vertical = sub.Vertical

		-- топливо
		local working = (math.abs(throttle) > 0.05 or vertical ~= 0)
		if working and sub.Fuel > 0 then
			sub.Fuel = math.max(0, sub.Fuel - Config.FuelBurnPerSec * dt)
			sub.Model:SetAttribute("Fuel", math.round(sub.Fuel))
		end
		if sub.Fuel <= 0 then
			throttle = 0
			vertical = 0
		end

		-- скорость (нос подлодки смотрит вдоль +X)
		local speed = sub.Speed
		local forward = (CFrame.Angles(0, sub.Yaw, 0) * CFrame.Angles(0, math.rad(-90), 0)).LookVector
		-- вертикаль: кнопки/клавиши; над водой без ввода — мягкая посадка на гладь
		local vy = vertical * speed * 0.55
		if vertical == 0 then
			local y = sub.Root.Position.Y
			if y > ctx.Config.SeaLevel - 3 then
				vy = math.clamp((ctx.Config.SeaLevel + 1.6 - y) * 1.2, -6, 6)
			end
		end
		sub.LV.VectorVelocity = forward * (throttle * speed) + Vector3.new(0, vy, 0)

		-- поворот
		sub.Yaw += -steer * 1.4 * sub.Turn * dt * (throttle ~= 0 and math.sign(throttle) or 1)
		sub.AO.CFrame = CFrame.Angles(0, sub.Yaw, 0)

		-- винт
		sub.Hinge.AngularVelocity = throttle * 18 * (sub.Fuel > 0 and 1 or 0)

		-- автозаправка у своего стапеля
		local base = ctx.Services.BaseService.GetBase(player)
		if base and (sub.Root.Position - base.PadCF.Position).Magnitude < 22 and math.abs(throttle) < 0.05 then
			if sub.Fuel < sub.MaxFuel then
				sub.Fuel = math.min(sub.MaxFuel, sub.Fuel + sub.MaxFuel * dt * 0.3)
				sub.Model:SetAttribute("Fuel", math.round(sub.Fuel))
			end
		end
	end
end

function SubmarineService.Init(c)
	ctx = c
	-- отдельный remote вертикального управления (клиент: кнопки / Space / Shift)
	local subControl = Instance.new("RemoteEvent")
	subControl.Name = "SubControl"
	subControl.Parent = ctx.Remotes.Folder
	subControl.OnServerEvent:Connect(function(player: Player, vertical: any)
		if type(vertical) ~= "number" then return end
		local sub = subs[player]
		if sub then
			sub.Vertical = math.clamp(vertical, -1, 1)
		end
	end)

	ctx.Remotes.BuildSub.OnServerEvent:Connect(onBuildSub)
end

function SubmarineService.Start()
	local World = ctx.Services.WorldService
	-- поверхность -> подводный док
	hookPortal(World.PortalSurface.PortalZone, function(_player)
		return CFrame.new(0, -40, -14)
	end)
	-- под воду -> обратно к своему стапелю
	hookPortal(World.PortalUnder.PortalZone, function(player)
		local base = ctx.Services.BaseService.GetBase(player)
		return base and base.PadCF or CFrame.new(58, 2, 0)
	end)

	RunService.Heartbeat:Connect(physicsTick)
	Players.PlayerRemoving:Connect(function(player)
		SubmarineService.RemoveSub(player)
	end)
end

return SubmarineService
