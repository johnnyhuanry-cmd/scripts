-- Headless Hub v9 (client-side only)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local env = (getgenv and getgenv()) or _G

-- Remove any previous copy
if env.HeadlessHubUnload then pcall(env.HeadlessHubUnload) end
pcall(function()
    for _, n in ipairs({ "HeadlessHub", "HeadlessHubTags" }) do
        local old = parentGui:FindFirstChild(n)
        if old then old:Destroy() end
    end
end)

--------------------------------------------------------------------
-- Fonts (change these to restyle everything)
--------------------------------------------------------------------
local FONT = Enum.Font.Ubuntu
local FONT_TITLE = Enum.Font.Oswald

--------------------------------------------------------------------
-- Config (saves if your executor supports writefile)
--------------------------------------------------------------------
local CONFIG_FILE = "HeadlessHub_v9.json"
local DEFAULTS = {
    headless = false, hideFace = true, hideAccessories = false,
    invisible = false, invisLevel = 0.8,
    speedOn = false, speed = 32,
    jumpOn = false, jump = 80,
    infJump = false,
    fovOn = false, fov = 90,
    fpsTags = false, tagRange = 250,
    accent = "Teal", scale = 1, opacity = 1,
    guiKey = "RightShift", headlessKey = "H",
}
local config = {}
for k, v in pairs(DEFAULTS) do config[k] = v end

pcall(function()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(data) do
            if DEFAULTS[k] ~= nil and type(v) == type(DEFAULTS[k]) then config[k] = v end
        end
    end
end)

local dirty, running = false, true
local function save() dirty = true end
task.spawn(function()
    while running do
        task.wait(2)
        if dirty and writefile then
            dirty = false
            pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end)
        end
    end
end)

--------------------------------------------------------------------
-- Theme / helpers
--------------------------------------------------------------------
local THEME = {
    bg = Color3.fromRGB(18, 18, 21),
    side = Color3.fromRGB(23, 23, 27),
    panel = Color3.fromRGB(31, 31, 36),
    hover = Color3.fromRGB(41, 41, 48),
    line = Color3.fromRGB(52, 52, 60),
    off = Color3.fromRGB(68, 68, 78),
    text = Color3.fromRGB(236, 236, 240),
    sub = Color3.fromRGB(138, 138, 150),
    good = Color3.fromRGB(90, 210, 120),
    warn = Color3.fromRGB(240, 190, 70),
    bad = Color3.fromRGB(235, 85, 85),
}

local ACCENT_LIST = {
    { "Teal", Color3.fromRGB(45, 190, 170) },
    { "Blue", Color3.fromRGB(80, 140, 255) },
    { "Orange", Color3.fromRGB(240, 140, 60) },
    { "Rose", Color3.fromRGB(235, 90, 110) },
    { "Lime", Color3.fromRGB(140, 200, 70) },
    { "Violet", Color3.fromRGB(150, 110, 240) },
}
local function accentByName(name)
    for _, a in ipairs(ACCENT_LIST) do if a[1] == name then return a[2] end end
    return ACCENT_LIST[1][2]
end

local accent = accentByName(config.accent)
local accentListeners = {}
local function onAccent(fn)
    table.insert(accentListeners, fn)
    fn()
end
local function setAccent(color)
    accent = color
    for _, fn in ipairs(accentListeners) do fn() end
end

local function new(class, props)
    local inst = Instance.new(class)
    local parent = props.Parent
    props.Parent = nil
    for k, v in pairs(props) do inst[k] = v end
    inst.Parent = parent
    return inst
end

local function corner(inst, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = inst })
end

local function tween(inst, time, props, style)
    local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local connections = {}
local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function keyFromName(name, fallback)
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    return (ok and key) or fallback
end
local keys = {
    gui = keyFromName(config.guiKey, Enum.KeyCode.RightShift),
    headless = keyFromName(config.headlessKey, Enum.KeyCode.H),
}

local visible, minimized = true, false
local fps = 0

--------------------------------------------------------------------
-- Character look: headless + invisible (local only)
--------------------------------------------------------------------
local orig = setmetatable({}, { __mode = "k" })
local HEAD_ATTACHMENTS = {
    HatAttachment = true, HairAttachment = true,
    FaceFrontAttachment = true, FaceCenterAttachment = true,
}

local function isHeadAccessory(acc)
    local handle = acc:FindFirstChild("Handle")
    if not handle then return false end
    for _, child in ipairs(handle:GetChildren()) do
        if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then return true end
    end
    return false
end

local function applyLook(forceOff)
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hideHead = (not forceOff) and config.headless
    local invisible = (not forceOff) and config.invisible
    local hideAcc = (not forceOff) and config.hideAccessories

    for _, d in ipairs(char:GetDescendants()) do
        local isPart = d:IsA("BasePart")
        if (isPart or d:IsA("Decal")) and d.Name ~= "HumanoidRootPart" then
            if orig[d] == nil then orig[d] = d.Transparency end
            local target = orig[d]
            if invisible then target = math.max(target, config.invisLevel) end
            if hideHead and head then
                if d == head then
                    target = 1
                elseif d.Parent == head and config.hideFace and d:IsA("Decal") then
                    target = 1
                end
            end
            if hideAcc and isPart and d.Name == "Handle" and d.Parent:IsA("Accessory") and isHeadAccessory(d.Parent) then
                target = 1
            end
            if d.Transparency ~= target then d.Transparency = target end
        end
    end
end

--------------------------------------------------------------------
-- Movement and camera
--------------------------------------------------------------------
local function getHum()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local cam = workspace.CurrentCamera
local origFov = cam and cam.FieldOfView or 70
local speedApplied, jumpApplied, fovApplied = false, false, false

connect(RunService.Stepped, function() applyLook(false) end)

connect(RunService.Heartbeat, function()
    local hum = getHum()
    if not hum then return end
    if config.speedOn then
        hum.WalkSpeed = config.speed
        speedApplied = true
    elseif speedApplied then
        hum.WalkSpeed = 16
        speedApplied = false
    end
    if config.jumpOn then
        hum.UseJumpPower = true
        hum.JumpPower = config.jump
        jumpApplied = true
    elseif jumpApplied then
        hum.JumpPower = 50
        jumpApplied = false
    end
end)

connect(RunService.RenderStepped, function()
    cam = workspace.CurrentCamera
    if not cam then return end
    if config.fovOn then
        cam.FieldOfView = config.fov
        fovApplied = true
    elseif fovApplied then
        cam.FieldOfView = origFov
        fovApplied = false
    end
end)

connect(UserInputService.JumpRequest, function()
    if config.infJump then
        local hum = getHum()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

--------------------------------------------------------------------
-- Player finding + teleport
--------------------------------------------------------------------
local function findPlayer(query)
    query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return nil end
    local list = Players:GetPlayers()
    table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)

    -- 1) exact display name or username
    for _, p in ipairs(list) do
        if p ~= player and (p.DisplayName:lower() == query or p.Name:lower() == query) then return p end
    end
    -- 2) display name starts with the text
    for _, p in ipairs(list) do
        if p ~= player and p.DisplayName:lower():sub(1, #query) == query then return p end
    end
    -- 3) username starts with the text
    for _, p in ipairs(list) do
        if p ~= player and p.Name:lower():sub(1, #query) == query then return p end
    end
    -- 4) text appears anywhere in either name
    for _, p in ipairs(list) do
        if p ~= player and (p.DisplayName:lower():find(query, 1, true) or p.Name:lower():find(query, 1, true)) then return p end
    end
    return nil
end

local notify -- defined with the GUI below

local function teleportToQuery(query)
    local target = findPlayer(query)
    if not target then
        notify("No player matches \"" .. query .. "\"")
        return
    end
    local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local theirRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if not (myRoot and theirRoot) then
        notify(target.DisplayName .. " has no character loaded")
        return
    end
    myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 1, 3)
    notify("Teleported to " .. target.DisplayName)
end

--------------------------------------------------------------------
-- Hide + mute players (local only)
--------------------------------------------------------------------
local hidden = {}
local hideOrig = setmetatable({}, { __mode = "k" })

local function applyHide(p, on)
    local char = p.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                if hideOrig[d] == nil then hideOrig[d] = d.Transparency end
                local target = on and 1 or hideOrig[d]
                if d.Transparency ~= target then d.Transparency = target end
            end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.DisplayDistanceType = on and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
        end
    end
    -- mute their voice input on your end
    for _, d in ipairs(p:GetDescendants()) do
        if d:IsA("AudioDeviceInput") then
            pcall(function() d.Muted = on end)
        end
    end
end

local function setHidden(p, on)
    if on then
        hidden[p] = true
        pcall(function() game:GetService("VoiceChatInternal"):SubscribeBlock(p.UserId) end)
    else
        hidden[p] = nil
        pcall(function() game:GetService("VoiceChatInternal"):SubscribeUnblock(p.UserId) end)
    end
    applyHide(p, on)
end

local function restoreHidden()
    for p in pairs(hidden) do applyHide(p, false) end
    hidden = {}
end

local hideTimer = 0
connect(RunService.Heartbeat, function(dt)
    hideTimer += dt
    if hideTimer < 0.15 then return end
    hideTimer = 0
    for p in pairs(hidden) do applyHide(p, true) end
end)
connect(Players.PlayerRemoving, function(p) hidden[p] = nil end)

local function hideCommand(query, on)
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query:lower() == "all" then
        local n = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then setHidden(p, on) n += 1 end
        end
        notify((on and "Hid " or "Showed ") .. n .. " players")
        return
    end
    local target = findPlayer(query)
    if not target then
        notify("No player matches \"" .. query .. "\"")
        return
    end
    setHidden(target, on)
    notify((on and "Hidden + muted: " or "Showed: ") .. target.DisplayName)
end

--------------------------------------------------------------------
-- Chat commands: !to, !hide, !unhide / !show
--------------------------------------------------------------------
local lastMsg, lastTime = "", 0
local function handleChat(msg)
    if type(msg) ~= "string" then return end
    local now = os.clock()
    if msg == lastMsg and now - lastTime < 0.5 then return end
    lastMsg, lastTime = msg, now

    local cmd, arg = msg:match("^%s*!(%a+)%s*(.-)%s*$")
    if not cmd then return end
    cmd = cmd:lower()

    if cmd == "to" then
        if arg ~= "" then teleportToQuery(arg) else notify("Usage: !to <name>") end
    elseif cmd == "hide" then
        if arg ~= "" then hideCommand(arg, true) else notify("Usage: !hide <name or all>") end
    elseif cmd == "unhide" or cmd == "show" then
        if arg ~= "" then hideCommand(arg, false) else notify("Usage: !unhide <name or all>") end
    end
end

connect(player.Chatted, handleChat)
pcall(function()
    connect(TextChatService.MessageReceived, function(m)
        if m.TextSource and m.TextSource.UserId == player.UserId then
            handleChat(m.Text)
        end
    end)
end)

--------------------------------------------------------------------
-- Player tags (FPS, distance, health)
--------------------------------------------------------------------
local tagFolder = new("Folder", { Name = "HeadlessHubTags", Parent = parentGui })
local tags = {}

local function fpsColor(v)
    if v >= 45 then return THEME.good elseif v >= 25 then return THEME.warn end
    return THEME.bad
end

local function removeTag(p)
    local t = tags[p]
    if t then
        pcall(function() t.gui:Destroy() end)
        tags[p] = nil
    end
end

local function clearTags()
    for p in pairs(tags) do removeTag(p) end
end

local function ensureTag(p)
    local char = p.Character
    local head = char and char:FindFirstChild("Head")
    local t = tags[p]
    if t and head and t.gui.Adornee == head and t.gui.Parent then return t end
    if t then removeTag(p) end
    if not head then return nil end

    local g = new("BillboardGui", {
        Name = "Tag_" .. p.UserId, Adornee = head, AlwaysOnTop = true,
        Size = UDim2.fromOffset(130, 50), StudsOffset = Vector3.new(0, 2.8, 0),
        MaxDistance = config.tagRange, LightInfluence = 0, Parent = tagFolder,
    })
    local bg = new("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = THEME.bg,
        BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = g,
    })
    corner(bg, 6)
    new("UIStroke", { Color = THEME.line, Thickness = 1, Parent = bg })
    local function line(y, size, color)
        return new("TextLabel", {
            Size = UDim2.new(1, -8, 0, 15), Position = UDim2.new(0, 4, 0, y), BackgroundTransparency = 1,
            Text = "", TextColor3 = color, Font = FONT, TextSize = size,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = bg,
        })
    end
    local nameL = line(2, 14, THEME.text)
    local fpsL = line(18, 13, THEME.sub)
    local infoL = line(33, 12, THEME.sub)
    t = { gui = g, nameL = nameL, fpsL = fpsL, infoL = infoL, last = nil, count = 0, est = nil }
    tags[p] = t
    return t
end

connect(Players.PlayerRemoving, removeTag)

local tagTimer = 0
connect(RunService.RenderStepped, function(dt)
    if not config.fpsTags then return end
    tagTimer += dt

    for p, t in pairs(tags) do
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local cf = root.CFrame
            if cf ~= t.last then
                t.count += 1
                t.last = cf
            end
        end
    end

    if tagTimer >= 1 then
        local elapsed = tagTimer
        tagTimer = 0
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        for p, t in pairs(tags) do
            t.nameL.Text = p.DisplayName
            local char = p.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            -- distance + health (real values)
            local dist = (myRoot and root) and math.floor((myRoot.Position - root.Position).Magnitude) or nil
            local hp = hum and math.floor(hum.Health) or nil
            t.infoL.Text = (dist and (dist .. " studs") or "-") .. "  |  " .. (hp and (hp .. " HP") or "-")

            -- FPS (exact only if the game publishes it)
            local exact = p:GetAttribute("FPS") or p:GetAttribute("Fps")
            if not exact then
                local ls = p:FindFirstChild("leaderstats")
                local v = ls and (ls:FindFirstChild("FPS") or ls:FindFirstChild("Fps"))
                exact = v and v.Value
            end

            if p == player then
                t.fpsL.Text = fps .. " FPS"
                t.fpsL.TextColor3 = fpsColor(fps)
            elseif exact and tonumber(exact) then
                t.fpsL.Text = math.floor(tonumber(exact)) .. " FPS"
                t.fpsL.TextColor3 = fpsColor(tonumber(exact))
            else
                if t.count >= 4 then
                    t.est = math.min(math.floor(t.count / elapsed + 0.5), 60)
                    t.fpsL.Text = "~" .. t.est .. " FPS (est)"
                    t.fpsL.TextColor3 = fpsColor(t.est)
                elseif t.est then
                    t.fpsL.Text = "idle (last ~" .. t.est .. ")"
                    t.fpsL.TextColor3 = THEME.sub
                else
                    t.fpsL.Text = "idle"
                    t.fpsL.TextColor3 = THEME.sub
                end
            end
            t.count = 0
        end
    end
end)

task.spawn(function()
    while running do
        task.wait(0.5)
        if config.fpsTags then
            for _, p in ipairs(Players:GetPlayers()) do ensureTag(p) end
        elseif next(tags) then
            clearTags()
        end
    end
end)

--------------------------------------------------------------------
-- Root GUI
--------------------------------------------------------------------
local WIN_W, WIN_H, HEADER_H = 520, 360, 44
local gui = new("ScreenGui", {
    Name = "HeadlessHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui,
})

local main = new("Frame", {
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    BackgroundColor3 = THEME.bg, BackgroundTransparency = 1 - config.opacity,
    BorderSizePixel = 0, ClipsDescendants = true, Active = true, Parent = gui,
})
corner(main, 8)
new("UIStroke", { Color = THEME.line, Thickness = 1, Parent = main })
local uiScale = new("UIScale", { Scale = 0, Parent = main })

-- Header
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = THEME.side,
    BorderSizePixel = 0, Parent = main,
})
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = THEME.line, BorderSizePixel = 0, Parent = header,
})
local dot = new("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 16, 0.5, -4), BorderSizePixel = 0, Parent = header,
})
corner(dot, 4)
onAccent(function() dot.BackgroundColor3 = accent end)
new("TextLabel", {
    Size = UDim2.new(0, 130, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1,
    Text = "Headless Hub", TextColor3 = THEME.text, Font = FONT_TITLE, TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
new("TextLabel", {
    Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(0, 142, 0, 2), BackgroundTransparency = 1,
    Text = "v9", TextColor3 = THEME.sub, Font = FONT, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})

local function headerButton(text, xOffset, hoverColor)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xOffset, 0.5, -13),
        BackgroundColor3 = THEME.panel, Text = text, TextColor3 = THEME.text,
        Font = FONT, TextSize = 16, AutoButtonColor = false, Parent = header,
    })
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundColor3 = hoverColor }) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundColor3 = THEME.panel }) end)
    return b
end
local minimizeBtn = headerButton("-", -68, THEME.hover)
local closeBtn = headerButton("x", -36, Color3.fromRGB(190, 60, 70))

-- Sidebar and content
local sidebar = new("Frame", {
    Size = UDim2.new(0, 128, 1, -HEADER_H), Position = UDim2.new(0, 0, 0, HEADER_H),
    BackgroundColor3 = THEME.side, BorderSizePixel = 0, Parent = main,
})
new("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = THEME.line, BorderSizePixel = 0, Parent = sidebar,
})
new("UIListLayout", { Padding = UDim.new(0, 4), Parent = sidebar })
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10), Parent = sidebar })
local content = new("Frame", {
    Size = UDim2.new(1, -128, 1, -HEADER_H), Position = UDim2.new(0, 128, 0, HEADER_H),
    BackgroundTransparency = 1, Parent = main,
})

-- FPS / ping readout
local statsLabel = new("TextLabel", {
    Size = UDim2.new(0, 108, 0, 32), Position = UDim2.new(0, 12, 1, -42),
    BackgroundTransparency = 1, Text = "FPS --\nPing --", TextColor3 = THEME.sub,
    Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = main,
})
local frames, last = 0, os.clock()
connect(RunService.RenderStepped, function()
    frames += 1
    local now = os.clock()
    if now - last >= 0.5 then
        fps = math.floor(frames / (now - last) + 0.5)
        local ping = "--"
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms" end)
        statsLabel.Text = "FPS " .. fps .. "\nPing " .. ping
        frames, last = 0, now
    end
end)

--------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------
local resetting = false
local notifHolder = new("Frame", {
    Size = UDim2.new(0, 270, 1, -20), Position = UDim2.new(1, -280, 0, 10),
    BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = notifHolder })

notify = function(text)
    if resetting then return end
    local n = new("Frame", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = THEME.panel,
        BackgroundTransparency = 1, BorderSizePixel = 0, Parent = notifHolder,
    })
    corner(n, 6)
    local strip = new("Frame", {
        Size = UDim2.new(0, 3, 1, -12), Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = n,
    })
    corner(strip, 2)
    local label = new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 18, 0, 0), BackgroundTransparency = 1,
        Text = text, TextColor3 = THEME.text, TextTransparency = 1, Font = FONT, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = n,
    })
    tween(n, 0.25, { BackgroundTransparency = 0.05 })
    tween(strip, 0.25, { BackgroundTransparency = 0 })
    tween(label, 0.25, { TextTransparency = 0 })
    task.delay(2.4, function()
        if not n.Parent then return end
        tween(n, 0.3, { BackgroundTransparency = 1 })
        tween(strip, 0.3, { BackgroundTransparency = 1 })
        tween(label, 0.3, { TextTransparency = 1 })
        task.wait(0.35)
        n:Destroy()
    end)
end

--------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------
local pages, tabButtons = {}, {}
local currentTab

local function createPage(name)
    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -20), Position = UDim2.new(0, 8, 0, 10),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.off, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content,
    })
    new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = page })
    pages[name] = page
    return page
end

local function selectTab(name)
    if currentTab == name then return end
    currentTab = name
    for n, page in pairs(pages) do page.Visible = (n == name) end
    for n, b in pairs(tabButtons) do
        b.active = (n == name)
        tween(b.button, 0.2, { BackgroundTransparency = b.active and 0 or 1 })
        tween(b.label, 0.2, { TextColor3 = b.active and THEME.text or THEME.sub, Position = UDim2.new(0, b.active and 16 or 12, 0, 0) })
        tween(b.bar, 0.2, { Size = UDim2.new(0, 3, b.active and 0.55 or 0, 0) })
    end
end

local function createTab(name)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.panel, BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, Parent = sidebar,
    })
    corner(b, 6)
    local label = new("TextLabel", {
        Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1,
        Text = name, TextColor3 = THEME.sub, Font = FONT, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = b,
    })
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = b,
    })
    corner(bar, 2)
    onAccent(function() bar.BackgroundColor3 = accent end)
    local entry = { button = b, label = label, bar = bar, active = false }
    tabButtons[name] = entry
    b.MouseEnter:Connect(function()
        if entry.active then return end
        tween(b, 0.15, { BackgroundTransparency = 0.6 })
        tween(label, 0.15, { Position = UDim2.new(0, 17, 0, 0), TextColor3 = THEME.text })
    end)
    b.MouseLeave:Connect(function()
        if entry.active then return end
        tween(b, 0.15, { BackgroundTransparency = 1 })
        tween(label, 0.15, { Position = UDim2.new(0, 12, 0, 0), TextColor3 = THEME.sub })
    end)
    b.MouseButton1Click:Connect(function() selectTab(name) end)
    return createPage(name)
end

--------------------------------------------------------------------
-- Components
--------------------------------------------------------------------
local components = {}

local function createSection(parent, order, text)
    new("TextLabel", {
        Size = UDim2.new(1, -6, 0, 18), BackgroundTransparency = 1, LayoutOrder = order,
        Text = string.upper(text), TextColor3 = THEME.sub, Font = FONT, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
end

local function createRow(parent, order, height)
    local row = new("Frame", {
        Size = UDim2.new(1, -6, 0, height), BackgroundColor3 = THEME.panel,
        BorderSizePixel = 0, LayoutOrder = order, Parent = parent,
    })
    corner(row, 6)
    local strip = new("Frame", {
        Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = row,
    })
    corner(strip, 2)
    onAccent(function() strip.BackgroundColor3 = accent end)
    row.MouseEnter:Connect(function()
        tween(row, 0.15, { BackgroundColor3 = THEME.hover })
        tween(strip, 0.2, { Size = UDim2.new(0, 3, 0.6, 0) })
    end)
    row.MouseLeave:Connect(function()
        tween(row, 0.15, { BackgroundColor3 = THEME.panel })
        tween(strip, 0.2, { Size = UDim2.new(0, 3, 0, 0) })
    end)
    return row
end

local function rowLabels(row, title, desc)
    new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 18), Position = UDim2.new(0, 14, 0, 8), BackgroundTransparency = 1,
        Text = title, TextColor3 = THEME.text, Font = FONT, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    if desc then
        new("TextLabel", {
            Size = UDim2.new(1, -100, 0, 14), Position = UDim2.new(0, 14, 0, 28), BackgroundTransparency = 1,
            Text = desc, TextColor3 = THEME.sub, Font = FONT, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
    end
end

local function createToggle(parent, order, title, desc, key, callback)
    local row = createRow(parent, order, 52)
    rowLabels(row, title, desc)
    local value = config[key]

    local track = new("TextButton", {
        Size = UDim2.fromOffset(42, 22), Position = UDim2.new(1, -56, 0.5, -11),
        Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(track, 11)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 8)
    onAccent(function() track.BackgroundColor3 = value and accent or THEME.off end)

    track.MouseEnter:Connect(function() tween(knob, 0.12, { Size = UDim2.fromOffset(20, 16) }) end)
    track.MouseLeave:Connect(function() tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }) end)

    local api = {}
    function api.Set(v)
        value = v
        config[key] = v
        save()
        tween(track, 0.2, { BackgroundColor3 = v and accent or THEME.off })
        tween(knob, 0.2, { Position = v and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
        if callback then callback(v) end
    end
    function api.Get() return value end
    track.MouseButton1Click:Connect(function() api.Set(not value) end)
    components[key] = api
    return api
end

local function createSlider(parent, order, title, key, min, max, decimals, callback)
    local row = createRow(parent, order, 62)
    rowLabels(row, title)
    local fmt = "%." .. decimals .. "f"
    local valueLabel = new("TextLabel", {
        Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -74, 0, 8), BackgroundTransparency = 1,
        Text = string.format(fmt, config[key]), TextColor3 = THEME.sub, Font = FONT, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local track = new("TextButton", {
        Size = UDim2.new(1, -28, 0, 5), Position = UDim2.new(0, 14, 0, 42),
        BackgroundColor3 = THEME.off, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Parent = row,
    })
    corner(track, 3)
    local alpha0 = (config[key] - min) / (max - min)
    local fill = new("Frame", { Size = UDim2.new(alpha0, 0, 1, 0), BorderSizePixel = 0, Parent = track })
    corner(fill, 3)
    onAccent(function() fill.BackgroundColor3 = accent end)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(alpha0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Parent = track,
    })
    corner(knob, 6)
    track.MouseEnter:Connect(function() tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }) end)
    track.MouseLeave:Connect(function() tween(knob, 0.12, { Size = UDim2.fromOffset(12, 12) }) end)

    local api = {}
    function api.Set(v)
        v = math.clamp(v, min, max)
        local mult = 10 ^ decimals
        v = math.floor(v * mult + 0.5) / mult
        local alpha = (v - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = string.format(fmt, v)
        config[key] = v
        save()
        if callback then callback(v) end
    end
    local sliding = false
    local function fromX(x)
        api.Set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            fromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    components[key] = api
    return api
end

local function styleButton(b, w, h)
    corner(b, 6)
    onAccent(function() b.BackgroundColor3 = accent end)
    b.MouseEnter:Connect(function()
        tween(b, 0.15, { BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.18), Size = UDim2.fromOffset(w + 4, h + 2) })
    end)
    b.MouseLeave:Connect(function()
        tween(b, 0.15, { BackgroundColor3 = accent, Size = UDim2.fromOffset(w, h) })
    end)
    b.MouseButton1Down:Connect(function() tween(b, 0.08, { Size = UDim2.fromOffset(w - 4, h - 2) }) end)
    b.MouseButton1Up:Connect(function() tween(b, 0.1, { Size = UDim2.fromOffset(w + 4, h + 2) }) end)
end

local function createButton(parent, order, title, desc, btnText, callback)
    local row = createRow(parent, order, 52)
    rowLabels(row, title, desc)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(84, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Text = btnText, TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 13,
        AutoButtonColor = false, BorderSizePixel = 0, Parent = row,
    })
    styleButton(b, 84, 28)
    b.MouseButton1Click:Connect(function() callback(b) end)
    return b
end

local listening = nil
local function createKeybind(parent, order, title, desc, key, fallback, onChange)
    local btn = createButton(parent, order, title, desc, config[key], function(b)
        b.Text = "press a key"
        listening = function(code)
            b.Text = code.Name
            config[key] = code.Name
            save()
            onChange(code)
        end
    end)
    components[key] = { Set = function(name)
        config[key] = name
        btn.Text = name
        onChange(keyFromName(name, fallback))
    end }
    return btn
end

local function createInput(parent, order, title, desc, placeholder, btnText, callback)
    local row = createRow(parent, order, 88)
    rowLabels(row, title, desc)
    local box = new("TextBox", {
        Size = UDim2.new(1, -118, 0, 28), Position = UDim2.new(0, 14, 0, 50),
        BackgroundColor3 = THEME.bg, Text = "", PlaceholderText = placeholder,
        PlaceholderColor3 = THEME.sub, TextColor3 = THEME.text, Font = FONT, TextSize = 14,
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0, Parent = row,
    })
    corner(box, 6)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box })
    local stroke = new("UIStroke", { Color = THEME.line, Thickness = 1, Parent = box })
    box.Focused:Connect(function() tween(stroke, 0.15, { Color = accent }) end)
    box.FocusLost:Connect(function() tween(stroke, 0.15, { Color = THEME.line }) end)

    local b = new("TextButton", {
        Size = UDim2.fromOffset(70, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 50),
        Text = btnText, TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 13,
        AutoButtonColor = false, BorderSizePixel = 0, Parent = row,
    })
    styleButton(b, 70, 28)
    local function submit() callback(box.Text) end
    b.MouseButton1Click:Connect(submit)
    box.FocusLost:Connect(function(enter) if enter then submit() end end)
end

--------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------
local mainPage = createTab("Main")
local playerPage = createTab("Player")
local playersPage = createTab("Players")
local visualsPage = createTab("Visuals")
local settingsPage = createTab("Settings")

-- Main
createSection(mainPage, 0, "Head")
createToggle(mainPage, 1, "Headless", "Hides your head (only you see it)", "headless", function(v)
    notify("Headless " .. (v and "on" or "off"))
end)
createToggle(mainPage, 2, "Hide Face", "Also hides the face while headless", "hideFace")
createToggle(mainPage, 3, "Hide Head Accessories", "Hats, hair and face items", "hideAccessories")
createSection(mainPage, 4, "Body")
createToggle(mainPage, 5, "Invisible", "Makes your whole character see-through to you", "invisible", function(v)
    notify("Invisible " .. (v and "on" or "off"))
end)
createSlider(mainPage, 6, "Invisible Level", "invisLevel", 0.3, 1, 2)

-- Player
createSection(playerPage, 0, "Movement")
createToggle(playerPage, 1, "Speed Boost", "Custom walk speed", "speedOn", function(v)
    notify("Speed boost " .. (v and "on" or "off"))
end)
createSlider(playerPage, 2, "Walk Speed", "speed", 16, 150, 0)
createToggle(playerPage, 3, "Jump Boost", "Custom jump power", "jumpOn", function(v)
    notify("Jump boost " .. (v and "on" or "off"))
end)
createSlider(playerPage, 4, "Jump Power", "jump", 50, 250, 0)
createToggle(playerPage, 5, "Infinite Jump", "Jump again in mid-air", "infJump", function(v)
    notify("Infinite jump " .. (v and "on" or "off"))
end)
createSection(playerPage, 6, "Camera")
createToggle(playerPage, 7, "Custom FOV", "Override your field of view", "fovOn")
createSlider(playerPage, 8, "Field of View", "fov", 40, 120, 0)

-- Players
createSection(playersPage, 0, "Teleport")
createInput(playersPage, 1, "Go To Player", "Part of a name, or !to name in chat", "name...", "Go", teleportToQuery)
createSection(playersPage, 2, "Hide + Mute")
createInput(playersPage, 3, "Hide Player", "Name, part of a name, or all (!hide in chat)", "name or all...", "Hide", function(q)
    if q ~= "" then hideCommand(q, true) end
end)
createInput(playersPage, 4, "Unhide Player", "Name, part of a name, or all (!unhide in chat)", "name or all...", "Show", function(q)
    if q ~= "" then hideCommand(q, false) end
end)
createSection(playersPage, 5, "Tags")
createToggle(playersPage, 6, "Player Tags", "FPS, distance and health above every player", "fpsTags", function(v)
    if not v then clearTags() end
    notify("Player tags " .. (v and "on" or "off"))
end)
createSlider(playersPage, 7, "Tag Range", "tagRange", 50, 1000, 0, function(v)
    for _, t in pairs(tags) do t.gui.MaxDistance = v end
end)

-- Visuals
createSection(visualsPage, 0, "Accent Color")
local swatchRow = createRow(visualsPage, 1, 56)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10),
    VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Center,
    Parent = swatchRow,
})
for _, a in ipairs(ACCENT_LIST) do
    local name, color = a[1], a[2]
    local sw = new("TextButton", {
        Size = UDim2.fromOffset(30, 30), BackgroundColor3 = color, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0, Parent = swatchRow,
    })
    corner(sw, 6)
    sw.MouseEnter:Connect(function() tween(sw, 0.15, { Size = UDim2.fromOffset(36, 36) }) end)
    sw.MouseLeave:Connect(function() tween(sw, 0.15, { Size = UDim2.fromOffset(30, 30) }) end)
    sw.MouseButton1Click:Connect(function()
        config.accent = name
        save()
        setAccent(color)
        notify("Accent: " .. name)
    end)
end
createSection(visualsPage, 2, "Window")
createSlider(visualsPage, 3, "UI Scale", "scale", 0.7, 1.4, 2, function(v) uiScale.Scale = v end)
createSlider(visualsPage, 4, "Window Opacity", "opacity", 0.4, 1, 2, function(v)
    main.BackgroundTransparency = 1 - v
end)

-- Show / hide
local function setVisible(v)
    visible = v
    if v then
        main.Visible = true
        tween(uiScale, 0.3, { Scale = config.scale }, Enum.EasingStyle.Back)
    else
        tween(uiScale, 0.2, { Scale = 0 })
        task.delay(0.22, function() if not visible then main.Visible = false end end)
    end
end

-- Unload
local function unload()
    running = false
    if writefile then pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(config)) end) end
    applyLook(true)
    restoreHidden()
    clearTags()
    pcall(function() tagFolder:Destroy() end)
    local hum = getHum()
    if hum then
        if speedApplied then hum.WalkSpeed = 16 end
        if jumpApplied then hum.JumpPower = 50 end
    end
    if cam and fovApplied then cam.FieldOfView = origFov end
    for _, c in ipairs(connections) do c:Disconnect() end
    gui:Destroy()
    env.HeadlessHubUnload = nil
end
env.HeadlessHubUnload = unload

-- Settings
createSection(settingsPage, 0, "Keybinds")
createKeybind(settingsPage, 1, "GUI Key", "Show or hide the window", "guiKey", Enum.KeyCode.RightShift, function(code) keys.gui = code end)
createKeybind(settingsPage, 2, "Headless Key", "Quick toggle headless", "headlessKey", Enum.KeyCode.H, function(code) keys.headless = code end)
createSection(settingsPage, 3, "Manage")
createButton(settingsPage, 4, "Reset", "Restore all default settings", "Reset", function()
    resetting = true
    for key, comp in pairs(components) do
        if comp.Set then comp.Set(DEFAULTS[key]) end
    end
    config.accent = DEFAULTS.accent
    setAccent(accentByName(DEFAULTS.accent))
    resetting = false
    notify("Everything reset")
end)
createButton(settingsPage, 5, "Unload", "Restore everything and remove the GUI", "Unload", unload)

selectTab("Main")

--------------------------------------------------------------------
-- Minimize, close, hotkeys
--------------------------------------------------------------------
local FULL, MINI = UDim2.fromOffset(WIN_W, WIN_H), UDim2.fromOffset(WIN_W, HEADER_H)

minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tween(main, 0.25, { Size = minimized and MINI or FULL })
    minimizeBtn.Text = minimized and "+" or "-"
end)
closeBtn.MouseButton1Click:Connect(function()
    setVisible(false)
    notify("Press " .. keys.gui.Name .. " to reopen")
end)

connect(UserInputService.InputBegan, function(input, processed)
    if listening then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            local fn = listening
            listening = nil
            fn(input.KeyCode)
        end
        return
    end
    if processed then return end
    if input.KeyCode == keys.gui then
        setVisible(not visible)
    elseif input.KeyCode == keys.headless then
        local h = components.headless
        if h then h.Set(not h.Get()) end
    end
end)

-- Small floating button (mobile / forgot the key)
local fab = new("TextButton", {
    Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 14, 0.5, -20),
    Text = "HH", TextColor3 = Color3.new(1, 1, 1), Font = FONT_TITLE, TextSize = 16,
    AutoButtonColor = false, BorderSizePixel = 0, Parent = gui,
})
corner(fab, 8)
onAccent(function() fab.BackgroundColor3 = accent end)
fab.MouseEnter:Connect(function() tween(fab, 0.15, { Size = UDim2.fromOffset(44, 44) }) end)
fab.MouseLeave:Connect(function() tween(fab, 0.15, { Size = UDim2.fromOffset(40, 40) }) end)
fab.MouseButton1Click:Connect(function() setVisible(not visible) end)

--------------------------------------------------------------------
-- Dragging (header moves the window)
--------------------------------------------------------------------
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, input.Position, main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- Intro
tween(uiScale, 0.4, { Scale = config.scale }, Enum.EasingStyle.Back)
task.delay(0.5, function() notify("Headless Hub v9 loaded") end)
