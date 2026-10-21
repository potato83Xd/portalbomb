--!nonstrict
-- ============================================================
-- RICK PRIME - TODO EN UNO (LocalScript / Delta) - solo tú lo ves
--
--  1) OUTFIT   : Rick Prime + hombrera + pantalón (auto en cada respawn)
--  2) REGEN    : Z brazo | X pierna | C todos | V morir  (+ botones)
--  3) PORTALES : Portal Gun de Rick Prime + menú (botón MENU, a la derecha)
--                Pestañas: Boton 1, Boton 2, Jugadores, Juegos, Agarre, Colocar
--                Modos de portal: Acostado / Parado / VOLANDO (tecla F)
--  4) BOMBA    : Tool "Bomba Interdimensional" + panel de control
--                (botón con el asset 82398905680280, debajo de MENU)
--  5) FÉNIX    : Protocolo Fénix (hasta 4 cápsulas). P = colocar | O = abrir/cerrar
--                (botones CÁPSULA / ABRIR / QUITAR, en una fila sobre los de REGEN)
--
-- RICK PRIME <-> FÉNIX (lo decide el interruptor "RICK PRIME: ON/OFF"):
--   * ON  -> al morir solo actúa la regeneración de Rick Prime.
--   * OFF -> al morir solo actúa el Protocolo Fénix: reapareces DENTRO de la
--            cápsula que toca (1, 2, 3, 4). Las cápsulas no se tocan mientras
--            Rick Prime esté en ON.
--
-- BOMBA <-> PORTALES:
--   * Solo en el MODO 1 (2 portales abiertos) la bomba entra por un
--     portal y sale por el otro.
--   * En el MODO 2 (hasta 6 portales) la bomba no atraviesa ninguno.
--
-- Cada módulo corre aislado: si uno falla, los demás siguen.
-- Si re-ejecutas, cada módulo limpia su versión anterior.
-- ============================================================

-- Datos compartidos entre módulos (portales <-> bomba)
local Shared = {}

--##########################################################################
-- MÓDULO 1: OUTFIT
--##########################################################################
local function MODULO_OUTFIT()
	local Players = game:GetService("Players")
	local InsertService = game:GetService("InsertService")
	local jugador = Players.LocalPlayer

	local env = (getgenv and getgenv()) or _G
	if env.OUTFIT_LIMPIAR then
		pcall(env.OUTFIT_LIMPIAR)
	end

	local IDS = {
		14985859247,     -- Grey Star Military Right Shoulder
		10319492221,     -- Weird Rick BOTTOM
		113332974175271, -- Rick Prime
	}
	-- Ajuste del hombro en R6 (X: +afuera | Y: +arriba | Z: +atrás)
	local AJUSTE_R6 = Vector3.new(-0.2, -0.1, 0.15)
	local GIRO_R6 = Vector3.new(0, 0, 0)

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	local cache = {}
	local puestos = {}
	local token = 0

	local function cargar(id)
		if cache[id] then
			return cache[id]
		end
		local objs
		local ok = pcall(function()
			objs = game:GetObjects("rbxassetid://" .. id)
		end)
		if not ok or not objs or #objs == 0 then
			ok = pcall(function()
				objs = { InsertService:LoadAsset(id) }
			end)
		end
		if not ok or not objs or #objs == 0 then
			warn("[OUTFIT] No se pudo cargar el ID: " .. id)
			return nil
		end
		cache[id] = objs
		return objs
	end

	local function limpiarPuestos()
		for _, o in ipairs(puestos) do
			pcall(function() o:Destroy() end)
		end
		table.clear(puestos)
	end

	local function ponerAccesorio(char, hum, item)
		local c = item:Clone()
		local handle = c:FindFirstChild("Handle")
		if not handle then
			warn("[OUTFIT] Accesorio sin Handle: " .. c.Name)
			return
		end

		handle.Anchored = false
		handle.CanCollide = false
		handle.Massless = true
		handle.Transparency = 0

		pcall(function() hum:AddAccessory(c) end)
		if c.Parent ~= char then
			c.Parent = char
		end
		table.insert(puestos, c)
		task.wait(0.25)
		if not char.Parent then return end

		for _, d in ipairs(handle:GetChildren()) do
			if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
				d:Destroy()
			end
		end

		local att = handle:FindFirstChildOfClass("Attachment")
		local nombre = (att and att.Name or c.Name):lower()
		local esDerecho = nombre:find("right") ~= nil
		local esIzquierdo = nombre:find("left") ~= nil
		local esHombro = nombre:find("shoulder") ~= nil or c.Name:lower():find("shoulder") ~= nil

		local destino
		if esDerecho then
			destino = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
		elseif esIzquierdo then
			destino = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
		end
		if not destino or not esHombro then
			destino = (not esHombro and destino) or nil
			destino = destino or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
		end
		if not destino then
			warn("[OUTFIT] No se encontró dónde pegar: " .. c.Name)
			return
		end

		local attHandle = att and att.CFrame or CFrame.new()
		local puntoCuerpo

		local attCuerpo = att and destino:FindFirstChild(att.Name)
		if attCuerpo and attCuerpo:IsA("Attachment") then
			puntoCuerpo = attCuerpo.CFrame
		else
			local lado = esIzquierdo and -1 or 1
			local base = CFrame.new(0, destino.Size.Y / 2, 0)
			if destino.Name == "Torso" or destino.Name == "UpperTorso" then
				base = CFrame.new(lado * destino.Size.X / 2, destino.Size.Y / 2, 0)
			end
			local aj = CFrame.new(AJUSTE_R6.X * lado, AJUSTE_R6.Y, AJUSTE_R6.Z)
				* CFrame.Angles(math.rad(GIRO_R6.X), math.rad(GIRO_R6.Y * lado), math.rad(GIRO_R6.Z * lado))
			puntoCuerpo = base * aj
		end

		local w = Instance.new("Weld")
		w.Name = "OutfitWeld"
		w.Part0 = destino
		w.Part1 = handle
		w.C0 = puntoCuerpo
		w.C1 = attHandle
		w.Parent = handle
	end

	local function aplicar(char)
		if not char then return end
		token += 1
		local miToken = token

		local hum = char:WaitForChild("Humanoid", 10)
		if not hum or miToken ~= token then return end

		local t = 0
		while not jugador:HasAppearanceLoaded() and t < 5 do
			t += task.wait(0.1)
		end
		if miToken ~= token or not char.Parent then return end

		limpiarPuestos()

		for _, id in ipairs(IDS) do
			local objs = cargar(id)
			if objs then
				for _, raiz in ipairs(objs) do
					local lista = { raiz }
					for _, d in ipairs(raiz:GetDescendants()) do
						table.insert(lista, d)
					end
					for _, item in ipairs(lista) do
						if miToken ~= token or not char.Parent then return end
						if item:IsA("Accoutrement") then
							ponerAccesorio(char, hum, item)
						elseif item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
							for _, old in ipairs(char:GetChildren()) do
								if old.ClassName == item.ClassName and not table.find(puestos, old) then
									old:Destroy()
								end
							end
							local c = item:Clone()
							c.Parent = char
							table.insert(puestos, c)
						end
					end
				end
			end
		end
	end

	con(jugador.CharacterAdded, function(char)
		task.spawn(aplicar, char)
	end)
	if jugador.Character then
		task.spawn(aplicar, jugador.Character)
	end

	env.OUTFIT_LIMPIAR = function()
		token += 1
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		limpiarPuestos()
	end

	print("[OUTFIT] Cargado.")
end

--##########################################################################
-- MÓDULO 2: RICK PRIME REGENERATION
--##########################################################################
local function MODULO_RICK()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Debris = game:GetService("Debris")
	local Lighting = game:GetService("Lighting")
	local UIS = game:GetService("UserInputService")

	local jugador = Players.LocalPlayer
	local playerGui = jugador:WaitForChild("PlayerGui")

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

	local CFG = {
		DamageToSever = 1,
		TriggerOnDamage = true,
		DamageCooldown = 0.8,
		FallToSever = true,
		FallSpeedToSever = 60,

		DeathLinger = 3.4,
		LimbLinger = 2.0,
		LimbBloomTime = 0.9,
		BodyBloomTime = 0.45,
		FormTime = 0.4,
		ClothFadeTime = 0.7,
		TendrilFadeOut = 0.15,
		MassFadeOut = 0.12,

		BloodColor = Color3.fromRGB(150, 10, 20),
		PuddleLife = 40,
		MaxPuddles = 220,
		ClearPuddlesOnBodyRegen = true,

		Quality = 1,
		CameraFx = true,
		KeepCamera = true,
		MoveDuringRegen = true,

		Sound = true,
		SfxVolume = 1,
		VoiceLines = {
			"rbxassetid://138925430725431",
			"rbxassetid://104144683858662",
		},
		VoiceVolume = 1.4,
		TearOnLimbCut = false,
		VoiceOnLimbRegen = false,
		CustomSounds = {
			tear = "rbxassetid://100892314541959",
			print = "rbxassetid://84312631986360",
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

	local autoActivo = true
	local cleaned = false

	-- El módulo FÉNIX lee este interruptor para saber qué sistema usar al morir
	Shared.RickActivo = function()
		return autoActivo
	end

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

	---------------- Ticker / Scope / geometría ----------------
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

	local function upCF(pos)
		return CFrame.fromMatrix(pos, Vector3.xAxis, Vector3.zAxis, -Vector3.yAxis)
	end

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

	---------------- Cámara ----------------
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
			camHold = { cf = cf, untilT = os.clock() + 10 }
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
		punchFov(28, 0.1, 0.9)
		shake(0.7, 0.7)
		playGrade({
			{ t = 0.10, tint = Color3.fromRGB(40, 255, 230), sat = 1.5, bri = 0.2, blur = 26 },
			{ t = 0.12, tint = Color3.fromRGB(255, 150, 210), sat = 1, bri = 0.1, blur = 30 },
			{ t = 0.12, tint = Color3.fromRGB(190, 20, 25), sat = 0, bri = -0.08, blur = 22 },
			{ t = 0.65, tint = WHITE, sat = 0, bri = 0, blur = 0 },
		})
	end

	function CamFx.sever()
		if not CFG.CameraFx then
			return
		end
		shake(0.35, 0.3)
		playGrade({
			{ t = 0.06, tint = Color3.fromRGB(255, 110, 110), sat = 0.3, bri = 0.08, blur = 6 },
			{ t = 0.30, tint = WHITE, sat = 0, bri = 0, blur = 0 },
		})
	end

	---------------- FX ----------------
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

	---------------- Sonidos ----------------
	local ContentProvider = game:GetService("ContentProvider")
	local SoundService = game:GetService("SoundService")

	local Sfx = { ready = {}, last = {}, loops = {}, voices = {}, voiceLast = nil }
	local SOUND_FALLBACKS = {
		tear = {},
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
			s.Parent = SoundService
			local t = os.clock()
			while not s.IsLoaded and os.clock() - t < 5 do
				task.wait(0.1)
			end
			if not s.IsLoaded then
				warn("[RICKPRIME] NO cargó el audio: " .. s.SoundId)
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
		Debris:AddItem(target, 20)
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

	---------------- Sangre ----------------
	local Blood = { mine = {}, all = {}, layer = 0 }
	local GRAVITY = 90

	function Blood.disc(pos, normal, diameter)
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

	function Blood.cluster(pos, normal, diameter)
		Blood.disc(pos, normal, diameter)
		if diameter > 2 then
			Sfx.play("splat", pos, 0.3, rand(1.1, 1.6))
		end
		local extra = (diameter > 2.4) and rng:NextInteger(2, 4) or rng:NextInteger(0, 1)
		for _ = 1, extra do
			local ang = rand(0, 6.28)
			local r = diameter * 0.5 * rand(0.6, 1)
			local offset = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
			Blood.disc(pos + offset, normal, diameter * rand(0.35, 0.65))
		end
	end

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

	---------------- Listones ----------------
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
			p = Vector3.new(p.X, math.max(p.Y, floorY + 0.1), p.Z)
		end
		return p
	end

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
				freq = rand(7, 11),
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

	---------------- Rig ----------------
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

	function Rig.socket(rootPart)
		return rootPart.CFrame:PointToWorldSpace(Vector3.new(0, rootPart.Size.Y / 2, 0))
	end

	function Rig.limbBase(rootPart)
		return function()
			local cf = rootPart.CFrame
			local top = cf:PointToWorldSpace(Vector3.new(0, rootPart.Size.Y / 2, 0))
			return CFrame.lookAt(top, top - cf.UpVector, cf.RightVector)
		end
	end

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

	---------------- Piezas ----------------
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

	---------------- Regenerar grupo ----------------
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
		return {
			base = Rig.limbBase(parts[1]),
			count = 12, length = Rig.length(parts) * 0.95, cone = math.rad(30),
			width = 0.32, thick = 0.09, droop = 0.3,
		}
	end

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
			profile.duration = bloom + form + 0.1
			profile.fadeOut = CFG.TendrilFadeOut
			scope:Add(Tendrils.spawn(profile))

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
		Sfx.play("snap", Rig.center(parts), 0.9, 1.3)
		local proxies = scope:Add(Proxies.run(list, fly, form))
		task.wait(form)
		printLoop.Stop(0.15)
		if not alive() then
			return
		end

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
			Debris:AddItem(piece.model, CFG.ClothFadeTime + 0.5)
		end
		task.wait(CFG.ClothFadeTime)
	end

	---------------- Estado ----------------
	local State = { char = nil, hum = nil, busy = false, severed = {} }
	local pendingDeath = nil

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
		task.delay(0.8, function()
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

	local STEPS = {
		{ names = { "Head" }, wait = 0.15 },
		{ names = { "LeftLeg", "RightLeg" }, wait = 0.3 },
		{ names = { "Torso" }, wait = 0.3 },
		{ names = { "LeftArm", "RightArm" }, wait = 0 },
	}

	local function onDeath(char, hum)
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

		local pieces = {}
		for gname, list in pairs(groups) do
			pieces[gname] = Piece.make(list, origin, (gname == "Torso") and 0.4 or 1)
		end

		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				setHidden(d, true)
				d.AssemblyLinearVelocity = Vector3.zero
				d.AssemblyAngularVelocity = Vector3.zero
				d.Anchored = true
			end
		end

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
		task.delay(0.75, function()
			Sfx.play("thump", origin, 0.9, 0.9)
		end)
		Fx.glow(origin, Color3.fromRGB(255, 70, 90), 9, 0.35)
		Fx.bloodCloud(origin, 1.8)
		Fx.puff(origin + Vector3.new(0, 1, 0), 2.4, 24)
		Fx.shards(origin, 14)
		Blood.splatter(origin, 38, 10, 2.0, 5.0)

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

		Rig.hideAll(char)
		root.Anchored = true
		char:PivotTo(data.cf)
		local waited = 0
		while not jugador:HasAppearanceLoaded() and waited < 3 do
			waited += task.wait(0.1)
		end
		Rig.hideAll(char)
		root.Anchored = true
		char:PivotTo(data.cf)
		local bbCF, bbSize = char:GetBoundingBox()
		local hit = groundAt(data.cf.Position, 3)
		if hit then
			local bottom = bbCF.Position.Y - bbSize.Y / 2
			char:PivotTo(char:GetPivot() + Vector3.new(0, hit.Position.Y - bottom + 0.05, 0))
		end
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
		if CFG.MoveDuringRegen and char.Parent then
			root.Anchored = false
		end
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
			task.delay(0.25, Sfx.voice)
		end
		pendingDeath = nil
		State.busy = false
	end

	---------------- Acciones ----------------
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

	---------------- Interfaz ----------------
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

	env.RICKPRIME_LIMPIAR = function()
		cleaned = true
		Shared.RickActivo = nil
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

	print("[RICKPRIME] Cargado. Botones BRAZO / PIERNA / TODO / MORIR | Teclas Z X C V")
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

local function CreatePortalPart()

	local part = nil
	local measure = nil

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
		part.Size = part.Size * PORTAL_SIZE

		measure = MeasurePortal(part.Size)

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

	return part, measure
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

local function ClosePortal(entry)

	if entry.part and entry.part.Parent then

		local part = entry.part

		PlaySound(SOUND_CLOSE, part)

		task.delay(0.1, function()
			part:Destroy()
		end)
	end
end

local function CloseAllPortals()

	for _, entry in ipairs(Portals) do
		ClosePortal(entry)
	end

	table.clear(Portals)
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

	local part, measure = CreatePortalPart()

	-- Respeta el maximo de portales (cierra los mas viejos)
	while #Portals >= MAX_PORTALS and #Portals > 0 do
		ClosePortal(table.remove(Portals, 1))
	end

	local standing = false

	if StandMode and math.abs(normal.Y) > 0.8 then

		standing = true

		local height = measure and measure.height or 5
		local sign = normal.Y > 0 and 1 or -1

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
		normal = normal,
		position = position + normal * 0.05,
		face = normal,
		tallDir = Vector3.new(0, 1, 0),
		look = normal,
		exit = position + normal * 3,
		radius = ENTER_RADIUS,
		enterDepth = 2.2,
		spin = 0
	}

	if AUTO_ALIGN and measure then

		local tallDir = GetTallDir(position, normal)

		local offset = measure.thickness / 2 + 0.03
		local center = position + normal * offset

		if not standing and not PLACE_EXACT then
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

		local flat = Vector3.new(-dir.X, 0, -dir.Z)

		if flat.Magnitude > 0.01 then
			hitNormal = flat.Unit
		else
			hitNormal = Vector3.new(0, 0, 1)
		end

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

	pcall(FireBeam, handle.Position, hitPos)

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
		PortalGun = tool
		LastToolChange = os.clock()
		StandGui.Enabled = true
	end)

	tool.Unequipped:Connect(function()
		ToolEquipped = false
		PortalGun = nil
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

	if depth < -2 or depth > entry.enterDepth then
		return false
	end

	return (alongTall / hh) ^ 2 + (alongSide / hw) ^ 2 <= 1
end

--------------------------------------------------
-- GIRO Y TELETRANSPORTE
--------------------------------------------------

Con(RunService.Heartbeat, function(dt)

	for _, entry in ipairs(Portals) do

		if entry.part.Parent then

			entry.spin = (entry.spin + SPIN_SPEED * dt) % 360

			entry.part.CFrame = EntryCFrame(entry)
		end
	end

	local root = Character:FindFirstChild("HumanoidRootPart")

	if not root then
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
StandButton.Position = UDim2.new(0, 20, 0.5, 0)
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
Title.Size = UDim2.new(1, -70, 0, 36)
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

local TabNames = { "Boton 1", "Boton 2", "Jugadores", "Juegos", "Agarre", "Colocar" }
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
	b.Size = UDim2.new(1 / 6, -4, 1, 0)
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

	local closeAll = MakeButton(page, "Cerrar todos los portales", 6, 44, RED)

	local status = MakeLabel(page, "", 7, 32, true)

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

RefreshPlayers = function()

	for _, child in ipairs(PlayersPage:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

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
		tp.BackgroundColor3 = GREEN
		tp.Text = "TP"
		tp.TextColor3 = Color3.new(1, 1, 1)
		tp.Font = Enum.Font.GothamBold
		tp.TextScaled = true
		tp.Parent = row
		Round(6, tp)

		tp.Activated:Connect(function()

			local targetChar = plr.Character
			local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
			local myRoot = Character:FindFirstChild("HumanoidRootPart")

			if targetRoot and myRoot then
				myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 3)
			end
		end)
	end
end

Con(Players.PlayerAdded, function()
	if Pages[3].Visible then
		RefreshPlayers()
	end
end)

Con(Players.PlayerRemoving, function()
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

MakeLabel(PlacePage, "Volando: toca el cielo y el portal aparece en ese punto del aire. Si tocas una superficie funciona como Acostado. La tecla F cambia de modo.", 6, 84, false)

table.insert(Refreshers, function()
	for i, pb in ipairs(PlaceButtons) do
		if i == PlaceMode then
			pb.BackgroundColor3 = GREEN
		else
			pb.BackgroundColor3 = BTN_BG
		end
	end
end)

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
-- MÓDULO 3: BOMBA INTERDIMENSIONAL
-- Explosión hecha SOLO con partículas (humo, fuego, chispas), rayos y
-- discos planos en el suelo. Ya NO hay esferas ni burbujas.
--##########################################################################
local function MODULO_BOMBA()
	-- ===================== CONFIG =====================
	local NOMBRE_TOOL   = "Bomba Interdimensional"
	local TIEMPO_MECHA  = 3
	local COOLDOWN      = 4
	local FUERZA        = 60
	local ELEVACION     = 30
	local RADIO         = 20
	local ESCALA        = 0.55   -- tamaño de la bomba (antes 0.7)
	local NUM_EMBUDOS   = 30
	local COLOR_NUCLEO  = Color3.fromRGB(95, 112, 108)
	local COLOR_EMBUDO  = Color3.fromRGB(36, 40, 42)
	local COLOR_ARO     = Color3.fromRGB(240, 232, 160)
	local ROSA_OJO      = Color3.fromRGB(235, 30, 150)
	local ROSA          = Color3.fromRGB(255, 20, 147)
	local VIOLETA       = Color3.fromRGB(150, 60, 255)
	local BLANCO        = Color3.fromRGB(255, 255, 255)
	local MAGENTA       = Color3.fromRGB(240, 40, 185)
	local ROSA_CLARO    = Color3.fromRGB(255, 150, 235)
	local CIRUELA       = Color3.fromRGB(110, 40, 110)
	local HUMO_CLARO    = Color3.fromRGB(176, 150, 190)
	local HUMO_OSCURO   = Color3.fromRGB(105, 85, 120)
	local SONIDO_BOOM   = "rbxasset://sounds/impact_explosion_03.mp3"
	local SONIDO_BEEP   = "rbxasset://sounds/electronicpingshort.wav"
	local DURACION_FUEGO = 10
	local NUM_FOCOS      = 12

	-- Controles de lanzamiento (los cambia la interfaz de la bomba)
	local DIR_X, DIR_Y, DIR_Z = 0, 0, 0
	local LEJOS = false
	local FACTOR_LEJOS = 2.5
	local MODO_LANZ = 1 -- 1 = frente del personaje, 2 = camara, 3 = ejes del mundo
	local ATRAVESAR = true
	-- ==================================================

	local Players      = game:GetService("Players")
	local TweenService = game:GetService("TweenService")
	local Debris       = game:GetService("Debris")
	local RunService   = game:GetService("RunService")
	local Lighting     = game:GetService("Lighting")

	local LocalPlayer = Players.LocalPlayer

	local env = (getgenv and getgenv()) or _G
	if env.BombaStop then
		pcall(env.BombaStop)
		env.BombaStop = nil
	end

	local todas = {}
	local function conectar(signal, fn)
		local c = signal:Connect(fn)
		table.insert(todas, c)
		return c
	end

	local activo = true
	local tool = nil
	local bombas = {}
	local ultimoUso = -math.huge

	-- ===================== UTILIDADES =====================
	local function cs(...)
		local kp = {}
		for _, k in ipairs({ ... }) do
			table.insert(kp, ColorSequenceKeypoint.new(k[1], k[2]))
		end
		return ColorSequence.new(kp)
	end

	local function ns(...)
		local kp = {}
		for _, k in ipairs({ ... }) do
			table.insert(kp, NumberSequenceKeypoint.new(k[1], k[2]))
		end
		return NumberSequence.new(kp)
	end

	local function rnd(a, b)
		return a + math.random() * (b - a)
	end

	local function puntosEsfera(n)
		local puntos = {}
		local golden = math.pi * (3 - math.sqrt(5))
		for i = 0, n - 1 do
			local y = 1 - (i / (n - 1)) * 2
			local r = math.sqrt(1 - y * y)
			local theta = golden * i
			table.insert(puntos, Vector3.new(math.cos(theta) * r, y, math.sin(theta) * r))
		end
		return puntos
	end

	-- ===================== CONSTRUIR BOMBA =====================
	local function crearHandle()
		local S = ESCALA
		local R = 1.6 * S

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Shape = Enum.PartType.Ball
		handle.Size = Vector3.one * R * 2
		handle.Color = COLOR_NUCLEO
		handle.Material = Enum.Material.SmoothPlastic

		local function pieza(nombre, dir, dist, largo, diametro, color, material)
			local p = Instance.new("Part")
			p.Name = nombre
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(largo * S, diametro * S, diametro * S)
			p.Color = color
			p.Material = material
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			local pos = dir * (R + dist * S)
			local arriba = (math.abs(dir.Y) > 0.99) and Vector3.xAxis or Vector3.yAxis
			p.CFrame = CFrame.lookAt(pos, pos + dir, arriba) * CFrame.Angles(0, math.rad(90), 0)
			p.Parent = handle

			local weld = Instance.new("Weld")
			weld.Part0 = handle
			weld.Part1 = p
			weld.C0 = p.CFrame
			weld.Parent = p
			return p
		end

		for _, dir in ipairs(puntosEsfera(NUM_EMBUDOS)) do
			pieza("Cuello",  dir, 0.15, 0.60, 0.38, COLOR_EMBUDO, Enum.Material.SmoothPlastic)
			pieza("Medio",   dir, 0.50, 0.30, 0.75, COLOR_EMBUDO, Enum.Material.SmoothPlastic)
			pieza("Campana", dir, 0.78, 0.26, 1.20, COLOR_EMBUDO, Enum.Material.SmoothPlastic)
			pieza("Aro",     dir, 0.92, 0.06, 1.02, COLOR_ARO, Enum.Material.SmoothPlastic)
			pieza("Ojo",     dir, 0.95, 0.06, 0.84, ROSA_OJO, Enum.Material.Neon)
		end

		local luz = Instance.new("PointLight")
		luz.Color = ROSA
		luz.Range = 8
		luz.Brightness = 1
		luz.Parent = handle

		return handle
	end

	-- ===================== EFECTOS =====================
	local TEX_FUEGO  = "rbxasset://textures/particles/fire_main.dds"
	local TEX_HUMO   = "rbxasset://textures/particles/smoke_main.dds"
	local TEX_CHISPA = "rbxasset://textures/particles/sparkles_main.dds"

	local function emisor(padre, cfg)
		local e = Instance.new("ParticleEmitter")
		for k, v in pairs(cfg) do
			e[k] = v
		end
		e.Enabled = false
		e.Parent = padre
		return e
	end

	local function parteAncla(pos, vida)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Position = pos
		p.Parent = workspace
		Debris:AddItem(p, vida)
		return p
	end

	-- Suelta una "bocanada" de partículas en un punto (nube, llama, etc.)
	local function bocanada(pos, cfg, cantidad, retraso, vida)
		task.delay(retraso or 0, function()
			if not activo then return end
			local a = parteAncla(pos, vida or 8)
			emisor(a, cfg):Emit(cantidad)
		end)
	end

	local function anilloSuelo(pos, color, tamanoFinal, duracion, transparenciaInicial)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Transparency = transparenciaInicial
		p.Size = Vector3.new(0.2, 2, 2)
		p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = workspace
		TweenService:Create(
			p,
			TweenInfo.new(duracion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.2, tamanoFinal, tamanoFinal), Transparency = 1 }
		):Play()
		Debris:AddItem(p, duracion + 0.1)
	end

	local function sonido(padre, id, volumen, velocidad)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volumen
		s.PlaybackSpeed = velocidad
		s.RollOffMinDistance = 30
		s.RollOffMaxDistance = 400
		s.Parent = padre
		s:Play()
		Debris:AddItem(s, 8)
	end

	local function sacudirCamara(intensidad, duracion)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or intensidad <= 0 then return end
		task.spawn(function()
			local t0 = os.clock()
			while activo and os.clock() - t0 < duracion do
				local k = (1 - (os.clock() - t0) / duracion) * intensidad
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, 0)
				RunService.RenderStepped:Wait()
			end
			pcall(function() hum.CameraOffset = Vector3.zero end)
		end)
	end

	local function destelloPantalla(intensidad)
		local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if not pg or intensidad <= 0 then return end
		local g = Instance.new("ScreenGui")
		g.Name = "BombaFlash"
		g.IgnoreGuiInset = true
		g.ResetOnSpawn = false
		g.DisplayOrder = 1000
		g.Parent = pg
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = BLANCO
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1 - intensidad
		f.Parent = g
		TweenService:Create(
			f,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundColor3 = Color3.fromRGB(255, 110, 215), BackgroundTransparency = 1 - 0.5 * intensidad }
		):Play()
		task.delay(0.3, function()
			if f.Parent then
				TweenService:Create(
					f,
					TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 }
				):Play()
			end
		end)
		Debris:AddItem(g, 2)
	end

	local function efectosCine(intensidad)
		if intensidad <= 0 then return end
		local bloom = Instance.new("BloomEffect")
		bloom.Size = 40
		bloom.Threshold = 0.6
		bloom.Intensity = 2.5 * intensidad
		bloom.Parent = Lighting

		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness = 0.18 * intensidad
		cc.Contrast = 0.25 * intensidad
		cc.TintColor = Color3.fromRGB(255, 200, 235)
		cc.Parent = Lighting

		local blur = Instance.new("BlurEffect")
		blur.Size = 20 * intensidad
		blur.Parent = Lighting

		local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(bloom, info, { Intensity = 0 }):Play()
		TweenService:Create(cc, info, { Brightness = 0, Contrast = 0, TintColor = BLANCO }):Play()
		TweenService:Create(blur, info, { Size = 0 }):Play()
		Debris:AddItem(bloom, 1.8)
		Debris:AddItem(cc, 1.8)
		Debris:AddItem(blur, 1.8)
	end

	-- ===================== EXPLOSIÓN (estilo del video) =====================
	-- Video: destello rosa -> hongo con cabeza magenta brillante -> humo
	-- lavanda enorme y esponjoso que se oscurece -> arcos eléctricos,
	-- astillas de pavimento y llamas rosas ardiendo en el suelo.
	local carpetaFX = nil
	local function obtenerCarpeta()
		if carpetaFX and carpetaFX.Parent then return carpetaFX end
		carpetaFX = Instance.new("Folder")
		carpetaFX.Name = "BombaFX"
		carpetaFX.Parent = workspace
		return carpetaFX
	end

	local function rayosEstrella(pos, carpeta)
		for _ = 1, 18 do
			local dir = Vector3.new(rnd(-1, 1), rnd(-0.6, 1), rnd(-1, 1)).Unit
			local largo = RADIO * rnd(0.8, 1.7)
			local ancho = rnd(0.5, 1.2)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = (math.random() < 0.6) and BLANCO or ROSA_CLARO
			p.Size = Vector3.new(ancho, ancho, 1)
			p.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, -0.5)
			p.Parent = carpeta
			TweenService:Create(
				p,
				TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = Vector3.new(ancho * 0.2, ancho * 0.2, largo),
					CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(0, 0, -largo / 2),
					Transparency = 1,
				}
			):Play()
			Debris:AddItem(p, 0.4)
		end
	end

	local function rayoElectrico(origen, carpeta)
		local color = (math.random() < 0.5) and Color3.fromRGB(255, 90, 215) or VIOLETA
		local dir = Vector3.new(rnd(-1, 1), rnd(0.2, 1), rnd(-1, 1)).Unit
		local actual = origen
		for _ = 1, 6 do
			local sig = actual + dir * rnd(1.5, 3.5)
				+ Vector3.new(rnd(-1.2, 1.2), rnd(-1.2, 1.2), rnd(-1.2, 1.2))
			local largo = (sig - actual).Magnitude
			if largo > 0.05 then
				local seg = Instance.new("Part")
				seg.Anchored = true
				seg.CanCollide = false
				seg.CanQuery = false
				seg.CanTouch = false
				seg.CastShadow = false
				seg.Material = Enum.Material.Neon
				seg.Color = color
				seg.Size = Vector3.new(0.22, 0.22, largo)
				seg.CFrame = CFrame.lookAt(actual, sig) * CFrame.new(0, 0, -largo / 2)
				seg.Parent = carpeta
				Debris:AddItem(seg, 0.12)
			end
			actual = sig
		end
	end

	local function marcasSuelo(piso, carpeta)
		local y = piso + Vector3.new(0, 0.12, 0)
		for _ = 1, 14 do
			local ang = math.random() * math.pi * 2
			local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local largo = RADIO * rnd(0.5, 1.2)
			local ini = RADIO * 0.1
			local ancho = rnd(0.35, 0.9)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(70, 50, 72)
			p.Transparency = 0.3
			p.Size = Vector3.new(ancho, 0.05, 1)
			p.CFrame = CFrame.lookAt(y, y + dir) * CFrame.new(0, 0, -(ini + 0.5))
			p.Parent = carpeta
			TweenService:Create(
				p,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = Vector3.new(ancho, 0.05, largo),
					CFrame = CFrame.lookAt(y, y + dir) * CFrame.new(0, 0, -(ini + largo / 2)),
				}
			):Play()
			TweenService:Create(
				p,
				TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 4),
				{ Transparency = 1 }
			):Play()
			Debris:AddItem(p, 8)
		end
	end

	local function escombros(base, carpeta)
		for _ = 1, 30 do
			local p = Instance.new("Part")
			local tipo = math.random()
			local brillante = false
			if tipo < 0.4 then
				p.Size = Vector3.new(rnd(0.2, 0.5), 0.2, rnd(1.5, 4))
				p.Material = Enum.Material.Wood
				p.Color = Color3.fromRGB(math.random(150, 190), math.random(105, 135), math.random(70, 95))
			elseif tipo < 0.75 then
				local t = rnd(0.4, 1.5)
				p.Size = Vector3.new(t, t * rnd(0.4, 1), t)
				p.Material = Enum.Material.Slate
				p.Color = Color3.fromRGB(math.random(60, 100), math.random(55, 90), math.random(65, 100))
			else
				brillante = true
				local t = rnd(0.3, 0.9)
				p.Size = Vector3.new(t, t, t * rnd(1, 3))
				p.Material = Enum.Material.Neon
				p.Color = (math.random() < 0.5) and MAGENTA or VIOLETA
			end
			p.CanTouch = false
			p.CFrame = CFrame.new(base + Vector3.new(rnd(-1.5, 1.5), rnd(1, 3), rnd(-1.5, 1.5)))
				* CFrame.Angles(rnd(0, 6), rnd(0, 6), rnd(0, 6))
			p.Parent = carpeta

			local dir = Vector3.new(rnd(-1, 1), rnd(0.4, 1.4), rnd(-1, 1)).Unit
			p.AssemblyLinearVelocity = dir * rnd(40, 110)
			p.AssemblyAngularVelocity = Vector3.new(rnd(-1, 1), rnd(-1, 1), rnd(-1, 1)) * 25

			if brillante then
				emisor(p, {
					Texture = TEX_FUEGO,
					Color = cs({ 0, BLANCO }, { 0.4, MAGENTA }, { 1, Color3.fromRGB(60, 20, 90) }),
					Size = ns({ 0, 1.6 }, { 1, 0 }),
					Transparency = ns({ 0, 0 }, { 1, 1 }),
					Lifetime = NumberRange.new(0.3, 0.6),
					Speed = NumberRange.new(0, 2),
					LightEmission = 1,
					Rate = 40,
				}).Enabled = true
			else
				emisor(p, {
					Texture = TEX_HUMO,
					Color = ColorSequence.new(HUMO_OSCURO),
					Size = ns({ 0, 1.5 }, { 1, 5 }),
					Transparency = ns({ 0, 0.4 }, { 1, 1 }),
					Lifetime = NumberRange.new(0.8, 1.5),
					Speed = NumberRange.new(0, 2),
					Rate = 18,
				}).Enabled = true
			end
			Debris:AddItem(p, 5)
		end
	end

	-- Configs de partículas del hongo
	local function cfgFuegoCabeza(tam)
		return {
			Texture = TEX_FUEGO,
			-- blanco -> rosa claro -> magenta -> ciruela
			Color = cs({ 0, BLANCO }, { 0.12, ROSA_CLARO }, { 0.4, MAGENTA }, { 0.75, Color3.fromRGB(150, 30, 130) }, { 1, CIRUELA }),
			Size = ns({ 0, tam * 0.55 }, { 0.35, tam }, { 1, tam * 1.15 }),
			Transparency = ns({ 0, 0 }, { 0.65, 0.1 }, { 1, 1 }),
			Lifetime = NumberRange.new(1.3, 2.0),
			Speed = NumberRange.new(0, RADIO * 0.7),
			Drag = 3,
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			LightEmission = 0.3,
			LightInfluence = 0,
		}
	end

	local function cfgHumo(tam, claro, vida)
		return {
			Texture = TEX_HUMO,
			Color = cs({ 0, claro }, { 0.5, HUMO_CLARO }, { 1, HUMO_OSCURO }),
			Size = ns({ 0, tam * 0.5 }, { 0.4, tam }, { 1, tam * 1.3 }),
			Transparency = ns({ 0, 0.15 }, { 0.6, 0.2 }, { 1, 1 }),
			Lifetime = NumberRange.new(vida * 0.8, vida * 1.2),
			Speed = NumberRange.new(0, RADIO * 0.55),
			Drag = 2.5,
			SpreadAngle = Vector2.new(180, 180),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-20, 20),
			LightInfluence = 0.6,
		}
	end

	local function explotar(bomba)
		local pos = bomba.Position
		bomba:Destroy()

		local carpeta = obtenerCarpeta()
		local arriba = Vector3.new(0, 1, 0)

		local miChar = LocalPlayer.Character
		local hrp = miChar and miChar:FindFirstChild("HumanoidRootPart")
		local dist = hrp and (hrp.Position - pos).Magnitude or math.huge
		local cerca = math.clamp(1 - dist / (RADIO * 6), 0, 1)

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local filtro = { carpeta }
		if miChar then table.insert(filtro, miChar) end
		params.FilterDescendantsInstances = filtro
		local res = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -RADIO * 3, 0), params)
		local suelo = res and res.Position or nil
		local cercaSuelo = suelo ~= nil and (pos.Y - suelo.Y) <= RADIO * 1.5
		local enSuelo = suelo ~= nil and (pos.Y - suelo.Y) <= RADIO * 0.6
		local base = enSuelo and Vector3.new(pos.X, suelo.Y, pos.Z) or pos
		local centro = enSuelo and (base + arriba * (RADIO * 0.7)) or (pos + arriba * (RADIO * 0.15))

		-- Empuje físico (sin fuego naranja)
		local explosion = Instance.new("Explosion")
		explosion.Position = pos
		explosion.BlastRadius = RADIO
		explosion.BlastPressure = 200000
		explosion.DestroyJointRadiusPercent = 0
		explosion.ExplosionType = Enum.ExplosionType.NoCraters
		explosion.Visible = false
		explosion.Parent = workspace

		local ancla = parteAncla(pos, 10)

		-- Sonido
		sonido(ancla, SONIDO_BOOM, 3, 0.9)
		sonido(ancla, SONIDO_BOOM, 2.2, 0.5)
		task.delay(0.25, function()
			if ancla.Parent then sonido(ancla, SONIDO_BOOM, 1.6, 0.35) end
		end)

		-- ===== 0.0s: destello rosa-blanco (partículas, no esferas) + rayos =====
		bocanada(pos, {
			Texture = TEX_FUEGO,
			Color = cs({ 0, BLANCO }, { 0.5, ROSA_CLARO }, { 1, MAGENTA }),
			Size = ns({ 0, RADIO * 1.4 }, { 1, RADIO * 2.4 }),
			Transparency = ns({ 0, 0 }, { 0.5, 0.15 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.22, 0.3),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			LightEmission = 1,
			LightInfluence = 0,
		}, 3, 0, 2)
		bocanada(pos, {
			Texture = TEX_CHISPA,
			Color = cs({ 0, BLANCO }, { 1, ROSA_CLARO }),
			Size = ns({ 0, RADIO * 1.6 }, { 1, RADIO * 2.8 }),
			Transparency = ns({ 0, 0 }, { 1, 1 }),
			Lifetime = NumberRange.new(0.25, 0.35),
			Speed = NumberRange.new(0, 0),
			Rotation = NumberRange.new(0, 360),
			LightEmission = 1,
			LightInfluence = 0,
		}, 2, 0, 2)
		rayosEstrella(pos, carpeta)

		-- Luz dinámica
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 170, 235)
		luz.Range = RADIO * 3.5
		luz.Brightness = 30
		luz.Parent = ancla
		TweenService:Create(luz, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Brightness = 0, Range = RADIO }):Play()

		-- ===== 0.1s+: hongo de humo y fuego =====
		-- Columna que sube (tallo): bocanadas magenta a distintas alturas
		local altoTallo = centro.Y - base.Y
		for i = 1, 8 do
			local fr = i / 8
			bocanada(
				base + arriba * (1 + altoTallo * fr) + Vector3.new(rnd(-1.5, 1.5), 0, rnd(-1.5, 1.5)),
				cfgFuegoCabeza(RADIO * (0.5 - 0.15 * fr)),
				3, 0.05 + fr * 0.28, 6
			)
		end

		-- Cabeza de fuego: blanco -> rosa -> magenta -> ciruela
		for i = 1, 7 do
			local off = Vector3.new(rnd(-1, 1), rnd(-0.4, 0.8), rnd(-1, 1))
			bocanada(centro + off * (RADIO * 0.22), cfgFuegoCabeza(RADIO * rnd(0.8, 1.1)), 4, 0.1 + i * 0.04, 6)
		end

		-- Humo lavanda enorme y esponjoso alrededor de la cabeza
		for i = 1, 14 do
			local dir = Vector3.new(rnd(-1, 1), rnd(-0.1, 1), rnd(-1, 1)).Unit
			bocanada(
				centro + dir * (RADIO * rnd(0.25, 0.7)),
				cfgHumo(RADIO * rnd(0.9, 1.4), Color3.fromRGB(205, 180, 215), 5),
				4, 0.2 + i * 0.05, 9
			)
		end

		-- La cabeza se oscurece: núcleo de humo ciruela/gris
		bocanada(centro, cfgHumo(RADIO * 1.2, Color3.fromRGB(140, 85, 140), 4.5), 8, 1.1, 9)

		-- Falda oscura rosada pegada al suelo
		for _ = 1, 8 do
			local ang = math.random() * math.pi * 2
			local r = RADIO * rnd(0.2, 0.6)
			bocanada(
				base + Vector3.new(math.cos(ang) * r, rnd(1, 3), math.sin(ang) * r),
				{
					Texture = TEX_HUMO,
					Color = cs({ 0, MAGENTA }, { 0.4, Color3.fromRGB(150, 30, 125) }, { 1, Color3.fromRGB(70, 30, 80) }),
					Size = ns({ 0, RADIO * 0.3 }, { 0.5, RADIO * 0.6 }, { 1, RADIO * 0.8 }),
					Transparency = ns({ 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 }),
					Lifetime = NumberRange.new(2.0, 3.2),
					Speed = NumberRange.new(0, RADIO * 0.4),
					Drag = 2,
					SpreadAngle = Vector2.new(180, 180),
					Rotation = NumberRange.new(0, 360),
					LightInfluence = 0.5,
				},
				3, rnd(0.1, 0.4), 7
			)
		end

		-- Chispas / brasas de energía
		emisor(ancla, {
			Texture = TEX_CHISPA,
			Color = cs({ 0, BLANCO }, { 0.35, ROSA_CLARO }, { 1, VIOLETA }),
			Size = ns({ 0, 0.9 }, { 1, 0 }),
			Transparency = ns({ 0, 0 }, { 1, 1 }),
			Lifetime = NumberRange.new(1.2, 2.4),
			Speed = NumberRange.new(50, 130),
			Acceleration = Vector3.new(0, -45, 0),
			Drag = 0.5,
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
		}):Emit(120)

		-- Escombros con física
		escombros(base, carpeta)

		-- Arcos eléctricos sobre la nube
		task.spawn(function()
			local origenArco = centro
			for _ = 1, 14 do
				if not activo then return end
				task.wait(rnd(0.1, 0.32))
				local a = math.random() * math.pi * 2
				local d = math.random() * RADIO * 0.5
				rayoElectrico(origenArco + Vector3.new(math.cos(a) * d, rnd(-0.2, 0.5) * RADIO, math.sin(a) * d), carpeta)
			end
		end)

		-- Efectos pegados al suelo
		if cercaSuelo then
			local anclaSuelo = parteAncla(suelo + Vector3.new(0, 0.5, 0), 8)

			-- Anillos planos en el suelo + marcas
			anilloSuelo(suelo, BLANCO, RADIO * 2.4, 0.5, 0.2)
			anilloSuelo(suelo, MAGENTA, RADIO * 3.0, 0.7, 0.35)
			marcasSuelo(Vector3.new(pos.X, suelo.Y, pos.Z), carpeta)

			-- Polvo que sale en horizontal
			emisor(anclaSuelo, {
				Texture = TEX_HUMO,
				Color = ColorSequence.new(Color3.fromRGB(165, 145, 180)),
				Size = ns({ 0, 4 }, { 1, 18 }),
				Transparency = ns({ 0, 0.5 }, { 1, 1 }),
				Lifetime = NumberRange.new(2, 3.5),
				Speed = NumberRange.new(35, 65),
				Drag = 4,
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(85, 85),
				Rotation = NumberRange.new(0, 360),
				LightInfluence = 1,
			}):Emit(50)

			-- Llamas residuales rosas y humo fino
			local llamas = emisor(anclaSuelo, {
				Texture = TEX_FUEGO,
				Color = cs({ 0, Color3.fromRGB(255, 200, 235) }, { 0.5, ROSA }, { 1, Color3.fromRGB(60, 15, 80) }),
				Size = ns({ 0, 3 }, { 1, 0.5 }),
				Transparency = ns({ 0, 0.2 }, { 1, 1 }),
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(4, 10),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(40, 40),
				Acceleration = Vector3.new(0, 6, 0),
				LightEmission = 0.8,
				Rate = 18,
			})
			local humoFino = emisor(anclaSuelo, {
				Texture = TEX_HUMO,
				Color = ColorSequence.new(Color3.fromRGB(60, 45, 75)),
				Size = ns({ 0, 3 }, { 1, 9 }),
				Transparency = ns({ 0, 0.5 }, { 1, 1 }),
				Lifetime = NumberRange.new(3, 4),
				Speed = NumberRange.new(4, 9),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(25, 25),
				Acceleration = Vector3.new(0, 4, 0),
				LightInfluence = 1,
				Rate = 8,
			})
			llamas.Enabled = true
			humoFino.Enabled = true
			task.delay(2.5, function() llamas.Enabled = false end)
			task.delay(4, function() humoFino.Enabled = false end)

			-- Focos de fuego que quedan ardiendo: morado, rosa y magenta
			local paletas = {
				{ Color3.fromRGB(235, 190, 255), VIOLETA, Color3.fromRGB(60, 20, 110) },
				{ Color3.fromRGB(255, 205, 235), ROSA, Color3.fromRGB(90, 10, 70) },
				{ Color3.fromRGB(255, 170, 240), Color3.fromRGB(230, 0, 200), Color3.fromRGB(80, 0, 80) },
			}
			for i = 1, NUM_FOCOS do
				local ang = math.random() * math.pi * 2
				local d = math.random() * RADIO * 0.55
				local origen = suelo + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
				local hit = workspace:Raycast(origen + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
				local fogata = (hit and hit.Position or origen) + Vector3.new(0, 0.3, 0)
				local paleta = paletas[(i % 3) + 1]
				local tam = 3 + math.random() * 3

				local foco = parteAncla(fogata, DURACION_FUEGO + 4)
				local llama = emisor(foco, {
					Texture = TEX_FUEGO,
					Color = cs({ 0, paleta[1] }, { 0.45, paleta[2] }, { 1, paleta[3] }),
					Size = ns({ 0, tam }, { 0.6, tam * 0.7 }, { 1, 0 }),
					Transparency = ns({ 0, 0.1 }, { 0.8, 0.4 }, { 1, 1 }),
					Lifetime = NumberRange.new(0.7, 1.3),
					Speed = NumberRange.new(3, 8),
					EmissionDirection = Enum.NormalId.Top,
					SpreadAngle = Vector2.new(25, 25),
					Acceleration = Vector3.new(0, 8, 0),
					Rotation = NumberRange.new(0, 360),
					LightEmission = 0.9,
					Rate = 14,
				})
				local luzFuego = Instance.new("PointLight")
				luzFuego.Color = paleta[2]
				luzFuego.Range = 12
				luzFuego.Brightness = 0
				luzFuego.Parent = foco

				task.delay(math.random() * 1.4, function()
					if not foco.Parent then return end
					llama.Enabled = true
					local inicio = os.clock()
					local apagando = false
					while activo and foco.Parent and os.clock() - inicio < DURACION_FUEGO do
						if not apagando and os.clock() - inicio > DURACION_FUEGO - 3 then
							apagando = true
							TweenService:Create(llama, TweenInfo.new(3), { Rate = 0 }):Play()
						end
						if not apagando then
							luzFuego.Brightness = 1.5 + math.random() * 1.5
						else
							luzFuego.Brightness = luzFuego.Brightness * 0.9
						end
						task.wait(0.1)
					end
					llama.Enabled = false
					luzFuego.Brightness = 0
				end)
			end

			-- Cicatriz quemada (disco plano)
			local cicatriz = Instance.new("Part")
			cicatriz.Shape = Enum.PartType.Cylinder
			cicatriz.Anchored = true
			cicatriz.CanCollide = false
			cicatriz.CanQuery = false
			cicatriz.CanTouch = false
			cicatriz.Material = Enum.Material.SmoothPlastic
			cicatriz.Color = Color3.fromRGB(12, 8, 16)
			cicatriz.Transparency = 0.25
			cicatriz.Size = Vector3.new(0.15, RADIO * 1.1, RADIO * 1.1)
			cicatriz.CFrame = CFrame.new(suelo + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
			cicatriz.Parent = workspace
			TweenService:Create(
				cicatriz,
				TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 4),
				{ Transparency = 1 }
			):Play()
			Debris:AddItem(cicatriz, 11)
		end

		-- Cámara, pantalla y post-proceso
		sacudirCamara(2 * cerca, 1.8)
		destelloPantalla(cerca)
		efectosCine(cerca)
	end

	-- ===================== DIRECCION + PORTALES =====================
	local function calcularDireccion(hrp)
		local cam = workspace.CurrentCamera
		local marco = hrp.CFrame

		if MODO_LANZ == 2 and cam then
			marco = cam.CFrame
		end

		local v
		if MODO_LANZ == 3 then
			v = Vector3.new(DIR_X, DIR_Y, DIR_Z)
		else
			v = marco.LookVector * (1 + DIR_Z) + marco.RightVector * DIR_X + Vector3.new(0, DIR_Y, 0)
		end

		if v.Magnitude < 0.05 then
			v = hrp.CFrame.LookVector
		end
		return v.Unit
	end

	-- La bomba SOLO cruza portales en el Modo 1 con sus 2 portales abiertos.
	-- En el Modo 2 (6 portales) o con un destino de otro juego, los ignora.
	local function estadoPortales()
		if not ATRAVESAR then
			return false, "Portales: desactivado"
		end
		if Shared.GetDestino and Shared.GetDestino() then
			return false, "Portales: hay destino de otro juego"
		end
		local ps = Shared.Portals
		local n = ps and #ps or 0
		local modo = Shared.GetModo and Shared.GetModo() or 0
		if modo ~= 1 then
			return false, "Portales: bloqueados (solo Modo 1)"
		end
		if n ~= 2 then
			return false, "Modo 1: faltan portales (" .. n .. "/2)"
		end
		return true, "Portales: LISTOS (Modo 1, 2/2)"
	end

	-- Cruce con barrido: detecta el paso por el portal aunque la bomba vaya
	-- muy rapido (compara la posicion anterior con la actual, no solo un punto).
	local function cruzaPortal(e, p0, p1)
		if not (e and e.part and e.part.Parent) then
			return false
		end

		local c = e.position
		local f = e.face
		local tall = e.tallDir
		local side = f:Cross(tall)
		-- margen extra: la bomba tiene radio, no es un punto
		local hh = (e.measure and e.measure.height or 6) * 0.62 + 0.9
		local hw = (e.measure and e.measure.width or 6) * 0.62 + 0.9

		local d0 = (p0 - c):Dot(f)
		local d1 = (p1 - c):Dot(f)

		-- 1) el tramo p0 -> p1 atraviesa el plano del portal dentro de su elipse
		if (d0 > 0) ~= (d1 > 0) and math.abs(d0 - d1) > 1e-4 then
			local t = d0 / (d0 - d1)
			local q = p0:Lerp(p1, t) - c
			local u = q:Dot(tall) / hh
			local v = q:Dot(side) / hw
			if u * u + v * v <= 1 then
				return true
			end
		end

		-- 2) o se acerca al portal dentro de su zona de captura. La zona llega
		--    varios studs por delante: asi, en un portal pegado a la pared, la
		--    bomba se teletransporta ANTES de chocar y rebotar contra la pared.
		local rel = p1 - c
		local depth = d1
		if depth > -2.5 and depth < (e.enterDepth or 2.2) + 3 and d1 <= d0 + 0.02 then
			local u = rel:Dot(tall) / hh
			local v = rel:Dot(side) / hw
			if u * u + v * v <= 1 then
				return true
			end
		end

		return false
	end

	local function vigilarPortales(bomba)
		task.spawn(function()
			local dentro = true -- si nace dentro de un portal, primero debe salir
			local ultimo = os.clock()
			local prev = bomba.Position
			local bloqueado, tBloq = nil, 0

			while activo and bomba.Parent do
				RunService.Heartbeat:Wait()
				if not bomba.Parent then break end

				local actual = bomba.Position
				local cerca = nil
				local ps = Shared.Portals

				if ps and estadoPortales() then
					for i = 1, 2 do
						if not (ps[i] == bloqueado and os.clock() - tBloq < 1.5)
							and cruzaPortal(ps[i], prev, actual) then
							cerca = i
							break
						end
					end
				end

				prev = actual

				if not cerca then
					dentro = false
				elseif not dentro and os.clock() - ultimo > 0.25 then
					local destino = ps[cerca % 2 + 1]
					if destino and destino.part and destino.part.Parent then
						local rapidez = math.max(bomba.AssemblyLinearVelocity.Magnitude, 35)
						dentro = true
						ultimo = os.clock()
						bomba.CFrame = CFrame.new(destino.exit)
						bomba.AssemblyLinearVelocity = destino.face * rapidez
						prev = destino.exit
						bloqueado = destino
						tBloq = os.clock()
						if Shared.PlaySound then
							pcall(Shared.PlaySound, Shared.SOUND_ENTER, destino.part)
						end
					end
				end
			end
		end)
	end

	-- ===================== PUNTERO (rayo rosa + disco en el suelo) =====================
	local COLOR_RAYO = Color3.fromRGB(255, 45, 200)
	local COLOR_DISCO = Color3.fromRGB(255, 130, 255)
	local PUNTERO = true
	local carpetaPuntero = nil
	local segmentos = {}
	local disco = nil

	local function asegurarPuntero()
		if carpetaPuntero and carpetaPuntero.Parent then return end

		carpetaPuntero = Instance.new("Folder")
		carpetaPuntero.Name = "BombaPuntero"
		carpetaPuntero.Parent = workspace
		segmentos = {}

		disco = Instance.new("Part")
		disco.Shape = Enum.PartType.Cylinder
		disco.Size = Vector3.new(0.15, 5.5, 5.5)
		disco.Material = Enum.Material.Neon
		disco.Color = COLOR_DISCO
		disco.Anchored = true
		disco.CanCollide = false
		disco.CanQuery = false
		disco.CanTouch = false
		disco.CastShadow = false
		disco.Transparency = 1
		disco.Parent = carpetaPuntero

		local luz = Instance.new("PointLight")
		luz.Color = COLOR_DISCO
		luz.Range = 14
		luz.Brightness = 2
		luz.Parent = disco
	end

	local function segmento(i)
		local s = segmentos[i]
		if not s then
			s = Instance.new("Part")
			s.Material = Enum.Material.Neon
			s.Color = COLOR_RAYO
			s.Size = Vector3.new(0.3, 0.3, 1)
			s.Anchored = true
			s.CanCollide = false
			s.CanQuery = false
			s.CanTouch = false
			s.CastShadow = false
			s.Transparency = 1
			s.Parent = carpetaPuntero
			segmentos[i] = s
		end
		return s
	end

	local function ocultarPuntero()
		if not (carpetaPuntero and carpetaPuntero.Parent) then return end
		for _, s in ipairs(segmentos) do s.Transparency = 1 end
		disco.Transparency = 1
	end

	local function actualizarPuntero()
		if not activo then return end

		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")

		if not (PUNTERO and tool and tool.Parent == char and hrp) then
			ocultarPuntero()
			return
		end

		asegurarPuntero()

		local dir = calcularDireccion(hrp)
		local pos = hrp.Position + Vector3.new(0, 1.5, 0) + dir * 4
		local vel = dir * (FUERZA * (LEJOS and FACTOR_LEJOS or 1))
			+ Vector3.new(0, ELEVACION * (LEJOS and 1.4 or 1), 0)
		local g = Vector3.new(0, -workspace.Gravity, 0)

		local usaPortales = estadoPortales()
		local ps = Shared.Portals

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char, carpetaPuntero }

		local dt = 0.05
		local pasos = math.clamp(math.ceil(TIEMPO_MECHA / dt), 10, 120)
		local pts = { pos }
		local corte = {}
		local impacto = nil
		local saltos = 0
		local t = 0
		local bloq, tBloq = nil, -10

		for _ = 1, pasos do
			t += dt
			local nvel = vel + g * dt
			local npos = pos + vel * dt + g * (0.5 * dt * dt)

			local r = workspace:Raycast(pos, npos - pos, params)
			if r then
				impacto = r
				table.insert(pts, r.Position)
				break
			end

			if usaPortales and ps and saltos < 4 then
				for k = 1, 2 do
					if not (ps[k] == bloq and t - tBloq < 1.5) and cruzaPortal(ps[k], pos, npos) then
						local d = ps[k % 2 + 1]
						if d and d.part and d.part.Parent then
							saltos += 1
							npos = d.exit
							nvel = d.face * math.max(nvel.Magnitude, 35)
							table.insert(pts, npos)
							corte[#pts] = true
							bloq, tBloq = d, t
						end
						break
					end
				end
			end

			pos, vel = npos, nvel
			table.insert(pts, pos)
		end

		local n = #pts
		local handle = tool:FindFirstChild("Handle")
		local origen = handle and handle.Position or pts[1]

		local usados = 0
		local function trazo(a, b)
			local len = (b - a).Magnitude
			if len < 0.02 then return end
			usados += 1
			local s = segmento(usados)
			s.Size = Vector3.new(0.3, 0.3, len)
			s.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
			s.Transparency = 0
		end

		trazo(origen, pts[1])
		for i = 2, n do
			if not corte[i] then
				trazo(pts[i - 1], pts[i])
			end
		end
		for i = usados + 1, #segmentos do
			segmentos[i].Transparency = 1
		end

		if impacto then
			local normal = impacto.Normal
			local ref = (math.abs(normal.X) < 0.9) and Vector3.xAxis or Vector3.zAxis
			local tang = normal:Cross(ref).Unit
			disco.CFrame = CFrame.fromMatrix(impacto.Position + normal * 0.1, normal, tang)
			disco.Transparency = 0.35
		else
			disco.Transparency = 1
		end
	end

	conectar(RunService.RenderStepped, actualizarPuntero)

	-- ===================== LANZAR =====================
	local function lanzar(handleOriginal)
		if not activo then return false end
		if os.clock() - ultimoUso < COOLDOWN then return false end
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end
		ultimoUso = os.clock()

		local bomba = handleOriginal:Clone()
		bomba.Name = "BombaLanzada"
		bomba.CanCollide = true
		bomba.Anchored = false
		bomba.CustomPhysicalProperties = PhysicalProperties.new(1, 0.6, 0.3)
		local dirLanz = calcularDireccion(hrp)
		bomba.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 1.5, 0) + dirLanz * 4)
		bomba.Parent = workspace
		local fuerzaReal = FUERZA * (LEJOS and FACTOR_LEJOS or 1)
		local elevReal = ELEVACION * (LEJOS and 1.4 or 1)
		bomba.AssemblyLinearVelocity = dirLanz * fuerzaReal + Vector3.new(0, elevReal, 0)
		bombas[bomba] = true
		vigilarPortales(bomba)

		task.spawn(function()
			local inicio = os.clock()
			local luz = bomba:FindFirstChildOfClass("PointLight")
			while activo and bomba.Parent and os.clock() - inicio < TIEMPO_MECHA do
				local progreso = (os.clock() - inicio) / TIEMPO_MECHA
				local espera = 0.4 - 0.33 * progreso
				for _, parte in ipairs(bomba:GetChildren()) do
					if parte.Name == "Ojo" then parte.Color = BLANCO end
				end
				if luz then luz.Brightness = 4 end
				sonido(bomba, SONIDO_BEEP, 0.7, 0.8 + 0.9 * progreso)
				task.wait(espera / 2)
				if not bomba.Parent then break end
				for _, parte in ipairs(bomba:GetChildren()) do
					if parte.Name == "Ojo" then parte.Color = ROSA_OJO end
				end
				if luz then luz.Brightness = 1 end
				task.wait(espera / 2)
			end
			bombas[bomba] = nil
			if activo and bomba.Parent then
				pcall(explotar, bomba)
			end
		end)

		return true
	end

	-- ===================== TOOL =====================
	local function darTool()
		if not activo then return end
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
			or LocalPlayer:WaitForChild("Backpack", 5)
		if not backpack then return end

		if tool then
			pcall(function() tool:Destroy() end)
			tool = nil
		end

		local t = Instance.new("Tool")
		t.Name = NOMBRE_TOOL
		t.RequiresHandle = true
		t.CanBeDropped = false
		t.ToolTip = "Clic para lanzar"
		tool = t

		local handle = crearHandle()
		handle.Parent = t

		conectar(t.Activated, function()
			if tool ~= t then return end
			if lanzar(handle) then
				tool = nil
				pcall(function() t:Destroy() end)
				task.delay(COOLDOWN, function()
					if activo then darTool() end
				end)
			end
		end)

		t.Parent = backpack
	end

	-- ===================== INTERFAZ DE LA BOMBA =====================
	local uiObjetos = {}
	local ASSET_BOMBA = 82398905680280 -- Rick Prime's Bomb
	local NOMBRES_MODO = { "Frente del personaje", "Cámara", "Ejes del mundo" }

	local function crearInterfaz()
		local espera = os.clock()
		while activo and not (Shared.MenuGui and Shared.MenuGui.Parent and Shared.MakeStepper)
			and os.clock() - espera < 30 do
			task.wait(0.1)
		end
		if not activo then return end
		if not (Shared.MenuGui and Shared.MakeStepper) then
			warn("[BOMBA] No se encontró el menú de portales; no se creó la interfaz de la bomba.")
			return
		end

		local gui = Shared.MenuGui
		local C = Shared.Colores
		local MakeStepper, MakeButton, MakeLabel = Shared.MakeStepper, Shared.MakeButton, Shared.MakeLabel
		local Refreshers = Shared.Refreshers
		local BLANCO_TXT = Color3.new(1, 1, 1)

		-- Panel
		local panel = Instance.new("Frame")
		panel.Name = "BombaPanel"
		panel.Position = UDim2.new(0.5625, 0, 0.105, 0)
		panel.Size = UDim2.new(0.3125, 0, 0.88, 0)
		panel.BackgroundColor3 = C.PANEL_BG
		panel.BorderSizePixel = 0
		panel.Active = true
		panel.Visible = false
		panel.Parent = gui
		Shared.EstilizarPanel(panel)
		table.insert(uiObjetos, panel)
		Shared.BombaPanel = panel

		local titulo = Instance.new("TextLabel")
		titulo.BackgroundTransparency = 1
		titulo.Position = UDim2.new(0, 14, 0, 6)
		titulo.Size = UDim2.new(1, -70, 0, 36)
		titulo.Text = "Bomba  -  Control"
		titulo.TextColor3 = BLANCO_TXT
		titulo.Font = Enum.Font.GothamBold
		titulo.TextScaled = true
		titulo.TextXAlignment = Enum.TextXAlignment.Left
		titulo.Parent = panel
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 22
		tc.MinTextSize = 10
		tc.Parent = titulo

		local cerrar = Instance.new("TextButton")
		cerrar.AnchorPoint = Vector2.new(1, 0)
		cerrar.Position = UDim2.new(1, -8, 0, 8)
		cerrar.Size = UDim2.new(0, 44, 0, 32)
		cerrar.BackgroundColor3 = C.RED
		cerrar.Text = "X"
		cerrar.TextColor3 = BLANCO_TXT
		cerrar.Font = Enum.Font.GothamBold
		cerrar.TextScaled = true
		cerrar.Parent = panel
		Shared.Round(6, cerrar)
		cerrar.Activated:Connect(function()
			panel.Visible = false
		end)

		local pagina = Instance.new("ScrollingFrame")
		pagina.Position = UDim2.new(0, 8, 0, 54)
		pagina.Size = UDim2.new(1, -16, 1, -62)
		pagina.BackgroundTransparency = 1
		pagina.BorderSizePixel = 0
		pagina.ScrollBarThickness = 4
		pagina.CanvasSize = UDim2.new(0, 0, 0, 0)
		pagina.AutomaticCanvasSize = Enum.AutomaticSize.Y
		pagina.Parent = panel
		local lay = Instance.new("UIListLayout")
		lay.Padding = UDim.new(0, 6)
		lay.SortOrder = Enum.SortOrder.LayoutOrder
		lay.Parent = pagina

		local function refrescarTodo()
			for _, fn in ipairs(Refreshers) do
				pcall(fn)
			end
		end

		-- Direccion
		MakeLabel(pagina, "Dirección del lanzamiento:", 1, 30, true)

		local btnModo = MakeButton(pagina, "", 2, 44, C.BTN_BG)
		btnModo.Activated:Connect(function()
			MODO_LANZ = MODO_LANZ % 3 + 1
			refrescarTodo()
		end)
		table.insert(Refreshers, function()
			btnModo.Text = "Modo: " .. NOMBRES_MODO[MODO_LANZ]
		end)

		MakeStepper(pagina, "Eje X (lado)", 3,
			function() return DIR_X end, function(v) DIR_X = v end, 0.25, -5, 5, "%.2f")
		MakeStepper(pagina, "Eje Y (altura)", 4,
			function() return DIR_Y end, function(v) DIR_Y = v end, 0.25, -5, 5, "%.2f")
		MakeStepper(pagina, "Eje Z (adelante)", 5,
			function() return DIR_Z end, function(v) DIR_Z = v end, 0.25, -5, 5, "%.2f")

		-- Distancia / potencia
		local btnLejos = MakeButton(pagina, "", 6, 44, C.BTN_BG)
		btnLejos.Activated:Connect(function()
			LEJOS = not LEJOS
			refrescarTodo()
		end)
		table.insert(Refreshers, function()
			btnLejos.Text = LEJOS and "Lanzar lejos: SÍ" or "Lanzar lejos: NO"
			btnLejos.BackgroundColor3 = LEJOS and C.GREEN or C.BTN_BG
		end)

		MakeStepper(pagina, "Factor lejos", 7,
			function() return FACTOR_LEJOS end, function(v) FACTOR_LEJOS = v end, 0.5, 1.5, 6, "%.1f")
		MakeStepper(pagina, "Fuerza", 8,
			function() return FUERZA end, function(v) FUERZA = v end, 10, 10, 400, "%.0f")
		MakeStepper(pagina, "Elevación", 9,
			function() return ELEVACION end, function(v) ELEVACION = v end, 5, 0, 150, "%.0f")
		MakeStepper(pagina, "Mecha (s)", 10,
			function() return TIEMPO_MECHA end, function(v) TIEMPO_MECHA = v end, 0.5, 1, 10, "%.1f")
		MakeStepper(pagina, "Enfriamiento (s)", 11,
			function() return COOLDOWN end, function(v) COOLDOWN = v end, 1, 1, 15, "%.0f")
		MakeStepper(pagina, "Radio explosión", 12,
			function() return RADIO end, function(v) RADIO = v end, 5, 5, 60, "%.0f")

		-- Portales
		local btnPortal = MakeButton(pagina, "", 13, 44, C.BTN_BG)
		btnPortal.Activated:Connect(function()
			ATRAVESAR = not ATRAVESAR
			refrescarTodo()
		end)
		table.insert(Refreshers, function()
			btnPortal.Text = ATRAVESAR and "Atravesar portales: SÍ" or "Atravesar portales: NO"
			btnPortal.BackgroundColor3 = ATRAVESAR and C.GREEN or C.BTN_BG
		end)

		local estado = MakeLabel(pagina, "", 14, 36, true)
		table.insert(Refreshers, function()
			local ok, texto = estadoPortales()
			estado.Text = texto
			estado.TextColor3 = ok and Color3.fromRGB(110, 230, 160) or Color3.fromRGB(150, 175, 230)
		end)

		local btnPunt = MakeButton(pagina, "", 15, 44, C.BTN_BG)
		btnPunt.Activated:Connect(function()
			PUNTERO = not PUNTERO
			refrescarTodo()
		end)
		table.insert(Refreshers, function()
			btnPunt.Text = PUNTERO and "Puntero rosa: SÍ" or "Puntero rosa: NO"
			btnPunt.BackgroundColor3 = PUNTERO and C.GREEN or C.BTN_BG
		end)

		local btnReset = MakeButton(pagina, "Restablecer valores", 16, 44, C.DARK_RED)
		btnReset.Activated:Connect(function()
			PUNTERO = true
			DIR_X, DIR_Y, DIR_Z = 0, 0, 0
			LEJOS = false
			FACTOR_LEJOS = 2.5
			MODO_LANZ = 1
			ATRAVESAR = true
			FUERZA = 60
			ELEVACION = 30
			TIEMPO_MECHA = 3
			COOLDOWN = 4
			RADIO = 20
			refrescarTodo()
		end)

		-- Boton del menu de la bomba (asset 82398905680280)
		local boton = Instance.new("ImageButton")
		boton.Name = "BombaButton"
		boton.AnchorPoint = Vector2.new(0, 0.5)
		boton.Position = UDim2.new(0.885, 0, 0.66, 0)
		boton.Size = UDim2.new(0.058, 0, 0.1, 0)
		boton.BackgroundColor3 = C.PANEL_BG
		boton.Image = "rbxthumb://type=Asset&id=" .. ASSET_BOMBA .. "&w=150&h=150"
		boton.ScaleType = Enum.ScaleType.Fit
		boton.AutoButtonColor = true
		boton.Parent = gui
		Shared.Round(12, boton)
		Shared.AddStroke(boton, C.GREEN, 2)
		table.insert(uiObjetos, boton)

		local rotulo = Instance.new("TextLabel")
		rotulo.BackgroundTransparency = 1
		rotulo.AnchorPoint = Vector2.new(0, 1)
		rotulo.Position = UDim2.new(0, 0, 1, 0)
		rotulo.Size = UDim2.new(1, 0, 0.28, 0)
		rotulo.Text = "BOMBA"
		rotulo.TextColor3 = BLANCO_TXT
		rotulo.TextStrokeTransparency = 0.2
		rotulo.Font = Enum.Font.GothamBold
		rotulo.TextScaled = true
		rotulo.Parent = boton

		boton.Activated:Connect(function()
			panel.Visible = not panel.Visible
			if panel.Visible then
				if Shared.OcultarPrincipal then Shared.OcultarPrincipal() end
				refrescarTodo()
			end
		end)

		refrescarTodo()
	end

	task.spawn(crearInterfaz)


	darTool()

	conectar(LocalPlayer.CharacterAdded, function()
		task.wait(0.6)
		darTool()
	end)

	env.BombaStop = function()
		activo = false
		for _, c in ipairs(todas) do pcall(function() c:Disconnect() end) end
		todas = {}
		for b in pairs(bombas) do pcall(function() b:Destroy() end) end
		bombas = {}
		if carpetaFX then pcall(function() carpetaFX:Destroy() end) carpetaFX = nil end
		if tool then pcall(function() tool:Destroy() end) tool = nil end
		for _, o in ipairs(uiObjetos) do pcall(function() o:Destroy() end) end
		uiObjetos = {}
		if carpetaPuntero then pcall(function() carpetaPuntero:Destroy() end) carpetaPuntero = nil end
	end

	print("[BOMBA] Cargada. Busca '" .. NOMBRE_TOOL .. "' en tu inventario.")
end


--##########################################################################
-- MÓDULO 5: PROTOCOLO FÉNIX (hasta 4 cápsulas)
-- Solo actúa cuando RICK PRIME está en OFF (usa el mismo interruptor).
-- P = colocar cápsula | O = abrir/cerrar la más cercana
--##########################################################################
local function MODULO_FENIX()
	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	local jugador = Players.LocalPlayer
	local playerGui = jugador:WaitForChild("PlayerGui")

	-- Anti-duplicados
	local env = (getgenv and getgenv()) or _G
	if env.PHOENIX_LIMPIAR then
		pcall(env.PHOENIX_LIMPIAR)
	end

	local conexiones = {}
	local function con(senal, fn)
		local c = senal:Connect(fn)
		table.insert(conexiones, c)
		return c
	end

	-- ===== TAMAÑO (solo cambia RADIO, todo lo demás escala) =====
	local RADIO = 4
	-- ============================================================

	-- ===== COLOR DEL CRISTAL =====
	local COLOR_VIDRIO = Color3.fromRGB(90, 215, 150)
	local TRANSPARENCIA_VIDRIO = 0.55
	-- =============================

	local TAM_CIRCULO = 70
	local MAX_CAPSULAS = 4
	local ESPERA_ABRIR = 1.5

	local ALTO = RADIO * 3.68
	local ALT_FALDA = 1.0
	local ALT_MEDIA = 0.9
	local ALT_TOPE = 0.7
	local ALT_DISCO = 0.4
	local PISO = ALT_FALDA + ALT_MEDIA + ALT_TOPE + ALT_DISCO

	local SUBIDA_TAPA = RADIO * 1.9

	local TECLA_DESPLEGAR = Enum.KeyCode.P
	local TECLA_ABRIR = Enum.KeyCode.O
	local DISTANCIA_FRENTE = 14
	local SEPARACION_MIN = RADIO * 3.5   -- distancia mínima entre cápsulas

	local COLOR_FONDO = Color3.fromRGB(10, 10, 10)
	local COLOR_ROJO = Color3.fromRGB(200, 20, 30)
	local COLOR_VERDE = Color3.fromRGB(0, 200, 90)

	local COLOR_LUZ = Color3.fromRGB(90, 230, 110)

	local VERT = CFrame.Angles(0, 0, math.rad(90))

	local cola = {}               -- cápsulas colocadas, en orden (1 = la primera)
	local capsulaUso = nil        -- cápsula donde estás reviviendo
	local regenerando = false
	local murio = false
	local murioConFenix = false   -- se decide al MORIR según el interruptor de RICK PRIME
	local secuencia = 0

	local mensaje, mensajeHasta = nil, 0
	local function aviso(texto)
		mensaje = texto
		mensajeHasta = os.clock() + 1.5
	end

	-- Utilidades
	local function tween(obj, t, props)
		local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local tw = TweenService:Create(obj, info, props)
		tw:Play()
		return tw
	end

	local function obtenerSueloY(pos, char)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = char and { char } or {}
		params.IgnoreWater = true

		local r = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -500, 0), params)
		if r then
			return r.Position.Y
		end
		return pos.Y - 3
	end

	-- Construcción de la cápsula
	local function parte(modelo, forma, size, cf, color, material, transp, colisiona)
		local p = Instance.new("Part")
		p.Shape = forma
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Transparency = transp
		p.Reflectance = 0
		p.Anchored = true
		p.CanCollide = colisiona or false
		p.CanQuery = false
		p.CastShadow = false
		p.Parent = modelo
		return p
	end

	local function crearCapsula(origen, colisionInicial)
		local m = Instance.new("Model")
		m.Name = "PhoenixCapsule"

		local cil = Enum.PartType.Cylinder
		local bola = Enum.PartType.Ball
		local blq = Enum.PartType.Block
		local SP = Enum.Material.SmoothPlastic
		local R = RADIO
		local D = R * 2

		local function cilV(alto, diam, y, color, transp, colisiona)
			return parte(m, cil, Vector3.new(alto, diam, diam),
				origen * CFrame.new(0, y, 0) * VERT,
				color, SP, transp, colisiona)
		end

		-- BASE ancha (3 capas, con colisión)
		cilV(ALT_FALDA, D * 1.65, ALT_FALDA / 2,
			Color3.fromRGB(32, 38, 40), 0, true)
		cilV(ALT_MEDIA, D * 1.5, ALT_FALDA + ALT_MEDIA / 2,
			Color3.fromRGB(52, 64, 62), 0, true)
		cilV(ALT_TOPE, D * 1.35, ALT_FALDA + ALT_MEDIA + ALT_TOPE / 2,
			Color3.fromRGB(64, 78, 74), 0, true)

		-- Rayitas verdes del frente de la base
		for _, ang in ipairs({ -49, -10, 17, 50 }) do
			parte(m, blq, Vector3.new(0.15, 0.75, 0.1),
				origen * CFrame.Angles(0, math.rad(ang), 0)
					* CFrame.new(0, ALT_FALDA + ALT_MEDIA / 2, -(D * 0.75 + 0.02)),
				Color3.fromRGB(120, 225, 150), SP, 0)
		end

		-- DISCO MENTA DEL PISO
		cilV(ALT_DISCO, D * 0.9, PISO - ALT_DISCO / 2,
			Color3.fromRGB(95, 210, 185), 0, true)

		-- LUCES AMBAR (afuera del cristal, sobre la base)
		local yTope = ALT_FALDA + ALT_MEDIA + ALT_TOPE
		for _, lado in ipairs({ -1, 1 }) do
			local a = math.rad(35) * lado
			local r = R * 1.19
			local p = Vector3.new(math.sin(a) * r, yTope + 0.55, -math.cos(a) * r)
			local out = Vector3.new(p.X, 0, p.Z)
			local cf = origen * CFrame.lookAt(p, p + out)

			parte(m, blq, Vector3.new(1.3, 1.1, 1.0), cf,
				Color3.fromRGB(45, 52, 50), SP, 0, true)

			for _, dx in ipairs({ -0.25, 0.25 }) do
				parte(m, blq, Vector3.new(0.3, 0.7, 0.1),
					cf * CFrame.new(dx, 0, -0.52),
					Color3.fromRGB(240, 180, 60), SP, 0)
			end
		end

		-- PILARES (afuera del cristal, con colisión)
		local pilarH = R * 2.95
		local pw = R * 0.21
		local luces = {}
		local largoPilar = pilarH - pw / 2 + ALT_DISCO

		for _, lado in ipairs({ -1, 1 }) do
			local x = lado * (R + pw * 0.35)
			local colorPilar = Color3.fromRGB(70, 160, 145)

			parte(m, cil, Vector3.new(largoPilar, pw, pw),
				origen * CFrame.new(x, yTope + largoPilar / 2, 0) * VERT,
				colorPilar, SP, 0, true)

			parte(m, bola, Vector3.new(pw, pw, pw),
				origen * CFrame.new(x, PISO + pilarH - pw / 2, 0),
				colorPilar, SP, 0, true)

			-- Cara del pilar que mira al centro de la cápsula
			local dentro = -lado * (pw / 2 - 0.05)

			for _, f in ipairs({ { 0.93, 0.88 }, { 0.53, 0.44 } }) do
				parte(m, blq, Vector3.new(0.25, 1.1, pw * 0.5),
					origen * CFrame.new(x + dentro, PISO + pilarH * f[2], 0),
					Color3.fromRGB(40, 90, 88), SP, 0)

				local luz = parte(m, bola, Vector3.new(0.5, 0.5, 0.5),
					origen * CFrame.new(x + dentro, PISO + pilarH * f[1], 0),
					COLOR_LUZ, SP, 0)
				table.insert(luces, luz)
			end
		end

		-- CRISTAL VERDE TRANSPARENTE
		local vidrio = {}

		table.insert(vidrio, parte(m, cil, Vector3.new(ALTO, D, D),
			origen * CFrame.new(0, PISO + ALTO / 2, 0) * VERT,
			COLOR_VIDRIO, SP, TRANSPARENCIA_VIDRIO, colisionInicial))

		table.insert(vidrio, parte(m, bola, Vector3.new(D, D, D),
			origen * CFrame.new(0, PISO + ALTO, 0),
			COLOR_VIDRIO, SP, TRANSPARENCIA_VIDRIO, colisionInicial))

		table.insert(vidrio, cilV(0.2, D + 0.2, PISO + 0.1,
			Color3.fromRGB(80, 200, 140), 0.35, false))

		local cerrado = {}
		for _, p in ipairs(vidrio) do
			cerrado[p] = p.CFrame
		end

		local pl = Instance.new("PointLight")
		pl.Color = Color3.fromRGB(110, 230, 160)
		pl.Range = 12
		pl.Brightness = 0.6
		pl.Parent = vidrio[1]

		m.Parent = workspace

		return {
			modelo = m,
			vidrio = vidrio,
			cerrado = cerrado,
			luces = luces,
			origen = origen,
			abierta = false,
			moviendo = false,
			vigia = 0,
		}
	end

	local function destruirCapsula(c)
		if c and c.modelo and c.modelo.Parent then
			c.modelo:Destroy()
		end
	end

	-- Colisión del cristal (cuerpo + cúpula)
	local function fijarColision(c, valor)
		if c.vidrio[1] then c.vidrio[1].CanCollide = valor end
		if c.vidrio[2] then c.vidrio[2].CanCollide = valor end
	end

	-- Enciende la colisión del cristal solo cuando tú no estás adentro
	local function vigilarColision(c)
		c.vigia += 1
		local id = c.vigia

		task.spawn(function()
			while c.modelo.Parent and not c.abierta and not c.moviendo and c.vigia == id do
				local char = jugador.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local dentro = false

				if hrp then
					local rel = c.origen:PointToObjectSpace(hrp.Position)
					local horiz = Vector3.new(rel.X, 0, rel.Z).Magnitude
					dentro = horiz < RADIO + 1.5
						and rel.Y > -1
						and rel.Y < PISO + ALTO + RADIO
				end

				if not dentro then
					fijarColision(c, true)
					return
				end

				task.wait(0.2)
			end
		end)
	end

	-- Animaciones
	local function parpadearLuces(c, veces)
		task.spawn(function()
			for _ = 1, veces do
				if not c.modelo.Parent then return end
				for _, l in ipairs(c.luces) do
					l.Color = Color3.fromRGB(255, 255, 255)
				end
				task.wait(0.12)
				if not c.modelo.Parent then return end
				for _, l in ipairs(c.luces) do
					l.Color = COLOR_LUZ
				end
				task.wait(0.12)
			end
		end)
	end

	local function abrirCapsula(c)
		if not c or c.abierta or c.moviendo or not c.modelo.Parent then
			return
		end
		c.abierta = true
		c.moviendo = true
		fijarColision(c, false)

		for _, p in ipairs(c.vidrio) do
			tween(p, 1.6, { CFrame = c.cerrado[p] + Vector3.new(0, SUBIDA_TAPA, 0) })
		end

		task.delay(1.7, function()
			c.moviendo = false
		end)
	end

	local function cerrarCapsula(c)
		if not c or not c.abierta or c.moviendo or not c.modelo.Parent then
			return
		end
		c.moviendo = true

		for _, p in ipairs(c.vidrio) do
			tween(p, 1.6, { CFrame = c.cerrado[p] })
		end

		task.delay(1.7, function()
			c.abierta = false
			c.moviendo = false
			if c.modelo.Parent then
				vigilarColision(c)
			end
		end)
	end

	-- Cápsula más cercana a ti (para el botón ABRIR)
	local function capsulaCercana()
		local lista = {}
		for _, c in ipairs(cola) do
			if c.modelo.Parent then
				table.insert(lista, c)
			end
		end
		if capsulaUso and capsulaUso.modelo.Parent then
			table.insert(lista, capsulaUso)
		end
		if #lista == 0 then
			return nil
		end

		local char = jugador.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return lista[#lista]
		end

		local mejor, mejorDist = nil, math.huge
		for _, c in ipairs(lista) do
			local d = (c.origen.Position - hrp.Position).Magnitude
			if d < mejorDist then
				mejor, mejorDist = c, d
			end
		end
		return mejor
	end

	local function alternarCapsula()
		local c = capsulaCercana()
		if not c then
			aviso("SIN\nCÁPSULA")
			return
		end

		if c.abierta then
			cerrarCapsula(c)
		else
			abrirCapsula(c)
		end
	end

	-- Colocar una cápsula (hasta 4)
	local function desplegarManual()
		if #cola >= MAX_CAPSULAS then
			aviso("LLENO\n" .. MAX_CAPSULAS .. "/" .. MAX_CAPSULAS)
			return
		end

		local char = jugador.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		local look = hrp.CFrame.LookVector
		local plano = Vector3.new(look.X, 0, look.Z)
		if plano.Magnitude < 0.01 then
			plano = Vector3.new(0, 0, -1)
		end
		plano = plano.Unit

		local pos = hrp.Position + plano * DISTANCIA_FRENTE

		-- Evita encimar cápsulas
		local todas = {}
		for _, c in ipairs(cola) do table.insert(todas, c) end
		if capsulaUso then table.insert(todas, capsulaUso) end

		for _, c in ipairs(todas) do
			if c.modelo.Parent then
				local o = c.origen.Position
				local d = Vector3.new(o.X - pos.X, 0, o.Z - pos.Z).Magnitude
				if d < SEPARACION_MIN then
					aviso("MUY\nCERCA")
					return
				end
			end
		end

		local sueloY = obtenerSueloY(pos, char)
		local base = Vector3.new(pos.X, sueloY, pos.Z)
		local origen = CFrame.lookAt(base, base - plano)

		table.insert(cola, crearCapsula(origen, true))
		print("[PHOENIX] Cápsula " .. #cola .. "/" .. MAX_CAPSULAS .. " colocada")
	end

	-- Quitar la última cápsula colocada
	local function quitarUltima()
		local c = table.remove(cola)
		if not c then
			aviso("SIN\nCÁPSULA")
			return
		end
		destruirCapsula(c)
	end

	-- ¿Está activada la regeneración de Rick Prime? (lee su interruptor real)
	-- Si el módulo de Rick Prime no está disponible, cuenta como DESACTIVADA.
	local function rickActivo()
		local f = Shared.RickActivo
		if f then
			local ok, v = pcall(f)
			if ok then
				return v == true
			end
		end
		return false
	end

	-- Y del punto más bajo de los pies (para apoyar al personaje en el piso interior)
	local function pieY(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local nombres = { "Left Leg", "Right Leg" }
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then
			nombres = { "LeftFoot", "RightFoot", "LeftLowerLeg", "RightLowerLeg" }
		end
		local minY = nil
		for _, n in ipairs(nombres) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				local y = p.Position.Y - p.Size.Y / 2
				if not minY or y < minY then
					minY = y
				end
			end
		end
		if not minY then
			local bbCF, bbSize = char:GetBoundingBox()
			minY = bbCF.Position.Y - bbSize.Y / 2
		end
		return minY
	end

	-- Cara superior del disco menta del piso (el suelo interior real de la cápsula)
	local function sueloInterior(c)
		return c.origen:PointToWorldSpace(Vector3.new(0, PISO, 0))
	end

	-- ¿El personaje está de verdad dentro del cristal? (eje central, sobre el disco, bajo la cúpula)
	local function estaDentro(char, c)
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return false
		end
		local rel = c.origen:PointToObjectSpace(hrp.Position)
		local horiz = Vector3.new(rel.X, 0, rel.Z).Magnitude
		return horiz <= RADIO - 1.5 and rel.Y >= PISO and rel.Y <= PISO + ALTO
	end

	-- Coloca al personaje de pie SOBRE el disco interior, en el eje de la cápsula,
	-- mirando hacia el frente de la cápsula (misma orientación que ella).
	local function ponerDentro(char, c)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp or not c.modelo.Parent then
			return false
		end
		local suelo = sueloInterior(c)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		char:PivotTo(CFrame.new(suelo + Vector3.new(0, 3.3, 0)) * c.origen.Rotation)

		-- Ajuste fino: los pies quedan justo sobre el disco, ni hundidos ni flotando
		local y = pieY(char)
		if y then
			char:PivotTo(char:GetPivot() + Vector3.new(0, suelo.Y + 0.1 - y, 0))
		end
		return estaDentro(char, c)
	end

	-- PROTOCOLO FÉNIX: revives en la cápsula 1, luego 2, 3, 4...
	local function regenerar(char)
		if regenerando then
			return
		end

		-- Toma la primera cápsula válida de la cola
		local c
		while #cola > 0 do
			local candidata = table.remove(cola, 1)
			if candidata.modelo and candidata.modelo.Parent then
				c = candidata
				break
			end
		end

		if not c then
			return -- sin cápsulas: reapareces normal
		end

		regenerando = true
		secuencia += 1
		local mi = secuencia
		capsulaUso = c

		local hrpRef

		local ok, err = pcall(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 5)
			local hum = char:WaitForChild("Humanoid", 5)
			if not hrp or not hum then
				return
			end
			hrpRef = hrp

			-- Detiene el vigilante de colisión y deja el cristal sin colisión
			c.vigia += 1
			fijarColision(c, false)

			hrp.Anchored = true
			ponerDentro(char, c)

			-- Luces parpadean y la cápsula se abre sola
			parpadearLuces(c, 6)

			-- Espera ESPERA_ABRIR (y, si hace falta, hasta 3 s a que cargue la apariencia)
			local t0 = os.clock()
			while (os.clock() - t0 < ESPERA_ABRIR)
				or (not jugador:HasAppearanceLoaded() and os.clock() - t0 < 3) do
				task.wait(0.1)
				if mi ~= secuencia then return end
			end

			-- Recoloca ya con el outfit puesto y comprueba que quedó DENTRO
			hrp.Anchored = true
			if not ponerDentro(char, c) then
				warn("[PHOENIX] No se pudo confirmar la posición interior de la cápsula")
			end
			if mi ~= secuencia then return end

			abrirCapsula(c)
			task.wait(1.7)
			if mi ~= secuencia then return end

			-- El clon sale
			hrp.Anchored = false
			task.wait(6)
		end)

		if hrpRef and hrpRef.Parent then
			hrpRef.Anchored = false
		end

		if not ok then
			warn("[PHOENIX] Error en regeneración: " .. tostring(err))
		end

		-- La cápsula usada desaparece
		destruirCapsula(c)
		capsulaUso = nil
		regenerando = false
		print("[PHOENIX] Regeneración terminada. Cápsulas restantes: " .. #cola)
	end

	-- Muerte / respawn
	local function vigilar(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end

		con(hum.Died, function()
			murio = true
			-- Solo Fénix se encarga de esta muerte si Rick Prime está en OFF
			murioConFenix = not rickActivo()
		end)
	end

	con(jugador.CharacterAdded, function(char)
		task.spawn(vigilar, char)

		local usarFenix = murio and murioConFenix
		murio = false
		murioConFenix = false
		if usarFenix then
			task.spawn(regenerar, char)
		end
	end)

	if jugador.Character then
		task.spawn(vigilar, jugador.Character)
	end

	-- Interfaz
	local anterior = playerGui:FindFirstChild("PhoenixProtocolUI")
	if anterior then
		anterior:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PhoenixProtocolUI"
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
			pad.PaddingLeft = UDim.new(0, 12)
			pad.PaddingRight = UDim.new(0, 12)
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

	-- Botón circular: colocar cápsula (muestra cuántas llevas)
	local boton = crearBoton(
		"CÁPSULA\n0/" .. MAX_CAPSULAS,
		UDim2.new(0, TAM_CIRCULO, 0, TAM_CIRCULO),
		UDim2.new(0, 30, 1, -182),
		COLOR_ROJO, COLOR_VERDE, true
	)

	hacerArrastrable(boton, desplegarManual)

	-- Botón circular: abrir / cerrar la cápsula más cercana
	local botonAbrir = crearBoton(
		"ABRIR",
		UDim2.new(0, TAM_CIRCULO, 0, TAM_CIRCULO),
		UDim2.new(0, 30 + TAM_CIRCULO + 12, 1, -182),
		COLOR_VERDE, COLOR_ROJO, true
	)

	hacerArrastrable(botonAbrir, alternarCapsula)

	-- Botón circular: quitar la última cápsula colocada
	local botonQuitar = crearBoton(
		"QUITAR",
		UDim2.new(0, TAM_CIRCULO, 0, TAM_CIRCULO),
		UDim2.new(0, 30 + (TAM_CIRCULO + 12) * 2, 1, -182),
		COLOR_ROJO, COLOR_ROJO, true
	)

	hacerArrastrable(botonQuitar, quitarUltima)

	-- Actualiza los textos
	task.spawn(function()
		while gui.Parent do
			if mensaje and os.clock() < mensajeHasta then
				boton.Text = mensaje
			else
				mensaje = nil
				boton.Text = "CÁPSULA\n" .. #cola .. "/" .. MAX_CAPSULAS
			end

			local c = capsulaCercana()
			botonAbrir.Text = (c and c.abierta) and "CERRAR" or "ABRIR"
			task.wait(0.2)
		end
	end)

	con(UIS.InputBegan, function(input, procesado)
		if procesado then
			return
		end

		if input.KeyCode == TECLA_DESPLEGAR then
			desplegarManual()
		elseif input.KeyCode == TECLA_ABRIR then
			alternarCapsula()
		end
	end)

	-- Limpieza al re-ejecutar
	env.PHOENIX_LIMPIAR = function()
		secuencia += 1
		for _, c in ipairs(conexiones) do
			pcall(function() c:Disconnect() end)
		end
		for _, c in ipairs(cola) do
			destruirCapsula(c)
		end
		cola = {}
		destruirCapsula(capsulaUso)
		if gui then gui:Destroy() end
	end

	print("[PHOENIX] Cargado. P = colocar (máx " .. MAX_CAPSULAS .. ") | O = abrir/cerrar | Con RICK PRIME: OFF, al morir revives en la cápsula")
end

--##########################################################################
-- ARRANQUE: cada módulo aislado con pcall (portales antes que la bomba)
--##########################################################################
local MODULOS = {
	{ "OUTFIT", MODULO_OUTFIT },
	{ "RICK", MODULO_RICK },
	{ "FENIX", MODULO_FENIX },
	{ "PORTALES", MODULO_PORTALES },
	{ "BOMBA", MODULO_BOMBA },
}

for _, par in ipairs(MODULOS) do
	task.spawn(function()
		local ok, err = pcall(par[2])
		if not ok then
			warn("[TODO-EN-UNO] Falló el módulo " .. par[1] .. ": " .. tostring(err))
		end
	end)
end
