-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Tear down a previous load so re-executing never stacks windows.
if shared.AxionLib then
	pcall(shared.AxionLib.destroy, shared.AxionLib)
end

local AxionLib = {
	version = "2.0.0",
	alive = true,
	flags = {},
	options = {},
	windows = {},
	configFolder = "AxionLib",
	themeName = "Purple",
}

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

-- Constants.
local ICONS_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/dist/Icons.lua"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local SIDEBAR_WIDTH = 150
local HEADER_HEIGHT = 48
local CORNER_RADIUS = 12
local FONT = Enum.Font.Gotham
local FONT_MEDIUM = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold

local BUILTIN_ICONS = {
	logo = "rbxassetid://10709819149",
	close = "rbxassetid://10747384394",
	minimize = "rbxassetid://10709791185",
	chevron = "rbxassetid://10709790948",
}

local THEME_PRESETS = {
	Purple = { Color3.fromRGB(84, 38, 232), Color3.fromRGB(172, 44, 248) },
	Ocean = { Color3.fromRGB(20, 110, 230), Color3.fromRGB(0, 200, 220) },
	Crimson = { Color3.fromRGB(200, 30, 60), Color3.fromRGB(255, 90, 60) },
	Emerald = { Color3.fromRGB(16, 150, 90), Color3.fromRGB(60, 220, 150) },
	Sunset = { Color3.fromRGB(240, 110, 30), Color3.fromRGB(240, 50, 120) },
	Mono = { Color3.fromRGB(70, 70, 90), Color3.fromRGB(150, 150, 175) },
}

local NOTIFY_COLORS = {
	info = "accentLight",
	success = "good",
	error = "bad",
	warning = "warn",
}

-- Services.
local cloneRef = cloneref or function(value)
	return value
end

local tweenService = cloneRef(game:GetService("TweenService"))
local userInputService = cloneRef(game:GetService("UserInputService"))
local runService = cloneRef(game:GetService("RunService"))
local httpService = cloneRef(game:GetService("HttpService"))
local coreGui = cloneRef(game:GetService("CoreGui"))
local lighting = cloneRef(game:GetService("Lighting"))

-- State.
local themedObjects = {}
local pendingIcons = {}
local rawIcons = {}
local iconsLoaded = false
local notifyGui = nil
local notifyHolder = nil
local notifyOrder = 0

---Derive a full palette from two accent colors.
---@param accentA Color3
---@param accentB Color3
---@return table
local function buildTheme(accentA, accentB)
	local mixed = accentA:Lerp(accentB, 0.5)
	local light = mixed:Lerp(WHITE, 0.6)

	return {
		accentA = accentA,
		accentB = accentB,
		accentLight = light,
		bgTop = accentA:Lerp(BLACK, 0.78),
		bgBot = accentA:Lerp(BLACK, 0.97),
		sidebarTop = accentA:Lerp(BLACK, 0.88),
		sidebarBot = accentA:Lerp(BLACK, 0.98),
		cardTop = accentA:Lerp(BLACK, 0.62),
		cardBot = accentA:Lerp(BLACK, 0.88),
		chipOff = accentA:Lerp(BLACK, 0.8),
		chipHover = accentA:Lerp(BLACK, 0.62),
		track = accentA:Lerp(BLACK, 0.92),
		text = WHITE,
		textDim = mixed:Lerp(WHITE, 0.88),
		muted = light:Lerp(BLACK, 0.35),
		good = Color3.fromRGB(130, 255, 180),
		bad = Color3.fromRGB(255, 100, 130),
		warn = Color3.fromRGB(255, 204, 102),
	}
end

local theme = buildTheme(THEME_PRESETS.Purple[1], THEME_PRESETS.Purple[2])
AxionLib.theme = theme

---Create an instance, apply properties, then parent it last.
---@param className string
---@param properties table
---@param parent Instance?
---@return Instance
local function create(className, properties, parent)
	local instance = Instance.new(className)

	for property, value in pairs(properties) do
		instance[property] = value
	end

	instance.Parent = parent
	return instance
end

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

local function tween(object, duration, goal, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local playing = tweenService:Create(object, info, goal)
	playing:Play()
	return playing
end

---Tween a goal, or apply it instantly when duration is 0.
local function transition(instance, goal, duration, style, direction)
	if not duration or duration <= 0 then
		for property, value in pairs(goal) do
			instance[property] = value
		end
		return
	end

	tween(instance, duration, goal, style, direction)
end

local function onCallbackError(message)
	warn("[AxionLib] Callback error: " .. tostring(message))
	warn(debug.traceback())
end

---Run a user callback on its own thread so UI code never breaks.
local function fire(callback, ...)
	if type(callback) ~= "function" then
		return
	end

	task.spawn(xpcall, callback, onCallbackError, ...)
end

local function hashString(text)
	local hash = 5381

	for index = 1, #text do
		hash = (hash * 33 + text:byte(index)) % 4294967296
	end

	return string.format("%08x", hash)
end

local function ensureFolder()
	if makefolder and isfolder and not isfolder(AxionLib.configFolder) then
		pcall(makefolder, AxionLib.configFolder)
	end
end

-- Theme binding. Bound properties follow the active theme automatically.

local function bind(instance, property, key)
	instance[property] = theme[key]
	table.insert(themedObjects, { instance = instance, property = property, key = key })
	return instance
end

---Run a refresh function whenever the theme changes (for stateful colors).
local function onTheme(owner, refresh)
	table.insert(themedObjects, { instance = owner, refresh = refresh })
end

local function addGradient(parent, rotation, keyA, keyB)
	local gradient = create("UIGradient", { Rotation = rotation }, parent)
	gradient.Color = ColorSequence.new(theme[keyA], theme[keyB])
	table.insert(themedObjects, { instance = gradient, gradient = true, keyA = keyA, keyB = keyB })
	return gradient
end

local function addCorner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function addStroke(parent, thickness, transparency)
	local stroke = create("UIStroke", {
		Color = WHITE,
		Thickness = thickness,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)

	return stroke, addGradient(stroke, 45, "accentA", "accentB")
end

local function applyTheme()
	for index = #themedObjects, 1, -1 do
		local entry = themedObjects[index]

		if not entry.instance.Parent then
			table.remove(themedObjects, index)
		elseif entry.refresh then
			pcall(entry.refresh)
		elseif entry.gradient then
			entry.instance.Color = ColorSequence.new(theme[entry.keyA], theme[entry.keyB])
		else
			entry.instance[entry.property] = theme[entry.key]
		end
	end
end

-- Icons. Accepts rbxassetid strings, numbers, or Lucide names.

local function getIcon(input)
	if type(input) == "number" then
		return "rbxassetid://" .. input
	end

	if type(input) ~= "string" or input == "" then
		return ""
	end

	if input:find("rbxassetid://", 1, true) or input:find("rbxthumb://", 1, true) then
		return input
	end

	local found = rawIcons[input:lower()]

	if type(found) == "number" then
		return "rbxassetid://" .. found
	end

	if type(found) == "string" and found ~= "" then
		return found
	end

	return nil
end

local function parseIconSource(source)
	local chunk = loadstring(source)
	if not chunk then
		return false
	end

	local ok, data = pcall(chunk)
	if ok and type(data) == "table" then
		rawIcons = data
		return true
	end

	return false
end

local function loadIconLibrary()
	if iconsLoaded then
		return
	end

	local cachePath = AxionLib.configFolder .. "/icons.lua"

	if isfile and readfile and isfile(cachePath) then
		local ok, source = pcall(readfile, cachePath)
		if ok and parseIconSource(source) then
			iconsLoaded = true
			return
		end
	end

	local ok, response = pcall(request, { Url = ICONS_URL, Method = "GET" })
	if not ok or not response or not response.Success or not parseIconSource(response.Body) then
		return
	end

	iconsLoaded = true

	pcall(function()
		ensureFolder()
		writefile(cachePath, response.Body)
	end)
end

local function resolvePendingIcons()
	for _, entry in ipairs(pendingIcons) do
		local image = getIcon(entry.name)

		if image and entry.label.Parent then
			entry.label.Image = image
		end
	end

	table.clear(pendingIcons)
end

---Download a remote image once and return a local asset.
local function resolveLogoUrl(url)
	if not (request and getcustomasset and writefile and isfile) then
		return nil
	end

	local path = AxionLib.configFolder .. "/logo_" .. hashString(url) .. ".png"

	if not isfile(path) then
		local ok, response = pcall(request, { Url = url, Method = "GET" })
		if not ok or not response or not response.Success or #response.Body < 100 then
			return nil
		end

		pcall(function()
			ensureFolder()
			writefile(path, response.Body)
		end)
	end

	local ok, asset = pcall(getcustomasset, path)
	return ok and asset or nil
end

-- Widget helpers.

local function makeIcon(parent, icon, size, position, colorKey)
	local label = create("ImageLabel", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Fit,
	}, parent)

	local image = getIcon(icon)

	if image then
		label.Image = image
	elseif type(icon) == "string" then
		table.insert(pendingIcons, { label = label, name = icon })
	end

	if colorKey then
		bind(label, "ImageColor3", colorKey)
	end

	return label
end

local function makeLabel(parent, text, size, position, font, textSize, colorKey, alignment)
	local label = create("TextLabel", {
		Text = text,
		Size = size,
		Position = position,
		Font = font or FONT,
		TextSize = textSize or 12,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)

	bind(label, "TextColor3", colorKey or "text")
	return label
end

---Chip hover effect for button-like rows.
local function addHover(button)
	button.MouseEnter:Connect(function()
		tween(button, 0.15, { BackgroundColor3 = theme.chipHover })
	end)

	button.MouseLeave:Connect(function()
		tween(button, 0.15, { BackgroundColor3 = theme.chipOff })
	end)
end

---Store the new value on an element and mirror it into the flag table.
local function publish(element, value)
	element.value = value

	if element.flag then
		AxionLib.flags[element.flag] = value
	end
end

local function normalizeKey(value)
	if typeof(value) == "EnumItem" then
		return value
	end

	if type(value) == "string" then
		local ok, key = pcall(function()
			return Enum.KeyCode[value]
		end)

		if ok then
			return key
		end
	end

	return nil
end

-- Section: a card that holds elements and lays them out automatically.

---@param tab table
---@param name string?
function Section.new(tab, name)
	local self = setmetatable({}, Section)
	self.tab = tab
	self.window = tab.window
	self.order = 0

	tab.order = tab.order + 1

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		LayoutOrder = tab.order,
	}, tab.page)

	addCorner(card, CORNER_RADIUS)
	addGradient(card, 100, "cardTop", "cardBot")
	addStroke(card, 1, 0.65)

	create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, card)

	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, card)

	if name and name ~= "" then
		local title = makeLabel(card, string.upper(name), UDim2.new(1, 0, 0, 14), UDim2.new(), FONT_BOLD, 10, "accentLight")
		title.LayoutOrder = 0
	end

	self.card = card
	return self
end

function Section:nextOrder()
	self.order = self.order + 1
	return self.order
end

---Create the base row every element sits in.
---@param height number
---@param asButton boolean?
---@param accent boolean?
function Section:makeRow(height, asButton, accent)
	local row = create(asButton and "TextButton" or "Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.card)

	if asButton then
		row.Text = ""
		row.AutoButtonColor = false
	end

	addCorner(row, 8)

	if accent then
		row.BackgroundColor3 = WHITE
		addGradient(row, 20, "accentA", "accentB")
	else
		bind(row, "BackgroundColor3", "chipOff")
	end

	return row
end

---Add a text label that wraps automatically.
---@param text string
function Section:addLabel(text)
	if type(text) == "table" then
		text = text.text
	end

	local label = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = tostring(text or ""),
		Font = FONT,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = self:nextOrder(),
	}, self.card)

	bind(label, "TextColor3", "textDim")

	local element = { kind = "label" }

	function element:setText(value)
		label.Text = tostring(value)
	end

	return element
end

---Add a clickable button. options: name, callback, icon, style ("accent" for filled).
---@param options table
function Section:addButton(options)
	options = options or {}

	local accent = options.style == "accent"
	local row = self:makeRow(34, true, accent)

	if not accent then
		addHover(row)
	end

	if options.icon then
		makeIcon(row, options.icon, UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), "text")
	end

	local label = makeLabel(
		row,
		options.name or "Button",
		UDim2.new(1, 0, 1, 0),
		UDim2.new(),
		FONT_BOLD,
		12,
		accent and "text" or "textDim",
		Enum.TextXAlignment.Center
	)

	row.MouseButton1Click:Connect(function()
		if accent then
			row.BackgroundTransparency = 0.4
			tween(row, 0.3, { BackgroundTransparency = 0 })
		else
			row.BackgroundColor3 = theme.accentA
			tween(row, 0.3, { BackgroundColor3 = theme.chipHover })
		end

		fire(options.callback)
	end)

	local element = { kind = "button" }

	function element:setText(value)
		label.Text = tostring(value)
	end

	return element
end

---Add an on/off switch. options: name, default, flag, callback, icon.
---@param options table
function Section:addToggle(options)
	options = options or {}

	local row = self:makeRow(36, true)
	addHover(row)

	local textOffset = 12

	if options.icon then
		makeIcon(row, options.icon, UDim2.new(0, 16, 0, 16), UDim2.new(0, 12, 0.5, -8), "accentLight")
		textOffset = 36
	end

	makeLabel(row, options.name or "Toggle", UDim2.new(1, -(textOffset + 64), 1, 0), UDim2.new(0, textOffset, 0, 0), FONT_MEDIUM, 12, "text")

	local pill = create("Frame", {
		Size = UDim2.new(0, 44, 0, 22),
		Position = UDim2.new(1, -56, 0.5, -11),
		BorderSizePixel = 0,
	}, row)

	bind(pill, "BackgroundColor3", "track")
	addCorner(pill, 999)
	addStroke(pill, 1, 0.6)

	local fill = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, pill)

	addCorner(fill, 999)
	addGradient(fill, 0, "accentA", "accentB")

	local knob = create("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(0, 3, 0.5, -8),
		BorderSizePixel = 0,
	}, pill)

	addCorner(knob, 999)

	local element = { kind = "toggle", flag = options.flag }

	local function render(instant)
		local on = element.value

		transition(fill, { BackgroundTransparency = on and 0 or 1 }, instant and 0 or 0.2)
		transition(knob, {
			Position = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
			BackgroundColor3 = on and WHITE or theme.muted,
		}, instant and 0 or 0.25, Enum.EasingStyle.Back)
	end

	function element:set(value, silent)
		publish(self, value == true)
		render(silent)

		if not silent then
			fire(options.callback, self.value)
		end
	end

	function element:get()
		return self.value
	end

	function element:serialize()
		return self.value
	end

	element:set(options.default == true, true)
	onTheme(row, function()
		render(true)
	end)

	row.MouseButton1Click:Connect(function()
		element:set(not element.value)
	end)

	return self:register(element)
end

---Add a numeric slider. options: name, min, max, default, increment, suffix, flag, callback.
---@param options table
function Section:addSlider(options)
	options = options or {}

	local minimum = options.min or 0
	local maximum = options.max or 100
	local increment = options.increment or 1
	local suffix = options.suffix or ""

	-- Work out how many decimals the increment needs for display.
	local decimals = 0

	while decimals < 4 do
		local scaled = increment * 10 ^ decimals
		if math.abs(scaled - math.floor(scaled + 0.5)) < 1e-6 then
			break
		end
		decimals = decimals + 1
	end

	local format = "%." .. decimals .. "f"
	local row = self:makeRow(48)

	makeLabel(row, options.name or "Slider", UDim2.new(1, -100, 0, 18), UDim2.new(0, 12, 0, 6), FONT_MEDIUM, 12, "text")
	local valueLabel = makeLabel(row, "", UDim2.new(0, 84, 0, 18), UDim2.new(1, -96, 0, 6), FONT_BOLD, 11, "accentLight", Enum.TextXAlignment.Right)

	local track = create("Frame", {
		Size = UDim2.new(1, -24, 0, 6),
		Position = UDim2.new(0, 12, 0, 32),
		BorderSizePixel = 0,
	}, row)

	bind(track, "BackgroundColor3", "track")
	addCorner(track, 999)

	local fill = create("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)

	addCorner(fill, 999)
	addGradient(fill, 0, "accentA", "accentB")

	local knob = create("Frame", {
		Size = UDim2.new(0, 12, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)

	addCorner(knob, 999)

	local hit = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 1, -28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, row)

	local element = { kind = "slider", flag = options.flag }

	local function snap(value)
		value = math.clamp(value, minimum, maximum)
		value = minimum + math.floor((value - minimum) / increment + 0.5) * increment
		return math.clamp(tonumber(string.format(format, value)), minimum, maximum)
	end

	local function render()
		local range = maximum - minimum
		local alpha = range > 0 and (element.value - minimum) / range or 0

		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = string.format(format, element.value) .. suffix
	end

	function element:set(value, silent)
		value = snap(tonumber(value) or minimum)

		local changed = value ~= self.value
		publish(self, value)
		render()

		if changed and not silent then
			fire(options.callback, value)
		end
	end

	function element:get()
		return self.value
	end

	function element:serialize()
		return self.value
	end

	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		element:set(minimum + alpha * (maximum - minimum))
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		self.window.activeSlider = fromX
		fromX(input.Position.X)
	end)

	element:set(options.default or minimum, true)
	return self:register(element)
end

---Add a dropdown. options: name, options (array), default, multi, flag, callback.
---@param options table
function Section:addDropdown(options)
	options = options or {}

	local multi = options.multi == true
	local list = options.options or {}

	local holder = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = self:nextOrder(),
	}, self.card)

	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, holder)

	local header = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = 1,
	}, holder)

	bind(header, "BackgroundColor3", "chipOff")
	addCorner(header, 8)
	addHover(header)

	makeLabel(header, options.name or "Dropdown", UDim2.new(0.5, -12, 1, 0), UDim2.new(0, 12, 0, 0), FONT_MEDIUM, 12, "text")
	local valueLabel = makeLabel(header, "", UDim2.new(0.5, -40, 1, 0), UDim2.new(0.5, 0, 0, 0), FONT, 11, "accentLight", Enum.TextXAlignment.Right)
	local chevron = makeIcon(header, BUILTIN_ICONS.chevron, UDim2.new(0, 14, 0, 14), UDim2.new(1, -26, 0.5, -7), "muted")

	local listFrame = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 0),
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 2,
	}, holder)

	bind(listFrame, "BackgroundColor3", "track")
	bind(listFrame, "ScrollBarImageColor3", "accentLight")
	addCorner(listFrame, 8)

	create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, listFrame)

	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)

	local element = { kind = "dropdown", flag = options.flag, multi = multi }
	local selected = {}
	local current = nil
	local buttons = {}
	local isOpen = false

	local function selectedList()
		local out = {}

		for _, name in ipairs(list) do
			if selected[name] then
				table.insert(out, name)
			end
		end

		return out
	end

	local function renderOptions()
		for name, data in pairs(buttons) do
			local on = multi and selected[name] == true or (not multi and current == name)

			data.button.BackgroundColor3 = theme.accentA
			data.button.BackgroundTransparency = on and 0.5 or 1
			data.button.TextColor3 = on and theme.text or theme.textDim
		end
	end

	local function commit(shouldFire)
		publish(element, multi and selectedList() or current)

		if multi then
			local names = element.value
			valueLabel.Text = #names > 0 and table.concat(names, ", ") or "None"
		else
			valueLabel.Text = current and tostring(current) or "None"
		end

		renderOptions()

		if shouldFire then
			fire(options.callback, element.value)
		end
	end

	local function setOpen(open)
		isOpen = open
		listFrame.Visible = open
		tween(chevron, 0.2, { Rotation = open and 180 or 0 })
	end

	local function choose(name)
		if multi then
			selected[name] = not selected[name] or nil
		else
			current = name
			setOpen(false)
		end

		commit(true)
	end

	local function rebuild()
		for _, data in pairs(buttons) do
			data.button:Destroy()
		end
		table.clear(buttons)

		for index, name in ipairs(list) do
			local button = create("TextButton", {
				Size = UDim2.new(1, 0, 0, 26),
				BorderSizePixel = 0,
				Text = tostring(name),
				Font = FONT_MEDIUM,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = index,
			}, listFrame)

			addCorner(button, 6)
			create("UIPadding", { PaddingLeft = UDim.new(0, 8) }, button)

			button.MouseButton1Click:Connect(function()
				choose(name)
			end)

			buttons[name] = { button = button }
		end

		listFrame.Size = UDim2.new(1, 0, 0, math.min(#list, 6) * 28 + 8)
	end

	function element:set(value, silent)
		if multi then
			table.clear(selected)

			if type(value) == "table" then
				for key, entry in pairs(value) do
					local name = type(key) == "number" and entry or (entry and key)

					if name and table.find(list, name) then
						selected[name] = true
					end
				end
			end
		else
			current = table.find(list, value) and value or nil
		end

		commit(not silent)
	end

	function element:get()
		return self.value
	end

	function element:serialize()
		return self.value
	end

	---Replace the option list. Pass keepValue to keep still-valid selections.
	function element:refresh(newOptions, keepValue)
		list = newOptions or {}

		if keepValue then
			for name in pairs(selected) do
				if not table.find(list, name) then
					selected[name] = nil
				end
			end

			if current and not table.find(list, current) then
				current = nil
			end
		else
			table.clear(selected)
			current = nil
		end

		rebuild()
		commit(false)
	end

	header.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end)

	rebuild()
	element:set(options.default, true)
	onTheme(holder, renderOptions)

	return self:register(element)
end

---Add a text input. options: name, default, placeholder, numeric, flag, callback.
---@param options table
function Section:addTextbox(options)
	options = options or {}

	local row = self:makeRow(36)
	makeLabel(row, options.name or "Textbox", UDim2.new(0.5, -12, 1, 0), UDim2.new(0, 12, 0, 0), FONT_MEDIUM, 12, "text")

	local box = create("TextBox", {
		Size = UDim2.new(0.42, 0, 0, 24),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = options.placeholder or "",
		ClearTextOnFocus = false,
		Font = FONT_MEDIUM,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	bind(box, "BackgroundColor3", "track")
	bind(box, "TextColor3", "text")
	bind(box, "PlaceholderColor3", "muted")
	addCorner(box, 6)

	local element = { kind = "textbox", flag = options.flag }

	function element:set(value, silent)
		if options.numeric then
			value = tonumber(value) or tonumber(self.value) or 0
		else
			value = tostring(value or "")
		end

		publish(self, value)
		box.Text = tostring(value)

		if not silent then
			fire(options.callback, value)
		end
	end

	function element:get()
		return self.value
	end

	function element:serialize()
		return self.value
	end

	box.FocusLost:Connect(function()
		element:set(box.Text)
	end)

	element:set(options.default or (options.numeric and 0 or ""), true)
	return self:register(element)
end

---Add a keybind picker. options: name, default (Enum.KeyCode or name), flag, callback, onChanged.
---@param options table
function Section:addKeybind(options)
	options = options or {}

	local row = self:makeRow(36)
	makeLabel(row, options.name or "Keybind", UDim2.new(1, -110, 1, 0), UDim2.new(0, 12, 0, 0), FONT_MEDIUM, 12, "text")

	local button = create("TextButton", {
		Size = UDim2.new(0, 86, 0, 24),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Font = FONT_BOLD,
		TextSize = 11,
	}, row)

	bind(button, "BackgroundColor3", "track")
	bind(button, "TextColor3", "accentLight")
	addCorner(button, 6)

	local listening = false
	local element = { kind = "keybind", flag = options.flag }

	local function render()
		button.Text = listening and "..." or (element.value and element.value.Name or "None")
	end

	function element:set(value, silent)
		local key = normalizeKey(value)

		publish(self, key)
		render()

		if not silent then
			fire(options.onChanged, key)
		end
	end

	function element:get()
		return self.value
	end

	function element:serialize()
		return self.value and self.value.Name or "None"
	end

	button.MouseButton1Click:Connect(function()
		listening = true
		render()
	end)

	self.window:track(userInputService.InputBegan:Connect(function(input, processed)
		if listening then
			if input.UserInputType ~= Enum.UserInputType.Keyboard then
				return
			end

			listening = false

			if input.KeyCode == Enum.KeyCode.Escape then
				element:set(nil)
			else
				element:set(input.KeyCode)
			end

			return
		end

		if processed or not element.value then
			return
		end

		if input.KeyCode == element.value then
			fire(options.callback, element.value)
		end
	end))

	element:set(options.default, true)
	return self:register(element)
end

---Register an element's flag so configs can save and load it.
function Section:register(element)
	element.section = self

	if element.flag then
		AxionLib.options[element.flag] = element
	end

	return element
end

-- Tab: a sidebar button plus a scrolling page of sections.

---@param window table
---@param options table
function Tab.new(window, options)
	local self = setmetatable({}, Tab)
	self.window = window
	self.name = options.name or "Tab"
	self.active = false
	self.order = 0
	self.sections = {}

	local hasDescription = options.description ~= nil

	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 42),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = #window.tabs + 1,
	}, window.tabList)

	bind(button, "BackgroundColor3", "chipOff")
	addCorner(button, 21)

	local glow = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, button)

	addCorner(glow, 21)
	addGradient(glow, 20, "accentA", "accentB")

	local badge = create("Frame", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 8, 0.5, -14),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
	}, button)

	bind(badge, "BackgroundColor3", "bgBot")
	addCorner(badge, 999)

	if options.icon then
		makeIcon(badge, options.icon, UDim2.new(0, 16, 0, 16), UDim2.new(0.5, -8, 0.5, -8), "accentLight")
	end

	local nameLabel = makeLabel(
		button,
		self.name,
		UDim2.new(1, -50, hasDescription and 0 or 1, hasDescription and 14 or 0),
		UDim2.new(0, 44, 0, hasDescription and 7 or 0),
		FONT_BOLD,
		11.5,
		"textDim"
	)

	local descLabel
	if hasDescription then
		descLabel = makeLabel(button, options.description, UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23), FONT, 9, "muted")
	end

	local function render(instant)
		local duration = instant and 0 or 0.2

		transition(button, { BackgroundColor3 = theme.chipOff }, duration)
		transition(glow, { BackgroundTransparency = self.active and 0 or 1 }, duration)
		nameLabel.TextColor3 = self.active and theme.text or theme.textDim

		if descLabel then
			descLabel.TextColor3 = self.active and theme.text or theme.muted
		end
	end

	local page = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, window.content)

	bind(page, "ScrollBarImageColor3", "accentLight")

	create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}, page)

	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, page)

	button.MouseEnter:Connect(function()
		if not self.active then
			tween(button, 0.15, { BackgroundColor3 = theme.chipHover })
		end
	end)

	button.MouseLeave:Connect(function()
		if not self.active then
			tween(button, 0.15, { BackgroundColor3 = theme.chipOff })
		end
	end)

	button.MouseButton1Click:Connect(function()
		window:selectTab(self)
	end)

	self.button = button
	self.page = page
	self.render = render

	render(true)
	onTheme(button, function()
		render(true)
	end)

	return self
end

function Tab:setActive(on, instant)
	self.active = on
	self.render(instant)

	if not on then
		self.page.Visible = false
		return
	end

	self.page.Visible = true

	if instant then
		self.page.Position = UDim2.new()
		return
	end

	self.page.Position = UDim2.new(0, 0, 0, 14)
	tween(self.page, 0.35, { Position = UDim2.new() }, Enum.EasingStyle.Quart)
end

---Create a titled card of elements.
---@param name string?
function Tab:addSection(name)
	local section = Section.new(self, name)
	table.insert(self.sections, section)
	return section
end

-- Tabs forward element calls to an untitled default section for convenience.
for _, methodName in ipairs({ "addToggle", "addButton", "addSlider", "addDropdown", "addTextbox", "addKeybind", "addLabel" }) do
	Tab[methodName] = function(self, ...)
		if not self.defaultSection then
			self.defaultSection = self:addSection("")
		end

		return self.defaultSection[methodName](self.defaultSection, ...)
	end
end

-- Window.

---Make `target` draggable by holding `handle`.
local function makeDraggable(window, handle, target)
	local state = { moved = false }
	local dragging = false
	local dragStart, startPosition

	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		dragging = true
		state.moved = false
		dragStart = input.Position
		startPosition = target.Position
	end)

	window:track(userInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart

		if delta.Magnitude > 4 then
			state.moved = true
		end

		target.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end))

	window:track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	return state
end

---@param options table
function Window.new(options)
	local self = setmetatable({}, Window)
	self.alive = true
	self.options = options
	self.connections = {}
	self.tabs = {}
	self.spinners = {}
	self.logoLabels = {}
	self.visible = false
	self.minimized = false
	self.animating = false
	self.closing = false
	self.activeSlider = nil
	self.toggleKey = options.toggleKey
	self.width = options.width or 590
	self.height = options.height or 410

	if self.toggleKey == nil then
		self.toggleKey = Enum.KeyCode.RightShift
	end

	local logo = options.logo or BUILTIN_ICONS.logo

	local gui = create("ScreenGui", {
		Name = randomName(),
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	}, safeParent())

	self.gui = gui

	-- Floating button shown while the window is minimized.
	local miniButton = create("TextButton", {
		Size = UDim2.new(0, 48, 0, 48),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 44, 0, 124),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
	}, gui)

	addCorner(miniButton, 999)
	self:spin(addGradient(miniButton, 45, "accentA", "accentB"), 60)
	addStroke(miniButton, 1.5, 0.3)

	self.miniScale = create("UIScale", { Scale = 0 }, miniButton)
	self.miniButton = miniButton

	local miniLogo = makeIcon(miniButton, logo, UDim2.new(1, -12, 1, -12), UDim2.new(0, 6, 0, 6))
	table.insert(self.logoLabels, miniLogo)

	local win = create("Frame", {
		Name = "Window",
		Size = UDim2.new(0, self.width, 0, self.height),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
	}, gui)

	addCorner(win, CORNER_RADIUS + 4)
	addGradient(win, 115, "bgTop", "bgBot")

	local winStroke, winStrokeGradient = addStroke(win, 1.5, 1)
	self:spin(winStrokeGradient, 35)

	self.win = win
	self.winStroke = winStroke
	self.baseScale = self:getBaseScale()
	self.winScale = create("UIScale", { Scale = self.baseScale * 0.85 }, win)

	-- Cover used for the open / close fade.
	local veil = create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 100,
	}, win)

	bind(veil, "BackgroundColor3", "bgBot")
	addCorner(veil, CORNER_RADIUS + 4)
	self.veil = veil

	local sidebar = create("Frame", {
		Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, win)

	addCorner(sidebar, CORNER_RADIUS + 4)
	addGradient(sidebar, 90, "sidebarTop", "sidebarBot")

	local sidebarLogo = makeIcon(sidebar, logo, UDim2.new(0, 52, 0, 52), UDim2.new(0, 14, 0, 10))
	table.insert(self.logoLabels, sidebarLogo)

	makeLabel(sidebar, options.title or "AxionLib", UDim2.new(1, -28, 0, 18), UDim2.new(0, 14, 0, 66), FONT_BOLD, 15, "text")
	makeLabel(sidebar, options.subtitle or ("AxionLib v" .. AxionLib.version), UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 84), FONT, 10, "accentLight")

	local footerText = options.footer
	if footerText == nil then
		footerText = self.toggleKey and ("[" .. self.toggleKey.Name .. "] toggle") or ""
	end

	makeLabel(sidebar, footerText, UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 1, -26), FONT, 9, "muted")

	self.tabList = create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -140),
		Position = UDim2.new(0, 0, 0, 110),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, sidebar)

	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, self.tabList)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.tabList)

	local header = create("Frame", {
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
		Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, win)

	self.titleLabel = makeLabel(header, "", UDim2.new(1, -110, 1, 0), UDim2.new(0, 18, 0, 0), FONT_BOLD, 15, "text")

	self.content = create("Frame", {
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -HEADER_HEIGHT),
		Position = UDim2.new(0, SIDEBAR_WIDTH, 0, HEADER_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, win)

	-- Header buttons.
	local minimizeButton = create("TextButton", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -62, 0.5, -11),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, header)

	bind(minimizeButton, "BackgroundColor3", "chipOff")
	addCorner(minimizeButton, 999)
	addHover(minimizeButton)
	makeIcon(minimizeButton, BUILTIN_ICONS.minimize, UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), "text")

	local closeButton = create("TextButton", {
		Size = UDim2.new(0, 22, 0, 22),
		Position = UDim2.new(1, -34, 0.5, -11),
		BackgroundColor3 = Color3.fromRGB(120, 32, 62),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, header)

	addCorner(closeButton, 999)
	makeIcon(closeButton, BUILTIN_ICONS.close, UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), "text")

	closeButton.MouseEnter:Connect(function()
		tween(closeButton, 0.15, { BackgroundColor3 = Color3.fromRGB(190, 48, 92) })
	end)

	closeButton.MouseLeave:Connect(function()
		tween(closeButton, 0.15, { BackgroundColor3 = Color3.fromRGB(120, 32, 62) })
	end)

	minimizeButton.MouseButton1Click:Connect(function()
		self:hide()
	end)

	closeButton.MouseButton1Click:Connect(function()
		self:close()
	end)

	local miniDrag = makeDraggable(self, miniButton, miniButton)

	miniButton.MouseButton1Click:Connect(function()
		if not miniDrag.moved then
			self:show()
		end
	end)

	makeDraggable(self, header, win)
	makeDraggable(self, sidebar, win)

	-- Slider dragging is routed through the window so only one slider moves at a time.
	self:track(userInputService.InputChanged:Connect(function(input)
		if not self.activeSlider then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			self.activeSlider(input.Position.X)
		end
	end))

	self:track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self.activeSlider = nil
		end
	end))

	self:track(userInputService.InputBegan:Connect(function(input, processed)
		if processed or not self.toggleKey or input.KeyCode ~= self.toggleKey then
			return
		end

		self:toggle()
	end))

	self:track(runService.Heartbeat:Connect(function()
		local now = os.clock()

		for _, spinner in ipairs(self.spinners) do
			spinner.gradient.Rotation = (now * spinner.speed) % 360
		end
	end))

	local camera = workspace.CurrentCamera
	if camera then
		self:track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self.baseScale = self:getBaseScale()

			if self.visible and not self.animating then
				self.winScale.Scale = self.baseScale
			end
		end))
	end

	if options.blur then
		self.blur = create("BlurEffect", { Name = randomName(), Size = 0 }, workspace.CurrentCamera or lighting)
	end

	task.spawn(function()
		loadIconLibrary()
		resolvePendingIcons()
	end)

	if options.logoUrl then
		task.spawn(function()
			local asset = resolveLogoUrl(options.logoUrl)

			if asset and self.alive then
				for _, label in ipairs(self.logoLabels) do
					label.Image = asset
				end
			end
		end)
	end

	self:show()
	return self
end

function Window:track(connection)
	table.insert(self.connections, connection)
	return connection
end

function Window:spin(gradient, speed)
	table.insert(self.spinners, { gradient = gradient, speed = speed })
	return gradient
end

function Window:getBaseScale()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(viewport.X * 0.9 / self.width, viewport.Y * 0.78 / self.height, 1), 0.4, 1)
end

function Window:show()
	if self.animating or self.visible or not self.alive then
		return
	end

	self.animating = true
	self.visible = true
	self.minimized = false
	self.baseScale = self:getBaseScale()
	self.win.Visible = true

	tween(self.miniScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(self.winScale, 0.5, { Scale = self.baseScale }, Enum.EasingStyle.Back)
	tween(self.veil, 0.35, { BackgroundTransparency = 1 })
	tween(self.winStroke, 0.3, { Transparency = 0.15 })

	if self.blur then
		tween(self.blur, 0.4, { Size = 6 })
	end

	task.delay(0.5, function()
		if not self.alive then
			return
		end

		self.miniButton.Visible = false
		self.animating = false
	end)
end

---Minimize into the floating button.
function Window:hide()
	if self.animating or not self.visible or not self.alive then
		return
	end

	self.animating = true
	self.visible = false
	self.minimized = true

	tween(self.winScale, 0.25, { Scale = self.baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(self.veil, 0.25, { BackgroundTransparency = 0 })
	tween(self.winStroke, 0.25, { Transparency = 1 })

	if self.blur then
		tween(self.blur, 0.25, { Size = 0 })
	end

	task.delay(0.28, function()
		if not self.alive then
			return
		end

		self.win.Visible = false
		self.miniButton.Visible = true
		self.miniScale.Scale = 0
		tween(self.miniScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		self.animating = false
	end)
end

function Window:toggle()
	if self.visible then
		self:hide()
	else
		self:show()
	end
end

---Fade out and destroy the window.
function Window:close()
	if not self.alive or self.closing or self.animating then
		return
	end

	self.closing = true
	self.animating = true
	fire(self.options.onClose)

	tween(self.winScale, 0.25, { Scale = self.baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(self.veil, 0.25, { BackgroundTransparency = 0 })
	tween(self.winStroke, 0.25, { Transparency = 1 })

	task.delay(0.28, function()
		self:destroy()
	end)
end

function Window:destroy()
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

	if self.blur then
		pcall(self.blur.Destroy, self.blur)
	end

	pcall(self.gui.Destroy, self.gui)

	local index = table.find(AxionLib.windows, self)
	if index then
		table.remove(AxionLib.windows, index)
	end
end

function Window:selectTab(tab, instant)
	if self.activeTab == tab then
		return
	end

	self.activeTab = tab

	for _, other in ipairs(self.tabs) do
		other:setActive(other == tab, instant)
	end

	self.titleLabel.Text = tab.name
end

---Add a sidebar tab. options: name, icon, description.
---@param options table|string
function Window:addTab(options)
	if type(options) == "string" then
		options = { name = options }
	end

	local tab = Tab.new(self, options or {})
	table.insert(self.tabs, tab)

	if #self.tabs == 1 then
		self:selectTab(tab, true)
	end

	return tab
end

---Add a ready-made Settings tab (theme, toggle key, config save / load, unload).
---@param options table?
function Window:addSettingsTab(options)
	options = options or {}

	local tab = self:addTab({
		name = options.name or "Settings",
		icon = options.icon or "settings",
		description = "theme & config",
	})

	local appearance = tab:addSection("Appearance")

	local themeNames = {}
	for name in pairs(THEME_PRESETS) do
		table.insert(themeNames, name)
	end
	table.sort(themeNames)

	appearance:addDropdown({
		name = "Theme",
		options = themeNames,
		default = AxionLib.themeName,
		callback = function(value)
			AxionLib:setTheme(value)
		end,
	})

	appearance:addKeybind({
		name = "Toggle UI",
		default = self.toggleKey or nil,
		onChanged = function(key)
			self.toggleKey = key
		end,
	})

	local config = tab:addSection("Config")
	local nameBox = config:addTextbox({ name = "Config name", default = "default", placeholder = "name" })

	config:addButton({
		name = "Save config",
		callback = function()
			local ok, err = AxionLib:saveConfig(nameBox:get())
			AxionLib:notify({
				title = "Config",
				content = ok and ("Saved " .. nameBox:get()) or tostring(err),
				type = ok and "success" or "error",
			})
		end,
	})

	config:addButton({
		name = "Load config",
		callback = function()
			local ok, err = AxionLib:loadConfig(nameBox:get())
			AxionLib:notify({
				title = "Config",
				content = ok and ("Loaded " .. nameBox:get()) or tostring(err),
				type = ok and "success" or "error",
			})
		end,
	})

	config:addButton({
		name = "Unload UI",
		style = "accent",
		callback = function()
			self:close()
		end,
	})

	return tab
end

function Window:notify(options)
	return AxionLib:notify(options)
end

-- Library API.

---Create a window. options: title, subtitle, logo, logoUrl, width, height, toggleKey,
---footer, theme, configFolder, blur, onClose.
---@param options table?
function AxionLib:createWindow(options)
	options = options or {}

	if options.configFolder then
		AxionLib.configFolder = options.configFolder
	end

	if options.theme then
		AxionLib:setTheme(options.theme)
	end

	local window = Window.new(options)
	table.insert(AxionLib.windows, window)

	return window
end

local function getNotifyHolder()
	if notifyHolder and notifyHolder.Parent then
		return notifyHolder
	end

	notifyGui = create("ScreenGui", {
		Name = randomName(),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1001,
	}, safeParent())

	notifyHolder = create("Frame", {
		Size = UDim2.new(0, 270, 1, -28),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, notifyGui)

	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
	}, notifyHolder)

	return notifyHolder
end

---Show a toast. options: title, content, duration, type ("info" | "success" | "error" | "warning").
---@param options table|string
function AxionLib:notify(options)
	if type(options) == "string" then
		options = { content = options }
	end

	options = options or {}

	local holder = getNotifyHolder()
	local colorKey = NOTIFY_COLORS[options.type or "info"] or "accentLight"

	notifyOrder = notifyOrder + 1

	local toast = create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		LayoutOrder = notifyOrder,
	}, holder)

	addCorner(toast, 10)
	addGradient(toast, 100, "cardTop", "cardBot")

	create("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}, toast)

	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, toast)

	if options.title then
		local title = makeLabel(toast, options.title, UDim2.new(1, 0, 0, 16), UDim2.new(), FONT_BOLD, 12, colorKey)
		title.LayoutOrder = 1
	end

	local body = create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = tostring(options.content or ""),
		Font = FONT,
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
	}, toast)

	bind(body, "TextColor3", options.title and "textDim" or colorKey)

	tween(toast, 0.25, { GroupTransparency = 0 })

	task.delay(options.duration or 3, function()
		if not AxionLib.alive or not toast.Parent then
			return
		end

		tween(toast, 0.3, { GroupTransparency = 1 })
		task.wait(0.35)
		pcall(toast.Destroy, toast)
	end)
end

---Switch theme by preset name, or pass { accentA = Color3, accentB = Color3, ...overrides }.
---@param input string|table
---@return boolean
function AxionLib:setTheme(input)
	local accentA, accentB = theme.accentA, theme.accentB
	local overrides = {}

	if type(input) == "string" then
		local preset = THEME_PRESETS[input]
		if not preset then
			return false
		end

		accentA, accentB = preset[1], preset[2]
		AxionLib.themeName = input
	elseif type(input) == "table" then
		accentA = input.accentA or accentA
		accentB = input.accentB or accentB
		overrides = input
		AxionLib.themeName = "Custom"
	else
		return false
	end

	local built = buildTheme(accentA, accentB)

	for key, value in pairs(overrides) do
		built[key] = value
	end

	table.clear(theme)

	for key, value in pairs(built) do
		theme[key] = value
	end

	applyTheme()
	return true
end

---Register your own theme preset so setTheme("Name") and the Settings dropdown can use it.
---@param name string
---@param accentA Color3
---@param accentB Color3
function AxionLib:addThemePreset(name, accentA, accentB)
	THEME_PRESETS[name] = { accentA, accentB }
end

local function configPath(name)
	return AxionLib.configFolder .. "/" .. tostring(name) .. ".json"
end

---Save every flagged element to a json file.
---@param name string
---@return boolean, string?
function AxionLib:saveConfig(name)
	if not writefile then
		return false, "writefile is not supported"
	end

	local data = {}

	for flag, element in pairs(AxionLib.options) do
		data[flag] = element:serialize()
	end

	local ok, err = pcall(function()
		ensureFolder()
		writefile(configPath(name), httpService:JSONEncode(data))
	end)

	return ok, not ok and tostring(err) or nil
end

---Load a saved config and apply it (callbacks fire so features update).
---@param name string
---@return boolean, string?
function AxionLib:loadConfig(name)
	if not (isfile and readfile) or not isfile(configPath(name)) then
		return false, "config not found"
	end

	local ok, data = pcall(function()
		return httpService:JSONDecode(readfile(configPath(name)))
	end)

	if not ok or type(data) ~= "table" then
		return false, "config is corrupted"
	end

	for flag, value in pairs(data) do
		local element = AxionLib.options[flag]

		if element then
			pcall(element.set, element, value)
		end
	end

	return true
end

---@return table
function AxionLib:listConfigs()
	local names = {}

	if not (listfiles and isfolder and isfolder(AxionLib.configFolder)) then
		return names
	end

	for _, path in ipairs(listfiles(AxionLib.configFolder)) do
		local name = path:match("([^/\\]+)%.json$")

		if name then
			table.insert(names, name)
		end
	end

	return names
end

function AxionLib:destroy()
	AxionLib.alive = false

	for _, window in ipairs(table.clone(AxionLib.windows)) do
		window:destroy()
	end

	if notifyGui then
		pcall(notifyGui.Destroy, notifyGui)
		notifyGui = nil
		notifyHolder = nil
	end

	table.clear(themedObjects)
	table.clear(AxionLib.options)
	table.clear(AxionLib.flags)

	if shared.AxionLib == AxionLib then
		shared.AxionLib = nil
	end
end

shared.AxionLib = AxionLib

return AxionLib
