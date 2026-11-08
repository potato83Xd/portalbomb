--[[
	=====================================================================
	  RICK PRIME REGENERATION  |  Versión local (solo para ti)
	  Tipo:       LocalScript
	  Ubicación:  StarterPlayer > StarterPlayerScripts
	  Controles:  Tecla H (o botón táctil "REGEN" en móvil / botón Y en mando)

	  Estructura copiada del script A-Train:
	   - Un solo LocalScript, sin Script de servidor ni RemoteEvent.
	   - Todo lo visual cuelga de workspace.RickPrimeFX (carpeta local).
	   - Todo se crea en TU cliente: los demás jugadores NO ven nada.

	  Incluye:
	   - Flash psicodélico -> tinta negra -> explosión con fuego y humo
	   - Cuerpo en partes neón con sangre y rayos de colores
	   - Las partes se juntan, el cuerpo se levanta entre llamas
	   - Piel, pantalones y camisa por etapas + cola de fuego
	   - Cámara cinemática (push v4 / low v3) y temblor de cámara
	=====================================================================
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------------
-- CONFIGURACIÓN
----------------------------------------------------------------------
local CONFIG = {
	-- Variante activa: "v3" o "v4"
	Variant = "v4",

	-- Activación
	TriggerKey = Enum.KeyCode.H,
	Cooldown = 5,                 -- segundos entre regeneraciones

	-- Solo funciona si la muerte la procesa tu cliente. El servidor sigue
	-- matando al personaje igual, por eso viene apagado.
	OnLethalDamage = false,
	RescueFromVoid = false,       -- solo se usa con OnLethalDamage = true
	VoidMargin = 80,

	-- Pantalla
	Palette = {
		Color3.fromRGB(18, 190, 185),
		Color3.fromRGB(20, 150, 160),
		Color3.fromRGB(255, 118, 62),
		Color3.fromRGB(235, 90, 70),
		Color3.fromRGB(70, 120, 255),
		Color3.fromRGB(170, 92, 255),
		Color3.fromRGB(255, 150, 175),
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

	-- Colores
	Colors = {
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
	},

	Textures = {
		Fire = "rbxasset://textures/particles/fire_main.dds",
		Smoke = "rbxasset://textures/particles/smoke_main.dds",
		Sparkle = "rbxasset://textures/particles/sparkles_main.dds",
		Soft = "rbxasset://textures/particles/sparkles_main.dds",
	},

	-- Sonidos: deja "" para silencio. Puedes poner tus ids "rbxassetid://..."
	Sounds = {
		Explosion = "rbxasset://sounds/impact_explosion_03.mp3",
		Portal = "",
		Reform = "",
		Rise = "",
		Fire = "",
		Volume = 1.2,
	},

	Blood = {
		Enabled = true,
		MaxParts = 260,
		Lifetime = 28,
		FadeTime = 4,
		Thickness = 0.05,
		MainPuddleRadius = { 5.5, 9 },
		LobeCount = { 4, 7 },
		DropCount = { 12, 20 },
		DropRadius = { 0.5, 2.2 },
		DropSpread = 20,
		ImpactChance = 0.55,
	},

	Debris = {
		SpeedMin = 34,
		SpeedMax = 72,
		SpinMax = 26,
		Density = 0.7,
		Friction = 0.4,
		Elasticity = 0.25,
		TrailLifetime = 0.45,
		FirePerPart = true,
		PulseSpeed = 14,
		RainbowTrailParts = 4,
	},

	Explosion = {
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
	},

	Rays = {
		Count = 3,
		Width = 0.45,
		LateralSpacing = 0.55,
		FlickerRate = 22,
		BulbSize = 1.7,
		BulbLightRange = 26,
		BulbLightBrightness = 6,
		FadeTime = 0.6,
	},

	Tail = {
		FireRate = 38,
		SmokeRate = 14,
		FireSideOffset = Vector3.new(-1.6, 0.6, 0.4),
		DecayStart = 0.55,
	},

	Clothes = {
		StripOnRegen = true,
		PulseOnReturn = true,
	},

	-- Variantes de tiempos (segundos). Todo se mide desde el disparo.
	Variants = {
		v4 = {
			PortalFlash = 0.26, InkBurst = 0.30, ExplosionDelay = 0.46,
			FlightTime = 1.15, SmolderTime = 0.12, ReassembleTime = 0.75,
			LieTime = 0.22, RiseTime = 0.55, SkinSettle = 0.35,
			PantsDelay = 0.18, ShirtDelay = 0.38, TailTime = 1.6,
			CameraMode = "push", CameraShake = 1.0, CameraTime = 1.9,
			RayDuration = 1.9, RayLength = 64, BloodBlast = 24, BleedRate = 6,
			FireScale = 1.0, DebrisSpeedScale = 1.0, GlowBlast = 1.0,
		},
		v3 = {
			PortalFlash = 0.30, InkBurst = 0.34, ExplosionDelay = 0.52,
			FlightTime = 0.95, SmolderTime = 3.4, ReassembleTime = 1.0,
			LieTime = 0.55, RiseTime = 0.9, SkinSettle = 0.7,
			PantsDelay = 0.4, ShirtDelay = 0.85, TailTime = 1.2,
			CameraMode = "low", CameraShake = 0.7, CameraTime = 5.3,
			RayDuration = 5.0, RayLength = 90, BloodBlast = 30, BleedRate = 10,
			FireScale = 1.2, DebrisSpeedScale = 0.75, GlowBlast = 0.9,
		},
	},
}

local C = CONFIG.Colors
local T = CONFIG.Textures

----------------------------------------------------------------------
-- UTILIDADES
----------------------------------------------------------------------
local rng = Random.new()

local function rand(a, b)
	return rng:NextNumber(a, b)
end

local function randInt(a, b)
	return rng:NextInteger(a, b)
end

local function chance(p)
	return rng:NextNumber() < p
end

local function randomUnit()
	return rng:NextUnitVector()
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp01(x)
	return math.max(0, math.min(1, x))
end

local function remap(x, a, b, c, d)
	if b == a then
		return c
	end
	return c + (d - c) * clamp01((x - a) / (b - a))
end

local function lerpColor(a, b, t)
	return a:Lerp(b, clamp01(t))
end

local Ease = {}
function Ease.inOutQuad(t)
	if t < 0.5 then
		return 2 * t * t
	end
	return 1 - ((-2 * t + 2) ^ 2) / 2
end
function Ease.inOutCubic(t)
	if t < 0.5 then
		return 4 * t * t * t
	end
	return 1 - ((-2 * t + 2) ^ 3) / 2
end
function Ease.outCubic(t)
	return 1 - (1 - t) ^ 3
end
function Ease.outBack(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * ((t - 1) ^ 3) + c1 * ((t - 1) ^ 2)
end

local function make(className, props, parent)
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

local function tween(inst, seconds, goal, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	tw:Play()
	return tw
end

-- Ejecuta callback(alpha, dt, elapsed) cada Heartbeat durante "duration".
-- Si el callback devuelve false se aborta y step devuelve false.
local function step(duration, callback)
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

local function numberSeq(points)
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(keys)
end

local function colorSeq(points)
	local keys = {}
	for _, p in ipairs(points) do
		table.insert(keys, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(keys)
end

-- CFrame con el eje X apuntando a "normal" (cilindros planos sobre el suelo)
local function cframeFromNormalX(position, normal, spin)
	local tangent = normal:Cross(Vector3.xAxis)
	if tangent.Magnitude < 0.01 then
		tangent = normal:Cross(Vector3.zAxis)
	end
	tangent = tangent.Unit
	return CFrame.fromMatrix(position, normal, tangent) * CFrame.Angles(spin or 0, 0, 0)
end

local function pickColor()
	return CONFIG.Palette[rng:NextInteger(1, #CONFIG.Palette)]
end

local function currentVariant()
	return CONFIG.Variants[CONFIG.Variant] or CONFIG.Variants.v4
end

print("[RickPrime] versión local cargada")

----------------------------------------------------------------------
-- MAID (limpieza de objetos / conexiones)
----------------------------------------------------------------------
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {}, _clean = false }, Maid)
end

local function disposeItem(item)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "function" then
		pcall(item)
	end
end

function Maid:Give(item)
	if self._clean then
		disposeItem(item)
		return item
	end
	table.insert(self._tasks, item)
	return item
end

function Maid:Clean()
	if self._clean then
		return
	end
	self._clean = true
	for i = #self._tasks, 1, -1 do
		disposeItem(self._tasks[i])
	end
	self._tasks = {}
end

----------------------------------------------------------------------
-- MUNDO LOCAL (carpeta de efectos, solo existe en tu cliente)
----------------------------------------------------------------------
local fxFolder = Workspace:FindFirstChild("RickPrimeFX")
if fxFolder then
	fxFolder:ClearAllChildren()
else
	fxFolder = make("Folder", { Name = "RickPrimeFX" }, Workspace)
end

local function subfolder(name, maid)
	local f = make("Folder", { Name = name }, fxFolder)
	if maid then
		maid:Give(f)
	end
	return f
end

local function findGround(position, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = character and { fxFolder, character } or { fxFolder }
	params.IgnoreWater = true
	local result = Workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -500, 0), params)
	if result then
		return result.Position, result.Normal, result.Instance
	end
	return Vector3.new(position.X, position.Y - 3, position.Z), Vector3.yAxis, nil
end

local function playSound(parent, soundId, volume, speed, maxDistance)
	if not soundId or soundId == "" or not parent then
		return nil
	end
	local s = make("Sound", {
		SoundId = soundId,
		Volume = (volume or 1) * CONFIG.Sounds.Volume,
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

----------------------------------------------------------------------
-- EFECTOS DE PANTALLA
----------------------------------------------------------------------
local Gui = make("ScreenGui", {
	Name = "RickPrimeRegenFX",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local Screen = {}

local function screenBase()
	local size = Gui.AbsoluteSize
	return math.max(1, math.min(size.X, size.Y))
end

-- Flash psicodélico: manchas grandes y borrosas que estallan desde el centro
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
	tween(blur, duration * 0.5, { Size = CONFIG.PortalBlur })

	for i = 1, CONFIG.PortalBlobs do
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
		BackgroundColor3 = CONFIG.InkTint,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 20,
	}, Gui)

	local blur = make("BlurEffect", { Name = "RPInkBlur", Size = 14 }, Lighting)
	tween(blur, duration, { Size = 0 })

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

	for i = 1, CONFIG.InkTendrils do
		local angle = (i / CONFIG.InkTendrils) * 360 + rand(-6, 6)
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

	for _ = 1, CONFIG.InkDots do
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
	local B = CONFIG.Blast
	local cc = make("ColorCorrectionEffect", {
		Name = "RPBlastCC",
		Brightness = B.Brightness,
		Contrast = B.Contrast,
		Saturation = B.Saturation,
	}, Lighting)
	tween(cc, B.Time, { Brightness = 0, Contrast = 0, Saturation = 0 })

	local bloom = make("BloomEffect", {
		Name = "RPBlastBloom",
		Intensity = B.BloomIntensity,
		Size = B.BloomSize,
		Threshold = B.BloomThreshold,
	}, Lighting)
	tween(bloom, B.Time + 0.2, { Intensity = 0 })

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

----------------------------------------------------------------------
-- TEMBLOR DE CÁMARA
----------------------------------------------------------------------
local Shake = { Active = {} }

function Shake.add(intensity, duration)
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
			local t = s.T * CONFIG.Shake.Frequency
			pos += Vector3.new(math.noise(t, s.Seed, 0), math.noise(0, t, s.Seed), 0) * 2 * amp * CONFIG.Shake.PositionScale
			rot += Vector3.new(math.noise(t, 0, s.Seed), math.noise(s.Seed, t, 0), math.noise(0, s.Seed, t)) * 2 * amp * CONFIG.Shake.RotationScale
		end
	end
	cam.CFrame = cam.CFrame * CFrame.new(pos) * CFrame.Angles(rot.X, rot.Y, rot.Z)
end)

----------------------------------------------------------------------
-- DIRECTOR DE CÁMARA
-- push (v4): empuje corto hacia la explosión y retorno.
-- low  (v3): cámara baja, orbitando lento la pila de restos.
----------------------------------------------------------------------
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

function Director.prepare(rootPos)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	Director.RootPos = rootPos
	Director.StartOffset = cam.CFrame.Position - rootPos
	Director.StartFov = cam.FieldOfView
end

local function desiredCF()
	local t = Director.Elapsed
	local target = Director.Target
	if Director.Mode == "low" then
		local L = CONFIG.Camera.Low
		local ang = Director.Angle + t * L.OrbitSpeed
		local pos = target + Vector3.new(math.cos(ang) * L.Radius, L.Height, math.sin(ang) * L.Radius)
		return CFrame.lookAt(pos, target + Vector3.new(0, L.LookHeight, 0)), L.FovTarget
	end
	local P = CONFIG.Camera.Push
	local away = Director.StartCF.Position - target
	if away.Magnitude < 0.5 then
		away = Vector3.new(0, 0, 1)
	end
	local drift = 1 + math.sin(t * 1.4) * 0.03 - t * 0.02 * P.DriftSpeed
	local pos = target + away.Unit * (P.Distance * drift) + Vector3.new(0, P.Height, 0)
	return CFrame.lookAt(pos, target + Vector3.new(0, 1.2, 0)), P.FovTarget
end

function Director.start(mode, target, duration)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	Director.Mode = mode or "push"
	Director.Target = target or Director.Target
	Director.Duration = duration or 2
	Director.Elapsed = 0
	Director.StartCF = cam.CFrame
	Director.StartFov = cam.FieldOfView
	Director.Releasing = false
	Director.Active = true
	local away = cam.CFrame.Position - Director.Target
	Director.Angle = math.atan2(away.Z, away.X)
	cam.CameraType = Enum.CameraType.Scriptable
end

function Director.release(targetPos)
	if not Director.Active or Director.Releasing then
		return
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local rootPos = targetPos or Director.RootPos
	Director.ReleaseFrom = cam.CFrame
	Director.ReleaseTo = CFrame.lookAt(rootPos + Director.StartOffset, rootPos + Vector3.new(0, 2, 0))
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
		local k = Ease.inOutCubic(clamp01(Director.ReleaseT / CONFIG.Camera.BlendOut))
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
	local blend = Ease.outCubic(clamp01(Director.Elapsed / CONFIG.Camera.BlendIn))
	cam.CFrame = Director.StartCF:Lerp(desired, blend)
	cam.FieldOfView = Director.StartFov + (fov - Director.StartFov) * blend

	-- por seguridad: si nadie libera la cámara, se libera sola
	if Director.Elapsed > Director.Duration + 3 then
		Director.release(Director.Target)
	end
end)

----------------------------------------------------------------------
-- SANGRE
-- Charcos y gotas rojas planas sobre el suelo. Hay un tope de partes.
----------------------------------------------------------------------
local Blood = {}
Blood.Folder = subfolder("Blood", nil)
Blood.Parts = {}
Blood.Layer = 0

local function pickBloodColor()
	local r = rng:NextNumber()
	if r < 0.58 then
		return C.Blood
	elseif r < 0.82 then
		return C.BloodDark
	end
	return C.BloodLight
end

function Blood.register(part)
	table.insert(Blood.Parts, part)
	while #Blood.Parts > CONFIG.Blood.MaxParts do
		local old = table.remove(Blood.Parts, 1)
		if old then
			old:Destroy()
		end
	end
	task.delay(CONFIG.Blood.Lifetime + rand(0, 6), function()
		if part.Parent then
			tween(part, CONFIG.Blood.FadeTime, { Transparency = 1 })
			task.delay(CONFIG.Blood.FadeTime + 0.2, function()
				if part.Parent then
					part:Destroy()
				end
			end)
		end
	end)
end

-- Una mancha circular. position = punto sobre el suelo, normal = normal del suelo
function Blood.splat(position, normal, radius, delay, growTime)
	if not CONFIG.Blood.Enabled then
		return nil
	end
	Blood.Layer = (Blood.Layer + 1) % 48
	local lift = 0.03 + Blood.Layer * 0.004
	local diameter = radius * 2
	local part = make("Part", {
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
		Size = Vector3.new(CONFIG.Blood.Thickness, 0.1, 0.1),
		CFrame = cframeFromNormalX(position + normal * lift, normal, rand(0, math.pi * 2)),
		Transparency = 1,
	}, Blood.Folder)
	Blood.register(part)

	task.delay(delay or 0, function()
		if not part.Parent then
			return
		end
		part.Transparency = 0
		local t = growTime or rand(0.25, 0.7)
		tween(part, t, { Size = Vector3.new(CONFIG.Blood.Thickness, diameter, diameter) },
			Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	end)
	return part
end

-- Charco grande con lóbulos (forma orgánica) + gotas alrededor
function Blood.puddle(center, character, scale, delay)
	if not CONFIG.Blood.Enabled then
		return
	end
	scale = scale or 1
	local ground, normal = findGround(center, character)
	local mainR = rand(CONFIG.Blood.MainPuddleRadius[1], CONFIG.Blood.MainPuddleRadius[2]) * scale
	Blood.splat(ground, normal, mainR, delay, 0.55)

	local lobes = randInt(CONFIG.Blood.LobeCount[1], CONFIG.Blood.LobeCount[2])
	for i = 1, lobes do
		local ang = (i / lobes) * math.pi * 2 + rand(-0.4, 0.4)
		local dist = mainR * rand(0.45, 0.85)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = findGround(ground + off, character)
		Blood.splat(g, n, mainR * rand(0.3, 0.62), (delay or 0) + rand(0, 0.12), 0.5)
	end

	local drops = randInt(CONFIG.Blood.DropCount[1], CONFIG.Blood.DropCount[2])
	for _ = 1, drops do
		local ang = rand(0, math.pi * 2)
		local dist = rand(mainR * 0.9, CONFIG.Blood.DropSpread * scale)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = findGround(ground + off, character)
		local r = rand(CONFIG.Blood.DropRadius[1], CONFIG.Blood.DropRadius[2]) * scale
		Blood.splat(g, n, r, (delay or 0) + rand(0.02, 0.35), rand(0.15, 0.4))
	end
end

-- Lluvia de gotas alrededor del punto (explosión)
function Blood.burst(center, character, count, spread, delay)
	for _ = 1, count do
		local ang = rand(0, math.pi * 2)
		local dist = rand(2, spread)
		local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
		local g, n = findGround(center + off, character)
		Blood.splat(g, n, rand(0.45, 2.1), (delay or 0) + dist / spread * 0.3 + rand(0, 0.1), rand(0.12, 0.35))
	end
end

-- Gota individual cuando una parte golpea el suelo
function Blood.impact(position, character)
	local g, n = findGround(position, character)
	Blood.splat(g, n, rand(0.5, 1.7), 0, rand(0.1, 0.25))
end

-- Sangrado continuo de la pila de restos
function Blood.bleed(center, character, duration, ratePerSecond, maid)
	task.spawn(function()
		local acc = 0
		step(duration, function(_, dt)
			if maid and maid._clean then
				return false
			end
			acc += dt * ratePerSecond
			while acc >= 1 do
				acc -= 1
				local ang = rand(0, math.pi * 2)
				local dist = rand(0.5, 6)
				local off = Vector3.new(math.cos(ang) * dist, 0, math.sin(ang) * dist)
				local g, n = findGround(center + off, character)
				Blood.splat(g, n, rand(0.4, 1.4), 0, rand(0.2, 0.5))
			end
		end)
	end)
end

----------------------------------------------------------------------
-- EFECTOS (partículas, explosión, rayos, cola de fuego)
----------------------------------------------------------------------
local FX = {}
FX.Presets = {}

function FX.anchorPart(position, name, parent)
	return make("Part", {
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
	e.Texture = T.Soft
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

function FX.Presets.Fireball(scale)
	scale = scale or 1
	return {
		Texture = T.Fire,
		Color = colorSeq({ { 0, C.FireA }, { 0.35, C.FireB }, { 0.75, C.FireC }, { 1, C.FireD } }),
		Size = numberSeq({ { 0, 4 * scale }, { 0.4, 11 * scale }, { 1, 3 * scale } }),
		Transparency = numberSeq({ { 0, 0.05 }, { 0.6, 0.3 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.SmokeDark }, { 0.5, C.SmokeMid }, { 1, C.SmokeLight } }),
		Size = numberSeq({ { 0, 5 * scale }, { 0.5, 12 * scale }, { 1, 18 * scale } }),
		Transparency = numberSeq({ { 0, 0.1 }, { 0.5, 0.35 }, { 1, 1 } }),
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
		Size = numberSeq({ { 0, 8 * scale }, { 1, 26 * scale } }),
		Transparency = numberSeq({ { 0, 0.55 }, { 0.4, 0.7 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.GlowWhite }, { 0.4, C.FireA }, { 1, C.FireB } }),
		Size = numberSeq({ { 0, 1.4 }, { 1, 0 } }),
		Transparency = numberSeq({ { 0, 0 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.FireA }, { 1, C.FireC } }),
		Size = numberSeq({ { 0, 0.7 }, { 1, 0 } }),
		Transparency = numberSeq({ { 0, 0 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.FireA }, { 0.5, C.FireB }, { 1, C.FireC } }),
		Size = numberSeq({ { 0, 2.2 * scale }, { 1, 0.3 } }),
		Transparency = numberSeq({ { 0, 0.15 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.SmokeMid }, { 1, C.SmokeDark } }),
		Size = numberSeq({ { 0, 1.2 }, { 1, 3.6 } }),
		Transparency = numberSeq({ { 0, 0.5 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.FireA }, { 0.45, C.FireB }, { 1, C.FireC } }),
		Size = numberSeq({ { 0, 2.6 }, { 0.5, 3.4 }, { 1, 0.6 } }),
		Transparency = numberSeq({ { 0, 0.1 }, { 1, 1 } }),
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
		Color = colorSeq({ { 0, C.SmokeLight }, { 1, C.SmokeMid } }),
		Size = numberSeq({ { 0, 1.4 }, { 1, 5 } }),
		Transparency = numberSeq({ { 0, 0.55 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.0, 2.2),
		Speed = NumberRange.new(1, 5),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, 6, 0),
		RotSpeed = NumberRange.new(-30, 30),
	}
end

-- Estela simple en una parte
function FX.trail(part, colorA, colorB, lifetime, width, offsetX)
	local a0 = make("Attachment", { Name = "RPTrail0", Position = Vector3.new(offsetX or 0, width * 0.5, 0) }, part)
	local a1 = make("Attachment", { Name = "RPTrail1", Position = Vector3.new(offsetX or 0, -width * 0.5, 0) }, part)
	return make("Trail", {
		Attachment0 = a0,
		Attachment1 = a1,
		Color = ColorSequence.new(colorA, colorB or colorA),
		Transparency = numberSeq({ { 0, 0.05 }, { 1, 1 } }),
		Lifetime = lifetime or 0.4,
		LightEmission = 1,
		LightInfluence = 0,
		MinLength = 0.05,
		FaceCamera = true,
	}, part)
end

-- Tres estelas rojo / amarillo / azul paralelas
function FX.rainbowTrail(part)
	local cols = { C.RayRed, C.RayYellow, C.RayBlue }
	for i, c in ipairs(cols) do
		FX.trail(part, c, c, 0.55, 0.55, (i - 2) * 0.55)
	end
end

local function ballPart(name, color, material, transparency, size, position, parent)
	return make("Part", {
		Name = name,
		Shape = Enum.PartType.Ball,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = material,
		Color = color,
		Transparency = transparency,
		Size = size,
		CFrame = CFrame.new(position),
	}, parent)
end

-- Explosión principal: bola de fuego, humo negro, destello, onda, esquirlas
function FX.explosion(position, character, variant)
	local folder = subfolder("Explosion", nil)
	local core = FX.anchorPart(position, "BlastCore", folder)
	local att = make("Attachment", nil, core)

	local light = make("PointLight", {
		Color = C.GlowWhite,
		Brightness = CONFIG.Explosion.FlashBrightness * variant.GlowBlast,
		Range = CONFIG.Explosion.FlashRange,
		Shadows = false,
	}, core)
	tween(light, 0.55, { Brightness = 0, Range = 8 })

	local fire = FX.emitter(att, FX.Presets.Fireball(variant.FireScale))
	local smoke = FX.emitter(att, FX.Presets.BlackSmoke(1))
	local haze = FX.emitter(att, FX.Presets.WhiteHaze(1))
	local sparks = FX.emitter(att, FX.Presets.Sparks())
	local embers = FX.emitter(att, FX.Presets.Embers())
	fire:Emit(CONFIG.Explosion.FireburstCount)
	smoke:Emit(CONFIG.Explosion.SmokeCount)
	haze:Emit(18)
	sparks:Emit(CONFIG.Explosion.SparkCount)
	embers:Emit(40)

	-- Destello esférico
	local flash = ballPart("BlastFlash", C.GlowWhite, Enum.Material.Neon, 0.1, Vector3.new(3, 3, 3), position, folder)
	tween(flash, 0.3, { Size = Vector3.new(22, 22, 22), Transparency = 1 }, Enum.EasingStyle.Quart)

	-- Onda de choque naranja
	local radius = CONFIG.Explosion.Radius
	local wave = ballPart("Shockwave", C.Shockwave, Enum.Material.Neon, 0.45, Vector3.new(2, 2, 2), position, folder)
	tween(wave, CONFIG.Explosion.ShockwaveTime, {
		Size = Vector3.new(radius * 2, radius * 2, radius * 2),
		Transparency = 1,
	})

	-- Bola de humo oscuro
	local smokeBall = ballPart("SmokeBall", C.SmokeDark, Enum.Material.SmoothPlastic, 0.3, Vector3.new(4, 4, 4), position, folder)
	tween(smokeBall, 0.55, { Size = Vector3.new(19, 15, 19), Transparency = 1 })

	-- Anillo en el suelo
	local ground, normal = findGround(position, character)
	local ring = make("Part", {
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
		CFrame = cframeFromNormalX(ground + normal * 0.12, normal, 0),
	}, folder)
	tween(ring, 0.5, { Size = Vector3.new(0.25, radius * 2.2, radius * 2.2), Transparency = 1 }, Enum.EasingStyle.Quart)

	-- Esquirlas oscuras (salpicadura negra)
	for _ = 1, CONFIG.Explosion.ShardCount do
		local s = rand(0.3, 1.2)
		local shard = make("Part", {
			Name = "Shard",
			Size = Vector3.new(s, s * rand(0.4, 1.6), s * rand(0.4, 1.4)),
			Color = C.Shard,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(position + randomUnit() * 1.2) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6)),
		}, folder)
		local dir = (randomUnit() + Vector3.new(0, 0.7, 0)).Unit
		shard.AssemblyLinearVelocity = dir * rand(30, 80)
		shard.AssemblyAngularVelocity = randomUnit() * rand(6, 24)
		task.delay(CONFIG.Explosion.ShardLifetime, function()
			if shard.Parent then
				tween(shard, 0.35, { Transparency = 1 })
			end
		end)
	end

	playSound(core, CONFIG.Sounds.Explosion, 1.3, rand(0.92, 1.05), CONFIG.Explosion.BlastSoundDistance)

	task.delay(6, function()
		if folder.Parent then
			folder:Destroy()
		end
	end)
	return folder
end

-- Rayos de colores atravesando la pila + foco amarillo en un extremo
function FX.rays(center, direction, duration, length, maid)
	local folder = subfolder("Rays", nil)
	if maid then
		maid:Give(folder)
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.zAxis
	end
	local baseDir = flat.Unit
	local cols = { C.RayRed, C.RayYellow, C.RayBlue }
	local count = CONFIG.Rays.Count
	local entries = {}

	for i = 1, count do
		local lat = (i - (count + 1) / 2) * CONFIG.Rays.LateralSpacing
		local lift = rand(0.15, 0.7)
		local pa = FX.anchorPart(center, "RayA", folder)
		local pb = FX.anchorPart(center, "RayB", folder)
		local a0 = make("Attachment", nil, pa)
		local a1 = make("Attachment", nil, pb)
		local beam = make("Beam", {
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
		table.insert(entries, { Beam = beam, PA = pa, PB = pb, Lat = lat, Lift = lift, Phase = rand(0, 6.28) })
	end

	local bulb = ballPart("RayBulb", C.Bulb, Enum.Material.Neon, 0, Vector3.new(0.1, 0.1, 0.1), center, folder)
	local bulbLight = make("PointLight", {
		Color = C.Bulb,
		Brightness = 0,
		Range = CONFIG.Rays.BulbLightRange,
		Shadows = false,
	}, bulb)

	task.spawn(function()
		local fadeTime = CONFIG.Rays.FadeTime
		step(duration, function(_, _, elapsed)
			if maid and maid._clean then
				return false
			end
			local fadeIn = math.min(1, elapsed / 0.14)
			local fadeOut = 1 - remap(elapsed, duration - fadeTime, duration, 0, 1)
			local env = fadeIn * fadeOut
			local angle = elapsed * 0.07
			local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(baseDir)
			local lateralDir = dir:Cross(Vector3.yAxis)
			if lateralDir.Magnitude < 0.01 then
				lateralDir = Vector3.xAxis
			end
			lateralDir = lateralDir.Unit
			for _, e in ipairs(entries) do
				local flicker = 0.72 + 0.28 * math.sin(elapsed * CONFIG.Rays.FlickerRate + e.Phase)
				local w = CONFIG.Rays.Width * flicker * env
				e.Beam.Width0 = w
				e.Beam.Width1 = w
				local off = lateralDir * e.Lat + Vector3.new(0, e.Lift, 0)
				e.PA.CFrame = CFrame.new(center - dir * (length * 0.28) + off)
				e.PB.CFrame = CFrame.new(center + dir * (length * 0.72) + off)
			end
			local s = CONFIG.Rays.BulbSize * env * (0.9 + 0.1 * math.sin(elapsed * 31))
			bulb.Size = Vector3.new(s, s, s)
			bulb.CFrame = CFrame.new(center - dir * (length * 0.28) + Vector3.new(0, 0.6, 0))
			bulbLight.Brightness = CONFIG.Rays.BulbLightBrightness * env
		end)
		if folder.Parent then
			folder:Destroy()
		end
	end)
end

-- Fuego lateral + humo sobre el personaje ya regenerado
function FX.tail(character, duration)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = make("Attachment", { Name = "RPTailFire", Position = CONFIG.Tail.FireSideOffset }, root)
	local att2 = make("Attachment", { Name = "RPTailSmoke", Position = Vector3.new(0.4, 1.8, 0.7) }, root)
	local fire = FX.emitter(att, FX.Presets.TailFire())
	fire.Rate = CONFIG.Tail.FireRate
	local smoke = FX.emitter(att2, FX.Presets.TailSmoke())
	smoke.Rate = CONFIG.Tail.SmokeRate
	local light = make("PointLight", { Name = "RPTailLight", Color = C.FireB, Brightness = 3, Range = 18, Shadows = false }, root)

	task.spawn(function()
		local decayFrom = duration * CONFIG.Tail.DecayStart
		step(duration, function(_, _, elapsed)
			if not root.Parent then
				return false
			end
			local k = 1 - remap(elapsed, decayFrom, duration, 0, 1)
			fire.Rate = CONFIG.Tail.FireRate * k
			smoke.Rate = CONFIG.Tail.SmokeRate * (0.4 + 0.6 * k)
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

----------------------------------------------------------------------
-- RESTOS DEL CUERPO
-- Cada parte del personaje se clona como "resto" físico, brillante y en
-- llamas. El personaje real se oculta (solo en tu cliente) y reaparece.
----------------------------------------------------------------------
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
	local rainbowLeft = CONFIG.Debris.RainbowTrailParts
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
				CONFIG.Debris.Density, CONFIG.Debris.Friction, CONFIG.Debris.Elasticity, 1, 1)
			clone.CFrame = orig.CFrame
			local entry = {
				Part = clone,
				Orig = orig,
				Offset = rootCF:ToObjectSpace(orig.CFrame),
				OrigColor = orig.Color,
				OrigMaterial = orig.Material,
				Phase = rand(0, math.pi * 2),
				BloodCD = rand(0, 0.2),
				FlashUntil = 0,
			}
			clone.Material = Enum.Material.Neon
			clone.Color = C.GlowCore
			clone.Transparency = 0
			clone.Parent = folder

			-- Fuego y humo continuos
			if CONFIG.Debris.FirePerPart then
				entry.FireEm = FX.emitter(clone, FX.Presets.DebrisFire(variant.FireScale))
				entry.SmokeEm = FX.emitter(clone, FX.Presets.DebrisSmoke())
			end
			entry.SparkEm = FX.emitter(clone, {
				Texture = T.Sparkle,
				Color = colorSeq({ { 0, C.GlowWhite }, { 1, C.FireA } }),
				Size = numberSeq({ { 0, 1.2 }, { 1, 0 } }),
				Transparency = numberSeq({ { 0, 0 }, { 1, 1 } }),
				Lifetime = NumberRange.new(0.2, 0.45),
				Speed = NumberRange.new(8, 22),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = 1,
			})

			-- Estelas
			FX.trail(clone, C.GlowCore, C.FireB, CONFIG.Debris.TrailLifetime, 1.1, 0)
			if rainbowLeft > 0 and chance(0.5) then
				rainbowLeft -= 1
				FX.rainbowTrail(clone)
			end
			if lightsLeft > 0 and chance(0.3) then
				lightsLeft -= 1
				make("PointLight", {
					Color = C.FireA,
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
	local lo = CONFIG.Debris.SpeedMin * variant.DebrisSpeedScale
	local hi = CONFIG.Debris.SpeedMax * variant.DebrisSpeedScale
	for _, e in ipairs(entries) do
		local p = e.Part
		local away = p.Position - origin
		local dir = away.Magnitude > 0.05 and away.Unit or randomUnit()
		dir = (dir + Vector3.new(rand(-0.35, 0.35), rand(0.5, 1.1), rand(-0.35, 0.35))).Unit
		p.AssemblyLinearVelocity = dir * rand(lo, hi)
		p.AssemblyAngularVelocity = randomUnit() * rand(8, CONFIG.Debris.SpinMax)
	end
end

-- Fase de vuelo / brasas: física real + pulso de brillo + sangre al golpear el suelo
function Remains.simulate(entries, duration, ctx)
	step(duration, function(_, dt, elapsed)
		if ctx.Maid._clean then
			return false
		end
		for _, e in ipairs(entries) do
			local p = e.Part
			if p.Parent then
				local pulse = 0.5 + 0.5 * math.sin(elapsed * CONFIG.Debris.PulseSpeed + e.Phase)
				p.Color = lerpColor(C.GlowHot, C.GlowCore, pulse)
				e.BloodCD -= dt
				if e.BloodCD <= 0 and (p.Position.Y - ctx.GroundY) < 3.4 and p.AssemblyLinearVelocity.Magnitude > 4 then
					e.BloodCD = rand(0.14, 0.34)
					if chance(CONFIG.Blood.ImpactChance) then
						Blood.impact(p.Position, ctx.Character)
					end
				end
				if p.Position.Y < ctx.GroundY - 60 then
					p.AssemblyLinearVelocity = Vector3.zero
					p.CFrame = CFrame.new(ctx.GroundPos + Vector3.new(rand(-3, 3), 3, rand(-3, 3)))
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
		e.Delay = rand(0, maxDelay)
		e.Travel = math.max(0.05, duration - maxDelay)
		e.StartCF = e.Part.CFrame
		e.Arrived = false
	end
	step(duration, function(_, _, elapsed)
		if ctx.Maid._clean then
			return false
		end
		local rootCF = poseFn(elapsed)
		local now = os.clock()
		for _, e in ipairs(entries) do
			local a = clamp01((elapsed - e.Delay) / e.Travel)
			local k = Ease.inOutCubic(a)
			e.Part.CFrame = e.StartCF:Lerp(rootCF * e.Offset, k)
			if a >= 1 and not e.Arrived then
				e.Arrived = true
				snapSparks(e)
			end
			e.Part.Color = (e.FlashUntil > now) and C.GlowWhite or C.GlowHot
		end
	end)
	for _, e in ipairs(entries) do
		if not e.Arrived then
			snapSparks(e)
		end
	end
end

-- Cuerpo tumbado convulsionando: temblor que va bajando
function Remains.holdLying(entries, duration, poseFn, ctx)
	step(duration, function(alpha, _, elapsed)
		if ctx.Maid._clean then
			return false
		end
		local amp = (1 - alpha) * 0.16
		local jitter = CFrame.new(rand(-amp, amp), rand(-amp, amp), rand(-amp, amp))
			* CFrame.Angles(rand(-amp, amp) * 0.3, rand(-amp, amp) * 0.3, rand(-amp, amp) * 0.3)
		local rootCF = poseFn(elapsed) * jitter
		local pulse = 0.5 + 0.5 * math.sin(elapsed * 30)
		for _, e in ipairs(entries) do
			e.Part.CFrame = rootCF * e.Offset
			e.Part.Color = lerpColor(C.GlowHot, C.GlowWhite, pulse)
		end
	end)
end

-- Se levanta pivotando en los pies (poseFn recibe alpha 0..1)
function Remains.rise(entries, duration, poseFn, ctx)
	step(duration, function(alpha)
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
	step(duration, function(alpha)
		if ctx.Maid._clean then
			return false
		end
		local k = Ease.inOutQuad(alpha)
		for _, e in ipairs(entries) do
			local p = e.Part
			p.CFrame = poseCF * e.Offset
			p.Color = lerpColor(C.GlowCore, e.OrigColor, k)
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
	local folder = subfolder("Pulse", nil)
	local p = ballPart("PulseFlash", color or C.GlowWhite, Enum.Material.Neon, 0.25,
		Vector3.new(1, 1, 1) * scale * 0.4, position, folder)
	tween(p, 0.28, { Size = Vector3.new(1, 1, 1) * scale * 2.2, Transparency = 1 }, Enum.EasingStyle.Quart)
	local att = make("Attachment", nil, p)
	local em = FX.emitter(att, FX.Presets.Sparks())
	em.Speed = NumberRange.new(10, 26)
	em:Emit(22)
	task.delay(1.2, function()
		folder:Destroy()
	end)
end

----------------------------------------------------------------------
-- ROPA POR ETAPAS
-- Primero piel, después pantalones, al final la camisa. Solo en tu cliente.
----------------------------------------------------------------------
local Clothing = {}

function Clothing.strip(character)
	local removed = {}
	if not CONFIG.Clothes.StripOnRegen then
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

----------------------------------------------------------------------
-- CONTROLADOR (secuencia de regeneración, todo en tu cliente)
----------------------------------------------------------------------
local Controller = {}
Controller.Active = {}        -- [character] = estado S
Controller.CooldownUntil = 0

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

	-- El cuerpo real (oculto) no debe empujar a los restos
	local bodyParts = {}
	for _, d in ipairs(S.Character:GetDescendants()) do
		if d:IsA("BasePart") and d ~= S.Root then
			table.insert(bodyParts, d)
		end
	end
	S.Maid:Give(RunService.Stepped:Connect(function()
		for _, part in ipairs(bodyParts) do
			if part.Parent and part.CanCollide then
				part.CanCollide = false
			end
		end
	end))
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
	end
	if S.Root and S.Root.Parent then
		S.Root.Anchored = saved and saved.Anchored or false
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
	Controller.Active[S.Character] = nil
	Controller.CooldownUntil = os.clock() + CONFIG.Cooldown
	-- si la secuencia se cortó a medias, devuelve la cámara
	if Director.Active and not Director.Releasing then
		Director.release(Director.RootPos)
	end
end

-- Llamaradas en el suelo cuando el cuerpo empieza a levantarse
local function riseFlames(position)
	local folder = subfolder("RiseFlames", nil)
	local anchor = FX.anchorPart(position + Vector3.new(0, 0.6, 0), "RiseAnchor", folder)
	local att = make("Attachment", nil, anchor)
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
	local character = S.Character
	local root = S.Root
	local humanoid = S.Humanoid

	local rootCF = root.CFrame
	local groundPos = findGround(rootCF.Position, character)
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
	local faceUp = chance(0.4)
	local lieTheta = faceUp and (math.pi / 2) or (-math.pi / 2)

	-- Pose del cuerpo: theta = inclinación sobre los pies (0 = de pie, ±90 = tumbado)
	local function poseAt(theta)
		local lift = 0.65 * math.abs(math.sin(theta))
		return CFrame.new(groundPos + Vector3.new(0, lift, 0)) * yawCF * CFrame.Angles(theta, 0, 0) * CFrame.new(0, standH, 0)
	end

	--------------------------------------------------------------------------
	-- FASE 0: flash psicodélico + tinta
	--------------------------------------------------------------------------
	Controller.freeze(S)
	Director.prepare(rootCF.Position)
	Screen.portalFlash(v.PortalFlash)
	playSound(root, CONFIG.Sounds.Portal, 1, 1, 100)
	if not pause(S, v.PortalFlash) then return end
	Screen.inkBurst(v.InkBurst)
	if not pause(S, math.max(0, v.ExplosionDelay - v.PortalFlash)) then return end

	--------------------------------------------------------------------------
	-- FASE 1: explosión, restos volando, sangre, rayos de colores
	--------------------------------------------------------------------------
	local folder = subfolder("Remains", S.Maid)
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
	Screen.blast()
	Shake.add(v.CameraShake, 1.3)
	Director.start(v.CameraMode, groundPos + Vector3.new(0, 1, 0), v.CameraTime)

	Blood.burst(groundPos, character, v.BloodBlast, 22, 0)
	Blood.puddle(groundPos, character, 1, 0.06)
	FX.rays(groundPos + Vector3.new(0, 0.9, 0), randomUnit(), v.RayDuration, v.RayLength, S.Maid)
	Blood.bleed(groundPos, character, v.FlightTime + v.SmolderTime + v.ReassembleTime * 0.4, v.BleedRate, S.Maid)

	Remains.launch(entries, origin, v)
	Remains.simulate(entries, v.FlightTime + v.SmolderTime, ctx)
	if not alive(S) then return end

	--------------------------------------------------------------------------
	-- FASE 2: las partes se juntan, el cuerpo se levanta
	--------------------------------------------------------------------------
	Remains.freeze(entries)
	Shake.add(0.35, 0.5)
	playSound(root, CONFIG.Sounds.Reform, 1, 1, 100)

	Remains.reassemble(entries, v.ReassembleTime, function()
		return poseAt(lieTheta)
	end, ctx)
	if not alive(S) then return end

	Remains.holdLying(entries, v.LieTime, function()
		return poseAt(lieTheta)
	end, ctx)
	if not alive(S) then return end

	riseFlames(groundPos)
	Shake.add(0.5, 0.6)
	playSound(root, CONFIG.Sounds.Rise, 1, 1, 100)
	Remains.rise(entries, v.RiseTime, function(a)
		return poseAt(lerp(lieTheta, 0, Ease.outBack(a)))
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
	Director.release(standCF.Position)
	FX.tail(character, v.TailTime)
	playSound(root, CONFIG.Sounds.Fire, 0.8, 1, 80)

	task.delay(0.2, function()
		Controller.release(S)
	end)

	if not pause(S, v.PantsDelay) then return end
	Clothing.restoreKind(character, S.Removed, { "Pants" })
	if CONFIG.Clothes.PulseOnReturn then
		Remains.flashPulse(root.Position - Vector3.new(0, 1.5, 0), 2.6, C.GlowHot)
	end

	if not pause(S, math.max(0, v.ShirtDelay - v.PantsDelay)) then return end
	Clothing.restoreKind(character, S.Removed, { "Shirt", "ShirtGraphic" })
	if CONFIG.Clothes.PulseOnReturn then
		Remains.flashPulse(root.Position + Vector3.new(0, 0.8, 0), 3.2)
	end

	pause(S, 0.4)
end

-- Punto de entrada. reason: "manual" | "lethal"
function Controller.regenerate(character, reason)
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
	if reason ~= "lethal" and os.clock() < Controller.CooldownUntil then
		return false
	end

	local S = {
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Maid = Maid.new(),
		Variant = currentVariant(),
		Hidden = {},
		Removed = {},
		Reason = reason,
	}
	Controller.Active[character] = S

	S.Maid:Give(character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			S.Maid:Clean()
		end
	end))

	task.spawn(function()
		local ok, err = pcall(Controller.run, S)
		if not ok then
			warn("[RickPrime] error en la secuencia: " .. tostring(err))
		end
		Controller.cleanup(S)
	end)
	return true
end

----------------------------------------------------------------------
-- PERSONAJE
----------------------------------------------------------------------
local activeCleanup = nil

local function setupCharacter(char)
	if activeCleanup then
		activeCleanup()
	end

	local humanoid = char:WaitForChild("Humanoid", 15)
	local root = char:WaitForChild("HumanoidRootPart", 15)
	if not humanoid or not root then
		return
	end

	local conns = {}
	local alive_ = true

	if CONFIG.OnLethalDamage then
		-- Sin estado "Dead" el personaje se queda con 0 de vida y lo regeneramos.
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end)
		table.insert(conns, humanoid.HealthChanged:Connect(function(health)
			if health <= 0 and not Controller.Active[char] then
				Controller.regenerate(char, "lethal")
			end
		end))
		if humanoid.Health <= 0 then
			Controller.regenerate(char, "lethal")
		end

		if CONFIG.RescueFromVoid then
			task.spawn(function()
				local lastSafe = root.CFrame
				local limit = Workspace.FallenPartsDestroyHeight + CONFIG.VoidMargin
				while alive_ and char.Parent and root.Parent do
					task.wait(0.25)
					local y = root.Position.Y
					if humanoid.FloorMaterial ~= Enum.Material.Air and y > limit + 40 then
						lastSafe = root.CFrame
					elseif y < limit and not Controller.Active[char] then
						root.AssemblyLinearVelocity = Vector3.zero
						root.CFrame = lastSafe + Vector3.new(0, 2, 0)
						Controller.regenerate(char, "lethal")
					end
				end
			end)
		end
	end

	activeCleanup = function()
		alive_ = false
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		local S = Controller.Active[char]
		if S then
			S.Maid:Clean()
		end
		activeCleanup = nil
	end
end

player.CharacterAdded:Connect(setupCharacter)
player.CharacterRemoving:Connect(function()
	if activeCleanup then
		activeCleanup()
	end
end)

----------------------------------------------------------------------
-- INPUT (tecla H, botón táctil en móvil, botón Y en mando)
----------------------------------------------------------------------
local function onRegen(_, state)
	if state == Enum.UserInputState.Begin then
		local char = player.Character
		if char then
			Controller.regenerate(char, "manual")
		end
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("RickPrimeRegen", onRegen, true, CONFIG.TriggerKey, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("RickPrimeRegen", "REGEN")
ContextActionService:SetPosition("RickPrimeRegen", UDim2.new(1, -90, 1, -240))

if player.Character then
	task.spawn(setupCharacter, player.Character)
end
