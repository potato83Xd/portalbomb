--[[
  RICK PRIME — REGENERATION v6  (LocalScript · Delta)
  Combina los 3 videos en un solo script:
  A) MUERTE (video v2): flash cian -> explosión + gore -> bola de tentáculos ->
     torso y cabeza aparecen de golpe con ropa -> brazos/piernas amarillos
     se pegan -> tentáculos cuelgan y se retraen con vapor -> la ropa aparece
     (brazos: amarillo -> manga | piernas: amarillo -> gris -> pantalón)
  B) DAÑO (videos v1 y v5), con el botón "Daño" eliges el estilo:
     v1 = pierdes un brazo: explosión roja, salpicadura, tentáculos gruesos
          rojos/azules, brazo de piel con carne roja, vapor, manga. (~2.8 s)
     v5 = pierdes brazo + pierna del mismo lado: cuchillas de sangre, charcos
          que se quedan, piezas de placa de diamante en el suelo. (~2.25 s)
     Sigues moviéndote normal.
  El color de piel se toma solo de tu cabeza (o fíjalo en CONFIG.SkinColor).
  Sonido aleatorio al revivir. El botón OFF corta todo al instante.
]]

--==================== AJUSTES ====================--
local CONFIG = {
	Enabled           = true,
	ShowButton        = true,
	ButtonPosition    = UDim2.new(0, 12, 0.5, -20),
	ReviveAtDeathSpot = true,
	LowCamera         = true,
	MoveDuringRegen   = true,

	SoundEnabled      = true,
	SoundVolume       = 1.5,
	ReviveSounds      = {
		"rbxassetid://114065568433604",
		"rbxassetid://138925430725431",
		"rbxassetid://104144683858662",
		"rbxassetid://70534758302331",
	},

	-- Regeneración por daño
	LimbRegen         = true,
	LimbMinDamage     = 1,
	LimbCooldown      = 0.35,
	LimbMaxActive     = 4,      -- miembros regenerando a la vez (v5 usa 2 por golpe)
	LimbStyle         = "v5",   -- "v1" = solo un brazo | "v5" = brazo + pierna (también con el botón)
	LimbIncludeLegs   = true,   -- en v5: pierda también la pierna del mismo lado
	LimbGoreCap       = true,   -- bola de carne roja en el hombro del miembro nuevo
	LimbPuddleLife    = 120,    -- segundos que duran los charcos de v5 (en el video no se van)
	SkinColor         = nil,    -- nil = automático (color de tu cabeza). Ej: Color3.fromRGB(240,222,100)
	-- (los tiempos y tamaños de v1 y v5 están en LIMB_STYLES, más abajo)

	-- Regeneración por muerte
	FlashTime         = 0.17,
	BlurEnabled       = true,
	BlurSize          = 48,
	ShakeAmount       = 1.4,

	ChunkCount        = 38,
	ChunkSpeed        = 48,
	SkyChunks         = 6,
	PuddleCount       = 14,
	PuddleMaxSize     = 9,
	PuddleLifetime    = 40,
	Steam             = true,

	TentacleCount     = 20,
	TentacleSegments  = 8,
	TentacleLength    = 2.4,
	TentacleThickness = 0.4,
	TentacleSpeed     = 1,
	TentacleCurl      = 1,

	WriggleTime       = 1.65,   -- bola de tentáculos antes de reconstruir (video v2: ~1.8 s tras el flash)
	RebuildTime       = 0.7,    -- ritmo en que se pegan los miembros
	YellowHold        = 0.25,   -- tiempo que se ve amarillo antes de la ropa
	ClothTime         = 0.45,   -- tiempo en aparecer la ropa
	WaitCharTimeout   = 25,
}
--=================================================--

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local Debris       = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

if env.__RickPrimeRegenCleanup then
	pcall(env.__RickPrimeRegenCleanup)
	env.__RickPrimeRegenCleanup = nil
end
for _, n in ipairs({"RickPrimeFX", "RickPrimeBlood", "RickPrimeLimbFX"}) do
	local s = workspace:FindFirstChild(n)
	if s then s:Destroy() end
end
local oldBlur = Lighting:FindFirstChild("RickPrimeBlur")
if oldBlur then oldBlur:Destroy() end

local puddleFolder = Instance.new("Folder")
puddleFolder.Name = "RickPrimeBlood"
puddleFolder.Parent = workspace

local limbFolder = Instance.new("Folder")
limbFolder.Name = "RickPrimeLimbFX"
limbFolder.Parent = workspace

local running = true
local connections = {}
local function track(c) table.insert(connections, c) return c end

local function rand(a, b) return a + math.random() * (b - a) end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function easeInOut(t) return t < 0.5 and 2 * t * t or 1 - ((-2 * t + 2) ^ 2) / 2 end
local function easeOut(t) return 1 - (1 - t) ^ 3 end

local SKIN_DEFAULT = Color3.fromRGB(240, 222, 100)
local SKIN = SKIN_DEFAULT   -- color de piel (se actualiza solo con refreshSkin)
local GRAY   = Color3.fromRGB(112, 112, 100)

local BLOOD = {
	Color3.fromRGB(170, 12, 30), Color3.fromRGB(120, 8, 22), Color3.fromRGB(205, 25, 40),
}
local TENT_COLORS = {
	Color3.fromRGB(175, 15, 35), Color3.fromRGB(150, 12, 30), Color3.fromRGB(110, 8, 22),
	Color3.fromRGB(215, 35, 55), Color3.fromRGB(30, 55, 195), Color3.fromRGB(22, 40, 160),
	Color3.fromRGB(18, 24, 70), Color3.fromRGB(28, 14, 22),
}
local CHUNK_COLORS = {
	Color3.fromRGB(240, 222, 100), Color3.fromRGB(240, 222, 100),
	Color3.fromRGB(170, 12, 30), Color3.fromRGB(120, 8, 22), Color3.fromRGB(30, 22, 28),
}

local function refreshSkin(char)
	local c = CONFIG.SkinColor
	if not c then
		local head = char and char:FindFirstChild("Head")
		c = (head and head:IsA("BasePart")) and head.Color or SKIN_DEFAULT
	end
	SKIN = c
	CHUNK_COLORS[1] = c
	CHUNK_COLORS[2] = c
end

--==================== ESTADO ====================--
local state = {
	token = 0, busy = false, phase = "idle", body = "none",
	lastSafeCF = nil, lastRels = nil, lastRelsChar = nil, deathCF = nil,
	oldChar = nil, newChar = nil, newReady = false,
	holdCF = nil, controlNew = false, hideOld = false,
	fx = nil, shake = 0, rebuildStart = 0, rebuildTotal = nil,
	arriveByName = {}, revealDur = {}, limbs = {}, decalOrig = {}, errShown = {},
	flashDeadline = nil, blurDeadline = nil,
}

local forceStop, cancelLimbFx

--==================== GUI ====================--
local function getGuiParent()
	local ok, ui = pcall(function() return gethui and gethui() end)
	if ok and ui then return ui end
	return player:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "RickPrimeRegenGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = getGuiParent()

local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Active = false
flash.ClipsDescendants = true
flash.ZIndex = 1
flash.Parent = gui

local button
local function refreshButton()
	if not button then return end
	button.Text = "Rick Prime Regen: " .. (CONFIG.Enabled and "ON" or "OFF")
	button.BackgroundColor3 = CONFIG.Enabled and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(180, 50, 50)
end
if CONFIG.ShowButton then
	button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.Size = UDim2.fromOffset(160, 40)
	button.Position = CONFIG.ButtonPosition
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.ZIndex = 5
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	refreshButton()
	track(button.Activated:Connect(function()
		CONFIG.Enabled = not CONFIG.Enabled
		refreshButton()
		if not CONFIG.Enabled and forceStop then forceStop() end
	end))
end

local blur = Instance.new("BlurEffect")
blur.Name = "RickPrimeBlur"
blur.Size = 0
blur.Parent = Lighting

--==================== UTILIDADES ====================--
local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not state.errShown[name] then
		state.errShown[name] = true
		warn("[RickPrime] " .. name .. ": " .. tostring(err))
	end
end

local function findGround(origin, ignore)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, -300, 0), rp)
	if r then return r.Position.Y end
	return origin.Y - 3
end

local function makeClone(char)
	local ok, clone = pcall(function()
		char.Archivable = true
		for _, d in ipairs(char:GetDescendants()) do d.Archivable = true end
		return char:Clone()
	end)
	if not ok or typeof(clone) ~= "Instance" then return nil, nil end
	local junk = {"Script", "LocalScript", "Humanoid", "Motor6D", "Animator", "Sound", "ForceField",
		"BillboardGui", "Shirt", "Pants", "ShirtGraphic", "CharacterMesh", "Tool", "Highlight"}
	for _, d in ipairs(clone:GetDescendants()) do
		for _, cn in ipairs(junk) do
			if d:IsA(cn) then d:Destroy() break end
		end
	end
	local rels = {}
	local hrp = clone:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		for _, p in ipairs(clone:GetChildren()) do
			if p:IsA("BasePart") and p ~= hrp then
				rels[p] = hrp.CFrame:ToObjectSpace(p.CFrame)
			end
		end
		hrp:Destroy()
	end
	return clone, rels
end

local function makeStandIn(real, pos, parent)
	local ok, c = pcall(function()
		real.Archivable = true
		local s = real:Clone()
		for _, ch in ipairs(s:GetChildren()) do
			if not ch:IsA("DataModelMesh") then ch:Destroy() end
		end
		s.Anchored = true
		s.CanCollide = false
		s.Transparency = 0
		s.LocalTransparencyModifier = 0
		s.CFrame = CFrame.new(pos + Vector3.new(rand(-3, 3), rand(0.5, 2), rand(-3, 3)))
			* CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
		s.Parent = parent
		return s
	end)
	if ok and typeof(c) == "Instance" then return c end
	return nil
end

local function newEmitter(parent, cfg)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(cfg.life[1], cfg.life[2])
	e.Speed = NumberRange.new(cfg.speed[1], cfg.speed[2])
	e.SpreadAngle = Vector2.new(cfg.spread, cfg.spread)
	e.Acceleration = cfg.accel or Vector3.new(0, 0, 0)
	e.Color = cfg.color
	e.Size = cfg.size
	e.Transparency = cfg.transp
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.LightEmission = cfg.light or 0
	e.Drag = cfg.drag or 0
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

local function noCollideWithChar(part, char)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			local nc = Instance.new("NoCollisionConstraint")
			nc.Part0 = part
			nc.Part1 = d
			nc.Parent = part
		end
	end
end

local function current(token) return running and state.token == token end

local function hideModel(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
	end
end

local lastSound = nil
local function playReviveSound()
	local list = CONFIG.ReviveSounds
	if not CONFIG.SoundEnabled or not list or #list == 0 then return end
	local n = #list
	local idx = math.random(n)
	if n > 1 and idx == lastSound then idx = (idx % n) + 1 end
	lastSound = idx
	local s = Instance.new("Sound")
	s.Name = "RickPrimeRevive"
	s.SoundId = list[idx]
	s.Volume = CONFIG.SoundVolume
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 20)
end

--==================== LIBERAR / LIMPIAR ====================--
local function restoreCamera(char)
	local cam = workspace.CurrentCamera
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if cam and hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
end

local function clearScreenFx()
	flash:ClearAllChildren()
	flash.BackgroundTransparency = 1
	blur.Size = 0
	state.flashDeadline = nil
	state.blurDeadline = nil
end

local function releaseNew()
	local char = state.newChar
	if char and state.controlNew then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			elseif (d:IsA("Decal") or d:IsA("Texture")) and state.decalOrig[d] ~= nil then
				d.Transparency = state.decalOrig[d]
			end
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
	end
	state.controlNew = false
	state.holdCF = nil
	state.decalOrig = {}
end

local function clearFx()
	local hadFx = state.fx ~= nil
	if state.fx and state.fx.folder then state.fx.folder:Destroy() end
	state.fx = nil
	state.limbs = {}
	releaseNew()
	state.phase = "idle"
	state.body = "none"
	state.hideOld = false
	clearScreenFx()
	if hadFx then restoreCamera(player.Character) end
end

forceStop = function()
	state.token += 1
	local nc = state.newChar
	if cancelLimbFx then pcall(cancelLimbFx) end
	pcall(clearFx)
	pcall(clearScreenFx)
	pcall(restoreCamera, nc or player.Character)
	state.busy = false
	state.oldChar = nil
	state.newChar = nil
	state.newReady = false
end

--==================== FLASH ====================--
local function addBlobs(parent, colors, n, minS, maxS)
	for _ = 1, n do
		local s = rand(minS, maxS)
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(rand(0, 1), rand(0, 1))
		b.Size = UDim2.fromScale(s, s)
		b.BorderSizePixel = 0
		b.BackgroundColor3 = colors[math.random(#colors)]
		b.BackgroundTransparency = rand(0, 0.25)
		local ar = Instance.new("UIAspectRatio")
		ar.AspectRatio = 1
		ar.Parent = b
		local uc = Instance.new("UICorner")
		uc.CornerRadius = UDim.new(0.5, 0)
		uc.Parent = b
		b.Parent = parent
	end
end

local function centerDot(parent, color, s)
	local b = Instance.new("Frame")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.5)
	b.Size = UDim2.fromScale(s, s)
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color
	local ar = Instance.new("UIAspectRatio")
	ar.AspectRatio = 1
	ar.Parent = b
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(0.5, 0)
	uc.Parent = b
	b.Parent = parent
end

local function playFlash(token)
	state.flashDeadline = os.clock() + CONFIG.FlashTime + 1.2
	task.spawn(function()
		local ok, err = pcall(function()
			local T = CONFIG.FlashTime
			flash:ClearAllChildren()
			flash.BackgroundColor3 = Color3.fromRGB(0, 185, 195)
			flash.BackgroundTransparency = 0
			addBlobs(flash, {Color3.fromRGB(0, 120, 130), Color3.fromRGB(20, 215, 225), Color3.fromRGB(120, 245, 245)}, 26, 0.12, 0.45)
			centerDot(flash, Color3.fromRGB(210, 50, 70), 0.03)
			task.wait(T * 0.5)
			if not current(token) then return end
			flash:ClearAllChildren()
			flash.BackgroundColor3 = Color3.fromRGB(60, 220, 230)
			addBlobs(flash, {Color3.fromRGB(245, 150, 150), Color3.fromRGB(150, 115, 235), Color3.fromRGB(240, 250, 250), Color3.fromRGB(20, 200, 215)}, 22, 0.1, 0.4)
			centerDot(flash, Color3.fromRGB(140, 100, 230), 0.16)
			task.wait(T * 0.5)
			if not current(token) then return end
			flash:ClearAllChildren()
			flash.BackgroundColor3 = Color3.fromRGB(238, 232, 240)
			flash.BackgroundTransparency = 0.1
			TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{BackgroundTransparency = 1}):Play()
		end)
		if not ok then
			warn("[RickPrime] flash: " .. tostring(err))
			pcall(clearScreenFx)
		end
	end)
end

--==================== EXPLOSIÓN (MUERTE) ====================--
local function burst()
	local fx = state.fx
	if not fx then return end
	local old = state.oldChar
	local cf = state.deathCF
	local origin = cf.Position

	local ignore = {fx.folder, puddleFolder, limbFolder}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local groundY = findGround(origin, ignore)
	fx.groundY = groundY
	fx.burstAt = os.clock()
	state.phase = "writhe"
	state.shake = CONFIG.ShakeAmount

	state.hideOld = true
	if old then
		for _, d in ipairs(old:GetDescendants()) do
			if d:IsA("BasePart") then pcall(function() d.Anchored = true end) end
		end
	end

	if CONFIG.BlurEnabled then
		blur.Size = CONFIG.BlurSize
		state.blurDeadline = os.clock() + 1.4
		TweenService:Create(blur, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
	end

	local ep = Instance.new("Part")
	ep.Name = "FXEmitter"
	ep.Anchored = true; ep.CanCollide = false; ep.CanQuery = false; ep.CanTouch = false
	ep.Transparency = 1
	ep.Size = Vector3.new(1, 1, 1)
	ep.CFrame = CFrame.new(origin.X, groundY + 1.2, origin.Z)
	ep.Parent = fx.folder
	fx.emitPart = ep

	local blood = newEmitter(ep, {
		life = {1, 1.8}, speed = {25, 60}, spread = 180, accel = Vector3.new(0, -60, 0),
		color = ColorSequence.new(Color3.fromRGB(195, 15, 30), Color3.fromRGB(90, 5, 15)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.15)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1)}),
	})
	local gore = newEmitter(ep, {
		life = {0.7, 1.5}, speed = {15, 45}, spread = 180, drag = 1.5,
		color = ColorSequence.new(Color3.fromRGB(130, 10, 22), Color3.fromRGB(35, 6, 12)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.8)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1)}),
	})
	local dark = newEmitter(ep, {
		life = {1.5, 2.6}, speed = {10, 28}, spread = 180, drag = 2,
		color = ColorSequence.new(Color3.fromRGB(55, 50, 58), Color3.fromRGB(20, 18, 22)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 10)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)}),
	})
	local haze = newEmitter(ep, {
		life = {1.6, 2.6}, speed = {5, 18}, spread = 180, drag = 2,
		color = ColorSequence.new(Color3.fromRGB(215, 218, 228)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 9), NumberSequenceKeypoint.new(1, 24)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)}),
	})
	blood:Emit(110); gore:Emit(150); dark:Emit(36); haze:Emit(20)

	fx.steam = newEmitter(ep, {
		life = {1.5, 2.5}, speed = {3, 6}, spread = 15, accel = Vector3.new(0, 2, 0),
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1)}),
	})

	local chunkPhys = PhysicalProperties.new(1, 0.8, 0.1)
	for _ = 1, CONFIG.ChunkCount do
		local c = Instance.new("Part")
		local s = rand(0.25, 1.1)
		c.Size = Vector3.new(s * rand(0.6, 1.4), s * rand(0.6, 1.4), s * rand(0.6, 1.4))
		c.Material = Enum.Material.SmoothPlastic
		c.Color = CHUNK_COLORS[math.random(#CHUNK_COLORS)]
		c.CanQuery = false; c.CanTouch = false
		c.CustomPhysicalProperties = chunkPhys
		c.CFrame = CFrame.new(origin + Vector3.new(rand(-1, 1), rand(-1, 2), rand(-1, 1)))
			* CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
		c.Parent = fx.folder
		local dir = Vector3.new(rand(-1, 1), rand(0.4, 1.4), rand(-1, 1)).Unit
		c.AssemblyLinearVelocity = dir * CONFIG.ChunkSpeed * rand(0.4, 1)
		c.AssemblyAngularVelocity = Vector3.new(rand(-20, 20), rand(-20, 20), rand(-20, 20))
	end

	for _ = 1, CONFIG.SkyChunks do
		local c = Instance.new("Part")
		local s = rand(0.4, 0.8)
		c.Size = Vector3.new(s, s, s)
		c.Material = Enum.Material.SmoothPlastic
		c.Color = SKIN
		c.CanQuery = false; c.CanTouch = false; c.CanCollide = false
		c.CFrame = CFrame.new(origin + Vector3.new(rand(-1, 1), 1, rand(-1, 1)))
		c.Parent = fx.folder
		c.AssemblyLinearVelocity = Vector3.new(rand(-25, 25), rand(70, 95), rand(-25, 25))
		c.AssemblyAngularVelocity = Vector3.new(rand(-8, 8), rand(-8, 8), rand(-8, 8))
	end

	for i = 1, CONFIG.PuddleCount do
		local d, a = rand(0.5, 7), rand(0, 6.28)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = BLOOD[math.random(#BLOOD)]
		p.Reflectance = 0.05
		p.Size = Vector3.new(0.05, 0.1, 0.1)
		p.CFrame = CFrame.new(origin.X + math.cos(a) * d, groundY + 0.03 + i * 0.004, origin.Z + math.sin(a) * d)
			* CFrame.Angles(0, 0, math.rad(90))
		p.Parent = puddleFolder
		local target = rand(2.5, CONFIG.PuddleMaxSize)
		TweenService:Create(p, TweenInfo.new(rand(0.4, 1.0), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.05, target, target)}):Play()
		task.delay(CONFIG.PuddleLifetime, function()
			if running and p.Parent then
				TweenService:Create(p, TweenInfo.new(3), {Transparency = 1}):Play()
				Debris:AddItem(p, 3.2)
			end
		end)
	end

	local clone = fx.clone
	local anchorNames = {}
	if clone then
		for part, rel in pairs(fx.rels or {}) do
			if part.Parent then
				part.Anchored = true
				part.CanCollide = false
				part.CFrame = cf * rel
			end
		end
		clone.Parent = fx.folder
		local head = clone:FindFirstChild("Head")
		for _, p in ipairs(clone:GetChildren()) do
			if p:IsA("BasePart") then
				if p == head then
					p.CFrame = CFrame.new(origin.X, groundY + 0.9, origin.Z)
						* CFrame.Angles(0, rand(0, 6.28), math.rad(rand(70, 110)))
					fx.head = p
					for _ = 1, 4 do table.insert(anchorNames, p.Name) end
				else
					p.Anchored = false
					p.CanCollide = true
					p.CustomPhysicalProperties = chunkPhys
					local dir = Vector3.new(rand(-1, 1), rand(0.5, 1.2), rand(-1, 1)).Unit
					p.AssemblyLinearVelocity = dir * rand(18, 38)
					p.AssemblyAngularVelocity = Vector3.new(rand(-12, 12), rand(-12, 12), rand(-12, 12))
					local n = p.Name:lower()
					local weight = n:find("torso") and 4 or 1
					for _ = 1, weight do table.insert(anchorNames, p.Name) end
				end
			end
		end
	end

	for _ = 1, CONFIG.TentacleCount do
		local aName = #anchorNames > 0 and anchorNames[math.random(#anchorNames)] or nil
		local aPart = aName and clone and clone:FindFirstChild(aName) or nil
		local off = Vector3.new(0, 0, 0)
		if aPart then
			local sz = aPart.Size
			off = Vector3.new(rand(-1, 1) * sz.X * 0.4, rand(-1, 1) * sz.Y * 0.4, rand(-1, 1) * sz.Z * 0.4)
		end
		local tn = {
			segs = {},
			anchorName = aName,
			localOff = off,
			dir = Vector3.new(rand(-1, 1), rand(0.1, 1.2), rand(-1, 1)).Unit,
			phase = rand(0, 10), speed = rand(2.2, 4.5),
			length = CONFIG.TentacleLength * rand(0.7, 1.2),
			curl = rand(0.22, 0.5) * CONFIG.TentacleCurl,
			twist = rand(-0.35, 0.35),
			thick = CONFIG.TentacleThickness * rand(0.85, 1.25),
			color = TENT_COLORS[math.random(#TENT_COLORS)],
		}
		for _ = 1, CONFIG.TentacleSegments do
			local s = Instance.new("Part")
			s.Anchored = true; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false
			s.Material = Enum.Material.SmoothPlastic
			s.Color = tn.color
			s.Size = Vector3.new(0.2, 0.2, 0.2)
			s.Transparency = 1
			s.Parent = fx.folder
			table.insert(tn.segs, s)
		end
		table.insert(fx.tentacles, tn)
	end
end

--==================== RECONSTRUCCIÓN (MUERTE) ====================--
-- cuándo se pega cada pieza (segundos × RebuildTime). El torso y la cabeza
-- aparecen YA; los brazos y las piernas llegan después, uno por uno.
local function delayFor(name)
	local n = name:lower()
	if n:find("torso") then return 0
	elseif n:find("head") then return 0.04
	elseif n:find("arm") or n:find("hand") then return n:find("left") and 0.3 or 0.45
	elseif n:find("leg") or n:find("foot") then return n:find("left") and 0.65 or 0.8
	end
	return 0.35
end

local function pickBody()
	if state.newReady and state.newChar and state.newChar.Parent then
		return "new", state.newChar
	end
	local old, fx = state.oldChar, state.fx
	if CONFIG.MoveDuringRegen then return nil, nil end
	if old and old.Parent and fx and fx.bodyRels and next(fx.bodyRels) ~= nil then
		return "old", old
	end
	return nil, nil
end

local function startRebuild(kind, body)
	local fx = state.fx
	if not fx or not body then return end
	local now = os.clock()
	state.phase = "rebuild"
	state.body = kind
	state.rebuildStart = now
	state.limbs = {}
	state.arriveByName = {}
	state.revealDur = {}

	safe("sonido", playReviveSound)

	local center = state.deathCF.Position
	if fx.head and fx.head.Parent then center = fx.head.Position end
	local C = CONFIG.ClothTime
	local byName = {}
	local total = 0

	for _, real in ipairs(body:GetChildren()) do
		if real:IsA("BasePart") and real.Name ~= "HumanoidRootPart" then
			local n = real.Name:lower()
			local pk = "core"
			if n:find("arm") or n:find("hand") then pk = "arm"
			elseif n:find("leg") or n:find("foot") then pk = "leg" end
			local delay = delayFor(real.Name) * CONFIG.RebuildTime
			local e

			if pk == "core" then
				-- torso y cabeza: aparecen de golpe, ya con ropa
				e = {
					name = real.Name, kind = "core", real = real, delay = delay,
					arriveAt = now + delay, doneAt = now + delay + 0.18, gone = false,
				}
				state.arriveByName[real.Name] = e.arriveAt
				state.revealDur[real.Name] = 0.18
			else
				-- brazos y piernas: llegan amarillos y se pegan al cuerpo
				local part = fx.clone and fx.clone:FindFirstChild(real.Name)
				if not (part and part:IsA("BasePart") and part.Parent) then
					part = makeStandIn(real, center, fx.folder)
				end
				if part then
					part.Anchored = true
					part.CanCollide = false
					part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
					part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
					local dur = CONFIG.RebuildTime * 0.25
					local arriveAt = now + delay + dur
					local clothStart = arriveAt + CONFIG.YellowHold
					e = {
						name = real.Name, kind = pk, part = part, real = real,
						startCF = part.CFrame, skin = part.Color,
						delay = delay, dur = dur, arriveAt = arriveAt,
						clothStart = clothStart, gone = false,
					}
					if pk == "leg" then
						-- piernas: amarillo -> gris -> pantalón negro
						e.grayEnd = clothStart + C * 0.6
						e.doneAt = e.grayEnd + C * 0.6
						state.arriveByName[real.Name] = e.grayEnd
						state.revealDur[real.Name] = C * 0.6
					else
						-- brazos: amarillo -> manga
						e.doneAt = clothStart + C
						state.arriveByName[real.Name] = clothStart
						state.revealDur[real.Name] = C
					end
				end
			end

			if e then
				byName[real.Name] = e
				table.insert(state.limbs, e)
				total = math.max(total, e.doneAt - now)
			end
		end
	end

	-- cada tentáculo se retrae cuando su pieza ya tiene ropa
	for _, tn in ipairs(fx.tentacles) do
		local e = tn.anchorName and byName[tn.anchorName]
		if e and e.kind ~= "core" then
			tn.rs = e.arriveAt
			tn.re = e.doneAt
		else
			tn.rs = now + 0.05
			tn.re = now + 0.4
		end
	end
	state.rebuildTotal = total + 0.15

	if fx.clone then
		for _, p in ipairs(fx.clone:GetChildren()) do
			if p:IsA("BasePart") and not body:FindFirstChild(p.Name) then p:Destroy() end
		end
	end
end

local function finish(token)
	local fx = state.fx
	state.phase = "done"
	state.body = "none"
	pcall(releaseNew)
	local old = state.oldChar
	if old and old.Parent then pcall(hideModel, old) end
	pcall(restoreCamera, state.newChar or player.Character)
	pcall(clearScreenFx)
	if fx then
		pcall(function()
			if fx.steam then fx.steam.Rate = 0 end
			for _, tn in ipairs(fx.tentacles) do
				for _, s in ipairs(tn.segs) do s:Destroy() end
			end
			fx.tentacles = {}
			for _, e in ipairs(state.limbs) do
				if e.part and e.part.Parent then e.part:Destroy() end
			end
			Debris:AddItem(fx.folder, 4)
		end)
	end
	state.limbs = {}
	state.fx = nil
	state.busy = false
	state.phase = "idle"
	state.hideOld = false
	state.oldChar = nil
	state.newChar = nil
	state.newReady = false
	state.rebuildTotal = nil
end

local function runSequence(token)
	playFlash(token)
	task.wait(CONFIG.FlashTime)
	if not current(token) then return end
	burst()

	task.wait(CONFIG.WriggleTime)
	if not current(token) then return end

	local kind, body = pickBody()
	local waited = 0
	while current(token) and not kind and waited < CONFIG.WaitCharTimeout do
		task.wait(0.05)
		waited += 0.05
		kind, body = pickBody()
	end
	if not current(token) then return end
	if not kind then finish(token) return end

	if kind == "new" then
		local t = 0
		while current(token) and t < 3 do
			if body:FindFirstChild("Head") and (body:FindFirstChild("Torso") or body:FindFirstChild("UpperTorso")) then break end
			task.wait(0.05)
			t += 0.05
		end
		if not current(token) then return end
	end

	if state.fx and state.fx.steam and CONFIG.Steam then state.fx.steam.Rate = 14 end
	startRebuild(kind, body)
	task.wait(state.rebuildTotal or (CONFIG.RebuildTime + CONFIG.ClothTime + 0.15))
	if not current(token) then return end

	waited = 0
	while current(token) and not state.newReady and waited < CONFIG.WaitCharTimeout do
		task.wait(0.05)
		waited += 0.05
	end
	if not current(token) then return end
	finish(token)
end

local function safeRun(token)
	local ok, err = pcall(runSequence, token)
	if not ok then
		warn("[RickPrime] error en la secuencia: " .. tostring(err))
		if current(token) then pcall(finish, token) end
	end
end

local startRegen
startRegen = function(oldChar)
	clearFx()
	state.token += 1
	local token = state.token
	refreshSkin(oldChar)
	state.busy = true
	state.phase = "flash"
	state.body = "none"
	state.oldChar = oldChar
	state.newChar = nil
	state.newReady = false
	state.controlNew = false
	state.holdCF = nil
	state.hideOld = false
	state.arriveByName = {}
	state.revealDur = {}
	state.rebuildTotal = nil
	state.limbs = {}
	state.decalOrig = {}

	local hrp = oldChar:FindFirstChild("HumanoidRootPart")
	state.deathCF = state.lastSafeCF or (hrp and hrp.CFrame) or CFrame.new(0, 10, 0)

	local folder = Instance.new("Folder")
	folder.Name = "RickPrimeFX"
	folder.Parent = workspace
	local fx = {folder = folder, tentacles = {}, bodyRels = {}}

	if state.lastRelsChar == oldChar and state.lastRels then
		fx.bodyRels = state.lastRels
	elseif hrp then
		local inv = hrp.CFrame:Inverse()
		for _, d in ipairs(oldChar:GetDescendants()) do
			if d:IsA("BasePart") then fx.bodyRels[d] = inv * d.CFrame end
		end
	end

	fx.clone, fx.rels = makeClone(oldChar)
	state.fx = fx

	task.spawn(safeRun, token)
end

--==================== REGENERACIÓN POR DAÑO ====================--
-- Dos estilos copiados de los videos (se cambian con el botón "Daño"):
--   v1 = un solo brazo. Sin charcos. Explosión de trozos rojos, 1.1 s después
--        salpicadura + tentáculos gruesos rojos/azules, brazo amarillo con carne
--        roja, vapor y manga. Dura ~2.8 s.
--   v5 = brazo + pierna del mismo lado. Cuchillas de sangre, trozos negros,
--        a veces destello rojo, charcos que NO desaparecen, piezas de placa
--        de diamante que quedan en el suelo. Dura ~2.25 s.
local LIMB_STYLES = {
	v1 = {
		legs = false,
		gap = 1.1,   -- segundos hasta que salen los tentáculos
		W = 2.0,     -- cuándo aparece el miembro nuevo (de piel)
		SH = 0.15,   -- lo que tarda en crecer
		YT = 0.20,   -- tiempo que se ve solo de piel
		CT = 0.45,   -- tiempo en que aparece la ropa
		tents = 9, tentSegs = 6, tentLen = 2.8, tentThick = 0.55,
		cap = 1.25,  -- bola de carne roja en el hombro del miembro nuevo
		pieceMat = Enum.Material.SmoothPlastic, pieceLife = 2.4,
		puddles = 0,
	},
	v5 = {
		legs = true,
		gap = 0.65,
		W = 1.6,
		SH = 0.12,
		YT = 0.13,
		CT = 0.40,
		tents = 8, tentSegs = 5, tentLen = 1.7, tentThick = 0.3,
		cap = 0.8,
		pieceMat = Enum.Material.DiamondPlate, pieceLife = 30,
		puddles = 3,
	},
}

local limbList = {}
local limbBusy = {}
local lastLimbTime = 0
local limbEpoch = 0
local puddleSeq = 0

local LIMBS_R6 = {
	{key = "RightArm", parts = {"Right Arm"}, side = 1,  leg = false},
	{key = "LeftArm",  parts = {"Left Arm"},  side = -1, leg = false},
	{key = "RightLeg", parts = {"Right Leg"}, side = 1,  leg = true},
	{key = "LeftLeg",  parts = {"Left Leg"},  side = -1, leg = true},
}
local LIMBS_R15 = {
	{key = "RightArm", parts = {"RightUpperArm", "RightLowerArm", "RightHand"}, side = 1,  leg = false},
	{key = "LeftArm",  parts = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},    side = -1, leg = false},
	{key = "RightLeg", parts = {"RightUpperLeg", "RightLowerLeg", "RightFoot"}, side = 1,  leg = true},
	{key = "LeftLeg",  parts = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},    side = -1, leg = true},
}

local SHARD_COLORS = {
	Color3.fromRGB(120, 8, 22), Color3.fromRGB(150, 10, 28),
	Color3.fromRGB(95, 6, 18), Color3.fromRGB(190, 20, 38),
}
local BLACK_BITS = {Color3.fromRGB(14, 12, 16), Color3.fromRGB(30, 26, 32)}
local DROP_COLORS = {Color3.fromRGB(205, 25, 40), Color3.fromRGB(170, 12, 30)}
local GLOW_COLORS = {Color3.fromRGB(255, 40, 40), Color3.fromRGB(255, 90, 70)}

local function stepNoise(t, seed)
	local k = math.floor(t * 8)
	local v = math.sin(k * 12.9898 + seed * 78.233) * 43758.5453
	return (v - math.floor(v)) * 2 - 1
end

local function lookCF(from, to)
	local d = to - from
	local up = (d.Magnitude > 0.001 and math.abs(d.Unit.Y) > 0.95) and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return CFrame.lookAt(from, to, up)
end

local function anchoredFx(size, color, material)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	return p
end

-- ráfaga esférica de trozos (sin física): salen, se encogen y desaparecen
local function shardBurst(origin, n, dist, life, size, colors, neon)
	for _ = 1, n do
		local s = rand(size[1], size[2])
		local p = anchoredFx(Vector3.new(s * rand(0.6, 1.5), s * rand(0.6, 1.5), s * rand(0.6, 1.5)),
			colors[math.random(#colors)], neon and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		local start = origin + Vector3.new(rand(-0.4, 0.4), rand(-0.4, 0.4), rand(-0.4, 0.4))
		local rot = CFrame.Angles(rand(0, 6.28), rand(0, 6.28), rand(0, 6.28))
		p.CFrame = CFrame.new(start) * rot
		p.Parent = limbFolder
		local dir = Vector3.new(rand(-1, 1), rand(-1, 1), rand(-1, 1))
		if dir.Magnitude < 0.05 then dir = Vector3.new(0, 1, 0) end
		local goal = CFrame.new(start + dir.Unit * rand(dist[1], dist[2])) * rot * CFrame.Angles(rand(-2, 2), rand(-2, 2), 0)
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = goal, Size = p.Size * 0.25}):Play()
		Debris:AddItem(p, life + 0.05)
	end
end

-- destello rojo brillante (variante del video v5)
local function glowBurst(origin)
	shardBurst(origin, 7, {2.5, 5.5}, 0.5, {0.5, 0.9}, GLOW_COLORS, true)
	shardBurst(origin, 5, {3, 7}, 0.7, {0.7, 1.4}, DROP_COLORS)
	local lp = anchoredFx(Vector3.new(1, 1, 1), Color3.new(1, 0, 0))
	lp.Transparency = 1
	lp.CFrame = CFrame.new(origin)
	lp.Parent = limbFolder
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 40, 40)
	l.Range = 14
	l.Brightness = 4
	l.Parent = lp
	TweenService:Create(l, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0}):Play()
	Debris:AddItem(lp, 0.5)
end

-- cuchillas / picos de sangre: salen disparados y se apagan
local function bloodSpikes(origin, count, vertical)
	for _ = 1, count do
		local dir, len, thick
		if vertical then
			dir = Vector3.new(rand(-0.3, 0.3), 1, rand(-0.3, 0.3)).Unit
			len, thick = rand(3, 5.5), rand(0.3, 0.45)
		else
			dir = Vector3.new(rand(-1, 1), rand(-0.2, 1), rand(-1, 1))
			if dir.Magnitude < 0.05 then dir = Vector3.new(0, 1, 0) end
			dir = dir.Unit
			len, thick = rand(5, 13), rand(0.1, 0.2)
		end
		local p = anchoredFx(Vector3.new(thick, thick * 0.4, 0.1), SHARD_COLORS[math.random(1, 3)])
		local base = lookCF(origin, origin + dir)
		p.CFrame = base
		p.Parent = limbFolder
		Debris:AddItem(p, 1.2)
		TweenService:Create(p, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(thick, thick * 0.4, len), CFrame = base * CFrame.new(0, 0, -len / 2)}):Play()
		task.delay(0.14, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Size = Vector3.new(0.02, 0.02, len), Transparency = 1}):Play()
			end
		end)
	end
end

-- chorro vertical de sangre que baja del hombro hasta el suelo (video v1)
local function bloodStreak(top)
	for i = 1, 3 do
		local a = top + Vector3.new(rand(-0.5, 0.5), rand(0, 1), rand(-0.5, 0.5))
		local len = rand(7, 9.5)
		local b = a + Vector3.new(rand(-0.4, 0.4), -len, rand(-0.4, 0.4))
		local w = (i == 1) and 0.9 or rand(0.3, 0.5)
		local p = anchoredFx(Vector3.new(w, 0.12, 0.2), SHARD_COLORS[math.random(1, 3)])
		local base = lookCF(a, b)
		p.CFrame = base
		p.Parent = limbFolder
		Debris:AddItem(p, 1)
		TweenService:Create(p, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(w, 0.12, len), CFrame = base * CFrame.new(0, 0, -len / 2)}):Play()
		task.delay(0.16, function()
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Size = Vector3.new(0.03, 0.03, len), Transparency = 1}):Play()
			end
		end)
	end
end

-- salpicadura plana con puntas, mirando a la cámara (video v1)
local function bloodSplat(center, normal)
	local rot = lookCF(Vector3.new(0, 0, 0), normal) * CFrame.Angles(0, math.pi / 2, 0)
	local U, V = rot.YVector, rot.ZVector
	local made = {}
	for _ = 1, 16 do
		local r = rand(0.5, 1.7)
		local ang, rad = rand(0, 6.28), rand(0, 1.7)
		local pos = center + (U * math.cos(ang) + V * math.sin(ang)) * rad + normal * rand(-0.15, 0.15)
		local p = anchoredFx(Vector3.new(0.1, 0.3, 0.3), SHARD_COLORS[math.random(#SHARD_COLORS)])
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = CFrame.new(pos) * rot.Rotation
		p.Parent = limbFolder
		TweenService:Create(p, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.1, r * 2, r * 2)}):Play()
		table.insert(made, p)
	end
	for _ = 1, 26 do
		local th = rand(0, 6.28)
		local d = U * math.cos(th) + V * math.sin(th)
		local a = center + d * rand(1.0, 1.8)
		local len = rand(0.8, 2.4)
		local p = anchoredFx(Vector3.new(0.14, 0.14, 0.2), SHARD_COLORS[math.random(#SHARD_COLORS)])
		local base = lookCF(a, a + d)
		p.CFrame = base
		p.Parent = limbFolder
		TweenService:Create(p, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.14, 0.14, len), CFrame = base * CFrame.new(0, 0, -len / 2)}):Play()
		table.insert(made, p)
	end
	for _, p in ipairs(made) do Debris:AddItem(p, 0.7) end
	task.delay(0.18, function()
		for _, p in ipairs(made) do
			if p.Parent then
				TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{Size = p.Size * 0.15, Transparency = 1}):Play()
			end
		end
	end)
end

-- charcos que quedan (video v5): grandes, cerca de los pies, no desaparecen
local function limbPuddles(origin, groundY, count, life)
	for _ = 1, count do
		local d, a = rand(0.2, 2.8), rand(0, 6.28)
		puddleSeq += 1
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = BLOOD[math.random(#BLOOD)]
		p.Reflectance = 0.05
		p.Size = Vector3.new(0.05, 0.1, 0.1)
		p.CFrame = CFrame.new(origin.X + math.cos(a) * d, groundY + 0.03 + (puddleSeq % 60) * 0.003, origin.Z + math.sin(a) * d)
			* CFrame.Angles(0, 0, math.rad(90))
		p.Parent = puddleFolder
		local target = rand(2.2, 4.4)
		TweenService:Create(p, TweenInfo.new(rand(0.4, 0.7), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.05, target, target)}):Play()
		task.delay(life, function()
			if running and p.Parent then
				TweenService:Create(p, TweenInfo.new(3), {Transparency = 1}):Play()
				Debris:AddItem(p, 3.2)
			end
		end)
	end
end

-- la pieza cortada sale volando, cae y se queda en el suelo
local function launchPieces(char, hrp, pk, style)
	local outward = hrp.CFrame:VectorToWorldSpace(Vector3.new(pk.g.side, 0, 0))
	local phys = PhysicalProperties.new(1, 0.8, 0.1)
	for _, lp in ipairs(pk.parts) do
		local c = Instance.new("Part")
		c.Size = lp.Size
		c.Material = style.pieceMat
		c.Color = SKIN
		c.CanQuery = false; c.CanTouch = false
		c.CustomPhysicalProperties = phys
		c.CFrame = lp.CFrame
		c.Parent = limbFolder
		noCollideWithChar(c, char)
		c.AssemblyLinearVelocity = outward * rand(14, 24) + Vector3.new(rand(-6, 6), rand(18, 30), rand(-6, 6))
		c.AssemblyAngularVelocity = Vector3.new(rand(-10, 10), rand(-10, 10), rand(-10, 10))
		task.delay(style.pieceLife, function()
			if running and c.Parent then
				TweenService:Create(c, TweenInfo.new(0.5), {Transparency = 1}):Play()
				Debris:AddItem(c, 0.6)
			end
		end)
	end
end

local function finishLimb(fx)
	for _, p in ipairs(fx.parts) do
		if p.Parent then p.LocalTransparencyModifier = 0 end
	end
	for _, g in ipairs(fx.ghosts) do
		if g.Parent then g:Destroy() end
	end
	if fx.cap and fx.cap.Parent then fx.cap:Destroy() end
	for _, tn in ipairs(fx.tents) do
		for _, s in ipairs(tn.segs) do s:Destroy() end
	end
	if fx.ep then fx.ep:Destroy() end
	limbBusy[fx.key] = nil
	for i, f in ipairs(limbList) do
		if f == fx then table.remove(limbList, i) break end
	end
end

cancelLimbFx = function()
	limbEpoch += 1
	for i = #limbList, 1, -1 do
		pcall(finishLimb, limbList[i])
	end
end

local function resolveLimbs(char)
	local groups = char:FindFirstChild("Torso") and LIMBS_R6 or LIMBS_R15
	local byKey = {}
	for _, g in ipairs(groups) do
		if not limbBusy[g.key] then
			local parts = {}
			for _, n in ipairs(g.parts) do
				local p = char:FindFirstChild(n)
				if p and p:IsA("BasePart") then table.insert(parts, p) end
			end
			if #parts == #g.parts then byKey[g.key] = {g = g, parts = parts} end
		end
	end
	return byKey
end

local function pickLimbs(char, style)
	local by = resolveLimbs(char)
	local picks = {}
	if not style.legs then
		-- v1: siempre el brazo derecho (el de la izquierda en pantalla)
		local arm = by.RightArm or by.LeftArm
		if arm then table.insert(picks, arm) end
	else
		-- v5: brazo + pierna del mismo lado (lado al azar)
		local right = math.random() < 0.5
		local armK, legK = right and "RightArm" or "LeftArm", right and "RightLeg" or "LeftLeg"
		if not by[armK] then
			right = not right
			armK, legK = right and "RightArm" or "LeftArm", right and "RightLeg" or "LeftLeg"
		end
		if by[armK] then table.insert(picks, by[armK]) end
		if CONFIG.LimbIncludeLegs and by[legK] then table.insert(picks, by[legK]) end
		if #picks == 0 and by[legK] then table.insert(picks, by[legK]) end
	end
	return picks
end

local function spawnLimbGroup(pk, char, hrp, style, groundY, t0)
	local g = pk.g
	local first = pk.parts[1]
	local fx = {
		t0 = t0, char = char, hrp = hrp, key = g.key, parts = pk.parts, g = g, style = style,
		ghosts = {}, ghostBase = {}, tents = {}, groundY = groundY,
		ghostMade = false, steamOn = false, steamOff = false,
	}
	limbBusy[fx.key] = true
	table.insert(limbList, fx)

	local ep = Instance.new("Part")
	ep.Name = "LimbEmitter"
	ep.Anchored = true; ep.CanCollide = false; ep.CanQuery = false; ep.CanTouch = false
	ep.Transparency = 1
	ep.Size = Vector3.new(1, 1, 1)
	ep.CFrame = CFrame.new(first.Position)
	ep.Parent = limbFolder
	fx.ep = ep
	fx.steam = newEmitter(ep, {
		life = {1.0, 1.8}, speed = {3, 6}, spread = 20, accel = Vector3.new(0, 2, 0),
		color = ColorSequence.new(Color3.new(1, 1, 1)),
		size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5)}),
		transp = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1)}),
	})

	-- tentáculos del muñón: rojos con partes azules, en bloques
	for _ = 1, style.tents do
		local dl
		if g.leg then
			dl = Vector3.new(g.side * rand(0.3, 1), rand(-1, 0.2), rand(-0.8, 0.8))
		else
			dl = Vector3.new(g.side * rand(0.4, 1.2), rand(-0.4, 0.9), rand(-0.9, 0.9))
		end
		if dl.Magnitude < 0.05 then dl = Vector3.new(g.side, 0, 0) end
		local tn = {
			segs = {},
			seed = rand(0, 100),
			dirLocal = dl.Unit,
			length = style.tentLen * rand(0.75, 1.2),
			curl = rand(-0.25, 0.4),
			thick = style.tentThick * rand(0.8, 1.25),
		}
		local main = TENT_COLORS[math.random(1, 4)]
		for _ = 1, style.tentSegs do
			local s = Instance.new("Part")
			s.Anchored = true; s.CanCollide = false; s.CanQuery = false; s.CanTouch = false
			s.Material = Enum.Material.Plastic
			s.Color = (math.random() < 0.25) and TENT_COLORS[math.random(5, 6)] or main
			s.Size = Vector3.new(0.2, 0.2, 0.2)
			s.Transparency = 1
			s.Parent = limbFolder
			table.insert(tn.segs, s)
		end
		table.insert(fx.tents, tn)
	end
end

local function startLimbFx(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local style = LIMB_STYLES[CONFIG.LimbStyle] or LIMB_STYLES.v5
	local picks = pickLimbs(char, style)
	if #picks == 0 then return end
	refreshSkin(char)

	local ignore = {limbFolder, puddleFolder}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ignore, pl.Character) end
	end
	local groundY = findGround(hrp.Position, ignore)
	local t0 = os.clock()
	local epoch = limbEpoch
	local c0 = picks[1].parts[1].Position

	for _, pk in ipairs(picks) do
		launchPieces(char, hrp, pk, style)
	end

	if style == LIMB_STYLES.v1 then
		-- T0: explosión de trozos rojos
		shardBurst(c0, 70, {2, 4.2}, 0.45, {0.12, 0.42}, SHARD_COLORS)
		-- T0 + 1.1: salpicadura + chorro + cuchillas, justo antes de los tentáculos
		task.delay(math.max(0, style.gap - 0.05), function()
			if limbEpoch ~= epoch or not running then return end
			local first = picks[1].parts[1]
			if not first.Parent then return end
			local base = first.CFrame:PointToWorldSpace(Vector3.new(0, first.Size.Y * 0.3, 0))
			local cam = workspace.CurrentCamera
			local n = cam and (cam.CFrame.Position - base) or Vector3.new(0, 0, 1)
			if n.Magnitude < 0.1 then n = Vector3.new(0, 0, 1) end
			bloodSplat(base, n.Unit)
			bloodStreak(base + Vector3.new(0, 1.2, 0))
			bloodSpikes(base, 4, false)
		end)
	else
		-- v5: cuchillas, trozos negros, gotas y a veces destello rojo
		for _, pk in ipairs(picks) do
			local c = pk.parts[1].Position
			bloodSpikes(c, pk.g.leg and 5 or 10, false)
			if pk.g.leg then
				task.delay(0.3, function()
					if limbEpoch ~= epoch or not running then return end
					bloodSpikes(c, 3, true)
				end)
			end
		end
		shardBurst(c0, 10, {3, 8}, 1.0, {0.25, 0.6}, BLACK_BITS)
		shardBurst(c0, 16, {2.5, 6}, 0.6, {0.15, 0.32}, DROP_COLORS)
		if math.random() < 0.5 then glowBurst(c0) end
		if style.puddles > 0 then
			task.delay(0.25, function()
				if limbEpoch ~= epoch or not running or not hrp.Parent then return end
				limbPuddles(hrp.Position, groundY, style.puddles, CONFIG.LimbPuddleLife)
			end)
		end
	end

	for _, pk in ipairs(picks) do
		spawnLimbGroup(pk, char, hrp, style, groundY, t0)
	end
end

local function blockyPoints(tn, base, dir, t, reach, boost, groundY)
	local N = #tn.segs
	local pts = {base}
	local segLen = (tn.length * reach) / N
	local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local ori = CFrame.lookAt(Vector3.new(0, 0, 0), dir, up)
	local pos = base
	for j = 1, N do
		local pitch = tn.curl + boost * 0.7 + stepNoise(t + j * 0.13, tn.seed + j) * 0.9 * (1 - 0.4 * boost)
		local yaw = stepNoise(t * 1.1 + j * 0.21, tn.seed * 1.7 + j) * 1.1
		ori = ori * CFrame.Angles(pitch, yaw, 0)
		pos = pos + ori.LookVector * segLen
		if pos.Y < groundY + 0.15 then pos = Vector3.new(pos.X, groundY + 0.15, pos.Z) end
		pts[j + 1] = pos
	end
	return pts
end

local function sectionLimbFx(now)
	for i = #limbList, 1, -1 do
		local fx = limbList[i]
		local char, hrp = fx.char, fx.hrp
		if not (char and char.Parent and hrp and hrp.Parent) then
			finishLimb(fx)
		else
			local st = fx.style
			local el = now - fx.t0
			local G, W, SH, C = st.gap, st.W, st.SH, st.CT
			local tC = W + SH + st.YT

			if el >= tC + C then
				finishLimb(fx)
			else
				local first = fx.parts[1]

				-- la ropa (el miembro real) aparece al final
				local a = 0
				if el > tC then a = easeOut(clamp01((el - tC) / C)) end
				for _, p in ipairs(fx.parts) do
					if p.Parent then p.LocalTransparencyModifier = 1 - a end
				end

				-- miembro nuevo de piel (con carne roja en el hombro)
				if el >= W and not fx.ghostMade then
					fx.ghostMade = true
					for gi, p in ipairs(fx.parts) do
						local g = Instance.new("Part")
						g.Name = "LimbGhost"
						g.Size = p.Size * 0.15
						g.Color = SKIN
						g.Material = Enum.Material.SmoothPlastic
						g.CanCollide = false; g.CanQuery = false; g.CanTouch = false
						g.Massless = true
						g.CFrame = p.CFrame
						local w = Instance.new("Weld")
						w.Part0 = p
						w.Part1 = g
						w.Parent = g
						g.Parent = limbFolder
						table.insert(fx.ghosts, g)
						table.insert(fx.ghostBase, p.Size)

						if CONFIG.LimbGoreCap and gi == 1 then
							local cap = Instance.new("Part")
							cap.Name = "LimbGoreCap"
							cap.Shape = Enum.PartType.Ball
							cap.Size = Vector3.new(0.2, 0.2, 0.2)
							cap.Color = BLOOD[math.random(#BLOOD)]
							cap.Material = Enum.Material.SmoothPlastic
							cap.CanCollide = false; cap.CanQuery = false; cap.CanTouch = false
							cap.Massless = true
							cap.CFrame = p.CFrame
							local cw = Instance.new("Weld")
							cw.Part0 = p
							cw.Part1 = cap
							cw.Parent = cap
							cap.Parent = limbFolder
							fx.cap, fx.capWeld = cap, cw
						end
					end
				end
				if fx.ghostMade then
					local k = easeOut(clamp01((el - W) / SH))
					local s = 0.15 + 0.85 * k
					for gi, g in ipairs(fx.ghosts) do
						if g.Parent then
							g.Size = fx.ghostBase[gi] * s
							g.Transparency = a
						end
					end
					if fx.cap and fx.cap.Parent then
						local b = fx.ghostBase[1]
						local d = math.max(0.05, st.cap * (0.3 + 0.7 * k) * (1 - a))
						fx.cap.Size = Vector3.new(d, d, d)
						fx.capWeld.C0 = CFrame.new(0, b.Y * s / 2, 0)
					end
				end

				-- vapor
				if fx.ep then fx.ep.CFrame = CFrame.new(first.Position) end
				if el >= W and not fx.steamOn then
					fx.steamOn = true
					fx.steam.Rate = 24
				end
				if el >= tC + C * 0.6 and not fx.steamOff then
					fx.steamOff = true
					fx.steam.Rate = 0
				end

				-- tentáculos: nada hasta "gap", salen, se enroscan en una bola y se retraen
				local reach, boost = 0, 0
				local cs = W - 0.4
				if el < G then
					reach = 0
				elseif el < cs then
					reach = 0.2 + 0.8 * easeOut(clamp01((el - G) / 0.12))
				elseif el < W then
					local k = easeInOut(clamp01((el - cs) / (W - cs)))
					reach = 1 - 0.7 * k
					boost = k
				else
					reach = 0.3 * (1 - easeInOut(clamp01((el - W) / 0.25)))
					boost = 1
				end

				local base = first.CFrame:PointToWorldSpace(Vector3.new(0, first.Size.Y * 0.3, 0))
				for _, tn in ipairs(fx.tents) do
					local dir = hrp.CFrame:VectorToWorldSpace(tn.dirLocal)
					local pts = blockyPoints(tn, base, dir, now, reach, boost, fx.groundY)
					local N = #tn.segs
					for j = 1, N do
						local p0, p1 = pts[j], pts[j + 1]
						local d = (p1 - p0).Magnitude
						local seg = tn.segs[j]
						if d < 0.01 or reach < 0.02 then
							seg.Transparency = 1
						else
							local taper = 1 - (j - 1) / N * 0.5
							seg.Size = Vector3.new(tn.thick * taper, tn.thick * taper, d + 0.05)
							seg.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
							seg.Transparency = 0
						end
					end
				end
			end
		end
	end
end

--==================== EVENTOS ====================--
local function hookDeath(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end

	track(hum.Died:Connect(function()
		if cancelLimbFx then pcall(cancelLimbFx) end
		if not (CONFIG.Enabled and running) then return end
		if state.busy then return end
		startRegen(char)
	end))

	local lastHealth = hum.Health
	track(hum.HealthChanged:Connect(function(h)
		local prev = lastHealth
		lastHealth = h
		if not (CONFIG.Enabled and CONFIG.LimbRegen and running) then return end
		if h <= 0 or state.busy then return end
		if prev - h < CONFIG.LimbMinDamage then return end
		local now = os.clock()
		if now - lastLimbTime < CONFIG.LimbCooldown then return end
		if #limbList >= CONFIG.LimbMaxActive then return end
		lastLimbTime = now
		safe("regen-dano", startLimbFx, char)
	end))
end

local function onCharacterAdded(char)
	if cancelLimbFx then pcall(cancelLimbFx) end
	task.spawn(hookDeath, char)
	if state.busy and not state.newChar then
		task.spawn(function()
			local hrp = char:WaitForChild("HumanoidRootPart", 10)
			if not hrp or not state.busy or state.newChar then return end
			state.newChar = char
			state.holdCF = CONFIG.ReviveAtDeathSpot and state.deathCF or hrp.CFrame
			hrp.CFrame = state.holdCF
			hrp.Anchored = not CONFIG.MoveDuringRegen
			state.controlNew = true
			state.newReady = true

			-- los trozos del suelo no te empujan ni te bloquean al moverte
			safe("sin-choque", function()
				local fx = state.fx
				if fx and fx.folder then
					for _, d in ipairs(fx.folder:GetDescendants()) do
						if d:IsA("BasePart") and not d.Anchored then noCollideWithChar(d, char) end
					end
				end
			end)
		end)
	end
end

track(player.CharacterAdded:Connect(onCharacterAdded))
if player.Character then task.spawn(hookDeath, player.Character) end

track(RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hrp and hum.Health > 0 and hrp.Position.Y > workspace.FallenPartsDestroyHeight + 30 then
		state.lastSafeCF = hrp.CFrame
		local inv = hrp.CFrame:Inverse()
		local rels = {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then rels[d] = inv * d.CFrame end
		end
		state.lastRels = rels
		state.lastRelsChar = char
	end
end))

--==================== ACTUALIZACIÓN POR FRAME ====================--
local function tentaclePoints(tn, base, t, reach, droop, groundY)
	local pts = {base}
	local N = #tn.segs
	local segLen = (tn.length * reach) / N

	local dir = tn.dir * (1 - droop) + Vector3.new(0, -1, 0) * droop
	if dir.Magnitude < 0.05 then dir = Vector3.new(0, -1, 0) end
	dir = dir.Unit
	local up = math.abs(dir.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local ori = CFrame.lookAt(Vector3.new(0, 0, 0), dir, up)

	local pos = base
	for j = 1, N do
		local pitch = (tn.curl + 0.35 * math.sin(t * tn.speed * CONFIG.TentacleSpeed + j * 0.9 + tn.phase)) * (1 - droop * 0.6)
		local yaw = tn.twist + 0.5 * math.cos(t * tn.speed * 1.2 * CONFIG.TentacleSpeed + j * 0.7 + tn.phase * 1.3)
		ori = ori * CFrame.Angles(pitch, yaw, 0)
		pos = pos + ori.LookVector * segLen
		if pos.Y < groundY + 0.15 then pos = Vector3.new(pos.X, groundY + 0.15, pos.Z) end
		pts[j + 1] = pos
	end
	return pts
end

local function revealAlpha(name, now)
	local at = state.arriveByName[name]
	if not at then
		if state.phase == "rebuild" then at = state.rebuildStart + CONFIG.RebuildTime
		else return 0 end
	end
	local dur = state.revealDur[name] or CONFIG.ClothTime
	return easeOut(clamp01((now - at) / dur))
end

local function applyReveal(model, now, hidden)
	local headKey = model:FindFirstChild("Head")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local a = 0
			if not hidden then
				local key = (d.Parent == model) and d or headKey
				a = key and revealAlpha(key.Name, now) or 0
			end
			d.LocalTransparencyModifier = 1 - a
		elseif d:IsA("Decal") or d:IsA("Texture") then
			if state.decalOrig[d] == nil then state.decalOrig[d] = d.Transparency end
			local a = 0
			if not hidden then
				local pp = d.Parent
				local key = (pp and pp.Parent == model) and pp or headKey
				a = key and revealAlpha(key.Name, now) or 0
			end
			d.Transparency = 1 - (1 - state.decalOrig[d]) * a
		end
	end
end

local function sectionShake(dt)
	local cam = workspace.CurrentCamera
	if state.shake > 0.02 and cam then
		local a = state.shake
		cam.CFrame = cam.CFrame * CFrame.new(rand(-a, a) * 0.15, rand(-a, a) * 0.15, 0)
			* CFrame.Angles(0, 0, rand(-a, a) * 0.01)
		state.shake = math.max(0, state.shake - dt * CONFIG.ShakeAmount * 1.6)
	end
end

local function sectionGuards(now)
	if state.flashDeadline and now > state.flashDeadline then
		state.flashDeadline = nil
		flash:ClearAllChildren()
		flash.BackgroundTransparency = 1
	end
	if state.blurDeadline and now > state.blurDeadline then
		state.blurDeadline = nil
		blur.Size = 0
	end
	if not state.fx then
		local cam = workspace.CurrentCamera
		local s = cam and cam.CameraSubject
		if cam and (s == nil or not s:IsDescendantOf(workspace) or s:FindFirstAncestor("RickPrimeFX")) then
			restoreCamera(player.Character)
		end
	end
end

local function sectionOld(now)
	local old = state.oldChar
	if not (old and old.Parent) then return end
	if state.body == "old" then
		local fx = state.fx
		if fx then
			for part, rel in pairs(fx.bodyRels) do
				if part.Parent then
					part.Anchored = true
					part.CFrame = state.deathCF * rel
				end
			end
		end
		applyReveal(old, now, false)
	elseif state.hideOld then
		applyReveal(old, now, true)
	end
end

local function sectionNew(now)
	local nc = state.newChar
	if not (state.controlNew and nc and nc.Parent) then return end
	local hrp = nc:FindFirstChild("HumanoidRootPart")
	if hrp and state.holdCF and not CONFIG.MoveDuringRegen then
		hrp.Anchored = true
		hrp.CFrame = state.holdCF
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	applyReveal(nc, now, state.body ~= "new")
end

local function bodyChar()
	if state.body == "old" then return state.oldChar end
	return state.newChar
end

local function sectionCamera()
	local cam = workspace.CurrentCamera
	local fx = state.fx
	if not (CONFIG.LowCamera and cam and fx and fx.burstAt) then return end

	if CONFIG.MoveDuringRegen and state.phase == "writhe" and fx.head and fx.head.Parent then
		local nc = state.newChar
		local hrp = nc and nc:FindFirstChild("HumanoidRootPart")
		if hrp then
			local target = Vector3.new(hrp.Position.X, (fx.groundY or hrp.Position.Y) + 0.9, hrp.Position.Z)
			local cur = fx.head.Position
			fx.head.CFrame = fx.head.CFrame.Rotation + cur:Lerp(target, 0.35)
		end
	end

	local subject
	if fx.head and fx.head.Parent and not fx.headGone then
		subject = fx.head
	else
		local b = bodyChar()
		subject = b and b:FindFirstChild("Head")
	end
	if subject and cam.CameraSubject ~= subject then cam.CameraSubject = subject end
end

local function sectionTentacles(now, fx)
	local center
	if fx.head and fx.head.Parent then center = fx.head.Position
	else center = Vector3.new(state.deathCF.X, (fx.groundY or 0) + 1, state.deathCF.Z) end

	-- en la reconstrucción el vapor y los tentáculos siguen al cuerpo nuevo
	if state.phase == "rebuild" then
		local b = bodyChar()
		local bh = b and b:FindFirstChild("HumanoidRootPart")
		if bh then center = bh.Position end
	end
	if fx.emitPart then fx.emitPart.CFrame = CFrame.new(center + Vector3.new(0, 0.5, 0)) end

	local reachG, droop = 0, 0
	if state.phase == "writhe" then
		reachG = 0.3 + 0.7 * easeOut(clamp01((now - fx.burstAt) / 1.0))
	elseif state.phase == "rebuild" then
		droop = easeInOut(clamp01((now - state.rebuildStart) / 0.6)) * 0.8
	end

	for _, tn in ipairs(fx.tentacles) do
		local reach = reachG
		if state.phase == "rebuild" then
			local rs, re = tn.rs or now, tn.re or now
			reach = 1 - easeInOut(clamp01((now - rs) / math.max(0.05, re - rs)))
		end

		local base = center
		if tn.anchorName then
			local ap = fx.clone and fx.clone:FindFirstChild(tn.anchorName)
			if not (ap and ap.Parent) then
				local b = bodyChar()
				ap = b and b:FindFirstChild(tn.anchorName)
			end
			if ap and ap:IsA("BasePart") then
				base = ap.CFrame:PointToWorldSpace(tn.localOff)
			end
		end

		local pts = tentaclePoints(tn, base, now, reach, droop, fx.groundY or 0)
		local N = #tn.segs
		for j = 1, N do
			local a, b = pts[j], pts[j + 1]
			local d = (b - a).Magnitude
			local seg = tn.segs[j]
			if d < 0.01 or reach < 0.03 then
				seg.Transparency = 1
			else
				local taper = 1 - (j - 1) / N * 0.55
				seg.Size = Vector3.new(tn.thick * taper, tn.thick * taper, d + 0.05)
				seg.CFrame = CFrame.lookAt((a + b) / 2, b)
				seg.Transparency = 0
			end
		end
	end
end

local function targetOf(e, fx)
	if state.body == "old" and fx.bodyRels[e.real] then
		return state.deathCF * fx.bodyRels[e.real]
	end
	return e.real.CFrame
end

local function sectionLimbs(now)
	if state.phase ~= "rebuild" then return end
	local fx = state.fx
	if not fx then return end
	if state.body == "old" and not (state.oldChar and state.oldChar.Parent) then
		state.body = "new"
	end
	for _, e in ipairs(state.limbs) do
		if not e.real.Parent then
			local nc = state.newChar
			local r2 = nc and nc:FindFirstChild(e.name)
			if r2 and r2:IsA("BasePart") then e.real = r2 end
		end

		if not e.gone then
			if e.kind == "core" then
				-- torso/cabeza: la pieza amarilla del suelo desaparece y el cuerpo con ropa aparece
				if now >= e.arriveAt then
					e.gone = true
					local cp = fx.clone and fx.clone:FindFirstChild(e.name)
					if cp then cp:Destroy() end
					if e.name == "Head" then fx.headGone = true end
				end
			else
				local p, real = e.part, e.real
				if p and p.Parent and real.Parent then
					local t0 = state.rebuildStart + e.delay
					if now < t0 then
						-- espera en el suelo temblando
						local k = 0.12
						p.CFrame = e.startCF * CFrame.new(rand(-k, k), rand(-k, k), rand(-k, k))
					elseif now < e.arriveAt then
						-- vuela hasta su sitio en el cuerpo
						local t = clamp01((now - t0) / e.dur)
						local cf = e.startCF:Lerp(targetOf(e, fx), easeInOut(t))
						p.CFrame = cf + Vector3.new(0, math.sin(t * math.pi) * 2.5, 0)
					else
						-- pegado al cuerpo, amarillo; luego llega la ropa
						p.CFrame = targetOf(e, fx)
						if e.kind == "leg" then
							local gk = clamp01((now - e.clothStart) / (e.grayEnd - e.clothStart))
							p.Color = e.skin:Lerp(GRAY, easeOut(gk))
							if now > e.grayEnd then
								p.Transparency = easeOut(clamp01((now - e.grayEnd) / (e.doneAt - e.grayEnd)))
							end
						else
							if now > e.clothStart then
								p.Transparency = easeOut(clamp01((now - e.clothStart) / (e.doneAt - e.clothStart)))
							end
						end
						if now >= e.doneAt then
							e.gone = true
							p:Destroy()
						end
					end
				end
			end
		end
	end
end

local function step(dt)
	if not running then return end
	local now = os.clock()
	safe("seguros", sectionGuards, now)
	safe("camara-temblor", sectionShake, dt)
	safe("cuerpo-viejo", sectionOld, now)
	safe("cuerpo-nuevo", sectionNew, now)
	safe("limbs-dano", sectionLimbFx, now)
	local fx = state.fx
	if fx and fx.burstAt then
		safe("camara", sectionCamera)
		safe("tentaculos", sectionTentacles, now, fx)
		safe("miembros", sectionLimbs, now)
	end
end

RunService:BindToRenderStep("RickPrimeRegen", Enum.RenderPriority.Last.Value, step)

--==================== LIMPIEZA ====================--
local function cleanup()
	running = false
	pcall(function() RunService:UnbindFromRenderStep("RickPrimeRegen") end)
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	connections = {}
	pcall(cancelLimbFx)
	pcall(releaseNew)
	pcall(clearScreenFx)
	pcall(restoreCamera, player.Character)
	pcall(function() if state.fx and state.fx.folder then state.fx.folder:Destroy() end end)
	pcall(function() puddleFolder:Destroy() end)
	pcall(function() limbFolder:Destroy() end)
	pcall(function() gui:Destroy() end)
	pcall(function() blur:Destroy() end)
end
env.__RickPrimeRegenCleanup = cleanup