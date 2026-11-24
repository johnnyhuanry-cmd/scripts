-- Mini Panel v2: draggable, animated, click sounds, noclip, Click TP tool, !to / !hide / !unhide
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- clean up any previous run
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

-- sounds (swap the IDs if you want different ones)
local CLICK_ID, TOGGLE_ID = "rbxassetid://421058925", "rbxassetid://6895079853"
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
main.Size = UDim2.fromOffset(300, 270)
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

-- title bar (drag handle)
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

-- output label
local out = Instance.new("TextLabel")
out.Size = UDim2.new(1, -28, 0, 64)
out.Position = UDim2.fromOffset(14, 194)
out.BackgroundTransparency = 1
out.Text = "K = open/close  |  drag the title to move"
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

-- toggle row builder
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
	return set
end

---------------------------------------------------------------- Noclip (fixed: restores collisions when off)
local noclipConn
local touched = {} -- parts we turned non-collidable (they were collidable before)

local function setNoclip(on)
	if noclipConn then noclipConn:Disconnect() noclipConn = nil end
	if on then
		noclipConn = RunService.Stepped:Connect(function()
			local char = LP.Character
			if not char then return end
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then
					touched[p] = true
					p.CanCollide = false
				end
			end
		end)
		say("Noclip ON")
	else
		for p in pairs(touched) do
			if p.Parent then p.CanCollide = true end
		end
		table.clear(touched)
		say("Noclip OFF")
	end
end

---------------------------------------------------------------- Click TP tool
local tpEnabled = false
local tpTool, tpTween

local function smoothTeleport(pos)
	local char = LP.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local lift = (hum and hum.HipHeight or 2) + root.Size.Y / 2 + 0.5
	local dist = (root.Position - pos).Magnitude
	local t = math.clamp(dist / 250, 0.25, 1.1)
	local rotation = root.CFrame - root.CFrame.Position
	local target = CFrame.new(pos + Vector3.new(0, lift, 0)) * rotation

	if tpTween then tpTween:Cancel() end
	root.Anchored = true
	local tw = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {CFrame = target})
	tpTween = tw
	tw.Completed:Connect(function()
		if tpTween ~= tw then return end
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)
	tw:Play()
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
		if not Mouse.Target then return end -- clicked the sky
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
		if tpTween then tpTween:Cancel() end
		local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = false end
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

---------------------------------------------------------------- Rows + command box
local setNoclipToggle = makeToggle("Noclip", 50, setNoclip)
local setTPToggle = makeToggle("Click TP Tool", 98, setTP)

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -28, 0, 36)
box.Position = UDim2.fromOffset(14, 148)
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
	end
end))

-- floating button (handy on mobile where there's no K key)
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

-- animated border
track(RunService.Heartbeat:Connect(function(dt)
	if isOpen then grad.Rotation = (grad.Rotation + dt * 70) % 360 end
end))

---------------------------------------------------------------- Dragging (mouse + touch)
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

---------------------------------------------------------------- Name matching (exact > starts with > contains)
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

---------------------------------------------------------------- !hide (client-side only)
local hidden = {}      -- [UserId] = true
local origVolume = setmetatable({}, {__mode = "k"})

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
		say("Hidden + muted: " .. plr.Name)
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
	if noclipConn then noclipConn:Disconnect() end
	for p in pairs(touched) do if p.Parent then p.CanCollide = true end end
	removeTool()
	for id in pairs(hidden) do
		local plr = Players:GetPlayerByUserId(id)
		if plr then applyUnhide(plr) end
	end
	pcall(function() TextChatService.OnIncomingMessage = nil end)
	gui:Destroy()
end

setOpen(true) -- smooth open on execute
