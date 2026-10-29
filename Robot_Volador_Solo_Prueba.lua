--!nonstrict
-- ============================================================
-- ROBOT VOLADOR - SOLITO (LocalScript / Delta) - solo tú lo ves
--
--  * MASCOTA : vuela a tu derecha y te sigue
--  * MONTURA : animación (R6 y R15) para subirte y bajarte; vuelo libre montado
--              (te agarras por detrás del robot, como Morty)
--  * LÁSER   : rayo rojo por el ojo, desde la mascota o montado
--  * DISPARO : un solo botón LÁSER: mantén = rayo seguido | toca varias veces = rayitos sueltos
--  * EQUIPO  : 6 robots (el tuyo + 5) que te rodean en órbita y disparan contigo
--  * ATACAR  : modo metralleta: todos los robots van contra UN objetivo y le disparan
--
-- BOTONES (movibles; el candado 🔓/🔒 los deja fijos): ROBOT, SUBIR/BAJAR, LÁSER, PRUEBA, ATACAR
-- TECLAS: B robot | E subir/bajar | U láser (mantener) | Y traerlo | M seguir/quieto
--         Espacio o salto = subir en vuelo | Ctrl = bajar en vuelo | = y - = tamaño
-- CHAT:   /robot /ocultar /seguir /quieto /aqui /subir /bajar /laser /prueba
--         /tamano N | /rot X Y Z | /ojo X Y Z | /asiento X Y Z | /mano der|izq X Y Z
--         /pierna CADERA ABRIR RODILLA TOBILLO [CERRAR]  (ajusta las piernas montado)
--         /mas /menos /robots N | /atacar
-- NUEVO:  N +robot | H -robot | T atacar (apunta a alguien o toma al jugador más cercano)
--         Botón ATACAR: los robots van SOLOS por un jugador y lo rafaguean con rayitos (con efectos)
--
-- Si re-ejecutas, se limpia la versión anterior.
-- ============================================================

--##########################################################################
-- SERVICIOS
--##########################################################################
local Players = game:GetService("Players")
local jugador = Players.LocalPlayer

--##########################################################################
-- CONFIGURACIÓN  (cambia aquí IDs, teclas y ajustes)
--##########################################################################
local CONFIG = {
	-- ---------- ROBOT (mascota voladora + montura + láser rojo por el ojo) ----------
	ROBOT = {
		-- Assets (los mismos de tu Robot_Seguidor.lua)
		MESH_ID = "96519206806109",
		TEXTURE_ID = "128473324994612",

		-- Tamaño y orientación de la malla
		TAMANO_OBJETIVO = 5,                       -- studs de la dimensión más grande (0 = usar ESCALA tal cual)
		ESCALA = 1,
		ROTACION = Vector3.new(0, 0, 0),           -- corrige hacia dónde mira la malla (chat: /rot X Y Z)
		OFFSET_MALLA = Vector3.new(0, 0, 0),

		-- Puntos del robot, en FRACCIONES de su tamaño (X = lado, Y = arriba, Z = atrás; el frente es -Z)
		OJO = Vector3.new(0, -0.08, -0.25),            -- de dónde sale el láser: el ojo rojo, subido 0.02 = 1 microstud (chat: /ojo X Y Z)
		ASIENTO = Vector3.new(0, 0.1, 0.32),      -- dónde te agarras: DETRÁS del robot (Z+ = atrás) (chat: /asiento X Y Z)
		INCLINAR_CUERPO = 6,                       -- grados que te recuestas hacia el robot
		ESCALA_MONTADO = 1,                        -- el robot crece mientras vas montado (para que te quepa abrazado)
		ALTURA_MONTADO = 2.5,                        -- altura mínima sobre el suelo al ir montado (despega, no vas pisando el piso)
		-- Dónde agarran las manos, en FRACCIONES del tamaño del robot, desde su centro (X+ = derecha del robot, Y+ = arriba)
		GRIP_DER = Vector3.new(0.2, 0.12, 0),      -- tu mano derecha agarra el borde derecho del robot (chat: /mano der X Y Z)
		GRIP_IZQ = Vector3.new(-0.2, 0.12, 0),     -- tu mano izquierda agarra el borde izquierdo del robot (chat: /mano izq X Y Z)

		-- Piernas al ir montado (estilo Evil Morty: muslos al frente abrazando el robot, rodillas dobladas)
		-- Se prueban en vivo con el chat: /pierna CADERA ABRIR RODILLA TOBILLO CERRAR
		PIERNAS = {
			CADERA = 105,    -- grados que sube cada muslo hacia el frente (90 = horizontal, más = rodilla arriba)
			ABRIR = 26,      -- grados que se separa cada pierna hacia afuera (abraza el robot)
			RODILLA = -130,  -- doblez de la rodilla (más negativo = pantorrilla más hacia atrás)
			TOBILLO = -20,   -- punta del pie hacia abajo (solo R15)
			CERRAR = 12,     -- grados que las pantorrillas se cierran hacia adentro (solo R15)
		},

		-- Mascota
		APARECER_AL_INICIO = true,
		MODO_INICIAL = "SEGUIR",                   -- "SEGUIR" | "QUIETO"
		LADO = 7,                                  -- a qué distancia a tu derecha vuela
		ATRAS = 1.5,                               -- cuánto se queda detrás de ti
		ALTURA = 2.5,                              -- altura respecto a tu personaje
		VELOCIDAD = 80,                            -- velocidad máxima al seguirte
		SUAVIDAD = 5,
		TELEPORT_DIST = 150,                       -- si te alejas más, se teletransporta contigo
		FLOTAR_AMP = 0.45,
		FLOTAR_VEL = 1.6,
		INCLINACION = 14,
		ALTURA_MINIMA = 2.5,                       -- no baja más que esto sobre el suelo
		APARECER_SEG = 0.6,

		-- Subir / bajar (animación)
		SUBIR_PREP_SEG = 0.45,                     -- el robot baja a tu lado y se agacha
		SUBIR_SALTO_SEG = 0.7,                     -- tu salto hacia el asiento
		SUBIR_LADO = 4,                            -- a qué distancia a tu derecha se pone para que subas
		SUBIR_ALTURA = 0.5,                        -- altura del asiento respecto a tu cuerpo al subir
		SUBIR_ARCO = 3.5,                          -- qué tan alto es el salto
		BAJAR_SEG = 0.8,
		BAJAR_LADO = 5,
		BAJAR_ARCO = 3,

		-- Vuelo libre (montado)
		VUELO_VELOCIDAD = 70,                      -- studs/s
		VUELO_VERTICAL = 45,                       -- velocidad al subir/bajar con salto / Ctrl
		VUELO_SUAVIDAD = 4,
		INCLINACION_VUELO = 22,

		-- Láser rojo (por el ojo)
		COLOR_LASER = Color3.fromRGB(255, 25, 25),
		ANCHO = 1.0,                               -- grosor del rayo en studs
		ALCANCE = 500,
		DANO = 12,                                 -- vida por golpe (solo en tu pantalla; los NPCs mueren)
		DANO_INTERVALO = 0.1,                      -- segundos entre golpes mientras el rayo toca algo
		CARGA_SEG = 0.2,                           -- el ojo brilla antes de soltar el rayo
		APAGADO_SEG = 0.2,
		MAX_SEG = 4,                               -- máximo disparando seguido
		RECARGA_SEG = 0.8,                         -- espera después de ese máximo
		SONIDO_LASER = "",                         -- ID de sonido en bucle (vacío = sin sonido)
		VOLUMEN = 1,

		-- Equipo de robots (el principal que te montas + seguidores)
		MAX_ROBOTS = 6,                            -- total contando al principal (1 + 5 seguidores)
		ROBOTS_INICIALES = 6,                      -- cuántos salen al ejecutar el script
		EXTRAS_RADIO = 11,                         -- radio de la órbita alrededor de ti
		EXTRAS_ORBITA = 0.35,                      -- velocidad con la que giran alrededor (rad/s)
		EXTRAS_ALTURA = 2.5,                       -- altura sobre tu personaje (a pie)
		EXTRAS_VELOCIDAD = 110,                    -- velocidad máxima de los seguidores
		EXTRAS_SUAVIDAD = 6,
		DISPARAN_JUNTOS = true,                    -- los seguidores disparan cuando tú disparas

		-- Disparo: un toque = rayito | mantener = rayo seguido
		TOQUE_SEG = 0.22,                          -- botón LÁSER: menos que esto = toque (rayito), más = rayo seguido
		COLOR_BALA = Color3.fromRGB(255, 70, 40),
		BALA_VELOCIDAD = 260,                      -- studs por segundo
		BALA_LARGO = 3,
		BALA_ANCHO = 0.35,
		BALA_DANO = 10,
		BALA_CADENCIA = 0.08,                      -- mínimo de segundos entre toques (anti-spam)
		BALA_ALCANCE = 400,
		MAX_BALAS = 160,                           -- tope de rayitos en el aire a la vez

		-- Efectos SOLO de los rayitos (el láser grande no cambia)
		EFECTOS_RAYITOS = true,                    -- estela, fogonazo en el ojo, anillo y chispas al pegar
		EFECTOS_MAX = 70,                          -- tope de partes de efecto vivas a la vez (bájalo si se pone lento)
		TRAIL_SEG = 0.22,                          -- largo de la estela del rayito
		COLOR_BALA_NUCLEO = Color3.fromRGB(255, 235, 210), -- centro caliente del rayito

		-- Modo metralleta / atacar: todos los robots van contra UN objetivo y le disparan
		ATAQUE_ALCANCE = 400,                      -- hasta dónde busca objetivo
		ATAQUE_RADIO = 16,                         -- distancia a la que rodean al objetivo
		ATAQUE_ALTURA = 7,                         -- altura sobre el objetivo
		ATAQUE_GIRO = 0.6,                         -- velocidad con la que dan vueltas alrededor
		ATAQUE_CADENCIA = 0.1,                     -- segundos entre disparos de cada robot
		ATAQUE_DANO = 5,
		ATAQUE_DISPERSION = 1.5,                   -- grados de desvío al azar (metralleta)
		ATAQUE_TAMBIEN_NPC = true,                 -- si no hay jugadores a la vista, va por NPCs
		ATAQUE_AUTO_SIGUIENTE = true,              -- si el objetivo cae, van solitos por el siguiente
		CONVERGER_DESDE = 35,                      -- los seguidores solo apuntan a tu mira si miras algo a más de estos studs de ti; si no, disparan en paralelo (ya no parece que te atacan)

		-- Controles (botones: ROBOT / SUBIR-BAJAR / LÁSER, movibles con el candado abierto)
		TECLA_VISIBLE = Enum.KeyCode.B,
		TECLA_MONTAR = Enum.KeyCode.E,
		TECLA_LASER = Enum.KeyCode.U,              -- mantenerla = disparar
		TECLA_TRAER = Enum.KeyCode.Y,
		TECLA_MODO = Enum.KeyCode.M,
		TECLA_BAJAR_VUELO = Enum.KeyCode.LeftControl,
		TECLA_MAS = Enum.KeyCode.Equals,
		TECLA_MENOS = Enum.KeyCode.Minus,
		TECLA_MAS_ROBOT = Enum.KeyCode.N,          -- agregar un robot
		TECLA_MENOS_ROBOT = Enum.KeyCode.H,        -- quitar un robot
		TECLA_ATACAR = Enum.KeyCode.T,             -- modo metralleta / atacar
		COMANDOS_CHAT = true,
		AVISOS_EN_PANTALLA = true,
	},
}

--##########################################################################
-- AYUDAS (botones movibles, colores, daño y candado)
--##########################################################################
local Shared = {}
Shared.COLORES = {
	ROJO = Color3.fromRGB(200, 20, 30),
	VERDE = Color3.fromRGB(0, 200, 90),
	FONDO = Color3.fromRGB(10, 10, 10),
}
Shared.UI = { cerrado = false }
function Shared.UI.bloqueado()
	return Shared.UI.cerrado == true
end

Shared.HacerMovible = function(boton, alPulsar, con)
	local UIS = game:GetService("UserInputService")
	local arrastrando, movido = false, false
	local inicioInput, posIni

	con(boton.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			movido = false
			inicioInput = input.Position
			posIni = boton.Position
		end
	end)

	con(UIS.InputChanged, function(input)
		if not arrastrando then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - inicioInput
			if d.Magnitude > 8 and not (Shared.UI and Shared.UI.bloqueado()) then
				movido = true
			end
			if movido then
				boton.Position = UDim2.new(
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
				alPulsar()
			end
		end
	end)
end

-- Estilo de la interfaz para los botones CUCHILLO / LANZAR / SIERRA / ESCUDO:
-- fondo negro, forma redondeada, fuente Code y texto con borde del mismo color
-- (verde = activo, rojo = apagado), igual que EMOTES, TODO, MORIR, DASH...
Shared.COLORES = {
	ROJO = Color3.fromRGB(200, 20, 30),
	VERDE = Color3.fromRGB(0, 200, 90),
	FONDO = Color3.fromRGB(10, 10, 10),
}

Shared.PintarBoton = function(boton, color)
	boton.BackgroundColor3 = Shared.COLORES.FONDO
	boton.BorderSizePixel = 0
	boton.Font = Enum.Font.Code
	boton.TextScaled = true
	boton.TextColor3 = color

	local esquina = boton:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(1, 0)
	esquina.Parent = boton

	local borde = boton:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	borde.Color = color
	borde.Thickness = 1
	borde.Parent = boton

	local tope = boton:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	tope.MaxTextSize = 14
	tope.MinTextSize = 6
	tope.Parent = boton

	local pad = boton:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = boton
end


-- Daño local (igual que tus otras armas): los NPCs mueren, a los jugadores se les baja la vida en tu pantalla
Shared.DanarDeParte = function(parte, dano)
	local m = parte
	while m and m ~= workspace do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
			break
		end
		m = m.Parent
	end
	if not m or m == workspace or m == jugador.Character then
		return false
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	if Players:GetPlayerFromCharacter(m) == nil then
		hum.Health = 0
	else
		hum.Health = math.max(0, hum.Health - (dano or 0))
	end
	return true
end

-- Candado (botón chiquito junto a LÁSER)
local function crearCandado()
	local pg = jugador:WaitForChild("PlayerGui")
	local viejo = pg:FindFirstChild("RobotCandadoGui")
	if viejo then
		viejo:Destroy()
	end
	local g = Instance.new("ScreenGui")
	g.Name = "RobotCandadoGui"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = true
	g.DisplayOrder = 100
	g.Parent = pg

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 32, 0, 26)
	b.Position = UDim2.new(0.8121, 0, 0.1918, 0)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.BackgroundColor3 = Color3.fromRGB(16, 70, 56)
	b.Text = "🔓"
	b.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = b
	b.Activated:Connect(function()
		Shared.UI.cerrado = not Shared.UI.cerrado
		b.Text = Shared.UI.cerrado and "🔒" or "🔓"
		b.BackgroundColor3 = Shared.UI.cerrado and Color3.fromRGB(150, 40, 50) or Color3.fromRGB(16, 70, 56)
	end)
end

--##########################################################################
-- MÓDULO: ROBOT (mascota voladora + montura con láser rojo por el ojo)
-- Botones movibles (se arrastran con el candado abierto): ROBOT, SUBIR/BAJAR y LÁSER.
-- Teclas: B robot | E subir/bajar | U láser (mantener) | Y traerlo | M seguir/quieto
--         Espacio o salto = subir en vuelo | Ctrl = bajar en vuelo | = y - = tamaño
-- En vuelo: el joystick / WASD te lleva hacia donde mira la cámara (también sube y baja).
-- Todo se ajusta en CONFIG.ROBOT. Chat: /robot /ocultar /seguir /quieto /aqui /subir
--   /bajar /laser /tamano N /rot X Y Z /ojo X Y Z /asiento X Y Z
--##########################################################################
local function MODULO_ROBOT()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	local UIS = game:GetService("UserInputService")
	local InsertService = game:GetService("InsertService")

	local jugador = Players.LocalPlayer
	local playerGui = jugador:WaitForChild("PlayerGui")

	-- Anti-duplicados (también limpia el Robot_Seguidor.lua suelto si lo ejecutaste antes)
	local env = (getgenv and getgenv()) or _G
	if env.ROBOT_LIMPIAR then
		pcall(env.ROBOT_LIMPIAR)
	end

	local C = CONFIG.ROBOT

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local function suave(x)
		x = math.clamp(x, 0, 1)
		return x * x * (3 - 2 * x)
	end

	-- ===================== CARPETA Y MODELO =====================
	local viejo = Workspace:FindFirstChild("Robot_Entidades")
	if viejo then
		viejo:Destroy()
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Robot_Entidades"
	carpeta.Parent = Workspace

	local carpetaRayos = Instance.new("Folder")
	carpetaRayos.Name = "Rayos"
	carpetaRayos.Parent = carpeta

	local modelo = Instance.new("Model")
	modelo.Name = "Robot"

	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Size = Vector3.one
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz

	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.FileMesh
	malla.MeshId = "rbxassetid://" .. C.MESH_ID
	malla.TextureId = "rbxassetid://" .. C.TEXTURE_ID
	malla.Offset = C.OFFSET_MALLA
	malla.Scale = Vector3.one * 0.001
	malla.Parent = raiz

	-- ===================== ESTADO =====================
	-- fase: "libre" (mascota) | "subiendo" | "montado" | "bajando"
	local estado = { visible = C.APARECER_AL_INICIO, modo = C.MODO_INICIAL, fase = "libre" }
	local ap = 0                       -- 0..1 progreso de aparecer
	local pos = Vector3.zero
	local vel = Vector3.zero
	local yaw = 0
	local sueloY = nil
	local escalaBase = C.ESCALA
	local escalaUser = 1
	local rotOff = C.ROTACION
	local ojoFrac = C.OJO
	local asientoFrac = C.ASIENTO
	local colocado = false
	local t = 0
	local rebote = 0
	local gripDer, gripIzq = C.GRIP_DER, C.GRIP_IZQ
	local velFrac, movW = 0, 0         -- animación al ir montado: velocidad (0..1) y peso del movimiento
	local fMonta = 1                   -- 1 = tamaño normal | ESCALA_MONTADO = tamaño de montura
	local marcoActual = CFrame.new()
	local sub = nil                    -- datos de la secuencia de subir / bajar
	local ultimoSalto = 0
	local aimActual = nil
	local toggleLaser, teclaLaser = false, false
	local recarga, tiempoDisparo, danoAcum = 0, 0, 0
	local rayoAlpha = 0
	local tSuelo, tFiltro, tAnim = 0, 0, 0
	local prueba = false               -- MODO PRUEBA: robot fijo (no sigue la cámara), punto verde en el ojo, rayo recto
	local yawFijo = 0
	-- Modos de disparo y equipo de robots
	local laserHold = { activo = false, mantenido = false, id = 0, input = nil, sigue = nil }
	local ultimoTap = 0
	local laserQuiere = false
	local aimTap, aimTapHasta = nil, 0
	local extras = {}                  -- los robots seguidores (el principal es el que te montas)
	local balas = {}                   -- rayitos en el aire
	local ataque = { activo = false, modelo = nil, hum = nil, raiz = nil }
	local cadAtaque = 0
	local chispas = 0
	local actualizarBotones            -- se define más abajo

	local function personaje()
		local ch = jugador.Character
		if not ch then
			return nil
		end
		local hrp = ch:FindFirstChild("HumanoidRootPart")
		local hum = ch:FindFirstChildOfClass("Humanoid")
		if hrp and hum then
			return ch, hrp, hum
		end
		return nil
	end

	-- tamaño real del robot en studs (dimensión más grande)
	local function tam()
		local base = 5
		if C.TAMANO_OBJETIVO and C.TAMANO_OBJETIVO > 0 then
			base = C.TAMANO_OBJETIVO * C.ESCALA
		end
		return base * escalaUser * fMonta
	end

	-- ===================== FILTROS DE RAYOS =====================
	local paramsSuelo = RaycastParams.new()          -- suelo: ignora a todos los jugadores
	paramsSuelo.FilterType = Enum.RaycastFilterType.Exclude
	local paramsMira = RaycastParams.new()           -- mira y láser: solo ignora tu personaje y al robot
	paramsMira.FilterType = Enum.RaycastFilterType.Exclude
	local paramsDano = OverlapParams.new()
	paramsDano.FilterType = Enum.RaycastFilterType.Exclude

	local function refrescarFiltro()
		local todos = { carpeta }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(todos, p.Character)
			end
		end
		paramsSuelo.FilterDescendantsInstances = todos

		local mios = { carpeta }
		if jugador.Character then
			table.insert(mios, jugador.Character)
		end
		paramsMira.FilterDescendantsInstances = mios
		paramsDano.FilterDescendantsInstances = mios
	end
	refrescarFiltro()

	-- ===================== GUI (avisos + botones) =====================
	local anterior = playerGui:FindFirstChild("RickRobotGui")
	if anterior then
		anterior:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RickRobotGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local etiqueta = Instance.new("TextLabel")
	etiqueta.AnchorPoint = Vector2.new(0.5, 1)
	etiqueta.Position = UDim2.new(0.5, 0, 0.85, 0)
	etiqueta.Size = UDim2.new(0, 320, 0, 24)
	etiqueta.BackgroundTransparency = 1
	etiqueta.Font = Enum.Font.GothamBold
	etiqueta.TextSize = 15
	etiqueta.TextColor3 = Color3.fromRGB(255, 220, 220)
	etiqueta.TextStrokeTransparency = 0.5
	etiqueta.TextTransparency = 1
	etiqueta.Text = ""
	etiqueta.Parent = gui

	local avisoId = 0
	local function aviso(txt)
		print("[ROBOT] " .. txt)
		if not C.AVISOS_EN_PANTALLA then
			return
		end
		avisoId += 1
		local mi = avisoId
		etiqueta.Text = txt
		etiqueta.TextTransparency = 0
		task.delay(2, function()
			if mi == avisoId and etiqueta.Parent then
				etiqueta.TextTransparency = 1
			end
		end)
	end

	local function crearBoton(nombre, texto, posicion)
		local b = Instance.new("TextButton")
		b.Name = nombre
		b.Size = UDim2.new(0, 64, 0, 30)
		b.Position = posicion
		b.BackgroundColor3 = Shared.COLORES.FONDO
		b.Text = texto
		b.AutoButtonColor = false
		b.Active = true
		b.Parent = gui
		return b
	end

	-- Filas libres entre SIERRA/CUCHILLO (y=0.35) y el candado; todos son movibles
	local botonVer = crearBoton("BotonRobot", "ROBOT", UDim2.new(0.7292, 0, 0.2705, 0))
	local botonMontar = crearBoton("BotonMontar", "SUBIR", UDim2.new(0.8121, 0, 0.2705, 0))
	local botonLaser = crearBoton("BotonLaser", "LÁSER", UDim2.new(0.7292, 0, 0.1918, 0))
	local botonPrueba = crearBoton("BotonPrueba", "PRUEBA", UDim2.new(0.7292, 0, 0.1131, 0))
	local botonAtacar = crearBoton("BotonAtacar", "ATACAR", UDim2.new(0.8121, 0, 0.1131, 0))

	actualizarBotones = function()
		local verde, rojo = Shared.COLORES.VERDE, Shared.COLORES.ROJO
		botonMontar.Text = (estado.fase == "montado" or estado.fase == "bajando") and "BAJAR" or "SUBIR"
		Shared.PintarBoton(botonVer, estado.visible and verde or rojo)
		Shared.PintarBoton(botonMontar, estado.fase == "montado" and verde or rojo)
		Shared.PintarBoton(botonLaser, (toggleLaser or teclaLaser) and verde or rojo)
		Shared.PintarBoton(botonPrueba, prueba and verde or rojo)
		Shared.PintarBoton(botonAtacar, ataque.activo and verde or rojo)
	end
	actualizarBotones()

	-- ===================== POSES (animación procedural R15) =====================
	-- Ángulos en grados (X, Y, Z) que se suman a cada articulación (Motor6D.C0).
	local POSE_SALTO = {
		RightShoulder = Vector3.new(140, 0, 15), LeftShoulder = Vector3.new(140, 0, -15),
		RightElbow = Vector3.new(25, 0, 0), LeftElbow = Vector3.new(25, 0, 0),
		RightHip = Vector3.new(70, 0, 0), LeftHip = Vector3.new(50, 0, 0),
		RightKnee = Vector3.new(-80, 0, 0), LeftKnee = Vector3.new(-55, 0, 0),
		Waist = Vector3.new(-12, 0, 0),
		-- R6: brazos y piernas giran en Z (derecha +, izquierda -)
		["Right Shoulder"] = Vector3.new(0, 0, 150), ["Left Shoulder"] = Vector3.new(0, 0, -150),
		["Right Hip"] = Vector3.new(0, 0, 60), ["Left Hip"] = Vector3.new(0, 0, -40),
	}
	local POSE_SENTADO = {
		-- Centrado detrás del robot, abrazándolo (como Morty): brazos al frente, piernas abiertas y dobladas
		RightShoulder = Vector3.new(85, 0, 0), LeftShoulder = Vector3.new(85, 0, 0),
		RightElbow = Vector3.new(50, 0, 0), LeftElbow = Vector3.new(50, 0, 0),
		Waist = Vector3.new(-6, 0, 0),
		-- R6
		["Right Shoulder"] = Vector3.new(0, 0, 85), ["Left Shoulder"] = Vector3.new(0, 0, -85),
	}

	-- Piernas (se rearman con /pierna). Cadera: X = muslo al frente, Y = giro, Z = abrir hacia afuera
	local pierna = {
		cad = C.PIERNAS.CADERA, abrir = C.PIERNAS.ABRIR, rod = C.PIERNAS.RODILLA,
		tob = C.PIERNAS.TOBILLO, cerrar = C.PIERNAS.CERRAR,
	}
	local function armarPiernas()
		-- R15
		POSE_SENTADO.RightHip = Vector3.new(pierna.cad, -pierna.cerrar, pierna.abrir)
		POSE_SENTADO.LeftHip = Vector3.new(pierna.cad, pierna.cerrar, -pierna.abrir)
		POSE_SENTADO.RightKnee = Vector3.new(pierna.rod, 0, 0)
		POSE_SENTADO.LeftKnee = Vector3.new(pierna.rod, 0, 0)
		POSE_SENTADO.RightAnkle = Vector3.new(pierna.tob, 0, 0)
		POSE_SENTADO.LeftAnkle = Vector3.new(pierna.tob, 0, 0)
		-- R6 (no tiene rodillas: X = abrir, Z = muslo al frente)
		POSE_SENTADO["Right Hip"] = Vector3.new(-pierna.abrir, 0, pierna.cad * 0.65)
		POSE_SENTADO["Left Hip"] = Vector3.new(-pierna.abrir, 0, -pierna.cad * 0.65)
	end
	armarPiernas()
	local NOMBRES_POSE = {}
	for n in pairs(POSE_SALTO) do
		NOMBRES_POSE[n] = true
	end
	for n in pairs(POSE_SENTADO) do
		NOMBRES_POSE[n] = true
	end

	local motores = {}

	local function capturarMotores(ch)
		table.clear(motores)
		for _, d in ipairs(ch:GetDescendants()) do
			if d:IsA("Motor6D") and (NOMBRES_POSE[d.Name] or d.Name == "RightWrist" or d.Name == "LeftWrist") and not motores[d.Name] then
				motores[d.Name] = { m = d, c0 = d.C0, c1 = d.C1 }
			end
		end
	end

	local function soltarMotores()
		for _, v in pairs(motores) do
			pcall(function()
				v.m.C0 = v.c0
			end)
		end
		table.clear(motores)
	end

	-- Movimiento vivo al ir montado: piernas que se balancean, y te recuestas más al ir rápido
	local function movimiento(n)
		local s1 = math.sin(t * 3.2)
		local s2 = math.sin(t * 3.2 + 1.4)
		if n == "Waist" then
			return Vector3.new(-12 * velFrac + s1 * 1.5, 0, 0)
		elseif n == "RightKnee" then
			return Vector3.new(-s1 * 4 * (0.4 + velFrac) - velFrac * 6, 0, 0)
		elseif n == "LeftKnee" then
			return Vector3.new(-s2 * 4 * (0.4 + velFrac) - velFrac * 6, 0, 0)
		elseif n == "RightHip" then
			return Vector3.new(s1 * 2.5 - velFrac * 3, 0, 0)
		elseif n == "LeftHip" then
			return Vector3.new(s2 * 2.5 - velFrac * 3, 0, 0)
		elseif n == "Right Hip" then
			return Vector3.new(0, 0, s1 * 2.5 - velFrac * 8)
		elseif n == "Left Hip" then
			return Vector3.new(0, 0, -s2 * 2.5 + velFrac * 8)
		end
		return nil
	end

	-- Giro mínimo que lleva el vector unitario a hacia el b
	local function giroEntre(a, b)
		local d = a:Dot(b)
		if d > 0.9999 then
			return CFrame.new()
		end
		if d < -0.9999 then
			local ax = a:Cross(Vector3.new(1, 0, 0))
			if ax.Magnitude < 0.001 then
				ax = a:Cross(Vector3.new(0, 1, 0))
			end
			return CFrame.fromAxisAngle(ax.Unit, math.pi)
		end
		return CFrame.fromAxisAngle(a:Cross(b).Unit, math.acos(math.clamp(d, -1, 1)))
	end

	-- Manos agarradas al robot (R6: brazo rígido apuntando | R15: IK de dos huesos hombro-codo)
	local function aplicarAgarre(w)
		if w <= 0.001 then
			return
		end
		local abajo = Vector3.new(0, -1, 0)
		local lados = {
			{ pre = "Right", r6 = "Right Shoulder", grip = gripDer, signo = 1 },
			{ pre = "Left", r6 = "Left Shoulder", grip = gripIzq, signo = -1 },
		}
		for _, l in ipairs(lados) do
			local objetivo = (marcoActual * CFrame.new(l.grip * tam())).Position
			local sh = motores[l.pre .. "Shoulder"]
			local el = motores[l.pre .. "Elbow"]
			local sh6 = motores[l.r6]

			if sh and el and sh.m.Parent and el.m.Parent and sh.m.Part0 then
				-- ---------- R15 ----------
				local cfT = sh.m.Part0.CFrame
				local P = sh.c0.Position
				local repSup = sh.c0 * sh.c1:Inverse()
				local codo = (repSup * el.c0).Position
				local L1 = (codo - P).Magnitude
				local L2 = 1.5
				local mw = motores[l.pre .. "Wrist"]
				if mw then
					local repInf = repSup * el.c0 * el.c1:Inverse()
					L2 = ((repInf * mw.c0).Position - codo).Magnitude + 0.3
				end
				local v = cfT:PointToObjectSpace(objetivo) - P
				if v.Magnitude > 0.05 and L1 > 0.1 then
					local u = v.Unit
					local d = math.clamp(v.Magnitude, math.abs(L1 - L2) + 0.05, L1 + L2 - 0.05)
					local cosA = math.clamp((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1)
					local ang = math.acos(cosA)
					local pole = Vector3.new(l.signo * 0.6, -1, 0.3)
					local perp = pole - u * pole:Dot(u)
					if perp.Magnitude < 0.001 then
						perp = Vector3.new(l.signo, 0, 0)
					end
					perp = perp.Unit
					local a = u * math.cos(ang) + perp * math.sin(ang)
					local punta = P + u * d
					local b = (punta - (P + a * L1)).Unit
					local Ts = giroEntre(abajo, a)
					local Te = giroEntre(abajo, Ts:Inverse() * b)
					local r0s = sh.c0.Rotation
					local r0e = el.c0.Rotation
					sh.m.C0 = sh.m.C0:Lerp(sh.c0 * (r0s:Inverse() * Ts * r0s), w)
					el.m.C0 = el.m.C0:Lerp(el.c0 * (r0e:Inverse() * Te * r0e), w)
				end

			elseif sh6 and sh6.m.Parent and sh6.m.Part0 then
				-- ---------- R6 ----------
				local torso = sh6.m.Part0
				local pivote = (torso.CFrame * sh6.c0).Position
				local dirMundo = objetivo - pivote
				if dirMundo.Magnitude > 0.05 then
					local dL = torso.CFrame.Rotation:Inverse() * dirMundo.Unit
					local rotRel = giroEntre(abajo, dL)
					local r0 = sh6.c0.Rotation
					sh6.m.C0 = sh6.m.C0:Lerp(sh6.c0 * (r0:Inverse() * rotRel * r0), w)
				end
			end
		end
	end

	local function aplicarPose(wSalto, wSentado, wAgarre)
		for n, v in pairs(motores) do
			if v.m.Parent then
				local a = Vector3.zero
				if POSE_SALTO[n] then
					a += POSE_SALTO[n] * wSalto
				end
				if POSE_SENTADO[n] then
					a += POSE_SENTADO[n] * wSentado
				end
				local mv = movimiento(n)
				if mv then
					a += mv * movW
				end
				local rx, ry, rz = math.rad(a.X), math.rad(a.Y), math.rad(a.Z)
				local giro
				if n == "RightHip" or n == "LeftHip" then
					-- R15: primero giro/abrir, luego subir el muslo (así abre de verdad)
					giro = CFrame.Angles(rx, 0, 0) * CFrame.Angles(0, 0, rz) * CFrame.Angles(0, ry, 0)
				elseif n == "Right Hip" or n == "Left Hip" then
					-- R6: primero abrir, luego subir
					giro = CFrame.Angles(0, 0, rz) * CFrame.Angles(rx, 0, 0)
				else
					giro = CFrame.Angles(rx, ry, rz)
				end
				v.m.C0 = v.c0 * giro
			end
		end
		aplicarAgarre(wAgarre or 0)
	end

	local function pararAnimaciones(hum)
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
				pcall(function()
					tr:Stop(0.1)
				end)
			end
		end
	end

	local function colocarPersonaje(hrp, cf)
		hrp.CFrame = cf
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end

	-- Termina cualquier montura sin animación (muerte, respawn, limpieza)
	local function abortarMontura()
		soltarMotores()
		local _, _, hum = personaje()
		if hum then
			pcall(function()
				hum.PlatformStand = false
				hum.AutoRotate = true
			end)
		end
		sub = nil
		estado.fase = "libre"
		toggleLaser = false
		if actualizarBotones then
			actualizarBotones()
		end
	end

	-- ===================== CONTROLES DE VUELO =====================
	local controles = nil
	task.spawn(function()
		local ok, res = pcall(function()
			local scripts = jugador:WaitForChild("PlayerScripts", 10)
			local pm = scripts and scripts:WaitForChild("PlayerModule", 10)
			return pm and require(pm):GetControls() or nil
		end)
		if ok then
			controles = res
		end
	end)

	local function vectorMovimiento(hum)
		if controles then
			local ok, v = pcall(function()
				return controles:GetMoveVector()
			end)
			if ok and typeof(v) == "Vector3" then
				return v
			end
		end
		local cam = Workspace.CurrentCamera
		if cam then
			return cam.CFrame:VectorToObjectSpace(hum.MoveDirection)
		end
		return Vector3.zero
	end

	-- ===================== LÁSER (partes) =====================
	local function nuevaParte(nombre, forma, color, transp)
		local p = Instance.new("Part")
		p.Name = nombre
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transp
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if forma then
			p.Shape = forma
		end
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		return p
	end

	local pHalo = nuevaParte("Halo", Enum.PartType.Cylinder, C.COLOR_LASER, 0.75)
	local pCuerpo = nuevaParte("Cuerpo", Enum.PartType.Cylinder, C.COLOR_LASER, 0.15)
	local pNucleo = nuevaParte("Nucleo", Enum.PartType.Cylinder, Color3.fromRGB(255, 215, 215), 0.05)
	local pImpacto = nuevaParte("Impacto", Enum.PartType.Ball, C.COLOR_LASER, 0.1)
	local pOjo = nuevaParte("OjoBrillo", Enum.PartType.Ball, C.COLOR_LASER, 0.1)
	local PARTES_RAYO = { pHalo, pCuerpo, pNucleo, pImpacto, pOjo }

	-- ===================== MODO PRUEBA: marcador del ojo + línea de dirección =====================
	-- Punto verde = de dónde sale el láser (se ve aunque quede dentro de la malla).
	-- Línea verde = hacia dónde apunta el robot (su frente). Ajusta con /ojo X Y Z y míralo moverse.
	local VERDE_PRUEBA = Color3.fromRGB(0, 255, 120)
	local pMarca = nuevaParte("MarcaOjo", Enum.PartType.Ball, VERDE_PRUEBA, 0.2)
	pMarca.Size = Vector3.one * 0.5
	local pDir = nuevaParte("MarcaDireccion", nil, VERDE_PRUEBA, 0.35)

	local bbMarca = Instance.new("BillboardGui")
	bbMarca.Size = UDim2.fromOffset(90, 24)
	bbMarca.AlwaysOnTop = true
	bbMarca.Parent = pMarca
	local puntoMarca = Instance.new("Frame")
	puntoMarca.AnchorPoint = Vector2.new(0.5, 0.5)
	puntoMarca.Position = UDim2.fromScale(0.5, 0.5)
	puntoMarca.Size = UDim2.fromOffset(10, 10)
	puntoMarca.BackgroundColor3 = VERDE_PRUEBA
	puntoMarca.BorderSizePixel = 0
	puntoMarca.Parent = bbMarca
	local esquinaMarca = Instance.new("UICorner")
	esquinaMarca.CornerRadius = UDim.new(1, 0)
	esquinaMarca.Parent = puntoMarca
	local textoMarca = Instance.new("TextLabel")
	textoMarca.Position = UDim2.new(0.5, 10, 0, 0)
	textoMarca.Size = UDim2.new(0, 50, 1, 0)
	textoMarca.BackgroundTransparency = 1
	textoMarca.Font = Enum.Font.GothamBold
	textoMarca.TextSize = 13
	textoMarca.TextXAlignment = Enum.TextXAlignment.Left
	textoMarca.TextColor3 = VERDE_PRUEBA
	textoMarca.TextStrokeTransparency = 0.3
	textoMarca.Text = "OJO"
	textoMarca.Parent = bbMarca

	local function ocultarMarca()
		if pMarca.Parent then
			pMarca.Parent = nil
		end
		if pDir.Parent then
			pDir.Parent = nil
		end
	end

	local function actualizarMarca()
		if not prueba then
			ocultarMarca()
			return
		end
		local posOjo = (marcoActual * CFrame.new(ojoFrac * tam())).Position
		local largoDir = 12
		pMarca.CFrame = CFrame.new(posOjo)
		pDir.Size = Vector3.new(0.15, 0.15, largoDir)
		pDir.CFrame = CFrame.new(posOjo) * marcoActual.Rotation * CFrame.new(0, 0, -largoDir / 2)
		if not pMarca.Parent then
			pMarca.Parent = carpetaRayos
		end
		if not pDir.Parent then
			pDir.Parent = carpetaRayos
		end
	end

	local luzImpacto = Instance.new("PointLight")
	luzImpacto.Color = C.COLOR_LASER
	luzImpacto.Range = 16
	luzImpacto.Brightness = 3
	luzImpacto.Parent = pImpacto

	local luzOjo = Instance.new("PointLight")
	luzOjo.Color = C.COLOR_LASER
	luzOjo.Range = 12
	luzOjo.Brightness = 2
	luzOjo.Parent = pOjo

	local sonidoLaser = nil
	if C.SONIDO_LASER and C.SONIDO_LASER ~= "" then
		sonidoLaser = Instance.new("Sound")
		sonidoLaser.SoundId = "rbxassetid://" .. C.SONIDO_LASER
		sonidoLaser.Looped = true
		sonidoLaser.Volume = C.VOLUMEN
		sonidoLaser.Parent = pOjo
	end

	local function ocultarRayo()
		for _, p in ipairs(PARTES_RAYO) do
			if p.Parent then
				p.Parent = nil
			end
		end
		if sonidoLaser then
			sonidoLaser:Stop()
		end
	end

	-- punto al que apunta el centro de la pantalla
	local function puntoDeMira()
		local cam = Workspace.CurrentCamera
		if not cam then
			return nil
		end
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local res = Workspace:Raycast(ray.Origin, ray.Direction * C.ALCANCE, paramsMira)
		if res then
			return res.Position
		end
		return ray.Origin + ray.Direction * C.ALCANCE
	end

	local function actualizarRayo(dt)
		local quiere = (toggleLaser or teclaLaser) and ap > 0.8 and recarga <= 0
		if recarga > 0 then
			recarga = math.max(0, recarga - dt)
		end

		if quiere then
			tiempoDisparo += dt
			if prueba then
				tiempoDisparo = 0 -- en PRUEBA el láser no se corta
			end
			if tiempoDisparo > C.MAX_SEG then
				toggleLaser = false
				teclaLaser = false
				laserHold.mantenido = false
				laserHold.activo = false
				tiempoDisparo = 0
				recarga = C.RECARGA_SEG
				quiere = false
				actualizarBotones()
				aviso("LÁSER: RECARGANDO")
			end
		else
			tiempoDisparo = math.max(0, tiempoDisparo - dt)
		end

		laserQuiere = quiere
		local objetivo = quiere and 1 or 0
		local paso = dt / math.max(quiere and C.CARGA_SEG or C.APAGADO_SEG, 0.02)
		if rayoAlpha < objetivo then
			rayoAlpha = math.min(rayoAlpha + paso, 1)
		else
			rayoAlpha = math.max(rayoAlpha - paso, 0)
		end

		if rayoAlpha <= 0.001 then
			ocultarRayo()
			aimActual = nil
			return
		end

		local ojo = (marcoActual * CFrame.new(ojoFrac * tam())).Position
		local mira = nil
		if prueba then
			-- PRUEBA: el rayo sale recto hacia el frente del robot (no hacia el centro de la pantalla)
			mira = ojo + marcoActual.LookVector * C.ALCANCE
			aimActual = nil
		else
			mira = puntoDeMira()
			aimActual = mira
		end
		local dir = mira and (mira - ojo) or Vector3.zero
		if dir.Magnitude < 3 then
			local cam = Workspace.CurrentCamera
			dir = cam and cam.CFrame.LookVector or marcoActual.LookVector
		end
		dir = dir.Unit

		local fin = ojo + dir * C.ALCANCE
		local res = Workspace:Raycast(ojo, dir * C.ALCANCE, paramsMira)
		if res then
			fin = res.Position
		end

		local e = suave(rayoAlpha)
		local w = C.ANCHO * e * (1 + 0.1 * math.sin(t * 55))
		local largo = math.max((fin - ojo).Magnitude, 0.5)
		local mitad = (ojo + fin) / 2
		local base = CFrame.lookAt(mitad, fin) * CFrame.Angles(0, math.rad(90), 0)

		pCuerpo.Size = Vector3.new(largo, w, w)
		pCuerpo.CFrame = base
		pNucleo.Size = Vector3.new(largo, w * 0.4, w * 0.4)
		pNucleo.CFrame = base
		pHalo.Size = Vector3.new(largo, w * 2, w * 2)
		pHalo.CFrame = base
		pImpacto.Size = Vector3.one * (w * 2.2 * (1 + 0.15 * math.sin(t * 40)))
		pImpacto.CFrame = CFrame.new(fin)
		pImpacto.Transparency = res and 0.1 or 1
		luzImpacto.Enabled = res ~= nil
		pOjo.Size = Vector3.one * (w * 1.6)
		pOjo.CFrame = CFrame.new(ojo)

		for _, p in ipairs(PARTES_RAYO) do
			if not p.Parent then
				p.Parent = carpetaRayos
			end
		end
		if sonidoLaser and not sonidoLaser.IsPlaying then
			sonidoLaser:Play()
		end

		-- daño (ancho del rayo): solo mientras dispara de verdad
		danoAcum += dt
		if quiere and rayoAlpha > 0.7 and danoAcum >= C.DANO_INTERVALO and Shared.DanarDeParte then
			danoAcum = 0
			local caja = CFrame.lookAt(mitad, fin)
			local partes = Workspace:GetPartBoundsInBox(caja, Vector3.new(w + 1.5, w + 1.5, largo), paramsDano)
			local vistos = {}
			for _, p in ipairs(partes) do
				local m = p
				while m and m ~= Workspace do
					if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
						break
					end
					m = m.Parent
				end
				if m and m ~= Workspace and not vistos[m] then
					vistos[m] = true
					pcall(Shared.DanarDeParte, p, C.DANO)
				end
			end
		end
	end

	-- ===================== RAYITOS (disparos sueltos) =====================
	local Debris = game:GetService("Debris")
	local TweenService = game:GetService("TweenService")

	local function modeloHumanoide(parte)
		local m = parte
		while m and m ~= Workspace do
			if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
				return m
			end
			m = m.Parent
		end
		return nil
	end

	-- ===================== EFECTOS DE LOS RAYITOS (solo metralleta) =====================
	local efectosVivos = 0
	local function efectoLibre()
		return C.EFECTOS_RAYITOS and efectosVivos < C.EFECTOS_MAX
	end

	local function efimero(p, seg)
		efectosVivos += 1
		Debris:AddItem(p, seg + 0.05)
		task.delay(seg, function()
			efectosVivos = math.max(0, efectosVivos - 1)
		end)
	end

	local function animar(p, seg, props)
		pcall(function()
			TweenService:Create(p, TweenInfo.new(seg, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
		end)
	end

	-- fogonazo en la boca del ojo al disparar
	local function destello(origen, dir)
		if not efectoLibre() then
			return
		end
		local p = nuevaParte("Destello", Enum.PartType.Ball, Color3.fromRGB(255, 235, 170), 0.05)
		p.Size = Vector3.one * 0.5
		p.CFrame = CFrame.new(origen + dir * 1.0)
		p.Parent = carpetaRayos
		animar(p, 0.1, { Size = Vector3.one * 2.4, Transparency = 1 })
		efimero(p, 0.1)
	end

	-- impacto: bola de luz + anillo en el suelo/pared + chispitas que salen disparadas
	local function chispa(posicion, normal)
		chispas += 1
		if not efectoLibre() then
			return
		end
		normal = normal or Vector3.new(0, 1, 0)

		local flash = nuevaParte("Chispa", Enum.PartType.Ball, Color3.fromRGB(255, 200, 120), 0.05)
		flash.Size = Vector3.one * 0.7
		flash.CFrame = CFrame.new(posicion)
		flash.Parent = carpetaRayos
		if chispas % 3 == 0 then
			local luz = Instance.new("PointLight")
			luz.Color = C.COLOR_BALA
			luz.Range = 10
			luz.Brightness = 3
			luz.Parent = flash
		end
		animar(flash, 0.16, { Size = Vector3.one * 3, Transparency = 1 })
		efimero(flash, 0.16)

		local anillo = nuevaParte("Anillo", Enum.PartType.Cylinder, C.COLOR_BALA, 0.2)
		anillo.Size = Vector3.new(0.1, 0.8, 0.8)
		anillo.CFrame = CFrame.lookAt(posicion, posicion + normal) * CFrame.Angles(0, math.rad(90), 0)
		anillo.Parent = carpetaRayos
		animar(anillo, 0.22, { Size = Vector3.new(0.1, 5, 5), Transparency = 1 })
		efimero(anillo, 0.22)

		-- chispitas: una ráfaga de cada 3 impactos para no llenar el mapa
		if chispas % 3 == 1 then
			for _ = 1, 3 do
				local v = normal * 1.2 + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2
				if v.Magnitude < 0.1 then
					v = normal
				end
				v = v.Unit
				local s = nuevaParte("Chispita", nil, Color3.fromRGB(255, 220, 140), 0)
				s.Size = Vector3.new(0.12, 0.12, 0.6)
				s.CFrame = CFrame.lookAt(posicion, posicion + v)
				s.Parent = carpetaRayos
				animar(s, 0.28, {
					CFrame = CFrame.lookAt(posicion + v * (2 + math.random() * 2), posicion + v * 6),
					Transparency = 1,
				})
				efimero(s, 0.28)
			end
		end
	end

	local function crearBala(origen, dir, dano)
		if #balas >= C.MAX_BALAS then
			local v = table.remove(balas, 1)
			if v and v.parte then
				v.parte:Destroy()
			end
		end
		local p = nuevaParte("Bala", nil, C.EFECTOS_RAYITOS and C.COLOR_BALA_NUCLEO or C.COLOR_BALA, 0.05)
		p.Size = Vector3.new(C.BALA_ANCHO, C.BALA_ANCHO, C.BALA_LARGO)
		p.CFrame = CFrame.lookAt(origen, origen + dir)
		if C.EFECTOS_RAYITOS then
			-- estela: núcleo blanco-caliente -> naranja -> rojo oscuro, que se adelgaza y se desvanece
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, C.BALA_ANCHO * 0.7, C.BALA_LARGO / 2)
			a0.Parent = p
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -C.BALA_ANCHO * 0.7, C.BALA_LARGO / 2)
			a1.Parent = p
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0
			tr.Attachment1 = a1
			tr.Lifetime = C.TRAIL_SEG
			tr.MinLength = 0.05
			tr.FaceCamera = true
			tr.LightEmission = 1
			tr.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, C.COLOR_BALA_NUCLEO),
				ColorSequenceKeypoint.new(0.35, C.COLOR_BALA),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 0, 0)),
			})
			tr.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(1, 1),
			})
			tr.WidthScale = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			})
			tr.Parent = p
		end
		p.Parent = carpetaRayos
		table.insert(balas, { parte = p, pos = origen, dir = dir, dist = 0, dano = dano })
	end

	-- al pegar o agotar alcance: el rayito se esconde y la estela se desvanece sola
	local function apagarBala(b, posFinal)
		if C.EFECTOS_RAYITOS and b.parte.Parent then
			b.parte.CFrame = CFrame.lookAt(posFinal, posFinal + b.dir)
			b.parte.Transparency = 1
			Debris:AddItem(b.parte, C.TRAIL_SEG + 0.05)
		else
			b.parte:Destroy()
		end
	end

	local function actualizarBalas(dt)
		for i = #balas, 1, -1 do
			local b = balas[i]
			local paso = C.BALA_VELOCIDAD * dt
			local res = Workspace:Raycast(b.pos, b.dir * paso, paramsMira)
			if res then
				if Shared.DanarDeParte then
					pcall(Shared.DanarDeParte, res.Instance, b.dano)
				end
				chispa(res.Position, res.Normal)
				apagarBala(b, res.Position)
				table.remove(balas, i)
			else
				b.pos = b.pos + b.dir * paso
				b.dist = b.dist + paso
				if b.dist >= C.BALA_ALCANCE then
					apagarBala(b, b.pos)
					table.remove(balas, i)
				else
					b.parte.CFrame = CFrame.lookAt(b.pos, b.pos + b.dir)
				end
			end
		end
	end

	-- desvía la dirección unos grados al azar (para el efecto metralleta)
	local function dispersar(dir, grados)
		if not grados or grados <= 0 then
			return dir
		end
		local g = math.rad(grados)
		local cf = CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles((math.random() - 0.5) * 2 * g, (math.random() - 0.5) * 2 * g, 0)
		return cf.LookVector
	end

	local function disparar(ojo, objetivo, dano, dispersion)
		local d = objetivo - ojo
		if d.Magnitude < 1 then
			return
		end
		local dir = dispersar(d.Unit, dispersion)
		crearBala(ojo, dir, dano)
		destello(ojo, dir)
	end

	-- ===================== EQUIPO DE ROBOTS (seguidores) =====================
	local function tamExtra()
		return tam() / math.max(fMonta, 0.001)
	end

	local function ojoDe(e)
		return (e.marco * CFrame.new(ojoFrac * tamExtra())).Position
	end

	local function ojoPrincipal()
		return (marcoActual * CFrame.new(ojoFrac * tam())).Position
	end

	-- A dónde dispara un seguidor cuando TÚ disparas: si miras algo lejos, todos convergen ahí;
	-- si no, disparan en PARALELO a tu rayo (así ya no parece que te apuntan a ti)
	local function apuntarExtra(ojoE, objetivo)
		local _, r = personaje()
		if r and (objetivo - r.Position).Magnitude > C.CONVERGER_DESDE then
			return objetivo
		end
		local d = objetivo - ojoPrincipal()
		if d.Magnitude < 1 then
			return ojoE + marcoActual.LookVector * C.ALCANCE
		end
		return ojoE + d.Unit * C.ALCANCE
	end

	local function crearExtra()
		local m = Instance.new("Model")
		m.Name = "RobotExtra"
		local rz = Instance.new("Part")
		rz.Name = "Raiz"
		rz.Size = Vector3.one
		rz.Anchored = true
		rz.CanCollide = false
		rz.CanQuery = false
		rz.CanTouch = false
		rz.Parent = m
		m.PrimaryPart = rz
		local ml = Instance.new("SpecialMesh")
		ml.MeshType = Enum.MeshType.FileMesh
		ml.MeshId = "rbxassetid://" .. C.MESH_ID
		ml.TextureId = "rbxassetid://" .. C.TEXTURE_ID
		ml.Offset = C.OFFSET_MALLA
		ml.Scale = Vector3.one * 0.001
		ml.Parent = rz
		m.Parent = carpeta
		local e = {
			modelo = m, raiz = rz, malla = ml,
			pos = pos, vel = Vector3.zero, yaw = yaw, marco = CFrame.new(pos),
			ap = 0, sueloY = nil, tSuelo = math.random() * 0.15,
			cad = math.random() * C.ATAQUE_CADENCIA, danoAcum = 0,
			desfase = math.random() * math.pi * 2, reaparecer = true, rayo = nil,
		}
		table.insert(extras, e)
		return e
	end

	local function nuevoRayoExtra()
		return {
			nuevaParte("Halo", Enum.PartType.Cylinder, C.COLOR_LASER, 0.75),
			nuevaParte("Cuerpo", Enum.PartType.Cylinder, C.COLOR_LASER, 0.15),
			nuevaParte("Nucleo", Enum.PartType.Cylinder, Color3.fromRGB(255, 215, 215), 0.05),
			nuevaParte("Impacto", Enum.PartType.Ball, C.COLOR_LASER, 0.1),
		}
	end

	local function ocultarRayoExtra(e)
		if e.rayo then
			for _, p in ipairs(e.rayo) do
				if p.Parent then
					p.Parent = nil
				end
			end
		end
	end

	-- cuando el robot principal se oculta, los seguidores también
	local function ocultarExtras()
		for _, e in ipairs(extras) do
			if e.modelo.Parent then
				e.modelo.Parent = nil
			end
			ocultarRayoExtra(e)
			e.reaparecer = true
		end
	end

	local function quitarUno()
		local e = table.remove(extras)
		if not e then
			return false
		end
		ocultarRayoExtra(e)
		if e.rayo then
			for _, p in ipairs(e.rayo) do
				p:Destroy()
			end
		end
		e.modelo:Destroy()
		return true
	end

	-- el mismo rayo rojo del principal, pero desde el ojo de un seguidor
	local function dibujarRayoExtra(e, dt)
		local ojo = ojoDe(e)
		local mira = aimActual and apuntarExtra(ojo, aimActual) or (ojo + e.marco.LookVector * C.ALCANCE)
		local dir = mira - ojo
		if dir.Magnitude < 3 then
			dir = e.marco.LookVector
		end
		dir = dir.Unit
		local fin = ojo + dir * C.ALCANCE
		local res = Workspace:Raycast(ojo, dir * C.ALCANCE, paramsMira)
		if res then
			fin = res.Position
		end
		if not e.rayo then
			e.rayo = nuevoRayoExtra()
		end
		local halo, cuerpo, nucleo, impacto = e.rayo[1], e.rayo[2], e.rayo[3], e.rayo[4]
		local ee = suave(rayoAlpha)
		local w = C.ANCHO * ee * (1 + 0.1 * math.sin(t * 55 + e.desfase))
		local largo = math.max((fin - ojo).Magnitude, 0.5)
		local mitad = (ojo + fin) / 2
		local base = CFrame.lookAt(mitad, fin) * CFrame.Angles(0, math.rad(90), 0)
		cuerpo.Size = Vector3.new(largo, w, w)
		cuerpo.CFrame = base
		nucleo.Size = Vector3.new(largo, w * 0.4, w * 0.4)
		nucleo.CFrame = base
		halo.Size = Vector3.new(largo, w * 2, w * 2)
		halo.CFrame = base
		impacto.Size = Vector3.one * (w * 2.2)
		impacto.CFrame = CFrame.new(fin)
		impacto.Transparency = res and 0.1 or 1
		for _, p in ipairs(e.rayo) do
			if not p.Parent then
				p.Parent = carpetaRayos
			end
		end

		-- daño (igual que el rayo principal)
		e.danoAcum += dt
		if laserQuiere and rayoAlpha > 0.7 and e.danoAcum >= C.DANO_INTERVALO and Shared.DanarDeParte then
			e.danoAcum = 0
			local caja = CFrame.lookAt(mitad, fin)
			local partes = Workspace:GetPartBoundsInBox(caja, Vector3.new(w + 1.5, w + 1.5, largo), paramsDano)
			local vistos = {}
			for _, p in ipairs(partes) do
				local m = modeloHumanoide(p)
				if m and not vistos[m] then
					vistos[m] = true
					pcall(Shared.DanarDeParte, p, C.DANO)
				end
			end
		end
	end

	local function actualizarExtras(dt)
		if #extras == 0 then
			return
		end
		local _, r = personaje()
		if not r then
			return
		end
		local libre = estado.fase == "libre"
		local centro, yawF, vRef
		if libre then
			centro = r.Position
			local look = r.CFrame.LookVector
			yawF = math.atan2(-look.X, -look.Z)
			local v = r.AssemblyLinearVelocity
			vRef = Vector3.new(v.X, 0, v.Z)
		else
			centro = pos
			yawF = yaw
			vRef = vel
		end
		local marcoF = CFrame.Angles(0, yawF, 0)
		local atacando = ataque.activo and ataque.raiz ~= nil and ataque.raiz.Parent ~= nil
		local n = libre and (#extras + 1) or #extras
		local ahora = os.clock()
		local dibujar = C.DISPARAN_JUNTOS and not atacando and rayoAlpha > 0.001

		for i, e in ipairs(extras) do
			if not e.modelo.Parent then
				e.modelo.Parent = carpeta
			end
			e.ap = math.min(e.ap + dt / math.max(C.APARECER_SEG, 0.05), 1)

			-- A) a dónde ir: rodear al objetivo (ataque) o ponerse en formación detrás de ti
			local dest
			local mirar = nil
			if atacando then
				local idx = libre and (i + 1) or i
				local ang = (idx / n) * math.pi * 2 + t * C.ATAQUE_GIRO
				dest = ataque.raiz.Position + Vector3.new(
					math.cos(ang) * C.ATAQUE_RADIO,
					C.ATAQUE_ALTURA + math.sin(t * 1.7 + e.desfase) * 0.6,
					math.sin(ang) * C.ATAQUE_RADIO
				)
				mirar = ataque.raiz.Position
			else
				-- ORBITA: dan vueltas alrededor de ti a distintas alturas (nada de fila)
				local ang = (i / #extras) * math.pi * 2 + t * C.EXTRAS_ORBITA
				local alto = (libre and C.EXTRAS_ALTURA or 0.5) + 1.5 + math.sin(t * 1.3 + i * 1.7) * 1.5
				dest = centro + Vector3.new(math.cos(ang) * C.EXTRAS_RADIO, alto, math.sin(ang) * C.EXTRAS_RADIO)
			end

			if e.reaparecer then
				e.reaparecer = false
				e.pos = dest
				e.vel = Vector3.zero
				e.ap = 0
			end
			if not atacando and (dest - e.pos).Magnitude > C.TELEPORT_DIST then
				e.pos = dest
				e.vel = Vector3.zero
			end

			-- B) moverse
			local deseada = (dest - e.pos) * 3 + (atacando and Vector3.zero or vRef)
			if deseada.Magnitude > C.EXTRAS_VELOCIDAD then
				deseada = deseada.Unit * C.EXTRAS_VELOCIDAD
			end
			e.vel = e.vel:Lerp(deseada, 1 - math.exp(-dt * C.EXTRAS_SUAVIDAD))
			e.pos = e.pos + e.vel * dt

			-- no atravesar el suelo
			e.tSuelo += dt
			if e.tSuelo > 0.15 then
				e.tSuelo = 0
				local res = Workspace:Raycast(e.pos + Vector3.new(0, 4, 0), Vector3.new(0, -400, 0), paramsSuelo)
				e.sueloY = res and res.Position.Y or nil
			end
			if e.sueloY then
				local minimo = e.sueloY + C.ALTURA_MINIMA * escalaUser
				if e.pos.Y < minimo then
					e.pos = e.pos + Vector3.new(0, (minimo - e.pos.Y) * (1 - math.exp(-dt * 8)), 0)
				end
			end

			-- C) hacia dónde miran
			local yawObj = yawF
			local mp = mirar
			if C.DISPARAN_JUNTOS and not mp then
				if aimActual and rayoAlpha > 0.05 then
					mp = apuntarExtra(e.pos, aimActual)
				elseif aimTap and ahora < aimTapHasta then
					mp = apuntarExtra(e.pos, aimTap)
				end
			end
			if mp then
				local d = mp - e.pos
				if d.X * d.X + d.Z * d.Z > 1 then
					yawObj = math.atan2(-d.X, -d.Z)
				end
			end
			local dif = (yawObj - e.yaw + math.pi) % (2 * math.pi) - math.pi
			e.yaw += dif * (1 - math.exp(-dt * 8))

			local marcoYaw = CFrame.Angles(0, e.yaw, 0)
			local vLocal = marcoYaw:VectorToObjectSpace(e.vel)
			local k = math.rad(C.INCLINACION) / math.max(C.VELOCIDAD, 1)
			local bob = math.sin(t * C.FLOTAR_VEL + e.desfase) * C.FLOTAR_AMP * escalaUser
			e.marco = CFrame.new(e.pos + Vector3.new(0, bob, 0))
				* marcoYaw
				* CFrame.Angles(vLocal.Z * k, 0, -vLocal.X * k)

			-- D) visual
			local aa = math.min(e.ap, ap)
			local a = aa * aa * (3 - 2 * aa)
			e.malla.Scale = Vector3.one * math.max(a, 0.001) * escalaBase * escalaUser
			e.raiz.CFrame = e.marco * CFrame.Angles(math.rad(rotOff.X), math.rad(rotOff.Y), math.rad(rotOff.Z))

			-- E) disparo: metralleta contra el objetivo, o el rayo rojo junto contigo
			if atacando and e.ap > 0.8 then
				e.cad -= dt
				if e.cad <= 0 then
					e.cad = C.ATAQUE_CADENCIA
					disparar(ojoDe(e), ataque.raiz.Position, C.ATAQUE_DANO, C.ATAQUE_DISPERSION)
				end
			end
			if dibujar and e.ap > 0.8 then
				dibujarRayoExtra(e, dt)
			else
				ocultarRayoExtra(e)
			end
		end
	end

	-- el robot principal tambien dispara en el ataque (cuando no vas montado en el)
	local function actualizarAtaquePrincipal(dt)
		if not (ataque.activo and ataque.raiz and ataque.raiz.Parent) then
			return
		end
		if estado.fase ~= "libre" or ap < 0.8 then
			return
		end
		cadAtaque -= dt
		if cadAtaque <= 0 then
			cadAtaque = C.ATAQUE_CADENCIA
			local ojo = (marcoActual * CFrame.new(ojoFrac * tam())).Position
			disparar(ojo, ataque.raiz.Position, C.ATAQUE_DANO, C.ATAQUE_DISPERSION)
		end
	end

	-- modo RAYITOS: un toque = un disparo (y los seguidores disparan contigo)
	local function dispararRayito()
		if not estado.visible or ap < 0.8 then
			return
		end
		local ahora = os.clock()
		if ahora - ultimoTap < C.BALA_CADENCIA then
			return
		end
		ultimoTap = ahora
		local ojo = (marcoActual * CFrame.new(ojoFrac * tam())).Position
		local objetivo
		if prueba then
			objetivo = ojo + marcoActual.LookVector * C.ALCANCE
		else
			objetivo = puntoDeMira() or (ojo + marcoActual.LookVector * C.ALCANCE)
			aimTap = objetivo
			aimTapHasta = ahora + 0.4
		end
		disparar(ojo, objetivo, C.BALA_DANO)
		if C.DISPARAN_JUNTOS and not ataque.activo then
			for i, e in ipairs(extras) do
				if e.ap > 0.8 and e.modelo.Parent then
					task.delay(i * 0.025, function()
						if e.modelo.Parent then
							local oe = ojoDe(e)
							pcall(disparar, oe, apuntarExtra(oe, objetivo), C.BALA_DANO)
						end
					end)
				end
			end
		end
	end

	-- UN SOLO BOTON DE DISPARO: mantener = rayo seguido | tocar (click click click) = rayitos
	-- A prueba de "se queda pegado": se suelta cuando se levanta el dedo/tecla, cuando el botón avisa,
	-- cuando el VIGILANTE ve que el input ya terminó, al perder foco, al recalentar y al reaparecer.
	local function laserLiberar()
		laserHold.activo = false
		laserHold.mantenido = false
		laserHold.input = nil
		laserHold.sigue = nil
		laserHold.id += 1
		if teclaLaser then
			teclaLaser = false
			actualizarBotones()
		end
	end

	local function laserSoltar()
		if not laserHold.activo then
			return
		end
		local eraMantenido = laserHold.mantenido
		local sigue = laserHold.sigue
		laserLiberar()
		if not eraMantenido and (not sigue or sigue()) then
			dispararRayito()
		end
	end

	-- vigilante (se llama cada frame): si el input ya terminó y nadie nos avisó, suelta
	local function laserVigilar()
		if not laserHold.activo then
			if teclaLaser then
				teclaLaser = false
				actualizarBotones()
			end
			return
		end
		local inp = laserHold.input
		if inp then
			local st = inp.UserInputState
			if st == Enum.UserInputState.End or st == Enum.UserInputState.Cancel then
				laserSoltar()
			end
		end
	end

	local function laserPulsar(sigueQuieto, input)
		laserVigilar() -- si quedó algo viejo pegado, se limpia antes de empezar
		if laserHold.activo then
			return
		end
		laserHold.activo = true
		laserHold.mantenido = false
		laserHold.input = input
		laserHold.sigue = sigueQuieto
		laserHold.id += 1
		local id = laserHold.id
		task.delay(C.TOQUE_SEG, function()
			if laserHold.activo and laserHold.id == id and (not sigueQuieto or sigueQuieto()) then
				laserHold.mantenido = true
				teclaLaser = true
				actualizarBotones()
			end
		end)
	end

	local function agregarRobot()
		if not estado.visible then
			aviso("PRIMERO SACA AL ROBOT")
			return
		end
		if #extras + 1 >= C.MAX_ROBOTS then
			aviso("MÁXIMO " .. C.MAX_ROBOTS .. " ROBOTS")
			return
		end
		crearExtra()
		actualizarBotones()
		aviso(string.format("ROBOTS: %d/%d", #extras + 1, C.MAX_ROBOTS))
	end

	local function quitarRobot()
		if quitarUno() then
			actualizarBotones()
			aviso(string.format("ROBOTS: %d/%d", #extras + 1, C.MAX_ROBOTS))
		else
			aviso("SOLO QUEDA EL PRINCIPAL")
		end
	end

	local function ponerRobots(n)
		if not estado.visible then
			aviso("PRIMERO SACA AL ROBOT")
			return
		end
		n = math.clamp(math.floor(n), 1, C.MAX_ROBOTS)
		while #extras + 1 < n do
			crearExtra()
		end
		while #extras + 1 > n do
			quitarUno()
		end
		actualizarBotones()
		aviso(string.format("ROBOTS: %d/%d", #extras + 1, C.MAX_ROBOTS))
	end

	-- ===================== ATAQUE (metralleta: todos contra uno) =====================
	local function datosObjetivo(m)
		if not m or m == jugador.Character or m:IsDescendantOf(carpeta) then
			return nil
		end
		local h = m:FindFirstChildOfClass("Humanoid")
		local rp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if h and rp and h.Health > 0 then
			return m, h, rp
		end
		return nil
	end

	-- apuntar = true: primero a quien apuntas con la mira (botón/tecla).
	-- Si no apuntas a nadie (o es automático): el JUGADOR más cercano; si no hay, NPCs.
	local function buscarObjetivo(apuntar)
		local _, r = personaje()
		if not r then
			return nil
		end

		if apuntar then
			local cam = Workspace.CurrentCamera
			if cam then
				local vp = cam.ViewportSize
				local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
				local res = Workspace:Raycast(ray.Origin, ray.Direction * C.ATAQUE_ALCANCE, paramsMira)
				if res then
					local m, h, rp = datosObjetivo(modeloHumanoide(res.Instance))
					if m then
						return m, h, rp
					end
				end
			end
		end

		-- jugador más cercano
		local mejor, mejorD = nil, C.ATAQUE_ALCANCE
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= jugador and p.Character then
				local m, h, rp = datosObjetivo(p.Character)
				if m then
					local dist = (rp.Position - r.Position).Magnitude
					if dist < mejorD then
						mejorD = dist
						mejor = { m, h, rp }
					end
				end
			end
		end
		if mejor then
			return mejor[1], mejor[2], mejor[3]
		end

		-- sin jugadores: NPCs
		if C.ATAQUE_TAMBIEN_NPC then
			mejorD = C.ATAQUE_ALCANCE
			for _, d in ipairs(Workspace:GetDescendants()) do
				if d:IsA("Humanoid") and not Players:GetPlayerFromCharacter(d.Parent) then
					local m, h, rp = datosObjetivo(d.Parent)
					if m then
						local dist = (rp.Position - r.Position).Magnitude
						if dist < mejorD then
							mejorD = dist
							mejor = { m, h, rp }
						end
					end
				end
			end
			if mejor then
				return mejor[1], mejor[2], mejor[3]
			end
		end
		return nil
	end

	local function alternarAtaque()
		if ataque.activo then
			ataque.activo = false
			ataque.modelo, ataque.hum, ataque.raiz = nil, nil, nil
			actualizarBotones()
			aviso("ATAQUE: OFF")
			return
		end
		if not estado.visible then
			aviso("PRIMERO SACA AL ROBOT")
			return
		end
		local atacantes = #extras + ((estado.fase == "libre") and 1 or 0)
		if atacantes == 0 then
			aviso("NECESITAS MÁS ROBOTS (/mas)")
			return
		end
		local m, h, rp = buscarObjetivo(true)
		if not m then
			aviso("NO HAY OBJETIVO A LA VISTA")
			return
		end
		ataque.activo = true
		ataque.modelo, ataque.hum, ataque.raiz = m, h, rp
		toggleLaser = false
		cadAtaque = 0
		actualizarBotones()
		aviso("ATAQUE: " .. m.Name)
	end

	-- si el objetivo muere o desaparece: va solito por el siguiente (o termina si ya no hay)
	local function validarAtaque()
		if not ataque.activo then
			return
		end
		local ok = ataque.hum and ataque.hum.Parent and ataque.hum.Health > 0 and ataque.raiz and ataque.raiz.Parent
		if ok then
			return
		end
		if C.ATAQUE_AUTO_SIGUIENTE then
			local m, h, rp = buscarObjetivo(false)
			if m then
				ataque.modelo, ataque.hum, ataque.raiz = m, h, rp
				aviso("SIGUIENTE OBJETIVO: " .. m.Name)
				return
			end
		end
		ataque.activo = false
		ataque.modelo, ataque.hum, ataque.raiz = nil, nil, nil
		actualizarBotones()
		aviso("SIN OBJETIVOS - ATAQUE: OFF")
	end

	-- ===================== ACCIONES =====================
	local function colocarCerca()
		local _, r = personaje()
		if not r then
			return
		end
		local f = r.CFrame
		pos = r.Position + f.RightVector * C.LADO + Vector3.new(0, C.ALTURA, 0)
		vel = Vector3.zero
		local look = f.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		colocado = true
	end

	local function mostrar(v)
		if not v and estado.fase ~= "libre" then
			aviso("BÁJATE PRIMERO")
			return
		end
		estado.visible = v
		if v and ap <= 0 then
			colocado = false
		end
		if not v then
			toggleLaser = false
			prueba = false
			ataque.activo = false
			laserLiberar()
		end
		actualizarBotones()
		aviso(v and "ROBOT: ON" or "ROBOT: OFF")
	end

	-- MODO PRUEBA: el robot se queda fijo (no sigue cámara ni jugador), sale el punto verde del ojo
	-- y el láser sale recto sin cortarse. Gira la cámara y míralo de lado.
	local function alternarPrueba()
		if not estado.visible then
			aviso("PRIMERO SACA AL ROBOT")
			return
		end
		prueba = not prueba
		if prueba then
			yawFijo = yaw
			aviso("PRUEBA: ON (robot fijo)")
			print("[ROBOT] PRUEBA ON: punto verde = ojo, línea verde = frente. Dispara con LÁSER y gira la cámara. Ajusta con /ojo X Y Z")
		else
			aviso("PRUEBA: OFF")
		end
		actualizarBotones()
	end

	local function ponerModo(m)
		estado.modo = m
		aviso("MODO: " .. m)
	end

	local function alternarModo()
		ponerModo(estado.modo == "SEGUIR" and "QUIETO" or "SEGUIR")
	end

	local function traer()
		if estado.fase ~= "libre" then
			aviso("YA ESTÁS EN EL ROBOT")
			return
		end
		colocarCerca()
		if not estado.visible then
			mostrar(true)
		else
			aviso("ROBOT: AQUÍ")
		end
	end

	local function tamanoA(n)
		escalaUser = math.clamp(n, 0.05, 50)
		aviso(string.format("TAMAÑO x%.2f", escalaUser))
	end

	local function tamanoMult(m)
		tamanoA(escalaUser * m)
	end

	local function rotar(x, y, z)
		rotOff = Vector3.new(x, y, z)
		aviso(string.format("ROTACIÓN: %g, %g, %g  (cópialo a CONFIG.ROBOT.ROTACION)", x, y, z))
	end

	local function moverOjo(x, y, z)
		ojoFrac = Vector3.new(x, y, z)
		aviso(string.format("OJO: %g, %g, %g  (cópialo a CONFIG.ROBOT.OJO)", x, y, z))
	end

	local function moverAsiento(x, y, z)
		asientoFrac = Vector3.new(x, y, z)
		aviso(string.format("ASIENTO: %g, %g, %g  (cópialo a CONFIG.ROBOT.ASIENTO)", x, y, z))
	end

	local function alternarLaser()
		if not estado.visible then
			aviso("PRIMERO SACA AL ROBOT")
			return
		end
		toggleLaser = not toggleLaser
		actualizarBotones()
	end

	-- ---------- SUBIR: el robot baja a tu lado, se agacha y saltas encima ----------
	local function subir()
		if estado.fase ~= "libre" then
			return
		end
		local _, r, hum = personaje()
		if not r or hum.Health <= 0 then
			return
		end

		local chSub = jugador.Character
		if chSub then
			capturarMotores(chSub)
		end
		local yaVisible = estado.visible and ap > 0.8
		if not estado.visible then
			mostrar(true)
		end
		if not colocado then
			colocarCerca()
		end

		local look = r.CFrame.LookVector
		local yawJ = math.atan2(-look.X, -look.Z)
		local marcoJ = CFrame.Angles(0, yawJ, 0)
		local lado = C.SUBIR_LADO * math.max(escalaUser, 0.6)
		local asientoDeseado = r.Position + marcoJ.RightVector * lado + Vector3.new(0, C.SUBIR_ALTURA, 0)
		local posFin = asientoDeseado - marcoJ:VectorToWorldSpace(asientoFrac * tam() * (C.ESCALA_MONTADO / fMonta))

		-- que no se hunda en el suelo
		local res = Workspace:Raycast(r.Position, Vector3.new(0, -60, 0), paramsSuelo)
		if res then
			posFin = Vector3.new(posFin.X, math.max(posFin.Y, res.Position.Y + C.ALTURA_MINIMA * escalaUser * C.ESCALA_MONTADO), posFin.Z)
		end

		sub = {
			t = yaVisible and 0 or -C.APARECER_SEG,
			yaw = yawJ,
			posIni = pos,
			posFin = posFin,
		}
		estado.fase = "subiendo"
		actualizarBotones()
		aviso("SUBIENDO...")
	end

	-- ---------- BAJAR: saltas hacia un lado ----------
	local function bajar()
		if estado.fase ~= "montado" then
			return
		end
		local _, r, hum = personaje()
		if not r then
			abortarMontura()
			return
		end
		local frame = CFrame.Angles(0, yaw, 0)
		local dest = r.Position + frame.RightVector * C.BAJAR_LADO * math.max(escalaUser, 0.6)
		local alturaPie = hum.HipHeight + r.Size.Y / 2
		if hum.HipHeight <= 0 then
			alturaPie = 3
		end
		local res = Workspace:Raycast(dest + Vector3.new(0, 4, 0), Vector3.new(0, -80, 0), paramsSuelo)
		if res then
			dest = Vector3.new(dest.X, res.Position.Y + alturaPie, dest.Z)
		else
			dest = dest - Vector3.new(0, 4, 0)
		end
		sub = { t = 0, p0 = r.Position, rot0 = r.CFrame.Rotation, dest = dest }
		estado.fase = "bajando"
		actualizarBotones()
		aviso("BAJANDO...")
	end

	local function alternarMontura()
		if estado.fase == "libre" then
			subir()
		elseif estado.fase == "montado" then
			bajar()
		end
	end

	-- ===================== MEDIR LA MALLA (tamaño automático) =====================
	if C.TAMANO_OBJETIVO and C.TAMANO_OBJETIVO > 0 then
		task.spawn(function()
			local ok, mp = pcall(function()
				return InsertService:CreateMeshPartAsync(
					"rbxassetid://" .. C.MESH_ID,
					Enum.CollisionFidelity.Box,
					Enum.RenderFidelity.Automatic
				)
			end)
			if ok and mp then
				local s = mp.Size
				local m = math.max(s.X, s.Y, s.Z)
				if m > 0 then
					escalaBase = C.TAMANO_OBJETIVO / m * C.ESCALA
					print(string.format("[ROBOT] Malla medida: %.2f x %.2f x %.2f -> escala %.3f", s.X, s.Y, s.Z, escalaBase))
				end
				mp:Destroy()
			else
				warn("[ROBOT] No pude medir la malla (¿ID inválido o sin permiso?). Uso ESCALA = " .. tostring(C.ESCALA) .. ". Ajusta con /tamano.")
			end
		end)
	end

	-- ===================== BUCLE PRINCIPAL =====================
	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.1)
		t += dt
		laserVigilar()

		-- aparecer / desaparecer
		local objetivoAp = estado.visible and 1 or 0
		if ap ~= objetivoAp then
			local paso = dt / math.max(C.APARECER_SEG, 0.05)
			if ap < objetivoAp then
				ap = math.min(ap + paso, 1)
			else
				ap = math.max(ap - paso, 0)
			end
		end
		if ap <= 0 then
			if modelo.Parent then
				modelo.Parent = nil
			end
			colocado = false
			ocultarRayo()
			ocultarMarca()
			ocultarExtras()
			actualizarBalas(dt)
			return
		end

		local ch, r, hum = personaje()
		if not r then
			return
		end
		if not modelo.Parent then
			modelo.Parent = carpeta
		end
		if not colocado then
			colocarCerca()
		end
		local rp = r.Position
		local cam = Workspace.CurrentCamera

		-- si mueres montado, se cancela todo
		if estado.fase ~= "libre" and hum.Health <= 0 then
			abortarMontura()
		end

		validarAtaque()

		-- filtro y suelo
		tFiltro += dt
		if tFiltro > 2 then
			tFiltro = 0
			refrescarFiltro()
		end
		tSuelo += dt
		if tSuelo > 0.1 then
			tSuelo = 0
			local res = Workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -400, 0), paramsSuelo)
			sueloY = res and res.Position.Y or nil
		end

		local yawObj = yaw
		local tiltVel = vel
		local tiltMax = C.INCLINACION
		local tiltVelMax = C.VELOCIDAD
		local extraPitch = 0
		local ampBob = 1
		local limitarSuelo = true
		local objetivoF = (estado.fase == "subiendo" or estado.fase == "montado") and C.ESCALA_MONTADO or 1
		fMonta += (objetivoF - fMonta) * (1 - math.exp(-dt * 4))
		velFrac = math.clamp(vel.Magnitude / math.max(C.VUELO_VELOCIDAD, 1), 0, 1)
		movW += ((estado.fase == "montado" and 1 or 0) - movW) * (1 - math.exp(-dt * 5))

		-- ---------- A) MOVER AL ROBOT SEGÚN LA FASE ----------
		if estado.fase == "libre" then
			local deseada = Vector3.zero
			local atacandoMain = ataque.activo and ataque.raiz ~= nil and ataque.raiz.Parent ~= nil
			if atacandoMain then
				-- ATAQUE: el principal tambien rodea al objetivo (si no vas montado)
				local n = #extras + 1
				local ang = (1 / n) * math.pi * 2 + t * C.ATAQUE_GIRO
				local dest = ataque.raiz.Position + Vector3.new(math.cos(ang) * C.ATAQUE_RADIO, C.ATAQUE_ALTURA, math.sin(ang) * C.ATAQUE_RADIO)
				deseada = (dest - pos) * 3
				if deseada.Magnitude > C.EXTRAS_VELOCIDAD then
					deseada = deseada.Unit * C.EXTRAS_VELOCIDAD
				end
			elseif estado.modo == "SEGUIR" and not prueba then
				local f = r.CFrame
				local objetivo = rp + f.RightVector * C.LADO - f.LookVector * C.ATRAS + Vector3.new(0, C.ALTURA, 0)
				if (objetivo - pos).Magnitude > C.TELEPORT_DIST then
					colocarCerca()
				end
				deseada = (objetivo - pos) * 3
				if deseada.Magnitude > C.VELOCIDAD then
					deseada = deseada.Unit * C.VELOCIDAD
				end
			end
			vel = vel:Lerp(deseada, 1 - math.exp(-dt * C.SUAVIDAD))
			pos = pos + vel * dt
			tiltVel = vel

			local look = r.CFrame.LookVector
			yawObj = math.atan2(-look.X, -look.Z)
			local aimYaw = nil
			if atacandoMain then
				aimYaw = ataque.raiz.Position
			elseif aimActual and rayoAlpha > 0.05 then
				aimYaw = aimActual
			elseif aimTap and os.clock() < aimTapHasta then
				aimYaw = aimTap
			end
			if aimYaw then
				local d = aimYaw - pos
				if d.X * d.X + d.Z * d.Z > 1 then
					yawObj = math.atan2(-d.X, -d.Z)
				end
			end

		elseif estado.fase == "subiendo" and sub then
			sub.t += dt
			local up = suave(sub.t / C.SUBIR_PREP_SEG)
			pos = sub.posIni:Lerp(sub.posFin, up)
			vel = Vector3.zero
			tiltVel = Vector3.zero
			yawObj = sub.yaw
			extraPitch = math.rad(-10) * math.sin(math.pi * up)
			limitarSuelo = false

		elseif estado.fase == "montado" then
			local mv = vectorMovimiento(hum)
			if mv.Magnitude > 1 then
				mv = mv.Unit
			end
			local cf = cam and cam.CFrame or r.CFrame
			local dirIn = cf.RightVector * mv.X + cf.LookVector * (-mv.Z)
			local arriba = 0
			if UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump or (os.clock() - ultimoSalto) < 0.15 then
				arriba += 1
			end
			if UIS:IsKeyDown(C.TECLA_BAJAR_VUELO) then
				arriba -= 1
			end
			local deseada = dirIn * C.VUELO_VELOCIDAD + Vector3.new(0, arriba * C.VUELO_VERTICAL, 0)
			vel = vel:Lerp(deseada, 1 - math.exp(-dt * C.VUELO_SUAVIDAD))
			pos = pos + vel * dt
			tiltVel = vel
			tiltMax = C.INCLINACION_VUELO
			tiltVelMax = C.VUELO_VELOCIDAD
			ampBob = 0.3

			local cl = cf.LookVector
			yawObj = math.atan2(-cl.X, -cl.Z)

		elseif estado.fase == "bajando" and sub then
			sub.t += dt
			vel = vel:Lerp(Vector3.zero, 1 - math.exp(-dt * 3))
			pos = pos + vel * dt
			tiltVel = vel
			ampBob = 0.3
		end

		-- no atravesar el suelo (con suavidad)
		if limitarSuelo and sueloY then
			local alturaMin = C.ALTURA_MINIMA
			local ritmo = 8
			if estado.fase == "montado" then
				alturaMin = C.ALTURA_MONTADO
				ritmo = 3 -- despegue suave
			end
			local minimo = sueloY + alturaMin * escalaUser
			if pos.Y < minimo then
				pos = pos + Vector3.new(0, (minimo - pos.Y) * (1 - math.exp(-dt * ritmo)), 0)
			end
		end

		-- PRUEBA: el robot no gira con la cámara ni contigo (queda mirando a donde estaba)
		if prueba and (estado.fase == "libre" or estado.fase == "montado") then
			yawObj = yawFijo
		end

		-- ---------- B) ORIENTACIÓN Y MARCO DEL ROBOT ----------
		local dif = (yawObj - yaw + math.pi) % (2 * math.pi) - math.pi
		yaw += dif * (1 - math.exp(-dt * 8))

		local marcoYaw = CFrame.Angles(0, yaw, 0)
		local vLocal = marcoYaw:VectorToObjectSpace(tiltVel)
		local k = math.rad(tiltMax) / math.max(tiltVelMax, 1)
		local bob = math.sin(t * C.FLOTAR_VEL) * C.FLOTAR_AMP * escalaUser * ampBob
		marcoActual = CFrame.new(pos + Vector3.new(0, bob, 0))
			* marcoYaw
			* CFrame.Angles(vLocal.Z * k + extraPitch, 0, -vLocal.X * k)

		-- ---------- C) TU PERSONAJE SEGÚN LA FASE ----------
		if estado.fase == "subiendo" and sub and sub.t >= C.SUBIR_PREP_SEG then
			if not sub.saltando then
				sub.saltando = true
				sub.p0 = r.Position
				sub.rot0 = r.CFrame.Rotation
				if next(motores) == nil then
					capturarMotores(ch)
				end
				hum.PlatformStand = true
				hum.AutoRotate = false
			end
			local u = math.clamp((sub.t - C.SUBIR_PREP_SEG) / C.SUBIR_SALTO_SEG, 0, 1)
			local e = suave(u)
			local asiento = marcoActual * CFrame.new(asientoFrac * tam())
			local p = sub.p0:Lerp(asiento.Position, e) + Vector3.new(0, C.SUBIR_ARCO * math.sin(math.pi * u), 0)
			local rotAsiento = marcoActual.Rotation * CFrame.Angles(math.rad(-C.INCLINAR_CUERPO), 0, 0)
			colocarPersonaje(r, CFrame.new(p) * sub.rot0:Lerp(rotAsiento, e))
			aplicarPose(math.sin(math.pi * u), e * e, suave((u - 0.5) * 2))
			if u >= 1 then
				estado.fase = "montado"
				sub = nil
				rebote = 0.14
				actualizarBotones()
				aviso("MONTADO: joystick = volar | salto = subir | LÁSER = disparar")
			end

		elseif estado.fase == "subiendo" and sub and sub.t >= 0 then
			aplicarPose(0.6 * suave(sub.t / C.SUBIR_PREP_SEG), 0, 0) -- levantas pierna y brazos para trepar

		elseif estado.fase == "montado" then
			colocarPersonaje(r, marcoActual * CFrame.new(asientoFrac * tam()) * CFrame.Angles(math.rad(-C.INCLINAR_CUERPO), 0, 0))
			aplicarPose(0, 1, 1)
			tAnim += dt
			if tAnim > 0.3 then
				tAnim = 0
				pararAnimaciones(hum)
			end

		elseif estado.fase == "bajando" and sub then
			local u = math.clamp(sub.t / C.BAJAR_SEG, 0, 1)
			local e = suave(u)
			local p = sub.p0:Lerp(sub.dest, e) + Vector3.new(0, C.BAJAR_ARCO * math.sin(math.pi * u), 0)
			colocarPersonaje(r, CFrame.new(p) * sub.rot0:Lerp(CFrame.Angles(0, yaw, 0), e))
			aplicarPose(math.sin(math.pi * u), 1 - e, 1 - suave(u * 2))
			if u >= 1 then
				soltarMotores()
				pcall(function()
					hum.PlatformStand = false
					hum.AutoRotate = true
					hum:ChangeState(Enum.HumanoidStateType.Freefall)
				end)
				sub = nil
				estado.fase = "libre"
				actualizarBotones()
				aviso("ROBOT: MASCOTA")
			end
		end

		-- ---------- D) LÁSER ----------
		actualizarRayo(dt)
		actualizarMarca()
		actualizarBalas(dt)
		actualizarAtaquePrincipal(dt)
		actualizarExtras(dt)

		-- ---------- E) VISUAL DEL ROBOT ----------
		rebote = math.max(0, rebote - dt * 0.8)
		local a = ap * ap * (3 - 2 * ap)
		malla.Scale = Vector3.one * math.max(a, 0.001) * escalaBase * escalaUser * fMonta * (1 - rebote)
		raiz.CFrame = marcoActual
			* CFrame.Angles(math.rad(rotOff.X), math.rad(rotOff.Y), math.rad(rotOff.Z))
	end)

	-- ===================== TECLAS =====================
	con(UIS.JumpRequest, function()
		ultimoSalto = os.clock()
	end)

	con(UIS.InputBegan, function(input, procesado)
		if procesado then
			return
		end
		local kc = input.KeyCode
		if kc == C.TECLA_VISIBLE then
			mostrar(not estado.visible)
		elseif kc == C.TECLA_MONTAR then
			alternarMontura()
		elseif kc == C.TECLA_LASER then
			laserPulsar(nil, input)
		elseif kc == C.TECLA_TRAER then
			traer()
		elseif kc == C.TECLA_MODO then
			alternarModo()
		elseif kc == C.TECLA_MAS then
			tamanoMult(1.25)
		elseif kc == C.TECLA_MENOS then
			tamanoMult(0.8)
		elseif kc == C.TECLA_MAS_ROBOT then
			agregarRobot()
		elseif kc == C.TECLA_MENOS_ROBOT then
			quitarRobot()
		elseif kc == C.TECLA_ATACAR then
			alternarAtaque()
		end
	end)

	con(UIS.InputEnded, function(input)
		if input.KeyCode == C.TECLA_LASER then
			laserSoltar()
		end
	end)

	-- ===================== BOTONES (movibles, respetan el candado) =====================
	Shared.HacerMovible(botonVer, function()
		mostrar(not estado.visible)
	end, con)
	Shared.HacerMovible(botonMontar, alternarMontura, con)
	-- LÁSER: solo arrastrable con el candado abierto; el toque / mantener lo manejo aquí
	local laserPos = nil
	local function laserQuieto()
		return botonLaser.Position == laserPos
	end
	Shared.HacerMovible(botonLaser, function() end, con)
	con(botonLaser.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			laserPos = botonLaser.Position
			laserPulsar(laserQuieto, input)
		end
	end)
	-- se suelta por el botón, por el input global, por el vigilante (cada frame) o al perder foco
	con(botonLaser.InputEnded, function(input)
		if input == laserHold.input then
			laserSoltar()
		end
	end)
	con(UIS.InputEnded, function(input)
		if input == laserHold.input then
			laserSoltar()
		end
	end)
	con(UIS.WindowFocusReleased, laserLiberar)
	Shared.HacerMovible(botonPrueba, alternarPrueba, con)
	Shared.HacerMovible(botonAtacar, alternarAtaque, con)

	-- ===================== RESPAWN =====================
	con(jugador.CharacterAdded, function()
		abortarMontura()
		colocado = false
		ataque.activo = false
		laserLiberar()
		actualizarBotones()
		refrescarFiltro()
	end)

	-- ===================== COMANDOS DE CHAT =====================
	if C.COMANDOS_CHAT then
		con(jugador.Chatted, function(msg)
			local m = string.lower(msg)
			if m == "/robot" then
				if estado.visible then
					traer()
				else
					mostrar(true)
				end
			elseif m == "/ocultar" then
				mostrar(false)
			elseif m == "/seguir" then
				ponerModo("SEGUIR")
			elseif m == "/quieto" then
				ponerModo("QUIETO")
			elseif m == "/aqui" then
				traer()
			elseif m == "/subir" then
				subir()
			elseif m == "/bajar" then
				bajar()
			elseif m == "/laser" then
				alternarLaser()
			elseif m == "/prueba" then
				alternarPrueba()
			elseif m == "/mas" then
				agregarRobot()
			elseif m == "/menos" then
				quitarRobot()
			elseif m == "/atacar" then
				alternarAtaque()
			elseif m == "/tamano+" then
				tamanoMult(1.25)
			elseif m == "/tamano-" then
				tamanoMult(0.8)
			elseif m:match("^/pierna%s") then
				local nums = {}
				for n in m:gmatch("%-?[%d%.]+") do
					table.insert(nums, tonumber(n))
				end
				if #nums >= 4 then
					pierna.cad, pierna.abrir, pierna.rod, pierna.tob = nums[1], nums[2], nums[3], nums[4]
					if nums[5] then
						pierna.cerrar = nums[5]
					end
					armarPiernas()
					aviso(string.format("PIERNAS: %g %g %g %g %g  (cópialo a CONFIG.ROBOT.PIERNAS)", pierna.cad, pierna.abrir, pierna.rod, pierna.tob, pierna.cerrar))
				else
					aviso("USO: /pierna CADERA ABRIR RODILLA TOBILLO [CERRAR]")
				end
			else
				local nr = tonumber(m:match("^/robots%s+(%d+)$"))
				if nr then
					ponerRobots(nr)
					return
				end
				local n = tonumber(m:match("^/tamano%s+([%d%.]+)$"))
				if n then
					tamanoA(n)
					return
				end
				local num = "(%-?[%d%.]+)"
				local x, y, z = m:match("^/rot%s+" .. num .. "%s+" .. num .. "%s+" .. num .. "$")
				if x and y and z then
					rotar(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
					return
				end
				x, y, z = m:match("^/ojo%s+" .. num .. "%s+" .. num .. "%s+" .. num .. "$")
				if x and y and z then
					moverOjo(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
					return
				end
				x, y, z = m:match("^/asiento%s+" .. num .. "%s+" .. num .. "%s+" .. num .. "$")
				if x and y and z then
					moverAsiento(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
					return
				end
				local lado, mx, my, mz = m:match("^/mano%s+(%a+)%s+" .. num .. "%s+" .. num .. "%s+" .. num .. "$")
				if lado and mx and my and mz then
					local g = Vector3.new(tonumber(mx) or 0, tonumber(my) or 0, tonumber(mz) or 0)
					if lado == "der" then
						gripDer = g
					elseif lado == "izq" then
						gripIzq = g
					else
						return
					end
					aviso(string.format("MANO %s: %g, %g, %g  (cópialo a CONFIG.ROBOT.GRIP_%s)", string.upper(lado), g.X, g.Y, g.Z, string.upper(lado)))
				end
			end
		end)
	end

	-- ===================== ROBOTS INICIALES =====================
	for _ = 2, math.clamp(C.ROBOTS_INICIALES, 1, C.MAX_ROBOTS) do
		crearExtra()
	end

	-- ===================== LIMPIEZA =====================
	env.ROBOT_LIMPIAR = function()
		pcall(abortarMontura)
		for _, c in ipairs(conexiones) do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(conexiones)
		pcall(function()
			carpeta:Destroy()
		end)
		pcall(function()
			gui:Destroy()
		end)
	end

	print("[ROBOT] Cargado. Botones ROBOT / SUBIR / LÁSER / PRUEBA / ATACAR | Teclas B E U Y M N H T | chat: /robot /subir /bajar /laser /prueba /ojo /asiento /rot /tamano")
end

--##########################################################################
-- ARRANQUE
--##########################################################################
task.spawn(function()
	local ok, err = pcall(crearCandado)
	if not ok then
		warn("[ROBOT] Falló el candado: " .. tostring(err))
	end
end)

local ok, err = pcall(MODULO_ROBOT)
if not ok then
	warn("[ROBOT] Falló el módulo: " .. tostring(err))
end
