--[[
	Portal Bomb Ability
	Secuencia exacta:
	1. Aparece el marcador y se mueve
	2. Confirmas → aparece el portal en ese punto
	3. Portal espera 3 segundos
	4. Bomba sale del portal
	5. Portal desaparece JUSTO cuando sale la bomba
	6. Bomba viaja e impacta
	7. Se puede usar infinitamente
	8. Marcador se reinicia correctamente
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

local MarkerTemplate = ReplicatedStorage:WaitForChild("Marker")
local PortalTemplate = ReplicatedStorage:WaitForChild("Portal")
local BombTemplate   = ReplicatedStorage:WaitForChild("Bomb")

local PORTAL_TIME = 3
local BOMB_SPEED = 90
local MAX_RANGE = 140
local COOLDOWN = 0.4

local aiming = false
local marker = nil
local ready = true

local function clean(model)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Anchored = true
			v.Massless = true
		end
	end
end

local function destroyMarker()
	if marker then
		marker:Destroy()
		marker = nil
	end
end

local function startAim()
	if not ready or aiming then return end
	aiming = true

	marker = MarkerTemplate:Clone()
	marker.Parent = workspace
	marker.PrimaryPart = marker.PrimaryPart or marker:FindFirstChildWhichIsA("BasePart")
	clean(marker)
end

local function updateMarker()
	if not marker or not marker.PrimaryPart then return end

	local pos = mouse.Hit.Position
	local origin = root.Position
	local dir = pos - origin

	if dir.Magnitude > MAX_RANGE then
		dir = dir.Unit * MAX_RANGE
	end

	local target = origin + dir

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character, marker}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ray = workspace:Raycast(target + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	if ray then
		target = ray.Position
	end

	marker:SetPrimaryPartCFrame(CFrame.new(target))
end

local function fire()
	if not aiming or not marker or not marker.PrimaryPart then return end

	local targetPos = marker.PrimaryPart.Position
	destroyMarker()
	aiming = false
	ready = false

	local portal = PortalTemplate:Clone()
	portal.Parent = workspace
	portal.PrimaryPart = portal.PrimaryPart or portal:FindFirstChildWhichIsA("BasePart")
	clean(portal)
	portal:SetPrimaryPartCFrame(CFrame.new(targetPos + Vector3.new(0, 1.8, 0)))

	task.wait(PORTAL_TIME)

	if not portal.Parent then
		ready = true
		return
	end

	local bomb = BombTemplate:Clone()
	bomb.Parent = workspace
	bomb.PrimaryPart = bomb.PrimaryPart or bomb:FindFirstChildWhichIsA("BasePart")

	for _, v in ipairs(bomb:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CanCollide = true
			v.Anchored = false
		end
	end

	local start = portal.PrimaryPart.Position
	bomb:SetPrimaryPartCFrame(CFrame.new(start))

	portal:Destroy()

	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = (targetPos - start).Unit * BOMB_SPEED
	bv.Parent = bomb.PrimaryPart

	local conn
	conn = bomb.PrimaryPart.Touched:Connect(function(hit)
		if hit:IsDescendantOf(character) then return end

		local exp = Instance.new("Explosion")
		exp.Position = bomb.PrimaryPart.Position
		exp.BlastRadius = 20
		exp.BlastPressure = 700000
		exp.DestroyJointRadiusPercent = 0
		exp.Parent = workspace

		bomb:Destroy()
		if conn then conn:Disconnect() end
	end)

	task.delay(8, function()
		if bomb and bomb.Parent then
			bomb:Destroy()
		end
	end)

	task.delay(COOLDOWN, function()
		ready = true
	end)
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.E and not aiming and ready then
		startAim()
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and aiming then
		fire()
	elseif (input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Q) and aiming then
		destroyMarker()
		aiming = false
	end
end)

RunService.RenderStepped:Connect(function()
	if aiming then
		updateMarker()
	end
end)

humanoid.Died:Connect(function()
	destroyMarker()
	aiming = false
	ready = true
end)

print("Portal Bomb listo | E = apuntar | Clic = confirmar | Q = cancelar")
