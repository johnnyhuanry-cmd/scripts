-- Headless Hub v4 | Christmas Edition (client-side only)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
local env = (getgenv and getgenv()) or _G

-- Clean up any previous copy
if env.HeadlessHubUnload then pcall(env.HeadlessHubUnload) end
pcall(function()
    local old = parentGui:FindFirstChild("HeadlessHub")
    if old then old:Destroy() end
end)

--------------------------------------------------------------------
-- Config (auto-saves if your executor supports writefile)
--------------------------------------------------------------------
local CONFIG_FILE = "HeadlessHub_v4.json"
local DEFAULTS = {
    headless = false, hideFace = true, hideAccessories = false,
    speedOn = false, speed = 32,
    jumpOn = false, jump = 80,
    infJump = false,
    fovOn = false, fov = 90,
    santaHat = false, lights = true,
    windowSnow = true, screenSnow = false,
    snowAmount = 70, snowSpeed = 1, snowWind = 0,
    festive = false, accent = "Candy Red", scale = 1, opacity = 1,
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
    side = Color3.fromRGB(14, 22, 40),
    panel = Color3.fromRGB(26, 36, 56),
    off = Color3.fromRGB(62, 72, 94),
    text = Color3.fromRGB(245, 248, 255),
    sub = Color3.fromRGB(160, 178, 202),
}

local ACCENT_LIST = {
    { "Candy Red", Color3.fromRGB(225, 50, 65) },
    { "Pine Green", Color3.fromRGB(45, 175, 100) },
    { "Gold", Color3.fromRGB(255, 196, 66) },
    { "Frost", Color3.fromRGB(110, 200, 255) },
    { "Berry", Color3.fromRGB(235, 90, 160) },
    { "Silver", Color3.fromRGB(200, 210, 225) },
}
local function accentByName(name)
    for _, a in ipairs(ACCENT_LIST) do if a[1] == name then return a[2] end end
    return ACCENT_LIST[1][2]
end

local RED, GOLD, GREEN, ICE = ACCENT_LIST[1][2], ACCENT_LIST[3][2], ACCENT_LIST[2][2], ACCENT_LIST[4][2]
local FESTIVE = { RED, GOLD, GREEN, ICE }
local FESTIVE_SEQ = ColorSequence.new({
    ColorSequenceKeypoint.new(0, RED),
    ColorSequenceKeypoint.new(0.33, GOLD),
    ColorSequenceKeypoint.new(0.66, GREEN),
    ColorSequenceKeypoint.new(1, RED),
})
local function festiveColor(t)
    local n = #FESTIVE
    local p = (t % 1) * n
    local i = math.floor(p)
    return FESTIVE[i % n + 1]:Lerp(FESTIVE[(i + 1) % n + 1], p - i)
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

--------------------------------------------------------------------
-- Core logic: headless, movement, camera
--------------------------------------------------------------------
local orig = setmetatable({}, { __mode = "k" })
local HEAD_ATTACHMENTS = {
    HatAttachment = true, HairAttachment = true,
    FaceFrontAttachment = true, FaceCenterAttachment = true,
}

local function setTransparency(inst, hide)
    if orig[inst] == nil then orig[inst] = inst.Transparency end
    local target = hide and 1 or orig[inst]
    if inst.Transparency ~= target then inst.Transparency = target end
end

local function headHandle(acc)
    local handle = acc:FindFirstChild("Handle")
    if not handle then return nil end
    for _, child in ipairs(handle:GetChildren()) do
        if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then return handle end
    end
    return nil
end

local function applyHeadless(forceOff)
    local char = player.Character
    if not char then return end
    local hl = (not forceOff) and config.headless
    local head = char:FindFirstChild("Head")
    if head then
        setTransparency(head, hl)
        for _, d in ipairs(head:GetChildren()) do
            if d:IsA("Decal") then setTransparency(d, hl and config.hideFace) end
        end
    end
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = headHandle(acc)
            if handle then setTransparency(handle, (not forceOff) and config.hideAccessories) end
        end
    end
end

local function getHum()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local cam = workspace.CurrentCamera
local origFov = cam and cam.FieldOfView or 70
local speedApplied, jumpApplied, fovApplied = false, false, false

connect(RunService.Stepped, function() applyHeadless(false) end)

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
-- Santa hat (built locally, only you can see it)
--------------------------------------------------------------------
local hatModel
local function destroyHat()
    if hatModel then pcall(function() hatModel:Destroy() end) hatModel = nil end
end

local function buildHat(char)
    destroyHat()
    local head = char and char:FindFirstChild("Head")
    if not head then return end

    local s = math.max(head.Size.X, head.Size.Z) / 2
    local top = head.Size.Y / 2
    local base = head.CFrame * CFrame.new(0, top, 0) * CFrame.Angles(math.rad(-10), 0, 0)

    local model = Instance.new("Model")
    model.Name = "SantaHat"

    local function piece(shape, size, y, color)
        local p = Instance.new("Part")
        p.Shape = shape
        p.Size = size
        p.Color = color
        p.Material = Enum.Material.SmoothPlastic
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Massless = true
        p.CFrame = base * CFrame.new(0, y * s, 0) * CFrame.Angles(0, 0, math.rad(90))
        p.Parent = model
        local w = Instance.new("WeldConstraint")
        w.Part0 = head
        w.Part1 = p
        w.Parent = p
    end

    local red = Color3.fromRGB(205, 30, 40)
    local white = Color3.fromRGB(250, 250, 255)
    local cyl = Enum.PartType.Cylinder
    piece(cyl, Vector3.new(0.4 * s, 2.5 * s, 2.5 * s), 0.1, white)
    piece(cyl, Vector3.new(0.8 * s, 2.0 * s, 2.0 * s), 0.7, red)
    piece(cyl, Vector3.new(0.8 * s, 1.5 * s, 1.5 * s), 1.5, red)
    piece(cyl, Vector3.new(0.8 * s, 1.0 * s, 1.0 * s), 2.3, red)
    piece(Enum.PartType.Ball, Vector3.new(0.75 * s, 0.75 * s, 0.75 * s), 2.9, white)

    model.Parent = char
    hatModel = model
end

local function refreshHat()
    local char = player.Character
    if config.santaHat and char then
        if not hatModel or hatModel.Parent ~= char then buildHat(char) end
    else
        destroyHat()
    end
end

--------------------------------------------------------------------
-- Snow engine
--------------------------------------------------------------------
local function createSnow(parent, maxCount, minSize, maxSize, w, h)
    local layer = { flakes = {}, lastCount = -1 }
    for i = 1, maxCount do
        local depth = math.random()
        local size = math.floor(minSize + (maxSize - minSize) * depth + 0.5)
        local f = new("Frame", {
            Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.6 - depth * 0.45, BorderSizePixel = 0,
            Visible = false, Parent = parent,
        })
        new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
        layer.flakes[i] = {
            gui = f, x = math.random() * w, y = math.random() * h, size = size, depth = depth,
            speed = 14 + depth * 46, amp = 4 + math.random() * 14,
            freq = 0.5 + math.random() * 1.2, phase = math.random() * 6.28,
        }
    end
    return layer
end

local function stepSnow(layer, dt, t, w, h, count, speedMul, wind)
    count = math.clamp(math.floor(count), 0, #layer.flakes)
    if layer.lastCount ~= count then
        layer.lastCount = count
        for i, f in ipairs(layer.flakes) do f.gui.Visible = i <= count end
    end
    for i = 1, count do
        local f = layer.flakes[i]
        f.y += f.speed * speedMul * dt
        f.x += wind * (0.4 + f.depth) * dt
        if f.y > h + f.size then
            f.y = -f.size
            f.x = math.random() * w
        end
        if f.x > w + 20 then f.x -= (w + 40) elseif f.x < -20 then f.x += (w + 40) end
        f.gui.Position = UDim2.fromOffset(f.x + math.sin(t * f.freq + f.phase) * f.amp, f.y)
    end
end

--------------------------------------------------------------------
-- Root GUI
--------------------------------------------------------------------
local WIN_W, WIN_H, HEADER_H = 560, 380, 46
local gui = new("ScreenGui", {
    Name = "HeadlessHub", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parentGui,
})

local function screenSize()
    local s = gui.AbsoluteSize
    if s.X < 10 then
        local c = workspace.CurrentCamera
        s = c and c.ViewportSize or Vector2.new(1920, 1080)
    end
    return s
end

-- Full-screen snow (created first so the window sits above it)
local snowScreen = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = config.screenSnow, Parent = gui,
})
local sv = screenSize()
local snowScreenLayer = createSnow(snowScreen, 100, 2, 6, sv.X, sv.Y)

-- Main window
local main = new("Frame", {
    Size = UDim2.fromOffset(WIN_W, WIN_H),
    Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2),
    BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 - config.opacity,
    BorderSizePixel = 0, ClipsDescendants = true, Active = true, Parent = gui,
})
corner(main, 14)
new("UIGradient", {
    Color = ColorSequence.new(Color3.fromRGB(14, 24, 50), Color3.fromRGB(8, 42, 38)),
    Rotation = 90, Parent = main,
})
local mainStroke = new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = main })
local strokeGrad = new("UIGradient", { Color = FESTIVE_SEQ, Parent = mainStroke })
local uiScale = new("UIScale", { Scale = 0, Parent = main })

-- Window snow (behind everything in the window)
local snowWin = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = config.windowSnow, Parent = main,
})
local snowWinLayer = createSnow(snowWin, 120, 2, 7, WIN_W, WIN_H)

-- Header
local header = new("Frame", {
    Size = UDim2.new(1, 0, 0, HEADER_H), BackgroundColor3 = THEME.side,
    BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = main,
})
local headerLine = new("Frame", {
    Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = header,
})
new("UIGradient", { Color = FESTIVE_SEQ, Parent = headerLine })

new("TextLabel", {
    Size = UDim2.new(1, -120, 0, 24), Position = UDim2.new(0, 16, 0, 5),
    BackgroundTransparency = 1, Text = "❄ HEADLESS HUB ❄", TextColor3 = THEME.text,
    Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
local subtitle = new("TextLabel", {
    Size = UDim2.new(1, -120, 0, 14), Position = UDim2.new(0, 16, 0, 27),
    BackgroundTransparency = 1, Text = "CHRISTMAS EDITION  •  v4", TextColor3 = THEME.sub,
    Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
onAccent(function() subtitle.TextColor3 = accent end)

local function headerButton(text, xOffset, color)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xOffset, 0.5, -13),
        BackgroundColor3 = color, Text = text, TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = false, Parent = header,
    })
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0.25 }) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, { BackgroundTransparency = 0 }) end)
    return b
end
local minimizeBtn = headerButton("-", -68, Color3.fromRGB(70, 80, 105))
local closeBtn = headerButton("X", -36, Color3.fromRGB(190, 55, 65))

-- Sidebar + content
local sidebar = new("Frame", {
    Size = UDim2.new(0, 124, 1, -HEADER_H), Position = UDim2.new(0, 0, 0, HEADER_H),
    BackgroundColor3 = THEME.side, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = main,
})
new("UIListLayout", { Padding = UDim.new(0, 6), Parent = sidebar })
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = sidebar })
local content = new("Frame", {
    Size = UDim2.new(1, -124, 1, -HEADER_H - 10), Position = UDim2.new(0, 124, 0, HEADER_H),
    BackgroundTransparency = 1, Parent = main,
})

-- Stats (FPS + ping)
local statsLabel = new("TextLabel", {
    Size = UDim2.new(0, 108, 0, 34), Position = UDim2.new(0, 10, 1, -58),
    BackgroundTransparency = 1, Text = "FPS: --\nPing: --", TextColor3 = THEME.sub,
    Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = main,
})
local frames, last = 0, os.clock()
connect(RunService.RenderStepped, function()
    frames += 1
    local now = os.clock()
    if now - last >= 0.5 then
        local ping = "--"
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms" end)
        statsLabel.Text = "FPS: " .. math.floor(frames / (now - last)) .. "\nPing: " .. ping
        frames, last = 0, now
    end
end)

-- Christmas lights across the header
local lightsHolder = new("Frame", {
    Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, HEADER_H - 2),
    BackgroundTransparency = 1, Visible = config.lights, Parent = main,
})
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 3),
    BackgroundColor3 = Color3.fromRGB(25, 70, 50), BorderSizePixel = 0, Parent = lightsHolder,
})
local LIGHT_COLORS = { RED, GOLD, GREEN, ICE }
local bulbs = {}
local BULB_COUNT = 24
for i = 1, BULB_COUNT do
    local x = (i - 0.5) / BULB_COUNT
    local y = 4 + (i % 2) * 3
    local color = LIGHT_COLORS[(i - 1) % #LIGHT_COLORS + 1]
    local glow = new("Frame", {
        Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(x, 0, 0, y + 5), BackgroundColor3 = color,
        BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = lightsHolder,
    })
    corner(glow, 8)
    local bulb = new("Frame", {
        Size = UDim2.fromOffset(7, 9), AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(x, 0, 0, y), BackgroundColor3 = color,
        BorderSizePixel = 0, Parent = lightsHolder,
    })
    corner(bulb, 4)
    bulbs[i] = { bulb = bulb, glow = glow }
end

-- Snow drift along the bottom of the window
local drift = new("Frame", { Size = UDim2.fromOffset(WIN_W, 20), Position = UDim2.fromOffset(0, WIN_H - 10),
    BackgroundTransparency = 1, Parent = main })
local DRIFT_N = 16
for i = 1, DRIFT_N do
    local size = math.random(28, 48)
    local c = new("Frame", {
        Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.fromRGB(240, 246, 255),
        Position = UDim2.fromOffset((i - 1) / (DRIFT_N - 1) * WIN_W - size / 2, math.random(-3, 3)),
        BorderSizePixel = 0, Parent = drift,
    })
    corner(c, size / 2)
end
new("Frame", {
    Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 8),
    BackgroundColor3 = Color3.fromRGB(240, 246, 255), BorderSizePixel = 0, Parent = drift,
})

--------------------------------------------------------------------
-- Notifications
--------------------------------------------------------------------
local resetting = false
local notifHolder = new("Frame", {
    Size = UDim2.new(0, 260, 1, -20), Position = UDim2.new(1, -270, 0, 10),
    BackgroundTransparency = 1, Parent = gui,
})
new("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = notifHolder })

local function notify(text)
    if resetting then return end
    local n = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.panel, BackgroundTransparency = 1,
        Text = "❄  " .. text, TextColor3 = THEME.text, TextTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 14, Parent = notifHolder,
    })
    corner(n, 8)
    local s = new("UIStroke", { Color = accent, Thickness = 1.2, Transparency = 1, Parent = n })
    tween(n, 0.25, { BackgroundTransparency = 0.05, TextTransparency = 0 })
    tween(s, 0.25, { Transparency = 0 })
    task.delay(2.2, function()
        if not n.Parent then return end
        tween(n, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
        tween(s, 0.3, { Transparency = 1 })
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
        Size = UDim2.new(1, -16, 1, -16), Position = UDim2.new(0, 8, 0, 12),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, Parent = content,
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
        local active = (n == name)
        tween(b.button, 0.2, { BackgroundTransparency = active and 0.1 or 1, TextColor3 = active and THEME.text or THEME.sub })
        tween(b.bar, 0.2, { Size = UDim2.new(0, 3, active and 0.6 or 0, 0) })
    end
end

local function createTab(name, icon)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.panel, BackgroundTransparency = 1,
        Text = "  " .. icon .. "  " .. name, TextColor3 = THEME.sub, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = sidebar,
    })
    corner(b, 8)
    local bar = new("Frame", {
        Size = UDim2.new(0, 3, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, Parent = b,
    })
    corner(bar, 2)
    onAccent(function() bar.BackgroundColor3 = accent end)
    tabButtons[name] = { button = b, bar = bar }
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
        Text = string.upper(text), TextColor3 = THEME.sub, Font = Enum.Font.GothamBold,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
    })
end

local function createRow(parent, order, height)
    local row = new("Frame", {
        Size = UDim2.new(1, -6, 0, height), BackgroundColor3 = THEME.panel,
        BackgroundTransparency = 0.2, LayoutOrder = order, Parent = parent,
    })
    corner(row, 8)
    return row
end

local function rowLabels(row, title, desc)
    new("TextLabel", {
        Size = UDim2.new(1, -90, 0, 18), Position = UDim2.new(0, 14, 0, 8), BackgroundTransparency = 1,
        Text = title, TextColor3 = THEME.text, Font = Enum.Font.GothamBold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
    })
    if desc then
        new("TextLabel", {
            Size = UDim2.new(1, -90, 0, 14), Position = UDim2.new(0, 14, 0, 28), BackgroundTransparency = 1,
            Text = desc, TextColor3 = THEME.sub, Font = Enum.Font.Gotham, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
        })
    end
end

local function createToggle(parent, order, title, desc, key, callback)
    local row = createRow(parent, order, 52)
    rowLabels(row, title, desc)
    local value = config[key]

    local track = new("TextButton", {
        Size = UDim2.fromOffset(46, 24), Position = UDim2.new(1, -60, 0.5, -12),
        Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(track, 12)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(18, 18), Position = value and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
    })
    corner(knob, 9)
    onAccent(function() track.BackgroundColor3 = value and accent or THEME.off end)

    local api = {}
    function api.Set(v)
        value = v
        config[key] = v
        save()
        tween(track, 0.2, { BackgroundColor3 = v and accent or THEME.off })
        tween(knob, 0.2, { Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
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
        Text = string.format(fmt, config[key]), TextColor3 = THEME.sub, Font = Enum.Font.GothamBold,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
    })
    local track = new("TextButton", {
        Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 0, 40),
        BackgroundColor3 = THEME.off, Text = "", AutoButtonColor = false, Parent = row,
    })
    corner(track, 3)
    local alpha0 = (config[key] - min) / (max - min)
    local fill = new("Frame", { Size = UDim2.new(alpha0, 0, 1, 0), BorderSizePixel = 0, Parent = track })
    corner(fill, 3)
    onAccent(function() fill.BackgroundColor3 = accent end)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(alpha0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track,
    })
    corner(knob, 7)

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

local function createButton(parent, order, title, desc, btnText, callback)
    local row = createRow(parent, order, 52)
    rowLabels(row, title, desc)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(70, 28), Position = UDim2.new(1, -84, 0.5, -14),
        Text = btnText, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold,
        TextSize = 12, AutoButtonColor = false, Parent = row,
    })
    corner(b, 6)
    onAccent(function() b.BackgroundColor3 = accent end)
    b.MouseButton1Click:Connect(function() callback(b) end)
    return b
end

local listening = nil
local function createKeybind(parent, order, title, desc, key, keyName, onChange)
    local btn = createButton(parent, order, title, desc, keyName, function(b)
        b.Text = "..."
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
        onChange(keyFromName(name, Enum.KeyCode.H))
    end }
    return btn
end

local function daysToChristmas()
    local now = os.date("*t")
    if now.month == 12 and now.day == 25 then return 0 end
    local target = os.time({ year = now.year, month = 12, day = 25, hour = 0 })
    if os.time() > target then
        target = os.time({ year = now.year + 1, month = 12, day = 25, hour = 0 })
    end
    return math.ceil((target - os.time()) / 86400)
end

--------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------
local mainPage = createTab("Main", "❄")
local playerPage = createTab("Player", "▲")
local xmasPage = createTab("Christmas", "★")
local visualsPage = createTab("Visuals", "◆")
local settingsPage = createTab("Settings", "⚙")

-- Main
do
    local days = daysToChristmas()
    local title
    if days == 0 then title = "🎄 Merry Christmas!"
    elseif days == 1 then title = "🎄 1 day until Christmas"
    else title = "🎄 " .. days .. " days until Christmas" end
    local row = createRow(mainPage, 0, 56)
    rowLabels(row, title, "Happy holidays, " .. player.DisplayName .. "!")
end
createSection(mainPage, 1, "Head")
createToggle(mainPage, 2, "Headless", "Hides your head (only you see it)", "headless", function(v)
    notify("Headless: " .. (v and "ON" or "OFF"))
end)
createToggle(mainPage, 3, "Hide Face", "Also hides the face decal while headless", "hideFace")
createToggle(mainPage, 4, "Hide Head Accessories", "Hats, hair and face accessories", "hideAccessories", function(v)
    notify("Head accessories: " .. (v and "hidden" or "shown"))
end)

-- Player
createSection(playerPage, 0, "Movement")
createToggle(playerPage, 1, "Speed Boost", "Custom walk speed", "speedOn", function(v)
    notify("Speed boost: " .. (v and "ON" or "OFF"))
end)
createSlider(playerPage, 2, "Walk Speed", "speed", 16, 150, 0)
createToggle(playerPage, 3, "Jump Boost", "Custom jump power", "jumpOn", function(v)
    notify("Jump boost: " .. (v and "ON" or "OFF"))
end)
createSlider(playerPage, 4, "Jump Power", "jump", 50, 250, 0)
createToggle(playerPage, 5, "Infinite Jump", "Jump again in mid-air", "infJump", function(v)
    notify("Infinite jump: " .. (v and "ON" or "OFF"))
end)
createSection(playerPage, 6, "Camera")
createToggle(playerPage, 7, "Custom FOV", "Override your field of view", "fovOn")
createSlider(playerPage, 8, "Field of View", "fov", 40, 120, 0)

-- Christmas
createSection(xmasPage, 0, "Decorations")
createToggle(xmasPage, 1, "Santa Hat", "A hat on your head (only you see it)", "santaHat", function(v)
    refreshHat()
    notify("Santa hat: " .. (v and "ON" or "OFF"))
end)
createToggle(xmasPage, 2, "Christmas Lights", "Twinkling lights on the window", "lights", function(v)
    lightsHolder.Visible = v
end)
createSection(xmasPage, 3, "Snow")
createToggle(xmasPage, 4, "Window Snow", "Snow falling inside the GUI", "windowSnow", function(v)
    snowWin.Visible = v
end)
createToggle(xmasPage, 5, "Screen Snow", "Snow falling across your whole screen", "screenSnow", function(v)
    snowScreen.Visible = v
    notify("Screen snow: " .. (v and "ON" or "OFF"))
end)
createSlider(xmasPage, 6, "Snow Amount", "snowAmount", 10, 120, 0)
createSlider(xmasPage, 7, "Snow Speed", "snowSpeed", 0.2, 3, 1)
createSlider(xmasPage, 8, "Wind", "snowWind", -60, 60, 0)

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
    local sw = new("TextButton", { Size = UDim2.fromOffset(32, 32), BackgroundColor3 = color, Text = "", AutoButtonColor = false, Parent = swatchRow })
    corner(sw, 16)
    sw.MouseEnter:Connect(function() tween(sw, 0.15, { Size = UDim2.fromOffset(36, 36) }) end)
    sw.MouseLeave:Connect(function() tween(sw, 0.15, { Size = UDim2.fromOffset(32, 32) }) end)
    sw.MouseButton1Click:Connect(function()
        config.accent = name
        save()
        if components.festive and components.festive.Get() then components.festive.Set(false) end
        setAccent(color)
        notify("Theme: " .. name)
    end)
end
createToggle(visualsPage, 2, "Festive Colors", "Cycles red, gold, green and ice", "festive", function(v)
    if not v then setAccent(accentByName(config.accent)) end
end)
createSection(visualsPage, 3, "Window")
createSlider(visualsPage, 4, "UI Scale", "scale", 0.7, 1.4, 2, function(v) uiScale.Scale = v end)
createSlider(visualsPage, 5, "Window Opacity", "opacity", 0.4, 1, 2, function(v)
    main.BackgroundTransparency = 1 - v
end)

-- Show / hide logic
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
    applyHeadless(true)
    destroyHat()
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
createKeybind(settingsPage, 1, "GUI Key", "Show / hide the GUI", "guiKey", keys.gui.Name, function(code) keys.gui = code end)
createKeybind(settingsPage, 2, "Headless Key", "Quick toggle headless", "headlessKey", keys.headless.Name, function(code) keys.headless = code end)

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
createButton(settingsPage, 5, "Unload", "Restore everything and remove GUI", "Unload", unload)

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

-- Floating snowflake button (mobile / forgot the key)
local fab = new("TextButton", {
    Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 14, 0.5, -22),
    Text = "❄", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
    TextSize = 22, AutoButtonColor = false, Parent = gui,
})
corner(fab, 22)
onAccent(function() fab.BackgroundColor3 = accent end)
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

--------------------------------------------------------------------
-- Visual loop: snow, lights, border, festive colors, hat watchdog
--------------------------------------------------------------------
local t, festiveAcc, hatAcc = 0, 0, 0
connect(RunService.Heartbeat, function(dt)
    t += dt

    if config.windowSnow and visible and not minimized then
        stepSnow(snowWinLayer, dt, t, WIN_W, WIN_H, config.snowAmount, config.snowSpeed, config.snowWind)
    end
    if config.screenSnow then
        local s = screenSize()
        stepSnow(snowScreenLayer, dt, t, s.X, s.Y, math.min(config.snowAmount, 100), config.snowSpeed, config.snowWind)
    end

    if visible then
        strokeGrad.Rotation = (t * 50) % 360
        if config.lights then
            for i, b in ipairs(bulbs) do
                local v = 0.5 + 0.5 * math.sin(t * 2.6 + i * 1.3)
                b.bulb.BackgroundTransparency = 0.5 * (1 - v)
                b.glow.BackgroundTransparency = 0.88 - 0.4 * v
            end
        end
    end

    if config.festive then
        festiveAcc += dt
        if festiveAcc >= 0.05 then
            festiveAcc = 0
            setAccent(festiveColor(t * 0.12))
        end
    end

    hatAcc += dt
    if hatAcc >= 0.5 then
        hatAcc = 0
        refreshHat()
    end
end)

-- Intro animation
tween(uiScale, 0.5, { Scale = config.scale }, Enum.EasingStyle.Back)
task.delay(0.6, function() notify("Merry Christmas, " .. player.DisplayName .. "!") end)
