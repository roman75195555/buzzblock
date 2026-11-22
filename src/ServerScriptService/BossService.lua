--!strict
--==============================================================================
-- SeedRush :: BossService
-- 7 локаций вдоль дорожки: спящий босс + пьедесталы с семенами.
-- Украл семя -> босс просыпается и гонится. Догнал -> семя потеряно.
-- Добежал до зелёной зоны (z < SafeZoneZ) -> семя твоё.
--==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BossService = {}
local ctx

type ZoneState = {
	Zone: any,
	Boss: Model,
	Root: BasePart,
	Home: Vector3,
	Eggs: { BasePart },
	EggRespawnAt: number,
	AggroOn: Player?,
	ChaseStart: number,
	Sleeping: boolean,
	Zzz: BillboardGui?,
	EyeL: BasePart?,
	EyeR: BasePart?,
}

local zones: { ZoneState } = {}
local carried: { [Player]: number } = {} -- player -> zoneId украденного семени
local carryMarker: { [Player]: Instance? } = {}

-- Блочный босс --------------------------------------------------------------------
local function buildBoss(parent: Instance, zone: any, pos: Vector3): (Model, BasePart, BasePart, BasePart)
	local B = ctx.Build
	local s = zone.BossScale
	local c = zone.Color

	local m = Instance.new("Model")
	m.Name = "Boss_" .. zone.Name

	local root = B.Part(m, {
		Size = Vector3.new(4 * s, 5 * s, 3 * s),
		CFrame = CFrame.new(pos + Vector3.new(0, 4.5 * s, 0)),
		Color = c,
		Name = "BossRoot",
		CanCollide = true,
	})
	root.Material = Enum.Material.SmoothPlastic

	-- голова
	local head = B.Part(m, {
		Size = Vector3.new(3 * s, 2.6 * s, 2.6 * s),
		CFrame = root.CFrame * CFrame.new(0, 3.8 * s, 0),
		Color = c:Lerp(Color3.new(1, 1, 1), 0.15),
	})
	-- глаза (спящие — тёмные)
	local eyeL = B.Neon(m, {
		Size = Vector3.new(0.6 * s, 0.3 * s, 0.3 * s),
		CFrame = head.CFrame * CFrame.new(-0.8 * s, 0.3 * s, -1.35 * s),
		Color = Color3.fromRGB(40, 40, 50),
	})
	local eyeR = B.Neon(m, {
		Size = Vector3.new(0.6 * s, 0.3 * s, 0.3 * s),
		CFrame = head.CFrame * CFrame.new(0.8 * s, 0.3 * s, -1.35 * s),
		Color = Color3.fromRGB(40, 40, 50),
	})
	-- руки
	B.Part(m, {
		Size = Vector3.new(1.2 * s, 4 * s, 1.2 * s),
		CFrame = root.CFrame * CFrame.new(-2.6 * s, -0.3 * s, 0),
		Color = c:Lerp(Color3.new(0, 0, 0), 0.15),
	})
	B.Part(m, {
		Size = Vector3.new(1.2 * s, 4 * s, 1.2 * s),
		CFrame = root.CFrame * CFrame.new(2.6 * s, -0.3 * s, 0),
		Color = c:Lerp(Color3.new(0, 0, 0), 0.15),
	})
	-- ноги
	B.Part(m, {
		Size = Vector3.new(1.4 * s, 2 * s, 1.4 * s),
		CFrame = root.CFrame * CFrame.new(-1.1 * s, -3.4 * s, 0),
		Color = c:Lerp(Color3.new(0, 0, 0), 0.25),
	})
	B.Part(m, {
		Size = Vector3.new(1.4 * s, 2 * s, 1.4 * s),
		CFrame = root.CFrame * CFrame.new(1.1 * s, -3.4 * s, 0),
		Color = c:Lerp(Color3.new(0, 0, 0), 0.25),
	})
	-- корона для финального
	if zone.BossScale >= 3 then
		local crown = B.Neon(m, {
			Size = Vector3.new(2 * s, 0.8 * s, 2 * s),
			CFrame = head.CFrame * CFrame.new(0, 1.8 * s, 0),
			Color = Color3.fromRGB(255, 215, 0),
		})
		B.Sparkles(crown, Color3.fromRGB(255, 215, 0))
	end

	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	m.PrimaryPart = root
	m.Parent = parent
	return m, root, eyeL, eyeR
end

-- Яйцо-семя -----------------------------------------------------------------------
local function buildEgg(parent: Instance, zone: any, pos: Vector3, zoneId: number): BasePart
	local B = ctx.Build
	-- пьедестал
	B.Part(parent, {
		Size = Vector3.new(3, 1.6, 3),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Marble,
	})
	local egg = B.Neon(parent, {
		Size = Vector3.new(1.6, 2, 1.6),
		CFrame = CFrame.new(pos + Vector3.new(0, 2.6, 0)),
		Color = zone.Color,
		Shape = Enum.PartType.Ball,
		Name = "SeedEgg" .. zoneId,
	})
	B.Sparkles(egg, zone.Color)
	B.Billboard(egg, string.format("🥚 %s · %d💰/с", zone.Name, zone.Income), zone.Color, 2.2)

	local pp = B.Prompt(egg, "Украсть", "Семя: " .. zone.Name, 0.5)
	pp.Triggered:Connect(function(player)
		BossService.TrySteal(player, zoneId, egg)
	end)
	return egg
end

-- Табличка локации ------------------------------------------------------------------
local function buildZoneSign(parent: Instance, zone: any, zoneId: number, z: number)
	local B = ctx.Build
	local x = ctx.Config.TrackCenterX + 40
	local post = B.Part(parent, {
		Size = Vector3.new(1, 8, 1),
		CFrame = CFrame.new(x, 8, z),
		Color = Color3.fromRGB(80, 60, 40),
		Material = Enum.Material.Wood,
	})
	local board = B.Part(parent, {
		Size = Vector3.new(14, 5, 0.6),
		CFrame = CFrame.new(x, 13.5, z),
		Color = zone.Color,
	})
	B.SignText(board, string.format("%s\nСила: %d+ · %d💰/с", zone.Name, zone.ReqStrength, zone.Income), Color3.new(1, 1, 1))
	post.Name = "ZoneSign" .. zoneId
	board.Name = "ZoneBoard" .. zoneId
end

-- Кража ------------------------------------------------------------------------------
function BossService.TrySteal(player: Player, zoneId: number, egg: BasePart?)
	local data = ctx.Services.DataService.Get(player)
	if not data then return end
	local Config = ctx.Config
	local zs = zones[zoneId]
	if not zs then return end

	if carried[player] then
		ctx.Remotes.Notify:FireClient(player, "Ты уже несёшь семя!", "error")
		return
	end
	if not zs.Sleeping then
		ctx.Remotes.Notify:FireClient(player, "Босс не спит! Жди, пока уснёт.", "error")
		return
	end
	if not egg or not egg.Parent then
		ctx.Remotes.Notify:FireClient(player, "Семя ещё не появилось!", "error")
		return
	end
	if data.Strength < zs.Zone.ReqStrength then
		ctx.Remotes.Notify:FireClient(player, "Нужна сила " .. zs.Zone.ReqStrength .. "+! Качайся гантелей.", "error")
		return
	end

	-- забрать яйцо
	local idx = table.find(zs.Eggs, egg)
	if idx then
		table.remove(zs.Eggs, idx)
	end
	egg:Destroy()
	zs.EggRespawnAt = os.clock() + Config.SeedRespawn
	carried[player] = zoneId

	-- маркер над головой
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		local bb = ctx.Build.Billboard(head, "🥚 НЕСЁТ СЕМЯ!", Color3.fromRGB(255, 230, 120), 2.5)
		carryMarker[player] = bb
	end

	-- разбудить босса
	zs.Sleeping = false
	zs.AggroOn = player
	zs.ChaseStart = os.clock()
	if zs.Zzz then
		zs.Zzz:Destroy()
		zs.Zzz = nil
	end
	if zs.EyeL then zs.EyeL.Color = Color3.fromRGB(255, 30, 30) end
	if zs.EyeR then zs.EyeR.Color = Color3.fromRGB(255, 30, 30) end

	ctx.Remotes.Notify:FireClient(player, zs.Zone.BossName .. " проснулся! БЕГИ НА БАЗУ!", "error")
end

local function clearCarry(player: Player)
	carried[player] = nil
	local m = carryMarker[player]
	if m then
		m:Destroy()
		carryMarker[player] = nil
	end
end

local function bossSleep(zs: ZoneState)
	zs.Sleeping = true
	zs.AggroOn = nil
	if zs.EyeL then zs.EyeL.Color = Color3.fromRGB(40, 40, 50) end
	if zs.EyeR then zs.EyeR.Color = Color3.fromRGB(40, 40, 50) end
	if not zs.Zzz and zs.Root then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 60)
		bb.StudsOffset = Vector3.new(0, 6 * zs.Zone.BossScale, 0)
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundTransparency = 1
		tl.Text = "💤 Zzz"
		tl.Font = Enum.Font.FredokaOne
		tl.TextSize = 36
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.5
		tl.Parent = bb
		bb.Parent = zs.Root
		zs.Zzz = bb
	end
end

local function resolveChase(zs: ZoneState, caught: boolean)
	local player = zs.AggroOn
	if player and carried[player] then
		local zoneId = carried[player]
		clearCarry(player)
		if caught then
			ctx.Remotes.Notify:FireClient(player, zs.Zone.BossName .. " отобрал семя!", "error")
			-- небольшой отброс
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.new(0, 60, -40)
			end
		else
			local data = ctx.Services.DataService.Get(player)
			if data then
				local k = tostring(zoneId)
				data.Seeds[k] = (data.Seeds[k] or 0) + 1
				ctx.Services.DataService.PushState(player)
			end
			ctx.Remotes.Notify:FireClient(player, "Семя «" .. zs.Zone.Name .. "» у тебя! Посади его на базе.", "success")
		end
	end
	zs.AggroOn = nil
	task.delay(2, function()
		bossSleep(zs)
	end)
end

-- Постройка локаций -------------------------------------------------------------------
local function buildZones()
	local Config = ctx.Config
	local folder = Instance.new("Folder")
	folder.Name = "BossZones"
	folder.Parent = workspace

	for id, zone in ipairs(Config.Zones) do
		local x = Config.TrackCenterX
		-- босс за семенами
		local bossPos = Vector3.new(x, 4, zone.Z + 22)
		local model, root, eyeL, eyeR = buildBoss(folder, zone, bossPos)
		-- имя босса над головой
		ctx.Build.Billboard(root, zone.BossName .. " · 💪" .. zone.ReqStrength .. "+", Color3.fromRGB(255, 120, 120), 8 * zone.BossScale)

		local zs: ZoneState = {
			Zone = zone,
			Boss = model,
			Root = root,
			Home = bossPos + Vector3.new(0, 4.5 * zone.BossScale, 0),
			Eggs = {},
			EggRespawnAt = math.huge,
			AggroOn = nil,
			ChaseStart = 0,
			Sleeping = true,
			Zzz = nil,
			EyeL = eyeL,
			EyeR = eyeR,
		}
		-- два пьедестала по бокам от центра
		table.insert(zs.Eggs, buildEgg(folder, zone, Vector3.new(x - 30, 4, zone.Z - 10), id))
		table.insert(zs.Eggs, buildEgg(folder, zone, Vector3.new(x + 30, 4, zone.Z - 10), id))
		buildZoneSign(folder, zone, id, zone.Z - 48)
		bossSleep(zs)
		zones[id] = zs
	end
end

-- Погоня -------------------------------------------------------------------------------
local chaseConn: RBXScriptConnection? = nil

local function startChaseLoop()
	local bob = 0
	chaseConn = RunService.Heartbeat:Connect(function(dt)
		bob += dt
		for id, zs in ipairs(zones) do
			-- возрождение яиц (только пока босс спит)
			if #zs.Eggs < 2 and os.clock() >= zs.EggRespawnAt and zs.Sleeping then
				local x = ctx.Config.TrackCenterX
				if #zs.Eggs == 0 then
					table.insert(zs.Eggs, buildEgg(zs.Boss.Parent, zs.Zone, Vector3.new(x - 30, 4, zs.Zone.Z - 10), id))
					table.insert(zs.Eggs, buildEgg(zs.Boss.Parent, zs.Zone, Vector3.new(x + 30, 4, zs.Zone.Z - 10), id))
				else
					local side = if zs.Eggs[1].Position.X < x then 30 else -30
					table.insert(zs.Eggs, buildEgg(zs.Boss.Parent, zs.Zone, Vector3.new(x + side, 4, zs.Zone.Z - 10), id))
				end
				zs.EggRespawnAt = math.huge
			end

			local root = zs.Root
			if not root then continue end

			if zs.AggroOn then
				local player = zs.AggroOn
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local invalid = (not hrp) or (not hum) or hum.Health <= 0 or (not carried[player])

				-- сбежал в безопасную зону
				if not invalid and hrp.Position.Z < ctx.Config.SafeZoneZ then
					resolveChase(zs, false)
				elseif invalid then
					resolveChase(zs, true)
				elseif os.clock() - zs.ChaseStart > ctx.Config.BossGiveUpTime then
					resolveChase(zs, false)
				else
					-- движение к игроку
					local pos = root.Position
					local target = hrp.Position
					local dir = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
					local dist = dir.Magnitude
					if dist < ctx.Config.CatchRadius then
						resolveChase(zs, true)
					else
						dir = dir.Unit
						local step = math.min(zs.Zone.BossSpeed * dt, dist)
						local newPos = pos + dir * step
						newPos = Vector3.new(newPos.X, zs.Home.Y + math.sin(bob * 8) * 0.4, newPos.Z)
						zs.Boss:PivotTo(CFrame.lookAt(newPos, Vector3.new(target.X, newPos.Y, target.Z)))
					end
				end
			else
				-- возврат домой
				local pos = root.Position
				local d = zs.Home - pos
				if d.Magnitude > 1 then
					local step = math.min(zs.Zone.BossSpeed * 0.6 * dt, d.Magnitude)
					local newPos = pos + d.Unit * step
					zs.Boss:PivotTo(CFrame.lookAt(newPos, zs.Home))
				else
					-- лёгкое покачивание во сне
					local sway = math.sin(bob * 1.5 + zs.Zone.Z) * 0.05
					zs.Boss:PivotTo(CFrame.new(zs.Home) * CFrame.Angles(0, sway, 0))
				end
			end
		end
	end)
end

-- Смерть носителя = потеря семени -----------------------------------------------------
local function watchDeaths()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid")
			hum.Died:Connect(function()
				if carried[player] then
					local zoneId = carried[player]
					clearCarry(player)
					local zs = zones[zoneId]
					if zs and zs.AggroOn == player then
						zs.AggroOn = nil
						task.delay(2, function()
							bossSleep(zs)
						end)
					end
				end
			end)
		end)
	end)
end

function BossService.Init(c)
	ctx = c
end

function BossService.Start()
	buildZones()
	startChaseLoop()
	watchDeaths()
	print("[BossService] Локаций построено: " .. #zones)
end

return BossService
