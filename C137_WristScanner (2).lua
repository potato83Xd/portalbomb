--[[
	C-137 WRIST SCANNER
	LocalScript -> StarterPlayer > StarterPlayerScripts
	100% local. Sin RemoteEvents / RemoteFunctions / FireServer / InvokeServer.
	Módulos internos: Config, Util, Sound, Database, Bracelet, Scanners, Interface.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local Stats = game:GetService("Stats")
local GroupService = game:GetService("GroupService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local old = PlayerGui:FindFirstChild("C137Scanner")
if old then old:Destroy() end

local SESSION_START = os.clock()

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local Config = {}

Config.Colors = {
	Bg = Color3.fromRGB(10, 52, 92),
	Panel = Color3.fromRGB(18, 92, 140),
	Cyan = Color3.fromRGB(0, 229, 255),
	Blue = Color3.fromRGB(0, 150, 255),
	Text = Color3.fromRGB(235, 252, 255),
	Dim = Color3.fromRGB(165, 210, 232),
	Warn = Color3.fromRGB(255, 176, 0),
	Danger = Color3.fromRGB(255, 60, 90),
	Ok = Color3.fromRGB(60, 255, 170),
}

-- Pega aquí tus propios IDs de audio ("rbxassetid://123..."). Vacío = ese sonido no suena.
Config.Sounds = {
	activate = "",
	deactivate = "",
	scan = "",
	identify = "",
	confirm = "",
	error = "",
	notify = "",
	loading = "",
}

Config.Defaults = {
	Effects = true,
	Sound = true,
	Volume = 0.6,
	UiScale = 1,
	Auto = false,
	AutoInterval = 4,
	Range = 120,
	Opacity = 0.05,
	Compact = false,
}

Config.MaxHistory = 30
Config.Keybind = Enum.KeyCode.E -- tecla de escaneo rápido

Config.Modes = {
	{ id = "identity", label = "IDENTITY" },
	{ id = "life", label = "LIFE" },
	{ id = "species", label = "SPECIES" },
	{ id = "threat", label = "THREAT" },
	{ id = "environment", label = "ENVIRONMENT" },
	{ id = "object", label = "OBJECT" },
}

local C = Config.Colors

local Settings = {}
local function resetSettings()
	for k, v in pairs(Config.Defaults) do
		Settings[k] = v
	end
end
resetSettings()

------------------------------------------------------------------------
-- UTIL
------------------------------------------------------------------------
local Util = {}

function Util.new(class, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	inst.Parent = parent
	return inst
end

function Util.corner(r)
	return Util.new("UICorner", { CornerRadius = UDim.new(0, r) })
end

function Util.stroke(color, thickness, transparency)
	return Util.new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Util.tween(inst, duration, props, style, direction)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

function Util.newMaid()
	local maid = { tasks = {} }
	function maid:give(item)
		table.insert(self.tasks, item)
		return item
	end
	function maid:clean()
		for _, item in ipairs(self.tasks) do
			local t = typeof(item)
			if t == "RBXScriptConnection" then
				item:Disconnect()
			elseif t == "Instance" then
				item:Destroy()
			elseif t == "function" then
				item()
			end
		end
		table.clear(self.tasks)
	end
	return maid
end

function Util.esc(s)
	s = tostring(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

function Util.hex(color)
	return string.format(
		"#%02x%02x%02x",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Util.renderLines(lines)
	local out = {}
	local keyColor = Util.hex(C.Cyan)
	for _, l in ipairs(lines) do
		local tag = l.sim and ' <font color="#ffb000">[SIM]</font>' or ""
		if l.k == "" then
			table.insert(out, Util.esc(l.v))
		else
			table.insert(out, string.format('<font color="%s">%s</font>  %s%s', keyColor, Util.esc(l.k), Util.esc(l.v), tag))
		end
	end
	return table.concat(out, "\n")
end

function Util.vec(v)
	return string.format("%.1f, %.1f, %.1f", v.X, v.Y, v.Z)
end

------------------------------------------------------------------------
-- SOUND
------------------------------------------------------------------------
local Sound = { Enabled = true, Volume = 0.6, pool = {} }

function Sound.init(maid)
	for name, id in pairs(Config.Sounds) do
		if id ~= "" then
			local s = Instance.new("Sound")
			s.Name = "C137_" .. name
			s.SoundId = id
			s.Parent = SoundService
			Sound.pool[name] = s
			maid:give(s)
		end
	end
end

function Sound.play(name)
	local s = Sound.pool[name]
	if not s or not Sound.Enabled then
		return
	end
	s.Volume = Sound.Volume
	s:Play()
end

function Sound.configuredCount()
	local n, total = 0, 0
	for _, id in pairs(Config.Sounds) do
		total = total + 1
		if id ~= "" then
			n = n + 1
		end
	end
	return n, total
end

------------------------------------------------------------------------
-- DATABASE (memoria local de la sesión)
------------------------------------------------------------------------
local Database = { history = {}, errors = {} }
local nextId = 0

local function sessionStamp()
	local t = math.floor(os.clock() - SESSION_START)
	return string.format("T+%02d:%02d", math.floor(t / 60), t % 60)
end

function Database.add(entry)
	nextId = nextId + 1
	entry.id = nextId
	entry.timeText = sessionStamp()
	entry.fav = false
	table.insert(Database.history, 1, entry)
	while #Database.history > Config.MaxHistory do
		local removed = false
		for i = #Database.history, 1, -1 do
			if not Database.history[i].fav then
				table.remove(Database.history, i)
				removed = true
				break
			end
		end
		if not removed then
			break
		end
	end
	return entry
end

function Database.find(id)
	for i, e in ipairs(Database.history) do
		if e.id == id then
			return e, i
		end
	end
end

function Database.toggleFav(id)
	local e = Database.find(id)
	if e then
		e.fav = not e.fav
	end
end

function Database.remove(id)
	local _, i = Database.find(id)
	if i then
		table.remove(Database.history, i)
	end
end

function Database.clearNonFavorites()
	for i = #Database.history, 1, -1 do
		if not Database.history[i].fav then
			table.remove(Database.history, i)
		end
	end
end

function Database.logError(msg)
	table.insert(Database.errors, 1, { t = sessionStamp(), msg = tostring(msg) })
	while #Database.errors > 50 do
		table.remove(Database.errors)
	end
end

function Database.exportText()
	local out = { "C-137 WRIST SCANNER - exportación local (" .. #Database.history .. " registros)" }
	for _, e in ipairs(Database.history) do
		table.insert(out, string.format("\n[%s] %s | %s%s", e.timeText, e.modeLabel, e.targetName, e.fav and " | FAV" or ""))
		for _, l in ipairs(e.result.lines) do
			table.insert(out, string.format("  %s: %s%s", l.k, l.v, l.sim and " [SIMULADO]" or ""))
		end
	end
	return table.concat(out, "\n")
end

------------------------------------------------------------------------
-- BRACELET (brazalete físico, solo visible para el jugador local)
------------------------------------------------------------------------
local Bracelet = {}
Bracelet.__index = Bracelet

function Bracelet.new()
	local self = setmetatable({}, Bracelet)
	self.maid = Util.newMaid()
	self.parts = {}
	self.active = false
	self.maid:give(LocalPlayer.CharacterAdded:Connect(function(char)
		self:build(char)
	end))
	if LocalPlayer.Character then
		task.spawn(function()
			self:build(LocalPlayer.Character)
		end)
	end
	return self
end

function Bracelet:clear()
	for _, p in ipairs(self.parts) do
		p:Destroy()
	end
	table.clear(self.parts)
	self.screen, self.light, self.emitter, self.rings = nil, nil, nil, nil
end

function Bracelet:build(char)
	self:clear()
	local hum = char:WaitForChild("Humanoid", 8)
	if not hum then
		return
	end
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	local arm = char:WaitForChild(isR15 and "LeftLowerArm" or "Left Arm", 8)
	if not arm or not char.Parent then
		return
	end

	local yOff = isR15 and -0.25 or -0.6
	local axis = CFrame.new(0, yOff, 0) * CFrame.Angles(0, 0, math.pi / 2)

	local function make(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		if shape then
			p.Shape = shape
		end
		p.CFrame = arm.CFrame * cf
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = arm
		weld.Part1 = p
		weld.Parent = p
		p.Parent = char
		table.insert(self.parts, p)
		return p
	end

	local dark = Color3.fromRGB(20, 45, 80)
	make("C137Band", Vector3.new(0.75, 1.32, 1.32), axis, dark, Enum.Material.Metal, Enum.PartType.Cylinder)
	self.rings = {
		make("C137RingA", Vector3.new(0.1, 1.38, 1.38), axis * CFrame.new(0.3, 0, 0), C.Blue, Enum.Material.Neon, Enum.PartType.Cylinder),
		make("C137RingB", Vector3.new(0.1, 1.38, 1.38), axis * CFrame.new(-0.3, 0, 0), C.Blue, Enum.Material.Neon, Enum.PartType.Cylinder),
	}
	self.screen = make("C137Screen", Vector3.new(0.14, 0.55, 0.85), CFrame.new(-0.7, yOff, 0), Color3.fromRGB(10, 40, 90), Enum.Material.Neon)

	self.light = Instance.new("PointLight")
	self.light.Color = C.Cyan
	self.light.Range = 8
	self.light.Brightness = 0
	self.light.Parent = self.screen

	self.emitter = Instance.new("ParticleEmitter")
	self.emitter.Rate = 0
	self.emitter.Lifetime = NumberRange.new(0.5, 0.9)
	self.emitter.Speed = NumberRange.new(2, 5)
	self.emitter.SpreadAngle = Vector2.new(180, 180)
	self.emitter.LightEmission = 1
	self.emitter.Color = ColorSequence.new(C.Cyan)
	self.emitter.Size = NumberSequence.new(0.18, 0)
	self.emitter.Transparency = NumberSequence.new(0.2, 1)
	self.emitter.Parent = self.screen

	self:cacheArm(char, isR15)
	self:setActive(self.active, true)
end

function Bracelet:cacheArm(char, isR15)
	local shoulder, elbow, neck
	if isR15 then
		local upper = char:FindFirstChild("LeftUpperArm")
		local lower = char:FindFirstChild("LeftLowerArm")
		shoulder = upper and upper:FindFirstChild("LeftShoulder")
		elbow = lower and lower:FindFirstChild("LeftElbow")
		local head = char:FindFirstChild("Head")
		neck = head and head:FindFirstChild("Neck")
	else
		local torso = char:FindFirstChild("Torso")
		shoulder = torso and torso:FindFirstChild("Left Shoulder")
	end
	if not shoulder then
		self.arm = nil
		return
	end
	if self.arm and self.arm.shoulder == shoulder then
		return
	end
	self.arm = {
		shoulder = shoulder,
		s0 = shoulder.C0,
		elbow = elbow,
		e0 = elbow and elbow.C0,
		neck = neck,
		n0 = neck and neck.C0,
		isR15 = isR15,
		raised = false,
	}
end

function Bracelet:armNeedsRaise()
	return self.arm ~= nil and not self.arm.raised
end

-- Gesto de "mirar el reloj": brazo izquierdo doblado a través del pecho,
-- muñeca hacia arriba y cabeza inclinada hacia ella (solo local).
function Bracelet:setArmRaised(on, duration)
	local a = self.arm
	if not a or not a.shoulder.Parent then
		return
	end
	a.raised = on
	local sGoal, eGoal, nGoal = a.s0, a.e0, a.n0
	if on then
		if a.isR15 then
			-- hombro: adelante 35° y giro interno -70° para que el codo doble hacia el pecho
			sGoal = a.s0 * CFrame.Angles(math.rad(35), math.rad(-70), 0)
			-- codo: flexión 100° + giro de muñeca para que la pantalla mire hacia arriba
			eGoal = a.e0 and (a.e0 * CFrame.Angles(math.rad(100), math.rad(-65), 0))
			nGoal = a.n0 and (a.n0 * CFrame.Angles(math.rad(-22), 0, 0))
		else
			sGoal = a.s0 * CFrame.Angles(0, 0, -math.rad(70))
		end
	end
	local d = duration or 0.4
	if d <= 0 then
		a.shoulder.C0 = sGoal
		if a.elbow and eGoal then
			a.elbow.C0 = eGoal
		end
		if a.neck and nGoal then
			a.neck.C0 = nGoal
		end
		return
	end
	Util.tween(a.shoulder, d, { C0 = sGoal }, Enum.EasingStyle.Quad)
	if a.elbow and eGoal then
		Util.tween(a.elbow, d, { C0 = eGoal }, Enum.EasingStyle.Quad)
	end
	if a.neck and nGoal then
		Util.tween(a.neck, d, { C0 = nGoal }, Enum.EasingStyle.Quad)
	end
end

function Bracelet:setActive(on, silent)
	self.active = on
	if not self.screen then
		return
	end
	Util.tween(self.screen, 0.4, { Color = on and C.Cyan or Color3.fromRGB(10, 40, 90) })
	Util.tween(self.light, 0.4, { Brightness = on and 2 or 0 })
	for _, r in ipairs(self.rings) do
		Util.tween(r, 0.4, { Color = on and C.Cyan or C.Blue })
	end
	if on and not silent and Settings.Effects then
		self.emitter:Emit(24)
	end
end

function Bracelet:screenPosition()
	local cam = Workspace.CurrentCamera
	if not self.screen or not self.screen.Parent or not cam then
		return nil
	end
	local v = cam:WorldToViewportPoint(self.screen.Position)
	if v.Z > 0 then
		return Vector2.new(v.X, v.Y)
	end
	return nil
end

function Bracelet:isAttached()
	return self.screen ~= nil and self.screen.Parent ~= nil
end

function Bracelet:destroy()
	self:setArmRaised(false, 0)
	self.maid:clean()
	self:clear()
end

------------------------------------------------------------------------
-- SCANNERS (solo APIs y datos disponibles en el cliente)
------------------------------------------------------------------------
local Scanners = {}

local function myRoot()
	local c = LocalPlayer.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function charRoot(p)
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function distTo(pos)
	local r = myRoot()
	if not r then
		return nil
	end
	return (r.Position - pos).Magnitude
end

local function fmtDist(d)
	return d and string.format("%.1f studs", d) or "No disponible"
end

local function L(k, v, sim)
	return { k = k, v = tostring(v), sim = sim or false }
end

local function topModel(part)
	local top = part
	while top.Parent and top.Parent ~= Workspace and top.Parent:IsA("Model") do
		top = top.Parent
	end
	return top
end

function Scanners.nearbyPlayers(range)
	local out = {}
	local r = myRoot()
	for _, p in ipairs(Players:GetPlayers()) do
		local root = charRoot(p)
		if root then
			local d = r and (r.Position - root.Position).Magnitude or 0
			if p == LocalPlayer or d <= range then
				table.insert(out, {
					kind = "player",
					instance = p,
					name = p.DisplayName .. " (@" .. p.Name .. ")" .. (p == LocalPlayer and " (tú)" or ""),
					distance = d,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	return out
end

function Scanners.nearbyObjects(range, opts)
	opts = opts or {}
	local out = {}
	local r = myRoot()
	if not r then
		return out
	end
	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.MaxParts = opts.maxParts or 200
	local parts = Workspace:GetPartBoundsInRadius(r.Position, math.min(range, opts.maxRadius or 80), params)
	local byTop = {}
	for _, part in ipairs(parts) do
		if not part:IsA("Terrain") then
			local top = topModel(part)
			local e = byTop[top]
			if not e then
				local hum = top:IsA("Model") and top:FindFirstChildOfClass("Humanoid") or nil
				local pos = top:IsA("Model") and top:GetPivot().Position or top.Position
				e = {
					kind = "object",
					instance = top,
					isNpc = hum ~= nil,
					moving = false,
					distance = (r.Position - pos).Magnitude,
					name = top.Name .. (hum and " [NPC]" or (" [" .. top.ClassName .. "]")),
				}
				byTop[top] = e
				table.insert(out, e)
			end
			if not part.Anchored and part.AssemblyLinearVelocity.Magnitude > 0.5 then
				e.moving = true
			end
		end
	end
	if opts.onlyLive then
		for i = #out, 1, -1 do
			if not (out[i].isNpc or out[i].moving) then
				table.remove(out, i)
			end
		end
	end
	table.sort(out, function(a, b)
		return a.distance < b.distance
	end)
	while #out > (opts.limit or 12) do
		table.remove(out)
	end
	return out
end

function Scanners.summary(t)
	if t.kind == "player" then
		local p = t.instance
		local root = charRoot(p)
		return {
			L("Nombre", p.Name),
			L("Display Name", p.DisplayName),
			L("User ID", p.UserId),
			L("Distancia", root and fmtDist(distTo(root.Position)) or "No disponible"),
			L("Conexión", p.Parent == Players and "Conectado" or "Desconectado"),
		}
	end
	local inst = t.instance
	if not inst or not inst.Parent then
		return { L("Objeto", "Ya no existe") }
	end
	local pos = inst:IsA("Model") and inst:GetPivot().Position or inst.Position
	return {
		L("Nombre", inst.Name),
		L("Clase", inst.ClassName),
		L("Distancia", fmtDist(distTo(pos))),
		L("Posición", Util.vec(pos)),
	}
end

-- Equipo visible del jugador (datos replicados al cliente) ----------------
function Scanners.equipment(p, charOverride)
	local info = { tools = {}, accNames = {}, accLines = {}, accCount = 0 }
	local char = charOverride or (p and p.Character)
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Tool") then
				table.insert(info.tools, c.Name)
			end
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			for _, acc in ipairs(hum:GetAccessories()) do
				info.accCount = info.accCount + 1
				table.insert(info.accNames, acc.Name)
				local okT, at = pcall(function()
					return acc.AccessoryType.Name
				end)
				table.insert(info.accLines, acc.Name .. ((okT and at ~= "Unknown") and (" (" .. at .. ")") or ""))
			end
			info.rig = hum.RigType.Name
			info.seat = hum.SeatPart and hum.SeatPart.Name or nil
			local function sv(name)
				local v = hum:FindFirstChild(name)
				return v and v:IsA("NumberValue") and v.Value or nil
			end
			info.scale = { height = sv("BodyHeightScale"), width = sv("BodyWidthScale"), depth = sv("BodyDepthScale"), head = sv("HeadScale") }
			info.height = char:GetExtentsSize().Y
		end
		local function assetId(str)
			if not str or str == "" then
				return nil
			end
			return str:match("id=(%d+)") or str:match("%d+") or str
		end
		local shirt = char:FindFirstChildOfClass("Shirt")
		local pants = char:FindFirstChildOfClass("Pants")
		local graphic = char:FindFirstChildOfClass("ShirtGraphic")
		info.shirt = shirt and assetId(shirt.ShirtTemplate)
		info.pants = pants and assetId(pants.PantsTemplate)
		info.graphic = graphic and assetId(graphic.Graphic)
		local bc = char:FindFirstChildOfClass("BodyColors")
		info.skin = bc and Util.hex(bc.HeadColor3) or nil
	end
	-- Mochila y carpetas del jugador: solo aparecen si el juego las replica al cliente
	local bp = p and p:FindFirstChildOfClass("Backpack")
	if bp then
		info.backpack = {}
		for _, t in ipairs(bp:GetChildren()) do
			table.insert(info.backpack, t.Name)
		end
	end
	info.guiTools = {}
	local pg = p and p:FindFirstChildOfClass("PlayerGui")
	if pg then
		for _, d in ipairs(pg:GetDescendants()) do
			if d:IsA("Tool") then
				table.insert(info.guiTools, d.Name)
				if #info.guiTools >= 20 then
					break
				end
			end
		end
	end
	info.folders = {}
	for _, c in ipairs(p and p:GetChildren() or {}) do
		if c:IsA("Folder") or c:IsA("Configuration") then
			local kids = c:GetChildren()
			local items = {}
			for i, it in ipairs(kids) do
				if i > 12 then
					table.insert(items, "...")
					break
				end
				local okV, val = pcall(function()
					return it.Value
				end)
				table.insert(items, it.Name .. ((okV and val ~= nil) and ("=" .. tostring(val)) or ""))
			end
			table.insert(info.folders, { name = c.Name, count = #kids, items = items })
		end
	end
	return info
end

-- Datos públicos de Roblox (consultas web, pueden tardar; usar dentro de un hilo)
function Scanners.web(p)
	local assets, social = {}, {}
	local ok, info = pcall(function()
		return Players:GetCharacterAppearanceInfoAsync(p.UserId)
	end)
	if ok and info and info.assets then
		table.insert(assets, L("Total", #info.assets))
		for i, a in ipairs(info.assets) do
			if i > 18 then
				table.insert(assets, L("...", "y " .. (#info.assets - 18) .. " más"))
				break
			end
			table.insert(assets, L((a.assetType and a.assetType.name) or "Asset", tostring(a.name) .. " [" .. tostring(a.id) .. "]"))
		end
		if info.playerAvatarType then
			table.insert(assets, L("Tipo de avatar", tostring(info.playerAvatarType)))
		end
	else
		table.insert(assets, L("Artículos", "No disponible"))
	end
	if p ~= LocalPlayer then
		local okF, isFriend = pcall(function()
			return LocalPlayer:IsFriendsWith(p.UserId)
		end)
		table.insert(social, L("Amigo tuyo", okF and (isFriend and "Sí" or "No") or "No disponible"))
	end
	local okC, count, finished = pcall(function()
		local pages = Players:GetFriendsAsync(p.UserId)
		local n = 0
		for _ = 1, 5 do
			n = n + #pages:GetCurrentPage()
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		return n, pages.IsFinished
	end)
	table.insert(social, L("Amigos", okC and (count .. (finished and "" or "+")) or "No disponible"))
	local okG, groups = pcall(function()
		return GroupService:GetGroupsAsync(p.UserId)
	end)
	if okG and groups then
		table.insert(social, L("Grupos", #groups))
		for i, g in ipairs(groups) do
			if i > 8 then
				table.insert(social, L("...", "y " .. (#groups - 8) .. " más"))
				break
			end
			table.insert(social, L(tostring(g.Name), tostring(g.Role) .. " (rango " .. tostring(g.Rank) .. ")"))
		end
	else
		table.insert(social, L("Grupos", "No disponible"))
	end
	return { assets = assets, social = social }
end

function Scanners.identity(t)
	local p = t.instance
	if not p or p.Parent ~= Players then
		return nil, "El jugador ya no está conectado"
	end
	local root = charRoot(p)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local gear = Scanners.equipment(p)
	local sections = {}
	local function section(title, items)
		if #items > 0 then
			table.insert(sections, { title = title, items = items })
		end
	end
	local function f2(v)
		return v and string.format("%.2f", v) or "N/D"
	end

	local okV, verified = pcall(function()
		return p.HasVerifiedBadge
	end)
	section("IDENTIDAD", {
		L("Nombre", p.Name),
		L("Display", p.DisplayName),
		L("User ID", p.UserId),
		L("Conexión", "Conectado a este servidor"),
		L("Distancia", root and fmtDist(distTo(root.Position)) or "No disponible"),
		L("Equipo", p.Team and p.Team.Name or "No disponible"),
	})
	section("CUENTA", {
		L("Edad", p.AccountAge .. " días"),
		L("Creada (aprox.)", os.date("!%Y-%m-%d", os.time() - p.AccountAge * 86400)),
		L("Membresía", p.MembershipType.Name),
		L("Verificada", okV and (verified and "Sí" or "No") or "No disponible"),
	})
	local sc = gear.scale or {}
	section("ROPA Y TAMAÑO", {
		L("Camisa", gear.shirt or "Ninguna"),
		L("Pantalón", gear.pants or "Ninguno"),
		L("Camiseta gráfica", gear.graphic or "Ninguna"),
		L("Piel", gear.skin or "N/D"),
		L("Altura", gear.height and string.format("%.2f studs", gear.height) or "N/D"),
		L("Escala alto", f2(sc.height)),
		L("ancho", f2(sc.width)),
		L("profundidad", f2(sc.depth)),
		L("cabeza", f2(sc.head)),
		L("Rig", gear.rig or "N/D"),
	})
	local equipo = {
		L("En mano", #gear.tools > 0 and table.concat(gear.tools, ", ") or "Nada equipado"),
		L("Mochila", gear.backpack and (#gear.backpack > 0 and table.concat(gear.backpack, ", ") or "Vacía") or "No visible (el juego no la replica)"),
		L("Accesorios", gear.accCount),
	}
	if gear.accCount > 0 then
		table.insert(equipo, L("Puestos", table.concat(gear.accLines, ", ")))
	end
	if #gear.guiTools > 0 then
		table.insert(equipo, L("Herramientas en PlayerGui", table.concat(gear.guiTools, ", ")))
	end
	section("EQUIPO E INVENTARIO", equipo)
	if hum and root then
		section("ESTADO", {
			L("Salud", string.format("%.0f / %.0f", hum.Health, hum.MaxHealth)),
			L("Humanoid", hum:GetState().Name),
			L("Velocidad", string.format("%.1f studs/s (config. %s)", root.AssemblyLinearVelocity.Magnitude, tostring(hum.WalkSpeed))),
			L("Sentado en", gear.seat or "No"),
			L("Posición", Util.vec(root.Position)),
		})
	end
	local datos = {}
	for _, fd in ipairs(gear.folders) do
		table.insert(datos, L(fd.name, fd.count == 0 and "vacío" or table.concat(fd.items, ", ")))
	end
	section("DATOS DEL JUEGO", datos)

	local web = Scanners.web(p)
	section("AVATAR (ARTÍCULOS OFICIALES)", web.assets)
	section("SOCIAL", web.social)

	local lines = {}
	for _, sec in ipairs(sections) do
		table.insert(lines, L("", "── " .. sec.title .. " ──"))
		for _, l in ipairs(sec.items) do
			table.insert(lines, l)
		end
	end
	return { lines = lines, sections = sections, userId = p.UserId, simulated = false }
end

function Scanners.life(t)
	local p = t.instance
	local char = p and p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return nil, "Sin Humanoid disponible en el objetivo"
	end
	local frac = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
	local color = frac > 0.6 and C.Ok or (frac > 0.3 and C.Warn or C.Danger)
	local jump = hum.UseJumpPower and ("JumpPower " .. hum.JumpPower) or ("JumpHeight " .. hum.JumpHeight)
	local lines = {
		L("Salud", string.format("%.0f / %.0f (%d%%)", hum.Health, hum.MaxHealth, math.floor(frac * 100 + 0.5))),
		L("Estado Humanoid", hum:GetState().Name),
		L("Velocidad configurada", hum.WalkSpeed),
		L("Velocidad real", string.format("%.1f studs/s", root.AssemblyLinearVelocity.Magnitude)),
		L("Salto", jump),
		L("Altura aproximada", string.format("%.2f studs", char:GetExtentsSize().Y)),
		L("Posición", Util.vec(root.Position)),
		L("Movimiento", root.AssemblyLinearVelocity.Magnitude > 1 and "En movimiento" or "Quieto"),
		L("En el aire", hum.FloorMaterial == Enum.Material.Air and "Sí" or "No"),
		L("Personaje activo", hum.Health > 0 and "Sí" or "No (sin vida)"),
		L("Pulso", math.floor(62 + (1 - frac) * 70) .. " bpm", true),
	}
	return { lines = lines, simulated = true, bar = frac, color = color }
end

local SPECIES = {
	{ "Gromflomita", "Humanoide" },
	{ "Zigerion", "Humanoide" },
	{ "Squanchiano", "Híbrido" },
	{ "Cromulón", "Cósmico" },
	{ "Plumbiano", "Híbrido" },
	{ "Gazorpiano", "Humanoide" },
	{ "Meeseeksoide", "Cósmico" },
	{ "Glorzo", "Híbrido" },
}

function Scanners.species(t)
	local p = t.instance
	local char = p and p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil, "Información insuficiente: NO IDENTIFICADA"
	end
	local lines = {
		L("Rig detectado", hum.RigType.Name),
		L("Clasificación local", "Humanoide (por tipo de rig)"),
	}
	if p.UserId <= 0 then
		table.insert(lines, L("Especie ficticia", "DESCONOCIDA (cuenta sin ID válido)", true))
	else
		local sp = SPECIES[(p.UserId % #SPECIES) + 1]
		table.insert(lines, L("Especie ficticia", sp[1], true))
		table.insert(lines, L("Categoría", sp[2], true))
	end
	table.insert(lines, L("Registro local", #SPECIES .. " especies ficticias"))
	table.insert(lines, L("Aviso", "La especie se asigna por User ID. Es un juego, no un dato real."))
	return { lines = lines, simulated = true }
end

local markers = {}

function Scanners.clearMarkers()
	for _, m in ipairs(markers) do
		m:Destroy()
	end
	table.clear(markers)
end

function Scanners.setMarker(info, parentGui)
	Scanners.clearMarkers()
	local root = charRoot(info.player)
	if not root then
		return
	end
	local bb = Util.new("BillboardGui", {
		Name = "C137Marker",
		Adornee = root,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(130, 32),
		StudsOffset = Vector3.new(0, 3.4, 0),
		Parent = parentGui,
	}, {
		Util.new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Bg,
			BackgroundTransparency = 0.3,
			Text = info.text,
			TextColor3 = info.color,
			Font = Enum.Font.GothamBold,
			TextStrokeTransparency = 0.55,
			TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
			TextSize = 13,
		}, { Util.corner(8), Util.stroke(info.color, 1.5) }),
	})
	table.insert(markers, bb)
	task.delay(8, function()
		if bb.Parent then
			bb:Destroy()
		end
	end)
end

local THREAT_LEVELS = {
	{ "NULA", C.Ok },
	{ "BAJA", C.Cyan },
	{ "MODERADA", C.Warn },
	{ "ALTA", Color3.fromRGB(255, 120, 40) },
	{ "CRÍTICA", C.Danger },
}

function Scanners.threat(t)
	local p = t.instance
	local char = p and p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		return nil, "Sin personaje disponible para evaluar"
	end
	local d = distTo(root.Position) or 0
	local score = 0
	if d < 15 then
		score = score + 2
	elseif d < 40 then
		score = score + 1
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then
		score = score + 1
	end
	if hum.Health > 0 and hum.WalkSpeed > 24 then
		score = score + 1
	end
	if p == LocalPlayer or hum.Health <= 0 then
		score = 0
	end
	local level = THREAT_LEVELS[math.clamp(score, 0, 4) + 1]
	local lines = {
		L("Nivel de amenaza", level[1], true),
		L("Distancia", fmtDist(d)),
		L("Herramienta equipada", tool and tool.Name or "Ninguna"),
		L("Velocidad configurada", hum.WalkSpeed),
		L("Salud", string.format("%.0f / %.0f", hum.Health, hum.MaxHealth)),
		L("Método", "Heurística local: distancia + herramienta + velocidad"),
		L("Aviso", "Clasificación visual ficticia. No es una evaluación real."),
	}
	return {
		lines = lines,
		simulated = true,
		bar = (score + 1) / 5,
		color = level[2],
		marker = { player = p, text = "AMENAZA: " .. level[1], color = level[2] },
	}
end

local placeNameCache
local function getPlaceName()
	if placeNameCache then
		return placeNameCache
	end
	if game.PlaceId == 0 then
		return "No disponible (lugar sin publicar)"
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId)
	end)
	if ok and info and info.Name then
		placeNameCache = info.Name
		return placeNameCache
	end
	return "No disponible"
end

local function cardinal(deg)
	local names = { "N", "NE", "E", "SE", "S", "SO", "O", "NO" }
	return names[(math.floor((deg + 22.5) / 45) % 8) + 1]
end

function Scanners.environment(t)
	local root = myRoot()
	if not root then
		return nil, "Tu personaje no está disponible"
	end
	local cam = Workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local heading = math.deg(math.atan2(look.X, -look.Z)) % 360

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character }

	local lines = {
		L("Lugar", getPlaceName()),
		L("Coordenadas locales", Util.vec(root.Position)),
		L("Altitud (Y)", string.format("%.1f studs", root.Position.Y)),
		L("Dist. al origen (0,0,0)", fmtDist(root.Position.Magnitude)),
		L("Brújula", string.format("%d° %s", math.floor(heading + 0.5), cardinal(heading))),
		L("Gravedad", string.format("%.1f", Workspace.Gravity)),
	}

	local down = Workspace:Raycast(root.Position, Vector3.new(0, -30, 0), params)
	if down then
		local inst = down.Instance
		table.insert(lines, L("Superficie inferior", inst:IsA("Terrain") and "Terreno" or inst.Name))
		table.insert(lines, L("Material del suelo", down.Material.Name))
		if not inst:IsA("Terrain") then
			table.insert(lines, L("Color del suelo", Util.hex(inst.Color)))
		end
		table.insert(lines, L("Altura sobre el suelo", string.format("%.1f studs", down.Distance)))
	else
		table.insert(lines, L("Superficie inferior", "Ninguna en 30 studs"))
	end

	local fwd = Workspace:Raycast(root.Position, Vector3.new(look.X, 0, look.Z).Unit * 40, params)
	if fwd then
		table.insert(lines, L("Superficie al frente", (fwd.Instance:IsA("Terrain") and "Terreno" or fwd.Instance.Name) .. " a " .. fmtDist(fwd.Distance)))
		table.insert(lines, L("Material al frente", fwd.Material.Name))
	else
		table.insert(lines, L("Superficie al frente", "Ninguna en 40 studs"))
	end

	local clock = Lighting.ClockTime
	table.insert(lines, L("Hora del entorno", string.format("%.1f (%s)", clock, (clock >= 6 and clock < 18) and "día" or "noche")))
	table.insert(lines, L("Brillo de iluminación", string.format("%.2f", Lighting.Brightness)))
	table.insert(lines, L("Sombras globales", Lighting.GlobalShadows and "Activadas" or "Desactivadas"))
	table.insert(lines, L("Niebla (FogEnd)", string.format("%.0f", Lighting.FogEnd)))

	if t and t.instance then
		local pos
		if t.kind == "player" then
			local r = charRoot(t.instance)
			pos = r and r.Position
		elseif t.instance.Parent then
			pos = t.instance:IsA("Model") and t.instance:GetPivot().Position or t.instance.Position
		end
		if pos then
			table.insert(lines, L("Distancia al objetivo", fmtDist((root.Position - pos).Magnitude)))
		end
	end
	return { lines = lines, simulated = false }
end

function Scanners.object(t)
	local inst = t.instance
	if not inst or not inst.Parent then
		return nil, "El objeto ya no existe"
	end
	local isModel = inst:IsA("Model")
	local hum = isModel and inst:FindFirstChildOfClass("Humanoid") or nil
	local pos = isModel and inst:GetPivot().Position or inst.Position
	local primary = inst
	if isModel then
		primary = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	local size = isModel and inst:GetExtentsSize() or inst.Size

	local partCount, maxSpeed, seats, lights, emitters, clicks = 0, 0, 0, 0, 0, 0
	local prompts, sounds = {}, {}
	local function visit(d)
		if d:IsA("BasePart") then
			partCount = partCount + 1
			if not d.Anchored then
				local sp = d.AssemblyLinearVelocity.Magnitude
				if sp > maxSpeed then
					maxSpeed = sp
				end
			end
		elseif d:IsA("ProximityPrompt") then
			table.insert(prompts, (d.ActionText ~= "" and d.ActionText or "Interactuar") .. (d.ObjectText ~= "" and (" / " .. d.ObjectText) or ""))
		elseif d:IsA("ClickDetector") then
			clicks = clicks + 1
		elseif d:IsA("Sound") then
			table.insert(sounds, d.Name .. (d.IsPlaying and " (sonando)" or ""))
		elseif d:IsA("Light") then
			lights = lights + 1
		elseif d:IsA("ParticleEmitter") then
			emitters = emitters + 1
		elseif d:IsA("Seat") or d:IsA("VehicleSeat") then
			seats = seats + 1
		end
	end
	visit(inst)
	for i, d in ipairs(inst:GetDescendants()) do
		if i > 600 then
			break
		end
		visit(d)
	end

	local sections = {}
	local function section(title, items)
		if #items > 0 then
			table.insert(sections, { title = title, items = items })
		end
	end
	local kindTxt = hum and "NPC (Humanoid)" or (isModel and ("Modelo (" .. partCount .. " partes)") or ("Parte (" .. inst.ClassName .. ")"))
	section("IDENTIDAD", {
		L("Nombre", inst.Name),
		L("Clase", inst.ClassName),
		L("Tipo", kindTxt),
		L("Distancia", fmtDist(distTo(pos))),
		L("Posición", Util.vec(pos)),
		L("Ruta", inst:GetFullName()),
	})

	local mov = {
		L("Velocidad máx.", string.format("%.1f studs/s", maxSpeed)),
		L("Se mueve", maxSpeed > 0.5 and "Sí" or "No"),
	}
	if primary and primary:IsA("BasePart") then
		local v = primary.AssemblyLinearVelocity
		if v.Magnitude > 0.5 then
			table.insert(mov, L("Dirección", Util.vec(v.Unit)))
		end
		table.insert(mov, L("Giro", string.format("%.1f rad/s", primary.AssemblyAngularVelocity.Magnitude)))
		table.insert(mov, L("Anclado", primary.Anchored and "Sí" or "No"))
		table.insert(mov, L("Masa", string.format("%.1f", primary.AssemblyMass)))
	end
	section("MOVIMIENTO", mov)

	if hum then
		local jump = hum.UseJumpPower and ("JumpPower " .. hum.JumpPower) or ("JumpHeight " .. hum.JumpHeight)
		section("ESTADO", {
			L("Salud", string.format("%.0f / %.0f", hum.Health, hum.MaxHealth)),
			L("Humanoid", hum:GetState().Name),
			L("Velocidad config.", hum.WalkSpeed),
			L("Salto", jump),
			L("En el aire", hum.FloorMaterial == Enum.Material.Air and "Sí" or "No"),
			L("Activo", hum.Health > 0 and "Sí" or "No (sin vida)"),
		})
		local gear = Scanners.equipment(nil, inst)
		local sc = gear.scale or {}
		local function f2(v)
			return v and string.format("%.2f", v) or "N/D"
		end
		section("ROPA Y TAMAÑO", {
			L("Camisa", gear.shirt or "Ninguna"),
			L("Pantalón", gear.pants or "Ninguno"),
			L("Camiseta gráfica", gear.graphic or "Ninguna"),
			L("Piel", gear.skin or "N/D"),
			L("Altura", gear.height and string.format("%.2f studs", gear.height) or "N/D"),
			L("Escala alto", f2(sc.height)),
			L("ancho", f2(sc.width)),
			L("cabeza", f2(sc.head)),
			L("Rig", gear.rig or "N/D"),
		})
		local equipo = {
			L("En mano", #gear.tools > 0 and table.concat(gear.tools, ", ") or "Nada equipado"),
			L("Accesorios", gear.accCount),
		}
		if gear.accCount > 0 then
			table.insert(equipo, L("Puestos", table.concat(gear.accLines, ", ")))
		end
		section("EQUIPO", equipo)
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			local names = {}
			for i, tr in ipairs(animator:GetPlayingAnimationTracks()) do
				if i > 6 then
					break
				end
				table.insert(names, tr.Name)
			end
			section("ANIMACIONES ACTIVAS", { L("Reproduciendo", #names > 0 and table.concat(names, ", ") or "Ninguna") })
		end
	elseif primary and primary:IsA("BasePart") then
		section("FÍSICA Y APARIENCIA", {
			L("Tamaño", Util.vec(size)),
			L("Material", primary.Material.Name),
			L("Color", Util.hex(primary.Color)),
			L("Transparencia", string.format("%.2f", primary.Transparency)),
			L("Colisión", primary.CanCollide and "Sí" or "No"),
			L("Partes", partCount),
		})
	end

	local inter = {}
	local resumen = {}
	if #prompts > 0 then
		table.insert(resumen, #prompts .. " prompt(s)")
	end
	if clicks > 0 then
		table.insert(resumen, clicks .. " click(s)")
	end
	if #sounds > 0 then
		table.insert(resumen, #sounds .. " sonido(s)")
	end
	if seats > 0 then
		table.insert(resumen, seats .. " asiento(s)")
	end
	if lights > 0 then
		table.insert(resumen, lights .. " luz/luces")
	end
	if emitters > 0 then
		table.insert(resumen, emitters .. " partículas")
	end
	table.insert(inter, L("Interacciones", #resumen > 0 and table.concat(resumen, ", ") or "Ninguna detectada"))
	if #prompts > 0 then
		table.insert(inter, L("Prompts", table.concat(prompts, ", ")))
	end
	if #sounds > 0 then
		table.insert(inter, L("Sonidos", table.concat(sounds, ", ")))
	end
	section("INTERACCIÓN", inter)

	local extra = {}
	for k, v in pairs(inst:GetAttributes()) do
		table.insert(extra, L(k, tostring(v)))
	end
	local tags = CollectionService:GetTags(inst)
	if #tags > 0 then
		table.insert(extra, L("Etiquetas", table.concat(tags, ", ")))
	end
	section("ATRIBUTOS Y ETIQUETAS", extra)

	local lines = {}
	for _, sec in ipairs(sections) do
		table.insert(lines, L("", "── " .. sec.title .. " ──"))
		for _, l in ipairs(sec.items) do
			table.insert(lines, l)
		end
	end
	return { lines = lines, sections = sections, simulated = false, isNpc = hum ~= nil, maxSpeed = maxSpeed }
end

------------------------------------------------------------------------
-- INTERFACE
------------------------------------------------------------------------
local Interface = {}
Interface.__index = Interface

local W, H, TOP = 600, 360, 40
local MODE_BY_ID = {}
for _, m in ipairs(Config.Modes) do
	MODE_BY_ID[m.id] = m
end

local function makeButton(parent, text, size, pos, callback)
	local b = Util.new("TextButton", {
		Text = text,
		Size = size,
		Position = pos,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.25,
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = 13,
		TextWrapped = true,
		AutoButtonColor = false,
		Parent = parent,
	}, { Util.corner(8), Util.stroke(C.Cyan, 1, 0.4) })
	local function up()
		b.BackgroundTransparency = 0.25
	end
	b.MouseButton1Down:Connect(function()
		b.BackgroundTransparency = 0
	end)
	b.MouseButton1Up:Connect(up)
	b.MouseLeave:Connect(up)
	if callback then
		b.Activated:Connect(callback)
	end
	return b
end

local function makeLabel(parent, text, size, pos, textSize, color, align)
	return Util.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Size = size,
		Position = pos,
		TextColor3 = color or C.Text,
		Font = Enum.Font.Code,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = textSize or 14,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

function Interface.new(bracelet)
	local self = setmetatable({}, Interface)
	self.maid = Util.newMaid()
	self.fx = Util.newMaid()
	self.bracelet = bracelet
	self.mode = "identity"
	self.page = "MAIN"
	self.visible = false
	self.animating = false
	self.minimized = false
	self.scanning = false
	self.destroyed = false
	self.dragging = false
	self.target = nil
	self.last = nil
	self.targets = {}
	self.rows = {}
	self.rowData = {}
	self.pages = {}
	self.tabBtns = {}
	self.modeBtns = {}
	self.refreshers = {}
	self.toasts = {}
	self.avatarCache = {}
	self.fps = 60
	self.lowPower = false
	self.pos = nil
	self:build()
	return self
end

function Interface:viewport()
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(800, 400)
end

function Interface:build()
	local gui = Util.new("ScreenGui", {
		Name = "C137Scanner",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = PlayerGui,
	})
	self.gui = gui
	self.maid:give(gui)

	-- Botón de encendido
	self.toggle = Util.new("TextButton", {
		Name = "PowerButton",
		Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.38, 0),
		BackgroundColor3 = C.Blue,
		BackgroundTransparency = 0,
		Text = "C-137",
		TextColor3 = C.Cyan,
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = 13,
		AutoButtonColor = false,
		Parent = gui,
	}, { Util.corner(31), Util.stroke(Color3.new(1, 1, 1), 2) })
	self.toggle.Activated:Connect(function()
		self:toggleDevice()
	end)

	-- Notificaciones
	self.toastHost = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(300, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Util.new("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	})

	-- Ventana holográfica
	local win = Util.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = Settings.Opacity,
		ClipsDescendants = true,
		Visible = false,
		Parent = gui,
	}, {
		Util.corner(16),
		Util.stroke(C.Cyan, 2),
		Util.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(30, 120, 175), Color3.fromRGB(8, 48, 88)),
		}),
	})
	self.win = win
	self.scale = Util.new("UIScale", { Parent = win })

	-- Barra superior
	local top = Util.new("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, TOP),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = win,
	})
	makeLabel(top, "C-137 // WRIST SCANNER", UDim2.new(1, -100, 1, 0), UDim2.fromOffset(14, 0), 15, C.Cyan).Font = Enum.Font.GothamBold
	Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BackgroundColor3 = C.Cyan,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = top,
	})
	self.minBtn = makeButton(top, "_", UDim2.fromOffset(38, 30), UDim2.new(1, -86, 0, 5), function()
		self:toggleMinimize()
	end)
	makeButton(top, "X", UDim2.fromOffset(38, 30), UDim2.new(1, -44, 0, 5), function()
		self:close()
	end)

	top.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.dragging = true
			self.dragStart = input.Position
			self.dragOrigin = self.pos
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					self.dragging = false
					conn:Disconnect()
				end
			end)
		end
	end)
	self.maid:give(UserInputService.InputChanged:Connect(function(input)
		if
			self.dragging
			and self.dragOrigin
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			local d = input.Position - self.dragStart
			self.pos = self.dragOrigin + Vector2.new(d.X, d.Y)
			self:clampPos()
		end
	end))

	-- Cuerpo
	local body = Util.new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, TOP),
		Size = UDim2.new(1, 0, 1, -TOP),
		BackgroundTransparency = 1,
		Parent = win,
	})
	self.body = body

	-- Pestañas
	local tabs = { { "MAIN", "PANEL" }, { "TARGET", "OBJETIVO" }, { "RESULT", "RESULTADO" }, { "HISTORY", "HISTORIAL" }, { "CONFIG", "CONFIG" } }
	for i, tab in ipairs(tabs) do
		local b = makeButton(body, tab[2], UDim2.fromOffset(104, 46), UDim2.fromOffset(8, 8 + (i - 1) * 52), function()
			Sound.play("confirm")
			self:setPage(tab[1])
		end)
		self.tabBtns[tab[1]] = b
	end

	-- Contenido
	local content = Util.new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(120, 8),
		Size = UDim2.new(1, -128, 1, -44),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})
	for _, tab in ipairs(tabs) do
		self.pages[tab[1]] = Util.new("Frame", {
			Name = tab[1],
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = content,
		})
	end

	self:buildMainPage(self.pages.MAIN)
	self:buildTargetPage(self.pages.TARGET)
	self:buildResultPage(self.pages.RESULT)
	self:buildHistoryPage(self.pages.HISTORY)
	self:buildConfigPage(self.pages.CONFIG)

	-- Barra de estado
	local status = Util.new("Frame", {
		Position = UDim2.new(0, 8, 1, -30),
		Size = UDim2.new(1, -16, 0, 24),
		BackgroundTransparency = 1,
		Parent = body,
	})
	self.status = makeLabel(status, "STANDBY", UDim2.fromOffset(190, 24), UDim2.fromOffset(0, 0), 12, C.Cyan)
	local track = Util.new("Frame", {
		Position = UDim2.fromOffset(196, 8),
		Size = UDim2.new(1, -250, 0, 8),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Parent = status,
	}, { Util.corner(4), Util.stroke(C.Cyan, 1, 0.5) })
	self.progressFill = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Cyan,
		BorderSizePixel = 0,
		Parent = track,
	}, { Util.corner(4) })
	self.pct = makeLabel(status, "0%", UDim2.fromOffset(46, 24), UDim2.new(1, -46, 0, 0), 12, C.Text, Enum.TextXAlignment.Right)

	-- Capas de efectos
	self.fxLayer = Util.new("Frame", {
		Name = "FxLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 18,
		Active = false,
		Parent = win,
	})
	self.scanline = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = C.Cyan,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 18,
		Parent = self.fxLayer,
	})
	self.particles = {}
	for i = 1, 12 do
		local f = Util.new("Frame", {
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = C.Cyan,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 18,
			Parent = self.fxLayer,
		}, { Util.corner(2) })
		table.insert(self.particles, { f = f, x = math.random(0, W), y = math.random(0, H), s = math.random(12, 40) })
	end
	self.sweep = Util.new("Frame", {
		Size = UDim2.new(0, 40, 1, 0),
		BackgroundColor3 = C.Cyan,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 19,
		Parent = win,
	}, {
		Util.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	self.flash = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Danger,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 25,
		Parent = win,
	})

	-- Viewport
	local cam = Workspace.CurrentCamera
	if cam then
		self.maid:give(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:applyScale()
		end))
	end

	self:buildQuick()
	self:setMode("identity")
	self:setPage("MAIN")
	self:refreshHistory()
	self:applySettings()
end

-- MAIN ---------------------------------------------------------------
function Interface:buildMainPage(page)
	for i, m in ipairs(Config.Modes) do
		local col = (i - 1) % 3
		local row = math.floor((i - 1) / 3)
		self.modeBtns[m.id] = makeButton(page, m.label, UDim2.fromOffset(152, 38), UDim2.fromOffset(col * 160, row * 44), function()
			Sound.play("confirm")
			self:setMode(m.id)
		end)
	end

	makeButton(page, "ESCANEAR", UDim2.fromOffset(152, 42), UDim2.fromOffset(0, 92), function()
		self:startScan(false)
	end).BackgroundColor3 = C.Blue
	makeButton(page, "REPETIR", UDim2.fromOffset(152, 42), UDim2.fromOffset(160, 92), function()
		self:repeatScan()
	end)
	self.autoBtn = makeButton(page, "AUTO: OFF", UDim2.fromOffset(152, 42), UDim2.fromOffset(320, 92), function()
		Settings.Auto = not Settings.Auto
		Sound.play("confirm")
		self:applySettings()
		self:notify(Settings.Auto and "Modo AUTOMÁTICO activado" or "Modo MANUAL activado")
	end)

	self.listTitle = makeLabel(page, "OBJETIVOS CERCANOS", UDim2.fromOffset(320, 22), UDim2.fromOffset(0, 140), 12, C.Dim)
	makeButton(page, "ACTUALIZAR", UDim2.fromOffset(120, 24), UDim2.fromOffset(352, 139), function()
		Sound.play("confirm")
		self:refreshTargets()
	end).TextSize = 11

	self.list = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 168),
		Size = UDim2.new(1, 0, 1, -168),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		Util.corner(8),
		Util.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Util.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	self.emptyLbl = makeLabel(page, "", UDim2.new(1, 0, 0, 100), UDim2.fromOffset(0, 168), 13, C.Dim, Enum.TextXAlignment.Center)
	self.emptyLbl.TextWrapped = true
end

-- TARGET -------------------------------------------------------------
function Interface:buildTargetPage(page)
	self.avatar = Util.new("ImageLabel", {
		Size = UDim2.fromOffset(120, 120),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.4,
		Image = "",
		Parent = page,
	}, { Util.corner(12), Util.stroke(C.Cyan, 1.5) })
	self.avatarNote = makeLabel(self.avatar, "SIN IMAGEN", UDim2.fromScale(1, 1), UDim2.new(), 11, C.Dim, Enum.TextXAlignment.Center)
	self.avatarNote.ZIndex = 0
	self.targetInfo = makeLabel(page, "", UDim2.new(1, -136, 1, 0), UDim2.fromOffset(136, 0), 15, C.Text)
	self.targetInfo.RichText = true
	self.targetInfo.TextWrapped = true
	self.targetInfo.TextYAlignment = Enum.TextYAlignment.Top
end

function Interface:loadAvatar(userId, image, note)
	if self.avatarCache[userId] then
		image.Image = self.avatarCache[userId]
		note.Visible = false
		return
	end
	image.Image = ""
	note.Visible = true
	note.Text = "CARGANDO..."
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if self.destroyed then
			return
		end
		if ok and img then
			self.avatarCache[userId] = img
			if image.Parent then
				image.Image = img
				note.Visible = false
			end
		else
			note.Text = "AVATAR NO DISPONIBLE"
		end
	end)
end

function Interface:updateTargetPage()
	local t = self.target
	if not t then
		self.targetInfo.Text = "Sin objetivo seleccionado.\nElige uno en PANEL."
		self.avatar.Image = ""
		self.avatarNote.Visible = true
		self.avatarNote.Text = "SIN IMAGEN"
		return
	end
	self.targetInfo.Text = Util.renderLines(Scanners.summary(t))
	if t.kind == "player" then
		self:loadAvatar(t.instance.UserId, self.avatar, self.avatarNote)
	else
		self.avatar.Image = ""
		self.avatarNote.Visible = true
		self.avatarNote.Text = "OBJETO"
	end
end

-- RESULT -------------------------------------------------------------
function Interface:buildResultPage(page)
	self.resHeader = makeLabel(page, "SIN RESULTADOS", UDim2.new(1, 0, 0, 24), UDim2.fromOffset(0, 0), 13, C.Dim)
	self.resHeader.Font = Enum.Font.GothamBold
	local barBg = Util.new("Frame", {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Parent = page,
	}, { Util.corner(4) })
	self.resBar = barBg
	self.resBarFill = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.Cyan,
		BorderSizePixel = 0,
		Parent = barBg,
	}, { Util.corner(4) })
	self.resAvatar = Util.new("ImageLabel", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.4,
		Visible = false,
		Parent = page,
	}, { Util.corner(10), Util.stroke(C.Cyan, 1.5) })
	self.resAvatarNote = makeLabel(self.resAvatar, "", UDim2.fromScale(1, 1), UDim2.new(), 9, C.Dim, Enum.TextXAlignment.Center)
	self.resAvatarNote.ZIndex = 0
	self.resScroll = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	})
	self.resRows = Util.new("Frame", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self.resScroll,
	}, { Util.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	self.resText = Util.new("TextLabel", {
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		TextWrapped = true,
		Text = "Realiza un escaneo para ver resultados.",
		TextColor3 = C.Text,
		Font = Enum.Font.Code,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = self.resScroll,
	})
end

-- Cada sección se dibuja como una fila (tarjeta) con su título y sus datos en línea.
function Interface:renderRows(sections)
	for _, c in ipairs(self.resRows:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local keyColor = Util.hex(C.Cyan)
	for i, sec in ipairs(sections) do
		local row = Util.new("Frame", {
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = 0.45,
			LayoutOrder = i,
			Parent = self.resRows,
		}, {
			Util.corner(8),
			Util.stroke(C.Cyan, 1, 0.55),
			Util.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
			Util.new("UIPadding", {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
		local title = makeLabel(row, sec.title, UDim2.new(1, 0, 0, 16), UDim2.new(), 12, C.Cyan)
		title.Font = Enum.Font.GothamBold
		title.LayoutOrder = 0
		local parts = {}
		for _, l in ipairs(sec.items) do
			local tag = l.sim and ' <font color="#ffb000">[SIM]</font>' or ""
			table.insert(parts, string.format('<font color="%s">%s</font> %s%s', keyColor, Util.esc(l.k), Util.esc(l.v), tag))
		end
		local body = makeLabel(row, "", UDim2.new(1, 0, 0, 0), UDim2.new(), 13, C.Text)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.RichText = true
		body.TextWrapped = true
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.LayoutOrder = 1
		body.Text = table.concat(parts, "   ·   ")
	end
end

function Interface:showResult(entry, noSwitch)
	local r = entry.result
	self.resHeader.Text = entry.modeLabel .. "  |  " .. (r.simulated and "CONTIENE DATOS SIMULADOS [SIM]" or "DATOS LOCALES REALES")
	self.resHeader.TextColor3 = r.simulated and C.Warn or C.Cyan
	self.resBar.Visible = r.bar ~= nil
	if r.bar then
		self.resBarFill.BackgroundColor3 = r.color or C.Cyan
		Util.tween(self.resBarFill, 0.4, { Size = UDim2.fromScale(r.bar, 1) })
	end
	self.resText.TextColor3 = C.Text
	if r.sections then
		self.resText.Visible = false
		self.resRows.Visible = true
		self:renderRows(r.sections)
	else
		self.resRows.Visible = false
		self.resText.Visible = true
		self.resText.Text = Util.renderLines(r.lines)
	end
	if r.userId then
		self.resAvatar.Visible = true
		self:loadAvatar(r.userId, self.resAvatar, self.resAvatarNote)
		self.resScroll.Position = UDim2.fromOffset(80, 44)
		self.resScroll.Size = UDim2.new(1, -80, 1, -44)
	else
		self.resAvatar.Visible = false
		self.resScroll.Position = UDim2.fromOffset(0, 44)
		self.resScroll.Size = UDim2.new(1, 0, 1, -44)
	end
	self.resScroll.CanvasPosition = Vector2.new()
	if not noSwitch then
		self:setPage("RESULT")
	end
end

-- HISTORY ------------------------------------------------------------
function Interface:buildHistoryPage(page)
	makeButton(page, "BORRAR (menos FAV)", UDim2.fromOffset(152, 34), UDim2.fromOffset(0, 0), function()
		Sound.play("confirm")
		Database.clearNonFavorites()
		self:refreshHistory()
		self:notify("Historial borrado (se conservan favoritos)")
	end)
	makeButton(page, "EXPORTAR", UDim2.fromOffset(152, 34), UDim2.fromOffset(160, 0), function()
		self:exportHistory()
	end)
	self.histList = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		Util.corner(8),
		Util.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Util.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	self.histEmpty = makeLabel(page, "Aún no hay escaneos.", UDim2.new(1, 0, 0, 60), UDim2.fromOffset(0, 70), 13, C.Dim, Enum.TextXAlignment.Center)
end

function Interface:refreshHistory()
	for _, c in ipairs(self.histList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	self.histEmpty.Visible = #Database.history == 0
	for i, e in ipairs(Database.history) do
		local row = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = self.histList,
		})
		local main = makeButton(row, string.format("%s  %s · %s", e.timeText, e.modeLabel, e.targetName), UDim2.new(1, -92, 1, 0), UDim2.new(), function()
			Sound.play("confirm")
			self:showResult(e)
		end)
		main.TextXAlignment = Enum.TextXAlignment.Left
		main.TextSize = 11
		main.Font = Enum.Font.Code
		local fav = makeButton(row, "FAV", UDim2.fromOffset(40, 36), UDim2.new(1, -88, 0, 0), function()
			Database.toggleFav(e.id)
			self:refreshHistory()
		end)
		fav.TextSize = 11
		fav.TextColor3 = e.fav and C.Warn or C.Dim
		makeButton(row, "X", UDim2.fromOffset(40, 36), UDim2.new(1, -44, 0, 0), function()
			Database.remove(e.id)
			self:refreshHistory()
		end).TextColor3 = C.Danger
	end
end

function Interface:exportHistory()
	local text = Database.exportText()
	print(text)
	self.resHeader.Text = "EXPORTACIÓN LOCAL (SESIÓN ACTUAL)"
	self.resHeader.TextColor3 = C.Cyan
	self.resBar.Visible = false
	self.resAvatar.Visible = false
	self.resScroll.Position = UDim2.fromOffset(0, 44)
	self.resScroll.Size = UDim2.new(1, 0, 1, -44)
	self.resRows.Visible = false
	self.resText.Visible = true
	self.resText.Text = Util.esc(text)
	self.resText.TextColor3 = C.Text
	self:setPage("RESULT")
	self:notify("Exportado a esta pantalla y a la consola (F9)")
end

-- CONFIG -------------------------------------------------------------
function Interface:buildConfigPage(page)
	local scroll = Util.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, { Util.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local function addRow(label)
		local r = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 38),
			BackgroundColor3 = C.Panel,
			BackgroundTransparency = 0.6,
			Parent = scroll,
		}, { Util.corner(8) })
		makeLabel(r, label, UDim2.new(1, -190, 1, 0), UDim2.fromOffset(10, 0), 13, C.Text)
		return r
	end

	local function toggleRow(label, key)
		local r = addRow(label)
		local b
		local function refresh()
			b.Text = Settings[key] and "ON" or "OFF"
			b.TextColor3 = Settings[key] and C.Ok or C.Dim
		end
		b = makeButton(r, "", UDim2.fromOffset(118, 30), UDim2.new(1, -126, 0, 4), function()
			Settings[key] = not Settings[key]
			Sound.play("confirm")
			self:applySettings()
		end)
		table.insert(self.refreshers, refresh)
		refresh()
	end

	local function stepRow(label, key, min, max, step, fmt)
		local r = addRow(label)
		local val = makeLabel(r, "", UDim2.fromOffset(86, 30), UDim2.new(1, -138, 0, 4), 13, C.Cyan, Enum.TextXAlignment.Center)
		local function change(dir)
			local v = math.floor((Settings[key] + step * dir) * 100 + 0.5) / 100
			Settings[key] = math.clamp(v, min, max)
			Sound.play("confirm")
			self:applySettings()
		end
		makeButton(r, "-", UDim2.fromOffset(44, 30), UDim2.new(1, -186, 0, 4), function()
			change(-1)
		end)
		makeButton(r, "+", UDim2.fromOffset(44, 30), UDim2.new(1, -50, 0, 4), function()
			change(1)
		end)
		local function refresh()
			val.Text = fmt(Settings[key])
		end
		table.insert(self.refreshers, refresh)
		refresh()
	end

	toggleRow("Efectos visuales", "Effects")
	toggleRow("Sonido", "Sound")
	toggleRow("Modo compacto", "Compact")
	stepRow("Volumen", "Volume", 0, 1, 0.1, function(v)
		return math.floor(v * 100 + 0.5) .. "%"
	end)
	stepRow("Tamaño de interfaz", "UiScale", 0.6, 1.4, 0.1, function(v)
		return string.format("x%.1f", v)
	end)
	stepRow("Opacidad (transp. fondo)", "Opacity", 0, 0.6, 0.05, function(v)
		return string.format("%.2f", v)
	end)
	stepRow("Intervalo modo AUTO", "AutoInterval", 1, 15, 1, function(v)
		return v .. " s"
	end)
	stepRow("Rango de escaneo", "Range", 20, 300, 20, function(v)
		return v .. " studs"
	end)

	local function bigButton(text, cb)
		makeButton(scroll, text, UDim2.new(1, -8, 0, 36), UDim2.new(), cb)
	end
	bigButton("DIAGNÓSTICO DE MÓDULOS", function()
		Sound.play("confirm")
		self:runDiagnostics()
	end)
	bigButton("REINICIAR MÓDULOS", function()
		self:resetModules()
	end)
	bigButton("RESTABLECER CONFIGURACIÓN", function()
		resetSettings()
		self:applySettings()
		self:notify("Configuración restablecida")
	end)
end

-- Estado / ajustes ---------------------------------------------------
function Interface:applySettings()
	Sound.Enabled = Settings.Sound
	Sound.Volume = Settings.Volume
	self.win.BackgroundTransparency = Settings.Opacity
	self.fxLayer.Visible = Settings.Effects and not self.lowPower
	self.autoBtn.Text = Settings.Auto and "AUTO: ON" or "AUTO: OFF"
	self.autoBtn.TextColor3 = Settings.Auto and C.Ok or C.Text
	self:applyScale()
	for _, f in ipairs(self.refreshers) do
		f()
	end
end

function Interface:applyScale()
	local vp = self:viewport()
	local s = math.clamp(math.min(vp.X / (W + 40), vp.Y / (H + 30)), 0.5, 1.4) * Settings.UiScale
	if Settings.Compact then
		s = s * 0.82
	end
	self.scale.Scale = s
	self:applyQuickScale()
	self:clampPos()
end

function Interface:clampPos()
	local vp = self:viewport()
	local s = self.scale.Scale
	local halfW = W * s / 2
	local hgt = (self.minimized and TOP or H) * s
	local p = self.pos or Vector2.new(vp.X / 2, math.max(0, (vp.Y - H * s) / 2))
	p = Vector2.new(
		math.clamp(p.X, halfW, math.max(halfW, vp.X - halfW)),
		math.clamp(p.Y, 0, math.max(0, vp.Y - hgt))
	)
	self.pos = p
	if self.visible and not self.animating then
		self.win.Position = UDim2.fromOffset(p.X, p.Y)
	end
end

function Interface:setProgress(a)
	self.progressFill.Size = UDim2.fromScale(a, 1)
	self.pct.Text = math.floor(a * 100 + 0.5) .. "%"
	self.sweep.Position = UDim2.new(0, a * W - 20, 0, 0)
end

function Interface:setPage(name)
	self.page = name
	for n, p in pairs(self.pages) do
		local on = n == name
		p.Visible = on
		if on then
			if Settings.Effects then
				p.Position = UDim2.fromOffset(14, 0)
				Util.tween(p, 0.2, { Position = UDim2.fromOffset(0, 0) })
			else
				p.Position = UDim2.fromOffset(0, 0)
			end
		end
	end
	for n, b in pairs(self.tabBtns) do
		b.BackgroundColor3 = n == name and C.Blue or C.Panel
	end
	if name == "MAIN" then
		self:refreshTargets()
	elseif name == "TARGET" then
		self:updateTargetPage()
	end
end

function Interface:setMode(id)
	self.mode = id
	for mid, b in pairs(self.modeBtns) do
		b.BackgroundColor3 = mid == id and C.Blue or C.Panel
	end
	if self.target and ((id == "object") ~= (self.target.kind == "object")) then
		self.target = nil
	end
	if id == "object" then
		self.listTitle.Text = "OBJETOS CERCANOS"
	elseif id == "environment" then
		self.listTitle.Text = "ENVIRONMENT: no requiere objetivo"
	else
		self.listTitle.Text = "JUGADORES CERCANOS"
	end
	self:refreshTargets()
end

function Interface:setStatus(text, color)
	self.status.Text = text
	self.status.TextColor3 = color or C.Cyan
end

-- Objetivos ----------------------------------------------------------
function Interface:refreshTargets()
	local list
	if self.mode == "object" then
		list = Scanners.nearbyObjects(Settings.Range)
	elseif self.mode == "environment" then
		list = {}
	else
		list = Scanners.nearbyPlayers(Settings.Range)
	end
	self.targets = list
	local keep = {}
	for i, t in ipairs(list) do
		keep[t.instance] = true
		self.rowData[t.instance] = t
		local row = self.rows[t.instance]
		if not row then
			local inst = t.instance
			row = Util.new("TextButton", {
				Size = UDim2.new(1, -8, 0, 32),
				BackgroundColor3 = C.Panel,
				BackgroundTransparency = 0.2,
				TextColor3 = C.Text,
				Font = Enum.Font.Code,
				TextStrokeTransparency = 0.55,
				TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				Parent = self.list,
			}, { Util.corner(6), Util.new("UIPadding", { PaddingLeft = UDim.new(0, 8) }) })
			row.Activated:Connect(function()
				Sound.play("confirm")
				self:selectTarget(self.rowData[inst])
			end)
			self.rows[t.instance] = row
		end
		row.LayoutOrder = i
		row.Text = string.format("%s  ·  %.0f studs", t.name, t.distance)
		row.BackgroundColor3 = (self.target and self.target.instance == t.instance) and C.Blue or C.Panel
	end
	for inst, row in pairs(self.rows) do
		if not keep[inst] then
			row:Destroy()
			self.rows[inst] = nil
			self.rowData[inst] = nil
		end
	end
	if #list == 0 then
		self.emptyLbl.Text = self.mode == "environment" and "El Environment Scan analiza tu entorno.\nPulsa ESCANEAR." or "Sin objetivos en rango."
	end
	self.emptyLbl.Visible = #list == 0
end

function Interface:selectTarget(t)
	if not t then
		return
	end
	self.target = t
	for inst, row in pairs(self.rows) do
		row.BackgroundColor3 = inst == t.instance and C.Blue or C.Panel
	end
	self:notify("Objetivo: " .. t.name)
	if self.page == "TARGET" then
		self:updateTargetPage()
	end
end

-- Escaneo ------------------------------------------------------------
function Interface:startScan(silent)
	if self.scanning then
		return
	end
	local mode = self.mode
	local def = MODE_BY_ID[mode]
	local target = self.target
	if mode ~= "environment" and not target then
		self:showError("Sin objetivo seleccionado", silent)
		return
	end
	self.scanning = true
	self.last = { mode = mode, target = target }
	self:setStatus("ESCANEANDO · " .. def.label)
	if not silent then
		Sound.play("scan")
	end
	self.sweep.Visible = Settings.Effects
	task.spawn(function()
		local duration = Settings.Effects and 1.2 or 0.35
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			self:setProgress(a)
			if a >= 1 or self.destroyed or not self.visible then
				break
			end
			RunService.Heartbeat:Wait()
		end
		self.sweep.Visible = false
		if self.destroyed then
			return
		end
		local ok, res, err = pcall(Scanners[mode], target)
		self.scanning = false
		if not self.visible then
			return
		end
		if not ok then
			Database.logError(res)
			self:showError("Fallo interno del módulo: " .. tostring(res), silent)
		elseif not res then
			self:showError(err or "Sin información disponible", silent)
		else
			local entry = Database.add({
				mode = mode,
				modeLabel = def.label,
				targetName = target and target.name or "Entorno local",
				result = res,
			})
			self.last.entry = entry
			self:showResult(entry, silent)
			self:refreshHistory()
			self:setStatus("COMPLETADO · " .. def.label, C.Ok)
			if res.marker then
				Scanners.setMarker(res.marker, self.gui)
			end
			if not silent then
				Sound.play(mode == "identity" and "identify" or "confirm")
				self:notify(def.label .. " completado" .. (res.simulated and " (con datos simulados)" or ""))
			end
		end
	end)
end

function Interface:repeatScan()
	if not self.last then
		self:notify("No hay nada que repetir", "warn")
		return
	end
	Sound.play("confirm")
	self:setMode(self.last.mode)
	self.target = self.last.target
	self:startScan(false)
end

function Interface:showError(msg, silent)
	self.scanning = false
	Database.logError(msg)
	self:setStatus("ERROR", C.Danger)
	self:setProgress(0)
	self.resHeader.Text = "SIN DATOS"
	self.resHeader.TextColor3 = C.Danger
	self.resBar.Visible = false
	self.resAvatar.Visible = false
	self.resScroll.Position = UDim2.fromOffset(0, 44)
	self.resScroll.Size = UDim2.new(1, 0, 1, -44)
	self.resRows.Visible = false
	self.resText.Visible = true
	self.resText.Text = Util.esc("ERROR: " .. msg)
	self.resText.TextColor3 = C.Danger
	if Settings.Effects then
		self.flash.BackgroundTransparency = 0.75
		Util.tween(self.flash, 0.5, { BackgroundTransparency = 1 })
		self:glitch()
	end
	if not silent then
		Sound.play("error")
		self:notify(msg, "error")
	end
end

-- Diagnóstico --------------------------------------------------------
function Interface:runDiagnostics()
	self:setStatus("DIAGNÓSTICO...")
	task.spawn(function()
		local lines = {}
		local function add(k, v)
			table.insert(lines, L(k, v))
		end
		add("Módulos", "Config, Util, Sound, Database, Bracelet, Scanners, Interface: cargados")
		local selfT = { kind = "player", instance = LocalPlayer, name = LocalPlayer.Name }
		for _, id in ipairs({ "identity", "life", "species", "threat", "environment" }) do
			local ok, res, err = pcall(Scanners[id], selfT)
			add("Prueba " .. id, ok and (res and "OK" or ("SIN DATOS: " .. tostring(err))) or ("ERROR: " .. tostring(res)))
		end
		local objs = Scanners.nearbyObjects(Settings.Range)
		if #objs > 0 then
			local ok, res, err = pcall(Scanners.object, objs[1])
			add("Prueba object", ok and (res and "OK" or ("SIN DATOS: " .. tostring(err))) or ("ERROR: " .. tostring(res)))
		else
			add("Prueba object", "OMITIDA (sin objetos en rango)")
		end
		local n, total = Sound.configuredCount()
		add("Sonidos configurados", n .. " / " .. total .. (n == 0 and " (pega IDs en Config.Sounds)" or ""))
		add("Brazalete en el personaje", self.bracelet:isAttached() and "Sí" or "No")
		add("FPS (promedio)", string.format("%.0f", self.fps))
		add("Modo ahorro", self.lowPower and "ACTIVO" or "inactivo")
		add("Memoria del cliente", string.format("%.0f MB", Stats:GetTotalMemoryUsageMb()))
		add("Efectos", Settings.Effects and "ON" or "OFF")
		add("Objetivos listados", #self.targets)
		add("Historial", #Database.history .. " registros")
		add("Errores registrados", #Database.errors)
		for i = 1, math.min(3, #Database.errors) do
			add("  error " .. i, Database.errors[i].t .. " " .. Database.errors[i].msg)
		end
		local remotes = 0
		for _, d in ipairs(script.Parent:GetDescendants()) do
			if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
				remotes = remotes + 1
			end
		end
		add("Remotes en el contenedor del script", remotes)
		if self.destroyed then
			return
		end
		self:showResult({ modeLabel = "DIAGNOSTIC", result = { lines = lines, simulated = false } })
		self:setStatus("DIAGNÓSTICO LISTO", C.Ok)
	end)
end

function Interface:resetModules()
	Scanners.clearMarkers()
	self.target = nil
	self.last = nil
	self.scanning = false
	self.lowPower = false
	self.sweep.Visible = false
	self:setProgress(0)
	self:setStatus("MÓDULOS REINICIADOS")
	self:applySettings()
	self:refreshTargets()
	self:updateTargetPage()
	if LocalPlayer.Character then
		task.spawn(function()
			self.bracelet:build(LocalPlayer.Character)
		end)
	end
	Sound.play("confirm")
	self:notify("Módulos reiniciados")
end

-- Notificaciones -----------------------------------------------------
function Interface:notify(text, kind)
	if self.destroyed then
		return
	end
	local color = kind == "error" and C.Danger or (kind == "warn" and C.Warn or C.Cyan)
	if kind ~= "error" then
		Sound.play("notify")
	end
	local toast = Util.new("TextLabel", {
		Size = UDim2.fromOffset(300, 30),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.Code,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = 13,
		LayoutOrder = os.clock() * 100,
		Parent = self.toastHost,
	}, { Util.corner(8), Util.stroke(color, 1) })
	Util.tween(toast, 0.2, { BackgroundTransparency = 0.2, TextTransparency = 0 })
	table.insert(self.toasts, toast)
	while #self.toasts > 3 do
		local first = table.remove(self.toasts, 1)
		first:Destroy()
	end
	task.delay(2.6, function()
		if toast.Parent then
			Util.tween(toast, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
			task.delay(0.3, function()
				toast:Destroy()
			end)
		end
	end)
end

-- Efectos ------------------------------------------------------------
function Interface:glitch()
	if not Settings.Effects or not self.visible or self.dragging then
		return
	end
	local token = (self.glitchToken or 0) + 1
	self.glitchToken = token
	task.spawn(function()
		for _ = 1, 6 do
			if self.glitchToken ~= token or not self.visible or self.animating then
				break
			end
			self.win.Position = UDim2.fromOffset(self.pos.X + math.random(-6, 6), self.pos.Y + math.random(-3, 3))
			self.win.BackgroundTransparency = math.random() < 0.5 and 0.4 or Settings.Opacity
			task.wait(0.04)
		end
		if self.visible and not self.animating and not self.destroyed then
			self.win.Position = UDim2.fromOffset(self.pos.X, self.pos.Y)
			self.win.BackgroundTransparency = Settings.Opacity
		end
	end)
end

function Interface:startFx()
	self.fx:clean()
	local refreshAcc, autoAcc, lowAcc = 0, 0, 0
	self.fx:give(RunService.Heartbeat:Connect(function(dt)
		self.fps = self.fps * 0.92 + (1 / math.max(dt, 0.001)) * 0.08
		local fxOn = Settings.Effects and not self.lowPower and not self.minimized

		if fxOn then
			local t = os.clock()
			self.scanline.Position = UDim2.fromOffset(0, (t * 90) % H)
			for _, p in ipairs(self.particles) do
				p.y = p.y - p.s * dt
				if p.y < -4 then
					p.y = H
					p.x = math.random(0, W)
				end
				p.f.Position = UDim2.fromOffset(p.x, p.y)
			end
			if math.random() < dt * 0.12 then
				self:glitch()
			end
		end

		lowAcc = lowAcc + dt
		if lowAcc >= 2 then
			lowAcc = 0
			if self.fps < 26 and not self.lowPower then
				self.lowPower = true
				self:applySettings()
				self:notify("Ahorro de recursos activado (FPS bajos)", "warn")
			elseif self.fps > 45 and self.lowPower then
				self.lowPower = false
				self:applySettings()
			end
		end

		refreshAcc = refreshAcc + dt
		if refreshAcc >= 2 then
			refreshAcc = 0
			if self.page == "MAIN" and not self.scanning and not self.minimized then
				self:refreshTargets()
			end
		end

		if Settings.Auto then
			autoAcc = autoAcc + dt
			if autoAcc >= Settings.AutoInterval then
				autoAcc = 0
				self:autoTick()
			end
		else
			autoAcc = 0
		end
	end))
end

function Interface:autoTick()
	if self.scanning or self.animating then
		return
	end
	self:refreshTargets()
	if self.mode ~= "environment" then
		local stillThere = false
		if self.target then
			for _, t in ipairs(self.targets) do
				if t.instance == self.target.instance then
					stillThere = true
					break
				end
			end
		end
		if not stillThere then
			self.target = self.targets[1]
		end
		if not self.target then
			return
		end
	end
	self:startScan(true)
end

-- Escaneo rápido (tecla E / botón E) ---------------------------------
local function findLine(res, key)
	if not res then
		return nil
	end
	for _, l in ipairs(res.lines) do
		if l.k == key then
			return l.v
		end
	end
end

function Interface:buildQuick()
	local gui = self.gui
	local q = { base = 1, idx = 0 }
	self.q = q
	local function round()
		return Util.new("UICorner", { CornerRadius = UDim.new(0.5, 0) })
	end

	-- Botón E (siempre visible, también sirve la tecla E en PC)
	q.button = Util.new("TextButton", {
		Name = "QuickScanButton",
		Size = UDim2.fromOffset(66, 66),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -18, 0.42, 0),
		BackgroundColor3 = C.Blue,
		Text = "E",
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.55,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		TextSize = 30,
		AutoButtonColor = false,
		ZIndex = 40,
		Parent = gui,
	}, { round(), Util.stroke(Color3.new(1, 1, 1), 2) })
	Util.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, 2),
		Text = "ESCANEAR",
		TextColor3 = C.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextStrokeTransparency = 0.3,
		TextStrokeColor3 = Color3.fromRGB(0, 20, 45),
		ZIndex = 40,
		Parent = q.button,
	})
	q.button.Activated:Connect(function()
		self:quickScan()
	end)
	self.maid:give(UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.Keybind then
			self:quickScan()
		end
	end))

	-- Panel de escaneo rápido
	q.panel = Util.new("Frame", {
		Name = "QuickPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 322),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	}, {
		Util.corner(16),
		Util.stroke(C.Cyan, 2),
		Util.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(30, 120, 175), Color3.fromRGB(8, 48, 88)),
		}),
	})
	q.stroke = q.panel:FindFirstChildOfClass("UIStroke")
	q.scale = Util.new("UIScale", { Parent = q.panel })

	q.title = makeLabel(q.panel, "C-137 // ESCANEO RÁPIDO", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(14, 4), 14, C.Cyan)
	q.title.Font = Enum.Font.GothamBold

	-- Datos del objetivo
	q.avatar = Util.new("ImageLabel", {
		Position = UDim2.fromOffset(16, 44),
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.4,
		Image = "",
		Parent = q.panel,
	}, { Util.corner(10), Util.stroke(C.Cyan, 1.5) })
	q.avatarNote = makeLabel(q.avatar, "", UDim2.fromScale(1, 1), UDim2.new(), 9, C.Dim, Enum.TextXAlignment.Center)
	q.avatarNote.ZIndex = 0
	q.name = makeLabel(q.panel, "", UDim2.fromOffset(264, 56), UDim2.fromOffset(80, 44), 15, C.Text)
	q.name.Font = Enum.Font.GothamBold
	q.name.TextWrapped = true
	q.lines = makeLabel(q.panel, "", UDim2.fromOffset(328, 172), UDim2.fromOffset(16, 106), 13, C.Text)
	q.lines.RichText = true
	q.lines.TextWrapped = true
	q.lines.TextYAlignment = Enum.TextYAlignment.Top

	q.viewBtn = makeButton(q.panel, "VER TODO", UDim2.fromOffset(160, 30), UDim2.fromOffset(16, 284), function()
		self:quickViewAll()
	end)
	q.viewBtn.Visible = false
	makeButton(q.panel, "CERRAR", UDim2.fromOffset(160, 30), UDim2.fromOffset(184, 284), function()
		self:hideQuick()
	end)
end

function Interface:applyQuickScale()
	local q = self.q
	if not q then
		return
	end
	local vp = self:viewport()
	q.base = math.clamp(math.min(vp.X / 390, vp.Y / 350), 0.5, 1.3)
	if q.panel.Visible then
		q.scale.Scale = q.base
	end
end

function Interface:quickRender(a, steps)
	local q = self.q
	local n = #steps
	local idx = a >= 1 and (n + 1) or (math.min(n, math.floor(a * n)) + 1)
	if idx == q.idx then
		return
	end
	if idx > 1 and idx > q.idx then
		Sound.play("confirm")
	end
	q.idx = idx
	local view = {}
	for j, s in ipairs(steps) do
		if j < idx then
			table.insert(view, L(s.k, s.v, s.sim))
		elseif j == idx then
			table.insert(view, L(s.k, "ANALIZANDO ···"))
		else
			table.insert(view, L(s.k, "···"))
		end
	end
	q.lines.Text = Util.renderLines(view)
end

-- Anima las filas del panel; devuelve false si se canceló.
function Interface:quickRunSteps(steps, token, lead)
	if lead > 0 then
		task.wait(lead)
		if self.destroyed or self.quickToken ~= token then
			return false
		end
	end
	local total = #steps * (Settings.Effects and 0.4 or 0.1)
	local t0 = os.clock()
	while true do
		if self.destroyed or self.quickToken ~= token then
			return false
		end
		local a = math.clamp((os.clock() - t0) / total, 0, 1)
		self:quickRender(a, steps)
		if a >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
end

local function sectionValue(res, key)
	if not res or not res.sections then
		return nil
	end
	for _, sec in ipairs(res.sections) do
		for _, l in ipairs(sec.items) do
			if l.k == key then
				return l.v
			end
		end
	end
end

-- Escaneo rápido de NPCs, objetos en movimiento y cualquier otra cosa.
function Interface:quickScanEntity(target, token)
	local q = self.q
	local inst = target.instance
	local ok, res = pcall(Scanners.object, target)
	if not ok or not res then
		Database.logError(ok and "Objeto no disponible" or res)
		q.title.Text = "C-137 // SIN DATOS"
		q.name.Text = tostring(inst.Name)
		q.stroke.Color = C.Danger
		q.lines.Text = Util.renderLines({ L("ERROR", ok and "El objeto ya no existe" or tostring(res)) })
		Sound.play("error")
		task.delay(2.8, function()
			if self.quickToken == token and not self.destroyed then
				self:hideQuick()
			end
		end)
		return
	end
	local isNpc = res.isNpc
	q.name.Text = inst.Name .. "\n" .. (isNpc and "NPC" or (res.maxSpeed > 0.5 and "OBJETO EN MOVIMIENTO" or "OBJETO"))
	q.avatar.Image = ""
	q.avatarNote.Visible = true
	q.avatarNote.Text = isNpc and "NPC" or "OBJ"

	local function v(k)
		return sectionValue(res, k) or "NO DISPONIBLE"
	end
	local steps = {
		{ k = "TIPO", v = v("Tipo") },
		{ k = "CLASE", v = v("Clase") },
		{ k = "DISTANCIA", v = v("Distancia") },
	}
	if isNpc then
		table.insert(steps, { k = "VIDA", v = v("Salud") })
		table.insert(steps, { k = "EN MANO", v = v("En mano") })
		table.insert(steps, { k = "ACCESORIOS", v = v("Accesorios") })
		table.insert(steps, { k = "ALTURA", v = v("Altura") })
	else
		table.insert(steps, { k = "TAMAÑO", v = v("Tamaño") })
		table.insert(steps, { k = "MATERIAL", v = v("Material") })
		table.insert(steps, { k = "ANCLADO", v = v("Anclado") })
	end
	table.insert(steps, { k = "VELOCIDAD", v = v("Velocidad máx.") })
	table.insert(steps, { k = "INTERACCIÓN", v = v("Interacciones") })

	task.spawn(function()
		if not self:quickRunSteps(steps, token, self.quickLead or 0) then
			return
		end
		q.title.Text = "C-137 // ESCANEO COMPLETADO"
		q.name.TextColor3 = C.Cyan
		q.entry = Database.add({
			mode = "quick",
			modeLabel = "QUICK SCAN",
			targetName = inst.Name .. (isNpc and " [NPC]" or ""),
			result = { lines = res.lines, sections = res.sections, simulated = false },
		})
		self.target = target
		self:refreshHistory()
		q.viewBtn.Visible = true
		Sound.play("identify")
		self:notify("Escaneo rápido: " .. inst.Name)
		task.delay(20, function()
			if self.quickToken == token and not self.destroyed then
				self:hideQuick()
			end
		end)
	end)
end

function Interface:quickScan()
	if self.destroyed then
		return
	end
	local q = self.q
	local target
	for _, t in ipairs(Scanners.nearbyPlayers(Settings.Range)) do
		if t.instance ~= LocalPlayer then
			target = t
			break
		end
	end
	-- NPCs y cosas en movimiento también cuentan; gana el más cercano
	for _, t in ipairs(Scanners.nearbyObjects(Settings.Range, { onlyLive = true, maxParts = 400, maxRadius = 150, limit = 1 })) do
		if not target or t.distance < target.distance then
			target = t
		end
	end

	self.quickToken = (self.quickToken or 0) + 1
	local token = self.quickToken

	-- reinicio visual
	q.idx = 0
	q.title.Text = "C-137 // ESCANEO RÁPIDO"
	q.name.TextColor3 = C.Text
	q.stroke.Color = C.Cyan
	q.viewBtn.Visible = false
	q.entry = nil
	self:applyQuickScale()
	local lead = (Settings.Effects and self.bracelet:armNeedsRaise()) and 0.5 or 0
	self.bracelet:setArmRaised(true, lead > 0 and lead or 0.15)
	local function showPanel()
		if self.destroyed or self.quickToken ~= token then
			return
		end
		q.panel.Visible = true
		if Settings.Effects then
			q.scale.Scale = q.base * 0.7
			Util.tween(q.scale, 0.25, { Scale = q.base }, Enum.EasingStyle.Back)
		else
			q.scale.Scale = q.base
		end
	end
	q.panel.Visible = false
	if lead > 0 then
		task.delay(lead, showPanel)
	else
		showPanel()
	end
	Util.tween(q.button, 0.08, { Size = UDim2.fromOffset(58, 58) })
	task.delay(0.1, function()
		if not self.destroyed then
			Util.tween(q.button, 0.12, { Size = UDim2.fromOffset(66, 66) })
		end
	end)
	self.bracelet:setActive(true)
	Sound.play("scan")

	if not target then
		local msg = "No hay jugadores, NPCs ni cosas en movimiento a menos de " .. Settings.Range .. " studs"
		Database.logError(msg)
		q.title.Text = "C-137 // SIN OBJETIVO"
		q.name.Text = "SIN OBJETIVO"
		q.avatar.Image = ""
		q.avatarNote.Text = "---"
		q.avatarNote.Visible = true
		q.stroke.Color = C.Danger
		q.lines.Text = Util.renderLines({ L("ERROR", msg) })
		Sound.play("error")
		self:notify("Nada que escanear cerca", "error")
		task.delay(2.8, function()
			if self.quickToken == token and not self.destroyed then
				self:hideQuick()
			end
		end)
		return
	end

	if target.kind == "object" then
		self.quickLead = lead
		self:quickScanEntity(target, token)
		return
	end

	local p = target.instance
	q.name.Text = p.DisplayName .. "\n@" .. p.Name
	self:loadAvatar(p.UserId, q.avatar, q.avatarNote)

	-- datos reales/simulados calculados al instante; se revelan con animación
	local results = {}
	for _, id in ipairs({ "life", "species", "threat" }) do
		local ok, res = pcall(Scanners[id], target)
		if ok and res then
			results[id] = res
		elseif not ok then
			Database.logError(res)
		end
	end
	local root = charRoot(p)
	local gear = Scanners.equipment(p)
	local fetched = false
	task.spawn(function()
		local ok, res = pcall(Scanners.identity, target)
		if ok and res then
			results.identity = res
		elseif not ok then
			Database.logError(res)
		end
		fetched = true
	end)
	local function clip(str, n)
		if #str > n then
			return str:sub(1, n - 3) .. "..."
		end
		return str
	end
	local steps = {
		{ k = "USUARIO", v = "@" .. p.Name },
		{ k = "ID", v = tostring(p.UserId) },
		{ k = "VIDA", v = findLine(results.life, "Salud") or "NO DISPONIBLE" },
		{ k = "ESPECIE", v = findLine(results.species, "Especie ficticia") or "NO DISPONIBLE", sim = results.species ~= nil },
		{ k = "AMENAZA", v = findLine(results.threat, "Nivel de amenaza") or "NO DISPONIBLE", sim = results.threat ~= nil },
		{ k = "DISTANCIA", v = root and fmtDist(distTo(root.Position)) or "NO DISPONIBLE" },
		{ k = "EN MANO", v = #gear.tools > 0 and clip(table.concat(gear.tools, ", "), 30) or "Nada equipado" },
		{ k = "ACCESORIOS", v = gear.accCount > 0 and (gear.accCount .. ": " .. clip(table.concat(gear.accNames, ", "), 24)) or "Ninguno" },
		{ k = "ROPA", v = (gear.shirt and "camisa" or "sin camisa") .. " + " .. (gear.pants and "pantalón" or "sin pantalón") .. (gear.graphic and " + camiseta" or "") },
		{ k = "TAMAÑO", v = gear.height and string.format("%.1f studs · escala %s", gear.height, gear.scale and gear.scale.height and string.format("%.2f", gear.scale.height) or "N/D") or "NO DISPONIBLE" },
	}

	task.spawn(function()
		if not self:quickRunSteps(steps, token, lead) then
			return
		end

		if not fetched then
			q.title.Text = "C-137 // RECOPILANDO DATOS PÚBLICOS..."
			local w0 = os.clock()
			while not fetched and os.clock() - w0 < 10 do
				if self.destroyed or self.quickToken ~= token then
					return
				end
				task.wait(0.1)
			end
		end
		local threat = results.threat
		q.title.Text = "C-137 // ESCANEO COMPLETADO"
		if threat then
			q.name.TextColor3 = threat.color
			q.stroke.Color = threat.color
		end

		local lines, sections = {}, {}
		local function addSec(title, items)
			table.insert(sections, { title = title, items = items })
			table.insert(lines, L("", "── " .. title .. " ──"))
			for _, l in ipairs(items) do
				table.insert(lines, l)
			end
		end
		local none = { L("Estado", "No disponible") }
		if results.identity then
			for _, sec in ipairs(results.identity.sections) do
				addSec(sec.title, sec.items)
			end
		else
			addSec("IDENTIDAD", none)
		end
		addSec("VIDA", results.life and results.life.lines or none)
		addSec("ESPECIE", results.species and results.species.lines or none)
		addSec("AMENAZA", results.threat and results.threat.lines or none)

		local life = results.life
		q.entry = Database.add({
			mode = "quick",
			modeLabel = "QUICK SCAN",
			targetName = target.name,
			result = {
				lines = lines,
				sections = sections,
				simulated = true,
				userId = p.UserId,
				bar = life and life.bar,
				color = life and life.color,
			},
		})
		self.target = target
		self:refreshHistory()
		if threat and threat.marker then
			Scanners.setMarker(threat.marker, self.gui)
		end
		q.viewBtn.Visible = true
		Sound.play("identify")
		self:notify("Escaneo rápido: " .. p.DisplayName)
		task.delay(20, function()
			if self.quickToken == token and not self.destroyed then
				self:hideQuick()
			end
		end)
	end)
end

function Interface:hideQuick()
	local q = self.q
	self.quickToken = (self.quickToken or 0) + 1
	local token = self.quickToken
	self.bracelet:setActive(self.visible)
	self.bracelet:setArmRaised(false, Settings.Effects and 0.4 or 0)
	local d = Settings.Effects and 0.2 or 0
	if d > 0 then
		Util.tween(q.scale, d, { Scale = q.base * 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(d, function()
		if self.quickToken == token and not self.destroyed then
			q.panel.Visible = false
		end
	end)
end

function Interface:quickViewAll()
	local q = self.q
	local entry = q.entry
	if not entry then
		return
	end
	Sound.play("confirm")
	if not self.visible then
		self:open()
	end
	self:showResult(entry)
	self:hideQuick()
end

-- Encendido / apagado ------------------------------------------------
function Interface:origin()
	local o = self.bracelet:screenPosition()
	if not o then
		local ap, as = self.toggle.AbsolutePosition, self.toggle.AbsoluteSize
		o = ap + as / 2
	end
	local vp = self:viewport()
	return Vector2.new(math.clamp(o.X, 0, vp.X), math.clamp(o.Y, 0, vp.Y))
end

function Interface:toggleDevice()
	if self.visible then
		self:close()
	else
		self:open()
	end
end

function Interface:open()
	if self.visible or self.animating or self.destroyed then
		return
	end
	self.animating = true
	self.visible = true
	self:applyScale()
	local win = self.win
	local h = self.minimized and TOP or H
	local origin = self:origin()
	Sound.play("activate")
	self.bracelet:setActive(true)
	self.bracelet:setArmRaised(true, Settings.Effects and 0.45 or 0.1)
	self.toggle.TextColor3 = C.Ok
	win.Visible = true
	self.body.Visible = not self.minimized
	local d = 0
	if Settings.Effects then
		d = 0.45
		win.Size = UDim2.fromOffset(60, TOP * 0.5)
		win.Position = UDim2.fromOffset(origin.X, origin.Y)
		Util.tween(win, d, {
			Size = UDim2.fromOffset(W, h),
			Position = UDim2.fromOffset(self.pos.X, self.pos.Y),
		}, Enum.EasingStyle.Back)
	else
		win.Size = UDim2.fromOffset(W, h)
		win.Position = UDim2.fromOffset(self.pos.X, self.pos.Y)
	end
	self:startFx()
	task.delay(d, function()
		self.animating = false
		if not self.destroyed and self.visible then
			self:boot()
		end
	end)
end

function Interface:boot()
	if self.minimized then
		return
	end
	self:setStatus("INICIALIZANDO C-137")
	Sound.play("loading")
	task.spawn(function()
		local t0 = os.clock()
		local dur = Settings.Effects and 0.7 or 0.15
		while self.visible and not self.destroyed do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			if self.scanning then
				return
			end
			self:setProgress(a)
			if a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if not self.scanning and self.visible then
			self:setProgress(0)
			self:setStatus("LISTO · " .. MODE_BY_ID[self.mode].label)
		end
	end)
end

function Interface:close()
	if not self.visible or self.animating or self.destroyed then
		return
	end
	self.animating = true
	self.visible = false
	self.fx:clean()
	Scanners.clearMarkers()
	self.bracelet:setActive(false)
	if not (self.q and self.q.panel.Visible) then
		self.bracelet:setArmRaised(false, Settings.Effects and 0.4 or 0)
	end
	self.toggle.TextColor3 = C.Cyan
	Sound.play("deactivate")
	local origin = self:origin()
	local d = Settings.Effects and 0.35 or 0
	if d > 0 then
		Util.tween(self.win, d, {
			Size = UDim2.fromOffset(60, TOP * 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		self.win.Visible = false
	end
	task.delay(d, function()
		self.animating = false
		if not self.visible and not self.destroyed then
			self.win.Visible = false
		end
	end)
end

function Interface:toggleMinimize()
	if self.animating or not self.visible then
		return
	end
	self.minimized = not self.minimized
	self.animating = true
	self.minBtn.Text = self.minimized and "+" or "_"
	local d = Settings.Effects and 0.25 or 0
	if self.minimized then
		Util.tween(self.win, d, { Size = UDim2.fromOffset(W, TOP) })
	else
		self.body.Visible = true
		Util.tween(self.win, d, { Size = UDim2.fromOffset(W, H) })
	end
	task.delay(d, function()
		self.animating = false
		if self.destroyed then
			return
		end
		self.body.Visible = not self.minimized
		if not self.minimized then
			self:clampPos()
		end
	end)
end

function Interface:destroy()
	self.destroyed = true
	self.fx:clean()
	Scanners.clearMarkers()
	self.maid:clean()
end

------------------------------------------------------------------------
-- MAIN
------------------------------------------------------------------------
local rootMaid = Util.newMaid()
Sound.init(rootMaid)

local bracelet = Bracelet.new()
local ui = Interface.new(bracelet)

script.Destroying:Connect(function()
	ui:destroy()
	bracelet:destroy()
	rootMaid:clean()
end)

task.delay(1, function()
	ui:notify("C-137 cargado")
	ui:open()
end)
