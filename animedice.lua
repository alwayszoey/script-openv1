-- Check for table that is shared between executions.
if not shared then
	return warn("No shared, no script.")
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local AxionHub = {
	alive = true,
	connections = {},
	spinners = {},
	restores = {},
	gui = nil,
	blur = nil,
}

-- Constants.
local HUB_VERSION = "v18"
local WHITE = Color3.new(1, 1, 1)
local SIDEBAR_WIDTH = 150
local CORNER_RADIUS = 12
local CONFIG_FOLDER = "AxionHub"
local CONFIG_FILE = "AxionHub/config.json"
local RELOAD_FILE = "AxionHub.lua"
local LOGO_URL = "https://raw.githubusercontent.com/alwayszoey/script-openv1/refs/heads/main/assets/Untitled27_20261009042444.png"
local LOGO_FILE = "AxionHub/logo.png"
local SAFE_MAX_RATE = 30
local WATCHDOG_TIMEOUT = 90
local IDLE_PULSE_MIN = 90
local IDLE_PULSE_MAX = 180
local TOGGLE_KEY = Enum.KeyCode.RightShift
local PERSIST_KEYS = {
	"mode",
	"spamSpeed",
	"bypassAnim",
	"killCutscene",
	"plotMin",
	"plotMax",
	"antiAfk",
	"autoReconnect",
	"autoResume",
	"lowPower",
	"antiKick",
	"safeMode",
	"uiSound",
}

local Icons = {
	Logo = "rbxassetid://10709819149",
	Search = "rbxassetid://10734943674",
	Close = "rbxassetid://10747384394",
	Minimize = "rbxassetid://10709791185",
	Settings = "rbxassetid://10734950309",
	ChevronDown = "rbxassetid://10709790948",
	Palette = "rbxassetid://10734910430",
	Save = "rbxassetid://10734941499",
	Skull = "rbxassetid://10734962068",
	Dashboard = "rbxassetid://10709752035",
	Combat = "rbxassetid://10709818534",
	Visuals = "rbxassetid://10747375132",
	Teleport = "rbxassetid://10723404337",
	Refresh = "rbxassetid://10734933222",
	Server = "rbxassetid://10734963400",
	Copy = "rbxassetid://10709812159",
	Sound = "rbxassetid://10709810814",
	SoundMute = "rbxassetid://10709810619",
	Bell = "rbxassetid://10709752996",
	Info = "rbxassetid://10709752996",
	Check = "rbxassetid://10709790644",
	Zap = "rbxassetid://10709791882",
}

local BubbleSoundMap = {
	Click = { id = "rbxassetid://6895079853", pitch = 1.10, vol = 0.32 },
	ToggleOn = { id = "rbxassetid://6895079853", pitch = 1.40, vol = 0.35 },
	ToggleOff = { id = "rbxassetid://6895079853", pitch = 0.88, vol = 0.28 },
	TabSwitch = { id = "rbxassetid://6895079853", pitch = 1.25, vol = 0.30 },
	Dropdown = { id = "rbxassetid://6895079853", pitch = 1.00, vol = 0.30 },
	Notify = { id = "rbxassetid://4590662766", pitch = 1.35, vol = 0.38 },
}

local cloneRef = cloneref or function(value)
	return value
end

-- Services.
local playersService = cloneRef(game:GetService("Players"))
local replicatedStorage = cloneRef(game:GetService("ReplicatedStorage"))
local runService = cloneRef(game:GetService("RunService"))
local tweenService = cloneRef(game:GetService("TweenService"))
local userInputService = cloneRef(game:GetService("UserInputService"))
local lighting = cloneRef(game:GetService("Lighting"))
local teleportService = cloneRef(game:GetService("TeleportService"))
local guiService = cloneRef(game:GetService("GuiService"))
local httpService = cloneRef(game:GetService("HttpService"))
local virtualUser = cloneRef(game:GetService("VirtualUser"))
local coreGui = cloneRef(game:GetService("CoreGui"))
local soundService = cloneRef(game:GetService("SoundService"))

local localPlayer = playersService.LocalPlayer

local Config = {
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

local MODE_INFO = {
	AUTO = "ให้เซิร์ฟเวอร์ออโต้โรลให้ เบาและเสถียร",
	SPAM = "ยิงรีโมทโรลรัวๆ ตามความเร็วที่ตั้ง",
	BOTH = "ออโต้ + สแปมพร้อมกัน เร็วที่สุด",
}

local State = {
	page = "MAIN",
	mode = "AUTO",
	running = false,
	rolls = 0,
	autoRollOn = false,
	diceThread = nil,
	spamSpeed = 0.04,
	bypassAnim = true,
	killCutscene = true,
	failStreak = 0,
	lastActivity = 0,

	autoCollect = false,
	collectThread = nil,
	collectRate = 0.5,
	plotMin = 1,
	plotMax = 16,
	collected = 0,
	lastPlot = 0,
	collectStarted = false,

	-- AFK / protection.
	antiAfk = true,
	autoReconnect = true,
	autoResume = true,
	lowPower = false,
	antiKick = true,
	safeMode = true,
	reconnecting = false,
	reconnects = 0,
	reloadQueued = false,
	resumeRoll = false,
	resumeCollect = false,
	startTime = os.clock(),
	origFps = 60,

	uiSound = true,

	minimized = false,
	animating = false,
}

-- Filled by buildUI so logic code can reach the interface.
local uiRefs = {}
local notify = function() end

---Random identifier so the gui has no fixed name.
local function randomName()
	local chars = {}
	for index = 1, math.random(10, 16) do
		chars[index] = string.char(math.random(97, 122))
	end
	return table.concat(chars)
end

---Humanize a delay when safe mode is on.
local function jitter(base)
	if not State.safeMode then
		return base
	end

	return base * (0.8 + math.random() * 0.5)
end

---Delay between spam rolls, capped in safe mode.
local function getRollDelay()
	local delay = State.spamSpeed

	if State.safeMode then
		delay = math.max(delay, 1 / SAFE_MAX_RATE)
	end

	return jitter(delay)
end

local function formatTime(seconds)
	seconds = math.floor(seconds)
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

---Parent that keeps the gui hidden from the game when possible.
local function safeParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end

	return coreGui
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

---Play a short ui sound.
local function playSound(name)
	local info = BubbleSoundMap[name]
	if not State.uiSound or not info then
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

---Download the logo through request, cache it, and turn it into an asset.
local function resolveLogo()
	if LOGO_URL == "" or not (getcustomasset and writefile and isfile) then
		return Icons.Logo
	end

	if not isfile(LOGO_FILE) then
		local ok, response = pcall(request, { Url = LOGO_URL, Method = "GET" })
		if not ok or not response or not response.Success or #response.Body < 100 then
			return Icons.Logo
		end

		pcall(function()
			if makefolder and not isfolder(CONFIG_FOLDER) then
				makefolder(CONFIG_FOLDER)
			end
			writefile(LOGO_FILE, response.Body)
		end)
	end

	local ok, asset = pcall(getcustomasset, LOGO_FILE)
	return ok and asset or Icons.Logo
end

-- Persistence.

---Save settings and what was running so a rejoin can resume.
local function saveConfig()
	if not writefile then
		return
	end

	local data = {}
	for _, key in ipairs(PERSIST_KEYS) do
		data[key] = State[key]
	end
	data.wasRolling = State.running
	data.wasCollecting = State.autoCollect

	pcall(function()
		if makefolder and isfolder and not isfolder(CONFIG_FOLDER) then
			makefolder(CONFIG_FOLDER)
		end
		writefile(CONFIG_FILE, httpService:JSONEncode(data))
	end)
end

local function loadConfig()
	if not (isfile and readfile and isfile(CONFIG_FILE)) then
		return
	end

	local ok, data = pcall(function()
		return httpService:JSONDecode(readfile(CONFIG_FILE))
	end)

	if not ok or type(data) ~= "table" then
		return
	end

	for _, key in ipairs(PERSIST_KEYS) do
		if data[key] ~= nil and type(data[key]) == type(State[key]) then
			State[key] = data[key]
		end
	end

	State.resumeRoll = data.wasRolling == true
	State.resumeCollect = data.wasCollecting == true
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

-- Dice / collect logic.

---Ask the server to run auto roll once.
local function armAutoRoll()
	if State.autoRollOn or not Remotes.setAutoRoll then
		return
	end

	local ok = pcall(function()
		Remotes.setAutoRoll:FireServer(true)
	end)

	if ok then
		State.autoRollOn = true
	end
end

local function doRoll()
	if not Remotes.rollDice then
		return
	end

	local ok = pcall(function()
		Remotes.rollDice:InvokeServer()
	end)

	if ok then
		State.rolls = State.rolls + 1
		State.failStreak = 0
		State.lastActivity = os.clock()
	else
		State.failStreak = State.failStreak + 1
	end

	if State.mode == "AUTO" or State.mode == "BOTH" then
		armAutoRoll()
	end
end

local function diceLoop()
	State.running = true
	State.lastActivity = os.clock()

	while State.running do
		local delay

		if State.mode == "SPAM" or State.mode == "BOTH" then
			doRoll()
			delay = getRollDelay()
		else
			armAutoRoll()
			delay = jitter(1)
		end

		-- Back off when the remote keeps failing.
		if State.failStreak > 0 then
			delay = delay + math.min(State.failStreak * 0.5, 8)
		end

		task.wait(delay)
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
		State.diceThread = nil
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

---Plot order, shuffled in safe mode so it is not a perfect sweep.
local function buildPlotOrder()
	local order = {}

	for plotNumber = State.plotMin, State.plotMax do
		table.insert(order, plotNumber)
	end

	if State.safeMode then
		for index = #order, 2, -1 do
			local swap = math.random(1, index)
			order[index], order[swap] = order[swap], order[index]
		end
	end

	return order
end

local function collectLoop()
	while State.autoCollect do
		for _, plotNumber in ipairs(buildPlotOrder()) do
			if not State.autoCollect then
				break
			end

			collectOnePlot(plotNumber)
			task.wait(jitter(0.06))
		end

		task.wait(jitter(State.collectRate))
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

---Restart the dice loop if it silently stalls.
local function watchdogLoop()
	while AxionHub.alive do
		task.wait(5)

		local spamming = State.mode == "SPAM" or State.mode == "BOTH"
		if State.running and spamming and os.clock() - State.lastActivity > WATCHDOG_TIMEOUT then
			State.lastActivity = os.clock()
			stopDice()
			task.wait(1)
			startDice()
		end
	end
end

-- AFK 24/7.

---Tiny fake input so the client never counts as idle.
local function pulseIdle()
	pcall(function()
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new(math.random(1, 50), math.random(1, 50)))
	end)
end

local function initAntiAfk()
	-- Disable the default idle connections first.
	if getconnections then
		pcall(function()
			for _, connection in ipairs(getconnections(localPlayer.Idled)) do
				connection:Disable()
				table.insert(AxionHub.restores, function()
					connection:Enable()
				end)
			end
		end)
	end

	track(localPlayer.Idled:Connect(function()
		if State.antiAfk then
			pulseIdle()
		end
	end))

	task.spawn(function()
		while AxionHub.alive do
			task.wait(math.random(IDLE_PULSE_MIN, IDLE_PULSE_MAX))
			if State.antiAfk then
				pulseIdle()
			end
		end
	end)
end

---Re-run the script after the teleport when the file exists.
local function queueReload()
	if State.reloadQueued then
		return
	end

	if not (queue_on_teleport and isfile and isfile(RELOAD_FILE)) then
		return
	end

	State.reloadQueued = true
	pcall(queue_on_teleport, string.format('loadstring(readfile("%s"))()', RELOAD_FILE))
end

---Retry teleporting with a growing delay until it works.
local function reconnect()
	if State.reconnecting or not State.autoReconnect or not AxionHub.alive then
		return
	end

	State.reconnecting = true
	saveConfig()

	task.spawn(function()
		local attempt = 0

		while AxionHub.alive and State.autoReconnect do
			attempt = attempt + 1
			State.reconnects = attempt

			pcall(function()
				teleportService:Teleport(game.PlaceId, localPlayer)
			end)

			task.wait(math.min(4 * attempt, 45) + math.random() * 3)
		end

		State.reconnecting = false
	end)
end

local function initReconnect()
	track(guiService.ErrorMessageChanged:Connect(function(message)
		if message and message ~= "" then
			reconnect()
		end
	end))

	task.spawn(function()
		local promptGui = coreGui:WaitForChild("RobloxPromptGui", 15)
		local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 15)
		if not overlay then
			return
		end

		track(overlay.ChildAdded:Connect(function(child)
			if child.Name == "ErrorPrompt" then
				reconnect()
			end
		end))

		if overlay:FindFirstChild("ErrorPrompt") then
			reconnect()
		end
	end)

	track(localPlayer.OnTeleport:Connect(function(teleportState)
		if teleportState == Enum.TeleportState.Started then
			queueReload()
		end
	end))
end

---Low power: no 3D render and a low fps cap for long idle sessions.
local function applyLowPower(on)
	pcall(function()
		runService:Set3dRenderingEnabled(not on)
	end)

	if setfpscap then
		pcall(setfpscap, on and 15 or State.origFps)
	end
end

---Block client-side Kick calls on the local player.
local function installAntiKick()
	local oldNamecall
	local namecallHook = newcclosure(function(self, ...)
		local method = getnamecallmethod()

		if
			method == "Kick"
			and State.antiKick
			and AxionHub.alive
			and not checkcaller()
			and typeof(self) == "Instance"
			and compareinstances(self, localPlayer)
		then
			return
		end

		return oldNamecall(self, ...)
	end)
	pcall(setstackhidden, namecallHook, true)
	oldNamecall = hookmetamethod(game, "__namecall", namecallHook)

	local kickFunction = localPlayer.Kick
	local oldKick
	local kickHook = newcclosure(function(self, ...)
		if
			State.antiKick
			and AxionHub.alive
			and not checkcaller()
			and typeof(self) == "Instance"
			and compareinstances(self, localPlayer)
		then
			return
		end

		return oldKick(self, ...)
	end)
	pcall(setstackhidden, kickHook, true)

	local ok, original = pcall(hookfunction, kickFunction, kickHook)
	if ok then
		oldKick = original
		table.insert(AxionHub.restores, function()
			pcall(restorefunction, kickFunction)
		end)
	end
end

-- UI helpers.

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

---Register a gradient that slowly rotates.
local function spin(gradient, speed)
	table.insert(AxionHub.spinners, {
		gradient = gradient,
		speed = speed,
		offset = gradient.Rotation,
	})
end

local function accentSequence()
	return ColorSequence.new(Config.accentBlue, Config.accentPink)
end

local function createStroke(parent, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	local gradient = createGradient(stroke, 45, accentSequence())
	return stroke, gradient
end

---Image icon used across the interface.
local function makeIcon(parent, image, size, position, color)
	local icon = Instance.new("ImageLabel")
	icon.Size = size
	icon.Position = position
	icon.Image = image
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
	card.BackgroundColor3 = WHITE
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = 3
	card.Parent = parent
	createCorner(card, CORNER_RADIUS)
	createGradient(card, 100, ColorSequence.new(Config.cardTop, Config.cardBot))
	createStroke(card, 1, 0.65)

	return card
end

---A page is a plain frame that slides in.
local function makePage(parent)
	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Visible = false
	page.Parent = parent
	return page
end

local function makeChip(parent, size, position, text, textSize, radius)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Config.chipOff
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
		Config.fontBold,
		textSize,
		Config.textDim,
		Enum.TextXAlignment.Center
	)
	label.ZIndex = 5

	return {
		button = button,
		glow = glow,
		label = label,
		on = false,
	}
end

local function refreshChip(chip, hover, instant)
	local buttonGoal = {
		BackgroundColor3 = hover and Config.chipHover or Config.chipOff,
	}
	local glowGoal = {
		BackgroundTransparency = chip.on and 0 or 1,
	}
	local labelGoal = {
		TextColor3 = chip.on and Config.text or Config.textDim,
	}

	if instant then
		for property, value in pairs(buttonGoal) do
			chip.button[property] = value
		end
		for property, value in pairs(glowGoal) do
			chip.glow[property] = value
		end
		for property, value in pairs(labelGoal) do
			chip.label[property] = value
		end
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

local function addHover(chip)
	track(chip.button.MouseEnter:Connect(function()
		refreshChip(chip, true)
	end))

	track(chip.button.MouseLeave:Connect(function()
		refreshChip(chip, false)
	end))
end

local PILL_SIZE = UDim2.new(0, 46, 0, 24)
local KNOB_SIZE = UDim2.new(0, 18, 0, 18)
local KNOB_PAD = 3

local function buildPill(parent, position)
	local pill = Instance.new("TextButton")
	pill.Size = PILL_SIZE
	pill.Position = position
	pill.BackgroundColor3 = Config.track
	pill.BorderSizePixel = 0
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.ZIndex = 5
	pill.Parent = parent
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

	local parts = {
		pill = pill,
		fill = fill,
		offPos = UDim2.new(0, KNOB_PAD, 0.5, -9),
		onPos = UDim2.new(1, -(18 + KNOB_PAD), 0.5, -9),
	}

	local knob = Instance.new("Frame")
	knob.Size = KNOB_SIZE
	knob.Position = parts.offPos
	knob.BackgroundColor3 = Config.muted
	knob.BorderSizePixel = 0
	knob.ZIndex = 7
	knob.Parent = pill
	createCorner(knob, 999)
	parts.knob = knob

	return parts
end

local function stylePill(parts, on, instant)
	local fillGoal = {
		BackgroundTransparency = on and 0 or 1,
	}
	local knobGoal = {
		Position = on and parts.onPos or parts.offPos,
		BackgroundColor3 = on and WHITE or Config.muted,
	}

	if instant then
		for property, value in pairs(fillGoal) do
			parts.fill[property] = value
		end
		for property, value in pairs(knobGoal) do
			parts.knob[property] = value
		end
		return
	end

	tween(parts.fill, 0.2, fillGoal)
	tween(parts.knob, 0.3, knobGoal, Enum.EasingStyle.Back)
end

local function makeToggle(parent, y, title, defaultOn, callback, iconImage)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Position = UDim2.new(0, 0, 0, y)
	row.BackgroundTransparency = 1
	row.ZIndex = 4
	row.Parent = parent

	local icon
	if iconImage then
		icon = makeIcon(row, iconImage, UDim2.new(0, 18, 0, 18), UDim2.new(0, 14, 0.5, -9), Config.accentLight)
	end

	makeLabel(row, title, UDim2.new(0.7, 0, 1, 0), UDim2.new(0, iconImage and 40 or 14, 0, 0), Config.fontMedium, 12, Config.text)

	local parts = buildPill(row, UDim2.new(1, -60, 0.5, -12))
	local on = defaultOn
	stylePill(parts, on, true)

	track(parts.pill.MouseButton1Click:Connect(function()
		on = not on
		stylePill(parts, on)
		playSound(on and "ToggleOn" or "ToggleOff")
		if callback then
			callback(on)
		end
	end))

	return {
		icon = icon,
		set = function(value)
			on = value
			stylePill(parts, on)
		end,
	}
end

---Build the whole interface.
local function buildUI()
	local parent = safeParent()
	local logo = resolveLogo()

	local gui = Instance.new("ScreenGui")
	gui.Name = randomName()
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 999
	gui.Parent = parent
	AxionHub.gui = gui

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
	spin(createGradient(miniBtn, 45, accentSequence()), 60)
	createStroke(miniBtn, 1.5, 0.3)

	local miniScale = Instance.new("UIScale")
	miniScale.Scale = 0
	miniScale.Parent = miniBtn

	makeIcon(miniBtn, logo, UDim2.new(1, -12, 1, -12), UDim2.new(0, 6, 0, 6))

	-- Scale the window to fit any screen (phone, tablet, pc).
	local function getBaseScale()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(viewport.X * 0.9 / 590, viewport.Y * 0.78 / 410, 1), 0.4, 1)
	end

	local baseScale = getBaseScale()

	local win = Instance.new("Frame")
	win.Name = "Window"
	win.Size = UDim2.new(0, 590, 0, 410)
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.new(0.5, 0, 0.5, 0)
	win.BackgroundColor3 = WHITE
	win.BackgroundTransparency = 0.04
	win.BorderSizePixel = 0
	win.ClipsDescendants = true
	win.Active = true
	win.Parent = gui
	createCorner(win, CORNER_RADIUS + 4)
	createGradient(win, 115, ColorSequence.new(Config.bgTop, Config.bgBot))
	local winStroke, winStrokeGradient = createStroke(win, 1.5, 1)
	spin(winStrokeGradient, 35)

	local winScale = Instance.new("UIScale")
	winScale.Scale = baseScale * 0.85
	winScale.Parent = win

	-- Veil fades the whole window in and out.
	local veil = Instance.new("Frame")
	veil.Size = UDim2.new(1, 0, 1, 0)
	veil.BackgroundColor3 = Config.bgBot
	veil.BackgroundTransparency = 0
	veil.BorderSizePixel = 0
	veil.Active = false
	veil.ZIndex = 100
	veil.Parent = win
	createCorner(veil, CORNER_RADIUS + 4)

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, 0)
	sidebar.BackgroundColor3 = WHITE
	sidebar.BackgroundTransparency = 0.12
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 2
	sidebar.Parent = win
	createCorner(sidebar, CORNER_RADIUS + 4)
	createGradient(sidebar, 90, ColorSequence.new(Config.sidebarTop, Config.sidebarBot))

	local logoBox = Instance.new("Frame")
	logoBox.Size = UDim2.new(0, 46, 0, 46)
	logoBox.Position = UDim2.new(0, 16, 0, 18)
	logoBox.BackgroundColor3 = WHITE
	logoBox.BorderSizePixel = 0
	logoBox.ZIndex = 3
	logoBox.Parent = sidebar
	createCorner(logoBox, CORNER_RADIUS)
	spin(createGradient(logoBox, 45, accentSequence()), 70)
	createStroke(logoBox, 1, 0.4)

	makeIcon(logoBox, logo, UDim2.new(1, -8, 1, -8), UDim2.new(0, 4, 0, 4))

	makeLabel(sidebar, "AxionHub", UDim2.new(1, -20, 0, 18), UDim2.new(0, 16, 0, 72), Config.fontBold, 15, Config.text)
	makeLabel(sidebar, "AutoDice  " .. HUB_VERSION, UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 0, 90), Config.font, 10, Config.accentLight)

	local uptimeLabel = makeLabel(sidebar, "⏱ 00:00:00", UDim2.new(1, -20, 0, 14), UDim2.new(0, 16, 1, -40), Config.fontMedium, 10.5, Config.textDim)
	local shieldLabel = makeLabel(sidebar, "● protected", UDim2.new(1, -20, 0, 12), UDim2.new(0, 16, 1, -24), Config.font, 9, Config.good)

	local pages = {
		{ id = "MAIN", icon = Icons.Dashboard, label = "Main", desc = "dice & collect" },
		{ id = "SETTINGS", icon = Icons.Settings, label = "Settings", desc = "animation / range" },
		{ id = "AFK", icon = Icons.Server, label = "AFK & Safe", desc = "24/7 · anti-ban" },
	}

	local pageButtons = {}

	for index, page in ipairs(pages) do
		local chip = makeChip(
			sidebar,
			UDim2.new(1, -24, 0, 44),
			UDim2.new(0, 12, 0, 132 + (index - 1) * 50),
			"",
			11,
			22
		)
		addHover(chip)

		local badge = Instance.new("Frame")
		badge.Size = UDim2.new(0, 28, 0, 28)
		badge.Position = UDim2.new(0, 8, 0.5, -14)
		badge.BackgroundColor3 = Config.bgBot
		badge.BackgroundTransparency = 0.35
		badge.BorderSizePixel = 0
		badge.ZIndex = 6
		badge.Parent = chip.button
		createCorner(badge, 999)

		makeIcon(badge, page.icon, UDim2.new(0, 16, 0, 16), UDim2.new(0.5, -8, 0.5, -8), Config.accentLight)

		local nameLabel = makeLabel(chip.button, page.label, UDim2.new(1, -50, 0, 14), UDim2.new(0, 44, 0, 7), Config.fontBold, 11.5, Config.textDim)
		nameLabel.ZIndex = 6
		local descLabel = makeLabel(chip.button, page.desc, UDim2.new(1, -50, 0, 12), UDim2.new(0, 44, 0, 23), Config.font, 9, Config.muted)
		descLabel.ZIndex = 6

		pageButtons[page.id] = {
			button = chip.button,
			chip = chip,
			name = nameLabel,
			desc = descLabel,
		}
	end

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, 0)
	content.Position = UDim2.new(0, SIDEBAR_WIDTH, 0, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = win

	local mainPage = makePage(content)
	local settingsPage = makePage(content)
	local afkPage = makePage(content)
	local pageFrames = { MAIN = mainPage, SETTINGS = settingsPage, AFK = afkPage }

	-- Toast notification that slides up from the bottom.
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 250, 0, 28)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 420)
	toast.BackgroundColor3 = Config.cardBot
	toast.BackgroundTransparency = 1
	toast.BorderSizePixel = 0
	toast.ZIndex = 20
	toast.Parent = content
	createCorner(toast, 999)
	local toastStroke = createStroke(toast, 1, 1)
	local toastLabel = makeLabel(toast, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Config.fontMedium, 11, Config.text, Enum.TextXAlignment.Center)
	toastLabel.ZIndex = 21
	toastLabel.TextTransparency = 1

	local toastIcon = makeIcon(toast, Icons.Bell, UDim2.new(0, 14, 0, 14), UDim2.new(0, 12, 0.5, -7), Config.text)
	toastIcon.ImageTransparency = 1
	toastIcon.ZIndex = 22

	local toastToken = 0

	notify = function(text, color)
		toastToken = toastToken + 1
		local token = toastToken

		toastLabel.Text = text
		toastLabel.TextColor3 = color or Config.text
		toastIcon.Image = color == Config.good and Icons.Check or Icons.Bell
		toast.Position = UDim2.new(0.5, 0, 0, 420)

		tween(toast, 0.35, { Position = UDim2.new(0.5, 0, 0, 372), BackgroundTransparency = 0.1 }, Enum.EasingStyle.Back)
		tween(toastLabel, 0.25, { TextTransparency = 0 })
		tween(toastStroke, 0.25, { Transparency = 0.4 })
		tween(toastIcon, 0.25, { ImageTransparency = 0 })
		playSound("Notify")

		task.delay(2.2, function()
			if token ~= toastToken or not AxionHub.alive then
				return
			end

			tween(toast, 0.3, { Position = UDim2.new(0.5, 0, 0, 420), BackgroundTransparency = 1 })
			tween(toastLabel, 0.25, { TextTransparency = 1 })
			tween(toastStroke, 0.25, { Transparency = 1 })
			tween(toastIcon, 0.25, { ImageTransparency = 1 })
		end)
	end

	-- Main page.
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

	local modeCard = makeCard(mainPage, UDim2.new(1, -36, 0, 132), UDim2.new(0, 18, 0, 70))

	makeLabel(modeCard, "MODE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local modeDesc = makeLabel(modeCard, MODE_INFO[State.mode], UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 66), Config.font, 10, Config.muted)

	local modes = { "AUTO", "SPAM", "BOTH" }
	local modeChips = {}

	local function refreshModes()
		for key, chip in pairs(modeChips) do
			styleChip(chip, key == State.mode)
		end

		modeDesc.Text = MODE_INFO[State.mode]
	end

	for index, mode in ipairs(modes) do
		local chip = makeChip(
			modeCard,
			UDim2.new(0, 82, 0, 30),
			UDim2.new(0, 14 + (index - 1) * 90, 0, 28),
			mode,
			11,
			999
		)
		modeChips[mode] = chip
		addHover(chip)

		track(chip.button.MouseButton1Click:Connect(function()
			playSound("Click")
			State.mode = mode
			refreshModes()
			saveConfig()
		end))
	end

	for key, chip in pairs(modeChips) do
		styleChip(chip, key == State.mode, true)
	end
	modeDesc.Text = MODE_INFO[State.mode]

	uiRefs.autoRoll = makeToggle(modeCard, 88, "Auto Roll", false, function(value)
		if value then
			startDice()
		else
			stopDice()
		end

		uiRefs.autoRoll.set(State.running)
		saveConfig()
	end, Icons.Zap)

	-- Speed card.
	local speedCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 212))

	makeLabel(speedCard, "SPAM SPEED", UDim2.new(0.5, 0, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local speedValue = makeLabel(speedCard, "", UDim2.new(0.6, -14, 0, 14), UDim2.new(0.4, 0, 0, 8), Config.fontBold, 11, Config.text, Enum.TextXAlignment.Right)

	local sliderTrack = Instance.new("TextButton")
	sliderTrack.Size = UDim2.new(1, -28, 0, 10)
	sliderTrack.Position = UDim2.new(0, 14, 0, 36)
	sliderTrack.BackgroundColor3 = Config.track
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Text = ""
	sliderTrack.AutoButtonColor = false
	sliderTrack.ZIndex = 4
	sliderTrack.Parent = speedCard
	createCorner(sliderTrack, 999)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0.5, 0, 1, 0)
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.ZIndex = 5
	fill.Parent = sliderTrack
	createCorner(fill, 999)
	createGradient(fill, 0, accentSequence())

	local sliderKnob = Instance.new("Frame")
	sliderKnob.Size = UDim2.new(0, 16, 0, 16)
	sliderKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
	sliderKnob.BackgroundColor3 = WHITE
	sliderKnob.BorderSizePixel = 0
	sliderKnob.ZIndex = 6
	sliderKnob.Parent = sliderTrack
	createCorner(sliderKnob, 999)
	createStroke(sliderKnob, 2, 0)

	local draggingSlider = false

	local function updateSpeedText()
		local rate = math.clamp(math.floor(1 / State.spamSpeed + 0.5), 20, 200)
		local text = rate .. " / sec"

		if State.safeMode and rate > SAFE_MAX_RATE then
			text = text .. "  ·  safe cap " .. SAFE_MAX_RATE
		end

		speedValue.Text = text
	end

	uiRefs.updateSpeed = updateSpeedText

	local function applyRelative(relative)
		fill.Size = UDim2.new(relative, 0, 1, 0)
		sliderKnob.Position = UDim2.new(relative, -8, 0.5, -8)

		local rate = math.floor(20 + relative * 180)
		State.spamSpeed = 1 / rate
		updateSpeedText()
	end

	local function setFromX(x)
		applyRelative(math.clamp((x - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1))
	end

	local initialRate = math.clamp(math.floor(1 / State.spamSpeed + 0.5), 20, 200)
	fill.Size = UDim2.new((initialRate - 20) / 180, 0, 1, 0)
	sliderKnob.Position = UDim2.new((initialRate - 20) / 180, -8, 0.5, -8)
	updateSpeedText()

	track(sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSlider = true
			playSound("Click")
			setFromX(input.Position.X)
			tween(sliderKnob, 0.15, { Size = UDim2.new(0, 20, 0, 20) })
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
			if draggingSlider then
				draggingSlider = false
				tween(sliderKnob, 0.15, { Size = UDim2.new(0, 16, 0, 16) })
				saveConfig()
			end
		end
	end))

	-- Collect card.
	local collectCard = makeCard(mainPage, UDim2.new(1, -36, 0, 62), UDim2.new(0, 18, 0, 284))

	uiRefs.collect = makeToggle(collectCard, 4, "AFK Collect Money", State.autoCollect, function(value)
		if value then
			startCollect()
		else
			stopCollect()
		end

		uiRefs.collect.set(State.autoCollect)
		saveConfig()
	end, Icons.Save)

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
	local settingsHeader = makeCard(settingsPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	makeIcon(settingsHeader, Icons.Settings, UDim2.new(0, 16, 0, 16), UDim2.new(0, 16, 0.5, -8), Config.accentLight)
	makeLabel(settingsHeader, "Settings", UDim2.new(1, -50, 1, 0), UDim2.new(0, 40, 0, 0), Config.fontBold, 12, Config.text)

	local settingsCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 136), UDim2.new(0, 18, 0, 70))

	makeToggle(settingsCard, 4, "Bypass Roll Animation", State.bypassAnim, function(value)
		State.bypassAnim = value
		saveConfig()
	end, Icons.Visuals)

	makeToggle(settingsCard, 48, "Kill Camera Cutscene", State.killCutscene, function(value)
		State.killCutscene = value
		saveConfig()
	end, Icons.Skull)

	local soundToggle
	soundToggle = makeToggle(settingsCard, 92, "UI Sounds", State.uiSound, function(value)
		State.uiSound = value
		soundToggle.icon.Image = value and Icons.Sound or Icons.SoundMute
		saveConfig()
	end, State.uiSound and Icons.Sound or Icons.SoundMute)

	local rangeCard = makeCard(settingsPage, UDim2.new(1, -36, 0, 80), UDim2.new(0, 18, 0, 216))

	makeLabel(rangeCard, "PLOT RANGE", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 8), Config.fontBold, 9.5, Config.accentLight)

	local rangeValue = makeLabel(rangeCard, string.format("1 → %d", State.plotMax), UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 26), Config.font, 10, Config.text)

	local rangeChips = {}

	local function refreshRange()
		for value, chip in pairs(rangeChips) do
			styleChip(chip, State.plotMax == value)
		end
	end

	local function makeRangeButton(text, x, value)
		local chip = makeChip(rangeCard, UDim2.new(0, 56, 0, 26), UDim2.new(0, x, 0, 46), text, 10, 999)
		rangeChips[value] = chip
		addHover(chip)

		track(chip.button.MouseButton1Click:Connect(function()
			playSound("Click")
			State.plotMin = 1
			State.plotMax = value
			rangeValue.Text = string.format("1 → %d", State.plotMax)
			refreshRange()
			saveConfig()
		end))
	end

	makeRangeButton("1 → 4", 14, 4)
	makeRangeButton("1 → 8", 76, 8)
	makeRangeButton("1 → 16", 138, 16)

	for value, chip in pairs(rangeChips) do
		styleChip(chip, State.plotMax == value, true)
	end

	-- AFK & protection page.
	local afkHeader = makeCard(afkPage, UDim2.new(1, -90, 0, 42), UDim2.new(0, 18, 0, 16))

	makeIcon(afkHeader, Icons.Server, UDim2.new(0, 16, 0, 16), UDim2.new(0, 16, 0.5, -8), Config.accentLight)
	makeLabel(afkHeader, "AFK 24/7 & Protection", UDim2.new(1, -50, 1, 0), UDim2.new(0, 40, 0, 0), Config.fontBold, 12, Config.text)

	local sessionCard = makeCard(afkPage, UDim2.new(1, -36, 0, 50), UDim2.new(0, 18, 0, 66))

	makeLabel(sessionCard, "SESSION", UDim2.new(1, -28, 0, 14), UDim2.new(0, 14, 0, 6), Config.fontBold, 9.5, Config.accentLight)
	local sessionLabel = makeLabel(sessionCard, "", UDim2.new(1, -28, 0, 16), UDim2.new(0, 14, 0, 24), Config.fontMedium, 11, Config.text)

	local copyChip = makeChip(sessionCard, UDim2.new(0, 28, 0, 28), UDim2.new(1, -42, 0, 11), "", 10, 999)
	addHover(copyChip)
	makeIcon(copyChip.button, Icons.Copy, UDim2.new(0, 14, 0, 14), UDim2.new(0.5, -7, 0.5, -7), Config.text)

	track(copyChip.button.MouseButton1Click:Connect(function()
		playSound("Click")
		if setclipboard then
			setclipboard(sessionLabel.Text .. string.format(" · rolls: %d · collected: %d", State.rolls, State.collected))
			notify("Copied session stats", Config.good)
		end
	end))

	local switchCard = makeCard(afkPage, UDim2.new(1, -36, 0, 236), UDim2.new(0, 18, 0, 124))

	local function addSwitch(y, title, key, icon, onChange)
		return makeToggle(switchCard, y, title, State[key], function(value)
			State[key] = value

			if onChange then
				onChange(value)
			end

			saveConfig()
			notify(title .. (value and "  ON" or "  OFF"), value and Config.good or Config.muted)
		end, icon)
	end

	addSwitch(4, "Anti-AFK (no idle kick)", "antiAfk", Icons.Bell)
	addSwitch(42, "Auto Reconnect", "autoReconnect", Icons.Refresh)
	addSwitch(80, "Auto Resume after rejoin", "autoResume", Icons.Teleport)
	addSwitch(118, "Low Power Mode", "lowPower", Icons.Palette, applyLowPower)
	addSwitch(156, "Anti-Kick (client)", "antiKick", Icons.Combat)
	addSwitch(194, "Safe Mode (human timing)", "safeMode", Icons.Info, function()
		updateSpeedText()
	end)

	-- Live status updater.
	task.spawn(function()
		while statusLabel.Parent and AxionHub.alive do
			local status = remotesReady and (State.running and "RUNNING" or "IDLE") or "NO REMOTES"
			local color = remotesReady and (State.running and Config.good or Config.muted) or Config.bad

			statusLabel.Text = string.format("💤 · %s · rolls: %d · 💰 %d", status, State.rolls, State.collected)
			dot.BackgroundColor3 = color

			local uptime = formatTime(os.clock() - State.startTime)
			uptimeLabel.Text = "⏱ " .. uptime
			sessionLabel.Text = string.format(
				"%s  ·  reconnects: %d  ·  afk: %s",
				uptime,
				State.reconnects,
				State.antiAfk and "ON" or "OFF"
			)

			local safe = State.antiAfk and State.antiKick and State.safeMode
			shieldLabel.Text = safe and "● protected" or "● partial"
			shieldLabel.TextColor3 = safe and Config.good or Config.muted

			task.wait(0.25)
		end
	end)

	-- Page switching with a slide + fade.
	local function applyPage(instant)
		for id, data in pairs(pageButtons) do
			local on = id == State.page
			data.name.TextColor3 = on and Config.text or Config.textDim
			data.desc.TextColor3 = on and Config.text or Config.muted
			styleChip(data.chip, on, instant)
		end

		for id, frame in pairs(pageFrames) do
			if id ~= State.page then
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

	for id, data in pairs(pageButtons) do
		track(data.button.MouseButton1Click:Connect(function()
			if State.page == id then
				return
			end

			playSound("TabSwitch")
			State.page = id
			applyPage()
		end))
	end

	-- Window buttons.
	local topButtons = Instance.new("Frame")
	topButtons.Size = UDim2.new(0, 54, 0, 22)
	topButtons.Position = UDim2.new(1, -68, 0, 26)
	topButtons.BackgroundTransparency = 1
	topButtons.ZIndex = 10
	topButtons.Parent = content

	local minChip = makeChip(topButtons, UDim2.new(0, 22, 0, 22), UDim2.new(0, 0, 0, 0), "", 13, 999)
	minChip.button.ZIndex = 11
	makeIcon(minChip.button, Icons.Minimize, UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), Config.text).ZIndex = 12
	styleChip(minChip, false, true)
	addHover(minChip)

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(0, 32, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(120, 32, 62)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.Font = Config.fontBold
	closeBtn.TextSize = 12
	closeBtn.TextColor3 = Config.text
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 11
	closeBtn.Parent = topButtons
	createCorner(closeBtn, 999)
	makeIcon(closeBtn, Icons.Close, UDim2.new(0, 12, 0, 12), UDim2.new(0.5, -6, 0.5, -6), Config.text).ZIndex = 12

	track(closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(190, 48, 92) })
	end))
	track(closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.15, { BackgroundColor3 = Color3.fromRGB(120, 32, 62) })
	end))

	-- Blur sits under the camera, not in Lighting.
	local blur = Instance.new("BlurEffect")
	blur.Name = randomName()
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera or lighting
	AxionHub.blur = blur

	-- Open / close animations.
	local function showWindow()
		State.minimized = false
		State.animating = true

		win.Visible = true
		baseScale = getBaseScale()
		tween(winScale, 0.5, { Scale = baseScale }, Enum.EasingStyle.Back)
		tween(veil, 0.35, { BackgroundTransparency = 1 })
		tween(winStroke, 0.3, { Transparency = 0.15 })
		tween(blur, 0.4, { Size = Config.blurSize })

		task.delay(0.5, function()
			State.animating = false
		end)
	end

	local function hideWindow(onDone)
		State.animating = true

		tween(winScale, 0.25, { Scale = baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(veil, 0.25, { BackgroundTransparency = 0 })
		tween(winStroke, 0.25, { Transparency = 1 })
		tween(blur, 0.25, { Size = 0 })

		task.delay(0.28, function()
			if not AxionHub.alive then
				return
			end

			win.Visible = false
			State.animating = false

			if onDone then
				onDone()
			end
		end)
	end

	local function minimize()
		if State.animating then
			return
		end

		playSound("Dropdown")
		State.minimized = true
		hideWindow(function()
			miniBtn.Visible = true
			miniScale.Scale = 0
			tween(miniScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end

	local function restore()
		if State.animating then
			return
		end

		playSound("Dropdown")
		tween(miniScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.2, function()
			miniBtn.Visible = false
		end)
		showWindow()
	end

	track(minChip.button.MouseButton1Click:Connect(minimize))
	track(miniBtn.MouseButton1Click:Connect(restore))

	track(closeBtn.MouseButton1Click:Connect(function()
		if State.animating then
			return
		end

		playSound("Click")

		-- Stop first so the saved config does not auto resume next run.
		pcall(stopDice)
		pcall(stopCollect)
		saveConfig()
		hideWindow(function()
			AxionHub.detach()
		end)
	end))

	track(userInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= TOGGLE_KEY then
			return
		end

		if State.minimized then
			restore()
		else
			minimize()
		end
	end))

	-- Window drag via the header cards.
	local draggingWindow = false
	local dragStart, startPosition

	for _, handle in ipairs({ header, settingsHeader, afkHeader }) do
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

	-- Keep the size correct when the screen changes (rotate, resize).
	local camera = workspace.CurrentCamera
	if camera then
		track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			baseScale = getBaseScale()
			if not State.animating and not State.minimized then
				winScale.Scale = baseScale
			end
		end))
	end

	applyPage(true)
	showWindow()

	return gui
end

---Stop everything and remove the interface.
function AxionHub.detach()
	AxionHub.alive = false

	pcall(stopDice)
	pcall(stopCollect)

	if State.lowPower then
		pcall(applyLowPower, false)
	end

	for _, restore in ipairs(AxionHub.restores) do
		pcall(restore)
	end
	table.clear(AxionHub.restores)

	for _, connection in ipairs(AxionHub.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(AxionHub.connections)
	table.clear(AxionHub.spinners)

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

---Spin the gradients and run the roll visual killer.
local function onHeartbeat()
	tickAntiFX()

	if State.minimized then
		return
	end

	local now = os.clock()
	for _, spinner in ipairs(AxionHub.spinners) do
		spinner.gradient.Rotation = (spinner.offset + now * spinner.speed) % 360
	end
end

---Wire up the anti-fx loops, remotes, afk systems and the interface.
local function initializeScript()
	loadConfig()

	State.startTime = os.clock()
	State.lastActivity = os.clock()

	local okFps, fps = pcall(getfpscap)
	State.origFps = okFps and tonumber(fps) or 60

	initAntiFX()

	task.spawn(function()
		while AxionHub.alive do
			task.wait(2)
			initAntiFX()
		end
	end)

	track(runService.Heartbeat:Connect(onHeartbeat))

	if Remotes.rollMessage then
		track(Remotes.rollMessage.OnClientEvent:Connect(function()
			State.lastActivity = os.clock()
		end))
	end

	-- Resume collecting after respawn.
	track(localPlayer.CharacterAdded:Connect(function()
		task.wait(2)
		if State.collectStarted and not State.autoCollect then
			startCollect()
		end
	end))

	for _, step in ipairs({ initAntiAfk, initReconnect, installAntiKick }) do
		pcall(step)
	end

	task.spawn(watchdogLoop)

	buildUI()

	if State.lowPower then
		applyLowPower(true)
	end

	-- Pick the work back up after a rejoin.
	if State.autoResume then
		task.delay(1.5, function()
			if not AxionHub.alive then
				return
			end

			if State.resumeRoll then
				startDice()
				uiRefs.autoRoll.set(State.running)
			end

			if State.resumeCollect then
				startCollect()
				uiRefs.collect.set(State.autoCollect)
			end

			if State.resumeRoll or State.resumeCollect then
				notify("Resumed after rejoin", Config.good)
			end
		end)
	end
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
