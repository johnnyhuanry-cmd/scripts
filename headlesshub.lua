-- Mini Panel: K toggles, noclip switch, !to / !hide / !unhide
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local LP = Players.LocalPlayer

local parent = (gethui and gethui()) or (pcall(function() return game.CoreGui end) and game.CoreGui) or LP:WaitForChild("PlayerGui")
if parent:FindFirstChild("MiniPanel") then parent.MiniPanel:Destroy() end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(o, r) local c = Instance.new("UICorner", o) c.CornerRadius = UDim.new(0, r) return c end

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "MiniPanel"
gui.ResetOnSpawn = false
gui.Parent = parent

local main = Instance.new("CanvasGroup")
main.Size = UDim2.fromOffset(300, 230)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
main.GroupTransparency = 1
main.Visible = false
main.Parent = gui
corner(main, 14)

local scale = Instance.new("UIScale", main)
scale.Scale = 0.6

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(120, 90, 255)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 36)
title.Position = UDim2.fromOffset(14, 4)
title.BackgroundTransparency = 1
title.Text = "Mini Panel"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local function hoverable(btn, normal, hover)
	local s = Instance.new("UIScale", btn)
	btn.MouseEnter:Connect(function()
		tween(btn, 0.2, {BackgroundColor3 = hover})
		tween(s, 0.2, {Scale = 1.06}, Enum.EasingStyle.Back)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.2, {BackgroundColor3 = normal})
		tween(s, 0.2, {Scale = 1})
	end)
	btn.MouseButton1Down:Connect(function() tween(s, 0.1, {Scale = 0.94}) end)
	btn.MouseButton1Up:Connect(function() tween(s, 0.15, {Scale = 1.06}, Enum.EasingStyle.Back) end)
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

-- Noclip row
local row = Instance.new("Frame")
row.Size = UDim2.new(1, -28, 0, 40)
row.Position = UDim2.fromOffset(14, 48)
row.BackgroundColor3 = Color3.fromRGB(34, 34, 46)
row.Parent = main
corner(row, 10)

local rowLabel = Instance.new("TextLabel")
rowLabel.Size = UDim2.new(1, -80, 1, 0)
rowLabel.Position = UDim2.fromOffset(12, 0)
rowLabel.BackgroundTransparency = 1
rowLabel.Text = "Noclip"
rowLabel.Font = Enum.Font.GothamMedium
rowLabel.TextSize = 14
rowLabel.TextColor3 = Color3.new(1, 1, 1)
rowLabel.TextXAlignment = Enum.TextXAlignment.Left
rowLabel.Parent = row

local sw = Instance.new("TextButton")
sw.Size = UDim2.fromOffset(46, 24)
sw.Position = UDim2.new(1, -58, 0.5, -12)
sw.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
sw.Text = ""
sw.AutoButtonColor = false
sw.Parent = row
corner(sw, 12)

local knob = Instance.new("Frame")
knob.Size = UDim2.fromOffset(18, 18)
knob.Position = UDim2.fromOffset(3, 3)
knob.BackgroundColor3 = Color3.new(1, 1, 1)
knob.Parent = sw
corner(knob, 9)

local swScale = Instance.new("UIScale", sw)
sw.MouseEnter:Connect(function() tween(swScale, 0.2, {Scale = 1.08}, Enum.EasingStyle.Back) end)
sw.MouseLeave:Connect(function() tween(swScale, 0.2, {Scale = 1}) end)

-- Command box
local box = Instance.new("TextBox")
box.Size = UDim2.new(1, -28, 0, 36)
box.Position = UDim2.fromOffset(14, 100)
box.BackgroundColor3 = Color3.fromRGB(34, 34, 46)
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
boxStroke.Color = Color3.fromRGB(120, 90, 255)
boxStroke.Transparency = 1
box.Focused:Connect(function() tween(boxStroke, 0.2, {Transparency = 0}) end)
box.FocusLost:Connect(function() tween(boxStroke, 0.2, {Transparency = 1}) end)
box.MouseEnter:Connect(function() tween(box, 0.2, {BackgroundColor3 = Color3.fromRGB(42, 42, 58)}) end)
box.MouseLeave:Connect(function() tween(box, 0.2, {BackgroundColor3 = Color3.fromRGB(34, 34, 46)}) end)

local out = Instance.new("TextLabel")
out.Size = UDim2.new(1, -28, 0, 60)
out.Position = UDim2.fromOffset(14, 146)
out.BackgroundTransparency = 1
out.Text = "K = open/close. Type a command and press Enter."
out.Font = Enum.Font.Gotham
out.TextSize = 12
out.TextWrapped = true
out.TextYAlignment = Enum.TextYAlignment.Top
out.TextXAlignment = Enum.TextXAlignment.Left
out.TextColor3 = Color3.fromRGB(170, 170, 190)
out.Parent = main
local function say(msg) out.Text = msg end

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

closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.K then setOpen(not isOpen) end
end)
setOpen(true) -- opens smoothly on execute

---------------------------------------------------------------- Noclip
local noclip = false
sw.MouseButton1Click:Connect(function()
	noclip = not noclip
	tween(knob, 0.25, {Position = noclip and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}, Enum.EasingStyle.Back)
	tween(sw, 0.25, {BackgroundColor3 = noclip and Color3.fromRGB(120, 90, 255) or Color3.fromRGB(70, 70, 90)})
end)
RunService.Stepped:Connect(function()
	if not noclip then return end
	local char = LP.Character
	if not char then return end
	for _, p in ipairs(char:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
end)

---------------------------------------------------------------- Name matching
-- exact > starts with > contains. Returns player, or nil + message.
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

---------------------------------------------------------------- !to
local function teleportTo(plr)
	local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local theirRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and theirRoot then
		myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
		return true
	end
	return false
end

---------------------------------------------------------------- !hide (client-side only)
local hidden = {} -- [UserId] = true

local function applyHide(plr)
	local char = plr.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif d:IsA("Sound") then
				d.Volume = 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = false
			end
		end
	end
	-- best-effort voice chat mute
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
				d.Volume = 0.5
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

-- keep hidden players hidden (respawns, new sounds, etc.)
task.spawn(function()
	while gui.Parent do
		for id in pairs(hidden) do
			local plr = Players:GetPlayerByUserId(id)
			if plr then applyHide(plr) else hidden[id] = nil end
		end
		task.wait(0.4)
	end
end)

-- hide chat from hidden players + hide your own "!" commands on your screen
pcall(function()
	TextChatService.OnIncomingMessage = function(msg)
		local props = Instance.new("TextChatMessageProperties")
		local src = msg.TextSource
		if src then
			if hidden[src.UserId] or (src.UserId == LP.UserId and msg.Text:sub(1, 1) == "!") then
				props.Text = ""
			end
		end
		return props
	end
end)

---------------------------------------------------------------- Command handler
local lastRun, lastText = 0, ""
local function runCommand(text)
	text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if text:sub(1, 1) ~= "!" then return end
	if text == lastText and tick() - lastRun < 0.4 then return end -- dedupe chat hooks
	lastText, lastRun = text, tick()

	local cmd, arg = text:match("^!(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()

	if cmd == "to" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		say(teleportTo(plr) and ("Teleported to " .. plr.Name) or (plr.Name .. " has no character yet."))
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

-- from the panel box
box.FocusLost:Connect(function(enter)
	if enter then
		runCommand(box.Text)
		box.Text = ""
	end
end)

-- from in-game chat (new + legacy chat)
pcall(function() TextChatService.SendingMessage:Connect(function(m) runCommand(m.Text) end) end)
pcall(function() LP.Chatted:Connect(runCommand) end)
