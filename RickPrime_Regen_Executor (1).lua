--!nonstrict
-- ============================================================
-- RICK PRIME REGENERATION (Delta Executor / LocalScript)
-- Los 3 videos en un solo script: miembro (brazo / pierna) y muerte completa
-- Z = brazo | X = pierna | C = todos los miembros | V = morir
-- Botones circulares arrastrables (celular) | panel ON/OFF arriba
-- Todo es LOCAL: lo ves tú. Al morir reapareces EN EL MISMO LUGAR.
-- NO salen tentáculos del suelo: los listones nacen del cuerpo.
-- v2: al regenerarte el cuerpo queda TUMBADO en el piso y se PARA como en los 3 videos
--     (piernas primero, torso pivotando desde la cadera, brazos que se abren y bajan).
--     Sin temblor, sin convulsión, sin mover la cámara, siempre apoyado en el suelo,
--     y PUEDES MOVERTE mientras se reproduce (el root no se ancla; velocidad reducida hasta pararte).
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

-- ===== CONFIG =====
local CFG = {
	DamageToSever = 1, -- daño mínimo para perder un miembro (sube a 10-15 si quieres que solo pase con golpes fuertes)
	TriggerOnDamage = true,
	DamageCooldown = 0.8, -- segundos mínimos entre un miembro perdido y otro por daño
	FallToSever = true, -- caídas fuertes también te cortan un miembro (aunque el juego no tenga daño de caída)
	FallSpeedToSever = 60, -- velocidad de caída mínima (studs/s); ~60 = salto desde unos 25 studs

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
	MoveDuringRegen = true, -- true: puedes caminar y mover la cámara mientras te regeneras (con GetUpMoveSpeed controlas qué tan rápido)

	-- ===== LEVANTARSE (copiado de los videos: frente / lado / arriba) =====
	GetUp = true, -- true: el cuerpo regenerado empieza TUMBADO en el piso y se para; false: aparece de pie como antes
	GetUpDelay = 0.5, -- segundos tumbado antes de empezar a pararse
	GetUpRise = 1.3, -- segundos que tarda en pararse (piernas primero, torso despues)
	GetUpSettle = 0.6, -- segundos finales: los brazos bajan y se acomoda
	GetUpLean = 12, -- grados que se inclina hacia adelante (cabeza agachada) justo al terminar de pararse (0 = recto)
	GetUpArms = 1, -- cuanto abre los brazos al pararse (0 = no los mueve, 1 = como el video, 1.5 = mas)
	GetUpMoveSpeed = 0.45, -- velocidad al caminar mientras te paras (0 = quieto, 1 = normal); sube sola a la normal al terminar

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
-- LEVANTARSE (copiado de los 3 videos: frente / lado / arriba)
--   Del video de ARRIBA: el cuerpo nace TUMBADO en el piso, boca arriba, con los pies donde estaba parado.
--   Del video de LADO:   las PIERNAS se paran primero; el torso se levanta DESPUES, pivotando desde la
--                        cadera, con la cabeza agachada; se pasa un poco hacia adelante y se endereza.
--   Del video de FRENTE: los brazos se abren hacia los lados al pararse y luego bajan despacio.
--
--   Como funciona (para que puedas moverte y no haya temblores):
--   * El HumanoidRootPart NO se ancla ni se mueve a mano: sigue de pie y TU controlas el movimiento.
--     Solo se cambia el C0 de las articulaciones (Motor6D), asi que el cuerpo se ve tumbado/parandose
--     mientras caminas. La camara sigue al root (de pie), por eso NO se mueve ni baja.
--   * Todo es matematica suave (sin azar, sin vibracion): cero temblores, cero sacudidas.
--   * Pegado al piso: cada cuadro se calcula el punto mas bajo del cuerpo y se sube lo justo para que
--     NUNCA se hunda ni flote (el cuerpo jamas sale del suelo).
--   * Mientras te paras: sin saltar y con velocidad reducida; la velocidad vuelve sola a la normal.
--------------------------------------------------------------------------------
local GetUp = { active = nil }

local function smooth01(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function bump(x) -- 0 en los extremos, 1 en el medio, sin saltos
	local s = math.sin(math.pi * math.clamp(x, 0, 1))
	return s * s
end

local function mix(a, b, t)
	return a + (b - a) * t
end

local function findJoint(char, partName)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == partName then
			return d
		end
	end
	return nil
end

-- gira lo que cuelga de la articulacion, alrededor de la articulacion (ejes del Part0)
local function offsetJoint(entry, rot)
	local pivot = entry.base.Position
	entry.j.C0 = CFrame.new(pivot) * rot * CFrame.new(-pivot) * entry.base
end

-- gira alrededor de un punto, sobre el eje X (adelante / atras)
local function rotAbout(pivot, a)
	return CFrame.new(pivot) * CFrame.Angles(a, 0, 0) * CFrame.new(-pivot)
end

function GetUp.stop()
	local s = GetUp.active
	if not s then
		return
	end
	GetUp.active = nil
	pcall(function()
		RunService:UnbindFromRenderStep("RickPrimeGetUp")
	end)
	pcall(s.restore)
end

-- Devuelve { finish() } o nil. Llamar con el cuerpo de pie, escondido y ya apoyado en el piso.
function GetUp.start(char, hum, root)
	GetUp.stop()
	if not CFG.GetUp or cleaned or not char.Parent then
		return nil
	end
	if not char.PrimaryPart then
		char.PrimaryPart = root
	end

	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local rootJoint = findJoint(char, r15 and "LowerTorso" or "Torso")
	if not rootJoint or rootJoint.Part0 ~= root then
		return nil -- rig raro: no se anima (el cuerpo solo aparece de pie)
	end
	local torso = rootJoint.Part1

	-- el root queda libre para que puedas moverte (si MoveDuringRegen = false se queda quieto)
	root.Anchored = not CFG.MoveDuringRegen

	-- ===== geometria (todo en el espacio del root, que esta de pie) =====
	local bbCF, bbSize = char:GetBoundingBox()
	local hx, hy, hz = bbSize.X / 2, bbSize.Y / 2, bbSize.Z / 2
	local c = root.CFrame:PointToObjectSpace(bbCF.Position)
	local feetY = c.Y - hy
	local topY = feetY + hy * 2
	local F = Vector3.new(c.X, feetY, c.Z) -- punto entre los pies, a ras del piso

	local torsoRel = rootJoint.C0 * rootJoint.C1:Inverse() -- root -> torso (de pie)
	local rootBase = rootJoint.C0

	-- caderas: ahi se dobla el torso respecto a las piernas
	local hips = {}
	local function addHip(partName)
		local j = findJoint(char, partName)
		if j and j.Part0 == torso then
			table.insert(hips, { j = j, base = j.C0 })
		end
	end
	if r15 then
		addHip("LeftUpperLeg")
		addHip("RightUpperLeg")
	else
		addHip("Left Leg")
		addHip("Right Leg")
	end
	local hinge = #hips == 2
	local H = F + Vector3.new(0, hy * 0.8, 0)
	if hinge then
		local sum = Vector3.zero
		for _, e in ipairs(hips) do
			sum += e.base.Position
		end
		H = torsoRel:PointToWorldSpace(sum / #hips)
	end
	H = Vector3.new(H.X, math.clamp(H.Y, feetY + 0.5, topY - 0.5), H.Z)

	-- cajas (piernas / parte de arriba) para saber cual es el punto mas bajo y apoyarlo en el piso
	local function boxPoints(y0, y1)
		local pts = {}
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ y0, y1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					pts[#pts + 1] = Vector3.new(c.X + sx * hx, sy, c.Z + sz * hz)
				end
			end
		end
		return pts
	end
	local lowerPts = boxPoints(feetY, H.Y)
	local upperPts = boxPoints(H.Y, topY)

	-- aL = angulo de las piernas, aT = angulo del torso (> 0 tumbado boca arriba, < 0 inclinado hacia adelante)
	-- Devuelve: CFrame del cuerpo entero (root joint) y CFrame de doblez en la cadera
	local function bodyOffsets(aL, aT)
		local offL = rotAbout(F, aL)
		local bend = rotAbout(H, aT - aL)
		local offT = offL * bend
		local minY = math.huge
		for _, p in ipairs(lowerPts) do
			minY = math.min(minY, offL:PointToWorldSpace(p).Y)
		end
		for _, p in ipairs(upperPts) do
			minY = math.min(minY, offT:PointToWorldSpace(p).Y)
		end
		local lift = math.max(0, feetY - minY) -- sube lo justo para no hundirse; jamas mas
		return CFrame.new(0, lift, 0) * offT, bend
	end

	-- ===== tiempos y curvas =====
	local D = math.max(CFG.GetUpDelay, 0)
	local R = math.max(CFG.GetUpRise, 0.1)
	local S = math.max(CFG.GetUpSettle, 0.05)
	local total = D + R + S
	local A0 = math.rad(90)
	local lean = math.rad(math.max(CFG.GetUpLean, 0))
	local armK = CFG.GetUpArms
	local speedK = math.clamp(CFG.GetUpMoveSpeed or 0.45, 0, 1)

	-- curva del torso: arranca y termina suave (velocidad 0) con una pasadita hacia adelante antes de enderezarse
	local function fAt(p, k)
		local q = math.clamp((p - 0.45) / 0.55, 0, 1)
		return smooth01(p) + k * bump(q)
	end
	local want = 1 + lean / A0
	local lo, hi = 0, 2
	for _ = 1, 22 do
		local mid = (lo + hi) / 2
		local peak = 0
		for i = 0, 40 do
			peak = math.max(peak, fAt(i / 40, mid))
		end
		if peak < want then
			lo = mid
		else
			hi = mid
		end
	end
	local K = (lo + hi) / 2

	local function anglesAt(t)
		if t <= D then
			return A0, A0
		end
		local p = math.clamp((t - D) / R, 0, 1)
		local aT = A0 * (1 - fAt(p, K)) -- el torso se levanta despacio, con cabeza agachada
		local aL = A0 * (1 - smooth01(p / 0.62)) -- las piernas se paran primero (video de lado)
		if not hinge then
			aL = aT
		end
		return aL, aT
	end

	-- brazos (abrir hacia los lados + un poco hacia adelante, luego bajar) y cabeza (agacha la barbilla al subir)
	local function limbsAt(t)
		if t <= D then
			return math.rad(22) * armK, math.rad(22) * armK, 0, 0
		end
		local p = math.clamp((t - D) / R, 0, 1)
		local s = math.clamp((t - D - R) / S, 0, 1)
		local open = smooth01(p / 0.8)
		local k = (1 - smooth01(s)) * armK
		local rAbd = mix(math.rad(22), math.rad(78), open) * k -- el derecho sube un poco mas (como en el video)
		local lAbd = mix(math.rad(22), math.rad(58), open) * k
		local flex = math.rad(26) * open * k
		local nod = -math.rad(10) * bump(p)
		return rAbd, lAbd, flex, nod
	end

	-- ===== articulaciones de brazos y cabeza (R6 y R15) =====
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

	-- sin animaciones del juego peleando contra la pose (eso es lo que causa los temblores)
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
	local keepStopping = true
	local function backToAnimate()
		if animateWasOn and animate and animate.Parent and animate.Disabled then
			animate.Disabled = false
		end
		keepStopping = false
	end

	-- las partes no chocan con el piso mientras estas tumbado (no te empujan ni te hacen vibrar)
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

	-- sin saltos mientras te paras (saltar sacaria el cuerpo tumbado del suelo)
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end)
	local baseWalk = hum.WalkSpeed
	local moveFree = CFG.MoveDuringRegen

	local state = {}
	GetUp.active = state
	local t0 = os.clock()

	local function pose(t)
		-- cuerpo entero (articulacion raiz) + doblez de cadera (las piernas se quedan paradas)
		local offT, bend = bodyOffsets(anglesAt(t))
		rootJoint.C0 = offT * rootBase
		if hinge then
			local fix = torsoRel:Inverse() * bend:Inverse() * torsoRel
			for _, e in ipairs(hips) do
				e.j.C0 = fix * e.base
			end
		end

		local rAbd, lAbd, flex, nod = limbsAt(t)
		if joints.R then
			offsetJoint(joints.R, CFrame.Angles(flex, 0, rAbd))
		end
		if joints.L then
			offsetJoint(joints.L, CFrame.Angles(flex, 0, -lAbd))
		end
		if joints.N then
			offsetJoint(joints.N, CFrame.Angles(nod, 0, 0))
		end

		-- poder caminar mientras te paras: lento al inicio, velocidad normal al terminar
		if moveFree then
			local s = smooth01((t - D - R) / S)
			hum.WalkSpeed = baseWalk * mix(speedK, 1, s)
		end
		-- al terminar de subir, vuelve la animacion normal (caminar / idle) mientras bajan los brazos
		if t >= D + R and keepStopping then
			backToAnimate()
		end
	end

	function state.restore()
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
		for _, e in ipairs(hips) do
			if e.j.Parent then
				e.j.C0 = e.base
			end
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
			if moveFree then
				hum.WalkSpeed = baseWalk
			end
		end
	end

	pose(0)
	RunService:BindToRenderStep("RickPrimeGetUp", Enum.RenderPriority.Input.Value + 2, function()
		if GetUp.active ~= state or cleaned or not root.Parent then
			GetUp.stop()
			return
		end
		local ok, err = pcall(pose, os.clock() - t0)
		if not ok then
			warn("[RICKPRIME] GetUp: " .. tostring(err))
			GetUp.stop()
			return
		end
		if keepStopping then
			stopTracks()
		end
	end)

	local handle = {}
	-- deja que la animacion termine (si falta) y devuelve todo a la normalidad
	function handle.finish()
		while GetUp.active == state and (os.clock() - t0) < total and not cleaned do
			task.wait()
		end
		if GetUp.active == state then
			pcall(pose, total)
			GetUp.stop()
		end
	end
	return handle
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
local State = { char = nil, hum = nil, busy = false, severed = {} }
local pendingDeath = nil

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
	Rig.hide(parts)
	task.delay(0.8, function() -- el miembro cae al piso
		if piece.model.Parent then
			Sfx.play("thump", piece.list[1].piece.Position, 0.5, 1.4)
		end
	end)

	spawnSafe(function()
		task.wait(CFG.LimbLinger)
		if cleaned or not Rig.isAlive(char, hum) then
			return
		end
		local ctx = { char = char, hum = hum, scope = Scope.new() }
		regenGroup(ctx, groups, gname, piece, "grow")
		State.severed[gname] = nil
		if CFG.VoiceOnLimbRegen and not cleaned then
			Sfx.voice()
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
	GetUp.stop() -- si moriste mientras te parabas, se suelta todo
	if not autoActivo or pendingDeath then
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

	pendingDeath = { cf = deathCF, camCF = camSaved, pieces = pieces, mass = mass, t0 = os.clock() }
end

local function regenBody(char, hum, data)
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
	if not CFG.MoveDuringRegen then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum.AutoRotate = false
	end

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
	-- con GetUp, GetUp.start suelta el root (puedes moverte mientras te paras); sin GetUp ya puedes caminar
	if CFG.MoveDuringRegen and not CFG.GetUp and char.Parent then
		root.Anchored = false
	end

	-- empieza a pararse (el cuerpo real sigue escondido; los bloques amarillos lo siguen)
	local getUp = nil
	if CFG.GetUp and char.Parent then
		local okGU, res = pcall(GetUp.start, char, hum, root)
		if okGU then
			getUp = res
		else
			warn("[RICKPRIME] GetUp: " .. tostring(res))
		end
	end

	-- empieza la regeneración: sonido de generación en bucle hasta que termine
	local printLoop = Sfx.loop("print", nil, 1.2, 1)
	if not Sfx.ready.print then
		Sfx.play("squelch", nil, 1, 0.5)
	end
	task.wait(0.3)
	if data.mass then
		data.mass.Stop(CFG.MassFadeOut)
	end

	local groups = Rig.groups(char)
	local ctx = { char = char, hum = hum, scope = Scope.new() }
	local running = 0
	for _, step in ipairs(STEPS) do
		if cleaned or not Rig.isAlive(char, hum) then
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
	while running > 0 do
		task.wait()
	end
	printLoop.Stop(0.3)

	-- termina de pararse (si falta) y devuelve articulaciones / animaciones / cámara a la normalidad
	if getUp then
		getUp.finish()
	end

	-- red de seguridad: todo visible y sin restos
	for _, parts in pairs(groups) do
		Rig.reveal(parts, 0)
	end
	Rig.revealAccessories(char)
	ctx.scope:Destroy()
	for _, pc in pairs(data.pieces) do
		if pc.model.Parent then
			pc.model:Destroy()
		end
	end

	if char.Parent then
		root.Anchored = false
		hum.WalkSpeed = saved.walk
		hum.JumpPower = saved.jumpPower
		hum.JumpHeight = saved.jumpHeight
		hum.AutoRotate = saved.autoRotate
		-- ya reviviste: sale una de las frases (alternando)
		task.delay(0.25, Sfx.voice)
	end
	pendingDeath = nil
	State.busy = false
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
	State.char = char
	State.hum = hum
	State.severed = {}

	con(hum.Died, function()
		onDeath(char, hum)
	end)

	local last = hum.Health
	con(hum.HealthChanged, function(health)
		local damage = last - health
		last = health
		if autoActivo and CFG.TriggerOnDamage and health > 0 and damage >= CFG.DamageToSever then
			severRandomLimb()
		end
	end)

	-- caídas: mide la velocidad al aterrizar
	local fallV = 0
	con(RunService.Heartbeat, function()
		if char.Parent and hum:GetState() == Enum.HumanoidStateType.Freefall then
			local r = char:FindFirstChild("HumanoidRootPart")
			if r then
				fallV = math.min(fallV, r.AssemblyLinearVelocity.Y)
			end
		end
	end)
	con(hum.StateChanged, function(_, new)
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
	GetUp.stop()
	State.busy = false
	task.spawn(vigilar, char)

	if pendingDeath then
		local data = pendingDeath
		spawnSafe(function()
			local hum = char:WaitForChild("Humanoid", 10)
			if not hum then
				pendingDeath = nil
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
	local arrastrando, movido = false, false
	local inicio, posIni

	con(obj.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			movido = false
			inicio = input.Position
			posIni = obj.Position
		end
	end)

	con(UIS.InputChanged, function(input)
		if not arrastrando then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - inicio

			if d.Magnitude > 8 then
				movido = true
			end

			if movido then
				obj.Position = UDim2.new(
					posIni.X.Scale, posIni.X.Offset + d.X,
					posIni.Y.Scale, posIni.Y.Offset + d.Y
				)
			end
		end
	end)

	con(UIS.InputEnded, function(input)
		if not arrastrando then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = false
			if not movido then
				alClick()
			end
		end
	end)
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
	pcall(GetUp.stop)
	for _, c in ipairs(conexiones) do
		pcall(function()
			c:Disconnect()
		end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("RickPrimeShake")
		RunService:UnbindFromRenderStep("RickPrimeCamHold")
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

print("[RICKPRIME] Cargado. Botones BRAZO / PIERNA / TODO / MORIR | Teclas Z X C V | Daño >= " .. CFG.DamageToSever .. " corta un miembro | Se para al regenerarse: " .. tostring(CFG.GetUp))
