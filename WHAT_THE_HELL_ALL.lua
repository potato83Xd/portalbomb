-- WHAT_THE_HELL_ALL.lua | Todos los add-ons en un solo LocalScript (StarterPlayerScripts).
-- Cada módulo va en su propio bloque do...end para que sus variables no choquen.
-- Todo es local: no hay RemoteEvents ni cambios en el servidor.

-- ===================== MÓDULO: WHAT_THE_HELL (base de desastres) =====================
do
--[[
	WHAT_THE_HELL.lua | UNIVERSAL LOCAL REALITY COLLAPSE
	Ubicación: LocalScript en StarterPlayer > StarterPlayerScripts
	100% local: sin RemoteEvents, sin tocar el servidor, sin afectar a otros jugadores.
	Los modelos se cargan con GetObjects si tu cuenta tiene acceso; si no, se usan
	stand-ins procedurales (se avisa en consola). Nada de esto es visible para nadie más.
]]

--==================== SERVICIOS ====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local rng = Random.new()
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local CAM_BIND = "WTH_Camera"

--==================== CONFIG ====================
local CONFIG = {
	MaxObjects = IS_MOBILE and 90 or 220,
	MaxActiveEvents = IS_MOBILE and 3 or 5,
	BaseInterval = 9,
	AlertDuration = 4.5,
	HistorySize = 6,
	MaxAlerts = 3,
}

--==================== ESTADO ====================
local V, C = Vector3.new, Color3.fromRGB
local BL, BA, CY = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

local function defaultTargets()
	return {blur = 0, sat = 0, contrast = 0, density = 0.05, bloom = 0,
		tint = Color3.new(1, 1, 1), atmo = C(190, 205, 255), fov = 0}
end

local State = {
	running = false,
	destroyed = false,
	frequency = 0.5,
	intensity = 0.4,
	power = 0.4,
	chaosTime = 0,
	timer = 0,
	hudAcc = 0,
	active = {},
	history = {},
	lastUsed = {},
	comboAt = {},
	multiAlertAt = -999,
	movers = {},
	tweens = {},
	fx = {},
	stash = {},
	lightingBackup = nil,
	baseFov = nil,
	session = 0,
	tokenCount = 0,
	curToken = 0,
	objectCount = 0,
	holeCenter = nil,
	cam = {roll = 0, rollTarget = 0, shake = 0, fovWarp = 0, flash = 0},
	tg = defaultTargets(),
	conns = {},
	ui = {},
}

local root = Instance.new("Folder")
root.Name = "WTH_Chaos"
root.Parent = workspace

local showAlert, updateHUD -- forward declarations

--==================== HELPERS ====================
local function pick(t)
	return t[rng:NextInteger(1, #t)]
end

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thick
	s.Parent = parent
end

local function tween(obj, time, props, style)
	if #State.tweens > 150 then State.tweens = {} end
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	table.insert(State.tweens, tw)
	return tw
end

local function playerPos()
	local cam = workspace.CurrentCamera
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	if h then return h.Position end
	return cam.CFrame.Position + cam.CFrame.LookVector * 20
end

local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = {root}
	if player.Character then table.insert(ex, player.Character) end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + V(0, 300, 0), V(0, -800, 0), params)
	return hit and hit.Position.Y or pos.Y
end

local function randomAround(radius, minR)
	local base = playerPos()
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(minR or 30, radius)
	return base + V(math.cos(a) * d, 0, math.sin(a) * d)
end

local function skyPoint(dist, height)
	local base = playerPos()
	local a = rng:NextNumber(0, math.pi * 2)
	return base + V(math.cos(a) * dist, height, math.sin(a) * dist)
end

local function mkPart(size, color, cf, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color or C(255, 255, 255)
	p.CFrame = cf or CFrame.new()
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Transparency = opts.transparency or 0
	p.Shape = opts.shape or BL
	p.Name = opts.name or "WTH_Part"
	return p
end

-- Presupuesto global de objetos. Todo lo creado queda etiquetado con su evento para limpieza.
local function place(inst)
	if State.objectCount >= CONFIG.MaxObjects then
		inst:Destroy()
		return nil
	end
	State.objectCount += 1
	inst:SetAttribute("ev", State.curToken)
	inst.Destroying:Connect(function()
		State.objectCount -= 1
	end)
	inst.Parent = root
	return inst
end

local function addMover(fn, life, done)
	table.insert(State.movers, {fn = fn, t = 0, life = life or math.huge, done = done})
end

local function runMovers(dt)
	local list = State.movers
	for i = #list, 1, -1 do
		local m = list[i]
		m.t += dt
		local keep = m.t < m.life
		if keep then
			local ok, res = pcall(m.fn, dt, m.t)
			if not ok then
				warn("[WTH] " .. tostring(res))
				keep = false
			elseif res == false then
				keep = false
			end
		end
		if not keep then
			table.remove(list, i)
			if m.done then pcall(m.done) end
		end
	end
end

-- Ejecuta algo más tarde, pero solo si la sesión sigue viva y etiquetando con el token correcto.
local function later(sec, fn)
	local s = State.session
	local tok = State.curToken
	task.delay(sec, function()
		if s == State.session and not State.destroyed then
			State.curToken = tok
			fn()
		end
	end)
end

--==================== LIGHTING / FX / CÁMARA ====================
local function makeFx(class, key)
	local fx = Instance.new(class)
	fx.Name = "WTH_" .. key
	fx.Parent = Lighting
	State.fx[key] = fx
	return fx
end

local function backupLighting()
	State.lightingBackup = {}
	for _, k in ipairs({"Ambient", "OutdoorAmbient", "Brightness", "ClockTime", "FogEnd", "FogStart", "FogColor", "GeographicLatitude"}) do
		State.lightingBackup[k] = Lighting[k]
	end
	for _, c in ipairs(Lighting:GetChildren()) do
		if c:IsA("Sky") or c:IsA("Atmosphere") then
			table.insert(State.stash, c)
			c.Parent = nil
		end
	end
end

local function setupFx()
	local blur = makeFx("BlurEffect", "blur")
	blur.Size = 0
	makeFx("ColorCorrectionEffect", "cc")
	local bloom = makeFx("BloomEffect", "bloom")
	bloom.Intensity = 0
	local atmo = makeFx("Atmosphere", "atmo")
	atmo.Density = 0.05
	atmo.Color = C(190, 205, 255)
end

local function restoreVisuals()
	local b = State.lightingBackup
	if b then
		for k, v in pairs(b) do
			pcall(function() Lighting[k] = v end)
		end
	end
	for _, fx in pairs(State.fx) do fx:Destroy() end
	State.fx = {}
	for _, c in ipairs(State.stash) do c.Parent = Lighting end
	State.stash = {}
	State.lightingBackup = nil
	if State.baseFov then workspace.CurrentCamera.FieldOfView = State.baseFov end
end

local function ambientStep(dt)
	local tg = State.tg
	local k = math.min(1, dt * 2.5)
	State.cam.fovWarp += (tg.fov - State.cam.fovWarp) * k
	local fx = State.fx
	if not fx.blur then return end
	fx.blur.Size += (tg.blur - fx.blur.Size) * k
	fx.cc.Saturation += (tg.sat - fx.cc.Saturation) * k
	fx.cc.Contrast += (tg.contrast - fx.cc.Contrast) * k
	fx.cc.TintColor = fx.cc.TintColor:Lerp(tg.tint, k)
	fx.atmo.Density += (tg.density - fx.atmo.Density) * k
	fx.atmo.Color = fx.atmo.Color:Lerp(tg.atmo, k)
	fx.bloom.Intensity += (tg.bloom - fx.bloom.Intensity) * k
	local base = State.lightingBackup and State.lightingBackup.Brightness or 2
	Lighting.Brightness = base + State.cam.flash * 6
end

-- Cámara local: shake, roll (inversión), FOV warp. Corre después de la cámara por defecto.
local function cameraStep(dt)
	local c = State.cam
	c.roll += (c.rollTarget - c.roll) * math.min(1, dt * 1.5)
	c.shake *= math.max(0, 1 - dt * 4)
	c.flash *= math.max(0, 1 - dt * 3)
	local ox, oy = 0, 0
	if c.shake > 0.01 then
		ox = rng:NextNumber(-c.shake, c.shake)
		oy = rng:NextNumber(-c.shake, c.shake)
	end
	local cam = workspace.CurrentCamera
	cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0) * CFrame.Angles(0, 0, c.roll)
	cam.FieldOfView = math.clamp((State.baseFov or 70) + c.fovWarp, 30, 120)
end

--==================== ASSETS ====================
local ASSET_IDS = {
	Tattletail = 837048922,
	Shrek = 100513111509436,
	CocaCola = 8279338523,
	CocaColaTool = 16112607763,
	TungSahur = 136528368108736,
	Chick = 112458656748491,
	CowCar = 9904414343,
	SkibidiToilet = 115439748234383,
	GManToilet = 15258276852,
	SkibidiGMan = 15092283006,
}

local assetCache = {}

local function loadAsset(key)
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. ASSET_IDS[key])
	end)
	local obj = ok and type(objs) == "table" and objs[1] or nil
	if not obj then
		assetCache[key] = false
		return false
	end
	if obj:IsA("Tool") then
		local w = Instance.new("Model")
		for _, c in ipairs(obj:GetChildren()) do c.Parent = w end
		obj:Destroy()
		obj = w
	end
	-- Seguridad: nada de scripts ajenos corriendo en tu cliente.
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") then
			pcall(function() d:Destroy() end)
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	assetCache[key] = obj
	return true
end

local function preloadAssets()
	local okCount, fbCount = 0, 0
	for key in pairs(ASSET_IDS) do
		if loadAsset(key) then okCount += 1 else fbCount += 1 end
	end
	print(("[WTH] Assets cargados: %d | con stand-in procedural: %d"):format(okCount, fbCount))
end

-- Stand-ins procedurales para cuando un asset no está disponible o no existe (Whale, UFO, Train, Alien...).
local FALLBACK = {
	Tattletail = {{V(3, 4, 3), C(235, 190, 80), V(0, 2, 0), BL}, {V(2.6, 2.6, 2.6), C(235, 190, 80), V(0, 5.6, 0), BA},
		{V(0.7, 0.7, 0.3), C(20, 20, 20), V(-0.7, 5.9, -1.3), BA}, {V(0.7, 0.7, 0.3), C(20, 20, 20), V(0.7, 5.9, -1.3), BA},
		{V(1.2, 0.8, 0.6), C(230, 130, 60), V(-1.8, 2.2, 0), BL}, {V(1.2, 0.8, 0.6), C(230, 130, 60), V(1.8, 2.2, 0), BL},
		{V(0.9, 1.2, 0.9), C(200, 150, 60), V(-0.8, -0.6, 0), BL}, {V(0.9, 1.2, 0.9), C(200, 150, 60), V(0.8, -0.6, 0), BL}},
	Shrek = {{V(2.4, 3.2, 1.5), C(80, 160, 60), V(0, 2.6, 0), BL}, {V(2.4, 2.4, 2.4), C(90, 170, 70), V(0, 5.6, 0), BA},
		{V(0.6, 0.6, 0.3), C(255, 255, 255), V(-0.6, 5.8, -1.1), BA}, {V(0.6, 0.6, 0.3), C(255, 255, 255), V(0.6, 5.8, -1.1), BA},
		{V(0.4, 0.4, 0.2), C(20, 20, 20), V(-0.6, 5.8, -1.25), BA}, {V(0.4, 0.4, 0.2), C(20, 20, 20), V(0.6, 5.8, -1.25), BA},
		{V(1.6, 0.6, 0.5), C(80, 130, 60), V(0, 4.6, -0.8), BL},
		{V(0.9, 2.6, 0.9), C(80, 160, 60), V(-1.6, 2.4, 0), BL}, {V(0.9, 2.6, 0.9), C(80, 160, 60), V(1.6, 2.4, 0), BL}},
	CocaCola = {{V(3, 1.6, 1.6), C(220, 30, 30), V(0, 1, 0), CY}},
	TungSahur = {{V(2, 3, 2), C(120, 80, 40), V(0, 2, 0), BL}, {V(1.9, 1.9, 1.9), C(200, 160, 110), V(0, 4.8, 0), BA}},
	Chick = {{V(2, 2, 2), C(255, 220, 60), V(0, 1, 0), BA}, {V(0.8, 0.6, 0.8), C(255, 140, 30), V(0, 1.2, -1.1), BL},
		{V(0.3, 0.3, 0.2), C(20, 20, 20), V(-0.4, 1.5, -0.9), BA}, {V(0.3, 0.3, 0.2), C(20, 20, 20), V(0.4, 1.5, -0.9), BA},
		{V(0.4, 0.5, 0.3), C(255, 140, 30), V(-0.5, 0.2, 0.1), BL}, {V(0.4, 0.5, 0.3), C(255, 140, 30), V(0.5, 0.2, 0.1), BL}},
	CowCar = {
		{V(5, 2, 3), C(240, 240, 240), V(0, 1.5, 0), BL},
		{V(2.5, 1.5, 2.4), C(160, 160, 170), V(0, 3.2, 0.2), BL},
		{V(1, 1, 1), C(20, 20, 20), V(-1.8, 0.5, 1.4), BA},
		{V(1, 1, 1), C(20, 20, 20), V(1.8, 0.5, 1.4), BA},
		{V(1, 1, 1), C(20, 20, 20), V(-1.8, 0.5, -1.4), BA},
		{V(1, 1, 1), C(20, 20, 20), V(1.8, 0.5, -1.4), BA},
		{V(0.2, 0.9, 2.5), C(40, 40, 40), V(0, 0.9, 0), BL}, {V(0.6, 0.2, 0.6), C(255, 240, 180), V(2.4, 1.5, 0.8), BA},
		{V(0.6, 0.2, 0.6), C(255, 240, 180), V(2.4, 1.5, -0.8), BA},
	},
	Train = {{V(6, 3, 3), C(80, 100, 170), V(0, 1.5, 0), BL}, {V(6, 0.4, 3.2), C(60, 60, 70), V(0, 3.2, 0), BL}},
	Whale = {{V(24, 24, 24), C(90, 120, 170), V(0, 0, 0), BA}, {V(8, 8, 16), C(90, 120, 170), V(0, -1, -16), BL}},
	UFO = {{V(14, 14, 14), C(190, 200, 210), V(0, 0, 0), BA}, {V(7, 7, 7), C(150, 255, 200), V(0, 7, 0), BA},
		{V(16, 0.6, 16), C(120, 130, 150), V(0, -1.5, 0), CY}, {V(1.2, 1.2, 1.2), C(255, 255, 160), V(5, -1.5, 0), BA},
		{V(1.2, 1.2, 1.2), C(255, 255, 160), V(-5, -1.5, 0), BA}, {V(1.2, 1.2, 1.2), C(255, 255, 160), V(0, -1.5, 5), BA}},
	Alien = {{V(2, 2, 2), C(120, 255, 120), V(0, 1, 0), BA}, {V(0.8, 2, 0.8), C(60, 160, 60), V(0, 3, 0), BL}},
	SkibidiToilet = {{V(2, 2, 2), C(245, 245, 245), V(0, 1, 0), BL}, {V(2.6, 2.6, 2.6), C(230, 210, 180), V(0, 3.8, 0), BA},
		{V(2.2, 0.5, 2.2), C(220, 220, 225), V(0, 2.2, 0), CY}, {V(0.5, 0.5, 0.2), C(20, 20, 20), V(-0.6, 4.1, -1.2), BA},
		{V(0.5, 0.5, 0.2), C(20, 20, 20), V(0.6, 4.1, -1.2), BA}},
	GManToilet = {{V(3, 4, 3), C(245, 245, 245), V(0, 2, 0), BL}, {V(2.5, 2.5, 2.5), C(240, 240, 240), V(0, 5.5, 0), BA}},
	SkibidiGMan = {{V(3, 5, 2), C(25, 25, 30), V(0, 2.5, 0), BL}, {V(2.2, 2.2, 2.2), C(255, 220, 190), V(0, 6, 0), BA}},
	Default = {{V(2, 2, 2), C(160, 160, 160), V(0, 1, 0), BL}},
}
FALLBACK.CocaColaTool = FALLBACK.CocaCola

local function buildFallback(key)
	local def = FALLBACK[key] or FALLBACK.Default
	local m = Instance.new("Model")
	m.Name = key
	for i, d in ipairs(def) do
		local p = mkPart(d[1], d[2], CFrame.new(d[3]), {shape = d[4], name = key .. i})
		p.Parent = m
	end
	m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart")
	return m
end

local function instantiate(key)
	local tpl = assetCache[key]
	local m
	if tpl then
		m = tpl:Clone()
	else
		m = buildFallback(key)
	end
	if m:IsA("BasePart") then
		local w = Instance.new("Model")
		m.Parent = w
		m = w
	end
	if not m.PrimaryPart then
		m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true)
	end
	return m
end

--==================== SPAWN HELPERS ====================
local function spiralDebris(center, radius)
	local d = place(mkPart(V(0.6, 0.6, 0.6), C(255, 140, 60), CFrame.new(center + V(radius, 0, 0)), {material = Enum.Material.Neon, name = "Debris"}))
	if not d then return end
	local a0 = rng:NextNumber(0, math.pi * 2)
	addMover(function(dt, t)
		if not d.Parent then return false end
		local r = radius * math.max(0.05, 1 - t * 0.25)
		local a = a0 + t * (3 + 6 / (r + 1))
		d.CFrame = CFrame.new(center + V(math.cos(a) * r, -t * 0.2, math.sin(a) * r))
		if r < 1.5 then
			d:Destroy()
			return false
		end
	end, 6)
end

local function impact(pos, size)
	local boom = place(mkPart(V(1, 1, 1), C(255, 170, 70), CFrame.new(pos), {material = Enum.Material.Neon, shape = BA, transparency = 0.2, name = "Impact"}))
	if not boom then return end
	tween(boom, 0.6, {Size = V(size * 6, size * 6, size * 6), Transparency = 1})
	later(0.7, function()
		if boom.Parent then boom:Destroy() end
	end)
	-- cráter oscuro y anillo de choque en el suelo
	local crater = place(mkPart(V(0.3, 2, 2), C(35, 28, 22), CFrame.new(pos + V(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), {material = Enum.Material.Mud, shape = CY, name = "Crater"}))
	if crater then
		tween(crater, 1.2, {Size = V(0.3, size * 7, size * 7)})
		later(4, function()
			if crater.Parent then crater:Destroy() end
		end)
	end
	local shock = place(mkPart(V(0.4, 2, 2), C(255, 200, 140), CFrame.new(pos + V(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), {material = Enum.Material.Neon, shape = CY, transparency = 0.3, name = "Shock"}))
	if shock then
		tween(shock, 0.7, {Size = V(0.4, size * 10, size * 10), Transparency = 1})
		later(1, function()
			if shock.Parent then shock:Destroy() end
		end)
	end
	local d = (playerPos() - pos).Magnitude
	State.cam.shake = math.max(State.cam.shake, math.clamp(1 - d / 150, 0, 1) * 1.2)
end

local function dropMeteor(radius)
	local tp = randomAround(radius, 8)
	tp = V(tp.X, groundAt(tp), tp.Z)
	local start = tp + V(rng:NextNumber(-40, 40), 260, rng:NextNumber(-40, 40))
	local size = rng:NextNumber(2.5, 6)
	local m = place(mkPart(V(size, size, size), C(255, 110, 40), CFrame.new(start), {material = Enum.Material.Neon, shape = BA, name = "Meteor"}))
	if not m then return end
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 35
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(2, 6)
	pe.Size = NumberSequence.new(size * 0.4, 0)
	pe.Color = ColorSequence.new(C(255, 190, 70), C(120, 30, 0))
	pe.LightEmission = 1
	pe.Parent = m
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 25
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Size = NumberSequence.new(size * 0.6, size * 1.8)
	smoke.Color = ColorSequence.new(C(90, 90, 95), C(40, 40, 45))
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Parent = m
	local dir = (tp - start).Unit
	local speed = rng:NextNumber(160, 230)
	local pos = start
	addMover(function(dt)
		if not m.Parent then return false end
		pos += dir * speed * dt
		m.CFrame = m.CFrame * CFrame.Angles(dt * 6, dt * 4, 0)
		m.Position = pos
		if pos.Y <= tp.Y then
			impact(tp, size)
			m:Destroy()
			return false
		end
	end, 5)
end

local function dropProp(key, scale, radius)
	local tp = randomAround(radius, 8)
	local gy = groundAt(tp)
	local m = place(instantiate(key))
	if not m then return end
	if scale ~= 1 then pcall(function() m:ScaleTo(scale) end) end
	local halfH = m:GetExtentsSize().Y / 2
	local x, z = tp.X, tp.Z
	local y = gy + halfH + 170 + rng:NextNumber(0, 60)
	local v = 0
	local landedAt = nil
	local spin = rng:NextNumber(1, 4)
	addMover(function(dt, t)
		if not m.Parent then return false end
		if not landedAt then
			v -= 120 * dt
			y += v * dt
			if y <= gy + halfH then
				y = gy + halfH
				landedAt = t
			end
		elseif t - landedAt > 6 then
			m:Destroy()
			return false
		end
		local ang = spin * math.min(t, landedAt or t)
		m:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(ang, ang * 0.7, 0))
	end, 14)
end

-- Caminante / perseguidor / giganta. Sigue al jugador y se detiene a stopDist.
local function spawnWalker(key, origin, life, opts)
	opts = opts or {}
	local m = place(instantiate(key))
	if not m then return end
	if opts.scale and opts.scale ~= 1 then pcall(function() m:ScaleTo(opts.scale) end) end
	local halfH = m:GetExtentsSize().Y / 2
	local speed = opts.speed or 10
	local stopDist = opts.stop or 6
	local pos = origin
	local off = rng:NextNumber(0, 6)
	addMover(function(dt, t)
		if not m.Parent then return false end
		local pp = playerPos()
		local flat = V(pp.X - pos.X, 0, pp.Z - pos.Z)
		local dist = flat.Magnitude
		local dir = dist > 0.01 and flat.Unit or V(0, 0, -1)
		if dist > stopDist then pos += dir * speed * dt end
		local gy = groundAt(pos)
		local bob = math.abs(math.sin(t * 7 + off)) * 0.5
		local center = V(pos.X, gy + halfH + bob, pos.Z)
		m:PivotTo(CFrame.lookAt(center, center + dir))
		if dist < 14 then
			State.cam.shake = math.max(State.cam.shake, (1 - dist / 14) * 0.35)
		end
	end, life or 15)
end

-- Entidad que aparece, se queda y se desvanece (G-Man y compañía).
local function flashEntity(key, dist)
	local m = place(instantiate(key))
	if not m then return end
	local pp = playerPos()
	local p = randomAround(dist, 15)
	local gy = groundAt(p)
	local halfH = m:GetExtentsSize().Y / 2
	local base = V(p.X, gy + halfH, p.Z)
	m:PivotTo(CFrame.lookAt(base, V(pp.X, base.Y, pp.Z)))
	local parts = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			table.insert(parts, d)
		end
	end
	for _, d in ipairs(parts) do tween(d, 0.5, {Transparency = 0}) end
	State.cam.shake = math.max(State.cam.shake, 0.2)
	later(rng:NextNumber(2, 3.5), function()
		for _, d in ipairs(parts) do
			if d.Parent then tween(d, 0.6, {Transparency = 1}) end
		end
		later(0.7, function()
			if m.Parent then m:Destroy() end
		end)
	end)
end

--==================== EVENTOS ====================
local EVENTS = {}
local EVENT_BY_ID = {}
local function defEvent(t)
	table.insert(EVENTS, t)
	EVENT_BY_ID[t.id] = t
end

defEvent {
	id = "blackhole", title = "AGUJERO NEGRO DETECTADO", danger = 4, weight = 1,
	tags = {gravity = true, vortex = true}, dur = 24, cooldown = 45,
	descs = {
		"Masa invisible. Todo lo que está cerca empieza a estirarse hacia el centro.",
		"El horizonte de eventos avanza unos studs por segundo. No es buena señal.",
	},
	run = function(ctx)
		local center = skyPoint(ctx.dist * 0.6, 40)
		State.holeCenter = center
		local hole = place(mkPart(V(9, 9, 9), C(0, 0, 0), CFrame.new(center), {shape = BA, name = "BlackHole"}))
		if not hole then return end
		local ring = Instance.new("Model")
		ring.Name = "AccretionRing"
		local parts = {}
		for i = 1, 14 do
			local p = mkPart(V(3, 0.25, 0.25), C(255, 150, 60), CFrame.new(center), {material = Enum.Material.Neon, name = "Ring"})
			p.Parent = ring
			parts[i] = p
		end
		place(ring)
		local glow = place(mkPart(V(11, 11, 11), C(255, 120, 40), CFrame.new(center), {material = Enum.Material.Neon, shape = BA, transparency = 0.8, name = "HoleGlow"}))
		local acc = 0
		addMover(function(dt, t)
			if not hole.Parent then return false end
			local pulse = 1 + math.sin(t * 3) * 0.08
			hole.Size = V(9, 9, 9) * pulse
			if glow and glow.Parent then glow.Size = V(11, 11, 11) * (pulse + 0.1) end
			for i, p in ipairs(parts) do
				local a = t * 2.2 + i * (math.pi * 2 / 14)
				p.CFrame = CFrame.new(center) * CFrame.Angles(math.rad(70), a, 0) * CFrame.new(7 * pulse, 0, 0)
			end
			acc += dt
			if acc > 0.1 then
				acc = 0
				spiralDebris(center, 8 + rng:NextNumber(0, 5))
			end
			local near = math.clamp(1 - (playerPos() - center).Magnitude / 130, 0, 1)
			State.tg.blur = math.max(State.tg.blur, 4 + near * 12)
			State.tg.sat = math.min(State.tg.sat, -0.3 - near * 0.4)
			State.tg.contrast = math.max(State.tg.contrast, 0.3)
			State.cam.shake = math.max(State.cam.shake, near * 0.3)
		end, ctx.dur)
	end,
}

defEvent {
	id = "meteor", title = "LLUVIA DE CAGUAMAS DETECTADA", danger = 3, weight = 1.3,
	tags = {sky = true, impact = true}, dur = 18, cooldown = 25,
	descs = {
		"Caguamas de origen desconocido. Ninguna tiene etiqueta de reciclaje.",
		"Impacto estimado en tu posición. Probablemente.",
	},
	run = function(ctx)
		local count = 8 + math.floor(ctx.power * 12)
		for i = 1, count do
			later((i - 1) * 0.5 + rng:NextNumber(0, 0.4), function()
				dropMeteor(ctx.radius)
			end)
		end
	end,
}

defEvent {
	id = "tornado", title = "TORNADO DIMENSIONAL", danger = 3, weight = 1.1,
	tags = {ground = true, vortex = true}, dur = 22, cooldown = 35,
	descs = {
		"Vórtice de 9 pisos que se mueve sin permiso. Se llevó una silla.",
		"Recolecta cajas, objetos y un par de ideas malas.",
	},
	run = function(ctx)
		local origin = randomAround(ctx.dist * 0.7, 60)
		origin = V(origin.X, groundAt(origin), origin.Z)
		local model = Instance.new("Model")
		model.Name = "Tornado"
		local pieces = {}
		for i = 1, 9 do
			local w = 4 + i * 1.6
			local p = mkPart(V(4.5, w, w), C(105, 105, 118), CFrame.new(), {transparency = 0.35, shape = CY, name = "Funnel"})
			p.Parent = model
			pieces[i] = p
		end
		local debris = {}
		for i = 1, 8 do
			local d = mkPart(V(1, 1, 1) * rng:NextNumber(0.8, 1.8), C(150, 130, 110), CFrame.new(), {name = "Debris"})
			d.Parent = model
			debris[i] = d
		end
		if not place(model) then return end
		addMover(function(dt, t)
			if not model.Parent then return false end
			local base = origin + V(math.cos(t * 0.35) * 25, 0, math.sin(t * 0.35) * 25)
			for i, p in ipairs(pieces) do
				local wob = math.sin(t * 4 + i) * 1.2
				p.CFrame = CFrame.new(base + V(wob, (i - 0.5) * 4.5, 0)) * CFrame.Angles(0, t * (3 + i * 0.5), 0) * CFrame.Angles(0, 0, math.pi / 2)
			end
			for i, d in ipairs(debris) do
				local a = t * 3 + i * 0.8
				local h = (t * 2 + i * 3) % 36
				local r = 4 + h * 0.4
				d.CFrame = CFrame.new(base + V(math.cos(a) * r, h, math.sin(a) * r))
			end
			local dd = (playerPos() - base).Magnitude
			if dd < 80 then
				State.cam.shake = math.max(State.cam.shake, (1 - dd / 80) * 0.9)
			end
			State.tg.blur = math.max(State.tg.blur, math.clamp(1 - dd / 120, 0, 1) * 8)
		end, ctx.dur)
	end,
}

defEvent {
	id = "tsunami", title = "MAREMOTO VISUAL", danger = 3, weight = 1,
	tags = {ground = true, water = true}, dur = 16, cooldown = 40,
	descs = {
		"Ola de 70 studs. No hay agua, pero el pánico sí es real.",
		"Dirección: hacia ti. Ya no hay vuelta atrás.",
	},
	run = function(ctx)
		local pp = playerPos()
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = V(math.cos(a), 0, math.sin(a))
		local fwd = -dir
		local spawnPos = pp + dir * 300 + V(0, 35, 0)
		local wall = place(mkPart(V(180, 70, 22), C(40, 120, 200), CFrame.lookAt(spawnPos, spawnPos + fwd), {transparency = 0.2, material = Enum.Material.Glass, name = "Tsunami"}))
		if not wall then return end
		addMover(function(dt, t)
			if not wall.Parent then return false end
			local pos = wall.Position + fwd * 55 * dt
			wall.CFrame = CFrame.lookAt(pos, pos + fwd)
			if t > 9 then wall.Transparency = math.min(1, wall.Transparency + dt * 0.4) end
			local d = (playerPos() - pos).Magnitude
			local near = math.clamp(1 - d / 160, 0, 1)
			State.tg.tint = C(150, 200, 255)
			State.tg.atmo = C(110, 160, 255)
			State.tg.density = math.max(State.tg.density, 0.25)
			State.cam.shake = math.max(State.cam.shake, near * 1.0)
		end, ctx.dur)
	end,
}

defEvent {
	id = "dimstorm", title = "ANOMALÍA DIMENSIONAL", danger = 3, weight = 1.2,
	tags = {storm = true, sky = true}, dur = 25, cooldown = 30,
	descs = {
		"Grietas violetas abriendo el cielo. Se cierran solas. Probablemente.",
		"Lectura atmosférica: 'mal, pero con estilo'.",
	},
	run = function(ctx)
		local rm = Instance.new("Model")
		rm.Name = "Rifts"
		local rifts = {}
		for i = 1, 4 do
			local r = mkPart(V(0.6, 90, 0.6), C(190, 90, 255), CFrame.new(), {material = Enum.Material.Neon, name = "Rift"})
			r.Parent = rm
			rifts[i] = r
		end
		if not place(rm) then return end
		local nextFlash = 0
		addMover(function(dt)
			if not rm.Parent then return false end
			State.tg.tint = C(205, 160, 255)
			State.tg.atmo = C(150, 90, 255)
			State.tg.density = math.max(State.tg.density, 0.3)
			State.tg.contrast = math.max(State.tg.contrast, 0.25)
			State.tg.bloom = math.max(State.tg.bloom, 0.8)
			nextFlash -= dt
			if nextFlash <= 0 then
				nextFlash = rng:NextNumber(1.2, 4.5)
				State.cam.flash = 1
				for _, r in ipairs(rifts) do
					local p = randomAround(170, 40)
					r.CFrame = CFrame.new(p + V(0, 45, 0)) * CFrame.Angles(0, 0, rng:NextNumber(-0.5, 0.5))
					r.Transparency = rng:NextNumber(0, 0.5)
				end
			end
		end, ctx.dur)
	end,
}

defEvent {
	id = "lighting", title = "CAMBIO EXTREMO DE ILUMINACIÓN", danger = 2, weight = 1.1,
	tags = {sky = true, light = true}, dur = 16, cooldown = 25,
	descs = {"Tu ciclo solar fue reemplazado por un DJ. Son las 3 AM en cuatro colores."},
	run = function(ctx)
		local palette = {C(255, 70, 130), C(70, 255, 190), C(255, 220, 60), C(70, 100, 255), C(190, 70, 255)}
		for i = 0, math.floor(ctx.dur / 4) do
			later(i * 4, function()
				tween(Lighting, 3.5, {
					Ambient = pick(palette),
					OutdoorAmbient = pick(palette),
					ClockTime = rng:NextNumber(0, 24),
				}, Enum.EasingStyle.Sine)
			end)
		end
	end,
}

defEvent {
	id = "moon", title = "LUNA GIGANTE EN ÓRBITA", danger = 2, weight = 1,
	tags = {sky = true, light = true}, dur = 28, cooldown = 45,
	descs = {"Satélite no autorizado a 380 studs. Mareas: sí. Permiso: no."},
	run = function(ctx)
		local center = skyPoint(380, 240)
		local moon = place(mkPart(V(150, 150, 150), C(215, 215, 230), CFrame.new(center), {shape = BA, material = Enum.Material.Neon, name = "GiantMoon"}))
		if not moon then return end
		addMover(function(dt, t)
			if not moon.Parent then return false end
			moon.Position = center + V(0, math.sin(t * 0.2) * 20, 0)
			State.tg.bloom = math.max(State.tg.bloom, 0.3)
		end, ctx.dur)
	end,
}

defEvent {
	id = "sun", title = "SOL DUPLICADO DETECTADO", danger = 2, weight = 1,
	tags = {sky = true, light = true}, dur = 28, cooldown = 45,
	descs = {"Dos soles. Uno de ellos parece un globo de cumpleaños gigante."},
	run = function(ctx)
		local pos = skyPoint(300, 200)
		local sun = place(mkPart(V(90, 90, 90), C(255, 230, 90), CFrame.new(pos), {shape = BA, material = Enum.Material.Neon, name = "FakeSun"}))
		if not sun then return end
		local light = Instance.new("PointLight")
		light.Range = 260
		light.Brightness = 3
		light.Color = C(255, 230, 120)
		light.Parent = sun
		addMover(function()
			if not sun.Parent then return false end
			State.tg.bloom = math.max(State.tg.bloom, 1.2)
			State.tg.tint = C(255, 245, 220)
		end, ctx.dur)
	end,
}

defEvent {
	id = "invert", title = "INVERSIÓN DEL CIELO", danger = 4, weight = 0.8, exclusive = true,
	tags = {sky = true, camera = true}, dur = 15, cooldown = 60,
	descs = {
		"Arriba es abajo. Tu personaje no se entera, pero tú sí.",
		"La gravedad sigue igual. Eso es lo más preocupante.",
	},
	run = function(ctx)
		State.cam.rollTarget = math.pi
		later(ctx.dur - 3, function()
			State.cam.rollTarget = 0
		end)
		addMover(function()
			State.tg.tint = C(180, 255, 200)
		end, ctx.dur)
	end,
}

defEvent {
	id = "falling", title = "OBJETOS EN CAÍDA", danger = 2, weight = 1.1,
	tags = {sky = true, props = true}, dur = 18, cooldown = 20,
	descs = {
		"Latas, pollitos y un auto de vacas. Ninguno trae paracaídas.",
		"Lluvia de objetos con estilo de caricatura.",
	},
	run = function(ctx)
		local keys = {"CocaCola", "CocaColaTool", "Chick", "CowCar"}
		local count = 8 + math.floor(ctx.power * 10)
		for i = 1, count do
			later((i - 1) * 0.7 + rng:NextNumber(0, 0.5), function()
				dropProp(pick(keys), rng:NextNumber(0.9, 1.6), ctx.radius)
			end)
		end
	end,
}

defEvent {
	id = "whale", title = "BALLENA AÉREA DETECTADA", danger = 2, weight = 0.9,
	tags = {sky = true, props = true}, dur = 20, cooldown = 30,
	descs = {
		"Ballena de 40 studs nadando en el aire. Aerodinámicamente no debería existir.",
		"Respira. Se escucha desde tu casa.",
	},
	run = function(ctx)
		local m = place(instantiate("Whale"))
		if not m then return end
		local center = playerPos() + V(0, 150, 0)
		local a0 = rng:NextNumber(0, math.pi * 2)
		local sign = rng:NextNumber() < 0.5 and 1 or -1
		addMover(function(dt, t)
			if not m.Parent then return false end
			local ang = a0 + t * 0.12 * sign
			local pos = center + V(math.cos(ang) * 260, math.sin(t * 0.8) * 25, math.sin(ang) * 260)
			local tangent = V(-math.sin(ang), 0, math.cos(ang)) * sign
			m:PivotTo(CFrame.lookAt(pos, pos + tangent))
		end, ctx.dur)
	end,
}

defEvent {
	id = "trains", title = "TREN VOLADOR EN RUTA", danger = 2, weight = 0.9,
	tags = {sky = true, props = true}, dur = 22, cooldown = 30,
	descs = {
		"Vagones sin vías. Maquinista: nadie. Destino: tu cabeza.",
		"Tren de cuatro vagones con vacas de copiloto.",
	},
	run = function(ctx)
		local train = Instance.new("Model")
		train.Name = "FlyingTrain"
		local cars = {}
		for i = 1, 4 do
			local car = instantiate(i % 2 == 0 and "CowCar" or "Train")
			car.Parent = train
			cars[i] = car
		end
		if not place(train) then return end
		local center = playerPos() + V(0, 110, 0)
		local a0 = rng:NextNumber(0, math.pi * 2)
		addMover(function(dt, t)
			if not train.Parent then return false end
			for i, car in ipairs(cars) do
				local ang = a0 + t * 0.25 - (i - 1) * 0.12
				local pos = center + V(math.cos(ang) * 190, math.sin(ang * 2) * 8, math.sin(ang) * 190)
				local tangent = V(-math.sin(ang), 0, math.cos(ang))
				car:PivotTo(CFrame.lookAt(pos, pos + tangent))
			end
		end, ctx.dur)
	end,
}

defEvent {
	id = "portal", title = "PORTAL DIMENSIONAL ABIERTO", danger = 3, weight = 1,
	tags = {portal = true, entity = true}, dur = 20, cooldown = 30,
	descs = {"Un agujero con marco de neón. Dentro hay gente que no pidió salir."},
	run = function(ctx)
		local p = randomAround(ctx.dist * 0.5, 40)
		local gy = groundAt(p)
		local center = V(p.X, gy + 9, p.Z)
		local pm = Instance.new("Model")
		pm.Name = "Portal"
		local ringPart = mkPart(V(0.5, 16, 16), C(180, 80, 255), CFrame.new(), {material = Enum.Material.Neon, shape = CY, name = "PortalRing"})
		local core = mkPart(V(0.3, 13, 13), C(20, 0, 40), CFrame.new(), {shape = CY, transparency = 0.25, name = "PortalCore"})
		ringPart.Parent = pm
		core.Parent = pm
		if not place(pm) then return end
		local pp = playerPos()
		local facing = CFrame.lookAt(center, V(pp.X, center.Y, pp.Z)) * CFrame.Angles(0, math.pi / 2, 0)
		ringPart.CFrame = facing
		core.CFrame = facing
		local timer = 0
		addMover(function(dt, t)
			if not pm.Parent then return false end
			local s = 12 + math.sin(t * 4) * 1.5
			core.Size = V(0.3, s, s)
			timer -= dt
			if timer <= 0 and t < ctx.dur - 4 then
				timer = 3.5
				local key = pick({"Tattletail", "Shrek", "Chick", "TungSahur", "SkibidiGMan"})
				spawnWalker(key, V(center.X, gy, center.Z), 15, {speed = rng:NextNumber(8, 14), stop = 8})
			end
		end, ctx.dur)
	end,
}

defEvent {
	id = "distortion", title = "DISTORSIÓN VISUAL", danger = 2, weight = 1.2,
	tags = {camera = true, storm = true}, dur = 14, cooldown = 25,
	descs = {
		"Tu cámara procesa algo que tu cerebro todavía no entiende.",
		"Ojo de pez, tono VHS. Muy retro, muy incómodo.",
	},
	run = function(ctx)
		addMover(function(dt, t)
			State.tg.blur = math.max(State.tg.blur, 6 + math.sin(t * 2) * 4)
			State.tg.fov = math.sin(t * 1.3) * 12
			State.tg.sat = math.min(State.tg.sat, -0.2 + math.sin(t * 3) * 0.5)
			State.tg.tint = Color3.new(1, 0.8 + math.sin(t * 5) * 0.2, 1)
			State.cam.shake = math.max(State.cam.shake, 0.05 + math.abs(math.sin(t * 7)) * 0.08)
		end, ctx.dur)
	end,
}

defEvent {
	id = "gravity", title = "GRAVEDAD INESTABLE", danger = 3, weight = 1,
	tags = {camera = true, gravity = true}, dur = 12, cooldown = 30,
	descs = {
		"La gravedad se tomó el día libre. Tu cámara flota con ella.",
		"Objetos levitando alrededor. Ninguno está atado a un hilo invisible.",
	},
	run = function(ctx)
		local fm = Instance.new("Model")
		fm.Name = "Floaters"
		local items = {}
		for i = 1, 14 do
			local s = rng:NextNumber(0.8, 2.5)
			local p = mkPart(V(s, s, s), Color3.fromHSV(rng:NextNumber(), 0.6, 1), CFrame.new(), {name = "Floater"})
			p.Parent = fm
			items[i] = {part = p, a = rng:NextNumber(0, math.pi * 2), r = rng:NextNumber(6, 40), s = rng:NextNumber(0.5, 1.5)}
		end
		if not place(fm) then return end
		addMover(function(dt, t)
			if not fm.Parent then return false end
			local pp = playerPos()
			for _, it in ipairs(items) do
				local y = 6 + (math.sin(t * it.s + it.a) * 0.5 + 0.5) * 22
				local ang = it.a + t * 0.4
				it.part.CFrame = CFrame.new(pp + V(math.cos(ang) * it.r, y, math.sin(ang) * it.r)) * CFrame.Angles(t * it.s, t * it.s * 0.7, 0)
			end
			State.tg.fov = math.sin(t * 1.1) * 10
			State.cam.shake = math.max(State.cam.shake, 0.04)
		end, ctx.dur)
	end,
}

defEvent {
	id = "invasion", title = "INVASIÓN EXTRATERRESTRE", danger = 4, weight = 1,
	tags = {entity = true, sky = true}, dur = 25, cooldown = 45,
	descs = {
		"Naves en formación sobre tu zona. Piden hablar con tu jefe.",
		"Traen un recibo de luz pendiente. Esto ya es personal.",
	},
	run = function(ctx)
		for _ = 1, 3 do
			local ufo = place(instantiate("UFO"))
			if ufo then
				local base = skyPoint(ctx.dist * 0.7, 120)
				local target = randomAround(90, 20)
				target = V(target.X, groundAt(target), target.Z)
				local beam = mkPart(V(10, 6, 6), C(120, 255, 160), CFrame.new(), {material = Enum.Material.Neon, transparency = 0.45, shape = CY, name = "Beam"})
				beam.Parent = ufo
				local a0 = rng:NextNumber(0, math.pi * 2)
				local nextAlien = rng:NextNumber(2, 4)
				addMover(function(dt, t)
					if not ufo.Parent then return false end
					local ang = a0 + t * 0.15
					local pos = base + V(math.cos(ang) * 40, math.sin(t * 1.5) * 3, math.sin(ang) * 40)
					ufo:PivotTo(CFrame.new(pos) * CFrame.Angles(0, ang, 0))
					local top = pos - V(0, 4, 0)
					local len = (top - target).Magnitude
					beam.Size = V(len, 6, 6)
					beam.CFrame = CFrame.lookAt((top + target) / 2, top) * CFrame.Angles(0, math.pi / 2, 0)
					nextAlien -= dt
					if nextAlien <= 0 and t < ctx.dur - 5 then
						nextAlien = rng:NextNumber(3, 5)
						spawnWalker("Alien", target, 14, {speed = 14, stop = 6})
					end
					State.tg.tint = C(180, 255, 190)
					State.tg.bloom = math.max(State.tg.bloom, 0.4)
				end, ctx.dur)
			end
		end
	end,
}

defEvent {
	id = "giants", title = "MULTIPLE ENTITIES DETECTED", danger = 3, weight = 1,
	tags = {entity = true, ground = true}, dur = 22, cooldown = 35,
	descs = {
		"Figuras gigantes en el horizonte. Caminan despacio, pero llegan.",
		"Escala 5x. El comportamiento también.",
	},
	run = function(ctx)
		spawnWalker("Shrek", randomAround(230, 180), ctx.dur, {scale = 5, speed = 9, stop = 80})
		spawnWalker("SkibidiToilet", randomAround(230, 180), ctx.dur, {scale = 4, speed = 8, stop = 80})
	end,
}

defEvent {
	id = "npcs", title = "MULTIPLE ENTITIES DETECTED", danger = 2, weight = 1.1,
	tags = {entity = true, ground = true}, dur = 20, cooldown = 25,
	descs = {
		"NPCs sin guion persiguiéndote. Ninguno sabe por qué está aquí.",
		"Grupo de cuatro. Uno de ellos sabe cantar. Lo sentimos.",
	},
	run = function(ctx)
		local keys = {"TungSahur", "Shrek", "Tattletail", "Chick"}
		for i = 1, 4 do
			later((i - 1) * 0.8, function()
				spawnWalker(pick(keys), randomAround(120, 60), ctx.dur - 2, {speed = rng:NextNumber(10, 16), stop = 6})
			end)
		end
	end,
}

defEvent {
	id = "ghosts", title = "ENTIDAD DESCONOCIDA", danger = 2, weight = 1,
	tags = {entity = true}, dur = 15, cooldown = 20,
	descs = {
		"Presencia detectada. Aparece, saluda y se va. Muy educada.",
		"Ojos sin pupilas. Traje perfecto. Mala señal.",
	},
	run = function(ctx)
		for i = 0, math.floor(ctx.dur / 3) do
			later(i * 3 + rng:NextNumber(0, 1), function()
				flashEntity(pick({"SkibidiGMan", "GManToilet"}), ctx.dist * 0.25)
			end)
		end
	end,
}

defEvent {
	id = "collapse", title = "COLAPSO DE LA REALIDAD", danger = 5, weight = 0.5, exclusive = true,
	tags = {camera = true, storm = true, portal = true}, dur = 30, cooldown = 90,
	descs = {
		"Todo a la vez. Sí, incluso lo que dijimos que no iba a pasar.",
		"Tu realidad está en modo cooperativo con cinco eventos.",
	},
	run = function(ctx)
		for _, id in ipairs({"dimstorm", "distortion", "portal", "giants", "meteor"}) do
			local ev = EVENT_BY_ID[id]
			if ev then
				pcall(ev.run, {dist = ctx.dist, power = ctx.power, dur = ctx.dur, radius = ctx.radius})
			end
		end
		addMover(function(dt, t)
			State.cam.rollTarget = math.sin(t * 0.6) * 0.6
			State.cam.shake = math.max(State.cam.shake, 0.25)
			State.tg.blur = math.max(State.tg.blur, 10)
		end, ctx.dur)
	end,
}

-- Sinergias: combinaciones que disparan efectos extra cuando ambos eventos están activos.
local COMBOS = {
	{need = {"blackhole", "meteor"}, title = "LLUVIA SUCCIONADA",
		desc = "Las caguamas caen en espiral hacia el agujero. Respeto.",
		run = function()
			local c = State.holeCenter
			if not c then return end
			for i = 1, 10 do
				later(i * 0.25, function() spiralDebris(c, 12 + rng:NextNumber(0, 6)) end)
			end
		end},
	{need = {"tornado", "tsunami"}, title = "TIFÓN MARINO",
		desc = "Un segundo tornado decidió unirse a la fiesta.",
		run = function(ctx)
			EVENT_BY_ID.tornado.run({dist = ctx.dist, power = ctx.power, dur = ctx.dur, radius = ctx.radius})
		end},
	{need = {"dimstorm", "portal"}, title = "PORTAL EN TORMENTA",
		desc = "El portal se abrió dentro de la tormenta. Nadie sabe qué salió primero.",
		run = function(ctx)
			local p = randomAround(90, 30)
			spawnWalker("SkibidiGMan", p, 12, {speed = 12, stop = 8})
			State.cam.flash = 1
		end},
	{need = {"invasion", "giants"}, title = "FLOTA GIGANTE",
		desc = "Un gigante extra llegó en la nave de reserva.",
		run = function()
			spawnWalker("Shrek", randomAround(260, 200), 16, {scale = 6, speed = 8, stop = 90})
		end},
	{need = {"sun", "moon"}, title = "ECLIPSE FORZADO",
		desc = "Sol y luna compitiendo por el mismo cielo. Gana el ruido.",
		run = function()
			State.cam.flash = 1
			State.cam.shake = math.max(State.cam.shake, 0.8)
			State.tg.density = math.max(State.tg.density, 0.4)
		end},
}
State.comboAt = {}

--==================== DIRECTOR ====================
local DANGER_NAMES = {"BAJO", "MODERADO", "ALTO", "CRÍTICO", "EXTREMO"}
local DANGER_COLORS = {
	C(80, 200, 120), C(230, 220, 80), C(255, 150, 60), C(255, 70, 70), C(200, 60, 255),
}
local NAME_A = {"Vórtice", "Rasgón", "Eclipse", "Ola", "Ojo", "Tormenta", "Colapso", "Entidad", "Nube", "Portal"}
local NAME_B = {"Ocho", "Carmesí", "Sin Fondo", "Tostado", "Blindado", "Gris", "Cósmico", "Mojado", "Hiperactivo", "Olvidado"}
local EXTRA_DESCS = {
	"Probabilidad de que nada de esto sea real: 3.7%.",
	"Recomendación oficial: no mirar hacia arriba. Ya es tarde.",
	"El director de caos opina que esto es 'el mejor día del año'.",
}

local function randomName()
	return pick(NAME_A) .. " " .. pick(NAME_B) .. " MK-" .. rng:NextInteger(10, 99)
end

local function pickEvent()
	local now = os.clock()
	local tags = {}
	for _, a in ipairs(State.active) do
		for tag in pairs(a.event.tags) do tags[tag] = true end
	end
	local scores, total = {}, 0
	for i, ev in ipairs(EVENTS) do
		local s = ev.weight
		local blocked = (now - (State.lastUsed[ev.id] or -999)) < (ev.cooldown or 20)
		for _, a in ipairs(State.active) do
			if a.event.id == ev.id or (ev.exclusive and a.event.exclusive) then blocked = true end
		end
		if blocked then
			s = 0
		else
			for _, hid in ipairs(State.history) do
				if hid == ev.id then s *= 0.3 end
			end
			-- Más peligro cuando sube el caos
			s *= 1 + (ev.danger / 5) * State.power * 1.5
			-- Sinergia: los eventos que combinan con lo activo pesan más
			for tag in pairs(ev.tags) do
				if tags[tag] then s *= 1.35 end
			end
		end
		scores[i] = s
		total += s
	end
	if total <= 0 then return nil end
	local r = rng:NextNumber(0, total)
	for i, s in ipairs(scores) do
		r -= s
		if r <= 0 and s > 0 then return EVENTS[i] end
	end
	return nil
end

local function computeStability()
	local sum = 0
	for _, a in ipairs(State.active) do sum += a.event.danger * 3.2 end
	return math.max(0, math.floor(100 - sum))
end

local function endEvent(entry)
	for i = #State.active, 1, -1 do
		if State.active[i] == entry then table.remove(State.active, i) end
	end
	for _, c in ipairs(root:GetChildren()) do
		if c:GetAttribute("ev") == entry.token then c:Destroy() end
	end
	updateHUD()
end

local function checkCombos(ev, ctx)
	local ids = {}
	for _, a in ipairs(State.active) do ids[a.event.id] = true end
	for _, c in ipairs(COMBOS) do
		local a, b = c.need[1], c.need[2]
		local involved = ev.id == a or ev.id == b
		if involved and ids[a] and ids[b] and (os.clock() - (State.comboAt[c.title] or -999)) > 30 then
			State.comboAt[c.title] = os.clock()
			showAlert("SINERGIA: " .. c.title, 5, c.desc, randomName(), CONFIG.AlertDuration)
			local ok, err = pcall(c.run, ctx)
			if not ok then warn("[WTH] combo: " .. tostring(err)) end
		end
	end
end

local function triggerEvent(ev)
	State.tokenCount += 1
	State.curToken = State.tokenCount
	table.insert(State.active, {event = ev, token = State.curToken, endsAt = os.clock() + ev.dur})
	State.lastUsed[ev.id] = os.clock()
	table.insert(State.history, ev.id)
	while #State.history > CONFIG.HistorySize do table.remove(State.history, 1) end

	local ctx = {dist = 170 + State.power * 120, power = State.power, dur = ev.dur, radius = 110}
	local ok, err = pcall(ev.run, ctx)
	if not ok then warn("[WTH] " .. ev.id .. ": " .. tostring(err)) end

	showAlert(ev.title, ev.danger, pick(ev.descs), randomName(), CONFIG.AlertDuration)
	checkCombos(ev, ctx)

	if #State.active >= 3 and os.clock() - State.multiAlertAt > 30 then
		State.multiAlertAt = os.clock()
		showAlert("MULTIPLE ENTITIES DETECTED", 4, "Tres o más anomalías activas. Esto ya no es un simulador, es un problema.", "NIVEL DE CAOS: ELEVADO", CONFIG.AlertDuration)
	end
	updateHUD()
end

local function triggerNext(force)
	if #State.active >= CONFIG.MaxActiveEvents then return false end
	local ev = pickEvent()
	if not ev and force then ev = pick(EVENTS) end
	if not ev then return false end
	triggerEvent(ev)
	return true
end

local function updateDirector(dt)
	State.chaosTime += dt
	State.power = math.min(1, State.intensity + State.chaosTime / 480 * 0.5)
	State.timer -= dt
	if State.timer <= 0 then
		triggerNext(false)
		State.timer = math.max(2, CONFIG.BaseInterval * (1.6 - State.frequency * 1.2) * (1 - State.power * 0.35))
	end
end

local function onHeartbeat(dt)
	if State.destroyed then return end
	State.tg = defaultTargets()
	if State.running then updateDirector(dt) end
	runMovers(dt)
	ambientStep(dt)
	local now = os.clock()
	for i = #State.active, 1, -1 do
		local a = State.active[i]
		if now >= a.endsAt then endEvent(a) end
	end
	State.hudAcc += dt
	if State.hudAcc > 0.3 then
		State.hudAcc = 0
		updateHUD()
	end
end

local function cleanAll()
	State.session += 1
	State.active = {}
	State.movers = {}
	for _, tw in ipairs(State.tweens) do tw:Cancel() end
	State.tweens = {}
	root:ClearAllChildren()
	State.objectCount = 0
	State.cam.rollTarget = 0
	State.cam.roll = 0
	State.cam.shake = 0
	State.cam.flash = 0
	State.cam.fovWarp = 0
	State.tg = defaultTargets()
end

local function startChaos()
	if State.running then return end
	if not State.lightingBackup then
		backupLighting()
		setupFx()
	end
	State.running = true
	State.chaosTime = 0
	State.timer = 1.5
	showAlert("REALIDAD INESTABLE", 2, "Sistema iniciado. Nada de esto es culpa del script.", "ESTADO: CAOS ACTIVO", CONFIG.AlertDuration)
	updateHUD()
end

local function stopChaos()
	State.running = false
	cleanAll()
	restoreVisuals()
	updateHUD()
end

local function restoreReality()
	stopChaos()
	State.intensity = 0.4
	State.frequency = 0.5
	State.history = {}
	State.lastUsed = {}
	State.comboAt = {}
	showAlert("REALIDAD RESTAURADA", 1, "Todo volvió a la normalidad. Por ahora.", "ESTADO: ESTABLE", 3)
	updateHUD()
end

--==================== ALERTAS ====================
local function label(parent, text, size, color, font, h, autoY)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, h or 0)
	if autoY then l.AutomaticSize = Enum.AutomaticSize.Y end
	l.Font = font or Enum.Font.GothamMedium
	l.TextSize = size or 14
	l.TextColor3 = color or C(255, 255, 255)
	l.Text = text or ""
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

showAlert = function(title, danger, desc, sub, dur)
	local container = State.ui.alerts
	if not container then return end
	local col = DANGER_COLORS[danger] or DANGER_COLORS[2]

	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = C(12, 12, 20)
	f.BackgroundTransparency = 0.1
	f.BorderSizePixel = 0
	f.Parent = container
	corner(f, 10)
	stroke(f, col, 2)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = f

	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 2)
	lay.Parent = f

	local sc = Instance.new("UIScale")
	sc.Scale = 0.5
	sc.Parent = f
	tween(sc, 0.35, {Scale = 1}, Enum.EasingStyle.Back)

	local t1 = label(f, title, 15, col, Enum.Font.GothamBlack, nil, true)
	local t2 = label(f, sub or "", 12, C(230, 230, 240), Enum.Font.GothamBold, nil, true)
	local t3 = label(f, desc or "", 12, C(190, 190, 205), Enum.Font.GothamMedium, nil, true)
	local t4 = label(f, "PELIGRO: " .. DANGER_NAMES[danger] .. " (" .. danger .. "/5)", 12, col, Enum.Font.GothamBold, nil, true)
	t1.LayoutOrder, t2.LayoutOrder, t3.LayoutOrder, t4.LayoutOrder = 1, 2, 3, 4

	local old = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Frame") then table.insert(old, c) end
	end
	while #old > CONFIG.MaxAlerts do
		table.remove(old, 1):Destroy()
	end

	task.delay(dur or CONFIG.AlertDuration, function()
		if not f.Parent then return end
		for _, l in ipairs({t1, t2, t3, t4}) do
			tween(l, 0.4, {TextTransparency = 1})
		end
		tween(f, 0.4, {BackgroundTransparency = 1})
		tween(sc, 0.4, {Scale = 0.7})
		task.delay(0.45, function()
			if f then f:Destroy() end
		end)
	end)
end

--==================== UI ====================
local function button(parent, text, color, w, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(w, -3, 1, 0)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = C(255, 255, 255)
	b.Text = text
	b.Parent = parent
	corner(b, 8)
	b.Activated:Connect(cb)
	return b
end

local function rowFrame(parent, h)
	local r = Instance.new("Frame")
	r.Size = UDim2.new(1, 0, 0, h or 34)
	r.BackgroundTransparency = 1
	r.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = r
	return r
end

local function buildUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WTH_UI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	State.ui.gui = gui

	local uiScale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 720, 0.6, 1)

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.fromOffset(300, 0)
	main.AutomaticSize = Enum.AutomaticSize.Y
	main.Position = UDim2.new(0, 14, 0.12, 0)
	main.BackgroundColor3 = C(14, 14, 22)
	main.BackgroundTransparency = 0.05
	main.BorderSizePixel = 0
	main.Active = true
	main.Parent = gui
	corner(main, 12)
	stroke(main, C(255, 80, 200), 2)

	local sc = Instance.new("UIScale")
	sc.Scale = uiScale
	sc.Parent = main

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = main

	local lay = Instance.new("UIListLayout")
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 6)
	lay.Parent = main

	-- Header arrastrable (ratón y táctil)
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Active = true
	header.LayoutOrder = 1
	header.Parent = main
	label(header, "WHAT_THE_HELL.lua", 18, C(255, 120, 220), Enum.Font.GothamBlack, 30).TextXAlignment = Enum.TextXAlignment.Center

	local dragging, dragStart, startPos = false, nil, nil
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	table.insert(State.conns, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
	table.insert(State.conns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	local status = label(main, "ESTADO: REALIDAD ESTABLE", 12, C(150, 255, 200), Enum.Font.GothamBold, 18)
	status.LayoutOrder = 2
	State.ui.status = status

	local stabLabel = label(main, "REALITY STABILITY: 100%", 14, C(255, 255, 255), Enum.Font.GothamBlack, 20)
	stabLabel.LayoutOrder = 3
	State.ui.stabilityLabel = stabLabel

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, 0, 0, 14)
	barBg.BackgroundColor3 = C(40, 40, 55)
	barBg.BorderSizePixel = 0
	barBg.LayoutOrder = 4
	barBg.Parent = main
	corner(barBg, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = C(80, 255, 120)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	corner(fill, 6)
	State.ui.fill = fill

	local r1 = rowFrame(main)
	r1.LayoutOrder = 5
	button(r1, "Start Chaos", C(40, 160, 90), 0.5, startChaos)
	button(r1, "Stop Chaos", C(170, 90, 40), 0.5, stopChaos)

	local r2 = rowFrame(main)
	r2.LayoutOrder = 6
	button(r2, "Random Disaster", C(120, 60, 200), 0.5, function()
		startChaos()
		triggerNext(true)
	end)
	button(r2, "Maximum Chaos", C(220, 90, 30), 0.5, function()
		State.intensity = 1
		State.frequency = 1
		startChaos()
		for i = 0, 2 do
			later(i * 0.8, function() triggerNext(true) end)
		end
		updateHUD()
	end)

	local freqRow = rowFrame(main, 30)
	freqRow.LayoutOrder = 7
	local freqLabel = label(freqRow, "", 12, C(220, 220, 235), Enum.Font.GothamBold, nil)
	freqLabel.Size = UDim2.new(0.5, 0, 1, 0)
	freqLabel.TextYAlignment = Enum.TextYAlignment.Center
	State.ui.freqLabel = freqLabel
	button(freqRow, "-", C(60, 60, 80), 0.22, function()
		State.frequency = math.clamp(math.floor((State.frequency - 0.1) * 10 + 0.5) / 10, 0.1, 1)
		updateHUD()
	end)
	button(freqRow, "+", C(60, 60, 80), 0.22, function()
		State.frequency = math.clamp(math.floor((State.frequency + 0.1) * 10 + 0.5) / 10, 0.1, 1)
		updateHUD()
	end)

	local intRow = rowFrame(main, 30)
	intRow.LayoutOrder = 8
	local intLabel = label(intRow, "", 12, C(220, 220, 235), Enum.Font.GothamBold, nil)
	intLabel.Size = UDim2.new(0.5, 0, 1, 0)
	intLabel.TextYAlignment = Enum.TextYAlignment.Center
	State.ui.intLabel = intLabel
	button(intRow, "-", C(60, 60, 80), 0.22, function()
		State.intensity = math.clamp(math.floor((State.intensity - 0.1) * 10 + 0.5) / 10, 0, 1)
		updateHUD()
	end)
	button(intRow, "+", C(60, 60, 80), 0.22, function()
		State.intensity = math.clamp(math.floor((State.intensity + 0.1) * 10 + 0.5) / 10, 0, 1)
		updateHUD()
	end)

	local timesList = {3, 4.5, 7}
	local timeIdx = 2
	local r3 = rowFrame(main)
	r3.LayoutOrder = 9
	local timeBtn = button(r3, "Alert duration: 4.5s", C(50, 70, 110), 1, function()
		timeIdx = timeIdx % #timesList + 1
		CONFIG.AlertDuration = timesList[timeIdx]
		State.ui.timeBtn.Text = "Alert duration: " .. CONFIG.AlertDuration .. "s"
	end)
	State.ui.timeBtn = timeBtn

	local activeLabel = label(main, "", 12, C(200, 200, 215), Enum.Font.GothamMedium, nil, true)
	activeLabel.LayoutOrder = 10
	State.ui.activeLabel = activeLabel

	local r4 = rowFrame(main)
	r4.LayoutOrder = 11
	button(r4, "Restore Reality", C(150, 30, 40), 1, restoreReality)

	-- Contenedor de alertas (arriba al centro)
	local alerts = Instance.new("Frame")
	alerts.Name = "Alerts"
	alerts.AnchorPoint = Vector2.new(0.5, 0)
	alerts.Position = UDim2.new(0.5, 0, 0.02, 0)
	alerts.Size = UDim2.new(0, 340, 0, 0)
	alerts.AutomaticSize = Enum.AutomaticSize.Y
	alerts.BackgroundTransparency = 1
	alerts.Parent = gui
	local alayout = Instance.new("UIListLayout")
	alayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	alayout.Padding = UDim.new(0, 6)
	alayout.SortOrder = Enum.SortOrder.LayoutOrder
	alayout.Parent = alerts
	local ascale = Instance.new("UIScale")
	ascale.Scale = uiScale
	ascale.Parent = alerts
	State.ui.alerts = alerts
end

updateHUD = function()
	local ui = State.ui
	if not ui.stabilityLabel then return end
	local s = computeStability()
	ui.stabilityLabel.Text = "REALITY STABILITY: " .. s .. "%"
	ui.fill.Size = UDim2.new(s / 100, 0, 1, 0)
	ui.fill.BackgroundColor3 = Color3.new(math.clamp(1 - s / 100 * 0.8, 0, 1), math.clamp(s / 100 * 0.9, 0, 1), 0.2)
	ui.status.Text = State.running and "ESTADO: CAOS ACTIVO" or "ESTADO: REALIDAD ESTABLE"
	ui.status.TextColor3 = State.running and C(255, 110, 150) or C(150, 255, 200)
	ui.freqLabel.Text = "Event Frequency: " .. math.floor(State.frequency * 100 + 0.5) .. "%"
	ui.intLabel.Text = "Chaos Intensity: " .. math.floor(State.intensity * 100 + 0.5) .. "%"
	local names = {}
	for _, a in ipairs(State.active) do table.insert(names, a.event.id) end
	ui.activeLabel.Text = "Active Events (" .. #State.active .. "/" .. CONFIG.MaxActiveEvents .. "): " .. (#names > 0 and table.concat(names, ", ") or "ninguno")
end

--==================== INIT ====================
local function init()
	buildUI()
	State.baseFov = workspace.CurrentCamera.FieldOfView
	RunService:BindToRenderStep(CAM_BIND, Enum.RenderPriority.Camera.Value + 1, cameraStep)
	table.insert(State.conns, RunService.Heartbeat:Connect(onHeartbeat))
	task.spawn(preloadAssets)
	updateHUD()
	print("[WTH] Listo. Pulsa Start Chaos y que el universo decida.")
end

init()
end

-- ===================== MÓDULO: PLUS (golpes y cura) =====================
do
-- WHAT_THE_HELL_PLUS.lua | LocalScript add-on, StarterPlayerScripts. Solo para ti.
-- Va junto con WHAT_THE_HELL.lua. Todo es local: la vida real la controla el servidor,
-- así que el "daño" y la "cura" son visuales en tu pantalla (barra falsa + viñeta roja).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	SCALE = 3,                 -- multiplicador de tamaño de todo lo que spawnea este add-on
	MAX_HP = 100,
	HIT_DAMAGE = {18, 35},     -- daño visual por impacto (rango)
	HIT_INTERVAL = {9, 16},    -- segundos entre impactos automáticos
	AUTO_HITS = true,
	HIT_KEY = Enum.KeyCode.H,
	CURE_KEY = Enum.KeyCode.K,
}

if _G.WTH_PLUS_CLEANUP then pcall(_G.WTH_PLUS_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Plus"
folder.Parent = workspace

local hp = CONFIG.MAX_HP
local nextAuto = os.clock() + rng:NextNumber(CONFIG.HIT_INTERVAL[1], CONFIG.HIT_INTERVAL[2])

local function hrpPos()
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Position or workspace.CurrentCamera.CFrame.Position
end

--==================== UI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "WTH_PlusUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60
gui.Parent = player:WaitForChild("PlayerGui")

local vignette = Instance.new("ImageLabel")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxasset://textures/ui/Controls/vignette.png"
vignette.ImageColor3 = Color3.fromRGB(255, 0, 0)
vignette.ImageTransparency = 1
vignette.ZIndex = 0
vignette.Parent = gui

local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -20)
bar.Size = UDim2.new(0.5, 0, 0, 18)
bar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
bar.BorderSizePixel = 0
bar.Parent = gui
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 9)
barCorner.Parent = bar

local fill = Instance.new("Frame")
fill.Size = UDim2.new(1, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
fill.BorderSizePixel = 0
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 9)
fillCorner.Parent = fill

local hpLabel = Instance.new("TextLabel")
hpLabel.Size = UDim2.fromScale(1, 1)
hpLabel.BackgroundTransparency = 1
hpLabel.Font = Enum.Font.GothamBlack
hpLabel.TextSize = 13
hpLabel.TextColor3 = Color3.new(1, 1, 1)
hpLabel.ZIndex = 2
hpLabel.Parent = bar

local function refreshBar()
	local ratio = math.clamp(hp / CONFIG.MAX_HP, 0, 1)
	fill.Size = UDim2.new(ratio, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(1 - ratio * 0.7, 0.3 + ratio * 0.6, 0.3)
	hpLabel.Text = "VIDA (visual): " .. math.floor(hp) .. "/" .. CONFIG.MAX_HP
end
refreshBar()

local function flashVignette(color, peak)
	vignette.ImageColor3 = color
	vignette.ImageTransparency = peak
	TweenService:Create(vignette, TweenInfo.new(0.7, Enum.EasingStyle.Quad), {ImageTransparency = 1}):Play()
end

local function shake(amount)
	local cam = workspace.CurrentCamera
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = 1 - (os.clock() - start) / 0.5
		if k <= 0 then
			conn:Disconnect()
			return
		end
		cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-1, 1) * amount * k, rng:NextNumber(-1, 1) * amount * k, 0)
	end)
	table.insert(conns, conn)
end

--==================== EFECTOS (escalados) ====================
local function part(size, color, cf, opts)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = (opts and opts.material) or Enum.Material.Neon
	p.Shape = (opts and opts.shape) or Enum.PartType.Block
	p.Transparency = (opts and opts.transparency) or 0
	p.Parent = folder
	return p
end

local function ring(center, color, life)
	local r = part(Vector3.new(0.5, 2, 2) * CONFIG.SCALE, color, CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), {shape = Enum.PartType.Cylinder, transparency = 0.2})
	TweenService:Create(r, TweenInfo.new(life, Enum.EasingStyle.Quad), {
		Size = Vector3.new(0.5, 60, 60) * CONFIG.SCALE / 3,
		Transparency = 1,
	}):Play()
	Debris:AddItem(r, life + 0.2)
end

local function giantMeteorOnYou(dmg)
	local center = hrpPos()
	local size = 6 * CONFIG.SCALE
	local start = center + Vector3.new(rng:NextNumber(-20, 20), 300, rng:NextNumber(-20, 20))
	local m = part(Vector3.new(size, size, size), Color3.fromRGB(255, 110, 40), CFrame.new(start), {shape = Enum.PartType.Ball})
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 60
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(4, 10)
	pe.Size = NumberSequence.new(size * 0.5, 0)
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(120, 30, 0))
	pe.LightEmission = 1
	pe.Parent = m
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 30
	smoke.Lifetime = NumberRange.new(0.8, 1.4)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.Size = NumberSequence.new(size * 0.6, size * 1.6)
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 95), Color3.fromRGB(35, 35, 40))
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Parent = m

	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local dt = os.clock() - t0
		local y = 300 - dt * 260
		m.Position = Vector3.new(start.X, math.max(center.Y, center.Y + y), start.Z)
		if y <= 0 then
			conn:Disconnect()
			m:Destroy()
			ring(center, Color3.fromRGB(255, 170, 70), 0.9)
			ring(center, Color3.fromRGB(255, 240, 200), 0.5)
			shake(1.8)
			flashVignette(Color3.fromRGB(255, 0, 0), 0.1)
			hp = math.max(0, hp - dmg)
			refreshBar()
		end
	end)
	table.insert(conns, conn)
end

local function giantMoon()
	local c = hrpPos() + Vector3.new(0, 420 * CONFIG.SCALE / 3, -600)
	local moon = part(Vector3.new(300, 300, 300) * CONFIG.SCALE / 3, Color3.fromRGB(215, 215, 230), CFrame.new(c), {shape = Enum.PartType.Ball})
	for i = 1, 4 do
		local s = rng:NextNumber(30, 60) * CONFIG.SCALE / 3
		local crater = part(Vector3.new(4, s, s), Color3.fromRGB(170, 170, 185), moon.CFrame * CFrame.new(rng:NextNumber(-100, 100), rng:NextNumber(-100, 100), 150) * CFrame.Angles(0, 0, math.pi / 2), {shape = Enum.PartType.Cylinder, material = Enum.Material.Concrete})
		crater.Parent = moon
	end
	Debris:AddItem(moon, 20)
end

local function cure()
	hp = CONFIG.MAX_HP
	refreshBar()
	flashVignette(Color3.fromRGB(80, 255, 140), 0.3)
	ring(hrpPos(), Color3.fromRGB(80, 255, 140), 1.2)
	shake(0.4)
end

local function hit()
	local dmg = rng:NextInteger(CONFIG.HIT_DAMAGE[1], CONFIG.HIT_DAMAGE[2])
	giantMeteorOnYou(dmg)
	if rng:NextNumber() < 0.5 then giantMoon() end
end

--==================== BOTONES ====================
local function button(x, text, color, cb)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0, 1)
	b.Position = UDim2.new(0, x, 1, -60)
	b.Size = UDim2.fromOffset(120, 34)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	b.Activated:Connect(cb)
end
button(14, "IMPACTO", Color3.fromRGB(170, 40, 40), hit)
button(144, "CURA TOTAL", Color3.fromRGB(40, 150, 80), cure)

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.HIT_KEY then hit()
	elseif input.KeyCode == CONFIG.CURE_KEY then cure() end
end))

--==================== DIRECTOR AUTOMÁTICO ====================
table.insert(conns, RunService.Heartbeat:Connect(function()
	if not CONFIG.AUTO_HITS then return end
	if os.clock() >= nextAuto then
		nextAuto = os.clock() + rng:NextNumber(CONFIG.HIT_INTERVAL[1], CONFIG.HIT_INTERVAL[2])
		hit()
	end
end))

_G.WTH_PLUS_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: MEGA (desastres grandes) =====================
do
-- WHAT_THE_HELL_MEGA.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, 100% local.
-- Va junto con WHAT_THE_HELL.lua y WHAT_THE_HELL_PLUS.lua. Nada se replica ni toca el servidor.
-- Lo que es "físico" aquí (vida, empujones reales) no se puede hacer desde el cliente;
-- se simula con cámara, viñetas, partículas y piezas que solo ves tú.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	SCALE = 3,
	MAX_ACTIVE = 4,
	INTERVAL = {10, 18},
	TOGGLE_KEY = Enum.KeyCode.Semicolon,
	MAX_KEY = Enum.KeyCode.Quote,
	ASSET_IDS = {
		Shrek = 100513111509436,
		Tattletail = 837048922,
		SkibidiGMan = 15092283006,
		TungSahur = 136528368108736,
	},
}

if _G.WTH_MEGA_CLEANUP then pcall(_G.WTH_MEGA_CLEANUP) end

local conns, active = {}, {}
local enabled = true
local folder = Instance.new("Folder")
folder.Name = "WTH_Mega"
folder.Parent = workspace
local nextEvent = os.clock() + 4

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local function pos()
	local h = hrp()
	return h and h.Position or workspace.CurrentCamera.CFrame.Position
end

--==================== UI ====================
local gui = Instance.new("ScreenGui")
gui.Name = "WTH_MegaUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 61
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 420, 0, 36)
banner.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
banner.BackgroundTransparency = 0.2
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 16
banner.TextColor3 = Color3.fromRGB(255, 90, 90)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text)
	banner.Text = text
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

--==================== CÁMARA / ILUMINACIÓN ====================
local camState = {roll = 0, rollTarget = 0, shake = 0, pull = 0, pullTarget = 0}
local bound = "WTH_Mega_Cam"
RunService:BindToRenderStep(bound, Enum.RenderPriority.Camera.Value + 2, function(dt)
	camState.roll += (camState.rollTarget - camState.roll) * math.min(1, dt * 2)
	camState.shake *= math.max(0, 1 - dt * 4)
	camState.pull += (camState.pullTarget - camState.pull) * math.min(1, dt * 2)
	local cam = workspace.CurrentCamera
	local ox, oy = 0, 0
	if camState.shake > 0.01 then
		ox = rng:NextNumber(-camState.shake, camState.shake)
		oy = rng:NextNumber(-camState.shake, camState.shake)
	end
	cam.CFrame = cam.CFrame * CFrame.new(ox, oy, camState.pull) * CFrame.Angles(0, 0, camState.roll)
end)

local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Name = "WTH_MegaBlur"
blur.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "WTH_MegaCC"
cc.Parent = Lighting

local function flash(color, peak)
	cc.TintColor = color
	TweenService:Create(cc, TweenInfo.new(0.8), {TintColor = Color3.new(1, 1, 1)}):Play()
end

--==================== ASSETS (con respaldo) ====================
local cache = {}
task.spawn(function()
	for key, id in pairs(CONFIG.ASSET_IDS) do
		local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
		if ok and objs and objs[1] then
			local m = objs[1]
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") then pcall(function() d:Destroy() end)
				elseif d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
			end
			cache[key] = m
		else
			cache[key] = false
		end
	end
	print("[WTH MEGA] Carga de assets terminada (los que no salieron usan respaldo).")
end)

local function makeModel(key)
	local tpl = cache[key]
	local m
	if tpl then
		m = tpl:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Size = Vector3.new(2, 4, 1.5)
		body.Color = Color3.fromRGB(120, 120, 130)
		body.Anchored, body.CanCollide, body.CanQuery = true, false, false
		body.Parent = m
		m.PrimaryPart = body
		local head = Instance.new("Part")
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(2.4, 2.4, 2.4)
		head.Color = Color3.fromRGB(90, 90, 100)
		head.Position = body.Position + Vector3.new(0, 3.2, 0)
		head.Parent = m
		for _, sx in ipairs({-1, 1}) do
			local leg = Instance.new("Part")
			leg.Size = Vector3.new(0.7, 2, 0.7)
			leg.Color = Color3.fromRGB(40, 40, 50)
			leg.Position = body.Position + Vector3.new(sx * 0.6, -3, 0)
			leg.Parent = m
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	m.Parent = folder
	if not m.PrimaryPart then m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true) end
	pcall(function() m:ScaleTo(CONFIG.SCALE) end)
	return m
end

local function glow(center, size, color, life)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.Position = center
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(life), {Size = Vector3.new(size * 3, size * 3, size * 3), Transparency = 1}):Play()
	Debris:AddItem(p, life + 0.1)
end

--==================== DESASTRES ====================
local DISASTERS = {}

-- Agujero negro: la cámara se acerca y el mundo se estira
DISASTERS.blackhole = {
	title = "AGUJERO NEGRO DETECTADO", dur = 14,
	run = function(life)
		local c = pos() + Vector3.new(rng:NextNumber(-60, 60), 40, rng:NextNumber(-60, 60))
		local hole = Instance.new("Part")
		hole.Shape = Enum.PartType.Ball
		hole.Size = Vector3.new(14, 14, 14) * CONFIG.SCALE / 3
		hole.Position = c
		hole.Color = Color3.new(0, 0, 0)
		hole.Anchored, hole.CanCollide, hole.CanQuery, hole.CanTouch = true, false, false, false
		hole.Parent = folder
		Debris:AddItem(hole, life)
		local halo = Instance.new("Part")
		halo.Shape = Enum.PartType.Ball
		halo.Size = Vector3.new(20, 20, 20)
		halo.Color = Color3.fromRGB(255, 140, 60)
		halo.Material = Enum.Material.Neon
		halo.Transparency = 0.8
		halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch = true, false, false, false
		halo.Position = c
		halo.Parent = folder
		Debris:AddItem(halo, life)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > life or not hole.Parent then conn:Disconnect(); return end
			local dist = (pos() - c).Magnitude
			camState.pullTarget = math.clamp(1 - dist / 200, 0, 1) * 6
			cc.Contrast = 0.4
			cc.Saturation = -0.5
			blur.Size = math.clamp(1 - dist / 220, 0, 1) * 18
		end)
		table.insert(conns, conn)
		task.delay(life, function()
			camState.pullTarget = 0
			cc.Contrast = 0
			cc.Saturation = 0
			blur.Size = 0
		end)
	end,
}

-- Tornado de piezas alrededor de ti
DISASTERS.tornado = {
	title = "TORNADO DIMENSIONAL", dur = 16,
	run = function(life)
		local base = pos() + Vector3.new(rng:NextNumber(-40, 40), -2, rng:NextNumber(-40, 40))
		local pieces = {}
		for i = 1, 24 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(1, 1, 1) * rng:NextNumber(1, 3) * CONFIG.SCALE / 3
			p.Color = Color3.fromRGB(140, 140, 150)
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Parent = folder
			pieces[i] = p
		end
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > life then conn:Disconnect(); for _, p in ipairs(pieces) do p:Destroy() end; return end
			for i, p in ipairs(pieces) do
				local h = (t * 10 + i * 3) % 40
				local r = 3 + h * 0.6
				local a = t * 3 + i
				p.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)) * CFrame.Angles(t * 4, t * 3, 0)
			end
			local d = (pos() - base).Magnitude
			camState.shake = math.max(camState.shake, math.clamp(1 - d / 60, 0, 1) * 0.5)
		end)
		table.insert(conns, conn)
	end,
}

-- Cielo invertido: la cámara rueda media vuelta y vuelve
DISASTERS.invert = {
	title = "INVERSIÓN DEL CIELO", dur = 12,
	run = function(life)
		camState.rollTarget = math.pi
		flash(Color3.fromRGB(180, 255, 200))
		task.delay(life - 3, function() camState.rollTarget = 0 end)
	end,
}

-- Shrek gigante caminando hacia ti
DISASTERS.giantShrek = {
	title = "MULTIPLE ENTITIES DETECTED", dur = 18,
	run = function(life)
		local m = makeModel("Shrek")
		local start = pos() + Vector3.new(rng:NextNumber(-200, 200), 0, 300)
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - t0
			if t > life or not m.Parent then conn:Disconnect(); m:Destroy(); return end
			local target = pos()
			local flat = Vector3.new(target.X - start.X, 0, target.Z - start.Z)
			local dist = flat.Magnitude
			local dir = dist > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
			if dist > 90 then start = start + dir * 60 * dt end
			m:PivotTo(CFrame.lookAt(Vector3.new(start.X, target.Y + 6 * CONFIG.SCALE / 2, start.Z), Vector3.new(target.X, target.Y + 6, target.Z)))
			if dist < 120 then camState.shake = math.max(camState.shake, math.clamp(1 - dist / 120, 0, 1) * 0.6) end
		end)
		table.insert(conns, conn)
	end,
}

-- G-Man que aparece y se desvanece
DISASTERS.ghost = {
	title = "ENTIDAD DESCONOCIDA", dur = 10,
	run = function(life)
		local m = makeModel("SkibidiGMan")
		local p = pos() + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(-30, 30))
		m:PivotTo(CFrame.lookAt(p + Vector3.new(0, 6, 0), pos()))
		local parts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency = 1; table.insert(parts, d) end
		end
		for _, d in ipairs(parts) do TweenService:Create(d, TweenInfo.new(0.4), {Transparency = 0}):Play() end
		task.delay(life - 1, function()
			for _, d in ipairs(parts) do
				if d.Parent then TweenService:Create(d, TweenInfo.new(0.8), {Transparency = 1}):Play() end
			end
			task.delay(0.9, function() m:Destroy() end)
		end)
	end,
}

-- Meteoritos gigantes cayendo cerca
DISASTERS.meteors = {
	title = "LLUVIA DE CAGUAMAS DETECTADA", dur = 12,
	run = function(life)
		local count = 0
		local t0 = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			if t > life then conn:Disconnect(); return end
			if count < 8 and t > count * 1.2 then
				count += 1
				local target = pos() + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
				local size = rng:NextNumber(3, 6) * CONFIG.SCALE / 3
				local m = Instance.new("Part")
				m.Shape = Enum.PartType.Ball
				m.Size = Vector3.new(size, size, size)
				m.Color = Color3.fromRGB(255, 110, 40)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Rate = 30
		smoke.Lifetime = NumberRange.new(1, 1.8)
		smoke.Speed = NumberRange.new(1, 3)
		smoke.Size = NumberSequence.new(3, 7)
		smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 95), Color3.fromRGB(40, 40, 45))
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Parent = m
				m.Material = Enum.Material.Neon
				m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch = true, false, false, false
				m.Parent = folder
				local fall = 0
				local c2
				c2 = RunService.Heartbeat:Connect(function(dt)
					fall += dt
					local y = 220 - fall * 200
					m.Position = Vector3.new(target.X, math.max(target.Y, target.Y + y), target.Z)
					if y <= 0 then
						c2:Disconnect()
						m:Destroy()
						glow(target, size * 3, Color3.fromRGB(255, 170, 70), 0.8)
						camState.shake = math.max(camState.shake, 1.2)
					end
				end)
				table.insert(conns, c2)
			end
		end)
		table.insert(conns, conn)
	end,
}

-- Portal dimensional con personajes saliendo
DISASTERS.portal = {
	title = "ANOMALÍA DIMENSIONAL", dur = 12,
	run = function(life)
		local p = pos() + Vector3.new(rng:NextNumber(-50, 50), 4, rng:NextNumber(-50, 50))
		local ringP = Instance.new("Part")
		ringP.Shape = Enum.PartType.Cylinder
		ringP.Size = Vector3.new(0.5, 16, 16) * CONFIG.SCALE / 3
		ringP.Color = Color3.fromRGB(180, 80, 255)
		local ringGlow = Instance.new("Part")
		ringGlow.Shape = Enum.PartType.Cylinder
		ringGlow.Size = Vector3.new(0.2, 18, 18) * CONFIG.SCALE / 3
		ringGlow.Color = Color3.fromRGB(230, 180, 255)
		ringGlow.Material = Enum.Material.Neon
		ringGlow.Transparency = 0.5
		ringGlow.Anchored, ringGlow.CanCollide, ringGlow.CanQuery, ringGlow.CanTouch = true, false, false, false
		ringGlow.CFrame = CFrame.lookAt(p, pos()) * CFrame.Angles(0, math.pi / 2, 0)
		ringGlow.Parent = folder
		Debris:AddItem(ringGlow, life)
		ringP.Material = Enum.Material.Neon
		ringP.Anchored, ringP.CanCollide, ringP.CanQuery, ringP.CanTouch = true, false, false, false
		ringP.CFrame = CFrame.lookAt(p, pos()) * CFrame.Angles(0, math.pi / 2, 0)
		ringP.Parent = folder
		Debris:AddItem(ringP, life)
		task.delay(life * 0.3, function()
			local m = makeModel(rng:NextNumber() < 0.5 and "Tattletail" or "TungSahur")
			m:PivotTo(CFrame.new(p + Vector3.new(0, 4, 0)))
		end)
	end,
}

--==================== DIRECTOR ====================
local ORDER = {"blackhole", "tornado", "invert", "giantShrek", "ghost", "meteors", "portal"}

local function pickNext()
	local name = ORDER[rng:NextInteger(1, #ORDER)]
	for _, a in ipairs(active) do
		if a.name == name then return nil end
	end
	return name
end

local function fire(name, forced)
	if #active >= CONFIG.MAX_ACTIVE and not forced then return end
	local d = DISASTERS[name]
	if not d then return end
	table.insert(active, {name = name, ends = os.clock() + d.dur})
	alert("⚠ " .. d.title .. " | PELIGRO: ALTO")
	d.run(d.dur)
	task.delay(d.dur, function()
		for i = #active, 1, -1 do
			if active[i].name == name then table.remove(active, i) end
		end
	end)
end

table.insert(conns, RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if enabled and now >= nextEvent then
		local name = pickNext()
		if name then fire(name, false) end
		nextEvent = now + rng:NextNumber(CONFIG.INTERVAL[1], CONFIG.INTERVAL[2])
	end
end))

-- Botón de "todo al máximo"
local maxBtn = Instance.new("TextButton")
maxBtn.AnchorPoint = Vector2.new(1, 1)
maxBtn.Position = UDim2.new(1, -14, 1, -60)
maxBtn.Size = UDim2.fromOffset(140, 34)
maxBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 40)
maxBtn.BorderSizePixel = 0
maxBtn.Font = Enum.Font.GothamBold
maxBtn.TextSize = 13
maxBtn.TextColor3 = Color3.new(1, 1, 1)
maxBtn.Text = "TODO AL MÁXIMO"
maxBtn.Parent = gui
local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = maxBtn
maxBtn.Activated:Connect(function()
	for _, name in ipairs(ORDER) do
		task.delay(rng:NextNumber(0, 2), function() fire(name, true) end)
	end
end)

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.TOGGLE_KEY then
		enabled = not enabled
		alert(enabled and "CAOS MEGA: ACTIVO" or "CAOS MEGA: PAUSADO")
	elseif input.KeyCode == CONFIG.MAX_KEY then
		for _, name in ipairs(ORDER) do
			task.delay(rng:NextNumber(0, 2), function() fire(name, true) end)
		end
	end
end))

_G.WTH_MEGA_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	RunService:UnbindFromRenderStep(bound)
	folder:Destroy()
	blur:Destroy()
	cc:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: GRAVITY (gravedad y maremoto) =====================
do
-- WHAT_THE_HELL_GRAVITY.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- Desastres de gravedad: GRAVEDAD CERO (saltas altísimo), GRAVEDAD AL REVÉS, MAREMOTO.
-- Workspace.Gravity y JumpPower se cambian en TU cliente. El servidor puede corregir tu
-- posición si no está de acuerdo, así que si ves rebotes raros, es eso.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	ZERO_GRAVITY = 0,
	ZERO_JUMP = 120,           -- JumpPower durante gravedad cero
	ZERO_TIME = 10,
	REVERSE_GRAVITY = -70,     -- negativo = todo cae hacia arriba
	REVERSE_TIME = 6,
	KEY_ZERO = Enum.KeyCode.G,
	KEY_REVERSE = Enum.KeyCode.Y,
	KEY_TSUNAMI = Enum.KeyCode.T,
	AUTO = true,
	AUTO_INTERVAL = {20, 35},
}

if _G.WTH_GRAVITY_CLEANUP then pcall(_G.WTH_GRAVITY_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Gravity"
folder.Parent = workspace
local originalGravity = workspace.Gravity
local originalJump = nil
local camRoll = {v = 0, target = 0}
local activeKind = nil
local nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])

local function hum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "WTH_GravityUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 62
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 460, 0, 36)
banner.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
banner.BackgroundTransparency = 0.2
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 16
banner.TextColor3 = Color3.fromRGB(120, 200, 255)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(120, 200, 255)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

-- Cámara: roll para el "al revés"
RunService:BindToRenderStep("WTH_GravityCam", Enum.RenderPriority.Camera.Value + 3, function(dt)
	camRoll.v += (camRoll.target - camRoll.v) * math.min(1, dt * 2)
	if math.abs(camRoll.v) > 0.001 then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, camRoll.v)
	end
end)

-- Partículas flotantes (gravedad cero)
local function floaters(life)
	local emitter = Instance.new("Part")
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.Parent = folder
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 25
	pe.Lifetime = NumberRange.new(3, 5)
	pe.Speed = NumberRange.new(0.5, 2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.4, 0.1)
	pe.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255))
	pe.LightEmission = 1
	pe.Parent = emitter
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 12
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Speed = NumberRange.new(0, 1)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.15, 0)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	sparkle.LightEmission = 1
	sparkle.Parent = emitter
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local h = hrp()
		if h then emitter.Position = h.Position end
	end)
	table.insert(conns, conn)
	Debris:AddItem(emitter, life)
end

-- Sonido de "desbloqueo" (visual en texto: la UI ya avisa)
local function restoreGravity()
	workspace.Gravity = originalGravity
	camRoll.target = 0
	local h = hum()
	if h and originalJump then h.JumpPower = originalJump end
	activeKind = nil
end

local function zeroGravity()
	if activeKind then return end
	activeKind = "zero"
	originalGravity = workspace.Gravity
	local h = hum()
	if h then
		originalJump = h.JumpPower
		h.JumpPower = CONFIG.ZERO_JUMP
	end
	workspace.Gravity = CONFIG.ZERO_GRAVITY
	alert("GRAVEDAD CERO: saltas hasta el cielo", Color3.fromRGB(120, 220, 255))
	floaters(CONFIG.ZERO_TIME)
	task.delay(CONFIG.ZERO_TIME, function()
		if activeKind == "zero" then restoreGravity() end
	end)
end

local function reverseGravity()
	if activeKind then return end
	activeKind = "reverse"
	originalGravity = workspace.Gravity
	workspace.Gravity = CONFIG.REVERSE_GRAVITY
	camRoll.target = math.pi
	alert("GRAVEDAD AL REVÉS: el suelo ahora está arriba", Color3.fromRGB(255, 180, 90))
	task.delay(CONFIG.REVERSE_TIME, function()
		if activeKind == "reverse" then restoreGravity() end
	end)
end

-- Maremoto visual: una pared azul que avanza y se disuelve
local function tsunami()
	local h = hrp()
	if not h then return end
	local pos = h.Position
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local wall = Instance.new("Part")
	wall.Size = Vector3.new(180, 70, 22) * 1.5
	wall.Color = Color3.fromRGB(40, 120, 200)
	wall.Material = Enum.Material.Glass
	wall.Transparency = 0.2
	wall.Anchored, wall.CanCollide, wall.CanQuery, wall.CanTouch = true, false, false, false
	local spawnPos = pos + dir * 300 + Vector3.new(0, 35, 0)
	wall.CFrame = CFrame.lookAt(spawnPos, spawnPos - dir)
	wall.Parent = folder
	local crest = Instance.new("Part")
	crest.Size = Vector3.new(180, 12, 26) * 1.5
	crest.Color = Color3.fromRGB(230, 245, 255)
	crest.Material = Enum.Material.Neon
	crest.Transparency = 0.3
	crest.Anchored, crest.CanCollide, crest.CanQuery, crest.CanTouch = true, false, false, false
	crest.Parent = folder
	alert("MAREMOTO VISUAL: no hay agua, pero hay pánico", Color3.fromRGB(90, 170, 255))
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if t > 9 or not wall.Parent then
			conn:Disconnect()
			wall:Destroy()
			crest:Destroy()
			return
		end
		wall.CFrame = CFrame.lookAt(wall.Position + (-dir) * 55 * dt, wall.Position + (-dir) * 55 * dt - dir)
		crest.CFrame = wall.CFrame * CFrame.new(0, 41, 0)
		if t > 7 then wall.Transparency = math.min(1, wall.Transparency + 0.02) end
	end)
	table.insert(conns, conn)
end

-- Entradas
table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_ZERO then zeroGravity()
	elseif input.KeyCode == CONFIG.KEY_REVERSE then reverseGravity()
	elseif input.KeyCode == CONFIG.KEY_TSUNAMI then tsunami() end
end))

-- Automático (elige uno al azar)
table.insert(conns, RunService.Heartbeat:Connect(function()
	if not CONFIG.AUTO then return end
	if os.clock() >= nextAuto then
		nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])
		local pick = rng:NextInteger(1, 3)
		if pick == 1 then zeroGravity() elseif pick == 2 then reverseGravity() else tsunami() end
	end
end))

_G.WTH_GRAVITY_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	RunService:UnbindFromRenderStep("WTH_GravityCam")
	workspace.Gravity = originalGravity
	local h = hum()
	if h and originalJump then h.JumpPower = originalJump end
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: MORE (eclipse, pollos, reloj) =====================
do
-- WHAT_THE_HELL_MORE.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- Tres desastres nuevos: ECLIPSE, LLUVIA DE POLLOS GIGANTES y RELOJ ROTO.
-- Todo es visual y solo lo ves tú. Usa ids de los assets, con respaldo si no cargan.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY_ECLIPSE = Enum.KeyCode.E,
	KEY_CHICKS = Enum.KeyCode.C,
	KEY_CLOCK = Enum.KeyCode.R,
	CHICK_ID = 112458656748491,
	CHICK_SCALE = 4,
	ECLIPSE_TIME = 14,
	CLOCK_TIME = 10,
}

if _G.WTH_MORE_CLEANUP then pcall(_G.WTH_MORE_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_More"
folder.Parent = workspace
local busy = {}
local originalClock = Lighting.ClockTime

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_MoreUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 63
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 460, 0, 36)
banner.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
banner.BackgroundTransparency = 0.2
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 16
banner.TextColor3 = Color3.fromRGB(255, 220, 120)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 220, 120)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- ECLIPSE: un disco negro tapa el sol y el cielo se oscurece
local function eclipse()
	if busy.eclipse then return end
	busy.eclipse = true
	alert("ECLIPSE DIMENSIONAL: el sol se tomó la tarde", Color3.fromRGB(255, 160, 80))
	local disc = Instance.new("Part")
	disc.Shape = Enum.PartType.Ball
	disc.Size = Vector3.new(160, 160, 160)
	disc.Color = Color3.new(0, 0, 0)
	disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch = true, false, false, false
	disc.Parent = folder
	local halo = Instance.new("Part")
	halo.Shape = Enum.PartType.Ball
	halo.Size = Vector3.new(190, 190, 190)
	halo.Color = Color3.fromRGB(255, 200, 120)
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.5
	local corona = Instance.new("Part")
	corona.Shape = Enum.PartType.Ball
	corona.Size = Vector3.new(210, 210, 210)
	corona.Color = Color3.fromRGB(255, 240, 200)
	corona.Material = Enum.Material.Neon
	corona.Transparency = 0.85
	corona.Anchored, corona.CanCollide, corona.CanQuery, corona.CanTouch = true, false, false, false
	corona.Parent = folder
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not corona.Parent then return end
		local h = hrp()
		if h then corona.Position = h.Position + Vector3.new(0, 260, -220) end
	end))
	halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch = true, false, false, false
	halo.Parent = folder
	local oldAmb = Lighting.Ambient
	local oldBright = Lighting.Brightness
	TweenService:Create(Lighting, TweenInfo.new(1.5), {Ambient = Color3.fromRGB(20, 15, 30), Brightness = 0.5}):Play()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > CONFIG.ECLIPSE_TIME then
			conn:Disconnect()
			TweenService:Create(Lighting, TweenInfo.new(1.5), {Ambient = oldAmb, Brightness = oldBright}):Play()
			disc:Destroy()
			halo:Destroy()
			busy.eclipse = false
			return
		end
		local h = hrp()
		local base = h and h.Position or Vector3.new()
		local p = base + Vector3.new(0, 260, -220)
		disc.Position = p
		halo.Position = p
	end)
	table.insert(conns, conn)
end

-- POLLOS GIGANTES cayendo alrededor tuyo
local chickTemplate
task.spawn(function()
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. CONFIG.CHICK_ID) end)
	if ok and objs and objs[1] then
		chickTemplate = objs[1]
		for _, d in ipairs(chickTemplate:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") then pcall(function() d:Destroy() end) end
		end
	end
end)

local function makeChick()
	local m
	if chickTemplate then
		m = chickTemplate:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(2, 2, 2)
		body.Color = Color3.fromRGB(255, 220, 60)
		body.Parent = m
		m.PrimaryPart = body
		for _, sx in ipairs({-1, 1}) do
			local wing = Instance.new("Part")
			wing.Size = Vector3.new(0.4, 1.2, 1.6)
			wing.Color = Color3.fromRGB(250, 235, 120)
			wing.Position = body.Position + Vector3.new(sx * 1.3, 0.2, 0)
			wing.Parent = m
		end
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	m.Parent = folder
	if not m.PrimaryPart then m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true) end
	pcall(function() m:ScaleTo(CONFIG.CHICK_SCALE) end)
	return m
end

local function chickRain()
	if busy.chicks then return end
	busy.chicks = true
	alert("LLUVIA DE POLLOS GIGANTES: no pregunten", Color3.fromRGB(255, 230, 90))
	local h = hrp()
	local center = h and h.Position or Vector3.new()
	local count = 0
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 12 then
			conn:Disconnect()
			busy.chicks = false
			return
		end
		if count < 10 and t > count * 1.0 then
			count += 1
			local m = makeChick()
			local target = center + Vector3.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(-80, 80))
			local fall = 0
			local c2
			c2 = RunService.Heartbeat:Connect(function(dt)
				fall += dt
				local y = 200 - fall * 150
				if y <= 0 then
					c2:Disconnect()
					m:PivotTo(CFrame.new(target.X, target.Y + 4, target.Z))
					Debris:AddItem(m, 4)
					return
				end
				m:PivotTo(CFrame.new(target.X, target.Y + y, target.Z) * CFrame.Angles(0, fall * 3, 0))
			end)
			table.insert(conns, c2)
		end
	end)
	table.insert(conns, conn)
end

-- RELOJ ROTO: la hora se queda atorada y parpadea la luz
local function brokenClock()
	if busy.clock then return end
	busy.clock = true
	alert("RELOJ ROTO: el tiempo se atoró en una hora rara", Color3.fromRGB(180, 200, 255))
	originalClock = Lighting.ClockTime
	local stuck = rng:NextNumber(0, 24)
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > CONFIG.CLOCK_TIME then
			conn:Disconnect()
			Lighting.ClockTime = originalClock
			busy.clock = false
			return
		end
		Lighting.ClockTime = stuck
		if math.random() < 0.08 then
			Lighting.Brightness = rng:NextNumber(0, 5)
		else
			Lighting.Brightness = 2
		end
	end)
	table.insert(conns, conn)
end

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_ECLIPSE then eclipse()
	elseif input.KeyCode == CONFIG.KEY_CHICKS then chickRain()
	elseif input.KeyCode == CONFIG.KEY_CLOCK then brokenClock() end
end))

_G.WTH_MORE_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	Lighting.ClockTime = originalClock
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: WEATHER (clima extremo) =====================
do
-- WHAT_THE_HELL_WEATHER.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- Clima extremo: GRANIZO GIGANTE, HURACÁN DE LLUVIA, NEVADA CÓSMICA y TORMENTA DE RAYOS.
-- Todo visual y solo lo ves tú. Tecla de disparo por desastre (abajo en CONFIG).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY_HAIL = Enum.KeyCode.One,
	KEY_HURRICANE = Enum.KeyCode.Two,
	KEY_SNOW = Enum.KeyCode.Three,
	KEY_STORM = Enum.KeyCode.Four,
	HAIL_TIME = 12,
	HURRICANE_TIME = 14,
	SNOW_TIME = 16,
	STORM_TIME = 14,
	AUTO = true,
	AUTO_INTERVAL = {25, 40},
}

if _G.WTH_WEATHER_CLEANUP then pcall(_G.WTH_WEATHER_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Weather"
folder.Parent = workspace
local busy = {}
local origAtmo = nil
local origBright = Lighting.Brightness
local nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_WeatherUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 64
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 460, 0, 36)
banner.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
banner.BackgroundTransparency = 0.2
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 16
banner.TextColor3 = Color3.fromRGB(180, 230, 255)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(180, 230, 255)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function center()
	local h = hrp()
	return h and h.Position or workspace.CurrentCamera.CFrame.Position
end

-- Partícula de "gota/copo" que cae alrededor del jugador (una sola emisión por parte)
local function fallingPart(size, color, material, startY, speed, life, spread)
	local c = center()
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	local trail = Instance.new("ParticleEmitter")
	trail.Rate = 18
	trail.Lifetime = NumberRange.new(0.3, 0.6)
	trail.Speed = NumberRange.new(0, 1)
	trail.Size = NumberSequence.new(size.X * 0.3, 0)
	trail.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255), Color3.fromRGB(180, 210, 255))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 0.6
	trail.Parent = p
	local x = rng:NextNumber(-spread, spread)
	local z = rng:NextNumber(-spread, spread)
	local fall = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		fall += dt
		local y = startY - fall * speed
		if y <= 0 or fall > life then
			conn:Disconnect()
			p:Destroy()
			return
		end
		p.CFrame = CFrame.new(c.X + x, c.Y + y, c.Z + z) * CFrame.Angles(fall * 2, fall * 3, 0)
	end)
	table.insert(conns, conn)
end

-- GRANIZO GIGANTE: piedras grandes que rebotan en el suelo
local function hail()
	if busy.hail then return end
	busy.hail = true
	alert("GRANIZO GIGANTE: cada piedra es del tamaño de un carro", Color3.fromRGB(200, 240, 255))
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - t0 > CONFIG.HAIL_TIME then
			conn:Disconnect()
			busy.hail = false
			return
		end
		for _ = 1, 2 do
			local s = rng:NextNumber(3, 7)
			fallingPart(Vector3.new(s, s, s), Color3.fromRGB(200, 230, 255), Enum.Material.Ice, 200, rng:NextNumber(120, 180), 4, 90)
		end
	end)
	table.insert(conns, conn)
end

-- HURACÁN: anillo de viento con lluvia horizontal y cámara temblando
local function hurricane()
	if busy.hurricane then return end
	busy.hurricane = true
	alert("HURACÁN DE LLUVIA: la lluvia ya no cae, viaja", Color3.fromRGB(150, 200, 255))
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.3
	cc.TintColor = Color3.fromRGB(190, 210, 255)
	cc.Parent = Lighting
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if t > CONFIG.HURRICANE_TIME then
			conn:Disconnect()
			cc:Destroy()
			busy.hurricane = false
			return
		end
		local c = center()
		for _ = 1, 2 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.3, 0.3, 6)
			p.Color = Color3.fromRGB(170, 200, 255)
			p.Material = Enum.Material.Neon
			p.Transparency = 0.4
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CastShadow = false
			p.Parent = folder
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(10, 60)
			local start = CFrame.new(c.X + math.cos(a) * r, c.Y + rng:NextNumber(-2, 15), c.Z + math.sin(a) * r)
			local age = 0
			local c2
			c2 = RunService.Heartbeat:Connect(function(dt2)
				age += dt2
				if age > 0.6 then c2:Disconnect(); p:Destroy(); return end
				p.CFrame = start * CFrame.Angles(0, math.atan2(-math.sin(a), math.cos(a)) + math.pi / 2, 0) * CFrame.new(0, 0, -age * 50)
			end)
			table.insert(conns, c2)
		end
		local wobble = math.sin(t * 6) * 0.2
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(0, 0, wobble * dt)
	end)
	table.insert(conns, conn)
end

-- NEVADA CÓSMICA: copos luminosos y niebla azul
local function snow()
	if busy.snow then return end
	busy.snow = true
	alert("NEVADA CÓSMICA: copos del tamaño de tu cabeza", Color3.fromRGB(220, 240, 255))
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.45
	atmo.Color = Color3.fromRGB(200, 220, 255)
	atmo.Decay = Color3.fromRGB(230, 240, 255)
	atmo.Parent = Lighting
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - t0 > CONFIG.SNOW_TIME then
			conn:Disconnect()
			atmo:Destroy()
			busy.snow = false
			return
		end
		fallingPart(Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(240, 250, 255), Enum.Material.Neon, 80, rng:NextNumber(4, 8), 14, 70)
	end)
	table.insert(conns, conn)
end

-- TORMENTA DE RAYOS: destellos y rayos que bajan del cielo
local function storm()
	if busy.storm then return end
	busy.storm = true
	alert("TORMENTA DE RAYOS: el cielo está haciendo ruido", Color3.fromRGB(255, 255, 160))
	local t0 = os.clock()
	local nextBolt = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > CONFIG.STORM_TIME then
			conn:Disconnect()
			Lighting.Brightness = origBright
			busy.storm = false
			return
		end
		if t > nextBolt then
			nextBolt = t + rng:NextNumber(0.8, 2.5)
			Lighting.Brightness = 6
			task.delay(0.08, function() Lighting.Brightness = origBright end)
			local c = center()
			local ox, oz = rng:NextNumber(-60, 60), rng:NextNumber(-60, 60)
			local bolt = Instance.new("Part")
			bolt.Size = Vector3.new(0.6, 220, 0.6)
			bolt.Color = Color3.fromRGB(255, 255, 200)
			bolt.Material = Enum.Material.Neon
			bolt.Anchored, bolt.CanCollide, bolt.CanQuery, bolt.CanTouch = true, false, false, false
			bolt.CastShadow = false
			bolt.CFrame = CFrame.new(c.X + ox, c.Y + 100, c.Z + oz)
			bolt.Parent = folder
			Debris:AddItem(bolt, 0.25)
		end
	end)
	table.insert(conns, conn)
end

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_HAIL then hail()
	elseif input.KeyCode == CONFIG.KEY_HURRICANE then hurricane()
	elseif input.KeyCode == CONFIG.KEY_SNOW then snow()
	elseif input.KeyCode == CONFIG.KEY_STORM then storm() end
end))

table.insert(conns, RunService.Heartbeat:Connect(function()
	if not CONFIG.AUTO then return end
	if os.clock() >= nextAuto then
		nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])
		local pick = rng:NextInteger(1, 4)
		if pick == 1 then hail() elseif pick == 2 then hurricane() elseif pick == 3 then snow() else storm() end
	end
end))

_G.WTH_WEATHER_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	Lighting.Brightness = origBright
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: NIGHTMARE (jefes) =====================
do
-- WHAT_THE_HELL_NIGHTMARE.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- MODO PESADILLA: jefes gigantes con barra de vida, ataques visuales (ondas de choque y
-- proyectiles) y recompensa visual al derrotarlos. Todo es local: el daño a los jefes
-- es solo en tu pantalla, nadie más lo ve.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY_TOGGLE = Enum.KeyCode.F1,
	KEY_HIT = Enum.KeyCode.F2,      -- golpea al jefe más cercano (solo visual)
	BOSSES = {
		{name = "SHREK TITÁN", id = 100513111509436, scale = 6, hp = 300, color = Color3.fromRGB(80, 160, 60)},
		{name = "SKIBIDI COLOSO", id = 115439748234383, scale = 5, hp = 260, color = Color3.fromRGB(240, 240, 240)},
		{name = "G-MAN ETERNO", id = 15092283006, scale = 5, hp = 220, color = Color3.fromRGB(25, 25, 30)},
	},
	ATTACK_EVERY = {4, 7},
	SPAWN_EVERY = {35, 50},
}

if _G.WTH_NIGHTMARE_CLEANUP then pcall(_G.WTH_NIGHTMARE_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Nightmare"
folder.Parent = workspace
local enabled = true
local bosses = {}
local nextSpawn = os.clock() + 8
local templates = {}

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_NightmareUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 65
gui.Parent = player:WaitForChild("PlayerGui")

local hudBars = Instance.new("Frame")
hudBars.AnchorPoint = Vector2.new(1, 0)
hudBars.Position = UDim2.new(1, -14, 0, 80)
hudBars.Size = UDim2.new(0, 260, 0, 0)
hudBars.AutomaticSize = Enum.AutomaticSize.Y
hudBars.BackgroundTransparency = 1
hudBars.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = hudBars

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 480, 0, 40)
banner.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
banner.BackgroundTransparency = 0.15
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 17
banner.TextColor3 = Color3.fromRGB(255, 60, 60)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 60, 60)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

-- Plantillas (con respaldo si no cargan)
task.spawn(function()
	for i, b in ipairs(CONFIG.BOSSES) do
		local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. b.id) end)
		if ok and objs and objs[1] then
			local m = objs[1]
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("Sound") then pcall(function() d:Destroy() end) end
			end
			templates[i] = m
		end
	end
end)

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function makeBossModel(cfg)
	local m
	local tpl = templates[cfg.index]
	if tpl then
		m = tpl:Clone()
	else
		m = Instance.new("Model")
		local body = Instance.new("Part")
		body.Size = Vector3.new(2, 4, 1.5)
		body.Color = cfg.color
		body.Parent = m
		local head = Instance.new("Part")
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(2.4, 2.4, 2.4)
		head.Color = cfg.color
		head.Position = body.Position + Vector3.new(0, 3.2, 0)
		head.Parent = m
		for _, sx in ipairs({-1, 1}) do
			local eye = Instance.new("Part")
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(0.5, 0.5, 0.5)
			eye.Color = Color3.fromRGB(255, 40, 40)
			eye.Material = Enum.Material.Neon
			eye.Position = head.Position + Vector3.new(sx * 0.6, 0.2, -1.1)
			eye.Parent = m
		end
		m.PrimaryPart = body
	end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false end
	end
	m.Parent = folder
	if not m.PrimaryPart then m.PrimaryPart = m:FindFirstChildWhichIsA("BasePart", true) end
	pcall(function() m:ScaleTo(cfg.scale) end)
	return m
end

local function makeBar(name)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
	row.BackgroundTransparency = 0.2
	row.BorderSizePixel = 0
	row.Parent = hudBars
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 6)
	rc.Parent = row
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -8, 0, 16)
	label.Position = UDim2.new(0, 4, 0, 2)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 12
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name
	label.Parent = row
	local bg = Instance.new("Frame")
	bg.Position = UDim2.new(0, 4, 0, 20)
	bg.Size = UDim2.new(1, -8, 0, 10)
	bg.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
	bg.BorderSizePixel = 0
	bg.Parent = row
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	return row, fill
end

-- Ataque: onda de choque en el suelo o proyectil hacia ti
local function shockwave(center)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Size = Vector3.new(0.5, 4, 4)
	r.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	r.Color = Color3.fromRGB(255, 80, 80)
	r.Material = Enum.Material.Neon
	r.Transparency = 0.2
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch = true, false, false, false
	r.Parent = folder
	TweenService:Create(r, TweenInfo.new(0.8), {Size = Vector3.new(0.5, 120, 120), Transparency = 1}):Play()
	local dust = Instance.new("Part")
	dust.Shape = Enum.PartType.Cylinder
	dust.Size = Vector3.new(0.3, 6, 6)
	dust.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	dust.Color = Color3.fromRGB(120, 60, 60)
	dust.Material = Enum.Material.Slate
	dust.Transparency = 0.4
	dust.Anchored, dust.CanCollide, dust.CanQuery, dust.CanTouch = true, false, false, false
	dust.Parent = folder
	TweenService:Create(dust, TweenInfo.new(1), {Size = Vector3.new(0.3, 100, 100), Transparency = 1}):Play()
	Debris:AddItem(dust, 1.2)
	Debris:AddItem(r, 1)
	local h = hrp()
	if h and (h.Position - center).Magnitude < 90 then
		workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 0, 0.5)
		TweenService:Create(Lighting, TweenInfo.new(0.2), {Brightness = 5}):Play()
		task.delay(0.25, function()
			TweenService:Create(Lighting, TweenInfo.new(0.6), {Brightness = 2}):Play()
		end)
	end
end

local function projectile(from, to)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(3, 3, 3)
	p.Color = Color3.fromRGB(255, 60, 40)
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Parent = folder
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - t0) / 1.2
		if t >= 1 or not p.Parent then
			conn:Disconnect()
			p:Destroy()
			shockwave(to)
			return
		end
		p.Position = from:Lerp(to, t)
	end)
	table.insert(conns, conn)
end

local function spawnBoss()
	local idx = rng:NextInteger(1, #CONFIG.BOSSES)
	local cfg = table.clone(CONFIG.BOSSES[idx])
	cfg.index = idx
	local h = hrp()
	local base = h and h.Position or Vector3.new()
	local a = rng:NextNumber(0, math.pi * 2)
	local spawnAt = base + Vector3.new(math.cos(a) * 180, 0, math.sin(a) * 180)
	local model = makeBossModel(cfg)
	local rowFrame, fill = makeBar(cfg.name)
	local boss = {model = model, hp = cfg.hp, maxHp = cfg.hp, row = rowFrame, fill = fill, pos = spawnAt, nextAttack = os.clock() + 2, name = cfg.name}
	table.insert(bosses, boss)
	alert("⚠ " .. cfg.name .. " APARECIÓ | PELIGRO: EXTREMO", Color3.fromRGB(255, 60, 60))
	TweenService:Create(Lighting, TweenInfo.new(1), {Ambient = Color3.fromRGB(40, 0, 0)}):Play()
end

local function defeat(boss)
	alert("DERROTADO: " .. boss.name .. " (visual)", Color3.fromRGB(120, 255, 160))
	boss.row:Destroy()
	boss.model:Destroy()
	for i = #bosses, 1, -1 do
		if bosses[i] == boss then table.remove(bosses, i) end
	end
	TweenService:Create(Lighting, TweenInfo.new(2), {Ambient = Color3.fromRGB(70, 70, 70)}):Play()
end

local function hitNearest()
	local h = hrp()
	if not h then return end
	local best, bestDist = nil, math.huge
	for _, b in ipairs(bosses) do
		local d = (b.pos - h.Position).Magnitude
		if d < bestDist then best, bestDist = b, d end
	end
	if best then
		best.hp = math.max(0, best.hp - rng:NextInteger(15, 30))
		best.fill.Size = UDim2.new(best.hp / best.maxHp, 0, 1, 0)
		if best.hp <= 0 then defeat(best) end
	end
end

table.insert(conns, RunService.Heartbeat:Connect(function(dt)
	if not enabled then return end
	local now = os.clock()
	if now >= nextSpawn and #bosses < 2 then
		nextSpawn = now + rng:NextNumber(CONFIG.SPAWN_EVERY[1], CONFIG.SPAWN_EVERY[2])
		spawnBoss()
	end
	local h = hrp()
	for _, b in ipairs(bosses) do
		local target = h and h.Position or b.pos
		local flat = Vector3.new(target.X - b.pos.X, 0, target.Z - b.pos.Z)
		local dist = flat.Magnitude
		local dir = dist > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
		if dist > 80 then b.pos += dir * 40 * dt end
		b.model:PivotTo(CFrame.lookAt(Vector3.new(b.pos.X, target.Y + 6, b.pos.Z), Vector3.new(target.X, target.Y + 6, target.Z)))
		if now >= b.nextAttack then
			b.nextAttack = now + rng:NextNumber(CONFIG.ATTACK_EVERY[1], CONFIG.ATTACK_EVERY[2])
			if rng:NextNumber() < 0.5 and h then
				projectile(b.pos + Vector3.new(0, 10, 0), target)
			else
				shockwave(b.pos)
			end
		end
	end
end))

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_TOGGLE then
		enabled = not enabled
		alert(enabled and "MODO PESADILLA: ACTIVO" or "MODO PESADILLA: PAUSADO", Color3.fromRGB(255, 120, 120))
	elseif input.KeyCode == CONFIG.KEY_HIT then
		hitNearest()
	end
end))

_G.WTH_NIGHTMARE_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	for _, b in ipairs(bosses) do
		if b.row then b.row:Destroy() end
	end
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: CATACLYSM (cataclismos) =====================
do
-- WHAT_THE_HELL_CATACLYSM.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- Cuatro desastres nuevos: SOL NEGRO, LLUVIA DE RELOJES, CIUDAD AL REVÉS (espejo) y
-- MAR DE NUBES. Todo visual, solo lo ves tú. Teclas en CONFIG.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY_BLACK_SUN = Enum.KeyCode.Z,
	KEY_CLOCKS = Enum.KeyCode.X,
	KEY_MIRROR = Enum.KeyCode.V,
	KEY_CLOUDS = Enum.KeyCode.B,
	AUTO = true,
	AUTO_INTERVAL = {30, 50},
}

if _G.WTH_CATA_CLEANUP then pcall(_G.WTH_CATA_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Cataclysm"
folder.Parent = workspace
local busy = {}
local nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_CataUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 67
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 480, 0, 38)
banner.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
banner.BackgroundTransparency = 0.15
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 16
banner.TextColor3 = Color3.fromRGB(255, 200, 120)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 200, 120)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(3.5, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function center()
	local h = hrp()
	return h and h.Position or workspace.CurrentCamera.CFrame.Position
end

-- SOL NEGRO: esfera negra con halo morado que tapa el cielo y apaga la luz
local function blackSun()
	if busy.sun then return end
	busy.sun = true
	alert("SOL NEGRO: la luz decidió tomarse el día", Color3.fromRGB(180, 120, 255))
	local c = center()
	local sun = Instance.new("Part")
	sun.Shape = Enum.PartType.Ball
	sun.Size = Vector3.new(140, 140, 140)
	sun.Color = Color3.new(0, 0, 0)
	sun.Anchored, sun.CanCollide, sun.CanQuery, sun.CanTouch = true, false, false, false
	sun.Parent = folder
	local halo = Instance.new("Part")
	halo.Shape = Enum.PartType.Ball
	halo.Size = Vector3.new(180, 180, 180)
	halo.Color = Color3.fromRGB(150, 70, 255)
	halo.Material = Enum.Material.Neon
	halo.Transparency = 0.6
	local accretion = Instance.new("Part")
	accretion.Shape = Enum.PartType.Cylinder
	accretion.Size = Vector3.new(0.4, 260, 260)
	accretion.Color = Color3.fromRGB(200, 120, 255)
	accretion.Material = Enum.Material.Neon
	accretion.Transparency = 0.6
	accretion.Anchored, accretion.CanCollide, accretion.CanQuery, accretion.CanTouch = true, false, false, false
	accretion.Parent = folder
	table.insert(conns, RunService.Heartbeat:Connect(function()
		if not accretion.Parent or not sun.Parent then return end
		accretion.CFrame = CFrame.new(sun.Position) * CFrame.Angles(math.rad(80), os.clock() * 0.8, 0)
	end))
	halo.Anchored, halo.CanCollide, halo.CanQuery, halo.CanTouch = true, false, false, false
	halo.Parent = folder
	local oldAmb, oldBright = Lighting.Ambient, Lighting.Brightness
	TweenService:Create(Lighting, TweenInfo.new(1.5), {Ambient = Color3.fromRGB(10, 0, 20), Brightness = 0.3}):Play()
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 12 then
			conn:Disconnect()
			TweenService:Create(Lighting, TweenInfo.new(1.5), {Ambient = oldAmb, Brightness = oldBright}):Play()
			sun:Destroy()
			halo:Destroy()
			busy.sun = false
			return
		end
		local p = center() + Vector3.new(120, 280, -200)
		sun.Position = p
		halo.Position = p
		halo.Size = Vector3.new(180, 180, 180) * (1 + math.sin(t * 2) * 0.05)
	end)
	table.insert(conns, conn)
end

-- LLUVIA DE RELOJES: relojes dorados que caen y se estrellan con destellos
local function clockRain()
	if busy.clocks then return end
	busy.clocks = true
	alert("LLUVIA DE RELOJES: todos marcan una hora distinta", Color3.fromRGB(255, 220, 140))
	local t0 = os.clock()
	local count = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 10 then
			conn:Disconnect()
			busy.clocks = false
			return
		end
		if count < 14 and t > count * 0.7 then
			count += 1
			local c = center()
			local target = c + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
			local clock = Instance.new("Part")
			clock.Shape = Enum.PartType.Cylinder
			clock.Size = Vector3.new(0.4, 4, 4)
			clock.Color = Color3.fromRGB(230, 190, 80)
			clock.Material = Enum.Material.Metal
			clock.Anchored, clock.CanCollide, clock.CanQuery, clock.CanTouch = true, false, false, false
			clock.Parent = folder
			local fall = 0
			local c2
			c2 = RunService.Heartbeat:Connect(function(dt)
				fall += dt
				local y = 160 - fall * 140
				if y <= 0 then
					c2:Disconnect()
					clock:Destroy()
					local boom = Instance.new("Part")
					boom.Shape = Enum.PartType.Ball
					boom.Size = Vector3.new(2, 2, 2)
					boom.Color = Color3.fromRGB(255, 240, 180)
					boom.Material = Enum.Material.Neon
					boom.Anchored, boom.CanCollide, boom.CanQuery, boom.CanTouch = true, false, false, false
					boom.Position = target
					boom.Parent = folder
					TweenService:Create(boom, TweenInfo.new(0.5), {Size = Vector3.new(12, 12, 12), Transparency = 1}):Play()
					Debris:AddItem(boom, 0.6)
					return
				end
				clock.CFrame = CFrame.new(target.X, target.Y + y, target.Z) * CFrame.Angles(fall * 4, 0, fall * 3)
			end)
			table.insert(conns, c2)
		end
	end)
	table.insert(conns, conn)
end

-- CIUDAD AL REVÉS: piezas flotando boca abajo sobre tu cabeza (solo visual)
local function mirrorCity()
	if busy.mirror then return end
	busy.mirror = true
	alert("CIUDAD AL REVÉS: hay edificios colgando del cielo", Color3.fromRGB(160, 220, 255))
	local c = center()
	local pieces = {}
	for i = 1, 12 do
		local h = rng:NextNumber(8, 40)
		local p = Instance.new("Part")
		p.Size = Vector3.new(rng:NextNumber(6, 12), h, rng:NextNumber(6, 12))
		p.Color = Color3.fromRGB(90, 100, 130)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Parent = folder
		table.insert(pieces, {part = p, x = rng:NextNumber(-80, 80), z = rng:NextNumber(-80, 80), h = h})
	end
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 12 then
			conn:Disconnect()
			for _, it in ipairs(pieces) do it.part:Destroy() end
			busy.mirror = false
			return
		end
		local base = center()
		for _, it in ipairs(pieces) do
			local bob = math.sin(t * 1.2 + it.x) * 3
			it.part.CFrame = CFrame.new(base.X + it.x, base.Y + 120 + bob, base.Z + it.z) * CFrame.Angles(math.pi, 0, 0)
		end
	end)
	table.insert(conns, conn)
end

-- MAR DE NUBES: niebla blanca muy densa a la altura de tu cintura
local function cloudSea()
	if busy.clouds then return end
	busy.clouds = true
	alert("MAR DE NUBES: nadie te avisó que el suelo era opcional", Color3.fromRGB(230, 240, 255))
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.6
	atmo.Color = Color3.fromRGB(235, 240, 255)
	atmo.Decay = Color3.fromRGB(250, 250, 255)
	atmo.Haze = 2
	atmo.Parent = Lighting
	local sea = Instance.new("Part")
	sea.Size = Vector3.new(900, 1, 900)
	sea.Color = Color3.fromRGB(245, 248, 255)
	sea.Material = Enum.Material.Neon
	sea.Transparency = 0.25
	sea.Anchored, sea.CanCollide, sea.CanQuery, sea.CanTouch = true, false, false, false
	sea.Parent = folder
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > 14 then
			conn:Disconnect()
			atmo:Destroy()
			sea:Destroy()
			busy.clouds = false
			return
		end
		local c = center()
		sea.Position = Vector3.new(c.X, c.Y - 3, c.Z)
	end)
	table.insert(conns, conn)
end


table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_BLACK_SUN then blackSun()
	elseif input.KeyCode == CONFIG.KEY_CLOCKS then clockRain()
	elseif input.KeyCode == CONFIG.KEY_MIRROR then mirrorCity()
	elseif input.KeyCode == CONFIG.KEY_CLOUDS then cloudSea() end
end))

table.insert(conns, RunService.Heartbeat:Connect(function()
	if not CONFIG.AUTO then return end
	if os.clock() >= nextAuto then
		nextAuto = os.clock() + rng:NextNumber(CONFIG.AUTO_INTERVAL[1], CONFIG.AUTO_INTERVAL[2])
		local pick = rng:NextInteger(1, 4)
		if pick == 1 then blackSun() elseif pick == 2 then clockRain() elseif pick == 3 then mirrorCity() else cloudSea() end
	end
end))

_G.WTH_CATA_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	Lighting.Brightness = 2
	folder:Destroy()
	gui:Destroy()
end
end

-- ===================== MÓDULO: VISUALS (meteoro, tornado, agujero) =====================
do
-- WHAT_THE_HELL_VISUALS.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- Versión mejorada de tres desastres: METEORO (roca con fuego, humo y cráter),
-- TORNADO (embudo con capas, polvo y escombros) y AGUJERO NEGRO (disco de acreción con brillo
-- y lente). Teclas 6, 7, 8. Todo visual, solo lo ves tú.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY_METEOR = Enum.KeyCode.Six,
	KEY_TORNADO = Enum.KeyCode.Seven,
	KEY_BLACKHOLE = Enum.KeyCode.Eight,
	METEOR_COUNT = 6,
	TORNADO_LIFE = 14,
	HOLE_LIFE = 16,
}

if _G.WTH_VIS_CLEANUP then pcall(_G.WTH_VIS_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Visuals"
folder.Parent = workspace
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Name = "WTH_VisBlur"
blur.Parent = Lighting

local function center()
	local c = player.Character
	local h = c and c:FindFirstChild("HumanoidRootPart")
	return h and h.Position or workspace.CurrentCamera.CFrame.Position
end

local function anchored(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

local function emitter(parent, rate, life, speed, size, c1, c2)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(life[1], life[2])
	pe.Speed = NumberRange.new(speed[1], speed[2])
	pe.Size = NumberSequence.new(size[1], size[2])
	pe.Color = ColorSequence.new(c1, c2)
	pe.LightEmission = 0.8
	pe.Parent = parent
	return pe
end

-- METEORO: roca con capas, cola de fuego, humo y cráter al caer
local function meteor()
	local target = center() + Vector3.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(-80, 80))
	local size = rng:NextNumber(4, 8)
	local rock = anchored(Instance.new("Part"))
	rock.Shape = Enum.PartType.Ball
	rock.Size = Vector3.new(size, size, size)
	rock.Color = Color3.fromRGB(70, 55, 45)
	rock.Material = Enum.Material.Slate
	rock.Parent = folder
	-- núcleo incandescente dentro de la roca
	local core = anchored(Instance.new("Part"))
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(size * 0.6, size * 0.6, size * 0.6)
	core.Color = Color3.fromRGB(255, 120, 30)
	core.Material = Enum.Material.Neon
	core.Parent = rock
	local trail = emitter(rock, 90, {0.4, 0.9}, {2, 6}, {size * 0.9, 0}, Color3.fromRGB(255, 170, 60), Color3.fromRGB(60, 40, 40))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Rate = 40
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(1, 3)
	smoke.Size = NumberSequence.new(size * 0.5, size * 2)
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90), Color3.fromRGB(40, 40, 40))
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Parent = rock
	local start = target + Vector3.new(rng:NextNumber(-30, 30), 280, rng:NextNumber(-30, 30))
	local dir = (target - start).Unit
	local speed = 220
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local pos = start + dir * speed * (os.clock() - t0)
		rock.Position = pos
		core.Position = pos
		rock.CFrame = CFrame.new(pos) * CFrame.Angles(dt * 5, dt * 3, 0)
		if pos.Y <= target.Y + size * 0.5 then
			conn:Disconnect()
			trail.Enabled = false
			smoke.Enabled = false
			rock:Destroy()
			-- cráter, onda de polvo y brillo de impacto
			local crater = anchored(Instance.new("Part"))
			crater.Shape = Enum.PartType.Cylinder
			crater.Size = Vector3.new(0.3, 2, 2)
			crater.CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.pi / 2)
			crater.Color = Color3.fromRGB(30, 25, 20)
			crater.Material = Enum.Material.Mud
			crater.Parent = folder
			TweenService:Create(crater, TweenInfo.new(1.2), {Size = Vector3.new(0.3, 30, 30)}):Play()
			local shock = anchored(Instance.new("Part"))
			shock.Shape = Enum.PartType.Ball
			shock.Size = Vector3.new(4, 4, 4)
			shock.Position = target
			shock.Color = Color3.fromRGB(255, 200, 140)
			shock.Material = Enum.Material.Neon
			shock.Transparency = 0.2
			shock.Parent = folder
			TweenService:Create(shock, TweenInfo.new(0.7), {Size = Vector3.new(size * 10, size * 10, size * 10), Transparency = 1}):Play()
			local dust = emitter(folder, 0, {1.5, 2.5}, {10, 20}, {4, 10}, Color3.fromRGB(150, 120, 90), Color3.fromRGB(60, 50, 40))
			dust.Enabled = false
			local att = anchored(Instance.new("Part"))
			att.Transparency = 1
			att.Size = Vector3.new(1, 1, 1)
			att.Position = target
			att.Parent = folder
			local burst = Instance.new("ParticleEmitter")
			burst.Rate = 0
			burst.Lifetime = NumberRange.new(1.2, 2)
			burst.Speed = NumberRange.new(20, 40)
			burst.Size = NumberSequence.new(size * 0.8, size * 2)
			burst.Color = ColorSequence.new(Color3.fromRGB(150, 120, 90), Color3.fromRGB(50, 40, 30))
			burst.Transparency = NumberSequence.new(0.3, 1)
			burst.Parent = att
			burst:Emit(60)
			Debris:AddItem(att, 3)
			Debris:AddItem(crater, 6)
			Debris:AddItem(shock, 1)
			Debris:AddItem(dust, 3)
			-- sacudida si estás cerca
			local d = (center() - target).Magnitude
			if d < 120 then
				blur.Size = math.clamp(1 - d / 120, 0, 1) * 6
				TweenService:Create(blur, TweenInfo.new(1.2), {Size = 0}):Play()
			end
		end
	end)
	table.insert(conns, conn)
end

-- TORNADO: embudo de capas, escombros girando y polvo a ras de suelo
local function tornado()
	local base = center() + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-60, 60))
	local layers = {}
	for i = 1, 10 do
		local w = 3 + i * 1.5
		local p = anchored(Instance.new("Part"))
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(4, w, w)
		p.Color = Color3.fromRGB(110 + i * 4, 110 + i * 4, 120 + i * 4)
		p.Material = Enum.Material.Concrete
		p.Transparency = 0.4 + i * 0.03
		p.Parent = folder
		table.insert(layers, p)
	end
	local debris = {}
	for i = 1, 30 do
		local d = anchored(Instance.new("Part"))
		d.Size = Vector3.new(1, 1, 1) * rng:NextNumber(0.6, 2)
		d.Color = Color3.fromRGB(120, 100, 80)
		d.Material = Enum.Material.Wood
		d.Parent = folder
		table.insert(debris, d)
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Rate = 120
	dust.Lifetime = NumberRange.new(1, 2)
	dust.Speed = NumberRange.new(10, 25)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Size = NumberSequence.new(3, 6)
	dust.Color = ColorSequence.new(Color3.fromRGB(160, 140, 110), Color3.fromRGB(90, 80, 70))
	dust.Transparency = NumberSequence.new(0.5, 1)
	dust.Parent = layers[1]
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > CONFIG.TORNADO_LIFE then
			conn:Disconnect()
			for _, p in ipairs(layers) do p:Destroy() end
			for _, d in ipairs(debris) do d:Destroy() end
			return
		end
		local drift = Vector3.new(math.cos(t * 0.25) * 20, 0, math.sin(t * 0.25) * 20)
		local b = base + drift
		for i, p in ipairs(layers) do
			local wob = math.sin(t * 3 + i) * (0.4 * i)
			p.CFrame = CFrame.new(b.X + wob, b.Y + (i - 1) * 3.5, b.Z) * CFrame.Angles(0, t * (2 + i * 0.4), 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
		for i, d in ipairs(debris) do
			local h = ((t * 8 + i * 2.5) % 30)
			local r = 2 + h * 0.5
			local a = t * 3 + i
			d.CFrame = CFrame.new(b + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)) * CFrame.Angles(t * 3, t * 2, 0)
		end
		local dd = (center() - b).Magnitude
		if dd < 90 then
			blur.Size = math.clamp(1 - dd / 90, 0, 1) * 5
		else
			blur.Size = math.max(0, blur.Size - 0.1)
		end
	end)
	table.insert(conns, conn)
end

-- AGUJERO NEGRO: disco de acreción con brillo, lente y chorros de luz
local function blackHole()
	local c = center() + Vector3.new(rng:NextNumber(-70, 70), 45, rng:NextNumber(-70, 70))
	local core = anchored(Instance.new("Part"))
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(12, 12, 12)
	core.Color = Color3.new(0, 0, 0)
	core.Position = c
	core.Parent = folder
	local ringParts = {}
	for i = 1, 3 do
		local r = anchored(Instance.new("Part"))
		r.Shape = Enum.PartType.Cylinder
		r.Size = Vector3.new(0.3, 16 + i * 8, 16 + i * 8)
		r.Color = Color3.fromRGB(255, 150 + i * 20, 80)
		r.Material = Enum.Material.Neon
		r.Transparency = 0.2 + i * 0.1
		r.Parent = folder
		table.insert(ringParts, r)
	end
	local glowP = anchored(Instance.new("Part"))
	glowP.Shape = Enum.PartType.Ball
	glowP.Size = Vector3.new(40, 40, 40)
	glowP.Color = Color3.fromRGB(255, 140, 60)
	glowP.Material = Enum.Material.Neon
	glowP.Transparency = 0.85
	glowP.Position = c
	glowP.Parent = folder
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > CONFIG.HOLE_LIFE then
			conn:Disconnect()
			for _, r in ipairs(ringParts) do r:Destroy() end
			core:Destroy()
			glowP:Destroy()
			blur.Size = 0
			return
		end
		for i, r in ipairs(ringParts) do
			r.CFrame = CFrame.new(c) * CFrame.Angles(math.rad(75), t * (1.5 + i * 0.6), 0)
		end
		glowP.Size = Vector3.new(40, 40, 40) * (1 + math.sin(t * 2) * 0.08)
		local dist = (center() - c).Magnitude
		blur.Size = math.clamp(1 - dist / 200, 0, 1) * 10
	end)
	table.insert(conns, conn)
end

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_METEOR then
		for i = 1, CONFIG.METEOR_COUNT do
			task.delay(rng:NextNumber(0, 2.5), meteor)
		end
	elseif input.KeyCode == CONFIG.KEY_TORNADO then tornado()
	elseif input.KeyCode == CONFIG.KEY_BLACKHOLE then blackHole() end
end))

_G.WTH_VIS_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	folder:Destroy()
	blur:Destroy()
end
end

-- ===================== MÓDULO: DEATH (muerte visual) =====================
do
-- WHAT_THE_HELL_DEATH.lua | LocalScript add-on. Solo para ti, 100% visual y local.
-- Muerte exagerada con UI animada: viñeta, glitch, texto que se escribe, barra de reinicio,
-- contador de muertes y "arranque" al volver. No mata a tu personaje (la vida es del servidor).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	KEY = Enum.KeyCode.Backspace,
	FALL_DEPTH = 3,
	FALL_TIME = 1.6,
	HOLD_TIME = 2.6,
	TYPE_SPEED = 0.045,       -- segundos por letra
	MESSAGES = {
		"ELIMINADO POR LA REALIDAD",
		"COLAPSO PERSONAL DETECTADO",
		"TU UNIVERSO TE DIO DE BAJA",
		"REINICIANDO DESDE LA ÚLTIMA ANOMALÍA",
	},
	SUBTITLES = {
		"Causa: mirar hacia arriba durante una anomalía.",
		"Causa: tomar una decisión dimensional sin consultar.",
		"Causa: la gravedad se cansó de ti.",
	},
}

if _G.WTH_DEATH_CLEANUP then pcall(_G.WTH_DEATH_CLEANUP) end

local conns = {}
local busy = false
local deaths = 0

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_DeathUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 99
gui.Parent = player:WaitForChild("PlayerGui")

-- Viñeta roja (imagen de viñeta de Roblox)
local vignette = Instance.new("ImageLabel")
vignette.Size = UDim2.fromScale(1, 1)
vignette.BackgroundTransparency = 1
vignette.Image = "rbxasset://textures/ui/Controls/vignette.png"
vignette.ImageColor3 = Color3.fromRGB(255, 0, 0)
vignette.ImageTransparency = 1
vignette.Parent = gui

local black = Instance.new("Frame")
black.Size = UDim2.fromScale(1, 1)
black.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
black.BackgroundTransparency = 1
black.BorderSizePixel = 0
black.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.new(0.5, 0, 0.45, 0)
title.Size = UDim2.new(0.9, 0, 0, 60)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 60, 60)
title.TextTransparency = 1
title.Text = ""
title.Parent = gui

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.new(0.5, 0, 0.45, 40)
sub.Size = UDim2.new(0.9, 0, 0, 24)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.GothamMedium
sub.TextSize = 16
sub.TextColor3 = Color3.fromRGB(230, 200, 200)
sub.TextTransparency = 1
sub.Text = ""
sub.Parent = gui

local counter = Instance.new("TextLabel")
counter.AnchorPoint = Vector2.new(0.5, 0)
counter.Position = UDim2.new(0.5, 0, 0.45, 72)
counter.Size = UDim2.new(0.9, 0, 0, 20)
counter.BackgroundTransparency = 1
counter.Font = Enum.Font.Code
counter.TextSize = 14
counter.TextColor3 = Color3.fromRGB(255, 220, 120)
counter.TextTransparency = 1
counter.Text = ""
counter.Parent = gui

-- Barra de reinicio
local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 1)
barBg.Position = UDim2.new(0.5, 0, 1, -80)
barBg.Size = UDim2.new(0.5, 0, 0, 10)
barBg.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
barBg.BackgroundTransparency = 1
barBg.BorderSizePixel = 0
barBg.Parent = gui
local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
barFill.BorderSizePixel = 0
barFill.Parent = barBg

local function typeText(label, text, delayStart)
	label.Text = ""
	task.delay(delayStart, function()
		for i = 1, #text do
			if not label.Parent then return end
			label.Text = text:sub(1, i)
			task.wait(CONFIG.TYPE_SPEED)
		end
	end)
end

-- Glitch: desplaza el título unos pixeles unos instantes
local function glitch(duration)
	local t0 = os.clock()
	local c
	c = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t > duration then
			c:Disconnect()
			title.Position = UDim2.new(0.5, 0, 0.45, 0)
			return
		end
		if rng:NextNumber() < 0.3 then
			title.Position = UDim2.new(0.5, rng:NextInteger(-8, 8), 0.45, rng:NextInteger(-4, 4))
		end
	end)
	table.insert(conns, c)
end

local function die()
	if busy then return end
	busy = true
	deaths += 1
	local cam = workspace.CurrentCamera
	local startCF = cam.CFrame
	local t0 = os.clock()
	local total = CONFIG.FALL_TIME + CONFIG.HOLD_TIME

	-- Viñeta y fondo rojo
	vignette.ImageTransparency = 0
	TweenService:Create(vignette, TweenInfo.new(1.2), {ImageTransparency = 0}):Play()
	TweenService:Create(black, TweenInfo.new(0.4), {BackgroundTransparency = 0.3}):Play()
	barBg.BackgroundTransparency = 0.2
	barFill.Size = UDim2.new(0, 0, 1, 0)
	TweenService:Create(barFill, TweenInfo.new(total, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)}):Play()

	-- Cámara que cae y se inclina
	local camConn
	camConn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.clamp(t / CONFIG.FALL_TIME, 0, 1)
		local ease = k * k
		cam.CFrame = startCF * CFrame.new(0, -CONFIG.FALL_DEPTH * ease, 0) * CFrame.Angles(0, 0, math.rad(25) * ease)
		if t > total then camConn:Disconnect() end
	end)
	table.insert(conns, camConn)

	-- Texto
	local message = CONFIG.MESSAGES[rng:NextInteger(1, #CONFIG.MESSAGES)]
	title.TextTransparency = 0
	sub.TextTransparency = 0
	counter.TextTransparency = 0
	glitch(0.6)
	typeText(title, message, 0.4)
	typeText(sub, CONFIG.SUBTITLES[rng:NextInteger(1, #CONFIG.SUBTITLES)], 1.2)
	counter.Text = ("Muertes en esta sesión: %d | Estabilidad: %d%%"):format(deaths, math.max(0, 100 - deaths * 7))

	-- Fin: arranque de vuelta
	task.delay(total, function()
		TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(sub, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(counter, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(vignette, TweenInfo.new(0.8), {ImageTransparency = 1}):Play()
		TweenService:Create(black, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
		TweenService:Create(barBg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		task.delay(0.8, function()
			-- "arranque" rápido: la cámara vuelve con un pequeño rebote
			local back = os.clock()
			local bounceConn
			bounceConn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - back
				if t > 0.5 then bounceConn:Disconnect(); return end
				cam.CFrame = startCF * CFrame.new(0, -0.4 * math.sin(t * 20) * (1 - t / 0.5), 0)
			end)
			table.insert(conns, bounceConn)
			busy = false
		end)
	end)
end

table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY then die() end
end))

local btn = Instance.new("TextButton")
btn.AnchorPoint = Vector2.new(0, 1)
btn.Position = UDim2.new(0, 14, 1, -110)
btn.Size = UDim2.fromOffset(120, 34)
btn.BackgroundColor3 = Color3.fromRGB(90, 0, 0)
btn.BorderSizePixel = 0
btn.Font = Enum.Font.GothamBold
btn.TextSize = 13
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Text = "MORIR (visual)"
btn.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = btn
btn.Activated:Connect(die)

_G.WTH_DEATH_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	gui:Destroy()
end
end

-- ===================== MÓDULO: SECRETS (eventos secretos) =====================
do
-- WHAT_THE_HELL_SECRETS.lua | LocalScript add-on (StarterPlayerScripts). Solo para ti, local.
-- EVENTOS SECRETOS: se desbloquean con condiciones raras que tú haces en tu cliente.
-- Se guardan en tu sesión (no se guardan entre ejecuciones). Todo visual y local.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local rng = Random.new()

local CONFIG = {
	-- Condiciones
	JUMPS_NEEDED = 25,            -- saltos totales para "ESTIRAMIENTO"
	STILL_NEEDED = 20,            -- segundos quieto para "CALMA ANTINATURAL"
	CLICKS_NEEDED = 40,           -- clics en 5 segundos para "DEDO NERVIOSO"
	DASH_NEEDED = 5,              -- dashes/saltos rápidos seguidos (visuales)
	SECRET_COOLDOWN = 60,         -- segundos entre secretos
	KEY_LIST = Enum.KeyCode.Insert,
}

if _G.WTH_SECRETS_CLEANUP then pcall(_G.WTH_SECRETS_CLEANUP) end

local conns = {}
local folder = Instance.new("Folder")
folder.Name = "WTH_Secrets"
folder.Parent = workspace
local unlocked = {}
local lastSecret = -999
local jumps = 0
local stillTime = 0
local clickTimes = {}
local lastPos = nil
local jumpWasOn = false

local gui = Instance.new("ScreenGui")
gui.Name = "WTH_SecretsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 66
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.08, 0)
banner.Size = UDim2.new(0, 500, 0, 40)
banner.BackgroundColor3 = Color3.fromRGB(12, 0, 24)
banner.BackgroundTransparency = 0.15
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 17
banner.TextColor3 = Color3.fromRGB(220, 160, 255)
banner.Text = ""
banner.Visible = false
banner.Parent = gui
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = banner

local function alert(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(220, 160, 255)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0.02, 0)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0.08, 0)}):Play()
	task.delay(4, function()
		if banner.Text == text then banner.Visible = false end
	end)
end

local function hrp()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- Lista de secretos: cada uno tiene una condición y un efecto visual
local SECRETS = {
	{
		id = "stretch", title = "ESTIRAMIENTO DIMENSIONAL",
		desc = "Desbloqueado: saltaste 25 veces. El cuerpo ya no sabe qué es arriba.",
		run = function()
			-- la cámara se estira y el mundo se ve más alto
			local cam = workspace.CurrentCamera
			local t0 = os.clock()
			local c
			c = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				if t > 4 then c:Disconnect(); return end
				local s = 1 + math.sin(t * 6) * 0.15 * (1 - t / 4)
				cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.sin(t * 3) * 0.05)
				cam.FieldOfView = 70 * s
			end)
			table.insert(conns, c)
		end,
	},
	{
		id = "calm", title = "CALMA ANTINATURAL",
		desc = "Desbloqueado: te quedaste quieto 20 segundos. Algo te observa de vuelta.",
		run = function()
			-- aparece un ojo gigante en el cielo que sigue tu cámara un rato
			local eye = Instance.new("Part")
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(120, 120, 120)
			eye.Color = Color3.fromRGB(255, 255, 255)
			eye.Material = Enum.Material.Neon
			eye.Anchored, eye.CanCollide, eye.CanQuery, eye.CanTouch = true, false, false, false
			eye.Parent = folder
			Debris:AddItem(eye, 8)
			local pupil = Instance.new("Part")
			pupil.Shape = Enum.PartType.Ball
			pupil.Size = Vector3.new(40, 40, 40)
			pupil.Color = Color3.fromRGB(180, 0, 0)
			pupil.Material = Enum.Material.Neon
			pupil.Anchored, pupil.CanCollide, pupil.CanQuery, pupil.CanTouch = true, false, false, false
			pupil.Parent = folder
			Debris:AddItem(pupil, 8)
			local t0 = os.clock()
			local c
			c = RunService.Heartbeat:Connect(function()
				local t = os.clock() - t0
				if t > 8 or not eye.Parent then c:Disconnect(); return end
				local cam = workspace.CurrentCamera.CFrame.Position
				local p = cam + workspace.CurrentCamera.CFrame.LookVector * 500 + Vector3.new(0, 120, 0)
				eye.Position = p
				pupil.Position = p + (workspace.CurrentCamera.CFrame.Position - p).Unit * 60
			end)
			table.insert(conns, c)
		end,
	},
	{
		id = "fingers", title = "DEDO NERVIOSO",
		desc = "Desbloqueado: hiciste 40 clics en 5 segundos. El universo también quiere clicar.",
		run = function()
			-- lluvia de confeti de colores por 5 segundos
			local t0 = os.clock()
			local c
			c = RunService.Heartbeat:Connect(function()
				local t = os.clock() - t0
				if t > 5 then c:Disconnect(); return end
				local h = hrp()
				local base = h and h.Position or Vector3.new()
				for _ = 1, 3 do
					local p = Instance.new("Part")
					p.Size = Vector3.new(0.8, 0.8, 0.8)
					p.Color = Color3.fromHSV(rng:NextNumber(), 0.8, 1)
					p.Material = Enum.Material.Neon
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
					p.Parent = folder
					local x, z = rng:NextNumber(-40, 40), rng:NextNumber(-40, 40)
					local fall = 0
					local c2
					c2 = RunService.Heartbeat:Connect(function(dt)
						fall += dt
						if fall > 4 then c2:Disconnect(); p:Destroy(); return end
						p.CFrame = CFrame.new(base.X + x, base.Y + 80 - fall * 18, base.Z + z) * CFrame.Angles(fall * 3, fall * 2, 0)
					end)
					table.insert(conns, c2)
				end
			end)
			table.insert(conns, c)
		end,
	},
	{
		id = "sky_ink", title = "CIELO DE TINTA",
		desc = "Desbloqueado: moviste el mouse en círculos (mucho). El cielo se tiñó.",
		run = function()
			local cc = Instance.new("ColorCorrectionEffect")
			cc.TintColor = Color3.fromRGB(120, 60, 200)
			cc.Saturation = -0.6
			cc.Parent = Lighting
			task.delay(10, function() cc:Destroy() end)
		end,
	},
}

-- Condiciones
local function unlock(secret)
	if unlocked[secret.id] then return end
	local now = os.clock()
	if now - lastSecret < CONFIG.SECRET_COOLDOWN then return end
	unlocked[secret.id] = true
	lastSecret = now
	alert("SECRETO: " .. secret.title, Color3.fromRGB(255, 220, 120))
	task.delay(0.6, function()
		alert(secret.desc, Color3.fromRGB(220, 200, 255))
	end)
	secret.run()
end

local function findSecret(id)
	for _, s in ipairs(SECRETS) do
		if s.id == id then return s end
	end
end

-- Saltos
table.insert(conns, RunService.Heartbeat:Connect(function(dt)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h then
		local onAir = h.FloorMaterial == Enum.Material.Air
		if onAir and not jumpWasOn then
			jumps += 1
			if jumps >= CONFIG.JUMPS_NEEDED then
				local s = findSecret("stretch")
				if s then unlock(s) end
			end
		end
		jumpWasOn = onAir
	end

	-- Quieto
	local root = hrp()
	if root then
		if lastPos and (root.Position - lastPos).Magnitude < 0.05 then
			stillTime += dt
			if stillTime >= CONFIG.STILL_NEEDED then
				local s = findSecret("calm")
				if s then unlock(s) end
			end
		else
			stillTime = 0
		end
		lastPos = root.Position
	end
end))

-- Clics rápidos
table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local now = os.clock()
	table.insert(clickTimes, now)
	for i = #clickTimes, 1, -1 do
		if now - clickTimes[i] > 5 then table.remove(clickTimes, i) end
	end
	if #clickTimes >= CONFIG.CLICKS_NEEDED then
		clickTimes = {}
		local s = findSecret("fingers")
		if s then unlock(s) end
	end
end))

-- Secreto de tinta: mucho movimiento de mouse en círculos (heurística simple)
local lastMouse = nil
local turns = 0
table.insert(conns, UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	local d = input.Delta
	if lastMouse then
		local cross = lastMouse.X * d.Y - lastMouse.Y * d.X
		if math.abs(cross) > 400 then turns += 1 end
		if turns >= 60 then
			turns = 0
			local s = findSecret("sky_ink")
			if s then unlock(s) end
		end
	end
	lastMouse = d
end))

-- Lista de secretos (ver desbloqueados)
table.insert(conns, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == CONFIG.KEY_LIST then
		local lines = {}
		for _, s in ipairs(SECRETS) do
			table.insert(lines, (unlocked[s.id] and "✔ " or "🔒 ") .. s.title)
		end
		alert("SECRETOS: " .. table.concat(lines, " | "), Color3.fromRGB(200, 200, 255))
	end
end))

_G.WTH_SECRETS_CLEANUP = function()
	for _, c in ipairs(conns) do c:Disconnect() end
	folder:Destroy()
	gui:Destroy()
end
end

