--[[
	AxionLib — standalone UI library for Roblox executor scripts.

	Extracted from AxionHub: this file contains ONLY the UI framework
	(theme, primitives, window/sidebar/tabs, components, notifications,
	loading screen). No game-specific automation logic lives here —
	require() it from any script and build a fresh hub on top of it.

	Usage:
		local AxionLib = loadstring(readfile("AxionLib.lua"))()
		-- or: local AxionLib = require(path_to_this_module)

		local window = AxionLib.new({
			Title = "MyHub",
			Subtitle = "v1",
			Tabs = {
				{ Id = "HOME", Icon = "home", Label = "Home", Desc = "overview" },
				{ Id = "SETTINGS", Icon = "settings", Label = "Settings", Desc = "options" },
			},
		})

		local home = window:GetPage("HOME")
		window:AddToggle(home, 10, "Example Toggle", false, function(on)
			print("toggled", on)
		end)

	See AxionLibExample.lua for a fuller example.
]]

local AxionLib = {}
AxionLib.__index = AxionLib

-- Services
local playersService = game:GetService("Players")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local lighting = game:GetService("Lighting")
local coreGui = game:GetService("CoreGui")
local soundService = game:GetService("SoundService")

local localPlayer = playersService.LocalPlayer
local WHITE = Color3.new(1, 1, 1)

-- Default theme. Pass a `Theme` table to AxionLib.new to override any of these.
local DEFAULT_THEME = {
	accentBlue = Color3.fromRGB(84, 38, 232),
	accentPink = Color3.fromRGB(172, 44, 248),
	accentLight = Color3.fromRGB(206, 164, 255),

	bgTop = Color3.fromRGB(26, 12, 48),
	bgBot = Color3.fromRGB(4, 2, 9),
	sidebarTop = Color3.fromRGB(14, 6, 26),
	sidebarBot = Color3.fromRGB(2, 1, 5),

	cardTop = Color3.fromRGB(44, 20, 82),
	cardBot = Color3.fromRGB(14, 6, 28),

	chipOff = Color3.fromRGB(26, 14, 44),
	chipHover = Color3.fromRGB(44, 26, 74),
	track = Color3.fromRGB(10, 5, 20),

	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(224, 212, 246),
	muted = Color3.fromRGB(150, 132, 188),
	good = Color3.fromRGB(130, 255, 180),
	bad = Color3.fromRGB(255, 100, 130),

	font = Enum.Font.Gotham,
	fontBold = Enum.Font.GothamBold,
	fontMedium = Enum.Font.GothamMedium,
}

-- A handful of built-in rbxassetid icons (lucide set) so components work
-- out of the box. Pass any rbxassetid:// / http image, or a numeric id,
-- directly to a component call to use your own.
local BUILTIN_ICONS = {
	search = "rbxassetid://10734943674",
	close = "rbxassetid://10747384394",
	minimize = "rbxassetid://10709791185",
	settings = "rbxassetid://10734950309",
	chevrondown = "rbxassetid://10709790948",
	palette = "rbxassetid://10734910430",
	save = "rbxassetid://10734941499",
	skull = "rbxassetid://10734962068",
	dashboard = "rbxassetid://10709752035",
	shield = "rbxassetid://10709818534",
	eye = "rbxassetid://10747375132",
	teleport = "rbxassetid://10723404337",
	refresh = "rbxassetid://10734933222",
	server = "rbxassetid://10734963400",
	copy = "rbxassetid://10709812159",
	sound = "rbxassetid://10709810814",
	soundmute = "rbxassetid://10709810619",
	bell = "rbxassetid://10709752996",
	info = "rbxassetid://10709752996",
	check = "rbxassetid://10709790644",
	zap = "rbxassetid://10709791882",
	home = "rbxassetid://10723407389",
	users = "rbxassetid://10709818534",
	link = "rbxassetid://10709812159",
}

local DEFAULT_SOUNDS = {
	Click = { id = "rbxassetid://6895079853", pitch = 1.10, vol = 0.32 },
	ToggleOn = { id = "rbxassetid://6895079853", pitch = 1.40, vol = 0.35 },
	ToggleOff = { id = "rbxassetid://6895079853", pitch = 0.88, vol = 0.28 },
	TabSwitch = { id = "rbxassetid://6895079853", pitch = 1.25, vol = 0.30 },
	Dropdown = { id = "rbxassetid://6895079853", pitch = 1.00, vol = 0.30 },
	Notify = { id = "rbxassetid://4590662766", pitch = 1.35, vol = 0.38 },
}

--// Generic helpers -----------------------------------------------------

local function randomName()
	local chars = {}
	for index = 1, math.random(10, 16) do
		chars[index] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

local function safeParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end
	return coreGui
end

local function resolveIcon(input, fallback)
	if type(input) == "number" then
		return "rbxassetid://" .. input
	end

	if type(input) ~= "string" or input == "" then
		return fallback or ""
	end

	if input:find("rbxassetid://", 1, true) or input:find("http", 1, true) then
		return input
	end

	local found = BUILTIN_ICONS[input:lower()]
	if type(found) == "string" and found ~= "" then
		return found
	end

	return fallback or input
end

local function tween(object, duration, goal, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	tweenService:Create(object, info, goal):Play()
	return info
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createGradient(parent, rotation, colorSequence)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or 90
	gradient.Color = colorSequence
	gradient.Parent = parent
	return gradient
end

-- Register extra icons into the resolver, e.g.:
--   AxionLib.RegisterIcons({ myIcon = "rbxassetid://123", gear = 456 })
-- Names are matched case-insensitively wherever a component takes an icon.
function AxionLib.RegisterIcons(icons)
	for name, value in pairs(icons) do
		BUILTIN_ICONS[tostring(name):lower()] = value
	end
end

-- Load an icon pack from a URL: a Lua source file that returns a table of
-- { name = rbxassetid_or_image, ... }, e.g. a self-hosted dist/Icons.lua.
-- Optionally caches it to `cacheFile` so later loads don't need the network.
-- Returns true on success (and registers the icons), false otherwise.
function AxionLib.LoadIconPack(url, cacheFile)
	local function parse(source)
		local chunk = loadstring(source)
		if not chunk then
			return false
		end

		local ok, data = pcall(chunk)
		if ok and type(data) == "table" then
			AxionLib.RegisterIcons(data)
			return true
		end

		return false
	end

	if cacheFile and isfile and readfile and isfile(cacheFile) then
		local ok, source = pcall(readfile, cacheFile)
		if ok and parse(source) then
			return true
		end
	end

	local ok, response = pcall(request, { Url = url, Method = "GET" })
	if not ok or not response or not response.Success then
		return false
	end

	if not parse(response.Body) then
		return false
	end

	if cacheFile and writefile then
		pcall(function()
			local folder = cacheFile:match("^(.*)/[^/]+$")
			if folder and makefolder and isfolder and not isfolder(folder) then
				makefolder(folder)
			end
			writefile(cacheFile, response.Body)
		end)
	end

	return true
end

--// AxionLib.new ---------------------------------------------------------

-- options:
--   Title, Subtitle, Version        strings shown in the sidebar
--   Logo                            rbxassetid:// / http image / numeric id
--   Theme                           table, merged over DEFAULT_THEME
--   Sounds                          table, merged over DEFAULT_SOUNDS
--   SoundsEnabled                   boolean, default true
--   SidebarWidth, CornerRadius      numbers
--   ToggleKey                       Enum.KeyCode, default RightShift
--   Tabs                            array of { Id, Icon, Label, Desc }
--   Size                            UDim2, default 590x410
function AxionLib.new(options)
	options = options or {}

	local self = setmetatable({}, AxionLib)

	self.theme = setmetatable(options.Theme or {}, { __index = DEFAULT_THEME })
	self.sounds = setmetatable(options.Sounds or {}, { __index = DEFAULT_SOUNDS })
	self.soundsEnabled = options.SoundsEnabled ~= false
	self.sidebarWidth = options.SidebarWidth or 150
	self.cornerRadius = options.CornerRadius or 12
	self.toggleKey = options.ToggleKey or Enum.KeyCode.RightShift
	self.windowSize = options.Size or UDim2.new(0, 590, 0, 410)

	self.title = options.Title or "Hub"
	self.subtitle = options.Subtitle or ""
	self.logo = resolveIcon(options.Logo, "rbxassetid://10723407389")

	self.alive = true
	self.minimized = false
	self.animating = false
	self.connections = {}
	self.spinners = {}
	self.pages = {}
	self.pageButtons = {}
	self.activePage = nil

	self:_buildShell(options.Tabs or {})

	return self
end

function AxionLib:_track(connection)
	table.insert(self.connections, connection)
	return connection
end

function AxionLib:_accentSequence()
	return ColorSequence.new(self.theme.accentBlue, self.theme.accentPink)
end

function AxionLib:_playSound(name)
	local info = self.sounds[name]
	if not self.soundsEnabled or not info then
		return
	end

	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = info.id
		sound.Volume = info.vol
		sound.PlaybackSpeed = info.pitch
		sound.Parent = soundService
		sound:Play()
		task.delay(3, function()
			sound:Destroy()
		end)
	end)
end

function AxionLib:_spin(gradient, speed)
	table.insert(self.spinners, { gradient = gradient, speed = speed, offset = gradient.Rotation })
end

--// Component primitives -------------------------------------------------
-- These can be used directly on any page/frame the window gives you.

function AxionLib:Stroke(parent, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	local gradient = createGradient(stroke, 45, self:_accentSequence())
	return stroke, gradient
end

function AxionLib:Icon(parent, image, size, position, color)
	local icon = Instance.new("ImageLabel")
	icon.Size = size
	icon.Position = position
	icon.Image = resolveIcon(image)
	icon.ImageColor3 = color or WHITE
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.ZIndex = 8
	icon.Parent = parent
	return icon
end

function AxionLib:Label(parent, text, size, position, opts)
	opts = opts or {}
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = opts.font or self.theme.font
	label.TextSize = opts.textSize or 11
	label.TextColor3 = opts.color or self.theme.text
	label.BackgroundTransparency = 1
	label.TextXAlignment = opts.alignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent
	return label
end

function AxionLib:Card(parent, size, position)
	local card = Instance.new("Frame")
	card.Size = size
	card.Position = position
	card.BackgroundColor3 = WHITE
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = parent
	createCorner(card, self.cornerRadius)
	createGradient(card, 100, ColorSequence.new(self.theme.cardTop, self.theme.cardBot))
	self:Stroke(card, 1, 0.65)
	return card
end

function AxionLib:Page(parent)
	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Visible = false
	page.Parent = parent
	return page
end

function AxionLib:Chip(parent, size, position, text, textSize, radius)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = self.theme.chipOff
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.ZIndex = 3
	button.Parent = parent
	createCorner(button, radius)

	local glow = Instance.new("Frame")
	glow.Size = UDim2.new(1, 0, 1, 0)
	glow.BackgroundColor3 = WHITE
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 4
	glow.Parent = button
	createCorner(glow, radius)
	createGradient(glow, 20, self:_accentSequence())

	local label = self:Label(button, text, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), {
		font = self.theme.fontBold,
		textSize = textSize,
		color = self.theme.textDim,
		alignment = Enum.TextXAlignment.Center,
	})
	label.ZIndex = 5

	local chip = { button = button, glow = glow, label = label, on = false }

	local function refresh(hover, instant)
		local buttonGoal = { BackgroundColor3 = hover and self.theme.chipHover or self.theme.chipOff }
		local glowGoal = { BackgroundTransparency = chip.on and 0 or 1 }
		local labelGoal = { TextColor3 = chip.on and self.theme.text or self.theme.textDim }

		if instant then
			button.BackgroundColor3 = buttonGoal.BackgroundColor3
			glow.BackgroundTransparency = glowGoal.BackgroundTransparency
			label.TextColor3 = labelGoal.TextColor3
			return
		end

		tween(button, 0.18, buttonGoal)
		tween(glow, 0.22, glowGoal)
		tween(label, 0.18, labelGoal)
	end

	chip.refresh = refresh

	chip.setOn = function(on, instant)
		chip.on = on
		refresh(false, instant)
	end

	self:_track(button.MouseEnter:Connect(function()
		refresh(true)
	end))
	self:_track(button.MouseLeave:Connect(function()
		refresh(false)
	end))

	return chip

	-- Chips are bare buttons: connect MouseButton1Click yourself for
	-- behaviour (see Toggle/ActionChip below for ready-made patterns).
end

-- A chip wired up as a clickable action button with an icon + click feedback.
function AxionLib:ActionChip(parent, position, width, text, icon, callback)
	local chip = self:Chip(parent, UDim2.new(0, width, 0, 30), position, text, 10, 999)
	chip.label.Position = UDim2.new(0, 22, 0, 0)
	chip.label.Size = UDim2.new(1, -28, 1, 0)

	if icon then
		self:Icon(chip.button, icon, UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), self.theme.text)
	end

	self:_track(chip.button.MouseButton1Click:Connect(function()
		self:_playSound("Click")
		chip.setOn(true)
		task.delay(0.3, function()
			if self.alive then
				chip.setOn(false)
			end
		end)
		if callback then
			callback()
		end
	end))

	return chip
end

local PILL_SIZE = UDim2.new(0, 46, 0, 24)
local KNOB_SIZE = UDim2.new(0, 18, 0, 18)
local KNOB_PAD = 3

function AxionLib:_buildPill(parent, position)
	local pill = Instance.new("TextButton")
	pill.Size = PILL_SIZE
	pill.Position = position
	pill.BackgroundColor3 = self.theme.track
	pill.BorderSizePixel = 0
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.ZIndex = 5
	pill.Parent = parent
	createCorner(pill, 999)
	self:Stroke(pill, 1, 0.6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = WHITE
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.ZIndex = 6
	fill.Parent = pill
	createCorner(fill, 999)
	createGradient(fill, 0, self:_accentSequence())

	local parts = {
		pill = pill,
		fill = fill,
		offPos = UDim2.new(0, KNOB_PAD, 0.5, -9),
		onPos = UDim2.new(1, -(18 + KNOB_PAD), 0.5, -9),
	}

	local knob = Instance.new("Frame")
	knob.Size = KNOB_SIZE
	knob.Position = parts.offPos
	knob.BackgroundColor3 = self.theme.muted
	knob.BorderSizePixel = 0
	knob.ZIndex = 7
	knob.Parent = pill
	createCorner(knob, 999)
	parts.knob = knob

	return parts
end

function AxionLib:_stylePill(parts, on, instant)
	local fillGoal = { BackgroundTransparency = on and 0 or 1 }
	local knobGoal = { Position = on and parts.onPos or parts.offPos, BackgroundColor3 = on and WHITE or self.theme.muted }

	if instant then
		parts.fill.BackgroundTransparency = fillGoal.BackgroundTransparency
		parts.knob.Position = knobGoal.Position
		parts.knob.BackgroundColor3 = knobGoal.BackgroundColor3
		return
	end

	tween(parts.fill, 0.2, fillGoal)
	tween(parts.knob, 0.3, knobGoal, Enum.EasingStyle.Back)
end

-- Toggle row: parent frame, y offset, title text, default state,
-- callback(newValue), optional icon.
-- Returns { icon = ImageLabel?, set = function(value) }
function AxionLib:AddToggle(parent, y, title, defaultOn, callback, iconImage)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.ZIndex = 4
	row.Parent = parent

	local icon
	if iconImage then
		icon = self:Icon(row, iconImage, UDim2.new(0, 18, 0, 18), UDim2.new(0, 14, 0.5, -9), self.theme.accentLight)
	end

	self:Label(row, title, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, icon and 40 or 14, 0, 0), {
		font = self.theme.fontMedium,
		textSize = 12,
		color = self.theme.text,
	})

	local parts = self:_buildPill(row, UDim2.new(1, -60, 0.5, -12))
	local on = defaultOn
	self:_stylePill(parts, on, true)

	self:_track(parts.pill.MouseButton1Click:Connect(function()
		on = not on
		self:_stylePill(parts, on)
		self:_playSound(on and "ToggleOn" or "ToggleOff")
		if callback then
			callback(on)
		end
	end))

	return {
		icon = icon,
		set = function(value)
			on = value
			self:_stylePill(parts, on)
		end,
	}
end

-- Slider row: parent, y, title, { min, max, default, suffix, onChange }
-- Values are integers between min and max. Returns { set = function(value) }.
function AxionLib:AddSlider(parent, y, title, config)
	config = config or {}
	local min = config.min or 0
	local max = config.max or 100
	local suffix = config.suffix or ""
	local value = math.clamp(config.default or min, min, max)

	local titleLabel = self:Label(parent, title, UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 14, 0, y), {
		font = self.theme.fontBold,
		textSize = 9.5,
		color = self.theme.accentLight,
	})

	local valueLabel = self:Label(parent, "", UDim2.new(0.6, -14, 0, 14), UDim2.new(0.4, 0, 0, y), {
		font = self.theme.fontBold,
		textSize = 11,
		color = self.theme.text,
		alignment = Enum.TextXAlignment.Right,
	})

	local sliderTrack = Instance.new("TextButton")
	sliderTrack.Size = UDim2.new(1, -28, 0, 10)
	sliderTrack.Position = UDim2.new(0, 14, 0, y + 28)
	sliderTrack.BackgroundColor3 = self.theme.track
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Text = ""
	sliderTrack.AutoButtonColor = false
	sliderTrack.ZIndex = 4
	sliderTrack.Parent = parent
	createCorner(sliderTrack, 999)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = sliderTrack
	createCorner(fill, 999)
	createGradient(fill, 0, self:_accentSequence())

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.BackgroundColor3 = WHITE
	knob.BorderSizePixel = 0
	knob.ZIndex = 6
	knob.Parent = sliderTrack
	createCorner(knob, 999)
	self:Stroke(knob, 2, 0)

	local function render()
		local relative = (value - min) / math.max(max - min, 1)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		knob.Position = UDim2.new(relative, -8, 0.5, -8)
		valueLabel.Text = tostring(value) .. suffix
	end

	local function setValue(newValue, silent)
		value = math.clamp(math.floor(newValue + 0.5), min, max)
		render()
		if not silent and config.onChange then
			config.onChange(value)
		end
	end

	render()

	local dragging = false

	local function setFromX(x)
		local relative = math.clamp((x - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
		setValue(min + relative * (max - min))
	end

	self:_track(sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			self:_playSound("Click")
			setFromX(input.Position.X)
			tween(knob, 0.15, { Size = UDim2.new(0, 20, 0, 20) })
		end
	end))

	self:_track(userInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end))

	self:_track(userInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, 0.15, { Size = UDim2.new(0, 16, 0, 16) })
		end
	end))

	return {
		set = function(v)
			setValue(v, true)
		end,
		get = function()
			return value
		end,
	}
end

--// Window shell ----------------------------------------------------------

function AxionLib:_buildShell(tabs)
	local parent = safeParent()
	local theme = self.theme

	local gui = Instance.new("ScreenGui")
	gui.Name = randomName()
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent
	self.gui = gui

	-- floating minimized button
	local miniBtn = Instance.new("TextButton")
	miniBtn.Size = UDim2.new(0, 48, 0, 48)
	miniBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	miniBtn.Position = UDim2.new(0, 44, 0, 124)
	miniBtn.BackgroundColor3 = WHITE
	miniBtn.BorderSizePixel = 0
	miniBtn.Text = ""
	miniBtn.AutoButtonColor = false
	miniBtn.Visible = false
	miniBtn.Active = true
	miniBtn.Draggable = true
	miniBtn.Parent = gui
	createCorner(miniBtn, 999)
	self:_spin(createGradient(miniBtn, 45, self:_accentSequence()), 60)
	self:Stroke(miniBtn, 1.5, 0.3)

	local miniScale = Instance.new("UIScale")
	miniScale.Scale = 0
	miniScale.Parent = miniBtn

	self:Icon(miniBtn, self.logo, UDim2.new(1, -12, 1, -12), UDim2.new(0, 6, 0, 6))

	local function getBaseScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(viewport.X * 0.9 / self.windowSize.X.Offset, viewport.Y * 0.78 / self.windowSize.Y.Offset, 1), 0.4, 1)
	end

	local baseScale = getBaseScale()

	local win = Instance.new("Frame")
	win.Name = "Window"
	win.Size = self.windowSize
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.new(0.5, 0, 0.5, 0)
	win.BackgroundColor3 = WHITE
	win.BackgroundTransparency = 0.04
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Active = true
	win.Parent = gui
	createCorner(win, self.cornerRadius + 4)
	createGradient(win, 115, ColorSequence.new(theme.bgTop, theme.bgBot))
	local winStroke, winStrokeGradient = self:Stroke(win, 1.5, 1)
	self:_spin(winStrokeGradient, 35)

	local winScale = Instance.new("UIScale")
	winScale.Scale = baseScale * 0.85
	winScale.Parent = win

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, self.sidebarWidth, 1, 0)
	sidebar.BackgroundColor3 = WHITE
	sidebar.BackgroundTransparency = 0.12
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 2
	sidebar.Parent = win
	createCorner(sidebar, self.cornerRadius + 4)
	createGradient(sidebar, 90, ColorSequence.new(theme.sidebarTop, theme.sidebarBot))
	self.sidebar = sidebar

	local sidebarLogo = self:Icon(sidebar, self.logo, UDim2.new(0, 68, 0, 68), UDim2.new(0, 12, 0, 4), WHITE)
	sidebarLogo.ScaleType = Enum.ScaleType.Fit
	sidebarLogo.ZIndex = 3
	self.logoLabel = sidebarLogo

	self:Label(sidebar, self.title, UDim2.new(1, -20, 0, 18), UDim2.new(0, 16, 0, 72), { font = theme.fontBold, textSize = 15 })
	self:Label(sidebar, self.subtitle, UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 0, 90), { font = theme.font, textSize = 10, color = theme.accentLight })

	self.statusLabel = self:Label(sidebar, "", UDim2.new(1, -20, 0, 12), UDim2.new(0, 16, 1, -24), { font = theme.font, textSize = 9, color = theme.good })

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -self.sidebarWidth, 1, 0)
	content.Position = UDim2.new(0, self.sidebarWidth, 0, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = win
	self.content = content

	-- tabs
	for index, tab in ipairs(tabs) do
		self:_addTabButton(sidebar, index, tab)
	end

	-- toast / notify
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 250, 0, 28)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, self.windowSize.Y.Offset + 10)
	toast.BackgroundColor3 = theme.cardBot
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.ZIndex = 20
	toast.Parent = content
	createCorner(toast, 999)
	local toastStroke = self:Stroke(toast, 1, 1)
	local toastLabel = self:Label(toast, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), {
		font = theme.fontMedium,
		textSize = 11,
		alignment = Enum.TextXAlignment.Center,
	})
	toastLabel.ZIndex = 21
	toastLabel.TextTransparency = 1

	local toastIcon = self:Icon(toast, "bell", UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), theme.text)
	toastIcon.ImageTransparency = 1
	toastIcon.ZIndex = 22

	self._toast = { frame = toast, stroke = toastStroke, label = toastLabel, icon = toastIcon, token = 0, restY = self.windowSize.Y.Offset + 10, showY = self.windowSize.Y.Offset - 38 }

	-- top-right minimize/close buttons
	local topButtons = Instance.new("Frame")
	topButtons.Size = UDim2.new(0, 54, 0, 22)
	topButtons.Position = UDim2.new(1, -68, 0, 26)
	topButtons.BackgroundTransparency = 1
	topButtons.ZIndex = 10
	topButtons.Parent = content

	local minChip = self:Chip(topButtons, UDim2.new(0, 22, 0, 22), UDim2.new(0, 0, 0, 0), "", 13, 999)
	minChip.button.ZIndex = 11
	self:Icon(minChip.button, "minimize", UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), theme.text).ZIndex = 12
	minChip.setOn(false, true)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(0, 32, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(120, 32, 62)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 11
	closeBtn.Parent = topButtons
	createCorner(closeBtn, 999)
	self:Icon(closeBtn, "close", UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), theme.text).ZIndex = 12

	self:_track(closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(190, 48, 92) })
	end))
	self:_track(closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(120, 32, 62) })
	end))

	local blur = Instance.new("BlurEffect")
	blur.Name = randomName()
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera or lighting
	self.blur = blur

	local function showWindow()
		self.minimized = false
		self.animating = true
		win.Visible = true
		baseScale = getBaseScale()
		tween(winScale, 0.5, { Scale = baseScale }, Enum.EasingStyle.Back)
		tween(winStroke, 0.3, { Transparency = 0.15 })
		tween(blur, 0.4, { Size = 6 })
		task.delay(0.5, function()
			self.animating = false
		end)
	end
	self._showWindow = showWindow

	local function hideWindow(onDone)
		self.animating = true
		tween(winScale, 0.25, { Scale = baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(winStroke, 0.25, { Transparency = 1 })
		tween(blur, 0.25, { Size = 0 })
		task.delay(0.28, function()
			if not self.alive then
				return
			end
			win.Visible = false
			self.animating = false
			if onDone then
				onDone()
			end
		end)
	end

	self:_track(minChip.button.MouseButton1Click:Connect(function()
		self:Minimize()
	end))
	self:_track(miniBtn.MouseButton1Click:Connect(function()
		self:Restore()
	end))
	self:_track(closeBtn.MouseButton1Click:Connect(function()
		if self.animating then
			return
		end
		self:_playSound("Click")
		hideWindow(function()
			self:Destroy()
		end)
	end))

	self._miniBtn = miniBtn
	self._miniScale = miniScale
	self._win = win
	self._winScale = winScale
	self._winStroke = winStroke
	self._getBaseScale = getBaseScale
	self._hideWindow = hideWindow
	self._baseScaleRef = function()
		return baseScale
	end

	self:_track(userInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= self.toggleKey then
			return
		end
		if self.minimized then
			self:Restore()
		else
			self:Minimize()
		end
	end))

	-- window dragging (grab anywhere on sidebar or a header you add)
	local draggingWindow = false
	local dragStart, startPosition

	local function beginDrag(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingWindow = true
			dragStart = input.Position
			startPosition = win.Position
		end
	end

	self:_track(sidebar.InputBegan:Connect(beginDrag))
	self._beginDrag = beginDrag -- expose so page headers you add can also be grab handles

	self:_track(userInputService.InputChanged:Connect(function(input)
		if draggingWindow and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			win.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
		end
	end))

	self:_track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingWindow = false
		end
	end))

	local camera = workspace.CurrentCamera
	if camera then
		self:_track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			baseScale = getBaseScale()
			if not self.animating and not self.minimized then
				winScale.Scale = baseScale
			end
		end))
	end

	self:_track(runService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, spinner in ipairs(self.spinners) do
			spinner.gradient.Rotation = (spinner.offset + now * spinner.speed) % 360
		end
	end))

	if self.pageButtons[tabs[1] and tabs[1].Id] then
		self:SetPage(tabs[1].Id, true)
	end

	showWindow()
end

function AxionLib:_addTabButton(sidebar, index, tab)
	local chip = self:Chip(sidebar, UDim2.new(1, -24, 0, 42), UDim2.new(0, 12, 0, 132 + (index - 1) * 46), "", 11, 22)

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 28, 0, 28)
	badge.Position = UDim2.new(0, 8, 0.5, -14)
	badge.BackgroundColor3 = self.theme.bgBot
	badge.BackgroundTransparency = 0.35
	badge.BorderSizePixel = 0
	badge.ZIndex = 6
	badge.Parent = chip.button
	createCorner(badge, 999)

	self:Icon(badge, tab.Icon, UDim2.new(0, 16, 0, 16), UDim2.new(0.5, -8, 0.5, -8), self.theme.accentLight)

	local nameLabel = self:Label(chip.button, tab.Label or tab.Id, UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7), {
		font = self.theme.fontBold,
		textSize = 11.5,
		color = self.theme.textDim,
	})
	nameLabel.ZIndex = 6

	local descLabel = self:Label(chip.button, tab.Desc or "", UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23), {
		font = self.theme.font,
		textSize = 9,
		color = self.theme.muted,
	})
	descLabel.ZIndex = 6

	local page = self:Page(self.content)
	self.pages[tab.Id] = page
	self.pageButtons[tab.Id] = { button = chip.button, chip = chip, name = nameLabel, desc = descLabel }

	self:_track(chip.button.MouseButton1Click:Connect(function()
		self:SetPage(tab.Id)
	end))

	return page
end

--// Public API -------------------------------------------------------------

-- Add a tab/page after window creation.
function AxionLib:AddTab(tab)
	local index = 0
	for _ in pairs(self.pageButtons) do
		index = index + 1
	end
	local page = self:_addTabButton(self.sidebar, index + 1, tab)
	if not self.activePage then
		self:SetPage(tab.Id, true)
	end
	return page
end

function AxionLib:GetPage(id)
	return self.pages[id]
end

function AxionLib:SetPage(id, instant)
	if self.activePage == id then
		return
	end

	self.activePage = id
	self:_playSound("TabSwitch")

	for pageId, data in pairs(self.pageButtons) do
		local on = pageId == id
		data.name.TextColor3 = on and self.theme.text or self.theme.textDim
		data.desc.TextColor3 = on and self.theme.text or self.theme.muted
		data.chip.setOn(on, instant)
	end

	for pageId, frame in pairs(self.pages) do
		if pageId ~= id then
			frame.Visible = false
		elseif instant then
			frame.Position = UDim2.new()
			frame.Visible = true
		else
			frame.Position = UDim2.new(0, 0, 0, 16)
			frame.Visible = true
			tween(frame, 0.35, { Position = UDim2.new() }, Enum.EasingStyle.Quart)
		end
	end
end

-- Update the small status line at the bottom of the sidebar.
function AxionLib:SetStatus(text, color)
	self.statusLabel.Text = text
	self.statusLabel.TextColor3 = color or self.theme.good
end

function AxionLib:SetLogo(image)
	self.logo = resolveIcon(image, self.logo)
	self.logoLabel.Image = self.logo
end

function AxionLib:Notify(text, color)
	local toast = self._toast
	toast.token = toast.token + 1
	local token = toast.token

	toast.label.Text = text
	toast.label.TextColor3 = color or self.theme.text
	toast.icon.Image = resolveIcon(color == self.theme.good and "check" or "bell")
	toast.frame.Position = UDim2.new(0.5, 0, 0, toast.restY)

	tween(toast.frame, 0.35, { Position = UDim2.new(0.5, 0, 0, toast.showY), BackgroundTransparency = 0.1 }, Enum.EasingStyle.Back)
	tween(toast.label, 0.25, { TextTransparency = 0 })
	tween(toast.stroke, 0.25, { Transparency = 0.4 })
	tween(toast.icon, 0.25, { ImageTransparency = 0 })
	self:_playSound("Notify")

	task.delay(2.2, function()
		if token ~= toast.token or not self.alive then
			return
		end
		tween(toast.frame, 0.3, { Position = UDim2.new(0.5, 0, 0, toast.restY), BackgroundTransparency = 1 })
		tween(toast.label, 0.25, { TextTransparency = 1 })
		tween(toast.stroke, 0.25, { Transparency = 1 })
		tween(toast.icon, 0.25, { ImageTransparency = 1 })
	end)
end

function AxionLib:Minimize()
	if self.animating then
		return
	end
	self:_playSound("Dropdown")
	self.minimized = true
	self._hideWindow(function()
		self._miniBtn.Visible = true
		self._miniScale.Scale = 0
		tween(self._miniScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

function AxionLib:Restore()
	if self.animating then
		return
	end
	self:_playSound("Dropdown")
	tween(self._miniScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.2, function()
		self._miniBtn.Visible = false
	end)
	self._showWindow()
end

function AxionLib:Destroy()
	self.alive = false

	for _, connection in ipairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.connections)
	table.clear(self.spinners)

	if self.blur then
		pcall(function()
			self.blur:Destroy()
		end)
	end

	if self.gui then
		pcall(function()
			self.gui:Destroy()
		end)
	end
end

--// Standalone loading screen (optional, used while your script sets up) --

-- AxionLib.CreateLoadingScreen({ Title = "MyHub", Logo = ... })
-- returns { SetStep = function(text, progress), Destroy = function() }
function AxionLib.CreateLoadingScreen(options)
	options = options or {}
	local theme = setmetatable(options.Theme or {}, { __index = DEFAULT_THEME })
	local title = options.Title or "Loading"
	local logo = resolveIcon(options.Logo, "rbxassetid://10723407389")

	local gui = Instance.new("ScreenGui")
	gui.Name = randomName()
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1000
	gui.Parent = safeParent()

	local root = Instance.new("CanvasGroup")
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.GroupTransparency = 1
	root.Parent = gui

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = WHITE
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.ZIndex = 1
	overlay.Parent = root
	createGradient(overlay, 115, ColorSequence.new(theme.bgTop, theme.bgBot))

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(0, 320, 0, 220)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = 2
	holder.Parent = root

	local holderScale = Instance.new("UIScale")
	holderScale.Parent = holder

	local function getScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(viewport.X * 0.9 / 340, viewport.Y * 0.8 / 240, 1), 0.5, 1)
	end
	holderScale.Scale = getScale()

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 1, 0)
	card.BackgroundColor3 = WHITE
	card.BackgroundTransparency = 0.03
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = holder
	createCorner(card, 18)
	createGradient(card, 110, ColorSequence.new(theme.bgTop, theme.bgBot))

	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 1.5
	stroke.Transparency = 0.35
	stroke.Parent = card
	createGradient(stroke, 45, ColorSequence.new(theme.accentBlue, theme.accentPink))

	local logoImage = Instance.new("ImageLabel")
	logoImage.Size = UDim2.new(0, 72, 0, 72)
	logoImage.Position = UDim2.new(0.5, -36, 0, 20)
	logoImage.BackgroundTransparency = 1
	logoImage.Image = logo
	logoImage.ScaleType = Enum.ScaleType.Fit
	logoImage.ZIndex = 5
	logoImage.Parent = card

	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logoImage

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -40, 0, 26)
	nameLabel.Position = UDim2.new(0, 20, 0, 100)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = title
	nameLabel.Font = theme.fontBold
	nameLabel.TextSize = 20
	nameLabel.TextColor3 = theme.text
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.ZIndex = 5
	nameLabel.Parent = card

	local barTrack = Instance.new("Frame")
	barTrack.Size = UDim2.new(1, -80, 0, 8)
	barTrack.Position = UDim2.new(0, 40, 0, 146)
	barTrack.BackgroundColor3 = theme.track
	barTrack.BorderSizePixel = 0
	barTrack.ZIndex = 4
	barTrack.Parent = card
	createCorner(barTrack, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = barTrack
	createCorner(fill, 999)
	local fillGradient = createGradient(fill, 0, ColorSequence.new(theme.accentBlue, theme.accentPink))

	local stepLabel = Instance.new("TextLabel")
	stepLabel.Size = UDim2.new(1, -40, 0, 16)
	stepLabel.Position = UDim2.new(0, 20, 0, 164)
	stepLabel.BackgroundTransparency = 1
	stepLabel.Text = "Starting..."
	stepLabel.Font = theme.fontMedium
	stepLabel.TextSize = 11
	stepLabel.TextColor3 = theme.textDim
	stepLabel.TextXAlignment = Enum.TextXAlignment.Center
	stepLabel.ZIndex = 5
	stepLabel.Parent = card

	local percent = Instance.new("TextLabel")
	percent.Size = UDim2.new(1, -40, 0, 14)
	percent.Position = UDim2.new(0, 20, 0, 184)
	percent.BackgroundTransparency = 1
	percent.Text = "0%"
	percent.Font = theme.font
	percent.TextSize = 10
	percent.TextColor3 = theme.muted
	percent.TextXAlignment = Enum.TextXAlignment.Center
	percent.ZIndex = 5
	percent.Parent = card

	local state = { progress = 0, target = 0, alive = true }

	local connection
	connection = runService.Heartbeat:Connect(function(dt)
		local diff = state.target - state.progress
		state.progress = state.progress + diff * math.min(dt * 6, 1)

		fill.Size = UDim2.new(math.clamp(state.progress, 0, 1), 0, 1, 0)
		percent.Text = string.format("%d%%", math.floor(state.progress * 100 + 0.5))

		local now = os.clock()
		logoScale.Scale = 1 + math.sin(now * 3) * 0.04
		fillGradient.Offset = Vector2.new(math.sin(now * 2) * 0.25, 0)
		holderScale.Scale = getScale()
	end)

	tween(root, 0.3, { GroupTransparency = 0 })

	local handle = {}

	function handle.SetStep(text, progress)
		if not state.alive then
			return
		end
		stepLabel.Text = text
		state.target = progress
	end

	function handle.Destroy(animated)
		if not state.alive then
			return
		end

		local function cleanup()
			if connection then
				connection:Disconnect()
				connection = nil
			end
			state.alive = false
			pcall(function()
				gui:Destroy()
			end)
		end

		if animated == false then
			cleanup()
			return
		end

		state.target = 1
		task.spawn(function()
			local deadline = os.clock() + 1
			while state.progress < 0.97 and os.clock() < deadline do
				task.wait()
			end
			tween(root, 0.4, { GroupTransparency = 1 })
			task.wait(0.45)
			cleanup()
		end)
	end

	return handle
end

return AxionLib
