local P=game:GetService("Players")
local R=game:GetService("RunService")
local G=game:GetService("CoreGui")
local me=P.LocalPlayer
local gui=me:WaitForChild("PlayerGui")
local Y=Color3.fromRGB(255,210,0)
local Y2=Color3.fromRGB(255,235,80)
local B=Color3.new(0,0,0)
local RED=Color3.fromRGB(200,20,20)
local IMG="rbxassetid://105752278503706"
local WPNIMG="rbxassetid://132612039997186"
local SND="rbxassetid://137299977455447"
local FOLDER_GRID="rbxassetid://89406815331721"
local FOLDER_SEL="rbxassetid://96677771893759"
local NOT_FOUND="rbxassetid://101279093579785"

for _,v in ipairs({G,gui}) do
	pcall(function()
		local o=v:FindFirstChild("EvilMortyScanner") if o then o:Destroy() end
		local o2=v:FindFirstChild("EvilMortyRegistry") if o2 then o2:Destroy() end
	end)
end

local function equippedTool(char)
	for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") then return v end end
end

local function equipped(char)
	local t={}
	for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") then table.insert(t,v.Name) end end
	return #t>0 and table.concat(t,", ") or "NINGUNO"
end

local function inventory(char,plr)
	local t,seen={},{}
	local function add(v) if v:IsA("Tool") and not seen[v] then seen[v]=true table.insert(t,v.Name) end end
	if char then for _,v in ipairs(char:GetChildren()) do add(v) end end
	if plr then
		for _,v in ipairs(plr:GetChildren()) do
			if v:IsA("Backpack") then for _,tl in ipairs(v:GetChildren()) do add(tl) end end
		end
		local pg=plr:FindFirstChildOfClass("PlayerGui")
		if pg then for _,v in ipairs(pg:GetDescendants()) do add(v) end end
	end
	if #t==0 then return "VACIO" end
	local s=table.concat(t,", ")
	return s=="" and "VACIO" or s
end

local function movement(char)
	local h=char:FindFirstChildOfClass("Humanoid")
	local root=char:FindFirstChild("HumanoidRootPart")
	if not h or not root then return "UNKNOWN" end
	local s=h:GetState()
	if s==Enum.HumanoidStateType.Jumping then return "JUMPING" end
	if s==Enum.HumanoidStateType.Freefall then return "FALLING" end
	if s==Enum.HumanoidStateType.Climbing then return "CLIMBING" end
	if s==Enum.HumanoidStateType.Swimming then return "SWIMMING" end
	local v=root.AssemblyLinearVelocity
	local sp=Vector3.new(v.X,0,v.Z).Magnitude
	if v.Y<-20 then return "FALLING" end
	if v.Y>15 then return "JUMPING" end
	if sp<1 then return "IDLE" end
	return sp<h.WalkSpeed+1 and "WALKING" or "RUNNING"
end

local ui=Instance.new("ScreenGui")
ui.Name="EvilMortyScanner"
ui.ResetOnSpawn=false
ui.IgnoreGuiInset=true
ui.Parent=gui

local snd=Instance.new("Sound")
snd.SoundId=SND
snd.Volume=1
snd.Parent=ui

local function mkBtn(t,y)
	local b=Instance.new("TextButton")
	b.Size=UDim2.fromOffset(110,40)
	b.Position=UDim2.new(0,20,.5,y)
	b.BackgroundColor3=B
	b.Text=t
	b.TextColor3=Y
	b.Font=Enum.Font.Code
	b.TextScaled=true
	b.Parent=ui
	Instance.new("UIStroke",b).Color=RED
	return b
end

local scan=mkBtn("SCAN",-100)
local stop=mkBtn("STOP",-50)
local regBtn=mkBtn("REGISTRADOS",0)

local regGui=Instance.new("ScreenGui")
regGui.Name="EvilMortyRegistry"
regGui.ResetOnSpawn=false
regGui.IgnoreGuiInset=true
regGui.Enabled=false
regGui.Parent=gui

local holder=Instance.new("Frame")
holder.Size=UDim2.fromScale(0.85,0.85)
holder.Position=UDim2.fromScale(0.5,0.5)
holder.AnchorPoint=Vector2.new(0.5,0.5)
holder.BackgroundTransparency=1
holder.Parent=regGui

local aspect=Instance.new("UIAspectRatioConstraint",holder)
aspect.AspectRatio=1604/980
aspect.AspectType=Enum.AspectType.FitWithinMaxSize

local baseImg=Instance.new("ImageLabel")
baseImg.Size=UDim2.fromScale(1,1)
baseImg.BackgroundTransparency=1
baseImg.Image=FOLDER_GRID
baseImg.ScaleType=Enum.ScaleType.Stretch
baseImg.Parent=holder

local carpetas={
	{0.020,0.190,0.150,0.180},{0.175,0.190,0.150,0.180},
	{0.330,0.190,0.150,0.180},{0.485,0.190,0.150,0.180},
	{0.020,0.385,0.150,0.180},{0.175,0.385,0.150,0.180},
	{0.330,0.385,0.150,0.180},{0.485,0.385,0.150,0.180},
	{0.020,0.580,0.150,0.180},{0.175,0.580,0.150,0.180},
	{0.330,0.580,0.150,0.180},{0.485,0.580,0.150,0.180},
}

local panelX,panelY,panelW,panelH=0.655,0.145,0.305,0.690
local centerX,centerY=panelX+panelW/2,panelY+panelH/2

local avatarImg=Instance.new("ImageLabel")
avatarImg.Size=UDim2.fromScale(panelW*0.60,panelH*0.34)
avatarImg.Position=UDim2.fromScale(panelX+panelW*0.20,panelY+panelH*(-0.01))
avatarImg.BackgroundTransparency=1
avatarImg.ScaleType=Enum.ScaleType.Fit
avatarImg.Visible=false
avatarImg.ZIndex=8
avatarImg.Parent=holder

local panelName=Instance.new("TextLabel")
panelName.Size=UDim2.fromScale(panelW*0.90,panelH*0.07)
panelName.Position=UDim2.fromScale(panelX+panelW*0.05,panelY+panelH*0.33)
panelName.BackgroundTransparency=1
panelName.Text=""
panelName.TextColor3=Y2
panelName.Font=Enum.Font.Code
panelName.TextSize=22
panelName.TextStrokeTransparency=0
panelName.TextStrokeColor3=B
panelName.TextScaled=true
panelName.Visible=false
panelName.ZIndex=8
panelName.Parent=holder

local folderButtons={}
for i,pos in ipairs(carpetas) do
	local btn=Instance.new("TextButton")
	btn.Position=UDim2.fromScale(pos[1],pos[2])
	btn.Size=UDim2.fromScale(pos[3],pos[4])
	btn.BackgroundTransparency=1
	btn.Text=""
	btn.ZIndex=5
	btn.Visible=false
	btn.Parent=holder

	local sel=Instance.new("ImageLabel")
	sel.Name="Sel"
	sel.AnchorPoint=Vector2.new(0.5,0.5)
	sel.Position=UDim2.fromScale(0.5,0.5)
	sel.Size=UDim2.fromScale(1.1,1.1)
	sel.BackgroundTransparency=1
	sel.Image=FOLDER_SEL
	sel.ScaleType=Enum.ScaleType.Stretch
	sel.Visible=false
	sel.ZIndex=6
	sel.Parent=btn

	local nl=Instance.new("TextLabel")
	nl.Name="PlayerName"
	nl.AnchorPoint=Vector2.new(0.5,0)
	nl.Position=UDim2.new(0.5,0,1,2)
	nl.Size=UDim2.new(1,0,0,16)
	nl.BackgroundTransparency=0.4
	nl.BackgroundColor3=B
	nl.Text=""
	nl.TextColor3=Y2
	nl.Font=Enum.Font.Code
	nl.TextSize=12
	nl.TextStrokeTransparency=0
	nl.TextStrokeColor3=B
	nl.TextTruncate=Enum.TextTruncate.AtEnd
	nl.ZIndex=7
	nl.Parent=btn

	folderButtons[i]={btn=btn,sel=sel,label=nl,userId=nil}
end

local nfImg=Instance.new("ImageLabel")
nfImg.AnchorPoint=Vector2.new(0.5,0.5)
nfImg.Position=UDim2.fromScale(centerX,centerY)
nfImg.Size=UDim2.fromScale(panelW*1.40,panelH*0.75)
nfImg.BackgroundTransparency=1
nfImg.Image=NOT_FOUND
nfImg.ScaleType=Enum.ScaleType.Fit
nfImg.Visible=false
nfImg.ZIndex=9
nfImg.Parent=holder

local infoFrame=Instance.new("Frame")
infoFrame.Size=UDim2.fromScale(panelW*0.96,panelH*0.52)
infoFrame.Position=UDim2.fromScale(panelX+panelW*0.02,panelY+panelH*0.44)
infoFrame.BackgroundTransparency=1
infoFrame.ClipsDescendants=true
infoFrame.Visible=false
infoFrame.ZIndex=8
infoFrame.Parent=holder

local iPad=Instance.new("UIPadding",infoFrame)
iPad.PaddingTop=UDim.new(0,4)
iPad.PaddingBottom=UDim.new(0,4)
iPad.PaddingLeft=UDim.new(0,8)
iPad.PaddingRight=UDim.new(0,8)

local iList=Instance.new("UIListLayout",infoFrame)
iList.Padding=UDim.new(0,2)

local function mkInfo(txt)
	local l=Instance.new("TextLabel")
	l.Size=UDim2.new(1,0,0,16)
	l.BackgroundTransparency=1
	l.TextColor3=Y2
	l.TextStrokeColor3=B
	l.TextStrokeTransparency=0
	l.Font=Enum.Font.Code
	l.TextSize=13
	l.TextXAlignment=Enum.TextXAlignment.Left
	l.TextWrapped=true
	l.TextYAlignment=Enum.TextYAlignment.Top
	l.Text=txt
	l.Parent=infoFrame
	return l
end

local lStatus=mkInfo("STATUS: --")
local lSubject=mkInfo("SUJETO: --")
local lHealth=mkInfo("SALUD: --")
local lWeapon=mkInfo("EQUIPADO: --")
local lInv=mkInfo("INVENTARIO: --")
local lMove=mkInfo("MOVIMIENTO: --")
lInv.Size=UDim2.new(1,0,0,60)

local closeBtn=Instance.new("TextButton")
closeBtn.Size=UDim2.fromOffset(80,25)
closeBtn.Position=UDim2.new(1,-90,0,10)
closeBtn.BackgroundColor3=RED
closeBtn.Text="CERRAR"
closeBtn.TextColor3=Y
closeBtn.Font=Enum.Font.Code
closeBtn.TextSize=12
closeBtn.ZIndex=10
closeBtn.Parent=holder

local scannedList={}
local scannedSet={}
local selectedFolder=nil

local function getAvatar(userId)
	local ok,url=pcall(function()
		return P:GetUserThumbnailAsync(userId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150)
	end)
	return ok and url or ""
end

local function snapshot(plr)
	local ch=plr.Character
	local h=ch and ch:FindFirstChildOfClass("Humanoid")
	local invTxt="VACIO"
	if ch then
		local inv=inventory(ch,plr)
		if type(inv)=="string" and inv\~="" then invTxt=inv end
	end
	return {
		name=plr.Name,
		status=ch and movement(ch) or "UNKNOWN",
		subject=plr.Name,
		health=h and (math.floor(h.Health).."/"..math.floor(h.MaxHealth)) or "--",
		weapon=ch and equipped(ch) or "NINGUNO",
		inventory=invTxt,
		move=ch and movement(ch) or "UNKNOWN"
	}
end

local function addScannedPlayer(plr)
	if scannedSet[plr.UserId] then
		for _,e in ipairs(scannedList) do
			if e.userId==plr.UserId then e.snap=snapshot(plr) break end
		end
		return
	end
	if #scannedList>=12 then return end
	table.insert(scannedList,{userId=plr.UserId,name=plr.Name,snap=snapshot(plr)})
	scannedSet[plr.UserId]=true
	local fb=folderButtons[#scannedList]
	fb.userId=plr.UserId
	fb.label.Text=plr.Name
	fb.btn.Visible=true
end

local function showSnapshot(snap,userId)
	avatarImg.Image=getAvatar(userId)
	panelName.Text=tostring(snap.name)
	lStatus.Text="STATUS: "..tostring(snap.status)
	lSubject.Text="SUJETO: "..tostring(snap.subject)
	lHealth.Text="SALUD: "..tostring(snap.health)
	lWeapon.Text="EQUIPADO: "..tostring(snap.weapon)
	lInv.Text="INVENTARIO: "..tostring(snap.inventory)
	lMove.Text="MOVIMIENTO: "..tostring(snap.move)
end

for i,fb in ipairs(folderButtons) do
	fb.btn.MouseButton1Click:Connect(function()
		if not fb.userId then return end
		if selectedFolder then selectedFolder.sel.Visible=false end
		selectedFolder=fb
		fb.sel.Visible=true

		local tp
		for _,p in ipairs(P:GetPlayers()) do
			if p.UserId==fb.userId then tp=p break end
		end

		local entry
		for _,e in ipairs(scannedList) do
			if e.userId==fb.userId then entry=e break end
		end

		if tp and tp.Character and entry then
			entry.snap=snapshot(tp)
			nfImg.Visible=false
			infoFrame.Visible=true
			avatarImg.Visible=true
			panelName.Visible=true
			showSnapshot(entry.snap,fb.userId)
		else
			infoFrame.Visible=false
			nfImg.Visible=true
			avatarImg.Visible=false
			panelName.Visible=false
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(1)
		if regGui.Enabled and selectedFolder and selectedFolder.userId then
			local tp
			for _,p in ipairs(P:GetPlayers()) do
				if p.UserId==selectedFolder.userId then tp=p break end
			end
			local entry
			for _,e in ipairs(scannedList) do
				if e.userId==selectedFolder.userId then entry=e break end
			end
			if tp and tp.Character and entry and infoFrame.Visible then
				entry.snap=snapshot(tp)
				showSnapshot(entry.snap,selectedFolder.userId)
			end
		end
	end
end)

regBtn.MouseButton1Click:Connect(function()
	regGui.Enabled=not regGui.Enabled
end)

closeBtn.MouseButton1Click:Connect(function()
	regGui.Enabled=false
	infoFrame.Visible=false
	nfImg.Visible=false
	avatarImg.Visible=false
	panelName.Visible=false
end)

local target,bb,wpnGui,labels

local function create(char)
	if bb then bb:Destroy() end
	local head=char:FindFirstChild("Head")
	if not head then return end
	bb=Instance.new("BillboardGui")
	bb.Adornee=head
	bb.Size=UDim2.fromOffset(240,320)
	bb.AlwaysOnTop=true
	bb.Parent=head

	local image=Instance.new("ImageLabel",bb)
	image.AnchorPoint=Vector2.new(0.5,0.5)
	image.Position=UDim2.fromScale(0.5,0.5)
	image.Size=UDim2.fromOffset(70,70)
	image.BackgroundTransparency=1
	image.Image=IMG
	image.ScaleType=Enum.ScaleType.Fit
	image.ZIndex=2

	local root=Instance.new("Frame",bb)
	root.AnchorPoint=Vector2.new(0.5,0)
	root.Position=UDim2.new(0.5,0,0.5,40)
	root.Size=UDim2.new(1,0,0,220)
	root.BackgroundTransparency=1

	local list=Instance.new("UIListLayout",root)
	list.HorizontalAlignment=Enum.HorizontalAlignment.Center
	list.Padding=UDim.new(0,2)

	local function lbl(txt,h)
		local l=Instance.new("TextLabel",root)
		l.Size=UDim2.new(1,0,0,h or 17)
		l.BackgroundColor3=B
		l.BackgroundTransparency=0.2
		l.TextColor3=Y
		l.TextStrokeTransparency=0.3
		l.Font=Enum.Font.Code
		l.TextSize=11
		l.TextWrapped=true
		l.TextXAlignment=Enum.TextXAlignment.Left
		l.Text=txt
		return l
	end

	return {
		title=lbl(target.Name,20),
		status=lbl("STATUS: --"),
		subject=lbl("SUJETO: --"),
		health=lbl("SALUD: --"),
		weapon=lbl("EQUIPADO: --",30),
		inv=lbl("INVENTARIO: --",60),
		move=lbl("MOVIMIENTO: --"),
		dist=lbl("DISTANCIA: --"),
		scanImage=image,
		infoFrame=root
	}
end

local function createWeaponGui(tool)
	if wpnGui then wpnGui:Destroy() wpnGui=nil end
	local handle=tool:FindFirstChild("Handle")
	if not handle then return end
	wpnGui=Instance.new("BillboardGui")
	wpnGui.Adornee=handle
	wpnGui.Size=UDim2.fromOffset(220,180)
	wpnGui.AlwaysOnTop=true
	wpnGui.Parent=handle

	local frame=Instance.new("ImageLabel",wpnGui)
	frame.AnchorPoint=Vector2.new(0.5,0.5)
	frame.Position=UDim2.fromScale(0.5,0.4)
	frame.Size=UDim2.fromOffset(100,100)
	frame.BackgroundTransparency=1
	frame.Image=WPNIMG
	frame.ScaleType=Enum.ScaleType.Fit
	frame.ZIndex=3

	local wl=Instance.new("TextLabel",wpnGui)
	wl.Name="WeaponDetected"
	wl.AnchorPoint=Vector2.new(0.5,0)
	wl.Position=UDim2.new(0.5,0,1,-30)
	wl.Size=UDim2.fromOffset(240,26)
	wl.BackgroundTransparency=1
	wl.TextColor3=Y
	wl.TextStrokeTransparency=0.3
	wl.Font=Enum.Font.Code
	wl.TextSize=20
	wl.Text="ARMA DETECTADA: "..tool.Name
	wl.ZIndex=4
end

local function closest()
	local c=me.Character
	local r=c and c:FindFirstChild("HumanoidRootPart")
	if not r then return end
	local best,dmin
	for _,p in ipairs(P:GetPlayers()) do
		local ch=p.Character
		local hr=ch and ch:FindFirstChild("HumanoidRootPart")
		local h=ch and ch:FindFirstChildOfClass("Humanoid")
		if p\~=me and hr and h and h.Health>0 then
			local d=(hr.Position-r.Position).Magnitude
			if not dmin or d<dmin then best,dmin=p,d end
		end
	end
	return best
end

local beamOuter,beamInner
local function ensureBeam()
	if beamOuter and beamOuter.Parent then return end
	beamOuter=Instance.new("Part")
	beamOuter.Anchored=true
	beamOuter.CanCollide=false
	beamOuter.CanQuery=false
	beamOuter.CanTouch=false
	beamOuter.CastShadow=false
	beamOuter.Material=Enum.Material.Neon
	beamOuter.Color=Y
	beamOuter.Transparency=0.25
	beamOuter.Size=Vector3.new(0.18,0.18,1)
	beamOuter.Parent=workspace

	beamInner=Instance.new("Part")
	beamInner.Anchored=true
	beamInner.CanCollide=false
	beamInner.CanQuery=false
	beamInner.CanTouch=false
	beamInner.CastShadow=false
	beamInner.Material=Enum.Material.Neon
	beamInner.Color=Color3.fromRGB(255,245,180)
	beamInner.Size=Vector3.new(0.08,0.08,1)
	beamInner.Parent=workspace
end

local function destroyBeam()
	if beamOuter then beamOuter:Destroy() beamOuter=nil end
	if beamInner then beamInner:Destroy() beamInner=nil end
end

local function start()
	snd:Play()
	target=closest()
	if not target then return end
	local ch=target.Character
	if not ch or not ch:FindFirstChild("Head") then return end
	labels=create(ch)
	ensureBeam()
	addScannedPlayer(target)
end

local function finish()
	target=nil
	if bb then bb:Destroy() bb=nil end
	if wpnGui then wpnGui:Destroy() wpnGui=nil end
	labels=nil
	destroyBeam()
	snd:Stop()
end

scan.MouseButton1Click:Connect(start)
stop.MouseButton1Click:Connect(finish)

R.RenderStepped:Connect(function()
	if not target then return end
	local ch=target.Character
	if not ch then return end
	local head=ch:FindFirstChild("Head")
	local hum=ch:FindFirstChildOfClass("Humanoid")
	local mine=me.Character
	local a=mine and mine:FindFirstChild("HumanoidRootPart")
	local b=ch:FindFirstChild("HumanoidRootPart")
	if not head then return end
	if not bb then labels=create(ch) end
	if not labels then return end

	local tool=equippedTool(ch)
	if tool then
		labels.scanImage.Visible=false
		labels.infoFrame.Visible=false
		local handle=tool:FindFirstChild("Handle")
		if not wpnGui or wpnGui.Adornee\~=handle then
			createWeaponGui(tool)
		else
			local l=wpnGui:FindFirstChild("WeaponDetected")
			if l then l.Text="ARMA DETECTADA: "..tool.Name end
		end
	else
		if wpnGui then wpnGui:Destroy() wpnGui=nil end
		labels.scanImage.Visible=true
		labels.infoFrame.Visible=true
		labels.status.Text="STATUS: "..movement(ch)
		labels.subject.Text="SUJETO: "..target.Name
		labels.health.Text=hum and ("SALUD: "..math.floor(hum.Health).."/"..math.floor(hum.MaxHealth)) or "SALUD: --"
		labels.weapon.Text="EQUIPADO: "..equipped(ch)
		labels.inv.Text="INVENTARIO: "..inventory(ch,target)
		labels.move.Text="MOVIMIENTO: "..movement(ch)
		labels.dist.Text="DISTANCIA: "..(a and b and math.floor((a.Position-b.Position).Magnitude).." studs" or "--")
	end

	local myHead=mine and mine:FindFirstChild("Head")
	if myHead and beamOuter and beamInner then
		local p1=myHead.Position
		local p2=head.Position
		local d=(p2-p1).Magnitude
		if d>0.1 then
			local mid=(p1+p2)/2
			local look=CFrame.lookAt(mid,p2)
			beamOuter.CFrame=look
			beamOuter.Size=Vector3.new(0.18,0.18,d)
			beamInner.CFrame=look
			beamInner.Size=Vector3.new(0.08,0.08,d)
			beamOuter.Transparency=0.25
			beamInner.Transparency=0
		else
			beamOuter.Transparency=1
			beamInner.Transparency=1
		end
	end
end)
