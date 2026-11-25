loadstring([==[
-- Mini Panel v2.5: Superman fly, Laser Eyes tool, cinematic Click TP, noclip, !to / !hide / !unhide
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

local env = (getgenv and getgenv()) or _G
if env.MiniPanelCleanup then pcall(env.MiniPanelCleanup) end

local conns = {}
local function track(c) table.insert(conns, c) return c end

local function getParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok = pcall(function() return game.CoreGui:GetChildren() end)
	if ok then return game.CoreGui end
	return LP:WaitForChild("PlayerGui")
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(o, r) local c = Instance.new("UICorner", o) c.CornerRadius = UDim.new(0, r) return c end
local rng = Random.new()

---------------------------------------------------------------- Colors
local BG        = Color3.fromRGB(24, 24, 32)
local ROW       = Color3.fromRGB(34, 34, 46)
local ROW_HOVER = Color3.fromRGB(44, 44, 60)
local ACCENT    = Color3.fromRGB(120, 90, 255)
local ACCENT2   = Color3.fromRGB(80, 200, 255)
local OFF       = Color3.fromRGB(70, 70, 90)

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "MiniPanel"
gui.ResetOnSpawn = false
gui.Parent = getParent()

local CLICK_ID, TOGGLE_ID = "rbxassetid://421058925", "rbxassetid://6895079853"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local function sfx(id, speed, vol)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = gui
	s:Play()
	Debris:AddItem(s, 2)
end

local main = Instance.new("CanvasGroup")
main.Size = UDim2.fromOffset(300, 392)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.BackgroundColor3 = BG
main.GroupTransparency = 1
main.Visible = false
main.Parent = gui
corner(main, 14)

local scale = Instance.new("UIScale", main)
scale.Scale = 0.6

local stroke = Instance.new("UIStroke", main)
stroke.Thickness = 1.5
stroke.Color = Color3.new(1, 1, 1)
local grad = Instance.new("UIGradient", stroke)
grad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, ACCENT),
	ColorSequenceKeypoint.new(0.5, ACCENT2),
	ColorSequenceKeypoint.new(1, ACCENT),
})

local handle = Instance.new("Frame")
handle.Size = UDim2.new(1, -50, 0, 44)
handle.BackgroundTransparency = 1
handle.Parent = main

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(8, 8)
dot.Position = UDim2.fromOffset(16, 18)
dot.BackgroundColor3 = ACCENT2
dot.Parent = handle
corner(dot, 4)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.fromOffset(32, 0)
title.BackgroundTransparency = 1
title.Text = "Mini Panel"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = handle

local function hoverable(btn, normal, hover)
	local s = Instance.new("UIScale", btn)
	btn.MouseEnter:Connect(function()
		tween(btn, 0.2, {BackgroundColor3 = hover})
		tween(s, 0.2, {Scale = 1.08}, Enum.EasingStyle.Back)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.2, {BackgroundColor3 = normal})
		tween(s, 0.2, {Scale = 1})
	end)
	btn.MouseButton1Down:Connect(function() tween(s, 0.1, {Scale = 0.92}) end)
	btn.MouseButton1Up:Connect(function() tween(s, 0.15, {Scale = 1.08}, Enum.EasingStyle.Back) end)
end

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -38, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 66)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.AutoButtonColor = false
closeBtn.Parent = main
corner(closeBtn, 8)
hoverable(closeBtn, Color3.fromRGB(50, 50, 66), Color3.fromRGB(220, 70, 80))

local out = Instance.new("TextLabel")
out.Size = UDim2.new(1, -28, 0, 50)
out.Position = UDim2.fromOffset(14, 334)
out.BackgroundTransparency = 1
out.Text = "K = panel  |  F = fly  |  L = laser eyes"
out.Font = Enum.Font.Gotham
out.TextSize = 12
out.TextWrapped = true
out.TextYAlignment = Enum.TextYAlignment.Top
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextColor3 = Color3.fromRGB(170, 170, 190)
out.Parent = main
local function say(msg)
	out.Text = msg
	out.TextTransparency = 1
	tween(out, 0.3, {TextTransparency = 0})
end

local function makeToggle(labelText, y, onChange)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -28, 0, 40)
	row.Position = UDim2.fromOffset(14, y)
	row.BackgroundColor3 = ROW
	row.AutoButtonColor = false
	row.Text = ""
	row.Parent = main
	corner(row, 10)
	local rs = Instance.new("UIScale", row)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 1, 0)
	lbl.Position = UDim2.fromOffset(12, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(200, 200, 215)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local sw = Instance.new("Frame")
	sw.Size = UDim2.fromOffset(46, 24)
	sw.Position = UDim2.new(1, -58, 0.5, -12)
	sw.BackgroundColor3 = OFF
	sw.Parent = row
	corner(sw, 12)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = sw
	corner(knob, 9)

	local state = false
	local function set(v)
		state = v
		tween(knob, 0.28, {Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}, Enum.EasingStyle.Back)
		tween(sw, 0.25, {BackgroundColor3 = v and ACCENT or OFF})
		tween(lbl, 0.25, {TextColor3 = v and Color3.new(1, 1, 1) or Color3.fromRGB(200, 200, 215)})
		onChange(v)
	end

	row.MouseEnter:Connect(function()
		tween(row, 0.2, {BackgroundColor3 = ROW_HOVER})
		tween(rs, 0.2, {Scale = 1.02}, Enum.EasingStyle.Back)
	end)
	row.MouseLeave:Connect(function()
		tween(row, 0.2, {BackgroundColor3 = ROW})
		tween(rs, 0.2, {Scale = 1})
	end)
	row.MouseButton1Down:Connect(function() tween(rs, 0.1, {Scale = 0.97}) end)
	row.MouseButton1Up:Connect(function() tween(rs, 0.15, {Scale = 1.02}, Enum.EasingStyle.Back) end)
	row.MouseButton1Click:Connect(function()
		sfx(TOGGLE_ID, state and 0.85 or 1.15)
		set(not state)
	end)
	return set, function() return state end
end

---------------------------------------------------------------- Noclip
local noclipActive = false
local noclipConns = {}
local originalCollide = setmetatable({}, {__mode = "k"})

local function noclipStep()
	local char = LP.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then
			if originalCollide[p] == nil then originalCollide[p] = p.CanCollide end
			if p.CanCollide then p.CanCollide = false end
		end
	end
end

local function unstick()
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local function blocked()
		for _, part in ipairs(workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(2, 4.5, 1.5), params)) do
			if part.CanCollide then return true end
		end
		return false
	end
	local moved = 0
	while moved < 80 and blocked() do
		root.CFrame = root.CFrame + Vector3.new(0, 1, 0)
		moved += 1
	end
	if moved > 0 then root.AssemblyLinearVelocity = Vector3.zero end
end

local function noclipOff()
	noclipActive = false
	for _, c in ipairs(noclipConns) do pcall(function() c:Disconnect() end) end
	table.clear(noclipConns)
	for p, was in pairs(originalCollide) do
		if p.Parent then p.CanCollide = was end
		originalCollide[p] = nil
	end
	pcall(unstick)
end

local function setNoclip(on)
	if on then
		if noclipActive then return end
		noclipActive = true
		table.insert(noclipConns, RunService.Stepped:Connect(noclipStep))
		table.insert(noclipConns, RunService.Heartbeat:Connect(noclipStep))
		say("Noclip ON")
	else
		noclipOff()
		say("Noclip OFF")
	end
end

---------------------------------------------------------------- Click TP (arc + motion blur + FOV punch + trail)
local TP_BLUR_MAX = 26
local TP_FOV_MAX  = 26

local tpEnabled = false
local tpTool
local flyVel = Vector3.zero

local tpBlur = Instance.new("BlurEffect")
tpBlur.Name = "MiniPanelBlur"
tpBlur.Size = 0
tpBlur.Enabled = false
tpBlur.Parent = Lighting

local tpConn, blurTween, fovTween, tpBaseFov, trailObjs

local function ease(a)
	if a < 0.5 then return 4 * a * a * a end
	return 1 - ((-2 * a + 2) ^ 3) / 2
end

local function dropTrail(immediate)
	if not trailObjs then return end
	for _, o in ipairs(trailObjs) do
		if o:IsA("Trail") then o.Enabled = false end
		if immediate then pcall(function() o:Destroy() end) else Debris:AddItem(o, 0.7) end
	end
	trailObjs = nil
end

local function makeTrail(root)
	dropTrail(true)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.4, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.4, 0)
	a1.Parent = root
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.4
	tr.MinLength = 0
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(ACCENT2, ACCENT)
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	tr.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
	tr.Parent = root
	trailObjs = {a0, a1, tr}
end

local function pulseRing(pos)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = ACCENT2
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	tween(ring, 0.7, {Size = Vector3.new(0.2, 9, 9), Transparency = 1})
	Debris:AddItem(ring, 0.8)
end

local function finishTeleport(root)
	if tpConn then tpConn:Disconnect() tpConn = nil end
	if root and root.Parent then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	flyVel = Vector3.zero
	dropTrail(false)

	local cam = workspace.CurrentCamera
	if cam and tpBaseFov then
		fovTween = tween(cam, 0.45, {FieldOfView = tpBaseFov}, Enum.EasingStyle.Quad)
		fovTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not tpConn then tpBaseFov = nil end
		end)
	end
	blurTween = tween(tpBlur, 0.35, {Size = 0}, Enum.EasingStyle.Quad)
	blurTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not tpConn then tpBlur.Enabled = false end
	end)
	sfx(CLICK_ID, 0.7, 0.5)
end

local function cancelTeleport()
	if tpConn then
		local char = LP.Character
		finishTeleport(char and char:FindFirstChild("HumanoidRootPart"))
	end
end

local function smoothTeleport(pos)
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera

	local lift = (hum and hum.HipHeight or 2) + root.Size.Y / 2 + 0.5
	local goal = pos + Vector3.new(0, lift, 0)
	local start = root.Position
	local dist = (goal - start).Magnitude
	if dist < 1 then return end

	if tpConn then tpConn:Disconnect() tpConn = nil end
	if blurTween then blurTween:Cancel() end
	if fovTween then fovTween:Cancel() end

	pulseRing(pos)
	sfx(TOGGLE_ID, 1.7, 0.45)
	makeTrail(root)

	local dur = math.clamp(0.35 + dist / 450, 0.4, 1.5)
	local arc = dist > 12 and math.clamp(dist * 0.1, 3, 35) or 0
	local flat = Vector3.new(goal.X - start.X, 0, goal.Z - start.Z)
	local rot = root.CFrame.Rotation
	local faceRot = flat.Magnitude > 1 and CFrame.lookAt(Vector3.zero, flat.Unit) or rot

	tpBlur.Enabled = true
	if cam and not tpBaseFov then tpBaseFov = cam.FieldOfView end

	root.Anchored = true
	local elapsed, prev = 0, start
	local blurSize = tpBlur.Size
	local fovAdd = (cam and tpBaseFov) and (cam.FieldOfView - tpBaseFov) or 0

	tpConn = RunService.RenderStepped:Connect(function(dt)
		if not root.Parent then
			finishTeleport(nil)
			return
		end
		elapsed += dt
		local a = math.min(elapsed / dur, 1)
		local p = start:Lerp(goal, ease(a)) + Vector3.new(0, math.sin(math.pi * a) * arc, 0)
		rot = rot:Lerp(faceRot, 1 - math.exp(-dt * 9))
		root.CFrame = CFrame.new(p) * rot
		root.AssemblyLinearVelocity = Vector3.zero

		local speed = (p - prev).Magnitude / math.max(dt, 1e-3)
		prev = p
		blurSize += (math.clamp(speed / 24, 0, TP_BLUR_MAX) - blurSize) * (1 - math.exp(-dt * 14))
		tpBlur.Size = blurSize
		fovAdd += (math.clamp(speed / 20, 0, TP_FOV_MAX) - fovAdd) * (1 - math.exp(-dt * 10))
		if cam and tpBaseFov then cam.FieldOfView = tpBaseFov + fovAdd end

		if a >= 1 then finishTeleport(root) end
	end)
end

local function removeTool()
	if tpTool then tpTool:Destroy() tpTool = nil end
end

local function giveTool()
	if tpTool and tpTool.Parent then return end
	local t = Instance.new("Tool")
	t.Name = "Click TP"
	t.ToolTip = "Equip, then click/tap anywhere to teleport"
	t.RequiresHandle = false
	t.CanBeDropped = false
	t.Activated:Connect(function()
		if not tpEnabled then return end
		Mouse.TargetFilter = LP.Character
		if not Mouse.Target then return end
		smoothTeleport(Mouse.Hit.Position)
	end)
	tpTool = t
	t.Parent = LP:FindFirstChildOfClass("Backpack") or LP:WaitForChild("Backpack")
end

local function setTP(on)
	tpEnabled = on
	if on then
		giveTool()
		say("Click TP ON: equip the tool, then click/tap the ground.")
	else
		removeTool()
		cancelTeleport()
		say("Click TP OFF")
	end
end

track(LP.CharacterAdded:Connect(function()
	if tpEnabled then
		task.wait(0.5)
		removeTool()
		giveTool()
	end
end))

---------------------------------------------------------------- Superman Fly
local flyEnabled = false
local flySpeed = 60
local FLY_MIN, FLY_MAX = 10, 250
local flyConn, flyObjs
local upHeld, downHeld = false, false
local flyJoints, flyCape, flyAnim, windTrail
local flyPose = 0
local lastFlat = Vector3.new(0, 0, -1)

local JOINT_NAMES = {
	rs = {"RightShoulder", "Right Shoulder"},
	ls = {"LeftShoulder", "Left Shoulder"},
	rh = {"RightHip", "Right Hip"},
	lh = {"LeftHip", "Left Hip"},
	neck = {"Neck"},
}

local function grabJoints(char)
	local j = {}
	for key, names in pairs(JOINT_NAMES) do
		for _, n in ipairs(names) do
			local m = char:FindFirstChild(n, true)
			if m and m:IsA("Motor6D") then
				j[key] = {m = m, c0 = m.C0}
				break
			end
		end
	end
	return j
end

local function applyPose(j, p, t)
	local sway = math.sin(t * 2.2) * 0.04
	local function set(key, rot)
		local e = j[key]
		if e and e.m.Parent then
			e.m.C0 = CFrame.new(e.c0.Position) * rot * e.c0.Rotation
		end
	end
	set("rs", CFrame.Angles(math.rad(168) * p + sway * p, 0, 0))
	set("ls", CFrame.Angles(math.rad(-14) * p, 0, 0))
	set("rh", CFrame.Angles(math.rad(-10) * p, 0, 0))
	set("lh", CFrame.Angles(math.rad(-16) * p, 0, 0))
	set("neck", CFrame.Angles(math.rad(70) * p, 0, 0))
end

local SEG_LEN, SEG_COUNT = 1.15, 3
local function makeCape(char)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso then return nil end
	local top = torso.Name == "UpperTorso" and 0.72 or 0.9
	local cape = {segs = {}, welds = {}, top = top}
	local prev = torso
	for i = 1, SEG_COUNT do
		local seg = Instance.new("Part")
		seg.Name = "MiniPanelCape"
		seg.Size = Vector3.new(1.9, SEG_LEN, 0.12)
		seg.Color = Color3.fromRGB(200, 20, 30)
		seg.Material = Enum.Material.Fabric
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.Massless = true
		seg.CastShadow = false
		local w = Instance.new("Weld")
		w.Part0 = prev
		w.Part1 = seg
		w.C0 = i == 1 and CFrame.new(0, top, 0.55) or CFrame.new(0, -SEG_LEN / 2, 0)
		w.C1 = CFrame.new(0, SEG_LEN / 2, 0)
		w.Parent = seg
		seg.Parent = char
		cape.segs[i] = seg
		cape.welds[i] = w
		prev = seg
	end
	return cape
end

local function updateCape(cp, p, t)
	for i, w in ipairs(cp.welds) do
		local flutter = math.sin(t * 7 - i * 0.9) * (0.05 + 0.16 * p)
		local flare = -(0.05 + 0.22 * p) * (i == 1 and 1.5 or 0.7) + flutter
		local side = math.sin(t * 4.1 - i * 1.3) * 0.05 * (0.4 + p)
		if i == 1 then
			w.C0 = CFrame.new(0, cp.top, 0.55) * CFrame.Angles(flare, 0, side)
		else
			w.C0 = CFrame.new(0, -SEG_LEN / 2, 0) * CFrame.Angles(flare * 0.6, 0, side)
		end
	end
end

local function stopFly()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyObjs then
		for _, o in pairs(flyObjs) do pcall(function() o:Destroy() end) end
		flyObjs = nil
	end
	windTrail = nil
	if flyJoints then
		for _, e in pairs(flyJoints) do
			if e.m.Parent then e.m.C0 = e.c0 end
		end
		flyJoints = nil
	end
	if flyCape then
		for _, s in ipairs(flyCape.segs) do pcall(function() s:Destroy() end) end
		flyCape = nil
	end
	if flyAnim then
		pcall(function() flyAnim.Disabled = false end)
		flyAnim = nil
	end
	flyPose = 0
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum then hum.PlatformStand = false end
	if root and not root.Anchored then root.AssemblyLinearVelocity = Vector3.zero end
	flyVel = Vector3.zero
end

local function startFly()
	stopFly()
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return false end

	local att = Instance.new("Attachment")
	att.Name = "FlyAttachment"
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = att
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.MaxTorque = math.huge
	ao.Responsiveness = 28
	ao.CFrame = root.CFrame.Rotation
	ao.Parent = root

	-- wind ribbon (shows when you're going fast)
	local wa0 = Instance.new("Attachment")
	wa0.Position = Vector3.new(1.3, 0, 0)
	wa0.Parent = root
	local wa1 = Instance.new("Attachment")
	wa1.Position = Vector3.new(-1.3, 0, 0)
	wa1.Parent = root
	local wt = Instance.new("Trail")
	wt.Attachment0, wt.Attachment1 = wa0, wa1
	wt.Lifetime = 0.35
	wt.MinLength = 0
	wt.LightEmission = 0.35
	wt.FaceCamera = false
	wt.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	wt.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
	wt.Enabled = false
	wt.Parent = root
	windTrail = wt

	flyObjs = {att, lv, ao, wa0, wa1, wt}
	flyVel = root.AssemblyLinearVelocity
	hum.PlatformStand = true

	flyJoints = grabJoints(char)
	flyCape = makeCape(char)
	local animate = char:FindFirstChild("Animate")
	if animate then
		local ok = pcall(function() animate.Disabled = true end)
		if ok then flyAnim = animate end
	end
	flyPose = 0

	flyConn = RunService.RenderStepped:Connect(function(dt)
		if not (root.Parent and hum.Parent and hum.Health > 0) then return end
		if root.Anchored then return end
		local cam = workspace.CurrentCamera
		if not cam then return end
		local cf = cam.CFrame
		local look, right = cf.LookVector, cf.RightVector

		local x, z, y = 0, 0, 0
		if not UIS:GetFocusedTextBox() then
			local function k(code) return UIS:IsKeyDown(code) and 1 or 0 end
			x = k(Enum.KeyCode.D) - k(Enum.KeyCode.A)
			z = k(Enum.KeyCode.W) - k(Enum.KeyCode.S)
			y = math.max(k(Enum.KeyCode.Space), k(Enum.KeyCode.E)) - math.max(k(Enum.KeyCode.LeftControl), k(Enum.KeyCode.Q))
		end
		if upHeld then y = 1 elseif downHeld then y = -1 end

		if x == 0 and z == 0 then
			local md = hum.MoveDirection
			if md.Magnitude > 0.05 then
				local flatLook = Vector3.new(look.X, 0, look.Z)
				local flatRight = Vector3.new(right.X, 0, right.Z)
				if flatLook.Magnitude > 0.01 and flatRight.Magnitude > 0.01 then
					z = md:Dot(flatLook.Unit)
					x = md:Dot(flatRight.Unit)
				end
			end
		end

		local dir = right * x + look * z + Vector3.new(0, y, 0)
		if dir.Magnitude > 1 then dir = dir.Unit end

		flyVel = flyVel:Lerp(dir * flySpeed, 1 - math.exp(-dt * 7))
		lv.VectorVelocity = flyVel
		local speed = flyVel.Magnitude

		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.02 then
			flat = flat.Unit
			lastFlat = flat
		else
			flat = lastFlat
		end

		-- Superman pose weight: needs speed and mostly-forward movement
		local fwd = speed > 1 and flyVel.Unit:Dot(look) or 0
		local pTarget = math.clamp((speed - 6) / 18, 0, 1) * math.clamp((fwd + 0.15) / 0.45, 0, 1)
		flyPose += (pTarget - flyPose) * (1 - math.exp(-dt * 5))

		-- body orientation: upright facing the camera, blending into prone with head leading
		local goal = CFrame.lookAt(Vector3.zero, flat)
		if flyPose > 0.02 and speed > 1 then
			local dirV = flyVel.Unit
			local A = Vector3.yAxis - dirV * Vector3.yAxis:Dot(dirV)
			local nf = -flat
			local B = nf - dirV * nf:Dot(dirV)
			local perp = A + B
			if perp.Magnitude > 0.05 then
				perp = perp.Unit
				local prone = CFrame.fromMatrix(Vector3.zero, dirV:Cross(perp), dirV, perp)
				goal = goal:Lerp(prone, flyPose)
			end
		end
		ao.CFrame = goal

		-- keep default animations off, drive the pose + cape
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do tr:Stop(0.1) end
		end
		local tnow = os.clock()
		if flyJoints then applyPose(flyJoints, flyPose, tnow) end
		if flyCape then updateCape(flyCape, flyPose, tnow) end
		if windTrail then windTrail.Enabled = speed > 32 end
	end)
	return true
end

local setFlyToggle
local function setFly(on)
	flyEnabled = on
	if on then
		if startFly() then
			say("Fly ON: WASD + Space/Ctrl (or E/Q). Fly forward for the Superman pose.")
		else
			flyEnabled = false
			say("No character to fly with yet.")
			task.defer(function() if setFlyToggle then setFlyToggle(false) end end)
		end
	else
		stopFly()
		say("Fly OFF")
	end
end

track(LP.CharacterAdded:Connect(function()
	if flyEnabled then
		task.wait(0.6)
		if flyEnabled then startFly() end
	end
end))

---------------------------------------------------------------- Laser Eyes (client-sided)
local LASER_ID = ""        -- optional: paste your own laser loop, e.g. "rbxassetid://123456789"
local LASER_RANGE = 450
local MAX_ROCKS, MAX_SCORCH = 150, 70

local laserEnabled = false
local laserTool
local firing = false
local laserConn
local laserCharge = 0
local laserState

local fxFolder = Instance.new("Folder")
fxFolder.Name = "MiniPanelFX"
fxFolder.Parent = workspace

local rocks, scorches = {}, {}

local function surfaceCF(pos, n)
	local ref = math.abs(n.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local x = ref:Cross(n).Unit
	return CFrame.fromMatrix(pos, x, n)
end

local function surfaceLook(res)
	local inst, mat = res.Instance, res.Material
	local col = Color3.fromRGB(110, 100, 90)
	if inst then
		if inst:IsA("Terrain") then
			local ok, c = pcall(function() return workspace.Terrain:GetMaterialColor(mat) end)
			if ok and c then col = c end
		elseif inst:IsA("BasePart") then
			col = inst.Color
			mat = inst.Material
		end
	end
	if mat == Enum.Material.Water or mat == Enum.Material.Air or mat == Enum.Material.Neon
		or mat == Enum.Material.Glass or mat == Enum.Material.ForceField then
		mat = Enum.Material.Slate
	end
	return col, mat
end

local function spawnRock(pos, n, col, mat, big)
	local k = rng:NextNumber()
	local s = (0.22 + k * k * 1.0) * (big and 1.8 or 1)
	local r = Instance.new(rng:NextNumber() < 0.35 and "WedgePart" or "Part")
	r.Size = Vector3.new(s * rng:NextNumber(0.7, 1.5), s * rng:NextNumber(0.6, 1.2), s * rng:NextNumber(0.7, 1.5))
	local shade = rng:NextNumber(0.65, 1.15)
	r.Color = Color3.new(math.clamp(col.R * shade, 0, 1), math.clamp(col.G * shade, 0, 1), math.clamp(col.B * shade, 0, 1))
	r.Material = mat
	r.TopSurface = Enum.SurfaceType.Smooth
	r.BottomSurface = Enum.SurfaceType.Smooth
	r.CanQuery = false
	r.CanTouch = false
	r.CastShadow = false
	r.CustomPhysicalProperties = PhysicalProperties.new(2, 0.6, 0.25)
	r.CFrame = CFrame.new(pos + n * 0.35 + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6)))
		* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
	r.Parent = fxFolder
	local lateral = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * rng:NextNumber(10, 38)
	r.AssemblyLinearVelocity = n * rng:NextNumber(26, 80) + lateral
	r.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(-18, 18), rng:NextNumber(-18, 18))
	table.insert(rocks, r)
	if #rocks > MAX_ROCKS then
		local old = table.remove(rocks, 1)
		if old then old:Destroy() end
	end
	task.delay(rng:NextNumber(2.2, 4.2), function()
		if r.Parent then
			tween(r, 0.6, {Transparency = 1}, Enum.EasingStyle.Quad)
			Debris:AddItem(r, 0.7)
		end
	end)
end

local function spawnScorch(pos, n, big)
	local d = rng:NextNumber(1.6, 3.2) * (big and 1.5 or 1)
	local function disc(color, mat, trans, size, offset)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = mat
		p.Color = color
		p.Transparency = trans
		p.Size = Vector3.new(0.06, size, size)
		p.CFrame = surfaceCF(pos + n * offset, n) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = fxFolder
		return p
	end
	local burn = disc(Color3.fromRGB(18, 14, 12), Enum.Material.SmoothPlastic, 0.2, d, 0.035)
	local glow = disc(Color3.fromRGB(255, 120, 30), Enum.Material.Neon, 0.1, d * 0.8, 0.05)
	tween(glow, 1.4, {Transparency = 1, Color = Color3.fromRGB(120, 20, 5), Size = Vector3.new(0.06, d * 0.6, d * 0.6)}, Enum.EasingStyle.Quad)
	Debris:AddItem(glow, 1.5)
	table.insert(scorches, burn)
	if #scorches > MAX_SCORCH then
		local old = table.remove(scorches, 1)
		if old then old:Destroy() end
	end
	task.delay(5, function()
		if burn.Parent then
			tween(burn, 1.5, {Transparency = 1})
			Debris:AddItem(burn, 1.6)
		end
	end)
end

local function newGlowPart(color, trans)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = trans
	p.Size = Vector3.new(0.1, 0.1, 0.1)
	p.Parent = fxFolder
	return p
end

local function makeLoop(speed, dist)
	local s = Instance.new("Sound")
	s.Looped = true
	s.Volume = 0
	if LASER_ID ~= "" then
		s.SoundId = LASER_ID
		s.PlaybackSpeed = 1
	else
		s.SoundId = PING
		s.PlaybackSpeed = speed
	end
	local d = Instance.new("DistortionSoundEffect")
	d.Level = dist
	d.Parent = s
	s.Parent = gui
	s:Play()
	return s
end

local function startLaserFx()
	local st = {beams = {}, em = {}, snds = {}, debrisT = 0, scorchT = 0, bigT = 0, dwell = 0}

	for i = 1, 2 do
		local b = {
			glow = newGlowPart(Color3.fromRGB(255, 10, 10), 0.72),
			mid = newGlowPart(Color3.fromRGB(255, 60, 40), 0.2),
			core = newGlowPart(Color3.fromRGB(255, 235, 225), 0),
			flare = newGlowPart(Color3.fromRGB(255, 40, 30), 0.15),
		}
		b.flare.Shape = Enum.PartType.Ball
		st.beams[i] = b
	end

	local hp = Instance.new("Part")
	hp.Anchored = true
	hp.CanCollide = false
	hp.CanQuery = false
	hp.CanTouch = false
	hp.Transparency = 1
	hp.Size = Vector3.new(0.4, 0.4, 0.4)
	hp.Parent = fxFolder
	st.hp = hp

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 60, 40)
	light.Range = 18
	light.Brightness = 3
	light.Parent = hp
	st.light = light

	local ball = newGlowPart(Color3.fromRGB(255, 120, 60), 0.2)
	ball.Shape = Enum.PartType.Ball
	st.glowBall = ball

	local function emitter(cfg)
		local e = Instance.new("ParticleEmitter")
		e.Texture = cfg.tex
		e.Color = cfg.color
		e.LightEmission = cfg.light
		e.Size = cfg.size
		e.Transparency = cfg.trans
		e.Lifetime = cfg.life
		e.Rate = cfg.rate
		e.Speed = cfg.speed
		e.SpreadAngle = cfg.spread
		e.Acceleration = cfg.acc
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = Enum.NormalId.Top
		e.Enabled = false
		e.Parent = hp
		return e
	end

	local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	st.em.sparks = emitter({tex = SPARK, color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 80, 20)),
		light = 1, size = NumberSequence.new(0.35, 0), trans = NumberSequence.new(0, 1), life = NumberRange.new(0.25, 0.6),
		rate = 90, speed = NumberRange.new(18, 45), spread = Vector2.new(75, 75), acc = Vector3.new(0, -70, 0)})
	st.em.embers = emitter({tex = SPARK, color = ColorSequence.new(Color3.fromRGB(255, 170, 60)),
		light = 1, size = NumberSequence.new(0.18, 0), trans = NumberSequence.new(0, 1), life = NumberRange.new(0.8, 1.6),
		rate = 26, speed = NumberRange.new(6, 16), spread = Vector2.new(80, 80), acc = Vector3.new(0, 6, 0)})
	st.em.smoke = emitter({tex = SMOKE, color = ColorSequence.new(Color3.fromRGB(90, 85, 80)),
		light = 0, size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.6)}),
		trans = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)}),
		life = NumberRange.new(0.9, 1.7), rate = 22, speed = NumberRange.new(3, 9), spread = Vector2.new(35, 35), acc = Vector3.new(0, 5, 0)})
	st.em.dust = emitter({tex = SMOKE, color = ColorSequence.new(Color3.fromRGB(150, 140, 125)),
		light = 0, size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4)}),
		trans = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1)}),
		life = NumberRange.new(0.8, 1.4), rate = 30, speed = NumberRange.new(6, 14), spread = Vector2.new(60, 60), acc = Vector3.new(0, 2, 0)})

	table.insert(st.snds, makeLoop(0.55, 0.6))
	if LASER_ID == "" then table.insert(st.snds, makeLoop(1.4, 0.4)) end
	return st
end

local function stopLaserFx()
	local st = laserState
	laserState = nil
	if laserConn then laserConn:Disconnect() laserConn = nil end
	laserCharge = 0
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = Vector3.zero
		hum.AutoRotate = true
	end
	if not st then return end
	for _, b in ipairs(st.beams) do
		for _, p in pairs(b) do p:Destroy() end
	end
	st.glowBall:Destroy()
	for _, e in pairs(st.em) do e.Enabled = false end
	st.light.Enabled = false
	Debris:AddItem(st.hp, 1.8)
	for _, s in ipairs(st.snds) do
		tween(s, 0.15, {Volume = 0})
		Debris:AddItem(s, 0.25)
	end
	sfx(PING, 0.7, 0.3)
end

local function laserStep(dt)
	local st = laserState
	if not st then return end
	local char = LP.Character
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (head and hum and root) then
		stopLaserFx()
		return
	end
	if hum.Health <= 0 then firing = false end

	if firing then
		laserCharge = math.min(1, laserCharge + dt / 0.14)
	else
		laserCharge = math.max(0, laserCharge - dt / 0.12)
		if laserCharge <= 0 then
			stopLaserFx()
			return
		end
	end
	local c = laserCharge
	local t = os.clock()

	-- aim from the mouse/touch point
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(Mouse.X, Mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, fxFolder}
	params.IgnoreWater = true
	local aimRes = workspace:Raycast(ray.Origin, ray.Direction * LASER_RANGE, params)
	local aimPos = aimRes and aimRes.Position or (ray.Origin + ray.Direction * LASER_RANGE)

	local eyeL = head.CFrame * Vector3.new(-0.2, 0.12, -0.52)
	local eyeR = head.CFrame * Vector3.new(0.2, 0.12, -0.52)
	local mid = (eyeL + eyeR) / 2
	local dir = aimPos - mid
	if dir.Magnitude < 0.5 then dir = head.CFrame.LookVector end
	dir = dir.Unit

	local res = workspace:Raycast(mid, dir * LASER_RANGE, params)
	local hitPos = res and res.Position or (mid + dir * LASER_RANGE)
	local normal = res and res.Normal or -dir

	-- beams (two eyes converging on the hit point)
	local eyes = {eyeL, eyeR}
	for i = 1, 2 do
		local b = st.beams[i]
		local from = eyes[i]
		local dist = (hitPos - from).Magnitude
		if dist > 0.1 then
			local cf = CFrame.lookAt(from, hitPos) * CFrame.new(0, 0, -dist / 2)
			local pulse = 1 + math.sin(t * 70 + i) * 0.1 + rng:NextNumber(-0.05, 0.05)
			local w = math.max(c * pulse, 0.02)
			b.glow.Size = Vector3.new(0.55 * w, 0.55 * w, dist)
			b.mid.Size = Vector3.new(0.2 * w, 0.2 * w, dist)
			b.core.Size = Vector3.new(0.07 * w, 0.07 * w, dist)
			b.glow.CFrame = cf
			b.mid.CFrame = cf
			b.core.CFrame = cf
		end
		local f = math.max(0.42 * c * (1 + math.sin(t * 50) * 0.15), 0.02)
		b.flare.Size = Vector3.new(f, f, f)
		b.flare.CFrame = CFrame.new(from)
	end

	-- impact
	local hitValid = res ~= nil
	local isChar = false
	if res then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		isChar = m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
	end
	st.hp.CFrame = surfaceCF(hitPos + normal * 0.1, normal)
	st.glowBall.CFrame = CFrame.new(hitPos + normal * 0.15)
	local gs = math.max((1.0 + math.sin(t * 40) * 0.25 + rng:NextNumber(-0.15, 0.15)) * c * (hitValid and 1 or 0), 0.02)
	st.glowBall.Size = Vector3.new(gs, gs, gs)
	st.light.Enabled = hitValid
	st.light.Brightness = 3 * c * (0.85 + rng:NextNumber(0, 0.3))

	local on = firing and hitValid
	st.em.sparks.Enabled = on
	st.em.embers.Enabled = on
	st.em.smoke.Enabled = on and not isChar
	st.em.dust.Enabled = on and not isChar

	-- ground breaking: rocks, scorch + molten glow, bigger chunks if you linger
	if firing and hitValid and not isChar then
		local col, mat = surfaceLook(res)
		st.em.dust.Color = ColorSequence.new(col:Lerp(Color3.fromRGB(150, 140, 125), 0.35))

		local moved = st.lastHit and (hitPos - st.lastHit).Magnitude or 99
		st.lastHit = hitPos
		if moved < 2.5 * math.max(dt, 0.016) * 8 then
			st.dwell += dt
		else
			st.dwell = math.max(0, st.dwell - dt * 2)
		end

		st.debrisT += dt
		st.scorchT += dt
		local spawned = 0
		while st.debrisT >= 0.04 and spawned < 3 do
			st.debrisT -= 0.04
			spawned += 1
			for _ = 1, rng:NextInteger(1, 3) do spawnRock(hitPos, normal, col, mat, false) end
		end
		if st.debrisT > 0.2 then st.debrisT = 0 end
		if st.dwell > 0.5 then
			st.bigT += dt
			if st.bigT >= 0.07 then
				st.bigT = 0
				spawnRock(hitPos, normal, col, mat, true)
			end
		end
		if st.scorchT >= 0.1 then
			st.scorchT = 0
			spawnScorch(hitPos, normal, st.dwell > 0.5)
		end
	else
		st.lastHit = nil
		st.dwell = 0
	end

	-- shake + face the target
	hum.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * 0.05 * c
	if not flyEnabled and not root.Anchored then
		hum.AutoRotate = false
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude > 0.05 then
			local goal = CFrame.lookAt(Vector3.zero, flatDir.Unit)
			root.CFrame = CFrame.new(root.Position) * root.CFrame.Rotation:Lerp(goal, 1 - math.exp(-dt * 16))
		end
	end

	-- laser hum (pitch wobble + charge-up)
	for i, s in ipairs(st.snds) do
		s.Volume = (i == 1 and 0.55 or 0.3) * c
		if LASER_ID == "" then
			local base = i == 1 and 0.55 or 1.4
			s.PlaybackSpeed = base * (0.8 + 0.2 * c) * (1 + math.sin(t * (i == 1 and 31 or 47)) * 0.12)
		end
	end
end

local function startLaser()
	if laserState then
		firing = true
		return
	end
	firing = true
	laserCharge = 0
	laserState = startLaserFx()
	sfx(PING, 2.0, 0.35)
	laserConn = RunService.RenderStepped:Connect(laserStep)
end

local function removeLaserTool()
	firing = false
	if laserTool then laserTool:Destroy() laserTool = nil end
end

local function giveLaserTool()
	if laserTool and laserTool.Parent then return end
	local t = Instance.new("Tool")
	t.Name = "Laser Eyes"
	t.ToolTip = "Equip, then hold left click / tap to fire"
	t.RequiresHandle = false
	t.CanBeDropped = false
	t.Activated:Connect(function()
		if laserEnabled then startLaser() end
	end)
	t.Deactivated:Connect(function() firing = false end)
	t.Unequipped:Connect(function() firing = false end)
	laserTool = t
	t.Parent = LP:FindFirstChildOfClass("Backpack") or LP:WaitForChild("Backpack")
end

local function setLaser(on)
	laserEnabled = on
	if on then
		giveLaserTool()
		say("Laser Eyes ON: equip the tool, then hold left click / tap.")
	else
		removeLaserTool()
		say("Laser Eyes OFF")
	end
end

track(LP.CharacterAdded:Connect(function()
	if laserEnabled then
		task.wait(0.5)
		removeLaserTool()
		giveLaserTool()
	end
end))

---------------------------------------------------------------- Rows, speed slider, command box
local setNoclipToggle = makeToggle("Noclip", 50, setNoclip)
local setTPToggle = makeToggle("Click TP Tool", 98, setTP)
local getFly
setFlyToggle, getFly = makeToggle("Fly", 146, setFly)
local setLaserToggle, getLaser = makeToggle("Laser Eyes Tool", 194, setLaser)

local sRow = Instance.new("Frame")
sRow.Size = UDim2.new(1, -28, 0, 40)
sRow.Position = UDim2.fromOffset(14, 242)
sRow.BackgroundColor3 = ROW
sRow.Parent = main
corner(sRow, 10)

local sLbl = Instance.new("TextLabel")
sLbl.Size = UDim2.new(1, -24, 0, 18)
sLbl.Position = UDim2.fromOffset(12, 4)
sLbl.BackgroundTransparency = 1
sLbl.Text = "Fly speed: " .. flySpeed
sLbl.Font = Enum.Font.GothamMedium
sLbl.TextSize = 12
sLbl.TextColor3 = Color3.fromRGB(200, 200, 215)
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.Parent = sRow

local sTrack = Instance.new("Frame")
sTrack.Size = UDim2.new(1, -24, 0, 6)
sTrack.Position = UDim2.fromOffset(12, 27)
sTrack.BackgroundColor3 = OFF
sTrack.Parent = sRow
corner(sTrack, 3)

local sFill = Instance.new("Frame")
sFill.BackgroundColor3 = ACCENT
sFill.Size = UDim2.fromScale((flySpeed - FLY_MIN) / (FLY_MAX - FLY_MIN), 1)
sFill.Parent = sTrack
corner(sFill, 3)

local sKnob = Instance.new("Frame")
sKnob.Size = UDim2.fromOffset(14, 14)
sKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sKnob.Position = UDim2.fromScale((flySpeed - FLY_MIN) / (FLY_MAX - FLY_MIN), 0.5)
sKnob.BackgroundColor3 = Color3.new(1, 1, 1)
sKnob.Parent = sTrack
corner(sKnob, 7)
local sKnobScale = Instance.new("UIScale", sKnob)

local sliding = false
local function slideTo(px)
	local a = math.clamp((px - sTrack.AbsolutePosition.X) / math.max(sTrack.AbsoluteSize.X, 1), 0, 1)
	flySpeed = math.floor(FLY_MIN + a * (FLY_MAX - FLY_MIN) + 0.5)
	sLbl.Text = "Fly speed: " .. flySpeed
	tween(sFill, 0.08, {Size = UDim2.fromScale(a, 1)}, Enum.EasingStyle.Quad)
	tween(sKnob, 0.08, {Position = UDim2.fromScale(a, 0.5)}, Enum.EasingStyle.Quad)
end

sRow.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		sliding = true
		tween(sKnobScale, 0.15, {Scale = 1.3}, Enum.EasingStyle.Back)
		slideTo(input.Position.X)
	end
end)
sRow.MouseEnter:Connect(function() tween(sRow, 0.2, {BackgroundColor3 = ROW_HOVER}) end)
sRow.MouseLeave:Connect(function() tween(sRow, 0.2, {BackgroundColor3 = ROW}) end)
track(UIS.InputChanged:Connect(function(input)
	if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		slideTo(input.Position.X)
	end
end))
track(UIS.InputEnded:Connect(function(input)
	if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		sliding = false
		tween(sKnobScale, 0.15, {Scale = 1}, Enum.EasingStyle.Back)
	end
end))

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -28, 0, 36)
box.Position = UDim2.fromOffset(14, 290)
box.BackgroundColor3 = ROW
box.PlaceholderText = "!to name  |  !hide name  |  !unhide name"
box.PlaceholderColor3 = Color3.fromRGB(130, 130, 150)
box.Text = ""
box.ClearTextOnFocus = false
box.Font = Enum.Font.Gotham
box.TextSize = 13
box.TextColor3 = Color3.new(1, 1, 1)
box.Parent = main
corner(box, 10)
local boxStroke = Instance.new("UIStroke", box)
boxStroke.Color = ACCENT
boxStroke.Transparency = 1
box.Focused:Connect(function() tween(boxStroke, 0.2, {Transparency = 0}) end)
box.FocusLost:Connect(function() tween(boxStroke, 0.2, {Transparency = 1}) end)
box.MouseEnter:Connect(function() tween(box, 0.2, {BackgroundColor3 = ROW_HOVER}) end)
box.MouseLeave:Connect(function() tween(box, 0.2, {BackgroundColor3 = ROW}) end)

---------------------------------------------------------------- Open / close
local isOpen, busy = false, false
local function setOpen(state)
	if busy or state == isOpen then return end
	busy = true
	isOpen = state
	if state then
		main.Visible = true
		tween(main, 0.35, {GroupTransparency = 0})
		tween(scale, 0.45, {Scale = 1}, Enum.EasingStyle.Back)
	else
		tween(main, 0.25, {GroupTransparency = 1})
		tween(scale, 0.3, {Scale = 0.6}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	task.delay(0.45, function()
		if not isOpen then main.Visible = false end
		busy = false
	end)
end

closeBtn.MouseButton1Click:Connect(function() sfx(CLICK_ID, 0.9) setOpen(false) end)
track(UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.K then
		sfx(CLICK_ID, isOpen and 0.85 or 1.1)
		setOpen(not isOpen)
	elseif input.KeyCode == Enum.KeyCode.F then
		local nextState = not getFly()
		sfx(TOGGLE_ID, nextState and 1.15 or 0.85)
		setFlyToggle(nextState)
	elseif input.KeyCode == Enum.KeyCode.L then
		local nextState = not getLaser()
		sfx(TOGGLE_ID, nextState and 1.15 or 0.85)
		setLaserToggle(nextState)
	end
end))

local fab = Instance.new("TextButton")
fab.Size = UDim2.fromOffset(38, 38)
fab.AnchorPoint = Vector2.new(0, 0.5)
fab.Position = UDim2.new(0, 12, 0.5, 0)
fab.BackgroundColor3 = BG
fab.Text = "K"
fab.Font = Enum.Font.GothamBold
fab.TextSize = 14
fab.TextColor3 = Color3.new(1, 1, 1)
fab.AutoButtonColor = false
fab.Parent = gui
corner(fab, 19)
local fabStroke = Instance.new("UIStroke", fab)
fabStroke.Color = ACCENT
fabStroke.Thickness = 1.5
hoverable(fab, BG, Color3.fromRGB(44, 40, 70))
fab.MouseButton1Click:Connect(function()
	sfx(CLICK_ID, isOpen and 0.85 or 1.1)
	setOpen(not isOpen)
end)

local function holdButton(text, yOffset, onHold)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(54, 54)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -16, 0.5, yOffset)
	b.BackgroundColor3 = BG
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.Visible = false
	b.Parent = gui
	corner(b, 27)
	local st = Instance.new("UIStroke", b)
	st.Color = ACCENT
	st.Thickness = 1.5
	local bs = Instance.new("UIScale", b)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onHold(true)
			tween(bs, 0.1, {Scale = 0.9})
			tween(b, 0.1, {BackgroundColor3 = ACCENT})
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onHold(false)
			tween(bs, 0.15, {Scale = 1}, Enum.EasingStyle.Back)
			tween(b, 0.15, {BackgroundColor3 = BG})
		end
	end)
	return b
end
local upBtn = holdButton("UP", -34, function(v) upHeld = v end)
local downBtn = holdButton("DOWN", 34, function(v) downHeld = v end)
track(RunService.Heartbeat:Connect(function()
	local show = flyEnabled and UIS.TouchEnabled
	upBtn.Visible = show
	downBtn.Visible = show
end))

track(RunService.Heartbeat:Connect(function(dt)
	if isOpen then grad.Rotation = (grad.Rotation + dt * 70) % 360 end
end))

---------------------------------------------------------------- Dragging
local dragging, dragStart, startPos, dragInput
handle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		tween(stroke, 0.2, {Thickness = 2.5})
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				tween(stroke, 0.2, {Thickness = 1.5})
			end
		end)
	end
end)
handle.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
track(UIS.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local d = input.Position - dragStart
		tween(main, 0.08, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)}, Enum.EasingStyle.Quad)
	end
end))

---------------------------------------------------------------- Name matching
local function findPlayer(query)
	query = (query or ""):lower()
	if query == "" then return nil, "Type a name." end
	local tiers = {{}, {}, {}}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local n, d = p.Name:lower(), p.DisplayName:lower()
			if n == query or d == query then
				table.insert(tiers[1], p)
			elseif n:sub(1, #query) == query or d:sub(1, #query) == query then
				table.insert(tiers[2], p)
			elseif n:find(query, 1, true) or d:find(query, 1, true) then
				table.insert(tiers[3], p)
			end
		end
	end
	for _, list in ipairs(tiers) do
		if #list == 1 then return list[1] end
		if #list > 1 then
			local names = {}
			for _, p in ipairs(list) do table.insert(names, p.Name) end
			return nil, "Multiple matches: " .. table.concat(names, ", ") .. " - type more letters."
		end
	end
	return nil, "No player found for '" .. query .. "'."
end

---------------------------------------------------------------- !hide
local hidden = {}
local origVolume = setmetatable({}, {__mode = "k"})
local origDisplay = setmetatable({}, {__mode = "k"})

local function applyHide(plr)
	local char = plr.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif d:IsA("Sound") then
				if origVolume[d] == nil then origVolume[d] = d.Volume end
				d.Volume = 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			elseif d:IsA("Humanoid") then
				if origDisplay[d] == nil then origDisplay[d] = d.DisplayDistanceType end
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end
	pcall(function()
		for _, d in ipairs(plr:GetDescendants()) do
			if d:IsA("AudioDeviceInput") then d.Muted = true end
		end
	end)
end

local function applyUnhide(plr)
	local char = plr.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			elseif d:IsA("Decal") or d:IsA("Texture") then
				if d.Name == "face" then d.Transparency = 0 end
			elseif d:IsA("Sound") then
				d.Volume = origVolume[d] or 0.5
			elseif d:IsA("BillboardGui") then
				d.Enabled = true
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = origDisplay[d] or Enum.HumanoidDisplayDistanceType.Viewer
			end
		end
	end
	pcall(function()
		for _, d in ipairs(plr:GetDescendants()) do
			if d:IsA("AudioDeviceInput") then d.Muted = false end
		end
	end)
end

task.spawn(function()
	while gui.Parent do
		for id in pairs(hidden) do
			local plr = Players:GetPlayerByUserId(id)
			if plr then applyHide(plr) else hidden[id] = nil end
		end
		task.wait(0.4)
	end
end)

pcall(function()
	TextChatService.OnIncomingMessage = function(msg)
		local props = Instance.new("TextChatMessageProperties")
		local src = msg.TextSource
		if src and (hidden[src.UserId] or (src.UserId == LP.UserId and msg.Text:sub(1, 1) == "!")) then
			props.Text = ""
		end
		return props
	end
end)

---------------------------------------------------------------- Commands
local lastRun, lastText = 0, ""
local function runCommand(text)
	text = ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if text:sub(1, 1) ~= "!" then return end
	if text == lastText and tick() - lastRun < 0.4 then return end
	lastText, lastRun = text, tick()

	local cmd, arg = text:match("^!(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "to" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		local theirRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if myRoot and theirRoot then
			myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
			say("Teleported to " .. plr.Name)
		else
			say(plr.Name .. " has no character yet.")
		end
	elseif cmd == "hide" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		hidden[plr.UserId] = true
		applyHide(plr)
		say("Hidden (body, name, sound, chat): " .. plr.Name)
	elseif cmd == "unhide" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		hidden[plr.UserId] = nil
		applyUnhide(plr)
		say("Unhidden: " .. plr.Name)
	else
		say("Unknown command. Try !to, !hide, !unhide.")
	end
end

box.FocusLost:Connect(function(enter)
	if enter then
		sfx(CLICK_ID, 1.2)
		runCommand(box.Text)
		box.Text = ""
	end
end)
pcall(function() track(TextChatService.SendingMessage:Connect(function(m) runCommand(m.Text) end)) end)
pcall(function() track(LP.Chatted:Connect(runCommand)) end)

---------------------------------------------------------------- Cleanup for re-execution
env.MiniPanelCleanup = function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(cancelTeleport)
	pcall(noclipOff)
	pcall(stopFly)
	pcall(removeLaserTool)
	pcall(stopLaserFx)
	pcall(function() fxFolder:Destroy() end)
	removeTool()
	pcall(function() dropTrail(true) end)
	pcall(function() tpBlur:Destroy() end)
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam and tpBaseFov then cam.FieldOfView = tpBaseFov end
	end)
	for id in pairs(hidden) do
		local plr = Players:GetPlayerByUserId(id)
		if plr then applyUnhide(plr) end
	end
	pcall(function() TextChatService.OnIncomingMessage = nil end)
	gui:Destroy()
end

setOpen(true)
]==])()
