-- Headless Hub key gate
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")
local rng = Random.new()

---------------------------------------------------------------- settings
local GET_KEY_URL = "https://scripts-aktreyhub1.vercel.app/get-key.html"
local VERIFY_URL  = "https://scripts-aktreyhub1.vercel.app/verify-key.html"
local KEY_PARAM   = "key"     -- the key is sent as VERIFY_URL?key=THEIR_KEY
local CACHE_BUST  = true      -- adds &_=<time> so a stale cached answer is never reused
local HUB_URL     = "https://raw.githubusercontent.com/johnnyhuanry-cmd/scripts/refs/heads/main/headlesshub.lua"
local SAVE_FILE   = "HeadlessHub_key.txt"   -- remembers the last good key on this device

local env = (getgenv and getgenv()) or _G
if env.HubKeyGateCleanup then pcall(env.HubKeyGateCleanup) end
local conns = {}
local function track(c) table.insert(conns, c) return c end

---------------------------------------------------------------- utils
local function getParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok = pcall(function() return game.CoreGui:GetChildren() end)
	if ok then return game.CoreGui end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end
local function new(class, props, parent)
	local o = Instance.new(class)
	if props then for k, v in pairs(props) do o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function pad(o, l, t, r, b)
	return new("UIPadding", {PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b)}, o)
end

local ACCENT, ACCENT2 = Color3.fromRGB(124, 92, 255), Color3.fromRGB(70, 200, 255)
local BG, FIELD = Color3.fromRGB(15, 15, 23), Color3.fromRGB(10, 10, 17)
local TEXT, SUB, OFF = Color3.fromRGB(238, 238, 248), Color3.fromRGB(150, 150, 176), Color3.fromRGB(60, 60, 82)
local GOOD, BAD, WARN = Color3.fromRGB(90, 230, 140), Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 190, 80)
local function accentSeq()
	return ColorSequence.new({ColorSequenceKeypoint.new(0, ACCENT), ColorSequenceKeypoint.new(.5, ACCENT2), ColorSequenceKeypoint.new(1, ACCENT)})
end

---------------------------------------------------------------- key checking
local function httpGet(url)
	local req = (syn and syn.request) or (http and http.request) or http_request or request or (fluxus and fluxus.request)
	if req then
		local ok, res = pcall(req, {Url = url, Method = "GET"})
		if ok and type(res) == "table" then return true, tonumber(res.StatusCode) or 200, res.Body or "" end
		return false, 0, tostring(res)
	end
	local ok, body = pcall(function() return game:HttpGet(url, true) end)
	return ok, ok and 200 or 0, ok and body or tostring(body)
end

local NEG = {"invalid", "not", "denied", "expired", "wrong", "incorrect", "fail", "failed", "error", "false", "unauthorized", "forbidden", "revoked", "banned"}
local POS = {"valid", "granted", "success", "verified", "approved", "correct", "authorized", "ok", "true", "yes"}
local function has(s, w) return s:find("%f[%a]" .. w .. "%f[%A]") ~= nil end
local function textGranted(s)
	s = tostring(s):lower()
	for _, w in ipairs(NEG) do if has(s, w) then return false end end
	for _, w in ipairs(POS) do if has(s, w) then return true end end
	return false
end

-- returns true (granted), false (not granted) or nil + reason (technical problem)
local function judge(status, body)
	body = tostring(body or "")
	local text = body:gsub("^%s+", ""):gsub("%s+$", "")
	local lower = text:lower()
	if text == "" then return nil, "Empty answer from the key server" end
	if lower:sub(1, 1) == "<" or lower:find("<html", 1, true) then
		if lower:find("vercel", 1, true) and (lower:find("login", 1, true) or lower:find("authentication", 1, true)) then
			return nil, "Site is behind a Vercel login. Turn off Deployment Protection"
		end
		return nil, "The verify link returned a web page, not a result"
	end
	if status >= 500 then return nil, "Key server error (" .. status .. ")" end

	local ok, data = pcall(function() return HttpService:JSONDecode(text) end)
	if ok and type(data) == "table" then
		local function read(t)
			for _, k in ipairs({"valid", "verified", "authorized", "granted", "access", "result", "status", "success", "ok", "message"}) do
				local v = t[k]
				if v ~= nil then
					if v == true or v == 1 then return true end
					if v == false or v == 0 then return false end
					if type(v) == "string" then return textGranted(v) end
				end
			end
			if type(t.data) == "table" then return read(t.data) end
			return false
		end
		return read(data)
	end
	if ok and data ~= nil then
		if data == true or data == 1 then return true end
		if type(data) == "string" then return textGranted(data) end
		return false
	end
	return textGranted(text)
end

local function checkKey(key)
	local url = VERIFY_URL .. (VERIFY_URL:find("?", 1, true) and "&" or "?") .. KEY_PARAM .. "=" .. HttpService:UrlEncode(key)
	if CACHE_BUST then url = url .. "&_=" .. tostring(os.time()) end
	local ok, status, body = httpGet(url)
	if not ok then return nil, "Couldn't reach the key server" end
	return judge(status, body)
end

local function readSaved()
	if not (readfile and isfile) then return nil end
	local ok, v = pcall(function()
		if isfile(SAVE_FILE) then return readfile(SAVE_FILE) end
	end)
	if ok and type(v) == "string" and v:match("%S") then return (v:gsub("%s+", "")) end
	return nil
end

---------------------------------------------------------------- dashboard
local gui = new("ScreenGui", {Name = "HubKeyGate", ResetOnSpawn = false, DisplayOrder = 2000, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, getParent())
local blur = new("BlurEffect", {Name = "HubKeyBlur", Size = 0}, Lighting)
local backdrop = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(5, 5, 11), BackgroundTransparency = 1, BorderSizePixel = 0, Active = true}, gui)

-- drifting particles
local specks = {}
for i = 1, 34 do
	local sz = rng:NextNumber(2, 5)
	local f = new("Frame", {Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = i % 3 == 0 and ACCENT2 or (i % 3 == 1 and ACCENT or Color3.new(1, 1, 1)),
		BackgroundTransparency = rng:NextNumber(.55, .9), BorderSizePixel = 0}, backdrop)
	corner(f, 5)
	specks[i] = {f = f, x = rng:NextNumber(), y = rng:NextNumber(), sp = rng:NextNumber(.012, .04), ph = rng:NextNumber(0, 6), amp = rng:NextNumber(.004, .014)}
end

local W, H = 420, 372
local win = new("Frame", {Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1}, gui)
local viewY = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y) or 720
new("UIScale", {Scale = math.clamp(viewY / 700, .62, 1)}, win)
local pop = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, win)
local popScale = new("UIScale", {Scale = .8}, pop)
local halo = new("Frame", {Size = UDim2.new(1, 30, 1, 30), Position = UDim2.fromOffset(-15, -15), BackgroundColor3 = ACCENT, BackgroundTransparency = 1, BorderSizePixel = 0}, pop)
corner(halo, 30)
local card = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG, GroupTransparency = 1}, pop)
corner(card, 18)
new("UIGradient", {Rotation = 60, Color = ColorSequence.new(Color3.fromRGB(24, 21, 44), Color3.fromRGB(12, 12, 20))}, card)
local stroke = new("UIStroke", {Thickness = 1.8, Color = Color3.new(1, 1, 1)}, card)
local strokeGrad = new("UIGradient", {Color = accentSeq()}, stroke)

local function section(y, h)
	local s = new("CanvasGroup", {Size = UDim2.new(1, 0, 0, h), Position = UDim2.fromOffset(0, y + 14), BackgroundTransparency = 1, GroupTransparency = 1}, card)
	return s
end
local function label(parent, text, size, font, color, pos, sz, align)
	return new("TextLabel", {BackgroundTransparency = 1, Text = text, TextSize = size, Font = font, TextColor3 = color, Position = pos, Size = sz,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextWrapped = true}, parent)
end

-- header
local secHead = section(0, 84)
local logoRing = new("Frame", {Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(48, 42), BackgroundColor3 = ACCENT, BackgroundTransparency = .85, BorderSizePixel = 0}, secHead)
corner(logoRing, 28)
local logo = new("Frame", {Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(48, 42), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, secHead)
corner(logo, 14)
new("UIGradient", {Rotation = 45, Color = ColorSequence.new(ACCENT, ACCENT2)}, logo)
label(logo, "H", 24, Enum.Font.GothamBlack, Color3.new(1, 1, 1), UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
label(secHead, "HEADLESS HUB", 20, Enum.Font.GothamBlack, TEXT, UDim2.fromOffset(86, 20), UDim2.fromOffset(230, 24))
label(secHead, "🔒  Key verification", 12, Enum.Font.GothamMedium, SUB, UDim2.fromOffset(86, 46), UDim2.fromOffset(230, 16))
local closeBtn = new("TextButton", {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(W - 46, 20), BackgroundColor3 = Color3.fromRGB(34, 34, 50), Text = "×",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = TEXT, AutoButtonColor = false}, secHead)
corner(closeBtn, 9)
new("Frame", {Size = UDim2.new(1, -48, 0, 1), Position = UDim2.fromOffset(24, 84), BackgroundColor3 = Color3.fromRGB(40, 40, 58), BorderSizePixel = 0}, card)

-- step 1: get key
local sec1 = section(96, 108)
label(sec1, "STEP 1  ·  Get your key", 11, Enum.Font.GothamBold, SUB, UDim2.fromOffset(24, 0), UDim2.fromOffset(300, 16))
local statusLbl = label(sec1, "", 12, Enum.Font.GothamMedium, GOOD, UDim2.fromOffset(24, 72), UDim2.fromOffset(372, 32))
statusLbl.TextTransparency = 1
local statusScale = new("UIScale", {}, statusLbl)

-- step 2: key + verify
local sec2 = section(212, 120)
label(sec2, "STEP 2  ·  Paste your key", 11, Enum.Font.GothamBold, SUB, UDim2.fromOffset(24, 0), UDim2.fromOffset(300, 16))
local keyBox = new("TextBox", {Position = UDim2.fromOffset(24, 22), Size = UDim2.fromOffset(372, 42), BackgroundColor3 = FIELD, PlaceholderText = "🔑  Paste your key here",
	PlaceholderColor3 = SUB, Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left}, sec2)
corner(keyBox, 12)
pad(keyBox, 14, 0, 14, 0)
local keyStroke = new("UIStroke", {Thickness = 1.5, Color = OFF, Transparency = .3}, keyBox)
keyBox.Focused:Connect(function() tween(keyStroke, .2, {Color = ACCENT2, Transparency = 0}) end)
keyBox.FocusLost:Connect(function() tween(keyStroke, .2, {Color = OFF, Transparency = .3}) end)

-- result line
local secRes = section(338, 28)
local resultLbl = label(secRes, "", 15, Enum.Font.GothamBold, TEXT, UDim2.fromOffset(24, 0), UDim2.fromOffset(372, 24), Enum.TextXAlignment.Center)
resultLbl.TextTransparency = 1
local resultScale = new("UIScale", {}, resultLbl)

-- buttons (hover glow + press squish + click ripple)
local function ripple(b)
	local m = UIS:GetMouseLocation()
	local k = math.max(win.AbsoluteSize.X / W, .01)
	local r = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .7, AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(0, 0),
		Position = UDim2.fromOffset((m.X - b.AbsolutePosition.X) / k, (m.Y - b.AbsolutePosition.Y) / k), ZIndex = 3}, b)
	corner(r, 999)
	tween(r, .55, {Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1})
	Debris:AddItem(r, .6)
end
local function makeButton(parent, text, pos, colors)
	local b = new("TextButton", {Position = pos, Size = UDim2.fromOffset(372, 44), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, ClipsDescendants = true}, parent)
	corner(b, 12)
	local g = new("UIGradient", {Color = colors, Rotation = 0}, b)
	local st = new("UIStroke", {Color = Color3.new(1, 1, 1), Transparency = .85, Thickness = 1.2}, b)
	local lbl = label(b, text, 15, Enum.Font.GothamBold, Color3.new(1, 1, 1), UDim2.new(), UDim2.fromScale(1, 1), Enum.TextXAlignment.Center)
	lbl.ZIndex = 4
	local sc = new("UIScale", {}, b)
	b.MouseEnter:Connect(function()
		tween(sc, .18, {Scale = 1.035}, Enum.EasingStyle.Back)
		tween(st, .18, {Transparency = .35})
		tween(g, .45, {Rotation = 25})
	end)
	b.MouseLeave:Connect(function()
		tween(sc, .18, {Scale = 1})
		tween(st, .18, {Transparency = .85})
		tween(g, .45, {Rotation = 0})
	end)
	b.MouseButton1Down:Connect(function() tween(sc, .1, {Scale = .965}) end)
	b.MouseButton1Up:Connect(function() tween(sc, .15, {Scale = 1.035}, Enum.EasingStyle.Back) end)
	return b, lbl
end
local getBtn, getLbl = makeButton(sec1, "🔑  Get Key", UDim2.fromOffset(24, 22), ColorSequence.new(ACCENT, ACCENT2))
local verifyBtn, verifyLbl = makeButton(sec2, "Verify Key", UDim2.fromOffset(24, 72), ColorSequence.new(ACCENT2, ACCENT))
closeBtn.MouseEnter:Connect(function() tween(closeBtn, .15, {BackgroundColor3 = Color3.fromRGB(220, 70, 85)}) end)
closeBtn.MouseLeave:Connect(function() tween(closeBtn, .15, {BackgroundColor3 = Color3.fromRGB(34, 34, 50)}) end)

---------------------------------------------------------------- behaviour
local closing, busy, lastTry = false, false, 0

local function setResult(text, color)
	resultLbl.Text = text
	resultLbl.TextColor3 = color
	resultLbl.TextTransparency = 1
	resultScale.Scale = .75
	tween(resultLbl, .25, {TextTransparency = 0})
	tween(resultScale, .4, {Scale = 1}, Enum.EasingStyle.Back)
end
local function setStatus(text, color)
	statusLbl.Text = text
	statusLbl.TextColor3 = color
	statusLbl.TextTransparency = 1
	statusScale.Scale = .9
	tween(statusLbl, .3, {TextTransparency = 0})
	tween(statusScale, .4, {Scale = 1}, Enum.EasingStyle.Back)
end
local function shake()
	task.spawn(function()
		for i = 1, 7 do
			pop.Position = UDim2.fromOffset((8 - i) * 2.2 * (i % 2 == 0 and 1 or -1), 0)
			task.wait(.04)
		end
		pop.Position = UDim2.new()
	end)
end
local function flash(color)
	strokeGrad.Enabled = false
	tween(stroke, .15, {Color = color})
	tween(halo, .15, {BackgroundColor3 = color, BackgroundTransparency = .8})
end
local function unflash()
	tween(halo, .4, {BackgroundColor3 = ACCENT, BackgroundTransparency = .88})
	tween(stroke, .3, {Color = Color3.new(1, 1, 1)})
	strokeGrad.Enabled = true
end

local function closeGate()
	if closing then return end
	closing = true
	tween(card, .35, {GroupTransparency = 1})
	tween(popScale, .4, {Scale = 1.08}, Enum.EasingStyle.Quint)
	tween(halo, .3, {BackgroundTransparency = 1})
	tween(backdrop, .4, {BackgroundTransparency = 1})
	tween(blur, .4, {Size = 0})
	task.delay(.55, function()
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		pcall(function() blur:Destroy() end)
		pcall(function() gui:Destroy() end)
	end)
end
env.HubKeyGateCleanup = function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() blur:Destroy() end)
	pcall(function() gui:Destroy() end)
end

local function onGranted(key)
	setResult("✅  Access granted", GOOD)
	flash(GOOD)
	pcall(function() if writefile then writefile(SAVE_FILE, key) end end)
	task.wait(1)
	local ok, err = pcall(function()
		local fn, cerr = loadstring(game:HttpGet(HUB_URL))
		assert(fn, cerr)
		fn()
	end)
	if ok then
		closeGate()
	else
		unflash()
		setResult("❗  Key accepted, but the hub couldn't load", WARN)
		warn("[Headless Hub] load error: " .. tostring(err))
		busy = false
	end
end

local function runVerify(key)
	if busy then return end
	busy = true
	local done = false
	task.spawn(function()
		local i = 0
		while not done do
			i = i % 3 + 1
			verifyLbl.Text = "Verifying" .. string.rep(".", i)
			task.wait(.28)
		end
		verifyLbl.Text = "Verify Key"
	end)
	local granted, reason = checkKey(key)
	done = true
	if granted == true then
		onGranted(key)
		return
	end
	if granted == false then
		setResult("❌  Access not granted", BAD)
	else
		setResult("❗  " .. tostring(reason), WARN)
	end
	flash(granted == false and BAD or WARN)
	shake()
	task.delay(.9, unflash)
	busy = false
end

getBtn.MouseButton1Click:Connect(function()
	ripple(getBtn)
	local copy = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
	local ok = false
	if copy then ok = pcall(copy, GET_KEY_URL) end
	if ok then
		getLbl.Text = "✅  Link copied"
		task.delay(1.6, function() if not closing then getLbl.Text = "🔑  Get Key" end end)
		setStatus("Copied link! Now paste it into your browser to get your key", GOOD)
	else
		setStatus("Your executor can't copy. Open this in your browser: " .. GET_KEY_URL, WARN)
	end
end)

local function verifyClick()
	if busy or closing then return end
	if os.clock() - lastTry < 1.2 then return end
	lastTry = os.clock()
	local key = (keyBox.Text:gsub("%s+", ""))
	if key == "" then
		setResult("❗  Paste your key first", WARN)
		shake()
		return
	end
	runVerify(key)
end
verifyBtn.MouseButton1Click:Connect(function() ripple(verifyBtn) verifyClick() end)
keyBox.FocusLost:Connect(function(enter) if enter then verifyClick() end end)
closeBtn.MouseButton1Click:Connect(closeGate)

---------------------------------------------------------------- animation loop + intro
local t0 = os.clock()
track(RunService.Heartbeat:Connect(function(dt)
	local t = os.clock() - t0
	strokeGrad.Rotation = (strokeGrad.Rotation + dt * 70) % 360
	logoRing.Size = UDim2.fromOffset(56 + math.sin(t * 2.4) * 5, 56 + math.sin(t * 2.4) * 5)
	logoRing.BackgroundTransparency = .84 + math.sin(t * 2.4) * .06
	for _, s in ipairs(specks) do
		s.y -= s.sp * dt
		if s.y < -.05 then s.y = 1.05 s.x = rng:NextNumber() end
		s.f.Position = UDim2.fromScale(s.x + math.sin(t * .7 + s.ph) * s.amp, s.y)
	end
end))

tween(backdrop, .5, {BackgroundTransparency = .35})
tween(blur, .6, {Size = 16})
tween(card, .5, {GroupTransparency = 0})
tween(popScale, .65, {Scale = 1}, Enum.EasingStyle.Back)
tween(halo, .9, {BackgroundTransparency = .88})
for i, pair in ipairs({{secHead, 0}, {sec1, 96}, {sec2, 212}, {secRes, 338}}) do
	task.delay(.15 + i * .1, function()
		tween(pair[1], .5, {GroupTransparency = 0, Position = UDim2.fromOffset(0, pair[2])})
	end)
end

-- a saved key from last time gets re-checked automatically
task.delay(1.2, function()
	local saved = readSaved()
	if saved and not closing then
		keyBox.Text = saved
		setResult("🔑  Checking your saved key...", SUB)
		runVerify(saved)
	end
end)
