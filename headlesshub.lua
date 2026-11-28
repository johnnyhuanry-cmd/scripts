loadstring([==[
-- Headless Hub v4.0
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local rng = Random.new()

local env = (getgenv and getgenv()) or _G
if env.MiniPanelCleanup then pcall(env.MiniPanelCleanup) end

local conns = {}
local function track(c) table.insert(conns, c) return c end
local sendState -- assigned in the sync section
local NT = {stats = {ok = false, status = "starting...", last = 0, ping = 0, polls = 0}, gv = -1, syncNow = false}

local RELAY_URL = "https://scripts-aktreyhub1.vercel.app/api/relay"   -- your relay (nothing is ever typed in chat)
local ROOM = (game.JobId ~= "" and game.JobId) or ("place" .. tostring(game.PlaceId))
local LASER_ID = ""            -- optional: your own laser loop, e.g. "rbxassetid://123456789"
local LASER_RANGE = 450
local MAX_ROCKS, MAX_SCORCH = 140, 260
local CLICK_ID, TOGGLE_ID = "rbxassetid://421058925", "rbxassetid://6895079853"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SND_HISS = "rbxasset://sounds/Rocket whoosh 01.wav"

-- icons (emoji). If one ever shows as a square on your device, swap it here.
local ICONS = {
	move = "🚀", combat = "🔥", visuals = "🌈", players = "👥", settings = "⚙️", owner = "👑",
	fly = "🚀", speed = "💨", cape = "🎭", travel = "🌍", noclip = "👻", tp = "📍",
	run = "🏃", jump = "🎈", moon = "🌙", afk = "💤", light = "💡", esp = "👤", fov = "🔭",
	laser = "👀", color = "🎨", width = "📏", volume = "🔊", ground = "💥",
	chat = "💬", hub = "⚡", hubusers = "📡", size = "🔍", net = "🌐", script = "🔧", unload = "🔌",
	tag = "📛", snow = "❄️", mark = "🎯", save = "💾", lock = "🔐",
}

---------------------------------------------------------------- utils
local function getParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok = pcall(function() return game.CoreGui:GetChildren() end)
	if ok then return game.CoreGui end
	return LP:WaitForChild("PlayerGui")
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
local function lerpAngle(a, b, t)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

---------------------------------------------------------------- presets, saved settings, theme
local ACCENTS = {
	{"Violet", Color3.fromRGB(124, 92, 255), Color3.fromRGB(70, 200, 255)},
	{"Crimson", Color3.fromRGB(255, 70, 100), Color3.fromRGB(255, 170, 90)},
	{"Emerald", Color3.fromRGB(40, 210, 130), Color3.fromRGB(90, 230, 255)},
	{"Gold", Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 120, 60)},
	{"Rose", Color3.fromRGB(255, 100, 190), Color3.fromRGB(150, 120, 255)},
}
local LASERS = {
	{"Heat vision red", Color3.fromRGB(255, 30, 20)}, {"Ice blue", Color3.fromRGB(60, 170, 255)}, {"Toxic green", Color3.fromRGB(60, 255, 120)},
	{"Royal purple", Color3.fromRGB(170, 80, 255)}, {"Gold", Color3.fromRGB(255, 205, 80)},
}
local CFG_FILE = "HeadlessHub_config.json"
local CFG = {
	sync = true, ground = true, cape = true, laserIdx = 1, laserWidth = 1, sfxVol = 1,
	flySpeed = 60, flyBoost = true,
	nametags = true, markers = true, markDist = 100, tagHeight = 3.9,
	accentIdx = 1, uiScale = 0,
	walkOn = false, walk = 32, jumpOn = false, jump = 90, infJump = false, gravOn = false, grav = 90,
	fovOn = false, fov = 70, esp = false, bright = false, antiAfk = true,
}
pcall(function()
	if readfile and isfile and isfile(CFG_FILE) then
		local t = HttpService:JSONDecode(readfile(CFG_FILE))
		for k, v in pairs(t) do
			if CFG[k] ~= nil and type(v) == type(CFG[k]) then CFG[k] = v end
		end
	end
end)
CFG.accentIdx = math.clamp(math.floor(CFG.accentIdx), 1, #ACCENTS)
CFG.laserIdx = math.clamp(math.floor(CFG.laserIdx), 1, #LASERS)
CFG.laserColor = LASERS[CFG.laserIdx][2]
local saveQueued = false
local function saveCfg()
	if saveQueued or not writefile then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		local t = {}
		for k, v in pairs(CFG) do
			local tv = type(v)
			if tv == "boolean" or tv == "number" or tv == "string" then t[k] = v end
		end
		pcall(function() writefile(CFG_FILE, HttpService:JSONEncode(t)) end)
	end)
end

local THEME = {
	bg = Color3.fromRGB(15, 15, 23), panel = Color3.fromRGB(21, 21, 31), card = Color3.fromRGB(29, 29, 43),
	cardHover = Color3.fromRGB(39, 39, 57), text = Color3.fromRGB(238, 238, 248), sub = Color3.fromRGB(150, 150, 176),
	off = Color3.fromRGB(60, 60, 80),
	accent = ACCENTS[CFG.accentIdx][2], accent2 = ACCENTS[CFG.accentIdx][3],
}
local accentReg, gradReg, accentHooks = {}, {}, {}
local function reg(obj, prop, key)
	table.insert(accentReg, {obj, prop, key or "accent"})
	obj[prop] = THEME[key or "accent"]
end
local function accentSeq()
	return ColorSequence.new({ColorSequenceKeypoint.new(0, THEME.accent), ColorSequenceKeypoint.new(.5, THEME.accent2), ColorSequenceKeypoint.new(1, THEME.accent)})
end
local function regGrad(g) table.insert(gradReg, g) g.Color = accentSeq() end
local function applyAccent(a, b)
	THEME.accent, THEME.accent2 = a, b
	for _, e in ipairs(accentReg) do
		if e[1].Parent then tween(e[1], .35, {[e[2]] = THEME[e[3]]}) end
	end
	for _, g in ipairs(gradReg) do if g.Parent then g.Color = accentSeq() end end
	for _, f in ipairs(accentHooks) do pcall(f) end
end

---------------------------------------------------------------- root gui, sounds, toasts
local gui = new("ScreenGui", {Name = "MiniPanel", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000, IgnoreGuiInset = true}, getParent())

local function sfx(id, speed, vol)
	local s = new("Sound", {SoundId = id, Volume = (vol or .6) * CFG.sfxVol, PlaybackSpeed = speed or 1}, gui)
	s:Play()
	Debris:AddItem(s, 2)
end

local toastHolder = new("Frame", {Size = UDim2.fromOffset(290, 400), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1}, gui)
new("UIListLayout", {Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder}, toastHolder)
local toastN = 0
local function toast(msg)
	toastN += 1
	local t = new("CanvasGroup", {Size = UDim2.fromOffset(280, 44), BackgroundColor3 = THEME.panel, GroupTransparency = 1, LayoutOrder = -toastN}, toastHolder)
	corner(t, 10)
	local bar = new("Frame", {Size = UDim2.new(0, 4, 1, 0), BorderSizePixel = 0}, t)
	reg(bar, "BackgroundColor3")
	new("TextLabel", {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1, Text = msg, TextColor3 = THEME.text, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true}, t)
	local sc = new("UIScale", {Scale = .85}, t)
	tween(t, .3, {GroupTransparency = 0})
	tween(sc, .4, {Scale = 1}, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		tween(t, .3, {GroupTransparency = 1})
		tween(sc, .3, {Scale = .85})
		Debris:AddItem(t, .4)
	end)
end
local say = toast

local UI = {}

local fxFolder = new("Folder", {Name = "MiniPanelFX"}, workspace)

local hissOK = false
task.spawn(function()
	local s = new("Sound", {SoundId = SND_HISS, Volume = 0}, gui)
	pcall(function() ContentProvider:PreloadAsync({s}) end)
	hissOK = s.TimeLength > 0
	s:Destroy()
end)

---------------------------------------------------------------- effect helpers (rocks, burn line, emitters)
local rocks, scorches = {}, {}

local function surfaceCF(pos, n)
	local ref = math.abs(n.Y) > .95 and Vector3.xAxis or Vector3.yAxis
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
	local s = (.2 + k * k * .9) * (big and 1.8 or 1)
	local r = Instance.new(rng:NextNumber() < .35 and "WedgePart" or "Part")
	r.Size = Vector3.new(s * rng:NextNumber(.7, 1.5), s * rng:NextNumber(.6, 1.2), s * rng:NextNumber(.7, 1.5))
	local shade = rng:NextNumber(.65, 1.15)
	r.Color = Color3.new(math.clamp(col.R * shade, 0, 1), math.clamp(col.G * shade, 0, 1), math.clamp(col.B * shade, 0, 1))
	r.Material = mat
	r.TopSurface, r.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	r.CanQuery, r.CanTouch, r.CastShadow = false, false, false
	r.CustomPhysicalProperties = PhysicalProperties.new(2, .6, .25)
	r.CFrame = CFrame.new(pos + n * .35 + Vector3.new(rng:NextNumber(-.4, .4), 0, rng:NextNumber(-.4, .4)))
		* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
	r.Parent = fxFolder
	local lateral = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * rng:NextNumber(8, 32)
	r.AssemblyLinearVelocity = n * rng:NextNumber(24, 70) + lateral
	r.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(-18, 18), rng:NextNumber(-18, 18))
	table.insert(rocks, r)
	if #rocks > MAX_ROCKS then
		local old = table.remove(rocks, 1)
		if old then old:Destroy() end
	end
	task.delay(rng:NextNumber(2.2, 4.2), function()
		if r.Parent then
			tween(r, .6, {Transparency = 1}, Enum.EasingStyle.Quad)
			Debris:AddItem(r, .7)
		end
	end)
end

-- continuous burn line (one flat segment between consecutive hit points)
local function spawnBurnSegment(a, b, n, w)
	local seg = b - a
	local len = seg.Magnitude
	local flat = seg - n * seg:Dot(n)
	if flat.Magnitude < .01 then return end
	flat = flat.Unit
	local mid = (a + b) / 2 + n * .04
	local cf = CFrame.fromMatrix(mid, n:Cross(flat), n, flat)
	local function part(color, mat, trans, width, y)
		return new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
			Material = mat, Color = color, Transparency = trans, Size = Vector3.new(width, .05, len + .25), CFrame = cf + n * y}, fxFolder)
	end
	local char = part(Color3.fromRGB(14, 10, 9), Enum.Material.SmoothPlastic, .1, .8 * w, 0)
	local glow = part(Color3.fromRGB(255, 165, 55), Enum.Material.Neon, .05, .34 * w, .03)
	tween(glow, 1.5, {Color = Color3.fromRGB(150, 25, 10), Transparency = 1}, Enum.EasingStyle.Quad)
	Debris:AddItem(glow, 1.6)
	table.insert(scorches, char)
	if #scorches > MAX_SCORCH then
		local old = table.remove(scorches, 1)
		if old then old:Destroy() end
	end
	task.delay(7, function()
		if char.Parent then
			tween(char, 1.5, {Transparency = 1})
			Debris:AddItem(char, 1.6)
		end
	end)
end

local function glowPart(color, trans, ball)
	return new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = color, Transparency = trans, Size = Vector3.new(.1, .1, .1),
		Shape = ball and Enum.PartType.Ball or Enum.PartType.Block}, fxFolder)
end

local function emitter(parent, cfg)
	return new("ParticleEmitter", {Texture = cfg.tex, Color = cfg.color, LightEmission = cfg.light, Size = cfg.size,
		Transparency = cfg.trans, Lifetime = cfg.life, Rate = cfg.rate, Speed = cfg.speed, SpreadAngle = cfg.spread,
		Acceleration = cfg.acc, Rotation = NumberRange.new(0, 360), EmissionDirection = Enum.NormalId.Top, Enabled = false}, parent)
end

local function layerSound(parent, id, speed, vol, positional, eq)
	local s = new("Sound", {SoundId = id, Looped = true, Volume = 0, PlaybackSpeed = speed, RollOffMode = Enum.RollOffMode.Linear,
		RollOffMinDistance = 10, RollOffMaxDistance = positional and 160 or 100000}, parent)
	if eq then new("EqualizerSoundEffect", {HighGain = eq[1], MidGain = eq[2], LowGain = eq[3]}, s) end
	s:Play()
	return {s = s, vol = vol}
end

---------------------------------------------------------------- Laser FX (used for you AND for other hub users)
local LaserFx = {}
LaserFx.__index = LaserFx

function LaserFx.new(soundParent, positional)
	local self = setmetatable({charge = 0, rockT = 0, bigT = 0, dwell = 0, em = {}, beams = {}, snds = {}, width = CFG.laserWidth}, LaserFx)
	local base = CFG.laserColor
	local midC = base:Lerp(Color3.new(1, 1, 1), .2)
	local coreC = base:Lerp(Color3.new(1, 1, 1), .85)
	for i = 1, 2 do
		self.beams[i] = {glow = glowPart(base, .72), mid = glowPart(midC, .2), core = glowPart(coreC, 0), flare = glowPart(base, .15, true)}
	end
	self.hp = new("Part", {Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(.4, .4, .4)}, fxFolder)
	self.light = new("PointLight", {Color = base:Lerp(Color3.fromRGB(255, 120, 60), .4), Range = 16, Brightness = 3}, self.hp)
	self.hot = glowPart(coreC, .1, true)
	local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	self.em.sparks = emitter(self.hp, {tex = SPARK, color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 80, 20)),
		light = 1, size = NumberSequence.new(.3, 0), trans = NumberSequence.new(0, 1), life = NumberRange.new(.25, .55),
		rate = 60, speed = NumberRange.new(16, 40), spread = Vector2.new(70, 70), acc = Vector3.new(0, -70, 0)})
	self.em.embers = emitter(self.hp, {tex = SPARK, color = ColorSequence.new(Color3.fromRGB(255, 170, 60)),
		light = 1, size = NumberSequence.new(.16, 0), trans = NumberSequence.new(0, 1), life = NumberRange.new(.8, 1.5),
		rate = 18, speed = NumberRange.new(5, 14), spread = Vector2.new(80, 80), acc = Vector3.new(0, 6, 0)})
	self.em.smoke = emitter(self.hp, {tex = SMOKE, color = ColorSequence.new(Color3.fromRGB(90, 85, 80)),
		light = 0, size = NumberSequence.new({NumberSequenceKeypoint.new(0, .7), NumberSequenceKeypoint.new(1, 3)}),
		trans = NumberSequence.new({NumberSequenceKeypoint.new(0, .55), NumberSequenceKeypoint.new(1, 1)}),
		life = NumberRange.new(.9, 1.6), rate = 14, speed = NumberRange.new(3, 8), spread = Vector2.new(35, 35), acc = Vector3.new(0, 5, 0)})
	self.em.dust = emitter(self.hp, {tex = SMOKE, color = ColorSequence.new(Color3.fromRGB(150, 140, 125)),
		light = 0, size = NumberSequence.new({NumberSequenceKeypoint.new(0, .8), NumberSequenceKeypoint.new(1, 3.2)}),
		trans = NumberSequence.new({NumberSequenceKeypoint.new(0, .45), NumberSequenceKeypoint.new(1, 1)}),
		life = NumberRange.new(.8, 1.3), rate = 14, speed = NumberRange.new(5, 12), spread = Vector2.new(55, 55), acc = Vector3.new(0, 2, 0)})
	-- sound: soft sizzle + low rumble (no wobble)
	if LASER_ID ~= "" then
		table.insert(self.snds, layerSound(soundParent, LASER_ID, 1, .5, positional))
	elseif hissOK then
		table.insert(self.snds, layerSound(soundParent, SND_HISS, 1.1, .4, positional, {4, 0, -2}))
		table.insert(self.snds, layerSound(soundParent, SND_HISS, .55, .36, positional, {-6, 2, 6}))
	else
		table.insert(self.snds, layerSound(soundParent, PING, .3, .18, positional, {0, 0, 2}))
	end
	return self
end

function LaserFx:update(dt, t, eyeL, eyeR, hitPos, normal, res, firing)
	if firing then self.charge = math.min(1, self.charge + dt / .16) else self.charge = math.max(0, self.charge - dt / .14) end
	local c, w0 = self.charge, self.width
	local eyes = {eyeL, eyeR}
	for i = 1, 2 do
		local b, from = self.beams[i], eyes[i]
		local dist = (hitPos - from).Magnitude
		if dist > .1 then
			local cf = CFrame.lookAt(from, hitPos) * CFrame.new(0, 0, -dist / 2)
			local w = math.max(c * w0 * (1 + math.sin(t * 60 + i * 2) * .06 + rng:NextNumber(-.03, .03)), .02)
			b.glow.Size = Vector3.new(.5 * w, .5 * w, dist)
			b.mid.Size = Vector3.new(.2 * w, .2 * w, dist)
			b.core.Size = Vector3.new(.07 * w, .07 * w, dist)
			b.glow.CFrame, b.mid.CFrame, b.core.CFrame = cf, cf, cf
		end
		local f = math.max(.4 * c * w0, .02)
		b.flare.Size = Vector3.new(f, f, f)
		b.flare.CFrame = CFrame.new(from)
	end

	local hitValid = res ~= nil
	local isChar = false
	if res then
		local m = res.Instance:FindFirstAncestorOfClass("Model")
		isChar = m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
	end
	self.hp.CFrame = surfaceCF(hitPos + normal * .1, normal)
	local hs = math.max(.3 * c * w0 * (1 + math.sin(t * 45) * .2) * (hitValid and 1 or 0), .02)
	self.hot.Size = Vector3.new(hs, hs, hs)
	self.hot.CFrame = CFrame.new(hitPos + normal * .1)
	self.light.Enabled = hitValid
	self.light.Brightness = 3 * c * (.85 + rng:NextNumber(0, .3))

	local on = firing and hitValid
	self.em.sparks.Enabled = on
	self.em.embers.Enabled = on
	self.em.smoke.Enabled = on and not isChar
	self.em.dust.Enabled = on and not isChar

	if on and not isChar and CFG.ground then
		local col, mat = surfaceLook(res)
		self.em.dust.Color = ColorSequence.new(col:Lerp(Color3.fromRGB(150, 140, 125), .35))
		local speed = self.prevHit and (hitPos - self.prevHit).Magnitude / math.max(dt, .001) or 99
		self.prevHit = hitPos
		if speed < 3 then self.dwell += dt else self.dwell = math.max(0, self.dwell - dt * 2) end
		if self.lastHit and self.lastN and self.lastN:Dot(normal) > .9 then
			local d = (hitPos - self.lastHit).Magnitude
			if d > 1 then
				if d < 16 then spawnBurnSegment(self.lastHit, hitPos, normal, w0) end
				self.lastHit = hitPos
			end
		else
			self.lastHit = hitPos
		end
		self.lastN = normal
		self.rockT += dt
		local n = 0
		while self.rockT >= .06 and n < 3 do
			self.rockT -= .06
			n += 1
			for _ = 1, rng:NextInteger(1, 2) do spawnRock(hitPos, normal, col, mat, false) end
		end
		if self.rockT > .3 then self.rockT = 0 end
		if self.dwell > .5 then
			self.bigT += dt
			if self.bigT >= .09 then
				self.bigT = 0
				spawnRock(hitPos, normal, col, mat, true)
			end
		end
	else
		self.lastHit, self.lastN, self.prevHit = nil, nil, nil
		self.dwell = 0
	end

	for i, l in ipairs(self.snds) do
		l.s.Volume = l.vol * c * CFG.sfxVol * (1 + math.sin(t * 3 + i) * .05)
	end
	return c
end

function LaserFx:destroy()
	for _, b in ipairs(self.beams) do
		for _, p in pairs(b) do p:Destroy() end
	end
	self.hot:Destroy()
	for _, e in pairs(self.em) do e.Enabled = false end
	self.light.Enabled = false
	Debris:AddItem(self.hp, 1.8)
	for _, l in ipairs(self.snds) do
		tween(l.s, .15, {Volume = 0})
		Debris:AddItem(l.s, .25)
	end
end

---------------------------------------------------------------- Superman flight visuals (pose + cape + trails), also used on other hub users
local JOINT_NAMES = {
	rs = {"RightShoulder", "Right Shoulder"}, ls = {"LeftShoulder", "Left Shoulder"},
	rh = {"RightHip", "Right Hip"}, lh = {"LeftHip", "Left Hip"}, neck = {"Neck"},
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
	local sway = math.sin(t * 2.2) * .04
	local function set(key, rot)
		local e = j[key]
		if e and e.m.Parent then e.m.C0 = CFrame.new(e.c0.Position) * rot * e.c0.Rotation end
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
	local top = torso.Name == "UpperTorso" and .72 or .9
	local cape = {segs = {}, welds = {}, top = top}
	local prev = torso
	for i = 1, SEG_COUNT do
		local seg = new("Part", {Name = "MiniPanelCape", Size = Vector3.new(1.9, SEG_LEN, .12), Color = Color3.fromRGB(200, 20, 30),
			Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false, CanTouch = false, Massless = true, CastShadow = false})
		local w = new("Weld", {Part0 = prev, Part1 = seg,
			C0 = i == 1 and CFrame.new(0, top, .55) or CFrame.new(0, -SEG_LEN / 2, 0), C1 = CFrame.new(0, SEG_LEN / 2, 0)}, seg)
		seg.Parent = char
		cape.segs[i], cape.welds[i] = seg, w
		prev = seg
	end
	return cape
end
local function updateCape(cp, p, t)
	for i, w in ipairs(cp.welds) do
		local flutter = math.sin(t * 7 - i * .9) * (.05 + .16 * p)
		local flare = -(.05 + .22 * p) * (i == 1 and 1.5 or .7) + flutter
		local side = math.sin(t * 4.1 - i * 1.3) * .05 * (.4 + p)
		if i == 1 then
			w.C0 = CFrame.new(0, cp.top, .55) * CFrame.Angles(flare, 0, side)
		else
			w.C0 = CFrame.new(0, -SEG_LEN / 2, 0) * CFrame.Angles(flare * .6, 0, side)
		end
	end
end
local function destroyCape(cp)
	for _, s in ipairs(cp.segs) do pcall(function() s:Destroy() end) end
end

local FV = {}
FV.__index = FV
function FV.new(char)
	local self = setmetatable({char = char, objs = {}}, FV)
	self.joints = grabJoints(char)
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local function ribbon(p0, p1, color, life)
			local a0 = new("Attachment", {Position = p0}, root)
			local a1 = new("Attachment", {Position = p1}, root)
			table.insert(self.objs, a0)
			table.insert(self.objs, a1)
			local tr = new("Trail", {Attachment0 = a0, Attachment1 = a1, Lifetime = life, MinLength = 0, LightEmission = .5, FaceCamera = false,
				Color = ColorSequence.new(color), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .5), NumberSequenceKeypoint.new(1, 1)}), Enabled = false}, root)
			table.insert(self.objs, tr)
			return tr
		end
		self.t1 = ribbon(Vector3.new(1.3, 0, 0), Vector3.new(-1.3, 0, 0), Color3.fromRGB(235, 245, 255), .4)
		self.t2 = ribbon(Vector3.new(0, 0, 1.3), Vector3.new(0, 0, -1.3), Color3.fromRGB(150, 200, 255), .55)
	end
	return self
end
function FV:update(p, t, speed)
	if self.joints then applyPose(self.joints, p, t) end
	if CFG.cape and not self.cape then
		self.cape = makeCape(self.char)
	elseif not CFG.cape and self.cape then
		destroyCape(self.cape)
		self.cape = nil
	end
	if self.cape then updateCape(self.cape, p, t) end
	if self.t1 then self.t1.Enabled = speed > 32 end
	if self.t2 then self.t2.Enabled = speed > 55 end
end
function FV:destroy()
	if self.joints then
		for _, e in pairs(self.joints) do
			if e.m.Parent then e.m.C0 = e.c0 end
		end
	end
	if self.cape then destroyCape(self.cape) end
	for _, o in ipairs(self.objs) do pcall(function() o:Destroy() end) end
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
local TP_BLUR_MAX, TP_FOV_MAX = 26, 26
local tpEnabled = false
local tpTool
local flyVel = Vector3.zero
local tpBlur = new("BlurEffect", {Name = "MiniPanelBlur", Size = 0, Enabled = false}, Lighting)
local tpConn, blurTween, fovTween, tpBaseFov, trailObjs

local function ease(a)
	if a < .5 then return 4 * a * a * a end
	return 1 - ((-2 * a + 2) ^ 3) / 2
end
local function dropTrail(immediate)
	if not trailObjs then return end
	for _, o in ipairs(trailObjs) do
		if o:IsA("Trail") then o.Enabled = false end
		if immediate then pcall(function() o:Destroy() end) else Debris:AddItem(o, .7) end
	end
	trailObjs = nil
end
local function makeTrail(root)
	dropTrail(true)
	local a0 = new("Attachment", {Position = Vector3.new(0, 1.4, 0)}, root)
	local a1 = new("Attachment", {Position = Vector3.new(0, -1.4, 0)}, root)
	local tr = new("Trail", {Attachment0 = a0, Attachment1 = a1, Lifetime = .4, MinLength = 0, LightEmission = 1, FaceCamera = true,
		Color = ColorSequence.new(THEME.accent2, THEME.accent),
		Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, .15), NumberSequenceKeypoint.new(1, 1)}),
		WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})}, root)
	trailObjs = {a0, a1, tr}
end
local function pulseRing(pos)
	local ring = new("Part", {Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Material = Enum.Material.Neon, Color = THEME.accent2, Transparency = .2, Size = Vector3.new(.2, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, .15, 0)) * CFrame.Angles(0, 0, math.rad(90))}, workspace)
	tween(ring, .7, {Size = Vector3.new(.2, 9, 9), Transparency = 1})
	Debris:AddItem(ring, .8)
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
		fovTween = tween(cam, .45, {FieldOfView = tpBaseFov}, Enum.EasingStyle.Quad)
		fovTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and not tpConn then tpBaseFov = nil end
		end)
	end
	blurTween = tween(tpBlur, .35, {Size = 0}, Enum.EasingStyle.Quad)
	blurTween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not tpConn then tpBlur.Enabled = false end
	end)
	sfx(CLICK_ID, .7, .5)
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
	local lift = (hum and hum.HipHeight or 2) + root.Size.Y / 2 + .5
	local goal = pos + Vector3.new(0, lift, 0)
	local start = root.Position
	local dist = (goal - start).Magnitude
	if dist < 1 then return end
	if tpConn then tpConn:Disconnect() tpConn = nil end
	if blurTween then blurTween:Cancel() end
	if fovTween then fovTween:Cancel() end
	pulseRing(pos)
	sfx(TOGGLE_ID, 1.7, .45)
	makeTrail(root)
	local dur = math.clamp(.35 + dist / 450, .4, 1.5)
	local arc = dist > 12 and math.clamp(dist * .1, 3, 35) or 0
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
		if not root.Parent then finishTeleport(nil) return end
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
	local t = new("Tool", {Name = "Click TP", ToolTip = "Equip, then click/tap anywhere to teleport", RequiresHandle = false, CanBeDropped = false})
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
		say("Click TP ON: equip the tool, then click the ground")
	else
		removeTool()
		cancelTeleport()
		say("Click TP OFF")
	end
end
track(LP.CharacterAdded:Connect(function()
	if tpEnabled then task.wait(.5) removeTool() giveTool() end
end))

---------------------------------------------------------------- Hide system
local hidden = {}
local origVolume = setmetatable({}, {__mode = "k"})
local origDisplay = setmetatable({}, {__mode = "k"})
local function applyHide(plr)
	local char = plr.Character
	if char then
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1
			elseif d:IsA("Sound") then
				if origVolume[d] == nil then origVolume[d] = d.Volume end
				d.Volume = 0
			elseif d:IsA("BillboardGui") then d.Enabled = false
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
			if d:IsA("BasePart") then d.LocalTransparencyModifier = 0
			elseif d:IsA("Decal") or d:IsA("Texture") then
				if d.Name == "face" then d.Transparency = 0 end
			elseif d:IsA("Sound") then d.Volume = origVolume[d] or .5
			elseif d:IsA("BillboardGui") then d.Enabled = true
			elseif d:IsA("Humanoid") then d.DisplayDistanceType = origDisplay[d] or Enum.HumanoidDisplayDistanceType.Viewer
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
		task.wait(.4)
	end
end)

local function findPlayer(query)
	query = (query or ""):lower()
	if query == "" then return nil, "Type a name." end
	local tiers = {{}, {}, {}}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			local n, d = p.Name:lower(), p.DisplayName:lower()
			if n == query or d == query then table.insert(tiers[1], p)
			elseif n:sub(1, #query) == query or d:sub(1, #query) == query then table.insert(tiers[2], p)
			elseif n:find(query, 1, true) or d:find(query, 1, true) then table.insert(tiers[3], p) end
		end
	end
	for _, list in ipairs(tiers) do
		if #list == 1 then return list[1] end
		if #list > 1 then
			local names = {}
			for _, p in ipairs(list) do table.insert(names, p.Name) end
			return nil, "Multiple matches: " .. table.concat(names, ", ")
		end
	end
	return nil, "No player found for '" .. query .. "'"
end
local function tpToPlayer(plr)
	local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	local theirRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and theirRoot then
		myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 3)
		return true
	end
	return false
end
local lastRun, lastText = 0, ""
local function runCommand(text)
	text = ((text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
	if text:sub(1, 1) ~= "!" then return end
	if text == lastText and tick() - lastRun < .4 then return end
	lastText, lastRun = text, tick()
	local cmd, arg = text:match("^!(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "to" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		say(tpToPlayer(plr) and ("Teleported to " .. plr.Name) or (plr.Name .. " has no character yet"))
	elseif cmd == "hide" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		hidden[plr.UserId] = true
		applyHide(plr)
		say("Hidden: " .. plr.Name)
	elseif cmd == "unhide" then
		local plr, err = findPlayer(arg)
		if not plr then return say(err) end
		hidden[plr.UserId] = nil
		applyUnhide(plr)
		say("Unhidden: " .. plr.Name)
	else
		say("Unknown command. Try !to, !hide, !unhide")
	end
end

---------------------------------------------------------------- Superman fly (local)
local flyEnabled = false
local FLY_MIN, FLY_MAX = 10, 250
local flyConn, flyObjs, flyFV, flyAnim
local flyPose = 0
local lastFlat = Vector3.new(0, 0, -1)
local upHeld, downHeld = false, false

local function stopFly()
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyObjs then
		for _, o in pairs(flyObjs) do pcall(function() o:Destroy() end) end
		flyObjs =
