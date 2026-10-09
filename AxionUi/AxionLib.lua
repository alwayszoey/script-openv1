-- AxionLib.lua
local Library = {}
Library.__index = Library

local Tab = {}
Tab.__index = Tab

local Card = {}
Card.__index = Card

-- Constants.
local WHITE = Color3.new(1, 1, 1)
local SIDEBAR_WIDTH = 150
local CORNER_RADIUS = 12
local WINDOW_WIDTH = 590
local WINDOW_HEIGHT = 410
local ICONS_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"

local Theme = {
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
	blurSize = 6,
}

Library.Theme = Theme

local SoundMap = {
	Click = { pitch = 1.10, vol = 0.32 },
	ToggleOn = { pitch = 1.40, vol = 0.35 },
	ToggleOff = { pitch = 0.88, vol = 0.28 },
	TabSwitch = { pitch = 1.25, vol = 0.30 },
	Notify = { pitch = 1.35, vol = 0.38 },
}

local DEFAULT_ICONS = {
	logo = "rbxassetid://10709819149",
	close = "rbxassetid://10747384394",
	minimize = "rbxassetid://10709791185",
	bell = "rbxassetid://10709752996",
	check = "rbxassetid://10709790644",
}

local ICON_NAMES = {
	close = "x",
	minimize = "minimize-2",
	bell = "bell",
	check = "check",
}

-- Services.
local cloneRef = cloneref or function(value)
	return value
end

local tweenService = cloneRef(game:GetService("TweenService"))
local userInputService = cloneRef(game:GetService("UserInputService"))
local runService = cloneRef(game:GetService("RunService"))
local lighting = cloneRef(game:GetService("Lighting"))
local coreGui = cloneRef(game:GetService("CoreGui"))
local soundService = cloneRef(game:GetService("SoundService"))

-- Icon library, loaded once and shared by every window.
local rawIcons = {}
local iconsLoaded = false

local function loadIconLibrary()
	if iconsLoaded then
		return
	end

	iconsLoaded = true

	local ok, response = pcall(request, { Url = ICONS_URL, Method = "GET" })
	if not ok or not response or not response.Success then
		return
	end

	local chunk = loadstring(response.Body)
	if not chunk then
		return
	end

	local loaded, data = pcall(chunk)
	if loaded and type(data) == "table" then
		rawIcons = data
	end
end

---Accept an asset id, a url, or an icon name from the library.
---@param input string|number
---@param fallback string?
---@return string
local function getIcon(input, fallback)
	if type(input) == "number" then
		return "rbxassetid://" .. input
	end

	if type(input) ~= "string" or input == "" then
		return fallback or ""
	end

	if input:find("rbxassetid://", 1, true) or input:find("http", 1, true) or input:find("rbxthumb://", 1, true) then
		return input
	end

	local found = rawIcons[input:lower()]

	if type(found) == "number" then
		return "rbxassetid://" .. found
	end

	if type(found) == "string" and found ~= "" then
		return found
	end

	return fallback or input
end

---Resolve a built-in icon with the library name first.
local function builtinIcon(key)
	return getIcon(ICON_NAMES[key], DEFAULT_ICONS[key])
end

-- Instance helpers.
local function tween(object, duration, goal, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	tweenService:Create(object, info, goal):Play()
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

local function accentSequence()
	return ColorSequence.new(Theme.accentBlue, Theme.accentPink)
end

local function createStroke(parent, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke, createGradient(stroke, 45, accentSequence())
end

local function makeIcon(parent, image, size, position, color)
	local icon = Instance.new("ImageLabel")
	icon.Size = size
	icon.Position = position
	icon.Image = getIcon(image)
	icon.ImageColor3 = color or WHITE
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.ZIndex = 8
	icon.Parent = parent
	return icon
end

local function makeLabel(parent, text, size, position, font, textSize, color, alignment)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = font or Theme.font
	label.TextSize = textSize or 11
	label.TextColor3 = color or Theme.text
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent
	return label
end

---Keep a connection so destroy can clean it up.
---@param self table
local function track(self, connection)
	table.insert(self.connections, connection)
	return connection
end

local function makeChip(parent, size, position, text, textSize, radius)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Theme.chipOff
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
	createGradient(glow, 20, accentSequence())

	local label = makeLabel(
		button,
		text,
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		Theme.fontBold,
		textSize,
		Theme.textDim,
		Enum.TextXAlignment.Center
	)

	return { button = button, glow = glow, label = label, on = false }
end

local function refreshChip(chip, hover, instant)
	local buttonGoal = { BackgroundColor3 = hover and Theme.chipHover or Theme.chipOff }
	local glowGoal = { BackgroundTransparency = chip.on and 0 or 1 }
	local labelGoal = { TextColor3 = chip.on and Theme.text or Theme.textDim }

	if instant then
		chip.button.BackgroundColor3 = buttonGoal.BackgroundColor3
		chip.glow.BackgroundTransparency = glowGoal.BackgroundTransparency
		chip.label.TextColor3 = labelGoal.TextColor3
		return
	end

	tween(chip.button, 0.18, buttonGoal)
	tween(chip.glow, 0.22, glowGoal)
	tween(chip.label, 0.18, labelGoal)
end

local function styleChip(chip, on, instant)
	chip.on = on
	refreshChip(chip, false, instant)
end

local function addHover(self, chip)
	track(self, chip.button.MouseEnter:Connect(function()
		refreshChip(chip, true)
	end))

	track(self, chip.button.MouseLeave:Connect(function()
		refreshChip(chip, false)
	end))
end

-- Window.

---Create a window.
---@param options table? title, subtitle, logo, toggleKey, uiSound, soundId, onClose, parent
---@return table
function Library.new(options)
	options = options or {}

	local self = setmetatable({}, Library)
	self.alive = true
	self.connections = {}
	self.spinners = {}
	self.tabs = {}
	self.minimized = false
	self.animating = false
	self.uiSound = options.uiSound ~= false
	self.soundId = options.soundId or "rbxassetid://6895079853"
	self.toggleKey = options.toggleKey or Enum.KeyCode.RightShift
	self.onClose = options.onClose
	self.toastToken = 0

	loadIconLibrary()

	local logo = getIcon(options.logo, DEFAULT_ICONS.logo)
	local parent = options.parent

	if not parent then
		local ok, hui = pcall(function()
			return gethui()
		end)
		parent = ok and hui or coreGui
	end

	local chars = {}
	for index = 1, math.random(10, 16) do
		chars[index] = string.char(math.random(97, 122))
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = table.concat(chars)
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent
	self.gui = gui

	-- Minimized launcher.
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
	self:spin(createGradient(miniBtn, 45, accentSequence()), 60)
	createStroke(miniBtn, 1.5, 0.3)

	local miniScale = Instance.new("UIScale")
	miniScale.Scale = 0
	miniScale.Parent = miniBtn
	makeIcon(miniBtn, logo, UDim2.new(1, -12, 1, -12), UDim2.new(0, 6, 0, 6))

	local function getBaseScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(viewport.X * 0.9 / WINDOW_WIDTH, viewport.Y * 0.78 / WINDOW_HEIGHT, 1), 0.4, 1)
	end

	local baseScale = getBaseScale()

	local win = Instance.new("Frame")
	win.Name = "Window"
	win.Size = UDim2.new(0, WINDOW_WIDTH, 0, WINDOW_HEIGHT)
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.new(0.5, 0, 0.5, 0)
	win.BackgroundColor3 = WHITE
	win.BackgroundTransparency = 0.04
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Active = true
	win.Parent = gui
	createCorner(win, CORNER_RADIUS + 4)
	createGradient(win, 115, ColorSequence.new(Theme.bgTop, Theme.bgBot))
	local winStroke, winStrokeGradient = createStroke(win, 1.5, 1)
	self:spin(winStrokeGradient, 35)

	local winScale = Instance.new("UIScale")
	winScale.Scale = baseScale * 0.85
	winScale.Parent = win

	local veil = Instance.new("Frame")
	veil.Size = UDim2.new(1, 0, 1, 0)
	veil.BackgroundColor3 = Theme.bgBot
	veil.BorderSizePixel = 0
	veil.Active = false
	veil.ZIndex = 100
	veil.Parent = win
	createCorner(veil, CORNER_RADIUS + 4)

	-- Sidebar.
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
	sidebar.BackgroundColor3 = WHITE
	sidebar.BackgroundTransparency = 0.12
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 2
	sidebar.Parent = win
	createCorner(sidebar, CORNER_RADIUS + 4)
	createGradient(sidebar, 90, ColorSequence.new(Theme.sidebarTop, Theme.sidebarBot))

	local sidebarLogo = makeIcon(sidebar, logo, UDim2.new(0, 68, 0, 68), UDim2.new(0, 12, 0, 4), WHITE)
	sidebarLogo.ScaleType = Enum.ScaleType.Fit
	sidebarLogo.ZIndex = 3

	makeLabel(sidebar, options.title or "AxionLib", UDim2.new(1, -20, 0, 18), UDim2.new(0, 16, 0, 72), Theme.fontBold, 15, Theme.text)
	makeLabel(sidebar, options.subtitle or "", UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 0, 90), Theme.font, 10, Theme.accentLight)

	local footerLabel = makeLabel(sidebar, "", UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 1, -26), Theme.fontMedium, 10, Theme.textDim)
	self.footerLabel = footerLabel

	local tabList = Instance.new("Frame")
	tabList.Size = UDim2.new(1, -24, 1, -190)
	tabList.Position = UDim2.new(0, 12, 0, 132)
	tabList.BackgroundTransparency = 1
	tabList.Parent = sidebar

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabList

	-- Content.
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0)
	content.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = win

	-- Title bar is also the drag handle.
	local topBar = Instance.new("Frame")
	topBar.Size = UDim2.new(1, 0, 0, 44)
	topBar.BackgroundTransparency = 1
	topBar.ZIndex = 9
	topBar.Parent = content

	local titleLabel = makeLabel(topBar, "", UDim2.new(1, -100, 1, 0), UDim2.new(0, 18, 0, 0), Theme.fontBold, 13, Theme.text)
	titleLabel.ZIndex = 10

	local buttons = Instance.new("Frame")
	buttons.Size = UDim2.new(0, 54, 0, 22)
	buttons.Position = UDim2.new(1, -68, 0, 12)
	buttons.BackgroundTransparency = 1
	buttons.ZIndex = 10
	buttons.Parent = topBar

	local minChip = makeChip(buttons, UDim2.new(0, 22, 0, 22), UDim2.new(0, 0, 0, 0), "", 13, 999)
	minChip.button.ZIndex = 11
	makeIcon(minChip.button, builtinIcon("minimize"), UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), Theme.text).ZIndex = 12
	addHover(self, minChip)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(0, 32, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(120, 32, 62)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 11
	closeBtn.Parent = buttons
	createCorner(closeBtn, 999)
	makeIcon(closeBtn, builtinIcon("close"), UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), Theme.text).ZIndex = 12

	track(self, closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(190, 48, 92) })
	end))
	track(self, closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(120, 32, 62) })
	end))

	-- Toast.
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 250, 0, 28)
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, 40)
	toast.BackgroundColor3 = Theme.cardBot
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.ZIndex = 20
	toast.Parent = content
	createCorner(toast, 999)

	local toastStroke = createStroke(toast, 1, 1)
	local toastLabel = makeLabel(toast, "", UDim2.new(1, -28, 1, 0), UDim2.new(0, 28, 0, 0), Theme.fontMedium, 11, Theme.text, Enum.TextXAlignment.Left)
	toastLabel.ZIndex = 21
	toastLabel.TextTransparency = 1

	local toastIcon = makeIcon(toast, builtinIcon("bell"), UDim2.new(0, 14, 0, 14), UDim2.new(0, 10, 0.5, -7), Theme.text)
	toastIcon.ImageTransparency = 1
	toastIcon.ZIndex = 22

	local blur = Instance.new("BlurEffect")
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera or lighting
	self.blur = blur

	self.win = win
	self.content = content
	self.tabList = tabList
	self.titleLabel = titleLabel
	self.toast = toast
	self.toastLabel = toastLabel
	self.toastIcon = toastIcon
	self.toastStroke = toastStroke
	self.winScale = winScale
	self.winStroke = winStroke
	self.veil = veil
	self.miniBtn = miniBtn
	self.miniScale = miniScale
	self.getBaseScale = getBaseScale
	self.baseScale = baseScale

	-- Open / close animations.
	function self:show()
		self.minimized = false
		self.animating = true

		self.win.Visible = true
		self.baseScale = self.getBaseScale()
		tween(self.winScale, 0.5, { Scale = self.baseScale }, Enum.EasingStyle.Back)
		tween(self.veil, 0.35, { BackgroundTransparency = 1 })
		tween(self.winStroke, 0.3, { Transparency = 0.15 })
		tween(self.blur, 0.4, { Size = Theme.blurSize })

		task.delay(0.5, function()
			self.animating = false
		end)
	end

	function self:hide(onDone)
		self.animating = true

		tween(self.winScale, 0.25, { Scale = self.baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(self.veil, 0.25, { BackgroundTransparency = 0 })
		tween(self.winStroke, 0.25, { Transparency = 1 })
		tween(self.blur, 0.25, { Size = 0 })

		task.delay(0.28, function()
			if not self.alive then
				return
			end

			self.win.Visible = false
			self.animating = false

			if onDone then
				onDone()
			end
		end)
	end

	function self:minimize()
		if self.animating or self.minimized then
			return
		end

		self.minimized = true
		self:hide(function()
			self.miniBtn.Visible = true
			self.miniScale.Scale = 0
			tween(self.miniScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end

	function self:restore()
		if self.animating or not self.minimized then
			return
		end

		tween(self.miniScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.2, function()
			self.miniBtn.Visible = false
		end)
		self:show()
	end

	track(self, minChip.button.MouseButton1Click:Connect(function()
		self:playSound("Click")
		self:minimize()
	end))

	track(self, miniBtn.MouseButton1Click:Connect(function()
		self:playSound("Click")
		self:restore()
	end))

	track(self, closeBtn.MouseButton1Click:Connect(function()
		if self.animating then
			return
		end

		self:playSound("Click")

		if self.onClose then
			pcall(self.onClose)
		end

		self:hide(function()
			self:destroy()
		end)
	end))

	track(self, userInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= self.toggleKey then
			return
		end

		if self.minimized then
			self:restore()
		else
			self:minimize()
		end
	end))

	-- Window drag through the title bar.
	local dragging = false
	local dragStart, startPosition

	track(self, topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = win.Position
		end
	end))

	track(self, userInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			local delta = input.Position - dragStart
			win.Position = UDim2.new(
				startPosition.X.Scale,
				startPosition.X.Offset + delta.X,
				startPosition.Y.Scale,
				startPosition.Y.Offset + delta.Y
			)
		end
	end))

	track(self, userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	local camera = workspace.CurrentCamera
	if camera then
		track(self, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self.baseScale = self.getBaseScale()
			if not self.animating and not self.minimized then
				self.winScale.Scale = self.baseScale
			end
		end))
	end

	-- Rotating gradients.
	track(self, runService.Heartbeat:Connect(function()
		if self.minimized then
			return
		end

		local now = os.clock()
		for _, spinner in ipairs(self.spinners) do
			spinner.gradient.Rotation = (spinner.offset + now * spinner.speed) % 360
		end
	end))

	self:show()

	return self
end

---Register a gradient that slowly rotates.
function Library:spin(gradient, speed)
	table.insert(self.spinners, { gradient = gradient, speed = speed, offset = gradient.Rotation })
end

---Play a short ui sound.
---@param name string
function Library:playSound(name)
	local info = SoundMap[name]
	if not self.uiSound or not info then
		return
	end

	task.spawn(function()
		local sound = Instance.new("Sound")
		sound.SoundId = self.soundId
		sound.Volume = info.vol
		sound.PlaybackSpeed = info.pitch
		sound.Parent = soundService
		sound:Play()

		task.delay(3, function()
			sound:Destroy()
		end)
	end)
end

---Toggle ui sounds.
function Library:setSound(value)
	self.uiSound = value
end

---Text shown at the bottom of the sidebar.
function Library:setFooter(text, color)
	self.footerLabel.Text = text
	self.footerLabel.TextColor3 = color or Theme.textDim
end

---Show a toast message.
---@param text string
---@param color Color3?
function Library:notify(text, color)
	if not self.alive then
		return
	end

	self.toastToken = self.toastToken + 1
	local token = self.toastToken

	self.toastLabel.Text = text
	self.toastLabel.TextColor3 = color or Theme.text
	self.toastIcon.Image = color == Theme.good and builtinIcon("check") or builtinIcon("bell")
	self.toast.Position = UDim2.new(0.5, 0, 1, 40)

	tween(self.toast, 0.35, { Position = UDim2.new(0.5, 0, 1, -16), BackgroundTransparency = 0.1 }, Enum.EasingStyle.Back)
	tween(self.toastLabel, 0.25, { TextTransparency = 0 })
	tween(self.toastStroke, 0.25, { Transparency = 0.4 })
	tween(self.toastIcon, 0.25, { ImageTransparency = 0 })
	self:playSound("Notify")

	task.delay(2.2, function()
		if token ~= self.toastToken or not self.alive then
			return
		end

		tween(self.toast, 0.3, { Position = UDim2.new(0.5, 0, 1, 40), BackgroundTransparency = 1 })
		tween(self.toastLabel, 0.25, { TextTransparency = 1 })
		tween(self.toastStroke, 0.25, { Transparency = 1 })
		tween(self.toastIcon, 0.25, { ImageTransparency = 1 })
	end)
end

---Remove the interface and disconnect everything.
function Library:destroy()
	if not self.alive then
		return
	end

	self.alive = false

	for _, connection in ipairs(self.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.connections)
	table.clear(self.spinners)

	pcall(function()
		self.blur:Destroy()
	end)

	pcall(function()
		self.gui:Destroy()
	end)
end

-- Tabs.

---Add a sidebar tab with its own page.
---@param options table name, desc, icon
---@return table
function Library:addTab(options)
	options = options or {}

	local tab = setmetatable({}, Tab)
	tab.window = self
	tab.name = options.name or "Tab"

	local chip = makeChip(self.tabList, UDim2.new(1, 0, 0, 42), UDim2.new(), "", 11, 22)
	chip.button.LayoutOrder = #self.tabs + 1
	addHover(self, chip)

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 28, 0, 28)
	badge.Position = UDim2.new(0, 8, 0.5, -14)
	badge.BackgroundColor3 = Theme.bgBot
	badge.BackgroundTransparency = 0.35
	badge.BorderSizePixel = 0
	badge.ZIndex = 6
	badge.Parent = chip.button
	createCorner(badge, 999)
	makeIcon(badge, options.icon or "home", UDim2.new(0, 16, 0, 16), UDim2.new(0.5, -8, 0.5, -8), Theme.accentLight)

	tab.nameLabel = makeLabel(chip.button, tab.name, UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7), Theme.fontBold, 11.5, Theme.textDim)
	tab.nameLabel.ZIndex = 6
	tab.descLabel = makeLabel(chip.button, options.desc or "", UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23), Theme.font, 9, Theme.muted)
	tab.descLabel.ZIndex = 6
	tab.chip = chip

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 2
	page.ScrollBarImageColor3 = Theme.accentLight
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = self.content
	tab.page = page

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 48)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.Parent = page

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	track(self, chip.button.MouseButton1Click:Connect(function()
		if self.activeTab == tab then
			return
		end

		self:playSound("TabSwitch")
		self:selectTab(tab)
	end))

	table.insert(self.tabs, tab)

	if not self.activeTab then
		self:selectTab(tab, true)
	end

	return tab
end

---Switch the visible tab.
---@param target table
---@param instant boolean?
function Library:selectTab(target, instant)
	self.activeTab = target
	self.titleLabel.Text = target.name

	for _, tab in ipairs(self.tabs) do
		local on = tab == target
		tab.nameLabel.TextColor3 = on and Theme.text or Theme.textDim
		tab.descLabel.TextColor3 = on and Theme.text or Theme.muted
		styleChip(tab.chip, on, instant)

		if not on then
			tab.page.Visible = false
		end
	end

	if instant then
		target.page.Position = UDim2.new()
		target.page.Visible = true
		return
	end

	target.page.Position = UDim2.new(0, 0, 0, 16)
	target.page.Visible = true
	tween(target.page, 0.35, { Position = UDim2.new() }, Enum.EasingStyle.Quart)
end

-- Cards.

---Add a card to the tab. Rows stack inside it automatically.
---@param title string?
---@return table
function Tab:addCard(title)
	local window = self.window

	local card = setmetatable({}, Card)
	card.window = window
	card.order = 0

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = WHITE
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.ZIndex = 3
	frame.LayoutOrder = #self.page:GetChildren()
	frame.Parent = self.page
	createCorner(frame, CORNER_RADIUS)
	createGradient(frame, 100, ColorSequence.new(Theme.cardTop, Theme.cardBot))
	createStroke(frame, 1, 0.65)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	card.frame = frame

	if title and title ~= "" then
		card:addSection(title)
	end

	return card
end

function Card:nextOrder()
	self.order = self.order + 1
	return self.order
end

function Card:makeRow(height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.ZIndex = 4
	row.LayoutOrder = self:nextOrder()
	row.Parent = self.frame
	return row
end

---Small caps heading.
function Card:addSection(text)
	local row = self:makeRow(18)
	makeLabel(row, text:upper(), UDim2.new(1, -28, 1, 0), UDim2.new(0, 14, 0, 0), Theme.fontBold, 9.5, Theme.accentLight)
	return row
end

---Plain text row.
---@param text string
---@param color Color3?
---@return table
function Card:addLabel(text, color)
	local row = self:makeRow(20)
	local label = makeLabel(row, text, UDim2.new(1, -28, 1, 0), UDim2.new(0, 14, 0, 0), Theme.font, 10, color or Theme.muted)
	label.TextWrapped = true

	return {
		set = function(value, newColor)
			label.Text = value
			if newColor then
				label.TextColor3 = newColor
			end
		end,
	}
end

---Toggle switch.
---@param options table title, default, icon, callback
---@return table
function Card:addToggle(options)
	local window = self.window
	local row = self:makeRow(40)

	local resolved = options.icon and getIcon(options.icon) or nil
	local icon
	if resolved and resolved ~= "" then
		icon = makeIcon(row, resolved, UDim2.new(0, 18, 0, 18), UDim2.new(0, 14, 0.5, -9), Theme.accentLight)
	end

	makeLabel(row, options.title or "Toggle", UDim2.new(0.7, 0, 1, 0), UDim2.new(0, icon and 40 or 14, 0, 0), Theme.fontMedium, 12, Theme.text)

	local pill = Instance.new("TextButton")
	pill.Size = UDim2.new(0, 46, 0, 24)
	pill.Position = UDim2.new(1, -60, 0.5, -12)
	pill.BackgroundColor3 = Theme.track
	pill.BorderSizePixel = 0
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.ZIndex = 5
	pill.Parent = row
	createCorner(pill, 999)
	createStroke(pill, 1, 0.6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = WHITE
	fill.BackgroundTransparency = 1
	fill.BorderSizePixel = 0
	fill.ZIndex = 6
	fill.Parent = pill
	createCorner(fill, 999)
	createGradient(fill, 0, accentSequence())

	local offPos = UDim2.new(0, 3, 0.5, -9)
	local onPos = UDim2.new(1, -21, 0.5, -9)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = offPos
	knob.BackgroundColor3 = Theme.muted
	knob.BorderSizePixel = 0
	knob.ZIndex = 7
	knob.Parent = pill
	createCorner(knob, 999)

	local state = options.default == true

	local function apply(instant)
		local fillGoal = state and 0 or 1
		local knobPos = state and onPos or offPos
		local knobColor = state and WHITE or Theme.muted

		if instant then
			fill.BackgroundTransparency = fillGoal
			knob.Position = knobPos
			knob.BackgroundColor3 = knobColor
			return
		end

		tween(fill, 0.2, { BackgroundTransparency = fillGoal })
		tween(knob, 0.3, { Position = knobPos, BackgroundColor3 = knobColor }, Enum.EasingStyle.Back)
	end

	apply(true)

	track(window, pill.MouseButton1Click:Connect(function()
		state = not state
		apply()
		window:playSound(state and "ToggleOn" or "ToggleOff")

		if options.callback then
			task.spawn(options.callback, state)
		end
	end))

	return {
		icon = icon,
		get = function()
			return state
		end,
		set = function(value)
			state = value == true
			apply()
		end,
	}
end

---Row of buttons.
---@param items table list of { text, icon, width, callback }
function Card:addButtons(items)
	local window = self.window
	local row = self:makeRow(40)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = row

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.Parent = row

	for _, item in ipairs(items) do
		local chip = makeChip(row, UDim2.new(0, item.width or 110, 0, 30), UDim2.new(), item.text or "Button", 10, 999)
		addHover(window, chip)

		if item.icon then
			chip.label.Position = UDim2.new(0, 22, 0, 0)
			chip.label.Size = UDim2.new(1, -28, 1, 0)
			makeIcon(chip.button, item.icon, UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), Theme.text)
		end

		track(window, chip.button.MouseButton1Click:Connect(function()
			window:playSound("Click")
			styleChip(chip, true)

			task.delay(0.3, function()
				if window.alive then
					styleChip(chip, false)
				end
			end)

			if item.callback then
				task.spawn(item.callback)
			end
		end))
	end
end

---Single choice chips.
---@param options table title, options (list of strings), default, callback
---@return table
function Card:addChoice(options)
	local window = self.window
	local row = self:makeRow(56)

	makeLabel(row, options.title or "Choice", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 2), Theme.fontMedium, 11, Theme.text)

	local chips = {}
	local current = options.default

	local function refresh(instant)
		for key, chip in pairs(chips) do
			styleChip(chip, key == current, instant)
		end
	end

	for index, name in ipairs(options.options or {}) do
		local chip = makeChip(row, UDim2.new(0, 82, 0, 28), UDim2.new(0, 14 + (index - 1) * 90, 0, 22), name, 11, 999)
		chips[name] = chip
		addHover(window, chip)

		track(window, chip.button.MouseButton1Click:Connect(function()
			window:playSound("Click")
			current = name
			refresh()

			if options.callback then
				task.spawn(options.callback, name)
			end
		end))
	end

	refresh(true)

	return {
		get = function()
			return current
		end,
		set = function(value)
			current = value
			refresh()
		end,
	}
end

---Number slider.
---@param options table title, min, max, default, suffix, callback
---@return table
function Card:addSlider(options)
	local window = self.window
	local minValue = options.min or 0
	local maxValue = options.max or 100
	local suffix = options.suffix or ""
	local value = math.clamp(options.default or minValue, minValue, maxValue)

	local row = self:makeRow(52)

	makeLabel(row, options.title or "Slider", UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 14, 0, 4), Theme.fontMedium, 11, Theme.text)
	local valueLabel = makeLabel(row, "", UDim2.new(0.5, -14, 0, 14), UDim2.new(0.5, 0, 0, 4), Theme.fontBold, 11, Theme.text, Enum.TextXAlignment.Right)

	local sliderTrack = Instance.new("TextButton")
	sliderTrack.Size = UDim2.new(1, -28, 0, 10)
	sliderTrack.Position = UDim2.new(0, 14, 0, 30)
	sliderTrack.BackgroundColor3 = Theme.track
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Text = ""
	sliderTrack.AutoButtonColor = false
	sliderTrack.ZIndex = 4
	sliderTrack.Parent = row
	createCorner(sliderTrack, 999)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = sliderTrack
	createCorner(fill, 999)
	createGradient(fill, 0, accentSequence())

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.BackgroundColor3 = WHITE
	knob.BorderSizePixel = 0
	knob.ZIndex = 6
	knob.Parent = sliderTrack
	createCorner(knob, 999)
	createStroke(knob, 2, 0)

	local function render()
		local relative = (value - minValue) / math.max(maxValue - minValue, 1)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		knob.Position = UDim2.new(relative, -8, 0.5, -8)
		valueLabel.Text = tostring(value) .. suffix
	end

	local function setFromX(x)
		local relative = math.clamp((x - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
		local newValue = math.floor(minValue + relative * (maxValue - minValue) + 0.5)

		if newValue == value then
			return
		end

		value = newValue
		render()

		if options.callback then
			task.spawn(options.callback, value)
		end
	end

	render()

	local dragging = false

	track(window, sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			window:playSound("Click")
			setFromX(input.Position.X)
			tween(knob, 0.15, { Size = UDim2.new(0, 20, 0, 20) })
		end
	end))

	track(window, userInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			setFromX(input.Position.X)
		end
	end))

	track(window, userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				tween(knob, 0.15, { Size = UDim2.new(0, 16, 0, 16) })
			end
		end
	end))

	return {
		get = function()
			return value
		end,
		set = function(newValue)
			value = math.clamp(newValue, minValue, maxValue)
			render()
		end,
	}
end

return Library
