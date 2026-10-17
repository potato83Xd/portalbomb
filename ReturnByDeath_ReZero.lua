--[[
	RETURN BY DEATH — RE:ZERO EDITION  (v2)
	LocalScript para Delta Executor (Android). Todo es del lado del cliente.

	QUÉ HACE
	  1. Guarda checkpoints de tu personaje mientras estás vivo, pero SOLO si estás
	     parado sobre un suelo estable (no en el aire, no sobre plataformas que
	     desaparecen, no sobre suelos móviles/sueltos/peligrosos).
	  2. Al morir lanza una secuencia oscura (fundido a negro, sombras moradas,
	     texto "RETURN BY DEATH", reloj que retrocede).
	  3. Cuando el juego te reaparece, REVALIDA el checkpoint justo antes de volver
	     (el mapa pudo cambiar). Si ya no es seguro, usa el último checkpoint seguro
	     anterior; si no hay ninguno, te deja en el spawn del juego.
	  4. Al volver, el checkpoint nuevo queda en ese punto y el ciclo se repite.
	  5. AURA DE SATELLA acumulativa: tras cada retorno aparece (o se actualiza)
	     un aura negra/violeta que crece con el total de muertes de la sesión.
	  6. Anti-bucle: varias muertes seguidas en pocos segundos descartan los
	     checkpoints y detienen los regresos repetidos a una posición mala.

	CÓMO EJECUTAR
	  Pega el script completo en Delta y pulsa Execute. Si lo ejecutas otra vez,
	  limpia la versión anterior sola. No necesita botones: es automático.

	LIMITACIONES (importante)
	  - Un LocalScript NO puede reaparecerte ni cambiar tu vida en el servidor.
	    El script espera a que el propio juego te reaparezca.
	  - Tu vida (Health) la controla el servidor: se guarda para referencia, pero
	    no se puede restaurar desde el cliente.
	  - El movimiento de tu personaje sí lo controla tu cliente, así que el
	    teletransporte suele funcionar. Si el juego tiene anticheat o te devuelve
	    a otra posición, el script lo detecta, reintenta y si no puede, falla de
	    forma segura (te deja donde reapareciste).
	  - El cliente NO puede saber si una plataforma es temporal en el servidor.
	    Lo que hace es: exigir que el suelo lleve >= MinStandTime segundos sin
	    moverse ni desvanecerse, y volver a comprobar (raycast) justo antes de
	    regresar. Una plataforma que desaparece DESPUÉS de esa comprobación no se
	    puede prever; para eso están el chequeo de aterrizaje, el regreso al spawn
	    y el anti-bucle. Los suelos "peligrosos" se detectan por nombre (heurística).
	  - El aura es solo visual y local: otros jugadores no la ven.
	  - No usa RemoteEvents del juego ni intenta saltarse protecciones.
]]

--------------------------------------------------------------------------------
-- CONFIGURACIÓN
--------------------------------------------------------------------------------
local CFG = {
	Enabled = true,

	-- Checkpoints
	SaveInterval = 0.5, -- cada cuántos segundos se guarda tu posición
	RewindSeconds = 4, -- vuelves al checkpoint de hace N segundos (0 = el último guardado exacto)
	HistoryExtra = 3, -- segundos extra de historial que se conservan
	SaveOnlyWhenGrounded = true, -- solo guarda en suelo (o nadando): evita volver en el aire / lava
	MinHeightAboveVoid = 60, -- no guarda si estás cerca de la altura donde se destruyen las partes

	-- Tiempos (segundos)
	DeathSequenceTime = 3.2, -- duración mínima de la secuencia de muerte (pantalla negra + texto)
	RespawnTimeout = 30, -- cuánto esperar a que el juego te reaparezca
	AppearanceTimeout = 3, -- cuánto esperar a que cargue tu apariencia al reaparecer
	SettleDelay = 0.4, -- pausa tras reaparecer (algunos juegos te mueven al spawn)
	RewindTime = 2.2, -- duración del "mundo retrocediendo"
	RestoreTime = 1.8, -- cuánto tarda en volver la imagen
	ReturnLift = 1.5, -- studs que te sube al volver (evita quedar dentro del suelo)
	ReturnRetries = 3, -- intentos de teletransporte
	VerifyDelay = 0.35, -- espera antes de comprobar que el movimiento se aceptó
	VerifyTolerance = 12, -- distancia máxima (studs) para considerar válido el regreso
	RestoreCamera = true, -- coloca la cámara una vez, bajo la pantalla negra (luego la mueves tú)

	-- Visual
	Quality = 2, -- 1 = gama baja (menos sombras, sin glitch) | 2 = normal | 3 = alta
	Text = "RETURN BY DEATH",
	GlowColor = Color3.fromRGB(150, 60, 255),
	TextColor = Color3.fromRGB(235, 220, 255),
	ShadowColor = Color3.fromRGB(6, 0, 12),
	Debug = false, -- true: imprime el estado en la consola

	-- Seguridad de checkpoints (anti-vacío)
	SafeCheckpoints = true, -- false = comportamiento clásico (sin validar el suelo)
	MinStandTime = 1.2, -- segundos mínimos sobre el MISMO suelo antes de guardar un checkpoint
	GroundRayLength = 8, -- studs que se miran hacia abajo para confirmar suelo
	MinFloorNormalY = 0.6, -- pendiente máxima del suelo (1 = plano, 0.6 = unos 53°)
	MaxVerticalSpeed = 8, -- no guarda si te mueves más rápido que esto en vertical (saltando/cayendo)
	RequireGroundedState = true, -- solo guarda en estado Running/Landed (no Freefall/Jumping/etc.)
	MaxFloorTransparency = 0.85, -- un suelo más transparente se considera "desapareciendo"
	MaxFloorMove = 1.5, -- studs que puede moverse el suelo entre muestras (0.5 s)
	AllowMovingFloors = false, -- true = permite guardar sobre plataformas móviles
	RequireAnchoredFloor = true, -- el suelo debe estar anclado (no piezas sueltas)
	AllowSwimmingCheckpoints = false, -- true = también guarda nadando (sin validar suelo)
	HazardNames = { "kill", "lava", "death", "damage", "hurt", "acid" }, -- nombres de suelo que se rechazan
	FloorHeightTolerance = 3, -- al volver, el suelo no puede estar a más de N studs de donde estaba
	MaxAnchors = 6, -- checkpoints de respaldo (suelo anclado donde estuviste parado un rato)
	AnchorStandTime = 4, -- segundos parado en el mismo suelo para que cuente como respaldo
	AnchorMinSpacing = 10, -- distancia mínima entre respaldos
	AnchorMinInterval = 4, -- segundos mínimos entre respaldos
	MaxValidationsPerRestore = 14, -- tope de comprobaciones al volver (rendimiento)
	MaxReturnCandidates = 3, -- cuántos checkpoints distintos se prueban al volver
	LandingTimeout = 0.9, -- segundos para confirmar que aterrizaste tras volver
	FallAbortSpeed = 60, -- si caes más rápido que esto tras volver, se aborta y vuelves al spawn

	-- Anti-bucle de muertes
	LoopWindow = 25, -- ventana (segundos) para contar muertes seguidas
	LoopMaxDeaths = 3, -- muertes dentro de la ventana que activan el corte del bucle
	LoopAvoidRadius = 8, -- tras 2 muertes seguidas no se repite un checkpoint a menos de N studs

	-- Aura de Satella (negra con morado): aparece tras volver y crece con cada muerte
	AuraEnabled = true,
	AuraMaxLevel = 10, -- nivel = muertes de la sesión, con este tope (aura al máximo)
	AuraColor = Color3.fromRGB(150, 60, 255),
	AuraDeepColor = Color3.fromRGB(80, 10, 150),
	AuraDarkColor = Color3.fromRGB(4, 0, 10),
	AuraMaxIntensity = 1, -- 0..1: tope de opacidad/brillo
	AuraMaxSizeScale = 1, -- multiplicador del tamaño máximo de partículas y ondas
	AuraMaxParticleRate = 90, -- tope duro de partículas/segundo sumando todos los emisores
	AuraMaxRings = 3, -- tope de ondas de energía en el suelo (también limitado por Quality)
	AuraWaves = true, -- ondas de energía oscura en el suelo
	AuraSparks = true, -- chispas violetas pequeñas
	AuraLight = true, -- luz violeta que pulsa
	AuraAutoLowEnd = true, -- en móvil táctil sin teclado reduce las partículas
	AuraMobileScale = 0.6, -- factor aplicado en esos dispositivos
	AuraHideCameraDist = 3.5, -- si la cámara está más cerca, el humo se oculta (primera persona)
	AuraPersistDeaths = false, -- true = el contador sobrevive a volver a ejecutar el script

	-- Manos de sombra de Satella (4 imágenes independientes durante la secuencia de muerte)
	HandsEnabled = true,
	-- id = ID del asset de imagen. edge = borde por el que entra: "top", "bottom", "left" o "right".
	-- Si una mano sale en el borde equivocado, solo cambia su `edge`.
	HandImages = {
		{ id = "122683101701538", edge = "bottom" }, -- mano hacia arriba, brazo desde abajo
		{ id = "89215458522959", edge = "top" }, -- mano hacia abajo, brazo desde arriba
		{ id = "93422346067104", edge = "right" }, -- mano hacia la izquierda, brazo desde la derecha
		{ id = "129182958486986", edge = "left" }, -- mano hacia la derecha, brazo desde la izquierda
	},
	HandScale = 0.46, -- alto de cada mano (fracción del alto de pantalla)
	HandAspect = 2 / 3, -- ancho/alto de las imágenes (2:3 = vertical)
	HandImageColor = Color3.fromRGB(45, 15, 80), -- tinte: oscurece el fondo BLANCO de los JPG. Con PNG transparente pon Color3.new(1, 1, 1)
	HandShownTransparency = 0.08, -- transparencia cuando están visibles (0 = opacas)
	HandStartDelay = 0.6, -- segundos tras empezar la muerte (la pantalla ya va oscureciéndose)
	HandStagger = 0.35, -- retraso entre mano y mano
	HandEmergeTime = 2.4, -- duración de la aparición desde el borde
	HandCreepTime = 9, -- avance lento hacia el centro (continúa mientras esperas el respawn)

	-- Sonido al terminar la animación
	SoundEnabled = true,
	RezeroSoundId = "rbxassetid://107395341363434",
	SoundVolume = 1.5,
	SoundDelay = 0, -- segundos extra tras terminar la animación
}

--------------------------------------------------------------------------------
-- SERVICIOS Y LIMPIEZA DE EJECUCIONES ANTERIORES
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
if not player then
	warn("[RETURN BY DEATH] No hay LocalPlayer: ejecútalo como script de cliente.")
	return
end

local env = (getgenv and getgenv()) or _G
if env.__RBD_CLEANUP then
	pcall(env.__RBD_CLEANUP)
end

local rng = Random.new()
local function dbg(...)
	if CFG.Debug then
		print("[RETURN BY DEATH]", ...)
	end
end

--------------------------------------------------------------------------------
-- ESTADO
--------------------------------------------------------------------------------
local STATE = {
	ALIVE = "ALIVE",
	DEATH = "DEATH_SEQUENCE",
	WAIT = "WAITING_FOR_RESPAWN",
	RETURN = "RETURNING",
}
local state = STATE.ALIVE
local cycleId = 0
local deaths = 0 -- muertes en esta sesión: define qué tan fuerte es el aura (nunca se reinicia al reaparecer)
if CFG.AuraPersistDeaths and type(env.__RBD_DEATHS) == "number" then
	deaths = env.__RBD_DEATHS
end
local restoreOwner = 0 -- id del ciclo con permiso para restaurar (evita restauraciones simultáneas)
local cleaned = false
local persistentConns = {}
local charConns = {}
local currentChar, currentHum, currentRoot = nil, nil, nil
local diedHandled = setmetatable({}, { __mode = "k" })

local function setState(s)
	state = s
	dbg("estado ->", s)
end

local function persistent(conn)
	persistentConns[#persistentConns + 1] = conn
	return conn
end

--------------------------------------------------------------------------------
-- CHECKPOINTS (sin nada visual aquí)
--------------------------------------------------------------------------------
local Checkpoints = { history = {}, anchors = {} }

--------------------------------------------------------------------------------
-- SEGURIDAD DEL SUELO: valida el entorno al GUARDAR y otra vez justo al VOLVER
-- (todo con Raycast / GetPartBoundsInBox locales, baratos y sin bucles pesados)
--------------------------------------------------------------------------------
local Safety = {}

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude
overlapParams.MaxParts = 1
pcall(function()
	rayParams.RespectCanCollide = true
end)
pcall(function()
	overlapParams.RespectCanCollide = true
end)

local GROUNDED_STATES = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

local track = { part = nil, pos = nil, transp = 0, since = 0 }

function Safety.resetTrack()
	track.part, track.pos, track.transp, track.since = nil, nil, 0, 0
end

local function setFilter(char)
	local f = {}
	if char then
		f[1] = char
	end
	rayParams.FilterDescendantsInstances = f
	overlapParams.FilterDescendantsInstances = f
end

local function isAnchored(part)
	if part.Anchored then
		return true
	end
	local ar = part.AssemblyRootPart
	return ar ~= nil and ar.Anchored
end

local function nameIsHazard(inst)
	local names = CFG.HazardNames
	if not names then
		return false
	end
	local n = (inst.Name .. " " .. (inst.Parent and inst.Parent.Name or "")):lower()
	for _, w in ipairs(names) do
		if n:find(w, 1, true) then
			return true
		end
	end
	return false
end

-- Devuelve nil si el suelo es aceptable, o el motivo por el que no lo es.
local function floorProblem(res)
	if not res then
		return "sin suelo"
	end
	local part = res.Instance
	if not part or not part.Parent then
		return "suelo inexistente"
	end
	if res.Material == Enum.Material.Water or res.Material == Enum.Material.CrackedLava then
		return "material peligroso"
	end
	if res.Normal.Y < CFG.MinFloorNormalY then
		return "pendiente demasiado fuerte"
	end
	if not part:IsA("Terrain") then
		if part.Transparency > CFG.MaxFloorTransparency then
			return "suelo invisible o desapareciendo"
		end
		if not part.CanCollide then
			return "suelo sin colisión"
		end
		if CFG.RequireAnchoredFloor and not isAnchored(part) then
			return "suelo no anclado"
		end
		if nameIsHazard(part) then
			return "suelo peligroso por nombre"
		end
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then
			return "el suelo es otro personaje"
		end
	end
	return nil
end

local function groundBelow(pos, up, down)
	return Workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -(up + down), 0), rayParams)
end

-- ¿Está el personaje apoyado ahora mismo en un suelo válido? (para GUARDAR)
function Safety.sampleFloor(char, hum, root)
	if hum.Health <= 0 or hum.Sit or hum.PlatformStand then
		return nil, "sentado o muerto"
	end
	if hum.FloorMaterial == Enum.Material.Air then
		return nil, "en el aire"
	end
	if CFG.RequireGroundedState and not GROUNDED_STATES[hum:GetState()] then
		return nil, "estado no estable"
	end
	if math.abs(root.AssemblyLinearVelocity.Y) > CFG.MaxVerticalSpeed then
		return nil, "moviéndose en vertical"
	end
	setFilter(char)
	local res = groundBelow(root.Position, 0.5, CFG.GroundRayLength)
	local why = floorProblem(res)
	if why then
		return nil, why
	end
	return res
end

-- Revalida un checkpoint YA guardado justo antes de volver (el mapa pudo cambiar).
function Safety.validateEntry(entry, char)
	local pos = entry.cf.Position
	if pos.Y < Workspace.FallenPartsDestroyHeight + CFG.MinHeightAboveVoid then
		return false, "cerca del vacío"
	end
	setFilter(char)
	if not entry.swim then
		local res = groundBelow(pos, 1.5, CFG.GroundRayLength + CFG.ReturnLift)
		local why = floorProblem(res)
		if why then
			return false, why
		end
		if entry.floorY and math.abs(res.Position.Y - entry.floorY) > CFG.FloorHeightTolerance then
			return false, "el suelo cambió de altura"
		end
		local target = pos + Vector3.new(0, CFG.ReturnLift, 0)
		local ok, parts = pcall(function()
			return Workspace:GetPartBoundsInBox(CFrame.new(target), Vector3.new(1.6, 3, 1.6), overlapParams)
		end)
		if ok and #parts > 0 then
			return false, "zona obstruida"
		end
	end
	return true
end

-- Primer checkpoint válido de la lista (ya ordenada), saltando los que fallaron.
function Safety.resolve(list, char, avoid, failed)
	if not CFG.SafeCheckpoints then
		for _, e in ipairs(list) do
			if not failed[e] then
				return e
			end
		end
		return nil
	end
	local checks, bad = 0, {}
	for _, e in ipairs(list) do
		if not failed[e] then
			local p = e.cf.Position
			local skip = avoid ~= nil and (p - avoid).Magnitude < CFG.LoopAvoidRadius
			if not skip then
				for _, b in ipairs(bad) do
					if (p - b).Magnitude < 3 then
						skip = true
						break
					end
				end
			end
			if not skip then
				if checks >= CFG.MaxValidationsPerRestore then
					break
				end
				checks += 1
				local ok, why = Safety.validateEntry(e, char)
				if ok then
					return e
				end
				bad[#bad + 1] = p
				Checkpoints.markFailed(e)
				dbg("checkpoint descartado:", why)
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- CHECKPOINTS
--------------------------------------------------------------------------------
function Checkpoints.reset()
	table.clear(Checkpoints.history)
end

function Checkpoints.clearAll()
	table.clear(Checkpoints.history)
	table.clear(Checkpoints.anchors)
end

local function pushEntry(cf, camCF, hum)
	local h = Checkpoints.history
	local entry = {
		t = os.clock(),
		cf = cf,
		cam = camCF,
		health = hum and hum.Health or 0,
		walkSpeed = hum and hum.WalkSpeed or 16,
	}
	h[#h + 1] = entry
	local now = os.clock()
	local keep = CFG.RewindSeconds + CFG.HistoryExtra
	while #h > 2 and now - h[2].t >= keep do
		table.remove(h, 1)
	end
	while #h > 600 do
		table.remove(h, 1)
	end
	return entry
end

-- Los "anclas" son checkpoints en suelo anclado donde estuviste parado varios
-- segundos: sirven de respaldo si los más recientes dejan de ser seguros.
function Checkpoints.considerAnchor(entry, now)
	if entry.swim or not entry.floor or entry.stand < CFG.AnchorStandTime then
		return
	end
	if not isAnchored(entry.floor) then
		return
	end
	local list = Checkpoints.anchors
	local last = list[#list]
	if last and ((entry.cf.Position - last.cf.Position).Magnitude < CFG.AnchorMinSpacing or now - last.t < CFG.AnchorMinInterval) then
		return
	end
	entry.anchor = true
	list[#list + 1] = entry
	while #list > CFG.MaxAnchors do
		table.remove(list, 1)
	end
end

function Checkpoints.markFailed(e)
	e.fails = (e.fails or 0) + 1
	if e.anchor and e.fails >= 2 then
		for i, a in ipairs(Checkpoints.anchors) do
			if a == e then
				table.remove(Checkpoints.anchors, i)
				break
			end
		end
	end
end

-- Guarda un checkpoint si las condiciones son seguras.
function Checkpoints.record(hum, root)
	if not hum or not root or hum.Health <= 0 then
		return false
	end
	local now = os.clock()
	if root.Position.Y < Workspace.FallenPartsDestroyHeight + CFG.MinHeightAboveVoid then
		Safety.resetTrack()
		return false
	end
	local cam = Workspace.CurrentCamera
	local camCF = cam and cam.CFrame or nil

	if not CFG.SafeCheckpoints then
		-- modo clásico (comportamiento original)
		if CFG.SaveOnlyWhenGrounded and hum.FloorMaterial == Enum.Material.Air then
			if hum:GetState() ~= Enum.HumanoidStateType.Swimming then
				return false
			end
		end
		pushEntry(root.CFrame, camCF, hum)
		return true
	end

	local swim = CFG.AllowSwimmingCheckpoints and hum:GetState() == Enum.HumanoidStateType.Swimming
	local floorPart, floorY = nil, nil
	if swim then
		Safety.resetTrack()
	else
		local res = Safety.sampleFloor(root.Parent, hum, root)
		if not res then
			Safety.resetTrack()
			return false
		end
		local part = res.Instance
		local isTerrain = part:IsA("Terrain")
		local transp = isTerrain and 0 or part.Transparency
		local pos = isTerrain and Vector3.zero or part.Position
		local same = track.part == part
		local moved = same and (pos - track.pos).Magnitude or 0
		local fading = same and (transp - track.transp) > 0.02
		if not same or fading or (moved > CFG.MaxFloorMove and not CFG.AllowMovingFloors) then
			track.since = now
		end
		track.part, track.pos, track.transp = part, pos, transp
		if now - track.since < CFG.MinStandTime then
			return false -- aún no sabemos si el suelo es estable
		end
		floorPart, floorY = part, res.Position.Y
	end

	local entry = pushEntry(root.CFrame, camCF, hum)
	entry.floor, entry.floorY, entry.swim = floorPart, floorY, swim
	entry.stand = swim and 0 or (now - track.since)
	Checkpoints.considerAnchor(entry, now)
	return true
end

-- Fija un checkpoint nuevo (limpia el historial): se usa tras volver.
function Checkpoints.set(cf, camCF, hum, info)
	Checkpoints.reset()
	local e = pushEntry(cf, camCF, hum)
	if info then
		e.floor, e.floorY, e.swim = info.floor, info.floorY, info.swim
	end
	return e
end

-- Elige el checkpoint con al menos RewindSeconds de antigüedad (o el más viejo).
function Checkpoints.pick(now)
	local h = Checkpoints.history
	if #h == 0 then
		return nil
	end
	if CFG.RewindSeconds <= 0 then
		return h[#h]
	end
	for i = #h, 1, -1 do
		if now - h[i].t >= CFG.RewindSeconds then
			return h[i]
		end
	end
	return h[1]
end

-- Lista ordenada de candidatos: el elegido y los anteriores del historial, y
-- después los anclas (del más reciente al más antiguo).
function Checkpoints.candidates(now)
	local out = {}
	local h = Checkpoints.history
	if #h > 0 then
		local start = 1
		if CFG.RewindSeconds <= 0 then
			start = #h
		else
			for i = #h, 1, -1 do
				if now - h[i].t >= CFG.RewindSeconds then
					start = i
					break
				end
			end
		end
		for i = start, 1, -1 do
			out[#out + 1] = h[i]
		end
	end
	local a = Checkpoints.anchors
	for i = #a, 1, -1 do
		local e, dup = a[i], false
		for _, o in ipairs(out) do
			if o == e then
				dup = true
				break
			end
		end
		if not dup then
			out[#out + 1] = e
		end
	end
	return out
end

--------------------------------------------------------------------------------
-- ANTI-BUCLE: muertes consecutivas en poco tiempo
--------------------------------------------------------------------------------
local Loop = { times = {}, lastReturnPos = nil }

function Loop.register(now)
	local t = Loop.times
	t[#t + 1] = now
	while #t > 0 and now - t[1] > CFG.LoopWindow do
		table.remove(t, 1)
	end
	return #t
end

function Loop.reset()
	table.clear(Loop.times)
	Loop.lastReturnPos = nil
end

--------------------------------------------------------------------------------
-- EFECTOS VISUALES (solo GUI + Lighting; todo se destruye al terminar cada ciclo)
--------------------------------------------------------------------------------
local TITLE_FONT = Enum.Font.Fondamento
pcall(function()
	TITLE_FONT = Enum.Font.GrenzeGotisch
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ReturnByDeath_" .. tostring(rng:NextInteger(1000, 9999))
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	gui.OnTopOfCoreBlur = true
end)

local function mountGui(g)
	local okHui, hui = pcall(function()
		return gethui()
	end)
	if okHui and typeof(hui) == "Instance" then
		if pcall(function()
			g.Parent = hui
		end) and g.Parent == hui then
			return "gethui"
		end
	end
	local okCore, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if okCore and core then
		if pcall(function()
			g.Parent = core
		end) and g.Parent == core then
			return "CoreGui"
		end
	end
	g.Parent = player:WaitForChild("PlayerGui", 10)
	return "PlayerGui"
end
dbg("GUI montada en", mountGui(gui))

local FX = { cycle = nil }

local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tw(c, obj, time, props, style, dir, delay)
	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Sine,
		dir or Enum.EasingDirection.InOut,
		0,
		false,
		delay or 0
	)
	local t = TweenService:Create(obj, info, props)
	c.tweens[#c.tweens + 1] = t
	t:Play()
	return t
end

-- registra un objeto en un grupo para mostrarlo / ocultarlo en bloque
local function addFade(c, group, obj, prop, shown)
	obj[prop] = 1
	c.groups[group] = c.groups[group] or {}
	local g = c.groups[group]
	g[#g + 1] = { obj = obj, prop = prop, shown = shown }
end

local function showGroup(c, group, delay, time)
	for _, e in ipairs(c.groups[group] or {}) do
		tw(c, e.obj, time, { [e.prop] = e.shown }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, delay)
	end
end

local function hideGroup(c, group, delay, time)
	for _, e in ipairs(c.groups[group] or {}) do
		tw(c, e.obj, time, { [e.prop] = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, delay)
	end
end

function FX.destroyCycle()
	local c = FX.cycle
	if not c then
		return
	end
	FX.cycle = nil
	for _, t in ipairs(c.tweens) do
		pcall(function()
			t:Cancel()
		end)
	end
	for _, cn in ipairs(c.conns) do
		pcall(function()
			cn:Disconnect()
		end)
	end
	for _, o in ipairs(c.objs) do
		pcall(function()
			o:Destroy()
		end)
	end
	local cam = Workspace.CurrentCamera
	if cam and c.baseFov then
		pcall(function()
			cam.FieldOfView = c.baseFov
		end)
	end
end

local function buildVignette(c)
	-- cuatro bordes oscuros con degradado: crecen hacia el centro
	local defs = {
		{ anchor = Vector2.new(0, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0, hidden = UDim2.new(0, 0, 1, 0), shown = UDim2.new(0.42, 0, 1, 0) },
		{ anchor = Vector2.new(1, 0), pos = UDim2.new(1, 0, 0, 0), rot = 180, hidden = UDim2.new(0, 0, 1, 0), shown = UDim2.new(0.42, 0, 1, 0) },
		{ anchor = Vector2.new(0, 0), pos = UDim2.new(0, 0, 0, 0), rot = 90, hidden = UDim2.new(1, 0, 0, 0), shown = UDim2.new(1, 0, 0.5, 0) },
		{ anchor = Vector2.new(0, 1), pos = UDim2.new(0, 0, 1, 0), rot = 270, hidden = UDim2.new(1, 0, 0, 0), shown = UDim2.new(1, 0, 0.5, 0) },
	}
	c.vignette = {}
	for _, d in ipairs(defs) do
		local f = make("Frame", {
			Name = "Vignette",
			AnchorPoint = d.anchor,
			Position = d.pos,
			Size = d.hidden,
			BackgroundColor3 = Color3.fromRGB(10, 0, 22),
			BorderSizePixel = 0,
			ZIndex = 3,
		}, c.root)
		make("UIGradient", {
			Rotation = d.rot,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.55, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, f)
		c.vignette[#c.vignette + 1] = { frame = f, hidden = d.hidden, shown = d.shown }
	end
end

local function buildShadows(c)
	-- "manos" de sombra negras con borde morado que invaden desde los bordes
	local counts = { 8, 14, 22 }
	local n = counts[math.clamp(CFG.Quality, 1, 3)]
	c.shadows = {}
	for i = 1, n do
		local edge = (i - 1) % 4
		local thick = rng:NextInteger(14, 44)
		local along = rng:NextNumber(0.04, 0.96)
		local len = rng:NextNumber(0.28, 0.62)
		local f = make("Frame", {
			Name = "Shadow",
			BackgroundColor3 = CFG.ShadowColor,
			BorderSizePixel = 0,
			Rotation = rng:NextNumber(-24, 24),
			ZIndex = 4,
		}, c.root)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		make("UIStroke", {
			Color = CFG.GlowColor,
			Thickness = 1.5,
			Transparency = 0.35,
		}, f)
		local hidden, shown
		if edge == 0 then -- izquierda
			f.AnchorPoint = Vector2.new(0, 0.5)
			f.Position = UDim2.new(0, -4, along, 0)
			hidden = UDim2.new(0, 0, 0, thick)
			shown = UDim2.new(len, 0, 0, thick)
		elseif edge == 1 then -- derecha
			f.AnchorPoint = Vector2.new(1, 0.5)
			f.Position = UDim2.new(1, 4, along, 0)
			hidden = UDim2.new(0, 0, 0, thick)
			shown = UDim2.new(len, 0, 0, thick)
		elseif edge == 2 then -- arriba
			f.AnchorPoint = Vector2.new(0.5, 0)
			f.Position = UDim2.new(along, 0, 0, -4)
			hidden = UDim2.new(0, thick, 0, 0)
			shown = UDim2.new(0, thick, len, 0)
		else -- abajo
			f.AnchorPoint = Vector2.new(0.5, 1)
			f.Position = UDim2.new(along, 0, 1, 4)
			hidden = UDim2.new(0, thick, 0, 0)
			shown = UDim2.new(0, thick, len, 0)
		end
		f.Size = hidden
		c.shadows[#c.shadows + 1] = { frame = f, hidden = hidden, shown = shown }
	end
end

local function buildTitle(c)
	local holder = make("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.38, 0),
		Size = UDim2.new(0.9, 0, 0.2, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, c.root)
	c.titleScale = make("UIScale", { Scale = 1.2 }, holder)

	local function label(color, maxSize, z, shownTransparency, strokeThickness, strokeShown)
		local l = make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = CFG.Text,
			Font = TITLE_FONT,
			TextScaled = true,
			TextColor3 = color,
			ZIndex = z,
		}, holder)
		make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 12 }, l)
		addFade(c, "title", l, "TextTransparency", shownTransparency)
		local stroke = make("UIStroke", {
			Color = CFG.GlowColor,
			Thickness = strokeThickness,
		}, l)
		addFade(c, "title", stroke, "Transparency", strokeShown)
		return l, stroke
	end

	-- resplandor violeta: capas de texto detrás del principal
	local g2, s2 = label(CFG.GlowColor, 98, 10, 0.78, 9, 0.8)
	local g1, s1 = label(CFG.GlowColor, 90, 11, 0.62, 5, 0.6)
	label(CFG.TextColor, 80, 12, 0, 2, 0.25)
	c.glowLabels = { g1, g2 }
	c.glowStrokes = { s1, s2 }
end

local function buildClock(c)
	local clock = make("Frame", {
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.66, 0),
		Size = UDim2.new(0, 74, 0, 74),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, c.root)
	local ring = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, clock)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	local ringStroke = make("UIStroke", { Color = CFG.GlowColor, Thickness = 2 }, ring)
	addFade(c, "clock", ringStroke, "Transparency", 0.2)

	local function hand(length, width)
		local pivot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 11,
		}, clock)
		local bar = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5 - length, 0),
			Size = UDim2.new(0, width, length, 0),
			BackgroundColor3 = CFG.TextColor,
			BorderSizePixel = 0,
			ZIndex = 11,
		}, pivot)
		addFade(c, "clock", bar, "BackgroundTransparency", 0.1)
		return pivot
	end
	c.minuteHand = hand(0.42, 2)
	c.hourHand = hand(0.28, 3)
end

local function buildSubtitle(c)
	c.sub = make("TextLabel", {
		Name = "Counter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.80, 0),
		Size = UDim2.new(0.8, 0, 0, 26),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Code,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(200, 170, 255),
		ZIndex = 12,
	}, c.root)
	addFade(c, "sub", c.sub, "TextTransparency", 0.1)
end

local function buildGlitch(c)
	c.bars = {}
	if CFG.Quality < 2 then
		return
	end
	for i = 1, 5 do
		local b = make("Frame", {
			BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(120, 255, 255) or CFG.GlowColor,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0.3, 0, 0, 3),
			ZIndex = 13,
		}, c.root)
		c.bars[#c.bars + 1] = b
	end
end

--------------------------------------------------------------------------------
-- MANOS DE SOMBRA (cada imagen es un ImageLabel independiente dentro del ciclo)
-- Todo vive dentro de c.root: se destruye con FX.destroyCycle(), sin acumularse.
--------------------------------------------------------------------------------
-- posiciones en escala de pantalla (centro de la mano): fuera / asoma / cerca del centro
local HAND_EDGES = {
	bottom = { hidden = Vector2.new(0.62, 1.5), peek = Vector2.new(0.62, 0.95), deep = Vector2.new(0.55, 0.66), rot = { -10, -4, 3 } },
	top = { hidden = Vector2.new(0.36, -0.5), peek = Vector2.new(0.36, 0.05), deep = Vector2.new(0.45, 0.34), rot = { 10, 4, -3 } },
	left = { hidden = Vector2.new(-0.45, 0.6), peek = Vector2.new(0.05, 0.6), deep = Vector2.new(0.2, 0.55), rot = { -8, -3, 3 } },
	right = { hidden = Vector2.new(1.45, 0.28), peek = Vector2.new(0.95, 0.28), deep = Vector2.new(0.8, 0.33), rot = { 8, 3, -3 } },
}

local function assetUrl(id)
	id = tostring(id)
	if id:find("^rbxassetid://") or id:find("^http") then
		return id
	end
	return "rbxassetid://" .. id
end

local function buildHands(c)
	c.hands = {}
	c.handsFading = false
	if not CFG.HandsEnabled then
		return
	end
	local function size(mult)
		return UDim2.new(CFG.HandScale * CFG.HandAspect * mult, 0, CFG.HandScale * mult, 0)
	end
	for i, def in ipairs(CFG.HandImages) do
		local e = HAND_EDGES[def.edge]
		if e and def.id and tostring(def.id) ~= "" then
			local img = make("ImageLabel", {
				Name = "Hand" .. i,
				AnchorPoint = Vector2.new(0.5, 0.5),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Size = size(0.85),
				Position = UDim2.fromScale(e.hidden.X, e.hidden.Y),
				Rotation = e.rot[1],
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = assetUrl(def.id),
				ImageColor3 = CFG.HandImageColor,
				ImageTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 5, -- sobre las sombras (4), bajo el título (10+)
			}, c.root)
			c.hands[#c.hands + 1] = { img = img, e = e, size0 = size(0.85), size1 = size(1), size2 = size(1.15) }
		end
	end
end

-- Las manos asoman desde su borde y después avanzan despacio hacia el centro.
local function startHands(c)
	for i, h in ipairs(c.hands or {}) do
		local e = h.e
		local t1 = tw(c, h.img, CFG.HandEmergeTime, {
			Position = UDim2.fromScale(e.peek.X, e.peek.Y),
			Rotation = e.rot[2],
			Size = h.size1,
			ImageTransparency = CFG.HandShownTransparency,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, CFG.HandStartDelay + (i - 1) * CFG.HandStagger)
		-- fase 2 encadenada (una sola vez por mano; no hay bucles que se solapen)
		c.conns[#c.conns + 1] = t1.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and FX.cycle == c and not c.handsFading then
				tw(c, h.img, CFG.HandCreepTime, {
					Position = UDim2.fromScale(e.deep.X, e.deep.Y),
					Rotation = e.rot[3],
					Size = h.size2,
				}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			end
		end)
	end
end

-- Desvanece las manos (se llama al empezar el rewind; es idempotente).
local function fadeHands(c, dur)
	if not c.hands or c.handsFading then
		return
	end
	c.handsFading = true
	for _, h in ipairs(c.hands) do
		tw(c, h.img, dur, {
			Position = UDim2.fromScale(h.e.peek.X, h.e.peek.Y),
			Size = h.size1,
			ImageTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

-- Precarga las imágenes una vez al ejecutar, para que no aparezcan en blanco.
local function preloadHands()
	if not CFG.HandsEnabled then
		return
	end
	task.spawn(function()
		local list = {}
		for _, def in ipairs(CFG.HandImages) do
			local l = Instance.new("ImageLabel")
			l.Image = assetUrl(def.id)
			list[#list + 1] = l
		end
		pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId, status)
				if status ~= Enum.AssetFetchStatus.Success then
					warn("[RETURN BY DEATH] La imagen de la mano no cargó: " .. tostring(contentId) .. " (ID incorrecto, no es de tipo Imagen o sin permiso)")
				end
			end)
		end)
		for _, l in ipairs(list) do
			l:Destroy()
		end
	end)
end

function FX.begin()
	FX.destroyCycle()
	local cam = Workspace.CurrentCamera
	local c = {
		tweens = {},
		conns = {},
		objs = {},
		groups = {},
		baseFov = cam and cam.FieldOfView or 70,
		minuteSpeed = -40,
		hourSpeed = -6,
		minuteAngle = 0,
		hourAngle = 0,
		rewind = nil,
		glitch = false,
	}
	FX.cycle = c

	c.root = make("Frame", {
		Name = "Cycle",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = false,
		ZIndex = 1,
	}, gui)
	c.objs[#c.objs + 1] = c.root

	c.blur = make("BlurEffect", { Name = "RBD_Blur", Size = 0 }, Lighting)
	c.cc = make("ColorCorrectionEffect", { Name = "RBD_CC" }, Lighting)
	c.objs[#c.objs + 1] = c.blur
	c.objs[#c.objs + 1] = c.cc

	c.black = make("Frame", {
		Name = "Black",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, c.root)

	buildVignette(c)
	buildShadows(c)
	buildHands(c)
	buildTitle(c)
	buildClock(c)
	buildSubtitle(c)
	buildGlitch(c)

	-- un solo Heartbeat por ciclo: reloj, contador y glitch
	local acc = 0
	c.conns[#c.conns + 1] = RunService.Heartbeat:Connect(function(dt)
		c.minuteAngle = (c.minuteAngle + c.minuteSpeed * dt) % 360
		c.hourAngle = (c.hourAngle + c.hourSpeed * dt) % 360
		if c.minuteHand then
			c.minuteHand.Rotation = c.minuteAngle
			c.hourHand.Rotation = c.hourAngle
		end
		local rw = c.rewind
		if rw and c.sub then
			local p = math.clamp((os.clock() - rw.t0) / rw.dur, 0, 1)
			c.sub.Text = string.format("<< REWINDING  -%04.1fs", rw.age * p)
		end
		if c.glitch then
			acc += dt
			if acc >= 0.05 then
				acc = 0
				for _, b in ipairs(c.bars) do
					if rng:NextNumber() < 0.7 then
						b.BackgroundTransparency = rng:NextNumber(0.35, 0.8)
						b.Size = UDim2.new(rng:NextNumber(0.08, 0.5), 0, 0, rng:NextInteger(2, 6))
						b.Position = UDim2.new(rng:NextNumber(0, 0.6), 0, rng:NextNumber(0, 1), 0)
					else
						b.BackgroundTransparency = 1
					end
				end
			end
		end
	end)
	return c
end

-- Secuencia de muerte: negro, desenfoque, sombras que invaden, texto, reloj
function FX.playDeath()
	local c = FX.cycle
	if not c then
		return
	end
	local blurMax = ({ 10, 16, 20 })[math.clamp(CFG.Quality, 1, 3)]

	tw(c, c.black, 1.6, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw(c, c.blur, 1.4, { Size = blurMax })
	tw(c, c.cc, 1.4, {
		TintColor = Color3.fromRGB(190, 150, 255),
		Saturation = -0.55,
		Contrast = 0.25,
		Brightness = -0.08,
	})
	local cam = Workspace.CurrentCamera
	if cam then
		tw(c, cam, 1.3, { FieldOfView = c.baseFov + 10 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	for _, v in ipairs(c.vignette) do
		tw(c, v.frame, 1.6, { Size = v.shown }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	for _, s in ipairs(c.shadows) do
		tw(c, s.frame, rng:NextNumber(1.0, 1.7), { Size = s.shown }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.25 + rng:NextNumber(0, 1.1))
	end
	tw(c, c.titleScale, 1.2, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0.9)
	showGroup(c, "title", 0.9, 0.9)
	showGroup(c, "clock", 1.4, 0.6)
	startHands(c)
end

-- Mientras esperas el respawn: el texto y el resplandor "respiran"
function FX.hold()
	local c = FX.cycle
	if not c then
		return
	end
	c.minuteSpeed = -90
	c.hourSpeed = -12
	local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local function pulse(obj, prop, value)
		local t = TweenService:Create(obj, info, { [prop] = value })
		c.tweens[#c.tweens + 1] = t
		c.pulses = c.pulses or {}
		c.pulses[#c.pulses + 1] = t
		t:Play()
	end
	for _, l in ipairs(c.glowLabels) do
		pulse(l, "TextTransparency", 0.88)
	end
	for _, s in ipairs(c.glowStrokes) do
		pulse(s, "Transparency", 0.95)
	end
end

local function stopPulses(c)
	for _, t in ipairs(c.pulses or {}) do
		pcall(function()
			t:Cancel()
		end)
	end
	c.pulses = nil
end

-- "El mundo retrocede": reloj girando al revés, contador y glitch
function FX.playRewind(age, dur)
	local c = FX.cycle
	if not c then
		return
	end
	stopPulses(c)
	c.minuteSpeed = -900
	c.hourSpeed = -110
	c.rewind = { t0 = os.clock(), dur = dur, age = math.max(age, 0) }
	c.glitch = CFG.Quality >= 2
	fadeHands(c, dur * 0.5) -- las manos se desvanecen al empezar el rewind
	showGroup(c, "sub", 0, 0.25)
	local cam = Workspace.CurrentCamera
	if cam then
		tw(c, cam, dur * 0.5, { FieldOfView = c.baseFov - 8 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end

function FX.setSub(text)
	local c = FX.cycle
	if not c or not c.sub then
		return
	end
	c.rewind = nil
	c.sub.Text = text
	showGroup(c, "sub", 0, 0.15)
end

-- Restauración gradual de la imagen
function FX.restore(dur)
	local c = FX.cycle
	if not c then
		return
	end
	stopPulses(c)
	c.glitch = false
	c.rewind = nil
	fadeHands(c, dur * 0.4) -- por si restore se llama sin rewind (no hace nada si ya se desvanecieron)
	c.minuteSpeed = -500
	c.hourSpeed = -60
	for _, b in ipairs(c.bars) do
		b.BackgroundTransparency = 1
	end
	hideGroup(c, "sub", 0, dur * 0.3)
	hideGroup(c, "title", 0, dur * 0.4)
	hideGroup(c, "clock", 0, dur * 0.4)
	tw(c, c.titleScale, dur * 0.5, { Scale = 1.15 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw(c, c.black, dur, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, dur * 0.1)
	tw(c, c.blur, dur, { Size = 0 })
	tw(c, c.cc, dur, {
		TintColor = Color3.new(1, 1, 1),
		Saturation = 0,
		Contrast = 0,
		Brightness = 0,
	})
	for _, v in ipairs(c.vignette) do
		tw(c, v.frame, dur, { Size = v.hidden }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	for _, s in ipairs(c.shadows) do
		tw(c, s.frame, dur * rng:NextNumber(0.6, 1), { Size = s.hidden }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	local cam = Workspace.CurrentCamera
	if cam then
		tw(c, cam, dur, { FieldOfView = c.baseFov })
	end
end

--------------------------------------------------------------------------------
-- AURA DE SATELLA (negra + violeta, acumulativa)
-- Un único aura por personaje: al morir otra vez se ACTUALIZA, no se duplica.
-- El nivel sale del contador `deaths` (muertes de la sesión), que nunca se
-- reinicia al reaparecer ni al limpiar el aura.
--------------------------------------------------------------------------------
local Aura = { char = nil, root = nil, hl = nil, emit = nil, att = {}, light = nil, rings = {}, tw = {}, hiddenNear = false }
local AURA_TAG = "RBD_Aura"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function lerpN(a, b, t)
	return a + (b - a) * t
end

-- factor de rendimiento: calidad elegida y recorte extra en móviles táctiles
local function auraPerf()
	local perf = ({ 0.5, 1, 1.4 })[math.clamp(CFG.Quality, 1, 3)]
	if CFG.AuraAutoLowEnd then
		local ok, mobile = pcall(function()
			return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		end)
		if ok and mobile then
			perf *= CFG.AuraMobileScale
		end
	end
	return perf
end

local function auraTween(key, obj, info, goal)
	local old = Aura.tw[key]
	if old then
		pcall(function()
			old:Cancel()
		end)
	end
	local ok, tween = pcall(function()
		return TweenService:Create(obj, info, goal)
	end)
	if not ok then
		return
	end
	Aura.tw[key] = tween
	tween:Play()
end

local function killInst(o)
	if o then
		pcall(function()
			o:Destroy()
		end)
	end
end

-- borra restos con nuestra etiqueta (de ejecuciones anteriores o huérfanos)
local function sweep(char)
	if not char then
		return
	end
	pcall(function()
		for _, d in ipairs(char:GetDescendants()) do
			if d.Name == AURA_TAG then
				d:Destroy()
			end
		end
	end)
end

-- Limpieza segura: NO toca el contador de muertes.
function Aura.destroy()
	for _, t in pairs(Aura.tw) do
		pcall(function()
			t:Cancel()
		end)
	end
	Aura.tw = {}
	killInst(Aura.hl)
	killInst(Aura.light)
	if Aura.emit then
		for _, e in pairs(Aura.emit) do
			killInst(e)
		end
	end
	for _, a in ipairs(Aura.att) do
		killInst(a)
	end
	for _, r in ipairs(Aura.rings) do
		killInst(r.part)
	end
	sweep(Aura.char)
	Aura.char, Aura.root, Aura.hl, Aura.emit, Aura.light = nil, nil, nil, nil, nil
	Aura.att = {}
	Aura.rings = {}
	Aura.hiddenNear = false
end

function Aura.valid()
	local a = Aura
	if not a.char or not a.root or not a.emit then
		return false
	end
	if not a.char.Parent or not a.root.Parent then
		return false
	end
	-- el Highlight puede no existir (límite del motor): no se exige para evitar reconstruir en bucle
	if a.hl and a.hl.Parent ~= a.char then
		return false
	end
	for _, e in pairs(a.emit) do
		if not e.Parent or not e:IsDescendantOf(a.char) then
			return false
		end
	end
	return true
end

local function newAttachment(root, y)
	local a = Instance.new("Attachment")
	a.Name = AURA_TAG
	a.Position = Vector3.new(0, y, 0)
	a.Parent = root
	Aura.att[#Aura.att + 1] = a
	return a
end

local function newEmitter(parent, tex, colors, lightEmission, life, speed, accel)
	local e = Instance.new("ParticleEmitter")
	e.Name = AURA_TAG
	e.Texture = tex
	e.Color = colors
	e.LightEmission = lightEmission
	e.Rate = 0
	e.Lifetime = NumberRange.new(life * 0.7, life * 1.3)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Acceleration = accel
	e.Parent = parent
	return e
end

-- onda de energía: un aro violeta que se expande por el suelo y se desvanece
local function newRing()
	local char, root = Aura.char, Aura.root
	local part = Instance.new("Part")
	part.Name = AURA_TAG
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1.5, 0.05, 1.5)
	part.CFrame = root.CFrame * CFrame.new(0, -2.9, 0)
	part.Parent = char
	local weld = Instance.new("WeldConstraint")
	weld.Name = AURA_TAG
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	local sg = Instance.new("SurfaceGui")
	sg.Name = AURA_TAG
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(256, 256)
	sg.LightInfluence = 0
	sg.AlwaysOnTop = false
	sg.Adornee = part
	sg.Parent = part
	local fr = Instance.new("Frame")
	fr.BackgroundTransparency = 1
	fr.BorderSizePixel = 0
	fr.Size = UDim2.new(1, 0, 1, 0)
	fr.Parent = sg
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = fr
	local stroke = Instance.new("UIStroke")
	stroke.Color = CFG.AuraColor
	stroke.Thickness = 8
	stroke.Transparency = 1
	stroke.Parent = fr
	return { part = part, stroke = stroke, gui = sg, started = false }
end

local function buildAura(char, root)
	sweep(char)
	Aura.char, Aura.root = char, root
	Aura.att = {}
	Aura.rings = {}
	Aura.tw = {}
	Aura.hiddenNear = false

	pcall(function()
		local hl = Instance.new("Highlight")
		hl.Name = AURA_TAG
		hl.Adornee = char
		hl.FillColor = CFG.AuraDarkColor
		hl.OutlineColor = CFG.AuraColor
		hl.FillTransparency = 1
		hl.OutlineTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = char
		Aura.hl = hl
	end)

	Aura.emit = {}
	pcall(function()
		local upper = newAttachment(root, 1.2)
		local lower = newAttachment(root, -1.8)
		-- humo negro denso desde el torso
		Aura.emit.smoke = newEmitter(root, SMOKE_TEX, ColorSequence.new(CFG.AuraDarkColor), 0, 1.5, 4, Vector3.new(0, 3, 0))
		-- volutas violetas desde la parte alta del cuerpo
		Aura.emit.wisp = newEmitter(
			upper,
			SMOKE_TEX,
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, CFG.AuraColor),
				ColorSequenceKeypoint.new(1, CFG.AuraDeepColor),
			}),
			0.9,
			1.2,
			3.5,
			Vector3.new(0, 4, 0)
		)
		-- chispas violetas pequeñas desde los pies, suben en espiral
		if CFG.AuraSparks then
			Aura.emit.spark = newEmitter(lower, SPARK_TEX, ColorSequence.new(CFG.AuraColor), 1, 1.1, 5, Vector3.new(0, 7, 0))
		end
		if CFG.AuraLight then
			local pl = Instance.new("PointLight")
			pl.Name = AURA_TAG
			pl.Color = CFG.AuraColor
			pl.Shadows = false
			pl.Parent = root
			Aura.light = pl
		end
	end)
end

-- aplica/actualiza los valores según el nivel (sin recrear nada)
function Aura.apply(level)
	local t = math.clamp(level / math.max(CFG.AuraMaxLevel, 1), 0, 1)
	local I = math.clamp(CFG.AuraMaxIntensity, 0, 1)
	local S = math.max(CFG.AuraMaxSizeScale, 0.1)
	local perf = auraPerf()
	local function tr(base) -- la intensidad máxima configurable escala la opacidad
		return 1 - (1 - base) * I
	end

	-- tasas de partículas con tope duro (anti-lag en Android)
	local rs = (8 + 46 * t) * perf
	local rw = (5 + 34 * t) * perf
	local rk = CFG.AuraSparks and (2 + 22 * t) * perf or 0
	local total = rs + rw + rk
	local cap = math.max(CFG.AuraMaxParticleRate, 1)
	if total > cap then
		local f = cap / total
		rs, rw, rk = rs * f, rw * f, rk * f
	end

	local e = Aura.emit or {}
	if e.smoke then
		local size = lerpN(2, 5.5, t) * S
		e.smoke.Rate = rs
		e.smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) })
		e.smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, tr(0.35)), NumberSequenceKeypoint.new(1, 1) })
	end
	if e.wisp then
		local size = lerpN(1.2, 3.2, t) * S
		e.wisp.Rate = rw
		e.wisp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size) })
		e.wisp.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, tr(0.45)), NumberSequenceKeypoint.new(1, 1) })
	end
	if e.spark then
		local size = lerpN(0.18, 0.4, t) * S
		e.spark.Rate = rk
		e.spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.3) })
		e.spark.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, tr(0.1)), NumberSequenceKeypoint.new(1, 1) })
	end

	-- silueta negra con borde morado (se va llenando con cada muerte)
	if Aura.hl and Aura.hl.Parent then
		auraTween("hl", Aura.hl, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			FillTransparency = tr(lerpN(0.92, 0.5, t)),
			OutlineTransparency = tr(lerpN(0.6, 0.08, t)),
		})
	end

	-- luz que "respira" (latido de la influencia de la Bruja)
	if Aura.light and Aura.light.Parent then
		local b = lerpN(0.5, 3, t) * I
		local r = lerpN(8, 22, t) * math.min(S, 1.5)
		Aura.light.Brightness = b
		Aura.light.Range = r
		auraTween("light", Aura.light, TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Brightness = b * 1.5,
			Range = r * 1.2,
		})
	end

	-- ondas de energía en el suelo (más aros con más muertes, con tope)
	if CFG.AuraWaves then
		local qualityCap = ({ 1, 2, 3 })[math.clamp(CFG.Quality, 1, 3)]
		local want = math.clamp(1 + math.floor(t * 2 + 0.5), 1, math.max(1, math.min(CFG.AuraMaxRings, qualityCap)))
		while #Aura.rings < want do
			local ok, ring = pcall(newRing)
			if not ok or not ring then
				break
			end
			Aura.rings[#Aura.rings + 1] = ring
		end
		local R = lerpN(6, 12, t) * S
		local dur = 1.9
		for i, ring in ipairs(Aura.rings) do
			if ring.part.Parent then
				ring.stroke.Transparency = tr(0.2)
				local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
				local function go()
					if not ring.part.Parent then
						return
					end
					auraTween("rs" .. i, ring.part, info, { Size = Vector3.new(R, 0.05, R) })
					auraTween("rt" .. i, ring.stroke, info, { Transparency = 1 })
				end
				if ring.started then
					go()
				else
					ring.started = true
					task.delay((i - 1) * dur / #Aura.rings, function()
						pcall(go)
					end)
				end
			end
		end
	end
	dbg("aura nivel", level, "/", CFG.AuraMaxLevel)
end

-- Punto de entrada: crea el aura si no existe (o si es de otro personaje) y
-- si ya existe solo la actualiza al nivel actual.
function Aura.update(char, root, totalDeaths)
	if cleaned or not CFG.AuraEnabled or not char or not root or not root.Parent then
		return
	end
	local level = math.min(totalDeaths, CFG.AuraMaxLevel)
	if level <= 0 then
		return
	end
	if Aura.char ~= char or Aura.root ~= root or not Aura.valid() then
		Aura.destroy()
		buildAura(char, root)
	end
	Aura.apply(level)
end

local function setAuraNear(near)
	Aura.hiddenNear = near
	for _, e in pairs(Aura.emit or {}) do
		e.Enabled = not near
	end
	for _, r in ipairs(Aura.rings) do
		pcall(function()
			r.gui.Enabled = not near
		end)
	end
end

-- Llamado ~2 veces por segundo desde el Heartbeat de checkpoints.
function Aura.tick()
	if cleaned or not CFG.AuraEnabled or deaths <= 0 then
		return
	end
	local char, root = currentChar, currentRoot
	if not char or not root or not char.Parent or not root.Parent then
		return
	end
	if Aura.char ~= char or Aura.root ~= root or not Aura.valid() then
		Aura.update(char, root, deaths) -- alguien borró el aura o cambió el personaje
		return
	end
	-- en primera persona el humo taparía la pantalla: se oculta si la cámara está pegada
	local cam = Workspace.CurrentCamera
	if cam then
		local near = (cam.CFrame.Position - root.Position).Magnitude < CFG.AuraHideCameraDist
		if near ~= Aura.hiddenNear then
			setAuraNear(near)
		end
	end
end

--------------------------------------------------------------------------------
-- SONIDO FINAL (se carga con espera y avisa si Roblox lo bloquea)
--------------------------------------------------------------------------------
local Sfx = {}

function Sfx.preload()
	if not CFG.SoundEnabled then
		return
	end
	task.spawn(function()
		local s = Instance.new("Sound")
		s.SoundId = CFG.RezeroSoundId
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ s })
		end)
		if not ok or s.TimeLength <= 0 then
			warn("[RETURN BY DEATH] El sonido no cargó (id " .. CFG.RezeroSoundId .. "): puede ser privado o sin permiso.")
		end
		s:Destroy()
	end)
end

function Sfx.play()
	if not CFG.SoundEnabled then
		return
	end
	task.spawn(function()
		local s = Instance.new("Sound")
		s.SoundId = CFG.RezeroSoundId
		s.Volume = CFG.SoundVolume
		s.Parent = SoundService
		local t0 = os.clock()
		while not s.IsLoaded and os.clock() - t0 < 5 and not cleaned do
			task.wait(0.1)
		end
		if cleaned or not s.IsLoaded then
			warn("[RETURN BY DEATH] NO cargó el sonido: " .. CFG.RezeroSoundId .. " (privado o sin permiso)")
			s:Destroy()
			return
		end
		s:Play()
		Debris:AddItem(s, math.max(s.TimeLength, 1) + 2)
	end)
end

--------------------------------------------------------------------------------
-- UTILIDADES DEL CICLO
--------------------------------------------------------------------------------
local function waitFor(seconds, alive)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		if not alive() then
			return false
		end
		task.wait(0.05)
	end
	return alive()
end

local function findLiveCharacter()
	local c = player.Character
	if c and c.Parent then
		local h = c:FindFirstChildOfClass("Humanoid")
		local r = c:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 then
			return c, h, r
		end
	end
	return nil
end

local function waitForRespawn(alive)
	local t0 = os.clock()
	while alive() and os.clock() - t0 < CFG.RespawnTimeout do
		local c, h, r = findLiveCharacter()
		if c then
			return c, h, r
		end
		task.wait(0.1)
	end
	return nil
end

-- Mueve al personaje al destino con reintentos y verifica que se aceptó.
local function teleportTo(char, hum, root, targetCF, alive, id)
	for attempt = 1, CFG.ReturnRetries do
		if not alive() or restoreOwner ~= id or not char.Parent or hum.Health <= 0 then
			return false, "cancelado"
		end
		local ok, err = pcall(function()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			char:PivotTo(targetCF)
		end)
		if not ok then
			dbg("error al mover:", err)
		end
		task.wait(CFG.VerifyDelay)
		if root.Parent and (root.Position - targetCF.Position).Magnitude <= CFG.VerifyTolerance then
			return true
		end
		dbg("intento", attempt, "rechazado")
	end
	return false, "posición rechazada"
end

-- Tras volver: comprueba que realmente aterrizaste (no sigues cayendo al vacío).
local function confirmLanding(char, hum, root, swim, alive, id)
	local t0 = os.clock()
	while true do
		if not alive() or restoreOwner ~= id then
			return false, "cancelado"
		end
		if not char.Parent or not root.Parent or hum.Health <= 0 then
			return false, "murió al volver"
		end
		if swim then
			if hum:GetState() == Enum.HumanoidStateType.Swimming or hum.FloorMaterial ~= Enum.Material.Air then
				return true
			end
		elseif hum.FloorMaterial ~= Enum.Material.Air then
			return true
		end
		if root.AssemblyLinearVelocity.Y < -CFG.FallAbortSpeed then
			return false, "cayendo"
		end
		if root.Position.Y < Workspace.FallenPartsDestroyHeight + CFG.MinHeightAboveVoid then
			return false, "cerca del vacío"
		end
		if os.clock() - t0 >= CFG.LandingTimeout then
			return false, "sin suelo al aterrizar"
		end
		task.wait(0.05)
	end
end

local function goToSpawn(char, hum, root, spawnCF, alive, id)
	if not spawnCF or not alive() or restoreOwner ~= id or not char.Parent or hum.Health <= 0 then
		return
	end
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		char:PivotTo(spawnCF)
	end)
	task.wait(0.15)
end

-- Elige un checkpoint VÁLIDO ahora mismo (revalidando el entorno), vuelve a él y
-- confirma el aterrizaje. Si falla, regresa al spawn del juego y prueba el siguiente
-- candidato más antiguo. Devuelve el checkpoint usado, o nil + motivo.
local function returnTo(char, hum, root, candidates, spawnCF, alive, id, avoid)
	local failed = {}
	local tried = 0
	local lastWhy = "sin checkpoint válido"
	while tried < CFG.MaxReturnCandidates do
		if not alive() or restoreOwner ~= id then
			return nil, "cancelado"
		end
		if not char.Parent or hum.Health <= 0 then
			return nil, "cancelado"
		end
		local entry = Safety.resolve(candidates, char, avoid, failed)
		if not entry then
			break
		end
		tried += 1
		local target = entry.cf + Vector3.new(0, CFG.ReturnLift, 0)
		local ok, why = teleportTo(char, hum, root, target, alive, id)
		if ok and CFG.SafeCheckpoints then
			ok, why = confirmLanding(char, hum, root, entry.swim, alive, id)
		end
		if not alive() or restoreOwner ~= id then
			return nil, "cancelado"
		end
		if ok then
			return entry
		end
		lastWhy = why or lastWhy
		failed[entry] = true
		Checkpoints.markFailed(entry)
		dbg("retorno fallido:", why)
		-- evita seguir cayendo: vuelve al punto donde el juego te reapareció
		goToSpawn(char, hum, root, spawnCF, alive, id)
		if not CFG.SafeCheckpoints then
			break
		end
	end
	if tried == 0 then
		return nil, "sin checkpoint válido"
	end
	return nil, lastWhy
end

local function placeCamera(hum, root, cp)
	if not CFG.RestoreCamera or not cp.cam then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	pcall(function()
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
		local offset = cp.cam.Position - cp.cf.Position
		local rotation = cp.cam - cp.cam.Position
		cam.CFrame = CFrame.new(root.Position + offset) * rotation
	end)
end

--------------------------------------------------------------------------------
-- CICLO COMPLETO: muerte -> espera de respawn -> retorno seguro -> nuevo checkpoint
--------------------------------------------------------------------------------
local function runCycle()
	cycleId += 1
	deaths += 1
	if CFG.AuraPersistDeaths then
		env.__RBD_DEATHS = deaths
	end
	local id = cycleId
	restoreOwner = id -- solo el ciclo más reciente puede mover al personaje
	local function alive()
		return not cleaned and cycleId == id
	end

	setState(STATE.DEATH)
	local deathTime = os.clock()
	local recentDeaths = Loop.register(deathTime)
	local candidates = Checkpoints.candidates(deathTime)
	local primary = candidates[1]
	local age = primary and (deathTime - primary.t) or 0

	FX.begin()
	FX.playDeath()
	if not waitFor(CFG.DeathSequenceTime, alive) then
		return
	end

	setState(STATE.WAIT)
	FX.hold()
	local char, hum, root = waitForRespawn(alive)
	if not alive() then
		return
	end
	if not char then
		warn("[RETURN BY DEATH] El juego no te reapareció a tiempo; se cancela el retorno.")
		FX.setSub("NO RESPAWN")
		if not waitFor(0.8, alive) then
			return
		end
		FX.restore(CFG.RestoreTime)
		setState(STATE.ALIVE)
		if waitFor(CFG.RestoreTime + 0.2, alive) then
			FX.destroyCycle()
		end
		return
	end

	setState(STATE.RETURN)

	-- esperar apariencia y a que el juego termine de colocarte
	local t0 = os.clock()
	while alive() and not player:HasAppearanceLoaded() and os.clock() - t0 < CFG.AppearanceTimeout do
		task.wait(0.1)
	end
	if not waitFor(CFG.SettleDelay, alive) then
		return
	end
	if not char.Parent or hum.Health <= 0 then
		return -- murió otra vez: su propio ciclo se encarga
	end

	-- donde el juego te reapareció: alternativa segura si ningún checkpoint sirve
	local spawnCF = root.CFrame

	FX.playRewind(age, CFG.RewindTime)
	if not waitFor(CFG.RewindTime * 0.55, alive) then
		return
	end

	-- aquí la pantalla está negra: se revalida el entorno y se mueve al personaje
	local usedEntry = nil
	if recentDeaths >= CFG.LoopMaxDeaths then
		warn("[RETURN BY DEATH] Bucle de muertes detectado (" .. recentDeaths .. " en " .. CFG.LoopWindow .. "s). Se descartan los checkpoints y sigues en el spawn del juego.")
		Checkpoints.clearAll()
		Loop.reset()
		FX.setSub("LOOP BROKEN")
	elseif #candidates > 0 then
		-- 2.ª muerte seguida: no repetir el mismo punto que acabas de usar
		local avoid = (recentDeaths >= 2) and Loop.lastReturnPos or nil
		local entry, why = returnTo(char, hum, root, candidates, spawnCF, alive, id, avoid)
		if not alive() then
			return
		end
		if entry then
			placeCamera(hum, root, entry)
			usedEntry = entry
			Loop.lastReturnPos = entry.cf.Position
		else
			warn("[RETURN BY DEATH] No se pudo volver a un checkpoint seguro (" .. tostring(why) .. "). Sigues donde reapareciste.")
			FX.setSub(why == "sin checkpoint válido" and "NO SAFE CHECKPOINT" or "RETURN FAILED")
		end
	else
		FX.setSub("NO CHECKPOINT")
	end
	if not waitFor(CFG.RewindTime * 0.45, alive) then
		return
	end

	-- nuevo ciclo: checkpoint en el punto de regreso (o donde estés si falló)
	if char.Parent and hum.Health > 0 then
		Safety.resetTrack()
		if usedEntry then
			Checkpoints.set(usedEntry.cf, usedEntry.cam, hum, usedEntry)
		else
			Checkpoints.reset()
			Checkpoints.record(hum, root)
		end
	end
	if char.Parent and hum.Health > 0 then
		Aura.update(char, root, deaths)
	end
	FX.restore(CFG.RestoreTime)
	setState(STATE.ALIVE)
	if waitFor(CFG.RestoreTime + 0.2, alive) then
		FX.destroyCycle()
		-- la animación terminó: suena el sonido
		if waitFor(CFG.SoundDelay, alive) then
			Sfx.play()
		end
	end
end

local function handleDeath(char)
	if cleaned or not CFG.Enabled then
		return
	end
	if diedHandled[char] then
		return
	end
	local current = player.Character
	if current and current ~= char then
		return -- muerte tardía de un personaje viejo
	end
	diedHandled[char] = true
	if state == STATE.DEATH or state == STATE.WAIT then
		return -- ya hay una secuencia en curso
	end
	task.spawn(runCycle)
end

--------------------------------------------------------------------------------
-- VIGILAR PERSONAJE Y GUARDAR CHECKPOINTS
--------------------------------------------------------------------------------
local function disconnectChar()
	for _, cn in ipairs(charConns) do
		pcall(function()
			cn:Disconnect()
		end)
	end
	table.clear(charConns)
end

local function onCharacter(char)
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 15)
		local root = char:WaitForChild("HumanoidRootPart", 15)
		if cleaned or not hum or not root or player.Character ~= char then
			return
		end
		disconnectChar()
		currentChar, currentHum, currentRoot = char, hum, root
		charConns[#charConns + 1] = hum.Died:Connect(function()
			handleDeath(char)
		end)
		charConns[#charConns + 1] = hum.HealthChanged:Connect(function(h)
			if h <= 0 then
				handleDeath(char)
			end
		end)
		if hum.Health <= 0 then
			handleDeath(char)
		elseif state == STATE.ALIVE then
			Safety.resetTrack()
			Checkpoints.record(hum, root)
			if deaths > 0 then
				Aura.update(char, root, deaths)
			end
		end
	end)
end

local saveAcc = 0
persistent(RunService.Heartbeat:Connect(function(dt)
	if cleaned or not CFG.Enabled or state ~= STATE.ALIVE then
		return
	end
	saveAcc += dt
	if saveAcc < CFG.SaveInterval then
		return
	end
	saveAcc = 0
	local hum, root = currentHum, currentRoot
	if not hum or not root or not hum.Parent or not root.Parent then
		return
	end
	Checkpoints.record(hum, root)
	Aura.tick()
end))

persistent(player.CharacterAdded:Connect(onCharacter))
persistent(player.CharacterRemoving:Connect(function(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		handleDeath(char)
	end
end))
if player.Character then
	onCharacter(player.Character)
end

--------------------------------------------------------------------------------
-- LIMPIEZA TOTAL (al re-ejecutar el script)
--------------------------------------------------------------------------------
env.__RBD_CLEANUP = function()
	cleaned = true
	cycleId += 1
	restoreOwner = -1
	for _, cn in ipairs(persistentConns) do
		pcall(function()
			cn:Disconnect()
		end)
	end
	table.clear(persistentConns)
	disconnectChar()
	FX.destroyCycle()
	Aura.destroy() -- limpia el aura; el contador `deaths` no se toca
	pcall(function()
		gui:Destroy()
	end)
	Checkpoints.clearAll()
	Safety.resetTrack()
	Loop.reset()
	env.__RBD_CLEANUP = nil
end

Sfx.preload()
preloadHands()
print("[RETURN BY DEATH] Activo. Muere para probarlo. Checkpoint cada " .. CFG.SaveInterval .. "s, retroceso de " .. CFG.RewindSeconds .. "s. Checkpoints seguros: " .. tostring(CFG.SafeCheckpoints) .. ".")
