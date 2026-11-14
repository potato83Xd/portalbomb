--!nonstrict
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
--    equipar (la mano gira y se asienta), disparar (el brazo sube y vuelve) y efectos del disparo
--    (chispas, pulso de luz, destello verde, temblor de camara). Brazo: solo R6.
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
	-- UN solo candado (botón arriba a la derecha de la pantalla):
	--   abierto  -> botones flotantes y menús se pueden mover
	--   cerrado  -> todo queda fijo
	-- UI.agregar(panel) añade al menú una barra superior para arrastrarlo.
	-- El estado vive mientras el script esté activo.
	local UI = { cerrado = false, boton = nil }
	Shared.UI = UI

	function UI.bloqueado()
		return UI.cerrado == true
	end

	local function pintar()
		local btn = UI.boton
		if btn and btn.Parent then
			btn.Text = UI.cerrado and "🔒" or "🔓"
			btn.BackgroundColor3 = UI.cerrado and Color3.fromRGB(150, 40, 50) or Color3.fromRGB(16, 70, 56)
		end
	end

	function UI.alternar()
		UI.cerrado = not UI.cerrado
		pintar()
	end

	local lockGui = nil

	task.spawn(function()
		local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
		local viejo = pg:FindFirstChild("RickLockGui")
		if viejo then
			viejo:Destroy()
		end

		local g = Instance.new("ScreenGui")
		g.Name = "RickLockGui"
		g.ResetOnSpawn = false
		g.DisplayOrder = 100
		g.Parent = pg
		lockGui = g

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

		UI.boton = b
		pintar()

		con(b.Activated, function()
			UI.alternar()
		end)
	end)

	-- Evita perder el menú fuera de la pantalla
	local function sujetar(panel)
		local padre = panel.Parent
		if not (padre and padre:IsA("GuiBase2d")) then
			return
		end
		local vs = padre.AbsoluteSize
		local ap = panel.AbsolutePosition - padre.AbsolutePosition
		local as = panel.AbsoluteSize
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
			panel.Position = panel.Position + UDim2.fromOffset(dx, dy)
		end
	end

	function UI.agregar(panel, nombre)
		-- Barra de arrastre (deja libre la X de la derecha)
		local barra = Instance.new("Frame")
		barra.Name = "BarraArrastre"
		barra.BackgroundTransparency = 1
		barra.BorderSizePixel = 0
		barra.Position = UDim2.new(0, 0, 0, 0)
		barra.Size = UDim2.new(1, -60, 0, 46)
		barra.Active = true
		barra.ZIndex = 10
		barra.Parent = panel

		local arrastrando = false
		local inicio, posIni

		con(barra.InputBegan, function(input)
			if UI.bloqueado() then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				arrastrando = true
				inicio = input.Position
				posIni = panel.Position
			end
		end)

		con(UIS.InputChanged, function(input)
			if not arrastrando then
				return
			end
			if UI.bloqueado() then
				arrastrando = false
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				local d = input.Position - inicio
				panel.Position = UDim2.new(
					posIni.X.Scale, posIni.X.Offset + d.X,
					posIni.Y.Scale, posIni.Y.Offset + d.Y
				)
			end
		end)

		con(UIS.InputEnded, function(input)
			if not arrastrando then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				arrastrando = false
				sujetar(panel)
			end
		end)

		return barra
	end

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
		if lockGui then
			pcall(function() lockGui:Destroy() end)
		end
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
local FIRE_COOLDOWN = 0.35

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
	Extras = {},              -- portales de salida (los que salen DETRAS del jugador objetivo)
	behindDist = 9,           -- distancia del portal de salida detras del jugador (studs)
	behindGap = 3,            -- studs delante del portal de salida donde apareces
	wallDepth = 1.4,          -- que tan adentro de un portal de pared debes estar para cruzar
	openTime = 0.45,          -- duracion de la animacion de apertura
	closeTime = 0.28,         -- duracion de la animacion de cierre
	recoilAngle = 0.42,       -- retroceso del brazo al disparar (radianes)
	muzzle = 1.5,             -- studs delante de la mano donde nace el rayo
	aimArm = true,            -- la mano/brazo sigue el cursor
	turnBody = false,         -- el cuerpo gira hacia donde apuntas
	anims = true,             -- animaciones del brazo y del disparo ON/OFF
	portalAnims = false,      -- v5: animaciones propias del portal ELIMINADAS (apertura, cierre, pulso, salida)
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
	emerge = false,           -- v5: salida animada ELIMINADA (el teletransporte es directo)
	emergeTime = 1.5,         -- duracion de esa animacion (s)
	em = nil,                 -- estado de la animacion de salida en curso
	-- v3
	closeMode = "collapse",   -- "v2" = cierre original | "collapse" = cierre por colapso (nuevo)
	collapseTime = 0.65,      -- duracion del colapso (s)
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
		A = { rot = Vector3.new(40, -15, -20), off = Vector3.new(0, -0.15, -0.15), t = 0.12 }, -- pose de entrada
		B = { rot = Vector3.new(35, -10, -15), off = Vector3.new(0, -0.10, -0.10), t = 0.15 }, -- pose sostenida
		up = { rot = Vector3.new(-70, 20, -30), off = Vector3.new(0, 0.25, 0.10), t = 0.22 },  -- brazo arriba al disparar
		twist = 110,          -- giro de la mano al equipar (grados)
		twistT = 0.14,        -- duracion del giro (s)
		backT = 0.15,         -- regreso del disparo a la pose B (s)
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

function NX.SizeVec(unit, m, mul)
	local u = { unit.X, unit.Y, unit.Z }

	u[m.thin] *= mul
	u[m.third] *= mul * NX.widthMul
	u[m.tall] *= mul * NX.heightMul

	return Vector3.new(u[1], u[2], u[3])
end

local function CreatePortalPart()

	local part = nil
	local measure = nil
	local unit = nil
	local meshObj = nil

	local ok, result

	if PortalTemplate then
		ok, result = true, PortalTemplate:Clone()
	else
		ok, result = pcall(function()
			return AssetService:CreateMeshPartAsync(PORTAL_MESH)
		end)
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

function NX.EaseOutBack(a)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
end

-- Escala visual del portal (f = 1 es su tamano normal)
function NX.SetScale(entry, f)
	f = math.max(f, 0.02)

	local part = entry.part

	if not (part and part.Parent) then
		return
	end

	local mul = (entry.sizeMul or PORTAL_SIZE) * f

	if entry.unit then
		if entry.measure then
			part.Size = NX.SizeVec(entry.unit, entry.measure, mul)
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

-- Modo colapso: al COMPLETAR el teletransporte, el portal de entrada y el de salida se encogen
function NX.CollapsePair(a, b)

	if NX.closeMode ~= "collapse" then
		return
	end

	for _, e in ipairs({ a, b }) do

		if e and not e.closed then

			local i = table.find(Portals, e)

			if i then
				table.remove(Portals, i)
			end

			ClosePortal(e)
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
		local dirty = false

		if entry.openT then
			entry.openT += dt
			local a = math.clamp(entry.openT / NX.openTime, 0, 1)
			f = NX.EaseOutBack(a)
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
			NX.SetScale(entry, f)
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

	entry.openT = 0
	NX.SetScale(entry, 0.02)

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
		expire = os.clock() + 120,
	}

	ApplyExitPose(e, ground, face)

	part.CFrame = EntryCFrame(e)
	part.Parent = PortalFolder

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

local function OpenPortal(position, normal, flying)

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
	}

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

	part.CFrame = EntryCFrame(entry)
	part.Parent = PortalFolder

	PlaySound(SOUND_OPEN, part)

	table.insert(Portals, entry)

	-- animacion de apertura
	NX.StartOpen(entry)

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
	beam.Parent = PortalFolder

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

	model.Parent = PortalFolder

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
	local Atw = A * CFrame.Angles(0, math.rad(V.twist), 0)

	local D = B

	-- EQUIPAR: la mano gira mientras sube -> se asienta en A con rebote -> pasa a la pose B
	if NX.vmEquipT then

		NX.vmEquipT += dt
		local t = NX.vmEquipT
		local t1 = V.twistT
		local t2 = t1 + V.A.t
		local t3 = t2 + V.B.t

		if t < t1 then
			local a = t / t1
			D = CFrame.new():Lerp(Atw, 1 - (1 - a) * (1 - a))
		elseif t < t2 then
			D = Atw:Lerp(A, NX.EaseOutBack((t - t1) / V.A.t))
		elseif t < t3 then
			local a = (t - t2) / V.B.t
			D = A:Lerp(B, 1 - (1 - a) * (1 - a))
		else
			NX.vmEquipT = nil
		end
	end

	-- DISPARAR: el brazo sube con rebote (Back Out) y vuelve a B suavemente (Sine Out)
	if NX.vmShotT then

		NX.vmShotT += dt
		local t = NX.vmShotT
		local tUp = V.up.t
		local split = tUp * 0.6

		if t < split then
			D = B:Lerp(U, NX.EaseOutBack(t / tUp))
		elseif t < split + V.backT then
			local from = B:Lerp(U, NX.EaseOutBack(split / tUp))
			D = from:Lerp(B, math.sin((t - split) / V.backT * math.pi / 2))
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
	if NX.anims and NX.arm.r6 and want == 1 then

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
		pcall(NX.CollapsePair, em.a, em.b)
	end
end

-- b = portal por el que sales | lookAt = punto al que miras (opcional) | launch = empujon final
-- a = portal por el que entraste (se cierra por colapso al terminar, si ese modo esta activo)
function NX.StartEmerge(b, root, lookAt, launch, a)

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

	-- destello verde de pantalla
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
		or not CanShoot
		or not PortalGun then
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

	CanShoot = false

	-- El cooldown se programa ANTES: si algo falla al abrir el portal,
	-- el disparo no se queda bloqueado para siempre.
	task.delay(FIRE_COOLDOWN, function()
		CanShoot = true
	end)

	local muzzlePos = NX.GetMuzzle(handle)

	pcall(FireBeam, muzzlePos, hitPos)
	pcall(NX.ShootAnim, muzzlePos, hitPos - muzzlePos)

	local ok, err = pcall(OpenPortal, hitPos, hitNormal, flying)

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

	if depth < -(entry.backDepth or 2) or depth > entry.enterDepth then
		return false
	end

	return (alongTall / hh) ^ 2 + (alongSide / hw) ^ 2 <= 1
end

--------------------------------------------------
-- GIRO Y TELETRANSPORTE
--------------------------------------------------

Con(RunService.Heartbeat, function(dt)

	for _, entry in ipairs(Portals) do
		NX.TickEntry(entry, dt)
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

	local root = Character:FindFirstChild("HumanoidRootPart")

	if not root then
		return
	end

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

		if IsInsidePortal(Portals[i], root) then
			near = i
			break
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
			ex.expire = os.clock() + 1.8 + ((NX.emerge and NX.portalAnims) and NX.emergeTime or 0)   -- se cierra solo despues de salir
		else
			local g2, f2 = NX.BehindSpot(tRoot)
			dest = Vector3.new(g2.X, g2.Y + 3.2, g2.Z) + f2 * NX.behindGap
		end

		-- Apareces detras de el, mirando hacia su espalda (saliendo del portal pata por pata)
		if not (ex and NX.StartEmerge(ex, root, tRoot.Position, Vector3.zero, entry)) then
			root.CFrame = CFrame.lookAt(dest, Vector3.new(tRoot.Position.X, dest.Y, tRoot.Position.Z))
			root.AssemblyLinearVelocity = Vector3.zero
			pcall(NX.CollapsePair, entry, ex)   -- teletransporte completado (sin animacion)
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

		pcall(function()
			TeleportService:Teleport(DestPlaceId, Player)
		end)

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
StandButton.Activated:Connect(ToggleStand)

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
	[1] = { max = 2, spin = 150, speed = 450, cooldown = 0.35 },
	[2] = { max = 6, spin = 150, speed = 450, cooldown = 0.35 },
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
		0.05, 0.05, 3, "%.2f")

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
		hl.Parent = PortalFolder
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

-- PAGINA JUEGOS ----------------------------------

local GamesPage = Pages[4]

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

local function RefreshGames()
	if DestPlaceId then
		GameStatus.Text = "Destino: " .. DestPlaceId
		GameStatus.TextColor3 = GREEN
	else
		GameStatus.Text = "Sin destino (portales normales)"
		GameStatus.TextColor3 = Color3.new(1, 1, 1)
	end
end

ConfigButton.Activated:Connect(function()

	local id = tonumber(IdBox.Text)

	if id and id > 0 then
		DestPlaceId = math.floor(id)
		RefreshGames()
	else
		GameStatus.Text = "ID invalido"
		GameStatus.TextColor3 = Color3.fromRGB(255, 90, 90)
	end
end)

ClearDest.Activated:Connect(function()
	DestPlaceId = nil
	RefreshGames()
end)

table.insert(Refreshers, RefreshGames)

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

local mc = Instance.new("UITextSizeConstraint")
mc.MaxTextSize = 22
mc.MinTextSize = 8
mc.Parent = MenuButton

MenuButton.Activated:Connect(function()
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
