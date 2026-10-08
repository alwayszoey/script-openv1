-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

local AxionHub = {
	alive = true,
	connections = {},
	gui = nil,
	blur = nil,
}

-- Constants.
local HUB_NAME = "AxionHub_AutoDice"
local HUB_VERSION = "v14"
local WHITE = Color3.new(1, 1, 1)

-- Services.
local playersService = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local lighting = game:GetService("Lighting")

local localPlayer = playersService.LocalPlayer

local Config = {
	-- Electric purple accent (logo X).
	accent = Color3.fromRGB(157, 78, 221),
	accentDim = Color3.fromRGB(104, 44, 168),
	accentLight = Color3.fromRGB(199, 146, 245),

	-- Obsidian panels.
	bgTop = Color3.fromRGB(18, 8, 30),
	bgBot = Color3.fromRGB(9, 4, 14),
	sidebarTop = Color3.fromRGB(21, 10, 35),
	sidebarBot = Color3.fromRGB(11, 5, 18),
	card = Color3.fromRGB(27, 14, 44),
	cardStroke = Color3.fromRGB(58, 34, 92),

	-- Inactive controls: dark solid purple-gray.
	chipOff = Color3.fromRGB(46, 34, 70),
	chipOffHover = Color3.fromRGB(62, 46, 94),
	chipStroke = Color3.fromRGB(88, 64, 130),

	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(220, 208, 242),
	muted = Color3.fromRGB(150, 130, 185),
	good = Color3.fromRGB(130, 255, 180),
	bad = Color3.fromRGB(255, 100, 130),

	font = Enum.Font.Gotham,
	fontBold = Enum.Font.GothamBold,
	fontMedium = Enum.Font.GothamMedium,

	blurSize = 6,
}

local State = {
	page = "MAIN",
	mode = "AUTO",
	running = false,
	rolls = 0,
	autoRollOn = false,
	diceThread = nil,
	spamSpeed = 0.03,
	bypassAnim = true,
	killCutscene = true,

	autoCollect = false,
	collectThread = nil,
	collectRate = 0.5,
	plotMin = 1,
	plotMax = 16,
	collected = 0,
	lastPlot = 0,
	collectStarted = false,

	minimized = false,
}

---Parent that keeps the gui hidden from the game when possible.
local function safeParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end

	return game:GetService("CoreGui")
end

---Walk a path of children with a timeout on each step.
local function safeFind(root, ...)
	local node = root

	for _, name in ipairs({ ... }) do
		if not node then
			return nil
		end

		local ok, child = pcall(function()
			return node:WaitForChild(name, 5)
		end)

		if not ok or not child then
			return nil
		end

		node = child
	end

	return node
end

---Keep a connection so detach can clean it up.
local function track(connection)
	table.insert(AxionHub.connections, connection)
	return connection
end

local Remotes = {
	rollDice = safeFind(replicatedStorage, "Network", "RollService", "RF", "RollDice"),
	setAutoRoll = safeFind(replicatedStorage, "Network", "RollService", "RE", "SetAutoRoll"),
	rollMessage = safeFind(replicatedStorage, "Network", "RollService", "RE", "RollMessage"),
	collectBalance = safeFind(replicatedStorage, "Network", "PlotService", "RE", "CollectBalance"),
}

local remotesReady = Remotes.rollDice ~= nil and Remotes.setAutoRoll ~= nil
local collectReady = Remotes.collectBalance ~= nil

local AntiFX = {
	camModel = nil,
	cutscene = nil,
	rollingDir = nil,
	ccEffects = {},
}

---Resolve the roll cutscene, impact frames and rolling gui.
local function initAntiFX()
	local rolling = safeFind(replicatedStorage, "Framework", "Features", "Rolling")
	if rolling then
		AntiFX.cutscene = rolling:FindFirstChild("RollCutscene")
		if AntiFX.cutscene then
			AntiFX.camModel = AntiFX.cutscene:FindFirstChild("CameraModel")
		end
	end

	AntiFX.ccEffects = {}
	for _, name in ipairs({
		"VFXImpactFrameWhite",
		"WhiteImpactFrame",
		"BlackImpactFrame",
		"VFXImpactFrameBlack",
	}) do
		local effect = lighting:FindFirstChild(name)
		if effect and effect:IsA("PostEffect") then
			table.insert(AntiFX.ccEffects, effect)
		end
	end

	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local root = playerGui:FindFirstChild("Root")
		if root then
			AntiFX.rollingDir = root:FindFirstChild("Rolling")
		end
	end

	if AntiFX.cutscene then
		local lines = AntiFX.cutscene:FindFirstChild("lines")
		if lines then
			pcall(function()
				lines:Destroy()
			end)
		end

		for _, child in ipairs(AntiFX.cutscene:GetChildren()) do
			if child:IsA("Sound") then
				pcall(function()
					child.Volume = 0
					child:Stop()
				end)
			end
		end
	end
end

---Hide the roll visuals every frame.
local function tickAntiFX()
	if not State.bypassAnim then
		return
	end

	if State.killCutscene and AntiFX.camModel then
		pcall(function()
			AntiFX.camModel.Transparency = 1
			AntiFX.camModel.CanCollide = false
			AntiFX.camModel.Anchored = true

			for _, part in ipairs(AntiFX.camModel:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.CanCollide = false
				end
			end
		end)
	end

	for _, effect in ipairs(AntiFX.ccEffects) do
		if effect.Parent and effect.Enabled then
			effect.Enabled = false
		end
	end

	if AntiFX.rollingDir and AntiFX.rollingDir.Parent then
		if AntiFX.rollingDir.Visible then
			AntiFX.rollingDir.Visible = false
		end

		for _, child in ipairs(AntiFX.rollingDir:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				child.Visible = false
			end
		end
	end
end

---Invoke one roll and keep server auto roll armed in AUTO / BOTH.
local function doRoll()
	if not Remotes.rollDice then
		return
	end

	local ok = pcall(function()
		Remotes.rollDice:InvokeServer()
	end)

	if ok then
		State.rolls = State.rolls + 1
	end

	if (State.mode == "AUTO" or State.mode == "BOTH") and not State.autoRollOn and Remotes.setAutoRoll then
		pcall(function()
			Remotes.setAutoRoll:FireServer(true)
			State.autoRollOn = true
		end)
	end
end

local function diceLoop()
	State.running = true

	while State.running do
		if State.mode == "SPAM" or State.mode == "BOTH" then
			doRoll()
		elseif State.mode == "AUTO" then
			if not State.autoRollOn and Remotes.setAutoRoll then
				pcall(function()
					Remotes.setAutoRoll:FireServer(true)
					State.autoRollOn = true
				end)
			end
		end

		task.wait(State.spamSpeed)
	end
end

local function startDice()
	if State.running or not remotesReady then
		return
	end

	State.diceThread = task.spawn(diceLoop)
end

local function stopDice()
	State.running = false

	if State.diceThread then
		pcall(task.cancel, State.diceThread)
	end

	if State.autoRollOn and Remotes.setAutoRoll then
		pcall(function()
			Remotes.setAutoRoll:FireServer(false)
		end)
		State.autoRollOn = false
	end
end

local function collectOnePlot(plotNumber)
	if not Remotes.collectBalance then
		return
	end

	pcall(function()
		Remotes.collectBalance:FireServer(plotNumber)
	end)

	State.collected = State.collected + 1
	State.lastPlot = plotNumber
end

local function collectLoop()
	while State.autoCollect do
		for plotNumber = State.plotMin, State.plotMax do
			if not State.autoCollect then
				break
			end

			collectOnePlot(plotNumber)
			task.wait(0.04)
		end

		task.wait(State.collectRate)
	end
end

local function startCollect()
	if State.collectThread or not collectReady then
		return
	end

	State.autoCollect = true
	State.collectStarted = true
	State.collectThread = task.spawn(collectLoop)
end

local function stopCollect()
	State.autoCollect = false
	State.collectStarted = false

	if State.collectThread then
		pcall(task.cancel, State.collectThread)
		State.collectThread = nil
	end
end

-- UI helpers.

local function tween(object, duration, goal)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tweenService:Create(object, info, goal):Play()
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createGradient(parent, rotation, colorSequence, transparencySequence)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or 90
	if colorSequence then
		gradient.Color = colorSequence
	end
	if transparencySequence then
		gradient.Transparency = transparencySequence
	end
	gradient.Parent = parent
	return gradient
end

local function createStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, size, position, font, textSize, color, alignment)
	local label = Instance.new("TextLabel")
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = font or Config.font
	label.TextSize = textSize or 11
	label.TextColor3 = color or Config.text
	label.BackgroundTransparency = 1
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local function makeCard(parent, size, position)
	local card = Instance.new("Frame")
	card.Size = size
	card.Position = position
	card.BackgroundColor3 = Config.card
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = parent
	createCorner(card, 10)
	createStroke(card, Config.cardStroke, 0.45, 1)
	return card
end

-- Chip: flat button that tweens between dark and glowing purple.
local function makeChip(button)
	button.BackgroundColor3 = Config.chipOff
	button.BackgroundTransparency = 0
	button.TextColor3 = Config.textDim

	return {
		button = button,
		on = false,
		stroke = createStroke(button, Config.chipStroke, 0.4, 1),
	}
end

local function refreshChip(chip, hover, instant)
	local background
	if chip.on then
		background = hover and Config.accent:Lerp(WHITE, 0.12) or Config.accent
	else
		background = hover and Config.chipOffHover or Config.chipOff
	end

	local buttonGoal = {
		BackgroundColor3 = background,
		TextColor3 = chip.on and Config.text or Config.textDim,
	}

	local strokeGoal = {
		Color = chip.on and Config.accentLight or Config.chipStroke,
		Transparency = (chip.on and 0) or (hover and 0.15 or 0.4),
	}

	if instant then
		for property, value in pairs(buttonGoal) do
			chip.button[property] = value
		end
		for property, value in pairs(strokeGoal) do
			chip.stroke[property] = value
		end
		return
	end

	tween(chip.button, 0.18, buttonGoal)
	tween(chip.stroke, 0.18, strokeGoal)
end

local function styleChip(chip, on, instant)
	chip.on = on
	refreshChip(chip, false, instant)
end

local function addHover(chip)
	track(chip.button.MouseEnter:Connect(function()
		refreshChip(chip, true)
	end))

	track(chip.button.MouseLeave:Connect(function()
		refreshChip(chip, false)
	end))
end

-- Pill toggle (fixed 46x24 with 18px knob so every toggle matches).
local PILL_SIZE = UDim2.new(0, 46, 0, 24)
local KNOB_SIZE = UDim2.new(0, 18, 0, 18)
local KNOB_PAD = 3

local function buildPill(parent, position)
	local pill = Instance.new("TextButton")
	pill.Size = PILL_SIZE
	pill.Position = position
	pill.BackgroundColor3 = Config.chipOff
	pill.BorderSizePixel = 0
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.ZIndex = 5
	pill.Parent = parent
	createCorner(pill, 999)

	local knob = Instance.new("Frame")
	knob.Size = KNOB_SIZE
	knob.BackgroundColor3 = Config.textDim
	knob.BorderSizePixel = 0
	knob.ZIndex = 6
	knob.Parent = pill
	createCorner(knob, 999)

	local parts = {
		pill = pill,
		knob = knob,
		stroke = createStroke(pill, Config.chipStroke, 0.3, 1),
		offPos = UDim2.new(0, KNOB_PAD, 0.5, -9),
		onPos = UDim2.new(1, -(18 + KNOB_PAD), 0.5, -9),
	}

	knob.Position = parts.offPos
	return parts
end

local function stylePill(parts, on, instant)
	local pillGoal = { BackgroundColor3 = on and Config.accent or Config.chipOff }
	local strokeGoal = {
		Color = on and Config.accentLight or Config.chipStroke,
		Transparency = on and 0 or 0.3,
	}
	local knobGoal = {
		Position = on and parts.onPos or parts.offPos,
		BackgroundColor3 = on and WHITE or Config.textDim,
	}

	if instant then
		for property, value in pairs(pillGoal) do
			parts.pill[property] = value
		end
		for property, value in pairs(strokeGoal) do
			parts.stroke[property] = value
		end
		for property, value in pairs(knobGoal) do
			parts.knob[property] = value
		end
		return
	end

	tween(parts.pill, 0.2, pillGoal)
	tween(parts.stroke, 0.2, strokeGoal)
	tween(parts.knob, 0.2, knobGoal)
end

local function makeToggle(parent, y, title, defaultOn, callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.ZIndex = 4
	row.Parent = parent

	makeLabel(row, title, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, 14, 0, 0), Config.fontMedium, 12, Config.text)

	local parts = buildPill(row, UDim2.new(1, -60, 0.5, -12))
	local on = defaultOn
	stylePill(parts, on, true)

	track(parts.pill.MouseButton1Click:Connect(function()
		on = not on
		stylePill(parts, on)
		if callback then
			callback(on)
		end
	end))

	return {
		set = function(value)
			on = value
			stylePill(parts, on)
		end,
	}
end

---Build the whole interface.
local function buildUI()
	local parent = safeParent()
	local old = parent:FindFirstChild(HUB_NAME)
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = HUB_NAME
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent
	AxionHub.gui = gui

	-- Minimized launcher.
	local miniBtn = Instance.new("TextButton")
	miniBtn.Name = "MiniBtn"
	miniBtn.Size = UDim2.new(0, 48, 0, 48)
	miniBtn.Position = UDim2.new(0, 20, 0, 100)
	miniBtn.BackgroundColor3 = Config.accent
	miniBtn.BorderSizePixel = 0
	miniBtn.Text = ""
	miniBtn.AutoButtonColor = false
	miniBtn.Visible = false
	miniBtn.Active = true
	miniBtn.Draggable = true
	miniBtn.Parent = gui
	createCorner(miniBtn, 12)
	createStroke(miniBtn, Config.accentLight, 0.2, 1.5)

	makeLabel(miniBtn, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 22, Config.text, Enum.TextXAlignment.Center)

	-- Transparent shell, sidebar and content are separate panels.
	local win = Instance.new("Frame")
	win.Name = "Window"
	win.Size = UDim2.new(0, 580, 0, 400)
	win.Position = UDim2.new(0.5, -290, 0.5, -200)
	win.BackgroundTransparency = 1
	win.BorderSizePixel = 0
	win.Active = true
	win.ClipsDescendants = false
	win.Parent = gui

	-- Sidebar.
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 155, 1, 0)
	sidebar.BackgroundColor3 = WHITE
	sidebar.BackgroundTransparency = 0.06
	sidebar.BorderSizePixel = 0
	sidebar.Parent = win
	createCorner(sidebar, 14)
	createGradient(sidebar, 90, ColorSequence.new(Config.sidebarTop, Config.sidebarBot))
	createStroke(sidebar, Config.cardStroke, 0.35, 1)

	local logoBox = Instance.new("Frame")
	logoBox.Size = UDim2.new(0, 44, 0, 44)
	logoBox.Position = UDim2.new(0, 18, 0, 18)
	logoBox.BackgroundColor3 = WHITE
	logoBox.BorderSizePixel = 0
	logoBox.ZIndex = 3
	logoBox.Parent = sidebar
	createCorner(logoBox, 10)
	createGradient(logoBox, 135, ColorSequence.new(Config.accent, Config.accentDim))

	makeLabel(logoBox, "◆", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 22, Config.text, Enum.TextXAlignment.Center)

	makeLabel(sidebar, "AxionHub", UDim2.new(1, -20, 0, 18), UDim2.new(0, 18, 0, 70), Config.fontBold, 15, Config.text)

	makeLabel(sidebar, "AutoDice  " .. HUB_VERSION, UDim2.new(1, -20, 0, 14), UDim2.new(0, 18, 0, 88), Config.font, 10, Config.muted)

	local pages = {
		{ id = "MAIN", icon = "🏠", label = "Main", desc = "dice & collect" },
		{ id = "SETTINGS", icon = "⚙", label = "Settings", desc = "animation / range" },
	}

	local pageButtons = {}

	for index, page in ipairs(pages) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -24, 0, 44)
		button.Position = UDim2.new(0, 12, 0, 132 + (index - 1) * 50)
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.ZIndex = 3
		button.Parent = sidebar
		createCorner(button, 10)

		local chip = makeChip(button)
		addHover(chip)

		local badge = Instance.new("Frame")
		badge.Size = UDim2.new(0, 28, 0, 28)
		badge.Position = UDim2.new(0, 8, 0.5, -14)
		badge.BackgroundColor3 = Config.bgBot
		badge.BorderSizePixel = 0
		badge.ZIndex = 4
		badge.Parent = button
		createCorner(badge, 8)

		makeLabel(badge, page.icon, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontBold, 14, Config.accentLight, Enum.TextXAlignment.Center)

		local nameLabel = makeLabel(button, page.label, UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7), Config.fontBold, 11.5, Config.textDim)
		local descLabel = makeLabel(button, page.desc, UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23), Config.font, 9, Config.muted)

		pageButtons[page.id] = {
			button = button,
			chip = chip,
			name = nameLabel,
			desc = descLabel,
		}
	end

	-- Content panel.
	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -163, 1, 0)
	content.Position = UDim2.new(0, 163, 0, 0)
	content.BackgroundColor3 = WHITE
	content.BackgroundTransparency = 0.06
	content.BorderSizePixel = 0
	content.Parent = win
	createCorner(content, 14)
	createGradient(content, 90, ColorSequence.new(Config.bgTop, Config.bgBot))
	createStroke(content, Config.cardStroke, 0.35, 1)

	-- Main page.
	local mainPage = Instance.new("Frame")
	mainPage.Size = UDim2.new(1, 0, 1, 0)
	mainPage.BackgroundTransparency = 1
	mainPage.Parent = content

	-- Header leaves room on the right for the window buttons.
	local header = makeCard(mainPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.Position = UDim2.new(0, 14, 0.5, -4)
	dot.BackgroundColor3 = Config.muted
	dot.BorderSizePixel = 0
	dot.ZIndex = 5
	dot.Parent = header
	createCorner(dot, 999)

	local statusLabel = makeLabel(header, "READY", UDim2.new(1, -44, 1, 0), UDim2.new(0, 30, 0, 0), Config.font, 11, Config.text)
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

	task.spawn(function()
		while statusLabel.Parent and AxionHub.alive do
			local status = remotesReady and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
			local color = remotesReady and (State.running and Config.good or Config.muted) or Config.bad

			statusLabel.Text = string.format("💤 · %s · rolls: %d · 💰 %d", status, State.rolls, State.collected)
			dot.BackgroundColor3 = color
			task.wait(0.2)
		end
	end)

	-- Mode card.
	local modeCard = makeCard(mainPage, UDim2.new(1, -36, 0, 106), UDim2.new(0, 18, 0, 70))

	makeLabel(modeCard, "MODE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local modes = { "AUTO", "SPAM", "BOTH" }
	local modeChips = {}

	local function refreshModes()
		for key, chip in pairs(modeChips) do
			styleChip(chip, key == State.mode)
		end
	end

	for index, mode in ipairs(modes) do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 82, 0, 32)
		button.Position = UDim2.new(0, 14 + (index - 1) * 88, 0, 28)
		button.BorderSizePixel = 0
		button.Text = mode
		button.Font = Config.fontBold
		button.TextSize = 11
		button.AutoButtonColor = false
		button.ZIndex = 4
		button.Parent = modeCard
		createCorner(button, 8)

		local chip = makeChip(button)
		modeChips[mode] = chip
		addHover(chip)

		track(button.MouseButton1Click:Connect(function()
			State.mode = mode
			refreshModes()
		end))
	end

	for _, chip in pairs(modeChips) do
		styleChip(chip, false, true)
	end
	styleChip(modeChips[State.mode], true, true)

	-- Same toggle builder as AFK Collect so both switches match.
	local autoRollToggle
	autoRollToggle = makeToggle(modeCard, 64, "🎲 Auto Roll", false, function(value)
		if value then
			startDice()
		else
			stopDice()
		end

		autoRollToggle.set(State.running)
	end)

	-- Speed card.
	local speedCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 186))

	makeLabel(speedCard, "SPAM SPEED", UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local speedValue = makeLabel(speedCard, "33 / sec", UDim2.new(0.5, -14, 0, 14), UDim2.new(0.5, 0, 0, 8), Config.fontBold, 11, Config.text, Enum.TextXAlignment.Right)

	local track_ = Instance.new("TextButton")
	track_.Size = UDim2.new(1, -28, 0, 10)
	track_.Position = UDim2.new(0, 14, 0, 36)
	track_.BackgroundColor3 = Config.bgBot
	track_.BorderSizePixel = 0
	track_.Text = ""
	track_.AutoButtonColor = false
	track_.ZIndex = 4
	track_.Parent = speedCard
	createCorner(track_, 999)
	createStroke(track_, Config.chipStroke, 0.5, 1)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = track_
	createCorner(fill, 999)
	createGradient(fill, 0, ColorSequence.new(Config.accentDim, Config.accent))

	local sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.new(0, 14, 0, 14)
	sliderKnob.Position = UDim2.new(0.5, -7, 0.5, -7)
	sliderKnob.BackgroundColor3 = Config.accentLight
	sliderKnob.BorderSizePixel = 0
	sliderKnob.ZIndex = 6
	sliderKnob.Parent = track_
	createCorner(sliderKnob, 999)
	createStroke(sliderKnob, Config.accent, 0.4, 3)

	local draggingSlider = false

	local function applyRelative(relative)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		sliderKnob.Position = UDim2.new(relative, -7, 0.5, -7)

		local rate = math.floor(20 + relative * 180)
		State.spamSpeed = 1 / rate
		speedValue.Text = rate .. " / sec"
	end

	local function setFromX(x)
		applyRelative(math.clamp((x - track_.AbsolutePosition.X) / track_.AbsoluteSize.X, 0, 1))
	end

	-- Match the slider to the default spam speed.
	local initialRate = math.clamp(math.floor(1 / State.spamSpeed + 0.5), 20, 200)
	fill.Size = UDim2.new((initialRate - 20) / 180, 0, 1, 0)
	sliderKnob.Position = UDim2.new((initialRate - 20) / 180, -7, 0.5, -7)
	speedValue.Text = initialRate .. " / sec"

	track(track_.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			setFromX(input.Position.X)
		end
	end))

	track(userInputService.InputChanged:Connect(function(input)
		if
			draggingSlider
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			setFromX(input.Position.X)
		end
	end))

	track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = false
		end
	end))

	-- Collect card.
	local collectCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 258))

	makeToggle(collectCard, 4, "💰 AFK Collect Money", State.autoCollect, function(value)
		if value then
			startCollect()
		else
			stopCollect()
		end
	end)

	makeLabel(
		collectCard,
		string.format("every %.1fs · plot %d→%d", State.collectRate, State.plotMin, State.plotMax),
		UDim2.new(1, -28, 0, 14),
		UDim2.new(0, 14, 0, 42),
		Config.font,
		9,
		Config.accentLight
	)

	-- Settings page.
	local settingsPage = Instance.new("Frame")
	settingsPage.Size = UDim2.new(1, 0, 1, 0)
	settingsPage.BackgroundTransparency = 1
	settingsPage.Visible = false
	settingsPage.Parent = content

	local settingsHeader = makeCard(settingsPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	makeLabel(settingsHeader, "⚙  Settings", UDim2.new(1, -30, 1, 0), UDim2.new(0, 16, 0, 0), Config.fontBold, 12, Config.text)

	local settingsCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 92), UDim2.new(0, 18, 0, 70))

	makeToggle(settingsCard, 4, "Bypass Roll Animation", State.bypassAnim, function(value)
		State.bypassAnim = value
	end)

	makeToggle(settingsCard, 48, "Kill Camera Cutscene", State.killCutscene, function(value)
		State.killCutscene = value
	end)

	local rangeCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 76), UDim2.new(0, 18, 0, 172))

	makeLabel(rangeCard, "PLOT RANGE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local rangeValue = makeLabel(rangeCard, string.format("1 → %d", State.plotMax), UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 26), Config.font, 10, Config.text)

	local rangeChips = {}

	local function refreshRange()
		for value, chip in pairs(rangeChips) do
			styleChip(chip, State.plotMax == value)
		end
	end

	local function makeRangeButton(text, x, value)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0, 52, 0, 26)
		button.Position = UDim2.new(0, x, 0, 44)
		button.BorderSizePixel = 0
		button.Text = text
		button.Font = Config.fontBold
		button.TextSize = 10
		button.AutoButtonColor = false
		button.ZIndex = 4
		button.Parent = rangeCard
		createCorner(button, 8)

		local chip = makeChip(button)
		rangeChips[value] = chip
		addHover(chip)

		track(button.MouseButton1Click:Connect(function()
			State.plotMin = 1
			State.plotMax = value
			rangeValue.Text = string.format("1 → %d", State.plotMax)
			refreshRange()
		end))
	end

	makeRangeButton("1 → 4", 14, 4)
	makeRangeButton("1 → 8", 72, 8)
	makeRangeButton("1 → 16", 130, 16)

	for _, chip in pairs(rangeChips) do
		styleChip(chip, false, true)
	end
	styleChip(rangeChips[State.plotMax] or rangeChips[16], true, true)

	-- Page switching.
	local function applyPage(instant)
		for id, data in pairs(pageButtons) do
			local on = id == State.page
			data.name.TextColor3 = on and Config.text or Config.textDim
			data.desc.TextColor3 = on and Config.accentLight or Config.muted
			styleChip(data.chip, on, instant)
		end

		mainPage.Visible = State.page == "MAIN"
		settingsPage.Visible = State.page == "SETTINGS"
	end

	for id, data in pairs(pageButtons) do
		track(data.button.MouseButton1Click:Connect(function()
			State.page = id
			applyPage()
		end))
	end

	-- Window buttons, aligned with the header row.
	local topButtons = Instance.new("Frame")
	topButtons.Size = UDim2.new(0, 54, 0, 22)
	topButtons.Position = UDim2.new(1, -68, 0, 26)
	topButtons.BackgroundTransparency = 1
	topButtons.ZIndex = 10
	topButtons.Parent = content

	local minBtn = Instance.new("TextButton")
	minBtn.Size = UDim2.new(0, 22, 0, 22)
	minBtn.BackgroundColor3 = Config.chipOff
	minBtn.BorderSizePixel = 0
	minBtn.Text = "—"
	minBtn.Font = Config.fontBold
	minBtn.TextSize = 14
	minBtn.TextColor3 = Config.text
	minBtn.AutoButtonColor = false
	minBtn.ZIndex = 11
	minBtn.Parent = topButtons
	createCorner(minBtn, 999)
	local minChip = { button = minBtn, on = false, stroke = createStroke(minBtn, Config.chipStroke, 0.4, 1) }
	addHover(minChip)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(0, 32, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(120, 32, 62)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.Font = Config.fontBold
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = Config.text
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 11
	closeBtn.Parent = topButtons
	createCorner(closeBtn, 999)
	createStroke(closeBtn, Config.bad, 0.5, 1)

	track(closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(170, 44, 84) })
	end))
	track(closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(120, 32, 62) })
	end))

	-- Background blur.
	local blur = Instance.new("BlurEffect")
	blur.Name = "AxionHubBlur_Internal"
	blur.Size = Config.blurSize
	blur.Parent = lighting
	AxionHub.blur = blur

	track(minBtn.MouseButton1Click:Connect(function()
		State.minimized = true
		win.Visible = false
		miniBtn.Visible = true
		blur.Size = 0
	end))

	track(miniBtn.MouseButton1Click:Connect(function()
		State.minimized = false
		win.Visible = true
		miniBtn.Visible = false
		blur.Size = Config.blurSize
	end))

	track(closeBtn.MouseButton1Click:Connect(function()
		AxionHub.detach()
	end))

	-- Window drag via the header cards.
	local draggingWindow = false
	local dragStart, startPosition

	for _, handle in ipairs({ header, settingsHeader }) do
		track(handle.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingWindow = true
				dragStart = input.Position
				startPosition = win.Position
			end
		end))
	end

	track(userInputService.InputChanged:Connect(function(input)
		if
			draggingWindow
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

	track(userInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingWindow = false
		end
	end))

	applyPage(true)
	return gui
end

---Stop everything and remove the interface.
function AxionHub.detach()
	AxionHub.alive = false

	pcall(stopDice)
	pcall(stopCollect)

	for _, connection in ipairs(AxionHub.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(AxionHub.connections)

	if AxionHub.blur then
		pcall(function()
			AxionHub.blur:Destroy()
		end)
	end

	if AxionHub.gui then
		pcall(function()
			AxionHub.gui:Destroy()
		end)
	end
end

---Wire up the anti-fx loops, remotes and the interface.
local function initializeScript()
	initAntiFX()

	task.spawn(function()
		while AxionHub.alive do
			task.wait(2)
			initAntiFX()
		end
	end)

	track(runService.Heartbeat:Connect(tickAntiFX))

	if Remotes.rollMessage then
		track(Remotes.rollMessage.OnClientEvent:Connect(function() end))
	end

	-- Resume collecting after respawn.
	track(localPlayer.CharacterAdded:Connect(function()
		task.wait(2)
		if State.collectStarted and not State.autoCollect then
			startCollect()
		end
	end))

	buildUI()
end

---This is called when initialization errors.
---@param error string
local function onInitializeError(error)
	warn("[AxionHub] Failed to initialize.")
	warn(error)
	warn(debug.traceback())
	AxionHub.detach()
end

-- Detach the previous execution before starting a new one.
if shared.AxionHub then
	pcall(shared.AxionHub.detach)
end

shared.AxionHub = AxionHub

xpcall(initializeScript, onInitializeError)
