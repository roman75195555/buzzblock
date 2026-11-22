--!strict
--==============================================================================
-- BuzzBlocks :: BuildUtil
-- Конструктор блочных LEGO-моделей: детали, studs, свечение, эмиттеры, сварка.
--==============================================================================

local BuildUtil = {}

export type PartOpts = {
	Size: Vector3?,
	CFrame: CFrame?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Shape: Enum.PartType?,
	Name: string?,
}

local function apply(p: BasePart, opts: PartOpts?)
	if opts then
		if opts.Size then p.Size = opts.Size end
		if opts.CFrame then p.CFrame = opts.CFrame end
		if opts.Color then p.Color = opts.Color end
		if opts.Material then p.Material = opts.Material end
		if opts.Transparency then p.Transparency = opts.Transparency end
		if opts.CanCollide ~= nil then p.CanCollide = opts.CanCollide end
		if opts.Name then p.Name = opts.Name end
		if opts.Shape and p:IsA("Part") then p.Shape = opts.Shape end
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- Обычный блок
function BuildUtil.Part(parent: Instance, opts: PartOpts?): Part
	local p = Instance.new("Part")
	p.Anchored = if opts and opts.Anchored ~= nil then opts.Anchored else true
	apply(p, opts)
	p.Parent = parent
	return p
end

-- Клин
function BuildUtil.Wedge(parent: Instance, opts: PartOpts?): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = if opts and opts.Anchored ~= nil then opts.Anchored else true
	apply(p, opts)
	p.Parent = parent
	return p
end

-- Клин «угловой»
function BuildUtil.CornerWedge(parent: Instance, opts: PartOpts?): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	p.Anchored = if opts and opts.Anchored ~= nil then opts.Anchored else true
	apply(p, opts)
	p.Parent = parent
	return p
end

-- Светящийся неоновый блок
function BuildUtil.Neon(parent: Instance, opts: PartOpts?): Part
	opts = opts or {}
	opts.Material = Enum.Material.Neon
	return BuildUtil.Part(parent, opts)
end

-- LEGO-studs: сетка цилиндров на верхней грани.
-- center — CFrame центра плиты, size — её размер, cell — шаг сетки.
function BuildUtil.Studs(parent: Instance, center: CFrame, size: Vector3, color: Color3, cell: number?)
	cell = cell or 2
	local group = Instance.new("Model")
	group.Name = "Studs"
	local nx = math.floor(size.X / cell)
	local nz = math.floor(size.Z / cell)
	local y = size.Y / 2 + 0.12
	for ix = 1, nx do
		for iz = 1, nz do
			local stud = Instance.new("Part")
			stud.Shape = Enum.PartType.Cylinder
			stud.Size = Vector3.new(0.24, cell * 0.62, cell * 0.62)
			local ox = (ix - 0.5) * cell - size.X / 2 + cell / 2
			local oz = (iz - 0.5) * cell - size.Z / 2 + cell / 2
			stud.CFrame = center * CFrame.new(ox, y, oz) * CFrame.Angles(0, 0, math.rad(90))
			stud.Color = color
			stud.Material = Enum.Material.SmoothPlastic
			stud.TopSurface = Enum.SurfaceType.Smooth
			stud.BottomSurface = Enum.SurfaceType.Smooth
			stud.Anchored = true
			stud.Parent = group
		end
	end
	group.Parent = parent
	return group
end

-- Сварка всех деталей модели к PrimaryPart (для незаякоренных сборок).
-- skipNames — имена деталей, которые сваривать НЕ нужно (например, винт на шарнире).
function BuildUtil.WeldTo(root: BasePart, model: Model, skipNames: { [string]: boolean }?)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root and not (skipNames and skipNames[d.Name]) then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = d
			w.Parent = root
			d.Anchored = false
		end
	end
end

-- Пузыри (подводный мир / винт)
function BuildUtil.Bubbles(parent: Instance, rate: number?, size: number?, color: Color3?)
	local a0 = Instance.new("Attachment")
	a0.Parent = parent
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Bubbles"
	pe.Texture = "rbxassetid://258128463"
	pe.Color = ColorSequence.new(color or Color3.fromRGB(200, 235, 255))
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, (size or 0.6) * 0.6),
		NumberSequenceKeypoint.new(1, size or 0.6),
	})
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Lifetime = NumberRange.new(2.5, 4.5)
	pe.Rate = rate or 6
	pe.Speed = NumberRange.new(3, 6)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, 4, 0)
	pe.LightEmission = 0.2
	pe.Parent = a0
	return pe
end

-- Блеск редких предметов
function BuildUtil.Sparkles(parent: Instance, color: Color3?)
	local s = Instance.new("Sparkles")
	s.SparkleColor = color or Color3.fromRGB(255, 230, 120)
	s.Parent = parent
	return s
end

-- Точечный свет
function BuildUtil.Light(parent: Instance, color: Color3, range: number?, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 16
	l.Brightness = brightness or 1.2
	l.Parent = parent
	return l
end

-- Плавающий текст (названия животных, ценники)
function BuildUtil.Billboard(parent: Instance, text: string, color: Color3?, offsetY: number?, textSize: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 44)
	bb.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Text = text
	tl.Font = Enum.Font.FredokaOne
	tl.TextSize = textSize or 20
	tl.TextColor3 = color or Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.4
	tl.TextStrokeColor3 = Color3.new(0, 0, 0)
	tl.Parent = bb
	bb.Parent = parent
	return bb
end

-- Сборка простого блочного дерева
function BuildUtil.Tree(parent: Instance, cf: CFrame, scale: number?, leafColor: Color3?)
	local P = BuildUtil.Part
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "Tree"
	P(m, { Size = Vector3.new(1.6 * s, 7 * s, 1.6 * s), CFrame = cf * CFrame.new(0, 3.5 * s, 0), Color = Color3.fromRGB(128, 90, 52) })
	P(m, { Size = Vector3.new(6.5 * s, 3 * s, 6.5 * s), CFrame = cf * CFrame.new(0, 7.5 * s, 0), Color = leafColor or Color3.fromRGB(72, 158, 66) })
	P(m, { Size = Vector3.new(4.6 * s, 2.6 * s, 4.6 * s), CFrame = cf * CFrame.new(0, 10 * s, 0), Color = leafColor or Color3.fromRGB(96, 190, 84) })
	P(m, { Size = Vector3.new(2.8 * s, 2.2 * s, 2.8 * s), CFrame = cf * CFrame.new(0, 12 * s, 0), Color = leafColor or Color3.fromRGB(120, 210, 100) })
	m.Parent = parent
	return m
end

-- Промпт взаимодействия (работает на ПК и телефонах)
function BuildUtil.Prompt(parent: Instance, actionText: string, objectText: string, holdTime: number?): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = actionText
	pp.ObjectText = objectText
	pp.HoldDuration = holdTime or 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

return BuildUtil
