--!nonstrict
-- ============================================================
-- RICK PRIME REGENERATION (Delta Executor / LocalScript)
-- Los 3 videos en un solo script: miembro (brazo / pierna) y muerte completa
-- Z = brazo | X = pierna | C = todos los miembros | V = morir
-- Botones circulares arrastrables (celular) | panel ON/OFF arriba
-- Todo es LOCAL: lo ves tú. Al morir reapareces EN EL MISMO LUGAR.
-- NO salen tentáculos del suelo: los listones nacen del cuerpo.
-- v10:
--   * QUITADA la animación de "levantarse" (tumbado -> se para) de la v2.
--   * REVIVIR = el de OMEGA (emergeFromGround): el cuerpo sale del piso inclinado, con chorros de sangre.
--   * BRAZO CORTADO = animación copiada del video (sacudida al cortar, brazo abierto -> doblado -> baja).
--   * Con las 2 PIERNAS rotas te ARRASTRAS solo con los brazos hasta que se regeneran.
--   * Incluye la PISTOLA LASER v7 (fling / eliminar, tecla E cambia de modo) y la PISTOLA DE PORTALES.
-- v11 (TODO EN UN SOLO SCRIPT):
--   * La PISTOLA DE PORTALES va INCLUIDA dentro de este archivo (ya no se carga con loadstring / HttpGet).
--   * CANDADO GLOBAL: un solo candado (arriba a la derecha) que bloquea el arrastre de TODAS las interfaces:
--     botones y panel de Rick, panel de la pistola laser, menu de portales y botones flotantes.
--   * REGENERACION AUTOMATICA con control de estados (armada -> muriendo -> reviviendo -> regenerando -> completada
--     -> armada): se re-arma sola al terminar cada ciclo, sin conexiones duplicadas y con anti-bucle real.
--   * PISTOLA DE PORTALES: disparo mucho mas rapido, los portales siempre aparecen y el Touch es consistente.
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")

local jugador = Players.LocalPlayer
local playerGui = jugador:WaitForChild("PlayerGui")

-- Anti-duplicados
local env = (getgenv and getgenv()) or _G
if env.RICKPRIME_LIMPIAR then
	pcall(env.RICKPRIME_LIMPIAR)
end

local conexiones = {}
local function con(senal, fn)
	local c = senal:Connect(fn)
	table.insert(conexiones, c)
	return c
end

--------------------------------------------------------------------------------
-- CANDADO GLOBAL (v11)
-- Un solo candado para TODAS las interfaces. Abierto = se pueden mover | cerrado = todo fijo.
-- Antes el candado vivia dentro de la pistola de portales y solo conocia SU menu: los botones de Rick y el
-- panel de la pistola laser tenian su propio arrastre y nunca lo consultaban (por eso "no funcionaba").
-- Ahora todas las interfaces usan Candado.hacerArrastrable() y consultan el mismo estado.
--------------------------------------------------------------------------------
local Candado = { cerrado = false, boton = nil, gui = nil, vivo = true, paneles = {} }
env.RICKPRIME_CANDADO = Candado
do -- (bloque: los locales del candado no ocupan espacio en el chunk principal)
local movidoEn = setmetatable({}, { __mode = "k" })

function Candado.bloqueado()
	return Candado.cerrado == true
end

local function pintarCandado()
	local b = Candado.boton
	if b and b.Parent then
		b.Text = Candado.cerrado and "🔒" or "🔓"
		b.BackgroundColor3 = Candado.cerrado and Color3.fromRGB(150, 40, 50) or Color3.fromRGB(16, 70, 56)
	end
end

function Candado.alternar()
	Candado.cerrado = not Candado.cerrado
	pintarCandado()
end

-- true si el objeto acaba de ser arrastrado (para que su Activated no se dispare al soltar)
function Candado.recienMovido(obj)
	local t = movidoEn[obj]
	return t ~= nil and os.clock() - t < 0.3
end

-- evita perder una interfaz fuera de la pantalla
function Candado.sujetar(obj)
	local padre = obj.Parent
	if not (padre and padre:IsA("GuiBase2d")) then
		return
	end
	local vs = padre.AbsoluteSize
	local ap = obj.AbsolutePosition - padre.AbsolutePosition
	local as = obj.AbsoluteSize
	local dx, dy = 0, 0
	if ap.X + as.X < 80 then
		dx = 80 - (ap.X + as.X)
	elseif ap.X > vs.X - 80 then
		dx = (vs.X - 80) - ap.X
	end
	if ap.Y < 0 then
		dy = -ap.Y
	elseif ap.Y > vs.Y - 50 then
		dy = (vs.Y - 50) - ap.Y
	end
	if dx ~= 0 or dy ~= 0 then
		obj.Position = obj.Position + UDim2.fromOffset(dx, dy)
	end
end

local function esPuntero(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

local function esMovimiento(input)
	local t = input.UserInputType
	return t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch
end

-- Hace arrastrable una interfaz respetando el candado.
--   opts.handle  = elemento que recibe el toque (por defecto el propio objeto)
--   opts.alClick = funcion que se llama si se toca SIN arrastrar
-- Con el candado cerrado el objeto no se mueve, y un intento de arrastre tampoco dispara el click.
function Candado.hacerArrastrable(obj, opts)
	opts = opts or {}
	local handle = opts.handle or obj
	local alClick = opts.alClick
	local arrastrando, movido = false, false
	local inicio, posIni

	con(handle.InputBegan, function(input)
		if esPuntero(input) then
			arrastrando = true
			movido = false
			inicio = input.Position
			posIni = obj.Position
		end
	end)

	con(UIS.InputChanged, function(input)
		if not arrastrando or not esMovimiento(input) then
			return
		end
		local d = input.Position - inicio
		if d.Magnitude > 8 then
			movido = true
		end
		if movido and not Candado.bloqueado() then
			obj.Position = UDim2.new(
				posIni.X.Scale, posIni.X.Offset + d.X,
				posIni.Y.Scale, posIni.Y.Offset + d.Y
			)
		end
	end)

	con(UIS.InputEnded, function(input)
		if not arrastrando or not esPuntero(input) then
			return
		end
		arrastrando = false
		if movido then
			movidoEn[obj] = os.clock()
			if not Candado.bloqueado() then
				Candado.sujetar(obj)
			end
		elseif alClick then
			alClick()
		end
	end)
end

-- Barra superior para arrastrar un menu (la X de la derecha queda libre)
function Candado.agregar(panel, nombre)
	local barra = Instance.new("Frame")
	barra.Name = "BarraArrastre"
	barra.BackgroundTransparency = 1
	barra.BorderSizePixel = 0
	barra.Position = UDim2.new(0, 0, 0, 0)
	barra.Size = UDim2.new(1, -60, 0, 46)
	barra.Active = true
	barra.ZIndex = 10
	barra.Parent = panel
	Candado.hacerArrastrable(panel, { handle = barra })
	return barra
end

local function crearGuiCandado()
	local viejo = playerGui:FindFirstChild("RickLockGui")
	if viejo then
		viejo:Destroy()
	end

	local g = Instance.new("ScreenGui")
	g.Name = "RickLockGui"
	g.ResetOnSpawn = false
	g.DisplayOrder = 1000
	g.Parent = playerGui
	Candado.gui = g

	local b = Instance.new("TextButton")
	b.Name = "Candado"
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -52, 0, 67)
	b.Size = UDim2.new(0, 32, 0, 26)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = g

	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 7)
	esquina.Parent = b

	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(44, 160, 102)
	borde.Thickness = 1.5
	borde.Parent = b

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 2)
	pad.Parent = b

	Candado.boton = b
	pintarCandado()

	con(b.Activated, function()
		Candado.alternar()
	end)
end

crearGuiCandado()

-- si el juego borra la interfaz del candado, se vuelve a crear (conserva el estado abierto / cerrado)
task.spawn(function()
	while Candado.vivo do
		task.wait(1)
		if Candado.vivo and not (Candado.gui and Candado.gui.Parent) then
			pcall(crearGuiCandado)
		end
	end
end)
end -- fin del bloque del candado

-- ===== CONFIG =====
local CFG = {
	DamageToSever = 1, -- daño mínimo para perder un miembro (sube a 10-15 si quieres que solo pase con golpes fuertes)
	TriggerOnDamage = true,
	DamageCooldown = 0.8, -- segundos mínimos entre un miembro perdido y otro por daño
	FallToSever = true, -- caídas fuertes también te cortan un miembro (aunque el juego no tenga daño de caída)
	FallSpeedToSever = 60, -- velocidad de caída mínima (studs/s); ~60 = salto desde unos 25 studs

	-- ===== EXTRAS (se cargan junto con este script) =====
	PistolaLaser = true, -- true: te da la Pistola Laser v7 (arma en la mochila; E cambia fling / eliminar)
	PistolaPortales = true, -- true: activa la Pistola de Portales (viene INCLUIDA en este mismo script, ya no usa loadstring ni HttpGet)
	PortalGunURL = nil, -- (ya no se usa: la pistola de portales viene incluida en este script)

	DeathLoopGuard = 4, -- segundos tras COMPLETAR una regeneracion en los que una muerte cuenta como "muerte rapida" (posible zona mortal)
	MaxQuickDeaths = 2, -- muertes rapidas seguidas que SI regeneran; la siguiente reaparece normal (rompe el bucle) y la regeneracion sigue armada
	RearmSettle = 0.35, -- segundos que el personaje debe estar vivo, suelto y quieto antes de re-armar la regeneracion automatica
	RegenWatchdog = 45, -- si un ciclo dura mas que esto (algo se trabo) el estado se reinicia solo
	DeathLinger = 3.4, -- cuerpo tirado antes de regenerar
	LimbLinger = 2.0, -- miembro cortado tirado antes de regenerar
	LimbBloomTime = 0.9, -- listones saliendo del muñón
	BodyBloomTime = 0.45, -- idem en la regeneración completa
	FormTime = 0.4, -- el bloque amarillo crece / vuela a su sitio
	ClothFadeTime = 0.7, -- la ropa "se viste"
	TendrilFadeOut = 0.15, -- qué tan rápido desaparecen los listones al formarse el miembro
	MassFadeOut = 0.12, -- idem para la bola de listones del cuerpo tirado

	BloodColor = Color3.fromRGB(150, 10, 20),
	PuddleLife = 40,
	MaxPuddles = 220,
	ClearPuddlesOnBodyRegen = true,

	Quality = 1, -- baja a 0.6 si tu celular va lento (menos listones)
	CameraFx = true, -- destello de color (turquesa -> rosa -> rojo) al morir. NO mueve la cámara. false = sin destello
	CameraMotion = false, -- true: además zoom (FOV) y temblor de cámara al morir (apagado: sin movimientos de cámara)
	KeepCamera = true, -- al revivir, la cámara empieza mirando el cuerpo desde donde la tenías al morir (solo un instante; luego la mueves tú)

	-- ===== REVIVIR (copiado de OMEGA: emergeFromGround + regenBurst) =====
	Emerge = true, -- true: el cuerpo sale del piso al revivir (como en Omega)
	EmergeTime = 2.0, -- segundos que tarda en salir del piso
	EmergeDepth = 3.4, -- studs bajo el piso donde empieza (3.4 = Omega; 0 = automático según tu altura)
	EmergeTilt = 38, -- grados de inclinación al empezar (38 = Omega)
	EmergeShake = 0.14, -- temblor del cuerpo al salir (0.14 = Omega; 0 = nada)
	EmergeBlood = true, -- chorros de sangre en el piso mientras sale
	EmergeLockCamera = false, -- false = cámara LIBRE mientras sales (puedes moverla); true = se queda fija como la cámara de muerte de Omega

	-- ===== BRAZO CORTADO (copiado del video) =====
	ArmCutRecoil = true, -- sacudida del cuerpo al cortarte un brazo
	ArmRegenAnim = true, -- el brazo sale abierto, se dobla con el núcleo rojo y baja al regenerarse
	ArmAnimK = 1, -- intensidad de esas animaciones (0 = nada, 1 = video, 1.5 = más)

	-- ===== ARRASTRE (2 piernas rotas) =====
	Crawl = true, -- true: con las 2 piernas cortadas te arrastras solo
	CrawlSpeed = 5, -- velocidad al arrastrarte (studs/s)
	CrawlBlend = 0.45, -- segundos para tumbarte / volver a pararte
	CrawlArmRate = 6.5, -- qué tan rápido jalan los brazos al avanzar
	LegsRegenTogether = true, -- las 2 piernas se regeneran a la vez (te arrastras hasta que vuelven las dos)

	Sound = true,
	SfxVolume = 1,
	-- Frases que suenan al TERMINAR de revivir. Van variando: nunca repite la misma dos veces seguidas.
	VoiceLines = {
		"rbxassetid://138925430725431", -- Rick Prime
		"rbxassetid://104144683858662", -- Rick Prime: "well well well"
	},
	VoiceVolume = 1.4,
	TearOnLimbCut = false, -- true: el sonido de desgarro/explosión también suena al cortarte un miembro (solo suena al morir si es false)
	VoiceOnLimbRegen = false, -- true: también suena al regenerar un brazo / pierna
	-- ¿Quieres tus propios sonidos? Pega aquí un id, ej: splat = "rbxassetid://123456789".
	-- Ranuras: splat (sangre) | squelch (carne viscosa) | snap (hueso / pop) | thump (golpe grave) | whoosh (humo)
	-- Si un id no carga, se usa el sonido interno de Roblox; si tampoco, queda en silencio.
	CustomSounds = {
		tear = "rbxassetid://100892314541959", -- desgarro del cuerpo (al cortar / al morir)
		print = "rbxassetid://84312631986360", -- generación: suena en bucle mientras regeneras
		splat = "",
		squelch = "",
		snap = "",
		thump = "",
		whoosh = "",
	},
}

local TAM_CIRCULO = 70
local COLOR_FONDO = Color3.fromRGB(10, 10, 10)
local COLOR_ROJO = Color3.fromRGB(200, 20, 30)
local COLOR_VERDE = Color3.fromRGB(0, 200, 90)
-- ==================

local autoActivo = true
local cleaned = false

-- Anti-duplicado de efectos viejos
do
	local old = workspace:FindFirstChild("RickPrimeFX")
	if old then
		old:Destroy()
	end
end
local fx = Instance.new("Folder")
fx.Name = "RickPrimeFX"
fx.Parent = workspace

local rng = Random.new()
local function rand(a, b)
	return rng:NextNumber(a, b)
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

--------------------------------------------------------------------------------
-- Utilidades: Ticker (un solo Heartbeat), Scope (limpieza), geometría
--------------------------------------------------------------------------------
local Ticker = { list = {} }

function Ticker.add(fn)
	table.insert(Ticker.list, fn)
end

con(RunService.Heartbeat, function(dt)
	local list = Ticker.list
	for i = #list, 1, -1 do
		local ok, done = pcall(list[i], dt)
		if not ok then
			warn("[RICKPRIME] " .. tostring(done))
			table.remove(list, i)
		elseif done then
			table.remove(list, i)
		end
	end
end)

-- Agrupa cosas (Instances o tablas con .Destroy) para limpiarlas juntas si algo se aborta.
local Scope = {}
Scope.__index = Scope

function Scope.new()
	return setmetatable({ items = {} }, Scope)
end

function Scope:Add(item)
	table.insert(self.items, item)
	return item
end

function Scope:Destroy()
	for _, item in ipairs(self.items) do
		if typeof(item) == "Instance" then
			item:Destroy()
		elseif type(item) == "table" and item.Destroy then
			item.Destroy()
		end
	end
	self.items = {}
end

local function spawnSafe(fn, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		if not ok then
			warn("[RICKPRIME] " .. tostring(err))
		end
	end)
end

local function newFxPart(size, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	return p
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Raycast hacia abajo ignorando efectos y personajes. Devuelve RaycastResult o nil.
local function groundAt(pos, up)
	local ignore = { fx }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(pos + Vector3.new(0, up or 3, 0), Vector3.new(0, -300, 0), rayParams)
end

local function surfaceCF(pos, normal)
	local ref = (math.abs(normal.X) < 0.9) and Vector3.xAxis or Vector3.zAxis
	local tangent = normal:Cross(ref).Unit
	return CFrame.fromMatrix(pos, normal, tangent) * CFrame.Angles(rand(0, 6.28), 0, 0)
end

-- base cuyo eje de salida (-Z) apunta hacia ARRIBA
local function upCF(pos)
	return CFrame.fromMatrix(pos, Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis)
end

-- Que las piezas físicas no empujen ni lancen a tu personaje
local function ignoreCharacter(part)
	local char = jugador.Character
	if not char then
		return
	end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = part
			nc.Part1 = d
			nc.Parent = part
		end
	end
end

--------------------------------------------------------------------------------
-- EFECTOS DE CÁMARA (zoom, temblor, destello turquesa -> rosa -> rojo)
--------------------------------------------------------------------------------
local grade = Instance.new("ColorCorrectionEffect")
grade.Enabled = false
grade.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

local shakeAmp, shakeStart, shakeEnd = 0, 0, 0
pcall(function()
	RunService:BindToRenderStep("RickPrimeShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		local cam = workspace.CurrentCamera
		if now >= shakeEnd or not cam then
			return
		end
		local k = (shakeEnd - now) / (shakeEnd - shakeStart)
		local a = shakeAmp * k * k
		cam.CFrame = cam.CFrame
			* CFrame.new((math.random() - 0.5) * 2 * a, (math.random() - 0.5) * 2 * a, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * a * 0.08)
	end)
end)

local CamFx = {}
local gradeToken = 0

-- mantiene la cámara en un CFrame fijo un rato (para que al reaparecer no se voltee a un lado)
local camHold = nil
pcall(function()
	RunService:BindToRenderStep("RickPrimeCamHold", Enum.RenderPriority.Camera.Value + 2, function()
		local cam = workspace.CurrentCamera
		if not camHold or not cam then
			return
		end
		if os.clock() >= camHold.untilT then
			camHold = nil
			return
		end
		cam.CFrame = camHold.cf
	end)
end)
function CamFx.hold(cf)
	if CFG.KeepCamera and cf then
		camHold = { cf = cf, untilT = os.clock() + 10 } -- tope de seguridad
	end
end
function CamFx.release(delay)
	if camHold then
		camHold.untilT = os.clock() + (delay or 0.5)
	end
end
local WHITE = Color3.new(1, 1, 1)

local function shake(amp, duration)
	shakeAmp = amp
	shakeStart = os.clock()
	shakeEnd = shakeStart + duration
end

local function playGrade(steps)
	gradeToken += 1
	local token = gradeToken
	grade.Enabled = true
	blur.Enabled = true
	task.spawn(function()
		for _, s in ipairs(steps) do
			if token ~= gradeToken or cleaned then
				return
			end
			local info = TweenInfo.new(s.t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(grade, info, {
				TintColor = s.tint,
				Saturation = s.sat or 0,
				Brightness = s.bri or 0,
			}):Play()
			TweenService:Create(blur, info, { Size = s.blur or 0 }):Play()
			task.wait(s.t)
		end
		if token == gradeToken and not cleaned then
			grade.Enabled = false
			blur.Enabled = false
		end
	end)
end

local function punchFov(toFov, inTime, outTime)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local base = cam.FieldOfView
	TweenService:Create(cam, TweenInfo.new(inTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = toFov }):Play()
	task.delay(inTime, function()
		TweenService:Create(cam, TweenInfo.new(outTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { FieldOfView = base }):Play()
	end)
end

function CamFx.death()
	if not CFG.CameraFx then
		return
	end
	if CFG.CameraMotion then
		punchFov(28, 0.1, 0.9)
		shake(0.7, 0.7)
	end
	playGrade({
		{ t = 0.10, tint = Color3.fromRGB(40, 255, 230), sat = 1.5, bri = 0.2, blur = 26 }, -- turquesa
		{ t = 0.12, tint = Color3.fromRGB(255, 150, 210), sat = 1, bri = 0.1, blur = 30 }, -- rosa
		{ t = 0.12, tint = Color3.fromRGB(190, 20, 25), sat = 0, bri = -0.08, blur = 22 }, -- nube roja
		{ t = 0.65, tint = WHITE, sat = 0, bri = 0, blur = 0 },
	})
end

function CamFx.sever()
	if not CFG.CameraFx then
		return
	end
	if CFG.CameraMotion then
		shake(0.35, 0.3)
	end
	playGrade({
		{ t = 0.06, tint = Color3.fromRGB(255, 110, 110), sat = 0.3, bri = 0.08, blur = 6 },
		{ t = 0.30, tint = WHITE, sat = 0, bri = 0, blur = 0 },
	})
end

--------------------------------------------------------------------------------
-- FX: humo, nube de sangre, brillo rojo, fragmentos negros
--------------------------------------------------------------------------------
local Fx = {}
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function makeEmitter(parent, color, size0, size1, transp0, life, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEX
	e.Color = ColorSequence.new(color)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, transp0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size0),
		NumberSequenceKeypoint.new(1, size1),
	})
	e.Lifetime = NumberRange.new(life * 0.7, life * 1.3)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = 0
	e.Parent = parent
	return e
end

local function emitBurst(pos, color, size0, size1, count, speed, life, transp0)
	local p = newFxPart(Vector3.one, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.Position = pos
	p.Parent = fx
	makeEmitter(p, color, size0, size1, transp0, life, speed):Emit(count)
	Debris:AddItem(p, life * 1.4 + 0.5)
end

function Fx.puff(pos, scale, count)
	emitBurst(pos, Color3.fromRGB(235, 235, 235), 1.2 * scale, 4 * scale, count or 14, 5, 1.1, 0.35)
end

function Fx.bloodCloud(pos, scale)
	emitBurst(pos, Color3.fromRGB(110, 8, 15), 1.5 * scale, 5 * scale, 22, 14, 0.8, 0.2)
end

-- vapor que se queda un rato pegado a una parte (sigue al personaje)
function Fx.steam(part, duration)
	local e = makeEmitter(part, Color3.fromRGB(240, 240, 240), 0.8, 2.6, 0.55, 1.2, 3)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Speed = NumberRange.new(2, 4)
	e.Rate = 16
	task.delay(duration, function()
		if e.Parent then
			e.Enabled = false
		end
	end)
	Debris:AddItem(e, duration + 2)
end

-- bola neón que se expande y se apaga (el brillo rojo al cortar)
function Fx.glow(pos, color, size, duration)
	local ball = newFxPart(Vector3.one * 0.5, color, Enum.Material.Neon)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.25
	ball.Position = pos
	ball.Parent = fx
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 4
	light.Parent = ball
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ball, info, { Size = Vector3.one * size, Transparency = 1 }):Play()
	TweenService:Create(light, info, { Brightness = 0 }):Play()
	Debris:AddItem(ball, duration + 0.1)
end

-- fragmentos negros que ruedan por el piso
function Fx.shards(origin, count)
	for _ = 1, count do
		local s = rand(0.3, 0.6)
		local p = Instance.new("Part")
		p.Size = Vector3.new(s, s * rand(0.6, 1), s)
		p.Color = Color3.fromRGB(22, 18, 20)
		p.Material = Enum.Material.Slate
		p.CanTouch = false
		p.CanQuery = false
		p.CFrame = CFrame.new(origin) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		ignoreCharacter(p)
		p.Parent = fx
		p.AssemblyLinearVelocity = Vector3.new(rand(-18, 18), rand(14, 30), rand(-18, 18))
		p.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
		Debris:AddItem(p, 5)
	end
end

--------------------------------------------------------------------------------
-- SONIDOS (se prueban al iniciar; el que no cargue simplemente no suena)
--------------------------------------------------------------------------------
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Sfx = { ready = {}, last = {}, loops = {}, voices = {}, voiceLast = nil }
local SOUND_FALLBACKS = {
	tear = {}, -- sin interno: solo suena si carga el id de CustomSounds
	print = {},
	splat = { "rbxasset://sounds/splat.wav" },
	squelch = { "rbxasset://sounds/impact_water.mp3" },
	snap = { "rbxasset://sounds/snap.mp3" },
	thump = { "rbxasset://sounds/bass.wav" },
	whoosh = { "rbxasset://sounds/swoosh.wav" },
}

task.spawn(function()
	local activos = {}
	for slot, fallbacks in pairs(SOUND_FALLBACKS) do
		local candidatos = {}
		local propio = CFG.CustomSounds[slot]
		if propio and propio ~= "" then
			table.insert(candidatos, propio)
		end
		for _, id in ipairs(fallbacks) do
			table.insert(candidatos, id)
		end
		for _, id in ipairs(candidatos) do
			local s = Instance.new("Sound")
			s.SoundId = id
			local ok = pcall(function()
				ContentProvider:PreloadAsync({ s })
			end)
			local bueno = ok and s.TimeLength > 0
			s:Destroy()
			if bueno then
				Sfx.ready[slot] = id
				table.insert(activos, slot)
				break
			end
		end
		if not Sfx.ready[slot] and #fallbacks == 0 then
			local propio2 = CFG.CustomSounds[slot]
			if propio2 and propio2 ~= "" then
				Sfx.ready[slot] = propio2
				table.insert(activos, slot .. "(sin verificar)")
			end
		end
	end
	table.sort(activos)
	print("[RICKPRIME] Sonidos activos: " .. (#activos > 0 and table.concat(activos, ", ") or "ninguno"))
end)

-- pos = nil -> suena en 2D (para lo grande, como la muerte)
function Sfx.play(slot, pos, volume, pitch)
	if not CFG.Sound then
		return
	end
	local id = Sfx.ready[slot]
	if not id then
		return
	end
	local now = os.clock()
	if Sfx.last[slot] and now - Sfx.last[slot] < 0.05 then
		return
	end
	Sfx.last[slot] = now

	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = math.clamp((volume or 1) * CFG.SfxVolume, 0, 10)
	s.PlaybackSpeed = (pitch or 1) * rand(0.92, 1.08)
	if pos then
		local holder = newFxPart(Vector3.one * 0.2, Color3.new(1, 1, 1))
		holder.Transparency = 1
		holder.Position = pos
		holder.Parent = fx
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
		s.Parent = holder
		Debris:AddItem(holder, 6)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 6)
	end
	s:Play()
end

-- Frase de voz al terminar de revivir. Rota en orden aleatorio: no repite hasta que salgan todas
-- y nunca suenan dos a la vez.
local voiceBag = {}
local voiceBusy = false
function Sfx.voice()
	if not CFG.Sound or #CFG.VoiceLines == 0 or voiceBusy then
		return
	end
	if #voiceBag == 0 then
		for i = 1, #CFG.VoiceLines do
			table.insert(voiceBag, i)
		end
		for i = #voiceBag, 2, -1 do
			local j = rng:NextInteger(1, i)
			voiceBag[i], voiceBag[j] = voiceBag[j], voiceBag[i]
		end
		if #voiceBag > 1 and voiceBag[#voiceBag] == Sfx.voiceLast then
			voiceBag[1], voiceBag[#voiceBag] = voiceBag[#voiceBag], voiceBag[1]
		end
	end
	local idx = table.remove(voiceBag)
	Sfx.voiceLast = idx

	voiceBusy = true
	task.spawn(function()
		local s = Instance.new("Sound")
		s.SoundId = CFG.VoiceLines[idx]
		s.Volume = math.clamp(CFG.VoiceVolume * CFG.SfxVolume, 0, 10)
		s.Parent = SoundService -- 2D: se oye clara sin importar dónde estés
		local t = os.clock()
		while not s.IsLoaded and os.clock() - t < 5 do
			task.wait(0.1)
		end
		if not s.IsLoaded then
			warn("[RICKPRIME] NO cargó el audio: " .. s.SoundId .. " (privado o sin permiso)")
			s:Destroy()
			voiceBusy = false
			return
		end
		s:Play()
		Debris:AddItem(s, math.max(s.TimeLength, 1) + 2)
		task.wait(math.max(s.TimeLength, 0.5))
		voiceBusy = false
	end)
end

-- sonido en bucle (la "impresión" del cuerpo). Devuelve { Stop(fade) }.
function Sfx.loop(slot, pos, volume, speed)
	local ctrl = { Stop = function() end }
	local id = Sfx.ready[slot]
	if not CFG.Sound or not id then
		return ctrl
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = math.clamp((volume or 1) * CFG.SfxVolume, 0, 10)
	s.PlaybackSpeed = speed or 1
	local holder
	if pos then
		holder = newFxPart(Vector3.one * 0.2, Color3.new(1, 1, 1))
		holder.Transparency = 1
		holder.Position = pos
		holder.Parent = fx
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 140
		s.Parent = holder
	else
		s.Parent = SoundService
	end
	s:Play()
	local target = holder or s
	Debris:AddItem(target, 20) -- seguro por si algo falla antes del Stop
	Sfx.loops[ctrl] = target
	function ctrl.Stop(fade)
		if Sfx.loops[ctrl] == nil then
			return
		end
		Sfx.loops[ctrl] = nil
		fade = fade or 0.2
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(fade), { Volume = 0 }):Play()
		end
		Debris:AddItem(target, fade + 0.1)
	end
	return ctrl
end

--------------------------------------------------------------------------------
-- SANGRE: charcos (cilindros aplanados en racimos) y gotas
--------------------------------------------------------------------------------
local Blood = { mine = {}, all = {}, layer = 0 }
local GRAVITY = 90

function Blood.disc(pos, normal, diameter)
	-- cada disco en una altura distinta para que los racimos no hagan z-fighting
	Blood.layer = (Blood.layer + 1) % 60
	local height = 0.025 + Blood.layer * 0.0015
	local th = 0.05
	local color = CFG.BloodColor:Lerp(Color3.new(0, 0, 0), rand(0, 0.35))
	local p = newFxPart(Vector3.new(th, diameter * 0.2, diameter * 0.2), color)
	p.Shape = Enum.PartType.Cylinder
	p.Reflectance = 0.04
	p.CFrame = surfaceCF(pos + normal * height, normal)
	p.Parent = fx
	TweenService:Create(p, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(th, diameter, diameter * rand(0.8, 1.15)),
	}):Play()

	table.insert(Blood.all, p)
	if #Blood.all > CFG.MaxPuddles then
		table.remove(Blood.all, 1):Destroy()
	end
	table.insert(Blood.mine, p)
	task.delay(CFG.PuddleLife, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(2), { Transparency = 1 }):Play()
			Debris:AddItem(p, 2.1)
		end
	end)
end

-- charco principal + círculos que se solapan (como en los videos)
function Blood.cluster(pos, normal, diameter)
	Blood.disc(pos, normal, diameter)
	if diameter > 2 then
		Sfx.play("splat", pos, 0.3, rand(1.1, 1.6)) -- gota grande cayendo
	end
	local extra = (diameter > 2.4) and rng:NextInteger(2, 4) or rng:NextInteger(0, 1)
	for _ = 1, extra do
		local ang = rand(0, 6.28)
		local r = diameter * 0.5 * rand(0.6, 1)
		local offset = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		Blood.disc(pos + offset, normal, diameter * rand(0.35, 0.65))
	end
end

-- los charcos se encogen y desaparecen (al empezar la regeneración completa)
function Blood.clear()
	local list = Blood.mine
	Blood.mine = {}
	for _, p in ipairs(list) do
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(0.5), { Size = Vector3.new(0.05, 0.1, 0.1) }):Play()
			Debris:AddItem(p, 0.55)
		end
	end
end

-- gotas en parábola que al caer dejan un racimo de charcos
function Blood.splatter(origin, count, radius, diaMin, diaMax)
	for _ = 1, count do
		local ang = rand(0, math.pi * 2)
		local r = radius * math.sqrt(rng:NextNumber())
		local target = origin + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local hit = groundAt(target, 3)
		local gy, land, normal
		if hit then
			gy, land, normal = hit.Position.Y, hit.Position, hit.Normal
		else
			gy = origin.Y - 3
			land = Vector3.new(target.X, gy, target.Z)
			normal = Vector3.yAxis
		end
		local y0 = origin.Y + rand(-0.5, 1)
		local start = Vector3.new(origin.X, y0, origin.Z)
		local flight = rand(0.3, 0.5) + r * 0.03 + math.sqrt(2 * math.max(0, y0 - gy) / GRAVITY)
		local vy = ((gy - y0) + 0.5 * GRAVITY * flight * flight) / flight
		local hv = Vector3.new(land.X - start.X, 0, land.Z - start.Z) / flight

		local size = rand(0.18, 0.45)
		local dark = rng:NextNumber() < 0.15
		local drop = newFxPart(Vector3.one * size, dark and Color3.fromRGB(25, 5, 8) or CFG.BloodColor)
		drop.Shape = Enum.PartType.Ball
		drop.Position = start
		drop.Parent = fx

		local t = 0
		Ticker.add(function(dt)
			t += dt
			if t >= flight then
				drop:Destroy()
				if not dark then
					Blood.cluster(land, normal, rand(diaMin, diaMax))
				end
				return true
			end
			drop.Position = start + hv * t + Vector3.new(0, vy * t - 0.5 * GRAVITY * t * t, 0)
			return false
		end)
	end
end

--------------------------------------------------------------------------------
-- LISTONES (rojos con hebras azules, enroscados). NUNCA nacen del piso.
--------------------------------------------------------------------------------
local Tendrils = {}
local RIBBON_COLORS = {
	Color3.fromRGB(168, 20, 40),
	Color3.fromRGB(104, 8, 28),
	Color3.fromRGB(190, 32, 52),
	Color3.fromRGB(40, 70, 235),
}

local function ribbonPoint(tn, s, g, t, baseCF, droop, floorY)
	local along = tn.dir * (s * tn.length * g)
	local w = tn.amp * s * g
	local off = tn.u * (math.sin(s * tn.freq + t * tn.speed + tn.phase) * w)
		+ tn.v * (math.cos(s * tn.freq * 0.8 + t * tn.speed * 1.2 + tn.phase) * w)
	local p = baseCF:PointToWorldSpace(along + off) - Vector3.new(0, droop * s * s * g, 0)
	if floorY then
		-- el piso solo FRENA los listones, jamás los emite
		p = Vector3.new(p.X, math.max(p.Y, floorY + 0.1), p.Z)
	end
	return p
end

-- o = { base=fn->CFrame, count, length, cone, width, thick, droop?, floorY?, duration? }
-- Devuelve handle con Stop(fade) y Destroy().
function Tendrils.spawn(o)
	local segs = math.max(5, math.floor(9 * CFG.Quality + 0.5))
	local count = math.max(3, math.floor(o.count * CFG.Quality + 0.5))
	local folder = Instance.new("Folder")
	folder.Name = "RP_Tendrils"
	folder.Parent = fx

	local ribbons, parts = {}, {}
	for i = 1, count do
		local theta = o.cone * (rng:NextNumber() ^ 0.8)
		local phi = rand(0, math.pi * 2)
		local dir = Vector3.new(math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), -math.cos(theta))
		local ref = (math.abs(dir.Y) < 0.9) and Vector3.yAxis or Vector3.xAxis
		local u = dir:Cross(ref).Unit
		local v = dir:Cross(u).Unit
		local color = RIBBON_COLORS[(i - 1) % #RIBBON_COLORS + 1]
		local r = {
			dir = dir, u = u, v = v,
			length = o.length * rand(0.7, 1.25),
			freq = rand(7, 11), -- enroscado apretado
			amp = rand(0.3, 0.65),
			speed = rand(5, 9),
			phase = rand(0, 6.28),
			width = o.width * rand(0.85, 1.25),
			thick = o.thick,
			segs = {},
		}
		for s = 1, segs do
			local seg = newFxPart(Vector3.new(0.2, 0.08, 0.2), color)
			seg.Reflectance = 0.06
			seg.Parent = folder
			r.segs[s] = seg
			parts[#parts + 1] = seg
		end
		ribbons[i] = r
	end

	local handle = {}
	local t, stopAt, stopFade = 0, nil, 1
	local cfs = table.create(#parts)

	function handle.Stop(fade)
		if not stopAt then
			stopFade = math.max(fade or 0.3, 0.01)
			stopAt = t
		end
	end
	handle.Destroy = function()
		handle.Stop(0.1)
	end

	local droop = o.droop or 0
	Ticker.add(function(dt)
		t += dt
		local finished = (o.duration and t >= o.duration) or (stopAt and (t - stopAt) >= stopFade)
		if finished or not folder.Parent then
			folder:Destroy()
			return true
		end
		local okBase, baseCF = pcall(o.base)
		if not okBase then
			folder:Destroy()
			return true
		end

		local gIn = math.min(t / 0.35, 1)
		gIn = 1 - (1 - gIn) * (1 - gIn)
		local gOut = o.duration and math.clamp((o.duration - t) / (o.fadeOut or 0.3), 0, 1) or 1
		local gStop = stopAt and math.clamp(1 - (t - stopAt) / stopFade, 0, 1) or 1
		local g = gIn * math.min(gOut, gStop)

		local n = 0
		for _, r in ipairs(ribbons) do
			local prev = ribbonPoint(r, 0, g, t, baseCF, droop, o.floorY)
			for i = 1, segs do
				local s = i / segs
				local cur = ribbonPoint(r, s, g, t, baseCF, droop, o.floorY)
				local seg = r.segs[i]
				local len = (cur - prev).Magnitude
				local taper = 1 - 0.5 * s
				n += 1
				if len < 0.001 then
					seg.Size = Vector3.new(r.width * taper, r.thick, 0.02)
					cfs[n] = CFrame.new(prev)
				else
					seg.Size = Vector3.new(r.width * taper, r.thick, len + 0.03)
					-- el "up" gira a lo largo del listón: se ve como cinta retorcida
					local a = s * 2.5 + t * 1.5 + r.phase
					local up = r.u * math.cos(a) + r.v * math.sin(a)
					cfs[n] = CFrame.lookAt((prev + cur) / 2, cur, up)
				end
				prev = cur
			end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		return false
	end)
	return handle
end

--------------------------------------------------------------------------------
-- RIG: grupos de partes (R6 / R15), ocultar / mostrar
--------------------------------------------------------------------------------
local Rig = {}
Rig.LIMBS = { "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

function Rig.groups(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local groups = {}
	local function add(name, names)
		local list = {}
		for _, n in ipairs(names) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				list[#list + 1] = p
			end
		end
		if #list > 0 then
			groups[name] = list
		end
	end
	if hum and hum.RigType == Enum.HumanoidRigType.R15 then
		add("Head", { "Head" })
		add("Torso", { "UpperTorso", "LowerTorso" })
		add("LeftArm", { "LeftUpperArm", "LeftLowerArm", "LeftHand" })
		add("RightArm", { "RightUpperArm", "RightLowerArm", "RightHand" })
		add("LeftLeg", { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" })
		add("RightLeg", { "RightUpperLeg", "RightLowerLeg", "RightFoot" })
	else
		add("Head", { "Head" })
		add("Torso", { "Torso" })
		add("LeftArm", { "Left Arm" })
		add("RightArm", { "Right Arm" })
		add("LeftLeg", { "Left Leg" })
		add("RightLeg", { "Right Leg" })
	end
	return groups
end

function Rig.center(parts)
	local sum = Vector3.zero
	for _, p in ipairs(parts) do
		sum += p.Position
	end
	return sum / #parts
end

function Rig.length(parts)
	local total = 0
	for _, p in ipairs(parts) do
		total += p.Size.Y
	end
	return total
end

-- hombro / cadera: punta superior de la primera parte del miembro
function Rig.socket(rootPart)
	return rootPart.CFrame:PointToWorldSpace(Vector3.new(0, rootPart.Size.Y / 2, 0))
end

-- base de listones para un miembro: eje (-Z) apunta a lo largo del miembro, hacia abajo
function Rig.limbBase(rootPart)
	return function()
		local cf = rootPart.CFrame
		local top = cf:PointToWorldSpace(Vector3.new(0, rootPart.Size.Y / 2, 0))
		return CFrame.lookAt(top, top - cf.UpVector, cf.RightVector)
	end
end

-- guarda la transparencia original (una sola vez) para poder restaurarla
local function setHidden(p, hidden)
	if p:GetAttribute("RPT") == nil then
		p:SetAttribute("RPT", p.Transparency)
	end
	p.Transparency = hidden and 1 or p:GetAttribute("RPT")
end

function Rig.hide(parts)
	for _, p in ipairs(parts) do
		setHidden(p, true)
	end
end

function Rig.hideAll(char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			setHidden(d, true)
		end
	end
end

-- muestra las partes; con fade la ropa "se viste" gradualmente
function Rig.reveal(parts, fade)
	for _, p in ipairs(parts) do
		local target = p:GetAttribute("RPT") or 0
		if fade and fade > 0 then
			p.Transparency = 1
			TweenService:Create(p, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = target,
			}):Play()
		else
			p.Transparency = target
		end
	end
end

function Rig.revealAccessories(char)
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") then
			for _, d in ipairs(acc:GetDescendants()) do
				if d:IsA("BasePart") then
					setHidden(d, false)
				end
			end
		end
	end
end

function Rig.isAlive(char, hum)
	return char.Parent ~= nil and hum.Health > 0
end

--------------------------------------------------------------------------------
-- PIEZAS: bloques lisos que quedan TIRADOS en el piso (física real, no flotan)
--------------------------------------------------------------------------------
local Piece = {}

function Piece.make(parts, fromPos, power)
	local model = Instance.new("Model")
	model.Name = "RP_Piece"
	local list, primary = {}, nil
	for _, src in ipairs(parts) do
		local p = Instance.new("Part")
		p.Name = "Chunk"
		p.Size = src.Size
		p.CFrame = src.CFrame
		p.Color = src.Color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanTouch = false
		p.CanQuery = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.8, 0.1, 1, 1)
		ignoreCharacter(p)
		p.Parent = model
		list[#list + 1] = { piece = p, src = src }
		primary = primary or p
	end
	for i = 2, #list do
		local w = Instance.new("WeldConstraint")
		w.Part0 = primary
		w.Part1 = list[i].piece
		w.Parent = primary
	end
	model.PrimaryPart = primary
	model.Parent = fx

	local dir = primary.Position - fromPos
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.2 then
		dir = Vector3.new(rand(-1, 1), 0, rand(-1, 1))
	end
	dir = dir.Unit
	primary.AssemblyLinearVelocity = dir * rand(12, 24) * power + Vector3.new(rand(-3, 3), rand(22, 36) * power, rand(-3, 3))
	primary.AssemblyAngularVelocity = Vector3.new(rand(-9, 9), rand(-9, 9), rand(-9, 9))
	return { model = model, list = list }
end

function Piece.freeze(piece)
	for _, e in ipairs(piece.list) do
		e.piece.AssemblyLinearVelocity = Vector3.zero
		e.piece.AssemblyAngularVelocity = Vector3.zero
		e.piece.Anchored = true
		e.piece.CanCollide = false
	end
end

-- suelta las soldaduras y deja cada chunk anclado, listo para animarlo individualmente
function Piece.detach(piece)
	for _, d in ipairs(piece.model:GetDescendants()) do
		if d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local out = {}
	for _, e in ipairs(piece.list) do
		e.piece.Anchored = true
		e.piece.CanCollide = false
		out[#out + 1] = { part = e.piece, src = e.src }
	end
	return out
end

function Piece.shrink(piece)
	local pos = piece.list[1].piece.Position
	for _, it in ipairs(Piece.detach(piece)) do
		TweenService:Create(it.part, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = it.part.Size * 0.1,
			Transparency = 1,
		}):Play()
	end
	Fx.puff(pos, 0.5, 8)
	Debris:AddItem(piece.model, 0.6)
end

-- Proxies: los bloques amarillos que se "convierten" en la parte real.
--   fly  = chunks de la pieza vuelan hasta la parte real (muerte)
--   grow = fantasmas que crecen sobre la parte real (miembro)
local Proxies = {}

function Proxies.run(list, fly, duration)
	local ctrl = { stopped = false, list = list }
	for _, it in ipairs(list) do
		it.startCF = it.part.CFrame
		it.baseSize = it.src.Size
	end
	local t = 0
	Ticker.add(function(dt)
		if ctrl.stopped then
			return true
		end
		t += dt
		local a = math.min(t / duration, 1)
		local e = a * a * (3 - 2 * a)
		for _, it in ipairs(list) do
			if it.part.Parent and it.src.Parent then
				if fly then
					it.part.CFrame = (a < 1) and it.startCF:Lerp(it.src.CFrame, e) or it.src.CFrame
				else
					it.part.CFrame = it.src.CFrame
					it.part.Size = it.baseSize * ((0.15 + 0.85 * e) * 1.03)
				end
			end
		end
		return false
	end)
	function ctrl.Destroy()
		ctrl.stopped = true
		for _, it in ipairs(list) do
			if it.part.Parent then
				it.part:Destroy()
			end
		end
	end
	-- desvanece los bloques mientras la ropa real aparece, luego se destruyen
	function ctrl.FadeOut(fade)
		for _, it in ipairs(list) do
			TweenService:Create(it.part, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		end
		task.delay(fade + 0.05, ctrl.Destroy)
	end
	return ctrl
end

function Proxies.ghosts(parts)
	local list = {}
	for _, src in ipairs(parts) do
		local g = newFxPart(src.Size * 0.15, src.Color)
		g.CastShadow = true
		g.CFrame = src.CFrame
		g.Parent = fx
		list[#list + 1] = { part = g, src = src }
	end
	return list
end

--------------------------------------------------------------------------------
-- ANIMACIONES
--   1) REVIVIR (copiado de OMEGA): el cuerpo sale del piso. Es la funcion emergeFromGround del script
--      Omega: arranca 3.4 studs bajo el suelo, inclinado 38 grados, y sube con easing cubico mientras
--      tiembla un poco y suelta chorros de sangre en el piso. Antes de subir hay un estallido rojo
--      (regenBurst de Omega). El root queda anclado mientras sube (como en Omega).
--   2) BRAZO CORTADO (copiado del video "Rick Prime Regeneration"):
--        al cortar:   sacudida del cuerpo (se aleja del lado cortado, cabeza ladeada, el otro brazo se abre)
--        al regenerar: el brazo sale ABIERTO hacia el costado (cuando salen los listones), luego se DOBLA
--                      (antebrazo arriba, nucleo rojo cerca del pecho), suelta vapor y BAJA al costado.
--   3) ARRASTRE: con las 2 piernas rotas el cuerpo se tumba boca abajo y avanza solo con los brazos
--      (alternando, como se arrastra un soldado) hasta que las piernas se regeneran.
--------------------------------------------------------------------------------
local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function mix(a, b, t)
	return a + (b - a) * t
end

-- articulacion (Motor6D) cuyo Part1 se llama partName
local function findJoint(char, partName)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == partName then
			return d
		end
	end
	return nil
end

-- gira lo que cuelga de la articulacion, alrededor de la articulacion (ejes del Part0) usando C0
local function offsetJoint(entry, rot)
	local pivot = entry.base.Position
	entry.j.C0 = CFrame.new(pivot) * rot * CFrame.new(-pivot) * entry.base
end

local function rotAbout3(pivot, rot)
	return CFrame.new(pivot) * rot * CFrame.new(-pivot)
end

--------------------------------------------------------------------------------
-- POSE por Transform (misma tecnica del emote de Omega: se escribe en Stepped + Heartbeat + RenderStepped
-- para que gane a la animacion de caminar). R se aplica en los ejes del Part0, alrededor de la articulacion.
--------------------------------------------------------------------------------
local Pose = { drivers = {} }

local function poseEntry(j)
	if not j then
		return nil
	end
	local c0 = j.C0
	local rc = c0 - c0.Position
	return { j = j, rc = rc, rcInv = rc:Inverse() }
end

local function poseSet(e, rot)
	if e and e.j.Parent then
		e.j.Transform = e.rcInv * rot * e.rc
	end
end

function Pose.drive(dur, step, entries)
	local list = {}
	for _, e in ipairs(entries) do
		if e then
			list[#list + 1] = e
		end
	end
	local conns, done = {}, false
	local t0 = os.clock()
	local driver = {}
	local function finish()
		if done then
			return
		end
		done = true
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		for _, e in ipairs(list) do
			if e.j.Parent then
				e.j.Transform = CFrame.new()
			end
		end
		Pose.drivers[driver] = nil
	end
	local function tick()
		if done then
			return
		end
		if cleaned then
			finish()
			return
		end
		local t = os.clock() - t0
		if t >= dur then
			finish()
			return
		end
		local ok, err = pcall(step, t)
		if not ok then
			warn("[RICKPRIME] Pose: " .. tostring(err))
			finish()
		end
	end
	table.insert(conns, RunService.Stepped:Connect(tick))
	table.insert(conns, RunService.Heartbeat:Connect(tick))
	table.insert(conns, RunService.RenderStepped:Connect(tick))
	driver.finish = finish
	Pose.drivers[driver] = true
	return driver
end

function Pose.stopAll()
	for d in pairs(Pose.drivers) do
		pcall(d.finish)
	end
end

--------------------------------------------------------------------------------
-- BRAZO: sacudida al cortar + pose al regenerar
--------------------------------------------------------------------------------
local Anim = {}

local function armJointNames(r15, side)
	if r15 then
		if side == 1 then
			return { "RightUpperArm", "RightLowerArm", "RightHand" }
		end
		return { "LeftUpperArm", "LeftLowerArm", "LeftHand" }
	end
	return { side == 1 and "Right Arm" or "Left Arm" }
end

-- side: 1 = brazo derecho, -1 = izquierdo
function Anim.cutRecoil(char, hum, gname)
	if not CFG.ArmCutRecoil then
		return
	end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local side = (gname == "RightArm") and 1 or -1
	local torsoE = poseEntry(findJoint(char, r15 and "UpperTorso" or "Torso"))
	local headE = poseEntry(findJoint(char, "Head"))
	local otherE = poseEntry(findJoint(char, armJointNames(r15, -side)[1]))
	local K = CFG.ArmAnimK
	local D = 0.6
	Pose.drive(D, function(t)
		-- golpe rapido (0.07 s) y regreso suave
		local a = (t < 0.07) and smooth01(t / 0.07) or (1 - smooth01((t - 0.07) / (D - 0.07)))
		a *= K
		-- el cuerpo se aleja del lado cortado y gira un poco
		poseSet(torsoE, CFrame.Angles(math.rad(-4) * a, math.rad(14 * side) * a, math.rad(10 * side) * a))
		-- cabeza ladeada hacia atras
		poseSet(headE, CFrame.Angles(math.rad(-12) * a, 0, math.rad(9 * side) * a))
		-- el otro brazo se abre por el impacto
		poseSet(otherE, CFrame.Angles(0, 0, math.rad(32 * -side) * a) * CFrame.Angles(math.rad(12) * a, 0, 0))
	end, { torsoE, headE, otherE })
end

-- bloom = tiempo de los listones, form = tiempo en que se forma el bloque, cloth = tiempo de la ropa
function Anim.armRegen(char, hum, gname, bloom, form, cloth)
	if not CFG.ArmRegenAnim then
		return
	end
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local side = (gname == "RightArm") and 1 or -1
	local names = armJointNames(r15, side)
	local sh = poseEntry(findJoint(char, names[1]))
	if not sh then
		return
	end
	local el = r15 and poseEntry(findJoint(char, names[2])) or nil
	local wr = r15 and poseEntry(findJoint(char, names[3])) or nil
	local K = CFG.ArmAnimK
	local T = bloom + form + cloth
	local down = math.min(0.6, cloth * 0.85)

	Pose.drive(T, function(t)
		local up = smooth01(t / 0.28) -- sale abierto hacia el costado (cuando brotan los listones)
		local fold = smooth01((t - bloom) / math.max(form, 0.05)) -- se dobla (antebrazo arriba) al formarse
		local keep = 1 - smooth01((t - (T - down)) / down) -- al final baja al costado
		local abd = mix(85, 52, fold) * up * keep
		local flex = mix(16, r15 and 34 or 70, fold) * up * keep
		poseSet(sh, CFrame.Angles(0, 0, math.rad(abd * side * K)) * CFrame.Angles(math.rad(flex * K), 0, 0))
		if el then
			poseSet(el, CFrame.Angles(math.rad(100 * fold * keep * K), 0, 0))
		end
		if wr then
			poseSet(wr, CFrame.Angles(math.rad(-12 * fold * keep * K), 0, 0))
		end
	end, { sh, el, wr })
end

--------------------------------------------------------------------------------
-- REVIVIR: salir del piso (Omega: regenBurst + emergeFromGround)
--------------------------------------------------------------------------------
local Emerge = {}

-- regenBurst de Omega: bola roja que se expande + explosion de gotas
function Emerge.burst(root)
	local pos = root.Position - Vector3.new(0, 1.2, 0)
	Fx.glow(pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(190, 15, 25), 7, 0.32)
	Fx.bloodCloud(pos + Vector3.new(0, 0.8, 0), 1)
	Blood.splatter(pos + Vector3.new(0, 0.8, 0), 14, 4, 0.8, 2.2)
	Sfx.play("splat", pos, 1, 0.9)
end

-- Devuelve { done = bool }. El root debe estar anclado y en su sitio final.
function Emerge.start(char, root, duration)
	local rootCF = root.CFrame
	local pos0 = rootCF.Position
	local baseRot = rootCF - pos0
	local _, bbSize = char:GetBoundingBox()
	local depth = (CFG.EmergeDepth > 0) and CFG.EmergeDepth or math.max(3, bbSize.Y * 0.66)
	local tilt = math.rad(CFG.EmergeTilt)
	local hit = groundAt(pos0, 3)
	local gp = hit and hit.Position or (pos0 - Vector3.new(0, 3, 0))

	local ctrl = { done = false }
	local function place(e, u)
		local shake = (1 - u) * CFG.EmergeShake
		local off = Vector3.new((rand(0, 1) - 0.5) * shake, -depth * (1 - e), (rand(0, 1) - 0.5) * shake)
		root.CFrame = CFrame.new(pos0 + off) * baseRot * CFrame.Angles(-tilt * (1 - e) ^ 1.5, 0, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	root.Anchored = true
	place(0, 0)

	local t, nextFx = 0, 0
	Ticker.add(function(dt)
		if cleaned or not root.Parent then
			ctrl.done = true
			return true
		end
		t += dt
		local u = t / duration
		if u >= 1 then
			root.CFrame = rootCF
			ctrl.done = true
			return true
		end
		local e = 1 - (1 - u) ^ 3 -- easeOut cubico, igual que Omega
		place(e, u)
		if CFG.EmergeBlood and t >= nextFx then
			nextFx = t + 0.09
			Blood.splatter(gp + Vector3.new(0, 0.4, 0), 2, 1.8, 0.5, 1.3)
		end
		return false
	end)
	return ctrl
end

--------------------------------------------------------------------------------
-- ARRASTRE: con las 2 piernas rotas el cuerpo se tumba boca abajo y avanza con los brazos
--   * El root sigue de pie y TU controlas el movimiento; solo cambian las articulaciones (C0).
--   * Brazos alternados: uno se estira hacia adelante mientras el otro jala hacia atras.
--   * Solo se anima cuando realmente avanzas; quieto, los brazos descansan a los lados.
--------------------------------------------------------------------------------
local Crawl = { state = nil }

function Crawl.stop(instant)
	local s = Crawl.state
	if not s then
		return
	end
	if instant then
		s.finishNow()
	else
		s.target = 0
	end
end

function Crawl.start(char, hum, root)
	if not CFG.Crawl or cleaned then
		return
	end
	local old = Crawl.state
	if old then
		if old.char == char then
			old.target = 1
			return
		end
		Crawl.stop(true)
	end
	if not char.PrimaryPart then
		char.PrimaryPart = root
	end

	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local rootJoint = findJoint(char, r15 and "LowerTorso" or "Torso")
	if not rootJoint or rootJoint.Part0 ~= root then
		return -- rig raro: no se anima
	end
	local torso = rootJoint.Part1

	-- geometria en el espacio del root (de pie)
	local bbCF, bbSize = char:GetBoundingBox()
	local c = root.CFrame:PointToObjectSpace(bbCF.Position)
	local feetY = c.Y - bbSize.Y / 2
	local halfT = math.max(torso.Size.Z, 1) / 2
	-- bajar el cuerpo tumbado hasta que el pecho toque el piso (ni hundido ni flotando)
	local dy = feetY + 0.05 - (c.Y - halfT)
	local rootBase = rootJoint.C0

	local joints = {}
	local function add(key, partName)
		local j = findJoint(char, partName)
		if j then
			joints[key] = { j = j, base = j.C0 }
		end
	end
	add("R", r15 and "RightUpperArm" or "Right Arm")
	add("L", r15 and "LeftUpperArm" or "Left Arm")
	add("N", "Head")

	-- sin la animacion de caminar peleando contra la pose
	local animate = char:FindFirstChild("Animate")
	local animateWasOn = false
	if animate and animate:IsA("LocalScript") and not animate.Disabled then
		animateWasOn = true
		animate.Disabled = true
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	local function stopTracks()
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
				tr:Stop(0)
			end
		end
	end
	stopTracks()

	-- sin choques mientras estas tumbado (no te empujan ni te hacen vibrar)
	local origCollide = {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d ~= root then
			local isR6Leg = (not r15) and (d.Name == "Left Leg" or d.Name == "Right Leg")
			if not isR6Leg then
				origCollide[d] = d.CanCollide
			end
		end
	end
	local collideConn = RunService.Stepped:Connect(function()
		for p in pairs(origCollide) do
			if p.Parent then
				p.CanCollide = false
			end
		end
	end)

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end)
	local baseWalk = hum.WalkSpeed
	local A0 = math.rad(90)

	local state = { char = char, target = 1, blend = 0, phase = 0, moving = 0 }
	Crawl.state = state
	local bindName = "RickPrimeCrawl"

	local function pose(dt)
		local rate = 1 / math.max(CFG.CrawlBlend, 0.05)
		if state.blend < state.target then
			state.blend = math.min(state.target, state.blend + dt * rate)
		elseif state.blend > state.target then
			state.blend = math.max(state.target, state.blend - dt * rate)
		end
		local b = smooth01(state.blend)

		-- fase de los brazos segun la velocidad real (quieto = no jala)
		local v = root.AssemblyLinearVelocity
		local sp = Vector3.new(v.X, 0, v.Z).Magnitude
		local k = math.clamp(sp / math.max(CFG.CrawlSpeed, 0.1), 0, 1)
		state.moving = mix(state.moving, k, math.min(dt * 8, 1))
		state.phase += dt * CFG.CrawlArmRate * state.moving
		local m = state.moving

		-- cuerpo tumbado boca abajo (cabeza hacia adelante) + leve balanceo al avanzar
		local sway = math.rad(7) * math.sin(state.phase) * m * b
		local offT = CFrame.new(0, dy * b, 0) * rotAbout3(c, CFrame.Angles(-A0 * b, 0, 0) * CFrame.Angles(0, 0, sway))
		rootJoint.C0 = offT * rootBase

		-- brazos alternados dentro del plano del piso: 35 grados = pegado al cuerpo, 155 = estirado hacia adelante
		local sR = (math.sin(state.phase) + 1) / 2
		local sL = (math.sin(state.phase + math.pi) + 1) / 2
		local reachR = mix(35, mix(65, 155, sR), m)
		local reachL = mix(35, mix(65, 155, sL), m)
		if joints.R then
			offsetJoint(joints.R, CFrame.Angles(0, 0, math.rad(reachR) * b))
		end
		if joints.L then
			offsetJoint(joints.L, CFrame.Angles(0, 0, -math.rad(reachL) * b))
		end
		-- cabeza levantada mirando al frente
		if joints.N then
			offsetJoint(joints.N, CFrame.Angles(math.rad(62) * b, 0, 0))
		end

		hum.WalkSpeed = mix(baseWalk, CFG.CrawlSpeed, b)
		stopTracks()
	end

	local finished = false
	function state.finishNow()
		if finished then
			return
		end
		finished = true
		pcall(function()
			RunService:UnbindFromRenderStep(bindName)
		end)
		pcall(function()
			collideConn:Disconnect()
		end)
		for p, v in pairs(origCollide) do
			if p.Parent then
				p.CanCollide = v
			end
		end
		if rootJoint.Parent then
			rootJoint.C0 = rootBase
		end
		for _, e in pairs(joints) do
			if e.j.Parent then
				e.j.C0 = e.base
			end
		end
		if animateWasOn and animate and animate.Parent then
			animate.Disabled = false
		end
		if hum.Parent then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			end)
			hum.WalkSpeed = baseWalk
		end
		if Crawl.state == state then
			Crawl.state = nil
		end
	end

	pose(0)
	RunService:BindToRenderStep(bindName, Enum.RenderPriority.Input.Value + 2, function(dt)
		if finished then
			return
		end
		if cleaned or Crawl.state ~= state or not root.Parent or not char.Parent then
			state.finishNow()
			return
		end
		local ok, err = pcall(pose, dt)
		if not ok then
			warn("[RICKPRIME] Crawl: " .. tostring(err))
			state.finishNow()
			return
		end
		if state.target == 0 and state.blend <= 0 then
			state.finishNow()
		end
	end)
end

--------------------------------------------------------------------------------
-- REGENERAR UN GRUPO (miembro / torso / cabeza)
--------------------------------------------------------------------------------
local function tendrilProfile(gname, parts)
	if gname == "Torso" then
		return {
			base = function()
				return upCF(Rig.center(parts))
			end,
			count = 20, length = 2.3, cone = math.rad(115),
			width = 0.34, thick = 0.09, droop = 0.4,
		}
	end
	-- miembros: los listones cuelgan a lo largo del miembro, apretados
	return {
		base = Rig.limbBase(parts[1]),
		count = 12, length = Rig.length(parts) * 0.95, cone = math.rad(30),
		width = 0.32, thick = 0.09, droop = 0.3,
	}
end

-- ctx = { char, hum, scope }       mode = "fly" (muerte) | "grow" (miembro)
local function regenGroup(ctx, groups, gname, piece, mode)
	local parts = groups[gname]
	if not parts then
		return
	end
	local scope = ctx.scope
	local isHead, isTorso = (gname == "Head"), (gname == "Torso")
	local fly = (mode == "fly") and piece ~= nil
	local bloom = isHead and 0.12 or ((mode == "fly") and CFG.BodyBloomTime or CFG.LimbBloomTime)
	local form = CFG.FormTime
	local alive = function()
		return not cleaned and Rig.isAlive(ctx.char, ctx.hum)
	end
	local printLoop = { Stop = function() end }

	-- animación del brazo (copiada del video): abierto -> doblado -> baja
	if mode == "grow" and (gname == "RightArm" or gname == "LeftArm") then
		Anim.armRegen(ctx.char, ctx.hum, gname, bloom, form, CFG.ClothFadeTime)
	end

	if not isHead then
		local profile = tendrilProfile(gname, parts)
		-- los listones se esfuman justo cuando el miembro termina de formarse
		profile.duration = bloom + form + 0.1
		profile.fadeOut = CFG.TendrilFadeOut
		scope:Add(Tendrils.spawn(profile))

		-- mientras brotan los listones: sonido de generación (o carne viscosa si no cargó)
		local at = Rig.center(parts)
		if mode == "grow" then
			printLoop = Sfx.loop("print", at, 1, 1)
		end
		if not Sfx.ready.print then
			Sfx.play("squelch", at, 0.9, 0.6)
			task.delay(bloom * 0.45, function()
				Sfx.play("squelch", at, 0.7, 0.85)
			end)
		end
	end

	if mode == "grow" then
		local socket = Rig.socket(parts[1])
		Fx.bloodCloud(socket, 0.6)
		Sfx.play("splat", socket, 0.8, 1.1)
		Blood.splatter(socket, 6, 2.5, 1.2, 2.6)
		if piece then
			Piece.shrink(piece)
		end
	end

	task.wait(bloom)
	if not alive() then
		printLoop.Stop(0.1)
		return
	end

	local list = fly and Piece.detach(piece) or Proxies.ghosts(parts)
	Sfx.play("snap", Rig.center(parts), 0.9, 1.3) -- el hueso "encaja"
	local proxies = scope:Add(Proxies.run(list, fly, form))
	task.wait(form)
	printLoop.Stop(0.15)
	if not alive() then
		return
	end

	-- la ropa se "viste": parte real aparece mientras el bloque amarillo se desvanece
	if isHead then
		Rig.reveal(parts, 0.2)
		Rig.revealAccessories(ctx.char)
	else
		Rig.reveal(parts, CFG.ClothFadeTime)
	end
	proxies.FadeOut(CFG.ClothFadeTime)
	Fx.puff(Rig.center(parts), isTorso and 1 or 0.75, isTorso and 18 or 12)
	Sfx.play("whoosh", Rig.center(parts), 0.8, isTorso and 0.9 or 1.2)
	if isTorso then
		Sfx.play("thump", Rig.center(parts), 0.9, 0.8)
	end
	if not isHead then
		Fx.steam(parts[1], 1.4)
	end
	if piece and fly then
		-- los chunks son los proxies: se destruyen solos al terminar el fade
		Debris:AddItem(piece.model, CFG.ClothFadeTime + 0.5)
	end
	task.wait(CFG.ClothFadeTime)
end

--------------------------------------------------------------------------------
-- ESTADO DEL PERSONAJE ACTUAL
--------------------------------------------------------------------------------
local State = { char = nil, hum = nil, busy = false, severed = {}, pieces = {}, started = {}, waiting = {} }
local pendingDeath = nil
local lastBodyRegen = -1e9 -- cuándo terminó la última regeneración completa

--------------------------------------------------------------------------------
-- CONTROL DE ESTADOS DE LA REGENERACION AUTOMATICA (v11)
--   armada       : lista; la proxima muerte dispara el ciclo
--   muriendo     : murio, el cuerpo esta tirado esperando el respawn del juego
--   reviviendo   : respawn en curso (animacion de salir del piso)
--   regenerando  : se reconstruyen cabeza / piernas / torso / brazos
--   completada   : el ciclo termino; en cuanto el personaje esta estable vuelve a ARMADA
-- Solo en ARMADA una muerte inicia un ciclo. Asi nunca se activa mientras reviven / animan / regeneran.
--------------------------------------------------------------------------------
local FASE = { ARMADA = "armada", MURIENDO = "muriendo", REVIVIENDO = "reviviendo", REGENERANDO = "regenerando", COMPLETADA = "completada" }
local fase = FASE.ARMADA
local faseDesde = os.clock()
local ciclo = 0 -- id del ciclo en curso: un hilo viejo (abortado / trabado) no puede tocar el estado de uno nuevo
local quickDeaths = 0 -- muertes rapidas seguidas tras completar (detector de zona mortal)

local function setFase(f)
	fase = f
	faseDesde = os.clock()
end

-- vigilante: si un ciclo se traba (algo del juego lo interrumpe) el estado se reinicia solo y la regeneracion queda armada
task.spawn(function()
	while not cleaned do
		task.wait(1)
		if not cleaned and fase ~= FASE.ARMADA and os.clock() - faseDesde > CFG.RegenWatchdog then
			warn("[RICKPRIME] la regeneracion se quedo trabada: se reinicia el estado")
			ciclo += 1
			local data = pendingDeath
			pendingDeath = nil
			if data then
				data.abort = true
				pcall(function()
					if data.mass and not data.massStopped then
						data.massStopped = true
						data.mass.Stop(0.1)
					end
				end)
				for _, pc in pairs(data.pieces or {}) do
					pcall(function()
						if pc.model and pc.model.Parent then
							pc.model:Destroy()
						end
					end)
				end
			end
			pcall(function()
				local c = State.char
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r then
					r.Anchored = false
				end
			end)
			State.busy = false
			setFase(FASE.ARMADA)
		end
	end
end)

-- arrastre: activo mientras las DOS piernas están cortadas
local function legsDown()
	return (State.severed.LeftLeg and State.severed.RightLeg) and true or false
end

local function updateCrawl()
	local char, hum = State.char, State.hum
	if not char or not hum then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if legsDown() and root and Rig.isAlive(char, hum) and not pendingDeath then
		Crawl.start(char, hum, root)
	else
		Crawl.stop()
	end
end

-- regenera un miembro cortado (una sola vez por miembro)
local function runLimbRegen(char, hum, groups, gname)
	if State.started[gname] then
		return
	end
	State.started[gname] = true
	spawnSafe(function()
		local ctx = { char = char, hum = hum, scope = Scope.new() }
		regenGroup(ctx, groups, gname, State.pieces[gname], "grow")
		if State.char == char then
			State.severed[gname] = nil
			State.started[gname] = nil
			State.pieces[gname] = nil
			updateCrawl()
		end
		if CFG.VoiceOnLimbRegen and not cleaned then
			Sfx.voice()
		end
	end)
end

--------------------------------------------------------------------------------
-- PERDER Y REGENERAR UN MIEMBRO  (videos "arm" y "any limb")
--------------------------------------------------------------------------------
local function severLimb(gname)
	local char, hum = State.char, State.hum
	if not char or not hum or State.busy or State.severed[gname] or not Rig.isAlive(char, hum) then
		return
	end
	local groups = Rig.groups(char)
	local parts = groups[gname]
	if not parts then
		return
	end
	State.severed[gname] = true

	-- brazo: sacudida del cuerpo (copiada del video)
	if gname == "RightArm" or gname == "LeftArm" then
		pcall(Anim.cutRecoil, char, hum, gname)
	end

	local torso = groups.Torso and groups.Torso[1] or char.PrimaryPart
	local socket = Rig.socket(parts[1])
	local center = Rig.center(parts)

	-- explosión: brillo rojo + nube + fragmentos negros + gotas
	Fx.glow(center, Color3.fromRGB(255, 70, 90), 6, 0.28)
	Fx.bloodCloud(socket, 0.8)
	Fx.shards(center, rng:NextInteger(6, 10))
	Blood.splatter(center, 12, 7, 1.6, 3.6)
	CamFx.sever()
	if CFG.TearOnLimbCut then
		Sfx.play("tear", center, 1.6, 1)
	end
	Sfx.play("splat", center, 1.3, 0.85)
	Sfx.play("snap", center, 1.0, 0.8)
	task.delay(0.12, function()
		Sfx.play("squelch", center, 0.9, 0.7)
	end)

	local piece = Piece.make(parts, torso.Position, 0.8)
	State.pieces[gname] = piece
	Rig.hide(parts)
	task.delay(0.8, function() -- el miembro cae al piso
		if piece.model.Parent then
			Sfx.play("thump", piece.list[1].piece.Position, 0.5, 1.4)
		end
	end)

	-- las 2 piernas cortadas -> te arrastras
	if gname == "LeftLeg" or gname == "RightLeg" then
		updateCrawl()
	end

	spawnSafe(function()
		task.wait(CFG.LimbLinger)
		if cleaned or not Rig.isAlive(char, hum) or State.char ~= char then
			return
		end
		local other = (gname == "LeftLeg" and "RightLeg") or (gname == "RightLeg" and "LeftLeg") or nil
		if CFG.LegsRegenTogether and other and State.severed[other] and not State.started[other] and not State.waiting[other] then
			-- la otra pierna sigue rota: esperamos y se regeneran juntas (mientras tanto te arrastras)
			State.waiting[gname] = true
			return
		end
		State.waiting[gname] = nil
		runLimbRegen(char, hum, groups, gname)
		if other and State.waiting[other] then
			State.waiting[other] = nil
			runLimbRegen(char, hum, groups, other)
		end
	end)
end

--------------------------------------------------------------------------------
-- MUERTE + REGENERACION COMPLETA  (video "death")
--------------------------------------------------------------------------------
local STEPS = {
	{ names = { "Head" }, wait = 0.15 },
	{ names = { "LeftLeg", "RightLeg" }, wait = 0.3 },
	{ names = { "Torso" }, wait = 0.3 },
	{ names = { "LeftArm", "RightArm" }, wait = 0 },
}

local function onDeath(char, hum)
	if char ~= State.char then
		return -- muerte de un personaje viejo: no toca nada del actual
	end
	Crawl.stop(true) -- si moriste arrastrándote, se suelta todo
	Pose.stopAll()
	if not autoActivo then
		return
	end
	-- solo la fase ARMADA inicia un ciclo: si ya estas muriendo / reviviendo / regenerando no se activa otra vez
	if fase ~= FASE.ARMADA or pendingDeath then
		return
	end

	-- anti-bucle (causa real del MUERTE -> RESPAWN -> MUERTE): reaparecer EN EL MISMO LUGAR donde moriste.
	-- Si ese lugar mata (vacio, lava, kill brick) el personaje moria apenas terminaba el ciclo y empezaba otro, sin fin.
	--   1) muerte en el vacio: no se puede regenerar ahi -> reaparece normal en el spawn del juego
	--   2) muertes rapidas seguidas tras completar: se permiten MaxQuickDeaths con efecto; la siguiente reaparece normal
	--      y la regeneracion automatica SIGUE armada para la muerte siguiente
	local rootV = char:FindFirstChild("HumanoidRootPart")
	if rootV then
		local okV, fpdh = pcall(function()
			return workspace.FallenPartsDestroyHeight
		end)
		if okV and type(fpdh) == "number" and rootV.Position.Y < fpdh + 30 then
			quickDeaths = 0
			return
		end
	end
	if os.clock() - lastBodyRegen < CFG.DeathLoopGuard then
		quickDeaths += 1
	else
		quickDeaths = 0
	end
	if quickDeaths >= CFG.MaxQuickDeaths then
		quickDeaths = 0
		return
	end

	local groups = Rig.groups(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	local torsoPart = groups.Torso and groups.Torso[1]
	local origin = (torsoPart or root).Position
	local yaw = 0
	if root then
		local _, y = root.CFrame:ToOrientation()
		yaw = y
	end
	local deathCF = CFrame.new(root and root.Position or origin) * CFrame.Angles(0, yaw, 0)
	local camSaved = workspace.CurrentCamera and workspace.CurrentCamera.CFrame

	-- piezas ANTES de esconder el cuerpo (copian tamaño / posición / color)
	local pieces = {}
	for gname, list in pairs(groups) do
		pieces[gname] = Piece.make(list, origin, (gname == "Torso") and 0.4 or 1)
	end

	-- el cuerpo se congela en su sitio (así la cámara NO se cae) y se esconde
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			setHidden(d, true)
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
			d.Anchored = true
		end
	end

	-- explosión de la muerte
	CamFx.death()
	Sfx.play("tear", nil, 2, 1)
	Sfx.play("thump", nil, 1.6, 0.6)
	Sfx.play("splat", nil, 1.6, 0.6)
	task.delay(0.15, function()
		Sfx.play("squelch", nil, 1.2, 0.6)
	end)
	task.delay(0.4, function()
		Sfx.play("splat", origin, 1.1, 0.8)
	end)
	task.delay(0.75, function() -- los bloques caen al piso
		Sfx.play("thump", origin, 0.9, 0.9)
	end)
	Fx.glow(origin, Color3.fromRGB(255, 70, 90), 9, 0.35)
	Fx.bloodCloud(origin, 1.8)
	Fx.puff(origin + Vector3.new(0, 1, 0), 2.4, 24) -- neblina gris que se disipa
	Fx.shards(origin, 14)
	Blood.splatter(origin, 38, 10, 2.0, 5.0)

	-- bola de listones sobre el bloque del torso (nace del cuerpo, el piso solo la frena)
	local mass
	if pieces.Torso then
		local tp = pieces.Torso.list[1].piece
		local gr = groundAt(origin, 3)
		mass = Tendrils.spawn({
			base = function()
				return upCF(tp.Position + Vector3.new(0, 0.4, 0))
			end,
			count = 24, length = 2.4, cone = math.rad(100),
			width = 0.34, thick = 0.09, droop = 0.8,
			floorY = gr and gr.Position.Y or (origin.Y - 3),
		})
	end

	ciclo += 1
	pendingDeath = { cf = deathCF, camCF = camSaved, pieces = pieces, mass = mass, t0 = os.clock(), char = char, id = ciclo }
	setFase(FASE.MURIENDO)
end

local function regenBodyCore(char, hum, data)
	State.busy = true
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		pendingDeath = nil
		State.busy = false
		return
	end

	-- el juego te hace reaparecer: te escondemos y te llevamos a donde moriste
	Rig.hideAll(char)
	root.Anchored = true
	char:PivotTo(data.cf)
	local waited = 0
	while not jugador:HasAppearanceLoaded() and waited < 3 do
		waited += task.wait(0.1)
	end
	Rig.hideAll(char) -- accesorios que llegaron tarde
	root.Anchored = true
	char:PivotTo(data.cf)
	local bbCF, bbSize = char:GetBoundingBox()
	local hit = groundAt(data.cf.Position, 3)
	if hit then
		local bottom = bbCF.Position.Y - bbSize.Y / 2
		char:PivotTo(char:GetPivot() + Vector3.new(0, hit.Position.Y - bottom + 0.05, 0))
	end
	-- cámara: una orientación inicial rápida y se suelta enseguida (la controlas tú)
	local cam = workspace.CurrentCamera
	if cam then
		pcall(function()
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = hum
		end)
	end
	CamFx.hold(data.camCF)
	CamFx.release(0.15)

	local saved = {
		walk = hum.WalkSpeed, jumpPower = hum.JumpPower, jumpHeight = hum.JumpHeight,
		autoRotate = hum.AutoRotate, display = hum.DisplayDistanceType,
	}
	data.saved = saved
	-- como en Omega: quieto mientras sale del piso
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.JumpHeight = 0
	hum.AutoRotate = false

	for _, pc in pairs(data.pieces) do
		Piece.freeze(pc)
	end

	-- el cuerpo queda tirado un rato (si el juego te reaparece antes, esperamos)
	local remain = data.t0 + CFG.DeathLinger - os.clock()
	if remain > 0 then
		task.wait(remain)
	end
	if cleaned then
		return
	end

	if CFG.ClearPuddlesOnBodyRegen then
		Blood.clear()
	end
	-- REVIVIR (Omega): estallido rojo y el cuerpo sale del piso (el root queda anclado mientras sube)
	local emerge = nil
	if CFG.Emerge and char.Parent then
		if CFG.EmergeLockCamera then
			local cam = workspace.CurrentCamera
			if cam then
				CamFx.hold(cam.CFrame)
			end
		end
		pcall(Emerge.burst, root)
		emerge = Emerge.start(char, root, math.max(CFG.EmergeTime, 0.3))
	else
		root.Anchored = false
	end

	-- empieza la regeneración: sonido de generación en bucle hasta que termine
	local printLoop = Sfx.loop("print", nil, 1.2, 1)
	if not Sfx.ready.print then
		Sfx.play("squelch", nil, 1, 0.5)
	end
	task.wait(0.3)
	if data.mass then
		data.massStopped = true
		data.mass.Stop(CFG.MassFadeOut)
	end

	local groups = Rig.groups(char)
	local ctx = { char = char, hum = hum, scope = Scope.new() }
	data.ctx = ctx
	if data.id == ciclo then
		setFase(FASE.REGENERANDO)
	end
	local running = 0
	for _, step in ipairs(STEPS) do
		if cleaned or data.abort or not Rig.isAlive(char, hum) then
			break
		end
		for _, gname in ipairs(step.names) do
			running += 1
			spawnSafe(function()
				regenGroup(ctx, groups, gname, data.pieces[gname], "fly")
				running -= 1
			end)
		end
		if step.wait > 0 then
			task.wait(step.wait)
		end
	end
	while running > 0 and not data.abort do
		task.wait()
	end
	printLoop.Stop(0.3)

	-- espera a que termine de salir del piso y devuelve la cámara
	if emerge then
		while not emerge.done and not cleaned and not data.abort do
			task.wait()
		end
		CamFx.release(0.2)
	end
	if CFG.ClearPuddlesOnBodyRegen then
		Blood.clear()
	end

	-- red de seguridad: todo visible y sin restos
	for _, parts in pairs(groups) do
		Rig.reveal(parts, 0)
	end
	Rig.revealAccessories(char)
	data.ctxDone = true
	ctx.scope:Destroy()
	for _, pc in pairs(data.pieces) do
		if pc.model.Parent then
			pc.model:Destroy()
		end
	end

	data.restored = true
	if char.Parent then
		root.Anchored = false
		hum.WalkSpeed = saved.walk
		hum.JumpPower = saved.jumpPower
		hum.JumpHeight = saved.jumpHeight
		hum.AutoRotate = saved.autoRotate
		-- ya reviviste: sale una de las frases (alternando)
		task.delay(0.25, Sfx.voice)
	end
	data.finishedOk = true
end

-- Re-arma la regeneracion automatica cuando el ciclo ya TERMINO por completo y el personaje esta estable
-- (vivo, suelto, sin animacion en curso). Nunca se re-arma a mitad de un respawn.
local function reArmar(id)
	local t0 = os.clock()
	while not cleaned and os.clock() - t0 < 8 do
		local c, h = State.char, State.hum
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if id ~= ciclo then
			return
		end
		if c and h and r and h.Health > 0 and not r.Anchored and not State.busy and not pendingDeath then
			break
		end
		task.wait(0.1)
	end
	task.wait(CFG.RearmSettle)
	if cleaned or id ~= ciclo then
		return
	end
	if fase == FASE.COMPLETADA then
		setFase(FASE.ARMADA)
	end
end

-- Cierre UNICO de todo ciclo (termino bien, se aborto o fallo): limpia restos, devuelve el control y re-arma
local function finalizarRegeneracion(char, hum, data)
	pcall(function()
		if data.mass and not data.massStopped then
			data.massStopped = true
			data.mass.Stop(0.1)
		end
	end)
	pcall(function()
		if data.ctx and not data.ctxDone then
			data.ctxDone = true
			data.ctx.scope:Destroy()
		end
	end)
	pcall(function()
		for _, pc in pairs(data.pieces or {}) do
			if pc.model and pc.model.Parent then
				pc.model:Destroy()
			end
		end
	end)
	pcall(function()
		if char and char.Parent and not data.finishedOk then
			-- el ciclo se corto a medias con el personaje vivo: se deja entero, visible y suelto
			for _, parts in pairs(Rig.groups(char)) do
				Rig.reveal(parts, 0)
			end
			Rig.revealAccessories(char)
			local r = char:FindFirstChild("HumanoidRootPart")
			if r then
				r.Anchored = false
			end
			CamFx.release(0.2)
		end
	end)
	pcall(function()
		if hum and hum.Parent and data.saved and not data.restored then
			hum.WalkSpeed = data.saved.walk
			hum.JumpPower = data.saved.jumpPower
			hum.JumpHeight = data.saved.jumpHeight
			hum.AutoRotate = data.saved.autoRotate
		end
	end)

	data.char = nil
	data.ctx = nil
	if data.id ~= ciclo then
		return -- un ciclo mas nuevo (o el vigilante) ya tomo el control del estado
	end
	if pendingDeath == data then
		pendingDeath = nil
	end
	State.busy = false
	lastBodyRegen = os.clock()
	setFase(FASE.COMPLETADA)
	local id = ciclo
	task.spawn(reArmar, id)
end

local function regenBody(char, hum, data)
	data.char = char
	local ok, err = pcall(regenBodyCore, char, hum, data)
	if not ok then
		warn("[RICKPRIME] regeneracion: " .. tostring(err))
	end
	finalizarRegeneracion(char, hum, data)
end

--------------------------------------------------------------------------------
-- ACCIONES
--------------------------------------------------------------------------------
local ACTIONS = {
	arm = function()
		severLimb(pick({ "LeftArm", "RightArm" }))
	end,
	leg = function()
		severLimb(pick({ "LeftLeg", "RightLeg" }))
	end,
	all = function()
		for _, g in ipairs(Rig.LIMBS) do
			severLimb(g)
		end
	end,
	die = function()
		local hum = State.hum
		if hum and hum.Health > 0 then
			hum.Health = 0
			pcall(function()
				hum:ChangeState(Enum.HumanoidStateType.Dead)
			end)
		end
	end,
}

local function runAction(name)
	local fn = ACTIONS[name]
	if fn then
		fn()
	end
end

-- Pierde un miembro al azar por daño / caída: varía (no repite el mismo seguido) y salta los que ya están cortados
local lastLimb = nil
local lastLimbTime = 0
local function severRandomLimb()
	if State.busy or pendingDeath then
		return
	end
	local now = os.clock()
	if now - lastLimbTime < CFG.DamageCooldown then
		return
	end
	local opts = {}
	for _, g in ipairs(Rig.LIMBS) do
		if not State.severed[g] and g ~= lastLimb then
			table.insert(opts, g)
		end
	end
	if #opts == 0 then
		for _, g in ipairs(Rig.LIMBS) do
			if not State.severed[g] then
				table.insert(opts, g)
			end
		end
	end
	if #opts == 0 then
		return
	end
	local g = opts[rng:NextInteger(1, #opts)]
	lastLimb = g
	lastLimbTime = now
	severLimb(g)
end

--------------------------------------------------------------------------------
-- VIGILAR PERSONAJE (muerte, daño)
--------------------------------------------------------------------------------
local function vigilar(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	if jugador.Character ~= char then
		return -- ya hay un personaje mas nuevo: este no se vigila
	end
	State.char = char
	State.hum = hum
	State.severed = {}
	State.pieces = {}
	State.started = {}
	State.waiting = {}

	-- conexiones de ESTE personaje: se sueltan al llegar el siguiente (sin duplicados ni referencias viejas)
	if State.conns then
		for _, c in ipairs(State.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	local cc = {}
	State.conns = cc
	local function ccon(senal, fn)
		local c = senal:Connect(fn)
		table.insert(cc, c)
		return c
	end

	ccon(hum.Died, function()
		onDeath(char, hum)
	end)

	local last = hum.Health
	ccon(hum.HealthChanged, function(health)
		local damage = last - health
		last = health
		if autoActivo and CFG.TriggerOnDamage and health > 0 and damage >= CFG.DamageToSever then
			severRandomLimb()
		end
	end)

	-- caídas: mide la velocidad al aterrizar
	local fallV = 0
	ccon(RunService.Heartbeat, function()
		if char.Parent and hum:GetState() == Enum.HumanoidStateType.Freefall then
			local r = char:FindFirstChild("HumanoidRootPart")
			if r then
				fallV = math.min(fallV, r.AssemblyLinearVelocity.Y)
			end
		end
	end)
	ccon(hum.StateChanged, function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			local v = -fallV
			fallV = 0
			if autoActivo and CFG.FallToSever and v >= CFG.FallSpeedToSever and hum.Health > 0 then
				severRandomLimb()
			end
		elseif new ~= Enum.HumanoidStateType.Freefall and new ~= Enum.HumanoidStateType.Landed then
			fallV = 0
		end
	end)
end

con(jugador.CharacterAdded, function(char)
	Crawl.stop(true)
	Pose.stopAll()
	State.busy = false
	task.spawn(vigilar, char)

	-- llego un respawn con un ciclo ya en marcha (moriste otra vez mientras reaparecias / regenerabas):
	-- el ciclo viejo se aborta limpio; este personaje reaparece normal y la regeneracion se re-arma sola al cerrar el ciclo
	if pendingDeath and pendingDeath.started and pendingDeath.char and pendingDeath.char ~= char then
		pendingDeath.abort = true
	end

	-- solo UNA regeneracion por muerte, y solo si el ciclo esta en MURIENDO
	if fase == FASE.MURIENDO and pendingDeath and not pendingDeath.started then
		local data = pendingDeath
		data.started = true
		setFase(FASE.REVIVIENDO)
		spawnSafe(function()
			local hum = char:WaitForChild("Humanoid", 10)
			if not hum then
				finalizarRegeneracion(char, nil, data)
				return
			end
			State.char = char
			State.hum = hum
			regenBody(char, hum, data)
		end)
	end
end)

if jugador.Character then
	task.spawn(vigilar, jugador.Character)
end

--------------------------------------------------------------------------------
-- INTERFAZ (mismo estilo que Phoenix Protocol)
--------------------------------------------------------------------------------
local anterior = playerGui:FindFirstChild("RickPrimeUI")
if anterior then
	anterior:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "RickPrimeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local function crearBoton(texto, tam, pos, colorTexto, colorBorde, redondo)
	local b = Instance.new("TextButton")
	b.Size = tam
	b.Position = pos
	b.BackgroundColor3 = COLOR_FONDO
	b.BorderSizePixel = 0
	b.Text = texto
	b.TextColor3 = colorTexto
	b.Font = Enum.Font.Code
	b.TextScaled = true
	b.AutoButtonColor = false
	b.Active = true
	b.Parent = gui

	if redondo then
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(1, 0)
		esquina.Parent = b

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.Parent = b
	end

	local s = Instance.new("UIStroke")
	s.Color = colorBorde
	s.Thickness = 2
	s.Parent = b

	return b
end

local function hacerArrastrable(obj, alClick)
	-- v11: usa el candado global (con el candado cerrado no se mueve; tocar sin arrastrar sigue funcionando)
	Candado.hacerArrastrable(obj, { alClick = alClick })
end

-- Panel superior (ON/OFF)
local panel = crearBoton(
	"RICK PRIME: ON",
	UDim2.new(0, 260, 0, 44),
	UDim2.new(0.5, -130, 0, 20),
	COLOR_VERDE, COLOR_ROJO
)

hacerArrastrable(panel, function()
	autoActivo = not autoActivo
	panel.Text = autoActivo and "RICK PRIME: ON" or "RICK PRIME: OFF"
	panel.TextColor3 = autoActivo and COLOR_VERDE or COLOR_ROJO
end)

-- Botones circulares
local BOTONES = {
	{ texto = "BRAZO", accion = "arm", cTexto = COLOR_ROJO, cBorde = COLOR_VERDE },
	{ texto = "PIERNA", accion = "leg", cTexto = COLOR_VERDE, cBorde = COLOR_ROJO },
	{ texto = "TODO", accion = "all", cTexto = COLOR_ROJO, cBorde = COLOR_VERDE },
	{ texto = "MORIR", accion = "die", cTexto = COLOR_ROJO, cBorde = COLOR_ROJO },
}

for i, def in ipairs(BOTONES) do
	local b = crearBoton(
		def.texto,
		UDim2.new(0, TAM_CIRCULO, 0, TAM_CIRCULO),
		UDim2.new(0, 30 + (TAM_CIRCULO + 12) * (i - 1), 1, -100),
		def.cTexto, def.cBorde, true
	)
	hacerArrastrable(b, function()
		runAction(def.accion)
	end)
end

local TECLAS = {
	[Enum.KeyCode.Z] = "arm",
	[Enum.KeyCode.X] = "leg",
	[Enum.KeyCode.C] = "all",
	[Enum.KeyCode.V] = "die",
}

con(UIS.InputBegan, function(input, procesado)
	if procesado then
		return
	end
	local accion = TECLAS[input.KeyCode]
	if accion then
		runAction(accion)
	end
end)

--------------------------------------------------------------------------------
-- Limpieza al re-ejecutar
--------------------------------------------------------------------------------
env.RICKPRIME_LIMPIAR = function()
	cleaned = true
	pcall(Crawl.stop, true)
	pcall(Pose.stopAll)
	pcall(function() -- Pistola Laser: conexiones, panel y arma
		if env.LaserConns then
			for _, c in ipairs(env.LaserConns) do
				pcall(function()
					c:Disconnect()
				end)
			end
			env.LaserConns = nil
		end
		local okH, hui = pcall(function()
			return gethui and gethui()
		end)
		local panelLaser = ((okH and hui) or playerGui):FindFirstChild("LaserPanel")
		if panelLaser then
			panelLaser:Destroy()
		end
		local mochila = jugador:FindFirstChild("Backpack")
		local t1 = mochila and mochila:FindFirstChild("LaserGun")
		if t1 then
			t1:Destroy()
		end
		local t2 = jugador.Character and jugador.Character:FindFirstChild("LaserGun")
		if t2 then
			t2:Destroy()
		end
	end)
	Candado.vivo = false
	if Candado.gui then
		pcall(function()
			Candado.gui:Destroy()
		end)
	end
	if State.conns then
		for _, c in ipairs(State.conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
	end
	for _, c in ipairs(conexiones) do
		pcall(function()
			c:Disconnect()
		end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("RickPrimeShake")
		RunService:UnbindFromRenderStep("RickPrimeCamHold")
		RunService:UnbindFromRenderStep("RickPrimeCrawl")
	end)
	Ticker.list = {}
	for ctrl in pairs(Sfx.loops) do
		pcall(ctrl.Stop, 0.05)
	end
	if gui then
		gui:Destroy()
	end
	grade:Destroy()
	blur:Destroy()
	fx:Destroy()
end

--------------------------------------------------------------------------------
-- EXTRA 1: PISTOLA LASER v7 (script tal cual lo pasaste, dentro de su propia función para que no
-- choquen sus variables con las de este script)
--------------------------------------------------------------------------------
local function iniciarPistolaLaser()
--[[ PISTOLA LASER v7 — para ejecutor (Delta/Wave/Xeno)
     - Fling: ahora se COMPRUEBA si realmente movió al objetivo (desplazamiento
       y velocidad tras el intento). Si no funcionó, se avisa y no se finge éxito.
     - Modo eliminar: solo borra Modelos con Humanoid vivo (ya no desaparecen
       props del mapa ni partes sueltas). Antes de destruir, hace un efecto de
       disolución (encogen y se desvanecen) para que no sea un "pop" instantáneo.
     - Aviso en pantalla de qué pasó en cada disparo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer

-- ===== CONFIGURACIÓN =====
local ID_PISTOLA       = 99060206427611
local ID_RESPALDO      = 212296936
local SONIDO_FLING_ID  = "71286443122760"
local ID_ELIMINAR      = "138687206526097"
local VOLUMEN          = 1
local RAYO_ID          = ""

local GRIP_AJUSTE    = CFrame.new(-1.35, -0.15, -0.05) * CFrame.Angles(math.rad(0), math.rad(-88), math.rad(0))
local BOCA_OFFSET    = Vector3.zero

local GROSOR         = 1.0
local COLOR_NORMAL   = Color3.fromRGB(255, 40, 40)
local COLOR_ELIMINAR = Color3.fromRGB(255, 40, 40)

local DISTANCIA        = 500
local DURACION_FLING   = 0.5
local VEL_ANGULAR      = 50000
local VEL_LINEAL       = 4000
local COOLDOWN         = 0.2
local UMBRAL_DESPLAZ   = 8    -- studs: si el objetivo no se movió esto, el fling "no sirvió"
local UMBRAL_VELOCIDAD = 25   -- studs/s: alternativa al desplazamiento (por si quedó frenado por algo)
local DURACION_DISOLVER = 0.2 -- segundos que tarda el efecto de desvanecido antes de Destroy

-- ===== ESTADO =====
local modoEliminar = false
local equipado = false
local ocupado = false
local mira = nil
local ultimoToque = nil
local refrescarPanel = nil
local sonidoEliminar = nil
local texturaEliminar = nil

-- ===== CONEXIONES (se limpian al reejecutar) =====
local env = (getgenv and getgenv()) or _G
if env.LaserGunConn then pcall(function() env.LaserGunConn:Disconnect() end) end
if env.LaserConns then
	for _, c in ipairs(env.LaserConns) do pcall(function() c:Disconnect() end) end
end
env.LaserConns = {}
local function conectar(senal, fn)
	local c = senal:Connect(fn)
	table.insert(env.LaserConns, c)
	return c
end

-- ===== TIPO DE ASSET DE ID_ELIMINAR =====
task.spawn(function()
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(tonumber(ID_ELIMINAR), Enum.InfoType.Asset)
	end)
	local tipo = ok and info and info.AssetTypeId or nil
	if tipo == 1 then
		texturaEliminar = ID_ELIMINAR
	elseif tipo == nil or tipo == 3 then
		sonidoEliminar = ID_ELIMINAR
	else
		warn("[LaserGun] ID_ELIMINAR es de otro tipo (AssetTypeId = " .. tostring(tipo) .. "); no se usa")
	end
end)

-- ===== UTILIDADES =====
local function colorActual()
	return modoEliminar and COLOR_ELIMINAR or COLOR_NORMAL
end

local function actualizarMira()
	if mira then mira.Color = colorActual() end
end

local function personajeJugador(inst)
	local modelo = inst:FindFirstAncestorOfClass("Model")
	if modelo and modelo:FindFirstChild("HumanoidRootPart") then
		local jugador = Players:GetPlayerFromCharacter(modelo)
		if jugador then return modelo, jugador end
	end
	return nil, nil
end

-- devuelve el Model si `inst` pertenece a un personaje con Humanoid vivo (jugador o NPC)
local function personajeConHumanoid(inst)
	local modelo = inst:FindFirstAncestorOfClass("Model")
	if not modelo then return nil end
	local hum = modelo:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and modelo:FindFirstChild("HumanoidRootPart") then
		return modelo, hum
	end
	return nil
end

-- ===== AVISO EN PANTALLA =====
local labelAviso = nil
local function aviso(texto, color)
	if not labelAviso then return end
	labelAviso.Text = texto
	labelAviso.TextColor3 = color
	labelAviso.TextTransparency = 0
	labelAviso.BackgroundTransparency = 0.35
	TweenService:Create(labelAviso, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, BackgroundTransparency = 1}):Play()
end

-- ===== PUNTO APUNTADO =====
conectar(UIS.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		ultimoToque = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

local function rayoDeApuntado()
	local camara = workspace.CurrentCamera
	if UIS:GetLastInputType() == Enum.UserInputType.Touch and ultimoToque then
		return camara:ScreenPointToRay(ultimoToque.X, ultimoToque.Y)
	elseif UIS.MouseEnabled then
		local p = UIS:GetMouseLocation()
		return camara:ViewportPointToRay(p.X, p.Y)
	end
	local c = camara.ViewportSize / 2
	return camara:ViewportPointToRay(c.X, c.Y)
end

-- ===== CARGA DEL MODELO POR ID =====
local function cargarTool(id)
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. tostring(id))
	end)
	if not ok or type(objs) ~= "table" or not objs[1] then
		warn("[LaserGun] no se pudo cargar el ID " .. tostring(id))
		return nil
	end
	local raiz = objs[1]

	for _, d in ipairs(raiz:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end

	local tool = raiz:IsA("Tool") and raiz or raiz:FindFirstChildWhichIsA("Tool", true)

	if tool then
		tool.Parent = nil
	else
		local partes = {}
		if raiz:IsA("BasePart") then table.insert(partes, raiz) end
		for _, d in ipairs(raiz:GetDescendants()) do
			if d:IsA("BasePart") then table.insert(partes, d) end
		end
		if #partes == 0 then return nil end

		local base = (raiz:IsA("Model") and raiz.PrimaryPart) or partes[1]

		for _, d in ipairs(raiz:GetDescendants()) do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") then d:Destroy() end
		end
		for _, p in ipairs(partes) do
			if p ~= base and p.Name == "Handle" then p.Name = "HandleOriginal" end
		end
		base.Name = "Handle"

		for _, p in ipairs(partes) do
			if p ~= base then
				local w = Instance.new("Weld")
				w.Part0 = base
				w.Part1 = p
				w.C0 = base.CFrame:ToObjectSpace(p.CFrame)
				w.Parent = p
			end
		end

		tool = Instance.new("Tool")
		for _, p in ipairs(partes) do p.Parent = tool end
	end

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return nil end

	tool.Name = "LaserGun"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			if d ~= handle then d.Massless = true end
		end
	end
	return tool
end

local plantilla = nil
local plantillaLista = false

local function obtenerPlantilla()
	if not plantillaLista then
		plantillaLista = true
		plantilla = cargarTool(ID_PISTOLA) or cargarTool(ID_RESPALDO)
		if not plantilla then
			warn("[LaserGun] sin modelo importado: se usa la pistola básica")
		end
	end
	return plantilla and plantilla:Clone() or nil
end

-- ===== RAYO =====
local function crearRayo(desde, hasta, color, impacto)
	local largo = (hasta - desde).Magnitude
	if largo < 0.1 then return end
	local cf = CFrame.lookAt(desde, hasta) * CFrame.new(0, 0, -largo / 2)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function capa(ancho, col, transp)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = col
		p.Transparency = transp
		p.Size = Vector3.new(ancho, ancho, largo)
		p.CFrame = cf
		p.Parent = workspace
		TweenService:Create(p, info, {
			Transparency = 1,
			Size = Vector3.new(0.01, 0.01, largo),
		}):Play()
		Debris:AddItem(p, 0.45)
	end

	capa(GROSOR * 0.4, Color3.new(1, 1, 1), 0)
	capa(GROSOR, color, 0.4)

	if impacto then
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Ball
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.Neon
		s.Color = color
		s.Transparency = 0.2
		s.Size = Vector3.new(GROSOR * 1.5, GROSOR * 1.5, GROSOR * 1.5)
		s.CFrame = CFrame.new(hasta)
		s.Parent = workspace
		TweenService:Create(s, TweenInfo.new(0.3), {
			Size = Vector3.new(GROSOR * 6, GROSOR * 6, GROSOR * 6),
			Transparency = 1,
		}):Play()
		Debris:AddItem(s, 0.4)
	end
end

local function puntoAnclado(pos)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	local a = Instance.new("Attachment")
	a.Parent = p
	return p, a
end

local function crearBeamTextura(desde, hasta, color, textura)
	local partA, attA = puntoAnclado(desde)
	local partB, attB = puntoAnclado(hasta)
	local beam = Instance.new("Beam")
	beam.Attachment0 = attA
	beam.Attachment1 = attB
	beam.Color = ColorSequence.new(color)
	beam.Width0 = GROSOR
	beam.Width1 = GROSOR * 0.4
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Texture = "rbxassetid://" .. textura
	beam.Parent = partA
	task.delay(0.2, function()
		partA:Destroy()
		partB:Destroy()
	end)
end

local function disparoVisual(desde, hasta, color, impacto, texturaModo)
	local tex = texturaModo or (RAYO_ID ~= "" and RAYO_ID or nil)
	if tex then
		crearBeamTextura(desde, hasta, color, tex)
	else
		crearRayo(desde, hasta, color, impacto)
	end
end

-- ===== SONIDO =====
local function sonar(handle, id)
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = VOLUMEN
	s.Parent = handle
	s:Play()
	Debris:AddItem(s, 8)
end

-- ===== PUNTO DE SALIDA DEL RAYO =====
local function puntoDeBoca(tool, handle)
	local base = handle.Position
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("Attachment") then
			local n = d.Name:lower()
			if n:find("muzzle") or n:find("boca") or n:find("barrel") or n:find("fire") then
				base = d.WorldPosition
				break
			end
		end
	end
	return base + handle.CFrame:VectorToWorldSpace(BOCA_OFFSET)
end

-- ===== ELIMINAR (solo local, solo personajes vivos, con disolución) =====
-- devuelve true si de verdad se eliminó un personaje
local function intentarEliminar(inst)
	local modelo, hum = personajeConHumanoid(inst)
	if not modelo then
		return false  -- no era un personaje: terreno, props del mapa, etc. No se toca nada.
	end

	local jugador = Players:GetPlayerFromCharacter(modelo)
	local nombre = (jugador and jugador.Name) or modelo.Name

	-- congelar y disolver antes de destruir, para que no sea un "pop" instantáneo
	for _, p in ipairs(modelo:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			TweenService:Create(p, TweenInfo.new(DURACION_DISOLVER), {
				Transparency = 1,
			}):Play()
		elseif p:IsA("Decal") or p:IsA("Texture") then
			TweenService:Create(p, TweenInfo.new(DURACION_DISOLVER), {Transparency = 1}):Play()
		end
	end

	task.delay(DURACION_DISOLVER, function()
		if modelo and modelo.Parent then
			modelo:Destroy()
		end
	end)

	return true, nombre
end

-- ===== FLING ESTILO INFINITE YIELD (con verificación de éxito) =====
-- devuelve true si el objetivo realmente se desplazó o quedó con velocidad alta
local function fling(modelo)
	local miChar = LP.Character
	local miHRP = miChar and miChar:FindFirstChild("HumanoidRootPart")
	local hrpObj = modelo:FindFirstChild("HumanoidRootPart")
	if not miHRP or not hrpObj then return false end

	local cfOriginal = miHRP.CFrame
	local posicionInicial = hrpObj.Position

	local att = Instance.new("Attachment")
	att.Parent = miHRP

	local av = Instance.new("AngularVelocity")
	av.Attachment0 = att
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.MaxTorque = math.huge
	av.AngularVelocity = Vector3.zero
	av.Parent = miHRP

	local fase = false
	local conexion = RunService.Heartbeat:Connect(function()
		if not (hrpObj.Parent and miHRP.Parent) then return end
		fase = not fase
		av.AngularVelocity = fase and Vector3.new(0, VEL_ANGULAR, 0) or Vector3.zero
		miHRP.CFrame = hrpObj.CFrame
		miHRP.AssemblyLinearVelocity = Vector3.new(VEL_LINEAL, VEL_LINEAL, VEL_LINEAL) * (fase and 1 or -1)
	end)

	task.wait(DURACION_FLING)

	conexion:Disconnect()
	if av.Parent then av:Destroy() end
	if att.Parent then att:Destroy() end

	if miHRP.Parent then
		miHRP.AssemblyLinearVelocity = Vector3.zero
		miHRP.AssemblyAngularVelocity = Vector3.zero
		miHRP.CFrame = cfOriginal
	end

	-- ===== COMPROBACIÓN REAL =====
	if not hrpObj.Parent then
		-- el objetivo ya no existe (murió, se fue, etc.): no se puede afirmar éxito
		return false
	end

	local desplazamiento = (hrpObj.Position - posicionInicial).Magnitude
	local velocidad = hrpObj.AssemblyLinearVelocity.Magnitude

	return (desplazamiento >= UMBRAL_DESPLAZ) or (velocidad >= UMBRAL_VELOCIDAD)
end

-- ===== TOOL =====
local function crearTool()
	local tool = obtenerPlantilla()
	local handle

	if tool then
		handle = tool:FindFirstChild("Handle")
		mira = nil
		tool.Grip = GRIP_AJUSTE
	else
		tool = Instance.new("Tool")
		tool.Name = "LaserGun"
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.GripPos = Vector3.new(0, -0.2, -0.4)

		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.4, 0.8, 1.4)
		handle.Color = Color3.fromRGB(40, 40, 40)
		handle.Material = Enum.Material.Metal
		handle.Parent = tool

		mira = Instance.new("Part")
		mira.Name = "Mira"
		mira.Size = Vector3.new(0.1, 0.1, 0.1)
		mira.Material = Enum.Material.Neon
		mira.CanCollide = false
		mira.CanQuery = false
		mira.CanTouch = false
		mira.Massless = true
		mira.Parent = handle

		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = mira
		weld.C0 = CFrame.new(0, 0.15, -0.7)
		weld.Parent = handle
	end

	actualizarMira()

	conectar(tool.Equipped, function() equipado = true end)
	conectar(tool.Unequipped, function() equipado = false end)

	local function disparar()
		if ocupado then return end
		ocupado = true

		local ok, err = pcall(function()
			local apuntado = rayoDeApuntado()
			local origen = apuntado.Origin
			local direccion = apuntado.Direction.Unit * DISTANCIA

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = LP.Character and {LP.Character} or {}

			local resultado = workspace:Raycast(origen, direccion, params)
			local puntoFinal = resultado and resultado.Position or (origen + direccion)

			local eliminando = modoEliminar
			disparoVisual(
				puntoDeBoca(tool, handle), puntoFinal, colorActual(),
				resultado ~= nil, eliminando and texturaEliminar or nil
			)
			sonar(handle, eliminando and sonidoEliminar or SONIDO_FLING_ID)

			if not resultado then
				aviso("Sin blanco", Color3.fromRGB(180, 180, 180))
				return
			end

			if eliminando then
				local exito, nombre = intentarEliminar(resultado.Instance)
				if exito then
					aviso("Eliminado: " .. nombre, Color3.fromRGB(255, 90, 90))
				else
					aviso("Eso no es un personaje", Color3.fromRGB(180, 180, 180))
				end
			else
				local modelo, jugador = personajeJugador(resultado.Instance)
				if jugador and jugador ~= LP then
					local funciono = fling(modelo)
					if funciono then
						aviso("Fling: SÍ", Color3.fromRGB(90, 255, 120))
					else
						aviso("Fling: NO (rechazado por el servidor)", Color3.fromRGB(255, 170, 60))
					end
				else
					aviso("No hay jugador ahí", Color3.fromRGB(180, 180, 180))
				end
			end
		end)
		if not ok then warn("[LaserGun] " .. tostring(err)) end

		task.wait(COOLDOWN)
		ocupado = false
	end

	conectar(tool.Activated, disparar)
	return tool
end

-- ===== ENTREGA (también tras respawn) =====
local function entregar()
	local backpack = LP:WaitForChild("Backpack")
	local viejo = backpack:FindFirstChild("LaserGun")
	if viejo then viejo:Destroy() end
	crearTool().Parent = backpack
end

entregar()
conectar(LP.CharacterAdded, function()
	equipado = false
	task.wait(1)
	entregar()
end)

-- ===== TOGGLE MODO ELIMINAR =====
local function alternarModo()
	modoEliminar = not modoEliminar
	actualizarMira()
	if refrescarPanel then refrescarPanel() end
end

conectar(UIS.InputBegan, function(input, gp)
	if gp or not equipado then return end
	if input.KeyCode == Enum.KeyCode.E then alternarModo() end
end)

-- ===== PANEL (modo eliminar + aviso) =====
local function crear(clase, props, padre)
	local o = Instance.new(clase)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = padre
	return o
end

local destino
do
	local ok, r = pcall(function() return gethui and gethui() end)
	destino = (ok and r) or LP:WaitForChild("PlayerGui")
end
local guiViejo = destino:FindFirstChild("LaserPanel")
if guiViejo then guiViejo:Destroy() end

local COL_FONDO = Color3.fromRGB(24, 24, 30)
local COL_FILA  = Color3.fromRGB(40, 40, 50)
local COL_TEXTO = Color3.fromRGB(235, 235, 240)

local gui = crear("ScreenGui", {
	Name = "LaserPanel", ResetOnSpawn = false, DisplayOrder = 999,
}, destino)

local panel = crear("Frame", {
	Size = UDim2.new(0, 230, 0, 112),
	Position = UDim2.new(0, 10, 0.18, 0),
	BackgroundColor3 = COL_FONDO, BorderSizePixel = 0, Active = true,
}, gui)
crear("UICorner", {CornerRadius = UDim.new(0, 8)}, panel)

local titulo = crear("TextLabel", {
	Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Active = true,
	Text = "  PISTOLA (arrastra aquí)", TextColor3 = COL_TEXTO, TextSize = 13,
	Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

local botonModo = crear("TextButton", {
	Position = UDim2.new(0, 8, 0, 32), Size = UDim2.new(1, -16, 0, 38),
	BackgroundColor3 = COL_FILA, TextColor3 = COL_TEXTO, TextSize = 14,
	Font = Enum.Font.GothamBold, BorderSizePixel = 0,
}, panel)
crear("UICorner", {CornerRadius = UDim.new(0, 6)}, botonModo)

labelAviso = crear("TextLabel", {
	Position = UDim2.new(0, 8, 0, 76), Size = UDim2.new(1, -16, 0, 28),
	BackgroundColor3 = COL_FILA, BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(180, 180, 180), TextTransparency = 1,
	Text = "", TextSize = 12, Font = Enum.Font.GothamMedium,
}, panel)
crear("UICorner", {CornerRadius = UDim.new(0, 6)}, labelAviso)

refrescarPanel = function()
	botonModo.Text = modoEliminar and "Modo: ELIMINAR" or "Modo: NORMAL (fling)"
	botonModo.BackgroundColor3 = modoEliminar and Color3.fromRGB(170, 30, 30) or COL_FILA
end
refrescarPanel()
conectar(botonModo.Activated, alternarModo)

-- v11: el panel se arrastra desde el titulo y respeta el candado global (antes tenia su propio arrastre y lo ignoraba)
Candado.hacerArrastrable(panel, { handle = titulo })
Candado.paneles.PistolaPanel = panel
end

if CFG.PistolaLaser then
	spawnSafe(iniciarPistolaLaser)
end

--------------------------------------------------------------------------------
-- EXTRA 2: PISTOLA DE PORTALES (incluida en este script)
--------------------------------------------------------------------------------
if CFG.PistolaPortales then
	spawnSafe(function()
		-- ===== PISTOLA DE PORTALES (v14, incluida en este mismo script) =====
		-- ============================================================
		-- PISTOLA DE PORTALES SOLITARIA (LocalScript / Delta) - solo tú lo ves
		-- Versión solitaria: este script ES SOLO la pistola de portales (todo lo demás se quitó).
		--
		--  * Pistola de portales con todas sus funciones: menú (botón MENU), modos
		--    Boton 1 / Boton 2, Jugadores (TP), Juegos, Agarre, Colocar y Config.
		--  * TELETRANSPORTE A JUGADORES: Menú > Jugadores > TP marca al objetivo y
		--    el siguiente portal que crees abre una SALIDA DETRÁS DE ÉL (lejos pero
		--    no tanto). Al cruzar apareces a su espalda mirándolo.
		--  * TAMAÑO: stepper "Tamaño del portal" en Boton 1, Boton 2 y Config
		--    (también cambia los portales que ya están abiertos).
		--  * TRASPASO: si metes la mano / la pistola en un portal, sale por el otro
		--    (a 2-3 studs del portal, apuntando el cursor hacia él).
		--  * MANO: el brazo derecho sigue el cursor en PC (en celular apunta al
		--    centro o al último toque).
		--  * ANIMACIONES propias (sin assets): apertura con rebote y chispas,
		--    cierre girando, pulso al cruzar, la mano se mueve como si disparara (R6 y R15).
		--  * Teclas: F cambia el modo de colocar | R cierra todos los portales.
		--  * v4: ANIMACIONES DEL PERSONAJE hechas a mano (R6 y R15): sacar la pistola de la cadera con
		--    rebote, apuntar con la cabeza y el torso siguiendo, y disparar con retroceso de hombro / codo /
		--    muñeca, torso echado atrás, cabeceo y brazo izquierdo de equilibrio.
		--  * v3: sin invisibilidad en 1ra persona, cierre por COLAPSO (selector V2 / NUEVO en Config),
		--    salidas animadas por orientacion (pared / suelo / cielo, R6 y R15), copias con ropa,
		--    portal en el aire sale hacia abajo y animaciones de equipar / disparar con el brazo.
		--  * v2: ANCHO y ALTO del portal (Config / Boton 1 / Boton 2), SALIDA ANIMADA
		--    (al salir asoma una pata, luego la otra y sales) y botones con los colores del menu.
		--
		--  * v5: se QUITARON las animaciones propias (brazo / cuerpo v4 y las del portal: apertura, cierre, pulso,
		--    salida pata por pata, mano por el otro portal) y se pusieron SOLO las del script original:
		--    equipar (la mano gira y el brazo sube y se asienta), disparar (el brazo baja con retroceso y vuelve) y efectos del disparo
		--    (chispas, pulso de luz, destello verde, temblor de camara). Brazo: solo R6.
		--
		--  * v13: SALIDA DE FRENTE. Si los 2 portales estan en la MISMA estructura (la misma pieza o el mismo Model),
		--    entras por uno y sales por el otro por el FRENTE, mirando hacia afuera (antes salias por detras del
		--    portal, dentro de la pared y mirando al portal). Los portales pasan SIEMPRE, esten donde esten: no hay
		--    ningun bloqueo ni aviso. Los portales PARADOS y los del aire (y cualquier otro caso) salen como en tu v12.
		--
		-- Si re-ejecutas, se limpia la versión anterior.
		-- ============================================================

		local Shared = {}

		--##########################################################################
		-- HELPERS COMPARTIDOS: candado/arrastre de menús + carga segura de animaciones
		--##########################################################################
		do
			local UIS = game:GetService("UserInputService")
			local KFS = game:GetService("KeyframeSequenceProvider")
			local env = (getgenv and getgenv()) or _G

			if env.HELPERS_LIMPIAR then
				pcall(env.HELPERS_LIMPIAR)
			end

			local conns = {}
			local function con(senal, fn)
				local c = senal:Connect(fn)
				table.insert(conns, c)
				return c
			end

			-- ===================== CANDADO + ARRASTRE =====================
			-- v14: el candado ya NO vive aqui: es el CANDADO GLOBAL de Rick Prime (env.RICKPRIME_CANDADO), el mismo para
			-- los botones de Rick, el panel de la pistola laser, el menu de portales y los botones flotantes.
			local UI = env.RICKPRIME_CANDADO
			Shared.UI = UI

			-- ===================== CARGA SEGURA DE ANIMACIONES =====================
			-- Acepta IDs de animación normales y también IDs de catálogo de emotes:
			-- 1) prueba el ID directo; 2) si no carga, lo abre con GetObjects (Animation o
			-- KeyframeSequence) y usa esa animación. Devuelve nil si no se pudo.
			local cache = {}

			local function funciona(animator, url)
				local a = Instance.new("Animation")
				a.AnimationId = url
				local ok, track = pcall(function()
					return animator:LoadAnimation(a)
				end)
				a:Destroy()
				if not ok or not track then
					return false
				end
				local t0 = os.clock()
				while track.Length <= 0 and os.clock() - t0 < 2 do
					task.wait(0.1)
				end
				local largo = track.Length
				pcall(function() track:Destroy() end)
				return largo > 0
			end

			local function viaObjetos(url)
				local resuelto
				local okO, objs = pcall(function()
					return game:GetObjects(url)
				end)
				if okO and type(objs) == "table" then
					for _, o in ipairs(objs) do
						local anim = o:IsA("Animation") and o or o:FindFirstChildWhichIsA("Animation", true)
						if anim and anim.AnimationId ~= "" then
							resuelto = anim.AnimationId
							break
						end
						local ks = o:IsA("KeyframeSequence") and o or o:FindFirstChildWhichIsA("KeyframeSequence", true)
						if ks then
							local okR, hash = pcall(function()
								return KFS:RegisterKeyframeSequence(ks)
							end)
							if okR and hash then
								resuelto = hash
								break
							end
						end
					end
					for _, o in ipairs(objs) do
						pcall(function() o:Destroy() end)
					end
				end
				return resuelto
			end

			-- Los IDs de catálogo (emotes / bundles) no siempre son el ID real de la animación:
			-- 1) se abre el asset con GetObjects y se usa la animación que trae dentro;
			-- 2) si no, se prueba el ID directo.
			local function resolver(animator, id)
				id = tostring(id)
				if id == "" then
					return nil
				end
				if cache[id] then
					return cache[id]
				end

				local url = "rbxassetid://" .. id

				local resuelto = viaObjetos(url)
				if resuelto and funciona(animator, resuelto) then
					cache[id] = resuelto
					return resuelto
				end

				if funciona(animator, url) then
					cache[id] = url
					return url
				end

				warn("[ANIM] No se pudo cargar el ID " .. id)
				return nil
			end

			Shared.ResolverAnim = resolver

			Shared.CargarPista = function(animator, id)
				local url = resolver(animator, id)
				if not url then
					return nil
				end
				local a = Instance.new("Animation")
				a.AnimationId = url
				local ok, track = pcall(function()
					return animator:LoadAnimation(a)
				end)
				a:Destroy()
				if ok then
					return track, url
				end
				return nil
			end

			env.HELPERS_LIMPIAR = function()
				for _, c in ipairs(conns) do
					pcall(function() c:Disconnect() end)
				end
				table.clear(conns)
			end
		end

		--##########################################################################
		-- MODULO: PORTAL GUN DE RICK PRIME + MENU (portales, modos, jugadores, juegos, agarre)
		--##########################################################################
		local function MODULO_PORTALES()
		print("=== RICK PRIME PORTAL GUN + MENU ===")

		-- Limpia la version anterior si se vuelve a ejecutar
		local env = (getgenv and getgenv()) or _G
		if env.PORTALES_LIMPIAR then
			pcall(env.PORTALES_LIMPIAR)
		end

		local Conns = {}
		local Alive = true

		local function Con(signal, fn)
			local c = signal:Connect(fn)
			table.insert(Conns, c)
			return c
		end

		-- PALETA: verde oscuro + azul oscuro
		local GREEN = Color3.fromRGB(44, 160, 102)
		local PANEL_BG = Color3.fromRGB(10, 24, 48)
		local BTN_BG = Color3.fromRGB(16, 70, 56)
		local ROW_BG = Color3.fromRGB(14, 36, 72)
		local RED = Color3.fromRGB(22, 58, 124)
		local DARK_RED = Color3.fromRGB(14, 34, 72)

		--------------------------------------------------
		-- SERVICIOS
		--------------------------------------------------

		local Players = game:GetService("Players")
		local RunService = game:GetService("RunService")
		local UserInputService = game:GetService("UserInputService")
		local Debris = game:GetService("Debris")
		local TweenService = game:GetService("TweenService")
		local GuiService = game:GetService("GuiService")
		local ContentProvider = game:GetService("ContentProvider")
		local InsertService = game:GetService("InsertService")
		local AssetService = game:GetService("AssetService")
		local TeleportService = game:GetService("TeleportService")

		local Player = Players.LocalPlayer
		local Character = Player.Character or Player.CharacterAdded:Wait()

		--------------------------------------------------
		-- CONFIGURACION
		--------------------------------------------------

		-- PISTOLA
		local GUN_ASSET = 102216258534195
		local GUN_PART_NAME = nil
		local GUN_SCALE = 1.5
		local GUN_ROTATION = Vector3.new(90, 180, 0)
		local GUN_GRIP_POINT = Vector3.new(0, -0.25, 0.3)
		local GUN_GRIP = CFrame.new(0, 0, 0)
		local PRINT_GUN_PARTS = false

		-- PORTALES
		local PORTAL_MESH = "rbxassetid://113206648303948"
		local PORTAL_TEXTURE = "rbxassetid://84300011755527"
		local BALL_COLOR = Color3.fromRGB(20, 150, 20)
		local PORTAL_COLOR = Color3.fromRGB(57, 255, 20)

		local AUTO_ALIGN = true
		local PLACE_EXACT = true

		-- Tecla para alternar portal parado / acostado en PC
		local STAND_KEY = Enum.KeyCode.F

		-- RECONOCIMIENTO DE TERRENO
		local TERRAIN_FIT = true
		local TERRAIN_GRID = 6
		local TERRAIN_MAX_RISE = 4

		local PORTAL_SIZE = 1.8
		local ROT_X = 0
		local ROT_Y = 40.3
		local ROT_Z = 90

		-- Estos 4 valores los controla el menu (Boton 1 / Boton 2)
		local SPIN_SPEED = 150
		local MAX_PORTALS = 2
		local BALL_SPEED = 450
		local FIRE_COOLDOWN = 0.08

		local MAX_DIST = 5000

		local ENTER_RADIUS = 4
		local ENTER_COOLDOWN = 1

		-- SALIDA
		local EXIT_SPEED = 55
		local EXIT_FORWARD_SPEED = 25
		local EXIT_UP_SPEED = 20

		-- SONIDOS
		local SOUND_OPEN = "rbxassetid://1013378689"
		local SOUND_ENTER = "rbxassetid://1013378689"
		local SOUND_CLOSE = "rbxassetid://1013378689"

		--------------------------------------------------
		-- ESTADO
		--------------------------------------------------

		local PortalGun = nil
		local GunTool = nil
		local ToolEquipped = false
		local CanShoot = true
		local LastEnter = 0
		local Inside = false

		local Portals = {}

		-- ===== NUEVO (v20): tabla con todo lo agregado (evita el limite de 200 locales) =====
		local NX = {
			nextShot = 0,             -- v14: reloj del siguiente disparo permitido (reemplaza al task.delay + CanShoot)
			shotQueued = false,       -- v14: un disparo en cola si llega justo antes de terminar el enfriamiento
			lastRootPos = nil,        -- v14: posicion anterior del personaje (barrido anti-tunel del Touch)
			reach = 0,                -- v14: alcance extra segun el tamano real del personaje
			templateDone = false,     -- v14: la carga de la malla del portal ya termino (bien o mal)
			Extras = {},              -- portales de salida (los que salen DETRAS del jugador objetivo)
			behindDist = 9,           -- distancia del portal de salida detras del jugador (studs)
			behindGap = 3,            -- studs delante del portal de salida donde apareces
			wallDepth = 1.4,          -- que tan adentro de un portal de pared debes estar para cruzar
			openTime = 0.18,          -- v10: el portal nace chiquito y llega a normal RAPIDO
			closeTime = 0.28,         -- duracion de la animacion de cierre
			recoilAngle = 0.42,       -- retroceso del brazo al disparar (radianes)
			muzzle = 1.5,             -- studs delante de la mano donde nace el rayo
			aimArm = true,            -- la mano/brazo sigue el cursor
			turnBody = false,         -- el cuerpo gira hacia donde apuntas
			anims = true,             -- animaciones del brazo y del disparo ON/OFF
			portalAnims = true,       -- v8: REACTIVADAS (apertura estilo Rick y Morty, cierre por colapso, pulso)
			seeThrough = false,       -- v5: copia de la mano por el otro portal ELIMINADA
			sizeMin = 0.4,
			sizeMax = 12,
			rot180 = CFrame.Angles(0, math.pi, 0),
			renderName = "RickPortalGunHand",
			pieces = {},              -- partes reales de la mano (brazo + pistola)
			ghosts = {},              -- copias que salen por el otro portal
			hiddenLTM = {},
			arm = nil,
			aimDir = nil,
			aimWeight = 0,
			shotT = nil,
			bodyTurned = false,
			lastArmSearch = 0,
			aimTouch = nil,
			aimTouchUntil = 0,
			widthMul = 1,             -- ANCHO del portal (multiplicador)
			heightMul = 1,            -- ALTO del portal (multiplicador)
			structExit = true,        -- v13: con los 2 portales en la misma estructura sales de FRENTE (false = salida de la v12)
			emerge = true,            -- v8: salida animada REACTIVADA (asoma una pata, luego la otra y sales)
			emergeTime = 0.3,         -- v10: salida mas rapida
			em = nil,                 -- estado de la animacion de salida en curso
			-- v3
			closeMode = "collapse",   -- "v2" = cierre original | "collapse" = cierre por colapso (nuevo)
			collapseTime = 0.2,       -- v9: cierre medido en los videos (~0.13-0.17 s)
			hideStore = {},           -- partes reales ocultas con Transparency (sin tocar LocalTransparencyModifier)
			ghostModel = nil,         -- copia visual del personaje (con ropa y accesorios)
			ghostMap = {},            -- pieza real -> pieza de la copia
			ghostOn = {},             -- piezas de la copia visibles ahora
			ghostKey = nil,
			equipT = nil,             -- animacion de equipar (s)
			-- v5: animaciones leidas del script original (equipar con giro de mano / disparo con el brazo arriba)
			vmEquipT = nil,           -- tiempo desde que equipaste (s)
			vmShotT = nil,            -- tiempo desde el ultimo disparo (s)
			vm = {
				-- v6: CORREGIDO (estaban cambiadas). EQUIPAR = pose "up"; DISPARAR = poses A -> B.
				up = { rot = Vector3.new(-70, 20, -30), off = Vector3.new(0, 0.25, 0.10), t = 0.22 },  -- EQUIPAR: pose final sostenida (Back Out)
				A = { rot = Vector3.new(40, -15, -20), off = Vector3.new(0, -0.15, -0.15), t = 0.12 }, -- DISPARAR: primer golpe
				B = { rot = Vector3.new(35, -10, -15), off = Vector3.new(0, -0.10, -0.10), t = 0.15 }, -- DISPARAR: segundo tramo
				kick = 40,            -- v12: cuanto SUBE la mano al disparar (grados)
				kickT = 0.1,          -- v12: tiempo de subida (s)
				twist = 110,          -- giro de la mano al equipar (grados)
				twistT = 0.14,        -- duracion del giro (s)
				backT = 0.15,         -- regreso del disparo a la pose de equipado (s)
			},
		}
		local StandMode = false
		local FlyMode = false
		local PlaceMode = 1 -- 1 = Acostado, 2 = Parado, 3 = Volando
		local SkyDistance = 80
		local PortalTemplate = nil
		local LastToolChange = 0
		local StandGui = nil
		local MenuGui = nil

		-- Destino de otro juego (pestana Juegos). nil = portales normales
		local DestPlaceId = nil

		-- Jugador marcado como OBJETIVO (pestana Jugadores > TP). Los portales que crees
		-- mientras haya objetivo te llevan a la posicion de ese jugador.
		local TargetPlayer = nil
		local TargetNotify = nil -- se asigna mas abajo (aviso en pantalla)
		local ClearTargetFn = nil -- se asigna mas abajo (quita el objetivo)

		-- El objetivo es de UN solo uso: se marca, el siguiente portal que crees te lleva al
		-- jugador, y despues los portales vuelven a funcionar normal. Tras teletransportarte
		-- a un jugador hay un cooldown antes de poder volver a hacerlo.
		local PLAYER_TP_COOLDOWN = 1.3
		local LastPlayerTP = 0

		-- Ajuste de agarre (pestana Agarre)
		local GripState = { px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0 }

		local function ApplyGrip()
			if GunTool and GunTool.Parent then
				GunTool.Grip = GUN_GRIP
					* CFrame.new(GripState.px, GripState.py, GripState.pz)
					* CFrame.Angles(
						math.rad(GripState.rx),
						math.rad(GripState.ry),
						math.rad(GripState.rz)
					)
			end
		end

		local PortalFolder = Instance.new("Folder")
		PortalFolder.Name = "RickPrimePortals"
		PortalFolder.Parent = workspace

		-- v14: si el juego borra la carpeta (limpieza del workspace, respawn) se vuelve a crear. Antes
		-- part.Parent = <carpeta destruida> fallaba y el portal simplemente NO aparecia.
		function NX.Folder()
			if not PortalFolder or PortalFolder.Parent == nil then
				PortalFolder = Instance.new("Folder")
				PortalFolder.Name = "RickPrimePortals"
				PortalFolder.Parent = workspace
			end

			return PortalFolder
		end


		--------------------------------------------------
		-- RAYCAST
		--------------------------------------------------

		local CastParams = RaycastParams.new()
		CastParams.FilterType = Enum.RaycastFilterType.Exclude

		local function IsValidHit(result)

			local inst = result.Instance

			if inst.Transparency >= 0.9 then
				return false
			end

			local model = inst:FindFirstAncestorOfClass("Model")

			if model and model:FindFirstChildOfClass("Humanoid") then
				return false
			end

			return true
		end

		local function CastValid(origin, direction)

			local ignore = { Character, PortalFolder }

			for _ = 1, 25 do

				CastParams.FilterDescendantsInstances = ignore

				local result = workspace:Raycast(origin, direction, CastParams)

				if not result then
					return nil
				end

				if IsValidHit(result) then
					return result
				end

				local inst = result.Instance
				local model = inst:FindFirstAncestorOfClass("Model")

				if model and model:FindFirstChildOfClass("Humanoid") then
					table.insert(ignore, model)
				else
					table.insert(ignore, inst)
				end
			end

			return nil
		end

		local function GetAimRay(touchPos)

			local camera = workspace.CurrentCamera

			if not camera then
				return nil
			end

			if touchPos then
				return camera:ScreenPointToRay(touchPos.X, touchPos.Y)
			end

			if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
				local size = camera.ViewportSize
				return camera:ViewportPointToRay(size.X / 2, size.Y / 2)
			end

			local pos = UserInputService:GetMouseLocation()

			return camera:ViewportPointToRay(pos.X, pos.Y)
		end

		--------------------------------------------------
		-- SONIDO
		--------------------------------------------------

		local function PlaySound(id, parent)
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = 1.5
			sound.RollOffMaxDistance = 150
			sound.Parent = parent
			sound:Play()

			Debris:AddItem(sound, 4)
		end

		--------------------------------------------------
		-- PORTAL (TUS MODELOS)
		--------------------------------------------------

		local function MeasurePortal(size)

			local s = { size.X, size.Y, size.Z }
			local order = { 1, 2, 3 }

			table.sort(order, function(a, b)
				return s[a] < s[b]
			end)

			return {
				thin = order[1],
				third = order[2],
				tall = order[3],
				thickness = s[order[1]],
				width = s[order[2]],
				height = s[order[3]]
			}
		end

		-- Medidas reales del portal: grosor, ANCHO (eje medio) y ALTO (eje largo)
		function NX.FillMeasure(m, unit, mul)
			local u = { unit.X, unit.Y, unit.Z }

			m.thickness = u[m.thin] * mul
			m.width = u[m.third] * mul * NX.widthMul
			m.height = u[m.tall] * mul * NX.heightMul
		end

		function NX.SizeVec(unit, m, mul, wr)
			local u = { unit.X, unit.Y, unit.Z }

			u[m.thin] *= mul
			u[m.third] *= mul * NX.widthMul * (wr or 1)
			u[m.tall] *= mul * NX.heightMul

			return Vector3.new(u[1], u[2], u[3])
		end

		local function CreatePortalPart()

			local part = nil
			local measure = nil
			local unit = nil
			local meshObj = nil

			local ok, result

			-- v14: si la plantilla aun se esta cargando se espera (max. 2 s, solo al principio). Antes CADA disparo
			-- pedia una malla nueva con CreateMeshPartAsync (yield lento que a veces fallaba): disparos lentos,
			-- portales que no salian y disparos rapidos que se pisaban entre si.
			if not PortalTemplate and not NX.templateDone then
				local t0 = os.clock()

				while not PortalTemplate and not NX.templateDone and os.clock() - t0 < 2 do
					task.wait(0.05)
				end
			end

			if PortalTemplate then
				ok, result = true, PortalTemplate:Clone()
			else
				-- sin plantilla: pieza de respaldo al instante (sin yield) y se reintenta la carga en segundo plano
				if NX.templateDone and not NX.retrying then
					NX.retrying = true

					task.spawn(function()
						local okR, res = pcall(function()
							return AssetService:CreateMeshPartAsync(PORTAL_MESH)
						end)

						if okR and res then
							res.TextureID = PORTAL_TEXTURE
							PortalTemplate = res
						end

						NX.retrying = false
					end)
				end

				ok, result = false, nil
			end

			if ok and result then

				part = result
				part.TextureID = PORTAL_TEXTURE

				-- tamano base (x1) y tamano actual (x PORTAL_SIZE, con ancho y alto)
				unit = part.Size
				measure = MeasurePortal(unit)
				NX.FillMeasure(measure, unit, PORTAL_SIZE)
				part.Size = NX.SizeVec(unit, measure, PORTAL_SIZE)

			else

				part = Instance.new("Part")
				part.Size = Vector3.new(1, 1, 1)

				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.FileMesh
				mesh.MeshId = PORTAL_MESH
				mesh.TextureId = PORTAL_TEXTURE
				mesh.Scale = Vector3.new(
					PORTAL_SIZE,
					PORTAL_SIZE,
					PORTAL_SIZE
				)
				mesh.Parent = part
				meshObj = mesh
			end

			part.Name = "RickPrimePortal"
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false

			local light = Instance.new("PointLight")
			light.Color = PORTAL_COLOR
			light.Brightness = 3
			light.Range = 16
			light.Parent = part

			return part, measure, unit, meshObj
		end

		local function PortalCFrame(position, normal, spin)
			return CFrame.lookAt(position, position + normal)
				* CFrame.Angles(0, 0, math.rad(spin))
				* CFrame.Angles(
					math.rad(ROT_X),
					math.rad(ROT_Y),
					math.rad(ROT_Z)
				)
		end

		local AxisVectors = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

		local function AlignedCFrame(position, face, tallDir, measure, spin)

			local side = face:Cross(tallDir)

			local v = {}
			v[measure.thin] = face
			v[measure.tall] = tallDir
			v[measure.third] = side

			if v[1]:Cross(v[2]):Dot(v[3]) < 0 then
				v[measure.third] = -side
			end

			return CFrame.fromMatrix(position, v[1], v[2], v[3])
				* CFrame.fromAxisAngle(
					AxisVectors[measure.thin],
					math.rad(spin)
				)
		end

		local function EntryCFrame(entry)

			if AUTO_ALIGN and entry.measure then
				return AlignedCFrame(
					entry.position,
					entry.face,
					entry.tallDir,
					entry.measure,
					entry.spin
				)
			end

			return PortalCFrame(
				entry.position,
				entry.normal,
				entry.spin
			)
		end

		--------------------------------------------------
		-- ANIMACIONES DE PORTAL (hechas a mano: apertura, cierre, pulso al cruzar)
		--------------------------------------------------

		-- v9: apertura medida en los videos: nace al ~22% de su tamano, crece hasta ~122% (rafaga) y se asienta en 100%
		function NX.OpenEase(a)

			-- v10: de chiquito (15%) a normal (100%), rapido y sin rebote
			return 0.15 + 0.85 * (1 - (1 - a) ^ 3)
		end

		function NX.EaseOutBack(a)
			local c1 = 1.70158
			local c3 = c1 + 1
			return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
		end

		-- Escala visual del portal (f = 1 es su tamano normal)
		function NX.SetScale(entry, f, wr)
			f = math.max(f, 0.02)

			local part = entry.part

			if not (part and part.Parent) then
				return
			end

			local mul = (entry.sizeMul or PORTAL_SIZE) * f

			if entry.unit then
				if entry.measure then
					part.Size = NX.SizeVec(entry.unit, entry.measure, mul, wr)
				else
					part.Size = entry.unit * mul
				end
			elseif entry.mesh then
				entry.mesh.Scale = Vector3.new(mul, mul, mul)
			end
		end

		-- Oculta / muestra una pieza REAL con Transparency (y sus Decal/Texture), guardando el valor
		-- original. NO toca LocalTransparencyModifier: ese valor lo controla la camara de Roblox
		-- (primera / tercera persona) y tocarlo dejaba al personaje invisible.
		function NX.Hide(store, p, on)

			local rec = store[p]

			if on then

				if not rec then
					rec = { t = p.Transparency, d = {} }

					for _, c in ipairs(p:GetChildren()) do
						if c:IsA("Decal") or c:IsA("Texture") then
							rec.d[c] = c.Transparency
						end
					end

					store[p] = rec
				end

				p.Transparency = 1

				for c in pairs(rec.d) do
					c.Transparency = 1
				end

			elseif rec then

				store[p] = nil

				pcall(function()
					p.Transparency = rec.t
				end)

				for c, v in pairs(rec.d) do
					pcall(function()
						c.Transparency = v
					end)
				end
			end
		end

		function NX.UnhideAll(store)

			local list = {}

			for p in pairs(store) do
				table.insert(list, p)
			end

			for _, p in ipairs(list) do
				NX.Hide(store, p, false)
			end
		end

		-- Giro "rot" de una articulacion Motor6D expresado en el marco de su Part0
		-- (sirve igual en R6 y R15 porque compensa la rotacion de C0)
		function NX.JointRot(motor, rot)
			local c0r = motor.C0.Rotation
			return c0r:Inverse() * rot * c0r
		end

		-- Cierre por COLAPSO: el portal conserva su forma (ovalada o no) y se encoge hacia su
		-- centro hasta ser un punto; entonces desaparece. No usa transparencia.
		function NX.Collapse(entry)

			local part = entry.part

			local light = part:FindFirstChildOfClass("PointLight")

			if light then
				TweenService:Create(light, TweenInfo.new(NX.collapseTime), { Brightness = 0 }):Play()
			end

			task.spawn(function()

				local t = 0
				local dur = math.max(NX.collapseTime, 0.15)

				while t < dur and part.Parent do

					local dt = RunService.Heartbeat:Wait()
					t += dt

					if entry.unit and math.abs(NX.widthMul - NX.heightMul) > 0.01 then
						local goal = 8 * math.sin(os.clock() * 3)
						local d = ((goal - entry.spin + 180) % 360) - 180
						entry.spin = (entry.spin + d * math.min(1, dt * 10)) % 360
					else
						entry.spin = (entry.spin + SPIN_SPEED * dt) % 360
					end

					local a = math.clamp(t / dur, 0, 1)

					-- escala uniforme en los 3 ejes: la forma no cambia, solo el tamano
					NX.SetScale(entry, (1 - a) ^ 1.5)

					if part.Parent then
						part.CFrame = EntryCFrame(entry)
					end
				end

				if part.Parent then
					part:Destroy()
				end
			end)
		end

		local function ClosePortal(entry)

			if entry.closed then
				return
			end

			entry.closed = true

			-- Si es un portal con salida detras del jugador, la salida tambien se cierra
			local ex = entry.partner

			if ex and ex.isExit and not ex.closed then
				ClosePortal(ex)
			end

			local part = entry.part

			if not (part and part.Parent) then
				return
			end

			PlaySound(SOUND_CLOSE, part)

			if not NX.portalAnims then

				-- v7: el portal de salida (detras del jugador) se desvanece suavemente
				if entry.isExit then

					local t = 0.5

					TweenService:Create(part, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Transparency = 1 }):Play()

					local light = part:FindFirstChildOfClass("PointLight")

					if light then
						TweenService:Create(light, TweenInfo.new(t), { Brightness = 0 }):Play()
					end

					Debris:AddItem(part, t + 0.05)
					return
				end

				task.delay(0.1, function()
					part:Destroy()
				end)
				return
			end

			-- v3: modo NUEVO = colapso (el modo V2 sigue abajo, intacto)
			if NX.closeMode == "collapse" then
				NX.Collapse(entry)
				return
			end

			-- Cierre: gira rapido y se encoge
			task.spawn(function()

				local t = 0
				local dur = NX.closeTime

				while t < dur and part.Parent do

					local dt = RunService.Heartbeat:Wait()
					t += dt

					entry.spin = (entry.spin + 720 * dt) % 360

					local a = math.clamp(t / dur, 0, 1)

					NX.SetScale(entry, (1 - a) * (1 - a))
					part.CFrame = EntryCFrame(entry)
				end

				part:Destroy()
			end)
		end

		local function CloseAllPortals()

			for _, entry in ipairs(Portals) do
				ClosePortal(entry)
			end

			table.clear(Portals)

			for _, entry in ipairs(NX.Extras) do
				ClosePortal(entry)
			end

			table.clear(NX.Extras)
		end

		-- v6: al COMPLETAR el teletransporte los portales NO se cierran al instante: permanecen
		-- NX.keepTime segundos (30) y despues se cierran (con colapso si el modo es "collapse").
		NX.keepTime = 30

		function NX.CollapsePair(a, b, instant)

			if NX.closeMode ~= "collapse" then
				return
			end

			-- instant = TP a jugador: el portal de salida detras de el desaparece como antes (sin esperar)
			if instant then

				for _, e in ipairs({ a, b }) do

					if e and not e.closed then

						local i = table.find(Portals, e)

						if i then
							table.remove(Portals, i)
						end

						ClosePortal(e)
					end
				end

				return
			end

			for _, e in ipairs({ a, b }) do

				if e and not e.closed and not e.keepScheduled then

					e.keepScheduled = true

					task.delay(NX.keepTime, function()

						if e.closed then
							return
						end

						local i = table.find(Portals, e)

						if i then
							table.remove(Portals, i)
						end

						ClosePortal(e)
					end)
				end
			end
		end

		-- Cada frame: giro, animacion de apertura y pulso
		function NX.TickEntry(entry, dt)

			local part = entry.part

			if entry.closed or not (part and part.Parent) then
				return
			end

			local boost = 1

			if NX.portalAnims then

				local f = 1
				local wr = 1
				local dirty = false

				if entry.openT then
					entry.openT += dt
					local a = math.clamp(entry.openT / NX.openTime, 0, 1)
					f = NX.OpenEase(a)   -- v9: el ancho y el alto crecen juntos (asi se ve en los videos)
					boost = 1 + (1 - a) * 6
					dirty = true

					if a >= 1 then
						entry.openT = nil
					end
				end

				if entry.pulseT then
					entry.pulseT += dt
					local a = math.clamp(entry.pulseT / 0.35, 0, 1)
					f *= 1 + 0.25 * math.sin(a * math.pi)
					boost += math.sin(a * math.pi) * 3
					dirty = true

					if a >= 1 then
						entry.pulseT = nil
					end
				end

				if dirty or entry.dirty then
					NX.SetScale(entry, f, wr)
					entry.dirty = dirty
				end

			elseif entry.openT or entry.pulseT or entry.dirty then

				entry.openT = nil
				entry.pulseT = nil
				entry.dirty = nil
				NX.SetScale(entry, 1)
			end

			if entry.unit and math.abs(NX.widthMul - NX.heightMul) > 0.01 then
				-- portal ovalado: no gira (el ovalo daria vueltas), solo se balancea
				local goal = 8 * math.sin(os.clock() * 3)
				local d = ((goal - entry.spin + 180) % 360) - 180

				entry.spin = (entry.spin + d * math.min(1, dt * 10)) % 360
			else
				entry.spin = (entry.spin + SPIN_SPEED * boost * dt) % 360
			end
			part.CFrame = EntryCFrame(entry)
		end

		-- Apertura: nace chiquito, gira muy rapido, crece con rebote y suelta chispas
		function NX.StartOpen(entry)

			if not NX.portalAnims then
				NX.SetScale(entry, 1)
				return
			end

			-- v8: primero el chispazo de la descarga (0.12 s) y luego el portal crece
			entry.openT = 0
			NX.SetScale(entry, 0.15)

			local part = entry.part

			pcall(function()
				local pe = Instance.new("ParticleEmitter")
				pe.Color = ColorSequence.new(PORTAL_COLOR)
				pe.LightEmission = 1
				pe.Size = NumberSequence.new(0.5, 0)
				pe.Lifetime = NumberRange.new(0.35, 0.7)
				pe.Speed = NumberRange.new(8, 20)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Rate = 0
				pe.Parent = part
				pe:Emit(35)
				Debris:AddItem(pe, 1.5)
			end)

			local light = part:FindFirstChildOfClass("PointLight")

			if light then
				light.Brightness = 14
				TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 3 }):Play()
			end
		end

		-- Recalcula las medidas de un portal ya abierto (tamano, ancho y alto) y mantiene
		-- los pies en el suelo si esta parado
		function NX.ResizeEntry(entry)

			entry.sizeMul = PORTAL_SIZE

			local m = entry.measure

			if m and entry.unit then

				local oldH = m.height
				local oldT = m.thickness

				NX.FillMeasure(m, entry.unit, PORTAL_SIZE)

				local delta

				if entry.standSign then
					delta = Vector3.new(0, entry.standSign * (m.height - oldH) / 2, 0)
				else
					delta = (entry.face or entry.normal) * ((m.thickness - oldT) / 2)
				end

				entry.position += delta

				if entry.exit then
					entry.exit += delta
				end

				entry.radius = math.max(ENTER_RADIUS, m.width * 0.5)
			end

			entry.dirty = true
		end

		function NX.RefreshDims()

			for _, e in ipairs(Portals) do
				NX.ResizeEntry(e)
			end

			for _, e in ipairs(NX.Extras) do
				NX.ResizeEntry(e)
			end
		end

		function NX.SetPortalSize(v)
			PORTAL_SIZE = v
			NX.RefreshDims()
		end

		function NX.SetPortalWidth(v)
			NX.widthMul = v
			NX.RefreshDims()
		end

		function NX.SetPortalHeight(v)
			NX.heightMul = v
			NX.RefreshDims()
		end

		--------------------------------------------------
		-- PORTAL DE SALIDA DETRAS DEL JUGADOR OBJETIVO
		--------------------------------------------------

		local function FlatLook(cf)
			local lv = cf.LookVector
			local f = Vector3.new(lv.X, 0, lv.Z)

			if f.Magnitude < 0.01 then
				return Vector3.new(0, 0, 1)
			end

			return f.Unit
		end

		-- Punto en el suelo DETRAS del jugador (lejos pero no tanto) y hacia donde mira el
		function NX.BehindSpot(tRoot)

			local look = FlatLook(tRoot.CFrame)
			local origin = tRoot.Position
			local dist = NX.behindDist

			-- Si hay una pared detras, acerca el portal para que no quede dentro
			local wall = CastValid(origin, -look * (dist + 3))

			if wall then
				dist = math.max(3.5, (wall.Position - origin).Magnitude - 3)
			end

			local pos = origin - look * dist

			local g = CastValid(pos + Vector3.new(0, 4, 0), Vector3.new(0, -26, 0))
			local groundY = g and g.Position.Y or (origin.Y - 3)

			return Vector3.new(pos.X, groundY, pos.Z), look
		end

		local function ApplyExitPose(e, ground, face)

			local height = e.measure and e.measure.height or 5

			e.normal = face
			e.face = face
			e.look = face
			e.tallDir = Vector3.new(0, 1, 0)
			e.position = ground + Vector3.new(0, height / 2, 0)

			-- Donde apareces: delante del portal, mirando hacia la espalda del jugador
			e.exit = Vector3.new(ground.X, ground.Y + 3.2, ground.Z) + face * NX.behindGap
		end

		function NX.MakeExit(ground, face)

			local ok, part, measure, unit, meshObj = pcall(CreatePortalPart)

			if not ok or not part then
				return nil
			end

			local e = {
				part = part,
				measure = measure,
				unit = unit,
				mesh = meshObj,
				sizeMul = PORTAL_SIZE,
				spin = 0,
				radius = measure and math.max(ENTER_RADIUS, measure.width * 0.5) or ENTER_RADIUS,
				enterDepth = NX.wallDepth,
				standSign = 1,
				isExit = true,
				expire = os.clock() + 2,   -- v7: visible 2 s y se desvanece
			}

			ApplyExitPose(e, ground, face)

			part.CFrame = EntryCFrame(e)
			part.Parent = NX.Folder()

			PlaySound(SOUND_OPEN, part)

			table.insert(NX.Extras, e)
			NX.StartOpen(e)

			return e
		end

		-- Crea (o recoloca si el jugador se movio) el portal de salida detras del objetivo
		function NX.PlaceBehind(entry, tRoot)

			local ground, face = NX.BehindSpot(tRoot)

			local ex = entry.partner
			local alive = ex and ex.part and ex.part.Parent and not ex.closed

			if alive then

				local moved = ex.refPos and (ex.refPos - tRoot.Position).Magnitude or math.huge
				local same = ex.refLook and ex.refLook:Dot(face) or -1

				if moved < 2.5 and same > 0.93 then
					return ex
				end

				ApplyExitPose(ex, ground, face)
				ex.part.CFrame = EntryCFrame(ex)
				ex.pulseT = 0

			else

				ex = NX.MakeExit(ground, face)

				if ex then
					entry.partner = ex
					ex.partner = entry
				end
			end

			if ex then
				ex.refPos = tRoot.Position
				ex.refLook = face
			end

			return ex, ground, face
		end

		-- Con quien esta conectado un portal (para ver la mano pasar al otro lado)
		function NX.PartnerOf(entry)

			local p = entry.partner

			if p and p.part and p.part.Parent and not p.closed then
				return p
			end

			if entry.isExit or entry.target or DestPlaceId then
				return nil
			end

			local count = #Portals

			if count >= 2 then

				local idx = table.find(Portals, entry)

				if idx then
					local other = Portals[idx % count + 1]

					if other and other ~= entry and other.part and other.part.Parent then
						return other
					end
				end
			end

			return nil
		end

		-- v13: estructura a la que pertenece una pieza.
		-- Si esta dentro de un Model, la estructura es ese Model; si no, es la pieza misma.
		function NX.StructureOf(inst)

			if typeof(inst) ~= "Instance" or not inst:IsDescendantOf(workspace) then
				return nil
			end

			local model = inst:FindFirstAncestorOfClass("Model")

			if model and model ~= workspace then
				return model
			end

			return inst
		end

		-- v13: true si los dos portales estan puestos en la misma estructura
		function NX.SameStructure(a, b)

			local sa = a and NX.StructureOf(a.hit)
			local sb = b and NX.StructureOf(b.hit)

			return sa ~= nil and sa == sb
		end

		local function GetTallDir(position, normal)

			local up = Vector3.new(0, 1, 0)
			local dir = up

			if math.abs(normal.Y) > 0.8 then

				dir = Vector3.new(0, 0, -1)

				local root = Character:FindFirstChild("HumanoidRootPart")

				if root then

					local d = position - root.Position
					d = Vector3.new(d.X, 0, d.Z)

					if d.Magnitude > 0.01 then
						dir = d.Unit
					end
				end
			end

			local tall = dir - normal * dir:Dot(normal)

			if tall.Magnitude < 0.01 then
				tall = Vector3.new(1, 0, 0) - normal * normal.X
			end

			return tall.Unit
		end

		local function FitPortal(center, face, tallDir, measure)

			local third = face:Cross(tallDir)
			local halfH = measure.height / 2
			local halfW = measure.width / 2

			local samples = {}

			for i = 0, 7 do

				local ang = i / 8 * math.pi * 2

				table.insert(
					samples,
					tallDir * math.cos(ang) * halfH
						+ third * math.sin(ang) * halfW
				)
			end

			local lift = 0.25
			local maxShift = math.min(halfH, halfW) * 0.8
			local moved = Vector3.new(0, 0, 0)

			for _ = 1, 6 do

				local push = Vector3.new(0, 0, 0)
				local origin = center + moved + face * lift

				for _, off in ipairs(samples) do

					local length = off.Magnitude
					local dir = off / length

					local hit = CastValid(origin, off)

					if hit then

						local missing = length - (hit.Position - origin).Magnitude
						push -= dir * (missing + 0.05)

					else

						local support = CastValid(
							origin + off,
							-face * (lift + measure.thickness + 1)
						)

						if not support then
							push -= dir * 0.4
						end
					end
				end

				if push.Magnitude < 0.05 then
					break
				end

				if push.Magnitude > 1.5 then
					push = push.Unit * 1.5
				end

				moved += push

				if moved.Magnitude > maxShift then
					moved = moved.Unit * maxShift
					break
				end
			end

			return center + moved
		end

		--------------------------------------------------
		-- RECONOCIMIENTO DE TERRENO
		--------------------------------------------------

		local function Det3(a, b, c, d, e, f, g, h, i)
			return a * (e * i - f * h)
				- b * (d * i - f * g)
				+ c * (d * h - e * g)
		end

		local function FitTerrain(base, normal, tallDir, measure)

			local third = normal:Cross(tallDir)
			local halfH = measure.height / 2 * 0.9
			local halfW = measure.width / 2 * 0.9

			local grid = math.max(TERRAIN_GRID, 3)

			local pts = {}

			for i = 0, grid - 1 do
				for j = 0, grid - 1 do

					local u = (i / (grid - 1) * 2 - 1) * halfH
					local v = (j / (grid - 1) * 2 - 1) * halfW

					if (u / halfH) ^ 2 + (v / halfW) ^ 2 <= 1.05 then

						local origin = base + tallDir * u + third * v + normal * 4
						local hit = CastValid(origin, -normal * 9)

						if hit then
							table.insert(pts, {
								u = u,
								v = v,
								h = (hit.Position - base):Dot(normal),
								pos = hit.Position
							})
						end
					end
				end
			end

			if #pts < 4 then
				return base + normal * (measure.thickness / 2 + 0.03), normal, tallDir
			end

			local n = #pts
			local Suu, Suv, Svv, Su, Sv, Suh, Svh, Sh = 0, 0, 0, 0, 0, 0, 0, 0

			for _, p in ipairs(pts) do
				Suu += p.u * p.u
				Suv += p.u * p.v
				Svv += p.v * p.v
				Su += p.u
				Sv += p.v
				Suh += p.u * p.h
				Svh += p.v * p.h
				Sh += p.h
			end

			local D = Det3(Suu, Suv, Su, Suv, Svv, Sv, Su, Sv, n)

			local a, b, c = 0, 0, Sh / n

			if math.abs(D) > 1e-4 then
				a = Det3(Suh, Suv, Su, Svh, Svv, Sv, Sh, Sv, n) / D
				b = Det3(Suu, Suh, Su, Suv, Svh, Sv, Su, Sh, n) / D
				c = Det3(Suu, Suv, Suh, Suv, Svv, Svh, Su, Sv, Sh) / D
			end

			local face = (normal - tallDir * a - third * b).Unit

			if face:Dot(normal) < 0.5 then
				face = (normal + face).Unit
			end

			local tall = tallDir - face * tallDir:Dot(face)

			if tall.Magnitude < 0.01 then
				tall = tallDir
			end

			tall = tall.Unit

			local planePoint = base + normal * c
			local maxD = 0

			for _, p in ipairs(pts) do
				local d = (p.pos - planePoint):Dot(face)

				if d > maxD then
					maxD = d
				end
			end

			maxD = math.min(maxD, TERRAIN_MAX_RISE)

			planePoint += face * maxD

			return planePoint + face * (measure.thickness / 2 + 0.03), face, tall
		end

		local function IsFiniteVec(v)
			return typeof(v) == "Vector3"
				and v.X == v.X and v.Y == v.Y and v.Z == v.Z
				and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
		end

		local function OpenPortal(position, normal, flying, hitInst)

			-- v3: un portal SUSPENDIDO EN EL AIRE tiene su salida orientada HACIA ABAJO (gravedad):
			-- se sale por debajo y se cae, nunca disparado hacia arriba
			if flying then
				normal = Vector3.new(0, -1, 0)
			end

			local part, measure, unit, meshObj = CreatePortalPart()

			-- Respeta el maximo de portales (cierra los mas viejos)
			while #Portals >= MAX_PORTALS and #Portals > 0 do
				ClosePortal(table.remove(Portals, 1))
			end

			local standing = false
			local standSign = nil

			if StandMode and not flying and math.abs(normal.Y) > 0.8 then

				standing = true

				local height = measure and measure.height or 5
				local sign = normal.Y > 0 and 1 or -1
				standSign = sign

				local dir = Vector3.new(0, 0, 1)
				local root = Character:FindFirstChild("HumanoidRootPart")

				if root then
					local d = root.Position - position
					d = Vector3.new(d.X, 0, d.Z)

					if d.Magnitude > 0.01 then
						dir = d.Unit
					end
				end

				normal = dir
				position = position + Vector3.new(0, sign * height / 2, 0)
			end

			local entry = {
				part = part,
				measure = measure,
				unit = unit,
				mesh = meshObj,
				sizeMul = PORTAL_SIZE,
				standSign = standSign,
				normal = normal,
				position = position + normal * 0.05,
				face = normal,
				tallDir = Vector3.new(0, 1, 0),
				look = normal,
				exit = position + normal * 3,
				radius = ENTER_RADIUS,
				enterDepth = 2.2,
				spin = 0,
				flying = flying and true or false,
				backDepth = flying and 4.5 or nil,
				hit = (not flying) and hitInst or nil,   -- v13: pieza donde se puso el portal (para "misma estructura")
			}

			local okAlign, errAlign = pcall(function()
			if AUTO_ALIGN and measure then

				local tallDir = GetTallDir(position, normal)

				local offset = measure.thickness / 2 + 0.03
				local center = position + normal * offset

				if not standing and not flying and not PLACE_EXACT then
					center = FitPortal(center, normal, tallDir, measure)
				end

				local face = normal

				if TERRAIN_FIT and not standing and not flying then
					local base = center - normal * offset
					local okFit, c2, f2, t2 = pcall(FitTerrain, base, normal, tallDir, measure)

					-- Si el ajuste al terreno falla o da valores invalidos, usa el portal plano
					if okFit and IsFiniteVec(c2) and IsFiniteVec(f2) and IsFiniteVec(t2) then
						center, face, tallDir = c2, f2, t2
					end
				end

				entry.position = center
				entry.face = face
				entry.tallDir = tallDir
				entry.radius = math.max(ENTER_RADIUS, measure.width * 0.5)

				if math.abs(normal.Y) > 0.8 then

					entry.enterDepth = 4.5

					local flat = Vector3.new(tallDir.X, 0, tallDir.Z)

					if flat.Magnitude > 0.01 then
						entry.look = flat.Unit
					else
						entry.look = Vector3.new(0, 0, -1)
					end

					entry.exit = center + face * 3

				else

					entry.enterDepth = NX.wallDepth

					local look = Vector3.new(normal.X, 0, normal.Z)

					if look.Magnitude > 0.01 then
						entry.look = look.Unit
					else
						entry.look = Vector3.new(0, 0, 1)
					end

					entry.exit = center + face * 3

					local down = CastValid(
						entry.exit,
						Vector3.new(0, -(measure.height + 6), 0)
					)

					if down and not flying then
						entry.exit = Vector3.new(
							entry.exit.X,
							down.Position.Y + 3,
							entry.exit.Z
						)
					end
				end
			end
			end)

			if not okAlign then
				-- v14: si el ajuste falla el portal se abre plano en el punto de impacto (antes el error cancelaba TODO el portal)
				warn("Ajuste de portal fallo (se abre plano): " .. tostring(errAlign))
				entry.measure = nil
			end

			part.CFrame = EntryCFrame(entry)
			part.Parent = NX.Folder()

			pcall(PlaySound, SOUND_OPEN, part)

			table.insert(Portals, entry)

			-- animacion de apertura (si falla, el portal queda abierto a tamano normal)
			local okOpen = pcall(NX.StartOpen, entry)

			if not okOpen then
				pcall(NX.SetScale, entry, 1)
			end

			-- Con un jugador marcado, este portal te lleva hasta el y el portal de
			-- salida se abre DETRAS de el
			if TargetPlayer then

				local plr = TargetPlayer

				entry.target = plr

				-- El objetivo se gasta con este portal: los siguientes son normales
				if ClearTargetFn then
					ClearTargetFn()
				end

				local tChar = plr.Character
				local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

				if tRoot then
					local okE, errE = pcall(NX.PlaceBehind, entry, tRoot)

					if not okE then
						warn("Error al crear portal de salida: " .. tostring(errE))
					end
				end
			end
		end

		--------------------------------------------------
		-- RAYO VISUAL
		--------------------------------------------------

		local function FireBeam(startPos, hitPos)

			local dist = (hitPos - startPos).Magnitude

			if dist < 0.1 then
				return
			end

			local beam = Instance.new("Part")
			beam.Name = "PortalBeam"
			beam.Anchored = true
			beam.CanCollide = false
			beam.CanTouch = false
			beam.CanQuery = false
			beam.CastShadow = false
			beam.Material = Enum.Material.Neon
			beam.Color = BALL_COLOR
			beam.Size = Vector3.new(0.15, 0.15, dist)
			beam.CFrame = CFrame.lookAt(startPos, hitPos) * CFrame.new(0, 0, -dist / 2)
			beam.Parent = NX.Folder()

			-- Velocidad bala: mas alta = el rayo desaparece mas rapido
			local fade = math.clamp(dist / math.max(BALL_SPEED, 1), 0.08, 1)

			TweenService:Create(
				beam,
				TweenInfo.new(fade),
				{ Transparency = 1 }
			):Play()

			Debris:AddItem(beam, fade + 0.05)
		end

		--------------------------------------------------
		-- MANO / BRAZO: animaciones hechas a mano (sin assets)
		--   * el brazo derecho apunta al cursor (PC) o al centro / ultimo toque (celular)
		--   * retroceso y destello al disparar
		--   * la mano y la pistola SALEN por el otro portal cuando las metes en uno
		--------------------------------------------------

		function NX.FindArm()

			local char = Character

			if not char then
				return nil
			end

			local m = char:FindFirstChild("RightShoulder", true) or char:FindFirstChild("Right Shoulder", true)

			if not (m and m:IsA("Motor6D") and m.Part0 and m.Part1) then
				return nil
			end

			local pieces = {}

			for _, n in ipairs({ "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" }) do
				local p = char:FindFirstChild(n)

				if p and p:IsA("BasePart") then
					table.insert(pieces, p)
				end
			end

			return {
				motor = m,
				pieces = pieces,
				elbow = char:FindFirstChild("RightElbow", true),   -- solo R15
				wrist = char:FindFirstChild("RightWrist", true),   -- solo R15
				waist = char:FindFirstChild("Waist", true),        -- solo R15
				neck = char:FindFirstChild("Neck", true),         -- R6 y R15 (cabeza)
				lshoulder = char:FindFirstChild("LeftShoulder", true) or char:FindFirstChild("Left Shoulder", true),
				lelbow = char:FindFirstChild("LeftElbow", true),   -- solo R15
				r6 = (char:FindFirstChild("Right Arm") ~= nil),
			}
		end

		function NX.RefreshPieces()

			table.clear(NX.pieces)

			if NX.arm then
				for _, p in ipairs(NX.arm.pieces) do
					table.insert(NX.pieces, p)
				end
			end

			if GunTool and GunTool.Parent == Character then
				for _, d in ipairs(GunTool:GetDescendants()) do
					if d:IsA("BasePart") and d.Transparency < 0.95 then
						table.insert(NX.pieces, d)
					end
				end
			end

			-- accesorios pegados al brazo (guantes, brazaletes...): tambien cruzan con su apariencia
			if NX.arm and Character then

				local set = {}

				for _, p in ipairs(NX.arm.pieces) do
					set[p] = true
				end

				for _, acc in ipairs(Character:GetChildren()) do

					if acc:IsA("Accessory") then

						local h = acc:FindFirstChild("Handle")
						local w = h and h:FindFirstChildWhichIsA("Weld")

						if h and h:IsA("BasePart") and w and (set[w.Part0] or set[w.Part1]) and h.Transparency < 0.95 then
							table.insert(NX.pieces, h)
						end
					end
				end
			end
		end

		-- Perfil del disparo: sube rapido y vuelve con un pequeno rebote (0 = reposo)
		function NX.ShotProfile(t)

			if t < 0.05 then
				local s = t / 0.05
				return s * s * (3 - 2 * s)
			end

			local tau = t - 0.05

			-- v3: vuelve SUAVEMENTE a la posicion de apuntado (sin rebote por debajo del reposo)
			return math.exp(-5.5 * tau)
		end

		-- Rotacion de camino mas corto que lleva el vector a hacia el vector b
		function NX.RotFromTo(a, b)

			local d = a:Dot(b)

			if d > 0.9999 then
				return CFrame.new()
			end

			if d < -0.9999 then
				local axis = a:Cross(Vector3.new(1, 0, 0))

				if axis.Magnitude < 0.01 then
					axis = a:Cross(Vector3.new(0, 0, 1))
				end

				return CFrame.fromAxisAngle(axis.Unit, math.pi)
			end

			return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(math.clamp(d, -1, 1)))
		end

		-- Marco del portal SIN el giro de la animacion: x = derecha, y = arriba, z = hacia afuera
		function NX.PortalFrame(e)

			local face = e.face.Unit
			local up = e.tallDir - face * e.tallDir:Dot(face)

			if up.Magnitude < 0.01 then
				up = Vector3.new(0, 1, 0) - face * face.Y

				if up.Magnitude < 0.01 then
					up = Vector3.new(1, 0, 0)
				end
			end

			up = up.Unit

			return CFrame.fromMatrix(e.position, up:Cross(face), up, face)
		end

		--------------------------------------------------
		-- COPIAS (la parte de la mano que cruza aparece en el otro portal)
		--------------------------------------------------

		-- Copia visual del personaje COMPLETO (ropa, colores, texturas y accesorios incluidos).
		-- Se clona el modelo entero (no pieza por pieza) para que la ropa se siga dibujando; todo
		-- queda anclado y sin colision / consulta / toque, y se oculta salvo las piezas que cruzan.
		function NX.BuildGhostModel()

			local char = Character

			NX.ClearGhosts()

			if not char then
				return false
			end

			local ok, model = pcall(function()
				return char:Clone()
			end)

			if not ok or not model then
				return false
			end

			local orig = char:GetDescendants()
			local copy = model:GetDescendants()

			if #orig ~= #copy then
				pcall(function() model:Destroy() end)
				return false
			end

			local map = {}

			for i, o in ipairs(orig) do

				local c = copy[i]

				if o:IsA("BasePart") and c and c.ClassName == o.ClassName then
					map[o] = c
				end
			end

			for _, d in ipairs(copy) do

				if d:IsA("BaseScript")
					or d:IsA("JointInstance")
					or d:IsA("WeldConstraint")
					or d:IsA("Constraint")
					or d:IsA("Sound")
					or d:IsA("ParticleEmitter")
					or d:IsA("Beam")
					or d:IsA("Trail")
					or d:IsA("ForceField") then

					pcall(function() d:Destroy() end)

				elseif d:IsA("BasePart") then

					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
					d.Massless = true
					d.CastShadow = false

				elseif d:IsA("Humanoid") then

					pcall(function()
						d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
						d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
						d.BreakJointsOnDeath = false
						d.RequiresNeck = false
					end)
				end
			end

			model.Name = "PortalGhostModel"

			NX.ghostHide = {}

			-- todo oculto al inicio; solo se muestran las piezas que cruzan el portal
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					NX.Hide(NX.ghostHide, d, true)
				end
			end

			model.Parent = NX.Folder()

			NX.ghostModel = model
			NX.ghostMap = map
			NX.ghostChar = char

			return true
		end

		function NX.GetGhost(p)

			local key = (GunTool and GunTool.Parent == Character) and GunTool or false

			if not NX.ghostModel
				or not NX.ghostModel.Parent
				or NX.ghostChar ~= Character
				or NX.ghostKey ~= key then

				-- las partes reales no pueden estar ocultas al clonar (si no, la copia nace invisible)
				NX.UnhideAll(NX.hideStore)

				if not NX.BuildGhostModel() then
					NX.ghostKey = key
					return nil
				end

				NX.ghostKey = key
			end

			return NX.ghostMap[p]
		end

		function NX.ShowGhost(g, on)

			if on then

				if not NX.ghostOn[g] then
					NX.ghostOn[g] = true
					NX.Hide(NX.ghostHide, g, false)
				end

			elseif NX.ghostOn[g] then
				NX.ghostOn[g] = nil
				NX.Hide(NX.ghostHide, g, true)
			end
		end

		function NX.ClearGhosts()

			if NX.ghostModel then
				pcall(function() NX.ghostModel:Destroy() end)
			end

			for _, g in pairs(NX.ghosts) do
				pcall(function() g:Destroy() end)
			end

			table.clear(NX.ghosts)

			NX.ghostModel = nil
			NX.ghostMap = {}
			NX.ghostOn = {}
			NX.ghostHide = {}
			NX.ghostKey = nil
			NX.ghostChar = nil

			-- devuelve la apariencia original de las partes reales
			NX.UnhideAll(NX.hideStore)
		end

		function NX.UpdateSeeThrough()

			local shown = {}
			local hidden = {}

			if NX.seeThrough and not NX.em and not DestPlaceId and #NX.pieces > 0 then

				local function consider(entry)

					if entry.closed or not (entry.part and entry.part.Parent) or not entry.measure then
						return
					end

					local partner = NX.PartnerOf(entry)

					if not partner then
						return
					end

					local A = NX.PortalFrame(entry)
					local zAxis = A.ZVector
					local hh = entry.measure.height * 0.5
					local hw = entry.measure.width * 0.5
					local B = nil

					for _, p in ipairs(NX.pieces) do

						if p.Parent and not shown[p] then

							local cf = p.CFrame
							local rel = A:PointToObjectSpace(cf.Position)
							local sz = p.Size

							-- cuanto sobresale la pieza hacia el plano del portal
							local ext = 0.5 * (
								math.abs(cf.RightVector:Dot(zAxis)) * sz.X
								+ math.abs(cf.UpVector:Dot(zAxis)) * sz.Y
								+ math.abs(cf.LookVector:Dot(zAxis)) * sz.Z
							)

							if rel.Z - ext < 0.05
								and rel.Z > -6
								and (rel.X / hw) ^ 2 + (rel.Y / hh) ^ 2 <= 1.1 then

								B = B or (NX.PortalFrame(partner) * NX.rot180)

								local g = NX.GetGhost(p)

								if g then
									g.CFrame = B * A:ToObjectSpace(cf)
									NX.ShowGhost(g, true)
									shown[p] = true

									-- la pieza ya paso del plano: se oculta la real
									if rel.Z < 0 then
										hidden[p] = true
									end
								end
							end
						end
					end
				end

				for _, e in ipairs(Portals) do
					consider(e)
				end

				for _, e in ipairs(NX.Extras) do
					consider(e)
				end
			end

			for p, g in pairs(NX.ghostMap) do
				if not shown[p] and NX.ghostOn[g] then
					NX.ShowGhost(g, false)
				end
			end

			-- la pieza real que ya paso del plano se oculta con Transparency (nunca con LTM)
			for _, p in ipairs(NX.pieces) do
				NX.Hide(NX.hideStore, p, hidden[p] == true)
			end

			-- piezas que ya no estan en la lista (soltaste la pistola, etc.) vuelven a la normalidad
			for p in pairs(NX.hideStore) do
				if not table.find(NX.pieces, p) then
					NX.Hide(NX.hideStore, p, false)
				end
			end
		end

		--------------------------------------------------
		-- APUNTAR: el brazo sigue el cursor
		--------------------------------------------------

		-- v4: ANIMACIONES DEL PERSONAJE hechas a mano (sin assets), R6 y R15:
		--   * SACAR la pistola: la mano sale de la cadera, sube con rebote; torso, cabeza y brazo izquierdo acompañan
		--   * APUNTAR: brazo derecho al cursor, cabeza mira al objetivo, respiración suave, brazo izquierdo de equilibrio
		--   * DISPARAR: retroceso del hombro, codo y muñeca (R15), el torso se echa atrás y la cabeza cabecea

		-- Apaga las animaciones de herramienta por defecto (levantan el brazo solas y pelean con las nuestras)
		function NX.StopToolTracks(hum)

			local animator = hum:FindFirstChildOfClass("Animator")

			if not animator then
				return
			end

			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do

				if string.find(string.lower(tr.Name), "tool", 1, true) then
					pcall(function()
						tr:Stop(0.1)
					end)
				end
			end
		end

		-- Pose del hombro derecho segun el script original (R6). Devuelve el Transform del Motor6D:
		-- el brazo termina en C0 * D, igual que al animar C0 en el original.
		function NX.vmRestore()

			local m = NX.vmMotor

			if m and m.Parent and NX.vmBase then
				m.C0 = NX.vmBase
			end

			NX.vmMotor = nil
			NX.vmBase = nil
		end

		function NX.VMCF(c)
			return CFrame.Angles(math.rad(c.rot.X), math.rad(c.rot.Y), math.rad(c.rot.Z)) * CFrame.new(c.off)
		end

		function NX.VMPose(dt)

			local V = NX.vm
			local A = NX.VMCF(V.A)
			local B = NX.VMCF(V.B)
			local U = NX.VMCF(V.up)
			local Utw = U * CFrame.Angles(0, math.rad(V.twist), 0)
			local I = CFrame.new() -- pose NORMAL (la animacion predeterminada de Roblox al equipar un tool)

			local D = I

			-- EQUIPAR: la mano gira mientras sube -> se asienta en la pose "up" con rebote (Back Out)
			-- -> vuelve a la pose normal de sostener el tool
			if NX.vmEquipT then

				NX.vmEquipT += dt
				local t = NX.vmEquipT
				local t1 = V.twistT
				local t2 = t1 + V.up.t
				local t3 = t2 + V.backT

				if t < t1 then
					local a = t / t1
					D = I:Lerp(Utw, 1 - (1 - a) * (1 - a))
				elseif t < t2 then
					D = Utw:Lerp(U, NX.EaseOutBack((t - t1) / V.up.t))
				elseif t < t3 then
					D = U:Lerp(I, math.sin((t - t2) / V.backT * math.pi / 2))
				else
					NX.vmEquipT = nil
				end
			end

			-- DISPARAR (v11): la mano SUBE con retroceso (Back Out) y vuelve a la pose normal (Sine Out)
			if NX.vmShotT then

				NX.vmShotT += dt
				local t = NX.vmShotT
				local tUp = V.kickT or 0.1
				-- v12: giro del brazo sobre el eje del hombro (cabeceo): + = el brazo SUBE
				local K = CFrame.Angles(0, 0, math.rad(V.kick or 40))

				if t < tUp then
					D = I:Lerp(K, NX.EaseOutBack(t / tUp))
				elseif t < tUp + V.backT then
					D = K:Lerp(I, math.sin((t - tUp) / V.backT * math.pi / 2))
				else
					NX.vmShotT = nil
				end
			end

			return D
		end

		function NX.UpdateArm(dt)

			-- durante la salida de un portal el brazo lo mueve la animacion de salida
			if NX.em then
				return
			end

			local char = Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")

			local want = (ToolEquipped and hum and hum.Health > 0) and 1 or 0

			if not NX.arm or not NX.arm.motor.Parent then

				if os.clock() - NX.lastArmSearch > 0.5 then
					NX.lastArmSearch = os.clock()
					NX.arm = NX.FindArm()
					NX.RefreshPieces()
				end

				if not NX.arm then
					return
				end
			end

			if not NX.anims then
				NX.vmEquipT = nil
				NX.vmShotT = nil
			end

			NX.aimWeight += (want - NX.aimWeight) * (1 - math.exp(-10 * dt))

			if want == 0 and NX.aimWeight < 0.01 then
				NX.aimWeight = 0
				NX.aimDir = nil
				NX.vmEquipT = nil
				NX.vmShotT = nil
				NX.vmRestore()
				return
			end

			local m = NX.arm.motor
			local p0 = m.Part0

			if not (p0 and m.Part1) then
				return
			end

			local S = p0.CFrame * m.C0

			-- Punto de mira: SOLO se usa para sacar el rayo y la punta de la pistola (no mueve el brazo)
			local dir

			if NX.aimArm then

				local cam = workspace.CurrentCamera
				local ray

				if NX.aimTouch and os.clock() < NX.aimTouchUntil and cam then
					ray = cam:ScreenPointToRay(NX.aimTouch.X, NX.aimTouch.Y)
				else
					ray = GetAimRay()
				end

				if not ray then
					return
				end

				local rdir = ray.Direction.Unit
				local hit = CastValid(ray.Origin, rdir * 600)
				local target = hit and hit.Position or (ray.Origin + rdir * 600)
				local v = target - S.Position

				dir = (v.Magnitude < 1.5) and rdir or v.Unit
			else
				local look = root and root.CFrame.LookVector or p0.CFrame.LookVector
				dir = Vector3.new(look.X, 0.1, look.Z).Unit
			end

			if NX.aimDir then

				local mixed = NX.aimDir:Lerp(dir, 1 - math.exp(-28 * dt))

				NX.aimDir = (mixed.Magnitude > 0.01) and mixed.Unit or dir
			else
				NX.aimDir = dir
			end

			-- v5: UNICA animacion del brazo = la del script original (equipar con giro de mano / disparo con brazo arriba).
			-- Solo R6. Todo lo demas (cabeza, cintura, codo, muneca, brazo izquierdo, retroceso) ya no se anima.
			-- Igual que el original: se mueve C0 y la animacion de herramienta de Roblox (la que levanta el brazo)
			-- sigue corriendo por debajo.
			-- v6: solo se toca el C0 MIENTRAS corre una animacion; al terminar se restaura y Roblox
			-- deja el brazo en su pose normal de tool.
			if NX.anims and NX.arm.r6 and want == 1 and (NX.vmEquipT or NX.vmShotT) then

				if NX.vmMotor ~= m or not NX.vmBase then
					NX.vmRestore()
					NX.vmMotor = m
					NX.vmBase = m.C0
				end

				m.C0 = NX.vmBase * NX.VMPose(dt)
			else
				NX.vmRestore()
			end
		end

		--------------------------------------------------
		-- SALIDA ANIMADA: sacas una pata del portal, luego la otra y sales
		--   * portal de pared: asoma la pierna derecha, luego la izquierda y al final sale el cuerpo
		--   * portal de suelo: asoma la mano derecha, luego la izquierda y subes
		--   * lo que todavia esta "dentro" del portal (detras de su plano) se oculta, asi que ves
		--     salir las piernas / manos una por una. Solo lo ves tu.
		--------------------------------------------------

		function NX.Smooth(a)
			a = math.clamp(a, 0, 1)
			return a * a * (3 - 2 * a)
		end

		function NX.Seg(u, a, b)
			return math.clamp((u - a) / (b - a), 0, 1)
		end

		-- Giro de una articulacion Motor6D alrededor del eje X del cuerpo.
		-- ang > 0 = el miembro (que cuelga) se mueve hacia ADELANTE
		function NX.LimbSwing(motor, ang)
			local c0r = motor.C0.Rotation
			return c0r:Inverse() * CFrame.Angles(ang, 0, 0) * c0r
		end

		-- Chispas y pulso del portal cada vez que asoma algo
		function NX.Spark(entry)

			entry.pulseT = 0

			local part = entry.part

			if not (part and part.Parent) then
				return
			end

			pcall(function()
				local pe = Instance.new("ParticleEmitter")
				pe.Color = ColorSequence.new(PORTAL_COLOR)
				pe.LightEmission = 1
				pe.Size = NumberSequence.new(0.35, 0)
				pe.Lifetime = NumberRange.new(0.25, 0.5)
				pe.Speed = NumberRange.new(6, 14)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Rate = 0
				pe.Parent = part
				pe:Emit(16)
				Debris:AddItem(pe, 1)
			end)
		end

		function NX.EndEmerge(abort)

			local em = NX.em

			if not em then
				return
			end

			NX.em = nil

			-- las partes ocultas vuelven a su Transparency original (la camara de Roblox no se toca)
			NX.UnhideAll(em.hid)

			for p, v in pairs(em.cc) do
				pcall(function() p.CanCollide = v end)
			end

			for _, m in pairs(em.motors) do
				pcall(function()
					if m.Parent then
						m.Transform = CFrame.new()
					end
				end)
			end

			local root, hum = em.root, em.hum

			if not abort and root and root.Parent then
				root.CFrame = CFrame.new(em.E) * em.rot
				root.AssemblyLinearVelocity = em.launch
				root.AssemblyAngularVelocity = Vector3.zero
			end

			-- el jugador recupera el control
			if hum and hum.Parent then

				hum.PlatformStand = em.ps

				if not abort then
					pcall(function()
						hum:ChangeState(Enum.HumanoidStateType.Freefall)
					end)
				end
			end

			-- cooldown para no volver a entrar al portal por el que acabas de salir
			LastEnter = os.clock()
			Inside = true

			-- v3: en modo colapso los portales se cierran DESPUES de completar el teletransporte
			if not abort then

				if em.b and em.b.isExit then
					-- v7: TP a jugador. El portal por el que entraste se cierra; el de SALIDA (detras del
					-- jugador) se queda visible 2 s y desaparece suave.
					local a = em.a

					if a then
						a.partner = nil

						local i = table.find(Portals, a)

						if i then
							table.remove(Portals, i)
						end

						ClosePortal(a)
					end

					em.b.expire = os.clock() + 2
				else
					pcall(NX.CollapsePair, em.a, em.b)
				end
			end
		end

		-- b = portal por el que sales | lookAt = punto al que miras (opcional) | launch = empujon final
		-- a = portal por el que entraste (se cierra por colapso al terminar, si ese modo esta activo)
		function NX.StartEmerge(b, root, lookAt, launch, a, flip)

			if NX.em or not (NX.emerge and NX.portalAnims) then
				return false
			end

			local char = Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")

			if not (hum and root and root.Parent and b and b.face and b.exit and b.position) then
				return false
			end

			local F = b.face.Unit
			local E = b.exit
			local look = b.look or Vector3.new(0, 0, 1)

			-- v12: flip = sales por el lado CONTRARIO de la cara del portal (para conservar tu direccion)
			if flip then
				E = E - 2 * (E - b.position):Dot(F) * F
				F = -F
				look = Vector3.new(F.X, 0, F.Z)
			end

			if lookAt then
				local d = Vector3.new(lookAt.X - E.X, 0, lookAt.Z - E.Z)

				if d.Magnitude > 0.01 then
					look = d.Unit
				end
			end

			-- wall = portal vertical (pared) | floor = horizontal mirando arriba | sky = horizontal mirando
			-- abajo (suspendido en el aire o en un techo)
			local mode = "wall"

			if F.Y >= 0.8 then
				mode = "floor"
			elseif F.Y <= -0.8 then
				mode = "sky"
			end

			local rootCF = root.CFrame
			local rot = CFrame.lookAt(E, E + look).Rotation

			-- en el cielo se asoma de cabeza (la cabeza va por delante) y luego se endereza
			local startRot = rot

			if mode == "sky" then
				startRot = rot * CFrame.Angles(math.pi, 0, 0)
			end

			local base = CFrame.new(E) * startRot

			-- cuanto sobresale el cuerpo (en la direccion de salida) para empezar totalmente dentro
			local parts = {}
			local maxExt = 0.5

			for _, d in ipairs(char:GetDescendants()) do

				if d:IsA("BasePart") and d ~= root then

					local cf = base * rootCF:ToObjectSpace(d.CFrame)
					local sz = d.Size

					local ext = (cf.Position - E):Dot(F)
						+ 0.5 * (
							math.abs(cf.RightVector:Dot(F)) * sz.X
							+ math.abs(cf.UpVector:Dot(F)) * sz.Y
							+ math.abs(cf.LookVector:Dot(F)) * sz.Z
						)

					if ext > maxExt then
						maxExt = ext
					end

					table.insert(parts, d)
				end
			end

			-- articulaciones (R6 y R15): se busca por nombre, lo que no exista se ignora
			local function mot(...)

				for _, n in ipairs({ ... }) do

					local m = char:FindFirstChild(n, true)

					if m and m:IsA("Motor6D") then
						return m
					end
				end

				return nil
			end

			local motors = {
				hipR = mot("RightHip", "Right Hip"),
				hipL = mot("LeftHip", "Left Hip"),
				kneeR = mot("RightKnee"),
				kneeL = mot("LeftKnee"),
				shR = mot("RightShoulder", "Right Shoulder"),
				shL = mot("LeftShoulder", "Left Shoulder"),
				elbR = mot("RightElbow"),
				elbL = mot("LeftElbow"),
				neck = mot("Neck"),
				lean = mot("Waist", "RootJoint"),   -- R15: cintura | R6: unico nexo torso-raiz
			}

			-- altura del hombro y largo del brazo (para apoyar las manos en portales de suelo)
			local shY, armL = 1.0, 2.0

			if motors.shR and motors.shR.Part0 then

				local okS, rel = pcall(function()
					return rootCF:ToObjectSpace(motors.shR.Part0.CFrame * motors.shR.C0).Position
				end)

				if okS and rel then
					shY = rel.Y
				end
			end

			local sumL = 0

			for _, n in ipairs({ "RightUpperArm", "RightLowerArm", "RightHand", "Right Arm" }) do

				local pp = char:FindFirstChild(n)

				if pp and pp:IsA("BasePart") then
					sumL += pp.Size.Y
				end
			end

			if sumL > 1 then
				armL = sumL
			end

			local cc = { [root] = root.CanCollide }

			for _, p in ipairs(parts) do
				cc[p] = p.CanCollide
			end

			NX.ClearGhosts()

			local dE = (E - b.position):Dot(F)
			local dS = -(math.min(maxExt, 9) + 0.15)

			-- puntos de paso de la trayectoria (distancia al plano del portal)
			local dA = math.max(-(0.5 * armL + shY), dS + 0.3)
			local dB = math.max(-(0.4 * armL + shY), dA + 0.2)
			local dU = math.min(math.max(0.85 * armL - shY, dB + 0.3), dE - 0.3)
			local dP = math.max(2.4 - math.min(maxExt, 9), dS + 0.8)

			local marks = { 0, 0.26, 0.52 }

			if mode == "floor" then
				marks = { 0, 0.28, 0.5, 0.78 }
			elseif mode == "sky" then
				marks = { 0, 0.3, 0.58 }
			end

			NX.em = {
				a = a,
				b = b,
				char = char,
				root = root,
				hum = hum,
				F = F,
				P = b.position,
				E = E,
				rot = rot,
				dE = dE,
				dS = dS,
				dA = dA,
				dB = dB,
				dU = dU,
				dP = dP,
				shY = shY,
				L = armL,
				t = 0,
				T = math.max(NX.emergeTime, 0.4),
				mode = mode,
				marks = marks,
				parts = parts,
				motors = motors,
				hid = {},
				cc = cc,
				ps = hum.PlatformStand,
				launch = launch or Vector3.zero,
				phase = 0,
				r6 = (motors.kneeR == nil),   -- R6: piernas rigidas y la inclinacion del torso arrastra las piernas
			}

			-- sin control del jugador mientras dura la animacion
			hum.PlatformStand = true

			NX.UpdateEmerge(0)

			return true
		end

		-- ===================== v8: ENTRADA CAMINANDO + SALIDA ESTILO RICK Y MORTY =====================
		-- Entras CAMINANDO al portal (las partes que pasan el plano se ocultan, piernas en movimiento) y,
		-- cuando todo el cuerpo esta dentro, sales por el otro con la salida animada: asoma una pata, luego la
		-- otra y sales. En portales de suelo te hundes mas despacio y emerges empujandote con las manos.
		-- No hay teletransporte instantaneo. Se puede repetir sin limite (Inside / LastEnter evitan bucles).
		NX.sink = true
		NX.sinkTimeIn = 0.2    -- minimo de la entrada (s)
		NX.walkSpeed = 12     -- velocidad de la entrada (studs/s)

		function NX.StartSink(a, b, root, lookAt, launch, outward)

			if NX.em or not NX.sink then
				return false
			end

			local char = Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")

			if not (hum and root and root.Parent and a and b and a.face and b.face and a.position and b.position and b.exit) then
				return false
			end

			local Fa, Fb = a.face.Unit, b.face.Unit

			-- portales de cielo / techo (cara hacia abajo): se usa la salida animada directa de siempre
			if Fa.Y <= -0.8 or Fb.Y <= -0.8 then
				return false
			end

			-- v12: en un portal de pared "entrar" es avanzar en el sentido en que ibas, venga del lado que venga
			if math.abs(Fa.Y) < 0.8 and (root.Position - a.position):Dot(Fa) < 0 then
				Fa = -Fa
			end

			local E = b.exit
			local rootCF = root.CFrame
			local look = b.look or Vector3.new(0, 0, 1)
			local flip = false

			-- v12: CONSERVAS TU DIRECCION. Entras avanzando hacia un lado y sales avanzando hacia ese mismo
			-- lado (como en el dibujo): si la cara del portal de salida mira en contra de tu avance, sales por
			-- su otro lado en vez de volver hacia donde entraste.
			if lookAt then

				local d = Vector3.new(lookAt.X - E.X, 0, lookAt.Z - E.Z)

				if d.Magnitude > 0.01 then
					look = d.Unit
				end
			else

				local head

				if math.abs(Fa.Y) < 0.8 then
					head = Vector3.new(-Fa.X, 0, -Fa.Z)
				else
					head = Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z)
				end

				local Fbe = Fb

				if math.abs(Fb.Y) < 0.8 then

					-- v13: con los 2 portales en la misma estructura NUNCA se sale por detras del portal (dentro / detras de la
					-- pared mirando al portal): siempre sales por el FRENTE del portal de salida, mirando hacia afuera
					if not outward and head.Magnitude > 0.01 and Fb:Dot(head.Unit) < 0 then
						flip = true
						Fbe = -Fb
						E = E - 2 * (E - b.position):Dot(Fb) * Fb
					end

					look = Vector3.new(Fbe.X, 0, Fbe.Z)

				elseif head.Magnitude > 0.01 then
					look = head
				end

				if look.Magnitude > 0.01 then
					look = look.Unit
				end

				-- punto al que mira al salir (StartEmerge lo usa para orientar el cuerpo)
				lookAt = E + look * 10

				-- empujon suave en la misma direccion en la que sales
				if math.abs(Fb.Y) > 0.8 then
					launch = Fb * 14 + look * 6
				else
					launch = Fbe * 14 + Vector3.new(0, 12, 0)
				end
			end

			local rot = CFrame.lookAt(E, E + look).Rotation

			local function ext(cf, sz, F)
				return 0.5 * (
					math.abs(cf.RightVector:Dot(F)) * sz.X
					+ math.abs(cf.UpVector:Dot(F)) * sz.Y
					+ math.abs(cf.LookVector:Dot(F)) * sz.Z
				)
			end

			local wallIn = math.abs(Fa.Y) < 0.8

			-- al entrar a un portal de pared el cuerpo se gira para entrar de frente
			local inRot = rootCF.Rotation

			if wallIn then

				local flat = Vector3.new(-Fa.X, 0, -Fa.Z)

				if flat.Magnitude > 0.01 then
					inRot = CFrame.lookAt(rootCF.Position, rootCF.Position + flat.Unit).Rotation
				end
			end

			local parts = {}
			local topIn = 0.5
			local cc = { [root] = root.CanCollide }
			local baseIn = CFrame.new(rootCF.Position) * inRot

			for _, d in ipairs(char:GetDescendants()) do

				if d:IsA("BasePart") and d ~= root then

					local cfA = baseIn * rootCF:ToObjectSpace(d.CFrame)

					topIn = math.max(topIn, (cfA.Position - rootCF.Position):Dot(Fa) + ext(cfA, d.Size, Fa))

					table.insert(parts, d)
					cc[d] = d.CanCollide
				end
			end

			local function mot(...)

				for _, n in ipairs({ ... }) do

					local m = char:FindFirstChild(n, true)

					if m and m:IsA("Motor6D") then
						return m
					end
				end

				return nil
			end

			NX.ClearGhosts()

			local dNow = (rootCF.Position - a.position):Dot(Fa)
			local dDeep = -(math.min(topIn, 9) + 0.2)
			local d0 = math.max(dNow, dDeep + 0.01)

			NX.em = {
				kind = "sink",
				a = a,
				b = b,
				char = char,
				root = root,
				hum = hum,
				Fa = Fa,
				Pa = a.position,
				E = E,
				flip = flip,
				rot = rot,
				lookAt = lookAt,
				wallIn = wallIn,
				rootRot = rootCF.Rotation,
				inRot = inRot,
				lat0 = rootCF.Position - Fa * dNow,
				d0 = d0,
				dDeep = dDeep,
				t = 0,
				TIn = math.clamp((d0 - dDeep) / NX.walkSpeed, NX.sinkTimeIn, 1.4),
				parts = parts,
				hips = { mot("RightHip", "Right Hip"), mot("LeftHip", "Left Hip") },
				motors = {},
				hid = {},
				cc = cc,
				ps = hum.PlatformStand,
				launch = launch or Vector3.zero,
			}

			-- sin control ni fisica del humanoide mientras dura la animacion (la posicion la manda el script)
			hum.PlatformStand = true

			NX.UpdateSink(NX.em, 0)

			return true
		end

		-- Cuando todo el cuerpo esta dentro del portal A, sale por el B con la salida animada
		function NX.SinkHandoff(em)

			NX.em = nil

			NX.UnhideAll(em.hid)

			for p, v in pairs(em.cc) do
				pcall(function() p.CanCollide = v end)
			end

			for _, m in ipairs(em.hips) do
				pcall(function() m.Transform = CFrame.new() end)
			end

			local hum = em.hum

			if hum and hum.Parent then
				hum.PlatformStand = em.ps
			end

			PlaySound(SOUND_ENTER, em.b.part)

			if NX.StartEmerge(em.b, em.root, em.lookAt, em.launch, em.a, em.flip) then
				return
			end

			-- plan B (no deberia pasar): sale directo
			local root = em.root

			if root and root.Parent then
				root.CFrame = CFrame.new(em.E) * em.rot
				root.AssemblyLinearVelocity = em.launch
			end

			LastEnter = os.clock()
			Inside = true

			pcall(NX.CollapsePair, em.a, em.b, em.b.isExit)
		end

		function NX.UpdateSink(em, dt)

			local root = em.root
			local S = NX.Smooth

			em.t += dt

			local u = math.clamp(em.t / em.TIn, 0, 1)
			local k = S(u)
			local d = em.d0 + (em.dDeep - em.d0) * k

			local target = em.Pa

			if em.wallIn then
				target = Vector3.new(em.Pa.X, em.lat0.Y, em.Pa.Z)
			end

			local lat = em.lat0:Lerp(target, 0.7 * k)
			local rotNow = em.rootRot

			if em.wallIn then
				rotNow = em.rootRot:Lerp(em.inRot, S(math.clamp(u / 0.35, 0, 1)))
			end

			root.CFrame = CFrame.new(lat + em.Fa * d) * rotNow
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero

			-- caminando: las piernas se mueven alternadas
			if em.wallIn then

				local sw = 0.7 * math.sin(em.t * 11) * (1 - u * 0.4)

				if em.hips[1] and em.hips[1].Parent then
					em.hips[1].Transform = NX.JointRot(em.hips[1], CFrame.Angles(sw, 0, 0))
				end

				if em.hips[2] and em.hips[2].Parent then
					em.hips[2].Transform = NX.JointRot(em.hips[2], CFrame.Angles(-sw, 0, 0))
				end
			end

			-- lo que queda detras del plano del portal no se ve (Transparency)
			for _, p in ipairs(em.parts) do

				if p.Parent then
					NX.Hide(em.hid, p, (p.Position - em.Pa):Dot(em.Fa) < 0)
				end
			end

			for p in pairs(em.cc) do

				if p.Parent and p.CanCollide then
					p.CanCollide = false
				end
			end

			if u >= 1 then
				NX.SinkHandoff(em)
			end
		end

		function NX.UpdateEmerge(dt)

			local em = NX.em

			if not em then
				return
			end

			local root, hum = em.root, em.hum

			if em.char ~= Character
				or not (root and root.Parent and hum and hum.Parent)
				or hum.Health <= 0 then

				NX.EndEmerge(true)
				return
			end

			if em.kind == "sink" then
				NX.UpdateSink(em, dt)
				return
			end

			em.t += dt

			local u = math.clamp(em.t / em.T, 0, 1)
			local S, Seg = NX.Smooth, NX.Seg
			local mo = em.motors
			local mode = em.mode

			-- pulso y chispas del portal cuando empieza cada fase
			if em.phase < #em.marks and u >= em.marks[em.phase + 1] then
				em.phase += 1
				NX.Spark(em.b)
			end

			-- giro de una articulacion (marco del Part0; funciona igual en R6 y R15)
			local function rotate(m, cf)
				if m and m.Parent then
					m.Transform = NX.JointRot(m, cf)
				end
			end

			local d = em.dE
			local roll = 0

			if mode == "wall" then

				-- PARED: pierna derecha -> pierna izquierda -> torso inclinado y brazos en equilibrio
				-- -> sale el cuerpo y termina con un pequeno salto
				local aR = S(Seg(u, 0.00, 0.22))
				local aL = S(Seg(u, 0.26, 0.48))
				local pull = S(Seg(u, 0.52, 1.00))
				local back = S(Seg(u, 0.60, 0.98))
				local jump = S(Seg(u, 0.86, 1.00))

				local s = 0.1 * S(Seg(u, 0, 0.5)) + 0.9 * pull
				d = em.dS + (em.dE - em.dS) * s

				local outR = aR * (1 - back)
				local outL = aL * (1 - back)

				-- el torso se inclina hacia delante
				local lean = -0.4 * S(Seg(u, 0.12, 0.55)) * (1 - S(Seg(u, 0.8, 1.0)))
				rotate(mo.lean, CFrame.Angles(lean, 0, 0))

				-- R6: al inclinar el torso las piernas se inclinan tambien; se compensa y se exagera
				-- el paso (no hay rodillas) con un pequeno vaiven de cadera
				local comp = em.r6 and -lean or 0
				local stride = em.r6 and 1.2 or 1

				rotate(mo.hipR, CFrame.Angles(1.25 * stride * outR + 0.55 * jump + comp, 0, 0))
				rotate(mo.kneeR, CFrame.Angles(-0.45 * outR - 0.6 * jump, 0, 0))
				rotate(mo.hipL, CFrame.Angles(1.25 * stride * outL + 0.55 * jump + comp, 0, 0))
				rotate(mo.kneeL, CFrame.Angles(-0.45 * outL - 0.6 * jump, 0, 0))

				-- los brazos se abren y se balancean para mantener el equilibrio
				local spread = 0.95 * S(Seg(u, 0.08, 0.34)) * (1 - S(Seg(u, 0.8, 1.0)))
				local sw = 0.5 * math.sin(math.pi * pull)

				rotate(mo.shR, CFrame.Angles(0, 0, spread) * CFrame.Angles(-sw, 0, 0))
				rotate(mo.shL, CFrame.Angles(0, 0, -spread) * CFrame.Angles(sw, 0, 0))
				rotate(mo.elbR, CFrame.Angles(0.4 * spread, 0, 0))
				rotate(mo.elbL, CFrame.Angles(0.4 * spread, 0, 0))

			elseif mode == "floor" then

				-- SUELO: asoman ambas manos -> se apoyan en la superficie -> los brazos empujan y sacan el
				-- cuerpo -> las piernas acompanan hasta salir
				if u < 0.28 then
					d = em.dS + (em.dA - em.dS) * S(Seg(u, 0, 0.28))
				elseif u < 0.5 then
					d = em.dA + (em.dB - em.dA) * S(Seg(u, 0.28, 0.5))
				elseif u < 0.78 then
					d = em.dB + (em.dU - em.dB) * S(Seg(u, 0.5, 0.78))
				else
					d = em.dU + (em.dE - em.dU) * S(Seg(u, 0.78, 1.0))
				end

				-- con las manos apoyadas en el plano, el angulo del brazo depende de la altura del hombro
				local shH = d + em.shY
				local ik = math.acos(math.clamp(shH / em.L, -1, 1))

				local th = 2.95
				th += (ik - th) * S(Seg(u, 0.20, 0.42))
				th += (0.2 - th) * S(Seg(u, 0.80, 0.95))

				rotate(mo.shR, CFrame.Angles(0, 0, th))
				rotate(mo.shL, CFrame.Angles(0, 0, -th))

				local elb = 0.35 * S(Seg(u, 0.40, 0.55)) * (1 - S(Seg(u, 0.78, 0.90)))
				rotate(mo.elbR, CFrame.Angles(elb, 0, 0))
				rotate(mo.elbL, CFrame.Angles(elb, 0, 0))

				local lean = -0.3 * S(Seg(u, 0.45, 0.78)) * (1 - S(Seg(u, 0.84, 1.0)))
				rotate(mo.lean, CFrame.Angles(lean, 0, 0))

				local comp = em.r6 and -lean or 0   -- R6: las piernas no siguen la inclinacion del torso

				-- las piernas suben y salen una tras otra
				local lr = S(Seg(u, 0.76, 0.90)) * (1 - S(Seg(u, 0.92, 1.0)))
				local ll = S(Seg(u, 0.82, 0.95)) * (1 - S(Seg(u, 0.96, 1.0)))

				rotate(mo.hipR, CFrame.Angles(0.9 * lr + comp, 0, 0))
				rotate(mo.kneeR, CFrame.Angles(-0.8 * lr, 0, 0))
				rotate(mo.hipL, CFrame.Angles(0.9 * ll + comp, 0, 0))
				rotate(mo.kneeL, CFrame.Angles(-0.8 * ll, 0, 0))

			else

				-- CIELO / TECHO: asoma cabeza y parte del torso, mira hacia abajo, termina de salir y cae
				-- (el cuerpo nace de cabeza y se endereza al salir; no recibe ningun impulso)
				if u < 0.30 then
					d = em.dS + (em.dP - em.dS) * S(Seg(u, 0, 0.30))
				elseif u < 0.58 then
					d = em.dP + 0.12 * math.sin(Seg(u, 0.30, 0.58) * math.pi * 2)
				else
					d = em.dP + (em.dE - em.dP) * S(Seg(u, 0.58, 1.0))
				end

				roll = math.pi * (1 - S(Seg(u, 0.58, 1.0)))

				local yaw = 0.85 * math.sin(Seg(u, 0.30, 0.58) * math.pi * 2)
				local pitch = 0.5 * S(Seg(u, 0.10, 0.30)) * (1 - S(Seg(u, 0.60, 0.80)))

				rotate(mo.neck, CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0))

				local spread = 0.5 * S(Seg(u, 0.20, 0.50)) * (1 - S(Seg(u, 0.70, 1.0)))
				rotate(mo.shR, CFrame.Angles(0, 0, spread))
				rotate(mo.shL, CFrame.Angles(0, 0, -spread))

				local kick = 0.35 * S(Seg(u, 0.62, 0.85)) * (1 - S(Seg(u, 0.88, 1.0)))
				rotate(mo.hipR, CFrame.Angles(kick, 0, 0))
				rotate(mo.hipL, CFrame.Angles(-kick, 0, 0))
			end

			root.CFrame = CFrame.new(em.E + em.F * (d - em.dE)) * em.rot * CFrame.Angles(roll, 0, 0)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero

			-- lo que sigue detras del plano del portal no se ve (Transparency, no LocalTransparencyModifier)
			local P, F = em.P, em.F

			for _, p in ipairs(em.parts) do

				if p.Parent then
					NX.Hide(em.hid, p, (p.Position - P):Dot(F) < 0)
				end
			end

			for p in pairs(em.cc) do
				if p.Parent and p.CanCollide then
					p.CanCollide = false
				end
			end

			if u >= 1 then
				NX.EndEmerge(false)
			end
		end

		-- sin colision durante la salida (si no, la pared te empuja)
		Con(RunService.Stepped, function()

			local em = NX.em

			if not em then
				return
			end

			for p in pairs(em.cc) do
				if p.Parent and p.CanCollide then
					p.CanCollide = false
				end
			end
		end)

		--------------------------------------------------
		-- DISPARO: punta de la pistola, destello y retroceso
		--------------------------------------------------

		function NX.GetMuzzle(handle)
			local dir = NX.aimDir or handle.CFrame.LookVector
			return handle.Position + dir * NX.muzzle
		end

		-- v5: efectos del disparo del script original: chispas en la boca, pulso de luz,
		-- destello verde de pantalla (Quart Out 0.45 s) y temblor de camara que decae
		function NX.ShotFX()

			local handle = GunTool and (GunTool:FindFirstChild("Handle") or GunTool:FindFirstChildWhichIsA("BasePart", true))

			if handle then

				local pe = Instance.new("ParticleEmitter")
				pe.Color = ColorSequence.new(Color3.fromRGB(140, 255, 140))
				pe.LightEmission = 1
				pe.LightInfluence = 0
				pe.Rate = 0
				pe.Lifetime = NumberRange.new(0.25, 0.5)
				pe.Speed = NumberRange.new(8, 16)
				pe.Drag = 5
				pe.Rotation = NumberRange.new(0, 360)
				pe.RotSpeed = NumberRange.new(-360, 360)
				pe.SpreadAngle = Vector2.new(180, 180)
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
				pe.Parent = handle
				pe:Emit(20)
				Debris:AddItem(pe, 1)

				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(80, 255, 120)
				light.Range = 12
				light.Shadows = false
				light.Brightness = 4
				light.Parent = handle
				TweenService:Create(light, TweenInfo.new(0.2), { Brightness = 0 }):Play()
				Debris:AddItem(light, 0.3)
			end

			-- destello verde de pantalla (v14: maximo uno cada 0.12 s para que el disparo rapido no sature la pantalla)
			if os.clock() - (NX.lastFlash or 0) >= 0.12 then
			NX.lastFlash = os.clock()
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Brightness = 0.55
			cc.Contrast = 0.2
			cc.Saturation = 0.25
			cc.TintColor = Color3.fromRGB(140, 255, 140)
			cc.Parent = game:GetService("Lighting")

			TweenService:Create(cc, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
				TintColor = Color3.fromRGB(255, 255, 255),
			}):Play()

			Debris:AddItem(cc, 0.55)
			end

			-- temblor de camara
			local hum = Character and Character:FindFirstChildOfClass("Humanoid")

			if hum and not NX.shaking then

				NX.shaking = true

				task.spawn(function()

					local t0 = os.clock()
					local dur = 0.18

					while os.clock() - t0 < dur and hum.Parent do
						local k = 0.35 * (1 - (os.clock() - t0) / dur)
						hum.CameraOffset = Vector3.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, 0)
						RunService.RenderStepped:Wait()
					end

					if hum.Parent then
						hum.CameraOffset = Vector3.zero
					end

					NX.shaking = false
				end)
			end
		end

		-- Animacion de disparar: el brazo sube (pose del original) + efectos del disparo
		function NX.ShootAnim()

			if NX.anims then
				NX.shotT = 0
				NX.vmShotT = 0
				pcall(NX.ShotFX)
			end
		end

		local ErrWarned = false

		pcall(function()
			RunService:UnbindFromRenderStep(NX.renderName)
		end)

		RunService:BindToRenderStep(NX.renderName, Enum.RenderPriority.Last.Value, function(dt)

			local ok, err = pcall(function()
				NX.UpdateArm(dt)
				NX.UpdateSeeThrough()
				NX.UpdateEmerge(dt)
			end)

			if not ok and not ErrWarned then
				ErrWarned = true
				warn("[PortalGun] mano: " .. tostring(err))
			end
		end)

		--------------------------------------------------
		-- DISPARAR
		--------------------------------------------------

		local function Shoot(touchPos)

			if not ToolEquipped
				or not PortalGun then
				return
			end

			-- v14: el enfriamiento se mide con el reloj (os.clock). Si el toque llega un instante antes de
			-- que termine, queda UN disparo en cola y sale justo al acabar (antes ese toque se perdia).
			local ahora = os.clock()

			if ahora < NX.nextShot then
				local resta = NX.nextShot - ahora

				if resta <= 0.15 and not NX.shotQueued then
					NX.shotQueued = true

					task.delay(resta, function()
						NX.shotQueued = false
						Shoot(touchPos)
					end)
				end

				return
			end

			local handle = PortalGun:FindFirstChild("Handle")

			if not handle then
				return
			end

			local ray = GetAimRay(touchPos)

			if touchPos then
				NX.aimTouch = touchPos
				NX.aimTouchUntil = os.clock() + 0.7
			end

			if not ray then
				return
			end

			local result = CastValid(ray.Origin, ray.Direction * MAX_DIST)

			local hitPos, hitNormal, flying = nil, nil, false

			if result then
				hitPos = result.Position
				hitNormal = result.Normal
			elseif FlyMode then
				-- VOLANDO: toco el cielo -> el portal aparece en ese punto del aire
				local dir = ray.Direction.Unit
				hitPos = ray.Origin + dir * SkyDistance

				-- Siempre acostado (horizontal, a 90°), nunca parado
				hitNormal = Vector3.new(0, 1, 0)

				flying = true
			else
				return
			end

			-- El cooldown se fija ANTES: si algo falla al abrir el portal,
			-- el disparo no se queda bloqueado para siempre.
			NX.nextShot = os.clock() + FIRE_COOLDOWN

			local muzzlePos = NX.GetMuzzle(handle)

			pcall(FireBeam, muzzlePos, hitPos)
			pcall(NX.ShootAnim, muzzlePos, hitPos - muzzlePos)

			local ok, err = pcall(OpenPortal, hitPos, hitNormal, flying, result and result.Instance)

			if not ok then
				warn("Error al abrir portal: " .. tostring(err))
			end
		end

		--------------------------------------------------
		-- CARGAR PISTOLA
		--------------------------------------------------

		local function LoadGunAsset()

			local ok, objects = pcall(function()
				local container =
					InsertService:LoadAsset(GUN_ASSET)

				return container:GetChildren()
			end)

			if ok and objects and objects[1] then
				return objects
			end

			ok, objects = pcall(function()
				return game:GetObjects(
					"rbxassetid://" .. GUN_ASSET
				)
			end)

			if ok and objects and objects[1] then
				return objects
			end

			return nil
		end

		--------------------------------------------------
		-- CREAR PISTOLA
		--------------------------------------------------

		local function GetExtents(root)

			local minV = Vector3.new(math.huge, math.huge, math.huge)
			local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

			local list = root:GetDescendants()
			table.insert(list, root)

			for _, d in ipairs(list) do

				if d:IsA("BasePart") then

					local half = d.Size / 2

					for x = -1, 1, 2 do
						for y = -1, 1, 2 do
							for z = -1, 1, 2 do

								local p = d.CFrame:PointToWorldSpace(
									Vector3.new(half.X * x, half.Y * y, half.Z * z)
								)

								minV = Vector3.new(
									math.min(minV.X, p.X),
									math.min(minV.Y, p.Y),
									math.min(minV.Z, p.Z)
								)

								maxV = Vector3.new(
									math.max(maxV.X, p.X),
									math.max(maxV.Y, p.Y),
									math.max(maxV.Z, p.Z)
								)
							end
						end
					end
				end
			end

			return (minV + maxV) / 2, maxV - minV
		end

		local function GripOffset(root)

			local center, size = GetExtents(root)

			return center + Vector3.new(
				GUN_GRIP_POINT.X * size.X,
				GUN_GRIP_POINT.Y * size.Y,
				GUN_GRIP_POINT.Z * size.Z
			)
		end

		local function CreatePortalGun()

			for _, item in ipairs(Player.Backpack:GetChildren()) do
				if item.Name == "Portal Gun" then
					item:Destroy()
				end
			end

			local oldGun = Character:FindFirstChild("Portal Gun")

			if oldGun then
				oldGun:Destroy()
			end

			local objects = LoadGunAsset()

			if not objects then
				warn("No se pudo cargar el asset de la pistola: " .. GUN_ASSET)
				return
			end

			if PRINT_GUN_PARTS then
				print("--- PARTES DEL MODELO " .. GUN_ASSET .. " ---")

				for _, obj in ipairs(objects) do
					print(obj.ClassName, obj.Name)

					for _, d in ipairs(obj:GetDescendants()) do
						if d:IsA("BasePart") then
							print("   ", d.ClassName, d.Name, d.Size)
						end
					end
				end

				print("--- FIN ---")
			end

			local source = nil

			if GUN_PART_NAME then

				for _, obj in ipairs(objects) do

					if obj.Name == GUN_PART_NAME then
						source = obj
						break
					end

					local found =
						obj:FindFirstChild(GUN_PART_NAME, true)

					if found then
						source = found
						break
					end
				end

				if not source then
					warn("No se encontro la parte: " .. GUN_PART_NAME)
					return
				end

				source = source:Clone()
			else
				source = objects[1]
			end

			for _, d in ipairs(source:GetDescendants()) do
				if d:IsA("Script")
					or d:IsA("LocalScript")
					or d:IsA("Humanoid") then
					d:Destroy()
				end
			end

			if source:IsA("Model") then
				source:ScaleTo(GUN_SCALE)
			elseif source:IsA("BasePart") then
				source.Size = source.Size * GUN_SCALE
			end

			local tool = Instance.new("Tool")
			tool.Name = "Portal Gun"
			tool.RequiresHandle = true
			tool.CanBeDropped = false
			tool.Grip = GUN_GRIP

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(0.2, 0.2, 0.2)
			handle.Transparency = 1
			handle.CanCollide = false
			handle.Massless = true
			handle.Parent = tool

			local rotation = CFrame.Angles(
				math.rad(GUN_ROTATION.X),
				math.rad(GUN_ROTATION.Y),
				math.rad(GUN_ROTATION.Z)
			)

			if source:IsA("Model") then

				local primary =
					source.PrimaryPart
					or source:FindFirstChildWhichIsA("BasePart", true)

				if primary then
					source.PrimaryPart = primary
					source:PivotTo(handle.CFrame * rotation)
					source:PivotTo(source:GetPivot() - GripOffset(source))
				end

				for _, part in ipairs(source:GetDescendants()) do

					if part:IsA("BasePart") then

						part.CanCollide = false
						part.Anchored = false
						part.Massless = true

						local weld = Instance.new("WeldConstraint")
						weld.Part0 = handle
						weld.Part1 = part
						weld.Parent = part
					end
				end

				source.Parent = tool

			elseif source:IsA("BasePart") then

				source.CanCollide = false
				source.Anchored = false
				source.Massless = true
				source.CFrame = handle.CFrame * rotation
				source.CFrame = source.CFrame - GripOffset(source)

				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = source
				weld.Parent = source

				source.Parent = tool
			end

			tool.Equipped:Connect(function()
				ToolEquipped = true
				NX.equipT = 0
				NX.vmEquipT = 0
				NX.vmShotT = nil
				PortalGun = tool
				NX.RefreshPieces()
				LastToolChange = os.clock()
				StandGui.Enabled = true
			end)

			tool.Unequipped:Connect(function()
				ToolEquipped = false
				NX.equipT = nil
				NX.vmEquipT = nil
				NX.vmShotT = nil
				PortalGun = nil
				NX.RefreshPieces()
				LastToolChange = os.clock()
				StandGui.Enabled = false
			end)

			tool.Activated:Connect(function()

				if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
					return
				end

				Shoot()
			end)

			GunTool = tool
			ApplyGrip()

			tool.Parent = Player.Backpack

			print("Portal Gun lista")
		end

		--------------------------------------------------
		-- DETECTAR ENTRADA AL PORTAL
		--------------------------------------------------

		local function IsInsidePortal(entry, root)

			local rel = root.Position - entry.position

			if not (AUTO_ALIGN and entry.measure) then
				return rel.Magnitude <= entry.radius
			end

			local side = entry.face:Cross(entry.tallDir)

			local depth = rel:Dot(entry.face)
			local alongTall = rel:Dot(entry.tallDir)
			local alongSide = rel:Dot(side)

			local hh = entry.measure.height * 0.45
			local hw = entry.measure.width * 0.45

			if depth < -(entry.backDepth or 2) or depth > math.max(entry.enterDepth, NX.reach or 0) then
				return false
			end

			return (alongTall / hh) ^ 2 + (alongSide / hw) ^ 2 <= 1
		end

		-- v14: contacto de CUERPO (centro, cabeza y pies), no solo del centro del HumanoidRootPart. Antes un portal
		-- bajo en una pared, o un personaje grande, nunca se detectaba aunque lo tocaras.
		function NX.HitEntry(e, pos, sy)
			if e.closed then
				return false
			end

			if IsInsidePortal(e, { Position = pos }) then
				return true
			end

			if IsInsidePortal(e, { Position = pos + Vector3.new(0, sy * 1.2, 0) }) then
				return true
			end

			if IsInsidePortal(e, { Position = pos - Vector3.new(0, sy * 1.4, 0) }) then
				return true
			end

			return false
		end

		--------------------------------------------------
		-- GIRO Y TELETRANSPORTE
		--------------------------------------------------

		Con(RunService.Heartbeat, function(dt)

			-- v14: TickEntry va protegido. Antes UN solo error aqui cortaba la funcion entera y la deteccion de Touch
			-- dejaba de correr. Ademas se purgan los portales cuya pieza desaparecio (no se quedan estorbando en la lista).
			for i = #Portals, 1, -1 do
				local entry = Portals[i]

				if not (entry.part and entry.part.Parent) then
					table.remove(Portals, i)
					entry.closed = true
				else
					local okT, errT = pcall(NX.TickEntry, entry, dt)

					if not okT and not NX.tickWarned then
						NX.tickWarned = true
						warn("[PortalGun] portal: " .. tostring(errT))
					end
				end
			end

			-- portales de salida (detras del jugador objetivo)
			for i = #NX.Extras, 1, -1 do

				local e = NX.Extras[i]

				if e.closed or not (e.part and e.part.Parent) then

					table.remove(NX.Extras, i)

				else

					NX.TickEntry(e, dt)

					if e.expire and os.clock() > e.expire then
						ClosePortal(e)
					end
				end
			end

			-- v14: siempre el personaje ACTUAL (por si la referencia quedo vieja tras un respawn)
			if Player.Character and Player.Character ~= Character and Player.Character.Parent then
				Character = Player.Character
			end

			local root = Character and Character:FindFirstChild("HumanoidRootPart")

			if not root then
				NX.lastRootPos = nil
				return
			end

			local prevPos = NX.lastRootPos
			NX.lastRootPos = root.Position
			NX.reach = math.max(root.Size.X, root.Size.Z) * 0.5 + 0.6
			local sy = root.Size.Y

			-- mientras sales del portal (animacion) no se detectan entradas
			if NX.em then
				return
			end

			local count = #Portals

			if count == 0 then
				Inside = false
				return
			end

			local near = nil

			for i = 1, count do

				if NX.HitEntry(Portals[i], root.Position, sy) then
					near = i
					break
				end
			end

			-- v14: barrido del tramo recorrido este frame. A mucha velocidad (caida, lag) el personaje "saltaba"
			-- por encima del portal entre dos frames y no se detectaba.
			if not near and prevPos and not Inside and os.clock() - LastEnter >= ENTER_COOLDOWN then
				local delta = root.Position - prevPos
				local dist = delta.Magnitude

				if dist > 1.5 and dist < 80 then
					local steps = math.ceil(dist / 1.5)

					for s = 1, steps - 1 do
						local p = prevPos + delta * (s / steps)

						for i = 1, count do
							if NX.HitEntry(Portals[i], p, sy) then
								near = i
								break
							end
						end

						if near then
							break
						end
					end
				end
			end

			if not near then
				Inside = false
				return
			end

			if Inside or os.clock() - LastEnter < ENTER_COOLDOWN then
				return
			end

			-- Portal con OBJETIVO: te lleva DETRAS del jugador marcado (basta con 1 portal).
			-- El portal de salida aparece a su espalda, lejos pero no tanto.
			if Portals[near].target then

				local entry = Portals[near]
				local plr = entry.target

				LastEnter = os.clock()
				Inside = true

				-- Cooldown: justo despues de un TP a jugador este portal no te lleva otra vez
				if os.clock() - LastPlayerTP < PLAYER_TP_COOLDOWN then
					return
				end

				local tChar = plr and plr.Parent and plr.Character
				local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")

				-- Un portal con objetivo se usa una sola vez: despues funciona normal
				entry.target = nil

				if not tRoot then

					if entry.partner then
						ClosePortal(entry.partner)
					end

					return
				end

				LastPlayerTP = os.clock()

				PlaySound(SOUND_ENTER, entry.part)
				entry.pulseT = 0

				-- Portal de salida detras del jugador (si ya existe, solo se recoloca si se movio)
				local okE, ex, ground, face = pcall(NX.PlaceBehind, entry, tRoot)

				if not okE then
					warn("Error al crear portal de salida: " .. tostring(ex))
					ex = nil
				end

				local dest

				if ex then
					dest = ex.exit
					ex.pulseT = 0
					ex.expire = os.clock() + 30   -- v8: se mantiene mientras sales; al terminar la salida queda 2 s y se cierra (EndEmerge)
				else
					local g2, f2 = NX.BehindSpot(tRoot)
					dest = Vector3.new(g2.X, g2.Y + 3.2, g2.Z) + f2 * NX.behindGap
				end

				-- Apareces detras de el, mirando hacia su espalda (saliendo del portal pata por pata)
				local started = ex and (NX.StartSink(entry, ex, root, tRoot.Position, Vector3.zero)
					or NX.StartEmerge(ex, root, tRoot.Position, Vector3.zero, entry))

				if not started then
					root.CFrame = CFrame.lookAt(dest, Vector3.new(tRoot.Position.X, dest.Y, tRoot.Position.Z))
					root.AssemblyLinearVelocity = Vector3.zero
					pcall(NX.CollapsePair, entry, ex, true)   -- TP a jugador: cierre inmediato como antes
				end

				PlaySound(SOUND_ENTER, tRoot)

				-- "Well, well, well" justo al salir del portal
				task.delay(0.15, function()

					local voz = Instance.new("Sound")
					voz.Name = "WellWellWell"
					voz.SoundId = "rbxassetid://104144683858662"
					voz.Volume = 1.5
					voz.RollOffMaxDistance = 250
					voz.Parent = root
					voz:Play()

					Debris:AddItem(voz, 12)
				end)

				return
			end

			-- Si hay un destino configurado (pestana Juegos), el portal te lleva a ese juego
			if DestPlaceId then

				LastEnter = os.clock()
				Inside = true

				PlaySound(SOUND_ENTER, Portals[near].part)

				NX.GoToGame(DestPlaceId)

				return
			end

			-- Portales normales: necesitas al menos 2.
			-- Con mas de 2 (Modo 2) cada portal te manda al siguiente en cadena.
			if count < 2 then
				return
			end

			local a = Portals[near]
			local b = Portals[near % count + 1]

			LastEnter = os.clock()
			Inside = true

			PlaySound(SOUND_ENTER, a.part)

			a.pulseT = 0
			b.pulseT = 0

			-- Salida animada: asoma una pata, luego la otra y sales del portal.
			-- Termina con un empujon suave hacia afuera (sin salir disparado).
			local gentle

			if b.flying then
				gentle = Vector3.zero                         -- portal en el aire: solo cae por gravedad
			elseif math.abs(b.normal.Y) > 0.8 then
				gentle = b.face * 14 + b.look * 6             -- suelo / techo: impulso segun su orientacion
			else
				gentle = b.face * 14 + Vector3.new(0, 12, 0)  -- pared: impulso + pequeno salto
			end

			-- v13: la salida de FRENTE solo es para portales de PARED en la misma estructura.
			-- Los portales PARADOS (de pie en el suelo) y los del aire siguen exactamente como en la v12.
			local outward = NX.structExit and not a.standSign and not b.standSign and NX.SameStructure(a, b)

			-- v7: te hundes en un portal y emerges por el otro (sin teletransporte instantaneo)
			if NX.StartSink(a, b, root, nil, gentle, outward) then
				return
			end

			if NX.StartEmerge(b, root, nil, gentle, a) then
				PlaySound(SOUND_ENTER, b.part)
				return
			end

			root.CFrame = CFrame.lookAt(
				b.exit,
				b.exit + b.look
			)

			local launch = b.face * EXIT_SPEED

			if math.abs(b.normal.Y) > 0.8 then
				launch += b.look * EXIT_FORWARD_SPEED
			else
				launch += Vector3.new(0, EXIT_UP_SPEED, 0)
			end

			if b.flying then
				launch = Vector3.zero
			end

			local humanoid = Character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end

			root.AssemblyLinearVelocity = launch

			task.spawn(function()
				RunService.Heartbeat:Wait()

				if root.Parent then
					root.AssemblyLinearVelocity = launch
				end
			end)

			PlaySound(SOUND_ENTER, b.part)

			-- teletransporte completado (sin animacion): en modo colapso se cierran ambos portales
			pcall(NX.CollapsePair, a, b)
		end)

		--------------------------------------------------
		-- CONTROLES
		--------------------------------------------------

		local PlayerGui = Player:WaitForChild("PlayerGui")
		local ActiveTouches = {}

		local TAP_MAX_TIME = 0.5
		local TAP_MAX_MOVE = 45

		local function TouchOnUIAt(pos)

			local camera = nil

			if pos.Y < 10 then
				return true
			end

			camera = workspace.CurrentCamera

			if camera then
				local vs = camera.ViewportSize

				-- Zona de la hotbar: solo lo que ocupan tus herramientas (antes era enorme
				-- y bloqueaba los toques al suelo cerca de tus pies)
				local count = 0

				for _, t in ipairs(Player.Backpack:GetChildren()) do
					if t:IsA("Tool") then
						count += 1
					end
				end

				for _, t in ipairs(Character:GetChildren()) do
					if t:IsA("Tool") then
						count += 1
					end
				end

				local half = (math.max(count, 1) * 0.0312 + 0.02) * vs.X

				if pos.Y > vs.Y * 0.84
					and math.abs(pos.X - vs.X / 2) < half then
					return true
				end
			end

			-- v14: paneles de otras interfaces (el panel de la pistola laser vive fuera de PlayerGui) tambien bloquean el disparo
			do
				local cand = env.RICKPRIME_CANDADO

				if cand and cand.paneles then
					for _, pnl in pairs(cand.paneles) do
						if pnl.Parent and pnl.Visible then
							local ap, asz = pnl.AbsolutePosition, pnl.AbsoluteSize

							if pos.X >= ap.X and pos.X <= ap.X + asz.X
								and pos.Y >= ap.Y and pos.Y <= ap.Y + asz.Y then
								return true
							end
						end
					end
				end
			end

			local ok, objs = pcall(function()
				return PlayerGui:GetGuiObjectsAtPosition(pos.X, pos.Y)
			end)

			if not ok then
				return false
			end

			local vs = camera and camera.ViewportSize or Vector2.new(1000, 500)

			for _, o in ipairs(objs) do

				-- Cualquier cosa del menu bloquea el disparo
				if MenuGui and o:IsDescendantOf(MenuGui) then
					return true
				end

				if o:IsA("GuiButton")
					and o.AbsoluteSize.X < vs.X * 0.4
					and o.AbsoluteSize.Y < vs.Y * 0.4 then
					return true
				end
			end

			return false
		end

		local function TouchOnUI(pos)

			local camera = workspace.CurrentCamera

			if camera then
				local vs = camera.ViewportSize

				if pos.X > vs.X * 0.82 and pos.Y > vs.Y * 0.7 then
					return true
				end
			end

			local inset = GuiService:GetGuiInset().Y

			for _, dy in ipairs({ 0, inset, -inset }) do

				if TouchOnUIAt(Vector2.new(pos.X, pos.Y + dy)) then
					return true
				end
			end

			return false
		end

		local SHOOT_ON_PRESS = true

		Con(UserInputService.TouchStarted, function(input)

			if TouchOnUI(input.Position) then
				ActiveTouches[input] = nil
				return
			end

			if SHOOT_ON_PRESS then
				Shoot(input.Position)
				return
			end

			ActiveTouches[input] = {
				pos = input.Position,
				time = os.clock()
			}
		end)

		Con(UserInputService.TouchEnded, function(input)

			local t = ActiveTouches[input]
			ActiveTouches[input] = nil

			if not t then
				return
			end

			if os.clock() - t.time > TAP_MAX_TIME then
				return
			end

			if os.clock() - LastToolChange < 0.5 then
				return
			end

			if (input.Position - t.pos).Magnitude > TAP_MAX_MOVE then
				return
			end

			Shoot(t.pos)
		end)

		Con(UserInputService.TouchTapInWorld, function(position)

			if SHOOT_ON_PRESS or TouchOnUI(position) then
				return
			end

			if os.clock() - LastToolChange < 0.5 then
				return
			end

			Shoot(position)
		end)

		-- BOTON PARADO / ACOSTADO
		StandGui = Instance.new("ScreenGui")
		StandGui.Name = "PortalStandGui"
		StandGui.ResetOnSpawn = false
		StandGui.Enabled = false
		StandGui.Parent = PlayerGui

		local StandButton = Instance.new("TextButton")
		StandButton.Size = UDim2.new(0, 150, 0, 50)
		StandButton.AnchorPoint = Vector2.new(0, 0.5)
		StandButton.Position = UDim2.new(0, 63, 0.5, 29)
		StandButton.BackgroundColor3 = BTN_BG
		StandButton.TextColor3 = Color3.new(1, 1, 1)
		StandButton.TextScaled = true
		StandButton.Font = Enum.Font.GothamBold
		StandButton.Parent = StandGui

		local ButtonCorner = Instance.new("UICorner")
		ButtonCorner.CornerRadius = UDim.new(0, 10)
		ButtonCorner.Parent = StandButton
		Shared.UI.hacerArrastrable(StandButton)

		do
			local sb = Instance.new("UIStroke")
			sb.Color = GREEN
			sb.Thickness = 2
			sb.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			sb.Parent = StandButton
		end

		local PLACE_NAMES = { "ACOSTADO", "PARADO", "VOLANDO" }
		local PLACE_COLORS = { BTN_BG, GREEN, RED }

		local function RefreshStandButton()
			StandButton.Text = "Portal: " .. PLACE_NAMES[PlaceMode]
			StandButton.BackgroundColor3 = PLACE_COLORS[PlaceMode]
			StandButton.TextColor3 = Color3.new(1, 1, 1)
		end

		local function SetPlaceMode(m)
			PlaceMode = m
			StandMode = (m == 2)
			FlyMode = (m == 3)
			RefreshStandButton()
		end

		local function ToggleStand()
			SetPlaceMode(PlaceMode % 3 + 1)
		end

		RefreshStandButton()
		StandButton.Activated:Connect(function()
			if Shared.UI.recienMovido(StandButton) then
				return
			end

			ToggleStand()
		end)

		Con(UserInputService.InputBegan,
			function(input, processed)

				if processed then
					return
				end

				if input.KeyCode == STAND_KEY then
					ToggleStand()
				end

				if input.KeyCode == Enum.KeyCode.R then
					CloseAllPortals()
				end
			end
		)

		--------------------------------------------------
		-- MENU (Portal - Menu)
		--------------------------------------------------


		-- Ajustes de cada modo
		local ModeSettings = {
			[1] = { max = 2, spin = 150, speed = 450, cooldown = 0.08 },
			[2] = { max = 6, spin = 150, speed = 450, cooldown = 0.08 },
		}

		local CurrentMode = 1
		local Refreshers = {}

		local function ApplyMode()

			local s = ModeSettings[CurrentMode]

			MAX_PORTALS = s.max
			SPIN_SPEED = s.spin
			BALL_SPEED = s.speed
			FIRE_COOLDOWN = s.cooldown

			while #Portals > MAX_PORTALS do
				ClosePortal(table.remove(Portals, 1))
			end
		end

		local function RefreshAll()
			for _, fn in ipairs(Refreshers) do
				fn()
			end
		end

		local function Round(corner, parent)
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, corner)
			c.Parent = parent
		end

		local function MakeLabel(parent, text, order, height, bold)

			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, 0, height or 30)
			l.LayoutOrder = order
			l.Text = text
			l.TextColor3 = Color3.new(1, 1, 1)
			l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.Parent = parent

			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = 18
			c.MinTextSize = 8
			c.Parent = l

			return l
		end

		local function MakeButton(parent, text, order, height, color, textColor)

			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, 0, 0, height or 40)
			b.LayoutOrder = order
			b.BackgroundColor3 = color or BTN_BG
			b.TextColor3 = textColor or Color3.new(1, 1, 1)
			b.Text = text
			b.Font = Enum.Font.GothamBold
			b.TextScaled = true
			b.AutoButtonColor = true
			b.Parent = parent

			local st = Instance.new("UIStroke")
			st.Color = GREEN
			st.Thickness = 1
			st.Transparency = 0.45
			st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			st.Parent = b

			Round(8, b)

			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = 20
			c.MinTextSize = 8
			c.Parent = b

			return b
		end

		-- Fila:  Texto   [-]  valor  [+]
		local function MakeStepper(parent, text, order, get, set, step, minV, maxV, fmt)

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 40)
			row.BackgroundTransparency = 1
			row.LayoutOrder = order
			row.Parent = parent

			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, -190, 1, 0)
			label.Text = text
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.Gotham
			label.TextScaled = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Parent = row

			local lc = Instance.new("UITextSizeConstraint")
			lc.MaxTextSize = 18
			lc.MinTextSize = 8
			lc.Parent = label

			local function sideButton(txt, offsetX)
				local b = Instance.new("TextButton")
				b.AnchorPoint = Vector2.new(1, 0)
				b.Position = UDim2.new(1, offsetX, 0, 0)
				b.Size = UDim2.new(0, 38, 1, 0)
				b.BackgroundColor3 = BTN_BG
				b.TextColor3 = Color3.new(1, 1, 1)
				b.Text = txt
				b.Font = Enum.Font.GothamBold
				b.TextScaled = true
				b.Parent = row
				Round(8, b)

				local st = Instance.new("UIStroke")
				st.Color = GREEN
				st.Thickness = 1
				st.Transparency = 0.45
				st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				st.Parent = b

				local c = Instance.new("UITextSizeConstraint")
				c.MaxTextSize = 22
				c.Parent = b

				return b
			end

			local plus = sideButton("+", 0)
			local minus = sideButton("-", -110)

			local value = Instance.new("TextLabel")
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, -38, 0, 0)
			value.Size = UDim2.new(0, 72, 1, 0)
			value.BackgroundTransparency = 1
			value.TextColor3 = GREEN
			value.Font = Enum.Font.GothamBold
			value.TextScaled = true
			value.Parent = row

			local vc = Instance.new("UITextSizeConstraint")
			vc.MaxTextSize = 20
			vc.MinTextSize = 8
			vc.Parent = value

			local function refresh()
				value.Text = string.format(fmt, get())
			end

			local function change(dir)
				local v = math.clamp(get() + dir * step, minV, maxV)
				v = math.floor(v * 1000 + 0.5) / 1000
				set(v)
				refresh()
			end

			minus.Activated:Connect(function()
				change(-1)
			end)

			plus.Activated:Connect(function()
				change(1)
			end)

			table.insert(Refreshers, refresh)
			refresh()
		end

		local function MakeSizeStepper(parent, order)
			MakeStepper(parent, "Tamaño del portal", order,
				function() return PORTAL_SIZE end,
				function(v) NX.SetPortalSize(v) end,
				0.2, NX.sizeMin, NX.sizeMax, "%.1f")
		end

		function NX.MakeWidthStepper(parent, order)
			MakeStepper(parent, "Ancho del portal", order,
				function() return NX.widthMul end,
				function(v) NX.SetPortalWidth(v) end,
				0.1, 0.3, 4, "%.1f")
		end

		function NX.MakeHeightStepper(parent, order)
			MakeStepper(parent, "Alto del portal", order,
				function() return NX.heightMul end,
				function(v) NX.SetPortalHeight(v) end,
				0.1, 0.3, 4, "%.1f")
		end

		-- ESTILO ------------------------------------------

		local function AddStroke(obj, color, thick)
			local s = Instance.new("UIStroke")
			s.Color = color or GREEN
			s.Thickness = thick or 2
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = obj
			return s
		end

		local function StylePanel(f)
			f.BackgroundColor3 = Color3.new(1, 1, 1)
			Round(12, f)

			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Color = ColorSequence.new(
				Color3.fromRGB(9, 22, 52),
				Color3.fromRGB(8, 52, 44)
			)
			g.Parent = f

			AddStroke(f, GREEN, 2)
		end

		-- VENTANA ----------------------------------------

		MenuGui = Instance.new("ScreenGui")
		MenuGui.Name = "PortalMenuGui"
		MenuGui.ResetOnSpawn = false
		MenuGui.DisplayOrder = 20
		MenuGui.Parent = PlayerGui

		local Panel = Instance.new("Frame")
		Panel.Name = "Panel"
		Panel.Position = UDim2.new(0.5625, 0, 0.105, 0)
		Panel.Size = UDim2.new(0.3125, 0, 0.88, 0)
		Panel.BackgroundColor3 = PANEL_BG
		Panel.BorderSizePixel = 0
		Panel.Active = true
		Panel.Visible = false
		Panel.Parent = MenuGui
		StylePanel(Panel)

		local Title = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.Position = UDim2.new(0, 14, 0, 6)
		Title.Size = UDim2.new(1, -120, 0, 36)
		Title.Text = "Portal  -  Menu"
		Title.TextColor3 = Color3.new(1, 1, 1)
		Title.Font = Enum.Font.GothamBold
		Title.TextScaled = true
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Panel

		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 22
		tc.MinTextSize = 10
		tc.Parent = Title

		local CloseButton = Instance.new("TextButton")
		CloseButton.AnchorPoint = Vector2.new(1, 0)
		CloseButton.Position = UDim2.new(1, -8, 0, 8)
		CloseButton.Size = UDim2.new(0, 44, 0, 32)
		CloseButton.BackgroundColor3 = RED
		CloseButton.Text = "X"
		CloseButton.TextColor3 = Color3.new(1, 1, 1)
		CloseButton.Font = Enum.Font.GothamBold
		CloseButton.TextScaled = true
		CloseButton.Parent = Panel
		Round(6, CloseButton)

		-- Candado + arrastre del menú (candado abierto = se mueve | cerrado = fijo)
		Shared.UI.agregar(Panel, "portales")

		local TabBar = Instance.new("Frame")
		TabBar.Position = UDim2.new(0, 8, 0, 50)
		TabBar.Size = UDim2.new(1, -16, 0, 38)
		TabBar.BackgroundTransparency = 1
		TabBar.Parent = Panel

		local TabLayout = Instance.new("UIListLayout")
		TabLayout.FillDirection = Enum.FillDirection.Horizontal
		TabLayout.Padding = UDim.new(0, 4)
		TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		TabLayout.Parent = TabBar

		local Content = Instance.new("Frame")
		Content.Position = UDim2.new(0, 8, 0, 96)
		Content.Size = UDim2.new(1, -16, 1, -104)
		Content.BackgroundTransparency = 1
		Content.ClipsDescendants = true
		Content.Parent = Panel

		local TabNames = { "Boton 1", "Boton 2", "Jugadores", "Juegos", "Agarre", "Colocar", "Config" }
		local TabButtons = {}
		local Pages = {}

		local function MakePage()

			local page = Instance.new("ScrollingFrame")
			page.Size = UDim2.new(1, 0, 1, 0)
			page.BackgroundTransparency = 1
			page.BorderSizePixel = 0
			page.ScrollBarThickness = 4
			page.CanvasSize = UDim2.new(0, 0, 0, 0)
			page.AutomaticCanvasSize = Enum.AutomaticSize.Y
			page.Visible = false
			page.Parent = Content

			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 6)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = page

			return page
		end

		local RefreshPlayers = nil

		local function ShowTab(index)

			for i, page in ipairs(Pages) do
				page.Visible = (i == index)

				TabButtons[i].BackgroundColor3 = (i == index) and GREEN or BTN_BG
				TabButtons[i].TextColor3 = (i == index) and Color3.new(1, 1, 1) or Color3.new(1, 1, 1)
			end

			if index == 3 and RefreshPlayers then
				RefreshPlayers()
			end
		end

		for i, name in ipairs(TabNames) do

			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.Size = UDim2.new(1 / 7, -4, 1, 0)
			b.BackgroundColor3 = BTN_BG
			b.Text = name
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Font = Enum.Font.GothamBold
			b.TextScaled = true
			b.Parent = TabBar
			Round(8, b)

			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = 15
			c.MinTextSize = 6
			c.Parent = b

			TabButtons[i] = b
			Pages[i] = MakePage()

			b.Activated:Connect(function()
				ShowTab(i)
			end)
		end

		-- PAGINAS BOTON 1 y BOTON 2 ----------------------

		local function SetMode(m)
			CurrentMode = m
			ApplyMode()
			RefreshAll()
		end

		local function BuildModePage(page, mode)

			local modeButton = MakeButton(page, "", 1, 44, BTN_BG)

			MakeStepper(page, "Portales max.", 2,
				function() return ModeSettings[mode].max end,
				function(v)
					ModeSettings[mode].max = v
					if CurrentMode == mode then ApplyMode() end
				end,
				1, 2, (mode == 1) and 2 or 20, "%.0f")

			MakeStepper(page, "Velocidad giro", 3,
				function() return ModeSettings[mode].spin end,
				function(v)
					ModeSettings[mode].spin = v
					if CurrentMode == mode then ApplyMode() end
				end,
				10, 0, 720, "%.0f")

			MakeStepper(page, "Velocidad bala", 4,
				function() return ModeSettings[mode].speed end,
				function(v)
					ModeSettings[mode].speed = v
					if CurrentMode == mode then ApplyMode() end
				end,
				50, 50, 2000, "%.0f")

			MakeStepper(page, "Enfriamiento (s)", 5,
				function() return ModeSettings[mode].cooldown end,
				function(v)
					ModeSettings[mode].cooldown = v
					if CurrentMode == mode then ApplyMode() end
				end,
				0.01, 0.02, 3, "%.2f")

			MakeSizeStepper(page, 6)
			NX.MakeWidthStepper(page, 7)
			NX.MakeHeightStepper(page, 8)

			local closeAll = MakeButton(page, "Cerrar todos los portales", 9, 44, RED)

			local status = MakeLabel(page, "", 10, 32, true)

			modeButton.Activated:Connect(function()
				SetMode(mode)
			end)

			closeAll.Activated:Connect(CloseAllPortals)

			table.insert(Refreshers, function()

				local active = (CurrentMode == mode)

				if active then
					modeButton.Text = "Modo " .. mode .. " ACTIVO"
					modeButton.BackgroundColor3 = GREEN
					modeButton.TextColor3 = Color3.new(1, 1, 1)
					closeAll.BackgroundColor3 = RED
					status.Text = "Portales activos: " .. #Portals .. " / " .. MAX_PORTALS
				else
					modeButton.Text = "Activar modo " .. mode
					modeButton.BackgroundColor3 = BTN_BG
					modeButton.TextColor3 = Color3.new(1, 1, 1)
					closeAll.BackgroundColor3 = DARK_RED
					status.Text = "Activa este modo para ver sus portales"
				end
			end)
		end

		BuildModePage(Pages[1], 1)
		BuildModePage(Pages[2], 2)

		-- PAGINA JUGADORES -------------------------------

		local PlayersPage = Pages[3]

		-- OBJETIVO DE PORTAL: marcar / quitar ------------

		local TargetHighlight = nil
		local TargetCharConn = nil

		-- (sin avisos en pantalla: el portal y el resalte del jugador son el feedback)
		TargetNotify = function() end

		local function SetTarget(plr)

			TargetPlayer = plr

			if TargetHighlight then
				TargetHighlight:Destroy()
				TargetHighlight = nil
			end

			if TargetCharConn then
				TargetCharConn:Disconnect()
				TargetCharConn = nil
			end

			if plr then

				local hl = Instance.new("Highlight")
				hl.Name = "PortalTargetHighlight"
				hl.FillColor = Color3.fromRGB(80, 220, 255)
				hl.FillTransparency = 0.75
				hl.OutlineColor = Color3.fromRGB(110, 225, 255)
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Adornee = plr.Character
				hl.Parent = NX.Folder()
				TargetHighlight = hl

				TargetCharConn = plr.CharacterAdded:Connect(function(char)
					if TargetHighlight then
						TargetHighlight.Adornee = char
					end
				end)
			end
		end

		ClearTargetFn = function()
			SetTarget(nil)

			if Pages[3].Visible and RefreshPlayers then
				task.defer(RefreshPlayers)
			end
		end

		RefreshPlayers = function()

			for _, child in ipairs(PlayersPage:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end

			local info = Instance.new("Frame")
			info.Size = UDim2.new(1, -6, 0, 44)
			info.BackgroundColor3 = BTN_BG
			info.LayoutOrder = 0
			info.Parent = PlayersPage
			Round(8, info)

			local infoText = Instance.new("TextLabel")
			infoText.BackgroundTransparency = 1
			infoText.Position = UDim2.new(0, 10, 0, 2)
			infoText.Size = UDim2.new(1, -20, 1, -4)
			infoText.Text = TargetPlayer
				and ("Objetivo: " .. TargetPlayer.DisplayName .. "  -  crea un portal con la pistola")
				or "Pulsa TP en un jugador y luego crea un portal: te llevara hasta el"
			infoText.TextColor3 = Color3.new(1, 1, 1)
			infoText.Font = Enum.Font.Gotham
			infoText.TextScaled = true
			infoText.TextXAlignment = Enum.TextXAlignment.Left
			infoText.Parent = info

			local infoC = Instance.new("UITextSizeConstraint")
			infoC.MaxTextSize = 15
			infoC.MinTextSize = 7
			infoC.Parent = infoText

			for i, plr in ipairs(Players:GetPlayers()) do

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -6, 0, 44)
				row.BackgroundColor3 = ROW_BG
				row.LayoutOrder = i
				row.Parent = PlayersPage
				Round(8, row)

				local name = Instance.new("TextLabel")
				name.BackgroundTransparency = 1
				name.Position = UDim2.new(0, 10, 0, 0)
				name.Size = UDim2.new(1, -90, 1, 0)
				name.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
				name.TextColor3 = Color3.new(1, 1, 1)
				name.Font = Enum.Font.Gotham
				name.TextScaled = true
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.Parent = row

				local nc = Instance.new("UITextSizeConstraint")
				nc.MaxTextSize = 16
				nc.MinTextSize = 7
				nc.Parent = name

				local tp = Instance.new("TextButton")
				tp.AnchorPoint = Vector2.new(1, 0.5)
				tp.Position = UDim2.new(1, -6, 0.5, 0)
				tp.Size = UDim2.new(0, 64, 0, 34)
				local isTarget = (TargetPlayer == plr)
				tp.BackgroundColor3 = isTarget and GREEN or BTN_BG
				tp.Text = isTarget and "✔ TP" or "TP"
				tp.TextColor3 = Color3.new(1, 1, 1)
				tp.Font = Enum.Font.GothamBold
				tp.TextScaled = true
				tp.Parent = row
				Round(6, tp)
				AddStroke(tp, GREEN, 1)

				-- Nueva mecanica: TP ya no te mueve. Marca (o quita) al jugador como objetivo;
				-- los portales que crees despues te llevan hasta el.
				tp.Activated:Connect(function()

					if plr == Player then
						TargetNotify("No puedes marcarte a ti mismo")
						return
					end

					if os.clock() - LastPlayerTP < PLAYER_TP_COOLDOWN then
						return
					end

					if TargetPlayer == plr then
						SetTarget(nil)
					else
						SetTarget(plr)
					end

					RefreshPlayers()
				end)
			end
		end

		Con(Players.PlayerAdded, function()
			if Pages[3].Visible then
				RefreshPlayers()
			end
		end)

		Con(Players.PlayerRemoving, function(leaving)

			if leaving == TargetPlayer then
				SetTarget(nil)
			end

			task.defer(function()
				if Pages[3].Visible then
					RefreshPlayers()
				end
			end)
		end)

		-- PAGINA JUEGOS (en un bloque aparte para no pasar el limite de locales)
		do

		local GamesPage = Pages[4]
		local MarketplaceService = game:GetService("MarketplaceService")
		local HttpService = game:GetService("HttpService")

		-- ID sin notacion cientifica (los PlaceId nuevos tienen 15 digitos)
		local function FmtId(n)
			return string.format("%.0f", n)
		end

		-- Juegos famosos: { nombre, PlaceId }
		local FamousGames = {
			{ "Murder Mystery 2 (MM2)", 142823291 },
			{ "Build A Boat For Treasure", 537413528 },
			{ "Natural Disaster Survival", 189707 },
			{ "Brookhaven RP", 4924922222 },
			{ "Adopt Me!", 920587237 },
			{ "Blox Fruits", 2753915549 },
			{ "Tower of Hell", 1962086868 },
			{ "Arsenal", 286090429 },
			{ "Jailbreak", 606849621 },
			{ "Doors", 6516141723 },
			{ "Pet Simulator 99", 8737899170 },
			{ "Grow a Garden", 126884695634066 },
			{ "Steal a Brainrot", 109983668079237 },
			{ "Raise A Catboy", 129852792970565 },
			{ "Catboy Obby", 76668617367998 },
		}

		MakeLabel(GamesPage, "ID del juego (PlaceId):", 1, 30, true)

		local IdBox = Instance.new("TextBox")
		IdBox.Size = UDim2.new(1, 0, 0, 44)
		IdBox.LayoutOrder = 2
		IdBox.BackgroundColor3 = ROW_BG
		IdBox.PlaceholderText = "Ej: 920587237"
		IdBox.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
		IdBox.Text = ""
		IdBox.TextColor3 = Color3.new(1, 1, 1)
		IdBox.Font = Enum.Font.Gotham
		IdBox.TextScaled = true
		IdBox.ClearTextOnFocus = false
		IdBox.Parent = GamesPage
		Round(8, IdBox)

		local ic = Instance.new("UITextSizeConstraint")
		ic.MaxTextSize = 20
		ic.MinTextSize = 8
		ic.Parent = IdBox

		local ConfigButton = MakeButton(GamesPage, "Configurar portal", 3, 44, GREEN, Color3.new(1, 1, 1))
		local GameStatus = MakeLabel(GamesPage, "Sin destino (portales normales)", 4, 36, false)
		local ClearDest = MakeButton(GamesPage, "Quitar destino (portales normales)", 5, 44, RED)

		local DestName = nil

		local function RefreshGames()
			if DestPlaceId then
				GameStatus.Text = "Destino: " .. (DestName or "juego") .. " (" .. FmtId(DestPlaceId) .. ")"
				GameStatus.TextColor3 = GREEN
			else
				GameStatus.Text = "Sin destino (portales normales)"
				GameStatus.TextColor3 = Color3.new(1, 1, 1)
			end
		end

		-- Devuelve (placeId, nombre). Si el numero NO es un PlaceId pero si un UniverseId,
		-- lo convierte al PlaceId real del juego. Si no puede comprobar nada, devuelve el mismo ID.
		local function ResolvePlace(id)

			local okI, info = pcall(function()
				return MarketplaceService:GetProductInfo(id)
			end)

			if okI and type(info) == "table" and info.AssetTypeId == 9 then
				return id, info.Name
			end

			-- Puede ser un UniverseId: se pregunta a la API de Roblox (si el ejecutor deja hacer peticiones)
			local req = (syn and syn.request) or request or http_request

			if req then
				local okR, place, nombre = pcall(function()
					local r = req({
						Url = "https://games.roblox.com/v1/games?universeIds=" .. FmtId(id),
						Method = "GET",
					})
					local body = r and (r.Body or r.body)
					local data = body and HttpService:JSONDecode(body)
					local g = data and data.data and data.data[1]
					if g and g.rootPlaceId then
						return g.rootPlaceId, g.name
					end
					return nil
				end)

				if okR and place then
					return place, nombre
				end
			end

			return id, nil
		end

		local Resolving = 0

		local function SetDest(id, knownName)

			Resolving += 1
			local mine = Resolving

			DestPlaceId = id
			DestName = knownName
			IdBox.Text = FmtId(id)

			GameStatus.Text = "Buscando juego..."
			GameStatus.TextColor3 = Color3.new(1, 1, 1)

			task.spawn(function()

				local place, nombre = ResolvePlace(id)

				-- si el usuario eligio otro mientras tanto, se ignora este resultado
				if mine ~= Resolving or DestPlaceId == nil then
					return
				end

				DestPlaceId = place
				DestName = nombre or knownName
				IdBox.Text = FmtId(place)
				RefreshGames()
			end)
		end

		ConfigButton.Activated:Connect(function()

			local id = tonumber((string.gsub(IdBox.Text or "", "%s", "")))

			if id and id > 0 then
				SetDest(math.floor(id), nil)
			else
				GameStatus.Text = "ID invalido"
				GameStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
			end
		end)

		ClearDest.Activated:Connect(function()
			Resolving += 1
			DestPlaceId = nil
			DestName = nil
			RefreshGames()
		end)

		-- Viaje al juego (lo llama el portal al cruzarlo). Prueba Teleport y, si falla, TeleportAsync.
		local TriedAsync = false
		local PendingDest = nil

		function NX.GoToGame(id)

			TriedAsync = false
			PendingDest = id
			GameStatus.Text = "Viajando a " .. (DestName or FmtId(id)) .. "..."
			GameStatus.TextColor3 = GREEN

			-- el destino se gasta: los siguientes portales vuelven a ser normales
			DestPlaceId = nil
			DestName = nil
			Resolving += 1

			local ok, err = pcall(function()
				TeleportService:Teleport(id, Player)
			end)

			if not ok then

				TriedAsync = true

				local ok2, err2 = pcall(function()
					TeleportService:TeleportAsync(id, { Player })
				end)

				if not ok2 then
					GameStatus.Text = "No se pudo viajar: " .. tostring(err2 or err)
					GameStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
				end
			end
		end

		Con(TeleportService.TeleportInitFailed, function(plr, result, msg)

			if plr ~= Player or not PendingDest then
				return
			end

			if not TriedAsync then
				TriedAsync = true
				local ok = pcall(function()
					TeleportService:TeleportAsync(PendingDest, { Player })
				end)
				if ok then
					return
				end
			end

			GameStatus.Text = "No te dejo entrar: " .. tostring(msg or result)
			GameStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
		end)

		-- Lista de juegos famosos, cada uno con su ID y boton verde "Configurar"
		MakeLabel(GamesPage, "Juegos famosos (toca Configurar, dispara y cruza el portal):", 6, 34, true)

		for i, g in ipairs(FamousGames) do

			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 56)
			row.LayoutOrder = 6 + i
			row.BackgroundColor3 = ROW_BG
			row.Parent = GamesPage
			Round(8, row)

			local nameLabel = Instance.new("TextLabel")
			nameLabel.BackgroundTransparency = 1
			nameLabel.Position = UDim2.new(0, 10, 0, 4)
			nameLabel.Size = UDim2.new(1, -130, 0, 28)
			nameLabel.Text = g[1]
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextScaled = true
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = row

			local nc = Instance.new("UITextSizeConstraint")
			nc.MaxTextSize = 16
			nc.MinTextSize = 7
			nc.Parent = nameLabel

			local idLabel = Instance.new("TextLabel")
			idLabel.BackgroundTransparency = 1
			idLabel.Position = UDim2.new(0, 10, 0, 32)
			idLabel.Size = UDim2.new(1, -130, 0, 20)
			idLabel.Text = "ID: " .. FmtId(g[2])
			idLabel.TextColor3 = Color3.fromRGB(150, 170, 200)
			idLabel.Font = Enum.Font.Gotham
			idLabel.TextScaled = true
			idLabel.TextXAlignment = Enum.TextXAlignment.Left
			idLabel.Parent = row

			local ic2 = Instance.new("UITextSizeConstraint")
			ic2.MaxTextSize = 13
			ic2.MinTextSize = 7
			ic2.Parent = idLabel

			local go = Instance.new("TextButton")
			go.AnchorPoint = Vector2.new(1, 0.5)
			go.Position = UDim2.new(1, -8, 0.5, 0)
			go.Size = UDim2.new(0, 108, 0, 38)
			go.BackgroundColor3 = GREEN
			go.Text = "Configurar"
			go.TextColor3 = Color3.new(1, 1, 1)
			go.Font = Enum.Font.GothamBold
			go.TextScaled = true
			go.Parent = row
			Round(8, go)

			local gc = Instance.new("UITextSizeConstraint")
			gc.MaxTextSize = 16
			gc.MinTextSize = 7
			gc.Parent = go

			go.Activated:Connect(function()
				SetDest(g[2], g[1])
			end)
		end

		table.insert(Refreshers, RefreshGames)
		end

		-- PAGINA AGARRE ----------------------------------

		local GripPage = Pages[5]

		local function GripStepper(text, order, key, step, isRot)

			MakeStepper(GripPage, text, order,
				function() return GripState[key] end,
				function(v)
					if isRot then
						v = v % 360
					end
					GripState[key] = v
					ApplyGrip()
				end,
				step, -10000, 10000, isRot and "%.0f" or "%.2f")
		end

		GripStepper("Pos X", 1, "px", 0.05, false)
		GripStepper("Pos Y", 2, "py", 0.05, false)
		GripStepper("Pos Z", 3, "pz", 0.05, false)
		GripStepper("Giro X", 4, "rx", 15, true)
		GripStepper("Giro Y", 5, "ry", 15, true)
		GripStepper("Giro Z", 6, "rz", 15, true)

		local RollButton = MakeButton(GripPage, "Rodar arma 90 (si esta recostada)", 7, 40, BTN_BG)
		local FlipButton = MakeButton(GripPage, "Invertir canon (si apunta hacia atras)", 8, 40, BTN_BG)
		local AxisButton = MakeButton(GripPage, "Cambiar eje del canon (X / Z)", 9, 40, BTN_BG)

		RollButton.Activated:Connect(function()
			GripState.rz = (GripState.rz + 90) % 360
			ApplyGrip()
			RefreshAll()
		end)

		FlipButton.Activated:Connect(function()
			GripState.ry = (GripState.ry + 180) % 360
			ApplyGrip()
			RefreshAll()
		end)

		AxisButton.Activated:Connect(function()
			GripState.ry = (GripState.ry + 90) % 360
			ApplyGrip()
			RefreshAll()
		end)

		-- PAGINA COLOCAR ---------------------------------

		local PlacePage = Pages[6]
		local PlaceButtons = {}

		MakeLabel(PlacePage, "Como aparecen los portales:", 1, 30, true)

		for i, name in ipairs({ "Acostado (suelo)", "Parado (de pie)", "Volando (cielo)" }) do

			local pb = MakeButton(PlacePage, name, i + 1, 44, BTN_BG)
			PlaceButtons[i] = pb

			pb.Activated:Connect(function()
				SetPlaceMode(i)
			end)
		end

		MakeStepper(PlacePage, "Distancia cielo", 5,
			function() return SkyDistance end,
			function(v) SkyDistance = v end,
			10, 20, 1000, "%.0f")

		MakeLabel(PlacePage, "Volando: toca el cielo y el portal aparece acostado (horizontal) en ese punto del aire. Si tocas una superficie funciona como Acostado. La tecla F cambia de modo.", 6, 84, false)

		table.insert(Refreshers, function()
			for i, pb in ipairs(PlaceButtons) do
				if i == PlaceMode then
					pb.BackgroundColor3 = GREEN
				else
					pb.BackgroundColor3 = BTN_BG
				end
			end
		end)

		-- PAGINA CONFIG ----------------------------------

		local CfgPage = Pages[7]

		local function MakeToggle(parent, order, text, get, set)

			local b = MakeButton(parent, "", order, 44, BTN_BG)

			local function refresh()
				local on = get()
				b.Text = text .. ": " .. (on and "ON" or "OFF")
				b.BackgroundColor3 = on and GREEN or BTN_BG
			end

			b.Activated:Connect(function()
				set(not get())
				refresh()
			end)

			table.insert(Refreshers, refresh)
			refresh()

			return b
		end

		MakeLabel(CfgPage, "Portal - configuracion", 1, 30, true)

		MakeSizeStepper(CfgPage, 2)
		NX.MakeWidthStepper(CfgPage, 3)
		NX.MakeHeightStepper(CfgPage, 4)

		do
			local resetShape = MakeButton(CfgPage, "Restablecer tamaño / ancho / alto", 5, 40, BTN_BG)

			resetShape.Activated:Connect(function()
				NX.widthMul = 1
				NX.heightMul = 1
				NX.SetPortalSize(1.8)
				RefreshAll()
			end)
		end

		MakeStepper(CfgPage, "Dist. detras del jugador", 6,
			function() return NX.behindDist end,
			function(v) NX.behindDist = v end,
			1, 4, 40, "%.0f")

		MakeToggle(CfgPage, 7, "Mano sigue el cursor",
			function() return NX.aimArm end,
			function(v) NX.aimArm = v end)

		MakeToggle(CfgPage, 9, "Animaciones (brazo y disparo)",
			function() return NX.anims end,
			function(v) NX.anims = v end)

		MakeStepper(CfgPage, "Giro de mano al equipar", 15,
			function() return NX.vm.twist end,
			function(v) NX.vm.twist = v end,
			10, 0, 360, "%.0f")

		MakeLabel(CfgPage, "Tamano cambia todo el portal; Ancho y Alto lo estiran (si son distintos el portal no gira, solo se balancea). Los cambios afectan tambien a los portales ya abiertos.", 16, 80, false)

		-- BOTON MENU -------------------------------------

		local MenuButton = Instance.new("TextButton")
		MenuButton.Name = "MenuButton"
		MenuButton.AnchorPoint = Vector2.new(0, 0.5)
		MenuButton.Position = UDim2.new(0.885, 0, 0.517, 0)
		MenuButton.Size = UDim2.new(0.058, 0, 0.1, 0)
		MenuButton.BackgroundColor3 = PANEL_BG
		MenuButton.Text = "MENU"
		MenuButton.TextColor3 = GREEN
		MenuButton.Font = Enum.Font.GothamBold
		MenuButton.TextScaled = true
		MenuButton.Parent = MenuGui
		Round(12, MenuButton)
		AddStroke(MenuButton, GREEN, 2)
		Shared.UI.hacerArrastrable(MenuButton)

		local mc = Instance.new("UITextSizeConstraint")
		mc.MaxTextSize = 22
		mc.MinTextSize = 8
		mc.Parent = MenuButton

		MenuButton.Activated:Connect(function()
			if Shared.UI.recienMovido(MenuButton) then
				return
			end

			Panel.Visible = not Panel.Visible

			if Panel.Visible and Shared.BombaPanel then
				Shared.BombaPanel.Visible = false
			end

			if Panel.Visible and Shared.PistolaPanel then
				Shared.PistolaPanel.Visible = false
			end

			if Panel.Visible then
				RefreshAll()
			end
		end)

		CloseButton.Activated:Connect(function()
			Panel.Visible = false
		end)

		-- Actualiza el contador "Portales activos" mientras el menu esta abierto
		task.spawn(function()
			while Alive do
				task.wait(0.25)

				if Panel.Visible or (Shared.BombaPanel and Shared.BombaPanel.Visible) then
					RefreshAll()
				end
			end
		end)

		ApplyMode()
		ShowTab(1)
		RefreshAll()

		--------------------------------------------------
		-- RESPAWN
		--------------------------------------------------

		local function OnCharacterAdded(newCharacter)

			Character = newCharacter

			pcall(NX.EndEmerge, true)

			NX.arm = nil
			table.clear(NX.pieces)
			NX.ClearGhosts()

			ToolEquipped = false
			PortalGun = nil
			CanShoot = true
			NX.nextShot = 0
			NX.shotQueued = false
			NX.lastRootPos = nil

			CloseAllPortals()

			task.wait(1)

			CreatePortalGun()
		end

		Con(Player.CharacterAdded, OnCharacterAdded)

		--------------------------------------------------
		-- INICIO
		--------------------------------------------------

		task.spawn(function()

			for _ = 1, 10 do

				local ok, result = pcall(function()
					return AssetService:CreateMeshPartAsync(PORTAL_MESH)
				end)

				if ok and result then

					result.TextureID = PORTAL_TEXTURE

					pcall(function()
						ContentProvider:PreloadAsync({
							result,
							PORTAL_TEXTURE,
							SOUND_OPEN,
							SOUND_ENTER,
							SOUND_CLOSE
						})
					end)

					PortalTemplate = result
					break
				end

				task.wait(1)
			end

			NX.templateDone = true
		end)

		-- Datos compartidos con el modulo de la bomba
		Shared.Portals = Portals
		Shared.GetModo = function() return CurrentMode end
		Shared.GetDestino = function() return DestPlaceId end
		Shared.IsInsidePortal = IsInsidePortal
		Shared.PlaySound = PlaySound
		Shared.SOUND_ENTER = SOUND_ENTER
		Shared.Refreshers = Refreshers
		Shared.MakeStepper = MakeStepper
		Shared.MakeButton = MakeButton
		Shared.MakeLabel = MakeLabel
		Shared.Round = Round
		Shared.AddStroke = AddStroke
		Shared.EstilizarPanel = StylePanel
		Shared.OcultarPrincipal = function() Panel.Visible = false end
		Shared.Colores = {
			GREEN = GREEN, PANEL_BG = PANEL_BG, BTN_BG = BTN_BG,
			ROW_BG = ROW_BG, RED = RED, DARK_RED = DARK_RED,
		}
		Shared.MenuGui = MenuGui

		env.PORTALES_LIMPIAR = function()
			Alive = false

			for _, c in ipairs(Conns) do
				pcall(function() c:Disconnect() end)
			end

			pcall(function() RunService:UnbindFromRenderStep(NX.renderName) end)
			pcall(NX.vmRestore)
			pcall(function()
				local h = Character and Character:FindFirstChildOfClass("Humanoid")
				if h and NX.bodyTurned then h.AutoRotate = true end
			end)
			pcall(NX.EndEmerge, true)
			pcall(NX.ClearGhosts)
			pcall(CloseAllPortals)
			pcall(function() PortalFolder:Destroy() end)
			pcall(function() MenuGui:Destroy() end)
			pcall(function() StandGui:Destroy() end)
			pcall(function() if GunTool then GunTool:Destroy() end end)

			Shared.MenuGui = nil
			Shared.BombaPanel = nil
			Shared.Portals = nil
		end

		CreatePortalGun()

		print("=== SISTEMA CARGADO ===")
		print("Portal Gun de Rick Prime + Menu")

		end


		--##########################################################################
		-- ARRANQUE
		--##########################################################################
		task.spawn(function()
			local ok, err = pcall(MODULO_PORTALES)
			if not ok then
				warn("[PISTOLA-PORTALES] Falló el módulo: " .. tostring(err))
			end
		end)

	end)
end

print("[RICKPRIME] Cargado. Botones BRAZO / PIERNA / TODO / MORIR | Teclas Z X C V | Daño >= " .. CFG.DamageToSever .. " corta un miembro | Revivir saliendo del piso (Omega): " .. tostring(CFG.Emerge) .. " | Arrastre con 2 piernas rotas: " .. tostring(CFG.Crawl))
