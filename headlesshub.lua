loadstring([==[
-- Headless Hub v3.1  (nametags + far markers)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local rng = Random.new()

local env = (getgenv and getgenv()) or _G
if env.MiniPanelCleanup then pcall(env.MiniPanelCleanup) end

local conns = {}
local function track(c) table.insert(conns, c) return c end
local sendState -- assigned in the sync section
local NT = {}    -- nametag + marker module (filled in below)

local LASER_ID = ""            -- optional: your own laser loop, e.g. "rbxassetid://123456789"
local LASER_RANGE = 450
local MAX_ROCKS, MAX_SCORCH = 140, 260
local CLICK_ID, TOGGLE_ID = "rbxassetid://421058925", "rbxassetid://6895079853"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local SND_HISS = "rbxasset://sounds/Rocket whoosh 01.wav"

-- icons (emoji). If one ever shows as a square on your device, swap it here.
local ICONS = {
	move = "🚀", combat = "🔥", players = "👥", settings = "⚙️",
	fly = "🚀", speed = "💨", cape = "🎭", travel = "🌍", noclip = "👻", tp = "📍",
	laser = "👀", color = "🎨", width = "📏", volume = "🔊", ground = "💥",
	chat = "💬", hub = "⚡", hubusers = "📡", size = "🔍", net = "🌐", script = "🔧", unload = "🔌",
	tag = "📛", snow = "❄️", mark = "🎯",
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

---------------------------------------------------------------- config + theme
local CFG = {
	sync = true, ground = true, cape = true,
	laserColor = Color3.fromRGB(255, 30, 20), laserWidth = 1, sfxVol = 1,
	flySpeed = 60,
	nametags = true, markers = true, markDist = 100, tagHeight = 3.9, previewCustom = false,
}
local THEME = {
	bg = Color3.fromRGB(15, 15, 23), panel = Color3.fromRGB(21, 21, 31), card = Color3.fromRGB(29, 29, 43),
	cardHover = Color3.fromRGB(39, 39, 57), text = Color3.fromRGB(238, 238, 248), sub = Color3.fromRGB(150, 150, 176),
	off = Color3.fromRGB(60, 60, 80),
	accent = Color3.fromRGB(124, 92, 255), accent2 = Color3.fromRGB(70, 200, 255),
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
		flyObjs = nil
	end
	if flyFV then flyFV:destroy() flyFV = nil end
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
	local att = new("Attachment", {Name = "FlyAttachment"}, root)
	local lv = new("LinearVelocity", {Attachment0 = att, RelativeTo = Enum.ActuatorRelativeTo.World,
		VelocityConstraintMode = Enum.VelocityConstraintMode.Vector, MaxForce = math.huge, VectorVelocity = Vector3.zero}, root)
	local ao = new("AlignOrientation", {Attachment0 = att, Mode = Enum.OrientationAlignmentMode.OneAttachment,
		MaxTorque = math.huge, Responsiveness = 28, CFrame = root.CFrame.Rotation}, root)
	flyObjs = {att, lv, ao}
	flyVel = root.AssemblyLinearVelocity
	hum.PlatformStand = true
	flyFV = FV.new(char)
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
			if md.Magnitude > .05 then
				local fl = Vector3.new(look.X, 0, look.Z)
				local fr = Vector3.new(right.X, 0, right.Z)
				if fl.Magnitude > .01 and fr.Magnitude > .01 then
					z = md:Dot(fl.Unit)
					x = md:Dot(fr.Unit)
				end
			end
		end
		local dir = right * x + look * z + Vector3.new(0, y, 0)
		if dir.Magnitude > 1 then dir = dir.Unit end
		flyVel = flyVel:Lerp(dir * CFG.flySpeed, 1 - math.exp(-dt * 7))
		lv.VectorVelocity = flyVel
		local speed = flyVel.Magnitude

		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > .02 then flat = flat.Unit lastFlat = flat else flat = lastFlat end

		local fwd = speed > 1 and flyVel.Unit:Dot(look) or 0
		local pTarget = math.clamp((speed - 6) / 18, 0, 1) * math.clamp((fwd + .15) / .45, 0, 1)
		flyPose += (pTarget - flyPose) * (1 - math.exp(-dt * 5))

		local goal = CFrame.lookAt(Vector3.zero, flat)
		if flyPose > .02 and speed > 1 then
			local dirV = flyVel.Unit
			local A = Vector3.yAxis - dirV * Vector3.yAxis:Dot(dirV)
			local nf = -flat
			local B = nf - dirV * nf:Dot(dirV)
			local perp = A + B
			if perp.Magnitude > .05 then
				perp = perp.Unit
				goal = goal:Lerp(CFrame.fromMatrix(Vector3.zero, dirV:Cross(perp), dirV, perp), flyPose)
			end
		end
		ao.CFrame = goal

		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do tr:Stop(.1) end
		end
		if flyFV then flyFV:update(flyPose, os.clock(), speed) end
	end)
	return true
end

local function setFly(on)
	flyEnabled = on
	if on then
		if startFly() then
			say("Fly ON: WASD + Space/Ctrl. Fly forward for the Superman pose")
		else
			flyEnabled = false
			say("No character to fly with yet")
			task.defer(function() if UI.fly then UI.fly.set(false) end end)
		end
	else
		stopFly()
		say("Fly OFF")
	end
	if sendState then sendState() end
end
track(LP.CharacterAdded:Connect(function()
	if flyEnabled then
		task.wait(.6)
		if flyEnabled then startFly() end
	end
end))

---------------------------------------------------------------- Laser Eyes (local)
local laserEnabled, laserTool, laserConn, lfx = false, nil, nil, nil
local firing = false
local aimYaw, aimPitch = 0, 0
local lastYaw, lastPitch, lastAimTime = 0, 0, 0

local function stopLaserLocal()
	if laserConn then laserConn:Disconnect() laserConn = nil end
	if lfx then lfx:destroy() lfx = nil end
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = Vector3.zero
		hum.AutoRotate = true
	end
end

local function laserStep(dt)
	local char = LP.Character
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (lfx and head and hum and root) then stopLaserLocal() return end
	if hum.Health <= 0 then firing = false end
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local ray = cam:ScreenPointToRay(Mouse.X, Mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char, fxFolder}
	params.IgnoreWater = true
	local aimRes = workspace:Raycast(ray.Origin, ray.Direction * LASER_RANGE, params)
	local aimPos = aimRes and aimRes.Position or (ray.Origin + ray.Direction * LASER_RANGE)
	local eyeL = head.CFrame * Vector3.new(-.2, .12, -.52)
	local eyeR = head.CFrame * Vector3.new(.2, .12, -.52)
	local mid = (eyeL + eyeR) / 2
	local dir = aimPos - mid
	if dir.Magnitude < .5 then dir = head.CFrame.LookVector end
	dir = dir.Unit
	local res = workspace:Raycast(mid, dir * LASER_RANGE, params)
	local hitPos = res and res.Position or (mid + dir * LASER_RANGE)
	local normal = res and res.Normal or -dir
	aimYaw = math.atan2(-dir.X, -dir.Z)
	aimPitch = math.asin(math.clamp(dir.Y, -1, 1))

	local c = lfx:update(dt, t, eyeL, eyeR, hitPos, normal, res, firing)

	hum.CameraOffset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * .05 * c
	if not flyEnabled and not root.Anchored then
		hum.AutoRotate = false
		local flatDir = Vector3.new(dir.X, 0, dir.Z)
		if flatDir.Magnitude > .05 then
			local goal = CFrame.lookAt(Vector3.zero, flatDir.Unit)
			root.CFrame = CFrame.new(root.Position) * root.CFrame.Rotation:Lerp(goal, 1 - math.exp(-dt * 16))
		end
	end
	if firing and t - lastAimTime > 1.3 then
		local dy = math.abs((aimYaw - lastYaw + math.pi) % (2 * math.pi) - math.pi)
		if dy > .1 or math.abs(aimPitch - lastPitch) > .09 then
			lastYaw, lastPitch, lastAimTime = aimYaw, aimPitch, t
			if sendState then sendState() end
		end
	end
	if c <= 0 and not firing then stopLaserLocal() end
end

local function setFiring(v)
	if firing == v then return end
	firing = v
	if sendState then sendState() end
end
local function startLaser()
	if not lfx then lfx = LaserFx.new(gui, false) end
	if not laserConn then laserConn = RunService.RenderStepped:Connect(laserStep) end
	firing = true
	laserStep(1 / 60)
	lastYaw, lastPitch, lastAimTime = aimYaw, aimPitch, os.clock()
	if sendState then sendState() end
end
local function removeLaserTool()
	setFiring(false)
	if laserTool then laserTool:Destroy() laserTool = nil end
end
local function giveLaserTool()
	if laserTool and laserTool.Parent then return end
	local t = new("Tool", {Name = "Laser Eyes", ToolTip = "Equip, then hold left click / tap to fire", RequiresHandle = false, CanBeDropped = false})
	t.Activated:Connect(function() if laserEnabled then startLaser() end end)
	t.Deactivated:Connect(function() setFiring(false) end)
	t.Unequipped:Connect(function() setFiring(false) end)
	laserTool = t
	t.Parent = LP:FindFirstChildOfClass("Backpack") or LP:WaitForChild("Backpack")
end
local function setLaser(on)
	laserEnabled = on
	if on then
		giveLaserTool()
		say("Laser Eyes ON: equip the tool, hold left click")
	else
		removeLaserTool()
		say("Laser Eyes OFF")
	end
end
track(LP.CharacterAdded:Connect(function()
	if laserEnabled then task.wait(.5) removeLaserTool() giveLaserTool() end
end))

---------------------------------------------------------------- Sync with other hub users (hidden chat packets)
local Z0, Z1 = "\u{200B}", "\u{200C}"
local function encodePacket(fly, laser, hello, yaw, pitch)
	local bits = {1, 0, 1, 1, 0, 1, fly and 1 or 0, laser and 1 or 0, hello and 1 or 0}
	local y8 = math.floor(((yaw % (2 * math.pi)) / (2 * math.pi)) * 256) % 256
	for i = 7, 0, -1 do bits[#bits + 1] = bit32.extract(y8, i) end
	local p6 = math.clamp(math.floor((pitch + math.pi / 2) / math.pi * 63 + .5), 0, 63)
	for i = 5, 0, -1 do bits[#bits + 1] = bit32.extract(p6, i) end
	local par = 0
	for _, b in ipairs(bits) do par = bit32.bxor(par, b) end
	bits[#bits + 1] = par
	local out = {}
	for i, b in ipairs(bits) do out[i] = b == 1 and Z1 or Z0 end
	return table.concat(out)
end
local function decodePacket(text)
	if type(text) ~= "string" or #text < 20 or #text > 120 then return nil end
	local bits = {}
	local ok = pcall(function()
		for _, cp in utf8.codes(text) do
			if cp == 0x200B then bits[#bits + 1] = 0
			elseif cp == 0x200C then bits[#bits + 1] = 1
			else bits = nil return end
		end
	end)
	if not ok or not bits or #bits ~= 24 then return nil end
	local magic = {1, 0, 1, 1, 0, 1}
	for i = 1, 6 do if bits[i] ~= magic[i] then return nil end end
	local par = 0
	for i = 1, 23 do par = bit32.bxor(par, bits[i]) end
	if par ~= bits[24] then return nil end
	local function num(a, b)
		local v = 0
		for i = a, b do v = v * 2 + bits[i] end
		return v
	end
	return {fly = bits[7] == 1, laser = bits[8] == 1, hello = bits[9] == 1,
		yaw = num(10, 17) / 256 * 2 * math.pi, pitch = num(18, 23) / 63 * math.pi - math.pi / 2}
end
local function chatSend(msg)
	local ok = pcall(function()
		local ch = TextChatService:FindFirstChild("TextChannels")
		ch = ch and ch:FindFirstChild("RBXGeneral")
		assert(ch)
		ch:SendAsync(msg)
	end)
	if not ok then
		pcall(function()
			game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
		end)
	end
end

local lastSend, pending, wantHello = 0, false, false
sendState = function(hello)
	if hello then wantHello = true end
	if not CFG.sync or pending then return end
	pending = true
	task.delay(math.max(0, 1.2 - (os.clock() - lastSend)), function()
		pending = false
		if not CFG.sync then return end
		lastSend = os.clock()
		local h = wantHello
		wantHello = false
		chatSend(encodePacket(flyEnabled, firing, h, aimYaw, aimPitch))
	end)
end

local peers = {}
local peersChanged = function() end
local function dropPeer(uid)
	local pr = peers[uid]
	if not pr then return end
	if pr.fv then pr.fv:destroy() end
	if pr.lfx then pr.lfx:destroy() end
	peers[uid] = nil
	if NT.destroy then NT.destroy(uid) end
	peersChanged()
end
local function handlePacket(uid, pkt)
	if not CFG.sync then return end
	local plr = Players:GetPlayerByUserId(uid)
	if not plr or plr == LP then return end
	local pr = peers[uid]
	if not pr then
		pr = {vel = Vector3.zero, pose = 0, yaw = 0, pitch = 0, yawMsg = 0, pitchMsg = 0}
		peers[uid] = pr
		peersChanged()
	end
	if pkt.laser and not pr.laser then pr.yaw, pr.pitch = pkt.yaw, pkt.pitch end
	pr.flying, pr.laser = pkt.fly, pkt.laser
	pr.yawMsg, pr.pitchMsg = pkt.yaw, pkt.pitch
	-- everyone answers a newcomer's hello so each hub user learns who else has the script
	if pkt.hello then
		task.delay(rng:NextNumber(.8, 6), function() sendState() end)
	end
end

local function peerStep(dt)
	local now = os.clock()
	for uid, pr in pairs(peers) do
		local plr = Players:GetPlayerByUserId(uid)
		if not plr then
			dropPeer(uid)
		else
			local char = plr.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local head = char and char:FindFirstChild("Head")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local ok = CFG.sync and not hidden[uid] and root and head and hum and hum.Health > 0
			if pr.char ~= char then
				if pr.fv then pr.fv:destroy() pr.fv = nil end
				if pr.lfx then pr.lfx:destroy() pr.lfx = nil end
				pr.char, pr.lastPos, pr.pose = char, nil, 0
			end
			if root and pr.lastPos and dt > 0 then
				pr.vel = pr.vel:Lerp((root.Position - pr.lastPos) / dt, 1 - math.exp(-dt * 10))
			end
			pr.lastPos = root and root.Position

			-- flying: cape, pose, trails
			if ok and pr.flying then
				if not pr.fv then pr.fv = FV.new(char) end
				local speed = pr.vel.Magnitude
				local pT = 0
				if speed > 6 then
					local align = root.CFrame.UpVector:Dot(pr.vel.Unit)
					pT = math.clamp((speed - 6) / 18, 0, 1) * math.clamp((align - .3) / .5, 0, 1)
				end
				pr.pose += (pT - pr.pose) * (1 - math.exp(-dt * 5))
				pr.fv:update(pr.pose, now, speed)
			elseif pr.fv then
				pr.fv:destroy()
				pr.fv, pr.pose = nil, 0
			end

			-- laser eyes
			local active = ok and pr.laser
			if active and not pr.lfx then pr.lfx = LaserFx.new(head, true) end
			if pr.lfx then
				if not ok then
					pr.lfx:destroy()
					pr.lfx = nil
				else
					if pr.flying then
						pr.yaw = lerpAngle(pr.yaw, pr.yawMsg, 1 - math.exp(-dt * 6))
					else
						local lv = root.CFrame.LookVector
						pr.yaw = math.atan2(-lv.X, -lv.Z)
					end
					pr.pitch += (pr.pitchMsg - pr.pitch) * (1 - math.exp(-dt * 6))
					local dir = (CFrame.Angles(0, pr.yaw, 0) * CFrame.Angles(pr.pitch, 0, 0)).LookVector
					local eyeL = head.CFrame * Vector3.new(-.2, .12, -.52)
					local eyeR = head.CFrame * Vector3.new(.2, .12, -.52)
					local mid = (eyeL + eyeR) / 2
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = {char, LP.Character, fxFolder}
					params.IgnoreWater = true
					local res = workspace:Raycast(mid, dir * LASER_RANGE, params)
					local hitPos = res and res.Position or (mid + dir * LASER_RANGE)
					local normal = res and res.Normal or -dir
					local c = pr.lfx:update(dt, now, eyeL, eyeR, hitPos, normal, res, active)
					if not active and c <= 0 then
						pr.lfx:destroy()
						pr.lfx = nil
					end
				end
			end
		end
	end
end
track(RunService.RenderStepped:Connect(peerStep))

pcall(function()
	TextChatService.OnIncomingMessage = function(msg)
		local props = Instance.new("TextChatMessageProperties")
		local src = msg.TextSource
		if src then
			local pkt = decodePacket(msg.Text)
			if pkt then
				props.Text = ""
				props.PrefixText = ""
				if src.UserId ~= LP.UserId then handlePacket(src.UserId, pkt) end
				return props
			end
			if hidden[src.UserId] or (src.UserId == LP.UserId and msg.Text:sub(1, 1) == "!") then props.Text = "" end
		end
		return props
	end
end)
local function hookLegacy(plr)
	track(plr.Chatted:Connect(function(m)
		local pkt = decodePacket(m)
		if pkt and plr ~= LP then handlePacket(plr.UserId, pkt) end
	end))
end
for _, p in ipairs(Players:GetPlayers()) do hookLegacy(p) end
track(Players.PlayerAdded:Connect(hookLegacy))
track(Players.PlayerRemoving:Connect(function(p) dropPeer(p.UserId) end))
pcall(function() track(TextChatService.SendingMessage:Connect(function(m) runCommand(m.Text) end)) end)
pcall(function() track(LP.Chatted:Connect(runCommand)) end)

task.delay(3, function() sendState(true) end)
task.spawn(function()
	while gui.Parent do
		task.wait(20)
		if CFG.sync and (flyEnabled or firing) then sendState() end
	end
end)

---------------------------------------------------------------- Nametags + far markers (only hub users see these)
-- Who gets the red/white snow "Hub Tr3y" tag: usernames (any case) or UserIds. Everyone else gets the grey "Hub User" tag.
NT.users = {"trey"}
NT.name = "Hub Tr3y"
NT.subjects = {}
NT.W, NT.H = 224, 50
NT.RED = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(196, 18, 38)), ColorSequenceKeypoint.new(.4, Color3.fromRGB(228, 52, 66)),
	ColorSequenceKeypoint.new(.75, Color3.fromRGB(250, 214, 220)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})
NT.GREY = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(112, 112, 122)), ColorSequenceKeypoint.new(.45, Color3.fromRGB(176, 176, 186)),
	ColorSequenceKeypoint.new(.8, Color3.fromRGB(232, 232, 238)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
})

function NT.isCustom(plr, isSelf)
	for _, v in ipairs(NT.users) do
		if type(v) == "number" then
			if plr.UserId == v then return true end
		elseif plr.Name:lower() == tostring(v):lower() then
			return true
		end
	end
	return (isSelf and CFG.previewCustom) or false
end

function NT.makeFlakes(parent, n, x0, x1, h, zi, smax)
	local fl = {}
	for i = 1, n do
		local sz = rng:NextNumber(2.2, smax)
		local f = new("Frame", {Size = UDim2.fromOffset(sz, sz), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = rng:NextNumber(0, .2), BorderSizePixel = 0, ZIndex = zi}, parent)
		corner(f, 4)
		new("UIStroke", {Color = Color3.fromRGB(165, 190, 228), Thickness = .7, Transparency = .3}, f)
		fl[i] = {f = f, x = rng:NextNumber(x0, x1), y = rng:NextNumber(0, h), sp = rng:NextNumber(14, 30),
			ph = rng:NextNumber(0, 6), amp = rng:NextNumber(2, 5), x0 = x0, x1 = x1, h = h}
	end
	return fl
end
function NT.stepFlakes(fl, dt, t)
	for _, s in ipairs(fl) do
		s.y += s.sp * dt
		if s.y > s.h + 5 then
			s.y = -6
			s.x = rng:NextNumber(s.x0, s.x1)
		end
		s.f.Position = UDim2.fromOffset(s.x + math.sin(t * 2 + s.ph) * s.amp, s.y)
	end
end

-- the billboard nametag above a hub user's head
NT.Tag = {}
NT.Tag.__index = NT.Tag
function NT.Tag.new(plr, head, custom)
	local W, H = NT.W, NT.H
	local self = setmetatable({plr = plr, custom = custom, phase = rng:NextNumber(0, 6), ts = {phase = "type", n = 0, timer = 0}}, NT.Tag)
	local bb = new("BillboardGui", {Name = "HubTag", Adornee = head, Size = UDim2.fromOffset(W, H), AlwaysOnTop = true, LightInfluence = 0,
		StudsOffset = Vector3.new(0, CFG.tagHeight, 0), MaxDistance = 1000000, Enabled = false}, head)
	self.bb = bb
	local pill = new("Frame", {AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true}, bb)
	corner(pill, 21)
	new("UIStroke", {Color = custom and Color3.fromRGB(8, 8, 10) or Color3.fromRGB(34, 34, 40), Thickness = 2.2}, pill)
	self.grad = new("UIGradient", {Color = custom and NT.RED or NT.GREY}, pill)
	self.scale = new("UIScale", {}, pill)

	self.shine = new("Frame", {Size = UDim2.fromOffset(14, 70), AnchorPoint = Vector2.new(.5, .5), Rotation = 20,
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .72, BorderSizePixel = 0, ZIndex = 2}, pill)

	if custom then
		self.flakes = NT.makeFlakes(pill, 16, 46, 190, 42, 3, 5)
	end

	local ring = new("Frame", {Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = custom and Color3.fromRGB(205, 24, 42) or Color3.fromRGB(140, 140, 150), BorderSizePixel = 0, ZIndex = 4}, pill)
	corner(ring, 18)
	new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.5}, ring)
	local av = new("ImageLabel", {Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.fromRGB(230, 230, 236),
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(plr.UserId), BorderSizePixel = 0, ZIndex = 5}, ring)
	corner(av, 15)

	self.l1 = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 2), Size = UDim2.new(1, -52, 0, 22),
		Text = custom and "" or "Hub User", Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = custom and Color3.fromRGB(28, 8, 14) or Color3.fromRGB(36, 36, 44),
		TextStrokeColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = .55, ZIndex = 6}, pill)
	new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(46, 23), Size = UDim2.new(1, -52, 0, 15),
		Text = "@" .. plr.Name, Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = custom and Color3.fromRGB(92, 60, 68) or Color3.fromRGB(88, 88, 100),
		TextStrokeColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = .6, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6}, pill)
	return self
end
function NT.Tag:update(dt, t, near, dist)
	self.bb.Enabled = near
	if not near then return end
	self.bb.StudsOffset = Vector3.new(0, CFG.tagHeight, 0)
	self.scale.Scale = math.clamp(1.1 - (dist - 8) / 150, .55, 1)
	self.grad.Offset = Vector2.new(math.sin(t * 1.3 + self.phase) * .18, 0)
	local f = (t * .4 + self.phase) % 2.8
	self.shine.Position = UDim2.fromOffset(-30 + f * 270, 21)
	if self.custom then
		-- types "Hub Tr3y" slowly, holds, deletes it letter by letter, then types it again
		local s = self.ts
		local name = NT.name
		s.timer += dt
		if s.phase == "type" then
			if s.timer >= .17 then
				s.timer = 0
				s.n += 1
				if s.n >= #name then s.n = #name s.phase = "hold" end
			end
		elseif s.phase == "hold" then
			if s.timer >= 1.8 then s.phase = "delete" s.timer = 0 end
		elseif s.phase == "delete" then
			if s.timer >= .11 then
				s.timer = 0
				s.n -= 1
				if s.n <= 0 then s.n = 0 s.phase = "empty" end
			end
		else
			if s.timer >= .6 then s.phase = "type" s.timer = 0 end
		end
		local blink = math.floor(t * 2.6) % 2 == 0
		self.l1.Text = name:sub(1, s.n) .. (blink and "|" or "")
		NT.stepFlakes(self.flakes, dt, t)
	end
end
function NT.Tag:destroy()
	pcall(function() self.bb:Destroy() end)
end

-- the little circle shown for far-away hub users; click it to teleport to them
NT.Marker = {}
NT.Marker.__index = NT.Marker
function NT.Marker.new(plr, custom)
	local self = setmetatable({plr = plr, custom = custom, phase = rng:NextNumber(0, 6), hover = false}, NT.Marker)
	local root = new("Frame", {Name = "HubMarker", Size = UDim2.fromOffset(64, 66), AnchorPoint = Vector2.new(.5, .33), BackgroundTransparency = 1, Visible = false}, gui)
	self.root = root
	local cg = new("CanvasGroup", {Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 0), BackgroundColor3 = Color3.new(1, 1, 1)}, root)
	corner(cg, 22)
	new("UIStroke", {Color = custom and Color3.fromRGB(8, 8, 10) or Color3.fromRGB(34, 34, 40), Thickness = 2}, cg)
	self.grad = new("UIGradient", {Color = custom and NT.RED or NT.GREY, Rotation = 45}, cg)
	local bs = new("UIScale", {}, cg)
	if custom then
		self.flakes = NT.makeFlakes(cg, 10, 6, 38, 44, 3, 4.2)
	end
	local av = new("ImageLabel", {Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
		BackgroundColor3 = Color3.fromRGB(230, 230, 236), Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(plr.UserId), BorderSizePixel = 0, ZIndex = 4}, cg)
	corner(av, 14)
	self.label = new("TextLabel", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(64, 14), Text = "",
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.new(0, 0, 0), TextStrokeTransparency = .35,
		TextTruncate = Enum.TextTruncate.AtEnd}, root)
	local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8}, cg)
	hit.MouseEnter:Connect(function() self.hover = true tween(bs, .15, {Scale = 1.14}, Enum.EasingStyle.Back) end)
	hit.MouseLeave:Connect(function() self.hover = false tween(bs, .15, {Scale = 1}) end)
	hit.MouseButton1Click:Connect(function()
		local c = plr.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			sfx(TOGGLE_ID, 1.4, .5)
			say("Teleporting to " .. plr.DisplayName)
			smoothTeleport(r.Position - Vector3.new(0, 3, 0) + r.CFrame.RightVector * 4)
		end
	end)
	return self
end
function NT.Marker:update(dt, t, worldPos, dist, cam)
	local view = cam.ViewportSize
	local vp = cam:WorldToViewportPoint(worldPos + Vector3.new(0, 2.5, 0))
	local x, y = vp.X, vp.Y
	if vp.Z < 0 then x, y = view.X - x, view.Y - y end
	local m = 60
	local inside = vp.Z > 0 and x > m and x < view.X - m and y > m and y < view.Y - m
	if not inside then
		local cx, cy = view.X / 2, view.Y / 2
		local dx, dy = x - cx, y - cy
		if dx == 0 and dy == 0 then dy = -1 end
		local s = math.min((cx - m) / math.max(math.abs(dx), 1e-3), (cy - m) / math.max(math.abs(dy), 1e-3))
		x, y = cx + dx * s, cy + dy * s
	end
	self.root.Position = UDim2.fromOffset(x, y)
	self.root.Visible = true
	self.grad.Offset = Vector2.new(math.sin(t * 1.3 + self.phase) * .2, 0)
	self.label.Text = self.hover and self.plr.DisplayName or (math.floor(dist + .5) .. "m")
	if self.custom then NT.stepFlakes(self.flakes, dt, t) end
end
function NT.Marker:destroy()
	pcall(function() self.root:Destroy() end)
end

function NT.destroy(uid)
	local s = NT.subjects[uid]
	if not s then return end
	NT.subjects[uid] = nil
	if s.tag then s.tag:destroy() end
	if s.marker then s.marker:destroy() end
end

function NT.step(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local t = os.clock()
	local active = {}
	local function handle(plr, isSelf)
		local uid = plr.UserId
		active[uid] = true
		local char = plr.Character
		local head = char and char:FindFirstChild("Head")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local ok = head and hum and hum.Health > 0 and not hidden[uid] and (CFG.nametags or CFG.markers)
		local custom = NT.isCustom(plr, isSelf)
		local s = NT.subjects[uid]
		if s and (not ok or s.char ~= char or s.custom ~= custom) then
			NT.destroy(uid)
			s = nil
		end
		if not ok then return end
		if not s then
			s = {plr = plr, char = char, custom = custom}
			NT.subjects[uid] = s
		end
		local dist = (head.Position - cam.CFrame.Position).Magnitude
		local near
		if isSelf then near = dist > 4 else near = dist <= CFG.markDist end
		if CFG.nametags then
			if not s.tag then s.tag = NT.Tag.new(plr, head, custom) end
			s.tag:update(dt, t, near, dist)
		elseif s.tag then
			s.tag:destroy()
			s.tag = nil
		end
		if CFG.markers and not isSelf and not near then
			if not s.marker then s.marker = NT.Marker.new(plr, custom) end
			s.marker:update(dt, t, head.Position, dist, cam)
		elseif s.marker then
			s.marker:destroy()
			s.marker = nil
		end
	end
	handle(LP, true)
	for uid in pairs(peers) do
		local plr = Players:GetPlayerByUserId(uid)
		if plr then handle(plr, false) end
	end
	for uid in pairs(NT.subjects) do
		if not active[uid] then NT.destroy(uid) end
	end
end
track(RunService.RenderStepped:Connect(NT.step))

---------------------------------------------------------------- GUI (built inside its own function so it has its own local limit)
local function buildGui()
local W, H = 580, 400
local win = new("Frame", {Name = "Window", Size = UDim2.fromOffset(W, H), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundTransparency = 1, Visible = false}, gui)
local userScale = new("UIScale", {Scale = math.clamp(((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y) or 700) / 640, .6, 1)}, win)
local popFrame = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1}, win)
local popScale = new("UIScale", {Scale = .75}, popFrame)
local shadow = new("Frame", {Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromOffset(-5, 8), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1}, popFrame)
corner(shadow, 22)
local halo = new("Frame", {Size = UDim2.new(1, 26, 1, 26), Position = UDim2.fromOffset(-13, -13), BackgroundTransparency = 1}, popFrame)
corner(halo, 28)
reg(halo, "BackgroundColor3")
local body = new("CanvasGroup", {Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.bg, GroupTransparency = 1}, popFrame)
corner(body, 16)
local bodyStroke = new("UIStroke", {Thickness = 1.6, Color = Color3.new(1, 1, 1)}, body)
local bodyGrad = new("UIGradient", {}, bodyStroke)
regGrad(bodyGrad)

local top = new("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = THEME.panel, BorderSizePixel = 0}, body)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = THEME.cardHover, BorderSizePixel = 0}, top)
local logo = new("Frame", {Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(14, 9)}, top)
corner(logo, 9)
reg(logo, "BackgroundColor3")
new("UIGradient", {Rotation = 45, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 215))}, logo)
new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "H", Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1)}, logo)
local function L(parent, text, size, font, color, pos, sz, align)
	return new("TextLabel", {BackgroundTransparency = 1, Text = text, TextSize = size, Font = font, TextColor3 = color, Position = pos, Size = sz,
		TextXAlignment = align or Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd}, parent)
end
L(top, "HEADLESS HUB", 15, Enum.Font.GothamBlack, THEME.text, UDim2.fromOffset(52, 7), UDim2.fromOffset(180, 18))
L(top, "v3.1  ·  Superman Edition", 10, Enum.Font.GothamMedium, THEME.sub, UDim2.fromOffset(52, 24), UDim2.fromOffset(180, 14))

local hubPill = new("Frame", {Size = UDim2.fromOffset(112, 24), AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -90, .5, 0), BackgroundColor3 = THEME.bg}, top)
corner(hubPill, 12)
local hubDot = new("Frame", {Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = Color3.fromRGB(90, 230, 140)}, hubPill)
corner(hubDot, 4)
local hubLbl = L(hubPill, "0 hub users", 11, Enum.Font.GothamBold, THEME.sub, UDim2.fromOffset(26, 0), UDim2.new(1, -30, 1, 0))

local function topBtn(text, xRight, hoverCol)
	local b = new("TextButton", {Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -xRight, .5, 0), BackgroundColor3 = THEME.card,
		Text = text, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.text, AutoButtonColor = false}, top)
	corner(b, 8)
	local s = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(b, .15, {BackgroundColor3 = hoverCol}) tween(s, .15, {Scale = 1.1}, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(b, .15, {BackgroundColor3 = THEME.card}) tween(s, .15, {Scale = 1}) end)
	return b
end
local closeBtn = topBtn("×", 12, Color3.fromRGB(220, 70, 85))
local minBtn = topBtn("–", 46, THEME.cardHover)

local sidebar = new("Frame", {Position = UDim2.fromOffset(0, 46), Size = UDim2.new(0, 150, 1, -74), BackgroundColor3 = THEME.panel, BorderSizePixel = 0}, body)
local content = new("Frame", {Position = UDim2.fromOffset(150, 46), Size = UDim2.new(1, -150, 1, -74), BackgroundTransparency = 1, ClipsDescendants = true}, body)
local footer = new("Frame", {Position = UDim2.new(0, 0, 1, -28), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = THEME.panel, BorderSizePixel = 0}, body)
L(footer, "K  hide      F  fly      L  laser", 11, Enum.Font.GothamMedium, THEME.sub, UDim2.fromOffset(14, 0), UDim2.new(.7, 0, 1, 0))
local fpsLbl = L(footer, "FPS 60", 11, Enum.Font.GothamBold, THEME.sub, UDim2.new(1, -90, 0, 0), UDim2.fromOffset(76, 28), Enum.TextXAlignment.Right)

-- nav
local navItems = {{"Movement", ICONS.move}, {"Combat", ICONS.combat}, {"Players", ICONS.players}, {"Settings", ICONS.settings}}
local navBtns, pages, current = {}, {}, nil
local pill = new("Frame", {Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 12), BackgroundTransparency = .82}, sidebar)
corner(pill, 10)
reg(pill, "BackgroundColor3")
local pillBar = new("Frame", {Size = UDim2.fromOffset(3, 20), Position = UDim2.fromOffset(0, 9), BorderSizePixel = 0}, pill)
corner(pillBar, 2)
reg(pillBar, "BackgroundColor3")

local function makePage(name)
	local cg = new("CanvasGroup", {Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false}, content)
	local sc = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y}, cg)
	reg(sc, "ScrollBarImageColor3")
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, sc)
	pad(sc, 14, 12, 14, 12)
	pages[name] = cg
	return sc
end

local function selectPage(name)
	if current == name then return end
	local oldName = current
	current = name
	local idx
	for i, n in ipairs(navItems) do if n[1] == name then idx = i end end
	tween(pill, .4, {Position = UDim2.fromOffset(8, 12 + (idx - 1) * 44)}, Enum.EasingStyle.Back)
	for n, b in pairs(navBtns) do tween(b, .2, {TextColor3 = n == name and THEME.text or THEME.sub}) end
	if oldName then
		local old = pages[oldName]
		tween(old, .18, {GroupTransparency = 1, Position = UDim2.fromOffset(-20, 0)})
		task.delay(.2, function() if current ~= oldName then old.Visible = false end end)
	end
	local pg = pages[name]
	pg.Visible = true
	pg.Position = UDim2.fromOffset(26, 0)
	pg.GroupTransparency = 1
	tween(pg, .35, {GroupTransparency = 0, Position = UDim2.new()})
end

for i, item in ipairs(navItems) do
	local b = new("TextButton", {Size = UDim2.new(1, -16, 0, 38), Position = UDim2.fromOffset(8, 12 + (i - 1) * 44), BackgroundTransparency = 1,
		Text = item[2] .. "  " .. item[1], Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.sub, TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false, ZIndex = 2}, sidebar)
	pad(b, 14, 0, 0, 0)
	navBtns[item[1]] = b
	b.MouseEnter:Connect(function() if current ~= item[1] then tween(b, .15, {TextColor3 = THEME.text}) end end)
	b.MouseLeave:Connect(function() if current ~= item[1] then tween(b, .15, {TextColor3 = THEME.sub}) end end)
	b.MouseButton1Click:Connect(function() sfx(CLICK_ID, 1.1, .35) selectPage(item[1]) end)
end

local me = new("Frame", {Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -54), BackgroundColor3 = THEME.card}, sidebar)
corner(me, 10)
local meAv = new("ImageLabel", {Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(7, 7), BackgroundColor3 = THEME.off,
	Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(LP.UserId)}, me)
corner(meAv, 16)
L(me, LP.DisplayName, 12, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(46, 6), UDim2.new(1, -50, 0, 16))
L(me, "ready", 10, Enum.Font.Gotham, Color3.fromRGB(90, 230, 140), UDim2.fromOffset(46, 22), UDim2.new(1, -50, 0, 14))

-- widgets
local function ripple(c)
	local m = UIS:GetMouseLocation()
	local k = math.max(win.AbsoluteSize.X / W, .01)
	local r = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = .85, AnchorPoint = Vector2.new(.5, .5),
		Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset((m.X - c.AbsolutePosition.X) / k, (m.Y - c.AbsolutePosition.Y) / k), ZIndex = 3}, c)
	corner(r, 999)
	local big = math.max(c.AbsoluteSize.X, c.AbsoluteSize.Y) / k * 2.4
	tween(r, .55, {Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1})
	Debris:AddItem(r, .6)
end
local function card(parent, h, noHit)
	local c = new("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = THEME.card, ClipsDescendants = true, LayoutOrder = #parent:GetChildren() + 1}, parent)
	corner(c, 10)
	local st = new("UIStroke", {Thickness = 1.2, Transparency = 1}, c)
	reg(st, "Color")
	local hit
	if not noHit then
		hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4}, c)
		hit.MouseEnter:Connect(function() tween(c, .18, {BackgroundColor3 = THEME.cardHover}) tween(st, .18, {Transparency = .55}) end)
		hit.MouseLeave:Connect(function() tween(c, .18, {BackgroundColor3 = THEME.card}) tween(st, .18, {Transparency = 1}) end)
	end
	return c, hit
end
local function section(parent, text)
	local l = L(parent, text, 11, Enum.Font.GothamBold, THEME.sub, UDim2.new(), UDim2.new(1, 0, 0, 16))
	l.LayoutOrder = #parent:GetChildren()
	return l
end
local function toggle(parent, title, desc, cb, hint)
	local c, hit = card(parent, 58)
	L(c, title, 14, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 10), UDim2.new(1, -130, 0, 18))
	L(c, desc, 11, Enum.Font.Gotham, THEME.sub, UDim2.fromOffset(14, 30), UDim2.new(1, -130, 0, 16))
	local sw = new("Frame", {Size = UDim2.fromOffset(46, 24), AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -14, .5, 0), BackgroundColor3 = THEME.off}, c)
	corner(sw, 12)
	local knob = new("Frame", {Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Color3.new(1, 1, 1)}, sw)
	corner(knob, 9)
	if hint then
		local h = L(c, hint, 11, Enum.Font.GothamBold, THEME.sub, UDim2.new(1, -72, .5, 0), UDim2.fromOffset(24, 20), Enum.TextXAlignment.Center)
		h.AnchorPoint = Vector2.new(1, .5)
		h.BackgroundTransparency = 0
		h.BackgroundColor3 = THEME.bg
		corner(h, 6)
	end
	local state = false
	local api = {}
	local function render()
		tween(knob, .3, {Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)}, Enum.EasingStyle.Back)
		tween(sw, .25, {BackgroundColor3 = state and THEME.accent or THEME.off})
	end
	table.insert(accentHooks, function() if state then tween(sw, .3, {BackgroundColor3 = THEME.accent}) end end)
	function api.set(v) if v == state then return end state = v render() cb(v) end
	function api.silent(v) state = v render() end
	function api.get() return state end
	hit.MouseButton1Down:Connect(function() tween(knob, .1, {Size = UDim2.fromOffset(24, 18)}) end)
	hit.MouseButton1Up:Connect(function() tween(knob, .15, {Size = UDim2.fromOffset(18, 18)}) end)
	hit.MouseButton1Click:Connect(function() ripple(c) sfx(TOGGLE_ID, state and .85 or 1.15, .5) api.set(not state) end)
	return api
end
local function slider(parent, title, mn, mx, val, fmt, cb)
	local c = card(parent, 64, true)
	L(c, title, 14, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 8), UDim2.new(1, -110, 0, 18))
	local vl = L(c, fmt(val), 13, Enum.Font.GothamBold, THEME.accent, UDim2.new(1, -94, 0, 8), UDim2.fromOffset(80, 18), Enum.TextXAlignment.Right)
	reg(vl, "TextColor3")
	local tr = new("Frame", {Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = THEME.off}, c)
	corner(tr, 3)
	local f0 = (val - mn) / (mx - mn)
	local fill = new("Frame", {Size = UDim2.fromScale(f0, 1)}, tr)
	corner(fill, 3)
	reg(fill, "BackgroundColor3")
	local knob = new("Frame", {Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(f0, .5), BackgroundColor3 = Color3.new(1, 1, 1)}, tr)
	corner(knob, 8)
	local ks = new("UIScale", {}, knob)
	local band = new("TextButton", {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 31), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5}, c)
	local sliding = false
	local function setFrac(f)
		f = math.clamp(f, 0, 1)
		local v = mn + f * (mx - mn)
		vl.Text = fmt(v)
		tween(fill, .06, {Size = UDim2.fromScale(f, 1)}, Enum.EasingStyle.Quad)
		tween(knob, .06, {Position = UDim2.fromScale(f, .5)}, Enum.EasingStyle.Quad)
		cb(v)
	end
	local function fromX(x) setFrac((x - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1)) end
	band.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			tween(ks, .15, {Scale = 1.3}, Enum.EasingStyle.Back)
			fromX(input.Position.X)
		end
	end)
	track(UIS.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromX(input.Position.X) end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			sliding = false
			tween(ks, .15, {Scale = 1}, Enum.EasingStyle.Back)
		end
	end))
end
local function chips(parent, title, opts, selected, cb)
	local c = card(parent, 74, true)
	L(c, title, 14, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 8), UDim2.new(1, -140, 0, 18))
	local nameLbl = L(c, opts[selected][1], 12, Enum.Font.GothamBold, THEME.accent, UDim2.new(1, -134, 0, 9), UDim2.fromOffset(120, 16), Enum.TextXAlignment.Right)
	reg(nameLbl, "TextColor3")
	local row = new("Frame", {Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 30), BackgroundTransparency = 1}, c)
	new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center}, row)
	local strokes = {}
	for i, o in ipairs(opts) do
		local b = new("TextButton", {Size = UDim2.fromOffset(28, 28), BackgroundColor3 = o[2], Text = "", AutoButtonColor = false}, row)
		corner(b, 14)
		local st = new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = i == selected and 0 or 1}, b)
		strokes[i] = st
		local s = new("UIScale", {}, b)
		b.MouseEnter:Connect(function() tween(s, .15, {Scale = 1.15}, Enum.EasingStyle.Back) end)
		b.MouseLeave:Connect(function() tween(s, .15, {Scale = 1}) end)
		b.MouseButton1Click:Connect(function()
			sfx(CLICK_ID, 1.2, .35)
			for j, k in ipairs(strokes) do tween(k, .2, {Transparency = j == i and 0 or 1}) end
			nameLbl.Text = o[1]
			cb(i, o)
		end)
	end
end
local function button(parent, text, cb, danger)
	local b = new("TextButton", {Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = danger and Color3.fromRGB(190, 50, 70) or THEME.accent, Text = text,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, LayoutOrder = #parent:GetChildren() + 1, ClipsDescendants = true}, parent)
	corner(b, 10)
	if not danger then reg(b, "BackgroundColor3") end
	local s = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(s, .15, {Scale = 1.02}, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(s, .15, {Scale = 1}) end)
	b.MouseButton1Down:Connect(function() tween(s, .1, {Scale = .97}) end)
	b.MouseButton1Click:Connect(function() ripple(b) sfx(CLICK_ID, 1, .4) cb() end)
	return b
end

-- Movement page
local pgMove = makePage("Movement")
section(pgMove, ICONS.fly .. "  FLIGHT")
UI.fly = toggle(pgMove, ICONS.fly .. " Superman Fly", "Smooth flight with the Superman pose, cape and wind trails", setFly, "F")
slider(pgMove, ICONS.speed .. " Fly speed", FLY_MIN, FLY_MAX, CFG.flySpeed, function(v) return math.floor(v + .5) end, function(v) CFG.flySpeed = math.floor(v + .5) end)
local capeT = toggle(pgMove, ICONS.cape .. " Show capes", "Capes on you and on other hub users", function(v) CFG.cape = v end)
capeT.silent(true)
section(pgMove, ICONS.travel .. "  TRAVEL")
UI.noclip = toggle(pgMove, ICONS.noclip .. " Noclip", "Walk through walls, restores collisions when off", setNoclip)
UI.tp = toggle(pgMove, ICONS.tp .. " Click TP tool", "Adds a tool that glides you to where you click", setTP)

-- Combat page
local pgCombat = makePage("Combat")
section(pgCombat, ICONS.laser .. "  LASER EYES")
UI.laser = toggle(pgCombat, ICONS.laser .. " Laser Eyes tool", "Hold left click: a burning line follows the beam", setLaser, "L")
chips(pgCombat, ICONS.color .. " Beam color", {
	{"Heat vision red", Color3.fromRGB(255, 30, 20)}, {"Ice blue", Color3.fromRGB(60, 170, 255)}, {"Toxic green", Color3.fromRGB(60, 255, 120)},
	{"Royal purple", Color3.fromRGB(170, 80, 255)}, {"Gold", Color3.fromRGB(255, 205, 80)},
}, 1, function(_, o) CFG.laserColor = o[2] end)
slider(pgCombat, ICONS.width .. " Beam width", .5, 2.5, 1, function(v) return ("%.1fx"):format(v) end, function(v) CFG.laserWidth = v end)
slider(pgCombat, ICONS.volume .. " Laser volume", 0, 1.5, 1, function(v) return math.floor(v * 100 + .5) .. "%" end, function(v) CFG.sfxVol = v end)
local groundT = toggle(pgCombat, ICONS.ground .. " Ground damage", "Burn line, flying rocks, sparks and dust", function(v) CFG.ground = v end)
groundT.silent(true)

-- Players page
local pgPlayers = makePage("Players")
section(pgPlayers, ICONS.chat .. "  COMMAND BAR")
local cc = card(pgPlayers, 92, true)
L(cc, ICONS.chat .. " Run a command", 14, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18))
L(cc, "!to name  ·  !hide name  ·  !unhide name   (partial names work)", 11, Enum.Font.Gotham, THEME.sub, UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 14))
local box = new("TextBox", {Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 0, 28), BackgroundColor3 = THEME.bg, PlaceholderText = "type a command and press Enter",
	PlaceholderColor3 = THEME.sub, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left}, cc)
corner(box, 8)
pad(box, 10, 0, 10, 0)
local boxSt = new("UIStroke", {Thickness = 1.2, Transparency = 1}, box)
reg(boxSt, "Color")
box.Focused:Connect(function() tween(boxSt, .2, {Transparency = 0}) end)
box.FocusLost:Connect(function(enter)
	tween(boxSt, .2, {Transparency = 1})
	if enter then sfx(CLICK_ID, 1.2, .4) runCommand(box.Text) box.Text = "" end
end)
section(pgPlayers, ICONS.players .. "  PLAYERS")
local sc2 = card(pgPlayers, 38, true)
local searchBox = new("TextBox", {Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -20, 0, 28), BackgroundTransparency = 1, PlaceholderText = ICONS.size .. " search players...",
	PlaceholderColor3 = THEME.sub, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = THEME.text, TextXAlignment = Enum.TextXAlignment.Left}, sc2)
local listHolder = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 999}, pgPlayers)
new("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, listHolder)
local emptyLbl = L(pgPlayers, "No other players in this server", 12, Enum.Font.Gotham, THEME.sub, UDim2.new(), UDim2.new(1, 0, 0, 24), Enum.TextXAlignment.Center)
emptyLbl.LayoutOrder = 1000

local function miniBtn(parent, text, xRight, cb)
	local b = new("TextButton", {Size = UDim2.fromOffset(46, 28), AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -xRight, .5, 0), BackgroundColor3 = THEME.off,
		Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.text, AutoButtonColor = false}, parent)
	corner(b, 8)
	local s = new("UIScale", {}, b)
	b.MouseEnter:Connect(function() tween(b, .15, {BackgroundColor3 = THEME.accent}) tween(s, .15, {Scale = 1.08}, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function() tween(b, .15, {BackgroundColor3 = THEME.off}) tween(s, .15, {Scale = 1}) end)
	b.MouseButton1Click:Connect(function() sfx(CLICK_ID, 1.1, .4) cb(b) end)
	return b
end
local searchText = ""
local function playerRow(plr)
	local r = new("Frame", {Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = THEME.card, LayoutOrder = #listHolder:GetChildren() + 1}, listHolder)
	corner(r, 10)
	local av = new("ImageLabel", {Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = THEME.off,
		Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(plr.UserId)}, r)
	corner(av, 17)
	L(r, plr.DisplayName, 13, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(52, 8), UDim2.new(1, -170, 0, 18))
	L(r, "@" .. plr.Name .. (peers[plr.UserId] and ("   " .. ICONS.hub .. " HUB") or ""), 10, Enum.Font.Gotham, peers[plr.UserId] and THEME.accent2 or THEME.sub, UDim2.fromOffset(52, 27), UDim2.new(1, -170, 0, 14))
	miniBtn(r, "TP", 62, function() if not tpToPlayer(plr) then say(plr.Name .. " has no character yet") else say("Teleported to " .. plr.Name) end end)
	miniBtn(r, hidden[plr.UserId] and "Show" or "Hide", 10, function(b)
		if hidden[plr.UserId] then
			hidden[plr.UserId] = nil
			applyUnhide(plr)
			b.Text = "Hide"
			say("Unhidden: " .. plr.Name)
		else
			hidden[plr.UserId] = true
			applyHide(plr)
			b.Text = "Show"
			say("Hidden: " .. plr.Name)
		end
	end)
end
local function refreshPlayers()
	for _, ch in ipairs(listHolder:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local q, n = searchText:lower(), 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP and (q == "" or plr.Name:lower():find(q, 1, true) or plr.DisplayName:lower():find(q, 1, true)) then
			playerRow(plr)
			n += 1
		end
	end
	emptyLbl.Visible = n == 0
end
searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchText = searchBox.Text refreshPlayers() end)
track(Players.PlayerAdded:Connect(function() task.wait(.3) refreshPlayers() end))
track(Players.PlayerRemoving:Connect(function() task.defer(refreshPlayers) end))
refreshPlayers()

-- Settings page
local pgSet = makePage("Settings")
section(pgSet, ICONS.color .. "  APPEARANCE")
chips(pgSet, ICONS.color .. " Accent color", {
	{"Violet", Color3.fromRGB(124, 92, 255)}, {"Crimson", Color3.fromRGB(255, 70, 100)}, {"Emerald", Color3.fromRGB(40, 210, 130)},
	{"Gold", Color3.fromRGB(255, 190, 60)}, {"Rose", Color3.fromRGB(255, 100, 190)},
}, 1, function(i, o)
	local pairs2 = {
		{Color3.fromRGB(124, 92, 255), Color3.fromRGB(70, 200, 255)}, {Color3.fromRGB(255, 70, 100), Color3.fromRGB(255, 170, 90)},
		{Color3.fromRGB(40, 210, 130), Color3.fromRGB(90, 230, 255)}, {Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 120, 60)},
		{Color3.fromRGB(255, 100, 190), Color3.fromRGB(150, 120, 255)},
	}
	applyAccent(pairs2[i][1], pairs2[i][2])
end)
slider(pgSet, ICONS.size .. " UI size", .6, 1.4, userScale.Scale, function(v) return math.floor(v * 100 + .5) .. "%" end, function(v) userScale.Scale = v end)

section(pgSet, ICONS.tag .. "  NAMETAGS")
local tagT = toggle(pgSet, ICONS.tag .. " Hub nametags", "Animated tags over hub users (only hub users see them)", function(v) CFG.nametags = v end)
tagT.silent(true)
local markT = toggle(pgSet, ICONS.mark .. " Far markers", "Click a circle to teleport to a far-away hub user", function(v) CFG.markers = v end)
markT.silent(true)
slider(pgSet, ICONS.mark .. " Marker distance", 40, 400, CFG.markDist, function(v) return math.floor(v + .5) .. "m" end, function(v) CFG.markDist = math.floor(v + .5) end)
slider(pgSet, ICONS.size .. " Tag height", 2, 7, CFG.tagHeight, function(v) return ("%.1f"):format(v) end, function(v) CFG.tagHeight = v end)
local prevT = toggle(pgSet, ICONS.snow .. " Preview custom tag", "Local preview on you. Others see it only if you are on the custom list", function(v) CFG.previewCustom = v end)
local tagCard = card(pgSet, 52, true)
L(tagCard, NT.isCustom(LP, false) and (ICONS.snow .. " Your nametag: Custom (red + snow)") or (ICONS.tag .. " Your nametag: Default (grey)"), 13, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18))
L(tagCard, "You are @" .. LP.Name .. "  (id " .. LP.UserId .. ").  Add it to NT.users in the script to get the custom tag.", 11, Enum.Font.Gotham, THEME.sub, UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 16))

section(pgSet, ICONS.net .. "  MULTIPLAYER")
local syncT = toggle(pgSet, ICONS.net .. " Share with hub users", "Others running this script see your cape, trail, pose and lasers", function(v)
	CFG.sync = v
	if not v then
		for uid in pairs(peers) do dropPeer(uid) end
	else
		sendState(true)
	end
	say(v and "Sharing ON" or "Sharing OFF")
end)
syncT.silent(true)
local statusCard = card(pgSet, 52, true)
local statusLbl = L(statusCard, ICONS.hubusers .. " Hub users seen: 0", 13, Enum.Font.GothamBold, THEME.text, UDim2.fromOffset(14, 8), UDim2.new(1, -28, 0, 18))
L(statusCard, "Sync runs through game chat, so everyone needs the script and chat on", 11, Enum.Font.Gotham, THEME.sub, UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 16))
section(pgSet, ICONS.script .. "  SCRIPT")
button(pgSet, ICONS.unload .. "  Unload Headless Hub", function() if env.MiniPanelCleanup then env.MiniPanelCleanup() end end, true)

peersChanged = function()
	local n = 0
	for _ in pairs(peers) do n += 1 end
	hubLbl.Text = n .. (n == 1 and " hub user" or " hub users")
	hubLbl.TextColor3 = n > 0 and THEME.text or THEME.sub
	statusLbl.Text = ICONS.hubusers .. " Hub users seen: " .. n
	refreshPlayers()
end

-- open / close / drag / keys
local isOpen, busy, minimized = false, false, false
local function setOpen(state)
	if busy or state == isOpen then return end
	busy = true
	isOpen = state
	if state then
		win.Visible = true
		tween(body, .4, {GroupTransparency = 0})
		tween(popScale, .55, {Scale = 1}, Enum.EasingStyle.Back)
		tween(halo, .5, {BackgroundTransparency = .9})
		tween(shadow, .5, {BackgroundTransparency = .55})
	else
		tween(body, .25, {GroupTransparency = 1})
		tween(popScale, .3, {Scale = .8}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(halo, .25, {BackgroundTransparency = 1})
		tween(shadow, .25, {BackgroundTransparency = 1})
	end
	task.delay(.5, function()
		if not isOpen then win.Visible = false end
		busy = false
	end)
end
closeBtn.MouseButton1Click:Connect(function() sfx(CLICK_ID, .9, .4) setOpen(false) end)
minBtn.MouseButton1Click:Connect(function()
	sfx(CLICK_ID, 1, .4)
	minimized = not minimized
	local p = win.Position
	local d = (H - 46) / 2
	tween(win, .35, {Size = UDim2.fromOffset(W, minimized and 46 or H),
		Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + (minimized and -d or d))}, Enum.EasingStyle.Quint)
end)

local dragging, dragStart, startPos, dragInput
top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, input.Position, win.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
top.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
track(UIS.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local d = input.Position - dragStart
		tween(win, .08, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)}, Enum.EasingStyle.Quad)
	end
end))

track(UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.K then
		sfx(CLICK_ID, isOpen and .85 or 1.1, .4)
		setOpen(not isOpen)
	elseif input.KeyCode == Enum.KeyCode.F then
		UI.fly.set(not UI.fly.get())
	elseif input.KeyCode == Enum.KeyCode.L then
		UI.laser.set(not UI.laser.get())
	end
end))

-- floating K button (mobile)
local fab = new("TextButton", {Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 12, .5, 0), BackgroundColor3 = THEME.bg,
	Text = "K", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false}, gui)
corner(fab, 20)
local fabSt = new("UIStroke", {Thickness = 1.6}, fab)
reg(fabSt, "Color")
local fabS = new("UIScale", {}, fab)
fab.MouseEnter:Connect(function() tween(fabS, .15, {Scale = 1.12}, Enum.EasingStyle.Back) end)
fab.MouseLeave:Connect(function() tween(fabS, .15, {Scale = 1}) end)
fab.MouseButton1Click:Connect(function() sfx(CLICK_ID, isOpen and .85 or 1.1, .4) setOpen(not isOpen) end)

-- mobile fly up/down
local function holdButton(text, yOffset, onHold)
	local b = new("TextButton", {Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(1, .5), Position = UDim2.new(1, -16, .5, yOffset), BackgroundColor3 = THEME.bg,
		BackgroundTransparency = .1, Text = text, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Visible = false}, gui)
	corner(b, 28)
	local st = new("UIStroke", {Thickness = 1.6}, b)
	reg(st, "Color")
	local bs = new("UIScale", {}, b)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onHold(true)
			tween(bs, .1, {Scale = .9})
			tween(b, .1, {BackgroundColor3 = THEME.accent})
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onHold(false)
			tween(bs, .15, {Scale = 1}, Enum.EasingStyle.Back)
			tween(b, .15, {BackgroundColor3 = THEME.bg})
		end
	end)
	return b
end
local upBtn = holdButton("UP", -34, function(v) upHeld = v end)
local downBtn = holdButton("DOWN", 34, function(v) downHeld = v end)

-- heartbeat: border spin, mobile buttons, fps
local frames, fpsT = 0, 0
track(RunService.Heartbeat:Connect(function(dt)
	if isOpen then bodyGrad.Rotation = (bodyGrad.Rotation + dt * 70) % 360 end
	local show = flyEnabled and UIS.TouchEnabled
	upBtn.Visible, downBtn.Visible = show, show
	frames += 1
	fpsT += dt
	if fpsT >= .5 then
		fpsLbl.Text = "FPS " .. math.floor(frames / fpsT + .5)
		frames, fpsT = 0, 0
	end
end))

-- splash intro, then the window opens
selectPage("Movement")
do
	local sp = new("CanvasGroup", {Size = UDim2.fromOffset(320, 120), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), BackgroundColor3 = THEME.bg, GroupTransparency = 1}, gui)
	corner(sp, 18)
	local st = new("UIStroke", {Thickness = 1.6, Color = Color3.new(1, 1, 1)}, sp)
	regGrad(new("UIGradient", {}, st))
	local ss = new("UIScale", {Scale = .85}, sp)
	L(sp, "HEADLESS HUB", 24, Enum.Font.GothamBlack, THEME.text, UDim2.fromOffset(0, 20), UDim2.new(1, 0, 0, 32), Enum.TextXAlignment.Center)
	L(sp, "loading modules...", 12, Enum.Font.Gotham, THEME.sub, UDim2.fromOffset(0, 58), UDim2.new(1, 0, 0, 16), Enum.TextXAlignment.Center)
	local bar = new("Frame", {Position = UDim2.new(.5, -110, 0, 88), Size = UDim2.fromOffset(220, 5), BackgroundColor3 = THEME.off}, sp)
	corner(bar, 3)
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1)}, bar)
	corner(fill, 3)
	reg(fill, "BackgroundColor3")
	tween(sp, .3, {GroupTransparency = 0})
	tween(ss, .45, {Scale = 1}, Enum.EasingStyle.Back)
	tween(fill, 1.1, {Size = UDim2.fromScale(1, 1)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	task.delay(1.25, function()
		tween(sp, .3, {GroupTransparency = 1})
		tween(ss, .3, {Scale = 1.08})
		Debris:AddItem(sp, .4)
		setOpen(true)
		say("Headless Hub loaded. Press K to hide")
	end)
end
end
buildGui()

---------------------------------------------------------------- cleanup for re-execution
env.MiniPanelCleanup = function()
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	for uid in pairs(peers) do pcall(dropPeer, uid) end
	for uid in pairs(NT.subjects) do pcall(NT.destroy, uid) end
	pcall(cancelTeleport)
	pcall(noclipOff)
	pcall(stopFly)
	pcall(removeLaserTool)
	pcall(stopLaserLocal)
	removeTool()
	pcall(function() dropTrail(true) end)
	pcall(function() tpBlur:Destroy() end)
	pcall(function() fxFolder:Destroy() end)
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
]==])()
