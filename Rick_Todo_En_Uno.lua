--!nonstrict
-- ============================================================
-- TODO EN UNO (LocalScript / Delta) - solo tú lo ves
--  1) OUTFIT   : Rick Prime + hombrera + pantalón (auto en cada respawn)
--  2) REGEN    : Z brazo | X pierna | C todos | V morir  (+ botones)
--  3) BOMBA    : Tool "Bomba Interdimensional" (explosión del video, sin esferas)
-- Cada módulo corre aislado: si uno falla, los demás siguen.
-- Si re-ejecutas, cada módulo limpia su versión anterior.
-- ============================================================

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
	local ESCALA        = 0.4   -- tamaño de la bomba (antes 0.7)
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
		bomba.CFrame = hrp.CFrame * CFrame.new(0, 1.5, -4)
		bomba.Parent = workspace
		bomba.AssemblyLinearVelocity = hrp.CFrame.LookVector * FUERZA + Vector3.new(0, ELEVACION, 0)
		bombas[bomba] = true

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
	end

	print("[BOMBA] Cargada. Busca '" .. NOMBRE_TOOL .. "' en tu inventario.")
end

--##########################################################################
-- ARRANQUE: cada módulo aislado con pcall
--##########################################################################
for nombre, modulo in pairs({ OUTFIT = MODULO_OUTFIT, RICK = MODULO_RICK, BOMBA = MODULO_BOMBA }) do
	task.spawn(function()
		local ok, err = pcall(modulo)
		if not ok then
			warn("[TODO-EN-UNO] Falló el módulo " .. nombre .. ": " .. tostring(err))
		end
	end)
end
