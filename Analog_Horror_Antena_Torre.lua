--!nonstrict
-- ============================================================
-- ANALOG HORROR - LA ANTENA CAMINANTE & LA TORRE (LocalScript / Delta) - solo tú lo ves
--
--  1) VHS         : overlay analógico (líneas de escaneo, ruido, bandas de tracking,
--                   viñeta), indicador REC con fecha ficticia y pantalla "SEÑAL PERDIDA"
--  2) PROXIMIDAD  : atmósfera del mapa (niebla, luz, color), sacudida suave de cámara
--                   y reverb; todo crece poco a poco según qué tan cerca están las criaturas
--  3) AUDIO       : ambiente + estática que sube con la interferencia (IDs los pones tú)
--  4) ANTENA      : ANTENA CAMINANTE. Antena Yagi sobre 3 patas largas articuladas (IK),
--                   cable colgando. Estados: PATRULLAR / OBSERVAR / REPOSICION / ACERCAR /
--                   PERSEGUIR / ATAQUE (solo pérdida de señal) / OCULTA
--  5) TORRE       : LA TORRE. Colosal, 4 patas enormes, columna de 6 segmentos que se
--                   dobla, platos, látigos, cables y masas orgánicas que pulsan.
--                   Fases: OCULTA / HORIZONTE / ACERCANDOSE / EVENTO / DESAPARECIENDO
--  6) DIRECTOR    : eventos de terror (apagón de señal, radio, luces, distorsión)
--  7) CAMARA      : visor de videocámara VHS: pila que se gasta, zoom, enfoque que falla,
--                   cinta, mano temblorosa, arranque de cámara, apagado por pila y subtítulos
--  8) CONTROL     : teclas y comandos de chat (botones solo para el zoom en celular)
--
-- CONTROLES:
--   V = VHS ON/OFF | B = MODO SUAVE (sin parpadeos ni sacudidas) | N = sonidos ON/OFF
--   Z / X = zoom (mantén) | C = cámara ON/OFF
--   Chat: /vhs  /suave  /sonido  /antena (la llama)  /torre (la llama)  /ocultar
--         /camara  /zoom+  /zoom-  /zoom 3  /bateria  /persona  /autozoom
--   En celular: botones + y - de zoom a la derecha, y los comandos de chat.
--
-- SINCRONÍA: es un script local, pero la Torre y los eventos del DIRECTOR usan el reloj
--   del servidor con semilla compartida: todos los que ejecuten este script ven la
--   misma fase de la Torre y los mismos eventos al mismo tiempo.
--
-- Cada módulo corre aislado: si uno falla, los demás siguen.
-- Si re-ejecutas, cada módulo limpia su versión anterior.
-- ============================================================

--##########################################################################
-- SERVICIOS
--##########################################################################
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local PathfindingService = game:GetService("PathfindingService")
local jugador = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

--##########################################################################
-- CONFIGURACIÓN  (cambia aquí IDs, teclas y límites; todo lo demás se adapta)
--##########################################################################
local CONFIG = {
	-- ---------- GENERAL ----------
	CALIDAD = "media",               -- "baja" (Android modesto) | "media" | "alta"
	AVISAR_SONIDOS_VACIOS = true,    -- imprime en consola qué sonidos faltan por poner
	AVISOS_EN_PANTALLA = true,       -- texto chico al activar/desactivar efectos

	-- ---------- CONTROLES (sin botones en pantalla) ----------
	TECLA_VHS = Enum.KeyCode.V,
	TECLA_SUAVE = Enum.KeyCode.B,
	TECLA_SONIDO = Enum.KeyCode.N,
	TECLA_CAMARA = Enum.KeyCode.C,   -- cámara VHS ON/OFF
	TECLA_ZOOM_MAS = Enum.KeyCode.Z, -- mantén para acercar
	TECLA_ZOOM_MENOS = Enum.KeyCode.X, -- mantén para alejar
	COMANDOS_CHAT = true,            -- /vhs /suave /sonido /antena /torre /ocultar /camara /zoom+ /zoom- /zoom N /bateria /persona /autozoom

	-- ---------- VHS ----------
	VHS = {
		ACTIVO = true,
		MODO_SUAVE = false,          -- true = sin parpadeo REC, sin sacudida, ruido y señal perdida atenuados
		LINEAS_TRANSP = 0.9,         -- transparencia de las líneas de escaneo (más alto = más tenues)
		REC_PARPADEA = true,         -- el punto REC parpadea lento (1 vez por segundo)
		SACUDIDA_CAMARA = true,
		SENAL_VEL = 2.5,             -- qué tan rápido entra/sale "SEÑAL PERDIDA" (por seg; bajo = más suave)
		SENAL_MAX = 0.9,             -- opacidad máxima de la pantalla de señal perdida
		FECHA = { mes = "SEP", dia = 12, ano = 1997, h = 23, m = 41, s = 7 },
	},

	-- ---------- CÁMARA VHS (visor de videocámara) ----------
	CAMARA = {
		ACTIVA = true,               -- al ejecutar ya se ve como cámara
		PRIMERA_PERSONA = true,      -- ves desde la cámara (primera persona fija); /persona lo cambia
		INTRO = true,                -- al ejecutar: estática, "CARGANDO CINTA" y PLAY
		MANO_TEMBLOROSA = true,      -- la cámara tiembla un poco, más con zoom e interferencia
		POLVO = true,                -- motas flotando en el aire
		FOV_BASE = 70,               -- campo de visión sin zoom (0 = usar el actual)
		-- Zoom
		ZOOM_MIN = 1,
		ZOOM_MAX = 6,
		ZOOM_VEL = 1.0,              -- velocidad al mantener Z/X o los botones
		ZOOM_SUAVE = 6,              -- qué tan rápido llega al zoom pedido (más alto = más seco)
		ZOOM_PASO = 1.35,            -- multiplicador por cada /zoom+ o /zoom-
		AUTO_ZOOM = false,           -- si apuntas a una criatura, la cámara se acerca sola
		BOTONES_TACTIL = true,       -- botones + y - de zoom (solo celular). false = sin botones
		-- Pila
		BATERIA_MIN = 14,            -- minutos que dura la pila en calma
		BATERIA_CRIATURAS = 2.5,     -- se gasta hasta X veces más rápido con la interferencia al máximo
		BATERIA_AGOTA = true,        -- al llegar a 0 la cámara se apaga unos segundos
		BATERIA_REINICIO = 0.35,     -- pila con la que vuelve a encender
		APAGADO_SEG = 5,             -- segundos que se queda apagada
		-- Subtítulos al estilo de los videos (texto grande blanco abajo)
		SUBTITULOS = true,
		SUBT_MIN = 70, SUBT_MAX = 150,
		MENSAJES = { "NOCHE", "CALLADA", "NADIE", "HACIA TI", "SE MOVIÓ", "NO LA MIRES", "SIGUE AHÍ", "TE ESCUCHA" },
	},

	-- ---------- PROXIMIDAD / ATMÓSFERA ----------
	PROXIMIDAD = {
		SUAVIZADO = 0.6,             -- qué tan lento cambia la atmósfera (más bajo = más gradual)
		FOG_MIN = 900,               -- distancia de niebla cuando la Torre está encima
		FOG_COLOR = Color3.fromRGB(38, 22, 18),
		TINTE_TORRE = Color3.fromRGB(255, 226, 196),
		TINTE_ANTENA = Color3.fromRGB(214, 255, 238),
		REVERB_TORRE = true,         -- reverb de cueva cuando la Torre está muy cerca
	},

	-- ---------- ANTENA CAMINANTE ----------
	ANTENA = {
		ESCALA = 1,
		DIPOLOS = 9,
		INICIO_ESPERA = 25,          -- segundos antes de la primera aparición
		APARECER_MIN = 160,          -- distancia mínima/máxima de aparición (siempre lejos)
		APARECER_MAX = 260,
		OCULTA_MIN = 25, OCULTA_MAX = 55,
		VEL_PATRULLA = 6,
		VEL_ACERCAR = 5,
		VEL_PERSEGUIR = 20,          -- un poco más rápida que caminar, no que correr
		GIRO = 1.6,                  -- rad/seg que puede girar el cuerpo
		DIST_VER = 450,              -- a esta distancia ya "te nota" (si hay línea de vista)
		DIST_ZONA = 380,             -- si está más lejos que esto, patrulla hacia ti
		DIST_MANTENER = 45,          -- al acercarse se detiene a esta distancia a observarte
		DIST_PERSEGUIR = 80,         -- desde aquí puede perseguir (si está agresiva)
		DIST_ATAQUE = 14,
		PERSECUCION_MAX = 11,        -- segundos máximo de persecución
		AGRESIVIDAD_INICIAL = 0.15,
		AGRESIVIDAD_POR_MIN = 0.12,  -- sube sola con el tiempo
		UMBRAL_PERSEGUIR = 0.55,
		OBSERVA_MIN = 4, OBSERVA_MAX = 9,
		ATAQUE_SEG = 1.6,            -- duración de la pérdida de señal del ataque
		DANO = 0,                    -- 0 = el ataque solo corta la señal (sin daño). Daño solo en tu pantalla.
		INTERF_MIN = 25,             -- interferencia al 100% a esta distancia
		INTERF_MAX = 230,            -- interferencia empieza a esta distancia
		FUNDIDO = 3,                 -- segundos de fundido al aparecer
		LOD_DIST = 500,              -- más lejos que esto anima a menos FPS
		-- Pathfinding (si falla, usa movimiento directo esquivando obstáculos altos)
		PATHFINDING = true,
		PATH_RADIO = 3,
		PATH_ALTURA = 6,
		PATH_REFRESCO = 1.6,
	},

	-- ---------- LA TORRE ----------
	TORRE = {
		ALTURA = 260,                -- alto de la columna (sin contar las patas)
		ANCHO_BASE = 46,
		CADERA_ALTO = 62,            -- a qué altura empieza la columna sobre el suelo
		PIERNA_LARGO = 48,           -- largo de cada hueso de las patas (2 por pata)
		PIERNA_GROSOR = 5.5,
		RADIO_CADERA = 14,
		RADIO_PIE = 64,
		DIST_APARECER = 760,
		DIST_MIN = 400,              -- se queda a esta distancia como mínimo
		DIST_ALCANCE = 1500,         -- desde aquí empieza a notarse su presencia
		VEL_ACERCAR = 3,             -- studs/seg (extremadamente lenta para su tamaño)
		FUNDIDO = 8,
		ALFA_MAX = 0.92,             -- nunca totalmente sólida: parcialmente visible
		POSTURA_SEG = 25,            -- cada cuánto cambia de postura
		POSTURA_GRAD = 3.2,          -- grados máximos de doblez por segmento
		POSTURA_TAU = 8,             -- qué tan lento se acomoda a la postura nueva
		CICLO = 420,                 -- duración del ciclo completo (segundos, reloj del servidor)
	},

	-- ---------- DIRECTOR DE EVENTOS ----------
	DIRECTOR = {
		SLOT_SEG = 40,               -- cada slot puede traer un evento (igual para todos)
		PROB_SLOT = 0.35,
		APAGON_SEG = 1.4,
		ANTENA_MIN = 90, ANTENA_MAX = 180,   -- cada cuánto "sugiere" que aparezca la Antena (local)
	},

	-- ---------- AUDIO ----------
	AUDIO = {
		AMBIENTE_VOL = 0.35,
		ESTATICA_VOL = 0.7,
	},

	-- ---------- SONIDOS (pon aquí TUS IDs; "" = ese sonido no se usa) ----------
	-- No inventé ningún ID. Sin IDs todo funciona igual, solo en silencio.
	SONIDOS = {
		AMBIENTE = "",         -- viento nocturno / ciudad lejana (loop)
		ESTATICA = "",         -- estática de TV (loop); sube con la interferencia
		SENAL_PERDIDA = "",    -- golpe de estática corto
		RADIO = "",            -- ráfaga de radio / voces entrecortadas
		ANTENA_ZUMBIDO = "",   -- chisporroteo metálico (loop, posicional)
		ANTENA_PASO = "",      -- paso metálico (posicional)
		ANTENA_CHIRRIDO = "",  -- chirrido de metal (posicional)
		TORRE_ZUMBIDO = "",    -- zumbido grave (loop, posicional)
		TORRE_PASO = "",       -- golpe pesado de pata (posicional)
		CAMARA_ENCENDER = "", -- clic + zumbido de cámara al encender
		CAMARA_APAGAR = "",   -- apagado de TV vieja
		ZOOM_MOTOR = "",      -- motorcito del zoom
		BATERIA_BEEP = "",    -- pitido de pila baja
	},
}

--##########################################################################
-- ESTADO  (compartido entre módulos)
--##########################################################################
local Shared = {
	Ajustes = {
		vhs = CONFIG.VHS.ACTIVO, suave = CONFIG.VHS.MODO_SUAVE, sonido = true,
		camara = CONFIG.CAMARA.ACTIVA, primera = CONFIG.CAMARA.PRIMERA_PERSONA, autozoom = CONFIG.CAMARA.AUTO_ZOOM,
	},
	Interf = { antena = 0, torre = 0, evento = 0 },   -- 0..1, lo escriben las criaturas
	Mundo = nil,        -- helpers (abajo)
	Antena = nil,       -- API de la antena: forzar() / sugerir() / ocultar()
	Torre = nil,        -- API de la torre: forzar() / ocultar()
	-- Los módulos añaden: senalPerdida, pulso, luces, Vibrar, vib, reproducir, evento, aviso, hud, Camara, subtitulo
}

local PRESETS = {
	baja  = { lineas = 24, motas = 16, bandas = 1, platos = 3, latigos = 4, cables = 3, torreSeg = 5, torreFps = 15 },
	media = { lineas = 40, motas = 30, bandas = 2, platos = 5, latigos = 6, cables = 4, torreSeg = 6, torreFps = 24 },
	alta  = { lineas = 60, motas = 48, bandas = 3, platos = 7, latigos = 9, cables = 6, torreSeg = 6, torreFps = 30 },
}
local Q = PRESETS[CONFIG.CALIDAD] or PRESETS.media

--##########################################################################
-- HELPERS COMPARTIDOS: partes, raycast, puntos válidos, sonido, IK y marcha de patas
--##########################################################################
local Mundo = {}
Shared.Mundo = Mundo
do
	if env.AH_HELPERS_LIMPIAR then
		pcall(env.AH_HELPERS_LIMPIAR)
	end

	local viejo = Workspace:FindFirstChild("AnalogHorror_Entidades")
	if viejo then
		viejo:Destroy()
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "AnalogHorror_Entidades"
	carpeta.Parent = Workspace
	Mundo.carpeta = carpeta

	local viejoGrupo = SoundService:FindFirstChild("AnalogHorrorSonido")
	if viejoGrupo then
		viejoGrupo:Destroy()
	end
	local grupo = Instance.new("SoundGroup")
	grupo.Name = "AnalogHorrorSonido"
	grupo.Volume = 1
	grupo.Parent = SoundService
	Mundo.grupoSonido = grupo

	-- Raycast: ignora a todos los personajes y a las criaturas
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	Mundo.params = params

	local vivo = true
	local function refrescarParams()
		local lista = { carpeta }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(lista, p.Character)
			end
		end
		params.FilterDescendantsInstances = lista
	end
	refrescarParams()
	task.spawn(function()
		while vivo do
			task.wait(3)
			pcall(refrescarParams)
		end
	end)

	env.AH_HELPERS_LIMPIAR = function()
		vivo = false
		pcall(function() carpeta:Destroy() end)
		pcall(function() grupo:Destroy() end)
	end

	function Mundo.rand(a, b)
		return a + math.random() * (b - a)
	end

	function Mundo.angDif(a, b)
		return (a - b + math.pi) % (2 * math.pi) - math.pi
	end

	function Mundo.raiz()
		local c = jugador.Character
		return c and c:FindFirstChild("HumanoidRootPart") or nil
	end

	function Mundo.rayo(origen, dir)
		return Workspace:Raycast(origen, dir, params)
	end

	-- Suelo bajo una posición (ignora agua). Devuelve el resultado del raycast o nil.
	function Mundo.suelo(pos, arriba, abajo)
		arriba = arriba or 30
		abajo = abajo or 200
		local r = Workspace:Raycast(pos + Vector3.new(0, arriba, 0), Vector3.new(0, -(arriba + abajo), 0), params)
		if r and r.Material == Enum.Material.Water then
			return nil
		end
		return r
	end

	-- Punto válido (suelo plano, tejados incluidos) alrededor de "centro".
	-- ang0/spread opcionales para sesgar la dirección. Devuelve posición y ángulo, o nil.
	function Mundo.puntoValido(centro, dmin, dmax, ang0, spread, intentos)
		for _ = 1, (intentos or 14) do
			local ang
			if ang0 then
				ang = ang0 + (math.random() - 0.5) * (spread or math.pi * 2)
			else
				ang = math.random() * math.pi * 2
			end
			local d = dmin + math.random() * (dmax - dmin)
			local p = centro + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
			local r = Mundo.suelo(Vector3.new(p.X, centro.Y, p.Z), 220, 360)
			if r and r.Normal.Y > 0.6 and math.abs(r.Position.Y - centro.Y) < 160 then
				return r.Position, ang
			end
		end
		return nil
	end

	function Mundo.enPantalla(pos)
		local cam = Workspace.CurrentCamera
		if not cam then
			return false
		end
		local v, dentro = cam:WorldToViewportPoint(pos)
		return dentro and v.Z > 0
	end

	function Mundo.lineaVista(origen, destino)
		return Workspace:Raycast(origen, destino - origen, params) == nil
	end

	function Mundo.mirar(pos, dir)
		if dir.Magnitude < 1e-4 then
			return CFrame.new(pos)
		end
		local u = dir.Unit
		local arriba = math.abs(u.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
		return CFrame.lookAt(pos, pos + u, arriba)
	end

	function Mundo.parte(padre, nombre, tam, color, material, forma)
		local p = Instance.new("Part")
		p.Name = nombre
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = tam
		p.Color = color
		p.Material = material or Enum.Material.Metal
		if forma then
			p.Shape = forma
		end
		p.Parent = padre
		return p
	end

	-- Estira una parte (bloque delgado) entre dos puntos
	function Mundo.segmento(p, a, b, grosor)
		local d = b - a
		local l = d.Magnitude
		if l < 0.05 then
			return
		end
		p.Size = Vector3.new(grosor, grosor, l)
		p.CFrame = Mundo.mirar((a + b) / 2, d)
	end

	-- Fundido de todo un modelo: a = 1 visible, 0 invisible
	function Mundo.alfa(modelo, a)
		for _, d in ipairs(modelo:GetDescendants()) do
			if d:IsA("BasePart") then
				local t0 = d:GetAttribute("T0")
				if t0 == nil then
					t0 = d.Transparency
					d:SetAttribute("T0", t0)
				end
				d.Transparency = 1 - (1 - t0) * a
			end
		end
	end

	-- Sonido con tu ID de CONFIG.SONIDOS (nil si no pusiste ID)
	local avisado = {}
	function Mundo.sonido(padre, clave, vol, minD, maxD, loop)
		local id = CONFIG.SONIDOS[clave]
		if not id or id == "" then
			if CONFIG.AVISAR_SONIDOS_VACIOS and not avisado[clave] then
				avisado[clave] = true
				print("[ANALOG HORROR] Sonido vacío (opcional): " .. clave)
			end
			return nil
		end
		local s = Instance.new("Sound")
		s.Name = clave
		s.SoundId = "rbxassetid://" .. id
		s.Volume = vol or 1
		s.Looped = loop or false
		s.SoundGroup = grupo
		if minD and maxD then
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = minD
			s.RollOffMaxDistance = maxD
		end
		s.Parent = padre
		return s
	end

	-- Rodilla de una pata de 2 huesos (IK). Devuelve rodilla y pie (limitado al alcance).
	function Mundo.rodilla(H, F, a, b, polo)
		local v = F - H
		local mag = v.Magnitude
		if mag < 0.1 then
			return H + Vector3.new(0, -a, 0), H + Vector3.new(0, -a - b, 0)
		end
		local d = math.clamp(mag, 0.1, a + b - 0.05)
		local u = v / mag
		local perp = polo - u * polo:Dot(u)
		if perp.Magnitude < 1e-3 then
			perp = Vector3.xAxis - u * u.X
		end
		perp = perp.Unit
		local along = (a * a - b * b + d * d) / (2 * d)
		local h = math.sqrt(math.max(a * a - along * along, 0))
		return H + u * along + perp * h, H + u * d
	end

	-- Marcha de patas articuladas (la usan la Antena y la Torre)
	-- cfg: n, giro, largo1, largo2, grosor, radioCadera, radioPie, caderaY, umbral, altura,
	--      tiempoPaso, irregular, anticipo, maxLev, poloArriba, color, colorJunta, onPaso(pos)
	function Mundo.nuevaMarcha(padre, cfg)
		local M = { patas = {}, cfg = cfg }
		local g = cfg.grosor
		for i = 1, cfg.n do
			local ang = (i - 1) / cfg.n * math.pi * 2 + (cfg.giro or 0)
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			table.insert(M.patas, {
				dir = dir,
				hipLocal = dir * cfg.radioCadera + Vector3.new(0, cfg.caderaY or 0, 0),
				pieLocal = dir * cfg.radioPie,
				muslo = Mundo.parte(padre, "Muslo" .. i, Vector3.new(g, g, 1), cfg.color),
				canilla = Mundo.parte(padre, "Canilla" .. i, Vector3.new(g * 0.8, g * 0.8, 1), cfg.color),
				rodilla = Mundo.parte(padre, "Rodilla" .. i, Vector3.new(g * 1.9, g * 1.9, g * 1.9), cfg.colorJunta, Enum.Material.Metal, Enum.PartType.Ball),
				cadera = Mundo.parte(padre, "Cadera" .. i, Vector3.new(g * 2.2, g * 2.2, g * 2.2), cfg.colorJunta, Enum.Material.Metal, Enum.PartType.Ball),
				punta = Mundo.parte(padre, "Punta" .. i, Vector3.new(g * 1.3, g * 1.3, g * 3.5), cfg.colorJunta),
				vol = false, t = 0, dur = 1, ultimo = 0,
				factor = 0.85 + math.random() * 0.4,
				proxTic = os.clock() + 2 + math.random() * 6,
				pos = Vector3.zero, desde = Vector3.zero, hacia = Vector3.zero,
			})
		end

		function M:reiniciar(cfRaiz, yBase)
			for _, p in ipairs(self.patas) do
				local ideal = cfRaiz:PointToWorldSpace(p.pieLocal)
				local r = Mundo.suelo(Vector3.new(ideal.X, yBase, ideal.Z), 40, 160)
				p.pos = r and r.Position or Vector3.new(ideal.X, yBase, ideal.Z)
				p.vol = false
				p.ultimo = os.clock()
			end
		end

		function M:iniciarPaso(p, objetivo, yBase)
			local r = Mundo.suelo(Vector3.new(objetivo.X, yBase, objetivo.Z), 40, 160)
			p.hacia = r and r.Position or Vector3.new(objetivo.X, yBase, objetivo.Z)
			p.desde = p.pos
			p.vol = true
			p.t = 0
			p.dur = self.cfg.tiempoPaso * (1 + (math.random() - 0.5) * 2 * self.cfg.irregular)
		end

		function M:actualizar(dt, cfRaiz, vel, yBase)
			local c = self.cfg
			local ahora = os.clock()
			local lev = 0
			for _, p in ipairs(self.patas) do
				if p.vol then
					lev += 1
				end
			end
			for _, p in ipairs(self.patas) do
				local cadera = cfRaiz:PointToWorldSpace(p.hipLocal)
				if not p.vol then
					local ideal = cfRaiz:PointToWorldSpace(p.pieLocal) + vel * c.anticipo
					local dx, dz = p.pos.X - ideal.X, p.pos.Z - ideal.Z
					local dist = math.sqrt(dx * dx + dz * dz)
					local forzar = (p.pos - cadera).Magnitude > (c.largo1 + c.largo2) * 0.97
					if (dist > c.umbral * p.factor or forzar) and lev < c.maxLev and ahora - p.ultimo > 0.15 then
						self:iniciarPaso(p, ideal, yBase)
						lev += 1
					elseif ahora > p.proxTic and lev == 0 and vel.Magnitude < 0.5 then
						-- tic irregular: reacomoda el pie aunque no haga falta
						local j = Vector3.new((math.random() - 0.5) * c.umbral * 0.8, 0, (math.random() - 0.5) * c.umbral * 0.8)
						self:iniciarPaso(p, p.pos + j, yBase)
						p.proxTic = ahora + 4 + math.random() * 8
						lev += 1
					end
				end
				if p.vol then
					p.t += dt / p.dur
					if p.t >= 1 then
						p.vol = false
						p.pos = p.hacia
						p.ultimo = ahora
						p.proxTic = ahora + 4 + math.random() * 8
						if c.onPaso then
							c.onPaso(p.pos)
						end
					else
						local a = p.t * p.t * (3 - 2 * p.t)
						p.pos = p.desde:Lerp(p.hacia, a) + Vector3.new(0, math.sin(p.t * math.pi) * c.altura, 0)
					end
				end
				-- IK y colocación de los huesos
				local polo = cfRaiz:VectorToWorldSpace(p.dir) + Vector3.new(0, c.poloArriba or 0.7, 0)
				local K, Fc = Mundo.rodilla(cadera, p.pos, c.largo1, c.largo2, polo)
				Mundo.segmento(p.muslo, cadera, K, c.grosor)
				Mundo.segmento(p.canilla, K, Fc, c.grosor * 0.8)
				p.rodilla.CFrame = CFrame.new(K)
				p.cadera.CFrame = CFrame.new(cadera)
				p.punta.CFrame = Mundo.mirar(Fc, Fc - K)
			end
		end

		return M
	end
end

--##########################################################################
-- MÓDULO 1: VHS (overlay analógico + REC + señal perdida)
--##########################################################################
local function MODULO_VHS()
	local V = CONFIG.VHS
	if env.AH_VHS_LIMPIAR then
		pcall(env.AH_VHS_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local pg = jugador:WaitForChild("PlayerGui")
	local viejo = pg:FindFirstChild("AnalogHorrorGui")
	if viejo then
		viejo:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AnalogHorrorGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg

	local TODO = UDim2.new(1, 0, 1, 0)
	local function marco(padre, nombre, pos, tam, color, transp)
		local f = Instance.new("Frame")
		f.Name = nombre
		f.Position = pos
		f.Size = tam
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp
		f.BorderSizePixel = 0
		f.Active = false
		f.Parent = padre
		return f
	end
	local function etiqueta(padre, nombre, txt, pos, tam, anchor, alinea)
		local l = Instance.new("TextLabel")
		l.Name = nombre
		l.BackgroundTransparency = 1
		l.Text = txt
		l.Font = Enum.Font.Code
		l.TextSize = tam
		l.TextColor3 = Color3.fromRGB(236, 236, 226)
		l.TextXAlignment = alinea or Enum.TextXAlignment.Left
		l.AnchorPoint = anchor or Vector2.zero
		l.Position = pos
		l.Size = UDim2.new(0, 320, 0, tam + 8)
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(0, 0, 0)
		st.Thickness = 1.5
		st.Transparency = 0.2
		st.Parent = l
		l.Parent = padre
		return l
	end

	-- El contorno (UIStroke) no se desvanece solo con TextTransparency: lo ajustamos a la vez
	local function transpTexto(l, a)
		l.TextTransparency = a
		local s = l:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = 0.2 + 0.8 * a
		end
	end

	local raiz = marco(gui, "Raiz", UDim2.new(0, 0, 0, 0), TODO, Color3.new(0, 0, 0), 1)

	-- Tinte general (verdoso con la Antena, cálido con la Torre)
	local tinte = marco(raiz, "Tinte", UDim2.new(0, 0, 0, 0), TODO, Color3.fromRGB(120, 140, 120), 1)

	-- Viñeta (4 bordes con degradado)
	local vinetas = {}
	local bordes = {
		{ UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0.25, 0), 90 },
		{ UDim2.new(0, 0, 0.75, 0), UDim2.new(1, 0, 0.25, 0), 270 },
		{ UDim2.new(0, 0, 0, 0), UDim2.new(0.18, 0, 1, 0), 0 },
		{ UDim2.new(0.82, 0, 0, 0), UDim2.new(0.18, 0, 1, 0), 180 },
	}
	for i, b in ipairs(bordes) do
		local f = marco(raiz, "Vineta" .. i, b[1], b[2], Color3.new(0, 0, 0), 1)
		local g = Instance.new("UIGradient")
		g.Rotation = b[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		vinetas[i] = f
	end

	-- Bandas de tracking
	local bandas = {}
	for i = 1, Q.bandas do
		bandas[i] = {
			f = marco(raiz, "Banda" .. i, UDim2.new(0, 0, math.random(), 0), UDim2.new(1, 0, 0, math.random(8, 22)), Color3.fromRGB(235, 235, 235), 1),
			y = math.random(),
			vel = 0.04 + math.random() * 0.08,
		}
	end

	-- Ruido de señal (motas que cambian de sitio ~12 veces por segundo)
	local ruido = marco(raiz, "Ruido", UDim2.new(0, 0, 0, 0), TODO, Color3.new(0, 0, 0), 1)
	local motas = {}
	for i = 1, Q.motas do
		motas[i] = marco(ruido, "M" .. i, UDim2.new(0, 0, 0, 0), UDim2.new(0, 8, 0, 2), Color3.fromRGB(240, 240, 240), 1)
	end

	-- Líneas de escaneo (estáticas, baratas)
	local lineas = marco(raiz, "Lineas", UDim2.new(0, 0, 0, 0), TODO, Color3.new(0, 0, 0), 1)
	local listaLineas = {}
	for i = 1, Q.lineas do
		listaLineas[i] = marco(lineas, "L" .. i, UDim2.new(0, 0, (i - 1) / Q.lineas, 0), UDim2.new(1, 0, 0, 2), Color3.new(0, 0, 0), V.LINEAS_TRANSP)
	end

	-- Pantalla de señal perdida
	local senal = marco(raiz, "Senal", UDim2.new(0, 0, 0, 0), TODO, Color3.fromRGB(8, 8, 10), 1)
	local lblSenal = etiqueta(senal, "TextoSenal", "SEÑAL PERDIDA", UDim2.new(0.5, 0, 0.5, 0), 26, Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
	transpTexto(lblSenal, 1)

	-- HUD: REC / PLAY / hora / fecha
	local hud = marco(raiz, "HUD", UDim2.new(0, 0, 0, 0), TODO, Color3.new(0, 0, 0), 1)
	local punto = marco(hud, "PuntoREC", UDim2.new(0.035, 0, 0.065, 0), UDim2.new(0, 14, 0, 14), Color3.fromRGB(220, 30, 30), 0)
	local esq = Instance.new("UICorner")
	esq.CornerRadius = UDim.new(0.5, 0)
	esq.Parent = punto
	etiqueta(hud, "REC", "REC", UDim2.new(0.035, 22, 0.065, -4), 20)
	etiqueta(hud, "PLAY", "PLAY ▶  SP", UDim2.new(0.965, 0, 0.065, -4), 18, Vector2.new(1, 0), Enum.TextXAlignment.Right)
	local lblHora = etiqueta(hud, "Hora", "", UDim2.new(0.035, 0, 0.925, -46), 22)
	local lblFecha = etiqueta(hud, "Fecha", "", UDim2.new(0.035, 0, 0.925, -22), 18)
	Shared.hud = { hora = lblHora, fecha = lblFecha }   -- la cámara los corrompe con interferencia

	local lblAviso = etiqueta(raiz, "Aviso", "", UDim2.new(0.5, 0, 0.88, 0), 18, Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
	transpTexto(lblAviso, 1)
	local avisoHasta = 0
	Shared.aviso = function(txt)
		if not CONFIG.AVISOS_EN_PANTALLA then
			return
		end
		lblAviso.Text = txt
		transpTexto(lblAviso, 0.1)
		avisoHasta = os.clock() + 2.2
	end

	-- Señal perdida (API para los demás módulos)
	local senalObj, senalAct, senalHasta = 0, 0, 0
	Shared.senalPerdida = function(dur)
		senalObj = 1
		senalHasta = os.clock() + (dur or 1.4)
		if Shared.pulso then
			Shared.pulso(1, (dur or 1.4) + 2)
		end
		if Shared.reproducir then
			Shared.reproducir("SENAL_PERDIDA", 0.8)
		end
	end

	-- Reloj ficticio
	local F = V.FECHA
	local base = F.h * 3600 + F.m * 60 + F.s
	local t0 = os.clock()
	local ultimoSeg = -1
	local function pintarReloj()
		local seg = math.floor(os.clock() - t0)
		if seg == ultimoSeg then
			return
		end
		ultimoSeg = seg
		local total = (base + seg) % 86400
		lblHora.Text = string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor(total / 60) % 60, total % 60)
		lblFecha.Text = string.format("%s. %02d %d", F.mes, F.dia, F.ano)
	end

	local modoAnterior = nil
	local function aplicarModo(suave)
		if modoAnterior == suave then
			return
		end
		modoAnterior = suave
		local t = suave and math.min(0.97, V.LINEAS_TRANSP + 0.06) or V.LINEAS_TRANSP
		for _, l in ipairs(listaLineas) do
			l.BackgroundTransparency = t
		end
	end

	local Is = 0          -- interferencia suavizada
	local Vs = 0          -- viñeta suavizada
	local acumRuido = 0
	local puntoOn = true

	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.1)
		local visible = Shared.Ajustes.vhs
		raiz.Visible = visible
		if not visible then
			return
		end
		local suave = Shared.Ajustes.suave
		aplicarModo(suave)
		pintarReloj()

		-- Interferencia objetivo (sube y baja despacio: nada de saltos bruscos)
		local I = Shared.Interf
		local obj = math.max(I.antena, I.torre * 0.85, I.evento)
		local subida = suave and 0.25 or 0.6
		local bajada = suave and 0.15 or 0.3
		if obj > Is then
			Is = math.min(obj, Is + subida * dt)
		else
			Is = math.max(obj, Is - bajada * dt)
		end
		local objV = (0.22 + 0.6 * I.torre) * (suave and 0.7 or 1)
		Vs += (objV - Vs) * math.min(1, dt * 0.8)
		for _, f in ipairs(vinetas) do
			f.BackgroundTransparency = 1 - Vs
		end

		-- Tinte
		local tintObj = I.torre > I.antena and Color3.fromRGB(150, 100, 70) or Color3.fromRGB(110, 150, 120)
		tinte.BackgroundColor3 = tintObj
		tinte.BackgroundTransparency = 1 - math.max(I.torre, I.antena) * (suave and 0.05 or 0.1)

		-- Bandas de tracking
		for _, b in ipairs(bandas) do
			b.y += b.vel * dt * (0.4 + 2.2 * Is) * (suave and 0.5 or 1)
			if b.y > 1.05 then
				b.y = -0.05
				b.vel = 0.04 + math.random() * 0.08
			end
			b.f.Position = UDim2.new(0, b.f.Position.X.Offset, b.y, 0)
			local a = (0.05 + 0.17 * Is) * (suave and 0.5 or 1)
			b.f.BackgroundTransparency = 1 - (Is > 0.03 and a or 0)
		end

		-- Ruido (~12 Hz)
		acumRuido += dt
		if acumRuido >= 0.083 then
			acumRuido = 0
			local activas = math.floor(#motas * (0.25 + 0.75 * Is))
			local minTransp = suave and 0.9 or (0.82 - 0.3 * Is)
			for i, m in ipairs(motas) do
				if i <= activas then
					m.Position = UDim2.new(math.random(), 0, math.random(), 0)
					m.Size = UDim2.new(0, math.random(3, 26), 0, math.random(1, 2))
					m.BackgroundTransparency = minTransp + math.random() * 0.12
				else
					m.BackgroundTransparency = 1
				end
			end
			if Is > 0.5 and not suave then
				for _, b in ipairs(bandas) do
					b.f.Position = UDim2.new(0, math.random(-10, 10), b.y, 0)
				end
			end
		end

		-- REC (parpadeo lento 1 Hz; en modo suave queda fijo)
		local on = true
		if V.REC_PARPADEA and not suave then
			on = math.floor(os.clock()) % 2 == 0
		end
		if on ~= puntoOn then
			puntoOn = on
			punto.BackgroundTransparency = on and 0 or 0.8
		end

		-- Señal perdida: entra y sale con velocidad limitada (anti-parpadeo)
		if os.clock() > senalHasta then
			senalObj = 0
		end
		local vel = V.SENAL_VEL * (suave and 0.5 or 1)
		if senalObj > senalAct then
			senalAct = math.min(senalObj, senalAct + vel * dt)
		else
			senalAct = math.max(senalObj, senalAct - vel * 0.6 * dt)
		end
		local maxA = suave and 0.55 or V.SENAL_MAX
		senal.BackgroundTransparency = 1 - senalAct * maxA
		transpTexto(lblSenal, 1 - senalAct)

		-- Aviso
		if avisoHasta > 0 and os.clock() > avisoHasta then
			avisoHasta = 0
			transpTexto(lblAviso, 1)
		end
	end)

	env.AH_VHS_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function() gui:Destroy() end)
		Shared.senalPerdida = nil
		Shared.aviso = nil
		Shared.hud = nil
	end

	print("[VHS] Cargado.")
end

--##########################################################################
-- MÓDULO 2: PROXIMIDAD (atmósfera, color, niebla, sacudida de cámara, reverb)
--##########################################################################
local function MODULO_PROXIMIDAD()
	local P = CONFIG.PROXIMIDAD
	if env.AH_PROX_LIMPIAR then
		pcall(env.AH_PROX_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local orig = {
		Brightness = Lighting.Brightness,
		FogEnd = Lighting.FogEnd,
		FogStart = Lighting.FogStart,
		FogColor = Lighting.FogColor,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Reverb = SoundService.AmbientReverb,
	}
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local atmOrig = atm and { Density = atm.Density, Haze = atm.Haze } or nil

	local viejoCC = Lighting:FindFirstChild("AH_Color")
	if viejoCC then
		viejoCC:Destroy()
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AH_Color"
	cc.Parent = Lighting

	local pT, pA, pE = 0, 0, 0
	local luzT, luzDur, luz = 0, 0, 0
	local pulsos = {}
	local reverbPuesto = false
	Shared.vib = 0

	Shared.pulso = function(valor, dur)
		table.insert(pulsos, { v = valor, t = 0, d = dur })
	end
	Shared.luces = function(dur)
		luzT = 0
		luzDur = dur
	end
	Shared.Vibrar = function(x)
		Shared.vib = math.max(Shared.vib, x)
	end

	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.1)

		-- Pulsos de eventos (suben y bajan suave)
		local ev = 0
		for i = #pulsos, 1, -1 do
			local q = pulsos[i]
			q.t += dt
			if q.t >= q.d then
				table.remove(pulsos, i)
			else
				local f = q.t / q.d
				local forma = f < 0.2 and (f / 0.2) or (1 - (f - 0.2) / 0.8)
				ev = math.max(ev, q.v * forma)
			end
		end
		Shared.Interf.evento = ev

		-- Luces tenues (sin parpadeo: sube, aguanta y baja)
		if luzDur > 0 then
			luzT += dt
			local f = luzT / luzDur
			local forma = f < 0.2 and (f / 0.2) or (1 - (f - 0.2) / 0.8)
			luz = forma * forma * (3 - 2 * forma)
			if luzT >= luzDur then
				luzDur = 0
				luz = 0
			end
		end

		local k = math.min(1, dt * P.SUAVIZADO)
		pT += (Shared.Interf.torre - pT) * k
		pA += (Shared.Interf.antena - pA) * k
		pE += (ev - pE) * k

		Lighting.Brightness = math.max(0, orig.Brightness * (1 - 0.35 * pT - 0.55 * luz))
		if orig.FogEnd > P.FOG_MIN then
			Lighting.FogEnd = orig.FogEnd * (P.FOG_MIN / orig.FogEnd) ^ pT
		end
		Lighting.FogStart = orig.FogStart * (1 - 0.8 * pT)
		Lighting.FogColor = orig.FogColor:Lerp(P.FOG_COLOR, pT * 0.7)
		local oscuro = math.min(1, 0.45 * pT + 0.4 * luz)
		Lighting.Ambient = orig.Ambient:Lerp(Color3.new(0, 0, 0), oscuro)
		Lighting.OutdoorAmbient = orig.OutdoorAmbient:Lerp(Color3.new(0, 0, 0), oscuro)
		if atm and atmOrig then
			atm.Density = math.min(0.7, atmOrig.Density + 0.25 * pT)
			atm.Haze = atmOrig.Haze + 3 * pT
		end

		cc.Saturation = -0.12 * pA - 0.3 * pT - 0.2 * pE
		cc.Contrast = 0.06 + 0.1 * pT + 0.05 * pE
		cc.Brightness = -0.02 * pT
		cc.TintColor = Color3.new(1, 1, 1):Lerp(P.TINTE_TORRE, pT * 0.6):Lerp(P.TINTE_ANTENA, pA * 0.5)

		if P.REVERB_TORRE then
			local quiere = pT > 0.6
			if quiere ~= reverbPuesto then
				reverbPuesto = quiere
				SoundService.AmbientReverb = quiere and Enum.ReverbType.Cave or orig.Reverb
			end
		end
	end)

	-- Sacudida de cámara: temblor fino con la Antena, balanceo lento y pesado con la Torre
	local function sacudida(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if Shared.Ajustes.suave or not CONFIG.VHS.SACUDIDA_CAMARA or not Shared.Ajustes.vhs then
			Shared.vib = 0
			return
		end
		Shared.vib = math.max(0, Shared.vib - dt * 0.9)
		local t = os.clock()
		local aA = pA * pA * 0.0035
		local aT = pT * 0.0025 + Shared.vib * 0.009
		if aA + aT < 0.0002 then
			return
		end
		local rx = math.noise(t * 14, 1.3, 0) * aA * 2 + math.sin(t * 0.7) * aT
		local ry = math.noise(t * 13, 7.7, 0) * aA * 2 + math.sin(t * 0.45 + 1) * aT * 0.6
		local rz = math.noise(t * 9, 3.1, 0) * aA + math.sin(t * 0.33) * aT * 0.8
		cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
	end
	pcall(function() RunService:UnbindFromRenderStep("AnalogHorrorShake") end)
	RunService:BindToRenderStep("AnalogHorrorShake", Enum.RenderPriority.Camera.Value + 1, sacudida)

	env.AH_PROX_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function() RunService:UnbindFromRenderStep("AnalogHorrorShake") end)
		pcall(function() cc:Destroy() end)
		pcall(function()
			Lighting.Brightness = orig.Brightness
			Lighting.FogEnd = orig.FogEnd
			Lighting.FogStart = orig.FogStart
			Lighting.FogColor = orig.FogColor
			Lighting.Ambient = orig.Ambient
			Lighting.OutdoorAmbient = orig.OutdoorAmbient
			SoundService.AmbientReverb = orig.Reverb
			if atm and atmOrig then
				atm.Density = atmOrig.Density
				atm.Haze = atmOrig.Haze
			end
		end)
		Shared.pulso, Shared.luces, Shared.Vibrar = nil, nil, nil
	end

	print("[PROXIMIDAD] Cargado.")
end

--##########################################################################
-- MÓDULO 3: AUDIO (ambiente, estática dinámica, one-shots)
--##########################################################################
local function MODULO_AUDIO()
	local A = CONFIG.AUDIO
	if env.AH_AUDIO_LIMPIAR then
		pcall(env.AH_AUDIO_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local cache = {}
	local function obtener(clave, loop)
		if cache[clave] == nil then
			cache[clave] = Mundo.sonido(SoundService, clave, 1, nil, nil, loop) or false
		end
		return cache[clave] or nil
	end

	local ambiente = obtener("AMBIENTE", true)
	local estatica = obtener("ESTATICA", true)
	if ambiente then
		ambiente.Volume = A.AMBIENTE_VOL
		ambiente:Play()
	end
	if estatica then
		estatica.Volume = 0
		estatica:Play()
	end

	Shared.reproducir = function(clave, vol)
		local s = obtener(clave, false)
		if s then
			s.Volume = vol or 1
			s.PlaybackSpeed = 0.95 + math.random() * 0.1
			s:Play()
		end
	end

	local ultimoSonido = nil
	con(RunService.Heartbeat, function(dt)
		-- Silencia/activa solo los sonidos de este script
		if ultimoSonido ~= Shared.Ajustes.sonido then
			ultimoSonido = Shared.Ajustes.sonido
			Mundo.grupoSonido.Volume = ultimoSonido and 1 or 0
		end
		local I = Shared.Interf
		local m = math.max(I.antena, I.torre * 0.9, I.evento)
		if ambiente then
			-- el ambiente se "apaga" cuando algo se acerca
			ambiente.Volume += (A.AMBIENTE_VOL * (1 - 0.6 * m) - ambiente.Volume) * math.min(1, dt)
		end
		if estatica then
			estatica.Volume += (A.ESTATICA_VOL * m * m - estatica.Volume) * math.min(1, dt * 1.5)
			estatica.PlaybackSpeed = 0.9 + 0.2 * math.noise(os.clock() * 0.6, 4.4, 0) + 0.1
		end
	end)

	env.AH_AUDIO_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		for _, s in pairs(cache) do
			if s then
				pcall(function() s:Destroy() end)
			end
		end
		Shared.reproducir = nil
	end

	print("[AUDIO] Cargado.")
end

--##########################################################################
-- MÓDULO 4: ANTENA CAMINANTE (modelo articulado + IA por estados)
--##########################################################################
local function MODULO_ANTENA()
	local A = CONFIG.ANTENA
	if env.AH_ANTENA_LIMPIAR then
		pcall(env.AH_ANTENA_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local k = A.ESCALA
	local COL_METAL = Color3.fromRGB(176, 168, 150)
	local COL_OXIDO = Color3.fromRGB(122, 100, 78)
	local COL_CABLE = Color3.fromRGB(28, 30, 34)
	local ALTURA_CUERPO = 14 * k

	-- ===================== MODELO =====================
	local modelo = Instance.new("Model")
	modelo.Name = "AntenaCaminante"
	local raiz = Mundo.parte(modelo, "Raiz", Vector3.one, COL_OXIDO)
	raiz.Transparency = 1
	modelo.PrimaryPart = raiz

	-- Cabeza: cubo + brazo (boom) + dipolos de la antena Yagi
	local cabeza = Instance.new("Model")
	cabeza.Name = "Cabeza"
	local hub = Mundo.parte(cabeza, "Hub", Vector3.new(1.8, 1.8, 2.2) * k, COL_OXIDO)
	hub.CFrame = CFrame.new()
	cabeza.PrimaryPart = hub
	local boomCF = CFrame.new(0, 0.9 * k, -3.6 * k) * CFrame.Angles(math.rad(14), 0, 0)
	local boom = Mundo.parte(cabeza, "Boom", Vector3.new(0.4, 0.4, 10.5) * k, COL_METAL)
	boom.CFrame = boomCF
	for i = 1, A.DIPOLOS do
		local f = (i - 1) / math.max(1, A.DIPOLOS - 1)
		local z = (4.6 - f * 9.6) * k
		local largo = (7.4 - f * 3.2) * k
		local d = Mundo.parte(cabeza, "Dipolo" .. i, Vector3.new(largo, 0.16 * k, 0.16 * k), COL_METAL)
		d.CFrame = boomCF * CFrame.new(0, 0.1 * k, z)
	end
	cabeza.Parent = modelo

	-- Cable coaxial colgando
	local NCABLE = 6
	local cable = {}
	for i = 1, NCABLE do
		cable[i] = Mundo.parte(modelo, "Cable" .. i, Vector3.new(0.2 * k, 0.2 * k, 1), COL_CABLE, Enum.Material.SmoothPlastic)
	end

	-- Patas: 3, largas y finas, con rodilla
	local function onPaso(p)
		if Shared.Ajustes.sonido and modelo.Parent then
			if Shared.sPasoAntena then
				Shared.sPasoAntena.PlaybackSpeed = 0.85 + math.random() * 0.4
				Shared.sPasoAntena:Play()
			end
		end
	end
	local marcha = Mundo.nuevaMarcha(modelo, {
		n = 3, giro = 0.5,
		largo1 = 8.4 * k, largo2 = 8.4 * k, grosor = 0.45 * k,
		radioCadera = 1.0 * k, radioPie = 7.5 * k, caderaY = -0.9 * k,
		umbral = 4.2 * k, altura = 3.2 * k, tiempoPaso = 0.55, irregular = 0.45,
		anticipo = 0.5, maxLev = 1, poloArriba = 0.7,
		color = COL_METAL, colorJunta = COL_OXIDO, onPaso = onPaso,
	})

	-- Sonidos posicionales (solo si pusiste IDs)
	local sZumbido = Mundo.sonido(raiz, "ANTENA_ZUMBIDO", 0, 12, 180, true)
	local sChirrido = Mundo.sonido(raiz, "ANTENA_CHIRRIDO", 1, 14, 240, false)
	Shared.sPasoAntena = Mundo.sonido(raiz, "ANTENA_PASO", 0.8, 10, 160, false)

	-- ===================== VARIABLES =====================
	local pos = Vector3.zero
	local rumbo = 0
	local velVec = Vector3.zero
	local estado = "OCULTA"
	local tEstado, durEstado = 0, A.INICIO_ESPERA
	local agresividad = A.AGRESIVIDAD_INICIAL
	local alfa, alfaFade = 0, 0
	local headYaw, headPitch = 0, 0
	local ticYaw, ticT = 0, 1
	local objetivoMov = nil
	local congelado = 0
	local dirCache, tLibre = nil, 0
	local yObj, tSuelo = 0, 0
	local sensorT = 0
	local dist, losOK, enPantalla, sinVista = 9999, false, false, 0
	local acumAnim, lodC = 0, 0
	local semilla = math.random() * 100
	local rutaFallaT = 0

	-- Pathfinding (con alternativa: movimiento directo esquivando obstáculos altos)
	local path = PathfindingService:CreatePath({
		AgentRadius = A.PATH_RADIO, AgentHeight = A.PATH_ALTURA, AgentCanJump = false, WaypointSpacing = 12,
	})
	local ruta, rutaIdx, rutaBusca, rutaFalla, rutaTiempo = nil, 2, false, 0, 0

	local function siguienteWaypoint(dest, dt)
		rutaTiempo -= dt
		if rutaTiempo <= 0 and not rutaBusca then
			rutaTiempo = A.PATH_REFRESCO
			rutaBusca = true
			local origen, destino = pos, dest
			task.spawn(function()
				local ok = pcall(function() path:ComputeAsync(origen, destino) end)
				if ok and path.Status == Enum.PathStatus.Success then
					local nueva = {}
					for _, w in ipairs(path:GetWaypoints()) do
						table.insert(nueva, w.Position)
					end
					ruta = nueva
					rutaIdx = 2
					rutaFalla = 0
				else
					rutaFalla += 1
					ruta = nil
				end
				rutaBusca = false
			end)
		end
		if ruta then
			while ruta[rutaIdx] and Vector3.new(ruta[rutaIdx].X - pos.X, 0, ruta[rutaIdx].Z - pos.Z).Magnitude < 6 * k do
				rutaIdx += 1
			end
			return ruta[rutaIdx]
		end
		return nil
	end

	local function direccionLibre(dir)
		local origen = pos + Vector3.new(0, 6 * k, 0)
		for _, giro in ipairs({ 0, 0.9, -0.9, 1.8, -1.8 }) do
			local c, s = math.cos(giro), math.sin(giro)
			local d = Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
			local r = Mundo.rayo(origen, d * (14 * k))
			local bloq = false
			if r and math.abs(r.Normal.Y) < 0.5 then
				bloq = r.Instance:IsA("Terrain") or r.Instance.Size.Y > 7 * k
			end
			if not bloq then
				return d
			end
		end
		return nil
	end

	-- Avanza hacia "dest". Devuelve true si llegó.
	local function irA(dest, vel, dt)
		local plano = Vector3.new(dest.X - pos.X, 0, dest.Z - pos.Z)
		local d = plano.Magnitude
		if d < 2 then
			velVec = Vector3.zero
			return true
		end
		local meta = dest
		if A.PATHFINDING and d > 25 and rutaFalla < 3 then
			meta = siguienteWaypoint(dest, dt) or dest
		end
		local dir = Vector3.new(meta.X - pos.X, 0, meta.Z - pos.Z)
		if dir.Magnitude < 0.5 then
			dir = plano
		end
		dir = dir.Unit
		tLibre -= dt
		if tLibre <= 0 then
			tLibre = 0.2
			dirCache = direccionLibre(dir)
		end
		if not dirCache then
			velVec = Vector3.zero
			rumbo += dt * 0.8
			return false
		end
		local objYaw = math.atan2(-dirCache.X, -dirCache.Z)
		local dif = Mundo.angDif(objYaw, rumbo)
		rumbo += math.clamp(dif, -A.GIRO * dt, A.GIRO * dt)
		-- paso irregular: arranca y se frena sin ritmo fijo
		local n = math.noise(os.clock() * 0.7, semilla, 0)
		local mult = math.clamp(0.75 + n * 1.2, 0.15, 1.15)
		if math.abs(dif) > 1.2 then
			mult *= 0.2
		end
		local rapidez = vel * mult
		local fwd = Vector3.new(-math.sin(rumbo), 0, -math.cos(rumbo))
		pos += fwd * rapidez * dt
		velVec = fwd * rapidez
		return false
	end

	-- ===================== ESTADOS =====================
	local function cambiar(nuevo, dur)
		estado = nuevo
		tEstado = 0
		durEstado = dur or 20
		objetivoMov = nil
		congelado = 0
		ruta = nil
		rutaFalla = 0
	end

	local function ocultar(dur)
		cambiar("OCULTA", dur or Mundo.rand(A.OCULTA_MIN, A.OCULTA_MAX))
		velVec = Vector3.zero
		alfa = 0
		modelo.Parent = nil
		Shared.Interf.antena = 0
		if sZumbido then
			sZumbido:Stop()
		end
	end

	local function colocar(spot, conFundido)
		pos = spot
		yObj = spot.Y
		rumbo = math.random() * math.pi * 2
		velVec = Vector3.zero
		headYaw = rumbo
		alfa = conFundido and 0 or 1
		acumAnim = 1
		Mundo.alfa(modelo, alfa)
		modelo.Parent = Mundo.carpeta
		marcha:reiniciar(CFrame.new(pos + Vector3.new(0, ALTURA_CUERPO, 0)) * CFrame.Angles(0, rumbo, 0), pos.Y)
		if sZumbido then
			sZumbido:Play()
		end
	end

	local function aparecer(spot)
		colocar(spot, true)
		cambiar("PATRULLAR", Mundo.rand(15, 25))
	end

	local function atacar(hrp)
		cambiar("ATAQUE", 0.9)
		if Shared.senalPerdida then
			Shared.senalPerdida(A.ATAQUE_SEG)
		end
		if A.DANO > 0 then
			local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:TakeDamage(A.DANO)
			end
		end
		agresividad = A.AGRESIVIDAD_INICIAL
	end

	local function pensar(dt, hrpPos)
		tEstado += dt
		local hubPos = pos + Vector3.new(0, ALTURA_CUERPO, 0)

		if estado == "PATRULLAR" then
			if not objetivoMov then
				local ang0 = nil
				if dist > A.DIST_ZONA then
					ang0 = math.atan2(hrpPos.Z - pos.Z, hrpPos.X - pos.X)
				end
				local p = Mundo.puntoValido(pos, 30, 90, ang0, ang0 and 1.4 or nil, 8)
				objetivoMov = p or (pos + Vector3.new(math.random(-60, 60), 0, math.random(-60, 60)))
			end
			local llego = irA(objetivoMov, A.VEL_PATRULLA, dt)
			if llego or tEstado > durEstado then
				if dist < A.DIST_VER and losOK then
					cambiar("OBSERVAR", Mundo.rand(A.OBSERVA_MIN, A.OBSERVA_MAX))
				else
					cambiar("PATRULLAR", Mundo.rand(12, 22))
				end
			elseif dist < A.DIST_VER and losOK and math.random() < dt * 0.1 then
				cambiar("OBSERVAR", Mundo.rand(A.OBSERVA_MIN, A.OBSERVA_MAX))
			end

		elseif estado == "OBSERVAR" then
			velVec = Vector3.zero
			if sChirrido and math.random() < dt * 0.05 and Shared.Ajustes.sonido then
				sChirrido:Play()
			end
			if tEstado > durEstado then
				local r = math.random()
				if r < agresividad then
					cambiar("ACERCAR", Mundo.rand(25, 45))
				elseif r < agresividad + 0.35 then
					cambiar("REPOSICION", 25)
				else
					cambiar("PATRULLAR", Mundo.rand(12, 22))
				end
			elseif sinVista > 10 then
				cambiar("PATRULLAR", Mundo.rand(12, 22))
			end

		elseif estado == "ACERCAR" then
			if dist < A.DIST_PERSEGUIR and agresividad > A.UMBRAL_PERSEGUIR and losOK then
				cambiar("PERSEGUIR", A.PERSECUCION_MAX)
				if sChirrido and Shared.Ajustes.sonido then
					sChirrido:Play()
				end
			elseif congelado > 0 then
				congelado -= dt
				velVec = Vector3.zero
			else
				-- se congela de golpe de vez en cuando (movimiento antinatural)
				if math.random() < dt * 0.12 then
					congelado = 1 + math.random() * 2.5
				end
				if dist > A.DIST_MANTENER then
					irA(hrpPos, A.VEL_ACERCAR, dt)
				else
					agresividad = math.min(1, agresividad + 0.1)
					cambiar("OBSERVAR", Mundo.rand(5, 9))
				end
			end
			if estado == "ACERCAR" and (sinVista > 8 or tEstado > durEstado) then
				cambiar("REPOSICION", 25)
			end

		elseif estado == "PERSEGUIR" then
			irA(hrpPos, A.VEL_PERSEGUIR, dt)
			if dist < A.DIST_ATAQUE then
				atacar()
			elseif dist > A.DIST_PERSEGUIR * 2.2 or tEstado > durEstado or sinVista > 6 then
				agresividad = math.max(0.2, agresividad - 0.15)
				cambiar("REPOSICION", 25)
			end

		elseif estado == "ATAQUE" then
			velVec = Vector3.zero
			if tEstado > durEstado then
				ocultar(Mundo.rand(A.OCULTA_MIN, A.OCULTA_MAX) + 20)
			end

		elseif estado == "REPOSICION" then
			-- se pierde de vista y reaparece en otro lugar válido
			if (not enPantalla) and tEstado > 2 then
				local spot = Mundo.puntoValido(hrpPos, A.APARECER_MIN, A.APARECER_MAX)
				if spot then
					colocar(spot, false)
					cambiar("PATRULLAR", Mundo.rand(15, 25))
				end
			else
				local lejos = pos + (pos - hrpPos).Unit * 40
				irA(lejos, A.VEL_PATRULLA * 1.3, dt)
			end
			if estado == "REPOSICION" and tEstado > durEstado then
				ocultar()
			end
		end
	end

	-- ===================== ANIMACIÓN =====================
	local function cabezaCF(dt, hrpPos, hubPos)
		local objYaw, objPitch = rumbo, 0
		if estado == "OBSERVAR" or estado == "ACERCAR" or estado == "PERSEGUIR" or estado == "ATAQUE" then
			local d = hrpPos - hubPos
			objYaw = math.atan2(-d.X, -d.Z)
			objPitch = math.clamp(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)), -0.6, 0.6)
		end
		ticT -= dt
		if ticT <= 0 then
			ticT = 0.8 + math.random() * 3.5
			ticYaw = (math.random() - 0.5) * (estado == "OBSERVAR" and 0.9 or 0.35)
		end
		ticYaw *= (1 - math.min(1, dt * 2.5))
		local dif = Mundo.angDif(objYaw + ticYaw, headYaw)
		headYaw += dif * math.min(1, dt * (estado == "PERSEGUIR" and 8 or 3.5))
		headPitch += (objPitch - headPitch) * math.min(1, dt * 3)
		return CFrame.new(hubPos) * CFrame.Angles(0, headYaw, 0) * CFrame.Angles(headPitch, 0, 0)
	end

	local function actualizarCable(hubPos, t)
		local inicio = hubPos + Vector3.new(0, -0.7 * k, 0)
		local largoSeg = (A.ESCALA * 11) / NCABLE
		local prev = inicio
		for i = 1, NCABLE do
			local f = i / NCABLE
			local s = f * f
			local off = Vector3.new(math.sin(t * 1.1 + i * 0.7) * 1.2 * s, 0, math.cos(t * 0.9 + i * 0.5) * 1.0 * s) * k - velVec * 0.12 * f
			local sig = inicio + Vector3.new(0, -largoSeg * i, 0) + off
			if sig.Y < pos.Y + 0.4 then
				sig = Vector3.new(sig.X, pos.Y + 0.4, sig.Z)
			end
			Mundo.segmento(cable[i], prev, sig, 0.2 * k)
			prev = sig
		end
	end

	-- ===================== BUCLE PRINCIPAL =====================
	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.1)
		local hrp = Mundo.raiz()
		if not hrp then
			return
		end
		local hrpPos = hrp.Position

		-- La agresividad sube sola con el tiempo
		agresividad = math.min(1, agresividad + dt * A.AGRESIVIDAD_POR_MIN / 60)

		-- Pathfinding: reintenta de vez en cuando si falló
		rutaFallaT += dt
		if rutaFallaT > 20 then
			rutaFallaT = 0
			rutaFalla = 0
		end

		if estado == "OCULTA" then
			tEstado += dt
			Shared.Interf.antena = 0
			if tEstado >= durEstado then
				local spot = Mundo.puntoValido(hrpPos, A.APARECER_MIN, A.APARECER_MAX)
				if spot then
					aparecer(spot)
				else
					tEstado = durEstado - 3
				end
			end
			return
		end

		-- Sensores (5 veces por segundo)
		sensorT -= dt
		if sensorT <= 0 then
			sensorT = 0.2
			local hubPos = pos + Vector3.new(0, ALTURA_CUERPO, 0)
			dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			losOK = Mundo.lineaVista(hubPos, hrpPos + Vector3.new(0, 2, 0))
			enPantalla = Mundo.enPantalla(hubPos) and losOK
			sinVista = losOK and 0 or (sinVista + 0.2)
			-- altura del suelo bajo la antena
			local r = Mundo.suelo(pos, 25 * k, 120)
			if r then
				yObj = r.Position.Y
			end
		end

		pensar(dt, hrpPos)
		pos = Vector3.new(pos.X, pos.Y + (yObj - pos.Y) * math.min(1, dt * 4), pos.Z)

		-- Fundido de aparición
		if alfa < 1 then
			alfa = math.min(1, alfa + dt / A.FUNDIDO)
			alfaFade -= dt
			if alfaFade <= 0 or alfa >= 1 then
				alfaFade = 0.1
				Mundo.alfa(modelo, alfa)
			end
		end

		-- Interferencia según cercanía (para VHS, atmósfera y audio)
		local p = math.clamp(1 - (dist - A.INTERF_MIN) / (A.INTERF_MAX - A.INTERF_MIN), 0, 1)
		p = p ^ 1.5
		if estado == "PERSEGUIR" then
			p = math.min(1, p + 0.2)
		elseif estado == "ATAQUE" then
			p = 1
		end
		Shared.Interf.antena = p * alfa
		if sZumbido then
			sZumbido.Volume = math.clamp(0.15 + p * 0.85, 0, 1)
		end
		raiz.CFrame = CFrame.new(pos + Vector3.new(0, ALTURA_CUERPO * 0.6, 0))

		-- Animación (a menos FPS si está muy lejos)
		acumAnim += dt
		local intervalo = dist > A.LOD_DIST and (1 / 20) or 0
		if acumAnim >= intervalo then
			local adt = acumAnim
			acumAnim = 0
			local t = os.clock()
			local rapidez = velVec.Magnitude
			local bob = math.sin(t * 2.1) * 0.25 * k * (0.4 + rapidez / 8)
			local lean = math.noise(t * 0.9, semilla, 1) * 0.12
			local cfCuerpo = CFrame.new(pos + Vector3.new(0, ALTURA_CUERPO + bob, 0)) * CFrame.Angles(0, rumbo, 0) * CFrame.Angles(lean, 0, lean * 0.6)
			marcha:actualizar(adt, cfCuerpo, velVec, pos.Y)
			local hubPos = cfCuerpo.Position
			cabeza:PivotTo(cabezaCF(adt, hrpPos, hubPos))
			actualizarCable(hubPos, t)
		end
	end)

	-- ===================== API =====================
	Shared.Antena = {
		forzar = function()
			local hrp = Mundo.raiz()
			if not hrp then
				return
			end
			local spot = Mundo.puntoValido(hrp.Position, 90, 130)
			if spot then
				colocar(spot, true)
				cambiar("OBSERVAR", Mundo.rand(6, 10))
			end
		end,
		sugerir = function()
			if estado == "OCULTA" then
				tEstado = math.max(tEstado, durEstado - 3)
			end
		end,
		ocultar = function()
			ocultar(60)
		end,
		estado = function()
			return estado
		end,
	}

	env.AH_ANTENA_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function() modelo:Destroy() end)
		Shared.Interf.antena = 0
		Shared.Antena = nil
		Shared.sPasoAntena = nil
	end

	print("[ANTENA] Cargado.")
end

--##########################################################################
-- MÓDULO 5: LA TORRE (colosal, lenta, fases sincronizadas por reloj del servidor)
--##########################################################################
local function MODULO_TORRE()
	local T = CONFIG.TORRE
	if env.AH_TORRE_LIMPIAR then
		pcall(env.AH_TORRE_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local COL = Color3.fromRGB(88, 84, 80)
	local COL_OX = Color3.fromRGB(110, 80, 62)
	local COL_CARNE = Color3.fromRGB(92, 38, 40)
	local COL_CABLE = Color3.fromRGB(22, 22, 26)
	local nSeg = Q.torreSeg
	local segH = T.ALTURA / nSeg
	local function ancho(i)
		return T.ANCHO_BASE * (1 - 0.72 * i / nSeg)
	end

	-- ===================== MODELO =====================
	local modelo = Instance.new("Model")
	modelo.Name = "LaTorre"
	local raiz = Mundo.parte(modelo, "Raiz", Vector3.one, COL)
	raiz.Transparency = 1
	modelo.PrimaryPart = raiz

	local pelvis = Mundo.parte(modelo, "Pelvis", Vector3.new(32, 10, 32), COL_CARNE, Enum.Material.Slate)

	-- Columna: cada segmento es un modelo rígido; se doblan entre sí (columna que se mueve)
	local segs, esqB, esqT = {}, {}, {}
	local signos = { { 1, 1 }, { 1, -1 }, { -1, -1 }, { -1, 1 } }
	for i = 1, nSeg do
		local wB, wT = ancho(i - 1), ancho(i)
		local seg = Instance.new("Model")
		seg.Name = "Seg" .. i
		local base = Mundo.parte(seg, "Base", Vector3.one, COL)
		base.Transparency = 1
		base.CFrame = CFrame.new()
		seg.PrimaryPart = base
		local gr = math.max(1.2, wB * 0.05)
		esqB[i], esqT[i] = {}, {}
		for j, s in ipairs(signos) do
			esqB[i][j] = Vector3.new(s[1] * wB / 2, 0, s[2] * wB / 2)
			esqT[i][j] = Vector3.new(s[1] * wT / 2, segH, s[2] * wT / 2)
			local poste = Mundo.parte(seg, "Poste" .. j, Vector3.one, COL)
			Mundo.segmento(poste, esqB[i][j], esqT[i][j], gr)
		end
		for j = 1, 4 do
			local brazo = Mundo.parte(seg, "Diag" .. j, Vector3.one, COL_OX)
			Mundo.segmento(brazo, esqB[i][j], esqT[i][j % 4 + 1], gr * 0.6)
		end
		local anillo = Mundo.parte(seg, "Anillo", Vector3.new(wT * 1.1, 1.2, wT * 1.1), COL_OX)
		anillo.CFrame = CFrame.new(0, segH, 0)
		seg.Parent = modelo
		segs[i] = seg
	end

	-- Masas orgánicas que pulsan (pegadas a las esquinas de los segmentos)
	local sacs = {}
	for i = 2, nSeg do
		for _, j in ipairs({ 1, 3 }) do
			local tam = 6 + math.random() * 4
			local parte = Mundo.parte(modelo, "Masa", Vector3.new(tam, tam * 1.3, tam), COL_CARNE, Enum.Material.Slate, Enum.PartType.Ball)
			table.insert(sacs, { p = parte, seg = i, cf = CFrame.new(esqB[i][j] * 1.06 + Vector3.new(0, 3, 0)), base = parte.Size, ph = math.random() * 6 })
		end
	end

	-- Platos que giran por su cuenta
	local platos = {}
	for n = 1, Q.platos do
		local s = 2 + (n - 1) % (nSeg - 1)
		local lado = (n % 2 == 0) and 1 or -1
		local disco = Mundo.parte(modelo, "Plato", Vector3.new(0.8, 14, 14), COL, Enum.Material.Metal, Enum.PartType.Cylinder)
		local brazo = Mundo.parte(modelo, "Alimentador", Vector3.new(0.6, 0.6, 8), COL_OX)
		table.insert(platos, {
			disco = disco, brazo = brazo, seg = s, lado = lado,
			bisagra = CFrame.new(lado * (ancho(s - 1) * 0.5 + 4), segH * (0.35 + 0.3 * math.random()), 0) * CFrame.Angles(0, -lado * math.pi / 2, 0),
			f1 = 0.04 + math.random() * 0.05, f2 = 0.03 + math.random() * 0.05, ph = math.random() * 6,
		})
	end

	-- Látigos (antenas largas) en lo alto
	local latigos = {}
	for n = 1, Q.latigos do
		local a = n / Q.latigos * math.pi * 2
		local r = ancho(nSeg) * 0.5
		local largo = 28 + math.random() * 26
		table.insert(latigos, {
			p = Mundo.parte(modelo, "Latigo", Vector3.new(0.5, largo, 0.5), COL),
			off = Vector3.new(math.cos(a) * r, segH, math.sin(a) * r), largo = largo, ph = math.random() * 6,
		})
	end

	-- Cables colgantes (cadenas de segmentos que se balancean)
	local cables = {}
	local NC = 6
	for n = 1, Q.cables do
		local s = 3 + (n - 1) % math.max(1, nSeg - 2)
		local c = { seg = s, anclaje = Vector3.new((n % 2 == 0 and 1 or -1) * ancho(s - 1) * 0.5, segH * 0.4, ((n % 3) - 1) * ancho(s - 1) * 0.3), partes = {}, ph = math.random() * 6 }
		for i = 1, NC do
			c.partes[i] = Mundo.parte(modelo, "Cable", Vector3.new(0.7, 0.7, 1), COL_CABLE, Enum.Material.SmoothPlastic)
		end
		table.insert(cables, c)
	end

	-- Corona giratoria en la punta y "ojos" rojos que respiran
	local corona = {
		Mundo.parte(modelo, "Corona1", Vector3.new(30, 0.8, 0.8), COL),
		Mundo.parte(modelo, "Corona2", Vector3.new(30, 0.8, 0.8), COL),
	}
	local ojos = {}
	for n = 1, 3 do
		local s = math.min(nSeg, 2 + n)
		local o = Mundo.parte(modelo, "Ojo", Vector3.new(3, 3, 3), Color3.fromRGB(170, 30, 30), Enum.Material.Neon, Enum.PartType.Ball)
		table.insert(ojos, { p = o, seg = s, cf = CFrame.new(ancho(s - 1) * 0.5 + 1.5, segH * 0.5, 0) * CFrame.Angles(0, (n - 2) * 1.6, 0), ph = math.random() * 6 })
	end

	-- Sonidos posicionales
	local sZumbido = Mundo.sonido(raiz, "TORRE_ZUMBIDO", 0.3, 200, 3000, true)
	local sPaso = Mundo.sonido(raiz, "TORRE_PASO", 1, 150, 2500, false)

	local pos = Vector3.zero
	local rumbo = 0
	local velVec = Vector3.zero

	local marcha = Mundo.nuevaMarcha(modelo, {
		n = 4, giro = math.pi / 4,
		largo1 = T.PIERNA_LARGO, largo2 = T.PIERNA_LARGO, grosor = T.PIERNA_GROSOR,
		radioCadera = T.RADIO_CADERA, radioPie = T.RADIO_PIE, caderaY = -4,
		umbral = 26, altura = 14, tiempoPaso = 5, irregular = 0.25,
		anticipo = 6, maxLev = 1, poloArriba = 0.9,
		color = COL, colorJunta = COL_CARNE,
		onPaso = function(p)
			local hrp = Mundo.raiz()
			if hrp then
				local d = (hrp.Position - p).Magnitude
				local f = math.clamp(1 - d / 900, 0, 1)
				if f > 0 and Shared.Vibrar then
					Shared.Vibrar(0.6 * f)
				end
			end
			if sPaso and Shared.Ajustes.sonido then
				sPaso.PlaybackSpeed = 0.7 + math.random() * 0.15
				sPaso:Play()
			end
		end,
	})

	-- ===================== POSTURA Y FASES =====================
	local angs, tgt = {}, {}
	for i = 1, nSeg do
		angs[i] = { x = 0, z = 0 }
		tgt[i] = { x = 0, z = 0 }
	end
	local function nuevaPostura()
		for i = 1, nSeg do
			tgt[i].x = math.rad((math.random() * 2 - 1) * T.POSTURA_GRAD)
			tgt[i].z = math.rad((math.random() * 2 - 1) * T.POSTURA_GRAD)
		end
	end
	nuevaPostura()
	local proxPostura = os.clock() + T.POSTURA_SEG

	local semilla = 0
	for i = 1, #game.JobId do
		semilla += string.byte(game.JobId, i)
	end

	local forzFase, forzHasta, forzAng = nil, 0, 0
	local function faseTorre()
		if forzFase and os.clock() < forzHasta then
			return forzFase, forzAng
		end
		local t = Workspace:GetServerTimeNow()
		local c = math.floor(t / T.CICLO)
		local rng = Random.new(c * 7919 + semilla)
		local f = (t - c * T.CICLO) / T.CICLO
		local b1 = 0.12 + rng:NextNumber() * 0.12
		local b2 = b1 + 0.22 + rng:NextNumber() * 0.10
		local b3 = b2 + 0.20 + rng:NextNumber() * 0.10
		local b4 = b3 + 0.06
		local ang = rng:NextNumber() * math.pi * 2
		if f < b1 then
			return "OCULTA", ang
		elseif f < b2 then
			return "HORIZONTE", ang
		elseif f < b3 then
			return "ACERCANDOSE", ang
		elseif f < b4 then
			return "EVENTO", ang
		end
		return "DESAPARECIENDO", ang
	end

	local estado, faseAnt = "OCULTA", nil
	local alfa, alfaObj, fadeT = 0, 0, 0
	local colocada, intentos, tIntento = false, 0, 0
	local yObj, tSuelo = 0, 0
	local dist = 9999
	local acum = 0
	local lastAng = 0

	local function ocultarYa()
		alfa = 0
		colocada = false
		modelo.Parent = nil
		Shared.Interf.torre = 0
		if sZumbido then
			sZumbido:Stop()
		end
	end

	local function colocar(hrpPos, ang, distancia)
		local spot = Mundo.puntoValido(hrpPos, distancia, distancia + 60, ang, 0.5, 16)
		intentos += 1
		if not spot and intentos >= 3 then
			-- Alternativa para mapas sin suelo detectable: la pone a esa distancia, a nivel del jugador
			spot = hrpPos + Vector3.new(math.cos(ang) * distancia, -3, math.sin(ang) * distancia)
		end
		if not spot then
			return false
		end
		pos = spot
		yObj = spot.Y
		rumbo = ang + math.pi + (math.random() - 0.5) * 0.6
		velVec = Vector3.zero
		alfa = 0
		acum = 1
		Mundo.alfa(modelo, 0)
		modelo.Parent = Mundo.carpeta
		marcha:reiniciar(CFrame.new(pos + Vector3.new(0, T.CADERA_ALTO, 0)) * CFrame.Angles(0, rumbo, 0), pos.Y)
		if sZumbido then
			sZumbido:Play()
		end
		colocada = true
		return true
	end

	-- ===================== ANIMACIÓN =====================
	local segCF = {}
	local function animar(dt, hrpPos, sesgo)
		local t = os.clock()
		local cfBase = CFrame.new(pos + Vector3.new(0, T.CADERA_ALTO, 0)) * CFrame.Angles(0, rumbo, 0)

		-- Postura: tiende despacio hacia la meta (y hacia el jugador en los segmentos altos)
		local hacia = hrpPos - pos
		local lp = hacia.Magnitude > 1 and cfBase:VectorToObjectSpace(hacia.Unit) or Vector3.zero
		local kk = 1 - math.exp(-dt / T.POSTURA_TAU)
		for i = 1, nSeg do
			local a, g = angs[i], tgt[i]
			local bx, bz = 0, 0
			if i > nSeg - 3 then
				bx = lp.Z * 0.03 * sesgo
				bz = -lp.X * 0.03 * sesgo
			end
			a.x += (g.x + bx + math.noise(t * 0.05, i, 0.5) * 0.03 - a.x) * kk
			a.z += (g.z + bz + math.noise(t * 0.05, i, 7.5) * 0.03 - a.z) * kk
		end

		-- Columna
		local cf = cfBase
		for i = 1, nSeg do
			cf = cf * CFrame.Angles(angs[i].x, 0, angs[i].z)
			segCF[i] = cf
			segs[i]:PivotTo(cf)
			cf = cf * CFrame.new(0, segH, 0)
		end
		local topCF = cf
		pelvis.CFrame = cfBase * CFrame.new(0, -2, 0)
		raiz.CFrame = CFrame.new(pos + Vector3.new(0, T.ALTURA * 0.5, 0))

		-- Patas (pesadas y lentas)
		marcha:actualizar(dt, cfBase, velVec, pos.Y)

		-- Masas orgánicas: pulsan
		for _, s in ipairs(sacs) do
			s.p.CFrame = segCF[s.seg] * s.cf
			s.p.Size = s.base * (1 + 0.09 * math.sin(t * 0.5 + s.ph))
		end

		-- Platos
		for _, d in ipairs(platos) do
			local h = segCF[d.seg] * d.bisagra * CFrame.Angles(math.sin(t * d.f1 + d.ph) * 0.4 + 0.3, math.sin(t * d.f2 + d.ph * 2) * 0.6, 0)
			d.disco.CFrame = h * CFrame.Angles(0, math.pi / 2, 0)
			d.brazo.CFrame = h * CFrame.new(0, 0, -4.5)
		end

		-- Látigos
		local top = segCF[nSeg]
		for _, l in ipairs(latigos) do
			local sx = math.noise(t * 0.12, l.ph, 0) * 0.18
			local sz = math.noise(t * 0.12, l.ph, 5) * 0.18
			l.p.CFrame = top * CFrame.new(l.off) * CFrame.Angles(sx, 0, sz) * CFrame.new(0, l.largo / 2, 0)
		end

		-- Cables colgantes
		for _, c in ipairs(cables) do
			local inicio = segCF[c.seg]:PointToWorldSpace(c.anclaje)
			local prev = inicio
			for i = 1, NC do
				local f = i / NC
				local sig = inicio + Vector3.new(math.sin(t * 0.35 + c.ph + i * 0.4) * 6 * f * f, -15 * i, math.cos(t * 0.3 + c.ph + i * 0.5) * 5 * f * f)
				if sig.Y < pos.Y + 1 then
					sig = Vector3.new(sig.X, pos.Y + 1, sig.Z)
				end
				Mundo.segmento(c.partes[i], prev, sig, 0.7)
				prev = sig
			end
		end

		-- Corona y ojos
		local ang = t * 0.12
		corona[1].CFrame = topCF * CFrame.new(0, 2, 0) * CFrame.Angles(0, ang, 0)
		corona[2].CFrame = topCF * CFrame.new(0, 2, 0) * CFrame.Angles(0, ang + math.pi / 2, 0)
		for _, o in ipairs(ojos) do
			o.p.CFrame = segCF[o.seg] * o.cf
			o.p.Transparency = 0.25 + 0.4 * (0.5 + 0.5 * math.sin(t * 0.7 + o.ph))
		end
	end

	-- ===================== BUCLE PRINCIPAL =====================
	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.2)
		local hrp = Mundo.raiz()
		if not hrp then
			return
		end
		local hrpPos = hrp.Position

		local fase, ang = faseTorre()
		lastAng = ang
		if fase ~= faseAnt then
			faseAnt = fase
			estado = fase
			intentos = 0
			if fase == "EVENTO" and Shared.evento then
				Shared.evento("TORRE")
			end
		end

		local visibleFase = (estado == "HORIZONTE" or estado == "ACERCANDOSE" or estado == "EVENTO")
		alfaObj = visibleFase and T.ALFA_MAX or 0

		-- Aparece lejos, en el horizonte (o a medio camino si entraste a mitad de fase)
		if visibleFase and not colocada then
			tIntento -= dt
			if tIntento <= 0 then
				tIntento = 2
				local d = estado == "HORIZONTE" and T.DIST_APARECER or (T.DIST_APARECER * 0.75)
				colocar(hrpPos, ang, d)
			end
		end

		if not colocada then
			Shared.Interf.torre = 0
			return
		end

		-- Fundido lento
		if alfa ~= alfaObj then
			local paso = dt / T.FUNDIDO * T.ALFA_MAX
			if alfa < alfaObj then
				alfa = math.min(alfaObj, alfa + paso)
			else
				alfa = math.max(alfaObj, alfa - paso)
			end
			fadeT -= dt
			if fadeT <= 0 or alfa == alfaObj then
				fadeT = 0.1
				Mundo.alfa(modelo, alfa)
			end
			if alfa <= 0.001 and alfaObj == 0 then
				ocultarYa()
				return
			end
		end

		dist = (Vector3.new(hrpPos.X, 0, hrpPos.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude

		-- Se acerca muy despacio hasta su distancia mínima
		velVec = Vector3.zero
		if estado == "ACERCANDOSE" and dist > T.DIST_MIN then
			local dir = Vector3.new(hrpPos.X - pos.X, 0, hrpPos.Z - pos.Z).Unit
			velVec = dir * T.VEL_ACERCAR
			pos += velVec * dt
			local objYaw = math.atan2(-dir.X, -dir.Z)
			rumbo += math.clamp(Mundo.angDif(objYaw, rumbo), -0.05 * dt, 0.05 * dt)
		end

		-- Altura del suelo (cada medio segundo)
		tSuelo -= dt
		if tSuelo <= 0 then
			tSuelo = 0.5
			local r = Mundo.suelo(pos, 60, 200)
			if r then
				yObj = r.Position.Y
			end
		end
		pos = Vector3.new(pos.X, pos.Y + (yObj - pos.Y) * math.min(1, dt * 2), pos.Z)

		-- Presencia: crece poco a poco y altera atmósfera, VHS y audio
		local p = math.clamp((T.DIST_ALCANCE - dist) / (T.DIST_ALCANCE - T.DIST_MIN), 0, 1)
		Shared.Interf.torre = p * p * (alfa / T.ALFA_MAX)
		if sZumbido then
			sZumbido.Volume = 0.2 + 0.8 * Shared.Interf.torre
		end

		-- Cambio de postura lento y periódico
		if os.clock() > proxPostura then
			proxPostura = os.clock() + T.POSTURA_SEG * (0.7 + math.random() * 0.6)
			nuevaPostura()
		end

		-- Animación: a menos FPS cuanto más lejos
		acum += dt
		local fps = dist < 500 and Q.torreFps or (dist < 1200 and 15 or 8)
		if acum >= 1 / fps then
			local adt = acum
			acum = 0
			animar(adt, hrpPos, visibleFase and 1 or 0)
		end
	end)

	-- ===================== API =====================
	Shared.Torre = {
		forzar = function()
			forzFase = "ACERCANDOSE"
			forzHasta = os.clock() + 150
			forzAng = math.random() * math.pi * 2
		end,
		ocultar = function()
			forzFase = "DESAPARECIENDO"
			forzHasta = os.clock() + 60
		end,
		estado = function()
			return estado
		end,
	}

	env.AH_TORRE_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function() modelo:Destroy() end)
		Shared.Interf.torre = 0
		Shared.Torre = nil
	end

	print("[TORRE] Cargada.")
end

--##########################################################################
-- MÓDULO 6: DIRECTOR DE EVENTOS (apagón de señal, radio, luces, distorsión)
--##########################################################################
local function MODULO_DIRECTOR()
	local D = CONFIG.DIRECTOR
	if env.AH_DIRECTOR_LIMPIAR then
		pcall(env.AH_DIRECTOR_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local vivo = true
	local semilla = 0
	for i = 1, #game.JobId do
		semilla += string.byte(game.JobId, i)
	end
	local TIPOS = { "APAGON", "RADIO", "LUCES", "DISTORSION" }
	local ultimoSlot = nil
	local proxLocal = os.clock() + Mundo.rand(D.ANTENA_MIN, D.ANTENA_MAX)
	local acum = 0

	Shared.evento = function(nombre)
		if nombre == "APAGON" then
			if Shared.senalPerdida then
				Shared.senalPerdida(D.APAGON_SEG)
			end
		elseif nombre == "RADIO" then
			if Shared.reproducir then
				Shared.reproducir("RADIO", 0.7)
			end
			if Shared.pulso then
				Shared.pulso(0.5, 6)
			end
		elseif nombre == "LUCES" then
			if Shared.luces then
				Shared.luces(7)
			end
		elseif nombre == "DISTORSION" then
			if Shared.pulso then
				Shared.pulso(0.7, 8)
			end
		elseif nombre == "TORRE" then
			-- la Torre hace su evento: señal, radio y luces a la vez
			if Shared.senalPerdida then
				Shared.senalPerdida(D.APAGON_SEG)
			end
			if Shared.reproducir then
				Shared.reproducir("RADIO", 0.8)
			end
			if Shared.luces then
				Shared.luces(9)
			end
			if Shared.Vibrar then
				Shared.Vibrar(0.5)
			end
		elseif nombre == "ANTENA_LEJANA" then
			if Shared.Antena then
				Shared.Antena.sugerir()
			end
		end
	end

	con(RunService.Heartbeat, function(dt)
		acum += dt
		if acum < 1 then
			return
		end
		acum = 0

		-- Eventos sincronizados: misma semilla = mismo evento para todos al mismo tiempo
		local slot = math.floor(Workspace:GetServerTimeNow() / D.SLOT_SEG)
		if slot ~= ultimoSlot then
			local primera = ultimoSlot == nil
			ultimoSlot = slot
			if not primera then
				local rng = Random.new(slot * 7919 + semilla)
				if rng:NextNumber() < D.PROB_SLOT then
					local tipo = TIPOS[rng:NextInteger(1, #TIPOS)]
					local espera = rng:NextNumber() * (D.SLOT_SEG - 5)
					task.delay(espera, function()
						if vivo then
							Shared.evento(tipo)
						end
					end)
				end
			end
		end

		-- Evento local: invita a la Antena a aparecer
		if os.clock() > proxLocal then
			proxLocal = os.clock() + Mundo.rand(D.ANTENA_MIN, D.ANTENA_MAX)
			Shared.evento("ANTENA_LEJANA")
		end
	end)

	env.AH_DIRECTOR_LIMPIAR = function()
		vivo = false
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		Shared.evento = nil
	end

	print("[DIRECTOR] Cargado.")
end

--##########################################################################
-- MÓDULO 7: CÁMARA VHS (visor de videocámara: pila, zoom, enfoque, cinta, mano temblorosa)
--##########################################################################
local function MODULO_CAMARA()
	local C = CONFIG.CAMARA
	if env.AH_CAMARA_LIMPIAR then
		pcall(env.AH_CAMARA_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local BLANCO = Color3.fromRGB(236, 236, 226)
	local ROJO = Color3.fromRGB(220, 30, 30)
	local NEGRO = Color3.new(0, 0, 0)
	local TODO = UDim2.new(1, 0, 1, 0)
	local RUIDO = { "#", "?", "%", "/", "*" }
	local CINTA_TOTAL = 2 * 3600          -- cinta ficticia de 2 horas

	-- ---------- estado ----------
	local zoom, zoomObj, zoomPrev = 1, 1, 1
	local dirTecla, dirBoton = 0, 0
	local bateria = 1
	local cinta = 0
	local desenfoque = 0                  -- "tirón de foco" al hacer zoom
	local dip = 0                         -- parpadeo oscuro con poca pila
	local mI = 0                          -- interferencia actual (0..1)
	local objetivo = nil                  -- criatura vista por la cámara
	local apuntando = false
	local tApunta = 0
	local avisada20, avisada10 = false, false
	local ultimaVez = os.clock()
	local ultimoMotor = 0
	local fase, faseT = (C.INTRO and "intro" or "on"), 0
	local negroT = C.INTRO and 0 or 1     -- transparencia de la pantalla negra (0 = opaca)
	local ruidoI = C.INTRO and 1 or 0
	local barras, linea = 0, 0            -- apagado tipo TV vieja
	local textoCentro = ""
	local sonidoPendiente = C.INTRO
	local subT0, subDur = 0, 0
	local proxSub = os.clock() + Mundo.rand(C.SUBT_MIN, C.SUBT_MAX)
	local proxDip = os.clock() + 4
	local fovRestaurado = false

	local camInicial = Workspace.CurrentCamera
	local fovBase = (C.FOV_BASE and C.FOV_BASE > 0) and C.FOV_BASE or (camInicial and camInicial.FieldOfView or 70)
	local sensOrig = UIS.MouseDeltaSensitivity
	local modoOrig = jugador.CameraMode

	local function aviso(txt)
		if Shared.aviso then
			Shared.aviso(txt)
		end
	end

	-- ---------- GUI ----------
	local pg = jugador:WaitForChild("PlayerGui")
	local viejo = pg:FindFirstChild("AnalogHorrorCamara")
	if viejo then
		viejo:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "AnalogHorrorCamara"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 52
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pg

	local function marco(padre, nombre, pos, tam, color, transp, anchor)
		local f = Instance.new("Frame")
		f.Name = nombre
		f.AnchorPoint = anchor or Vector2.zero
		f.Position = pos
		f.Size = tam
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp
		f.BorderSizePixel = 0
		f.Active = false
		f.Parent = padre
		return f
	end
	local function texto(padre, nombre, txt, pos, tam, anchor, alinea, fuente)
		local l = Instance.new("TextLabel")
		l.Name = nombre
		l.BackgroundTransparency = 1
		l.Text = txt
		l.Font = fuente or Enum.Font.Code
		l.TextSize = tam
		l.TextColor3 = BLANCO
		l.TextXAlignment = alinea or Enum.TextXAlignment.Left
		l.AnchorPoint = anchor or Vector2.zero
		l.Position = pos
		l.Size = UDim2.new(0, 320, 0, tam + 8)
		local st = Instance.new("UIStroke")
		st.Color = NEGRO
		st.Thickness = 1.5
		st.Transparency = 0.2
		st.Parent = l
		l.Parent = padre
		return l
	end

	local raiz = marco(gui, "Raiz", UDim2.new(0, 0, 0, 0), TODO, NEGRO, 1)
	local visor = marco(raiz, "Visor", UDim2.new(0, 0, 0, 0), TODO, NEGRO, 1)
	visor.ZIndex = 1
	local capas = marco(raiz, "Capas", UDim2.new(0, 0, 0, 0), TODO, NEGRO, 1)
	capas.ZIndex = 5

	-- Marcas de las 4 esquinas del visor
	for nombre, c in pairs({ TL = { 0, 0 }, TR = { 1, 0 }, BL = { 0, 1 }, BR = { 1, 1 } }) do
		local ox = c[1] == 0 and 18 or -18
		local oy = c[2] == 0 and 18 or -18
		marco(visor, "Esq" .. nombre .. "H", UDim2.new(c[1], ox, c[2], oy), UDim2.new(0, 42, 0, 3), BLANCO, 0.25, Vector2.new(c[1], c[2]))
		marco(visor, "Esq" .. nombre .. "V", UDim2.new(c[1], ox, c[2], oy), UDim2.new(0, 3, 0, 42), BLANCO, 0.25, Vector2.new(c[1], c[2]))
	end

	-- Retícula de enfoque (centro)
	local ret = marco(visor, "Reticula", UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, 90, 0, 90), NEGRO, 1, Vector2.new(0.5, 0.5))
	local retEsc = Instance.new("UIScale")
	retEsc.Parent = ret
	local retPartes = {}
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		table.insert(retPartes, marco(ret, "R", UDim2.new(c[1], 0, c[2], 0), UDim2.new(0, 16, 0, 2), BLANCO, 0.3, Vector2.new(c[1], c[2])))
		table.insert(retPartes, marco(ret, "R", UDim2.new(c[1], 0, c[2], 0), UDim2.new(0, 2, 0, 16), BLANCO, 0.3, Vector2.new(c[1], c[2])))
	end
	table.insert(retPartes, marco(ret, "CruzH", UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, 10, 0, 1), BLANCO, 0.3, Vector2.new(0.5, 0.5)))
	table.insert(retPartes, marco(ret, "CruzV", UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, 1, 0, 10), BLANCO, 0.3, Vector2.new(0.5, 0.5)))
	local lblAF = texto(visor, "AF", "AF", UDim2.new(0.5, 0, 0.5, 58), 16, Vector2.new(0.5, 0), Enum.TextXAlignment.Center)

	-- Cinta (arriba a la izquierda, debajo del REC)
	local lblCinta = texto(visor, "Cinta", "CINTA 0:00:00", UDim2.new(0.035, 22, 0.065, 24), 16)
	local lblResta = texto(visor, "Resta", "RESTA 2:00:00", UDim2.new(0.035, 22, 0.065, 42), 16)

	-- Pila (arriba a la derecha, debajo del PLAY)
	local batCont = marco(visor, "Bateria", UDim2.new(0.965, 0, 0.065, 30), UDim2.new(0, 60, 0, 20), NEGRO, 1, Vector2.new(1, 0))
	local batCuerpo = marco(batCont, "Cuerpo", UDim2.new(0, 0, 0, 0), UDim2.new(0, 54, 0, 20), NEGRO, 1)
	local batBorde = Instance.new("UIStroke")
	batBorde.Color = BLANCO
	batBorde.Thickness = 2
	batBorde.Parent = batCuerpo
	local batNub = marco(batCont, "Nub", UDim2.new(0, 54, 0.5, 0), UDim2.new(0, 4, 0, 10), BLANCO, 0, Vector2.new(0, 0.5))
	local batSeg = {}
	for i = 1, 4 do
		batSeg[i] = marco(batCuerpo, "S" .. i, UDim2.new(0, 4 + (i - 1) * 12, 0, 3), UDim2.new(0, 10, 0, 14), BLANCO, 0)
	end
	local lblBat = texto(visor, "BateriaPct", "100%", UDim2.new(0.965, -66, 0.065, 28), 16, Vector2.new(1, 0), Enum.TextXAlignment.Right)

	-- Zoom (abajo a la derecha): ZOOM x2.5  /  W ----|---- T
	local zoomCont = marco(visor, "Zoom", UDim2.new(0.965, 0, 0.925, 0), UDim2.new(0, 190, 0, 44), NEGRO, 1, Vector2.new(1, 1))
	local lblZoom = texto(zoomCont, "ZoomTxt", "ZOOM x1.0", UDim2.new(1, 0, 0, 0), 16, Vector2.new(1, 0), Enum.TextXAlignment.Right)
	local barra = marco(zoomCont, "Barra", UDim2.new(0, 18, 1, -8), UDim2.new(1, -36, 0, 3), BLANCO, 0.35, Vector2.new(0, 1))
	local marca = marco(barra, "Marca", UDim2.new(0, 0, 0.5, 0), UDim2.new(0, 6, 0, 12), BLANCO, 0, Vector2.new(0.5, 0.5))
	texto(zoomCont, "W", "W", UDim2.new(0, 0, 1, 0), 14, Vector2.new(0, 1))
	texto(zoomCont, "T", "T", UDim2.new(1, 0, 1, 0), 14, Vector2.new(1, 1), Enum.TextXAlignment.Right)

	-- Alerta de pila (centro arriba) y subtítulo estilo los videos (abajo)
	local lblAlerta = texto(visor, "Alerta", "", UDim2.new(0.5, 0, 0.11, 0), 20, Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)
	lblAlerta.TextColor3 = ROJO
	lblAlerta.Visible = false
	local sub = texto(visor, "Subtitulo", "", UDim2.new(0.5, 0, 0.76, 0), 30, Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center, Enum.Font.GothamBlack)
	sub.Size = UDim2.new(0.9, 0, 0, 40)
	sub.TextTransparency = 1
	local subStroke = sub:FindFirstChildOfClass("UIStroke")
	subStroke.Thickness = 2.5
	subStroke.Transparency = 1

	-- Polvo flotando en el aire (como en el video de la antena)
	local polvo = {}
	if C.POLVO then
		for i = 1, math.max(8, math.floor(Q.motas * 0.5)) do
			local tam = math.random(2, 4)
			local f = marco(visor, "Polvo" .. i, UDim2.new(0, 0, 0, 0), UDim2.new(0, tam, 0, tam), BLANCO, 0.6, Vector2.new(0.5, 0.5))
			local e = Instance.new("UICorner")
			e.CornerRadius = UDim.new(0.5, 0)
			e.Parent = f
			polvo[i] = {
				f = f, x = math.random(), y = math.random(),
				vx = (math.random() - 0.5) * 0.012, vy = -0.004 - math.random() * 0.012,
				fase = math.random() * 6.28, base = 0.55 + math.random() * 0.25,
			}
		end
	end

	-- Botones de zoom solo en celular (se quitan con CAMARA.BOTONES_TACTIL = false)
	if C.BOTONES_TACTIL and UIS.TouchEnabled then
		local function boton(nombre, txt, y, dir)
			local b = Instance.new("TextButton")
			b.Name = nombre
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(0.97, 0, y, 0)
			b.Size = UDim2.new(0, 46, 0, 46)
			b.BackgroundColor3 = NEGRO
			b.BackgroundTransparency = 0.55
			b.BorderSizePixel = 0
			b.Text = txt
			b.Font = Enum.Font.Code
			b.TextSize = 28
			b.TextColor3 = BLANCO
			b.AutoButtonColor = false
			b.Parent = visor
			local st = Instance.new("UIStroke")
			st.Color = BLANCO
			st.Thickness = 1.5
			st.Transparency = 0.4
			st.Parent = b
			con(b.MouseButton1Down, function()
				dirBoton = dir
			end)
			con(b.MouseButton1Up, function()
				if dirBoton == dir then
					dirBoton = 0
				end
			end)
			con(b.MouseLeave, function()
				if dirBoton == dir then
					dirBoton = 0
				end
			end)
			con(b.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
					if dirBoton == dir then
						dirBoton = 0
					end
				end
			end)
		end
		boton("ZoomMas", "+", 0.40, 1)
		boton("ZoomMenos", "-", 0.56, -1)
	end

	-- Capas de arriba: oscurecimiento por pila baja, pantalla negra, estática, apagado y texto central
	local atenua = marco(capas, "Atenua", UDim2.new(0, 0, 0, 0), TODO, NEGRO, 1)
	local negro = marco(capas, "Negro", UDim2.new(0, 0, 0, 0), TODO, NEGRO, negroT)
	local motasR = {}
	for i = 1, math.max(30, Q.motas + 10) do
		motasR[i] = marco(capas, "N" .. i, UDim2.new(0, 0, 0, 0), UDim2.new(0, 20, 0, 2), BLANCO, 1)
	end
	local barTop = marco(capas, "BarraArriba", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 0), NEGRO, 0)
	local barBot = marco(capas, "BarraAbajo", UDim2.new(0, 0, 1, 0), UDim2.new(1, 0, 0, 0), NEGRO, 0, Vector2.new(0, 1))
	local lineaF = marco(capas, "LineaApagado", UDim2.new(0.5, 0, 0.5, 0), UDim2.new(0, 0, 0, 3), BLANCO, 0, Vector2.new(0.5, 0.5))
	lineaF.Visible = false
	local lblCentro = texto(capas, "Centro", "", UDim2.new(0.5, 0, 0.5, 0), 30, Vector2.new(0.5, 0.5), Enum.TextXAlignment.Center)

	-- ---------- efectos de imagen ----------
	local function efecto(clase, nombre)
		local v = Lighting:FindFirstChild(nombre)
		if v then
			v:Destroy()
		end
		local e = Instance.new(clase)
		e.Name = nombre
		e.Parent = Lighting
		return e
	end
	local cc = efecto("ColorCorrectionEffect", "AH_CamColor")
	local blur = efecto("BlurEffect", "AH_CamBlur")
	blur.Size = 0.8
	local bloom = nil
	if CONFIG.CALIDAD ~= "baja" then
		bloom = efecto("BloomEffect", "AH_CamBloom")
		bloom.Intensity = 0.4
		bloom.Size = 22
		bloom.Threshold = 0.9
	end

	-- ---------- utilidades ----------
	local function formato(seg)
		seg = math.max(0, math.floor(seg))
		return string.format("%d:%02d:%02d", math.floor(seg / 3600), math.floor(seg / 60) % 60, seg % 60)
	end

	-- Cambia dígitos por basura con probabilidad p (cinta dañada)
	local function glitch(s, p)
		if p < 0.02 then
			return s
		end
		return (s:gsub("%d", function(d)
			if math.random() < p then
				return RUIDO[math.random(#RUIDO)]
			end
			return d
		end))
	end

	local function mostrarSub(txt, dur)
		if not C.SUBTITULOS then
			return
		end
		sub.Text = txt
		subT0 = os.clock()
		subDur = dur or 2.6
	end

	local function aplicarPersona()
		pcall(function()
			if Shared.Ajustes.primera and Shared.Ajustes.camara then
				jugador.CameraMode = Enum.CameraMode.LockFirstPerson
			else
				jugador.CameraMode = modoOrig
			end
		end)
	end

	-- Criatura más cercana que la cámara tiene en pantalla
	local function buscarCriatura()
		local cam = Workspace.CurrentCamera
		if not cam or not Mundo.carpeta then
			return nil
		end
		local mejor = nil
		for _, nombre in ipairs({ "AntenaCaminante", "LaTorre" }) do
			local m = Mundo.carpeta:FindFirstChild(nombre)
			if m and m:IsA("Model") then
				local ok, cf = pcall(function()
					return (m:GetBoundingBox())
				end)
				if ok and cf and Mundo.enPantalla(cf.Position) then
					local d = (cf.Position - cam.CFrame.Position).Magnitude
					if not mejor or d < mejor.d then
						local v = cam:WorldToViewportPoint(cf.Position)
						local vp = cam.ViewportSize
						local cent = (Vector2.new(v.X, v.Y) - vp / 2).Magnitude / math.max(1, vp.Magnitude) * 2
						mejor = { nombre = nombre, d = d, cent = cent }
					end
				end
			end
		end
		return mejor
	end

	-- ---------- fases: arranque, normal, apagado por pila y reinicio ----------
	local function actualizarFase(dt)
		faseT += dt
		if fase == "intro" then
			if faseT < 0.7 then
				negroT, ruidoI, textoCentro = 0, 1, ""
			elseif faseT < 2.6 then
				negroT, ruidoI = 0, 0.3
				textoCentro = "CARGANDO CINTA" .. string.rep(".", math.floor(faseT * 3) % 4)
			elseif faseT < 3.4 then
				local f = (faseT - 2.6) / 0.8
				negroT, ruidoI = f, 0.6 * (1 - f)
				textoCentro = faseT < 3.0 and "PLAY" or ""
			else
				fase, faseT = "on", 0
				negroT, ruidoI, textoCentro = 1, 0, ""
			end
		elseif fase == "apagando" then
			if faseT < 0.5 then
				barras = faseT / 0.5
				linea = 0
			elseif faseT < 0.9 then
				barras = 1
				linea = 1 - (faseT - 0.5) / 0.4
				negroT = 0
			else
				barras, linea, negroT = 1, 0, 0
				textoCentro = "SIN BATERIA"
				fase, faseT = "apagada", 0
			end
		elseif fase == "apagada" then
			negroT = 0
			textoCentro = "SIN BATERIA"
			if faseT >= C.APAGADO_SEG then
				fase, faseT = "reiniciando", 0
				barras, linea = 0, 0
				bateria = C.BATERIA_REINICIO
				avisada20, avisada10 = false, false
				if Shared.reproducir then
					Shared.reproducir("CAMARA_ENCENDER", 0.9)
				end
			end
		elseif fase == "reiniciando" then
			if faseT < 1.6 then
				negroT, ruidoI = 0, 0.8
				textoCentro = "REINICIANDO" .. string.rep(".", math.floor(faseT * 3) % 4)
			elseif faseT < 2.4 then
				local f = (faseT - 1.6) / 0.8
				negroT, ruidoI = f, 0.8 * (1 - f)
				textoCentro = ""
			else
				fase, faseT = "on", 0
				negroT, ruidoI, textoCentro = 1, 0, ""
				mostrarSub("NO TE QUEDES SIN LUZ", 2.8)
			end
		end
	end

	-- ---------- zoom, mano temblorosa y sensibilidad (después de la cámara de Roblox) ----------
	local function enRender(dt)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if not Shared.Ajustes.camara then
			if not fovRestaurado then
				fovRestaurado = true
				cam.FieldOfView = fovBase
				UIS.MouseDeltaSensitivity = sensOrig
			end
			return
		end
		fovRestaurado = false

		local dir = dirTecla ~= 0 and dirTecla or dirBoton
		if dir ~= 0 then
			zoomObj = math.clamp(zoomObj * math.exp(dir * C.ZOOM_VEL * dt), C.ZOOM_MIN, C.ZOOM_MAX)
		elseif Shared.Ajustes.autozoom and apuntando and objetivo then
			zoomObj = math.clamp(objetivo.d / 45, C.ZOOM_MIN, C.ZOOM_MAX)
		end
		zoomPrev = zoom
		zoom += (zoomObj - zoom) * math.min(1, dt * C.ZOOM_SUAVE)

		-- motor del zoom + foco que se escapa
		local vz = math.abs(zoom - zoomPrev) / math.max(dt, 0.001)
		if vz > 0.08 then
			desenfoque = math.max(desenfoque, math.min(1, vz * 0.6))
			if os.clock() - ultimoMotor > 0.6 then
				ultimoMotor = os.clock()
				if Shared.reproducir then
					Shared.reproducir("ZOOM_MOTOR", 0.5)
				end
			end
		end

		cam.FieldOfView = math.deg(2 * math.atan(math.tan(math.rad(fovBase) / 2) / zoom))

		-- con zoom la mira es más lenta (mouse)
		local sens = sensOrig / (math.max(1, zoom) ^ 0.7)
		if math.abs(UIS.MouseDeltaSensitivity - sens) > 0.01 then
			UIS.MouseDeltaSensitivity = sens
		end

		-- cámara en mano: tiembla más con zoom y con interferencia
		if not Shared.Ajustes.suave and C.MANO_TEMBLOROSA then
			local t = os.clock()
			local amp = (0.0006 + 0.0011 * (zoom - 1)) * (1 + 1.5 * mI)
			local rx = math.noise(t * 1.7, 11.1, 0) * amp + math.sin(t * 0.9) * 0.0004
			local ry = math.noise(t * 1.5, 23.3, 0) * amp
			local rz = math.noise(t * 1.1, 5.5, 0) * amp * 0.6
			cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
		end
	end
	pcall(function() RunService:UnbindFromRenderStep("AnalogHorrorCamara") end)
	RunService:BindToRenderStep("AnalogHorrorCamara", Enum.RenderPriority.Camera.Value + 2, enRender)

	-- ---------- bucle principal ----------
	local acumHud, acumDet, acumRuido = 0, 0, 0
	local textoAnterior = nil
	local afAnterior = nil
	local estadoRet = nil

	con(RunService.Heartbeat, function(dt)
		dt = math.min(dt, 0.1)
		local activa = Shared.Ajustes.camara
		if raiz.Visible ~= activa then
			raiz.Visible = activa
			cc.Enabled = activa
			blur.Enabled = activa
			if bloom then
				bloom.Enabled = activa
			end
		end
		if not activa then
			return
		end
		local suave = Shared.Ajustes.suave
		local I = Shared.Interf
		mI = math.max(I.antena, I.torre * 0.85, I.evento)
		local ahora = os.clock()

		if sonidoPendiente and Shared.reproducir then
			sonidoPendiente = false
			Shared.reproducir("CAMARA_ENCENDER", 0.9)
		end

		-- criatura dentro del visor (4 veces por segundo)
		acumDet += dt
		if acumDet >= 0.25 then
			acumDet = 0
			local previo = objetivo
			objetivo = buscarCriatura()
			if objetivo then
				if not previo and ahora - ultimaVez > 30 and fase == "on" then
					mostrarSub("SE MOVIÓ", 2.8)
				end
				ultimaVez = ahora
			end
		end
		apuntando = objetivo ~= nil and objetivo.cent < 0.22 and objetivo.d < 700

		actualizarFase(dt)

		-- pila y cinta
		if fase == "on" then
			local gasto = 1 / (C.BATERIA_MIN * 60)
			gasto *= 1 + (C.BATERIA_CRIATURAS - 1) * mI
			gasto *= 1 + 0.12 * (zoom - 1)
			if apuntando then
				gasto *= 1.4
			end
			bateria = math.max(0, bateria - gasto * dt)
			cinta += dt

			if bateria <= 0.2 and not avisada20 then
				avisada20 = true
				if Shared.pulso then
					Shared.pulso(0.35, 5)
				end
				if Shared.reproducir then
					Shared.reproducir("BATERIA_BEEP", 0.6)
				end
			elseif bateria > 0.25 then
				avisada20 = false
			end
			if bateria <= 0.1 and not avisada10 then
				avisada10 = true
				if Shared.pulso then
					Shared.pulso(0.55, 6)
				end
				if Shared.reproducir then
					Shared.reproducir("BATERIA_BEEP", 0.8)
				end
			elseif bateria > 0.15 then
				avisada10 = false
			end
			if bateria <= 0 and C.BATERIA_AGOTA then
				fase, faseT = "apagando", 0
				if Shared.reproducir then
					Shared.reproducir("CAMARA_APAGAR", 0.9)
				end
			end
		end

		-- capas: negro, apagado, texto central
		negro.BackgroundTransparency = negroT
		barTop.Size = UDim2.new(1, 0, 0.5 * barras, 0)
		barBot.Size = UDim2.new(1, 0, 0.5 * barras, 0)
		lineaF.Visible = linea > 0.01
		lineaF.Size = UDim2.new(linea, 0, 0, 3)
		if textoCentro ~= textoAnterior then
			textoAnterior = textoCentro
			lblCentro.Text = textoCentro
			lblCentro.TextColor3 = textoCentro == "SIN BATERIA" and ROJO or BLANCO
		end
		visor.Visible = negroT > 0.02

		-- estática de las capas (~15 Hz)
		local rI = ruidoI * (suave and 0.5 or 1)
		acumRuido += dt
		if acumRuido >= 0.066 then
			acumRuido = 0
			local n = rI > 0.01 and math.floor(#motasR * math.min(1, rI)) or 0
			for i, m in ipairs(motasR) do
				if i <= n then
					m.Position = UDim2.new(math.random(), 0, math.random(), 0)
					m.Size = UDim2.new(math.random() * 0.4 + 0.03, 0, 0, math.random(1, 5))
					m.BackgroundTransparency = 0.15 + math.random() * 0.45
				elseif m.BackgroundTransparency < 1 then
					m.BackgroundTransparency = 1
				end
			end
		end

		-- oscurecimiento y parpadeo con la pila casi vacía
		if bateria < 0.12 and not suave and fase == "on" and ahora > proxDip then
			proxDip = ahora + Mundo.rand(3, 8)
			dip = 0.7
		end
		dip = math.max(0, dip - dt * 5)
		local base = 0.3 * math.clamp((0.15 - bateria) / 0.15, 0, 1)
		atenua.BackgroundTransparency = 1 - math.max(dip, base)

		-- retícula: se pone roja y "caza" el foco cuando apuntas a algo
		if apuntando then
			tApunta += dt
		else
			tApunta = 0
		end
		local escObj = apuntando and (1 + 0.12 * math.sin(ahora * 7)) or 1
		retEsc.Scale += (escObj - retEsc.Scale) * math.min(1, dt * 10)
		if estadoRet ~= apuntando then
			estadoRet = apuntando
			for _, p in ipairs(retPartes) do
				p.BackgroundColor3 = apuntando and ROJO or BLANCO
			end
			lblAF.TextColor3 = apuntando and ROJO or BLANCO
		end
		local af = "AF"
		if apuntando then
			if tApunta < 2.2 then
				af = "ENFOCANDO" .. string.rep(".", math.floor(ahora * 3) % 4)
			else
				af = "NO SE PUEDE ENFOCAR"
			end
		end
		if af ~= afAnterior then
			afAnterior = af
			lblAF.Text = af
		end

		-- imagen: tinte frío/cálido, grano suave, blur de foco, brillo de luces
		cc.Saturation = -0.18 - 0.25 * mI
		cc.Contrast = 0.12 + 0.12 * mI
		cc.Brightness = -0.03 - 0.07 * math.clamp((0.2 - bateria) / 0.2, 0, 1)
		cc.TintColor = Color3.fromRGB(255, 238, 220):Lerp(Color3.fromRGB(190, 222, 228), math.min(1, mI) * 0.5)
		desenfoque = math.max(0, desenfoque - dt * 1.4)
		local objBlur = 0.8 + 5.5 * desenfoque
		if apuntando then
			objBlur += 3 * math.clamp(1 - objetivo.d / 700, 0.2, 1) * math.clamp(tApunta / 2.2, 0, 1)
		end
		if suave then
			objBlur = math.min(objBlur, 3)
		end
		blur.Size += (objBlur - blur.Size) * math.min(1, dt * 6)

		-- polvo flotando
		for _, p in ipairs(polvo) do
			p.x += p.vx * dt * (suave and 0.5 or 1)
			p.y += p.vy * dt * (suave and 0.5 or 1)
			if p.y < -0.02 then
				p.y = 1.02
				p.x = math.random()
			end
			p.x = p.x % 1
			p.f.Position = UDim2.new(p.x, 0, p.y, 0)
			p.f.BackgroundTransparency = math.clamp(p.base + 0.25 * math.sin(ahora * 1.6 + p.fase), 0.3, 0.95)
		end

		-- marca del zoom
		marca.Position = UDim2.new((zoom - C.ZOOM_MIN) / math.max(0.01, C.ZOOM_MAX - C.ZOOM_MIN), 0, 0.5, 0)

		-- alerta de pila
		local alerta = ""
		if bateria <= 0.08 then
			alerta = "CAMBIAR BATERIA"
		elseif bateria <= 0.2 then
			alerta = "BATERIA BAJA"
		end
		lblAlerta.Text = alerta
		lblAlerta.Visible = alerta ~= "" and (suave or math.floor(ahora * 2) % 2 == 0)

		-- subtítulo estilo video: aparece, aguanta y se desvanece
		if C.SUBTITULOS and fase == "on" and ahora > proxSub then
			proxSub = ahora + Mundo.rand(C.SUBT_MIN, C.SUBT_MAX)
			mostrarSub(C.MENSAJES[math.random(#C.MENSAJES)], 2.6)
		end
		local ts = ahora - subT0
		local aSub = 1
		if subDur > 0 and ts < subDur then
			if ts < 0.2 then
				aSub = 1 - ts / 0.2
			elseif ts > subDur - 0.5 then
				aSub = (ts - (subDur - 0.5)) / 0.5
			else
				aSub = 0
			end
		end
		sub.TextTransparency = aSub
		subStroke.Transparency = aSub

		-- textos (5 Hz): cinta, pila, zoom; se corrompen con interferencia fuerte
		acumHud += dt
		if acumHud >= 0.2 then
			acumHud = 0
			local pg2 = (suave or mI < 0.45) and 0 or (mI - 0.45) * 0.5
			lblCinta.Text = glitch("CINTA " .. formato(cinta), pg2)
			lblResta.Text = glitch("RESTA " .. formato(CINTA_TOTAL - cinta), pg2)
			lblBat.Text = glitch(string.format("%d%%", math.ceil(bateria * 100 - 1e-6)), pg2)
			lblZoom.Text = glitch(string.format("ZOOM x%.1f", zoom), pg2) .. (Shared.Ajustes.autozoom and " AUTO" or "")

			local nSeg = math.ceil(bateria * 4 - 1e-6)
			local baja = bateria <= 0.2
			local parpadea = bateria <= 0.12 and not suave and math.floor(ahora) % 2 == 0
			local col = baja and ROJO or BLANCO
			batBorde.Color = col
			batNub.BackgroundColor3 = col
			batCont.Visible = not parpadea
			for i, s in ipairs(batSeg) do
				s.BackgroundColor3 = col
				s.BackgroundTransparency = i <= nSeg and 0 or 1
			end

			-- la fecha y la hora del VHS se corrompen cuando algo anda cerca
			if Shared.hud and not suave and mI > 0.5 and math.random() < 0.12 then
				Shared.hud.fecha.Text = glitch(Shared.hud.fecha.Text, 0.5)
				Shared.hud.hora.Text = glitch(Shared.hud.hora.Text, 0.35)
			end
		end
	end)

	-- ---------- API para el módulo de control ----------
	Shared.subtitulo = mostrarSub
	Shared.Camara = {
		zoomDir = function(d)
			dirTecla = d
		end,
		zoomA = function(z)
			zoomObj = math.clamp(z, C.ZOOM_MIN, C.ZOOM_MAX)
			aviso(string.format("ZOOM x%.1f", zoomObj))
		end,
		zoomMas = function()
			zoomObj = math.clamp(zoomObj * C.ZOOM_PASO, C.ZOOM_MIN, C.ZOOM_MAX)
		end,
		zoomMenos = function()
			zoomObj = math.clamp(zoomObj / C.ZOOM_PASO, C.ZOOM_MIN, C.ZOOM_MAX)
		end,
		bateria = function(p)
			bateria = p or 1
			avisada20, avisada10 = false, false
			aviso("BATERIA CAMBIADA")
		end,
		alternar = function()
			Shared.Ajustes.camara = not Shared.Ajustes.camara
			if Shared.Ajustes.camara and C.INTRO then
				fase, faseT = "intro", 0
				negroT, ruidoI = 0, 1
				sonidoPendiente = true
			end
			aplicarPersona()
			aviso(Shared.Ajustes.camara and "CAMARA: ON" or "CAMARA: OFF")
		end,
		persona = function()
			Shared.Ajustes.primera = not Shared.Ajustes.primera
			aplicarPersona()
			aviso(Shared.Ajustes.primera and "PRIMERA PERSONA: ON" or "PRIMERA PERSONA: OFF")
		end,
		autozoom = function()
			Shared.Ajustes.autozoom = not Shared.Ajustes.autozoom
			aviso(Shared.Ajustes.autozoom and "AUTOZOOM: ON" or "AUTOZOOM: OFF")
		end,
	}

	aplicarPersona()

	env.AH_CAMARA_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function() RunService:UnbindFromRenderStep("AnalogHorrorCamara") end)
		pcall(function() gui:Destroy() end)
		pcall(function() cc:Destroy() end)
		pcall(function() blur:Destroy() end)
		if bloom then
			pcall(function() bloom:Destroy() end)
		end
		pcall(function()
			local cam = Workspace.CurrentCamera
			if cam then
				cam.FieldOfView = fovBase
			end
			UIS.MouseDeltaSensitivity = sensOrig
			jugador.CameraMode = modoOrig
		end)
		Shared.Camara = nil
		Shared.subtitulo = nil
	end

	print("[CAMARA] Cargado. Z/X = zoom | C = cámara ON/OFF | chat: /zoom+ /zoom- /zoom N /bateria /camara /persona /autozoom")
end

--##########################################################################
-- MÓDULO 8: CONTROL (teclas y comandos de chat; solo el zoom tiene botones, en celular)
--##########################################################################
local function MODULO_CONTROL()
	if env.AH_CONTROL_LIMPIAR then
		pcall(env.AH_CONTROL_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local function aviso(txt)
		if Shared.aviso then
			Shared.aviso(txt)
		end
	end
	local function alternarVHS()
		Shared.Ajustes.vhs = not Shared.Ajustes.vhs
		aviso(Shared.Ajustes.vhs and "VHS: ON" or "VHS: OFF")
	end
	local function alternarSuave()
		Shared.Ajustes.suave = not Shared.Ajustes.suave
		aviso(Shared.Ajustes.suave and "MODO SUAVE: ON" or "MODO SUAVE: OFF")
	end
	local function alternarSonido()
		Shared.Ajustes.sonido = not Shared.Ajustes.sonido
		aviso(Shared.Ajustes.sonido and "SONIDO: ON" or "SONIDO: OFF")
	end

	con(UIS.InputBegan, function(input, procesado)
		if procesado then
			return
		end
		local k = input.KeyCode
		if k == CONFIG.TECLA_VHS then
			alternarVHS()
		elseif k == CONFIG.TECLA_SUAVE then
			alternarSuave()
		elseif k == CONFIG.TECLA_SONIDO then
			alternarSonido()
		elseif k == CONFIG.TECLA_CAMARA then
			if Shared.Camara then
				Shared.Camara.alternar()
			end
		elseif k == CONFIG.TECLA_ZOOM_MAS then
			if Shared.Camara then
				Shared.Camara.zoomDir(1)
			end
		elseif k == CONFIG.TECLA_ZOOM_MENOS then
			if Shared.Camara then
				Shared.Camara.zoomDir(-1)
			end
		end
	end)

	con(UIS.InputEnded, function(input)
		local k = input.KeyCode
		if (k == CONFIG.TECLA_ZOOM_MAS or k == CONFIG.TECLA_ZOOM_MENOS) and Shared.Camara then
			Shared.Camara.zoomDir(0)
		end
	end)

	if CONFIG.COMANDOS_CHAT then
		con(jugador.Chatted, function(msg)
			local m = string.lower(msg)
			if m == "/vhs" then
				alternarVHS()
			elseif m == "/suave" then
				alternarSuave()
			elseif m == "/sonido" then
				alternarSonido()
			elseif m == "/antena" then
				if Shared.Antena then
					Shared.Antena.forzar()
				end
			elseif m == "/torre" then
				if Shared.Torre then
					Shared.Torre.forzar()
				end
			elseif m == "/camara" then
				if Shared.Camara then
					Shared.Camara.alternar()
				end
			elseif m == "/zoom+" then
				if Shared.Camara then
					Shared.Camara.zoomMas()
				end
			elseif m == "/zoom-" then
				if Shared.Camara then
					Shared.Camara.zoomMenos()
				end
			elseif m:match("^/zoom%s+[%d%.]+$") then
				local n = tonumber(m:match("^/zoom%s+([%d%.]+)$"))
				if Shared.Camara and n then
					Shared.Camara.zoomA(n)
				end
			elseif m == "/bateria" then
				if Shared.Camara then
					Shared.Camara.bateria(1)
				end
			elseif m == "/persona" then
				if Shared.Camara then
					Shared.Camara.persona()
				end
			elseif m == "/autozoom" then
				if Shared.Camara then
					Shared.Camara.autozoom()
				end
			elseif m == "/ocultar" then
				if Shared.Antena then
					Shared.Antena.ocultar()
				end
				if Shared.Torre then
					Shared.Torre.ocultar()
				end
			end
		end)
	end

	env.AH_CONTROL_LIMPIAR = function()
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
	end

	print("[CONTROL] Cargado. V = VHS | B = suave | N = sonido | C = cámara | Z/X = zoom | chat: /vhs /suave /sonido /antena /torre /ocultar /camara /zoom+ /zoom- /zoom N /bateria /persona /autozoom")
end

--##########################################################################
-- ARRANQUE: cada módulo aislado con pcall (VHS y atmósfera primero)
--##########################################################################
local MODULOS = {
	{ "VHS", MODULO_VHS },
	{ "PROXIMIDAD", MODULO_PROXIMIDAD },
	{ "AUDIO", MODULO_AUDIO },
	{ "CAMARA", MODULO_CAMARA },
	{ "ANTENA", MODULO_ANTENA },
	{ "TORRE", MODULO_TORRE },
	{ "DIRECTOR", MODULO_DIRECTOR },
	{ "CONTROL", MODULO_CONTROL },
}

for _, par in ipairs(MODULOS) do
	task.spawn(function()
		local ok, err = pcall(par[2])
		if not ok then
			warn("[ANALOG-HORROR] Falló el módulo " .. par[1] .. ": " .. tostring(err))
		end
	end)
end
