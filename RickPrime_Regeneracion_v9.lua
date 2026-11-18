--!nonstrict
-- ============================================================================
-- RICK PRIME REGENERATION v9  (script NUEVO e independiente | LocalScript / Executor)
-- Reproduce los 3 videos: miembro cortado (brazo / pierna) y muerte completa con regeneracion.
--
-- CONTROLES:  Z = brazo | X = pierna | C = todos los miembros | V = morir y regenerar | B = probar solo el levantarse
-- Botones circulares arrastrables (celular) + panel superior AUTO ON/OFF.
-- Todo es LOCAL (solo tu lo ves). Al morir de verdad reapareces EN EL MISMO LUGAR y se reproduce la regeneracion.
--
-- LINEA DE TIEMPO DE LA MUERTE (medida de los videos, segundos desde el destello):
--   0.00  destello turquesa -> rosa -> rojo + manchas negras, explosion de sangre, humo y fragmentos
--   0.00  los 4 miembros salen disparados como BLOQUES AMARILLOS; el cuerpo queda tirado cubierto de listones rojo/azul
--   1.00  los bloques de las piernas vuelan y quedan PARADOS; el torso (doblado hacia atras, cabeza abajo) levanta
--   ~2.2  latigazo del torso hasta quedar de pie; los bloques de los brazos vuelan a los hombros y abren en V
--   ~2.6  los brazos se "visten" (amarillo -> manga blanca); un poco despues las piernas (amarillo -> pantalon)
--   ~3.4  de pie, saliendo vapor; vuelve el control
--
-- NOTA: durante la secuencia de muerte quedas fijo en el sitio (~3.5 s). Los miembros sueltos si te dejan caminar.
-- Si algo no coincide con el video, ajusta CFG (arriba del todo).
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")

local jugador = Players.LocalPlayer

-- Anti-duplicado: si se ejecuta dos veces, limpia la copia anterior
local env = (getgenv and getgenv()) or _G
if env.RP9_LIMPIAR then
	pcall(env.RP9_LIMPIAR)
end

local conexiones = {}
local function con(senal, fn)
	local c = senal:Connect(fn)
	table.insert(conexiones, c)
	return c
end

-- ============================ CONFIGURACION ================================
local CFG = {
	-- Disparadores automaticos (panel AUTO)
	DamageToSever = 1, -- dano minimo para perder un miembro (sube a 10-15 para golpes fuertes)
	DamageCooldown = 0.8,
	FallToSever = true,
	FallSpeedToSever = 60, -- velocidad de caida (studs/s) que corta un miembro
	RegenOnRealDeath = true, -- al morir de verdad: reapareces en el mismo sitio y te regeneras

	-- Miembros
	LimbLinger = 1.6, -- miembro cortado tirado antes de regenerar
	LimbBloomTime = 0.9, -- listones saliendo del munon
	LimbFormTime = 0.4, -- el bloque amarillo crece sobre el munon
	ClothFadeTime = 0.7, -- amarillo -> ropa
	RightArmClothDelay = 0.4, -- el brazo derecho tarda mas en vestirse (se ve en los videos)

	-- Muerte
	DeathLinger = 1.0, -- cuerpo tirado antes de levantarse (videos: ~1.0 s)
	GetUpSpeed = 1, -- 1 = igual al video; 0.7 mas lento; 1.3 mas rapido
	GetUpLean = 5, -- grados de inclinacion hacia adelante al terminar de pararse
	GetUpArms = 1, -- apertura de los brazos en V (1 = video, 0 = quietos)
	GetUpArmsForward = 0, -- ajuste extra hacia adelante (grados)
	SteamTime = 2.6, -- segundos de vapor al terminar

	-- Colores (tomados de los fotogramas)
	YellowBlock = Color3.fromRGB(240, 234, 142),
	BloodColor = Color3.fromRGB(185, 18, 32),
	MeatColor = Color3.fromRGB(118, 22, 34),
	PuddleLife = 40,
	MaxPuddles = 200,

	Quality = 1, -- 0.6 si tu celular va lento
	CameraFx = true, -- destello de color al morir (NO mueve la camara)

	Sound = true,
	SfxVolume = 1,
	VoiceVolume = 1.4,
	-- IDs tomados de tu script de referencia (VERIFICAR si alguno no suena; si falla queda en silencio)
	Sounds = {
		tear = "rbxassetid://100892314541959", -- desgarro al morir / cortar
		print = "rbxassetid://84312631986360", -- bucle mientras regeneras
	},
	VoiceLines = {
		"rbxassetid://138925430725431",
		"rbxassetid://104144683858662",
	},
	TearOnLimbCut = false,
	VoiceOnLimbRegen = false,
}

local COLOR_FONDO = Color3.fromRGB(10, 10, 10)
local COLOR_ROJO = Color3.fromRGB(200, 20, 30)
local COLOR_VERDE = Color3.fromRGB(0, 200, 90)
local TAM_CIRCULO = 66
-- ===========================================================================

local autoActivo = true
local limpiado = false

local rng = Random.new()
local function rand(a, b)
	return rng:NextNumber(a, b)
end
local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Carpeta de efectos
do
	local old = workspace:FindFirstChild("RP9_FX")
	if old then
		old:Destroy()
	end
end
local fx = Instance.new("Folder")
fx.Name = "RP9_FX"
fx.Parent = workspace

--------------------------------------------------------------------------------
-- TICKER (un solo Heartbeat) y SCOPE (limpieza agrupada)
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
			warn("[RP9] " .. tostring(done))
			table.remove(list, i)
		elseif done then
			table.remove(list, i)
		end
	end
end)

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
	for i = #self.items, 1, -1 do
		local item = self.items[i]
		if typeof(item) == "Instance" then
			pcall(function()
				item:Destroy()
			end)
		elseif type(item) == "table" and item.Destroy then
			pcall(item.Destroy)
		end
	end
	self.items = {}
end

local function newPart(size, color, material)
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
local function groundAt(pos, up)
	local ignore = { fx }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ignore, pl.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	return workspace:Raycast(pos + Vector3.new(0, up or 3, 0), Vector3.new(0, -400, 0), rayParams)
end

--------------------------------------------------------------------------------
-- OCULTAR PARTES (local): registro que se reaplica cada cuadro
--------------------------------------------------------------------------------
local Hidden = {}
local function setHide(part, amount)
	if amount and amount > 0 then
		Hidden[part] = amount
	else
		Hidden[part] = nil
		pcall(function()
			part.LocalTransparencyModifier = 0
		end)
	end
end
pcall(function()
	RunService:BindToRenderStep("RP9_Hide", Enum.RenderPriority.Last.Value, function()
		for p, a in pairs(Hidden) do
			if p.Parent then
				p.LocalTransparencyModifier = a
			else
				Hidden[p] = nil
			end
		end
	end)
end)

-- Interpola el ocultamiento de una lista de partes (from -> to) tras 'delay'
local function fadeHidden(parts, from, to, dur, delay, onDone)
	local t0 = os.clock() + (delay or 0)
	Ticker.add(function()
		local a = math.clamp((os.clock() - t0) / math.max(dur, 0.01), 0, 1)
		local v = from + (to - from) * a
		for _, p in ipairs(parts) do
			if p.Parent then
				setHide(p, v)
			end
		end
		if a >= 1 then
			if onDone then
				onDone()
			end
			return true
		end
		return false
	end)
end

--------------------------------------------------------------------------------
-- EFECTOS DE PANTALLA: destello turquesa -> rosa -> rojo + manchas negras
--------------------------------------------------------------------------------
local grade = Instance.new("ColorCorrectionEffect")
grade.Enabled = false
grade.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting
local WHITE = Color3.new(1, 1, 1)
local gradeToken = 0

local flashGui = Instance.new("ScreenGui")
flashGui.Name = "RP9_Flash"
flashGui.IgnoreGuiInset = true
flashGui.ResetOnSpawn = false
flashGui.DisplayOrder = 50

local function playGrade(steps)
	gradeToken += 1
	local token = gradeToken
	grade.Enabled = true
	blur.Enabled = true
	task.spawn(function()
		for _, s in ipairs(steps) do
			if token ~= gradeToken or limpiado then
				return
			end
			local info = TweenInfo.new(s.t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(grade, info, { TintColor = s.tint, Saturation = s.sat or 0, Brightness = s.bri or 0 }):Play()
			TweenService:Create(blur, info, { Size = s.blur or 0 }):Play()
			task.wait(s.t)
		end
		if token == gradeToken and not limpiado then
			grade.Enabled = false
			blur.Enabled = false
		end
	end)
end

local CamFx = {}
function CamFx.death()
	if not CFG.CameraFx then
		return
	end
	playGrade({
		{ t = 0.10, tint = Color3.fromRGB(40, 255, 230), sat = 1.5, bri = 0.2, blur = 26 },
		{ t = 0.12, tint = Color3.fromRGB(255, 150, 210), sat = 1, bri = 0.1, blur = 30 },
		{ t = 0.12, tint = Color3.fromRGB(190, 20, 25), sat = 0, bri = -0.08, blur = 22 },
		{ t = 0.65, tint = WHITE, sat = 0, bri = 0, blur = 0 },
	})
	-- manchas negras sobre la pantalla (se ven en el fotograma del destello)
	pcall(function()
		if not flashGui.Parent then
			flashGui.Parent = jugador:FindFirstChildOfClass("PlayerGui")
		end
		for _ = 1, 16 do
			local f = Instance.new("Frame")
			local d = math.random(30, 170)
			f.Size = UDim2.fromOffset(d, d)
			f.Position = UDim2.fromScale(rand(0.05, 0.95), rand(0.1, 0.9))
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BackgroundColor3 = Color3.fromRGB(8, 14, 16)
			f.BackgroundTransparency = rand(0.1, 0.3)
			f.BorderSizePixel = 0
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
			f.Parent = flashGui
			TweenService:Create(f, TweenInfo.new(rand(0.3, 0.6), Enum.EasingStyle.Quad), {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(d * 1.4, d * 1.4),
			}):Play()
			Debris:AddItem(f, 0.8)
		end
	end)
end

function CamFx.sever()
	if not CFG.CameraFx then
		return
	end
	playGrade({
		{ t = 0.06, tint = Color3.fromRGB(255, 110, 110), sat = 0.3, bri = 0.08, blur = 6 },
		{ t = 0.30, tint = WHITE, sat = 0, bri = 0, blur = 0 },
	})
end

--------------------------------------------------------------------------------
-- FX: humo, nube de sangre, brillo rojo, fragmentos negros, vapor
--------------------------------------------------------------------------------
local Fx = {}
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function makeEmitter(parent, color, size0, size1, transp0, life, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEX
	e.Color = ColorSequence.new(color)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, transp0), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Lifetime = NumberRange.new(life * 0.7, life * 1.3)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = 0
	e.Parent = parent
	return e
end

local function burst(pos, color, size0, size1, count, speed, life, transp0)
	local a = newPart(Vector3.one * 0.2, color)
	a.Transparency = 1
	a.CFrame = CFrame.new(pos)
	a.Parent = fx
	local e = makeEmitter(a, color, size0, size1, transp0 or 0.3, life, speed)
	e:Emit(math.max(1, math.floor(count * CFG.Quality)))
	Debris:AddItem(a, life * 1.5 + 0.6)
end

function Fx.puff(pos, scale, count)
	burst(pos, Color3.fromRGB(225, 225, 230), 3 * scale, 9 * scale, count or 14, 10 * scale, 1.2, 0.35)
end
function Fx.bloodCloud(pos, scale)
	burst(pos, Color3.fromRGB(140, 8, 18), 4 * scale, 12 * scale, 60, 22 * scale, 1.3, 0.2)
	burst(pos, Color3.fromRGB(60, 4, 10), 2 * scale, 7 * scale, 30, 26 * scale, 1.0, 0.25)
end
function Fx.glow(pos, color, size, duration)
	local p = newPart(Vector3.one * size * 0.3, color, Enum.Material.Neon)
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.2
	p.CFrame = CFrame.new(pos)
	p.Parent = fx
	TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, duration + 0.1)
end
-- fragmentos negros con fisica
function Fx.shards(origin, count)
	for _ = 1, math.max(4, math.floor(count * CFG.Quality)) do
		local s = rand(0.25, 0.6)
		local p = newPart(Vector3.new(s, s * rand(0.5, 1.2), s), Color3.fromRGB(18, 18, 22), Enum.Material.Slate)
		p.Anchored = false
		p.CanCollide = true
		p.CFrame = CFrame.new(origin) * CFrame.Angles(rand(0, 6), rand(0, 6), rand(0, 6))
		p.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.6, 0.2, 1, 1)
		p.Parent = fx
		p.AssemblyLinearVelocity = Vector3.new(rand(-22, 22), rand(14, 38), rand(-22, 22))
		p.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
		Debris:AddItem(p, rand(3, 5))
	end
end
-- vapor continuo sobre una parte; devuelve el emisor
function Fx.steam(part, duration)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE_TEX
	e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 2.8) })
	e.Lifetime = NumberRange.new(0.9, 1.5)
	e.Speed = NumberRange.new(1.5, 3.5)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(25, 25)
	e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Rate = 16 * CFG.Quality
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = part
	task.delay(duration, function()
		if e.Parent then
			e.Enabled = false
			Debris:AddItem(e, 2)
		end
	end)
	return e
end

--------------------------------------------------------------------------------
-- SONIDO (si un id no carga, queda en silencio)
--------------------------------------------------------------------------------
local Sfx = { voiceLast = nil }
function Sfx.play(slot, pos, volume, pitch, looped)
	if not CFG.Sound then
		return nil
	end
	local id = CFG.Sounds[slot]
	if not id or id == "" then
		return nil
	end
	local holder = newPart(Vector3.one * 0.2, WHITE)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(pos)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = (volume or 1) * CFG.SfxVolume
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 140
	s.Looped = looped or false
	s.Parent = holder
	holder.Parent = fx
	pcall(function()
		s:Play()
	end)
	if not looped then
		Debris:AddItem(holder, 8)
	end
	return holder
end
function Sfx.voice(pos)
	if not CFG.Sound or #CFG.VoiceLines == 0 then
		return
	end
	local list = {}
	for _, id in ipairs(CFG.VoiceLines) do
		if id ~= Sfx.voiceLast then
			table.insert(list, id)
		end
	end
	if #list == 0 then
		list = CFG.VoiceLines
	end
	local id = list[rng:NextInteger(1, #list)]
	Sfx.voiceLast = id
	local holder = newPart(Vector3.one * 0.2, WHITE)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(pos)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = CFG.VoiceVolume
	s.RollOffMaxDistance = 140
	s.Parent = holder
	holder.Parent = fx
	pcall(function()
		s:Play()
	end)
	Debris:AddItem(holder, 8)
end

--------------------------------------------------------------------------------
-- SANGRE: charcos planos (discos rojos) que quedan en el piso
--------------------------------------------------------------------------------
local Blood = { list = {}, layer = 0 }
function Blood.disc(pos, normal, diameter)
	normal = normal or Vector3.yAxis
	local ref = (math.abs(normal.X) < 0.9) and Vector3.xAxis or Vector3.zAxis
	local tangent = normal:Cross(ref).Unit
	Blood.layer = (Blood.layer + 1) % 40
	local p = newPart(Vector3.new(0.05, diameter, diameter), CFG.BloodColor)
	p.Shape = Enum.PartType.Cylinder
	p.Reflectance = 0.04
	p.CFrame = CFrame.fromMatrix(pos + normal * (0.03 + Blood.layer * 0.002), normal, tangent)
	p.Parent = fx
	table.insert(Blood.list, p)
	if #Blood.list > CFG.MaxPuddles then
		local old = table.remove(Blood.list, 1)
		if old then
			old:Destroy()
		end
	end
	Debris:AddItem(p, CFG.PuddleLife)
	return p
end
function Blood.at(xz, y, diameter)
	local r = groundAt(Vector3.new(xz.X, y, xz.Z), 4)
	if r then
		Blood.disc(r.Position, r.Normal, diameter)
	end
end
function Blood.splatter(origin, count, radius, dmin, dmax)
	count = math.max(3, math.floor(count * CFG.Quality))
	for _ = 1, count do
		local a = rand(0, 6.283)
		local d = radius * math.sqrt(rng:NextNumber())
		Blood.at(origin + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), origin.Y, rand(dmin, dmax))
	end
end
function Blood.clear()
	for _, p in ipairs(Blood.list) do
		p:Destroy()
	end
	Blood.list = {}
end

--------------------------------------------------------------------------------
-- LISTONES (rojo / azul) que se retuercen: salen del munon o cubren el cuerpo tirado
--------------------------------------------------------------------------------
local RIBBON_COLORS = {
	Color3.fromRGB(168, 20, 40),
	Color3.fromRGB(104, 8, 28),
	Color3.fromRGB(190, 32, 52),
	Color3.fromRGB(40, 70, 235),
}

-- o = { base=fn->CFrame (el -Z apunta hacia donde salen), count, length, cone, width, thick, droop, floorY, duration }
local function spawnTendrils(o)
	local nSeg = math.max(5, math.floor(9 * CFG.Quality + 0.5))
	local count = math.max(3, math.floor(o.count * CFG.Quality + 0.5))
	local folder = Instance.new("Folder")
	folder.Name = "RP9_Tendrils"
	folder.Parent = fx

	local ribbons, parts = {}, {}
	for i = 1, count do
		local theta = o.cone * (rng:NextNumber() ^ 0.8)
		local phi = rand(0, 6.283)
		local dir = Vector3.new(math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), -math.cos(theta))
		local ref = (math.abs(dir.Y) < 0.9) and Vector3.yAxis or Vector3.xAxis
		local u = dir:Cross(ref).Unit
		local v = dir:Cross(u).Unit
		local color = RIBBON_COLORS[(i - 1) % #RIBBON_COLORS + 1]
		local r = {
			dir = dir, u = u, v = v,
			length = o.length * rand(0.7, 1.25),
			freq = rand(7, 11), amp = rand(0.3, 0.65), speed = rand(5, 9), phase = rand(0, 6.28),
			width = o.width * rand(0.85, 1.25), segs = {},
		}
		for s = 1, nSeg do
			local seg = newPart(Vector3.new(0.2, 0.08, 0.2), color)
			seg.Reflectance = 0.06
			seg.Parent = folder
			r.segs[s] = seg
			parts[#parts + 1] = seg
		end
		ribbons[i] = r
	end

	local handle = {}
	local t, stopAt, stopFade = 0, nil, 1
	function handle.Stop(fade)
		if not stopAt then
			stopFade = math.max(fade or 0.3, 0.01)
			stopAt = t
		end
	end
	handle.Destroy = function()
		handle.Stop(0.1)
	end

	local function point(r, s, g, tt, baseCF)
		local along = r.dir * (s * r.length * g)
		local w = r.amp * s * g
		local off = r.u * (math.sin(s * r.freq + tt * r.speed + r.phase) * w)
			+ r.v * (math.cos(s * r.freq * 0.8 + tt * r.speed * 1.2 + r.phase) * w)
		local p = baseCF:PointToWorldSpace(along + off) - Vector3.new(0, (o.droop or 0) * s * s * g, 0)
		if o.floorY then
			p = Vector3.new(p.X, math.max(p.Y, o.floorY + 0.1), p.Z)
		end
		return p
	end

	local cfs = table.create(#parts)
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
		local gStop = stopAt and math.clamp(1 - (t - stopAt) / stopFade, 0, 1) or 1
		local g = gIn * gStop

		local n = 0
		for _, r in ipairs(ribbons) do
			local prev = point(r, 0, g, t, baseCF)
			for i = 1, nSeg do
				local s = i / nSeg
				local cur = point(r, s, g, t, baseCF)
				local seg = r.segs[i]
				local len = (cur - prev).Magnitude
				local taper = 1 - 0.5 * s
				n += 1
				if len < 0.001 then
					seg.Size = Vector3.new(r.width * taper, o.thick, 0.02)
					cfs[n] = CFrame.new(prev)
				else
					seg.Size = Vector3.new(r.width * taper, o.thick, len + 0.03)
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
-- RIG: grupos de partes (R6 / R15), clon fantasma, pose de reposo
--------------------------------------------------------------------------------
local Rig = {}
Rig.LIMBS = { "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

function Rig.groups(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	local groups = {}
	local function add(name, names)
		local list = {}
		for _, n in ipairs(names) do
			local p = model:FindFirstChild(n)
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

function Rig.length(parts)
	local total = 0
	for _, p in ipairs(parts) do
		total += p.Size.Y
	end
	return total
end

function Rig.allParts(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			list[#list + 1] = d
		end
	end
	return list
end

-- Clon "fantasma" del personaje: la raiz anclada, el resto sigue a las articulaciones (Motor6D)
local function makeGhost(char)
	local was = char.Archivable
	char.Archivable = true
	local ok, g = pcall(function()
		return char:Clone()
	end)
	char.Archivable = was
	if not ok or not g then
		return nil
	end
	g.Name = "RP9_Ghost"
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ForceField")
			or d:IsA("Highlight") or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") or d:IsA("ParticleEmitter")
			or d:IsA("Tool") then
			d:Destroy()
		end
	end
	local hum = g:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.RequiresNeck = false
			hum.BreakJointsOnDeath = false
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.AutoRotate = false
			hum.PlatformStand = true
		end)
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		end)
		local an = hum:FindFirstChildOfClass("Animator")
		if an then
			an:Destroy()
		end
	end
	for _, d in ipairs(g:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = (d.Name == "HumanoidRootPart")
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	return g
end

-- Contexto del fantasma: mapa de articulaciones y pose de reposo relativa a la raiz
local function makeGhostCtx(ghost)
	local ctx = { model = ghost, jointOf = {}, rel = {} }
	ctx.root = ghost:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 then
			ctx.jointOf[d.Part1] = d
		end
	end
	ctx.groups = Rig.groups(ghost)
	return ctx
end

local function restRel(ctx, part)
	if part == ctx.root then
		return CFrame.identity
	end
	local c = ctx.rel[part]
	if c then
		return c
	end
	local m = ctx.jointOf[part]
	local r = CFrame.identity
	if m and m.Part0 then
		r = restRel(ctx, m.Part0) * m.C0 * m.C1:Inverse()
	end
	ctx.rel[part] = r
	return r
end

-- Gira el brazo del fantasma sobre el hombro (ax = adelante, az = abrir hacia el lado), en ejes del torso
local function poseArm(ctx, groupName, rootCF, ax, az)
	local list = ctx.groups[groupName]
	if not list then
		return
	end
	local m = ctx.jointOf[list[1]]
	if not m or not m.Part0 then
		return
	end
	local P0 = rootCF * restRel(ctx, m.Part0)
	local pivotCF = P0 * m.C0
	local S = pivotCF.Position
	local D0 = pivotCF * m.C1:Inverse()
	local rot = P0.Rotation
	local R = CFrame.new(S) * rot * CFrame.Angles(ax, 0, az) * rot:Inverse() * CFrame.new(-S)
	m.Transform = pivotCF:Inverse() * (R * D0) * m.C1
end

local function lowestY(parts, rootCF, ctx)
	local low = math.huge
	for _, p in ipairs(parts) do
		local cf = rootCF * restRel(ctx, p)
		local s = p.Size / 2
		for sx = -1, 1, 2 do
			for sy = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local y = cf:PointToWorldSpace(Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)).Y
					if y < low then
						low = y
					end
				end
			end
		end
	end
	return low
end

-- Curva cubica (Catmull-Rom) por claves {t, valor}
local function makeCurve(keys)
	local n = #keys
	local m = {}
	for i = 1, n do
		local a = keys[math.max(i - 1, 1)]
		local b = keys[math.min(i + 1, n)]
		local dt = b[1] - a[1]
		m[i] = (dt > 0) and ((b[2] - a[2]) / dt) or 0
	end
	return function(t)
		if t <= keys[1][1] then
			return keys[1][2]
		end
		if t >= keys[n][1] then
			return keys[n][2]
		end
		for i = 1, n - 1 do
			local k0, k1 = keys[i], keys[i + 1]
			if t <= k1[1] then
				local h = k1[1] - k0[1]
				local s = (t - k0[1]) / h
				local s2, s3 = s * s, s * s * s
				return (2 * s3 - 3 * s2 + 1) * k0[2] + (s3 - 2 * s2 + s) * h * m[i]
					+ (-2 * s3 + 3 * s2) * k1[2] + (s3 - s2) * h * m[i + 1]
			end
		end
		return keys[n][2]
	end
end

--------------------------------------------------------------------------------
-- BLOQUES AMARILLOS (los miembros sueltos): fisica real hasta que vuelan a su sitio
--------------------------------------------------------------------------------
local Chunks = {}
local function ignoreChar(part, char)
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

-- parts = partes reales del miembro; devuelve lista { part=bloque, srcName=nombre }
function Chunks.make(parts, fromPos, power, char)
	local list = {}
	local primary
	for _, src in ipairs(parts) do
		local p = newPart(src.Size, CFG.YellowBlock)
		p.Name = "Chunk"
		p.Anchored = false
		p.CanCollide = true
		p.CFrame = src.CFrame
		p.CastShadow = true
		p.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.8, 0.1, 1, 1)
		ignoreChar(p, char)
		p.Parent = fx
		list[#list + 1] = { part = p, srcName = src.Name }
		if not primary then
			primary = p
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = p
			w.Parent = primary
		end
	end
	if primary then
		local dir = primary.Position - fromPos
		dir = Vector3.new(dir.X, 0, dir.Z)
		if dir.Magnitude < 0.2 then
			dir = Vector3.new(rand(-1, 1), 0, rand(-1, 1))
		end
		dir = dir.Unit
		primary.AssemblyLinearVelocity = dir * rand(8, 16) * power + Vector3.new(rand(-3, 3), rand(18, 28) * power, rand(-3, 3))
		primary.AssemblyAngularVelocity = Vector3.new(rand(-9, 9), rand(-9, 9), rand(-9, 9))
	end
	return list
end

-- congela los bloques para animarlos a mano
function Chunks.detach(list)
	for _, e in ipairs(list) do
		for _, d in ipairs(e.part:GetChildren()) do
			if d:IsA("WeldConstraint") or d:IsA("NoCollisionConstraint") then
				d:Destroy()
			end
		end
		e.part.AssemblyLinearVelocity = Vector3.zero
		e.part.AssemblyAngularVelocity = Vector3.zero
		e.part.Anchored = true
		e.part.CanCollide = false
	end
end

function Chunks.destroy(list)
	for _, e in ipairs(list or {}) do
		if e.part and e.part.Parent then
			e.part:Destroy()
		end
	end
end

-- el bloque se encoge con un humito
function Chunks.shrink(list)
	if not list or #list == 0 then
		return
	end
	local pos = list[1].part.Position
	Chunks.detach(list)
	for _, e in ipairs(list) do
		TweenService:Create(e.part, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = e.part.Size * 0.1,
			Transparency = 1,
		}):Play()
		Debris:AddItem(e.part, 0.5)
	end
	Fx.puff(pos, 0.5, 8)
end

--------------------------------------------------------------------------------
-- ESTADO
--------------------------------------------------------------------------------
local State = { busy = false, token = 0, limbs = {}, lastSever = 0, deathCF = nil }

local function clearLimbs()
	for _, L in pairs(State.limbs) do
		L.cancelled = true
		Chunks.destroy(L.chunks)
	end
	State.limbs = {}
end

local function charParts()
	local char = jugador.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return char, hum, root
end

--------------------------------------------------------------------------------
-- MIEMBRO CORTADO: sale volando como bloque amarillo, luego se regenera con listones
--------------------------------------------------------------------------------
local function limbBase(part)
	return function()
		local cf = part.CFrame
		local top = cf:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2, 0))
		return CFrame.lookAt(top, top - cf.UpVector, cf.RightVector)
	end
end

local regenLimb

local function severLimb(gname)
	local char, hum, root = charParts()
	if not (char and hum and root) or hum.Health <= 0 or State.busy or State.limbs[gname] then
		return false
	end
	local parts = Rig.groups(char)[gname]
	if not parts then
		return false
	end
	local socket = limbBase(parts[1])()
	for _, p in ipairs(parts) do
		setHide(p, 1)
	end
	local chunks = Chunks.make(parts, root.Position, 0.85, char)
	State.limbs[gname] = { parts = parts, chunks = chunks, name = gname }

	CamFx.sever()
	Fx.bloodCloud(socket.Position, 0.25)
	Blood.splatter(socket.Position, 6, 3.5, 0.6, 1.8)
	if CFG.TearOnLimbCut then
		Sfx.play("tear", socket.Position, 0.9, rand(0.95, 1.1))
	end
	-- charco bajo el bloque cuando cae
	task.delay(0.7, function()
		for _, e in ipairs(chunks) do
			if e.part.Parent then
				Blood.at(e.part.Position, e.part.Position.Y + 1, rand(1.4, 2.6))
			end
		end
	end)
	task.delay(CFG.LimbLinger, function()
		if not limpiado then
			regenLimb(gname)
		end
	end)
	return true
end

regenLimb = function(gname)
	local L = State.limbs[gname]
	if not L or L.cancelled or L.busy then
		return
	end
	L.busy = true
	local parts = L.parts
	local first = parts[1]
	if not first or not first.Parent then
		State.limbs[gname] = nil
		Chunks.destroy(L.chunks)
		return
	end
	local socketPos = limbBase(first)().Position

	local tend = spawnTendrils({
		base = limbBase(first), count = 14, length = Rig.length(parts) * 0.9, cone = 0.55,
		width = 0.28, thick = 0.12, droop = 0.5,
	})
	local snd = Sfx.play("print", socketPos, 0.8, 1, true)
	Fx.puff(socketPos, 0.5, 8)

	-- bloques que crecen sobre el munon
	local ghosts = {}
	for _, src in ipairs(parts) do
		local g = newPart(src.Size * 0.15, CFG.YellowBlock)
		g.CastShadow = true
		g.CFrame = src.CFrame
		g.Parent = fx
		ghosts[#ghosts + 1] = { part = g, src = src }
	end
	local t0 = os.clock()
	local formStart = math.max(CFG.LimbBloomTime - CFG.LimbFormTime, 0.1)
	local stopped = false
	Ticker.add(function()
		local t = os.clock() - t0
		local a = ease((t - formStart) / CFG.LimbFormTime)
		for _, it in ipairs(ghosts) do
			if it.part.Parent and it.src.Parent then
				it.part.CFrame = it.src.CFrame
				it.part.Size = it.src.Size * ((0.15 + 0.85 * a) * 1.03)
			end
		end
		if t >= CFG.LimbBloomTime and not stopped then
			stopped = true
			tend.Stop(0.15)
			if snd then
				snd:Destroy()
			end
			Chunks.shrink(L.chunks)
			-- la ropa se "viste": amarillo -> manga / pantalon
			local delay = (gname == "RightArm") and CFG.RightArmClothDelay or 0
			fadeHidden(parts, 1, 0, CFG.ClothFadeTime, delay, function()
				Fx.puff(socketPos, 0.4, 6)
				if CFG.VoiceOnLimbRegen then
					Sfx.voice(socketPos)
				end
				State.limbs[gname] = nil
			end)
			local tf0 = os.clock() + delay
			Ticker.add(function()
				local k = math.clamp((os.clock() - tf0) / CFG.ClothFadeTime, 0, 1)
				for _, it in ipairs(ghosts) do
					if it.part.Parent then
						if it.src.Parent then
							it.part.CFrame = it.src.CFrame
						end
						it.part.Transparency = k
					end
				end
				if k >= 1 then
					for _, it in ipairs(ghosts) do
						it.part:Destroy()
					end
					return true
				end
				return false
			end)
			-- vapor sobre el miembro
			Fx.steam(first, 1.6 + delay)
			return true
		end
		return false
	end)
end

--------------------------------------------------------------------------------
-- MUERTE COMPLETA
--------------------------------------------------------------------------------
-- Claves medidas (segundos desde que el torso empieza a levantarse, grados desde la vertical; + = hacia atras)
local function torsoCurve()
	local lean = CFG.GetUpLean
	return makeCurve({
		{ 0, 140 }, { 0.25, 128 }, { 0.45, 100 }, { 0.58, 70 }, { 0.70, 25 },
		{ 0.82, -lean * 2.4 }, { 1.0, -lean }, { 1.25, -lean * 0.9 }, { 1.7, -lean * 0.3 }, { 2.1, 0 },
	})
end
local armOpenRight = makeCurve({ { 0, 0 }, { 0.12, 135 }, { 0.30, 138 }, { 0.45, 85 }, { 0.60, 38 }, { 0.72, 50 }, { 0.90, 32 }, { 1.20, 10 }, { 1.5, 0 } })
local armOpenLeft = makeCurve({ { 0, 0 }, { 0.12, 160 }, { 0.30, 165 }, { 0.45, 95 }, { 0.60, 42 }, { 0.72, 54 }, { 0.90, 34 }, { 1.20, 10 }, { 1.5, 0 } })

local function deathBody(char, hum, root, opts, token, scope)
	local function alive()
		return token == State.token and char.Parent ~= nil and hum.Health > 0 and not limpiado
	end

	-- 1) Fijar el personaje real y ocultarlo
	local saved = {
		ws = hum.WalkSpeed, jp = hum.JumpPower, jh = hum.JumpHeight, ar = hum.AutoRotate,
		anch = root.Anchored, dist = hum.DisplayDistanceType,
	}
	local realParts = Rig.allParts(char)
	scope:Add({
		Destroy = function()
			for _, p in ipairs(realParts) do
				setHide(p, 0)
			end
			pcall(function()
				root.Anchored = saved.anch
				hum.WalkSpeed = saved.ws
				hum.JumpPower = saved.jp
				hum.JumpHeight = saved.jh
				hum.AutoRotate = saved.ar
				hum.DisplayDistanceType = saved.dist
			end)
		end,
	})
	pcall(function()
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.JumpHeight = 0
		hum.AutoRotate = false
	end)
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true

	-- 2) Datos de pie: suelo, altura, orientacion
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	local standH = (isR15 and hum.HipHeight or 2) + root.Size.Y / 2
	local ground = groundAt(root.Position, 2)
	local groundY = ground and ground.Position.Y or (root.Position.Y - standH)
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local standPos = Vector3.new(root.Position.X, groundY + standH, root.Position.Z)
	local standCF = CFrame.new(standPos) * CFrame.Angles(0, yaw, 0)
	local pivotPos = standCF:PointToWorldSpace(Vector3.new(0, -root.Size.Y / 2, 0))
	local P = CFrame.new(pivotPos) * standCF.Rotation -- marco de la cadera
	local center = root.Position

	local function bentCF(thetaDeg)
		return P * CFrame.Angles(math.rad(thetaDeg), 0, 0) * P:Inverse() * standCF
	end
	-- tirado de espalda, un poco detras de la cadera
	local back = standCF.Rotation:VectorToWorldSpace(Vector3.new(0, 0, 1.4))
	local lyingCF = CFrame.new(Vector3.new(standPos.X, groundY + 0.6, standPos.Z) + back)
		* CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.pi / 2, 0, 0)

	for _, p in ipairs(realParts) do
		setHide(p, 1)
	end

	-- 3) Fantasma (cadaver)
	local ghost = makeGhost(char)
	if not ghost then
		error("no se pudo clonar el personaje")
	end
	scope:Add(ghost)
	local ctx = makeGhostCtx(ghost)
	if not ctx.root then
		error("el clon no tiene HumanoidRootPart")
	end
	local gHeadList = ctx.groups.Head or {}
	local gTorsoList = ctx.groups.Torso or {}
	local clampParts = {}
	for _, p in ipairs(gHeadList) do
		clampParts[#clampParts + 1] = p
	end
	for _, p in ipairs(gTorsoList) do
		clampParts[#clampParts + 1] = p
	end
	-- tirado sin hundirse en el piso
	do
		local low0 = lowestY(clampParts, lyingCF, ctx)
		if low0 < groundY + 0.05 then
			lyingCF = lyingCF + Vector3.new(0, groundY + 0.05 - low0, 0)
		end
	end
	ctx.root.CFrame = lyingCF
	ghost.Parent = fx
	-- brazos y piernas del fantasma ocultos hasta que se "visten"
	local ghostLimbParts = {}
	for _, gn in ipairs(Rig.LIMBS) do
		ghostLimbParts[gn] = ctx.groups[gn] or {}
		for _, p in ipairs(ghostLimbParts[gn]) do
			setHide(p, 1)
		end
	end

	-- aspecto de cadaver: torso rojo carne, sin ropa
	local clothes, origColors = {}, {}
	local function corpseLook(on)
		if on then
			for _, d in ipairs(ghost:GetChildren()) do
				if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
					table.insert(clothes, d)
					d.Parent = nil
				end
			end
			for _, p in ipairs(gTorsoList) do
				origColors[p] = p.Color
				p.Color = CFG.MeatColor
			end
		else
			for _, d in ipairs(clothes) do
				d.Parent = ghost
			end
			clothes = {}
			for p, c in pairs(origColors) do
				p.Color = c
			end
			origColors = {}
		end
	end
	corpseLook(true)

	-- 4) Explosion
	local limbsData = {}
	for _, gn in ipairs(Rig.LIMBS) do
		local L = State.limbs[gn]
		if L then
			L.cancelled = true
			State.limbs[gn] = nil
		end
		if L and not L.busy then
			limbsData[gn] = L.chunks -- ya estaba tirado como bloque
		else
			local parts = Rig.groups(char)[gn]
			if parts then
				limbsData[gn] = Chunks.make(parts, center, opts.test and 0.35 or 1, char)
			end
		end
	end
	for _, list in pairs(limbsData) do
		scope:Add({ Destroy = function() Chunks.destroy(list) end })
	end
	-- (los bloques de miembros ya cortados estaban ocultos en el personaje real)

	if not opts.test then
		CamFx.death()
		Fx.glow(center, Color3.fromRGB(255, 40, 60), 14, 0.35)
		Fx.bloodCloud(center, 1)
		Fx.puff(center, 1.4, 30)
		Fx.shards(center, 22)
		Blood.splatter(Vector3.new(center.X, groundY, center.Z), 28, 9, 0.8, 3.6)
		Sfx.play("tear", center, 1.2, rand(0.95, 1.05))
		task.delay(0.7, function()
			for _, list in pairs(limbsData) do
				for _, e in ipairs(list) do
					if e.part.Parent then
						Blood.at(e.part.Position, e.part.Position.Y + 1, rand(1.6, 3.0))
					end
				end
			end
		end)
	end

	-- listones sobre el cuerpo tirado
	local gTorso = gTorsoList[1]
	local mass = spawnTendrils({
		base = function()
			local pos = ctx.root.Position + Vector3.new(0, 0.3, 0)
			return CFrame.fromMatrix(pos, Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis)
		end,
		count = 30, length = 3.0, cone = 1.25, width = 0.32, thick = 0.14, droop = 2.2, floorY = groundY,
	})
	scope:Add({ Destroy = function() mass.Stop(0.05) end })
	local printSnd = Sfx.play("print", center, 0.9, 1, true)
	scope:Add({ Destroy = function() if printSnd then printSnd:Destroy() end end })

	-- 5) Cuerpo tirado
	local linger = opts.test and 0.6 or CFG.DeathLinger
	local tL = os.clock()
	while os.clock() - tL < linger do
		if not alive() then
			return
		end
		task.wait()
	end
	if not alive() then
		return
	end

	-- 6) Levantarse
	local legTargets = {} -- { chunk, targetCF }
	local armChunks = {} -- { chunk, ghostPart }
	for _, gn in ipairs({ "LeftLeg", "RightLeg" }) do
		Chunks.detach(limbsData[gn] or {})
		for _, e in ipairs(limbsData[gn] or {}) do
			local gp = ghost:FindFirstChild(e.srcName, true)
			if gp then
				legTargets[#legTargets + 1] = { e = e, start = e.part.CFrame, target = standCF * restRel(ctx, gp), gp = gp, gn = gn }
			end
		end
	end
	for _, gn in ipairs({ "LeftArm", "RightArm" }) do
		Chunks.detach(limbsData[gn] or {})
		for _, e in ipairs(limbsData[gn] or {}) do
			local gp = ghost:FindFirstChild(e.srcName, true)
			if gp then
				armChunks[#armChunks + 1] = { e = e, start = nil, gp = gp, gn = gn }
			end
		end
	end

	local curve = torsoCurve()
	local FLY_LEG = 0.35 -- vuelo de las piernas y torso de tirado a doblado
	local speed = math.max(CFG.GetUpSpeed, 0.1)
	local g0 = os.clock()
	local state = { corpseOff = false, tendrilsOff = false, armsLaunched = false, armCloth = false, legCloth = false, steam = false, done = false }
	local armsAmount = CFG.GetUpArms
	local fwd = math.rad(CFG.GetUpArmsForward)

	Ticker.add(function()
		if not alive() then
			state.done = true
			return true
		end
		local G = (os.clock() - g0) * speed
		local w = G - FLY_LEG

		-- torso / cabeza (todo el fantasma gira sobre la cadera)
		local rootCF
		if G < FLY_LEG then
			rootCF = lyingCF:Lerp(bentCF(curve(0)), ease(G / FLY_LEG))
		else
			rootCF = bentCF(curve(w))
		end
		-- jamas hundido en el piso
		local low = lowestY(clampParts, rootCF, ctx)
		if low < groundY + 0.05 then
			rootCF = rootCF + Vector3.new(0, groundY + 0.05 - low, 0)
		end
		ctx.root.CFrame = rootCF

		-- cadaver -> cuerpo vestido (bajo los listones)
		if w >= 0.25 and not state.corpseOff then
			state.corpseOff = true
			corpseLook(false)
			Fx.puff(rootCF.Position, 0.7, 10)
		end
		if w >= 0.45 and not state.tendrilsOff then
			state.tendrilsOff = true
			mass.Stop(0.2)
			if printSnd then
				printSnd:Destroy()
			end
		end

		-- piernas: bloques vuelan y quedan PARADOS desde el inicio
		local a = ease(G / FLY_LEG)
		for _, it in ipairs(legTargets) do
			if it.e.part.Parent then
				local cf = it.start:Lerp(it.target, a) + Vector3.new(0, math.sin(math.pi * a) * 2.2, 0)
				it.e.part.CFrame = cf
				if a >= 1 then
					it.e.part.Size = it.gp.Size * 1.03
				end
			end
		end

		-- brazos: vuelan a los hombros y abren en V cuando el torso queda parado
		if w >= 0.25 then
			if not state.armsLaunched then
				state.armsLaunched = true
				for _, it in ipairs(armChunks) do
					it.start = it.e.part.CFrame
				end
			end
			local f = ease((w - 0.25) / 0.5)
			for _, it in ipairs(armChunks) do
				if it.e.part.Parent and it.gp.Parent then
					local tgt = it.gp.CFrame
					local cf = it.start:Lerp(tgt, f) + Vector3.new(0, math.sin(math.pi * f) * 1.6, 0)
					it.e.part.CFrame = cf
					if f >= 1 then
						it.e.part.Size = it.gp.Size * 1.03
					end
				end
			end
		end
		local wa = w - 0.8
		local aR = math.rad(armOpenRight(wa) * armsAmount)
		local aL = math.rad(armOpenLeft(wa) * armsAmount)
		local fR = (wa > 0) and (aR * 0.28 + fwd) or 0
		local fL = (wa > 0) and (aL * 0.28 + fwd) or 0
		poseArm(ctx, "RightArm", rootCF, fR, aR)
		poseArm(ctx, "LeftArm", rootCF, fL, -aL)

		-- vapor
		if w >= 0.8 and not state.steam then
			state.steam = true
			if gTorso then
				Fx.steam(gTorso, CFG.SteamTime)
			end
			for _, it in ipairs(legTargets) do
				if it.gn == "RightLeg" then
					Fx.steam(it.e.part, 1.2)
					break
				end
			end
		end

		-- ropa: brazos primero (amarillo -> manga), piernas despues (amarillo -> pantalon)
		local function cloth(gn, startW, delay)
			local k = math.clamp((w - startW - (delay or 0)) / CFG.ClothFadeTime, 0, 1)
			for _, p in ipairs(ghostLimbParts[gn]) do
				setHide(p, 1 - k)
			end
			local lst = limbsData[gn] or {}
			for _, e in ipairs(lst) do
				if e.part.Parent then
					e.part.Transparency = k
				end
			end
			return k
		end
		local kEnd = 0
		kEnd = math.max(kEnd, cloth("LeftArm", 0.9, 0))
		kEnd = math.max(kEnd, cloth("RightArm", 0.9, CFG.RightArmClothDelay))
		local kl = cloth("LeftLeg", 1.25, 0)
		local kr = cloth("RightLeg", 1.25, 0)
		-- una vez vestido, el fantasma vuelve a cubrir el bloque (los bloques ya estan transparentes)
		if w >= 2.1 then
			state.done = true
			return true
		end
		return false
	end)

	while not state.done do
		task.wait()
	end
	if not alive() then
		return
	end

	-- 7) Entrega: el personaje real aparece exactamente donde terminó el fantasma
	pcall(function()
		root.CFrame = standCF
	end)
	for _, p in ipairs(realParts) do
		setHide(p, 0)
	end
	Fx.puff(standPos, 0.6, 10)
	local steamPart = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or root
	Fx.steam(steamPart, CFG.SteamTime)
	Sfx.voice(standPos)
end

local function runDeath(opts)
	opts = opts or {}
	local char, hum, root = charParts()
	if State.busy or not (char and hum and root) or hum.Health <= 0 then
		return
	end
	State.busy = true
	State.token += 1
	local token = State.token
	local scope = Scope.new()
	local ok, err = pcall(deathBody, char, hum, root, opts, token, scope)
	if not ok then
		warn("[RP9] " .. tostring(err))
	end
	scope:Destroy()
	State.busy = false
end

--------------------------------------------------------------------------------
-- ACCIONES
--------------------------------------------------------------------------------
local function pickFree(names)
	local free = {}
	for _, n in ipairs(names) do
		if not State.limbs[n] then
			free[#free + 1] = n
		end
	end
	if #free == 0 then
		return nil
	end
	return free[rng:NextInteger(1, #free)]
end

local ACTIONS = {
	arm = function()
		local n = pickFree({ "LeftArm", "RightArm" })
		if n then
			severLimb(n)
		end
	end,
	leg = function()
		local n = pickFree({ "LeftLeg", "RightLeg" })
		if n then
			severLimb(n)
		end
	end,
	all = function()
		for _, n in ipairs(Rig.LIMBS) do
			severLimb(n)
		end
	end,
	die = function()
		task.spawn(runDeath, {})
	end,
	test = function()
		task.spawn(runDeath, { test = true })
	end,
}

--------------------------------------------------------------------------------
-- DISPARADORES AUTOMATICOS: dano, caida, muerte real
--------------------------------------------------------------------------------
local charConns = {}
local function clearCharConns()
	for _, c in ipairs(charConns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	charConns = {}
end

local function vigilar(char)
	clearCharConns()
	local hum = char:WaitForChild("Humanoid", 10)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then
		return
	end
	local lastHealth = hum.Health
	local minVy = 0

	table.insert(charConns, hum.HealthChanged:Connect(function(h)
		local d = lastHealth - h
		lastHealth = h
		if autoActivo and d >= CFG.DamageToSever and h > 0 and not State.busy then
			if os.clock() - State.lastSever > CFG.DamageCooldown then
				State.lastSever = os.clock()
				local n = pickFree(Rig.LIMBS)
				if n then
					severLimb(n)
				end
			end
		end
	end))

	table.insert(charConns, RunService.Heartbeat:Connect(function()
		if root.Parent then
			minVy = math.min(minVy, root.AssemblyLinearVelocity.Y)
		end
	end))
	table.insert(charConns, hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			if autoActivo and CFG.FallToSever and minVy < -CFG.FallSpeedToSever and not State.busy then
				local n = pickFree(Rig.LIMBS)
				if n then
					severLimb(n)
				end
			end
			minVy = 0
		end
	end))

	table.insert(charConns, hum.Died:Connect(function()
		if root.Parent then
			State.deathCF = root.CFrame
		end
		State.token += 1 -- aborta cualquier secuencia en curso
	end))
end

con(jugador.CharacterAdded, function(char)
	clearLimbs()
	State.busy = false
	local deathCF = State.deathCF
	State.deathCF = nil
	task.spawn(vigilar, char)
	if CFG.RegenOnRealDeath and autoActivo and deathCF then
		task.spawn(function()
			local root = char:WaitForChild("HumanoidRootPart", 10)
			local hum = char:WaitForChild("Humanoid", 10)
			if not root or not hum then
				return
			end
			-- oculto al instante y aparezco donde moriste
			for _, p in ipairs(Rig.allParts(char)) do
				setHide(p, 1)
			end
			pcall(function()
				char:PivotTo(deathCF)
			end)
			task.wait(0.35)
			if char.Parent and hum.Health > 0 then
				runDeath({ respawn = true })
			end
			-- por si la secuencia no pudo correr
			for _, p in ipairs(Rig.allParts(char)) do
				if Hidden[p] == 1 and not State.busy then
					setHide(p, 0)
				end
			end
		end)
	end
end)
if jugador.Character then
	task.spawn(vigilar, jugador.Character)
end

--------------------------------------------------------------------------------
-- INTERFAZ: panel AUTO + botones circulares arrastrables
--------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RP9_UI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 60

local function parentGui(g)
	local okH, h = pcall(function()
		return gethui and gethui()
	end)
	if okH and h then
		local ok = pcall(function()
			g.Parent = h
		end)
		if ok and g.Parent then
			return
		end
	end
	local okC = pcall(function()
		g.Parent = game:GetService("CoreGui")
	end)
	if okC and g.Parent then
		return
	end
	g.Parent = jugador:WaitForChild("PlayerGui")
end
parentGui(gui)

local function crearBoton(texto, sub, tam, pos, colorBorde)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(tam, tam)
	b.Position = pos
	b.BackgroundColor3 = COLOR_FONDO
	b.BackgroundTransparency = 0.1
	b.AutoButtonColor = false
	b.Text = texto .. "\n" .. sub
	b.TextColor3 = WHITE
	b.TextSize = 13
	b.Font = Enum.Font.GothamBold
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = colorBorde
	s.Thickness = 2
	s.Parent = b
	return b
end

local function hacerArrastrable(obj, alClick)
	local dragging, moved = false, false
	local startIn, startPos
	con(obj.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			moved = false
			startIn = input.Position
			startPos = obj.Position
			local ch
			ch = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					ch:Disconnect()
					if not moved then
						alClick()
					end
				end
			end)
		end
	end)
	con(UIS.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = input.Position - startIn
			if d.Magnitude > 8 then
				moved = true
			end
			if moved then
				obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
end

-- panel superior
local panel = Instance.new("TextButton")
panel.Size = UDim2.fromOffset(190, 34)
panel.Position = UDim2.new(0.5, -95, 0, 8)
panel.BackgroundColor3 = COLOR_FONDO
panel.BackgroundTransparency = 0.1
panel.AutoButtonColor = false
panel.Font = Enum.Font.GothamBold
panel.TextSize = 13
panel.TextColor3 = WHITE
panel.Parent = gui
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = panel
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Name = "Borde"
	s.Parent = panel
end
local function refrescarPanel()
	panel.Text = "RICK PRIME REGEN  " .. (autoActivo and "AUTO ON" or "AUTO OFF")
	panel.Borde.Color = autoActivo and COLOR_VERDE or COLOR_ROJO
end
refrescarPanel()
con(panel.Activated, function()
	autoActivo = not autoActivo
	refrescarPanel()
end)

local BOTONES = {
	{ "BRAZO", "Z", "arm", 0 },
	{ "PIERNA", "X", "leg", 1 },
	{ "TODOS", "C", "all", 2 },
	{ "MORIR", "V", "die", 3 },
	{ "LEVANTAR", "B", "test", 4 },
}
for _, def in ipairs(BOTONES) do
	local b = crearBoton(def[1], "[" .. def[2] .. "]", TAM_CIRCULO, UDim2.new(1, -TAM_CIRCULO - 12, 0.18, def[4] * (TAM_CIRCULO + 8)), COLOR_ROJO)
	b.TextSize = 11
	hacerArrastrable(b, function()
		local f = ACTIONS[def[3]]
		if f then
			f()
		end
	end)
end

local TECLAS = {
	[Enum.KeyCode.Z] = "arm",
	[Enum.KeyCode.X] = "leg",
	[Enum.KeyCode.C] = "all",
	[Enum.KeyCode.V] = "die",
	[Enum.KeyCode.B] = "test",
}
con(UIS.InputBegan, function(input, gp)
	if gp then
		return
	end
	local a = TECLAS[input.KeyCode]
	if a then
		ACTIONS[a]()
	end
end)

--------------------------------------------------------------------------------
-- LIMPIEZA GLOBAL
--------------------------------------------------------------------------------
env.RP9_LIMPIAR = function()
	limpiado = true
	State.token += 1
	for _, c in ipairs(conexiones) do
		pcall(function()
			c:Disconnect()
		end)
	end
	clearCharConns()
	pcall(function()
		RunService:UnbindFromRenderStep("RP9_Hide")
	end)
	local char = jugador.Character
	if char then
		for _, p in ipairs(Rig.allParts(char)) do
			pcall(function()
				p.LocalTransparencyModifier = 0
			end)
		end
		local root = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if root and State.busy then
			pcall(function()
				root.Anchored = false
			end)
		end
		if hum and State.busy then
			pcall(function()
				hum.WalkSpeed = 16
				hum.JumpPower = 50
				hum.AutoRotate = true
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end)
		end
	end
	Hidden = {}
	for _, o in ipairs({ gui, flashGui, grade, blur, fx }) do
		pcall(function()
			o:Destroy()
		end)
	end
	env.RP9_LIMPIAR = nil
end

print("[RICK PRIME REGEN v9] listo | Z brazo | X pierna | C todos | V morir | B probar levantarse")
