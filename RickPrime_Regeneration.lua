--[[
================================================================================
  RICK PRIME REGENERATION  -  UN SOLO SCRIPT
  Pon este archivo como "Script" (normal) en ServerScriptService. Nada mas.

  Como funciona: el mismo Script corre en el servidor y, al arrancar, se
  clona a ReplicatedStorage con RunContext = Client para que cada jugador
  ejecute la parte de pantalla/camara. Si IsClient() es true corre la parte
  de cliente; si no, la del servidor.

  Replica "Rick Prime Regeneration v3" y "v4 (combined v2 and v3)":
    flash psicodelico -> tinta negra -> explosion con fuego y humo -> cuerpo
    en partes neon con sangre y rayos de colores -> las partes se juntan ->
    se levanta entre llamas -> piel, pantalones y camisa por etapas -> cola
    de fuego.

  Disparadores: dano letal, tecla H (cambiable en la seccion de cliente),
  o BindableEvent "RickPrimeRegenTrigger" en ServerStorage (fire(player)).
  Variante: Config.Variant = "v3" | "v4", o atributo RickPrimeVariant en
  Workspace.
================================================================================
]]

local RunService = game:GetService("RunService")

----------------------------------------------------------------------------
-- PARTE CLIENTE (se ejecuta solo en la copia con RunContext = Client)
----------------------------------------------------------------------------
if RunService:IsClient() then

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Event = ReplicatedStorage:WaitForChild("RickPrimeRegenEvent")

--// CONFIGURACION --------------------------------------------------------------
local Config = {
	TriggerKey = Enum.KeyCode.H,
	ShowTouchButton = true,

	Palette = {
		Color3.fromRGB(18, 190, 185),   -- verde azulado
		Color3.fromRGB(20, 150, 160),
		Color3.fromRGB(255, 118, 62),   -- naranja
		Color3.fromRGB(235, 90, 70),
		Color3.fromRGB(70, 120, 255),   -- azul
		Color3.fromRGB(170, 92, 255),   -- violeta
		Color3.fromRGB(255, 150, 175),  -- rosa
	},
	PortalBlobs = 34,
	PortalBlur = 26,

	InkTint = Color3.fromRGB(255, 172, 168),
	InkTendrils = 46,
	InkDots = 84,

	Blast = {
		Brightness = 0.32,
		Contrast = 0.16,
		Saturation = 0.2,
		BloomIntensity = 1.7,
		BloomSize = 38,
		BloomThreshold = 0.78,
		HazeAdd = 6,
		DensityAdd = 0.35,
		Time = 0.85,
	},

	Shake = {
		MaxDistance = 220,
		PositionScale = 1.6,
		RotationScale = 0.03,
		Frequency = 38,
	},

	Camera = {
		BlendIn = 0.45,
		BlendOut = 0.7,
		Push = { Distance = 15, Height = 3.4, FovTarget = 60, DriftSpeed = 0.5 },
		Low = { Radius = 11, Height = 2.1, LookHeight = 0.9, OrbitSpeed = 0.12, FovTarget = 66 },
	},
}

--// UTILIDADES -----------------------------------------------------------------
local rng = Random.new()

local function rand(a, b)
	return rng:NextNumber(a, b)
end

local function clamp01(x)
	return math.max(0, math.min(1, x))
end

local function easeInOut(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - ((-2 * t + 2) ^ 3) / 2
end

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function tween(inst, seconds, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function pickColor()
	return Config.Palette[rng:NextInteger(1, #Config.Palette)]
end

--// GUI RAIZ -------------------------------------------------------------------
local Gui = make("ScreenGui", {
	Name = "RickPrimeRegenFX",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

--// EFECTOS DE PANTALLA --------------------------------------------------------
local Screen = {}

local function screenBase()
	local size = Gui.AbsoluteSize
	return math.max(1, math.min(size.X, size.Y))
end

-- Flash psicodelico: manchas grandes y borrosas de colores que estallan desde el centro
function Screen.portalFlash(duration)
	local base = make("Frame", {
		Name = "PortalFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 160, 160),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 10,
	}, Gui)
	tween(base, duration * 0.35, { BackgroundTransparency = 0.12 })

	local blur = make("BlurEffect", { Name = "RPPortalBlur", Size = 0 }, Lighting)
	tween(blur, duration * 0.5, { Size = Config.PortalBlur })

	for i = 1, Config.PortalBlobs do
		local finalSize = rand(0.28, 0.85)
		local startSize = finalSize * rand(0.15, 0.4)
		local startPos = UDim2.fromScale(0.5 + rand(-0.12, 0.12), 0.5 + rand(-0.12, 0.12))
		local endPos = UDim2.fromScale(0.5 + rand(-0.5, 0.5), 0.5 + rand(-0.55, 0.55))
		local blob = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = startPos,
			Size = UDim2.fromScale(startSize, startSize * 0.56),
			BackgroundColor3 = pickColor(),
			BackgroundTransparency = rand(0.08, 0.38),
			BorderSizePixel = 0,
			ZIndex = 11 + (i % 5),
			Rotation = rand(0, 360),
		}, base)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, blob)
		tween(blob, duration, {
			Position = endPos,
			Size = UDim2.fromScale(finalSize, finalSize * 0.56),
			Rotation = blob.Rotation + rand(-80, 80),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	task.delay(duration, function()
		tween(base, 0.08, { BackgroundTransparency = 1 })
		for _, c in ipairs(base:GetChildren()) do
			if c:IsA("Frame") then
				tween(c, 0.08, { BackgroundTransparency = 1 })
			end
		end
		tween(blur, 0.1, { Size = 0 })
		task.delay(0.15, function()
			base:Destroy()
			blur:Destroy()
		end)
	end)
end

-- Salpicadura de tinta negra sobre tinte rosado (el cuadro oscuro antes del fuego)
function Screen.inkBurst(duration)
	local px = screenBase()
	local root = make("Frame", {
		Name = "InkBurst",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.InkTint,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, Gui)

	local blur = make("BlurEffect", { Name = "RPInkBlur", Size = 14 }, Lighting)
	tween(blur, duration, { Size = 0 })

	-- mancha central
	local core = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(px * 0.05, px * 0.05),
		BackgroundColor3 = Color3.fromRGB(8, 6, 6),
		BorderSizePixel = 0,
		ZIndex = 22,
	}, root)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, core)
	tween(core, duration * 0.5, { Size = UDim2.fromOffset(px * 0.4, px * 0.4) }, Enum.EasingStyle.Quart)

	local items = { core }

	-- ramas radiales
	for i = 1, Config.InkTendrils do
		local angle = (i / Config.InkTendrils) * 360 + rand(-6, 6)
		local len = px * rand(0.18, 0.62)
		local thick = rand(3, 14)
		local t = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, thick),
			Rotation = angle,
			BackgroundColor3 = Color3.fromRGB(10, 8, 8),
			BackgroundTransparency = rand(0, 0.2),
			BorderSizePixel = 0,
			ZIndex = 21,
		}, root)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, t)
		tween(t, duration * rand(0.35, 0.6), { Size = UDim2.fromOffset(len, thick * 0.4) }, Enum.EasingStyle.Quart)
		table.insert(items, t)
	end

	-- gotas sueltas
	for _ = 1, Config.InkDots do
		local ang = rand(0, math.pi * 2)
		local rad = px * rand(0.08, 0.7)
		local s = rand(3, 20)
		local d = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0),
			BackgroundColor3 = Color3.fromRGB(12, 10, 10),
			BorderSizePixel = 0,
			ZIndex = 21,
		}, root)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
		local endPos = UDim2.new(0.5, math.cos(ang) * rad, 0.5, math.sin(ang) * rad)
		tween(d, duration * rand(0.3, 0.55), { Position = endPos, Size = UDim2.fromOffset(s, s) }, Enum.EasingStyle.Quart)
		table.insert(items, d)
	end

	task.delay(duration * 0.55, function()
		local t = duration * 0.45
		tween(root, t, { BackgroundTransparency = 1 })
		for _, it in ipairs(items) do
			if it.Parent then
				tween(it, t, { BackgroundTransparency = 1 })
			end
		end
		task.delay(t + 0.1, function()
			root:Destroy()
			blur:Destroy()
		end)
	end)
end

-- Brillo, bloom y neblina blanca al estallar
function Screen.blast()
	local B = Config.Blast
	local cc = make("ColorCorrectionEffect", {
		Name = "RPBlastCC",
		Brightness = B.Brightness,
		Contrast = B.Contrast,
		Saturation = B.Saturation,
	}, Lighting)
	tween(cc, B.Time, { Brightness = 0, Contrast = 0, Saturation = 0 }, Enum.EasingStyle.Quad)

	local bloom = make("BloomEffect", {
		Name = "RPBlastBloom",
		Intensity = B.BloomIntensity,
		Size = B.BloomSize,
		Threshold = B.BloomThreshold,
	}, Lighting)
	tween(bloom, B.Time + 0.2, { Intensity = 0 }, Enum.EasingStyle.Quad)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local createdAtmosphere = false
	if not atmosphere then
		atmosphere = make("Atmosphere", { Density = 0, Haze = 0, Offset = 0.25 }, Lighting)
		createdAtmosphere = true
	end
	local origHaze, origDensity = atmosphere.Haze, atmosphere.Density
	atmosphere.Haze = origHaze + B.HazeAdd
	atmosphere.Density = math.min(0.9, origDensity + B.DensityAdd)
	tween(atmosphere, B.Time + 0.5, { Haze = origHaze, Density = origDensity })

	task.delay(B.Time + 0.8, function()
		cc:Destroy()
		bloom:Destroy()
		if createdAtmosphere then
			atmosphere:Destroy()
		end
	end)
end

--// TEMBLOR DE CAMARA ----------------------------------------------------------
local Shake = { Active = {} }

function Shake.add(intensity, duration, origin)
	local cam = Workspace.CurrentCamera
	if origin and cam then
		local dist = (cam.CFrame.Position - origin).Magnitude
		intensity *= clamp01(1 - dist / Config.Shake.MaxDistance)
	end
	if intensity <= 0.01 then
		return
	end
	table.insert(Shake.Active, { I = intensity, D = math.max(0.05, duration), T = 0, Seed = rand(0, 1000) })
end

RunService:BindToRenderStep("RickPrimeShake", Enum.RenderPriority.Camera.Value + 10, function(dt)
	if #Shake.Active == 0 then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local pos = Vector3.zero
	local rot = Vector3.zero
	for i = #Shake.Active, 1, -1 do
		local s = Shake.Active[i]
		s.T += dt
		local k = 1 - s.T / s.D
		if k <= 0 then
			table.remove(Shake.Active, i)
		else
			local amp = s.I * k * k
			local t = s.T * Config.Shake.Frequency
			pos += Vector3.new(math.noise(t, s.Seed, 0), math.noise(0, t, s.Seed), 0) * 2 * amp * Config.Shake.PositionScale
			rot += Vector3.new(math.noise(t, 0, s.Seed), math.noise(s.Seed, t, 0), math.noise(0, s.Seed, t)) * 2 * amp * Config.Shake.RotationScale
		end
	end
	cam.CFrame = cam.CFrame * CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
end)

--// DIRECTOR DE CAMARA ---------------------------------------------------------
-- push (v4): empuje corto hacia la explosion y retorno.
-- low  (v3): camara baja, orbitando lento la pila de restos ardiendo.
local Director = {
	Active = false,
	Mode = "push",
	Target = Vector3.zero,
	Duration = 2,
	Elapsed = 0,
	StartCF = nil,
	StartFov = 70,
	StartOffset = Vector3.new(0, 6, 14),
	RootPos = Vector3.zero,
	Releasing = false,
	ReleaseT = 0,
	ReleaseFrom = nil,
	ReleaseTo = nil,
	Angle = 0,
}

function Director.prepare(data)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	Director.RootPos = data.Root or Director.RootPos
	Director.StartOffset = cam.CFrame.Position - Director.RootPos
	Director.StartFov = cam.FieldOfView
end

local function desiredCF()
	local cam = Workspace.CurrentCamera
	local t = Director.Elapsed
	local target = Director.Target
	if Director.Mode == "low" then
		local L = Config.Camera.Low
		local ang = Director.Angle + t * L.OrbitSpeed
		local pos = target + Vector3.new(math.cos(ang) * L.Radius, L.Height, math.sin(ang) * L.Radius)
		return CFrame.lookAt(pos, target + Vector3.new(0, L.LookHeight, 0)), L.FovTarget
	end
	local P = Config.Camera.Push
	local from = Director.StartCF.Position
	local away = from - target
	if away.Magnitude < 0.5 then
		away = Vector3.new(0, 0, 1)
	end
	local drift = 1 + math.sin(t * 1.4) * 0.03 - t * 0.02 * P.DriftSpeed
	local pos = target + away.Unit * (P.Distance * drift) + Vector3.new(0, P.Height, 0)
	return CFrame.lookAt(pos, target + Vector3.new(0, 1.2, 0)), P.FovTarget
end

function Director.start(data)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	Director.Mode = data.Mode or "push"
	Director.Target = data.Target or Director.Target
	Director.Duration = data.Duration or 2
	Director.Elapsed = 0
	Director.StartCF = cam.CFrame
	Director.StartFov = cam.FieldOfView
	Director.Releasing = false
	Director.Active = true
	local away = cam.CFrame.Position - Director.Target
	Director.Angle = math.atan2(away.Z, away.X)
	cam.CameraType = Enum.CameraType.Scriptable
end

function Director.release(data)
	if not Director.Active or Director.Releasing then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local rootPos = (data and data.Target) or Director.RootPos
	local lookAt = rootPos + Vector3.new(0, 2, 0)
	local pos = rootPos + Director.StartOffset
	Director.ReleaseFrom = cam.CFrame
	Director.ReleaseTo = CFrame.lookAt(pos, lookAt)
	Director.ReleaseT = 0
	Director.Releasing = true
end

function Director.finish()
	if not Director.Active then
		return
	end
	local cam = Workspace.CurrentCamera
	Director.Active = false
	Director.Releasing = false
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = Director.StartFov
	end
end

RunService:BindToRenderStep("RickPrimeCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not Director.Active then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end

	if Director.Releasing then
		Director.ReleaseT += dt
		local k = easeInOut(clamp01(Director.ReleaseT / Config.Camera.BlendOut))
		cam.CFrame = Director.ReleaseFrom:Lerp(Director.ReleaseTo, k)
		local cur = cam.FieldOfView
		cam.FieldOfView = cur + (Director.StartFov - cur) * clamp01(dt * 6)
		if k >= 1 then
			Director.finish()
		end
		return
	end

	Director.Elapsed += dt
	local desired, fov = desiredCF()
	local blend = easeOut(clamp01(Director.Elapsed / Config.Camera.BlendIn))
	cam.CFrame = Director.StartCF:Lerp(desired, blend)
	cam.FieldOfView = Director.StartFov + (fov - Director.StartFov) * blend

	-- por seguridad: si el servidor no manda liberar, se libera solo
	if Director.Elapsed > Director.Duration + 3 then
		Director.release({ Target = Director.Target })
	end
end)

--// ENTRADA ---------------------------------------------------------------------
local function requestRegen()
	Event:FireServer("Request")
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Config.TriggerKey then
		requestRegen()
	end
end)

if Config.ShowTouchButton and UserInputService.TouchEnabled then
	local buttonGui = make("ScreenGui", {
		Name = "RickPrimeRegenButton",
		ResetOnSpawn = false,
		DisplayOrder = 50,
	}, playerGui)
	local btn = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -120),
		Size = UDim2.fromOffset(86, 86),
		BackgroundColor3 = Color3.fromRGB(30, 190, 180),
		Text = "REGEN",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		AutoButtonColor = true,
	}, buttonGui)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
	make("UIStroke", { Color = Color3.fromRGB(255, 120, 60), Thickness = 3 }, btn)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 28),
		PaddingBottom = UDim.new(0, 28),
	}, btn)
	btn.Activated:Connect(requestRegen)
end

--// EVENTOS DEL SERVIDOR --------------------------------------------------------
Event.OnClientEvent:Connect(function(phase, data)
	data = data or {}
	if phase == "Begin" then
		Director.prepare(data)
	elseif phase == "Portal" then
		Screen.portalFlash(data.Duration or 0.26)
	elseif phase == "Ink" then
		Screen.inkBurst(data.Duration or 0.3)
	elseif phase == "Blast" then
		Screen.blast()
	elseif phase == "Shake" then
		Shake.add(data.Intensity or 1, data.Duration or 1.2, data.Origin)
	elseif phase == "Camera" then
		Director.start(data)
	elseif phase == "Reform" then
		Shake.add(0.35, 0.5)
	elseif phase == "Rise" then
		Shake.add(0.5, 0.6)
	elseif phase == "CameraRelease" then
		Director.release(data)
	elseif phase == "Finish" then
		if Director.Active and not Director.Releasing then
			Director.release({ Target = Director.RootPos })
		end
	end
end)

	return
end

----------------------------------------------------------------------------
-- PARTE SERVIDOR
----------------------------------------------------------------------------

--// SERVICIOS ------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")

local EVENT_NAME = "RickPrimeRegenEvent"
local TRIGGER_NAME = "RickPrimeRegenTrigger"
local FX_FOLDER_NAME = "RickPrimeFX"
local COLLISION_GROUP = "RickPrimeDebris"

--// CONFIGURACION --------------------------------------------------------------
local Config = {}

Config.Debug = false

-- Variante activa: "v3" o "v4"
Config.Variant = "v4"

Config.Trigger = {
	OnLethalDamage = true,       -- regenera en vez de morir
	ManualEnabled = true,        -- permite la tecla del cliente
	Cooldown = 5,                -- segundos entre regeneraciones por jugador
	RescueFromVoid = true,       -- si cae al vacio, vuelve al ultimo suelo seguro y regenera
	VoidMargin = 80,
	Invulnerable = true,         -- ForceField invisible mientras dura
	RestoreHealthTo = 1,         -- fraccion de MaxHealth al terminar (1 = completa)
}

Config.Colors = {
	GlowCore = Color3.fromRGB(255, 244, 190),
	GlowHot = Color3.fromRGB(255, 214, 96),
	GlowWhite = Color3.fromRGB(255, 255, 240),
	FireA = Color3.fromRGB(255, 220, 90),
	FireB = Color3.fromRGB(255, 130, 20),
	FireC = Color3.fromRGB(190, 40, 10),
	FireD = Color3.fromRGB(40, 20, 15),
	SmokeDark = Color3.fromRGB(25, 22, 22),
	SmokeMid = Color3.fromRGB(90, 85, 85),
	SmokeLight = Color3.fromRGB(190, 190, 195),
	Blood = Color3.fromRGB(208, 8, 18),
	BloodDark = Color3.fromRGB(150, 0, 12),
	BloodLight = Color3.fromRGB(230, 25, 30),
	RayRed = Color3.fromRGB(255, 70, 60),
	RayYellow = Color3.fromRGB(255, 232, 70),
	RayBlue = Color3.fromRGB(70, 150, 255),
	Bulb = Color3.fromRGB(255, 236, 90),
	Shard = Color3.fromRGB(20, 16, 16),
	Shockwave = Color3.fromRGB(255, 170, 70),
}

Config.Textures = {
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	Soft = "rbxasset://textures/particles/sparkles_main.dds",
}

-- Sonidos: deja "" para silencio. Puedes poner tus propios ids "rbxassetid://..."
Config.Sounds = {
	Explosion = "rbxasset://sounds/impact_explosion_03.mp3",
	Portal = "",
	Reform = "",
	Rise = "",
	Fire = "",
	Volume = 1.2,
}

Config.Blood = {
	Enabled = true,
	MaxParts = 260,
	Lifetime = 28,           -- segundos antes de desvanecerse
	FadeTime = 4,
	Thickness = 0.05,
	MainPuddleRadius = { 5.5, 9 },
	LobeCount = { 4, 7 },
	DropCount = { 12, 20 },
	DropRadius = { 0.5, 2.2 },
	DropSpread = 20,
	ImpactChance = 0.55,
}

Config.Debris = {
	SpeedMin = 34,
	SpeedMax = 72,
	SpinMax = 26,
	Density = 0.7,
	Friction = 0.4,
	Elasticity = 0.25,
	TrailLifetime = 0.45,
	FirePerPart = true,
	PulseSpeed = 14,
	RainbowTrailParts = 4,    -- cuantas partes dejan estela de colores
}

Config.Explosion = {
	Radius = 26,
	ShockwaveTime = 0.4,
	FlashBrightness = 14,
	FlashRange = 64,
	FireburstCount = 70,
	SmokeCount = 46,
	SparkCount = 90,
	ShardCount = 28,
	ShardLifetime = 1.3,
	BlastSoundDistance = 160,
}

Config.Rays = {
	Count = 3,
	Width = 0.45,
	LateralSpacing = 0.55,
	FlickerRate = 22,
	BulbSize = 1.7,
	BulbLightRange = 26,
	BulbLightBrightness = 6,
	FadeTime = 0.6,
}

Config.Tail = {
	FireRate = 38,
	SmokeRate = 14,
	FireSideOffset = Vector3.new(-1.6, 0.6, 0.4),
	DecayStart = 0.55,
}

Config.Clothes = {
	-- Etapas de regeneracion: se quitan Shirt/Pants/ShirtGraphic y vuelven despues
	StripOnRegen = true,
	PulseOnReturn = true,
}

-- Variantes de tiempos (segundos). Todo se mide desde el disparo.
Config.Variants = {
	v4 = {
		Label = "Rick Prime Regeneration v4 (combined v2 and v3)",
		PortalFlash = 0.26,
		InkBurst = 0.30,
		ExplosionDelay = 0.46,
		FlightTime = 1.15,
		SmolderTime = 0.12,
		ReassembleTime = 0.75,
		LieTime = 0.22,
		RiseTime = 0.55,
		SkinSettle = 0.35,
		PantsDelay = 0.18,
		ShirtDelay = 0.38,
		TailTime = 1.6,
		CameraMode = "push",
		CameraShake = 1.0,
		CameraTime = 1.9,
		RayDuration = 1.9,
		RayLength = 64,
		BloodBlast = 24,
		BleedRate = 6,
		FireScale = 1.0,
		DebrisSpeedScale = 1.0,
		GlowBlast = 1.0,
	},
	v3 = {
		Label = "Rick Prime Regeneration v3",
		PortalFlash = 0.30,
		InkBurst = 0.34,
		ExplosionDelay = 0.52,
		FlightTime = 0.95,
		SmolderTime = 3.4,
		ReassembleTime = 1.0,
		LieTime = 0.55,
		RiseTime = 0.9,
		SkinSettle = 0.7,
		PantsDelay = 0.4,
		ShirtDelay = 0.85,
		TailTime = 1.2,
		CameraMode = "low",
		CameraShake = 0.7,
		CameraTime = 5.3,
		RayDuration = 5.0,
		RayLength = 90,
		BloodBlast = 30,
		BleedRate = 10,
		FireScale = 1.2,
		DebrisSpeedScale = 0.75,
		GlowBlast = 0.9,
	},
}

local function activeVariant()
	return Config.Variants[Config.Variant] or Config.Variants.v4
end

--// UTILIDADES -----------------------------------------------------------------
local Utils = {}
Utils.rng = Random.new()

function Utils.rand(a, b)
	return Utils.rng:NextNumber(a, b)
end

function Utils.randInt(a, b)
	return Utils.rng:NextInteger(a, b)
end

function Utils.chance(p)
	return Utils.rng:NextNumber() < p
end

function Utils.randomUnit()
	return Utils.rng:NextUnitVector()
end

function Utils.pick(list)
	return list[Utils.rng:NextInteger(1, #list)]
end

function Utils.lerp(a, b, t)
	return a + (b - a) * t
end

function Utils.clamp01(x)
	return math.max(0, math.min(1, x))
end

function Utils.remap(x, a, b, c, d)
	if b == a then
		return c
	end
	return c + (d - c) * Utils.clamp01((x - a) / (b - a))
end

function Utils.lerpColor(a, b, t)
	return a:Lerp(b, Utils.clamp01(t))
end

-- Easings
Utils.Ease = {}
function Utils.Ease.linear(t) return t end
function Utils.Ease.inQuad(t) return t * t end
function Utils.Ease.outQuad(t) return 1 - (1 - t) * (1 - t) end
function Utils.Ease.inOutQuad(t)
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end
function Utils.Ease.inCubic(t) return t * t * t end
function Utils.Ease.outCubic(t) return 1 - (1 - t) ^ 3 end
function Utils.Ease.inOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - ((-2 * t + 2) ^ 3) / 2
end
function Utils.Ease.outQuart(t) return 1 - (1 - t) ^ 4 end
function Utils.Ease.outExpo(t)
	if t >= 1 then
		return 1
	end
	return 1 - 2 ^ (-10 * t)
end
function Utils.Ease.outBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * ((t - 1) ^ 3) + c1 * ((t - 1) ^ 2)
end
function Utils.Ease.inBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return c3 * t * t * t - c1 * t * t
end
function Utils.Ease.outElastic(t)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	local c4 = (2 * math.pi) / 3
	return (2 ^ (-10 * t)) * math.sin((t * 10 - 0.75) * c4) + 1
end

-- Crea una instancia con propiedades en una sola llamada
function Utils.make(className, props, parent)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Utils.tween(inst, seconds, goal, style, direction)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end

-- Ejecuta callback(alpha, dt, elapsed) cada Heartbeat durante "duration".
-- Si el callback devuelve false se aborta y step devuelve false.
function Utils.step(duration, callback)
	local elapsed = 0
	if duration <= 0 then
		callback(1, 0, 0)
		return true
	end
	while elapsed < duration do
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		local alpha = math.clamp(elapsed / duration, 0, 1)
		if callback(alpha, dt, elapsed) == false then
			return false
		end
	end
	return true
end

function Utils.safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and Config.Debug then
		warn("[RickPrimeRegen] " .. tostring(err))
	end
	return ok
end

function Utils.log(...)
	if Config.Debug then
		print("[RickPrimeRegen]", ...)
	end
end

-- CFrame con el eje X apuntando a "normal" (para cilindros planos sobre el suelo)
function Utils.cframeFromNormalX(position, normal, spin)
	local tangent = normal:Cross(Vector3.xAxis)
	if tangent.Magnitude < 0.01 then
		tangent = normal:Cross(Vector3.zAxis)
	end
	tangent = tangent.Unit
	local base = CFrame.fromMatrix(position, normal, tangent)
	return base * CFrame.Angles(spin or 0, 0, 0)
end

function Utils.numberSeq(points)
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
end

function Utils.colorSeq(points)
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(keys)
end

--// MAID -----------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {}, _clean = false }, Maid)
end

function Maid:Give(item)
	if self._clean then
		Maid._dispose(item)
		return item
	end
	table.insert(self._tasks, item)
	return item
end

function Maid._dispose(item)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "function" then
		pcall(item)
	elseif t == "table" and item.Destroy then
		pcall(function() item:Destroy() end)
	end
end

function Maid:Clean()
	if self._clean then
		return
	end
	self._clean = true
	for i = #self._tasks, 1, -1 do
		Maid._dispose(self._tasks[i])
	end
	self._tasks = {}
end

Maid.Destroy = Maid.Clean

--// MUNDO / RED ----------------------------------------------------------------
local World = {}

World.Folder = Workspace:FindFirstChild(FX_FOLDER_NAME)
if not World.Folder then
	World.Folder = Utils.make("Folder", { Name = FX_FOLDER_NAME }, Workspace)
end

World.GroupOk = pcall(function()
	PhysicsService:RegisterCollisionGroup(COLLISION_GROUP)
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(COLLISION_GROUP, COLLISION_GROUP, false)
end)

function World.ignoreList(character)
	local list = { World.Folder }
	if character then
		table.insert(list, character)
	end
	return list
end

function World.findGround(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = World.ignoreList(character)
	params.IgnoreWater = true
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -500, 0), params)
	if result then
		return result.Position, result.Normal, result.Instance
	end
	return Vector3.new(position.X, position.Y - 3, position.Z), Vector3.yAxis, nil
end

function World.subfolder(name, maid)
	local f = Utils.make("Folder", { Name = name }, World.Folder)
	if maid then
		maid:Give(f)
	end
	return f
end

local Network = {}
Network.Event = ReplicatedStorage:FindFirstChild(EVENT_NAME)
if not Network.Event then
	Network.Event = Utils.make("RemoteEvent", { Name = EVENT_NAME }, ReplicatedStorage)
end

function Network.fire(player, phase, data)
	if player and player.Parent then
		Network.Event:FireClient(player, phase, data)
	end
end

function Network.fireNearby(position, radius, phase, data)
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude <= radius then
			Network.fire(plr, phase, data)
		end
	end
end

--// SONIDO ---------------------------------------------------------------------
local Sfx = {}

function Sfx.play(parent, soundId, volume, speed, maxDistance)
	if not soundId or soundId == "" or not parent then
		return nil
	end
	local s = Utils.make("Sound", {
		SoundId = soundId,
		Volume = (volume or 1) * Config.Sounds.Volume,
		PlaybackSpeed = speed or 1,
		RollOffMode = Enum.RollOffMode.Linear,
		RollOffMaxDistance = maxDistance or 120,
		RollOffMinDistance = 10,
	}, parent)
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

--// SANGRE ---------------------------------------------------------------------
-- Charcos y gotas rojas planas sobre el suelo. Quedan un buen rato como en los
-- videos y luego se desvanecen. Hay un tope de partes para no saturar el mapa.
local Blood = {}
Blood.Folder = World.subfolder("Blood", nil)
Blood.Parts = {}
Blood.Layer = 0

local function pickBloodColor()
	local r = Utils.rng:NextNumber()
	if r < 0.58 then
		return Config.Colors.Blood
	elseif r < 0.82 then
		return Config.Colors.BloodDark
	end
	return Config.Colors.BloodLight
end

function Blood.register(part)
	table.insert(Blood.Parts, part)
	while #Blood.Parts > Config.Blood.MaxParts do
		local old = table.remove(Blood.Parts, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(Config.Blood.Lifetime + Utils.rand(0, 6), function()
		if part.Parent then
			Utils.tween(part, Config.Blood.FadeTime, { Transparency = 1 })
			task.delay(Config.Blood.FadeTime + 0.2, function()
				if part.Parent then
					part:Destroy()
				end
			end)
		end
	end)
end

-- Una mancha circular. position = punto sobre el suelo, normal = normal del suelo
function Blood.splat(position, normal, radius, delay, growTime)
	if not Config.Blood.Enabled then
		return nil
	end
	Blood.Layer = (Blood.Layer + 1) % 48
	local lift = 0.03 + Blood.Layer * 0.004
	local diameter = radius * 2
	local part = Utils.make("Part", {
		Name = "BloodSplat",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.04,
		Color = pickBloodColor(),
		Size = Vector3.new(Config.Blood.Thickness, 0.1, 0.1),
		CFrame = Utils.cframeFromNormalX(position + normal * lift, normal, Utils.rand(0, math.pi * 2)),
		Transparency = 1,
	}, Blood.Folder)
	Blood.register(part)

	task.delay(delay or 0, function()
		if not part.Parent then
			return
		end
		part.Transparency = 0
		local t = growTime or Utils.rand(0.25, 0.7)
		Utils.tween(part, t, { Size = Vector3.new(Config.Blood.Thickness, diameter, diameter) },
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end)
	return part
end

-- Charco grande con lobulos (forma organica) + gotas alrededor
function Blood.puddle(center, character, scale, delay)
	if not Config.Blood.Enabled then
		return
	end
	scale = scale or 1
	local ground, normal = World.findGround(center, character)
	local mainR = Utils.rand(Config.Blood.MainPuddleRadius[1], Config.Blood.MainPuddleRadius[2]) * scale
	Blood.splat(ground, normal, mainR, delay, 0.55)

	local lobes = Utils.randInt(Config.Blood.LobeCount[1], Config.Blood.LobeCount[2])
	for i = 1, lobes do
		local ang = (i / lobes) * math.pi * 2 + Utils.rand(-0.4, 0.4)
		local dist = mainR * Utils.rand(0.45, 0.85)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = World.findGround(ground + off, character)
		Blood.splat(g, n, mainR * Utils.rand(0.3, 0.62), (delay or 0) + Utils.rand(0, 0.12), 0.5)
	end

	local drops = Utils.randInt(Config.Blood.DropCount[1], Config.Blood.DropCount[2])
	for _ = 1, drops do
		local ang = Utils.rand(0, math.pi * 2)
		local dist = Utils.rand(mainR * 0.9, Config.Blood.DropSpread * scale)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = World.findGround(ground + off, character)
		local r = Utils.rand(Config.Blood.DropRadius[1], Config.Blood.DropRadius[2]) * scale
		Blood.splat(g, n, r, (delay or 0) + Utils.rand(0.02, 0.35), Utils.rand(0.15, 0.4))
	end
end

-- Lluvia de gotas alrededor del punto (explosion)
function Blood.burst(center, character, count, spread, delay)
	for _ = 1, count do
		local ang = Utils.rand(0, math.pi * 2)
		local dist = Utils.rand(2, spread)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = World.findGround(center + off, character)
		local r = Utils.rand(0.45, 2.1)
		Blood.splat(g, n, r, (delay or 0) + dist / spread * 0.3 + Utils.rand(0, 0.1), Utils.rand(0.12, 0.35))
	end
end

-- Gota individual cuando una parte golpea el suelo
function Blood.impact(position, character)
	local g, n = World.findGround(position, character)
	Blood.splat(g, n, Utils.rand(0.5, 1.7), 0, Utils.rand(0.1, 0.25))
end

-- Sangrado continuo de la pila de restos
function Blood.bleed(center, character, duration, ratePerSecond, maid)
	task.spawn(function()
		local acc = 0
		Utils.step(duration, function(_, dt)
			if maid and maid._clean then
				return false
			end
			acc += dt * ratePerSecond
			while acc >= 1 do
				acc -= 1
				local ang = Utils.rand(0, math.pi * 2)
				local dist = Utils.rand(0.5, 6)
				local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
				local g, n = World.findGround(center + off, character)
				Blood.splat(g, n, Utils.rand(0.4, 1.4), 0, Utils.rand(0.2, 0.5))
			end
		end)
	end)
end

--// EFECTOS --------------------------------------------------------------------
local FX = {}
FX.Presets = {}

function FX.anchorPart(position, name, parent)
	return Utils.make("Part", {
		Name = name or "FXAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position),
	}, parent)
end

function FX.emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Config.Textures.Soft
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local C = Config.Colors
local T = Config.Textures

function FX.Presets.Fireball(scale)
	scale = scale or 1
	return {
		Texture = T.Fire,
		Color = Utils.colorSeq({ { 0, C.FireA }, { 0.35, C.FireB }, { 0.75, C.FireC }, { 1, C.FireD } }),
		Size = Utils.numberSeq({ { 0, 4 * scale }, { 0.4, 11 * scale }, { 1, 3 * scale } }),
		Transparency = Utils.numberSeq({ { 0, 0.05 }, { 0.6, 0.3 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.45, 1.05),
		Speed = NumberRange.new(24, 54),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-140, 140),
		LightEmission = 0.9,
		Drag = 2.2,
	}
end

function FX.Presets.BlackSmoke(scale)
	scale = scale or 1
	return {
		Texture = T.Smoke,
		Color = Utils.colorSeq({ { 0, C.SmokeDark }, { 0.5, C.SmokeMid }, { 1, C.SmokeLight } }),
		Size = Utils.numberSeq({ { 0, 5 * scale }, { 0.5, 12 * scale }, { 1, 18 * scale } }),
		Transparency = Utils.numberSeq({ { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.2, 2.6),
		Speed = NumberRange.new(8, 24),
		SpreadAngle = Vector2.new(180, 180),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-50, 50),
		LightEmission = 0,
		Drag = 1.6,
		Acceleration = Vector3.new(0, 5, 0),
	}
end

function FX.Presets.WhiteHaze(scale)
	scale = scale or 1
	return {
		Texture = T.Smoke,
		Color = ColorSequence.new(C.SmokeLight),
		Size = Utils.numberSeq({ { 0, 8 * scale }, { 1, 26 * scale } }),
		Transparency = Utils.numberSeq({ { 0, 0.55 }, { 0.4, 0.7 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.5, 3.2),
		Speed = NumberRange.new(4, 14),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 0.4,
		Drag = 1,
		Acceleration = Vector3.new(0, 3, 0),
	}
end

function FX.Presets.Sparks()
	return {
		Texture = T.Sparkle,
		Color = Utils.colorSeq({ { 0, C.GlowWhite }, { 0.4, C.FireA }, { 1, C.FireB } }),
		Size = Utils.numberSeq({ { 0, 1.4 }, { 1, 0 } }),
		Transparency = Utils.numberSeq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.95),
		Speed = NumberRange.new(40, 95),
		SpreadAngle = Vector2.new(180, 180),
		LightEmission = 1,
		Acceleration = Vector3.new(0, -70, 0),
		Drag = 0.6,
	}
end

function FX.Presets.Embers()
	return {
		Texture = T.Sparkle,
		Color = Utils.colorSeq({ { 0, C.FireA }, { 1, C.FireC } }),
		Size = Utils.numberSeq({ { 0, 0.7 }, { 1, 0 } }),
		Transparency = Utils.numberSeq({ { 0, 0 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.8),
		Speed = NumberRange.new(3, 12),
		SpreadAngle = Vector2.new(60, 60),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 9, 0),
	}
end

function FX.Presets.DebrisFire(scale)
	scale = scale or 1
	return {
		Texture = T.Fire,
		Color = Utils.colorSeq({ { 0, C.FireA }, { 0.5, C.FireB }, { 1, C.FireC } }),
		Size = Utils.numberSeq({ { 0, 2.2 * scale }, { 1, 0.3 } }),
		Transparency = Utils.numberSeq({ { 0, 0.15 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.3, 0.75),
		Speed = NumberRange.new(2, 7),
		SpreadAngle = Vector2.new(25, 25),
		LightEmission = 1,
		Acceleration = Vector3.new(0, 12, 0),
		Rotation = NumberRange.new(0, 360),
		Rate = 24,
	}
end

function FX.Presets.DebrisSmoke()
	return {
		Texture = T.Smoke,
		Color = Utils.colorSeq({ { 0, C.SmokeMid }, { 1, C.SmokeDark } }),
		Size = Utils.numberSeq({ { 0, 1.2 }, { 1, 3.6 } }),
		Transparency = Utils.numberSeq({ { 0, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 7, 0),
		Rate = 8,
	}
end

function FX.Presets.TailFire()
	return {
		Texture = T.Fire,
		Color = Utils.colorSeq({ { 0, C.FireA }, { 0.45, C.FireB }, { 1, C.FireC } }),
		Size = Utils.numberSeq({ { 0, 2.6 }, { 0.5, 3.4 }, { 1, 0.6 } }),
		Transparency = Utils.numberSeq({ { 0, 0.1 }, { 1, 1 } }),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(5, 12),
		SpreadAngle = Vector2.new(35, 35),
		LightEmission = 0.95,
		Acceleration = Vector3.new(-5, 14, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-80, 80),
	}
end

function FX.Presets.TailSmoke()
	return {
		Texture = T.Smoke,
		Color = Utils.colorSeq({ { 0, C.SmokeLight }, { 1, C.SmokeMid } }),
		Size = Utils.numberSeq({ { 0, 1.4 }, { 1, 5 } }),
		Transparency = Utils.numberSeq({ { 0, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.0, 2.2),
		Speed = NumberRange.new(1, 5),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 6, 0),
		RotSpeed = NumberRange.new(-30, 30),
	}
end

-- Estela simple en una parte
function FX.trail(part, colorA, colorB, lifetime, width, offsetX)
	local a0 = Utils.make("Attachment", { Name = "RPTrail0", Position = Vector3.new(offsetX or 0, width * 0.5, 0) }, part)
	local a1 = Utils.make("Attachment", { Name = "RPTrail1", Position = Vector3.new(offsetX or 0, -width * 0.5, 0) }, part)
	local tr = Utils.make("Trail", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(colorA, colorB or colorA),
		Transparency = Utils.numberSeq({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = lifetime or 0.4,
		LightEmission = 1,
		LightInfluence = 0,
		MinLength = 0.05,
		FaceCamera = true,
	}, part)
	return tr
end

-- Tres estelas rojo / amarillo / azul paralelas (como las lineas de los videos)
function FX.rainbowTrail(part)
	local cols = { C.RayRed, C.RayYellow, C.RayBlue }
	local list = {}
	for i, c in ipairs(cols) do
		table.insert(list, FX.trail(part, c, c, 0.55, 0.55, (i - 2) * 0.55))
	end
	return list
end

-- Explosion principal: bola de fuego, humo negro, destello, onda, esquirlas
function FX.explosion(position, character, variant)
	local folder = World.subfolder("Explosion", nil)
	local core = FX.anchorPart(position, "BlastCore", folder)
	local att = Utils.make("Attachment", nil, core)

	local light = Utils.make("PointLight", {
		Color = C.GlowWhite,
		Brightness = Config.Explosion.FlashBrightness * variant.GlowBlast,
		Range = Config.Explosion.FlashRange,
		Shadows = false,
	}, core)
	Utils.tween(light, 0.55, { Brightness = 0, Range = 8 })

	local fire = FX.emitter(att, FX.Presets.Fireball(variant.FireScale))
	local smoke = FX.emitter(att, FX.Presets.BlackSmoke(1))
	local haze = FX.emitter(att, FX.Presets.WhiteHaze(1))
	local sparks = FX.emitter(att, FX.Presets.Sparks())
	local embers = FX.emitter(att, FX.Presets.Embers())
	fire:Emit(Config.Explosion.FireburstCount)
	smoke:Emit(Config.Explosion.SmokeCount)
	haze:Emit(18)
	sparks:Emit(Config.Explosion.SparkCount)
	embers:Emit(40)

	-- Destello esferico
	local flash = Utils.make("Part", {
		Name = "BlastFlash",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = C.GlowWhite,
		Transparency = 0.1,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position),
	}, folder)
	Utils.tween(flash, 0.3, { Size = Vector3.new(22, 22, 22), Transparency = 1 }, Enum.EasingStyle.Quart)

	-- Onda de choque naranja
	local radius = Config.Explosion.Radius
	local wave = Utils.make("Part", {
		Name = "Shockwave",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = C.Shockwave,
		Transparency = 0.45,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(position),
	}, folder)
	Utils.tween(wave, Config.Explosion.ShockwaveTime, {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	}, Enum.EasingStyle.Quad)

	-- Bola de humo oscuro
	local smokeBall = Utils.make("Part", {
		Name = "SmokeBall",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.SmoothPlastic,
		Color = C.SmokeDark,
		Transparency = 0.3,
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(position),
	}, folder)
	Utils.tween(smokeBall, 0.55, { Size = Vector3.new(19, 15, 19), Transparency = 1 }, Enum.EasingStyle.Quad)

	-- Anillo en el suelo
	local ground, normal = World.findGround(position, character)
	local ring = Utils.make("Part", {
		Name = "GroundRing",
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = C.FireB,
		Transparency = 0.35,
		Size = Vector3.new(0.25, 3, 3),
		CFrame = Utils.cframeFromNormalX(ground + normal * 0.12, normal, 0),
	}, folder)
	Utils.tween(ring, 0.5, { Size = Vector3.new(0.25, radius * 2.2, radius * 2.2), Transparency = 1 }, Enum.EasingStyle.Quart)

	-- Esquirlas oscuras (salpicadura negra de los videos)
	for _ = 1, Config.Explosion.ShardCount do
		local s = Utils.rand(0.3, 1.2)
		local shard = Utils.make("Part", {
			Name = "Shard",
			Size = Vector3.new(s, s * Utils.rand(0.4, 1.6), s * Utils.rand(0.4, 1.4)),
			Color = C.Shard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(position + Utils.randomUnit() * 1.2) * CFrame.Angles(Utils.rand(0, 6), Utils.rand(0, 6), Utils.rand(0, 6)),
			CollisionGroup = World.GroupOk and COLLISION_GROUP or "Default",
		}, folder)
		local dir = (Utils.randomUnit() + Vector3.new(0, 0.7, 0)).Unit
		shard.AssemblyLinearVelocity = dir * Utils.rand(30, 80)
		shard.AssemblyAngularVelocity = Utils.randomUnit() * Utils.rand(6, 24)
		task.delay(Config.Explosion.ShardLifetime, function()
			if shard.Parent then
				Utils.tween(shard, 0.35, { Transparency = 1 })
			end
		end)
	end

	Sfx.play(core, Config.Sounds.Explosion, 1.3, Utils.rand(0.92, 1.05), Config.Explosion.BlastSoundDistance)

	task.delay(6, function()
		if folder.Parent then
			folder:Destroy()
		end
	end)
	return folder
end

-- Rayos de colores atravesando la pila + foco amarillo en un extremo
function FX.rays(center, direction, duration, length, maid)
	local folder = World.subfolder("Rays", nil)
	if maid then
		maid:Give(folder)
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.zAxis
	end
	local baseDir = flat.Unit
	local cols = { C.RayRed, C.RayYellow, C.RayBlue }
	local count = Config.Rays.Count
	local entries = {}

	for i = 1, count do
		local lat = (i - (count + 1) / 2) * Config.Rays.LateralSpacing
		local lift = Utils.rand(0.15, 0.7)
		local pa = FX.anchorPart(center, "RayA", folder)
		local pb = FX.anchorPart(center, "RayB", folder)
		local a0 = Utils.make("Attachment", nil, pa)
		local a1 = Utils.make("Attachment", nil, pb)
		local beam = Utils.make("Beam", {
			Attachment0 = a0,
			Attachment1 = a1,
			Color = ColorSequence.new(cols[((i - 1) % #cols) + 1]),
			Width0 = 0,
			Width1 = 0,
			LightEmission = 1,
			LightInfluence = 0,
			FaceCamera = true,
			Segments = 1,
			Transparency = NumberSequence.new(0.08),
		}, pa)
		table.insert(entries, { Beam = beam, PA = pa, PB = pb, Lat = lat, Lift = lift, Phase = Utils.rand(0, 6.28) })
	end

	local bulb = Utils.make("Part", {
		Name = "RayBulb",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = C.Bulb,
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = CFrame.new(center),
	}, folder)
	local bulbLight = Utils.make("PointLight", {
		Color = C.Bulb,
		Brightness = 0,
		Range = Config.Rays.BulbLightRange,
		Shadows = false,
	}, bulb)

	local running = true
	local api = {}
	function api.Destroy()
		running = false
	end

	task.spawn(function()
		local fadeTime = Config.Rays.FadeTime
		Utils.step(duration, function(_, _, elapsed)
			if not running or (maid and maid._clean) then
				return false
			end
			local fadeIn = math.min(1, elapsed / 0.14)
			local fadeOut = 1 - Utils.remap(elapsed, duration - fadeTime, duration, 0, 1)
			local env = fadeIn * fadeOut
			local angle = elapsed * 0.07
			local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(baseDir)
			local lateralDir = dir:Cross(Vector3.yAxis)
			if lateralDir.Magnitude < 0.01 then
				lateralDir = Vector3.xAxis
			end
			lateralDir = lateralDir.Unit
			for _, e in ipairs(entries) do
				local flicker = 0.72 + 0.28 * math.sin(elapsed * Config.Rays.FlickerRate + e.Phase)
				local w = Config.Rays.Width * flicker * env
				e.Beam.Width0 = w
				e.Beam.Width1 = w
				local off = lateralDir * e.Lat + Vector3.new(0, e.Lift, 0)
				e.PA.CFrame = CFrame.new(center - dir * (length * 0.28) + off)
				e.PB.CFrame = CFrame.new(center + dir * (length * 0.72) + off)
			end
			local s = Config.Rays.BulbSize * env * (0.9 + 0.1 * math.sin(elapsed * 31))
			bulb.Size = Vector3.new(s, s, s)
			bulb.CFrame = CFrame.new(center - dir * (length * 0.28) + Vector3.new(0, 0.6, 0))
			bulbLight.Brightness = Config.Rays.BulbLightBrightness * env
		end)
		if folder.Parent then
			folder:Destroy()
		end
	end)
	return api
end

-- Fuego lateral + humo sobre el personaje ya regenerado
function FX.tail(character, duration)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = Utils.make("Attachment", { Name = "RPTailFire", Position = Config.Tail.FireSideOffset }, root)
	local att2 = Utils.make("Attachment", { Name = "RPTailSmoke", Position = Vector3.new(0.4, 1.8, 0.7) }, root)
	local fire = FX.emitter(att, FX.Presets.TailFire())
	fire.Rate = Config.Tail.FireRate
	local smoke = FX.emitter(att2, FX.Presets.TailSmoke())
	smoke.Rate = Config.Tail.SmokeRate
	local light = Utils.make("PointLight", { Name = "RPTailLight", Color = C.FireB, Brightness = 3, Range = 18, Shadows = false }, root)

	task.spawn(function()
		local decayFrom = duration * Config.Tail.DecayStart
		Utils.step(duration, function(_, _, elapsed)
			if not root.Parent then
				return false
			end
			local k = 1 - Utils.remap(elapsed, decayFrom, duration, 0, 1)
			fire.Rate = Config.Tail.FireRate * k
			smoke.Rate = Config.Tail.SmokeRate * (0.4 + 0.6 * k)
			light.Brightness = 3 * k
		end)
		fire.Enabled = false
		light:Destroy()
		task.wait(1)
		smoke.Enabled = false
		task.wait(2.5)
		att:Destroy()
		att2:Destroy()
	end)
end

--// RESTOS DEL CUERPO ------------------------------------------------------------
-- Cada parte del personaje se clona como "resto" fisico, brillante y en llamas.
-- El personaje real se oculta mientras tanto y reaparece al final.
local Remains = {}

function Remains.collect(character)
	local list = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.99 then
			table.insert(list, d)
		end
	end
	return list
end

function Remains.hideReal(character, store)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			store[d] = d.Transparency
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			store[d] = d.Transparency
			d.Transparency = 1
		end
	end
end

function Remains.showReal(store)
	for inst, t in pairs(store) do
		if inst.Parent then
			inst.Transparency = t
		end
	end
	table.clear(store)
end

local STRIP_CLASSES = {
	"JointInstance", "Constraint", "WeldConstraint", "Script", "LocalScript",
	"BodyMover", "ParticleEmitter", "Fire", "Smoke", "Sparkles", "Light",
	"Sound", "Beam", "Trail",
}

local function shouldStrip(inst)
	for _, cls in ipairs(STRIP_CLASSES) do
		if inst:IsA(cls) then
			return true
		end
	end
	return false
end

function Remains.build(character, rootCF, folder, variant)
	local entries = {}
	local rainbowLeft = Config.Debris.RainbowTrailParts
	local lightsLeft = 3

	for _, orig in ipairs(Remains.collect(character)) do
		local ok, clone = pcall(function()
			return orig:Clone()
		end)
		if ok and clone then
			for _, d in ipairs(clone:GetDescendants()) do
				if shouldStrip(d) then
					d:Destroy()
				end
			end
			clone.Name = "RPDebris_" .. orig.Name
			clone.Anchored = false
			clone.CanCollide = true
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Massless = false
			clone.CustomPhysicalProperties = PhysicalProperties.new(
				Config.Debris.Density, Config.Debris.Friction, Config.Debris.Elasticity, 1, 1)
			if World.GroupOk then
				clone.CollisionGroup = COLLISION_GROUP
			end
			clone.CFrame = orig.CFrame
			local entry = {
				Part = clone,
				Orig = orig,
				Offset = rootCF:ToObjectSpace(orig.CFrame),
				OrigColor = orig.Color,
				OrigMaterial = orig.Material,
				OrigTransparency = orig.Transparency,
				Phase = Utils.rand(0, math.pi * 2),
				BloodCD = Utils.rand(0, 0.2),
				FlashUntil = 0,
			}
			clone.Material = Enum.Material.Neon
			clone.Color = Config.Colors.GlowCore
			clone.Transparency = 0
			clone.Parent = folder

			-- Fuego y humo continuos
			if Config.Debris.FirePerPart then
				entry.FireEm = FX.emitter(clone, FX.Presets.DebrisFire(variant.FireScale))
				entry.SmokeEm = FX.emitter(clone, FX.Presets.DebrisSmoke())
			end
			entry.SparkEm = FX.emitter(clone, {
				Texture = Config.Textures.Sparkle,
				Color = Utils.colorSeq({ { 0, Config.Colors.GlowWhite }, { 1, Config.Colors.FireA } }),
				Size = Utils.numberSeq({ { 0, 1.2 }, { 1, 0 } }),
				Transparency = Utils.numberSeq({ { 0, 0 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.2, 0.45),
				Speed = NumberRange.new(8, 22),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = 1,
			})

			-- Estelas
			FX.trail(clone, Config.Colors.GlowCore, Config.Colors.FireB, Config.Debris.TrailLifetime, 1.1, 0)
			if rainbowLeft > 0 and Utils.chance(0.5) then
				rainbowLeft -= 1
				FX.rainbowTrail(clone)
			end
			if lightsLeft > 0 and Utils.chance(0.3) then
				lightsLeft -= 1
				Utils.make("PointLight", {
					Color = Config.Colors.FireA,
					Brightness = 2.5,
					Range = 14,
					Shadows = false,
				}, clone)
			end
			table.insert(entries, entry)
		end
	end
	return entries
end

function Remains.launch(entries, origin, variant)
	local lo = Config.Debris.SpeedMin * variant.DebrisSpeedScale
	local hi = Config.Debris.SpeedMax * variant.DebrisSpeedScale
	for _, e in ipairs(entries) do
		local p = e.Part
		local away = p.Position - origin
		local dir = away.Magnitude > 0.05 and away.Unit or Utils.randomUnit()
		dir = (dir + Vector3.new(Utils.rand(-0.35, 0.35), Utils.rand(0.5, 1.1), Utils.rand(-0.35, 0.35))).Unit
		p.AssemblyLinearVelocity = dir * Utils.rand(lo, hi)
		p.AssemblyAngularVelocity = Utils.randomUnit() * Utils.rand(8, Config.Debris.SpinMax)
		pcall(function()
			p:SetNetworkOwner(nil)
		end)
	end
end

-- Fase de vuelo / brasas: fisica real + pulso de brillo + sangre al golpear el suelo
function Remains.simulate(entries, duration, ctx)
	Utils.step(duration, function(_, dt, elapsed)
		if ctx.Maid._clean then
			return false
		end
		for _, e in ipairs(entries) do
			local p = e.Part
			if p.Parent then
				local pulse = 0.5 + 0.5 * math.sin(elapsed * Config.Debris.PulseSpeed + e.Phase)
				p.Color = Utils.lerpColor(Config.Colors.GlowHot, Config.Colors.GlowCore, pulse)
				e.BloodCD -= dt
				if e.BloodCD <= 0 and (p.Position.Y - ctx.GroundY) < 3.4 and p.AssemblyLinearVelocity.Magnitude > 4 then
					e.BloodCD = Utils.rand(0.14, 0.34)
					if Utils.chance(Config.Blood.ImpactChance) then
						Blood.impact(p.Position, ctx.Character)
					end
				end
				if p.Position.Y < ctx.GroundY - 60 then
					p.AssemblyLinearVelocity = Vector3.zero
					p.CFrame = CFrame.new(ctx.GroundPos + Vector3.new(Utils.rand(-3, 3), 3, Utils.rand(-3, 3)))
				end
			end
		end
	end)
end

function Remains.freeze(entries)
	for _, e in ipairs(entries) do
		local p = e.Part
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
		p.Anchored = true
		p.CanCollide = false
	end
end

local function snapSparks(e)
	e.FlashUntil = os.clock() + 0.14
	if e.SparkEm then
		e.SparkEm:Emit(10)
	end
end

-- Las partes vuelan desde donde cayeron hasta la pose tumbada
function Remains.reassemble(entries, duration, poseFn, ctx)
	local maxDelay = duration * 0.38
	for _, e in ipairs(entries) do
		e.Delay = Utils.rand(0, maxDelay)
		e.Travel = math.max(0.05, duration - maxDelay)
		e.StartCF = e.Part.CFrame
		e.Arrived = false
	end
	Utils.step(duration, function(_, _, elapsed)
		if ctx.Maid._clean then
			return false
		end
		local rootCF = poseFn(elapsed)
		local now = os.clock()
		for _, e in ipairs(entries) do
			local a = Utils.clamp01((elapsed - e.Delay) / e.Travel)
			local k = Utils.Ease.inOutCubic(a)
			e.Part.CFrame = e.StartCF:Lerp(rootCF * e.Offset, k)
			if a >= 1 and not e.Arrived then
				e.Arrived = true
				snapSparks(e)
			end
			e.Part.Color = (e.FlashUntil > now) and Config.Colors.GlowWhite or Config.Colors.GlowHot
		end
	end)
	-- los que no hayan llegado por redondeo
	for _, e in ipairs(entries) do
		if not e.Arrived then
			snapSparks(e)
		end
	end
end

-- Cuerpo tumbado convulsionando: temblor que va bajando
function Remains.holdLying(entries, duration, poseFn, ctx)
	Utils.step(duration, function(alpha, _, elapsed)
		if ctx.Maid._clean then
			return false
		end
		local amp = (1 - alpha) * 0.16
		local jitter = CFrame.new(Utils.rand(-amp, amp), Utils.rand(-amp, amp), Utils.rand(-amp, amp))
			* CFrame.Angles(Utils.rand(-amp, amp) * 0.3, Utils.rand(-amp, amp) * 0.3, Utils.rand(-amp, amp) * 0.3)
		local rootCF = poseFn(elapsed) * jitter
		local pulse = 0.5 + 0.5 * math.sin(elapsed * 30)
		for _, e in ipairs(entries) do
			e.Part.CFrame = rootCF * e.Offset
			e.Part.Color = Utils.lerpColor(Config.Colors.GlowHot, Config.Colors.GlowWhite, pulse)
		end
	end)
end

-- Se levanta pivotando en los pies (poseFn recibe alpha 0..1)
function Remains.rise(entries, duration, poseFn, ctx)
	Utils.step(duration, function(alpha)
		if ctx.Maid._clean then
			return false
		end
		local rootCF = poseFn(alpha)
		for _, e in ipairs(entries) do
			e.Part.CFrame = rootCF * e.Offset
		end
	end)
end

-- El brillo se apaga y el color pasa a ser piel
function Remains.settle(entries, duration, poseCF, ctx)
	for _, e in ipairs(entries) do
		if e.FireEm then
			e.FireEm.Enabled = false
		end
		if e.SmokeEm then
			e.SmokeEm.Rate = 3
		end
	end
	Utils.step(duration, function(alpha)
		if ctx.Maid._clean then
			return false
		end
		local k = Utils.Ease.inOutQuad(alpha)
		for _, e in ipairs(entries) do
			local p = e.Part
			p.CFrame = poseCF * e.Offset
			p.Color = Utils.lerpColor(Config.Colors.GlowCore, e.OrigColor, k)
			if alpha > 0.5 and p.Material ~= e.OrigMaterial then
				p.Material = e.OrigMaterial
			end
		end
	end)
end

function Remains.destroy(entries)
	for _, e in ipairs(entries) do
		if e.Part then
			e.Part:Destroy()
		end
	end
	table.clear(entries)
end

-- Destello corto al aparecer el personaje real o al volver una prenda
function Remains.flashPulse(position, scale, color)
	local folder = World.subfolder("Pulse", nil)
	local p = Utils.make("Part", {
		Name = "PulseFlash",
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color or Config.Colors.GlowWhite,
		Transparency = 0.25,
		Size = Vector3.new(1, 1, 1) * scale * 0.4,
		CFrame = CFrame.new(position),
	}, folder)
	Utils.tween(p, 0.28, { Size = Vector3.new(1, 1, 1) * scale * 2.2, Transparency = 1 }, Enum.EasingStyle.Quart)
	local att = Utils.make("Attachment", nil, p)
	local em = FX.emitter(att, FX.Presets.Sparks())
	em.Speed = NumberRange.new(10, 26)
	em:Emit(22)
	task.delay(1.2, function()
		folder:Destroy()
	end)
end

--// ROPA POR ETAPAS ---------------------------------------------------------------
-- Los videos muestran la regeneracion: primero piel, despues pantalones, al
-- final la camisa/chaleco. Quitamos las prendas y las devolvemos escalonadas.
local Clothing = {}

function Clothing.strip(character)
	local removed = {}
	if not Config.Clothes.StripOnRegen then
		return removed
	end
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			table.insert(removed, c)
			c.Parent = nil
		end
	end
	return removed
end

function Clothing.restoreKind(character, removed, classNames)
	for i = #removed, 1, -1 do
		local c = removed[i]
		for _, cls in ipairs(classNames) do
			if c:IsA(cls) then
				if character.Parent then
					c.Parent = character
				end
				table.remove(removed, i)
				break
			end
		end
	end
end

function Clothing.restoreAll(character, removed)
	for i = #removed, 1, -1 do
		local c = removed[i]
		if character and character.Parent then
			c.Parent = character
		end
		table.remove(removed, i)
	end
end

--// CONTROLADOR -----------------------------------------------------------------
local Controller = {}
Controller.Cooldowns = {}
Controller.Active = {}

local function currentVariant()
	local override = Workspace:GetAttribute("RickPrimeVariant")
	if typeof(override) == "string" and Config.Variants[override] then
		return Config.Variants[override], override
	end
	return activeVariant(), Config.Variant
end

local function alive(S)
	return (not S.Maid._clean) and S.Character.Parent ~= nil and S.Root.Parent ~= nil
end

local function pause(S, seconds)
	if seconds > 0 then
		task.wait(seconds)
	end
	return alive(S)
end

function Controller.freeze(S)
	local h = S.Humanoid
	S.Saved = {
		WalkSpeed = h.WalkSpeed,
		JumpPower = h.JumpPower,
		JumpHeight = h.JumpHeight,
		DisplayDistanceType = h.DisplayDistanceType,
		Anchored = S.Root.Anchored,
	}
	h.WalkSpeed = 0
	h.JumpPower = 0
	h.JumpHeight = 0
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	S.Root.AssemblyLinearVelocity = Vector3.zero
	S.Root.AssemblyAngularVelocity = Vector3.zero
	S.Root.Anchored = true
	if Config.Trigger.Invulnerable then
		S.ForceField = Utils.make("ForceField", { Name = "RPRegenShield", Visible = false }, S.Character)
	end
end

function Controller.release(S)
	if S.Released then
		return
	end
	S.Released = true
	local h = S.Humanoid
	local saved = S.Saved
	if h and h.Parent and saved then
		h.WalkSpeed = saved.WalkSpeed
		h.JumpPower = saved.JumpPower
		h.JumpHeight = saved.JumpHeight
		h.DisplayDistanceType = saved.DisplayDistanceType
		h.Health = h.MaxHealth * Config.Trigger.RestoreHealthTo
	end
	if S.Root and S.Root.Parent then
		S.Root.Anchored = saved and saved.Anchored or false
	end
	if S.ForceField then
		local ff = S.ForceField
		task.delay(0.6, function()
			if ff.Parent then
				ff:Destroy()
			end
		end)
	end
end

function Controller.cleanup(S)
	if S.Cleaned then
		return
	end
	S.Cleaned = true
	Remains.showReal(S.Hidden)
	Clothing.restoreAll(S.Character, S.Removed)
	Controller.release(S)
	S.Maid:Clean()
	if S.Character and S.Character.Parent then
		S.Character:SetAttribute("RickPrimeRegenerating", false)
	end
	Controller.Active[S.Character] = nil
	if S.Player then
		Controller.Cooldowns[S.Player] = os.clock() + Config.Trigger.Cooldown
		Network.fire(S.Player, "Finish", {})
	end
	Utils.log("regeneracion terminada")
end

-- Llamaradas en el suelo cuando el cuerpo empieza a levantarse
local function riseFlames(position)
	local folder = World.subfolder("RiseFlames", nil)
	local anchor = FX.anchorPart(position + Vector3.new(0, 0.6, 0), "RiseAnchor", folder)
	local att = Utils.make("Attachment", nil, anchor)
	local fire = FX.emitter(att, FX.Presets.Fireball(0.7))
	fire.Speed = NumberRange.new(8, 22)
	fire.SpreadAngle = Vector2.new(60, 60)
	fire.Acceleration = Vector3.new(0, 16, 0)
	fire:Emit(26)
	local embers = FX.emitter(att, FX.Presets.Embers())
	embers:Emit(24)
	local smoke = FX.emitter(att, FX.Presets.BlackSmoke(0.5))
	smoke:Emit(12)
	task.delay(3.5, function()
		folder:Destroy()
	end)
end

function Controller.run(S)
	local v = S.Variant
	local player = S.Player
	local character = S.Character
	local root = S.Root
	local humanoid = S.Humanoid

	local rootCF = root.CFrame
	local groundPos, groundNormal = World.findGround(rootCF.Position, character)
	local measured = rootCF.Position.Y - groundPos.Y
	local standH
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		standH = math.clamp(measured, 2, 6)
	elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
		standH = humanoid.HipHeight + root.Size.Y / 2
	else
		standH = 3
	end
	local flat = Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	local yawCF = CFrame.lookAt(Vector3.zero, flat.Unit)
	local faceUp = Utils.chance(0.4)
	local lieTheta = faceUp and (math.pi / 2) or (-math.pi / 2)

	-- Pose del cuerpo: theta = inclinacion sobre los pies (0 = de pie, +-90 = tumbado)
	local function poseAt(theta)
		local lift = 0.65 * math.abs(math.sin(theta))
		return CFrame.new(groundPos + Vector3.new(0, lift, 0)) * yawCF * CFrame.Angles(theta, 0, 0) * CFrame.new(0, standH, 0)
	end

	--------------------------------------------------------------------------
	-- FASE 0: flash psicodelico + tinta
	--------------------------------------------------------------------------
	Controller.freeze(S)
	Network.fire(player, "Begin", { Variant = S.VariantName, Label = v.Label, Root = rootCF.Position })
	Network.fire(player, "Portal", { Duration = v.PortalFlash })
	Sfx.play(root, Config.Sounds.Portal, 1, 1, 100)
	if not pause(S, v.PortalFlash) then return end
	Network.fire(player, "Ink", { Duration = v.InkBurst })
	if not pause(S, math.max(0, v.ExplosionDelay - v.PortalFlash)) then return end

	--------------------------------------------------------------------------
	-- FASE 1: explosion, restos volando, sangre, rayos de colores
	--------------------------------------------------------------------------
	local folder = World.subfolder("Remains", S.Maid)
	local entries = Remains.build(character, rootCF, folder, v)
	Remains.hideReal(character, S.Hidden)
	S.Removed = Clothing.strip(character)

	local origin = rootCF.Position + Vector3.new(0, 0.4, 0)
	local ctx = {
		Maid = S.Maid,
		Character = character,
		GroundPos = groundPos,
		GroundY = groundPos.Y,
	}

	FX.explosion(origin, character, v)
	Network.fire(player, "Blast", { Position = origin, Variant = S.VariantName })
	Network.fireNearby(origin, 260, "Shake", { Intensity = v.CameraShake, Duration = 1.3, Origin = origin })
	Network.fire(player, "Camera", {
		Mode = v.CameraMode,
		Target = groundPos + Vector3.new(0, 1, 0),
		Duration = v.CameraTime,
	})

	Blood.burst(groundPos, character, v.BloodBlast, 22, 0)
	Blood.puddle(groundPos, character, 1, 0.06)
	FX.rays(groundPos + Vector3.new(0, 0.9, 0), Utils.randomUnit(), v.RayDuration, v.RayLength, S.Maid)
	Blood.bleed(groundPos, character, v.FlightTime + v.SmolderTime + v.ReassembleTime * 0.4, v.BleedRate, S.Maid)

	Remains.launch(entries, origin, v)
	Remains.simulate(entries, v.FlightTime + v.SmolderTime, ctx)
	if not alive(S) then return end

	--------------------------------------------------------------------------
	-- FASE 2: las partes se juntan, el cuerpo se levanta
	--------------------------------------------------------------------------
	Remains.freeze(entries)
	Network.fire(player, "Reform", { Duration = v.ReassembleTime })
	Sfx.play(root, Config.Sounds.Reform, 1, 1, 100)

	Remains.reassemble(entries, v.ReassembleTime, function()
		return poseAt(lieTheta)
	end, ctx)
	if not alive(S) then return end

	Remains.holdLying(entries, v.LieTime, function()
		return poseAt(lieTheta)
	end, ctx)
	if not alive(S) then return end

	riseFlames(groundPos)
	Network.fire(player, "Rise", {})
	Sfx.play(root, Config.Sounds.Rise, 1, 1, 100)
	Remains.rise(entries, v.RiseTime, function(a)
		return poseAt(Utils.lerp(lieTheta, 0, Utils.Ease.outBack(a)))
	end, ctx)
	if not alive(S) then return end

	Remains.settle(entries, v.SkinSettle, poseAt(0), ctx)
	if not alive(S) then return end

	--------------------------------------------------------------------------
	-- FASE 3: el personaje real regresa (primero piel), ropa por etapas
	--------------------------------------------------------------------------
	local standCF = poseAt(0)
	root.CFrame = standCF
	Remains.showReal(S.Hidden)
	Remains.destroy(entries)
	Remains.flashPulse(standCF.Position, 5)
	Network.fire(player, "CameraRelease", { Target = standCF.Position })
	FX.tail(character, v.TailTime)
	Sfx.play(root, Config.Sounds.Fire, 0.8, 1, 80)

	task.delay(0.2, function()
		Controller.release(S)
	end)

	if not pause(S, v.PantsDelay) then return end
	Clothing.restoreKind(character, S.Removed, { "Pants" })
	if Config.Clothes.PulseOnReturn then
		Remains.flashPulse(root.Position - Vector3.new(0, 1.5, 0), 2.6, Config.Colors.GlowHot)
	end

	if not pause(S, math.max(0, v.ShirtDelay - v.PantsDelay)) then return end
	Clothing.restoreKind(character, S.Removed, { "Shirt", "ShirtGraphic" })
	if Config.Clothes.PulseOnReturn then
		Remains.flashPulse(root.Position + Vector3.new(0, 0.8, 0), 3.2)
	end

	pause(S, 0.4)
end

-- Punto de entrada. reason: "lethal" | "manual" | "api" | "void"
function Controller.regenerate(player, character, reason)
	if typeof(character) ~= "Instance" or not character:IsA("Model") or not character.Parent then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return false
	end
	if Controller.Active[character] then
		return false
	end
	if reason ~= "lethal" and player then
		local t = Controller.Cooldowns[player]
		if t and os.clock() < t then
			return false
		end
	end

	local variant, variantName = currentVariant()
	local S = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Maid = Maid.new(),
		Variant = variant,
		VariantName = variantName,
		Hidden = {},
		Removed = {},
		Reason = reason,
	}
	Controller.Active[character] = S
	character:SetAttribute("RickPrimeRegenerating", true)

	S.Maid:Give(character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			S.Maid:Clean()
		end
	end))

	task.spawn(function()
		local ok, err = pcall(Controller.run, S)
		if not ok then
			warn("[RickPrimeRegen] error en la secuencia: " .. tostring(err))
		end
		Controller.cleanup(S)
	end)
	return true
end

--// ENGANCHES POR PERSONAJE -----------------------------------------------------
local function onCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 15)
	local root = character:WaitForChild("HumanoidRootPart", 15)
	if not humanoid or not root then
		return
	end

	if Config.Trigger.OnLethalDamage then
		-- Sin estado "Dead" el personaje se queda con 0 de vida y lo regeneramos.
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end)
		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 and not character:GetAttribute("RickPrimeRegenerating") then
				Controller.regenerate(player, character, "lethal")
			end
		end)
		if humanoid.Health <= 0 then
			Controller.regenerate(player, character, "lethal")
		end
	end

	if Config.Trigger.OnLethalDamage and Config.Trigger.RescueFromVoid then
		task.spawn(function()
			local lastSafe = root.CFrame
			local limit = Workspace.FallenPartsDestroyHeight + Config.Trigger.VoidMargin
			while character.Parent and root.Parent do
				task.wait(0.25)
				local y = root.Position.Y
				if humanoid.FloorMaterial ~= Enum.Material.Air and y > limit + 40 then
					lastSafe = root.CFrame
				elseif y < limit and not character:GetAttribute("RickPrimeRegenerating") then
					root.AssemblyLinearVelocity = Vector3.zero
					root.CFrame = lastSafe + Vector3.new(0, 2, 0)
					Controller.regenerate(player, character, "lethal")
				end
			end
		end)
	end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(player)
	Controller.Cooldowns[player] = nil
end)

-- Tecla del cliente
Network.Event.OnServerEvent:Connect(function(player, action)
	if action ~= "Request" or not Config.Trigger.ManualEnabled then
		return
	end
	local character = player.Character
	if character then
		Controller.regenerate(player, character, "manual")
	end
end)

-- API para otros scripts del servidor: BindableEvent en ServerStorage
local bindable = ServerStorage:FindFirstChild(TRIGGER_NAME)
if not bindable then
	bindable = Utils.make("BindableEvent", { Name = TRIGGER_NAME }, ServerStorage)
end
bindable.Event:Connect(function(target)
	if typeof(target) ~= "Instance" then
		return
	end
	if target:IsA("Player") and target.Character then
		Controller.regenerate(target, target.Character, "api")
	elseif target:IsA("Model") then
		Controller.regenerate(Players:GetPlayerFromCharacter(target), target, "api")
	end
end)

-- Instala la parte cliente: este mismo Script se clona con RunContext = Client
do
	local old = ReplicatedStorage:FindFirstChild("RickPrimeRegenClient")
	if old then
		old:Destroy()
	end
	local ok, err = pcall(function()
		local copy = script:Clone()
		copy.Name = "RickPrimeRegenClient"
		copy.RunContext = Enum.RunContext.Client
		copy.Enabled = true
		copy.Parent = ReplicatedStorage
	end)
	if not ok then
		warn("[RickPrimeRegen] no se pudo instalar la parte cliente: " .. tostring(err))
	end
end

Utils.log("Rick Prime Regeneration cargado. Variante:", Config.Variant)
